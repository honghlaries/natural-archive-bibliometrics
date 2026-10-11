# =============================================================================
# fig1_wedge.R — Figure 1d/e: sampling-publication wedge by archive class
# 对应原脚本：scripts/34_archive_stratified_inequality.R
# 产出：script/_derived/fig1_wedge.csv
# =============================================================================
local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- grep('^--file=', a, value = TRUE)
  s <- c(if (length(f)) dirname(sub('^--file=', '', f[1])), getwd())
  for (x in s) {
    d <- normalizePath(x, mustWork = FALSE)
    for (i in 1:8) {
      if (file.exists(file.path(d, '00_load.R'))) {
        assign('HERE', d, envir = globalenv()); return(invisible())
      }
      p <- dirname(d); if (identical(p, d)) break; d <- p
    }
  }
  stop('Cannot locate 00_load.R')
})
source(file.path(HERE, '00_load.R'))

OUT <- file.path(HERE, '_derived'); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
d   <- load_corpus()
fr  <- load_fractional() %>% filter(record_id %in% d$record_id)
ss  <- load_sampling()   %>% filter(record_id %in% d$record_id)
ros <- load_roster()

UNIV <- align_universe(c(ss$canon, fr$canon), ros$canon)
cat(sprintf('  universe: %d (roster %d + extra %d)\n',
            length(UNIV), length(unique(ros$canon)), length(UNIV) - length(unique(ros$canon))))

vec_of <- function(dd, wcol = NULL) {
  v <- numeric(length(UNIV)); names(v) <- UNIV
  tb <- if (is.null(wcol)) table(dd$canon) else tapply(dd[[wcol]], dd$canon, sum)
  v[names(tb)] <- as.numeric(tb)
  v
}

vc  <- d %>% count(jev_archive_mid, name = 'n') %>% arrange(desc(n))
KEEP <- vc$jev_archive_mid[vc$n >= 100 & vc$jev_archive_mid != 'Unclassified']
rows <- list()
for (tp in KEEP) {
  ids <- d$record_id[d$jev_archive_mid == tp]
  xs  <- vec_of(ss %>% filter(record_id %in% ids))
  xp  <- vec_of(fr %>% filter(record_id %in% ids), 'frac')
  diff <- xs / sum(xs) - xp / sum(xp)
  rows[[tp]] <- tibble(archive_mid = tp, n_records = length(ids),
    n_countries_sampling = sum(xs > 0), median_share_diff = round(median(diff), 4),
    gini_sampling = round(gini(xs), 4), gini_publication = round(gini(xp), 4))
}
out <- bind_rows(rows) %>% arrange(desc(median_share_diff))
print(as.data.frame(out))
cat(sprintf('\n  sampling Gini range: %.4f - %.4f\n', min(out$gini_sampling), max(out$gini_sampling)))
cat(sprintf('  sampling countries : %d - %d\n', min(out$n_countries_sampling), max(out$n_countries_sampling)))
write_csv(out, file.path(OUT, 'fig1_wedge.csv'))
cat('\nsaved _derived/fig1_wedge.csv\n')