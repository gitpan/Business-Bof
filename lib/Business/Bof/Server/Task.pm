package Business::Bof::Server::Task;

use warnings;
use strict;
use vars qw($VERSION);

$VERSION = 0.10;

use DBIx::Recordset;
use XML::Dumper;

sub new {
  my ($type, $db) = @_;
  my $self = {};
  $self->{db} = $db;
  return bless $self,$type;
}

sub newTask {
  my $self = shift;
  my %task = %{ shift() };
  my $db = $self->{db};
  my $parms;
  if (defined $task{data}) {
    $parms = pl2xml($task{data});
  } else {
    $parms = $task{parameters};
  }
  my %values = (
    user_id => $task{user_id},
    function => $task{function},
    title => $task{title},
    status => $task{status},
    parameters => $parms
  );
  my $set = DBIx::Recordset -> Insert ({%values,
     ('!DataSource'   => $db,
      '!Table' => "fw_task",
      '!Serial' => "task_id",
      '!Sequence' => "fw_tasksequence"
     )}
   );
  my $task_id = $$set -> LastSerial();
}

sub updTask {
  my $self = shift;
  my %values = %{ shift() };
  my $db = $self->{db};
  my $set = DBIx::Recordset -> Update ({%values,
     ('!DataSource'   => $db,
      '!Table'   => 'fw_task',
      '!PrimKey' =>  'task_id'
     )}
   );
}

sub getTask {
  my $self = shift;
  my $db = $self->{db};
  my $ro;  # Read Only
  my %values;
  if (ref $_[0] eq 'HASH') {
   %values = %{shift()};
   $ro = $values{ro} if $values{ro};
   undef $values{ro};
  }
  my $set = DBIx::Recordset -> Search ({%values,
    '!DataSource'   => $db,
    '!Table' => 'fw_task',
    '!Order' => 'task_id',
    '!PrimKey' =>  'task_id'
  });
  my $retVal;
  if (my $rec = $$set -> Next) {
    if (!$ro) {
      $values{status} = 150;
      $values{task_id} = $rec->{task_id};
      $self -> updTask(\%values);
    }
    my $parms = $rec->{parameters};
    my $data = xml2pl($parms); 
    $rec->{data} = $data;
    my %r;
    for my $k (keys %$rec) {
      if ($k eq 'result') {
        $r{$k} = xml2pl($rec->{$k})
      } else {
        $r{$k} = $rec->{$k};
      }
    };
    $retVal = \%r;
  }
  return $retVal;
}

sub getTasklist {
  my ($self, $userInfo) = @_;
  my $db = $self->{db};
  my $set = DBIx::Recordset -> Search ({
    '!DataSource'   => $db,
    '!Fields' => 'task_id, title, status',
    '!Table' => 'fw_task',
    '!Order' => 'task_id DESC',
    '$where' => 'user_id = ?',
    '$values'  =>  [$userInfo->{user_id}],
  });
##    '$max' => 20
  #return if !$$set -> MoreRecords;
  my @return;
  while (my $rec = $$set -> Next) {
    push @return, { ( %$rec ) };
  }
  \@return;
}

1;
__END__

=head1 NAME

Business::Bof::Server::Task -- Handle Bof task creation, updating and reading

=head1 SYNOPSIS

  use Business::Bof::Server::Task;

  my $task = new Business::Bof::Server::Task($db);
  my $taskId = $fw -> newTask({
     user_id => $user_id,
     function => "$class/$method",
     data => $data,
     status => 100
  });
  ...
  my $task = getTask({task_id => $taskId});
  ...

=head1 DESCRIPTION

Business::Bof::Server::Task creates, updates and reads the tasks that Bof
(Business Oriented Framework) uses to keep track of its batch processes.

When a client process wants to have a task executed at a later time,
and when there is a recurring scheduled task, this module handles the
necessary tasks.

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>

