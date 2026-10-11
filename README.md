<https://github.com/honghlaries/natural-archive-bibliometrics>

# Uneven evidence for a shared planet — analysis code

Analysis code for the paper *Uneven evidence for a shared planet, sampling and publication are coupled worldwide*.

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23294431.svg)](https://doi.org/10.5281/zenodo.23294431)


---

## Data

The dataset is archived separately on Zenodo:

> **DOI**: 10.5281/zenodo.23294431

After downloading, either unpack into `data/`:

    mkdir -p data
    unzip ~/Downloads/zenodo-dataset.zip -d data/

or point the loader at the unpack directory:

    export PAPER_DATA_DIR=/path/to/dataset        # Linux / macOS
    $env:PAPER_DATA_DIR = 'D:\path\to\dataset'   # Windows PowerShell

The loader searches `PAPER_DATA_DIR`, `./data/`, `../data/` and the script directory, in that order.

---

## Requirements

**R** carries the analysis and every figure except the Sankey; **Python** is used only for the Sankey.

| Purpose | Environment |
|---|---|
| Analysis and figures | **R 4.5.0** (dplyr, tidyr, readr, readxl, jsonlite, ggplot2) |
| Sankey figure | Python 3.14 + matplotlib 3.11.2 |

```r
install.packages(c('dplyr','tidyr','readr','readxl','jsonlite','ggplot2'))
```


---

## Scripts

| Script | Language | Reproduces |
|---|---|---|
| `00_load.R` | R | Shared loader: country-name canon, Gini, corpus and sampling readers |
| `fig1a_growth.R` | R | Fig. 1a/b — annual output and the four developmental periods |
| `fig1_geography.R` | R | Fig. 1a-c — nine-class typology, concentration, continental shares |
| `fig1_wedge.R` | R | Fig. 1d,e — sampling-publication wedge by archive class |
| `fig2_scaling.R` | R | Fig. 2 — income groups and scaling |
| `fig3_network.R` | R | Fig. 3a — five-layer network flows (data preparation) |
| `plot_fig3a_sankey.py` | **Python** | Sankey rendering (the one figure not drawn in R) |
| `main_tests.R` | R | Main tests — marine vs lake sediment, polar ice core vs tree ring |

Panel assembly (compositing sub-panels into the published figures) is **not** included.

---

## Usage

```bash
# Analysis and figures (R)
Rscript script/fig1a_growth.R
Rscript script/fig1_geography.R
Rscript script/fig1_wedge.R
Rscript script/fig2_scaling.R
Rscript script/fig3_network.R

# Main tests (R)
Rscript script/main_tests.R

# Sankey figure (Python, the only non-R figure)
python script/plot_fig3a_sankey.py
```

---

## Reproduced values

Every script runs standalone and reproduces the published numbers:

| Script | Key values |
|---|---|
| `fig1a_growth.R` | Periods 2,489 / 5,685 / 8,471 / 15,319; 26 articles in 1980; 1,857.8 per year over 2021-2025; 1,181 records outside the window |
| `fig1_geography.R` | Publication Gini 0.910, sampling Gini 0.847; high-high share 89.11% of publications and 81.29% of sampling; ten largest producers from the United States (5,657) to the Russian Federation (861) |
| `fig3_network.R` | SDG 13 = 60.34%, 15 = 13.14%, 14 = 12.17%, 6 = 10.25%; top four = 95.90% |
| `main_tests.R` | H1 = +0.0190, H2 = +0.0690 |

---

## Conventions

The code follows the original analysis library in three places that matter for reproduction:

1. **Country-name canon** — aliases first (Taiwan / Hong Kong to China), then diacritic stripping, then upper case.
2. **Gini** — same estimator as the original archive-stratified inequality script.
3. **Multi-label weighting** — each record contributes a total weight of 1 per layer (labels split 1/n),
   so the node flows in any layer sum to the corpus size (33,145).

`doc/data_audit.md` records the full numeric audit of the manuscript against the shared data.

---

## Citation

If you use this code, please cite the paper and the dataset (see `CITATION.cff`).

## Licence

Code released under the **MIT License** (see `LICENSE`).
The dataset is released separately under **CC BY-NC-SA 4.0** on Zenodo.
