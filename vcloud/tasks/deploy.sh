#!/usr/bin/env bash

set -e

: ${VCLOUD_VLAN:?}
: ${VCLOUD_HOST:?}
: ${VCLOUD_USER:?}
: ${VCLOUD_PASSWORD:?}
: ${VCLOUD_ORG:?}
: ${VCLOUD_VDC:?}
: ${VCLOUD_VAPP:?}
: ${VCLOUD_CATALOG:?}
: ${NETWORK_CIDR:?}
: ${NETWORK_GATEWAY:?}
: ${BATS_DIRECTOR_IP:?}

source /etc/profile.d/chruby.sh
chruby 2.1.2

# inputs
cpi_release_dir=$(realpath bosh-cpi-release)
bosh_release_dir=$(realpath bosh-release)
stemcell_dir=$(realpath stemcell)
bosh_init_dir=$(realpath bosh-init)
director_state_dir=$(realpath director-state)

bosh_init=$(echo ${bosh_init_dir}/bosh-init-*)
chmod +x $bosh_init

bosh_tarball=$(echo ${bosh_release_dir}/*.tgz)
cpi_tarball=$(echo ${cpi_release_dir}/*.tgz)
stemcell_tarball=$(echo ${stemcell_dir}/*.tgz)

# outputs
deployment_dir="$(realpath deployment)"

cat > "${deployment_dir}/${manifest_filename}" <<EOF
---
name: bats-director

releases:
  - name: bosh
    url: file://${bosh_tarball}
  - name: bosh-vcloud-cpi
    url: file://${cpi_tarball}

resource_pools:
  - name: vms
    network: private
    stemcell:
      url: file://${stemcell_tarball}
    cloud_properties:
      cpu: 2
      ram: 4_096
      disk: 20_000
    env:
      vapp: ${VCLOUD_VAPP}

disk_pools:
  - name: disks
    disk_size: 20_000

networks:
  - name: private
    type: manual
    subnets:
      - range: ${NETWORK_CIDR}
        gateway: ${NETWORK_GATEWAY}
        dns: [8.8.8.8]
        cloud_properties: {name: ${VCLOUD_VLAN}}

jobs:
  - name: bosh
    instances: 1

    templates:
      - {name: nats, release: bosh}
      - {name: redis, release: bosh}
      - {name: postgres, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: vcloud_cpi, release: bosh-vcloud-cpi}

    resource_pool: vms
    persistent_disk_pool: disks

    networks:
      - {name: private, static_ips: [${BATS_DIRECTOR_IP}]}

    properties:
      nats:
        address: 127.0.0.1
        user: nats
        password: nats-password

      redis:
        listen_addresss: 127.0.0.1
        address: 127.0.0.1
        password: redis-password

      postgres: &db
        host: 127.0.0.1
        user: postgres
        password: postgres-password
        database: bosh
        adapter: postgres

      blobstore:
        address: ${BATS_DIRECTOR_IP}
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: bats-director
        db: *db
        cpi_job: vcloud_cpi
        max_threads: 10

      vcd: &vcd
        url: ${VCLOUD_HOST}
        user: ${VCLOUD_USER}
        password: ${VCLOUD_PASSWORD}
        entities:
          organization: ${VCLOUD_ORG}
          virtual_datacenter: ${VCLOUD_VDC}
          vapp_catalog: ${VCLOUD_CATALOG}
          media_catalog: ${VCLOUD_CATALOG}
          media_storage_profile: '*'
          vm_metadata_key: vm-metadata-key
        control: {wait_max: 900}

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: admin, password: admin}
        resurrector_enabled: true

      dns:
        address: 127.0.0.1
        db: *db

      agent: {mbus: "nats://nats:nats-password@${BATS_DIRECTOR_IP}:4222"}

      ntp: &ntp [0.pool.ntp.org, 1.pool.ntp.org]

cloud_provider:
  template: {name: vcloud_cpi, release: bosh-vcloud-cpi}

  mbus: "https://mbus:mbus-password@${BATS_DIRECTOR_IP}:6868"

  properties:
    vcd: *vcd
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: *ntp
EOF

echo "deleting existing BOSH Director VM..."
cp ${director_state_dir}/director-state.json ${deployment_dir}/director-state.json
$bosh_init delete ${deployment_dir}/director.yml

echo "deploying BOSH..."
$bosh_init deploy ${deployment_dir}/director.yml
