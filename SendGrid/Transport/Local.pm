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
    $fh = $self->openSendmail();
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
