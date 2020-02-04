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

- Make sure you have your own DNS and a public domain name or a delegated one under blindside-dev.com
  (e.g. <JOHN>.blindside-dev.com)


## Preliminary steps


## Steps

Clone this repository:

```
git clone git@github.com:blindsidenetworks/scalelite-run.git
cd scalelite-run
```

Copy  `dotenv` file located in the root of the project as `.env` and edit it

```
vi .env
```

You will need to replace both variables as in:
`DOMAIN_ROOT=bigbluebutton.org` to the one assigned to you (e.g. `DOMAIN_ROOT=blindside-dev.com`)
`DOMAIN_SUB=lab` to the one assigned to you (e.g. `DOMAIN_SUB=<JOHN>`)

Create your own SSL Letsencrypt certificates. As you are normally going to
have this deployment running on your own computer (or in a private VM), you
need to generate the SSL certificates with certbot by adding the challenge to
your DNS.

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
cp -R /etc/letsencrypt/archive/sl.<JOHN>.blindside-dev.com <YOUR ROOT>/scalelite-run/nginx/letsencrypt/live
```

```
cd <YOUR ROOT>/scalelite-run/nginx/letsencrypt/live/sl.<JOHN>.blindside-dev.com/
mv cert1.pem cert.pem
mv chain1.pem chain.pem
mv fullchain1.pem fullchain.pem
mv privkey1.pem privkey.pem
```

As you have to have access to dockerhub private repositories sign in into docker hub with your account
with `docker login -u <YOUR_USERNAME> -p <YOUR_PASSWORD>` or `docker login -u <YOUR_USERNAME>` if you
want to type your password using the stdin

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
