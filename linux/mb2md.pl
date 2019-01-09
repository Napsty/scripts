#!/usr/bin/perl -w
#
# $Id: mb2md.pl,v 1.26 2004/03/28 00:09:46 juri Exp $
#
# mb2md-3.20.pl      Converts Mbox mailboxes to Maildir format.
#

# !! This is a version modified for Dovecot. Use Dovecot mailing list
# !! <dovecot@dovecot.org> for questions, patches, etc. You don't have to be
# !! subscribed to send mail there. Do not send mail directly to people
# !! listed below.

# Public domain.
#
# currently maintained by:
# Juri Haberland <juri@koschikode.com>
# initially wrote by:
# Robin Whittle
#
# This script's web abode is http://batleth.sapienti-sat.org/projects/mb2md/ .
# For a changelog see http://batleth.sapienti-sat.org/projects/mb2md/changelog.txt
#
# The Mbox -> Maildir inner loop is based on  qmail's script mbox2maildir, which
# was kludged by Ivan Kohler in 1997 from convertandcreate (public domain)
# by Russel Nelson.  Both these convert a single mailspool file.
#
# The qmail distribution has a maildir2mbox.c program.
#
# What is does:
# =============
#
# Reads a directory full of Mbox format mailboxes and creates a set of
# Maildir format mailboxes.  Some details of this are to suit Courier
# IMAP's naming conventions for Maildir mailboxes.
#
#   http://www.inter7.com/courierimap/
#
# This is intended to automate the conversion of the old
# /var/spool/mail/blah file - with one call of this script - and to
# convert one or more mailboxes in a specifed directory with separate
# calls with other command line arguments.
#
# Run this as the user - in these examples "blah".

