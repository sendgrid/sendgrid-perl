# Copyright(c) 2010 SendGrid

package Mail::SendGrid;

use strict;
use vars qw($VERSION);

$VERSION = '1.0';

use Mail::SendGrid::Header;
use Mail::Address;
use Encode;
use MIME::Words qw(encode_mimeword decode_mimewords);

use Carp;

sub new
{
  my $class = shift;

  my $self = bless { header => Mail::SendGrid::Header->new(),
                     rcpts => [],
                     to => [],
                     cc => [],
                     bcc => [],
                     attachments => [],
                     encoding => 'quoted-printable',
                     charset => 'UTF-8',
                     @_ }, $class;

  return $self;
}


sub header
{
  my $self = shift;
  return $self->{header};
}

sub addTo
{
  my $self = shift;
  my @rcpts = @_;
  push(@{$self->{to}}, @rcpts);
}

sub addCc
{
  my $self = shift;
  my @rcpts = @_;
  push(@{$self->{cc}}, @rcpts);
}

sub addBcc
{
  my $self = shift;
  my @rcpts = @_;
  push(@{$self->{bcc}}, @rcpts);
}

sub addRcpts
{
  my $self = shift;
  my @rcpts = @_;

  foreach my $rcpt (@rcpts)
  {
    my ($addr) = Mail::Address->parse($rcpt);
    my $to = $addr->address();
    push(@{$self->{rcpts}}, $to);
  }
}

sub get
{
  my $self = shift;
  my $field = shift;
  my %args = @_;

  my $fields = { date => 1, text => 1, html => 1, subject => 1, from => 1, 'reply-to' => 1,
                 encoding => 1, charset => 1, attachments => 1, mail_from => 1,
                 to => 1, cc => 1, bcc => 1 };

  croak "Unknown field '$field'" if ( !defined($fields->{$field}) );

  my $ret = $self->{$field};
  $ret = encode($self->{charset}, $ret) if ( $args{'encode'} );

  return $ret;
}

sub set
{
  my $self = shift;
  my $field = shift;
  my $val = shift;

  my $fields = { date => 1, text => 1, html => 1, subject => 1, from => 1, 'reply-to' => 1,
                 encoding => 1, charset => 1, attachments => 1 };

  croak "Unknown field '$field'" if ( !defined($fields->{$field}) );

  $self->{$field} = $val;
}

sub addAttachment
{
  my $self = shift;
  my $attach = shift;
  push(@{$self->{attachments}}, { data => $attach, @_ });
}

sub getMailFrom
{
  my $self = shift;
  my ($addr) = Mail::Address->parse($self->{from});
  my $mailFrom = $addr->address();
  return $mailFrom
}

sub createMimeMessage
{
  my $self = shift;

  my $mime;

  if ( !defined($self->{text}) && !defined($self->{html}) )
  {
    croak "No message data specified";
  }

  my $text = $self->{text};
  my $html = $self->{html};

  $text = encode($self->{charset}, $self->{text}) if ( $self->{text} && utf8::is_utf8($self->{text}) );
  $html = encode($self->{charset}, $self->{html}) if ( $self->{html} && utf8::is_utf8($self->{html}) );

  if ( defined($text) && defined($html) )
  {
    $mime = MIME::Entity->build( Type => 'multipart/alternative' );

    $mime->attach(Type => 'text/plain',
                  Encoding => $self->{encoding},
                  Charset => $self->{charset},
                  Data => $text);

    $mime->attach(Type => 'text/html',
                  Encoding => $self->{encoding},
                  Charset => $self->{charset},
                  Data => $html);
  }
  elsif ( defined($self->{text}) )
  {
    $mime = MIME::Entity->build(Type => 'text/plain',
                                Encoding => $self->{encoding},
                                Charset => $self->{charset},
                                Data => $text);
  }
  else
  {
    $mime = MIME::Entity->build(Type => 'text/html',
                                Encoding => $self->{encoding},
                                Charset => $self->{charset},
                                Data => $html);
  }

  foreach my $attach ( @{$self->{attachments}} )
  {
    my $data = $attach->{data};
    my %params;

    if ( -f $data )
    {
      $params{Path} = $data;
    }
    else
    {
      $params{Data} = $data;
    }
    $params{Type} = $attach->{type} if ( defined($attach->{type}) );
    $params{Encoding} = $attach->{encoding} if ( defined($attach->{encoding}) );

    $mime->attach( %params );
  }

  if ( defined($self->{subject}) )
  {
    $mime->head->replace('subject', $self->encodeHeader($self->{subject}));
  }

  if ( defined($self->{from}) )
  {
    $mime->head->replace('from', $self->encodeHeader($self->{from}));
  }

  if ( defined($self->{date}) )
  {
    $mime->head->replace('date', $self->encodeHeader($self->{date}));
  }

  if ( defined($self->{'message-id'}) )
  {
    $mime->head->replace('message-id', $self->{'message-id'});
  }

  if ( defined($self->{'reply-to'}) )
  {
    $mime->head->replace('reply-to', $self->encodeHeader($self->{'reply-to'}));
  }

  $self->mergeAddresses($mime, 'to');
  $self->mergeAddresses($mime, 'cc');

  if ( keys(%{$self->header->{data}}) )
  {
    $mime->head->replace('x-smtpapi', $self->header->asJSON( fold => 72 ));
  }

  return $mime;
}

