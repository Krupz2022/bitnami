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

# Constants
EXEC="node"
declare -a args=("${ERPNEXT_BASE_DIR}/frappe-bench/apps/frappe/socketio.js" "$@")

info "** Starting erpnext-node-socketio **"
if am_i_root; then
    exec_as_user "$ERPNEXT_DAEMON_USER" "$EXEC" "${args[@]}"
else
    exec "$EXEC" "${args[@]}"
fi
