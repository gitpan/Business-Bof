package Business::Bof::Server::Connection;

use warnings;
use strict;

##
use DateTime;
use Log::Log4perl qw(get_logger :levels);
use DBIx::Recordset;
##

use Business::Bof::Server::Fw;
use Business::Bof::Server::Task;
use Business::Bof::Server::Schedule;
use Business::Bof::Server::Docprint;

our ($fw, $fwtask);
our $VERSION = 0.03;

sub set_fw {
  $fw = shift;
}

sub set_fwtask {
  $fwtask = shift;
}

sub login {
  my $log_info = shift;
  my $userinfo = $fw->get_userinfo($log_info);
 if ($userinfo) {
    my $session_id = $fw -> get_newsessionid($log_info->{name});
    Business::Bof::Server::Session::set_userinfo($session_id, $userinfo);
    Business::Bof::Server::Session::set_timestamp($session_id, DateTime->now()); ## Eventually move calls to set_timestamp to exec_method and setup_class
    my $menu = $fw->get_menu($userinfo->{user_id});
    Business::Bof::Server::Session::set_menu($session_id, $menu);
    Business::Bof::Server::Session::set_allowed($session_id, $fw->get_allowed());
    Business::Bof::Server::Session::set_db($session_id, $fw->getdb({ userinfo => $userinfo }));
##Log
#   $logger->info("Login user $log_info->{name}, session $session_id");
   return $session_id;
  } else {
    return 0
  }
}

sub logout {
  my $session_id = shift;
  Business::Bof::Server::Session::remove_session($session_id);
#Log
#  $logger->info("Removed session $session_id");
  return 0;
}

sub get_clientdata {
  my $session_id = shift;
  my $result = 0;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    $result = $fw -> get_clientsettings();
    $result = _get_sessiondata($session_id, $result);
  }
  return $result;
}

sub _get_sessiondata {
  my $session_id = shift;
  my %sp = %{ shift() };
  $sp{userinfo} = Business::Bof::Server::Session::get_userinfo($session_id);
  $sp{menu} = Business::Bof::Server::Session::get_menu($session_id);
  $sp{allowed}  = Business::Bof::Server::Session::get_allowed($session_id);
  delete @{$sp{userinfo}}{'dbtype', 'dbname', 'dbusername', 'dbschema', 'password', 'host'};
  return \%sp;
}

sub get_data {
  my $session_id = shift;
  my %sp = %{ shift() };
  $sp{'!DataSource'} = Business::Bof::Server::Session::get_db($session_id);
#$DBIx::Recordset::Debug = 4;
  my $set = DBIx::Recordset -> Search ( {%sp} );
  my @data;
  while (my $rec = $$set -> Next) {
    push @data, { ( %$rec ) };
  }
  my $moreRecords = defined($$set->MoreRecords(1));
  my %returnSet = (
    moreRecords => $moreRecords,
    startRecordno => $$set->{'*StartRecordNo'},
    fetchMax => $$set->{'*FetchMax'},
    fetchStart => $$set->{'*FetchStart'},
    data => [ @data ]
  );
  return \%returnSet;
}

sub cache_data {
  my ($session_id, $cachename, $data) = @_;
  Business::Bof::Server::Session::set_cachedata($session_id, $cachename, $data);
  return;
}

sub get_cachedata {
  my ($session_id, $cachename) = @_;
  return Business::Bof::Server::Session::get_cachedata($session_id, $cachename);
}

sub get_task {
  my ($session_id, $taskId) = @_;
  my $result;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    $result = $fwtask -> getTask({task_id => $taskId, ro => 1});
  } else {
    $result = "No session";
  }
  return $result ;
}

sub get_tasklist {
  my ($session_id, $cachename) = @_;
  my $result;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    my $userinfo =  Business::Bof::Server::Session::get_userinfo($session_id);
    $result = $fwtask->getTasklist($userinfo);
  } else {
    $result = "No session";
  }
  return $result ;
}

sub print_file {
  my ($session_id, $data) = @_;
  my $result;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    my $serverSettings = $fw->getServerSettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    my $userinfo =  Business::Bof::Server::Session::get_userinfo($session_id);
    $result = $fwprint -> printFile($data, $userinfo);
  } else {
    $result = "No session";
  }
  return $result ;
}

sub get_printfile {
  my ($session_id, $data) = @_;
  my $result;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    my $serverSettings = $fw->get_serversettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    my $userinfo =  Business::Bof::Server::Session::get_userinfo($session_id);
    $result = $fwprint -> getFile($data, $userinfo);
  } else {
    $result = "No session";
  }
  return $result ;
}

sub get_printfilelist {
  my ($session_id, $data) = @_;
  my $result;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    my $serverSettings = $fw->get_serversettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    my $userinfo =  Business::Bof::Server::Session::get_userinfo($session_id);
    $result = $fwprint->get_filelist($data, $userinfo);
  } else {
    $result = "No session";
  }
  return $result ;
}

