local CsvLoader = require 'data.csv_loader'
local hero_attr_config = require 'data.object_tables.hero_attr_config'

local function parse_scalar(raw)
  if raw == 'true' then
    return true
  end
  if raw == 'false' then
    return false
  end
  return tonumber(raw) or raw
end

local function read_rule_groups(path)
  local rows = CsvLoader.read_rows(path)
  local result = {}
  for _, row in ipairs(rows) do
    result[row.group] = result[row.group] or {}
    result[row.group][row.key] = parse_scalar(row.value)
  end
  return result
end

local groups = read_rule_groups('data_csv/battle_base_rules.csv')
local flags = groups.flags or {}

return {
  global_rules = groups.global_rules or {},
  hero_init_stats = hero_attr_config.hero_init_stats,
  debug_hero_bonus_stats = hero_attr_config.debug_hero_bonus_stats,
  debug_apply_hero_bonus_on_spawn = flags.debug_apply_hero_bonus_on_spawn == true,
  progression_rules = groups.progression_rules or {},
  resource_rules = groups.resource_rules or {},
  challenge_rules = groups.challenge_rules or {},
}
