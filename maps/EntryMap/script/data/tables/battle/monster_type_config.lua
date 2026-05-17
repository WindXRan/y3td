local CsvLoader = require 'data.csv_loader'
local helpers = require 'data.tables.helpers'

local M = {}

local function to_number(value)
  if value == nil or value == '' then
    return nil
  end
  return tonumber(value)
end

local MONSTER_TYPE_CONFIG = {}

local rows = CsvLoader.read_rows({path = 'data_csv/monster_types.csv'})
for _, row in ipairs(rows) do
  local id = row['id']
  if id and id ~= '' and id ~= '__字段说明__' then
    MONSTER_TYPE_CONFIG[id] = {
      name = row['name'] or id,
      type = row['type'] or 'main',

      hp_scale = to_number(row['hp_scale']) or 1.0,
      attack_scale = to_number(row['attack_scale']) or 1.0,
      armor_scale = to_number(row['armor_scale']) or 1.0,
      move_speed_scale = to_number(row['move_speed_scale']) or 1.0,

      reward_gold_scale = to_number(row['reward_gold_scale']) or 1.0,
      reward_wood_scale = to_number(row['reward_wood_scale']) or 1.0,
      reward_exp_scale = to_number(row['reward_exp_scale']) or 1.0,

      visual = {
        model_scale = to_number(row['model_scale']) or 1.0,
        effect_scale = to_number(row['effect_scale']) or 1.0,
      },

      hit_reaction = {
        heavy_hit_threshold = to_number(row['heavy_hit_threshold']) or 0.12,
        medium_hit_threshold = to_number(row['medium_hit_threshold']) or 0.04,
        shove_distance = to_number(row['shove_distance']) or 26,
      },

      death_reaction = {
        corpse_distance = to_number(row['corpse_distance']) or 160,
        corpse_speed = to_number(row['corpse_speed']) or 920,
        remove_delay = to_number(row['remove_delay']) or 1.0,
        effect_scale = to_number(row['death_effect_scale']) or 0.96,
      },
    }
  end
end

local function get_monster_type_config(monster_type)
  local t = monster_type or 'normal'
  return MONSTER_TYPE_CONFIG[t] or MONSTER_TYPE_CONFIG.normal
end

local function resolve_monster_type(info)
  if info and info.type then
    return info.type
  end
  if info and info.kind == 'boss' then
    return 'boss'
  end
  if info and info.kind == 'challenge' then
    return 'challenge'
  end
  if info and info.is_elite then
    return 'elite'
  end
  return 'normal'
end

local function apply_monster_type_scaling(attr_pack, monster_type)
  local config = get_monster_type_config(monster_type)
  if not attr_pack then
    return attr_pack
  end
  
  local scaled = {}
  for k, v in pairs(attr_pack) do
    scaled[k] = v
  end
  
  if scaled['hp_max'] or scaled['生命'] then
    local hp_key = scaled['hp_max'] and 'hp_max' or '生命'
    scaled[hp_key] = (scaled[hp_key] or 0) * config.hp_scale
  end
  
  if scaled['攻击'] or scaled['物理攻击'] then
    local atk_key = scaled['攻击'] and '攻击' or '物理攻击'
    scaled[atk_key] = (scaled[atk_key] or 0) * config.attack_scale
  end
  
  if scaled['护甲'] or scaled['物理防御'] then
    local armor_key = scaled['护甲'] and '护甲' or '物理防御'
    scaled[armor_key] = (scaled[armor_key] or 0) * config.armor_scale
  end
  
  return scaled
end

local function apply_reward_scaling(reward, monster_type)
  local config = get_monster_type_config(monster_type)
  if not reward then
    return reward
  end
  
  return {
    gold = (reward.gold or 0) * config.reward_gold_scale,
    wood = (reward.wood or 0) * config.reward_wood_scale,
    exp = (reward.exp or 0) * config.reward_exp_scale,
    special = reward.special,
  }
end

M.configs = MONSTER_TYPE_CONFIG
M.get_config = get_monster_type_config
M.resolve_type = resolve_monster_type
M.apply_attr_scaling = apply_monster_type_scaling
M.apply_reward_scaling = apply_reward_scaling

return M