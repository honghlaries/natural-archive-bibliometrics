# =============================================================================
# fig1_wedge.R — Figure 1d-e: archive-sub-class concentration and the
#                 sampling-publication wedge, with bootstrap intervals.
#
# Method (identical to scripts/34_archive_stratified_inequality.R):
#   * archive sub-class labels are multi-label: each record's unit weight is
#     split 1/n across the sub-classes it carries;
#   * sampling side: weight w on every sampling country of the record;
#   * publication side: weight w * frac (fractional author-country credit);
#   * concentration is computed on the 195-country roster universe;
#   * only sub-classes with >= 100 records enter the main analysis.
#
# Outputs: fig1d_archive_concentration.csv, fig1e_archive_wedge.csv,
#          fig1_archive_robustness.csv
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
msg("== fig1_wedge.R ==")
corpus <- load_corpus("analysed")
roster <- load_roster(); roster_canon <- roster$canon

# ---- record x archive_mid long table (1/n across sub-classes) ----------------
mid_w <- archive_mid_long(corpus)
rec <- corpus %>% transmute(record_id, year) %>%
  inner_join(mid_w, by = "record_id", relationship = "many-to-many")

ss_r <- load_sampling(split = TRUE) %>%
  filter(record_id %in% corpus$record_id) %>%
  distinct(record_id, canon)
fr_r <- load_fractional(analysed = TRUE) %>%
  filter(record_id %in% corpus$record_id)

rec_ss <- rec %>% inner_join(ss_r, by = "record_id", relationship = "many-to-many") %>%
  transmute(record_id, archive_mid, w, canon)
rec_fr <- rec %>% inner_join(fr_r, by = "record_id", relationship = "many-to-many") %>%
  transmute(record_id, archive_mid, w = w * frac, canon)
msg("  archive_mid labels: %d | record-label pairs: %d", n_distinct(rec$archive_mid), nrow(rec))
msg("  sampling side rows: %d | publication side rows: %d", nrow(rec_ss), nrow(rec_fr))

n_by_type <- rec %>% group_by(archive_mid) %>%
  summarise(n_rec = n_distinct(record_id), .groups = "drop")
KEEP <- n_by_type %>%
  filter(n_rec >= 100, archive_mid != "Unclassified", !is.na(archive_mid)) %>%
  pull(archive_mid)
msg("  sub-classes kept (n >= 100, excl. Unclassified): %d -> %s",
    length(KEEP), paste(KEEP, collapse = ", "))

# ---- 1d: concentration by sub-class and side ---------------------------------
universe <- function(d, tp) {
  v <- d %>% filter(archive_mid == tp) %>% group_by(canon) %>%
    summarise(v = sum(w), .groups = "drop")
  x <- setNames(rep(0, length(roster_canon)), roster_canon)
  x[v$canon] <- v$v
  as.numeric(x)
}
concent <- function(d, types, side) {
  bind_rows(lapply(types, function(tp) {
    x <- universe(d, tp)
    tibble(archive_mid = tp, side = side, n_records = sum(x),
           n_countries = sum(x > 0), gini = gini(x), hhi = hhi(x),
           top1_pct = 100 * max(x) / sum(x),
           top5_pct = 100 * sum(sort(x, decreasing = TRUE)[1:5]) / sum(x),
           top10_pct = 100 * sum(sort(x, decreasing = TRUE)[1:10]) / sum(x))
  }))
}
conc <- bind_rows(concent(rec_ss, KEEP, "sampling"),
                  concent(rec_fr, KEEP, "publication")) %>%
  arrange(archive_mid, side) %>%
  mutate(across(c(gini, hhi, top1_pct, top5_pct, top10_pct), ~ round(.x, 4)))

# ---- 1e: sampling-publication wedge by sub-class ----------------------------
wedge_for <- function(tp) {
  s <- rec_ss %>% filter(archive_mid == tp) %>% group_by(canon) %>%
    summarise(v = sum(w), .groups = "drop")
  p <- rec_fr %>% filter(archive_mid == tp) %>% group_by(canon) %>%
    summarise(v = sum(w), .groups = "drop")
  full_join(s %>% transmute(canon, ss = v / sum(v)),
            p %>% transmute(canon, pp = v / sum(v)), by = "canon") %>%
    mutate(ss = replace_na(ss, 0), pp = replace_na(pp, 0), d = ss - pp)
}
wedge_boot_ci <- function(d, B = NB_BOOT) {
  med <- replicate(B, median(sample(d, length(d), replace = TRUE)))
  quantile(med, c(.025, .975), names = FALSE)
}
wedge <- bind_rows(lapply(KEEP, function(tp) {
  wd <- wedge_for(tp)
  wt <- suppressWarnings(wilcox.test(wd$d, alternative = "greater", exact = FALSE))
  st <- binom.test(sum(wd$d > 0), sum(wd$d != 0), 0.5, alternative = "greater")
  ci <- wedge_boot_ci(wd$d)
  tibble(archive_mid = tp, n_countries = nrow(wd),
         n_sampling_countries = sum(wd$ss > 0),
         n_records = sum(rec_ss$w[rec_ss$archive_mid == tp]),
         median_share_diff = median(wd$d),
         mean_share_diff = mean(wd$d),
         ci_low = ci[1], ci_high = ci[2],
         positive_share = mean(wd$d > 0),
         wilcoxon_p = wt$p.value, sign_test_p = st$p.value)
})) %>% arrange(desc(median_share_diff))

