#!/usr/bin/env bash

set -eu

source pipelines/shared/utils.sh
source director-state/director.env

creds_path /jumpbox_ssh/private_key > /tmp/jumpbox_private_key
chmod 600 /tmp/jumpbox_private_key
export BOSH_GW_PRIVATE_KEY=/tmp/jumpbox_private_key

export BOSH_BINARY_PATH=$(which bosh)
export SYSLOG_RELEASE_PATH=$(realpath syslog-release/*.tgz)
export OS_CONF_RELEASE_PATH=$(realpath os-conf-release/*.tgz)
export STEMCELL_PATH=$(realpath stemcell/*.tgz)
export BOSH_stemcell_version=\"$(realpath stemcell/version | xargs -n 1 cat)\"

pushd bosh-linux-stemcell-builder
  export PATH=/usr/local/go/bin:$PATH
  export GOPATH=$(pwd)
  echo -e "Rebasing with the official latest code until the issue bosh-linux-stemcell-builder/issues/93 and /bosh-linux-stemcell-builder/pull/89 are fixed"
  git branch
  git remote add bosh https://github.com/cloudfoundry/bosh-linux-stemcell-builder.git
  git remote -v
  git pull --rebase bosh master

  echo -e "Rebase finished."

  pushd src/github.com/cloudfoundry/stemcell-acceptance-tests
    ./bin/test-smoke $package
  popd
popd
