# -*- coding: utf-8 -*-
'''plot_fig1a_growth.py — 图 1a/b 绘图段。需 matplotlib（C:\Python314\python.exe）。'''
import os, csv
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
HERE = os.path.dirname(os.path.abspath(__file__))
for f in [r'C:\Windows\Fonts\times.ttf', r'C:\Windows\Fonts\timesbd.ttf']:
    try: fm.fontManager.addfont(f)
    except Exception: pass
plt.rcParams['font.family'] = ['Times New Roman']
plt.rcParams['pdf.fonttype'] = 42
p = os.path.join(HERE, '_derived', 'fig1a_growth.csv')
rows = list(csv.DictReader(open(p, encoding='utf-8')))
xs = [int(r['year']) for r in rows]; ys = [int(r['articles']) for r in rows]
fig, ax = plt.subplots(figsize=(180/25.4, 70/25.4))
ax.plot(xs, ys, lw=1.0, color='#333333')
for b in (2000, 2009, 2017): ax.axvline(b, color='#BBBBBB', lw=0.6, ls='--')
ax.set_xlabel('Year', fontsize=8.5); ax.set_ylabel('Articles', fontsize=8.5)
ax.tick_params(labelsize=8.5)
for sp in ('top','right'): ax.spines[sp].set_visible(False)
fig.tight_layout()
fig.savefig(os.path.join(HERE, 'fig1a_growth.png'), dpi=600)
fig.savefig(os.path.join(HERE, 'fig1a_growth.pdf'))
print('saved fig1a_growth.{png,pdf}')