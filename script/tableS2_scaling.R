# =============================================================================
# tableS2_scaling.R — Table S2: scaling regressions under alternative specifications
#
# Uses the archived country-year panel (panel_country_year.csv). Rows 1-5 use
# GDP per capita in current US$ (the legacy specification of the table); the
# last two rows repeat the main specifications in constant 2021 PPP int$.
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

msg("== tableS2_scaling.R ==")
panel <- load_panel()
if (is.null(panel)) stop("panel_country_year.csv not found", call. = FALSE)
gdp <- load_gdp_ppp()
d <- panel %>%
  left_join(gdp %>% rename(gdppc_ppp = value), by = c("iso3", "year")) %>%
  filter(!is.na(gdp_per_capita), gdp_per_capita > 0, !is.na(pop), pop > 0) %>%
  mutate(ly = log10(pub_per_million),
         lx_cur = log10(gdp_per_capita),
         lx_ppp = log10(gdppc_ppp)) %>%
  filter(is.finite(ly))
fit_spec <- function(dat, xcol, label) {
  dat <- dat %>% filter(!is.na(.data[[xcol]]))
  m <- lm(reformulate(xcol, "ly"), data = dat)
  tibble(specification = label, n_obs = nrow(dat), n_countries = n_distinct(dat$iso3),
         slope = round(unname(coef(m)[2]), 4), intercept = round(unname(coef(m)[1]), 4),
         coefficient_A = signif(10^unname(coef(m)[1]), 4),
         r2 = round(summary(m)$r.squared, 4),
         spearman = round(cor(dat[[xcol]], dat$ly, method = "spearman"), 4))
}
latest <- d %>% group_by(iso3) %>% slice_max(year, n = 1, with_ties = FALSE) %>% ungroup()
tab <- bind_rows(
  fit_spec(d, "lx_cur", "full panel, current US$ (all observations)"),
  fit_spec(latest, "lx_cur", "latest year per country, current US$ (cross-section)"),
  fit_spec(d %>% filter(year >= 1990), "lx_cur", "1990-2025 panel, current US$"),
  fit_spec(d %>% filter(gdp_per_capita <= 35119), "lx_cur", "below threshold (<= US$35,119)"),
  fit_spec(d %>% filter(gdp_per_capita > 35119), "lx_cur", "above threshold (> US$35,119)"),
  fit_spec(d, "lx_ppp", "full panel, PPP constant 2021 int$"),
  fit_spec(latest, "lx_ppp", "latest year per country, PPP constant 2021 int$"))
for (i in seq_len(nrow(tab))) msg("  %-50s n=%4d cty=%2d slope=%7.4f r2=%.4f",
                                  tab$specification[i], tab$n_obs[i], tab$n_countries[i],
                                  tab$slope[i], tab$r2[i])
write_derived(tab, "tableS2_scaling.csv")
msg("  tableS2_scaling.R done")
