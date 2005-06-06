package Business::Bof::Server::Docprint;

use strict;
use File::stat;
use Printer;

our $VERSION = 0.05;

sub new {
  my ($type, $serverSettings) = @_;
  my $self = {};
  $self->{domdir} = $serverSettings->{domdir};
  return bless $self,$type;
}

sub print_file {
  my ($self, $values, $userinfo) = @_;
  $self->{domain} = $userinfo->{domain};
  my $file = $values->{file} if defined($values->{file});
  my $queue = $values->{queue} if defined($values->{queue});
  my $type = $values->{type} || 'print';
  my $prn = new Printer();
  $prn->use_default;
  my $out_dir = "$self->{domdir}/$self->{domain}/doc/";
  my $prn_files;
  if ($file) {
    my $file_dir = "$self->{domdir}/$self->{domain}/$type/$queue/";
    push @$prn_files, {name => $file, path => $file_dir}
  } else {
    $prn_files = $self -> get_filelist({type => $type, queue => $queue}, $userinfo);
  }
  for my $if (@$prn_files) {
    my $fn = $if->{name};
    my $in_file = $if->{path} . $if->{name};
    open IN, $in_file or die("Can't open $in_file\n");
    my $data;
    while (<IN>) {$data .= $_};
    close IN;
    $prn->print($data);
    rename $in_file, "$out_dir/$if->{name}" if lc($type) eq 'print';
  }
}

sub get_file {
  my ($self, $values, $userinfo) = @_;
  $self->{domain} = $userinfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $queue = $values->{queue} if defined($values->{queue});
  my $file = $values->{file} if defined($values->{file});
  my $file_dir = "$self->{domdir}/$self->{domain}/$type/$queue/";
  my $in_file = $file_dir . $file;
  open IN, $in_file or die("Can't open $in_file\n");
  my $data;
  while (<IN>) {$data .= $_};
  close IN;
  return $data;
}

sub get_filelist {
  my ($self, $values, $userinfo) = @_;
  $self->{domain} = $userinfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $queue = $values->{queue} if defined($values->{queue});
  my $file_dir = "$self->{domdir}/$self->{domain}/$type/$queue/";
  return $self -> _get_filelist($file_dir);
}

sub get_queuelist {
  my ($self, $values, $userinfo) = @_;
  $self->{domain} = $userinfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $q_dir = "$self->{domdir}/$self->{domain}/$type/";
  return $self -> _get_queuelist($q_dir);
}

sub fileSort {
  my  @files = @_;
  my @sort = sort {$b->{mtime} <=> $a->{mtime}} @files;
  return \@sort;
}

sub _get_filelist {
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

sub _get_queuelist {
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

  my $result = $prt -> print_file($data, $userinfo);
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

$result = $prt -> print_file($data, $userinfo);

User applications are expected to print to the doc directory. Docprint
will find the file there or in the print directory and print it. It will
move any printed file from the doc to the print directory.
You can have any number of queues.

=item get_file

Returns the requested file.

my $result = $prt -> get_file($data, $userinfo);

=item get_printfilelist

Returns a list of files in either the doc or the print directory.

my $result = $prt -> get_filelist($data, $userinfo);

=item get_queuelist

Returns a list of queues in the doc or the print directory.

my $result = $prt -> get_queuelist($data, $userinfo);

=back

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
