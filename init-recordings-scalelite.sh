#!/bin/bash

echo 'Add the bigbluebutton user...'
useradd -m -d /home/bigbluebutton -s /bin/bash bigbluebutton
su - bigbluebutton -s /bin/bash -c 'mkdir ~/.ssh && touch ~/.ssh/authorized_keys'

echo 'Create a new group with GID 2000...'
groupadd -g 2000 scalelite-spool

echo 'Add the bigbluebutton user to the group...'
usermod -a -G scalelite-spool bigbluebutton

echo 'Create the directory structure for storing recording ...'
mkdir -p /var/bigbluebutton/spool
mkdir -p /var/bigbluebutton/recording/scalelite
mkdir -p /var/bigbluebutton/published
mkdir -p /var/bigbluebutton/unpublished
chown -R 1000:2000 /var/bigbluebutton/
chmod -R 0775 /var/bigbluebutton/

echo 'Create the mouniting point directory for recording transfer from BigBlueButton...'
mkdir -p /mnt/scalelite-recordings/var
chown -R 1000:2000 /mnt/scalelite-recordings/
chmod -R 0775 /mnt/scalelite-recordings/
ln -s /var/bigbluebutton /mnt/scalelite-recordings/var/bigbluebutton
