# =============================================================================
# tableS3_data_quality.R — Table S3: data-quality profile
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
msg("== tableS3_data_quality.R ==")
records <- load_corpus("records"); corpus <- load_corpus("analysed")
ss <- load_sampling(split = FALSE)
sf <- load_sampling_fragments()
cov <- function(x) round(100 * mean(!is.na(x) & nzchar(trimws(as.character(x)))), 1)
tab <- tibble(
  item = c("records in the merged corpus", "records in the analysed corpus",
           "records outside 1980-2025", "title present (%)", "publication year present (%)",
           "journal present (%)", "author list present (%)",
           "records with an extracted sampling location",
           "records without an extracted sampling location",
           "archive class unclassified (records)", "archive class unclassified (%)",
           "distinct unresolved sampling fragments"),
  value = c(nrow(records), nrow(corpus),
            sum(!(corpus$year %in% YEAR_MIN:YEAR_MAX), na.rm = TRUE),
            cov(records$title), cov(records$year), cov(records$journal), cov(records$authors),
            n_distinct(ss$record_id), nrow(corpus) - n_distinct(ss$record_id),
            sum(corpus$jev_archive_class == "Unclassified"),
            round(100 * mean(corpus$jev_archive_class == "Unclassified"), 2),
            if (is.null(sf)) NA_integer_ else nrow(sf)))
for (i in seq_len(nrow(tab))) msg("  %-52s %s", tab$item[i], tab$value[i])
write_derived(tab, "tableS3_data_quality.csv")
msg("  tableS3_data_quality.R done")