sub mergeAddresses
{
  my $self = shift;
  my $mime = shift;
  my $field = shift;

  if ( defined($self->{$field}) )
  {
    my $str = $self->{$field};

    if ( ref($self->{$field}) eq "ARRAY" )
    {
      $str = '';
      foreach my $addr (@{$self->{$field}})
      {
        $str .= "$addr, ";
      }
      # Remove the trailing , on the last entry
      chop($str);
      chop($str);
    }

    # If we had any addresses to put here, do so
    if ( $str )
    {
      $mime->head->replace($field, $self->encodeHeader($str));
    }
  }
}

sub getRecipients
{
  my $self = shift;
  my @rcpts = $self->extractRecipients('to');
  push(@rcpts, $self->extractRecipients('cc'));
  push(@rcpts, $self->extractRecipients('bcc'));
  return @rcpts;
}

sub extractRecipients
{
  my $self = shift;
  my $field = shift;

  my @list;
  if ( ref($self->{$field}) ne "ARRAY" )
  {
    $self->{$field} = [ $self->{$field} ];
  }

  foreach my $addr ( @{$self->{$field}} )
  {
    my @addrs = Mail::Address->parse($addr);

    foreach my $ad ( @addrs )
    {
      my $a = $ad->address();
      if ( $a )
      {
        push(@list, $a);
      }
    }
  }

  return @list;
}

# This returns a string with proper MIME header encoding
sub encodeHeader
{
  my $self = shift;
  my $header = shift;

  my $str = $header;

  # First, if the thing is unicode, downgrade it
  if ( utf8::is_utf8($header) )
  {
    $str = encode($self->{charset}, $str);
  }

  # If the string is not 7bit clean, encode the header.
  if ( my $count = () = $str =~ /[^\x00-\x7f]/g )
  {
    my $type = 'q';
    # If the number of characters to be encoded is over 6, use base 64
    $type = 'b' if ( $count > 6 );

    $str = encode_mimeword($str, $type, $self->{charset});
  }

  return $str;
}


#############################################################
# Convienience functions for working with the api

