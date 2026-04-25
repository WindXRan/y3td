#!/usr/bin/env python3
import copy
import json
import os
import subprocess
import sys
from pathlib import Path


MAP_ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = Path(__file__).resolve().parent
CONVERTER = Path(r"C:\Users\裴浩然\.codex\skills\y3-ui-generator\scripts\html_to_y3_ui.py")
TREE_DIR = MAP_ROOT / "ui_tree"
PANEL_TREE_INFO_PATH = MAP_ROOT / "editor" / "uipaneltreegroupinfo.json"

PANELS = [
    (
        TOOLS_DIR / "bond_choice_3_preview_y3.html",
        MAP_ROOT / "ui" / "BondChoice3.json",
        "BondChoice3",
        520,
    ),
    (
        TOOLS_DIR / "bond_choice_4_preview_y3.html",
        MAP_ROOT / "ui" / "BondChoice4.json",
        "BondChoice4",
        520,
    ),
]


def tree_of(node):
    result = {"name": node["name"], "uid": node["uid"], "type": node["type"]}
    if node.get("children"):
        result["children"] = [tree_of(child) for child in node["children"]]
    return result


def walk(node):
    yield node
    for child in node.get("children", []):
        yield from walk(child)


def patch_panel(panel):
    panel["zorder"] = 520
    for node in walk(panel):
        if node.get("type") == 3 and isinstance(node.get("font"), dict):
            items = node["font"].get("items", [])
            if items and not items[0]:
                items[0] = "MSYH"
        if node.get("name") in {"bond_choice_3_bg", "bond_choice_4_bg"}:
            node["visible"] = False
        if node.get("name") == "dim_bg_bg":
            node["image"] = 999
            node["color"] = [5, 8, 14, 184]
            node["alpha"] = 100
        if node.get("name") == "dim_bg":
            node["swallow_touches"] = True
            node["visible"] = False
        if node.get("type") == 1:
            node["swallow_touches"] = True


def build_two_choice_panel(source_panel):
    panel = copy.deepcopy(source_panel)
    panel["name"] = "BondChoice2"
    root = panel["children"][0]
    root["name"] = "bond_choice_2"

    for child in root.get("children", []):
        if child.get("name") == "bond_choice_3_bg":
            child["name"] = "bond_choice_2_bg"
        if child.get("name") == "cards_row":
            child["children"] = [
                entry for entry in child.get("children", [])
                if entry.get("name") != "card_3"
            ]
            for entry in child["children"]:
                if entry.get("name") == "card_1":
                    entry["pos_data"]["items"][0] = 286.0
                elif entry.get("name") == "card_2":
                    entry["pos_data"]["items"][0] = 606.0

    patch_panel(panel)
    return panel


def write_tree(panel, output_path):
    TREE_DIR.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(tree_of(panel), f, ensure_ascii=False, indent=2)
        f.write("\n")


def register_panel(panel):
    panel_tree_info = json.loads(PANEL_TREE_INFO_PATH.read_text(encoding="utf-8"))
    custom_group = None
    for entry in panel_tree_info:
        if entry.get("name") == "code_ui_custom_panel_tree":
            custom_group = entry
            break

    if custom_group is None:
        custom_group = {"name": "code_ui_custom_panel_tree", "key": 2147483647, "group": []}
        panel_tree_info.insert(0, custom_group)

    panel_pair = {"__tuple__": True, "items": [panel["uid"], panel["name"]]}
    kept = []
    for item in custom_group.get("group", []):
        name = None
        if isinstance(item, dict) and item.get("__tuple__") is True:
            items = item.get("items", [])
            if len(items) >= 2:
                name = items[1]
        if name != panel["name"]:
            kept.append(item)
    kept.append(panel_pair)
    custom_group["group"] = kept

    with PANEL_TREE_INFO_PATH.open("w", encoding="utf-8") as f:
        json.dump(panel_tree_info, f, ensure_ascii=False, indent=1)
        f.write("\n")


def build_panel(html_path, output_path, panel_name, zorder):
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"
    subprocess.run(
        [
            sys.executable,
            str(CONVERTER),
            str(html_path),
            str(output_path),
            "--panel-name",
            panel_name,
            "--zorder",
            str(zorder),
        ],
        check=True,
        env=env,
    )

    with output_path.open("r", encoding="utf-8") as f:
        panel = json.load(f)

    patch_panel(panel)

    with output_path.open("w", encoding="utf-8") as f:
        json.dump(panel, f, ensure_ascii=False, indent=4)
        f.write("\n")

    write_tree(panel, TREE_DIR / f"{panel_name}_Tree.json")
    register_panel(panel)
    print(f"[OK] built {output_path}")


def main():
    for html_path, output_path, panel_name, zorder in PANELS:
        build_panel(html_path, output_path, panel_name, zorder)

    source_panel = json.loads((MAP_ROOT / "ui" / "BondChoice3.json").read_text(encoding="utf-8"))
    bond_choice_2 = build_two_choice_panel(source_panel)
    output_path = MAP_ROOT / "ui" / "BondChoice2.json"
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(bond_choice_2, f, ensure_ascii=False, indent=4)
        f.write("\n")
    write_tree(bond_choice_2, TREE_DIR / "BondChoice2_Tree.json")
    register_panel(bond_choice_2)
    print(f"[OK] built {output_path}")


if __name__ == "__main__":
    main()
