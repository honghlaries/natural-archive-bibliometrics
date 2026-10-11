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

| Purpose | Interpreter |
|---|---|
| pandas computation | Python 3.12 (pandas 3.0.1) |
| matplotlib figures | Python 3.14 (matplotlib 3.11.2) |
| R statistics | R 4.5.0 |

    pip install -r requirements.txt

**Two-stage note.** pandas and matplotlib were not installed in the same interpreter in the
development environment, so figure scripts write a CSV into `script/_derived/` and a separate
`plot_*.py` renders it. That directory is git-ignored.

---

## Scripts

| Script | Reproduces |
|---|---|
| `00_load.py` | Shared loader: country-name canon, Gini, named-vector semantics |
| `fig1a_growth.py` + `plot_fig1a_growth.py` | Fig. 1a/b — annual output and the four developmental periods |
| `fig1_geography.py` | Fig. 1a-c — nine-class country typology, concentration, continental shares |
| `fig1_wedge.py` | Fig. 1d,e — sampling-publication wedge by archive class |
| `fig2_scaling.py` | Fig. 2 — income groups and scaling |
| `fig3_network.py` | Fig. 3a — five-layer knowledge network and SDG attribution |
| `plot_fig3b_sdg_share.py` | Fig. 3b — SDG flow by country tier (plot stage) |
| `main_tests.R` | Main tests — marine vs lake sediment, polar ice core vs tree ring |

Panel assembly (compositing sub-panels into the published figures) is **not** included.

---

## Usage

    # Fig. 1a/b
    python script/fig1a_growth.py           # writes script/_derived/fig1a_growth.csv
    python script/plot_fig1a_growth.py      # renders the figure

    # Remaining figures (computation stage)
    python script/fig1_geography.py
    python script/fig1_wedge.py
    python script/fig2_scaling.py
    python script/fig3_network.py
    python script/plot_fig3b_sdg_share.py   # needs matplotlib

    # Main tests
    Rscript script/main_tests.R

---

## Reproduced values

Every script runs standalone and reproduces the published numbers:

| Script | Key values |
|---|---|
| `fig1a_growth.py` | Periods 2,489 / 5,685 / 8,471 / 15,319; 26 articles in 1980; 1,857.8 per year over 2021-2025; 1,181 records outside the window |
| `fig1_geography.py` | Publication Gini 0.910, sampling Gini 0.847; high-high share 89.11% of publications and 81.29% of sampling; ten largest producers from the United States (5,657) to the Russian Federation (861) |
| `fig3_network.py` | SDG 13 = 60.34%, 15 = 13.14%, 14 = 12.17%, 6 = 10.25%; top four = 95.90% |
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
