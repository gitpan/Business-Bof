package Business::Bof::Server::Schedule;

use warnings;
use strict;
use vars qw($VERSION);

$VERSION = 0.02;

use DBIx::Recordset;
use XML::Dumper;
use Business::Bof::Server::Task;

sub new {
  my ($type, $db) = @_;
  my $self = {};
  $self->{db} = $db;
  return bless $self,$type;
}

sub newSchedule {
  my $self = shift;
  my %schedule = %{ shift() };
  my $db = $self->{db};
  my $parms = pl2xml([$schedule{data}]);
  my %values = (
    user_id => $schedule{user_id},
    function => $schedule{function},
    title => $schedule{title},
    parameters => $parms,
  );
  my $set = DBIx::Recordset -> Insert ({%values,
     ('!DataSource'   => $db,
      '!Table' => "fw_schedule",
      '!Serial' => "schedule_id",
      '!Sequence' => "fw_schedulesequence"
     )}
   );
  my $schedule_id = $$set -> LastSerial();
}

sub updSchedule {
  my $self = shift;
  my %values = %{ shift() };
  my $db = $self->{db};
  my $set = DBIx::Recordset -> Update ({%values,
     ('!DataSource'   => $db,
      '!Table'   => 'fw_schedule',
      '!PrimKey' =>  'schedule_id'
     )}
   );
}

sub getSchedule {
  my $self = shift;
  my $db = $self->{db};
  my %values;
  %values = %{shift()};
  my $set = DBIx::Recordset -> Search ({%values,
    '!DataSource'   => $db,
    '!Table' => 'fw_schedule',
    '!Order' => 'schedule_id',
  });
  my $retVal;
  if (my $rec = $$set -> Next) {
    my $parms = $rec->{parameters};
    my $data = eval("$parms"); 
    $rec->{data} = $data;
    my %r;
    for my $k (keys %$rec) {$r{$k} = $rec->{$k}};
    $retVal = \%r;
  }
  return $retVal;
}

sub getSchedulelist {
  my ($self, $sched, $date, $time, $trunc, $comp) = @_;
  my $db = $self->{db};
  my $set = DBIx::Recordset -> Search ({
    '!DataSource'   => $db,
    '!Table' => 'fw_schedule',
    '$where' => 'schedtype = ?
     AND ?::time >= schedule::time
     AND (lastrun IS null OR date_trunc(?, lastrun) < ?)',
    '$values'  =>  [$sched, $time, $trunc, $comp],
    '!PrimKey' =>  'schedule_id'
  });
  return $set;
}

sub addTask {
  my ($self, $fwtask, $schedule) = @_;
  my $db = $self->{db};
  $fwtask -> newTask({
    user_id => $schedule->{user_id},
    function => $schedule->{function},
    title => $schedule->{title},
    parameters => $schedule->{parameters},
    status => 100
  });
}

sub dailySchedule {
  my ($self, $date, $time) = @_;
  my $db = $self->{db};
  my $fwtask = new Business::Bof::Server::Task($db);
  my $set = $self -> getSchedulelist('D', $date, $time, 'day', $date);
  while (my $schedule = $$set -> Next) {
    $self -> addTask($fwtask, $schedule);
    $schedule->{lastrun} = "$date $time";
  }
}

1;
__END__

=head1 NAME

Business::Bof::Server::Schedule -- Schedule schedules to be run

=head1 SYNOPSIS

  use Business::Bof::Server::Schedule;

  my $sch = new Business::Bof::Server::Schedule($db);
##
  my $scheduleId = $fw -> newSchedule({
     user_id => $user_id,
     function => "$class/$method",
     data => $data
  });
  ...
  my $schedule = getSchedule({schedule_id => $scheduleId});
  ...

=head1 DESCRIPTION

Bof::Server::Schedule creates, updates and reads the schedules that Bof (Business 
Oriented Framework) uses to keep track of its batch processes.

When a client process wants to have a schedule executed at a later time,
and when there is a recurring scheduled schedule, this module handles the
necessary schedules.

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>

