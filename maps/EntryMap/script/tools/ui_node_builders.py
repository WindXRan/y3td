#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import uuid


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


def text(name, x, y, width, height, value, font_size, color, align_h=1):
    node = base_node(name, 3, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["alignment"] = tuple_value(align_h, 8)
    node["bold"] = False
    node["border"] = False
    node["font"] = tuple_value("MSYH", font_size)
    node["font_color"] = tuple_value(*color)
    node["font_min_size"] = 15
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


def button(name, x, y, width, height, value):
    node = base_node(name, 1, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["normal_picture"] = 107525
    node["suspend_picture"] = 107526
    node["press_picture"] = 107527
    node["disabled_picture"] = 107528
    node["normal_text"] = tuple_value(value, False)
    node["suspend_text"] = tuple_value(value, False)
    node["press_text"] = tuple_value(value, False)
    node["disabled_text"] = tuple_value(value, False)
    node["font"] = tuple_value("MSYH", 20)
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


def scroll(name, x, y, width, height):
    node = base_node(name, 10, x, y, width, height)
    node["adapter_option"] = [False, False, False, False, 0, 0, 0, 0]
    node["anchor"] = tuple_value(0.5, 0.5)
    node["color"] = tuple_value(255, 255, 255, 0)
    node["clip_enabled"] = False
    node["clipping_type"] = 1
    node["open_adapter"] = False
    node["swallow_touches"] = False
    return node
