#!/usr/bin/env bash

set -e

: ${DIRECTOR_VARS_FILE:?}
: ${INFRASTRUCTURE:?}

source pipelines/shared/utils.sh

bosh int \
  -o bosh-deployment/${INFRASTRUCTURE}/cpi.yml \
  -o bosh-deployment/misc/powerdns.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -o pipelines/shared/assets/ops/custom-releases.yml \
  -o pipelines/${INFRASTRUCTURE}/assets/ops/custom-cpi-release.yml \
  $( echo ${OPTIONAL_OPS_FILE} ) \
  -v bosh_release_uri="file://$(echo bosh-release/*.tgz)" \
  -v cpi_release_uri="file://$(echo cpi-release/*.tgz)" \
  -v stemcell_uri="file://$(echo stemcell/*.tgz)" \
  -v director_name=bosh \
  -l <( echo "${DIRECTOR_VARS_FILE}" ) \
  -l <( pipelines/${INFRASTRUCTURE}/assets/director-vars ) \
  bosh-deployment/bosh.yml > director-config/director.yml
