#!/bin/bash
set -e

function init-variables {
    local file="../env_variables"

    CASSANDRA_REPLICATION_TYPE="Simple"
    CASSANDRA_CONTACT_POINTS='172.16.238.68:9042' #initialized by the start-up script
    CASSANDRA_REPLICAS="1"
    POSTGRES_DRIVER_CLASS="org.postgresql.Driver"
    POSTGRES_HOST='172.16.238.66' #initialized by the start-up script
    POSTGRES_PWD="postgres"

    MS_VENDOR="Apache Fineract"
    IDENTITY_MS_NAME="identity-v1"
    RHYTHM_MS_NAME="rhythm-v1"
    OFFICE_MS_NAME="office-v1"
    CUSTOMER_MS_NAME="customer-v1"
    ACCOUNTING_MS_NAME="accounting-v1"
    PORTFOLIO_MS_NAME="portfolio-v1"
    DEPOSIT_MS_NAME="deposit-v1"
    TELLER_MS_NAME="teller-v1"
    REPORT_MS_NAME="report-v1"
    CHEQUES_MS_NAME="cheques-v1"
    PAYROLL_MS_NAME="payroll-v1"
    GROUP_MS_NAME="group-v1"
    NOTIFICATIONS_MS_NAME="notification-v1"

    while IFS="=" read -r key value; do
        case "$key" in
            '#'*) ;;
            "CASSANDRA_CLUSTER_NAME") CASSANDRA_CLUSTER_NAME="$value" ;;
            "POSTGRESQL_PORT") POSTGRESQL_PORT="$value" ;;
            "POSTGRESQL_USER") POSTGRESQL_USER="$value" ;;
            "PROVISIONER_IP") PROVISIONER_IP="$value"; PROVISIONER_URL="http://${PROVISIONER_IP}:2020/provisioner/v1" ;;
            "IDENTITY_IP") IDENTITY_IP="$value"; IDENTITY_URL="http://${IDENTITY_IP}:2021/identity/v1";;
            "RHYTHM_IP") RHYTHM_IP="$value"; RHYTHM_URL="http://${RHYTHM_IP}:2022/rhythm/v1";;
            "OFFICE_IP") OFFICE_IP="$value"; OFFICE_URL="http://${OFFICE_IP}:2023/office/v1";;
            "CUSTOMER_IP") CUSTOMER_IP="$value"; CUSTOMER_URL="http://${CUSTOMER_IP}:2024/customer/v1";;
            "ACCOUNTING_IP") ACCOUNTING_IP="$value"; ACCOUNTING_URL="http://${ACCOUNTING_IP}:2025/accounting/v1";;
            "PORTFOLIO_IP") PORTFOLIO_IP="$value"; PORTFOLIO_URL="http://${PORTFOLIO_IP}:2026/portfolio/v1";;
            "DEPOSIT_ACCOUNT_MANAGEMENT_IP") DEPOSIT_IP="$value"; DEPOSIT_URL="http://${DEPOSIT_IP}:2027/deposit/v1";;
            "TELLER_IP") TELLER_IP="$value"; TELLER_URL="http://${TELLER_IP}:2028/teller/v1";;
            "REPORTING_IP") REPORT_IP="$value"; REPORT_URL="http://${REPORT_IP}:2029/report/v1";;
            "CHEQUES_IP") CHEQUES_IP="$value"; CHEQUES_URL="http://${CHEQUES_IP}:2030/cheques/v1";;
            "PAYROLL_IP") PAYROLL_IP="$value"; PAYROLL_URL="http://${PAYROLL_IP}:2031/payroll/v1";;
            "GROUP_IP") GROUP_IP="$value"; GROUP_URL="http://${GROUP_IP}:2032/group/v1";;
            "NOTIFICATIONS_IP") NOTIFICATIONS_IP="$value"; NOTIFICATIONS_URL="http://${NOTIFICATIONS_IP}:2033/notification/v1";;
            *) ;;
        esac
    done < "$file"
}

function auto-seshat {
    TOKEN=$( curl -s -X POST -H "Content-Type: application/json" \
        "$PROVISIONER_URL"'/auth/token?grant_type=password&client_id=service-runner&username=wepemnefret&password=oS/0IiAME/2unkN1momDrhAdNKOhGykYFH/mJN20' \
         | jq --raw-output '.token' )
}

function login {
    local tenant="$1"
    local username="$2"
    local password="$3"

    ACCESS_TOKEN=$( curl -s -X POST -H "Content-Type: application/json" -H "User: guest" -H "X-Tenant-Identifier: $tenant" \
       "${IDENTITY_URL}/token?grant_type=password&username=${username}&password=${password}" \
        | jq --raw-output '.accessToken' )
}

