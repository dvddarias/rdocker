#!/bin/bash
# set -e

if [[  $# -ne 1 || $1 == "-h" || $1 == "-help" ]]; then
    echo "Usage: rdocker [-h|-help] [user@]hostname"
    exit
fi

control_path="$HOME/.rdocker-master-`date +%s%N`"

ssh ${1} -nNf -o ControlMaster=yes -o ControlPath="$control_path" -o ControlPersist=yes

if [ ! -S "$control_path" ]; then
    exit
fi

find_port_code="import socket;s=socket.socket(socket.AF_INET, socket.SOCK_STREAM);s.bind(('', 0));print(s.getsockname()[1]);s.close()"

remote_port=$(ssh ${1} -o ControlPath=$control_path python -c \"$find_port_code\")

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
    addr = (\"localhost\",$remote_port)
    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(addr)
        server.listen(50)
    except socket.error as msg:
        server.close()
        print \"Port $remote_port is already taken.\"
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
    try:
        uds_socket.connect(\"/var/run/docker.sock\")
    except socket.error as msg:
        uds_socket.close()
        tcp_socket.close()
        return

    rlist = [tcp_socket, uds_socket]
    while running:
        readable, writable, exceptional = select.select(rlist, [], [], 0.5)

        if tcp_socket in readable:
            data = tcp_socket.recv(4096)
            if not data or not running: break
            else:
                uds_socket.sendall(data)

        if uds_socket in readable:
            data = uds_socket.recv(4096)
            if not data or not running: break
            else:
                tcp_socket.sendall(data)

    tcp_socket.shutdown(socket.SHUT_RDWR)
    tcp_socket.close()
    uds_socket.shutdown(socket.SHUT_RDWR)
    uds_socket.close()

if __name__ == \"__main__\":
    main()
"

# find an unused local port
# create a temporary named pipe and attach it to file descriptor 3
PIPE=$(mktemp -u); mkfifo $PIPE
exec 3<>$PIPE; rm $PIPE
# execute ssh in background
local_port=$(python -c "$find_port_code")
remote_script_path="/tmp/rdocker-forwarder.py"
printf "$forwarder" | ssh ${1} -o ControlPath=$control_path -o ExitOnForwardFailure=yes -L localhost:$local_port:localhost:$remote_port "cat > ${remote_script_path}; exec python -u ${remote_script_path}" 1>&3 &
CONNECTION_PID=$!
# wait for it's output
read -u 3 -d . line
exec 3>&-

if [[ $line == $success_msg ]]; then
    echo "Starting a new shell session with docker host set to \"localhost:${local_port}\"."
    echo "Press Ctrl+D to exit."
    export DOCKER_HOST="tcp://localhost:${local_port}"
    bash
    kill -15 $CONNECTION_PID
    echo "Disconnected from ${1} docker daemon."
else
    echo $line
fi

ssh -O exit -o ControlPath="$control_path" ${1} 2> /dev/null
rm -f "$control_path"
