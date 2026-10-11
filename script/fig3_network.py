# -*- coding: utf-8 -*-
'''fig3_network.py — 图 3a：五层知识网络的流量与 SDG 归属（计算段）。

对应原脚本：scripts/11_sankey_network.R + scripts/sankey/_plot_sankey_map.py
输入：share/data/corpus_annotated.xlsx（JEV 各层标签）
输出：share/script/_derived/fig3_layers.csv（各层节点流量）

口径：桑基按记录加权，每条记录在每层的权重合计为 1（多标签按 1/n 分摊），
      因此各层节点流量之和等于语料记录数。这与 scripts/sankey/ 的渲染口径一致。
'''
import os, sys, importlib.util as iu
import pandas as pd, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '_derived'); os.makedirs(OUT, exist_ok=True)
spec = iu.spec_from_file_location('ld', os.path.join(HERE, '00_load.py'))
ld = iu.module_from_spec(spec); spec.loader.exec_module(ld)

d = ld.load_corpus()
n = len(d)
print('语料 %d 条；网络总流量 = %d' % (n, n))
print()
LAYERS = [('archive', 'jev_archive_class'), ('archive_mid', 'jev_archive_mid'),
          ('indicator', 'jev_indicator_class'), ('question', 'jev_axis_a'), ('sdg', 'jev_sdGoals')]
rows = []
for name, col in LAYERS:
    flow = {}
    for val in d[col].astype(str):
        parts = [x.strip() for x in val.split(';') if x.strip() and x.strip() != 'nan']
        if not parts: continue
        w = 1.0 / len(parts)
        for p in parts: flow[p] = flow.get(p, 0.0) + w
    for k, v in sorted(flow.items(), key=lambda z: -z[1]):
        rows.append({'layer': name, 'node': k, 'flow': round(v, 2), 'share_pct': round(100*v/n, 2)})
out = pd.DataFrame(rows)
print('=== 各层节点流量（前 5）===')
for lay in out.layer.unique():
    print('  [%s]  层流量合计 %.1f' % (lay, out[out.layer == lay].flow.sum()))
    for _, r in out[out.layer == lay].head(5).iterrows():
        print('    %-32s %8.1f  %5.2f%%' % (str(r['node'])[:32], r['flow'], r['share_pct']))
print()
print('=== SDG 目标合计（前 4）===')
sd = out[out.layer == 'sdg'].copy()
sd['g'] = sd.node.str.extract(r'(\d+)').astype(float)
agg = sd.groupby('g').flow.sum().sort_values(ascending=False).head(4)
for g, v in agg.items(): print('  SDG %-3d %8.1f  %5.2f%%' % (int(g), v, 100*v/n))
print('  前四合计 %.2f%%' % (100*agg.sum()/n))
out.to_csv(os.path.join(OUT, 'fig3_layers.csv'), index=False, encoding='utf-8')
print()
print('saved _derived/fig3_layers.csv')