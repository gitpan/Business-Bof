package Business::Bof::Server::Fw;

use warnings;
use strict;
use Carp;
use XML::Dumper;
use Digest::MD5 qw(md5_base64);

use Business::Bof::Data::Fw;

our $VERSION = 0.05;

sub new {
  my ($type, $conffile) = @_;
  my $self = {};
  $self->{config} = xml2pl($conffile);
  my $class = bless $self,$type;
  $class->new_fwdb;
  return $class;
}

sub get_newsessionid {
  my $self = shift;
  return md5_base64(join ("", (@_, localtime())));
}

sub new_fwdb {
  my $self = shift;
  my $dbtype = $self->{config}{fwdb}{type};
  my $dbname = $self->{config}{fwdb}{name};
  my $username = $self->{config}{fwdb}{username};
  my $password = $self->{config}{fwdb}{password};
  my $host = $self->{config}{fwdb}{host};
  my @connect = ("dbi:$dbtype:dbname=$dbname;host=$host");
  $connect[++$#connect] = $username if $username; 
  $connect[++$#connect] = $password if $password; 
  Business::Bof::Data::Fw->connection(@connect)
    or croak("Unable to connect to $dbname");
  return;
}

sub getdb {
  my $self = shift;
  my %data = %{ shift() };
  my $dbtype = $data{userinfo}{dbtype};
  my $dbname = $data{userinfo}{dbname};
  my $username = $data{userinfo}{dbusername};
  my $password = $data{userinfo}{password};
  my $host = $data{userinfo}{host};
  my $schema = $data{userinfo}{dbschema};
  my $db = DBI->connect("dbi:$dbtype:dbname=$dbname;host=$host",
    "$username",
    "$password"
  ) or die("Unable to connect to $dbname");
  $db -> do ("SET search_path TO $schema, public") if $schema;
  return $db;
}

sub get_userinfo {
  my ($self, $data) = @_;
  my $user = Business::Bof::Data::Fw::fw_user->retrieve(%$data);
  return if !defined($user);
  my @uig = $user->fw_useringroup_user_id;
  my $group = $uig[0]->usergroup_id;
  my $db = $group->db_id;
  my %userinfo = (
    user_id => $user->user_id,
    name => $group->name,
    domain => $group->domainname,
    dbtype => $db->dbtype,
    dbname => $db->dbname,
    dbusername => $db->dbusername,
    password => $db->dbpassword,
    dbschema => $db->dbschema,
    host => $db->dbhost,
  );
  return \%userinfo;
}

sub find_menus {
  my ($self, $menu_id, $usergroup_id) = @_;
  my @fwmenu = Business::Bof::Data::Fw::fw_menu->search_submenu($menu_id, $usergroup_id);
  my @menu;
  for my $fwmenu (@fwmenu) {
  	my %ml = (name => $fwmenu->name, uri => $fwmenu->uri);
    my $submenu = $self -> find_menus( $fwmenu->menu_id, $usergroup_id );
    if (@$submenu) {
      $ml{menu} = $submenu;
    }
    $self->{allowed}->{$fwmenu->uri} = 1 if $fwmenu->uri;
    push @menu, { ( %ml ) };
  }
  return \@menu;
}

sub get_menu {
  my ($self, $user_id, $usergroup_id) = @_;
  $self->{allowed} = {};
  my @uig = Business::Bof::Data::Fw::fw_useringroup->search(
    user_id => $user_id 
  );

## For now, we only use the first
  $usergroup_id = $uig[0]->usergroup_id;
  my @fwmenu = Business::Bof::Data::Fw::fw_menu->topmenu($usergroup_id);
  my @menu;
  for my $fwmenu (@fwmenu) {
  	my %ml = (name => $fwmenu->name, uri => $fwmenu->uri);
    my $submenu = $self -> find_menus( $fwmenu->menu_id, $usergroup_id );
    if (@$submenu) {
      $ml{menu} = $submenu;
    }
    $self->{allowed}->{$fwmenu->uri} = 1 if $fwmenu->uri;
    push @menu, { ( %ml ) };
  }
  return \@menu;
}

sub get_serverconfig {
  my ($self, $var) = @_;
  my $res;
  if ($var) {
    $res = $self->{config}{ServerConfig}{$var}
  } else {
    $res = $self->{config}{ServerConfig}
  }
  return $res;
}

sub get_serversettings {
  my ($self, $var) = @_;
  my $res;
  if ($var) {
    $res = $self->{config}{ServerSettings}{$var}
  } else {
    $res = $self->{config}{ServerSettings}
  }
  return $res;
}

sub get_clientsettings {
  my ($self, $var) = @_;
  my $res;
  if ($var) {
    $res = $self->{config}{ClientSettings}{$var}
  } else {
    $res = $self->{config}{ClientSettings}
  }
  return $res;
}

sub get_allowed {
  my $self = shift;
  $self->{allowed}{"notallowed"} = 1;
  $self->{allowed}{"index"} = 1;
  $self->{allowed}{"logout"} = 1;
  $self->{allowed}{"login"} = 1;
  return $self->{allowed}
}

1;

__END__

=head1 NAME

Business::Bof::Server::Fw -- Framework support for CLI and utility methods

=head1 DESCRIPTION

Business::Bof::Server::Fw is an interface to BOF's Framework Database.
It also provides a few utility methods.

=head2 Methods

Fw has these methods:

=over 4

=item get_newSessionid

Returns a session ID to be used all throughout the client's session.

=item getdb

Returns a handle to the application's database.

=item get_userinfo

Returns the User Information from the Framework Database given the login
information 

my $data = {
  name => $username,
  password => $password
}
my $userinfo = $fw -> getUserinfo( $data );

=item get_menu

Returns a pointer to an array containing the menus from the Framework Database.

=item getAllowed

Returns a pointer to an array containing the allowed menu items.

=item get_serverconfig

Returns the Server's Configuration (as provided in the configuration XML
file).

=item get_serversettings

Returns the Server's Server Settings (as provided in the configuration
XML file).

=item get_clientsettings

Returns the Server's Client Settings (as provided in the configuration
XML file).

=back

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
