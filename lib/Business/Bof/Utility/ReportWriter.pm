package Business::Bof::Utility::ReportWriter;

use POSIX qw(setlocale LC_NUMERIC);
use utf8;
use PDF::Report;

sub new {
  my ($type, %parms) = @_;
  my $self = {};
  $self = bless $self,$type;
  $self->{report}{papersize} = $parms{papersize};
  $self->{report}{locale} = $parms{locale};
  return $self;
}

sub processReport {
  my ($self, $outfile, $report, $head, $list) = @_;
  my %report = %$report;
  my @list = @$list;
  $self -> reportInit( $report{report} );
  $self -> pageHeader( $report{page}{header} );
  $self -> body( $report{body} );
  $self -> graphics( $report{graphics} );
  $self -> logos( $report{page}{logo} );
  $self -> breaks( $report{breaks} );
  $self -> fields( $report{fields} );
  $self -> printList(\@list, \%$head );
  $self -> printDoc($outfile);
}

sub reportInit {
  my ($self, $parms) = @_;
  $self->{report}{papersize} = $parms->{papersize};
  $self->{report}{locale} = $parms->{locale};
}

sub pageHeader {
  my ($self, $parms) = @_;
  $self->{report}{page} = $parms;
}

sub body {
  my ($self, $parms) = @_;
  $self->{report}{body} = $parms;
}

sub graphics {
  my ($self, $parms) = @_;
  $self->{report}{graphics} = $parms;
}

sub logos {
  my ($self, $parms) = @_;
  $self->{report}{logo} = $parms;
}

sub breaks {
  my ($self, $parms) = @_;
  $self->{report}{breaks} = $parms;
  my @breakorder;
  for (keys %$parms) {
    $breakorder[$parms->{$_}{order}] = $_;
  }
  $self->{report}{breaks}{order} = [ @breakorder ];
}

sub fields {
  my ($self, $parms) = @_;
  $self->{report}{fields} = $parms;
  my @fields = @$parms;
# Find maximum line height
  $self->{font}{maxheight} = 8;
  for (0..$#{ $self->{report}{fields} }) {
    $self->{fields}{$fields[$_]{name}} = $_;
    if (defined($fields[$_]{font}{size}) &&
      $fields[$_]{font}{size} > $self->{font}{_maxheight})
    {
      $self->{font}{_maxheight} = $fields[$_]{font}{size};
    }
  }
}

# Routines for report writing

sub calcYoffset {
  my ($self, $fontsize) = @_;
  $self->{ypos} -= $fontsize + 2;
  return $self->{ypos};
}

sub footer {
  my ($self, $fontsize) = @_;
  my $break = '_page';
  $self->{breaks}{$break} = '_break';
  my $text = $self -> makeHeadertext(0,
    $self->{report}{breaks}{$break}{text});
  $self->{breaktext}{$break} = $text;
  $self -> printBreak();
  $self->{breaks}{$break} = "";
}

sub makePagefunc {
  my ($page, $func) = @_;
  my @fields = ($func =~ /\$(\w*)/g);
  for my $field (@fields) {
    $func =~ s/\$$field/\$page->{$field}/g;
  }
  my $text;
  setlocale(LC_NUMERIC, $self->{report}{locale});
  eval('$text = ' . $func);
  setlocale( LC_NUMERIC, "C" );
  return $text;
}

sub makePagetext {
  my ($page, $text) = @_;
  my @fields = ($text =~ /\$(\w*)/g);
  for my $field (@fields) {
    $text =~ s/\$$field/$page->{$field}/eg;
  }
  return $text;
}

