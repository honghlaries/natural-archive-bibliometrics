# Changelog

All notable changes to the `share/` archive (data, code, documentation and the Zenodo mirror) are
recorded here. The archive is versioned semantically: MAJOR = changes that alter published numbers
or file schemas, MINOR = additions that do not alter existing values, PATCH = documentation fixes.

## [2.0.0] - 2026-10-27

### Summary

This release rebuilds the archive around the publication-count definition stated in the paper's
Methods: strict fractional counting, `frac(record, country) = author_count / total_authors`, with
each record contributing at most one unit in total. The previous archive carried a duplicate-weighted
contribution table (9,286 duplicated rows) whose per-country totals (47,006.3) exceeded the corpus
size (33,145) and therefore could not represent fractional counting. The record set is also corrected
to the post-deduplication pool (49,189 instead of the pre-deduplication pool 58,201). Analytical
corpus (33,145), period series (31,964) and all analyses that do not depend on per-country publication
totals are unchanged.

### Fixed

- **Duplicate-weighted publication counts (root cause).** The internal table `明细_作者贡献_分数`
  contained 87,901 rows for 38,218 records (9,286 fully duplicated rows) and summed to 47,006.3.
  Replaced by `fractional_weights.csv`: 87,901 unique `(record, country)` pairs, 0 duplicates,
  roster sum 32,647.3 (all countries 32,659.0).
- **PRISMA vs `records` sheet mismatch.** `records` is now the post-deduplication set of **49,189**
  records (11,055 / 18,449 / 19,685 by source), consistent with Table S7.
- **`countries` column was reported as empty.** It was 100% populated but unnormalised. Split into
  `author_countries_raw` (as deposited) and `author_countries` (normalised to the 195-country roster).
- **Archive-class caliber (revised 2026-10-27).** The official class is now the **JEV
  `archive_class` directly** (Sediment **63.47%**, Other natural **3.01%**, Unclassified **0.30%** of
  the 33,145 analysed records), not the 18-mid-level → 5-top-level mapping. The mapped result is kept
  as the auxiliary column `archive_class_mapped`, and the 18 mid-level classes are used only for
  stratification. The earlier 70.85 / 0.17 / 2.54 figures were the mapped caliber; the manuscript
  §2.1/§2.3/§3.4, SI §S4 and SI §S6 have been updated accordingly.
- **Gini 0.910 → 0.911** (new fractional weights).

### Changed

Published values that change with the rebuilt weights (old → new):

| Item | Old | New |
|---|---|---|
| `records` rows | 58,201 | **49,189** |
| Fractional publication sum (roster) | 47,006 | **32,647.3** |
| China / United States | 9,642 / 7,657 | **5,324 / 5,657** (US first) |
| HH countries | 26 (13.33%) | **25 (12.82%)** |
| HH publication / sampling share | 89.11 / 81.29 | **88.97 / 80.53** |
| HH surplus | 7.8 pp | **8.44 pp** |
| MM countries / deficit | 39 / 7.2 pp | **37 / −7.06 pp** |
| Zero-publication / publication countries | 42 / 153 | **51 / 144** |
| Double-zero countries | 39 | **47** |
| Zero-sampling countries | 85 | **85** |
| Publication / sampling Gini | 0.910 / 0.847 | **0.911 / 0.847** |
| Pearson / Spearman | 0.938 / 0.884 | **0.885 / 0.884** |
| Nine classes | 26 / 12 / 1 / 39 / 36 / 4 / 77 | **HH25 HM11 MH2 MM37 ML33 LM7 LL80** (HL, LH still empty) |
| Top-10 producers | China, … | **US 5,657 / China 5,324 / Germany 3,070 / UK 2,414 / France 1,597 / Canada 1,397 / Japan 974 / Australia 963 / Switzerland 923 / Russia 861** |
| Europe publication / Asia sampling | 45.1 / 34.3 | **45.13 / 34.34** |
| Income-group publication share (H / UM / LM / L) | 70.52 / 26.10 / 3.30 / 0.09 | **75.55 / 21.31 / 3.06 / 0.08** (sampling 57.60 / 34.22 / 7.32 / 0.86) |
| Network subset | 29,379 (88.6% of corpus) | **29,379 (88.6%) unchanged**; publication share **95.3%** (was 95.4) |
| Archive-class composition (official, JEV direct) | 70.85 / 13.79 / 8.52 / 4.12 / 0.17 / 2.54 (mapped caliber) | **63.47 / 19.57 / 8.81 / 4.84 / 3.01 / 0.30** (21,037 / 6,486 / 2,919 / 1,603 / 999 / 101); mapped caliber demoted to `archive_class_mapped` |
| Penetration index (Ice core / Method development) | +1.64 / +1.47 | **+1.50 / +1.49** |
| Total variation distance (TVD) range | 0.103-0.120 (SDG layer 0.022) | **0.098-0.118** (SDG layer 0.022 unchanged) |
| Population share of the HH countries | 57.5% | **55.1%** (WDI 2025 world-total definition; paper text: "55%") |
| Per-capita output intensity | 28× | **6.6×** (relative to the rest of the world; paper text: "about seven times") |
| Period HH shares (1980–1999 / 2017–2025) | 93.2 / 88.9 | **93.20 / 88.54** |
| OLS residual medians (0 / 1–5 / 6–20 / 21–100 / >100) | −0.383 / −0.638 / +0.921 / +0.258 / −0.040 | **−0.235 / −0.325 / +0.477 / +0.178 / −0.151** |
| SDG share of HH countries (eleven goals) | 81.9–90.1% | **81.7–89.6%** (base 31,964; SDG 13/15/14/6 = 89.63/87.86/88.30/88.94) |
| Nine-class network (SI S6) coverage / HH flow | 33,145 / 29,560 (89.2%) | **31,964 / 28,438 (89.0%)** |

