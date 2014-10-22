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
use Math::BigFloat;

use Math::Histo::Grid::Constants
    -linear => { -strip_tag => 1 },
    -limit ;
use Math::Histo::Grid::Types -all;

use Moo;

extends 'Math::Histo::Grid::Base';

my $precision = -12;


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
# So, the attributes which are unique BigFloats are prefixed with '_', but
# have init args without the '_'.  We construct readers for the
# unprefixed attribute names which perform the conversion back to scalars.

has _min => (
    is       => 'rwp',
    isa      => BigNum,
    init_arg => 'min',
    coerce   => 1,
);

has _min_state => (
    is       => 'rwp',
    isa      => LimitState,
    default  => sub { LIMIT_SOFT },
    init_arg => undef,
);

has _max => (
    is       => 'rwp',
    isa      => BigNum,
    init_arg => 'max',
    coerce   => 1,
);

has _max_state => (
    is       => 'rwp',
    isa      => LimitState,
    default  => sub { LIMIT_SOFT },
    init_arg => undef,
);

has _center => (
    is       => 'rwp',
    isa      => BigNum,
    init_arg => 'center',
    coerce   => 1,
);

has _range_width => (
    is       => 'rwp',
    isa      => BigPositiveNum,
    init_arg => 'range_width',
    coerce   => 1,
);

has _binw => (
    is       => 'rwp',
    isa      => BigPositiveNum,
    coerce   => 1,
    init_arg => 'binw',
);

has _nbins => (
    is       => 'rwp',
    isa      => BigPositiveInt,
    coerce   => 1,
    init_arg => 'nbins',
);

has _soft_min => (
    is     => 'rwp',
    isa    => BigNum,
    coerce => 1,
    init_arg => 'soft_min',
);

has _soft_max => (
    is     => 'rwp',
    isa    => BigNum,
    coerce => 1,
    init_arg => 'soft_max',
);

has vary => (
    is     => 'ro',
    coerce => sub { lc $_[0] },
    isa    => sub { croak "illegal value\n" unless $_[0] =~ /^(nbins|binw)$/ },
    default => sub { 'binw' },
);

has _align => (
    is       => 'rwp',
    isa      => Alignment,
    coerce   => 1,
    init_arg => 'align'
);

sub align {

    return defined $_[0]->_align ? [ @{ $_[0]->_align } ] : undef;
}

sub BUILD {

    my $self = shift;

    # figure out what chunk of the input data to work on. This also checks that
    # the input parameters are consistent.

    $self->_data_bounds;

    return;
}

sub _build_bin_edges {

    my $self = shift;

    # Second, calculate the number of bins, size and position
    $self->_bin_calc;

    return [ map { ($self->_min + $self->_binw * $_)->numify } 0..$self->_nbins ] ;
}

