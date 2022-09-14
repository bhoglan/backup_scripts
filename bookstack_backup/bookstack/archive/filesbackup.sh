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
#This is a script to backup the Bookstack app #
#user files and environment config. It pulls  #
#files from the container into a tarball, then#
#$DOCKERDIR/shared/bookstackbackup.sh pulls   #
#together this tarball and the db dump from   #
#the bookstack_db container and ships them off#
#to Google Drive after encryption.            #
# 1. Pull together the files and directories  #
# from inside the container into a tarball.   #
# 2. Put the tarball in the archive directory.#
###############################################

#crontab entries
#0 0 * * * /archive/filesbackup.sh
#0 12 * * * /archive/filesbackup.sh

#Set variables
date=$(date +"%y%m%d-%H%M")
appRoot="/app/www/"
filesTar=${date}"bookstackFiles.tar"

#Tar 'em up
tar -cf /archive/${filesTar} ${appRoot}public/ ${appRoot}.env ${appRoot}storage/

#Write a nice little log note
echo -e "\xE2\x9C\x85" ${date} "\\ Bookstack files backed up successfully!" ${filesTar} "\xE2\x9C\x85" >> /archive/archive.log
