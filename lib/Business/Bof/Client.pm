package Business::Bof::Client;

use warnings;
use strict;
use vars qw($VERSION);

use SOAP::Lite;

$VERSION = 0.02;

sub new {
  my $type = shift;
  my $self = {};
  my %params = @_;
  my $protocol = $params{ssl} ? 'https' : 'http';
  my $uri = "$protocol://$params{server}:$params{port}/";
  my $proxy = "$uri$\?session=$params{session}";
  my $remote = SOAP::Lite -> uri($uri) -> proxy($proxy);
  die("Couldn't connect to server $uri") unless $remote;
  $self->{remote} = $remote;
  return bless $self,$type;
}

sub disconnect {
  my $self = shift;
  my $remote = $self->{remote};
  $remote->disconnect;
}

sub ping {
  my $self = shift;
  my $remote = $self->{remote};
  return $remote->ping;
}

sub setSessionId {
  my ($self, $sessionId) = @_;
  $self->{SOAPsessionId} = SOAP::Data->name(sessionId => $sessionId);
}

sub login {
  my ($self, $logInfo) = @_;
  my $remote = $self->{remote};
  my $sessionId = $remote->login($logInfo)->result;
  $self -> setSessionId($sessionId);
  return $sessionId;
}

sub logout {
  my $self = shift;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $res = $remote->logout($sessionId)->result;
  return $res;
}

sub getClientdata {
  my $self = shift;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $res = $remote->getClientdata($sessionId)->result;
  return $res;
}

sub getData {
  my ($self, $parms) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPparms = SOAP::Data->name(parms => $parms);
  my $res = $remote->getData($sessionId, $SOAPparms)->result;
  return $res;
}

sub cacheData {
  my ($self, $name, $data) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPname = SOAP::Data->name(name => $name);
  my $SOAPdata = SOAP::Data->name(data => $data);
  my $res = $remote->cacheData($sessionId, $SOAPname, $SOAPdata)->result;
  return $res;
}

sub getCachedata {
  my ($self, $name) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPname = SOAP::Data->name(name => $name);
  my $res = $remote->getCachedata($sessionId, $SOAPname)->result;
  return $res;
}

sub getTask {
  my ($self, $taskId) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPtaskId = SOAP::Data->name(taskId => $taskId);
  my $res = $remote->getTask($sessionId, $SOAPtaskId)->result;
  return $res;
}

sub getTasklist {
  my ($self) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $res = $remote->getTasklist($sessionId)->result;
  return $res;
}

sub printFile {
  my ($self, $data) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPdata = SOAP::Data->name(data => $data);
  my $res = $remote->printFile($sessionId, $SOAPdata)->result;
  return $res;
}

sub getPrintfile {
  my ($self, $data) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPdata = SOAP::Data->name(data => $data);
  my $res = $remote->getPrintfile($sessionId, $SOAPdata)->result;
  return $res;
}

sub getPrintfilelist {
  my ($self, $data) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPdata = SOAP::Data->name(data => $data);
  my $res = $remote->getPrintfilelist($sessionId, $SOAPdata)->result;
  return $res;
}

sub getQueuelist {
  my ($self, $data) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPdata = SOAP::Data->name(data => $data);
  my $res = $remote->getQueuelist($sessionId, $SOAPdata)->result;
  return $res;
}


sub callMethod {
  my ($self, $parms) = @_;
  my $sessionId = $self->{SOAPsessionId};
  my $remote = $self->{remote};
  my $SOAPparms = SOAP::Data->name(parms => $parms);
  my $res = $remote->callMethod($sessionId, $SOAPparms)->result;
  return $res;
}

1;
__END__

=head1 NAME

Business::Bof::Client -- Client interface to Business Oriented Framework

=head1 SYNOPSIS

  use Business::Bof::Client;

  my $client = new Business::Bof::Client(server => localhost,
        port => 12345,
        session => myserver
  );
  my $sessionId = $client->login({
    name => $username,
    password => $password
  });

  my $parms = {
    '!Table' => 'order, customer',
    '!TabJoin' => 'order JOIN customer USING (contact_id)',
    '$where'  =>  'ordernr = ?',
    '$values'  =>  [ $ordernr ]
  };

  $result = $client -> getData($parms);
  $showresult = Dumper($result);
  print "getData: $showresult\n";

=head1 DESCRIPTION

Business::Bof::Client is a Perl interface to the Business Oriented
Framework Server. It is meant to ease the pain of accessing the server,
making SOAP programming unnecessary.

=head2 Method calls

=over 4

=item $obj = new(server => $hostname, port => $portnr, session => $session)

Instantiates a new client and performs a connection to the server with
the information given. Will fail if no server is active at that address.

=item $sessionId = $obj -> login({name => $username, password => $password});

Creates a session in the server and returns an ID. This ID is for the
pleasure of the user only.

I<name> and I<password> must be a valid pair in the Framework Database.

=item $obj -> logout()

Will terminate the session in the server and delete all working data.

=item $obj -> getClientdata()

Returns a hash ref with 

a) The data provided in the configuration file under the section
C<ClientSettings>.

b) Some data from the current session to be used by the client.

=item $obj -> getData($parms);

The purpose of getData is to request a set of data from the server. The
format of the request is the same as is used by DBIx::Recordset. E.g.:

  my $parms = {
    '!Table' => 'order, customer',
    '!TabJoin' => 'order JOIN customer USING (contact_id)',
    '$where'  =>  'ordernr = ?',
    '$values'  =>  [ $ordernr ]
  };

=item $obj -> cacheData($cachename, $somedata);

cacheData will let the server save some data for the client. It is
very useful in a web environment, where the client is stateless. E.g.:

my $data = {
  foo => 'bar',
  this => 'that'
};
$obj -> cacheData('some data', $data);

=item $obj -> getCachedata($cachename);

getCachedata retrieves the cached data, given the right key. E.g.:

$thedata = $obj -> getCachedata('some data');

=item $obj -> getTask($sessionId, $taskId);

The server returns the task with the given taskId.

=item $obj -> getTasklist($sessionId);

The server returns the list of tasks.

=item $obj -> printFile

printFile will print a file from Bof's queue system. The given parameter
indicates which file is to be printed.

It looks like this:

C<< $parms = {
  type => 'doc' or 'print', 
  file => $filename,
  queue => $queuename
}; >>

=item $obj -> getPrintfile

getPrintfile works like printFile, exept it returns the file instead of
printing it.

=item $obj -> getPrintfilelist

getPrintfilelist returns an array containing information about the files
in the chosen queue

C<< $parms = {
  type => 'doc' or 'print', 
  queue => $queuename
}; >>

=item $obj -> getQueuelist

getQueuelist returns an array containing information about the available
queues.

C<< $parms = {
  type => 'doc' or 'print', 
}; >>


=item $obj -> callMethod

The main portion of the client call will be callMethod. It will find the
class and method, produce a new instant and execute it with the given
data as parameter.

It looks like this:

$parms = {
  class => 'myClass',
  data => $data,
  method => 'myMethod',
  [long => 1,
  task => 1 ]
};

$res = $obj -> callMethod($parms);
 
Two modifiers will help the server determine what to do with the call.

If C<long> is defined, the server will handle it as a long running task,
spawning a separate process.

If C<task> is defined, the server will not execute the task immediately,
but rather save it in the framework's task table. The server will
execute it later depending on the server's configuration settings.

=back

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>

