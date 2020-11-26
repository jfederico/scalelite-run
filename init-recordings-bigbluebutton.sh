#!/bin/bash

if [[ ! -f ./.env ]]; then
  echo ".env file does not exist on your filesystem."
  exit 1
fi

URL_HOST=$(grep URL_HOST .env | cut -d '=' -f2)
echo $URL_HOST

echo 'Create a new group with GID 2000...'
groupadd -g 2000 scalelite-spool
echo 'Add the bigbluebutton user to the group...'
usermod -a -G scalelite-spool bigbluebutton

echo 'Add recording transfer scripts...'
cd /usr/local/bigbluebutton/core/scripts/post_publish
wget -O post_publish_scalelite.rb https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_post_publish.rb

echo 'Add recording transfer settings...'
cd /usr/local/bigbluebutton/core/scripts
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite.yml
echo "spool_dir: bigbluebutton@$URL_HOST:/var/bigbluebutton/spool" | tee -a /usr/local/bigbluebutton/core/scripts

echo 'Generate ssh key pair...'
mkdir /home/bigbluebutton
chown bigbluebutton.bigbluebutton /home/bigbluebutton/
su - bigbluebutton -s /bin/bash -c "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_rsa"

echo 'Add this key to /home/bigbluebutton/.ssh/authorized_keys in scalelite:'
cat /home/bigbluebutton/.ssh/scalelite.pub

echo 'done'
