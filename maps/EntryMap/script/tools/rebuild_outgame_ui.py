#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
from pathlib import Path

from ui_node_builders import button, fullscreen_layout, image, layout, panel, text, tuple_value, uid


ROOT = Path(__file__).resolve().parents[4]
UI_PATH = ROOT / "maps" / "EntryMap" / "ui" / "outgame.json"
TREE_PATH = ROOT / "maps" / "EntryMap" / "ui_tree" / "outgame_Tree.json"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"


def build_mode_entry(name, label_text):
    root = layout(name, 170, 0, 340, 126)
    shadow = panel("shadow", 170, 60, 336, 116, [0, 0, 0, 84])
    box = panel("模式", 170, 63, 324, 112, [33, 26, 15, 244])
    outer_line = panel("outer_line", 170, 63, 320, 108, [155, 115, 45, 255])
    inner = panel("inner", 170, 63, 312, 100, [77, 56, 24, 236])
    title_band = panel("title_band", 170, 88, 232, 28, [168, 121, 36, 228])
    accent = panel("accent", 170, 26, 220, 4, [233, 191, 96, 255])
    label = text("mode", 170, 67, 240, 44, label_text, 28, [255, 242, 197, 255])
    selected = panel("selected", 170, 63, 332, 120, [74, 217, 255, 104])
    selected["visible"] = False
    box["children"] = [outer_line, inner, title_band, accent, label, selected]
    root["children"] = [shadow, box]
    return root


def build_difficulty_entry(name, label_text):
    root = layout(name, 160, 0, 320, 92)
    shadow = panel("shadow", 160, 43, 310, 86, [0, 0, 0, 72])
    box = panel("模式", 160, 46, 304, 82, [20, 22, 28, 246])
    inner = panel("inner", 160, 46, 294, 72, [43, 46, 57, 228])
    left_bar = panel("left_bar", 34, 46, 16, 72, [194, 145, 44, 255])
    right_bar = panel("right_bar", 286, 46, 6, 72, [86, 92, 104, 188])
    label = text("mode", 214, 46, 132, 42, label_text, 26, [240, 242, 248, 255])
    lock = text("lock", 74, 46, 76, 38, "锁", 26, [188, 190, 201, 255])
    selected = panel("selected", 160, 46, 312, 88, [233, 177, 22, 92])
    selected["visible"] = False
    box["children"] = [inner, left_bar, right_bar, lock, label, selected]
    root["children"] = [shadow, box]
    return root


def build_task_entry(index, center_y):
    root = layout(f"task_{index}", 172, center_y, 334, 64)
    shadow = panel("shadow", 167, 30, 334, 64, [0, 0, 0, 62])
    bg = panel("bg", 167, 32, 334, 64, [12, 57, 83, 240])
    left_bar = panel("left_bar", 10, 32, 8, 58, [84, 219, 255, 255])
    inner = panel("inner", 172, 32, 310, 52, [10, 29, 46, 246])
    title = text("title", 122, 41, 196, 20, f"任务 {index}", 15, [246, 248, 252, 255], 0)
    reward = text("reward", 112, 18, 188, 18, "奖励：待配置", 12, [255, 196, 73, 255], 0)
    progress = text("progress", 273, 42, 66, 26, "0/1", 18, [255, 255, 255, 255])
    status_bg = panel("status_bg", 287, 18, 80, 26, [123, 123, 131, 222])
    status = text("status", 287, 18, 76, 18, "未完成", 12, [245, 245, 245, 255])
    bg["children"] = [left_bar, inner]
    root["children"] = [shadow, bg, title, reward, progress, status_bg, status]
    return root


def tree_of(node):
    result = {"name": node["name"], "uid": node["uid"], "type": node["type"]}
    if node.get("children"):
        result["children"] = [tree_of(child) for child in node["children"]]
    return result


