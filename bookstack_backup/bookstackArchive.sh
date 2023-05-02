#!/bin/bash

###############################################
#Author: Brian Hoglan                         #
#Email: bhoglan@gmail.com                     #
#Created Date: 2022/12/09                     #
#Updated:                                     #
#Version: 1.0                                 #
###############################################
# v 1.0 - Initial script creation.

###############################################
# This script will backup the Bookstack app   #
# user files and environment config. Tasks to #
# complete:                                   #
# 1. Exec mariadb dump in the bookstack_db    #
# container to a shared location.             #
# 2. Gather and tar up some directories in the#
# Bookstack app container and place them in a #
# shared location.                            #
# 3. Tar and GZ the archive files we just made#
# 4. Encrypt the gz file with GPG.            #
# 5. Use rclone to ship the encrypted archive #
# to Wasabi.                                  #
# 6. Clean up temp files.                     #
###############################################

# Set some variables
date=$(date +"%y%m%d-%H%M")
bookstackDir="/home/bhoglan/docker/appdata/bookstack/"
dbDir="/home/bhoglan/docker/appdata/mariadb/"
bookstackArchive=${date}"bookstackArchive.tar"
bookstackDB=${date}"bookstackDB.sql"
backupGZ=${date}"bookstackGZ.tar.gz"
#bookstack_db_container=$(/usr/bin/docker ps | grep bookstack_db | awk '{print $1}')
#bookstack_app_container=$(/usr/bin/docker ps | grep lscr.io/linuxserver/bookstack | awk '{print $1}')
bookstack_db_container=$(/usr/bin/docker ps --format "{{.ID}}" --filter "name=bookstack_db")
bookstack_app_container=$(/usr/bin/docker ps --format "{{.ID}}" --filter "ancestor=lscr.io/linuxserver/bookstack")
appRoot="/app/www/"
dockerDir="/home/bhoglan/docker/"

#Declare some functions
function dbdump()
{
    # docker exec "${bookstack_db_container}" mysqldump --defaults-file=/root/.secrets/bookstackCreds.cnf --all-databases > /archive/"${bookstackDB}"
    docker exec "${bookstack_db_container}" /bin/sh /archive/dbbackup.sh
}

function archive()
{
    docker exec "${bookstack_app_container}" tar --create --file /archive/"${bookstackArchive}" ${appRoot}"public/" ${appRoot}".env" ${appRoot}"storage/"
}

# Dump the mariadb to a shared directory
dbdump
archive

# Let the script take a nap in case it takes some time to generate the files
sleep 30

# Tar and GZ the collected files
tar --create --bzip2 --file "${dockerDir}""shared/archive/""${backupGZ}" "${bookstackDir}""archive/""${bookstackArchive}" "${dbDir}""archive/""${bookstackDB}"

# Encrypt the archive
gpg --batch --yes --cipher-algo aes256 --passphrase-fd 0 --symmetric "${dockerDir}"shared/archive/"${backupGZ}" < /root/.secrets/bookstackArchive

# Ship it out to Wasabi
rclone --config="/root/.config/rclone/rclone.conf" --log-file=${dockerDir}"shared/archive/rclone.log" -v copy "${dockerDir}""shared/archive/""${backupGZ}"".gpg" "Wasabi:/bookstackbackup"

#Write a log entry
echo -e "\xE2\x9C\x85" ${date} "\\\ Bookstack DB backed up successfully!" "${backupGZ}"".gpg" "\xE2\x9C\x85" >> "${dockerDir}""/shared/archive/bookstackArchive.log"

# Clean up
rm "${dockerDir}""shared/archive/""${backupGZ}"
rm "${dockerDir}""shared/archive/""${backupGZ}"".gpg"
rm "${bookstackDir}""archive/""${bookstackArchive}"
rm "${dbDir}""archive/""${bookstackDB}"
