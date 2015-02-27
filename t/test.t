#! /usr/bin/perl
use Test::Class::Load '.';

$ENV{TEST_METHOD} = $ARGV[0] if defined($ARGV[0]);

# run all the test methods in the libraries we've loaded
Test::Class->runtests;
