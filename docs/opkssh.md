# opkssh sysext

This sysext ships [opkssh](https://github.com/openpubkey/opkssh/),

opkssh is a tool which enables ssh to be used with OpenID Connect allowing SSH access to be managed via identities like alice@example.com instead of long-lived SSH keys. It does not replace SSH, but instead generates SSH public keys containing PK Tokens and configures sshd to verify them. These PK Tokens contain standard OpenID Connect ID Tokens. This protocol builds on the OpenPubkey which adds user public keys to OpenID Connect without breaking compatibility with existing OpenID Provider.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the arm-64 version of opkssh v0.5.1.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/opkssh for a list of all versions available in the bakery.

Generic configuration for both Server (control plane) and Agent (worker):

```yaml
variant: flatcar
version: 1.0.0

passwd:
  users:
    - name: opksshuser
      no_create_home: true
      shell: /sbin/nologin
      uid: 999
      primary_group: opksshuser
      no_user_group: true
  groups:
    - name: opksshuser
      gid: 999
      system: true


storage:
  files:
    - path: /opt/extensions/opkssh/opkssh-v0.5.1-arm64.raw
      contents:
        source: https://extensions.flatcar.org/extensions/opkssh-v0.5.1-arm64.raw
    - path: /etc/sysupdate.opkssh.d/opkssh-v0.5.1.conf
      contents:
        source: https://extensions.flatcar.org/extensions/opkssh/opkssh-v0.5.1.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
    - path: /etc/opk/providers
      mode: 0640
      group:
        id: 999
      contents:
        inline: |
          # Issuer Client-ID expiration-policy
          https://accounts.google.com 206584157355-7cbe4s640tvm7naoludob4ut1emii7sf.apps.googleusercontent.com 24h
    - path: /etc/opk/auth_id
      mode: 0640
      group:
        id: 999
      contents:
        inline: |
          core my.email@gmail.com https://accounts.google.com
    - path: /var/log/opkssh.log
      mode: 0660
      group:
        id: 999
      contents:
        inline: ''
    - path: /etc/sudoers.d/okpsshuser
      contents:
        inline: |
          opksshuser ALL=(ALL) NOPASSWD: /usr/local/bin/opkssh readhome *
    - path: /etc/ssh/sshd_config.d/99-opkssh.conf
      contents:
        inline: |
          AuthorizedKeysCommand /usr/local/bin/opkssh verify %u %k %t
          AuthorizedKeysCommandUser opksshuser
  links:
    - target: /opt/extensions/opkssh/opkssh-v0.5.1-arm64.raw
      path: /etc/extensions/opkssh.raw
      hard: false

systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: opkssh.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/opkssh.raw > /tmp/opkssh"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C opkssh update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/opkssh.raw > /tmp/opkssh-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/opkssh /tmp/opkssh-new; then systemd-sysext refresh; fi"
```
