package Math::Histo::Grid::Ratio;

use Moo;
use Carp;

use Math::Histo::Grid::Constants -autoscale => { -strip_tag => 1, -prefix => 'AS_' };

extends 'Math::Histo::Grid::Base';

use Types::Standard qw[ Bool ];
use Types::Common::Numeric qw[ PositiveNum PositiveInt ];

# [min]:[max]:[+]r0:ratio
use Regexp::Common;
use constant rangeRE => qr/^
                               (?<min>$RE{num}{real})?  # min
                               :
                               (?<max>$RE{num}{real})?  # max
                               :
                               (?<binw>$RE{num}{real})   # binw
                               :
                               (?<ratio>$RE{num}{real})   # ratio
                               $/x;

my %AttrFlag;

BEGIN {
    %AttrFlag = (
        _min   => 1,
        _max   => 2,
        _binw  => 4,
        _nbins => 8,
    );
    constant->import( { map { uc $_ => $AttrFlag{$_} } keys %AttrFlag } );
}

has _binw => (
    is       => 'ro',
    isa      => PositiveNum,
    init_arg => 'binw',
    required => 1,
);

has _nbins => (
    is       => 'ro',
    isa      => PositiveInt,
    init_arg => 'nbins'
);

has ratio => (
    is  => 'ro',
    isa => PositiveNum
      & sub { $_[0] > 1 or die "ratio must be greater than 1\n" },
    required => 1,
);


sub BUILD { }

sub _build_bin_edges {

    my $self = shift;

    # input parameter combinations are ( min, binw, max ), ( min, binw, nbins )

    croak(
        "please specify either the nbins attribute or the max attribute (but not both)\n"
      )
      if ( defined $self->_max
        && defined $self->_nbins
        && !defined $self->_autoscaled )
      || ( !defined $self->_max && !defined $self->_nbins );

    my $nbins = $self->_nbins;

    # max specified.
    if ( !defined $nbins ) {

        my $max = $self->_min;
        $nbins = 0;
        $nbins++
          while ( $max += $self->_binw * $self->ratio**( $nbins ) ) < $self->_max;

    }

    my $sum = $self->_min;

    return [
        $self->_min,
        map {
            $sum += $self->_binw * $self->ratio**( $_ );
            $sum;
        } 0 .. $nbins - 1
    ];

}

sub autoscale_flags { AS_MIN }

with 'Math::Histo::Grid::Role::AutoScale';

1;
