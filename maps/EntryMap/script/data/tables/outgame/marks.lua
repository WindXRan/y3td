local AttrEffect = require 'data.tables.skill.attreffect'
local HeroRoster = (require 'data.game_tables').hero_roster
local helpers = require 'data.tables.helpers'

local bonus_groups = AttrEffect.by_source.mark or {}
local hero_list = HeroRoster.list or {}

local list = {}

local function build_bonus_bucket(mark_id, bucket_name)
  local source = bonus_groups[mark_id]
  local bucket = source and source[bucket_name] or nil
  if not bucket then
    return nil
  end
  local out = {}
  for key, value in pairs(bucket) do
    out[key] = tonumber(value) or 0
  end
  return out
end

local function push_mark(index, hero_entry)
  local quality = 'common'
  if index >= 5 then
    quality = 'epic'
  elseif index >= 3 then
    quality = 'rare'
  end

  local mark_id = string.format('mark_%s', tostring(hero_entry.id or index))
  list[#list + 1] = {
    id = mark_id,
    name = hero_entry.name or ('英雄专精' .. tostring(index)),
    quality = quality,
    pool_weight = quality == 'epic' and 20 or (quality == 'rare' and 35 or 45),
    order_index = index,
    hero_unit_id = hero_entry.unit_id,
    summary = hero_entry.summary or '激活该英雄真身与专精效果。',
    tags = { 'hero_form', quality },
    bonuses = {
      attr = build_bonus_bucket(mark_id, 'attr'),
      runtime = build_bonus_bucket(mark_id, 'runtime'),
      attack_skill = build_bonus_bucket(mark_id, 'attack_skill'),
    },
  }
end

for index, hero_entry in ipairs(hero_list) do
  if index > 8 then
    break
  end
  if hero_entry and hero_entry.id and hero_entry.unit_id then
    push_mark(index, hero_entry)
  end
end

if #list < 2 then
  for index = #list + 1, 2 do
    list[#list + 1] = {
      id = string.format('mark_fallback_%d', index),
      name = string.format('英雄专精 %d', index),
      quality = index == 2 and 'rare' or 'common',
      pool_weight = 30,
      order_index = index,
      hero_unit_id = 100001 + index,
      summary = '激活该英雄真身与专精效果。',
      tags = { 'hero_form' },
      bonuses = {
        attr = nil,
        runtime = nil,
        attack_skill = nil,
      },
    }
  end
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}