function create-application {
    local name="$1"
    local description="$2"
    local vendor="$3"
    local homepage="$4"

    curl -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" \
    --data '{ "name": "'"$name"'", "description": "'"$description"'", "vendor": "'"$vendor"'", "homepage": "'"$homepage"'" }' \
     ${PROVISIONER_URL}/applications
    echo "Created microservice: $name"
}

function get-application {
    echo ""
    echo "Microservices: "
    curl -s -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" ${PROVISIONER_URL}/applications | jq '.'
}

function delete-application {
    local service_name="$1"

    curl -X delete -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" ${PROVISIONER_URL}/applications/${service_name}
    echo "Deleted microservice: $name"
}

function create-tenant {
    local identifier="$1"
    local name="$2"
    local description="$3"
    local database_name="$4"

    curl -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" \
    --data '{
	"identifier": "'"$identifier"'",
	"name": "'"$name"'",
	"description": "'"$description"'",
	"cassandraConnectionInfo": {
		"clusterName": "'"$CASSANDRA_CLUSTER_NAME"'",
		"contactPoints": "'"$CASSANDRA_CONTACT_POINTS"'",
		"keyspace": "'"$database_name"'",
		"replicationType": "'"$CASSANDRA_REPLICATION_TYPE"'",
		"replicas": "'"$CASSANDRA_REPLICAS"'"
	},
	"databaseConnectionInfo": {
		"driverClass": "'"$POSTGRES_DRIVER_CLASS"'",
		"databaseName": "'"$database_name"'",
		"host": "'"$POSTGRES_HOST"'",
		"port": "'"$POSTGRES_PORT"'",
		"user": "'"$POSTGRES_USER"'",
		"password": "'"$POSTGRES_PWD"'"
	}}' \
    ${PROVISIONER_URL}/tenants
    echo "Created tenant: $database_name"
}

function get-tenants {
    echo ""
    echo "Tenants: "
    curl -s -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" ${PROVISIONER_URL}/tenants | jq '.'
}

function assign-identity-ms {
    local tenant="$1"

    ADMIN_PASSWORD=$( curl -s -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" \
	--data '{ "name": "'"$IDENTITY_MS_NAME"'" }' \
	${PROVISIONER_URL}/tenants/${tenant}/identityservice | jq --raw-output '.adminPassword')
    echo "Assigned identity microservice for tenant $tenant"
}

function get-tenant-services {
    local tenant="$1"

    echo ""
    echo "$tenant services: "
    curl -s -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" -H "X-Tenant-Identifier: $tenant" ${PROVISIONER_URL}/tenants/$tenant/applications | jq '.'
}

function create-scheduler-role {
    local tenant="$1"

    curl -H "Content-Type: application/json" -H "User: antony" -H "Authorization: ${ACCESS_TOKEN}" -H "X-Tenant-Identifier: $tenant" \
        --data '{
                "identifier": "scheduler",
                "permissions": [
                        {
                                "permittableEndpointGroupIdentifier": "identity__v1__app_self",
                                "allowedOperations": ["CHANGE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "portfolio__v1__khepri",
                                "allowedOperations": ["CHANGE"]
                        }
                ]
        }' \
        ${IDENTITY_URL}/roles
    echo "Created scheduler role"
}

function create-org-admin-role {
    local tenant="$1"

    curl -H "Content-Type: application/json" -H "User: antony" -H "Authorization: ${ACCESS_TOKEN}" -H "X-Tenant-Identifier: $tenant" \
        --data '{
                "identifier": "orgadmin",
                "permissions": [
                        {
                                "permittableEndpointGroupIdentifier": "office__v1__employees",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "office__v1__offices",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "identity__v1__users",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "identity__v1__roles",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "identity__v1__self",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "accounting__v1__ledger",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        },
                        {
                                "permittableEndpointGroupIdentifier": "accounting__v1__account",
                                "allowedOperations": ["READ", "CHANGE", "DELETE"]
                        }
                ]
        }' \
        ${IDENTITY_URL}/roles
    echo "Created organisation administrator role"
}

function create-user {
    local tenant="$1"
    local user="$2"
    local user_identifier="$3"
    local password="$4"
    local role="$5"

    curl -s -H "Content-Type: application/json" -H "User: $user" -H "Authorization: ${ACCESS_TOKEN}" -H "X-Tenant-Identifier: $tenant" \
        --data '{
                "identifier": "'"$user_identifier"'",
                "password": "'"$password"'",
                "role": "'"$role"'"
        }' \
        ${IDENTITY_URL}/users | jq '.'
    echo "Created user: $user_identifier"
}

function get-users {
    local tenant="$1"
    local user="$2"

    echo ""
    echo "Users: "
    curl -s -H "Content-Type: application/json" -H "User: $user" -H "Authorization: ${ACCESS_TOKEN}" -H "X-Tenant-Identifier: $tenant" ${IDENTITY_URL}/users | jq '.'
}

