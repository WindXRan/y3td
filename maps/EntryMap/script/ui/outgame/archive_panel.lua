local M = {}

local STATE
local CONFIG
local y3
local message
local play_ui_click
local OUTGAME_DEFS
local ARCHIVE_SHOP_OPTIONS
local ArchiveShop
local ArchiveTabDefinitions
local RANKING_TABS
local utils

local ARCHIVE_PANEL_Z_ORDER = 9800

function M.init(env)
  STATE = env.STATE
  CONFIG = env.CONFIG
  y3 = env.y3
  message = env.message
  play_ui_click = env.play_ui_click
  OUTGAME_DEFS = env.OUTGAME_DEFS
  ArchiveShop = env.ArchiveShop
  ArchiveTabDefinitions = env.ArchiveTabDefinitions
  RANKING_TABS = env.RANKING_TABS or {}
  utils = require('ui.outgame.utils')
  utils.init(env)

  local group_templates = {}
  for _, name in ipairs(ArchiveTabDefinitions.get_valid_primary_tabs()) do
    local cfg = ArchiveTabDefinitions.get_tab_render_config(name)
    local flags = cfg.flags or {}
    group_templates[name] = {
      icon = flags.icon or false,
      lv = flags.lv or false,
      num = flags.num or false,
      suit = flags.suit or false,
      map_level = flags.map_level or false,
      honor = flags.honor or false,
      show_equip_count = flags.equip_count or false,
      show_progress = flags.progress or false,
      show_points = flags.points or false,
      label = cfg.label_mode,
    }
  end

  local DEFAULT_PRIMARY = ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品'

  ARCHIVE_SHOP_OPTIONS = {
    state = STATE,
    player = env.get_player and env.get_player() or nil,
    specs = OUTGAME_DEFS.archive_shop_item_specs or {},
    primary_tabs = OUTGAME_DEFS.archive_shop_primary_tabs or { OUTGAME_DEFS.archive_shop_primary_tab or DEFAULT_PRIMARY },
    primary_tab_label = OUTGAME_DEFS.archive_shop_primary_tab or DEFAULT_PRIMARY,
    categories = OUTGAME_DEFS.archive_shop_categories or {},
    all_category_label = '全部',
    categories_by_primary = OUTGAME_DEFS.archive_shop_categories_by_primary or {},
    group_templates = group_templates,
    default_icon = OUTGAME_DEFS.archive_shop_default_icon or 906565,
    play_ui_click = play_ui_click,
    message = message,
    persist_archive_items_state = env.persist_archive_items_state,
  }
end

local function ensure_archive_panel_on_top(ui)
  if not ui then
    return
  end
  utils.set_z_order_if_alive(ui.root, ARCHIVE_PANEL_Z_ORDER)
  utils.set_z_order_if_alive(ui.overlay, ARCHIVE_PANEL_Z_ORDER + 1)
  utils.set_z_order_if_alive(ui.window, ARCHIVE_PANEL_Z_ORDER + 1)
  utils.set_z_order_if_alive(ui.layout, ARCHIVE_PANEL_Z_ORDER + 2)
  utils.set_z_order_if_alive(ui.layout_bg, ARCHIVE_PANEL_Z_ORDER + 2)
  utils.set_z_order_if_alive(ui.panel_main, ARCHIVE_PANEL_Z_ORDER + 3)
  utils.set_z_order_if_alive(ui.panel_ranking, ARCHIVE_PANEL_Z_ORDER + 3)
  utils.set_z_order_if_alive(ui.panel_idle, ARCHIVE_PANEL_Z_ORDER + 3)
  utils.set_z_order_if_alive(ui.panel_start, ARCHIVE_PANEL_Z_ORDER + 3)
  utils.set_z_order_if_alive(ui.panel_battlepass, ARCHIVE_PANEL_Z_ORDER + 3)
  utils.set_z_order_if_alive(ui.layout_title, ARCHIVE_PANEL_Z_ORDER + 4)
  utils.set_z_order_if_alive(ui.layout_exit, ARCHIVE_PANEL_Z_ORDER + 4)
end

