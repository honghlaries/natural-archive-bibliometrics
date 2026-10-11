# -*- coding: utf-8 -*-
'''fig3b_sdg_share.py — 图 3b：各 SDG 流量来自 high-high 国家的份额。

对应原脚本：scripts/162_fig4_panel_b.py（v3 对齐版）
输入：share/data/corpus_annotated.xlsx（国家档位由 share/data/sdg_by_country_tier.csv 提供）
输出：仅子图 (b)，不含拼图（面板 a 的桑基由 scripts/sankey/ 渲染）
'''
import os, sys, csv
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

HERE = os.path.dirname(os.path.abspath(__file__))
for f in [r'C:\Windows\Fonts\times.ttf', r'C:\Windows\Fonts\timesbd.ttf']:
    try: fm.fontManager.addfont(f)
    except Exception: pass
plt.rcParams['font.family'] = ['Times New Roman']
plt.rcParams['pdf.fonttype'] = 42
MM = 1/25.4

# 与桑基渲染器 scripts/sankey/_plot_sankey_map.py 完全一致的几何常量
W_MM, L_MARG, R_MARG = 190.0, 24.0, 24.0
XS0, XS4 = L_MARG, W_MM - R_MARG      # 24 -> 166 mm
BAR_MM = XS4 - XS0
FS = 8.5                              # 与桑基 FS 一致
XLIM = 116.0
H_SAN, H_PAN = 140.0, 140.0/1.618     # (a):(b) = 1:phi

# 数据目录解析：环境变量 > ./data > ../data
def _data_dir():
    for c in [os.environ.get('PAPER_DATA_DIR', ''), os.path.join(HERE, 'data'),
              os.path.join(os.path.dirname(HERE), 'data')]:
        if c and os.path.exists(os.path.join(c, 'sdg_by_country_tier.csv')): return c
    raise FileNotFoundError('sdg_by_country_tier.csv 未找到：请从 Zenodo 下载放入 data/')
src = os.path.join(_data_dir(), 'sdg_by_country_tier.csv')
rows = sorted([{'sdg': r['sdg'], 'flow': float(r['flow']), 'HH': float(r['HH_share_pct']),
                'nonHH': float(r['nonHH_share_pct'])} for r in csv.DictReader(open(src, encoding='utf-8-sig'))],
              key=lambda r: -r['flow'])
names = {'SDG 13':'13 Climate','SDG 15':'15 Land life','SDG 14':'14 Ocean life','SDG 6':'6 Clean water',
         'SDG 11':'11 Cities','SDG 9':'9 Industry','SDG 3':'3 Health','SDG 2':'2 Hunger',
         'SDG 12':'12 Consumption','SDG 7':'7 Energy','SDG 17':'17 Partnerships'}
HH_C, NH_C = '#6E2A5E', '#D8CDCB'

fig = plt.figure(figsize=(W_MM*MM, H_PAN*MM))
ax_w = (XLIM/100.0)*BAR_MM/W_MM
ax = fig.add_axes([XS0/W_MM, 0.085, ax_w, 0.885])
ax.set_xlim(0, XLIM)
n = len(rows)
for i, r in enumerate(rows):
    y = n - 1 - i
    ax.barh(y, r['HH'], height=0.66, color=HH_C, edgecolor='white', linewidth=0.5, zorder=3)
    ax.barh(y, r['nonHH'], left=r['HH'], height=0.66, color=NH_C, edgecolor='white', linewidth=0.5, zorder=3)
    ax.text(-1.4, y, names.get(r['sdg'], r['sdg']), ha='right', va='center', fontsize=FS, color='#111111')
    ax.text(101.6, y, '%.1f%%' % r['HH'], ha='left', va='center', fontsize=FS, color=HH_C)
    ax.text(114.0, y, '%.0f' % r['flow'], ha='right', va='center', fontsize=FS, color='#555555')
ax.set_ylim(-0.75, n - 0.25); ax.axis('off')
ax.text(0, n + 0.30, 'Share of each goal flow originating in high-high countries', ha='left', va='bottom', fontsize=FS)
ax.text(114.0, n + 0.30, 'flow', ha='right', va='bottom', fontsize=FS, color='#555555')
fig.savefig(os.path.join(HERE, 'fig3b_sdg_share.png'), dpi=600)
fig.savefig(os.path.join(HERE, 'fig3b_sdg_share.pdf'))
print('saved fig3b_sdg_share.{png,pdf} | 条形 0-100%% -> %.0f-%.0f mm | (a):(b)=1:phi' % (XS0, XS4))