package ignition

import (
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/flatcar/sysext-bakery/internal/catalog"
)

// RenderOptions controls Ignition snippet generation.
type RenderOptions struct {
	IncludeSysupdateConfig bool
}

// RenderButaneSnippet produces a Butane YAML snippet that stages the provided sysexts.
func RenderButaneSnippet(assets []catalog.Asset, opts RenderOptions) (string, error) {
	if len(assets) == 0 {
		return "", errors.New("no system extensions supplied")
	}

	sorted := append([]catalog.Asset(nil), assets...)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Extension != sorted[j].Extension {
			return sorted[i].Extension < sorted[j].Extension
		}
		if sorted[i].Version != sorted[j].Version {
			return sorted[i].Version < sorted[j].Version
		}
		return sorted[i].Arch < sorted[j].Arch
	})

	var b strings.Builder
	b.WriteString("variant: flatcar\n")
	b.WriteString("version: 1.0.0\n\n")
	b.WriteString("storage:\n")
	b.WriteString("  files:\n")

	for _, asset := range sorted {
		if _, err := hex.DecodeString(asset.Checksum); err != nil {
			return "", fmt.Errorf("decode checksum for %s: %w", asset.Name, err)
		}
		targetFile := fmt.Sprintf("/opt/extensions/%s/%s", asset.Extension, asset.Name)
		b.WriteString(fmt.Sprintf("    - path: %s\n", targetFile))
		b.WriteString("      mode: 0644\n")
		b.WriteString("      contents:\n")
		hash := strings.ToLower(asset.Checksum)
		b.WriteString(fmt.Sprintf("        source: %s\n", asset.DownloadURL))
		b.WriteString(fmt.Sprintf("        verification:\n          hash: sha256-%s\n", hash))
	}

	if opts.IncludeSysupdateConfig {
		added := map[string]bool{}
		for _, asset := range sorted {
			if added[asset.Extension] {
				continue
			}
			added[asset.Extension] = true
			configFile := fmt.Sprintf("/etc/sysupdate.%s.d/%s.conf", asset.Extension, asset.Extension)
			configSource := catalog.BakeryAssetURL(asset.Extension + ".conf")
			b.WriteString(fmt.Sprintf("    - path: %s\n", configFile))
			b.WriteString("      mode: 0644\n")
			b.WriteString("      contents:\n")
			b.WriteString(fmt.Sprintf("        source: %s\n", configSource))
		}
	}

	b.WriteString("  links:\n")
	seenLinks := map[string]bool{}
	for _, asset := range sorted {
		linkPath := fmt.Sprintf("/etc/extensions/%s.raw", asset.Extension)
		if seenLinks[linkPath] {
			continue
		}
		seenLinks[linkPath] = true
		target := fmt.Sprintf("/opt/extensions/%s/%s", asset.Extension, asset.Name)
		b.WriteString(fmt.Sprintf("    - path: %s\n", linkPath))
		b.WriteString(fmt.Sprintf("      target: %s\n", target))
		b.WriteString("      hard: false\n")
	}

	return b.String(), nil
}
