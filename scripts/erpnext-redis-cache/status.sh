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

# Load ERPNext environment for 'ERPNEXT_BASE_DIR' (after 'redis-env.sh' so that MODULE is not set to a wrong value)
. /opt/bitnami/scripts/erpnext-env.sh

redis_conf_file="${ERPNEXT_BASE_DIR}/frappe-bench/config/redis_cache.conf"
redis_pid_file="$(redis_conf_get "pidfile" "$redis_conf_file")"

if is_redis_running "$redis_pid_file"; then
    info "erpnext-redis-cache is already running"
else
    info "erpnext-redis-cache is not running"
fi
