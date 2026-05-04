local M = {}

M.palette = {
  ink = { 5, 8, 15, 255 },
  surface = { 10, 15, 25, 240 },
  surface_soft = { 15, 22, 36, 235 },
  panel = { 12, 18, 32, 245 },
  panel_alt = { 18, 26, 45, 240 },
  panel_deep = { 8, 14, 24, 250 },
  panel_glass = { 15, 22, 38, 200 },
  accent = { 100, 149, 237, 255 },
  accent_soft = { 72, 118, 200, 230 },
  accent_bright = { 135, 206, 250, 255 },
  accent_glow = { 100, 170, 255, 180 },
  success = { 80, 200, 120, 240 },
  success_soft = { 60, 160, 96, 230 },
  warning = { 255, 180, 80, 240 },
  warning_soft = { 220, 150, 60, 230 },
  danger = { 255, 100, 100, 240 },
  danger_soft = { 200, 80, 80, 230 },
  text = { 248, 250, 252, 255 },
  text_soft = { 200, 210, 230, 255 },
  text_muted = { 140, 155, 180, 255 },
  gold = { 255, 215, 0, 255 },
  gold_soft = { 255, 190, 50, 240 },
  wood = { 180, 220, 180, 255 },
  purple = { 147, 112, 219, 250 },
  purple_soft = { 120, 90, 180, 230 },
}

M.insets = {
  soft = { 14, 14, 14, 14 },
  normal = { 18, 18, 18, 18 },
  large = { 24, 24, 22, 22 },
}

M.spacing = {
  xs = 4,
  sm = 8,
  md = 12,
  lg = 16,
  xl = 24,
}

M.typography = {
  title = { size = 20, color = M.palette.text },
  subtitle = { size = 15, color = M.palette.text_soft },
  body = { size = 14, color = M.palette.text_soft },
  caption = { size = 12, color = M.palette.text_muted },
  value = { size = 17, color = M.palette.gold },
  gain = { size = 15, color = M.palette.wood },
}

M.components = {
  panel = {
    bg = M.palette.panel,
    border = M.palette.accent_soft,
    title = M.palette.accent_bright,
  },
  button = {
    normal = M.palette.accent,
    hover = M.palette.accent_bright,
    pressed = M.palette.accent_soft,
    disabled = M.palette.surface_soft,
    text = M.palette.text,
  },
  primary_button = {
    normal = M.palette.gold_soft,
    hover = M.palette.gold,
    pressed = M.palette.warning_soft,
    disabled = M.palette.surface_soft,
    text = M.palette.ink,
  },
  secondary_button = {
    normal = M.palette.purple_soft,
    hover = M.palette.purple,
    pressed = { 100, 70, 150, 230 },
    disabled = M.palette.surface_soft,
    text = M.palette.text,
  },
  reward_button = {
    normal = M.palette.warning,
    hover = M.palette.gold,
    text = M.palette.text,
  },
  slot = {
    empty = M.palette.panel_deep,
    filled = M.palette.panel_alt,
    active = M.palette.gold,
    disabled = M.palette.surface,
  },
  tooltip = {
    bg = M.palette.panel_deep,
    title = M.palette.accent_bright,
    body = M.palette.text_soft,
    hint = M.palette.gold,
  },
  progress = {
    bg = M.palette.panel_deep,
    fill = M.palette.accent_bright,
    ready = M.palette.gold,
  },
}

return M
