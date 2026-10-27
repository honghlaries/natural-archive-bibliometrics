# -*- coding: utf-8 -*-
"""plot_fig3a_sankey.py — render Figure 3a from the R-computed Sankey data.

This is the only Python step in the reproduction package. All analysis and
data preparation is done in R (fig3_network.R); this script only draws the
five-layer flow diagram.

Input : script/_derived/fig3a_sankey.json   (written by fig3_network.R)
Output: script/_derived/fig3a_sankey.png and .pdf

Usage:
    python plot_fig3a_sankey.py [--data PATH] [--outdir PATH]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.path import Path
from matplotlib.patches import PathPatch

PALETTE = ["#2E5A88", "#C4503F", "#3F7E44", "#7FA0DC", "#B8860B", "#6E2A5E",
           "#8C8C8C", "#4E9A9A", "#A0522D", "#556B2F"]


def load_data(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def node_positions(spec):
    """Return {layer_index: {node: (y0, y1)}} laid out top-to-bottom by order."""
    pos = {}
    for li, layer in enumerate(spec["nodes"]):
        order = layer["order"]
        flow = layer["flow"]
        vals = np.array([float(flow.get(n, 0.0)) for n in order])
        total = vals.sum() if vals.sum() > 0 else 1.0
        gap = 0.012
        usable = 1.0 - gap * (len(order) - 1)
        heights = vals / total * usable
        top = 1.0
        d = {}
        for name, h in zip(order, heights):
            d[name] = (top - h, top)
            top -= h + gap
        pos[li] = d
    return pos


def ribbon(ax, x0, x1, y0a, y0b, y1a, y1b, color, alpha=0.55):
    n = 40
    t = np.linspace(0, 1, n)
    xs = x0 + (x1 - x0) * t
    ease = t * t * (3 - 2 * t)
    lower = y0a + (y1a - y0a) * ease
    upper = y0b + (y1b - y0b) * ease
    verts = np.vstack([
        np.column_stack([xs, upper]),
        np.column_stack([xs[::-1], lower[::-1]]),
    ])
    verts = np.vstack([verts, verts[0]])
    codes = [Path.MOVETO] + [Path.LINETO] * (len(verts) - 2) + [Path.CLOSEPOLY]
    ax.add_patch(PathPatch(Path(verts, codes), facecolor=color, edgecolor="none",
                           alpha=alpha, zorder=1))


def render(spec, out_stem):
    layers = spec["layers"]
    pos = node_positions(spec)
    n = len(layers)
    x = np.linspace(0.0, 1.0, n)
    bw = 0.055

    fig, ax = plt.subplots(figsize=(11.5, 8.6))
    # node bars and labels
    for li, layer in enumerate(layers):
        for name, (y0, y1) in pos[li].items():
            ax.add_patch(plt.Rectangle((x[li] - bw / 2, y0), bw, y1 - y0,
                                       facecolor="#4A4A4A", edgecolor="none", zorder=3))
        ax.text(x[li], 1.045, layer, ha="center", va="bottom", fontsize=10.5, fontweight="bold")
        for name in pos[li]:
            y0, y1 = pos[li][name]
            label = name
            if len(label) > 26:
                label = label[:24] + "…"
            if li == n - 1:
                ax.text(x[li] + bw / 2 + 0.012, (y0 + y1) / 2, label,
                        ha="left", va="center", fontsize=7.4, color="#222222")
            else:
                ax.text(x[li] - bw / 2 - 0.012, (y0 + y1) / 2, label,
                        ha="right", va="center", fontsize=7.4, color="#222222")

    # links: stacked ribbons between adjacent layers
    cursor0 = {li: {name: pos[li][name][1] for name in pos[li]} for li in range(n)}
    cursor1 = {li: {name: pos[li][name][1] for name in pos[li]} for li in range(n)}
    totals = {}
    for link in spec["links"]:
        totals[(int(link["layer"]), link["source"])] = totals.get((int(link["layer"]), link["source"]), 0.0) + float(link["flow"])
        totals[(int(link["layer"]) + 1, link["target"])] = totals.get((int(link["layer"]) + 1, link["target"]), 0.0) + float(link["flow"])
    for link in sorted(spec["links"], key=lambda z: -float(z["flow"])):
        li = int(link["layer"]); src = link["source"]; tgt = link["target"]; fl = float(link["flow"])
        h0 = pos[li][src][1] - pos[li][src][0]
        h1 = pos[li + 1][tgt][1] - pos[li + 1][tgt][0]
        f0 = fl / totals.get((li, src), fl)
        f1 = fl / totals.get((li + 1, tgt), fl)
        y0b = cursor0[li][src]; y0a = y0b - h0 * f0; cursor0[li][src] = y0a
        y1b = cursor1[li + 1][tgt]; y1a = y1b - h1 * f1; cursor1[li + 1][tgt] = y1a
        color = PALETTE[li % len(PALETTE)]
        ribbon(ax, x[li] + bw / 2, x[li + 1] - bw / 2, y0a, y0b, y1a, y1b, color)

    ax.set_xlim(-0.34, 1.18)
    ax.set_ylim(-0.02, 1.10)
    ax.axis("off")
    ax.set_title("Five-layer knowledge network (29,379 records; countries split at 41,458 PPP int$)",
                 fontsize=11, pad=18)
    fig.tight_layout()
    for ext in ("png", "pdf"):
        fig.savefig(out_stem + "." + ext, dpi=600 if ext == "png" else None,
                    bbox_inches="tight")
    plt.close(fig)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(here, "_derived", "fig3a_sankey.json"))
    ap.add_argument("--outdir", default=os.path.join(here, "_derived"))
    args = ap.parse_args()
    if not os.path.exists(args.data):
        sys.exit("Sankey data not found: %s\nRun fig3_network.R first." % args.data)
    os.makedirs(args.outdir, exist_ok=True)
    spec = load_data(args.data)
    stem = os.path.join(args.outdir, "fig3a_sankey")
    render(spec, stem)
    print("wrote", stem + ".png / .pdf")


if __name__ == "__main__":
    main()
