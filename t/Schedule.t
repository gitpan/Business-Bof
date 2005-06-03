#!/usr/bin/perl -w

use strict;
use Test::More skip_all => 'Not possible yet', tests => 3;

use lib './lib';

BEGIN { use_ok('Business::Bof::Server::Fw'); };
BEGIN { use_ok('Business::Bof::Server::Schedule'); };

  my $fw = Business::Bof::Server::Fw->new('t/bof.xml');

  $fw->newFwdb();
  my %key = (
    name     => 'Freemoney',
    password => 'test'
  );
  my $ui = $fw->getUserinfo(\%key);

  my $sch = new Business::Bof::Server::Schedule();
  my $scheduleId = $sch->newSchedule({
    user_id => 1,
    function => "class/method",
    data => 'Some schedule data'
  });
  like($scheduleId, qr/^[+‐]?\d+$/, 'New schedule');

  my $schData = {
    schedule_id => $scheduleId,
    schedtype => 'D',
    schedule => '10:00',
    function => "subscription/calcSubscription",
    data => "{invoicedate => 'today'}"
  };
  my $res = $sch->updSchedule($schData);
  is($res, 1, 'Update Task');

  my $schedule = $sch->getSchedule({schedule_id => $scheduleId});
  isa_ok($schedule, 'Business::Bof::Data::Fw::fw_schedule', 'Get Schedule');

