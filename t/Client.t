#!/usr/bin/perl -w

use strict;
use Test::More tests => 3;

use Business::Bof::Client;

  my $fw = Business::Bof::Client->new();
  ok(defined $fw);
  ok($fw->isa('Business::Bof::Client'));

  ok($fw->setSessionId('sessionID'));

