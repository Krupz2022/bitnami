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

if erpnext_is_node_socketio_running; then
    erpnext_node_socketio_stop
    if ! retry_while "erpnext_is_node_socketio_not_running"; then
        error "erpnext-node-socketio could not be stopped"
        error_code=1
    else
        info "erpnext-node-socketio stopped"
    fi
else
    info "erpnext-node-socketio is not running"
fi

exit "$error_code"
