#!/usr/bin/env python3
import copy
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path


MAP_ROOT = Path(__file__).resolve().parents[2]
HTML_PATH = Path(__file__).with_name("top_best_preview_y3.html")
TOP_JSON = MAP_ROOT / "ui" / "top.json"
PANEL_TREE_INFO_PATH = MAP_ROOT / "editor" / "uipaneltreegroupinfo.json"
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


def find_child_or_none(node, name):
    for child in node.get("children", []):
        if child.get("name") == name:
            return child
    return None


def fresh_uid():
    return str(uuid.uuid4())


def reassign_uids(node):
    node["uid"] = fresh_uid()
    for child in node.get("children", []):
        reassign_uids(child)


def set_pos(node, x, y, parent_width=None, parent_height=None):
    pos_data = node.get("pos_data")
    if not isinstance(pos_data, dict):
        return
    items = pos_data.get("items", [])
    if len(items) < 4:
        return
    items[0] = float(x)
    items[1] = float(y)
    if parent_width and parent_height:
        items[2] = round((float(x) / float(parent_width)) * 100, 4)
        items[3] = round((float(y) / float(parent_height)) * 100, 4)


def set_size(node, width, height):
    node["size"] = [float(width), float(height)]


def set_adapter_offsets(node, top, bottom, left, right):
    adapter = node.get("adapter_option")
    if not isinstance(adapter, list) or len(adapter) < 8:
        adapter = [False, False, False, False, 0.0, 0.0, 0.0, 0.0]
        node["adapter_option"] = adapter
        node["open_adapter"] = True
    adapter[4] = float(top)
    adapter[5] = float(bottom)
    adapter[6] = float(left)
    adapter[7] = float(right)


def set_color(node, rgba):
    if not isinstance(node, dict):
        return
    if "color" in node:
        node["color"] = list(rgba)


def set_font_color(node, rgba):
    if not isinstance(node, dict):
        return
    if "font_color" in node:
        node["font_color"] = list(rgba)


def set_font_size(node, size):
    if not isinstance(node, dict):
        return
    font = node.get("font")
    if isinstance(font, dict):
        items = font.get("items", [])
        if len(items) >= 2:
            items[1] = size


def set_label_text(node, label):
    if not isinstance(node, dict):
        return
    text = node.get("text")
    if isinstance(text, dict):
        items = text.get("items", [])
        if items:
            items[0] = label


def set_button_label(node, label):
    for key in ("normal_text", "disabled_text", "press_text", "suspend_text"):
        text = node.get(key)
        if isinstance(text, dict):
            items = text.get("items", [])
            if items:
                items[0] = label


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


