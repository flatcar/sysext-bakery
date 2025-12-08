package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"sort"
	"text/tabwriter"
	"time"

	"github.com/spf13/cobra"

	"github.com/flatcar/sysext-bakery/internal/catalog"
	"github.com/flatcar/sysext-bakery/internal/download"
	"github.com/flatcar/sysext-bakery/internal/ignition"
)

var (
	rootFlag  string
	debugFlag bool
)

func main() {
	rootCmd := newRootCmd()
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:           "sysextctl",
		Short:         "Manage Flatcar system extensions",
		SilenceUsage:  true,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}
	cmd.SetContext(context.Background())
	cmd.PersistentFlags().StringVar(&rootFlag, "root", "", "Alternative filesystem root (default: /)")
	cmd.PersistentFlags().BoolVar(&debugFlag, "debug", false, "Print HTTP requests (method and URL)")
	cmd.AddCommand(
		newListCmd(),
		newDownloadCmd(),
		newIgnitionCmd(),
	)
	return cmd
}

func newListCmd() *cobra.Command {
	var (
		extension string
		arch      string
		showAll   bool
		asJSON    bool
	)
	cmd := &cobra.Command{
		Use:   "list",
		Short: "Enumerate available extensions and versions",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := commandContext(cmd)
			client := newHTTPClient(debugFlag)

			releaseTag := extension
			cat, err := catalog.BuildCatalog(ctx, client, catalog.Options{
				ExtensionFilter: extension,
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
			for _, name := range cat.ExtensionNames() {
				if extension != "" && extension != name {
					continue
				}
				releases, err := cat.ReleasesFor(name)
				if err != nil {
					return err
				}
				if !showAll && len(releases) > 0 {
					releases = releases[:1]
				}
				for _, rel := range releases {
					archKeys := make([]string, 0, len(rel.Assets))
					for k := range rel.Assets {
						archKeys = append(archKeys, k)
					}
					sort.Strings(archKeys)
					for _, archKey := range archKeys {
						if arch != "" && arch != archKey {
							continue
						}
						asset := rel.Assets[archKey]
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

			if arch != "" {
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

			if asJSON {
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
		},
	}

	cmd.Flags().StringVarP(&extension, "extension", "e", "", "Filter by extension name")
	cmd.Flags().StringVarP(&arch, "arch", "a", "", "Filter by architecture (e.g. x86-64, arm64)")
	cmd.Flags().BoolVar(&showAll, "all", false, "Show all published versions (default: only latest)")
	cmd.Flags().BoolVar(&asJSON, "json", false, "Print JSON instead of table output")
	return cmd
}

func newDownloadCmd() *cobra.Command {
	var (
		arch        string
		version     string
		force       bool
		withConfig  bool = true
		withSymlink bool = true
		dryRun      bool
	)
	cmd := &cobra.Command{
		Use:   "download <extension>",
		Short: "Download an extension image into the filesystem",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := commandContext(cmd)
			client := newHTTPClient(debugFlag)
			extension := args[0]

			releaseTag := extension
			if version != "" {
				releaseTag = fmt.Sprintf("%s-%s", extension, version)
			}
			cat, err := catalog.BuildCatalog(ctx, client, catalog.Options{
				ExtensionFilter: extension,
				ReleaseTag:      releaseTag,
			})
			if err != nil {
				return err
			}

			var asset catalog.Asset
			var ok bool
			if version != "" {
				asset, ok = cat.Find(extension, version, arch)
				if !ok {
					return fmt.Errorf("extension %s version %s arch %s not found", extension, version, arch)
				}
			} else {
				asset, ok = cat.Latest(extension, arch)
				if !ok {
					return fmt.Errorf("no release found for %s arch %s", extension, arch)
				}
			}

			if dryRun {
				fmt.Printf("[dry-run] would download %s (%s) to root %s\n", asset.Name, asset.DownloadURL, effectiveRoot(rootFlag))
				return nil
			}

			d := &download.Downloader{
				Client: client,
				Root:   rootFlag,
			}
			targetPath, err := d.Download(ctx, asset, download.Options{
				Root:        rootFlag,
				Force:       force,
				WithConfig:  withConfig,
				WithSymlink: withSymlink,
			})
			if err != nil {
				return err
			}

			fmt.Printf("Downloaded %s -> %s\n", asset.Name, targetPath)
			if withSymlink {
				fmt.Printf("Symlinked to /etc/extensions/%s.raw (within root %s)\n", asset.Extension, effectiveRoot(rootFlag))
			}
			if withConfig {
				fmt.Printf("Installed sysupdate config under %s\n", fmt.Sprintf("%s/etc/sysupdate.%s.d/%s.conf", effectiveRoot(rootFlag), asset.Extension, asset.Extension))
			}
			return nil
		},
	}
	cmd.Flags().StringVar(&arch, "arch", defaultArch(), "Architecture to download (e.g. x86-64, arm64)")
	cmd.Flags().StringVar(&version, "version", "", "Specific version to download (default: latest)")
	cmd.Flags().BoolVar(&force, "force", false, "Overwrite existing files even if checksum matches")
	cmd.Flags().BoolVar(&withConfig, "with-config", true, "Download sysupdate config alongside the image")
	cmd.Flags().BoolVar(&withSymlink, "with-symlink", true, "Maintain /etc/extensions/<name>.raw symlink")
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Print actions without downloading")
	return cmd
}

func newIgnitionCmd() *cobra.Command {
	var (
		arch       string
		version    string
		withConfig bool = true
	)
	cmd := &cobra.Command{
		Use:   "ignition <extension>",
		Short: "Emit a Butane snippet to provision an extension",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := commandContext(cmd)
			client := newHTTPClient(debugFlag)
			extension := args[0]

			releaseTag := extension
			if version != "" {
				releaseTag = fmt.Sprintf("%s-%s", extension, version)
			}
			cat, err := catalog.BuildCatalog(ctx, client, catalog.Options{
				ExtensionFilter: extension,
				ReleaseTag:      releaseTag,
			})
			if err != nil {
				return err
			}

			var asset catalog.Asset
			var ok bool
			if version != "" {
				asset, ok = cat.Find(extension, version, arch)
				if !ok {
					return fmt.Errorf("extension %s version %s arch %s not found", extension, version, arch)
				}
			} else {
				asset, ok = cat.Latest(extension, arch)
				if !ok {
					return fmt.Errorf("no release found for %s arch %s", extension, arch)
				}
			}

			out, err := ignition.RenderButaneSnippet(asset, ignition.RenderOptions{IncludeSysupdateConfig: withConfig})
			if err != nil {
				return err
			}
			fmt.Println(out)
			return nil
		},
	}
	cmd.Flags().StringVar(&arch, "arch", defaultArch(), "Architecture to target (e.g. x86-64, arm64)")
	cmd.Flags().StringVar(&version, "version", "", "Specific version (default: latest)")
	cmd.Flags().BoolVar(&withConfig, "with-config", true, "Include sysupdate config download")
	return cmd
}

func commandContext(cmd *cobra.Command) context.Context {
	ctx := cmd.Context()
	if ctx == nil {
		return context.Background()
	}
	return ctx
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
