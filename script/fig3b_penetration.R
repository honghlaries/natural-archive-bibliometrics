# =============================================================================
# fig3b_penetration.R — Figure 3b: how far capacity penetrates each layer
#
# For every layer of the five-layer network the records are split by the
# country-type layer (Above/Below 41,458 PPP). Two measures per layer:
#   TVD = total variation distance between the two distributions (0 = identical)
#   PI  = log2(share_above / share_below) per node (penetration index)
#
# Outputs: fig3b_layer_shares.csv, fig3b_tvd.csv, fig3b_penetration_index.csv
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

msg("== fig3b_penetration.R ==")
corpus <- load_corpus("analysed")
ns <- load_network_subset()
KEEP <- ns$record_id
corp <- corpus %>% filter(record_id %in% KEEP)
LNAMES <- c("Country type", "Archive", "Indicator", "Question", "SDGs")

layer_long <- function(col, layer) {
  x <- corp %>% select(record_id, v = all_of(col)) %>% mutate(v = as.character(v)) %>%
    filter(!is.na(v), nzchar(v)) %>% separate_rows(v, sep = ";") %>%
    mutate(v = trimws(v)) %>% filter(nzchar(v), v != "NA") %>%
    group_by(record_id) %>% mutate(w = 1 / n()) %>% ungroup()
  x %>% transmute(record_id, layer = layer, node = v, w)
}
lay <- bind_rows(
  ns %>% transmute(record_id, layer = "Country type", node = ctype, w = 1),
  layer_long("jev_archive_class", "Archive"),
  layer_long("jev_indicator_class", "Indicator"),
  layer_long("jev_axis_a", "Question"),
  layer_long("jev_sdGoals", "SDGs") %>% mutate(node = paste0("SDG ", sub("[.].*", "", node)))
)
ctype <- ns %>% select(record_id, ctype)
sh <- lay %>% filter(layer != "Country type") %>%
  inner_join(ctype, by = "record_id") %>%
  group_by(layer, node, ctype) %>% summarise(flow = sum(w), .groups = "drop") %>%
  group_by(layer, ctype) %>% mutate(share = flow / sum(flow)) %>% ungroup()

tvd <- sh %>% select(layer, node, ctype, share) %>%
  pivot_wider(names_from = ctype, values_from = share, values_fill = 0) %>%
  group_by(layer) %>% summarise(TVD = round(0.5 * sum(abs(.data[["Above 41,458 PPP"]] -
                                                        .data[["Below 41,458 PPP"]])), 4),
                                n_nodes = n(), .groups = "drop")
pi <- sh %>% select(layer, node, ctype, share) %>%
  pivot_wider(names_from = ctype, values_from = share, values_fill = 0) %>%
  mutate(PI = round(log2((.data[["Above 41,458 PPP"]] + 1e-9) /
                           (.data[["Below 41,458 PPP"]] + 1e-9)), 3),
         gap_pp = round(100 * (.data[["Above 41,458 PPP"]] - .data[["Below 41,458 PPP"]]), 2)) %>%
  arrange(layer, desc(abs(PI)))
msg("
  total variation distance by layer (0 = identical distributions):")
for (i in seq_len(nrow(tvd))) msg("    %-12s %.4f", tvd$layer[i], tvd$TVD[i])
msg("
  largest penetration indices:")
top <- pi %>% arrange(desc(abs(PI))) %>% slice_head(n = 12)
for (i in seq_len(nrow(top)))
  msg("    %-10s %-28s PI %+6.2f  gap %+6.2f pp", top$layer[i], top$node[i], top$PI[i], top$gap_pp[i])
write_derived(sh, "fig3b_layer_shares.csv")
write_derived(tvd, "fig3b_tvd.csv")
write_derived(pi, "fig3b_penetration_index.csv")
msg("
  fig3b_penetration.R done")
