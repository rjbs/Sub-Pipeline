use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Sub::Pipeline',
    AUTHOR              => 'Ricardo Signes <rjbs@cpan.org>',
    VERSION_FROM        => 'lib/Sub/Pipeline.pm',
    ABSTRACT_FROM       => 'lib/Sub/Pipeline.pm',
    LICENSE             => 'perl',
    PL_FILES            => {},
    PREREQ_PM => {
        'Exception::Class' => 1.22,
        'Params::Util'     => 0.22, # most working _CODELIKE
        'Sub::Install'     => 0,    # minimum required version unknown
        'Sub::Exporter'    => 0.95, # original reasoning unknown
        'Test::More'       => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Sub-Pipeline-* cover_db' },
);
