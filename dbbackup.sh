#!/bin/bash

###############################################
#Author: Brian Hoglan                         #
#Email: bhoglan@gmail.com                     #
#Creaated Date: 2020/12/24                    #
#Version: 1.0                                 #
###############################################


###############################################
#This is a script to backup the Bitwarden DB. #
#First it creates a tarball of the db         #
#directory then gzips it. Then it has GPG     #
#encrypt the resulting file .                 #
###############################################

#Set variables
data_directory="/root/bwdata"
date=$(date +"%y%m%d-%H%M")
tar_filename="/root/bwbackup/bwdata-$date.tar.gz"

#Tar and GZip the db directory
tar -czf $tar_filename $data_directory

#Use GPG to encrypt the file using the passphrase listed in the pw file
# --batch Use batch mode. Never ask, do not allow interactive commands.
# --yes Assume "yes" on most questions.
# --passphrase-fd 0 - Read the passphrase from file descriptor n. If you use 0 for n, 
# the passphrase will be read from stdin. 
cat /root/bwpasswd | gpg --batch --yes --passphrase-fd 0 --symmetric $tar_filename

#Clean up our dirty work
rm $tar_filename

#Ship the file off to the Google drive
rclone copy $tar_filename.gpg "GDrive:/"

#Clean up the cloned file
rm $tar_filename.gpg

#Write a log message of the success
logger "$date BW DB backed up to Google Drive successfully!"
