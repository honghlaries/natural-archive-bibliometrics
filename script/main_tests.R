# =============================================================================
# main_tests.R — 主检验 H1/H2：设施依赖是否提高采样集中度
#   H1（主）海洋沉积物 vs 湖泊沉积物   H2（次）极地冰芯 vs 树轮
# 对应原脚本：scripts/34_archive_stratified_inequality.R（口径逐行一致）
# 产出：script/_derived/main_tests.csv
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

T4 <- c('Marine sediment', 'Lake sediment', 'Polar ice core', 'Tree ring')
g4 <- sapply(T4, function(tp) gof(rec_ss, tp))
print(round(g4, 4))

h1 <- g4[['Marine sediment']] - g4[['Lake sediment']]
h2 <- g4[['Polar ice core']] - g4[['Tree ring']]

cat(sprintf('\n  H1 marine vs lake : %.4f vs %.4f | diff %+.4f\n',
            g4[['Marine sediment']], g4[['Lake sediment']], h1))
cat(sprintf('  H2 ice vs tree    : %.4f vs %.4f | diff %+.4f\n',
            g4[['Polar ice core']], g4[['Tree ring']], h2))

res <- tibble(comparison = c('Marine vs lake sediment', 'Polar ice core vs tree ring'),
              gini_a = round(c(g4[['Marine sediment']], g4[['Polar ice core']]), 4),
              gini_b = round(c(g4[['Lake sediment']], g4[['Tree ring']]), 4),
              difference = round(c(h1, h2), 4))
write_csv(res, file.path(OUT, 'main_tests.csv'))
cat('\nsaved _derived/main_tests.csv\n')