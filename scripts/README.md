# Helpers

## Running automatic updates

```
sudo ln -s /home/ubuntu/scalelite-run/scripts/deploy.sh /usr/local/bin/scalelite-deploy
sudo cp /home/ubuntu/scalelite-run/scripts/scalelite-auto-deployer.service /etc/systemd/system/scalelite-auto-deployer.service
sudo cp /home/ubuntu/scalelite-run/scripts/scalelite-auto-deployer.timer /etc/systemd/system/scalelite-auto-deployer.timer
sudo systemctl daemon-reload
sudo systemctl enable scalelite-auto-deployer.service
sudo systemctl enable scalelite-auto-deployer.timer
sudo systemctl start scalelite-auto-deployer.timer
```