def patch_top_style(panel):
    top_root = find_child(panel, "top")
    top_root_height = float(top_root["size"][1])
    top_root_width = float(top_root["size"][0])

    top_bg = find_child(top_root, "top_bg")
    left_strip = find_child(top_root, "left_strip")
    rail_glow = find_child(top_root, "rail_glow")
    rail_glow_gold = find_child_or_none(top_root, "rail_glow_gold")
    top_line = find_child(top_root, "top_line")
    scoreboard = find_child(top_root, "scoreboard")
    scoreboard_bg = find_child(scoreboard, "scoreboard_bg")
    scoreboard_title = find_child(scoreboard, "title")
    scoreboard_shadow = find_child_or_none(scoreboard, "shadow")
    scoreboard_shadow_bg = find_child_or_none(scoreboard_shadow, "shadow_bg") if scoreboard_shadow else None
    scoreboard_header = find_child_or_none(scoreboard, "header_bar")
    scoreboard_body = find_child_or_none(scoreboard, "bg")
    scoreboard_body_bg = find_child_or_none(scoreboard_body, "bg_bg") if scoreboard_body else None
    gold_panel = find_child(top_root, "金币")
    wood_panel = find_child(top_root, "木材")
    pop_panel = find_child(top_root, "人口")
    tophud = find_child(panel, "tophud")
    layout_2 = find_child(tophud, "layout_2")
    tophud_bg = find_child(tophud, "tophud_bg")
    layout_2_bg = find_child(layout_2, "layout_2_bg")

    set_size(top_bg, top_root_width, top_root_height)
    set_color(top_bg, [5, 12, 19, 221])

    set_size(left_strip, top_root_width, 64)
    set_pos(left_strip, top_root_width / 2, 204, top_root_width, top_root_height)
    set_adapter_offsets(left_strip, 0, top_root_height - 64, 0, 0)
    set_color(left_strip, [18, 32, 49, 240])

    set_size(rail_glow, 1360, 64)
    set_pos(rail_glow, top_root_width / 2, 204, top_root_width, top_root_height)
    set_adapter_offsets(rail_glow, 0, top_root_height - 64, 280, 280)
    set_color(rail_glow, [78, 116, 166, 51])

    if rail_glow_gold is not None:
        set_size(rail_glow_gold, 800, 64)
        set_pos(rail_glow_gold, top_root_width / 2, 204, top_root_width, top_root_height)
        set_adapter_offsets(rail_glow_gold, 0, top_root_height - 64, 560, 560)
        set_color(rail_glow_gold, [199, 155, 74, 34])

    set_size(top_line, 1544, 1)
    set_pos(top_line, top_root_width / 2, 146.5, top_root_width, top_root_height)
    set_adapter_offsets(top_line, 89, 146, 188, 188)
    set_color(top_line, [116, 170, 232, 158])

    set_color(scoreboard_bg, [9, 18, 26, 230])
    set_color(scoreboard_shadow, [10, 16, 23, 216])
    set_color(scoreboard_shadow_bg, [10, 16, 23, 216])
    set_color(scoreboard_header, [43, 73, 112, 214])
    set_color(scoreboard_body, [16, 25, 37, 217])
    set_color(scoreboard_body_bg, [16, 25, 37, 217])
    set_font_color(scoreboard_title, [238, 245, 255, 255])

    for panel_node in (gold_panel, wood_panel, pop_panel):
        card_bg = find_child(panel_node, "card_bg")
        set_color(card_bg, [39, 53, 71, 236])

    set_size(tophud, 468, 80)
    set_adapter_offsets(tophud, 10, 990, 726, 726)
    set_size(layout_2, 468, 80)
    set_color(tophud_bg, [7, 12, 18, 239])
    set_color(layout_2_bg, [10, 18, 27, 230])
    set_color(find_child(layout_2, "center_shadow"), [8, 14, 20, 232])
    set_color(find_child(layout_2, "phase_bg"), [42, 73, 108, 148])
    set_color(find_child(layout_2, "wave_chip_bg"), [17, 27, 39, 148])
    set_color(find_child(layout_2, "timer_core_bg"), [19, 31, 45, 242])
    set_color(find_child(layout_2, "threat_chip_bg"), [17, 27, 39, 148])
    set_color(find_child_or_none(layout_2, "center_rim"), [213, 175, 105, 255])
    set_color(find_child_or_none(layout_2, "mode_icon"), [255, 213, 125, 255])
    set_font_color(find_child(layout_2, "gametime"), [255, 224, 155, 255])
    set_font_size(find_child(layout_2, "curlevel"), 14)
    set_font_size(find_child(layout_2, "curlevel_sub"), 10)
    set_font_size(find_child(layout_2, "phase_text"), 10)
    set_font_size(find_child(layout_2, "wave"), 14)
    set_font_size(find_child(layout_2, "threat_text"), 12)


