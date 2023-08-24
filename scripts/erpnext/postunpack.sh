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
. /opt/bitnami/scripts/liberpnext.sh
. /opt/bitnami/scripts/libfile.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/liblog.sh

# Ensure the ERPNext base directory exists and has proper permissions
info "Configuring file permissions for ERPNext"
ensure_user_exists "$ERPNEXT_DAEMON_USER" --group "$ERPNEXT_DAEMON_GROUP"
for dir in "${ERPNEXT_BASE_DIR}/frappe-bench/logs" "${ERPNEXT_BASE_DIR}/frappe-bench/sites"; do
    ensure_dir_exists "$dir"
    configure_permissions_ownership "$dir" -d "g+rwx" -f "g+rw" -u "$ERPNEXT_DAEMON_USER" -g "root"
done
# Allow new folders to be created like 'archived_sites' in Frappe's bench directory
chown "${ERPNEXT_DAEMON_USER}:root" "${ERPNEXT_BASE_DIR}/frappe-bench"
chmod g+rwX "${ERPNEXT_BASE_DIR}/frappe-bench"

# Configure common site settings
# https://frappeframework.com/docs/user/en/basics/site_config#common-site-config
info "Configuring common site settings"
erpnext_site_conf_set "common" "frappe_user" "$ERPNEXT_DAEMON_USER"

# Load additional libraries
# shellcheck disable=SC1090,SC1091
. /opt/bitnami/scripts/libwebserver.sh
. /opt/bitnami/scripts/libredis.sh

# Load web server environment for web_server_* functions
. "/opt/bitnami/scripts/$(web_server_type)-env.sh"
# Load web server environment for redis_* functions
. /opt/bitnami/scripts/redis-env.sh

# Log rotation
# 'su' option used to avoid: "error: skipping (...) because parent directory has insecure permissions (It's world writable or writable by group which is not "root")"
# Setting owner to 'bitnami' since 'bench.log' must belong to 'bitnami' for the CLI to work
generate_logrotate_conf "erpnext" "${ERPNEXT_BASE_DIR}/frappe-bench/logs/*log" --extra "su ${ERPNEXT_DAEMON_USER} ${ERPNEXT_DAEMON_GROUP}"

# Enable extra service management configuration
info "Configuring extra services"
if [[ "$BITNAMI_SERVICE_MANAGER" = "monit" ]]; then
    for redis_instance in cache socketio queue; do
        redis_instance_conf_file="${ERPNEXT_BASE_DIR}/frappe-bench/config/redis_${redis_instance}.conf"
        redis_instance_pid_file="$(redis_conf_get "pidfile" "$redis_instance_conf_file")"
        generate_monit_conf "erpnext-redis-${redis_instance}" "$redis_instance_pid_file" /opt/bitnami/scripts/"erpnext-redis-${redis_instance}"/start.sh /opt/bitnami/scripts/"erpnext-redis-${redis_instance}"/stop.sh
    done
    # Socket.io service
    generate_monit_conf "erpnext-node-socketio" "$ERPNEXT_NODE_SOCKETIO_PID_FILE" /opt/bitnami/scripts/erpnext-node-socketio/start.sh /opt/bitnami/scripts/erpnext-node-socketio/stop.sh
    # Background jobs
    generate_monit_conf "erpnext-frappe-schedule" "$ERPNEXT_FRAPPE_SCHEDULE_PID_FILE" /opt/bitnami/scripts/erpnext-frappe-schedule/start.sh /opt/bitnami/scripts/erpnext-frappe-schedule/stop.sh
    for worker_instance in default short long; do
        worker_instance_pid_file_variable="ERPNEXT_FRAPPE_${worker_instance^^}_WORKER_PID_FILE"
        generate_monit_conf "erpnext-frappe-${worker_instance}-worker" "${!worker_instance_pid_file_variable}" "/opt/bitnami/scripts/erpnext-frappe-${worker_instance}-worker/start.sh" "/opt/bitnami/scripts/erpnext-frappe-${worker_instance}-worker/stop.sh"
    done
elif [[ "$BITNAMI_SERVICE_MANAGER" = "systemd" ]]; then
    for redis_instance in cache socketio queue; do
        redis_instance_conf_file="${ERPNEXT_BASE_DIR}/frappe-bench/config/redis_${redis_instance}.conf"
        redis_instance_pid_file="$(redis_conf_get "pidfile" "$redis_instance_conf_file")"
        generate_systemd_conf "erpnext-redis-${redis_instance}" \
            --name "ERPNext Redis ${redis_instance}" \
            --user "$ERPNEXT_DAEMON_USER" \
            --group "$ERPNEXT_DAEMON_GROUP" \
            --exec-start "${REDIS_BIN_DIR}/redis-server ${redis_instance_conf_file} --daemonize yes" \
            --pid-file "$redis_instance_pid_file"
    done
    # Use 'simple' type to start service in foreground and consider started while it is running
    # Socket.io service
    generate_systemd_conf "erpnext-node-socketio" \
        --type "simple" \
        --name "ERPNext node Socket.io" \
        --user "$ERPNEXT_DAEMON_USER" \
        --group "$ERPNEXT_DAEMON_GROUP" \
        --exec-start "${BITNAMI_ROOT_DIR}/node/bin/node ${ERPNEXT_BASE_DIR}/frappe-bench/apps/frappe/socketio.js"
    # Background jobs
    generate_systemd_conf "erpnext-frappe-schedule" \
        --type "simple" \
        --name "ERPNext Frappe schedule" \
        --user "$ERPNEXT_DAEMON_USER" \
        --group "$ERPNEXT_DAEMON_GROUP" \
        --working-directory "${ERPNEXT_BASE_DIR}/frappe-bench" \
        --exec-start "${ERPNEXT_BIN_DIR}/bench schedule"
    for worker_instance in default short long; do
        worker_instance_pid_file_variable="ERPNEXT_FRAPPE_${worker_instance^^}_WORKER_PID_FILE"
        generate_systemd_conf "erpnext-frappe-${worker_instance}-worker" \
            --type "simple" \
            --name "ERPNext Frappe ${worker_instance} worker" \
            --user "$ERPNEXT_DAEMON_USER" \
            --group "$ERPNEXT_DAEMON_GROUP" \
            --working-directory "${ERPNEXT_BASE_DIR}/frappe-bench" \
            --exec-start "${ERPNEXT_BIN_DIR}/bench worker --queue ${worker_instance}"
    done
