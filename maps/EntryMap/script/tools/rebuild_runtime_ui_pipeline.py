#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import shutil
import subprocess
import sys
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TOOLS_DIR = ROOT / "maps" / "EntryMap" / "script" / "tools"
UI_DIR = ROOT / "maps" / "EntryMap" / "ui"
TREE_DIR = ROOT / "maps" / "EntryMap" / "ui_tree"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"
CONVERTER = Path(r"C:\Users\裴浩然\.codex\skills\y3-ui-generator\scripts\html_to_y3_ui.py")
TREE_GENERATOR = Path(r"C:\Users\裴浩然\.codex\skills\y3-ui-pipeline\gen_ui_tree.py")

PANELS = [
    ("battle_bottom_hud_preview_y3.html", "BattleBottomHUD.json", "BattleBottomHUD", 410),
    ("bond_choice_2_preview_y3.html", "BondChoice2.json", "BondChoice2", 520),
    ("bond_choice_3_preview_y3.html", "BondChoice3.json", "BondChoice3", 520),
    ("bond_choice_4_preview_y3.html", "BondChoice4.json", "BondChoice4", 520),
]


def walk(node):
    yield node
    for child in node.get("children", []):
        yield from walk(child)


def find_child(parent, name):
    for child in parent.get("children", []):
        if child.get("name") == name:
            return child
    return None


def tuple_value(*items):
    return {"__tuple__": True, "items": list(items)}


def make_layout(name, x, y, width, height, children=None, color=None):
    node = {
        "children": children or [],
        "event_list": [],
        "name": name,
        "pos_data": tuple_value(float(x), float(y), 50.0, 50.0, 1, 1),
        "prefab_sub_key": None,
        "scene_ui_name": None,
        "size": [width, height],
        "type": 7,
        "uid": str(uuid.uuid4()),
    }
    if color is not None:
        node["color"] = tuple_value(*color)
    return node


def make_image(name, x, y, width, height, image=None, color=None, scale9=False, cap_insets=None):
    node = {
        "children": [],
        "event_list": [],
        "name": name,
        "pos_data": tuple_value(float(x) + width / 2.0, float(y) + height / 2.0, 50.0, 50.0, 1, 1),
        "prefab_sub_key": None,
        "scene_ui_name": None,
        "size": [width, height],
        "type": 4,
        "uid": str(uuid.uuid4()),
    }
    if image is not None:
        node["image"] = image
    if color is not None:
        node["color"] = color if isinstance(color, list) else tuple_value(*color)
    if scale9:
        node["is_scale9_enable"] = True
        node["cap_insets"] = cap_insets or [18, 18, 18, 18]
    return node


def make_label(name, x, y, width, height, text="", font_size=12, color=None, align=(1, 8)):
    node = {
        "children": [],
        "event_list": [],
        "font": tuple_value("MSYH", font_size),
        "font_min_size": max(10, min(font_size, 14)),
        "name": name,
        "over_pattern": True,
        "pos_data": tuple_value(float(x) + width / 2.0, float(y) + height / 2.0, 50.0, 50.0, 1, 1),
        "prefab_sub_key": None,
        "scene_ui_name": None,
        "size": tuple_value(width, float(height)),
        "text": tuple_value(text, False),
        "type": 3,
        "uid": str(uuid.uuid4()),
    }
    if color is not None:
        node["font_color"] = color if isinstance(color, dict) else tuple_value(*color)
    if align is not None:
        node["alignment"] = tuple_value(*align)
    return node


def make_model(name, x, y, width, height):
    return {
        "anchor": tuple_value(0.5, 0.5),
        "children": [],
        "event_list": [],
        "name": name,
        "pos_data": tuple_value(float(x) + width / 2.0, float(y) + height / 2.0, 50.0, 50.0, 1, 1),
        "prefab_sub_key": None,
        "scene_ui_name": None,
        "size": [width, height],
        "type": 6,
        "uid": str(uuid.uuid4()),
    }


def upsert_child(parent, node, before_name=None):
    children = [child for child in parent.get("children", []) if child.get("name") != node.get("name")]
    insert_at = len(children)
    if before_name:
        for index, child in enumerate(children):
            if child.get("name") == before_name:
                insert_at = index
                break
    children.insert(insert_at, node)
    parent["children"] = children


def remove_children(parent, names):
    removed = set(names)
    parent["children"] = [child for child in parent.get("children", []) if child.get("name") not in removed]


