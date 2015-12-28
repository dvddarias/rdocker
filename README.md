# Remote Docker

Securely control a remote docker daemon using ssh forwarding, effectively avoiding the SSL setup.

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

The forwarding uses by default the port `22522` on the remote host and the local machine so it will fail if it is already in use. If you want to use another port, for example 12345, run `./rdocker.sh user@myamazingweb.com 12345`.

##How does it work

This is a general overview of how it works, feel free to check the script for further details:

 1. Connects over ssh to the remote host and forwards the local 22522 port to the remote 22522 port
 2. Runs over the ssh connection a python script that forwards connections on the remote host from `localhost:22522` to the unix domain socket at `/var/run/docker.sock`
 2. Starts a new bash session with DOCKER_HOST environment variable set to `tcp://localhost:22522`
 3. On session exit it SIGTERMs the ssh connection.

Contributions are of course welcome.




