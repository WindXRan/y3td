local ui_res = require 'ui.res'
local skin = require 'ui.skin'
local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local layout = require 'ui.choice_panel_layout'

local M = {}

local IMAGE_TYPE = '图片'
local TEXT_TYPE = '文本'
local BUTTON_TYPE = '按钮'

local BODY_COLORS = {
  green = { 86, 255, 92, 255 },
  gold = { 255, 216, 74, 255 },
  cyan = { 118, 248, 255, 255 },
  white = { 226, 232, 238, 255 },
  blue = { 39, 157, 255, 255 },
  dim = { 154, 154, 154, 255 },
}

local QUALITY_PALETTES = {
  common = {
    badge = { 62, 255, 68, 255 },
    title = { 255, 210, 50, 255 },
    subtitle = { 62, 255, 68, 255 },
    frame_color = { 76, 255, 82, 255 },
  },
  rare = {
    badge = { 40, 149, 255, 255 },
    title = { 255, 210, 50, 255 },
    subtitle = { 40, 149, 255, 255 },
    frame_color = { 40, 149, 255, 255 },
  },
  epic = {
    badge = { 198, 120, 255, 255 },
    title = { 255, 210, 50, 255 },
    subtitle = { 198, 120, 255, 255 },
    frame_color = { 198, 120, 255, 255 },
  },
}

local function get_body_color(color_name)
  return BODY_COLORS[color_name or 'white'] or BODY_COLORS.white
end

local function get_quality_palette(quality)
  return QUALITY_PALETTES[quality or 'common'] or QUALITY_PALETTES.common
end

local function get_panel_title(kind)
  if kind == 'upgrade' then
    return '技能强化'
  end
  if kind == 'bond' then
    return '羁绊抽卡'
  end
  if kind == 'treasure_replace' then
    return '替换宝物'
  end
  if kind == 'treasure' then
    return '宝物候选'
  end
  return '三选一奖励'
end

