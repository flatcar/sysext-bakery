package catalog

import "net/url"

func BakeryAssetURL(filename string) string {
	return (&url.URL{
		Scheme: "https",
		Host:   "extensions.flatcar.org",
		Path:   "/extensions/" + filename,
	}).String()
}
