# =============================================================================
# 00_load.R — shared data loader for every reproduction script
#
# This is the single entry point: it locates the archived dataset, normalises
# country names exactly as the analysis repository does (scripts/R/io.R),
# defines the concentration indices, and exposes one loader per data file.
#
# Data location (first match wins):
#   1. environment variable PAPER_DATA_DIR
#   2. <repo>/data            (share/data next to share/script)
#   3. <repo parent>/data
#   4. the script directory itself
#
# Usage from another script:
#   source("00_load.R")     # located next to that script
# Nothing here writes to the data directory.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(readxl)
  library(jsonlite)
  library(stringr)
  library(tibble)
})

# ---- script / repo / data directory -----------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- grep("^--file=", .args, value = TRUE)
HERE  <- if (length(.file)) {
  dirname(normalizePath(sub("^--file=", "", .file[1]), mustWork = FALSE))
} else {
  normalizePath(getwd(), mustWork = FALSE)
}
REPO <- dirname(HERE)

.find_data_dir <- function() {
  cand <- c(Sys.getenv("PAPER_DATA_DIR", ""),
            file.path(REPO, "data"),
            file.path(dirname(REPO), "data"),
            HERE)
  cand <- cand[nzchar(cand)]
  hit <- cand[file.exists(file.path(cand, "corpus_annotated.xlsx")) |
              file.exists(file.path(cand, "fractional_weights.csv"))]
  if (!length(hit)) {
    stop(paste0("Shared dataset not found.\n",
                "  Looked in: ", paste(cand, collapse = ", "), "\n",
                "  Download the archive to share/data/, or set PAPER_DATA_DIR."),
         call. = FALSE)
  }
  normalizePath(hit[1], mustWork = FALSE)
}
DATA <- .find_data_dir()
dpath <- function(f) file.path(DATA, f)

DERIVED <- file.path(HERE, "_derived")
dir.create(DERIVED, showWarnings = FALSE, recursive = TRUE)

msg <- function(...) cat(sprintf(...), "\n", sep = "")
write_derived <- function(df, filename) {
  stopifnot(is.data.frame(df))
  path <- file.path(DERIVED, filename)
  readr::write_excel_csv(df, path, na = "")
  msg("[derived] %-42s %5d rows x %2d cols", filename, nrow(df), ncol(df))
  invisible(path)
}

# ---- analysis constants (frozen in the manuscript methods) -------------------
ROSTER_N     <- 195L
YEAR_MIN     <- 1980L
YEAR_MAX     <- 2025L
EXCLUDED_YEARS <- c(2026L, 2027L)
PPP_BREAK    <- 41458            # elasticity step, PPP constant-2021 int$
NB_BOOT      <- 2000L            # bootstrap replicates (country block / record block)
NB_BOOT_FAST <- 400L             # reduced replicates where the original used 400/200
CLASS_LEVELS <- c("HH", "HM", "HL", "MH", "MM", "ML", "LH", "LM", "LL")
ARCHIVE_CLASS_EN <- c("Sediment" = "Sediment", "Ice core" = "Ice core",
                      "Biological growth" = "Biological growth",
                      "Fossil & shell" = "Fossil & shell",
                      "Other natural" = "Other natural",
                      "Unclassified" = "Unclassified")
CONTINENT_EN <- c("亚洲" = "Asia", "欧洲" = "Europe", "非洲" = "Africa",
                  "北美洲" = "North America", "南美洲" = "South America",
                  "大洋洲" = "Oceania", "南极洲" = "Antarctica")
INCOME_EN <- c("高收入国家" = "High income",
               "中高等收入国家" = "Upper middle income",
               "中低等收入国家" = "Lower middle income",
               "低收入国家" = "Low income")

to_income_en <- function(x) {
  x <- as.character(x)
  out <- unname(INCOME_EN[x])
  rule <- dplyr::case_when(
    grepl("中高", x) ~ "Upper middle income",
    grepl("中低", x) ~ "Lower middle income",
    grepl("高收入", x) ~ "High income",
    grepl("低收入", x) ~ "Low income",
    TRUE ~ NA_character_)
  out[is.na(out)] <- rule[is.na(out)]
  out
}
to_continent_en <- function(x) {
  x <- as.character(x)
  out <- unname(CONTINENT_EN[x]); out[is.na(out)] <- x[is.na(out)]; out
}

# ---- country-name normalisation (line-for-line from scripts/R/io.R) ----------
CFG_ALIASES <- tryCatch(
  jsonlite::fromJSON(dpath("config_aliases.json"), simplifyVector = TRUE),
  error = function(e) list())

canon_country <- function(x) {
  al <- unlist(CFG_ALIASES)
  x  <- trimws(as.character(x))
  hit <- al[x]; x[!is.na(hit)] <- hit[!is.na(hit)]
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"); x[is.na(x)] <- ""
  toupper(gsub("[^A-Za-z]", "", x))
}