function update-password {
    local tenant="$1"
    local user="$2"
    local password="$3"

    curl -s -X PUT -H "Content-Type: application/json" -H "User: $user" -H "Authorization: ${ACCESS_TOKEN}" -H "X-Tenant-Identifier: $tenant" \
        --data '{
                "password": "'"$password"'"
        }' \
        ${IDENTITY_URL}/users/${user}/password | jq '.'
    echo "Updated $user password"
}

function provision-app {
    local tenant="$1"
    local service="$2"

    curl -s -X PUT -H "Content-Type: application/json" -H "User: wepemnefret" -H "Authorization: ${TOKEN}" \
	--data '[{ "name": "'"$service"'" }]' \
	${PROVISIONER_URL}/tenants/${tenant}/applications | jq '.'
    echo "Provisioned microservice, $service for tenant, $tenant"
}

function set-application-permission-enabled-for-user {
    local tenant="$1"
    local service="$2"
    local permission="$3"
    local user="$4"

    curl -s -X PUT -H "Content-Type: application/json" -H "User: $user" -H "Authorization: ${ACCESS_TOKEN}" -H "X-Tenant-Identifier: $tenant" \
	--data 'true' \
	${IDENTITY_URL}/applications/${service}/permissions/${permission}/users/${user}/enabled | jq '.'
    echo "Enabled permission, $permission for service $service"
}

init-variables
auto-seshat
create-application "$IDENTITY_MS_NAME" "" "$MS_VENDOR" "$IDENTITY_URL"
create-application "$RHYTHM_MS_NAME" "" "$MS_VENDOR" "$RHYTHM_URL"
create-application "$OFFICE_MS_NAME" "" "$MS_VENDOR" "$OFFICE_URL"
create-application "$CUSTOMER_MS_NAME" "" "$MS_VENDOR" "$CUSTOMER_URL"
create-application "$ACCOUNTING_MS_NAME" "" "$MS_VENDOR" "$LEDGER_URL"
create-application "$PORTFOLIO_MS_NAME" "" "$MS_VENDOR" "$PORTFOLIO_URL"
create-application "$DEPOSIT_MS_NAME" "" "$MS_VENDOR" "$DEPOSIT_URL"
create-application "$TELLER_MS_NAME" "" "$MS_VENDOR" "$TELLER_URL"
create-application "$REPORT_MS_NAME" "" "$MS_VENDOR" "$REPORT_URL"
create-application "$CHEQUES_MS_NAME" "" "$MS_VENDOR" "$CHEQUES_URL"
create-application "$PAYROLL_MS_NAME" "" "$MS_VENDOR" "$PAYROLL_URL"
create-application "$GROUP_MS_NAME" "" "$MS_VENDOR" "$GROUP_URL"
create-application "$NOTIFICATIONS_MS_NAME" "" "$MS_VENDOR" "$NOTIFICATIONS_URL"

#Set tenant identifier
TENANT=$1
create-tenant ${TENANT} "${TENANT}" "All in one Demo Server" ${TENANT}
assign-identity-ms ${TENANT}
login ${TENANT} "antony" $ADMIN_PASSWORD
create-scheduler-role ${TENANT}
create-user ${TENANT} "antony" "imhotep" "p4ssw0rd" "scheduler"
login ${TENANT} "imhotep" "p4ssw0rd"
update-password ${TENANT} "imhotep" "p4ssw0rd"
provision-app ${TENANT} $RHYTHM_MS_NAME
login ${TENANT} "imhotep" "p4ssw0rd"
# Rhythm is not available at the moment
# set-application-permission-enabled-for-user ${TENANT} $RHYTHM_MS_NAME "identity__v1__app_self" "imhotep"
provision-app ${TENANT} $OFFICE_MS_NAME
provision-app ${TENANT} $ACCOUNTING_MS_NAME
provision-app ${TENANT} $PORTFOLIO_MS_NAME
# Rhythm is not available at the moment
# set-application-permission-enabled-for-user ${TENANT} $RHYTHM_MS_NAME "portfolio__v1__khepri" "imhotep"
provision-app ${TENANT} $CUSTOMER_MS_NAME
provision-app ${TENANT} $DEPOSIT_MS_NAME
provision-app ${TENANT} $TELLER_MS_NAME
provision-app ${TENANT} $REPORT_MS_NAME
provision-app ${TENANT} $CHEQUES_MS_NAME
provision-app ${TENANT} $PAYROLL_MS_NAME
provision-app ${TENANT} $GROUP_MS_NAME
provision-app ${TENANT} $NOTIFICATIONS_MS_NAME
login ${TENANT} "antony" $ADMIN_PASSWORD
create-org-admin-role ${TENANT}
create-user ${TENANT} "antony" "operator" "init1@l23" "orgadmin"
login ${TENANT} "operator" "init1@l"

echo "COMPLETED PROVISIONING PROCESS."