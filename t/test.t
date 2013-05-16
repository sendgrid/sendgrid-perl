#! /usr/bin/perl
use Test::Class::Load '.';

# run all the test methods in the libraries we've loaded
Test::Class->runtests;
