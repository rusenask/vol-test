#!/bin/bash -ex 
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. envfile.sh

  # TODO: provision new key and add to jenkins slaves

if [[ -z $SUITES ]] || [[ -z "$STORAGEOS_VERSION" ]]; then
  (>2& echo "Please specify the Job you want to run and the container version") 
  exit 1
fi

function main() {
for IaaS in $IAAS; do
    IAASDIR="$DIR/cloud-provisioners/${IaaS}/"
    
    file=$(tempfile)
    python generate-job.py ${CONTAINER:--c} $SUITES > $file

    # the assumption here is we don't want to run a job if identical jobfile (same SHA) + identical storageos version 
    PARTSHA=$(sha1sum $file | cut -c1-5)
    JOBUID="${PARTSHA}-$(echo $STORAGEOS_VERSION | tr '.' '_')"

    # we take the existence of this unique job file to mean a cluster for this job is running
    # this is what the limitations of bash lead to..
    if [[ -f $IAASDIR/configs/$JOBUID ]]; then
      echo "Provisioner failed for suites $SUITES on $IaaS, continuing.."
      continue 
    else
      mkdir -p $IAASDIR/configs
      cp -T $file $IAASDIR/configs/$JOBUID
      env JOBUID=$JOBUID STORAGEOS_VERSION=$STORAGEOS_VERSION $IAASDIR/scripts/new-cluster.sh 
    fi

done 
}

main
