# scalelite-run

This document provides instructions on how to deploy scalelite behind a nginx proxy
using docker-compose.

This can be performed as an [All-In-One-Box Deployment](#all-in-one-box-deployment) or making use of distributed services in the cloud (or virtual private cloud) through a cloud computing provider as a [Distributed Deployment](#distributed-deployment).

<a name="prerequisites"/>

## Prerequisites

- Install
[docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04)
  and
[docker-compose](https://www.digitalocean.com/community/tutorials/how-to-install-docker-compose-on-ubuntu-18-04)

- Make sure you have access to Blindside Networks repositories in
  [dockerhub](https://cloud.docker.com/u/blindsidenetwks/repository/list) (particularly to [scalelite](https://cloud.docker.com/u/blindsidenetwks/repository/docker/blindsidenetwks/scalelite)).

- Make sure you have your own public domain name (e.g. blindside-dev.com) or a delegated one (e.g. <JOHN>.blindside-dev.com) and have access to manage it through a DNS.

<a name="preparation"/>

## Preparation

These steps were written for an Ubuntu 18.04 machine. It is assumed that your machine has the same (or a compatible version).

<a name="accessing-dockerhub"/>

### 1. Accessing DockerHub

If you have to have access to dockerhub private repositories sign in into docker hub with your account
with `docker login` any type your username and password using the stdin.

```
docker login
```

<a name="getting-the-scripts"/>

### 2. Getting the scripts

Clone this repository:

```
git clone git@github.com:blindsidenetworks/scalelite-run.git
cd scalelite-run
```

<a name="all-in-one-box-deployment"/>

## I. All-In-One-Box Deployment

<a name="initial-settings"/>

### 1. Initial settings

Copy `dotenv` file located in the root of the project as `.env` and edit it.

```
cp dotenv .env
```

You need to replace the variable `HOST_NAME=sl.xlab.blindside-dev.com` with a hostname under your own domain name (e.g. `HOST_NAME=sl.john.blindside-dev.com`) or delegated sub-domain.

```
vi .env
```

Copy `dotenv` file located in the scalelite directory as `.env` and in the same way as before, edit it:

```
cp scalelite/dotenv scalelite/.env
```

You can start it as is, but you may want to replace both variables with your own values.

- `SECRET_KEY_BASE` is the Ruby On Rails secret key and must be replaced with a random one generated with `openssl rand -hex 64`.
- `LOADBALANCER_SECRET` is the shared secret used by external applications for accessing Scalelite LoadBalancer as if it was a BigBlueButton server. This variable must be defined in order for the application to start. A secret can be generated with `openssl rand -hex 24`

```
vi scalelite/.env
```

<a name="ssl-certificate"/>

### 2. SSL Certificate

The docker-compose scripts come configured for using SSL Certificates, but you may want not to use an SSL certificate. If this is the case see the section [Removing SSL Certificate](#removing-ssl-certificate) in [Special Cases](#special-cases).

The procedure for setting up the SSL Certificate will be different depending if [Let's Encrypt SSL CA](#letsencrypt-ssl-ca) CA or [Other SSL CA](#other-ssl-ca) will be used.

<a name="letsencrypt-ssl-ca"/>

#### 2.1. Using Let's Encrypt SSL CA

There are also two paths that can be followed whether the box where Scalelite is going to be installed is [visible from the Internet](#letsencrypt-ssl-public-network) or [NOT visible from the Internet](#letsencrypt-ssl-private-network).

<a name="letsencrypt-ssl-public-network"/>

##### 2.1.1. Server is visible from the Internet

If all the previous steps were properly followed and the machine is accessible in the Internet, only execute:

```
./init-letsencrypt.sh
```

This will generate the SSL certificates and run scalelite for the first time, so all the required files are automatically generated.

<a name="letsencrypt-ssl-private-network"/>

##### 2.1.2. Server is NOT visible from the Internet

If you are trying to install scalelite locally or in a private network, the SSL certificate must be generated manually using certbot and by adding the manual challenge to the DNS.

Install Let's Encrypt

```
sudo apt-get update
sudo apt-get -y install letsencrypt
```

Become root

```
sudo -i
```

Start creating the certificates

```
certbot certonly --manual -d sl.<JOHN>.blindside-dev.com --agree-tos --no-bootstrap --manual-public-ip-logging-ok --preferred-challenges=dns --email hostmaster@blindsdie-dev.com --server https://acme-v02.api.letsencrypt.org/directory
```

The output should look like this example

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

Create a TXT record in the DNS for
`_acme-challenge.sl.<JOHN>.blindside-dev.com` with the challenge string as
its value `2dxWYkcETHnimmQmCL0MCbhneRNxMEMo9yjk6P_17kE`

Copy the certificates to the scalelite-run directory. Although `/etc/letsencrypt/live/`
holds the latest certificate, they are only symbolic links. The real files must be copied and renamed

```
cp -R /etc/letsencrypt <YOUR ROOT>/scalelite-run/data/certbot/conf
```

<a name="other-ssl-ca"/>

#### 2.2. Using Other SSL CA

For adding an SSL certificate from an CA other than Let's Encrypt,

DO NOT execute the `./init-letsencrypt.sh` script

Place the SSL Certificate, Intermediate Certificate (or Bundle with both of them if you have it) and Private Key files inside `nginx/ssl` as `fullchain.pem` and `privkey.pem`.
E.g.
```
cd ~/
cat your_domain_name.crt Intermediate.crt >> bundle.crt
cp bundle.crt <YOUR ROOT>/scalelite/nginx/ssl/fullchain.pem
cp private.key <YOUR ROOT>/scalelite/nginx/ssl/privkey.pem
```

Edit the template for nginx.
```
cd <YOUR ROOT>/scalelite
vi nginx/sites.template
```
Comment the lines referencing the Let's Encrypt Certificate and uncomment the other two. After that, it should look like this:

```
...
    ## Configuration for Letsencrypt SSL Certificate
    #ssl_certificate /etc/letsencrypt/live/$NGINX_HOSTNAME/fullchain.pem;
    #ssl_certificate_key /etc/letsencrypt/live/$NGINX_HOSTNAME/privkey.pem;

    ## Configuration for SSL Certificate from a CA other than Letsencrypt
    ssl_certificate /etc/ssl/fullchain.pem;
    ssl_certificate_key /etc/ssl/privkey.pem;
...
```

Comment out in `docker-compose.yml` the certbot container. After that, it should look like this:

```
...
## Configuration for Letsencrypt SSL Certificate
## comment out when using an SSL Certificate from a CA other than Letsencrypt
#  certbot:
#    image: certbot/certbot
#    volumes:
#      - ./data/certbot/conf:/etc/letsencrypt
#      - ./data/certbot/www:/var/www/certbot
#    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
...
```

Start the containers as usual.

<a name="start-up"/>

### 3. Start Up

And finally, start the application with docker-compose

```
cd <YOUR ROOT>/scalelite-run
docker-compose up
```

If everything goes well, the logs will show ip in the console for all the containers starting and scalelite will be available at:

```
https://sl.<JOHN>.blindside-dev.com/bigbluebutton/api
```

Note that the application can be run in the background with `docker-compose up -d`

<a name="final-steps"/>

### 4. Final Steps

<a name="initializing-pool"/>

#### 4.1. Initializing pool of servers
Since there are no servers added by default, atleast 1 server must be added and enabled in order to get started. 

Open a new console and get the IDs of the docker containers running:

```
docker ps
```

Get into the container running the api

```
docker exec -it <CONTAINER_ID> sh
```

Once inside, all the rails commands can be executed as needed. In this case, and assuming that the current current BigBlueButton server is going to be enabled.

```
bundle exec rake servers:add[BIGBLUEBUTTON_SERVER_URL,BIGBLUEBUTTON_SERVER_SECRET]
bundle exec rake servers
bundle exec rake servers:enable["SERVER_ID_AS SHOWN"]
```

For more information on what rake commands can be executed, see [scalelite documentation](https://github.com/blindsidenetworks/scalelite).

<a name="rolling-out-updates"/>

#### 4.2. Rolling-out updates

Scalelite is constantly updated. Either because of bug fixes or improvements. It is recommended to keep the deployment updated with the latest image available, which corresponds to the latest stable release.

Those updates can be performed manually (recommended for a production alike environment) or automatically.

<a name="rolling-out-updates-manual"/>

##### 4.2.1. Manual updates

Simply run the `deploy.sh` script included under `scripts`.

```
cd <YOUR ROOT>/scalelite-run
sudo .scripts/deploy.sh
```

<a name="rolling-out-updates-automatic"/>

##### 4.2.2. Automatic updates and auto-start

Use the scripts provided.

```
sudo ln -s /home/ubuntu/scalelite-run/scripts/deploy.sh /usr/local/bin/scalelite-deploy
sudo cp /home/ubuntu/scalelite-run/scripts/scalelite-auto-deployer.service /etc/systemd/system/scalelite-auto-deployer.service
sudo cp /home/ubuntu/scalelite-run/scripts/scalelite-auto-deployer.timer /etc/systemd/system/scalelite-auto-deployer.timer
sudo systemctl daemon-reload
sudo systemctl enable scalelite-auto-deployer.service
sudo systemctl enable scalelite-auto-deployer.timer
sudo systemctl start scalelite-auto-deployer.timer
```

<a name="distributed-deployment"/>

## II. Distributed Deployment

On a real production environment Scalelite should be deployed using distributed services in the cloud (or virtual private cloud) through a cloud computing provider like [AWS](https://aws.amazon.com/), [Google Cloud](https://cloud.google.com/), [Azure](https://azure.microsoft.com/en-ca/), [Digital Ocean](https://www.digitalocean.com/), [Alibaba Cloud](https://www.alibabacloud.com/), etc.

Contact us at [Blindside Networks Contact](https://blindsidenetworks.com/contact/) getting recommendations on best practices with any of those cloud providers.

<a name="special-cases"/>

## III. Special cases

<a name="building-docker-image"/>

### Building Docker image

If no access to the DockerHub registry is available, it is still possible to build the image. Either by running `docker build` where scalelite code is placed, or using the build script provided in this repo at `scripts/build.sh`. The only advantage of using the script is that the last commit is included as the build number.

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

<a name="removing-ssl-certificate"/>

### Removing SSL Certificate

DO NOT execute the `./init-letsencrypt.sh` script

Edit the template for nginx.
```
cd <YOUR ROOT>/scalelite
vi nginx/sites.template
```
Comment out all the lines from 13 to 34. The sites.template file should look like this:

```
...
listen [::]:80;

#    location /.well-known/acme-challenge/ {
#        root /var/www/certbot;
#    }
#
#    location / {
#        return 301 https://$host$request_uri;
#    }
#}
#
#server {
#    server_name $NGINX_HOSTNAME;
#
#    listen 443 ssl;
#    listen [::]:443;
#
#    ## Configuration for Letsencrypt SSL Certificate
#    ssl_certificate /etc/letsencrypt/live/$NGINX_HOSTNAME/fullchain.pem;
#    ssl_certificate_key /etc/letsencrypt/live/$NGINX_HOSTNAME/privkey.pem;
#
#    ## Configuration for SSL Certificate from a CA other than Letsencrypt
#    #ssl_certificate /etc/ssl/fullchain.pem;
#    #ssl_certificate_key /etc/ssl/privkey.pem;

     location / {
...
```

Comment out in `docker-compose.yml` the certbot container. After that, it should look like this:

```
...
## Configuration for Letsencrypt SSL Certificate
## comment out when using an SSL Certificate from a CA other than Letsencrypt
#  certbot:
#    image: certbot/certbot
#    volumes:
#      - ./data/certbot/conf:/etc/letsencrypt
#      - ./data/certbot/www:/var/www/certbot
#    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
...
```

Start the containers as usual.
