# NAME

Mail::SendGrid - Class for building a message to be sent through the SendGrid
mail service

# SYNOPSIS

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

# DESCRIPTION

This module allows for easy integration with the SendGrid email distribution
service and its SMTP API. It allows you to build up the pieces that make the
email itself, and then pass this object to the Mail::SendGrid::Transport class
that you wish to use for final delivery.

# CLASS METHODS

## Creation

### new\[ARGS\]

This creates the object and optionally populates some of the data fields. Available fields are:

- from

    The From address to use in the email

        from => 'Your Name <you@yourcompany.com>'

- to

    Either a string or ARRAYREF containing the addresses to send to

        to => 'Your Customer <them@theircompany.com>, Another Customer <someone@somewhereelse.com>'

        to => [ them@theircompany.com, someone@somewhereelse.com ]

- cc

    Adds additional recipients for the email and sets the CC field of the email

- bcc

    Adds additional recipients whose addresses will not appear in the headers of
    the email

- subject

    Sets the subject for the message

- date

    Sets the date header for the message. If this is not specified, the current
    date will be used

- message-id

    Sets the message id header. If this is not specified, one will be randomly
    generated

- encoding

    Sets the encoding for the email. Options are 7bit, base64, binary, and
    quoted-printable.
    Quoted printable is the default encoding

- charset

    Sets the default character set. iso-8859-1 (latin1) is the default
    If you will be using wide characters, it is expected that the strings
    passed in will already be encoded with this charset

- text

    Sets the data for the plain text portion of the email

- html

    Sets the data for the html portion of the email

## Methods for setting data

### addTo(LIST)

### addCc(LIST)

### addBcc(LIST)

Inserts additional recipients for the message

### get(PARAMETER)

### set(PARAMETER, VALUE)

Returns / sets a parameter for this message. Parameters are the same as those
in the new method

### addAttachment(DATA, \[OPTIONS\])

Specifies an attachment for the email. This can either be the data for the
attachment, or a file to attach

While the underlying MIME::Entity that will be created will try to determine
the best encoding and MIME type, you can also specify it in the options

    $sg->addAttachment('/tmp/my.pdf',
                        type => 'application/pdf',
                        encoding => 'base64');

## SMTP API functions

This class contains a number of methods for working with the SMTP API. The
SMTP API allows for customization of SendGrid filters on an individual
basis for emails. For more information about the api, please visit
http://wiki.sendgrid.com/doku.php?id=smtp\_api

### header

Returns a reference to the Mail::SendGrid::Header object used to communicate
with the SMTP API. Useful if you want to set unique identifiers or use the
mail merge functionality

### enableGravatar

### disableGravatar

Enable / disable the addition of a gravatar in the email

### enableClickTracking

### disableClickTracking

Enables / disables click tracking for emails. By default this will only
enable click tracking for the html portion of emails. If you want to
also do click tracking on plain text, you can use the addition prameter 'text'
  $sg->enableClickTracking( text => 1 );

### enableUnsubscribe

### disableUnsubscribe

Enables / disables the addition of subscription management headers / links
in the email.

If no arguments are specified for enable, only a list-unsubscribe header
will be added to the email. Additional parameters are:

- text

    The string to be added to the plain text portion of the email. This must
    contain the string <% %>, which is where the link will be placed

- html

    The string to be added to the html portion of the email. This must contain a
    tag with the format "<% link text %>", which will be replaced with the link

- replace

    A string inside of the email body to replace with the unsubscribe link. If
    this tag is not found in the body of the email, then the appropriate text or
    html setting will be used. If none of these are found, a link will not be
    inserted

        $sg->enableUnsubscribe( text => 'Unsubscribe here: <% %>',
                                html => 'Unsubscribe <% here %>',
                                replace => 'MyUnsubscribeTag' );

### enableOpenTracking

### disableOpenTracking

Enables / disables open tracking

### enableFooter

### disableFooter

Enables / disables the insertion of a footer in this email.

Parameters are:

- text

    String to insert into the plain text portion of the email

- html

    String to insert into the html portion of the email

        $sg->enableFooter( text => 'Text footer', html => 'Html footer' );

### enableSpamCheck

### disableSpamCheck

Enables / disables the checking of email for spam content. This is useful when
you are sending content that is generated by your users, such as a forum

Parameters are:

- score

    Spam Assassin score at which point the email will be flagged as spam and
    dropped. If this is not specified, 5 will be used

- url

    A url to post to in the event that the message is flagged as spam and dropped.

### enableGoogleAnalytics

### disabelGoogleAnalytics

Enables / disables link rewrites to support Google Analytics.

Paramters are:

- source

    Sets the string for the utm\_source field

- medium

    Sets the string for the utm\_medium field

- term

    Sets the string for the utm\_term field

- content

    Sets the string for the utm\_content field

- campaign

    Sets the string for the utm\_campaign field

### enableDomainKeys

### disableDomainKeys

Enables / disables Domain Keys signatures for the message.

Domain Keys is a digitial signature method, primarily used by Yahoo.

Parameters are:

- domain

    The domain to sign the messages as. This domain must be set up with the proper
    DNS records, which can be found when going through the whitelabel wizard

- sender

    Sets if SendGrid will add a Sender header if the From email address does not
    match the specified domain. This allows for messages to still have a valid
    DomainKeys signature if the email address in the From field does not have
    whitelabeling set up, however it means that some email clients will display
    the message as "on behalf of" the From address

### enableTemplate

### disableTemplate

Enables / disables the insertion of an email template. If you are enabling a
template, you must specify the text of it in the html parameter. This
text must contain the string "<% %>", which will be replaced with the body
of the message

### enableTwitter

Allows you to set twitter username / password information for this email.
The Twitter filter can be used to send either status updates or direct
messages, based on the recipient email address

    my $sg = Mail::SendGrid->new( to => 'sendgrid@twitter', text => "My update" );

    $sg->enableTwitter( username => 'myusername', password => 'mypassword' );

### enableBcc

### disableBcc

Enables / disables the automatic blind carbon copy of the email to a specific
email address. While it makes little sense to enable a bcc here, versus adding
it as a Bcc with the methods discussed previously, you can specify an email
paramter which is the address to send to

### enableBypassListManagement

Allows you to specify that this email should not be suppressed for any reason,
including the address appearing on the bounce, unsubscribe, or spam report
suppression lists. This is useful for urgent emails, such as password reset
notifications, that should always be attempted for delivery.

## Transport methods

If you don't want to use one of the Mail::SendGrid::Transport classes, or
want to build your own, these methods are used to get the data for transport

### createMimeMessage

Returns a MIME::Entity for the email

### getMailFrom

Returns the address to be used in the MAIL FROM portion of the SMTP protocol

### getRecipients

Returns an array of the recipient address for the email, to be used in the
RCPT TO portion of the SMTP protocol

# AUTHOR

Tim Jenkins <tim@sendgrid.com>

# COPYRIGHT

Copyright (c) 2010 SendGrid. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


