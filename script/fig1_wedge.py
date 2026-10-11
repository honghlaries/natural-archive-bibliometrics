# -*- coding: utf-8 -*-
'''fig1_wedge.py — 图 1d,e：各档案类型的采样-发表楔子（计算段）。

对应原脚本：scripts/34_archive_stratified_inequality.R（t38_archive_wedge_by_type.csv）
输入：share/data 下的 corpus_annotated.xlsx、country_workbook_v4.xlsx、fractional_weights.csv、roster_195_v6.csv
输出：script/_derived/fig1_wedge.csv

口径：国名向量按 R 的命名向量语义构造 —— 未在名册中的实体（Antarctica 等）追加到末尾，
      因此非主权采样地也进入 Gini 与份额的分母。见 00_load.py: country_vector()。
'''
import os, sys, importlib.util as iu
import pandas as pd, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '_derived'); os.makedirs(OUT, exist_ok=True)
spec = iu.spec_from_file_location('ld', os.path.join(HERE, '00_load.py'))
ld = iu.module_from_spec(spec); spec.loader.exec_module(ld)

d = ld.load_corpus()
ros = pd.read_csv(ld.dpath('roster_195_v6.csv'))
ros['canon'] = ros['英文名'].map(ld.canon)
roster_canon = list(ros['canon'])

ss = pd.read_excel(ld.dpath('country_workbook_v4.xlsx'), sheet_name='明细_采样地国家')[['record_id','ss_country']].dropna()
ss['record_id'] = ss.record_id.astype(str); ss = ss[ss.record_id.isin(set(d.record_id))]
ss['canon'] = ss.ss_country.astype(str).map(ld.canon)
fr = pd.read_csv(ld.dpath('fractional_weights.csv'), low_memory=False)
fr['record_id'] = fr.record_id.astype(str); fr = fr[fr.record_id.isin(set(d.record_id))]
fr['canon'] = fr.country.map(ld.canon)

# R 的向量扩展语义：名册在前，非名册实体按字母序追加
UNIV = ld.align_universe(pd.concat([ss.canon, fr.canon]), roster_canon)
print('国名宇宙: %d（名册 %d + 非名册 %d）' % (len(UNIV), len(set(roster_canon)), len(UNIV) - len(set(roster_canon))))
print()

vc = d.jev_archive_mid.value_counts()
KEEP = [k for k, v in vc.items() if v >= 100 and k != 'Unclassified']
rows = []
for tp in KEEP:
    ids = set(d[d.jev_archive_mid == tp].record_id)
    s = ss[ss.record_id.isin(ids)].groupby('canon').size()
    p = fr[fr.record_id.isin(ids)].groupby('canon').frac.sum()
    xs = pd.Series(ld.country_vector(s.to_dict(), UNIV), index=UNIV)
    xp = pd.Series(ld.country_vector(p.to_dict(), UNIV), index=UNIV)
    diff = (xs / xs.sum()) - (xp / xp.sum())
    rows.append({'archive_mid': tp, 'n_records': len(ids),
                 'n_countries_sampling': int((xs > 0).sum()),
                 'median_share_diff': round(float(diff.median()), 4),
                 'gini_sampling': round(ld.gini(xs.values), 4),
                 'gini_publication': round(ld.gini(xp.values), 4)})
out = pd.DataFrame(rows).sort_values('median_share_diff', ascending=False)
print(out.to_string(index=False))
print()
print('  采样集中度范围: %.4f - %.4f' % (out.gini_sampling.min(), out.gini_sampling.max()))
print('  采样国数范围  : %d - %d' % (out.n_countries_sampling.min(), out.n_countries_sampling.max()))
out.to_csv(os.path.join(OUT, 'fig1_wedge.csv'), index=False, encoding='utf-8')
print('saved _derived/fig1_wedge.csv')