sub headerText {
  my $self = shift;
  my $p = $self->{pdf};
  my $page = $self->{pageData};
  for my $th (@{ $self->{report}{page}{text} }) {
    my $text;
    next if (defined($th->{depends}) && 
      !eval($self -> makePagetext($page, $th->{depends})));
    if (defined($th->{function})) {
      $text = makePagefunc($page, $th->{function});
    } else {
      $text = makePagetext($page, $th->{text});
    }
    $self->{ypos} = $self->{paper}{topmargen}-mmtoPt($th->{ypos})
     if $th->{ypos};
    if (defined($th->{font})) {
      $self->{font}{size} = $th->{font}{size} if $th->{font}{size};
      $self->{font}{face} = $th->{font}{face} if $th->{font}{face};
    }
    next if !$text;
    $p->setSize($self->{font}{size}+0);
    $p->setFont($self->{font}{face});
    $self->outText($text, $th->{xpos}, $self->{ypos}, $th->{align});
    $self -> calcYoffset($self->{font}{size}) unless $th->{sameline};
  }
}

sub printPageheader {
  my $self = shift;
  my $p = $self->{pdf};
  $self->{ypos} = $self->{paper}{topmargen} -
    mmtoPt($self->{report}{page}{number}{ypos})
    if $self->{report}{page}{number}{ypos};
  $self->outText($self->{report}{page}{number}{text}.$self->{pageData}{pagenr},
    $self->{report}{page}{number}{xpos},
    $self->{ypos}, $self->{report}{page}{number}{align}
  );
  $self -> calcYoffset($self->{font}{size}
  );
}

sub bodyStart {
  my $self = shift;
  my $p = $self->{pdf};
  my $body = $self->{report}{body};
  if (defined($body->{font})) {
    $self->{font}{size} = $body->{font}{size} if $body->{font}{size};
    $self->{font}{face} = $body->{font}{face} if $body->{font}{face};
  }
  $p->setSize($self->{font}{size}+0);
  $p->setFont($self->{font}{face});
  $self->{ypos} = $self->{paper}{topmargen}-mmtoPt($body->{ypos})
   if $body->{ypos};
  my $heigth = mmtoPt($body->{heigth}) if $body->{heigth};
  $heigth += mmtoPt($body->{ypos}) if $body->{ypos};
  $self->{paper}{heigth} = $heigth if $heigth;
  for (@{ $self->{report}{fields} }) {
    $self->outText($_->{text}, $_->{xpos}, $self->{ypos}, $_->{align});
  }
}

sub drawGraphics {
  my $self = shift;
  my $p = $self->{pdf};
  my $graphics = $self->{report}{graphics};
  $p->setGfxLineWidth($graphics->{width}+0) if defined($graphics->{width});
  for (@{ $graphics->{boxes} }) {
    my $bottomy = $self->{paper}{topmargen}-mmtoPt($_->{bottomy});
    my $topy = $self->{paper}{topmargen}-mmtoPt($_->{topy});
    $p->drawRect(mmtoPt($_->{topx}), $bottomy,
      mmtoPt($_->{bottomx}), $topy
    );
  }
}

sub drawLogos {
  my $self = shift;
  my $p = $self->{pdf};
  my $logos = $self->{report}{logo};
#  my $loc = setlocale( LC_NUMERIC );
#  setlocale( LC_NUMERIC, "C" );
  for (@{ $logos->{logo} }) {
    my $x = mmtoPt($_->{x});
    my $y = $self->{paper}{topmargen}-mmtoPt($_->{y});
    $p->addImgScaled($_->{name}, $x, $y, $_->{scale});
    #!!$p->importepsfile($_->{name}, mmtoPt($_->{topx}), mmtoPt($_->{topy}),
    #!!  mmtoPt($_->{bottomx}), mmtoPt($_->{bottomy}));
  }
#  setlocale( LC_NUMERIC, $loc )
}

sub newPage {
  my $self = shift;
  my $p = $self->{pdf};
  $self->{pageData}{pagenr}++;
  $self->{breaks}{'_page'} = "";
  $self -> footer() if $self->{pageData}{pagenr} > 1;
  $self->{ypos} = $self->{paper}{topmargen};
  $p->newpage;
  $self->{font}{size} = $self->{report}{page}{font}{size};
  $self->{font}{face} = $self->{report}{page}{font}{face};
  $p->setSize($self->{font}{size}+0);
  $p->setFont($self->{font}{face});
  $self -> headerText();
  $self -> printPageheader() if defined($self->{report}{page}{number});
  $self -> bodyStart();
  $self -> drawGraphics();
  $self -> drawLogos();
}

