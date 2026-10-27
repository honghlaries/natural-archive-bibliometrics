# =============================================================================
# main_tests.R — primary stratified tests H1/H2
#
#   H1 (primary)   marine sediment vs lake sediment
#   H2 (secondary) polar ice core vs tree ring
#
# Both compare the Gini concentration of *sampling locations* between two
# archive sub-classes. Record-level labels are multi-label and are split 1/n.
# Confidence intervals come from a record-block bootstrap (2,000 replicates),
# the same scheme as scripts/34_archive_stratified_inequality.R.
#
# Output: main_tests.csv
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
msg("== main_tests.R ==")
corpus <- load_corpus("analysed")
roster <- load_roster(); roster_canon <- roster$canon
mid_w <- archive_mid_long(corpus)
rec <- corpus %>% transmute(record_id) %>%
  inner_join(mid_w, by = "record_id", relationship = "many-to-many")
ss_r <- load_sampling(split = TRUE) %>%
  filter(record_id %in% corpus$record_id) %>%
  distinct(record_id, canon)

T4 <- c("Marine sediment", "Lake sediment", "Polar ice core", "Tree ring")
rec_ids <- unique(rec$record_id)
rec_ss <- rec %>%
  inner_join(ss_r, by = "record_id", relationship = "many-to-many") %>%
  transmute(record_id, archive_mid, w, canon)

# Record-level label weights are split 1/n; country universe = 195-country
# roster plus any non-sovereign sampling entities that actually appear
# (the named-vector construction appends them by name).
gini_of <- function(d, tp) {
  v <- d %>% filter(archive_mid == tp) %>% group_by(canon) %>%
    summarise(v = sum(w), .groups = "drop")
  x <- setNames(rep(0, length(roster_canon)), roster_canon)
  x[v$canon] <- v$v
  gini(as.numeric(x))
}
g4 <- sapply(T4, function(tp) gini_of(rec_ss, tp))
msg("  Gini marine %.4f | lake %.4f | ice core %.4f | tree ring %.4f",
    g4[1], g4[2], g4[3], g4[4])

# Record-block bootstrap (2,000 replicates), same scheme as script 34.
N <- length(rec_ids)
B <- NB_BOOT
bootm <- replicate(B, {
  s <- sample(rec_ids, N, replace = TRUE)
  tag <- tibble(record_id = s, .b = seq_along(s)) %>%
    left_join(rec %>% select(record_id, archive_mid, w),
              by = "record_id", relationship = "many-to-many")
  sl <- tag %>% inner_join(ss_r, by = "record_id", relationship = "many-to-many") %>%
    transmute(.b, archive_mid, w, canon)
  sapply(T4, function(tp) {
    v <- sl %>% filter(archive_mid == tp) %>%
      group_by(.b, canon) %>% summarise(v = sum(w), .groups = "drop") %>%
      group_by(canon) %>% summarise(v = sum(v), .groups = "drop")
    x <- setNames(rep(0, length(roster_canon)), roster_canon)
    x[v$canon] <- v$v
    gini(as.numeric(x))
  })
})
rownames(bootm) <- T4
g_all <- gini_of(rec_ss %>% mutate(archive_mid = "all"), "all")
msg("  reference: all archives pooled Gini %.4f", g_all)

pair_row <- function(label, ta, tb, hyp) {
  o <- g4[[ta]] - g4[[tb]]
  bb <- bootm[ta, ] - bootm[tb, ]
  q <- quantile(bb, c(.025, .5, .975), na.rm = TRUE)
  tibble(test = label, hypothesis = hyp,
         gini_a = round(g4[[ta]], 4), gini_b = round(g4[[tb]], 4),
         difference = round(o, 4), ci_low = round(q[1], 4), ci_high = round(q[3], 4),
         boot_median = round(q[2], 4), boot_p_gt0 = round(mean(bb > 0, na.rm = TRUE), 3),
         ci_excludes_zero = !(q[1] <= 0 && q[3] >= 0),
         boot_B = B, records_resampled = N)
}
res <- bind_rows(
  pair_row("marine sediment vs lake sediment (H1, primary)",
           "Marine sediment", "Lake sediment",
           "facility dependence raises sampling concentration"),
  pair_row("polar ice core vs tree ring (H2, secondary)",
           "Polar ice core", "Tree ring",
           "facility dependence raises sampling concentration"),
  tibble(test = "reference: all archives pooled", hypothesis = NA_character_,
         gini_a = round(g_all, 4), gini_b = NA_real_, difference = NA_real_,
         ci_low = NA_real_, ci_high = NA_real_, boot_median = NA_real_,
         boot_p_gt0 = NA_real_, ci_excludes_zero = NA,
         boot_B = B, records_resampled = N))

for (i in 1:2)
  msg("  %s | %.4f vs %.4f | diff %+.4f [%+.4f, %+.4f] | CI excludes 0: %s",
      res$test[i], res$gini_a[i], res$gini_b[i], res$difference[i],
      res$ci_low[i], res$ci_high[i], res$ci_excludes_zero[i])

write_derived(res, "main_tests.csv")
msg("\n  main_tests.R done")
