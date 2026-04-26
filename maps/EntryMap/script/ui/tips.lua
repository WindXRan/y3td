local UIRoot = require 'ui.ui_root'

local M = {}

local DEFAULTS = {
  width = 168,
  height = 116,
  duration = 0.9,
  z_order = 9800,
  text = '金币不足',
  font_size = 24,
  text_color = { 255, 49, 104, 255 },
  shadow_color = { 65, 9, 28, 210 },
  line_count = 5,
  line_gap = 18,
  rise = 38,
}
local CENTER_BANNER_DEFAULTS = {
  width = 760,
  height = 74,
  duration = 1.15,
  z_order = 9850,
  text = '木头不足，无法抽卡！',
  font_size = 28,
  bg_color = { 13, 13, 13, 238 },
  border_color = { 0, 0, 0, 255 },
  text_color = { 255, 63, 78, 255 },
  shadow_color = { 45, 0, 6, 230 },
}

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function call_ui(ui, method_name, ...)
  if not is_alive(ui) then
    return false
  end
  local method = ui[method_name]
  if type(method) ~= 'function' then
    return false
  end
  return pcall(method, ui, ...)
end

local function color_at(color, index, fallback)
  return color and color[index] or fallback
end

local function apply_text_style(ui, text, font_size, color)
  if not is_alive(ui) then
    return
  end
  call_ui(ui, 'set_text', text)
  call_ui(ui, 'set_font_size', font_size)
  call_ui(ui, 'set_text_alignment', '中', '中')
  call_ui(ui, 'set_text_color',
    color_at(color, 1, 255),
    color_at(color, 2, 255),
    color_at(color, 3, 255),
    color_at(color, 4, 255))
  call_ui(ui, 'set_intercepts_operations', false)
end

local function try_create_prefab(y3, player, parent, prefab_name)
  if not prefab_name or prefab_name == '' then
    return nil, nil
  end
  if not y3 or not y3.ui_prefab or type(y3.ui_prefab.create) ~= 'function' then
    return nil, nil
  end
  local ok, prefab = pcall(y3.ui_prefab.create, player, prefab_name, parent)
  if not ok or not prefab then
    return nil, nil
  end
  local root = prefab.get_child and prefab:get_child() or nil
  if not is_alive(root) then
    if prefab.remove then
      pcall(prefab.remove, prefab)
    end
    return nil, nil
  end
  return prefab, root
end

local function create_dynamic_root(parent, width, height)
  if not is_alive(parent) or type(parent.create_child) ~= 'function' then
    return nil
  end
  local ok, root = pcall(parent.create_child, parent, '图片')
  if not ok or not is_alive(root) then
    return nil
  end
  call_ui(root, 'set_image', 999)
  call_ui(root, 'set_image_color', 255, 255, 255, 0)
  call_ui(root, 'set_ui_size', width, height)
  call_ui(root, 'set_intercepts_operations', false)
  return root
end

local function create_child(parent, ui_type)
  if not is_alive(parent) or type(parent.create_child) ~= 'function' then
    return nil
  end
  local ok, child = pcall(parent.create_child, parent, ui_type)
  if not ok or not is_alive(child) then
    return nil
  end
  return child
end

local function remove_later(y3, ui, prefab, duration)
  if not y3 or not y3.ltimer or type(y3.ltimer.wait) ~= 'function' then
    return
  end
  y3.ltimer.wait(duration, function()
    if prefab and prefab.remove then
      pcall(prefab.remove, prefab)
      return
    end
    if is_alive(ui) and ui.remove then
      pcall(ui.remove, ui)
    end
  end)
end

local function animate_absolute_rise(y3, ui, start_x, start_y, rise, duration)
  if not y3 or not y3.ltimer or type(y3.ltimer.loop_count) ~= 'function' then
    return false
  end
  local steps = math.max(1, math.floor((tonumber(duration) or 0.8) / 0.03))
  y3.ltimer.loop_count(0.03, steps, function(_, current)
    if not is_alive(ui) then
      return
    end
    local ratio = math.max(0, math.min(1, (tonumber(current) or 1) / steps))
    local y = start_y + rise * ratio
    call_ui(ui, 'set_absolute_pos', start_x, y)
    call_ui(ui, 'set_alpha', math.max(0, math.floor(100 - 100 * ratio + 0.5)))
  end)
  return true
end

