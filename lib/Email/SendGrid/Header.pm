package Email::SendGrid::Header;

use strict;

use JSON;
use MIME::Entity;

sub new
{
  my $class = shift;

  my $self = bless { 'data' => { },
                     @_
                   }, $class;

  return $self;
}

sub addTo
{
  my $self = shift;
  my @to = @_;
  push(@{$self->{data}->{to}}, @to);
}

sub addSubVal
{
  my $self = shift;
  my $var = shift;
  my @val = @_;

  if (!defined($self->{data}->{sub}->{$var}))
  {
    $self->{data}->{sub}->{$var} = [];
  }
  push(@{$self->{data}->{sub}->{$var}}, @val);
}

sub addUniqueIdentifier
{
  my $self = shift;
  my $args;
  if ( scalar(@_) == 1 && ref($_[0]) eq "HASH" )
  {
    $args = $_[0];
  }
  else
  {
    $args = { @_ };
  }

  foreach my $arg ( keys(%{$args}) )
  {
    $self->{data}->{unique_args}->{$arg} = $args->{$arg};
  }
}

sub addSection
{
  my $self = shift;
  my %sections = @_;
  foreach my $sec ( keys(%sections) )
  {
    $self->{data}->{section}->{$sec} = $sections{$sec};
  }
}

sub setCategory
{
  my $self = shift;
  my $cat = shift;
  $self->{data}->{category} = $cat;
}

sub enable
{
  my $self = shift;
  my $filter = shift;

  $self->addFilterSetting($filter, 'enable', 1);
}

sub disable
{
  my $self = shift;
  my $filter = shift;

  $self->addFilterSetting($filter, 'enable', 0);
}

sub addFilterSetting
{
  my $self = shift;
  my $filter = shift;

  my $val = pop;

  if (!defined($self->{data}->{filters}->{$filter}))
  {
    $self->{data}->{filters}->{$filter} = {};
  }
  if (!defined($self->{data}->{filters}->{$filter}->{settings}))
  {
    $self->{data}->{filters}->{$filter}->{settings} = {};
  }

  my $set = $self->{data}->{filters}->{$filter}->{settings};

  while ( my $setting = shift(@_) )
  {
    if ( scalar(@_ ) )
    {
      $set->{$setting} = {} if ( !defined($set->{$setting}) );
      die "Attempt to overwrite setting" if ( ref($set->{$setting}) ne "HASH" );
      $set = $set->{$setting};
    }
    else
    {
      die "Attempt to overwrite hash" if ( ref($set->{$setting}) );
      $set->{$setting} = $val;
    }
  }
}

sub setASMGroupID
{
  my $self = shift;
  my $asmGroupId = shift;
  $self->{data}->{asm_group_id} = $asmGroupId;
}

sub addHeader
{
  my $self = shift;
  my $mime = shift;

  $mime->head->replace('x-smtpapi', $self->asJSON());
  $mime->head->fold('x-smtpapi');
}

sub asJSON
{
  my $self = shift;
  my %args = @_;

  my $json = JSON->new;
  $json->space_before(1);
  $json->space_after(1);
  $json->ascii(1);
  my $str = $json->encode($self->{data});
  if ( $args{fold} )
  {
    my $length = $args{fold};

    $str =~ s/(.{1,$length})(\s)/$1\n$2/g;
  }

  return $str;
}

=head1 NAME

Mail::SendGrid::Header - Functions for building the string necessary for
working with SendGrid's SMTP API

=head1 SYNOPSIS

  use Mail::SendGrid::Header;

  my $hdr = Mail::SendGrid::Header->new();
  $hdr->setCategory('first contact');
  $hdr->addUniqueIdentifier( customer_id => 4 );
  my $str = $hdr->asJSON( fold => 72 );

=head1 DESCRIPTION

This class handles setting the appropriate hash variables to work with
SendGrid's SMTP API. With the SMTP API you can control filters that are
applied to your email, supply additional parameters to identify the message,
and make use of mail merge capabilities.

=head1 CLASS METHODS

=head2 new

Creates a new instance of the class

=head2 addFilterSetting

Allows you to specify a filter setting. You can find a list of filters and
their settings here:
http://wiki.sendgrid.com/doku.php?id=filters

  $hdr->addFilterSetting('twitter', 'username', 'myusername');

=head2 enable

=head2 disable

These are shortcut methods for enabling / disabling a filter. They are
the same as using addFilterSetting on the 'enable' setting.

  $hdr->enable('opentrack');

is the same as

  $hdr->addFilterSetting('opentrack', 'enable', 1)

=head2 setCategory

This sets the category for this email. Statistics are stored on a per
category basis, so this can be useful for tracking on a per group
basis

=head2 addUniqueIdentifier

This adds parameters and values that will be passed back through SendGrid's
Event API if an event notification is triggered by this email

  $hdr->addUniqueIdentifier( customer => 'someone', location => 'somewhere' );

=head2 addSection

This adds sections of text that will be replaced, allowing for common text that will be reused
on multiple recipients to be combined in one location.

  $hdr->addSection( String-in-Substitutions => String-To-replace )

An example of this would look like the following:

$hdr->addSubVal('%body', '%body1%', '%body2%');
$hdr->addSubVal('%name%', 'Tim', 'Joe');
$hdr->addSection('%body1' => "Body text specific unspecific for %name%");
$hdr->addSection('%body2' => "Some other body text, customized for %name%");

=head2 addTo(ARRAY)

This adds recipients for the mail merge functionality. Recipients can be
specified as simply an email address, such as

 'someone@somewhere.com'

or as a full name and address, like

 'Someone Special <someone@somewhere.com>'

This value will be substituted into the To header of the email when it is merged

This functionality can also be used to help decrease the latency caused by the
SMTP protocol when sending the same message to a large number of recipients

=head2 addSubVal(TAG, ARRAY)

This adds a substitution value to be used during the mail merge. Substitutions
will happen in order added, so calls to this should match calls to addTo

  $hdr->addTo('me@myplace.com');
  $hdr->addTo('you@myplace.com');

  $hdr->addSubVal('%name%', 'me', 'you');

=head2 setASMGroupID

This sets the ASM Group ID for this email. Please read the documentation here:
https://sendgrid.com/docs/API_Reference/Web_API_v3/Advanced_Suppression_Manager/index.html

  $hdr->setASMGroupID(123);

=head2 asJSON

Returns the JSON encoded string used to communicate with the SMTP API. It
takes an optional fold paramter specifying the length at which to fold the
header. It is important to fold the header, since most mail servers will
break lines up to keep them shorter than 1,000 characters, which will
introduce spaces into values in the string

=head2 addHeader(MIME Entity)

Shortcut function for adding the x-smtpapi header into a mime entity

=head1 AUTHOR

Tim Jenkins <tim@sendgrid.com>

=cut

1;

