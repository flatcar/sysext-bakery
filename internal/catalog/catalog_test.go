package catalog

import (
	"reflect"
	"testing"
)

func TestParseFileName(t *testing.T) {
	tests := map[string][3]string{
		"docker-28.0.4-x86-64.raw":          {"docker", "28.0.4", "x86-64"},
		"cilium-v0.18.9-arm64.raw":          {"cilium", "v0.18.9", "arm64"},
		"nvidia-runtime-v1.17.5-x86-64.raw": {"nvidia-runtime", "v1.17.5", "x86-64"},
		"k3s-v1.32.2+k3s1-arm64.raw":        {"k3s", "v1.32.2+k3s1", "arm64"},
		"kubernetes-v1.32.2-x86-64.raw":     {"kubernetes", "v1.32.2", "x86-64"},
		"rke2-v1.32.1+rke2r1-arm64.raw":     {"rke2", "v1.32.1+rke2r1", "arm64"},
		"ollama-v0.13.1-x86-64.raw":         {"ollama", "v0.13.1", "x86-64"},
		"wasmcloud-v1.7.0-x86-64.raw":       {"wasmcloud", "v1.7.0", "x86-64"},
		"wasmedge-0.14.1-arm64.raw":         {"wasmedge", "0.14.1", "arm64"},
		"tailscale-v1.80.3-x86-64.raw":      {"tailscale", "v1.80.3", "x86-64"},
		"containerd-2.0.4-arm64.raw":        {"containerd", "2.0.4", "arm64"},
		"docker-buildx-0.25.0-x86-64.raw":   {"docker-buildx", "0.25.0", "x86-64"},
		"docker-compose-2.34.0-arm64.raw":   {"docker-compose", "2.34.0", "arm64"},
		"keepalived-v2.3.1-x86-64.raw":      {"keepalived", "v2.3.1", "x86-64"},
		"nebula-v1.9.5-arm64.raw":           {"nebula", "v1.9.5", "arm64"},
		"nomad-1.9.2-x86-64.raw":            {"nomad", "1.9.2", "x86-64"},
		"consul-1.21.4-arm64.raw":           {"consul", "1.21.4", "arm64"},
		"wasmtime-v31.0.0-x86-64.raw":       {"wasmtime", "v31.0.0", "x86-64"},
	}

	for input, expected := range tests {
		ext, version, arch, err := parseFileName(input)
		if err != nil {
			t.Fatalf("parseFileName(%q) unexpected error: %v", input, err)
		}
		got := [3]string{ext, version, arch}
		if got != expected {
			t.Fatalf("parseFileName(%q) got %v, expected %v", input, got, expected)
		}
	}
}

func TestParseSHA256Index(t *testing.T) {
	data := []byte(`
16cfde40cc28fe7921dd206bdabe2970c16817186c05b6a0c1b5c59fa9a26bb4  ollama-v0.13.1-x86-64.raw
b6c70a58ada59d079cebe1dabbbfc5ef9d99904e22d6faf3ecc865d131620355  ollama-v0.13.1-arm64.raw
`)
	entries, err := parseSHA256Index(data)
	if err != nil {
		t.Fatalf("parseSHA256Index error: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	want := []shaEntry{
		{
			Checksum:  "b6c70a58ada59d079cebe1dabbbfc5ef9d99904e22d6faf3ecc865d131620355",
			FileName:  "ollama-v0.13.1-arm64.raw",
			Extension: "ollama",
			Version:   "v0.13.1",
			Arch:      "arm64",
		},
		{
			Checksum:  "16cfde40cc28fe7921dd206bdabe2970c16817186c05b6a0c1b5c59fa9a26bb4",
			FileName:  "ollama-v0.13.1-x86-64.raw",
			Extension: "ollama",
			Version:   "v0.13.1",
			Arch:      "x86-64",
		},
	}
	if !reflect.DeepEqual(entries, want) {
		t.Fatalf("entries mismatch\n got: %#v\nwant: %#v", entries, want)
	}
}
