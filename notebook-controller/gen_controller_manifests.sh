#!/bin/bash
set -eu -o pipefail

kf_repository="github.com/samuelvl/kubeflow"
kf_branch="notebooks-k8s-1.22"
kf_image="quay.io/samuvl/kubeflow-notebook-controller"
kf_tag="v1.5.0-rc.0-16-g88fca620"
kf_namespace="opendatahub"

cleanup() {
    echo -n ".. Removing the temporary clone"
    rm -rf ${tmp_dir}
    echo -e "\r ✓ "
}

trap cleanup EXIT

echo -n ".. Temporarily cloning the upstream repo"
tmp_dir=$(mktemp -d)
kf_controller_dir=${tmp_dir}/components/notebook-controller
git clone \
    -c advice.detachedHead=false --quiet --depth 1 \
    --branch ${kf_branch} --single-branch \
    https://${kf_repository}.git  ${tmp_dir} > /dev/null
echo -e "\r ✓"

echo -n ".. Reinitializing thecontroller folder structure"
rm -rf controller
mkdir controller
echo -e "\r ✓"

echo -n ".. Copying controller/base folder"
cp -r "${kf_controller_dir}/config/base" controller/base
echo -e "\r ✓"

echo -n "   .. Updating controller image"
sed -i 's,newName:.*,newName: '${kf_image}',g' controller/base/kustomization.yaml
sed -i 's,newTag:.*,newTag: '${kf_tag}',g' controller/base/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying controller/default folder"
cp -r "${kf_controller_dir}/config/default" controller/default
echo -e "\r ✓"

echo -n "   .. Adding opendatahub labels to notebook controller objects"
yq -i '.commonLabels += {"component.opendatahub.io/name":"notebook-controller"}' controller/default/kustomization.yaml
yq -i '.commonLabels += {"opendatahub.io/component":"true"}' controller/default/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Updating controller namespace to opendatahub"
sed -i 's,namespace:.*,namespace: '${kf_namespace}',g' controller/default/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Enabling CRD installation"
sed -i 's/#- \.\.\/crd/- \.\.\/crd/g' controller/default/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying controller/crd folder"
cp -r "${kf_controller_dir}/config/crd" controller/crd
echo -e "\r ✓"

echo -n "   .. Removing CRD description to reduce size"
yq -i 'del(.. | select(has("description")).description)' controller/crd/bases/kubeflow.org_notebooks.yaml
echo -e "\r    ✓"

echo -n "   .. Removing CRD unused kustomize patching"
yq -i 'with_entries(select(.key | test("resources")))' controller/crd/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying controller/rbac folder"
cp -r "${kf_controller_dir}/config/rbac" controller/rbac
echo -e "\r ✓"

echo -n "   .. Disable leader election RBAC"
sed -i 's,^\- leader_election_role.*,#&,' controller/rbac/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying controller/manager folder"
cp -r "${kf_controller_dir}/config/manager" controller/manager
echo -e "\r ✓"

echo -n "   .. Disabling kustomize NameSuffixHash property"
yq -i '.generatorOptions.disableNameSuffixHash = true' controller/manager/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Disabling istio deployment"
sed -i 's,USE_ISTIO=.*,USE_ISTIO=false,g' controller/manager/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Disabling fsGroup in the PSC"
yq -i '.configMapGenerator.[0].literals += "ADD_FSGROUP=false"' controller/manager/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Adding ADD_FSGROUP environment variable"
yq -i '.spec.template.spec.containers[0].env += {"name":"ADD_FSGROUP","valueFrom":{"configMapKeyRef":{"name":"config","key":"ADD_FSGROUP"}}}' controller/manager/manager.yaml
echo -e "\r    ✓"

echo -n "   .. Removing dedicated namespace"
yq -i 'select(.kind != "Namespace")' controller/manager/manager.yaml
echo -e "\r    ✓"

echo -n "   .. Adding metrics port to the manager service"
yq -i '.spec.ports = [{"name":"nbc-metrics","port":8080}]' controller/manager/service.yaml
echo -e "\r    ✓"
