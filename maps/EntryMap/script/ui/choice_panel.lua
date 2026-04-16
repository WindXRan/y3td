local ui_res = require 'ui.res'
local theme = require 'ui.theme'
local skin = require 'ui.skin'
local Factory = require 'ui.factory'
local BondTipPanel = require 'ui.bond_tip_panel'
local layout = require 'ui.choice_panel_layout'
local TextLayout = require 'ui.choice_panel_text_layout'
local TextColorizer = require 'ui.choice_panel_text_colorizer'

local M = {}

local IMAGE_TYPE = '图片'
local BOND_CHOICE_PREFAB = 'bond_choice_card'

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

local function get_choice_panel_images()
  return skin.images.choice_panel or {}
end

local function get_card_frame_image(quality)
  local images = get_choice_panel_images()
  if quality == 'epic' then
    return images.card_frame_epic or ui_res.hero_prefab.panel_decor
  end
  if quality == 'rare' then
    return images.card_frame_rare or ui_res.hero_prefab.panel_frame_alt
  end
  return images.card_frame_common or ui_res.hero_prefab.panel_frame
end

local function get_badge_bg_image(quality)
  local images = get_choice_panel_images()
  if quality == 'epic' then
    return images.badge_bg_epic or ui_res.common_tip.panel_bg
  end
  if quality == 'rare' then
    return images.badge_bg_rare or ui_res.common_tip.panel_bg
  end
  return images.badge_bg_common or ui_res.common_tip.panel_bg
