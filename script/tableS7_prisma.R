# =============================================================================
# tableS7_prisma.R — Table S7: PRISMA flow of records
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
msg("== tableS7_prisma.R ==")
records <- load_corpus("records"); corpus <- load_corpus("analysed")
# Retrieval counts are fixed in the PRISMA ledger; the merged archive only
# distributes post-deduplication records, so the pre-dedup counts are kept as
# constants exactly as reported in the SI (Table S7 / Figure S8).
N_WOS1 <- 11174; N_WOS2 <- 42063; N_OA <- 27014
N_ID <- N_WOS1 + N_WOS2 + N_OA
N_DEDUP <- nrow(records); N_INCL <- nrow(corpus)
stopifnot(N_DEDUP == 49189)
tab <- tibble(
  stage = c("Records identified from Web of Science Core Collection, original search",
            "Records identified from Web of Science Core Collection, expanded search",
            "Records identified from OpenAlex",
            "Records identified (total)", "Records removed before screening (duplicates)",
            "Records after de-duplication", "Records screened at title and abstract",
            "Records excluded at screening (not natural-archive research)",
            "Records included in the bibliometric analysis"),
  records_n = c(N_WOS1, N_WOS2, N_OA, N_ID, N_ID - N_DEDUP, N_DEDUP, N_DEDUP,
                N_DEDUP - N_INCL, N_INCL))
for (i in seq_len(nrow(tab))) msg("  %-70s %6d", tab$stage[i], tab$records_n[i])
write_derived(tab, "tableS7_prisma.csv")
msg("  tableS7_prisma.R done")