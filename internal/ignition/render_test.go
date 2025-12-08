package ignition

import (
	"strings"
	"testing"

	"github.com/flatcar/sysext-bakery/internal/catalog"
)

func TestRenderButaneSnippet(t *testing.T) {
	assets := []catalog.Asset{
		{
			Extension:   "ollama",
			Version:     "v0.13.1",
			Name:        "ollama-v0.13.1-x86-64.raw",
			Arch:        "x86-64",
			Checksum:    "16cfde40cc28fe7921dd206bdabe2970c16817186c05b6a0c1b5c59fa9a26bb4",
			DownloadURL: "https://extensions.flatcar.org/extensions/ollama-v0.13.1-x86-64.raw",
		},
		{
			Extension:   "wasmedge",
			Version:     "0.14.1",
			Name:        "wasmedge-0.14.1-arm64.raw",
			Arch:        "arm64",
			Checksum:    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
			DownloadURL: "https://extensions.flatcar.org/extensions/wasmedge-0.14.1-arm64.raw",
		},
	}
	out, err := RenderButaneSnippet(assets, RenderOptions{IncludeSysupdateConfig: true})
	if err != nil {
		t.Fatalf("RenderButaneSnippet error: %v", err)
	}
	if !strings.Contains(out, "variant: flatcar") {
		t.Fatalf("expected variant header")
	}
	if !strings.Contains(out, "ollama-v0.13.1-x86-64.raw") {
		t.Fatalf("missing filename")
	}
	const expectedHash = "hash: sha256-16cfde40cc28fe7921dd206bdabe2970c16817186c05b6a0c1b5c59fa9a26bb4"
	if !strings.Contains(out, expectedHash) {
		t.Fatalf("missing verification hash")
	}
	if !strings.Contains(out, "/etc/sysupdate.ollama.d/ollama.conf") {
		t.Fatalf("missing config path")
	}
	if !strings.Contains(out, "/etc/sysupdate.wasmedge.d/wasmedge.conf") {
		t.Fatalf("missing second config path")
	}
	if !strings.Contains(out, "links:") {
		t.Fatalf("expected links section")
	}
}
