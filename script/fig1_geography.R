# =============================================================================
# fig1_geography.R — Figure 1a-c: nine-class typology, concentration, continents
#
# Reproduces, from share/data only:
#   1a  the 195-country publication x sampling cross-classification (P25/P75,
#       double-zero countries forced to LL)                       -> fig1a_*.csv
#   1b  class x year output per country (fractional publications and
#       sampling-location articles)                               -> fig1b_*.csv
#   1c  Lorenz curves and concentration statistics                -> fig1c_*.csv
#
# Method notes
#   * publication credit = fractional weights (in_analysed_corpus only),
#     roster countries only; sampling = distinct (record, country) pairs.
#   * quantiles use R's default type 7, computed on countries with value > 0.
#   * HH-share confidence intervals: 2,000 country-block bootstrap replicates.
# =============================================================================
local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- grep("^--file=", a, value = TRUE)
  s <- c(if (length(f)) dirname(sub("^--file=", "", f[1])), getwd())
  for (x in s) {
    d <- normalizePath(x, mustWork = FALSE)
    for (i in 1:8) {
      if (file.exists(file.path(d, "00_load.R"))) {
        assign("HERE", d, envir = globalenv()); return(invisible())
      }
      p <- dirname(d); if (identical(p, d)) break; d <- p
    }
  }
  stop("Cannot locate 00_load.R")
})
source(file.path(HERE, "00_load.R"))

set.seed(42)
corpus <- load_corpus("analysed")
roster <- load_roster()
roster_canon <- roster$canon

# ---- country totals ----------------------------------------------------------
m <- build_country_metrics(corpus)

# Recompute the nine classes from the frozen definition: double-zero countries
# go to LL; otherwise each dimension is split at its own P25/P75, taken over
# countries with a non-zero value (R type-7 quantiles).
nz_pub  <- m$publications_frac[m$publications_frac > 0]
nz_samp <- m$sampling_total[m$sampling_total > 0]
brk <- list(pub = quantile(nz_pub, c(.25, .75), names = FALSE),
            samp = quantile(nz_samp, c(.25, .75), names = FALSE))
band <- function(x, b) ifelse(x <= b[1], "L", ifelse(x <= b[2], "M", "H"))
m <- m %>% mutate(
  double_zero = publications_frac == 0 & sampling_total == 0,
  pub_band  = ifelse(double_zero, "L", band(publications_frac, brk$pub)),
  samp_band = ifelse(double_zero, "L", band(sampling_total, brk$samp)),
  class = paste0(pub_band, samp_band))
# Cross-check against the archived class table (nine_class_195.csv) when present.
if ("class_archived" %in% names(m)) {
  mism <- m %>% filter(!is.na(class_archived), as.character(class_archived) != class)
  if (nrow(mism)) warning("nine_class_195.csv disagrees with recomputed classes for ",
                          nrow(mism), " countries; recomputed classes are used")
  msg("  class cross-check vs nine_class_195.csv: %d/%d agree", nrow(m) - nrow(mism), nrow(m))
}
m <- m %>% mutate(class = factor(class, levels = CLASS_LEVELS)) %>% arrange(class, desc(publications_frac))

TOT_P <- sum(m$publications_frac); TOT_S <- sum(m$sampling_total)
msg("== fig1_geography.R ==")
msg("  countries            : %d", nrow(m))
msg("  fractional total     : %.1f", TOT_P)
msg("  sampling total       : %.0f", TOT_S)
msg("  publication Gini     : %.4f", gini(m$publications_frac))
msg("  sampling Gini        : %.4f", gini(m$sampling_total))
msg("  Pearson r            : %.3f", cor(m$publications_frac, m$sampling_total))
msg("  Spearman rho         : %.3f", cor(m$publications_frac, m$sampling_total, method = "spearman"))

# ---- 1a: nine-class table ----------------------------------------------------
hh <- m %>% filter(class == "HH")
mm <- m %>% filter(class == "MM")
msg("  HH countries         : %d (%.2f%%)", nrow(hh), 100 * nrow(hh) / nrow(m))
msg("  HH publication share : %.2f%%", 100 * sum(hh$publications_frac) / TOT_P)
msg("  HH sampling share    : %.2f%%", 100 * sum(hh$sampling_total) / TOT_S)
msg("  HH surplus           : %.2f pp", 100 * sum(hh$publications_frac) / TOT_P - 100 * sum(hh$sampling_total) / TOT_S)
msg("  MM countries         : %d | deficit %.2f pp", nrow(mm),
    100 * sum(mm$publications_frac) / TOT_P - 100 * sum(mm$sampling_total) / TOT_S)
msg("  zero publication     : %d | with publication: %d", sum(m$publications_frac == 0), sum(m$publications_frac > 0))
msg("  zero sampling        : %d | double-zero: %d", sum(m$sampling_total == 0), sum(m$double_zero))
msg("  nine classes         : %s",
    paste(sprintf("%s=%d", names(table(m$class)), as.integer(table(m$class))), collapse = " "))

# ---- 1c: concentration and Lorenz -------------------------------------------
conc <- tibble(
  metric = c("publications_frac", "sampling_total"),
  total  = c(TOT_P, TOT_S),
  gini   = c(gini(m$publications_frac), gini(m$sampling_total)),
  hhi    = c(hhi(m$publications_frac), hhi(m$sampling_total)),
  top1_pct  = c(100 * max(m$publications_frac) / TOT_P, 100 * max(m$sampling_total) / TOT_S),
  top5_pct  = c(100 * sum(sort(m$publications_frac, decreasing = TRUE)[1:5]) / TOT_P,
                100 * sum(sort(m$sampling_total, decreasing = TRUE)[1:5]) / TOT_S),
  top10_pct = c(100 * sum(sort(m$publications_frac, decreasing = TRUE)[1:10]) / TOT_P,
                100 * sum(sort(m$sampling_total, decreasing = TRUE)[1:10]) / TOT_S),
  n_zero    = c(sum(m$publications_frac == 0), sum(m$sampling_total == 0)))
