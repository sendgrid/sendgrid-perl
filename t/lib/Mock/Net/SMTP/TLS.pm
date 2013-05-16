package Mock::Net::SMTP::TLS;

use strict;
use Data::Dumper qw(Dumper);
use Carp;

our $AUTOLOAD;

sub create
{
  my $this = shift;
  my $class = ref($this) || $this;

  my $self = bless{
                    new => sub { return $_[0]; },
                    mail => sub { return 1; },
                    to => sub { return 1; },
                    data => sub { return 1; },
                    datasend => sub { return 1; },
                    dataend => sub { return 1; },
                    quit => sub { return 1; },
                    @_ }, $class;

    return $self;
}

# Autload functions for all the methods we have objects for
sub AUTOLOAD
{
   my $self = shift;

   my $type = ref ($self) || croak "$self is not an object";
   my $field = $AUTOLOAD;
   $field =~ s/.*://;

   unless (exists $self->{$field})
   {
      croak "$field does not exist in object/class $type";
   }

   return $self->{$field}($self, @_);
}

# Keep autoload from pissing things off
sub DESTROY
{
}
1;

