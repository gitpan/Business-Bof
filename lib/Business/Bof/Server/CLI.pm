package Business::Bof::Server::CLI;

use warnings;
use strict;

use DateTime;
use Exporter ();
use Getopt::Std;
use Log::Log4perl qw(get_logger :levels);
use POE qw(Session Wheel::Run Filter::Reference);
use POE::Component::Server::SOAP;
use Scalar::Util qw(blessed refaddr);
use Switch;

## Debug purpose only:
use Data::Dumper;
$|=1;
##

use Business::Bof::Server::Fw;
use Business::Bof::Server::Task;
use Business::Bof::Server::Schedule;
use Business::Bof::Server::Session;
use Business::Bof::Server::Connection;

our $VERSION = 0.05;
our @ISA = qw(Exporter);
our @EXPORT = qw(run);

our ($conffile, $fw, $fwtask, $expire_after, $tz, $obj_seq, $logger);

sub init {
  $fw = new Business::Bof::Server::Fw($conffile);
  Business::Bof::Server::Connection::set_fw($fw);
  my $conf = $fw -> get_serverconfig() ;
  _process_conf($conf);
  _start_logger($conf);
  _start_poe($conf);
  if (defined($conf->{fwdb}{level}) && $conf->{fwdb}{level} > 1) {
    $fwtask = new Business::Bof::Server::Task();
    Business::Bof::Server::Connection::set_fwtask($fwtask);
  }
}


sub _process_conf {
  my $conf = shift;
  $tz = $conf->{timezone};
  $expire_after = DateTime::Duration->new(seconds => $conf->{expireAfter});
  foreach my $cat (@{ $conf->{inc} }) {
    unshift(@INC, $cat);
  }
}

sub _start_logger {
  my $conf = shift;
  my $log_conf = "$conf->{home}/etc/log.conf";
  return unless -r $log_conf;
  Log::Log4perl->init_and_watch($log_conf, $conf->{logCheck});
  $logger = get_logger("Bof");
  $logger->info("Started $conf->{application} Server");
}

sub _start_poe {
  my $conf = shift;
  my %parms = (
    'ALIAS'      => $conf->{name},
    'ADDRESS'    => $conf->{host},
    'PORT'       => $conf->{port},
    'HOSTNAME'   => $conf->{hostname}
  );
  if (defined($conf->{SSL})) {
    my $publicKey =  $conf->{home} . '/' . $conf->{SSL}{PUBLICKEY};
    my $publicCert = $conf->{home} . '/' . $conf->{SSL}{PUBLICCERT};
    $parms{SIMPLEHTTP} = {
      'SSLKEYCERT' => [ $publicKey, $publicCert ]
    }
  };
  POE::Component::Server::SOAP->new(
    %parms
  );
  POE::Session->create (
    inline_states => {
      _start => \&setup_service,
      _stop  => \&shutdown_service,
      houseKeeping => \&houseKeeping,
      handleTasks => \&handleTasks,
      setupClass => \&setup_class,
      execMethod => \&exec_method
    }
  );
}

sub get_parameters {
  my %opts;
  getopt('cfh', \%opts);
  if ($opts{h} || !$opts{c} || !(-r $opts{c})) {
    help();
    exit
  }
  return $opts{c};
}

sub help {
  print<<EOT
Syntax: <server> -ch
        -c Config File
        -h This help
EOT
}

#
# service methods
#
sub setup_service {
  my $kernel = $_[KERNEL];
  my $name = $fw -> get_serverconfig("name");
  my $serviceName = $fw -> get_serverconfig("serviceName");
  my $application = $fw -> get_serverconfig("application");
  $kernel->alias_set("$serviceName");
  $kernel->post($name, 'ADDMETHOD', $serviceName, 'setupClass');
  $kernel->post($name, 'ADDMETHOD', $serviceName, 'execMethod');
  $kernel->delay('houseKeeping', $fw -> get_serverconfig("housekeepingDelay"));
  $kernel->delay('handleTasks', $fw -> get_serverconfig("taskDelay")) if $fwtask;
  my $logtext = "$application Server is running on PID $$";
  $logger->info($logtext) if defined($logger);
  print "\n$logtext\n";
}

