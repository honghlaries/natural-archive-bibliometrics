# =============================================================================
# 00_load.R — 共享数据加载层（所有复现脚本的公共入口）
#
# 口径与原分析库 scripts/R/io.R 完全一致：
#   canon_country()  <-> io.R: canon_country()
#   gini()           <-> scripts/08_concentration_inequality.R: gini()
#   hhi()            <-> scripts/08_concentration_inequality.R: hhi()
#
# 数据位置解析顺序：环境变量 PAPER_DATA_DIR > ./data > ../data > 脚本同级
# 数据请从 Zenodo 下载（DOI: 10.5281/zenodo.23294431）
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(readxl); library(jsonlite)
})

# ---- 定位脚本目录与数据目录 -------------------------------------------------
.args <- commandArgs(trailingOnly = FALSE)
.file <- grep('^--file=', .args, value = TRUE)
HERE  <- if (length(.file)) dirname(normalizePath(sub('^--file=', '', .file[1]))) else getwd()
REPO  <- dirname(HERE)

.data_dir <- function() {
  cand <- c(Sys.getenv('PAPER_DATA_DIR', ''),
            file.path(REPO, 'data'),
            file.path(dirname(REPO), 'data'),
            HERE)
  cand <- cand[nzchar(cand)]
  hit  <- cand[file.exists(file.path(cand, 'corpus_annotated.xlsx'))]
  if (!length(hit)) {
    stop(paste0('corpus_annotated.xlsx not found. ',
                'Download the dataset from Zenodo (DOI 10.5281/zenodo.23294431) ',
                'into data/, or set PAPER_DATA_DIR.'), call. = FALSE)
  }
  hit[1]
}
DATA <- .data_dir()
dpath <- function(f) file.path(DATA, f)

# ---- 口径常量 ---------------------------------------------------------------
ROSTER_N   <- 195L
YEAR_MIN   <- 1980L
YEAR_MAX   <- 2025L
CLASS_LEVELS <- c('HH','HM','HL','MH','MM','ML','LH','LM','LL')

# ---- 国名归一（与 io.R 逐行一致）--------------------------------------------
CFG_ALIASES <- fromJSON(dpath('config_aliases.json'), simplifyVector = TRUE)

canon_country <- function(x) {
  al <- unlist(CFG_ALIASES)
  x  <- trimws(as.character(x))
  hit <- al[x]; x[!is.na(hit)] <- hit[!is.na(hit)]
  x <- iconv(x, from = 'UTF-8', to = 'ASCII//TRANSLIT'); x[is.na(x)] <- ''
  toupper(gsub('[^A-Za-z]', '', x))
}

# ---- 集中度指数（与 08 逐行一致）--------------------------------------------
gini <- function(x) {
  x <- sort(x[x >= 0]); n <- length(x)
  if (n < 2 || sum(x) == 0) return(NA_real_)
  (2 * sum(seq_len(n) * x) / (n * sum(x))) - (n + 1) / n
}
hhi <- function(x) { p <- x / sum(x); sum(p^2) * 10000 }

# ---- 读取 -------------------------------------------------------------------
load_corpus <- function() {
  df <- read_excel(dpath('corpus_annotated.xlsx'), sheet = 'analysed_corpus')
  df %>% mutate(record_id = as.character(record_id),
                year = suppressWarnings(as.integer(year)))
}

load_sampling <- function() {
  read_excel(dpath('country_workbook_v4.xlsx'), sheet = '明细_采样地国家') %>%
    select(record_id, ss_country) %>% filter(!is.na(ss_country)) %>%
    mutate(record_id = as.character(record_id), canon = canon_country(ss_country))
}

load_fractional <- function() {
  read_csv(dpath('fractional_weights.csv'), show_col_types = FALSE) %>%
    mutate(record_id = as.character(record_id), canon = canon_country(country))
}

load_roster <- function() {
  read_csv(dpath('roster_195_v6.csv'), show_col_types = FALSE) %>%
    mutate(canon = canon_country(英文名))
}

load_classes <- function() read_csv(dpath('nine_class_195.csv'), show_col_types = FALSE)

# 按 R 的命名向量语义构造国名宇宙：名册在前，非名册实体按字母序追加
align_universe <- function(country_vec, roster) {
  present <- unique(canon_country(country_vec))
  extra   <- sort(setdiff(present[!is.na(present) & nzchar(present)], roster))
  c(roster, extra)
}

if (sys.nframe() == 0) {
  cat('Data dir :', DATA, '\n')
  d <- load_corpus()
  cat(sprintf('Corpus   : %d records x %d columns\n', nrow(d), ncol(d)))
  cat(sprintf('Years    : %d-%d\n', min(d$year, na.rm = TRUE), max(d$year, na.rm = TRUE)))
  print(count(d, source))
}