#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0
#
# Bitnami ERPNext library

# shellcheck disable=SC1091

# Load generic libraries
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libnet.sh
. /opt/bitnami/scripts/libfile.sh
. /opt/bitnami/scripts/libvalidations.sh
. /opt/bitnami/scripts/libpersistence.sh
. /opt/bitnami/scripts/libservice.sh

# Load database library
if [[ -f /opt/bitnami/scripts/libmysqlclient.sh ]]; then
    . /opt/bitnami/scripts/libmysqlclient.sh
elif [[ -f /opt/bitnami/scripts/libmysql.sh ]]; then
    . /opt/bitnami/scripts/libmysql.sh
elif [[ -f /opt/bitnami/scripts/libmariadb.sh ]]; then
    . /opt/bitnami/scripts/libmariadb.sh
fi

########################
# Validate settings in ERPNEXT_* env vars
# Globals:
#   ERPNEXT_*
# Arguments:
#   None
# Returns:
#   0 if the validation succeeded, 1 otherwise
#########################
erpnext_validate() {
    debug "Validating settings in ERPNEXT_* environment variables..."
    local error_code=0

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }
    check_empty_value() {
        if is_empty_value "${!1}"; then
            print_validation_error "${1} must be set"
        fi
    }
    check_yes_no_value() {
        if ! is_yes_no_value "${!1}" && ! is_true_false_value "${!1}"; then
            print_validation_error "The allowed values for ${1} are: yes no"
        fi
    }
    check_multi_value() {
        if [[ " ${2} " != *" ${!1} "* ]]; then
            print_validation_error "The allowed values for ${1} are: ${2}"
        fi
    }
    check_resolved_hostname() {
        if ! is_hostname_resolved "$1"; then
            warn "Hostname ${1} could not be resolved, this could lead to connection issues"
        fi
    }
    check_valid_port() {
        local port_var="${1:?missing port variable}"
        local err
        if ! err="$(validate_port "${!port_var}")"; then
            print_validation_error "An invalid port was specified in the environment variable ${port_var}: ${err}."
        fi
    }

    # Validate user inputs
    ! is_empty_value "$ERPNEXT_DATABASE_HOST" && check_resolved_hostname "$ERPNEXT_DATABASE_HOST"
    ! is_empty_value "$ERPNEXT_DATABASE_PORT_NUMBER" && check_valid_port "ERPNEXT_DATABASE_PORT_NUMBER"
    ! is_empty_value "$ERPNEXT_REDIS_CACHE_HOST" && check_resolved_hostname "$ERPNEXT_REDIS_CACHE_HOST"
    ! is_empty_value "$ERPNEXT_REDIS_CACHE_PORT_NUMBER" && check_valid_port "ERPNEXT_REDIS_CACHE_PORT_NUMBER"
    ! is_empty_value "$ERPNEXT_REDIS_SOCKETIO_HOST" && check_resolved_hostname "$ERPNEXT_REDIS_CACHE_HOST"
    ! is_empty_value "$ERPNEXT_REDIS_SOCKETIO_PORT_NUMBER" && check_valid_port "ERPNEXT_REDIS_CACHE_PORT_NUMBER"
    ! is_empty_value "$ERPNEXT_REDIS_QUEUE_HOST" && check_resolved_hostname "$ERPNEXT_REDIS_CACHE_HOST"
    ! is_empty_value "$ERPNEXT_REDIS_QUEUE_PORT_NUMBER" && check_valid_port "ERPNEXT_REDIS_CACHE_PORT_NUMBER"

    # Validate credentials
    # Note that ERPNext does not support empty credentials, it requires them to be defined or it will set them by itself
    for empty_env_var in "ERPNEXT_DATABASE_ADMIN_PASSWORD" "ERPNEXT_PASSWORD"; do
        is_empty_value "${!empty_env_var}" && print_validation_error "The ${empty_env_var} environment variable is empty or not set."
    done

    # Validate SMTP credentials
    if ! is_empty_value "$ERPNEXT_SMTP_HOST"; then
        for empty_env_var in "ERPNEXT_SMTP_USER" "ERPNEXT_SMTP_PASSWORD"; do
            is_empty_value "${!empty_env_var}" && warn "The ${empty_env_var} environment variable is empty or not set."
        done
        is_empty_value "$ERPNEXT_SMTP_PORT_NUMBER" && print_validation_error "The ERPNEXT_SMTP_PORT_NUMBER environment variable is empty or not set."
        ! is_empty_value "$ERPNEXT_SMTP_PORT_NUMBER" && check_valid_port "ERPNEXT_SMTP_PORT_NUMBER"
        ! is_empty_value "$ERPNEXT_SMTP_PROTOCOL" && check_multi_value "ERPNEXT_SMTP_PROTOCOL" "ssl tls"
    fi

    return "$error_code"
}

