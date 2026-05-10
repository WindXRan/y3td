local M = {}

local MONSTER_TYPE_CONFIG = {
  normal = {
    name = '普通怪物',
    type = 'main',
    
    hp_scale = 1.0,
    attack_scale = 1.0,
    armor_scale = 1.0,
    move_speed_scale = 1.0,
    
    reward_gold_scale = 1.0,
    reward_wood_scale = 1.0,
    reward_exp_scale = 1.0,
    
    visual = {
      model_scale = 1.0,
      health_bar_width = 1.0,
      effect_scale = 1.0,
    },
    
    health_bar = {
      bar_type = 0x0050002,
      color = '#E35A5A',
      name_prefix = '敌人',
      name_font_size = 13,
      show_text = true,
      show_name = true,
    },
    
    hit_reaction = {
      heavy_hit_threshold = 0.12,
      medium_hit_threshold = 0.04,
      shove_distance = 26,
    },
    
    death_reaction = {
      corpse_distance = 160,
      corpse_speed = 920,
      remove_delay = 1.0,
      effect_scale = 0.96,
    },
  },
  
  elite = {
    name = '精英怪物',
    type = 'elite',
    
    hp_scale = 3.0,
    attack_scale = 2.0,
    armor_scale = 2.0,
    move_speed_scale = 0.85,
    
    reward_gold_scale = 3.0,
    reward_wood_scale = 3.0,
    reward_exp_scale = 3.0,
    
    visual = {
      model_scale = 1.3,
      health_bar_width = 1.5,
      effect_scale = 1.2,
    },
    
    health_bar = {
      bar_type = 0x0050003,
      color = '#F0B84E',
      name_prefix = '精英',
      name_font_size = 14,
      show_text = true,
      show_name = true,
    },
    
    hit_reaction = {
      heavy_hit_threshold = 0.10,
      medium_hit_threshold = 0.035,
      shove_distance = 18,
    },
    
    death_reaction = {
      corpse_distance = 120,
      corpse_speed = 780,
      remove_delay = 1.2,
      effect_scale = 1.15,
    },
  },
  
  boss = {
    name = 'Boss',
    type = 'boss',
    
    hp_scale = 15.0,
    attack_scale = 5.0,
    armor_scale = 4.0,
    move_speed_scale = 0.7,
    
    reward_gold_scale = 10.0,
    reward_wood_scale = 10.0,
    reward_exp_scale = 10.0,
    
    visual = {
      model_scale = 1.8,
      health_bar_width = 2.5,
      effect_scale = 1.5,
    },
    
    health_bar = {
      bar_type = 0x0060002,
      color = '#D953FF',
      name_prefix = '首领',
      name_font_size = 18,
      show_text = true,
      show_name = true,
    },
    
    hit_reaction = {
      heavy_hit_threshold = 0.08,
      medium_hit_threshold = 0.025,
      shove_distance = 0,
    },
    
    death_reaction = {
      corpse_distance = 96,
      corpse_speed = 680,
      remove_delay = 1.3,
      effect_scale = 1.26,
    },
  },
}

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
    return 'normal'
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
  
  if scaled['最大生命'] or scaled['生命'] then
    local hp_key = scaled['最大生命'] and '最大生命' or '生命'
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