function M.show_floating_text(env, options)
  env = env or {}
  options = options or {}
  local y3 = env.y3
  local player = options.player or (env.get_player and env.get_player()) or nil
  local parent = options.parent_ui
  if not parent and player then
    parent = UIRoot.get_overlay_parent(y3, player)
  end
  if not player or not is_alive(parent) then
    return nil
  end

  local width = tonumber(options.width) or DEFAULTS.width
  local height = tonumber(options.height) or DEFAULTS.height
  local duration = tonumber(options.duration) or DEFAULTS.duration
  local start_x = tonumber(options.x) or 960
  local start_y = tonumber(options.y) or 540
  local rise = tonumber(options.rise) or DEFAULTS.rise
  local text = tostring(options.text or DEFAULTS.text)
  local font_size = tonumber(options.font_size) or DEFAULTS.font_size
  local text_color = options.text_color or DEFAULTS.text_color
  local shadow_color = options.shadow_color or DEFAULTS.shadow_color
  local line_count = math.max(1, tonumber(options.line_count) or DEFAULTS.line_count)
  local line_gap = tonumber(options.line_gap) or DEFAULTS.line_gap
  local prefab, root = try_create_prefab(y3, player, parent, options.prefab_name)

  if not is_alive(root) then
    root = create_dynamic_root(parent, width, height)
  end
  if not is_alive(root) then
    return nil
  end

  call_ui(root, 'set_ui_size', width, height)
  call_ui(root, 'set_anchor', 0.5, 0.5)
  call_ui(root, 'set_pos', start_x, start_y)
  call_ui(root, 'set_absolute_pos', start_x, start_y)
  call_ui(root, 'set_z_order', tonumber(options.z_order) or DEFAULTS.z_order)
  call_ui(root, 'set_visible', true)
  call_ui(root, 'set_intercepts_operations', false)
  if not animate_absolute_rise(y3, root, start_x, start_y, rise, duration) then
    call_ui(root, 'set_anim_pos', start_x, start_y, start_x, start_y + rise, duration, options.ease_type or 0)
    call_ui(root, 'set_anim_opacity', 100, 0, duration, options.ease_type or 0)
  end

  for index = 1, line_count do
    local y = height - 16 - (index - 1) * line_gap
    local shadow = create_child(root, '文本')
    call_ui(shadow, 'set_ui_size', width, line_gap + 6)
    call_ui(shadow, 'set_pos', width / 2 + 2, y - 2)
    apply_text_style(shadow, text, font_size, shadow_color)

    local label = create_child(root, '文本')
    call_ui(label, 'set_ui_size', width, line_gap + 6)
    call_ui(label, 'set_pos', width / 2, y)
    apply_text_style(label, text, font_size, text_color)
  end

  remove_later(y3, root, prefab, duration + 0.08)
  return root
end

function M.show_insufficient_gold(env, options)
  options = options or {}
  options.text = options.text or '金币不足'
  options.text_color = options.text_color or { 255, 49, 104, 255 }
  options.shadow_color = options.shadow_color or { 62, 8, 27, 220 }
  options.line_count = options.line_count or 5
  return M.show_floating_text(env, options)
end

function M.show_center_banner(env, options)
  env = env or {}
  options = options or {}
  local y3 = env.y3
  local player = options.player or (env.get_player and env.get_player()) or nil
  local parent = options.parent_ui
  if not parent and player then
    parent = UIRoot.get_overlay_parent(y3, player)
  end
  if not player or not is_alive(parent) then
    return nil
  end

  local width = tonumber(options.width) or CENTER_BANNER_DEFAULTS.width
  local height = tonumber(options.height) or CENTER_BANNER_DEFAULTS.height
  local duration = tonumber(options.duration) or CENTER_BANNER_DEFAULTS.duration
  local start_x = tonumber(options.x) or 960
  local start_y = tonumber(options.y) or 858
  local text = tostring(options.text or CENTER_BANNER_DEFAULTS.text)
  local font_size = tonumber(options.font_size) or CENTER_BANNER_DEFAULTS.font_size
  local bg_color = options.bg_color or CENTER_BANNER_DEFAULTS.bg_color
  local border_color = options.border_color or CENTER_BANNER_DEFAULTS.border_color
  local text_color = options.text_color or CENTER_BANNER_DEFAULTS.text_color
  local shadow_color = options.shadow_color or CENTER_BANNER_DEFAULTS.shadow_color
  local prefab, root = try_create_prefab(y3, player, parent, options.prefab_name)

  if not is_alive(root) then
    root = create_dynamic_root(parent, width, height)
  end
  if not is_alive(root) then
    return nil
  end

  call_ui(root, 'set_ui_size', width, height)
  call_ui(root, 'set_anchor', 0.5, 0.5)
  call_ui(root, 'set_pos', start_x, start_y)
  call_ui(root, 'set_absolute_pos', start_x, start_y)
  call_ui(root, 'set_z_order', tonumber(options.z_order) or CENTER_BANNER_DEFAULTS.z_order)
  call_ui(root, 'set_visible', true)
  call_ui(root, 'set_intercepts_operations', false)
  call_ui(root, 'set_anim_opacity', 100, 0, duration, options.ease_type or 0)

  local border = create_child(root, '图片')
  call_ui(border, 'set_image', 999)
  call_ui(border, 'set_ui_size', width, height)
  call_ui(border, 'set_pos', width / 2, height / 2)
  call_ui(border, 'set_image_color',
    color_at(border_color, 1, 0),
    color_at(border_color, 2, 0),
    color_at(border_color, 3, 0),
    color_at(border_color, 4, 255))

  local bg = create_child(root, '图片')
  call_ui(bg, 'set_image', 999)
  call_ui(bg, 'set_ui_size', width - 6, height - 6)
  call_ui(bg, 'set_pos', width / 2, height / 2)
  call_ui(bg, 'set_image_color',
    color_at(bg_color, 1, 13),
    color_at(bg_color, 2, 13),
    color_at(bg_color, 3, 13),
    color_at(bg_color, 4, 238))

  local shadow = create_child(root, '文本')
  call_ui(shadow, 'set_ui_size', width, height)
  call_ui(shadow, 'set_pos', width / 2 + 2, height / 2 - 2)
  apply_text_style(shadow, text, font_size, shadow_color)

  local label = create_child(root, '文本')
  call_ui(label, 'set_ui_size', width, height)
  call_ui(label, 'set_pos', width / 2, height / 2)
  apply_text_style(label, text, font_size, text_color)

  remove_later(y3, root, prefab, duration + 0.08)
  return root
end

return M
