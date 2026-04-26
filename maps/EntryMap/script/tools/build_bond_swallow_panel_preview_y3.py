#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
OUT_PATH = TOOLS_DIR / "bond_swallow_panel_preview_y3.html"


def div(node_type, name, x, y, w, h, attrs=None, children=None, text=""):
    attrs = attrs or {}
    children = children or []
    attr_text = " ".join(
        f'{key}="{value}"'
        for key, value in {
            "data-type": node_type,
            "data-name": name,
            "data-x": x,
            "data-y": y,
            "data-w": w,
            "data-h": h,
            **attrs,
        }.items()
    )
    style = f"left:{x}px; top:{y}px; width:{w}px; height:{h}px;"
    body = text + "".join(children)
    return f'<div {attr_text} style="{style}">{body}</div>\n'


def layout(name, x, y, w, h, attrs=None, children=None):
    return div("layout", name, x, y, w, h, attrs, children)


def image(name, x, y, w, h, image_id=999, color="#ffffffff", attrs=None):
    merged = {
        "data-image": image_id,
        "data-color": color,
    }
    if attrs:
        merged.update(attrs)
    return div("image", name, x, y, w, h, merged)


def label(name, x, y, w, h, text, size=15, color="#e6eef8ff", align="left,middle"):
    return div(
        "label",
        name,
        x,
        y,
        w,
        h,
        {
            "data-text": text,
            "data-font-size": size,
            "data-color": color,
            "data-align": align,
        },
        text=text,
    )


def button(name, x, y, w, h, text="", preset="blue", color="#ffffffff"):
    return div(
        "button",
        name,
        x,
        y,
        w,
        h,
        {
            "data-text": text,
            "data-preset": preset,
            "data-color": color,
        },
        text=text,
    )


def group_button(index, x, y, text):
    return layout(
        f"root_btn_{index}",
        x,
        y,
        124,
        32,
        children=[
            button("button", 0, 0, 124, 32, text, "blue"),
        ],
    )


def card_slot(index, x, y):
    return layout(
        f"card_slot_{index}",
        x,
        y,
        68,
        68,
        children=[
            image("slot_bg", 0, 0, 68, 68, 131998, "#091119d8", {"data-scale9": "true", "data-cap-insets": "18,18,18,18"}),
            image("empty_mark", 13, 13, 42, 42, 100061, "#ffffff42"),
            image("frame", 0, 0, 68, 68, 100062, "#ffffffd8", {"data-scale9": "true", "data-cap-insets": "18,18,18,18"}),
            image("icon", 10, 10, 48, 48, 999, "#ffffffff"),
            image("state_glow", 0, 0, 68, 68, 100062, "#ffd24e00", {"data-scale9": "true", "data-cap-insets": "18,18,18,18"}),
        ],
    )