else
    error "Unsupported service manager ${BITNAMI_SERVICE_MANAGER}"
    exit 1
fi

# Enable default web server configuration for ERPNext
info "Creating default web server configuration for ERPNext"
web_server_validate
# Based on https://github.com/frappe/bench/blob/develop/bench/config/templates/nginx.conf
# Note: Using WSGI instead of a reverse proxy
ensure_web_server_app_configuration_exists "erpnext" \
    --apache-move-htaccess no \
    --document-root "${ERPNEXT_BASE_DIR}/frappe-bench/sites" \
    --apache-additional-configuration "$(cat <<EOF
# BEGIN: Virtualenv configuration
<IfDefine !IS_ERPNEXT_LOADED>
  Define IS_ERPNEXT_LOADED
  WSGIDaemonProcess erpnext user=daemon group=daemon processes=2 threads=15 display-name=%{GROUP} python-home=${ERPNEXT_BASE_DIR}/frappe-bench/env home=${ERPNEXT_BASE_DIR}/frappe-bench/sites
</IfDefine>
WSGIProcessGroup erpnext
WSGIApplicationGroup %{GLOBAL}
# Avoid '504 Gateway Timeout' errors while executing the application's setup wizard
TimeOut 120
# END: Virtualenv configuration

# BEGIN: ERPNext configuration
# Based on the 'nginx.conf' template with modifications for WSGI support
# https://github.com/frappe/bench/blob/develop/bench/config/templates/nginx.conf
# A final version of the 'nginx.conf' can be generated by executing 'bench setup nginx' and checking 'config/nginx.conf' afterwards

# Block: 'location /assets'
Alias /assets ${ERPNEXT_BASE_DIR}/frappe-bench/sites/assets
<Directory ${ERPNEXT_BASE_DIR}/frappe-bench/sites/assets>
  Require all granted
</Directory>

# Block: 'location ~ ^/protected/(.*)'
Alias /protected ${ERPNEXT_BASE_DIR}/frappe-bench/sites/erpnext/
<Directory /protected>
  Require local
</Directory>

# Block: 'location /socket.io'
<Location /socket.io/>
  RewriteEngine On
  RewriteCond %{REQUEST_URI}  ^/socket.io/           [NC]
  RewriteCond %{QUERY_STRING} transport=websocket    [NC]
  RewriteRule /(.*)           ws://localhost:3000/\$1 [P,L]
  ProxyPass         http://localhost:3000/socket.io/
  ProxyPassReverse  http://localhost:3000/socket.io/
</Location>

# Block: 'location /'
RewriteEngine on
RewriteRule ^(.+)/$ \$1 [R=permanent,L]
RewriteRule ^(.+)/index\.html$ \$1 [R=permanent,L]
RewriteRule ^(.+)\.html$ \$1 [R=permanent,L]
# -> Sub-block: 'location ~ ^/files/.*.(htm|html|svg|xml)'
Alias /files ${ERPNEXT_BASE_DIR}/frappe-bench/sites/erpnext/public/files
<Location ~ ^/files/.*.(htm|html|svg|xml)>
  Header set Content-Disposition attachment
</Location>
<Directory ${ERPNEXT_BASE_DIR}/frappe-bench/sites/erpnext/public/files>
  Require all granted
</Directory>
# -> Sub-block: 'try_files /erpnext/public/\$uri'
WSGIScriptAlias / ${ERPNEXT_BASE_DIR}/frappe-bench/apps/frappe/frappe/app.py
<Directory ${ERPNEXT_BASE_DIR}/frappe-bench/apps/frappe/frappe>
  Options +MultiViews
  Require all granted
</Directory>

# Block: 'location @webserver'
<Location />
  RequestHeader set X-Frappe-Site-Name erpnext
</Location>

# Block: error pages
ErrorDocument 502 /502.html
Alias /502.html ${ERPNEXT_BASE_DIR}/bench/bench/config/templates/502.html
<Directory ${ERPNEXT_BASE_DIR}/bench/bench/config/templates>
  Require all granted
</Directory>

# END: ERPNext configuration
EOF
    )"

# Grant ownership to the default "bitnami" SSH user to edit files, and restrict permissions for the web server
info "Granting ERPNext files ownership to the 'bitnami' user"
configure_permissions_ownership "$ERPNEXT_BASE_DIR" -u "bitnami" -g "$ERPNEXT_DAEMON_GROUP"
# Ensure that the config and log folders can be written to by sub-services
chmod -R g+rwX "${ERPNEXT_BASE_DIR}/frappe-bench/config" "${ERPNEXT_BASE_DIR}/frappe-bench/logs"
