#!perl -T

use Test::More tests => 1;

BEGIN {
  use_ok('Math::Histo::Grid');
}

diag( "Testing Math::Histo::Grid $Math::Histo::Grid::VERSION, Perl $], $^X" );
