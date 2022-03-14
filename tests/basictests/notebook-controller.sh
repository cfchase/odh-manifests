#!/bin/bash

source $TEST_DIR/common

MY_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)

source ${MY_DIR}/../util

NOTEBOOKS_DIR="${MY_DIR}/../resources/notebook-controller/notebooks"

os::test::junit::declare_suite_start "$MY_SCRIPT"

function test_notebook_controller() {
    header "Testing Notebook Controller installation"
    os::cmd::expect_success "oc project ${ODHPROJECT}"
    # Verify the notebook controller is running
    os::cmd::try_until_text "oc get deployment/notebook-controller-deployment" "notebook-controller-deployment" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc rollout status deployment/notebook-controller-deployment -w=false" "successfully rolled out" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pods -l app=notebook-controller --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}'" "notebook-controller-deployment" ${odhdefaulttimeout} ${odhdefaultinterval}
    # Verify the number of pods runnings is 1
    runningpods=($(oc get pods -l app=notebook-controller --field-selector="status.phase=Running" -o jsonpath="{$.items[*].metadata.name}"))
    os::cmd::expect_success_and_text "echo ${#runningpods[@]}" "1"

    # Test the creation and deletion of notebooks in the NOTEBOOKS_DIR folder
    for notebook_path in ${NOTEBOOKS_DIR}/*.yaml; do
        notebook_name="$(basename "${notebook_path}" .yaml)"
        test_notebook_creation ${notebook_path} ${notebook_name}
        test_notebook_deletion ${notebook_path} ${notebook_name}
    done
}

function test_notebook_creation() {
    header "Creating ${2} notebook"
    local notebook_path=${1}
    local notebook_name=${2}
    # Create notebook resources
    os::cmd::expect_success "oc apply -f ${notebook_path}"
    # Verify notebook CR exists
    os::cmd::try_until_not_text "oc get notebook ${notebook_name}" "not found" $odhdefaulttimeout $odhdefaultinterval
    # Verify notebook STS is created
    os::cmd::try_until_text "oc get statefulset ${notebook_name}" "${notebook_name}" $odhdefaulttimeout $odhdefaultinterval
    # Verify notebook Pod is running
    os::cmd::try_until_text "oc get pods -l notebook-name=${notebook_name} --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}'" "${notebook_name}-0" $odhdefaulttimeout $odhdefaultinterval
    # Verify notebook is reachable trough the Openshift Route
    os::cmd::try_until_text "oc get route ${notebook_name}" "${notebook_name}" $odhdefaulttimeout $odhdefaultinterval
    local notebook_host="$(oc get route ${notebook_name} -o jsonpath='{.spec.host}')"
    os::cmd::try_until_text "curl -k -s -o /dev/null -w \"%{http_code}\" https://${notebook_host}/api" "200" $odhdefaulttimeout $odhdefaultinterval
}

function test_notebook_deletion() {
    header "Cleaning up ${2} notebook"
    local notebook_path=${1}
    local notebook_name=${2}
    # Delete notebook resources
    os::cmd::expect_success "oc delete -f ${notebook_path}"
    # Verify the notebook CR does not exist anymore
    os::cmd::try_until_text "oc get notebook ${notebook_name}" "not found" $odhdefaulttimeout $odhdefaultinterval
    # Verify the notebook STS is deleted
    os::cmd::try_until_text "oc get statefulset ${notebook_name}" "not found" $odhdefaulttimeout $odhdefaultinterval
    # Verify the notebook Pod is not running anymore
    os::cmd::try_until_text "oc get pods -l notebook-name=${notebook_name}" "No resources found" $odhdefaulttimeout $odhdefaultinterval
    # Verify the notebook Route is deleted
    os::cmd::try_until_text "oc get route ${notebook_name}" "not found" $odhdefaulttimeout $odhdefaultinterval
}

function gather_notebook_controller_logs() {
    echo "Saving the logs from the notebook-controller pod in the artifacts directory"
    oc logs -l app=notebook-controller --all-containers --tail=-1 -n ${ODHPROJECT} \
        > ${ARTIFACT_DIR}/notebook-controller.log 2> /dev/null || echo "No logs for ${ODHPROJECT}/notebook-controller"
}

test_notebook_controller

os::test::junit::declare_suite_end

gather_notebook_controller_logs
