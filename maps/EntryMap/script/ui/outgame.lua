local theme = require 'ui.theme'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local play_ui_click = env.play_ui_click
  local ensure_music_loop = env.ensure_music_loop

  local STAGE_LIST = CONFIG.stages and CONFIG.stages.list or {}
  local STAGES_BY_ID = CONFIG.stages and CONFIG.stages.by_id or {}
  local MODES_BY_ID = CONFIG.stage_modes and CONFIG.stage_modes.by_id or {}
  local SAVE_SLOT = CONFIG.save_slots and CONFIG.save_slots.outgame_profile or 1
  local OUTGAME_ATTR_BONUS_BY_STAGE_MODE = CONFIG.outgame_attr_bonus_config
    and CONFIG.outgame_attr_bonus_config.by_stage_mode
    or {}
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
      reward = '奖励：宝物精华+30',
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

  local function set_text_color_if_alive(ui, color)
    if is_ui_alive(ui) and ui.set_text_color and color then
      ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
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
    local hidden_paths = {
      'GameHUD',
      'top',
      'bottom_bg',
      'BattleBottomHUD',
      'panel_1',
      'CommonTip',
      'SceneUI',
    }
    for _, path in ipairs(hidden_paths) do
      local ui = resolve_ui(path)
      set_visible_if_alive(ui, visible == true)
    end

    if STATE.gm_ui then
      set_visible_if_alive(STATE.gm_ui.panel, visible == true)
      set_visible_if_alive(STATE.gm_ui.toggle_button, visible == true)
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
    if not progress then
      return false
    end
    if mode_id == SINGLE_MODE_ID then
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
    local is_first_stage = stage_id == get_first_stage_id()
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

    if is_ui_alive(ui.start_button) and ui.start_bound ~= true then
      ui.start_bound = true
      ui.start_button:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        api.start_selected_stage()
      end)
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

  local ARCHIVE_PAGE_KEYS = { 'profile', 'equipment', 'talent', 'universal', 'chest', 'pool' }
  local ARCHIVE_PAGE_PANEL_NAMES = {
    profile = 'ArchivePageProfile',
    equipment = 'ArchivePageEquipment',
    talent = 'ArchivePageTalent',
    universal = 'ArchivePageUniversal',
    chest = 'ArchivePageChest',
    pool = 'ArchivePagePool',
  }
  local ARCHIVE_MENU_SPECS = {
    { key = 'profile', page_key = 'profile' },
    { key = 'universal', page_key = 'universal' },
    { key = 'chest', page_key = 'chest' },
    { key = 'club', page_key = nil },
    { key = 'talent', page_key = 'talent' },
    { key = 'equipment', page_key = 'equipment' },
    { key = 'hero', page_key = nil },
    { key = 'beast', page_key = nil },
    { key = 'skin', page_key = nil },
    { key = 'shop', page_key = nil },
    { key = 'heirloom', page_key = nil },
  }
  local ARCHIVE_UNIVERSAL_KEYS = { 'pass', 'map', 'community', 'achievement', 'lottery', 'test', 'fish' }
  local ARCHIVE_UNIVERSAL_ITEM_SPECS = {
    pass = {
      { node = 'pass_badge_1', title = '难度 1 通关奖励', line_1 = '累计通关可领取夺宝券。', line_2 = '当前用于查看通关奖励进度。', line_3 = '点击其它难度可切换详情。' },
      { node = 'pass_badge_2', title = '难度 2 通关奖励', line_1 = '奖励随难度逐步提高。', line_2 = '通关后写入存档进度。', line_3 = '可作为赛季成长目标。' },
      { node = 'pass_badge_3', title = '难度 3 通关奖励', line_1 = '展示更高难度通关次数。', line_2 = '用于核对夺宝券来源。', line_3 = '当前为存档预览条目。' },
      { node = 'pass_badge_4', title = '难度 4 通关奖励', line_1 = '后续可接入实际领取状态。', line_2 = '列表点击会刷新右侧详情。', line_3 = '未达成时显示为预览。' },
      { node = 'pass_badge_5', title = '难度 5 通关奖励', line_1 = '高难度通关累计目标。', line_2 = '奖励内容可由配置表驱动。', line_3 = '适合展示阶段性奖励。' },
    },
    map = {
      { node = 'map_badge_1', title = '地图等级 1', line_1 = '地图等级提供基础成长奖励。', line_2 = '已接入列表点击详情。', line_3 = '后续可显示当前等级进度。' },
      { node = 'map_badge_2', title = '地图等级 2', line_1 = '提升地图等级解锁更多收益。', line_2 = '条目以列表形式展示。', line_3 = '点击可查看奖励说明。' },
      { node = 'map_badge_3', title = '地图等级 3', line_1 = '可放置等级礼包或属性。', line_2 = '未领取状态可继续扩展。', line_3 = '当前作为可点示例。' },
    },
    community = {
      { node = 'community_badge_1', title = '收藏奖励', line_1 = '社区行为奖励入口。', line_2 = '可展示收藏/关注状态。', line_3 = '点击条目查看详情。' },
      { node = 'community_badge_2', title = '分享奖励', line_1 = '分享活动奖励预览。', line_2 = '后续可接入活动存档。', line_3 = '当前为交互示例。' },
      { node = 'community_badge_3', title = '社群礼包', line_1 = '社群兑换类奖励。', line_2 = '适合显示礼包码状态。', line_3 = '点击会刷新右侧说明。' },
    },
    achievement = {
      { node = 'achievement_badge_1', title = '生涯首胜', line_1 = '首次通关任意难度。', line_2 = '达成后可领取成就奖励。', line_3 = '点击查看成就条件。' },
      { node = 'achievement_badge_2', title = '连胜挑战', line_1 = '连续胜利累计目标。', line_2 = '可用于长期目标展示。', line_3 = '当前显示预览数据。' },
      { node = 'achievement_badge_3', title = '资源大师', line_1 = '累计获得资源类成就。', line_2 = '后续可接入统计字段。', line_3 = '点击后切换详情。' },
    },
    lottery = {
      { node = 'lottery_badge_1', title = '幸运戒', line_1 = '群抽奖奖励池物品。', line_2 = '可通过口令或抽奖获得。', line_3 = '点击查看奖励说明。' },
      { node = 'lottery_badge_2', title = '强化石', line_1 = '常规抽奖材料。', line_2 = '用于装备或天赋成长。', line_3 = '当前展示为列表条目。' },
      { node = 'lottery_badge_3', title = '夺宝券', line_1 = '用于进入夺宝奖池。', line_2 = '通关和活动均可产出。', line_3 = '点击后刷新右侧详情。' },
    },
    test = {
      { node = 'test_badge_1', title = '测试礼包 A', line_1 = '测试大厅调试条目。', line_2 = '用于验证点击与详情刷新。', line_3 = '正式版可替换为活动奖励。' },
      { node = 'test_badge_2', title = '测试礼包 B', line_1 = '保留给调试流程。', line_2 = '不影响正式存档字段。', line_3 = '点击可确认交互可用。' },
    },
    fish = {
      { node = 'fish_feature_1', title = '小丑鱼图鉴', line_1 = '捕鱼模式图鉴条目。', line_2 = '可展示捕获次数与奖励。', line_3 = '点击切换右侧详情。' },
      { node = 'fish_feature_2', title = '海龟图鉴', line_1 = '稀有鱼类图鉴预览。', line_2 = '适合展示捕获条件。', line_3 = '后续可接入存档计数。' },
      { node = 'fish_feature_3', title = '宝箱鱼图鉴', line_1 = '特殊收益鱼类。', line_2 = '可展示掉落奖励。', line_3 = '当前为可点击示例。' },
    },
  }

  local function append_archive_generated_specs(target, prefix, start_index, end_index, title_prefix, line_1, line_2, line_3)
    for index = start_index, end_index do
      target[#target + 1] = {
        node = string.format('%s_%d', prefix, index),
        title = string.format('%s %d', title_prefix, index),
        line_1 = line_1,
        line_2 = line_2,
        line_3 = line_3,
      }
    end
  end

  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.pass, 'pass_badge', 6, 10, '难度', '更高难度通关奖励。', '滚动列表中的可点击条目。', '后续可接入实际领取状态。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.map, 'map_badge', 4, 21, '地图等级', '地图等级阶段奖励。', '可展示等级达成与领取状态。', '当前作为图鉴列表预览。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.community, 'community_badge', 4, 14, '社区福利', '社区活动奖励条目。', '可接入收藏、关注、分享等状态。', '点击后刷新右侧详情。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.achievement, 'achievement_badge', 4, 14, '成就', '长期目标成就条目。', '可显示达成进度与奖励。', '点击后查看成就条件。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.lottery, 'lottery_badge', 4, 14, '群抽奖', '群抽奖奖励条目。', '可展示口令与抽奖产出。', '点击后刷新奖励说明。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.test, 'test_badge', 3, 8, '测试礼包', '测试大厅奖励条目。', '用于验证滚动网格点击。', '正式版可替换为活动奖励。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.fish, 'fish_feature', 4, 5, '捕鱼图鉴', '捕鱼模式功能条目。', '可展示捕获次数与收益。', '点击后查看图鉴详情。')
  append_archive_generated_specs(ARCHIVE_UNIVERSAL_ITEM_SPECS.fish, 'fish_rarity', 1, 3, '鱼类品质', '鱼类品质分类。', '用于划分捕鱼图鉴奖励。', '点击后查看该品质说明。')
  for row_index, count in ipairs({ 6, 7, 4 }) do
    for index = 1, count do
      ARCHIVE_UNIVERSAL_ITEM_SPECS.fish[#ARCHIVE_UNIVERSAL_ITEM_SPECS.fish + 1] = {
        node = string.format('fish_badge_%d_%d', row_index, index),
        title = string.format('鱼类图鉴 %d-%d', row_index, index),
        line_1 = '捕鱼模式图鉴条目。',
        line_2 = '可接入捕获次数和奖励状态。',
        line_3 = '滚动列表中的可点击鱼类。',
      }
    end
  end

  local ARCHIVE_POOL_ITEM_SPECS = {
    { node = 'item_east', title = '东', glyph = '东', icon = 106330, cost = 100, line_1 = '+0.5% 攻击加成', line_2 = '数量可无限拥有，属性生效上限为地图等级。' },
    { node = 'item_south', title = '南', glyph = '南', icon = 106331, cost = 100, line_1 = '+0.5% 生命加成', line_2 = '适合前期提高容错。' },
    { node = 'item_west', title = '西', glyph = '西', icon = 106364, cost = 100, line_1 = '+0.5% 攻速加成', line_2 = '适合依赖普攻的阵容。' },
    { node = 'item_north', title = '北', glyph = '北', icon = 106379, cost = 100, line_1 = '+0.5% 防御加成', line_2 = '提高单位承伤能力。' },
    { node = 'item_mid', title = '中', glyph = '中', icon = 106380, cost = 120, line_1 = '+0.5% 全属性加成', line_2 = '稀有通用成长物品。' },
    { node = 'item_fa', title = '发', glyph = '发', icon = 106381, cost = 80, line_1 = '+1 初始金币', line_2 = '经济型奖池物品。' },
    { node = 'item_sugar', title = '糖', glyph = '糖', icon = 106382, cost = 80, line_1 = '+1% 回复效果', line_2 = '提高续航能力。' },
    { node = 'item_pop', title = '爆', glyph = '爆', icon = 106383, cost = 120, line_1 = '+1% 暴击伤害', line_2 = '爆发流派奖励。' },
    { node = 'item_meat', title = '肉', glyph = '肉', icon = 106384, cost = 80, line_1 = '+10 最大生命', line_2 = '稳健型基础奖励。' },
  }

  local ARCHIVE_POOL_EXTRA_ITEMS = {
    { 'item_blank', '空位', '□' }, { 'item_food_n', '鸡腿饭', '饭' }, { 'item_spear', '长矛', '矛' }, { 'item_scroll', '卷轴', '卷' },
    { 'item_ball', '紫球', '球' }, { 'item_wine', '符酒', '酒' }, { 'item_mail', '信封', '信' },
    { 'item_doll', '娃娃', '娃' }, { 'item_pie', '甜点', '饼' }, { 'item_spade', '黑桃A', '♠' },
    { 'item_heart', '红心A', '♥' }, { 'item_diamond', '方片A', '♦' }, { 'item_club', '梅花A', '♣' },
    { 'item_gun', '手枪', '枪' }, { 'item_shield', '护符', '盾' }, { 'item_fist', '拳套', '拳' },
    { 'item_food', '炒饭', '饭' }, { 'item_mushroom', '蘑菇', '菇' }, { 'item_bell', '铃铛', '铃' },
    { 'item_horn', '喇叭', '喇' }, { 'item_crab', '螃蟹', '蟹' }, { 'item_brick', '金砖', '砖' },
    { 'item_mace', '狼牙锤', '刺' }, { 'item_moon', '月牙', '月' }, { 'item_sea', '海宝', '海' },
    { 'item_branch', '金枝', '枝' }, { 'item_hat', '草帽', '帽' }, { 'item_scale', '龙鳞', '鳞' },
    { 'item_glove', '拳甲', '拳' }, { 'item_ring', '金环', '环' }, { 'item_fire', '异火', '火' },
    { 'item_lamp', '魂灯', '灯' }, { 'item_seal', '玉印', '印' }, { 'item_armor', '古铠', '铠' },
    { 'item_fruit', '灵果', '灵' },
  }
  for index, item in ipairs(ARCHIVE_POOL_EXTRA_ITEMS) do
    ARCHIVE_POOL_ITEM_SPECS[#ARCHIVE_POOL_ITEM_SPECS + 1] = {
      node = item[1],
      title = item[2],
      glyph = item[3],
      icon = 106384 + index,
      cost = 100 + (index % 5) * 20,
      line_1 = '奖池图鉴物品。',
      line_2 = '当前已接入列表点击与详情预览。',
    }
  end

  local function get_archive_page_root_path(page_key)
    local panel_name = ARCHIVE_PAGE_PANEL_NAMES[page_key]
    if not panel_name then
      return nil
    end
    return panel_name .. '.root'
  end

  local function get_archive_page_path(page_key)
    local root_path = get_archive_page_root_path(page_key)
    if not root_path then
      return nil
    end
    return root_path .. '.content.page_' .. page_key
  end

  local function get_archive_page_content_path(page_key)
    local root_path = get_archive_page_root_path(page_key)
    if not root_path then
      return nil
    end
    return root_path .. '.content'
  end

  local function is_archive_panel_ui_alive(ui)
    if not (
      ui
      and is_ui_alive(ui.root)
      and is_ui_alive(ui.overlay)
      and is_ui_alive(ui.window)
      and is_ui_alive(ui.close_button)
    ) then
      return false
    end
    for _, page_key in ipairs(ARCHIVE_PAGE_KEYS) do
      if not is_ui_alive(ui.pages and ui.pages[page_key]) then
        return false
      end
    end
    return true
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

  local function bind_archive_demo_click(path, text)
    local root = resolve_ui(path)
    if not is_ui_alive(root) or not root.add_fast_event then
      return false
    end
    if root.set_intercepts_operations then
      root:set_intercepts_operations(true)
    end
    root:add_fast_event('左键-按下', function()
      if play_ui_click then
        play_ui_click()
      end
      message(text)
    end)
    return true
  end

  local function to_non_negative_integer(value)
    local number = tonumber(value) or 0
    return math.max(0, math.floor(number))
  end

  local function get_archive_player()
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

  local function get_archive_clear_counts(profile)
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

  local function refresh_archive_menu_chip(entry, selected)
    local chip = entry and entry.chip or nil
    local enabled = entry and entry.page_key ~= nil
    if not chip then
      return
    end
    set_visible_if_alive(chip.active, selected == true)
    if enabled ~= true then
      set_image_color_if_alive(chip.bg, { 58, 60, 70, 220 })
      set_text_color_if_alive(chip.label, { 134, 139, 150, 255 })
      return
    end
    set_image_color_if_alive(chip.bg, selected and { 104, 110, 126, 244 } or { 212, 54, 42, 244 })
    set_text_color_if_alive(chip.label, selected and { 255, 247, 232, 255 } or { 255, 238, 226, 255 })
  end

  local function refresh_archive_tab_chip(chip, selected)
    if not chip then
      return
    end
    set_visible_if_alive(chip.active, selected == true)
    set_image_color_if_alive(chip.bg, selected and { 183, 137, 48, 244 } or { 64, 68, 80, 230 })
    set_text_color_if_alive(chip.label, selected and { 255, 247, 232, 255 } or { 218, 222, 232, 255 })
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

  local function configure_archive_page_shells(ui)
    if not ui then
      return
    end
    for _, page_key in ipairs(ARCHIVE_PAGE_KEYS) do
      set_intercepts_if_alive(ui.page_roots and ui.page_roots[page_key], false)
      set_intercepts_if_alive(ui.page_contents and ui.page_contents[page_key], false)
    end
  end

  ensure_archive_panel_ui = function()
    if is_archive_panel_ui_alive(STATE.archive_panel_ui) then
      bind_archive_panel_events(STATE.archive_panel_ui)
      return STATE.archive_panel_ui
    end

    local root = resolve_ui('ArchivePanel')
    local overlay = resolve_ui('ArchivePanel.root.overlay')
    local window = resolve_ui('ArchivePanel.root.overlay.window')
    local close_chip = resolve_archive_chip('ArchivePanel.root.overlay.window.close_button')
    if not (is_ui_alive(root) and is_ui_alive(overlay) and is_ui_alive(window) and close_chip) then
      if not STATE.archive_panel_ui_warned then
        STATE.archive_panel_ui_warned = true
        message('未找到 ArchivePanel 主壳静态画板，请重新载入地图后再测试存档界面。')
      end
      return nil
    end

    local profile_page_path = get_archive_page_path('profile')
    local chest_page_path = get_archive_page_path('chest')
    local universal_page_path = get_archive_page_path('universal')
    local pool_page_path = get_archive_page_path('pool')

    local ui = {
      root = root,
      overlay = overlay,
      dim = resolve_ui('ArchivePanel.root.overlay.dim'),
      window = window,
      close_button = close_chip.root,
      close_chip = close_chip,
      save_status_value = resolve_ui('ArchivePanel.root.overlay.window.save_status_card.save_status_value'),
      pages = {},
      page_roots = {},
      page_contents = {},
      menu_entries = {},
      tab_entries = {},
      universal_bodies = {},
      universal_grids = {},
      universal_details = {},
      universal_items = {},
      profile = {
        player_name = resolve_ui(profile_page_path .. '.info_card.player_name_value'),
        map_level = resolve_ui(profile_page_path .. '.info_card.map_level_value'),
        pass_value = resolve_ui(profile_page_path .. '.info_card.pass_row.pass_value'),
        sign_value = resolve_ui(profile_page_path .. '.info_card.sign_row.sign_value'),
        save_state_value = resolve_ui(profile_page_path .. '.info_card.save_state_row.save_state_value'),
        count_values = {},
      },
      chest = {
        ticket_value = resolve_ui(chest_page_path .. '.reward_card.ticket_row.value'),
        score_value = resolve_ui(chest_page_path .. '.reward_card.score_row.value'),
        count_value = resolve_ui(chest_page_path .. '.reward_card.count_row.value'),
        pool_entry = resolve_archive_chip(chest_page_path .. '.chest_card.pool_entry', 'button_bg'),
        prob_entry = resolve_archive_chip(chest_page_path .. '.chest_card.prob_entry', 'button_bg'),
      },
      pool = {
        back_button = resolve_archive_chip(pool_page_path .. '.pool_card.back_button'),
        board = resolve_ui(pool_page_path .. '.pool_card.pool_board') or resolve_ui(pool_page_path .. '.pool_card'),
        items = {},
        selected_nodes = {},
        detail = {
          icon = resolve_ui(pool_page_path .. '.detail_card.big_item_icon'),
          glyph = resolve_ui(pool_page_path .. '.detail_card.big_item_glyph'),
          name = resolve_ui(pool_page_path .. '.detail_card.item_name'),
          owned = resolve_ui(pool_page_path .. '.detail_card.item_owned'),
          attr_line_1 = resolve_ui(pool_page_path .. '.detail_card.attr_line_1'),
          attr_line_2 = resolve_ui(pool_page_path .. '.detail_card.attr_line_2'),
          score_text = resolve_ui(pool_page_path .. '.detail_card.score_text'),
          cost_text = resolve_ui(pool_page_path .. '.detail_card.cost_text'),
          exchange_button = resolve_archive_chip(pool_page_path .. '.detail_card.exchange_button'),
        },
      },
      bound = false,
    }

    for _, page_key in ipairs(ARCHIVE_PAGE_KEYS) do
      local page_root_path = get_archive_page_root_path(page_key)
      local page_content_path = get_archive_page_content_path(page_key)
      ui.page_roots[page_key] = page_root_path and resolve_ui(page_root_path) or nil
      ui.page_contents[page_key] = page_content_path and resolve_ui(page_content_path) or nil
      ui.pages[page_key] = page_root_path and resolve_ui(page_root_path) or nil
    end

    for _, entry in ipairs(ARCHIVE_MENU_SPECS) do
      ui.menu_entries[#ui.menu_entries + 1] = {
        key = entry.key,
        page_key = entry.page_key,
        chip = resolve_archive_chip('ArchivePanel.root.overlay.window.sidebar.menu_' .. entry.key),
      }
    end

    for _, tab_key in ipairs(ARCHIVE_UNIVERSAL_KEYS) do
      ui.tab_entries[#ui.tab_entries + 1] = {
        key = tab_key,
        chip = resolve_archive_chip(universal_page_path .. '.main_card.tab_' .. tab_key),
      }
      ui.universal_bodies[tab_key] = resolve_ui(universal_page_path .. '.main_card.body_' .. tab_key)
      ui.universal_grids[tab_key] = ui.universal_bodies[tab_key]
      ui.universal_details[tab_key] = resolve_ui(universal_page_path .. '.detail_card.detail_' .. tab_key)
    end

    for tab_key, specs in pairs(ARCHIVE_UNIVERSAL_ITEM_SPECS) do
      ui.universal_items[tab_key] = {}
      for _, spec in ipairs(specs) do
        ui.universal_items[tab_key][#ui.universal_items[tab_key] + 1] = {
          spec = spec,
          root = resolve_ui(string.format('%s.main_card.body_%s.%s', universal_page_path, tab_key, spec.node)),
        }
      end
    end

    for _, spec in ipairs(ARCHIVE_POOL_ITEM_SPECS) do
      ui.pool.items[#ui.pool.items + 1] = {
        spec = spec,
        root = resolve_ui(pool_page_path .. '.pool_card.pool_board.' .. spec.node) or resolve_ui(pool_page_path .. '.pool_card.' .. spec.node),
        icon = resolve_ui(pool_page_path .. '.pool_card.pool_board.' .. spec.node .. '.icon_image') or resolve_ui(pool_page_path .. '.pool_card.' .. spec.node .. '.icon_image'),
        glyph = resolve_ui(pool_page_path .. '.pool_card.pool_board.' .. spec.node .. '.glyph') or resolve_ui(pool_page_path .. '.pool_card.' .. spec.node .. '.glyph'),
      }
      ui.pool.selected_nodes[spec.node] = resolve_ui(pool_page_path .. '.pool_card.pool_board.' .. spec.node .. '.selected') or resolve_ui(pool_page_path .. '.pool_card.' .. spec.node .. '.selected')
    end

    for index = 1, 10 do
      ui.profile.count_values[index] = resolve_ui(string.format(
        '%s.count_card.count_row_%d.count_value_%d',
        profile_page_path,
        index,
        index
      ))
    end

    if not is_archive_panel_ui_alive(ui) then
      if not STATE.archive_panel_ui_warned then
        STATE.archive_panel_ui_warned = true
        message('未找到 ArchivePage 分页静态画板，请重新载入地图后再测试存档界面。')
      end
      return nil
    end

    STATE.archive_panel_ui = ui
    configure_archive_page_shells(ui)
    configure_archive_grid_views(ui)
    bind_archive_panel_events(ui)
    return ui
  end

  local function get_archive_main_page_key(page_key)
    if page_key == 'pool' then
      return 'chest'
    end
    return page_key
  end

  local function set_archive_panel_page(page_key)
    local ui = ensure_archive_panel_ui()
    if not is_archive_panel_ui_alive(ui) then
      return false
    end
    if not ui.pages[page_key] then
      page_key = 'profile'
    end
    STATE.archive_panel_page = page_key
    for key, page in pairs(ui.pages) do
      set_visible_if_alive(page, STATE.archive_panel_visible == true and key == page_key)
    end
    local main_page_key = get_archive_main_page_key(page_key)
    for _, entry in ipairs(ui.menu_entries or {}) do
      refresh_archive_menu_chip(entry, entry.page_key == main_page_key)
    end
    return true
  end

  local function set_archive_universal_tab(tab_key)
    local ui = ensure_archive_panel_ui()
    if not is_archive_panel_ui_alive(ui) then
      return false
    end
    if not ui.universal_bodies[tab_key] then
      tab_key = 'pass'
    end
    STATE.archive_panel_universal_tab = tab_key
    for _, entry in ipairs(ui.tab_entries or {}) do
      local selected = entry.key == tab_key
      refresh_archive_tab_chip(entry.chip, selected)
      set_visible_if_alive(ui.universal_bodies[entry.key], selected)
      set_visible_if_alive(ui.universal_details[entry.key], selected)
    end
    return true
  end

  local function refresh_archive_universal_detail(ui, tab_key, spec)
    if not ui or not spec then
      return false
    end
    local detail = ui.universal_details and ui.universal_details[tab_key]
    if not is_ui_alive(detail) then
      return false
    end
    set_text_if_alive(resolve_ui(string.format('ArchivePageUniversal.root.content.page_universal.detail_card.detail_%s.title', tab_key)), spec.title)
    set_text_if_alive(resolve_ui(string.format('ArchivePageUniversal.root.content.page_universal.detail_card.detail_%s.line_1', tab_key)), spec.line_1)
    set_text_if_alive(resolve_ui(string.format('ArchivePageUniversal.root.content.page_universal.detail_card.detail_%s.line_2', tab_key)), spec.line_2)
    set_text_if_alive(resolve_ui(string.format('ArchivePageUniversal.root.content.page_universal.detail_card.detail_%s.line_3', tab_key)), spec.line_3)
    return true
  end

  local function refresh_archive_pool_detail(ui, spec)
    if not ui or not ui.pool or not spec then
      return false
    end
    STATE.archive_panel_pool_item = spec.node
    local profile = STATE.outgame_profile or load_profile()
    local owned_count = get_archive_pool_item_count(profile, spec.node)
    local pool_score = get_archive_pool_score(profile)
    for _, entry in ipairs(ui.pool.items or {}) do
      local entry_spec = entry.spec or {}
      set_visible_if_alive(entry.icon, entry_spec.icon ~= nil)
      set_visible_if_alive(entry.glyph, entry_spec.icon == nil)
      set_image_if_alive(entry.icon, entry_spec.icon)
      set_text_if_alive(entry.glyph, entry_spec.glyph or entry_spec.title)
    end
    for node_name, selected_node in pairs(ui.pool.selected_nodes or {}) do
      set_visible_if_alive(selected_node, node_name == spec.node)
    end
    local detail = ui.pool.detail or {}
    set_visible_if_alive(detail.icon, spec.icon ~= nil)
    set_visible_if_alive(detail.glyph, spec.icon == nil)
    set_image_if_alive(detail.icon, spec.icon)
    set_text_if_alive(detail.glyph, spec.glyph or spec.title)
    set_text_if_alive(detail.name, spec.title)
    set_text_if_alive(detail.owned, owned_count > 0 and string.format('已拥有 ×%d', owned_count) or '未拥有')
    set_text_if_alive(detail.attr_line_1, spec.line_1)
    set_text_if_alive(detail.attr_line_2, spec.line_2)
    set_text_if_alive(detail.score_text, string.format('夺宝积分：%d', pool_score))
    set_text_if_alive(detail.cost_text, string.format('兑换需要 %d 积分', spec.cost or 100))
    return true
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
      STATE.archive_panel_visible = true
      set_archive_panel_page('profile')
      return true
    end

    if STATE.archive_panel_hidden_non_outgame == true then
      set_non_outgame_ui_visible(STATE.session_phase ~= 'outgame')
      STATE.archive_panel_hidden_non_outgame = false
    end
    if is_archive_panel_ui_alive(ui) then
      set_visible_if_alive(ui.overlay, false)
      for _, page in pairs(ui.pages or {}) do
        set_visible_if_alive(page, false)
      end
    end
    STATE.archive_panel_visible = false
    return true
  end

  local function configure_grid_view(ui, column_count, row_count, cell_width, cell_height, row_space, col_space, scroll)
    if not is_ui_alive(ui) or not ui.set_ui_gridview_count then
      return false
    end
    if ui.clear_ui_comp_image then
      ui:clear_ui_comp_image()
    end
    set_image_color_if_alive(ui, { 255, 255, 255, 0 })
    if ui.set_ui_gridview_type then
      ui:set_ui_gridview_type(0)
    end
    ui:set_ui_gridview_count(column_count, row_count)
    if ui.set_ui_gridview_size then
      ui:set_ui_gridview_size(cell_width, cell_height)
    end
    if ui.set_ui_gridview_margin then
      ui:set_ui_gridview_margin(0, 0, 0, 0)
    end
    if ui.set_ui_gridview_space then
      ui:set_ui_gridview_space(row_space or 0, col_space or 0)
    end
    if ui.set_ui_gridview_align then
      ui:set_ui_gridview_align(0)
    end
    if ui.set_ui_gridview_scroll then
      ui:set_ui_gridview_scroll(scroll == true)
    end
    if ui.set_ui_gridview_size_adaptive then
      ui:set_ui_gridview_size_adaptive(false)
    end
    return true
  end

  local function configure_archive_grid_views(ui)
    if not ui then
      return
    end
    configure_grid_view(ui.universal_grids and ui.universal_grids.pass, 8, 2, 78, 78, 20, 16, true)
    configure_grid_view(ui.universal_grids and ui.universal_grids.map, 8, 4, 78, 78, 20, 16, true)
    configure_grid_view(ui.universal_grids and ui.universal_grids.community, 8, 3, 78, 78, 20, 16, true)
    configure_grid_view(ui.universal_grids and ui.universal_grids.achievement, 8, 3, 78, 78, 20, 16, true)
    configure_grid_view(ui.universal_grids and ui.universal_grids.lottery, 8, 3, 78, 78, 20, 16, true)
    configure_grid_view(ui.universal_grids and ui.universal_grids.test, 8, 2, 78, 78, 20, 16, true)
    configure_grid_view(ui.universal_grids and ui.universal_grids.fish, 8, 5, 78, 78, 20, 16, true)
    configure_grid_view(ui.pool and ui.pool.board, 8, 4, 64, 64, 14, 18, true)
  end

  local function bind_archive_demo_interactions()
    local universal_page_path = get_archive_page_path('universal')
    local pool_page_path = get_archive_page_path('pool')
    local profile_page_path = get_archive_page_path('profile')
    local chest_page_path = get_archive_page_path('chest')
    local talent_page_path = get_archive_page_path('talent')
    local equipment_page_path = get_archive_page_path('equipment')

    bind_archive_demo_click(profile_page_path .. '.info_card', '我的信息：查看玩家等级、通关和存档状态')
    bind_archive_demo_click(profile_page_path .. '.count_card', '通关次数：点击后可用于查看各难度累计次数')
    bind_archive_demo_click(profile_page_path .. '.limit_card', '每日上限：这里展示今日资源获取限制')

    bind_archive_demo_click(chest_page_path .. '.chest_card.mode_tab_1', '夺宝宝箱：已切换到夺宝奇兵示例')
    bind_archive_demo_click(chest_page_path .. '.chest_card.stage', '夺宝宝箱：点击宝箱可预览抽奖反馈')
    bind_archive_demo_click(talent_page_path .. '.talent_layout.output_column.node_1', '天赋页：强击节点，可查看升级消耗和效果')
    bind_archive_demo_click(talent_page_path .. '.talent_layout.survival_column.node_1', '天赋页：护体节点，可查看升级消耗和效果')
    bind_archive_demo_click(talent_page_path .. '.talent_layout.resource_column.node_1', '天赋页：富矿节点，可查看升级消耗和效果')
    bind_archive_demo_click(equipment_page_path .. '.equipment_card.slot_head', '神装：头部装备槽预览')
    bind_archive_demo_click(equipment_page_path .. '.bag_card.bag_slot_1', '神装：背包装备预览')
  end

  bind_archive_panel_events = function(ui)
    if not is_archive_panel_ui_alive(ui) or ui.bound == true then
      return
    end
    ui.bound = true

    if is_ui_alive(ui.dim) then
      ui.dim:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_visible(false)
      end)
    end

    local close_button_target = get_archive_chip_click_target(ui.close_chip)
    if is_ui_alive(close_button_target) then
      close_button_target:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_visible(false)
      end)
    end

    for _, entry in ipairs(ui.menu_entries or {}) do
      local page_key = entry.page_key
      local click_target = get_archive_chip_click_target(entry.chip)
      if page_key and is_ui_alive(click_target) then
        click_target:add_fast_event('左键-按下', function()
          if play_ui_click then
            play_ui_click()
          end
          set_archive_panel_page(page_key)
        end)
      end
    end

    for _, entry in ipairs(ui.tab_entries or {}) do
      local tab_key = entry.key
      local click_target = get_archive_chip_click_target(entry.chip)
      if is_ui_alive(click_target) then
        click_target:add_fast_event('左键-按下', function()
          if play_ui_click then
            play_ui_click()
          end
          set_archive_universal_tab(tab_key)
          local entries = ui.universal_items and ui.universal_items[tab_key]
          if entries and entries[1] then
            refresh_archive_universal_detail(ui, tab_key, entries[1].spec)
          end
        end)
      end
    end

    for tab_key, entries in pairs(ui.universal_items or {}) do
      for _, entry in ipairs(entries) do
        if is_ui_alive(entry.root) then
          set_intercepts_if_alive(entry.root, true)
          entry.root:add_fast_event('左键-按下', function()
            if play_ui_click then
              play_ui_click()
            end
            set_archive_universal_tab(tab_key)
            refresh_archive_universal_detail(ui, tab_key, entry.spec)
          end)
        end
      end
    end

    for _, entry in ipairs(ui.pool.items or {}) do
      if is_ui_alive(entry.root) then
        set_intercepts_if_alive(entry.root, true)
        entry.root:add_fast_event('左键-按下', function()
          if play_ui_click then
            play_ui_click()
          end
          refresh_archive_pool_detail(ui, entry.spec)
        end)
      end
    end

    local exchange_button_root = get_archive_chip_click_target(ui.pool.detail and ui.pool.detail.exchange_button)
    if is_ui_alive(exchange_button_root) then
      exchange_button_root:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        local selected_node = STATE.archive_panel_pool_item
        local selected_spec = ui.pool.items and ui.pool.items[1] and ui.pool.items[1].spec or nil
        for _, entry in ipairs(ui.pool.items or {}) do
          if entry.spec and entry.spec.node == selected_node then
            selected_spec = entry.spec
            break
          end
        end
        if not selected_spec then
          message('请先选择一个奖池物品。')
          return
        end
        local profile = load_profile()
        local ok, remain = spend_archive_pool_score(profile, selected_spec.cost or 100)
        if not ok then
          message(string.format('夺宝积分不足：当前 %d，兑换需要 %d。', remain or 0, selected_spec.cost or 100))
          refresh_archive_pool_detail(ui, selected_spec)
          return
        end
        local owned_count = add_archive_pool_item(profile, selected_spec.node, 1)
        mark_profile_dirty()
        refresh_archive_panel_ui(profile)
        refresh_archive_pool_detail(ui, selected_spec)
        message(string.format('已兑换 %s ×1，当前拥有 %d 个。', selected_spec.title or '奖池物品', owned_count))
      end)
    end

    local pool_entry_root = get_archive_chip_click_target(ui.chest.pool_entry)
    if is_ui_alive(pool_entry_root) then
      pool_entry_root:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_page('pool')
      end)
    end

    local prob_entry_root = get_archive_chip_click_target(ui.chest.prob_entry)
    if is_ui_alive(prob_entry_root) then
      prob_entry_root:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_page('pool')
      end)
    end

    local function bind_pool_draw_button(path, draw_count)
      local root = resolve_ui(path)
      if not is_ui_alive(root) then
        return
      end
      set_intercepts_if_alive(root, true)
      root:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        local profile = load_profile()
        local score, total_draw_count = add_archive_pool_draw_reward(profile, draw_count)
        mark_profile_dirty()
        refresh_archive_panel_ui(profile)
        message(string.format('夺宝 %d 次完成，获得 %d 积分。累计夺宝 %d 次，当前积分 %d。', draw_count, draw_count * 10, total_draw_count, score))
      end)
    end

    bind_pool_draw_button(get_archive_page_path('chest') .. '.chest_card.draw_one', 1)
    bind_pool_draw_button(get_archive_page_path('chest') .. '.chest_card.draw_ten', 10)

    local back_button_root = get_archive_chip_click_target(ui.pool.back_button)
    if is_ui_alive(back_button_root) then
      back_button_root:add_fast_event('左键-按下', function()
        if play_ui_click then
          play_ui_click()
        end
        set_archive_panel_page('chest')
      end)
    end

    bind_archive_demo_interactions()
  end

  refresh_archive_panel_ui = function(profile)
    local ui = ensure_archive_panel_ui()
    if not is_archive_panel_ui_alive(ui) then
      return false
    end

    profile = profile or load_profile()
    local clear_counts, total_clear_count = get_archive_clear_counts(profile)
    local save_state_color = STATE.outgame_profile_save_enabled == true
      and { 114, 234, 77, 255 }
      or { 240, 174, 62, 255 }

    set_text_if_alive(ui.save_status_value, get_archive_save_state_text(false))
    set_text_color_if_alive(ui.save_status_value, STATE.outgame_profile_save_enabled == true and theme.palette.gold or save_state_color)

    set_text_if_alive(ui.profile.player_name, get_player_display_name())
    set_text_if_alive(ui.profile.map_level, tostring(get_archive_player_integer('get_map_level')))
    set_text_if_alive(ui.profile.pass_value, tostring(total_clear_count))
    set_text_if_alive(ui.profile.sign_value, tostring(get_archive_player_integer('get_sign_in_days')))
    set_text_if_alive(ui.profile.save_state_value, get_archive_save_state_text(true))
    set_text_color_if_alive(ui.profile.save_state_value, save_state_color)

    for index = 1, 10 do
      set_text_if_alive(ui.profile.count_values[index], tostring(clear_counts[index] or 0))
    end

    set_text_if_alive(ui.chest.ticket_value, '-')
    set_text_if_alive(ui.chest.score_value, tostring(get_archive_pool_score(profile)))
    local platform_lottery_count = get_archive_total_lottery_count()
    local local_draw_count = get_archive_pool_draw_count(profile)
    set_text_if_alive(ui.chest.count_value, tostring(math.max(platform_lottery_count, local_draw_count)))

    set_archive_universal_tab(STATE.archive_panel_universal_tab or 'pass')
    local universal_tab = STATE.archive_panel_universal_tab or 'pass'
    local universal_entries = ui.universal_items and ui.universal_items[universal_tab]
    if universal_entries and universal_entries[1] then
      refresh_archive_universal_detail(ui, universal_tab, universal_entries[1].spec)
    end
    if ui.pool.items and ui.pool.items[1] then
      local selected_pool_item = STATE.archive_panel_pool_item
      local selected_spec = ui.pool.items[1].spec
      for _, entry in ipairs(ui.pool.items) do
        if entry.spec.node == selected_pool_item then
          selected_spec = entry.spec
          break
        end
      end
      refresh_archive_pool_detail(ui, selected_spec)
    end
    if STATE.archive_panel_visible == true then
      set_archive_panel_page(STATE.archive_panel_page or 'profile')
    end
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
    local tip_root = resolve_ui('outgame.大厅.layout.right.mode_name.修仙模式tips')
    local tip = resolve_ui('outgame.大厅.layout.right.mode_name.修仙模式tips.layout_2.label_3')
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
      local cultivation_slot = build_static_mode_slot('outgame.大厅.layout.left_2.list.修仙模式', VIEW_MODE_CULTIVATION, '打鱼模式')
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
      set_archive_panel_visible(false)
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
    local ui = ensure_ui()
    set_non_outgame_ui_visible(visible ~= true)
    if not is_outgame_ui_alive(ui) then
      if visible == true then
        schedule_ui_retry()
      end
      return
    end
    set_visible_if_alive(ui.root, visible == true)
    set_visible_if_alive(ui.hall_root, visible == true)
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

  api.rebuild_hero_attr_bonus_stats = rebuild_hero_attr_bonus_stats

  return api
end

return M
