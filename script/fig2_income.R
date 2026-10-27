# =============================================================================
# fig2_income.R — Figure 2a-e: income structure and the scaling step
#
# 2a  Country counts, publications and sampling by World Bank income group
# 2b  Country-level publication ~ sampling relation, Tweedie GAM (k = 6)
# 2c  Median residuals by publication size class (log10(x + 0.5) OLS, bootstrap CI)
# 2d  Country-year publications per million ~ GDP per capita, PPP constant 2021
# 2e  Country-specific elasticities and the precision-weighted step model
#
# Outputs: fig2a_income_groups.csv, fig2b_gam_grid.csv, fig2b_gam_models.csv,
#          fig2c_residual_bins.csv, fig2d_panel.csv, fig2d_scaling_regressions.csv,
#          fig2e_country_slopes.csv, fig2e_step_model.csv
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

suppressPackageStartupMessages(library(mgcv))
msg("== fig2_income.R ==")
corpus <- load_corpus("analysed")
m <- build_country_metrics(corpus)
eco <- load_economy()

# ---- 2a income groups --------------------------------------------------------
mi <- m %>% left_join(eco %>% select(canon, income_group), by = "canon")
ig <- mi %>% filter(!is.na(income_group)) %>% group_by(income_group) %>%
  summarise(countries_n = n(), publications_n = sum(publications_frac),
            sampling_n = sum(sampling_total), .groups = "drop") %>%
  mutate(share_countries_pct = round(100 * countries_n / sum(countries_n), 2),
         share_publications_pct = round(100 * publications_n / sum(publications_n), 2),
         share_sampling_pct = round(100 * sampling_n / sum(sampling_n), 2)) %>%
  arrange(desc(publications_n))
