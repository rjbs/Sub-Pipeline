#!perl -T

use strict;
use warnings;
use lib 't/lib';

use Test::More 'no_plan';

BEGIN { use_ok('Sub::Pipeline'); }

use Test::SubPipeline::Class;

my $data = {};

Test::SubPipeline::Class->call($data);

is_deeply(
  $data,
  { first => 1, second => 2, third => 3 },
  "pipeline did its thing",
);