########################
# Ensure ERPNext is initialized
# Globals:
#   ERPNEXT_*
# Arguments:
#   None
# Returns:
#   None
#########################
erpnext_initialize() {
    local -r site_name="erpnext"

    # Check that external services are alive
    info "Trying to connect to the database server"
    erpnext_wait_for_mysql_connection "$ERPNEXT_DATABASE_HOST" "$ERPNEXT_DATABASE_PORT_NUMBER" "$ERPNEXT_DATABASE_ADMIN_USER" "$ERPNEXT_DATABASE_ADMIN_PASSWORD"
    info "Trying to connect to the Redis services"
    erpnext_wait_for_redis_connection "$ERPNEXT_REDIS_CACHE_HOST" "$ERPNEXT_REDIS_CACHE_PORT_NUMBER"
    erpnext_wait_for_redis_connection "$ERPNEXT_REDIS_SOCKETIO_HOST" "$ERPNEXT_REDIS_SOCKETIO_PORT_NUMBER"
    erpnext_wait_for_redis_connection "$ERPNEXT_REDIS_QUEUE_HOST" "$ERPNEXT_REDIS_QUEUE_PORT_NUMBER"

    # Configure common site config
    # https://frappeframework.com/docs/user/en/basics/site_config#common-site-config
    info "Configuring common site settings based on environment variables"
    erpnext_site_conf_set "common" "redis_cache" "redis://${ERPNEXT_REDIS_CACHE_HOST}:${ERPNEXT_REDIS_CACHE_PORT_NUMBER}"
    erpnext_site_conf_set "common" "redis_socketio" "redis://${ERPNEXT_REDIS_SOCKETIO_HOST}:${ERPNEXT_REDIS_SOCKETIO_PORT_NUMBER}"
    erpnext_site_conf_set "common" "redis_queue" "redis://${ERPNEXT_REDIS_QUEUE_HOST}:${ERPNEXT_REDIS_QUEUE_PORT_NUMBER}"
    erpnext_site_conf_set "common" "socketio_port" "$ERPNEXT_NODE_SOCKETIO_PORT_NUMBER"

    # Perform initial bootstrapping for ERPNext
    # Based on https://github.com/frappe/bench#basic-usage
    # and https://github.com/frappe/frappe_docker/blob/master/development/README.md#create-a-new-site-with-bench
    info "Installing ERPNext"
    local -a install_flags=(
        # Admin user credentials
        "--admin-password" "$ERPNEXT_PASSWORD"
        # Database credentials
        # Note that there is no --db-user parameter because Frappe sets it to the value of --db-name
        # See: https://github.com/frappe/frappe/blob/master/frappe/__init__.py#L187
        # In function 'connect': 'local.db = Database(user=db_name or local.conf.db_name)'
        "--db-name" "$ERPNEXT_DATABASE_NAME"
        "--db-type" "mariadb"
        "--db-host" "$ERPNEXT_DATABASE_HOST"
        "--db-port" "$ERPNEXT_DATABASE_PORT_NUMBER"
        "--mariadb-root-username" "$ERPNEXT_DATABASE_ADMIN_USER"
        "--mariadb-root-password" "$ERPNEXT_DATABASE_ADMIN_PASSWORD"
    )
    # This is going to create a database and an associated database user for the site
    # Unfortunately ERPNext does not allow this database or user to be created externally (i.e. via mysql-client), as it would fail
    erpnext_execute new-site "${install_flags[@]}" "$site_name"
    erpnext_execute --site "$site_name" install-app erpnext

    # FIX: Print support by setting app hostname
    # There is no public references about this, however the solution is repeatedly mentioned in their forum
    # E.g.: https://discuss.erpnext.com/t/no-product-image-in-pdf-or-while-printing/12040/3
    # NOTE: The host name does not need to be publicly available, however if unset, trying to print anything will cause a Gateway Timeout error
    erpnext_site_conf_set "$site_name" "host_name" "http://localhost"

    if ! is_empty_value "$ERPNEXT_SMTP_HOST"; then
        # List of supported SMTP options is not documented, but can be obtained from
        # https://github.com/frappe/frappe/blob/develop/frappe/data/sample_site_config.json
        erpnext_site_conf_set "$site_name" "mail_server" "$ERPNEXT_SMTP_HOST"
        erpnext_site_conf_set "$site_name" "mail_login" "$ERPNEXT_SMTP_USER"
        erpnext_site_conf_set "$site_name" "mail_password" "$ERPNEXT_SMTP_PASSWORD"
        erpnext_site_conf_set "$site_name" "mail_port" "$ERPNEXT_SMTP_PORT_NUMBER"
        erpnext_site_conf_set "$site_name" "use_ssl" "1"
        erpnext_site_conf_set "$site_name" "auto_email_id" "$ERPNEXT_EMAIL"
    fi

    info "Passing ERPNext setup wizard"
    erpnext_pass_wizard

    # Avoid exit code of previous commands to affect the result of this function
    true
}

