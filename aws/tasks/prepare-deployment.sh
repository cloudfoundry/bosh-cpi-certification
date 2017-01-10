#!/usr/bin/env bash

set -e

: ${BOSH_CLIENT_SECRET:?}
: ${BOSH_CLIENT:?}
: ${RELEASE_NAME:?}
: ${STEMCELL_NAME:?}
: ${DEPLOYMENT_NAME:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# inputs
bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

# configuration
: ${DIRECTOR_IP:=$(          stack_info "DirectorEIP" )}
: ${AVAILABILITY_ZONE:=$(    stack_info "AvailabilityZone" )}
: ${SUBNET_ID:=$(            stack_info "PublicSubnetID" )}

# outputs
manifest_dir="$(realpath deployment-manifest)"

time $bosh_cli -n env ${DIRECTOR_IP//./-}.sslip.io

cat > "${manifest_dir}/deployment.yml" <<EOF
---
name: ${DEPLOYMENT_NAME}

releases:
  - name: ${RELEASE_NAME}
    version: latest

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    instance_type: m3.medium
    availability_zone: ${AVAILABILITY_ZONE}

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3

resource_pools:
  - name: default
    stemcell:
      name: ${STEMCELL_NAME}
      version: latest
    network: private
    cloud_properties:
      instance_type: m3.medium
      availability_zone: ${AVAILABILITY_ZONE}

networks:
  - name: private
    type: dynamic
    cloud_properties: {subnet: ${SUBNET_ID}}

jobs:
  - name: simple
    template: simple
    instances: 1
    resource_pool: default
    networks:
      - name: private
        default: [dns, gateway]
EOF
