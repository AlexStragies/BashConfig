#!/bin/sh
[ -z "$1" ] && { echo "ADB-SSH Destination required as \$1"; exit 1; }

Port="3"$(echo $1 | md5sum | tr -d a-z | colrm 5 55)
ssh $1 adb start-server     || { echo "Error: Can't contact $1 by SSH";exit 1; }
ssh -fNT -L $Port:0:5037 $1 || { echo "Error: Can't contact $1 by SSH";exit 1; }
shift

[ ! -z $1 ] && DevID="-s $1" && shift;

adb -P $Port $DevID "${@:-shell}"
