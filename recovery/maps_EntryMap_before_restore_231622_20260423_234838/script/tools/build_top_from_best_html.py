#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path


MAP_ROOT = Path(__file__).resolve().parents[2]
HTML_PATH = Path(__file__).with_name("top_best_preview_y3.html")
TOP_JSON = MAP_ROOT / "ui" / "top.json"
CONVERTER = Path(r"C:\Users\裴浩然\.codex\skills\y3-ui-generator\scripts\html_to_y3_ui.py")

SETTING_PANEL_UID = "54182739-d294-4dbd-9d3e-6800c3becd7d"
EXIT_PANEL_UID = "a06c0e95-daa5-4976-9d46-d3e9ebd1db0f"


def walk(node):
    yield node
    for child in node.get("children", []):
        yield from walk(child)


def find_child(node, name):
    for child in node.get("children", []):
        if child.get("name") == name:
            return child
    raise KeyError(f"missing child: {name}")


def patch_fonts(panel):
    for node in walk(panel):
        if node.get("type") == 3 and isinstance(node.get("font"), dict):
            items = node["font"].get("items", [])
            if items and not items[0]:
                items[0] = "MSYH"


def hide_extra_nodes(panel):
    top_root = find_child(panel, "top")
    system_notice = find_child(top_root, "system_notice")
    system_notice["visible"] = False

    hidden_names = {"curlevel_sub", "phase_bg", "phase_text", "wave_chip_bg", "timer_core_bg", "threat_chip_bg", "threat_text", "top_line", "rail_glow", "top_bg", "scoreboard_bg", "system_notice_bg", "main_bar_bg", "reward_bar_bg", "title_chip_bg", "tophud_bg", "layout_2_bg", "left_buttons_bg", "image_3_bg"}
    for node in walk(panel):
        if node.get("name") in hidden_names and node.get("name").endswith("_bg"):
            # keep generated bg nodes visible; only list items explicitly intended to stay.
            continue


def patch_events(panel):
    patch_fonts(panel)
    top_root = find_child(panel, "top")
    left_buttons = find_child(top_root, "left_buttons")
    btn_exit = find_child(left_buttons, "btn_exit")
    btn_setting = find_child(left_buttons, "btn_setting")
    system_notice = find_child(top_root, "system_notice")

    btn_exit["event_list"] = [
        {
            "action_list": [
                {
                    "anim_duration": 1.0,
                    "anim_id": None,
                    "anim_type": 0,
                    "comp": EXIT_PANEL_UID,
                    "ease_type": 0,
                    "name": "BackToHall_66",
                    "open_timeline": True,
                    "type": 5,
                }
            ],
            "enabled": True,
            "name": "top_exit_btn_0",
            "not_wait_network": False,
            "sound_id": None,
            "type": 1,
        }
    ]

    btn_setting["event_list"] = [
        {
            "action_list": [
                {
                    "anim_duration": 1.0,
                    "anim_id": None,
                    "anim_type": 0,
                    "comp": SETTING_PANEL_UID,
                    "ease_type": 0,
                    "name": "Show_66",
                    "open_timeline": True,
                    "type": 2,
                }
            ],
            "enabled": True,
            "name": "top_setting_btn_0",
            "not_wait_network": False,
            "sound_id": None,
            "type": 1,
        }
    ]

    system_notice["visible"] = False
    panel["zorder"] = 405


def main():
    env = dict(os.environ)
    env["PYTHONIOENCODING"] = "utf-8"
    subprocess.run(
        [
            sys.executable,
            str(CONVERTER),
            str(HTML_PATH),
            str(TOP_JSON),
            "--panel-name",
            "top",
            "--zorder",
            "405",
        ],
        check=True,
        env=env,
    )

    with TOP_JSON.open("r", encoding="utf-8") as f:
        panel = json.load(f)

    patch_events(panel)

    with TOP_JSON.open("w", encoding="utf-8") as f:
        json.dump(panel, f, ensure_ascii=False, indent=4)
        f.write("\n")

    print(f"[OK] built {TOP_JSON}")


if __name__ == "__main__":
    main()
