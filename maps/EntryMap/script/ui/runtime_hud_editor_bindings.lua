local UIRoot = require 'ui.ui_root'
local RuntimeHudSchema = require 'ui.runtime_hud_editor_schema'

local M = {}

local function resolve_many(y3, player, paths)
  local list = {}
  for index, path in ipairs(paths or {}) do
    list[index] = UIRoot.resolve_ui(y3, player, path)
  end
  return list
end

local function append_resolved_paths(target, y3, player, paths)
  for _, path in ipairs(paths or {}) do
    target[#target + 1] = UIRoot.resolve_ui(y3, player, path)
  end
end

function M.attach(runtime_hud, env)
  if not runtime_hud then
    return nil
  end

  local y3 = env.y3
  local player = env.get_player()

  runtime_hud.editor_top_panel = UIRoot.get_top_sheet(y3, player)
  runtime_hud.editor_top_root = UIRoot.resolve_first_ui(y3, player, RuntimeHudSchema.top.root_paths)
  runtime_hud.editor_top_gold_value = UIRoot.resolve_first_ui(y3, player, RuntimeHudSchema.top.gold_value_paths)
  runtime_hud.editor_top_wood_value = UIRoot.resolve_first_ui(y3, player, RuntimeHudSchema.top.wood_value_paths)
  runtime_hud.editor_top_kill_value = UIRoot.resolve_first_ui(y3, player, RuntimeHudSchema.top.kill_value_paths)

  runtime_hud.editor_utility_hud = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.utility.hud_path)
  runtime_hud.editor_setting_button = UIRoot.resolve_first_ui(y3, player, RuntimeHudSchema.utility.setting_button_paths)
  runtime_hud.editor_exit_button = UIRoot.resolve_first_ui(y3, player, RuntimeHudSchema.utility.exit_button_paths)
  runtime_hud.legacy_setting_button = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.utility.legacy_setting_button)
  runtime_hud.legacy_setting_panel = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.utility.legacy_setting_panel)
  runtime_hud.legacy_exit_button = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.utility.legacy_exit_button)

  runtime_hud.editor_bottom_panel = runtime_hud.bottom_bg_root
  runtime_hud.editor_bottom_root = runtime_hud.bottom_bg_root
  runtime_hud.editor_bottom_layout = runtime_hud.bottom_bg_root

  runtime_hud.legacy_gamehud_main = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.legacy.gamehud_main)
  runtime_hud.legacy_inventory_bar = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.legacy.inventory_bar)
  runtime_hud.legacy_skill_bar = UIRoot.resolve_ui(y3, player, RuntimeHudSchema.legacy.skill_bar)
  runtime_hud.legacy_inventory_slot_roots = resolve_many(y3, player, RuntimeHudSchema.legacy.inventory_slot_root_paths)
  runtime_hud.legacy_inventory_slots = resolve_many(y3, player, RuntimeHudSchema.legacy.inventory_slot_paths)
  runtime_hud.legacy_skill_button_roots = resolve_many(y3, player, RuntimeHudSchema.legacy.skill_button_root_paths)

  runtime_hud.editor_bottom_hp_bar = runtime_hud.bottom_hp_fill
  runtime_hud.editor_bottom_hp_value = runtime_hud.bottom_hp_text
  runtime_hud.editor_bottom_hp_recover = nil
  runtime_hud.editor_bottom_exp_bar = runtime_hud.bottom_exp_fill
  runtime_hud.editor_bottom_attack_text = runtime_hud.bottom_attack_value
  runtime_hud.editor_bottom_armor_text = runtime_hud.bottom_armor_value
  runtime_hud.editor_bottom_strength_text = runtime_hud.bottom_strength_value
  runtime_hud.editor_bottom_agility_text = runtime_hud.bottom_agility_value
  runtime_hud.editor_bottom_intelligence_text = runtime_hud.bottom_intelligence_value
  runtime_hud.editor_bottom_inventory_slots = runtime_hud.legacy_inventory_slots or {}
  runtime_hud.editor_bottom_bond_slots = runtime_hud.bottom_bond_icons or {}
  runtime_hud.editor_bottom_bond_slot_bound = runtime_hud.editor_bottom_bond_slot_bound or {}
  runtime_hud.editor_bottom_bond_payloads = runtime_hud.editor_bottom_bond_payloads or {}

  if not runtime_hud.legacy_bottom_nodes then
    runtime_hud.legacy_bottom_nodes = {}
    append_resolved_paths(runtime_hud.legacy_bottom_nodes, y3, player, RuntimeHudSchema.legacy.hidden_paths)
    runtime_hud.legacy_bottom_nodes[#runtime_hud.legacy_bottom_nodes + 1] = runtime_hud.legacy_setting_button
    runtime_hud.legacy_bottom_nodes[#runtime_hud.legacy_bottom_nodes + 1] = runtime_hud.legacy_setting_panel
    runtime_hud.legacy_bottom_nodes[#runtime_hud.legacy_bottom_nodes + 1] = runtime_hud.legacy_exit_button
  end

  return runtime_hud
end

return M
