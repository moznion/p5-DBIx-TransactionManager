package DBIx::TransactionManager;
use strict;
use warnings;
use Carp ();
our $VERSION = '0.01';

sub new {
    my ($class, $dbh) = @_;

    my $self = bless {
        dbh => $dbh,
        active_transaction => 0,
        rollbacked_in_nested_transaction => 0,
    }, $class;
}

sub txn_scope {
    DBIx::TransactionManager::ScopeGuard->new( @_ );
}

sub txn_begin {
    my $self = shift;
    return if ( ++$self->{active_transaction} > 1 );
    $self->{dbh}->begin_work;
}

sub txn_rollback {
    my $self = shift;
    return unless $self->{active_transaction};

    if ( $self->{active_transaction} == 1 ) {
        $self->{dbh}->rollback;
        $self->txn_end;
    }
    elsif ( $self->{active_transaction} > 1 ) {
        $self->{active_transaction}--;
        $self->{rollbacked_in_nested_transaction}++;
    }
}

sub txn_commit {
    my $self = shift;
    return unless $self->{active_transaction};

    if ( $self->{rollbacked_in_nested_transaction} ) {
        $self->{dbh}->rollback;
        Carp::croak "tried to commit but already rollbacked in nested transaction.";
    }
    elsif ( $self->{active_transaction} > 1 ) {
        $self->{active_transaction}--;
        return;
    }

    $self->{dbh}->commit;
    $self->txn_end;
}

sub txn_end {
    $_[0]->{active_transaction} = 0;
    $_[0]->{rollbacked_in_nested_transaction} = 0;
}

package DBIx::TransactionManager::ScopeGuard;
use Try::Tiny;

sub new {
    my($class, $klass) = @_;
    $klass->txn_begin;
    bless [ 0, $klass, ], $class;
}

sub rollback {
    return if $_[0]->[0];
    $_[0]->[1]->txn_rollback;
    $_[0]->[0] = 1;
}

sub commit {
    return if $_[0]->[0];
    $_[0]->[1]->txn_commit;
    $_[0]->[0] = 1;
}

sub DESTROY {
    my($dismiss, $klass) = @{ $_[0] };
    return if $dismiss;

    Carp::carp('do rollback');

    try {
        $klass->txn_rollback;
    } catch {
        die "Rollback failed: $_";
    };
}

1;
__END__

=head1 NAME

DBIx::TransactionManager -

=head1 SYNOPSIS

  use DBIx::TransactionManager;

=head1 DESCRIPTION

DBIx::TransactionManager is

=head1 AUTHOR

Atsushi Kobayashi E<lt>nekokak _at_ gmail _dot_ comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
