# =============================================================================
# tableS4_archive_contrasts.R — Table S4: archive-type contrasts across corpus scopes
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
msg("== tableS4_archive_contrasts.R ==")
set.seed(42); msg("  (record-block bootstrap, B = 400 for the scope comparison)")
records <- load_corpus("records"); corpus <- load_corpus("analysed")
roster <- load_roster(); rc <- roster$canon
mid <- archive_mid_long(corpus)
rec <- corpus %>% transmute(record_id) %>% inner_join(mid, by = "record_id", relationship = "many-to-many")
ss <- load_sampling(split = TRUE) %>% filter(record_id %in% corpus$record_id) %>% distinct(record_id, canon)
T4 <- c("Marine sediment", "Lake sediment", "Polar ice core", "Tree ring")
gini_of <- function(d, tp) {
  v <- d %>% filter(archive_mid == tp) %>% group_by(canon) %>% summarise(v = sum(w), .groups = "drop")
  x <- setNames(rep(0, length(rc)), rc); x[v$canon] <- v$v; gini(as.numeric(x))
}
scopes <- list(
  "analysed corpus (screened WoS + OpenAlex)" = corpus$record_id,
  "Web of Science only" = records$record_id[records$source %in% c("WoS", "WoS2") & records$in_analysed_corpus %in% c(TRUE, "TRUE", 1)],
  "OpenAlex only" = records$record_id[records$source == "OpenAlex" & records$in_analysed_corpus %in% c(TRUE, "TRUE", 1)])
run_scope <- function(label, ids) {
  ids <- intersect(ids, corpus$record_id)
  d <- rec %>% filter(record_id %in% ids) %>% inner_join(ss, by = "record_id", relationship = "many-to-many")
  if (!nrow(d)) return(NULL)
  rec_ids <- unique(d$record_id)
  g <- sapply(T4, function(tp) gini_of(d, tp))
  boot <- replicate(400, {
    s <- sample(rec_ids, length(rec_ids), replace = TRUE)
    tag <- tibble(record_id = s, .b = seq_along(s)) %>%
      left_join(rec %>% filter(record_id %in% ids) %>% select(record_id, archive_mid, w),
                by = "record_id", relationship = "many-to-many")
    sl <- tag %>% inner_join(ss, by = "record_id", relationship = "many-to-many") %>%
      transmute(.b, archive_mid, w, canon)
    sapply(T4, function(tp) gini_of(sl %>% filter(archive_mid == tp), tp))
  })
  rows <- lapply(list(c(1, 2, "Marine vs lake sediment"), c(3, 4, "Polar ice core vs tree ring")), function(x) {
    i <- as.integer(x[1]); j <- as.integer(x[2]); dif <- g[i] - g[j]
    bb <- boot[i, ] - boot[j, ]; q <- quantile(bb, c(.025, .975), na.rm = TRUE, names = FALSE)
    tibble(comparison = x[3], corpus = label, records = length(rec_ids),
           gini_a = round(g[i], 4), gini_b = round(g[j], 4), difference = round(dif, 4),
           ci_low = round(q[1], 4), ci_high = round(q[2], 4),
           ci_excludes_zero = !(q[1] <= 0 && q[3] >= 0))
  })
  bind_rows(rows)
}
tab <- bind_rows(lapply(names(scopes), function(nm) run_scope(nm, scopes[[nm]])))
for (i in seq_len(nrow(tab))) msg("  %-40s %-40s %6d diff %+.4f [%+.4f, %+.4f]",
                                  tab$comparison[i], tab$corpus[i], tab$records[i],
                                  tab$difference[i], tab$ci_low[i], tab$ci_high[i])
write_derived(tab, "tableS4_archive_contrasts.csv")
msg("  tableS4_archive_contrasts.R done")