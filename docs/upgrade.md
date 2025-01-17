# Upgrade

# Command line

You can also use the `rancherd upgrade` command on a `server` node to automatically 
upgrade RancherOS, Rancher, and/or Kubernetes.

# Kubernetes API

All components in RancherOS are managed using Kubernetes. Below is how
to use Kubernetes approaches to upgrade the components.

## RancherOS

RancherOS is upgraded with the RancherOS operator. Refer to the
[RancherOS Operator](https://github.com/rancher-sandbox/rancheros-operator/blob/main/README.md) documentation for complete information, but the
TL;DR is

```bash
kubectl edit -n fleet-local default-os-image
```
```yaml
apiVersion: rancheros.cattle.io/v1
kind: ManagedOSImage
metadata:
  name: default-os-image
  namespace: fleet-local
spec:
  # Set to the new RancherOS version you would like to upgrade to
  osImage: quay.io/costoolkit/os2:v0.0.0
```

### Managing available versions

An upgrade channel file ( `rancheros-v0.0.0-amd64.upgradechannel-amd64.yaml` ) file is shipped in os2 releases and can be applied in a Kubernetes cluster where the rancheros operator is installed to syncronize available version for upgrades.


For instance an upgrade channel file might look like this and is sufficient to `kubectl apply` it where the ros-operator is installed: 
```yaml
apiVersion: rancheros.cattle.io/v1
kind: ManagedOSVersionChannel
metadata:
  name: os2-amd64
  namespace: fleet-default
spec:
  options:
    args:
    - github
    command:
    - /usr/bin/upgradechannel-discovery
    envs:
    - name: REPOSITORY
      value: rancher-sandbox/os2
    - name: IMAGE_PREFIX
      value: quay.io/costoolkit/os2-ci
    - name: VERSION_SUFFIX
      value: -amd64
    image: quay.io/costoolkit/upgradechannel-discovery:v0.3-4b83dbe
  type: custom
```

Note: the namespace here is set by default to `fleet-default`, that can be changed to `fleet-local` to target instead the local clusters.

The operator will syncronize available versions and populate `ManagedOSVersion` accordingly. 

To trigger an upgrade from a `ManagedOSVersion` refer to its name in the `ManagedOSImage` field, instead of an `osImage`: 

```bash
kubectl edit -n fleet-local default-os-image
```

```yaml
apiVersion: rancheros.cattle.io/v1
kind: ManagedOSImage
metadata:
  name: default-os-image
  namespace: fleet-local
spec:
  # Set to the new ManagedOSVersion you would like to upgrade to
  managedOSVersionName: v0.1.0-alpha22-amd64
```

Note: be sure to have `osImage` empty when refering to a `ManagedOSVersion` as it takes precedence over `ManagedOSVersion`s.

## rancherd

Rancherd itself doesn't need to be upgraded. It is only ran once per node
to bootstrap the system and then after that provides no value. Rancherd is
packaged in the OS image so newer versions of Rancherd will come with newer
versions of RancherOS.

## Rancher
Rancher is installed as a helm chart following the standard procedure. You can upgrade
Rancher with the [standard procedure documented](https://rancher.com/docs/rancher/v2.6/en/installation/install-rancher-on-k8s/upgrades/).

## Kubernetes
To upgrade Kubernetes you will use Rancher to orchestrate the upgrade. This is a matter of changing
the Kubernetes version on the `fleet-local/local` `Cluster` in the `provisioning.cattle.io/v1`
apiVersion.  For example

```shell
kubectl edit clusters.provisioning.cattle.io -n fleet-local local
```
```yaml
apiVersion: provisioning.cattle.io/v1
kind: Cluster
metadata:
  name: local
  namespace: fleet-local
spec:
  # Change to new valid k8s version, >= 1.21
  # Valid versions are
  # k3s: curl -sL https://raw.githubusercontent.com/rancher/kontainer-driver-metadata/release-v2.6/data/data.json | jq -r '.k3s.releases[].version'
  # RKE2: curl -sL https://raw.githubusercontent.com/rancher/kontainer-driver-metadata/release-v2.6/data/data.json | jq -r '.rke2.releases[].version'
  kubernetesVersion: v1.21.4+k3s1
```

