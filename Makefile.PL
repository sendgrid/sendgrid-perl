  use inc::Module::Install;
  
  # Define metadata
  name           'SendGrid';
  all_from       'lib/Mail/SendGrid.pm';
  version_from   'lib/mail/SendGrid.pm';
  license        'MIT';

  # Specific dependencies
  test_requires  'Test::More'  => '0.42';
  
  WriteAll;
