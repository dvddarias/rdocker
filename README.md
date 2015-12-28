# Remote Docker

Securely control a remote docker daemon using ssh forwarding, no SSL setup needed.

##Usage

Lets assume you want to control the docker daemon on your `myamazingweb.com` server from your local machine. You would run:

    git clone https://github.com/dvddarias/rdocker.git
    cd rdocker
    ./rdocker.sh user@myamazingweb.com

This will open a new bash session with a new DOCKER_HOST variable setup. Any `docker` command you execute will take place on the remote docker daemon.
To test the connection run:

    docker info

Check the `Name:` field it should have the remote hostname. That's it!!!

You could for example run `docker build` to build an image on the remote host and then `docker save -o myimage.tar image_name` to store it locally.
Or maybe run `docker exec -it container_name bash` to open a shell session on a remote container. Even bash auto-completion works ok.

To stop controlling the remote daemon and close the ssh forwarding, just exit the bash session (press `Ctrl+D`).

##Dependencies & Configuration

The user you log in with should have permissions access the `/var/run/docker.sock`. It uses `ssh` to connect to the host so you should also have the the appropriate permissions. There are **no dependencies on the remote host** other than: python2, bash, and ssh that are already installed on most linux distributions.

##How does it work

This is a general overview of how it works, feel free to check the script for further details:

 1. Connects over ssh to the remote host and finds a free port on both computers
 2. Runs over the ssh connection a python script that forwards connections on the remote host from `localhost:remote_port` to the unix domain socket at `/var/run/docker.sock`
 3. Starts a new bash session with DOCKER_HOST environment variable set to `tcp://localhost:local_port`
 4. On session exit it SIGTERMs the ssh connection.

Contributions are of course welcome.




