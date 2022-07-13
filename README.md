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

Obtain the value for SECRET_KEY_BASE and LOADBALANCER_SECRET with:

```
sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" .env
sed -i "s/LOADBALANCER_SECRET=.*/LOADBALANCER_SECRET=$(openssl rand -hex 24)/" .env
```

Set the hostname on URL_HOST (E.g. scalelite.example.com)

When using a SSL certificate set NGINX_SSL to true

Your final .env file should look like this:

```
SECRET_KEY_BASE=a7441a3548b9890a8f12b385854743f3101fd7fac9353f689fc4fa4f2df6cdcd1f58bdf6a02ca0d35a611b9063151d70986bad8123a73244abb2a11763847a45
LOADBALANCER_SECRET=c2d3a8e27844d56060436f3129acd945d7531fe77e661716
URL_HOST=scalelite.example.com
NGINX_SSL=true
```

For using a SSL certificate signed by Let’s Encrypt, generate the certificates.

```
./init-letsencrypt.sh
```

Start the services.

```
docker-compose up -d
```

Now, the scalelite server is running, but it is not quite yet ready. The database must be initialized.

```
docker exec -i scalelite-api bundle exec rake db:setup
```
