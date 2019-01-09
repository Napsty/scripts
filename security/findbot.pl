#!/usr/bin/perl
# The above line may need to be changed to point at your version of Perl
#
#	This script attempts to find malicious files/scripts on your machine.
#	It specifically looks for spambots that we're aware of, as well
#	as "suspicious" constructs in various scripting languages.
#
#	To use it, you should put this in a file on your computer called
#	"findbot.pl" and make it executable by "chmod 755 findbot.pl".
#
#	By default, findbot.pl scans the directories /tmp, /usr/tmp, /home and
#	/var/www.  This script isn't fast.  So if you know where to look you can
#	speed things up by giving just the directories that you suspect has the
#	malware.
#
#	You can often find out what user is infected by using:
#		lsof -i | grep smtp
#	and looking for processes that are NOT your mail server.
#
#	If you're successful finding the user, you need to look everywhere the user
#	has write permissions - and you can run findbot.pl faster, by something like:
#
#	findbot.pl /tmp /usr/tmp /home/<user> <user's web directory>
#
#	There are two types of "detections" - "suspicious files" are files that contain
#	things that -may- be malicious.
#	"malware" is definitely malicious software.
#
#	This script needs the following command line utilities.  It will not run
#	if it can't find them, you will have to install them yourself:
#		- "md5sum" (Linux) or "md5" (FreeBSD etc) this appears to be standard
#			core utilities.
#		- "strings" - on Linux this is in the "binutils" package
#		- "file" - on Linux this is in the "file" package.
#
# Usage:
#	findbot.pl [-c] [directories...]
#
#	If a list of directories is supplied, it's used, otherwise,
#	/tmp, /usr/tmp, /home and /var/www are use by default.
#
#	The -c option is a shortcut to make finding cryptophp faster and
#	easier, but this may not work in all situations
#
# Very simple web malware detection module.
# Version 0.02 2013/01/02 Ray
# .01 -> .02:
#	- more strings of bad software
#	- search for encoded perl scripts
# .02 -> .03: 2013/01/10 Ray
#	- speed up
#	- MD5 stuff
# .03 -> .04: 2013/01/13 Ray
#	- improved docs
# .04 -> .05: 2013/01/20 Ray
#	- more patterns
#	- MAXLINES way too small
# .05 -> .06: 2014/10/31 Havriliuc Andrei, Hostvision srl, Romania
#	- many more patterns/heuristics from hoster's experience
#	- Thanks for the contribution!
# .06 -> 07: 2014/11/22 Ray
#	- Speed up specifically for current version of cryptophp

my $access = '(\.htaccess)';
my $accesspat = '(RewriteRule)';

## Extensions scanned

my $scripts = '\.(php|pl|cgi|bak|sh|txt|jpeg|jpg|png|gif|bmp|css)$';

