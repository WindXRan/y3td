local M = {}

M.panel = {
  width = 1480,
  height = 820,
  percent_x = 50,
  percent_y = 55,
}

M.header = {
  shell_width = 1428,
  shell_height = 796,
  title_y = 772,
  title_width = 620,
  title_height = 42,
  hint_y = 728,
  hint_width = 860,
  hint_height = 30,
}

M.card = {
  width = 356,
  height = 584,
  -- stage 内左下角矩形坐标；choice_panel.lua 会先转换成中心锚点再交给 ui.factory
  x = { 152, 562, 972 },
  y = 126,
  badge_width = 96,
  badge_height = 36,
  icon_size = 100,
  body_line_height = 60,
  body_line_count = 4,
}

M.bond = {
  design_width = 300,
  design_height = 445,
  content_left = 38,
  content_width = 224,
  background_width = 300,
  background_height = 445,
  frame_width = 292,
  frame_height = 437,
  badge_y = 414,
  badge_width = 88,
  badge_height = 28,
  set_name_y = 374,
  set_name_width = 190,
  set_name_height = 34,
  set_progress_y = 346,
  set_progress_width = 132,
  set_progress_height = 22,
  icon_frame_y = 288,
  icon_frame_size = 90,
  icon_size = 72,
  item_name_y = 238,
  item_name_width = 224,
  item_name_height = 34,
  bonus_area_y = 182,
  bonus_area_left = 38,
  bonus_width = 224,
  bonus_line_height = 18,
  effect_area_y = 84,
  effect_stack_left = 38,
  effect_area_width = 244,
  effect_area_height = 126,
  effect_area_y_by_bonus_count = {
    [0] = 272,
    [1] = 272,
    [2] = 286,
    [3] = 302,
  },
  effect_index_x = 38,
  effect_index_y = 110,
  effect_index_width = 224,
  effect_index_height = 18,
  effect_name_x = 38,
  effect_name_y = 90,
  effect_name_width = 224,
  effect_name_height = 18,
  effect_body_x = 38,
  effect_body_y = 86,
  effect_body_width = 224,
  effect_body_height = 38,
  set_title_x = 38,
  set_title_y = 42,
  set_title_width = 224,
  set_title_height = 18,
  set_body_x = 38,
  set_body_width = 224,
  set_body_height = 16,
}

M.actions = {
  -- stage 内左下角矩形坐标
  hide_x = 496,
  refresh_x = 764,
  y = 30,
  width = 232,
  height = 64,
}

return M
