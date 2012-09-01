# --8<--8<--8<--8<--
#
# Copyright (C) 2012 Smithsonian Astrophysical Observatory
#
# This file is part of Math::Histo::Grid
#
# Math::Histo::Grid is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -->8-->8-->8-->8--

use strict;
use warnings;

package Math::Histo::Grid::Linear;

our $VERSION = '0.01';


use Carp;

use Moo;
use MooX::Types::MooseLike::Numeric ':all';
use MooX::Types::MooseLike::Base ':all';

use Sub::Quote 'quote_sub';

use Math::BigFloat;

use POSIX 'floor';

use Data::Printer alias => 'pp';

use constant { LIMIT_HARD => 0, LIMIT_SOFT => 1 };

sub LimitState {
    sub {
        croak( "illegal state\n" )
          unless $_[0] == LIMIT_HARD || $_[0] == LIMIT_SOFT;
      }
}

use constant BigFloat => 'BigFloat';

sub gen_BigFloat {

    my ( $type ) = @_;

    return sub {
        local $Carp::Internal{'Math::Histo::Grid::Linear'} = 1;
        $type->( $_[0] );
        return Math::BigFloat->new( $_[0] );
    };

}

{
    # use state for perl > 5.10
    my $sub = sub {
        local $Carp::Internal{'Math::Histo::Grid::Linear'} = 1;

        return if is_Num( $_[0] );

        return
             if is_ArrayRef( $_[0] )
          && @{ $_[0] } == 2
          && is_Num( $_[0][0] )
          && is_PositiveOrZeroNum( $_[0][1] ) && $_[0][1] < 1;

        croak( "illegal value for align\n" );
    };

    sub Align { $sub }
}

# a number of attributes are stored as Math::BigFloat objects; they
# should be numified when read by the caller, else weird things may
# happen if they are used without knowledge.  For example,
#
#   $bigfloat * $scalar
#
# works, but
#
#   $scalar * $bigfloat
#
# doesn't, because * isn't overloaded for $scalar to know how to deal
# with $bigfloat
#
# So, the attributes which are BigFloats are prefixed with '_', but
# have init args without the '_'.  We construct readers for the
# unprefixed attribute names which perform the conversion back to scalars.

my @attr;

sub ihas { push @attr, [@_] }

ihas _min => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => Num,
    predicate => 1,
);

ihas _min_state => (
    is       => 'rwp',
    isa      => LimitState,
    default  => sub { LIMIT_SOFT },
    init_arg => undef,
);

ihas _max => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => Num,
    predicate => 1,
);

ihas _max_state => (
    is       => 'rwp',
    isa      => LimitState,
    default  => sub { LIMIT_SOFT },
    init_arg => undef,
);

ihas _center => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => Num,
    predicate => 1,
);

ihas _range_width => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => PositiveNum,
    predicate => 1,
    clearer   => 1,
    builder   => '_build_range_width',
    lazy      => 1,
);

ihas _binw => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => PositiveNum,
    predicate => 1,
);

ihas _nbins => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => PositiveInt,
    predicate => 1,
);

ihas data_min => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => Num,
    predicate => 1,
);

ihas data_max => (
    is        => 'rwp',
    coerce    => BigFloat,
    isa       => Num,
    predicate => 1,
);

ihas vary => (

    is     => 'ro',
    coerce => sub { lc $_[0] },
    isa    => sub { croak "illegal value\n" unless $_[0] =~ /^(nbins|binw)$/ },
    default => sub { 'binw' },
);

has _align => (
    is        => 'rwp',
    predicate => 'has_align',
    coerce    => sub {
        Align( $_[0] );
        is_ArrayRef( $_[0] ) ? [ @{ $_[0] } ] : [ $_[0], 0.5 ];
    },
    isa      => Align,
    init_arg => 'align'
);

sub align {

    return [ @{ $_[0]->_align } ] if $_[0]->has_align;

    return;
}

sub _build_range_width {
    croak "internal error; min or max not specified\n"
      unless $_[0]->has_min && $_[0]->has_max;
    $_[0]->_max - $_[0]->_min;
}


