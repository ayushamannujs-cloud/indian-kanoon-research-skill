# Indian Kanoon — Query Patterns

The Indian Kanoon search engine is a citation-graph database with keyword search bolted on. The single biggest unlock is to **stop treating it like Google** and start using its citation operators.

## Table of contents

1. The citation operators (`citedby:`, `cites:`) — the strongest tools
2. Phrase quoting
3. Doctype filter and full court code table
4. Facet narrowing (`+tag:`, `+year:`, `+authorid:`, `+benchid:`)
5. Date range parameters
6. Intersections (multi-pillar queries)
7. Worked examples
8. Common pitfalls

---

## 1. Citation operators

### `citedby:<docid>` — every later case citing this anchor

This is the highest-precision operator on the entire API. Use it as your first move once you've identified an anchor case.

```
citedby:853800                                   # every case citing tid 853800 (Hridaya Ranjan)
citedby:853800 doctypes:supremecourt             # only SC citations
citedby:853800 doctypes:karnataka year:2024      # Karnataka HC, 2024 only
```

### `cites:<docid>` — every case the anchor itself cites

Back-tracking. When you find one perfect HC judgment and want its full case-law spine.

```
cites:128975041                                  # every case cited by Kakarlapudi
```

### Intersections

Combine to find cases that cite BOTH anchors — the strongest dual-pillar precedents.

```
citedby:853800 citedby:1841921                   # cite both Hridaya Ranjan AND Satvinder Kaur
```

---

## 2. Phrase quoting

Wrap multi-word legal terms of art in double quotes:

```
"section 482"
"dishonest intention"
"cause of action"
"breach of contract"
"prima facie"
"abuse of process"
"commercial quantity"
```

Single-word terms don't need quoting. Quote phrases that would otherwise match unrelated documents containing the same individual words.

---

## 3. Doctype filter — full code table

Use `doctypes:<code>` or `doctypes:<code1>,<code2>,...` to restrict the corpus.

### Aggregate codes

| Code | What |
|---|---|
| `supremecourt` | Supreme Court of India |
| `highcourts` | All High Courts |
| `scorders` | SC orders (non-judgment) |
| `judgments` | All judgments (SC + HCs) |
| `laws` | Statutes / acts |
| `tribunals` | Tribunals |

### High Courts (individual codes)

| Code | Court |
|---|---|
| `karnataka` | Karnataka High Court |
| `chennai` | Madras High Court |
| `delhi` | Delhi High Court |
| `delhiorders` | Delhi High Court — Orders |
| `bombay` | Bombay High Court |
| `allahabad` | Allahabad High Court |
| `punjab` | Punjab & Haryana High Court |
| `madhyapradesh` | MP High Court |
| `kolkata_app` | Calcutta HC (Appellate Side) |
| `calcutta` | Calcutta High Court |
| `gujarat` | Gujarat High Court |
| `kerala` | Kerala High Court |
| `telangana` | Telangana HC |
| `amravati` | AP HC, Amaravati |
| `jaipur` | Rajasthan HC, Jaipur Bench |
| `jodhpur` | Rajasthan HC, Jodhpur Bench |
| `patna` | Patna High Court |
| `patna_orders` | Patna HC — Orders |
| `jharkhand` | Jharkhand HC |
| `gauhati` | Gauhati HC |
| `chattisgarh` | Chattisgarh HC |
| `uttaranchal` | Uttarakhand HC |
| `jammu` | J&K HC (Jammu) |
| `srinagar` | J&K HC (Srinagar) |
| `sikkim` | Sikkim HC |
| `tripura` | Tripura HC |
| `meghalaya` | Meghalaya HC |
| `manipur` | Manipur HC |
| `himachal` | Himachal HC |

### District / tribunal / regulator codes (selected)

