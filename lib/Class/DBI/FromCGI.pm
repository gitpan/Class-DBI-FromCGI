package Class::DBI::FromCGI;

=head1 NAME

Class::DBI::FromCGI - Update Class::DBI data using CGI::Untaint

=head1 SYNOPSIS

  package Film;
  use Class::DBI::FromCGI;
  use base 'Class::DBI'; 
  # set up as any other Class::DBI class.

  __PACKAGE__->untaint_columns(
    printable => [qw/Title Director/],
    integer   => [qw/DomesticGross NumExplodingSheep],
    date      => [qw/OpeningDate/],
  );

  # Later on, over in another package ...

  my $h = CGI::Untaint->new;
  my $film = Film->retrieve('Godfather II');
  unless ($film->update_from_cgi($h => @columns_to_update)) {
    my %errors = $film->cgi_update_errors;
    while (my ($field, $problem) = each %errors) {                              
      warn "Problem with $field: $problem\n";
    }
  }

=head1 DESCRIPTION

Lots of times, Class::DBI is used in web-based applications. (In fact,
coupled with a templating system that allows you to pass objects, such
as Template::Toolkit, Class::DBI is very much your friend for these.)

And, as we all know, one of the most irritating things about writing
web-based applications is the monotony of writing much of the same stuff
over and over again. And, where there's monotony there's a tendency to
skip over stuff that we all know is really important, but is a pain to
write - like Taint Checking and sensible input validation. (Especially
as we can still show a 'working' application without it!). So, we now
have CGI::Untaint to take care of a lot of that for us.

It so happens that CGI::Untaint also plays well with Class::DBI. All
you need to do is to 'use Class::DBI::FromCGI' in your class (or in your
local Class::DBI subclass that all your other classes inherit from. You
do do that, don't you?). 

Then, in each class in which you want to use this, you declare how you
want to untaint each column:

  __PACKAGE__->untaint_columns(
    printable => [qw/Title Director/],
    integer   => [qw/DomesticGross NumExplodingSheep],
    date      => [qw/OpeningDate/],
  );

(where the keys are the CGI::Untaint package to be used, and the values
a listref of the relevant columns).

Then, when you want to update based on the values coming in from a
web-based form, you just call:

  $obj->update_from_cgi($h => @columns_to_update);

If every value passed in gets through the CGI::Untaint process, the
object will be updated (but not committed, in case you want to do anything
else with it). Otherwise the update will fail (there are no partial
updates), and $obj->cgi_update_errors will tell you what went wrong
(as a hash of problem field => error from CGI::Untaint).

Doesn't that make your life so much easier?

=head1 NOTE

Don't try to update the value of your primary key. Class::DBI doesn't
like that. If you try to do this it will be silently skipped.

Note that this means, on the other hand, that you can do:
  
  $obj->update_from_cgi($h => $obj->columns('All'));

In fact, this is the behaviour if you don't pass it any columns at all,
and just do:
  $obj->update_from_cgi($h);

=head1 SEE ALSO

L<Class::DBI>. L<CGI::Untaint>. L<Template>.

=head1 AUTHOR

Tony Bowden. E<lt>tmtm@kasei.comE<gt>.

=head1 FEEDBACK

I'd love to hear from you if you start using this. I'd particularly like
to hear any suggestions as to how to make it even better / easier etc.

=head1 COPYRIGHT

Copyright (C) 2001 Kasei. All rights reserved.

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use vars qw/$VERSION/;
$VERSION = 0.04;

use strict;
use Exporter;

use vars qw/@ISA @EXPORT/;
use base 'Exporter';
@EXPORT = qw/update_from_cgi untaint_columns _untaint_handlers
             cgi_update_errors/;

sub untaint_columns {
  my ($class, %args) = @_;
  $class->mk_classdata('__untaint_types')
    unless $class->can('__untaint_types');
  while (my($type, $ref) = each(%args)) {
    my %types = %{$class->__untaint_types || {}};
       $types{$type} = $ref;
    $class->__untaint_types(\%types);
  }
}

sub update_from_cgi {
  my ($self, $h, @wanted) = @_;
  my $class = ref($self) 
    or die "update_from_form cannot be called as a class method";
  my %handler = $class->_untaint_handlers;
  my %to_update;
  $self->{_cgi_update_error} = {};
  my %pri = map { $_ => 1 } $class->columns('Primary');
  @wanted = $class->columns('All') unless @wanted;
  foreach my $field (@wanted) {
    next if $pri{$field};
    die "Don't know how to untaint $field" unless $handler{$field};
    my $value = $h->extract("-as_$handler{$field}" => $field);
    if (my $err = $h->error) {
      $self->{_cgi_update_error}->{$field} = $err
    } else {
      $to_update{$field} = $value;
    }
  }
  return 0 if $self->cgi_update_errors;
  $self->$_($to_update{$_}) foreach keys %to_update;
  return 1;
}

sub cgi_update_errors { %{shift->{_cgi_update_error}} }

sub _untaint_handlers { 
  my $class = shift;
  die "untaint_columns not set up for $class"
    unless $class->can('__untaint_types');
  my %type = %{$class->__untaint_types || {}};
  my %h; @h{@{$type{$_}}} = ($_) x @{$type{$_}} foreach keys %type;
  return %h;
}

1;

