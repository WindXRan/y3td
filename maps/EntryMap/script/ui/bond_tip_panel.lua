local layout = require 'ui.bond_tip_panel_layout'
local UIStyle = require 'ui.style'

local M = {}

local QUALITY_COLORS = {
  common = {
    badge = { 62, 255, 68, 255 },
    item = { 62, 255, 68, 255 },
  },
  rare = {
    badge = { 40, 149, 255, 255 },
    item = { 40, 149, 255, 255 },
  },
  epic = {
    badge = { 198, 120, 255, 255 },
    item = { 198, 120, 255, 255 },
  },
}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function resolve_child(node, path)
  if not node or not path or path == '' then
    return nil
  end
  local ok, child = pcall(node.get_child, node, path)
  if ok and child then
    return child
  end
  return nil
end

local function is_alive(node)
  return node ~= nil and (not node.is_removed or not node:is_removed())
end

local function is_cache_valid(nodes)
  if not nodes or not is_alive(nodes.panel) or not is_alive(nodes.quality_badge) then
    return false
  end

  for _, node in ipairs({
    nodes.set_name,
    nodes.set_progress,
    nodes.item_icon,
    nodes.item_name,
    nodes.effect_area,
    nodes.effect_index,
    nodes.effect_name,
    nodes.effect_body,
    nodes.set_title,
    nodes.set_body,
    nodes.set_body_2,
    nodes.set_body_3,
  }) do
    if node and not is_alive(node) then
      return false
    end
  end

  for _, node in ipairs(nodes.bonus or {}) do
    if node and not is_alive(node) then
      return false
    end
  end

  return true
end

local function set_text(node, text)
  if not node then
    return
  end
  node:set_text(text or '')
  node:set_visible(text ~= nil and text ~= '')
end

local function set_styled_text(node, target_key, text)
  if not node then
    return
  end
  local value = text or ''
  UIStyle.apply_text(node, target_key, value)
  node:set_visible(value ~= '')
end

local function set_lines(nodes, lines)
  for index, node in ipairs(nodes or {}) do
    set_text(node, lines and lines[index] or '')
  end
end

local function get_quality_palette(quality)
  return QUALITY_COLORS[quality or 'common'] or QUALITY_COLORS.common
end