local function get_ranking_rows_for_tab(tab)
  local rows = {}
  local local_player = env.get_player and env.get_player() or nil
  local local_name = '玩家'
  if local_player and local_player.get_name then
    local ok_name, name = pcall(function()
      return local_player:get_name()
    end)
    if ok_name and type(name) == 'string' and name ~= '' then
      local_name = name
    end
  end
  local map_rank = (local_player and local_player.get_map_level_rank and local_player:get_map_level_rank()) or 0
  local kill_count = tonumber(STATE.total_kills or 0) or 0
  local score = 0
  if tab == 1 then
    score = math.max(0, 100000 - map_rank * 100 + kill_count * 10)
  elseif tab == 2 then
    score = kill_count
  else
    score = math.floor(kill_count * 0.65)
  end
  rows[#rows + 1] = { name = local_name, score = score }

  local group = y3 and y3.player_group and y3.player_group.get_all_players and y3.player_group.get_all_players() or nil
  if group and group.pairs then
    for p in group:pairs() do
      if p and p ~= local_player then
        local pname = (p.get_name and p:get_name()) or '玩家'
        local prank = (p.get_map_level_rank and p:get_map_level_rank()) or 0
        local pscore = (tab == 1) and math.max(0, 100000 - prank * 100) or 0
        rows[#rows + 1] = { name = pname, score = pscore }
      end
    end
  end

  table.sort(rows, function(a, b)
    if (a.score or 0) ~= (b.score or 0) then
      return (a.score or 0) > (b.score or 0)
    end
    return tostring(a.name or '') < tostring(b.name or '')
  end)
  return rows
end

local function get_ranking_tab_index()
  local tab = tonumber(STATE.archive_ranking_tab or 1) or 1
  if tab < 1 then
    tab = 1
  end
  if #RANKING_TABS > 0 and tab > #RANKING_TABS then
    tab = #RANKING_TABS
  end
  return tab
end

function M.refresh_archive_ranking_ui(ui)
  if not ui then
    return
  end
  local tab = get_ranking_tab_index()
  local active_tab = RANKING_TABS[tab] or { tab = 1, title = '排行榜', list_node = '排行榜列表_1' }

  local tab_paths = {
    'ArchiveMain.排行榜.page_grid.ArchivePageOne',
    'ArchiveMain.排行榜.page_grid.ArchivePageOne_1',
    'ArchiveMain.排行榜.page_grid.ArchivePageOne_2',
    'ArchiveMain.排行榜.page_grid.ArchivePageOne_3',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne_1',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne_2',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne_3',
  }
  for i, path in ipairs(tab_paths) do
    local root = utils.resolve_ui(path)
    if utils.is_ui_alive(root) then
      local idx = ((i - 1) % 4) + 1
      local def = RANKING_TABS[idx]
      local visible = def ~= nil and def.enabled ~= false
      utils.set_visible_if_alive(root, visible)
      if visible then
        local label = utils.resolve_ui(path .. '.label')
        local bg = utils.resolve_ui(path .. '.button') or root
        utils.set_text_if_alive(label, tostring(def.title or '排行榜'))
        local selected = def.tab == active_tab.tab
        utils.set_image_color_if_alive(bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
        utils.set_text_color_if_alive(label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
      end
    end
  end

  for _, def in ipairs(RANKING_TABS) do
    local list_root = utils.resolve_ui_first({
      'ArchiveMain.排行榜.排行.' .. tostring(def.list_node or ''),
      'ArchivePanel.排行榜.排行.' .. tostring(def.list_node or ''),
    })
    if utils.is_ui_alive(list_root) then
      local is_active = def.tab == active_tab.tab
      utils.set_visible_if_alive(list_root, is_active)
      if is_active then
        local rows = get_ranking_rows_for_tab(tab)
        local function resolve_ranking_row_path(list_node, row_index)
          local candidates = {}
          if row_index == 1 then
            candidates[#candidates + 1] = 'bg'
          else
            candidates[#candidates + 1] = 'bg_' .. tostring(row_index - 1)
          end
          candidates[#candidates + 1] = 'bg_' .. tostring(row_index + 6)
          for _, row_name in ipairs(candidates) do
            local row_root = utils.resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name,
              'ArchivePanel.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name,
            })
            local name_label = utils.resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_1',
              'ArchivePanel.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_1',
            })
            local score_label = utils.resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_2',
              'ArchivePanel.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_2',
            })
            if utils.is_ui_alive(row_root) and (utils.is_ui_alive(name_label) or utils.is_ui_alive(score_label)) then
              return row_name
            end
          end
          return candidates[1]
        end

        for idx = 1, 5 do
          local row_name = resolve_ranking_row_path(def.list_node, idx)
          local row_root = utils.resolve_ui_first({
            'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name,
            'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name,
          })
          local rank_label = utils.resolve_ui_first({
            'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.num',
            'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.num',
          })
          local name_label = utils.resolve_ui_first({
            'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_1',
            'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_1',
          })
          local score_label = utils.resolve_ui_first({
            'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_2',
            'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_2',
          })

          local row = rows[idx]
          utils.set_visible_if_alive(row_root, row ~= nil)
          if row then
            utils.set_text_if_alive(rank_label, tostring(idx))
            utils.set_text_if_alive(name_label, tostring(row.name or '玩家'))
            utils.set_text_if_alive(score_label, tostring(tonumber(row.score or 0) or 0))
          end
        end
      end
    end
  end
end

local function is_archive_panel_ui_alive(ui)
  return ui
    and utils.is_ui_alive(ui.root)
    and utils.is_ui_alive(ui.overlay)
    and utils.is_ui_alive(ui.window)
end

local function resolve_archive_chip(path, bg_name)
  bg_name = bg_name or 'bg'
  local root = utils.resolve_ui(path)
  if not utils.is_ui_alive(root) then
    return nil
  end
  return {
    root = root,
    bg = utils.resolve_ui(path .. '.' .. bg_name) or root,
    label = utils.resolve_ui(path .. '.label'),
    active = utils.resolve_ui(path .. '.active'),
  }
end

local function refresh_archive_main_shop_items(ui)
  ARCHIVE_SHOP_OPTIONS.player = env.get_player and env.get_player() or ARCHIVE_SHOP_OPTIONS.player
  return ArchiveShop.refresh(ui, ARCHIVE_SHOP_OPTIONS)
end

local function ensure_archive_main_shop_ui(ui)
  ARCHIVE_SHOP_OPTIONS.player = env.get_player and env.get_player() or ARCHIVE_SHOP_OPTIONS.player
  return ArchiveShop.ensure(ui, ARCHIVE_SHOP_OPTIONS)
end

local function get_archive_chip_click_target(chip)
  if chip and utils.is_ui_alive(chip.bg) then
    return chip.bg
  end
  if chip and utils.is_ui_alive(chip.root) then
    return chip.root
  end
  return nil
end

local bind_archive_panel_events
local refresh_archive_enter_panel_visible

local function ensure_archive_panel_ui()
  if is_archive_panel_ui_alive(STATE.archive_panel_ui) then
    ensure_archive_main_shop_ui(STATE.archive_panel_ui)
    bind_archive_panel_events(STATE.archive_panel_ui)
    refresh_archive_enter_panel_visible(STATE.archive_panel_ui)
    return STATE.archive_panel_ui
  end

  local archive_main_root = utils.resolve_ui_first({ 'ArchiveMain', 'ArchivePanel' })
  local archive_main_overlay = utils.resolve_ui_first({ 'ArchiveMain.layout_1', 'ArchiveMain.layout', 'ArchivePanel.layout_1', 'ArchivePanel.layout' })
  local archive_main_close = utils.resolve_ui_first({
    'ArchiveMain.layout_1.exit',
    'ArchiveMain.layout.exit',
    'ArchiveMain.layout.close',
    'ArchivePanel.layout_1.exit',
    'ArchivePanel.layout.exit',
  })
  if utils.is_ui_alive(archive_main_root) and utils.is_ui_alive(archive_main_overlay) then
    local ui = {
      variant = 'archive_main_v2',
      root = archive_main_root,
      layout = utils.resolve_ui_first({ 'ArchiveMain.layout', 'ArchivePanel.layout' }),
      layout_bg = utils.resolve_ui_first({ 'ArchiveMain.layout.bg', 'ArchivePanel.layout.bg' }),
      layout_title = utils.resolve_ui_first({ 'ArchiveMain.layout.title', 'ArchivePanel.layout.title' }),
      layout_exit = utils.resolve_ui_first({ 'ArchiveMain.layout.exit', 'ArchivePanel.layout.exit' }),
      overlay = archive_main_overlay,
      window = archive_main_overlay,
      panel_main = utils.resolve_ui_first({ 'ArchiveMain.存档生涯商城', 'ArchivePanel.存档生涯商城' }),
      panel_content_list = utils.resolve_ui_first({ 'ArchiveMain.内容列表', 'ArchivePanel.内容列表' }),
      panel_main_page_grid = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.page_grid',
        'ArchivePanel.存档生涯商城.page_grid',
      }),
      panel_main_page2_grid = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.page2_grid',
        'ArchivePanel.存档生涯商城.page2_grid',
      }),
      panel_main_content_root = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.中间内容',
        'ArchivePanel.存档生涯商城.中间内容',
      }),
      panel_main_detail = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.文本详情',
        'ArchiveMain.存档生涯商城.scroll_view',
        'ArchivePanel.存档生涯商城.文本详情',
        'ArchivePanel.存档生涯商城.scroll_view',
      }),
      panel_main_content_archive = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.中间内容.存档',
        'ArchivePanel.存档生涯商城.中间内容.存档',
      }),
      panel_main_content_shop = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.中间内容.商城',
        'ArchivePanel.存档生涯商城.中间内容.商城',
      }),
      panel_main_content_career = utils.resolve_ui_first({
        'ArchiveMain.存档生涯商城.中间内容.生涯',
        'ArchivePanel.存档生涯商城.中间内容.生涯',
      }),
      panel_ranking = utils.resolve_ui_first({ 'ArchiveMain.排行榜', 'ArchivePanel.排行榜' }),
      panel_ranking_page_grid = utils.resolve_ui_first({ 'ArchiveMain.排行榜.page_grid', 'ArchivePanel.排行榜.page_grid' }),
      panel_ranking_list = utils.resolve_ui_first({ 'ArchiveMain.排行榜.排行榜列表', 'ArchivePanel.排行榜.排行榜列表' }),
      panel_ranking_scroll = utils.resolve_ui_first({ 'ArchiveMain.排行榜.排行', 'ArchivePanel.排行榜.排行' }),
      panel_idle = utils.resolve_ui_first({ 'ArchiveMain.挂机', 'ArchivePanel.挂机' }),
      panel_idle_page_grid = utils.resolve_ui_first({ 'ArchiveMain.挂机.page_grid', 'ArchivePanel.挂机.page_grid' }),
      panel_idle_list = utils.resolve_ui_first({ 'ArchiveMain.挂机.排行榜列表', 'ArchivePanel.挂机.排行榜列表' }),
      panel_idle_scroll = utils.resolve_ui_first({ 'ArchiveMain.挂机.排行', 'ArchivePanel.挂机.排行' }),
      panel_start = utils.resolve_ui_first({ 'ArchiveMain.开始', 'ArchivePanel.开始' }),
      panel_battlepass = utils.resolve_ui_first({ 'ArchiveMain.战令', 'ArchivePanel.战令' }),
      close_button = archive_main_close,
      close_chip = {
        root = archive_main_close,
        bg = archive_main_close,
      },
      enter_panel_root = utils.resolve_ui_first({ 'EnterPanel', 'ArchiveMain.EnterPanel' }),
      enter_panel_icon = utils.resolve_ui_first({ 'EnterPanel.YangChengIcon', 'ArchiveMain.EnterPanel.YangChengIcon' }),
      enter_panel_bg = utils.resolve_ui_first({ 'EnterPanel.YangChengIcon.bg', 'ArchiveMain.EnterPanel.YangChengIcon.bg' }),
      enter_panel_name = utils.resolve_ui_first({ 'EnterPanel.YangChengIcon.name', 'ArchiveMain.EnterPanel.YangChengIcon.name' }),
      enter_panel_bound = false,
      bound = false,
    }
    STATE.archive_panel_ui = ui
    ensure_archive_panel_on_top(ui)
    ensure_archive_main_shop_ui(ui)
    bind_archive_panel_events(ui)
    refresh_archive_enter_panel_visible(ui)
    return ui
  end

  if not STATE.archive_panel_ui_warned then
    STATE.archive_panel_ui_warned = true
    message('未找到 ArchiveMain 节点，请先热更新版存档 UI 后再测试。')
  end
  return nil
