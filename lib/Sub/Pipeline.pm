package Sub::Pipeline;

use warnings;
use strict;

use Carp ();
use Sub::Install;

=head1 NAME

Sub::Pipeline - subs composed of sequential pieces

=head1 VERSION

version 0.03

 $Id$

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

  use Sub::Pipeline;

  my $pipeline = Sub::Pipeline->new({
    on_success => 'return',
    order => [ qw(init validate check_acl do) ],
    pipe  => {
      init      => sub { die "can't initialize"  unless do_init; },
      validate  => sub { die "validatione error" unless validate_args(@_); },
      check_acl => sub { die "permission error"  unless get_user->may(@_); },
      do        => sub {
        my $result = do_something_complicated(@_);
        Sub::Pipeline::Sucess->throw($result)
      },
    },
  });

  $pipeline->install_pipeline({ as => "transmogrify", into => "Origami" });

  my $result = Origami->transmogrify(10, 20, 99);

=head1 DESCRIPTION

This module makes it easy to construct routines out of smaller routines which
can be swapped in and out, have their exception handling altered, or cause
early successful return.

=head1 METHODS

=head2 C< new >

This method constructs and initializes a new Sub::Pipeline.

Valid arguments are:

 order - a reference to an array of names of pipes to be run, in order
 pipe  - a reference to a hash of pipe names and implementations (code refs)
 on_success - what to do on success (default 'value'; see 'on_success' below)

=cut

sub new {
  my ($class, $arg) = @_;
  $arg->{on_success} ||= 'value';

  my $self = bless {} => $class;

  $self->order(@{ $arg->{order} }) if $arg->{order};
  $self->pipe($_ => $arg->{pipe}{$_}) for (keys %{ $arg->{pipe} });
  $self->on_success($arg->{on_success});

  return $self;
}

=head2 C< order >

  my @old_order = $pipeline->order;
  my @new_order = $pipeline->order(qw(begin check init run end));

This method sets the order in which the pipe pieces are run.

=cut

sub order {
  my $self = shift;
  return @{ $self->{order} } unless @_;

  $self->{order} = [ @_ ];
  return @_;
}

=head2 C< pipe >

  my $code = $pipeline->pipe($name);

  $pipeline->pipe($name => sub { });

This method sets the named pipe piece to the given code reference.

=cut

sub pipe {
  my ($self, $name, $code) = @_;
  return $self->{pipe}{$name} if @_ == 2;
  Carp::croak "pipe piece must be a code reference" unless ref $code eq 'CODE';
  $self->{pipe}{$name} = $code;
}

=head2 C< on_success >

  $pipeline->on_success('throw');

This method sets the behavior for handling the Sub::Pipeline::Success
exception.  That exception is thrown by a pipe piece to indicate completion.

Valid values are:

 throw  - the thrown exception is rethrown
 return - the thrown exception is returned
 value  - the value of the exception is returned

=cut

my %_behavior = map { $_ => 1 } qw(throw return value);

sub on_success {
  my $self = shift;
  return $self->{behavior} unless @_;

  my ($behavior) = @_;
  Carp::croak "invalid value for on_success" unless $_behavior{ $behavior };
  $self->{behavior} = $behavior;
}

=head2 C< check >

This method checks whether the pipe is complete and intact.  If any pipe piece
is missing, a Sub::Pipeline::PipeMissing exception is thrown.  Its C<pipe>
field is set to the name of the first missing pipe.

=cut

sub check {
  my ($self) = @_;
  for my $pipe ($self->order) {
    my $code = $self->pipe($pipe);
    unless ((ref $code eq 'CODE') or overload::Method($code, '&{}')) {
      Sub::Pipeline::PipeMissing->throw(pipe => $pipe);
    }
  }
  return 1;
}

=head2 C< call >

This method calls each piece of the pipeline in order.  Non-success exceptions
are rethrown.  Success exceptions are handled according to the defined
C<L</on_success>> behavior.

If a pipeline piece is missing, a Sub::Pipeline::PipeMissing exception is
thrown.  This method does not implement this in terms of C<L</check>>, so
multiple pipe pieces may be called before this exception is thrown.

=cut

sub _call_parts {
  my ($self, $order, $on_success, $get_part, $arg) = @_;

  push @$arg, {}; # notes

  for my $pipe (@$order) {
    my $code = $get_part->($pipe);
    unless ((ref $code eq 'CODE') or overload::Method($code, '&{}')) {
      Sub::Pipeline::PipeMissing->throw(pipe => $pipe);
    }
    eval { $code->(@$arg) };
    next unless $@;
    if (my $e = Exception::Class->caught('Sub::Pipeline::Success')) {
      return $e if $on_success eq 'return';
      return $e->value if $on_success eq 'value';
      $e->rethrow if $on_success eq 'throw';
      die "unknown on_success behavior: " . $on_success;
    } else {
      die $@;
    }
  }
}

