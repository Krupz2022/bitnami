#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load Redis environment variables
. /opt/bitnami/scripts/redis-env.sh

# Load libraries
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libredis.sh

# Load ERPNext environment for 'ERPNEXT_BASE_DIR' (after 'redis-env.sh' so that MODULE is not set to a wrong value)
. /opt/bitnami/scripts/erpnext-env.sh

# Parse CLI flags to pass to the 'redis-server' call
redis_conf_file="${ERPNEXT_BASE_DIR}/frappe-bench/config/redis_socketio.conf"
args=("$redis_conf_file" "--daemonize" "no")
# Add flags specified via the 'REDIS_EXTRA_FLAGS' environment variable
read -r -a extra_flags <<< "$REDIS_EXTRA_FLAGS"
[[ "${#extra_flags[@]}" -gt 0 ]] && args+=("${extra_flags[@]}")
# Add flags passed to this script
args+=("$@")

info "** Starting erpnext-redis-socketio **"
if am_i_root; then
    exec_as_user "$ERPNEXT_DAEMON_USER" redis-server "${args[@]}"
else
    exec redis-server "${args[@]}"
fi
