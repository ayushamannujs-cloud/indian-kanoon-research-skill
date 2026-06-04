---
name: indian-kanoon-research
description: Research Indian case law on Indian Kanoon (indiankanoon.org) and produce a tiered, citable authority list. Trigger whenever the user asks for Indian legal research using an Indian Kanoon API token.
---

# Indian Kanoon Legal Research

A disciplined research loop for Indian case law. The output is a tiered table — each row has the **docid**, **citation**, and a **one-line "why-it-matters"** — so the user can drop authorities straight into a petition or opinion.

This skill exists because keyword search alone on Indian Kanoon produces noisy, citation-weighted results (Kesavananda Bharati shows up for "default" queries, etc.). The fix is to treat Indian Kanoon as a **citation-graph database with keyword search bolted on**, and search the graph properly.

---

## Step 0 — Setup (do this once per session)

The API needs a token. Check in this order:

1. **`IK_TOKEN` env var** — preferred. If set, use it.
2. **`~/.config/indiankanoon/token`** — fallback file. Read with `cat`.
3. **Ask the user** if neither exists. Tell them: *"Paste the token in chat (I'll use it only via env var, not write it to disk unless you want me to)."*

After obtaining the token, export it once for the session:

```bash
export IK_TOKEN='<token>'
```

**Never echo the token back in chat output.** Treat it like a password. If the user pastes it in chat, gently flag that they should rotate it once research is done.

---

## Step 1 — Interview the user (do not skip)

Before any API call, gather these answers. Do this even when the user has already given a detailed prompt — confirm the gaps.

Use the `AskUserQuestion` tool for the court/forum question because it's the highest-impact filter and users often have an opinion. The others can be inline questions.

### Required answers

1. **Legal question, in one sentence.** ("Can a criminal case for credit-card default be quashed?")
2. **Court / forum preference.** This drives ranking. Ask the user, do NOT guess. Offer at least these options:
   - Supreme Court of India + all High Courts (default — broadest)
   - A specific High Court (Calcutta, Bombay, Delhi, Karnataka, Madras, etc.) — most persuasive before that bench
   - SC only (binding everywhere)
   - SC + a specific HC (common: where proceedings are pending AND/OR where petitioner resides)
3. **Anchor cases the user already knows** (optional but very valuable). If they hand you "Hridaya Ranjan" or "Y. Abraham Ajith," you can do the discovery search and if you find a new case other than which was handed; ask for permission from the user to proceed with search and not jump straight to citation-graph queries. In case user, hasn't given any cases, do the discovery search and show the cases so that user can check before you going to citation graph.
4. **Date range** (optional). Default: last 10 years for HC follow-ups; no limit for foundational SC.
5. **Specific statutes / sections** (optional). Helps when the legal issue maps to a particular IPC/CrPC/Act section.

Always ask all the questions

---

## Step 2 — Decompose the question into legal angles

This is the single most important step and the one most easily skipped. Without it, the searches devolve into keyword guessing.

For each legal question, identify **2-4 independent attack vectors / argument lines**. Each becomes its own search lane.

**Example — "quashing a credit-card default criminal case":**

| Angle | Doctrinal handle | Anchor case (likely) |
|---|---|---|
| Substantive — ingredients not met | Essential **ingredients** of cheating (IPC 415/420): deception + dishonest inducement + dishonest intent *at the inception* | *Hridaya Ranjan Prasad Verma v. State of Bihar* (2000) 4 SCC 168 |
| Procedural (wrong court) | Territorial jurisdiction; cause of action | *Y. Abraham Ajith v. Inspector of Police* (2004) 8 SCC 100 |
| Conduct (lender abuse) | Recovery cannot be coerced via criminal process | *ICICI Bank v. Prakash Kaur* (2007) 2 SCC 711 |
| Big-tent (civil dressed as criminal) | s.482 quashing on civil-flavoured disputes | *Gian Singh v. State of Punjab* (2012) 10 SCC 303 |

Write the angle table to the user before searching. It gives them a chance to redirect early. Take approval and then move forward.

**If you don't know the anchor case for an angle**, that's fine — Step 4 finds it by named-case search.

### Two depth rules (do not produce shallow results)

These two rules are what separate a usable petition annexure from a generic case list. Apply both.