for my $attr ( @attr ) {

    my ( $name, %attr ) = @$attr;

    # force all predicates to have the same format; Moo creates different
    # formats if name begins with '_'

    ( my $base = $name ) =~ s/^_//;

    $attr{predicate} = "has_${base}"
      if exists $attr{predicate} && $attr{predicate} == 1;

    if ( exists $attr{coerce} && $attr{coerce} eq BigFloat ) {

        croak( "internal error: no isa w/ coerce BigFloat\n" )
          unless exists $attr{isa};

        $attr{coerce} = gen_BigFloat( $attr{isa} );

        $attr{init_arg} = $base;

        quote_sub __PACKAGE__ . "::$base", qq[ \$_[0]->$name->numify + 0];
    }

    has( $name, %attr );


}


sub BUILD {


    my $self = shift;

	$DB::single = 1;

    $self->_set__min_state( LIMIT_HARD )
      if $self->has_min;

    $self->_set__max_state( LIMIT_HARD )
      if $self->has_max;

    # First, figure out what chunk of the input data to work on;
    # i.e. figure out min and max

    $self->_data_bounds;

    # Second, calculate the number of bins, size and position
    $self->_bin_calc;

    # reset range_width as it may need to be recalculated
    $self->_clear_range_width;

    return;
}

# return the attributes which were set
sub has_attr {
    my ( $self, $attrs ) = @_;

    return grep { !!$_ } map { my $method = "has_$_"; $self->$method } @$attrs;
}

# return true if all of the passed attributes were set
sub _checkhas_attr {

    my ( $self, $attrs ) = @_;

    return 1 if !defined $attrs;

    return @$attrs == $self->has_attr( $attrs );

}

sub _croak_ifhas_excluded {

    my ( $self, $attrs ) = @_;

    return if !defined $attrs;

    my @bad;
    for my $attr ( @$attrs ) {

        $attr = [$attr] unless ref $attr;

        push @bad, join( ' and ', @$attr )
          if @$attr == $self->has_attr( $attr );
    }

    croak( "current set of parameters cannot include ", join( ', or ', @bad ) )
      if @bad;

}

# check if attributes are set.  takes an arrayref whose elements are
# either attribute names or arrayrefs of attribute names.  an element
# which is an arrayref is matched if only one of its attribute names match.

sub _croak_if_missing_required {

    my ( $self, $attrs ) = @_;

    return if !defined $attrs;

    my $has_required;
    for my $attr ( @$attrs ) {

        $attr = [$attr] unless ref $attr;

        my @matched = $self->has_attr( $attr );

        croak(
            "can only specify one of ",
            join( ' or ', @$attr ),
            " with current set of parameters\n"
        ) if @matched > 1;

        $has_required += @matched;
    }

    croak( "current set of parameters is incomplete\n" )
      unless $has_required == @$attrs;

}

