#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"
. "${CI_SCRIPTS_DIR}"/test/test_utils.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# PDO-12226: the PEB pipeline no longer kubectl-applies the microservice uber
# yamls; the per-microservice ArgoCD Applications (ping-cloud-all-cdes-per-app)
# sync the charts from the pushed CSR. Verify every per-app Application that
# backs a p1as-* CSR directory has actually reached Synced.
testMicroserviceAppsSynced() {
  local base_app="${CLUSTER_NAME}-${REGION}-${ENV_TYPE}"
  local app_list
  app_list=($(find "${PROJECT_DIR}" -type d -name "p1as-*" -mindepth 1 -exec basename {} \;))

  for app_suffix in "${app_list[@]}"; do
    local app="${base_app}-${app_suffix}"
    local sync_status
    sync_status=$(kubectl get application "${app}" -n argocd \
      -o jsonpath='{.status.sync.status}' 2>/dev/null)
    assertEquals "Application ${app} not Synced (status=${sync_status:-<missing>})" "Synced" "${sync_status}"
  done
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run.  For integration
# tests, you need this line.
shift $#

# load shunit
. ${SHUNIT_PATH}
