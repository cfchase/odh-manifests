# Notebook controller

Deploy the [Kubeflow Notebook Controller](https://github.com/kubeflow/kubeflow/tree/master/components/notebook-controller) in Openshift using the **Opendatahub** operator.

## Deployment

Add the following configuration to your `KfDef` object to install the
`notebook-controller`:

```yaml
---
- kustomizeConfig:
  repoRef:
    name: manifests
    path: notebook-controller/controller
  name: notebook-controller
```

## Updating Manifests

The upstream code must be adapted before being deployed in Openshift. This is
done through the `gen_controller_manifests.sh` script.

### Requirements

To update the notebook controller manifests, your environment must have the
following:

- [yq](https://github.com/mikefarah/yq#install) version 4.21.1+.
- [kustomize](https://sigs.k8s.io/kustomize/docs/INSTALL.md) version 3.1.0+

### Variables

This script can be configured by modifying the following variables:

| **Name**      | **Description**                                     | **Example**                                      |
| ------------- | --------------------------------------------------- | ------------------------------------------------ |
| kf_repository | Kubeflow upstream repository                        | github.com/kubeflow                              |
| kf_branch     | Kubeflow repository branch to get cloned            | master                                           |
| kf_image      | Notebook controller container image                 | quay.io/opendatahub/kubeflow-notebook-controller |
| kf_tag        | Tag of the previous container image                 | latest                                           |
| kf_namespace  | Namespace where the notebook controller is deployed | opendatahub                                      |

### Script

Run the script to update the notebook controller manifests:

```shell
./gen_controller_manifests.sh
```

## Creating Notebooks

Create a notebook object with the notebook image and other parameters like
environment variables, resource limits, etc:

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

Create an Openshift route to expose the notebook in the Openshift ingress
controller:

```yaml
cat <<EOF | oc apply -f -
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: s2i-minimal-notebook
spec:
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
  to:
    kind: Service
    name: s2i-minimal-notebook
    weight: 100
  port:
    targetPort: http-s2i-minimal-notebook
  wildcardPolicy: None
EOF
```

Open the notebook URL in your browser:

```shell
firefox "$(oc get route s2i-minimal-notebook -o jsonpath='{.spec.host}')"
```

Find more examples in the [notebook tests folder](../tests/resources/notebook-controller/).
