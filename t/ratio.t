#! perl

use Test::More;

use Math::Histo::Grid::Ratio;

my %exp = (
    oob       => 0,
    min       => 0.5,
    binw      => 0.8,
    ratio     => 1.1,
    bin_edges => [ map { 0.5 + $_ } (
        0,          0.8,          1.68,     2.648,
        3.7128,     4.88408,      6.172488, 7.5897368,
        9.14871048, 10.863581528, 12.7499396808
    ) ],
);

{

    my %exp = %exp;

    my $grid = Math::Histo::Grid::Ratio->new(
        min   => $exp{min},
        binw  => $exp{binw},
        ratio => $exp{ratio},
        nbins => @{ $exp{bin_edges}}  - 1,
        oob   => $exp{oob},
    );

    delete $exp{binw};
    is_deeply( $grid->bin_edges, $exp{bin_edges}, 'MIN | BINW | NBINS' );

};

{

    my %exp = %exp;

    my $grid = Math::Histo::Grid::Ratio->new(
        min   => $exp{min},
        binw  => $exp{binw},
        ratio => $exp{ratio},
        max   => POSIX::ceil( $exp{bin_edges}[-1] ),
        oob   => $exp{oob},
    );

    delete $exp{binw};
    is_deeply( $grid->bin_edges, $exp{bin_edges}, 'MIN | BINW | NBINS' );

};

done_testing;

