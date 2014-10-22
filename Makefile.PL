use strict;
use warnings;
use inc::Module::Install;

name 'Math-Histo-Grid';
license 'gpl3';
all_from 'lib/Math/Histo/Grid.pm';

tests_recursive;

author_tests( 'xt' );

cpanfile;

auto_install;

WriteAll;