lorenz <- function(v, metric) {
  v <- sort(v); tibble(metric = metric, p = seq_along(v) / length(v), L = cumsum(v) / sum(v),
                       country = NA_character_)
}
lor <- bind_rows(lorenz(m$publications_frac, "Publication"),
                 lorenz(m$sampling_total, "Sampling"))

# HH-share bootstrap (country resampling with class labels held fixed as observed)
boot_share <- function(v) {
  idx <- seq_along(v)
  vals <- replicate(NB_BOOT, {
    s <- sample(idx, length(idx), replace = TRUE)
    sum(v[s][m$class[s] == "HH"]) / sum(v[s])
  })
  100 * quantile(vals, c(.025, .5, .975), names = FALSE)
}
ci_pub <- boot_share(m$publications_frac); ci_samp <- boot_share(m$sampling_total)
msg("  HH publication share 95%% CI : %.2f [%.2f, %.2f]", ci_pub[2], ci_pub[1], ci_pub[3])
msg("  HH sampling    share 95%% CI : %.2f [%.2f, %.2f]", ci_samp[2], ci_samp[1], ci_samp[3])
ci <- tibble(metric = c("HH publication share (%)", "HH sampling share (%)"),
             median = c(ci_pub[2], ci_samp[2]), lo = c(ci_pub[1], ci_samp[1]),
             hi = c(ci_pub[3], ci_samp[3]), boot_B = NB_BOOT)

# ---- continents and top producers -------------------------------------------
ros_key <- roster %>% select(canon, continent)
cpub <- load_fractional(analysed = TRUE) %>%
  filter(record_id %in% corpus$record_id) %>%
  inner_join(ros_key, by = "canon") %>%
  group_by(continent) %>% summarise(publications_frac = sum(frac), .groups = "drop")
csmp <- load_sampling(split = TRUE) %>%
  filter(record_id %in% corpus$record_id) %>%
  distinct(record_id, canon) %>% inner_join(ros_key, by = "canon") %>%
  count(continent, name = "sampling_total")
cont <- full_join(cpub, csmp, by = "continent") %>%
  mutate(publications_frac = replace_na(publications_frac, 0),
         sampling_total = replace_na(sampling_total, 0L),
         pub_pct = pct(publications_frac, TOT_P),
         samp_pct = pct(sampling_total, TOT_S)) %>%
  arrange(desc(publications_frac))
msg("\n  continents (fractional publication share / sampling share):")
for (i in seq_len(nrow(cont)))
  msg("    %-15s %6.2f%%  %6.2f%%", cont$continent[i], cont$pub_pct[i], cont$samp_pct[i])

top10 <- m %>% arrange(desc(publications_frac)) %>% slice_head(n = 10) %>%
  transmute(rank = row_number(), country, publications_frac = round(publications_frac, 1),
            sampling_total, class = as.character(class))
msg("\n  top 10 producers:")
for (i in seq_len(nrow(top10)))
  msg("    %2d %-22s %8.1f", top10$rank[i], top10$country[i], top10$publications_frac[i])

# ---- 1b: class x year per-country series ------------------------------------
cy_pub <- load_fractional(analysed = TRUE) %>%
  filter(record_id %in% corpus$record_id) %>%
  inner_join(corpus %>% select(record_id, year), by = "record_id") %>%
  filter(!is.na(year)) %>%
  group_by(canon, year) %>% summarise(publications_n = sum(frac), .groups = "drop")
cy_smp <- load_sampling(split = TRUE) %>%
  filter(record_id %in% corpus$record_id) %>%
  inner_join(corpus %>% select(record_id, year), by = "record_id") %>%
  filter(!is.na(year)) %>%
  distinct(record_id, canon, year) %>%
  count(canon, year, name = "sampling_n")
class_n <- m %>% count(class, name = "class_n")
cy <- full_join(cy_pub, cy_smp, by = c("canon", "year")) %>%
  mutate(publications_n = replace_na(publications_n, 0),
         sampling_n = replace_na(sampling_n, 0L)) %>%
  left_join(m %>% select(canon, class), by = "canon") %>%
  filter(!is.na(class)) %>%
  group_by(class, year) %>%
  summarise(publications_n = sum(publications_n), sampling_n = sum(sampling_n),
            countries_n = n_distinct(canon), .groups = "drop") %>%
  left_join(class_n, by = "class") %>%
  mutate(publications_per_country = publications_n / class_n,
         sampling_per_country = sampling_n / class_n) %>%
  arrange(class, year)

# ---- write derived tables ----------------------------------------------------
write_derived(m %>% transmute(country, country_cn, continent, iso3,
                              publications_frac, sampling_total, pub_band, samp_band,
                              class = as.character(class), double_zero), "fig1a_country_classes.csv")
write_derived(cy, "fig1b_class_year.csv")
write_derived(lor, "fig1c_lorenz.csv")
write_derived(conc, "fig1c_concentration.csv")
write_derived(ci, "fig1c_hh_share_ci.csv")
write_derived(cont, "fig1c_continents.csv")
write_derived(top10, "fig1c_top10_producers.csv")
msg("\n  fig1_geography.R done")
