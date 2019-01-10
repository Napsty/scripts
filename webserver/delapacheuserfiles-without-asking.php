<?php

########################################################
# delapacheuserfiles.php
#
# Author: Claudio Kuenzler
# Company: Nova Company GmbH www.novacompany.ch
# Purpose: Deletes files and folders created by Apache user
#
# Version History
# 20100116 Script programmed
# 20100118 Bugfix for current dir (could not be deleted)
# now set to chmod777 so ftp user can delete
########################################################

// Files
exec("find . -type f -user www-data", $fileresult);
echo "Die folgenden Dateien wurden gefunden:<br>";
foreach ($fileresult as $found) {
echo "<br> $found";
}

foreach ($fileresult as $file) {
unlink("$file");
}

// Folders
exec("find . -type d -user www-data", $folderresult);

if ($folderresult[0] == ".") {
chmod("$folderresult[0]", 0777);
unset($folderresult[0]); // This removes the current directory from the list
}

echo "<br>Die folgenden Ordner wurden gefunden:<br>";
foreach ($folderresult as $folder) {
echo "<br> $folder";
}

foreach ($folderresult as $folder) {
chmod("$folder", 0777);
rmdir("$folder");
}

?>
