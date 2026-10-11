# =============================================================================
# _core.R — 记录级长表装配（口径与 scripts/34_archive_stratified_inequality.R 一致）
# 被 fig1_wedge.R 与 main_tests.R source()
# =============================================================================
suppressPackageStartupMessages(library(stringr))

corpus <- load_corpus()
samp <- load_sampling() %>% transmute(record_id, canon) %>% distinct()
frac <- load_fractional() %>% transmute(record_id, canon, frac) %>%
  filter(!is.na(frac), nzchar(canon))
roster <- load_roster()

# ---- 记录级长表（口径与 scripts/34_archive_stratified_inequality.R 一致）----
# ① archive_mid 多标签按 1/n 分摊，得到 (record, archive_mid, w)
mid_w <- corpus %>%
  select(record_id, mid = jev_archive_mid) %>%
  mutate(mid = as.character(mid)) %>%
  separate_rows(mid, sep = ';') %>%
  mutate(mid = trimws(mid)) %>%
  filter(nzchar(mid), mid != 'NA') %>%
  group_by(record_id) %>% mutate(w = 1 / n()) %>% ungroup() %>%
  transmute(record_id, archive_mid = mid, w)

rec <- corpus %>% transmute(record_id, year) %>%
  inner_join(mid_w, by = 'record_id', relationship = 'many-to-many')

# ② 采样侧：每条记录展开到其采样国（保留 w）
rec_ss <- rec %>% inner_join(samp, by = 'record_id', relationship = 'many-to-many') %>%
  transmute(record_id, archive_mid, w, canon)

# ③ 发表侧：用分数计数，权重 = w * frac
rec_fr <- rec %>% inner_join(frac, by = 'record_id', relationship = 'many-to-many') %>%
  transmute(record_id, archive_mid, w = w * frac, canon)

# ④ Gini 的国名宇宙：仅 195 国名册（与权威脚本一致）
roster_canon <- roster$canon

gof <- function(d, tp) {
  v <- d %>% filter(archive_mid == tp) %>% group_by(canon) %>% summarise(v = sum(w), .groups = 'drop')
  x <- setNames(rep(0, length(roster_canon)), roster_canon); x[v$canon] <- v$v
  gini(as.numeric(x))
}