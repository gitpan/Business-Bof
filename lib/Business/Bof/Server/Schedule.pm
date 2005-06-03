package Business::Bof::Server::Schedule;

use warnings;
use strict;
use XML::Dumper;

use Business::Bof::Server::Task;
use Business::Bof::Data::Fw;

our $VERSION = 0.02;

sub new {
  my ($type) = @_;
  my $self = {};
  return bless $self,$type;
}

sub newSchedule {
  my ($self, $schedule) = @_;
  my $fwsch = Business::Bof::Data::Fw::fw_schedule->create({
    user_id => $schedule->{user_id},
    function => $schedule->{function},
    title => $schedule->{title},
    parameters => pl2xml($schedule->{data}),
  });
  $fwsch->dbi_commit();
  my $schedule_id = $fwsch->schedule_id;
}

sub updSchedule {
  my ($self,$values) = @_;
  my $fwsch = Business::Bof::Data::Fw::fw_schedule->retrieve($values->{schedule_id});
  if ($values->{data}) {
    $values->{parameters} = pl2xml($values->{data}),
    delete $values->{data};
  }
  $fwsch->set(%$values);
  $fwsch->update();
  $fwsch->dbi_commit();
}

sub getSchedule {
  my ($self,$values) = @_;
  my $fwsch = Business::Bof::Data::Fw::fw_schedule->retrieve($values->{schedule_id});
  $fwsch->{data} = xml2pl($fwsch->parameters);
  return $fwsch;
}

sub getSchedulelist {
  my ($self, $sched, $date, $time, $trunc) = @_;
  my @schlist = Business::Bof::Data::Fw::fw_schedule->schedlist(
    $sched, $time, $trunc, $date
  );
  return \@schlist;
}

sub addTask {
  my ($self, $fwtask, $schedule) = @_;
  my $db = $self->{db};
  $fwtask -> newTask({
    user_id => $schedule->user_id,
    function => $schedule->function,
    title => $schedule->title,
    parameters => $schedule->parameters,
    status => 100
  });
}

sub dailySchedule {
  my ($self, $date, $time) = @_;
  my $db = $self->{db};
  my $fwtask = new Business::Bof::Server::Task($db);
  my $schlist = $self -> getSchedulelist('D', $date, $time, 'day');
  for my $schedule ( @$schlist) {
    $self -> addTask($fwtask, $schedule);
    $schedule->lastrun("$date $time");
    $schedule->update;
    $schedule->dbi_commit;
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
  my $scheduleId = $sch->newSchedule({
     user_id => $user_id,
     function => "$class/$method",
     data => $data
  });
  ...
  my $schedule = $sch->getSchedule({schedule_id => $scheduleId});
  ...

=head1 DESCRIPTION

Bof::Server::Schedule creates, updates and reads the schedules that Bof (Business 
Oriented Framework) uses to keep track of its batch processes.

When a client process wants to have a schedule executed at a later time,
and when there is a recurring scheduled schedule, this module handles the
necessary schedules.

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>

