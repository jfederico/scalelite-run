#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="Status: Downloaded newer image for blindsidenetwks/scalelite:latest"

new_status=$(sudo docker pull blindsidenetwks/scalelite:latest | grep Status:)

echo $new_status

if [ "$STATUS" == "$new_status" ]
then
  cd $DIR/..
  docker-compose down
  docker rmi $(docker images -f dangling=true -q)
  docker-compose up -d
fi

exit 0
