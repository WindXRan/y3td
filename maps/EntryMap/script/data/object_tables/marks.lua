local CsvLoader = require 'data.csv_loader'
local AttrEffect = require 'data.object_tables.attreffect'
local helpers = require 'entry_objects.helpers'

local mark_rows = CsvLoader.read_rows('data_csv/marks.csv')
local tag_rows = CsvLoader.read_rows('data_csv/mark_tags.csv')
local bonus_groups = AttrEffect.by_source.mark or {}
local tag_groups = CsvLoader.group_by(tag_rows, 'mark_id')

local function to_number_if_possible(raw)
  if raw == nil or raw == '' then
    return nil
  end

  return tonumber(raw) or raw
end

local function sort_by_order_index(rows, fallback_key)
  table.sort(rows, function(a, b)
    local a_order = tonumber(a.order_index) or 0
    local b_order = tonumber(b.order_index) or 0
    if a_order == b_order then
      return tostring(a[fallback_key] or '') < tostring(b[fallback_key] or '')
    end
    return a_order < b_order
  end)
end

local function clone_number_map(source)
  local result = nil
  for key, value in pairs(source or {}) do
    result = result or {}
    result[key] = tonumber(value) or 0
  end
  return result
end

local function build_bonus_bucket(mark_id, bucket_name)
  local bucket = bonus_groups[mark_id]
  return clone_number_map(bucket and bucket[bucket_name] or nil)
end

local list = {}
for _, row in ipairs(mark_rows) do
  local tags = {}
  local grouped_tags = tag_groups[row.id] or {}
  sort_by_order_index(grouped_tags, 'tag')
  for _, tag_row in ipairs(grouped_tags) do
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
      attr = build_bonus_bucket(row.id, 'attr'),
      runtime = build_bonus_bucket(row.id, 'runtime'),
      attack_skill = build_bonus_bucket(row.id, 'attack_skill'),
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
