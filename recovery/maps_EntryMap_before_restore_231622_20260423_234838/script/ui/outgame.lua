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

  local function build_daily_task_rows(profile, selected_stage_id)
    local selected_stage_def = STAGES_BY_ID[selected_stage_id]
    local chapter_id = get_selected_chapter_id(selected_stage_id)
    local unlocked_count, cleared_count = get_chapter_progress_state(profile, chapter_id)
    local chapter_total = #get_chapter_stage_list(chapter_id)
    local stage_status = selected_stage_def and get_stage_status_text(profile, selected_stage_def) or '未选择'
    local stage_progress = get_stage_progress(profile, selected_stage_id)
    local stage_cleared = stage_progress and stage_progress.standard_cleared == true
    local result_text = format_last_result(profile)

    return {
      {
        title = string.format('章节 %s 推进', tostring(chapter_id or 1)),
        reward = '奖励：解锁后续关卡',
        progress = string.format('%d/%d', cleared_count, math.max(1, chapter_total)),
        status = cleared_count >= chapter_total and '完成' or '进行中',
      },
      {
        title = selected_stage_def and get_stage_display_text(selected_stage_def, selected_stage_id) or '当前关卡',
        reward = '奖励：推进当前主线',
        progress = stage_cleared and '1/1' or '0/1',
        status = stage_status,
      },
      {
        title = '关卡开放情况',
        reward = string.format('奖励：已开放 %d 个节点', unlocked_count),
        progress = string.format('%d/%d', unlocked_count, math.max(1, chapter_total)),
        status = unlocked_count >= chapter_total and '已满' or '开放中',
      },
      {
        title = '最近战报',
        reward = result_text ~= '' and result_text or '奖励：完成一局后写入战报',
        progress = result_text ~= '' and '1/1' or '0/1',
        status = result_text ~= '' and '已记录' or '待开始',
      },
      {
        title = '局外属性加成',
        reward = format_bonus_summary(profile),
        progress = next(profile.hero_attr_bonus_stats or {}) and '1/1' or '0/1',
        status = next(profile.hero_attr_bonus_stats or {}) and '生效中' or '未获得',
      },
    }
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
    message(build_save_status_detail(profile))
    return false
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_ui()
    end
    refresh_ui()
  end

  function api.set_ui_visible(visible)
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
