# Copyright (c) 2010 SendGrid

package Mail::SendGrid::Transport::Sendmail;

use strict;
use vars qw($VERSION);

$VERSION = '1.0';

use Sys::Hostname;
use Carp;

sub new
{
  my $class = shift;

  my $self = bless { 'sendmail' => 'sendmail',
                      @_
                   }, $class;

  return $self;
}

sub deliver
{
  my $self = shift;
  my $sg = shift;

  my $mime = $sg->createMimeMessage();
  my $msg = $mime->stringify();

  my $fh;
  eval {
    $fh = $self->openSendmail($sg);
  };
  return $@ if ( $@ );

  print $fh $msg;

  close($fh);

  return undef;
}

sub openSendmail
{
  my $self = shift;
  my $sg = shift;

  my @rcpts = $sg->getRecipients();
  my $from = $sg->getMailFrom();

  open(my $fh, "|$self->{sendmail} -oi -f $from @rcpts") || die "Could not open sendmail: $!";

  return $fh;
}


=head1 NAME

Mail::SendGrid::Transport::Sendmail - Transport class for SendGrid using local sendmail

=head1 SYNOPSIS

  use Mail::SendGrid::Transport::Sendmail;
  use Mail::SendGrid;

  my $sg = Mail::SendGrid->new();
  ...
  my $trans = Mail::SendGrid::Transport::Sendmail' );

  my $error = $trans->deliver($sg);
  die $error if ( $error );

=head1 DESCRIPTION

This is a transport module for sending messages through the SendGrid email
distribution system via your local sendmail application. After you have
completed building your Mail::SendGrid object, use this class to queue
the message to your local system, which should be set up to relay mail
through SendGrid's servers

Using a local queueing mechanism like this is the preferred method to
use SendGrid, since it allows for network issues to be handled while
not complicating your application

Note that despite the name Sendmail, this will work with any MTA that has
a sendmail binary, such as Postfix

=head1 CLASS METHODS

=head2 new[ARGS]

Creates the instance of the class.

If for some reason sendmail is not in your path, you can specify the sendmail
as the sendmail paramter

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