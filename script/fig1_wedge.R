# =============================================================================
# fig1_wedge.R — Figure 1d/e: sampling-publication wedge by archive class
# 对应原脚本：scripts/34_archive_stratified_inequality.R（t38 块，口径逐行一致）
# 产出：script/_derived/fig1_wedge.csv
#
# 口径：采样侧权重 w = 1/n（archive_mid 多标签分摊）；发表侧 w * frac；宇宙 = 195 国名册
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

source(file.path(HERE, '_core.R'))
OUT <- file.path(HERE, '_derived'); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# 保留 n>=100 的类型（与权威脚本一致）
n_by_type <- rec %>% group_by(archive_mid) %>% summarise(n_rec = n_distinct(record_id), .groups = 'drop')
KEEP <- n_by_type %>% filter(n_rec >= 100, archive_mid != 'Unclassified') %>% pull(archive_mid)
cat(sprintf('  archive_mid kept (n>=100): %d\n', length(KEEP)))

wedge_for <- function(tp) {
  s <- rec_ss %>% filter(archive_mid == tp) %>% group_by(canon) %>% summarise(v = sum(w), .groups = 'drop')
  p <- rec_fr %>% filter(archive_mid == tp) %>% group_by(canon) %>% summarise(v = sum(w), .groups = 'drop')
  ts <- sum(s$v); tpt <- sum(p$v)
  full_join(s %>% transmute(canon, ss = v / ts),
            p %>% transmute(canon, pp = v / tpt), by = 'canon') %>%
    mutate(ss = replace_na(ss, 0), pp = replace_na(pp, 0), d = ss - pp)
}

rows <- lapply(KEEP, function(tp) {
  wd <- wedge_for(tp)
  wt <- suppressWarnings(wilcox.test(wd$d, alternative = 'greater', exact = FALSE))
  st <- binom.test(sum(wd$d > 0), sum(wd$d != 0), 0.5, alternative = 'greater')
  tibble(archive_mid = tp, median_share_diff = round(median(wd$d), 4),
         mean_share_diff = round(mean(wd$d), 4),
         wilcoxon_p = signif(wt$p.value, 3), sign_test_p = signif(st$p.value, 3))
})
out <- bind_rows(rows) %>% arrange(desc(median_share_diff))
print(as.data.frame(out), row.names = FALSE)
write_csv(out, file.path(OUT, 'fig1_wedge.csv'))
cat('\nsaved _derived/fig1_wedge.csv\n')