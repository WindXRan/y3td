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

local function to_int(raw, default_value)
  local num = tonumber(raw)
  if num == nil then
    return default_value or 0
  end
  return num
end

local default_rewards = {
  { rank_type = 1, rank_min = 1, rank_max = 1, reward_category = 'special', reward_type = 'item', reward_id = 'wing_ur_s圣光', reward_name = 'UR翅膀[圣光翅膀]', reward_icon = 134223473, reward_count = 1 },
  { rank_type = 1, rank_min = 1, rank_max = 1, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 5000 },
  { rank_type = 1, rank_min = 2, rank_max = 3, reward_category = 'special', reward_type = 'item', reward_id = 'wing_ur_s圣光', reward_name = 'UR翅膀[圣光翅膀]', reward_icon = 134223473, reward_count = 1 },
  { rank_type = 1, rank_min = 2, rank_max = 3, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 3000 },
  { rank_type = 1, rank_min = 4, rank_max = 10, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 2000 },
  { rank_type = 1, rank_min = 4, rank_max = 10, reward_category = 'normal', reward_type = 'currency', reward_id = 'gem', reward_name = '钻石', reward_count = 50 },
  { rank_type = 1, rank_min = 11, rank_max = 50, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 1000 },
  { rank_type = 1, rank_min = 11, rank_max = 50, reward_category = 'normal', reward_type = 'currency', reward_id = 'gem', reward_name = '钻石', reward_count = 20 },
  { rank_type = 2, rank_min = 1, rank_max = 1, reward_category = 'special', reward_type = 'item', reward_id = 'wing_ur_s圣光', reward_name = 'UR翅膀[圣光翅膀]', reward_icon = 134223473, reward_count = 1 },
  { rank_type = 2, rank_min = 1, rank_max = 1, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 8000 },
  { rank_type = 2, rank_min = 2, rank_max = 3, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 5000 },
  { rank_type = 2, rank_min = 2, rank_max = 3, reward_category = 'normal', reward_type = 'currency', reward_id = 'gem', reward_name = '钻石', reward_count = 100 },
  { rank_type = 2, rank_min = 4, rank_max = 10, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 3000 },
  { rank_type = 2, rank_min = 4, rank_max = 10, reward_category = 'normal', reward_type = 'currency', reward_id = 'gem', reward_name = '钻石', reward_count = 50 },
  { rank_type = 2, rank_min = 11, rank_max = 50, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 1500 },
  { rank_type = 3, rank_min = 1, rank_max = 1, reward_category = 'special', reward_type = 'item', reward_id = 'material_rare', reward_name = '稀有材料', reward_count = 10 },
  { rank_type = 3, rank_min = 1, rank_max = 1, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 6000 },
  { rank_type = 3, rank_min = 2, rank_max = 3, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 4000 },
  { rank_type = 3, rank_min = 2, rank_max = 3, reward_category = 'normal', reward_type = 'currency', reward_id = 'gem', reward_name = '钻石', reward_count = 80 },
  { rank_type = 3, rank_min = 4, rank_max = 10, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 2500 },
  { rank_type = 3, rank_min = 4, rank_max = 10, reward_category = 'normal', reward_type = 'currency', reward_id = 'material_common', reward_name = '普通材料', reward_count = 20 },
  { rank_type = 3, rank_min = 11, rank_max = 50, reward_category = 'normal', reward_type = 'currency', reward_id = 'gold', reward_name = '金币', reward_count = 1200 },
}

local rows = CsvLoader.read_rows_optional('data_csv/outgame/outgame_ranking_rewards.csv')
local list = {}

for _, row in ipairs(rows) do
  local rank_type = to_int(row.rank_type)
  local rank_min = to_int(row.rank_min)
  local rank_max = to_int(row.rank_max)
  
  if rank_type > 0 and rank_min > 0 and rank_max >= rank_min then
    local category = trim(row.reward_category)
    if category == '' then
      category = 'normal'
    end
    
    list[#list + 1] = {
      rank_type = rank_type,
      rank_min = rank_min,
      rank_max = rank_max,
      reward_category = category,
      reward_type = trim(row.reward_type) or 'currency',
      reward_id = trim(row.reward_id) or '',
      reward_name = trim(row.reward_name) or '',
      reward_icon = to_int(row.reward_icon),
      reward_count = to_int(row.reward_count, 1),
      special_reward = trim(row.special_reward) or '',
    }
  end
end

if #list == 0 then
  list = default_rewards
end

table.sort(list, function(a, b)
  if a.rank_type ~= b.rank_type then
    return a.rank_type < b.rank_type
  end
  if a.rank_min ~= b.rank_min then
    return a.rank_min < b.rank_min
  end
  if a.reward_category ~= b.reward_category then
    return a.reward_category == 'special'
  end
  return a.reward_type < b.reward_type
end)

M.list = list

M.by_rank_type = {}
M.by_rank_type_and_category = {}

for _, reward in ipairs(list) do
  local type_key = reward.rank_type
  M.by_rank_type[type_key] = M.by_rank_type[type_key] or {}
  M.by_rank_type[type_key][#M.by_rank_type[type_key] + 1] = reward
  
  local type_category_key = string.format('%d_%s', type_key, reward.reward_category)
  M.by_rank_type_and_category[type_category_key] = M.by_rank_type_and_category[type_category_key] or {}
  M.by_rank_type_and_category[type_category_key][#M.by_rank_type_and_category[type_category_key] + 1] = reward
end

function M.get_rewards_for_rank(rank_type, rank)
  local rewards = M.by_rank_type[rank_type] or {}
  local result = {}
  for _, reward in ipairs(rewards) do
    if rank >= reward.rank_min and rank <= reward.rank_max then
      result[#result + 1] = reward
    end
  end
  return result
end

function M.get_special_rewards_for_rank(rank_type, rank)
  local rewards = M.get_rewards_for_rank(rank_type, rank)
  local result = {}
  for _, reward in ipairs(rewards) do
    if reward.reward_category == 'special' then
      result[#result + 1] = reward
    end
  end
  return result
end

function M.get_normal_rewards_for_rank(rank_type, rank)
  local rewards = M.get_rewards_for_rank(rank_type, rank)
  local result = {}
  for _, reward in ipairs(rewards) do
    if reward.reward_category == 'normal' then
      result[#result + 1] = reward
    end
  end
  return result
end

function M.get_rewards_for_rank_type(rank_type)
  return M.by_rank_type[rank_type] or {}
end

function M.get_rewards_by_category(rank_type, category)
  local key = string.format('%d_%s', rank_type, category)
  return M.by_rank_type_and_category[key] or {}
end

return M