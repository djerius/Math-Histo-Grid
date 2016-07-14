use strict;
use warnings;
use inc::Module::Install;

name 'Math-Histo-Grid';
license 'gpl3';
all_from 'lib/Math/Histo/Grid.pm';

readme_from;
readme_from '', { format => 'md' };;

tests_recursive;

author_tests( 'xt' );

cpanfile;

WriteAll;
