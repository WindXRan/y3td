local M = {}

function M.is_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

function M.set_visible(ui, visible)
  if M.is_alive(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

function M.set_text(ui, text)
  if M.is_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

function M.set_intercepts(ui, intercepts)
  if M.is_alive(ui) and ui.set_intercepts_operations then
    ui:set_intercepts_operations(intercepts == true)
  end
end

function M.set_text_color(ui, color)
  if M.is_alive(ui) and ui.set_text_color and color then
    ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

function M.set_image_color(ui, color)
  if M.is_alive(ui) and ui.set_image_color and color then
    ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
  end
end

function M.set_image(ui, image)
  if M.is_alive(ui) and ui.set_image and image ~= nil and image ~= '' then
    ui:set_image(image)
  end
end

function M.set_image_url(ui, url, aid)
  if M.is_alive(ui) and ui.set_image_url and type(url) == 'string' and url ~= '' then
    ui:set_image_url(url, aid)
  end
end

return M