msg("\n  1d concentration (Gini: sampling / publication):")
for (tp in KEEP) {
  a <- conc$gini[conc$archive_mid == tp & conc$side == "sampling"]
  b <- conc$gini[conc$archive_mid == tp & conc$side == "publication"]
  msg("    %-24s %.4f / %.4f", tp, a, b)
}
msg("\n  1e wedge (median share difference, 95%% country-block bootstrap CI):")
for (i in seq_len(nrow(wedge)))
  msg("    %-24s %+.4f [%+.4f, %+.4f]  n_samp=%3d  n_rec=%5.0f",
      wedge$archive_mid[i], wedge$median_share_diff[i], wedge$ci_low[i],
      wedge$ci_high[i], wedge$n_sampling_countries[i], wedge$n_records[i])

# ---- robustness items (Table S3 in the SI) ----------------------------------
# (a) primary-label-only sensitivity for the two sediment contrasts
mid1 <- mid_w %>% group_by(record_id) %>% slice(1) %>% ungroup()
rec1 <- corpus %>% transmute(record_id, year) %>%
  inner_join(mid1 %>% transmute(record_id, archive_mid, w = 1), by = "record_id")
ss1 <- rec1 %>% inner_join(ss_r, by = "record_id", relationship = "many-to-many") %>%
  transmute(record_id, archive_mid, w, canon)
gini_of <- function(d, tp) gini(universe(d, tp))
g_marine <- gini_of(rec_ss, "Marine sediment"); g_lake <- gini_of(rec_ss, "Lake sediment")
g_ice <- gini_of(rec_ss, "Polar ice core"); g_tree <- gini_of(rec_ss, "Tree ring")
gA1 <- gini_of(ss1, "Marine sediment"); gB1 <- gini_of(ss1, "Lake sediment")

# (b) unclassified records: is the residual non-random over periods?
stages <- c(1980L, 2000L, 2009L, 2017L, 2025L)
per_lab <- sprintf("%d-%d", stages[-length(stages)], c(stages[-c(1)] - 1L))
per_lab[length(per_lab)] <- sprintf("%d-%d", stages[length(stages) - 1L], stages[length(stages)])
unc <- rec %>% filter(archive_mid == "Unclassified") %>% distinct(record_id, year)
unc_per <- unc %>% mutate(period = cut(year, breaks = c(stages[-length(stages)], stages[length(stages)] + 1L),
                                       labels = per_lab, right = FALSE, include.lowest = TRUE))
c2_year <- suppressWarnings(chisq.test(table(unc_per$period), p = rep(1 / length(per_lab), length(per_lab))))

# (c) polar ice core sampling geography
pol_ids <- rec %>% filter(archive_mid == "Polar ice core") %>% pull(record_id) %>% unique()
pol_ss <- ss_r %>% filter(record_id %in% pol_ids)
n_polar <- length(pol_ids)
n_ant <- n_distinct(pol_ss$record_id[pol_ss$canon == "ANTARCTICA"])
n_grn <- n_distinct(pol_ss$record_id[pol_ss$canon == "GREENLAND"])
n_ant_grn <- n_distinct(intersect(pol_ss$record_id[pol_ss$canon == "ANTARCTICA"],
                                  pol_ss$record_id[pol_ss$canon == "GREENLAND"]))
n_off <- n_distinct(pol_ss$record_id[!(pol_ss$canon %in% roster_canon)])

robust <- tibble(
  item = c("records in corpus",
           "records with archive_mid",
           "records with archive_mid and sampling country",
           "Unclassified records (sub-class level)",
           "Unclassified: period distribution chi-square p",
           "multi-label sub-class records (>= 2)",
           "sub-classes with n < 100 (excluded from main)",
           "Gini marine, primary label only",
           "Gini lake, primary label only",
           "difference, primary label only",
           "Gini marine, 1/n weights",
           "Gini lake, 1/n weights",
           "polar ice core records",
           "polar ice core records sampled in Antarctica",
           "polar ice core records sampled in Greenland",
           "polar ice core records sampled in both Antarctica and Greenland",
           "polar ice core records sampled outside the 195-country roster"),
  value = c(nrow(corpus), n_distinct(rec$record_id), n_distinct(rec_ss$record_id),
            n_distinct(unc$record_id), c2_year$p.value,
            mid_w %>% count(record_id) %>% filter(n >= 2) %>% nrow(),
            sum(n_by_type$n_rec < 100),
            round(gA1, 4), round(gB1, 4), round(gA1 - gB1, 4),
            round(g_marine, 4), round(g_lake, 4),
            n_polar, n_ant, n_grn, n_ant_grn, n_off))

msg("\n  robustness:")
msg("    multi-label sub-class records (>=2): %d", as.integer(robust$value[6]))
msg("    unclassified records: %d | chi-square p = %.3g",
    n_distinct(unc$record_id), c2_year$p.value)
msg("    polar ice core: %d records | Antarctica %d | Greenland %d | both %d | off-roster %d",
    n_polar, n_ant, n_grn, n_ant_grn, n_off)
msg("    primary-label Gini: marine %.4f | lake %.4f | diff %.4f", gA1, gB1, gA1 - gB1)

write_derived(conc, "fig1d_archive_concentration.csv")
write_derived(wedge, "fig1e_archive_wedge.csv")
write_derived(robust, "fig1_archive_robustness.csv")
msg("\n  fig1_wedge.R done")
