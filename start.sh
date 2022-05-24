#!/bin/bash

DATADIR="./"

./stop.sh
./bp-position-daemon.sh & echo $! > $DATADIR/placeChecker.pid

