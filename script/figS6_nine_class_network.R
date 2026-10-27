# =============================================================================
# figS6_nine_class_network.R — Figure S6: five-layer network under the
#                              nine-class country typology (HH ... LL)
#
# Basis: the 31,964 in-window records (1980-2025). The country layer is split
# across the countries of each record by fractional weight, so a record's
# country-layer contribution adds up to one; the other layers are split 1/n.
#
# Outputs: figS6_layers.csv, figS6_links.csv, figS6_pathways_top20.csv
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

msg("== figS6_nine_class_network.R ==")
corpus <- load_corpus("analysed")
roster <- load_roster(); roster_canon <- roster$canon
m <- build_country_metrics(corpus)
nz_pub <- m$publications_frac[m$publications_frac > 0]
nz_samp <- m$sampling_total[m$sampling_total > 0]
brk <- list(pub = quantile(nz_pub, c(.25, .75), names = FALSE),
            samp = quantile(nz_samp, c(.25, .75), names = FALSE))
band <- function(x, b) ifelse(x <= b[1], "L", ifelse(x <= b[2], "M", "H"))
m <- m %>% mutate(double_zero = publications_frac == 0 & sampling_total == 0,
                  pub_band = ifelse(double_zero, "L", band(publications_frac, brk$pub)),
                  samp_band = ifelse(double_zero, "L", band(sampling_total, brk$samp)),
                  class = paste0(pub_band, samp_band))
ca <- corpus %>% filter(!is.na(year), year >= YEAR_MIN, year <= YEAR_MAX)
fr <- load_fractional(analysed = TRUE) %>% filter(record_id %in% ca$record_id) %>%
  filter(canon %in% roster_canon) %>% left_join(m %>% select(canon, class), by = "canon") %>%
  filter(!is.na(class))
tier <- fr %>% group_by(record_id, class) %>% summarise(w = sum(frac), .groups = "drop") %>%
  group_by(record_id) %>% mutate(w = w / sum(w)) %>% ungroup()
LNAMES <- c("Country tier", "Archive", "Indicator", "Question", "SDGs")
layer_long <- function(col, layer) {
  x <- ca %>% select(record_id, v = all_of(col)) %>% mutate(v = as.character(v)) %>%
    filter(!is.na(v), nzchar(v)) %>% separate_rows(v, sep = ";") %>%
    mutate(v = trimws(v)) %>% filter(nzchar(v), v != "NA") %>%
    group_by(record_id) %>% mutate(w = 1 / n()) %>% ungroup()
  x %>% transmute(record_id, layer = layer, node = v, w)
}
lay <- bind_rows(
  tier %>% transmute(record_id, layer = "Country tier", node = class, w),
  layer_long("jev_archive_class", "Archive"),
  layer_long("jev_indicator_class", "Indicator"),
  layer_long("jev_axis_a", "Question"),
  layer_long("jev_sdGoals", "SDGs") %>% mutate(node = paste0("SDG ", sub("[.].*", "", node)))
) %>% mutate(layer = factor(layer, levels = LNAMES))
layers <- lay %>% group_by(layer, node) %>% summarise(flow = sum(w), .groups = "drop") %>%
  group_by(layer) %>% mutate(share_pct = round(100 * flow / sum(flow), 2)) %>% ungroup() %>%
  mutate(layer = as.character(layer), node = as.character(node))
tiers <- layers %>% filter(layer == "Country tier") %>% arrange(desc(flow))
msg("
  country-tier flow (records):")
for (i in seq_len(nrow(tiers))) msg("    %-3s %8.1f  (%.2f%%)", tiers$node[i], tiers$flow[i], tiers$share_pct[i])
hh <- sum(tiers$flow[tiers$node == "HH"])
msg("  HH flow: %.0f / %.0f = %.2f%%", hh, sum(tiers$flow), 100 * hh / sum(tiers$flow))
links <- list()
for (j in seq_len(length(LNAMES) - 1)) {
  l1 <- LNAMES[j]; l2 <- LNAMES[j + 1]
  a1 <- lay %>% filter(layer == l1) %>% select(record_id, n1 = node, w1 = w)
  a2 <- lay %>% filter(layer == l2) %>% select(record_id, n2 = node, w2 = w)
  jj <- inner_join(a1, a2, by = "record_id", relationship = "many-to-many") %>% mutate(w = w1 * w2)
  links[[j]] <- jj %>% group_by(n1, n2) %>% summarise(flow = sum(w), .groups = "drop") %>%
    transmute(layer = l1, source = n1, target = n2, flow)
}
links <- bind_rows(links)
pw <- lay %>% filter(layer == LNAMES[1]) %>% select(record_id, !!LNAMES[1] := node, w = w)
for (L in LNAMES[-1]) {
  x <- lay %>% filter(layer == L) %>% select(record_id, node, w2 = w)
  pw <- pw %>% inner_join(x, by = "record_id", relationship = "many-to-many") %>%
    mutate(w = w * w2) %>% select(-w2) %>% rename(!!L := node)
}
pw <- pw %>% group_by(record_id) %>% mutate(w = w / sum(w)) %>% ungroup()
pathways <- pw %>% group_by(across(all_of(LNAMES))) %>% summarise(flow = sum(w), .groups = "drop") %>%
  arrange(desc(flow))
msg("  five-dimensional pathways: %d | top-20 all from HH: %s", nrow(pathways),
    all(grepl("^HH", pathways[["Country tier"]][1:20])))
write_derived(layers, "figS6_layers.csv")
write_derived(links, "figS6_links.csv")
write_derived(head(pathways, 20), "figS6_pathways_top20.csv")
msg("
  figS6_nine_class_network.R done")
