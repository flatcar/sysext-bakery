package catalog

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

const globalSHAURL = "https://github.com/flatcar/sysext-bakery/releases/download/SHA256SUMS/SHA256SUMS"

func fetchSHAEntries(ctx context.Context, httpClient HTTPClient, opts Options) ([]shaEntry, error) {
	client := httpClient
	if client == nil {
		client = http.DefaultClient
	}

	candidates := orderedSHAURLs(opts)
	var data []byte
	var err error
	for idx, candidate := range candidates {
		if candidate == "" {
			continue
		}
		data, err = fetchSHAFile(ctx, client, candidate)
		if err == nil {
			break
		}
		if idx == len(candidates)-1 {
			return nil, err
		}
	}
	return parseSHA256Index(data)
}

func orderedSHAURLs(opts Options) []string {
	var urls []string
	if opts.ReleaseTag != "" {
		urls = append(urls, releaseSHAURL(opts.ReleaseTag))
	}
	if opts.ExtensionFilter != "" && opts.ExtensionFilter != opts.ReleaseTag {
		urls = append(urls, releaseSHAURL(opts.ExtensionFilter))
	}
	urls = append(urls, globalSHAURL)
	return urls
}

func releaseSHAURL(tag string) string {
	escaped := url.PathEscape(tag)
	return fmt.Sprintf("https://github.com/flatcar/sysext-bakery/releases/download/%s/SHA256SUMS", escaped)
}

func fetchSHAFile(ctx context.Context, client HTTPClient, assetURL string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, assetURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "sysextctl")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("fetch %s: %s: %s", assetURL, resp.Status, body)
	}
	return io.ReadAll(resp.Body)
}
