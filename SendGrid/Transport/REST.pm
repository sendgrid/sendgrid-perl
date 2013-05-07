# Copyright (c) 2010 SendGrid

package Mail::SendGrid::Transport::REST;

use strict;
use vars qw($VERSION);

$VERSION = '1.0';

use LWP::UserAgent;
use Mail::Address;
use Sys::Hostname;
use URI::Escape;
use JSON;
use Encode;
use Carp;

use Data::Dumper qw(Dumper);

sub new
{
  my $class = shift;

  my $self = bless { server => 'sendgrid.com',
                     path => '/api/mail.send.json',
                     timeout => 30,
                     @_,
                    }, $class;

  return $self;
}

sub deliver
{
  my $self = shift;
  my $sg = shift;

  # Get the character set for encoding
  my $charset = $sg->get('charset');

  # Get the from fields
  my $from = $sg->get('from');

  my ($addr) = Mail::Address->parse($from);

  my $fromName = $addr->name();
  $fromName = encode($charset, $fromName) if ( utf8::is_utf8($fromName) );

  my $fromAddr = $addr->address();

  # Get the To fields.
  my ($toAddr, $toName) = $self->splitAddresses($sg->get('to'));

  # Do a sanity check on the argument lengths
  if ( scalar(@$toName) && scalar(@$toName) != scalar(@$toAddr) )
  {
    croak "There are an inconsistant number of recipients in the to field" .
          "that have names, which is incompatible with the REST API";
  }

  my $subject = $sg->get('subject', encode => 1);
  my $text = $sg->get('text', encode => 1);
  my $html = $sg->get('html', encode => 1);
  my $date = $sg->get('date', encode => 1);
  my $reply = $sg->get('reply-to', encode => 1);

  # Build the query

  my $query = 'https://' . $self->{server} . $self->{path} . "?";
  $query .= "api_user=" . uri_escape($self->{username}) . "&api_key=" . uri_escape($self->{password});

  # Add recipients
  foreach my $i ( 0..(scalar(@$toAddr)-1) )
  {
    $query .= "&to[]=$toAddr->[$i]";
    my $name = $toName->[$i];
    $name = encode($charset, $name) if ( utf8::is_utf8($name) );
    $query .= "&toname[]=" . uri_escape($name) if ( $name );
  }

  # Add the from
  $query .= "&from=$fromAddr";
  $query .= "&fromname=" . uri_escape($fromName) if ( defined($fromName) );

  # Add the subject
  $query .= "&subject=" . uri_escape($subject);

  # Add the reply to
  $query .= "&replyto=" . uri_escape($reply) if ( defined($reply) );

  # Date
  $query .= "&date=" . uri_escape($date) if ( defined($date) );

  # smtp api header
  my $hdr = $sg->header()->asJSON();
  $hdr = encode($charset, $hdr) if ( utf8::is_utf8($hdr) );

  $query .= "&x-smtpapi=" . uri_escape($hdr) if ( $hdr ne "{}" );

  # Text
  $query .= "&text=" . uri_escape($text) if ( defined($text) );

  # html
  $query .= "&html=" . uri_escape($html) if ( defined($html) );

  my $resp = $self->send($query);

  return undef if ( $resp->{message} eq "success" );

  return $resp->{errors}->[0];
}

sub send
{
  my $self = shift;
  my $query = shift;

  my $ua = LWP::UserAgent->new( timeout => $self->{timeout} );

  my $response = $ua->get($query);

  return { errors => [ $response->status_line() ] } if ( !$response->is_success );

  my $content = $response->decoded_content();

  my $resp;

  eval {
    $resp = from_json($content);
  };
  if ( $@ )
  {
    croak "malformed json response: $@";
  }

  return $resp;
}

sub splitAddresses
{
  my $self = shift;
  my $field = shift;

  my $str = $field;

  my @ad;
  my @name;

  if ( ref($field) eq "ARRAY" )
  {
    $str = '';
    foreach my $addr (@$field)
    {
      $str .= "$addr, ";
    }
    # Remove the trailing , on the last entry
    chop($str);
    chop($str);
  }

  my @addrs = Mail::Address->parse($str);
  foreach my $addr ( @addrs )
  {
    push(@ad, $addr->address());
    push(@name, $addr->name()) if ( $addr->name() );
  }

  return (\@ad, \@name);
}


=head1 NAME

Mail::SendGrid::Transport::REST - REST Transport class to SendGrid

=head1 SYNOPSIS

  use Mail::SendGrid::Transport::REST;
  use Mail::SendGrid;

  my $sg = Mail::SendGrid->new();
  ...
  my $trans = Mail::SendGrid::Transport::REST->new( username => 'mysuername',
                                                    password => 'mypassword' );

  my $error = $trans->deliver($sg);
  die $error if ( $error );

=head1 DESCRIPTION

This is a transport module for sending messages through the SendGrid email
distribution system via a REST API. After you have completed building your
Mail::SendGrid object, use this class to make a connection to SendGrid's
web servers and deliver the message.

=head1 CLASS METHODS

=head2 new[ARGS]

Creates the instance of the class. At a minimum you must specify the username
and password used to connect.

Parameters are:

=over

=item username

Your SendGrid username

=item password

Your SendGrid password

=item server

The server to connect to (default is sendgrid.com)

=item path

The path portion of the url (default is /api/mail.send.json)

=item timeout

Connection timeout, in seconds (default is 30)

=back

=head2 deliver(object)

Delivers the Mail::SendGrid object specified. This will return undef on
success, and the failure reason on error

=head1 AUTHOR

Tim Jenkins <tim@sendgrid.com>

=head1 COPYRIGHT

Copyright (c) 2010 SendGrid. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;