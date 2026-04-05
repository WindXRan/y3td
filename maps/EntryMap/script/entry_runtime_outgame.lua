local ui_res = require 'ui_res'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local round_number = env.round_number
  local message = env.message

  local STAGE_LIST = CONFIG.stages and CONFIG.stages.list or {}
  local STAGES_BY_ID = CONFIG.stages and CONFIG.stages.by_id or {}
  local MODES_BY_ID = CONFIG.stage_modes and CONFIG.stage_modes.by_id or {}
  local SAVE_SLOT = CONFIG.save_slots and CONFIG.save_slots.outgame_profile or 1

  local api = {}

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function clamp(value, min_value, max_value)
    if value < min_value then
      return min_value
    end
    if value > max_value then
      return max_value
    end
    return value
  end

  local function get_hud_metrics(hud)
    local width = round_number(hud:get_width())
    local height = round_number(hud:get_height())
    if width <= 0 then
      width = round_number(y3.ui.get_window_width())
    end
    if height <= 0 then
      height = round_number(y3.ui.get_window_height())
    end
    return width, height
  end

  local function get_hud_scale(hud)
    local width, height = get_hud_metrics(hud)
    return clamp(math.min(width / 1920, height / 1080), 0.82, 1.18)
  end

  local function scaled(value, scale)
    return round_number(value * scale)
  end

  local function set_percent_pos(ui, x, y)
    GameAPI.set_ui_comp_pos_percent(env.get_player().handle, ui.handle, x, y)
  end

  local function create_fullscreen_root(hud)
    local root = hud:create_child('图片')
    root:set_image(ui_res.common.empty)
    root:set_relative_parent_pos('顶部', 0)
    root:set_relative_parent_pos('底部', 0)
    root:set_relative_parent_pos('左侧', 0)
    root:set_relative_parent_pos('右侧', 0)
    root:set_image_color(6, 10, 18, 214)
    root:set_z_order(9700)
    root:set_intercepts_operations(true)
    return root
  end

  local function create_panel(parent, x, y, width, height, color, z_order)
    local panel = parent:create_child('图片')
    panel:set_image(ui_res.common.empty)
    panel:set_ui_size(width, height)
    panel:set_pos(x, y)
    panel:set_image_color(color[1], color[2], color[3], color[4] or 255)
    panel:set_ui_9_enable(true)
    panel:set_ui_9(18, 18, 18, 18)
    if z_order then
      panel:set_z_order(z_order)
    end
    return panel
  end

  local function create_text(parent, x, y, width, height, font_size, color, h_align, v_align, z_order)
    local text = parent:create_child('文本')
    text:set_ui_size(width, height)
    text:set_pos(x, y)
    text:set_font_size(font_size)
    text:set_text_color(color[1], color[2], color[3], color[4] or 255)
    text:set_text_alignment(h_align or '中', v_align or '中')
    if z_order then
      text:set_z_order(z_order)
    end
    return text
  end

  local function create_button(parent, x, y, width, height, label, callback, font_size)
    local bg = create_panel(parent, x, y, width, height, { 46, 76, 114, 234 }, 9702)
    local button = parent:create_child('按钮')
    button:set_ui_size(width, height)
    button:set_pos(x, y)
    button:set_text(label)
    button:set_font_size(font_size or 18)
    button:set_text_color(244, 248, 255, 255)
    button:set_btn_status_image(1, ui_res.common_tip.btn_blue_normal)
    button:set_btn_status_image(2, ui_res.common_tip.btn_blue_hover)
    button:set_btn_status_image(3, ui_res.common_tip.btn_blue_press)
    button:set_btn_status_image(4, ui_res.common_tip.btn_blue_disabled)
    button:set_z_order(9703)
    button:add_fast_event('左键-点击', function()
      callback()
    end)
    return {
      bg = bg,
      button = button,
    }
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

    for _, stage_def in ipairs(STAGE_LIST) do
      if ensure_stage_progress_defaults(profile, stage_def.stage_id) then
        dirty = true
      end
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

  local function get_stage_status_text(profile, stage_def)
    local progress = get_stage_progress(profile, stage_def.stage_id)
    if not progress or not progress.standard_unlocked then
      return '未解锁'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return '当前复用 1-1 内容'
    end
    if progress.standard_cleared then
      return '标准已通关'
    end
    return '当前章节内容已接入'
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
      return '当前选择无效。'
    end
    if not is_standard_unlocked(profile, stage_id) then
      return '当前章节尚未开放，先通关上一章标准模式。'
    end
    if mode_id == 'challenge' and not is_mode_unlocked(profile, stage_id, mode_id) then
      return '挑战模式需先通关本章标准模式后解锁。'
    end
    if stage_def.content_source_stage_id ~= stage_def.stage_id then
      return '本章暂复用 1-1 战斗内容，先用于验证局外流程与章节解锁。'
    end
    return '当前章节内容已接入，可以直接开始战斗。'
  end

  local function format_last_result(profile)
    local result = profile and profile.last_result or nil
    if type(result) ~= 'table' or not result.stage_id or not result.mode_id then
      return '最近结果：暂无记录'
    end

    local outcome = result.is_win and '胜利' or '失败'
    local stage_def = STAGES_BY_ID[result.stage_id]
    local mode_def = MODES_BY_ID[result.mode_id]
    local stage_name = stage_def and stage_def.display_name or tostring(result.stage_id)
    local mode_name = mode_def and mode_def.display_name or tostring(result.mode_id)
    local reached_wave = math.max(0, result.reached_wave_index or 0)

    return string.format(
      '最近结果：%s  %s  %s  到达波次 %d',
      stage_name,
      mode_name,
      outcome,
      reached_wave
    )
  end

  local function is_outgame_ui_alive(ui)
    return ui
      and ui.root
      and not ui.root:is_removed()
      and ui.stage_cards
      and ui.detail_panel
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

    for _, stage_def in ipairs(STAGE_LIST) do
      local card = ui.stage_cards[stage_def.stage_id]
      local selected = stage_def.stage_id == selected_stage_id
      local unlocked = is_standard_unlocked(profile, stage_def.stage_id)
      local status_text = get_stage_status_text(profile, stage_def)

      if selected then
        card.bg:set_image_color(48, 86, 138, 238)
      elseif unlocked then
        card.bg:set_image_color(20, 34, 54, 226)
      else
        card.bg:set_image_color(16, 24, 36, 218)
      end

      card.title:set_text(stage_def.display_name)
      card.note:set_text(stage_def.preview_note or '')
      card.status:set_text(status_text)
      if unlocked then
        card.status:set_text_color(210, 228, 242, 255)
      else
        card.status:set_text_color(176, 160, 132, 255)
      end
    end

    ui.detail_title:set_text(selected_stage_def.display_name)
    ui.detail_note:set_text(selected_stage_def.preview_note or '')
    ui.detail_status:set_text(build_start_hint(profile, selected_stage_id, selected_mode_id))
    ui.last_result:set_text(format_last_result(profile))

    for mode_id, button_ref in pairs(ui.mode_buttons) do
      local unlocked = is_mode_unlocked(profile, selected_stage_id, mode_id)
      local selected = selected_mode_id == mode_id
      button_ref.button:set_text(get_mode_button_text(profile, selected_stage_id, mode_id))
      button_ref.button:set_button_enable(unlocked)
      if selected and unlocked then
        button_ref.bg:set_image_color(54, 108, 172, 236)
      elseif unlocked then
        button_ref.bg:set_image_color(54, 78, 112, 226)
      else
        button_ref.bg:set_image_color(38, 42, 56, 206)
      end
    end

    local start_enabled = is_mode_unlocked(profile, selected_stage_id, selected_mode_id)
    ui.start_button.button:set_button_enable(start_enabled)
    if start_enabled then
      ui.start_button.bg:set_image_color(76, 126, 90, 236)
      ui.start_hint:set_text('点击开始进入本局。')
    else
      ui.start_button.bg:set_image_color(58, 62, 72, 214)
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

    local scale = get_hud_scale(hud)
    local root = create_fullscreen_root(hud)

    local container = create_panel(
      root,
      scaled(740, scale),
      scaled(410, scale),
      scaled(1500, scale),
      scaled(820, scale),
      { 9, 15, 24, 228 },
      9701
    )
    container:set_anchor(0.5, 0.5)
    set_percent_pos(container, 50, 50)

    local title = create_text(
      container,
      scaled(190, scale),
      scaled(760, scale),
      scaled(440, scale),
      scaled(42, scale),
      scaled(30, scale),
      { 245, 248, 255, 255 },
      '左',
      '中',
      9702
    )
    title:set_text('局外选关')

    local subtitle = create_text(
      container,
      scaled(230, scale),
      scaled(720, scale),
      scaled(520, scale),
      scaled(24, scale),
      scaled(14, scale),
      { 164, 186, 212, 255 },
      '左',
      '中',
      9702
    )
    subtitle:set_text('第一版先接通章节、模式、结算回流与存档骨架。')

    local stage_list_panel = create_panel(
      container,
      scaled(300, scale),
      scaled(390, scale),
      scaled(460, scale),
      scaled(620, scale),
      { 15, 24, 38, 232 },
      9701
    )
    local stage_list_title = create_text(
      stage_list_panel,
      scaled(112, scale),
      scaled(580, scale),
      scaled(180, scale),
      scaled(24, scale),
      scaled(18, scale),
      { 232, 240, 252, 255 },
      '左',
      '中',
      9702
    )
    stage_list_title:set_text('章节列表')

    local detail_panel = create_panel(
      container,
      scaled(1050, scale),
      scaled(390, scale),
      scaled(930, scale),
      scaled(620, scale),
      { 14, 22, 34, 232 },
      9701
    )

    local detail_title = create_text(
      detail_panel,
      scaled(140, scale),
      scaled(576, scale),
      scaled(320, scale),
      scaled(28, scale),
      scaled(24, scale),
      { 245, 248, 255, 255 },
      '左',
      '中',
      9702
    )
    local detail_note = create_text(
      detail_panel,
      scaled(180, scale),
      scaled(540, scale),
      scaled(760, scale),
      scaled(22, scale),
      scaled(14, scale),
      { 172, 192, 214, 255 },
      '左',
      '中',
      9702
    )
    local detail_status = create_text(
      detail_panel,
      scaled(440, scale),
      scaled(488, scale),
      scaled(760, scale),
      scaled(54, scale),
      scaled(16, scale),
      { 214, 228, 242, 255 },
      '左',
      '中',
      9702
    )
    local mode_title = create_text(
      detail_panel,
      scaled(110, scale),
      scaled(414, scale),
      scaled(160, scale),
      scaled(24, scale),
      scaled(18, scale),
      { 232, 240, 252, 255 },
      '左',
      '中',
      9702
    )
    mode_title:set_text('模式选择')

    local mode_buttons = {
      standard = create_button(
        detail_panel,
        scaled(232, scale),
        scaled(340, scale),
        scaled(324, scale),
        scaled(72, scale),
        '标准模式',
        function()
          if set_selected_mode('standard') then
            refresh_ui()
          end
        end,
        scaled(16, scale)
      ),
      challenge = create_button(
        detail_panel,
        scaled(592, scale),
        scaled(340, scale),
        scaled(324, scale),
        scaled(72, scale),
        '挑战模式',
        function()
          if set_selected_mode('challenge') then
            refresh_ui()
          end
        end,
        scaled(16, scale)
      ),
    }

    local start_button = create_button(
      detail_panel,
      scaled(274, scale),
      scaled(208, scale),
      scaled(572, scale),
      scaled(72, scale),
      '开始本局',
      function()
        api.start_selected_stage()
      end,
      scaled(22, scale)
    )
    local start_hint = create_text(
      detail_panel,
      scaled(456, scale),
      scaled(156, scale),
      scaled(700, scale),
      scaled(28, scale),
      scaled(14, scale),
      { 168, 186, 210, 255 },
      '中',
      '中',
      9702
    )
    local last_result = create_text(
      detail_panel,
      scaled(458, scale),
      scaled(84, scale),
      scaled(800, scale),
      scaled(52, scale),
      scaled(16, scale),
      { 220, 232, 246, 255 },
      '中',
      '中',
      9702
    )

    local stage_cards = {}
    local card_y = scaled(486, scale)
    local card_step = scaled(166, scale)
    for index, stage_def in ipairs(STAGE_LIST) do
      local y = card_y - (index - 1) * card_step
      local card_bg = create_panel(
        stage_list_panel,
        scaled(230, scale),
        y,
        scaled(380, scale),
        scaled(132, scale),
        { 20, 34, 52, 228 },
        9702
      )
      local card_button = stage_list_panel:create_child('按钮')
      card_button:set_ui_size(scaled(380, scale), scaled(132, scale))
      card_button:set_pos(scaled(230, scale), y)
      card_button:set_text('')
      card_button:set_btn_status_image(1, ui_res.common.empty)
      card_button:set_btn_status_image(2, ui_res.common.empty)
      card_button:set_btn_status_image(3, ui_res.common.empty)
      card_button:set_btn_status_image(4, ui_res.common.empty)
      card_button:set_z_order(9704)
      card_button:add_fast_event('左键-点击', function()
        if set_selected_stage(stage_def.stage_id) then
          refresh_ui()
        end
      end)

      local card_title = create_text(
        card_bg,
        scaled(108, scale),
        scaled(98, scale),
        scaled(180, scale),
        scaled(24, scale),
        scaled(20, scale),
        { 244, 248, 255, 255 },
        '左',
        '中',
        9705
      )
      local card_note = create_text(
        card_bg,
        scaled(152, scale),
        scaled(60, scale),
        scaled(296, scale),
        scaled(20, scale),
        scaled(13, scale),
        { 166, 188, 214, 255 },
        '左',
        '中',
        9705
      )
      local card_status = create_text(
        card_bg,
        scaled(188, scale),
        scaled(24, scale),
        scaled(312, scale),
        scaled(18, scale),
        scaled(13, scale),
        { 214, 228, 242, 255 },
        '左',
        '中',
        9705
      )

      stage_cards[stage_def.stage_id] = {
        bg = card_bg,
        button = card_button,
        title = card_title,
        note = card_note,
        status = card_status,
      }
    end

    STATE.outgame_ui = {
      root = root,
      container = container,
      title = title,
      subtitle = subtitle,
      stage_list_panel = stage_list_panel,
      detail_panel = detail_panel,
      stage_cards = stage_cards,
      detail_title = detail_title,
      detail_note = detail_note,
      detail_status = detail_status,
      mode_buttons = mode_buttons,
      start_button = start_button,
      start_hint = start_hint,
      last_result = last_result,
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

  return api
end

return M
