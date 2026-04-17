local GrowthWeaponItemTip = require 'ui.growth_weapon_item_tip'

local M = {}

local function trim_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  local value = text:gsub('\r', '')
  value = value:gsub('^%s+', '')
  value = value:gsub('%s+$', '')
  return value
end

local function join_non_empty(lines, sep)
  local parts = {}
  for _, line in ipairs(lines or {}) do
    local value = trim_text(line)
    if value ~= '' then
      parts[#parts + 1] = value
    end
  end
  return table.concat(parts, sep or '\n')
end

local function build_subtitle_text(tip_model, payload)
  local set_name = trim_text(tip_model and tip_model.set_name_text or '')
  local progress = trim_text(tip_model and tip_model.progress_text or '')
  if set_name ~= '' and progress ~= '' then
    return string.format('%s %s', set_name, progress)
  end
  if set_name ~= '' then
    return set_name
  end
  if progress ~= '' then
    return progress
  end
  return trim_text(payload and payload.title_text or '')
end

local function build_affix_lines(tip_model)
  local lines = {}
  local effect_body_text = trim_text(tip_model and tip_model.effect_body_text or '')
  if effect_body_text ~= '' then
    lines[#lines + 1] = {
      title = '当前效果',
      body = effect_body_text,
    }
  end

  local set_title = trim_text(tip_model and tip_model.set_title_text or '')
  local set_body = join_non_empty(tip_model and tip_model.set_body_lines or {}, '\n')
  if set_title ~= '' or set_body ~= '' then
    lines[#lines + 1] = {
      title = set_title ~= '' and set_title or '套装效果',
      body = set_body,
    }
  end

  return lines
end

local function build_panel_payload(payload)
  if not payload then
    return nil
  end
  local tip_model = payload.tip_model or {}
  return {
    title_text = trim_text(tip_model.item_name_text or payload.title_text or ''),
    subtitle_text = build_subtitle_text(tip_model, payload),
    cost_text = trim_text(tip_model.quality_text or payload.badge_text or ''),
    quality = payload.quality or 'common',
    icon_res = tip_model.icon_res or payload.icon_res,
    attr_lines = payload.bonus_lines or tip_model.bonus_lines or {},
    affix_lines = build_affix_lines(tip_model),
  }
end

function M.create(env)
  local shared_tip = GrowthWeaponItemTip.create(env)
  local api = {}

  function api.hide()
    if shared_tip and shared_tip.hide then
      shared_tip.hide()
    end
  end

  function api.show_for_anchor(anchor_ui, payload)
    if not shared_tip or not shared_tip.show_for_anchor then
      return
    end
    shared_tip.show_for_anchor(anchor_ui, build_panel_payload(payload))
  end

  function api.show_for_card(card, card_model)
    if not card or not card.root or not card_model or card_model.kind ~= 'bond' then
      api.hide()
      return
    end
    api.show_for_anchor(card.root, card_model)
  end

  return api
end

return M
