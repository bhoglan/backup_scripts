#!/bin/bash

###############################################
#Author: Brian Hoglan                         #
#Email: bhoglan@gmail.com                     #
#Created Date: 2020/12/24                     #
#Updated: 2022/11/2                           #
#Version: 1.3                                 #
###############################################
# v 1.0 - Initial script creation.
# v 1.1 - Updated file paths after migrating install to a new server.
# v 1.2 - Updated tar and gpg options. Added recovery steps.
#               - Changed tar compression from gzip to bzip2, default level (compressed file size went from ~74M to 52M). Also expanded the options to their long forms.
#               - Changed gpg cipher from aes128 to aes256.
#               - Added the filename to the end of the logger message.
#               - Added a local log bwbackup/archive.log for easy filename reference
#               - Changed gpg passphrase. 20 words now.
# v 1.3 - Updated script to use new Wasabi backup solution. Includes rclone command, log commands, and comments.
# v 1.4 - Updated script to use rclone's move argument rather than copy. Copy seems to be making incremental backups instead of full backups currently. This should perform a full file copy instead.

###############################################
#This is a script to backup the Bitwarden DB. #
#First it creates a tarball of the db         #
#directory then gzips it. Then it has GPG     #
#encrypt the resulting file .                 #
###############################################

#Set variables
data_directory="/opt/bitwarden/bwdata"
date=$(date +"%y%m%d-%H%M")
tar_filename="/opt/bitwarden/bwbackup/bwdata-$date.tar.bz2"

#Tar and GZip the db directory
tar --create --bzip2 --file $tar_filename $data_directory

#Use GPG to encrypt the file using the passphrase listed in the pw file
# --batch Use batch mode. Never ask, do not allow interactive commands.
# --yes Assume "yes" on most questions.
# --passphrase-fd 0 - Read the passphrase from file descriptor n. If you use 0 for n,
# the passphrase will be read from stdin.
cat /opt/bitwarden/bwpasswd | gpg --batch --yes --cipher-algo aes256 --passphrase-fd 0 --symmetric $tar_filename

#Ship the file off to the Google drive
rclone --log-file=/var/log/rclone -v move $tar_filename.gpg "wasabi-bwbackup:/bitwardenbackup/"

#Clean up the tarball and the cloned file
rm $tar_filename

#Write a log message of the success
logger "$date BW DB backed up to Wasabi successfully! $tar_filename.gpg"
#Write a handy message to the archive log for easy reference
echo "$date BW DB backed up to Wasabi successfully! $tar_filename.gpg" >> /opt/bitwarden/bwbackup/archive.log

##############################################################################################
#               Recovery steps                                                               #
# Before doing this, try to restore from a nightly backup:                                   #
# https://bitwarden.com/help/backup-on-premise/                                              #
# 1. Pull file from Wasabi. RClone can be used.                                              #
#   A. Retrieve last archive filename from /opt/bitwarden/bwbackup/archive.log               #
#   B. View files in remote repo: rclone lsl wasabi-bwbackup:bitwardenbackup/                #
#   C. rclone copy wasabi-bwbackup:bitwardenbackup/tar_filename /opt/bitwarden/bwbackup/     #
# 2. Decrypt the archive.                                                                    #
#   A. gpg --output tar_filename --decrypt tar_filename.gpg                                  #
#   B. Password is stored in Bitwarden in Bitwarden1 RClone Information under gpg passphrase.#
# 3. Decompress the archive.                                                                 #
#   A. tar -xvf tar_filename                                                                 #
# 4. Stop Bitwarden containers.                                                              #
#   A. /opt/bitwarden/bitwarden.sh stop                                                      #
# 5. Replace bwdata/ directory with the one we just downloaded.                              #
# 6. Run bitwarden.sh updatedb                                                               #
##############################################################################################