**1. Research the *ingredients* of any charged section — don't stop at the general principle.**
When a specific offence is charged (IPC 420 cheating, 406 CBT, s.138 NI Act, s.37 NDPS, etc.), make the statutory **ingredients** their own search lane. A quashing petition usually wins by showing the facts fail one or more *essential ingredients*, so a one-line doctrine ("mere breach of contract is not cheating") is the anchor, **not** the deliverable. Concretely:
- Pin down the essential ingredients of the section — from the bare act **and** the leading case that enumerates them (e.g. the elements of s.415 cheating).
- Then find cases that **apply those ingredients to facts like the user's** and hold the offence not made out.
- In the output, tie each ingredient to whether the facts satisfy it, so the user can see where the charge breaks.

**2. For "abuse / harassment" angles, find concrete holdings — not slogans.**
A precedent that merely *observes* "recovery harassment is wrong", or issues general directions (e.g. the "set up a trained recovery agency" remark in the Prakash Kaur line), is **weak** — that is obiter, not a holding on the facts. Hunt instead for cases where a court **actually found** that filing or continuing the criminal case was an abuse/harassment on comparable debt-recovery facts, and granted relief. Capture what those courts treated as *markers of harassment* — e.g. a pending civil recovery suit, part-payments already made, no inception fraud, the complaint timed to coincide with recovery efforts. Those markers are what the user argues, not a general homily.

---

## Step 3 — Look up the docid of each anchor case

Anchor docids unlock the citation-graph queries in Step 4. Find them like this:

```bash
bash scripts/ik_lookup_anchor.sh "Hridaya Ranjan Prasad Verma"
bash scripts/ik_lookup_anchor.sh "Y. Abraham Ajith"
```

The script returns the top 5 candidate hits sorted by date ascending (earliest first), with `tid`, `date`, `court`, `numcitedby`, `title`. The anchor judgment is usually the **earliest Supreme Court** decision in the list — not a later case that cites it. Watch for transliteration variants in case names (e.g. IK lists *Hridaya Ranjan* as "Hridaya **Rangan** Pd. Verma"); if a search returns nothing, try a shorter or variant spelling.

Stash the docids for Step 4.

---

## Step 4 — Run the searches (citation-graph first, keyword last)

Use the search techniques in priority order. Stop when you have enough.

### 4A. Citation-graph search — the strongest tool

For each anchor docid, ask: "what later cases have cited this?" Then filter by court and date.

```bash
# All citing cases, restricted to a specific HC (user's forum)
bash scripts/ik_search.sh "citedby:<ANCHOR_DOCID> doctypes:kolkata_app,calcutta" 0 /tmp/ik_cb_calcutta.json

# All citing cases, SC + HCs only, single recent year
bash scripts/ik_search.sh "citedby:<ANCHOR_DOCID> doctypes:supremecourt,highcourts year:2025" 0 /tmp/ik_cb_recent.json
```

You can also go the other way — pull every case **a key judgment cites** (useful when you find one perfect HC order and want its full case-law spine):

```bash
bash scripts/ik_search.sh "cites:<HC_BLUEPRINT_DOCID>" 0 /tmp/ik_cites.json
```

**Intersections** (e.g. cases that cite both the substantive anchor AND the jurisdictional anchor) are the strongest dual-pillar precedents:

```bash
bash scripts/ik_search.sh "citedby:<DOCID_A> citedby:<DOCID_B>" 0 /tmp/ik_intersect.json
```

### 4B. Phrase + doctype keyword search — second-best (Compulsory by default)

Even if you have an anchor docid, you should try giving user this options to user for a wider net. Before sending queries to Indian kannon, show what you are sending for approval. use phrase quoting + court filters:

```bash
bash scripts/ik_search.sh '"credit card" quashing "section 482" cheating doctypes:supremecourt,highcourts' 0 /tmp/ik_kw.json
```

Phrase-quote multi-word legal terms (`"section 482"`, `"dishonest intention"`, `"cause of action"`). Single-word terms don't need quotes.

### 4C. Named-case search — third-best, but useful

Fast way to confirm a case exists and find its docid:

```bash
bash scripts/ik_search.sh '"Hridaya Ranjan Prasad Verma" cheating' 0 /tmp/ik_named.json
```

Less precise than `citedby:` but produces a result set of judgments that cite the anchor in their text.

### 4D. Facet narrowing — used inside any of the above

Indian Kanoon's response JSON returns facet URLs you can append to the query to drill down without re-querying:

- `+doctypes:karnataka` — restrict to Karnataka HC
- `+year:2024` — single year
- `+authorid:m-nagaprasanna` — specific judge
- `+benchid:m-nagaprasanna` — bench
- `+tag:power-high-court-for-quashing` — IK's auto-tagged AI category

