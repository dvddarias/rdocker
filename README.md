# rDocker

Securely control a remote docker daemon using ssh forwarding, no SSL setup needed.

##Install

If you want it available on your system run the following (you may need elevated privileges for this to work):

    curl -L https://github.com/dvddarias/rdocker/raw/master/rdocker.sh > /usr/local/bin/rdocker
    chmod +x /usr/local/bin/rdocker

If you just want it lying around on your file system:

    git clone https://github.com/dvddarias/rdocker.git
    cd rdocker

##Usage

Lets assume you want to control the docker daemon on your `webserver.com` server from your local machine. You just run:

    rdocker user@webserver.com

This will open a new bash session with a new DOCKER_HOST variable setup. Any `docker` command you execute will take place on the remote docker daemon.
To test the connection run:

    docker info

Check the `Name:` field it should have the remote hostname .... That's it!!!

You could for example run `docker build` to build an image on the remote host and then `docker save -o myimage.tar image_name` to store it locally.
Or maybe run `docker exec -it container_name bash` to open a shell session on a remote container. Even bash auto-completion works ok.

To stop controlling the remote daemon and close the ssh forwarding, just exit the bash session (press `Ctrl+D`).

##Dependencies & Configuration

**Basically None**. If you can login to your server over ssh this script should work out of the box.

Just remember:
- The user you log in with should have permissions access the `/var/run/docker.sock`.
- It uses `ssh` to connect to the host so you should also have the the appropriate permissions.
- There are **no dependencies on the remote host** other than: python, bash, and ssh that are already installed on most linux distributions.

##How does it work

This is a general overview of how it works, feel free to check the script for further details:

 1. Connects over ssh to the remote host, finds a free port on both computers, and opens ssh forwarding
 2. Runs over the ssh connection a python script that forwards connections on the remote host from `localhost:remote_port` to the unix domain socket at `/var/run/docker.sock`
 3. Starts a new bash session with DOCKER_HOST environment variable set to `tcp://localhost:local_port`
 4. On session exit it SIGTERMs the ssh connection.

Tested on Ubuntu, Mint and Debian. It should work on any linux based OS. I don't have a Mac around to test it :(.
Contributions are of course welcome.




