#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1090,SC1091

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

if erpnext_is_frappe_schedule_not_running; then
    # Set proper ownership for log file, to ensure that log rotatio works
    touch "$ERPNEXT_FRAPPE_SCHEDULE_LOG_FILE"
    chmod g+rw "$ERPNEXT_FRAPPE_SCHEDULE_LOG_FILE"
    chown "${ERPNEXT_DAEMON_USER}:${ERPNEXT_DAEMON_GROUP}" "$ERPNEXT_FRAPPE_SCHEDULE_LOG_FILE"
    BITNAMI_QUIET=1 nohup /opt/bitnami/scripts/erpnext-frappe-schedule/run.sh >>"$ERPNEXT_FRAPPE_SCHEDULE_LOG_FILE" 2>&1 &
    if ! retry_while "erpnext_is_frappe_schedule_running"; then
        error "erpnext-frappe-schedule did not start"
        error_code=1
    else
        info "erpnext-frappe-schedule started"
    fi
else
    info "erpnext-frappe-schedule is already running"
fi

exit "$error_code"
