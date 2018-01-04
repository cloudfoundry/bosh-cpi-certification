#!/usr/bin/env bash

set -eu

: ${INFRASTRUCTURE:?}
: ${DIRECTOR_VARS_FILE:?}

source pipelines/shared/utils.sh
source director-state/director.env

bosh -n update-cloud-config bosh-deployment/$INFRASTRUCTURE/cloud-config.yml \
  -l <( pipelines/${INFRASTRUCTURE}/assets/director-vars ) \
  -l <( echo "$DIRECTOR_VARS_FILE" ) \
  $( echo ${OPTIONAL_OPS_FILE} )