########################
# Add or modify an entry in the ERPNext site configuration file
# Globals:
#   ERPNEXT_*
# Arguments:
#   $1 - Site name
#   $2 - Variable name
#   $3 - Value to assign to the variable
# Returns:
#   None
#########################
erpnext_site_conf_set() {
    local -r site_name="${1:?site name missing}"
    local -r key="${2:?key missing}"
    local -r value="${3:?value missing}"
    local -a cmd=("--site" "erpnext" "set-config")
    if [[ "$site_name" = "common" ]]; then
        cmd=("config" "set-common-config" "-c")
    fi
    # Ensure value is a quoted string (bench code returning errors)
    erpnext_execute "${cmd[@]}" "$key" "'${value//\'/\\\'}'"
}

########################
# Wait until the database is accessible with the currently-known credentials
# Globals:
#   *
# Arguments:
#   $1 - database host
#   $2 - database port
#   $3 - database admin username
#   $4 - database admin user password (optional)
# Returns:
#   true if the database connection succeeded, false otherwise
#########################
erpnext_wait_for_mysql_connection() {
    local -r db_host="${1:?missing database host}"
    local -r db_port="${2:?missing database port}"
    local -r db_admin_user="${3:?missing database user}"
    local -r db_admin_pass="${4:-}"
    local -r db_name=""
    check_mysql_connection() {
        echo "SELECT 1" | mysql_remote_execute "$db_host" "$db_port" "$db_name" "$db_admin_user" "$db_admin_pass"
    }
    if ! retry_while "check_mysql_connection"; then
        error "Could not connect to the database"
        return 1
    fi
}

########################
# Wait until Redis is accessible
# Globals:
#   *
# Arguments:
#   $1 - Redis host
#   $2 - Redis port
# Returns:
#   true if the Redis connection succeeded, false otherwise
#########################
erpnext_wait_for_redis_connection() {
    local -r redis_host="${1:?missing Redis host}"
    local -r redis_port="${2:?missing Redis port}"
    if ! retry_while "debug_execute wait-for-port --timeout 5 --host ${redis_host} ${redis_port}"; then
        error "Could not connect to Redis"
        return 1
    fi
}

########################
# Execute a command using the 'bench' CLI
# Globals:
#   ERPNEXT_*
# Arguments:
#   $1 - log file
# Returns:
#   None
#########################
erpnext_execute() {
    local -a cmd=("bench" "$@")
    am_i_root && cmd=("run_as_user" "$ERPNEXT_DAEMON_USER" "${cmd[@]}")
    (
        cd "${ERPNEXT_BASE_DIR}/frappe-bench" || false
        debug_execute "${cmd[@]}"
    )
}

