package download

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/flatcar/sysext-bakery/internal/catalog"
)

func TestDownloaderDownload(t *testing.T) {
	payload := []byte("hello world\n")
	sum := sha256.Sum256(payload)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(payload)
	}))
	defer server.Close()

	tmp := t.TempDir()

	asset := catalog.Asset{
		Name:         "demo-v1.0.0-x86-64.raw",
		Extension:    "demo",
		Version:      "v1.0.0",
		Arch:         "x86-64",
		Checksum:     hex.EncodeToString(sum[:]),
		DownloadURL:  server.URL,
		ReleaseNotes: "",
	}

	d := &Downloader{
		Client: server.Client(),
		Root:   tmp,
	}
	opts := Options{
		Root:        tmp,
		Force:       false,
		WithConfig:  false,
		WithSymlink: true,
	}

	path, err := d.Download(context.Background(), asset, opts)
	if err != nil {
		t.Fatalf("Download failed: %v", err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("expected artifact %s: %v", path, err)
	}
	linkPath := filepath.Join(tmp, "etc", "extensions", "demo.raw")
	target, err := os.Readlink(linkPath)
	if err != nil {
		t.Fatalf("expected symlink: %v", err)
	}
	expectedTarget := "/opt/extensions/demo/demo-v1.0.0-x86-64.raw"
	if target != expectedTarget {
		t.Fatalf("unexpected symlink target %q (want %q)", target, expectedTarget)
	}
}
