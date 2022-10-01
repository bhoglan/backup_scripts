#!/bin/bash

# Define some variables
data_directory="/data/"
date=$(date +"%y%m%d-%H%M")
tar_filename="/root/backuptmp/truenas-$date.tar.gz"

# Tar and GZ the data directory
tar -czf $tar_filename $data_directory

# Use GPG to encrypt the file using the passphrase listed in the pw file
# --batch Use batch mode. Never ask, do not allow interactive commands.
# --yes Assume "yes" on most questions.
# --passphrase-fd 0 - Read the passphrase from file descriptor n. If you use 0 for n,
# the passphrase will be read from stdin.
cat /root/truenas_passwd | gpg --batch --yes --passphrase-fd 0 --symmetric $tar_filename

#Ship the file off to the Google drive
rclone copy $tar_filename.gpg "Google Drive:/Backup"

#Clean up the tarball and the cloned file
rm $tar_filename*

#Write a log message of the success
logger "$date TrueNAS DB backed up to Google Drive successfully!"
