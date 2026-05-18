local M = {}

local y3

function M.init(env)
  y3 = env and env.y3 or _G.y3
end

function M.resolve_ui(path)
  local ok, ui = pcall(y3.ui.get_ui, env.get_player(), path)
  if not ok or not ui then
    return nil
  end
  return ui
end

function M.resolve_ui_first(paths)
  if type(paths) ~= 'table' then
    return nil
  end
  for _, path in ipairs(paths) do
    local ui = M.resolve_ui(path)
    if M.is_ui_alive(ui) then
      return ui
    end
  end
  return nil
end

function M.resolve_outgame_ui(path)
  return M.resolve_ui_first({
    'DifficultyHUD' .. path,
    'outgame' .. path,
  })
end

function M.is_ui_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

function M.set_visible_if_alive(ui, visible)
  if M.is_ui_alive(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

function M.set_text_if_alive(ui, text)
  if M.is_ui_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

function M.set_intercepts_if_alive(ui, intercepts)
  if M.is_ui_alive(ui) and ui.set_intercepts_operations then
    ui:set_intercepts_operations(intercepts == true)
  end
end

function M.set_z_order_if_alive(ui, z_order)
  if M.is_ui_alive(ui) and ui.set_z_order then
    ui:set_z_order(z_order)
  end
end

function M.set_parent_if_alive(ui, parent_ui)
  if M.is_ui_alive(ui) and M.is_ui_alive(parent_ui) and ui.set_ui_comp_parent and parent_ui.handle then
    ui:set_ui_comp_parent(parent_ui.handle, false, true, true)
    return true
  end
  return false
end

function M.set_relative_scale_if_alive(ui, scale_x, scale_y)
  if M.is_ui_alive(ui) and ui.set_widget_relative_scale then
    ui:set_widget_relative_scale(scale_x or 1, scale_y or scale_x or 1)
  end
end

function M.set_text_color_if_alive(ui, color)
  if M.is_ui_alive(ui) and ui.set_text_color and color then
    ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

function M.set_font_size_if_alive(ui, size)
  if M.is_ui_alive(ui) and ui.set_font_size and size then
    ui:set_font_size(size)
  end
end

function M.set_text_alignment_if_alive(ui, horizontal, vertical)
  if M.is_ui_alive(ui) and ui.set_text_alignment then
    ui:set_text_alignment(horizontal, vertical)
  end
end

function M.set_ui_size_if_alive(ui, width, height)
  if M.is_ui_alive(ui) and ui.set_ui_size then
    ui:set_ui_size(width, height)
  end
end

function M.set_image_color_if_alive(ui, color)
  if M.is_ui_alive(ui) and ui.set_image_color and color then
    ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
  end
end

function M.set_image_if_alive(ui, image)
  if M.is_ui_alive(ui) and ui.set_image and image ~= nil and image ~= '' then
    ui:set_image(image)
  end
end

function M.set_image_url_if_alive(ui, url, aid)
  if M.is_ui_alive(ui) and ui.set_image_url and type(url) == 'string' and url ~= '' then
    ui:set_image_url(url, aid)
  end
end

function M.parse_stage_id(stage_id)
  local chapter_text, stage_text = tostring(stage_id or ''):match('^(%d+)%-(%d+)$')
  return tonumber(chapter_text), tonumber(stage_text)
end

function M.to_archive_integer(value)
  local number = tonumber(value) or 0
  return math.max(0, math.floor(number))
end

function M.to_non_negative_integer(value)
  local number = tonumber(value) or 0
  return math.max(0, math.floor(number))
end

function M.archive_item_profile_key(spec)
  if type(spec) ~= 'table' then
    return ''
  end
  return table.concat({
    tostring(spec.partition or ''),
    tostring(spec.primary or spec.l1_tab or ''),
    tostring(spec.title or spec.name or ''),
  }, '|')
end

function M.get_window_metrics()
  local width = tonumber(y3.ui.get_window_width and y3.ui.get_window_width() or nil) or 1920
  local height = tonumber(y3.ui.get_window_height and y3.ui.get_window_height() or nil) or 1080
  return width, height
end

return M