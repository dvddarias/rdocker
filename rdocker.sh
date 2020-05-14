#!/bin/bash
set -e

re='^[0-9]+$'
if [[ $# -eq 0 || $1 == "-h" || $1 == "-help" ]]; then
    echo "Usage: rdocker [-h|-help] [user@]hostname [port] [cmd]"
    echo ""
    echo "    -h -help        print this message"
    echo "    user@hostname   ssh remote login address"
    echo "    port            local port used to forward the remote docker daemon, if not present a free random port will be used"
    echo "    cmd             when provided, it is the only command run on the remote host (no bash session is created)"
    exit
fi

PYTHON_CLIENT=$(command -v python || command -v python3)
PYTHON_REMOTE='$(command -v python || command -v python3)'

#Extracting parameters
remote_host=${1}
if [[ $2 =~ $re ]]; then
    local_port=${2}
    command=${@:3} #third parameter and beyond
else
    command=${@:2} #second parameter and beyond
fi

control_path="$HOME/.rdocker-master-`date +%s%N`"

ssh ${remote_host} -nNf -o ControlMaster=yes -o ControlPath="${control_path}" -o ControlPersist=yes

if [ ! -S "${control_path}" ]; then
    exit 1
fi

find_port_code="import socket;s=socket.socket(socket.AF_INET, socket.SOCK_STREAM);s.bind(('', 0));print(s.getsockname()[1]);s.close()"

remote_port=$(ssh ${remote_host} -o ControlPath=${control_path} $PYTHON_REMOTE -c \"$find_port_code\")

if [ -z $remote_port ]; then
    echo "ERROR: Failed to find a free port. This usually happens when python is not installed on the remote host."
    #clear the ssh control connection
    ssh -O exit -o ControlPath="$control_path" $remote_host 2> /dev/null
    rm -f "$control_path"
    exit 1
fi

success_msg="Connection established"
forwarder="
import threading,socket,select,signal,sys,os
running = True
remote_port = $remote_port
def signal_handler(signal, frame):
    global running
    running = False
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def main():
    global running
    addr = (\"localhost\", remote_port)
    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(addr)
        server.listen(50)
    except socket.error as msg:
        server.close()
        print(\"Port \" + remote_port + \" is already in use.\")
        sys.exit(0)
    print(\"${success_msg}.\")
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
# find a free port or use the provided one
local_port=${local_port:-$($PYTHON_CLIENT -c "$find_port_code")}

remote_script_path="/tmp/rdocker-$remote_port-forwarder.py"
printf "$forwarder" | ssh $remote_host -o ControlPath=$control_path -L $local_port:localhost:$remote_port "cat > ${remote_script_path}; exec $PYTHON_REMOTE -u ${remote_script_path}" 1>&3 &
CONNECTION_PID=$!
# wait for it's output
read -u 3 -d . line
exec 3>&-

if [[ $line == $success_msg ]]; then
    export DOCKER_HOST="tcp://localhost:${local_port}"

    if [[ -n "$command" ]]; then
        bash -c "$command"
        exit_status=$?
        kill -15 $CONNECTION_PID
        #clear the ssh control connection
        ssh -O exit -o ControlPath="$control_path" $remote_host 2> /dev/null
        rm -f "$control_path"
        #exit with the same status as the command
        exit $exit_status
    else
        COLOR='\033[0;33m'
        NC='\033[0m'
        RED='\033[1;31m'

        echo -e "Local docker client connected to ${COLOR}${remote_host}${NC} docker daemon."
        echo "Route: localhost:${local_port} -> ${remote_host}:${remote_port}"
        echo -e "Press ${RED}Ctrl+D${NC} to stop forwarding and exit the bash session."
        export PROMPT_COMMAND="echo -en \"${COLOR}docker:${remote_host}${NC} \""
        bash
    fi

    kill -15 $CONNECTION_PID
    echo -e "Disconnected from ${COLOR}$remote_host${NC} docker daemon."
else
    echo $line
fi

#clear the ssh control connection
ssh -O exit -o ControlPath="$control_path" $remote_host 2> /dev/null
rm -f "$control_path"
