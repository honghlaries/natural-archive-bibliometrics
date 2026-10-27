# Analysis code — Uneven evidence for a shared planet

Analysis code for the paper *Uneven evidence for a shared planet, sampling and publication are
coupled worldwide*.

This repository contains the **code only**. The annotated dataset is archived on Zenodo
(concept DOI **10.5281/zenodo.23294431**, version 2.0.0, 2026-10-27). Download and unpack the
archive, point `PAPER_DATA_DIR` at it (or place it in `data/`), then run the scripts below.

- **Code licence**: MIT (`LICENSE`)
- **Data licence**: CC BY-NC-SA 4.0 (see the archive `LICENSE`)

---

## What is in here

```
script/
├── 00_load.R                   # single data entry point (paths, country normalisation, helpers)
├── fig1_geography.R            # Fig. 1a-c: geography, nine classes, concentration
├── fig1_wedge.R                # Fig. 1d-e: publication-vs-sampling wedges by archive type
├── fig2_income.R               # Fig. 2a-e: income, scaling, threshold, residuals (Tweedie GAM)
├── fig3_network.R              # Fig. 3a: five-layer network flows (exports Sankey data)
├── fig3b_penetration.R         # Fig. 3b: penetration index by country tier
├── figS6_nine_class_network.R  # Fig. S6: nine-class network robustness
├── figS7_growth.R              # Fig. S7: growth and period series
├── tableS1_goals_by_period.R   # Table S1: SDG goals by period
├── tableS2_scaling.R           # Table S2: scaling regressions
├── tableS3_data_quality.R      # Table S3: data-quality diagnostics
├── tableS4_archive_contrasts.R # Table S4: archive-type contrasts (H1/H2 support)
├── tableS5_normalisation.R     # Table S5: normalisation and concentration metrics
├── tableS7_prisma.R            # Table S7: PRISMA flow (49,189 → 33,145)
├── tableS8_review_robustness.R # Table S8: review-article robustness
├── main_tests.R                # H1 (marine vs lake) and H2 (ice core vs tree ring) tests
├── check_values.R              # PASS/FAIL gate for every reported value
└── plot_fig3a_sankey.py        # Fig. 3a rendering (Python/matplotlib; reads data from fig3_network.R)
```

Helper modules may be added by the scripts; everything else is generated output.

### Delivery status (as of 2026-10-27)

| Status | Scripts |
|---|---|
| Delivered and run | All 18 scripts (17 R scripts rc=0; `plot_fig3a_sankey.py` rc=0); `check_values.R` **PASS 133 / FAIL 0 / SKIP 7**, exit code 0 |

All 18 scripts are present and run. `check_values.R` is green (`PASS 133 / FAIL 0 / SKIP 7`; SKIPs
are by design, including the elasticity block frozen from the main pipeline). The elasticity block is marked SKIP **by design** in `check_values.R`: the
authoritative values are frozen from the main pipeline (41,458 / 3.96 / AIC 289.6 vs 307.7 /
56 countries / 42 above pooled / edf 3.521), not re-fitted by the checker. There is no separate
`tableS6` script (the S6 mapping table ships with the data as `archive_mid_to_class.csv`, auxiliary).
SI Fig. S6 has been redrawn and re-embedded; its values are 31,964 / 28,438 / 89.0%.

---

## Requirements

| Component | Version used | Packages |
|---|---|---|
| R | 4.5 | dplyr, tidyr, readr, readxl, jsonlite, mgcv (Tweedie GAM in Fig. 2) |
| Python | 3.12+ | matplotlib (Fig. 3a only) |

The R scripts are the primary implementation. Python is used only to render the Sankey diagram,
because the original layout is a matplotlib plot; no Python statistics are needed.

---

## Data

1. Download the Zenodo archive (concept DOI **10.5281/zenodo.23294431**).
2. Either unpack it into `data/` next to `script/`, or set:
   ```
   export PAPER_DATA_DIR=/path/to/unpacked/archive
   ```
