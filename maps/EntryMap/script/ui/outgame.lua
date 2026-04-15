local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local layout = require 'ui.outgame_layout'

local skin = require 'ui.skin'
local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local message = env.message
  local play_ui_click = env.play_ui_click
  local ensure_music_loop = env.ensure_music_loop
  local factory = Factory.create(env)

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local create_button = factory.create_button
  local set_percent_pos = factory.set_percent_pos
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local outgame_skin = skin.images.outgame or {}

  local STAGE_LIST = CONFIG.stages and CONFIG.stages.list or {}
  local STAGES_BY_ID = CONFIG.stages and CONFIG.stages.by_id or {}
  local MODES_BY_ID = CONFIG.stage_modes and CONFIG.stage_modes.by_id or {}
  local SAVE_SLOT = CONFIG.save_slots and CONFIG.save_slots.outgame_profile or 1
  local OUTGAME_ATTR_BONUS_BY_STAGE_MODE = CONFIG.outgame_attr_bonus_config
    and CONFIG.outgame_attr_bonus_config.by_stage_mode
    or {}
  local STAGE_PAGE_SIZE = 3
  local CHAPTER_LIST = {}
  local STAGES_BY_CHAPTER = {}

  local api = {}

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function create_fullscreen_root(hud)
    local root = hud:create_child('图片')
    local width = math.floor((hud:get_width() or 0) + 0.5)
    local height = math.floor((hud:get_height() or 0) + 0.5)
    if width <= 0 then
      width = math.floor((y3.ui.get_window_width() or 1920) + 0.5)
    end
    if height <= 0 then
      height = math.floor((y3.ui.get_window_height() or 1080) + 0.5)
    end
    root:set_ui_size(width, height)
    root:set_anchor(0.5, 0.5)
    root:set_pos(width * 0.5, height * 0.5)
    root:set_image(999)
    root:set_image_color(6, 10, 18, 220)
    root:set_z_order(30000)
    root:set_visible(true)
    root:set_intercepts_operations(true)
    return root
  end

  local function parse_stage_id(stage_id)
    local chapter_text, stage_text = tostring(stage_id or ''):match('^(%d+)%-(%d+)$')
    return tonumber(chapter_text), tonumber(stage_text)
  end

  local function get_stage_display_text(stage_def, fallback_stage_id)
    if stage_def and stage_def.display_name and stage_def.display_name ~= '' then
      return stage_def.display_name
    end
    return tostring(fallback_stage_id or '未命名章节')
  end

  for _, stage_def in ipairs(STAGE_LIST) do
    local chapter_id = select(1, parse_stage_id(stage_def.stage_id))
    chapter_id = chapter_id or 1
    if not STAGES_BY_CHAPTER[chapter_id] then
      STAGES_BY_CHAPTER[chapter_id] = {}
      CHAPTER_LIST[#CHAPTER_LIST + 1] = chapter_id
    end
    STAGES_BY_CHAPTER[chapter_id][#STAGES_BY_CHAPTER[chapter_id] + 1] = stage_def
  end

  table.sort(CHAPTER_LIST)

  local function get_chapter_stage_list(chapter_id)
    return STAGES_BY_CHAPTER[chapter_id] or {}
  end

  local function get_chapter_name(chapter_id)
    local chapter_stages = get_chapter_stage_list(chapter_id)
    local first_stage = chapter_stages[1]
    local chapter_name = tostring(get_stage_display_text(first_stage, chapter_id)):match('^(.-)%-%d+$')
    if chapter_name and chapter_name ~= '' then
      return chapter_name
    end
    return string.format('第%d章', tonumber(chapter_id) or 1)
  end

  local function get_stage_page_count(chapter_id)
    local chapter_stages = get_chapter_stage_list(chapter_id)
    return math.max(1, math.ceil(#chapter_stages / STAGE_PAGE_SIZE))
  end

  local function get_stage_page_index(stage_id)
    local _, stage_index = parse_stage_id(stage_id)
    if not stage_index or stage_index <= 0 then
      return 1
    end
    return math.max(1, math.floor((stage_index - 1) / STAGE_PAGE_SIZE) + 1)
  end

  local function get_page_stage_defs(stage_id)
    local chapter_id = select(1, parse_stage_id(stage_id))
    chapter_id = chapter_id or CHAPTER_LIST[1] or 1

    local chapter_stages = get_chapter_stage_list(chapter_id)
    local page_index = get_stage_page_index(stage_id)
    local page_count = get_stage_page_count(chapter_id)
    local start_index = ((page_index - 1) * STAGE_PAGE_SIZE) + 1
    local visible_stages = {}

    for offset = 0, STAGE_PAGE_SIZE - 1 do
      local stage_def = chapter_stages[start_index + offset]
      if not stage_def then
        break
      end
      visible_stages[#visible_stages + 1] = stage_def
    end

    return chapter_id, page_index, page_count, visible_stages
  end

  local function get_stage_count_text()
    return string.format('已接入 %d 章 / %d 关', #CHAPTER_LIST, #STAGE_LIST)
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
    local progress = get_stage_progress(profile, stage_id)
    if not progress then
      return false
    end
    if mode_id == 'standard' then
      return progress.standard_unlocked == true
    end
    if mode_id == 'challenge' then
      return progress.challenge_unlocked == true
    end
    return false
  end

  local function get_first_stage_id()
    local first_stage = STAGE_LIST[1]
    return first_stage and first_stage.stage_id or '1-1'
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

  local function mark_profile_dirty()
    if STATE.outgame_profile_save_enabled ~= true then
      return
    end
    local ok, err = pcall(y3.save_data.upload_save_data, env.get_player())
    if ok then
      return
    end
    STATE.outgame_profile_save_enabled = false
    if not STATE.outgame_profile_save_warned then
      STATE.outgame_profile_save_warned = true
      message('局外存档上传失败，本次会话将继续使用内存态。错误：' .. tostring(err))
    end
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
    local selected_mode_id = profile.selected_mode_id
    local fallback_stage_id = get_highest_unlocked_standard_stage_id(profile)

    if type(selected_stage_id) ~= 'string'
      or not STAGES_BY_ID[selected_stage_id]
      or not is_standard_unlocked(profile, selected_stage_id) then
      profile.selected_stage_id = fallback_stage_id
      selected_stage_id = profile.selected_stage_id
      dirty = true
    end

    local stage_def = STAGES_BY_ID[selected_stage_id]
    if type(selected_mode_id) ~= 'string'
      or not MODES_BY_ID[selected_mode_id]
      or not is_stage_supported_mode(stage_def, selected_mode_id)
      or not is_mode_unlocked(profile, selected_stage_id, selected_mode_id) then
      profile.selected_mode_id = 'standard'
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
      return y3.save_data.load_table(env.get_player(), SAVE_SLOT)
    end)

    if ok and type(result) == 'table' then
      profile = result
      STATE.outgame_profile_save_enabled = true
    else
      profile = {}
      STATE.outgame_profile_save_enabled = false
      if not STATE.outgame_profile_save_warned then
        STATE.outgame_profile_save_warned = true
        message('局外存档槽位暂不可用，本次会话将使用内存态。错误：' .. tostring(result))
      end
    end

    local defaults_ok, defaults_dirty_or_err = pcall(ensure_profile_defaults, profile)
    if not defaults_ok then
      profile = {}
      STATE.outgame_profile = profile
      STATE.outgame_profile_save_enabled = false
      if not STATE.outgame_profile_save_warned then
        STATE.outgame_profile_save_warned = true
        message('局外存档读取失败，本次会话将使用内存态默认档。错误：' .. tostring(defaults_dirty_or_err))
      end
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
    STATE.selected_stage_id = stage_id
    STATE.selected_mode_id = mode_id
    STATE.current_stage_def = STAGES_BY_ID[stage_id]
    STATE.current_mode_def = MODES_BY_ID[mode_id]
  end

  local function set_selected_stage(stage_id)
    local profile = load_profile()
    local stage_def = STAGES_BY_ID[stage_id]
    if not stage_def then
      return false
    end

    profile.selected_stage_id = stage_id
    local mode_id = profile.selected_mode_id
    if not is_stage_supported_mode(stage_def, mode_id)
      or not is_mode_unlocked(profile, stage_id, mode_id) then
      profile.selected_mode_id = 'standard'
    end

    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    mark_profile_dirty()
    return true
  end

  local function set_selected_mode(mode_id)
    local profile = load_profile()
    local stage_def = STAGES_BY_ID[profile.selected_stage_id]
    if not stage_def or not MODES_BY_ID[mode_id] then
      return false
    end
    if not is_stage_supported_mode(stage_def, mode_id) then
      return false
    end
    if not is_mode_unlocked(profile, profile.selected_stage_id, mode_id) then
      return false
    end

    profile.selected_mode_id = mode_id
    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    mark_profile_dirty()
    return true
  end

  local function set_selected_chapter(chapter_id)
    local chapter_stages = get_chapter_stage_list(chapter_id)
    local target_stage = chapter_stages[1]
    if not target_stage then
      return false
    end
    return set_selected_stage(target_stage.stage_id)
  end

  local function step_stage_page(direction)
    local profile = load_profile()
    local selected_stage_id = STATE.selected_stage_id or profile.selected_stage_id or get_first_stage_id()
    local chapter_id, page_index, page_count = get_page_stage_defs(selected_stage_id)
    local target_page = math.max(1, math.min(page_count, page_index + direction))
    if target_page == page_index then
      return false
    end

    local chapter_stages = get_chapter_stage_list(chapter_id)
    local target_stage = chapter_stages[((target_page - 1) * STAGE_PAGE_SIZE) + 1]
    if not target_stage then
      return false
    end
    return set_selected_stage(target_stage.stage_id)
  end

  local function get_stage_status_text(profile, stage_def)
    local progress = get_stage_progress(profile, stage_def.stage_id)
    if not progress or not progress.standard_unlocked then
      return '未解锁'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return '内容接入中，当前复用 1-1 验证流程'
    end
    if progress.standard_cleared then
      return '标准流程已通关'
    end
    return '章节内容已接入，可直接推进'
  end

  local function get_mode_button_text(profile, stage_id, mode_id)
    local mode_def = MODES_BY_ID[mode_id]
    local progress = get_stage_progress(profile, stage_id)
    if not mode_def or not progress then
      return tostring(mode_id)
    end
    if mode_id == 'standard' then
      if progress.standard_cleared then
        return mode_def.display_name .. ' 已通关'
      end
      if progress.standard_unlocked then
        return mode_def.display_name .. ' 可进入'
      end
      return mode_def.display_name .. ' 未解锁'
    end
    if progress.challenge_cleared then
      return mode_def.display_name .. ' 已通关'
    end
    if progress.challenge_unlocked then
      return mode_def.display_name .. ' 可进入'
    end
    return mode_def.display_name .. ' 未解锁'
  end

  local function build_start_hint(profile, stage_id, mode_id)
    local stage_def = STAGES_BY_ID[stage_id]
    local mode_def = MODES_BY_ID[mode_id]
    if not stage_def or not mode_def then
      return '当前选择无效，请重新确认章节与模式。'
    end
    if not is_standard_unlocked(profile, stage_id) then
      return '当前章节尚未开放，请先通关上一章标准模式。'
    end
    if mode_id == 'challenge' and not is_mode_unlocked(profile, stage_id, mode_id) then
      return '挑战模式需要先通关本章标准模式后解锁。'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return '本章暂复用 1-1 战斗内容，当前主要用于验证局外流程与章节解锁。'
    end
    return '当前章节内容已准备完成，确认后即可开始战斗。'
  end

  local function format_last_result(profile)
    local result = profile and profile.last_result or nil
    if type(result) ~= 'table' or not result.stage_id or not result.mode_id then
      return '最近结果：暂无记录'
    end

    local outcome = result.is_win and '胜利' or '失败'
    local stage_def = STAGES_BY_ID[result.stage_id]
    local mode_def = MODES_BY_ID[result.mode_id]
    local stage_name = get_stage_display_text(stage_def, result.stage_id)
    local mode_name = mode_def and mode_def.display_name or tostring(result.mode_id)
    local reached_wave = math.max(0, result.reached_wave_index or 0)

    return string.format(
      '最近战报：%s  %s  %s  到达波次 %d',
      stage_name,
      mode_name,
      outcome,
      reached_wave
    )
  end

  local function get_detail_meta_text(stage_id, mode_id)
    local mode_name = MODES_BY_ID[mode_id] and MODES_BY_ID[mode_id].display_name or tostring(mode_id)
    local chapter_id = select(1, parse_stage_id(stage_id))
    return string.format('战前简报：%s / %s', get_chapter_name(chapter_id), mode_name)
  end

  local function get_profile_status_text()
    if STATE.outgame_profile_save_enabled then
      return '存档状态：云端存档可用'
    end
    return '存档状态：当前使用内存态'
  end

  local function get_mode_hint_text(profile, stage_id, mode_id)
    local mode_def = MODES_BY_ID[mode_id]
    if not mode_def then
      return '请选择可用模式后再开始本局。'
    end
    if not is_mode_unlocked(profile, stage_id, mode_id) then
      return string.format('%s 尚未开放，请先完成前置解锁条件。', mode_def.display_name)
    end
    if mode_id == 'challenge' then
      return '挑战模式用于毕业验证，会继承章节解锁进度并强调强度检验。'
    end
    return '标准模式用于推进章节，是当前版本的主要体验路径。'
  end

  local function get_start_ready_text(profile, stage_id, mode_id)
    local mode_def = MODES_BY_ID[mode_id]
    local stage_def = STAGES_BY_ID[stage_id]
    if not stage_def or not mode_def then
      return '当前选择无效，请重新确认。'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return string.format('将进入 %s，当前使用 %s 规则进行验证。', mode_def.display_name, stage_def.content_source_stage_id)
    end
    return string.format('将进入 %s 的 %s，请确认后开始。', get_stage_display_text(stage_def, stage_id), mode_def.display_name)
  end

  local function is_outgame_ui_alive(ui)
    return ui
      and ui.root
      and not ui.root:is_removed()
      and ui.stage_cards
      and ui.detail_panel
  end

  local function set_stage_card_visible(card, visible)
    if not card then
      return
    end
    if card.bg then
      card.bg:set_visible(visible == true)
    end
    if card.button then
      card.button:set_visible(visible == true)
    end
  end

  local function refresh_ui()
    local ui = STATE.outgame_ui
    local profile = load_profile()
    if not is_outgame_ui_alive(ui) then
      return
    end

    local selected_stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local selected_mode_id = STATE.selected_mode_id or profile.selected_mode_id
    local selected_stage_def = STAGES_BY_ID[selected_stage_id]

    ui.root:set_visible(STATE.session_phase == 'outgame')
    if not selected_stage_def then
      return
    end

    local active_chapter_id, active_page_index, active_page_count, visible_stage_defs = get_page_stage_defs(selected_stage_id)
    local visible_slots = {}
    for slot_index, stage_def in ipairs(visible_stage_defs) do
      visible_slots[stage_def.stage_id] = slot_index
    end

    for _, stage_def in ipairs(STAGE_LIST) do
      local card = ui.stage_cards[stage_def.stage_id]
      local slot_index = visible_slots[stage_def.stage_id]
      if not slot_index then
        set_stage_card_visible(card, false)
      else
        local y = ui.stage_card_y - (slot_index - 1) * ui.stage_card_step
        card.bg:set_pos(ui.stage_card_x, y)
        card.button:set_pos(ui.stage_card_x, y)
        set_stage_card_visible(card, true)
        local selected = stage_def.stage_id == selected_stage_id
        local unlocked = is_standard_unlocked(profile, stage_def.stage_id)
        local status_text = get_stage_status_text(profile, stage_def)

        if selected then
          card.bg:set_image_color(42, 92, 158, 238)
          if card.frame then
            card.frame:set_image_color(116, 190, 255, 188)
          end
          if card.icon then
            card.icon:set_image_color(238, 246, 255, 255)
          end
          card.line:set_image_color(96, 170, 255, 255)
          if card.badge_bg then
            card.badge_bg:set_image_color(82, 146, 226, 236)
          end
          if card.badge then
            card.badge:set_text('当前')
            card.badge:set_text_color(245, 248, 255, 255)
          end
          card.title:set_text_color(245, 248, 255, 255)
          card.note:set_text_color(214, 232, 248, 255)
        elseif unlocked then
          card.bg:set_image_color(20, 34, 54, 226)
          if card.frame then
            card.frame:set_image_color(90, 146, 212, 126)
          end
          if card.icon then
            card.icon:set_image_color(204, 226, 255, 240)
          end
          card.line:set_image_color(60, 110, 170, 188)
          if card.badge_bg then
            card.badge_bg:set_image_color(58, 92, 136, 220)
          end
          if card.badge then
            card.badge:set_text('开放')
            card.badge:set_text_color(230, 240, 252, 255)
          end
          card.title:set_text_color(236, 244, 255, 255)
          card.note:set_text_color(182, 201, 224, 255)
        else
          card.bg:set_image_color(16, 24, 36, 218)
          if card.frame then
            card.frame:set_image_color(92, 102, 118, 96)
          end
          if card.icon then
            card.icon:set_image_color(148, 158, 174, 214)
          end
          card.line:set_image_color(74, 78, 92, 156)
          if card.badge_bg then
            card.badge_bg:set_image_color(64, 68, 78, 210)
          end
          if card.badge then
            card.badge:set_text('未开')
            card.badge:set_text_color(214, 206, 186, 255)
          end
          card.title:set_text_color(188, 198, 214, 255)
          card.note:set_text_color(132, 146, 168, 255)
        end

        card.title:set_text(get_stage_display_text(stage_def, stage_def.stage_id))
        card.note:set_text(stage_def.preview_note or '')
        card.status:set_text(status_text)
        if unlocked then
          card.status:set_text_color(210, 228, 242, 255)
        else
          card.status:set_text_color(176, 160, 132, 255)
        end
      end
    end

    for _, chapter_id in ipairs(CHAPTER_LIST) do
      local button_ref = ui.chapter_buttons and ui.chapter_buttons[chapter_id] or nil
      if button_ref then
        local selected = chapter_id == active_chapter_id
        button_ref.button:set_text(get_chapter_name(chapter_id))
        if selected then
          button_ref.bg:set_image_color(54, 108, 172, 236)
          button_ref.shadow:set_image_color(18, 42, 74, 148)
          button_ref.button:set_text_color(245, 248, 255, 255)
        else
          button_ref.bg:set_image_color(44, 62, 90, 220)
          button_ref.shadow:set_image_color(8, 18, 34, 110)
          button_ref.button:set_text_color(220, 232, 246, 255)
        end
      end
    end

    if ui.page_prev_button then
      local can_prev = active_page_index > 1
      ui.page_prev_button.button:set_button_enable(can_prev)
      if can_prev then
        ui.page_prev_button.bg:set_image_color(44, 62, 90, 220)
        ui.page_prev_button.shadow:set_image_color(8, 18, 34, 110)
        ui.page_prev_button.button:set_text_color(220, 232, 246, 255)
      else
        ui.page_prev_button.bg:set_image_color(34, 38, 48, 196)
        ui.page_prev_button.shadow:set_image_color(8, 10, 18, 96)
        ui.page_prev_button.button:set_text_color(160, 170, 184, 255)
      end
    end

    if ui.page_next_button then
      local can_next = active_page_index < active_page_count
      ui.page_next_button.button:set_button_enable(can_next)
      if can_next then
        ui.page_next_button.bg:set_image_color(44, 62, 90, 220)
        ui.page_next_button.shadow:set_image_color(8, 18, 34, 110)
        ui.page_next_button.button:set_text_color(220, 232, 246, 255)
      else
        ui.page_next_button.bg:set_image_color(34, 38, 48, 196)
        ui.page_next_button.shadow:set_image_color(8, 10, 18, 96)
        ui.page_next_button.button:set_text_color(160, 170, 184, 255)
      end
    end

    if ui.stage_page_text then
      ui.stage_page_text:set_text(string.format('第 %d / %d 页', active_page_index, active_page_count))
    end
    ui.stage_list_hint:set_text(string.format('%s · 关卡分页', get_chapter_name(active_chapter_id)))

    ui.detail_title:set_text(get_stage_display_text(selected_stage_def, selected_stage_id))
    ui.detail_note:set_text(selected_stage_def.preview_note or '')
    ui.detail_status:set_text(build_start_hint(profile, selected_stage_id, selected_mode_id))
    ui.last_result:set_text(format_last_result(profile))
    ui.stage_badge.text:set_text('当前选择 ' .. get_stage_display_text(selected_stage_def, selected_stage_id))
    if ui.detail_meta then
      ui.detail_meta:set_text(get_detail_meta_text(selected_stage_id, selected_mode_id))
    end
    if ui.profile_status then
      ui.profile_status:set_text(get_profile_status_text())
    end
    if ui.mode_hint then
      ui.mode_hint:set_text(get_mode_hint_text(profile, selected_stage_id, selected_mode_id))
    end

    for mode_id, button_ref in pairs(ui.mode_buttons) do
      local unlocked = is_mode_unlocked(profile, selected_stage_id, mode_id)
      local selected = selected_mode_id == mode_id
      button_ref.button:set_text(get_mode_button_text(profile, selected_stage_id, mode_id))
      button_ref.button:set_button_enable(unlocked)
      if selected and unlocked then
        button_ref.bg:set_image_color(54, 108, 172, 236)
        button_ref.shadow:set_image_color(18, 42, 74, 148)
        button_ref.button:set_text_color(245, 248, 255, 255)
      elseif unlocked then
        button_ref.bg:set_image_color(54, 78, 112, 226)
        button_ref.shadow:set_image_color(8, 18, 34, 118)
        button_ref.button:set_text_color(228, 238, 250, 255)
      else
        button_ref.bg:set_image_color(38, 42, 56, 206)
        button_ref.shadow:set_image_color(8, 10, 18, 96)
        button_ref.button:set_text_color(170, 178, 190, 255)
      end
    end

    local start_enabled = is_mode_unlocked(profile, selected_stage_id, selected_mode_id)
    ui.start_button.button:set_button_enable(start_enabled)
    if start_enabled then
      ui.start_button.bg:set_image_color(76, 126, 90, 236)
      ui.start_button.shadow:set_image_color(26, 54, 32, 150)
      ui.start_button.button:set_text_color(245, 248, 255, 255)
      ui.start_hint:set_text(get_start_ready_text(profile, selected_stage_id, selected_mode_id))
    else
      ui.start_button.bg:set_image_color(58, 62, 72, 214)
      ui.start_button.shadow:set_image_color(8, 10, 18, 96)
      ui.start_button.button:set_text_color(186, 194, 206, 255)
      ui.start_hint:set_text(build_start_hint(profile, selected_stage_id, selected_mode_id))
    end
  end

  local function ensure_ui()
    local hud = get_hud_root()
    if not hud then
      return nil
    end
    if is_outgame_ui_alive(STATE.outgame_ui) then
      refresh_ui()
      return STATE.outgame_ui
    end

    local scale = get_hud_scale(hud, y3)
    local hud_width = math.floor((hud:get_width() or 0) + 0.5)
    local hud_height = math.floor((hud:get_height() or 0) + 0.5)
    if hud_width <= 0 then
      hud_width = math.floor((y3.ui.get_window_width() or 1920) + 0.5)
    end
    if hud_height <= 0 then
      hud_height = math.floor((y3.ui.get_window_height() or 1080) + 0.5)
    end
    local root = create_fullscreen_root(hud)

    local container = create_panel(
      root,
      0,
      0,
      hud_width,
      hud_height,
      { 6, 10, 18, 228 },
      { 48, 48, 48, 48 },
      30001,
      outgame_skin.backdrop
    )
    container:set_anchor(0.5, 0.5)
    set_percent_pos(env.get_player(), container, 50, 50)
    container:set_visible(true)

    local vignette = create_panel(
      container,
      hud_width * 0.5,
      hud_height * 0.5,
      math.floor(hud_width * 0.94),
      math.floor(hud_height * 0.9),
      { 8, 14, 24, 186 },
      { 48, 48, 48, 48 },
      30002,
      outgame_skin.vignette
    )
    vignette:set_anchor(0.5, 0.5)

    local header_band = create_panel(
      container,
      hud_width * 0.5,
      math.floor(hud_height * 0.92),
      math.floor(hud_width * 0.96),
      math.floor(hud_height * 0.12),
      { 10, 22, 38, 214 },
      { 40, 40, 32, 32 },
      30002,
      outgame_skin.header_band
    )
    header_band:set_anchor(0.5, 0.5)

    local footer_band = create_panel(
      container,
      hud_width * 0.5,
      math.floor(hud_height * 0.08),
      math.floor(hud_width * 0.96),
      math.floor(hud_height * 0.09),
      { 8, 16, 28, 186 },
      { 36, 36, 30, 30 },
      30002,
      outgame_skin.footer_band
    )
    footer_band:set_anchor(0.5, 0.5)

    local left_edge = create_panel(
      container,
      math.floor(hud_width * 0.035),
      hud_height * 0.5,
      math.floor(hud_width * 0.035),
      math.floor(hud_height * 0.8),
      { 20, 44, 76, 188 },
      { 24, 24, 24, 24 },
      30002,
      outgame_skin.edge_decor
    )
    left_edge:set_anchor(0.5, 0.5)

    local right_edge = create_panel(
      container,
      math.floor(hud_width * 0.965),
      hud_height * 0.5,
      math.floor(hud_width * 0.035),
      math.floor(hud_height * 0.8),
      { 20, 44, 76, 132 },
      { 24, 24, 24, 24 },
      30002,
      outgame_skin.edge_decor
    )
    right_edge:set_anchor(0.5, 0.5)

    local left_glow = create_panel(
      container,
      math.floor(hud_width * 0.12),
      hud_height * 0.5,
      math.floor(hud_width * 0.16),
      math.floor(hud_height * 0.72),
      { 18, 46, 78, 96 },
      { 40, 40, 40, 40 },
      30002,
      outgame_skin.side_glow
    )
    left_glow:set_anchor(0.5, 0.5)

    local right_glow = create_panel(
      container,
      math.floor(hud_width * 0.88),
      hud_height * 0.5,
      math.floor(hud_width * 0.16),
      math.floor(hud_height * 0.72),
      { 18, 40, 70, 72 },
      { 40, 40, 40, 40 },
      30002,
      outgame_skin.side_glow
    )
    right_glow:set_anchor(0.5, 0.5)

    local header_title = create_text(
      container,
      math.floor(hud_width * 0.16),
      math.floor(hud_height * 0.93),
      math.floor(hud_width * 0.22),
      math.floor(hud_height * 0.04),
      scaled(16, scale),
      theme.palette.accent_bright,
      '左',
      '中',
      30003
    )
    header_title:set_text('局外指挥终端')

    local header_hint = create_text(
      container,
      math.floor(hud_width * 0.84),
      math.floor(hud_height * 0.93),
      math.floor(hud_width * 0.28),
      math.floor(hud_height * 0.03),
      scaled(11, scale),
      theme.palette.text_soft,
      '右',
      '中',
      30003
    )
    header_hint:set_text('章节选择 / 模式确认 / 战斗开始')

    local content_root = create_panel(
      container,
      scaled(layout.container.x, scale),
      scaled(layout.container.y, scale),
      scaled(layout.container.width, scale),
      scaled(layout.container.height, scale),
      theme.palette.panel_deep,
      { 36, 36, 30, 30 },
      30003,
      outgame_skin.content_root
    )
    content_root:set_anchor(0.5, 0.5)
    set_percent_pos(env.get_player(), content_root, 50, 50)

    local left_strip = create_panel(
      content_root,
      scaled(layout.left_strip.x, scale),
      scaled(layout.left_strip.y, scale),
      scaled(layout.left_strip.width, scale),
      scaled(layout.left_strip.height, scale),
      { 78, 146, 224, 220 },
      theme.insets.soft,
      30004,
      outgame_skin.left_strip
    )
    left_strip:set_anchor(0.5, 0.5)

    local top_glow = create_panel(
      content_root,
      scaled(676, scale),
      scaled(734, scale),
      scaled(1220, scale),
      scaled(46, scale),
      { 20, 44, 74, 168 },
      { 26, 26, 26, 26 },
      30004,
      outgame_skin.top_glow
    )
    top_glow:set_anchor(0.5, 0.5)

    local top_line = create_panel(
      content_root,
      scaled(676, scale),
      scaled(748, scale),
      scaled(1210, scale),
      scaled(4, scale),
      theme.palette.accent_bright,
      theme.insets.soft,
      30005,
      outgame_skin.top_line
    )
    top_line:set_anchor(0.5, 0.5)

    local title_logo = create_panel(
      content_root,
      scaled(96, scale),
      scaled(716, scale),
      scaled(70, scale),
      scaled(70, scale),
      { 210, 230, 255, 255 },
      theme.insets.soft,
      30005,
      outgame_skin.title_logo
    )
    title_logo:set_anchor(0.5, 0.5)

    local title = create_text(
      content_root,
      scaled(170, scale),
      scaled(718, scale),
      scaled(420, scale),
      scaled(42, scale),
      scaled(32, scale),
      theme.palette.text,
      '左',
      '中',
      30002
    )
    title:set_text('远征终端')

    local subtitle = create_text(
      content_root,
      scaled(174, scale),
      scaled(680, scale),
      scaled(520, scale),
      scaled(42, scale),
      scaled(14, scale),
      theme.palette.text_soft,
      '左',
      '中',
      30002
    )
    subtitle:set_text('梳理章节、模式、结算回流与存档骨架，并统一整体 UI 风格。')
    subtitle:set_text('统一章节、模式、存档与战斗入口信息，让局外准备阶段更清晰。')

    local stage_list_panel = create_panel(
      content_root,
      scaled(layout.stage_list.x, scale),
      scaled(layout.stage_list.y, scale),
      scaled(layout.stage_list.width, scale),
      scaled(layout.stage_list.height, scale),
      theme.palette.panel_glass,
      { 28, 28, 24, 24 },
      30001,
      outgame_skin.stage_list_panel
    )
    stage_list_panel:set_anchor(0.5, 0.5)
    local stage_list_icon = create_panel(
      stage_list_panel,
      scaled(40, scale),
      scaled(532, scale),
      scaled(26, scale),
      scaled(26, scale),
      { 194, 222, 255, 255 },
      theme.insets.soft,
      30003,
      outgame_skin.stage_list_icon
    )
    stage_list_icon:set_anchor(0.5, 0.5)
    local stage_list_title = create_text(
      stage_list_panel,
      scaled(90, scale),
      scaled(534, scale),
      scaled(200, scale),
      scaled(24, scale),
      scaled(18, scale),
      theme.palette.text,
      '左',
      '中',
      30002
    )
    stage_list_title:set_text('章节列表')
    local stage_list_hint = create_text(
      stage_list_panel,
      scaled(92, scale),
      scaled(504, scale),
      scaled(220, scale),
      scaled(18, scale),
      scaled(11, scale),
      theme.palette.text_muted,
      nil,
      nil,
      30002
    )
    stage_list_hint:set_text('章节推进')

    local stage_list_count = create_text(
      stage_list_panel,
      scaled(286, scale),
      scaled(534, scale),
      scaled(170, scale),
      scaled(20, scale),
      scaled(11, scale),
      theme.palette.accent_bright,
      '右',
      '中',
      30002
    )
    stage_list_count:set_text(get_stage_count_text())

    local stage_list_divider = create_panel(
      stage_list_panel,
      scaled(207, scale),
      scaled(478, scale),
      scaled(342, scale),
      scaled(3, scale),
      { 72, 118, 178, 168 },
      theme.insets.soft,
      30002
    )
    stage_list_divider:set_anchor(0.5, 0.5)

    local chapter_buttons = {}
    local chapter_button_width = scaled(62, scale)
    local chapter_button_height = scaled(32, scale)
    local chapter_button_start_x = scaled(44, scale)
    local chapter_button_step = scaled(76, scale)
    for index, chapter_id in ipairs(CHAPTER_LIST) do
      chapter_buttons[chapter_id] = create_button(
        stage_list_panel,
        chapter_button_start_x + ((index - 1) * chapter_button_step),
        scaled(432, scale),
        chapter_button_width,
        chapter_button_height,
        get_chapter_name(chapter_id),
        function()
          if set_selected_chapter(chapter_id) then
            refresh_ui()
          end
        end,
        {
          font_size = scaled(11, scale),
          style = 'outgame_mode_secondary',
          shadow_offset_y = 2,
          shadow_grow = 6,
        }
      )
    end

    local stage_page_text = create_text(
      stage_list_panel,
      scaled(207, scale),
      scaled(42, scale),
      scaled(160, scale),
      scaled(18, scale),
      scaled(12, scale),
      theme.palette.text_soft,
      '中',
      '中',
      30002
    )
    stage_page_text:set_text('第 1 / 1 页')

    local page_prev_button = create_button(
      stage_list_panel,
      scaled(84, scale),
      scaled(42, scale),
      scaled(86, scale),
      scaled(30, scale),
      '上一页',
      function()
        if step_stage_page(-1) then
          refresh_ui()
        end
      end,
      {
        font_size = scaled(11, scale),
        style = 'outgame_mode_secondary',
        shadow_offset_y = 2,
        shadow_grow = 6,
      }
    )

    local page_next_button = create_button(
      stage_list_panel,
      scaled(330, scale),
      scaled(42, scale),
      scaled(86, scale),
      scaled(30, scale),
      '下一页',
      function()
        if step_stage_page(1) then
          refresh_ui()
        end
      end,
      {
        font_size = scaled(11, scale),
        style = 'outgame_mode_secondary',
        shadow_offset_y = 2,
        shadow_grow = 6,
      }
    )

    local detail_panel = create_panel(
      content_root,
      scaled(layout.detail.x, scale),
      scaled(layout.detail.y, scale),
      scaled(layout.detail.width, scale),
      scaled(layout.detail.height, scale),
      theme.palette.panel_glass,
      { 30, 30, 26, 26 },
      30001,
      outgame_skin.detail_panel
    )
    detail_panel:set_anchor(0.5, 0.5)

    local detail_hero = create_panel(
      detail_panel,
      scaled(366, scale),
      scaled(488, scale),
      scaled(650, scale),
      scaled(126, scale),
      { 14, 26, 42, 228 },
      { 24, 24, 20, 20 },
      30002,
      outgame_skin.detail_hero
    )
    detail_hero:set_anchor(0.5, 0.5)

    local detail_mode_block = create_panel(
      detail_panel,
      scaled(366, scale),
      scaled(258, scale),
      scaled(650, scale),
      scaled(150, scale),
      { 14, 24, 38, 220 },
      { 24, 24, 20, 20 },
      30002,
      outgame_skin.detail_mode_block
    )
    detail_mode_block:set_anchor(0.5, 0.5)

    local detail_footer = create_panel(
      detail_panel,
      scaled(366, scale),
      scaled(74, scale),
      scaled(650, scale),
      scaled(106, scale),
      { 10, 18, 30, 232 },
      { 24, 24, 20, 20 },
      30002,
      outgame_skin.detail_footer
    )
    detail_footer:set_anchor(0.5, 0.5)

    local stage_badge = {
      bg = create_panel(
        detail_hero,
        scaled(86, scale),
        scaled(102, scale),
        scaled(126, scale),
        scaled(30, scale),
        theme.palette.accent,
        theme.insets.soft,
        30003,
        outgame_skin.stage_badge
      ),
    }
    stage_badge.icon = create_panel(
      stage_badge.bg,
      scaled(16, scale),
      scaled(15, scale),
      scaled(18, scale),
      scaled(18, scale),
      { 255, 255, 255, 235 },
      theme.insets.soft,
      30004,
      outgame_skin.stage_badge_icon
    )
    stage_badge.icon:set_anchor(0.5, 0.5)
    stage_badge.text = create_text(
      stage_badge.bg,
      scaled(60, scale),
      scaled(14, scale),
      scaled(120, scale),
      scaled(20, scale),
      scaled(12, scale),
      theme.palette.text,
      '中',
      '中',
      9703
    )

    local detail_title = create_text(
      detail_hero,
      scaled(98, scale),
      scaled(66, scale),
      scaled(300, scale),
      scaled(32, scale),
      scaled(28, scale),
      theme.palette.text,
      '左',
      '中',
      30003
    )
    local detail_note = create_text(
      detail_hero,
      scaled(104, scale),
      scaled(28, scale),
      scaled(520, scale),
      scaled(22, scale),
      scaled(14, scale),
      theme.palette.text_soft,
      '左',
      '中',
      30003
    )
    local detail_status = create_text(
      detail_hero,
      scaled(330, scale),
      scaled(-8, scale),
      scaled(540, scale),
      scaled(48, scale),
      scaled(15, scale),
      theme.palette.text,
      '左',
      '中',
      30003
    )
    local detail_meta = create_text(
      detail_hero,
      scaled(542, scale),
      scaled(102, scale),
      scaled(170, scale),
      scaled(18, scale),
      scaled(11, scale),
      theme.palette.accent_bright,
      '右',
      '中',
      30003
    )
    detail_meta:set_text('战前简报')

    local detail_badge_decor = create_panel(
      detail_hero,
      scaled(602, scale),
      scaled(102, scale),
      scaled(30, scale),
      scaled(30, scale),
      { 186, 220, 255, 255 },
      theme.insets.soft,
      30003,
      outgame_skin.detail_badge_decor
    )
    detail_badge_decor:set_anchor(0.5, 0.5)

    local mode_title = create_text(
      detail_mode_block,
      scaled(84, scale),
      scaled(118, scale),
      scaled(180, scale),
      scaled(24, scale),
      scaled(18, scale),
      theme.palette.text,
      '左',
      '中',
      30002
    )
    mode_title:set_text('模式选择')
    local mode_icon = create_panel(
      detail_mode_block,
      scaled(42, scale),
      scaled(118, scale),
      scaled(24, scale),
      scaled(24, scale),
      { 194, 222, 255, 255 },
      theme.insets.soft,
      30003,
      outgame_skin.mode_icon
    )
    mode_icon:set_anchor(0.5, 0.5)

    local mode_buttons = {
      standard = create_button(
        detail_mode_block,
        scaled(176, scale),
        scaled(42, scale),
        scaled(220, scale),
        scaled(62, scale),
        '标准模式',
        function()
          if set_selected_mode('standard') then
            refresh_ui()
          end
        end,
        { font_size = scaled(15, scale), style = 'outgame_mode_primary' }
      ),
      challenge = create_button(
        detail_mode_block,
        scaled(432, scale),
        scaled(42, scale),
        scaled(220, scale),
        scaled(62, scale),
        '挑战模式',
        function()
          if set_selected_mode('challenge') then
            refresh_ui()
          end
        end,
        { font_size = scaled(15, scale), style = 'outgame_mode_secondary' }
      ),
    }

    local start_button = create_button(
      detail_panel,
      scaled(382, scale),
      scaled(120, scale),
      scaled(532, scale),
      scaled(72, scale),
      '开始本局',
      function()
        api.start_selected_stage()
      end,
      { font_size = scaled(22, scale), style = 'outgame_start' }
    )
    local start_button_decor = create_panel(
      detail_panel,
      scaled(128, scale),
      scaled(156, scale),
      scaled(42, scale),
      scaled(42, scale),
      { 255, 244, 216, 255 },
      theme.insets.soft,
      30003,
      outgame_skin.start_button_decor
    )
    start_button_decor:set_anchor(0.5, 0.5)
    local start_hint = create_text(
      detail_panel,
      scaled(382, scale),
      scaled(64, scale),
      scaled(560, scale),
      scaled(30, scale),
      scaled(14, scale),
      theme.palette.text_soft,
      '中',
      '中',
      30002
    )
    local last_result = create_text(
      detail_footer,
      scaled(324, scale),
      scaled(56, scale),
      scaled(560, scale),
      scaled(28, scale),
      scaled(15, scale),
      theme.palette.text,
      '中',
      '中',
      9702
    )

    local profile_status = create_text(
      detail_footer,
      scaled(324, scale),
      scaled(24, scale),
      scaled(560, scale),
      scaled(18, scale),
      scaled(11, scale),
      theme.palette.text_muted,
      nil,
      nil,
      9702
    )
    profile_status:set_text('存档状态读取中')
    local mode_hint = create_text(
      detail_mode_block,
      scaled(324, scale),
      scaled(18, scale),
      scaled(540, scale),
      scaled(18, scale),
      scaled(12, scale),
      theme.palette.text_muted,
      '中',
      '中',
      9702
    )
    mode_hint:set_text('请选择章节与模式，确认当前局的入口配置。')

    local stage_cards = {}
    local stage_card_x = scaled(layout.stage_list.card_x, scale)
    local stage_card_y = scaled(layout.stage_list.card_y - 74, scale)
    local stage_card_step = scaled(layout.stage_list.card_step, scale)
    for index, stage_def in ipairs(STAGE_LIST) do
      local y = stage_card_y - (index - 1) * stage_card_step
      local card_bg = create_panel(
        stage_list_panel,
        stage_card_x,
        y,
        scaled(layout.stage_list.card_width, scale),
        scaled(layout.stage_list.card_height, scale),
        { 17, 28, 43, 232 },
        theme.insets.normal,
        30002,
        outgame_skin.stage_card_bg
      )
      local card_frame = create_panel(
        card_bg,
        scaled(layout.stage_list.card_width * 0.5, scale),
        scaled(layout.stage_list.card_height * 0.5, scale),
        scaled(layout.stage_list.card_width, scale),
        scaled(layout.stage_list.card_height, scale),
        { 150, 196, 255, 132 },
        theme.insets.normal,
        30003,
        outgame_skin.stage_card_frame
      )
      card_frame:set_anchor(0.5, 0.5)
      local card_line = create_panel(
        card_bg,
        scaled(16, scale),
        scaled(61, scale),
        scaled(6, scale),
        scaled(82, scale),
        { 70, 120, 186, 190 },
        theme.insets.soft,
        9703
      )
      card_line:set_anchor(0.5, 0.5)
      local card_icon = create_panel(
        card_bg,
        scaled(44, scale),
        scaled(90, scale),
        scaled(34, scale),
        scaled(34, scale),
        { 204, 226, 255, 255 },
        theme.insets.soft,
        30005,
        outgame_skin.stage_card_icon
      )
      card_icon:set_anchor(0.5, 0.5)

      local card_button = stage_list_panel:create_child('按钮')
      card_button:set_ui_size(
        scaled(layout.stage_list.card_width, scale),
        scaled(layout.stage_list.card_height, scale)
      )
      card_button:set_pos(stage_card_x, y)
      card_button:set_text('')
      card_button:set_btn_status_image(1, 999)
      card_button:set_btn_status_image(2, 999)
      card_button:set_btn_status_image(3, 999)
      card_button:set_btn_status_image(4, 999)
      card_button:set_z_order(30004)
      card_button:add_fast_event('左键-点击', function()
        if play_ui_click then
          play_ui_click()
        end
        if set_selected_stage(stage_def.stage_id) then
          refresh_ui()
        end
      end)

      local card_title = create_text(
        card_bg,
        scaled(104, scale),
        scaled(90, scale),
        scaled(188, scale),
        scaled(24, scale),
        scaled(18, scale),
        theme.palette.text,
        '左',
        '中',
        30005,
        outgame_skin.stage_card_badge
      )
      local card_note = create_text(
        card_bg,
        scaled(134, scale),
        scaled(56, scale),
        scaled(250, scale),
        scaled(20, scale),
        scaled(12, scale),
        theme.palette.text_soft,
        '左',
        '中',
        30005
      )
      local card_status = create_text(
        card_bg,
        scaled(170, scale),
        scaled(22, scale),
        scaled(262, scale),
        scaled(18, scale),
        scaled(12, scale),
        theme.palette.text,
        '左',
        '中',
        30005
      )
      local card_badge_bg = create_panel(
        card_bg,
        scaled(266, scale),
        scaled(96, scale),
        scaled(56, scale),
        scaled(18, scale),
        theme.palette.accent_soft,
        theme.insets.soft,
        30005
      )
      local card_badge = create_text(
        card_badge_bg,
        scaled(30, scale),
        scaled(9, scale),
        scaled(60, scale),
        scaled(16, scale),
        scaled(10, scale),
        theme.palette.text,
        nil,
        nil,
        30006
      )
      card_badge:set_text('开放')

      stage_cards[stage_def.stage_id] = {
        bg = card_bg,
        frame = card_frame,
        icon = card_icon,
        line = card_line,
        button = card_button,
        title = card_title,
        note = card_note,
        status = card_status,
        badge_bg = card_badge_bg,
        badge = card_badge,
      }
    end

    STATE.outgame_ui = {
      root = root,
      container = container,
      content_root = content_root,
      left_strip = left_strip,
      title = title,
      subtitle = subtitle,
      stage_list_panel = stage_list_panel,
      detail_panel = detail_panel,
      stage_cards = stage_cards,
      chapter_buttons = chapter_buttons,
      page_prev_button = page_prev_button,
      page_next_button = page_next_button,
      stage_page_text = stage_page_text,
      stage_card_x = stage_card_x,
      stage_card_y = stage_card_y,
      stage_card_step = stage_card_step,
      detail_title = detail_title,
      detail_note = detail_note,
      detail_status = detail_status,
      detail_meta = detail_meta,
      mode_buttons = mode_buttons,
      mode_hint = mode_hint,
      start_button = start_button,
      start_hint = start_hint,
      last_result = last_result,
      profile_status = profile_status,
      stage_badge = stage_badge,
      stage_list_hint = stage_list_hint,
    }

    refresh_ui()
    return STATE.outgame_ui
  end

  function api.load_profile()
    local profile = load_profile()
    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    return profile
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_ui()
      return
    end
    refresh_ui()
  end

  function api.set_ui_visible(visible)
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      return
    end
    STATE.outgame_ui.root:set_visible(visible == true)
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
    if ensure_music_loop then
      ensure_music_loop()
    end
    env.set_battle_hud_visible(false)
    ensure_ui()
    refresh_ui()
    api.set_ui_visible(true)
  end

  function api.apply_battle_result(result)
    if not result then
      return
    end

    local profile = load_profile()
    local stage_id = result.stage_id or get_first_stage_id()
    local mode_id = result.mode_id or 'standard'
    local progress = get_stage_progress(profile, stage_id)
    if not progress then
      return
    end

    profile.last_result.stage_id = stage_id
    profile.last_result.mode_id = mode_id
    profile.last_result.is_win = result.is_win == true
    profile.last_result.reached_wave_index = math.max(0, result.reached_wave_index or 0)

    if result.is_win then
      if mode_id == 'standard' then
        progress.standard_cleared = true
        progress.challenge_unlocked = true

        local next_stage_id = get_next_stage_id(stage_id)
        if next_stage_id then
          local next_progress = get_stage_progress(profile, next_stage_id)
          if next_progress then
            next_progress.standard_unlocked = true
          end
        end
      elseif mode_id == 'challenge' then
        progress.challenge_cleared = true
      end
    end

    rebuild_hero_attr_bonus_stats(profile)

    mark_profile_dirty()
  end

  function api.start_selected_stage()
    local profile = load_profile()
    local stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local mode_id = STATE.selected_mode_id or profile.selected_mode_id

    if not is_mode_unlocked(profile, stage_id, mode_id) then
      message(build_start_hint(profile, stage_id, mode_id))
      refresh_ui()
      return false
    end

    local ok = env.start_selected_stage(stage_id, mode_id)
    if ok then
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
    return MODES_BY_ID[STATE.selected_mode_id]
  end

  function api.is_mode_unlocked(stage_id, mode_id)
    return is_mode_unlocked(load_profile(), stage_id, mode_id)
  end

  function api.get_profile()
    return load_profile()
  end

  api.rebuild_hero_attr_bonus_stats = rebuild_hero_attr_bonus_stats

  return api
end

return M

