#!/bin/bash

source $TEST_DIR/common

MY_DIR=$(readlink -f `dirname "${BASH_SOURCE[0]}"`)

source ${MY_DIR}/../util

os::test::junit::declare_suite_start "$MY_SCRIPT"

function test_grafana_functionality() {
    header "Testing ODH Grafana functionality"
    grafana_user="root"
    grafana_pass="secret"

    # Make sure that route is active and that the app responds as expected
    os::cmd::try_until_text "oc get route grafana-route -o jsonpath='{$.status.ingress[0].conditions[0].type}'" "Admitted" ${odhdefaulttimeout} ${odhdefaultinterval}
    uiroute=$(oc get route grafana-route -o jsonpath="{$.status.ingress[0].host}")
    os::cmd::try_until_text "curl -sk https://${uiroute}" "Grafana" ${odhdefaulttimeout} ${odhdefaultinterval}

    # Dashboards
    dashboard_names=("Kafka%20Overview" "Jupyterhub%20SLI/SLO" "JupyterHub%20Usage" "Argo%20Workflow")
    dashboard_ids=("kafka-overview" "jupyterhub-sli-slo" "jupyterhub-usage" "argo-workflow")

    ## Use the search api make sure that our dashboards are indeed there
    for index in "${!dashboard_names[@]}"; do
        dashboard_name=${dashboard_names[$index]}
        dashboard_id=${dashboard_ids[$index]}
        os::cmd::try_until_text "curl -sk https://${uiroute}/api/search?query=${dashboard_name} |\
            jq '.[].url'" "${dashboard_id}" ${odhdefaulttimeout} ${odhdefaultinterval}
        dashboard_url=$(curl -sk https://${uiroute}/api/search?query=${dashboard_name} | jq -r '.[].url')
        os::cmd::expect_success "curl -sk https://${uiroute}${dashboard_url}"
    done

    # Datasources
    datasources=("opendatahub")

    ## Use the search api make sure that our datasources are indeed there
    for index in "${!datasources[@]}"; do
        os::cmd::try_until_text "curl -sk -u ${grafana_user}:${grafana_pass} \
            https://${uiroute}/api/datasources | jq -r '.[].name'" \
                ${datasources[$index]} ${odhdefaulttimeout} ${odhdefaultinterval} 2>&1 |\
                    sed 's/'${grafana_user}'/****/g' | sed 's/'${grafana_pass}'/*****/g'
    done
}

function test_grafana() {
    header "Testing ODH Grafana installation"

    # Dashboards
    dashboards=("odh-kafka" "odh-jupyterhub-sli" "odh-jupyterhub-usage" "odh-argo")

    # Verify Grafana operator is deployed and running
    os::cmd::expect_success "oc project ${ODHPROJECT}"
    os::cmd::try_until_text "oc get deployment grafana-operator-controller-manager" "grafana-operator-controller-manager" ${odhdefaulttimeout} ${odhdefaultinterval}
    os::cmd::try_until_text "oc rollout status deployment/grafana-operator-controller-manager -w=false" "successfully rolled out" $odhdefaulttimeout $odhdefaultinterval
    os::cmd::try_until_text "oc get pods -l control-plane=controller-manager --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}'" "grafana-operator-controller-manager" ${odhdefaulttimeout} ${odhdefaultinterval}

    # Verify Grafana instance is deployed and running
    os::cmd::try_until_text "oc get grafana" "odh-grafana" ${odhdefaulttimeout} ${odhdefaultinterval}
    os::cmd::try_until_text "oc get pods -l app=grafana --field-selector='status.phase=Running' -o jsonpath='{$.items[*].metadata.name}'" "grafana-deployment" ${odhdefaulttimeout} ${odhdefaultinterval}
    runningpods=($(oc get pods -l app=grafana --field-selector="status.phase=Running" -o jsonpath="{$.items[*].metadata.name}"))
    os::cmd::expect_success_and_text "echo ${#runningpods[@]}" "1"

    # Verify Grafana dashboards exist
    for dashboard in "${dashboards[@]}"; do
        os::cmd::try_until_text "oc get grafanadashboard" "${dashboard}" ${odhdefaulttimeout} ${odhdefaultinterval}
    done

    # Verify Grafana datasource exist
    os::cmd::try_until_text "oc get grafanadatasource" "odh-datasource" ${odhdefaulttimeout} ${odhdefaultinterval}
}

test_grafana
test_grafana_functionality

os::test::junit::declare_suite_end
