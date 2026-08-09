# BlueZ sysext

This extension ships [BlueZ](http://www.bluez.org/), the Linux Bluetooth userspace: the `bluetoothd` daemon plus the `bluetoothctl`, `btmon`, `btmgmt` and `btattach` tools.

BlueZ has no upstream static or portable release and it links glib, dbus and readline, so this extension bundles the binaries together with their shared-library closure (including glibc and the dynamic loader) extracted from a Debian container, the same way the `qemu` and `tilde` extensions do. Because of that the version numbers you can build are the BlueZ versions Debian stable/testing ship, not arbitrary upstream releases.

## Kernel requirements

The extension ships **userspace only**. Bluetooth kernel modules have to match the running kernel exactly, so they belong in the Flatcar image rather than in a sysext.

Flatcar images built before [flatcar/scripts#4197](https://github.com/flatcar/scripts/pull/4197) contain no Bluetooth support at all — `CONFIG_BT` was never enabled — so `bluetoothd` has nothing to talk to. On such an image the `bluetooth.service` unit shipped here is skipped rather than failed, because it is guarded by `ConditionPathIsDirectory=/sys/class/bluetooth`.

On an image that does have the modules, the driver for your controller (`btusb` for USB adapters, `hci_uart` for UART-attached ones) is autoloaded when the device is detected, `/sys/class/bluetooth` appears, and `bluetooth.service` starts.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of BlueZ 5.82. Other architectures are also available.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/bluez for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/bluez/bluez-5.82-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/bluez-5.82-x86-64.raw
    - path: /etc/sysupdate.bluez.d/bluez.conf
      contents:
        source: https://extensions.flatcar.org/extensions/bluez.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/bluez/bluez-5.82-x86-64.raw
      path: /etc/extensions/bluez.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: bluez.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/bluez.raw > /tmp/bluez"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C bluez update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/bluez.raw > /tmp/bluez-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/bluez /tmp/bluez-new; then touch /run/reboot-required; fi"
```

## What the extension starts

`bluetooth.service` is upheld by `multi-user.target`, so it starts on merge and is restarted if it dies. It runs `bluetoothd` as a D-Bus service under the `org.bluez` name.

The extension drops a D-Bus policy file into `/usr/share/dbus-1/system.d/`, which a *running* `dbus-daemon` has not read yet. The unit therefore asks D-Bus to reload its configuration before starting `bluetoothd`; without that, `bluetoothd` cannot take its name on the system bus until the next reboot.

Adapter settings and pairing keys are stored under `/var/lib/bluetooth`, created by the shipped tmpfiles snippet.

## Configuration

`bluetoothd` reads `/etc/bluetooth/main.conf` if present and runs with built-in defaults otherwise. To change settings, drop your own file there via Ignition, for example to power adapters on automatically:

```yaml
storage:
  files:
    - path: /etc/bluetooth/main.conf
      mode: 0644
      contents:
        inline: |
          [Policy]
          AutoEnable=true
```

## Checking it works

```sh
# the controller shows up once the kernel driver has bound it
bluetoothctl list

# live HCI trace, useful when a controller misbehaves
btmon
```

If `bluetoothctl list` prints nothing, check that a driver actually bound the controller:

```sh
systemctl status bluetooth
ls /sys/class/bluetooth
journalctl -u bluetooth
```

An empty `/sys/class/bluetooth` means no Bluetooth driver is loaded — either the hardware is absent, or the image predates the kernel change linked above.
