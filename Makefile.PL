use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Sub::Pipeline',
    AUTHOR              => 'Ricardo Signes <rjbs@cpan.org>',
    VERSION_FROM        => 'lib/Sub/Pipeline.pm',
    ABSTRACT_FROM       => 'lib/Sub/Pipeline.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Exception::Class' => 1.22,
        'Test::More'       => 0,
        'Sub::Installer'   => 0.95,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Sub-Pipeline-* cover_db' },
);