sub setLinefont {
  my ($self, $fld) = @_;
  if (defined($fld->{font})) {
    $self->{font}{size} = $fld->{font}{size} if $fld->{font}{size};
    $self->{font}{face} = $fld->{font}{face} if $fld->{font}{face};
  }
}

sub printLine {
  my ($self, $rec) = @_;
  my $p = $self->{pdf};
  my $fontsize = $self->{font}{_maxheight};
  $self -> calcYoffset($fontsize);
  for (@{ $self->{report}{fields} }) {
    $self -> setLinefont($_);
    $fontsize = $self->{font}{size}+0;
    #$p->setSize($fontsize);
    $p->setFont($self->{font}{face});
    if (!defined($_->{depends}) || defined($_->{depends})
    && eval($self -> makeHeadertext($rec, $_->{depends}))) {
      my $res;
      if (defined($_->{function})) {
        my $function = '$res = ' .
          $self -> makeHeadertext($rec, $_->{function});
        setlocale(LC_NUMERIC, $self->{report}{locale});
        eval($function);
        setlocale( LC_NUMERIC, "C" );
      } elsif (defined($_->{name})) {
        $res = $rec->{$_->{name}};
        setlocale(LC_NUMERIC, $self->{report}{locale});
        $res = sprintf($_->{format}, $res) if $_->{format};
        setlocale( LC_NUMERIC, "C" );
      }
      $self->outText($res, $_->{xpos}, $self->{ypos}, $_->{align});
    }
  }
}

sub sumTotals {
  my $self = shift;
  my $rec = shift;
  for my $break (@{ $self->{report}{breaks}{order} }) {
    if (defined($self->{report}{breaks}{$break}{total})) {
      foreach my $tot (@{ $self->{report}{breaks}{$break}{total} }) {
        $self->{totals}{$break}{$tot} += $rec->{$tot};
      }
    }
  }
}

sub checkforBreak {
  my ($self, $rec, $last) = @_;
  my $brk = '';
  for my $break (reverse @{ $self->{report}{breaks}{order} }) {
    if (($last && !($break eq '_page'))
      || $self->{breaks}{$break} ne $rec->{$break}) {
      $brk = '_break';
    }
    $self->{breaks}{$break} = $brk if $brk;
  }
}

sub setBreakfont {
  my ($self, $break) = @_;
  if (defined($self->{report}{breaks}{$break}{font})) {
    $self->{font}{size} = $self->{report}{breaks}{$break}{font}{size}
      if $self->{report}{breaks}{$break}{font}{size};
    $self->{font}{face} = $self->{report}{breaks}{$break}{font}{face}
      if $self->{report}{breaks}{$break}{font}{face};
  }
}

sub printBreak {
  my $self = shift;
  my $p = $self->{pdf};
  for my $break (@{ $self->{report}{breaks}{order} }) {
    if ($self->{breaks}{$break} eq '_break') {
      $self -> setBreakfont($break);
      $self -> calcYoffset($self->{font}{size});
      #$p->setSize($self->{font}{size}+0);
      $p->setFont($self->{font}{face});
      if (defined($self->{report}{breaks}{$break}{total})) {
        $self->outText("Total $self->{breaktext}{$break}",
          $self->{report}{breaks}{$break}{xpos}, $self->{ypos});
        foreach my $tot (@{ $self->{report}{breaks}{$break}{total} }) {
          my $amount = $self->{totals}{$break}{$tot};
          if ($self->{report}{breaks}{$break}{format}) {
            setlocale(LC_NUMERIC, $self->{report}{locale});
            $amount = sprintf($self->{report}{breaks}{$break}{format}, $amount);
            setlocale( LC_NUMERIC, "C" );
          }
          my $fldno = $self->{fields}{$tot};
          my $field = $self->{report}{fields}[$fldno];
          $self->outText($amount, $field->{xpos}, $self->{ypos}, $field->{align});
          $self->{totals}{$break}{$tot} = 0;
        }
      }
    }
  }
}

