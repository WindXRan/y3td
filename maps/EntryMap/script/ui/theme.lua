local M = {}

M.palette = {
  ink = { 7, 12, 20, 236 },
  surface = { 12, 21, 34, 228 },
  surface_soft = { 20, 33, 51, 224 },
  panel = { 18, 29, 45, 232 },
  panel_alt = { 24, 40, 62, 228 },
  panel_deep = { 10, 18, 31, 242 },
  panel_glass = { 16, 28, 45, 208 },
  accent = { 62, 122, 196, 236 },
  accent_soft = { 68, 96, 136, 224 },
  accent_bright = { 96, 176, 255, 255 },
  success = { 78, 136, 96, 236 },
  warning = { 156, 118, 58, 232 },
  danger = { 130, 58, 66, 232 },
  text = { 242, 247, 255, 255 },
  text_soft = { 182, 201, 224, 255 },
  text_muted = { 142, 165, 192, 255 },
  gold = { 255, 236, 186, 255 },
  wood = { 218, 247, 214, 255 },
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
  title = { size = 18, color = M.palette.text },
  subtitle = { size = 14, color = M.palette.text_soft },
  body = { size = 14, color = M.palette.text_soft },
  caption = { size = 12, color = M.palette.text_muted },
  value = { size = 16, color = M.palette.gold },
  gain = { size = 14, color = M.palette.wood },
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
