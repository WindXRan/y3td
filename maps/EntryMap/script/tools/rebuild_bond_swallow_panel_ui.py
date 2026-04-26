#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TOOLS_DIR = ROOT / "maps" / "EntryMap" / "script" / "tools"
UI_PATH = ROOT / "maps" / "EntryMap" / "ui" / "BondSwallowPanel.json"
TREE_PATH = ROOT / "maps" / "EntryMap" / "ui_tree" / "BondSwallowPanel_Tree.json"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"

spec = importlib.util.spec_from_file_location("battle_bottom_builder", TOOLS_DIR / "rebuild_battle_bottom_hud_ui.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

BG_BLACK = builder.BG_BLACK
SHOP_BG = builder.SHOP_BG
SHOP_CONTENT_BG = builder.SHOP_CONTENT_BG
SHOP_CONTENT_BG_ALT = builder.SHOP_CONTENT_BG_ALT
SHOP_LINE = builder.SHOP_LINE
PROP_FRAME = builder.PROP_FRAME
PROP_FRAME_ALT = builder.PROP_FRAME_ALT
SKILL_SMALL_EMPTY = builder.SKILL_SMALL_EMPTY
BUTTON_BLUE = builder.BUTTON_BLUE
BUTTON_BLUE_HOV = builder.BUTTON_BLUE_HOV
BUTTON_BLUE_DWN = builder.BUTTON_BLUE_DWN
BUTTON_ACTION_GOLD = builder.BUTTON_ACTION_GOLD
BUTTON_ACTION_GOLD_HOV = builder.BUTTON_ACTION_GOLD_HOV
BUTTON_ACTION_GOLD_DWN = builder.BUTTON_ACTION_GOLD_DWN
ICON_MISC = builder.ICON_MISC


def layout(*args, **kwargs):
    return builder.layout(*args, **kwargs)


def panel(*args, **kwargs):
    return builder.panel(*args, **kwargs)


def image(*args, **kwargs):
    return builder.image(*args, **kwargs)


def text(*args, **kwargs):
    return builder.text(*args, **kwargs)


def button(*args, **kwargs):
    return builder.button(*args, **kwargs)


def fullscreen_layout(*args, **kwargs):
    return builder.fullscreen_layout(*args, **kwargs)


def tree_of(node):
    return builder.tree_of(node)


def uid():
    return builder.uid()


def grid_view(name, x, y, width, height):
    root = layout(name, x, y, width, height, [255, 255, 255, 0], True)
    root["type"] = 25
    root["children"] = []
    return root


def build_panel():
    root = {
        "adapt_mode": 2,
        "anim_data": {},
        "auto_create": True,
        "children": [],
        "name": "BondSwallowPanel",
        "opacity": 1.0,
        "script_name": "",
        "type": 2,
        "ui_anims": [],
        "uid": uid(),
        "visible": False,
        "zorder": 9560,
    }

    canvas = fullscreen_layout("layout")
    canvas["children"] = [
        image("dim_bg", 960, 540, 1920, 1080, BG_BLACK, [0, 0, 0, 106], True),
    ]

    main = panel("main_frame", 960, 540, 1180, 720, [10, 14, 22, 245])
    main["children"] = [
        image("frame_bg", 590, 360, 1180, 720, SHOP_BG, [255, 255, 255, 242], True),
        image("frame_inner", 590, 360, 1148, 686, BG_BLACK, [255, 255, 255, 218], True),
        image("top_bevel", 590, 704, 1126, 4, SHOP_LINE, [255, 220, 105, 185], True),
        text("title", 118, 676, 190, 40, "卡牌图鉴", 30, [255, 230, 74, 255], 0),
        text("subtitle", 312, 676, 220, 24, "职业卡组 / 特殊卡组", 16, [180, 210, 242, 255], 0),
        text("total_label", 492, 676, 140, 22, "全部已吞：", 16, [242, 246, 255, 255], 0),
        text("total_value", 594, 676, 60, 22, "0", 18, [255, 223, 95, 255], 0),
        button(
            "close_button",
            1140,
            676,
            44,
            44,
            "X",
            normal_picture=BUTTON_ACTION_GOLD,
            suspend_picture=BUTTON_ACTION_GOLD_HOV,
            press_picture=BUTTON_ACTION_GOLD_DWN,
            disabled_picture=BUTTON_ACTION_GOLD,
            font_size=20,
        ),
    ]

    left = panel("group_panel", 236, 348, 430, 590, [9, 12, 20, 220])
    left["children"] = [
        image("panel_bg", 215, 295, 420, 580, BG_BLACK, [255, 255, 255, 140], True),
        text("group_title", 30, 558, 160, 20, "羁绊列表：", 14, [123, 180, 255, 255], 0),
        grid_view("group_grid", 215, 286, 392, 510),
    ]

    grid = panel("card_grid", 725, 410, 500, 420, [8, 10, 16, 210])
    grid["children"] = [
        image("grid_bg", 250, 210, 500, 420, BG_BLACK, [255, 255, 255, 115], True),
        text("grid_title", 34, 394, 170, 22, "当前卡组", 16, [123, 180, 255, 255], 0),
        grid_view("card_list", 250, 190, 462, 340),
    ]

    detail = panel("detail_panel", 725, 118, 500, 210, [12, 14, 22, 230])
    detail["children"] = [
        image("detail_bg", 250, 105, 500, 210, BG_BLACK, [255, 255, 255, 142], True),
        image("detail_top", 250, 202, 472, 2, SHOP_LINE, [255, 221, 93, 160], True),
        text("detail_title", 250, 178, 430, 24, "选择左侧卡组查看详情", 17, [255, 225, 70, 255], 1),
        text("detail_status", 250, 150, 420, 20, "未激活", 13, [178, 190, 206, 255], 1),
        text("detail_body", 250, 82, 430, 96, "已吞羁绊与卡牌详情会显示在这里。", 15, [230, 238, 248, 255], 0),
    ]

    main["children"].extend([left, grid, detail])
    canvas["children"].append(main)
    root["children"] = [canvas]
    return root


def register_panel(panel_data):
    panel_tree_info = json.loads(PANEL_TREE_INFO_PATH.read_text(encoding="utf-8"))
    custom_group = None
    for entry in panel_tree_info:
        if entry.get("name") == "code_ui_custom_panel_tree":
            custom_group = entry
            break
    if custom_group is None:
        custom_group = {"name": "code_ui_custom_panel_tree", "key": 2147483647, "group": []}
        panel_tree_info.insert(0, custom_group)

    kept = []
    for item in custom_group.get("group", []):
        name = None
        if isinstance(item, dict) and item.get("__tuple__") is True:
            items = item.get("items", [])
            if len(items) >= 2:
                name = items[1]
        if name != panel_data["name"]:
            kept.append(item)
    kept.append({"__tuple__": True, "items": [panel_data["uid"], panel_data["name"]]})
    custom_group["group"] = kept
    PANEL_TREE_INFO_PATH.write_text(json.dumps(panel_tree_info, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main():
    panel_data = build_panel()
    UI_PATH.parent.mkdir(parents=True, exist_ok=True)
    TREE_PATH.parent.mkdir(parents=True, exist_ok=True)
    UI_PATH.write_text(json.dumps(panel_data, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    TREE_PATH.write_text(json.dumps(tree_of(panel_data), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    register_panel(panel_data)
    print(f"wrote {UI_PATH}")
    print(f"wrote {TREE_PATH}")


if __name__ == "__main__":
    main()