sub printTotals {
  my ($self, $rec) = @_;
  my $p = $self->{pdf};
  my $last = (ref $rec ne 'HASH');
  $self -> checkforBreak($rec, $last);
  $self -> printBreak();
}

sub makeHeadertext {
  my $self = shift;
  my ($rec, $text) = @_;
  my @fields = ($text =~ /\$(\w*)/g);
  for my $field (@fields) {
    $text =~ s/\$$field/$rec->{$field}/eg;
  }
  return $text;
}

sub printBreakheader {
  my ($self, $rec, $break) = @_;
  my $p = $self->{pdf};
  $self -> setBreakfont($break);
  $self -> calcYoffset($self->{font}{size});
  $p->setSize($self->{font}{size}+0);
  $p->setFont($self->{font}{face});
  my $text = $self -> makeHeadertext($rec,
    $self->{report}{breaks}{$break}{text});
  $self->outText($text, $self->{report}{breaks}{$break}{xpos}, $self->{ypos});
  $self->{breaktext}{$break} = $text;
}

sub saveBreaks {
  my $self = shift;
  my ($rec, $first) = @_;
  for my $break (reverse @{ $self->{report}{breaks}{order}}) {
    $self -> printBreakheader($rec, $break) 
      if $first and $break ne '_total' and $break ne '_page'
      or $self->{breaks}{$break} ne $rec->{$break};
    $self->{breaks}{$break} = $rec->{$break};
  }
}

sub processTotals {
  my $self = shift;
  my $rec = shift;
  my $first = (!defined($self->{started}));
  $self->{started} = 1;
  my $last = (ref $rec ne 'HASH');
  $self -> printTotals($rec) if !$first;
  $self -> saveBreaks($rec, $first) if !$last;
  $self -> sumTotals($rec) if !$last;
}

sub endPrint {
  my $self = shift;
  my $p = $self->{pdf};
  $self -> processTotals();
}

sub printList {
  my ($self, $list, $page) = @_;
  my @list = @$list;
  $self->{pageData} = $page;
  my $papersize = $self->{report}{papersize} || 'A4';
  my $orientation = $self->{report}{orientation} || 'Portrait';
  my $p = new PDF::Report(
    PageSize => $papersize,
    PageOrientation => $orientation
  );

  $self->{pdf} = $p;
  $self->{ypos} = -1;
  $self -> paperSize();

  foreach my $rec (@list) {
    my $bottommargen = $self->{paper}{topmargen} - $self->{paper}{heigth};
    $self -> newPage() if $self->{ypos} < $bottommargen;
    $self -> processTotals($rec);
    $self -> printLine($rec);
  }
  $self -> endPrint();
}

sub printDoc {
  my ($self, $filename) = @_;
  my $p = $self->{pdf};
  if ($filename) {
    open OUT, ">$filename";
    print OUT $p->Finish("none");
    close OUT;
  }
}

sub paperSize {
  my $self = shift;
  my $p = $self->{pdf};
  my ($pagewidth, $pageheigth) = $p->getPageDimensions();
  $self->{paper} = {
    width => $pagewidth,
    topmargen => $pageheigth-20,
    heigth => $self->{paper}{topmargen}
  };
}

sub outText {
  my ($self, $text, $x, $y, $align) = @_;
  my $p = $self->{pdf};
  $x = mmtoPt($x);
  # $text =~ s/\n//g; # If addText necessary to remove newlines
  utf8::decode($text) if utf8::is_utf8($text);
  my $sw = 0;
  $sw = int($p->getStringWidth($text)+.5) if lc($align) eq 'right';
  $x -= $sw;
  my $margen = 20;
  my $width = $self->{paper}{width}-$x-20;
  #$p->setAddTextPos($x, $y);
  #$p->addText($text, $x, $width);
  $p->addParagraph($text, $x, $y,
    $self->{paper}{width}-$x-20,
    $self->{paper}{topmargen}-$y, 0
  );
  my ($hPos, $vPos) = $p->getAddTextPos();
  $self->{ypos} = $vPos;
}

sub mmtoPt {
  my $mm = shift;
  return int($mm/.3527777);
}

1;
