#!/bin/sh
Port=$(echo $1 $2 | \
      md5sum | \
      sed -e 's/^[^0-9]*\(.\)[^0-9]*\(.\)[^0-9]*\(.\)[^0-9 ]*\(.\).*/3\1\2\3\4/')
#echo $BLA
ssh $1 adb start-server
ssh -fNT -L $Port:0:5037 $1
DevID=$2
shift;shift
adb -P $Port -s $DevID "$@"
