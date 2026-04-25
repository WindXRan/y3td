#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path


MAP_ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = Path(__file__).resolve().parent
CONVERTER = Path(r"C:\Users\裴浩然\.codex\skills\y3-ui-generator\scripts\html_to_y3_ui.py")

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

    print(f"[OK] built {output_path}")


def main():
    for html_path, output_path, panel_name, zorder in PANELS:
        build_panel(html_path, output_path, panel_name, zorder)


if __name__ == "__main__":
    main()