my @dispatch = (

    [
        ( MIN | MAX | NBINS         ),
        ( MIN | MAX | BINW          ),
        ( MIN | MAX | NBINS | ALIGN ),
        ( MIN | MAX | BINW  | ALIGN ),
        sub {
            croak( "min must be < max\n" )
              if $_->_min >= $_->_max;

            $_->_set__min_state( LIMIT_HARD );
            $_->_set__max_state( LIMIT_HARD );

        },
    ],

    [
        ( MIN | RANGE_WIDTH | NBINS         ),
        ( MIN | RANGE_WIDTH | BINW          ),
        ( MIN | RANGE_WIDTH | NBINS | ALIGN ),
        ( MIN | RANGE_WIDTH | BINW  | ALIGN ),
        sub {
            $_->_set__min_state( LIMIT_HARD );
            $_->_set__max( $_->_min + $_->_range_width );
        },
    ],

    [
        ( MIN | NBINS | BINW         ),
        ( MIN | NBINS | BINW | ALIGN ),
        sub {
            $_->_set__min_state( LIMIT_HARD );
            $_->_set__max( $_->_min + $_->_binw * $_->_nbins );
        },
    ],

    [
        ( MIN | SOFT_MAX | NBINS         ),
        ( MIN | SOFT_MAX | BINW          ),
        ( MIN | SOFT_MAX | NBINS | ALIGN ),
        ( MIN | SOFT_MAX | BINW  | ALIGN ),
        sub {
            $_->_set__min_state( LIMIT_HARD );
            $_->_set__max( $_->_soft_max );
        },

    ],

    [
        ( MAX | RANGE_WIDTH | NBINS         ),
        ( MAX | RANGE_WIDTH | BINW          ),
        ( MAX | RANGE_WIDTH | NBINS | ALIGN ),
        ( MAX | RANGE_WIDTH | BINW  | ALIGN ),
        sub {
            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min( $_->_max - $_->_range_width );
        },
    ],

    [
        ( MAX | NBINS | BINW         ),
        ( MAX | NBINS | BINW | ALIGN ),
        sub {
            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min( $_->_max - $_->_binw * $_->_nbins );
        },

    ],

    [
        ( MAX | SOFT_MIN | NBINS         ),
        ( MAX | SOFT_MIN | BINW          ),
        ( MAX | SOFT_MIN | NBINS | ALIGN ),
        ( MAX | SOFT_MIN | BINW  | ALIGN ),
        sub {
            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min( $_->_soft_min );
        },
    ],

    [
        ( CENTER | RANGE_WIDTH | NBINS ),

        sub {

            $_->_set__min( $_->_center - $_->_range_width / 2 );
            $_->_set__max( $_->_center + $_->_range_width / 2 );

            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min_state( LIMIT_HARD );

	    # align on bin edge if even number, else bin center
            $_->_set__align( [ $_->_center, ($_->_nbins % 2) ? 0.5 : 0 ] );
        },
    ],

    [
        ( CENTER | RANGE_WIDTH | BINW ),

        sub {

            $_->_set__min( $_->_center - $_->_range_width / 2 );
            $_->_set__max( $_->_center + $_->_range_width / 2 );

            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min_state( LIMIT_HARD );

            $_->_set__align( [ $_->_center, 0.5 ] );
        },
    ],

    [
        ( CENTER | BINW | NBINS ),
        sub {
	    my $range_half_width = $_->_binw * $_->_nbins / 2;

            $_ ->_set__min( $_->_center -  $range_half_width);
            $_ ->_set__max( $_->_center +  $range_half_width);

            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min_state( LIMIT_HARD );

	    # align on bin edge if even number, else bin center
            $_->_set__align( [ $_->_center, ($_->_nbins % 2) ? 0.5 : 0 ] );
        },
    ],

    [
        ( CENTER | SOFT_MIN | SOFT_MAX | NBINS ),
        sub {
	    my $range_half_width =
                List::Util::max(
                    $_->_center - $_->_soft_min,
                    $_->_soft_max - $_->_center
                );

            $_->_set__min( $_->_center - $range_half_width );
            $_->_set__max( $_->_center + $range_half_width );

	    # align on bin edge if even number, else bin center
            $_->_set__align( [ $_->_center, ($_->_nbins % 2) ? 0.5 : 0 ] );
        },
    ],

    [
        ( CENTER | SOFT_MIN | SOFT_MAX | BINW ),
        sub {
	    my $range_half_width =
                List::Util::max(
                    $_->_center - $_->_soft_min,
                    $_->_soft_max - $_->_center
                );

            $_->_set__min( $_->_center - $range_half_width );
            $_->_set__max( $_->_center + $range_half_width );

            $_->_set__align( [ $_->_center, 0.5 ] );
        },
    ],

    [
        ( SOFT_MIN | SOFT_MAX | NBINS | BINW         ),
        ( SOFT_MIN | SOFT_MAX | NBINS | BINW | ALIGN ),
        sub {

            my $center = ( $_->_soft_min + $_->_soft_max ) / 2;
	    my $range_half_width = $_->_binw * $_->_nbins / 2;

            $_->_set__min( $center - $range_half_width );
            $_->_set__max( $center + $range_half_width );

            $_->_set__max_state( LIMIT_HARD );
            $_->_set__min_state( LIMIT_HARD );
        },

    ],

    [
        ( SOFT_MIN | SOFT_MAX | NBINS         ),
        ( SOFT_MIN | SOFT_MAX | BINW          ),
        ( SOFT_MIN | SOFT_MAX | NBINS | ALIGN ),
        ( SOFT_MIN | SOFT_MAX | BINW  | ALIGN ),
        sub {

            $_->_set__min( $_->_soft_min );
            $_->_set__max( $_->_soft_max );

            unless ( defined $_->_align || defined $_->_binw ) {

                $_->_set__align( [ ( $_->_soft_min + $_->_soft_max ) / 2,
				       $_->_nbins % 2 ? 0.5 : 0
				    ]
				  );
            }
        },
    ],


);

my %dispatch = map {
    my $sub = pop @$_;
    map { $_ => $sub } @$_;
} @dispatch;