end

refresh_archive_enter_panel_visible = function(ui)
  if not is_archive_panel_ui_alive(ui) then
    return
  end
  local visible = false
  utils.set_visible_if_alive(ui.enter_panel_root, visible)
  utils.set_visible_if_alive(ui.enter_panel_icon, visible)
  utils.set_visible_if_alive(ui.enter_panel_bg, visible)
  utils.set_visible_if_alive(ui.enter_panel_name, visible)
end

function M.set_archive_panel_visible(visible)
  visible = visible == true
  local ui = STATE.archive_panel_ui
  if not visible and not is_archive_panel_ui_alive(ui) then
    STATE.archive_panel_visible = false
    STATE.archive_panel_hidden_non_outgame = false
    return true
  end
  if visible or not is_archive_panel_ui_alive(ui) then
    ui = ensure_archive_panel_ui()
  end
  if visible then
    if not is_archive_panel_ui_alive(ui) then
      return false
    end
    if STATE.archive_panel_hidden_non_outgame ~= true then
      M.set_non_outgame_ui_visible(false)
      STATE.archive_panel_hidden_non_outgame = true
    end
    utils.set_visible_if_alive(ui.root, true)
    utils.set_visible_if_alive(ui.layout, true)
    utils.set_visible_if_alive(ui.layout_bg, true)
    utils.set_visible_if_alive(ui.layout_title, true)
    utils.set_visible_if_alive(ui.layout_exit, true)
    utils.set_visible_if_alive(ui.overlay, true)
    utils.set_visible_if_alive(ui.window, true)
    ensure_archive_panel_on_top(ui)
    STATE.archive_panel_visible = true
    if M.refresh_archive_panel_ui then
      M.refresh_archive_panel_ui(require('ui.outgame.profile').load_profile())
    end
    refresh_archive_enter_panel_visible(ui)
    return true
  end

  if STATE.archive_panel_hidden_non_outgame == true then
    M.set_non_outgame_ui_visible(STATE.session_phase ~= 'outgame')
    STATE.archive_panel_hidden_non_outgame = false
  end
  if is_archive_panel_ui_alive(ui) then
    utils.set_visible_if_alive(ui.root, false)
    utils.set_visible_if_alive(ui.layout, false)
    utils.set_visible_if_alive(ui.layout_bg, false)
    utils.set_visible_if_alive(ui.layout_title, false)
    utils.set_visible_if_alive(ui.layout_exit, false)
    utils.set_visible_if_alive(ui.overlay, false)
    utils.set_visible_if_alive(ui.window, false)
  end
  STATE.archive_panel_visible = false
  refresh_archive_enter_panel_visible(ui)
  return true
