#!/bin/bash

STATUS="Status: Downloaded newer image for blindsidenetwks/scalelite:master"

new_status=$(sudo docker pull blindsidenetwks/scalelite:master | grep Status:)

echo $new_status

if [ "$STATUS" == "$new_status" ]
then
  cd /home/ubuntu/scalelite-run
  sudo docker-compose down
  sudo docker rmi $(sudo docker images -f dangling=true -q)
  sudo docker-compose up -d
fi

exit 0
