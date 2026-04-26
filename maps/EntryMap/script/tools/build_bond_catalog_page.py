#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = Path(__file__).resolve().parent
OUT_PATH = TOOLS_DIR / 'bond_catalog_preview.html'
BOND_NODES_CSV = ROOT / 'script' / 'data_csv' / 'bond_nodes.csv'
BOND_GROUP_LABELS_CSV = ROOT / 'script' / 'data_csv' / 'bond_group_labels.csv'
BOND_ROOT_SETS_CSV = ROOT / 'script' / 'data_csv' / 'bond_root_sets.csv'

GROUP_GLYPHS = {
    'body': '体',
    'economy': '财',
    'magic': '法',
    'archery': '弓',
    'critical': '诛',
    'growth': '修',
}

QUALITY_LABELS = {
    'rare': '稀有',
    'epic': '史诗',
    'legendary': '传说',
}

QUALITY_CLASS = {
    'rare': 'rare',
    'epic': 'epic',
    'legendary': 'legendary',
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open('r', encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


def build_records() -> tuple[list[dict[str, object]], dict[str, str]]:
    group_rows = read_csv(BOND_GROUP_LABELS_CSV)
    group_labels = {row['group_id']: row['display_name'] for row in group_rows}

    node_rows = read_csv(BOND_NODES_CSV)
    root_rows = read_csv(BOND_ROOT_SETS_CSV)
    root_rules = {row['root_id']: row for row in root_rows}

    line_roots: dict[str, str] = {}
    line_best_tier: dict[str, int] = {}
    for row in node_rows:
        line_id = row['line_id']
        tier = int(row['tier'] or '0')
        if line_id not in line_best_tier or tier < line_best_tier[line_id]:
            line_best_tier[line_id] = tier
            line_roots[line_id] = row['display_name']

    records: list[dict[str, object]] = []
    for index, row in enumerate(node_rows, start=1):
        group_id = row['group_id']
        line_id = row['line_id']
        quality = row['quality'] or 'rare'
        tier = int(row['tier'] or '0')
        parent_id = row['parent_id'] or ''
        next_ids = [item for item in (row['next_ids'] or '').split('|') if item]
        route_tags = [item for item in (row['route_tags'] or '').split('|') if item]
        root_rule = root_rules.get(row['id']) if not parent_id else None

        records.append({
            'index': index,
            'id': row['id'],
            'display_name': row['display_name'],
            'group_id': group_id,
            'group_name': group_labels.get(group_id, group_id),
            'group_glyph': GROUP_GLYPHS.get(group_id, group_labels.get(group_id, group_id)[:1] or '羁'),
            'line_id': line_id,
            'line_name': line_roots.get(line_id, line_id),
            'tier': tier,
            'tier_text': f'第{tier}层',
            'parent_id': parent_id or None,
            'next_ids': next_ids,
            'route_tags': route_tags,
            'quality': quality,
            'quality_label': QUALITY_LABELS.get(quality, quality),
            'quality_class': QUALITY_CLASS.get(quality, 'rare'),
            'icon_id': row['icon'] or '',
            'editor_skill_id': row['editor_skill_id'] or '',
            'desc_single': row['desc_single'] or '',
            'desc_advanced': row['desc_advanced'] or '',
            'unlock_gold': int(row['unlock_gold'] or '0') if row['unlock_gold'] else 0,
            'unlock_wood': int(row['unlock_wood'] or '0') if row['unlock_wood'] else 0,
            'unlock_exp': int(row['unlock_exp'] or '0') if row['unlock_exp'] else 0,
            'root_required_count': int(root_rule['required_count']) if root_rule and root_rule.get('required_count') else 0,
            'root_base_text': root_rule['base_text'] if root_rule else '',
            'root_effect_text': root_rule['effect_text'] if root_rule else '',
            'completion_mode': root_rule['completion_mode'] if root_rule else '',
            'is_root': not parent_id,
        })

    return records, group_labels


def build_html(records: list[dict[str, object]], group_labels: dict[str, str]) -> str:
    payload = json.dumps(records, ensure_ascii=False)
    labels = json.dumps(group_labels, ensure_ascii=False)

    html = '''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>羁绊图鉴</title>
  <style>
    :root {{
      --bg-0: #06090f;
      --bg-1: #0e1118;
      --bg-2: #141824;
      --panel-0: #151a23;
      --panel-1: #1b2230;
      --panel-2: #202736;
      --line-0: #2f3745;
      --line-1: #515d73;
      --text-0: #eef3ff;
      --text-1: #cdd7ea;
      --text-2: #94a2b7;
      --gold-0: #f4cf6a;
      --gold-1: #c68e2a;
      --gold-2: #80591b;
      --rare: #4d8fd9;
      --epic: #9a53df;
      --legendary: #e0b243;
      --green: #6fe45a;
      --blue: #5cb8ff;
      --purple: #c36bff;
    }}
    * {{ box-sizing: border-box; }}
    html, body {{
      width: 100%;
      height: 100%;
      margin: 0;
      overflow: hidden;
      font-family: "Microsoft YaHei", "Noto Sans SC", sans-serif;
      color: var(--text-0);
      background:
        radial-gradient(circle at 18% 20%, rgba(102, 146, 255, .16), transparent 22%),
        radial-gradient(circle at 80% 18%, rgba(236, 171, 71, .18), transparent 18%),
        radial-gradient(circle at 50% 78%, rgba(63, 179, 126, .12), transparent 20%),
        linear-gradient(135deg, #090c13 0%, #111725 42%, #05070c 100%);
    }}
    body::before {{
      content: "";
      position: fixed;
      inset: 0;
      pointer-events: none;
      opacity: .22;
      background:
        linear-gradient(90deg, rgba(255,255,255,.05) 1px, transparent 1px),
        linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px);
      background-size: 44px 44px;
      mask-image: linear-gradient(to bottom, rgba(0,0,0,.85), rgba(0,0,0,.3));
    }}
    .shell {{
      position: absolute;
      left: 50%;
      top: 50%;
      width: min(1280px, calc(100vw - 40px));
      height: min(820px, calc(100vh - 40px));
      transform: translate(-50%, -50%);
      display: grid;
      grid-template-columns: 164px minmax(0, 1fr);
      background: linear-gradient(180deg, rgba(18, 22, 32, .94), rgba(9, 11, 16, .95));
      border: 1px solid rgba(231, 199, 111, .18);
      box-shadow:
        0 0 0 1px rgba(255,255,255,.05) inset,
        0 20px 70px rgba(0,0,0,.45);
      overflow: hidden;
    }}
    .sidebar {{
      position: relative;
      display: flex;
      flex-direction: column;
      padding: 24px 16px 18px 14px;
      background:
        linear-gradient(180deg, rgba(13,16,23,.98), rgba(17,21,30,.96)),
        linear-gradient(180deg, rgba(222, 186, 101, .08), transparent 24%);
      border-right: 1px solid rgba(255,255,255,.06);
    }}
    .sidebar .brand {{
      font-size: 30px;
      line-height: 1;
      letter-spacing: 0;
      color: var(--gold-0);
      margin-bottom: 16px;
      text-shadow: 0 2px 0 rgba(43, 28, 4, .65);
    }}
    .sidebar .brand::after {{
      content: "";
      display: block;
      width: 86px;
      height: 4px;
      margin-top: 12px;
      background: linear-gradient(90deg, var(--gold-1), rgba(255,255,255,0));
      border-radius: 999px;
    }}
    .sidebar .hint {{
      margin: 0 0 18px;
      color: var(--text-2);
      font-size: 12px;
      line-height: 1.7;
    }}
    .nav {{
      display: flex;
      flex-direction: column;
      gap: 8px;
    }}
    .nav button {{
      appearance: none;
      border: 0;
      padding: 0;
      text-align: left;
      background: transparent;
      color: var(--text-1);
      cursor: pointer;
      font: inherit;
      letter-spacing: 0;
    }}
    .nav-item {{
      height: 40px;
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 0 10px 0 12px;
      border-left: 4px solid transparent;
      background: rgba(255,255,255,.01);
      transition: transform .12s ease, background .12s ease, border-color .12s ease;
    }}
    .nav-item:hover {{ transform: translateX(1px); background: rgba(255,255,255,.04); }}
    .nav-item.active {{
      background: linear-gradient(90deg, rgba(220, 181, 73, .26), rgba(111, 130, 157, .14));
      border-left-color: var(--gold-0);
      color: var(--text-0);
      box-shadow: 0 0 0 1px rgba(255,255,255,.03) inset;
    }}
    .nav-item .key {{
      width: 24px;
      height: 24px;
      display: grid;
      place-items: center;
      border-radius: 999px;
      background: rgba(255,255,255,.06);
      color: var(--gold-0);
      font-size: 13px;
      flex: 0 0 auto;
    }}
    .nav-item .label {{
      min-width: 0;
      font-size: 15px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .nav-foot {{
      margin-top: auto;
      padding-top: 14px;
      display: grid;
      gap: 8px;
      color: var(--text-2);
      font-size: 12px;
      line-height: 1.6;
      border-top: 1px solid rgba(255,255,255,.06);
    }}
    .nav-foot strong {{
      color: var(--gold-0);
      font-weight: 500;
    }}
    .workspace {{
      min-width: 0;
      display: grid;
      grid-template-columns: minmax(0, 1fr) 300px;
      gap: 16px;
      padding: 14px;
      background:
        linear-gradient(180deg, rgba(255,255,255,.02), transparent 22%),
        linear-gradient(180deg, rgba(8,10,14,.96), rgba(10,12,18,.98));
    }}
    .catalog {{
      min-width: 0;
      display: grid;
      grid-template-rows: auto auto minmax(0, 1fr);
      gap: 12px;
      padding: 10px 10px 12px;
      background: linear-gradient(180deg, rgba(14, 18, 26, .98), rgba(12, 15, 22, .98));
      border: 1px solid rgba(255,255,255,.05);
      box-shadow: 0 0 0 1px rgba(255,255,255,.03) inset;
      overflow: hidden;
    }}
    .hero {{
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 12px;
      align-items: end;
      padding: 4px 2px 0;
    }}
    .title-block h1 {{
      margin: 0;
      font-size: 28px;
      line-height: 1;
      color: var(--gold-0);
      text-shadow: 0 2px 0 rgba(43, 28, 4, .6);
    }}
    .title-block .sub {{
      margin-top: 8px;
      color: var(--text-2);
      font-size: 13px;
      line-height: 1.6;
    }}
    .stats {{
      display: grid;
      grid-auto-flow: column;
      grid-auto-columns: minmax(86px, 1fr);
      gap: 8px;
      align-items: stretch;
    }}
    .stat {{
      min-width: 0;
      padding: 9px 10px 8px;
      background: linear-gradient(180deg, rgba(33, 40, 54, .9), rgba(18, 23, 33, .96));
      border: 1px solid rgba(255,255,255,.05);
      box-shadow: 0 1px 0 rgba(255,255,255,.04) inset;
    }}
    .stat .k {{
      color: var(--text-2);
      font-size: 12px;
      line-height: 1.2;
      white-space: nowrap;
    }}
    .stat .v {{
      margin-top: 6px;
      color: var(--text-0);
      font-size: 20px;
      line-height: 1;
      font-weight: 700;
    }}
    .filters {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      padding: 2px 0 0;
    }}
    .filter {{
      height: 32px;
      padding: 0 12px;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      border: 1px solid rgba(255,255,255,.07);
      background: rgba(33, 38, 49, .92);
      color: var(--text-1);
      cursor: pointer;
      user-select: none;
      transition: transform .12s ease, background .12s ease, border-color .12s ease;
      white-space: nowrap;
      font-size: 13px;
    }}
    .filter:hover {{ transform: translateY(-1px); }}
    .filter.active {{
      background: linear-gradient(180deg, rgba(207, 156, 53, .9), rgba(148, 99, 23, .94));
      color: white;
      border-color: rgba(255, 227, 154, .55);
    }}
    .filter .count {{
      padding: 0 6px;
      min-width: 22px;
      height: 18px;
      display: inline-grid;
      place-items: center;
      border-radius: 999px;
      background: rgba(255,255,255,.08);
      color: var(--gold-0);
      font-size: 11px;
    }}
    .filter.active .count {{
      background: rgba(255,255,255,.16);
      color: white;
    }}
    .grid-shell {{
      min-height: 0;
      display: grid;
      grid-template-rows: auto minmax(0, 1fr);
      gap: 10px;
      padding-top: 4px;
      overflow: hidden;
    }}
    .grid-head {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      color: var(--text-2);
      font-size: 12px;
      line-height: 1.5;
    }}
    .legend {{
      display: inline-flex;
      align-items: center;
      gap: 10px;
      white-space: nowrap;
    }}
    .legend span {{
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }}
    .dot {{
      width: 8px;
      height: 8px;
      border-radius: 50%;
      display: inline-block;
    }}
    .dot.rare {{ background: var(--rare); }}
    .dot.epic {{ background: var(--epic); }}
    .dot.legendary {{ background: var(--legendary); }}
    .grid {{
      min-height: 0;
      display: grid;
      grid-template-columns: repeat(10, minmax(0, 1fr));
      gap: 8px;
      align-content: start;
    }}
    .card {{
      position: relative;
      aspect-ratio: 1 / 1;
      min-width: 0;
      min-height: 0;
      border: 1px solid rgba(255,255,255,.07);
      background:
        linear-gradient(180deg, rgba(31, 37, 50, .98), rgba(20, 24, 33, .98));
      box-shadow:
        0 0 0 1px rgba(0,0,0,.34) inset,
        0 8px 14px rgba(0,0,0,.18);
      cursor: pointer;
      user-select: none;
      overflow: hidden;
      transition: transform .12s ease, border-color .12s ease, box-shadow .12s ease;
    }}
    .card:hover {{
      transform: translateY(-1px);
      border-color: rgba(255, 214, 107, .35);
      box-shadow:
        0 0 0 1px rgba(255,255,255,.04) inset,
        0 10px 18px rgba(0,0,0,.22);
    }}
    .card.active {{
      border-color: rgba(255, 221, 128, .86);
      box-shadow:
        0 0 0 1px rgba(255,255,255,.1) inset,
        0 0 0 2px rgba(255, 216, 107, .14),
        0 12px 20px rgba(0,0,0,.26);
    }}
    .card::before {{
      content: "";
      position: absolute;
      inset: 0;
      background:
        linear-gradient(135deg, rgba(255,255,255,.06), transparent 24%),
        linear-gradient(180deg, rgba(255,255,255,.03), transparent 36%);
      pointer-events: none;
    }}
    .card .band {{
      position: absolute;
      left: 0;
      top: 0;
      width: 100%;
      height: 4px;
    }}
    .card.rare .band {{ background: var(--rare); }}
    .card.epic .band {{ background: var(--epic); }}
    .card.legendary .band {{ background: var(--legendary); }}
    .card .glyph {{
      position: absolute;
      left: 50%;
      top: 10px;
      transform: translateX(-50%);
      width: 24px;
      height: 24px;
      display: grid;
      place-items: center;
      border-radius: 999px;
      background: rgba(246, 201, 101, .16);
      color: var(--gold-0);
      font-size: 16px;
      font-weight: 700;
    }}
    .card .title {{
      position: absolute;
      left: 4px;
      right: 4px;
      bottom: 16px;
      color: var(--text-0);
      text-align: center;
      font-size: 11px;
      line-height: 1.2;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .card .meta {{
      position: absolute;
      left: 4px;
      right: 4px;
      bottom: 2px;
      color: var(--text-2);
      text-align: center;
      font-size: 10px;
      line-height: 1.1;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .card .chip {{
      position: absolute;
      right: 4px;
      top: 4px;
      min-width: 20px;
      height: 16px;
      display: grid;
      place-items: center;
      padding: 0 4px;
      background: rgba(10, 13, 18, .76);
      border: 1px solid rgba(255,255,255,.06);
      color: var(--gold-0);
      font-size: 10px;
      border-radius: 999px;
    }}
    .card .selected {{
      position: absolute;
      inset: 0;
      border: 1px solid rgba(255, 219, 117, .58);
      background: rgba(255, 219, 117, .08);
      display: none;
    }}
    .card.active .selected {{ display: block; }}
    .detail {{
      min-width: 0;
      display: grid;
      grid-template-rows: auto auto auto 1fr auto;
      gap: 12px;
      padding: 12px;
      background: linear-gradient(180deg, rgba(18, 22, 31, .98), rgba(12, 15, 22, .98));
      border: 1px solid rgba(255,255,255,.05);
      box-shadow: 0 0 0 1px rgba(255,255,255,.03) inset;
      overflow: hidden;
    }}
    .detail-head {{
      display: grid;
      grid-template-columns: 94px minmax(0, 1fr);
      gap: 12px;
      align-items: center;
    }}
    .detail-icon {{
      position: relative;
      width: 94px;
      height: 94px;
      display: grid;
      place-items: center;
      border: 1px solid rgba(255,255,255,.08);
      background: linear-gradient(180deg, rgba(42, 50, 66, .96), rgba(18, 22, 31, .98));
      box-shadow: 0 0 0 1px rgba(0,0,0,.3) inset;
    }}
    .detail-icon .badge {{
      position: absolute;
      inset: 10px;
      border-radius: 18px;
      display: grid;
      place-items: center;
      background: rgba(246, 201, 101, .14);
      color: var(--gold-0);
      font-size: 44px;
      font-weight: 700;
    }}
    .detail-title {{
      min-width: 0;
    }}
    .detail-title h2 {{
      margin: 0;
      font-size: 22px;
      line-height: 1.08;
      color: var(--text-0);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .detail-title .sub {{
      margin-top: 8px;
      color: var(--text-2);
      font-size: 12px;
      line-height: 1.7;
    }}
    .detail-tags {{
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
    }}
    .pill {{
      height: 24px;
      display: inline-flex;
      align-items: center;
      padding: 0 9px;
      background: rgba(255,255,255,.05);
      border: 1px solid rgba(255,255,255,.06);
      color: var(--text-1);
      font-size: 11px;
      white-space: nowrap;
    }}
    .pill.gold {{ color: var(--gold-0); border-color: rgba(255, 209, 123, .18); background: rgba(255, 209, 123, .06); }}
    .pill.rare {{ color: #b7d7ff; border-color: rgba(77, 143, 217, .18); background: rgba(77, 143, 217, .06); }}
    .pill.epic {{ color: #e3c2ff; border-color: rgba(154, 83, 223, .18); background: rgba(154, 83, 223, .06); }}
    .pill.legendary {{ color: #ffe5aa; border-color: rgba(224, 178, 67, .18); background: rgba(224, 178, 67, .06); }}
    .block {{
      min-width: 0;
      padding: 10px 12px;
      background: linear-gradient(180deg, rgba(32, 38, 50, .92), rgba(18, 22, 31, .96));
      border: 1px solid rgba(255,255,255,.06);
    }}
    .block .k {{
      color: var(--gold-0);
      font-size: 12px;
      line-height: 1.4;
      margin-bottom: 6px;
    }}
    .block .v {{
      color: var(--text-1);
      font-size: 13px;
      line-height: 1.8;
      white-space: pre-wrap;
      word-break: break-word;
    }}
    .block.small .v {{
      line-height: 1.6;
    }}
    .detail-footer {{
      display: grid;
      gap: 8px;
    }}
    .action {{
      height: 40px;
      display: grid;
      place-items: center;
      background: linear-gradient(180deg, var(--gold-0), var(--gold-1));
      color: white;
      border: 1px solid rgba(255, 232, 161, .42);
      cursor: pointer;
      user-select: none;
      font-size: 15px;
      letter-spacing: 0;
      box-shadow: 0 8px 18px rgba(193, 141, 38, .18);
    }}
    .action.secondary {{
      background: linear-gradient(180deg, #3b4353, #2a3140);
      border-color: rgba(255,255,255,.05);
      box-shadow: none;
      color: var(--text-1);
    }}
    .footer-note {{
      color: var(--text-2);
      font-size: 12px;
      line-height: 1.6;
      margin: 0;
    }}
    .empty {{
      position: absolute;
      inset: 0;
      display: grid;
      place-items: center;
      color: var(--text-2);
      font-size: 14px;
      text-align: center;
      padding: 24px;
      pointer-events: none;
    }}
    @media (max-width: 1200px) {{
      body {{ overflow: auto; }}
      .shell {{
        position: static;
        transform: none;
        width: auto;
        height: auto;
        min-height: 100vh;
        grid-template-columns: 140px minmax(0, 1fr);
      }}
      .workspace {{
        grid-template-columns: minmax(0, 1fr) 280px;
      }}
      .grid {{
        grid-template-columns: repeat(8, minmax(0, 1fr));
      }}
    }}
  </style>
</head>
<body>
  <div class="shell">
    <aside class="sidebar">
      <div class="brand">图鉴</div>
      <div class="hint">羁绊图鉴 · 按流派、层级和品质浏览节点，点击卡片查看详细说明。</div>
      <nav class="nav" id="nav"></nav>
      <div class="nav-foot">
        <div>总节点 <strong id="navTotal">0</strong></div>
        <div>主线 <strong id="navRoots">0</strong></div>
        <div>品质 <strong id="navQuality">0</strong></div>
      </div>
    </aside>
    <main class="workspace">
      <section class="catalog">
        <div class="hero">
          <div class="title-block">
            <h1>羁绊图鉴</h1>
            <div class="sub">100 个节点 · 6 条主线 · 直接浏览每个节点的流派、层级、品质与效果。</div>
          </div>
          <div class="stats" id="stats"></div>
        </div>
        <div class="filters" id="filters"></div>
        <div class="grid-shell">
          <div class="grid-head">
            <div class="legend">
              <span><i class="dot rare"></i>稀有</span>
              <span><i class="dot epic"></i>史诗</span>
              <span><i class="dot legendary"></i>传说</span>
            </div>
            <div id="gridHint">点击节点查看详细内容</div>
          </div>
          <div class="grid" id="grid"></div>
        </div>
      </section>
      <aside class="detail">
        <div class="detail-head">
          <div class="detail-icon" id="detailIconWrap">
            <div class="badge" id="detailIcon">体</div>
          </div>
          <div class="detail-title">
            <h2 id="detailName">体术</h2>
            <div class="sub" id="detailSub">体术 · 金刚体线 · 第1层</div>
          </div>
        </div>
        <div class="detail-tags" id="detailTags"></div>
        <div class="block small">
          <div class="k">节点说明</div>
          <div class="v" id="detailSummary">请选择一个节点查看说明。</div>
        </div>
        <div class="block">
          <div class="k">效果与条件</div>
          <div class="v" id="detailEffect"></div>
        </div>
        <div class="detail-footer">
          <div class="action" id="detailAction">查看节点</div>
          <div class="action secondary" id="detailSecondary">切换到当前节点</div>
          <p class="footer-note" id="detailFoot">右侧详情会随卡片点击变化，适合后续接入真正的图鉴阅读页。</p>
        </div>
      </aside>
    </main>
  </div>
  <script>
    const GROUP_LABELS = __LABELS__;
    const BONDS = __PAYLOAD__;
    const GROUP_ORDER = ['all', 'body', 'economy', 'magic', 'archery', 'critical', 'growth'];
    const GROUP_TEXT = {{
      all: '全部',
      body: GROUP_LABELS.body || '体术',
      economy: GROUP_LABELS.economy || '经济',
      magic: GROUP_LABELS.magic || '法术',
      archery: GROUP_LABELS.archery || '箭术',
      critical: GROUP_LABELS.critical || '暴击',
      growth: GROUP_LABELS.growth || '成长',
    }};
    const GROUP_GLYPHS = {{
      all: '全',
      body: '体',
      economy: '财',
      magic: '法',
      archery: '弓',
      critical: '诛',
      growth: '修',
    }};

    const state = {{
      filter: 'all',
      selected: BONDS[0]?.id || null,
    }};

    const nav = document.getElementById('nav');
    const filters = document.getElementById('filters');
    const grid = document.getElementById('grid');
    const stats = document.getElementById('stats');

    const groupCounts = Object.fromEntries(GROUP_ORDER.map(key => [key, 0]));
    const qualityCounts = {{ rare: 0, epic: 0, legendary: 0 }};
    const rootCount = BONDS.filter(item => item.is_root).length;
    for (const item of BONDS) {{
      groupCounts[item.group_id] = (groupCounts[item.group_id] || 0) + 1;
      qualityCounts[item.quality] = (qualityCounts[item.quality] || 0) + 1;
    }}

    document.getElementById('navTotal').textContent = String(BONDS.length);
    document.getElementById('navRoots').textContent = String(rootCount);
    document.getElementById('navQuality').textContent = String(Object.keys(qualityCounts).length);

    const statItems = [
      ['节点总数', BONDS.length],
      ['主线根节点', rootCount],
      ['稀有 / 史诗', `${{qualityCounts.rare}} / ${{qualityCounts.epic}}`],
      ['传说节点', qualityCounts.legendary],
    ];
    stats.innerHTML = statItems.map(([k, v]) => `<div class="stat"><div class="k">${{k}}</div><div class="v">${{v}}</div></div>`).join('');

    function cleanText(value) {{
      return String(value || '').trim();
    }}

    function joinLines(lines) {{
      return (lines || []).filter(Boolean).map(cleanText).join('<br />');
    }}

    function buildTags(item) {{
      const tags = [
        `<span class="pill ${{item.quality_class}}">${{item.quality_label}}</span>`,
        `<span class="pill gold">${{item.group_name}}</span>`,
        `<span class="pill">${{item.line_name}}</span>`,
        `<span class="pill">${{item.tier_text}}</span>`,
      ];
      if (item.is_root) {{
        tags.push(`<span class="pill gold">主线根节点</span>`);
      }}
      return tags.join('');
    }}

    function buildSummary(item) {{
      const lines = [];
      if (item.is_root && item.root_base_text) {{
        lines.push(`根套装需求：${{item.root_required_count || 0}} 张`);
        lines.push(item.root_base_text);
      }} else {{
        lines.push(item.desc_single || '当前没有单卡说明。');
      }}
      if (item.is_root && item.root_effect_text) {{
        lines.push(item.root_effect_text);
      }} else if (item.desc_advanced) {{
        lines.push(item.desc_advanced);
      }}
      if (item.route_tags && item.route_tags.length > 0) {{
        lines.push(`路线标签：${{item.route_tags.join(' / ')}}`);
      }}
      return lines.map(cleanText).filter(Boolean).join('<br />');
    }}

    function buildEffect(item) {{
      const lines = [];
      if (item.unlock_gold || item.unlock_wood || item.unlock_exp) {{
        const rewards = [];
        if (item.unlock_gold) rewards.push(`金币 +${{item.unlock_gold}}`);
        if (item.unlock_wood) rewards.push(`木材 +${{item.unlock_wood}}`);
        if (item.unlock_exp) rewards.push(`经验 +${{item.unlock_exp}}`);
        lines.push(`解锁奖励：${{rewards.join('，')}}`);
      }}
      if (item.is_root) {{
        lines.push(`完成方式：${{item.completion_mode || 'consume_all'}}`);
        if (item.root_base_text) lines.push(`基础效果：${{item.root_base_text}}`);
        if (item.root_effect_text) lines.push(`成套效果：${{item.root_effect_text}}`);
      }} else {{
        lines.push(`前置节点：${{item.parent_id || '无'}}`);
        lines.push(`线路层级：${{item.line_name}} · ${{item.tier_text}}`);
        if (item.desc_advanced) lines.push(`进阶说明：${{item.desc_advanced}}`);
      }}
      if (item.route_tags && item.route_tags.length > 0) {{
        lines.push(`路线标签：${{item.route_tags.join('，')}}`);
      }}
      return lines.map(cleanText).filter(Boolean).join('<br />');
    }}

    function renderDetail(item) {{
      if (!item) return;
      const iconWrap = document.getElementById('detailIconWrap');
      document.getElementById('detailIcon').textContent = item.group_glyph || '羁';
      document.getElementById('detailName').textContent = item.display_name;
      document.getElementById('detailSub').textContent = `${{item.group_name}} · ${{item.line_name}} · ${{item.tier_text}}`;
      document.getElementById('detailTags').innerHTML = buildTags(item);
      document.getElementById('detailSummary').innerHTML = buildSummary(item);
      document.getElementById('detailEffect').innerHTML = buildEffect(item);
      document.getElementById('detailAction').textContent = item.is_root ? '查看主线条件' : '查看节点说明';
      document.getElementById('detailSecondary').textContent = item.is_root ? '定位主线根节点' : '定位前置路线';
      document.getElementById('detailFoot').textContent = item.is_root
        ? '主线节点展示根套装需求和成套效果，适合后续接入真正的存档图鉴。'
        : '子节点展示单卡说明、进阶描述和路线标签，方便后续接入筛选与跳转。';
      iconWrap.className = `detail-icon ${{item.quality_class}}`;
    }}

    function filteredItems() {{
      if (state.filter === 'all') return BONDS;
      return BONDS.filter(item => item.group_id === state.filter);
    }}

    function renderNav() {{
      nav.innerHTML = GROUP_ORDER.map(key => `
        <button type="button" class="nav-item ${{state.filter === key ? 'active' : ''}}" data-group="${{key}}">
          <span class="key">${{GROUP_GLYPHS[key]}}</span>
          <span class="label">${{GROUP_TEXT[key]}} ${{key === 'all' ? '' : `(${groupCounts[key] || 0})`}}</span>
        </button>
      `).join('');
      filters.innerHTML = GROUP_ORDER.map(key => `
        <button type="button" class="filter ${{state.filter === key ? 'active' : ''}}" data-group="${{key}}">
          <span>${{GROUP_TEXT[key]}}</span>
          <span class="count">${{key === 'all' ? BONDS.length : groupCounts[key] || 0}}</span>
        </button>
      `).join('');
    }}

    function renderGrid() {{
      const items = filteredItems();
      if (!state.selected || !items.some(item => item.id === state.selected)) {{
        state.selected = items[0]?.id || null;
      }}
      grid.innerHTML = items.map(item => `
        <div class="card ${{item.quality_class}} ${{state.selected === item.id ? 'active' : ''}}" data-item="${{item.id}}">
          <div class="band"></div>
          <div class="glyph">${{item.group_glyph}}</div>
          <div class="chip">${{item.tier}}</div>
          <div class="title">${{item.display_name}}</div>
          <div class="meta">${{item.group_name}}</div>
          <div class="selected"></div>
        </div>
      `).join('');

      document.getElementById('gridHint').textContent = `当前显示 ${{items.length}} 个节点，点击任一卡片即可查看详细说明。`;
      renderDetail(items.find(item => item.id === state.selected) || items[0] || BONDS[0]);
      renderNav();
    }}

    document.addEventListener('click', event => {{
      const navItem = event.target.closest('[data-group]');
      if (navItem) {{
        state.filter = navItem.dataset.group;
        renderGrid();
        return;
      }}
      const card = event.target.closest('[data-item]');
      if (card) {{
        state.selected = card.dataset.item;
        renderGrid();
        return;
      }}
    }});

    document.getElementById('detailAction').addEventListener('click', () => {{
      const item = BONDS.find(row => row.id === state.selected) || BONDS[0];
      if (!item) return;
      alert(`${{item.display_name}}\\n${{item.is_root ? item.root_effect_text || item.root_base_text || '' : item.desc_advanced || item.desc_single || ''}}`);
    }});

    document.getElementById('detailSecondary').addEventListener('click', () => {{
      const item = BONDS.find(row => row.id === state.selected) || BONDS[0];
      if (!item) return;
      state.filter = item.group_id;
      renderGrid();
    }});

    renderGrid();
  </script>
</body>
</html>
'''
    html = html.replace('{{', '{').replace('}}', '}')
    return html.replace('__LABELS__', labels).replace('__PAYLOAD__', payload)


def main() -> None:
    records, group_labels = build_records()
    OUT_PATH.write_text(build_html(records, group_labels), encoding='utf-8')
    print(f'[OK] wrote {OUT_PATH}')


if __name__ == '__main__':
    main()
