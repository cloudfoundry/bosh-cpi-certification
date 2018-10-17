#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.4.4

# preparation
export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
bats_dir=$(realpath bats)

# disable host key checking for deployed VMs
mkdir -p $HOME/.ssh
cat > $HOME/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

source "$(realpath bats-config/bats.env)"
: ${BAT_DIRECTOR:?}
: ${BAT_DNS_HOST:?}
: ${BAT_INFRASTRUCTURE:?}
: ${BAT_NETWORKING:?}
: ${BAT_VCAP_PASSWORD:?}

: ${BAT_VCAP_PRIVATE_KEY:=""}
: ${BAT_VIP:=""}
: ${BAT_SUBNET_ID:=""}
: ${BAT_SECURITY_GROUP_NAME:=""}
: ${BAT_RSPEC_FLAGS:=""}
: ${BAT_DIRECTOR_USER:=""}
: ${BAT_DIRECTOR_PASSWORD:=""}

if [ -n "${BAT_VCAP_PRIVATE_KEY}" ]; then
  ssh_key_path="$(realpath ${BAT_VCAP_PRIVATE_KEY})"
  chmod go-r ${ssh_key_path}
  eval $(ssh-agent)
  ssh-add ${ssh_key_path}
fi

pushd $bats_dir
  bundle install
  bundle exec rspec spec ${BAT_RSPEC_FLAGS}
popd