def patch_left_buttons(panel):
    top_root = find_child(panel, "top")
    left_buttons = find_child(top_root, "left_buttons")
    left_buttons_bg = find_child(left_buttons, "left_buttons_bg")
    scoreboard_title = find_child(find_child(top_root, "scoreboard"), "title")
    btn_exit = find_child(left_buttons, "btn_exit")
    btn_pause = find_child(left_buttons, "btn_pause")
    btn_setting = find_child(left_buttons, "btn_setting")
    btn_powerup = find_child(left_buttons, "btn_powerup")
    btn_hotkey = find_child(left_buttons, "btn_hotkey")

    parent_width = 648
    parent_height = 56
    top_root_width = float(top_root["size"][0])
    top_root_height = float(top_root["size"][1])

    set_size(left_buttons, parent_width, parent_height)
    set_pos(left_buttons, 396, 196, top_root_width, top_root_height)
    set_adapter_offsets(left_buttons, 12, 168, 72, 1200)

    brand_mark = find_child_or_none(left_buttons, "brand_mark")
    if brand_mark is None:
        brand_mark = {
            "adapter_option": [False, False, False, False, 1.0, 1.0, 0.0, 594.0],
            "children": [],
            "clip_enabled": False,
            "clipping_type": 1,
            "event_list": [],
            "name": "brand_mark",
            "open_adapter": True,
            "pos_data": {"__tuple__": True, "items": [27.0, 28.0, 4.1667, 50.0, 1, 1]},
            "prefab_sub_key": None,
            "scene_ui_name": None,
            "size": [54.0, 54.0],
            "type": 7,
            "uid": fresh_uid(),
            "visible": True,
        }
    set_size(brand_mark, 54, 54)
    set_pos(brand_mark, 27, 28, parent_width, parent_height)
    set_adapter_offsets(brand_mark, 1, 1, 0, 594)

    brand_mark_bg = find_child_or_none(brand_mark, "brand_mark_bg")
    if brand_mark_bg is None:
        brand_mark_bg = copy.deepcopy(left_buttons_bg)
        reassign_uids(brand_mark_bg)
        brand_mark_bg["name"] = "brand_mark_bg"
    brand_mark_bg["image"] = 131998
    brand_mark_bg["is_scale9_enable"] = True
    set_size(brand_mark_bg, 54, 54)
    set_pos(brand_mark_bg, 27, 27, 54, 54)
    set_adapter_offsets(brand_mark_bg, 0, 0, 0, 0)
    set_color(brand_mark_bg, [17, 26, 38, 246])

    brand_mark_glow = find_child_or_none(brand_mark, "brand_mark_glow")
    if brand_mark_glow is None:
        brand_mark_glow = copy.deepcopy(brand_mark_bg)
        reassign_uids(brand_mark_glow)
        brand_mark_glow["name"] = "brand_mark_glow"
    brand_mark_glow["image"] = 100062
    brand_mark_glow["is_scale9_enable"] = True
    set_size(brand_mark_glow, 38, 38)
    set_pos(brand_mark_glow, 27, 27, 54, 54)
    set_adapter_offsets(brand_mark_glow, 8, 8, 8, 8)
    set_color(brand_mark_glow, [255, 214, 126, 31])

    brand_mark_text = find_child_or_none(brand_mark, "brand_mark_text")
    if brand_mark_text is None:
        brand_mark_text = copy.deepcopy(scoreboard_title)
        reassign_uids(brand_mark_text)
        brand_mark_text["name"] = "brand_mark_text"
    set_size(brand_mark_text, 54, 54)
    set_pos(brand_mark_text, 27, 27, 54, 54)
    set_adapter_offsets(brand_mark_text, 0, 0, 0, 0)
    set_font_size(brand_mark_text, 20)
    set_font_color(brand_mark_text, [255, 228, 164, 255])
    set_label_text(brand_mark_text, "Y3")
    brand_mark["children"] = [brand_mark_bg, brand_mark_glow, brand_mark_text]

    set_size(left_buttons_bg, 582, parent_height)
    set_pos(left_buttons_bg, 357, 28, parent_width, parent_height)
    set_adapter_offsets(left_buttons_bg, 0, 0, 66, 0)
    set_color(left_buttons_bg, [7, 13, 20, 217])

    btn_save = find_child_or_none(left_buttons, "btn_save")
    if btn_save is None:
        btn_save = copy.deepcopy(btn_powerup)
        reassign_uids(btn_save)
        btn_save["name"] = "btn_save"
        btn_save["event_list"] = []

    button_specs = [
        ("btn_exit", btn_exit, "退出", 78, 84, 903408, [255, 228, 164, 255]),
        ("btn_pause", btn_pause, "暂停", 172, 84, 108210, [255, 211, 185, 255]),
        ("btn_setting", btn_setting, "设置", 268, 88, 133776, [220, 235, 255, 255]),
        ("btn_save", btn_save, "存档", 366, 88, 107030, [255, 226, 160, 255]),
        ("btn_powerup", btn_powerup, "强化", 464, 88, 106504, [255, 233, 168, 255]),
        ("btn_hotkey", btn_hotkey, "键位", 560, 84, 107030, [223, 232, 255, 255]),
    ]
    for name, node, label, left, width, icon_image, icon_color in button_specs:
        node["name"] = name
        set_button_label(node, label)
        set_size(node, width, 40)
        set_pos(node, left + (width / 2), 28, parent_width, parent_height)
        set_adapter_offsets(node, 8, 8, left, parent_width - left - width)
        set_font_size(node, 15)
        node["normal_picture"] = 134242808
        node["press_picture"] = 134242808
        node["disabled_picture"] = 134242808
        node["suspend_picture"] = 134242808
        node["hover_status_added"] = True
        node["disabled_status_added"] = True
        node["pressed_status_added"] = True

        icon = find_child_or_none(node, "icon")
        if icon is not None:
            icon["image"] = icon_image
            set_size(icon, 16, 16)
            set_pos(icon, 19, 20, width, 40)
            set_adapter_offsets(icon, 12, 12, 11, width - 27)
            set_color(icon, icon_color)

    left_buttons["children"] = [
        left_buttons_bg,
        brand_mark,
        btn_exit,
        btn_pause,
        btn_setting,
        btn_save,
        btn_powerup,
        btn_hotkey,
    ]