end

bind_archive_panel_events = function(ui)
  if not is_archive_panel_ui_alive(ui) or ui.bound == true then
    return
  end
  ui.bound = true

  if ui.enter_panel_bound ~= true then
    local enter_panel_target = ui.enter_panel_bg
      or ui.enter_panel_icon
      or ui.enter_panel_name
      or ui.enter_panel_root
    if utils.is_ui_alive(enter_panel_target) then
      ui.enter_panel_bound = true
      utils.set_intercepts_if_alive(enter_panel_target, true)
      enter_panel_target:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        M.open_save_panel()
      end)
    end
  end

  if utils.is_ui_alive(ui.dim) then
    ui.dim:add_fast_event('左键-按下', function()
      if STATE.archive_panel_visible ~= true then
        return
      end
      if play_ui_click then
        play_ui_click()
      end
      M.set_archive_panel_visible(false)
    end)
  end

  local close_button_target = get_archive_chip_click_target(ui.close_chip)
    or (utils.is_ui_alive(ui.close_button) and ui.close_button or nil)
  if utils.is_ui_alive(close_button_target) then
    close_button_target:add_fast_event('左键-按下', function()
      if STATE.archive_panel_visible ~= true then
        return
      end
      if play_ui_click then
        play_ui_click()
      end
      M.set_archive_panel_visible(false)
    end)
  end

  local ranking_tab_paths = {
    'ArchiveMain.排行榜.page_grid.ArchivePageOne',
    'ArchiveMain.排行榜.page_grid.ArchivePageOne_1',
    'ArchiveMain.排行榜.page_grid.ArchivePageOne_2',
    'ArchiveMain.排行榜.page_grid.ArchivePageOne_3',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne_1',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne_2',
    'ArchivePanel.排行榜.page_grid.ArchivePageOne_3',
  }
  for index, path in ipairs(ranking_tab_paths) do
    local root = utils.resolve_ui(path)
    local button = utils.resolve_ui(path .. '.button') or root
    if utils.is_ui_alive(button) then
      local tab_index = ((index - 1) % 4) + 1
      utils.set_intercepts_if_alive(button, true)
      button:add_fast_event('左键-按下', function()
        if tostring(STATE.archive_panel_section or '') ~= 'ranking' then
          return
        end
        if tonumber(STATE.archive_ranking_tab or 1) == tab_index then
          return
        end
        if play_ui_click then
          play_ui_click()
        end
        STATE.archive_ranking_tab = tab_index
        M.refresh_archive_ranking_ui(ui)
      end)
    end
  end
