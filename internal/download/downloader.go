package download

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/flatcar/sysext-bakery/internal/catalog"
)

// HTTPClient mirrors the Do method needed from http.Client.
type HTTPClient interface {
	Do(req *http.Request) (*http.Response, error)
}

// Options control downloader behaviour.
type Options struct {
	Root        string
	Force       bool
	WithConfig  bool
	WithSymlink bool
}

// Downloader fetches sysext artifacts and stages them under the chosen root.
type Downloader struct {
	Client HTTPClient
	Root   string
}

// Download fetches the asset, verifies the checksum, and writes it to disk.
func (d *Downloader) Download(ctx context.Context, asset catalog.Asset, opts Options) (string, error) {
	client := d.Client
	if client == nil {
		client = http.DefaultClient
	}

	root := opts.Root
	if root == "" {
		root = d.Root
	}
	if root == "" {
		root = "/"
	}
	if opts.WithSymlink && opts.WithConfig {
		// no-op; both allowed simultaneously.
	}

	targetDir := filepath.Join(root, "opt", "extensions", asset.Extension)
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return "", fmt.Errorf("create target dir %q: %w", targetDir, err)
	}

	targetPath := filepath.Join(targetDir, asset.Name)
	if !opts.Force {
		if ok, err := fileMatchesChecksum(targetPath, asset.Checksum); err != nil {
			return "", err
		} else if ok {
			// Already present and valid.
			if opts.WithSymlink {
				if err := d.ensureSymlink(root, asset); err != nil {
					return "", err
				}
			}
			if opts.WithConfig {
				if err := d.ensureConfig(ctx, client, root, asset.Extension); err != nil {
					return "", err
				}
			}
			return targetPath, nil
		}
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, asset.DownloadURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "sysextctl")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return "", fmt.Errorf("download failed: %s: %s", resp.Status, body)
	}

	tmp, err := os.CreateTemp(targetDir, ".download-*")
	if err != nil {
		return "", err
	}
	defer func() {
		tmp.Close()
		os.Remove(tmp.Name())
	}()

	hasher := sha256.New()
	writer := io.MultiWriter(tmp, hasher)
	if _, err := io.Copy(writer, resp.Body); err != nil {
		return "", err
	}
	if err := tmp.Sync(); err != nil {
		return "", err
	}
	if err := tmp.Chmod(0o644); err != nil {
		return "", err
	}

	calculated := hex.EncodeToString(hasher.Sum(nil))
	if !strings.EqualFold(calculated, asset.Checksum) {
		return "", fmt.Errorf("checksum mismatch for %s: expected %s got %s", asset.Name, asset.Checksum, calculated)
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}
	if err := os.Rename(tmp.Name(), targetPath); err != nil {
		return "", fmt.Errorf("move artifact into place: %w", err)
	}

	if opts.WithSymlink {
		if err := d.ensureSymlink(root, asset); err != nil {
			return targetPath, err
		}
	}
	if opts.WithConfig {
		if err := d.ensureConfig(ctx, client, root, asset.Extension); err != nil {
			return targetPath, err
		}
	}
	return targetPath, nil
}

func fileMatchesChecksum(path, checksum string) (bool, error) {
	if checksum == "" {
		return false, nil
	}
	info, err := os.Stat(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return false, nil
		}
		return false, err
	}
	if info.IsDir() {
		return false, fmt.Errorf("expected file at %s but found directory", path)
	}
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()
	hasher := sha256.New()
	if _, err := io.Copy(hasher, f); err != nil {
		return false, err
	}
	sum := hex.EncodeToString(hasher.Sum(nil))
	return strings.EqualFold(sum, checksum), nil
}

func (d *Downloader) ensureSymlink(root string, asset catalog.Asset) error {
	linkPath := filepath.Join(root, "etc", "extensions")
	if err := os.MkdirAll(linkPath, 0o755); err != nil {
		return fmt.Errorf("create link dir: %w", err)
	}
	linkPath = filepath.Join(linkPath, asset.Extension+".raw")
	target := filepath.Join("/opt/extensions", asset.Extension, asset.Name)

	existing, err := os.Lstat(linkPath)
	switch {
	case err == nil:
		if existing.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("cannot overwrite non-symlink at %s without --force", linkPath)
		}
		currentTarget, err := os.Readlink(linkPath)
		if err != nil {
			return fmt.Errorf("read existing symlink: %w", err)
		}
		if currentTarget == target {
			return nil
		}
		if err := os.Remove(linkPath); err != nil {
			return fmt.Errorf("remove existing symlink: %w", err)
		}
	case errors.Is(err, os.ErrNotExist):
		// ok
	default:
		return fmt.Errorf("inspect symlink: %w", err)
	}
	return os.Symlink(target, linkPath)
}

func (d *Downloader) ensureConfig(ctx context.Context, client HTTPClient, root, extension string) error {
	configURL := catalog.BakeryAssetURL(extension + ".conf")
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, configURL, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "sysextctl")
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("download config: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("download config failed: %s: %s", resp.Status, body)
	}

	targetDir := filepath.Join(root, fmt.Sprintf("etc/sysupdate.%s.d", extension))
	if err := os.MkdirAll(targetDir, 0o755); err != nil {
		return fmt.Errorf("create sysupdate dir: %w", err)
	}
	targetPath := filepath.Join(targetDir, extension+".conf")
	tmp, err := os.CreateTemp(targetDir, ".conf-*")
	if err != nil {
		return err
	}
	defer func() {
		tmp.Close()
		os.Remove(tmp.Name())
	}()
	if _, err := io.Copy(tmp, resp.Body); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), targetPath)
}
