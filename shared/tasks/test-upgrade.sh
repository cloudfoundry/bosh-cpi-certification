#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.4.4

: ${DEPLOYMENT_NAME:?}

# outputs
output_dir=$(realpath new-director-state/)

cp -r new-director-config/director.yml ${output_dir}
cp -r old-director-state/*-state.json ${output_dir}
cp old-director-state/creds.yml ${output_dir}
cp old-director-state/director.env ${output_dir}
source old-director-state/director.env

# deployment manifest references releases and stemcells relative to itself...make it true
# these resources are also used in the teardown step
mkdir -p ${output_dir}/{stemcell,bosh-release,cpi-release}
cp stemcell/*.tgz ${output_dir}/stemcell/
cp bosh-release/*.tgz ${output_dir}/bosh-release/
cp cpi-release/*.tgz ${output_dir}/cpi-release/

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat "${output_dir}/director-state.json"
  echo "=========================================="

  cp -r $HOME/.bosh ${output_dir}
}
trap finish EXIT

echo "upgrading existing BOSH Director VM..."
pushd ${output_dir} > /dev/null
  time bosh create-env --state "${output_dir}/director-state.json" \
    --vars-store "${output_dir}/creds.yml" -v director_name=bosh \
    director.yml
popd > /dev/null

echo "recreating existing BOSH Deployment..."
time bosh -n -d ${DEPLOYMENT_NAME} recreate