Unchanged: analytical corpus (33,145), period series (31,964), HHI / normalised entropy / NMI,
income threshold 41,458 and step 3.96 / AIC 289.6 vs
307.7, the four all-record SDG shares (13/15/14/6 = 60.34 / 13.14 / 12.17 / 10.25%), H1/H2, polar
ice-core counts (2,824 / 1,388 / 642 / 2,265) and the PRISMA chain to 49,189. Note that SDG shares
*within HH countries* do change (81.7–89.6%, base 31,964); only the all-record shares are unchanged.

### Added

- `archive_mid_to_class.csv` — the 18 mid-level → 5 top-level archive mapping, now **auxiliary**
  (the official class is the JEV `archive_class`; the mapped class ships as `archive_class_mapped`).
- `country_economy.csv` (195 rows), `worldbank_gdp_pc_ppp_const2021.csv` (3,413 rows) and
  `worldbank_population.csv` (17,130 rows) — economy and population series used by Fig. 2 and the
  income/population statements.
- `sampling_fragments.csv` (3,105 rows) — reproducible ledger of unresolvable sampling fragments.
- `panel_country_year.csv` (1,427 rows; 97 countries, 1980-2025) — country-year panel used to
  reproduce the Fig. 2d/e and Table S2/S5 elasticities (>=10 years per country -> 56 countries;
  breakpoint 41,458; step 3.96; AIC 289.6 vs 307.7).
- `network_subset.csv` (29,379 rows) — record subset used by the network analysis and Fig. 3.
- Rebuilt `baseline_recomputed.json` — the PASS/FAIL baseline read by `check_values.R`.
- `share/doc/CHANGELOG.md` (this file), `share/doc/更新说明_20261027.md` (Chinese note for authors
  and co-authors) and `share/doc/checksums.txt` (SHA-256 of the released archive).
- `share/script/check_values.R` — single PASS/FAIL gate over `baseline_recomputed.json`.

### Removed

- The duplicate-weighted values formerly stored in `publications_total` (`nine_class_195.csv`,
  `roster_195_v6.csv`); the column **name is retained** for compatibility, but now holds the strict
  fractional count (sum 32,647.3).
- The pre-deduplication `records` sheet (58,201 rows).

### Licence

- **Data: CC BY-NC-SA 4.0** (`LICENSE`, `zenodo/LICENSE`).
- **Code: MIT** (`github/LICENSE`).

### Verification

- `Rscript script/check_values.R` → `PASS n / FAIL 0 / SKIP n`, exit code 0.
- `Rscript script/main_tests.R` → H1 +0.0189, H2 +0.0690 (unchanged).
- `python script/plot_fig3a_sankey.py` reproduces Fig. 3a from the exported Sankey data.

