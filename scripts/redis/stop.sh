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

error_code=0

if is_redis_running; then
    BITNAMI_QUIET=1 redis_stop
    if ! retry_while "is_redis_not_running"; then
        error "redis could not be stopped"
        error_code=1
    else
        info "redis stopped"
    fi
else
    info "redis is not running"
fi

exit "$error_code"
