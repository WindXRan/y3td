local CsvLoader = require 'data.csv_loader'

local M = {}

local function trim(value)
  local s = tostring(value or '')
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function to_int(raw, default_value)
  local num = tonumber(raw)
  if num == nil then
    return default_value or 0
  end
  return num
end

local rows = CsvLoader.read_rows_optional('data_csv/outgame/outgame_ranking_players.csv')
local list = {}

for _, row in ipairs(rows) do
  local rank_type = to_int(row.rank_type)
  local score = to_int(row.score)
  local player_name = trim(row.player_name)

  if rank_type > 0 and player_name ~= '' then
    list[#list + 1] = {
      rank_type = rank_type,
      player_name = player_name,
      score = score,
    }
  end
end

table.sort(list, function(a, b)
  if a.rank_type ~= b.rank_type then
    return a.rank_type < b.rank_type
  end
  if (a.score or 0) ~= (b.score or 0) then
    return (a.score or 0) > (b.score or 0)
  end
  return tostring(a.player_name or '') < tostring(b.player_name or '')
end)

M.list = list

M.by_rank_type = {}
for _, player in ipairs(list) do
  local type_key = player.rank_type
  M.by_rank_type[type_key] = M.by_rank_type[type_key] or {}
  M.by_rank_type[type_key][#M.by_rank_type[type_key] + 1] = player
end

function M.get_players_for_rank_type(rank_type)
  return M.by_rank_type[rank_type] or {}
end

function M.get_top_players(rank_type, count)
  local players = M.by_rank_type[rank_type] or {}
  local result = {}
  for i, player in ipairs(players) do
    if i > count then
      break
    end
    result[#result + 1] = player
  end
  return result
end

return M