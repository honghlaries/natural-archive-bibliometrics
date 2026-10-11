# -*- coding: utf-8 -*-
'''00_load.py — 共享数据加载层（所有复现脚本的统一入口）。

用法：
    from 00_load import load_corpus   # 或按下文的 importlib 方式

数据位置解析顺序：
    1. 环境变量 PAPER_DATA_DIR
    2. 仓库内 ./data/
    3. 仓库上一级 ../data/
    4. 脚本同级 ./
数据请从 Zenodo 下载后放入 data/，或设置 PAPER_DATA_DIR 指向解压目录。

口径与论文原分析库一致：
    canon()  <-> scripts/R/io.R: canon_country()
    gini()   <-> scripts/R/io.R 与 34_archive_stratified_inequality.R
'''
import os, sys, json, re, unicodedata
import pandas as pd, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

def _data_dir():
    cands = []
    if os.environ.get('PAPER_DATA_DIR'):
        cands.append(os.environ['PAPER_DATA_DIR'])
    cands += [os.path.join(REPO, 'data'),
              os.path.join(os.path.dirname(REPO), 'data'),
              os.path.join(HERE, 'data'),
              HERE]
    for c in cands:
        if os.path.exists(os.path.join(c, 'corpus_annotated.xlsx')): return c
    raise FileNotFoundError(
        'corpus_annotated.xlsx 未找到。请从 Zenodo 下载数据集并放入 data/，'
        '或设置环境变量 PAPER_DATA_DIR 指向解压目录。')

DATA = _data_dir()

def dpath(name):
    '''取数据文件路径。'''
    return os.path.join(DATA, name)

# 国名别名表（与论文原库 scripts/config.json 的 country_aliases 一致）
with open(dpath('config_aliases.json'), encoding='utf-8') as f:
    ALIASES = json.load(f)

def canon(s):
    '''国名归一：别名 -> 去变音符号 -> 仅保留字母并大写。
    与 scripts/R/io.R: canon_country() 完全一致。'''
    s = str(s).strip()
    if s in ALIASES: s = ALIASES[s]
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub('[^A-Za-z]', '', s).upper()

def load_corpus():
    '''读入分析语料（33,145 条），返回 DataFrame。'''
    df = pd.read_excel(dpath('corpus_annotated.xlsx'), sheet_name='analysed_corpus')
    df['record_id'] = df.record_id.astype(str)
    df['year'] = pd.to_numeric(df.year, errors='coerce')
    return df

def gini(x):
    '''Gini 系数。与 scripts/R/io.R 及 34_archive_stratified_inequality.R 同一公式。'''
    x = np.sort(np.asarray(x, float)); n = len(x)
    if n < 2 or x.sum() == 0: return np.nan
    return float((2 * np.sum(np.arange(1, n + 1) * x) / (n * x.sum())) - (n + 1) / n)

def country_vector(pairs, universe):
    '''按 R 的命名向量语义构造：未在 universe 中的名字追加到末尾。'''
    x = pd.Series(0.0, index=list(universe))
    extra = [k for k in pairs if k not in x.index]
    if extra:
        x = pd.concat([x, pd.Series(0.0, index=sorted(extra))])
    for k, v in pairs.items(): x[k] = v
    return x.values

def align_universe(country_series, roster):
    '''按 R 的命名向量语义构造国名宇宙：名册在前，非名册实体按字母序追加。
    与 34_archive_stratified_inequality.R 中 setNames(...) + x[v$canon] <- v$v 的行为一致。'''
    present = set(pd.Series(country_series).dropna().map(canon))
    extra = sorted(present - set(roster))
    return list(roster) + [e for e in extra if e]

def load_table(name):
    '''通用读取：按扩展名分派。'''
    p = dpath(name)
    if name.endswith('.csv'): return pd.read_csv(p, low_memory=False)
    if name.endswith('.xlsx'): return pd.read_excel(p)
    if name.endswith('.json'): return json.load(open(p, encoding='utf-8'))
    raise ValueError('未知格式: ' + name)

if __name__ == '__main__':
    print('数据目录:', DATA)
    d = load_corpus()
    print('语料 %d 条 x %d 列' % d.shape)
    print('年份 %d-%d' % (d.year.min(), d.year.max()))
    print('来源:'); print(d.source.value_counts().to_string())