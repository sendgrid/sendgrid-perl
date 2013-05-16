package Mail::SendGrid::Transport::SMTP::Test;

use strict;
use base qw(Test::Class);
use Test::More;

use MIME::Entity;
use Mail::SendGrid;
use Mail::SendGrid::Transport::SMTP;

sub getSGObject
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim Jenkins <$fromAddr>";
  my $to =  "Tim Jenkins <$toAddr>";
  my $text = 'Some text';
  my $html = '<html><body>Some html</body></html>';
  my $encoding = 'base64';
  my $charset = 'utf-8';

  my $sg = Mail::SendGrid->new( from => $from,
                                to => $to,
                                encoding => $encoding,
                                charset => $charset,
                                text => $text,
                                html => $html,
                              );

  return $sg;
}

sub delivery : Test()
{
  my $smtp = Mock::Net::SMTP::TLS->create();
  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );


  my $sg = getSGObject();

  my $res = $deliv->deliver($sg);

  is($res, undef, 'normal delivery');
}

###################################################################################################
# Tests for the SMTP transaction
sub connection_refused : Test()
{
  my $smtp = Mock::Net::SMTP::TLS->create( 'new' =>
      sub { die "Connect failed :IO::Socket::INET: connect: Connection refused"; }
      );

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /refused/, 'connection refused');
}

sub unknown_host : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( 'new' =>
      sub { die "Connect failed :IO::Socket::INET: Bad hostname '$_[1]'"; }
      );

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /Bad hostname/, 'unknown host');
}

sub failed_authentication : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( 'new' =>
      sub { die "Auth failed: 535 5.7.8 Error: authentication failed: authentication failure"; }
      );

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /Auth failed/, 'failed authentication');
}

sub from_rejection : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( 'mail' => sub {
    my $self = shift;
    my $from = shift;
    die "Couldn't send MAIL <$from> 5.7.1 Relay denied"; }
      );

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /send MAIL.*tim\@sendgrid.net/, 'mail command rejected');
}

sub to_rejection : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( 'to' => sub {
    my $self = shift;
    my $to = shift;
    die "Couldn't send TO <$to>: 554 5.7.1 <unknown[10.8.49.102]>: Client host rejected: Access denied";
  });

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /send TO.*tim\@sendgrid.com/, 'to command rejected');
}

sub data_error : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( data => sub {
    die "An error occurred during DATA";
  });

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /during DATA\W/, 'data error');
}

sub datasend_error : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( datasend => sub {
    die "An error occurred during datasend";
  });

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /during datasend\W/, 'datasend error');
}

sub dataend_error : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( dataend => sub {
    die "An error occurred during dataend";
  });

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  ok($error =~ /during dataend\W/, 'dataend error');
}

# Errors on quit should be ignored
sub quit_error : Test
{
  my $smtp = Mock::Net::SMTP::TLS->create( quit => sub {
    die "An error occurred disconnecting from the mail server";
  });

  my $deliv = Mail::SendGrid::Transport::SMTP->new( 'username' => 'tim@sendgrid.net',
                                             'password' => 'testing',
                                             'smtp_class' => $smtp
                                             );

  my $sg = getSGObject();

  my $error = $deliv->deliver($sg);

  is($error, undef, 'handling of error on quit');
}

1;
