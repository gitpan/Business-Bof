package Business::Bof::Server::CLI;

use warnings;
use strict;

use DateTime;
use DBIx::Recordset;
use Exporter ();
use Getopt::Std;
use Log::Log4perl qw(get_logger :levels);
use POE qw(Session Wheel::Run Filter::Reference);
use POE::Component::Server::SOAP;
use XML::Dumper;

use Business::Bof::Server::Fw;
use Business::Bof::Server::Task;
use Business::Bof::Server::Schedule;
use Business::Bof::Server::Docprint;

use vars qw($VERSION @EXPORT @ISA);

$VERSION = 0.02;
@ISA = qw(Exporter);
@EXPORT = qw(run);

my $conffile;
my $fw;
my $fwtask;
my %session;
my $expireAfter;
my $tz;
my $logger;

sub init {
  $fw = new Business::Bof::Server::Fw($conffile);
  my $conf = $fw -> getServerConfig() ;
# We'll add the application's home directory to INC
  unshift(@INC, $conf->{home} . '/src');
  $tz = $conf->{timezone};
  $logger = get_logger("Server");
  Log::Log4perl->init_and_watch(
    "$conf->{home}/etc/log.conf",
    $conf->{logCheck}); # Check conf every x seconds
  $logger->info("Started $conf->{application} Server");
  my %newparms = (
    'ALIAS'      => $conf->{name},
    'ADDRESS'    => $conf->{host},
    'PORT'       => $conf->{port},
    'HOSTNAME'   => $conf->{hostname}
  );
  if (defined($conf->{SSL})) {
    my $publicKey =  $conf->{home} . '/' . $conf->{SSL}{PUBLICKEY};
    my $publicCert = $conf->{home} . '/' . $conf->{SSL}{PUBLICCERT};
    $newparms{SIMPLEHTTP} = {
      'SSLKEYCERT' => [ $publicKey, $publicCert ]
    }
  };
  POE::Component::Server::SOAP->new(
    %newparms
  );
  POE::Session->create
    ( inline_states =>
      { _start => \&setupService,
        _stop  => \&shutdownService,
        login => \&handleLogin, 
        logout => \&handleLogout,
        getClientdata => \&getClientdata,
        getData => \&getData,
        callMethod => \&findCallMethod,
        cacheData => \&cacheData,
        getCachedata => \&getCachedata,
        getTask => \&getTask,
        getTasklist => \&getTasklist,
        printFile => \&printFile,
        getPrintfile => \&getPrintfile,
        getPrintfilelist => \&getPrintfilelist,
        getQueuelist => \&getQueuelist,
        dumpSession => \&dumpSession,
        houseKeeping => \&houseKeeping,
        handleTasks => \&handleTasks,
        taskResult => \&taskResult,
        taskDone => \&taskDone,
        taskDebug => \&taskDebug
      }
    );

  my $db = $fw -> newFwdb;
  $fwtask = new Business::Bof::Server::Task($db);
  $expireAfter = DateTime::Duration->new( 
    seconds => $conf->{expireAfter}
  );
}