# This version supports conversion of:
#
#    Date    The date-time in the "From " line of the message in the
#            Mbox format is the date when the message was *received*.
#            This is transformed into the date-time of the file which
#            contains the message in the Maildir mailbox.
#
#            This relies on the Date::Parse perl module and the utime
#            perl function.
#
#            The script tries to cope with errant forms of the
#            Mbox "From " line which it may encounter, but if
#            there is something really screwy in a From line,
#            then perhaps the script will fail when "touch"
#            is given an invalid date.  Please report the
#            exact nature of any such "From " line!
#
#
#   Flagged
#   Replied
#   Read = Seen
#   Tagged for Deletion
#
#            In the Mbox message, flags for these are found in the
#            "Status: N" or "X-Status: N" headers, where "N" is 0
#            or more of the following characters in the left column.
#
#            They are converted to characters in the right column,
#            which become the last characters of the file name,
#            following the ":2," which indicates IMAP message status.
#
#
#                F -> F      Flagged
#                A -> R      Replied
#                R -> S      Read = Seen
#                D -> T      Tagged for Deletion (Trash)
#
#            This is based on the work of Philip Mak who wrote a
#            completely separate Mbox -> Maildir converter called
#            perfect_maildir and posted it to the Mutt-users mailing
#            list on 25 December 2001:
#
#               http://www.mail-archive.com/mutt-users@mutt.org/msg21872.html
#
#            Michael Best originally integrated those changes into mb2md.
#
#   UIDs (Dovecot and Courier)
#            Using the -U or -u options will cause this program to maintain
#            UIDVALIDITY and UIDLAST for folders and UIDs for individual
#            messages. The X-IMAP:, X-IMAPbase:, and X-UID: headers are
#            examined and appropriate files generated for Dovecot or Courier
#            in the destination Maildir to ensure these values are all kept.
#
#      UID support added by Julian Fitzell <jfitzell@gmail.com> June, 2008
#
#   Message Keywords (Dovecot only)
#            Using the -K option will cause this program to maintain message
#            keywords (also known by other names such as tags). This is
#            currently only supported for Dovecot and involves looking at
#            the X-IMAP:, X-IMAPbase:, and X-Keywords: headers. The keywords
#            are written to a file in the Maildir which maps them to flags.
#            The flags are then appended the message filenames.
#
#      Keyword support added by Julian Fitzell <jfitzell@gmail.com> June, 2008
#
#   In addition, the names of the message files in the Maildir are of a
#   regular length and are of the form:
#
#       7654321.000123.mbox:2,xxx
#
#   Where "7654321" is the Unix time in seconds when the script was
#   run and "000123" is the six zeroes padded message number as
#   messages are converted from the Mbox file.  "xxx" represents zero or
#   more of the above flags F, R, S or T.
#
# Message Size Tags
#
#   Additionally, there is optional support for including ,S= and ,W= tags
#   before the colon. These message names are still valid Maildir filenames
#   and the tags are used by mail programs to speed up calculation of quotas
#   and the return of message sizes to IMAP clients. ,S= is part of the
#   Maildir++ standard.
#   (See: http://www.inter7.com/courierimap/README.maildirquota.html )
#   As far as I can tell, ,W= is probably only used by Dovecot.
#   (See: http://wiki.dovecot.org/MailboxFormat/Maildir )
#
#   Size Tags added by Julian Fitzell <jfitzell@gmail.com> June, 2008
#
# ---------------------------------------------------------------------
#
#
# USAGE
# =====
#
# Run this as the user of the mailboxes, not as root.
#
#
# mb2md -h
# mb2md [-c] [-K] [-U|-u] [-S] [-W] -m [-d destdir]
# mb2md [-c] [-K] [-U|-u] [-S] [-W] -s sourcefile [-d destdir]
# mb2md [-c] [-K] [-U|-u] [-S] [-W] -s sourcedir [-l wu-mailboxlist] [-R|-f somefolder] [-d destdir] [-r strip_extension]
#
#  -c            use the Content-Length: headers (if present) to find the
#                beginning of the next message
#                Use with caution! Results may be unreliable. I recommend to do
#                a run without "-c" first and only use it if you are certain,
#                that the mbox in question really needs the "-c" option
#
#  -K            Preserve message keywords in a Dovecot-compatible way. This
#                looks for X-Keywords: tags and X-IMAP: and X-IMAPbase: tags
#                to determine keywords for messages and creates a Dovecot-
#                compatible "dovecot-keywords" file in "destdir"
#                NOTE: NO LOCKING IS DONE AND THE FILE MUST NOT ALREADY EXIST.
#                 IF YOU USE THIS OPTION ON A MAILDIR THAT MAY BE ACCESSED BY
#                 ANOTHER PROGRAM AT THE SAME TIME, STRANGE THINGS MAY HAPPEN.
#
#  -U            Preserve message UIDs in a Dovecot-compatible way
#                Looks for X-UID:, X-IMAP:, and X-IMAPbase: headers and
#                creates a Dovecot-compatible dovecot-uidlist file in
#                "destdir"
#                NOTE: NO LOCKING IS DONE AND THE FILE MUST NOT ALREADY EXIST.
#                 IF YOU USE THIS OPTION ON A MAILDIR THAT MAY BE ACCESSED BY
#                 ANOTHER PROGRAM AT THE SAME TIME, STRANGE THINGS MAY HAPPEN.
#
#  -u            Same as -U above, except creates a Courier IMAP-compatible
#                courierimapuiddb file instead. The only difference according
#                to http://wiki.dovecot.org/MailboxFormat/Maildir is that
#                Courier IMAP only stores the maildir file's basename
#                (everything before the colon)
#                NOTE: NO LOCKING IS DONE AND THE FILE MUST NOT ALREADY EXIST.
#                 IF YOU USE THIS OPTION ON A MAILDIR THAT MAY BE ACCESSED BY
#                 ANOTHER PROGRAM AT THE SAME TIME, STRANGE THINGS MAY HAPPEN.
#
#  -S            Add Maildir++ standard ,S= tag to the message filenames
#                indicating the size of the message on disk. This can be used
#                by Courier and Dovecot in calculating quotas.
#                I think Dovecot always uses this but not sure about Courier.
#                For Exim, see the quota_size_regex and maildir_tag config
#                statements.
#
#  -W            Add ,W= tag to the message filename indicating the RFC822.SIZE
#                of the message. This is the size of the message when actually
#                sent to an IMAP client with LF characters converted to CRLF
#                pairs as per the spec. Dovecot uses this to speed up returning
#                these sizes. Not sure if any other applications use it.
#
#  -m            If this is used then the source will
#                be the single mailbox at /var/spool/mail/blah for
#                user blah and the destination mailbox will be the
#                "destdir" mailbox itself.
#
#
#  -s source     Directory or file relative to the user's home directory,
#                which is where the the "somefolders" directories are located.
#                Or if starting with a "/" it is taken as a
#                absolute path, e.g. /mnt/oldmail/user
#
#                or
#
#                A single mbox file which will be converted to
#                the destdir.
#
#  -R		 If defined, do not skip directories found in a mailbox 
#		 directory, but runs recursively into each of them, 
# 		 creating all wanted folders in Maildir.
#		 Incompatible with '-f'
#
#  -f somefolder Directories, relative to "sourcedir" where the Mbox files
#                are. All mailboxes in the "sourcedir"
#                directory will be converted and placed in the
#                "destdir" directory.  (Typically the Inbox directory
#                which in this instance is also functioning as a
#                folder for other mailboxes.)
#
#                The "somefolder" directory
#                name will be encoded into the new mailboxes' names.
#                See the examples below.
#
#                This does not save an UW IMAP dummy message file
#                at the start of the Mbox file.  Small changes
#                in the code could adapt it for looking for
#                other distinctive patterns of dummy messages too.
#
#                Don't let the source directory you give as "somefolders"
#                contain any "."s in its name, unless you want to
#                create subfolders from the IMAP user's point of
#                view.  See the example below.
#
#                Incompatible with '-f'
#
#
#  -d destdir    Directory where the Maildir format directories will be created.
#                If not given, then the destination will be ~/Maildir .
#                Typically, this is what the IMAP server sees as the
#                Inbox and the folder for all user mailboxes.
#                If this begins with a '/' the path is considered to be
#                absolute, otherwise it is relative to the users
#                home directory.
#
#  -r strip_ext  If defined this extension will be stripped from
#                the original mailbox file name before creating
#                the corresponding maildir. The extension must be
#                given without the leading dot ("."). See the example below.
#
#  -l WU-file    File containing the list of subscribed folders.  If
#                migrating from WU-IMAP the list of subscribed folders will
#                be found in the file called .mailboxlist in the users
#                home directory.  This will convert all subscribed folders
#                for a single user:
#                /bin/mb2md -s mail -l .mailboxlist -R -d Maildir
#                and for all users in a directory as root you can do the
#                following:
#                for i in *; do echo $i;su - $i -c "/bin/mb2md -s mail -l .mailboxlist -R -d Maildir";done
#
#
#  Example
#  =======
#
# We have a bunch of directories of Mbox mailboxes located at
# /home/blah/oldmail/
#
#     /home/blah/oldmail/fffff
#     /home/blah/oldmail/ggggg
#     /home/blah/oldmail/xxx/aaaa
#     /home/blah/oldmail/xxx/bbbb
#     /home/blah/oldmail/xxx/cccc
#     /home/blah/oldmail/xxx/dddd
#     /home/blah/oldmail/yyyy/huey
#     /home/blah/oldmail/yyyy/duey
#     /home/blah/oldmail/yyyy/louie
#
# With the UW IMAP server, fffff and ggggg would have appeared in the root
# of this mail server, along with the Inbox.  aaaa, bbbb etc, would have
# appeared in a folder called xxx from that root, and xxx was just a folder
# not a mailbox for storing messages.
#
# We also have the mailspool Inbox at:
#
#     /var/spool/mail/blah
#
#
# To convert these, as user blah, we give the first command:
#
#    mb2md -m
#
# The main Maildir directory will be created if it does not exist.
# (This is true of any argument options, not just "-m".)
#
#    /home/blah/Maildir/
#
# It has the following subdirectories:
#
#    /home/blah/Maildir/tmp/
#    /home/blah/Maildir/new/
#    /home/blah/Maildir/cur/
#
# Then /var/spool/blah file is read, split into individual files and
# written into /home/blah/Maildir/cur/ .
#
# Now we give the second command:
#
#    mb2md  -s oldmail -R
#
# This reads recursively all Mbox mailboxes and creates:
#
#    /home/blah/Maildir/.fffff/
#    /home/blah/Maildir/.ggggg/
#    /home/blah/Maildir/.xxx/
#    /home/blah/Maildir/.xxx.aaaa/
#    /home/blah/Maildir/.xxx.bbbb/
#    /home/blah/Maildir/.xxx.cccc/
#    /home/blah/Maildir/.xxx.aaaa/
#    /home/blah/Maildir/.yyyy/
#    /home/blah/Maildir/.yyyy.huey/
#    /home/blah/Maildir/.yyyy.duey/
#    /home/blah/Maildir/.yyyy.louie/
#
#  The result, from the IMAP client's point of view is:
#
#    Inbox -----------------
#        |
#        | fffff -----------
#        | ggggg -----------
#        |
#        - xxx -------------
#        |   | aaaa --------
#        |   | bbbb --------
#        |   | cccc --------
#        |   | dddd --------
#        |
#        - yyyy ------------
#             | huey -------
#             | duey -------
#             | louie ------
#
# Note that although ~/Maildir/.xxx/ and ~/Maildir/.yyyy may appear
# as folders to the IMAP client the above commands to not generate
# any Maildir folders of these names.  These are simply elements
# of the names of other Maildir directories. (if you used '-R', they 
# whill be able to act as normal folders, containing messages AND folders)
#
# With a separate run of this script, using just the "-s" option
# without "-f" nor "-R", it would be possible to create mailboxes which
# appear at the same location as far as the IMAP client is
# concerned.  By having Mbox mailboxes in some directory:
# ~/oldmail/nnn/ of the form:
#
#     /home/blah/oldmail/nn/xxxx
#     /home/blah/oldmail/nn/yyyyy
#
# then the command:
#
#   mb2md -s oldmail/nn
#
# will create two new Maildirs:
#
#    /home/blah/Maildir/.xxx/
#    /home/blah/Maildir/.yyyy/
#
# Then what used to be the xxx and yyyy folders now function as
# mailboxes too.  Netscape 4.77 needed to be put to sleep and given ECT
# to recognise this - deleting the contents of (Win2k example):
#
#    C:\Program Files\Netscape\Users\uu\ImapMail\aaa.bbb.ccc\
#
# where "uu" is the user and "aaa.bbb.ccc" is the IMAP server
#
# I often find that deleting all this directory's contents, except
# "rules.dat", forces Netscape back to reality after its IMAP innards
# have become twisted.  Then maybe use File > Subscribe - but this
# seems incapable of subscribing to folders.
#
# For Outlook Express, select the mail server, then click the
# "IMAP Folders" button and use "Reset list".  In the "All"
# window, select the mailboxes you want to see in normal
# usage.
#
#
# This script did not recurse subdirectories or delete old mailboxes, before addition of the '-R' parameter :)
#
# Be sure not to be accessing the Mbox mailboxes while running this
# script.  It does not attempt to lock them.  Likewise, don't run two
# copies of this script either.
#
#
# Trickier usage . . .
# ====================
#
# If you have a bunch of mailboxes in a directory ~/oldmail/doors/
# and you want them to appear in folders such as:
#
# ~/Maildir/.music.bands.doors.Jim
# ~/Maildir/.music.bands.doors.John
#
# etc. so they appear in an IMAP folder:
#
#    Inbox -----------------
#        | music
#              | bands
#                    | doors
#                          | Jim
#                          | John
#                          | Robbie
#                          | Ray
#
# Then you could rename the source directory to:
#
#  ~/oldmail/music.bands.doors/
#
# then use:
#
#   mb2md -s oldmail -f music.bands.doors
#
#
# Or simply use '-R' switch with:
#   mb2md -s oldmail -R
#
#
# Stripping mailbox extensions:
# ============================= 
#
# If you want to convert mailboxes that came for example from
# a Windows box than you might want to strip the extension of
# the mailbox name so that it won't create a subfolder in your
# mail clients view.
#
# Example:
# You have several mailboxes named Trash.mbx, Sent.mbx, Drafts.mbx
# If you don't strip the extension "mbx" you will get the following
# hierarchy:
#
# Inbox
#      |
#       - Trash 
#      |       | mbx
#      |
#       - Sent 
#      |       | mbx
#      |
#       - Drafts 
#              | mbx
#
# This is more than ugly!
# Just use:
#   mb2md -s oldmail -r mbx
#
# Note: don't specify the dot! It will be stripped off
# automagically ;)
#
#------------------------------------------------------------------------------


