#!/usr/bin/env bash
# Fetch full text of an Indian Kanoon judgment by docid.
# Usage: ik_doc.sh <docid> [outfile]
# Example:
#   ik_doc.sh 128975041 /tmp/kakarlapudi.json
#
# Requires IK_TOKEN in env.

set -euo pipefail

: "${IK_TOKEN:?IK_TOKEN env var not set. Run: export IK_TOKEN='<your-indian-kanoon-api-token>'}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <docid> [outfile=stdout]" >&2
  exit 1
fi

DOCID="$1"
OUTFILE="${2:-}"

API="https://api.indiankanoon.org/doc/${DOCID}/"

if [[ -n "$OUTFILE" ]]; then
  curl -sS -X POST \
    -H "Authorization: Token ${IK_TOKEN}" \
    "${API}" -o "${OUTFILE}"
  BYTES=$(wc -c < "${OUTFILE}" | tr -d ' ')
  echo "Saved ${BYTES} bytes -> ${OUTFILE}"
else
  curl -sS -X POST \
    -H "Authorization: Token ${IK_TOKEN}" \
    "${API}"
fi