end

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
  local create_styled_text = factory.create_styled_text
  local get_hud_metrics = factory.get_hud_metrics
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local set_percent_pos = factory.set_percent_pos
  local apply_text_style = factory.apply_text_style
  local bond_tip_panel = BondTipPanel.create(env)

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
      apply_text_style(button_ref.label, 'choice_panel.action_label', label or '')
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

  local function get_node_child(node, path)
    if not node then
      return nil
    end
    return node:get_child(path)
  end

  local function create_prefab_action_button(parent, left, bottom, width, height, label, callback, index)
    local player = env.get_player()
    local prefab = y3.ui_prefab.create(player, 'choice_button', parent)
    local root = prefab and prefab:get_child() or nil
    local button = get_prefab_node(prefab, 'layout_1.button_1')
    local bg_node = get_prefab_node(prefab, 'layout_1.image_3')
    local label_node = get_prefab_node(prefab, 'layout_1.label_2')
    if not root or not button then
      return nil
    end

    local button_style = skin.get_button_style('choice_panel_action')

    local center_x, center_y = rect_center(left, bottom, width, height)
    root:set_anchor(0.5, 0.5)
    root:set_pos(center_x, center_y)
    root:set_widget_relative_scale(width / layout.actions.width, height / layout.actions.height)
    root:set_z_order(9824 + (index or 0))

    if button_style and button_style.status_images then
      button:set_btn_status_image(1, button_style.status_images.normal or ui_res.common_tip.btn_blue_normal)
      button:set_btn_status_image(2, button_style.status_images.hover or ui_res.common_tip.btn_blue_hover)
      button:set_btn_status_image(3, button_style.status_images.press or ui_res.common_tip.btn_blue_press)
      button:set_btn_status_image(4, button_style.status_images.disabled or ui_res.common_tip.btn_blue_disabled)
    end
    if button_style and button_style.text_color then
      button:set_text_color(
        button_style.text_color[1],
        button_style.text_color[2],
        button_style.text_color[3],
        button_style.text_color[4] or 255
      )
    end
    if bg_node then
      local bg_color = button_style and button_style.bg_color or theme.palette.accent_soft
      bg_node:set_image((button_style and button_style.bg_image) or ui_res.common.empty)
      bg_node:set_image_color(
        bg_color[1],
        bg_color[2],
        bg_color[3],
        bg_color[4] or 255
      )
    end
    button:set_text('')
    if label_node then
      apply_text_style(label_node, 'choice_panel.action_label', label or '')
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

  local function set_text_node(node, text, target_key, opts)
    if not node then
      return
    end
    local value = text or ''
    if target_key then
      apply_text_style(node, target_key, value, opts)
    else
      node:set_text(value)
    end
    node:set_visible(value ~= '')
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

  local function bind_choice_card_events(node, card, index)
    if not node then
      return
    end

    node:add_fast_event('左键-点击', function()
      bond_tip_panel.hide()
      if env.apply_round_choice then
        env.apply_round_choice(index)
      end
      refresh_panel()
    end)
    node:add_fast_event('鼠标-移入', function()
      set_choice_card_hover(card, true)
      bond_tip_panel.show_for_card(card, card.model)
    end)
    node:add_fast_event('鼠标-移出', function()
      set_choice_card_hover(card, false)
      bond_tip_panel.hide()
    end)
  end

  local function create_choice_card(parent, left, bottom, width, height, index, card_model, fallback_prefab_name)
    local player = env.get_player()
    local prefab_name = (card_model and card_model.render_prefab) or fallback_prefab_name or 'choice_panel'
    local prefab = y3.ui_prefab.create(player, prefab_name, parent)
    local root = prefab and prefab:get_child() or nil
    if not root then
      return nil
    end

    local design_width = 550
    local design_height = 900
    if prefab_name == BOND_CHOICE_PREFAB then
      local bond_layout = layout.bond or {}
      design_width = bond_layout.design_width or 300
      design_height = bond_layout.design_height or 445
    end

    local scale_x = width / design_width
    local scale_y = height / design_height
    local center_x, center_y = rect_center(left, bottom, width, height)

    root:set_anchor(0.5, 0.5)
    root:set_pos(center_x, center_y)
    root:set_widget_relative_scale(scale_x, scale_y)
    root:set_z_order(9811 + index)

    local button = get_prefab_node(prefab, 'layout_1.button')
    local card = {
      prefab = prefab,
      prefab_name = prefab_name,
      root = root,
      root_x = center_x,
      root_y = center_y,
      button = button,
      hover_offset = 0,
      hover_duration = CARD_HOVER_ANIM.duration,
      hover_steps = CARD_HOVER_ANIM.steps,
      hover_lift = math.max(10, math.floor((CARD_HOVER_ANIM.lift * math.min(scale_x, scale_y)) + 0.5)),
      value_highlight_nodes = {},
      effect_highlight_nodes = {},
    }

    if prefab_name == BOND_CHOICE_PREFAB then
      card.background = get_prefab_node(prefab, 'layout_1.image_panel_bg')
      card.bottom_shade = get_prefab_node(prefab, 'layout_1.image_bottom_shade')
      card.item_frame = get_prefab_node(prefab, 'layout_1.image_item_frame')
      card.icon = get_prefab_node(prefab, 'layout_1.image_item_icon')
      card.bonus_area = get_prefab_node(prefab, 'layout_1.layout_bonus_area')
      card.bonus_lines = {
        get_node_child(card.bonus_area, 'label_bonus_1'),
        get_node_child(card.bonus_area, 'label_bonus_2'),
        get_node_child(card.bonus_area, 'label_bonus_3'),
      }
      card.effect_area = get_prefab_node(prefab, 'layout_1.layout_effect_area')
      card.effect_index = get_node_child(card.effect_area, 'label_effect_index')
      card.effect_name = get_node_child(card.effect_area, 'label_effect_name')
      card.effect_body = get_node_child(card.effect_area, 'label_effect_body')
      card.set_title = get_node_child(card.effect_area, 'label_set_title')
      card.set_body = {
        get_node_child(card.effect_area, 'label_set_body'),
        get_node_child(card.effect_area, 'label_set_body_2'),
        get_node_child(card.effect_area, 'label_set_body_3'),
      }
      card.set_name = get_prefab_node(prefab, 'layout_1.label_set_name')
      card.set_progress = get_prefab_node(prefab, 'layout_1.label_set_progress')
      card.item_name = get_prefab_node(prefab, 'layout_1.label_item_name')
      card.rarity_text = get_prefab_node(prefab, 'layout_1.label_quality_badge')
      card.uses_default_renderer = false
    else
      card.background = get_prefab_node(prefab, 'layout_1.background')
      card.decoration = get_prefab_node(prefab, 'layout_1.background.decoration')
      card.icon = get_prefab_node(prefab, 'layout_1.icon')
      card.set_name = get_prefab_node(prefab, 'layout_1.set_name')
      card.name = get_prefab_node(prefab, 'layout_1.name')
      card.subtitle_name = get_prefab_node(prefab, 'layout_1.subtitle_name')
      card.rarity_background = get_prefab_node(prefab, 'layout_1.rarity_background')
      card.rarity_text = get_prefab_node(prefab, 'layout_1.rarity_background.rarity_text')
      card.desc_root = get_prefab_node(prefab, 'layout_1.desc_text')
      card.value_desc = get_prefab_node(prefab, 'layout_1.desc_text.value_desc')
      card.effect_desc = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc')
      card.effect_name = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc.effect_name')
      card.effect_text = get_prefab_node(prefab, 'layout_1.desc_text.effect_desc.effect_text')
      card.uses_default_renderer = true
    end

    if button then
      button:set_text('')
      bind_choice_card_events(button, card, index)
    else
      bind_choice_card_events(root, card, index)
    end

    return card
  end

  local function create_bond_choice_card(parent, left, bottom, width, height, index)
    local center_x, center_y = rect_center(left, bottom, width, height)
    local bond_layout = layout.bond or {}
    local card_images = get_choice_panel_images()
    local design_width = bond_layout.design_width or 300
    local design_height = bond_layout.design_height or 445
    local scale_x = width / design_width
    local scale_y = height / design_height
    local scale = math.min(scale_x, scale_y)

    local function px(value)
      return value * scale_x
    end

    local function py(value)
      return value * scale_y
    end

    local function create_card_panel(node_parent, x, y, w, h, color, z_order)
      local panel = create_panel(
        node_parent,
        px(x),
        py(y),
        px(w),
        py(h),
        color,
        theme.insets.soft,
        z_order,
        ui_res.common.empty
      )
      panel:set_anchor(0.5, 0.5)
      return panel
    end

    local function create_card_text(node_parent, x, y, w, h, font_size, color, align, z_order)
      local text = create_text(
        node_parent,
        px(x),
        py(y),
        px(w),
        py(h),
        math.max(10, math.floor((font_size * scale) + 0.5)),
        color,
        align or '中',
        '中',
        z_order
      )
      text:set_anchor(0.5, 0.5)
      return text
    end

    local function create_card_text_left(node_parent, left, y, w, h, font_size, color, v_align, z_order)
      local text = create_text(
        node_parent,
        px(left),
        py(y),
        px(w),
        py(h),
        math.max(10, math.floor((font_size * scale) + 0.5)),
        color,
        '左',
        v_align or '中',
        z_order
      )
      text:set_anchor(0, 0.5)
      return text
    end

    local root = create_card_panel(parent, center_x / scale_x, center_y / scale_y, design_width, design_height, { 0, 0, 0, 0 }, 9811 + index)
    root:set_pos(center_x, center_y)
    root:set_ui_size(width, height)
    root:set_image_color(255, 255, 255, 0)
    root:set_intercepts_operations(true)

    local card = {
      prefab = nil,
      root = root,
      root_x = center_x,
      root_y = center_y,
      hover_offset = 0,
      hover_duration = CARD_HOVER_ANIM.duration,
      hover_steps = CARD_HOVER_ANIM.steps,
      hover_lift = math.max(10, math.floor((CARD_HOVER_ANIM.lift * scale) + 0.5)),
      background = create_card_panel(
        root,
        design_width * 0.5,
        design_height * 0.5,
        bond_layout.background_width or design_width,
        bond_layout.background_height or design_height,
        { 255, 255, 255, 255 },
        9812
      ),
      decoration = create_card_panel(
        root,
        design_width * 0.5,
        design_height * 0.5,
        bond_layout.frame_width or (design_width - 8),
        bond_layout.frame_height or (design_height - 8),
        { 255, 255, 255, 255 },
        9813
      ),
      item_frame = create_card_panel(
        root,
        design_width * 0.5,
        bond_layout.icon_frame_y or 288,
        bond_layout.icon_frame_size or 90,
        bond_layout.icon_frame_size or 90,
        { 255, 255, 255, 255 },
        9813
      ),
      icon = create_card_panel(
        root,
        design_width * 0.5,
        bond_layout.icon_frame_y or 288,
        bond_layout.icon_size or 72,
        bond_layout.icon_size or 72,
        { 255, 255, 255, 255 },
        9814
      ),
      set_name = create_card_text(
        root,
        design_width * 0.5,
        bond_layout.set_name_y or 374,
        bond_layout.set_name_width or 190,
        bond_layout.set_name_height or 34,
        28,
        BODY_COLORS.gold,
        '中',
        9815
      ),
      set_progress = create_card_text(
        root,
        design_width * 0.5,
        bond_layout.set_progress_y or 346,
        bond_layout.set_progress_width or 132,
        bond_layout.set_progress_height or 22,
        18,
        BODY_COLORS.dim,
        '中',
        9815
      ),
      item_name = create_card_text(
        root,
        bond_layout.content_left or 38,
        bond_layout.item_name_y or 238,
        bond_layout.content_width or bond_layout.item_name_width or 224,
        bond_layout.item_name_height or 34,
        18,
        BODY_COLORS.blue,
        '左',
        9815
      ),
      rarity_text = create_card_text(
        root,
        design_width * 0.5,
        bond_layout.badge_y or 414,
        bond_layout.badge_width or 88,
        bond_layout.badge_height or 28,
        24,
        BODY_COLORS.blue,
        '中',
        9815
      ),
      bonus_area = create_card_panel(
        root,
        design_width * 0.5,
        bond_layout.bonus_area_y or 182,
        bond_layout.bonus_width or 224,
        72,
        { 0, 0, 0, 0 },
        9814
      ),
      effect_area = create_card_panel(
        root,
        design_width * 0.5,
        bond_layout.effect_area_y or 84,
        bond_layout.effect_area_width or 244,
        bond_layout.effect_area_height or 126,
        { 0, 0, 0, 0 },
        9814
      ),
      uses_default_renderer = false,
      value_highlight_nodes = {},
      effect_highlight_nodes = {},
    }

    if card.item_frame then
      card.item_frame:set_image(card_images.icon_frame or ui_res.hero_prefab.panel_frame)
      card.item_frame:set_image_color(255, 255, 255, 255)
    end

    if card.background then
      card.background:set_image(card_images.card_bg or ui_res.hero_prefab.panel_bg)
      card.background:set_image_color(255, 255, 255, 255)
    end
    if card.decoration then
      card.decoration:set_image(get_card_frame_image('common'))
      card.decoration:set_image_color(255, 255, 255, 220)
    end

    card.bonus_lines = {
      create_card_text_left(card.bonus_area, bond_layout.bonus_area_left or 38, 61, bond_layout.content_width or bond_layout.bonus_width or 224, bond_layout.bonus_line_height or 18, 17, BODY_COLORS.green, '中', 9815),
      create_card_text_left(card.bonus_area, bond_layout.bonus_area_left or 38, 39, bond_layout.content_width or bond_layout.bonus_width or 224, bond_layout.bonus_line_height or 18, 17, BODY_COLORS.green, '中', 9815),
      create_card_text_left(card.bonus_area, bond_layout.bonus_area_left or 38, 17, bond_layout.content_width or bond_layout.bonus_width or 224, bond_layout.bonus_line_height or 18, 17, BODY_COLORS.green, '中', 9815),
    }
    for _, bonus_node in ipairs(card.bonus_lines) do
      bonus_node:set_text_alignment('左', '中')
      bonus_node:set_anchor(0, 0.5)
    end

    card.effect_index = create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, bond_layout.effect_index_y or 110, bond_layout.content_width or bond_layout.effect_index_width or 224, bond_layout.effect_index_height or 18, 17, BODY_COLORS.gold, '中', 9815)
    card.effect_name = create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, bond_layout.effect_name_y or 90, bond_layout.content_width or bond_layout.effect_name_width or 224, bond_layout.effect_name_height or 18, 14, BODY_COLORS.white, '中', 9815)
    card.effect_body = create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, bond_layout.effect_body_y or 86, bond_layout.content_width or bond_layout.effect_body_width or 224, bond_layout.effect_body_height or 38, 14, BODY_COLORS.white, '上', 9815)
    card.set_title = create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, bond_layout.set_title_y or 42, bond_layout.content_width or bond_layout.set_title_width or 224, bond_layout.set_title_height or 18, 17, BODY_COLORS.gold, '中', 9815)
    card.set_body = {
      create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, 20, bond_layout.content_width or bond_layout.set_body_width or 224, bond_layout.set_body_height or 16, 13, BODY_COLORS.green, '上', 9815),
      create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, 4, bond_layout.content_width or bond_layout.set_body_width or 224, bond_layout.set_body_height or 16, 13, BODY_COLORS.green, '上', 9815),
      create_card_text_left(card.effect_area, bond_layout.effect_stack_left or 38, -12, bond_layout.content_width or bond_layout.set_body_width or 224, bond_layout.set_body_height or 16, 13, BODY_COLORS.green, '上', 9815),
    }
    for _, text_node in ipairs({
      card.effect_index,
      card.effect_name,
      card.effect_body,
      card.set_title,
      card.set_body[1],
      card.set_body[2],
      card.set_body[3],
    }) do
      if text_node then
        text_node:set_text_alignment('左', '中')
      end
    end
    if card.item_name then
      card.item_name:set_text_alignment('左', '中')
      card.item_name:set_anchor(0, 0.5)
    end
    card.effect_body:set_text_alignment('左', '上')
    card.effect_index:set_anchor(0, 0.5)
    card.effect_name:set_anchor(0, 0.5)
    card.set_title:set_anchor(0, 0.5)
    for _, body_node in ipairs(card.set_body) do
      body_node:set_text_alignment('左', '上')
      body_node:set_anchor(0, 0.5)
    end

    bind_choice_card_events(root, card, index)
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

    local card_images = get_choice_panel_images()

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

    local header_layout = layout.header or {}
    local stage_shell = create_panel(
      stage,
      scaled(layout.panel.width * 0.5, scale),
      scaled(layout.panel.height * 0.5, scale),
      scaled(header_layout.shell_width or layout.panel.width, scale),
      scaled(header_layout.shell_height or layout.panel.height, scale),
      { 255, 255, 255, 0 },
      theme.insets.large,
      9801,
      ui_res.common.empty
    )
    stage_shell:set_anchor(0.5, 0.5)
    stage_shell:set_image(ui_res.common.empty)
    stage_shell:set_image_color(255, 255, 255, 0)

    local model = env.get_current_choice_panel_model and env.get_current_choice_panel_model() or nil
    local use_bond_cards = model and model.kind == 'bond'
    local card_prefab_name = use_bond_cards and BOND_CHOICE_PREFAB or 'choice_panel'

    local cards = {
      create_choice_card(
        stage,
        scaled(layout.card.x[1], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        1,
        model and model.cards and model.cards[1] or nil,
        card_prefab_name
      ),
      create_choice_card(
        stage,
        scaled(layout.card.x[2], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        2,
        model and model.cards and model.cards[2] or nil,
        card_prefab_name
      ),
      create_choice_card(
        stage,
        scaled(layout.card.x[3], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        3,
        model and model.cards and model.cards[3] or nil,
        card_prefab_name
      ),
    }

    local title_text = create_styled_text(
      stage,
      scaled(layout.panel.width * 0.5, scale),
      scaled(header_layout.title_y or (layout.panel.height - 42), scale),
      scaled(header_layout.title_width or 480, scale),
      scaled(header_layout.title_height or 30, scale),
      'choice_panel.title',
      get_panel_title(model and model.kind or nil),
      9816
    )
    title_text:set_anchor(0.5, 0.5)

    local hint_text = create_styled_text(
      stage,
      scaled(layout.panel.width * 0.5, scale),
      scaled(header_layout.hint_y or (layout.panel.height - 76), scale),
      scaled(header_layout.hint_width or 620, scale),
      scaled(header_layout.hint_height or 24, scale),
      'choice_panel.hint',
      get_panel_hint(model),
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
      stage_shell = stage_shell,
      cards = cards,
      card_kind = use_bond_cards and 'bond' or 'default',
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
    bond_tip_panel.hide()
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
    local card_images = get_choice_panel_images()
    local visible = model ~= nil and STATE.session_phase == 'battle'
    panel.root:set_visible(visible)
    if not visible then
      bond_tip_panel.hide()
      for _, card in ipairs(panel.cards or {}) do
        reset_choice_card_transform(card)
      end
      return panel
    end

    local model_card_kind = model.kind == 'bond' and 'bond' or 'default'
    if panel.card_kind ~= model_card_kind then
      destroy_panel()
      return create_choice_panel()
    end

    if panel.title_text then
      apply_text_style(panel.title_text, 'choice_panel.title', get_panel_title(model.kind))
    end
    if panel.hint_text then
      apply_text_style(panel.hint_text, 'choice_panel.hint', get_panel_hint(model))
    end
    if panel.backdrop then
      panel.backdrop:set_image(card_images.overlay or ui_res.common.empty)
      panel.backdrop:set_image_color(10, 12, 16, 176)
    end
    if panel.stage_shell then
      panel.stage_shell:set_image(ui_res.common.empty)
      panel.stage_shell:set_image_color(255, 255, 255, 0)
    end

    for index, card in ipairs(panel.cards) do
      local card_model = model.cards and model.cards[index] or nil
      local card_visible = card ~= nil and card_model ~= nil
      if card then
        card.model = card_model
        set_prefab_card_visible(card, card_visible)
      end

      if card_visible and panel.card_kind == 'bond' and card.uses_default_renderer ~= true then
        local palette = get_quality_palette(card_model.quality)
        local tip_model = card_model.tip_model or {}
        local is_bond_prefab = card.prefab_name == BOND_CHOICE_PREFAB

        if card.background then
          card.background:set_image(ui_res.common.empty)
          card.background:set_image_color(255, 255, 255, 0)
        end
        if card.bottom_shade then
          card.bottom_shade:set_visible(false)
        end
        if card.decoration and not is_bond_prefab then
          card.decoration:set_image(get_card_frame_image(card_model.quality))
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
        if card.item_frame then
          if not is_bond_prefab then
            card.item_frame:set_image(card_images.icon_frame or ui_res.hero_prefab.panel_frame)
          end
          if card.item_frame.set_image_color then
            card.item_frame:set_image_color(
              palette.frame_color[1],
              palette.frame_color[2],
              palette.frame_color[3],
              255
            )
          end
        end
        if card.rarity_text then
          local badge_color = palette.badge
          card.rarity_text:set_text(build_badge_text(card_model))
          card.rarity_text:set_text_color(
            badge_color[1],
            badge_color[2],
            badge_color[3],
            badge_color[4]
          )
        end
        if card.set_name then
          local card_set_name_text = card_model.set_title_text or tip_model.set_name_text or ''
          local set_name_color = card_model.set_title_color and get_body_color(card_model.set_title_color) or BODY_COLORS.bond_red
          apply_text_style(
            card.set_name,
            'choice_panel.bond.title',
            card_set_name_text
          )
          card.set_name:set_text_color(
            set_name_color[1],
            set_name_color[2],
            set_name_color[3],
            set_name_color[4]
          )
          card.set_name:set_visible(card_set_name_text ~= '')
        end
        local card_progress_text = card_model.progress_text or tip_model.progress_text or ''
        set_text_node(card.set_progress, card_progress_text, 'choice_panel.bond.progress')
        if card.item_name then
          local card_item_name_text = build_title_text(card_model) or tip_model.item_name_text or ''
          local item_color = card_model.title_color and get_body_color(card_model.title_color) or palette.subtitle
          apply_text_style(
            card.item_name,
            'choice_panel.bond.item_name',
            card_item_name_text
          )
          card.item_name:set_text_color(
            item_color[1],
            item_color[2],
            item_color[3],
            item_color[4]
          )
        end
        for bonus_index, bonus_node in ipairs(card.bonus_lines or {}) do
          set_text_node(
            bonus_node,
            (tip_model.bonus_lines or {})[bonus_index] or '',
            'choice_panel.bond.bonus'
          )
        end
        set_text_node(card.effect_index, tip_model.effect_index_text or '', 'choice_panel.bond.effect_index')
        set_text_node(card.effect_name, '')
        set_text_node(card.effect_body, tip_model.effect_body_text or '', 'choice_panel.bond.effect_body')
        set_text_node(card.set_title, tip_model.set_title_text or '', 'choice_panel.bond.set_title')
        for body_index, body_node in ipairs(card.set_body or {}) do
          set_text_node(
            body_node,
            (tip_model.set_body_lines or {})[body_index] or '',
            'choice_panel.bond.set_body'
          )
        end
        if card.effect_area then
          local bonus_count = math.max(0, math.min(3, tonumber(card_model.effect_area_bonus_count) or 0))
          local bond_layout = layout.bond or {}
          local effect_area_y_by_bonus_count = bond_layout.effect_area_y_by_bonus_count or {}
          local effect_y = effect_area_y_by_bonus_count[bonus_count] or bond_layout.effect_area_y or 84
          card.effect_area:set_pos(card.effect_area:get_relative_x(), effect_y)
          local effect_visible = (tip_model.effect_index_text or '') ~= ''
              or (tip_model.effect_body_text or '') ~= ''
              or (tip_model.set_title_text or '') ~= ''
          card.effect_area:set_visible(effect_visible)
        end
        clear_value_highlights(card)
        clear_effect_highlights(card)
      elseif card_visible then
        local palette = get_quality_palette(card_model.quality)
        local text_layout = TextLayout.build_text_layout(card_model.body_blocks)
        local card_images = get_choice_panel_images()

        if card.background then
          card.background:set_image(card_images.card_bg or ui_res.hero_prefab.panel_bg)
          card.background:set_image_color(
            palette.surface[1],
            palette.surface[2],
            palette.surface[3],
            255
          )
        end
        if card.decoration then
          card.decoration:set_image(get_card_frame_image(card_model.quality))
          card.decoration:set_image_color(
            palette.frame_color[1],
            palette.frame_color[2],
            palette.frame_color[3],
            255
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
          card.rarity_background:set_image(get_badge_bg_image(card_model.quality))
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
          clear_value_highlights(card)
          render_value_highlights(card, text_layout.value_blocks)
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
          local effect_color = get_body_color(text_layout.effect_color)
          card.effect_text:set_visible(text_layout.effect_visible)
          card.effect_text:set_text(text_layout.effect_text or '')
          card.effect_text:set_text_color(
            effect_color[1],
            effect_color[2],
            effect_color[3],
            effect_color[4]
          )
          clear_effect_highlights(card)
          render_effect_highlights(card, text_layout.effect_blocks)
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
