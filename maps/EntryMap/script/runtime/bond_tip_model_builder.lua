local M = {}
local TipBlockStyle = require 'data.tables.tip_block_style'
local IconResolver = require 'data.tables.icon_resolver'
local SkillVisuals = require 'data.tables.skill.skill_visuals'

local function shallow_copy(t)
  local result = {}
  for k, v in pairs(t or {}) do
    result[k] = v
  end
  return result
end

local function resolve_icon(entry)
  if not entry then
    return nil
  end
  local icon = entry.icon or entry.ui_icon or nil
  if not icon then
    icon = IconResolver.pick('bond_default')
  end
  return icon
end

function M.build_bond_tip_model(bond_state, entry, slot_index)
  if not entry then
    return nil
  end

  local model = {
    title = tostring(entry.name or entry.id or '羁绊'),
    icon = resolve_icon(entry),
    summary = tostring(entry.summary or ''),
    detail_blocks = {},
    slot_index = slot_index,
    bond_id = entry.id,
  }

  if entry.bond_skill_activated then
    model.summary = model.summary .. ' [技能已激活]'
  end

  local blocks = {}
  local modifier = entry.modifier
  if modifier then
    for _, mod in ipairs(modifier) do
      local block = TipBlockStyle.build_block('modifier', mod)
      if block then
        blocks[#blocks + 1] = block
      end
    end
  end

  local stats = entry.stats
  if stats then
    for _, stat in ipairs(stats) do
      local block = TipBlockStyle.build_block('stat', stat)
      if block then
        blocks[#blocks + 1] = block
      end
    end
  end

  local effects = entry.effects
  if effects then
    for _, effect in ipairs(effects) do
      local block = TipBlockStyle.build_block('effect', effect)
      if block then
        blocks[#blocks + 1] = block
      end
    end
  end

  local tags = entry.tags
  if tags then
    for _, tag in ipairs(tags) do
      local block = TipBlockStyle.build_block('tag', tag)
      if block then
        blocks[#blocks + 1] = block
      end
    end
  end

  model.detail_blocks = blocks

  local visual = entry.visual
  if visual then
    if visual.border_color then
      model.border_color = visual.border_color
    end
    if visual.bg_color then
      model.bg_color = visual.bg_color
    end
    if visual.frame_style then
      model.frame_style = visual.frame_style
    end
  end

  if entry.quality then
    model.quality = entry.quality
  end

  return model
end

function M.build_bond_detail_models(bond_runtime)
  if not bond_runtime or not bond_runtime.current_choices then
    return {}
  end

  local models = {}
  for slot_index, entry in ipairs(bond_runtime.current_choices) do
    local model = M.build_bond_tip_model(bond_runtime, entry, slot_index)
    if model then
      models[#models + 1] = model
    end
  end
  return models
end

function M.build_bond_replacement_model(bond_runtime, slot_index)
  if not bond_runtime or not bond_runtime.current_replacements then
    return nil, nil
  end

  local old_entry = bond_runtime.current_replacements.old
  local new_entries = bond_runtime.current_replacements.new or {}

  local old_model = M.build_bond_tip_model(bond_runtime, old_entry, slot_index)
  local new_models = {}
  for i, new_entry in ipairs(new_entries) do
    new_models[i] = M.build_bond_tip_model(bond_runtime, new_entry, slot_index)
  end

  return old_model, new_models
end

function M.build_bond_status_model(bond_runtime)
  if not bond_runtime then
    return nil
  end

  local model = {
    current_bonds = {},
    slot_count = bond_runtime.slot_count or 0,
    max_slots = bond_runtime.max_slots or 8,
  }

  if bond_runtime.equipped then
    for slot_index, entry in ipairs(bond_runtime.equipped) do
      if entry then
        local tip = M.build_bond_tip_model(bond_runtime, entry, slot_index)
        if tip then
          model.current_bonds[#model.current_bonds + 1] = tip
        end
      end
    end
  end

  return model
end

function M.build_choice_card_model(entry, slot_index, style_override)
  if not entry then
    return nil
  end

  local model = M.build_bond_tip_model(nil, entry, slot_index)
  if not model then
    return nil
  end

  model.card_style = shallow_copy(style_override or {})

  if entry.card_data then
    model.card_data = shallow_copy(entry.card_data)
  end

  return model
end

function M.resolve_card_icon(card_data, fallback_icon)
  if card_data and card_data.icon then
    return card_data.icon
  end
  return fallback_icon
end

function M.resolve_card_name(card_data, fallback_name)
  if card_data and card_data.name then
    return card_data.name
  end
  return fallback_name
end

function M.resolve_card_quality(card_data, fallback_quality)
  if card_data and card_data.quality then
    return card_data.quality
  end
  return fallback_quality
end

return M
