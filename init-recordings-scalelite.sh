#!/bin/bash

source ./.env
SCALELITE_RECORDING_DIR=${SCALELITE_RECORDING_DIR-/mnt/scalelite-recordings/var/bigbluebutton}
SCALELITE_RECORDING_DIR_ROOT=$(dirname $(dirname $SCALELITE_RECORDING_DIR))

echo 'Add the bigbluebutton user...'
useradd -m -d /home/bigbluebutton -s /bin/bash bigbluebutton
su - bigbluebutton -s /bin/bash -c 'mkdir ~/.ssh && touch ~/.ssh/authorized_keys'

echo 'Create a new group with GID 2000...'
groupadd -g 2000 scalelite-spool

echo 'Add the bigbluebutton user to the group...'
usermod -a -G scalelite-spool bigbluebutton

echo 'Create the directory structure for recording ...'
mkdir -p $SCALELITE_RECORDING_DIR_ROOT/var/bigbluebutton/spool
mkdir -p $SCALELITE_RECORDING_DIR_ROOT/var/bigbluebutton/recording/scalelite
mkdir -p $SCALELITE_RECORDING_DIR_ROOT/var/bigbluebutton/published
mkdir -p $SCALELITE_RECORDING_DIR_ROOT/var/bigbluebutton/unpublished
chown -R 1000:2000 $SCALELITE_RECORDING_DIR_ROOT/
chmod -R 0775 $SCALELITE_RECORDING_DIR_ROOT/

echo 'Create symbolic link to the directory structure for uploading ...'
ln -s $SCALELITE_RECORDING_DIR_ROOT/var/bigbluebutton /var/bigbluebutton