msg("
  2a income groups:")
for (i in seq_len(nrow(ig)))
  msg("    %-20s n=%2d  pub=%7.1f (%.2f%%)  samp=%6.0f (%.2f%%)",
      ig$income_group[i], ig$countries_n[i], ig$publications_n[i],
      ig$share_publications_pct[i], ig$sampling_n[i], ig$share_sampling_pct[i])

# ---- 2b Tweedie GAM ---------------------------------------------------------
dd <- m %>% transmute(pub = publications_frac, samp = sampling_total, lx = log1p(publications_frac))
mods <- list(
  gaussian_linear = lm(lx ~ pub, data = dd),
  gaussian_gam = gam(lx ~ s(pub, k = 6), data = dd),
  poisson_linear = glm(samp ~ pub, family = poisson, data = dd),
  poisson_gam = gam(samp ~ s(pub, k = 6), family = poisson, data = dd),
  zip_gam = gam(samp ~ s(pub, k = 6), family = ziP, data = dd),
  tweedie_gam = gam(samp ~ s(lx, k = 6), family = tw, data = dd))
fit_tw <- mods$tweedie_gam
st <- summary(fit_tw)$s.table
msg("
  2b Tweedie GAM: edf=%.3f  F=%.1f  p=%.3g  theta=%.3f  dev.expl=%.2f%%",
    st[1, 1], st[1, 3], st[1, 4], fit_tw$family$getTheta(TRUE), 100 * summary(fit_tw)$dev.expl)
models <- tibble(model = names(mods),
                 aic = round(vapply(mods, AIC, numeric(1)), 1),
                 family = vapply(mods, function(x) {
                   if (inherits(x, "lm")) "gaussian" else as.character(x$family$family)
                 }, character(1)))
grid <- tibble(lx = seq(0, max(dd$lx), length.out = 200))
pr <- predict(fit_tw, grid, type = "response", se.fit = TRUE)
grid <- grid %>% mutate(fit = as.numeric(pr$fit),
                        lo = as.numeric(pr$fit - 1.96 * pr$se.fit),
                        hi = as.numeric(pr$fit + 1.96 * pr$se.fit))
msg("    AIC: %s", paste(sprintf("%s=%.1f", models$model, models$aic), collapse = " | "))

# ---- 2c residual bins -------------------------------------------------------
d <- m %>% arrange(desc(publications_frac)) %>%
  mutate(lx10 = log10(publications_frac + 0.5), ly10 = log10(sampling_total + 0.5))
lr <- lm(ly10 ~ lx10, data = d); d$res <- residuals(lr)
d <- d %>% mutate(grp = cut(publications_frac, c(-1, 0, 5, 20, 100, Inf),
                            labels = c("0", "1-5", "6-20", "21-100", ">100")))
set.seed(20261001)
bins <- d %>% group_by(grp) %>% summarise(
  n = n(), median_publications = median(publications_frac),
  median_sampling = median(sampling_total), median_residual = median(res),
  ci_low = quantile(replicate(2000, median(sample(res, replace = TRUE))), .025),
  ci_high = quantile(replicate(2000, median(sample(res, replace = TRUE))), .975),
  .groups = "drop")
msg("
  2c median residuals by publication class (log10 units):")
for (i in seq_len(nrow(bins)))
  msg("    %-7s n=%2d  median %+.4f  [%+.4f, %+.4f]", bins$grp[i], bins$n[i],
      bins$median_residual[i], bins$ci_low[i], bins$ci_high[i])

# ---- 2d/2e country-year panel (shipped in the archive) ----------------------
# panel_country_year.csv carries the main-analysis country-year panel
# (n_pub = publications counted by the country-year convention used in the
# scaling analysis). PPP GDP per capita is joined from the World Bank series.
panel_raw <- load_panel()
if (is.null(panel_raw)) stop("panel_country_year.csv is required for Figure 2d/2e", call. = FALSE)
gdp <- load_gdp_ppp()
panel <- panel_raw %>%
  left_join(gdp %>% rename(gdppc_ppp = value), by = c("iso3", "year")) %>%
  filter(!is.na(gdppc_ppp), gdppc_ppp > 0, !is.na(pop), pop > 0,
         !is.na(n_pub), n_pub > 0, year >= YEAR_MIN, year <= YEAR_MAX) %>%
  mutate(pub_per_million = 1e6 * n_pub / pop,
         lx = log10(gdppc_ppp), ly = log10(pub_per_million)) %>%
  filter(is.finite(lx), is.finite(ly))
msg("
  2d panel: %d observations / %d countries", nrow(panel), n_distinct(panel$iso3))
fit_spec <- function(dat, label) {
  m0 <- lm(ly ~ lx, data = dat)
  tibble(specification = label, n_obs = nrow(dat), n_countries = n_distinct(dat$iso3),
         slope = round(unname(coef(m0)[2]), 4), intercept = round(unname(coef(m0)[1]), 4),
         r2 = round(summary(m0)$r.squared, 4),
         spearman = round(cor(dat$lx, dat$ly, method = "spearman"), 4))
}
latest <- panel %>% group_by(iso3) %>% slice_max(year, n = 1, with_ties = FALSE) %>% ungroup()
scaling <- bind_rows(fit_spec(panel, "full panel (all observations)"),
                     fit_spec(latest, "latest year per country (cross-section)"),
                     fit_spec(panel %>% filter(year >= 1990), "1990-2025 panel"))
msg("    log-log slope: %s", paste(sprintf("%s=%.3f", scaling$specification, scaling$slope), collapse = " | "))

# 2e country elasticities + step model
cs <- panel %>% group_by(iso3) %>% filter(n() >= 10) %>%
  summarise(n = n(), slope = unname(coef(lm(ly ~ lx))[2]),
            se = unname(summary(lm(ly ~ lx))$coefficients[2, 2]),
            mean_lx = mean(lx), mean_ly = mean(ly), .groups = "drop") %>%
  filter(is.finite(slope), is.finite(se), se > 0) %>% mutate(prec = 1 / se^2)
AICm <- function(x) -2 * as.numeric(logLik(x)) + 2 * length(coef(x))
fit_single <- lm(slope ~ mean_lx, data = cs, weights = prec)
grid_lx <- as.numeric(quantile(cs$mean_lx, seq(.2, .8, length.out = 61)))
best <- NULL
for (g in grid_lx) {
  dd2 <- cs; dd2$step <- as.numeric(dd2$mean_lx > g)
  mi2 <- lm(slope ~ mean_lx + step, data = dd2, weights = prec)
  a <- AICm(mi2)
  if (is.null(best) || a < best$aic) best <- list(aic = a, g = g, m = mi2)
}
X <- model.matrix(best$m); e <- residuals(best$m); h <- hatvalues(best$m)
bread <- solve(t(X) %*% (cs$prec * X))
meat <- t(X) %*% (cs$prec^2 * diag((e / (1 - h))^2)) %*% X
se_r <- sqrt(diag(bread %*% meat %*% bread))
co <- unname(coef(best$m)); pj <- 2 * pt(-abs(co / se_r), df = best$m$df.residual)
step_tab <- tibble(
  quantity = c("breakpoint PPP int$", "jump", "jump HC3 se", "jump p (HC3)",
               "AIC single line", "AIC step", "BIC single line", "BIC step",
               "countries with >= 10 years", "countries above pooled slope"),
  value = c(round(10^best$g), round(co[3], 2), round(se_r[3], 2), signif(pj[3], 3),
            round(AICm(fit_single), 1), round(best$aic, 1),
            round(-2 * as.numeric(logLik(fit_single)) + log(nrow(cs)) * 3, 1),
            round(-2 * as.numeric(logLik(best$m)) + log(nrow(cs)) * 4, 1),
            nrow(cs), sum(cs$slope > unname(coef(lm(ly ~ lx, data = panel))[2]))))
msg("
  2e step model:")
for (i in seq_len(nrow(step_tab))) msg("    %-30s %s", step_tab$quantity[i], step_tab$value[i])

write_derived(ig, "fig2a_income_groups.csv")
write_derived(grid, "fig2b_gam_grid.csv")
write_derived(models, "fig2b_gam_models.csv")
write_derived(bins, "fig2c_residual_bins.csv")
write_derived(panel, "fig2d_panel.csv")
write_derived(scaling, "fig2d_scaling_regressions.csv")
write_derived(cs, "fig2e_country_slopes.csv")
write_derived(step_tab, "fig2e_step_model.csv")
msg("
  fig2_income.R done")
