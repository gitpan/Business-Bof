package Business::Bof::Server::Docprint;

use strict;
use File::stat;
use Printer;

our $VERSION = 0.03;

sub new {
  my ($type, $serverSettings) = @_;
  my $self = {};
  $self->{domdir} = $serverSettings->{domdir};
  return bless $self,$type;
}

sub print_file {
  my ($self, $values, $userInfo) = @_;
  $self->{domain} = $userInfo->{domain};
  my $file = $values->{file} if defined($values->{file});
  my $queue = $values->{queue} if defined($values->{queue});
  my $type = $values->{type} || 'print';
  my $prn = new Printer();
  $prn->use_default;
  my $outDir = "$self->{domdir}/$self->{domain}/doc/";
  my $prnFiles;
  if ($file) {
    my $fileDir = "$self->{domdir}/$self->{domain}/$type/$queue/";
    push @$prnFiles, {name => $file, path => $fileDir}
  } else {
    $prnFiles = $self -> getFilelist({type => $type, queue => $queue}, $userInfo);
  }
  for my $if (@$prnFiles) {
    my $fn = $if->{name};
    my $inFile = $if->{path} . $if->{name};
    open IN, $inFile or die("Can't open $inFile\n");
    my $data;
    while (<IN>) {$data .= $_};
    close IN;
    $prn->print($data);
    rename $inFile, "$outDir/$if->{name}" if lc($type) eq 'print';
  }
}

sub get_file {
  my ($self, $values, $userInfo) = @_;
  $self->{domain} = $userInfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $queue = $values->{queue} if defined($values->{queue});
  my $file = $values->{file} if defined($values->{file});
  my $fileDir = "$self->{domdir}/$self->{domain}/$type/$queue/";
  my $inFile = $fileDir . $file;
  open IN, $inFile or die("Can't open $inFile\n");
  my $data;
  while (<IN>) {$data .= $_};
  close IN;
  return $data;
}

sub get_filelist {
  my ($self, $values, $userInfo) = @_;
  $self->{domain} = $userInfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $queue = $values->{queue} if defined($values->{queue});
  my $fileDir = "$self->{domdir}/$self->{domain}/$type/$queue/";
  return $self -> _getFilelist($fileDir);
}

sub get_queuelist {
  my ($self, $values, $userInfo) = @_;
  $self->{domain} = $userInfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $qDir = "$self->{domdir}/$self->{domain}/$type/";
  return $self -> _getQueuelist($qDir);
}

sub fileSort {
  my  @files = @_;
  my @sort = sort {$b->{mtime} <=> $a->{mtime}} @files;
  return \@sort;
}

sub _getFilelist {
  my ($self, $dir) = @_;
  my @files;
  opendir(DIR, $dir) || die "can't opendir $dir: $!";
  while (my $file = readdir(DIR)) {
    my $fn = "$dir/$file";
    next unless -f $fn;
    my $sb = stat($fn);
    push @files, {name => $file, path => $dir, mtime => $sb->mtime}
  }
  closedir DIR;
  return fileSort(@files);
}

sub _getQueuelist {
  my ($self, $dir) = @_;
  my @files;
  opendir(DIR, $dir) || die "can't opendir $dir: $!";
  while (my $file = readdir(DIR)) {
    my $fn = "$dir/$file";
    next unless -d $fn && !($file eq '.' || $file eq'..');
    push @files, {name => $file, path => $dir}
  }
  closedir DIR;
  return \@files;
}

1;

__END__

=head1 NAME

Business::Bof::Server::Docprint -- Handles printing of documents

=head1 SYNOPSIS

  use Business::Bof::Server::Docprint

  my $prt = new Business::Bof::Server::Docprint($serverSettings);

  my $result = $prt -> printFile($data, $userInfo);
  ...

=head1 DESCRIPTION

Business::Bof::Server::Docprint handles the job of administrating the
printing of documenents for BOF. It is not meant to be called directly,
only from Business::Bof::Server::CLI, which will be the user's primary
interface to printing.

=head2 Methods

Docprint has four methods:

=over 4

=item print_file

Prints a file according to the provided data

$data = {
  type => 'doc' or 'print',
  file => $filename,
  queue => $queuename
};

$result = $prt -> print_file($data, $userInfo);

User applications are expected to print to the doc directory. Docprint
will find the file there or in the print directory and print it. It will
move any printed file from the doc to the print directory.
You can have any number of queues.

=item get_file

Returns the requested file.

my $result = $prt -> get_file($data, $userInfo);

=item get_printfilelist

Returns a list of files in either the doc or the print directory.

my $result = $prt -> getFilelist($data, $userInfo);

=item get_queuelist

Returns a list of queues in the doc or the print directory.

my $result = $prt -> get_queuelist($data, $userInfo);

=back

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
