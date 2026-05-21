local ui_root = require 'ui.ui_root'
local hero_evolutions = require 'data.tables.outgame.hero_evolutions'
local game_tables_hero_roster = require 'data.simple_data'.load_hero_roster()
local IconResolver = require 'data.tables.icon_resolver'
local hud_core = require 'ui.hud.hud_core'
local M = {}
local DEFAULT_TIP_DURATION = 8;
local EVOLUTION_SLOT_COUNT = 5;
local BUFF_SLOT_COUNT = 5;
local ATTR_ROW_NAMES = { 'battle_power_row', 'hero_attack_row', 'hero_defense_row', 'hero_power_row', 'hero_intelligence_row',
  'hero_agility_row' }
local HERO_MODEL_FRAME_SIZE = {
  width = 108,
  height = 122,
  x = 92,
  y = 142
}
local HERO_MODEL_CAMERA = {
  focus = { 0, 0, 1.0 },
  fov = 20,
  camera_pos = { 0, -0.2, 2.5 },
  camera_rot = { 0, 0, 0 },
  background = { 0, 0, 0, 0 }
}
local EXP_BAR_MAX_WIDTH = 260;
local EXP_BAR_HEIGHT = 12;
local EXP_BAR_X_OFFSET = 122;
local DETAIL_TIP_WIDTH = 360;
local DETAIL_TIP_CONTENT_WIDTH = 322;
local DETAIL_TIP_MIN_HEIGHT = 176;
local DETAIL_TIP_MAX_HEIGHT = 424;
local DETAIL_TIP_LINE_HEIGHT = 17;
local DETAIL_TIP_CONTENT_GAP = 8;
local RARITY_NAME_MAP = {
  common = '普通',
  rare = '稀有',
  epic = '史诗'
}
local evolutions_by_id = hero_evolutions.by_id or {}

local function resolve_display_icon(...)
  return IconResolver.pick(...)
end

