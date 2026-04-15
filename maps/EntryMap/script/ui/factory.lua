local ui_res = require 'ui.res'
local skin = require 'ui.skin'
local theme = require 'ui.theme'

local M = {}

local IMAGE_TYPE = '图片'
local TEXT_TYPE = '文本'
local BUTTON_TYPE = '按钮'

function M.create(env)
  local round_number = env.round_number
  local play_ui_click = env.play_ui_click

  local api = {}

  function api.clamp(value, min_value, max_value)
    if value < min_value then
      return min_value
    end
    if value > max_value then
      return max_value
    end
    return value
  end

  function api.scaled(value, scale)
    return round_number(value * scale)
  end

  function api.get_hud_metrics(hud, y3)
    local width = round_number(hud:get_width())
    local height = round_number(hud:get_height())
    if width <= 0 then
      width = round_number(y3.ui.get_window_width())
    end
    if height <= 0 then
      height = round_number(y3.ui.get_window_height())
    end
    return width, height
  end

  function api.get_hud_scale(hud, y3)
    local width, height = api.get_hud_metrics(hud, y3)
    return api.clamp(math.min(width / 1920, height / 1080), 0.82, 1.18)
  end

  function api.set_percent_pos(player, ui, x, y)
    GameAPI.set_ui_comp_pos_percent(player.handle, ui.handle, x, y)
  end

  function api.apply_panel_style(panel, color, insets, image)
    local applied_color = color or theme.palette.surface
    local applied_insets = insets or theme.insets.normal
    panel:set_image(image or ui_res.common.empty)
    panel:set_image_color(
      applied_color[1],
      applied_color[2],
      applied_color[3],
      applied_color[4] or 255
    )
    panel:set_ui_9_enable(true)
    panel:set_ui_9(
      applied_insets[1],
      applied_insets[2],
      applied_insets[3],
      applied_insets[4]
    )
    return panel
  end

  function api.create_panel(parent, x, y, width, height, color, insets, z_order, image)
    local panel = parent:create_child(IMAGE_TYPE)
    panel:set_ui_size(width, height)
    panel:set_pos(x, y)
    api.apply_panel_style(panel, color, insets, image)
    if z_order then
      panel:set_z_order(z_order)
    end
    return panel
  end

  function api.create_text(parent, x, y, width, height, font_size, color, h_align, v_align, z_order)
    local text = parent:create_child(TEXT_TYPE)
    local applied_color = color or theme.palette.text
    text:set_ui_size(width, height)
    text:set_pos(x, y)
    text:set_font_size(font_size)
    text:set_text_color(
      applied_color[1],
      applied_color[2],
      applied_color[3],
      applied_color[4] or 255
    )
    text:set_text_alignment(h_align or '中', v_align or '中')
    if z_order then
      text:set_z_order(z_order)
    end
    return text
  end

  function api.create_button(parent, x, y, width, height, label, callback, options)
    local opts = options or {}
    local style = skin.get_button_style(opts.style)
    local status_images = opts.status_images or style.status_images or {}
    local text_color = opts.text_color or style.text_color or { 245, 248, 255, 255 }

    local shadow = api.create_panel(
      parent,
      x,
      y - (opts.shadow_offset_y or 3),
      width + (opts.shadow_grow or 10),
      height + (opts.shadow_grow or 10),
      opts.shadow_color or style.shadow_color or { 4, 8, 16, 110 },
      theme.insets.soft,
      opts.shadow_z or 9700,
      opts.shadow_image or style.shadow_image
    )
    local bg = api.create_panel(
      parent,
      x,
      y,
      width,
      height,
      opts.bg_color or style.bg_color or theme.palette.accent_soft,
      opts.insets or theme.insets.normal,
      opts.bg_z or 9701,
      opts.bg_image or style.bg_image
    )
    local button = parent:create_child(BUTTON_TYPE)
    button:set_ui_size(width, height)
    button:set_pos(x, y)
    button:set_text(label)
    button:set_font_size(opts.font_size or 16)
    button:set_text_color(text_color[1], text_color[2], text_color[3], text_color[4] or 255)
    button:set_btn_status_image(1, status_images.normal or ui_res.common_tip.btn_blue_normal)
    button:set_btn_status_image(2, status_images.hover or ui_res.common_tip.btn_blue_hover)
    button:set_btn_status_image(3, status_images.press or ui_res.common_tip.btn_blue_press)
    button:set_btn_status_image(4, status_images.disabled or ui_res.common_tip.btn_blue_disabled)
    button:set_z_order(opts.button_z or 9702)
    button:add_fast_event('左键-点击', function()
      if play_ui_click then
        play_ui_click()
      end
      callback()
    end)

    return {
      shadow = shadow,
      bg = bg,
      button = button,
    }
  end

  return api
end

return M
