use inc::Module::Install;

# Define metadata
name 'SendGrid';
all_from 'lib/Email/SendGrid.pm';
license 'MIT';

# Specific dependencies
test_requires 'Test::More';
test_requires 'Test::MockObject';
test_requires 'Test::Class::Load';

requires 'Net::SMTP::TLS';
requires 'Sys::Hostname';
requires 'Carp';
requires 'LWP::UserAgent';
requires 'LWP::Protocol::https';
requires 'Mail::Address';
requires 'Sys::Hostname';
requires 'URI::Escape';
requires 'JSON';
requires 'Encode';
requires 'MIME::Entity';

WriteAll;
