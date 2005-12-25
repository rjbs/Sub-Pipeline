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

  my $code = \&$sub;

  isa_ok($code, 'CODE', "referenced code dereference of sub");

  {
    eval { $code->() };
    my $e = $@;
    isa_ok($e, 'Sub::Pipeline::Success');
  }
}

{
  my $sub = sample_pipeline;

  $sub->on_success('return');
  my $r = eval { $sub->call; };
  ok( !$@, "no exception thrown with 'return' behavior on");
  isa_ok($r, 'Sub::Pipeline::Success', 'return value');
  $sub->on_success('throw');
}

{
  my $sub = sample_pipeline;
  $sub->pipe(init => sub { $order = -10; die "internal failure" });
  eval { $sub->call; };
  my $e = $@;
  ok($e, "sub call threw exception");
  is(ref $e, '', "but it wasn't the success exception");
  cmp_ok($order, '==', -10, 'and now $order is -10');
}

