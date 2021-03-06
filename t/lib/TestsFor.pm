#
# Copyright (C)  2013  Zoltan Vass <zoltan.tombol (at) gmail (dot) com>
#

#
# This file is part of photo-man.
#
# photo-man is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# photo-man is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with photo-man.  If not, see <http://www.gnu.org/licenses/>.
#


package TestsFor;

use Test::Class::Most
    attributes => [qw(class_to_test)];

INIT {
    # Run all tests.
    Test::Class->runtests;
}

sub startup  : Tests(startup) {
    my $self  = shift;
    my $class = ref $self;
    $class =~ s/^TestsFor:://;

    # Automatically set 'class_to_test' and load the class.
    eval "use $class";
    die $@ if $@;
    $self->class_to_test( $class );
}
sub setup    : Tests(setup)    {}
sub teardown : Tests(teardown) {}
sub shutdown : Tests(shutdown) {}

sub is_abstract {
    my $self = shift;
    return Test::Class::Most->is_abstract( $self );
}

1;
