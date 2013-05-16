package Mail::SendGrid::Test;

use strict;
use base qw(Test::Class);
use Test::More;

use Mail::SendGrid;
use Encode;

use Data::Dumper qw(Dumper);

sub addresses : Test(12)
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim Jenkisn <$fromAddr>";
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

  my $mime = $sg->createMimeMessage();

  my $mailFrom = $sg->getMailFrom();
  is($mailFrom, $fromAddr, 'mail from');

  # Check to address
  my @rcpts = $sg->getRecipients();
  ok(scalar(@rcpts) == 1 && $rcpts[0] eq $toAddr, "to address from string");

  $sg = Mail::SendGrid->new( to => [ $to, $from ] );

  @rcpts = $sg->getRecipients();
  ok(scalar(@rcpts) == 2 && $rcpts[0] eq $toAddr && $rcpts[1] eq $fromAddr, "to address as array ref");

  # Check cc address
  $sg = Mail::SendGrid->new( cc => "$to, $from" );

  @rcpts = $sg->getRecipients();
  ok(scalar(@rcpts) == 2 && $rcpts[0] eq $toAddr && $rcpts[1] eq $fromAddr, "cc address as string");


  $sg = Mail::SendGrid->new( cc => [ $to, $from ] );

  @rcpts = $sg->getRecipients();
  ok(scalar(@rcpts) == 2 && $rcpts[0] eq $toAddr && $rcpts[1] eq $fromAddr, "cc address as array ref");

  # Check bcc address
  $sg = Mail::SendGrid->new( bcc => "$to, $from" );

  @rcpts = $sg->getRecipients();
  ok(scalar(@rcpts) == 2 && $rcpts[0] eq $toAddr && $rcpts[1] eq $fromAddr, "bcc address as string");


  $sg = Mail::SendGrid->new( bcc => [ $to, $from ] );

  @rcpts = $sg->getRecipients();
  ok(scalar(@rcpts) == 2 && $rcpts[0] eq $toAddr && $rcpts[1] eq $fromAddr, "bcc address as array ref");

  # Check with all addresses in place
  my $toa = [ $to, $from ];
  my $toad = [ $toAddr, $fromAddr ];
  my $cca = [ $from, $to ];
  my $ccad = [ $fromAddr, $toAddr ];
  my $bcca = [ $to, $from ];
  my $bccad = [ $toAddr, $fromAddr ];

  my @realrcpts = @$toad;
  push(@realrcpts, @$ccad, @$bccad);

  $sg = Mail::SendGrid->new( to => $toa, cc => $cca, bcc => $bcca,
                             from => $from,
                             text => $text,
                             html => $html,
   );

  @rcpts = $sg->getRecipients();
  my $match = 0;

  foreach my $i (0..$#rcpts)
  {
    $match++ if ( $rcpts[$i] eq $realrcpts[$i] );
  }

  is($match, scalar(@realrcpts), "to, cc, and bcc address merges");

  # Now check that the mime entity is created properly from this
  $mime = $sg->createMimeMessage();

  my $mimeFrom = $mime->head->get('from');
  my $mimeTo = $mime->head->get('to');
  my $mimeCc = $mime->head->get('cc');
  my $mimeBcc = $mime->head->get('bcc');

  chomp($mimeFrom);
  chomp($mimeTo);
  chomp($mimeCc);

  is($mimeFrom, $from, 'mime from field');
  is($mimeTo, "$to, $from", 'mime to field');
  is($mimeCc, "$from, $to", 'mime cc field');
  is($mimeBcc, undef, 'mime bcc field undefined');
}

sub multipart : Test(4)
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim Jenkisn <$fromAddr>";
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

  my $mime = $sg->createMimeMessage();
  my @parts = $mime->parts();

  ok($parts[0]->bodyhandle->as_string() eq $text && $parts[0]->mime_type eq 'text/plain', 'multipart text portion correct content');
  ok($parts[1]->bodyhandle->as_string() eq $html && $parts[1]->mime_type eq 'text/html', 'multipart html portion correct content');
  ok($parts[0]->head->mime_attr("content-type.charset") eq $charset &&
     $parts[1]->head->mime_attr("content-type.charset") eq $charset, 'multipart correct charset');
  ok($parts[0]->head->mime_encoding() eq $encoding &&
     $parts[1]->head->mime_encoding() eq $encoding, 'multipart correct encoding');
}