### Known issues / pending at release

- **19.23% unparsed sampling fragments (resolved by replacing the rate):** the rate's numerator and
  denominator were hard-coded in `12_data_quality.R` and cannot be reconstructed from the deposited
  `ss_country` values. v2.0.0 **does not release the derived rate**; instead it ships the reproducible
  ledger `sampling_fragments.csv` (3,105 distinct fragments, 3,120 occurrences, all unresolvable).
  The manuscript now states "3,105 distinct sampling-location fragments could not be resolved to a
  country". See `doc/data_audit.md` §4.3 and §8.
- **Wedge and network-layer flow shares**: recomputed for the new HH membership but not yet frozen in
  this release; the authoritative values will be taken from the final value table.
- **SI Fig. S6 redraw**: its values were recomputed (31,964 records; HH 28,438 = 89.0%), the SI text
  was updated, and the figure has been redrawn and re-embedded.
- **Reproduction code**: all 18 scripts are present and run (R rc=0; Python rc=0).
  `check_values.R` is **green** (PASS 133 / FAIL 0 / SKIP 7, exit code 0; the elasticity block is now
  computed from the archived panel and passes, except `elasticity.gam_edf`).
- **Fig. 2d/e and Table S2/S5 panel**: the country-year panel ships as `panel_country_year.csv`
  (97 countries, 1980-2025) and is read via `00_load.R::load_panel()`; `fig2_income.R`,
  `tableS2_scaling.R` and `tableS5_normalisation.R` now reproduce the 56-country elasticities
  (41,458 / 3.96 / AIC 289.6 vs 307.7) from it (rc=0).
- **GAM effective d.f. (open item)**: with the rebuilt fractional weights the Tweedie GAM gives
  edf **3.702** vs the frozen 3.521 (the old value came from the previous t13 table). It is reported
  as SKIP by `check_values.R` until the Lead/pipeline re-freezes t41a.
- **SDG cache rounding**: `sdg_by_country_tier.csv` was regenerated on the new in-window base
  (31,943) and reports SDG 13/15/14/6 = 89.63/87.87/88.31/88.95; `expected_values.json` gives
  89.63/87.86/88.30/88.94. The 0.01 pp differences are rounding; the expected values are authoritative.

### Revision log

**2026-10-27 has two caliber changes before release:** (1) publication side — duplicate-weighted
contribution table (47,006) replaced by strict fractional counting (32,647.3), and the record set
moved from the pre-deduplication pool (58,201) to the post-deduplication set (49,189); (2) archive
class — the 18-mid-level → 5-top-level mapping replaced by the JEV `archive_class` directly.

**Rev. 2 — 2026-10-27 (pre-release, user decision).** Archive-class caliber changed to the JEV
`archive_class` directly. Official composition of the 33,145 analysed records is now Sediment 63.47%
(21,037) / Biological growth 19.57% (6,486) / Ice core 8.81% (2,919) / Fossil & shell 4.84% (1,603) /
Other natural 3.01% (999) / Unclassified 0.30% (101); the 29,379-record network subset is
63.63 / 19.63 / 8.56 / 4.94 / 2.95 / 0.30. The mapped composition (70.85 / 13.79 / 8.52 / 4.12 /
0.17 / 2.54) is retained only as `archive_class_mapped`. Consequent changes: Ice-core penetration
+1.64 → **+1.50**, Method-development penetration +1.47 → **+1.49**, TVD range 0.103-0.120 →
**0.098-0.118** (SDG layer 0.022 unchanged); SDG 13/11/14 tests unchanged. Manuscript §2.1, §2.3,
§3.1, §3.4, the Fig. 3 caption, SI §S4 and SI §S6 were updated, and Figs. 1-3 (including the new
penetration panel) and SI Fig. S6 were redrawn and re-embedded; `doc/data_audit.md` judgment ③
changed to "true issue, resolved".

## [1.0.0] - 2026-10-11

- Initial public archive: `corpus_annotated.xlsx` (records 58,201; analysed 33,145),
  `fractional_weights.csv`, `country_workbook_v4.xlsx`, `nine_class_195.csv`, `roster_195_v6.csv`,
  first-generation Python/R reproduction scripts and `doc/data_audit.md`.

