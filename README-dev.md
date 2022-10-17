# Installation (short version)

On an Ubuntu 22.04 as the host machine.

## Prerequisites

This machine needs to be updated and have installed:

- Git
- [Docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04)
- [Docker Compose](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-22-04)
- Certbot

## Fetching the scripts

```
git clone https://github.com/jfederico/scalelite-run
cd scalelite-run
```

## Initializing environment variables

Create a new `.env` file based on the `dotenv` file included.

```
cp dotenv .env
```

Most required variables are preset by default, the ones that must be set before starting are:

```
SECRET_KEY_BASE=
LOADBALANCER_SECRET=
URL_HOST=
```

Obtain the value for SECRET_KEY_BASE and LOADBALANCER_SECRET with:

```
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" .env
sed -i "s/LOADBALANCER_SECRET=.*/LOADBALANCER_SECRET=$(openssl rand -hex 24)/" .env
```

Set the hostname on URL_HOST (E.g. sl.example.com)

```
sed -i "s/URL_HOST=.*/URL_HOST=sl.example.com" .env
```

## Generate LetsEncrypt SSL certificates manually

```
source ./.env
certbot certonly --manual -d sl.$DOMAIN_NAME --agree-tos --no-bootstrap --manual-public-ip-logging-ok --preferred-challenges=dns --email <YOUR_ENMAIL> --server https://acme-v02.api.letsencrypt.org/director
certbot certonly --manual -d redis.$DOMAIN_NAME --agree-tos --no-bootstrap --manual-public-ip-logging-ok --preferred-challenges=dns --email <YOUR_ENMAIL> --server https://acme-v02.api.letsencrypt.org/director
```

## Starting the app

Start the services.

```
docker-compose up -d
```

The database must be initialized.

```
docker exec -i scalelite-api bundle exec rake db:setup
```

The BBB servers must be added.

```
docker exec -i scalelite-api bundle exec rake servers:add[https://bbb25.example.com/bigbluebutton/api,secret]
docker exec -i scalelite-api bundle exec rake servers:enable[bbb25.example.com]
```

## Setup recordings

### Configuring the BBB server

Init the bbb server as explained in the documentation

Edit the `/home/bigbluebutton/.ssh/config` file

1. make sure the configured domain points to your local machine as this user needs to ssh to it

2. replace the default bigbluebutton with your own username (as you don't want to add bigbluebutton username to your local machine)

Host scalelite-spool
  HostName sl.jesus.blindside-dev.com
  User <YOUR_USERNAME>
  Port 22
  IdentityFile /home/bigbluebutton/.ssh/id_rsa

3. In your local machine, add the public key generated for the bigbluebutton user in the bbb machine into your own `~/.ssh/authorized_keys` file.

4. ssh into your own computer using the config env_file
ssh scalelite-spool

5. Edit the variable that indicates where the files will be placed

Edit `/usr/local/bigbluebutton/core/scripts/scalelite.yml`

```
# spool_dir: scalelite-spool:/var/bigbluebutton/spool 	## original
spool_dir: scalelite-spool:/home/<YOUR_USERNAME>/spool		## adapted
```

Accept the key, this is done only once.

### Final touches in your Local Machine

1. Make sure your user has rights to write in the `/mnt/scalelite-recordings/var/bigbluebutton/spool/`

sudo chown -R root.<YOUR_USERNAME> /mnt/scalelite-recordings/var/bigbluebutton/spool/

2. Create a symbolic link to that spool directory

ln -s /mnt/scalelite-recordings/var/bigbluebutton/spool/ /home/YOUR_USERNAME/spool