our @data_bounds = (

    {
        has      => [ 'min',    'max' ],
        excludes => [ 'center', 'range_width', [ 'nbins', 'binw' ] ],
        requires => [ [ 'nbins', 'binw' ] ],
        sub      => sub {
            croak( "min must be < max\n" )
              if $_[0]->_min >= $_[0]->_max;
        },
    },


    {
        has      => [ 'min', 'range_width' ],
        excludes => [ 'center', [ 'nbins', 'binw' ] ],
        requires => [           [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__max( $_[0]->_min + $_[0]->_range_width );
        },
    },


    {
        has      => [ 'min',    'nbins', 'binw' ],
        excludes => [ 'center', 'range_width' ],
        sub      => sub {
            $_[0]->_set__max( $_[0]->_min + $_[0]->_nbins * $_[0]->_binw );
        },
    },


    {
        has      => ['min'],
        excludes => ['center'],
        requires => [ 'data_max', [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__max( $_[0]->data_max );
        },
    },

    {
        has      => [ 'max', 'range_width' ],
        excludes => [ 'center', [ 'nbins', 'binw' ] ],
        requires => [           [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__min( $_[0]->_max - $_[0]->_range_width );
        },
    },


    {
        has      => [ 'max',    'nbins', 'binw' ],
        excludes => [ 'center', 'range_width' ],
        sub      => sub {
            $_[0]->_set__min( $_[0]->_max - $_[0]->_nbins * $_[0]->_binw );
        },
    },


    {
        has      => ['max'],
        excludes => ['center'],
        requires => [ 'data_min', [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__min( $_[0]->data_min );
        },
    },


    {
        has      => [ 'center', 'range_width' ],
        excludes => [ 'min',    'max', [ 'nbins', 'binw' ] ],
        requires => [ [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__min( $_[0]->_center - $_[0]->_range_width / 2 );
            $_[0]->_set__max( $_[0]->_center + $_[0]->_range_width / 2 );
            $_[0]->_set__max_state( LIMIT_HARD );
            $_[0]->_set__min_state( LIMIT_HARD );
            $_[0]->_set__align( [ $_[0]->_center, 0.5 ] );
        },
    },

    {
        has => [ 'center', 'binw', 'nbins' ],
        sub => sub {
            $_[0]->_set__min( $_[0]->_center - $_[0]->_binw * $_[0]->_nbins / 2 );
            $_[0]->_set__max( $_[0]->_center + $_[0]->_binw * $_[0]->_nbins / 2 );
            $_[0]->_set__max_state( LIMIT_HARD );
            $_[0]->_set__min_state( LIMIT_HARD );
            $_[0]->_set__align( [ $_[0]->_center, 0.5 ] );
        },
    },

    {
        has      => ['center'],
        excludes => ['align'],
        requires => [ 'data_min', 'data_max', [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__range_width(
                List::Util::max(
                    $_[0]->_center - $_[0]->data_min,
                    $_[0]->data_max - $_[0]->_center
                ) );
            $_[0]->_set__min( $_[0]->_center - $_[0]->_range_width / 2 );
            $_[0]->_set__max( $_[0]->_center + $_[0]->_range_width / 2 );
            $_[0]->_set__align( [ $_[0]->_center, 0.5 ] );
        },
    },

    {
        has      => [ 'nbins',    'binw' ],
        requires => [ 'data_min', 'data_max' ],
        sub      => sub {
            my $center = ( $_[0]->data_min + $_[0]->data_max ) / 2;
            $_[0]->_set__min( $center - $_[0]->_binw * $_[0]->_nbins / 2 );
            $_[0]->_set__max( $center + $_[0]->_binw * $_[0]->_nbins / 2 );
            $_[0]->_set__max_state( LIMIT_HARD );
            $_[0]->_set__min_state( LIMIT_HARD );
        },

    },

    {
        requires => [ 'data_min', 'data_max', [ 'nbins', 'binw' ] ],
        sub      => sub {
            $_[0]->_set__min( $_[0]->data_min );
            $_[0]->_set__max( $_[0]->data_max );
            unless ( $_[0]->has_align || $_[0]->has_binw ) {

                $_[0]->_set__align( [
                        ( $_[0]->data_min + $_[0]->data_max ) / 2,
                        $_[0]->nbins % 2 ? 0.5 : 0,
                ] );
            }
        },

    },

);

sub _dispatch {

    my $self = shift;

    for my $pars ( @data_bounds ) {

        ## no critic
        next unless $self->_checkhas_attr( $pars->{has} );
        $self->_croak_ifhas_excluded( $pars->{excludes} );
        $self->_croak_if_missing_required( $pars->{requires} );

        $pars->{sub}->( $self );

        return 1;
    }

    return;
}

sub _data_bounds {

    my $self = shift;

    $self->_dispatch
      or die(
        "internal error; should have croaked by now on illegal parameters\n" );

    return;
}

sub _bin_calc {


    my $self = shift;

    die( "internal error; neither nbins or binw was specified\n" )
      unless $self->has_binw || $self->has_nbins;


    # if grid is aligned, hard limits are pretty much ignored
    if ( $self->has_align ) {

        my $vary
          = $self->has_binw && $self->has_nbins ? $self->vary
          : $self->has_binw ? 'nbins'
          :                   'binw';

        $vary eq 'nbins'
          ? $self->_vary_aligned_nbins
          : $self->_vary_aligned_binw;

    }

    # grid not aligned
    else {

        # both limits are hard
        if (   $self->_min_state eq LIMIT_HARD
            && $self->_max_state eq LIMIT_HARD )
        {

            if ( $self->has_binw && $self->has_nbins ) {

            }

            # if only bin width, then the limits are no longer hard,
            # as there may be a non-integral number of bins
            elsif ( $self->has_binw ) {

                $self->_vary_nbins;
                $self->_center_grid;
            }

            # has_nbins
            else {

                $self->_set__binw( $self->_range_width / $self->_nbins );
            }

        }

        # soft limits
        else {

            if ( $self->has_nbins ) {

                $self->_set__binw( $self->_range_width / $self->_nbins )
                  unless $self->has_binw;
            }

            else {

                $self->_vary_nbins;

            }

            if ( $self->_min_state eq LIMIT_HARD ) {

                $self->_set__max( $self->_min + $self->_nbins * $self->_binw );
            }

            else {

                $self->_set__min( $self->_max - $self->_nbins * $self->_binw );

            }

            $self->_clear_range_width;

        }

    }

    return;
}

sub _vary_nbins {

    my $self = shift;

    my $nbins = floor( $self->_range_width / $self->_binw );
    $nbins++ while ( $self->_binw * $nbins < $self->_range_width );

    $self->_set__nbins( $nbins );

}

sub _center_grid {

    my $self = shift;

    my $range_width = $self->_nbins * $self->_binw;
    $self->_set__min(
        $self->_min - ( $range_width - $self->_range_width ) / 2 );
    $self->_set__max( $self->_min + $range_width );
    $self->_clear_range_width;

    return;
}

sub _vary_aligned_nbins {

    my $self = shift;

    my %bnd = $self->_find_aligned_ibnd;
    $self->_set__min( $bnd{min} );
    $self->_set__max( $bnd{max} );
    $self->_set__nbins( $bnd{nbins} );
    $self->_clear_range_width;

}


# if bins are aligned and nbins is fixed, then the
# bin width must be varied so that the range is covered.
# there is no unique solution to this problem.

# A reasonable solution is to find the bin width such
# that the range is minimally covered.  One could also
# attempt to find "nice" bin widths.  The solution
# below provides the basis for both, but only the first
# is provided, as it is trivially achieved.

# Aligned single bin

# If bins of width W are center aligned at C, and should cover a range R (R0,R1),
# one can write the following inequality

#   D + W/2 - N * W < W - R

# where D is the distance from C to the closer of R0 and R1, and N is
# the number of bins which fit within D.  Essentially this inequality
# states that the the last virtual bin before the single bin which
# covers R must be close enough to the closest bound of R that the
# next "real" bin will cover R.
#
# Dividing by R and moving terms around provides a scale free
# inequality

#   D/R - f * ( N + 0.5 ) + 1 < 0

# where f = W/R

# The immediate problem is that N is a function of D/R and f.  Worse,
#
#   N = floor( D/R/f + 0.5 )
#
# which makes N non-continuous.

# The insight here is to note that we want to maximize the quantity
#
#   f * ( N + 0.5 )
#
# A given value of N will (because of the floor function) correspond
# to a number of values of f; we want to find the maximum value of
# f for a given N.  We have
#
#  f = D/R / (N - 0.5 )
#
# Because N is an integer, f(N) is really f( [N, N+1) ) with f(N) the
# maximum value.

# So, we can transform this problem into generating fmax for a range
# of N's, and if the inequality holds for those fmax, they are valid
# bin widths.
#
# What is a valid set for N?  The mininum is 1, the maximum is set
# by the smallest valid bin width.  In this case there's only one
# bin, so the smallest possible width is R.  So,
#
#  Nmax = D/R

# For finding valid values of f, this is now a sequential search
# through N looking for the first f which solves the inequality.
# That f is the maximum f for the given N, so there is actually
# a range, (f-,f] for which the inequality is valid.  One can
# mine that range for a "nice" value of W, or move on to the
# next f which solves the inequality and try there.

# for bins which are edge, rather than center, aligned,
#
#  D - N * W < W - R
#  D/R - N * f < f - 1
#  D/r - f * ( N + 1 ) + 1 < 0
#
#  N = floor( D/R/f )
#  f = D/R/N

# the equations can be extended to n bins and to arbitrary
# alignment.
# nbins = number of bins
# offset = relative offset of the fiducial point within a bin
#          i haven't figured out the sign convention...

#  N = floor( D/R/f + offset )
#  f = D/R/ ( N - offset )
#  D/R - f * ( n + nbins - offset ) + 1 < 0

# this code will probably not work if the fiducial point is within the
# bin, D/R < 1

# find the "minimum" binwidth which obeys an alignment condition.
# there are technically smaller bins, but that optimization must wait
# for more tuits.

sub _optimize_aligned_binw {

    my ( $self ) = @_;

    my ( $align_val, $align_offset ) = @{ $self->align };

   # closest and furthest distances from the alignment value to the range bounds

    # positive distance indicates that lower fid bound is furthest
    # from closest range bound (unless fid val is in range, which is
    # handled separately.

    my @dist = ( $self->_min - $align_val, $align_val - $self->_max );

    my @abs_dist = map { abs( $_ ) } @dist;

    my $min_idx = $abs_dist[0] > $abs_dist[1] || 0;
    my $min_dist = $abs_dist[$min_idx];

    # make sure to choose fid bin edge furthest from the closest range bound
    my $offset = $dist[$min_idx] < 0 ? 1 - $align_offset : $align_offset;

    my $DR = $min_dist / $self->range_width;

    my $f;
    my $N;
  FOUND: {

        foreach ( reverse 1 .. floor( $DR * $self->nbins )+1 ) {

	        $N = $_;

            $f = $DR / ( $N - $offset );

            my $ineq = $DR - $f * ( $N + $self->nbins - $offset ) + 1;

            last FOUND if $ineq < 0;

        }

        croak(
            "internal error; unable to find bin width for aligned bin\n"
        );

    }

    # N is now determined; find $f such that $ineq = 0;
    $f = ( $DR + 1 ) / ( $N + $self->nbins - $offset );

    return $f * $self->range_width;

}

sub _find_minimum_aligned_binw {

    my $self = shift;

    my ( $align_val, $offset ) = @{ $self->align };

    if ( $self->nbins == 1 ) {

        # only impossible case is if it's a single bin and the
        # fiducial point is at the edge of a bin and the fiducial
        # value is in the range.  no way to fit a single bin in there.
        if (   ( $offset == 0 || $offset == 1 )
            && $self->_min < $align_val
            && $align_val < $self->_max )
        {

            croak(
                "cannot vary binwidth when nbins = 1, alignment offset = $offset, ",
                $self->_min, " < $align_val < ", $self->_max, "\n"
            );

        }

    }

    # the minimum bin width is R/$nbins; if either of the bounds of
    # the virtual fiducial bin with minimum width lies inside of the
    # range, then the fiducial point is in one of the actual bins.

    my $binw    = $self->_range_width / $self->nbins;
    my $fid_min = $align_val - $binw * $offset;
    my $fid_max = $fid_min + $binw;

    my $cmp = join( '',
        map { $_ || 0 } $fid_min < $self->_min,
        $fid_min < $self->_max,
        $fid_max < $self->_min,
        $fid_max < $self->_max );

    if    ( '1101' eq 'cmp' ) { $binw = ( $self->_max - $align_val ) / ( $self->nbins - $offset ); }

    elsif ( '0111' eq 'cmp' ) { $binw = ( $align_val - $self->_min ) / ( $self->nbins - 1 + $offset ); }

    else                      { $binw = $self->_optimize_aligned_binw; }

    return $binw;
}

sub _vary_aligned_binw {

    my $self = shift;

    $self->_set__binw( $self->_range_width / $self->_nbins )
      unless $self->has_binw;

    my %bnd = $self->_find_aligned_ibnd;

    # one can only hope that the range is exactly covered...
    return
      if $bnd{min} == $self->_min && $bnd{max} == $self->_max;


    # this finds the "minimum" bin width necessary.  not the
    # prettiest. see below.
    $self->_set__binw( $self->_find_minimum_aligned_binw );



    # the rest of these comments are a first cut at generating "nice"
    # bin widths.   alas it must wait for more tuits.


    # for nbins == 1 or 2, the subset of valid bin widths is not
    # a contiguous set, use _optimize_aligned_binw to determine the
    # contiguous subsets.

    # for nbins > 2, there is a continuous selection, so
    # things are easier, and one can narrow things down quickly:

    # If N bins exactly cover R, then
    #   W = R / N
    # is the minimum bin width

    # if N bins extends beyond R, then R may be covered by fewer than
    # N bins.  The fewest bins that can cover R are N-2 + epsilon, if
    # the bins are centered upon R and W is expanded until the inner
    # boundaries of the outermost two bins barely lie within R. Thus
    #   W = R / ( N - 2)
    # is the maximum bin width

    # So, need to find a "nice" number between R / N and R / ( N - 2 )

    # "nice" numbers have divisors of 2^n, 5, 10


    %bnd = $self->_find_aligned_ibnd;
    $self->_set__min( $bnd{min} );
    $self->_set__max( $bnd{max} );
    $self->_clear_range_width;

    return;
}

sub pbnd {

    my %nbnd = map { ref( $_ ) =~ /Big/ ? $_->numify + 0 : $_ } @_;
    pp %nbnd;
}

sub _find_ibnd {

    my ( $self, $offset ) = @_;

    # avoid rounding errors by not rounding.

    # adjust the lower bin.  make sure we cover min and
    # that there aren't extra bins

    my $imin = floor( ( $self->_min - $offset ) / $self->_binw );
    $imin-- while $offset + $self->_binw * $imin > $self->_min;
    $imin++ while $offset + $self->_binw * ( $imin + 1 ) < $self->_min;

    # ditto for the upper bin
    my $imax = floor( ( $self->_max - $offset ) / $self->_binw );
    $imax++ while $offset + $self->_binw * $imax < $self->_max;
    $imax-- while $offset + $self->_binw * ( $imax - 1 ) > $self->_max;

    my %bnd = (
        imin  => $imin,
        imax  => $imax,
        min   => $offset + $self->_binw * $imin,
        max   => $offset + $self->_binw * $imax,
        binw  => $self->_binw,
        nbins => $imax - $imin,
    );

    $bnd{dmax} = $bnd{max} - $self->_max;
    $bnd{dmin} = $self->_min - $bnd{min};

    return %bnd;

}

sub _find_aligned_ibnd {

    my $self = shift;

    return $self->_find_ibnd( $self->_align_offset );
}

# correct align so it is at the edge of a bin
sub _align_offset {

    my $self = shift;

    return $self->_align->[0] - $self->_binw * $self->_align->[1];
}

1;

__END__

=head1 NAME

Math::Histo::Bin::Linear - linear histogram binning

=head1 SYNOPSIS

    use Math::Histo::Grid::Linear;

  $bin = Math::Histo::Bin::Linear->new( %options );

=head1 DESCRIPTION

B<Math::Histo::Bin::Linear> constructs a self-consistent specification
for grouping data in contiguous linear bins.

It can handle a range of specificity in the input binning scheme. For example,

=over

=item *

The caller may specify the number of bins, the size of the bins, both, or none

=item *

Bins may be aligned so that a bin edge or the center of a bin falls
upon a specified value.

=item *

The caller may specify a data range as either extrema or as a center and range_width.

=back


=head2 Bin specifications

The two aspects of creating the binning scheme are

=over

=item 1

Determining the range of data to bin.  The range may be explicitly
specified or derived from data limits.  Range extrema derived from
data are "softer" than those explicitly specified, in that they may be
relaxed to better fit a grid onto the range.

=item 2

Fixing a grid onto the range.  This may involve adjusting bin widths
or the number of bins so that the range is fully covered by the grid.
In addition, a grid may be anchored so that the beginning and ending
bin edges fall upon certain values or so that bins are aligned so that
a specific value falls on an edge or center of a bin.

=back

=head3 Range specification

There are multiple ways to specify the range.  Depending on how the
grid is specified the final range may be slightly different from that
requested (e.g., if a bin width is specified there may not be an
integral number of bins in the range).

The acceptable parameter combinations and their resulting ranges are:

=over

=item I<min>, I<max> => [ I<min>, I<max> )

=item I<min>, I<range_width> => [ I<min>, I<min> + I<range_width> )

=item I<max>, I<range_width> => [ I<max> - I<range_width>, I<max> )

=item I<center>, I<range_width> => [ I<center> - I<range_width> / 2, I<center> + I<range_width> / 2 )

The lower and upper edges of the grid are anchored to the range
extrema if I<nbins> is specified.

=item I<min>, I<data_max> => [ I<min>, I<data_max> ).

The lower most bin's lower edge is anchored to I<min> if I<nbins> is
specified.

=item I<max>, I<data_min> => [ I<data_min>, I<max> ).

The upper most bin's upper edge is anchored to I<max> if I<nbins> is
specified.

=item I<center>, I<nbins>, I<binw> => [ I<center> - I<nbins> * I<binw> / 2, I<center> + I<nbins> * I<binw> / 2 )

=item I<min>, I<nbins>, I<binw> => [ I<min>, I<min> + I<nbins> * I<binw> )

=item I<max>, I<nbins>, I<binw> => [ I<max> - I<nbins> * I<binw>, I<max> )

The lower and upper edges of the grid are anchored to the range
extrema

=back

If I<min> and I<max> are not specified I<data_min> and
I<data_max> must be specified and will result in a (soft) range of [ I<data_min>, I<data_max> ).

=head3 Grid specification

The size, number, and location of the bins is determined by the
following combination of parameters (see L</Range specification> for specific interactions
of I<nbins> and I<binw> with range setting)

=over

=item I<nbins>

The number of bins.  If neither I<nbins> nor I<binw> are specified, I<nbins> defaults to 100.

=item I<binw>

The bin width.

=item I<align>

This specifies an optional grid alignment. It specifies a fiducial location within the bin
and a value which must fall upon the fiducial location if the grid were
extended to that value.

The alignment is specified as either a value or as an arrayref whose first element is the
location, the second the value:

  value
  [ edge => value ]
  [ center => value ]

In the first form the fiducial location defaults to C<edge>.

=item I<center>

Specify the center of the grid. If specified with I<nbins> B<or>
I<binw> and B<nothing> else, this implicitly specifies an C<align>
attribute of

  [ center => ( I<data_min> + I<data_max> ) / 2 ]

=back

=head3 Range Adjustment

The range extrema may be adjusted from those specified if a grid
alignment is specified via I<align> (either explicitly or implicitly)
or a bin width is specified which would lead to the extrema not
falling upon bin edges.

The following scenarios are possible:

=over

=item I<center> is specified with no hard limits

The grid is extended about the specified center. The specified center value falls on
the center of a bin unless I<align> is used to specify another alignment.

=back


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=over

=item new

  $bin = Math::Histo::Bin::Linear->new( %attr );

Construct a linear binning specification.  The available attributes are:

=over

=item min

=item max

=item center

=item range_width

=item binw

=item nbins

=item data_bounds

=item align

=back

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

Math::Histo::Grid::Linear requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-math-histo-grid-linear@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Math-Histo-Grid>.

=head1 SEE ALSO

=for author to fill in:
	Any other resources (e.g., modules or files) that are related.


=head1 VERSION

Version 0.01

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012 The Smithsonian Astrophysical Observatory

Math::Histo::Grid::Linear is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 AUTHOR

Diab Jerius  E<lt>djerius@cpan.orgE<gt>