end

function M.refresh_archive_panel_ui(profile)
  local ui = ensure_archive_panel_ui()
  if not is_archive_panel_ui_alive(ui) then
    return false
  end
  ensure_archive_panel_on_top(ui)
  local section = tostring(STATE.archive_panel_section or '')
  if STATE.archive_ranking_visible == true then
    section = 'ranking'
  elseif section == '' then
    section = 'archive'
  end
  if section == 'battlepass' and not utils.is_ui_alive(ui.panel_battlepass) then
    section = 'career'
  end
  local show_main = section == 'main' or section == 'career' or section == 'shop' or section == 'archive'
  local show_ranking = section == 'ranking'
  local show_idle = section == 'idle'
  local show_start = section == 'start'
  local show_battlepass = section == 'battlepass'
  local has_active_panel = show_main or show_ranking or show_idle or show_start or show_battlepass
  utils.set_visible_if_alive(ui.root, STATE.archive_panel_visible == true)
  utils.set_visible_if_alive(ui.layout, STATE.archive_panel_visible == true and has_active_panel)
  utils.set_visible_if_alive(ui.layout_bg, STATE.archive_panel_visible == true and has_active_panel)
  utils.set_visible_if_alive(ui.layout_title, STATE.archive_panel_visible == true and has_active_panel)
  utils.set_visible_if_alive(ui.layout_exit, STATE.archive_panel_visible == true and has_active_panel)
  utils.set_visible_if_alive(ui.overlay, STATE.archive_panel_visible == true and has_active_panel)
  utils.set_visible_if_alive(ui.window, STATE.archive_panel_visible == true and has_active_panel)
  utils.set_visible_if_alive(ui.panel_main, STATE.archive_panel_visible == true and show_main)
  utils.set_visible_if_alive(ui.panel_content_list, STATE.archive_panel_visible == true and show_main)
  utils.set_visible_if_alive(ui.panel_ranking, STATE.archive_panel_visible == true and show_ranking)
  utils.set_visible_if_alive(ui.panel_idle, STATE.archive_panel_visible == true and show_idle)
  utils.set_visible_if_alive(ui.panel_start, STATE.archive_panel_visible == true and show_start)
  utils.set_visible_if_alive(ui.panel_battlepass, STATE.archive_panel_visible == true and show_battlepass)
  local show_main_content = STATE.archive_panel_visible == true and show_main
  local show_archive_content = show_main_content and (section == 'archive')
  local show_shop_content = show_main_content and (section == 'shop')
  local show_career_content = show_main_content and (section == 'career' or section == 'main')
  utils.set_visible_if_alive(ui.panel_main_content_root, show_main_content)
  utils.set_visible_if_alive(ui.panel_main_content_archive, show_archive_content)
  utils.set_visible_if_alive(ui.panel_main_content_shop, show_shop_content)
  utils.set_visible_if_alive(ui.panel_main_content_career, show_career_content)
  utils.set_visible_if_alive(ui.panel_main_page_grid, show_main_content)
  utils.set_visible_if_alive(ui.panel_main_page2_grid, show_main_content)
  utils.set_visible_if_alive(ui.panel_main_detail, show_main_content)
  utils.set_visible_if_alive(ui.panel_ranking_page_grid, STATE.archive_panel_visible == true and show_ranking)
  utils.set_visible_if_alive(ui.panel_ranking_list, STATE.archive_panel_visible == true and show_ranking)
  utils.set_visible_if_alive(ui.panel_ranking_scroll, STATE.archive_panel_visible == true and show_ranking)
  utils.set_visible_if_alive(ui.panel_idle_page_grid, STATE.archive_panel_visible == true and show_idle)
  utils.set_visible_if_alive(ui.panel_idle_list, STATE.archive_panel_visible == true and show_idle)
  utils.set_visible_if_alive(ui.panel_idle_scroll, STATE.archive_panel_visible == true and show_idle)
  if STATE.archive_panel_visible == true and show_ranking then
    M.refresh_archive_ranking_ui(ui)
  end
  utils.set_text_if_alive(ui.layout_title, M.resolve_outgame_top_title(profile))
  ensure_archive_main_shop_ui(ui)
  refresh_archive_main_shop_items(ui)
  refresh_archive_enter_panel_visible(ui)
  return true
