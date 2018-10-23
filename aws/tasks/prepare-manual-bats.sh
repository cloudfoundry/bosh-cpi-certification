#!/usr/bin/env bash

set -e

# environment

: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}
: ${BAT_VCAP_PASSWORD:?}
: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${PUBLIC_KEY_NAME:?}
: ${STEMCELL_NAME:?}

: ${AWS_ACCESS_KEY_ID:=${AWS_ACCESS_KEY}}
: ${AWS_SECRET_ACCESS_KEY:=${AWS_SECRET_KEY}}
: ${AWS_DEFAULT_REGION:=${AWS_REGION_NAME}}

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.4.4

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# configuration
: ${SECURITY_GROUP:=$(         aws ec2 describe-security-groups --group-ids $(stack_info "SecurityGroupID") | jq -r '.SecurityGroups[] .GroupName' ) }
: ${DIRECTOR_EIP:=$(           stack_info "DirectorEIP" )}
: ${BATS_EIP:=$(               stack_info "DeploymentEIP" )}
: ${SUBNET_ID:=$(              stack_info "PublicSubnetID" )}
: ${AVAILABILITY_ZONE:=$(      stack_info "AvailabilityZone" )}
: ${NETWORK_CIDR:=$(           stack_info "PublicCIDR" )}
: ${NETWORK_GATEWAY:=$(        stack_info "PublicGateway" )}
: ${NETWORK_RESERVED_RANGE:=$( stack_info "ReservedRange" )}
: ${NETWORK_STATIC_RANGE:=$(   stack_info "StaticRange" )}
: ${NETWORK_STATIC_IP_1:=$(    stack_info "StaticIP1" )}
: ${NETWORK_STATIC_IP_2:=$(    stack_info "StaticIP2" )}

# inputs
director_config=$(realpath director-config)
bats_dir=$(realpath bats)

# outputs
output_dir=$(realpath bats-config)
bats_spec="${output_dir}/bats-config.yml"
bats_env="${output_dir}/bats.env"
ssh_key="${output_dir}/shared.pem"

# env file generation
cat > "${bats_env}" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${DIRECTOR_EIP}
export BAT_DNS_HOST=${DIRECTOR_EIP}
export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual
export BAT_VIP=${BATS_EIP}
export BAT_SUBNET_ID=${SUBNET_ID}
export BAT_SECURITY_GROUP_NAME=${SECURITY_GROUP}
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_VCAP_PRIVATE_KEY="bats-config/shared.pem"
export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~root_partition"
export BAT_DIRECTOR_USER="${BOSH_CLIENT}"
export BAT_DIRECTOR_PASSWORD="${BOSH_CLIENT_SECRET}"
EOF

pushd "${bats_dir}" > /dev/null
  ./write_gemfile
  bundle install
  bundle exec bosh -n target "${DIRECTOR_EIP}"
  BOSH_UUID="$(bundle exec bosh status --uuid)"
popd > /dev/null

# BATs spec generation
cat > "${bats_spec}" <<EOF
---
cpi: aws
properties:
  vip: ${BATS_EIP}
  second_static_ip: ${NETWORK_STATIC_IP_2}
  uuid: ${BOSH_UUID}
  pool_size: 1
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  instances: 1
  availability_zone: ${AVAILABILITY_ZONE}
  key_name:  ${PUBLIC_KEY_NAME}
  networks:
    - name: default
      static_ip: ${NETWORK_STATIC_IP_1}
      type: manual
      cidr: ${NETWORK_CIDR}
      reserved: [${NETWORK_RESERVED_RANGE}]
      static: [${NETWORK_STATIC_RANGE}]
      gateway: ${NETWORK_GATEWAY}
      subnet: ${SUBNET_ID}
      security_groups: [${SECURITY_GROUP}]
EOF

cp ${director_config}/shared.pem ${ssh_key}