use strict;
use Getopt::Std;
use Date::Parse;
use IO::Handle;
use Fcntl;

		    # print the usage message
sub usage() {
    print "Usage:\n";
    print "       mb2md -h\n";
    print "       mb2md [-c] [-K] [-U|-u] [-S] [-W] -m [-d destdir]\n";
    print "       mb2md [-c] [-K] [-U|-u] [-S] [-W] -s sourcefile [-d destdir]\n";
    die   "       mb2md [-c] [-K] [-U|-u] [-S] [-W] -s sourcedir [-l wu-mailboxlist] [-R|-f somefolder] [-d destdir] [-r strip_extension]\n";
}
		    # get options
my %opts;
getopts('d:f:chms:r:l:RUuKSW', \%opts) || usage();
usage() if ( defined($opts{h})
	|| (!defined($opts{m}) && !defined($opts{s})) );

# Get uid, username and home dir
my ($name, $passwd, $uid, $gid, $quota, $comment, $gcos, $homedir, $shell) = getpwuid($<);

# Get arguments and determine source
# and target directories.
my $mbroot = undef;	# this is the base directory for the mboxes
my $mbdir = undef;	# this is an mbox dir relative to the $mbroot
my $mbfile = undef;	# this is an mbox file
my $dest = undef;
my $strip_ext = undef;
my $use_cl = undef;	# defines whether we use the Content-Length: header if present
my $create_dovecot_keywords = 0; # defines whether we generate a Dovecot-compatible keywords file
my $create_dovecot_uidlist = 0;	# defines whether we generate a Dovecot-compatible uidlist UID file
my $create_courier_uidlist = 0;	# defines whether we generate a Courier IMAP-compatible courierimapuiddb UID file
my $note_message_size = 0;	# Whether we should add the ,S= message size tag
my $note_rfc822_size = 0;	# Whether we should add the ,W= RFC822.SIZE tag

# if option "-c" is given, we use the Content-Length: header if present
# dangerous! may be unreliable, as the whole CL stuff is a bad idea
if (defined($opts{c}))
{
	$use_cl = 1;
} else {
	$use_cl = 0;
}

# The -U and -u options cannot be specified together
if (defined($opts{U}) && defined($opts{u}))
{
	die("Options -U and -u cannot be specified together");
}

# if option "-K" is given, we will generate a Dovecot-compatible
# dovecot-keywords file in each Maildir
if (defined($opts{K}))
{
	$create_dovecot_keywords = 1;
}

# if option "-U" is given, we will generate a Dovecot-compatible
# dovecot-uidlist file in each Maildir
if (defined($opts{U}))
{
	$create_dovecot_uidlist = 1;
}

# if option "-u" is given, we will generate a Courier IMAP-compatible
# courierimapuiddb file in each Maildir
if (defined($opts{u}))
{
	$create_courier_uidlist = 1;
}

if (defined($opts{S}))
{
	$note_message_size = 1;
}

if (defined($opts{W}))
{
	$note_rfc822_size = 1;
}