########################
# Parse and validate ERPNext JSON responses
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   true if the message could be parsed and validated, false otherwise
#########################
erpnext_parse_json_response() {
    local -r response="${1:?missing response}"
    local error_msg
    # Check if it is a valid JSON response
    if jq -e '.' >/dev/null 2>&1 <<< "$response"; then
        # Check if it is a success response
        if jq -e 'if (.message | type == "string") then true else .message.status == "ok" end' >/dev/null 2>&1 <<< "$response"; then
            local message_content
            message_content="$(jq -r 'if (.message | type == "string") then .message else .message.status end' <<< "$response")"
            debug "Got response: ${message_content}"
            # Print the message so it can be obtained as result of this function
            echo "$message_content"
            return
        elif jq -e '.message | has("fail")' >/dev/null 2>&1 <<< "$response"; then
            error_msg="$(jq -r '.message.fail' <<< "$response")"
            error "An error occurred while installing ERPNext: ${error_msg}"
            if [[ "$error_msg" = "Failed to install presets" ]]; then
                error "Check your locale settings, UTF-8 is required"
            fi
            # Now print the output to debug (note: since we already validated it is a JSON object, format with jq)
            debug_execute jq . <<< "$response"
            return 1
        fi
    fi
    # Fallback error
    error "An unknown error occurred while installing ERPNext: Unable to parse response"
    debug "$curl_output"
    return 1
}

########################
# Pass ERPNext wizard
# Globals:
#   *
# Arguments:
#   None
# Returns:
#   true if the wizard succeeded, false otherwise
#########################
erpnext_pass_wizard() {
    local -r port="${WEB_SERVER_HTTP_PORT_NUMBER:-"$WEB_SERVER_DEFAULT_HTTP_PORT_NUMBER"}"
    local wizard_url cookie_file curl_output
    local -a curl_opts curl_data_opts
    local erpnext_response_message
    wizard_url="http://127.0.0.1:${port}"
    cookie_file="/tmp/cookie$(generate_random_string -t alphanumeric -c 8)"
    curl_opts=("--location" "--silent" "--cookie" "$cookie_file" "--cookie-jar" "$cookie_file")
    # Ensure the web server is started
    # Note: Force UTF-8 to ensure that the web server starts the Python environment via WSGI with a supported locale
    LANG="en_US.UTF-8" web_server_start
    # Step 0: Get cookies
    debug "Getting cookies"
    curl "${curl_opts[@]}" "$wizard_url" >/dev/null 2>/dev/null
    # Step 1: Log in as existing 'Administrator' account
    debug "Logging in"
    curl_opts+=("--header" "X-Requested-With: XMLHttpRequest")
    curl_data_opts=(
        "--data-urlencode" "cmd=login"
        "--data-urlencode" "usr=Administrator"
        "--data-urlencode" "pwd=${ERPNEXT_PASSWORD}"
        "--data-urlencode" "device=desktop"
    )
    curl_output="$(curl "${curl_opts[@]}" "${curl_data_opts[@]}" "$wizard_url" 2>/dev/null)"
    erpnext_response_message="$(erpnext_parse_json_response "$curl_output")"
    if [[ "$erpnext_response_message" != "Logged in" ]]; then
        error "An error occurred while installing ERPNext: ${erpnext_response_message}"
        return 1
    fi
    # Step 2: Initialize the ERPNext application with inputs passed via environment variables
    # NOTE: If this step fails with "Failed to install presets", check that the locale is using UTF-8 (e.g. LANG=en_US.UTF-8)
    debug "Populating data"
    local erpnext_install_data
    erpnext_install_data=(
        ".language=\"English\""
        ".country=\"United States\""
        ".timezone=\"America/Los_Angeles\""
        ".currency=\"USD\""
        ".full_name=\"${ERPNEXT_FIRST_NAME} ${ERPNEXT_LAST_NAME}\""
        ".email=\"${ERPNEXT_EMAIL}\""
        ".password=\"${ERPNEXT_PASSWORD}\""
        ".domains=[\"Services\"]"
        ".company_name=\"Bitnami\""
        ".company_abbr=\"B\""
        ".company_tagline=\"Build awesome stacks\""
        ".bank_account=\"XYZ\""
        ".chart_of_accounts=\"Standard\""
        ".fy_start_date=\"$(date "+%Y")-01-01\""
        ".fy_end_date=\"$(date "+%Y")-12-31\""
    )
    # Create JSON object with data in 'erpnext_install_values'
    local erpnext_install_json="{}"
    for entry in "${erpnext_install_data[@]}"; do
        erpnext_install_json="$(jq -c "${entry}" <<< "$erpnext_install_json")"
    done
    curl_data_opts=(
        "--data-urlencode" "cmd=frappe.desk.page.setup_wizard.setup_wizard.setup_complete"
        "--data-urlencode" "args=${erpnext_install_json}"
    )
    curl_output="$(curl "${curl_opts[@]}" "${curl_data_opts[@]}" "$wizard_url" 2>/dev/null)"
    erpnext_parse_json_response "$curl_output"
    # Stop the web server afterwards
    web_server_stop
}