end

function M.open_save_panel(load_profile_func, refresh_ui_func)
  local profile = load_profile_func and load_profile_func() or require('ui.outgame.profile').load_profile()
  STATE.archive_panel_section = 'archive'
  STATE.archive_ranking_visible = false
  if STATE.archive_panel_visible == true then
    if M.refresh_archive_panel_ui then
      M.refresh_archive_panel_ui(profile)
    end
    return true
  end
  if not M.set_archive_panel_visible(true) then
    message(require('ui.outgame.profile').build_save_status_detail(profile))
    return false
  end
  if M.refresh_archive_panel_ui then
    M.refresh_archive_panel_ui(profile)
  end
  return true
end

function M.set_non_outgame_ui_visible(visible)
  local base_paths = {
    'GameHUD',
    'top',
    'bottom_bg',
    'BattleBottomHUD',
  }
  local overlay_paths = {
    'Choice_Panel',
    'BattleDetailTipsPanel',
    'panel_1',
    'CommonTip',
    'SceneUI',
  }
  for _, path in ipairs(base_paths) do
    local ui = utils.resolve_ui(path)
    utils.set_visible_if_alive(ui, visible == true)
  end

  for _, path in ipairs(overlay_paths) do
    local ui = utils.resolve_ui(path)
    utils.set_visible_if_alive(ui, false)
  end

  if STATE.gm_ui then
    utils.set_visible_if_alive(STATE.gm_ui.toggle_button, visible == true)
    utils.set_visible_if_alive(STATE.gm_ui.panel, visible == true and STATE.gm_ui.visible == true)
  end
