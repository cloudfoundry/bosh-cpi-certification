#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.4.4

# inputs
input_dir=$(realpath director-state/)
bosh_cli=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $bosh_cli

if [ ! -e "${input_dir}/director-state.json" ]; then
  echo "director-state.json does not exist, skipping..."
  exit 0
fi

if [ -d "${input_dir}/.bosh" ]; then
  # reuse compiled packages
  cp -r ${input_dir}/.bosh $HOME/
fi

pushd ${input_dir} > /dev/null
  # configuration
  source director.env
  : ${BOSH_ENVIRONMENT:?}
  : ${BOSH_CLIENT:?}
  : ${BOSH_CLIENT_SECRET:?}

  # Don't exit on failure to delete existing deployment
  set +e
    # teardown deployments against BOSH Director
    if [ -n "${DEPLOYMENT_NAME}" ]; then
      time $bosh_cli -n delete-deployment -d ${DEPLOYMENT_NAME} --force
    fi
    time $bosh_cli -n clean-up --all
  set -e

  echo "deleting existing BOSH Director VM..."
  $bosh_cli -n delete-env director.yml
popd
