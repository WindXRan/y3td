#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
UI_PATH = ROOT / "maps" / "EntryMap" / "ui" / "BattleBottomHUD.json"
TREE_PATH = ROOT / "maps" / "EntryMap" / "ui_tree" / "BattleBottomHUD_Tree.json"
PANEL_TREE_INFO_PATH = ROOT / "maps" / "EntryMap" / "editor" / "uipaneltreegroupinfo.json"

BG_BLACK = 134275447
SHOP_BG = 134218572
SHOP_BG_ALT = 134222677
SHOP_CONTENT_BG = 134251378
SHOP_CONTENT_BG_ALT = 134257744
SHOP_LINE = 134265244
SHOP_INIT_BG = 134270624
PROP_FRAME = 134226696
PROP_FRAME_ALT = 134257674
SKILL_EMPTY = 134243288
SKILL_SMALL_EMPTY = 134265666
HERO_FRAME = 134274626
BUTTON_BLUE = 134242808
BUTTON_BLUE_HOV = 134275186
BUTTON_BLUE_DWN = 134282277
BUTTON_YELLOW = 134245485
BUTTON_YELLOW_DWN = 134229436
BUTTON_YELLOW_DIS = 134278408
BUTTON_ACTION_GOLD = 134242781
BUTTON_ACTION_GOLD_HOV = 134249985
BUTTON_ACTION_GOLD_DWN = 134279816
BUTTON_ACTION_BLUE = 134259827
BUTTON_ACTION_BLUE_HOV = 134227948
BUTTON_ACTION_BLUE_DWN = 134254902
ICON_ATTACK = 134264555
ICON_DEFENSE = 134271479
ICON_FAST = 134264913
ICON_ATTACK_SPEED = 134276172
ICON_MISC = 134227227
ICON_ITEM_1 = 300540000
ICON_ITEM_2 = 134275326
ICON_ITEM_3 = 134269594
ICON_ITEM_4 = 134222930
PORTRAIT_MAIN = 134223473
PORTRAIT_ALT_1 = 134229245
PORTRAIT_ALT_2 = 134247564
PORTRAIT_ALT_3 = 134250311
SKILL_ICON_1 = 134230757
SKILL_ICON_2 = 134225891
SKILL_ICON_3 = 134262182
SKILL_ICON_4 = 134227030
CARD_SKILL_1 = 134242811
CARD_SKILL_2 = 134231611
CARD_SKILL_3 = 134269795
CARD_SKILL_4 = 134220765
STAT_STRIP_LEFT = 134279005
STAT_STRIP_RIGHT = 134241430
STAT_ICON_ATTACK = 134230937
STAT_ICON_DEFENSE = 134268904
STAT_ICON_SPEED = 134264735
STAT_ICON_MAGIC = 134272066
HP_BAR_BG = 134257679
LONG_LINE = 134250742


def uid():
    return str(uuid.uuid4())


def tuple_value(*items):
    return {"__tuple__": True, "items": list(items)}


def base_node(name, node_type, x, y, width, height):
    return {
        "name": name,
        "type": node_type,
        "uid": uid(),
        "prefab_sub_key": None,
        "scene_ui_name": None,
        "children": [],
        "event_list": [],
        "pos_data": tuple_value(x, y, 0.0, 0.0, 1, 1),
        "size": [width, height],
        "visible": True,
    }


