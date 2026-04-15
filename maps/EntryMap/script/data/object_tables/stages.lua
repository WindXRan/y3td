local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local stage_rows = CsvLoader.read_rows('data_csv/stages.csv')
local stage_mode_link_rows = CsvLoader.read_rows('data_csv/stage_mode_links.csv')
local mode_groups = CsvLoader.group_by(stage_mode_link_rows, 'stage_id')

local function build_mode_ids(stage_id)
  local rows = {}
  for _, row in ipairs(mode_groups[stage_id] or {}) do
    rows[#rows + 1] = {
      order_index = tonumber(row.order_index) or 0,
      mode_id = row.mode_id,
    }
  end

  table.sort(rows, function(a, b)
    return a.order_index < b.order_index
  end)

  local mode_ids = {}
  for _, row in ipairs(rows) do
    mode_ids[#mode_ids + 1] = row.mode_id
  end
  return mode_ids
end

local list = {}
for _, row in ipairs(stage_rows) do
  list[#list + 1] = {
    id = row.id,
    stage_id = row.stage_id,
    display_name = row.display_name,
    order_index = tonumber(row.order_index) or 0,
    content_source_stage_id = row.content_source_stage_id,
    mode_ids = build_mode_ids(row.stage_id),
    preview_note = row.preview_note ~= '' and row.preview_note or nil,
  }
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
