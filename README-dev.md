- Install a BBB server
- Add a BBB server

# Setup recordings

## Configuring the BBB server

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

## Final touches in your Local Machine

1. Make sure your user has rights to write in the `/mnt/scalelite-recordings/var/bigbluebutton/spool/`

sudo chown -R root.<YOUR_USERNAME> /mnt/scalelite-recordings/var/bigbluebutton/spool/

2. Create a symbolic link to that spool directory

ln -s /mnt/scalelite-recordings/var/bigbluebutton/spool/ /home/YOUR_USERNAME/spool
