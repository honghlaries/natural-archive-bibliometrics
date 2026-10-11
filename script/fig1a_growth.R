# =============================================================================
# fig1a_growth.R — Figure 1a/b: growth of the field and its developmental periods
# 对应原脚本：scripts/01_corpus_overview.R + scripts/02_stage_detection.R
# 产出：script/_derived/fig1a_growth.csv
# =============================================================================
# ---- 引导：定位脚本目录并加载公共层（不依赖工作目录）-----------------------
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

d <- load_corpus() %>% filter(!is.na(year))
yearly <- d %>% filter(year >= YEAR_MIN, year <= YEAR_MAX) %>% count(year, name = 'publications_n')

cat(sprintf('  corpus            : %d\n', nrow(d)))
cat(sprintf('  in window %d-%d  : %d\n', YEAR_MIN, YEAR_MAX, sum(yearly$publications_n)))
cat(sprintf('  outside window    : %d\n', sum(d$year > YEAR_MAX | d$year < YEAR_MIN)))

BREAKS <- c(1980L, 2000L, 2009L, 2017L, 2026L)
periods <- tibble(period = c('1980-1999','2000-2008','2009-2016','2017-2025'),
                  start = BREAKS[1:4], end = BREAKS[2:5] - 1L) %>%
  rowwise() %>%
  mutate(n = sum(yearly$publications_n[yearly$year >= start & yearly$year <= end])) %>%
  ungroup() %>% select(period, start, end, n)
print(as.data.frame(periods))

cat(sprintf('\n  1980 output       : %d\n', yearly$publications_n[yearly$year == 1980]))
cat(sprintf('  2025 output       : %d\n', yearly$publications_n[yearly$year == 2025]))
cat(sprintf('  2021-2025 mean    : %.1f\n', mean(yearly$publications_n[yearly$year >= 2021 & yearly$year <= 2025])))

write_csv(periods, file.path(OUT, 'fig1a_growth.csv'))
cat('\nsaved _derived/fig1a_growth.csv\n')