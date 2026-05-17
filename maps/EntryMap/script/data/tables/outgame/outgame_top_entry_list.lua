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

local ACTION_BY_LABEL = {
  ['开始'] = 'start_stage',
  ['存档'] = 'open_archive',
  ['生涯'] = 'open_archive_career',
  ['养成'] = 'open_archive_career',
  ['商城'] = 'open_archive_shop',
  ['排行'] = 'open_archive_ranking',
  ['排行榜'] = 'open_archive_ranking',
  ['挂机'] = 'switch_cultivation',
  ['战令'] = 'open_battlepass',
  ['图鉴'] = 'open_archive_album',
  ['键位'] = 'open_keymap_settings',
  ['设置'] = 'open_system_settings',
  ['退出'] = 'open_exit_confirm',
  ['暂停'] = 'toggle_soft_pause',
}

local default_list = {
  { id = 'start',      slot = 1, label = '开始', title = '开始游戏', action = 'start_stage',           visible_in_outgame = true, visible_in_battle = true },
  { id = 'archive',    slot = 2, label = '存档', title = '存档',     action = 'open_archive',          visible_in_outgame = true, visible_in_battle = true },
  { id = 'career',     slot = 3, label = '生涯', title = '生涯',     action = 'open_archive_career',   visible_in_outgame = true, visible_in_battle = true },
  { id = 'shop',       slot = 4, label = '商城', title = '商城',     action = 'open_archive_shop',     visible_in_outgame = true, visible_in_battle = true },
  { id = 'ranking',    slot = 5, label = '排行', title = '排行榜',   action = 'open_archive_ranking',  visible_in_outgame = true, visible_in_battle = true },
  { id = 'idle',       slot = 6, label = '挂机', title = '挂机',     action = 'switch_cultivation',    visible_in_outgame = true, visible_in_battle = true },
  { id = 'battlepass', slot = 7, label = '战令', title = '战令',     action = 'open_battlepass',       visible_in_outgame = true, visible_in_battle = true },
}

local rows = CsvLoader.read_rows_optional({path = 'data_csv/outgame/outgame_top_entry_list.csv'})
local list = {}

for row_index, row in ipairs(rows) do
  local enabled = to_bool(row.enabled, true)
  if enabled then
    -- 兼容两种 CSV：
    -- 1) 完整字段：id/slot/label/title/action/visible_in_outgame/enabled
    -- 2) 简版字段：按钮/动作/显示（按行顺序自动决定 slot）
    local label = trim(row.label)
    if label == '' then label = trim(row.name) end
    if label == '' then label = trim(row['按钮']) end

    local title = trim(row.title)
    if title == '' then title = trim(row['标题']) end
    if title == '' then title = label end

    local action = trim(row.action)
    if action == '' then action = trim(row['动作']) end
    if action == '' then action = ACTION_BY_LABEL[label] or '' end

    local slot = tonumber(row.slot) or tonumber(row.index) or tonumber(row['序号']) or row_index
    local id = trim(row.id)
    if id == '' then
      id = trim(row.key)
    end
    if id == '' then
      id = string.format('top_%d', tonumber(slot) or row_index)
    end

    if id ~= '' and slot > 0 and action ~= '' then
      list[#list + 1] = {
        id = id,
        slot = slot,
        label = (label ~= '' and label) or id,
        title = title,
        action = action,
        visible_in_outgame = to_bool(row.visible_in_outgame, to_bool(row['显示'], true)),
        visible_in_battle = to_bool(row.visible_in_battle, to_bool(row['局内显示'], true)),
      }
    end
  end
end

if #list == 0 then
  list = default_list
end

table.sort(list, function(a, b)
  if (a.slot or 0) == (b.slot or 0) then
    return tostring(a.id or '') < tostring(b.id or '')
  end
  return (a.slot or 0) < (b.slot or 0)
end)

M.list = list
M.by_id = {}
M.by_slot = {}
for _, entry in ipairs(M.list) do
  M.by_id[entry.id] = entry
  M.by_slot[tonumber(entry.slot) or 0] = entry
end

return M

