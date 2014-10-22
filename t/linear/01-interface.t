#! perl

use strict;
use warnings;

use Math::Histo::Grid::Linear;

use Test::More;
use Test::Exception;
use Permute::Named 'permute_named';
use Math::Subsets::List;

# these tests are only to insure that the correct combination of
# parameters is allowed

sub new { return Math::Histo::Grid::Linear->new( @_ ) }

if ( 0 ) {

my %value = (

	     min => 20,
	     max => 33,
	     range_width => 13.2,
	     binw => 0.23,
	     nbins => 20,
	     data_min => 0,
	     data_max => 88.8,
	     center => 29.3,
         align => 3,
);

sub defval { $_[0] => $value{$_[0]} // 0 ; }


# these should work without error

for my $pars ( @Math::Histo::Grid::Linear::data_bounds ) {

    my %has = map { defval $_ } @{$pars->{has}};

    my %requires = map { defval $_ } grep { ! ref $_ } @{$pars->{requires}// []};

    my %choices = do {

	my $id=0;
	map { $id++ => $_ } grep { ref $_ } @{$pars->{requires}// []};

    };


    for my $p ( permute_named( %choices ) ) {

	my %pars = ( %has, %requires, map { defval $_ } values %$p );

	lives_ok { new( %pars ) } 'good: ' . join( ' & ', keys %pars )
	  or diag join( ' ', %pars );

    }

}

# make 'em sweat

for my $pars ( @Math::Histo::Grid::Linear::data_bounds ) {


	my %has = map { defval $_ } @{$pars->{has}};

	my @required = grep { ! ref $_ } @{$pars->{requires}// []};

	my %required_choices = do {

		my $id=0;
		map { $id++ => $_ } grep { ref $_ } @{$pars->{requires}// []};

	};

	my @excludes;
	subsets {


		my %e = map { defval $_ } map { ref $_ ? @{$_} : $_ } @_;

		# make sure to check for the case where none of the required
		# choices is set
		for my $rc ( {}, permute_named( %required_choices ) ) {

			# if not excluded and we've got a set of choices,
			# this will pass, and we are checking for failures.
			next if keys %e == 0 && ( keys %$rc != 0 || keys %required_choices == 0);

			my %p = ( %has, %e, map { defval $_ } values %$rc );

			next if keys %p == 0;

			throws_ok { new( %p ) } qr/current set of parameters/, 'bad: ' . join( ' & ', keys %p )
			  or diag join( ' ', 'has: ', %has,
			                     'rc: ',  %$rc,
			                     'e: ', %e );
		}

	} @{ $pars->{excludes} }, @required;


}
}

# aligned
my @aligned =
  (
 { soft_min => 1, soft_max => 20, nbins => 13, align => 21 },
 { min => 1, max => 2, nbins => 2, align => 0 },
 { soft_min => 1, soft_max => 20, nbins => 13, align => 0 },
 { min => 1, max => 2, nbins => 2, align => 0 },
 { min => 1, max => 2, nbins => 2, align => [ 0, 0 ] },
  );

for my $pars ( @aligned ) {

	lives_ok { new( %$pars ) } 'good: ' . join( ' & ', keys %$pars )
	  or diag join( ' ', map { ref $_ ? join(' ', '[', @$_, ']' ) : $_ } %$pars  );
}

done_testing;
