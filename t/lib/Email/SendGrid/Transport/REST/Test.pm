package Email::SendGrid::Transport::REST::Test;

use strict;
use base qw(Test::Class);
use Test::More;
use Test::Deep;

use MIME::Entity;
use Email::SendGrid;
use Email::SendGrid::Transport::REST;
use Test::MockObject::Extends;
use Test::MockModule;
use URI::Escape;
use Encode;
use JSON;
use Data::Dumper qw(Dumper);

sub getTransport
{
  my %args = @_;

  my $obj = Email::SendGrid::Transport::REST->new( username => 'u',
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
my $messageId = "1234";

sub getSGObject
{
  my %args = @_;

  my $extra;

  $extra = $args{unicode} if ( $args{unicode} );

  my $sg = Email::SendGrid->new( from => "$extra$from",
                                to => "$extra$to",
                                subject => "$extra$subject",
                                encoding => $encoding,
                                charset => $charset,
                                text => "$extra$text",
                                html => "$extra$html",
                                'reply-to' => "$extra$to",
                                "message-id" => $messageId,
                                date => $date,
                              );

  return $sg;
}

sub create : Test(no_plan)
{
  eval {
    my $trans = Email::SendGrid::Transport::REST->new( username => 'u' );
  };
  ok($@ =~ /Must speicfy username\/password or api key at/, "only providing username generated error");

  eval {
    my $trans = Email::SendGrid::Transport::REST->new( password => 'u' );
  };
  ok($@ =~ /Must speicfy username\/password or api key at/, "only providing password generated error");

  eval {
    my $trans = Email::SendGrid::Transport::REST->new( username => 'u', api_key => 'k' );
  };
  ok($@ =~ /Must only specify username\/password or api key, not both at/, "providing username and api key generated error");

}

sub deliver : Test(no_plan)
{
  my $deliv;
  my $sg;
  my $attachData = "my attachment";
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

    my $hdrs = from_json($p->{headers});
    cmp_deeply($hdrs, { "message-id" => $messageId }, "headers are included");
    is($p->{"files[attachment1]"}, $attachData, "attachment included");
    return { "message" => "success" };
  });

  $sg = getSGObject();
  $sg->addAttachment($attachData);
  $sg->enableClickTracking();

  my $res = $deliv->deliver($sg);

  is($res, undef, 'normal delivery');
}

sub unicode : Test(9)
{
  my $deliv;
  my $sg;

  my $u = "\x{587}";
  my $binaryAttachData = chr(0xE4);

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
    is($p->{"files[attachment1]"}, $binaryAttachData, "attachment included");

    return { "message" => "success" };
  });

  $sg = getSGObject(unicode => $u);

  $sg->header->setCategory("$u");
  $sg->addAttachment($binaryAttachData);

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

sub send_up : Test(no_plan)
{
  my $deliv = Test::MockObject::Extends->new(Email::SendGrid::Transport::REST->new(username => 'u', password => 'p'));
  my $content = { value => 1 };
  my $response = HTTP::Response->new('200', "ok", [], to_json($content));
  my $mm = Test::MockModule->new('LWP::UserAgent');
  my $obj;
  $mm->mock('new' => sub {
    $obj = Test::MockObject->new();
    $obj->set_always('default_header' => 1);
    $obj->mock('get' => sub { return $response } );
    return $obj;
    });

  my $query = "query";
  my $resp = $deliv->send($query);

  cmp_deeply($resp, $content, "sent");
  my ($func, $args) = $obj->next_call();
  is($func, 'get', "made call to get");
  shift(@$args);
  cmp_deeply($args, [$query], " with proper args");
  
  ($func, $args) = $obj->next_call();
  is($func, undef, "all lwp calls accounted for");

  $response = HTTP::Response->new('403', 'bad error');
  $resp = $deliv->send($query);
  cmp_deeply($resp, {errors => ['403 bad error']}, "error returned" );

  ($func, $args) = $obj->next_call();
  is($func, 'get', "made call to get");
  shift(@$args);
  cmp_deeply($args, [$query], " with proper args");
  
  ($func, $args) = $obj->next_call();
  is($func, undef, "all lwp calls accounted for");

}

sub send_apikey : Test(no_plan)
{
  my $deliv = Test::MockObject::Extends->new(Email::SendGrid::Transport::REST->new(api_key => 'k'));
  my $content = { value => 1 };
  my $response = HTTP::Response->new('200', "ok", [], to_json($content));
  my $mm = Test::MockModule->new('LWP::UserAgent');
  my $obj;
  $mm->mock('new' => sub {
    $obj = Test::MockObject->new();
    $obj->set_always('default_header' => 1);
    $obj->mock('get' => sub { return $response } );
    return $obj;
    });

  my $query = "query";
  my $resp = $deliv->send($query);

  cmp_deeply($resp, $content, "sent");
  my ($func, $args) = $obj->next_call();
  is($func, 'default_header', "made call to set header");
  shift(@$args);
  cmp_deeply($args,['Authorization','Bearer k'], " with proper api key header");

  ($func, $args) = $obj->next_call();  
  is($func, 'get', "made call to get");
  shift(@$args);
  cmp_deeply($args, [$query], " with proper args");
  
  ($func, $args) = $obj->next_call();
  is($func, undef, "all lwp calls accounted for");

  $response = HTTP::Response->new('403', 'bad error');
  $resp = $deliv->send($query);
  cmp_deeply($resp, {errors => ['403 bad error']}, "error returned" );

  ($func, $args) = $obj->next_call();
  is($func, 'default_header', "made call to set header");
  shift(@$args);
  cmp_deeply($args,['Authorization','Bearer k'], " with proper api key header");

  ($func, $args) = $obj->next_call();
  is($func, 'get', "made call to get");
  shift(@$args);
  cmp_deeply($args, [$query], " with proper args");
  
  ($func, $args) = $obj->next_call();
  is($func, undef, "all lwp calls accounted for");

}
1;