## Patterns
my $scriptpat = '(social\.png|r57|c99|web shell|passthru|shell_exec|base64_decode|edoced_46esab|PHPShell|EHLO|MAIL FROM|RCPT TO|fsockopen|\$random_num\.qmail|getmxrr|\$_POST\[\'emaillist\'\]|if\(isset\(\$_POST\[\'action\'\]|BAMZ|shell_style|malsite|cgishell|Defaced|defaced|Defacer|defacer|hackmode|ini_restore|ini_get\("open_basedir"\)|runkit_function|rename_function|override_function|mail.add_x_header|\@ini_get\(\'disable_functions\'\)|open_basedir|openbasedir|\@ini_get\("safe_mode"|JIKO|fpassthru|passthru|hacker|Hacker|gmail.ru|fsockopen\(\$mx|\'mxs\.mail\.ru\'|yandex.ru|UYAP-CASTOL|KEROX|BIANG|FucKFilterCheckUnicodeEncoding|FucKFilterCheckURLEncoding|FucKFilterScanPOST|FucKFilterEngine|fake mailer|Fake mailer|Mass Mailer|MasS Mailer|ALMO5EAM|3QRAB|Own3d|eval\(\@\$_GET|TrYaG|Turbo Force|eval \( gzinflate|eval \(gzinflate|cgi shell|cgitelnet|\$_FILES\[file\]|\@copy\(\$_FILES|root\@|eval\(\(base64_decode|define\(\'SA_ROOT\'|cxjcxj|PCT4BA6ODSE|if\(isset\(\$s22\)|yb dekcah|dekcah|\@md5\(\$_POST|iskorpitx|\$__C|back connect|ccteam.ru|"passthru"|"shell_exec"|CHMOD_SHELL|EXIT_KERNEL_TO_NULL|original exploit|prepare_the_exploit|RUN_ROOTSHELL|ROOTSHELL|\@popen\(\$sendmail|\'HELO localhost\'|TELNET|Telnet|BACK-CONNECT|BACKDOOR|BACK-CONNECT BACKDOOR|AnonGhost|CGI-Telnet|webr00t|Ruby Back Connect|Connect Shell|require \'socket\'|HACKED|\@posix_getgrgid\(\@filegroup|\@posix_getpwuid\(\@fileowner|\&\#222\;\&\#199\;\&\#198\;\&\#227\;\&\#229\;|open_basedir|disable_functions|brasrer64r_rdrecordre|hacked|Hacked|\$sF\[4\]\.\$sF\[5\]\.\$sF\[9\]\.\$sF\[10\]\.|\$sF\="PCT4BA6ODSE_"|\$s21\=strtolower|6ODSE_"\;|Windows-1251|\@eval\(\$_POST\[|h4cker|Kur-SaD|\'Fil\'\.\'esM\'\.\'an\'|echo PHP_OS\.|\$testa != ""|\@PHP_OS|\$_POST\[\'veio\'\]|file_put_contents\(\'1\.txt\'|\$GLOBALS\["\%x61|\\\40\\\x65\\\166\\\x61\\\154\\\x28\\\163\\\x74\\\162\\\x5f\\\162\\\x65\\\160\\\x6c\\\141\\\x63\\\145|md5decrypter\.com|rednoize\.com|hashcracking\.info|milw0rm\.com|hashcrack\.com|function_exists\(\'shell_exec\'\)|Sh3ll Upl04d3r|Sh3ll Uploader|S F N S A W|\$\{\$\{"GLOBALS"\}|\$i59\="Euc\<v\#|\$contenttype \= \$_POST\[|eval\(base64|killall|1\.sh|\/usr\/bin\/uname -a|FilesMan|unserialize\(base64_decode|eval \( base64|eval \(base64|eval\(unescape|eval\(@gzinflate|gzinflate\(base64|str_rot13\(\@base64|str_rot13\(base64|gzinflate\(\@str_rot13|\/\.\*\/e|gzuncompress\(base64|substr\(\$c, \$a, \$b|\\\x47LOB|\\\x47LO\\\x42|\\\x47L\\\x4f\\\x42|\\\x47\\\x4c\\\x4f\\\x42|eval\("\?\>"\.base64_decode|\|imsU\||\!msiU|host\=base64|exif \= exif_|"\?Q\?|decrypt\(base64|Shell by|die\(PHP_OS|shell_exec\(base64_decode|\$_F\=|edoced_46esab|\$_D\=strrev|\]\)\)\;\}\}eval|\\\x65\\\x76\\\x61\\\x6c\\\x28|"e"\."va"\."l|\$so64 \=|sqlr00t|qx\{pwd\}|OOO0000O0|OOO000O00|OOO000000|\/\\\r\\\n\\\r\\\n|\$baseurl \= base64_decode|\$remoteurl\,\'wp-login\.php\'|\'http\:\/\/\'\.\$_SERVER\[\'SERVER_NAME\'\]|kkmvbziu|\$opt\("\/292\/e"|\$file\=\@\$_COOKIE\[\'|phpinfo\(\)\;die|return base64_decode\(|\@imap_open\(|\@imap_list\(|\$Q0QQQ\=0|\$GLOBALS\[\'I111\'\]|base64_decode\(\$GLOBALS|eval\(x\(|\@array\(\(string\)stripslashes|function rx\(\)| IRC |BOT IRC|\$bot_password|this bot|Web Shell|Web shell|getenv\(\'SERVER_SOFTWARE\'\)|file_exists\(\'\/tmp\/mb_send_mail\'\)|unlink\(\'\/tmp\/|imap_open\(\'\/etc\/|ini_set\(\'allow_url|\'_de\'\.\'code\'|\'base\'\.\(32\*2\))';

my @defaultdirs = ('/tmp', '/usr/tmp', '/home', '/var/www');

my $MAXLINES = 40000;

my($strings, $md5sum, $file, %badhash);

&inithelpers;
&badhashes;

#my $executable = '^(sshd|cache|exim|sh|bash)$';