Date range via separate POST params (the wrapper does not pass these by default — add to the curl if needed):
- `fromdate=01-01-2020&todate=31-12-2026` (format `DD-MM-YYYY`)

### Stop condition

Stop search and ask user whether he wants to continue when you have:
- 1-2 strong hits for the user's preferred forum (their court)
- 3-5 foundational SC authorities
- 5-10 recent HC applications across India

If the count is much lower for a given angle, that angle is weak — flag it to the user rather than padding.

---

## Step 5 — Read result fields properly

Each hit in the response JSON has six fields that matter:

| Field | Meaning | Use for |
|---|---|---|
| `tid` | Stable docid — pass to `/doc/<tid>/` for full text | The docid you put in the output table |
| `title` | Case name + date | Display name |
| `docsource` | Court / tribunal | Forum match score |
| `publishdate` | Decision date | Recency score |
| `headline` | Snippet with bolded keyword matches | Triage — does the case actually say what we need? |
| `numcitedby` | Number of later cases citing this | Authority weight |
| `citation` | AIR / SCC citation, when present | Formal citation in output |

Triage by reading `headline` snippets. If the snippet shows the keyword in the rhetoric you need ("dishonest intention from the inception" / "no cause of action arose"), it's a real hit. If the snippet is about something else, skip it.

**Classify each kept case by strength of support — this is mandatory.** A snippet that *mentions* your point is not the same as a case that *decides* it. Tag every case as one of:

- **Ratio (on point)** — the court actually *held* the supporting proposition while deciding facts like the user's, and granted relief. Strongest; lead with these.
- **Foundational** — the leading authority that lays down the test or the ingredients (may be on different facts, but binding doctrine).
- **Observation only (obiter / direction)** — the case merely *remarks* the point in passing, or issues general directions, without holding it on comparable facts.

