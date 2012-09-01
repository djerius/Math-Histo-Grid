use strict;
use warnings;
use inc::Module::Install;

name 'Math-Histo-Grid';
license 'gpl3';
all_from 'lib/Math/Histo/Grid.pm';

tests_recursive;

author_tests( 'xt' );

requires 'Moo';
requires 'MooX::Types::MooseLike';

test_requires 'Test::More';

test_requires 'Test::Exception';
test_requires 'Permute::Named';
test_requires 'Math::Subsets::List';

auto_install;

WriteAll;
