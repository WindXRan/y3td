#!/usr/bin/env python3
import json
import uuid
from pathlib import Path


EMPTY_IMAGE = 999
BTN_BLUE = {
    "normal": 107525,
    "hover": 107526,
    "press": 107527,
    "disabled": 107528,
}
EXIT_BTN = {
    "normal": 903408,
    "hover": 903407,
    "press": 903406,
    "disabled": 903406,
}


def tup(*items):
    return {"__tuple__": True, "items": list(items)}


def color(*items):
    return tup(*items)


def adapt_flags(adapter):
    parts = {part.strip().lower() for part in adapter.split(",") if part.strip()}
    return (
        "top" in parts or "all" in parts,
        "bottom" in parts or "all" in parts,
        "left" in parts or "all" in parts,
        "right" in parts or "all" in parts,
    )


def base_node(name, node_type, x, y, width, height, parent_w, parent_h, adapter="", visible=None):
    cx = round(x + width * 0.5, 4)
    y3_cy = round(parent_h - (y + height * 0.5), 4)
    pct_x = round((cx / parent_w) * 100, 4) if parent_w else 50.0
    pct_y = round((y3_cy / parent_h) * 100, 4) if parent_h else 50.0
    top, bottom, left, right = adapt_flags(adapter)
    node = {
        "children": [],
        "event_list": [],
        "name": name,
        "open_adapter": True,
        "adapter_option": [
            top,
            bottom,
            left,
            right,
            round(y, 4),
            round(parent_h - y - height, 4),
            round(x, 4),
            round(parent_w - x - width, 4),
        ],
        "pos_data": tup(
            cx,
            y3_cy,
            pct_x,
            pct_y,
            0 if pct_x == 0 else 1,
            0 if pct_y == 0 else 1,
        ),
        "prefab_sub_key": None,
        "scene_ui_name": None,
        "size": tup(float(width), float(height)),
        "type": node_type,
        "uid": str(uuid.uuid4()),
    }
    if visible is not None:
        node["visible"] = visible
    return node


def image_node(
    name,
    x,
    y,
    width,
    height,
    parent_w,
    parent_h,
    image=EMPTY_IMAGE,
    rgba=(255, 255, 255, 255),
    adapter="",
    scale9=True,
    insets=(18, 18, 18, 18),
    visible=None,
):
    node = base_node(name, 4, x, y, width, height, parent_w, parent_h, adapter=adapter, visible=visible)
    node["image"] = image
    node["color"] = color(*rgba)
    if scale9:
        node["is_scale9_enable"] = True
        node["cap_insets"] = tup(*insets)
    return node


def layout_node(name, x, y, width, height, parent_w, parent_h, adapter="", visible=None):
    return base_node(name, 7, x, y, width, height, parent_w, parent_h, adapter=adapter, visible=visible)


def text_node(
    name,
    x,
    y,
    width,
    height,
    parent_w,
    parent_h,
    text,
    font_size=16,
    rgba=(242, 247, 255, 255),
    h_align=2,
    v_align=8,
    adapter="",
    visible=None,
):
    node = base_node(name, 3, x, y, width, height, parent_w, parent_h, adapter=adapter, visible=visible)
    node["text"] = tup(text, False)
    node["font"] = tup("MSYH", font_size)
    node["font_color"] = color(*rgba)
    node["font_min_size"] = max(10, font_size - 4)
    node["over_pattern"] = 2
    node["alignment"] = tup(h_align, v_align)
    return node


