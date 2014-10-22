#! perl

use Test::More;

use Math::Histo::Grid::Fixed;

{

    my %exp = (
        bin_edges => [ 0.5, 1.3, 2.1, 2.9, 3.7, 4.5, 5.3, 6.1, 6.9, 7.7 ],
    );



    my $grid = Math::Histo::Grid::Fixed->new( bin_edges => [ @{ $exp{bin_edges} } ] );


    is_deeply( $grid->bin_edges, $exp{bin_edges}, 'fixed' );

};

done_testing;

