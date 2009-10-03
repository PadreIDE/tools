#!/usr/bin/perl

use strict;
use warnings;

#
use Cwd                   qw{ cwd };
use File::Spec::Functions qw{ catfile catdir };
use File::Find::Rule;
use FindBin qw{ $Bin };

# check if perltidyrc file exists
my $perltidyrc = catfile( $Bin, 'perltidyrc' );
die "cannot find perltidy configuration file: $perltidyrc\n"
	unless -e $perltidyrc;

# build list of perl files to reformat
my @pmfiles = @ARGV
	? @ARGV
	: grep {/^lib/}	File::Find::Rule->file->name("*.pm")->relative->in(cwd);
my @tfiles = @ARGV
	? @ARGV
	: grep {/^t/}	File::Find::Rule->file->name("*.t")->relative->in(cwd);

my @files = (@pmfiles,@tfiles);

my @extras = ('Makefile.PL', 'Build.PL', 'dev.pl', 'script/padre',);
for my $extra (@extras) {
	push @files, $extra if -f $extra;
}

# formatting documents
my $cmd = "perltidy --backup-and-modify-in-place --profile=$perltidyrc @files";
system($cmd) == 0 or die "perltidy exited with return code " . ($? >> 8);

# removing backup files
unlink map {"$_.bak"} @files;