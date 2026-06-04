# Indian Kanoon Research Skill

A Claude agent skill for disciplined Indian case law research. The output is a tiered, citable authority table — docid, citation, court, date, and a one-line "why it matters" — ready to drop into a petition or opinion.

Built by [@ayushamannujs-cloud](https://github.com/ayushamannujs-cloud).

---

## The problem with searching Indian Kanoon directly

Indian Kanoon ranks results by `numcitedby` — the number of times a judgment has been cited. This means Kesavananda Bharati appears at the top of almost any query, regardless of relevance. Keyword search alone produces noisy results that miss the cases that actually matter.

The fix: treat Indian Kanoon as a **citation-graph database** and use its `citedby:` and `cites:` operators instead of relying on keyword ranking.

## What this skill does

When invoked, the skill:

1. **Interviews you** — legal question, preferred court/forum, anchor cases you already know, date range, relevant statutes. Does not skip this step.

2. **Decomposes the question** into 2–4 independent doctrinal angles, each with its own search lane. Shows you the angle table before running any query.

3. **Finds anchor case docids** using `ik_lookup_anchor.sh` — sorts candidates by date ascending so the original judgment ranks above later cases that merely cite it.

4. **Runs citation-graph queries first** (`citedby:<docid>` filtered by your forum), then phrase+doctype keyword search, then named-case lookup — in priority order.

5. **Classifies every result** as one of:
   - **Ratio (on point)** — court held the supporting proposition on comparable facts and granted relief
   - **Foundational** — leading authority that lays down the test or ingredients
   - **Observation only** — passing remark or general direction, not a holding

   Observation-only cases are kept but explicitly flagged. A weak authority is never presented as a holding.

6. **Outputs a tiered authority table**:
   - Tier 1 — strongest for your forum
   - Tier 2 — foundational SC/HC authorities
   - Tier 3 — recent applications across India

   Each row has: case name, court + date, citation, docid link, strength classification, one-line why-it-matters.

7. **Offers to pull full judgment text** for the highest-value cases — but waits for your confirmation. Judgment files are large.

## Why the classification matters

Most legal research tools return a list of cases. This skill forces a distinction between a case that *decided* the point on facts like yours versus one that *mentioned* it in passing. The difference matters enormously when you're arguing before a bench — a "ratio on point" from the same court is worth ten general observations from the Supreme Court.

## Requirements

- A Claude client that supports agent skills (Claude Code, Cowork, or compatible Claude API setup)
- An [Indian Kanoon API token](https://api.indiankanoon.org) — free to get on signup, comes with ₹500 free credit (~10,000 requests)
- `curl` and `jq` installed (for the bundled scripts)

## Setup

**1. Get an Indian Kanoon API token**

Sign up at [api.indiankanoon.org](https://api.indiankanoon.org). You get ₹500 free credit on signup (~10,000 requests).

**2. Set the token in your environment**

```bash
export IK_TOKEN='your-token-here'
```

Or save it to `~/.config/indiankanoon/token` for persistence.

**3. Install the skill**

Copy this repo into your Claude skills directory, or point your Claude setup at it. The skill is invoked when you ask for Indian legal research and have an IK token available.

## Bundled scripts

The scripts are thin `curl` wrappers — all research intelligence is in the skill prompt, not the scripts.

| Script | What it does |
|---|---|
| `scripts/ik_search.sh <query> <pagenum> <outfile>` | POST to `/search/` with URL encoding and auth header |
| `scripts/ik_doc.sh <docid> <outfile>` | POST to `/doc/<docid>/` for full judgment text |
| `scripts/ik_lookup_anchor.sh <case_name>` | Search by party name, return top 5 candidates sorted by date ascending |

All scripts require `IK_TOKEN` in env and fail loudly if it's missing.

## Reference files

- `references/api.md` — Indian Kanoon API endpoints, parameters, response schema
- `references/query-patterns.md` — Full catalogue of query techniques: `citedby:`, `cites:`, phrase quoting, doctype codes (all High Courts listed), facet narrowing, date filters, intersection queries, worked examples

Read `references/query-patterns.md` if you want to understand the query logic or adapt it for a different research tool.

## Honest limitations

- Requires an Indian Kanoon API token — not usable without one.
- Quality depends on the anchor cases identified in Step 3. If the anchor docid is wrong (e.g. a later citing case instead of the original), the citation-graph queries return noise.
- Does not pull full judgment text automatically — you have to request it. This is intentional (files are large) but means the skill cannot quote specific paragraphs without a second step.
- The skill is as good as the angle decomposition in Step 2. Shallow decomposition → shallow results.

## Feedback and collaboration

If you're a lawyer, law student, or researcher using Indian Kanoon for case law research — feedback on the query patterns and tier classification is welcome. Open an issue or reach out.
