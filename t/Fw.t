#!/usr/bin/perl -w

use strict;
use Test::More tests => 7;

use lib './lib';

BEGIN { use_ok('Business::Bof::Server::Fw'); };

  my $fw = Business::Bof::Server::Fw->new('t/bof.xml');

  ok(defined $fw, 'Defined Fw');
  ok($fw->isa('Business::Bof::Server::Fw'), 'Object type');
  ok($fw->get_newsessionid(), 'Get new Session ID');

  my $wui = $fw->get_userinfo({name=>'test', password=>'bof'});
  is($wui, undef, 'Wrong userinformation');
  my %key = (
    name     => 'bof',
    password => 'test'
  );
  my %exp_ui = (
    'dbschema' => '',
    'name' => 'bof',
    'host' => 'localhost',
    'dbname' => 't/test.sqlite',
    'domain' => 'bof',
    'password' => '',
    'dbtype' => 'SQLite',
    'dbusername' => '',
    'user_id' => '1'

  );
  my $ui = $fw->get_userinfo(\%key);
  ok(eq_hash(\%exp_ui, $ui), 'Get Userinfo');
  my $menu = $fw->get_menu($ui->{user_id});
  isa_ok($menu, 'ARRAY', 'Framework Menu');

