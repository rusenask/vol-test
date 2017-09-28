#!/bin/bash

# this script will be continually executed from the runner
# it will be running on every node
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 testtype blocksize [replicas] [cache true/false]"
  exit 1
fi

TEST_TYPE=$1
BLKSIZE=$2
REPLICAS=${3:-0}
CACHE=${4:-true}

cli_auth="-u ${STORAGEOS_USERNAME:-storageos} -p ${STORAGEOS_PASSWORD:-storageos}"
volname=$(uuidgen | cut -c1-5)

if [ $REPLICAS -gt 0 ]; then
  LABELS="--label storageos.feature.replicas=${REPLICAS}"
fi

if [ $CACHE == "false" ]; then
  LABELS="$LABELS --label storageos.feature.nocache=true"
fi

storageos $cli_auth volume create $LABELS $volname

volid=$(storageos $CREDS volume inspect default/$volname --format {{.ID}})

OUTPUT="tee -a"
if [[ -n $INFLUXDB_URI ]]; then
  TAGS="bs=${BLKSIZE},type=${TEST_TYPE},replicas=${REPLICAS},cache=${CACHE}"
  [ -n $HOSTNAME ] && TAGS="$TAGS,hostname=${HOSTNAME}"
  [ -n $CPU ] && TAGS="$TAGS,cpus=${CPU}"
  [ -n $MEMORY ] && TAGS="$TAGS,memory=${MEMORY}"
  OUTPUT="fiord influxdb --uri $INFLUXDB_URI --db=${INFLUXDB_DBNAME:-fio} --tags $TAGS"
fi

fio --output-format=json $DIR/$TEST_TYPE.fio --bs=$BLKSIZE --filename /var/lib/storageos/volumes/$volid | $OUTPUT

storageos $cli_auth volume rm default/$volname