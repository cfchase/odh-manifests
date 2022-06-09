# ODH Notebook Controller

The ODH Notebook Controller will watch the **Kubeflow Notebook** custom resource
events to extend the Kubeflow notebook controller behavior with the following
capabilities:

- Openshift ingress controller integration.
- Openshift OAuth sidecar injection.

![ODH Notebook Controller OAuth injection
diagram](./assets/odh-notebook-controller-oauth-diagram.png)

## Deployment

Add the following configuration to your `KfDef` object to install the
`odh-notebook-controller`:

```yaml
...
  - kustomizeConfig:
    repoRef:
      name: manifests
      path: odh-notebook-controller
    name: odh-notebook-controller
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
  name: thoth-minimal-oauth-notebook
  annotations:
    notebooks.opendatahub.io/inject-oauth: "true"
spec:
  template:
    spec:
      containers:
        - name: thoth-minimal-oauth-notebook
          image: quay.io/thoth-station/s2i-minimal-notebook:v0.2.2
          imagePullPolicy: Always
          workingDir: /opt/app-root/src
          env:
            - name: JUPYTER_NOTEBOOK_PORT
              value: "8888"
            - name: NOTEBOOK_ARGS
              value: "--NotebookApp.token='' --NotebookApp.password=''"
          ports:
            - name: notebook-port
              containerPort: 8888
              protocol: TCP
          resources:
            requests:
              cpu: "1"
              memory: 1Gi
            limits:
              cpu: "1"
              memory: 1Gi
          livenessProbe:
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 1
            successThreshold: 1
            failureThreshold: 3
            httpGet:
              scheme: HTTP
              path: /api
              port: notebook-port
EOF
```

Open the notebook URL in your browser:

```shell
firefox "$(oc get route thoth-minimal-oauth-notebook -o jsonpath='{.spec.host}')"
```

Find more examples in the [notebook tests folder](../tests/resources/notebook-controller/).

## Updating Manifests

The upstream code must be adapted before being deployed with the Opendatahub
operator. This is done through two different scripts:

- Script `gen_kubeflow_manifests.sh` for the Kubeflow Notebook Controller.
- Script `gen_odh_manifests.sh` for the ODH Notebook Controller.

### Requirements

To update the notebook controller manifests, your environment must have the
following:

- [yq](https://github.com/mikefarah/yq#install) version 4.21.1+.
- [kustomize](https://sigs.k8s.io/kustomize/docs/INSTALL.md) version 3.2.0+

### Updating Kubeflow manifests

Use the `gen_kubeflow_manifests.sh` to update the Kubeflow Notebook Controller
manifests.

#### Variables

This script can be configured by modifying the following variables:

| **Name**        | **Description**                                     | **Example**                                      |
| --------------- | --------------------------------------------------- | ------------------------------------------------ |
| ctrl_dir        | Manifests output directory                          | kf-notebook-controller                           |
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

### Updating ODH manifests

Use the `gen_odh_manifests.sh` to update the ODH Notebook Controller manifests.

#### Variables

This script can be configured by modifying the following variables:

| **Name**        | **Description**                                     | **Example**                                 |
| --------------- | --------------------------------------------------- | ------------------------------------------- |
| ctrl_dir        | Manifests output directory                          | odh-notebook-controller                     |
| ctrl_repository | Kubeflow upstream repository                        | github.com/opendatahub-io/kubeflow          |
| ctrl_branch     | Kubeflow repository branch to get cloned            | master                                      |
| ctrl_image      | Notebook controller container image                 | quay.io/opendatahub/odh-notebook-controller |
| ctrl_tag        | Notebook controller container image tag             | latest                                      |
| ctrl_namespace  | Namespace where the notebook controller is deployed | opendatahub                                 |

#### Script

Run the script to update the ODH Notebook Controller manifests:

```shell
./gen_odh_manifests.sh
```
