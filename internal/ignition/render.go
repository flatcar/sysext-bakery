package ignition

import (
	"encoding/hex"
	"fmt"
	"strings"

	"github.com/flatcar/sysext-bakery/internal/catalog"
)

// RenderOptions controls Ignition snippet generation.
type RenderOptions struct {
	IncludeSysupdateConfig bool
}

// RenderButaneSnippet produces a Butane YAML snippet that stages the sysext.
func RenderButaneSnippet(asset catalog.Asset, opts RenderOptions) (string, error) {
	if _, err := hex.DecodeString(asset.Checksum); err != nil {
		return "", fmt.Errorf("decode checksum: %w", err)
	}
	targetFile := fmt.Sprintf("/opt/extensions/%s/%s", asset.Extension, asset.Name)
	linkPath := fmt.Sprintf("/etc/extensions/%s.raw", asset.Extension)
	var b strings.Builder
	b.WriteString("variant: flatcar\n")
	b.WriteString("version: 1.0.0\n\n")
	b.WriteString("storage:\n")
	b.WriteString("  files:\n")
	b.WriteString(fmt.Sprintf("    - path: %s\n", targetFile))
	b.WriteString("      mode: 0644\n")
	b.WriteString("      contents:\n")
	b.WriteString(fmt.Sprintf("        source: %s\n", asset.DownloadURL))
	b.WriteString(fmt.Sprintf("        verification:\n          hash: sha256-%s\n", strings.ToLower(asset.Checksum)))

	if opts.IncludeSysupdateConfig {
		configFile := fmt.Sprintf("/etc/sysupdate.%s.d/%s.conf", asset.Extension, asset.Extension)
		configSource := catalog.BakeryAssetURL(asset.Extension + ".conf")
		b.WriteString(fmt.Sprintf("    - path: %s\n", configFile))
		b.WriteString("      mode: 0644\n")
		b.WriteString("      contents:\n")
		b.WriteString(fmt.Sprintf("        source: %s\n", configSource))
	}

	b.WriteString("  links:\n")
	b.WriteString(fmt.Sprintf("    - path: %s\n", linkPath))
	b.WriteString(fmt.Sprintf("      target: %s\n", targetFile))
	b.WriteString("      hard: false\n")
	return b.String(), nil
}
