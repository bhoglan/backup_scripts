#!/bin/bash
###############################################
#Author: Brian Hoglan                         #
#Email: bhoglan@gmail.com                     #
#Created Date: 2022/09/12                     #
#Updated:                                     #
#Version: 1.0                                 #
###############################################
# v 1.0 - Initial script creation.

###############################################
# This script is the second step in backing up#
# Bookstack. First two separate scripts run   #
# within the Bookstack and DB containers to   #
# tar files and dump the DB, respectively.    #
# This script runs on a cron job 5 minutes    #
# later to compress and encrypt the files     #
# before sending them to Google Drive.	      #
# Finish it off by cleaning up the files.     #
###############################################

#Reference: https://www.bookstackapp.com/docs/admin/backup-restore/

#crontab entries
#0 0 * * * /home/bhoglan/docker/shared/bookstackArchive.sh
#0 12 * * * /home/bhoglan/docker/shared/bookstackArchive.sh

# Exit when any command fails
set -e

# Keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# Echo an error message before exiting
trap 'echo -e ${date} "\xE2\x9D\x8C" "\xE2\x9D\x8C" "\"${last_command}\" command failed with exit code $?." "\xE2\x9D\x8C""\xE2\x9D\x8C" >> ${dockerDir}/shared/archive.log' EXIT

# Declare conditional logging and exit
function success()
{
	echo -e ${date} '$? ran successfully!'
}

function fail()
{
	echo -e ${date} "\xF0\x9F\x92\x80" '$? failed...' "\xF0\x9F\x92\x80"
}

# Declare exit cleanup function
function cleanup()
{
	# Let's delete some temp files
	rm ${dockerDir}${bookstack}*bookstackFiles.tar
	rm ${dockerDir}${bookstack_db}*bookstack_db.sql
	rm ${dockerDir}/shared/${archiveTar}
	rm ${dockerDir}/shared/${archiveGPG}

	# Oh yeah, just like that. Mmmkay, let's add a quick message to the log
	echo -e 'Bookstack file archive, Bookstack DB, temp bz2, and temp gpg files all deleted'
}

#Set variables
date=$(date +"%y%m%d-%H%M")
dockerDir="/home/bhoglan/docker"
bookstack="/appdata/bookstack/archive/"
bookstack_db="/appdata/mariadb/archive/"
archiveTar=${date}"-bookstackArchive.tar.bz2"
archiveGPG=${archiveTar}".gpg"

#Divider to make it a little more readable
echo -e "\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88" >> ${dockerDir}/shared/archive.log

#Tar 'em up
tar --create --bzip2 --file ${dockerDir}/shared/${archiveTar}  ${dockerDir}${bookstack}*bookstackFiles.tar ${dockerDir}${bookstack_db}*bookstack_db.sql
if [ $? -eq 0 ]; then
	success()
else
	fail()
	if [[ -e ${dockerDir}${bookstack}*bookstackFiles.tar || ${dockerDir}${bookstack_db}*bookstack_db.sql ]]
	then
		rm ${dockerDir}${bookstack}*bookstackFiles.tar
		rm ${dockerDir}${bookstack}*bookstack_db.sql
		EXIT
	fi
fi


#Write message 1
echo -e "\xE2\x9C\x85" ${date} "\\ Bookstack files tarred and bzipped successfully!" ${archiveTar} "\xE2\x9C\x85" >> ${dockerDir}/shared/archive.log

#GPG - Encryption time!
cat /home/bhoglan/.secrets/bookstackArchive.ini | gpg --batch --yes --cipher-algo aes256 --passphrase-fd 0 --symmetric $archiveTar
if [ $? -eq 0 ]; then
        success()
else
        fail()
        if [[ -e ${dockerDir}/shared/${archiveTar} || ${dockerDir}/shared/${archiveGPG} ]]
        then
                rm ${dockerDir}/shared/${archiveTar}
		rm ${dockerDir}/shared/${archiveGPG}
		EXIT
        fi
fi

#Write message 2
echo -e "\xE2\x9C\x85" ${date} "\\ Bookstack files encrypted successfully!" ${archiveGPG} "\xE2\x9C\x85" >> ${dockerDir}/shared/archive.log

#Ship it on off to Google Drive
rclone --config="/home/bhoglan/.config/rclone/rclone.conf" --log-file=${dockerDir}/shared/archive.log -v copy ${dockerDir}/shared/${archiveGPG} "Google Drive:/Bookstack_Backup"
if [ $? -eq 0 ]; then
        success()
else
        fail()
        if [[ -e ${dockerDir}/shared/${archiveGPG} ]]
        then
                rm ${dockerDir}/shared/${archiveGPG}
		EXIT
        fi
fi

#Write a nice little log note
echo -e "\xE2\x9C\x85" ${date} "\\ Bookstack files sent to Google Drive successfully!" ${archiveGPG} "\xE2\x9C\x85" >> ${dockerDir}/shared/archive.log

#Divider to make it a little more readable
echo -e "\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88""\xF0\x9F\x90\x88" >> ${dockerDir}/shared/archive.log

#Run the cleanup() function to tidy up the temp files
if [ $? -eq 0 ]; then
	cleanup()
else
	echo -e "Dude, something's wrong but I don't know what"
