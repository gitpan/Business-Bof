#!/usr/bin/perl -w

use strict;
use Test::More skip_all => 'Not possible yet', tests => 11;

use lib './lib';

;
BEGIN { 
  use_ok('Business::Bof::Server::Fw');
  use_ok('Business::Bof::Server::Task')
};

  my $fw = Business::Bof::Server::Fw->new('t/bof.xml');
  my $ui = $fw->get_userinfo({
    name     => 'bof',
    password => 'test'
  });

  my $fwtask = Business::Bof::Server::Task->new();
  isa_ok($fwtask, 'Business::Bof::Server::Task', 'Object is right type?');

  my $task_data = {
    user_id => 1,
    function => "class/method",
    data => 'some data',
    status => 100
  };
  my $task_id = $fwtask->new_task($task_data);
  like($task_id, qr/^[+‐]?\d+$/, 'New task');

  $task_data->{task_id}=$task_id;
  $task_data->{title}='A fine new title';
  $task_data->{data}='Some Other data';
  my $res = $fwtask->upd_task($task_data);
  is($res, 1, 'Update Task');

  my $task = $fwtask->get_task({task_id => $task_id, ro => 1});
  isa_ok($task, 'Business::Bof::Data::Fw::fw_task', 'Get Task');

  $task = $fwtask->get_tasklist($ui);
  isa_ok($task, 'ARRAY', 'Get Tasklist');
