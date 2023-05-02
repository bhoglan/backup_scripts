#!/bin/bash

###############################################
#Author: Brian Hoglan                         #
#Email: bhoglan@gmail.com                     #
#Created Date: 2023/05/01                     #
#Updated:                                     #
#Version: 1.0                                 #
###############################################
# v 1.0 - Initial script creation.

###############################################
# This script will backup the Sonarr DB file. #
# Tasks to complete:                          #
# 1. Copy Sonarr backup to temp directory.    #
# 2. Encrypt the gz file with GPG.            #
# 3. Use rclone to ship the encrypted archive #
# to Wasabi.                                  #
###############################################

# Makes sure the script fails with a non-zero status if a command fails rather than executing the next.
set -e

# Set some variables
date=$(date +"%y%m%d-%H%M")
sonarrDir="/home/bhoglan/docker/appdata/sonarr/config/Backups/scheduled/"
filename=$(ls -t $sonarrDir | head -n1)
dockerDir="/home/bhoglan/docker/"
archiveDir="/home/bhoglan/docker/shared/archive"

# Copy the backup to the temp dir
cp "${sonarrDir}"/"${filename}" "${archiveDir}"

# Encrypt the archive
gpg --batch --yes --cipher-algo aes256 --passphrase-fd 0 --symmetric "${archiveDir}"/"${filename}" < /root/.secrets/sonarrArchive

# Ship it out to Wasabi
rclone --config="/root/.config/rclone/arrArchive.conf" --log-file="${archiveDir}"/rclone.log -v copy "${archiveDir}"/"${filename}"".gpg" "Wasabi:/sonarrbackup"

#Write a log entry
echo -e "\xE2\x9C\x85" ${date} "\\\ Sonarr DB backed up successfully!" "${filename}"".gpg" "\xE2\x9C\x85" >> "${archiveDir}""/sonarrArchive.log"

# Clean up
rm "${archiveDir}"/"${filename}"
rm "${archiveDir}"/"${filename}"".gpg"