def layout(name, x, y, width, height, color=None, swallow=False):
    node = base_node(name, 7, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["clip_enabled"] = False
    node["clipping_type"] = 1
    node["color"] = tuple_value(*(color or [255, 255, 255, 0]))
    node["open_adapter"] = False
    node["swallow_touches"] = swallow
    return node


def panel(name, x, y, width, height, color, children=None):
    node = layout(name, x, y, width, height, color)
    node["children"] = children or []
    return node


def fullscreen_layout(name):
    node = layout(name, 960, 540, 1920, 1080, [255, 255, 255, 0])
    node["adapter_option"] = [True, True, True, True, 0.0, 0.0, 0.0, 0.0]
    node["open_adapter"] = True
    node["pos_data"] = tuple_value(960.0, 540.0, 50.0, 50.0, 1, 1)
    return node


def image(name, x, y, width, height, image_id, color=None, scale9=False):
    node = base_node(name, 4, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["image"] = image_id
    node["color"] = color or [255, 255, 255, 255]
    node["cap_insets"] = [18, 18, 18, 18]
    node["is_scale9_enable"] = scale9
    node["open_adapter"] = False
    node["opacity"] = 1.0
    node["rotation"] = 0
    node["scale"] = tuple_value(1, 1)
    node["swallow_touches"] = False
    node["anchor"] = tuple_value(0.5, 0.5)
    return node


def minimap(name, x, y, width, height):
    node = base_node(name, 16, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["anchor"] = tuple_value(0.5, 0.5)
    node["open_adapter"] = False
    node["opacity"] = 1.0
    node["rotation"] = 0
    node["scale"] = tuple_value(1, 1)
    node["swallow_touches"] = False
    return node


def text(name, x, y, width, height, value, font_size, color, align_h=1):
    node = base_node(name, 3, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["alignment"] = tuple_value(align_h, 8)
    node["bold"] = False
    node["border"] = False
    node["font"] = tuple_value("MSYH", font_size)
    node["font_color"] = tuple_value(*color)
    node["font_min_size"] = max(10, font_size - 4)
    node["gradient"] = False
    node["gradient_bl_color"] = tuple_value(255, 255, 255, 255)
    node["gradient_br_color"] = tuple_value(255, 255, 255, 255)
    node["gradient_tl_color"] = tuple_value(255, 255, 255, 255)
    node["gradient_tr_color"] = tuple_value(255, 255, 255, 255)
    node["italics"] = False
    node["label_effect"] = tuple_value(False, False, False, False, False, False)
    node["line_space"] = tuple_value(0, 0)
    node["open_adapter"] = False
    node["opacity"] = 1.0
    node["over_pattern"] = True
    node["review_word"] = False
    node["rotation"] = 0
    node["scale"] = tuple_value(1, 1)
    node["shadow"] = False
    node["strike_through"] = False
    node["strike_through_color"] = tuple_value(0, 0, 0, 255)
    node["strike_through_size"] = 0
    node["swallow_touches"] = False
    node["text"] = tuple_value(value, False)
    node["text_bind"] = tuple_value(None, None)
    node["text_border_color"] = tuple_value(0, 0, 0, 255)
    node["text_border_width"] = 0
    node["text_format"] = ""
    node["text_italic_radius"] = 0.5
    node["text_shadow_color"] = tuple_value(123, 123, 123, 255)
    node["text_shadow_offset"] = tuple_value(0, 0)
    node["typewriter_effect"] = 0
    node["typewriter_space"] = 0
    node["under_line"] = False
    node["anchor"] = tuple_value(0.5, 0.5)
    return node


def button(
    name,
    x,
    y,
    width,
    height,
    value,
    normal_picture=107525,
    suspend_picture=None,
    press_picture=None,
    disabled_picture=None,
    font_size=18,
):
    node = base_node(name, 1, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["normal_picture"] = normal_picture
    node["suspend_picture"] = suspend_picture or normal_picture
    node["press_picture"] = press_picture or suspend_picture or normal_picture
    node["disabled_picture"] = disabled_picture or normal_picture
    node["normal_text"] = tuple_value(value, False)
    node["suspend_text"] = tuple_value(value, False)
    node["press_text"] = tuple_value(value, False)
    node["disabled_text"] = tuple_value(value, False)
    node["font"] = tuple_value("MSYH", font_size)
    node["normal_font_color"] = [247, 247, 247, 255]
    node["suspend_font_color"] = [247, 247, 247, 255]
    node["press_font_color"] = [247, 247, 247, 255]
    node["disabled_font_color"] = [180, 180, 180, 255]
    node["hover_status_added"] = True
    node["pressed_status_added"] = True
    node["disabled_status_added"] = True
    node["open_adapter"] = False
    node["anchor"] = tuple_value(0.5, 0.5)
    return node


def build_debug_button(name, x, label):
    root = layout(name, x, 290, 94, 32)
    root["children"] = [
        button(
            "button",
            47,
            16,
            94,
            32,
            label,
            normal_picture=BUTTON_BLUE,
            suspend_picture=BUTTON_BLUE_HOV,
            press_picture=BUTTON_BLUE_DWN,
            disabled_picture=BUTTON_BLUE,
            font_size=12,
        ),
    ]
    return root


def build_challenge_badge(name, x, title, count, icon_id, accent_color):
    root = layout(name, x, 39, 114, 78)
    root["children"] = [
        image("plate", 57, 39, 114, 78, SHOP_INIT_BG, [255, 255, 255, 235], True),
        panel("accent", 57, 70, 96, 6, accent_color),
        image("icon_frame", 22, 39, 46, 46, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 22, 39, 28, 28, icon_id, [255, 255, 255, 255], False),
        text("count", 70, 44, 58, 30, str(count), 22, [255, 231, 156, 255], 0),
        image("line", 57, 14, 94, 1, SHOP_LINE, [255, 255, 255, 190], True),
        text("title", 57, 60, 98, 16, title, 12, [242, 246, 250, 255]),
    ]
    return root


def build_small_icon_slot(name, x, y, hotkey, title, icon_id):
    root = layout(name, x, y, 60, 60)
    root["children"] = [
        image("frame", 30, 30, 58, 58, SKILL_SMALL_EMPTY, [255, 255, 255, 255], False),
        image("icon", 30, 30, 28, 28, icon_id, [255, 255, 255, 255], False),
        image("hotkey_band", 30, 51, 46, 10, SHOP_CONTENT_BG, [255, 255, 255, 220], True),
        text("hotkey", 10, 51, 18, 12, hotkey, 11, [255, 215, 112, 255], 0),
        text("title", 30, -9, 54, 14, title, 10, [195, 204, 218, 255]),
    ]
    return root


def build_skill_slot(name, x, key_text, icon_id):
    root = layout(name, x, 51, 94, 102)
    root["children"] = [
        image("frame", 47, 51, 92, 92, SKILL_EMPTY, [255, 255, 255, 255], False),
        image("icon", 47, 53, 66, 66, icon_id, [255, 255, 255, 255], False),
        image("label_band", 47, 10, 82, 12, SHOP_CONTENT_BG_ALT, [255, 255, 255, 255], True),
        text("key", 17, 86, 22, 14, key_text, 12, [255, 223, 143, 255]),
        text("cooldown", 72, 88, 28, 14, "0", 12, [220, 235, 255, 255]),
        text("label", 47, 88, 76, 14, "未装配", 10, [185, 196, 212, 255]),
    ]
    return root


def build_card_slot(name, x, y, icon_id=None, frame_id=PROP_FRAME):
    root = layout(name, x, y, 74, 74)
    children = [image("frame", 37, 37, 72, 72, frame_id, [255, 255, 255, 255], False)]
    if icon_id is not None:
        children.append(image("icon", 37, 37, 52, 52, icon_id, [255, 255, 255, 255], False))
    root["children"] = children
    return root


def build_loadout_slot(name, x, y, icon_id=None, frame_id=PROP_FRAME):
    root = layout(name, x, y, 64, 64)
    children = [image("frame", 32, 32, 62, 62, frame_id, [255, 255, 255, 255], False)]
    if icon_id is not None:
        children.append(image("icon", 32, 32, 44, 44, icon_id, [255, 255, 255, 255], False))
    root["children"] = children
    return root


def build_small_card_slot(name, x, y, icon_id=None, frame_id=PROP_FRAME):
    root = layout(name, x, y, 70, 70)
    children = [image("frame", 35, 35, 64, 64, frame_id, [255, 255, 255, 255], False)]
    if icon_id is not None:
        children.append(image("icon", 35, 35, 46, 46, icon_id, [255, 255, 255, 255], False))
    root["children"] = children
    return root


def build_player_attr_row(name, x, y, label_text, value_text, delta_text, icon_id):
    root = layout(name, x, y, 150, 28)
    root["children"] = [
        image("strip", 75, 14, 150, 28, SHOP_CONTENT_BG_ALT, [255, 255, 255, 225], True),
        image("icon_frame", 16, 14, 24, 24, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 16, 14, 14, 14, icon_id, [255, 255, 255, 255], False),
        text("label", 42, 14, 42, 16, label_text, 11, [245, 247, 250, 255], 0),
        text("value", 92, 14, 54, 16, value_text, 11, [255, 223, 136, 255], 0),
        text("delta", 132, 14, 30, 16, delta_text, 10, [79, 214, 118, 255], 2),
    ]
    return root


def build_consumable_slot(name, x, y, hotkey, amount_text, icon_id):
    root = layout(name, x, y, 62, 52)
    root["children"] = [
        image("slot_bg", 31, 26, 62, 52, SHOP_CONTENT_BG_ALT, [255, 255, 255, 220], True),
        image("frame", 19, 26, 36, 36, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 19, 26, 26, 26, icon_id, [255, 255, 255, 255], False),
        text("hotkey", 50, 38, 18, 12, hotkey, 10, [255, 224, 135, 255], 2),
        text("count", 48, 14, 20, 12, amount_text, 10, [240, 245, 250, 255], 2),
    ]
    return root


def build_status_line(name, x, y, label_text, value_text, icon_id):
    root = layout(name, x, y, 170, 24)
    root["children"] = [
        image("strip", 85, 12, 170, 24, STAT_STRIP_LEFT, [255, 255, 255, 255], True),
        image("icon", 18, 12, 18, 18, icon_id, [255, 255, 255, 255], False),
        text("label", 58, 12, 62, 16, label_text, 11, [243, 247, 252, 255], 0),
        text("value", 132, 12, 60, 16, value_text, 11, [255, 220, 125, 255]),
    ]
    return root


def build_avatar_slot(name, x, y, portrait_id, label_text=""):
    root = layout(name, x, y, 56, 66)
    root["children"] = [
        image("frame", 28, 24, 54, 54, HERO_FRAME, [255, 255, 255, 255], False),
        image("avatar", 28, 24, 42, 42, portrait_id, [255, 255, 255, 255], False),
        text("label", 28, 56, 52, 12, label_text, 10, [255, 214, 121, 255]),
    ]
    return root


def build_action_card(name, x, y, width, title_text, hotkey, accent_color):
    root = layout(name, x, y, width, 68)
    root["children"] = [
        image("frame", width / 2, 34, width, 68, SHOP_INIT_BG, [255, 255, 255, 255], True),
        panel("accent", width / 2, 56, width - 10, 8, accent_color),
        image("line", width / 2, 10, width - 22, 1, SHOP_LINE, [255, 255, 255, 180], True),
        text("title", width / 2, 35, width - 18, 24, title_text, 16, [246, 248, 251, 255]),
        text("hotkey", 24, 52, 24, 12, hotkey, 12, [255, 223, 143, 255]),
    ]
    return root


def build_compact_button(name, x, y, label, hotkey, palette="yellow"):
    if palette == "blue":
        normal_picture = BUTTON_ACTION_BLUE
        suspend_picture = BUTTON_ACTION_BLUE_HOV
        press_picture = BUTTON_ACTION_BLUE_DWN
        disabled_picture = BUTTON_ACTION_BLUE
        width = 120
        height = 38
        font_size = 14
    else:
        normal_picture = BUTTON_ACTION_GOLD
        suspend_picture = BUTTON_ACTION_GOLD_HOV
        press_picture = BUTTON_ACTION_GOLD_DWN
        disabled_picture = BUTTON_ACTION_GOLD
        width = 128
        height = 44
        font_size = 15

    root = layout(name, x, y, width, height)
    root["children"] = [
        button(
            "button",
            width / 2,
            height / 2,
            width,
            height,
            label,
            normal_picture=normal_picture,
            suspend_picture=suspend_picture,
            press_picture=press_picture,
            disabled_picture=disabled_picture,
            font_size=font_size,
        ),
        text("hotkey", width - 16, height / 2, 24, 12, hotkey, 10, [255, 238, 173, 255], 2),
    ]
    return root


def build_card_button(name, x, y, label, hotkey, palette="yellow"):
    if palette == "blue":
        normal_picture = BUTTON_ACTION_BLUE
        suspend_picture = BUTTON_ACTION_BLUE_HOV
        press_picture = BUTTON_ACTION_BLUE_DWN
        disabled_picture = BUTTON_ACTION_BLUE
    else:
        normal_picture = BUTTON_ACTION_GOLD
        suspend_picture = BUTTON_ACTION_GOLD_HOV
        press_picture = BUTTON_ACTION_GOLD_DWN
        disabled_picture = BUTTON_ACTION_GOLD

    root = layout(name, x, y, 104, 34)
    root["children"] = [
        button(
            "button",
            52,
            17,
            104,
            34,
            label,
            normal_picture=normal_picture,
            suspend_picture=suspend_picture,
            press_picture=press_picture,
            disabled_picture=disabled_picture,
            font_size=14,
        ),
        text("hotkey", 86, 17, 18, 12, hotkey, 10, [255, 238, 173, 255], 2),
    ]
    return root


def build_toggle_button(name, x, y, label):
    root = layout(name, x, y, 90, 30)
    root["children"] = [
        button(
            "button",
            45,
            15,
            90,
            30,
            label,
            normal_picture=BUTTON_BLUE,
            suspend_picture=BUTTON_BLUE_HOV,
            press_picture=BUTTON_BLUE_DWN,
            disabled_picture=BUTTON_BLUE,
            font_size=12,
        ),
    ]
    return root


def build_attr_row(name, x, y, label_text, value_text, delta_text, icon_id):
    root = layout(name, x, y, 182, 24)
    root["children"] = [
        image("strip", 91, 12, 182, 24, STAT_STRIP_LEFT, [255, 255, 255, 255], True),
        image("icon_frame", 18, 12, 24, 24, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 18, 12, 18, 18, icon_id, [255, 255, 255, 255], False),
        text("label", 58, 12, 58, 16, label_text, 11, [243, 247, 252, 255], 0),
        text("value", 118, 12, 56, 16, value_text, 11, [255, 220, 125, 255], 0),
        text("delta", 160, 12, 34, 16, delta_text, 10, [79, 214, 118, 255], 2),
    ]
    return root


def build_reference_skill_slot(name, x, key_text, icon_id):
    root = layout(name, x, 36, 72, 72)
    root["children"] = [
        image("frame", 36, 36, 72, 72, SKILL_EMPTY, [255, 255, 255, 255], False),
        image("icon", 36, 36, 54, 54, icon_id, [255, 255, 255, 255], False),
    ]
    return root


def build_reference_growth_weapon_slot():
    root = layout("growth_weapon_slot", 40, 106, 72, 72)
    root["children"] = [
        image("frame", 36, 36, 72, 72, SKILL_EMPTY, [255, 255, 255, 255], False),
        image("icon", 36, 38, 50, 50, SKILL_ICON_1, [255, 255, 255, 255], False),
        image("label_band", 36, 9, 58, 10, SHOP_CONTENT_BG_ALT, [255, 255, 255, 235], True),
        text("key", 13, 60, 18, 12, "普", 10, [255, 223, 143, 255], 0),
        text("cooldown", 58, 60, 18, 12, "0", 10, [220, 235, 255, 255], 2),
        text("label", 36, 9, 42, 10, "", 9, [185, 196, 212, 255]),
    ]
    return root


def build_reference_grid_slot(name, x, y, icon_id=None, highlight=False):
    frame_id = PROP_FRAME_ALT if highlight else PROP_FRAME
    root = layout(name, x, y, 62, 62)
    children = [image("frame", 31, 31, 60, 60, frame_id, [255, 255, 255, 255], False)]
    if icon_id is not None:
        children.append(image("icon", 31, 31, 44, 44, icon_id, [255, 255, 255, 255], False))
    root["children"] = children
    return root


def build_reference_consumable_slot(name, x, y, hotkey, amount_text, icon_id):
    root = layout(name, x, y, 72, 60)
    root["children"] = [
        image("frame", 26, 30, 50, 50, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 26, 30, 34, 34, icon_id, [255, 255, 255, 255], False),
        text("hotkey", 56, 42, 18, 12, hotkey, 11, [255, 224, 135, 255], 2),
        text("count", 56, 16, 18, 12, amount_text, 11, [240, 245, 250, 255], 2),
    ]
    return root


def build_reference_action_button(name, x, y, label, hotkey, palette="yellow"):
    if palette == "blue":
        normal_picture = BUTTON_ACTION_BLUE
        suspend_picture = BUTTON_ACTION_BLUE_HOV
        press_picture = BUTTON_ACTION_BLUE_DWN
        disabled_picture = BUTTON_ACTION_BLUE
    else:
        normal_picture = BUTTON_ACTION_GOLD
        suspend_picture = BUTTON_ACTION_GOLD_HOV
        press_picture = BUTTON_ACTION_GOLD_DWN
        disabled_picture = BUTTON_ACTION_GOLD

    root = layout(name, x, y, 60, 52)
    root["children"] = [
        button(
            "button",
            30,
            26,
            60,
            52,
            label,
            normal_picture=normal_picture,
            suspend_picture=suspend_picture,
            press_picture=press_picture,
            disabled_picture=disabled_picture,
            font_size=15,
        ),
        text("hotkey", 49, 38, 14, 10, hotkey, 10, [255, 238, 173, 255], 2),
    ]
    return root


def build_reference_hover_tip_panel():
    root = layout("hover_tip_panel", 400, 345, 320, 192)
    root["visible"] = False
    root["children"] = [
        image("tip_bg", 160, 96, 320, 192, BG_BLACK, [255, 255, 255, 236], True),
        image("tip_inner", 160, 96, 310, 182, SHOP_CONTENT_BG, [255, 255, 255, 214], True),
        image("tip_head_bg", 160, 154, 310, 54, SHOP_BG_ALT, [255, 255, 255, 145], True),
        image("icon_bg", 34, 156, 34, 34, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 34, 156, 28, 28, ICON_ITEM_1, [255, 255, 255, 255], False),
        text("title", 178, 164, 240, 24, "提示标题", 18, [245, 248, 255, 255], 0),
        text("subtitle", 178, 138, 240, 18, "提示副标题", 12, [255, 223, 131, 255], 0),
        image("divider", 160, 116, 286, 1, SHOP_LINE, [255, 255, 255, 126], True),
        text("body", 160, 54, 284, 96, "提示内容", 14, [219, 229, 241, 255], 0),
    ]
    return root


def build_reference_buff_slot(name, x, icon_id):
    root = layout(name, x, 18, 34, 34)
    root["children"] = [
        image("icon", 17, 17, 28, 28, icon_id, [255, 255, 255, 255], False),
    ]
    return root


def build_reference_challenge_badge(name, x, title, count_text, icon_id, accent_color):
    count_text = str(count_text)
    font_size = 18 if len(count_text) <= 2 else 16 if len(count_text) <= 3 else 9
    root = layout(name, x, 34, 94, 68)
    root["children"] = [
        image("plate", 47, 34, 94, 68, SHOP_INIT_BG, [255, 255, 255, 235], True),
        panel("accent", 47, 57, 78, 6, accent_color),
        image("icon_frame", 21, 42, 38, 38, PROP_FRAME_ALT, [255, 255, 255, 255], False),
        image("icon", 21, 42, 20, 20, icon_id, [255, 255, 255, 255], False),
        text("count", 59, 42, 54, 18, count_text, font_size, [255, 231, 156, 255]),
        text("title", 57, 18, 62, 16, title, 11, [242, 246, 250, 255]),
    ]
    return root


def build_bottom_hud():
    root = {
        "adapt_mode": 2,
        "anim_data": {},
        "auto_create": True,
        "children": [],
        "name": "BattleBottomHUD",
        "opacity": 1.0,
        "script_name": "",
        "type": 2,
        "ui_anims": [],
        "uid": uid(),
        "visible": True,
        "zorder": 410,
    }

    canvas = fullscreen_layout("layout")
    shell = panel("bottom_shell", 927, 148, 1630, 280, [10, 14, 20, 90])
    shell["children"] = [
        image("shell_bg", 815, 140, 1630, 272, BG_BLACK, [255, 255, 255, 214], True),
        image("top_line", 815, 271, 1560, 1, SHOP_LINE, [255, 255, 255, 148], True),
    ]

    left_station = panel("left_station", 350, 148, 460, 268, [14, 18, 25, 92])
    left_station["children"] = [
        image("station_bg", 230, 134, 460, 252, BG_BLACK, [255, 255, 255, 126], True),
        image("station_title_line", 230, 228, 420, 1, SHOP_LINE, [255, 255, 255, 126], True),
        image("map_frame", 118, 138, 206, 180, BG_BLACK, [255, 255, 255, 146], True),
        image("map_badge_bg", 62, 240, 98, 24, SHOP_CONTENT_BG, [255, 220, 126, 238], True),
        text("map_badge", 62, 240, 84, 16, "第3赛季", 12, [255, 245, 206, 255]),
        image("mini_map", 118, 138, 186, 160, BG_BLACK, [255, 255, 255, 82], True),
        image("map_grid_v", 118, 138, 1, 152, LONG_LINE, [255, 255, 255, 76], True),
        image("map_grid_h", 118, 138, 154, 1, LONG_LINE, [255, 255, 255, 76], True),
        image("map_corner_mark", 182, 214, 24, 24, ICON_MISC, [255, 255, 255, 116], False),
    ]

    mini_map = next(child for child in left_station["children"] if child["name"] == "mini_map")
    mini_map["children"] = [layout("mini_map_o", 93, 80, 180, 154)]
    mini_map_o = mini_map["children"][0]
    mini_map_o["children"] = [minimap("mini_map_1", 90, 77, 176, 150)]

    toggle_frame = panel("toggle_frame", 158, 248, 316, 42, [15, 18, 26, 92])
    toggle_frame["children"] = [
        image("frame_bg", 158, 21, 316, 38, BG_BLACK, [255, 255, 255, 92], True),
        build_toggle_button("toggle_damage", 58, 21, "屏蔽跳字"),
        build_toggle_button("toggle_sfx", 158, 21, "屏蔽特效"),
        build_toggle_button("toggle_cursor", 258, 21, "大鼠标"),
    ]
    left_station["children"].append(toggle_frame)

    player_attr_list = panel("player_attr_list", 340, 138, 198, 188, [18, 22, 30, 80])
    player_attr_list["children"] = [
        image("section_line", 99, 146, 176, 1, SHOP_LINE, [255, 255, 255, 110], True),
        text("brand_name", 100, 170, 156, 18, "KK!官方对战平台", 14, [236, 241, 247, 255], 0),
        text("brand_site", 100, 152, 120, 14, "kkdzpt.com", 11, [188, 198, 212, 255], 0),
        build_attr_row("battle_power_row", 99, 128, "战力", "135250", "", ICON_ATTACK),
        build_attr_row("hero_attack_row", 99, 104, "攻击", "1263", "53%", STAT_ICON_ATTACK),
        build_attr_row("hero_defense_row", 99, 80, "护甲", "54", "0%", STAT_ICON_DEFENSE),
        build_attr_row("hero_power_row", 99, 56, "力量", "156", "0%", STAT_ICON_SPEED),
        build_attr_row("hero_intelligence_row", 99, 32, "智力", "136", "0%", ICON_DEFENSE),
        build_attr_row("hero_agility_row", 99, 8, "敏捷", "154", "0%", STAT_ICON_MAGIC),
    ]
    left_station["children"].append(player_attr_list)

    center_hub = panel("center_hub", 888, 148, 612, 268, [18, 22, 30, 0])
    center_hub["children"] = []

    hero_panel = panel("hero_panel", 100, 134, 184, 214, [28, 32, 42, 92])
    hero_panel["children"] = [
        image("portrait_frame", 92, 140, 120, 148, HERO_FRAME, [255, 255, 255, 255], False),
        image("hero_portrait", 92, 142, 98, 98, PORTRAIT_MAIN, [255, 255, 255, 255], False),
        text("hero_name", 92, 52, 140, 22, "六边形战士", 18, [246, 248, 251, 255]),
        image("hero_name_line", 92, 66, 120, 1, SHOP_LINE, [255, 255, 255, 106], True),
        image("hero_hp_bg", 92, 26, 146, 18, HP_BAR_BG, [255, 255, 255, 235], True),
        panel("hero_hp_fill", 78, 26, 118, 12, [35, 166, 90, 255]),
        text("hero_hp_text", 92, 26, 130, 14, "3680/3680", 10, [255, 255, 255, 255]),
    ]

    combat_module = panel("combat_module", 404, 134, 400, 214, [18, 22, 30, 96])
    combat_module["children"] = [image("module_line", 200, 194, 388, 1, SHOP_LINE, [255, 255, 255, 96], True)]

    skill_bar = panel("skill_bar", 200, 146, 388, 72, [21, 26, 36, 0])
    skill_bar["children"] = [
        build_reference_skill_slot("skill_slot_1", 42, "1", SKILL_ICON_1),
        build_reference_skill_slot("skill_slot_2", 118, "2", SKILL_ICON_2),
        build_reference_skill_slot("skill_slot_3", 194, "3", SKILL_ICON_3),
        build_reference_skill_slot("skill_slot_4", 270, "4", SKILL_ICON_4),
        build_reference_skill_slot("skill_slot_5", 346, "5", SKILL_ICON_1),
    ]

    buff_row = panel("buff_row", 200, 44, 388, 40, [12, 15, 22, 54])
    buff_row["children"] = [
        build_reference_buff_slot("buff_slot_1", 42, ICON_ITEM_1),
        build_reference_buff_slot("buff_slot_2", 118, ICON_ITEM_2),
        build_reference_buff_slot("buff_slot_3", 194, ICON_ITEM_3),
        build_reference_buff_slot("buff_slot_4", 270, SKILL_ICON_1),
        build_reference_buff_slot("buff_slot_5", 346, SKILL_ICON_3),
    ]

    combat_module["children"].extend(
        [
            skill_bar,
            buff_row,
        ]
    )

    center_hub["children"].extend(
        [
            hero_panel,
            combat_module,
        ]
    )

    right_station = panel("right_station", 1462, 148, 560, 268, [18, 22, 30, 78])
    right_station["children"] = []

    loadout_row = panel("loadout_row", 98, 134, 176, 214, [17, 22, 31, 58])
    loadout_row["children"] = [
        text("loadout_title", 46, 194, 76, 16, "物品栏", 12, [244, 249, 255, 255], 0),
    ]
    loadout_icons = [
        ICON_ITEM_2,
        ICON_ITEM_4,
        ICON_ITEM_3,
        ICON_ITEM_1,
        None,
        None,
    ]
    for index, (x, y, icon_id, highlight) in enumerate(
        [
            (46, 148, loadout_icons[0], True),
            (118, 148, loadout_icons[1], False),
            (46, 92, loadout_icons[2], False),
            (118, 92, loadout_icons[3], False),
            (46, 36, loadout_icons[4], False),
            (118, 36, loadout_icons[5], False),
        ],
        start=1,
    ):
        loadout_row["children"].append(build_reference_grid_slot(f"loadout_slot_{index}", x, y, icon_id, highlight))

    consumable_panel = panel("consumable_panel", 232, 122, 84, 190, [24, 28, 38, 58])
    consumable_panel["children"] = [
        build_reference_consumable_slot("slot_1", 42, 148, "D", "3", ICON_ITEM_1),
        build_reference_consumable_slot("slot_2", 42, 92, "F2", "1", ICON_ITEM_2),
        build_reference_consumable_slot("slot_3", 42, 36, "G", "1", ICON_ITEM_3),
    ]

    card_panel = panel("card_panel", 412, 134, 278, 214, [20, 24, 32, 58])
    card_panel["children"] = [
        image("station_hint_bg", 139, 194, 246, 22, BG_BLACK, [255, 255, 255, 78], True),
        text("station_hint", 139, 194, 236, 14, "F 抽卡   I 已吞   H 进化   P 存档", 10, [232, 236, 242, 255], 0),
        build_reference_action_button("draw_button", 35, 156, "抽卡", "F", "yellow"),
        build_reference_action_button("reward_button", 97, 156, "已吞", "I", "blue"),
        build_reference_action_button("kill_reward_button", 159, 156, "进化", "H", "yellow"),
        build_reference_action_button("fish_button", 221, 156, "存档", "P", "yellow"),
        build_reference_grid_slot("card_slot_1", 35, 102, CARD_SKILL_1, True),
        build_reference_grid_slot("card_slot_2", 97, 102, CARD_SKILL_2, True),
        build_reference_grid_slot("card_slot_3", 159, 102, CARD_SKILL_3, True),
        build_reference_grid_slot("card_slot_4", 221, 102, CARD_SKILL_4, True),
        build_reference_grid_slot("card_slot_5", 35, 38, CARD_SKILL_1, False),
        build_reference_grid_slot("card_slot_6", 97, 38, CARD_SKILL_2, False),
        build_reference_grid_slot("card_slot_7", 159, 38, CARD_SKILL_3, False),
        build_reference_grid_slot("card_slot_8", 221, 38, None, False),
    ]

    right_station["children"].extend(
        [
            loadout_row,
            consumable_panel,
            card_panel,
            build_reference_hover_tip_panel(),
        ]
    )

    canvas["children"] = [shell, left_station, center_hub, right_station]
    root["children"] = [canvas]
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


def main():
    data = build_bottom_hud()
    refresh_pos_percentages(data)
    layout_root = data["children"][0]
    layout_root["pos_data"] = tuple_value(960.0, 540.0, 50.0, 50.0, 1, 1)
    layout_root["adapter_option"] = [True, True, True, True, 0.0, 0.0, 0.0, 0.0]
    layout_root["open_adapter"] = True

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

    panel_pair = {"__tuple__": True, "items": [data["uid"], data["name"]]}
    stale_panel_names = {"BattleBottomHUD", "BattleBottomRightRedo"}
    kept = []
    for item in custom_group.get("group", []):
        name = None
        if isinstance(item, dict) and item.get("__tuple__") is True:
            items = item.get("items", [])
            if len(items) >= 2:
                name = items[1]
        if name not in stale_panel_names:
            kept.append(item)
    kept.append(panel_pair)
    custom_group["group"] = kept

    with PANEL_TREE_INFO_PATH.open("w", encoding="utf-8") as f:
        json.dump(panel_tree_info, f, ensure_ascii=False, indent=1)

    print(f"wrote {UI_PATH}")
    print(f"wrote {TREE_PATH}")
    print(f"updated {PANEL_TREE_INFO_PATH}")


if __name__ == "__main__":
    main()
