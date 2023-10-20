#!/bin/bash
compile() {
    echo "Compiling all targets..."
    cd /root/c++-multicast/
    /usr/sbin/cmake --build /root/c++-multicast/build --config Release --target all -j 14 --
    echo "All targets are compiled."
}

get_process_count() {
    echo $(pgrep multicast-dh | wc -l)
}

get_subscriber_count() {
    echo $(($1-1))
}

get_members_up_count_by_unique_ports() {
    echo $(ss -lup | grep multicast-dh-ex | awk '{print $4}' |  awk -F: '{print $NF}' | grep -v 65000 | sort -u | wc -l)
}

start() {
    cd /root/c++-multicast/
    /root/c++-multicast/build/statistics-writer-main $2 &
    echo "statistics-writer is started"

    for (( i=0; i<$(get_subscriber_count $2); i++ ))
    do
        /root/c++-multicast/build/multicast-dh-example false $1 $2 $3 $4 &
    done
    while [[ $(get_process_count) -ne $(get_subscriber_count $2) ]]; do
        echo "Waiting for all subscribers to start up, $(get_process_count)/$(get_subscriber_count $2) are up"
        sleep 1
    done
    echo "All subscribers started up"
    while [[ $(get_members_up_count_by_unique_ports) < $(get_subscriber_count $2) ]]; do
        echo "There are still ports bound more than once"
        sleep 1
    done
    /root/c++-multicast/build/multicast-dh-example true $1 $2 $3 $4 &
    echo "Initial sponsor is started"
    while [[ -n $(pgrep statistics-wr) ]]; do
        sleep 1
    done
    echo "statistics-writer is stopped"
}

function on_exit() {
    echo "Terminating all processes ..."
    pkill "statistics-wr"
    pkill "multicast-dh"
    echo "All processes terminated"
    exit 1
}

if [ $# -ne 4 ]; then
    echo "Not enough parameters" 1>&2
    echo "Usage: $0 <service_id> <member_count> <scatter_delay_min(ms)> <scatter_delay_max(ms)>"
    echo "Example: $0 42 20 10 100"
    exit 1
fi

if [[ $1 -lt 1 ]]; then
    echo "service id must be greater than 0"
    exit 1
fi

echo $2

if [[ $2 -lt 1 ]]; then
    echo "member count must be greater than 1"
    exit 1
fi

trap 'on_exit' SIGINT

compile
start $1 $2 $3 $4