sub _data_bounds {

    my $self = shift;

    my $attrs
      = ( defined $self->_min         ? MIN         : 0 )
      | ( defined $self->_max         ? MAX         : 0 )
      | ( defined $self->_nbins       ? NBINS       : 0 )
      | ( defined $self->_binw        ? BINW        : 0 )
      | ( defined $self->_range_width ? RANGE_WIDTH : 0 )
      | ( defined $self->_center      ? CENTER      : 0 )
      | ( defined $self->_align       ? ALIGN       : 0 )
      | ( defined $self->_soft_min    ? SOFT_MIN    : 0 )
      | ( defined $self->_soft_max    ? SOFT_MAX    : 0 );

    my $sub = $dispatch{$attrs};

    croak( "binning parameters are either over- or under-specified\n" )
      if ! defined $sub;

    local $_ = $self;
    $sub->();

    return;
}

sub _range {

    my $self = shift;

    croak "internal error; min or max not specified\n"
          unless defined $self->_min && defined $self->_max;
    return $self->_max - $self->_min;
}

sub _bin_calc {


    my $self = shift;

    die( "internal error; neither nbins or binw was specified\n" )
      unless defined $self->_binw || defined $self->_nbins;


    # if grid is aligned, hard limits are pretty much ignored
    if ( defined $self->_align ) {

        my $vary
          = defined $self->_binw && defined $self->_nbins ? $self->vary
          : defined $self->_binw                          ? 'nbins'
          :                                                 'binw';

        $vary eq 'nbins'
          ? $self->_vary_aligned_nbins
          : $self->_vary_aligned_binw;

    }

    # grid not aligned
    else {

        # both limits are hard
        if (   $self->_min_state == LIMIT_HARD
            && $self->_max_state == LIMIT_HARD )
        {

            if ( defined $self->_binw && defined $self->_nbins ) {
                # nothing

            }

            # if only bin width, then the limits are no longer hard,
            # as there may be a non-integral number of bins
            elsif ( defined $self->_binw ) {

                $self->_vary_nbins;
                $self->_center_grid;
            }

            # has_nbins
            else {

                $self->_set__binw( $self->_range / $self->_nbins );
            }

        }

        # soft limits
        else {

            if ( defined $self->_nbins ) {

                $self->_set__binw( $self->_range / $self->_nbins )
                  unless defined $self->_binw;
            }

            else {

                $self->_vary_nbins;

            }

            if ( $self->_min_state == LIMIT_HARD ) {

                $self->_set__max( $self->_min + $self->_binw * $self->_nbins  );
            }

            else {

                $self->_set__min( $self->_max - $self->_binw * $self->_nbins );

            }

        }

    }

    return;
}

# fixed bin width; determine number of bins required to span the given
# range
sub _vary_nbins {

    my $self = shift;

    my $nbins =  ( $self->_range / $self->_binw )->bfloor;
    $nbins++ while ( $self->_binw * $nbins < $self->_range );

    $self->_set__nbins( $nbins );

}

# given nbins & binw, center the bins on the current range and reset the
# min and max limits
sub _center_grid {

    my $self = shift;

    my $range_width =  $self->_binw * $self->_nbins;
    $self->_set__min(
        $self->_min - ( $range_width - $self->_range ) / 2 );
    $self->_set__max( $self->_min + $range_width );

    return;
}

