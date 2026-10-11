# =============================================================================
# fig1_geography.R — Figure 1a-c: nine-class typology, concentration, continents
# 对应原脚本：scripts/07_country_classification.R + scripts/08_concentration_inequality.R
# 产出：script/_derived/fig1_geography.csv
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
nc  <- load_classes()

pub_c <- fr %>% group_by(canon) %>% summarise(pub = sum(frac), .groups = 'drop')
smp_c <- ss %>% count(canon, name = 'smp')

m <- ros %>% select(canon, country = 英文名) %>%
  left_join(pub_c, by = 'canon') %>% left_join(smp_c, by = 'canon') %>%
  mutate(pub = replace_na(pub, 0), smp = replace_na(smp, 0L)) %>%
  left_join(nc %>% select(country, class), by = 'country')

TOT_P <- sum(m$pub); TOT_S <- sum(m$smp)
cat(sprintf('  countries         : %d\n', nrow(m)))
cat(sprintf('  publication Gini  : %.4f\n', gini(m$pub)))
cat(sprintf('  sampling Gini     : %.4f\n', gini(m$smp)))
cat(sprintf('  Spearman rho      : %.3f\n', cor(m$pub, m$smp, method = 'spearman')))
cat(sprintf('  Pearson r         : %.3f\n', cor(m$pub, m$smp)))
hh <- m %>% filter(class == 'HH')
cat(sprintf('  HH countries      : %d (%.2f%%)\n', nrow(hh), 100 * nrow(hh) / nrow(m)))
cat(sprintf('  HH publication    : %.2f%%\n', 100 * sum(hh$pub) / TOT_P))
cat(sprintf('  HH sampling       : %.2f%%\n', 100 * sum(hh$smp) / TOT_S))
cat(sprintf('  double-zero (LL)  : %d\n', sum(m$class == 'LL' & m$pub == 0 & m$smp == 0)))

cat('\n  nine classes:\n'); print(count(m, class) %>% arrange(class))

tm <- fr %>% left_join(ros %>% select(canon, 中文名, 大洲), by = 'canon')
cat('\n  continents (fractional):\n')
print(tm %>% group_by(大洲) %>% summarise(pub = round(sum(frac), 1),
      share = round(100 * sum(frac) / TOT_P, 2), .groups = 'drop') %>% arrange(desc(pub)))

cat('\n  top 10 producers:\n')
print(pub_c %>% left_join(ros %>% select(canon, 中文名), by = 'canon') %>%
      arrange(desc(pub)) %>% head(10) %>% select(中文名, pub))

write_csv(m, file.path(OUT, 'fig1_geography.csv'))
cat('\nsaved _derived/fig1_geography.csv\n')