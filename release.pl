#!/usr/bin/perl
use strict;
use warnings;

# check if there are versions in every module and if they are in the same
# allow updating version numbers to one specific version.

use autodie qw(:default system);
# needs IPC::System::Simple

use Cwd            ();
use File::Basename ();
use File::Copy     qw(copy);
use File::Find     qw(find);
use File::Slurp    qw(read_file write_file);
use File::Temp     ();

my $TRUNK   = "http://svn.perlide.org/padre/";
my $TAGS    = "http://svn.perlide.org/padre/tags";
my @LOCALES = map { substr(File::Basename::basename($_), 0, -3) } glob "share/locale/*.po";
my $error   = 0;

my ($rev, $version, $tag) = @ARGV;
die "Usage: $0 REV VERSION [--tag]\n"
	if not $version or $version !~ /^\d\.\d\d$/ or $rev !~ /^\d+$/;

my $start_dir = Cwd::cwd();
my $name = File::Basename::basename($start_dir);
#die "'$name'\n";
if ($name eq 'trunk') {
	$TRUNK .= 'trunk';
	$name   = 'Padre';
} else {
	$TRUNK .= "projects/$name";
}

my $dir = File::Temp::tempdir( CLEANUP => 1 );
chdir $dir;
print "DIR $dir\n";

_system("svn export --quiet -r$rev $TRUNK src");
chdir 'src';

if ($name eq 'Padre') {
	if (open my $fh, '>>', 'MANIFEST') {
		for my $locale ( @LOCALES ) {
			_system("msgfmt -o share/locale/$locale.mo share/locale/$locale.po");
			print {$fh} "\nshare/locale/$locale.mo\n";
		}
		close $fh;
	} else {
		die "Cannot open MANIFEST for appending: $!";
	}
}

#print "Setting VERSION $version\n";
find(\&check_version, 'lib');
die if $error;

_system("$^X Build.PL");
_system("$^X Build");
_system("$^X Build test");
_system("$^X Build disttest");
_system("$^X Build dist");
copy("$name-$version.tar.gz", $start_dir) or die $!;
if ($tag) {
	_system("svn cp -r$rev $TRUNK $TAGS/$name-$version -m'tag $name-$version'");
}
chdir $start_dir;


sub check_version {
    return if $File::Find::name =~ /\.svn/;
    return if $_ !~ /\.pm/;
    my @data = read_file($_);
    if (my ($line) = grep {$_ =~ /^our \$VERSION\s*=\s*'\d+\.\d\d';/ } @data ) {
		if ($line !~ /^(our \$VERSION\s*=\s*)'$version';/ ) {
			chomp $line;
			warn "Invalid VERSION in $File::Find::name  ($line)\n";
			$error++;
		}
    } else {
       warn "No VERSION in $File::Find::name\n";
       $error++;
    }
    return;
}

sub _system {
	my $cmd = shift;
	print "$cmd\n";
	system($cmd);
}