sub _vary_aligned_nbins {

    my $self = shift;

    my %bnd = $self->_find_aligned_ibnd;
    $self->_set__min( $bnd{min} );
    $self->_set__max( $bnd{max} );
    $self->_set__nbins( $bnd{nbins} );

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

#  N = floor( D/R/f + offset )
#  f = D/R/ ( N - offset )
#  D/R - f * ( n + nbins - offset ) + 1 < 0

# this code will probably not work if the fiducial point is within the
# bin, D/R < 1

# find the "minimum" binwidth which obeys an alignment condition.

sub _optimize_aligned_binw {

    my ( $self ) = @_;

    my ( $align_val, $align_offset ) = @{ $self->_align };

   # closest and furthest distances from the alignment value to the range bounds

    # positive distance indicates that lower fid bound is furthest
    # from closest range bound (unless fid val is in range, which is
    # handled separately.

    my @dist = ( $self->_min - $align_val, $self->_max - $align_val );

    my @abs_dist = map { $_->copy->babs } @dist;

    my $min_idx  = $abs_dist[0] > $abs_dist[1] || 0;
    my $min_dist = $abs_dist[$min_idx];
    my $max_dist = $abs_dist[ 1 - $min_idx ];

    # make sure to choose fid bin edge furthest from the closest range bound
    my $offset = $dist[$min_idx] < 0 ? Math::BigFloat->new( 1 ) - $align_offset : $align_offset;

    my $DR = $min_dist / $self->_range;

    my $f;
    my %bnd;
  FOUND: {

        for my $N ( reverse 1 .. ( ( $DR * $self->_nbins )->bfloor + 1 ) ) {

	    # mind operator overloading so we always get a BigFloat
            $f = ( $DR + 1 ) / ( - $offset + $N + $self->_nbins  );

            %bnd = $self->_find_aligned_ibnd( $self->_range * $f );

            #	    $bnd{dMin} = $self->_min - $bnd{min};
            #	    $bnd{dMax} = $self->_max - $bnd{max};

            #	    ph( N => $N, %bnd );

            last FOUND
              if $f * $self->_nbins > 1
              && ( $self->_min - $bnd{min} )->bfround( $precision ) >= 0
              && ( $self->_max - $bnd{max} )->bfround( $precision ) <= 0;
        }

        croak( "_optimize_aligned_binw: error optimizing bin width\n" )

    }

    return $self->_range * $f;

}

# alignment value is inside of range
sub _optimize_aligned_internal_binw {

    my $self = shift;

    my ( $align_val, $align_offset ) = @{ $self->_align };

    my $g0 = ( $align_val - $self->_min ) / $self->_range  * $self->_nbins - $align_offset;
    my $n0g = $g0->bfloor;
    my $n1g = $n0g + 1;

    my @bw = sort { $a <=> $b } ( ( $align_val - $self->_min ) / ( $align_offset + $n0g ),
				  ( $self->_max - $align_val ) / ( - ( $align_offset + $n1g )  + $self->_nbins  ),
				);
    my $binw;

    my $fail = 1;

    for ( 0, 1  ) {

	$binw = $bw[$_];

	next if $binw <= 0;

	my $nn0 = 0;
	$nn0-- while $align_val - $self->_min > $binw * ( $align_offset - $nn0 );

	my $r0 = $align_val - $binw * ( $align_offset - $nn0 );
	my $r1 = $r0 + $binw * $self->_nbins;

	my $dr1 = $self->_max - $r1;
	my $dr0 = $r0 - $self->_min;

	# tweak the bins if we get hit by round-off so we cover the
	# range. Since the roundoff amount is around 1 ULP, overdo it
	# by adding it to each bin (makes no sense to divide it by nbins!)

	unless ( $fail = $dr1 > 4e-15 || $dr0 > 4e-15 ) {
	    my $dr = $dr1 > $dr0 ? $dr1 : $dr0;
	    $binw += $dr if $dr > 0;
	    last;
	}

    }

    croak( "_optimize_aligned_internal_binw: error optimizing bin width\n" )
      if $fail;

    return $binw;
}



sub _find_minimum_aligned_binw {

    my $self = shift;

    my ( $align_val, $offset ) = @{ $self->_align };

    if ( $self->_nbins == 1 ) {

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

    my $binw    = $self->_range / $self->_nbins;
    my $fid_min = $align_val - $binw * $offset;
    my $fid_max = $fid_min + $binw;

    my $cmp = join( '',
        map { $_ || 0 } $fid_min < $self->_min,
        $fid_min < $self->_max,
        $fid_max < $self->_min,
        $fid_max < $self->_max );

    # left of fid bin is outside of range
    if ( '1101' eq $cmp ) {
        $binw = ( $self->_max - $align_val ) / $offset->copy->bneg->badd( $self->_nbins );
    }

    # right of fid bin is outside of range
    elsif ( '0100' eq $cmp ) {
          $binw = ( $align_val - $self->_min ) / 
	    $offset->copy->badd( $self->_nbins - 1 );
    }

    # fid bin is inside of range
    elsif ( '0101' eq $cmp ) { $binw = $self->_optimize_aligned_internal_binw; }

    else { $binw = $self->_optimize_aligned_binw; }

    return $binw;
}

sub _vary_aligned_binw {

      my $self = shift;

      $self->_set__binw( $self->_range / $self->_nbins )
        unless defined $self->_binw;

      my %bnd = $self->_find_aligned_ibnd;

      # one can only hope that the range is exactly covered...
      return
           if $bnd{min} == $self->_min
        && $bnd{max} == $self->_max
        && $bnd{nbins} == $self->_nbins;


      # this finds the "minimum" bin width necessary.  not the
      # prettiest. see below.
      $self->_set__binw( $self->_find_minimum_aligned_binw );


      #####################################################################
      #####################################################################

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

      #####################################################################
      #####################################################################


      # round off is a pain in the arse

      my ( $min, $max );

      my $imin
        = ( ( $self->_min - $self->_align_offset ) / $self->_binw )->bfloor;
      $imin-- while $self->_align_offset + $self->_binw * $imin > $self->_min;

      for( ; ; $imin++ ) {
          $min = $self->_align_offset + $self->_binw * $imin;
          $max = $min +  $self->_binw * $self->_nbins;

	  last if
	    ( $self->_max - $max )->bfround( $precision ) <= 0;
      }

      if (   ( $min - $self->_min )->bfround( $precision ) > 0
          || ( $max - $self->_max )->bfround( $precision ) < 0 )
      {

          croak( "_vary_aligned_binwith: error optimizing bin width\n" );
      }

      $self->_set__min( $min );
      $self->_set__max( $max );

      return;
}

# determine the minimum set of bins with width $binw, aligned on $offset
# which covers the range (_min, _max).
sub _find_ibnd {

      my ( $self, $offset, $binw ) = @_;

      $binw = Math::BigFloat->new( defined $binw ? $binw : $self->_binw );
      $offset = Math::BigFloat->new( $offset );

      # avoid rounding errors by not rounding.

      # adjust the lower bin.  make sure we cover min and
      # that there aren't extra bins

      my $imin = ( ( $self->_min - $offset ) / $binw )->bfloor;
      $imin-- while $offset + $binw * $imin > $self->_min;
      $imin++ while $offset + $binw * ( $imin + 1 ) < $self->_min;

      # ditto for the upper bin
      my $imax = ( ( $self->_max - $offset ) / $binw )->bfloor;
      $imax++ while $offset + $binw * $imax < $self->_max;
      $imax-- while $offset + $binw * ( $imax - 1 ) > $self->_max;

      my %bnd = (
          imin  => $imin,
          imax  => $imax,
          min   => $offset + $binw * $imin,
          max   => $offset + $binw * $imax,
          binw  => $binw,
          nbins => $imax - $imin,
      );

      $bnd{dmax} = $bnd{max} - $self->_max;
      $bnd{dmin} = $self->_min - $bnd{min};

      return %bnd;

}

sub _find_aligned_ibnd {

      my $self = shift;

      return $self->_find_ibnd( $self->_align_offset, @_ );
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

B<Math::Histo::Bin::Linear> constructs a set of contiguous equal width
bins.  It can handle a variety of ways of specifying the binning
scheme, including aligning bins on a particular value.

=head2 Range and bin specification

Range extrema may be set explicitly or determined from the number of
bins or the bin width.

Sometimes there is ambiguity in how to interpret a specification.  For
example, if the range extrema and a bin width are specified, this may
result in a non-integral number of bins.  To handle these cases,
extrema may be specified as I<hard> (C<min>, C<max>) or I<soft>
(C<soft_min>, C<soft_max>) limits. Bins may go beyond soft limits.  If
a bin alignment is specified, both extrema are considered soft.

A number of combinations of parameters are accepted.

Here are the easy ones:

=over

=item I<min>, I<max>, I<nbins>.

Extrema are as specified. The grid exactly covers the range.

=item I<min>, I<max>, I<binw>

If the bin width results in a non-integral number of bins, the number
of bins is adjusted to cover the specified range and the grid is centered
on the range.

=item I<min>, I<range_width>, I<nbins>

=item I<max>, I<range_width>, I<nbins>

The extremum is as specified.  The grid exactly covers the range.

=item I<min>, I<range_width>, I<binw>

=item I<max>, I<range_width>, I<binw>

The extremum is as specified. The number of bins is chosen
to minimally cover the specified range.

=item I<min>, I<nbins>, I<binw>

=item I<max>, I<nbins>, I<binw>

The extremum is as specified.  The grid exactly covers the calculated
range.

=item I<min>, I<soft_max>, I<nbins>

=item I<max>, I<soft_min>, I<nbins>

The extrema are as specified. The grid exactly covers the specified range.

=item I<min>, I<soft_max>, I<binw>

=item I<max>, I<soft_min>, I<binw>

The hard extremum is as specified. The number of bins is chosen to
minimally cover the specified range.

=item I<center>, I<range_width>, I<nbins>

The grid exactly covers the range.

=item I<center>, I<range_width>, I<binw>

The bins are aligned so that the center of a bin is at the specified
center; the grid minimally covers the range.

=item I<center>, I<nbins>, I<binw>

The grid exactly covers the range.

=item I<center>, I<soft_min>, I<soft_max>, I<nbins>

The grid is centered on the specified center and minimally
covers the specified range.

=item I<center>, I<soft_min>, I<soft_max>, I<binw>

The middle bin is centered on the specified center; the grid minimally
covers the specified range.


=item I<soft_min>, I<soft_max>, I<nbins>, I<binw>

The bins are centered in the middle of the specified range, the grid
extent is determined from I<nbins> and I<binw>.

=back




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

  [ center => ( I<soft_min> + I<soft_max> ) / 2 ]

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
