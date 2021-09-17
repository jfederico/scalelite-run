#!/bin/bash

source ./.env
SCALELITE_RECORDING_DIR=${SCALELITE_RECORDING_DIR-/mnt/scalelite-recordings/var/bigbluebutton}

echo 'Add dependencies...'
apt-get install -y rsync

echo 'Add the bigbluebutton user...'
id -u bigbluebutton &>/dev/null || useradd -m -d /home/bigbluebutton -s /bin/bash bigbluebutton
if [ ! -d "/home/bigbluebutton/.ssh" ]; then
  su - bigbluebutton -s /bin/bash -c 'mkdir ~/.ssh && touch ~/.ssh/authorized_keys'
fi

echo 'Create a new group with GID 2000...'
if grep -q scalelite-spool /etc/group; then
  echo "group scalelite-spool exists"
else
  echo "group scalelite-spool created"
  groupadd -g 2000 scalelite-spool
fi

echo 'Add the bigbluebutton user to the group...'
usermod -a -G scalelite-spool bigbluebutton

echo 'Create the directory structure for recording ...'
mkdir -p $SCALELITE_RECORDING_DIR/spool
mkdir -p $SCALELITE_RECORDING_DIR/recording/scalelite
mkdir -p $SCALELITE_RECORDING_DIR/published
mkdir -p $SCALELITE_RECORDING_DIR/unpublished
chown -R 1000:2000 $SCALELITE_RECORDING_DIR
chmod -R 0775 $SCALELITE_RECORDING_DIR

echo 'Create symbolic link to the directory structure for uploading ...'
if [ -d "/var/bigbluebutton" ]; then
  mv /var/bigbluebutton /var/.bigbluebutton
elif [ -e "/var/bigbluebutton" ]; then
  rm /var/bigbluebutton
fi
ln -s $SCALELITE_RECORDING_DIR /var/bigbluebutton
