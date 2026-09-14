# Shipped only when the sysext was built with --with-cni. Nomad merges every
# .hcl file in /etc/nomad.d, so this adds cni_path to the client block in
# nomad.hcl without replacing the rest of that configuration.
client {
  cni_path = "/usr/libexec/cni"
}
