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
	fmt.Fprintf(os.Stderr, "%s %s\n", req.Method, req.URL.String())
	resp, err := rt.RoundTrip(req)
	if err != nil {
		return nil, err
	}
	return resp, nil
}
