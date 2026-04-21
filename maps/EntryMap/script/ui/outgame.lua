local BattlePass = require 'runtime.battle_pass'

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
  local STAGE_PAGE_SIZE = 5
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
    [VIEW_MODE_CULTIVATION] = '修仙模式',
  }
  local DIFFICULTY_BUTTON_SLOT_WIDTH = 428
  local DIFFICULTY_BUTTON_SLOT_HEIGHT = 100
  local DIFFICULTY_BUTTON_WIDTH = 204
  local DIFFICULTY_BUTTON_HEIGHT = 68
  local DIFFICULTY_BUTTON_GAP = 12
  local DIFFICULTY_BUTTON_TOP_PADDING = 18
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
  local battle_pass_panel = nil

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

  local function set_intercepts_if_alive(ui, intercepts)
    if is_ui_alive(ui) and ui.set_intercepts_operations then
      ui:set_intercepts_operations(intercepts == true)
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
    merge_bonus_stats(rebuilt, BattlePass.collect_claimed_bonus_stats(profile))
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
    if BattlePass.ensure_profile_defaults(profile) then
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

  local function build_ui_refresh_signature(profile)
    local window_width, window_height = get_window_metrics()
    local last_result = profile and profile.last_result or nil
    return table.concat({
      tostring(STATE.session_phase or ''),
      tostring(STATE.stage_start_in_progress or false),
      tostring(STATE.outgame_profile_save_enabled or false),
      tostring(STATE.outgame_save_backend_ready or false),
      tostring(STATE.selected_stage_id or (profile and profile.selected_stage_id) or ''),
      tostring((profile and profile.selected_mode_id) or ''),
      tostring((profile and profile.selected_view_mode) or ''),
      tostring(last_result and last_result.stage_id or ''),
      tostring(last_result and last_result.is_win or ''),
      tostring(last_result and last_result.reached_wave_index or ''),
      tostring(window_width),
      tostring(window_height),
    }, '|')
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
      and ui.stage_slots
      and is_ui_alive(ui.page_container)
      and is_ui_alive(ui.start_button)
  end

  local function clear_page_buttons(ui)
    for _, root in ipairs(STATE.outgame_page_button_roots or {}) do
      if is_ui_alive(root) and root.remove then
        root:remove()
      end
    end
    STATE.outgame_page_button_roots = {}
    for _, button_ref in ipairs(ui.page_buttons or {}) do
      if is_ui_alive(button_ref.root) and button_ref.root.remove then
        button_ref.root:remove()
      end
    end
    ui.page_button_canvas = nil
    ui.page_button_top_spacer = nil
    ui.page_button_bottom_spacer = nil
    ui.page_button_count = 0
    ui.page_button_layout = nil
    ui.page_buttons = {}
  end

  local function create_difficulty_button(parent_ui)
    if not is_ui_alive(parent_ui) then
      return nil
    end

    local ok, prefab = pcall(y3.ui_prefab.create, env.get_player(), '难度按钮', parent_ui)
    if not ok or not prefab then
      return nil
    end

    local root = prefab:get_child()
    local button = prefab:get_child('button_2')
    if not is_ui_alive(root) or not is_ui_alive(button) then
      if prefab.remove then
        prefab:remove()
      end
      return nil
    end

    local locked = prefab:get_child('button_2.locked')
    set_intercepts_if_alive(root, false)
    set_intercepts_if_alive(locked, false)
    return {
      prefab = prefab,
      root = root,
      button = button,
      locked = locked,
    }
  end

  local function layout_difficulty_button(button_ref, center_x, center_y, z_order)
    if not button_ref then
      return
    end

    if not is_ui_alive(button_ref.root) then
      return
    end

    button_ref.root:set_anchor(0.5, 0.5)
    button_ref.root:set_pos(center_x, center_y)
    if button_ref.root.set_ui_size then
      button_ref.root:set_ui_size(DIFFICULTY_BUTTON_SLOT_WIDTH, DIFFICULTY_BUTTON_SLOT_HEIGHT)
    end
    set_intercepts_if_alive(button_ref.root, false)
    if z_order and button_ref.root.set_z_order then
      button_ref.root:set_z_order(z_order)
    end
    if is_ui_alive(button_ref.locked) and z_order and button_ref.locked.set_z_order then
      button_ref.locked:set_z_order(z_order + 1)
    end
  end

  local function get_top_aligned_vertical_pos(container_height, item_height, gap, item_index, top_padding)
    local start_y = container_height - math.max(0, top_padding or 0) - (item_height * 0.5)
    return math.floor(start_y - ((item_index - 1) * (item_height + gap)) + 0.5)
  end

  local function layout_page_buttons(ui)
    local container = ui and ui.page_container or nil
    local layout = ui and ui.page_button_layout or nil
    if not is_ui_alive(container) or not layout then
      return
    end

    local container_width = math.floor((container:get_width() or 428) + 0.5)
    local container_height = math.floor((container:get_height() or 688) + 0.5)
    local item_height = math.max(0, math.floor((layout.height or 100) + 0.5))
    local gap = math.max(0, math.floor((layout.gap or 0) + 0.5))
    local center_x = math.floor((container_width * 0.5) + 0.5)

    for index, button_ref in ipairs(ui.page_buttons or {}) do
      layout_difficulty_button(
        button_ref,
        center_x,
        get_top_aligned_vertical_pos(container_height, item_height, gap, index, layout.top_padding),
        10
      )
    end
  end

  local function clear_stage_slot_overlay(slot)
    if not slot or not is_ui_alive(slot.root) then
      return
    end

    local overlay_root = slot.root.get_child and slot.root:get_child('难度按钮') or nil
    if is_ui_alive(overlay_root) and overlay_root.remove then
      overlay_root:remove()
    end

    slot.prefab = nil
    slot.button_root = nil
    slot.button = nil
    slot.locked = nil
    slot.bound = false

    set_visible_if_alive(slot.bg, true)
    set_visible_if_alive(slot.label, true)
  end

  local function ensure_page_buttons(ui, desired_count)
    local container = ui.page_container
    if not is_ui_alive(container) then
      return
    end
    desired_count = math.max(0, tonumber(desired_count) or 0)
    if desired_count <= 0 then
      clear_page_buttons(ui)
      return
    end
    if desired_count == (ui.page_button_count or 0)
      and desired_count == #ui.page_buttons then
      layout_page_buttons(ui)
      return
    end

    clear_page_buttons(ui)
    STATE.outgame_page_button_roots = {}

    ui.page_button_count = desired_count

    ui.page_button_layout = {
      width = DIFFICULTY_BUTTON_SLOT_WIDTH,
      height = DIFFICULTY_BUTTON_SLOT_HEIGHT,
      gap = DIFFICULTY_BUTTON_GAP,
      top_padding = DIFFICULTY_BUTTON_TOP_PADDING,
    }

    for index = 1, desired_count do
      local button_ref = create_difficulty_button(container)
      if button_ref then
        local entry = {
          prefab = button_ref.prefab,
          root = button_ref.root,
          button = button_ref.button,
          locked = button_ref.locked,
          stage_def = nil,
        }
        layout_difficulty_button(entry, 0, 0, 10)
        button_ref.button:set_button_enable(true)
        button_ref.button:add_fast_event('左键-按下', function()
          local stage_def = entry.stage_def
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
        ui.page_buttons[#ui.page_buttons + 1] = entry
        STATE.outgame_page_button_roots[#STATE.outgame_page_button_roots + 1] = button_ref.root
      else
        local root = container:create_child('图片')
        root:set_image(999)
        root:set_ui_size(DIFFICULTY_BUTTON_SLOT_WIDTH, DIFFICULTY_BUTTON_SLOT_HEIGHT)
        layout_difficulty_button({ root = root }, 0, 0, 10)
        root:set_intercepts_operations(true)

        local label = root:create_child('文本')
        label:set_ui_size(DIFFICULTY_BUTTON_WIDTH, DIFFICULTY_BUTTON_HEIGHT)
        label:set_anchor(0.5, 0.5)
        label:set_pos(DIFFICULTY_BUTTON_SLOT_WIDTH * 0.5, DIFFICULTY_BUTTON_SLOT_HEIGHT * 0.5)
        label:set_text(string.format('N%d', index))
        label:set_font_size(24)
        label:set_text_alignment('中', '中')
        label:set_intercepts_operations(false)
        label:set_z_order(11)

        local entry = {
          root = root,
          label = label,
          stage_def = nil,
        }
        root:add_fast_event('左键-按下', function()
          local stage_def = entry.stage_def
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
        ui.page_buttons[#ui.page_buttons + 1] = entry
        STATE.outgame_page_button_roots[#STATE.outgame_page_button_roots + 1] = root
      end
    end

    layout_page_buttons(ui)
  end

  local function bind_stage_slot(slot)
    local click_target = slot.bg or slot.root
    if not is_ui_alive(click_target) or slot.bound == true then
      return
    end
    slot.bound = true
    click_target:add_fast_event('左键-按下', function()
      if not slot.chapter_id then
        return
      end
      local profile = load_profile()
      local target_stage_id = get_chapter_target_stage_id(profile, slot.chapter_id, profile.selected_stage_id)
      if not target_stage_id then
        return
      end
      if play_ui_click then
        play_ui_click()
      end
      if set_selected_stage(target_stage_id) then
        api.refresh_ui()
      end
    end)
  end

  local function bind_mode_slot(slot)
    local click_target = slot and (slot.bg or slot.root) or nil
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

    local root = ui.hall_root:create_child('图片')
    root:set_image(999)
    root:set_ui_size(312, 118)
    root:set_image_color(12, 18, 28, 228)
    root:set_z_order(25)
    root:set_intercepts_operations(true)

    local line = root:create_child('图片')
    line:set_image(999)
    line:set_ui_size(280, 2)
    line:set_pos(156, 78)
    line:set_image_color(88, 130, 198, 240)
    line:set_z_order(26)

    local title = root:create_child('文本')
    title:set_ui_size(136, 24)
    title:set_pos(82, 92)
    title:set_text('存档状态')
    title:set_font_size(20)
    title:set_text_color(244, 247, 255, 255)
    title:set_text_alignment('左', '中')
    title:set_intercepts_operations(false)
    title:set_z_order(27)

    local status = root:create_child('文本')
    status:set_ui_size(280, 46)
    status:set_pos(156, 52)
    status:set_font_size(15)
    status:set_text_color(204, 216, 232, 255)
    status:set_text_alignment('左', '上')
    status:set_intercepts_operations(false)
    status:set_z_order(27)

    local button_bg = root:create_child('图片')
    button_bg:set_image(999)
    button_bg:set_ui_size(120, 34)
    button_bg:set_pos(246, 20)
    button_bg:set_image_color(60, 98, 150, 235)
    button_bg:set_z_order(26)

    local button = root:create_child('按钮')
    button:set_ui_size(120, 34)
    button:set_pos(246, 20)
    button:set_font_size(16)
    button:set_text_color(245, 248, 255, 255)
    button:set_z_order(27)

    ui.save_entry = {
      root = root,
      title = title,
      status = status,
      button_bg = button_bg,
      button = button,
    }
    ui.save_entry_bound = false
    return ui.save_entry
  end

  local function refresh_save_entry_ui(ui, profile)
    local save_entry = ensure_save_entry_ui(ui)
    if not save_entry then
      return
    end

    local window_width, window_height = get_window_metrics()
    save_entry.root:set_pos(window_width - 208, window_height - 124)
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

  local function ensure_ui()
    if is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_page_buttons(STATE.outgame_ui, MAX_CHAPTER_DIFFICULTY_COUNT)
      for _, slot in ipairs(STATE.outgame_ui.stage_slots or {}) do
        clear_stage_slot_overlay(slot)
      end
      sync_outgame_backdrop(STATE.outgame_ui)
      ensure_save_entry_ui(STATE.outgame_ui)
      refresh_save_entry_ui(STATE.outgame_ui, STATE.outgame_profile)
      bind_ui_events(STATE.outgame_ui)
      return STATE.outgame_ui
    end

    local root = resolve_ui('outgame')
    local hall_root = resolve_ui('outgame.大厅')
    local backdrop = resolve_ui('outgame.大厅.layout.底板')
    local title = resolve_ui('outgame.大厅.layout.right.mode_name')
    local tip_root = resolve_ui('outgame.大厅.layout.right.mode_name.修仙模式tips')
    local tip = resolve_ui('outgame.大厅.layout.right.mode_name.修仙模式tips.layout.label')
    local page_container = resolve_ui('outgame.大厅.layout.right.难度列表')
    local mode_panel = resolve_ui('outgame.大厅.layout.left_2')
    local mode_list = resolve_ui('outgame.大厅.layout.left_2.list')
    local stage_slot_container = resolve_ui('outgame.大厅.layout.right_2.list')
    local start_button = resolve_ui('outgame.大厅.layout.start')

    if not root or not hall_root or not title or not page_container or not stage_slot_container or not start_button then
      if not STATE.outgame_ui_bind_warned then
        STATE.outgame_ui_bind_warned = true
        message('未找到 outgame 画板中的大厅节点，请先确认 outgame.json 已加载。')
      end
      return nil
    end

    for _, old_root in ipairs(STATE.outgame_page_button_roots or {}) do
      if is_ui_alive(old_root) and old_root.remove then
        old_root:remove()
      end
    end
    STATE.outgame_page_button_roots = {}

    local mode_slots = {}
    for _, slot_def in ipairs({
      { node_name = '主线模式', view_mode = VIEW_MODE_MAINLINE, label = '主线模式' },
      { node_name = '修仙模式', view_mode = VIEW_MODE_CULTIVATION, label = '修仙模式' },
    }) do
      local slot_root = mode_list and mode_list:get_child(slot_def.node_name) or nil
      local slot_bg = slot_root and slot_root:get_child('模式') or nil
      local slot_label = slot_root and slot_root:get_child('模式.mode') or nil
      local slot_selected = slot_root and slot_root:get_child('模式.selected') or nil
      set_intercepts_if_alive(slot_label, false)
      set_intercepts_if_alive(slot_selected, false)
      mode_slots[#mode_slots + 1] = {
        root = slot_root,
        bg = slot_bg,
        label = slot_label,
        selected = slot_selected,
        view_mode = slot_def.view_mode,
        display_label = slot_def.label,
        bound = false,
      }
    end

    local stage_slots = {}
    for index = 1, STAGE_PAGE_SIZE do
      local slot_root = stage_slot_container:get_child(string.format('mode%d', index))
      local slot_bg = slot_root and slot_root:get_child('模式') or nil
      local slot_label = slot_root and slot_root:get_child('模式.mode') or nil
      local slot_selected = slot_root and slot_root:get_child('模式.selected') or nil
      set_intercepts_if_alive(slot_label, false)
      set_intercepts_if_alive(slot_selected, false)
      stage_slots[index] = {
        root = slot_root,
        bg = slot_bg,
        label = slot_label,
        selected = slot_selected,
        chapter_id = nil,
        stage_id = nil,
        bound = false,
      }
      clear_stage_slot_overlay(stage_slots[index])
    end

    STATE.outgame_ui = {
      root = root,
      hall_root = hall_root,
      backdrop = backdrop,
      title = title,
      tip_root = tip_root,
      tip = tip,
      mode_panel = mode_panel,
      mode_slots = mode_slots,
      page_container = page_container,
      page_button_canvas = nil,
      page_button_count = 0,
      page_buttons = {},
      page_button_top_spacer = nil,
      page_button_bottom_spacer = nil,
      page_button_layout = nil,
      stage_slots = stage_slots,
      start_button = start_button,
      start_bound = false,
      save_entry = nil,
      save_entry_bound = false,
    }

    sync_outgame_backdrop(STATE.outgame_ui)
    ensure_save_entry_ui(STATE.outgame_ui)
    ensure_page_buttons(STATE.outgame_ui, MAX_CHAPTER_DIFFICULTY_COUNT)
    bind_ui_events(STATE.outgame_ui)
    return STATE.outgame_ui
  end

  local function refresh_mode_selectors(ui, profile, selected_stage_id, selected_mode_id)
    local selected_view_mode = get_selected_view_mode(profile)
    set_visible_if_alive(ui.mode_panel, true)
    for _, slot in ipairs(ui.mode_slots or {}) do
      local selected = slot.view_mode == selected_view_mode
      set_visible_if_alive(slot.root, true)
      set_text_if_alive(slot.label, slot.display_label)
      set_visible_if_alive(slot.selected, selected)
      set_image_color_if_alive(slot.bg, { 255, 255, 255, selected and 255 or 210 })
      set_text_color_if_alive(slot.label, selected and { 253, 151, 0, 255 } or { 208, 216, 228, 255 })
    end
    return selected_view_mode
  end

  local function refresh_page_buttons(ui, profile, selected_stage_id)
    local selected_chapter_id = get_selected_chapter_id(selected_stage_id)
    local chapter_stages = get_chapter_stage_list(selected_chapter_id)
    ensure_page_buttons(ui, #chapter_stages)
    for index, button_ref in ipairs(ui.page_buttons or {}) do
      local stage_def = chapter_stages[index]
      local progress = stage_def and get_stage_progress(profile, stage_def.stage_id) or nil
      local unlocked = progress and progress.standard_unlocked == true or false
      local cleared = progress and progress.standard_cleared == true or false
      local selected = stage_def and selected_stage_id == stage_def.stage_id or false

      button_ref.stage_def = stage_def
      set_visible_if_alive(button_ref.root, stage_def ~= nil)
      if stage_def then
        set_text_if_alive(button_ref.button or button_ref.label, get_difficulty_display_text(stage_def, index))
        set_visible_if_alive(button_ref.locked, not unlocked)

        if selected then
          set_image_color_if_alive(button_ref.button or button_ref.root, COLOR.selected_bg)
          set_text_color_if_alive(button_ref.button or button_ref.label, COLOR.selected_text)
        elseif not unlocked then
          set_image_color_if_alive(button_ref.button or button_ref.root, COLOR.locked_bg)
          set_text_color_if_alive(button_ref.button or button_ref.label, COLOR.locked_text)
        elseif cleared then
          set_image_color_if_alive(button_ref.button or button_ref.root, COLOR.cleared_bg)
          set_text_color_if_alive(button_ref.button or button_ref.label, COLOR.cleared_text)
        else
          set_image_color_if_alive(button_ref.button or button_ref.root, COLOR.available_bg)
          set_text_color_if_alive(button_ref.button or button_ref.label, COLOR.available_text)
        end
      else
        set_visible_if_alive(button_ref.locked, false)
      end
    end
  end

  local function refresh_stage_slots(ui, profile, selected_stage_id)
    local selected_chapter_id = get_selected_chapter_id(selected_stage_id)
    for index, slot in ipairs(ui.stage_slots or {}) do
      local chapter_id = CHAPTER_LIST[index]
      slot.chapter_id = chapter_id
      slot.stage_id = chapter_id and get_chapter_target_stage_id(
        profile,
        chapter_id,
        selected_chapter_id == chapter_id and selected_stage_id or nil
      ) or nil
      set_visible_if_alive(slot.root, chapter_id ~= nil)

      if chapter_id then
        local chapter_name = get_chapter_display_text(chapter_id)
        local chapter_stages = get_chapter_stage_list(chapter_id)
        local unlocked_count, cleared_count = get_chapter_progress_state(profile, chapter_id)
        local unlocked = unlocked_count > 0
        local selected = selected_chapter_id == chapter_id
        local cleared = cleared_count >= #chapter_stages and cleared_count > 0

        set_text_if_alive(slot.label, chapter_name)
        set_visible_if_alive(slot.selected, selected)

        if selected then
          set_image_color_if_alive(slot.bg, COLOR.selected_bg)
          set_text_color_if_alive(slot.label, COLOR.selected_text)
        elseif not unlocked then
          set_image_color_if_alive(slot.bg, COLOR.locked_bg)
          set_text_color_if_alive(slot.label, COLOR.locked_text)
        elseif cleared then
          set_image_color_if_alive(slot.bg, COLOR.cleared_bg)
          set_text_color_if_alive(slot.label, COLOR.cleared_text)
        else
          set_image_color_if_alive(slot.bg, COLOR.available_bg)
          set_text_color_if_alive(slot.label, COLOR.available_text)
        end
      end
    end

    return selected_chapter_id
  end

  local function refresh_ui(force_refresh)
    local ui = ensure_ui()
    if not is_outgame_ui_alive(ui) then
      return false
    end

    local profile = load_profile()
    local refresh_signature = build_ui_refresh_signature(profile)
    if force_refresh ~= true and STATE.outgame_ui_refresh_signature == refresh_signature then
      return false
    end
    STATE.outgame_ui_refresh_signature = refresh_signature

    local selected_stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local selected_mode_id = SINGLE_MODE_ID
    local selected_view_mode = get_selected_view_mode(profile)
    local selected_stage_def = STAGES_BY_ID[selected_stage_id]

    sync_outgame_backdrop(ui)
    set_visible_if_alive(ui.root, STATE.session_phase == 'outgame')
    set_visible_if_alive(ui.hall_root, STATE.session_phase == 'outgame')
    refresh_save_entry_ui(ui, profile)

    if not selected_stage_def then
      return true
    end

    if profile.selected_mode_id ~= SINGLE_MODE_ID then
      profile.selected_mode_id = SINGLE_MODE_ID
      mark_profile_dirty()
    end
    sync_selected_state(selected_stage_id, SINGLE_MODE_ID)

    set_text_if_alive(ui.title, get_view_mode_label(selected_view_mode))
    set_visible_if_alive(ui.tip_root, selected_view_mode == VIEW_MODE_CULTIVATION)

    refresh_mode_selectors(ui, profile, selected_stage_id, selected_mode_id)
    refresh_stage_slots(ui, profile, selected_stage_id)
    refresh_page_buttons(ui, profile, selected_stage_id)

    local start_enabled = is_mode_unlocked(profile, selected_stage_id, selected_mode_id)
    ui.start_button:set_text(start_enabled and '开始' or '未解锁')
    ui.start_button:set_button_enable(start_enabled)

    if start_enabled then
      set_image_color_if_alive(ui.start_button, COLOR.start_ready_bg)
      set_text_color_if_alive(ui.start_button, COLOR.selected_text)
    else
      set_image_color_if_alive(ui.start_button, COLOR.start_locked_bg)
      set_text_color_if_alive(ui.start_button, COLOR.locked_text)
    end
    return true
  end

  function api.load_profile()
    local profile = load_profile()
    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    return profile
  end

  function api.open_save_panel()
    if battle_pass_panel and battle_pass_panel.open_panel then
      if battle_pass_panel.set_ui_visible then
        battle_pass_panel.set_ui_visible(true)
      end
      if battle_pass_panel.open_panel('pass') then
        return true
      end
    end

    local profile = load_profile()
    message(build_save_status_detail(profile))
    return false
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_ui()
    end
    local did_refresh = refresh_ui()
    if did_refresh and battle_pass_panel and battle_pass_panel.refresh_ui then
      battle_pass_panel.refresh_ui()
    end
  end

  function api.set_ui_visible(visible)
    local ui = ensure_ui()
    if not is_outgame_ui_alive(ui) then
      return
    end
    if visible == true then
      STATE.outgame_ui_refresh_signature = nil
    end
    set_visible_if_alive(ui.root, visible == true)
    set_visible_if_alive(ui.hall_root, visible == true)
    if battle_pass_panel and battle_pass_panel.set_ui_visible then
      local battle_pass_visible = STATE.session_phase == 'battle'
        or (visible == true and STATE.session_phase == 'outgame')
      battle_pass_panel.set_ui_visible(battle_pass_visible)
    end
  end

  function api.enter_outgame(result)
    local profile = api.load_profile()
    local battle_pass_summary = nil
    if result then
      battle_pass_summary = api.apply_battle_result(result)
      profile = load_profile()
    end

    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)

    STATE.session_phase = 'outgame'
    STATE.game_finished = true
    STATE.outgame_ui_refresh_signature = nil
    if ensure_music_loop then
      ensure_music_loop()
    end
    env.set_battle_hud_visible(false)
    ensure_ui()
    refresh_ui(true)
    api.set_ui_visible(true)
    if battle_pass_panel and battle_pass_panel.enter_outgame then
      battle_pass_panel.enter_outgame()
    end
    if battle_pass_summary and battle_pass_summary.added_exp and battle_pass_summary.added_exp > 0 then
      message(BattlePass.build_gain_message(battle_pass_summary))
    end
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

    local battle_pass_summary = BattlePass.apply_battle_result(profile, result)
    rebuild_hero_attr_bonus_stats(profile)
    mark_profile_dirty()
    return battle_pass_summary
  end

  function api.start_selected_stage()
    if STATE.stage_start_in_progress == true then
      return false
    end

    local profile = load_profile()
    local stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local mode_id = SINGLE_MODE_ID

    if not is_mode_unlocked(profile, stage_id, mode_id) then
      message(build_start_hint(profile, stage_id, mode_id))
      refresh_ui()
      return false
    end

    if is_ui_alive(STATE.outgame_ui and STATE.outgame_ui.start_button) then
      STATE.outgame_ui.start_button:set_button_enable(false)
    end

    local ok = env.stage_runtime
      and env.stage_runtime.start_selected_stage
      and env.stage_runtime.start_selected_stage(stage_id, mode_id)
    if ok then
      if battle_pass_panel and battle_pass_panel.leave_outgame then
        battle_pass_panel.leave_outgame()
      end
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

  function api.set_battle_pass_panel(panel)
    battle_pass_panel = panel
  end

  api.rebuild_hero_attr_bonus_stats = rebuild_hero_attr_bonus_stats

  return api
end

return M
