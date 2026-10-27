# =============================================================================
# figS7_growth.R — Figure S7: growth of the field and its developmental periods
#
# (a) annual output with the fitted logistic curve, and archive-class composition
# (b) BIC as a function of the number of change points (binary segmentation)
#
# Method: binary segmentation on the annual series (1980-2025, minimum segment
# length 5), BIC = n log(RSS/n) + k * 2 log(n); logistic K/(1+exp(-r(t-t0))).
# The four reporting periods are the adopted boundaries 1980/2000/2009/2017/2025.
#
# Outputs: figS7_yearly.csv, figS7_composition.csv, figS7_periods.csv,
#          figS7_bic.csv, figS7_logistic.csv
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

msg("== figS7_growth.R ==")
corpus <- load_corpus("analysed")
ca <- corpus %>% filter(!is.na(year))
years <- YEAR_MIN:YEAR_MAX
series <- tibble(year = years) %>%
  left_join(ca %>% filter(year %in% years) %>% count(year, name = "total_n"), by = "year") %>%
  mutate(total_n = replace_na(total_n, 0L))
y <- series$total_n
msg("  1980 = %d | 2025 = %d | peak %d in %d | mean 2021-2025 = %.1f",
    y[years == 1980], y[years == 2025], max(y), years[which.max(y)],
    mean(y[years >= 2021]))
BOUNDS <- c(1980L, 2000L, 2009L, 2017L, 2025L)
per_of <- function(yr) cut(yr, c(1979, 1999, 2008, 2016, 2025),
                           labels = c("1980-1999", "2000-2008", "2009-2016", "2017-2025"))
periods <- ca %>% filter(year %in% years) %>% mutate(period = per_of(year)) %>%
  count(period, name = "records_n")
for (i in seq_len(nrow(periods))) msg("  %s : %d", periods$period[i], periods$records_n[i])

# archive-class composition per year and period (JEV archive_class, official)
comp <- ca %>% filter(year %in% years) %>%
  count(year, archive_class = jev_archive_class, name = "n") %>%
  group_by(year) %>% mutate(share = n / sum(n)) %>% ungroup() %>%
  rename(node = archive_class)
per_comp <- ca %>% filter(year %in% years) %>% mutate(period = per_of(year)) %>%
  count(period, archive_class = jev_archive_class, name = "n") %>%
  group_by(period) %>% mutate(share = n / sum(n)) %>% ungroup()

# ---- binary segmentation + BIC ---------------------------------------------
seg_sse <- function(x) if (!length(x)) 0 else sum((x - mean(x))^2)
binseg <- function(x, k, min_size) {
  segs <- list(c(1L, length(x)))
  if (k > 0) for (step in seq_len(k)) {
    best <- NULL
    for (i in seq_along(segs)) {
      s <- segs[[i]][1]; e <- segs[[i]][2]
      if (e - s + 1L < 2L * min_size) next
      for (cut in seq.int(s + min_size - 1L, e - min_size)) {
        gain <- seg_sse(x[s:e]) - seg_sse(x[s:cut]) - seg_sse(x[(cut + 1L):e])
        if (is.null(best) || gain > best$gain) best <- list(gain = gain, i = i, cut = cut)
      }
    }
    if (is.null(best) || best$gain <= 0) break
    s <- segs[[best$i]][1]; e <- segs[[best$i]][2]
    segs[[best$i]] <- c(best$cut + 1L, e)
    segs <- append(segs, list(c(s, best$cut)), after = best$i - 1L)
  }
  segs[order(vapply(segs, function(z) z[1], 0L))]
}
bic_tbl <- bind_rows(lapply(0:6, function(k) {
  segs <- binseg(y, k, 5)
  rss <- sum(vapply(segs, function(s) seg_sse(y[s[1]:s[2]]), numeric(1)))
  kk <- length(segs) - 1L
  cps <- vapply(segs[-length(segs)], function(s) years[s[2]], numeric(1))
  tibble(changepoints_k = kk, changepoints = if (length(cps)) paste(cps, collapse = ";") else "-",
         rss = round(rss, 1), bic = round(length(y) * log(rss / length(y)) + kk * 2 * log(length(y)), 2))
}))
msg("
  BIC surface:")
for (i in seq_len(nrow(bic_tbl))) msg("    k=%d  cps=%-12s  BIC=%.2f", bic_tbl$changepoints_k[i],
                                      bic_tbl$changepoints[i], bic_tbl$bic[i])

# ---- logistic fit -----------------------------------------------------------
t_idx <- seq_along(y) - 1
# logistic fit via bounded Nelder-Mead (K > 0, 0 < r < 0.5).
obj <- function(par) {
  K <- exp(par[1]); rate <- plogis(par[2]) * 0.5; t0 <- par[3]
  yh <- K / (1 + exp(-rate * (t_idx - t0)))
  sum((y - yh)^2)
}
fitL <- optim(c(log(max(y) * 1.35), qlogis(0.2), 30), obj, method = "Nelder-Mead",
              control = list(maxit = 50000, reltol = 1e-12))
bestK <- exp(fitL$par[1]); bestr <- plogis(fitL$par[2]) * 0.5; bestt0 <- fitL$par[3]
yhat <- as.numeric(bestK / (1 + exp(-bestr * (t_idx - bestt0))))
if (length(yhat) != length(y)) stop("logistic fit length mismatch: ", length(yhat), " vs ", length(y), " | t_idx ", length(t_idx), " K ", length(bestK), " r ", length(bestr), " t0 ", length(bestt0), " y ", length(y))
r2 <- 1 - sum((y - yhat)^2) / sum((y - mean(y))^2)
msg("
  logistic: K=%.1f r=%.4f t0=%d R2=%.4f",
    round(bestK, 1), round(bestr, 4), as.integer(round(bestt0 + YEAR_MIN)), r2)
series <- series %>% mutate(fit = yhat)
logistic <- tibble(K = round(bestK, 1), r = round(bestr, 4),
                   t0_year = as.integer(round(bestt0 + YEAR_MIN)), r2 = round(r2, 4),
                   peak_year = years[which.max(y)], peak_publications = max(y),
                   mean_2021_2025 = round(mean(y[years >= 2021]), 1))

write_derived(series, "figS7_yearly.csv")
write_derived(comp, "figS7_composition.csv")
write_derived(per_comp, "figS7_period_composition.csv")
write_derived(periods, "figS7_periods.csv")
write_derived(bic_tbl, "figS7_bic.csv")
write_derived(logistic, "figS7_logistic.csv")
msg("
  figS7_growth.R done")
