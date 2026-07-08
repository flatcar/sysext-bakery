# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

# Full configuration options can be found at https://developer.hashicorp.com/vault/docs/configuration

ui = true

# storage
# The storage stanza configures the storage backend, which represents the location
# for the durable storage of Vault's information. Each backend has pros, cons,
# advantages, and trade-offs. For example, some backends support high availability
# while others provide a more robust backup and restoration process.
storage "file" {
  path = "/var/lib/vault/data"
}

# For production the recommended storage backends are Integrated Storage (raft)
# or Consul. Example raft configuration:
#storage "raft" {
#  path    = "/var/lib/vault/data"
#  node_id = "node1"
#}

# listener
# The listener stanza configures the addresses and ports on which Vault will
# respond to requests. At least one listener is required. By default the listener
# below binds to loopback only; adjust address and TLS settings for production use.
listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}

# api_addr
# Specifies the address (full URL) to advertise to other Vault servers in the
# cluster for client redirection.
#api_addr = "https://vault.example.com:8200"

# cluster_addr
# Indicates the address and port to be used for communication between the Vault
# nodes in a cluster.
#cluster_addr = "https://vault.example.com:8201"

# Enterprise License
# Vault Enterprise requires a license.
#license_path = "/etc/vault.d/vault.hclic"
