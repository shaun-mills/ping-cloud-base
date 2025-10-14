#!/bin/bash

# Ensure heartbeat public endpoints return null object

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  # Wait for DNS resolution to be available
  pingaccess_ingress="$(kubectl get ingress pingaccess-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
  log "pingaccess-ingress: ${pingaccess_ingress}"
  dns_check=$(curl -k -s https://${pingaccess_ingress})
  exit_code=$?
  while [ ${exit_code} == 6 ]; do
    log "Trying DNS resolution for pingaccess-ingress..."
    dns_check=$(curl -k -s https://${pingaccess_ingress})
    exit_code=$?
    sleep 10
  done
}

# PingAccess heartbeat test cases

testHeartBeatPARegular() {
  # Regular request
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/heartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat http response code should be 200" "200" "${http_code}"
}

testHeartBeatPAEncodedPeriod() {
  # Encoded '.'
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/heartbeat%2Eping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat http response code should be 200" "200" "${http_code}"
}

testHeartBeatPAPathTraversal() {
  # Path traversal
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/something/../heartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat http response code should be 200" "200" "${http_code}"
}

testHeartBeatPAEncodedSlash() {
  # Encoded '/'
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa%2Fheartbeat.ping")
  body=${response%|*}
  http_code=${response#*|}
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${body}"
  assertEquals "PingAccess heartbeat http response code should be 200" "200" "${http_code}"
}

testHeartBeatPAPathParameterObfuscation() {
  # Path Parameter Obfuscation (Matrix URIs)
  response=$(curl -k -s -w "|%{http_code}" "https://${pingaccess_ingress}/pa/heartbeat.ping;junkparam=blah")
  body=${response%|*}
  http_code=${response#*|}
  # PingAccess returns 404 Not Found with path parameter obfuscation
  assertTrue "PingAccess heartbeat response should contain 'Not Found'" "echo '${body}' | grep -q 'Not Found'"
  assertEquals "PingAccess heartbeat http response code should be 404" "404" "${http_code}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}