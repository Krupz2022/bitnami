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
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/liberpnext.sh

if erpnext_is_frappe_schedule_running; then
    info "erpnext-frappe-schedule is already running"
else
    info "erpnext-frappe-schedule is not running"
fi