def patch_choice_panel(panel):
    root = panel["children"][0]
    for node in walk(panel):
        if node.get("type") == 1:
            node["swallow_touches"] = True
        if node.get("name") == "dim_bg":
            node["swallow_touches"] = True
        if node.get("name") in {"bond_choice_2_bg", "bond_choice_3_bg", "bond_choice_4_bg"}:
            node["visible"] = False
    root["visible"] = True


def patch_battle_bottom_hud(panel):
    for node in walk(panel):
        if node.get("name") == "hero_name":
            node["alignment"] = {"__tuple__": True, "items": [1, 8]}
        if node.get("name") == "hero_model":
            node["type"] = 6
            node.pop("image", None)
            node["anchor"] = {"__tuple__": True, "items": [0.5, 0.5]}
        if node.get("name") == "mini_map_1":
            node["type"] = 16
            node.pop("image", None)
            node["anchor"] = {"__tuple__": True, "items": [0.5, 0.5]}
        if node.get("name") == "icon":
            parent_name = node.get("__parent_name__")
            if parent_name and (
                parent_name.startswith("loadout_slot_")
                or parent_name.startswith("card_slot_")
                or parent_name.startswith("buff_slot_")
                or parent_name in {"slot_1", "slot_2", "slot_3"}
            ):
                node["image"] = None

    layout = panel["children"][0]
    center_hub = find_child(layout, "center_hub")
    right_station = find_child(layout, "right_station")
    if center_hub is None or right_station is None:
        return

    hero_panel = find_child(center_hub, "hero_panel")
    combat_module = find_child(center_hub, "combat_module")
    if hero_panel is not None:
        if find_child(hero_panel, "hero_model") is None:
            upsert_child(hero_panel, make_model("hero_model", 41, 28, 102, 112), before_name="hero_name")
        if find_child(hero_panel, "panel_glow") is None:
            upsert_child(
                hero_panel,
                make_image("panel_glow", 16, 12, 152, 186, image=100062, color=[95, 134, 181, 26], scale9=True),
                before_name="portrait_frame",
            )
        if find_child(hero_panel, "hero_name_line") is None:
            upsert_child(hero_panel, make_image("hero_name_line", 28, 166, 128, 1, image=999, color=[255, 255, 255, 106]), before_name="hero_name")

    if combat_module is not None:
        remove_children(combat_module, {"challenge_row", "growth_weapon_slot", "hero_level"})
        panel_bg = find_child(combat_module, "panel_bg")
        if panel_bg is not None:
            panel_bg["name"] = "combat_module_bg"
            panel_bg["image"] = 131998
            panel_bg["color"] = tuple_value(18, 26, 36, 168)
            panel_bg["is_scale9_enable"] = True
            panel_bg["cap_insets"] = [18, 18, 18, 18]
        if find_child(combat_module, "module_line") is None:
            upsert_child(combat_module, make_image("module_line", 6, 206, 388, 1, image=999, color=[134, 166, 196, 82]))

    if find_child(right_station, "hover_tip_panel") is None:
        hover_tip_panel = make_layout(
            "hover_tip_panel",
            -356,
            -200,
            340,
            180,
            children=[
                make_image("bg", 0, 0, 340, 180, image=131998, color=[12, 18, 25, 240], scale9=True),
                make_image("inner", 8, 8, 324, 164, image=100062, color=[27, 38, 52, 212], scale9=True),
                make_image("header", 12, 12, 316, 28, image=100062, color=[46, 60, 78, 224], scale9=True),
                make_image("icon_bg", 14, 50, 58, 58, image=134257674),
                make_image("icon", 21, 57, 44, 44, image=999),
                make_label("title", 82, 16, 226, 20, text="提示标题", font_size=16, color=[204, 226, 255, 255], align=(0, 8)),
                make_label("subtitle", 82, 42, 226, 18, text="副标题", font_size=13, color=[255, 213, 96, 255], align=(0, 8)),
                make_label("body", 82, 64, 236, 96, text="说明内容", font_size=14, color=[222, 232, 244, 255], align=(0, 0)),
            ],
        )
        right_station["children"].append(hover_tip_panel)

    if find_child(right_station, "tip_panel") is None:
        tip_panel = make_layout(
            "tip_panel",
            -436,
            -192,
            420,
            180,
            children=[
                make_image("bg", 0, 0, 420, 180, image=131998, color=[12, 18, 25, 240], scale9=True),
                make_image("inner", 8, 8, 404, 164, image=100062, color=[27, 38, 52, 212], scale9=True),
                make_image("header", 12, 12, 396, 28, image=100062, color=[46, 60, 78, 224], scale9=True),
                make_label("title", 18, 16, 240, 18, text="系统提示", font_size=16, color=[204, 226, 255, 255], align=(0, 8)),
                make_label("hint", 280, 16, 120, 18, text="点击关闭", font_size=12, color=[166, 187, 214, 255], align=(1, 8)),
                make_label("body", 18, 52, 384, 108, text="说明内容", font_size=14, color=[222, 232, 244, 255], align=(0, 0)),
            ],
        )
        right_station["children"].append(tip_panel)

    if find_child(right_station, "attr_panel") is None:
        attr_panel = make_layout(
            "attr_panel",
            -436,
            -386,
            420,
            210,
            children=[
                make_image("bg", 0, 0, 420, 210, image=131998, color=[12, 18, 25, 240], scale9=True),
                make_image("inner", 8, 8, 404, 194, image=100062, color=[27, 38, 52, 212], scale9=True),
                make_image("header", 12, 12, 396, 28, image=100062, color=[46, 60, 78, 224], scale9=True),
                make_label("title", 18, 16, 240, 18, text="属性总览", font_size=16, color=[204, 226, 255, 255], align=(0, 8)),
                make_label("hint", 280, 16, 120, 18, text="点击关闭", font_size=12, color=[166, 187, 214, 255], align=(1, 8)),
                make_label("body", 18, 52, 384, 120, text="属性说明", font_size=14, color=[222, 232, 244, 255], align=(0, 0)),
            ],
        )
        right_station["children"].append(attr_panel)


