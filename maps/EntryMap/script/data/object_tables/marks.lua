local CsvLoader = require 'data.csv_loader'
local helpers = require 'entry_objects.helpers'

local mark_rows = CsvLoader.read_rows('data_csv/marks.csv')
local bonus_attr_rows = CsvLoader.read_rows('data_csv/mark_bonus_attr.csv')
local bonus_runtime_rows = CsvLoader.read_rows('data_csv/mark_bonus_runtime.csv')
local tag_rows = CsvLoader.read_rows('data_csv/mark_tags.csv')

local bonus_attr_groups = CsvLoader.group_by(bonus_attr_rows, 'mark_id')
local bonus_runtime_groups = CsvLoader.group_by(bonus_runtime_rows, 'mark_id')
local tag_groups = CsvLoader.group_by(tag_rows, 'mark_id')

local function to_number_if_possible(raw)
  if raw == nil or raw == '' then
    return nil
  end

  return tonumber(raw) or raw
end

local function build_bonus_attr(mark_id)
  local attr = nil
  for _, row in ipairs(bonus_attr_groups[mark_id] or {}) do
    attr = attr or {}
    attr[row.attr] = to_number_if_possible(row.value)
  end
  return attr
end

local function build_bonus_runtime(mark_id, bucket_name)
  local bucket = nil
  for _, row in ipairs(bonus_runtime_groups[mark_id] or {}) do
    if row.bucket == bucket_name then
      bucket = bucket or {}
      bucket[row.runtime_key] = to_number_if_possible(row.value)
    end
  end
  return bucket
end

local list = {}
for _, row in ipairs(mark_rows) do
  local tags = {}
  for _, tag_row in ipairs(tag_groups[row.id] or {}) do
    tags[#tags + 1] = tag_row.tag
  end

  list[#list + 1] = {
    id = row.id,
    name = row.name,
    quality = row.quality,
    pool_weight = tonumber(row.pool_weight) or 0,
    order_index = tonumber(row.order_index) or 0,
    summary = row.summary,
    tags = tags,
    bonuses = {
      attr = build_bonus_attr(row.id),
      runtime = build_bonus_runtime(row.id, 'runtime'),
      attack_skill = build_bonus_runtime(row.id, 'attack_skill'),
    },
  }
end

table.sort(list, function(a, b)
  return (a.order_index or 0) < (b.order_index or 0)
end)

return {
  list = list,
  by_id = helpers.list_to_map(list),
}
