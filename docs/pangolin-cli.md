# Pangolin CLI sysext

This sysext ships the [Pangolin CLI](https://github.com/fosrl/cli), the command line client for [Pangolin](https://pangolin.net/).

Pangolin is a self-hosted tunneled reverse proxy with identity and access management.
The main use of the CLI on Flatcar is to run a [site connector](https://docs.pangolin.net/manage/sites/install-site), which creates a persistent connection from the host to a Pangolin server.

The sysext installs the upstream release binary as `/usr/local/bin/pangolin`.
It also ships a `pangolin-site.service` unit that runs `pangolin up site`.
The unit is not enabled by default, and it only starts when `/etc/pangolin/pangolin-site.env` exists.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

Before you use the snippet, create a site in Pangolin and copy its ID, secret and endpoint.
Put these values in `/etc/pangolin/pangolin-site.env`.
The site connector reads the environment variables automatically, so the unit does not repeat them as flags.
The snippet enables the shipped unit with a `multi-user.target.wants` link.
See [Configure Sites](https://docs.pangolin.net/manage/sites/configure-site) for more environment variables.

The snippet includes automated updates via systemd-sysupdate.
After an update, the extensions are refreshed and the site connector is restarted to use the new binary; no reboot is required.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of Pangolin CLI 0.17.0.
For arm64, replace `x86-64` with `arm64`.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/pangolin-cli for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  directories:
    - path: /etc/pangolinbgg
sudo systemctl status pangolin-site.service
sudo journalctl -u pangolin-site.service
```

If you change `/etc/pangolin/pangolin-site.env` later, restart the service so the site connector picks up the new values:

```bash
sudo systemctl restart pangolin-site.service
```
