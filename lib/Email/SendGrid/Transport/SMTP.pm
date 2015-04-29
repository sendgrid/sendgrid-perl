# Copyright (c) 2010 SendGrid

package Email::SendGrid::Transport::SMTP;

use strict;
use warnings;
use vars qw($VERSION);

$VERSION = '1.3';

use Net::SMTP::TLS;
use Sys::Hostname;
use Carp;

sub new
{
  my $class = shift;

  my $self = bless { server => 'smtp.sendgrid.net',
                     timeout => 30,
                     port => 587,
                     tls => 1,
                     smtp_class => 'Net::SMTP::TLS',
                     @_ }, $class;

  if ( !defined($self->{domain}) )
  {
    $self->{domain} = hostname();
  }

  croak "TLS is required for port 587" if ( !$self->{tls} && $self->{port} == 587 );

  if ( defined($self->{username}) && defined($self->{api_key}) )
  {
    die "Must only specify username/password or api key, not both";
  }

  if ( !(defined($self->{username}) && defined($self->{password})) && !defined($self->{api_key}) )
  {
    die "Must speicfy username/password or api key";
  }

  if ( defined($self->{api_key}) )
  {
    $self->{username} = "apikey";
    $self->{password} = delete $self->{api_key};
  }  
  return $self;
}

sub deliver
{
  my $self = shift;
  my $sg = shift;

  my $mime = $sg->createMimeMessage();
  my $msg = $mime->stringify();
  my @rcpts = $sg->getRecipients();
  my $from = $sg->getMailFrom();

  croak "Must specify a from address" if ( !defined($from) );
  croak "Must specify at least one recipient" if ( scalar(@rcpts) == 0 );

  eval {

  my $smtp = $self->{smtp_class}->new($self->{server},
                                      Port => $self->{port},
                                      NoTLS => !$self->{tls},
                                      Debug => 0,
                                      Timeout => $self->{timeout},
                                      User => $self->{username},
                                      Password => $self->{password},
                                      Hello => $self->{domain},
                                      %{$self->{smtp_params}});

    $smtp->mail($from);
    foreach my $rcpt ( @rcpts )
    {
      $smtp->to($rcpt);
    }

    $smtp->data();
    $smtp->datasend($msg);
    $smtp->dataend();
    # We'll try to be nice and shutdown the correct way, but if there is an error ignore it
    eval {
      $smtp->quit();
    }
  };
  if ( $@ )
  {
    return ($@);
  }

  return undef;
}

=head1 NAME

Email::SendGrid::Transport::SMTP - SMTP Transport class to SendGrid

=head1 SYNOPSIS

  use Email::SendGrid::Transport::SMTP;
  use Email::SendGrid;

  my $sg = Email::SendGrid->new();
  ...
  my $trans = Email::SendGrid::Transport::SMTP->new( username => 'mysuername',
                                                    password => 'mypassword' );

  my $error = $trans->deliver($sg);
  die $error if ( $error );

=head1 DESCRIPTION

This is a transport module for sending messages through the SendGrid email
distribution system via SMTP. After you have completed building your
Email::SendGrid object, use this class to make a connection to SendGrid's
SMTP servers and deliver the message.

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

=item api_key

Your SendGrid API key

=item server

The server to connect to (default is smtp.sendgrid.net)

=item port

The port to connect to (default is 587)

=item tls

If you want to use TLS encyption. Default is 1. If you do not want to use
encyption, you should specify the port as 25.

=item timeout

Connection timeout, in seconds (default is 30)

=item domain

The domain to use during the HELO portion of the SMTP protocol. Default is
to use the local system hostname

=back

=head2 deliver(object)

Delivers the Email::SendGrid object specified. This will return undef on
success, and the failure reason on error

=head1 AUTHOR

Tim Jenkins <tim@sendgrid.com>

=head1 COPYRIGHT

Copyright (c) 2010 SendGrid. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
=cut

1;
