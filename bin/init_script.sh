#!/bin/bash

INSTANCE_NAME=$1
THIS_DIR=$(dirname $0)


#sudo ./snapshooter.pl clone mnt "${INSTANCE_NAME}"  1>&2  || exit 1
#sudo ./snapshooter.pl reset mnt "${INSTANCE_NAME}"  1>&2  || exit 1

sudo $TRAKT_BIN/snapshooter.pl clone $STEP_CACHE/mnt "${INSTANCE_NAME}"  1>&2  || exit 1
sudo $TRAKT_BIN/snapshooter.pl reset $STEP_CACHE/mnt "${INSTANCE_NAME}"  1>&2  || exit 1

#echo "PGDATA=${THIS_DIR}/mnt/$INSTANCE_NAME"
echo "PGDATA=$STEP_CACHE/mnt/$INSTANCE_NAME"