When the headline is ambiguous about which of these a case is (common for the "harassment" line), pull the judgment with `ik_doc.sh` before tagging it — do not guess it up to "Ratio". Keep observation-only cases (per the user's preference) **but you must flag them as such** so a weak authority is never presented as if it were a holding. A general line like "harassment should not happen in debt recovery" is *observation only*, never sufficient support on its own.

**Do not invent docids or citations.** Every docid in the output must come from an actual API response. If you're unsure a case exists, search for it.

---

## Step 6 — Offer to Tier the results (optional)
Rank every kept case by three axes:

1. **Doctrinal fit** — does the holding actually support the user's argument? (highest weight)
2. **Forum match** — user's preferred court > same High Court > SC > other HCs
3. **Recency** — recent HC applications often outrank older SC dicta in persuasion before the same bench (the bench can see itself applying the principle)

Bucket into:

- **Tier 1 — Strongest for *this* case.** 3-7 cases. Same court as user's forum, or directly on the user's fact pattern, or SC with same-state link.
- **Tier 2 — Foundational SC / leading HC authorities.** 5-12 cases. The doctrinal source for each angle, plus the seminal procedural cases.
- **Tier 3 — Recent applications across India.** 5-15 cases. Shows the law is alive and being applied. Especially valuable when the user's forum has no recent case on point.

Optional further tiers (one per distinct angle) if the case has multiple distinct argument lines each needing its own list.

---

## Step 7 — Output format

Use this structure. Markdown tables only — no prose summaries of individual cases. If you offered tiering in Step 6 and the user declined, drop the Tier 1/2/3 split and present a single flat **Authorities** table — keep all the same columns, including Strength.

```markdown
# [Topic] — Indian Kanoon Research

## Background
[2-3 lines on the legal question and angles identified.]

## Angles searched
| Angle | Doctrinal handle | Anchor docid |
|---|---|---|
| … | … | … |

## Ingredients check (include whenever a specific section is charged)
| Ingredient of [section, e.g. s.415 cheating] | Do the facts satisfy it? | Supporting case(s) |
|---|---|---|
| … | likely not / disputed / yes | [tid](https://indiankanoon.org/doc/[tid]/) |

## Tier 1 — Strongest authorities   (use a single flat "Authorities" table instead if Step 6 tiering was skipped)
| # | Case | Court / Date | Citation | docid | Strength | Why it matters |
|---|---|---|---|---|---|---|
| 1 | **[Case name]** | [Court], [Date] | [AIR/SCC cite or —] | [tid](https://indiankanoon.org/doc/[tid]/) | Ratio / Foundational / Observation only | [one line] |

## Tier 2 — Foundational authorities
[same table format]

## Tier 3 — Recent applications
[same table format]

## Suggested next step
[One paragraph: which full judgment(s) to pull next via /doc/<tid>/, and what to look for.]
```


**"Why it matters" rules:**

- One sentence. Imperative or active voice.
- Quote the operative phrase from the headline if it's tight, otherwise paraphrase.
- Mention the relief granted ("FIR quashed", "criminal complaint quashed", "petition allowed", "bail granted/denied").
- Highlight forum match: *"Same court as user's pending matter"* or *"SC, binding"* if applicable.
- For an **Observation only** case, say so plainly in the cell (e.g. "general remark, not a holding — persuasive colour only") so it is never mistaken for a decided point.

**Example rows:**

```
| 1 | **Kakarlapudi Venkata Madhava Varma v. State of West Bengal** | Calcutta HC (App. Side), 12 Dec 2025 | — | [128975041](https://indiankanoon.org/doc/128975041/) | Ratio (on point) | Same court; quashed a debt-default cheating case for want of inception intent — blueprint on the facts. |
| 2 | **Hridaya Ranjan Prasad Verma v. State of Bihar** | SC, 2000 | (2000) 4 SCC 168 | [853800](https://indiankanoon.org/doc/853800/) | Foundational | Lays down the ingredients of cheating: dishonest intent must exist at inception; mere breach / failure to repay is not cheating. |
| 3 | **Ms. Tanisha Chanda v. State of West Bengal** | Calcutta HC (App. Side), 19 Apr 2024 | — | [161412716](https://indiankanoon.org/doc/161412716/) | Observation only | Mentions ICICI v. Prakash Kaur on recovery harassment as a general remark/direction — persuasive colour, NOT a holding on these facts; do not lead with it. |
```

---

## Step 8 — Offer to pull full judgments

After delivering the tiered tables, offer to fetch full text of the highest-value cases (typically Tier 1 #1-3) so the user can extract citable paragraphs:

```bash
bash scripts/ik_doc.sh <docid> /tmp/ik_doc_<docid>.json
```

Don't pull full text proactively — judgment files can be very large and slow. Wait for the user to confirm which they want.

---

## Bundled scripts

- `scripts/ik_search.sh <query> <pagenum> <outfile>` — POST `/search/`. Handles URL encoding, auth header, output file.
- `scripts/ik_doc.sh <docid> <outfile>` — POST `/doc/<docid>/` for full judgment.
- `scripts/ik_lookup_anchor.sh <case_name> [doctype]` — search by party name, return top 5 candidate docids sorted by date.

All scripts require `IK_TOKEN` in env. They fail loud if it's missing. `ik_lookup_anchor.sh` also needs `jq`.

---

## Reference files

- `references/api.md` — Indian Kanoon API endpoints, parameters, response schema.
- `references/query-patterns.md` — Full catalogue of query techniques: phrase quoting, doctype codes, AI tags, facet syntax, citation-graph operators, date filters, intersections, and worked examples.

Read `references/query-patterns.md` whenever you need a query pattern you haven't used before — it has the full doctype code table (`kolkata_app` vs `calcutta` etc.) and example combinations.

---

## Anti-patterns (what *not* to do)

1. **Do not assume the user's preferred forum.** Always ask. Persuasion weight depends on it.
2. **Do not run broad keyword queries without `doctypes:` filter.** You will get Kesavananda Bharati ranked above the actual answer because IK weights by `numcitedby`.
3. **Do not summarise individual cases in prose.** The user wants a tabular authority list to paste into a petition. Stick to the table format.
4. **Do not echo the API token in chat output, ever.** Even partial. Even "just to confirm."
5. **Do not pull full judgments speculatively.** Wait for the user to pick which ones. Full text fetches are large.
6. **Do not skip the angle decomposition (Step 2).** Without it the searches are guessing.
7. **Do not invent docids or citations.** Every docid must come from a real API response.
8. **Do not pass off observations/dicta as holdings.** A passing remark or general direction (e.g. "recovery harassment is bad") is weak support. Find a case that *holds* the point on comparable facts; if you keep an observation-only case, flag it as such in the Strength column.
9. **Do not stop at the general principle when a section is charged.** Research the section's *ingredients* and show, ingredient by ingredient, where the facts fail — a doctrinal one-liner is the anchor, not the deliverable.
