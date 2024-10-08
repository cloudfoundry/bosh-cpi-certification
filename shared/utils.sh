#!/usr/bin/env bash

state_path() { bosh int director-state/director.yml --path="$1" ; }
creds_path() { bosh int director-state/creds.yml --path="$1" ; }

certify_artifacts() {
  local usage="Usage: certify_artifacts BOSH_RELEASE_NAME BOSH_RELEASE_VERSION CPI_RELEASE_NAME CPI_RELEASE_VERSION STEMCELL_NAME STEMCELL_VERSION"

  local bosh_release_name=${1?$usage}
  local bosh_release_version=${2?$usage}

  local cpi_release_name=${3?$usage}
  local cpi_release_version=${4?$usage}

  local stemcell_name=${5?$usage}
  local stemcell_version=${6?$usage}

  cat  <<EOF
{
  "releases": [
    {
      "name": "$bosh_release_name",
      "version": "$bosh_release_version"
    },
    {
      "name": "$cpi_release_name",
      "version": "$cpi_release_version"
    }
  ],
  "stemcell": {
    "name": "$stemcell_name",
    "version": "$stemcell_version"
  }
}
EOF
}
