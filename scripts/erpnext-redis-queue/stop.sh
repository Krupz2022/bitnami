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
. /opt/bitnami/scripts/libredis.sh
. /opt/bitnami/scripts/libos.sh

# Load ERPNext environment for 'ERPNEXT_BASE_DIR' (after 'redis-env.sh' so that MODULE is not set to a wrong value)
. /opt/bitnami/scripts/erpnext-env.sh

error_code=0

redis_conf_file="${ERPNEXT_BASE_DIR}/frappe-bench/config/redis_queue.conf"
redis_port="$(redis_conf_get "port" "$redis_conf_file")"
redis_pid_file="$(redis_conf_get "pidfile" "$redis_conf_file")"

if is_redis_running "$redis_pid_file"; then
    if am_i_root; then
        run_as_user "$ERPNEXT_DAEMON_USER" "${REDIS_BASE_DIR}/bin/redis-cli" -p "$redis_port" shutdown
    else
        "${REDIS_BASE_DIR}/bin/redis-cli" -p "$redis_port" shutdown
    fi
    if ! retry_while "is_redis_not_running ${redis_pid_file}"; then
        error "erpnext-redis-queue could not be stopped"
        error_code=1
    else
        info "erpnext-redis-queue stopped"
    fi
else
    info "erpnext-redis-queue is not running"
fi

exit "$error_code"
