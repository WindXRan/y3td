local CsvLoader = require 'data.csv_loader'
local helpers = require 'data.tables.helpers'

local meta_rows = CsvLoader.read_rows_optional('data_csv/attack_skill_second_batch_meta.csv')
local lane_rows = CsvLoader.read_rows_optional('data_csv/attack_skill_second_batch_growth_lanes.csv')
local skill_rows = CsvLoader.read_rows_optional('data_csv/attack_skill_second_batch_skills.csv')
local evolution_rows = CsvLoader.read_rows_optional('data_csv/attack_skill_second_batch_evolutions.csv')
local card_rows = CsvLoader.read_rows_optional('data_csv/attack_skill_second_batch_cards.csv')
local ACTIVE_SKILL_IDS = {}

local evolution_by_skill = {}
for _, row in ipairs(evolution_rows) do
  evolution_by_skill[row.skill_id] = row
end

local cards_by_skill = CsvLoader.group_by(card_rows, 'skill_id')

local function to_scalar(raw)
  if raw == nil or raw == '' then
    return nil
  end
  return tonumber(raw) or raw
end

local meta_map = {}
for _, row in ipairs(meta_rows) do
  meta_map[row.key] = row.value
end

local growth_lanes = {}
table.sort(lane_rows, function(a, b)
  return (tonumber(a.seq) or 0) < (tonumber(b.seq) or 0)
end)
for _, row in ipairs(lane_rows) do
  growth_lanes[#growth_lanes + 1] = row.lane
end

local function build_cards(skill_id)
  local buckets = {
    common = {},
    excellent = {},
    rare = {},
    legendary = {},
  }

  local rows = {}
  for _, row in ipairs(cards_by_skill[skill_id] or {}) do
    rows[#rows + 1] = {
      bucket = row.bucket,
      seq = tonumber(row.seq) or 0,
      card_id = row.card_id,
      card_name = row.card_name,
      lane = row.lane,
      rarity = row.rarity,
      summary = row.summary,
    }
  end

  table.sort(rows, function(a, b)
    if a.bucket == b.bucket then
      return a.seq < b.seq
    end
    return a.bucket < b.bucket
  end)

  for _, row in ipairs(rows) do
    buckets[row.bucket][#buckets[row.bucket] + 1] = {
      id = row.card_id,
      name = row.card_name,
      lane = row.lane,
      rarity = row.rarity,
      summary = row.summary,
    }
  end

  return buckets
end

local list = {}
for _, row in ipairs(skill_rows) do
  if not ACTIVE_SKILL_IDS[row.id] then
    goto continue
  end
  local evolution = evolution_by_skill[row.id] or {}
  list[#list + 1] = {
    id = row.id,
    name = row.name,
    summary = row.summary,
    damage_type = row.damage_type,
    damage_form = row.damage_form,
    element = row.element,
    damage_label = row.damage_label,
    ui_icon = to_scalar(row.ui_icon),
    icon = to_scalar(row.ui_icon),
    archetype = row.archetype,
    base = {
      damage_ratio = to_scalar(row.damage_ratio),
      cooldown = to_scalar(row.cooldown),
      range = to_scalar(row.range),
      pierce = to_scalar(row.pierce),
      duration = to_scalar(row.duration),
      radius = to_scalar(row.radius),
      bounce = to_scalar(row.bounce),
    },
    evolution = {
      id = evolution.evolution_id,
      name = evolution.evolution_name,
      summary = evolution.evolution_summary,
    },
    cards = build_cards(row.id),
  }
  ::continue::
end

local active_skill_count = #list
local free_attack_skill_slots = math.max(0, math.min(tonumber(meta_map.free_attack_skill_slots) or 0, active_skill_count))
local total_attack_skills = 1 + free_attack_skill_slots
local runtime_note = meta_map.note or ''
if active_skill_count <= 0 then
  runtime_note = runtime_note .. ' 当前没有启用的可解锁攻击技能。'
else
  runtime_note = string.format('%s 当前运行时仅启用 %d 个代表技能。', runtime_note, active_skill_count)
end

return {
  version = meta_map.version,
  status = meta_map.status,
  note = runtime_note,
  system = {
    slot_rule = {
      fixed_base_slot = meta_map.fixed_base_slot,
      free_attack_skill_slots = free_attack_skill_slots,
      total_attack_skills = total_attack_skills,
      notation = string.format('1 个固定基础位 + %d 个自由攻击技能位', free_attack_skill_slots),
    },
    run_rule = {
      target_duration_minutes = tonumber(meta_map.target_duration_minutes) or 0,
      level_cap = meta_map.level_cap,
      xp_curve = meta_map.xp_curve,
      first_legend_window = meta_map.first_legend_window,
    },
    card_rule = {
      notation = meta_map.card_notation,
      rarity_plan = {
        common = tonumber(meta_map.rarity_plan_common) or 0,
        excellent = tonumber(meta_map.rarity_plan_excellent) or 0,
        rare = tonumber(meta_map.rarity_plan_rare) or 0,
        legendary = tonumber(meta_map.rarity_plan_legendary) or 0,
      },
      atomicity = meta_map.atomicity,
      growth_lanes = growth_lanes,
    },
  },
  list = list,
  by_id = helpers.list_to_map(list),
}


