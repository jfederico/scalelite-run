#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

if [[ ! -f ./.env ]]; then
  echo ".env file does not exist on your filesystem."
  exit 1
fi

usage() {
  echo -e "Initializes letsencrypt certificates for Nginx proxy container\n"
  echo -e "Usage: $0 [-z|-r|-h]\n"
  echo "  -n|--non-interactive  Enable non interactive mode"
  echo "  -r|--replace          Replace existing certificates without asking"
  echo "  -h|--help             Show usage information"
  exit 1
}

interactive=1
replaceExisting=0

while [[ $# -gt 0 ]]
do
    case "$1" in
        -n|--non-interactive) interactive=0;shift;;
        -r|--replace) replaceExisting=1;shift;;
        -h|--help) usage;;
        -*) echo "Unknown option: \"$1\"\n";usage;;
        *) echo "Script does not accept arguments\n";usage;;
    esac
done

URL_HOST=$(grep URL_HOST .env | cut -d '=' -f2)
echo $URL_HOST
NGINX_CONTAINER_NAME=$(grep DOCKER_PROXY_NGINX_TEMPLATE .env | cut -d '=' -f2)
if [[ -z "$NGINX_CONTAINER_NAME" ]]; then
  NGINX_CONTAINER_NAME=scalelite-proxy
fi

domains=($URL_HOST,redis.$URL_HOST)
rsa_key_size=4096
data_path="./data/certbot"
email="$LETSENCRYPT_EMAIL" # Adding a valid address is strongly recommended
staging=${LETSENCRYPT_STAGING:-0} # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  if [ "$replaceExisting" -eq 0 ] && [ "$interactive" -eq 1 ]; then
    read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
    if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
      exit
    fi
  elif [ "$interactive" -eq 0 ]; then
    echo "Certificates already exist."
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:1024 -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Starting $NGINX_CONTAINER_NAME ..."
docker-compose up --force-recreate -d $NGINX_CONTAINER_NAME
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $([ "$interactive" -ne 1 ] && echo '--non-interactive') \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --debug-challenges \
    --force-renewal" certbot
echo

echo "### Reloading $NGINX_CONTAINER_NAME..."
docker-compose exec $([ "$interactive" -ne 1 ] && echo "-T") $NGINX_CONTAINER_NAME nginx -s reload
