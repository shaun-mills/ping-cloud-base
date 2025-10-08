#!/bin/bash

# Ensure pingaccess and pingfederate heartbeat public endpoints return null object

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

oneTimeSetUp() {
  # Wait for DNS resolution to be available
  pingfederate_ingress="$(kubectl get ingress pingfederate-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
  log "pingfederate-ingress: ${pingfederate_ingress}"
  dns_check=$(curl -k https://${pingfederate_ingress})
  exit_code=$?
  while [ ${exit_code} == 6 ]; do
    log "Trying DNS resolution for pingfederate-ingress..."
    dns_check=$(curl -k https://${pingfederate_ingress})
    exit_code=$?
    sleep 10
  done

  pingaccess_ingress="$(kubectl get ingress pingaccess-ingress -n ${PING_CLOUD_NAMESPACE} -o jsonpath='{.spec.tls[*].hosts[0]}')"
  log "pingaccess-ingress: ${pingaccess_ingress}"
  dns_check=$(curl -k https://${pingaccess_ingress})
  exit_code=$?
  while [ ${exit_code} == 6 ]; do
    log "Trying DNS resolution for pingaccess-ingress..."
    dns_check=$(curl -k https://${pingaccess_ingress})
    exit_code=$?
    sleep 10
  done
}

# PingAccess heartbeat test cases

testHeartBeatPARegular() {
  # Regular request
  response=$(curl -k "https://${pingaccess_ingress}/pa/heartbeat.ping")
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPAEncodedPeriod() {
  # Encoded '.'
  response=$(curl -k "https://${pingaccess_ingress}/pa/heartbeat%2Eping")
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPAPathTraversal() {
  # Path traversal
  response=$(curl -k "https://${pingaccess_ingress}/pa/something/../heartbeat.ping")
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPAEncodedSlash() {
  # Encoded '/'
  response=$(curl -k "https://${pingaccess_ingress}/pa%2Fheartbeat.ping")
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPAPathParameterObfuscation() {
  # Path Parameter Obfuscation (Matrix URIs)
  response=$(curl -k "https://${pingaccess_ingress}/pa/heartbeat.ping;junkparam=blah")
  assertEquals "PingAccess heartbeat response code was not empty object" "{}" "${response}"
}

# PingFederate heartbeat test cases

testHeartBeatPFRegular() {
  # Regular request
  response=$(curl -k "https://${pingfederate_ingress}/pf/heartbeat.ping")
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPFEncodedPeriod() {
  # Encoded '.'
  response=$(curl -k "https://${pingfederate_ingress}/pf/heartbeat%2Eping")
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPFPathTraversal() {
  # Path traversal
  response=$(curl -k "https://${pingfederate_ingress}/pf/something/../heartbeat.ping")
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPFEncodedSlash() {
  # Encoded '/'
  response=$(curl -k "https://${pingfederate_ingress}/pf%2Fheartbeat.ping")
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${response}"
}

testHeartBeatPFPathParameterObfuscation() {
  # Path Parameter Obfuscation (Matrix URIs)
  response=$(curl -k "https://${pingfederate_ingress}/pf/heartbeat.ping;junkparam=blah")
  assertEquals "PingFederate heartbeat response code was not empty object" "{}" "${response}"
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}