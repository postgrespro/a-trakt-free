#!/bin/bash

INSTANCE_NAME=$1

#sudo ./snapshooter.pl reset mnt "${INSTANCE_NAME}"  1>&2 || exit 1
sudo $TRAKT_BIN/snapshooter.pl reset $STEP_CACHE/mnt "${INSTANCE_NAME}"  1>&2 || exit 1