# ---- concentration / divergence indices (same formulas as scripts/R/io.R) ----
gini <- function(x) {
  x <- sort(x[x >= 0]); n <- length(x)
  if (n < 2 || sum(x) == 0) return(NA_real_)
  (2 * sum(seq_len(n) * x) / (n * sum(x))) - (n + 1) / n
}
hhi <- function(x) {
  s <- sum(x); if (s == 0) return(NA_real_)
  sum((x / s)^2) * 10000
}
entropy <- function(p) { p <- p[p > 0]; -sum(p * log(p)) }
norm_entropy <- function(p) { p <- p[p > 0]; if (length(p) < 2) return(NA_real_); entropy(p) / log(length(p)) }
tvd <- function(a, b) {
  keys <- union(names(a), names(b))
  av <- ifelse(keys %in% names(a), a[keys], 0)
  bv <- ifelse(keys %in% names(b), b[keys], 0)
  av[is.na(av)] <- 0; bv[is.na(bv)] <- 0
  0.5 * sum(abs(av - bv))
}
pct <- function(x, total = sum(x)) round(100 * x / total, 2)

# ---- record-level loaders ----------------------------------------------------
load_corpus <- function(which = c("analysed", "records")) {
  which <- match.arg(which)
  sheet <- if (which == "analysed") "analysed_corpus" else "records"
  f <- dpath("corpus_annotated.xlsx")
  if (!file.exists(f)) stop("corpus_annotated.xlsx not found in ", DATA, call. = FALSE)
  df <- readxl::read_excel(f, sheet = sheet)
  df <- df %>%
    mutate(record_id = as.character(record_id),
           year = suppressWarnings(as.integer(year)))
  df
}

load_sampling <- function(split = TRUE) {
  f <- dpath("country_workbook_v4.xlsx")
  if (!file.exists(f)) stop("country_workbook_v4.xlsx not found in ", DATA, call. = FALSE)
  ss <- readxl::read_excel(f, sheet = "\u660e\u7ec6_\u91c7\u6837\u5730\u56fd\u5bb6", .name_repair = "minimal")
  names(ss)[1:3] <- c("record_id", "ss_raw", "ss_country")
  ss <- ss %>%
    transmute(record_id = as.character(record_id),
              ss_country = as.character(ss_country)) %>%
    filter(!is.na(ss_country), nzchar(trimws(ss_country)))
  if (!split) return(ss)
  ss %>%
    mutate(fragment = stringr::str_split(ss_country, "[;,]")) %>%
    tidyr::unnest(fragment) %>%
    mutate(fragment = trimws(fragment)) %>%
    filter(nzchar(fragment)) %>%
    transmute(record_id, fragment, canon = canon_country(fragment)) %>%
    filter(nzchar(canon))
}

load_first_author <- function() {
  f <- dpath("country_workbook_v4.xlsx")
  fa <- readxl::read_excel(f, sheet = "\u660e\u7ec6_\u7b2c\u4e00\u4f5c\u8005\u56fd\u5bb6", .name_repair = "minimal")
  names(fa)[1:3] <- c("record_id", "fa_raw", "fa_country")
  fa %>%
    transmute(record_id = as.character(record_id),
              country_raw = trimws(as.character(fa_country)),
              canon = canon_country(fa_country)) %>%
    filter(!is.na(country_raw), nzchar(country_raw), nzchar(canon)) %>%
    distinct(record_id, canon, .keep_all = TRUE)
}

load_fractional <- function(analysed = TRUE) {
  f <- dpath("fractional_weights.csv")
  if (!file.exists(f)) stop("fractional_weights.csv not found in ", DATA, call. = FALSE)
  fr <- readr::read_csv(f, show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_guess()))
  fr <- fr %>%
    transmute(record_id = as.character(record_id),
              country = as.character(country),
              frac = suppressWarnings(as.numeric(frac)),
              in_analysed_corpus = if ("in_analysed_corpus" %in% names(fr))
                as.logical(in_analysed_corpus) else TRUE,
              canon = canon_country(country))
  if (analysed) fr <- filter(fr, in_analysed_corpus)
  fr %>% filter(!is.na(frac), nzchar(canon))
}

# ---- country-level reference tables -----------------------------------------
load_roster <- function() {
  f <- dpath("roster_195_v6.csv")
  if (!file.exists(f)) stop("roster_195_v6.csv not found in ", DATA, call. = FALSE)
  r <- readr::read_csv(f, show_col_types = FALSE)
  r <- r %>%
    transmute(country = as.character(.data[["\u82f1\u6587\u540d"]]),
              country_cn = as.character(.data[["\u4e2d\u6587\u540d"]]),
              continent = to_continent_en(.data[["\u5927\u6d32"]]),
              iso3 = toupper(trimws(as.character(ISO3))),
              canon = canon_country(.data[["\u82f1\u6587\u540d"]]))
  if (nrow(r) != ROSTER_N) warning("roster rows = ", nrow(r), " (expected ", ROSTER_N, ")")
  r
}

