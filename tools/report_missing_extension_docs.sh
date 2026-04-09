#!/usr/bin/env bash
#
# Detect extensions that are part of the automated release pipeline but are
# missing from the documentation index and/or do not have a dedicated docs page.

set -euo pipefail

scriptroot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
source "${scriptroot}/lib/helpers.sh"

create_issues="$(get_optional_param "create-issues" "false" "${@}")"
repository="${GITHUB_REPOSITORY:-flatcar/sysext-bakery}"

function list_release_extensions() {
  sed -e 's:\s*#.*::' -e 's/[[:space:]]*$//' -e '/^$/d' \
    "${scriptroot}/release_build_versions.txt" \
  | awk '{print $1}' \
  | sort -u
}
# --

function list_index_extensions() {
  sed -n -E 's/^\|[[:space:]]*`([^`]+)`[[:space:]]*\|.*$/\1/p' \
    "${scriptroot}/docs/index.md" \
  | sort -u
}
# --

function docs_page_path() {
  local extension="$1"
  local candidate

  # The repo usually uses docs/<extension>.md, but a few established pages map
  # hyphens to underscores instead.
  for candidate in "${extension}.md" "${extension//-/_}.md"; do
    if [[ -f "${scriptroot}/docs/${candidate}" ]] ; then
      echo "${candidate}"
      return 0
    fi
  done

  return 1
}
# --

function issue_title() {
  local extension="$1"
  echo "docs: add documentation for ${extension} sysext"
}
# --

function issue_body() {
  local extension="$1"
  local missing_index="$2"
  local missing_page="$3"

  cat <<EOF
This extension was detected in \`release_build_versions.txt\`, but its documentation is incomplete.

Current status:
- Extension: \`${extension}\`
- Missing from \`docs/index.md\`: \`${missing_index}\`
- Missing dedicated docs page: \`${missing_page}\`

Checklist:
- [ ] Add a row to the extensions table in \`docs/index.md\`
- [ ] Create \`docs/<extension>.md\` (or the repo's established underscore variant for hyphenated extensions) with a description, upstream project link, and a Butane configuration snippet
- [ ] Verify the extension's releases are accessible at \`https://github.com/flatcar/sysext-bakery/releases/tag/${extension}\`
EOF
}
# --

declare -A index_extensions=()

while IFS= read -r extension; do
  index_extensions["${extension}"]="true"
done < <(list_index_extensions)

open_issues_json="$(gh issue list -R "${repository}" --state open --limit 200 --json title)"
missing_extensions=()

while IFS= read -r extension; do
  missing_index="false"
  missing_page="false"

  if [[ -z ${index_extensions["${extension}"]+x} ]] ; then
    missing_index="true"
  fi

  if ! docs_page_path "${extension}" >/dev/null ; then
    missing_page="true"
  fi

  if [[ ${missing_index} == false && ${missing_page} == false ]] ; then
    continue
  fi

  missing_extensions+=( "${extension}" )

  echo "Missing documentation detected for '${extension}'"
  echo "  docs/index.md entry missing: ${missing_index}"
  echo "  dedicated docs page missing: ${missing_page}"

  title="$(issue_title "${extension}")"
  if jq -e --arg title "${title}" '.[] | select(.title == $title)' \
      >/dev/null <<< "${open_issues_json}" ; then
    echo "  Open issue already exists: ${title}"
    continue
  fi

  if [[ ${create_issues} != true ]] ; then
    echo "  Dry run only; no issue created."
    continue
  fi

  gh issue create \
    -R "${repository}" \
    --title "${title}" \
    --body "$(issue_body "${extension}" "${missing_index}" "${missing_page}")"
done < <(list_release_extensions)

if [[ ${#missing_extensions[@]} -eq 0 ]] ; then
  echo "All extensions listed in release_build_versions.txt are documented."
fi
