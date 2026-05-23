local M = {}

local STATE
local CONFIG
local y3
local OUTGAME_DEFS
local OUTGAME_ATTR_BONUS_BY_STAGE_MODE
local SAVE_SLOT = 1
local SINGLE_MODE_ID = 'standard'
local VIEW_MODE_MAINLINE = 'mainline'
local VIEW_MODE_CULTIVATION = 'cultivation'

function M.init(env)
  STATE = env.STATE
  CONFIG = env.CONFIG
  y3 = env.y3
  OUTGAME_DEFS = env.OUTGAME_DEFS
  OUTGAME_ATTR_BONUS_BY_STAGE_MODE = CONFIG.outgame_attr_bonus_config
    and CONFIG.outgame_attr_bonus_config.by_stage_mode
    or {}
  SAVE_SLOT = CONFIG.save_slots and CONFIG.save_slots.outgame_profile or 1
end

function M.set_save_backend_state(enabled, detail)
  STATE.outgame_profile_save_enabled = enabled == true
  if enabled == true then
    STATE.outgame_profile_save_error = nil
    return
  end
  if detail ~= nil and detail ~= '' then
    STATE.outgame_profile_save_error = tostring(detail)
    return
  end
  if not STATE.outgame_profile_save_error or STATE.outgame_profile_save_error == '' then
    STATE.outgame_profile_save_error = '局外存档不可用'
  end
end

function M.build_save_status_brief(profile)
  if STATE.outgame_profile_save_enabled == true then
    return string.format('槽位 %d · 云端已连接', SAVE_SLOT)
  end
  return string.format('槽位 %d · 当前为内存态\n点击按钮查看原因', SAVE_SLOT)
end

function M.build_save_status_detail(profile)
  if STATE.outgame_profile_save_enabled == true then
    return string.format(
      '局外存档已连接到槽位 %d。\n系统会在关键节点自动上传，也可以手动保存一次。',
      SAVE_SLOT
    )
  end
  return string.format(
    '当前会话使用内存态默认档。\n原因：%s',
    tostring(STATE.outgame_profile_save_error or '局外存档不可用')
  )
end

function M.mark_profile_dirty()
  if STATE.outgame_profile_save_enabled ~= true then
    return
  end
  local ok, err = pcall(y3.save_data.upload_save_data, y3.player.get_main_player())
  if ok then
    M.set_save_backend_state(true)
    return
  end
  M.set_save_backend_state(false, err)
end

function M.normalize_loaded_selection(profile)
  local dirty = false
  if profile.selected_mode_id ~= SINGLE_MODE_ID then
    profile.selected_mode_id = SINGLE_MODE_ID
    dirty = true
  end
  if profile.selected_view_mode ~= VIEW_MODE_MAINLINE and profile.selected_view_mode ~= VIEW_MODE_CULTIVATION then
    profile.selected_view_mode = VIEW_MODE_MAINLINE
    dirty = true
  end
  return dirty
end

local function merge_bonus_stats(target, source)
  for attr_name, value in pairs(source or {}) do
    local number = tonumber(value)
    if attr_name ~= nil and attr_name ~= '' and number ~= nil and number ~= 0 then
      target[attr_name] = (target[attr_name] or 0) + number
    end
  end
end

local function are_same_bonus_stats(left, right)
  left = type(left) == 'table' and left or {}
  right = type(right) == 'table' and right or {}
  for key, value in pairs(left) do
    if (tonumber(value) or value) ~= (tonumber(right[key]) or right[key]) then
      return false
    end
  end
  for key, value in pairs(right) do
    if (tonumber(value) or value) ~= (tonumber(left[key]) or left[key]) then
      return false
    end
  end
  return true
end

function M.rebuild_hero_attr_bonus_stats(profile)
  local rebuilt = {}
  if are_same_bonus_stats(profile.hero_attr_bonus_stats, rebuilt) then
    return false
  end
  profile.hero_attr_bonus_stats = rebuilt
  return true
end

local function ensure_archive_item_entry(profile, spec)
  if type(profile) ~= 'table' or type(spec) ~= 'table' then
    return false
  end
  if type(profile.archive_items) ~= 'table' then
    profile.archive_items = {}
  end
  local key = require('ui.outgame.utils').archive_item_profile_key(spec)
  if key == '||' or key == '' then
    return false
  end
  spec.archive_profile_key = key
  local entry = profile.archive_items[key]
  local dirty = false
  if type(entry) ~= 'table' then
    entry = {}
    profile.archive_items[key] = entry
    dirty = true
  end
  if entry.owned_text == nil then
    entry.owned_text = tostring(spec.owned_text or '')
    dirty = true
  end
  if spec.stackable == true then
    local normalized = tostring(require('ui.outgame.utils').to_archive_integer(entry.owned_text))
    if entry.owned_text ~= normalized then
      entry.owned_text = normalized
      dirty = true
    end
  end
  if type(entry.runtime_level) ~= 'number' then
    entry.runtime_level = require('ui.outgame.utils').to_archive_integer(entry.runtime_level)
    dirty = true
  end
  if type(entry.runtime_reroll_count) ~= 'number' then
    entry.runtime_reroll_count = require('ui.outgame.utils').to_archive_integer(entry.runtime_reroll_count)
    dirty = true
  end
  if entry.runtime_equipped ~= true and entry.runtime_equipped ~= false then
    entry.runtime_equipped = false
    dirty = true
  end
  if entry.runtime_random_bonus ~= nil and type(entry.runtime_random_bonus) ~= 'string' then
    entry.runtime_random_bonus = tostring(entry.runtime_random_bonus)
    dirty = true
  end
  return dirty
