#!/bin/bash

DIR="./"


    if [ -f $DIR"/placeChecker.pid" ]; then
	pid=`cat $DIR"/placeChecker.pid"`
	echo $pid
	kill $pid
	rm -r $DIR"/placeChecker.pid"
	
	echo -ne "Stoping Daemon"

        while true; do
            [ ! -d "/proc/$pid/fd" ] && break
            echo -ne "."
            sleep 1
        done
        echo -ne "\rDaemon Stopped.    \n"
    fi

