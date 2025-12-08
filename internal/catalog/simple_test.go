package catalog

import (
	"context"
	"io"
	"net/http"
	"strings"
	"testing"
)

type fakeResponse struct {
	status int
	body   string
}

type fakeHTTPClient struct {
	t         *testing.T
	responses map[string]fakeResponse
	requests  []string
}

func (c *fakeHTTPClient) Do(req *http.Request) (*http.Response, error) {
	url := req.URL.String()
	c.requests = append(c.requests, url)
	resp, ok := c.responses[url]
	if !ok {
		return &http.Response{
			StatusCode: http.StatusNotFound,
			Body:       io.NopCloser(strings.NewReader("not found")),
			Header:     make(http.Header),
		}, nil
	}
	return &http.Response{
		StatusCode: resp.status,
		Body:       io.NopCloser(strings.NewReader(resp.body)),
		Header:     make(http.Header),
	}, nil
}

func TestBuildCatalogGlobal(t *testing.T) {
	body := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  demo-v1.0.0-x86-64.raw\n"
	client := &fakeHTTPClient{
		t: t,
		responses: map[string]fakeResponse{
			globalSHAURL: {status: http.StatusOK, body: body},
		},
	}
	cat, err := BuildCatalog(context.Background(), client, Options{})
	if err != nil {
		t.Fatalf("BuildCatalog error: %v", err)
	}
	if cat.HasPublishInfo {
		t.Fatalf("expected no publish info")
	}
	names := cat.ExtensionNames()
	if len(names) != 1 || names[0] != "demo" {
		t.Fatalf("unexpected extensions: %v", names)
	}
	if got := len(client.requests); got != 1 {
		t.Fatalf("expected 1 request, got %d", got)
	}
	if client.requests[0] != globalSHAURL {
		t.Fatalf("unexpected url: %s", client.requests[0])
	}
}

func TestBuildCatalogReleaseTag(t *testing.T) {
	releaseURL := releaseSHAURL("demo-v1.0.0")
	body := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  demo-v1.0.0-x86-64.raw\n"
	client := &fakeHTTPClient{
		t: t,
		responses: map[string]fakeResponse{
			releaseURL: {status: http.StatusOK, body: body},
		},
	}
	opts := Options{
		ExtensionFilter: "demo",
		ReleaseTag:      "demo-v1.0.0",
	}
	cat, err := BuildCatalog(context.Background(), client, opts)
	if err != nil {
		t.Fatalf("BuildCatalog release mode error: %v", err)
	}
	if got := len(client.requests); got != 1 {
		t.Fatalf("expected 1 request, got %d", got)
	}
	if client.requests[0] != releaseURL {
		t.Fatalf("unexpected url: %s", client.requests[0])
	}
	if _, ok := cat.Extensions["demo"]; !ok {
		t.Fatalf("expected demo extension in catalog")
	}
}

func TestBuildCatalogFallback(t *testing.T) {
	extensionURL := releaseSHAURL("demo")
	client := &fakeHTTPClient{
		t: t,
		responses: map[string]fakeResponse{
			globalSHAURL:                 {status: http.StatusOK, body: "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc  demo-v1.1.0-x86-64.raw\n"},
			extensionURL:                 {status: http.StatusNotFound, body: "missing"},
			releaseSHAURL("demo-v2.0.0"): {status: http.StatusNotFound, body: "missing"},
		},
	}
	opts := Options{
		ExtensionFilter: "demo",
		ReleaseTag:      "demo-v2.0.0",
	}
	cat, err := BuildCatalog(context.Background(), client, opts)
	if err != nil {
		t.Fatalf("BuildCatalog fallback error: %v", err)
	}
	if len(client.requests) != 3 {
		t.Fatalf("expected 3 requests, got %d", len(client.requests))
	}
	if client.requests[0] != releaseSHAURL("demo-v2.0.0") {
		t.Fatalf("unexpected first request: %s", client.requests[0])
	}
	if client.requests[1] != extensionURL {
		t.Fatalf("unexpected second request: %s", client.requests[1])
	}
	if client.requests[2] != globalSHAURL {
		t.Fatalf("unexpected third request: %s", client.requests[2])
	}
	if _, ok := cat.Extensions["demo"]; !ok {
		t.Fatalf("expected filtered extension")
	}
}
