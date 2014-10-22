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

	return if ! delete $attr->{debug} && $debug;

	my $tag = join( ' ', map { $_ => $attr->{$_} } sort keys %$attr );

	subtest $tag => sub {

	    SKIP : {
	    my $grid;

	    is ( exception { $grid = new( %$attr ) }, undef,  'constructor')
	      or skip "can't construct; can't continue", 1;

	    my %exp = ( %$attr, %$exp );

	    $exp{binw} = array_each( num( $exp{binw}, 1e-8 ) );

	    $exp{$_} = num( $exp{$_}, 1e-8 )
	      for grep { exists $exp{$_} } qw/ min max  /;

            delete $exp{range_width};

	    my %got = map { $_ => $grid->$_ } qw[ min max binw nbins  ];
	    cmp_deeply( \%got, \%exp, 'results');
	}
	};

}

my @tests =
(

#------------------------
# min & max

 [
  { min => 1, max => 10, nbins => 10},
  { binw => 0.9 },
 ],

 [
  { min => 1, max => 10, binw => 1 },
  { nbins => 9},
 ],

 [
  { min => 1, max => 10, binw => 1.1 },
  { min => 0.55, max => 10.45, nbins => 9 },
 ],

#------------------------
# min & range_width

 [
  { min => 1, range_width => 9, nbins => 10,},
  { max => 10, binw => 0.9},
 ],

 [
  { min => 1, range_width => 9, binw => 1},
  { max => 10, nbins => 9},
 ],

 [
  { min => 1, range_width => 9, binw => 1.1 },
  { max => 10.9, nbins => 9 },
 ],

#------------------------
# max & range_width

 [
  { max => 10, range_width => 9, nbins => 10,},
  { min => 1, binw => 0.9},
 ],

 [
  { max => 10, range_width => 9, binw => 1},
  { min => 1, nbins => 9},
 ],

 [
  { max => 10, range_width => 9, binw => 1.1 },
  { min => 0.1, nbins => 9 },
 ],

#------------------------
# min & nbins & binw

 [
  { max => 10, nbins => 10, binw => 0.9 },
  { min => 1 },
 ],

 [
  { max => 10, nbins => 9, binw => 1},
  { min => 1 },
 ],

 [
  { max => 10, nbins => 9, binw => 1.1 },
  { min => 0.1 },
 ],


);

test( @$_ )  foreach @tests;

done_testing;