# Make the filter map something that can be exported so new filters can be added on the fly
our $filterMap = { 'Gravatar' => { filter => 'gravatar' },
                   'OpenTracking' => { filter => 'opentrack' },
                   'ClickTracking' => { filter => 'clicktrack',
                                        settings => {
                                          shorten => {
                                            setting => 'shorten',
                                            },
                                          text => {
                                            setting => 'enable_text'
                                          }
                                        }
                   },
                   'SpamCheck' => { filter => 'spamcheck',
                                    settings => {
                                      score => {
                                        setting => 'maxscore',
                                      },
                                      url => {
                                        setting => 'url'
                                      }
                                    }
                   },
                   'Unsubscribe' => {
                     filter => 'subscriptiontrack',
                     settings => {
                       text => {
                         setting => 'text/plain',
                         validation => sub {
                           croak "Missing substitution tag in text" if ( $_[0] !~ /<\%\s*\%>/ );
                         }
                       },
                       html => {
                         setting => 'text/html',
                         validation => sub {
                           croak "Missing substitution tag in html" if ( $_[0] !~ /<\%\s*[^\s]+\s*\%>/ );
                         }
                       },
                       replace => {
                         setting => 'replace',
                       },
                     },
                   },
                   'Footer' => {
                     filter => 'footer',
                     settings => {
                       text => { setting => 'text/plain' },
                       html => { setting => 'text/html' },
                     },
                   },
                   'GoogleAnalytics' => {
                     filter => 'ganalytics',
                     settings => {
                       source => { setting => 'utm_source' },
                       medium => { setting => 'utm_medium' },
                       term => { setting => 'utm_term' },
                       content => { setting => 'utm_content' },
                       campaign => { setting => 'utm_campaign' },
                     },
                   },
                   'DomainKeys' => {
                     filter => 'domainkeys',
                     settings => {
                       domain => { setting => 'domain' },
                       sender => { setting => 'sender' },
                     },
                   },
                   'DKIM' => {
                     filter => 'dkim',
                     settings => {
                       domain => { setting => 'domain' },
                       use_from => { setting => 'use_from' },
                     },
                   },
                   'Template' => {
                     filter => 'template',
                     validation => sub {
                       my %args = @_;
                       croak 'Missing html template' if ( !defined($args{html}) );
                     },
                     settings => {
                       html => {
                         setting => 'text/html',
                         validation => sub {
                           croak "Missing body substitution tag in template" if ( $_[0] !~ /<\%\s*\%>/ );
                         },
                       },
                     },
                   },
                   'Twitter' => {
                     filter => 'twitter',
                     validation => sub {
                       my %args = @_;
                       croak 'Missing twitter username' if ( !defined($args{username}) );
                       croak 'Missing twitter password' if ( !defined($args{password}) );
                     },
                     settings => {
                       username => { setting => 'username' },
                       password => { setting => 'password' },
                     },
                   },
                   'Bcc' => {
                     filter => 'bcc',
                     validation => sub {
                       my %args = @_;
                       croak 'Missing bcc email' if ( !defined($args{email}) );
                     },
                     settings => {
                       email => { setting => 'email' },
                     },
                   },
                   'BypassListManagement' => {
                     filter => 'bypass_list_management',
                   },
                   'Hold' => {
                     filter => 'hold',
                   },
                   'Drop' => {
                     filter => 'drop',
                   }
    };

our $AUTOLOAD;

# We autoload all of the filters and how their settings map to the smtpapi via the map above
sub AUTOLOAD
{
  my $self = shift;

  my $type = ref ($self) || croak "$self is not an object";
  my $func = $AUTOLOAD;
  $func =~ s/.*://;

  if ( $func =~ /^disable(.*)/ )
  {
    my $filterFunc = $1;

    my $filter = $filterMap->{$filterFunc}->{filter};

    croak "Unknown filter function '$func'" if ( !defined($filter) );
    $self->header->disable($filter);
  }
  elsif ( $func =~ /^enable(.*)/ )
  {
    my $filterFunc = $1;
    my %args = @_;

    my $filterData = $filterMap->{$filterFunc};
    $filterData->{validation}(%args) if ( defined($filterData->{validation}) );

    my $filter = $filterData->{filter};
    croak "Unknown filter function '$func'" if ( !defined($filter) );

    $self->header->enable($filter);
    foreach my $set ( keys(%args) )
    {
      my $filtSet = $filterData->{settings}->{$set};
      croak "Unknown filter setting '$set'" if ( !defined($filtSet) );
      $filtSet->{validation}($args{$set}) if ( defined($filtSet->{validation}) );

      $self->header->addFilterSetting($filter, $filtSet->{setting}, $args{$set});
    }
  }
  else
  {
    croak "Unknown subroutine '$func'";
  }
}

