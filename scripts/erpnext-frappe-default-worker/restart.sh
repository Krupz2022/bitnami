#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

/opt/bitnami/scripts/erpnext-frappe-default-worker/stop.sh
/opt/bitnami/scripts/erpnext-frappe-default-worker/start.sh