end

function M.resolve_outgame_top_title(profile, VIEW_MODE_MAINLINE, VIEW_MODE_CULTIVATION, OUTGAME_TOP_ENTRY_LIST, get_selected_view_mode)
  if STATE.archive_panel_visible == true then
    if STATE.archive_ranking_visible == true then
      return M.get_top_entry_title_by_action('open_archive_ranking', '排行榜')
    end
    local section = tostring(STATE.archive_panel_section or '')
    local partitions = ArchiveTabDefinitions.get_valid_partitions()
    if section == 'career' then
      return M.get_top_entry_title_by_action('open_archive_career', partitions[3] or '生涯')
    end
    if section == 'shop' then
      return M.get_top_entry_title_by_action('open_archive_shop', partitions[1] or '商城')
    end
    return M.get_top_entry_title_by_action('open_archive', partitions[2] or '存档')
  end
  local selected_view_mode = get_selected_view_mode and get_selected_view_mode(profile) or (profile and profile.selected_view_mode == VIEW_MODE_CULTIVATION and VIEW_MODE_CULTIVATION or VIEW_MODE_MAINLINE)
  if selected_view_mode == VIEW_MODE_CULTIVATION then
    return M.get_top_entry_title_by_action('switch_cultivation', '挂机')
  end
  return M.get_top_entry_title_by_action('start_stage', '开始游戏')
end

function M.get_top_entry_title_by_action(action, fallback_title)
  local target_action = tostring(action or '')
  if target_action ~= '' then
    for _, entry in ipairs(OUTGAME_TOP_ENTRY_LIST or {}) do
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

return M