# Have to define so that AUTOLOAD doesn't eat this
sub DESTROY
{
}

=head1 NAME

Mail::SendGrid - Class for building a message to be sent through the SendGrid
mail service

=head1 SYNOPSIS

    use Mail::SendGrid

    my $sg = Mail::SendGrid->new( from => $from,
                                  to => $to,
                                  subject => 'Testing',
                                  text => "Some text http://sendgrid.com/\n",
                                  html => '<html><body>Some html
                                                      <a href="http://sendgrid.com">SG</a>
                                           </body></html>',
                              );

    $sg->disableClickTracking();
    $sg->enableUnsubscribe( text => "Unsubscribe here: <% %>", html => "Unsubscribe <% here %>" );

=head1 DESCRIPTION

This module allows for easy integration with the SendGrid email distribution
service and its SMTP API. It allows you to build up the pieces that make the
email itself, and then pass this object to the Mail::SendGrid::Transport class
that you wish to use for final delivery.

=head1 CLASS METHODS

=head2 Creation

=head3 new[ARGS]

This creates the object and optionally populates some of the data fields. Available fields are:

=over

=item from

The From address to use in the email

  from => 'Your Name <you@yourcompany.com>'

=item to

Either a string or ARRAYREF containing the addresses to send to

  to => 'Your Customer <them@theircompany.com>, Another Customer <someone@somewhereelse.com>'

  to => [ them@theircompany.com, someone@somewhereelse.com ]

=item cc

Adds additional recipients for the email and sets the CC field of the email

=item bcc

Adds additional recipients whose addresses will not appear in the headers of
the email

=item subject

Sets the subject for the message

=item date

Sets the date header for the message. If this is not specified, the current
date will be used

=item message-id

Sets the message id header. If this is not specified, one will be randomly
generated

=item encoding

Sets the encoding for the email. Options are 7bit, base64, binary, and
quoted-printable.
Quoted printable is the default encoding

=item charset

Sets the default character set. iso-8859-1 (latin1) is the default
If you will be using wide characters, it is expected that the strings
passed in will already be encoded with this charset

=item text

Sets the data for the plain text portion of the email

=item html

Sets the data for the html portion of the email

=back

=head2 Methods for setting data

=head3 addTo(LIST)

=head3 addCc(LIST)

=head3 addBcc(LIST)

Inserts additional recipients for the message

=head3 get(PARAMETER)

=head3 set(PARAMETER, VALUE)

Returns / sets a parameter for this message. Parameters are the same as those
in the new method

=head3 addAttachment(DATA, [OPTIONS])

Specifies an attachment for the email. This can either be the data for the
attachment, or a file to attach

While the underlying MIME::Entity that will be created will try to determine
the best encoding and MIME type, you can also specify it in the options

  $sg->addAttachment('/tmp/my.pdf',
                      type => 'application/pdf',
                      encoding => 'base64');

=head2 SMTP API functions

This class contains a number of methods for working with the SMTP API. The
SMTP API allows for customization of SendGrid filters on an individual
basis for emails. For more information about the api, please visit
http://wiki.sendgrid.com/doku.php?id=smtp_api

=head3 header

Returns a reference to the Mail::SendGrid::Header object used to communicate
with the SMTP API. Useful if you want to set unique identifiers or use the
mail merge functionality

=head3 enableGravatar

=head3 disableGravatar

Enable / disable the addition of a gravatar in the email

=head3 enableClickTracking

=head3 disableClickTracking

Enables / disables click tracking for emails. By default this will only
enable click tracking for the html portion of emails. If you want to
also do click tracking on plain text, you can use the addition prameter 'text'
  $sg->enableClickTracking( text => 1 );

=head3 enableUnsubscribe

=head3 disableUnsubscribe

Enables / disables the addition of subscription management headers / links
in the email.

If no arguments are specified for enable, only a list-unsubscribe header
will be added to the email. Additional parameters are:

=over

=item text

