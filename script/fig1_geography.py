# -*- coding: utf-8 -*-
'''fig1_geography.py — 图 1a-c：195 国九类、集中度与洲际分布（计算段）。

对应原脚本：scripts/07_country_classification.R + scripts/08_concentration_inequality.R
输入：share/data/fractional_weights.csv（分数计数权重）
      share/data/country_workbook_v4.xlsx（采样地明细）
      share/data/roster_195_v6.csv（195 国名册）
      share/data/nine_class_195.csv（九类划分，由图 1a 的分档规则得出）
输出：share/script/_derived/fig1_geography.csv
'''
import os, sys, importlib.util as iu
import pandas as pd, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '_derived'); os.makedirs(OUT, exist_ok=True)
spec = iu.spec_from_file_location('ld', os.path.join(HERE, '00_load.py'))
ld = iu.module_from_spec(spec); spec.loader.exec_module(ld)

d = ld.load_corpus()
nc = pd.read_csv(ld.dpath('nine_class_195.csv'))
ros = pd.read_csv(ld.dpath('roster_195_v6.csv'))
fr = pd.read_csv(ld.dpath('fractional_weights.csv'), low_memory=False)
fr['record_id'] = fr.record_id.astype(str)
fr = fr[fr.record_id.isin(set(d.record_id))]
ss = pd.read_excel(ld.dpath('country_workbook_v4.xlsx'), sheet_name='明细_采样地国家')[['record_id','ss_country']].dropna()
ss['record_id'] = ss.record_id.astype(str)
ss = ss[ss.record_id.isin(set(d.record_id))]

print('=== 九类分布 ===')
print(nc['class'].value_counts().to_string())
pub = fr.groupby(fr.country.map(ld.canon)).frac.sum()
smp = ss.groupby(ss.ss_country.map(ld.canon)).size()
ros['canon'] = ros['英文名'].map(ld.canon)
ros['pub'] = ros.canon.map(pub).fillna(0)
ros['smp'] = ros.canon.map(smp).fillna(0)
m = ros.merge(nc[['country','class']], left_on='英文名', right_on='country', how='left')
TOT_P, TOT_S = m['pub'].sum(), m['smp'].sum()
print()
print('=== 集中度 ===')
print('  发表 Gini = %.4f' % ld.gini(m['pub']))
print('  采样 Gini = %.4f' % ld.gini(m['smp']))
print('  Spearman rho = %.3f | Pearson r = %.3f' % (
    m[['pub','smp']].corr(method='spearman').iloc[0,1], m[['pub','smp']].corr().iloc[0,1]))
hh = m[m['class'] == 'HH']
print('  HH 国家 %d (%.2f%%) | 发表份额 %.2f%% | 采样份额 %.2f%%' % (
    len(hh), 100*len(hh)/len(m), 100*hh['pub'].sum()/TOT_P, 100*hh['smp'].sum()/TOT_S))
print('  双零国家 (LL 且 pub=smp=0): %d' % ((m['class']=='LL') & (m['pub']==0) & (m['smp']==0)).sum())
print()
print('=== 洲际分布（分数计数）===')
cont = {ld.canon(a): b for a, b in zip(ros['英文名'], ros['大洲'])}
fr2 = fr.assign(canon=fr.country.map(ld.canon)); fr2['cont'] = fr2.canon.map(cont)
for k, v in fr2.groupby('cont').frac.sum().sort_values(ascending=False).items():
    print('  %-6s %9.1f  %6.2f%%' % (k, v, 100*v/TOT_P))
print()
print('=== 前十大产出国 ===')
name = {ld.canon(a): b for a, b in zip(ros['英文名'], ros['中文名'])}
top = pub.sort_values(ascending=False).head(10)
for k, v in top.items(): print('  %-22s %8.0f' % (name.get(k, k), v))
m.to_csv(os.path.join(OUT, 'fig1_geography.csv'), index=False, encoding='utf-8')
print()
print('saved _derived/fig1_geography.csv')