if ($ARGV[0] =~ /^-c/) {
    $patterns = '(social\.png)';
    $scripts = '\.(php)$';
    shift(@ARGV);
}

if ($ARGV[0] =~ /^-/) {
    my $l = join(',', @defaultdirs);
    print STDERR <<EOF;
usage: $0 [-c] [directories to scan...]

    If no directories specified, script uses:
$l
    If -c specified, searches just for one set of cryptphp
    markers.  May miss newer versions

EOF
    exit 0;
}

  

if (!scalar(@ARGV)) {
    push(@ARGV, @defaultdirs);
}

for my $dir (@ARGV) {
    &recursion($dir);
}

sub recursion {
    my ($dir) = @_;
    my (@list);
    if (!opendir(I, "$dir")) {
	return if $! =~ /no such file/i;
	print STDERR "$dir: Can't open: $!, skipping\n";
	return;
    }
    @list = readdir(I);
    closedir(I);
    for my $mfile (@list) {
	next if $mfile =~ /^\.\.?$/;	# skip . and ..
	my $cf = $currentfile = "$dir/$mfile";

	$cf =~ s/'/'"'"'/g;	# hide single-quotes in filename
	$cf = "'$cf'";		# bury in single-quotes

	if (-d $currentfile && ! -l $currentfile) {
	    &recursion($currentfile);	# don't scan symlinks
	    next;
	} 
	next if ! -f $currentfile;
	if ($mfile =~ /$scripts/) {
	    &scanfile($currentfile, $scriptpat);
	} elsif ($mfile =~ /$access/) {
	    &scanfile($currentfile, $accesspat);
	}

	# up to here it's fast.

	next if -s $currentfile > 1000000 || -s $currentfile < 2000;

#print STDERR "$currentfile\n";

	my $type = `$file $cf`;

	if ($type =~ /(ELF|\d\d-bit).*executable/ || $currentfile =~ /\.(exe|scr|com)$/) {
#print STDERR "cf: $cf\n";
	    my $checksum = `$md5sum $cf`;
	    chomp($checksum);
	    $checksum =~ s/\s.*//;
	    if ($badhash{$checksum}) {
		print STDERR "$currentfile: Malware detected!\n";
		next;
	    }

	    my $strings = `$strings $cf`;
	    if ($strings =~ /\/usr\/bin\/perl/sm) {
		print STDERR "$currentfile: possible binary-encoded-perl\n";
		next;
	    }
	}
    }
}

sub scanfile {
    my ($currentfile, $patterns) = @_;
#print $currentfile, "\n";
    open(I, "<$currentfile") || next;
    my $linecount = 1;
    while(<I>) {
	chomp;
	if ($_ =~ /$patterns/) {
	    my $pat = $1;
	    my $string = $_;


## Wasn't printing the result correctly, so we gave up on this code.
#	    if ($string =~ /^(.*)$pat(.*)$/) {
#		$string = substr($1, length($1)-10, 10) .
#				      $pat .
#				      substr($2, 0, 10);
#	    }
	    #$string =~ s/^.*(.{,10}$pat.{,10}).*$/... $1 .../;
	    print "$currentfile: Suspicious($pat):\n $string\n\n";
	    last;
	}
	last if $linecount++ > $MAXLINES;
    }
    close(I);
}

sub inithelpers {
    if (-x '/usr/bin/md5sum') {
	$md5sum = '/usr/bin/md5sum';
    } elsif (-x '/sbin/md5') {
	$md5sum = '/sbin/md5 -q';
    }
    for my $x (('/bin', '/usr/bin')) {
	if (-x "$x/strings") {
	    $strings = "$x/strings";
	}
	if (-x "$x/file") {
	    $file = "$x/file";
	}
    }
    die "Can't find 'md5' checksumming tool - normally in Linux coretools package" if !$md5sum;
    die "Can't find 'strings' tool - normally in Linux bintools package" if !$strings;
    die "Can't find 'file' tool - normally in Linux 'file' package" if !$file;
}

sub badhashes {
    map { $badhash{$_} = 1; } ((
    	'f7536bb412d6c4573fd6fd819e1b07bb',
	'0fdb34f48166dae57ff410d723efd3f7',
	'396d1fb94d79b732f6ab2fa6c5f3ed39',
	'fd3c01133946d59ace4fdb49dde93268', #Directmailer .exe Windows binary
	));
}

