#!/bin/bash

echo 'Add the bigbluebutton user...'
useradd -m -d /home/bigbluebutton -s /bin/bash bigbluebutton
su - bigbluebutton -s /bin/bash -c 'mkdir ~/.ssh && touch ~/.ssh/authorized_keys'

echo 'Create a new group with GID 2000...'
groupadd -g 2000 scalelite-spool

echo 'Add the bigbluebutton user to the group...'
usermod -a -G scalelite-spool bigbluebutton

echo 'Create the spool directory for recording transfer from BigBlueButton...'
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/spool
chown 1000:2000 /mnt/scalelite-recordings/var/bigbluebutton/spool
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/spool
mkdir /var/bigbluebutton/
ln -s /mnt/scalelite-recordings/var/bigbluebutton/spool /var/bigbluebutton/spool

echo 'Create the temporary (working) directory for recording import...'
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite
chown 1000:1000 /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite

echo 'Create the directory for published recordings...'
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/published
chown 1000:1000 /mnt/scalelite-recordings/var/bigbluebutton/published
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/published

echo 'Create the directory for unpublished recordings...'
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/unpublished
chown 1000:1000 /mnt/scalelite-recordings/var/bigbluebutton/unpublished
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/unpublished

