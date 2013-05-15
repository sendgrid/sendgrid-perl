package Mail::SendGrid::Header::Test;

use strict;
use base qw(Test::Class);
use Test::More;

use Mail::SendGrid::Header;
use JSON;

use Data::Dumper qw(Dumper);

sub uniqueAgs : Test(2)
{
  my $hdr = Mail::SendGrid::Header->new();

  $hdr->addUniqueIdentifier( foo => 'bar' );

  ok(scalar(keys(%{$hdr->{data}->{unique_args}})) == 1 &&
     $hdr->{data}->{unique_args}->{foo} eq 'bar', "set unique args");

  $hdr->addUniqueIdentifier( { bar => 'foo' } );
  ok(scalar(keys(%{$hdr->{data}->{unique_args}})) == 2 &&
     $hdr->{data}->{unique_args}->{bar} eq 'foo', "set unique args with hash");

}

sub category : Test
{
  my $category = "foo";

  my $hdr = Mail::SendGrid::Header->new();

  $hdr->setCategory($category);

  is($hdr->{data}->{category}, $category, "set category");
}

sub filterSettings : Test(7)
{
  my $hdr = Mail::SendGrid::Header->new();

  $hdr->addFilterSetting('clicktrack', 'enable', 1);

  is($hdr->{data}->{filters}->{clicktrack}->{settings}->{enable}, 1, "create filter setting");

  $hdr->addFilterSetting('clicktrack', 'enable_text', 1);

  is($hdr->{data}->{filters}->{clicktrack}->{settings}->{enable_text}, 1, "add filter setting");

  # Deep filter settings
  $hdr->addFilterSetting('myf', 'a', 'b', 'c', 1);
  $hdr->addFilterSetting('myf', 'a', 'b', 'd', 2);

  is($hdr->{data}->{filters}->{myf}->{settings}->{a}->{b}->{c}, 1, "deep filter setting");
  is($hdr->{data}->{filters}->{myf}->{settings}->{a}->{b}->{d}, 2, "deep filter setting addition");

  # Try to add a setting for something deep
  eval {
    $hdr->addFilterSetting('myf', 'a', 2);
  };
  ok($@ =~ 'overwrite hash', "attempt to overwrite setting hash");

  # Try to add a hash over a setting
  eval {
    $hdr->addFilterSetting('clicktrack', 'enable', 'a', 1);
  };
  ok($@ =~ 'overwrite setting', "attempt to overwrite hash with setting");

}

sub mailmerge : Test(2)
{
  my $to = 'tim@sendgrid.com';
  my $tag = 'name';
  my $val = 'Tim Jenkins';

  my $hdr = Mail::SendGrid::Header->new();

  $hdr->addTo($to);

  is($hdr->{data}->{to}->[0], $to, 'set to address');

  $hdr->addSubVal($tag, $val);

  is($hdr->{data}->{'sub'}->{$tag}->[0], $val, "set substitution value");
}

sub enabledisable : Test(2)
{
  my $hdr = Mail::SendGrid::Header->new();

  $hdr->enable('clicktrack');

  is($hdr->{data}->{filters}->{clicktrack}->{settings}->{enable}, 1, "enable filter");

  $hdr->disable('clicktrack');

  is($hdr->{data}->{filters}->{clicktrack}->{settings}->{enable}, 0, "disable filter");
}

sub json : Test(2)
{
  my $filt = { filters =>
              { 'a' => { 'settings' => {'a' => 1}},
               'b' => { 'settings' => {'b' => 2, 'a' => 'foobarrrrr'}},
               'c' => { 'settings' => {'str' => 'thisisaverylongstringthatdoesnothaveanyspacesinit'}}
              }
  };

  my $filtJson = to_json($filt);

  my $hdr = Mail::SendGrid::Header->new( data => $filt);

  my $length = 30;

  my $json = $hdr->asJSON( fold => $length );

  # Convert the returned string back into an object, then back to json for string comparison
  my $jsonStr = to_json(from_json($json));

  is($jsonStr, $filtJson, 'proper json conversion');

  my @lines = split('\n', $json);

  my $properFold = 1;

  foreach my $line ( @lines )
  {
    $properFold = 0 if ( !(length($line) < $length+3 ||
                           $line =~ $filt->{filters}->{c}->{settings}->{str}) );
  }

  is($properFold, 1, "proper folding");
}




1;

