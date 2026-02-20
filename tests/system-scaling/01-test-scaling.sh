#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}/common.sh" "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi


scaleUpPDReplicas() {
  log "Scaling up pingdirectory replicas to 3"
  kubectl scale --replicas=3 statefulset/pingdirectory -n "${PING_CLOUD_NAMESPACE}"
}

scaleDownPDReplicas() {
  log "Scaling down pingdirectory replicas to 2"
  kubectl scale --replicas=2 statefulset/pingdirectory -n "${PING_CLOUD_NAMESPACE}"
}

testSystemScaling() {
  local start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Determine if we are testing cluster-autoscaler or karpenter
  if [[ "${CLUSTER_AUTOSCALER_ENABLED}" == "true" ]]; then
    log "Testing cluster-autoscaler scaling"

  else
    log "Testing karpenter scaling"

    scaleUpPDReplicas

    # Wait for Karpenter to create the new node claim
    sleep 300

    # Get the new node claim created after scaling up if creation timestamp is greater than the start time of the test
    pdonly_node_claim_name=$(kubectl get nodeclaims -l karpenter.sh/nodepool=pd-only -n "${PING_CLOUD_NAMESPACE}" -o json | jq -r --arg start "$start_time" '.items[] | select(.metadata.creationTimestamp > $start) | .metadata.name' | head -n 1)

    assertNotNull "Karpenter failed to create a pd-onlyNodeClaim for the new pingdirectory replica" "${pdonly_node_claim_name}"

    scaleDownPDReplicas

  fi

}



# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}