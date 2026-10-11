# =============================================================================
# fig2_scaling.R — Figure 2: income groups and scaling
# 对应原脚本：scripts/10_income_groups.R + scripts/29_scaling_ppp.R
# 产出：script/_derived/fig2_publications_by_country.csv
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
d  <- load_corpus()
fr <- load_fractional() %>% filter(record_id %in% d$record_id)
pub <- fr %>% group_by(canon) %>% summarise(fractional_publications = sum(frac), .groups = 'drop') %>%
  arrange(desc(fractional_publications))
cat(sprintf('  countries : %d\n', nrow(pub)))
cat(sprintf('  total     : %.0f\n', sum(pub$fractional_publications)))
cat('  top 5:\n'); print(head(as.data.frame(pub), 5))
cat('\n')
cat('  NOTE: income grouping, PPP GDP per capita and the elasticity step require\n')
cat('        the World Bank income panel and the PPP series, which are not part of\n')
cat('        the shared dataset. Full reproduction: scripts/10_income_groups.R and\n')
cat('        scripts/29_scaling_ppp.R in the analysis repository.\n')
write_csv(pub, file.path(OUT, 'fig2_publications_by_country.csv'))
cat('\nsaved _derived/fig2_publications_by_country.csv\n')