def refresh_pos_percentages(node, parent_width=None, parent_height=None):
    pos_data = node.get("pos_data")
    if isinstance(pos_data, dict) and pos_data.get("__tuple__") is True:
      items = pos_data.get("items", [])
      if len(items) >= 4 and parent_width and parent_height:
          x = float(items[0])
          y = float(items[1])
          items[2] = round((x / float(parent_width)) * 100, 4)
          items[3] = round((y / float(parent_height)) * 100, 4)

    size = node.get("size", [0, 0])
    if isinstance(size, dict) and size.get("__tuple__") is True:
        size_items = size.get("items", [0, 0])
        node_width = float(size_items[0]) if len(size_items) >= 1 else 0
        node_height = float(size_items[1]) if len(size_items) >= 2 else 0
    else:
        node_width = float(size[0]) if len(size) >= 1 else 0
        node_height = float(size[1]) if len(size) >= 2 else 0

    for child in node.get("children", []):
        refresh_pos_percentages(child, node_width, node_height)


def build_outgame():
    root = {
        "adapt_mode": 2,
        "anim_data": {},
        "auto_create": True,
        "children": [],
        "name": "outgame",
        "opacity": 1.0,
        "script_name": "",
        "type": 2,
        "ui_anims": [],
        "uid": uid(),
        "visible": True,
        "zorder": 400,
    }

    hall = fullscreen_layout("大厅")
    wrapper = fullscreen_layout("layout")

    bottom = image("底板", 960, 540, 1920, 1080, 106331, [255, 255, 255, 210], False)
    shade = panel("shade", 960, 540, 1920, 1080, [7, 10, 15, 176])
    watermark_a = panel("watermark_a", 1070, 338, 1180, 840, [255, 255, 255, 22])
    watermark_b = panel("watermark_b", 940, 680, 980, 540, [255, 255, 255, 12])

    left = panel("left", 180, 530, 356, 1000, [12, 14, 18, 246])
    left_frame = panel("frame", 180, 530, 348, 992, [25, 29, 36, 156])
    left_header = panel("header_bg", 178, 956, 342, 68, [24, 28, 34, 248])
    left_header_line = panel("header_line", 178, 930, 336, 3, [0, 188, 255, 255])
    left["children"] = [
        left_frame,
        left_header,
        text("task_title", 182, 957, 280, 46, "日常任务", 34, [43, 201, 255, 255], 0),
        left_header_line,
        build_task_entry(1, 890),
        build_task_entry(2, 830),
        build_task_entry(3, 770),
        build_task_entry(4, 710),
        build_task_entry(5, 650),
        layout("reward_group", 180, 180, 320, 148),
    ]
    reward_group = left["children"][-1]
    reward_card = panel("reward_card_bg", 160, 74, 320, 148, [18, 18, 22, 244])
    reward_card_inner = panel("reward_card_inner", 160, 74, 306, 136, [30, 31, 38, 250])
    reward_accent = panel("reward_accent", 26, 74, 8, 132, [255, 183, 32, 255])
    reward_card["children"] = [reward_card_inner]
    reward_group["children"] = [
        reward_card,
        reward_accent,
        text("reward_title", 160, 104, 250, 30, "进群领奖励", 28, [255, 255, 255, 255]),
        text("reward_code", 160, 44, 238, 38, "4群: 1102282480", 22, [255, 183, 32, 255]),
        text("reward_hint", 160, 18, 250, 22, "点击复制群号", 12, [238, 238, 238, 255]),
    ]

    left_2 = panel("left_2", 958, 585, 360, 320, [0, 0, 0, 0])
    mode_list = layout("list", 180, 160, 360, 320, [0, 0, 0, 0])
    mode_list["children"] = [
        layout("空", 180, 300, 360, 20),
        build_mode_entry("主线模式", "正常模式"),
        build_mode_entry("猎场模式", "猎场模式"),
        layout("下空", 180, 20, 360, 20),
    ]
    mode_list["children"][1]["pos_data"] = tuple_value(180, 220, 0.0, 0.0, 1, 1)
    mode_list["children"][2]["pos_data"] = tuple_value(180, 78, 0.0, 0.0, 1, 1)
    center_prompt = text("mode_prompt", 180, 308, 420, 24, "请选择你要体验的模式", 16, [225, 229, 236, 255])
    left_2["children"] = [mode_list, center_prompt]

    right = panel("right", 1704, 530, 356, 1000, [15, 16, 20, 238])
    right_frame = panel("frame", 178, 530, 348, 992, [34, 29, 22, 122])
    right_header = panel("header_bg", 178, 954, 320, 68, [32, 27, 24, 244])
    right_panel_bg = panel("panel_bg", 178, 480, 318, 820, [17, 18, 25, 216])
    right_header_line = panel("header_line", 178, 928, 308, 3, [244, 180, 56, 255])
    difficulty_list = layout("难度列表", 160, 540, 320, 760)
    mode_name = text("mode_name", 178, 955, 240, 44, "正常模式", 30, [255, 190, 24, 255])
    tips = layout("猎场模式tips", 160, 816, 290, 66)
    tips_bg = panel("tips_bg", 145, 33, 290, 66, [19, 20, 24, 224])
    tips_layout = panel("layout_2", 145, 33, 286, 62, [47, 39, 24, 212])
    tips_label = text("label_3", 145, 33, 268, 40, "当前模式为挂机模式", 18, [255, 255, 255, 255])
    tips_layout["children"] = [tips_label]
    tips["children"] = [tips_bg, tips_layout]
    mode_name["children"] = [tips]
    right["children"] = [
        right_frame,
        right_panel_bg,
        right_header,
        right_header_line,
        difficulty_list,
        mode_name,
        text("difficulty_hint", 178, 860, 280, 30, "选择难度后即可开始游戏", 15, [200, 205, 214, 255]),
    ]

    right_2 = panel("right_2", 1704, 520, 340, 860, [0, 0, 0, 0])
    difficulty_scroll = layout("list", 160, 430, 320, 780, [0, 0, 0, 0])
    difficulty_scroll["children"] = [
        layout("空", 160, 742, 320, 16),
        build_difficulty_entry("mode1", "N1"),
        build_difficulty_entry("mode2", "N2"),
        build_difficulty_entry("mode3", "N3"),
        build_difficulty_entry("mode4", "N4"),
        build_difficulty_entry("mode5", "N5"),
        build_difficulty_entry("mode6", "N6"),
        build_difficulty_entry("mode7", "N7"),
        layout("下空", 160, 18, 320, 18),
    ]
    for child, pos_y in zip(difficulty_scroll["children"][1:8], [676, 584, 492, 400, 308, 216, 124]):
        child["pos_data"] = tuple_value(160, pos_y, 0.0, 0.0, 1, 1)
    right_2["children"] = [difficulty_scroll]

    start_bg = panel("start_bg", 1706, 92, 320, 116, [155, 88, 16, 236])
    start_glow = panel("start_glow", 1706, 92, 306, 100, [221, 145, 48, 236])
    start_btn = button("start", 1706, 92, 320, 116, "开始游戏")

    footer = panel("footer", 178, 70, 340, 108, [13, 15, 20, 248])
    footer["children"] = [
        panel("top_line", 170, 103, 320, 2, [57, 137, 214, 255]),
        text("player_name", 108, 92, 260, 18, "玩家", 14, [233, 238, 243, 255], 0),
    ]
    for index, x in enumerate([44, 118, 192, 266], start=1):
        slot = panel(f"slot_{index}", x, 34, 66, 66, [6, 8, 12, 230])
        slot_shadow = panel("shadow", 33, 33, 66, 66, [0, 0, 0, 96])
        slot_frame = panel("frame", 33, 33, 64, 64, [34, 38, 48, 255])
        slot_inner = panel("inner", 33, 33, 58, 58, [8, 11, 16, 255])
        slot_avatar = image("avatar", 33, 33, 54, 54, 999, [255, 255, 255, 255], False)
        slot_avatar["visible"] = index == 1
        slot["children"] = [
            slot_shadow,
            slot_frame,
            slot_inner,
            slot_avatar,
            text("label", 33, -12, 66, 18, "主机" if index == 1 else "", 12, [224, 194, 109, 255])
        ]
        footer["children"].append(slot)

    save_anchor = layout("save_anchor", 178, 474, 320, 46)
    save_root = panel("save_root", 96, 23, 178, 40, [18, 18, 22, 236])
    save_line = panel("line", 200, 23, 2, 26, [255, 211, 84, 186])
    save_title = text("title", 40, 23, 62, 22, "存档", 14, [255, 211, 84, 255], 0)
    save_status = text("status", 128, 23, 148, 22, "当前为内存态", 13, [245, 245, 245, 255], 0)
    save_button_bg = panel("button_bg", 268, 23, 90, 34, [160, 88, 16, 238])
    save_button = button("button", 268, 23, 90, 34, "存档")
    save_anchor["children"] = [save_root, save_line, save_title, save_status, save_button_bg, save_button]

    header_tip = text("header_tip", 640, 956, 540, 42, "等待玩家挑选难度.....", 24, [255, 255, 255, 255], 0)
    quit_tip = text("quit_tip", 520, 892, 320, 32, "按 ESC 键可退出游戏", 18, [255, 255, 255, 255], 0)
    detail_title = text("detail_title", 630, 824, 380, 34, "关卡标题", 22, [255, 255, 255, 255], 0)
    detail_status = text("detail_status", 630, 788, 380, 26, "已开放", 16, [208, 220, 230, 255], 0)
    detail_hint = text("detail_hint", 934, 505, 560, 42, "当前关卡已准备完成，点击开始即可进入战斗。", 15, [190, 198, 208, 255])

    wrapper["children"] = [
        bottom,
        shade,
        watermark_a,
        watermark_b,
        left,
        left_2,
        right,
        right_2,
        start_bg,
        start_glow,
        start_btn,
        footer,
        save_anchor,
        header_tip,
        quit_tip,
        detail_title,
        detail_status,
        detail_hint,
    ]
    hall["children"] = [wrapper]
    root["children"] = [hall]
    return root


