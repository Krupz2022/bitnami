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

error_code=0

redis_conf_file="${ERPNEXT_BASE_DIR}/frappe-bench/config/redis_socketio.conf"
redis_pid_file="$(redis_conf_get "pidfile" "$redis_conf_file")"
redis_log_file="${ERPNEXT_BASE_DIR}/frappe-bench/logs/redis-socketio.log"

if is_redis_not_running "$redis_pid_file"; then
    # Set proper ownership for log file, to ensure that log rotatio works
    touch "$redis_log_file"
    chmod g+rw "$redis_log_file"
    chown "${ERPNEXT_DAEMON_USER}:${ERPNEXT_DAEMON_GROUP}" "$redis_log_file"
    BITNAMI_QUIET=1 nohup /opt/bitnami/scripts/erpnext-redis-socketio/run.sh >>"$redis_log_file" 2>&1 &
    if ! retry_while "is_redis_running ${redis_pid_file}"; then
        error "erpnext-redis-socketio did not start"
        error_code=1
    else
        info "erpnext-redis-socketio started"
    fi
else
    info "erpnext-redis-socketio is already running"
fi

exit "$error_code"
