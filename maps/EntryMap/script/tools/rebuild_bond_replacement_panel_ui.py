#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TOOLS_DIR = ROOT / "maps" / "EntryMap" / "script" / "tools"
UI_PATH = ROOT / "maps" / "EntryMap" / "ui" / "BondReplacementPanel.json"
TREE_PATH = ROOT / "maps" / "EntryMap" / "ui_tree" / "BondReplacementPanel_Tree.json"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"

spec = importlib.util.spec_from_file_location("builder", TOOLS_DIR / "rebuild_battle_bottom_hud_ui.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

BG_BLACK = builder.BG_BLACK
SHOP_BG = builder.SHOP_BG
SHOP_CONTENT_BG = builder.SHOP_CONTENT_BG
SHOP_LINE = builder.SHOP_LINE
BUTTON_BLUE = builder.BUTTON_BLUE
BUTTON_BLUE_HOV = builder.BUTTON_BLUE_HOV
BUTTON_BLUE_DWN = builder.BUTTON_BLUE_DWN
BUTTON_ACTION_GOLD = builder.BUTTON_ACTION_GOLD
BUTTON_ACTION_GOLD_HOV = builder.BUTTON_ACTION_GOLD_HOV
BUTTON_ACTION_GOLD_DWN = builder.BUTTON_ACTION_GOLD_DWN
SKILL_SMALL_EMPTY = builder.SKILL_SMALL_EMPTY


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


def build_bond_option(option_index):
    option_panel = panel(f"option_{option_index}", 280, 470 - (option_index - 1) * 110, 520, 100, [15, 18, 26, 220])
    option_panel["children"] = [
        image(f"option_bg_{option_index}", 260, 50, 520, 100, SHOP_CONTENT_BG, [255, 255, 255, 200], True),
        image(f"option_icon_bg_{option_index}", 60, 50, 80, 80, SKILL_SMALL_EMPTY, [255, 255, 255, 255], True),
        image(f"option_icon_{option_index}", 60, 50, 70, 70, 100000, [255, 255, 255, 255], False),
        text(f"option_name_{option_index}", 280, 50, 300, 36, f"羁绊 {option_index}", 22, [255, 228, 88, 255], 0),
        text(f"option_desc_{option_index}", 280, 15, 300, 24, "点击替换", 16, [180, 200, 230, 255], 0),
    ]
    return option_panel


def build_panel():
    root = {
        "adapt_mode": 2,
        "anim_data": {},
        "auto_create": True,
        "children": [],
        "name": "BondReplacementPanel",
        "opacity": 1.0,
        "script_name": "",
        "type": 2,
        "ui_anims": [],
        "uid": uid(),
        "visible": False,
        "zorder": 9580,
    }

    canvas = fullscreen_layout("layout")
    canvas["children"] = [
        image("dim_bg", 960, 540, 1920, 1080, BG_BLACK, [0, 0, 0, 120], True),
    ]

    main = panel("main_frame", 960, 540, 760, 860, [12, 16, 24, 245])
    main["children"] = [
        image("frame_bg", 380, 430, 760, 860, SHOP_BG, [255, 255, 255, 240], True),
        image("frame_inner", 380, 430, 720, 820, BG_BLACK, [255, 255, 255, 210], True),
        image("top_bevel", 380, 825, 690, 4, SHOP_LINE, [255, 220, 105, 185], True),
        text("title_text", 150, 795, 460, 40, "选择要替换的羁绊", 26, [255, 226, 78, 255], 1),
        text("desc_text", 380, 740, 680, 60, "羁绊已满，请选择要替换的羁绊：\n新羁绊：未知", 18, [230, 240, 255, 255], 1),
    ]

    options = []
    for i in range(1, 9):
        option = build_bond_option(i)
        options.append(option)
    main["children"].extend(options)

    cancel_btn = button(
        "cancel_btn",
        380,
        70,
        180,
        56,
        "取消",
        normal_picture=BUTTON_BLUE,
        suspend_picture=BUTTON_BLUE_HOV,
        press_picture=BUTTON_BLUE_DWN,
        disabled_picture=BUTTON_BLUE,
        font_size=22,
    )
    main["children"].append(cancel_btn)

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
