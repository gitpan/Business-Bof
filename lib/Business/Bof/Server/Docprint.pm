package Business::Bof::Server::Docprint;

use strict;

use File::stat;
use Printer;

sub new {
  my ($type, $serverSettings) = @_;
  my $self = {};
  $self->{domdir} = $serverSettings->{domdir};
  return bless $self,$type;
}

sub printFile {
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
##    $prn->print($data);
##    rename $inFile, "$outDir/$if->{name}" if lc($type) eq 'print';
  }
}

sub getFile {
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

sub getFilelist {
  my ($self, $values, $userInfo) = @_;
  $self->{domain} = $userInfo->{domain};
  my $type = $values->{type} if defined($values->{type});
  my $queue = $values->{queue} if defined($values->{queue});
  my $fileDir = "$self->{domdir}/$self->{domain}/$type/$queue/";
  return $self -> _getFilelist($fileDir);
}

sub getQueuelist {
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
