#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.4.4

# inputs
input_dir=$(realpath director-config/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

# outputs
output_dir=$(realpath director-state/)
cp ${input_dir}/* ${output_dir}

# deployment manifest references releases and stemcells relative to itself...make it true
# these resources are also used in the teardown step
mkdir -p ${output_dir}/{stemcell,bosh-release,cpi-release}
cp ${stemcell_dir}/*.tgz ${output_dir}/stemcell/
cp ${bosh_dir}/*.tgz ${output_dir}/bosh-release/
cp ${cpi_dir}/*.tgz ${output_dir}/cpi-release/

logfile=$(mktemp /tmp/bosh-cli-log.XXXXXX)

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat "${output_dir}/director-state.json"
  echo "=========================================="

  cp -r $HOME/.bosh ${output_dir}
  rm -rf $logfile
}
trap finish EXIT

pushd ${output_dir} > /dev/null
  echo "deploying BOSH..."

  set +e
  BOSH_LOG_PATH=$logfile BOSH_LOG_LEVEL=DEBUG $bosh_cli create-env ./director.yml
  bosh_cli_exit_code="$?"
  set -e

  if [ ${bosh_cli_exit_code} != 0 ]; then
    echo "bosh-cli deploy failed!" >&2
    cat $logfile >&2
    exit ${bosh_cli_exit_code}
  fi
popd > /dev/null
