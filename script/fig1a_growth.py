# -*- coding: utf-8 -*-
'''fig1a_growth.py — 图 1a/b：年度产出与四个发展期（计算段）。

对应原脚本：scripts/02_stage_detection.R（分段）+ scripts/13_figures_main.R（绘图）
输入：share/data/corpus_annotated.xlsx（sheet=analysed_corpus）
输出：share/script/_derived/fig1a_growth.csv（绘图见 plot_fig1a_growth.py）

环境：本段只需 pandas（捆绑 Python 3.12）；绘图需 matplotlib（C:\Python314）。
'''
import os, sys, importlib.util as iu
import pandas as pd, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '_derived'); os.makedirs(OUT, exist_ok=True)
spec = iu.spec_from_file_location('ld', os.path.join(HERE, '00_load.py'))
ld = iu.module_from_spec(spec); spec.loader.exec_module(ld)

d = ld.load_corpus()
ys = d[(d.year >= 1980) & (d.year <= 2025)].groupby('year').size().reindex(range(1980, 2026), fill_value=0)
BREAKS = [2000, 2009, 2017]
PERIODS = [(1980,1999),(2000,2008),(2009,2016),(2017,2025)]
print('四期: ' + ' | '.join('%d-%d=%d' % (a,b,int(((d.year>=a)&(d.year<=b)).sum())) for a,b in PERIODS))
print('1980=%d  2025=%d  2021-2025 均值=%.1f' % (ys[1980], ys[2025], ys.loc[2021:2025].mean()))
print('窗口外(2026/2027)=%d' % int(((d.year>2025)).sum()))
ys.rename('articles').to_frame().to_csv(os.path.join(OUT, 'fig1a_growth.csv'), encoding='utf-8')
pd.Series({'breaks': ';'.join(map(str, BREAKS))}).to_csv(os.path.join(OUT, 'fig1a_breaks.csv'), encoding='utf-8')
print('saved _derived/fig1a_growth.csv')