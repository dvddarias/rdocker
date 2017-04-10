# rDocker

Securely control a remote docker daemon CLI using ssh forwarding, no SSL setup needed.

## Install

If you want it available on your system run the following (you may need elevated privileges for this to work):

    curl -L https://github.com/dvddarias/rdocker/raw/master/rdocker.sh > /usr/local/bin/rdocker
    chmod +x /usr/local/bin/rdocker

If you just want it lying around on your file system:

    git clone https://github.com/dvddarias/rdocker.git
    cd rdocker

## Usage

Lets assume you want to control the docker daemon on your `webserver.com` server from your local machine. You just run:

    rdocker user@webserver.com

This will open a new bash session with a new DOCKER_HOST variable setup. Any `docker` command you execute will take place on the remote docker daemon.
To test the connection run:

    docker info

Check the `Name:` field it should have the remote hostname .... That's it!!!

You could for example run `docker build` to build an image on the remote host and then `docker save -o myimage.tar image_name` to store it locally.
Or run `docker exec -it container_name bash` to open a shell session on a remote container. Even bash auto-completion works ok.

You can choose the local port the docker daemon will be forwarded to by passing it as the last argument:

    rdocker user@webserver.com 9000

You can also interact with the remote daemon from any other terminal by using the -H parameter of the docker client:

    docker -H localhost:9000 images

To stop controlling the remote daemon and close the ssh forwarding, just exit the newly created bash session (press `Ctrl+D`).

## Dependencies & Configuration

**Basically None**. If you can login to your server over ssh and run docker commands this script should work out of the box.

Just remember:
- The user you log in with should have permissions access the `/var/run/docker.sock` otherwise you will get a lot of: `An error occurred trying to connect...`. To solve this [add the user to the docker group](https://docs.docker.com/engine/installation/ubuntulinux/#create-a-docker-group).
- It uses `ssh` to connect to the host so you should also have the the appropriate permissions (private-key, password, etc..).
- On the remote host it uses: python(2/3), bash, and ssh but these are already installed on most linux distributions.
- Needless to say you need `docker` installed on both computers ;).

## How does it work

This is a general overview of how it works, feel free to check the script for further details:

 1. Connects over ssh to the remote host, finds a free port on both computers, and opens ssh forwarding
 2. Runs over the ssh connection a python script that forwards connections on the remote host from `localhost:remote_port` to the unix domain socket at `/var/run/docker.sock`
 3. Starts a new bash session with DOCKER_HOST environment variable set to `tcp://localhost:local_port`
 4. On session exit it SIGTERMs the ssh connection.

Tested on Ubuntu, Mint and Debian. It should work on any linux based OS. I don't have a Mac around to test it :(.
Contributions are of course welcome.




