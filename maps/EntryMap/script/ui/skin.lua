local ui_res = require 'ui.res'
local theme = require 'ui.theme'

local M = {}

M.images = (ui_res.skin and ui_res.skin.images) or {}

local default_button_images = {
  normal = ui_res.common_tip.btn_blue_normal,
  hover = ui_res.common_tip.btn_blue_hover,
  press = ui_res.common_tip.btn_blue_press,
  disabled = ui_res.common_tip.btn_blue_disabled,
}

local button_slots = (ui_res.skin and ui_res.skin.buttons) or {}

local function get_status_images(slot_name)
  local slot = button_slots[slot_name] or button_slots.primary or default_button_images
  return {
    normal = slot.normal or default_button_images.normal,
    hover = slot.hover or default_button_images.hover,
    press = slot.press or default_button_images.press,
    disabled = slot.disabled or default_button_images.disabled,
  }
end

M.button_styles = {
  primary = {
    status_images = get_status_images('primary'),
    bg_color = theme.palette.accent_soft,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
  },
  outgame_mode_primary = {
    status_images = get_status_images('primary'),
    bg_color = theme.palette.accent_soft,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
  },
  outgame_mode_secondary = {
    status_images = get_status_images('secondary'),
    bg_color = theme.palette.panel_alt,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
  },
  outgame_start = {
    status_images = get_status_images('success'),
    bg_color = theme.palette.success,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.outgame and M.images.outgame.start_button_bg or nil,
    shadow_image = M.images.outgame and M.images.outgame.start_button_shadow or nil,
  },
  runtime_action = {
    status_images = get_status_images('primary'),
    bg_color = theme.palette.accent_soft,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.runtime_hud and M.images.runtime_hud.action_button_bg or nil,
    shadow_image = M.images.runtime_hud and M.images.runtime_hud.action_button_shadow or nil,
  },
  choice_panel_action = {
    status_images = get_status_images('primary'),
    bg_color = theme.palette.accent_soft,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.choice_panel and M.images.choice_panel.action_button_bg or nil,
    shadow_image = M.images.choice_panel and M.images.choice_panel.action_button_shadow or nil,
  },
  runtime_trial_gold = {
    status_images = get_status_images('primary'),
    bg_color = { 126, 104, 52, 224 },
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_bg or nil,
    shadow_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_shadow or nil,
  },
  runtime_trial_wood = {
    status_images = get_status_images('primary'),
    bg_color = { 74, 118, 86, 224 },
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_bg or nil,
    shadow_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_shadow or nil,
  },
  runtime_trial_exp = {
    status_images = get_status_images('primary'),
    bg_color = { 74, 98, 146, 224 },
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_bg or nil,
    shadow_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_shadow or nil,
  },
  runtime_trial_treasure = {
    status_images = get_status_images('primary'),
    bg_color = { 128, 90, 68, 224 },
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
    bg_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_bg or nil,
    shadow_image = M.images.runtime_hud and M.images.runtime_hud.trial_button_shadow or nil,
  },
  overview_close = {
    status_images = get_status_images('secondary'),
    bg_color = theme.palette.accent_soft,
    shadow_color = { 4, 8, 16, 110 },
    text_color = { 245, 248, 255, 255 },
  },
}

function M.get_button_style(style_name)
  return M.button_styles[style_name] or M.button_styles.primary
end

return M
