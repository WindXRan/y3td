local M = {}

local STATE
local message
local play_ui_click
local OUTGAME_TOP_ENTRY_LIST
local VIEW_MODE_MAINLINE = 'mainline'
local utils

function M.init(env)
  STATE = env.STATE
  message = env.message
  play_ui_click = env.play_ui_click
  OUTGAME_TOP_ENTRY_LIST = env.OUTGAME_TOP_ENTRY_LIST or {}
  utils = require('ui.outgame.utils')
  utils.init(env)
end

local function resolve_top_entry_button(index)
  local idx = tonumber(index) or 0
  if idx <= 0 then
    return nil
  end
  local candidates = {}
  if idx == 1 then
    candidates = { 'button' }
  elseif idx == 7 then
    candidates = { 'button_7', 'button_6' }
  else
    candidates = { string.format('button_%d', idx - 1) }
  end
  local paths = {}
  for _, name in ipairs(candidates) do
    paths[#paths + 1] = 'top.list.' .. name
    paths[#paths + 1] = 'top.top.list.' .. name
  end
  return utils.resolve_ui_first(paths)
end

local function resolve_top_entry_label(index)
  local idx = tonumber(index) or 0
  if idx <= 0 then
    return nil
  end
  local candidates = {}
  if idx == 1 then
    candidates = { 'button' }
  elseif idx == 7 then
    candidates = { 'button_7', 'button_6' }
  else
    candidates = { string.format('button_%d', idx - 1) }
  end
  local paths = {}
  for _, name in ipairs(candidates) do
    paths[#paths + 1] = 'top.list.' .. name .. '.label'
    paths[#paths + 1] = 'top.top.list.' .. name .. '.label'
  end
  return utils.resolve_ui_first(paths)
end

function M.dispatch_top_entry_action(entry, set_selected_view_mode_func, open_save_panel_func, start_selected_stage_func, refresh_ui_func)
  if type(entry) ~= 'table' then
    return
  end
  local action = tostring(entry.action or '')
  local function open_archive_with(section, show_ranking)
    if set_selected_view_mode_func then
      set_selected_view_mode_func(VIEW_MODE_MAINLINE)
    end
    STATE.archive_panel_section = section
    STATE.archive_ranking_visible = show_ranking == true
    if STATE.archive_ranking_visible == true and (not STATE.archive_ranking_tab or STATE.archive_ranking_tab <= 0) then
      STATE.archive_ranking_tab = 1
    end
    if not open_save_panel_func or not open_save_panel_func() then
      return
    end
  end
  if action == 'open_archive' then
    STATE.archive_panel_section = 'archive'
    STATE.archive_ranking_visible = false
    if open_save_panel_func then
      open_save_panel_func()
    end
    return
  end
  if action == 'open_archive_career' then
    open_archive_with('career', false)
    return
  end
  if action == 'open_archive_shop' then
    open_archive_with('shop', false)
    return
  end
  if action == 'open_archive_ranking' then
    open_archive_with('ranking', true)
    return
  end
  if action == 'start_stage' then
    if start_selected_stage_func then
      start_selected_stage_func()
    end
    return
  end
  if action == 'switch_cultivation' then
    if set_selected_view_mode_func and set_selected_view_mode_func(VIEW_MODE_MAINLINE ~= 'mainline' and VIEW_MODE_MAINLINE or 'cultivation') then
      if refresh_ui_func then
        refresh_ui_func()
      end
    end
    return
  end
  if action == 'open_battlepass' then
    open_archive_with('battlepass', false)
    return
  end
  if action == 'show_hero_growth_tip' then
    message('英雄养成入口已迁移到"如何变强 / H"。')
    return
  end
  if action == 'refresh' then
    if refresh_ui_func then
      refresh_ui_func()
    end
    return
  end
end

function M.get_top_entry_title_by_action(action, fallback_title)
  local target_action = tostring(action or '')
  if target_action ~= '' then
    for _, entry in ipairs(OUTGAME_TOP_ENTRY_LIST) do
      if tostring(entry.action or '') == target_action then
        local title = tostring(entry.title or '')
        if title ~= '' then
          return title
        end
        local label = tostring(entry.label or '')
        if label ~= '' then
          return label
        end
        break
      end
    end
  end
  return tostring(fallback_title or '')
end

function M.ensure_top_entry_list_ui(ui)
  if not ui then
    message('[top_entry] ui is nil, cannot ensure top entry list')
    return nil
  end
  ui.top_entry_list_root = ui.top_entry_list_root or utils.resolve_ui_first({ 'top.list', 'top.top.list' })
  if not utils.is_ui_alive(ui.top_entry_list_root) then
    message('[top_entry] top_entry_list_root is not alive, trying fallback')
  end
  if (not utils.is_ui_alive(ui.top_entry_list_root)) and (ui.top_entry_fallback_root == nil) then
    local host = utils.resolve_ui_first({ 'top.top', 'top' })
    if utils.is_ui_alive(host) and host.create_child then
      local root = host:create_child('布局')
      if utils.is_ui_alive(root) then
        if root.set_ui_size then
          root:set_ui_size(820, 48)
        end
        if root.set_pos then
          root:set_pos(370, 1035)
        end
        ui.top_entry_fallback_root = root
        ui.top_entry_list_root = root
      end
    end
  end
  ui.top_entry_items = ui.top_entry_items or {}
  for _, entry in ipairs(OUTGAME_TOP_ENTRY_LIST) do
    local slot = tonumber(entry.slot) or 0
    if slot > 0 then
      ui.top_entry_items[slot] = ui.top_entry_items[slot] or {}
      ui.top_entry_items[slot].entry = entry
      ui.top_entry_items[slot].button = ui.top_entry_items[slot].button or resolve_top_entry_button(slot)
      ui.top_entry_items[slot].label = ui.top_entry_items[slot].label or resolve_top_entry_label(slot)
      if (not utils.is_ui_alive(ui.top_entry_items[slot].button)) and utils.is_ui_alive(ui.top_entry_fallback_root) and ui.top_entry_fallback_root.create_child then
        local btn = ui.top_entry_fallback_root:create_child('按钮')
        if utils.is_ui_alive(btn) then
          if btn.set_ui_size then
            btn:set_ui_size(104, 40)
          end
          if btn.set_pos then
            btn:set_pos(56 + (slot - 1) * 112, 24)
          end
          if btn.set_text then
            btn:set_text(tostring(entry.label or entry.title or entry.id or '入口'))
          end
          ui.top_entry_items[slot].button = btn
          ui.top_entry_items[slot].label = btn
        end
      end
    end
  end
  return ui.top_entry_items
end

function M.refresh_top_entry_list_ui(ui)
  local items = M.ensure_top_entry_list_ui(ui)
  if not items then
    return
  end
  local in_outgame = STATE.session_phase == 'outgame'
  local in_battle = STATE.session_phase == 'battle'
  local should_show = in_outgame or in_battle
  utils.set_visible_if_alive(ui.top_entry_list_root, should_show)
  for _, slot_ui in pairs(items) do
    local entry = slot_ui.entry
    local visible = false
    if in_outgame then
      visible = entry.visible_in_outgame ~= false
    elseif in_battle then
      visible = entry.visible_in_battle ~= false
    end
    utils.set_visible_if_alive(slot_ui.button, visible)
    utils.set_text_if_alive(slot_ui.label, entry.label or '')
  end
end

function M.bind_top_entry_list(ui, dispatch_action_func)
  local items = M.ensure_top_entry_list_ui(ui)
  if not items then
    message('[top_entry] bind_top_entry_list: items is nil')
    return
  end
  local bound_count = 0
  local missing_count = 0
  for _, slot_ui in pairs(items) do
    local button = slot_ui.button
    if utils.is_ui_alive(button) then
      if slot_ui.bound ~= true then
        slot_ui.bound = true
        button:add_fast_event('左键-按下', function()
          if play_ui_click then
            play_ui_click()
          end
          if dispatch_action_func then
            dispatch_action_func(slot_ui.entry or {})
          else
            M.dispatch_top_entry_action(slot_ui.entry or {})
          end
        end)
        bound_count = bound_count + 1
      end
    else
      missing_count = missing_count + 1
    end
  end
  message(string.format('[top_entry] bind_top_entry_list: bound %d buttons, missing %d buttons', bound_count, missing_count))
end

return M