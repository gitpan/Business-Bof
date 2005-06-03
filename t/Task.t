#!/usr/bin/perl -w

use strict;
use Test::More skip_all => 'Not possible yet', tests => 4;

use lib './lib';

use Business::Bof::Server::Fw;
use Business::Bof::Server::Task;

# Warming up
  my $fw = Business::Bof::Server::Fw->new('t/bof.xml');

  $fw->newFwdb();
  my %key = (
    name     => 'Freemoney',
    password => 'test'
  );
  my $ui = $fw->getUserinfo(\%key);

# Starting tests
  my $fwtask = Business::Bof::Server::Task->new();
  my $taskData = {
    user_id => 1,
    function => "class/method",
    data => 'some data',
    status => 100
  };
  my $task_id = $fwtask->newTask($taskData);
  like($task_id, qr/^[+‐]?\d+$/, 'New task');

  $taskData->{task_id}=$task_id;
  $taskData->{title}='A fine new title';
  $taskData->{data}='Some Other data';
  my $res = $fwtask->updTask($taskData);
  is($res, 1, 'Update Task');

  my $task = $fwtask->getTask({task_id => $task_id, ro => 1});
  isa_ok($task, 'Business::Bof::Data::Fw::fw_task', 'Get Task');

  $task = $fwtask->getTasklist($ui);
  isa_ok($task, 'ARRAY', 'Get Tasklist');
