use ExtUtils::MakeMaker;

my $me = "lib/Class/DBI/FromCGI.pm";

WriteMakefile(
    NAME          => 'Class::DBI::FromCGI',
    VERSION_FROM  => $me, 
    PREREQ_PM     => { 
      'Class::DBI'   => 0,
      'CGI::Untaint' => 0,
      'Test::More'   => '0.17',
    },
    ($] < 5.005 ? () : (
       ABSTRACT_FROM => $me, 
       AUTHOR     => 'Tony Bowden <kasei@tmtm.com>') 
    ),
);

