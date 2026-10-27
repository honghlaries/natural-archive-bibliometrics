# =============================================================================
# tableS8_review_robustness.R — Table S8: main tests with and without reviews
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
msg("== tableS8_review_robustness.R ==")
corpus <- load_corpus("analysed"); roster <- load_roster(); rc <- roster$canon
mid <- archive_mid_long(corpus)
rec <- corpus %>% transmute(record_id, articleType = jev_articleType) %>%
  inner_join(mid, by = "record_id", relationship = "many-to-many")
ss <- load_sampling(split = TRUE) %>% filter(record_id %in% corpus$record_id) %>% distinct(record_id, canon)
d <- rec %>% inner_join(ss, by = "record_id", relationship = "many-to-many") %>%
  transmute(record_id, archive_mid, articleType, w, canon)
rev_ids <- corpus$record_id[corpus$jev_articleType %in% "Review"]
specs <- list("all records (adopted)" = unique(d$record_id),
              "reviews excluded" = setdiff(unique(d$record_id), rev_ids))
gini_of <- function(dat, tp, roster_only = TRUE) {
  v <- dat %>% filter(archive_mid == tp) %>% group_by(canon) %>% summarise(v = sum(w), .groups = "drop")
  if (roster_only) {
    x <- setNames(rep(0, length(rc)), rc); x[v$canon] <- v$v
  } else {
    x <- setNames(v$v, v$canon)
  }
  gini(as.numeric(x))
}
rows <- lapply(names(specs), function(nm) {
  ids <- specs[[nm]]; dat <- d %>% filter(record_id %in% ids)
  g <- sapply(c("Marine sediment", "Lake sediment", "Polar ice core", "Tree ring"),
              function(tp) gini_of(dat, tp))
  allv <- dat %>% group_by(canon) %>% summarise(v = sum(w), .groups = "drop")
  xw <- setNames(rep(0, length(rc)), rc); xw[allv$canon] <- allv$v
  tibble(specification = nm, records = length(ids),
         reviews_included = length(intersect(ids, rev_ids)),
         marine_gini = round(g[1], 4), lake_gini = round(g[2], 4),
         marine_minus_lake = round(g[1] - g[2], 4),
         ice_core_gini = round(g[3], 4), tree_ring_gini = round(g[4], 4),
         ice_minus_tree_ring = round(g[3] - g[4], 4),
         sampling_gini_w = round(gini(as.numeric(xw)), 4),
         countries_with_sampling_w = sum(xw > 0))
})
tab <- bind_rows(rows)
for (i in seq_len(nrow(tab))) msg("  %-24s n=%5d  H1 %+.4f  H2 %+.4f  sampling Gini %.4f (%d countries)",
                                  tab$specification[i], tab$records[i], tab$marine_minus_lake[i],
                                  tab$ice_minus_tree_ring[i], tab$sampling_gini_w[i], tab$countries_with_sampling_w[i])
write_derived(tab, "tableS8_review_robustness.csv")
msg("  tableS8_review_robustness.R done")