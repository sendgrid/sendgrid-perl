[![Build Status](https://travis-ci.org/sendgrid/sendgrid-perl.png?branch=master)](https://travis-ci.org/sendgrid/sendgrid-perl)

#sendgrid-perl
Send emails via SendGrid. Provides wrapper for custom SMTP API fields
and allows for easy manipulation of filter/app settings.

Written by Tim Jenkins.

#License
Licensed under the MIT License.

#Install
We are currently working on getting this module on CPAN. In the
meantime, you can install from the included archive.

    git clone https://github.com/sendgrid/sendgrid-perl.git
    sudo cpanm SendGrid-1.1.tar.gz

You can also build the archive yourself:
    
    perl Makefile.PL
    make
    make test
    make dist

#Basic usage
```perl
use warnings;
use strict;

use Email::SendGrid;
use Email::SendGrid::Transport::REST;

my $sg = Email::SendGrid->new( from => 'from@example.com',
                              to => 'to@example.com',
                              subject => 'Testing',
                              text => "Some text http://sendgrid.com/\n",
                              html => '<html><body>Some html
                                                  <a href="http://sendgrid.com">SG</a>
                                       </body></html>' );

#disable click tracking filter for this request
$sg->disableClickTracking();

#turn on the unsubscribe filter here with custom values
$sg->enableUnsubscribe( text => "Unsubscribe here: <% %>", html => "Unsubscribe <% here %>" );

#set a category
$sg->header->setCategory('first contact');

#add unique arguments
$sg->header->addUniqueIdentifier( customer => '12345', location => 'somewhere' );

my $trans = Email::SendGrid::Transport::REST->new( username => 'sendgrid_username', password => 'sendgrid_password' );

my $error = $trans->deliver($sg);
die $error if ( $error );
```

#Advanced Usage
For more detailed information, please refer to the perldocs.