def button_node(
    name,
    x,
    y,
    width,
    height,
    parent_w,
    parent_h,
    text,
    images=None,
    font_size=16,
    font_rgba=(247, 247, 247, 255),
    adapter="",
    visible=None,
):
    img = images or BTN_BLUE
    node = base_node(name, 1, x, y, width, height, parent_w, parent_h, adapter=adapter, visible=visible)
    node["normal_picture"] = img["normal"]
    node["suspend_picture"] = img["hover"]
    node["press_picture"] = img["press"]
    node["disabled_picture"] = img["disabled"]
    node["hover_status_added"] = True
    node["pressed_status_added"] = True
    node["disabled_status_added"] = True
    node["font"] = tup("MSYH", font_size)
    node["normal_text"] = tup(text, False)
    node["suspend_text"] = tup(text, False)
    node["press_text"] = tup(text, False)
    node["disabled_text"] = tup(text, False)
    node["normal_font_color"] = color(*font_rgba)
    node["suspend_font_color"] = color(*font_rgba)
    node["press_font_color"] = color(*font_rgba)
    node["disabled_font_color"] = color(*font_rgba)
    node["normal_cap_insets"] = tup(33.0, 33.0, 33.0, 33.0)
    node["press_cap_insets"] = tup(33.0, 33.0, 33.0, 33.0)
    node["suspend_cap_insets"] = tup(33.0, 33.0, 33.0, 33.0)
    return node


def checkbox_node(name, x, y, width, height, parent_w, parent_h, adapter="", visible=None):
    return base_node(name, 46, x, y, width, height, parent_w, parent_h, adapter=adapter, visible=visible)


def panel(name, x, y, width, height, parent_w, parent_h, bg_rgba, adapter="", insets=(20, 20, 20, 20)):
    root = layout_node(name, x, y, width, height, parent_w, parent_h, adapter=adapter)
    root["children"].append(
        image_node(
            f"{name}_bg",
            0,
            0,
            width,
            height,
            width,
            height,
            rgba=bg_rgba,
            adapter="all",
            insets=insets,
        )
    )
    return root


def add(parent, *children):
    parent["children"].extend(child for child in children if child is not None)
    return parent


def button_bundle(
    name,
    x,
    y,
    width,
    height,
    parent_w,
    parent_h,
    label,
    bg_rgba,
    shadow_rgba,
    images=None,
    font_size=14,
):
    bundle = layout_node(name, x, y, width, height, parent_w, parent_h)
    add(
        bundle,
        image_node(
            "shadow",
            -4,
            4,
            width + 8,
            height + 8,
            width,
            height,
            rgba=shadow_rgba,
            insets=(16, 16, 16, 16),
        ),
        image_node(
            "bg",
            0,
            0,
            width,
            height,
            width,
            height,
            rgba=bg_rgba,
            insets=(16, 16, 16, 16),
        ),
        button_node(
            "button",
            0,
            0,
            width,
            height,
            width,
            height,
            label,
            images=images,
            font_size=font_size,
        ),
    )
    return bundle


