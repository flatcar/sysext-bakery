# Kubernetes sysext

Deploying Kubernetes is a complex topic; a full how-to guide is available at the [Flatcar Kubernetes docs](https://www.flatcar.org/docs/latest/container-runtimes/getting-started-with-kubernetes/).
The how-to guides through the deployment of a full-blown Kubernetes cluster using only Flatcar native features like Butane / Ignition and sysexts.
This makes the howto entirely portable and independent from any vendor / cloud provider.

The Kubernetes sysext is used by the Flatcar project for ClusterAPI.
Flatcar CAPI nodes are composited at provisioning time and can optionally in-place update Kubernetes.

## Usage

As mentioned above, a full howto is available.
Below are a few config snippets from that howto.
We'll discuss 2 node types - control plane and worker nodes - with minor differences in their configuration.

Note that the snippets are for the x86-64 version of Kubernetes v1.32.2.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/kubernetes for a list of all versions available in the bakery.

The snippet includes automated updates via systemd-sysupdate.
Updates are only supported within the same minor release, e.g. v1.32.2 -> v1.32.3; _never_ across releases (v1.31.x -> v1.32.x).
This is because upstream Kubernetes does not support unattended automated upgrades across releases.

Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
It is recommended to deploy [kured](https://kured.dev/) to the cluster to manage reboots.
Alternatively, you can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

```yaml
variant: flatcar
version: 1.0.0

storage:
  links:
    - target: /opt/extensions/kubernetes/kubernetes-v1.32.2-x86-64.raw
      path: /etc/extensions/kubernetes.raw
      hard: false
  files:
    - path: /etc/sysupdate.kubernetes.d/kubernetes-v1.32.conf
      contents:
        source: https://extensions.flatcar.org/extensions/kubernetes/kubernetes-v1.32.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
    - path: /opt/extensions/kubernetes/kubernetes-v1.32.2-x86-64.raw
      contents:
        source: https://extensions.flatcar.org/extensions/kubernetes-v1.32.2-x86-64.raw
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: kubernetes.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/kubernetes.raw > /tmp/kubernetes"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C kubernetes update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/kubernetes.raw > /tmp/kubernetes-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/kubernetes /tmp/kubernetes-new; then touch /run/reboot-required; fi"
    - name: locksmithd.service
      # Disable Flatcar native reboot coordination as KureD will handle OS updates, too
      mask: true
```

This brings up a node with basic support for Kubernetes.
At this point, orchestration would instruct the designated control plane to initialise and to generate secrets for worker nodes to join the cluster.
Orchestration would then spawn worker nodes and instruct these to join.

If you like to try step-by-step instructions for doing this with native Flatcar Butane / Ignition, check out
[Flatcar Kubernetes docs](https://www.flatcar.org/docs/latest/container-runtimes/getting-started-with-kubernetes/).