def ensure_registered(panel_uid):
    with PANEL_TREE_INFO_PATH.open("r", encoding="utf-8") as f:
        info = json.load(f)

    custom = next(item for item in info if item["name"] == "code_ui_custom_panel_tree")
    custom["group"] = [
        entry for entry in custom["group"]
        if not (isinstance(entry, dict) and entry.get("__tuple__") and entry["items"][1] == "top")
    ]
    custom["group"].append({"__tuple__": True, "items": [panel_uid, "top"]})

    with PANEL_TREE_INFO_PATH.open("w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
        f.write("\n")


def write_panel(panel):
    with TOP_JSON.open("w", encoding="utf-8") as f:
        json.dump(panel, f, ensure_ascii=False, indent=4)
        f.write("\n")


def has_expected_left_buttons(panel):
    try:
        top_root = find_child(panel, "top")
        left_buttons = find_child(top_root, "left_buttons")
    except KeyError:
        return False
    expected = [
        "left_buttons_bg",
        "brand_mark",
        "btn_exit",
        "btn_pause",
        "btn_setting",
        "btn_save",
        "btn_powerup",
        "btn_hotkey",
    ]
    actual = [child.get("name") for child in left_buttons.get("children", [])]
    return actual == expected


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
    patch_top_style(panel)
    patch_left_buttons(panel)

    write_panel(panel)

    with TOP_JSON.open("r", encoding="utf-8") as f:
        persisted_panel = json.load(f)
    if not has_expected_left_buttons(persisted_panel):
        patch_events(persisted_panel)
        patch_top_style(persisted_panel)
        patch_left_buttons(persisted_panel)
        write_panel(persisted_panel)

    ensure_registered(panel["uid"])

    print(f"[OK] built {TOP_JSON}")


if __name__ == "__main__":
    main()
