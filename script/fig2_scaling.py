# -*- coding: utf-8 -*-
'''fig2_scaling.py — 图 2：收入分组、残差、标度与弹性阶跃（计算段）。

对应原脚本：scripts/10_income_groups.R、29_scaling_ppp.R、31_elasticity_threshold.R、32_residual_diagnosis.R
输入：share/data/fractional_weights.csv + 收入分组 + 人均 GDP（PPP 2021 不变价）
输出：share/script/_derived/fig2_*.csv
'''
import os, sys, importlib.util as iu
import pandas as pd, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '_derived'); os.makedirs(OUT, exist_ok=True)
spec = iu.spec_from_file_location('ld', os.path.join(HERE, '00_load.py'))
ld = iu.module_from_spec(spec); spec.loader.exec_module(ld)

d = ld.load_corpus()
fr = pd.read_csv(ld.dpath('fractional_weights.csv'), low_memory=False)
fr['record_id'] = fr.record_id.astype(str); fr = fr[fr.record_id.isin(set(d.record_id))]
fr['canon'] = fr.country.map(ld.canon)
pub = fr.groupby('canon').frac.sum()
print('=== 发表份额（分数计数）===')
print('  国家数 %d | 合计 %.0f' % (pub.size, pub.sum()))
print('  前 5: %s' % pub.sort_values(ascending=False).head(5).round(0).to_dict())
print()
print('注：收入分组、PPP 人均 GDP 与弹性阶跃需要额外输入表（income_groups / GDP panel）。')
print('    这些表由 scripts/10_income_groups.R 与 scripts/29_scaling_ppp.R 生成，')
print('    本脚本给出分数计数侧的入口；完整复现请运行上述 R 脚本。')
pub.to_frame('fractional_publications').to_csv(os.path.join(OUT, 'fig2_publications_by_country.csv'), encoding='utf-8')
print('saved _derived/fig2_publications_by_country.csv')