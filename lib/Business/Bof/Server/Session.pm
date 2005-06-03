package Business::Bof::Server::Session;

use warnings;
use strict;

our $VERSION = 0.03;
our %session;

sub get_object {
  my ($session_id, $obj_id) = @_;
  return $session{$session_id}{objects}{$obj_id};
}

sub set_object {
  my ($session_id, $obj_id, $obj) = @_;
  $session{$session_id}{objects}{$obj_id} = $obj;
}

sub delete_object {
  my ($session_id, $obj_id) = @_;
  delete $session{$session_id}{objects}{$obj_id};
}

sub set_timestamp {
  my ($session_id, $date_time) = @_;
  $session{$session_id}{timestamp} = $date_time;
}

sub get_db {
  my ($session_id) = @_;
  return $session{$session_id}{db};
}

sub set_db {
  my ($session_id, $db) = @_;
  $session{$session_id}{db} = $db;
}

sub get_userinfo {
  my ($session_id) = @_;
  return $session{$session_id}{userInfo};
}

sub set_userinfo {
  my ($session_id, $userinfo) = @_;
  $session{$session_id}{userInfo} = $userinfo;
}

sub get_menu {
  my ($session_id) = @_;
  return $session{$session_id}{menu};
}

sub set_menu {
  my ($session_id, $menu) = @_;
  $session{$session_id}{menu} = $menu;
}

sub get_allowed {
  my ($session_id) = @_;
  $session{$session_id}{allowed};
}

sub set_allowed {
  my ($session_id, $allowed) = @_;
  $session{$session_id}{allowed} = $allowed;
}

sub get_cachedata {
  my ($session_id, $cachename) = @_;
  return $session{$session_id}{$cachename};
}

sub set_cachedata {
  my ($session_id, $cachename, $data) = @_;
  $session{$session_id}{$cachename} = $data;
}

sub defined_session {
  my $session_id = shift;
  return defined($session{$session_id});
}

sub remove_session {
  my $session_id = shift;
  my $rc = $session{$session_id}{db} -> disconnect() if defined($session{$session_id}{db});
  delete $session{$session_id};
}

sub scrub {
  my $expireAfter = shift;
  my $now = DateTime->now();
  foreach my $session_id (keys %session) {
    if ($session{$session_id}{timestamp} + $expireAfter < $now) {
      remove_session($session_id);
    }
  }
}

1;
__END__
=head1 NAME

Business::Bof::Server::Session -- Session handling methods

=head1 DESCRIPTION

Business::Bof::Server::Session should only be used from within bof.

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