sub textonly : Test(3)
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim Jenkisn <$fromAddr>";
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
                              );

  my $mime = $sg->createMimeMessage();
  my @parts = $mime->parts();

  ok($mime->bodyhandle->as_string() eq $text && $mime->mime_type eq 'text/plain', 'text only correct content');
  is($mime->head->mime_attr("content-type.charset"), $charset, 'text only correct charset');
  is($mime->head->mime_encoding(), $encoding, 'text only correct encoding');
}

sub htmlonly : Test(3)
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim Jenkisn <$fromAddr>";
  my $to =  "Tim Jenkins <$toAddr>";
  my $text = 'Some text';
  my $html = '<html><body>Some html</body></html>';
  my $encoding = 'base64';
  my $charset = 'utf-8';

  my $sg = Mail::SendGrid->new( from => $from,
                                to => $to,
                                encoding => $encoding,
                                charset => $charset,
                                html => $html,
                              );

  my $mime = $sg->createMimeMessage();
  my @parts = $mime->parts();

  ok($mime->bodyhandle->as_string() eq $html && $mime->mime_type eq 'text/html', 'html only correct content');
  is($mime->head->mime_attr("content-type.charset"), $charset, 'html only correct charset');
  is($mime->head->mime_encoding(), $encoding, 'html only correct encoding');
}

sub headers : Test(4)
{
  my $subject = "subject test";
  my $date = 'now';
  my $msgId = 'msg-id';
  my $text = "some text";

  my $sg = Mail::SendGrid->new( subject => $subject,
                                date => $date,
                                'message-id' => $msgId,
                                text => $text );

  my $mime = $sg->createMimeMessage();
  my $s = $mime->head->get('subject');
  chomp($s);
  is($s, $subject, "subject as parameter");

  my $d = $mime->head->get('date');
  chomp($d);
  is($d, $date, 'date as parameter');

  my $m = $mime->head->get('message-id');
  chomp($m);
  is($m, $msgId, 'message id as paramter');

  # Test subject set method
  $sg = Mail::SendGrid->new( text => $text );
  $sg->set('subject', $subject);

  $mime = $sg->createMimeMessage();
  $s = $mime->head->get('subject');
  chomp($s);
  is($s, $subject, "subject set with function");
}

sub unicode : Test(7)
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim\x{311} Jenkisn <$fromAddr>";
  my $to =  "Tim\x{312} Jenkins <$toAddr>";
  my $text = "Some unicode\x{587} text";
  my $html = "<html><body>Some unicode \x{465} html</body></html>";
  my $encoding = 'base64';
  my $charset = 'utf-8';
  my $subject = "subject \x{f441}";
  my $reply = "some reply \x{411}";

  my $sg = Mail::SendGrid->new( from => $from,
                                to => $to,
                                subject => $subject,
                                encoding => $encoding,
                                charset => $charset,
                                'reply-to' => $reply,
                                text => $text,
                                html => $html,
                              );

  my $mime = $sg->createMimeMessage();
  my @parts = $mime->parts();

  my $mText = $parts[0]->bodyhandle->as_string();
  my $mHtml = $parts[1]->bodyhandle->as_string();

  ok( $mText ne $text && decode($charset, $mText) eq $text, 'unicode text portion correctly enocded');
  ok( $mHtml ne $html && decode($charset, $mHtml) eq $html, 'unicode html portion correctly encoded');

  # Test unicode headers
  my $s = $mime->head->get('subject');
  chomp($s);

  my $sd = decode('MIME-Header', $s);

  ok($s =~ /\?Q\?/ && $sd eq $subject, "unicode headers, qp encoded");

  # Base64 encoding
  my $subj = "subject2 \x{f441}\x{443}\x{3423}\x{4322}\x{4333}\x{111}\x{465}";
  $sg->set('subject', $subj);

  $mime = $sg->createMimeMessage();

  $s = $mime->head->get('subject');
  chomp($s);

  $sd = decode('MIME-Header', $s);

  ok($s =~ /\?B\?/ && $sd eq $subj, "unicode headers, base64 encoded");

  # Check the other headers to be sure of proper encoding
  my $h = 'to';
  my $mh = $mime->head->get($h);
  chomp($mh);
  ok($mh =~ /\?Q\?/, "unicode $h encoded");

  $h = 'from';
  $mh = $mime->head->get($h);
  chomp($mh);
  ok($mh =~ /\?Q\?/, "unicode $h encoded");

  $h = 'reply-to';
  $mh = $mime->head->get($h);
  chomp($mh);
  ok($mh =~ /\?Q\?/, "unicode $h encoded");

}