load_classes <- function() {
  f <- dpath("nine_class_195.csv")
  if (!file.exists(f)) return(NULL)
  d <- readr::read_csv(f, show_col_types = FALSE)
  # Contract order: country, country_cn, continent, publications_total,
  # sampling_total, pub_band, samp_band, class, double_zero
  nm <- names(d)
  if (!"publications_frac" %in% nm && "publications_total" %in% nm) {
    d <- mutate(d, publications_frac = as.numeric(publications_total))
  }
  d <- d %>%
    mutate(country = as.character(country),
           country_cn = as.character(country_cn),
           continent = to_continent_en(continent),
           publications_frac = as.numeric(publications_frac),
           sampling_total = as.numeric(sampling_total),
           class = as.character(class),
           double_zero = as.logical(double_zero),
           canon = canon_country(country))
  d
}

load_archive_map <- function() {
  f <- dpath("archive_mid_to_class.csv")
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE) %>%
    transmute(archive_mid = as.character(archive_mid_en),
              archive_class = as.character(archive_class_en))
}

load_economy <- function() {
  f <- dpath("country_economy.csv")
  if (!file.exists(f)) stop("country_economy.csv not found in ", DATA, call. = FALSE)
  d <- readr::read_csv(f, show_col_types = FALSE)
  d %>%
    transmute(country = as.character(country),
              iso3 = toupper(trimws(as.character(ISO3))),
              gdppc = as.numeric(gdppc),
              gdp_year = suppressWarnings(as.integer(gdp_year)),
              income_group = to_income_en(income_group),
              ppp_group = as.character(ppp_group),
              population_latest = as.numeric(population_latest),
              canon = canon_country(country))
}

.read_wb_long <- function(f, value_name) {
  if (!file.exists(f)) return(NULL)
  d <- readr::read_csv(f, show_col_types = FALSE)
  nm <- names(d)
  iso_col <- intersect(c("iso3", "ISO3", "country_code", "country"), nm)[1]
  year_col <- intersect(c("year", "Year"), nm)[1]
  val_col <- intersect(c(value_name, "value", "gdppc", "population", "pop",
                         "gdppc_ppp_const2021"), nm)[1]
  if (is.na(iso_col) || is.na(year_col) || is.na(val_col)) {
    stop("Cannot identify columns in ", basename(f), ": ", paste(nm, collapse = ", "), call. = FALSE)
  }
  d %>%
    transmute(iso3 = toupper(trimws(as.character(.data[[iso_col]]))),
              year = suppressWarnings(as.integer(.data[[year_col]])),
              value = suppressWarnings(as.numeric(.data[[val_col]]))) %>%
    filter(!is.na(iso3), !is.na(year), !is.na(value))
}
load_gdp_ppp <- function() .read_wb_long(dpath("worldbank_gdp_pc_ppp_const2021.csv"), "gdppc")
load_population <- function() .read_wb_long(dpath("worldbank_population.csv"), "population")

load_network_subset <- function() {
  f <- dpath("network_subset.csv")
  if (!file.exists(f)) return(NULL)
  d <- readr::read_csv(f, show_col_types = FALSE)
  ctype <- as.character(d$ctype)
  thr <- suppressWarnings(as.numeric(gsub("[^0-9]", "", ctype)))
  thr[!is.finite(thr)] <- PPP_BREAK
  d %>%
    transmute(record_id = as.character(record_id),
              ctype = ctype,
              ppp_value = thr,
              ppp_above = grepl("^Above", ctype))
}

load_sampling_fragments <- function() {
  f <- dpath("sampling_fragments.csv")
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE)
}

# Country-year panel shipped with the archive (n_pub, population, GDP per capita)
load_panel <- function() {
  f <- dpath("panel_country_year.csv")
  if (!file.exists(f)) return(NULL)
  d <- readr::read_csv(f, show_col_types = FALSE)
  roster <- load_roster()
  d %>%
    mutate(country_en = as.character(country_en), canon = canon_country(country_en)) %>%
    left_join(roster %>% select(canon, iso3), by = "canon") %>%
    mutate(year = suppressWarnings(as.integer(year)))
}

# ---- expected / baseline tables ---------------------------------------------
load_expected <- function() {
  f1 <- file.path(REPO, "..", "tables", "_intermediate", "expected_values.json")
  f2 <- dpath("expected_values.json")
  f <- c(f2, f1); f <- f[file.exists(f)]
  if (!length(f)) return(NULL)
  jsonlite::fromJSON(f[1], simplifyVector = FALSE)
}
load_baseline <- function() {
  f <- dpath("baseline_recomputed.json")
  if (!file.exists(f)) return(NULL)
  jsonlite::fromJSON(f, simplifyVector = TRUE)
}

