#sendgrid-perl
Send emails via SendGrid. Provides wrapper for custom SMTP API fields.

#License
Licensed under the MIT License.

#Install
We are currently working on getting this module on CPAN. In the
meantime, you can install from the included archive.

    git clone https://github.com/sendgrid/sendgrid-perl.git
    sudo cpanm SendGrid-1.0.tar.gz

You can also build the archive yourself:
    
    perl Makefile.PL
    make
    make test
    make dist

#Basic usage
```perl
use Mail::SendGrid;
use Mail::SendGrid::Transport::SMTP;

my $sg = Mail::SendGrid->new( from => "from\@example.com",
                              to => "to\@example.com",
                              subject => 'Testing',
                              text => "Some text http://sendgrid.com/\n",
                              html => '<html><body>Some html
                                                  <a href="http://sendgrid.com">SG</a>
                                       </body></html>' );

my $trans = Mail::SendGrid::Transport::SMTP->new( username =>
'sendgrid_username', password => 'sendgrid_password' );

error = $trans->deliver($sg);
die $error if ( $error );
```

