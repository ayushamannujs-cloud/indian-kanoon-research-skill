# Indian Kanoon API — Reference

Base URL: `https://api.indiankanoon.org`

Auth: `Authorization: Token <token>` header on every request.

All endpoints are **POST**, even read-only ones.

---

## Endpoints

### `/search/` — keyword/citation search

POST params (form-encoded):
- `formInput` (required) — the query string. Combines keywords, phrase quotes, and filter prefixes (see Query Patterns).
- `pagenum` (required) — 0-indexed page number. 10 results per page.
- `fromdate` (optional) — `DD-MM-YYYY`
- `todate` (optional) — `DD-MM-YYYY`
- `maxcites` (optional) — limit number of citations included
- `maxpages` (optional) — limit number of pages

Response (JSON):
```json
{
  "categories": [ ... facet links ... ],
  "docs": [
    {
      "tid": 128975041,
      "title": "Case Name vs Other Party on DD Month YYYY",
      "doctype": 1006,
      "publishdate": "2025-12-12",
      "docsource": "Calcutta High Court (Appellete Side)",
      "headline": "...snippet with <b>bolded</b> keyword matches...",
      "numcites": 28,         // citations in this judgment
      "numcitedby": 0,        // later cases citing this judgment
      "docsize": 51808,
      "citation": "AIR 2025 ..."   // when available
    }
  ],
  "found": "1 - 10 of 542",
  "encodedformInput": "..."
}
```

### `/doc/<tid>/` — fetch full judgment text

POST with no body params, just the auth header.

Response includes full judgment text in `doc` field plus metadata. Large — can be hundreds of KB.

### `/docfragment/<tid>/` — fetch a fragment of a judgment

Useful when you want a section around a keyword without pulling the whole judgment.

---

## Triggering nuances

- **Default ranking** blends keyword match with `numcitedby`. Broad queries surface mega-cited cases regardless of topical fit. Counter with phrase quoting + doctype filters.
- **AI tags**: Indian Kanoon auto-tags judgments with categories like `power-high-court-for-quashing`, `cheque-dishonour`, `indian-penal-code`. These appear under `categories.["Filter by AI Tags"]` in the response and can be used as `+tag:<value>` filters.
- **Doctype codes** (used in `doctypes:` filter) — see `query-patterns.md` for the full table.
