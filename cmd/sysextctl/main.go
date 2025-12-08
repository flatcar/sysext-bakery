package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"sort"
	"text/tabwriter"
	"time"

	"github.com/flatcar/sysext-bakery/internal/catalog"
	"github.com/flatcar/sysext-bakery/internal/download"
	"github.com/flatcar/sysext-bakery/internal/ignition"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	ctx := context.Background()

	global := flag.NewFlagSet("sysextctl", flag.ContinueOnError)
	global.Usage = func() {
		fmt.Fprintf(global.Output(), `Usage: sysextctl [global flags] <command> [args]

Commands:
  list       Enumerate available extensions and versions
  download   Download an extension image into the local filesystem
  ignition   Emit a Butane snippet for provisioning

Global flags:
`)
		global.PrintDefaults()
	}
	root := global.String("root", "", "Alternative filesystem root (default: /)")
	debug := global.Bool("debug", false, "Print HTTP requests (method and URL)")
	if err := global.Parse(os.Args[1:]); err != nil {
		if err == flag.ErrHelp {
			return nil
		}
		return err
	}

	args := global.Args()
	if len(args) == 0 {
		global.Usage()
		return fmt.Errorf("no command specified")
	}
	command := args[0]
	cmdArgs := args[1:]

	httpClient := newHTTPClient(*debug)

	switch command {
	case "list":
		return cmdList(ctx, httpClient, cmdArgs)
	case "download":
		return cmdDownload(ctx, httpClient, *root, cmdArgs)
	case "ignition":
		return cmdIgnition(ctx, httpClient, cmdArgs)
	case "help", "-h", "--help":
		global.Usage()
		return nil
	default:
		return fmt.Errorf("unknown command %q", command)
	}
}

