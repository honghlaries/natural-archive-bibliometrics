# =============================================================================
# fig3_network.R — Figure 3a: five-layer knowledge network on the 29,379-record
#                  network subset, with countries split at 41,458 PPP int$.
#
# Layers: Country type (Above/Below 41,458 PPP) -> Archive class -> Indicator
#         class -> Scientific question -> SDG.
# Each record contributes a total weight of one per layer; multi-label fields
# are split 1/n. Country type is a single label per record (network_subset.csv).
#
# Outputs: fig3a_layers.csv, fig3a_links.csv, fig3a_pathways_top20.csv,
#          fig3a_metrics.csv, fig3a_sankey.json (consumed by the Python renderer)
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

msg("== fig3_network.R ==")
corpus <- load_corpus("analysed")
ns <- load_network_subset()
if (is.null(ns)) stop("network_subset.csv is required for Figure 3a", call. = FALSE)
KEEP <- ns$record_id
cty <- ns %>% transmute(record_id, ctype)
msg("  network subset: %d records (%.1f%% of the analysed corpus)", nrow(ns),
    100 * nrow(ns) / nrow(corpus))

LNAMES <- c("Country type", "Archive", "Indicator", "Question", "SDGs")
corp <- corpus %>% filter(record_id %in% KEEP)

layer_long <- function(col, layer, split = TRUE) {
  x <- corp %>% select(record_id, v = all_of(col)) %>%
    mutate(v = as.character(v)) %>% filter(!is.na(v), nzchar(v))
  if (split) x <- x %>% separate_rows(v, sep = ";") %>% mutate(v = trimws(v))
  x <- x %>% filter(nzchar(v), v != "NA")
  if (split) x <- x %>% group_by(record_id) %>% mutate(w = 1 / n()) %>% ungroup()
  else x <- x %>% mutate(w = 1)
  x %>% transmute(record_id, layer = layer, node = v, w)
}
lay <- bind_rows(
  cty %>% transmute(record_id, layer = "Country type", node = ctype, w = 1),
  layer_long("jev_archive_class", "Archive"),
  layer_long("jev_indicator_class", "Indicator"),
  layer_long("jev_axis_a", "Question"),
  layer_long("jev_sdGoals", "SDGs") %>%
    mutate(node = paste0("SDG ", sub("[.].*", "", node)))
) %>% mutate(layer = factor(layer, levels = LNAMES))

layers <- lay %>% group_by(layer, node) %>%
  summarise(flow = sum(w), .groups = "drop") %>%
  group_by(layer) %>% mutate(share_pct = round(100 * flow / sum(flow), 2)) %>%
  ungroup() %>% mutate(layer = as.character(layer), node = as.character(node))
tot_flow <- layers %>% group_by(layer) %>% summarise(total = sum(flow), .groups = "drop")
msg("\n  layer totals:")
for (i in seq_len(nrow(tot_flow))) msg("    %-14s %.1f", tot_flow$layer[i], tot_flow$total[i])

msg("\n  archive composition in the network (%%):")
acro <- layers %>% filter(layer == "Archive") %>% arrange(desc(flow))
for (i in seq_len(nrow(acro))) msg("    %-22s %6.2f%%  (%.1f)", acro$node[i], acro$share_pct[i], acro$flow[i])
msg("\n  indicator composition (%%):")
indi <- layers %>% filter(layer == "Indicator") %>% arrange(desc(flow))
for (i in seq_len(nrow(indi))) msg("    %-22s %6.2f%%", indi$node[i], indi$share_pct[i])
msg("\n  SDG composition (%%):")
sdg <- layers %>% filter(layer == "SDGs") %>% arrange(desc(flow))
for (i in head(seq_len(nrow(sdg)), 6)) msg("    %-8s %6.2f%%", sdg$node[i], sdg$share_pct[i])
msg("    top-4 SDGs: %.2f%%", sum(head(sdg$share_pct, 4)))

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

