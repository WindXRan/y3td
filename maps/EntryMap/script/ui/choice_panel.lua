local ui_res = require 'ui.res'
local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local layout = require 'ui.choice_panel_layout'
local TextLayout = require 'ui.choice_panel_text_layout'
local TextColorizer = require 'ui.choice_panel_text_colorizer'

local M = {}

local IMAGE_TYPE = '图片'

local BODY_COLORS = {
  green = { 86, 255, 92, 255 },
  gold = { 255, 216, 74, 255 },
  cyan = { 118, 248, 255, 255 },
  white = { 226, 232, 238, 255 },
  blue = { 39, 157, 255, 255 },
  purple = { 198, 120, 255, 255 },
  dim = { 154, 154, 154, 255 },
  bond_red = { 255, 82, 82, 255 },
}

local FONT_SIZES = {
  badge = 18,
  set_title = 26,
  bond_title = 26,
  subtitle = 23,
  value = 24,
  effect_title = 22,
  effect_text = 18,
}

local CARD_HOVER_ANIM = {
  duration = 0.08,
  steps = 4,
  lift = 16,
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

local function get_quality_value_color(quality)
  if quality == 'epic' then
    return BODY_COLORS.purple
  end
  if quality == 'rare' then
    return BODY_COLORS.blue
  end
  return BODY_COLORS.green
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
  return card_model.badge_text or ''
end

local function build_title_text(card_model)
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

  local function stop_card_hover_timer(card)
    if card and card.hover_timer then
      card.hover_timer:remove()
      card.hover_timer = nil
    end
  end

  local function apply_card_hover_offset(card, offset)
    if not card then
      return
    end

    local applied_offset = math.floor((offset or 0) + 0.5)
    card.hover_offset = applied_offset

    if card.root and not card.root:is_removed() then
      card.root:set_pos(card.root_x, card.root_y + applied_offset)
    end
  end

  local function reset_choice_card_transform(card)
    if not card then
      return
    end
    card.hovered = false
    stop_card_hover_timer(card)
    apply_card_hover_offset(card, 0)
  end

  local function set_choice_card_hover(card, hovered, immediate)
    if not card then
      return
    end

    local target_offset = hovered == true and (card.hover_lift or 0) or 0
    card.hovered = hovered == true

    stop_card_hover_timer(card)
    if immediate == true then
      apply_card_hover_offset(card, target_offset)
      return
    end

    local start_offset = card.hover_offset or 0
    local delta = target_offset - start_offset
    local steps = math.max(1, card.hover_steps or CARD_HOVER_ANIM.steps)
    if delta == 0 then
      apply_card_hover_offset(card, target_offset)
      return
    end

    card.hover_timer = y3.ltimer.loop_count((card.hover_duration or CARD_HOVER_ANIM.duration) / steps, steps, function(timer, count)
      if not is_ui_alive(card.root) then
        timer:remove()
        card.hover_timer = nil
        return
      end

      local progress = count / steps
      apply_card_hover_offset(card, start_offset + (delta * progress))
      if count >= steps then
        card.hover_timer = nil
      end
    end)
  end

  local function set_prefab_card_visible(card, visible)
    if card.root then
      card.root:set_visible(visible)
    end
    if card.button then
      card.button:set_visible(visible)
      card.button:set_button_enable(visible and not STATE.game_finished)
    end
    if not visible then
      reset_choice_card_transform(card)
    end
  end

  local function clear_effect_highlights(card)
    for _, node in ipairs(card.effect_highlight_nodes or {}) do
      if node and not node:is_removed() then
        node:remove()
      end
    end
    card.effect_highlight_nodes = {}
  end

  local function apply_card_typography(card, card_model)
    if not card then
      return
    end

    local title_size = FONT_SIZES.bond_title
    local subtitle_size = FONT_SIZES.subtitle
    local value_size = FONT_SIZES.value
    local effect_title_size = FONT_SIZES.effect_title
    local effect_text_size = FONT_SIZES.effect_text

    if card_model and card_model.kind == 'upgrade' then
      title_size = 24
      subtitle_size = 20
      value_size = 20
      effect_title_size = 20
      effect_text_size = 18
    end

    if card.rarity_text then
      card.rarity_text:set_font_size(FONT_SIZES.badge)
    end
    if card.set_name then
      card.set_name:set_font_size(FONT_SIZES.set_title)
    end
    if card.name then
      card.name:set_font_size(title_size)
    end
    if card.subtitle_name then
      card.subtitle_name:set_font_size(subtitle_size)
    end
    if card.value_desc then
      card.value_desc:set_font_size(value_size)
    end
    if card.effect_name then
      card.effect_name:set_font_size(effect_title_size)
    end
    if card.effect_text then
      card.effect_text:set_font_size(effect_text_size)
    end
  end

  local function render_effect_highlights(card, effect_text, mode)
    clear_effect_highlights(card)
    if not card or not card.effect_desc or not card.effect_text or type(effect_text) ~= 'string' or effect_text == '' then
      return
    end

    local lines = TextColorizer.build_highlight_lines(effect_text, 'dim', mode)
    if #lines == 0 then
      return
    end

    local base_x = math.floor((card.effect_text:get_relative_x() or 0) + 0.5)
    local base_y = math.floor((card.effect_text:get_relative_y() or 0) + 0.5)
    local line_height = 24
    local font_size = FONT_SIZES.effect_text

    for line_index, segments in ipairs(lines) do
      local cursor_x = base_x
      local cursor_y = base_y - ((line_index - 1) * line_height)
      for _, segment in ipairs(segments) do
        if segment.text and segment.text ~= '' and segment.color and segment.color ~= 'dim' then
          local text = card.effect_desc:create_child('文本')
          local width = math.max(24, TextColorizer.estimate_text_width(segment.text, font_size) + 8)
          local color = get_body_color(segment.color)
          text:set_ui_size(width, line_height)
          text:set_pos(cursor_x, cursor_y)
          text:set_font_size(font_size)
          text:set_text_alignment('左', '中')
          text:set_text(segment.text)
          text:set_text_color(color[1], color[2], color[3], color[4])
          text:set_z_order(9817)
          card.effect_highlight_nodes[#card.effect_highlight_nodes + 1] = text
        end
        cursor_x = cursor_x + TextColorizer.estimate_text_width(segment.text or '', font_size)
      end
    end
  end

  local function clear_value_highlights(card)
    for _, node in ipairs(card.value_highlight_nodes or {}) do
      if node and not node:is_removed() then
        node:remove()
      end
    end
    card.value_highlight_nodes = {}
  end

  local function has_manual_segments(blocks, default_color)
    for _, block in ipairs(blocks or {}) do
      for _, segment in ipairs(block.segments or {}) do
        if segment.color and segment.color ~= default_color then
          return true
        end
      end
    end
    return false
  end

  local function render_manual_highlights(parent, text_node, holder, blocks, default_color)
    if not parent or not text_node or not holder then
      return
    end

    local node_x = math.floor((text_node:get_relative_x() or 0) + 0.5)
    local node_y = math.floor((text_node:get_relative_y() or 0) + 0.5)
    local node_width = math.floor((text_node:get_width() or 0) + 0.5)
    local node_height = math.floor((text_node:get_height() or 0) + 0.5)
    local font_size = text_node.get_font_size and text_node:get_font_size() or FONT_SIZES.effect_text
    local line_height = font_size + 8
    local base_x = node_x - math.floor(node_width * 0.5) + 4
    local base_y = node_y + math.floor(node_height * 0.5) - 2

    for line_index, block in ipairs(blocks or {}) do
      local segments = block and block.segments or nil
      if not segments or #segments == 0 then
        segments = {
          {
            text = block and block.text or '',
            color = default_color,
          },
        }
      end

      local cursor_x = base_x
      local cursor_y = base_y - ((line_index - 1) * line_height)
      for _, segment in ipairs(segments) do
        if segment.text and segment.text ~= '' then
          local color = get_body_color(segment.color or default_color)
          local width = math.max(24, TextColorizer.estimate_text_width(segment.text, font_size) + 8)
          local text = create_text(
            parent,
            cursor_x,
            cursor_y,
            width,
            line_height,
            font_size,
            color,
            '左',
            '上',
            9817
          )
          text:set_anchor(0, 1)
          text:set_text(segment.text)
          holder[#holder + 1] = text
        end
        cursor_x = cursor_x + TextColorizer.estimate_text_width(segment.text or '', font_size)
      end
    end
  end

  local function render_effect_highlights(card, effect_blocks)
    clear_effect_highlights(card)
    if not card or not card.effect_desc or not card.effect_text then
      return
    end
    local node_x = math.floor((card.effect_text:get_relative_x() or 0) + 0.5)
    local node_y = math.floor((card.effect_text:get_relative_y() or 0) + 0.5)
    local node_width = math.floor((card.effect_text:get_width() or 0) + 0.5)
    local node_height = math.floor((card.effect_text:get_height() or 0) + 0.5)
    local font_size = card.effect_text.get_font_size and card.effect_text:get_font_size() or FONT_SIZES.effect_text
    local line_height = font_size + 8
    local rows = TextLayout.build_segment_rows({
      left = node_x - math.floor(node_width * 0.5) + 4,
      top = node_y + math.floor(node_height * 0.5) - 2,
      blocks = effect_blocks or {},
      default_color = 'dim',
      font_size = font_size,
      line_height = line_height,
      estimate_width = TextColorizer.estimate_text_width,
    })
    for _, row in ipairs(rows) do
      for _, segment in ipairs(row.segments or {}) do
        local color = get_body_color(segment.color or 'dim')
        local text = card.effect_desc:create_child('文本')
        text:set_anchor(0, 1)
        text:set_ui_size(segment.width, line_height)
        text:set_pos(segment.x, segment.y)
        text:set_font_size(font_size)
        text:set_text_alignment('左', '中')
        text:set_text(segment.text)
        text:set_text_color(color[1], color[2], color[3], color[4])
        text:set_z_order(9817)
        card.effect_highlight_nodes[#card.effect_highlight_nodes + 1] = text
      end
    end
  end

  local function render_value_highlights(card, value_blocks)
    clear_value_highlights(card)
    if not card or not card.desc_root or not card.value_desc then
      return
    end
    local node_x = math.floor((card.value_desc:get_relative_x() or 0) + 0.5)
    local node_y = math.floor((card.value_desc:get_relative_y() or 0) + 0.5)
    local node_width = math.floor((card.value_desc:get_width() or 0) + 0.5)
    local node_height = math.floor((card.value_desc:get_height() or 0) + 0.5)
    local font_size = card.value_desc.get_font_size and card.value_desc:get_font_size() or FONT_SIZES.value
    local line_height = font_size + 8
    local rows = TextLayout.build_segment_rows({
      left = node_x - math.floor(node_width * 0.5) + 4,
      top = node_y + math.floor(node_height * 0.5) - 2,
      blocks = value_blocks or {},
      default_color = 'white',
      font_size = font_size,
      line_height = line_height,
      estimate_width = TextColorizer.estimate_text_width,
    })
    for _, row in ipairs(rows) do
      for _, segment in ipairs(row.segments or {}) do
        local color = get_body_color(segment.color or 'white')
        local text = card.desc_root:create_child('文本')
        text:set_anchor(0, 1)
        text:set_ui_size(segment.width, line_height)
        text:set_pos(segment.x, segment.y)
        text:set_font_size(font_size)
        text:set_text_alignment('左', '中')
        text:set_text(segment.text)
        text:set_text_color(color[1], color[2], color[3], color[4])
        text:set_z_order(9817)
        card.value_highlight_nodes[#card.value_highlight_nodes + 1] = text
      end
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
    local card = {
      prefab = prefab,
      root = root,
      root_x = center_x,
      root_y = center_y,
      button = button,
      hover_offset = 0,
      hover_duration = CARD_HOVER_ANIM.duration,
      hover_steps = CARD_HOVER_ANIM.steps,
      hover_lift = math.max(10, math.floor((CARD_HOVER_ANIM.lift * math.min(scale_x, scale_y)) + 0.5)),
      background = get_prefab_node(prefab, 'layout_1.background'),
      decoration = get_prefab_node(prefab, 'layout_1.background.decoration'),
      icon = get_prefab_node(prefab, 'layout_1.icon'),
      set_name = get_prefab_node(prefab, 'layout_1.set_name'),
      name = get_prefab_node(prefab, 'layout_1.name'),
      subtitle_name = get_prefab_node(prefab, 'layout_1.subtitle_name'),
      rarity_background = get_prefab_node(prefab, 'layout_1.rarity_background'),
      rarity_text = get_prefab_node(prefab, 'layout_1.rarity_background.rarity_text'),
      desc_root = get_prefab_node(prefab, 'layout_1.desc_text'),
      value_desc = get_prefab_node(prefab, 'layout_1.desc_text.value_desc'),
      effect_desc = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc'),
      effect_name = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc.effect_name'),
      effect_text = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc.effect_text'),
      value_highlight_nodes = {},
      effect_highlight_nodes = {},
    }

    if button then
      button:set_text('')
      button:add_fast_event('左键-点击', function()
        if env.apply_round_choice then
          env.apply_round_choice(index)
        end
        refresh_panel()
      end)
      button:add_fast_event('鼠标-移入', function()
        set_choice_card_hover(card, true)
      end)
      button:add_fast_event('鼠标-移出', function()
        set_choice_card_hover(card, false)
      end)
    end

    return card
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
    if panel and panel.cards then
      for _, card in ipairs(panel.cards) do
        reset_choice_card_transform(card)
      end
    end
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
      for _, card in ipairs(panel.cards or {}) do
        reset_choice_card_transform(card)
      end
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
          card.background:set_image_color(255, 255, 255, 255)
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
        apply_card_typography(card, card_model)
        if card.set_name then
          local set_title_text = card_model.set_title_text or ''
          local set_title_visible = set_title_text ~= ''
          local set_title_color = card_model.set_title_color and get_body_color(card_model.set_title_color) or palette.title
          card.set_name:set_visible(set_title_visible)
          if set_title_visible then
            card.set_name:set_text(set_title_text)
            card.set_name:set_text_color(
              set_title_color[1],
              set_title_color[2],
              set_title_color[3],
              set_title_color[4]
            )
          end
        end
        if card.name then
          local title_color = card_model.title_color and get_body_color(card_model.title_color) or palette.title
          card.name:set_text(build_title_text(card_model))
          card.name:set_text_color(
            title_color[1],
            title_color[2],
            title_color[3],
            title_color[4]
          )
        end
        if card.subtitle_name then
          local subtitle_text = card_model.progress_text
          if not subtitle_text or subtitle_text == '' then
            subtitle_text = card_model.subtitle_text
          end
          local subtitle_color = card_model.subtitle_color and get_body_color(card_model.subtitle_color) or palette.subtitle
          local subtitle_visible = subtitle_text and subtitle_text ~= ''
          card.subtitle_name:set_visible(subtitle_visible)
          if subtitle_visible then
            card.subtitle_name:set_text(subtitle_text)
            card.subtitle_name:set_text_color(
              subtitle_color[1],
              subtitle_color[2],
              subtitle_color[3],
              subtitle_color[4]
            )
          end
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
          local value_color = get_quality_value_color(card_model.quality)
          card.value_desc:set_visible(text_layout.value_visible)
          card.value_desc:set_text(text_layout.value_text or '')
          card.value_desc:set_text_color(
            value_color[1],
            value_color[2],
            value_color[3],
            value_color[4]
          )
          clear_value_highlights(card)
        end
        if card.effect_desc then
          card.effect_desc:set_visible(text_layout.effect_visible)
        end
        if card.effect_name then
          local effect_name_visible = text_layout.effect_visible and text_layout.effect_title and text_layout.effect_title ~= ''
          card.effect_name:set_visible(effect_name_visible)
          card.effect_name:set_text(text_layout.effect_title or '')
          card.effect_name:set_text_color(
            BODY_COLORS.gold[1],
            BODY_COLORS.gold[2],
            BODY_COLORS.gold[3],
            BODY_COLORS.gold[4]
          )
        end
        if card.effect_text then
          local effect_color = BODY_COLORS.white
          card.effect_text:set_visible(text_layout.effect_visible)
          card.effect_text:set_text(text_layout.effect_text or '')
          card.effect_text:set_text_color(
            effect_color[1],
            effect_color[2],
            effect_color[3],
            effect_color[4]
          )
          clear_effect_highlights(card)
        end
      else
        clear_value_highlights(card)
        clear_effect_highlights(card)
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
