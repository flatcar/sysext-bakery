package main

import (
	"strings"
	"testing"

	"github.com/flatcar/sysext-bakery/internal/catalog"
)

func TestParseExtensionSelections(t *testing.T) {
	selections, err := parseExtensionSelections([]string{"kubernetes@1.32", "ollama@latest"}, "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(selections) != 2 {
		t.Fatalf("expected 2 selections, got %d", len(selections))
	}
	if selections[0].Name != "kubernetes" || selections[0].Version != "1.32" {
		t.Fatalf("unexpected first selection: %#v", selections[0])
	}
	if selections[1].Name != "ollama" || selections[1].Version != "latest" {
		t.Fatalf("unexpected second selection: %#v", selections[1])
	}

	if _, err := parseExtensionSelections([]string{"one", "two"}, "1.0.0"); err == nil {
		t.Fatalf("expected error when using --version with multiple extensions")
	}

	if _, err := parseExtensionSelections([]string{"demo", "demo@1.0.0"}, ""); err == nil {
		t.Fatalf("expected error for duplicate extension")
	}
}

func TestSelectAssetVersionMatching(t *testing.T) {
	cat := &catalog.Catalog{
		Extensions: map[string][]catalog.Release{
			"kubernetes": {
				{
					Extension: "kubernetes",
					Version:   "v1.32.2",
					Assets: map[string]catalog.Asset{
						"x86-64": {
							Name:        "kubernetes-v1.32.2-x86-64.raw",
							Extension:   "kubernetes",
							Version:     "v1.32.2",
							Arch:        "x86-64",
							Checksum:    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
							DownloadURL: "https://example/kubernetes-v1.32.2-x86-64.raw",
						},
					},
				},
				{
					Extension: "kubernetes",
					Version:   "v1.31.5",
					Assets:    map[string]catalog.Asset{},
				},
			},
		},
	}

	asset, err := selectAsset(cat, "kubernetes", "x86-64", "latest")
	if err != nil {
		t.Fatalf("latest lookup failed: %v", err)
	}
	if asset.Version != "v1.32.2" {
		t.Fatalf("expected latest version v1.32.2, got %s", asset.Version)
	}

	asset, err = selectAsset(cat, "kubernetes", "x86-64", "1.32")
	if err != nil {
		t.Fatalf("prefix lookup failed: %v", err)
	}
	if asset.Version != "v1.32.2" {
		t.Fatalf("expected prefix match v1.32.2, got %s", asset.Version)
	}

	if _, err = selectAsset(cat, "kubernetes", "arm64", "1.32"); err == nil {
		t.Fatalf("expected error for missing architecture")
	} else if !strings.Contains(err.Error(), "arch") {
		t.Fatalf("unexpected error: %v", err)
	}

	if _, err := selectAsset(cat, "kubernetes", "x86-64", "9.99"); err == nil {
		t.Fatalf("expected error for unknown version")
	}
}
