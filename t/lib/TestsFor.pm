package TestsFor;

use Test::Most;
use base 'Test::Class';

INIT { Test::Class->runtests }

sub startup  : Tests(startup)  {}
sub setup    : Tests(setup)    {}
sub teardown : Tests(teardown) {}
sub shutdown : Tests(shutdown) {}

1;
