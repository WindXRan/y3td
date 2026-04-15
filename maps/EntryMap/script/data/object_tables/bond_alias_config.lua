local CsvLoader = require 'data.csv_loader'

local node_alias_rows = CsvLoader.read_rows('data_csv/bond_node_aliases.csv')
local attr_alias_rows = CsvLoader.read_rows('data_csv/bond_runtime_attr_aliases.csv')
local runtime_alias_rows = CsvLoader.read_rows('data_csv/bond_runtime_aliases.csv')

local config = {
  legacy_tags_by_node_id = {},
  attr_aliases_from_runtime = {},
  runtime_aliases = {},
}

for _, row in ipairs(node_alias_rows) do
  config.legacy_tags_by_node_id[row.node_id] = config.legacy_tags_by_node_id[row.node_id] or {}
  config.legacy_tags_by_node_id[row.node_id][#config.legacy_tags_by_node_id[row.node_id] + 1] = row.legacy_tag
end

for _, row in ipairs(attr_alias_rows) do
  config.attr_aliases_from_runtime[row.runtime_key] = config.attr_aliases_from_runtime[row.runtime_key] or {}
  config.attr_aliases_from_runtime[row.runtime_key][row.attr_name] = tonumber(row.factor) or 0
end

for _, row in ipairs(runtime_alias_rows) do
  config.runtime_aliases[row.runtime_key] = config.runtime_aliases[row.runtime_key] or {}
  config.runtime_aliases[row.runtime_key][row.alias_key] = tonumber(row.factor) or 0
end

return config
