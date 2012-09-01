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
		delete $exp{align};

		$exp{range_width} = ( exists $exp{max} && exists $exp{min} ) ? $exp{max} - $exp{min}
		                  :                                            $exp{range_width};

		my %got = map { $_ => $grid->$_ } qw[ min max binw nbins range_width ];
		is_deeply( \%got, \%exp, 'results') or do { pp %{$attr}; pp %exp; pp %got };
	}

}

my @tests =
(

#------------------------
# min & max

 [
  { min => 1, max => 10, nbins => 10, align => [ 0, 0 ]},
  { binw => 1, max => 11},
 ],

 [
  { min => 1, max => 10, nbins => 10, align => [ 0, 0.5 ]},
  { binw => 1, max => 11},
 ],

 [
  { min => 1, max => 10, binw => 1 },
  { nbins => 9},
 ],

 [
  { min => 1, max => 10, binw => 1.1 },
  { min => 0.55, max => 10.45, nbins => 9 },
 ],



);

test( @{ $tests[1] } );
#test( @$_ )  foreach @tests;

done_testing;