# first, if the user has gone the -m option
# we simply convert their mailfile
if (defined($opts{m}))
{
	if (defined($ENV{'MAIL'})) {
		$mbfile = $ENV{'MAIL'};
	} elsif ( -f "/var/spool/mail/$name" ) {
		$mbfile = "/var/spool/mail/$name"
	} elsif ( -f "/var/mail/$name" ) {
		$mbfile = "/var/mail/$name"
	} else {
		die("I searched \$MAIL, /var/spool/mail/$name and /var/mail/$name, ".
			"but I couldn't find your mail spool file - ");
	}
}
# see if the user has specified a source directory
elsif (defined($opts{s}))
{
	# if opts{s} doesn't start with a "/" then
	# it is a subdir of the users $home
	# if it does start with a "/" then
	# let's take $mbroot as a absolut path
	$opts{s} = "$homedir/$opts{s}" if ($opts{s} !~ /^\//); 

	# check if the given source is a mbox file
	if (-f $opts{s})
	{
		$mbfile = $opts{s};
	}

	# otherwise check if it is a directory
	elsif (-d $opts{s})
	{
		$mbroot = $opts{s};
		# get rid of trailing /'s
		$mbroot =~ s/\/$//;

		# check if we have a specified sub directory,
		# otherwise the sub directory is '.'
		if (defined($opts{f}))
		{
			$mbdir = $opts{f};
			# get rid of trailing /'s
			$mbdir =~ s/\/$//;
		}
	}

	# otherwise we have an error
	else
	{
		die("Fatal: Source is not an mbox file or a directory!\n");
	}
}


# get the dest
defined($opts{d}) && ($dest = $opts{d}) || ($dest = "Maildir");
# see if we have anything to strip
defined($opts{r}) && ($strip_ext = $opts{r});
# No '-f' with '-R'
if((defined($opts{R}))&&(defined($opts{f}))) { die "No recursion with \"-f\"";}
# Get list of folders
my @flist;
if(defined($opts{l}))
{
    open (LIST,$opts{l}) or die "Could not open mailbox list $opts{l}: $!";
    @flist=<LIST>;
    close LIST;
}

# if the destination is relative to the home dir,
# check that the home dir exists
die("Fatal: home dir $homedir doesn't exist.\n") if ($dest !~ /^\// &&  ! -e $homedir);

#
# form the destination value
# slap the home dir on the front of the dest if the dest does not begin
# with a '/'
$dest = "$homedir/$dest" if ($dest !~ /^\//);
# get rid of trailing /'s
$dest =~ s/\/$//;


# Count the number of mailboxes, or
# at least files, we found.
my $mailboxcount = 0;

# Since we'll be making sub directories of the main
# Maildir, we need to make sure that the main maildir
# exists
&maildirmake($dest);

# Now we do different things depending on whether we convert one mbox
# file or a directory of mbox files
if (defined($mbfile))
{
	if (!isamailboxfile($mbfile))
        {
              print "Skipping $mbfile: not a mbox file\n";
        }
	else
	{
	      print "Converting $mbfile to maildir: $dest\n";
	      # this is easy, we just run the convert function
	      &convert($mbfile, $dest);
	}
}
# if '-f' was used ...
elsif (defined($mbdir))
{
	print "Converting mboxdir/mbdir: $mbroot/$mbdir to maildir: $dest/\n";
	
	# Now set our source directory
	my $sourcedir = "$mbroot/$mbdir";

	# check that the directory we are supposed to be finding mbox
	# files in, exists and is a directory
	-e $sourcedir or die("Fatal: MBDIR directory $sourcedir/ does not exist.\n");
	-d $sourcedir or die("Fatal: MBDIR $sourcedir is not a directory.\n");

	
	&convertit($mbdir,"");
}
# Else, let's work in $mbroot
else
{
	opendir(SDIR, $mbroot)
		or die("Fatal: Cannot open source directory $mbroot/ \n");


	while (my $sourcefile = readdir(SDIR))
	{
		if (-d "$mbroot/$sourcefile") {
			# Recurse only if requested (to be changed ?)
			if (defined($opts{R})) {
				print "convertit($sourcefile,\"\")\n";
				&convertit($sourcefile,"");
			} else {
			print("$sourcefile is a directory, but '-R' was not used... skipping\n");
			}
		}
    		elsif (!-f "$mbroot/$sourcefile")
		{
			print "Skipping $mbroot/$sourcefile : not a file nor a dir\n";
			next;
		}
		elsif (!isamailboxfile("$mbroot/$sourcefile"))
		{
			print "Skipping $mbroot/$sourcefile : not a mbox file\n";
			next;
		}
		else 
		{
			&convertit($sourcefile,"");
		}
	} # end of "while ($sfile = readdir(SDIR))" loop.
	closedir(SDIR);
	printf("$mailboxcount files processed.\n");
}
#

exit 0;

# My debbugging placeholder I can put somewhere to show how far the script ran.
# die("So far so good.\n\n");

# The isamailboxfile function
# ----------------------
# 
# Here we check if the file is a mailbox file, not an address-book or 
# something else.
# If file is empty, we say it is a mbox, to create it empty.
#
# Returns 1 if file is said mbox, 0 else.
sub isamailboxfile {
	my ($mbxfile) = @_;
	return 1 if(-z $mbxfile);
	sysopen(MBXFILE, "$mbxfile", O_RDONLY) or die "Could not open $mbxfile ! \n";
	while(<MBXFILE>) {
		if (/^From/) {
			close(MBXFILE);
			return 1;
		}
		else {
			close(MBXFILE);
			return 0;
		}
	}
}

# The convertit function
# -----------------------
#
# This function creates all subdirs in maildir, and calls convert() 
# for each mbox file.
# Yes, it becomes the 'main loop' :)
sub convertit
{
	# Get subdir as argument
	my ($dir,$oldpath) = @_;
	
	$oldpath =~ s/\/\///;

	# Skip files beginning with '.' since they are
	# not normally mbox files nor dirs (includes '.' and '..')
	if ($dir =~ /^\./)
	{
		print "Skipping $dir : name begins with a '.'\n";
		return;
	}
	my $destinationdir = $dir;
	my $temppath = $oldpath;

	# We don't want to have .'s in the $targetfile file
	# name because they will become directories in the
	# Maildir. Therefore we convert them to _'s
	$temppath =~ s/\./\_/g;
	$destinationdir =~ s/\./\_/g;
	
	# Appending $oldpath => path is only missing $dest
	$destinationdir = "$temppath.$destinationdir";

	# Converting '/' to '.' in $destinationdir
	$destinationdir =~s/\/+/\./g;
	
	# source dir
	my $srcdir="$mbroot/$oldpath/$dir";

	print("convertit(): Converting $dir in $mbroot/$oldpath to $dest/$destinationdir\n");
	&maildirmake("$dest/$destinationdir");

	# Subfolders are Maildir++ folders and should be marked by the
	# presence of an empty "maildirfolder" file
	sysopen(F, "$dest/$destinationdir/maildirfolder", O_CREAT|O_WRONLY, 0600) && close F;

	print("destination = $destinationdir\n");
	if (-d $srcdir) {
		opendir(SUBDIR, "$srcdir") or die "can't open $srcdir !\n";
		my @subdirlist=readdir(SUBDIR);
		closedir(SUBDIR);
		foreach (@subdirlist) {
			next if (/^\.+$/);
			print("Sub: $_\n");
			print("convertit($_,\"$oldpath/$dir\")\n");
			&convertit($_,"$oldpath/$dir");
		} 
	} else {
		# Source file verifs ....
		#
		return if(defined($opts{l}) && !inlist("$oldpath/$dir",@flist));

		if (!isamailboxfile("$mbroot/$oldpath/$dir"))
		{
			print "Skipping $dir (is not mbox)\n";
			return;
		}

		# target file verifs...
		#
		# if $strip_extension is defined,
		# strip it off the $targetfile
	    	defined($strip_ext) && ($destinationdir =~ s/\.$strip_ext$//);
		&convert("$mbroot/$oldpath/$dir","$dest/$destinationdir");
		$mailboxcount++;
	}
}
# The maildirmake function
# ------------------------
#
# It does the same thing that the maildirmake binary that 
# comes with courier-imap distribution
#
sub maildirmake
{
	foreach(@_) {
		-d $_ or mkdir $_,0700 or die("Fatal: Directory $_ doesn't exist and can't be created.\n");
	
		-d "$_/tmp" or mkdir("$_/tmp",0700) or die("Fatal: Unable to make $_/tmp/ subdirectory.\n");
		-d "$_/new" or mkdir("$_/new",0700) or die("Fatal: Unable to make $_/new/ subdirectory.\n");
		-d "$_/cur" or mkdir("$_/cur",0700) or die("Fatal: Unable to make $_/cur/ subdirectory.\n");
	}
}

# The inlist function
# ------------------------
#
# It checks that the folder to be converted is in the list of subscribed
# folders in WU-IMAP
#
sub inlist
{
	my ($file,@flist) = @_;
	my $valid = 0;
	# Get rid of the first / if any
	$file =~ s/^\///;
	foreach my $folder (@flist) {
		chomp $folder;
		if ($file eq $folder) {
			$valid = 1;
			last;
		}
	}
	if (!$valid) {
		print "$file is not in list\n";
	}
	else {
		print "$file is in list\n";
	}

	return $valid;
}
	
# 

# The convert function
# ---------------------
#
# This function does the down and dirty work of
# actually converting the mbox to a maildir
#
sub convert
{
	# get the source and destination as arguments
	my ($mbox, $maildir) = @_;

	print("Source Mbox is $mbox\n");
        print("Target Maildir is $maildir \n") ;

	# create the directories for the new maildir
	#
	# if it is the root maildir (ie. converting the inbox)
	# these already exist but thats not a big issue

	&maildirmake($maildir);

        # Change to the target mailbox directory.

        chdir "$maildir" ;

         	    # Converts a Mbox to multiple files
                    # in a Maildir.
                    # This is adapted from mbox2maildir.
                    #
                    # Open the Mbox mailbox file.


        if (sysopen(MBOX, "$mbox", O_RDONLY))
        {
            #printf("Converting Mbox   $mbox . . .  \n");
        }
        else
        {
            die("Fatal: unable to open input mailbox file: $mbox ! \n");
        }

                    # This loop scans the input mailbox for
                    # a line starting with "From ".  The
                    # "^" before it is pattern-matching
                    # lingo for it being at the start of a
                    # line.
                    #
                    # Each email in Mbox mailbox starts
                    # with such a line, which is why any
                    # such line in the body of the email
                    # has to have a ">" put in front of it.
                    #
                    # This is not required in a Maildir
                    # mailbox, and some majik below
                    # finds any such quoted "> From"s and
                    # gets rid of the "> " quote.
                    #
                    # Each email is put in a file
                    # in the cur/ subdirectory with a
                    # name of the form:
                    #
                    #    nnnnnnnnn.cccc.mbox:2,XXXX
                    #
                    # where:
                    #    "nnnnnnnnn" is the Unix time since
                    #       1970 when this script started
                    #       running, incremented by 1 for
                    #       every email.  This is to ensure
                    #       unique names for each message
                    #       file.
                    #
                    #    ".cccc" is the message count of
                    #       messages from this mbox.
                    #
                    #    ".mbox" is just to indicate that
                    #       this message was converted from
                    #       an Mbox mailbox.
                    #
                    #    ":2," is the start of potentially
                    #       multiple IMAP flag characters
                    #       "XXXX", but may be followed by
                    #       nothing.
                    #
                    # This is sort-of  compliant with
                    # the Maildir naming conventions
                    # specified at:
                    #
                    # http://www.qmail.org/man/man5/maildir.html
                    #
                    # This approach does not involve the
                    # process ID or the hostname, but it is
                    # probably good enough.
                    #
                    # When the IMAP server looks at this
                    # mailbox, it will move the files to
                    # the cur/ directory and change their
                    # names as it pleases.  In the case
                    # of Courier IMAP, the names will
                    # become like:
                    #
                    #   995096541.25351.mbox:2,S
                    #
                    # with 25351 being Courier IMAP's
                    # process ID.  The :2, is the start
                    # of the flags, and the "S" means
                    # that this one has been seen by
                    # the user.  (But is this the same
                    # meaning as the user actually
                    # having opened the message to see
                    # its contents, rather than just the
                    # IMAP server having been asked to
                    # list the message's Subject etc.
                    # so the client could list it in the
                    # visible Inbox?)
                    #
                    # This contrasts with a message
                    # created by Courier IMAP, say with
                    # a message copy, which is like:
                    #
                    #   995096541.25351.zair,S=14285:2,S
                    #
                    # where ",S=14285" is the size of the
                    # message in bytes.
                    #
                    # Courier Maildrop's names are similar
                    # but lack the ":2,XXXX" flags . . .
                    # except for my modified Maildrop
                    # which can deliver them with a
                    # ":2,T" - flagged for deletion.
                    #
                    # I have extended the logic of the
                    # per-message inner loop to stop
                    # saving a file for a message with:
                    #
                    # Subject: DON'T DELETE THIS MESSAGE -- FOLDER INTERNAL DATA
                    #
                    # This is the dummy message, always
                    # at the start of an Mbox format
                    # mailbox file - and is put there
                    # by UW IMAPD.  Since quite a few
                    # people will use this for
                    # converting from a UW system,
                    # I figure it is worth it.
                    #
                    # I will not save any such message
                    # file for the dummy message.
                    #
                    # Plan
                    # ----
                    #
                    # We want to read the entire Mbox file, whilst
                    # going through a loop for each message we find.
                    #
                    # We want to read all the headers of the message,
                    # starting with the "From " line.   For that "From "
                    # line we want to get a date.
                    #
                    # For all other header lines, we want to store them
                    # in $headers whilst parsing them to find:
                    #
                    #   1 - Any flags in the "Status: " or "X-Status: " or
                    #       "X-Mozilla-Status: " lines.
                    #
                    #   2 - A subject line indicating this is the dummy message
                    #       at the start (typically, but not necessarily) of
                    #       the Mbox.
                    #
                    # Once we reach the end of the headers, we will crunch any
                    # flags we found to create a file name.  Then, unless this is
                    # the dummy message we create that file and write all the
                    # headers to it.
                    #
                    # Then we continue reading the Mbox, converting ">From " to
                    # "From " and writing it to the file, until we reach one of:
                    #
                    #   1 - Another "From " line (indicating the start of another
                    #       message).
                    #
                    # or
                    #
                    #   2 - The end of the Mbox.
                    #
                    # In the former case, which we detect at the start of the loop
                    # we need to close the file and touch it to alter its date-time.
                    #
                    # In the later case, we also need to close the file and touch
                    # it to alter its date-time - but this is beyond the end of the
                    # loop.


                    # Variables
                    # ---------

        my $messagecount = 0;

                    # For generating unique filenames for
                    # each message.  Initialise it here with
                    # numeric time in seconds since 1970.
        my $unique = time;

                    # Name of message file to delete if we found that
                    # it was created by reading the Mbox dummy message.

        my $deletedummy = '';

                    # To store the complete "From (address) (date-time)
                    # which delineates the start of each message
                    # in the Mbox
        my $fromline = '';


                    # Set to 1 when we are reading the header lines,
                    # including the "From " line.
                    #
                    # 0 means we are reading the message body and looking
                    # for another "From " line.

        my $inheaders = 0;

                    # Variable to hold all headers (apart from
                    # the first line "From ...." which is not
                    # part of the message itself.
        my $headers = '';

                    # Variable to hold the accumulated characters
                    # we find in header lines of the type:
                    #
                    #    Status:
                    #    X-Status:
                    #    X-Mozilla-Status:
                    #    X-Evolution:
        my $flags = '';

                    # To build the file name for the message in.
        my $messagefn = '';


                    # The date string from the "From " line of each
                    # message will be written here - and used by
                    # touch to alter the date-time of each message
                    # file.  Put non-date text here to make it
                    # spit the dummy if my code fails to find a
                    # date to write into this.

        my $receivedate = 'Bogus';

	# The subject of the message
	my $subject = '';

	my $previous_line_was_empty = 1;

                    # We record the message start line here, for error
                    # reporting.
        my $startline;

                    # If defined, we use this as the number of bytes in the
                    # message body rather than looking for a /^From / line.
        my $contentlength;

			    # A From lines can either occur as the first
			    # line of a file, or after an empty line.
			    # Most mail systems will quote all From lines
		            # appearing in the message, but some will only
			    # do it when necessary.
			    # Since we initialise the variable to true,
			    # we don't need to check for beginning of file.

	            # The path to the UID list file
	my $uidlistfile;
	if ($create_dovecot_uidlist)
	{
		$uidlistfile = "${maildir}/dovecot-uidlist";
	} else {
		$uidlistfile = "${maildir}/courierimapuiddb";
	}
	            # Store the UIDVALIDITY and UIDLAST from the X-IMAP:
	            # header
	my $uidvalidity;
	my $uidlast = 0;

	            # Store the UID for the current message
	my $uidcurr = 0;

	            # Array to hold all the UIDs and filenames for outputing
	            # into a uidlist file
	my @uidlist;
	my $douidlist = $create_dovecot_uidlist || $create_courier_uidlist;
	if ($douidlist && scalar(stat($uidlistfile)))
	{
		$douidlist = 0;
		printf("WARNING: Skipping UIDs for this folder. %s already exists.\n", $uidlistfile);
	}

	            # The path to the Dovecot keywords list
	my $keywordsfile = "$maildir/dovecot-keywords";
	            # Hash to hold a list of all valid keywords for the folder.
	            # We use a hash to make looking up keywords in there fast.
	my %validkeywords;
	            # A list of already encountered keys. The index of each key
	            # is used when generating message filenames and they get
	            # written to the dovecot-keywords file. We also have a
	            # hash that maps from the keyword to the array index to
	            # facilitate checking if we already have an index for the
	            # keyword
	my @keywords;
	my %keywordshash;

	            # List of keyword flags used by Dovecot. The dovecot-keyword
	            # file maintains a 0-based index of keywords in use in the
	            # folder. The message filenames use the flags a-z to mark
	            # messages as having keywords (a=0, b=1, etc). Note that
	            # this means Dovecot only supports 26 different keywords
	            # per mail folder. This array maps the numeric indexes to
	            # the letter flags (in case Dovecot begins to use other 
	            # flags in the future).
	my @keywordflags = ('a'..'z');

	            # Store the keyword header found for the current message
	my $messagekeywords;

	            # If there already exists a dovecot-keywords file then
	            # we can't deal with keywords even if the user wants us to.
	            # It's not technically impossible, just more than this code
	            # can be bothered to deal with.
	my $dokeywords = $create_dovecot_keywords;
	if ($dokeywords && scalar(stat($keywordsfile)))
	{
		$dokeywords = 0;
		printf("WARNING: Skipping keywords for this folder. %s already exists.\n", $keywordsfile);
	}

	my $postclose = sub
	{
		if ($messagefn ne '' && $messagefn ne $deletedummy)
		{
			if ($note_message_size || $note_rfc822_size)
			{
				my $params = "";
				my $realsize = -s $messagefn;

				if ($note_message_size)
				{
					$params .= ",S=$realsize";
				}

				if ($note_rfc822_size && open(MSG, "<$messagefn"))
				{
					my $lfs = 0;
					my $line;
					while ($line = <MSG>)
					{
						$lfs += ($line =~ m/(?<!\r)\n/gs);
					}
					close(MSG);
					$params .= ",W=" . ($realsize + $lfs);
				}
				my $oldfn = $messagefn;
				$messagefn =~ s/:/$params:/;
				rename($oldfn, $messagefn);
				$uidlist[-1] =~ s/:/$params:/;
			}

			my $t = str2time($receivedate);
			if (defined($t))
			{
				utime $t, $t, $messagefn;
			} else {
				printf("WARNING: Unable to parse date for msg %d of %s\n", $messagecount, $mbox);
			}
		}
	};

        while(<MBOX>)
        {
                            # exchange possible Windows EOL (CRLF) with Unix EOL (LF)
            $_ =~ s/\r\n$/\n/;

            if ( /^From /
		&& $previous_line_was_empty
		&& (!defined $contentlength) 
	       )
            {
                            # We are reading the "From " line which has an
                            # email address followed by a receive date.
                            # Turn on the $inheaders flag until we reach
                            # the end of the headers.

                $inheaders = 1;

		            # In case we don't find an X-UID: header, set
		            # the UID for the current message to 1 higher
		            # than the previous message
		$uidcurr += 1;

		            # This is a new message so we need to undefine
		            # the message keyword header before looking at
		            # the new message (which may not have one)
		undef($messagekeywords);

                            # record the message start line

                $startline = $.;

                            # If this is not the first run through the loop
                            # then this means we have already been working
                            # on a message.

                if ($messagecount > 0)
                {
                            # If so, then close that message file and then
                            # use utime to change its date-time.
                            #
                            # Note this code should be duplicated to do
                            # the same thing at the end of the while loop
                            # since we must close and touch the final message
                            # file we were writing when we hit the end of the
                            # Mbox file.

                    close (OUT);
		    &$postclose();
                }

                            # Because we opened the Mbox file without any
                            # variable, I think this means that we have its
                            # current line in Perl's default variable "$_".
                            # So all sorts of pattern matching magic works
                            # directly on it.

                            # We are currently reading the first line starting with
                            # "From " which contains the date we want.
                            #
                            # This will be of the form:
                            #
                            #     From dduck@test.org Wed Nov 24 11:05:35 1999
                            #
                            # at least with UW-IMAP.
                            #
                            # However, I did find a nasty exception to this in my
                            # tests, of the form:
                            #
                            #   "bounce-MusicNewsletter 5-rw=test.org"@announce2.mp3.com
                            #
                            # This makes it trickier to get rid of the email address,
                            # but I did find a way.  I can't rule out that there would
                            # be some address like this with an "@" in the quoted
                            # portion too.
                            #
                            # Unfortunately, testing with an old Inbox Mbox file,
                            # I also found an instance where the email address
                            # had no @ sign at all.  It was just an email
                            # account name, with no host.
                            #
                            # I could search for the day of the week.  If I skipped
                            # at least one word of non-whitespace (1 or more contiguous
                            # non-whitespace characters) then searched for a day of
                            # the week, then I should be able to avoid almost
                            # every instance of a day of the week appearing in
                            # the email address.
                            #
                            # Do I need a failsafe arrangement to provide some
                            # other date to touch if I don't get what seems like
                            # a date in my resulting string?  For now, no.
                            #
                            # I will take one approach if there is an @ in the
                            # "From " line and another (just skip the first word
                            # after "From ") if there is no @ in the line.
                            #
                            # If I knew more about Perl I would probably do it in
                            # a more elegant way.

                            # Copy the current line into $fromline.

                $fromline = $_;

                            # Now get rid of the "From ". " =~ s" means substitute.
                            # Find the word "From " at the start of the line and
                            # replace it with nothing.  The nothing is what is
                            # between the second and third slash.

                $fromline =~ s/^From // ;


                            # Likewise get rid of the email address.
                            # This first section is if we determine there is one
                            # (or more . . . ) "@" characters in the line, which
                            # would normally be the case.

                if ($fromline =~ m/@/)
                {
                            # The line has at least one "@" in it, so we assume
                            # this is in the middle of an email address.
                            #
                            # If the email address had no spaces, then we could
                            # get rid of the whole thing by searching for any number
                            # of non-whitespace characters (\S) contiguously, and
                            # then I think a space.  Subsitute nothing for this.
                            #
                            #    $fromline =~ s/(\S)+ //    ;
                            #
                            # But we need something to match any number of non-@
                            # characters, then the "@" and then all the non-whitespace
                            # characters from there (which takes us to the end of
                            # "test.org") and then the space following that.
                            #
                            # A tutorial on regular expressions is:
                            #
                            #    http://www.perldoc.com/perl5.6.1/pod/perlretut.html
                            #
                            # Get rid of all non-@ characters up to the first "@":

                    $fromline =~ s/[^@]+//;


                            # Get rid of the "@".

                    $fromline =~ s/@//;
                }
                            # If there was an "@" in the line, then we have now
                            # removed the first one (lets hope there aren't more!)
                            # and everything which preceded it.
                            #
			    # we now remove either something like
			    # '(foo bar)'. eg. '(no mail address)',
			    # or everything after the '@' up to the trailing
			    # timezone
			    #
			    # FIXME: all those regexp should be combined to just one single one

		# If the first character is a quote, remove everything up to
		#  the next quote.
		if ($fromline =~ m/^\s*"/)
		{
			$fromline =~ s/"[^"]*"//;
		} else {
			$fromline =~ s/(\((\S*| )+\)|\S+) *//;
		}

		chomp $fromline;

                            # Stash the date-time for later use.  We will use it
                            # to touch the file after we have closed it.

                $receivedate = $fromline;
		
                            # Debugging lines:
                            #
                            # print "$receivedate is the receivedate of message $messagecount.\n";
                            # $receivedate = "Wed Nov 24 11:05:35 1999";
                            #
                            # To look at the exact date-time of files:
                            #
                            #   ls -lFa --full-time
                            #
                            # End of handling the "From " line.
            }


                            # Now process header lines which are not the "From " line.

            if (    ($inheaders eq 1)
                 && (! /^From /)
               )
            {
                            # Now we are reading the header lines after the "From " line.
                            # Keep looking for the blank line which indicates the end of the
                            # headers.


                            # ".=" means append the current line to the $headers
                            # variable.
                            #
                            # For some reason, I was getting two blank lines
                            # at the end of the headers, rather than one,
                            # so I decided not to read in the blank line
                            # which terminates the headers.
                            #
                            # Delete the "unless ($_ eq "\n")" to get rid
                            # of this kludge.
	                    #
	                    # Don't copy status headers, etc. if we've used
	                    # the info in them already for something.

                $headers .= $_ unless ( ($_ eq "\n") ||
					(/^Status: /) ||
					(/^X-Status: /) ||
					(/^X-Mozilla-Status: /i) ||
					(/^X\-Evolution:\s+/oi) ||
					(/^X-IMAP(?:base)?: /) ||
					(/^X-UID: /) ||
					(/^X-Keywords:\s+/));

		if (/^X-IMAP(?:base)?: (\d+)\s+(\d+)\s*([^\s].*)?\s*$/)
		{
			if (defined($uidvalidity))
			{
				printf("WARNING: Second X-IMAP: header found. Ignoring it (line %d, msg %d).\n", $., $messagecount);
			} else {
				$uidvalidity = $1;
				$uidlast = $2;
			}

			            # Valid keywords for the mailbox are stored
			            # in the X-IMAP: or X-IMAPbase: header. Any
			            # keywords in messages that are not in this
			            # list should be ignored
			if (defined($3))
			{
				foreach my $keyword (split(/\s+/, $3))
				{
					$validkeywords{$keyword} = 1;
				}
			}
		}

		if (/^X-UID: (\d+)/)
		{
			# UIDs must increase; we must have a UID at least 1
			# greater than the previous message
			if ($1 < $uidcurr)
			{
				printf("WARNING: UID from X-UID: header too low. Ignoring it (line %d, msg %d).\n", $., $messagecount);
			} else {
				$uidcurr = $1;
			}
		}

		if (/^X-Keywords:\s+(.*)\s*$/)
		{
			# Grab the keywords for use when we generate the
			# message filename below
			$messagekeywords = $1;
		}

                            # Now scan the line for various status flags
                            # and to fine the Subject line.

                $flags  .= $1 if /^Status: ([A-Z]+)/;
                $flags  .= $1 if /^X-Status: ([A-Z]+)/;
                if (/^X-Mozilla-Status: ([0-9a-f]{4})/i)
                {
                  $flags .= 'R' if (hex($1) & 0x0001);
                  $flags .= 'A' if (hex($1) & 0x0002);
                  $flags .= 'D' if (hex($1) & 0x0008);
                }
                if(/^X\-Evolution:\s+\w{8}\-(\w{4})/oi)
                {
                    $b = pack("H4", $1); #pack it as 4 digit hex (0x0000)
                    $b = unpack("B32", $b); #unpack into bit string

                    # "usually" only the right most six bits are used
                    # however, I have come across a seventh bit in
                    # about 15 (out of 10,000) messages with this bit
                    # activated.
                    # I have not found any documentation in the source.
                    # If you find out what it does, please let me know.

                    # Notes:
                    #   Evolution 1.4 does mark forwarded messages.
                    #   The sixth bit is to denote an attachment

                    $flags .= 'A' if($b =~ /[01]{15}1/); #replied
                    $flags .= 'D' if($b =~ /[01]{14}1[01]{1}/); #deleted
                    $flags .= 'T' if($b =~ /[01]{13}1[01]{2}/); #draft
                    $flags .= 'F' if($b =~ /[01]{12}1[01]{3}/); #flagged
                    $flags .= 'R' if($b =~ /[01]{11}1[01]{4}/); #seen/read
                }
                $subject = $1 if /^Subject: (.*)$/;
		if ($use_cl eq 1)
		{
                	$contentlength = $1 if /^Content-Length: (\d+)$/;
		}

                            # Now look out for the end of the headers - a blank
                            # line.  When we find it, create the file name and
                            # analyse the Subject line.

                if ($_ eq "\n")
                {
                            # We are at the end of the headers.  Set the
                            # $inheaders flag back to 0.

                    $inheaders = 0;

                            # Include the current newline in the content length

                    ++$contentlength if defined $contentlength;

                            # Create the file name for the current message.
                            #
                            # A simple version of this would be:
                            #
                            #   $messagefn = "cur/$unique.$messagecount.mbox:2,";
                            #
                            # This would create names with $messagecount values of
                            # 1, 2, etc.  But for neatness when looking at a
                            # directory of such messages, sorted by filename,
                            # I want to have leading zeroes on message count, so
                            # that they would be 000001 etc.  This makes them
                            # appear in message order rather than 1 being after
                            # 19 etc.  So this is good for up to 999,999 messages
                            # in a mailbox.  It is a cosmetic matter for a person
                            # looking into the Maildir directory manually.
                            # To do this, use sprintf instead with "%06d" for
                            # 6 characters of zero-padding:

            		$messagefn = sprintf ("cur/%d.%06d.mbox:2,", $unique, $messagecount) ;

			    # If the message has not been flagged as Opened
			    # then it should be put in the new/ folder. This
			    # Works with Exim/UW-IMAP folders but is otherwise
			    # untested.
			$messagefn =~ s/^cur/new/ unless $flags =~ /O/;

                            # Append flag characters to the end of the
                            # filename, according to flag characters
                            # collected from the message headers

                    $messagefn .= 'F' if $flags =~ /F/; # Flagged.
                    $messagefn .= 'R' if $flags =~ /A/; # Replied to.
                    $messagefn .= 'S' if $flags =~ /R/; # Seen or Read.
                    $messagefn .= 'T' if $flags =~ /D/; # Tagged for deletion.

		            # If the user has asked us to generate Dovecot-
		            # compatible keyword listings, let's give it a go
		    if ($dokeywords &&
			defined($messagekeywords) &&
			scalar(keys(%validkeywords)))
		    {
			foreach my $keyword (split(/\s+/, $messagekeywords))
			{
			    # Only keywords listed in the X-IMAP(base): header
			    # are valid for this folder
			    next unless $validkeywords{$keyword};

			    # Check if we've already used this keyword and
			    # assigned it an index. Try to assign one if not
			    unless (defined($keywordshash{$keyword}))
			    {
				unless (scalar(@keywords) < scalar(@keywordflags))
				{
				    printf("WARNING: Too many keywords (%d max). Ignoring keyword '%s' for message %d\n", scalar(@keywordflags), $keyword, $messagecount);
				    next;
				}

				# Add the keyword to the array
				push(@keywords, $keyword);
				# Update the keyword to index hash
				$keywordshash{$keyword} = scalar(@keywords)-1;
			    }

			    $messagefn .= $keywordflags[$keywordshash{$keyword}];
			}
		    }


                            # Opens filename $messagefn for output (>) with filehandle OUT.

                    open(OUT, ">$messagefn") or die("Fatal: unable to create new message $messagefn");

                            # Count the messages.

                    $messagecount++;

		            # If the current UID is higher than UIDLAST, we
		            # need to update UIDLAST
		    $uidlast = $uidcurr if ($uidcurr > $uidlast);

                            # Only for the first message,
                            # check to see if it is a dummy.
                            # Delete the message file we
                            # just created if it was for the
                            # dummy message at the start
                            # of the Mbox.
                            #
                            # Add search terms as required.
                            # The last 2 lines are for rent.
                            #
                            # "m" means match the regular expression,
                            # but we can do without it.
                            #
                            # Do I need to escape the ' in "DON'T"?
                            # I didn't in the original version.

                    if (   (($messagecount == 1) && defined($subject))
                        && ($subject =~ m/^DON'T DELETE THIS MESSAGE -- FOLDER INTERNAL DATA/)
                       )
                    {
                            # Stash the file name of the dummy message so we
                            # can delete it later.

                        $deletedummy = "$messagefn";

		            # If there was a dummy message, we still want
		            # the next message to be able to use UID 1
		        $uidcurr = $uidlast = 0;
                    } else {
		            # If this is not a dummy message then store
		            # the UID and message filename for outputing
		            # into the uidlist file at the end (dropping
		            # "cur/" from the beginning)
		        push(@uidlist, "$uidcurr ". substr($messagefn, 4));
		    }

                            # Print the collected headers to the message file.

                    print OUT "$headers";


                            # Clear $headers and $flags ready for the next message.

                    $headers = '';
                    $flags = '';

                            # End of processing the headers once we found the
                            # blank line which terminated them
                }

                            # End of dealing with the headers.
            }


            if ( $inheaders eq 0)
            {

                            # We are now processing the message body.
                            #
                            # Now we have passed the headers to the
                            # output file, we scan until the while
                            # loop finds another "From " line.

                            # Decrement our content length if we're
                            # using it to find the end of the message
                            # body

                if (defined $contentlength) {

                            # Decrement our $contentlength variable

                    $contentlength -= length($_);

                            # The proper end for a message with Content-Length
                            # specified is the $contentlength variable should
                            # be exactly -1 and we should be on a bare
                            # newline.  Note that the bare newline is not
                            # printed to the end of the current message as
                            # it's actually a message separator in the mbox
                            # format rather than part of the message.  The
                            # next line _should_ be a From_ line, but just in
                            # case the Content-Length header is incorrect
                            # (e.g. a corrupt mailbox), we just continue
                            # putting lines into the current message until we
                            # see the next From_ line.

                    if ($contentlength < 0) {
                        if ($contentlength == -1 && $_ eq "\n") {
                            $contentlength = undef;
                            next;
			}
                        $contentlength = undef;
                    }
                }

                            #
                            # We want to copy every part of the message
                            # body to the output file, except for the
                            # quoted ">From " lines, which was the
                            # way the IMAP server encoded body lines
                            # starting with "From ".
                            #
                            # Pattern matching Perl majik to
                            # get rid of an Mbox quoted From.
                            #
                            # This works on the default variable "$_" which
                            # contains the text from the Mbox mailbox - I
                            # guess this is the case because of our
                            # (open(MBOX ....) line above, which did not
                            # assign this to anything else, so it would go
                            # to the default variable.  This enables
                            # inscrutably terse Perlisms to follow.
                            #
                            # "s" means "Subsitute" and it looks for any
                            # occurrence of ">From" starting at the start
                            # of the line.  When it finds this, it replaces
                            # it with "From".
                            #
                            # So this finds all instances in the Mbox message
                            # where the original line started with the word
                            # "From" but was converted to ">From" in order to
                            # not be mistaken for the "From ..." line which
                            # is used to demark each message in the Mbox.
                            # This was was a destructive conversion because
                            # any message which originally had ">From" at the
                            # start of the line, before being put into the
                            # Mbox, will now have that line without the ">".

                s/^>From /From /;

                            # Glorious tersness here.  Thanks Simon for
                            # explaining this.
                            #
                            # "print OUT" means print the default variable to
                            # the file of file handle OUT.  This is where
                            # the bulk of the message text is written to
                            # the output file.

                print OUT or die("Fatal: unable to write to new message to $messagefn");


                            # End of the if statement dealing with message body.
            }

	    $previous_line_was_empty = ( $_ eq "\n" );

                            # End of while (MBOX) loop.
        }
                            # Close the input file.

        close(MBOX);

                            # Close the output file, and duplicate the code
                            # from the start of the while loop which touches
                            # the date-time of the most recent message file.

        close(OUT);
	&$postclose();

                            # After all the messages have been
                            # converted, check to see if the
                            # first one was a dummy.
                            # if so, delete it and make
                            # the message count one less.

        if ($deletedummy ne "")
        {
            printf("Dummy mail system first message detected and not saved.\n");
            unlink $deletedummy;

            $messagecount--;

        }

	            # If the user asked for a Dovecot keywords file and
	            # we found any keywords in this folder then write
	            # the file out.
	if ($dokeywords && scalar(@keywords))
	{

		    # $dokeywords should be false if the file already exists
		    # but we open it in O_EXCL mode to be sure.
		    # NOTE: NO LOCKING IS PERFORMED so beware running this
		    # on an active Maildir folder
		if (sysopen(KEYWORDS, $keywordsfile, O_WRONLY|O_CREAT|O_EXCL, 0600))
		{
			for (my $i = 0;$i < scalar(@keywords);$i++)
			{
				printf(KEYWORDS "%d %s\n", $i, $keywords[$i]);
			}
			close(KEYWORDS);
			printf("Created keywords list: %s\n", $keywordsfile);
		}
	}

	            # If the user asked for a uidlist file
	            # and we found an X-IMAP: or X-IMAPbase: header, then
	            # let's generate the file.
	if ($douidlist && defined($uidvalidity))
	{
		if ($create_courier_uidlist)
		{
			    # Courier IMAP only wants the basename of the
			    # maildir file (up to the colon) so let's strip
			    # the endings off.
			grep(s/:.*$//,@uidlist);
		}

		            # If there's already a uid list file, we don't
			    # know how to deal with the old UIDVALIDITY or
			    # whether the UIDs from the incoming messages
		            # are valid or unique. So we use O_EXCL and just
		            # bail out if the file exists and let the mail
		            # system update the index with new UIDs for
		            # these messages
		            # NOTE: NO LOCKING IS DONE SO DON'T RUN THIS ON
		            # AN ACTIVE MAILDIR
		if (sysopen(UIDLIST, $uidlistfile, O_WRONLY|O_CREAT|O_EXCL, 0600))
		{
			    # The first 1 is the file format version number
			    # The second number is the UIDVALIDITY value
			    # The last number is the next number to be given
			    #  to a new message (one higher than UIDLAST)
			printf(UIDLIST "1 %d %d\n", $uidvalidity, $uidlast+1);
			print(UIDLIST join("\n", @uidlist));
			print(UIDLIST "\n") if (scalar(@uidlist) > 0);
			close(UIDLIST);
			printf("Created UID list: %s\n", $uidlistfile);
		} else {
			printf("WARNING: Unable to create %s. Does it already exist?\n", $uidlistfile);
		}
	}

        printf("$messagecount messages.\n\n");
}
