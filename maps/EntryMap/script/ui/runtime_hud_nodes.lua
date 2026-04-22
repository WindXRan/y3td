local UIRoot = require 'ui.ui_root'
local RuntimeHudSchema = require 'ui.runtime_hud_editor_schema'

local M = {}

local function resolve_prefab_node(prefab, path)
  return UIRoot.resolve_child(prefab, path)
end

local function resolve_prefab_first(prefab, paths)
  for _, path in ipairs(paths or {}) do
    local node = resolve_prefab_node(prefab, path)
    if node then
      return node
    end
  end
  return nil
end

local function resolve_prefab_pair(prefab, pair)
  return resolve_prefab_first(prefab, pair or {})
end

function M.attach_bottom_bg(nodes, prefab)
  if not nodes or not prefab then
    return nodes
  end

  local bottom_nodes = {
    bottom_bg_root = prefab,
    bottom_bg_backpack = resolve_prefab_node(prefab, 'layout_1.backpack'),
    bottom_skill_bar = resolve_prefab_node(prefab, '技能栏'),
    bottom_skill_slot_hosts = (function()
      local slots = {}
      for index, path in ipairs(RuntimeHudSchema.bottom.skill_slot_host_paths or {}) do
        slots[index] = resolve_prefab_node(prefab, path)
      end
      return slots
    end)(),
    bottom_backpack_slot_hosts = (function()
      local slots = {}
      for index, pair in ipairs(RuntimeHudSchema.bottom.backpack_slot_host_paths or {}) do
        slots[index] = resolve_prefab_pair(prefab, pair)
      end
      return slots
    end)(),
    bottom_backpack_slots = (function()
      local slots = {}
      for index, pair in ipairs(RuntimeHudSchema.bottom.backpack_slot_host_paths or {}) do
        slots[index] = resolve_prefab_pair(prefab, pair)
      end
      return slots
    end)(),
    bottom_portrait = resolve_prefab_node(prefab, 'layout_1.mid.头像.英雄头像')
      or resolve_prefab_node(prefab, 'layout_1.mid.头像.touxiang'),
    bottom_name = resolve_prefab_node(prefab, 'layout_1.mid.头像.name'),
    bottom_level = resolve_prefab_node(prefab, 'layout_1.mid.头像.等级'),
    bottom_exp_fill = resolve_prefab_node(prefab, 'layout_1.mid.进化进度条.progress_bar_img')
      or resolve_prefab_node(prefab, 'exp'),
    bottom_exp_text = resolve_prefab_node(prefab, 'layout_1.mid.进化进度条.progress_percent_label'),
    bottom_hp_fill = resolve_prefab_node(prefab, 'layout_1.mid.头像.血条.progress_bar_img')
      or resolve_prefab_node(prefab, 'main_hp_bar'),
    bottom_hp_text = resolve_prefab_node(prefab, 'layout_1.mid.头像.血条.progress_percent_label')
      or resolve_prefab_node(prefab, 'hp_value'),
    bottom_attack_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.value')
      or resolve_prefab_node(prefab, 'layout_1.mid.bg_3.shuxing1.label_3_1'),
    bottom_attack_percent = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.名称+加成百分比'),
    bottom_attack_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.百分比加成'),
    bottom_attack_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.攻击力.数值加成'),
    bottom_strength_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.value_1')
      or resolve_prefab_node(prefab, 'layout_1.mid.bg_3.shuxing2.label_3'),
    bottom_strength_percent = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.percent'),
    bottom_strength_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.百分比加成'),
    bottom_strength_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.力量.数值加成'),
    bottom_agility_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.敏捷.value')
      or resolve_prefab_node(prefab, 'layout_1.mid.bg_3.shuxing2.label_3_1'),
    bottom_agility_percent = resolve_prefab_node(prefab, 'layout_1.mid.panel.敏捷.percent'),
    bottom_agility_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.敏捷.百分比加成'),
    bottom_agility_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.敏捷.数值加成'),
    bottom_intelligence_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.智力.value')
      or resolve_prefab_node(prefab, 'layout_1.mid.bg_3.shuxing2.label_3_2'),
    bottom_intelligence_percent = resolve_prefab_node(prefab, 'layout_1.mid.panel.智力.percent'),
    bottom_intelligence_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.智力.百分比加成'),
    bottom_intelligence_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.智力.数值加成'),
    bottom_armor_value = resolve_prefab_node(prefab, 'layout_1.mid.panel.护甲值.value')
      or resolve_prefab_node(prefab, 'layout_1.mid.bg_3.shuxing1.label_3_2'),
    bottom_armor_percent = resolve_prefab_node(prefab, 'layout_1.mid.panel.护甲值.percent'),
    bottom_armor_percent_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.护甲值.百分比加成'),
    bottom_armor_value_bonus = resolve_prefab_node(prefab, 'layout_1.mid.panel.护甲值.数值加成'),
    bottom_compact_stats_root = resolve_prefab_first(prefab, {
      'layout_1.mid.bg_3',
    }),
    bottom_bond_icons = {
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片1'),
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片2'),
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片3'),
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片4'),
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片5'),
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片6'),
      resolve_prefab_node(prefab, 'layout_1.UP.羁绊图片7'),
    },
    bottom_skill_draw_button = resolve_prefab_node(prefab, 'layout_1.button.技能抽卡'),
    bottom_bond_draw_button = resolve_prefab_node(prefab, 'layout_1.button.羁绊抽卡'),
    bottom_treasure_challenge_button = resolve_prefab_node(prefab, 'layout_1.challenge.宝物挑战'),
    bottom_gold_challenge_button = resolve_prefab_node(prefab, 'layout_1.challenge.金币挑战'),
    bottom_exp_challenge_button = resolve_prefab_node(prefab, 'layout_1.challenge.杀敌挑战'),
    bottom_wood_challenge_button = resolve_prefab_node(prefab, 'layout_1.challenge.木材挑战'),
  }

  for key, value in pairs(bottom_nodes) do
    nodes[key] = value
  end
  return nodes
end

return M
