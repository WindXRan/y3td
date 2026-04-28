local CsvLoader = require 'data.csv_loader'

local group_label_rows = CsvLoader.read_rows_optional('data_csv/bond_group_labels.csv')
local per_second_rows = CsvLoader.read_rows_optional('data_csv/bond_per_second_attr_keys.csv')
local color_keyword_rows = CsvLoader.read_rows('data_csv/bond_manual_color_keywords.csv')

local config = {
  group_labels = {},
  per_second_attr_keys = {},
  manual_color_keywords = {},
}

for _, row in ipairs(group_label_rows) do
  config.group_labels[row.group_id] = row.display_name
end

for _, row in ipairs(per_second_rows) do
  config.per_second_attr_keys[row.runtime_key] = row.attr_name
end

for _, row in ipairs(color_keyword_rows) do
  config.manual_color_keywords[row.color] = config.manual_color_keywords[row.color] or {}
  config.manual_color_keywords[row.color][#config.manual_color_keywords[row.color] + 1] = row.pattern
end

config.manual_color_keywords.green = config.manual_color_keywords.green or {}
config.manual_color_keywords.cyan = config.manual_color_keywords.cyan or {}

return config
