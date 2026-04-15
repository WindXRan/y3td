local CsvLoader = require 'data.csv_loader'

local rows = CsvLoader.read_rows('data_csv/battlefield_unit_config.csv')

local temp_unit_labels = {}
local fixed_unit_ids = {}

for _, row in ipairs(rows) do
  temp_unit_labels[row.role_id] = row.label ~= '' and row.label or nil
  if row.unit_id ~= nil and row.unit_id ~= '' then
    fixed_unit_ids[row.role_id] = tonumber(row.unit_id) or row.unit_id
  end
end

return {
  temp_unit_labels = temp_unit_labels,
  fixed_unit_ids = fixed_unit_ids,
}
