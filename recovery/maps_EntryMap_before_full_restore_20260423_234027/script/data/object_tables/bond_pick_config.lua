local CsvLoader = require 'data.csv_loader'

local rule_rows = CsvLoader.read_rows('data_csv/bond_pick_rules.csv')
local weight_rows = CsvLoader.read_rows('data_csv/bond_pick_weights.csv')

local config = {
  choice_count = 3,
  include_group_choices = true,
  weights = {},
}

for _, row in ipairs(rule_rows) do
  if row.key == 'choice_count' then
    config.choice_count = tonumber(row.value) or config.choice_count
  elseif row.key == 'include_group_choices' then
    config.include_group_choices = row.value == '1' or row.value == 'true'
  end
end

for _, row in ipairs(weight_rows) do
  config.weights[row.candidate_kind] = tonumber(row.base_weight) or 1
end

function config.get_candidate_weight(candidate)
  if candidate and candidate.id and string.sub(candidate.id, 1, 8) == '__group_' then
    return config.weights.group or 1
  end
  return config.weights.node or 1
end

return config