# ---- composite builders shared by several scripts ---------------------------
# Country-level publication/sampling totals under the frozen definitions:
#   publications_frac = sum of fractional weights over the analysed corpus,
#   sampling_total    = distinct (record, country) sampling pairs on the roster.
build_country_metrics <- function(corpus = load_corpus("analysed")) {
  roster <- load_roster()
  roster_canon <- roster$canon
  fr <- load_fractional(analysed = TRUE) %>%
    filter(record_id %in% corpus$record_id)
  pub <- fr %>% filter(canon %in% roster_canon) %>%
    group_by(canon) %>% summarise(publications_frac = sum(frac), .groups = "drop")
  ss <- load_sampling(split = TRUE) %>%
    filter(record_id %in% corpus$record_id, canon %in% roster_canon) %>%
    distinct(record_id, canon)
  smp <- ss %>% count(canon, name = "sampling_total")
  m <- roster %>%
    select(canon, country, country_cn, continent, iso3) %>%
    left_join(pub, by = "canon") %>% left_join(smp, by = "canon") %>%
    mutate(publications_frac = replace_na(publications_frac, 0),
           sampling_total = replace_na(sampling_total, 0L))
  cls <- load_classes()
  if (!is.null(cls)) {
    m <- m %>% left_join(
      cls %>% select(canon, class_archived = class, double_zero_archived = double_zero),
      by = "canon")
  }
  m
}

# Records with a non-missing archive sub-class and its 1/n weight (multi-label).
archive_mid_long <- function(corpus = load_corpus("analysed")) {
  corpus %>%
    select(record_id, mid = jev_archive_mid) %>%
    mutate(mid = as.character(mid)) %>%
    filter(!is.na(mid), nzchar(trimws(mid)), mid != "NA") %>%
    tidyr::separate_rows(mid, sep = ";") %>%
    mutate(mid = trimws(mid)) %>%
    filter(nzchar(mid), mid != "NA") %>%
    group_by(record_id) %>% mutate(w = 1 / n()) %>% ungroup() %>%
    transmute(record_id, archive_mid = mid, w)
}

# Country-year panel of fractional publications and sampling counts, joined to
# World Bank GDP per capita (PPP, constant 2021 int$) and population.
build_country_year_panel <- function(corpus = load_corpus("analysed")) {
  roster <- load_roster()
  fr <- load_fractional(analysed = TRUE) %>% filter(record_id %in% corpus$record_id)
  pub <- fr %>%
    inner_join(corpus %>% select(record_id, year), by = "record_id") %>%
    filter(!is.na(year)) %>%
    group_by(canon, year) %>%
    summarise(publications_frac = sum(frac), .groups = "drop")
  ss <- load_sampling(split = TRUE) %>%
    filter(record_id %in% corpus$record_id) %>%
    inner_join(corpus %>% select(record_id, year), by = "record_id") %>%
    filter(!is.na(year)) %>%
    distinct(record_id, canon, year)
  smp <- ss %>% group_by(canon, year) %>% summarise(sampling_total = n(), .groups = "drop")
  gdp <- load_gdp_ppp(); pop <- load_population()
  m <- roster %>% select(canon, country, iso3) %>%
    left_join(pub, by = "canon") %>% left_join(smp, by = "canon") %>%
    mutate(publications_frac = replace_na(publications_frac, 0),
           sampling_total = replace_na(sampling_total, 0L))
  if (!is.null(gdp)) m <- left_join(m, gdp %>% rename(gdppc = value), by = c("iso3", "year"))
  if (!is.null(pop)) m <- left_join(m, pop %>% rename(population = value), by = c("iso3", "year"))
  m
}

# ---- self-test when run directly -------------------------------------------
if (sys.nframe() == 0) {
  msg("Data dir : %s", DATA)
  cr <- load_corpus("records"); ca <- load_corpus("analysed")
  msg("Records  : %d rows (analysed_corpus %d)", nrow(cr), nrow(ca))
  fr <- load_fractional(analysed = TRUE)
  msg("Fractional: %d pairs | sum = %.1f", nrow(fr), sum(fr$frac))
  ss <- load_sampling(split = TRUE)
  msg("Sampling : %d (record x fragment) pairs over %d records", nrow(ss), n_distinct(ss$record_id))
  ros <- load_roster(); msg("Roster   : %d countries", nrow(ros))
  cls <- load_classes(); if (!is.null(cls)) msg("Classes  : %s",
      paste(sprintf("%s=%d", names(table(cls$class)), as.integer(table(cls$class))), collapse = " "))
  msg("Years    : %d-%d", min(ca$year, na.rm = TRUE), max(ca$year, na.rm = TRUE))
}
