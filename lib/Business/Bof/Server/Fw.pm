package Business::Bof::Server::Fw;

use warnings;
use strict;
use vars qw($VERSION);

use DBIx::Recordset;
use XML::Dumper;
use Digest::MD5 qw(md5_base64);

$VERSION = 0.10;

sub new {
  my ($type, $conffile) = @_;
  my $self = {};
  $self->{config} = xml2pl($conffile);
  return bless $self,$type;
}

sub getNewSessionid {
  my $self = shift;
  return md5_base64(join ("", (@_, localtime())));
}

# Get a new handle to the Framework database
sub newFwdb {
  my $self = shift;
  my $dbname = $self->{config}{fwdb}{name};
  my $username = $self->{config}{fwdb}{username};
  my $password = $self->{config}{fwdb}{password};
  my $host = $self->{config}{fwdb}{host};
  my @connect = ("dbi:Pg:dbname=$dbname;host=$host");
  $connect[++$#connect] = $username if $username; 
  $connect[++$#connect] = $password if $password; 
  my $fwdb = DBI->connect(@connect)
    or die("Unable to connect to $dbname");
  $self->{db} = $fwdb;
  return $fwdb;
}

# Get the current handle to the Framework database
sub getFwdb {
  my $self = shift;
  return $self->{db};
}

# Get a handle to the application's database
sub getdb {
  my $self = shift;
  my %data = %{ shift() };
  my $dbname = $data{userinfo}{dbname};
  my $username = $data{userinfo}{dbusername};
  my $password = $data{userinfo}{password};
  my $host = $data{userinfo}{host};
  my $schema = $data{userinfo}{dbschema};
  my $db = DBI->connect("dbi:Pg:dbname=$dbname;host=$host", "$username", "$password")
      or die("Unable to connect to $dbname");
  $db -> do ("SET search_path TO $schema");
  return $db;
}

sub getUserinfo {
  my $self = shift;
  my %data = %{ shift() };
  my %ndat;
  $ndat{'fw_user.name'} = $data{name} if $data{name};
  $ndat{'fw_user.password'} = $data{password} if $data{password};
# To prevent reading user info by user_id:
#  $ndat{'fw_user.name'} = $data{name} || '*';
#  $ndat{'fw_user.password'} = $data{password} || '*';
  $ndat{'fw_user.user_id'} = $data{user_id} if $data{user_id};
  my $db = $self->{db};
  my %userinfo;
#$DBIx::Recordset::Debug = 4;
  my $set = DBIx::Recordset -> Search ({%ndat,
    ('!DataSource'   => $db,
    '!Fields' => 'user_id, dbname, fw_usergroup.name AS groupname, 
      dbusername, dbpassword, dbhost, dbschema, contact_id, domainname',
    '!Table' => 'fw_user, fw_usergroup, fw_useringroup, fw_database',
    '!TabJoin' => 'fw_usergroup LEFT JOIN fw_useringroup USING (usergroup_id)
       LEFT JOIN fw_user USING (user_id)
       LEFT JOIN fw_database USING (db_id)'
    )});
  if (my $rec = $$set -> Next) {
#    my $now = DateTime->now();
    %userinfo = (
     user_id => $rec->{user_id},
     dbname => $rec->{dbname},
     name => $rec->{groupname},
     dbusername => $rec->{dbusername},
     dbschema => $rec->{dbschema},
     password => $rec->{dbpassword},
     host => $rec->{dbhost},
     owner_id => $rec->{contact_id},
     domain => $rec->{domainname},
##     year => $now -> year,
##     month => $now -> month,
##     day => $now -> day,
##     dow => $now -> dow,
##     dayofyear => $now -> day_of_year,
##     hour => $now -> hour,
##     minute => $now -> minute,
##     second => $now -> second
    );
  }
  return %userinfo;
}

# Retrieval

sub findMenus {
  my $self = shift;
  my ($menu_id, $usergroup_id) = @_;
  my $db = $self->{db};
  my $set = DBIx::Recordset -> Search ({
    '!DataSource'   => $db,
    '!Table' => 'fw_menu, fw_menulink',
    '!TabJoin' => 'fw_menu JOIN fw_menulink
      ON (fw_menu.menu_id = fw_menulink.child_id)',
    '$where'  =>  'parent_id = ? AND fw_menu.menu_id NOT IN
     (SELECT menu_id FROM fw_usermenu WHERE usergroup_id = ?)',
    '$values'  =>  [$menu_id, $usergroup_id]
  });
  my @menu;
  while (my $rec = $$set -> Next) {
    push @menu, { ( %$rec ) };
  }
  foreach my $rec (@menu) {
    my @subMenu = $self -> findMenus( $rec -> {menu_id}, $usergroup_id );
    if (@subMenu) {
      $rec -> {menu} = [ @subMenu ];
    }
    $self->{allowed}->{"$rec->{uri}"} = 1;
  }
  return @menu;
}

# getMenu ( {values => %values} )
sub getMenu {
  my $self = shift;
  my $user_id = shift;
  my $usergroup_id = 0;
  $self->{allowed} = {};
  my $db = $self->{db};
  my $set = DBIx::Recordset -> Search ({
    '!DataSource'   => $db,
    '!Table' => 'fw_useringroup',
    '$where'  =>  'user_id = ?',
    '$values'  =>  [$user_id]
  });
  if (my $rec = $$set -> Next) {
    $usergroup_id = $rec -> {usergroup_id}
  }
  $set = DBIx::Recordset -> Search ({
    '!DataSource'   => $db,
    '!Table' => 'fw_menu',
    '$where'  =>  'menu_id NOT IN (SELECT child_id FROM fw_menulink)
      AND menu_id NOT IN
     (SELECT menu_id FROM fw_usermenu WHERE usergroup_id = ?)',
    '$values'  =>  [$usergroup_id]
  });
  my @menu;
  while (my $rec = $$set -> Next) {
    my @subMenu = $self -> findMenus( $rec -> {menu_id}, $usergroup_id );
    if (@subMenu) {
      $rec -> {menu} = [ @subMenu ];
    }
    $self->{allowed}->{"$rec->{uri}"} = 1 if $rec->{uri};
    push @menu, { ( %$rec ) };
  }
  DBIx::Recordset::Undef ('set');
  @menu;
}

sub getServerConfig {
  my ($self, $var) = @_;
  my $res;
  if ($var) {
    $res = $self->{config}{ServerConfig}{$var}
  } else {
    $res = $self->{config}{ServerConfig}
  }
  return $res;
}

sub getServerSettings {
  my ($self, $var) = @_;
  my $res;
  if ($var) {
    $res = $self->{config}{ServerSettings}{$var}
  } else {
    $res = $self->{config}{ServerSettings}
  }
  return $res;
}

sub getClientSettings {
  my ($self, $var) = @_;
  my $res;
  if ($var) {
    $res = $self->{config}{ClientSettings}{$var}
  } else {
    $res = $self->{config}{ClientSettings}
  }
  return $res;
}

sub getAllowed {
  my $self = shift;
  $self->{allowed}{"notallowed.epl"} = 1;
  $self->{allowed}{"index.epl"} = 1;
  $self->{allowed}{"logout.epl"} = 1;
  $self->{allowed}{"login.epl"} = 1;
  return %{ $self->{allowed} }
}

1;
