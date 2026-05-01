local CsvLoader = require 'data.csv_loader'

local M = {}

local function trim(value)
  local s = tostring(value or '')
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function to_bool(raw, default_value)
  local text = string.lower(trim(raw))
  if text == '' then
    return default_value == true
  end
  return text == '1' or text == 'true' or text == 'yes' or text == 'y'
end

local function put_spec(target, field, state_key, value)
  if value == '' then
    return
  end
  if state_key == 'default' then
    target[field] = value
    return
  end
  local bucket_key = field .. '_by_state'
  target[bucket_key] = target[bucket_key] or {}
  target[bucket_key][state_key] = value
end

local rows = CsvLoader.read_rows_optional('data_csv/outgame_detail_config.csv')

local list = {}
local by_id = {}
local mode_details = {}
local stage_details = {}

for _, row in ipairs(rows) do
  local enabled = to_bool(row.enabled, true)
  if enabled then
    local item = {
      id = trim(row.id),
      scope = trim(row.scope),
      view_mode = trim(row.view_mode),
      stage_id = trim(row.stage_id),
      state_key = trim(row.state_key),
      title = trim(row.title),
      status = trim(row.status),
      hint = trim(row.hint),
      order_index = tonumber(row.order_index) or 0,
    }
    if item.state_key == '' then
      item.state_key = 'default'
    end

    list[#list + 1] = item
    if item.id ~= '' then
      by_id[item.id] = item
    end
  end
end

table.sort(list, function(a, b)
  if (a.order_index or 0) == (b.order_index or 0) then
    return tostring(a.id or '') < tostring(b.id or '')
  end
  return (a.order_index or 0) < (b.order_index or 0)
end)

for _, item in ipairs(list) do
  if item.scope == 'mode' and item.view_mode ~= '' then
    mode_details[item.view_mode] = mode_details[item.view_mode] or {}
    put_spec(mode_details[item.view_mode], 'title', item.state_key, item.title)
    put_spec(mode_details[item.view_mode], 'status', item.state_key, item.status)
    put_spec(mode_details[item.view_mode], 'hint', item.state_key, item.hint)
  elseif item.scope == 'stage' and item.stage_id ~= '' then
    stage_details[item.stage_id] = stage_details[item.stage_id] or {}
    put_spec(stage_details[item.stage_id], 'title', item.state_key, item.title)
    put_spec(stage_details[item.stage_id], 'status', item.state_key, item.status)
    put_spec(stage_details[item.stage_id], 'hint', item.state_key, item.hint)
  end
end

M.list = list
M.by_id = by_id
M.mode_details = mode_details
M.stage_details = stage_details

return M

