package main

import (
	"fmt"
	"net/http"
	"os"
	"time"
)

func newHTTPClient(debug bool) *http.Client {
	transport := http.DefaultTransport
	if debug {
		transport = &loggingTransport{rt: transport}
	}
	return &http.Client{
		Timeout:   30 * time.Second,
		Transport: transport,
	}
}

type loggingTransport struct {
	rt http.RoundTripper
}

func (t *loggingTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	rt := t.rt
	if rt == nil {
		rt = http.DefaultTransport
	}
	method := req.Method
	if method == "" {
		method = http.MethodGet
	}
	fmt.Fprintf(os.Stderr, "%s %s\n", method, req.URL.String())
	resp, err := rt.RoundTrip(req)
	if err != nil {
		return nil, err
	}
	printRateLimitHeaders(resp)
	return resp, nil
}

func printRateLimitHeaders(resp *http.Response) {
	if resp == nil || resp.Header == nil {
		return
	}
	report := []struct {
		Name string
		Key  string
	}{
		{"X-RateLimit-Limit", "X-RateLimit-Limit"},
		{"X-RateLimit-Remaining", "X-RateLimit-Remaining"},
		{"X-RateLimit-Used", "X-RateLimit-Used"},
		{"X-RateLimit-Resource", "X-RateLimit-Resource"},
		{"X-RateLimit-Reset", "X-RateLimit-Reset"},
	}
	for _, item := range report {
		if value := resp.Header.Get(item.Key); value != "" {
			fmt.Fprintf(os.Stderr, "  %s: %s\n", item.Name, value)
		}
	}
}