def build_top_cluster(parent):
    top = panel("top_battle_cluster", 400, 24, 1120, 168, *parent, bg_rgba=(10, 18, 31, 214), adapter="top")
    w, h = 1120, 168

    stage_chip = panel("stage_chip", 18, 18, 174, 42, w, h, bg_rgba=(24, 40, 62, 230))
    add(
        stage_chip,
        text_node("stage_label", 14, 6, 58, 14, 174, 42, "章节", font_size=10, rgba=(158, 184, 214, 255), h_align=1),
        text_node("stage_text", 14, 18, 146, 18, 174, 42, "主线 1-1", font_size=13, h_align=1),
    )

    timer_block = panel("timer_block", 228, 14, 304, 48, w, h, bg_rgba=(16, 28, 45, 226))
    add(
        timer_block,
        text_node("timer_label", 18, 8, 88, 14, 304, 48, "战斗计时", font_size=10, rgba=(158, 184, 214, 255), h_align=1),
        text_node("timer_text", 18, 22, 112, 18, 304, 48, "00:00", font_size=16, h_align=1),
        text_node("wave_status_text", 140, 14, 146, 22, 304, 48, "等待开战", font_size=12, rgba=(182, 201, 224, 255), h_align=4),
    )

    wave_medallion = panel("wave_medallion", 560, 10, 220, 58, w, h, bg_rgba=(62, 122, 196, 232))
    add(
        wave_medallion,
        text_node("wave_caption", 14, 8, 70, 14, 220, 58, "波次", font_size=10, rgba=(218, 232, 255, 255), h_align=1),
        text_node("wave_title", 14, 24, 192, 22, 220, 58, "第 0 / 5 波", font_size=18),
    )

    boss_capsule = panel("boss_capsule", 810, 14, 292, 48, w, h, bg_rgba=(156, 118, 58, 224))
    add(
        boss_capsule,
        text_node("boss_label", 16, 6, 42, 14, 292, 48, "Boss", font_size=10, rgba=(255, 236, 208, 255), h_align=1),
        text_node("boss_name", 16, 20, 120, 16, 292, 48, "Boss 未登场", font_size=13, h_align=1),
        text_node("boss_state", 146, 20, 130, 16, 292, 48, "等待本波开始", font_size=11, rgba=(255, 240, 220, 255), h_align=4),
    )

    resource_cluster = layout_node("resource_cluster", 18, 84, 1084, 66, w, h)
    for index, (name, x, label, bg, value_color) in enumerate(
        [
            ("gold_card", 0, "金币", (46, 40, 18, 226), (255, 236, 186, 255)),
            ("wood_card", 278, "木材", (22, 42, 26, 226), (218, 247, 214, 255)),
            ("skill_card", 556, "技能点", (24, 40, 62, 226), (242, 247, 255, 255)),
            ("challenge_card", 834, "挑战", (42, 28, 18, 226), (255, 236, 212, 255)),
        ]
    ):
        card = panel(name, x, 6, 250 if index < 3 else 250, 54, 1084, 66, bg_rgba=bg)
        value_name = name.replace("_card", "_value")
        add(
            card,
            text_node(f"{name}_label", 16, 8, 64, 14, 250, 54, label, font_size=10, rgba=(170, 188, 214, 255), h_align=1),
            text_node(value_name, 16, 22, 218, 20, 250, 54, "0", font_size=16, rgba=value_color, h_align=1),
        )
        resource_cluster["children"].append(card)

    add(top, stage_chip, timer_block, wave_medallion, boss_capsule, resource_cluster)
    return top


def build_left_panel(parent):
    left = panel("left_shortcut_panel", 40, 154, 286, 318, *parent, bg_rgba=(12, 21, 34, 214), adapter="top,left")
    w, h = 286, 318
    add(
        left,
        button_node("exit_button", 18, 18, 116, 34, w, h, "退出", images=EXIT_BTN, font_size=13),
        button_node("settings_button", 152, 18, 116, 34, w, h, "设置", images=BTN_BLUE, font_size=13),
        text_node("shortcut_title", 24, 72, 238, 22, w, h, "快捷操作", font_size=16, h_align=1),
        text_node(
            "shortcut_list",
            24,
            106,
            238,
            180,
            w,
            h,
            "G 技能升级\nF 羁绊抽取\nQ/W/E/R 试炼入口\nB 局内总览\nI 已吞噬羁绊",
            font_size=13,
            rgba=(182, 201, 224, 255),
            h_align=1,
            v_align=16,
        ),
    )
    return left


def build_right_tracker(parent):
    right = panel("right_tracker_panel", 1578, 146, 302, 314, *parent, bg_rgba=(12, 21, 34, 214), adapter="top,right")
    w, h = 302, 314
    add(
        right,
        text_node("tracker_title", 24, 18, 160, 22, w, h, "战斗追踪", font_size=16, h_align=1),
        text_node("tracker_objective", 24, 56, 254, 80, w, h, "目标：等待本波开始", font_size=14, h_align=1, v_align=16),
        text_node("tracker_progress", 24, 148, 254, 52, w, h, "进度：第 0 / 5 波", font_size=13, rgba=(182, 201, 224, 255), h_align=1, v_align=16),
        text_node("tracker_reward", 24, 210, 254, 28, w, h, "奖励：待领取 0", font_size=13, rgba=(255, 236, 186, 255), h_align=1),
        text_node("tracker_hint", 24, 246, 220, 24, w, h, "提示：挑战恢复中", font_size=12, rgba=(142, 165, 192, 255), h_align=1),
        checkbox_node("auto_task_checkbox", 24, 272, 44, 42, w, h),
        text_node("auto_task_label", 74, 282, 156, 18, w, h, "自动追踪", font_size=12, rgba=(182, 201, 224, 255), h_align=1),
    )
    return right