sub attachments : Test(no_plan)
{
  my $fromAddr = 'tim@sendgrid.net';
  my $toAddr = 'tim@sendgrid.com';
  my $from = "Tim Jenkisn <$fromAddr>";
  my $to =  "Tim Jenkins <$toAddr>";
  my $text = 'Some text';
  my $html = '<html><body>Some html</body></html>';
  my $encoding = 'quoted-printable';
  my $charset = 'utf-8';

  my $sg = Mail::SendGrid->new( from => $from,
                                to => $to,
                                encoding => $encoding,
                                charset => $charset,
                                html => $html,
                              );

  my $attachEncoding = 'binary';
  my $attachType = 'application/pdf';

  $sg->addAttachment( $text, encoding => $attachEncoding, type => $attachType );

  my $mime = $sg->createMimeMessage();
  my @parts = $mime->parts();
  is(scalar(@parts), 2, "Attachment");

  is($parts[1]->bodyhandle->as_string(), $text, "attachment correct content");
  is($parts[1]->head->mime_type(), $attachType, "attachment correct type");
  is($parts[1]->head->mime_encoding(), $attachEncoding, "attachment correct encoding");
}

sub filterShortcuts : Test(no_plan)
{
  my $sg = Mail::SendGrid->new();

  # click tracking
  $sg->enableClickTracking( text => 1 );
  is($sg->header->{data}->{filters}->{clicktrack}->{settings}->{enable}, 1, 'enable click tracking');
  is($sg->header->{data}->{filters}->{clicktrack}->{settings}->{enable_text}, 1, 'enable text click tracking');

  $sg->disableClickTracking();
  is($sg->header->{data}->{filters}->{clicktrack}->{settings}->{enable}, 0, 'disable click tracking');

  # Open tracking
  $sg->enableOpenTracking();
  is($sg->header->{data}->{filters}->{opentrack}->{settings}->{enable}, 1, 'enable open tracking');

  $sg->disableOpenTracking();
  is($sg->header->{data}->{filters}->{opentrack}->{settings}->{enable}, 0, 'disable open tracking');

  # Spam check
  $sg->enableSpamCheck( score => 4, url => 'foo' );
  is($sg->header->{data}->{filters}->{spamcheck}->{settings}->{enable}, 1, 'enable spam check');
  is($sg->header->{data}->{filters}->{spamcheck}->{settings}->{maxscore}, 4, 'set spam check score');
  is($sg->header->{data}->{filters}->{spamcheck}->{settings}->{url}, 'foo', 'set spam check url');

  $sg->disableSpamCheck();
  is($sg->header->{data}->{filters}->{spamcheck}->{settings}->{enable}, 0, 'disable spam check');

  # Gravatar
  $sg->enableGravatar();
  is($sg->header->{data}->{filters}->{gravatar}->{settings}->{enable}, 1, 'enable gravatar');

  $sg->disableGravatar();
  is($sg->header->{data}->{filters}->{gravatar}->{settings}->{enable}, 0, 'disable gravatar');

  # Subscription tracking
  $sg->enableUnsubscribe( text => '<% %>',
                          html => '<% here %>',
                          replace => 'foo',
                          );

  is($sg->header->{data}->{filters}->{subscriptiontrack}->{settings}->{enable}, 1,
      'enable subscription tracking');
  is($sg->header->{data}->{filters}->{subscriptiontrack}->{settings}->{'text/plain'}, '<% %>',
      'subscription text replacement');
  is($sg->header->{data}->{filters}->{subscriptiontrack}->{settings}->{'text/html'}, '<% here %>',
      'subscription html replacement');
  is($sg->header->{data}->{filters}->{subscriptiontrack}->{settings}->{replace}, 'foo',
      'subscription tag replacement');

  eval {
    $sg->enableUnsubscribe( text => 'unsubscribe' );
  };
  ok ( $@ =~ /tag in text/, "subscription text checking" );

  eval {
    $sg->enableUnsubscribe( html => '<% %>' );
  };
  ok ( $@ =~ /tag in html/, 'subscription html checking' );

  $sg->disableUnsubscribe();
  is($sg->header->{data}->{filters}->{subscriptiontrack}->{settings}->{enable}, 0,
      'disable subscription tracking');

  # Footer
  $sg->enableFooter( text => 'text', html => 'html' );
  is($sg->header->{data}->{filters}->{footer}->{settings}->{enable}, 1, 'enable footer');
  is($sg->header->{data}->{filters}->{footer}->{settings}->{'text/plain'}, "text", 'footer text setting');
  is($sg->header->{data}->{filters}->{footer}->{settings}->{'text/html'}, "html", 'footer html setting');

  $sg->disableFooter();
  is($sg->header->{data}->{filters}->{footer}->{settings}->{enable}, 0, 'disable footer');

  # Google Analytics
  $sg->enableGoogleAnalytics( source => 'source',
                              medium => 'medium',
                              term => 'term',
                              content => 'content',
                              campaign => 'campaign' );

  is($sg->header->{data}->{filters}->{ganalytics}->{settings}->{enable}, 1, 'enable ganalytics');
  foreach my $field ( qw(source medium term content campaign) )
  {
    is($sg->header->{data}->{filters}->{ganalytics}->{settings}->{"utm_$field"}, $field,
      "ganalytics $field");
  }

  $sg->disableGoogleAnalytics();
  is($sg->header->{data}->{filters}->{ganalytics}->{settings}->{enable}, 0, 'disable ganalytics');

  # Domain Keys
  $sg->enableDomainKeys( domain => 'domain', sender => 1 );
  is($sg->header->{data}->{filters}->{domainkeys}->{settings}->{enable}, 1, 'enable domainkeys');
  is($sg->header->{data}->{filters}->{domainkeys}->{settings}->{domain}, 'domain', 'domainkeys domain');
  is($sg->header->{data}->{filters}->{domainkeys}->{settings}->{sender}, 1, 'domainkeys sender');

  $sg->disableDomainKeys();
  is($sg->header->{data}->{filters}->{domainkeys}->{settings}->{enable}, 0, 'disable domainkeys');

  # Template
  $sg = Mail::SendGrid->new();
  $sg->enableTemplate( html => 'html<% %>' );
  is($sg->header->{data}->{filters}->{template}->{settings}->{enable}, 1, 'enable template');
  is($sg->header->{data}->{filters}->{template}->{settings}->{'text/html'}, 'html<% %>', 'template html');

  $sg->disableTemplate();
  is($sg->header->{data}->{filters}->{template}->{settings}->{enable}, 0, 'disable template');

  # Template argument validation
  eval { $sg->enableTemplate() };
  ok($@ =~ /Missing html/, 'template html tag required');

  eval { $sg->enableTemplate( html => 'foo' ) };
  ok($@ =~ /Missing body/, 'template html tag validation');

  # Twitter
  $sg = Mail::SendGrid->new();
  $sg->enableTwitter( username => 'user', password => 'pass' );
  is($sg->header->{data}->{filters}->{twitter}->{settings}->{enable}, 1, 'enable twitter');
  is($sg->header->{data}->{filters}->{twitter}->{settings}->{username}, 'user', 'twitter username');
  is($sg->header->{data}->{filters}->{twitter}->{settings}->{password}, 'pass', 'twitter password');

  # Twitter argument validation
  eval { $sg->enableTwitter( password => 'foo' ) };
  ok($@ =~ /username/, 'twitter username required');

  eval { $sg->enableTwitter( username => 'foo' ) };
  ok($@ =~ /password/, 'twitter password required');

  $sg->disableTwitter();
  is($sg->header->{data}->{filters}->{twitter}->{settings}->{enable}, 0, 'disable twitter');

  # BCC
  $sg = Mail::SendGrid->new();
  $sg->enableBcc( email => 'email' );
  is($sg->header->{data}->{filters}->{bcc}->{settings}->{enable}, 1, 'enable bcc');
  is($sg->header->{data}->{filters}->{bcc}->{settings}->{email}, 'email', 'bcc email');

  # BCC argument validation
  eval { $sg->enableBcc() };
  ok($@ =~ /email/, 'bcc email validation');

  # Bypass list management
  $sg = Mail::SendGrid->new();
  $sg->enableBypassListManagement();
  is($sg->header->{data}->{filters}->{bypass_list_management}->{settings}->{enable}, 1,
    'enable bypass list management');
}


1;
