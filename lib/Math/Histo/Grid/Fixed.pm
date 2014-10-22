package Math::Histo::Grid::Fixed;

use Moo;

use Types::Standard qw[ InstanceOf ];

extends 'Math::Histo::Grid::Base';
use PDL::Lite;

has '+bin_edges' => (
    required => 1,
);


1;
