#!perl -T

use strict;
use warnings;
use Test::More 'no_plan';

BEGIN { use_ok('Sub::Pipeline'); }

my $order;
sub sample_pipeline {
  $order = 0;
  # a stupidly simple pipeline that just runs through some things and succeeds
  my $sub = Sub::Pipeline->new({
    order => [ qw(begin check init run end) ],
    pipe  => {
      begin => sub { cmp_ok($order++, '==', 0, "begin pipeline runs") },
      check => sub { cmp_ok($order++, '==', 1, "check pipeline runs") },
      init  => sub { cmp_ok($order++, '==', 2, "init pipeline runs") },
      run   => sub { cmp_ok($order++, '==', 3, "run pipeline runs") },
      end   => sub {
        cmp_ok($order++, '==', 4, "end pipeline runs");
        Sub::Pipeline::Success->throw
      },
    },
  });
}

{
  my $sub = sample_pipeline;
  isa_ok($sub, 'Sub::Pipeline', 'sub');

  $sub->install_pipeline({ as => "do_it", into => "Whatever" });

  {
    eval { Whatever->do_it };
    my $e = $@;
    isa_ok($e, 'Sub::Pipeline::Success');
  }
}
