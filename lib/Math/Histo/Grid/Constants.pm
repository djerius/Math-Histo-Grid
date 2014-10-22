package Math::Histo::Grid::Constants;

use strict;
use warnings;

use base 'Exporter::Tiny';
use constant;

my %constants;

sub bitflags {
    my $tag = shift;
    my $bit = 1;
    return $tag => {
        "\U${tag}_" . shift() => 1,
        map {
            $bit <<= 1;
            "\U${tag}\E_${_}" => $bit;
        } @_
    };
}


BEGIN {

    %constants = (

        # min & max must be 1 & 2; the logic in Autoscale depends upon it.
        bitflags( autoscale => qw[
              MIN
              MAX
              MIN_AND_MAX
              MIN_OR_MAX ]
        ),

        bitflags( limit => qw[
              HARD
              SOFT
              ]
        ),

        bitflags( linear => qw[
              MIN
              MAX
              SOFT_MIN
              SOFT_MAX
              CENTER
              RANGE_WIDTH
              NBINS
              BINW
              ALIGN
              ]
        ),
    );

    constant->import( $_ ) for values %constants;
}



our %EXPORT_TAGS = (
    map { $_ => [ keys %{ $constants{$_} } ] }
      keys %constants
);

our @EXPORT_OK = map { @{$_} } values %EXPORT_TAGS;

sub _exporter_expand_tag {

    my $class = shift;

    # my ( $name, $args, $globals ) = @_;

    $_[1] = {} unless ref( $_[1] ) eq q(HASH);
    $_[1]->{tag} = $_[0];

    $class->SUPER::_exporter_expand_tag( @_ );
}

sub _exporter_install_sub {

    my $class = shift;
    # my ( $name, $value, $sym ) = @_;

    if ( defined $_[1]->{tag} && $_[1]->{-strip_tag} ) {

	$_[1]->{-as} = $1
	    if $_[0] =~ /^\U$_[1]->{tag}_(.*)/;

    }

    $class->SUPER::_exporter_install_sub( @_ );
}

1;