| Code | What |
|---|---|
| `bangaloredc` | Bangalore District Court |
| `delhidc` | Delhi District Court |
| `consumer_national` | National Consumer Disputes Redressal Comm. |
| `consumer_state` | State CDRCs |
| `cat_bangalore` | Central Administrative Tribunal, Bangalore |

---

## 4. Facet narrowing

The response JSON's `categories` field contains pre-formatted facet URLs. Patterns you can append to any query:

```
+tag:power-high-court-for-quashing       # IK's auto-classified category
+tag:cheating
+tag:indian-penal-code
+year:2024
+year:2025
+authorid:m-nagaprasanna                 # specific judge as author
+benchid:m-nagaprasanna                  # bench (single-judge bench)
+doctypes:karnataka                      # equivalent to top-level doctypes filter
```

You can chain multiple narrows in one query.

---

## 5. Date range parameters

Pass `fromdate` and `todate` as separate POST params (not inside `formInput`):

```
fromdate=01-01-2020
todate=31-12-2026
```

Format: `DD-MM-YYYY`. Useful for stripping out pre-2000 noise. (The `ik_search.sh` wrapper doesn't pass these by default — call curl directly, or use the inline `year:` filter instead for single years.)

---

## 6. Intersections — multi-pillar queries

Whenever a petition relies on two doctrinal pillars (e.g. inception-intent rule + territorial jurisdiction), the strongest precedents are the ones citing both anchors. Combine `citedby:` operators:

```
citedby:<HRPV_DOCID> citedby:<YAA_DOCID> doctypes:highcourts year:2024
```

These tiny result sets are gold — every hit is a judgment that already does the synthesis you're about to argue.

---

## 7. Worked examples

### Example A — Quashing a criminal case for credit-card default

```
# Pillar 1: inception-intent (Hridaya Ranjan citation graph) in user's forum
citedby:853800 doctypes:kolkata_app,calcutta

# Pillar 2: territorial jurisdiction recent applications
citedby:<YAA_DOCID> doctypes:supremecourt,highcourts year:2024

# Pillar 3: bank-recovery abuse
"ICICI Bank" "Prakash Kaur" doctypes:supremecourt,highcourts

# Big-tent civil-dispute angle
"civil dispute" "criminal complaint" quashing loan doctypes:supremecourt,highcourts
```

### Example B — Anticipatory bail in NDPS case

```
# Anchor SC case search (find docid first)
"Tofan Singh" NDPS doctypes:supremecourt

# Section 37 twin-conditions in user's forum
"section 37" NDPS "anticipatory bail" "commercial quantity" doctypes:bombay

# Recent SC applications
citedby:<S37_ANCHOR_DOCID> doctypes:supremecourt year:2024
```

### Example C — Specific performance vs. damages in real estate

```
# Section 14 Specific Relief Act amendment, post-2018
"specific performance" "section 14" "2018 amendment" doctypes:supremecourt,highcourts

# Cited authorities
cites:<KEY_HC_JUDGMENT_DOCID>
```

---

## 8. Common pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Broad keyword query | Top hits are Kesavananda, Puttaswamy, S.P. Gupta | Add `doctypes:` filter + phrase quote |
| Citation-weighted noise | Same mega-cited case across multiple unrelated queries | Use `citedby:<anchor_docid>` to bypass ranking |
| Wrong docid for anchor | Citation graph returns nothing or wrong cases | Re-run `ik_lookup_anchor.sh`; pick the **earliest SC** decision, not a later HC that cites it |
| Transliteration variance | Named search returns nothing for a real case | Try variant spellings ("Ranjan"/"Rangan"); shorten to distinctive fragment |
| Missing court in facets | Calcutta HC vs Calcutta HC App Side confusion | Always check both `calcutta` and `kolkata_app` doctypes |
| Stale precedent | Cited case has been overruled or distinguished | Run a citator check: `"<case name>" overruled OR distinguished OR doubted` |
| Token leaked in chat | User pasted token in conversation | Tell them to rotate at session end |