sub shutdown_service {
  my $name = $fw -> get_serverconfig("name");
  my $serviceName = $fw -> get_serverconfig("serviceName");
  $_[KERNEL]->post( $name, 'DELSERVICE', $serviceName );
  $logger->info("Server shutting down") if defined($logger);
}

sub houseKeeping {
  my $transaction = $_[ARG0];
  Business::Bof::Server::Session::scrub($expire_after);
  my $kernel = $_[KERNEL];
  $kernel->delay('houseKeeping', $fw -> get_serverconfig("housekeepingDelay"));
}

sub handleSchedules {
  my $now = DateTime->now() -> set_time_zone($tz);
  my $ymd = $now -> ymd;
  my $hms = $now -> hms;
  my $fwschedule = new Business::Bof::Server::Schedule();
  $fwschedule -> dailySchedule($ymd, $hms);
}

sub handleTasks {
  my ($kernel, $heap, $transaction) = @_[KERNEL, HEAP, ARG0];
  handleSchedules();
  runTasks($heap);
  $kernel->delay('handleTasks', $fw -> get_serverconfig("taskDelay"));
}

sub runTasks {
  my $heap = shift;
  my $session_id = 0; # Special session!
  Business::Bof::Server::Session::set_timestamp($session_id, DateTime->now());
  while (my $task = $fwtask -> getTask({status => 100})) {
    my $userinfo = $fw->get_userinfo( {user_id => $task->user_id} );
    Business::Bof::Server::Session::set_userinfo($session_id, $userinfo);
    my ($class, $method) = split/\//, $task->{function};
    my $data;
    eval '$data=' . $task->{data};
    my $fw_task = $task->{task_id};
    startTask($heap, $session_id,$class,$method,$data,$fw_task);
  }
}

