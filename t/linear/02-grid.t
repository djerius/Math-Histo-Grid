#! perl

use Math::Histo::Grid::Linear;

use Data::Printer alias => 'pp';

use Test::More;
use Test::Exception;

sub new { return Math::Histo::Grid::Linear->new( @_ ) }


sub test {

	my ( $attr, $exp ) = @_;

	my $grid;

	my $tag = join( ' ', map { $_ => $attr->{$_} } sort keys %$attr );

	subtest $tag => sub {

		lives_ok { $grid = new( %$attr ) } 'constructor';

		my %exp = ( %$attr, %$exp );

		$exp{range_width} = ( exists $exp{max} && exists $exp{min} ) ? $exp{max} - $exp{min}
		                  :                                            $exp{range_width};

		my %got = map { $_ => $grid->$_ } qw[ min max binw nbins range_width ];
		is_deeply( \%got, \%exp, 'results') or pp %got;
	}

}

my @tests =
(

#------------------------
# min & max

 [
  { min => 1, max => 10, nbins => 10},
  { binw => 0.9},
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