function M.create(env)
  local y3 = env.y3
  local player = env.get_player()
  local cache = nil

  local function ensure_nodes()
    if is_cache_valid(cache) then
      return cache
    end

    local panel = resolve_ui(y3, player, layout.nodes.panel)
    if not panel then
      local panel_root = resolve_ui(y3, player, layout.panel_name)
      panel = resolve_child(panel_root, 'panel_card_set_tip') or panel_root
    end
    if not panel or not resolve_child(panel, layout.nodes.quality_badge) then
      return nil
    end

    cache = {
      panel = panel,
      quality_badge = resolve_child(panel, layout.nodes.quality_badge),
      set_name = resolve_child(panel, layout.nodes.set_name),
      set_progress = resolve_child(panel, layout.nodes.set_progress),
      item_icon = resolve_child(panel, layout.nodes.item_icon),
      item_name = resolve_child(panel, layout.nodes.item_name),
      effect_area = resolve_child(panel, layout.nodes.effect_area),
      effect_index = resolve_child(panel, layout.nodes.effect_index),
      effect_name = resolve_child(panel, layout.nodes.effect_name),
      effect_body = resolve_child(panel, layout.nodes.effect_body),
      set_title = resolve_child(panel, layout.nodes.set_title),
      set_body = resolve_child(panel, layout.nodes.set_body),
      set_body_2 = resolve_child(panel, layout.nodes.set_body_2),
      set_body_3 = resolve_child(panel, layout.nodes.set_body_3),
      bonus = {
        resolve_child(panel, layout.nodes.bonus[1]),
        resolve_child(panel, layout.nodes.bonus[2]),
        resolve_child(panel, layout.nodes.bonus[3]),
      },
    }
    cache.panel:set_visible(false)
    return cache
  end

  local function position_panel(nodes, anchor_ui)
    if not nodes or not nodes.panel or not anchor_ui then
      return
    end
    local card_x = anchor_ui:get_absolute_x()
    local card_y = anchor_ui:get_absolute_y()
    local card_width = anchor_ui:get_real_width()
    local panel_width = nodes.panel:get_real_width()
    local panel_height = nodes.panel:get_real_height()
    local screen_width = y3.ui.get_window_width()
    local screen_height = y3.ui.get_window_height()

    local place_right = card_x < (screen_width * 0.5)
    local target_x
    local target_y = card_y

    if place_right then
      nodes.panel:set_anchor(0, 0.5)
      target_x = card_x + (card_width * 0.5) + 20
    else
      nodes.panel:set_anchor(1, 0.5)
      target_x = card_x - (card_width * 0.5) - 20
    end

    local half_panel_height = math.max(1, panel_height * 0.5)
    local min_y = half_panel_height + 8
    local max_y = math.max(min_y, screen_height - half_panel_height - 8)
    if target_y < min_y then
      target_y = min_y
    elseif target_y > max_y then
      target_y = max_y
    end

    if place_right then
      local max_x = math.max(8, screen_width - panel_width - 8)
      if target_x > max_x then
        target_x = max_x
      end
    else
      local min_x = math.max(panel_width + 8, 8)
      if target_x < min_x then
        target_x = min_x
      end
    end

    nodes.panel:set_absolute_pos(target_x, target_y)
  end

  local api = {}

  function api.hide()
    local nodes = ensure_nodes()
    if nodes and nodes.panel then
      nodes.panel:set_visible(false)
    end
  end

  local function show_tip(anchor_ui, tip, quality, fallback)
    local nodes = ensure_nodes()
    if not nodes or not tip then
      api.hide()
      return
    end

    local palette = get_quality_palette(quality)
    local bonus_lines = tip.bonus_lines or fallback and fallback.bonus_lines or {}
    local effect_area_bonus_count = fallback and fallback.effect_area_bonus_count or #bonus_lines

    set_styled_text(
      nodes.quality_badge,
      'editor.CardSetEffectTipPanel.label_quality_badge',
      tip.quality_text or fallback and fallback.badge_text or ''
    )
    set_styled_text(nodes.set_name, 'editor.CardSetEffectTipPanel.label_set_name', tip.set_name_text or '')
    set_styled_text(nodes.set_progress, 'editor.CardSetEffectTipPanel.label_set_progress', tip.progress_text or '')
    set_styled_text(
      nodes.item_name,
      'editor.CardSetEffectTipPanel.label_item_name',
      tip.item_name_text or fallback and fallback.title_text or ''
    )
    set_lines(nodes.bonus, bonus_lines)
    set_text(nodes.effect_index, tip.effect_index_text or '')
    set_text(nodes.effect_name, '')
    set_styled_text(nodes.effect_body, 'editor.CardSetEffectTipPanel.label_effect_body', tip.effect_body_text or '')
    set_text(nodes.set_title, tip.set_title_text or '')
    set_text(nodes.set_body, tip.set_body_lines and tip.set_body_lines[1] or '')
    set_text(nodes.set_body_2, tip.set_body_lines and tip.set_body_lines[2] or '')
    set_text(nodes.set_body_3, tip.set_body_lines and tip.set_body_lines[3] or '')

    if nodes.item_icon then
      nodes.item_icon:set_image(tip.icon_res or fallback and fallback.icon_res or 0)
    end
    if nodes.quality_badge then
      nodes.quality_badge:set_text_color(palette.badge[1], palette.badge[2], palette.badge[3], palette.badge[4])
    end
    if nodes.set_name then
      nodes.set_name:set_text_color(palette.item[1], palette.item[2], palette.item[3], palette.item[4])
    end
    if nodes.set_progress then
      nodes.set_progress:set_text_color(palette.badge[1], palette.badge[2], palette.badge[3], palette.badge[4])
    end
    if nodes.item_name then
      nodes.item_name:set_text_color(palette.item[1], palette.item[2], palette.item[3], palette.item[4])
    end
    if nodes.effect_area then
      local bonus_count = math.max(0, math.min(3, tonumber(effect_area_bonus_count) or #bonus_lines))
      local pos_y = layout.effect_area_y_by_bonus_count[bonus_count] or layout.effect_area_y_by_bonus_count[3]
      nodes.effect_area:set_pos(nodes.effect_area:get_relative_x(), pos_y)
    end

    position_panel(nodes, anchor_ui)
    nodes.panel:set_visible(true)
  end

  function api.show_for_card(card, card_model)
    if not card_model or card_model.kind ~= 'bond' or not card or not card.root then
      api.hide()
      return
    end
    show_tip(card.root, card_model.tip_model or {}, card_model.quality, card_model)
  end

  function api.show_for_anchor(anchor_ui, payload)
    if not anchor_ui or not payload then
      api.hide()
      return
    end
    show_tip(anchor_ui, payload.tip_model or {}, payload.quality, payload)
  end

  return api
end

return M