end

function M.ensure_archive_items_profile_defaults(profile)
  local dirty = false
  if type(profile.archive_items) ~= 'table' then
    profile.archive_items = {}
    dirty = true
  end
  for _, spec in ipairs(OUTGAME_DEFS.archive_shop_item_specs or {}) do
    if spec.source == 'csv_shangchengdaojv_feature' then
      if ensure_archive_item_entry(profile, spec) then
        dirty = true
      end
    end
  end
  return dirty
end

function M.apply_archive_item_profile_to_spec(profile, spec)
  if type(profile) ~= 'table' or type(spec) ~= 'table' then
    return
  end
  local key = spec.archive_profile_key or require('ui.outgame.utils').archive_item_profile_key(spec)
  local entry = type(profile.archive_items) == 'table' and profile.archive_items[key] or nil
  if type(entry) ~= 'table' then
    return
  end
  spec.archive_profile_key = key
  spec.owned_text = tostring(entry.owned_text or '')
  spec.runtime_level = require('ui.outgame.utils').to_archive_integer(entry.runtime_level)
  spec.runtime_reroll_count = require('ui.outgame.utils').to_archive_integer(entry.runtime_reroll_count)
  spec.runtime_equipped = entry.runtime_equipped == true
  spec.runtime_random_bonus = entry.runtime_random_bonus
end

function M.sync_archive_shop_specs_from_profile(profile)
  profile = profile or M.load_profile()
  if type(profile) ~= 'table' then
    return
  end
  if M.ensure_archive_items_profile_defaults(profile) then
    M.mark_profile_dirty()
  end
  for _, spec in ipairs(OUTGAME_DEFS.archive_shop_item_specs or {}) do
    if spec.source == 'csv_shangchengdaojv_feature' then
      M.apply_archive_item_profile_to_spec(profile, spec)
    end
  end
end

function M.persist_archive_shop_specs_to_profile()
  local profile = M.load_profile()
  M.ensure_archive_items_profile_defaults(profile)
  for _, spec in ipairs(OUTGAME_DEFS.archive_shop_item_specs or {}) do
    if spec.source == 'csv_shangchengdaojv_feature' then
      local key = spec.archive_profile_key or require('ui.outgame.utils').archive_item_profile_key(spec)
      if key ~= '' and key ~= '||' then
        local entry = profile.archive_items[key]
        if type(entry) ~= 'table' then
          entry = {}
          profile.archive_items[key] = entry
        end
        entry.owned_text = tostring(spec.owned_text or '')
        entry.runtime_level = require('ui.outgame.utils').to_archive_integer(spec.runtime_level)
        entry.runtime_reroll_count = require('ui.outgame.utils').to_archive_integer(spec.runtime_reroll_count)
        entry.runtime_equipped = spec.runtime_equipped == true
        entry.runtime_random_bonus = spec.runtime_random_bonus
      end
    end
  end
  M.mark_profile_dirty()
end

function M.ensure_profile_defaults(profile)
  local dirty = false
  if type(profile.version) ~= 'number' then
    profile.version = 1
    dirty = true
  end
  if type(profile.stage_progress) ~= 'table' then
    profile.stage_progress = {}
    dirty = true
  end
  if type(profile.last_result) ~= 'table' then
    profile.last_result = {}
    dirty = true
  end
  if type(profile.hero_attr_bonus_stats) ~= 'table' then
    profile.hero_attr_bonus_stats = {}
    dirty = true
  end
  if M.ensure_archive_items_profile_defaults(profile) then
    dirty = true
  end
  if profile.selected_view_mode ~= VIEW_MODE_MAINLINE and profile.selected_view_mode ~= VIEW_MODE_CULTIVATION then
    profile.selected_view_mode = VIEW_MODE_MAINLINE
    dirty = true
  end
  if M.rebuild_hero_attr_bonus_stats(profile) then
    dirty = true
  end
  local last_result = profile.last_result
  if last_result.is_win == nil then
    last_result.is_win = false
    dirty = true
  end
  if math.type(last_result.reached_wave_index) ~= 'integer' then
    last_result.reached_wave_index = 0
    dirty = true
  end
  if M.normalize_loaded_selection(profile) then
    dirty = true
  end
  return dirty
end

function M.load_profile()
  if STATE.outgame_profile then
    return STATE.outgame_profile
  end

  local profile
  local ok, result = pcall(function()
    return y3.save_data.load_table(y3.player.get_main_player(), SAVE_SLOT, true)
  end)

  if ok and type(result) == 'table' then
    profile = result
    M.set_save_backend_state(true)
  else
    profile = {}
    M.set_save_backend_state(false, result)
  end

  local defaults_ok, defaults_dirty_or_err = pcall(M.ensure_profile_defaults, profile)
  if not defaults_ok then
    profile = {}
    STATE.outgame_profile = profile
    M.set_save_backend_state(false, defaults_dirty_or_err)
    M.ensure_profile_defaults(profile)
    return profile
  end

  STATE.outgame_profile = profile
  if defaults_dirty_or_err then
    M.mark_profile_dirty()
  end

  return profile
end

function M.apply_battle_result(result)
  if not result then
    return nil
  end

  local profile = M.load_profile()

  profile.last_result.is_win = result.is_win == true
  profile.last_result.reached_wave_index = math.max(0, result.reached_wave_index or 0)

  M.rebuild_hero_attr_bonus_stats(profile)
  M.mark_profile_dirty()
  return nil
end

return M