def main():
    data = build_outgame()
    refresh_pos_percentages(data)
    hall = data["children"][0]
    wrapper = hall["children"][0]
    hall["pos_data"] = tuple_value(960.0, 540.0, 50.0, 50.0, 1, 1)
    hall["adapter_option"] = [True, True, True, True, 0.0, 0.0, 0.0, 0.0]
    hall["open_adapter"] = True
    wrapper["pos_data"] = tuple_value(960.0, 540.0, 50.0, 50.0, 1, 1)
    wrapper["adapter_option"] = [True, True, True, True, 0.0, 0.0, 0.0, 0.0]
    wrapper["open_adapter"] = True
    UI_PATH.parent.mkdir(parents=True, exist_ok=True)
    TREE_PATH.parent.mkdir(parents=True, exist_ok=True)

    with UI_PATH.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=4)

    with TREE_PATH.open("w", encoding="utf-8") as f:
        json.dump(tree_of(data), f, ensure_ascii=False, indent=2)

    panel_tree_info = json.loads(PANEL_TREE_INFO_PATH.read_text(encoding="utf-8"))
    custom_group = None
    for entry in panel_tree_info:
        if entry.get("name") == "code_ui_custom_panel_tree":
            custom_group = entry
            break
    if custom_group is None:
        custom_group = {"name": "code_ui_custom_panel_tree", "key": 2147483647, "group": []}
        panel_tree_info.insert(0, custom_group)

    outgame_pair = {"__tuple__": True, "items": [data["uid"], data["name"]]}
    kept = []
    for item in custom_group.get("group", []):
        name = None
        if isinstance(item, dict) and item.get("__tuple__") is True:
            items = item.get("items", [])
            if len(items) >= 2:
                name = items[1]
        if name != "outgame":
            kept.append(item)
    kept.append(outgame_pair)
    custom_group["group"] = kept

    with PANEL_TREE_INFO_PATH.open("w", encoding="utf-8") as f:
        json.dump(panel_tree_info, f, ensure_ascii=False, indent=1)

    print(f"wrote {UI_PATH}")
    print(f"wrote {TREE_PATH}")
    print(f"updated {PANEL_TREE_INFO_PATH}")


if __name__ == "__main__":
    main()