def build_challenge_strip(parent):
    strip = panel("challenge_strip", 60, 736, 426, 150, *parent, bg_rgba=(10, 18, 31, 214), adapter="bottom,left")
    w, h = 426, 150
    add(strip, text_node("challenge_strip_title", 18, 14, 120, 20, w, h, "试炼入口", font_size=15, h_align=1))
    strip["children"].extend(
        [
            button_bundle("gold_trial_button", 18, 48, 186, 38, w, h, "金币 Q", (126, 104, 52, 232), (40, 24, 8, 136)),
            button_bundle("wood_trial_button", 222, 48, 186, 38, w, h, "木材 W", (74, 118, 86, 232), (18, 34, 20, 136)),
            button_bundle("exp_trial_button", 18, 98, 186, 38, w, h, "经验 E", (74, 98, 146, 232), (20, 34, 58, 136)),
            button_bundle("treasure_trial_button", 222, 98, 186, 38, w, h, "宝物 R", (128, 90, 68, 232), (34, 18, 10, 136)),
        ]
    )
    return strip


def build_skill_slot(slot_name, key_label):
    slot = panel(slot_name, 0, 0, 96, 96, 96, 96, bg_rgba=(16, 28, 45, 224))
    add(
        slot,
        image_node(f"{slot_name}_accent", 8, 8, 80, 8, 96, 96, rgba=(62, 122, 196, 232), insets=(6, 6, 6, 6)),
        text_node(f"{slot_name}_key", 8, 16, 20, 14, 96, 96, key_label, font_size=11, rgba=(255, 236, 186, 255), h_align=1),
        text_node(f"{slot_name}_text", 10, 36, 76, 22, 96, 96, "未装配", font_size=12),
        text_node(f"{slot_name}_meta", 10, 64, 76, 16, 96, 96, "等待解锁", font_size=10, rgba=(142, 165, 192, 255)),
    )
    return slot


