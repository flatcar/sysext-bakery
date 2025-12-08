package catalog

import (
	"fmt"
	"sort"
	"time"
)

// Asset represents a downloadable artifact (typically a .raw sysext image).
type Asset struct {
	Name         string // original filename, e.g. "docker-28.0.4-x86-64.raw"
	Extension    string // e.g. "docker"
	Version      string // e.g. "28.0.4" / "v1.32.2+k3s1"
	Arch         string // e.g. "x86-64", "arm64"
	Checksum     string // SHA256 digest in hex
	DownloadURL  string // canonical bakery URL to download this asset
	PublishedAt  time.Time
	ReleaseNotes string // optional release body
}

// Release groups assets by extension version.
type Release struct {
	Extension   string
	Version     string
	PublishedAt time.Time
	Assets      map[string]Asset // keyed by architecture
}

// Catalog contains the full set of extensions known to the bakery.
type Catalog struct {
	Extensions     map[string][]Release
	HasPublishInfo bool
}

// Latest returns the most recent release for the extension/arch tuple.
func (c *Catalog) Latest(extension, arch string) (Asset, bool) {
	releases, ok := c.Extensions[extension]
	if !ok {
		return Asset{}, false
	}
	for _, rel := range releases {
		if asset, ok := rel.Assets[arch]; ok {
			return asset, true
		}
	}
	return Asset{}, false
}

// Find returns the asset for the given extension/version/arch.
func (c *Catalog) Find(extension, version, arch string) (Asset, bool) {
	releases, ok := c.Extensions[extension]
	if !ok {
		return Asset{}, false
	}
	for _, rel := range releases {
		if rel.Version != version {
			continue
		}
		asset, ok := rel.Assets[arch]
		return asset, ok
	}
	return Asset{}, false
}

// ExtensionNames returns the sorted list of known extension names.
func (c *Catalog) ExtensionNames() []string {
	names := make([]string, 0, len(c.Extensions))
	for name := range c.Extensions {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// ReleasesFor returns releases sorted by newest first.
func (c *Catalog) ReleasesFor(extension string) ([]Release, error) {
	releases, ok := c.Extensions[extension]
	if !ok {
		return nil, fmt.Errorf("unknown extension %q", extension)
	}
	return releases, nil
}

// FilterExtension restricts the catalog to a single extension if provided.
func (c *Catalog) FilterExtension(extension string) {
	if extension == "" {
		return
	}
	releases, ok := c.Extensions[extension]
	if !ok {
		c.Extensions = map[string][]Release{}
		return
	}
	c.Extensions = map[string][]Release{
		extension: releases,
	}
}
