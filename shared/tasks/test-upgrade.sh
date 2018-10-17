#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.4.4

: ${DEPLOYMENT_NAME:?}

# inputs
old_director_state=$(realpath old-director-state/)
new_director_config=$(realpath new-director-config/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

# outputs
output_dir=$(realpath new-director-state/)

source ${new_director_config}/director.env
: ${BOSH_ENVIRONMENT:?}
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}

cp -r ${new_director_config}/* ${output_dir}
cp -r ${old_director_state}/*-state.json ${output_dir}

# deployment manifest references releases and stemcells relative to itself...make it true
# these resources are also used in the teardown step
mkdir -p ${output_dir}/{stemcell,bosh-release,cpi-release}
cp ${stemcell_dir}/*.tgz ${output_dir}/stemcell/
cp ${bosh_dir}/*.tgz ${output_dir}/bosh-release/
cp ${cpi_dir}/*.tgz ${output_dir}/cpi-release/

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
  time ${bosh_cli} create-env director.yml
popd > /dev/null

echo "recreating existing BOSH Deployment..."
time $bosh_cli -n -d ${DEPLOYMENT_NAME} recreate
