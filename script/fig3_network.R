# =============================================================================
# fig3_network.R — Figure 3a: five-layer knowledge network, SDG attribution
# 对应原脚本：scripts/11_sankey_network.R（桑基数据准备）
# 渲染层仍为 Python：plot_fig3b_sdg_share.py / scripts/sankey/
# 产出：script/_derived/fig3_layers.csv
#
# 口径：每条记录在本层权重合计为 1（多标签按 1/n 分摊），各层流量之和 = 语料记录数
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

`%||%` <- function(a, b) if (is.null(a)) b else a
OUT <- file.path(HERE, '_derived'); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
d <- load_corpus(); n <- nrow(d)
cat(sprintf('  corpus %d | network flow total = %d\n', n, n))

LAYERS <- c(archive = 'jev_archive_class', archive_mid = 'jev_archive_mid',
            indicator = 'jev_indicator_class', question = 'jev_axis_a', sdg = 'jev_sdGoals')
rows <- list()
for (nm in names(LAYERS)) {
  vals <- as.character(d[[LAYERS[[nm]]]])
  flow <- list()
  for (v in vals) {
    parts <- trimws(strsplit(v, ';')[[1]])
    parts <- parts[nzchar(parts) & parts != 'NA' & parts != 'nan']
    if (!length(parts)) next
    w <- 1 / length(parts)
    for (p in parts) flow[[p]] <- (flow[[p]] %||% 0) + w
  }
  df <- tibble(layer = nm, node = names(flow), flow = unlist(flow)) %>%
    mutate(share_pct = round(100 * flow / n, 2)) %>% arrange(desc(flow))
  rows[[nm]] <- df
}
out <- bind_rows(rows)
for (nm in names(LAYERS)) {
  cat(sprintf('\n  [%s] layer total %.1f\n', nm, sum(out$flow[out$layer == nm])))
  print(head(as.data.frame(out[out$layer == nm, c('node','flow','share_pct')]), 5))
}
sd <- out %>% filter(layer == 'sdg') %>% mutate(g = as.integer(sub('^(\\d+).*', '\\1', node)))
agg <- sd %>% group_by(g) %>% summarise(flow = sum(flow), .groups='drop') %>% arrange(desc(flow)) %>% head(4)
cat('\n  top 4 SDG:\n'); print(as.data.frame(agg))
cat(sprintf('  top 4 share: %.2f%%\n', 100 * sum(agg$flow) / n))
write_csv(out, file.path(OUT, 'fig3_layers.csv'))
cat('\nsaved _derived/fig3_layers.csv\n')