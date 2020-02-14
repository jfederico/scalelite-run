# scalelite-run

This document provides instructions on how to deploy scalelite + redis behind a nginx proxy
using docker-compose.

## Prerequisites

- Install
[docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04)
  and
[docker-compose](https://www.digitalocean.com/community/tutorials/how-to-install-docker-compose-on-ubuntu-18-04)

- Make sure you have access to Blindside Networks private repository in
  [dockerhub](https://cloud.docker.com/u/blindsidenetwks/repository/list) particularly to:

  - [scalelite](https://cloud.docker.com/u/blindsidenetwks/repository/docker/blindsidenetwks/scalelite)

- Make sure you have your own DNS and a public domain name (e.g. example.com) or a delegated one (e.g. <JOHN>.blindside-dev.com).


- As you have to have access to dockerhub private repositories sign in into docker hub with your account
with `docker login` any type your username and password using the stdin.

```
docker login
```

## Steps

These steps were written for an Ubuntu 18.04 machine. It is assumed that your machine has the same (or a compatible version).

### Getting the scripts

Clone this repository:

```
git clone git@github.com:blindsidenetworks/scalelite-run.git
cd scalelite-run
```

Copy `dotenv` file located in the root of the project as `.env` and edit it

```
cp dotenv .env
vi .env
```

You need to replace the variable `HOST_NAME=sl.xlab.blindside-dev.com` with a hostname under your own domain name (e.g. `HOST_NAME=sl.john.blindside-dev.com`) or delegated sub-domain.


Copy `dotenv` file located in the scalelite directory as `.env` and in the same way as before, edit it:

```
cp scalelite/dotenv scalelite/.env
vi scalelite/.env
```

You can start it as is, but you may want to replace both variables with your own values.

`SECRET_KEY_BASE` is the Ruby On Rails secret key and should be replaced with a random one generated with `openssl rand -hex 64`.

`LOADBALANCER_SECRET` is the shared secret used by external applications for accessing the Load Balancer as if it was a BigBlueButton server. By default, it includes the Secret used for test-install (which is also the first server added to the pool as example).


### Using SSL Letsencrypt in the cloud

If all the previous steps were followed properly and the machine is accessible in the Internet, only execute:

```
./init-letsencrypt.sh
```

This will generate the SSL certificates and run scalelite for the first time, so all the required files are automatically generated.


### Using SSL Letsencrypt certificate in private Networks

If you are trying to install scalelite locally or in a private network, the process is more manual. You need to generate the SSL certificates with certbot by adding the challenge to your DNS.

Install letsencrypt in your own computer

```
sudo apt-get update
sudo apt-get -y install letsencrypt
```

Make yourself root

```
sudo -i
```

Start creating the certificates

```
certbot certonly --manual -d sl.<JOHN>.blindside-dev.com --agree-tos --no-bootstrap --manual-public-ip-logging-ok --preferred-challenges=dns --email hostmaster@blindsdie-dev.com --server https://acme-v02.api.letsencrypt.org/directory
```

You will see something like this
```
-server https://acme-v02.api.letsencrypt.org/directory
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator manual, Installer None
Obtaining a new certificate
Performing the following challenges:
dns-01 challenge for gl.<JOHN>.blindside-dev.com
dns-01 challenge for gl.<JOHN>.blindside-dev.com

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please deploy a DNS TXT record under the name
_acme-challenge.sl.<JOHN>.blindside-dev.com with the following value:

2dxWYkcETHnimmQmCL0MCbhneRNxMEMo9yjk6P_17kE

Before continuing, verify the record is deployed.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Press Enter to Continue
```

Create a TXT record in your DNS for
`_acme-challenge.sl.<JOHN>.blindside-dev.com` with the challenge string as
its value `2dxWYkcETHnimmQmCL0MCbhneRNxMEMo9yjk6P_17kE`

Copy the certificates to your scalelite-run directory. Although `/etc/letsencrypt/live/`
holds the latest certificate, they are only symbolic links. The real files must be copied and renamed

```
cp -R /etc/letsencrypt <YOUR ROOT>/scalelite-run/data/certbot/conf
```

### Starting the application

And finally, start your environment with docker-compose

```
cd <YOUR ROOT>/scalelite-run
docker-compose up
```

If everything goes well, you will see all the containers starting and at the
end you will have access to scalelite through:

```
https://sl.<JOHN>.blindside-dev.com/bigbluebutton/api
```

Note that you can always run the application in the background `docker-compose up -d`

### Final Steps

As the only BigBlueButton Server configured by default is test-install, this comes intentionally disabled. You would have to either enable it or to add new ones. Either way this has to be done through the console.

Open a new console and get the ids of the docker containers running:

```
docker ps
```

Get into the container running the api

```
docker exec -it <CONTAINER_ID> sh
```

Once inside, you can see execute all the rails commands as needed. In this case, lets assume that you want to enable the current BigBlueButton server

```
bundle exec rake servers
bundle exec rake servers:enable["SERVER_ID_AS SHOWN"]
```

For more information on what rake commands can be executed, see scalelite documentation.

### Special cases

#### Build your own image

If you don;t have access to the DockerHub registry, you can always build your own image. Either by running `docker build` where scalelite code is placed, or using the build script provided in this repo at `scripts/build.sh`. The only advantage of using the script is that the last commit is included as the build number.

```
cd <YOUR ROOT>/scalelite
docker build -t blindsidenetwks/scalelite:latest .
```

or

```
cd <YOUR ROOT>/scalelite
../scalelite-run/scripts/build.sh blindsidenetwks/scalelite latest
```

Keep in mind that the docker-compose.yml script makes use of some other configuration files that are mounted inside the containers. If any modification to nginx is needed it has to be done on the sites.template file. Also, whatever name is chosen for the image should match the one used in docker-compose.yml.
