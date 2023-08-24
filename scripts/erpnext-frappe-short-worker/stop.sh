#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load ERPNext environment
. /opt/bitnami/scripts/erpnext-env.sh

# Load libraries
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/liberpnext.sh

error_code=0

if erpnext_is_frappe_worker_running short; then
    erpnext_frappe_worker_stop short
    if ! retry_while "erpnext_is_frappe_worker_not_running short"; then
        error "erpnext-frappe-short-worker could not be stopped"
        error_code=1
    else
        info "erpnext-frappe-short-worker stopped"
    fi
else
    info "erpnext-frappe-short-worker is not running"
fi

exit "$error_code"