def build_bottom_bar(parent):
    bottom = panel("bottom_action_bar", 330, 814, 1260, 222, *parent, bg_rgba=(10, 18, 31, 222), adapter="bottom")
    w, h = 1260, 222

    hero_core = panel("hero_core_panel", 24, 24, 250, 152, w, h, bg_rgba=(12, 21, 34, 224))
    add(
        hero_core,
        image_node("hero_portrait", 18, 22, 74, 74, 250, 152, rgba=(255, 255, 255, 255), insets=(12, 12, 12, 12)),
        text_node("hero_name", 108, 24, 120, 22, 250, 152, "先锋英雄", font_size=17, h_align=1),
        text_node("hero_progress_text", 108, 50, 120, 18, 250, 152, "Lv1 0/100", font_size=12, rgba=(182, 201, 224, 255), h_align=1),
        image_node("hero_hp_bg", 18, 114, 214, 14, 250, 152, rgba=(44, 18, 22, 232), insets=(8, 8, 8, 8)),
        image_node("hero_hp_fill", 18, 114, 214, 14, 250, 152, rgba=(78, 136, 96, 236), insets=(8, 8, 8, 8)),
        text_node("hero_hp_text", 18, 88, 214, 18, 250, 152, "生命 0 / 0", font_size=12),
    )

    hotbar = layout_node("skill_hotbar", 300, 28, 420, 132, w, h)
    for index, x in enumerate([0, 108, 216, 324], start=1):
        slot = build_skill_slot(f"skill_slot_{index}", str(index))
        slot["name"] = f"skill_slot_{index}"
        slot["adapter_option"] = hotbar["adapter_option"][:]  # overwritten below
        # Rebuild with actual parent dimensions.
        rebuilt = panel(f"skill_slot_{index}", x, 18, 96, 96, 420, 132, bg_rgba=(16, 28, 45, 224))
        add(
            rebuilt,
            image_node(f"skill_slot_{index}_accent", 8, 8, 80, 8, 96, 96, rgba=(62, 122, 196, 232), insets=(6, 6, 6, 6)),
            text_node(f"skill_slot_{index}_key", 8, 16, 20, 14, 96, 96, str(index), font_size=11, rgba=(255, 236, 186, 255), h_align=1),
            text_node(f"skill_slot_{index}_text", 10, 36, 76, 22, 96, 96, "未装配", font_size=12),
            text_node(f"skill_slot_{index}_meta", 10, 64, 76, 16, 96, 96, "等待解锁", font_size=10, rgba=(142, 165, 192, 255)),
        )
        hotbar["children"].append(rebuilt)

    primary = layout_node("primary_action_cluster", 748, 30, 214, 110, w, h)
    primary["children"].extend(
        [
            button_bundle("skill_button", 0, 0, 214, 44, 214, 110, "技能 G", (58, 84, 112, 232), (8, 16, 28, 120)),
            button_bundle("bond_button", 0, 58, 214, 44, 214, 110, "羁绊 F", (84, 100, 132, 232), (8, 16, 28, 120)),
        ]
    )

    secondary = layout_node("secondary_action_cluster", 980, 30, 252, 110, w, h)
    secondary["children"].extend(
        [
            button_bundle("treasure_button", 0, 0, 252, 32, 252, 110, "宝物入口", (128, 90, 68, 232), (34, 18, 10, 130), font_size=13),
            button_bundle("focus_clear_button", 0, 42, 120, 28, 252, 110, "总览 B", (58, 84, 112, 226), (8, 16, 28, 120), font_size=12),
            button_bundle("swallowed_list_button", 132, 42, 120, 28, 252, 110, "吞噬 I", (58, 84, 112, 226), (8, 16, 28, 120), font_size=12),
        ]
    )

    exp_rail = panel("exp_rail", 20, 184, 1220, 18, w, h, bg_rgba=(16, 28, 45, 228))
    add(
        exp_rail,
        image_node("exp_rail_fill", 3, 3, 1214, 12, 1220, 18, rgba=(62, 122, 196, 236), insets=(8, 8, 8, 8)),
        text_node("exp_rail_text", 0, 0, 1220, 18, 1220, 18, "经验轨 0/0", font_size=10),
    )

    add(bottom, hero_core, hotbar, primary, secondary, exp_rail)
    return bottom


def build_hud_root():
    hud_root = layout_node("hud_root", 0, 0, 1920, 1080, 1920, 1080, adapter="all")
    add(
        hud_root,
        build_top_cluster((1920, 1080)),
        build_left_panel((1920, 1080)),
        build_right_tracker((1920, 1080)),
        build_challenge_strip((1920, 1080)),
        build_bottom_bar((1920, 1080)),
        layout_node("overlay_reserved", 0, 0, 1920, 1080, 1920, 1080, adapter="all"),
    )
    return hud_root


def patch_gamehud(gamehud_path: Path):
    with gamehud_path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    children = data.get("children", [])
    children = [child for child in children if child.get("name") != "hud_root"]
    children.append(build_hud_root())
    data["children"] = children

    with gamehud_path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=4)
        fh.write("\n")

    print(f"[OK] patched {gamehud_path}")


def main():
    map_root = Path(__file__).resolve().parents[2]
    patch_gamehud(map_root / "ui" / "GameHUD.json")


if __name__ == "__main__":
    main()