local function get_panel_hint(model)
  if model and model.kind == 'treasure_replace' then
    return '点击一张卡，指定要被替换的宝物位'
  end
  return '点击卡片或按 1 / 2 / 3 选择'
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local factory = Factory.create(env)

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local create_button = factory.create_button
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local set_percent_pos = factory.set_percent_pos

  local choice_skin = skin.images.choice_panel or {}
  local refresh_panel

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function is_panel_alive(panel)
    return panel and panel.root and not panel.root:is_removed()
  end

  local function set_card_visible(card, visible)
    card.shadow:set_visible(visible)
    card.bg:set_visible(visible)
    card.frame:set_visible(visible)
    card.badge_bg:set_visible(visible)
    card.badge_text:set_visible(visible)
    card.title_text:set_visible(visible)
    card.progress_text:set_visible(visible)
    card.icon_frame:set_visible(visible)
    card.icon:set_visible(visible)
    card.subtitle_text:set_visible(visible)
    card.button:set_visible(visible)
    card.button:set_button_enable(visible and not STATE.game_finished)
    for _, line in ipairs(card.body_lines) do
      line:set_visible(visible)
    end
  end

  local function set_action_button_state(button_ref, visible, enabled, label)
    button_ref.shadow:set_visible(visible)
    button_ref.bg:set_visible(visible)
    button_ref.button:set_visible(visible)
    if not visible then
      return
    end

    button_ref.button:set_text(label or '')
    button_ref.button:set_button_enable(enabled == true)
    if enabled == true then
      button_ref.bg:set_image_color(58, 74, 98, 230)
      button_ref.shadow:set_image_color(8, 12, 22, 124)
      button_ref.button:set_text_color(245, 248, 255, 255)
    else
      button_ref.bg:set_image_color(42, 42, 42, 218)
      button_ref.shadow:set_image_color(8, 12, 22, 90)
      button_ref.button:set_text_color(142, 146, 154, 255)
    end
  end

  local function get_refresh_label(refresh)
    if not refresh or refresh.visible == false then
      return ''
    end
    if refresh.enabled ~= true then
      return '刷新'
    end
    if (refresh.free_left or 0) > 0 then
      return string.format('刷新 免费%d', refresh.free_left)
    end
    return string.format('刷新 木%d', refresh.wood_cost or 0)
  end

  local function rect_center(left, bottom, width, height)
    return left + width * 0.5, bottom + height * 0.5
  end

  local function create_rect_panel(parent, left, bottom, width, height, color, insets, z_order, image)
    local center_x, center_y = rect_center(left, bottom, width, height)
    return create_panel(parent, center_x, center_y, width, height, color, insets, z_order, image)
  end

  local function create_rect_button(parent, left, bottom, width, height, label, callback, options)
    local center_x, center_y = rect_center(left, bottom, width, height)
    return create_button(parent, center_x, center_y, width, height, label, callback, options)
  end

  local function create_choice_card(parent, left, bottom, width, height, index, scale)
    local shadow = create_rect_panel(
      parent,
      left - scaled(4, scale),
      bottom - scaled(6, scale),
      width + scaled(8, scale),
      height + scaled(8, scale),
      { 4, 8, 16, 124 },
      theme.insets.soft,
      9810
    )
    local bg = create_rect_panel(
      parent,
      left,
      bottom,
      width,
      height,
      { 28, 28, 30, 238 },
      theme.insets.normal,
      9811,
      choice_skin.card_bg
    )
    local frame = create_rect_panel(
      parent,
      left,
      bottom,
      width,
      height,
      { 98, 102, 108, 224 },
      theme.insets.soft,
      9812,
      choice_skin.card_frame_common
    )
    frame:set_image_color(98, 102, 108, 224)

    local badge_bg = create_panel(
      parent,
      left + scaled(123, scale),
      bottom + height - scaled(26, scale),
      scaled(layout.card.badge_width, scale),
      scaled(layout.card.badge_height, scale),
      { 38, 38, 40, 255 },
      theme.insets.normal,
      9813,
      choice_skin.badge_bg_common
    )
    badge_bg:set_anchor(0.5, 0.5)
    local badge_text = create_text(
      parent,
      left + scaled(123, scale),
      bottom + height - scaled(26, scale),
      scaled(layout.card.badge_width, scale),
      scaled(layout.card.badge_height, scale),
      scaled(22, scale),
      { 86, 255, 92, 255 },
      '中',
      '中',
      9814
    )
    badge_text:set_anchor(0.5, 0.5)

    local title_text = create_text(
      parent,
      left + scaled(166, scale),
      bottom + height - scaled(86, scale),
      scaled(260, scale),
      scaled(30, scale),
      scaled(22, scale),
      { 255, 210, 50, 255 },
      '中',
      '中',
      9814
    )
    title_text:set_anchor(0.5, 0.5)
    local progress_text = create_text(
      parent,
      left + scaled(166, scale),
      bottom + height - scaled(118, scale),
      scaled(160, scale),
      scaled(22, scale),
      scaled(16, scale),
      BODY_COLORS.dim,
      '中',
      '中',
      9814
    )
    progress_text:set_anchor(0.5, 0.5)

    local icon_frame = create_panel(
      parent,
      left + scaled(166, scale),
      bottom + height - scaled(194, scale),
      scaled(layout.card.icon_size + 8, scale),
      scaled(layout.card.icon_size + 8, scale),
      { 72, 255, 82, 255 },
      theme.insets.soft,
      9813,
      choice_skin.icon_frame
    )
    icon_frame:set_anchor(0.5, 0.5)
    local icon = parent:create_child(IMAGE_TYPE)
    icon:set_ui_size(scaled(layout.card.icon_size, scale), scaled(layout.card.icon_size, scale))
    icon:set_pos(left + scaled(166, scale), bottom + height - scaled(194, scale))
    icon:set_anchor(0.5, 0.5)
    icon:set_z_order(9814)

    local subtitle_text = create_text(
      parent,
      left + scaled(166, scale),
      bottom + height - scaled(252, scale),
      scaled(240, scale),
      scaled(28, scale),
      scaled(20, scale),
      { 86, 255, 92, 255 },
      '中',
      '中',
      9814
    )
    subtitle_text:set_anchor(0.5, 0.5)

    local body_lines = {}
    for line_index = 1, layout.card.body_line_count, 1 do
      local line = create_text(
        parent,
        left + scaled(28, scale),
        bottom + height - scaled(308, scale) - scaled((line_index - 1) * layout.card.body_line_height, scale),
        scaled(276, scale),
        scaled(layout.card.body_line_height, scale),
        scaled(16, scale),
        BODY_COLORS.white,
        '左',
        '上',
        9814
      )
      body_lines[#body_lines + 1] = line
    end

    local button_center_x, button_center_y = rect_center(left, bottom, width, height)
    local button = parent:create_child(BUTTON_TYPE)
    button:set_ui_size(width, height)
    button:set_pos(button_center_x, button_center_y)
    button:set_anchor(0.5, 0.5)
    button:set_text('')
    button:set_btn_status_image(1, ui_res.common.empty)
    button:set_btn_status_image(2, ui_res.common.empty)
    button:set_btn_status_image(3, ui_res.common.empty)
    button:set_btn_status_image(4, ui_res.common.empty)
    button:set_z_order(9815)
    button:add_fast_event('左键-点击', function()
      if env.apply_round_choice then
        env.apply_round_choice(index)
      end
      refresh_panel()
    end)

    return {
      shadow = shadow,
      bg = bg,
      frame = frame,
      badge_bg = badge_bg,
      badge_text = badge_text,
      title_text = title_text,
      progress_text = progress_text,
      icon_frame = icon_frame,
      icon = icon,
      subtitle_text = subtitle_text,
      body_lines = body_lines,
      button = button,
    }
  end

  local function create_choice_panel()
    local hud = get_hud_root()
    if not hud then
      return nil
    end

    if is_panel_alive(STATE.choice_panel) then
      refresh_panel()
      return STATE.choice_panel
    end

    local scale = get_hud_scale(hud, y3)

    local root = hud:create_child(IMAGE_TYPE)
    root:set_image(ui_res.common.empty)
    root:set_relative_parent_pos('顶部', 0)
    root:set_relative_parent_pos('底部', 0)
    root:set_relative_parent_pos('左侧', 0)
    root:set_relative_parent_pos('右侧', 0)
    root:set_image_color(255, 255, 255, 0)
    root:set_z_order(9800)
    root:set_intercepts_operations(true)

    local backdrop = create_panel(
      root,
      0,
      0,
      scaled(layout.panel.width + 96, scale),
      scaled(layout.panel.height + 72, scale),
      { 6, 10, 18, 108 },
      theme.insets.large,
      9800,
      choice_skin.overlay
    )
    backdrop:set_anchor(0.5, 0.5)
    set_percent_pos(env.get_player(), backdrop, layout.panel.percent_x, layout.panel.percent_y)

    local stage = create_panel(
      root,
      0,
      0,
      scaled(layout.panel.width, scale),
      scaled(layout.panel.height, scale),
      { 0, 0, 0, 0 },
      theme.insets.large,
      9801,
      choice_skin.panel_bg
    )
    stage:set_anchor(0.5, 0.5)
    set_percent_pos(env.get_player(), stage, layout.panel.percent_x, layout.panel.percent_y)

    local cards = {
      create_choice_card(
        stage,
        scaled(layout.card.x[1], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        1,
        scale
      ),
      create_choice_card(
        stage,
        scaled(layout.card.x[2], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        2,
        scale
      ),
      create_choice_card(
        stage,
        scaled(layout.card.x[3], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        3,
        scale
      ),
    }

    local title_text = create_text(
      stage,
      scaled(layout.panel.width * 0.5, scale),
      scaled(layout.panel.height - 42, scale),
      scaled(480, scale),
      scaled(30, scale),
      scaled(26, scale),
      { 244, 247, 255, 255 },
      '中',
      '中',
      9816
    )
    title_text:set_anchor(0.5, 0.5)

    local hint_text = create_text(
      stage,
      scaled(layout.panel.width * 0.5, scale),
      scaled(layout.panel.height - 76, scale),
      scaled(620, scale),
      scaled(24, scale),
      scaled(14, scale),
      BODY_COLORS.dim,
      '中',
      '中',
      9816
    )
    hint_text:set_anchor(0.5, 0.5)

    local hide_button = create_rect_button(
      stage,
      scaled(layout.actions.hide_x, scale),
      scaled(layout.actions.y, scale),
      scaled(layout.actions.width, scale),
      scaled(layout.actions.height, scale),
      '暂时隐藏',
      function()
        if env.hide_current_choice_panel then
          env.hide_current_choice_panel()
        end
        refresh_panel()
      end,
      {
        font_size = scaled(22, scale),
        style = 'choice_panel_action',
      }
    )

    local refresh_button = create_rect_button(
      stage,
      scaled(layout.actions.refresh_x, scale),
      scaled(layout.actions.y, scale),
      scaled(layout.actions.width, scale),
      scaled(layout.actions.height, scale),
      '刷新',
      function()
        if env.refresh_current_choice_panel then
          env.refresh_current_choice_panel()
        end
        refresh_panel()
      end,
      {
        font_size = scaled(22, scale),
        style = 'choice_panel_action',
      }
    )

    STATE.choice_panel = {
      root = root,
      backdrop = backdrop,
      stage = stage,
      cards = cards,
      title_text = title_text,
      hint_text = hint_text,
      hide_button = hide_button,
      refresh_button = refresh_button,
    }

    refresh_panel()
    return STATE.choice_panel
  end

  local function destroy_panel()
    local panel = STATE.choice_panel
    if panel and panel.root and not panel.root:is_removed() then
      panel.root:remove()
    end
    STATE.choice_panel = nil
  end

  refresh_panel = function()
    local panel = STATE.choice_panel
    if not is_panel_alive(panel) then
      return nil
    end

    local model = env.get_current_choice_panel_model and env.get_current_choice_panel_model() or nil
    local visible = model ~= nil and STATE.session_phase == 'battle'
    panel.root:set_visible(visible)
    if not visible then
      return panel
    end

    if panel.title_text then
      panel.title_text:set_text(get_panel_title(model.kind))
    end
    if panel.hint_text then
      panel.hint_text:set_text(get_panel_hint(model))
    end

    for index, card in ipairs(panel.cards) do
      local card_model = model.cards and model.cards[index] or nil
      local card_visible = card_model ~= nil
      set_card_visible(card, card_visible)
      if card_visible then
        local palette = get_quality_palette(card_model.quality)
        local frame_image = choice_skin['card_frame_' .. tostring(card_model.quality or 'common')] or choice_skin.card_frame_common
        local badge_image = choice_skin['badge_bg_' .. tostring(card_model.quality or 'common')] or choice_skin.badge_bg_common
        card.bg:set_image_color(36, 36, 38, 236)
        card.frame:set_image(frame_image or ui_res.common.empty)
        card.frame:set_image_color(palette.frame_color[1], palette.frame_color[2], palette.frame_color[3], 232)
        card.badge_bg:set_image(badge_image or ui_res.common.empty)
        card.badge_bg:set_image_color(palette.badge[1], palette.badge[2], palette.badge[3], 255)
        card.badge_text:set_text(card_model.badge_text or '')
        card.badge_text:set_text_color(palette.badge[1], palette.badge[2], palette.badge[3], palette.badge[4])
        card.title_text:set_text(card_model.title_text or '')
        card.title_text:set_text_color(palette.title[1], palette.title[2], palette.title[3], palette.title[4])
        card.progress_text:set_text(card_model.progress_text or '')
        card.progress_text:set_visible(card_visible and card_model.progress_text ~= '')
        card.icon_frame:set_image_color(palette.frame_color[1], palette.frame_color[2], palette.frame_color[3], 255)
        card.icon:set_image(card_model.icon_res or ui_res.common.empty)
        card.subtitle_text:set_text(card_model.subtitle_text or '')
        card.subtitle_text:set_text_color(palette.subtitle[1], palette.subtitle[2], palette.subtitle[3], palette.subtitle[4])
        for line_index, line in ipairs(card.body_lines) do
          local block = card_model.body_blocks and card_model.body_blocks[line_index] or nil
          if block then
            local color = get_body_color(block.color)
            line:set_visible(true)
            line:set_text(block.text or '')
            line:set_text_color(color[1], color[2], color[3], color[4])
          else
            line:set_visible(false)
            line:set_text('')
          end
        end
      end
    end

    set_action_button_state(panel.hide_button, model.hide_enabled ~= false, true, '暂时隐藏')
    set_action_button_state(
      panel.refresh_button,
      model.refresh and model.refresh.visible ~= false,
      model.refresh and model.refresh.enabled == true,
      get_refresh_label(model.refresh)
    )
    return panel
  end

  return {
    ensure_panel = function()
      return create_choice_panel()
    end,
    refresh_panel = function()
      return refresh_panel()
    end,
    set_visible = function(visible)
      local panel = STATE.choice_panel
      if not is_panel_alive(panel) then
        return
      end
      if visible ~= true then
        panel.root:set_visible(false)
        return
      end
      refresh_panel()
    end,
    destroy_panel = function()
      destroy_panel()
    end,
  }
end

return M
