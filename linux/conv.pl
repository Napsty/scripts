#!/usr/bin/perl -W

use strict;
my @in;
my $file;

sub tobinary() {
 my @in;
 my $out;
 my $x;
 @in = @_;
 for($x=0;$x<=$#in;$x++) {
     $out .= unpack("B*", $in[$x]);
 }
 print("$out");
 print("\n");
}

sub totext() {
 my @in;
 my $out;
 my $x;
 @in = @_;
 for($x=0;$x<=$#in;$x++) {
     $out = pack("B*", $in[$x]);
  print($out);
 }
 print("\n");
}

sub help() {
 print("\nUsage: $0 [-b | -t] [-f filename | \"Test to convert\"]\n\n");
 print(" -b        : text to binary conversion\n");
 print(" -t        : binary to text conversion\n");
 print(" filename  : file to be converted\n");
 print(" message   : text to be converted\n");
}

if (@ARGV < 2) { 
 &help();
 exit(1);
}

if ($ARGV[0] eq '-b') {
  if ($ARGV[1] eq '-f') {
     $file = $::ARGV[2];
     open(F, "<$file") || die "Error: unable to open $file - $!\n";

     @in = <F>;
     close(F);
     if (!@in) {
        print("Error: no data in $file\n");
        exit(1);
     }
  } else {
     @in = $::ARGV[1];
  }
  &tobinary(@in);
}
elsif ($ARGV[0] eq '-t') {
  if ($ARGV[1] eq '-f') {
     $file = $::ARGV[2];
     open(F, "<$file") || die "Error: unable to open $file - $!\n";

     @in = <F>;
     close(F);
     if (!@in) {
        print("Error: no data in $file\n");
        exit(1);
     }
  } else {
     @in = $::ARGV[1];
  }
  &totext(@in);
}
else {
 &help();
 exit(1);
}
