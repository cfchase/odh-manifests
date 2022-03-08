#!/bin/bash
set -eu -o pipefail

ctrl_dir="kubeflow-notebook-controller"
ctrl_repository="github.com/samuelvl/kubeflow"
ctrl_branch="notebooks-k8s-1.22"
ctrl_image="quay.io/samuvl/kubeflow-notebook-controller"
ctrl_tag="v1.5.0-rc.0-16-g88fca620"
ctrl_namespace="opendatahub"

cleanup() {
    echo -n ".. Removing the temporary clone"
    rm -rf ${tmp_dir}
    echo -e "\r ✓ "
}

trap cleanup EXIT

echo -n ".. Temporarily cloning the upstream repo"
tmp_dir=$(mktemp -d)
ctrl_controller_dir=${tmp_dir}/components/notebook-controller
git clone \
    -c advice.detachedHead=false --quiet --depth 1 \
    --branch ${ctrl_branch} --single-branch \
    https://${ctrl_repository}.git  ${tmp_dir} > /dev/null
echo -e "\r ✓"

echo -n ".. Reinitializing the controller folder structure"
rm -rf ${ctrl_dir}
mkdir ${ctrl_dir}
echo -e "\r ✓"

echo -n ".. Copying controller/base folder"
cp -r "${ctrl_controller_dir}/config/base" ${ctrl_dir}/base
echo -e "\r ✓"

echo -n "   .. Updating controller image"
sed -i 's,newName:.*,newName: '${ctrl_image}',g' ${ctrl_dir}/base/kustomization.yaml
sed -i 's,newTag:.*,newTag: '${ctrl_tag}',g' ${ctrl_dir}/base/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying controller/default folder"
cp -r "${ctrl_controller_dir}/config/default" ${ctrl_dir}/default
echo -e "\r ✓"

echo -n "   .. Adding opendatahub labels to the controller objects"
yq -i '.commonLabels += {"component.opendatahub.io/name":"kubeflow-notebook-controller"}' ${ctrl_dir}/default/kustomization.yaml
yq -i '.commonLabels += {"opendatahub.io/component":"true"}' ${ctrl_dir}/default/kustomization.yaml
yq -i '.commonLabels += {"app.kubernetes.io/part-of":"notebook-controller"}' ${ctrl_dir}/default/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Updating controller namespace to opendatahub"
sed -i 's,namespace:.*,namespace: '${ctrl_namespace}',g' ${ctrl_dir}/default/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Enabling CRD installation"
sed -i 's/#- \.\.\/crd/- \.\.\/crd/g' ${ctrl_dir}/default/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying CRDs folder"
cp -r "${ctrl_controller_dir}/config/crd" ${ctrl_dir}/crd
echo -e "\r ✓"

echo -n "   .. Removing CRD description to reduce size"
yq -i 'del(.. | select(has("description")).description)' ${ctrl_dir}/crd/bases/kubeflow.org_notebooks.yaml
echo -e "\r    ✓"

echo -n "   .. Removing CRD unused kustomize patching"
yq -i 'with_entries(select(.key | test("resources")))' ${ctrl_dir}/crd/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying RBAC folder"
cp -r "${ctrl_controller_dir}/config/rbac" ${ctrl_dir}/rbac
echo -e "\r ✓"

echo -n "   .. Disable leader election RBAC"
sed -i 's,^\- leader_election_role.*,#&,' ${ctrl_dir}/rbac/kustomization.yaml
echo -e "\r    ✓"

echo -n ".. Copying manager deployment folder"
cp -r "${ctrl_controller_dir}/config/manager" ${ctrl_dir}/manager
echo -e "\r ✓"

echo -n "   .. Disabling kustomize NameSuffixHash property"
yq -i '.generatorOptions.disableNameSuffixHash = true' ${ctrl_dir}/manager/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Disabling istio deployment"
sed -i 's,USE_ISTIO=.*,USE_ISTIO=false,g' ${ctrl_dir}/manager/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Disabling fsGroup in the PSC"
yq -i '.configMapGenerator.[0].literals += "ADD_FSGROUP=false"' ${ctrl_dir}/manager/kustomization.yaml
echo -e "\r    ✓"

echo -n "   .. Adding ADD_FSGROUP environment variable"
yq -i '.spec.template.spec.containers[0].env += {"name":"ADD_FSGROUP","valueFrom":{"configMapKeyRef":{"name":"config","key":"ADD_FSGROUP"}}}' ${ctrl_dir}/manager/manager.yaml
echo -e "\r    ✓"

echo -n "   .. Adding CPU and memory resources"
yq -i '.spec.template.spec.containers[0].resources += {"requests":{"cpu":"1","memory":"512Mi"},"limits":{"cpu":"1","memory":"512Mi"}}' ${ctrl_dir}/manager/manager.yaml
echo -e "\r    ✓"

echo -n "   .. Removing dedicated namespace"
yq -i 'select(.kind != "Namespace")' ${ctrl_dir}/manager/manager.yaml
echo -e "\r    ✓"

echo -n "   .. Adding metrics port to the manager service"
yq -i '.spec.ports = [{"name":"nbc-metrics","port":8080}]' ${ctrl_dir}/manager/service.yaml
echo -e "\r    ✓"