3. `script/00_load.R` reads all inputs from there; no other paths are hard-coded.

The archive contains the 49,189-record deduplicated corpus, the 33,145-record analysed corpus,
strict fractional-counting weights, the country typology, the sampling-location detail, the
economy/population series used by Fig. 2, and the country-year panel `panel_country_year.csv`
(97 countries, 1980-2025) used to reproduce the 56-country elasticities (Fig. 2d/e, Table S2/S5).

---

## Run

```
# optional self-check of the data entry point
Rscript script/00_load.R

# figures
Rscript script/fig1_geography.R
Rscript script/fig1_wedge.R
Rscript script/fig2_income.R
Rscript script/fig3_network.R
python  script/plot_fig3a_sankey.py      # after fig3_network.R
Rscript script/fig3b_penetration.R
Rscript script/figS6_nine_class_network.R
Rscript script/figS7_growth.R

# tables
Rscript script/tableS1_goals_by_period.R
Rscript script/tableS2_scaling.R
Rscript script/tableS3_data_quality.R
Rscript script/tableS4_archive_contrasts.R
Rscript script/tableS5_normalisation.R
Rscript script/tableS7_prisma.R
Rscript script/tableS8_review_robustness.R

# main tests and full value check
Rscript script/main_tests.R
Rscript script/check_values.R
```

`check_values.R` reads `baseline_recomputed.json` from the data directory and prints one line per
check, ending with `PASS n / FAIL n / SKIP n`. Current result: **PASS 133 / FAIL 0 / SKIP 7**, exit
code 0. The elasticity block is SKIP by design (frozen from the main pipeline, not re-fitted).

---

## Reproduction map

| Script | Output | Status | Key values (v2.0.0) |
|---|---|---|---|
| `fig1_geography.R` | Fig. 1a-c | ✅ | 49,189 records; 33,145 analysed; nine classes HH 25 / HM 11 / MH 2 / MM 37 / ML 33 / LM 7 / LL 80; publication Gini 0.911, sampling Gini 0.847; Pearson 0.885, Spearman 0.884 |
| `fig1_wedge.R` | Fig. 1d-e | ✅ | archive-class composition (JEV direct) 63.47 / 19.57 / 8.81 / 4.84 / 3.01 / 0.30; mapped caliber kept as `archive_class_mapped` |
| `main_tests.R` | H1/H2 | ✅ | H1 +0.0189 (0.8748 vs 0.8559); H2 +0.0690 (0.9742 vs 0.9052) |
| `fig2_income.R` | Fig. 2a-e | ✅ landed | income threshold 41,458 (2021 PPP intl $); step 3.96; high-income publication share 75.55% |
| `fig3_network.R` + `plot_fig3a_sankey.py` | Fig. 3a | ✅ landed | network subset 29,379 records (88.6% of corpus; 95.3% of fractional publications); SDG 13/15/14/6 = 60.34 / 13.14 / 12.17 / 10.25% |
| `fig3b_penetration.R` | Fig. 3b | ✅ landed | SDG shares by country tier; HH share of eleven goals 81.7-89.6% |
| `tableS7_prisma.R` | Table S7 | ✅ landed | 49,189 = 11,055 + 18,449 + 19,685 -> 33,145 analysed |
| `check_values.R` | full numeric gate | ✅ | PASS/FAIL over baseline_recomputed.json (PASS 133 / FAIL 0 / SKIP 7; exit code 0) |

Values that are unchanged from v1.0.0 (H1/H2, archive composition, all-record SDG shares, ice-core
counts) and values that changed with the rebuilt fractional weights (China/US, HH/MM counts,
zero-publication countries, SDG shares within HH countries, period HH shares, residuals,
population/intensity) are documented in the archive `doc/data_audit.md` and `doc/CHANGELOG.md`.

---

## Citation

Please cite the manuscript and the archived dataset. Metadata: `CITATION.cff`.

## Licence

Code: **MIT** (see `LICENSE`). Data: **CC BY-NC-SA 4.0** (see the Zenodo archive).

