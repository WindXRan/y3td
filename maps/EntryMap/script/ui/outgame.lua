local theme = require 'ui.theme'
local outgame_defs = require 'ui.outgame_defs'
local ArchiveShop = require 'ui.outgame_archive_shop'
local OutgameHeroGrowth = require 'runtime.outgame_hero_growth'
local ArchiveRankingTabs = require 'data.tables.outgame.archive_ranking_tabs'
local ArchiveTabDefinitions = require 'data.tables.archive_tab_definitions'
local OutgameUIConfig = require 'data.tables.outgame.outgame_ui_config'

local utils = require 'ui.outgame.utils'
local profile_module = require 'ui.outgame.profile'
local archive_panel_module = require 'ui.outgame.archive_panel'
local top_entry_module = require 'ui.outgame.top_entry'

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

  utils.init(env)

  profile_module.init({
    STATE = STATE,
    CONFIG = CONFIG,
    y3 = y3,
    OUTGAME_DEFS = OUTGAME_DEFS,
  })

  archive_panel_module.init({
    STATE = STATE,
    CONFIG = CONFIG,
    y3 = y3,
    message = message,
    play_ui_click = play_ui_click,
    OUTGAME_DEFS = OUTGAME_DEFS,
    ArchiveShop = ArchiveShop,
    ArchiveTabDefinitions = ArchiveTabDefinitions,
    RANKING_TABS = RANKING_TABS,
    OUTGAME_TOP_ENTRY_LIST = OUTGAME_TOP_ENTRY_LIST,
    get_player = env.get_player,
    persist_archive_items_state = profile_module.persist_archive_shop_specs_to_profile,
  })

  top_entry_module.init({
    STATE = STATE,
    message = message,
    play_ui_click = play_ui_click,
    OUTGAME_TOP_ENTRY_LIST = OUTGAME_TOP_ENTRY_LIST,
  })

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

  local function get_chapter_stage_list(chapter_id)
    return STAGES_BY_CHAPTER[chapter_id] or {}
  end

  local function get_chapter_display_text(chapter_id)
    local chapter_stages = get_chapter_stage_list(chapter_id)
    local first_stage = chapter_stages[1]
    local display = profile_module.get_stage_display_text(first_stage, string.format('%s-1', tostring(chapter_id or 1)))
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

  local function get_selected_view_mode(profile)
    local view_mode = profile and profile.selected_view_mode or nil
    if view_mode == VIEW_MODE_CULTIVATION then
      return VIEW_MODE_CULTIVATION
    end
    return VIEW_MODE_MAINLINE
  end

  local function get_page_for_stage(stage_id)
    return PAGE_BY_STAGE_ID[stage_id] or PAGE_LIST[1]
  end

  local function get_chapter_page_list(chapter_id)
    return PAGES_BY_CHAPTER[chapter_id] or {}
  end

  local function get_difficulty_display_text(stage_def, fallback_index)
    local difficulty_index = stage_def and select(2, utils.parse_stage_id(stage_def.stage_id)) or fallback_index or 1
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
    local fallback_stage_id = page_stages[1] and page_stages[1].stage_id or profile_module.get_first_stage_id()
    local preferred_page = preferred_stage_id and get_page_for_stage(preferred_stage_id) or nil
    if preferred_page and page_def and preferred_page.id == page_def.id then
      return preferred_stage_id
    end

    local latest_unlocked_stage_id = nil
    for _, stage_def in ipairs(page_stages) do
      if profile_module.is_standard_unlocked(profile, stage_def.stage_id) then
        latest_unlocked_stage_id = stage_def.stage_id
      end
    end

    return latest_unlocked_stage_id or fallback_stage_id
  end

  local function get_selected_chapter_id(stage_id)
    return select(1, utils.parse_stage_id(stage_id)) or CHAPTER_LIST[1]
  end

  local function set_selected_stage(stage_id)
    local profile = profile_module.load_profile(hero_growth_api)
    local stage_def = STAGES_BY_ID[stage_id]
    if not stage_def then
      return false
    end

    profile.selected_stage_id = stage_id
    profile.selected_mode_id = SINGLE_MODE_ID

    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    profile_module.mark_profile_dirty()
    return true
  end

  local function set_selected_view_mode(view_mode)
    if view_mode ~= VIEW_MODE_CULTIVATION then
      view_mode = VIEW_MODE_MAINLINE
    end

    local profile = profile_module.load_profile(hero_growth_api)
    if profile.selected_view_mode == view_mode then
      return false
    end

    profile.selected_view_mode = view_mode
    profile_module.mark_profile_dirty()
    return true
  end

  local function get_stage_status_text(profile, stage_def)
    local progress = profile_module.get_stage_progress(profile, stage_def.stage_id)
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
    if not profile_module.is_standard_unlocked(profile, stage_id) then
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
    if not profile_module.is_standard_unlocked(profile, stage_id) then
      return 'locked'
    end
    if stage_def and stage_def.content_source_stage_id ~= stage_def.stage_id then
      return 'reused'
    end
    local progress = stage_def and profile_module.get_stage_progress(profile, stage_def.stage_id) or nil
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
      or profile_module.get_stage_display_text(stage_def, stage_id)
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
    local stage_name = profile_module.get_stage_display_text(stage_def, result.stage_id)
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
    local stage_name = profile_module.get_stage_display_text(stage_def, stage_id)
    local result_text = format_last_result(profile)
    local hint = build_start_hint(profile, stage_id, mode_id)
    if result_text ~= '' then
      return string.format('当前关卡：%s。%s %s', stage_name, hint, result_text)
    end
    return string.format('当前关卡：%s。%s', stage_name, hint)
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
    utils.set_image_color_if_alive(ui.reward_card, theme.palette.panel_alt)
    utils.set_text_if_alive(ui.reward_title, '当前关卡奖励')
    if selected_stage_def then
      utils.set_text_if_alive(ui.reward_code, string.format('章节：%s', profile_module.get_stage_display_text(selected_stage_def, selected_stage_id)))
    else
      utils.set_text_if_alive(ui.reward_code, '章节：未选择')
    end
    utils.set_text_if_alive(ui.reward_hint, format_bonus_summary(profile))
  end

  local function get_player_avatar_payload(player)
    if not player then
      return 'icon', 134223473
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

    return 'icon', 134223473
  end

  local function refresh_player_slot_avatar(slot, player, occupied)
    if not slot or not utils.is_ui_alive(slot.avatar) then
      return
    end
    if occupied ~= true then
      slot.avatar_key = nil
      utils.set_visible_if_alive(slot.avatar, false)
      return
    end

    local payload_kind, payload_value, payload_aid = get_player_avatar_payload(player)
    if payload_value == nil or payload_value == '' then
      slot.avatar_key = nil
      utils.set_visible_if_alive(slot.avatar, false)
      return
    end

    utils.set_visible_if_alive(slot.avatar, true)
    local payload_key = string.format('%s:%s', tostring(payload_kind), tostring(payload_value))
    if slot.avatar_key == payload_key then
      return
    end
    slot.avatar_key = payload_key

    if payload_kind == 'url' then
      utils.set_image_url_if_alive(slot.avatar, payload_value, payload_aid)
    else
      utils.set_image_if_alive(slot.avatar, payload_value)
    end
  end

  local get_player_display_name

  local function refresh_footer(ui, profile)
    local player = env.get_player and env.get_player() or nil
    local mode_label = VIEW_MODE_LABELS[profile.selected_view_mode] or VIEW_MODE_LABELS[VIEW_MODE_MAINLINE]
    local save_label = STATE.outgame_profile_save_enabled == true and '云存档' or '内存态'
    utils.set_text_if_alive(ui.player_name, string.format('%s · %s · %s', get_player_display_name(), mode_label, save_label))
    for index, slot in ipairs(ui.player_slots or {}) do
      utils.set_visible_if_alive(slot.root, true)
      if index == 1 then
        utils.set_image_color_if_alive(slot.bg, theme.palette.warning)
        utils.set_image_color_if_alive(slot.inner, { 255, 233, 192, 255 })
        utils.set_text_if_alive(slot.label, '主机')
        refresh_player_slot_avatar(slot, player, true)
      else
        utils.set_image_color_if_alive(slot.bg, theme.palette.panel)
        utils.set_image_color_if_alive(slot.inner, theme.palette.panel_deep)
        utils.set_text_if_alive(slot.label, '')
        refresh_player_slot_avatar(slot, player, false)
      end
    end
  end

  get_player_display_name = function()
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

  local function sync_selected_state(stage_id, mode_id)
    mode_id = mode_id == SINGLE_MODE_ID and mode_id or SINGLE_MODE_ID
    STATE.selected_stage_id = stage_id
    STATE.selected_mode_id = mode_id
    STATE.current_stage_def = STAGES_BY_ID[stage_id]
    STATE.current_mode_def = MODES_BY_ID[mode_id] or MODES_BY_ID[SINGLE_MODE_ID]
  end

  local function bind_stage_slot(slot)
    if not slot or not utils.is_ui_alive(slot.root) or slot.bound == true then
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
    if not utils.is_ui_alive(click_target) or slot.bound == true then
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
    if not ui or not utils.is_ui_alive(ui.hall_root) then
      return nil
    end
    if ui.save_entry
      and utils.is_ui_alive(ui.save_entry.root)
      and utils.is_ui_alive(ui.save_entry.status)
      and utils.is_ui_alive(ui.save_entry.button) then
      return ui.save_entry
    end
    return nil
  end

  local function refresh_save_entry_ui(ui, profile)
    local save_entry = ensure_save_entry_ui(ui)
    if not save_entry then
      return
    end

    utils.set_visible_if_alive(save_entry.root, STATE.session_phase == 'outgame')
    utils.set_text_if_alive(save_entry.status, profile_module.build_save_status_brief(profile))
    utils.set_text_if_alive(save_entry.button, '打开存档')
    utils.set_image_color_if_alive(
      save_entry.button_bg,
      STATE.outgame_profile_save_enabled == true and { 60, 98, 150, 235 } or { 120, 88, 54, 235 }
    )
  end

  local function bind_save_entry(ui)
    local save_entry = ui and ui.save_entry or nil
    local button = save_entry and save_entry.button or nil
    if not utils.is_ui_alive(button) or ui.save_entry_bound == true then
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

  local function dispatch_top_entry_action(entry)
    return top_entry_module.dispatch_top_entry_action(
      entry,
      set_selected_view_mode,
      api.open_save_panel,
      api.start_selected_stage,
      api.refresh_ui
    )
  end

  local function sync_outgame_backdrop(ui)
    local backdrop = ui and ui.backdrop or nil
    if not utils.is_ui_alive(backdrop) or not backdrop.set_ui_size then
      return
    end

    local window_width, window_height = utils.get_window_metrics()
    backdrop:set_ui_size(window_width, window_height)
  end

  local function is_outgame_ui_alive(ui)
    return ui
      and utils.is_ui_alive(ui.root)
      and utils.is_ui_alive(ui.hall_root)
      and utils.is_ui_alive(ui.stage_slot_container)
      and utils.is_ui_alive(ui.start_button)
  end

  local function bind_ui_events(ui)
    for _, slot in ipairs(ui.mode_slots or {}) do
      bind_mode_slot(slot)
    end
    for _, slot in ipairs(ui.stage_slots or {}) do
      bind_stage_slot(slot)
    end

    bind_save_entry(ui)
    top_entry_module.bind_top_entry_list(ui, dispatch_top_entry_action)

    if ui.start_bound ~= true then
      local click_targets = {}
      local seen = {}
      local function push_target(target)
        if not utils.is_ui_alive(target) then
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

  ensure_ui = function()
    if is_outgame_ui_alive(STATE.outgame_ui) then
      sync_outgame_backdrop(STATE.outgame_ui)
      refresh_save_entry_ui(STATE.outgame_ui, STATE.outgame_profile)
      bind_ui_events(STATE.outgame_ui)
      top_entry_module.refresh_top_entry_list_ui(STATE.outgame_ui)
      return STATE.outgame_ui
    end

    local root = utils.resolve_ui_first({ 'DifficultyHUD', 'outgame' })
    local hall_root = utils.resolve_ui_first({ 'DifficultyHUD.大厅', 'outgame.大厅' })
    local backdrop = utils.resolve_ui_first({
      'DifficultyHUD.大厅.layout.底板',
      'DifficultyHUD.大厅.layout.shade',
      'outgame.大厅.layout.底板',
      'outgame.大厅.layout.shade',
    })
    local title = utils.resolve_outgame_ui('.大厅.layout.right.mode_name')
    local tip_root = utils.resolve_outgame_ui('.大厅.layout.right.mode_name.猎场模式tips')
    local tip = utils.resolve_outgame_ui('.大厅.layout.right.mode_name.猎场模式tips.layout_2.label_3')
    local page_container = utils.resolve_outgame_ui('.大厅.layout.right.难度列表')
    local mode_panel = utils.resolve_outgame_ui('.大厅.layout.left_2')
    local stage_slot_container = utils.resolve_outgame_ui('.大厅.layout.right_2.list')
    local start_button = utils.resolve_outgame_ui('.大厅.layout.start')

    if not (utils.is_ui_alive(root) and utils.is_ui_alive(hall_root)) then
      if not STATE.outgame_ui_bind_warned then
        STATE.outgame_ui_bind_warned = true
        message('未找到 outgame 静态画板，已等待界面编辑器面板加载。')
      end
      return nil
    end

    if utils.is_ui_alive(root)
      and utils.is_ui_alive(hall_root)
      and utils.is_ui_alive(mode_panel)
      and utils.is_ui_alive(stage_slot_container)
      and utils.is_ui_alive(start_button) then
      local function build_static_stage_slot(base_path)
        local slot_root = utils.resolve_ui(base_path)
        local bg = utils.resolve_ui(base_path .. '.模式')
        local label = utils.resolve_ui(base_path .. '.模式.mode')
        local selected = utils.resolve_ui(base_path .. '.模式.selected')
        if not utils.is_ui_alive(slot_root) then
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
        local slot_root = utils.resolve_outgame_ui(base_path)
        if utils.is_ui_alive(slot_root) then
          player_slots[#player_slots + 1] = {
            root = slot_root,
            bg = utils.resolve_outgame_ui(base_path .. '.frame') or slot_root,
            inner = utils.resolve_outgame_ui(base_path .. '.inner'),
            avatar = utils.resolve_outgame_ui(base_path .. '.avatar'),
            label = utils.resolve_outgame_ui(base_path .. '.label'),
            avatar_key = nil,
          }
        end
      end

      STATE.outgame_ui = {
        root = root,
        hall_root = hall_root,
        backdrop = backdrop,
        title = title,
        header_tip = utils.resolve_outgame_ui('.大厅.layout.header_tip'),
        tip_root = tip_root,
        tip = tip,
        mode_panel = mode_panel,
        mode_slots = {},
        left_panel = utils.resolve_outgame_ui('.大厅.layout.left'),
        reward_card = utils.resolve_outgame_ui('.大厅.layout.left.reward_group.reward_card_bg'),
        reward_title = utils.resolve_outgame_ui('.大厅.layout.left.reward_group.reward_title'),
        reward_code = utils.resolve_outgame_ui('.大厅.layout.left.reward_group.reward_code'),
        reward_hint = utils.resolve_outgame_ui('.大厅.layout.left.reward_group.reward_hint'),
        page_container = page_container,
        stage_slots = stage_slots,
        stage_slot_container = stage_slot_container,
        start_button_bg = utils.resolve_outgame_ui('.大厅.layout.start_bg') or start_button,
        start_button = start_button,
        start_anchor = utils.resolve_outgame_ui('.大厅.layout.start_anchor') or utils.resolve_outgame_ui('.大厅.layout.start_root') or nil,
        start_bound = false,
        save_entry = {
          root = utils.resolve_outgame_ui('.大厅.layout.save_anchor.save_root'),
          line = utils.resolve_outgame_ui('.大厅.layout.save_anchor.line'),
          title = utils.resolve_outgame_ui('.大厅.layout.save_anchor.title'),
          status = utils.resolve_outgame_ui('.大厅.layout.save_anchor.status'),
          button_bg = utils.resolve_outgame_ui('.大厅.layout.save_anchor.button_bg'),
          button = utils.resolve_outgame_ui('.大厅.layout.save_anchor.button'),
        },
        save_entry_bound = false,
        right_panel = utils.resolve_outgame_ui('.大厅.layout.right'),
        difficulty_title = title,
        difficulty_hint = utils.resolve_outgame_ui('.大厅.layout.right.difficulty_hint'),
        cultivation_note = tip,
        detail_title = utils.resolve_outgame_ui('.大厅.layout.detail_title'),
        detail_status = utils.resolve_outgame_ui('.大厅.layout.detail_status'),
        detail_hint = utils.resolve_outgame_ui('.大厅.layout.detail_hint'),
        quit_tip = utils.resolve_outgame_ui('.大厅.layout.quit_tip'),
        player_name = utils.resolve_outgame_ui('.大厅.layout.footer.player_name'),
        player_slots = player_slots,
        save_anchor = utils.resolve_outgame_ui('.大厅.layout.save_anchor'),
        top_entry_list_root = utils.resolve_ui_first({ 'top.list', 'top.top.list' }),
        top_entry_items = {},
      }

      bind_ui_events(STATE.outgame_ui)
      top_entry_module.refresh_top_entry_list_ui(STATE.outgame_ui)
      return STATE.outgame_ui
    end
    if not STATE.outgame_ui_bind_warned then
      STATE.outgame_ui_bind_warned = true
      message('outgame 静态画板节点不完整，请检查界面编辑器中的节点结构。')
    end
    return nil
  end

  local function refresh_stage_slots(ui, profile, selected_stage_id)
    local selected_chapter_id = get_selected_chapter_id(selected_stage_id)
    local chapter_stages = get_chapter_stage_list(selected_chapter_id)
    for index, slot in ipairs(ui.stage_slots or {}) do
      local stage_def = chapter_stages[index]
      local progress = stage_def and profile_module.get_stage_progress(profile, stage_def.stage_id) or nil
      local unlocked = progress and progress.standard_unlocked == true or false
      local cleared = progress and progress.standard_cleared == true or false
      local selected = stage_def and selected_stage_id == stage_def.stage_id or false
      slot.stage_def = stage_def
      utils.set_visible_if_alive(slot.root, stage_def ~= nil)
      if stage_def then
        utils.set_text_if_alive(slot.label, get_difficulty_display_text(stage_def, index))
        utils.set_visible_if_alive(slot.selected, selected)
        if selected then
          utils.set_image_color_if_alive(slot.bg, { 255, 255, 255, 255 })
          utils.set_text_color_if_alive(slot.label, theme.palette.text)
        elseif not unlocked then
          utils.set_image_color_if_alive(slot.bg, { 132, 132, 132, 228 })
          utils.set_text_color_if_alive(slot.label, theme.palette.text_muted)
        elseif cleared then
          utils.set_image_color_if_alive(slot.bg, { 226, 198, 122, 255 })
          utils.set_text_color_if_alive(slot.label, { 38, 26, 0, 255 })
        else
          utils.set_image_color_if_alive(slot.bg, { 214, 224, 236, 255 })
          utils.set_text_color_if_alive(slot.label, { 255, 255, 255, 255 })
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

    local profile = profile_module.load_profile(hero_growth_api)
    local selected_stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local selected_mode_id = SINGLE_MODE_ID
    local selected_view_mode = get_selected_view_mode(profile)
    local selected_stage_def = STAGES_BY_ID[selected_stage_id]

    sync_outgame_backdrop(ui)
    utils.set_visible_if_alive(ui.root, STATE.session_phase == 'outgame')
    utils.set_visible_if_alive(ui.hall_root, STATE.session_phase == 'outgame')

    utils.set_visible_if_alive(ui.left_panel, true)
    utils.set_visible_if_alive(ui.right_panel, true)
    utils.set_visible_if_alive(ui.mode_panel, false)

    refresh_save_entry_ui(ui, profile)
    if STATE.archive_panel_visible == true then
      archive_panel_module.refresh_archive_panel_ui(profile)
    end

    if not selected_stage_def then
      local top_title = "开始游戏"
      utils.set_text_if_alive(ui.title, top_title)
      utils.set_text_if_alive(ui.header_tip, "请选择关卡")
      utils.set_text_if_alive(ui.quit_tip, '按 ESC 键可退出游戏')
      utils.set_visible_if_alive(ui.tip_root, false)

      utils.set_visible_if_alive(ui.stage_slot_container, false)

      utils.set_text_if_alive(ui.difficulty_title, top_title)
      utils.set_text_if_alive(ui.difficulty_hint, '请选择关卡')
      utils.set_visible_if_alive(ui.cultivation_note, false)

      utils.set_visible_if_alive(ui.detail_title, true)
      utils.set_visible_if_alive(ui.detail_status, false)
      utils.set_visible_if_alive(ui.detail_hint, true)
      utils.set_text_if_alive(ui.detail_title, "请选择关卡")
      utils.set_text_if_alive(ui.detail_hint, "请选择关卡")

      refresh_reward_card(ui, profile, nil)
      refresh_footer(ui, profile)

      ui.start_button:set_text('请选择关卡')
      ui.start_button:set_button_enable(false)
      utils.set_image_color_if_alive(ui.start_button_bg, COLOR.start_locked_bg)
      utils.set_text_color_if_alive(ui.start_button, COLOR.locked_text)

      return
    end

    if profile.selected_mode_id ~= SINGLE_MODE_ID then
      profile.selected_mode_id = SINGLE_MODE_ID
      profile_module.mark_profile_dirty()
    end
    sync_selected_state(selected_stage_id, SINGLE_MODE_ID)

    local top_title = "开始游戏"
    utils.set_text_if_alive(ui.title, top_title)
    utils.set_text_if_alive(ui.header_tip, build_header_tip_text(profile, selected_stage_id, selected_mode_id))
    utils.set_text_if_alive(ui.quit_tip, '按 ESC 键可退出游戏')
    utils.set_visible_if_alive(ui.tip_root, false)

    utils.set_text_if_alive(ui.difficulty_title, top_title)
    utils.set_visible_if_alive(ui.stage_slot_container, false)
    utils.set_visible_if_alive(ui.cultivation_note, false)
    utils.set_text_if_alive(ui.difficulty_hint, '')

    local detail_title, detail_status, detail_hint = resolve_outgame_detail_texts(profile, selected_stage_id, selected_mode_id)
    utils.set_visible_if_alive(ui.detail_title, true)
    utils.set_visible_if_alive(ui.detail_status, detail_status ~= '')
    utils.set_visible_if_alive(ui.detail_hint, true)
    utils.set_text_if_alive(ui.detail_title, detail_title)
    utils.set_text_if_alive(ui.detail_status, detail_status)
    utils.set_text_if_alive(ui.detail_hint, detail_hint)
    refresh_reward_card(ui, profile, selected_stage_id)
    refresh_footer(ui, profile)

    local start_enabled = profile_module.is_mode_unlocked(profile, selected_stage_id, selected_mode_id)
    if not start_enabled and selected_stage_id == profile_module.get_first_stage_id() then
      start_enabled = true
    end
    ui.start_button:set_text(start_enabled and '开始游戏' or '未解锁')
    ui.start_button:set_button_enable(start_enabled)

    if start_enabled then
      utils.set_image_color_if_alive(ui.start_button_bg, COLOR.start_ready_bg)
      utils.set_text_color_if_alive(ui.start_button, COLOR.selected_text)
    else
      utils.set_image_color_if_alive(ui.start_button_bg, COLOR.start_locked_bg)
      utils.set_text_color_if_alive(ui.start_button, COLOR.locked_text)
    end
  end

  function api.load_profile()
    local profile = profile_module.load_profile(hero_growth_api)
    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)
    return profile
  end

  function api.open_save_panel()
    return archive_panel_module.open_save_panel(api.load_profile)
  end

  function api.refresh_ui()
    if not is_outgame_ui_alive(STATE.outgame_ui) then
      ensure_ui()
    end
    refresh_ui()
    top_entry_module.refresh_top_entry_list_ui(STATE.outgame_ui)
  end

  function api.set_ui_visible(visible)
    if visible ~= true and STATE.session_phase == 'outgame' then
      archive_panel_module.set_archive_panel_visible(false)
    end
    local archive_ui = STATE.archive_panel_ui
    if visible == true and not archive_panel_module.is_archive_panel_ui_alive(archive_ui) then
      archive_ui = archive_panel_module.ensure_archive_panel_ui()
    end
    local ui = ensure_ui()
    archive_panel_module.set_non_outgame_ui_visible(visible ~= true)
    if not is_outgame_ui_alive(ui) then
      if visible == true then
        schedule_ui_retry()
      end
      return
    end
    utils.set_visible_if_alive(ui.root, visible == true)
    utils.set_visible_if_alive(ui.hall_root, visible == true)
    top_entry_module.refresh_top_entry_list_ui(ui)
  end

  function api.enter_outgame(result)
    local profile = api.load_profile()
    if result then
      api.apply_battle_result(result)
      profile = profile_module.load_profile(hero_growth_api)
    end

    sync_selected_state(profile.selected_stage_id, profile.selected_mode_id)

    STATE.session_phase = 'outgame'
    STATE.game_finished = true
    ui_retry_remaining = 12
    if ensure_music_loop then
      ensure_music_loop()
    end
    env.set_battle_hud_visible(false)
    archive_panel_module.set_non_outgame_ui_visible(false)
    ensure_ui()
    archive_panel_module.set_archive_panel_visible(false)
    refresh_ui()
    api.set_ui_visible(true)
  end

  function api.apply_battle_result(result)
    return profile_module.apply_battle_result(result, hero_growth_api)
  end

  function api.start_selected_stage()
    if STATE.session_phase ~= 'outgame' then
      return false
    end
    local profile = profile_module.load_profile(hero_growth_api)
    local stage_id = STATE.selected_stage_id or profile.selected_stage_id
    local mode_id = SINGLE_MODE_ID

    local first_stage_id = profile_module.get_first_stage_id()
    if stage_id == first_stage_id then
      local progress = profile_module.get_stage_progress(profile, stage_id)
      if progress and progress.standard_unlocked ~= true then
        progress.standard_unlocked = true
        profile_module.mark_profile_dirty()
      end
    end

    if not profile_module.is_mode_unlocked(profile, stage_id, mode_id) then
      message(build_start_hint(profile, stage_id, mode_id))
      refresh_ui()
      return false
    end

    local ok = env.stage_runtime
      and env.stage_runtime.start_selected_stage
      and env.stage_runtime.start_selected_stage(stage_id, mode_id)
    if ok then
      archive_panel_module.set_non_outgame_ui_visible(true)
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
    return profile_module.is_mode_unlocked(profile_module.load_profile(hero_growth_api), stage_id, SINGLE_MODE_ID)
  end

  function api.get_profile()
    return profile_module.load_profile(hero_growth_api)
  end

  function api.mark_profile_dirty()
    return profile_module.mark_profile_dirty()
  end

  function api.get_hero_growth(hero_ref)
    local profile = profile_module.load_profile(hero_growth_api)
    return hero_growth_api.get_growth_view(profile, hero_ref)
  end

  function api.get_all_hero_growth()
    local profile = profile_module.load_profile(hero_growth_api)
    return hero_growth_api.get_growth_list(profile)
  end

  function api.add_hero_proficiency(hero_ref, amount)
    local profile = profile_module.load_profile(hero_growth_api)
    local ok, msg, value = hero_growth_api.add_proficiency(profile, hero_ref, amount)
    if ok then
      profile_module.mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  function api.get_awaken_stone()
    local profile = profile_module.load_profile(hero_growth_api)
    return hero_growth_api.get_awaken_stone(profile)
  end

  function api.add_awaken_stone(amount)
    local profile = profile_module.load_profile(hero_growth_api)
    local ok, msg, value = hero_growth_api.add_awaken_stone(profile, amount)
    if ok then
      profile_module.mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  function api.try_hero_star_up(hero_ref)
    local profile = profile_module.load_profile(hero_growth_api)
    local ok, msg, value = hero_growth_api.try_star_up(profile, hero_ref)
    if ok then
      profile_module.mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  function api.try_hero_awaken(hero_ref)
    local profile = profile_module.load_profile(hero_growth_api)
    local ok, msg, value = hero_growth_api.try_awaken(profile, hero_ref)
    if ok then
      profile_module.mark_profile_dirty()
      refresh_ui()
    end
    return ok, msg, value
  end

  api.rebuild_hero_attr_bonus_stats = profile_module.rebuild_hero_attr_bonus_stats

  for _, stage_def in ipairs(STAGE_LIST) do
    if not stage_def.stage_id then
      goto continue
    end
    local chapter_id = select(1, utils.parse_stage_id(stage_def.stage_id))
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

  _G.outgame_system = api
  return api
end

return M