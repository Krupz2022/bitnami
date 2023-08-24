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

error_code=0

if is_redis_not_running; then
    nohup /opt/bitnami/scripts/redis/run.sh >/dev/null 2>&1 &
    if ! retry_while "is_redis_running"; then
        error "redis did not start"
        error_code=1
    else
        info "redis started"
    fi
else
    info "redis is already running"
fi

exit "$error_code"
