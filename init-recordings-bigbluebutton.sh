#!/bin/bash -ex

usage() {
    set +x
    cat 1>&2 <<HERE
Script for integrating BigBlueButton Recordings with Scaleite.
USAGE:
    wget -qO- https://raw.githubusercontent.com/jfederico/scalelite-run/master/init-recordings-bigbluebutton.sh | bash -s -- [OPTIONS]
OPTIONS
  -h <scalelite-hostname>          Configure server with <scalelite-hostname> (required)
  -u <scalelite-username>          Scalelite username <scalelite-username> (optional)
  -p <scalelite-ssh-port>          SSH port in Scalelite server <scalelite-ssh-port> (optional)
  -r <scalelite-id_rsa>            File wiht id_rsa private key to be used to ssh into Scalelite server <scalelite-id_rsa> (optional)
EXAMPLES:
Sample options for setup a BigBlueButton server
    -s scalelite.example.com
    -s scalelite.example.com -u bigbluebutton
    -s scalelite.example.com -u bigbluebutton -p 2222
    -s scalelite.example.com -u bigbluebutton -p 2222 -r id_rsa-example
HERE
exit 0
}

main() {
  export DEBIAN_FRONTEND=noninteractive
  while builtin getopts "s:u:p" opt "${@}"; do

    case $opt in
      s)
        HOST=$OPTARG
        if [ "$HOST" == "scalelite.example.com" ]; then
          err "You must specify a valid hostname (not the hostname given in the docs)."
        fi
        ;;
      u)
        USER=$OPTARG
        ;;
      p)
        PORT=$OPTARG
        ;;
      r)
        ID_RSA=$OPTARG
        ;;

    esac

  done

  if [ ! -z "$HOST" ]; then
    check_host $HOST
  else
    usage
  fi
}

check_root() {
  if [ $EUID != 0 ]; then err "You must run this command as root."; fi
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

if [ -d "/home/bigbluebutton" ]
then
  echo "Home Directory for <bigbluebutton> was found"
else
  echo "Home Directory for <bigbluebutton> was not found"
  mkdir /home/bigbluebutton
  chown bigbluebutton.bigbluebutton /home/bigbluebutton/
fi

echo 'Generate ssh key pair if does not exist...'
su - bigbluebutton -s /bin/bash -c "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_rsa <<<n >/dev/null 2>&1" || true

echo 'Generate ssh config...'
if [ -f "/home/bigbluebutton/.ssh/config" ]; then
  echo "file /home/bigbluebutton/.ssh/config exists"
  rm /home/bigbluebutton/.ssh/config
fi
echo "Host scalelite-spool" | sudo tee -a /home/bigbluebutton/.ssh/config
echo "  HostName $HOST" | sudo tee -a /home/bigbluebutton/.ssh/config
echo "  User ${USER:-bigbluebutton}" | sudo tee -a /home/bigbluebutton/.ssh/config
echo "  Port ${PORT:-22}" | sudo tee -a /home/bigbluebutton/.ssh/config
echo "  IdentityFile /home/bigbluebutton/.ssh/${ID_RSA:-id_rsa}" | sudo tee -a /home/bigbluebutton/.ssh/config
chown bigbluebutton.bigbluebutton /home/bigbluebutton/.ssh/config

echo 'Add recording transfer scripts...'
POST_PUBLISH_DIR=/usr/local/bigbluebutton/core/scripts/post_publish
if [ -f "$POST_PUBLISH_DIR/scalelite_post_publish.rb" ]; then
   echo "file $POST_PUBLISH_DIR/scalelite_post_publish.rb exists"
   rm $POST_PUBLISH_DIR/scalelite_post_publish.rb
fi
wget -O $POST_PUBLISH_DIR/post_publish_scalelite.rb https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_post_publish.rb

echo 'Add recording transfer settings...'
CORE_SCRIPTS_DIR=/usr/local/bigbluebutton/core/scripts
if [ -f "$CORE_SCRIPTS_DIR/scalelite.yml" ]; then
   echo "file $CORE_SCRIPTS_DIR/scalelite.yml exists"
   rm $CORE_SCRIPTS_DIR/scalelite.yml
fi
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite.yml -P $CORE_SCRIPTS_DIR
sed -e '/spool_dir/ s/^#*/#/' -i $CORE_SCRIPTS_DIR/scalelite.yml
sed -e '/extra_rsync_opts/ s/^#*/#/' -i $CORE_SCRIPTS_DIR/scalelite.yml
echo 'spool_dir: scalelite-spool:/var/bigbluebutton/spool' | tee -a $CORE_SCRIPTS_DIR/scalelite.yml
echo 'extra_rsync_opts: ["-av", "--no-owner", "--chmod=F664"]' | tee -a $CORE_SCRIPTS_DIR/scalelite.yml

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