def build_html():
    basic_labels = [
        "神射手(0/5)", "游侠(0/5)", "枪炮师(0/5)",
        "猎人(0/5)", "刀锋战士(0/5)", "魔剑士(0/5)",
        "狂战士(0/5)", "剑魂(0/5)", "骷髅法师(0/5)",
        "剑宗(0/5)", "龙骑士(0/5)", "雷电法王(0/5)",
        "火法师(0/5)", "冰霜法师(0/5)", "战斗法师(0/5)",
    ]
    special_labels = [
        "新兵套(0/3)", "炼金术(0/3)", "王牌(0/5)",
        "异火(0/10)", "赌神(0/5)", "狩猎达人(0/3)",
        "小成箭术(0/3)", "大成箭术(0/5)", "龙珠(0/7)",
        "凡人修仙(0/10)", "爆战兔(0/3)", "证帝(0/10)",
        "雀魂麻将(0/8)", "作者宝库(0/10)", "绝学(0/9)",
        "诛仙剑阵(0/5)", "超能果实(0/6)", "盲盒(0/5)",
    ]

    group_children = [
        image("panel_bg", 0, 0, 430, 590, 131998, "#090d16dd", {"data-scale9": "true", "data-cap-insets": "20,20,20,20"}),
        label("basic_title", 26, 18, 140, 20, "职业卡组：", 14, "#7bb4ffff"),
        label("special_title", 26, 320, 140, 20, "特殊卡组：", 14, "#ffd26eff"),
    ]
    for i, text in enumerate(basic_labels, start=1):
        col = (i - 1) % 3
        row = (i - 1) // 3
        group_children.append(group_button(i, 28 + col * 132, 50 + row * 42, text))
    for i, text in enumerate(special_labels, start=16):
        local = i - 16
        col = local % 3
        row = local // 3
        group_children.append(group_button(i, 28 + col * 132, 350 + row * 36, text))

    grid_children = [
        image("grid_bg", 0, 0, 500, 420, 131998, "#080b12d4", {"data-scale9": "true", "data-cap-insets": "20,20,20,20"}),
        label("grid_title", 24, 18, 180, 22, "当前卡组", 16, "#7bb4ffff"),
    ]
    for index in range(1, 21):
        col = (index - 1) % 5
        row = (index - 1) // 5
        grid_children.append(card_slot(index, 30 + col * 88, 58 + row * 82))

    detail_children = [
        image("detail_bg", 0, 0, 500, 210, 131998, "#0c1017e8", {"data-scale9": "true", "data-cap-insets": "20,20,20,20"}),
        image("detail_top", 16, 18, 468, 2, 999, "#ffdd5da0"),
        label("detail_title", 34, 34, 430, 24, "选择左侧卡组查看详情", 17, "#ffe146ff", "center,middle"),
        label("detail_status", 40, 66, 420, 20, "未激活", 13, "#b2becfff", "center,middle"),
        label("detail_body", 36, 98, 430, 96, "已吞羁绊与卡牌详情会显示在这里。", 15, "#e6eef8ff", "left,top"),
    ]

    main_children = [
        image("frame_bg", 0, 0, 1180, 720, 131998, "#0a0e16f2", {"data-scale9": "true", "data-cap-insets": "24,24,24,24"}),
        image("frame_inner", 16, 16, 1148, 688, 100062, "#101722d6", {"data-scale9": "true", "data-cap-insets": "20,20,20,20"}),
        image("top_bevel", 27, 22, 1126, 4, 999, "#ffdc69b9"),
        label("title", 36, 44, 190, 40, "卡牌图鉴", 30, "#ffe64aff"),
        label("subtitle", 230, 54, 230, 24, "职业卡组 / 特殊卡组", 16, "#b4d2f2ff"),
        label("total_label", 470, 55, 140, 22, "全部已吞：", 16, "#f2f6ffff"),
        label("total_value", 570, 55, 70, 22, "0", 18, "#ffdf5fff"),
        button("close_button", 1118, 42, 44, 44, "X", "gold"),
        layout("group_panel", 34, 104, 430, 590, children=group_children),
        layout("card_grid", 512, 104, 500, 420, children=grid_children),
        layout("detail_panel", 512, 484, 500, 210, children=detail_children),
    ]

    body = layout(
        "layout",
        0,
        0,
        1920,
        1080,
        {"data-adapter": "all"},
        children=[
            image("dim_bg", 0, 0, 1920, 1080, 999, "#0000006a"),
            layout("main_frame", 370, 180, 1180, 720, children=main_children),
        ],
    )
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>UI Preview: BondSwallowPanel</title>
  <style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
      background: #0c1219;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      font-family: "Segoe UI", "Microsoft YaHei", sans-serif;
    }}
    .canvas {{
      width: 1920px;
      height: 1080px;
      transform: scale(0.62);
      transform-origin: center;
      position: relative;
      overflow: hidden;
      background: linear-gradient(180deg, #111923 0%, #080c12 100%);
    }}
    [data-type] {{ position: absolute; }}
    [data-type="label"] {{
      display: flex;
      overflow: hidden;
      white-space: pre-wrap;
      line-height: 1.15;
      text-shadow: 0 1px 2px rgba(0,0,0,.65);
    }}
    [data-type="button"] {{
      display: flex;
      align-items: center;
      justify-content: center;
      color: #eef4fb;
      font-weight: 700;
    }}
  </style>
</head>
<body>
<div class="canvas">
{body}
</div>
</body>
</html>
"""


def main():
    OUT_PATH.write_text(build_html(), encoding="utf-8")
    print(f"[OK] wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
