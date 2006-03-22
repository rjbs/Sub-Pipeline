#!perl -T

use strict;
use warnings;
use lib 't/lib';

use Test::More tests => 3;

BEGIN { use_ok('Sub::Pipeline'); }

use Test::SubPipeline::Class;

my $data = {};

my $v = Test::SubPipeline::Class->call($data);

is_deeply(
  $data,
  { first => 1, second => 2, third => 3 },
  "pipeline did its thing",
);

is($v, "OK!!", "correct return");
