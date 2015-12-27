#!/bin/bash
# set -e

port=${2-12345}
success_msg="Connection established"
forwarder="
import threading,socket,select,signal,sys,os

running = True

def signal_handler(signal, frame):
    global running
    running = False
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def main():
    global running
    addr = (\"localhost\",$port)
    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(addr)
        server.listen(50)
    except socket.error as msg:
        server.close()
        print \"Port $port is already taken.\"
        sys.exit(0)
    print \"${success_msg}.\"
    rlist = [server]
    while running:
        readable, writable, exceptional = select.select(rlist, [], [], 0.5)
        if os.getppid() == 1:
            running=False
            break
        if server in readable:
            client, connection = server.accept()
            threading.Thread(target=serve_client, args=(client,)).start()

    server.shutdown(socket.SHUT_RDWR)
    server.close()

def serve_client(tcp_socket):
    global running
    uds_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    uds_socket.connect(\"/var/run/docker.sock\")
    rlist = [tcp_socket, uds_socket]
    while running:
        readable, writable, exceptional = select.select(rlist, [], [], 0.5)

        if tcp_socket in readable:
            data = tcp_socket.recv(4096)
            if not data or not running:
                break
            else:
                uds_socket.sendall(data)

        if uds_socket in readable:
            data = uds_socket.recv(4096)
            if not data: break
            else:
                tcp_socket.sendall(data)

    tcp_socket.shutdown(socket.SHUT_RDWR)
    tcp_socket.close()
    uds_socket.shutdown(socket.SHUT_RDWR)
    uds_socket.close()

if __name__ == \"__main__\":
    main()
"

config_file=$HOME/.rdocker.info

if [[ ( $# -eq 1 || $# -eq 2 ) && $1 != "-h" && $1 != "-help" ]]; then
    # create a temporary named pipe and attach it to file descriptor 3
    PIPE=$(mktemp -u); mkfifo $PIPE
    exec 3<>$PIPE; rm $PIPE
    printf "$forwarder" | ssh ${1} -L localhost:$port:localhost:$port "cat > /tmp/forward.py; exec python -u /tmp/forward.py;" 1>&3 &
    CONNECTION_PID=$!
    read -u 3 -d . line
    exec 3>&-

    if [[ $line == $success_msg ]]; then
        echo $line
        echo "Starting a new shell session with docker host set to ${1}."
        echo "Press Ctrl+D to exit."
        export DOCKER_HOST="tcp://localhost:${port}"
        bash
        kill -15 $CONNECTION_PID
        echo "Remote docker disconnected from ${1}."
    else
        echo $line
    fi
    exit
else
    echo "Usage: ./rdocker [-h] user@hostname [port]"
fi