sub setup_class {
  my $response = $_[ARG0];
  my $name = $fw -> get_serverconfig("name");
  my $params = $response->soapbody;
  my $session_id = $params->{sessionId};
  my $data = $params->{data};
  my $module = $data->{class};
  $logger->info("setup class $module") if defined($logger);
  eval "require $module";
  my $package = $data->{package};
  push @$package, $module;
  my $result = get_allowed_methods(@$package);
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub get_allowed_methods {
  my (@package) = @_;
##! Test for errors
  my %subs;
  foreach my $module (@package) {
    $subs{$module} = {_search_isa($module)};
#####print "m: $module : " . Dumper(\%subs);
  }
# Find restrictions for user
##  my $userInfo = $session{$session_id}{userInfo};
## Allow guests. Specifically for login purposes
## etc ...
  return \%subs;
}

sub _search_isa {
  my ($in_pkg, %subs) = @_;
  no strict qw/refs/;
  foreach my $entry (keys %{"${in_pkg}::"}) {
    $subs{$entry} = 1 if *{"${in_pkg}::${entry}"}{CODE};
    $logger->debug("class $in_pkg method: $entry") if defined($logger);
  }
  foreach my $pkg (@{"${in_pkg}::ISA"}) {
    %subs = _search_isa($pkg, %subs);
  }
  return %subs;
}

sub exec_method {
  my $response = $_[ARG0];
  my $name = $fw -> get_serverconfig("name");
  my $params = $response->soapbody;
  my $session_id = $params->{sessionId};
  my $cm = $params->{method};
  my $class = $cm->{class};
  my $method = $cm->{method};
  my $parms = $params->{parms};
  my @parms = @$parms;
  my $obj_id;
  $obj_id = proxy_object($session_id, \@parms);
  my $logtext = "class $class method $method";
  $logtext .= " Session $session_id" if $session_id; 
  $logtext .= " obj_id $obj_id" if $obj_id;
  $logger->debug($logtext) if defined($logger);
  my @result = $obj_id ? _instance_method($session_id, $obj_id, $method, @parms) : 
    _class_method($session_id, $class, $method, @parms);
  $response->content( \@result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub _instance_method {
  my ($session_id, $obj_id, $method, @parms) = @_;
  my @result;
  if ($method eq 'DESTROY') {
    Business::Bof::Server::Session::delete_object($session_id, $obj_id);
  } else {
    my $obj = shift @parms;
    eval { @result = $obj->$method(@parms) };
    object_proxy($session_id, \@result);
  }
  return @result;
}

sub _class_method {
  my ($session_id, $class, $method, @parms) = @_;
  my @result;
  no strict qw/refs/;
  if ($class eq $parms[0]) {
    shift @parms;
    eval { @result = $class->$method(@parms) };
  } else {
    my $fqm = "$class\:\:$method";
    eval {@result = &{ $fqm }(@parms) };
  }
  object_proxy($session_id, \@result);
  return @result;
}

sub proxy_object {
  my ($session_id, $parms) = @_;
  my ($obj_id, $more);
  for my $p (@$parms) {
    if (ref($p) eq 'ARRAY' && ${$p}[0] =~ /__bof__/) {
      my $oid = substr(${$p}[0], 7);
      $p = Business::Bof::Server::Session::get_object($session_id, $oid);
      $obj_id = $oid unless $more;
    }
    $more = 1;
  }
  return $obj_id;
}

sub object_proxy {
  my ($session_id, $parms) = @_;
   for my $p (@$parms) {
     if (blessed($p)) {
       my $obj_id = ++$obj_seq;
       Business::Bof::Server::Session::set_object($session_id, $obj_id, $p);
       my $prox = "__bof__" . $obj_id;
       my $class = ref($p);
       $p = [$prox, $class];
     }
   }
}

sub run {
  my $cfgfile = get_parameters();
  run_server($cfgfile);
}

sub run_server {
  $conffile = shift;
  init();
  $poe_kernel->run();
}

sub stop_server {
  my $response = $_[ARG0];
  my $name = $fw -> get_serverconfig("name");
  $_[KERNEL]->post( $name, '_stop');
}
1;
__END__

=head1 NAME

Business::Bof::Server::CLI -- Server of The Business Oriented Framework

=head1 DESCRIPTION

The Server of the Business Oriented Framework (bof) will read its
configuration parameters from an XML file (see the section L</The
configuration file> below), and will start listening on the specified
port.

The Server uses SOAP as its transport, in principle making it easy to
use any language to connect to as a client, and it will answer to these
calls:

=head1 Using SOAP::Lite

See C<Business::Bof::Client> for an example of using SOAP::Lite directly
with the server. Business::Bof::Client is an easy to use Object Oriented
interface to the BOF server. I recommend using it instead of talking
directly with the server.

=head1 The configuration file

The BOF server needs a configuration file, the name of which has to be
given on startup. It's an XML file looking like this:

=head2 Server Configuration

The name of this section in the XML file is C<ServerConfig>

=over 4

=item home

The place in the file system where the application located.
I<home> is used to tell where the log file configuration and the
optional SSL configuration is stored.

=item appclass

The applications class name.

=item host

The SOAP host name.

=item hostname

The SOAP server proxy name.

=item name

The SOAP server session name.

=item port

The server's port number.

=item serviceName

The servers Service Name.

=item application

The application's name. Freetext, only for display- and logging purpose.

=item taskDelay

Number of seconds for the task process to sleep. The task process will
wake up and look for new tasks in the framework database with this
interval.

=item housekeepingDelay

Number of seconds for the clean up process to sleep. The clean up
process will wake up and look for old sessions to purge.

=item expireAfter

Number of seconds to keep a session alive without activity. The clean up
process will check if a session has been idle for more than this period
of time, and if so, purge it.

=item logCheck

Number of seconds to tell the logger after which it will check for
changes in the configuration file. Users of log4perl will know what I'm
talking about.

=back

=head2 Configuration of Framework Database

The name of this section in the XML file is C<fwdb>. The database is a
PostgreSQL database.

=over 4

=item host

The database host name.

=item name

The database name.

=item username

Username that can access the Framework Database.

=item password

The user's password.

=back

=head2 Settings for application objects

The name of this section in the XML file is C<ServerSettings>. Any data
in this section will be handed over to the application's C<new> method
through a hash ref.  This gives the application a chance to know a
little about its surroundings, e.g. directories where it may write
files.

=head2 Settings for client programs

The name of this section in the XML file is C<ClientSettings>. Any data
in this section can be retrieved by the client program through the
method getClientdata. 

The server will also inform the client program about current session
data, so please don't use these names in the ClientSettings section:

C<menu>, C<allowed>, C<userinfo>

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