function M.create(params)
  local STATE = params and params.STATE or _G.STATE;
  local CONFIG = params and params.CONFIG or _G.CONFIG or {}
  local y3 = params and params.y3 or _G.y3 or y3;
  local skill_slot_count = math.max(1, tonumber(params and params.attack_skill_slot_count or _G.ATTACK_SKILL_SLOT_COUNT) or 5)
  local get_player_fn = params and params.get_player or y3.player.get_main_player;
  local hero_attr_system_ref = params and params.hero_attr_system or _G.hero_attr_system;

  local try_evolution_entry = params and params.try_evolution_entry or _G.try_evolution_entry or function() end;
  local try_start_challenge = params and params.try_start_challenge or _G.try_start_challenge or function() end;
  local open_save_panel = params and params.open_save_panel or _G.open_save_panel or function() end;
  local show_runtime_status = params and params.show_runtime_status or _G.show_runtime_status or function() end;
  local build_runtime_attr_dialog_chunks = params and params.build_runtime_attr_dialog_chunks or _G.build_runtime_attr_dialog_chunks or function() end;
  local get_status_effects_fn = params and params.get_bottom_status_effect_entries or _G.get_bottom_status_effect_entries or function() return {} end;
  local play_ui_click_fn = params and params.play_ui_click or _G.play_ui_click or function() end;
  local hero_model = params and params.hero_model or _G.hero_model
  -- UI 工具函数 (from ui.hud.hud_core)
  local core = hud_core.create({
    y3 = y3,
    ui_root = ui_root,
    STATE = STATE,
    get_player_fn = get_player_fn,
    HERO_MODEL_FRAME_SIZE = HERO_MODEL_FRAME_SIZE,
    HERO_MODEL_CAMERA = HERO_MODEL_CAMERA,
    hero_roster = game_tables_hero_roster,
    CONFIG = CONFIG,
    hero_model = hero_model,
  })
  local is_ui_alive = core.is_ui_alive
  local get_player = core.get_player
  local get_hud_state = core.get_hud_state
  local ensure_ui_preferences = core.ensure_ui_preferences
  local resolve_ui_node = core.resolve_ui_node
  local resolve_first_ui_node = core.resolve_first_ui_node
  local safe_ui_call = core.safe_ui_call
  local set_ui_visible = core.set_ui_visible
  local set_ui_text = core.set_ui_text
  local set_ui_text_color = core.set_ui_text_color
  local set_ui_font_size = core.set_ui_font_size
  local set_ui_text_alignment = core.set_ui_text_alignment
  local set_ui_image = core.set_ui_image
  local set_ui_image_color = core.set_ui_image_color
  local set_ui_size = core.set_ui_size
  local set_ui_anchor = core.set_ui_anchor
  local set_ui_pos = core.set_ui_pos
  local set_ui_progress = core.set_ui_progress
  local bind_ui_model_unit = core.bind_ui_model_unit
  local apply_ui_model_camera = core.apply_ui_model_camera
  local set_ui_pos_percent = core.set_ui_pos_percent
  local format_short_number = core.format_short_number
  local format_time_mmss = core.format_time_mmss
  local normalize_percent_value = core.normalize_percent_value
  local format_percent = core.format_percent
  local format_percent_delta = core.format_percent_delta
  local toggle_big_cursor
  local toggle_damage_text_visible
  local toggle_hit_effects_visible
  local toggle_soft_pause
  local toggle_runtime_attr_panel
  local ensure_hud
  local refresh_hud
  local set_hud_visible
  local show_runtime_tip_panel

  local function format_signed_number(aI)
    local aJ = tonumber(aI) or 0;
    local aW = aJ >= 0 and '+' or '-'
    return aW .. format_short_number(math.abs(aJ))
  end;

  local function get_hero_attr(b1, b2)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then return 0 end;

    local aI = hero_attr_system_ref and hero_attr_system_ref.get_attr(STATE.hero, b1) or STATE.hero:get_attr(b1)
    aI = tonumber(aI) or 0;
    if aI ~= 0 or not b2 then return aI end;

    local b3 = hero_attr_system_ref and hero_attr_system_ref.get_attr(STATE.hero, b2) or STATE.hero:get_attr(b2)
    return tonumber(b3) or 0
  end;

  local function get_hero_level() return math.max(1, math.floor(tonumber(STATE.hero_progress and STATE.hero_progress.level) or 1)) end;

  local function get_hero_name()
    local initial_hero = game_tables_hero_roster.initial_hero
    if initial_hero and initial_hero.name then
      return initial_hero.name
    end
    
    if STATE.hero and STATE.hero.get_name and STATE.hero:is_exist() then
      local b1 = STATE.hero:get_name()
      if b1 and b1 ~= '' then return b1 end
    end;

    return '英雄'
  end;

  local function get_hero_icon()
    if STATE.hero and STATE.hero.get_icon and STATE.hero:is_exist() then return STATE.hero:get_icon() end;

    return nil
  end;

  local function get_unit_type_icon(b8)
    if b8 and y3 and y3.unit and y3.unit.get_icon_by_key then return y3.unit.get_icon_by_key(b8) end;

    return nil
  end;

  local function get_hero_unit()
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() then return STATE.hero end;

    return nil
  end;

  local function get_hero_real_model_id()
    if hero_model and hero_model.get_active_model_id then
      return hero_model.get_active_model_id()
    end
    local evo_runtime = STATE.evolution_runtime
    if evo_runtime and evo_runtime.active_form_model_id then
      return evo_runtime.active_form_model_id
    end
    local initial_hero = game_tables_hero_roster.initial_hero
    if initial_hero and initial_hero.model_id then
      return initial_hero.model_id
    end
    return nil
  end;

  local function get_player_name()
    local player = get_player()
    if player and player.get_name then
      local b1 = player:get_name()
      if b1 and b1 ~= '' then return b1 end
    end;

    return '玩家'
  end;

  local function get_hero_hp_info()
    local bc = STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist()
        and (tonumber(STATE.hero:get_hp()) or 0) or 0;
    local bd = math.max(1, get_hero_attr('生命结算值', '生命'))
    return bc, bd
  end;

  local function get_hero_exp_info()
    local bf = tonumber(STATE.hero_progress and STATE.hero_progress.exp) or 0;
    local bg = tonumber(STATE.hero_progress and STATE.hero_progress.exp_to_next) or 1;
    if bg <= 0 then bg = math.max(1, bf) end;

    return bf, bg
  end;

  local function has_pending_evolution_choice()
    local evo_runtime = STATE.evolution_runtime;
    return evo_runtime and evo_runtime.awaiting_choice == true and evo_runtime.current_choices and #evo_runtime.current_choices > 0 or false
  end;

  local function get_hero_item_by_slot(bm)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() or not STATE.hero.get_item_by_slot then return nil end;

    local bn,
    bo = pcall(STATE.hero.get_item_by_slot, STATE.hero, '物品栏', bm)
    if not bn then return nil end;

    return bo
  end;

  local function get_item_display_info(bo)
    if not bo then return nil, nil end;

    local bz = bo.get_name and bo:get_name() or '物品'
    local bt = {}
    local bA = bo.get_description and bo:get_description() or nil;
    if bA and bA ~= '' then bt[#bt + 1] = tostring(bA) end;

    local bB = bo.get_stack and tonumber(bo:get_stack()) or 0;
    if bB and bB > 1 then bt[#bt + 1] = string.format('层数%d', bB) end;

    local bC = bo.get_charge and tonumber(bo:get_charge()) or 0;
    if bC and bC > 0 then bt[#bt + 1] = string.format('充能%d', bC) end;
    if #bt == 0 then bt[#bt + 1] = '当前没有额外说明' end;

    return tostring(bz), table.concat(bt, '\n')
  end;

  local function append_line(bE, ac)
    local aI = tostring(ac or '')
    if aI ~= '' then bE[#bE + 1] = aI end
  end;

  local function append_lines(bE, bt)
    for a_, bv in ipairs(bt or {})
    do append_line(bE, bv) end
  end;

  local function append_multiline_text(bE, ac)
    local aI = tostring(ac or '')
    if aI == '' then return end;

    for bv in aI:gmatch('[^\n]+') do append_line(bE, bv) end
  end;

  local function build_slot_tooltip(bm)
    local bo = get_hero_item_by_slot(bm)
    local bz,
    bJ = get_item_display_info(bo)
    if not bz or not bJ then return nil end;

    return {
      title = bz,
      subtitle = '',
      body = bJ,
      icon = bo and bo.get_icon and bo:get_icon() or nil
    }
  end;

  local function build_draw_tooltip()
    local bt = { '[左键点击]', string.format('本次消耗%d 个木材', 100), string.format('当前拥有 %s 木材',
      format_short_number(STATE.resources and STATE.resources.wood or 0)), '', '抽取流派卡牌，相同流派会自动收录进卡册' }
    return {
      title = '抽卡 - [快捷键：F]',
      subtitle = '',
      body = table.concat(bt, '\n'),
      icon = nil
    }
  end;

  local function build_hero_catalog_tooltip()
    local bt = { '[左键点击]', '打开英雄图鉴面板', '可查看英雄定位、核心技能与星级' }
    return {
      title = '如何变强',
      subtitle = '',
      body = table.concat(bt, '\n'),
      icon = nil
    }
  end;

  local function build_evolution_entry_tooltip()
    local bt = { '[左键点击]', '已改为新英雄功能入口，请点击"如何变强"进入英雄图鉴' }
    return {
      title = '英雄进阶入口 - [快捷键：H]',
      subtitle = '',
      body = table.concat(bt, '\n'),
      icon = nil
    }
  end;

  local function build_save_panel_tooltip()
    local bt = { '[左键点击]', '打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态' }
    return {
      title = '存档 - [快捷键：P]',
      subtitle = '',
      body = table.concat(bt, '\n'),
      icon = nil
    }
  end;

  local function build_consumable_tooltip(bm)
    if bm == 1 then
      return {
        title = '属性宝石',
        subtitle = '类型：消耗品',
        body = table.concat({ '[点击使用]', '可选择一条随机属性强化，英雄每升 5 级，或完成宝石挑战时，可获得 1 颗' }, '\n'),
        icon = 300540000
      }
    end;

    if bm == 2 then
      return {
        title = '快捷道具 2',
        subtitle = '特殊栏位',
        body = '当前用于特殊功能扩展',
        icon = nil
      }
    end;

    if bm == 3 then
      return {
        title = '快捷道具 3',
        subtitle = '特殊栏位',
        body = '当前用于特殊功能扩展',
        icon = nil
      }
    end;

    return nil
  end;

  local function build_attack_skill_entry(slot_data, slot_index)
    if not slot_data then return nil end;

    local tip_lines = {}
    if slot_data.summary and slot_data.summary ~= '' then tip_lines[#tip_lines + 1] = tostring(slot_data.summary) end;

    local damage_ratio = tonumber(slot_data.damage_ratio) or 0;
    if damage_ratio > 0 then tip_lines[#tip_lines + 1] = string.format('倍率%.0f%%', damage_ratio * 100) end;

    local cast_range = math.max(0, tonumber(slot_data.cast_range or 0) + tonumber(slot_data.range_bonus or 0))
    if cast_range > 0 then tip_lines[#tip_lines + 1] = string.format('射程%d', math.floor(cast_range + 0.5)) end;

    local base_cooldown = tonumber(slot_data.base_cooldown) or 0;
    if base_cooldown > 0 then tip_lines[#tip_lines + 1] = string.format('基础冷却%.1fs', base_cooldown) end;

    local cooldown_remaining = tonumber(slot_data.cooldown_remaining) or 0;
    local cooldown_text = '就绪'
    if cooldown_remaining > 0 then
      cooldown_text = string.format('%.1fs', cooldown_remaining)
    elseif cooldown_remaining < 0 then
      cooldown_text = '就绪'
    end
    return {
      id = tostring(slot_data.id or 'skill_' .. tostring(slot_index)),
      name = tostring(slot_data.name or slot_data.id or '技能' .. tostring(slot_index)),
      icon = resolve_display_icon(slot_data.icon_res, slot_data.ui_icon, slot_data.icon, slot_data.bg),
      key = tostring(slot_index),
      cooldown_text = cooldown_text,
      legacy_cooldown_text = cooldown_remaining > 0 and string.format('%.1f', cooldown_remaining) or '',
      badge_text = slot_data.level and 'Lv.' .. tostring(slot_data.level) or '',
      stack_text = '',
      tip_title = tostring(slot_data.name or slot_data.id or '技能'),
      tip_text = #tip_lines > 0 and table.concat(tip_lines, '\n') or '当前没有技能说明'
    }
  end;

  local function normalize_rarity_display(rarity_key) return RARITY_NAME_MAP[rarity_key] or '普通' end;

  local function get_evolution_runtime() return STATE.evolution_runtime end;

  local function get_hero_roster_and_entry(unit_def)
    return game_tables_hero_roster.initial_hero
  end;

  local function build_evolution_skill_entry(evo_def, slot_index)
    if not evo_def then return nil end;

    local roster_entry = get_hero_roster_and_entry(evo_def)
    local display_name = roster_entry and roster_entry.name or evo_def.name or '专精' .. tostring(slot_index)
    local display_title = '英雄真身'
    local description = roster_entry and roster_entry.summary or evo_def.summary or ''
    local tip_lines = { string.format('[%s] %s', normalize_rarity_display(evo_def.quality), display_title) }

    if description ~= '' then tip_lines[#tip_lines + 1] = tostring(description) end;

    return {
      id = tostring(evo_def.id or 'evolution_' .. tostring(slot_index)),
      name = tostring(display_name),
      icon = resolve_display_icon(
        roster_entry and roster_entry.skill_icon or nil,
        roster_entry and roster_entry.icon or nil,
        roster_entry and roster_entry.bg or nil,
        get_unit_type_icon(evo_def.hero_unit_id),
        get_hero_icon()
      ),
      key = tostring(slot_index),
      cooldown_text = '',
      legacy_cooldown_text = '',
      badge_text = normalize_rarity_display(evo_def.quality),
      stack_text = '',
      tip_title = string.format('%s·%s', tostring(display_name), tostring(display_title)),
      tip_text = table.concat(tip_lines, '\n')
    }
  end;

  local function get_skill_slot_entries(max_slots)
    local entries = {}
    local skill_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots or nil;
    for slot_index = 1, math.min(skill_slot_count, max_slots or skill_slot_count) do
      local slot_data = skill_slots and skill_slots[slot_index] or nil;
      if slot_data and slot_data.id ~= 'basic_attack' then entries[#entries + 1] = build_attack_skill_entry(slot_data, slot_index) end
    end;
    

    return entries
  end;

  local function get_evolution_slot_entries(count)
    local entries = {}
    local max_count = math.max(1, tonumber(count) or EVOLUTION_SLOT_COUNT)
    local evo_runtime = get_evolution_runtime()
    local evolution_ids = evo_runtime and (evo_runtime.ordered_evolution_ids) or nil;
    for bL = 1, max_count, 1 do
      local evo_id = evolution_ids and evolution_ids[bL] or nil;
      local evo_def = evo_id and evolutions_by_id[evo_id] or nil;
      if evo_def then
        local entry = build_evolution_skill_entry(evo_def, bL)
        if entry then entries[#entries + 1] = entry end
      end
    end;

    return entries
  end;

  local function get_skill_entry_by_slot(bL)
    if bL < 1 or bL > skill_slot_count then return nil end;

    local skill_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots or nil;
    local slot_data = skill_slots and skill_slots[bL] or nil;
    if slot_data and slot_data.id == 'basic_attack' then return nil end;
    return build_attack_skill_entry(slot_data, bL)
  end;

  local function get_pending_choice_status()
    local ct = STATE.evolution_runtime;
    if ct and ct.awaiting_choice and ct.current_choices then return '英雄功能提示', '进阶已迁移到新英雄功能，请打开英雄图鉴查看' end;

    return nil, nil
  end;

  local function get_current_tip_text()
    local hud_state = get_hud_state()
    if hud_state.tip_panel and hud_state.tip_expires_at and hud_state.tip_expires_at > (STATE.runtime_elapsed or 0) then return
      hud_state.tip_title_text ~= '' and hud_state.tip_title_text or '系统提示', hud_state.tip_body_text or '' end;

    local choice_label,
    choice_hint = get_pending_choice_status()
    if choice_label and choice_hint then return choice_label, choice_hint end;

    local ck = STATE.battle_event_feed and STATE.battle_event_feed.entries or nil;
    if ck and #ck > 0 then
      local c4 = ck[#ck]
      if c4 and c4.text and c4.text ~= '' then
        if c4.style == 'reward' then return '奖励提示', c4.text end;

        if c4.style == 'warning' then return '战斗警报', c4.text end;

        if c4.style == 'rare' then return '稀有事件', c4.text end;

        if c4.style == 'positive' then return '进度更新', c4.text end;

        return '系统消息', c4.text
      end
    end;

    return '操作提示', 'F 抽卡，如何变强查看英雄图鉴，H 查看英雄功能，P 打开存档'
  end;

  local function get_status_bar_text()
    local X = ensure_ui_preferences()
    local choice_label,
    _ = get_pending_choice_status()
    if choice_label then return '状态：' .. choice_label end;

    local damage_text_status = X.hide_damage_text and '跳字关' or '跳字开'
    local hit_effects_status = X.hide_hit_effects and '特效关' or '特效开'
    local pause_status = X.soft_paused and '已暂停' or '进行中'
    return string.format('状态：%s | %s | %s', damage_text_status, hit_effects_status, pause_status)
  end;

  local function get_station_hint_text() return '按F抽卡；点击如何变强查看英雄图鉴' end;

  local function get_hotkey_help_text() return table.concat(
    { 'F / 抽卡：流派三选一', '如何变强：查看英雄图鉴', 'H / 英雄功能：查看图鉴与成长', 'Q / W / E：试炼入口', 'TAB / T：属性面板', 'SPACE：打印状态概况', 'P：打开存档' },
      '\n') end;

  local function resolve_static_ui_panels()
    local hud_state = get_hud_state()
    hud_state.attr_panel = resolve_first_ui_node({ 'BattleBottomHUD.layout.attr_panel',
      'BattleBottomHUD.layout.right_station.attr_panel' })
    hud_state.attr_panel_title = resolve_first_ui_node({ 'BattleBottomHUD.layout.attr_panel.title',
      'BattleBottomHUD.layout.right_station.attr_panel.title' })
    hud_state.attr_panel_body = resolve_first_ui_node({ 'BattleBottomHUD.layout.attr_panel.body',
      'BattleBottomHUD.layout.right_station.attr_panel.body' })
    hud_state.attr_panel_hint = resolve_first_ui_node({ 'BattleBottomHUD.layout.attr_panel.hint',
      'BattleBottomHUD.layout.right_station.attr_panel.hint' })
    set_ui_visible(hud_state.attr_panel, false)
    safe_ui_call(hud_state.attr_panel, 'set_intercepts_operations', true)
    set_ui_text_alignment(hud_state.attr_panel_title, ', ')
    set_ui_text_alignment(hud_state.attr_panel_body, ', ')
    set_ui_text_alignment(hud_state.attr_panel_hint, ', ')
    if hud_state.bound_events.static_attr_panel_close ~= hud_state.attr_panel and is_ui_alive(hud_state.attr_panel) then
      hud_state.bound_events.static_attr_panel_close = hud_state.attr_panel; hud_state.attr_panel:add_fast_event('左键-点击', function()
        local hud_state_inner = get_hud_state()
        hud_state_inner.attr_panel_visible = false; set_ui_visible(hud_state_inner.attr_panel, false)
      end)
    end;
    hud_state.tip_panel = resolve_first_ui_node({ 'BattleBottomHUD.layout.tip_panel',
      'BattleBottomHUD.layout.right_station.tip_panel' })
    hud_state.tip_panel_title = resolve_first_ui_node({ 'BattleBottomHUD.layout.tip_panel.title',
      'BattleBottomHUD.layout.right_station.tip_panel.title' })
    hud_state.tip_panel_body = resolve_first_ui_node({ 'BattleBottomHUD.layout.tip_panel.body',
      'BattleBottomHUD.layout.right_station.tip_panel.body' })
    hud_state.tip_panel_hint = resolve_first_ui_node({ 'BattleBottomHUD.layout.tip_panel.hint',
      'BattleBottomHUD.layout.right_station.tip_panel.hint' })
    set_ui_visible(hud_state.tip_panel, false)
    safe_ui_call(hud_state.tip_panel, 'set_intercepts_operations', true)
    set_ui_text_alignment(hud_state.tip_panel_title, ', ')
    set_ui_text_alignment(hud_state.tip_panel_body, ', ')
    set_ui_text_alignment(hud_state.tip_panel_hint, ', ')
    if hud_state.bound_events.static_tip_panel_close ~= hud_state.tip_panel and is_ui_alive(hud_state.tip_panel) then
      hud_state.bound_events.static_tip_panel_close = hud_state.tip_panel; hud_state.tip_panel:add_fast_event('左键-点击', function()
        local hud_state_inner = get_hud_state()
        hud_state_inner.tip_expires_at = 0; set_ui_visible(hud_state_inner.tip_panel, false)
      end)
    end;
    hud_state.hover_tip_panel = resolve_first_ui_node({ 'BattleBottomHUD.layout.right_station.hover_tip_panel',
      'BattleBottomHUD.layout.hover_tip_panel' })
    hud_state.hover_tip_panel_icon_bg = resolve_first_ui_node({ 'BattleBottomHUD.layout.right_station.hover_tip_panel.icon_bg',
      'BattleBottomHUD.layout.hover_tip_panel.icon_bg' })
    hud_state.hover_tip_panel_icon = resolve_first_ui_node({ 'BattleBottomHUD.layout.right_station.hover_tip_panel.icon',
      'BattleBottomHUD.layout.hover_tip_panel.icon' })
    hud_state.hover_tip_panel_title = resolve_first_ui_node({ 'BattleBottomHUD.layout.right_station.hover_tip_panel.title',
      'BattleBottomHUD.layout.hover_tip_panel.title' })
    hud_state.hover_tip_panel_subtitle = resolve_first_ui_node({ 'BattleBottomHUD.layout.right_station.hover_tip_panel.subtitle',
      'BattleBottomHUD.layout.hover_tip_panel.subtitle' })
    hud_state.hover_tip_panel_body = resolve_first_ui_node({ 'BattleBottomHUD.layout.right_station.hover_tip_panel.body',
      'BattleBottomHUD.layout.hover_tip_panel.body' })
    set_ui_visible(hud_state.hover_tip_panel, false)
    safe_ui_call(hud_state.hover_tip_panel, 'set_intercepts_operations', false)
    set_ui_text_alignment(hud_state.hover_tip_panel_title, ', ')
    set_ui_text_alignment(hud_state.hover_tip_panel_subtitle, ', ')
    set_ui_text_alignment(hud_state.hover_tip_panel_body, ', ')
    hud_state.bond_tip_root = resolve_first_ui_node({ 'BattleDetailTipsPanel', 'TipsPanel' })
    hud_state.bond_tip_uses_dedicated_root = is_ui_alive(resolve_ui_node('BattleDetailTipsPanel'))
    hud_state.bond_tip_panel = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel', 'TipsPanel.详情面板', '详情面板' })
    hud_state.bond_tip_panel_bg = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.panel_bg' })
    hud_state.bond_tip_panel_edge = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.panel_edge' })
    hud_state.bond_tip_title_bar = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.title_bar' })
    hud_state.bond_tip_divider_top = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.divider_top' })
    hud_state.bond_tip_divider_bottom = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.divider_bottom' })
    hud_state.bond_tip_icon_box = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.icon_box' })
    hud_state.bond_tip_icon_bg = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.icon_box.icon_bg' })
    hud_state.bond_tip_title = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.title', 'TipsPanel.详情面板.列表.标题', '详情面板.列表.标题' })
    hud_state.bond_tip_subtitle = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.subtitle', 'TipsPanel.详情面板.列表.副标题', '详情面板.列表.副标题' })
    hud_state.bond_tip_contents = {}
    for i = 1, 5 do
      hud_state.bond_tip_contents[i] = resolve_first_ui_node({
        'BattleDetailTipsPanel.detail_panel.content_' .. tostring(i),
        'TipsPanel.详情面板.列表.内容' .. tostring(i),
        '详情面板.列表.内容' .. tostring(i)
      })
    end
    hud_state.bond_tip_bottom = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.bottom', 'TipsPanel.详情面板.列表.底部内容', '详情面板.列表.底部内容' })
    hud_state.bond_tip_icon = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.icon_box.icon', 'TipsPanel.详情面板.图标.图标', '详情面板.图标.图标' })
    hud_state.bond_tip_icon_name = resolve_first_ui_node({ 'BattleDetailTipsPanel.detail_panel.icon_name', 'TipsPanel.详情面板.图标.名称', '详情面板.图标.名称' })
    if not is_ui_alive(hud_state.bond_tip_panel) then
      local cE = hud_state.bond_tip_root or resolve_first_ui_node({ 'BattleDetailTipsPanel', 'TipsPanel' })
      if is_ui_alive(cE) then hud_state.bond_tip_panel = ui_root.resolve_child(cE, '详情面板') end
    end;
    if is_ui_alive(hud_state.bond_tip_panel) then
      safe_ui_call(hud_state.bond_tip_panel, 'set_follow_mouse', true, 16, 12)
      safe_ui_call(hud_state.bond_tip_panel, 'set_intercepts_operations', false)
      safe_ui_call(hud_state.bond_tip_panel, 'set_z_order', 9900)
      if not is_ui_alive(hud_state.bond_tip_title) then hud_state.bond_tip_title = ui_root.resolve_child(hud_state.bond_tip_panel, 'title') or ui_root.resolve_child(hud_state.bond_tip_panel, '列表.标题') end;
      if not is_ui_alive(hud_state.bond_tip_subtitle) then hud_state.bond_tip_subtitle = ui_root.resolve_child(hud_state.bond_tip_panel, 'subtitle') or ui_root.resolve_child(hud_state.bond_tip_panel, '列表.副标题') end;
      if not is_ui_alive(hud_state.bond_tip_bottom) then hud_state.bond_tip_bottom = ui_root.resolve_child(hud_state.bond_tip_panel, 'bottom') or ui_root.resolve_child(hud_state.bond_tip_panel, '列表.底部内容') end;
      if not is_ui_alive(hud_state.bond_tip_panel_bg) then hud_state.bond_tip_panel_bg = ui_root.resolve_child(hud_state.bond_tip_panel, 'panel_bg') end;
      if not is_ui_alive(hud_state.bond_tip_panel_edge) then hud_state.bond_tip_panel_edge = ui_root.resolve_child(hud_state.bond_tip_panel, 'panel_edge') end;
      if not is_ui_alive(hud_state.bond_tip_title_bar) then hud_state.bond_tip_title_bar = ui_root.resolve_child(hud_state.bond_tip_panel, 'title_bar') end;
      if not is_ui_alive(hud_state.bond_tip_divider_top) then hud_state.bond_tip_divider_top = ui_root.resolve_child(hud_state.bond_tip_panel, 'divider_top') end;
      if not is_ui_alive(hud_state.bond_tip_divider_bottom) then hud_state.bond_tip_divider_bottom = ui_root.resolve_child(hud_state.bond_tip_panel, 'divider_bottom') end;
      if not is_ui_alive(hud_state.bond_tip_icon_box) then hud_state.bond_tip_icon_box = ui_root.resolve_child(hud_state.bond_tip_panel, 'icon_box') end;
      if not is_ui_alive(hud_state.bond_tip_icon_bg) then hud_state.bond_tip_icon_bg = ui_root.resolve_child(hud_state.bond_tip_panel, 'icon_box.icon_bg') end;
      for i = 1, 5 do
        if not is_ui_alive(hud_state.bond_tip_contents[i]) then hud_state.bond_tip_contents[i] = ui_root.resolve_child(hud_state.bond_tip_panel, 'content_' .. tostring(i)) or ui_root.resolve_child(hud_state.bond_tip_panel, '列表.内容' .. tostring(i)) end;
      end
      if not is_ui_alive(hud_state.bond_tip_icon) then hud_state.bond_tip_icon = ui_root.resolve_child(hud_state.bond_tip_panel, 'icon_box.icon') or ui_root.resolve_child(hud_state.bond_tip_panel, '图标.图标') end;
      if not is_ui_alive(hud_state.bond_tip_icon_name) then hud_state.bond_tip_icon_name = ui_root.resolve_child(hud_state.bond_tip_panel, 'icon_name') or ui_root.resolve_child(hud_state.bond_tip_panel, '图标.名称') end;
    end;
    set_ui_visible(hud_state.bond_tip_panel, false)
    if not is_ui_alive(hud_state.big_cursor) then
      local player = get_player()
      local cF = player and ui_root.get_overlay_parent(y3, player) or nil;
      if not cF then return end;

      local ac = cF:create_child('文本')
      ac:set_ui_size(60, 60)
      ac:set_text('')
      ac:set_font_size(28)
      ac:set_text_color(255, 233, 158, 235)
      ac:set_text_alignment('', '')
      ac:set_z_order(9380)
      ac:set_intercepts_operations(false)
      safe_ui_call(ac, 'set_follow_mouse', true, 12, -10)
      hud_state.big_cursor = ac; set_ui_visible(ac, false)
    end
  end;

  local function get_attr_row_components(row_index)
    local row_name = ATTR_ROW_NAMES[row_index]
    if not row_name then return {} end;

    local path = 'BattleBottomHUD.layout.left_station.player_attr_list.' .. row_name;
    return {
      root = resolve_ui_node(path),
      label = resolve_ui_node(path .. '.label'),
      value = resolve_ui_node(path .. '.value'),
      delta = resolve_ui_node(path .. '.delta'),
      icon = resolve_ui_node(path .. '.icon')
    }
  end;

  local function reset_tip_state() return end;

  local function set_bond_tip_root_visible(dA0)
    local hud_state = get_hud_state()
    if not is_ui_alive(hud_state.bond_tip_root) then hud_state.bond_tip_root = resolve_first_ui_node({ 'BattleDetailTipsPanel', 'TipsPanel' }) end;
    if not is_ui_alive(hud_state.bond_tip_root) then return end;
    if hud_state.bond_tip_uses_dedicated_root == true then
      set_ui_visible(hud_state.bond_tip_root, dA0 == true)
    else
      set_ui_visible(hud_state.bond_tip_root, dA0 == true or STATE.attr_tips_panel_visible == true)
    end
  end;

  local function hide_all_tips()
    local hud_state = get_hud_state()
    hud_state.hover_tip_visible = false; hud_state.bond_tip_visible = false; hud_state.active_tip_kind = nil
    set_ui_visible(hud_state.hover_tip_panel, false)
    set_ui_visible(hud_state.bond_tip_panel, false)
    set_bond_tip_root_visible(false)
  end;

  local function split_non_empty_tip_lines(text, max_lines)
    local lines = {}
    local value = tostring(text or ''):gsub('\r', '')
    for line in value:gmatch('[^\n]+') do
      local trimmed = line:gsub('^%s+', ''):gsub('%s+$', '')
      if trimmed ~= '' then
        lines[#lines + 1] = trimmed
        if max_lines and #lines >= max_lines then
          return lines
        end
      end
    end
    return lines
  end

  local function join_or_default(lines, fallback)
    local result = {}
    for _, line in ipairs(lines or {}) do
      local text = tostring(line or '')
      if text ~= '' then result[#result + 1] = text end
    end
    if #result == 0 then return fallback or '' end
    return table.concat(result, '\n')
  end

  local function clamp_number(value, min_value, max_value)
    value = tonumber(value) or min_value
    if value < min_value then return min_value end
    if value > max_value then return max_value end
    return value
  end

  local function estimate_text_units(text)
    local value = tostring(text or '')
    local units = 0
    for i = 1, #value do
      local byte = value:byte(i)
      if byte == 9 then
        units = units + 4
      else
        units = units + 1
      end
    end
    return units
  end

  local function estimate_tip_line_count(text)
    local value = tostring(text or ''):gsub('\r', '')
    if value == '' then return 0 end

    local total = 0
    for line in value:gmatch('([^\n]*)\n?') do
      if line == '' then
        total = total + 1
      else
        total = total + math.max(1, math.ceil(estimate_text_units(line) / 46))
      end
      if total > 40 then return total end
    end
    return math.max(1, total)
  end

  local function set_detail_tip_node_layout(node, y, height)
    set_ui_size(node, DETAIL_TIP_CONTENT_WIDTH, height)
    set_ui_pos(node, DETAIL_TIP_WIDTH / 2, y)
  end

  local function apply_detail_tip_auto_layout(hud_state, payload_contents, bottom_text)
    if not hud_state.bond_tip_uses_dedicated_root then return end

    local rows = {}
    local content_height = 0
    for i = 1, 5 do
      local text = tostring(payload_contents[i] or '')
      if text ~= '' then
        local line_count = estimate_tip_line_count(text)
        local height = clamp_number(line_count * DETAIL_TIP_LINE_HEIGHT + 4, 24, 94)
        rows[i] = height
        content_height = content_height + height + DETAIL_TIP_CONTENT_GAP
      else
        rows[i] = 0
      end
    end

    local bottom_height = 0
    if tostring(bottom_text or '') ~= '' then
      bottom_height = clamp_number(estimate_tip_line_count(bottom_text) * 15 + 4, 20, 46)
      content_height = content_height + bottom_height + 8
    end
    if content_height > 0 then content_height = content_height - DETAIL_TIP_CONTENT_GAP end

    local panel_height = clamp_number(96 + content_height + 18, DETAIL_TIP_MIN_HEIGHT, DETAIL_TIP_MAX_HEIGHT)
    set_ui_size(hud_state.bond_tip_panel, DETAIL_TIP_WIDTH, panel_height)
    set_ui_size(hud_state.bond_tip_panel_bg, DETAIL_TIP_WIDTH, panel_height)
    set_ui_pos(hud_state.bond_tip_panel_bg, DETAIL_TIP_WIDTH / 2, panel_height / 2)
    set_ui_size(hud_state.bond_tip_panel_edge, DETAIL_TIP_WIDTH - 4, panel_height - 4)
    set_ui_pos(hud_state.bond_tip_panel_edge, DETAIL_TIP_WIDTH / 2, panel_height / 2)
    set_ui_size(hud_state.bond_tip_title_bar, DETAIL_TIP_WIDTH - 24, 42)
    set_ui_pos(hud_state.bond_tip_title_bar, DETAIL_TIP_WIDTH / 2, panel_height - 33)
    set_ui_size(hud_state.bond_tip_divider_top, DETAIL_TIP_CONTENT_WIDTH, 1)
    set_ui_pos(hud_state.bond_tip_divider_top, DETAIL_TIP_WIDTH / 2, panel_height - 67)
    set_ui_size(hud_state.bond_tip_divider_bottom, DETAIL_TIP_CONTENT_WIDTH, 1)
    set_ui_pos(hud_state.bond_tip_divider_bottom, DETAIL_TIP_WIDTH / 2, 38)
    set_ui_pos(hud_state.bond_tip_icon_box, 42, panel_height - 33)
    set_ui_pos(hud_state.bond_tip_icon_bg, 23, 23)
    set_ui_pos(hud_state.bond_tip_icon, 23, 23)
    set_ui_pos(hud_state.bond_tip_title, 205, panel_height - 24)
    set_ui_pos(hud_state.bond_tip_subtitle, 205, panel_height - 45)
    set_ui_pos(hud_state.bond_tip_icon_name, DETAIL_TIP_WIDTH / 2, panel_height - 78)

    local y = panel_height - 104
    for i = 1, 5 do
      local height = rows[i] or 0
      if height > 0 then
        set_detail_tip_node_layout(hud_state.bond_tip_contents[i], y - height / 2, height)
        y = y - height - DETAIL_TIP_CONTENT_GAP
      else
        set_detail_tip_node_layout(hud_state.bond_tip_contents[i], y, 1)
      end
    end

    if bottom_height > 0 then
      set_detail_tip_node_layout(hud_state.bond_tip_bottom, math.max(20, y - bottom_height / 2), bottom_height)
    else
      set_detail_tip_node_layout(hud_state.bond_tip_bottom, 20, 1)
    end
  end

  local function show_hover_tip_payload(bs)
    if not bs then
      hide_all_tips()
      return
    end;
    ensure_hud()
    local hud_state = get_hud_state()
    reset_tip_state()
    hud_state.bond_tip_visible = false; set_ui_visible(hud_state.bond_tip_panel, false)
    set_bond_tip_root_visible(false)
    if not is_ui_alive(hud_state.hover_tip_panel) then
      local dA3 = tostring(bs.title or '说明')
      local dA4 = tostring(bs.body or '')
      local dA5 = tostring(bs.subtitle or '')
      if dA5 ~= '' then
        if dA4 ~= '' then dA4 = dA5 .. '\n' .. dA4 else dA4 = dA5 end
      end;
      hud_state.tip_expires_at = math.huge;
      hud_state.tip_title_text = dA3;
      hud_state.tip_body_text = dA4;
      set_ui_text(hud_state.tip_panel_title, dA3)
      set_ui_text(hud_state.tip_panel_body, dA4)
      set_ui_visible(hud_state.tip_panel, hud_state.visible ~= false)
      return
    end;
    hud_state.hover_tip_visible = true; set_ui_text(hud_state.hover_tip_panel_title, bs.title or '说明')
    set_ui_text(hud_state.hover_tip_panel_subtitle, bs.subtitle or '')
    set_ui_text(hud_state.hover_tip_panel_body, bs.body or '')
    set_ui_font_size(hud_state.hover_tip_panel_title, 16)
    set_ui_font_size(hud_state.hover_tip_panel_subtitle, 13)
    set_ui_font_size(hud_state.hover_tip_panel_body, 14)
    set_ui_text_color(hud_state.hover_tip_panel_title, { 204, 226, 255, 255 })
    set_ui_text_color(hud_state.hover_tip_panel_subtitle, { 255, 213, 96, 255 })
    set_ui_text_color(hud_state.hover_tip_panel_body, { 222, 232, 244, 255 })
    set_ui_visible(hud_state.hover_tip_panel_subtitle, bs.subtitle ~= nil and bs.subtitle ~= '')
    set_ui_visible(hud_state.hover_tip_panel_icon_bg, bs.icon ~= nil)
    set_ui_visible(hud_state.hover_tip_panel_icon, bs.icon ~= nil)
    set_ui_image(hud_state.hover_tip_panel_icon, bs.icon)
    set_ui_visible(hud_state.hover_tip_panel, hud_state.visible ~= false)
  end;

  -- 通用详情面板渲染：{ title, subtitle, icon, icon_name, contents={...}, bottom }
  local function show_detail_payload(dP)
    if not dP then
      hide_all_tips()
      return
    end;
    ensure_hud()
    local hud_state = get_hud_state()
    reset_tip_state()
    if not is_ui_alive(hud_state.bond_tip_panel) or not is_ui_alive(hud_state.bond_tip_title) then resolve_static_ui_panels() end;
    if not is_ui_alive(hud_state.bond_tip_panel) or not is_ui_alive(hud_state.bond_tip_title) then
      local fallback_lines = {}
      append_lines(fallback_lines, dP.contents or {})
      if dP.bottom and dP.bottom ~= '' then fallback_lines[#fallback_lines + 1] = tostring(dP.bottom) end
      show_hover_tip_payload({ title = dP.title, subtitle = dP.subtitle, body = table.concat(fallback_lines, '\n') })
      return
    end;

    hud_state.hover_tip_visible = false; set_ui_visible(hud_state.hover_tip_panel, false)
    hud_state.bond_tip_visible = true
    set_ui_text(hud_state.bond_tip_title, tostring(dP.title or ''))
    set_ui_text(hud_state.bond_tip_subtitle, tostring(dP.subtitle or ''))

    local contents = hud_state.bond_tip_contents or {}
    local payload_contents = dP.contents or {}
    for i = 1, 5 do
      local text = tostring(payload_contents[i] or '')
      set_ui_text(contents[i], text)
      set_ui_visible(contents[i], text ~= '')
    end

    local bottom_text = tostring(dP.bottom or '')
    apply_detail_tip_auto_layout(hud_state, payload_contents, bottom_text)

    set_ui_text(hud_state.bond_tip_bottom, bottom_text)
    set_ui_visible(hud_state.bond_tip_bottom, bottom_text ~= '')

    set_ui_visible(hud_state.bond_tip_icon, dP.icon ~= nil)
    if dP.icon then set_ui_image(hud_state.bond_tip_icon, dP.icon) end;
    set_ui_text(hud_state.bond_tip_icon_name, tostring(dP.icon_name or ''))
    set_ui_visible(hud_state.bond_tip_icon_name, tostring(dP.icon_name or '') ~= '')

    set_ui_visible(hud_state.bond_tip_panel, hud_state.visible ~= false)
    set_bond_tip_root_visible(hud_state.visible ~= false)
  end;

  local function resolve_combat_module_ui(cO) return resolve_ui_node('BattleBottomHUD.layout.center_hub.combat_module.' ..
    cO) end;

    local function get_or_create_hero_model_ui()
    local hud_state = get_hud_state()
    if is_ui_alive(hud_state.hero_model_ui) then
        print('[HUD] hero_model_ui already exists')
        return hud_state.hero_model_ui
    end;

    -- use existing hero_model control from UI template, don't create new one
    local cR = resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_model')
    if not is_ui_alive(cR) then
        print('[HUD] hero_model node not found in UI tree')
        return nil
    end;

    print('[HUD] found existing hero_model_ui')
    hud_state.hero_model_ui = cR
    return cR
  end;


  local function bind_click_handler(cT, u, cU)
    local hud_state = get_hud_state()
    if hud_state.bound_events[cT] == u and is_ui_alive(u) then return end;

    if not is_ui_alive(u) or not u.add_fast_event then return end;
    hud_state.bound_events[cT] = u; safe_ui_call(u, 'set_intercepts_operations', true)
    u:add_fast_event('左键-点击', function()
      if play_ui_click_fn then play_ui_click_fn() end;
      cU()
    end)
  end;

  local function bind_hover_handlers(cT, u, cW, cX)
    local hud_state = get_hud_state()
    if hud_state.bound_events[cT] == u and is_ui_alive(u) then return end;

    if not is_ui_alive(u) or not u.add_fast_event then return end;
    hud_state.bound_events[cT] = u; safe_ui_call(u, 'set_intercepts_operations', true)
    u:add_fast_event('鼠标-移入', function()
      if cW then cW(u) end
    end)
    u:add_fast_event('鼠标-移出', function()
      if cX then cX(u) end
    end)
  end;

  local function hide_tip_panel()
    local hud_state = get_hud_state()
    hud_state.tip_expires_at = 0; set_ui_visible(hud_state.tip_panel, false)
  end;

  local function show_tip_panel(ac, c_, bz)
    ensure_hud()
    local hud_state = get_hud_state()
    local duration = tonumber(c_)
    if duration ~= nil and duration <= 0 then hud_state.tip_expires_at = math.huge else hud_state.tip_expires_at = (STATE.runtime_elapsed or 0) +
      math.max(1, duration or DEFAULT_TIP_DURATION) end;
    hud_state.tip_title_text = bz or '系统提示'
    hud_state.tip_body_text = tostring(ac or '')
    set_ui_text(hud_state.tip_panel_title, bz or '系统提示')
    set_ui_text(hud_state.tip_panel_body, tostring(ac or ''))
    set_ui_visible(hud_state.tip_panel, hud_state.visible ~= false)
  end;

  local function refresh_tip_panel_visibility()
    local hud_state = get_hud_state()
    local d2 = hud_state.tip_expires_at and hud_state.tip_expires_at > (STATE.runtime_elapsed or 0)
    set_ui_visible(hud_state.tip_panel, hud_state.visible ~= false and d2)
  end;

  local function refresh_hover_tip_visibility()
    local hud_state = get_hud_state()
    reset_tip_state()
    set_ui_visible(hud_state.hover_tip_panel, hud_state.visible ~= false and hud_state.hover_tip_visible == true)
    set_ui_visible(hud_state.bond_tip_panel, hud_state.visible ~= false and hud_state.bond_tip_visible == true)
    set_bond_tip_root_visible(hud_state.visible ~= false and hud_state.bond_tip_visible == true)
  end;

  local function toggle_big_cursor()
    local X = ensure_ui_preferences()
    X.big_cursor = not X.big_cursor;
    local hud_state = get_hud_state()
    set_ui_visible(hud_state.big_cursor, hud_state.visible ~= false and X.big_cursor)
    show_tip_panel(X.big_cursor and '大鼠标已开启，鼠标位置会显示辅助圈' or '大鼠标已关闭', 4, '鼠标辅助')
  end;

  local function toggle_damage_text_visible()
    local X = ensure_ui_preferences()
    X.hide_damage_text = not X.hide_damage_text; show_tip_panel(X.hide_damage_text and '已屏蔽跳字' or '已恢复跳字显示', 4, '本地显示')
  end;

  local function toggle_hit_effects_visible()
    local X = ensure_ui_preferences()
    X.hide_hit_effects = not X.hide_hit_effects; show_tip_panel(X.hide_hit_effects and '已屏蔽局内技能特效' or '已恢复局内技能特效', 4,
      '本地显示')
  end;

  local function toggle_soft_pause()
    local X = ensure_ui_preferences()
    X.soft_paused = not X.soft_paused;
    if X.soft_paused then
      y3.game.enable_soft_pause()
      show_tip_panel('对局已暂停，再点一次继续', 4, '战斗控制')
    else
      y3.game.resume_soft_pause()
      show_tip_panel('对局已继续', 4, '战斗控制')
    end
  end;

  local function toggle_runtime_attr_panel()
    ensure_hud()
    local hud_state = get_hud_state()
    hud_state.attr_panel_visible = not hud_state.attr_panel_visible;
    if hud_state.attr_panel_visible then
      local attr_chunks = build_runtime_attr_dialog_chunks and build_runtime_attr_dialog_chunks() or {
        string.format('等级%d', get_hero_level()),
        string.format('攻击%s', format_short_number(get_hero_attr('攻击结算值', '攻击'))),
        string.format('护甲%s', format_short_number(get_hero_attr('护甲结算值', '护甲'))),
        string.format('力量%s', format_short_number(get_hero_attr('最终力量', '力量'))),
        string.format('智力%s', format_short_number(get_hero_attr('最终智力', '智力'))),
        string.format('敏捷%s', format_short_number(get_hero_attr('最终敏捷', '敏捷'))),
      }
      set_ui_text(hud_state.attr_panel_title, '属性总览')
      set_ui_text(hud_state.attr_panel_body, table.concat(attr_chunks, '\n\n'))
    end;
    set_ui_visible(hud_state.attr_panel, hud_state.visible ~= false and hud_state.attr_panel_visible)
    return hud_state.attr_panel_visible
  end;

  local function set_static_labels()
    local X = ensure_ui_preferences()
    set_ui_text(resolve_ui_node('top.top.left_buttons.btn_exit'), '退出')
    set_ui_text(resolve_ui_node('top.top.left_buttons.btn_setting'), '设置')
    set_ui_text(resolve_ui_node('top.top.left_buttons.btn_save'), '存档')
    set_ui_text(resolve_ui_node('top.top.left_buttons.btn_pause'), X.soft_paused and '继续' or '暂停')
    set_ui_text(resolve_ui_node('top.top.left_buttons.btn_powerup'), '')
    set_ui_visible(resolve_ui_node('top.top.left_buttons.btn_powerup'), false)
    set_ui_text(resolve_ui_node('top.top.left_buttons.btn_hotkey'), '键位')
    set_ui_visible(resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame'), false)
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'), '抽卡')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'), '如何变强')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'), '杀敌')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'), '钓鱼')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button.hotkey'), 'F')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button.hotkey'), 'H')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.hotkey'), 'G')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button.hotkey'), 'B')
  end;

  local function show_slot_item_tip(bm)
    local bo = get_hero_item_by_slot(bm)
    local bz,
    bJ = get_item_display_info(bo)
    if bz and bJ then
      show_tip_panel(bJ, 0, bz)
      return
    end;
    hide_tip_panel()
  end;

  local function show_hero_skill_tip(bm, cj)
    local c4 = get_evolution_slot_entries(EVOLUTION_SLOT_COUNT)[bm]
    if not c4 then
      hide_all_tips()
      return
    end;
    if not c4.tip_text or c4.tip_text == '' then
      hide_all_tips()
      return
    end;

    local tip_lines = split_non_empty_tip_lines(c4.tip_text, 4)
    show_detail_payload({
      title = tostring(c4.tip_title or c4.name or '英雄技能'),
      subtitle = tostring(c4.badge_text or c4.quality or c4.cooldown_text or ''),
      icon = c4.icon,
      icon_name = tostring(c4.name or ''),
      contents = {
        join_or_default({ tip_lines[1], tip_lines[2] }, '当前没有技能说明'),
        join_or_default({ tip_lines[3], tip_lines[4] }, ''),
        c4.cooldown_text and c4.cooldown_text ~= '' and ('状态：' .. tostring(c4.cooldown_text)) or '',
        c4.stack_text and c4.stack_text ~= '' and ('计数：' .. tostring(c4.stack_text)) or '',
      },
      bottom = c4.key and ('技能位置：' .. tostring(c4.key)) or ''
    })
  end;

  local function show_skill_tip(bm, cj)
    local ck = get_skill_slot_entries(cj or 4)
    local c4 = ck[bm]
    if not c4 then
      hide_all_tips()
      return
    end;
    if not c4.tip_text or c4.tip_text == '' then
      hide_all_tips()
      return
    end;
    show_detail_payload({
      title = tostring(c4.tip_title or c4.name or '技能'),
      subtitle = tostring(c4.badge_text or ''),
      icon = c4.icon,
      icon_name = tostring(c4.name or ''),
      contents = { tostring(c4.tip_text) },
    })
  end;

  local function show_evolution_tip(bm)
    local c4 = get_evolution_slot_entries(EVOLUTION_SLOT_COUNT)[bm]
    if not c4 then
      hide_all_tips()
      return
    end;
    show_detail_payload({
      title = tostring(c4.tip_title or c4.name or '进化'),
      subtitle = tostring(c4.badge_text or c4.quality or ''),
      icon = c4.icon,
      icon_name = tostring(c4.name or ''),
      contents = { tostring(c4.tip_text or '') },
    })
  end;

  local function show_buff_tip(bm)
    local ck = get_status_effects_fn and get_status_effects_fn(skill_slot_count) or {}
    local c4 = ck[bm]
    if not c4 then
      hide_all_tips()
      return
    end;
    show_detail_payload({
      title = tostring(c4.tip_title or c4.name or '魔法效果'),
      subtitle = tostring(c4.badge_text or ''),
      icon = c4.icon,
      icon_name = tostring(c4.name or ''),
      contents = { tostring(c4.tip_text or '') },
    })
  end;

  local function show_loadout_tip(bm)
    local bs = build_slot_tooltip(bm)
    show_hover_tip_payload(bs)
  end;

  local function show_draw_button_tip()
    show_hover_tip_payload(build_draw_tooltip())
  end;

  local function show_hero_catalog_tip()
    show_hover_tip_payload(build_hero_catalog_tooltip())
  end;

  local function show_evolution_entry_tip()
    show_hover_tip_payload(build_evolution_entry_tooltip())
  end;

  local function show_save_panel_tip()
    show_hover_tip_payload(build_save_panel_tooltip())
  end;

  local function show_consumable_tip(bm)
    show_hover_tip_payload(build_consumable_tooltip(bm))
  end;

  local function refresh_loadout_row()
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), '物品栏')
    set_ui_size(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), 92, 17)
    set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), ', ')
    for bL = 1, 6 do
      local cJ = string.format('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_%d', bL)
      local bo = get_hero_item_by_slot(bL)
      local dq = bo and bo.get_icon and bo:get_icon() or nil;
      local dr = resolve_ui_node(cJ .. '.icon')
      
      set_ui_visible(dr, dq ~= nil)
      set_ui_image(dr, dq)
      if not dq then set_ui_image(dr, nil) end
    end
  end;

  local function ensure_buff_prefab()
    local hud_state = get_hud_state()
    local player = get_player()
    if not player or not y3 or not y3.ui_prefab or type(y3.ui_prefab.create) ~= 'function' then return end;
    local buff_parent = resolve_combat_module_ui('buff_row') or
    resolve_ui_node('BattleBottomHUD.layout.center_hub.combat_module')

    if not is_ui_alive(hud_state.buff_prefab_root) then
      local ok, prefab = pcall(y3.ui_prefab.create, player, 'bufflist', buff_parent)
      if ok and prefab then
        local root = prefab.get_child and prefab:get_child() or nil
        if is_ui_alive(root) then
          hud_state.buff_prefab = prefab
          hud_state.buff_prefab_root = root
          hud_state.buff_list_comp = ui_root.resolve_child(root, 'buff_list') or ui_root.resolve_child(root, 'bufflist')
          safe_ui_call(root, 'set_z_order', 9570)
          safe_ui_call(root, 'set_intercepts_operations', false)
          set_ui_visible(root, hud_state.visible ~= false)
        end
      end
    end
  end;

  local function refresh_buff_list()
    local hud_state = get_hud_state()
    local hero = get_hero_unit()
    if is_ui_alive(hud_state.buff_list_comp) then
      if hero and hud_state.buff_list_comp.set_buff_on_ui then
        pcall(hud_state.buff_list_comp.set_buff_on_ui, hud_state.buff_list_comp, hero)
        set_ui_visible(hud_state.buff_prefab_root, hud_state.visible ~= false)
      else
        set_ui_visible(hud_state.buff_prefab_root, false)
      end
    end
  end;

  ensure_hud = function()
    ensure_ui_preferences()
    resolve_static_ui_panels()
    ensure_buff_prefab()
    bind_click_handler('top_pause', resolve_ui_node('top.top.left_buttons.btn_pause'), function()
      toggle_soft_pause()
      refresh_hud()
    end)
    bind_click_handler('top_save', resolve_ui_node('top.top.left_buttons.btn_save'), function()
      if open_save_panel and open_save_panel() ~= false then return end;

      if show_runtime_status then show_runtime_status() end
    end)
    bind_click_handler('top_hotkey', resolve_ui_node('top.top.left_buttons.btn_hotkey'), function()
      show_tip_panel(get_hotkey_help_text(), 10, '快捷键')
    end)
    bind_click_handler('toggle_damage',
      resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame.toggle_damage.button'), function()
      toggle_damage_text_visible()
      refresh_hud()
    end)
    bind_click_handler('toggle_effects',
      resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame.toggle_sfx.button'), function()
      toggle_hit_effects_visible()
      refresh_hud()
    end)
    bind_click_handler('toggle_cursor',
      resolve_ui_node('BattleBottomHUD.layout.left_station.toggle_frame.toggle_cursor.button'), function()
      toggle_big_cursor()
      refresh_hud()
    end)
    bind_click_handler('draw_button',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'), function()
      refresh_hud()
    end)
    bind_click_handler('reward_button',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'), function()
      refresh_hud()
    end)
    bind_click_handler('kill_reward_button',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'), function()
      if try_evolution_entry then try_evolution_entry() end;
      refresh_hud()
    end)
    bind_click_handler('fish_button',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'), function()
      if open_save_panel and open_save_panel() ~= false then return end;

      if show_runtime_status then show_runtime_status() end
    end)
    bind_hover_handlers('draw_button_hover',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.draw_button'), function()
      show_draw_button_tip()
    end, function()
      hide_all_tips()
    end)
    bind_hover_handlers('reward_button_hover',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.reward_button'), function()
      show_hero_catalog_tip()
    end, function()
      hide_all_tips()
    end)
    bind_hover_handlers('kill_reward_button_hover',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button'), function()
      show_evolution_entry_tip()
    end, function()
      hide_all_tips()
    end)
    bind_hover_handlers('fish_button_hover',
      resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.fish_button'), function()
      show_save_panel_tip()
    end, function()
      hide_all_tips()
    end)
    for bL = 1, 3 do
      local slot_index = bL
      bind_hover_handlers('battle_consumable_hover_' .. tostring(slot_index),
        resolve_ui_node(string.format('BattleBottomHUD.layout.right_station.consumable_panel.slot_%d', slot_index)), function()
        show_consumable_tip(slot_index)
      end, function()
        hide_all_tips()
      end)
    end;
    bind_click_handler('gold_trial', resolve_combat_module_ui('challenge_row.gold_trial'), function()
      if try_start_challenge then try_start_challenge('gold_trial') end;
      refresh_hud()
    end)
    bind_click_handler('wood_trial', resolve_combat_module_ui('challenge_row.treasure_trial'), function()
      if try_start_challenge then try_start_challenge('wood_trial') end;
      refresh_hud()
    end)
    for bL = 1, 6 do
      local slot_index = bL
      bind_hover_handlers('battle_loadout_hover_' .. tostring(slot_index),
        resolve_ui_node(string.format('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_%d', slot_index)),
        function()
          show_loadout_tip(slot_index)
        end, function()
        hide_all_tips()
      end)
    end;

    for bL = 1, EVOLUTION_SLOT_COUNT do
      local slot_index = bL
      bind_hover_handlers('battle_skill_hover_' .. tostring(slot_index),
        resolve_combat_module_ui(string.format('skill_bar.skill_slot_%d', slot_index)), function()
        show_hero_skill_tip(slot_index)
      end, function()
        hide_all_tips()
      end)
    end;

    for slot_index = 1, BUFF_SLOT_COUNT do
      bind_hover_handlers('battle_buff_hover_' .. tostring(slot_index),
        resolve_combat_module_ui(string.format('buff_row.buff_slot_%d', slot_index)), function()
        show_buff_tip(slot_index)
      end, function()
        hide_all_tips()
      end)
    end;

    bind_click_handler('battle_exp_bar_evolve', resolve_combat_module_ui('exp_bar.evolve_click_area'), function()
      if try_evolution_entry then try_evolution_entry() end;
      refresh_hud()
    end)
    set_static_labels()
    return get_hud_state()
  end;

  local function refresh_top_bar()
    set_ui_text(resolve_ui_node('top.top.金币.image_3.label_2'), format_short_number(STATE.resources and STATE.resources.gold or 0))
    set_ui_text(resolve_ui_node('top.top.木材.image_3.label_2'), format_short_number(STATE.resources and STATE.resources.wood or 0))
    set_ui_text(resolve_ui_node('top.top.人口.image_3.label_2'), format_short_number(STATE.total_kills or 0))
    set_ui_text(resolve_ui_node('top.top.金币.delta'), string.format('+%s/s', format_short_number(get_hero_attr('每秒金币'))))
    set_ui_text(resolve_ui_node('top.top.木材.delta'), string.format('+%s/s', format_short_number(get_hero_attr('每秒木材'))))
    set_ui_text(resolve_ui_node('top.top.人口.delta'), string.format('%d', math.max(0, tonumber(STATE.total_enemy_alive) or 0)))
    local dt,
    du = get_current_tip_text()
    set_ui_text(resolve_ui_node('top.top.system_notice.notice_title'), dt)
    set_ui_text(resolve_ui_node('top.top.system_notice.notice_text'), du)
    local dv = '第1关'
    local dw = '战斗模式'
    local dx = STATE.active_wave and STATE.active_wave.wave and STATE.active_wave.wave.name or
    (STATE.current_wave_index and STATE.current_wave_index > 0 and string.format('%d', STATE.current_wave_index) or '未开始')
    local dy = ({ get_pending_choice_status() })[1] or (STATE.session_phase == 'battle' and '战斗中' or '准备中')
    local dz;
    if STATE.active_wave and STATE.active_wave.wave and STATE.active_wave.wave.boss_spawn_sec and STATE.active_wave.boss_spawned ~= true then
      dz = string.format('Boss %.1fs', math.max(0, (STATE.active_wave.wave.boss_spawn_sec or 0) -
      (STATE.active_wave.elapsed or 0)))
    else
      dz = string.format('敌人 %d', math.max(0, tonumber(STATE.total_enemy_alive) or 0))
    end;
    set_ui_text(resolve_ui_node('top.tophud.layout_2.curlevel'), dv)
    set_ui_text(resolve_ui_node('top.tophud.layout_2.curlevel_sub'), dw)
    set_ui_text(resolve_ui_node('top.tophud.layout_2.gametime'), format_time_mmss(STATE.runtime_elapsed or 0))
    set_ui_text(resolve_ui_node('top.tophud.layout_2.wave'), dx)
    set_ui_text(resolve_ui_node('top.tophud.layout_2.phase_text'), dy)
    set_ui_text(resolve_ui_node('top.tophud.layout_2.threat_text'), dz)
    set_ui_text(resolve_ui_node('top.top.scoreboard.title'), '玩家状态')
    set_ui_text(resolve_ui_node('top.top.scoreboard.player_name'), get_player_name())
    set_ui_text(resolve_ui_node('top.top.scoreboard.player_power'), format_short_number(get_hero_attr('攻击结算值', '攻击')))
    set_ui_text(resolve_ui_node('top.top.scoreboard.player_state'), STATE.session_phase == 'battle' and '战斗中' or '局中')
    set_ui_text(resolve_ui_node('top.top.scoreboard.player_level'), tostring(get_hero_level()))
    set_ui_text(resolve_ui_node('top.top.scoreboard.player_equip'), '0')
    set_ui_text(resolve_ui_node('top.top.scoreboard.player_swallow'), '0')
    for row_index = 2, 4 do
      set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_name_%d', row_index)), '-')
      set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_power_%d', row_index)), '-')
      set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_state_%d', row_index)), '-')
      set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_level_%d', row_index)), '-')
      set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_equip_%d', row_index)), '-')
      set_ui_text(resolve_ui_node(string.format('top.top.scoreboard.player_swallow_%d', row_index)), '-')
    end
  end;

  local function refresh_player_attr_list()
    local dB = format_short_number(get_hero_attr('攻击结算值', '攻击'))
    local dC = format_short_number(get_hero_attr('护甲结算值', '护甲'))
    local dD = { {
      label = '战力',
      value = dB,
      delta = ''
    },
      {
        label = '攻击',
        value = dB,
        delta = format_percent_delta(get_hero_attr('攻击增幅'), get_hero_attr('最终攻击'))
      },
      {
        label = '护甲',
        value = dC,
        delta = format_percent_delta(get_hero_attr('护甲增幅'), get_hero_attr('最终护甲'))
      },
      {
        label = '力量',
        value = format_short_number(get_hero_attr('最终力量', '力量')),
        delta = format_percent_delta(get_hero_attr('力量增幅'), get_hero_attr('最终力量增幅'))
      },
      {
        label = '智力',
        value = format_short_number(get_hero_attr('最终智力', '智力')),
        delta = format_percent_delta(get_hero_attr('智力增幅'), get_hero_attr('最终智力增幅'))
      },
      {
        label = '敏捷',
        value = format_short_number(get_hero_attr('最终敏捷', '敏捷')),
        delta = format_percent_delta(get_hero_attr('敏捷增幅'), get_hero_attr('最终敏捷增幅'))
      } }
    for cH, dE in ipairs(dD) do
      local dF = get_attr_row_components(cH)
      set_ui_visible(dF.root, true)
      set_ui_text(dF.label, dE.label)
      set_ui_text(dF.value, dE.value)
      set_ui_text(dF.delta, dE.delta)
      set_ui_text_color(dF.delta, { 131, 210, 255, 255 })
    end
  end;

  local function refresh_hero_panel()
    local bc,
    bd = get_hero_hp_info()
    local bf,
    bg = get_hero_exp_info()
    local dH = get_hero_unit()
    local dI = resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_portrait')
    local model_ui = get_or_create_hero_model_ui()
    
    local model_bound = false
    
    if is_ui_alive(model_ui) and dH ~= nil then
        print('[HUD] model_ui alive:', is_ui_alive(model_ui))
        print('[HUD] dH:', dH)
        print('[HUD] dH.is_exist:', dH.is_exist and dH:is_exist())
        
        local initial_hero = game_tables_hero_roster.initial_hero
        local hero_name = initial_hero and initial_hero.name or nil
        local hero_id = initial_hero and initial_hero.id or nil
        local bind_ok = bind_ui_model_unit(model_ui, dH, false, true, true, hero_name, hero_id)
        print('[HUD] bind_ui_model_unit result:', bind_ok)
        
        if bind_ok then
            apply_ui_model_camera(model_ui, HERO_MODEL_CAMERA)
            set_ui_visible(model_ui, true)
            set_ui_visible(dI, false)
            model_bound = true
        end
    else
        print('[HUD] model_ui alive:', is_ui_alive(model_ui), 'dH:', dH)
    end
    
    if not model_bound then
        set_ui_visible(model_ui, false)
        set_ui_visible(dI, true)
        set_ui_image(dI, get_hero_icon())
    end;
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), get_hero_name())
    set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), ', ')
    set_ui_progress(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_fill'), bc, bd)
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'),
      string.format('%s/%s', format_short_number(bc), format_short_number(bd)))
    set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'), ', ')
    set_ui_visible(resolve_combat_module_ui('exp_bar'), true)
    local exp_progress = math.max(0, math.min(1, bf / math.max(1, bg)))
    local dL = has_pending_evolution_choice()
    local bar_width = math.max(1, math.floor(EXP_BAR_MAX_WIDTH * exp_progress + 0.5))
    set_ui_text(resolve_combat_module_ui('exp_bar.level_label'), string.format('等级%d', get_hero_level()))
    set_ui_size(resolve_combat_module_ui('exp_bar.fill'), bar_width, EXP_BAR_HEIGHT)
    set_ui_pos(resolve_combat_module_ui('exp_bar.fill'), EXP_BAR_X_OFFSET + bar_width / 2, 12)
    set_ui_image_color(resolve_combat_module_ui('exp_bar.fill'), dL and { 255, 177, 37, 255 } or { 210, 38, 178, 255 })
    set_ui_image_color(resolve_combat_module_ui('exp_bar.fill_glow'), dL and { 255, 191, 58, 150 } or { 255, 86, 220, 72 })
    set_ui_image_color(resolve_combat_module_ui('exp_bar.evolve_glow'), dL and { 255, 173, 45, 210 } or { 255, 173, 45, 0 })
    set_ui_text_color(resolve_combat_module_ui('exp_bar.evolve_text'), dL and { 255, 226, 58, 255 } or { 255, 226, 58, 0 })
    set_ui_visible(resolve_combat_module_ui('exp_bar.evolve_click_area'), dL)
    set_ui_text(resolve_combat_module_ui('exp_bar.exp_text'),
      dL and '进化' or string.format('%s/%s', format_short_number(bf), format_short_number(bg)))
    set_ui_text_alignment(resolve_combat_module_ui('exp_bar.exp_text'), ', ')
  end;

  local function hide_challenge_row()
    set_ui_visible(resolve_combat_module_ui('challenge_row'), false)
    set_ui_visible(resolve_combat_module_ui('hero_level'), false)
  end;

  local function refresh_challenge_row()
    local dP = STATE.challenge_charge_map and STATE.challenge_charge_map.gold_trial or STATE.challenge_charges or 0;
    local dQ = STATE.challenge_charge_map and STATE.challenge_charge_map.wood_trial or STATE.challenge_charges or 0; set_ui_text(
    resolve_combat_module_ui('challenge_row.gold_trial.title'), '金币挑战')
    set_ui_text(resolve_combat_module_ui('challenge_row.gold_trial.count'), tostring(math.max(0, tonumber(dP) or 0)))
    set_ui_text(resolve_combat_module_ui('challenge_row.treasure_trial.title'), '木材挑战')
    set_ui_text(resolve_combat_module_ui('challenge_row.treasure_trial.count'), tostring(math.max(0, tonumber(dQ) or 0)))
    set_ui_text(resolve_combat_module_ui('challenge_row.climb_layer.title'), '当前波次')
    set_ui_text(resolve_combat_module_ui('challenge_row.climb_layer.count'),
      tostring(math.max(0, tonumber(STATE.current_wave_index) or 0)))
    set_ui_text(resolve_combat_module_ui('challenge_row.realm_progress.title'), '存活敌人')
    set_ui_text(resolve_combat_module_ui('challenge_row.realm_progress.count'),
      tostring(math.max(0, tonumber(STATE.total_enemy_alive) or 0)))
  end;

  local function refresh_skill_bar()
    local ck = get_evolution_slot_entries(EVOLUTION_SLOT_COUNT)
    for bL = 1, EVOLUTION_SLOT_COUNT do
      local cJ = string.format('skill_bar.skill_slot_%d', bL)
      local c4 = ck[bL]
      local dS = resolve_combat_module_ui(cJ)
      local dr = resolve_combat_module_ui(cJ .. '.icon')
      set_ui_visible(dS, true)
      set_ui_visible(dr, c4 ~= nil and c4.icon ~= nil)
      set_ui_image(dr, c4 and c4.icon or nil)
      if not c4 or not c4.icon then set_ui_image(dr, nil) end
    end
  end;

  local function refresh_buff_row()
    local entries = get_status_effects_fn and get_status_effects_fn(BUFF_SLOT_COUNT) or {}
    for slot_index = 1, BUFF_SLOT_COUNT do
      local slot_path = string.format('buff_row.buff_slot_%d', slot_index)
      local entry = entries[slot_index]
      local slot_ui = resolve_combat_module_ui(slot_path)
      local slot_icon = resolve_combat_module_ui(slot_path .. '.icon')
      set_ui_visible(slot_ui, entry ~= nil)
      set_ui_visible(slot_icon, entry ~= nil and entry.icon ~= nil)
      set_ui_image(slot_icon, entry and entry.icon or nil)
      set_ui_image_color(slot_icon, { 255, 255, 255, 255 })
      if not entry or not entry.icon then set_ui_image(slot_icon, nil) end
    end
  end;

  local function refresh_attr_list()
    refresh_player_attr_list()
  end;

  local function refresh_status_text()
    set_ui_visible(resolve_combat_module_ui('status_text'), true)
    set_ui_text(resolve_combat_module_ui('status_text'), '状态：')
    set_ui_text_alignment(resolve_combat_module_ui('status_text'), ', ')
    set_ui_text(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.station_hint'), get_station_hint_text())
    set_ui_text_alignment(resolve_ui_node('BattleBottomHUD.layout.right_station.card_panel.station_hint'), ', ')
  end;

  refresh_hud = function()
    ensure_hud()
    local hud_state = get_hud_state()
    ensure_buff_prefab()
    refresh_buff_list()
    set_static_labels()
    refresh_top_bar()
    refresh_attr_list()
    refresh_hero_panel()
    hide_challenge_row()
    refresh_skill_bar()
    refresh_buff_row()
    refresh_status_text()
    refresh_loadout_row()
    set_ui_visible(hud_state.big_cursor, hud_state.visible ~= false and ensure_ui_preferences().big_cursor)
    set_ui_visible(hud_state.attr_panel, hud_state.visible ~= false and hud_state.attr_panel_visible)
    set_ui_visible(hud_state.buff_prefab_root, hud_state.visible ~= false)
    refresh_tip_panel_visibility()
    refresh_hover_tip_visibility()
    if hud_state.bond_tip_visible and hud_state.active_tip_kind == 'weapon' then
      show_weapon_tip()
    end
    return hud_state
  end;

  local function set_hud_visible(visible)
    local hud_state = get_hud_state()
    hud_state.visible = visible == true; set_ui_visible(resolve_ui_node('top'), visible)
    set_ui_visible(resolve_ui_node('BattleBottomHUD'), visible)
    set_ui_visible(resolve_ui_node('GameHUD'), visible)
    set_ui_visible(resolve_ui_node('bottom_bg'), false)
    set_ui_visible(hud_state.attr_panel,
      visible == true and hud_state.attr_panel_visible)
    set_ui_visible(hud_state.tip_panel,
      visible == true and hud_state.tip_expires_at > (STATE.runtime_elapsed or 0))
    set_ui_visible(hud_state.hover_tip_panel,
      visible == true and hud_state.hover_tip_visible == true)
    set_ui_visible(hud_state.bond_tip_panel,
      visible == true and hud_state.bond_tip_visible == true)
    set_bond_tip_root_visible(visible == true and hud_state.bond_tip_visible == true)
    set_ui_visible(hud_state.big_cursor,
      visible == true and ensure_ui_preferences().big_cursor)
    set_ui_visible(hud_state.buff_prefab_root, visible == true)
  end;

  -- public api alias
  local api = {
    ensure_hud = ensure_hud,
    refresh_hud = refresh_hud,
    set_visible = set_hud_visible,
    show_tip_panel = show_runtime_tip_panel,
    toggle_attr_panel = toggle_runtime_attr_panel,
    safe_ui_call = safe_ui_call,
    set_ui_visible = set_ui_visible,
    set_ui_text = set_ui_text,
    set_ui_text_color = set_ui_text_color,
    set_ui_font_size = set_ui_font_size,
    set_ui_text_alignment = set_ui_text_alignment,
    set_ui_image = set_ui_image,
    set_ui_image_color = set_ui_image_color,
    set_ui_size = set_ui_size,
    set_ui_anchor = set_ui_anchor,
    set_ui_pos = set_ui_pos,
    set_ui_progress = set_ui_progress,
    bind_ui_model_unit = bind_ui_model_unit,
    apply_ui_model_camera = apply_ui_model_camera,
    set_ui_pos_percent = set_ui_pos_percent,
    toggle_big_cursor = toggle_big_cursor,
    toggle_damage_text_visible = toggle_damage_text_visible,
    toggle_hit_effects_visible = toggle_hit_effects_visible,
    toggle_soft_pause = toggle_soft_pause
  }
  _G.hud_system = api
  return api
end

return M