# full five-dimensional pathways: expand the label combination of each record,
# weight every combination by the product of its layer weights, then normalise
# each record's combinations to a total weight of one.
pw <- lay %>% filter(layer == LNAMES[1]) %>%
  select(record_id, !!LNAMES[1] := node, w = w)
for (L in LNAMES[-1]) {
  x <- lay %>% filter(layer == L) %>% select(record_id, node, w2 = w)
  pw <- pw %>% inner_join(x, by = "record_id", relationship = "many-to-many") %>%
    mutate(w = w * w2) %>% select(-w2) %>% rename(!!L := node)
}
pw <- pw %>% group_by(record_id) %>% mutate(w = w / sum(w)) %>% ungroup()
pathways <- pw %>% group_by(across(all_of(LNAMES))) %>%
  summarise(flow = sum(w), .groups = "drop") %>% arrange(desc(flow))

met <- tibble(
  metric = c("network records", "share of analysed corpus (%)", "five-dimensional pathways",
             "top-20 pathways from Above-threshold countries", "total flow"),
  value = c(nrow(ns), round(100 * nrow(ns) / nrow(corpus), 1), nrow(pathways),
            sum(grepl("^Above", pathways[["Country type"]][1:20])), round(sum(pathways$flow), 1)))
for (i in seq_len(nrow(met))) msg("  %-50s %s", met$metric[i], met$value[i])

# ---- merge nodes below 1% into "Other" (except the country-type layer) -------
node_share <- layers %>% group_by(layer) %>% mutate(share = flow / sum(flow)) %>% ungroup()
small <- node_share %>% filter(share < 0.01, layer != "Country type")
lay_m <- lay
if (nrow(small)) {
  key <- small %>% select(layer, node)
  lay_m <- bind_rows(
    lay %>% anti_join(key, by = c("layer", "node")),
    lay %>% semi_join(key, by = c("layer", "node")) %>% mutate(node = "Other"))
}
links_m <- list()
for (j in seq_len(length(LNAMES) - 1)) {
  l1 <- LNAMES[j]; l2 <- LNAMES[j + 1]
  a1 <- lay_m %>% filter(layer == l1) %>% select(record_id, n1 = node, w1 = w)
  a2 <- lay_m %>% filter(layer == l2) %>% select(record_id, n2 = node, w2 = w)
  jj <- inner_join(a1, a2, by = "record_id", relationship = "many-to-many") %>% mutate(w = w1 * w2)
  links_m[[j]] <- jj %>% group_by(n1, n2) %>% summarise(flow = sum(w), .groups = "drop") %>%
    transmute(layer = j - 1L, source = n1, target = n2, flow)
}
links_m <- bind_rows(links_m)
orders <- lapply(LNAMES, function(L) {
  d <- lay_m %>% filter(layer == L) %>% group_by(node) %>% summarise(flow = sum(w), .groups = "drop")
  if (L == "Country type") d <- d %>% arrange(desc(grepl("^Above", node))) else d <- d %>% arrange(desc(flow))
  d$node
})
nodes_list <- lapply(seq_along(LNAMES), function(i) {
  d <- lay_m %>% filter(layer == LNAMES[i]) %>% group_by(node) %>% summarise(flow = sum(w), .groups = "drop")
  list(order = orders[[i]], flow = as.list(setNames(round(d$flow, 2), d$node)))
})
JJ <- list(layers = LNAMES, nodes = nodes_list, links = links_m,
           threshold_ppp = PPP_BREAK,
           labels = list(above = "Above 41,458 PPP", below = "Below 41,458 PPP"))
jsonlite::write_json(JJ, file.path(DERIVED, "fig3a_sankey.json"), auto_unbox = TRUE,
                     pretty = TRUE, digits = 4)

write_derived(layers, "fig3a_layers.csv")
write_derived(links, "fig3a_links.csv")
write_derived(head(pathways, 20), "fig3a_pathways_top20.csv")
write_derived(met, "fig3a_metrics.csv")
msg("\n  fig3_network.R done (Sankey JSON: _derived/fig3a_sankey.json)")