sub call {
  my $self = shift;

  $self->_call_parts(
    [ $self->order ],
    $self->on_success,
    sub { $self->pipe($_[0]) },
    \@_
  );
}

=head2 C< as_code >

This method returns a code reference which, if called, is equivalent to calling
the pipeline's C<call> method.

=cut

sub as_code {
  my ($self) = @_;
  sub { $self->call(@_) };
}

=head2 C< load_from_package >

  $pipeline->load_from_package($package_name);

This method loads the pipeline's pipes by looking for subs with the pipe names
in the given package.

=cut

sub load_from_package {
  my ($self, $package) = @_;

  for my $pipe ($self->order) {
    my $code = $package->can($pipe);
    Carp::croak "package $package has no sub $pipe" unless $code;
    $self->pipe($pipe => $code);
  }
}

=head2 C< save_to_package >

  $pipeline->save_to_package($package_name, \%arg);

This method saves the pipeline to a package.  It installs each of its pipe
pieces as a named subroutine in the package, and installs a C<call> routine in
the package to invoke the pipeline.

An named argument, C<reinstall>, may be passed as a true value to suppress
warnings on redefining existing subs in the package.

=cut

sub save_to_package {
  my ($self, $package, $arg) = @_;

  my $installer
    = Sub::Install->can($arg->{reinstall} ? 'reinstall_sub' : 'install_sub');

  for my $pipe ($self->order) {
    $installer->({
      into => $package,
      as   => $pipe,
      code => $self->pipe($pipe),
    });
  }

  my $on_success = $self->on_success;

  my $caller = sub {
    $self->_call_parts(
      [ $self->order ],
      $self->on_success,
      $package->can($_[0]),
      \@_,
    );
  };

  $installer->({ into => $package, as => 'call', code => $caller });
}

=head2 C< install_pipeline >

  $pipeline->install_pipeline({ into => $package, as => $method_name });

This method installs the pipeline into the named package with the given method
name.  A C<reinstall> parameter may also be passed.  If true, warnings for
redefining over an existing sub are suppressed.

=cut

sub install_pipeline {
  my ($self, $arg) = @_;

  ($arg->{into}) ||= caller(0);

  my $installer
    = Sub::Install->can($arg->{reinstall} ? 'reinstall_sub' : 'install_sub');

  Carp::croak "install_pipeline requires an 'as' parameter" unless $arg->{as};
  $installer->({
    code => $self->as_code,
    into => $arg->{into},
    as   => $arg->{as}
  });
}

=head2 C< install_new >

  Sub::Pipeline->install_new(\%arg);

This method creates a new pipeline and installs it.  The C<into>, C<as>, and
C<reinstall> arguments are passed to C<install_pipeline>.  All other arguments
are passed to C<new>.

=cut

sub install_new {
  my ($self, $arg) = @_;

  my $install_arg = {};
  $install_arg->{$_} = delete $arg->{$_} for qw(into as reinstall);

  $self->new($arg)->install_pipeline($install_arg);
}

use overload
  '&{}'    => 'as_code',
  fallback => 1
;

use Sub::Exporter -setup => {
  groups     => { class => \&_class_generator },
  collectors => [ order => sub { ref $_[0] eq 'ARRAY' } ],
};

sub _class_generator {
  my ($class, $name, $arg, $col) = @_;

  my @order = @{ $col->{order} };
  
  my $order_acc = sub { return @_ ? (@order = @_) : @order; };
  my $caller    = sub {
    my ($self) = @_;
    $class->_call_parts(
      [ $order_acc->() ],
      'value', # make configurable
      sub { $self->can($_[0]) },
      \@_,
    );
  };

  return {
    order => $order_acc,
    call  => $caller,
  };
}

=head1 DIAGNOSTICS

This method defines two exception classes (via L<Exception::Class>): 

=over

=item * Sub::Pipeline::Success

This exception is thrown by a pipeline piece that wishes to indicate that the
pipeline is done.

=item * Sub::Pipeline::PipeMissing

This exception is thrown by C<L</check>> or C<L</call>> when a pipeline piece
listed in the pipeline's calling order is undefined or not callable.

=back

=cut

use Exception::Class (
  'Sub::Pipeline::Success',     { fields => [qw(value)] },
  'Sub::Pipeline::PipeMissing', { fields => [qw(pipe) ] },
);

=head1 TODO

=over

=item * B<urgent>: supply a method for passing data between pipeline segments

=back

=head1 AUTHOR

Ricardo Signes, C<< <rjbs@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sub-pipeline@rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org>.  I will be notified, and
then you'll automatically be notified of progress on your bug as I make
changes.

=head1 COPYRIGHT

Copyright 2005 Ricardo Signes, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
