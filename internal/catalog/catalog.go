package catalog

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"sort"
	"strings"
)

// Options drive catalog construction.
type Options struct {
	ExtensionFilter string
	ReleaseTag      string
}

// HTTPClient is a minimal subset of http.Client used for testability.
type HTTPClient interface {
	Do(req *http.Request) (*http.Response, error)
}

// BuildCatalog fetches metadata from SHA256SUMS files and returns a catalog.
func BuildCatalog(ctx context.Context, httpClient HTTPClient, opts Options) (*Catalog, error) {
	entries, err := fetchSHAEntries(ctx, httpClient, opts)
	if err != nil {
		return nil, err
	}

	if opts.ExtensionFilter != "" {
		filtered := entries[:0]
		for _, entry := range entries {
			if entry.Extension == opts.ExtensionFilter {
				filtered = append(filtered, entry)
			}
		}
		entries = append([]shaEntry(nil), filtered...)
	}

	catalog := assembleCatalog(entries)
	catalog.FilterExtension(opts.ExtensionFilter)
	return catalog, nil
}

type shaEntry struct {
	Checksum  string
	FileName  string
	Extension string
	Version   string
	Arch      string
}

func parseSHA256Index(data []byte) ([]shaEntry, error) {
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	var entries []shaEntry
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) != 2 {
			return nil, fmt.Errorf("invalid sha256 entry on line %d", lineNo)
		}
		checksum := parts[0]
		fileName := parts[1]
		ext, ver, arch, err := parseFileName(fileName)
		if err != nil {
			return nil, fmt.Errorf("line %d: %w", lineNo, err)
		}
		if _, err := hex.DecodeString(checksum); err != nil || len(checksum) != sha256.Size*2 {
			return nil, fmt.Errorf("line %d: invalid checksum %q", lineNo, checksum)
		}
		entries = append(entries, shaEntry{
			Checksum:  checksum,
			FileName:  fileName,
			Extension: ext,
			Version:   ver,
			Arch:      arch,
		})
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Extension == entries[j].Extension {
			if entries[i].Version == entries[j].Version {
				return entries[i].Arch < entries[j].Arch
			}
			return entries[i].Version > entries[j].Version
		}
		return entries[i].Extension < entries[j].Extension
	})
	return entries, nil
}

func parseFileName(fileName string) (extension, version, arch string, err error) {
	if !strings.HasSuffix(fileName, ".raw") {
		return "", "", "", fmt.Errorf("unexpected filename %q (missing .raw)", fileName)
	}
	base := strings.TrimSuffix(fileName, ".raw")
	var extAndVersion string
	for _, candidate := range []string{"x86-64", "arm64"} {
		suffix := "-" + candidate
		if strings.HasSuffix(base, suffix) {
			arch = candidate
			extAndVersion = strings.TrimSuffix(base, suffix)
			break
		}
	}
	if arch == "" {
		return "", "", "", fmt.Errorf("unexpected filename %q (unknown architecture)", fileName)
	}
	extAndVersion = strings.TrimSuffix(extAndVersion, "-")
	lastDash := strings.LastIndex(extAndVersion, "-")
	if lastDash == -1 {
		return "", "", "", fmt.Errorf("unexpected filename %q (missing version separator)", fileName)
	}
	extension = extAndVersion[:lastDash]
	version = extAndVersion[lastDash+1:]
	if extension == "" || version == "" || arch == "" {
		return "", "", "", fmt.Errorf("unexpected filename %q", fileName)
	}
	return extension, version, arch, nil
}

func assembleCatalog(entries []shaEntry) *Catalog {
	extMap := map[string]map[string]Release{}
	for _, entry := range entries {
		if _, ok := extMap[entry.Extension]; !ok {
			extMap[entry.Extension] = map[string]Release{}
		}
		release, ok := extMap[entry.Extension][entry.Version]
		if !ok || release.Assets == nil {
			release = Release{
				Extension: entry.Extension,
				Version:   entry.Version,
				Assets:    map[string]Asset{},
			}
		}
		asset := Asset{
			Name:        entry.FileName,
			Extension:   entry.Extension,
			Version:     entry.Version,
			Arch:        entry.Arch,
			Checksum:    entry.Checksum,
			DownloadURL: BakeryAssetURL(entry.FileName),
		}
		release.Assets[entry.Arch] = asset
		extMap[entry.Extension][entry.Version] = release
	}

	catalog := &Catalog{
		Extensions:     map[string][]Release{},
		HasPublishInfo: false,
	}
	for ext, versions := range extMap {
		var rels []Release
		for _, rel := range versions {
			rels = append(rels, rel)
		}
		sort.Slice(rels, func(i, j int) bool {
			// Newest first, fallback to version name (lexicographically descending).
			return rels[i].Version > rels[j].Version
		})
		for idx := range rels {
			rels[idx] = sortAssets(rels[idx])
		}
		catalog.Extensions[ext] = rels
	}
	return catalog
}

func sortAssets(rel Release) Release {
	keys := make([]string, 0, len(rel.Assets))
	for k := range rel.Assets {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	sorted := make(map[string]Asset, len(rel.Assets))
	for _, k := range keys {
		sorted[k] = rel.Assets[k]
	}
	rel.Assets = sorted
	return rel
}
