# scalelite-run
A simple way to deploy Scalelite as for production using docker-compose.

## Overview
[Scalelite](https://github.com/blindsidenetworks/scalelite) is an open-source load balancer, designed specifically for [BigBlueButton](https://bigbluebutton.org/), that evenly spreads the meeting load over a pool of BigBlueButton servers. It makes the pool of BigBlueButton servers appear to a front-end application such as Moodle [2], as a single and yet very scalable BigBlueButton server.

It was released by [Blindside Networks](https://blindsidenetworks.com/) under the AGPL license on March 13, 2020, in response to the high demand of Universities looking into scaling BigBlueButton as a [result of the COVID-19 pandemic](https://campustechnology.com/articles/2020/03/03/coronavirus-pushes-online-learning-forward.aspx).

The full source code is available on GitHub and pre-built docker images can be found on [DockerHub](https://hub.docker.com/r/blindsidenetwks/scalelite).

Scaleite itself is a ruby on rails application.

For its deployment it is required some experience with bigbluebutton and scalelite itself, and all the tools and components used as part of the stack such as redis, postgres, nginx, docker and docker-compose, as well as ubuntu and AWS infrastructure.

For those new to system administration or any of the components mentioned the article [Scalelite lazy deployment
](https://jffederico.medium.com/scalelite-lazy-deployment-745a7be849f6) is a step-vy-step guide on how to complete a full installation of Scalelite on AWS using this script. Also [Scalelite lazy deployment (Part II)](https://jffederico.medium.com/scalelite-lazy-deployment-part-ii-ca3e4bf82f8d) is a step-by-step guide to complete the installation with support for recordings.


## Installation (short version)

On an Ubuntu 20.04 machine (AWS EC2 instance, LXC container, VMWare machine etc).

### Fetching the scripts

```
git clone https://github.com/jfederico/scalelite-run
cd scalelite-run
```

### Initializing environment variables
Create a new .env file based on the dotenv file included.

```
cp dotenv .env

sed -e '/SECRET_KEY_BASE=/ s/^${openssl rand -hex 64}*/#/' -i .env

sed -i 's/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=[${openssl rand -hex 64}]/' .env

```

Most required variables are pre-set by default, the ones that must be set before starting are:

```
SECRET_KEY_BASE=
LOADBALANCER_SECRET=
URL_HOST=
NGINX_SSL=
```

Also, when using the `init-letsencrypt.sh` script, you should add the email.

```
LETSENCRYPT_EMAIL=
```
