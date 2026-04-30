local theme = require 'ui.theme'
local outgame_defs = require 'ui.outgame_defs'
local QualityImageTable = require 'data.object_tables.quality_image_table'
local ArchiveShop = require 'ui.outgame_archive_shop'
local OutgameHeroGrowth = require 'runtime.outgame_hero_growth'

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
  local TALENT_COLUMNS = OUTGAME_DEFS.talent_columns or {}
  local TALENT_NODE_SPECS = OUTGAME_DEFS.talent_nodes or {}
  local TALENT_BY_KEY = OUTGAME_DEFS.talent_by_key or {}
  local HONOR_LEVEL_SPECS = OUTGAME_DEFS.honor_level_specs or {}
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
  local DAILY_TASK_DEFS = {
    {
      key = 'clear_any_1',
      title = '首次通关任意难度',
      reward = '奖励：天赋点+500',
      target = 1,
    },
    {
      key = 'clear_any_3',
      title = '通关3次任意难度',
      reward = '奖励：强化石+3',
      target = 3,
    },
    {
      key = 'online_60',
      title = '累计在线60分钟',
      reward = '奖励：木材+30',
      target = 60,
    },
    {
      key = 'online_120',
      title = '累计在线120分钟',
      reward = '奖励：泡点+300',
      target = 120,
    },
    {
      key = 'online_300',
      title = '累计在线300分钟',
      reward = '奖励：重铸石+3',
      target = 300,
    },
  }
  local COLOR = {
    selected_bg = { 84, 138, 226, 255 },
    selected_text = { 245, 248, 255, 255 },
    available_bg = { 40, 58, 92, 236 },
    available_text = { 220, 232, 246, 255 },
    locked_bg = { 34, 38, 48, 214 },
    locked_text = { 164, 172, 186, 255 },
    cleared_bg = { 58, 100, 82, 232 },
    cleared_text = { 232, 246, 238, 255 },
    start_ready_bg = { 82, 132, 96, 236 },
    start_locked_bg = { 58, 62, 72, 214 },
  }

  local api = {}
  local ensure_ui
  local refresh_ui
  local ensure_archive_panel_ui
  local refresh_archive_panel_ui
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
  local function resolve_ui(path)
    local ok, ui = pcall(y3.ui.get_ui, env.get_player(), path)
    if not ok or not ui then
      return nil
    end
    return ui
  end

  local function is_ui_alive(ui)
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

  local function set_non_outgame_ui_visible(visible)
    local base_paths = {
      'GameHUD',
      'top',
      'bottom_bg',
      'BattleBottomHUD',
    }
    local overlay_paths = {
      'BondChoice2',
      'BondChoice3',
      'BondChoice4',
      'BondSwallowPanel',
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
    if STATE.gm_bond_ui then
      set_visible_if_alive(STATE.gm_bond_ui.toggle_button, visible == true)
      set_visible_if_alive(STATE.gm_bond_ui.panel, visible == true and STATE.gm_bond_ui.visible == true)
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
    local chapter_id = select(1, parse_stage_id(stage_def.stage_id))
    chapter_id = chapter_id or 1
    if not STAGES_BY_CHAPTER[chapter_id] then
      STAGES_BY_CHAPTER[chapter_id] = {}
      CHAPTER_LIST[#CHAPTER_LIST + 1] = chapter_id
    end
    STAGES_BY_CHAPTER[chapter_id][#STAGES_BY_CHAPTER[chapter_id] + 1] = stage_def
    MAX_CHAPTER_DIFFICULTY_COUNT = math.max(MAX_CHAPTER_DIFFICULTY_COUNT, #STAGES_BY_CHAPTER[chapter_id])
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
          PAGE_BY_STAGE_ID[stage_def.stage_id] = page_def
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
    local archive_rewards = profile and profile.archive_rewards or nil
    local talents = archive_rewards and archive_rewards.talents or nil
    if type(talents) == 'table' then
      for _, spec in ipairs(TALENT_NODE_SPECS) do
        local level = math.max(0, math.floor(tonumber(talents[spec.key]) or 0))
        if level > 0 then
          local per_level = spec.attr_bonus_per_level or {}
          for attr_name, value in pairs(per_level) do
            local number = tonumber(value)
            if attr_name ~= nil and number ~= nil and number ~= 0 then
              rebuilt[attr_name] = (rebuilt[attr_name] or 0) + number * level
            end
          end
        end
      end
    end
    if are_same_bonus_stats(profile.hero_attr_bonus_stats, rebuilt) then
      return false
    end
    profile.hero_attr_bonus_stats = rebuilt
    return true
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
    if type(profile.daily_tasks) ~= 'table' then
      profile.daily_tasks = {}
      dirty = true
    end
    if type(profile.daily_tasks.progress) ~= 'table' then
      profile.daily_tasks.progress = {}
      dirty = true
    end
    if type(profile.archive_rewards) ~= 'table' then
      profile.archive_rewards = {}
      dirty = true
    end
    if math.type(profile.archive_rewards.pool_score) ~= 'integer' then
      profile.archive_rewards.pool_score = 0
      dirty = true
    end
    if math.type(profile.archive_rewards.pool_draw_count) ~= 'integer' then
      profile.archive_rewards.pool_draw_count = 0
      dirty = true
    end
    if type(profile.archive_rewards.pool_items) ~= 'table' then
      profile.archive_rewards.pool_items = {}
      dirty = true
    end
    if type(profile.archive_rewards.claimed_universal) ~= 'table' then
      profile.archive_rewards.claimed_universal = {}
      dirty = true
    end
    if type(profile.archive_rewards.honor_levels) ~= 'table' then
      profile.archive_rewards.honor_levels = {}
      dirty = true
    end
    for _, spec in ipairs(HONOR_LEVEL_SPECS) do
      if spec.key and profile.archive_rewards.honor_levels[spec.key] == nil then
        profile.archive_rewards.honor_levels[spec.key] = spec.initial_unlocked == true
        dirty = true
      end
    end
    if math.type(profile.archive_rewards.talent_points) ~= 'integer' then
      profile.archive_rewards.talent_points = 0
      dirty = true
    end
    if type(profile.archive_rewards.talents) ~= 'table' then
      profile.archive_rewards.talents = {}
      dirty = true
    end
    if hero_growth_api and hero_growth_api.ensure_profile_defaults and hero_growth_api.ensure_profile_defaults(profile) then
      dirty = true
    end
    for _, task_def in ipairs(DAILY_TASK_DEFS) do
      if profile.daily_tasks.progress[task_def.key] == nil then
        profile.daily_tasks.progress[task_def.key] = 0
        dirty = true
      end
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

  local function load_profile()
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
    return string.format('N%d', difficulty_index or fallback_index or 1)
  end

  local function get_page_display_text(page_def)
    local difficulty_index = page_def and tonumber(page_def.chapter_page_index) or 1
    return string.format('N%d', difficulty_index or 1)
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

  local function get_daily_task_value(profile, task_def)
    local daily_tasks = profile and profile.daily_tasks or nil
    local progress = daily_tasks and daily_tasks.progress or nil
    if type(progress) == 'table' and progress[task_def.key] ~= nil then
      return math.max(0, tonumber(progress[task_def.key]) or 0)
    end

    return 0
  end

  local function build_daily_task_rows(profile, selected_stage_id)
    local rows = {}
    for _, task_def in ipairs(DAILY_TASK_DEFS) do
      local value = math.min(get_daily_task_value(profile, task_def), task_def.target)
      local completed = value >= task_def.target
      rows[#rows + 1] = {
        title = task_def.title,
        reward = task_def.reward,
        progress = string.format('(%d/%d)', value, task_def.target),
        status = completed and '完成' or '',
      }
    end
    return rows
  end

  local function refresh_daily_rows(ui, profile, selected_stage_id)
    local rows = build_daily_task_rows(profile, selected_stage_id)
    for index, row_ui in ipairs(ui.daily_rows or {}) do
      local row = rows[index]
      set_visible_if_alive(row_ui.root, row ~= nil)
      if row then
        set_text_if_alive(row_ui.title, row.title)
        set_text_if_alive(row_ui.reward, row.reward)
        set_text_if_alive(row_ui.progress, row.progress)
        set_text_if_alive(row_ui.status, row.status)
        set_visible_if_alive(row_ui.status_bg, row.status ~= '')
        set_visible_if_alive(row_ui.status, row.status ~= '')

        local status_bg = COLOR.available_bg
        local status_text = COLOR.available_text
        if row.status == '完成' or row.status == '已满' or row.status == '已通关' or row.status == '已记录' then
          status_bg = COLOR.cleared_bg
          status_text = COLOR.cleared_text
        elseif row.status == '未解锁' or row.status == '待开始' then
          status_bg = COLOR.locked_bg
          status_text = COLOR.locked_text
        end
        set_image_color_if_alive(row_ui.bg, theme.palette.panel)
        set_image_color_if_alive(row_ui.status_bg, status_bg)
        set_text_color_if_alive(row_ui.status, status_text)
      end
    end
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

  local function is_outgame_ui_alive(ui)
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

  local function bind_ui_events(ui)
    for _, slot in ipairs(ui.mode_slots or {}) do
      bind_mode_slot(slot)
    end
    for _, slot in ipairs(ui.stage_slots or {}) do
      bind_stage_slot(slot)
    end

    bind_save_entry(ui)

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

  local ARCHIVE_UNIVERSAL_ITEM_SPECS = OUTGAME_DEFS.archive_universal_item_specs or {}
  local ARCHIVE_SHOP_OPTIONS = {
    state = STATE,
    player = env.get_player and env.get_player() or nil,
    specs = OUTGAME_DEFS.archive_shop_item_specs or {},
    primary_tabs = OUTGAME_DEFS.archive_shop_primary_tabs or { OUTGAME_DEFS.archive_shop_primary_tab or '地图商城' },
    primary_tab_label = OUTGAME_DEFS.archive_shop_primary_tab or '地图商城',
    categories = OUTGAME_DEFS.archive_shop_categories or {},
    categories_by_primary = OUTGAME_DEFS.archive_shop_categories_by_primary or {},
    default_icon = OUTGAME_DEFS.archive_shop_default_icon or 906565,
    play_ui_click = play_ui_click,
  }

  local function is_archive_panel_ui_alive(ui)
    return ui
      and is_ui_alive(ui.root)
      and is_ui_alive(ui.overlay)
      and is_ui_alive(ui.window)
      and is_ui_alive(ui.close_button)
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
    return ArchiveShop.refresh(ui, ARCHIVE_SHOP_OPTIONS)
  end

  local function ensure_archive_main_shop_ui(ui)
    ARCHIVE_SHOP_OPTIONS.player = env.get_player and env.get_player() or ARCHIVE_SHOP_OPTIONS.player
    return ArchiveShop.ensure(ui, ARCHIVE_SHOP_OPTIONS)
  end

  local function to_non_negative_integer(value)
    local number = tonumber(value) or 0
    return math.max(0, math.floor(number))
  end

  function get_archive_player()
    return env.get_player and env.get_player() or nil
  end

  local function get_archive_player_integer(method_name)
    local player = get_archive_player()
    local method = player and player[method_name] or nil
    if type(method) ~= 'function' then
      return 0
    end
    local ok, value = pcall(method, player)
    if not ok then
      return 0
    end
    return to_non_negative_integer(value)
  end

  local function get_archive_total_lottery_count()
    local player = get_archive_player()
    local handle = player and player.handle or nil
    local method = handle and handle.api_get_number_of_all_lottery or nil
    if type(method) ~= 'function' then
      return 0
    end
    local ok, value = pcall(method, handle)
    if not ok then
      return 0
    end
    return to_non_negative_integer(value)
  end

  local get_archive_clear_counts

  local function get_archive_rewards(profile)
    profile = profile or load_profile()
    if type(profile.archive_rewards) ~= 'table' then
      profile.archive_rewards = {
        pool_score = 0,
        pool_draw_count = 0,
        pool_items = {},
        claimed_universal = {},
      }
    end
    if math.type(profile.archive_rewards.pool_score) ~= 'integer' then
      profile.archive_rewards.pool_score = to_non_negative_integer(profile.archive_rewards.pool_score)
    end
    if math.type(profile.archive_rewards.pool_draw_count) ~= 'integer' then
      profile.archive_rewards.pool_draw_count = to_non_negative_integer(profile.archive_rewards.pool_draw_count)
    end
    if type(profile.archive_rewards.pool_items) ~= 'table' then
      profile.archive_rewards.pool_items = {}
    end
    if type(profile.archive_rewards.claimed_universal) ~= 'table' then
      profile.archive_rewards.claimed_universal = {}
    end
    if type(profile.archive_rewards.honor_levels) ~= 'table' then
      profile.archive_rewards.honor_levels = {}
    end
    for _, spec in ipairs(HONOR_LEVEL_SPECS) do
      if spec.key and profile.archive_rewards.honor_levels[spec.key] == nil then
        profile.archive_rewards.honor_levels[spec.key] = spec.initial_unlocked == true
      end
    end
    profile.archive_rewards.talent_points = to_non_negative_integer(profile.archive_rewards.talent_points)
    if type(profile.archive_rewards.talents) ~= 'table' then
      profile.archive_rewards.talents = {}
    end
    return profile.archive_rewards
  end

  local function get_archive_pool_score(profile)
    return to_non_negative_integer(get_archive_rewards(profile).pool_score)
  end

  local function get_archive_pool_draw_count(profile)
    return to_non_negative_integer(get_archive_rewards(profile).pool_draw_count)
  end

  local function add_archive_pool_draw_reward(profile, draw_count)
    draw_count = math.max(1, to_non_negative_integer(draw_count or 1))
    local rewards = get_archive_rewards(profile)
    rewards.pool_draw_count = get_archive_pool_draw_count(profile) + draw_count
    rewards.pool_score = get_archive_pool_score(profile) + draw_count * 10
    return rewards.pool_score, rewards.pool_draw_count
  end

  local function get_archive_pool_item_count(profile, item_key)
    local rewards = get_archive_rewards(profile)
    return to_non_negative_integer(rewards.pool_items and rewards.pool_items[item_key] or 0)
  end

  local function get_archive_pool_item_key(spec)
    return tostring((spec and (spec.item_key or spec.id or spec.node)) or '')
  end

  local function get_archive_pool_item_icon(spec)
    if not spec then
      return nil
    end
    if spec.icon ~= nil and spec.icon ~= '' then
      return spec.icon
    end
    local item_key = spec.item_key or spec.id
    if item_key and y3 and y3.item and y3.item.get_icon_id_by_key then
      local ok, icon = pcall(y3.item.get_icon_id_by_key, item_key)
      if ok and icon ~= nil and icon ~= 0 then
        return icon
      end
    end
    return nil
  end

  local function get_archive_universal_item_icon(spec)
    if not spec then
      return nil
    end
    if spec.icon ~= nil and spec.icon ~= '' then
      return spec.icon
    end
    return nil
  end

  local function get_archive_universal_frame_image(spec)
    if not spec then
      return nil
    end
    return QualityImageTable.get_frame_image(spec.quality)
  end

  local function add_archive_pool_item(profile, item_key, count)
    local rewards = get_archive_rewards(profile)
    rewards.pool_items[item_key] = get_archive_pool_item_count(profile, item_key) + math.max(1, to_non_negative_integer(count or 1))
    return rewards.pool_items[item_key]
  end

  local function spend_archive_pool_score(profile, amount)
    amount = math.max(0, to_non_negative_integer(amount))
    local rewards = get_archive_rewards(profile)
    local current = get_archive_pool_score(profile)
    if current < amount then
      return false, current
    end
    rewards.pool_score = current - amount
    return true, rewards.pool_score
  end

  local function get_archive_talent_points(profile)
    return to_non_negative_integer(get_archive_rewards(profile).talent_points)
  end

  local function add_archive_talent_points(profile, amount)
    amount = to_non_negative_integer(amount)
    local rewards = get_archive_rewards(profile)
    if amount > 0 then
      rewards.talent_points = get_archive_talent_points(profile) + amount
    end
    return rewards.talent_points
  end

  local function spend_archive_talent_points(profile, amount)
    amount = math.max(0, to_non_negative_integer(amount))
    local rewards = get_archive_rewards(profile)
    local current = get_archive_talent_points(profile)
    if current < amount then
      return false, current
    end
    rewards.talent_points = current - amount
    return true, rewards.talent_points
  end

  local function get_archive_talent_level(profile, talent_key)
    local rewards = get_archive_rewards(profile)
    return to_non_negative_integer(rewards.talents and rewards.talents[talent_key] or 0)
  end

  local function is_archive_honor_level_unlocked(profile, spec)
    if not spec or not spec.key then
      return false
    end
    local rewards = get_archive_rewards(profile)
    return rewards.honor_levels and rewards.honor_levels[spec.key] == true or false
  end

  local function get_archive_talent_column_points(profile, column_key)
    local total = 0
    for _, spec in ipairs(TALENT_NODE_SPECS) do
      if spec.column == column_key then
        total = total + get_archive_talent_level(profile, spec.key)
      end
    end
    return total
  end

  local function is_archive_talent_unlocked(profile, spec)
    return spec ~= nil and get_archive_talent_column_points(profile, spec.column) >= (spec.require_points or 0)
  end

  local function get_archive_talent_status_text(profile, spec)
    if not spec then
      return '请选择一个天赋'
    end
    local level = get_archive_talent_level(profile, spec.key)
    if level >= (spec.max_level or 1) then
      return '已满级'
    end
    if not is_archive_talent_unlocked(profile, spec) then
      local column = TALENT_COLUMNS[spec.column]
      return string.format('未解锁：%s投入 %d 点', column and column.title or '本系', spec.require_points or 0)
    end
    return string.format('升级消耗 %d 天赋点', spec.cost or 1)
  end

  local function upgrade_archive_talent(profile, talent_key)
    profile = profile or load_profile()
    local spec = TALENT_BY_KEY[talent_key]
    if not spec then
      return false, '未找到该天赋。'
    end
    local level = get_archive_talent_level(profile, talent_key)
    if level >= (spec.max_level or 1) then
      return false, string.format('%s 已达到最高等级。', spec.title)
    end
    if not is_archive_talent_unlocked(profile, spec) then
      local column = TALENT_COLUMNS[spec.column]
      return false, string.format('%s尚未解锁：需要%s投入 %d 点。', spec.title, column and column.title or '本系', spec.require_points or 0)
    end
    local ok, remain = spend_archive_talent_points(profile, spec.cost or 1)
    if not ok then
      return false, string.format('天赋点不足：当前 %d，需要 %d。', remain or 0, spec.cost or 1)
    end
    local rewards = get_archive_rewards(profile)
    rewards.talents[spec.key] = level + 1
    rebuild_hero_attr_bonus_stats(profile)
    mark_profile_dirty()
    return true, string.format('%s 已升至 %d/%d。', spec.title, level + 1, spec.max_level or 1)
  end

  local function get_archive_universal_claim_key(tab_key, spec)
    if not spec or not spec.node then
      return nil
    end
    return tostring(tab_key or 'unknown') .. ':' .. tostring(spec.node)
  end

  local function get_archive_universal_reward_state(profile, tab_key, spec)
    if not spec then
      return nil
    end

    local node = tostring(spec.node or '')
    local clear_counts, total_clear_count = get_archive_clear_counts(profile)
    local current, target, reward_score = 0, 1, 0
    local condition_text = nil

    if spec.source == 'honor_level' then
      return nil
    elseif tab_key == 'pass' then
      local difficulty = tonumber(node:match('pass_badge_(%d+)')) or 1
      current = clear_counts[difficulty] or 0
      reward_score = 40 + difficulty * 10
      condition_text = string.format('难度 %d 通关 %d/%d', difficulty, current, target)
    elseif tab_key == 'map' then
      local level = tonumber(node:match('map_badge_(%d+)')) or 1
      current = get_archive_player_integer('get_map_level')
      target = level
      reward_score = 10 + level * 5
      condition_text = string.format('地图等级 %d/%d', current, target)
    elseif tab_key == 'achievement' then
      local index = tonumber(node:match('achievement_badge_(%d+)')) or 1
      current = index == 3 and get_archive_pool_draw_count(profile) or total_clear_count
      target = index == 1 and 1 or (index == 2 and 3 or (index == 3 and 10 or math.max(1, index)))
      reward_score = index == 1 and 80 or (index == 2 and 120 or (index == 3 and 100 or 60 + index * 10))
      local label = index == 3 and '累计夺宝' or '累计通关'
      condition_text = string.format('%s %d/%d', label, current, target)
    elseif tab_key == 'lottery' then
      local index = tonumber(node:match('lottery_badge_(%d+)')) or 1
      current = math.max(get_archive_total_lottery_count(), get_archive_pool_draw_count(profile))
      target = math.max(1, index)
      reward_score = 20 + index * 10
      condition_text = string.format('累计抽奖 %d/%d', current, target)
    else
      return nil
    end

    local rewards = get_archive_rewards(profile)
    local claim_key = get_archive_universal_claim_key(tab_key, spec)
    local claimed = rewards.claimed_universal and rewards.claimed_universal[claim_key] == true
    return {
      key = claim_key,
      current = current,
      target = target,
      reward_score = reward_score,
      condition_text = condition_text,
      can_claim = current >= target and not claimed,
      claimed = claimed,
    }
  end

  local function format_archive_universal_reward_status(profile, tab_key, spec)
    if spec and spec.source == 'honor_level' then
      local obtain = spec.obtain and spec.obtain ~= '' and spec.obtain or '查看荣誉等级达成条件'
      return string.format('存档：未拥有 · %s', obtain)
    end
    local state = get_archive_universal_reward_state(profile, tab_key, spec)
    if not state then
      return '状态：预览条目'
    end
    if state.claimed then
      return string.format('状态：已领取 · %s', state.condition_text)
    end
    if state.can_claim then
      return string.format('状态：可领取 · %s · 奖励 %d 积分', state.condition_text, state.reward_score)
    end
    return string.format('状态：未达成 · %s · 奖励 %d 积分', state.condition_text, state.reward_score)
  end

  local function format_honor_effect_line(line)
    local attr_name, value_text = tostring(line or ''):match('^%s*(.-)%s+%+(.-)%s*$')
    if attr_name and attr_name ~= '' and value_text and value_text ~= '' then
      return string.format('+%s%s', value_text, attr_name)
    end
    return tostring(line or '')
  end

  local function ensure_honor_detail_text(detail, key, x, y, width, height, font_size, color, align_h)
    if not detail or not is_ui_alive(detail.root) then
      return nil
    end
    detail.honor_dynamic = detail.honor_dynamic or {}
    local text = detail.honor_dynamic[key]
    if not is_ui_alive(text) and detail.root.create_child then
      local ok, created = pcall(detail.root.create_child, detail.root, '文本')
      if ok and is_ui_alive(created) then
        text = created
        detail.honor_dynamic[key] = text
      end
    end
    if not is_ui_alive(text) then
      return nil
    end
    set_visible_if_alive(text, true)
    set_ui_size_if_alive(text, width, height)
    if text.set_pos then
      text:set_pos(x, y)
    end
    set_font_size_if_alive(text, font_size)
    set_text_color_if_alive(text, color)
    set_text_alignment_if_alive(text, align_h or '左', '中')
    set_z_order_if_alive(text, 540)
    return text
  end

  local function set_honor_detail_dynamic_visible(detail, visible)
    if not detail or not detail.honor_dynamic then
      return
    end
    for _, text in pairs(detail.honor_dynamic) do
      set_visible_if_alive(text, visible == true)
    end
  end

  local function refresh_archive_honor_detail(detail, profile, spec)
    local attr_lines = spec.attr_lines or {}
    local effect_1 = format_honor_effect_line(attr_lines[1] or spec.line_1 or '')
    local effect_2 = format_honor_effect_line(attr_lines[2] or spec.line_2 or '')
    local obtain = spec.obtain and spec.obtain ~= '' and spec.obtain or '查看荣誉等级达成条件'

    set_text_if_alive(detail.title, spec.title)
    set_text_color_if_alive(detail.title, { 255, 232, 44, 255 })
    set_font_size_if_alive(detail.title, 19)
    set_text_alignment_if_alive(detail.title, '中', '中')

    set_visible_if_alive(detail.line_1, false)
    set_visible_if_alive(detail.line_2, false)
    set_visible_if_alive(detail.line_3, false)

    set_text_if_alive(ensure_honor_detail_text(detail, 'owned', 107, 286, 185, 22, 14, { 162, 166, 178, 255 }, '中'), '未拥有')
    set_text_if_alive(ensure_honor_detail_text(detail, 'effect_title', 12, 252, 185, 22, 14, { 255, 232, 44, 255 }), '[详情效果]')
    set_text_if_alive(ensure_honor_detail_text(detail, 'effect_1', 12, 224, 185, 22, 15, { 44, 255, 112, 255 }), effect_1)
    set_text_if_alive(ensure_honor_detail_text(detail, 'effect_2', 12, 198, 185, 22, 15, { 44, 255, 112, 255 }), effect_2)
    set_text_if_alive(ensure_honor_detail_text(detail, 'obtain_title', 12, 164, 185, 22, 14, { 255, 232, 44, 255 }), '[获取方式]')
    set_text_if_alive(ensure_honor_detail_text(detail, 'obtain', 12, 130, 185, 40, 14, { 178, 183, 194, 255 }), obtain)
    return true
  end

  local function claim_archive_universal_reward(profile, tab_key, spec)
    profile = profile or load_profile()
    local state = get_archive_universal_reward_state(profile, tab_key, spec)
    if not state then
      return false, '该条目暂无可领取奖励。'
    end
    if state.claimed then
      return false, '该奖励已领取。'
    end
    if not state.can_claim then
      return false, string.format('领取条件未达成：%s。', state.condition_text)
    end
    local rewards = get_archive_rewards(profile)
    rewards.claimed_universal[state.key] = true
    rewards.pool_score = get_archive_pool_score(profile) + state.reward_score
    mark_profile_dirty()
    return true, string.format('已领取 %s，获得 %d 夺宝积分。', spec.title or '通用奖励', state.reward_score)
  end

  local function get_archive_save_state_text(compact)
    if STATE.outgame_profile_save_enabled == true then
      if compact then
        return '云端'
      end
      return string.format('槽位 %d · 云端已连接', SAVE_SLOT)
    end
    if compact then
      return '内存态'
    end
    return string.format('槽位 %d · 内存态', SAVE_SLOT)
  end

  function get_archive_clear_counts(profile)
    local counts = {}
    local total = 0
    for _, stage_def in ipairs(STAGE_LIST) do
      local progress = get_stage_progress(profile, stage_def.stage_id)
      if progress and progress.standard_cleared == true then
        local difficulty_index = select(2, parse_stage_id(stage_def.stage_id)) or 1
        counts[difficulty_index] = (counts[difficulty_index] or 0) + 1
        total = total + 1
      end
    end
    return counts, total
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

    local archive_main_root = resolve_ui('ArchiveMain')
    local archive_main_overlay = resolve_ui('ArchiveMain.layout_1')
    local archive_main_close = resolve_ui('ArchiveMain.layout_1.exit')
    if is_ui_alive(archive_main_root) and is_ui_alive(archive_main_overlay) and is_ui_alive(archive_main_close) then
      local ui = {
        variant = 'archive_main_v2',
        root = archive_main_root,
        overlay = archive_main_overlay,
        window = archive_main_overlay,
        close_button = archive_main_close,
        close_chip = {
          root = archive_main_close,
          bg = archive_main_close,
        },
        enter_panel_root = resolve_ui('EnterPanel'),
        enter_panel_icon = resolve_ui('EnterPanel.YangChengIcon'),
        enter_panel_bg = resolve_ui('EnterPanel.YangChengIcon.bg'),
        enter_panel_name = resolve_ui('EnterPanel.YangChengIcon.name'),
        enter_panel_bound = false,
        bound = false,
      }
      STATE.archive_panel_ui = ui
      ensure_archive_main_shop_ui(ui)
      bind_archive_panel_events(ui)
      refresh_archive_enter_panel_visible(ui)
      return ui
    end

    if not STATE.archive_panel_ui_warned then
      STATE.archive_panel_ui_warned = true
      message('未找到 ArchiveMain/EnterPanel 节点，请先热更新版存档 UI 后再测试。')
    end
    return nil
  end


  refresh_archive_enter_panel_visible = function(ui)
    if not is_archive_panel_ui_alive(ui) then
      return
    end
    local visible = STATE.session_phase == 'outgame' and STATE.archive_panel_visible ~= true
    set_visible_if_alive(ui.enter_panel_root, visible)
    set_visible_if_alive(ui.enter_panel_icon, visible)
  end

  local function set_archive_panel_visible(visible)
    visible = visible == true
    local ui = ensure_archive_panel_ui()
    if visible then
      if not is_archive_panel_ui_alive(ui) then
        return false
      end
      if STATE.archive_panel_hidden_non_outgame ~= true then
        set_non_outgame_ui_visible(false)
        STATE.archive_panel_hidden_non_outgame = true
      end
      set_visible_if_alive(ui.root, true)
      set_visible_if_alive(ui.overlay, true)
      set_visible_if_alive(ui.window, true)
      STATE.archive_panel_visible = true
      refresh_archive_enter_panel_visible(ui)
      return true
    end

    if STATE.archive_panel_hidden_non_outgame == true then
      set_non_outgame_ui_visible(STATE.session_phase ~= 'outgame')
      STATE.archive_panel_hidden_non_outgame = false
    end
    if is_archive_panel_ui_alive(ui) then
      set_visible_if_alive(ui.root, false)
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
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_visible(false)
      end)
    end
  end

  refresh_archive_panel_ui = function(profile)
    local ui = ensure_archive_panel_ui()
    if not is_archive_panel_ui_alive(ui) then
      return false
    end
    set_visible_if_alive(ui.root, STATE.archive_panel_visible == true)
    set_visible_if_alive(ui.overlay, STATE.archive_panel_visible == true)
    set_visible_if_alive(ui.window, STATE.archive_panel_visible == true)
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
      return STATE.outgame_ui
    end

    local root = resolve_ui('outgame')
    local hall_root = resolve_ui('outgame.大厅')
    local backdrop = resolve_ui('outgame.大厅.layout.底板')
    local title = resolve_ui('outgame.大厅.layout.right.mode_name')
    local tip_root = resolve_ui('outgame.大厅.layout.right.mode_name.猎场模式tips')
    local tip = resolve_ui('outgame.大厅.layout.right.mode_name.猎场模式tips.layout_2.label_3')
    local page_container = resolve_ui('outgame.大厅.layout.right.难度列表')
    local mode_panel = resolve_ui('outgame.大厅.layout.left_2')
    local stage_slot_container = resolve_ui('outgame.大厅.layout.right_2.list')
    local start_button = resolve_ui('outgame.大厅.layout.start')

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
      local mainline_slot = build_static_mode_slot('outgame.大厅.layout.left_2.list.主线模式', VIEW_MODE_MAINLINE, '正常模式')
      local cultivation_slot = build_static_mode_slot('outgame.大厅.layout.left_2.list.猎场模式', VIEW_MODE_CULTIVATION, '猎场模式')
      if mainline_slot then
        mode_slots[#mode_slots + 1] = mainline_slot
      end
      if cultivation_slot then
        mode_slots[#mode_slots + 1] = cultivation_slot
      end

      local stage_slots = {}
      for index = 1, STAGE_PAGE_SIZE do
        local slot_name = string.format('mode%d', index)
        local slot = build_static_stage_slot('outgame.大厅.layout.right_2.list.' .. slot_name)
        if slot then
          stage_slots[#stage_slots + 1] = slot
        end
      end

      local daily_rows = {}
      for index = 1, 5 do
        local base_path = string.format('outgame.大厅.layout.left.task_%d', index)
        local row_root = resolve_ui(base_path)
        if is_ui_alive(row_root) then
          daily_rows[#daily_rows + 1] = {
            root = row_root,
            bg = resolve_ui(base_path .. '.bg'),
            title = resolve_ui(base_path .. '.title'),
            reward = resolve_ui(base_path .. '.reward'),
            progress = resolve_ui(base_path .. '.progress'),
            status_bg = resolve_ui(base_path .. '.status_bg'),
            status = resolve_ui(base_path .. '.status'),
          }
        end
      end

      local player_slots = {}
      for index = 1, 4 do
        local base_path = string.format('outgame.大厅.layout.footer.slot_%d', index)
        local slot_root = resolve_ui(base_path)
        if is_ui_alive(slot_root) then
          player_slots[#player_slots + 1] = {
            root = slot_root,
            bg = resolve_ui(base_path .. '.frame') or slot_root,
            inner = resolve_ui(base_path .. '.inner'),
            avatar = resolve_ui(base_path .. '.avatar'),
            label = resolve_ui(base_path .. '.label'),
            avatar_key = nil,
          }
        end
      end

      STATE.outgame_ui = {
        root = root,
        hall_root = hall_root,
        backdrop = backdrop,
        title = title,
        header_tip = resolve_ui('outgame.大厅.layout.header_tip'),
        tip_root = tip_root,
        tip = tip,
        mode_panel = mode_panel,
        mode_slots = mode_slots,
        left_panel = resolve_ui('outgame.大厅.layout.left'),
        left_title = resolve_ui('outgame.大厅.layout.left.task_title'),
        left_rule = resolve_ui('outgame.大厅.layout.left.task_line'),
        daily_rows = daily_rows,
        reward_card = resolve_ui('outgame.大厅.layout.left.reward_group.reward_card_bg'),
        reward_title = resolve_ui('outgame.大厅.layout.left.reward_group.reward_title'),
        reward_code = resolve_ui('outgame.大厅.layout.left.reward_group.reward_code'),
        reward_hint = resolve_ui('outgame.大厅.layout.left.reward_group.reward_hint'),
        page_container = page_container,
        stage_slots = stage_slots,
        stage_slot_container = stage_slot_container,
        start_button_bg = resolve_ui('outgame.大厅.layout.start_bg') or start_button,
        start_button = start_button,
        start_anchor = resolve_ui('outgame.大厅.layout.start_anchor') or resolve_ui('outgame.大厅.layout.start_root') or nil,
        start_bound = false,
        save_entry = {
          root = resolve_ui('outgame.大厅.layout.save_anchor.save_root'),
          line = resolve_ui('outgame.大厅.layout.save_anchor.line'),
          title = resolve_ui('outgame.大厅.layout.save_anchor.title'),
          status = resolve_ui('outgame.大厅.layout.save_anchor.status'),
          button_bg = resolve_ui('outgame.大厅.layout.save_anchor.button_bg'),
          button = resolve_ui('outgame.大厅.layout.save_anchor.button'),
        },
        save_entry_bound = false,
        right_panel = resolve_ui('outgame.大厅.layout.right'),
        difficulty_title = title,
        difficulty_hint = resolve_ui('outgame.大厅.layout.right.difficulty_hint'),
        cultivation_note = tip,
        detail_title = resolve_ui('outgame.大厅.layout.detail_title'),
        detail_status = resolve_ui('outgame.大厅.layout.detail_status'),
        detail_hint = resolve_ui('outgame.大厅.layout.detail_hint'),
        quit_tip = resolve_ui('outgame.大厅.layout.quit_tip'),
        player_name = resolve_ui('outgame.大厅.layout.footer.player_name'),
        player_slots = player_slots,
        save_anchor = resolve_ui('outgame.大厅.layout.save_anchor'),
      }

      bind_ui_events(STATE.outgame_ui)
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
    refresh_save_entry_ui(ui, profile)
    local archive_ui = ensure_archive_panel_ui()
    if is_archive_panel_ui_alive(archive_ui) then
      refresh_archive_enter_panel_visible(archive_ui)
    end
    if STATE.archive_panel_visible == true then
      refresh_archive_panel_ui(profile)
    end

    if not selected_stage_def then
      return
    end

    if profile.selected_mode_id ~= SINGLE_MODE_ID then
      profile.selected_mode_id = SINGLE_MODE_ID
      mark_profile_dirty()
    end
    sync_selected_state(selected_stage_id, SINGLE_MODE_ID)

    local is_cultivation_mode = selected_view_mode == VIEW_MODE_CULTIVATION

    set_text_if_alive(ui.title, is_cultivation_mode and '打鱼模式' or '正常模式')
    set_text_if_alive(ui.header_tip, build_header_tip_text(profile, selected_stage_id, selected_mode_id))
    set_text_if_alive(ui.quit_tip, '按 ESC 键可退出游戏')
    set_visible_if_alive(ui.tip_root, is_cultivation_mode)
    if is_cultivation_mode then
      set_text_if_alive(ui.tip, '当前模式为挂机模式')
    end

    refresh_mode_selectors(ui, profile, selected_stage_id, selected_mode_id)
    refresh_stage_slots(ui, profile, selected_stage_id)
    set_text_if_alive(ui.difficulty_title, is_cultivation_mode and '打鱼模式' or '正常模式')
    set_visible_if_alive(ui.stage_slot_container, not is_cultivation_mode)
    for _, slot in ipairs(ui.stage_slots or {}) do
      set_visible_if_alive(slot.root, not is_cultivation_mode and slot.stage_def ~= nil)
    end
    set_visible_if_alive(ui.cultivation_note, is_cultivation_mode)
    set_text_if_alive(ui.difficulty_hint, is_cultivation_mode and '' or '选择难度后即可开始游戏')

    set_visible_if_alive(ui.detail_title, not is_cultivation_mode)
    set_visible_if_alive(ui.detail_status, not is_cultivation_mode)
    set_visible_if_alive(ui.detail_hint, true)
    set_text_if_alive(ui.detail_title, is_cultivation_mode and '' or get_stage_display_text(selected_stage_def, selected_stage_id))
    set_text_if_alive(ui.detail_status, is_cultivation_mode and '' or get_stage_status_text(profile, selected_stage_def))
    set_text_if_alive(ui.detail_hint, build_start_hint(profile, selected_stage_id, selected_mode_id))
    set_text_if_alive(ui.left_title, '每日任务（周末双倍）')
    set_text_if_alive(ui.left_rule, '（每日任务获得的资源，不计算每日上限）')
    refresh_daily_rows(ui, profile, selected_stage_id)
    refresh_reward_card(ui, profile, selected_stage_id)
    refresh_footer(ui, profile)

    local start_enabled = not is_cultivation_mode and is_mode_unlocked(profile, selected_stage_id, selected_mode_id)
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
    if STATE.archive_panel_visible == true then
      return true
    end
    if not refresh_archive_panel_ui(profile) then
      message(build_save_status_detail(profile))
      return false
    end
    set_archive_panel_visible(true)
    return true
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_ui()
    end
    refresh_ui()
  end

  function api.set_ui_visible(visible)
    if visible ~= true then
      set_archive_panel_visible(false)
    end
    local archive_ui = ensure_archive_panel_ui()
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

    local was_standard_cleared = progress.standard_cleared == true
    if result.is_win then
      progress.standard_cleared = true
      if not was_standard_cleared then
        add_archive_talent_points(profile, 1)
      end

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

  function api.debug_get_archive_talent_points()
    return get_archive_talent_points(load_profile())
  end

  function api.debug_get_archive_talent_level(talent_key)
    return get_archive_talent_level(load_profile(), talent_key)
  end

  function api.debug_upgrade_archive_talent(talent_key)
    local ok, msg = upgrade_archive_talent(load_profile(), talent_key)
    return ok, msg
  end

  function api.debug_claim_archive_universal_reward(tab_key, node)
    local specs = ARCHIVE_UNIVERSAL_ITEM_SPECS[tab_key]
    local selected_spec = nil
    for _, spec in ipairs(specs or {}) do
      if spec.node == node then
        selected_spec = spec
        break
      end
    end
    return claim_archive_universal_reward(load_profile(), tab_key, selected_spec)
  end

  api.rebuild_hero_attr_bonus_stats = rebuild_hero_attr_bonus_stats

  return api
end

return M
