local ui_res = require 'ui.res'
local theme = require 'ui.theme'
local skin = require 'ui.skin'
local UIStyle = require 'ui.style'
local Factory = require 'ui.factory'
local UIRoot = require 'ui.ui_root'
local BondTipPanel = require 'ui.bond_tip_panel'
local layout = require 'ui.choice_panel_layout'
local TextLayout = require 'ui.choice_panel_text_layout'
local TextColorizer = require 'ui.choice_panel_text_colorizer'

local M = {}

local IMAGE_TYPE = '图片'
local ITEM_DESC_PREFAB = '物品说明'
local ITEM_DESC_DESIGN_WIDTH = 304
local ITEM_DESC_DESIGN_HEIGHT = 260

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
    title = { 120, 255, 126, 255 },
    subtitle = { 62, 255, 68, 255 },
    frame_color = { 76, 255, 82, 255 },
    surface = { 255, 255, 255, 255 },
  },
  rare = {
    badge = { 40, 149, 255, 255 },
    title = { 138, 203, 255, 255 },
    subtitle = { 40, 149, 255, 255 },
    frame_color = { 40, 149, 255, 255 },
    surface = { 220, 235, 255, 255 },
  },
  epic = {
    badge = { 198, 120, 255, 255 },
    title = { 226, 174, 255, 255 },
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
    return '仙缘感应'
  end
  if kind == 'evolution' or kind == 'mark' then
    return '真身进化'
  end
  if kind == 'treasure_replace' then
    return '替换宝物'
  end
  if kind == 'treasure' then
    return '宝物候选'
  end
  return '奖励抉择'
end

local function resolve_panel_title(model)
  if model and model.panel_title and model.panel_title ~= '' then
    return model.panel_title
  end
  return get_panel_title(model and model.kind or nil)
end

local function get_model_choice_count(model)
  local count = 0
  for _ in ipairs(model and model.cards or {}) do
    count = count + 1
  end
  return count
end

local function build_choice_key_hint(choice_count)
  local count = math.max(1, math.min(3, tonumber(choice_count) or 0))
  local keys = {}
  for index = 1, count do
    keys[index] = tostring(index)
  end
  return table.concat(keys, ' / ')
end

local function get_panel_hint(model)
  if model and model.hint_text and model.hint_text ~= '' then
    return model.hint_text
  end
  if model and model.kind == 'treasure_replace' then
    return '点击一张卡，指定要被替换的宝物位'
  end
  return string.format('点击卡片或按 %s 选择', build_choice_key_hint(get_model_choice_count(model)))
end

local function build_badge_text(card_model)
  return card_model.badge_text or ''
end

local function build_title_text(card_model)
  return card_model.title_text or ''
end

local function get_choice_panel_renderer_signature(model)
  local signatures = {}
  for index = 1, 3 do
    local card_model = model and model.cards and model.cards[index] or nil
    if not card_model then
      signatures[index] = 'none'
    elseif card_model.use_item_desc_card == true then
      signatures[index] = 'item_desc'
    else
      signatures[index] = 'default'
    end
  end
  return table.concat(signatures, '|')
end

local function trim_inline_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  local value = text:gsub('\r', '')
  value = value:gsub('^%s+', '')
  value = value:gsub('%s+$', '')
  return value
end

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG or {}
  local y3 = env.y3
  local factory = Factory.create(env)
  local ITEM_DESC_DEBUG = true

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local get_hud_metrics = factory.get_hud_metrics
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local set_percent_pos = factory.set_percent_pos
  local bond_tip_panel = BondTipPanel.create(env)

  local refresh_panel
  local set_text_node
  local clear_value_highlights
  local clear_effect_highlights
  local debug_choice_panel_lifecycle

  local function fallback_create_styled_text(parent, x, y, width, height, style_key, value, z_order, h_align, v_align, font_size, color)
    local text = create_text(
      parent,
      x,
      y,
      width,
      height,
      font_size or math.max(10, math.floor((height or 18) * 0.72)),
      color,
      h_align or '中',
      v_align or '中',
      z_order
    )
    UIStyle.apply_text(text, style_key, value or '')
    return text
  end

  local function fallback_apply_text_style(node, style_key, value, opts)
    if not node then
      return node
    end
    UIStyle.apply_text(node, style_key, value or '')

    local options = opts or {}
    if options.font_size and node.set_font_size then
      node:set_font_size(options.font_size)
    end
    if (options.h_align or options.v_align) and node.set_text_alignment then
      node:set_text_alignment(options.h_align or '中', options.v_align or '中')
    end
    if options.color and node.set_text_color then
      node:set_text_color(
        options.color[1],
        options.color[2],
        options.color[3],
        options.color[4] or 255
      )
    end
    if options.visible ~= nil and node.set_visible then
      node:set_visible(options.visible == true)
    end
    return node
  end

  local create_styled_text = factory.create_styled_text or fallback_create_styled_text
  local apply_text_style = factory.apply_text_style or fallback_apply_text_style

  local function get_hud_root()
    return UIRoot.get_overlay_parent(y3, env.get_player())
  end

  local function is_ui_alive(ui)
    return ui and not ui:is_removed()
  end

  local function is_panel_alive(panel)
    return panel and panel.root and is_ui_alive(panel.root)
  end

  local function get_current_choice_panel_model()
    return env.get_current_choice_panel_model and env.get_current_choice_panel_model() or nil
  end

  local function is_choice_panel_active(model)
    return model ~= nil and STATE.session_phase == 'battle'
  end

  local function create_ui_prefab_safe(player, prefab_name, parent, debug_scope)
    if not player or not parent or not prefab_name or prefab_name == '' then
      return nil
    end

    local ok, prefab_or_err = pcall(y3.ui_prefab.create, player, prefab_name, parent)
    if not ok or not prefab_or_err then
      debug_choice_panel_lifecycle(string.format(
        'prefab_create_failed prefab=%s scope=%s err=%s',
        tostring(prefab_name),
        tostring(debug_scope or '?'),
        tostring(prefab_or_err)
      ))
      return nil
    end

    return prefab_or_err
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

  local function get_card_left_positions(card_count)
    local visible_count = math.max(1, math.min(3, tonumber(card_count) or 0))
    local gap = (layout.card.x[2] - layout.card.x[1]) - layout.card.width
    local total_width = (layout.card.width * visible_count) + (gap * math.max(0, visible_count - 1))
    local first_left = math.floor(((layout.panel.width - total_width) * 0.5) + 0.5)
    local positions = {}

    for index = 1, visible_count do
      positions[index] = first_left + ((index - 1) * (layout.card.width + gap))
    end
    for index = visible_count + 1, 3 do
      positions[index] = layout.card.x[index] or layout.card.x[#layout.card.x]
    end

    return positions
  end

  local function get_prefab_node(prefab, path)
    if not prefab then
      return nil
    end
    local ok, node = pcall(prefab.get_child, prefab, path)
    if ok and node then
      return node
    end
    return nil
  end

  local function get_prefab_node_any(prefab, paths)
    for _, path in ipairs(paths or {}) do
      local node = get_prefab_node(prefab, path)
      if node then
        return node
      end
    end
    return nil
  end

  local function get_node_child(node, path)
    if not node then
      return nil
    end
    local ok, child = pcall(node.get_child, node, path)
    if ok and child then
      return child
    end
    return nil
  end

  local function get_node_name(node)
    if not node or not node.get_name then
      return 'nil'
    end
    local ok, name = pcall(node.get_name, node)
    if ok and name and name ~= '' then
      return tostring(name)
    end
    return 'unknown'
  end

  local function debug_item_desc(message)
    if not ITEM_DESC_DEBUG then
      return
    end
    if log and log.info then
      log.info('[choice_panel.item_desc] ' .. tostring(message))
      return
    end
    print('[choice_panel.item_desc] ' .. tostring(message))
  end

  debug_choice_panel_lifecycle = function(message)
    if log and log.info then
      log.info('[choice_panel.lifecycle] ' .. tostring(message))
      return
    end
    print('[choice_panel.lifecycle] ' .. tostring(message))
  end

  local last_refresh_panel_lifecycle_message
  local function debug_refresh_panel_lifecycle(message)
    if message == last_refresh_panel_lifecycle_message then
      return
    end
    last_refresh_panel_lifecycle_message = message
    debug_choice_panel_lifecycle(message)
  end

  debug_choice_panel_lifecycle('create')

  local function split_ui_path(path)
    local segments = {}
    if type(path) ~= 'string' or path == '' then
      return segments
    end
    for segment in string.gmatch(path, '[^.]+') do
      if segment ~= '' then
        segments[#segments + 1] = segment
      end
    end
    return segments
  end

  local function find_descendant_by_chain(node, segments, index)
    if not node or not segments or #segments == 0 then
      return nil
    end
    index = index or 1
    if index > #segments then
      return node
    end

    local children = node.get_childs and node:get_childs() or nil
    if not children or #children == 0 then
      return nil
    end

    for _, child in ipairs(children) do
      if child and get_node_name(child) == segments[index] then
        local matched = find_descendant_by_chain(child, segments, index + 1)
        if matched then
          return matched
        end
      end
    end

    for _, child in ipairs(children) do
      local matched = find_descendant_by_chain(child, segments, index)
      if matched then
        return matched
      end
    end

    return nil
  end

  local function summarize_item_desc_line(line)
    if type(line) == 'table' then
      local title = trim_inline_text(line.title or line.text or '')
      local body = trim_inline_text(line.body or line.desc or '')
      if title ~= '' and body ~= '' then
        return title .. ':' .. body
      end
      return title ~= '' and title or body
    end
    return trim_inline_text(tostring(line or ''))
  end

  local function summarize_item_desc_lines(lines, limit)
    local values = {}
    for index, line in ipairs(lines or {}) do
      local text = summarize_item_desc_line(line)
      if text ~= '' then
        values[#values + 1] = text
      end
      if limit and index >= limit then
        break
      end
    end
    return table.concat(values, ' | ')
  end

  local function get_item_desc_prefab_node(prefab, wrapper_root, root, paths, debug_key, card_index)
    local node = get_prefab_node_any(prefab, paths)
    if node then
      return node
    end
    node = get_prefab_node_any(wrapper_root, paths)
    if node then
      return node
    end
    node = get_prefab_node_any(root, paths)
    if node then
      return node
    end

    for _, base in ipairs({ wrapper_root, root }) do
      for _, path in ipairs(paths or {}) do
        local segments = split_ui_path(path)
        node = find_descendant_by_chain(base, segments, 1)
        if node then
          debug_item_desc(string.format(
            'card=%s key=%s fallback_chain=%s base=%s node=%s',
            tostring(card_index or '?'),
            tostring(debug_key or '?'),
            path,
            get_node_name(base),
            get_node_name(node)
          ))
          return node
        end
      end
    end

    if debug_key then
      debug_item_desc(string.format(
        'card=%s key=%s missing paths=%s wrapper=%s root=%s',
        tostring(card_index or '?'),
        tostring(debug_key),
        table.concat(paths or {}, ' || '),
        get_node_name(wrapper_root),
        get_node_name(root)
      ))
    end
    return nil
  end

  local function build_fallback_item_desc_payload(card_model)
    local text_layout = TextLayout.build_text_layout(card_model and card_model.body_blocks or {})
    local attr_lines = {}
    local affix_lines = {}

    for _, block in ipairs(text_layout.value_blocks or {}) do
      if block and block.text and block.text ~= '' then
        attr_lines[#attr_lines + 1] = block.text
      end
    end

    if text_layout.effect_text and text_layout.effect_text ~= '' then
      affix_lines[#affix_lines + 1] = {
        title = text_layout.effect_title ~= '' and text_layout.effect_title or '真意点化',
        body = text_layout.effect_text,
      }
    end

    return {
      title_text = build_title_text(card_model),
      subtitle_text = card_model and (card_model.subtitle_text or card_model.progress_text) or '',
      cost_text = card_model and card_model.badge_text or '',
      icon_res = card_model and card_model.icon_res or nil,
      attr_lines = attr_lines,
      affix_lines = affix_lines,
    }
  end

  local function set_item_desc_list_lines(entries, lines, title_key, body_key, opts)
    local min_visible_rows = opts and opts.min_visible_rows or 0
    local placeholder_text = opts and opts.placeholder_text or ''
    for index, entry in ipairs(entries or {}) do
      local line = lines and lines[index] or nil
      local title_text = ''
      local body_text = ''

      if type(line) == 'table' then
        title_text = tostring(line.title or line[title_key] or line.text or '')
        body_text = tostring(line.body or line[body_key] or line.desc or '')
      elseif line ~= nil then
        title_text = tostring(line)
      elseif index <= min_visible_rows then
        title_text = placeholder_text
      end

      set_text_node(entry and entry[title_key] or nil, title_text)
      if body_key then
        set_text_node(entry and entry[body_key] or nil, body_text)
      end
      if entry and entry.icon then
        entry.icon:set_visible(type(line) == 'table' and line.icon_res ~= nil)
        if type(line) == 'table' and line.icon_res ~= nil then
          entry.icon:set_image(line.icon_res)
        end
      end
      if entry and entry.root then
        entry.root:set_visible(title_text ~= '' or body_text ~= '')
      end
    end
  end

  local function build_item_desc_list_nodes(attr_root, descr_root)
    local attr_nodes = {}
    local descr_nodes = {}

    for row = 1, 6 do
      attr_nodes[row] = {
        root = attr_root and get_node_child(attr_root, tostring(row)) or nil,
      }
      attr_nodes[row].text = attr_nodes[row].root and get_node_child(attr_nodes[row].root, 'text') or nil
      attr_nodes[row].icon = attr_nodes[row].root and get_node_child(attr_nodes[row].root, 'icon') or nil
    end

    for row = 1, 3 do
      descr_nodes[row] = {
        root = descr_root and get_node_child(descr_root, tostring(row)) or nil,
      }
      descr_nodes[row].title_TEXT = descr_nodes[row].root and get_node_child(descr_nodes[row].root, 'title_TEXT') or nil
      descr_nodes[row].descr_TEXT = descr_nodes[row].root and get_node_child(descr_nodes[row].root, 'descr_TEXT') or nil
    end

    return attr_nodes, descr_nodes
  end

  local function resolve_item_desc_card_nodes(card)
    if not card or not card.prefab then
      return false
    end

    local card_index = card.index or (card.model and card.model.index) or '?'
    local prefab = card.prefab
    local wrapper_root = card.wrapper_root
    local root = card.item_desc_content_root or card.root
    local attr_root = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.attr_LIST',
      'shopTip.attr_LIST',
      '物品说明.layout_15.shopTip.attr_LIST',
      '物品说明.shopTip.attr_LIST',
      '物品说明.物品说明.shopTip.attr_LIST',
      'attr_LIST',
    }, 'attr_root', card_index)
    local descr_root = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.descr_LIST',
      'shopTip.descr_LIST',
      '物品说明.layout_15.shopTip.descr_LIST',
      '物品说明.shopTip.descr_LIST',
      '物品说明.物品说明.shopTip.descr_LIST',
      'descr_LIST',
    }, 'descr_root', card_index)

    card.item_desc_attr_root = attr_root
    card.item_desc_descr_root = descr_root
    card.item_desc_title = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.basic.title.title_TEXT',
      'shopTip.basic.title.title_TEXT',
      '物品说明.layout_15.shopTip.basic.title.title_TEXT',
      '物品说明.shopTip.basic.title.title_TEXT',
      '物品说明.物品说明.shopTip.basic.title.title_TEXT',
      'basic.title.title_TEXT',
    }, 'title', card_index)
    card.item_desc_subtitle = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.basic.title.subtitle_TEXT',
      'shopTip.basic.title.subtitle_TEXT',
      '物品说明.layout_15.shopTip.basic.title.subtitle_TEXT',
      '物品说明.shopTip.basic.title.subtitle_TEXT',
      '物品说明.物品说明.shopTip.basic.title.subtitle_TEXT',
      'basic.title.subtitle_TEXT',
    }, 'subtitle', card_index)
    card.item_desc_icon = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.basic.avatar.icon',
      'shopTip.basic.avatar.icon',
      '物品说明.layout_15.shopTip.basic.avatar.icon',
      '物品说明.shopTip.basic.avatar.icon',
      '物品说明.物品说明.shopTip.basic.avatar.icon',
      'basic.avatar.icon',
    }, 'icon', card_index)
    card.item_desc_note_root = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.note',
      'shopTip.note',
      '物品说明.layout_15.shopTip.note',
      '物品说明.shopTip.note',
      '物品说明.物品说明.shopTip.note',
      'note',
    }, 'note_root', card_index)
    card.item_desc_note = get_item_desc_prefab_node(prefab, wrapper_root, root, {
      'layout_15.shopTip.note.note_TEXT',
      'shopTip.note.note_TEXT',
      '物品说明.layout_15.shopTip.note.note_TEXT',
      '物品说明.shopTip.note.note_TEXT',
      '物品说明.物品说明.shopTip.note.note_TEXT',
      'note.note_TEXT',
    }, 'note_text', card_index)
    card.item_desc_attr_nodes, card.item_desc_descr_nodes = build_item_desc_list_nodes(attr_root, descr_root)

    local ready = card.item_desc_title ~= nil
      or card.item_desc_subtitle ~= nil
      or card.item_desc_icon ~= nil
      or card.item_desc_note ~= nil
      or attr_root ~= nil
      or descr_root ~= nil

    debug_item_desc(string.format(
      'resolve card=%s ready=%s title=%s subtitle=%s icon=%s note=%s attr_root=%s descr_root=%s',
      tostring(card_index),
      tostring(ready),
      get_node_name(card.item_desc_title),
      get_node_name(card.item_desc_subtitle),
      get_node_name(card.item_desc_icon),
      get_node_name(card.item_desc_note),
      get_node_name(attr_root),
      get_node_name(descr_root)
    ))

    return ready
  end

  local function create_prefab_action_button(parent, left, bottom, width, height, label, callback, index)
    local player = env.get_player()
    local prefab = create_ui_prefab_safe(player, 'choice_button', parent, 'action_button')
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
    if CONFIG.choice_panel_hover_animations_enabled ~= true or immediate == true then
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
    if card.wrapper_root then
      card.wrapper_root:set_visible(visible)
    end
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

  set_text_node = function(node, text, target_key, opts)
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

  local function render_item_desc_card(card, card_model)
    if not card then
      return
    end

    local resolved = resolve_item_desc_card_nodes(card)
    if not resolved then
      card.item_desc_retry_count = (card.item_desc_retry_count or 0) + 1
      if card.item_desc_retry_count <= 2 then
        debug_item_desc(string.format(
          'render_defer card=%s retry=%d',
          tostring(card_model and card_model.index or card.index or '?'),
          card.item_desc_retry_count
        ))
        y3.ltimer.wait(0, function()
          if not card or not card.model or not is_ui_alive(card.root) then
            return
          end
          render_item_desc_card(card, card.model)
        end)
      end
      return
    end
    card.item_desc_retry_count = 0

    local payload = (card_model and card_model.item_desc_payload) or build_fallback_item_desc_payload(card_model)
    debug_item_desc(string.format(
      'render card=%s kind=%s title=%s subtitle=%s cost=%s attr_count=%d affix_count=%d attr_preview=%s affix_preview=%s title_node=%s subtitle_node=%s note_node=%s',
      tostring(card_model and card_model.index or '?'),
      tostring(card_model and card_model.kind or 'default'),
      trim_inline_text(payload.title_text or ''),
      trim_inline_text(payload.subtitle_text or ''),
      trim_inline_text(payload.cost_text or ''),
      #(payload.attr_lines or {}),
      #(payload.affix_lines or {}),
      summarize_item_desc_lines(payload.attr_lines, 2),
      summarize_item_desc_lines(payload.affix_lines, 1),
      get_node_name(card.item_desc_title),
      get_node_name(card.item_desc_subtitle),
      get_node_name(card.item_desc_note)
    ))
    local palette = get_quality_palette(card_model and card_model.quality or 'common')
    local title_color = card_model and card_model.title_color and get_body_color(card_model.title_color) or palette.title
    local subtitle_color = card_model and card_model.subtitle_color and get_body_color(card_model.subtitle_color) or palette.subtitle

    set_text_node(card.item_desc_title, payload.title_text or '')
    if card.item_desc_title then
      card.item_desc_title:set_text_color(
        title_color[1],
        title_color[2],
        title_color[3],
        title_color[4]
      )
    end

    local subtitle_parts = {}
    local subtitle_text = trim_inline_text(payload.subtitle_text or '')
    local cost_text = trim_inline_text(payload.cost_text or '')
    if subtitle_text ~= '' then
      subtitle_parts[#subtitle_parts + 1] = subtitle_text
    end
    if cost_text ~= '' then
      subtitle_parts[#subtitle_parts + 1] = cost_text
    end
    set_text_node(card.item_desc_subtitle, table.concat(subtitle_parts, '  '))
    if card.item_desc_subtitle then
      card.item_desc_subtitle:set_text_color(
        subtitle_color[1],
        subtitle_color[2],
        subtitle_color[3],
        subtitle_color[4]
      )
    end

    if card.item_desc_icon then
      card.item_desc_icon:set_image(payload.icon_res or ui_res.common.empty)
      card.item_desc_icon:set_visible(payload.icon_res ~= nil)
    end

    local note_text = trim_inline_text(payload.note_text or '')
    set_text_node(card.item_desc_note, note_text)
    if card.item_desc_note_root then
      card.item_desc_note_root:set_visible(note_text ~= '')
    end

    set_item_desc_list_lines(card.item_desc_attr_nodes, payload.attr_lines, 'text', nil, {
      min_visible_rows = 4,
      placeholder_text = ' ',
    })
    set_item_desc_list_lines(card.item_desc_descr_nodes, payload.affix_lines, 'title_TEXT', 'descr_TEXT')
    clear_value_highlights(card)
    clear_effect_highlights(card)
  end

  clear_effect_highlights = function(card)
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

  clear_value_highlights = function(card)
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
      if card and card.uses_item_desc_renderer ~= true then
        bond_tip_panel.show_for_card(card, card.model)
      end
    end)
    node:add_fast_event('鼠标-移出', function()
      set_choice_card_hover(card, false)
      bond_tip_panel.hide()
    end)
  end

  local function create_item_desc_choice_card(parent, left, bottom, width, height, index, card_model)
    local player = env.get_player()
    local prefab = create_ui_prefab_safe(player, ITEM_DESC_PREFAB, parent, string.format('item_desc_card_%s', tostring(index)))
    local wrapper_root = prefab and prefab:get_child() or nil
    local card_root = get_item_desc_prefab_node(prefab, wrapper_root, nil, {
      'layout_15',
      '物品说明.layout_15',
      '物品说明.物品说明.layout_15',
    }, 'card_root', index)
    local content_root = get_item_desc_prefab_node(prefab, wrapper_root, card_root, {
      'layout_15.shopTip',
      'shopTip',
      '物品说明.layout_15.shopTip',
      '物品说明.shopTip',
      '物品说明.物品说明.shopTip',
    }, 'root', index)
    if not wrapper_root or not card_root or not content_root then
      return nil
    end

    local tip_position = get_item_desc_prefab_node(prefab, wrapper_root, card_root, {
      'layout_15.TipPosition',
      'TipPosition',
      '物品说明.layout_15.TipPosition',
      '物品说明.TipPosition',
      '物品说明.物品说明.TipPosition',
    }, 'tip_position', index)
    if tip_position then
      tip_position:set_visible(false)
    end

    local center_x, center_y = rect_center(left, bottom, width, height)
    local scale = math.min(width / ITEM_DESC_DESIGN_WIDTH, height / ITEM_DESC_DESIGN_HEIGHT)
    wrapper_root:set_anchor(0.5, 0.5)
    wrapper_root:set_pos(center_x, center_y)
    wrapper_root:set_widget_relative_scale(scale, scale)
    wrapper_root:set_z_order(9811 + index)
    wrapper_root:set_intercepts_operations(true)

    card_root:set_anchor(0.5, 0.5)
    card_root:set_pos(0, 0)
    card_root:set_intercepts_operations(true)

    local card = {
      prefab = prefab,
      prefab_name = ITEM_DESC_PREFAB,
      index = index,
      wrapper_root = wrapper_root,
      root = wrapper_root,
      item_desc_card_root = card_root,
      item_desc_content_root = content_root,
      root_x = center_x,
      root_y = center_y,
      button = nil,
      hover_offset = 0,
      hover_duration = CARD_HOVER_ANIM.duration,
      hover_steps = CARD_HOVER_ANIM.steps,
      hover_lift = math.max(10, math.floor((CARD_HOVER_ANIM.lift * math.min(width / ITEM_DESC_DESIGN_WIDTH, height / ITEM_DESC_DESIGN_HEIGHT)) + 0.5)),
      uses_item_desc_renderer = true,
      uses_default_renderer = false,
      item_desc_title = nil,
      item_desc_subtitle = nil,
      item_desc_icon = nil,
      item_desc_note_root = nil,
      item_desc_note = nil,
      item_desc_attr_root = nil,
      item_desc_descr_root = nil,
      item_desc_attr_nodes = {},
      item_desc_descr_nodes = {},
      item_desc_retry_count = 0,
      value_highlight_nodes = {},
      effect_highlight_nodes = {},
      model = card_model,
    }

    resolve_item_desc_card_nodes(card)
    debug_item_desc(string.format(
      'create card=%d wrapper=%s card_root=%s content_root=%s attr_root=%s descr_root=%s title=%s subtitle=%s icon=%s note=%s',
      index,
      get_node_name(wrapper_root),
      get_node_name(card_root),
      get_node_name(content_root),
      get_node_name(card.item_desc_attr_root),
      get_node_name(card.item_desc_descr_root),
      get_node_name(card.item_desc_title),
      get_node_name(card.item_desc_subtitle),
      get_node_name(card.item_desc_icon),
      get_node_name(card.item_desc_note)
    ))

    bind_choice_card_events(card_root, card, index)
    return card
  end

  local function create_choice_card(parent, left, bottom, width, height, index, card_model, fallback_prefab_name)
    if card_model and card_model.use_item_desc_card == true then
      local item_desc_card = create_item_desc_choice_card(parent, left, bottom, width, height, index, card_model)
      if item_desc_card then
        return item_desc_card
      end
      debug_choice_panel_lifecycle(string.format(
        'item_desc_fallback index=%s title=%s',
        tostring(index),
        tostring(card_model and card_model.title_text or '')
      ))
    end

    local player = env.get_player()
    local prefab_name = (card_model and card_model.render_prefab) or fallback_prefab_name or 'choice_panel'
    local prefab = create_ui_prefab_safe(player, prefab_name, parent, string.format('default_card_%s', tostring(index)))
    local root = prefab and prefab:get_child() or nil
    if not root then
      return nil
    end

    local design_width = 550
    local design_height = 900

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
      uses_default_renderer = true,
    }

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

    if button then
      button:set_text('')
      bind_choice_card_events(button, card, index)
    else
      bind_choice_card_events(root, card, index)
    end

    return card
  end

  local function create_choice_panel()
    if is_panel_alive(STATE.choice_panel) then
      debug_choice_panel_lifecycle('create_panel reuse_existing')
      refresh_panel()
      return STATE.choice_panel
    end

    local model = get_current_choice_panel_model()
    if not is_choice_panel_active(model) then
      return nil
    end

    debug_choice_panel_lifecycle('create_panel')
    local hud = get_hud_root()
    if not hud then
      debug_choice_panel_lifecycle('create_panel no_hud')
      return nil
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

    local model = get_current_choice_panel_model()
    local card_left_positions = get_card_left_positions(get_model_choice_count(model))

    local cards = {
      create_choice_card(
        stage,
        scaled(card_left_positions[1], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        1,
        model and model.cards and model.cards[1] or nil
      ),
      create_choice_card(
        stage,
        scaled(card_left_positions[2], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        2,
        model and model.cards and model.cards[2] or nil
      ),
      create_choice_card(
        stage,
        scaled(card_left_positions[3], scale),
        scaled(layout.card.y, scale),
        scaled(layout.card.width, scale),
        scaled(layout.card.height, scale),
        3,
        model and model.cards and model.cards[3] or nil
      ),
    }

    local title_text = create_styled_text(
      stage,
      scaled(layout.panel.width * 0.5, scale),
      scaled(header_layout.title_y or (layout.panel.height - 42), scale),
      scaled(header_layout.title_width or 480, scale),
      scaled(header_layout.title_height or 30, scale),
      'choice_panel.title',
      resolve_panel_title(model),
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
      renderer_signature = get_choice_panel_renderer_signature(model),
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
    last_refresh_panel_lifecycle_message = nil
  end

  refresh_panel = function()
    local panel = STATE.choice_panel
    if not is_panel_alive(panel) then
      debug_choice_panel_lifecycle('refresh_panel skipped panel_dead')
      return nil
    end

    local model = get_current_choice_panel_model()
    local card_images = get_choice_panel_images()
    local visible = is_choice_panel_active(model)
    local renderer_signature = get_choice_panel_renderer_signature(model)
    debug_refresh_panel_lifecycle(string.format(
      'refresh_panel kind=%s visible=%s hidden=%s session=%s signature=%s panel_signature=%s',
      tostring(model and model.kind or 'nil'),
      tostring(visible),
      tostring(STATE.choice_panel_hidden),
      tostring(STATE.session_phase),
      renderer_signature,
      tostring(panel.renderer_signature or 'nil')
    ))
    panel.root:set_visible(visible)
    if not visible then
      bond_tip_panel.hide()
      for _, card in ipairs(panel.cards or {}) do
        reset_choice_card_transform(card)
      end
      return panel
    end

    if panel.renderer_signature ~= renderer_signature then
      debug_choice_panel_lifecycle('refresh_panel renderer_signature_changed recreate')
      destroy_panel()
      return create_choice_panel()
    end

    if panel.title_text then
      apply_text_style(panel.title_text, 'choice_panel.title', resolve_panel_title(model))
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

      if card_visible and card.uses_item_desc_renderer == true then
        render_item_desc_card(card, card_model)
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
          local set_title_color = card_model.set_title_color and get_body_color(card_model.set_title_color) or palette.subtitle
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
      local panel = STATE.choice_panel
      if is_panel_alive(panel) then
        return panel
      end

      local model = get_current_choice_panel_model()
      if not is_choice_panel_active(model) then
        return nil
      end

      return create_choice_panel()
    end,
    refresh_panel = function()
      local panel = STATE.choice_panel
      if not is_panel_alive(panel) then
        local model = get_current_choice_panel_model()
        if not is_choice_panel_active(model) then
          return nil
        end
        return create_choice_panel()
      end

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
