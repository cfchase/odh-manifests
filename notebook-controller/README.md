# Notebook Controller

Deploy the
[Kubeflow](https://github.com/opendatahub-io/kubeflow/tree/master/components/notebook-controller)
and
[Openshift](https://github.com/opendatahub-io/kubeflow/tree/master/components/openshift-notebook-controller)
Notebook controllers using the **Opendatahub** operator.

## Deployment

Add the following configuration to your `KfDef` object to install the
`notebook-controller`:

```yaml
...
  - kustomizeConfig:
    repoRef:
      name: manifests
      path: notebook-controller
    name: notebook-controller
```

## Creating Notebooks

Create a notebook object with the image and other parameters such as the
environment variables, resource limits, tolerations, etc:

```yaml
cat <<EOF | oc apply -f -
---
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: s2i-minimal-notebook
spec:
  template:
    spec:
      containers:
        - name: s2i-minimal-notebook
          image: quay.io/thoth-station/s2i-minimal-notebook:v0.2.2
          imagePullPolicy: Always
          env:
            - name: NOTEBOOK_ARGS
              value: "--NotebookApp.token='' --NotebookApp.password=''"
EOF
```

Open the notebook URL in your browser:

```shell
firefox "$(oc get route s2i-minimal-notebook -o jsonpath='{.spec.host}')"
```

Find more examples in the [notebook tests folder](../tests/resources/notebook-controller/).

## Updating Manifests

The upstream code must be adapted before being deployed with the Opendatahub
operator. This is done through two different scripts:

- Script `gen_kubeflow_manifests.sh` for the Kubeflow Notebook Controller.
- Script `gen_openshift_manifests.sh` for the Openshift Notebook Controller.

### Requirements

To update the notebook controller manifests, your environment must have the
following:

- [yq](https://github.com/mikefarah/yq#install) version 4.21.1+.
- [kustomize](https://sigs.k8s.io/kustomize/docs/INSTALL.md) version 3.2.0+

### Updating KFNBC manifests

Use the `gen_kubeflow_manifests.sh` to update the Kubeflow Notebook Controller
manifests.

#### Variables

This script can be configured by modifying the following variables:

| **Name**        | **Description**                                     | **Example**                                      |
| --------------- | --------------------------------------------------- | ------------------------------------------------ |
| ctrl_dir        | Manifests output directory                          | kubeflow-notebook-controller                     |
| ctrl_repository | Kubeflow upstream repository                        | github.com/opendatahub-io/kubeflow               |
| ctrl_branch     | Kubeflow repository branch to get cloned            | master                                           |
| ctrl_image      | Notebook controller container image                 | quay.io/opendatahub/kubeflow-notebook-controller |
| ctrl_tag        | Notebook controller container image tag             | latest                                           |
| ctrl_namespace  | Namespace where the notebook controller is deployed | opendatahub                                      |

#### Script

Run the script to update the Kubeflow Notebook Controller manifests:

```shell
./gen_kubeflow_manifests.sh
```

### Updating OCPNBC manifests

Use the `gen_openshift_manifests.sh` to update the Openshift Notebook Controller
manifests.

#### Variables

This script can be configured by modifying the following variables:

| **Name**        | **Description**                                     | **Example**                                       |
| --------------- | --------------------------------------------------- | ------------------------------------------------- |
| ctrl_dir        | Manifests output directory                          | openshift-notebook-controller                     |
| ctrl_repository | Kubeflow upstream repository                        | github.com/opendatahub-io/kubeflow                |
| ctrl_branch     | Kubeflow repository branch to get cloned            | master                                            |
| ctrl_image      | Notebook controller container image                 | quay.io/opendatahub/openshift-notebook-controller |
| ctrl_tag        | Notebook controller container image tag             | latest                                            |
| ctrl_namespace  | Namespace where the notebook controller is deployed | opendatahub                                       |

#### Script

Run the script to update the Openshift Notebook Controller manifests:

```shell
./gen_openshift_manifests.sh
```