sub getParameters {
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

sub setupService {
  my $kernel = $_[KERNEL];
  my $name = $fw -> getServerConfig("name");
  my $serviceName = $fw -> getServerConfig("serviceName");
  my $application = $fw -> getServerConfig("application");
  $kernel->alias_set("$serviceName");
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'login' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'logout' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getClientdata' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getData' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'callMethod' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'cacheData' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getCachedata' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getTask' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getTasklist' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'printFile' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getPrintfile' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getPrintfilelist' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'getQueuelist' );
  $kernel->post( $name, 'ADDMETHOD', $serviceName, 'dumpSession' );
  $kernel->delay('houseKeeping', $fw -> getServerConfig("housekeepingDelay"));
  $kernel->delay('handleTasks', $fw -> getServerConfig("taskDelay"));
  print "\n$application Server is running on $$\n";
}

sub shutdownService {
  my $name = $fw -> getServerConfig("name");
  my $serviceName = $fw -> getServerConfig("serviceName");
  $_[KERNEL]->post( $name, 'DELSERVICE', $serviceName );
}

sub houseKeeping {
  my $transaction = $_[ARG0];
  scrubbing();
  my $kernel = $_[KERNEL];
  $kernel->delay('houseKeeping', $fw -> getServerConfig("housekeepingDelay"));
}

sub scrubbing {
# Expire sessions
  my $now = DateTime->now();
  foreach my $sessionId (keys %session) {
    if ($session{$sessionId}{timestamp} + $expireAfter < $now) {
      removeSession($sessionId);
    }
  }
}

sub removeSession {
  my $sessionId = shift;
  my $rc = $session{$sessionId}{db} -> disconnect();
  delete $session{$sessionId};
  $logger->info("Removed session $sessionId");
}

sub handleSchedules {
  my $now = DateTime->now() -> set_time_zone($tz);
  my $ymd = $now -> ymd;
  my $hms = $now -> hms;
  my $db = $fw -> getFwdb;
  my $fwschedule = new Business::Bof::Server::Schedule($db);
  $fwschedule -> dailySchedule($ymd, $hms);
}

sub handleTasks {
  my ($kernel, $heap, $transaction) = @_[KERNEL, HEAP, ARG0];
  handleSchedules();
# do stuff
  runTasks($heap);
  $kernel->delay('handleTasks', $fw -> getServerConfig("taskDelay"));
}

sub runTasks {
  my $heap = shift;
  my $sessionId = 0; # Special session!
  $session{$sessionId}{timestamp} = DateTime->now();
  while (my $task = $fwtask -> getTask({status => 100})) {
    my %userinfo = $fw -> getUserinfo( {user_id => $task->{user_id}} );
    $session{$sessionId}{userInfo} = { %userinfo };
    my ($class, $method) = split/\//, $task->{function};
    my $data = xml2pl($task->{parameters});
    my $fw_task = $task->{task_id};
    startTask($heap, $sessionId,$class,$method,$data,$fw_task); 
  }
}

sub handleLogin {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my ($value) = values(%$params);
  my $result;
  $result = login($value);
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub login {
  my $logInfo = shift();
  my %userinfo = $fw -> getUserinfo( $logInfo );
  if (%userinfo) {
    my $sessionId = $fw -> getNewSessionid($logInfo->{name});
    $session{$sessionId}{userInfo} = { %userinfo };
    $session{$sessionId}{timestamp} = DateTime->now();
    my @menu = $fw->getMenu($userinfo{user_id});
    $session{$sessionId}{menu} = [ (@menu) ];
    my %allowed = $fw->getAllowed();
    $session{$sessionId}{allowed} = { %allowed };
    $session{$sessionId}{db} = $fw -> getdb({ userinfo => {%userinfo} });
    $logger->info("Login user $logInfo->{name}, session $sessionId");
    return $sessionId;
  } else {
    return 0
  }
}

sub handleLogout {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $result = $sessionId;
  if (defined($session{$sessionId})) {
    $result = logout($sessionId);
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub logout {
  my $sessionId = shift;
  removeSession($sessionId);
  return 0;
}

sub getClientdata {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $result = 0;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    $result = $fw -> getClientSettings();
    $result = _getSessiondata($sessionId, $result);
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub _getSessiondata {
  my $sessionId = shift;
  my %sp = %{ shift() };
  my %userInfo = %{$session{$sessionId}{userInfo}};
  $sp{menu}  = $session{$sessionId}{menu};
  $sp{allowed}  = $session{$sessionId}{allowed};
  $sp{userinfo} = { %userInfo };
  delete @{$sp{userinfo}}{'dbname', 'dbusername', 'dbschema', 'password', 'host'};
  return \%sp;
}

sub getData {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $parms = $params->{parms};
  my $result;
  if ($sessionId && defined($session{$sessionId}) &&
     defined($parms) && ref($parms) eq "HASH") {
              $session{$sessionId}{timestamp} = DateTime->now();
    $result = _getData($sessionId, $parms);
  } else {
    $result = "No session or missing parameters";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub _getData {
  my $sessionId = shift;
  my %sp = %{ shift() };
  $sp{'!DataSource'}  = $session{$sessionId}{db};
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

#
# Will dispatch call to different routines depending on parms
# parms{task} will callNewtask
# parms {long} will callMetholdlong
# otherwise it will be callMethod
#
sub findCallMethod{
  my ($heap, $response) = @_[HEAP, ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $parms = $params->{parms};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    if (defined($parms->{task})) {
      $result = callNewtask($sessionId, $parms);
    } elsif (defined($parms->{long})) {
      $result = callMethodlong($heap, $sessionId, $parms);
    } else {
      $result = callMethod($sessionId, $parms);
    }
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub callMethod {
  my $sessionId = shift;
  my %parms = %{ shift() };
  my $db = $session{$sessionId}{db};
  my $domain = $session{$sessionId}{userInfo}{domain};
  my $class = $parms{class};
  my $method = $parms{method};
  my $serverSettings = $fw -> getServerSettings();
  my $module = instantiate($class, $db, $serverSettings);
  my $res = $module->$method($parms{data}, $session{$sessionId}{userInfo});
  $logger->info("Method call: $class\:\:$method for $domain");
  return $res;
}
 
sub callMethodlong {
  my ($heap, $sessionId, $parms) = @_;
  my $domain = $session{$sessionId}{userInfo}{domain};
  my $class = $parms->{class};
  my $method = $parms->{method};
  my $data = $parms->{data} || "";
## Der har været en mening med TaskId, men hvad ?
  my $fw_task;
  $parms->{fw_task} = $fw_task;
  $logger->info("Method call (long): $class::$method for $domain");
  startTask($heap, $sessionId, $class, $method, $data, $fw_task)
    unless $session{$sessionId}{taskInProgress};
  $session{$sessionId}{taskInProgress} = $parms unless $parms->{parallel};
  return $fw_task;
}

sub startTask {
  my ($heap, $sessionId,$class,$method,$data,$fw_task) = @_; 
  my $domain = $session{$sessionId}{userInfo}{domain};
  my $task = POE::Wheel::Run->new(
    Program => sub {
      taskStart($session{$sessionId}{userInfo}, $domain, $class, $method,
       $data, $fw_task) 
    },
    StdoutFilter => POE::Filter::Reference->new(),
    StdoutEvent  => "taskResult",
    StderrEvent  => "taskDebug",
    CloseEvent   => "taskDone"
  );
  my $task_ID = $task->ID;
  $heap->{task}->{ $task_ID } = $task;
  $heap->{sessionId}->{ $task_ID } = $sessionId;
  $logger->info("Task start ($task_ID): $class\::$method for $domain");
}

#
# taskStart is the sub routine that is executed in its own process
#
sub taskStart {
  my ($userinfo, $domain, $class, $method, $data, $fw_task) = @_;
  my $filter = POE::Filter::Reference->new();
  my $fw = new Business::Bof::Server::Fw($conffile);
  my $fwdb = $fw -> newFwdb;
  my $db = $fw -> getdb({ userinfo => $userinfo });
  my $serverSettings = $fw -> getServerSettings();
  my $module = instantiate($class, $db, $serverSettings);
  my $res = $module->$method($data, $userinfo);
  my %result = ($fw_task => $res); 
  my $output = $filter->put( [ \%result ] );
  print @$output;

  $fwdb -> disconnect();
  $db -> disconnect();
}

sub callNewtask {
  my ($sessionId, $parms) = @_;
  my $domain = $session{$sessionId}{userInfo}{domain};
  my $class = $parms->{class};
  my $method = $parms->{method};
  my $data = $parms->{data} || "";
  my $taskId;
  if (defined($parms->{task})) {
    my $userinfo = $session{$sessionId}{userInfo};
    $taskId = $fwtask -> newTask({
       user_id => $userinfo->{user_id},
       function => "$class/$method",
       data => $data,
       status => 100
    });
  }
  $parms->{fw_task} = $taskId;
}

sub instantiate {
  my $type = shift;
  my $appclass = $fw -> getServerConfig("appclass");
  my $location       = "$appclass/$type.pm";
  my $class          = "$appclass:\:$type";
  require $location;
  return $class->new(@_);
}

sub taskResult {
  my ($heap, $result, $task_id) = @_[ HEAP, ARG0, ARG1 ];
  $heap->{taskResult}->{$task_id} = $result;
}

sub taskDone {
  my ($heap, $task_id) = @_[ HEAP, ARG0 ];
  my $task = $heap->{task}->{$task_id};
  my $sessionId = $heap->{sessionId}->{$task_id};
  my $result = $heap->{taskResult}->{$task_id};
  if (defined($result)) {
    my ($fw_task, $res) = (%{ $result });
    $res = pl2xml($res);
    if (!$sessionId) {
      $fwtask -> updTask({task_id => $fw_task, result => $res, status => 200});
    }
  }
# Any tasks waiting ?
  if (defined($session{$sessionId}{taskInProgress})) {
    my $parms = $session{$sessionId}{taskInProgress};
    my $class = $parms->{class};
    my $method = $parms->{method};
    my $data = $parms->{data} || "";
    my $taskId = $parms->{fw_task};
    startTask($heap, $sessionId, $class, $method, $data, $taskId);
    delete $session{$sessionId}{taskInProgress};
  }
  $logger->info("Task done: $task_id");
  delete $heap->{task}->{$task_id};
  delete $heap->{sessionId}->{$task_id};
}

sub taskDebug {
  my $result = $_[ARG0];
  print "Debug: $result\n";
}

sub cacheData {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $cachename = $params->{name};
  my $cache = $params->{data};
  my $result;
  if (defined($cachename) && defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    $result = _cacheData($sessionId, $cachename, $cache);
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub _cacheData {
  my ($sessionId, $cachename, $data) = @_;
  $session{$sessionId}{cache}{$cachename} = $data;
  return;
}

sub getCachedata {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $cachename = $params->{name};
  my $result;
  if (defined($cachename) && defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    $result = _getCachedata($sessionId, $cachename);
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub _getCachedata {
  my ($sessionId, $cachename) = @_;
  return $session{$sessionId}{cache}{$cachename};
}

sub getTask {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $taskId = $params->{taskId};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    $result = $fwtask -> getTask({task_id => $taskId, ro => 1});
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub getTasklist {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $cachename = $params->{name};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    my $userinfo = $session{$sessionId}{userInfo};
    $result = $fwtask -> getTasklist($userinfo);
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub printFile {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $data = $params->{data};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    my $serverSettings = $fw -> getServerSettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    $result = $fwprint -> printFile($params->{data}, $session{$sessionId}{userInfo});
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub getPrintfile {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $data = $params->{data};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    my $serverSettings = $fw -> getServerSettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    $result = $fwprint -> getFile($params->{data}, $session{$sessionId}{userInfo});
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub getPrintfilelist {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $data = $params->{data};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    my $serverSettings = $fw -> getServerSettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    $result = $fwprint -> getFilelist($params->{data}, $session{$sessionId}{userInfo});
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub getQueuelist {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my $sessionId = $params->{sessionId};
  my $data = $params->{data};
  my $result;
  if (defined($session{$sessionId})) {
    $session{$sessionId}{timestamp} = DateTime->now();
    my $serverSettings = $fw -> getServerSettings();
    my $fwprint = new Business::Bof::Server::Docprint($serverSettings);
    $result = $fwprint -> getQueuelist($params->{data}, $session{$sessionId}{userInfo});
  } else {
    $result = "No session";
  }
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub dumpSession {
  my $response = $_[ARG0];
  my $name = $fw -> getServerConfig("name");
  my $params = $response->soapbody;
  my ($data) = values(%$params);
  my $result = pl2xml(\%session);
  $response->content( $result );
  $_[KERNEL]->post( $name, 'DONE', $response );
}

sub run {
  $conffile = getParameters();
  init();
  $poe_kernel->run();
}

1;
__END__

=head1 NAME

Business::Bof::Server::CLI -- Server of The Business Oriented Framework

=head1 SYNOPSIS

perl -MBusiness::Bof::Server::CLI -e run -- -c F<etc/freemoney.xml>

=head1 DESCRIPTION

The Server of the Business Oriented Framework (bof) will read its
configuration parameters from an XML file (see the section L</The
configuration file> below), and will start listening on the specified
port.

The Server uses SOAP as its transport, in principle making it easy to
use any language to connect to as a client, and it will answer to these
calls:

=head2 Method calls

B<NOTE> All method calls (except login, which has only one parameter),
depends upon the parameters being named correctly. With SOAP::Lite this
is easy using the SOAP::Data::Name method; I'm not sure how it's done in
other languages.

=over 4

=item login($logInfo)

Login will take a hash reference to login data and validate it against
the Framework Database. If it is a valid data pair, it will return a
session ID for the client to use in all subsequent calls. The format of
the hash is C<< {name => $username, password => $password} >>

=item logout($sessionId)

Provide your session ID to this function so it can clean up after you.
The server will be grateful ever after!

=item getData($sessionId, $parms)

getData takes two parameters. The obvious session ID and a hash
reference with SOAP name C<parms>. The format of the hash is the same as
is used by DBIx::Recordset. E.g.:

C<<  my $parms = {
    '!Table' => 'order, customer',
    '!TabJoin' => 'order JOIN customer USING (contact_id)',
    '$where'  =>  'ordernr = ?',
    '$values'  =>  [ $ordernr ]
  }; >>

=item callMethod($sessionId, $parms)

callMethod will find the class and method, produce a new instant and
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

=item cacheData($sessionId, $cachename, $somedata);

The server saves the data with SOAP name C<data> under the name provided
with SOAP name C<name> for later retrieval by getCachedata.

=item getCachedata($sessionId, $cachename);

The server returns the cached data, given the key with SOAP name
C<name>.

=item getClientdata

This method returns the data provided in the ClientSettings section of
the BOF server's configuration file. It also provides some additional
information about the current session.

=item getTask($sessionId, $taskId);

The server returns the task with the given taskId.

=item getTasklist($sessionId);

The server returns the list of tasks.

=item printFile($sessionId, $parms)

printFile will print a file from Bof's queue system. The given parameter
(SOAP name C<parms>) indicates which file is to be printed.

It looks like this:

C<< $parms = {
  type => 'doc' or 'print', 
  file => $filename,
  queue => $queuename
}; >>

=item getPrintfile($sessionId, $parms)

getPrintfile works like printFile, exept it returns the file instead of
printing it.

=item getPrintfilelist($sessionId, $parms)

getPrintfilelist returns an array containing information about the files
in the chosen queue

C<< $parms = {
  type => 'doc' or 'print', 
  queue => $queuename
}; >>

=item getQueuelist($sessionId, $parms)

getQueuelist returns an array containing information about the available
queues.

C<< $parms = {
  type => 'doc' or 'print', 
}; >>

=item dumpSession

This method will disappear in a future release. It is ony provided right
now as a way of debugging the server and the client calls.

=back

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

The place in the file system where the application located. The server
expects that there is a src directory here.

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

=head1 Business Classes and Methods

The actual classes that the application server will service must adhere
to some standards.

=head2 The C<new> method

C<new> must accept three parameters, its type, the database handle and
the reference to the server settings as provided in the configuration
file.

=head2 The methods

The individual methods must accept two parameters, the single value
(scalar, hash ref or array ref) that the client program sent and a hash
ref with the session's user info.

=head1 Requirements

PostgreSQL, POE, SOAP::Lite, DateTime, Log4Perl

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
