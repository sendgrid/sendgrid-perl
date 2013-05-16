package Mail::SendGrid::Transport::REST::Test;

use strict;
use base qw(Test::Class);
use Test::More;

use MIME::Entity;
use Mail::SendGrid;
use Mail::SendGrid::Transport::REST;
use Test::MockObject::Extends;
use URI::Escape;
use Encode;

use Data::Dumper qw(Dumper);

sub getTransport
{
  my %args = @_;

  my $obj = Mail::SendGrid::Transport::REST->new( username => 'u',
                                                  password => 'p' );

  my $mock = Test::MockObject::Extends->new($obj);

  foreach my $arg ( keys(%args) )
  {
    $mock->mock($arg, $args{$arg});
  }

  return $mock;
}

my $fromAddr = 'tim@sendgrid.net';
my $fromName = 'Tim Jenkins';
my $toAddr = 'tim@sendgrid.com';
my $toName = 'Tim Jenkins';
my $from = "$fromName <$fromAddr>";
my $to =  "$toName <$toAddr>";
my $text = 'Some text';
my $html = '<html><body>Some html</body></html>';
my $subject = 'subject';
my $encoding = 'base64';
my $charset = 'utf-8';
my $date = '2010 08 18';

sub getSGObject
{
  my %args = @_;

  my $extra;

  $extra = $args{unicode} if ( $args{unicode} );

  my $sg = Mail::SendGrid->new( from => "$extra$from",
                                to => "$extra$to",
                                subject => "$extra$subject",
                                encoding => $encoding,
                                charset => $charset,
                                text => "$extra$text",
                                html => "$extra$html",
                                'reply-to' => "$extra$to",
                                date => $date,
                              );

  return $sg;
}

sub deliver : Test(no_plan)
{
  my $deliv;
  my $sg;

  $deliv = getTransport( 'send' => sub {
    my $self = shift;
    my $query = shift;

    my ($url, $str) = $query =~ /^([^\?]+)\?(.*)$/;

    my @params = split('&', $str);
    my $p = {};

    foreach my $param (@params)
    {
      my ($key, $value) = split('=', $param);
      $p->{$key} = uri_unescape($value);
    }

    is($p->{api_user}, $deliv->{username}, "username set");
    is($p->{api_key}, $deliv->{password}, "password set");
    is($p->{subject}, $sg->get('subject'), "subject set");
    is($p->{fromname}, $fromName, "from name set");
    is($p->{from}, $fromAddr, "from addr set");
    is($p->{'x-smtpapi'}, $sg->header->asJSON(), "smtp api header set");
    is($p->{html}, $sg->get('html'), "html set");
    is($p->{text}, $sg->get('text'), "text set");
    is($p->{'to[]'}, $toAddr, "to addr set");
    is($p->{'toname[]'}, $toName, "to name set");

    return { "message" => "success" };
  });

  $sg = getSGObject();

  $sg->enableClickTracking();

  my $res = $deliv->deliver($sg);

  is($res, undef, 'normal delivery');
}

sub unicode : Test(8)
{
  my $deliv;
  my $sg;

  my $u = "\x{587}";

  $deliv = getTransport( 'send' => sub {
    my $self = shift;
    my $query = shift;

    my ($url, $str) = $query =~ /^([^\?]+)\?(.*)$/;

    my @params = split('&', $str);
    my $p = {};

    foreach my $param (@params)
    {
      my ($key, $value) = split('=', $param);
      $p->{$key} = uri_unescape($value);
    }

    is($p->{subject}, $sg->get('subject', encode => 1), "unicode subject set");
    is($p->{fromname}, encode('utf-8', "$u$fromName"), "unicode from name set");
    is($p->{from}, $fromAddr, "unicode from addr set");
    is($p->{'x-smtpapi'}, encode('utf-8', $sg->header->asJSON()), "unicode smtp api header set");
    is($p->{html}, $sg->get('html', encode => 1), "unicode html set");
    is($p->{text}, $sg->get('text', encode => 1), "unicode text set");
    is($p->{'to[]'}, $toAddr, "unicode to addr set");
    is($p->{'toname[]'}, encode('utf-8', "$u$toName"), "unicode to name set");

    return { "message" => "success" };
  });

  $sg = getSGObject(unicode => $u);

  $sg->header->setCategory("$u");

  my $res = $deliv->deliver($sg);
}

sub deliveryError : Test
{
  my $deliv = getTransport( 'send' => sub {
    return { message => "error",
             errors => [ "errormsg" ] };
  });

  my $sg = getSGObject();

  $sg->enableClickTracking();

  my $res = $deliv->deliver($sg);

  is($res, "errormsg", 'error handling');
}

1;
