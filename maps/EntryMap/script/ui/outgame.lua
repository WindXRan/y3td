local theme = require 'ui.theme'
local outgame_defs = require 'ui.outgame_defs'
local ArchiveShop = require 'ui.outgame_archive_shop'
local OutgameHeroGrowth = require 'runtime.outgame_hero_growth'
local ArchiveRankingTabs = require 'data.tables.outgame.archive_ranking_tabs'
local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'
local OutgameUIConfig = require 'data.tables.outgame.outgame_ui_config'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local play_ui_click = env.play_ui_click
  local ensure_music_loop = env.ensure_music_loop
  local hero_growth_api = OutgameHeroGrowth.create()

  local STAGE_LIST = CONFIG.stages and CONFIG.stages.list or {}
  local STAGES_BY_ID = CONFIG.stages and CONFIG.stages.by_id or {}
  local MODES_BY_ID = CONFIG.stage_modes and CONFIG.stage_modes.by_id or {}
  local SAVE_SLOT = CONFIG.save_slots and CONFIG.save_slots.outgame_profile or 1
  local OUTGAME_ATTR_BONUS_BY_STAGE_MODE = CONFIG.outgame_attr_bonus_config
    and CONFIG.outgame_attr_bonus_config.by_stage_mode
    or {}
  local OUTGAME_DEFS = outgame_defs.create(CONFIG)
  local RANKING_TABS = ArchiveRankingTabs.list or {}
  local OUTGAME_TOP_ENTRY_LIST = CONFIG.outgame_top_entry_list and CONFIG.outgame_top_entry_list.list or {}
  local OUTGAME_DETAIL_CONFIG = OUTGAME_DEFS.outgame_detail_config or {}
  local STAGE_PAGE_SIZE = 7
  local CHAPTER_LIST = {}
  local STAGES_BY_CHAPTER = {}
  local PAGE_LIST = {}
  local PAGES_BY_CHAPTER = {}
  local PAGE_BY_STAGE_ID = {}
  local MAX_CHAPTER_PAGE_COUNT = 0
  local MAX_CHAPTER_DIFFICULTY_COUNT = 0
  local SINGLE_MODE_ID = 'standard'
  local SINGLE_MODE_LABEL = '主线模式'
  local VIEW_MODE_MAINLINE = 'mainline'
  local VIEW_MODE_CULTIVATION = 'cultivation'
  local VIEW_MODE_LABELS = {
    [VIEW_MODE_MAINLINE] = '主线模式',
    [VIEW_MODE_CULTIVATION] = '打鱼模式',
  }
  local DAILY_TASK_DEFS = OutgameUIConfig.DAILY_TASK_DEFS or {}
  local COLOR = OutgameUIConfig.COLOR

  local api = {}
  local ensure_ui
  local refresh_ui
  local ensure_archive_panel_ui
  local refresh_archive_panel_ui
  local set_archive_panel_visible
  local is_outgame_ui_alive
  local ui_retry_timer = nil
  local ui_retry_remaining = 0

  local function clear_ui_retry_timer()
    if ui_retry_timer and ui_retry_timer.remove then
      ui_retry_timer:remove()
    end
    ui_retry_timer = nil
    ui_retry_remaining = 0
  end

  local function schedule_ui_retry()
    if not y3 or not y3.ltimer or type(y3.ltimer.wait) ~= 'function' then
      return
    end
    if ui_retry_timer then
      return
    end
    if ui_retry_remaining <= 0 then
      ui_retry_remaining = 12
    end
    ui_retry_timer = y3.ltimer.wait(0.2, function()
      ui_retry_timer = nil
      ui_retry_remaining = math.max(0, (ui_retry_remaining or 1) - 1)
      if STATE.session_phase ~= 'outgame' then
        clear_ui_retry_timer()
        return
      end
      local ui = ensure_ui()
      if is_outgame_ui_alive(ui) then
        clear_ui_retry_timer()
        refresh_ui()
        return
      end
      if ui_retry_remaining > 0 then
        schedule_ui_retry()
      end
    end)
  end
  local is_ui_alive

  local function resolve_ui(path)
    local ok, ui = pcall(y3.ui.get_ui, env.get_player(), path)
    if not ok or not ui then
      return nil
    end
    return ui
  end

  local function resolve_ui_first(paths)
    if type(paths) ~= 'table' then
      return nil
    end
    for _, path in ipairs(paths) do
      local ui = resolve_ui(path)
      if is_ui_alive(ui) then
        return ui
      end
    end
    return nil
  end

  local function resolve_outgame_ui(path)
    return resolve_ui_first({
      'DifficultyHUD' .. path,
      'outgame' .. path,
    })
  end

  function is_ui_alive(ui)
    return ui and (not ui.is_removed or not ui:is_removed())
  end

  local function set_visible_if_alive(ui, visible)
    if is_ui_alive(ui) and ui.set_visible then
      ui:set_visible(visible == true)
    end
  end

  local function set_text_if_alive(ui, text)
    if is_ui_alive(ui) and ui.set_text then
      ui:set_text(text or '')
    end
  end

  local function set_intercepts_if_alive(ui, intercepts)
    if is_ui_alive(ui) and ui.set_intercepts_operations then
      ui:set_intercepts_operations(intercepts == true)
    end
  end

  local function set_z_order_if_alive(ui, z_order)
    if is_ui_alive(ui) and ui.set_z_order then
      ui:set_z_order(z_order)
    end
  end
  local ARCHIVE_PANEL_Z_ORDER = 9800
  local function ensure_archive_panel_on_top(ui)
    if not ui then
      return
    end
    set_z_order_if_alive(ui.root, ARCHIVE_PANEL_Z_ORDER)
    set_z_order_if_alive(ui.overlay, ARCHIVE_PANEL_Z_ORDER + 1)
    set_z_order_if_alive(ui.window, ARCHIVE_PANEL_Z_ORDER + 1)
    set_z_order_if_alive(ui.layout, ARCHIVE_PANEL_Z_ORDER + 2)
    set_z_order_if_alive(ui.layout_bg, ARCHIVE_PANEL_Z_ORDER + 2)
    set_z_order_if_alive(ui.panel_main, ARCHIVE_PANEL_Z_ORDER + 3)
    set_z_order_if_alive(ui.panel_ranking, ARCHIVE_PANEL_Z_ORDER + 3)
    set_z_order_if_alive(ui.panel_idle, ARCHIVE_PANEL_Z_ORDER + 3)
    set_z_order_if_alive(ui.panel_start, ARCHIVE_PANEL_Z_ORDER + 3)
    set_z_order_if_alive(ui.panel_battlepass, ARCHIVE_PANEL_Z_ORDER + 3)
    set_z_order_if_alive(ui.layout_title, ARCHIVE_PANEL_Z_ORDER + 4)
    set_z_order_if_alive(ui.layout_exit, ARCHIVE_PANEL_Z_ORDER + 4)
  end

  local function set_parent_if_alive(ui, parent_ui)
    if is_ui_alive(ui) and is_ui_alive(parent_ui) and ui.set_ui_comp_parent and parent_ui.handle then
      ui:set_ui_comp_parent(parent_ui.handle, false, true, true)
      return true
    end
    return false
  end

  local function set_relative_scale_if_alive(ui, scale_x, scale_y)
    if is_ui_alive(ui) and ui.set_widget_relative_scale then
      ui:set_widget_relative_scale(scale_x or 1, scale_y or scale_x or 1)
    end
  end

  local function set_text_color_if_alive(ui, color)
    if is_ui_alive(ui) and ui.set_text_color and color then
      ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_font_size_if_alive(ui, size)
    if is_ui_alive(ui) and ui.set_font_size and size then
      ui:set_font_size(size)
    end
  end

  local function set_text_alignment_if_alive(ui, horizontal, vertical)
    if is_ui_alive(ui) and ui.set_text_alignment then
      ui:set_text_alignment(horizontal, vertical)
    end
  end

  local function set_ui_size_if_alive(ui, width, height)
    if is_ui_alive(ui) and ui.set_ui_size then
      ui:set_ui_size(width, height)
    end
  end

  local function set_image_color_if_alive(ui, color)
    if is_ui_alive(ui) and ui.set_image_color and color then
      ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_image_if_alive(ui, image)
    if is_ui_alive(ui) and ui.set_image and image ~= nil and image ~= '' then
      ui:set_image(image)
    end
  end

  local function set_image_url_if_alive(ui, url, aid)
    if is_ui_alive(ui) and ui.set_image_url and type(url) == 'string' and url ~= '' then
      ui:set_image_url(url, aid)
    end
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

  local function refresh_archive_ranking_ui(ui)
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
      local root = resolve_ui(path)
      if is_ui_alive(root) then
        local idx = ((i - 1) % 4) + 1
        local def = RANKING_TABS[idx]
        local visible = def ~= nil and def.enabled ~= false
        set_visible_if_alive(root, visible)
        if visible then
          local label = resolve_ui(path .. '.label')
          local bg = resolve_ui(path .. '.button') or root
          set_text_if_alive(label, tostring(def.title or '排行榜'))
          local selected = def.tab == active_tab.tab
          set_image_color_if_alive(bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
          set_text_color_if_alive(label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
        end
      end
    end

    for _, def in ipairs(RANKING_TABS) do
      local list_root = resolve_ui_first({
        'ArchiveMain.排行榜.排行.' .. tostring(def.list_node or ''),
        'ArchivePanel.排行榜.排行.' .. tostring(def.list_node or ''),
      })
      if is_ui_alive(list_root) then
        local is_active = def.tab == active_tab.tab
        set_visible_if_alive(list_root, is_active)
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
              local row_root = resolve_ui_first({
                'ArchiveMain.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name,
                'ArchivePanel.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name,
              })
              local name_label = resolve_ui_first({
                'ArchiveMain.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_1',
                'ArchivePanel.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_1',
              })
              local score_label = resolve_ui_first({
                'ArchiveMain.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_2',
                'ArchivePanel.排行榜.排行.' .. tostring(list_node) .. '.' .. row_name .. '.label_2',
              })
              if is_ui_alive(row_root) and (is_ui_alive(name_label) or is_ui_alive(score_label)) then
                return row_name
              end
            end
            return candidates[1]
          end

          for idx = 1, 5 do
            local row_name = resolve_ranking_row_path(def.list_node, idx)
            local row_root = resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name,
              'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name,
            })
            local rank_label = resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.num',
              'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.num',
            })
            local name_label = resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_1',
              'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_1',
            })
            local score_label = resolve_ui_first({
              'ArchiveMain.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_2',
              'ArchivePanel.排行榜.排行.' .. tostring(def.list_node) .. '.' .. row_name .. '.label_2',
            })

            local row = rows[idx]
            set_visible_if_alive(row_root, row ~= nil)
            if row then
              set_text_if_alive(rank_label, tostring(idx))
              set_text_if_alive(name_label, tostring(row.name or '玩家'))
              set_text_if_alive(score_label, tostring(tonumber(row.score or 0) or 0))
            end
          end
        end
      end
    end
  end

  local function set_non_outgame_ui_visible(visible)
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
      local ui = resolve_ui(path)
      set_visible_if_alive(ui, visible == true)
    end

    -- 面板类 UI 不跟随“恢复非局外 UI”强制显示，避免关闭存档时闪出旧界面
    for _, path in ipairs(overlay_paths) do
      local ui = resolve_ui(path)
      set_visible_if_alive(ui, false)
    end

    if STATE.gm_ui then
      set_visible_if_alive(STATE.gm_ui.toggle_button, visible == true)
      set_visible_if_alive(STATE.gm_ui.panel, visible == true and STATE.gm_ui.visible == true)
    end
  end

  local function get_window_metrics()
    local width = tonumber(y3.ui.get_window_width and y3.ui.get_window_width() or nil) or 1920
    local height = tonumber(y3.ui.get_window_height and y3.ui.get_window_height() or nil) or 1080
    return width, height
  end

  local function parse_stage_id(stage_id)
    local chapter_text, stage_text = tostring(stage_id or ''):match('^(%d+)%-(%d+)$')
    return tonumber(chapter_text), tonumber(stage_text)
  end

  local function get_stage_display_text(stage_def, fallback_stage_id)
    if stage_def and stage_def.display_name and stage_def.display_name ~= '' then
      return stage_def.display_name
    end
    return tostring(fallback_stage_id or '未命名关卡')
  end

  local function get_mode_ui_label(mode_id)
    if mode_id == SINGLE_MODE_ID then
      return SINGLE_MODE_LABEL
    end
    local mode_def = MODES_BY_ID[mode_id]
    if mode_def and mode_def.display_name and mode_def.display_name ~= '' then
      return mode_def.display_name
    end
    return SINGLE_MODE_LABEL
  end

  local function get_view_mode_label(view_mode)
    return VIEW_MODE_LABELS[view_mode] or VIEW_MODE_LABELS[VIEW_MODE_MAINLINE]
  end

  for _, stage_def in ipairs(STAGE_LIST) do
    if not stage_def.stage_id then
      goto continue
    end
    local chapter_id = select(1, parse_stage_id(stage_def.stage_id))
    chapter_id = chapter_id or 1
    if not STAGES_BY_CHAPTER[chapter_id] then
      STAGES_BY_CHAPTER[chapter_id] = {}
      CHAPTER_LIST[#CHAPTER_LIST + 1] = chapter_id
    end
    STAGES_BY_CHAPTER[chapter_id][#STAGES_BY_CHAPTER[chapter_id] + 1] = stage_def
    MAX_CHAPTER_DIFFICULTY_COUNT = math.max(MAX_CHAPTER_DIFFICULTY_COUNT, #STAGES_BY_CHAPTER[chapter_id])
    ::continue::
  end
  table.sort(CHAPTER_LIST)

  local function get_chapter_stage_list(chapter_id)
    return STAGES_BY_CHAPTER[chapter_id] or {}
  end

  local function get_chapter_display_text(chapter_id)
    local chapter_stages = get_chapter_stage_list(chapter_id)
    local first_stage = chapter_stages[1]
    local display = get_stage_display_text(first_stage, string.format('%s-1', tostring(chapter_id or 1)))
    local chapter_name = tostring(display):gsub('%-%d+$', '')
    if chapter_name == '' then
      return tostring(chapter_id or '未命名章节')
    end
    return chapter_name
  end

  local function get_page_label(page_stages)
    local first_stage = page_stages[1]
    local last_stage = page_stages[#page_stages]
    if not first_stage or not last_stage then
      return '暂无关卡'
    end
    if first_stage.stage_id == last_stage.stage_id then
      return first_stage.stage_id
    end
    return string.format('%s ~ %s', first_stage.stage_id, last_stage.stage_id)
  end

  do
    local global_index = 0
    for _, chapter_id in ipairs(CHAPTER_LIST) do
      local chapter_stages = get_chapter_stage_list(chapter_id)
      local chapter_page_index = 0
      for start_index = 1, #chapter_stages, STAGE_PAGE_SIZE do
        chapter_page_index = chapter_page_index + 1
        global_index = global_index + 1
        local page_stages = {}
        for offset = 0, STAGE_PAGE_SIZE - 1 do
          local stage_def = chapter_stages[start_index + offset]
          if not stage_def then
            break
          end
          page_stages[#page_stages + 1] = stage_def
        end
        local page_def = {
          id = string.format('page_%d', global_index),
          global_index = global_index,
          chapter_id = chapter_id,
          chapter_page_index = chapter_page_index,
          stages = page_stages,
          label = get_page_label(page_stages),
        }
        PAGE_LIST[#PAGE_LIST + 1] = page_def
        PAGES_BY_CHAPTER[chapter_id] = PAGES_BY_CHAPTER[chapter_id] or {}
        PAGES_BY_CHAPTER[chapter_id][#PAGES_BY_CHAPTER[chapter_id] + 1] = page_def
        MAX_CHAPTER_PAGE_COUNT = math.max(MAX_CHAPTER_PAGE_COUNT, #PAGES_BY_CHAPTER[chapter_id])
        for _, stage_def in ipairs(page_stages) do
          if stage_def.stage_id then
            PAGE_BY_STAGE_ID[stage_def.stage_id] = page_def
          end
        end
      end
    end
  end

  local function is_stage_supported_mode(stage_def, mode_id)
    if not stage_def or not stage_def.mode_ids then
      return false
    end
    for _, allowed_mode_id in ipairs(stage_def.mode_ids) do
      if allowed_mode_id == mode_id then
        return true
      end
    end
    return false
  end

  local function get_stage_progress(profile, stage_id)
    if not profile or type(profile.stage_progress) ~= 'table' then
      return nil
    end
    return profile.stage_progress[stage_id]
  end

  local function is_standard_unlocked(profile, stage_id)
    local progress = get_stage_progress(profile, stage_id)
    return progress and progress.standard_unlocked == true or false
  end

  local function is_mode_unlocked(profile, stage_id, mode_id)
    mode_id = mode_id or SINGLE_MODE_ID
    local progress = get_stage_progress(profile, stage_id)
    if not progress and (stage_id == '1-0' or stage_id == '1-1') and mode_id == SINGLE_MODE_ID then
      return true
    end
    if not progress then
      return false
    end
    if mode_id == SINGLE_MODE_ID then
      if stage_id == '1-0' or stage_id == '1-1' then
        return true
      end
      return progress.standard_unlocked == true
    end
    return false
  end

  local function get_first_stage_id()
    local first_stage = STAGE_LIST[1]
    return first_stage and first_stage.stage_id or '1-1'
  end

  local function set_save_backend_state(enabled, detail)
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

  local function build_save_status_brief(profile)
    local stage_id = profile and profile.selected_stage_id or STATE.selected_stage_id or get_first_stage_id()
    if STATE.outgame_profile_save_enabled == true then
      return string.format('槽位 %d · 云端已连接\n当前关卡：%s', SAVE_SLOT, tostring(stage_id))
    end
    return string.format('槽位 %d · 当前为内存态\n点击按钮查看原因', SAVE_SLOT)
  end

  local function build_save_status_detail(profile)
    local stage_id = profile and profile.selected_stage_id or STATE.selected_stage_id or get_first_stage_id()
    local stage_def = STAGES_BY_ID[stage_id]
    local stage_name = get_stage_display_text(stage_def, stage_id)
    if STATE.outgame_profile_save_enabled == true then
      return string.format(
        '局外存档已连接到槽位 %d。\n当前进度：%s。\n系统会在关键节点自动上传，也可以手动保存一次。',
        SAVE_SLOT,
        stage_name
      )
    end
    return string.format(
      '当前会话使用内存态默认档。\n当前进度：%s。\n原因：%s',
      stage_name,
      tostring(STATE.outgame_profile_save_error or '局外存档不可用')
    )
  end

  local function get_stage_index(stage_id)
    for index, stage_def in ipairs(STAGE_LIST) do
      if stage_def.stage_id == stage_id then
        return index
      end
    end
    return nil
  end

  local function get_next_stage_id(stage_id)
    local index = get_stage_index(stage_id)
    if not index then
      return nil
    end
    local next_stage = STAGE_LIST[index + 1]
    return next_stage and next_stage.stage_id or nil
  end

  local function get_highest_unlocked_standard_stage_id(profile)
    local fallback = get_first_stage_id()
    for _, stage_def in ipairs(STAGE_LIST) do
      if is_standard_unlocked(profile, stage_def.stage_id) then
        fallback = stage_def.stage_id
      end
    end
    return fallback
  end

  local function get_selected_chapter_id(stage_id)
    return select(1, parse_stage_id(stage_id)) or CHAPTER_LIST[1]
  end

  local function get_chapter_progress_state(profile, chapter_id)
    local unlocked_count = 0
    local cleared_count = 0
    for _, stage_def in ipairs(get_chapter_stage_list(chapter_id)) do
      local progress = get_stage_progress(profile, stage_def.stage_id)
      if progress and progress.standard_unlocked then
        unlocked_count = unlocked_count + 1
      end
      if progress and progress.standard_cleared then
        cleared_count = cleared_count + 1
      end
    end
    return unlocked_count, cleared_count
  end

  local function get_chapter_target_stage_id(profile, chapter_id, preferred_stage_id)
    local chapter_stages = get_chapter_stage_list(chapter_id)
    local fallback_stage_id = chapter_stages[1] and chapter_stages[1].stage_id or get_first_stage_id()
    if preferred_stage_id
      and STAGES_BY_ID[preferred_stage_id]
      and get_selected_chapter_id(preferred_stage_id) == chapter_id then
      return preferred_stage_id
    end

    local latest_unlocked_stage_id = nil
    for _, stage_def in ipairs(chapter_stages) do
      if is_standard_unlocked(profile, stage_def.stage_id) then
        latest_unlocked_stage_id = stage_def.stage_id
      end
    end

    return latest_unlocked_stage_id or fallback_stage_id
  end

  local function mark_profile_dirty()
    if STATE.outgame_profile_save_enabled ~= true then
      return
    end
    local ok, err = pcall(y3.save_data.upload_save_data, env.get_player())
    if ok then
      set_save_backend_state(true)
      return
    end
    set_save_backend_state(false, err)
  end

  local function ensure_stage_progress_defaults(profile, stage_id)
    local dirty = false
    if type(profile.stage_progress) ~= 'table' then
      profile.stage_progress = {}
      dirty = true
    end
    if type(profile.stage_progress[stage_id]) ~= 'table' then
      profile.stage_progress[stage_id] = {}
      dirty = true
    end
    local progress = profile.stage_progress[stage_id]
    local is_first_stage = stage_id == get_first_stage_id() or stage_id == '1-0' or stage_id == '1-1'
    if progress.standard_unlocked == nil then
      progress.standard_unlocked = is_first_stage
      dirty = true
    end
    if progress.standard_cleared == nil then
      progress.standard_cleared = false
      dirty = true
    end
    if progress.challenge_unlocked == nil then
      progress.challenge_unlocked = false
      dirty = true
    end
    if progress.challenge_cleared == nil then
      progress.challenge_cleared = false
      dirty = true
    end
    return dirty
  end

  local function normalize_loaded_selection(profile)
    local dirty = false
    local selected_stage_id = profile.selected_stage_id
    local fallback_stage_id = get_highest_unlocked_standard_stage_id(profile)
    if type(selected_stage_id) ~= 'string'
      or not STAGES_BY_ID[selected_stage_id]
      or not is_standard_unlocked(profile, selected_stage_id) then
      profile.selected_stage_id = fallback_stage_id
      dirty = true
    end
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

  local function rebuild_hero_attr_bonus_stats(profile)
    local rebuilt = {}
    for _, stage_def in ipairs(STAGE_LIST) do
      local stage_id = stage_def.stage_id
      local progress = get_stage_progress(profile, stage_id)
      local stage_rules = OUTGAME_ATTR_BONUS_BY_STAGE_MODE[stage_id]
      if progress and stage_rules then
        if progress.standard_cleared == true then
          merge_bonus_stats(rebuilt, stage_rules.standard)
        end
        if progress.challenge_cleared == true then
          merge_bonus_stats(rebuilt, stage_rules.challenge)
        end
      end
    end
    if are_same_bonus_stats(profile.hero_attr_bonus_stats, rebuilt) then
      return false
    end
    profile.hero_attr_bonus_stats = rebuilt
    return true
  end

  local load_profile

  local function archive_item_profile_key(spec)
    if type(spec) ~= 'table' then
      return ''
    end
    return table.concat({
      tostring(spec.partition or ''),
      tostring(spec.primary or spec.l1_tab or ''),
      tostring(spec.title or spec.name or ''),
    }, '|')
  end

  local function to_archive_integer(value)
    local number = tonumber(value) or 0
    return math.max(0, math.floor(number))
  end

  local function ensure_archive_item_entry(profile, spec)
    if type(profile) ~= 'table' or type(spec) ~= 'table' then
      return false
    end
    if type(profile.archive_items) ~= 'table' then
      profile.archive_items = {}
    end
    local key = archive_item_profile_key(spec)
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
      local normalized = tostring(to_archive_integer(entry.owned_text))
      if entry.owned_text ~= normalized then
        entry.owned_text = normalized
        dirty = true
      end
    end
    if type(entry.runtime_level) ~= 'number' then
      entry.runtime_level = to_archive_integer(entry.runtime_level)
      dirty = true
    end
    if type(entry.runtime_reroll_count) ~= 'number' then
      entry.runtime_reroll_count = to_archive_integer(entry.runtime_reroll_count)
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

  local function ensure_archive_items_profile_defaults(profile)
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

  local function apply_archive_item_profile_to_spec(profile, spec)
    if type(profile) ~= 'table' or type(spec) ~= 'table' then
      return
    end
    local key = spec.archive_profile_key or archive_item_profile_key(spec)
    local entry = type(profile.archive_items) == 'table' and profile.archive_items[key] or nil
    if type(entry) ~= 'table' then
      return
    end
    spec.archive_profile_key = key
    spec.owned_text = tostring(entry.owned_text or '')
    spec.runtime_level = to_archive_integer(entry.runtime_level)
    spec.runtime_reroll_count = to_archive_integer(entry.runtime_reroll_count)
    spec.runtime_equipped = entry.runtime_equipped == true
    spec.runtime_random_bonus = entry.runtime_random_bonus
  end

  local function sync_archive_shop_specs_from_profile(profile)
    profile = profile or STATE.outgame_profile
    if type(profile) ~= 'table' then
      return
    end
    if ensure_archive_items_profile_defaults(profile) then
      mark_profile_dirty()
    end
    for _, spec in ipairs(OUTGAME_DEFS.archive_shop_item_specs or {}) do
      if spec.source == 'csv_shangchengdaojv_feature' then
        apply_archive_item_profile_to_spec(profile, spec)
      end
    end
  end

  local function persist_archive_shop_specs_to_profile()
    local profile = load_profile()
    ensure_archive_items_profile_defaults(profile)
    for _, spec in ipairs(OUTGAME_DEFS.archive_shop_item_specs or {}) do
      if spec.source == 'csv_shangchengdaojv_feature' then
        local key = spec.archive_profile_key or archive_item_profile_key(spec)
        if key ~= '' and key ~= '||' then
          local entry = profile.archive_items[key]
          if type(entry) ~= 'table' then
            entry = {}
            profile.archive_items[key] = entry
          end
          entry.owned_text = tostring(spec.owned_text or '')
          entry.runtime_level = to_archive_integer(spec.runtime_level)
          entry.runtime_reroll_count = to_archive_integer(spec.runtime_reroll_count)
          entry.runtime_equipped = spec.runtime_equipped == true
          entry.runtime_random_bonus = spec.runtime_random_bonus
        end
      end
    end
    mark_profile_dirty()
  end

  local function ensure_profile_defaults(profile)
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
    if hero_growth_api and hero_growth_api.ensure_profile_defaults and hero_growth_api.ensure_profile_defaults(profile) then
      dirty = true
    end
    if ensure_archive_items_profile_defaults(profile) then
      dirty = true
    end
    if profile.selected_view_mode ~= VIEW_MODE_MAINLINE and profile.selected_view_mode ~= VIEW_MODE_CULTIVATION then
      profile.selected_view_mode = VIEW_MODE_MAINLINE
      dirty = true
    end
    for _, stage_def in ipairs(STAGE_LIST) do
      if ensure_stage_progress_defaults(profile, stage_def.stage_id) then
        dirty = true
      end
    end
    if rebuild_hero_attr_bonus_stats(profile) then
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
    if normalize_loaded_selection(profile) then
      dirty = true
    end
    return dirty
  end

  load_profile = function()
    if STATE.outgame_profile then
      return STATE.outgame_profile
    end

    local profile
    local ok, result = pcall(function()
      return y3.save_data.load_table(env.get_player(), SAVE_SLOT, true)
    end)

    if ok and type(result) == 'table' then
      profile = result
      set_save_backend_state(true)
    else
      profile = {}
      set_save_backend_state(false, result)
    end

    local defaults_ok, defaults_dirty_or_err = pcall(ensure_profile_defaults, profile)
    if not defaults_ok then
      profile = {}
      STATE.outgame_profile = profile
      set_save_backend_state(false, defaults_dirty_or_err)
      ensure_profile_defaults(profile)
      return profile
    end

    STATE.outgame_profile = profile
    if defaults_dirty_or_err then
      mark_profile_dirty()
    end

    return profile
  end

  local function sync_selected_state(stage_id, mode_id)
    mode_id = mode_id == SINGLE_MODE_ID and mode_id or SINGLE_MODE_ID
    STATE.selected_stage_id = stage_id
    STATE.selected_mode_id = mode_id
    STATE.current_stage_def = STAGES_BY_ID[stage_id]
    STATE.current_mode_def = MODES_BY_ID[mode_id] or MODES_BY_ID[SINGLE_MODE_ID]
  end

  local function get_page_for_stage(stage_id)
    return PAGE_BY_STAGE_ID[stage_id] or PAGE_LIST[1]
  end

  local function get_selected_view_mode(profile)
    local view_mode = profile and profile.selected_view_mode or nil
    if view_mode == VIEW_MODE_CULTIVATION then
      return VIEW_MODE_CULTIVATION
    end
    return VIEW_MODE_MAINLINE
  end

  local function get_chapter_page_list(chapter_id)
    return PAGES_BY_CHAPTER[chapter_id] or {}
  end

  local function get_difficulty_display_text(stage_def, fallback_index)
    local difficulty_index = stage_def and select(2, parse_stage_id(stage_def.stage_id)) or fallback_index or 1
    if tonumber(difficulty_index) == 1 then
      return 'N'
    end
    return 'R'
  end

  local function get_page_display_text(page_def)
    local difficulty_index = page_def and tonumber(page_def.chapter_page_index) or 1
    if tonumber(difficulty_index) == 1 then
      return 'N'
    end
    return 'R'
  end

  local function get_page_target_stage_id(profile, page_def, preferred_stage_id)
    local page_stages = page_def and page_def.stages or {}
    local fallback_stage_id = page_stages[1] and page_stages[1].stage_id or get_first_stage_id()
    local preferred_page = preferred_stage_id and get_page_for_stage(preferred_stage_id) or nil
    if preferred_page and page_def and preferred_page.id == page_def.id then
      return preferred_stage_id
    end

    local latest_unlocked_stage_id = nil
    for _, stage_def in ipairs(page_stages) do
      if is_standard_unlocked(profile, stage_def.stage_id) then
        latest_unlocked_stage_id = stage_def.stage_id
      end
    end

    return latest_unlocked_stage_id or fallback_stage_id
  end

  local function set_selected_stage(stage_id)
    local profile = load_profile()
    local stage_def = STAGES_BY_ID[stage_id]
    if not stage_def then
      return false
    end

    profile.selected_stage_id = stage_id
    profile.selected_mode_id = SINGLE_MODE_ID

    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    mark_profile_dirty()
    return true
  end

  local function set_selected_mode(mode_id)
    if mode_id ~= SINGLE_MODE_ID then
      return false
    end
    local profile = load_profile()
    if not is_mode_unlocked(profile, profile.selected_stage_id, SINGLE_MODE_ID) then
      return false
    end

    profile.selected_mode_id = SINGLE_MODE_ID
    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    mark_profile_dirty()
    return true
  end

  local function set_selected_view_mode(view_mode)
    if view_mode ~= VIEW_MODE_CULTIVATION then
      view_mode = VIEW_MODE_MAINLINE
    end

    local profile = load_profile()
    if profile.selected_view_mode == view_mode then
      return false
    end

    profile.selected_view_mode = view_mode
    mark_profile_dirty()
    return true
  end

  local function get_stage_status_text(profile, stage_def)
    local progress = get_stage_progress(profile, stage_def.stage_id)
    if not progress or not progress.standard_unlocked then
      return '未解锁'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return '当前关卡暂复用 1-1 战斗内容'
    end
    if progress.standard_cleared then
      return '已通关'
    end
    return '已开放'
  end

  local function get_mode_hint_text(profile, stage_id, mode_id)
    if mode_id ~= SINGLE_MODE_ID then
      return '当前版本仅保留主线模式。'
    end
    return '主线模式用于推进关卡，是当前版本的主要体验路径。'
  end

  local function build_start_hint(profile, stage_id, mode_id)
    local stage_def = STAGES_BY_ID[stage_id]
    if not stage_def then
      return '当前选择无效，请重新确认关卡。'
    end
    if get_selected_view_mode(profile) == VIEW_MODE_CULTIVATION then
      return '打鱼模式当前先保留为局外入口展示，暂不开放进入战斗。'
    end
    if mode_id ~= SINGLE_MODE_ID then
      return '当前版本仅保留主线模式。'
    end
    if not is_standard_unlocked(profile, stage_id) then
      return '当前关卡尚未开放，请先推进上一关。'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return string.format('本关当前复用 %s 战斗内容做流程验证。', tostring(stage_def.content_source_stage_id))
    end
    return '当前关卡已准备完成，点击开始即可进入战斗。'
  end

  local function get_detail_state_key(profile, stage_def, stage_id, mode_id)
    if get_selected_view_mode(profile) == VIEW_MODE_CULTIVATION then
      return 'cultivation'
    end
    if mode_id ~= SINGLE_MODE_ID then
      return 'mode_locked'
    end
    if not is_standard_unlocked(profile, stage_id) then
      return 'locked'
    end
    if stage_def and stage_def.content_source_stage_id ~= stage_def.stage_id then
      return 'reused'
    end
    local progress = stage_def and get_stage_progress(profile, stage_def.stage_id) or nil
    if progress and progress.standard_cleared == true then
      return 'cleared'
    end
    return 'open'
  end

  local function pick_detail_value(spec, key, state_key)
    if type(spec) ~= 'table' then
      return nil
    end
    local direct = spec[key]
    if type(direct) == 'string' and direct ~= '' then
      return direct
    end
    local by_state = spec[key .. '_by_state']
    if type(by_state) == 'table' then
      local value = by_state[state_key]
      if type(value) == 'string' and value ~= '' then
        return value
      end
      local fallback = by_state.default
      if type(fallback) == 'string' and fallback ~= '' then
        return fallback
      end
    end
    return nil
  end

  local function resolve_outgame_detail_texts(profile, stage_id, mode_id)
    local stage_def = STAGES_BY_ID[stage_id]
    local selected_view_mode = get_selected_view_mode(profile)
    local state_key = get_detail_state_key(profile, stage_def, stage_id, mode_id)

    local base_title = selected_view_mode == VIEW_MODE_CULTIVATION
      and '打鱼模式'
      or get_stage_display_text(stage_def, stage_id)
    local base_status = selected_view_mode == VIEW_MODE_CULTIVATION
      and ''
      or get_stage_status_text(profile, stage_def)
    local base_hint = build_start_hint(profile, stage_id, mode_id)

    local mode_key = selected_view_mode == VIEW_MODE_CULTIVATION and VIEW_MODE_CULTIVATION or VIEW_MODE_MAINLINE
    local mode_spec = OUTGAME_DETAIL_CONFIG.mode_details and OUTGAME_DETAIL_CONFIG.mode_details[mode_key] or nil
    local stage_spec = OUTGAME_DETAIL_CONFIG.stage_details and OUTGAME_DETAIL_CONFIG.stage_details[stage_id] or nil

    local title = pick_detail_value(mode_spec, 'title', state_key) or base_title
    title = pick_detail_value(stage_spec, 'title', state_key) or title

    local status = pick_detail_value(mode_spec, 'status', state_key) or base_status
    status = pick_detail_value(stage_spec, 'status', state_key) or status

    local hint = pick_detail_value(mode_spec, 'hint', state_key) or base_hint
    hint = pick_detail_value(stage_spec, 'hint', state_key) or hint

    return title, status, hint
  end

  local function format_last_result(profile)
    local result = profile and profile.last_result or nil
    if type(result) ~= 'table' or not result.stage_id then
      return ''
    end

    local outcome = result.is_win and '胜利' or '失败'
    local stage_def = STAGES_BY_ID[result.stage_id]
    local stage_name = get_stage_display_text(stage_def, result.stage_id)
    local reached_wave = math.max(0, result.reached_wave_index or 0)

    return string.format(
      '最近战报：%s %s %s，到达波次 %d',
      stage_name,
      SINGLE_MODE_LABEL,
      outcome,
      reached_wave
    )
  end

  local function build_header_tip_text(profile, stage_id, mode_id)
    local stage_def = STAGES_BY_ID[stage_id]
    local stage_name = get_stage_display_text(stage_def, stage_id)
    local result_text = format_last_result(profile)
    local hint = build_start_hint(profile, stage_id, mode_id)
    if result_text ~= '' then
      return string.format('当前关卡：%s。%s %s', stage_name, hint, result_text)
    end
    return string.format('当前关卡：%s。%s', stage_name, hint)
  end

  local function build_stage_slot_text(profile, stage_def)
    local display = get_stage_display_text(stage_def, stage_def.stage_id)
    local progress = get_stage_progress(profile, stage_def.stage_id)
    if not progress or not progress.standard_unlocked then
      return display .. ' · 未解锁'
    end
    if progress.standard_cleared then
      return display .. ' · 已通关'
    end
    return display
  end

  local function format_bonus_summary(profile)
    local stats = profile and profile.hero_attr_bonus_stats or nil
    if type(stats) ~= 'table' then
      return '尚未获得局外属性奖励'
    end

    local parts = {}
    for _, attr_name in ipairs({ '攻击白字', '生命白字', '攻击范围' }) do
      local value = tonumber(stats[attr_name])
      if value and value ~= 0 then
        parts[#parts + 1] = string.format('%s +%s', attr_name, value)
      end
    end

    if #parts == 0 then
      return '尚未获得局外属性奖励'
    end
    return table.concat(parts, ' / ')
  end

  local function refresh_reward_card(ui, profile, selected_stage_id)
    local selected_stage_def = STAGES_BY_ID[selected_stage_id]
    set_image_color_if_alive(ui.reward_card, theme.palette.panel_alt)
    set_text_if_alive(ui.reward_title, '当前关卡奖励')
    if selected_stage_def then
      set_text_if_alive(ui.reward_code, string.format('章节：%s', get_stage_display_text(selected_stage_def, selected_stage_id)))
    else
      set_text_if_alive(ui.reward_code, '章节：未选择')
    end
    set_text_if_alive(ui.reward_hint, format_bonus_summary(profile))
  end

  local get_player_display_name
  local DEFAULT_PLAYER_AVATAR = 134223473

  local function get_player_avatar_payload(player)
    if not player then
      return 'icon', DEFAULT_PLAYER_AVATAR
    end

    local icon_url = ''
    local ok_url, result_url = pcall(function()
      if player.get_platform_icon_url then
        return player:get_platform_icon_url()
      end
      return ''
    end)
    if ok_url and type(result_url) == 'string' then
      icon_url = result_url
    end
    if icon_url ~= '' then
      local aid = nil
      local ok_id, platform_id = pcall(function()
        if player.get_platform_id then
          return player:get_platform_id()
        end
        return 0
      end)
      if ok_id and platform_id and platform_id ~= 0 then
        aid = string.format('player_avatar_%s', tostring(platform_id))
      end
      return 'url', icon_url, aid
    end

    local ok_icon, platform_icon = pcall(function()
      if player.get_platform_icon then
        return player:get_platform_icon()
      end
      return nil
    end)
    if ok_icon and platform_icon ~= nil and platform_icon ~= '' then
      return 'icon', platform_icon
    end

    return 'icon', DEFAULT_PLAYER_AVATAR
  end

  local function refresh_player_slot_avatar(slot, player, occupied)
    if not slot or not is_ui_alive(slot.avatar) then
      return
    end
    if occupied ~= true then
      slot.avatar_key = nil
      set_visible_if_alive(slot.avatar, false)
      return
    end

    local payload_kind, payload_value, payload_aid = get_player_avatar_payload(player)
    if payload_value == nil or payload_value == '' then
      slot.avatar_key = nil
      set_visible_if_alive(slot.avatar, false)
      return
    end

    set_visible_if_alive(slot.avatar, true)
    local payload_key = string.format('%s:%s', tostring(payload_kind), tostring(payload_value))
    if slot.avatar_key == payload_key then
      return
    end
    slot.avatar_key = payload_key

    if payload_kind == 'url' then
      set_image_url_if_alive(slot.avatar, payload_value, payload_aid)
    else
      set_image_if_alive(slot.avatar, payload_value)
    end
  end

  local function refresh_footer(ui, profile)
    local player = env.get_player and env.get_player() or nil
    local mode_label = get_view_mode_label(profile.selected_view_mode)
    local save_label = STATE.outgame_profile_save_enabled == true and '云存档' or '内存态'
    set_text_if_alive(ui.player_name, string.format('%s · %s · %s', get_player_display_name(), mode_label, save_label))
    for index, slot in ipairs(ui.player_slots or {}) do
      set_visible_if_alive(slot.root, true)
      if index == 1 then
        set_image_color_if_alive(slot.bg, theme.palette.warning)
        set_image_color_if_alive(slot.inner, { 255, 233, 192, 255 })
        set_text_if_alive(slot.label, '主机')
        refresh_player_slot_avatar(slot, player, true)
      else
        set_image_color_if_alive(slot.bg, theme.palette.panel)
        set_image_color_if_alive(slot.inner, theme.palette.panel_deep)
        set_text_if_alive(slot.label, '')
        refresh_player_slot_avatar(slot, player, false)
      end
    end
  end

  local function get_page_progress_state(profile, page_def)
    local unlocked_count = 0
    local cleared_count = 0
    for _, stage_def in ipairs(page_def.stages or {}) do
      local progress = get_stage_progress(profile, stage_def.stage_id)
      if progress and progress.standard_unlocked then
        unlocked_count = unlocked_count + 1
      end
      if progress and progress.standard_cleared then
        cleared_count = cleared_count + 1
      end
    end
    return unlocked_count, cleared_count
  end

  function is_outgame_ui_alive(ui)
    return ui
      and is_ui_alive(ui.root)
      and is_ui_alive(ui.hall_root)
      and is_ui_alive(ui.stage_slot_container)
      and is_ui_alive(ui.start_button)
  end

  local function bind_stage_slot(slot)
    if not slot or not is_ui_alive(slot.root) or slot.bound == true then
      return
    end
    slot.bound = true
    slot.root:add_fast_event('左键-按下', function()
      local stage_def = slot.stage_def
      if not stage_def then
        return
      end
      if play_ui_click then
        play_ui_click()
      end
      if set_selected_stage(stage_def.stage_id) then
        api.refresh_ui()
      end
    end)
  end

  local function bind_mode_slot(slot)
    local click_target = slot and (slot.button or slot.root) or nil
    if not is_ui_alive(click_target) or slot.bound == true then
      return
    end
    slot.bound = true
    click_target:add_fast_event('左键-按下', function()
      if play_ui_click then
        play_ui_click()
      end
      if set_selected_view_mode(slot.view_mode) then
        api.refresh_ui()
      end
    end)
  end

  local function ensure_save_entry_ui(ui)
    if not ui or not is_ui_alive(ui.hall_root) then
      return nil
    end
    if ui.save_entry
      and is_ui_alive(ui.save_entry.root)
      and is_ui_alive(ui.save_entry.status)
      and is_ui_alive(ui.save_entry.button) then
      return ui.save_entry
    end
    return nil
  end

  local function refresh_save_entry_ui(ui, profile)
    local save_entry = ensure_save_entry_ui(ui)
    if not save_entry then
      return
    end

    set_visible_if_alive(save_entry.root, STATE.session_phase == 'outgame')
    set_text_if_alive(save_entry.status, build_save_status_brief(profile))
    set_text_if_alive(save_entry.button, '打开存档')
    set_image_color_if_alive(
      save_entry.button_bg,
      STATE.outgame_profile_save_enabled == true and { 60, 98, 150, 235 } or { 120, 88, 54, 235 }
    )
  end

  local function bind_save_entry(ui)
    local save_entry = ui and ui.save_entry or nil
    local button = save_entry and save_entry.button or nil
    if not is_ui_alive(button) or ui.save_entry_bound == true then
      return
    end

    ui.save_entry_bound = true
    button:add_fast_event('左键-按下', function()
      if play_ui_click then
        play_ui_click()
      end

      if api.open_save_panel() then
        return
      end
    end)
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
      -- 当前 top UI 缺少 button_6，直接兼容 button_7。
      candidates = { 'button_7', 'button_6' }
    else
      candidates = { string.format('button_%d', idx - 1) }
    end
    local paths = {}
    for _, name in ipairs(candidates) do
      paths[#paths + 1] = 'top.list.' .. name
      paths[#paths + 1] = 'top.top.list.' .. name
    end
    return resolve_ui_first(paths)
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
    return resolve_ui_first(paths)
  end

  local function dispatch_top_entry_action(entry)
    if type(entry) ~= 'table' then
      return
    end
    local action = tostring(entry.action or '')
    local function open_archive_with(section, show_ranking)
      if set_selected_view_mode then
        set_selected_view_mode(VIEW_MODE_MAINLINE)
      end
      STATE.archive_panel_section = section
      STATE.archive_ranking_visible = show_ranking == true
      if STATE.archive_ranking_visible == true and (not STATE.archive_ranking_tab or STATE.archive_ranking_tab <= 0) then
        STATE.archive_ranking_tab = 1
      end
      local profile = load_profile()
      if not set_archive_panel_visible(true) then
        api.open_save_panel()
        return
      end
      if refresh_archive_panel_ui then
        refresh_archive_panel_ui(profile)
      end
    end
    if action == 'open_archive' then
      STATE.archive_panel_section = 'archive'
      STATE.archive_ranking_visible = false
      api.open_save_panel()
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
      api.start_selected_stage()
      return
    end
    if action == 'switch_cultivation' then
      if set_selected_view_mode(VIEW_MODE_CULTIVATION) then
        api.refresh_ui()
      end
      return
    end
    if action == 'open_battlepass' then
      open_archive_with('battlepass', false)
      return
    end
    if action == 'show_hero_growth_tip' then
      message('英雄养成入口已迁移到“如何变强 / H”。')
      return
    end
    if action == 'refresh' then
      api.refresh_ui()
      return
    end
  end

  local function get_top_entry_title_by_action(action, fallback_title)
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

  local function resolve_outgame_top_title(profile)
    if STATE.archive_panel_visible == true then
      if STATE.archive_ranking_visible == true then
        return get_top_entry_title_by_action('open_archive_ranking', '排行榜')
      end
      local section = tostring(STATE.archive_panel_section or '')
      local partitions = ArchiveTabDefinitions.get_valid_partitions()
      if section == 'career' then
        return get_top_entry_title_by_action('open_archive_career', partitions[3] or '生涯')
      end
      if section == 'shop' then
        return get_top_entry_title_by_action('open_archive_shop', partitions[1] or '商城')
      end
      return get_top_entry_title_by_action('open_archive', partitions[2] or '存档')
    end
    local selected_view_mode = get_selected_view_mode(profile)
    if selected_view_mode == VIEW_MODE_CULTIVATION then
      return get_top_entry_title_by_action('switch_cultivation', '挂机')
    end
    return get_top_entry_title_by_action('start_stage', '开始游戏')
  end

  local function ensure_top_entry_list_ui(ui)
    if not ui then
      message('[top_entry] ui is nil, cannot ensure top entry list')
      return nil
    end
    ui.top_entry_list_root = ui.top_entry_list_root or resolve_ui_first({ 'top.list', 'top.top.list' })
    if not is_ui_alive(ui.top_entry_list_root) then
      message('[top_entry] top_entry_list_root is not alive, trying fallback')
    end
    if (not is_ui_alive(ui.top_entry_list_root)) and (ui.top_entry_fallback_root == nil) then
      local host = resolve_ui_first({ 'top.top', 'top' })
      if is_ui_alive(host) and host.create_child then
        local root = host:create_child('布局')
        if is_ui_alive(root) then
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
        if (not is_ui_alive(ui.top_entry_items[slot].button)) and is_ui_alive(ui.top_entry_fallback_root) and ui.top_entry_fallback_root.create_child then
          local btn = ui.top_entry_fallback_root:create_child('按钮')
          if is_ui_alive(btn) then
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

  local function refresh_top_entry_list_ui(ui)
    local items = ensure_top_entry_list_ui(ui)
    if not items then
      return
    end
    local in_outgame = STATE.session_phase == 'outgame'
    local in_battle = STATE.session_phase == 'battle'
    local should_show = in_outgame or in_battle
    set_visible_if_alive(ui.top_entry_list_root, should_show)
    for _, slot_ui in pairs(items) do
      local entry = slot_ui.entry
      local visible = false
      if in_outgame then
        visible = entry.visible_in_outgame ~= false
      elseif in_battle then
        visible = entry.visible_in_battle ~= false
      end
      set_visible_if_alive(slot_ui.button, visible)
      set_text_if_alive(slot_ui.label, entry.label or '')
    end
  end

  local function bind_top_entry_list(ui)
    local items = ensure_top_entry_list_ui(ui)
    if not items then
      message('[top_entry] bind_top_entry_list: items is nil')
      return
    end
    local bound_count = 0
    local missing_count = 0
    for _, slot_ui in pairs(items) do
      local button = slot_ui.button
      if is_ui_alive(button) then
        if slot_ui.bound ~= true then
          slot_ui.bound = true
          button:add_fast_event('左键-按下', function()
            if play_ui_click then
              play_ui_click()
            end
            dispatch_top_entry_action(slot_ui.entry or {})
          end)
          bound_count = bound_count + 1
        end
      else
        missing_count = missing_count + 1
      end
    end
    message(string.format('[top_entry] bind_top_entry_list: bound %d buttons, missing %d buttons', bound_count, missing_count))
  end

  local function bind_ui_events(ui)
    for _, slot in ipairs(ui.mode_slots or {}) do
      bind_mode_slot(slot)
    end
    for _, slot in ipairs(ui.stage_slots or {}) do
      bind_stage_slot(slot)
    end

    bind_save_entry(ui)
    bind_top_entry_list(ui)

    if ui.start_bound ~= true then
      local click_targets = {}
      local seen = {}
      local function push_target(target)
        if not is_ui_alive(target) then
          return
        end
        if seen[target] then
          return
        end
        seen[target] = true
        click_targets[#click_targets + 1] = target
      end
      push_target(ui.start_button)
      push_target(ui.start_button_bg)
      push_target(ui.start_anchor)
      if #click_targets > 0 then
        ui.start_bound = true
        local function on_start_click()
          if play_ui_click then
            play_ui_click()
          end
          message('[outgame] 点击开始游戏')
          api.start_selected_stage()
        end
        for _, target in ipairs(click_targets) do
          target:add_fast_event('左键-按下', on_start_click)
        end
      end
    end
  end

  local function sync_outgame_backdrop(ui)
    local backdrop = ui and ui.backdrop or nil
    if not is_ui_alive(backdrop) or not backdrop.set_ui_size then
      return
    end

    local window_width, window_height = get_window_metrics()
    backdrop:set_ui_size(window_width, window_height)
  end

  function get_player_display_name()
    local player = env.get_player and env.get_player() or nil
    if not player then
      return '玩家'
    end
    local ok, name = pcall(function()
      if player.get_name then
        return player:get_name()
      end
      return nil
    end)
    if ok and type(name) == 'string' and name ~= '' then
      return name
    end
    return '玩家'
  end

  local DEFAULT_PRIMARY = ArchiveTabDefinitions.get_valid_primary_tabs()[1] or '商品'

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

  local ARCHIVE_SHOP_OPTIONS = {
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
    persist_archive_items_state = persist_archive_shop_specs_to_profile,
  }

  local function is_archive_panel_ui_alive(ui)
    return ui
      and is_ui_alive(ui.root)
      and is_ui_alive(ui.overlay)
      and is_ui_alive(ui.window)
  end

  local function resolve_archive_chip(path, bg_name)
    bg_name = bg_name or 'bg'
    local root = resolve_ui(path)
    if not is_ui_alive(root) then
      return nil
    end
    return {
      root = root,
      bg = resolve_ui(path .. '.' .. bg_name) or root,
      label = resolve_ui(path .. '.label'),
      active = resolve_ui(path .. '.active'),
    }
  end

  local get_archive_player

  local function refresh_archive_main_shop_items(ui)
    ARCHIVE_SHOP_OPTIONS.player = env.get_player and env.get_player() or ARCHIVE_SHOP_OPTIONS.player
    sync_archive_shop_specs_from_profile(load_profile())
    return ArchiveShop.refresh(ui, ARCHIVE_SHOP_OPTIONS)
  end

  local function ensure_archive_main_shop_ui(ui)
    ARCHIVE_SHOP_OPTIONS.player = env.get_player and env.get_player() or ARCHIVE_SHOP_OPTIONS.player
    sync_archive_shop_specs_from_profile(load_profile())
    return ArchiveShop.ensure(ui, ARCHIVE_SHOP_OPTIONS)
  end

  local function to_non_negative_integer(value)
    local number = tonumber(value) or 0
    return math.max(0, math.floor(number))
  end

  local function get_archive_chip_click_target(chip)
    if chip and is_ui_alive(chip.bg) then
      return chip.bg
    end
    if chip and is_ui_alive(chip.root) then
      return chip.root
    end
    return nil
  end

  local bind_archive_panel_events
  local refresh_archive_enter_panel_visible

  ensure_archive_panel_ui = function()
    if is_archive_panel_ui_alive(STATE.archive_panel_ui) then
      ensure_archive_main_shop_ui(STATE.archive_panel_ui)
      bind_archive_panel_events(STATE.archive_panel_ui)
      refresh_archive_enter_panel_visible(STATE.archive_panel_ui)
      return STATE.archive_panel_ui
    end

    local archive_main_root = resolve_ui_first({ 'ArchiveMain', 'ArchivePanel' })
    local archive_main_overlay = resolve_ui_first({ 'ArchiveMain.layout_1', 'ArchiveMain.layout', 'ArchivePanel.layout_1', 'ArchivePanel.layout' })
    local archive_main_close = resolve_ui_first({
      'ArchiveMain.layout_1.exit',
      'ArchiveMain.layout.exit',
      'ArchiveMain.layout.close',
      'ArchivePanel.layout_1.exit',
      'ArchivePanel.layout.exit',
    })
    if is_ui_alive(archive_main_root) and is_ui_alive(archive_main_overlay) then
      local ui = {
        variant = 'archive_main_v2',
        root = archive_main_root,
        layout = resolve_ui_first({ 'ArchiveMain.layout', 'ArchivePanel.layout' }),
        layout_bg = resolve_ui_first({ 'ArchiveMain.layout.bg', 'ArchivePanel.layout.bg' }),
        layout_title = resolve_ui_first({ 'ArchiveMain.layout.title', 'ArchivePanel.layout.title' }),
        layout_exit = resolve_ui_first({ 'ArchiveMain.layout.exit', 'ArchivePanel.layout.exit' }),
        overlay = archive_main_overlay,
        window = archive_main_overlay,
        panel_main = resolve_ui_first({ 'ArchiveMain.存档生涯商城', 'ArchivePanel.存档生涯商城' }),
        panel_content_list = resolve_ui_first({ 'ArchiveMain.内容列表', 'ArchivePanel.内容列表' }),
        panel_main_page_grid = resolve_ui_first({
          'ArchiveMain.存档生涯商城.page_grid',
          'ArchivePanel.存档生涯商城.page_grid',
        }),
        panel_main_page2_grid = resolve_ui_first({
          'ArchiveMain.存档生涯商城.page2_grid',
          'ArchivePanel.存档生涯商城.page2_grid',
        }),
        panel_main_content_root = resolve_ui_first({
          'ArchiveMain.存档生涯商城.中间内容',
          'ArchivePanel.存档生涯商城.中间内容',
        }),
        panel_main_detail = resolve_ui_first({
          'ArchiveMain.存档生涯商城.文本详情',
          'ArchiveMain.存档生涯商城.scroll_view',
          'ArchivePanel.存档生涯商城.文本详情',
          'ArchivePanel.存档生涯商城.scroll_view',
        }),
        panel_main_content_archive = resolve_ui_first({
          'ArchiveMain.存档生涯商城.中间内容.存档',
          'ArchivePanel.存档生涯商城.中间内容.存档',
        }),
        panel_main_content_shop = resolve_ui_first({
          'ArchiveMain.存档生涯商城.中间内容.商城',
          'ArchivePanel.存档生涯商城.中间内容.商城',
        }),
        panel_main_content_career = resolve_ui_first({
          'ArchiveMain.存档生涯商城.中间内容.生涯',
          'ArchivePanel.存档生涯商城.中间内容.生涯',
        }),
        panel_ranking = resolve_ui_first({ 'ArchiveMain.排行榜', 'ArchivePanel.排行榜' }),
        panel_ranking_page_grid = resolve_ui_first({ 'ArchiveMain.排行榜.page_grid', 'ArchivePanel.排行榜.page_grid' }),
        panel_ranking_list = resolve_ui_first({ 'ArchiveMain.排行榜.排行榜列表', 'ArchivePanel.排行榜.排行榜列表' }),
        panel_ranking_scroll = resolve_ui_first({ 'ArchiveMain.排行榜.排行', 'ArchivePanel.排行榜.排行' }),
        panel_idle = resolve_ui_first({ 'ArchiveMain.挂机', 'ArchivePanel.挂机' }),
        panel_idle_page_grid = resolve_ui_first({ 'ArchiveMain.挂机.page_grid', 'ArchivePanel.挂机.page_grid' }),
        panel_idle_list = resolve_ui_first({ 'ArchiveMain.挂机.排行榜列表', 'ArchivePanel.挂机.排行榜列表' }),
        panel_idle_scroll = resolve_ui_first({ 'ArchiveMain.挂机.排行', 'ArchivePanel.挂机.排行' }),
        panel_start = resolve_ui_first({ 'ArchiveMain.开始', 'ArchivePanel.开始' }),
        panel_battlepass = resolve_ui_first({ 'ArchiveMain.战令', 'ArchivePanel.战令' }),
        close_button = archive_main_close,
        close_chip = {
          root = archive_main_close,
          bg = archive_main_close,
        },
        enter_panel_root = resolve_ui_first({ 'EnterPanel', 'ArchiveMain.EnterPanel' }),
        enter_panel_icon = resolve_ui_first({ 'EnterPanel.YangChengIcon', 'ArchiveMain.EnterPanel.YangChengIcon' }),
        enter_panel_bg = resolve_ui_first({ 'EnterPanel.YangChengIcon.bg', 'ArchiveMain.EnterPanel.YangChengIcon.bg' }),
        enter_panel_name = resolve_ui_first({ 'EnterPanel.YangChengIcon.name', 'ArchiveMain.EnterPanel.YangChengIcon.name' }),
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
    set_visible_if_alive(ui.enter_panel_root, visible)
    set_visible_if_alive(ui.enter_panel_icon, visible)
    set_visible_if_alive(ui.enter_panel_bg, visible)
    set_visible_if_alive(ui.enter_panel_name, visible)
  end

  set_archive_panel_visible = function(visible)
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
        set_non_outgame_ui_visible(false)
        STATE.archive_panel_hidden_non_outgame = true
      end
      set_visible_if_alive(ui.root, true)
      set_visible_if_alive(ui.layout, true)
      set_visible_if_alive(ui.layout_bg, true)
      set_visible_if_alive(ui.layout_title, true)
      set_visible_if_alive(ui.layout_exit, true)
      set_visible_if_alive(ui.overlay, true)
      set_visible_if_alive(ui.window, true)
      ensure_archive_panel_on_top(ui)
      STATE.archive_panel_visible = true
      if refresh_archive_panel_ui then
        refresh_archive_panel_ui(load_profile())
      end
      refresh_archive_enter_panel_visible(ui)
      return true
    end

    if STATE.archive_panel_hidden_non_outgame == true then
      set_non_outgame_ui_visible(STATE.session_phase ~= 'outgame')
      STATE.archive_panel_hidden_non_outgame = false
    end
    if is_archive_panel_ui_alive(ui) then
      set_visible_if_alive(ui.root, false)
      set_visible_if_alive(ui.layout, false)
      set_visible_if_alive(ui.layout_bg, false)
      set_visible_if_alive(ui.layout_title, false)
      set_visible_if_alive(ui.layout_exit, false)
      set_visible_if_alive(ui.overlay, false)
      set_visible_if_alive(ui.window, false)
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
      if is_ui_alive(enter_panel_target) then
        ui.enter_panel_bound = true
        set_intercepts_if_alive(enter_panel_target, true)
        enter_panel_target:add_fast_event('左键-按下', function()
          if play_ui_click then
            play_ui_click()
          end
          api.open_save_panel()
        end)
      end
    end

    if is_ui_alive(ui.dim) then
      ui.dim:add_fast_event('左键-按下', function()
        if STATE.archive_panel_visible ~= true then
          return
        end
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_visible(false)
      end)
    end

    local close_button_target = get_archive_chip_click_target(ui.close_chip)
      or (is_ui_alive(ui.close_button) and ui.close_button or nil)
    if is_ui_alive(close_button_target) then
      close_button_target:add_fast_event('左键-按下', function()
        if STATE.archive_panel_visible ~= true then
          return
        end
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_visible(false)
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
      local root = resolve_ui(path)
      local button = resolve_ui(path .. '.button') or root
      if is_ui_alive(button) then
        local tab_index = ((index - 1) % 4) + 1
        set_intercepts_if_alive(button, true)
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
          refresh_archive_ranking_ui(ui)
        end)
      end
    end
  end

  refresh_archive_panel_ui = function(profile)
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
    if section == 'battlepass' and not is_ui_alive(ui.panel_battlepass) then
      section = 'career'
    end
    local show_main = section == 'main' or section == 'career' or section == 'shop' or section == 'archive'
    local show_ranking = section == 'ranking'
    local show_idle = section == 'idle'
    local show_start = section == 'start'
    local show_battlepass = section == 'battlepass'
    local has_active_panel = show_main or show_ranking or show_idle or show_start or show_battlepass
    set_visible_if_alive(ui.root, STATE.archive_panel_visible == true)
    set_visible_if_alive(ui.layout, STATE.archive_panel_visible == true and has_active_panel)
    set_visible_if_alive(ui.layout_bg, STATE.archive_panel_visible == true and has_active_panel)
    set_visible_if_alive(ui.layout_title, STATE.archive_panel_visible == true and has_active_panel)
    set_visible_if_alive(ui.layout_exit, STATE.archive_panel_visible == true and has_active_panel)
    set_visible_if_alive(ui.overlay, STATE.archive_panel_visible == true and has_active_panel)
    set_visible_if_alive(ui.window, STATE.archive_panel_visible == true and has_active_panel)
    set_visible_if_alive(ui.panel_main, STATE.archive_panel_visible == true and show_main)
    set_visible_if_alive(ui.panel_content_list, STATE.archive_panel_visible == true and show_main)
    set_visible_if_alive(ui.panel_ranking, STATE.archive_panel_visible == true and show_ranking)
    set_visible_if_alive(ui.panel_idle, STATE.archive_panel_visible == true and show_idle)
    set_visible_if_alive(ui.panel_start, STATE.archive_panel_visible == true and show_start)
    set_visible_if_alive(ui.panel_battlepass, STATE.archive_panel_visible == true and show_battlepass)
    local show_main_content = STATE.archive_panel_visible == true and show_main
    local show_archive_content = show_main_content and (section == 'archive')
    local show_shop_content = show_main_content and (section == 'shop')
    local show_career_content = show_main_content and (section == 'career' or section == 'main')
    set_visible_if_alive(ui.panel_main_content_root, show_main_content)
    set_visible_if_alive(ui.panel_main_content_archive, show_archive_content)
    set_visible_if_alive(ui.panel_main_content_shop, show_shop_content)
    set_visible_if_alive(ui.panel_main_content_career, show_career_content)
    set_visible_if_alive(ui.panel_main_page_grid, show_main_content)
    set_visible_if_alive(ui.panel_main_page2_grid, show_main_content)
    set_visible_if_alive(ui.panel_main_detail, show_main_content)
    set_visible_if_alive(ui.panel_ranking_page_grid, STATE.archive_panel_visible == true and show_ranking)
    set_visible_if_alive(ui.panel_ranking_list, STATE.archive_panel_visible == true and show_ranking)
    set_visible_if_alive(ui.panel_ranking_scroll, STATE.archive_panel_visible == true and show_ranking)
    set_visible_if_alive(ui.panel_idle_page_grid, STATE.archive_panel_visible == true and show_idle)
    set_visible_if_alive(ui.panel_idle_list, STATE.archive_panel_visible == true and show_idle)
    set_visible_if_alive(ui.panel_idle_scroll, STATE.archive_panel_visible == true and show_idle)
    if STATE.archive_panel_visible == true and show_ranking then
      refresh_archive_ranking_ui(ui)
    end
    -- 面板标题跟随当前分区/入口，不再固定“选择难度”。
    set_text_if_alive(ui.layout_title, resolve_outgame_top_title(profile))
    ensure_archive_main_shop_ui(ui)
    refresh_archive_main_shop_items(ui)
    refresh_archive_enter_panel_visible(ui)
    return true
  end

  ensure_ui = function()
    if is_outgame_ui_alive(STATE.outgame_ui) then
      sync_outgame_backdrop(STATE.outgame_ui)
      refresh_save_entry_ui(STATE.outgame_ui, STATE.outgame_profile)
      bind_ui_events(STATE.outgame_ui)
      refresh_top_entry_list_ui(STATE.outgame_ui)
      return STATE.outgame_ui
    end

    local root = resolve_ui_first({ 'DifficultyHUD', 'outgame' })
    local hall_root = resolve_ui_first({ 'DifficultyHUD.大厅', 'outgame.大厅' })
    local backdrop = resolve_ui_first({
      'DifficultyHUD.大厅.layout.底板',
      'DifficultyHUD.大厅.layout.shade',
      'outgame.大厅.layout.底板',
      'outgame.大厅.layout.shade',
    })
    local title = resolve_outgame_ui('.大厅.layout.right.mode_name')
    local tip_root = resolve_outgame_ui('.大厅.layout.right.mode_name.猎场模式tips')
    local tip = resolve_outgame_ui('.大厅.layout.right.mode_name.猎场模式tips.layout_2.label_3')
    local page_container = resolve_outgame_ui('.大厅.layout.right.难度列表')
    local mode_panel = resolve_outgame_ui('.大厅.layout.left_2')
    local stage_slot_container = resolve_outgame_ui('.大厅.layout.right_2.list')
    local start_button = resolve_outgame_ui('.大厅.layout.start')

    if not (is_ui_alive(root) and is_ui_alive(hall_root)) then
      if not STATE.outgame_ui_bind_warned then
        STATE.outgame_ui_bind_warned = true
        message('未找到 outgame 静态画板，已等待界面编辑器面板加载。')
      end
      return nil
    end

    if is_ui_alive(root)
      and is_ui_alive(hall_root)
      and is_ui_alive(mode_panel)
      and is_ui_alive(stage_slot_container)
      and is_ui_alive(start_button) then
      local function build_static_mode_slot(base_path, view_mode, display_label)
        local slot_root = resolve_ui(base_path)
        local bg = resolve_ui(base_path .. '.模式')
        local label = resolve_ui(base_path .. '.模式.mode')
        local selected = resolve_ui(base_path .. '.模式.selected')
        if not is_ui_alive(slot_root) then
          return nil
        end
        return {
          root = slot_root,
          bg = bg or slot_root,
          button = bg or slot_root,
          label = label,
          selected = selected,
          view_mode = view_mode,
          display_label = display_label,
          bound = false,
        }
      end

      local function build_static_stage_slot(base_path)
        local slot_root = resolve_ui(base_path)
        local bg = resolve_ui(base_path .. '.模式')
        local label = resolve_ui(base_path .. '.模式.mode')
        local selected = resolve_ui(base_path .. '.模式.selected')
        if not is_ui_alive(slot_root) then
          return nil
        end
        return {
          root = slot_root,
          bg = bg or slot_root,
          label = label,
          selected = selected,
          bound = false,
          stage_def = nil,
        }
      end

      local mode_slots = {}

      local stage_slots = {}
      for index = 1, STAGE_PAGE_SIZE do
        local slot_name = string.format('mode%d', index)
        local slot = build_static_stage_slot('DifficultyHUD.大厅.layout.right_2.list.' .. slot_name)
        if not slot then
          slot = build_static_stage_slot('outgame.大厅.layout.right_2.list.' .. slot_name)
        end
        if slot then
          stage_slots[#stage_slots + 1] = slot
        end
      end

      local player_slots = {}
      for index = 1, 4 do
        local base_path = string.format('.大厅.layout.footer.slot_%d', index)
        local slot_root = resolve_outgame_ui(base_path)
        if is_ui_alive(slot_root) then
          player_slots[#player_slots + 1] = {
            root = slot_root,
            bg = resolve_outgame_ui(base_path .. '.frame') or slot_root,
            inner = resolve_outgame_ui(base_path .. '.inner'),
            avatar = resolve_outgame_ui(base_path .. '.avatar'),
            label = resolve_outgame_ui(base_path .. '.label'),
            avatar_key = nil,
          }
        end
      end

      STATE.outgame_ui = {
        root = root,
        hall_root = hall_root,
        backdrop = backdrop,
        title = title,
        header_tip = resolve_outgame_ui('.大厅.layout.header_tip'),
        tip_root = tip_root,
        tip = tip,
        mode_panel = mode_panel,
        mode_slots = mode_slots,
        left_panel = resolve_outgame_ui('.大厅.layout.left'),
        reward_card = resolve_outgame_ui('.大厅.layout.left.reward_group.reward_card_bg'),
        reward_title = resolve_outgame_ui('.大厅.layout.left.reward_group.reward_title'),
        reward_code = resolve_outgame_ui('.大厅.layout.left.reward_group.reward_code'),
        reward_hint = resolve_outgame_ui('.大厅.layout.left.reward_group.reward_hint'),
        page_container = page_container,
        stage_slots = stage_slots,
        stage_slot_container = stage_slot_container,
        start_button_bg = resolve_outgame_ui('.大厅.layout.start_bg') or start_button,
        start_button = start_button,
        start_anchor = resolve_outgame_ui('.大厅.layout.start_anchor') or resolve_outgame_ui('.大厅.layout.start_root') or nil,
        start_bound = false,
        save_entry = {
          root = resolve_outgame_ui('.大厅.layout.save_anchor.save_root'),
          line = resolve_outgame_ui('.大厅.layout.save_anchor.line'),
          title = resolve_outgame_ui('.大厅.layout.save_anchor.title'),
          status = resolve_outgame_ui('.大厅.layout.save_anchor.status'),
          button_bg = resolve_outgame_ui('.大厅.layout.save_anchor.button_bg'),
          button = resolve_outgame_ui('.大厅.layout.save_anchor.button'),
        },
        save_entry_bound = false,
        right_panel = resolve_outgame_ui('.大厅.layout.right'),
        difficulty_title = title,
        difficulty_hint = resolve_outgame_ui('.大厅.layout.right.difficulty_hint'),
        cultivation_note = tip,
        detail_title = resolve_outgame_ui('.大厅.layout.detail_title'),
        detail_status = resolve_outgame_ui('.大厅.layout.detail_status'),
        detail_hint = resolve_outgame_ui('.大厅.layout.detail_hint'),
        quit_tip = resolve_outgame_ui('.大厅.layout.quit_tip'),
        player_name = resolve_outgame_ui('.大厅.layout.footer.player_name'),
        player_slots = player_slots,
        save_anchor = resolve_outgame_ui('.大厅.layout.save_anchor'),
        top_entry_list_root = resolve_ui_first({ 'top.list', 'top.top.list' }),
        top_entry_items = {},
      }

      bind_ui_events(STATE.outgame_ui)
      refresh_top_entry_list_ui(STATE.outgame_ui)
      return STATE.outgame_ui
    end
    if not STATE.outgame_ui_bind_warned then
      STATE.outgame_ui_bind_warned = true
      message('outgame 静态画板节点不完整，请检查界面编辑器中的节点结构。')
    end
    return nil
  end

  local function refresh_mode_selectors(ui, profile, selected_stage_id, selected_mode_id)
    local selected_view_mode = get_selected_view_mode(profile)
    set_visible_if_alive(ui.mode_panel, true)
    for _, slot in ipairs(ui.mode_slots or {}) do
      local selected = slot.view_mode == selected_view_mode
      set_visible_if_alive(slot.root, true)
      set_text_if_alive(slot.label, slot.display_label)
      set_visible_if_alive(slot.selected, selected)
      set_image_color_if_alive(slot.bg, selected and { 255, 255, 255, 255 } or { 220, 228, 236, 235 })
    end
    return selected_view_mode
  end

  local function refresh_stage_slots(ui, profile, selected_stage_id)
    local selected_chapter_id = get_selected_chapter_id(selected_stage_id)
    local chapter_stages = get_chapter_stage_list(selected_chapter_id)
    for index, slot in ipairs(ui.stage_slots or {}) do
      local stage_def = chapter_stages[index]
      local progress = stage_def and get_stage_progress(profile, stage_def.stage_id) or nil
      local unlocked = progress and progress.standard_unlocked == true or false
      local cleared = progress and progress.standard_cleared == true or false
      local selected = stage_def and selected_stage_id == stage_def.stage_id or false
      slot.stage_def = stage_def
      set_visible_if_alive(slot.root, stage_def ~= nil)
      if stage_def then
        set_text_if_alive(slot.label, get_difficulty_display_text(stage_def, index))
        set_visible_if_alive(slot.selected, selected)
        if selected then
          set_image_color_if_alive(slot.bg, { 255, 255, 255, 255 })
          set_text_color_if_alive(slot.label, theme.palette.text)
        elseif not unlocked then
          set_image_color_if_alive(slot.bg, { 132, 132, 132, 228 })
          set_text_color_if_alive(slot.label, theme.palette.text_muted)
        elseif cleared then
          set_image_color_if_alive(slot.bg, { 226, 198, 122, 255 })
          set_text_color_if_alive(slot.label, { 38, 26, 0, 255 })
        else
          set_image_color_if_alive(slot.bg, { 214, 224, 236, 255 })
          set_text_color_if_alive(slot.label, { 255, 255, 255, 255 })
        end
      end
    end
    return selected_chapter_id
  end

  refresh_ui = function()
    local ui = ensure_ui()
    if not is_outgame_ui_alive(ui) then
      schedule_ui_retry()
      return
    end
    clear_ui_retry_timer()

    local profile = load_profile()
    local selected_stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local selected_mode_id = SINGLE_MODE_ID
    local selected_view_mode = get_selected_view_mode(profile)
    local selected_stage_def = STAGES_BY_ID[selected_stage_id]

    sync_outgame_backdrop(ui)
    set_visible_if_alive(ui.root, STATE.session_phase == 'outgame')
    set_visible_if_alive(ui.hall_root, STATE.session_phase == 'outgame')
    
    -- 确保这些面板始终可见（除非在非局外阶段）
    set_visible_if_alive(ui.left_panel, true)
    set_visible_if_alive(ui.right_panel, true)
    set_visible_if_alive(ui.mode_panel, false)
    
    refresh_save_entry_ui(ui, profile)
    local archive_ui = ensure_archive_panel_ui()
    if is_archive_panel_ui_alive(archive_ui) then
      refresh_archive_enter_panel_visible(archive_ui)
    end
    if STATE.archive_panel_visible == true then
      refresh_archive_panel_ui(profile)
    end

    -- 如果没有选择关卡，仍然刷新基本UI，只跳过依赖关卡的部分
    if not selected_stage_def then
      -- 仍然刷新不需要关卡的部分
      local top_title = "开始游戏"
      set_text_if_alive(ui.title, top_title)
      set_text_if_alive(ui.header_tip, "请选择关卡")
      set_text_if_alive(ui.quit_tip, '按 ESC 键可退出游戏')
      set_visible_if_alive(ui.tip_root, false)
      
      -- 隐藏难度选择器
      set_visible_if_alive(ui.stage_slot_container, false)
      
      -- 刷新其他面板
      set_text_if_alive(ui.difficulty_title, top_title)
      set_text_if_alive(ui.difficulty_hint, '请选择关卡')
      set_visible_if_alive(ui.cultivation_note, false)
      
      -- 刷新详情面板（使用默认值）
      set_visible_if_alive(ui.detail_title, true)
      set_visible_if_alive(ui.detail_status, false)
      set_visible_if_alive(ui.detail_hint, true)
      set_text_if_alive(ui.detail_title, "请选择关卡")
      set_text_if_alive(ui.detail_hint, "请选择关卡")
      
      refresh_reward_card(ui, profile, nil)
      refresh_footer(ui, profile)
      
      -- 禁用开始按钮
      ui.start_button:set_text('请选择关卡')
      ui.start_button:set_button_enable(false)
      set_image_color_if_alive(ui.start_button_bg, COLOR.start_locked_bg)
      set_text_color_if_alive(ui.start_button, COLOR.locked_text)
      
      return
    end

    if profile.selected_mode_id ~= SINGLE_MODE_ID then
      profile.selected_mode_id = SINGLE_MODE_ID
      mark_profile_dirty()
    end
    sync_selected_state(selected_stage_id, SINGLE_MODE_ID)

    local top_title = "开始游戏"
    set_text_if_alive(ui.title, top_title)
    set_text_if_alive(ui.header_tip, build_header_tip_text(profile, selected_stage_id, selected_mode_id))
    set_text_if_alive(ui.quit_tip, '按 ESC 键可退出游戏')
    set_visible_if_alive(ui.tip_root, false)

    set_text_if_alive(ui.difficulty_title, top_title)
    set_visible_if_alive(ui.stage_slot_container, false)
    set_visible_if_alive(ui.cultivation_note, false)
    set_text_if_alive(ui.difficulty_hint, '')

    local detail_title, detail_status, detail_hint = resolve_outgame_detail_texts(profile, selected_stage_id, selected_mode_id)
    set_visible_if_alive(ui.detail_title, true)
    set_visible_if_alive(ui.detail_status, detail_status ~= '')
    set_visible_if_alive(ui.detail_hint, true)
    set_text_if_alive(ui.detail_title, detail_title)
    set_text_if_alive(ui.detail_status, detail_status)
    set_text_if_alive(ui.detail_hint, detail_hint)
    refresh_reward_card(ui, profile, selected_stage_id)
    refresh_footer(ui, profile)

    local start_enabled = is_mode_unlocked(profile, selected_stage_id, selected_mode_id)
    if not start_enabled and selected_stage_id == get_first_stage_id() then
      start_enabled = true
    end
    ui.start_button:set_text(start_enabled and '开始游戏' or '未解锁')
    ui.start_button:set_button_enable(start_enabled)

    if start_enabled then
      set_image_color_if_alive(ui.start_button_bg, COLOR.start_ready_bg)
      set_text_color_if_alive(ui.start_button, COLOR.selected_text)
    else
      set_image_color_if_alive(ui.start_button_bg, COLOR.start_locked_bg)
      set_text_color_if_alive(ui.start_button, COLOR.locked_text)
    end
  end

  function api.load_profile()
    local profile = load_profile()
    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    return profile
  end

  function api.open_save_panel()
    local profile = load_profile()
    STATE.archive_panel_section = 'archive'
    STATE.archive_ranking_visible = false
    if STATE.archive_panel_visible == true then
      if refresh_archive_panel_ui then
        refresh_archive_panel_ui(profile)
      end
      return true
    end
    if not set_archive_panel_visible(true) then
      message(build_save_status_detail(profile))
      return false
    end
    if refresh_archive_panel_ui then
      refresh_archive_panel_ui(profile)
    end
    return true
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_ui()
    end
    refresh_ui()
    refresh_top_entry_list_ui(STATE.outgame_ui)
  end

  function api.set_ui_visible(visible)
    if visible ~= true and STATE.session_phase == 'outgame' then
      set_archive_panel_visible(false)
    end
    local archive_ui = STATE.archive_panel_ui
    if visible == true and not is_archive_panel_ui_alive(archive_ui) then
      archive_ui = ensure_archive_panel_ui()
    end
    if is_archive_panel_ui_alive(archive_ui) then
      refresh_archive_enter_panel_visible(archive_ui)
    end
    local ui = ensure_ui()
    set_non_outgame_ui_visible(visible ~= true)
    if not is_outgame_ui_alive(ui) then
      if visible == true then
        schedule_ui_retry()
      end
      if is_archive_panel_ui_alive(archive_ui) then
        refresh_archive_enter_panel_visible(archive_ui)
      end
      return
    end
    set_visible_if_alive(ui.root, visible == true)
    set_visible_if_alive(ui.hall_root, visible == true)
    refresh_top_entry_list_ui(ui)
    if is_archive_panel_ui_alive(archive_ui) then
      refresh_archive_enter_panel_visible(archive_ui)
    end
  end

  function api.enter_outgame(result)
    local profile = api.load_profile()
    if result then
      api.apply_battle_result(result)
      profile = load_profile()
    end

    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)

    STATE.session_phase = 'outgame'
    STATE.game_finished = true
    ui_retry_remaining = 12
    if ensure_music_loop then
      ensure_music_loop()
    end
    env.set_battle_hud_visible(false)
    set_non_outgame_ui_visible(false)
    ensure_ui()
    set_archive_panel_visible(false)
    refresh_ui()
    api.set_ui_visible(true)
  end

  function api.apply_battle_result(result)
    if not result then
      return nil
    end

    local profile = load_profile()
    local stage_id = result.stage_id or get_first_stage_id()
    local mode_id = SINGLE_MODE_ID
    local progress = get_stage_progress(profile, stage_id)
    if not progress then
      return nil
    end

    profile.last_result.stage_id = stage_id
    profile.last_result.mode_id = SINGLE_MODE_ID
    profile.last_result.is_win = result.is_win == true
    profile.last_result.reached_wave_index = math.max(0, result.reached_wave_index or 0)

    if result.is_win then
      progress.standard_cleared = true

      local next_stage_id = get_next_stage_id(stage_id)
      if next_stage_id then
        local next_progress = get_stage_progress(profile, next_stage_id)
        if next_progress then
          next_progress.standard_unlocked = true
        end
      end
    end

    rebuild_hero_attr_bonus_stats(profile)
    mark_profile_dirty()
    return nil
  end

  function api.start_selected_stage()
    local profile = load_profile()
    local stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local mode_id = SINGLE_MODE_ID

    local first_stage_id = get_first_stage_id()
    if stage_id == first_stage_id then
      local progress = get_stage_progress(profile, stage_id)
      if progress and progress.standard_unlocked ~= true then
        progress.standard_unlocked = true
        mark_profile_dirty()
      end
    end

    if not is_mode_unlocked(profile, stage_id, mode_id) then
      message(build_start_hint(profile, stage_id, mode_id))
      refresh_ui()
      return false
    end

    local ok = env.stage_runtime
      and env.stage_runtime.start_selected_stage
      and env.stage_runtime.start_selected_stage(stage_id, mode_id)
    if ok then
      set_non_outgame_ui_visible(true)
      api.set_ui_visible(false)
      return true
    end

    api.set_ui_visible(true)
    refresh_ui()
    return false
  end

  function api.get_selected_stage_def()
    return STAGES_BY_ID[STATE.selected_stage_id]
  end

  function api.get_selected_mode_def()
    return MODES_BY_ID[SINGLE_MODE_ID]
  end

  function api.is_mode_unlocked(stage_id, mode_id)
    if mode_id and mode_id ~= SINGLE_MODE_ID then
      return false
    end
    return is_mode_unlocked(load_profile(), stage_id, SINGLE_MODE_ID)
  end

  function api.get_profile()
    return load_profile()
  end

  function api.mark_profile_dirty()
    return mark_profile_dirty()
  end

  function api.get_hero_growth(hero_ref)
    local profile = load_profile()
    return hero_growth_api.get_growth_view(profile, hero_ref)
  end

  function api.get_all_hero_growth()
    local profile = load_profile()
    return hero_growth_api.get_growth_list(profile)
  end

  function api.add_hero_proficiency(hero_ref, amount)
    local profile = load_profile()
    local ok, msg, value = hero_growth_api.add_proficiency(profile, hero_ref, amount)
    if ok then
      mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  function api.get_awaken_stone()
    local profile = load_profile()
    return hero_growth_api.get_awaken_stone(profile)
  end

  function api.add_awaken_stone(amount)
    local profile = load_profile()
    local ok, msg, value = hero_growth_api.add_awaken_stone(profile, amount)
    if ok then
      mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  function api.try_hero_star_up(hero_ref)
    local profile = load_profile()
    local ok, msg, value = hero_growth_api.try_star_up(profile, hero_ref)
    if ok then
      mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  function api.try_hero_awaken(hero_ref)
    local profile = load_profile()
    local ok, msg, value = hero_growth_api.try_awaken(profile, hero_ref)
    if ok then
      mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  api.rebuild_hero_attr_bonus_stats = rebuild_hero_attr_bonus_stats

  _G.outgame_system = api
  return api
end

return M

