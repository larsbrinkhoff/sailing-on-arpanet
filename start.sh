#!/bin/sh

WAITS="http://sky-visions.com/dec/waits"
DSK="dsk/j6"
PACKS="0 1 2"

PDP10="$HOME/src/sims/BIN/pdp10-ka"
H316="$HOME/src/simh/BIN/h316"
NCPD="$HOME/src/linux-ncp/src/ncpd"
TELNETD="$HOME/src/linux-ncp/apps/ncp-telnet"

download() {
    echo -n "Downloading:"
    for i in $PACKS; do
        echo -n " $i"
        wget -q "$WAITS/$DSK/SYS00$i.ckd.bz2"
    done
    echo " OK"
}

reset() {
    echo -n "Unpacking:"
    for i in $PACKS; do
        echo -n " $i"
        bzcat "SYS00$i.ckd.bz2" > "SYS00$i.ckd"
    done
    echo " OK"
}

udp_ready() {
    while :; do
        netstat -un4 | grep ":$1 .* ESTABLISHED" >/dev/null && return
        sleep 1
    done
}

socket_ready() {
    while test \! -S "$1"; do
        sleep 1
    done
}

start_imp() {
    (echo "Starting IMP."
     "$H316" imp11.simh >imp.log 2>&1) &
    PIDS="$PIDS $!"
}

start_ncp() {
    (udp_ready 33003
     sleep 1
     echo "Starting NCP daemon."
     "$NCPD" localhost 33003 33004 2>ncp.log) &
    PIDS="$PIDS $!"
}

start_telnetd() {
    (socket_ready "$NCP"
     sleep 1
     echo "Starting telnet server."
     "$TELNETD" -osp 1 >telnetd.log 2>&1) &
    PIDS="$PIDS $!"
}

start_pdp10() {
    n=10
    echo "Allow $n seconds for IMP to start up."
    sleep $n
    echo "Starting PDP-10."
    "$PDP10" waits.ini 2> pdp10.log
}

export NCP="$PWD/ncp"
rm -f "$NCP"

test -f "SYS000.ckd.bz2" || download
test -n "$1" && "$1"
test -f "SYS000.ckd" || reset

PIDS=""
start_imp
start_ncp
start_telnetd
start_pdp10

kill $PIDS >/dev/null 2>&1
sleep 2
kill -9 $PIDS >/dev/null 2>&1

exit 0
