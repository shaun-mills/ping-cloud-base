#!/bin/bash

# Ensure pingaccess and pingfederate heartbeat public endpoints return null object

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# oneTimeSetUp() {
#   # Wait for DNS resolution to be available
#   mock_metadata_ingress_lb="$(kubectl get ingress mock-metadata-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')"
#   dns_check=$(curl -k -v https://${mock_metadata_ingress_lb})
#   exit_code=$?
#   while [ ${exit_code} == 6 ]; do
#     log "Trying DNS resolution for mock-metadata-ingress..."
#     dns_check=$(curl -k -v https://${mock_metadata_ingress_lb})
#     exit_code=$?
#     sleep 10
#   done

# }

heartBeatTestCases() {
    # Test cases for heartbeat endpoint
    local heartbeat_endpoint=$1
    local product=$2

    # Regular request
    curl -k -X GET "https://${heartbeat_endpoint}/${product}/heartbeat.ping"

    # Encoded '.'
    curl -k -X GET "https://${heartbeat_endpoint}/${product}/heartbeat%2Eping"

    # path traversal
    curl -k -X GET "https://${heartbeat_endpoint}//${product}/something/../heartbeat.ping"

    # extra /
    curl -k -X GET "https://${heartbeat_endpoint}/${product}//heartbeat.ping"

    # encoded slash
    curl -k -X GET "https://${heartbeat_endpoint}/${product}%2Fheartbeat.ping"
}

# PingAccess heartbeat test cases
testHeartBeatPA() {
    local heartbeat_endpoint="$(kubectl get ingress pingaccess-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
    log "Testing PingAccess heartbeat endpoint"
    log "PingAccess heartbeat endpoint: ${heartbeat_endpoint}"

    response=$(heartBeatTestCases "${heartbeat_endpoint}" "pa")
    log "PingAccess heartbeat response: ${response}"
    assertEquals "PingAccess heartbeat response code was not empty object" "{}{}{}{}{}" "${response}"
}

# PingFederate heartbeat test cases
testHeartBeatPF() {
    local heartbeat_endpoint="$(kubectl get ingress pingfederate-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
    log "Testing PingFederate heartbeat endpoint"
    log "PingFederate heartbeat endpoint: ${heartbeat_endpoint}"

    response=$(heartBeatTestCases "${heartbeat_endpoint}" "pf")
    log "PingFederate heartbeat response: ${response}"
    assertEquals "PingFederate heartbeat response code was not empty object" "{}{}{}{}{}" "${response}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}