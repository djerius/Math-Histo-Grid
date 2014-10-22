#!perl


package Math::Histo::Grid::Base;

use strict;
use warnings;

use Carp;

use Moo;
use MooX::StrictConstructor;

use POSIX ();

use Types::Standard qw[ ArrayRef InstanceOf Bool Object Num ];
use Types::Common::Numeric qw[ PositiveInt ];
use Type::Params qw[ compile ];

use List::MoreUtils qw[ pairwise ];
use Safe::Isa;

use overload '+' => \&merge;

has oob => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

# lb & ub are for public consumption; not used internally
has lb => (
    is       => 'rwp',
    lazy     => 1,
    isa      => ArrayRef[ Num ],
    init_arg => undef,
    default  => sub { shift->_build_bounds->lb },
);

has ub => (
    is       => 'rwp',
    lazy     => 1,
    isa      => ArrayRef[ Num ],
    init_arg => undef,
    default  => sub { shift->_build_bounds->ub },
);

# actual bin edges used in binning; subclass should define
# _build_bin_edges to generate it.
has bin_edges => (
    is   => 'lazy',
    isa  => ArrayRef[ Num ],
);

# number of *edges*
has nedges => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    isa      => PositiveInt,
    default  => sub { scalar @{shift->bin_edges } },
);


# number of *bins*, not *edges*
has nbins => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    isa      => PositiveInt,
    default  => sub { $#{ shift->bin_edges } },
);

has binw => (
    is       => 'lazy',
    isa      => ArrayRef[ Num ],
    init_arg => undef,
    builder  => sub {
	[ pairwise { $a - $b } @{ $_[0]->ub }, @{ $_[0]->lb } ]
    },
);

has min => (
    is       => 'rwp',
    is       => 'lazy',
    isa      => Num,
    init_arg => undef,
    builder  => sub { shift->bin_edges->[0] },
);

has max => (
    is       => 'rwp',
    is       => 'lazy',
    isa      => Num,
    init_arg => undef,
    builder  => sub { shift->bin_edges->[-1] },
);

sub _build_bounds {

    my $self = shift;

    my ( $lb, $ub );

    my $edges = $self->bin_edges;
    my @lb = @{$edges}[ 0..$self->nbins-1 ];
    my @ub = @{$edges}[ 1..$self->nbins   ];

    if ( $self->oob ) {

        require POSIX;

	unshift @lb, - POSIX::DBL_MAX;
	push    @ub,   POSIX::DBL_MAX;
    }

    $self->_set_lb( \@lb );
    $self->_set_ub( \@ub );

    return $self;
}


my ( $merge_check );
BEGIN {
    $merge_check = compile( Object, InstanceOf [ __PACKAGE__, ], );
}

sub merge {

    my ( $self, $other ) = $merge_check->( @_ );

    # check that bounds don't overlap

    my ( $s_min, $s_max )
      = ( $self->bin_edges->[ 0 ], $self->bin_edges->[ -1 ] );

    my ( $o_min, $o_max )
      = ( $other->bin_edges->[ 0 ], $other->bin_edges->[ -1 ] );

    my @bin_edges;

    # grids don't share an edge
    if ( $s_min > $o_max ) {

        @bin_edges = ( @{ $other->bin_edges }, @{ $self->bin_edges } );

    }
    elsif ( $o_min > $s_max ) {

        @bin_edges = ( @{ $self->bin_edges }, @{ $other->bin_edges } );

    }

    # grids share an edge
    elsif ( $s_min == $o_max ) {

        @bin_edges = @{ $other->bin_edges };
	pop @bin_edges;
	push @bin_edges, @{ $self->bin_edges };

    }

    elsif ( $o_min == $s_max ) {

        @bin_edges = @{ $self->bin_edges };
	pop @bin_edges;
	push @bin_edges, @{ $other->bin_edges };

    }

    else {

        croak( "cannot merge overlapping bin grids\n" );
    }

    return __PACKAGE__->new(
        bin_edges => \@bin_edges,
        ( $self->oob && $other->oob ? ( oob => 1 ) : () ) );
}

1;
