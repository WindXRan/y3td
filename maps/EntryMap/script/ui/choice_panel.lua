local ui_res = require 'ui.res'
local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local layout = require 'ui.choice_panel_layout'
local TextLayout = require 'ui.choice_panel_text_layout'

local M = {}

local IMAGE_TYPE = '图片'

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
    surface = { 255, 255, 255, 255 },
  },
  rare = {
    badge = { 40, 149, 255, 255 },
    title = { 255, 210, 50, 255 },
    subtitle = { 40, 149, 255, 255 },
    frame_color = { 40, 149, 255, 255 },
    surface = { 220, 235, 255, 255 },
  },
  epic = {
    badge = { 198, 120, 255, 255 },
    title = { 255, 210, 50, 255 },
    subtitle = { 198, 120, 255, 255 },
    frame_color = { 198, 120, 255, 255 },
    surface = { 255, 232, 255, 255 },
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

local function build_badge_text(card_model)
  local parts = {}
  if card_model.badge_text and card_model.badge_text ~= '' then
    parts[#parts + 1] = card_model.badge_text
  end
  if card_model.subtitle_text and card_model.subtitle_text ~= '' then
    parts[#parts + 1] = card_model.subtitle_text
  end
  return table.concat(parts, ' ')
end

local function build_title_text(card_model)
  if card_model.progress_text and card_model.progress_text ~= '' then
    return string.format('%s %s', card_model.title_text or '', card_model.progress_text)
  end
  return card_model.title_text or ''
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local factory = Factory.create(env)

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local get_hud_metrics = factory.get_hud_metrics
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local set_percent_pos = factory.set_percent_pos

  local refresh_panel

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function is_ui_alive(ui)
    return ui and not ui:is_removed()
  end

  local function is_panel_alive(panel)
    return panel and panel.root and is_ui_alive(panel.root)
  end

  local function set_action_button_state(button_ref, visible, enabled, label)
    if not button_ref or not button_ref.root or not button_ref.button then
      return
    end
    button_ref.root:set_visible(visible)
    button_ref.button:set_visible(visible)
    if button_ref.label then
      button_ref.label:set_visible(visible)
    end
    if not visible then
      return
    end

    if button_ref.label then
      button_ref.label:set_text(label or '')
    else
      button_ref.button:set_text(label or '')
    end
    button_ref.button:set_button_enable(enabled == true)
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

  local function get_prefab_node(prefab, path)
    if not prefab then
      return nil
    end
    return prefab:get_child(path)
  end

  local function create_prefab_action_button(parent, left, bottom, width, height, label, callback, index)
    local player = env.get_player()
    local prefab = y3.ui_prefab.create(player, 'choice_button', parent)
    local root = prefab and prefab:get_child() or nil
    local button = get_prefab_node(prefab, 'layout_1.button_1')
    local label_node = get_prefab_node(prefab, 'layout_1.label_2')
    if not root or not button then
      return nil
    end

    local center_x, center_y = rect_center(left, bottom, width, height)
    root:set_anchor(0.5, 0.5)
    root:set_pos(center_x, center_y)
    root:set_widget_relative_scale(width / layout.actions.width, height / layout.actions.height)
    root:set_z_order(9814 + (index or 0))

    button:set_text('')
    if label_node then
      label_node:set_text(label or '')
    end
    button:add_fast_event('左键-点击', callback)

    return {
      prefab = prefab,
      root = root,
      button = button,
      label = label_node,
    }
  end

  local function set_prefab_card_visible(card, visible)
    if card.root then
      card.root:set_visible(visible)
    end
    if card.button then
      card.button:set_visible(visible)
      card.button:set_button_enable(visible and not STATE.game_finished)
    end
  end

  local function create_choice_card(parent, left, bottom, width, height, index)
    local player = env.get_player()
    local prefab = y3.ui_prefab.create(player, 'choice_panel', parent)
    local root = prefab and prefab:get_child() or nil
    if not root then
      return nil
    end

    local scale_x = width / 550
    local scale_y = height / 900
    local center_x, center_y = rect_center(left, bottom, width, height)

    root:set_anchor(0.5, 0.5)
    root:set_pos(center_x, center_y)
    root:set_widget_relative_scale(scale_x, scale_y)
    root:set_z_order(9811 + index)

    local button = get_prefab_node(prefab, 'layout_1.button')
    if button then
      button:set_text('')
      button:add_fast_event('左键-点击', function()
        if env.apply_round_choice then
          env.apply_round_choice(index)
        end
        refresh_panel()
      end)
    end

    return {
      prefab = prefab,
      root = root,
      background = get_prefab_node(prefab, 'layout_1.background'),
      decoration = get_prefab_node(prefab, 'layout_1.background.decoration'),
      button = button,
      icon = get_prefab_node(prefab, 'layout_1.icon'),
      name = get_prefab_node(prefab, 'layout_1.name'),
      rarity_background = get_prefab_node(prefab, 'layout_1.rarity_background'),
      rarity_text = get_prefab_node(prefab, 'layout_1.rarity_background.rarity_text'),
      desc_root = get_prefab_node(prefab, 'layout_1.desc_text'),
      value_desc = get_prefab_node(prefab, 'layout_1.desc_text.value_desc'),
      effect_desc = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc'),
      effect_name = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc.effect_name'),
      effect_text = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc.effect_text'),
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
    local hud_width, hud_height = get_hud_metrics(hud, y3)

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
      hud_width * 0.5,
      hud_height * 0.5,
      hud_width,
      hud_height,
      { 96, 96, 96, 148 },
      theme.insets.large,
      9800,
      ui_res.common.empty
    )
    backdrop:set_anchor(0.5, 0.5)

    local stage = create_panel(
      root,
      0,
      0,
      scaled(layout.panel.width, scale),
      scaled(layout.panel.height, scale),
      { 0, 0, 0, 0 },
      theme.insets.large,
      9801,
      ui_res.common.empty
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
        1
      ),
      create_choice_card(
        stage,
        scaled(layout.card.x[2], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        2
      ),
      create_choice_card(
        stage,
        scaled(layout.card.x[3], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        3
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

    local hide_button = create_prefab_action_button(
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
      1
    )

    local refresh_button = create_prefab_action_button(
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
      2
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
      local card_visible = card ~= nil and card_model ~= nil
      if card then
        set_prefab_card_visible(card, card_visible)
      end

      if card_visible then
        local palette = get_quality_palette(card_model.quality)
        local text_layout = TextLayout.build_text_layout(card_model.body_blocks)

        if card.background then
          card.background:set_image_color(
            palette.surface[1],
            palette.surface[2],
            palette.surface[3],
            255
          )
        end
        if card.decoration then
          card.decoration:set_image_color(
            palette.frame_color[1],
            palette.frame_color[2],
            palette.frame_color[3],
            220
          )
        end
        if card.icon then
          card.icon:set_image(card_model.icon_res or ui_res.common.empty)
        end
        if card.name then
          card.name:set_text(build_title_text(card_model))
          card.name:set_text_color(
            palette.title[1],
            palette.title[2],
            palette.title[3],
            palette.title[4]
          )
        end
        if card.rarity_background then
          card.rarity_background:set_image_color(
            palette.badge[1],
            palette.badge[2],
            palette.badge[3],
            255
          )
        end
        if card.rarity_text then
          card.rarity_text:set_text(build_badge_text(card_model))
          card.rarity_text:set_text_color(22, 24, 28, 255)
        end

        if card.desc_root then
          card.desc_root:set_visible(text_layout.value_visible or text_layout.effect_visible)
        end
        if card.value_desc then
          local value_color = get_body_color(text_layout.value_color)
          card.value_desc:set_visible(text_layout.value_visible)
          card.value_desc:set_text(text_layout.value_text or '')
          card.value_desc:set_text_color(
            value_color[1],
            value_color[2],
            value_color[3],
            value_color[4]
          )
        end
        if card.effect_desc then
          card.effect_desc:set_visible(text_layout.effect_visible)
        end
        if card.effect_name then
          card.effect_name:set_visible(text_layout.effect_visible)
          card.effect_name:set_text(text_layout.effect_title or '')
          card.effect_name:set_text_color(
            BODY_COLORS.gold[1],
            BODY_COLORS.gold[2],
            BODY_COLORS.gold[3],
            BODY_COLORS.gold[4]
          )
        end
        if card.effect_text then
          local effect_color = get_body_color(text_layout.effect_color)
          card.effect_text:set_visible(text_layout.effect_visible)
          card.effect_text:set_text(text_layout.effect_text or '')
          card.effect_text:set_text_color(
            effect_color[1],
            effect_color[2],
            effect_color[3],
            effect_color[4]
          )
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
