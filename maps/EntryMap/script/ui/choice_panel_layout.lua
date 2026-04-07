local M = {}

M.panel = {
  width = 1360,
  height = 760,
  percent_x = 50,
  percent_y = 54,
}

M.card = {
  width = 332,
  height = 560,
  -- stage 内左下角矩形坐标；choice_panel.lua 会先转换成中心锚点再交给 ui.factory
  x = { 112, 514, 916 },
  y = 136,
  badge_width = 86,
  badge_height = 34,
  icon_size = 92,
  body_line_height = 56,
  body_line_count = 4,
}

M.actions = {
  -- stage 内左下角矩形坐标
  hide_x = 448,
  refresh_x = 720,
  y = 36,
  width = 220,
  height = 60,
}

return M
