#! perl

use strict;
use warnings;

use Math::Histo::Grid::Linear;

use Storable qw[ store retrieve ];

use Math::BigFloat;

use Test::More;
use Test::Fatal;
use Test::Deep;

use POSIX qw[ floor DBL_EPSILON ];

sub new { return Math::Histo::Grid::Linear->new( @_ ) }

my $precision = 9;

sub bigfloat { Math::BigFloat->new( @_ ) }
sub bfr      { Math::BigFloat->new( @_ )->bround( $precision ) }

srand 1;

my $debug = 0;

sub test {

    my ( $attr ) = @_;

    my $grid;

    return if ! delete $attr->{debug} && $debug;

    my $tag = delete $attr->{tag};

        subtest $tag => sub {


            is( exception { $grid = new( %$attr ) },
		undef,
		'constructor'
	      );

            my %got
              = map { $_ => $grid->$_ } qw[ min max binw nbins ];

	    cmp_deeply( $got{binw}, array_each( num( $got{binw}->[0], 1e-8 ) ),
		      'bin width');

	    $got{binw} = $got{binw}->[0];

            cmp_ok( bfr($got{min}), '<=', bfr($attr->{min}), 'min' );

            cmp_ok( bfr($got{max}), '>=', bfr($attr->{max}), 'max' );

            is( $got{nbins}, $attr->{nbins}, 'nbins' );

            my $calc_max = bigfloat($got{min})->badd( bigfloat($got{binw})->bmul( $got{nbins} ) )->bround( $precision );

	    # this is horrible
	    is( bfr( $got{max} ),
		$calc_max,
		'max = min + binw * nbins'
		  );

    };


}

my @tests = (

    # align < min

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 0, 0 ],
        tag   => 'align < min; 0'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 0, 1 / 4 ],
        tag   => 'align < min; 1/4',
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 0, 1 / 2 ],
        tag   => 'align < min; 1/2'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 0, 3 / 4 ],
        tag   => 'align < min; 3/4'
    },

    # align > max

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 11, 0 ],
        tag   => 'align > max; 0'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 11, 1 / 4 ],
        tag   => 'align > max; 1/4',
     debug => 1
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 11, 1 / 2 ],
        tag   => 'align > max; 1/2'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 11, 3 / 4 ],
        tag   => 'align > max; 3/4'
    },

    # align in range

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 1, 0 ],
        tag   => 'align in range; 0'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 3, 1 / 4 ],
        tag   => 'align in range; 1/4'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 7, 1 / 2 ],
        tag   => 'align in range; 1/2'
    },

    {
        min   => 1,
        max   => 10,
        nbins => 10,
        align => [ 9, 3 / 4 ],
        tag   => 'align in range; 3/4'
    },



);

sub random_pan {

    for ( my $align = -10 ; $align < 20 ; $align += rand(0.1) ) {

        for ( my $just = 0 ; $just < 1 ; $just += rand( 0.1 ) ) {

            my %attr = (
                min   => 1,
                max   => 10,
                nbins => 30,
                align => [ $align, $just ],
            );
            $attr{tag} = mk_tag( 'random pan', %attr );
            #	    diag $attr{tag};

	    eval { test( \%attr ) };

	    if ( $@ ) {

	      store \%attr, 'fail.dat';
	      die $@;

	    }
        }
    }


}


sub mk_tag {

    my ( $pfx, %attr ) = @_;

    my @tags;

    for my $k ( sort keys %attr ) {

        my $v = $attr{$k};

        do { push @tags, "$k = $v"; next } unless ref $v;

        push @tags, "$k = [ " . join( ', ', @$v ) . " ]";
    }

    return join( '; ', $pfx, @tags );

}

sub random_test {

    my $idx = shift;

    my $min = rand( 100 );
    my $max = $min + rand( 100 );

    my $nbins = 1 + floor( rand( 99 ) );

    my $align_offset = rand;
    my $align_value  = 200 - rand( 500 );

    # alignment values which lie inside of the range
    # can cause legitimate binning failures, but it's
    # hard to check that ahead of time.
    return 0 if $align_value > $min && $align_value < $max;

    my %attr = (
        min   => $min,
        max   => $max,
        nbins => $nbins,
        align => [ $align_value, $align_offset ],
    );

    $attr{tag} = mk_tag( 'random', %attr );

    eval { test( \%attr ) };

    if ( $@ ) {

        store \%attr, 'fail.dat';
        die $@;
    }

    return 1;

}

sub random_fail {

  my %attr      = %{ retrieve 'fail.dat' };

    eval { test( \%attr ) };

    die 1 if $@;

    unlink 'fail.dat' ;

}

random_fail if -f 'fail.dat';

foreach ( @tests ) {

    eval { test( $_ ) };

    if ( $@ ) {

        store $_, 'fail.dat';
        die $@;
    }


}

random_pan();
my $count = 1000;
$count -= random_test while $count;


done_testing;