########################
# Check if node-socketio daemons are running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
erpnext_is_node_socketio_running() {
    # node-socketio does not create any PID file
    # We regenerate the PID file for each time we query it to avoid getting outdated
    pgrep -f "^node ${ERPNEXT_BASE_DIR}/frappe-bench/apps/frappe/socketio.js" > "$ERPNEXT_NODE_SOCKETIO_PID_FILE"

    pid="$(get_pid_from_file "$ERPNEXT_NODE_SOCKETIO_PID_FILE")"
    if [[ -n "$pid" ]]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if node-socketio daemons are not running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
erpnext_is_node_socketio_not_running() {
    ! erpnext_is_node_socketio_running
}

########################
# Stop node-socketio daemons
# Arguments:
#   None
# Returns:
#   None
#########################
erpnext_node_socketio_stop() {
    ! erpnext_is_node_socketio_running && return
    stop_service_using_pid "$ERPNEXT_NODE_SOCKETIO_PID_FILE"
}

########################
# Check if frappe-schedule daemons are running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
erpnext_is_frappe_schedule_running() {
    # frappe-schedule does not create any PID file
    # We regenerate the PID file for each time we query it to avoid getting outdated
    pgrep -f "frappe schedule" > "$ERPNEXT_FRAPPE_SCHEDULE_PID_FILE"

    pid="$(get_pid_from_file "$ERPNEXT_FRAPPE_SCHEDULE_PID_FILE")"
    if [[ -n "$pid" ]]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if frappe-schedule daemons are not running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
erpnext_is_frappe_schedule_not_running() {
    ! erpnext_is_frappe_schedule_running
}

########################
# Stop frappe-schedule daemons
# Arguments:
#   None
# Returns:
#   None
#########################
erpnext_frappe_schedule_stop() {
    ! erpnext_is_frappe_schedule_running && return
    stop_service_using_pid "$ERPNEXT_FRAPPE_SCHEDULE_PID_FILE"
}

########################
# Check if a frappe worker daemon is running
# Arguments:
#   $1 - Worker
# Returns:
#   Boolean
#########################
erpnext_is_frappe_worker_running() {
    local -r worker="${1:?missing worker}"

    # frappe workers do not create any PID file
    # We regenerate the PID file for each time we query it to avoid getting outdated
    local pid_file_var="ERPNEXT_FRAPPE_${worker^^}_WORKER_PID_FILE"
    # At certain points in time, the service may be running a sub-process with the same cmdline
    # So for now stop only the main process
    pgrep -f "frappe worker --queue ${worker}" | head -n 1 > "${!pid_file_var}"

    pid="$(get_pid_from_file "${!pid_file_var}")"
    if [[ -n "$pid" ]]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if a frappe worker daemon is not running
# Arguments:
#   $1 - Worker
# Returns:
#   Boolean
#########################
erpnext_is_frappe_worker_not_running() {
    local -r worker="${1:?missing worker}"
    ! erpnext_is_frappe_worker_running "$worker"
}

########################
# Stop a frappe worker daemon
# Arguments:
#   $1 - Worker name
# Returns:
#   None
#########################
erpnext_frappe_worker_stop() {
    local -r worker="${1:?missing worker}"
    ! erpnext_is_frappe_worker_running "$worker" && return
    local pid_file_var="ERPNEXT_FRAPPE_${worker^^}_WORKER_PID_FILE"
    stop_service_using_pid "${!pid_file_var}"
}
