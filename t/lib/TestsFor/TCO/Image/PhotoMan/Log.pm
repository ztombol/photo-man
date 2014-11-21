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


package TestsFor::TCO::Image::PhotoMan::Log;

use Test::Class::Most
    parent      =>'TestsFor',
    attributes  => [qw/default_log/];

sub startup : Tests(startup) {
    my $self  = shift;
    my $class = ref $self;

    # First call the parent method.
    $self->next::method;

    # Startup code goes here...
}

sub setup : Tests(setup) {
    my $self  = shift;
    my $class = $self->class_to_test;

    # First call the parent method.
    $self->next::method;

    # Set default log object.
    $self->default_log( $self->_create_log );
}

sub teardown : Tests(teardown) {
    my $self = shift;

    # Teardown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

sub shutdown : Tests(shutdown) {
    my $self = shift;

    # Shutdown code goes here...

    # Finally, call parent method.
    $self->next::method;
}

# Instantiates a new log object.
sub _create_log {
    my $self = shift;
    my @attributes = @_;
    my $class = $self->class_to_test;

    return $class->new;
}

sub constructor : Tests {
    my $self  = shift;
    my $class = $self->class_to_test;

    can_ok $class, 'new';
    throws_ok { $class->new({}) }
        qr/Error: constructor requires no parameters!/,
        "Creating a $class with attributes should fail";
    isa_ok $self->default_log, $class;
}

sub move : Tests {
    my $self = shift;
    my $log = $self->_create_log;

    lives_ok sub { $log->move('a', 'b') },
        "logging a move operation should succeed";
}

sub does_file_exist : Tests {
    my $self = shift;

    # Prepare log.
    my $log = $self->_create_log;
    $log->move('a', 'b');

    # Does not exist.
    is $log->does_file_exist('a'), 0,
        "source of moving should not exist";

    # Exists.
    is $log->does_file_exist('b'), 1,
        "destination of moving should exist";

    # Unknown.
    is $log->does_file_exist('c'), -1,
        "a file that is not logged should have unknown state";
}

1;
