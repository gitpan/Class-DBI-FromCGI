#!/usr/bin/perl -w

use strict;

use CGI::Untaint;
use Test::More tests => 25;

#-------------------------------------------------------------------------

package Water;

use base 'Class::DBI';
use Class::DBI::FromCGI;
use File::Temp qw/tempdir/;

my $dir = tempdir( CLEANUP => 1 );

__PACKAGE__->set_db('Main', "DBI:CSV:f_dir=$dir", '', '');
__PACKAGE__->table('Water');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Other   => qw/title count wibble/);
__PACKAGE__->untaint_columns(
    printable => [qw/title/],
    integer   => [qw/count wibble/],
);

__PACKAGE__->db_Main->do(qq{
     CREATE TABLE Water (
        id     INTEGER,
        title  VARCHAR(80),
        count  INTEGER,
        wibble INTEGER
    )
});

#-------------------------------------------------------------------------

package main;
my %orig = (
  id     => 1,
  title  => 'Bout Ye',
  count  => 2,
  wibble => 10,
);
my $hoker = Water->create(\%orig);
isa_ok $hoker => 'Water';

my %args = (
  title  => 'Quare Geg',
  count  => 10,
  wibble => 8,
);

{ # Test an invalid count
  local $args{count} = "Foo";
  my $h = CGI::Untaint->new(%args);
  isa_ok $h => 'CGI::Untaint';
  ok !$hoker->update_from_cgi($h => qw/title count wibble/), "Update fails";
  ok my %error = $hoker->cgi_update_errors, "We have errors";
  ok $error{count}, "With count: $error{count}";
  ok !$error{title}, "But not with title";
  ok !$error{wibble}, "Not wibble";
  is $hoker->$_(), $orig{$_}, "$_ unchanged" foreach qw/title count wibble/;
}

{ # Test multiple errors
  local $args{count} = "Foo";
  local $args{wibble} = "Bar";
  my $h = CGI::Untaint->new(%args);
  isa_ok $h => 'CGI::Untaint';
  ok !$hoker->update_from_cgi($h => qw/title count wibble/), "Update fails";
  ok my %error = $hoker->cgi_update_errors, "We have errors";
  ok $error{count}, "With count: $error{count}";
  ok $error{wibble}, "And wibble: $error{wibble}";
  ok !$error{title}, "But not with title";
  is $hoker->$_(), $orig{$_}, "$_ unchanged" foreach qw/title count wibble/;
}

{ # Test everything OK
  my $h = CGI::Untaint->new(%args);
  isa_ok $h => 'CGI::Untaint';
  ok $hoker->update_from_cgi($h => qw/title count wibble/), "Can update";
  ok !$hoker->cgi_update_errors, "No error";
  is $hoker->$_(), $args{$_}, "$_ changed" foreach qw/title count wibble/;
  $hoker->commit;
}

