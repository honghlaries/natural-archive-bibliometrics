# =============================================================================
# tableS1_goals_by_period.R — Table S1: cognitive goal composition by developmental period
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
msg("== tableS1_goals_by_period.R ==")
corpus <- load_corpus("analysed")
ca <- corpus %>% filter(!is.na(year), year >= YEAR_MIN, year <= YEAR_MAX)
per_of <- function(y) cut(y, c(1979, 1999, 2008, 2016, 2025),
                         labels = c("1980-1999", "2000-2008", "2009-2016", "2017-2025"))
long <- ca %>% select(record_id, year, v = jev_axis_a) %>% mutate(v = as.character(v)) %>%
  filter(!is.na(v), nzchar(v)) %>% separate_rows(v, sep = ";") %>% mutate(v = trimws(v)) %>%
  filter(nzchar(v)) %>% group_by(record_id) %>% mutate(w = 1 / n()) %>% ungroup() %>%
  mutate(period = per_of(year)) %>% filter(!is.na(period))
tab <- long %>% group_by(period, axis_a = v) %>% summarise(records_n = sum(w), .groups = "drop") %>%
  group_by(period) %>% mutate(share_pct = round(100 * records_n / sum(records_n), 2)) %>%
  ungroup() %>% mutate(records_n = round(records_n), period = as.character(period)) %>%
  arrange(period, desc(records_n))
for (i in seq_len(nrow(tab))) msg("  %-10s %-34s %5d %6.2f%%", tab$period[i], tab$axis_a[i],
                                  tab$records_n[i], tab$share_pct[i])
write_derived(tab, "tableS1_goals_by_period.csv")
msg("  tableS1_goals_by_period.R done")