func cmdList(ctx context.Context, httpClient *http.Client, args []string) error {
	fs := flag.NewFlagSet("list", flag.ContinueOnError)
	extension := fs.String("extension", "", "Filter by extension name")
	arch := fs.String("arch", "", "Filter by architecture (e.g. x86-64, arm64)")
	showAll := fs.Bool("all", false, "Show all published versions (default: only latest)")
	asJSON := fs.Bool("json", false, "Print JSON instead of table output")
	fs.Usage = func() {
		fmt.Fprintf(fs.Output(), "Usage: sysextctl list [flags]\n\n")
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		if err == flag.ErrHelp {
			return nil
		}
		return err
	}

	releaseTag := ""
	if *extension != "" {
		releaseTag = *extension
	}
	cat, err := catalog.BuildCatalog(ctx, httpClient, catalog.Options{
		ExtensionFilter: *extension,
		ReleaseTag:      releaseTag,
	})
	if err != nil {
		return err
	}

	type item struct {
		Extension   string    `json:"extension"`
		Version     string    `json:"version"`
		Arch        string    `json:"arch"`
		Checksum    string    `json:"checksum"`
		DownloadURL string    `json:"download_url"`
		PublishedAt time.Time `json:"published_at,omitempty"`
	}

	var items []item
	extensions := cat.ExtensionNames()
	for _, name := range extensions {
		if *extension != "" && *extension != name {
			continue
		}
		releases, err := cat.ReleasesFor(name)
		if err != nil {
			return err
		}
		if !*showAll && len(releases) > 0 {
			releases = releases[:1]
		}
		for _, rel := range releases {
			archKeys := make([]string, 0, len(rel.Assets))
			for archKey := range rel.Assets {
				archKeys = append(archKeys, archKey)
			}
			sort.Strings(archKeys)
			for _, archKey := range archKeys {
				asset := rel.Assets[archKey]
				if *arch != "" && *arch != archKey {
					continue
				}
				items = append(items, item{
					Extension:   name,
					Version:     rel.Version,
					Arch:        archKey,
					Checksum:    asset.Checksum,
					DownloadURL: asset.DownloadURL,
					PublishedAt: asset.PublishedAt,
				})
			}
		}
	}
	if *arch != "" {
		sort.Slice(items, func(i, j int) bool {
			if items[i].Extension == items[j].Extension {
				if items[i].Version == items[j].Version {
					return items[i].Arch < items[j].Arch
				}
				return items[i].Version > items[j].Version
			}
			return items[i].Extension < items[j].Extension
		})
	}

	if *asJSON {
		data, err := json.MarshalIndent(items, "", "  ")
		if err != nil {
			return err
		}
		fmt.Println(string(data))
		return nil
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	if cat.HasPublishInfo {
		fmt.Fprintln(w, "EXTENSION\tVERSION\tARCH\tPUBLISHED\tURL")
	} else {
		fmt.Fprintln(w, "EXTENSION\tVERSION\tARCH\tURL")
	}
	for _, it := range items {
		if cat.HasPublishInfo {
			published := "-"
			if !it.PublishedAt.IsZero() {
				published = it.PublishedAt.Format(time.RFC3339)
			}
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", it.Extension, it.Version, it.Arch, published, it.DownloadURL)
		} else {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", it.Extension, it.Version, it.Arch, it.DownloadURL)
		}
	}
	return w.Flush()
}

func cmdDownload(ctx context.Context, httpClient *http.Client, root string, args []string) error {
	fs := flag.NewFlagSet("download", flag.ContinueOnError)
	arch := fs.String("arch", defaultArch(), "Architecture to download (e.g. x86-64, arm64)")
	version := fs.String("version", "", "Specific version to download (default: latest)")
	force := fs.Bool("force", false, "Overwrite existing files even if checksum matches")
	withConfig := fs.Bool("with-config", true, "Download sysupdate config alongside the image")
	withSymlink := fs.Bool("with-symlink", true, "Maintain /etc/extensions/<name>.raw symlink")
	dryRun := fs.Bool("dry-run", false, "Print actions without downloading")
	fs.Usage = func() {
		fmt.Fprintf(fs.Output(), "Usage: sysextctl download [flags] <extension>\n\n")
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		if err == flag.ErrHelp {
			return nil
		}
		return err
	}
	rest := fs.Args()
	if len(rest) == 0 {
		return fmt.Errorf("missing extension name")
	}
	extension := rest[0]

	releaseTag := extension
	if *version != "" {
		releaseTag = fmt.Sprintf("%s-%s", extension, *version)
	}
	cat, err := catalog.BuildCatalog(ctx, httpClient, catalog.Options{
		ExtensionFilter: extension,
		ReleaseTag:      releaseTag,
	})
	if err != nil {
		return err
	}

	var asset catalog.Asset
	var ok bool
	if *version != "" {
		asset, ok = cat.Find(extension, *version, *arch)
		if !ok {
			return fmt.Errorf("extension %s version %s arch %s not found", extension, *version, *arch)
		}
	} else {
		asset, ok = cat.Latest(extension, *arch)
		if !ok {
			return fmt.Errorf("no release found for %s arch %s", extension, *arch)
		}
	}

	if *dryRun {
		fmt.Printf("[dry-run] would download %s (%s) to root %s\n", asset.Name, asset.DownloadURL, effectiveRoot(root))
		return nil
	}

	d := &download.Downloader{
		Client: httpClient,
		Root:   root,
	}
	opts := download.Options{
		Root:        root,
		Force:       *force,
		WithConfig:  *withConfig,
		WithSymlink: *withSymlink,
	}
	targetPath, err := d.Download(ctx, asset, opts)
	if err != nil {
		return err
	}
	fmt.Printf("Downloaded %s -> %s\n", asset.Name, targetPath)
	if opts.WithSymlink {
		fmt.Printf("Symlinked to /etc/extensions/%s.raw (within root %s)\n", asset.Extension, effectiveRoot(root))
	}
	if opts.WithConfig {
		fmt.Printf("Installed sysupdate config under %s\n", fmt.Sprintf("%s/etc/sysupdate.%s.d/%s.conf", effectiveRoot(root), asset.Extension, asset.Extension))
	}
	return nil
}

func cmdIgnition(ctx context.Context, httpClient *http.Client, args []string) error {
	fs := flag.NewFlagSet("ignition", flag.ContinueOnError)
	arch := fs.String("arch", defaultArch(), "Architecture to target (e.g. x86-64, arm64)")
	version := fs.String("version", "", "Specific version (default: latest)")
	withConfig := fs.Bool("with-config", true, "Include sysupdate config download")
	fs.Usage = func() {
		fmt.Fprintf(fs.Output(), "Usage: sysextctl ignition [flags] <extension>\n\n")
		fs.PrintDefaults()
	}
	if err := fs.Parse(args); err != nil {
		if err == flag.ErrHelp {
			return nil
		}
		return err
	}
	rest := fs.Args()
	if len(rest) == 0 {
		return fmt.Errorf("missing extension name")
	}
	extension := rest[0]

	releaseTag := extension
	if *version != "" {
		releaseTag = fmt.Sprintf("%s-%s", extension, *version)
	}
	cat, err := catalog.BuildCatalog(ctx, httpClient, catalog.Options{
		ExtensionFilter: extension,
		ReleaseTag:      releaseTag,
	})
	if err != nil {
		return err
	}
	var asset catalog.Asset
	var ok bool
	if *version != "" {
		asset, ok = cat.Find(extension, *version, *arch)
		if !ok {
			return fmt.Errorf("extension %s version %s arch %s not found", extension, *version, *arch)
		}
	} else {
		asset, ok = cat.Latest(extension, *arch)
		if !ok {
			return fmt.Errorf("no release found for %s arch %s", extension, *arch)
		}
	}
	out, err := ignition.RenderButaneSnippet(asset, ignition.RenderOptions{IncludeSysupdateConfig: *withConfig})
	if err != nil {
		return err
	}
	fmt.Println(out)
	return nil
}

func defaultArch() string {
	switch runtime.GOARCH {
	case "amd64":
		return "x86-64"
	case "arm64":
		return "arm64"
	default:
		return "x86-64"
	}
}

func effectiveRoot(root string) string {
	if root == "" {
		return "/"
	}
	return root
}
