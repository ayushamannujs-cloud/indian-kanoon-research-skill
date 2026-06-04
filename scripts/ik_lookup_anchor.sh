#!/usr/bin/env bash
# Find the docid of an anchor case by party name.
# Usage: ik_lookup_anchor.sh "Hridaya Ranjan Prasad Verma" [doctype=supremecourt]
#
# Returns top 5 candidates with tid, date, court, numcitedby, title — sorted by date asc
# so the earliest (typically the anchor judgment itself) is at the top.
#
# Indian Kanoon ranks by `numcitedby`, which pushes later citing-cases above the original.
# Sorting by date asc and restricting to SC first counters this.
#
# If the anchor isn't found in SC, retry with all High Courts + SC.
#
# Note on transliteration: Indian case names sometimes appear with spelling variants on IK
# (e.g. "Hridaya Ranjan" vs "Hridaya Rangan"). If your first search returns nothing,
# try variant spellings or shorten to the most distinctive 1-2 words.
#
# Requires IK_TOKEN and `jq` in env.

set -euo pipefail

: "${IK_TOKEN:?IK_TOKEN env var not set. Run: export IK_TOKEN='<your-indian-kanoon-api-token>'}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"<case name>\" [doctype=supremecourt]" >&2
  echo "Examples:" >&2
  echo "  $0 \"Hridaya Ranjan Prasad Verma\"" >&2
  echo "  $0 \"Bhura Ram\" highcourts" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Install via: brew install jq  (or apt-get install jq)" >&2
  exit 1
fi

CASE_NAME="$1"
DOCTYPE="${2:-supremecourt}"
API="https://api.indiankanoon.org/search/"

search() {
  local doctypes="$1"
  curl -sS -X POST \
    -H "Authorization: Token ${IK_TOKEN}" \
    --data-urlencode "formInput=\"${CASE_NAME}\" doctypes:${doctypes}" \
    --data-urlencode "pagenum=0" \
    "${API}"
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

search "${DOCTYPE}" > "${TMP}"

HITS=$(jq '.docs | length' "${TMP}")
if [[ "$HITS" -eq 0 ]]; then
  echo "# No hits in doctypes:${DOCTYPE}. Retrying with supremecourt,highcourts..." >&2
  search "supremecourt,highcourts" > "${TMP}"
  HITS=$(jq '.docs | length' "${TMP}")
fi

if [[ "$HITS" -eq 0 ]]; then
  echo "# No hits anywhere. Try a variant spelling or shorter name fragment." >&2
  exit 2
fi

# Top 5, sorted by date ascending. Earliest case is usually the anchor judgment.
jq -r '
  .docs[0:10]
  | sort_by(.publishdate)
  | .[0:5]
  | .[]
  | "tid=\(.tid)\tdate=\(.publishdate)\tcourt=\(.docsource)\tnumcitedby=\(.numcitedby // 0)\ttitle=\(.title | gsub("<[^>]+>"; ""))"
' "${TMP}"
