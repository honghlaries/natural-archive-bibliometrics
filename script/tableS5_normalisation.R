# =============================================================================
# tableS5_normalisation.R — Table S5: robustness of the elasticity step to
# output normalisation (per-million vs raw total vs population).
# Uses the archived country-year panel.
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

msg("== tableS5_normalisation.R ==")
panel <- load_panel()
if (is.null(panel)) stop("panel_country_year.csv not found", call. = FALSE)
gdp <- load_gdp_ppp()
d <- panel %>%
  left_join(gdp %>% rename(gdppc_ppp = value), by = c("iso3", "year")) %>%
  filter(!is.na(gdppc_ppp), gdppc_ppp > 0, !is.na(pop), pop > 0, !is.na(n_pub), n_pub > 0) %>%
  mutate(lx = log10(gdppc_ppp),
         lraw = log10(n_pub),
         lpm = log10(1e6 * n_pub / pop),
         lpop = log10(pop)) %>%
  filter(is.finite(lx), is.finite(lraw), is.finite(lpm), is.finite(lpop))
cs <- d %>% group_by(iso3) %>% filter(n() >= 10) %>%
  summarise(s_pm = unname(coef(lm(lpm ~ lx))[2]), s_raw = unname(coef(lm(lraw ~ lx))[2]),
            s_pop = unname(coef(lm(lpop ~ lx))[2]),
            se_pm = unname(summary(lm(lpm ~ lx))$coefficients[2, 2]),
            se_raw = unname(summary(lm(lraw ~ lx))$coefficients[2, 2]),
            se_pop = unname(summary(lm(lpop ~ lx))$coefficients[2, 2]),
            mean_lx = mean(lx), .groups = "drop")
find_brk <- function(v) {
  sw <- sub("^s_", "se_", v); y <- cs[[v]]; w <- 1 / cs[[sw]]^2
  ok <- is.finite(y) & is.finite(w)
  dd <- data.frame(y = y[ok], mlx = cs$mean_lx[ok], w = w[ok])
  gs <- as.numeric(quantile(dd$mlx, seq(.2, .8, length.out = 61))); b <- NULL
  for (g in gs) {
    dd$step <- as.numeric(dd$mlx > g)
    m <- lm(y ~ mlx + step, data = dd, weights = w)
    if (is.null(b) || AIC(m) < b$a) b <- list(a = AIC(m), g = g)
  }
  10^b$g
}
step_at <- function(v) {
  sw <- sub("^s_", "se_", v); y <- cs[[v]]; w <- 1 / cs[[sw]]^2
  dd <- data.frame(y = y, mlx = cs$mean_lx, w = w, step = as.numeric(cs$mean_lx > log10(PPP_BREAK)))
  m <- lm(y ~ mlx + step, data = dd, weights = w)
  s <- summary(m)$coefficients
  c(jump = unname(s["step", 1]), p = unname(s["step", 4]))
}
bp_pm <- find_brk("s_pm"); bp_raw <- find_brk("s_raw")
a <- step_at("s_pm"); b <- step_at("s_raw"); c3 <- step_at("s_pop")
tab <- tibble(
  quantity = c("correlation log population vs log GDP per capita",
               "population elasticity wrt GDP per capita",
               "median country elasticity, per-million basis",
               "median country elasticity, raw-total basis",
               "breakpoint, per-million basis", "breakpoint, raw-total basis",
               "step at 41,458, per-million basis", "step at 41,458, raw-total basis",
               "step at 41,458, population basis",
               "step p, per-million basis", "step p, raw-total basis",
               "population share of the raw-total step (%)",
               "countries with >= 10 annual observations", "panel observations"),
  value = c(round(cor(d$lpop, d$lx), 4), round(unname(coef(lm(lpop ~ lx, data = d))[2]), 4),
            round(median(cs$s_pm), 4), round(median(cs$s_raw), 4),
            round(bp_pm, 0), round(bp_raw, 0),
            round(a["jump"], 4), round(b["jump"], 4), round(c3["jump"], 4),
            signif(a["p"], 3), signif(b["p"], 3),
            round(100 * abs(c3["jump"]) / abs(b["jump"]), 1), nrow(cs), nrow(d)))
for (i in seq_len(nrow(tab))) msg("  %-52s %s", tab$quantity[i], tab$value[i])
write_derived(tab, "tableS5_normalisation.csv")
msg("  tableS5_normalisation.R done")