sub get_queuelist {
  my ($session_id, $data) = @_;
  my $result;
  if (Business::Bof::Server::Session::defined_session($session_id)) {
    my $serversettings = $fw->get_serversettings();
    my $fwprint = new Business::Bof::Server::Docprint($serversettings);
    my $userinfo =  Business::Bof::Server::Session::get_userinfo($session_id);
    $result = $fwprint->get_queuelist($data, $userinfo);
  } else {
    $result = "No session";
  }
  return $result ;
}

sub call_method {
  my $session_id = shift;
  my %parms = %{ shift() };
  my $db = Business::Bof::Server::Session::get_db($session_id);
  my $userinfo =  Business::Bof::Server::Session::get_userinfo($session_id);
  my $domain = $userinfo->{domain};
  my $class = $parms{class};
  my $method = $parms{method};
  my $serversettings = $fw->get_serversettings();
  my $module = instantiate($class, $db, $serversettings);
  my $res = $module->$method($parms{data}, $userinfo);
##  $logger->info("Method call: $class\:\:$method for $domain");
  return $res;
}

sub instantiate {
  my $class = shift;
  my $location       = "$class.pm";
  require $location;
  return $class->new(@_);
}

1;
__END__

=head1 NAME

Business::Bof::Server::Connection -- Server methods for The Business Oriented Framework

=head1 SYNOPSIS

See C<Business::Bof::Client>

=head1 DESCRIPTION

Preferably to be used from Business::Bof::Client these methods help the user in common
enterprise related tasks.

=over 4

=item login($logInfo)

Login will take a hash reference to login data and validate it against
the Framework Database. If it is a valid data pair, it will return a
session ID for the client to use in all subsequent calls. The format of
the hash is C<< {name => $username, password => $password} >>

=item logout($session_id)

Provide your session ID to this function so it can clean up after you.
The server will be grateful ever after!

=item get_data($session_id, $parms)

get_data takes two parameters. The obvious session ID and a hash
reference with SOAP name C<parms>. The format of the hash is the same as
is used by DBIx::Recordset. E.g.:

C<<  my $parms = {
    '!Table' => 'order, customer',
    '!TabJoin' => 'order JOIN customer USING (contact_id)',
    '$where'  =>  'ordernr = ?',
    '$values'  =>  [ $ordernr ]
  }; >>

B<NOTE> get_data is deprecated and will modt likely be removed in a future release.
Use Class::DBI and the ROE interface instead.

=item call_method($session_id, $parms)

call_method will find the class and method, produce a new instant and
execute it with the given parameter (SOAP name C<parms>).

It looks like this:

C<< $parms = {
  class => 'myClass',
  data => $data,
  method => 'myMethod',
  [long => 1,
  task => 1 ]
}; >>

Two modifiers will help the server determine what to do with the call.

If C<long> is defined, the server will handle it as a long running task,
spawning a separate process.

If C<task> is defined, the server will not execute the task immediately,
but rather save it in the framework's task table. The server will
execute it later depending on the server's configuration settings.

See B<Business Classes and Methods> for an introduction to the layout of the
class layout for server classes.

=item cache_data($session_id, $cachename, $somedata);

The server saves the data with SOAP name C<data> under the name provided
with SOAP name C<name> for later retrieval by getCachedata.

=item get_cachedata($session_id, $cachename);

The server returns the cached data, given the key with SOAP name
C<name>.

=item get_clientdata

This method returns the data provided in the ClientSettings section of
the BOF server's configuration file. It also provides some additional
information about the current session.

=item get_task($session_id, $taskId);

The server returns the task with the given taskId.

=item get_tasklist($session_id);

The server returns the list of tasks.

=item print_file($session_id, $parms)

print_file will print a file from Bof's queue system. The given parameter
indicates which file is to be printed.

It looks like this:

C<< $parms = {
  type => 'doc' or 'print', 
  file => $filename,
  queue => $queuename
}; >>

=item get_printfile($session_id, $parms)

get_printfile works like print_file, except it returns the file instead of
printing it.

=item get_printfilelist($session_id, $parms)

get_printfilelist returns an array containing information about the files
in the chosen queue

C<< $parms = {
  type => 'doc' or 'print', 
  queue => $queuename
}; >>

=item get_queuelist($session_id, $parms)

get_queuelist returns an array containing information about the available
queues.

C<< $parms = {
  type => 'doc' or 'print', 
}; >>

=back

=head1 Business Classes and Methods

The actual classes that the application server will service when using call_method 
must adhere to some standards.

=head2 The C<new> method

C<new> must accept three parameters, its type, the database handle and
the reference to the server settings as provided in the configuration
file.

=head2 The methods

The individual methods must accept two parameters, the single value
(scalar, hash ref or array ref) that the client program sent and a hash
ref with the session's user info.

=head1 Requirements

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
