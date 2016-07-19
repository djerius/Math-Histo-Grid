#! perl

use strict;
use warnings;

use Math::Histo::Grid::Linear;

use Test::More;
use Test::Fatal;
use Test::Deep;

sub new { return Math::Histo::Grid::Linear->new( @_ ) }

my $debug = 0;

sub test {

    my ( $attr, $exp ) = @_;

    return if !delete $attr->{debug} && $debug;

    my $tag = join( ' ', map { $_ => $attr->{$_} } sort keys %$attr );

    subtest $tag => sub {

      SKIP: {
            my $grid;

            is( exception { $grid = new( %$attr ) }, undef, 'constructor' )
              or skip "can't construct; can't continue", 1;

            my %exp = ( %$attr, %$exp );

            $exp{binw} = array_each( num( $exp{binw}, 1e-8 ) );

            $exp{$_} = num( $exp{$_}, 1e-8 )
              for grep { exists $exp{$_} } qw/ min max  /;

            delete $exp{range_width};

            my %got = map { $_ => $grid->$_ }
              grep { defined $exp{$_} } qw[ min max binw nbins bin_edges ];

            cmp_deeply( \%got, \%exp, 'results' );
        }
    };

}

my @tests = (

    #------------------------
    # min & max

    [
        { min => 1, max => 10, nbins => 10 },
        {
            binw => 0.9,
            bin_edges =>
              [ 1, 1.9, 2.8, 3.7, 4.6, 5.5, 6.4, 7.3, 8.2, 9.1, 10.0 ],
        },
    ],

    [
        { min => 0.5, max => 7.7, nbins => 9 },
        {
            binw      => 0.8,
            bin_edges => [ 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ],

        },
    ],

    [
        { min => 1, max => 10, binw => 1 },
        {
            nbins     => 9,
            bin_edges => [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ],
        },
    ],

    [
        { min => 0.5, max => 8, binw => 0.8 },
        {
            min       => 0.25,
            max       => 8.25,
            nbins     => 10,
            bin_edges => [
                0.25, 1.05, 1.85, 2.65, 3.45, 4.25,
                5.05, 5.85, 6.65, 7.45, 8.25,
            ],
        },
    ],

    [
        { min => 1, max => 10, binw => 1.1 },
        {
            min   => 0.55,
            max   => 10.45,
            nbins => 9,
            bin_edges =>
              [ 0.55, 1.65, 2.75, 3.85, 4.95, 6.05, 7.15, 8.25, 9.35, 10.45 ],
        },
    ],

    #------------------------
    # min & range_width

    [
        { min => 1, range_width => 9, nbins => 10, },
        {
            max       => 10,
            binw      => 0.9,
            bin_edges => [ 1, 1.9, 2.8, 3.7, 4.6, 5.5, 6.4, 7.3, 8.2, 9.1, 10 ],
        },
    ],

    [
        { min => 1, range_width => 9, binw => 1 },
        {
            max       => 10,
            nbins     => 9,
            bin_edges => [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ],
        },
    ],

    [
        { min => 1, range_width => 9, binw => 1.1 },
        {
            max       => 10.9,
            nbins     => 9,
            bin_edges => [ 1, 2.1, 3.2, 4.3, 5.4, 6.5, 7.6, 8.7, 9.8, 10.9 ],
        },
    ],

    #------------------------
    # max & range_width

    [
        { max => 10, range_width => 9, nbins => 10, },
        {
            min  => 1,
            binw => 0.9,
            bin_edges =>
              [ 1, 1.9, 2.8, 3.7, 4.6, 5.5, 6.4, 7.3, 8.2, 9.1, 10, ],
        },
    ],

    [ { max => 10, range_width => 9, binw => 1 }, { min => 1, nbins => 9 }, ],

    [
        { max => 10, range_width => 9, binw => 1.1 },
        {
            min       => 0.1,
            nbins     => 9,
            bin_edges => [ 0.1, 1.2, 2.3, 3.4, 4.5, 5.6, 6.7, 7.8, 8.9, 10.0 ],
        },
    ],

    #------------------------
    # min & nbins & binw

    [
        { min => 0.5, nbins => 9, binw => 0.8 },
        {
            max       => 7.7,
            bin_edges => [ 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ],
        },
    ],

    [
        { min => 1, nbins => 9, binw => 1 },
        {
            max       => 10,
            bin_edges => [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ],
        },
    ],

    [
        { min => 1, nbins => 9, binw => 1.1 },
        {
            max       => 10.9,
            bin_edges => [ 1, 2.1, 3.2, 4.3, 5.4, 6.5, 7.6, 8.7, 9.8, 10.9 ],
        },
    ],

    #------------------------
    # max & nbins & binw

    [
        { max => 10, nbins => 10, binw => 0.9 },
        {
            min => 1,
            bin_edges =>
              [ 1, 1.9, 2.8, 3.7, 4.6, 5.5, 6.4, 7.3, 8.2, 9.1, 10.0 ],
        },
    ],

    [
        { max => 10, nbins => 9, binw => 1 },
        {
            min       => 1,
            bin_edges => [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ],
        },
    ],

    [
        { max => 10, nbins => 9, binw => 1.1 },
        {
            min       => 0.1,
            bin_edges => [ 0.1, 1.2, 2.3, 3.4, 4.5, 5.6, 6.7, 7.8, 8.9, 10 ],
        },
    ],


);

test( @$_ ) foreach @tests;

done_testing;