The string to be added to the plain text portion of the email. This must
contain the string <% %>, which is where the link will be placed

=item html

The string to be added to the html portion of the email. This must contain a
tag with the format "<% link text %>", which will be replaced with the link

=item replace

A string inside of the email body to replace with the unsubscribe link. If
this tag is not found in the body of the email, then the appropriate text or
html setting will be used. If none of these are found, a link will not be
inserted

  $sg->enableUnsubscribe( text => 'Unsubscribe here: <% %>',
                          html => 'Unsubscribe <% here %>',
                          replace => 'MyUnsubscribeTag' );

=back

=head3 enableOpenTracking

=head3 disableOpenTracking

Enables / disables open tracking

=head3 enableFooter

=head3 disableFooter

Enables / disables the insertion of a footer in this email.

Parameters are:

=over

=item text

String to insert into the plain text portion of the email

=item html

String to insert into the html portion of the email

  $sg->enableFooter( text => 'Text footer', html => 'Html footer' );

=back

=head3 enableSpamCheck

=head3 disableSpamCheck

Enables / disables the checking of email for spam content. This is useful when
you are sending content that is generated by your users, such as a forum

Parameters are:

=over

=item score

Spam Assassin score at which point the email will be flagged as spam and
dropped. If this is not specified, 5 will be used

=item url

A url to post to in the event that the message is flagged as spam and dropped.

=back

=head3 enableGoogleAnalytics

=head3 disabelGoogleAnalytics

Enables / disables link rewrites to support Google Analytics.

Paramters are:

=over

=item source

Sets the string for the utm_source field

=item medium

Sets the string for the utm_medium field

=item term

Sets the string for the utm_term field

=item content

Sets the string for the utm_content field

=item campaign

Sets the string for the utm_campaign field

=back

=head3 enableDomainKeys

=head3 disableDomainKeys

Enables / disables Domain Keys signatures for the message.

Domain Keys is a digitial signature method, primarily used by Yahoo.

Parameters are:

=over

=item domain

The domain to sign the messages as. This domain must be set up with the proper
DNS records, which can be found when going through the whitelabel wizard

=item sender

Sets if SendGrid will add a Sender header if the From email address does not
match the specified domain. This allows for messages to still have a valid
DomainKeys signature if the email address in the From field does not have
whitelabeling set up, however it means that some email clients will display
the message as "on behalf of" the From address

=back

=head3 enableTemplate

=head3 disableTemplate

Enables / disables the insertion of an email template. If you are enabling a
template, you must specify the text of it in the html parameter. This
text must contain the string "<% %>", which will be replaced with the body
of the message

=head3 enableTwitter

Allows you to set twitter username / password information for this email.
The Twitter filter can be used to send either status updates or direct
messages, based on the recipient email address

  my $sg = Mail::SendGrid->new( to => 'sendgrid@twitter', text => "My update" );

  $sg->enableTwitter( username => 'myusername', password => 'mypassword' );

=head3 enableBcc

=head3 disableBcc

Enables / disables the automatic blind carbon copy of the email to a specific
email address. While it makes little sense to enable a bcc here, versus adding
it as a Bcc with the methods discussed previously, you can specify an email
paramter which is the address to send to

=head3 enableBypassListManagement

Allows you to specify that this email should not be suppressed for any reason,
including the address appearing on the bounce, unsubscribe, or spam report
suppression lists. This is useful for urgent emails, such as password reset
notifications, that should always be attempted for delivery.

=head2 Transport methods

If you don't want to use one of the Mail::SendGrid::Transport classes, or
want to build your own, these methods are used to get the data for transport

=head3 createMimeMessage

Returns a MIME::Entity for the email

=head3 getMailFrom

Returns the address to be used in the MAIL FROM portion of the SMTP protocol

=head3 getRecipients

Returns an array of the recipient address for the email, to be used in the
RCPT TO portion of the SMTP protocol

=head1 AUTHOR

Tim Jenkins <tim@sendgrid.com>

=head1 COPYRIGHT

Copyright (c) 2010 SendGrid. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
