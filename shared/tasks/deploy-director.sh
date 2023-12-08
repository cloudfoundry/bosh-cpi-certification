#!/usr/bin/env bash

set -e

: ${NETWORK_NAME:?}

source pipelines/shared/utils.sh
if [[ -f "/etc/profile.d/chruby.sh" ]] ; then
  source /etc/profile.d/chruby.sh
  chruby $RUBY_VERSION
fi

# inputs
input_dir=$(realpath director-config/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)

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
  BOSH_LOG_PATH=$logfile bosh create-env \
    --vars-store "${output_dir}/creds.yml" \
    director.yml
  bosh_cli_exit_code="$?"
  set -e

  if [ ${bosh_cli_exit_code} != 0 ]; then
    echo "bosh-cli deploy failed!" >&2
    cat $logfile >&2
    exit ${bosh_cli_exit_code}
  fi
popd > /dev/null

director_ip=$( state_path "/instance_groups/name=bosh/networks/name=${NETWORK_NAME}/static_ips/0" )
ssh_private_key=$( creds_path /jumpbox_ssh/private_key | sed 's/$/\\n/' | tr -d '\n' )

cat > "${output_dir}/director.env" <<EOF
export BOSH_ENVIRONMENT="${director_ip}"
export BOSH_CLIENT="admin"
export BOSH_CLIENT_SECRET="$( creds_path /admin_password )"
export BOSH_CA_CERT="$( creds_path /director_ssl/ca )"
private_key_path=\$(mktemp)
echo -e "${ssh_private_key}" > \${private_key_path}

export BOSH_ALL_PROXY="ssh+socks5://jumpbox@${director_ip}:22?private-key=\${private_key_path}"
EOF