def attach_parent_names(node, parent_name=None):
    node["__parent_name__"] = parent_name
    for child in node.get("children", []):
        attach_parent_names(child, node.get("name"))


def strip_parent_names(node):
    node.pop("__parent_name__", None)
    for child in node.get("children", []):
        strip_parent_names(child)


def update_panel_registration(panel_names):
    data = json.loads(PANEL_TREE_INFO_PATH.read_text(encoding="utf-8"))
    custom_group = None
    for entry in data:
        if entry.get("name") == "code_ui_custom_panel_tree":
            custom_group = entry
            break
    if custom_group is None:
        custom_group = {"name": "code_ui_custom_panel_tree", "key": 2147483647, "group": []}
        data.insert(0, custom_group)

    uid_by_name = {}
    for panel_name in panel_names:
        panel_path = UI_DIR / f"{panel_name}.json"
        panel = json.loads(panel_path.read_text(encoding="utf-8"))
        uid_by_name[panel_name] = panel["uid"]

    kept = []
    for item in custom_group.get("group", []):
        name = None
        if isinstance(item, dict) and item.get("__tuple__") is True:
            items = item.get("items", [])
            if len(items) >= 2:
                name = items[1]
        if name not in uid_by_name:
            kept.append(item)
    for panel_name in panel_names:
        kept.append({"__tuple__": True, "items": [uid_by_name[panel_name], panel_name]})
    custom_group["group"] = kept

    PANEL_TREE_INFO_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def build_panel(html_name, output_name, panel_name, zorder):
    html_path = TOOLS_DIR / html_name
    output_path = UI_DIR / output_name
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"
    subprocess.run(
        [sys.executable, str(CONVERTER), str(html_path), str(output_path), "--panel-name", panel_name, "--zorder", str(zorder)],
        check=True,
        env=env,
    )

    panel = json.loads(output_path.read_text(encoding="utf-8"))
    attach_parent_names(panel)
    if panel_name == "BattleBottomHUD":
        patch_battle_bottom_hud(panel)
    else:
        patch_choice_panel(panel)
    strip_parent_names(panel)
    output_path.write_text(json.dumps(panel, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    print(f"[OK] built {output_path}")


def sync_trees(panel_names):
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"
    subprocess.run([sys.executable, str(TREE_GENERATOR), str(ROOT)], check=True, env=env)
    root_tree_dir = ROOT / "ui_tree"
    TREE_DIR.mkdir(parents=True, exist_ok=True)
    for panel_name in panel_names:
        src = root_tree_dir / f"{panel_name}_Tree.json"
        dst = TREE_DIR / f"{panel_name}_Tree.json"
        shutil.copyfile(src, dst)
        print(f"[OK] synced {dst}")


def main():
    panel_names = []
    for html_name, output_name, panel_name, zorder in PANELS:
        build_panel(html_name, output_name, panel_name, zorder)
        panel_names.append(panel_name)
    sync_trees(panel_names)
    update_panel_registration(panel_names)
    print("[OK] pipeline rebuild finished")


if __name__ == "__main__":
    main()
