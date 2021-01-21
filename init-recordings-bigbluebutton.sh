#!/bin/bash -ex

usage() {
    set +x
    cat 1>&2 <<HERE
Script for integrating BigBlueButton Recordings with Scaleite.
USAGE:
    wget -qO- https://raw.githubusercontent.com/jfederico/scalelite-run/master/init-recordings-bigbluebutton.sh | bash -s -- [OPTIONS]
OPTIONS
  -s <scalelite-hostname>          Configure server with <scalelite-hostname> (required)
EXAMPLES:
Sample options for setup a BigBlueButton server
    -s scalelite.example.com
HERE
exit 0
}

main() {
  export DEBIAN_FRONTEND=noninteractive
  while builtin getopts "s:" opt "${@}"; do

    case $opt in
      s)
        HOST=$OPTARG
        if [ "$HOST" == "scalelite.example.com" ]; then
          err "You must specify a valid hostname (not the hostname given in the docs)."
        fi
        ;;
    esac

  done

  if [ ! -z "$HOST" ]; then
    check_host $HOST
  else
    usage
  fi
}

check_host() {
  if [ ! -z "$HOST" ]; then
    need_pkg dnsutils apt-transport-https net-tools
    DIG_IP=$(dig +short $1 | grep '^[.0-9]*$' | tail -n1)
    if [ -z "$DIG_IP" ]; then err "Unable to resolve $1 to an IP address using DNS lookup.";  fi
  fi
}

err() {
  echo "$1" >&2
  exit 1
}

need_pkg() {
  check_root

  if [ ! "$SOURCES_FETCHED" = true ]; then
    apt-get update
    SOURCES_FETCHED=true
  fi

  if ! dpkg -s ${@:1} >/dev/null 2>&1; then
    LC_CTYPE=C.UTF-8 apt-get install -yq ${@:1}
  fi
}

main "$@" || exit 1


# We can proceed with the setup
if grep -q scalelite-spool /etc/group
then
  echo "Group <scalelite-spool> exists"
else
  echo "Group <scalelite-spool> does not exist. Create it with GID 2000..."
  groupadd -g 2000 scalelite-spool
fi

if grep -q bigbluebutton /etc/passwd
then
  echo "User <bigbluebutton> exists"
else
  echo 'User <bigbluebutton> does not exist. Add the bigbluebutton user using group <scalelite-spool>...'
  useradd -m -d /home/bigbluebutton -s /bin/bash bigbluebutton
fi
usermod -a -G scalelite-spool bigbluebutton

if [ -z "/home/bigbluebutton" ]
then
  echo "Home Directory for <bigbluebutton> was found"
else
  echo "Home Directory for <bigbluebutton> was not found"
  mkdir /home/bigbluebutton
  chown bigbluebutton.bigbluebutton /home/bigbluebutton/
fi

echo 'Generate ssh key pair...'
su - bigbluebutton -s /bin/bash -c "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_rsa"

echo 'Add recording transfer scripts...'
cd /usr/local/bigbluebutton/core/scripts/post_publish
rm scalelite_post_publish.rb
wget -O post_publish_scalelite.rb https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_post_publish.rb

echo 'Add recording transfer settings...'
cd /usr/local/bigbluebutton/core/scripts
rm scalelite.yml
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite.yml
echo "spool_dir: bigbluebutton@$HOST:/var/bigbluebutton/spool" | tee -a /usr/local/bigbluebutton/core/scripts/scalelite.yml

public_key=$(cat /home/bigbluebutton/.ssh/id_rsa.pub)
set +x
echo "**********************************************************************"
echo "Add this key to /home/bigbluebutton/.ssh/authorized_keys in scalelite:"
echo "**********************************************************************"
echo
echo "$public_key"
echo
echo "**********************************************************************"
exit 0
