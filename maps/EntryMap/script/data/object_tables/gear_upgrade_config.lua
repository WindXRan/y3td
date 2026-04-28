local function make_bonus_pack(attack, hp, armor, all_attr)
  local pack = {}
  if (attack or 0) ~= 0 then
    pack['攻击'] = attack
  end
  if (hp or 0) ~= 0 then
    pack['生命'] = hp
  end
  if (armor or 0) ~= 0 then
    pack['护甲'] = armor
  end
  if (all_attr or 0) ~= 0 then
    pack['力量'] = all_attr
    pack['敏捷'] = all_attr
    pack['智力'] = all_attr
  end
  return pack
end

local slots = {
  weapon = {
    slot = 'weapon',
    order_index = 1,
    display_name = '成长武器',
    max_level = 50,
    affix_choice_count = 3,
    item_key = 100001,
    weapon_id = 'weapon',
    weapon_name = '成长武器',
    init_level = 1,
    base_desc = '可通过金币持续升级，并在关键等级获得词条选择。',
  },
}

local weapons_by_id = {
  weapon = {
    weapon_id = 'weapon',
    weapon_name = '成长武器',
    init_level = 1,
    max_level = 50,
    item_key = 100001,
    base_desc = '可通过金币持续升级，并在关键等级获得词条选择。',
    slot = 'weapon',
  },
}

local levels = {}
local levels_by_level = {}
local levels_by_weapon = { weapon = {} }

for level = 1, 50 do
  local is_affix_node = (level % 5 == 0)
  local affix_pool_id = nil
  if is_affix_node then
    if level <= 15 then
      affix_pool_id = 'weapon_affix_t1'
    elseif level <= 30 then
      affix_pool_id = 'weapon_affix_t2'
    else
      affix_pool_id = 'weapon_affix_t3'
    end
  end

  local entry = {
    weapon_id = 'weapon',
    level = level,
    order_index = level,
    gold_cost = math.floor(35 + level * 22),
    is_affix_node = is_affix_node,
    affix_pool_id = affix_pool_id,
    bonus_pack = make_bonus_pack(8 + level * 3, 30 + level * 12, level >= 20 and 1 or 0, level >= 30 and 1 or 0),
  }
  levels[#levels + 1] = entry
  levels_by_weapon.weapon[level] = entry
  levels_by_level[level] = entry
end

local affixes = {
  { affix_id = 'bow_sniper_t1',    pool_id = 'weapon_affix_t1', order_index = 1, quality = 'rare', display_name = '狙击箭', summary = '永久 +50 攻击范围，并且会射出 1 根狙击箭。', attr_name = '攻击范围', attr_value = 50, is_unique = false, unique_group = nil, bonus_pack = { ['攻击范围'] = 50, ['多重数量'] = 1, ['多重伤害'] = 1.25 } },
  { affix_id = 'bow_gale_t1',      pool_id = 'weapon_affix_t1', order_index = 2, quality = 'rare', display_name = '疾风箭', summary = '永久 +25% 攻速，并且会射出 1 根疾风箭。', attr_name = '攻击速度', attr_value = 25, is_unique = false, unique_group = nil, bonus_pack = { ['攻击速度'] = 25, ['多重数量'] = 1, ['多重伤害'] = 0.85 } },
  { affix_id = 'bow_multishot_t1', pool_id = 'weapon_affix_t1', order_index = 3, quality = 'rare', display_name = '多重箭', summary = '攻击额外射出 2 根普通箭。', attr_name = '多重数量', attr_value = 2, is_unique = false, unique_group = nil, bonus_pack = { ['多重数量'] = 2, ['多重伤害'] = 1.00 } },

  { affix_id = 'bow_sniper_t2',    pool_id = 'weapon_affix_t2', order_index = 1, quality = 'epic', display_name = '狙击箭+', summary = '永久 +70 攻击范围，并且会射出 1 根更强的狙击箭。', attr_name = '攻击范围', attr_value = 70, is_unique = false, unique_group = nil, bonus_pack = { ['攻击范围'] = 70, ['多重数量'] = 1, ['多重伤害'] = 1.45 } },
  { affix_id = 'bow_gale_t2',      pool_id = 'weapon_affix_t2', order_index = 2, quality = 'epic', display_name = '疾风箭+', summary = '永久 +30% 攻速，并且会射出 1 根更快的疾风箭。', attr_name = '攻击速度', attr_value = 30, is_unique = false, unique_group = nil, bonus_pack = { ['攻击速度'] = 30, ['多重数量'] = 1, ['多重伤害'] = 0.95 } },
  { affix_id = 'bow_multishot_t2', pool_id = 'weapon_affix_t2', order_index = 3, quality = 'epic', display_name = '多重箭+', summary = '攻击额外射出 2 根强化普通箭。', attr_name = '多重数量', attr_value = 2, is_unique = false, unique_group = nil, bonus_pack = { ['多重数量'] = 2, ['多重伤害'] = 1.10 } },

  { affix_id = 'bow_sniper_t3',    pool_id = 'weapon_affix_t3', order_index = 1, quality = 'epic', display_name = '狙击箭·终', summary = '永久 +90 攻击范围，并且会射出 1 根终极狙击箭。', attr_name = '攻击范围', attr_value = 90, is_unique = false, unique_group = nil, bonus_pack = { ['攻击范围'] = 90, ['多重数量'] = 1, ['多重伤害'] = 1.70 } },
  { affix_id = 'bow_gale_t3',      pool_id = 'weapon_affix_t3', order_index = 2, quality = 'epic', display_name = '疾风箭·终', summary = '永久 +35% 攻速，并且会射出 1 根终极疾风箭。', attr_name = '攻击速度', attr_value = 35, is_unique = false, unique_group = nil, bonus_pack = { ['攻击速度'] = 35, ['多重数量'] = 1, ['多重伤害'] = 1.05 } },
  { affix_id = 'bow_multishot_t3', pool_id = 'weapon_affix_t3', order_index = 3, quality = 'epic', display_name = '多重箭·终', summary = '攻击额外射出 2 根终极普通箭。', attr_name = '多重数量', attr_value = 2, is_unique = false, unique_group = nil, bonus_pack = { ['多重数量'] = 2, ['多重伤害'] = 1.20 } },
}

local affixes_by_id = {}
local affixes_by_pool = {}
for _, entry in ipairs(affixes) do
  affixes_by_id[entry.affix_id] = entry
  affixes_by_pool[entry.pool_id] = affixes_by_pool[entry.pool_id] or {}
  table.insert(affixes_by_pool[entry.pool_id], entry)
end

return {
  slots = slots,
  weapons_by_id = weapons_by_id,
  default_weapon_id = 'weapon',
  levels = levels,
  levels_by_level = levels_by_level,
  levels_by_weapon = levels_by_weapon,
  affixes = affixes,
  affixes_by_id = affixes_by_id,
  affixes_by_pool = affixes_by_pool,
}
