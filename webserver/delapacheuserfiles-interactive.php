<?php
############################################################################
# delapacheuserfiles.php
#
# Author: Claudio Kuenzler
# Company: Nova Company GmbH www.novahosting.ch
# Purpose: Deletes files and folders created by Apache user
# Comments and Contact: www.claudiokuenzler.com
#
# Version History
# 20100116 Script programmed
# 20100118 Bugfix for current dir (could not be deleted)
# now set to chmod777 so ftp user can delete
# 20110107 The user decides what should be deleted
# 20110107 Variable for apache user name (different names on systems)
############################################################################
// Set your Apache-User
$apacheuser = "www-data";

// Get Variables
$deldir = $_GET['deldir'];
$delfile = $_GET['delfile'];
$deleted = $_GET['deleted'];

// Delete user approved files to delete
if (isset($deleted) || isset($delfile) || isset($deldir)) {

if (isset($delfile)) {
unlink($delfile);
$type="file";
header("Location: delapacheuserfiles.php?deleted=$delfile");
}

elseif (isset($deldir)) {
rmdir($deldir);
$type="dir";
header("Location: delapacheuserfiles.php?deleted=$deldir");
}

if (isset($deleted)) {
if($type=="file") {
if (is_file($deleted)) {
echo "There was a problem. File $deleted was <u>not</u> deleted."; }
else {echo "File $deleted has been deleted. <a href=\"delapacheuserfiles.php\">back to list</a>"; }
}
else {
if (is_dir($deleted)) {
echo "There was a problem. $deleted was <u>not</u> deleted. Maybe folder is not empty?"; }
else {echo "Folder $deleted has been deleted. <a href=\"delapacheuserfiles.php\">back to list</a>"; }
}
}

}

else {
// Show Files and Folders
header("Cache-Control: no-cache");

// Files
exec("find . -type f -user $apacheuser", $fileresult);

echo "<b>The following files were found:</b><br>";
foreach ($fileresult as $found) {
echo "$found - <a href=\"delapacheuserfiles.php?delfile=$found\">Delete?</a><br>";
}

// Folders
exec("find . -type d -user $apacheuser", $folderresult);

if ($folderresult[0] == ".") {
chmod("$folderresult[0]", 0777);
unset($folderresult[0]); // This removes the current directory from the list
}

echo "<br><br><b>The following folders were found::</b><br>";
foreach ($folderresult as $folder) {
echo "$folder - <a href=\"delapacheuserfiles.php?deldir=$folder\">Delete?</a><br>";
}

}

echo "<p>&copy; 2010-2011 Claudio Kuenzler @ Nova Hosting <a href=\"http://www.novahosting.ch\">www.novahosting.ch</a></p>";
?> 
