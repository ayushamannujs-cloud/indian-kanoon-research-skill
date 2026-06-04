#!/usr/bin/env bash
# Indian Kanoon search wrapper.
# Usage: ik_search.sh <query> [pagenum] [outfile]
# Example:
#   ik_search.sh 'citedby:853800 doctypes:supremecourt,highcourts' 0 /tmp/ik.json
#
# Requires IK_TOKEN in env.

set -euo pipefail

: "${IK_TOKEN:?IK_TOKEN env var not set. Run: export IK_TOKEN='<your-indian-kanoon-api-token>'}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <query> [pagenum=0] [outfile=stdout]" >&2
  exit 1
fi

QUERY="$1"
PAGENUM="${2:-0}"
OUTFILE="${3:-}"

API="https://api.indiankanoon.org/search/"

if [[ -n "$OUTFILE" ]]; then
  curl -sS -X POST \
    -H "Authorization: Token ${IK_TOKEN}" \
    --data-urlencode "formInput=${QUERY}" \
    --data-urlencode "pagenum=${PAGENUM}" \
    "${API}" -o "${OUTFILE}"
  BYTES=$(wc -c < "${OUTFILE}" | tr -d ' ')
  echo "Saved ${BYTES} bytes -> ${OUTFILE}"
else
  curl -sS -X POST \
    -H "Authorization: Token ${IK_TOKEN}" \
    --data-urlencode "formInput=${QUERY}" \
    --data-urlencode "pagenum=${PAGENUM}" \
    "${API}"
fi
