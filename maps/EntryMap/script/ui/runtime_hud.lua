local UIRoot = require 'ui.ui_root'
local EvolutionObjects = require 'entry_objects.evolutions'
local HeroRoster = require 'data.object_tables.hero_roster'
local HeroFormSkills = require 'data.object_tables.hero_form_skills'

local M = {}

local NOTICE_DURATION = 8
local BOND_SLOT_COUNT = 8
local CENTER_SKILL_SLOT_COUNT = 5
local BOTTOM_STATUS_SLOT_COUNT = 5
local BATTLE_ATTR_ROW_NAMES = {
  'battle_power_row',
  'hero_attack_row',
  'hero_defense_row',
  'hero_power_row',
  'hero_intelligence_row',
  'hero_agility_row',
}
local HERO_MODEL_LAYOUT = {
  width = 108,
  height = 122,
  x = 92,
  y = 142,
}
local HERO_MODEL_CONFIG = {
  focus = { 0, 0, 88 },
  fov = 32,
  camera_pos = { 156, -108, 88 },
  camera_rot = { 0, 0, 0 },
  background = { 0, 0, 0, 0 },
}
local EXP_BAR_WIDTH = 388
local EXP_BAR_INNER_WIDTH = 374
local EXP_BAR_FILL_HEIGHT = 12
local EXP_BAR_FILL_LEFT = (EXP_BAR_WIDTH - EXP_BAR_INNER_WIDTH) / 2
local EVOLUTION_QUALITY_LABELS = {
  common = '普通',
  rare = '稀有',
  epic = '史诗',
}
local EVOLUTION_DEFS = EvolutionObjects.by_id or {}
local HERO_ROSTER_BY_UNIT_ID = HeroRoster.by_unit_id or {}
local HERO_FORM_SKILLS_BY_HERO_ID = HeroFormSkills.by_hero_id or {}

local function is_ui_alive(ui)
  return UIRoot.is_alive(ui)
end

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG or {}
  local y3 = env.y3
  local ATTACK_SKILL_SLOT_COUNT = math.max(1, tonumber(env.attack_skill_slot_count) or 5)
  local get_player = env.get_player
  local hero_attr_system = env.hero_attr_system
  local message = env.message or function() end
  local show_upgrade_choices = env.show_upgrade_choices
  local try_bond_draw = env.try_bond_draw
  local show_bond_progress = env.show_bond_progress
  local try_evolution_entry = env.try_evolution_entry
  local try_treasure_entry = env.try_treasure_entry
  local try_start_challenge = env.try_start_challenge
  local open_save_panel = env.open_save_panel
  local try_upgrade_growth_weapon = env.try_upgrade_growth_weapon
  local show_runtime_status = env.show_runtime_status
  local build_runtime_attr_dialog_chunks = env.build_runtime_attr_dialog_chunks
  local build_growth_weapon_tip_payload = env.build_growth_weapon_tip_payload
  local build_bond_slot_tip_payload = env.build_bond_slot_tip_payload
  local bond_draw_cost = math.max(0, tonumber(env.bond_draw_cost) or 100)
  local get_bond_slot_icon = env.get_bond_slot_icon
  local get_bottom_status_effect_entries = env.get_bottom_status_effect_entries
  local play_ui_click = env.play_ui_click
  local ensure_hud
  local refresh_hud

  local function get_player_safe()
    return get_player and get_player() or nil
  end

  local function ensure_preferences()
    STATE.ui_preferences = STATE.ui_preferences or {}
    local prefs = STATE.ui_preferences
    if prefs.hide_damage_text == nil then
      prefs.hide_damage_text = false
    end
    if prefs.hide_hit_effects == nil then
      prefs.hide_hit_effects = false
    end
    if prefs.big_cursor == nil then
      prefs.big_cursor = false
    end
    if prefs.soft_paused == nil then
      prefs.soft_paused = false
    end
    return prefs
  end

  local function get_runtime()
    STATE.runtime_hud = STATE.runtime_hud or {
      nodes = {},
      bound_events = {},
      visible = true,
      attr_panel_visible = false,
      tip_title_text = '',
      tip_body_text = '',
      tip_panel = nil,
      tip_panel_title = nil,
      tip_panel_body = nil,
      tip_expires_at = 0,
      hover_tip_panel = nil,
      hover_tip_panel_icon_bg = nil,
      hover_tip_panel_icon = nil,
      hover_tip_panel_title = nil,
      hover_tip_panel_subtitle = nil,
      hover_tip_panel_body = nil,
      hover_tip_visible = false,
      attr_panel = nil,
      attr_panel_title = nil,
      attr_panel_body = nil,
      attr_panel_hint = nil,
      big_cursor = nil,
      hero_model_ui = nil,
    }
    return STATE.runtime_hud
  end

  local function resolve_ui(path)
    local runtime = get_runtime()
    local cached = runtime.nodes[path]
    if is_ui_alive(cached) then
      return cached
    end
    local player = get_player_safe()
    if not player then
      return nil
    end
    local ui = UIRoot.resolve_ui(y3, player, path)
    runtime.nodes[path] = ui
    return ui
  end

  local function resolve_first_ui(paths)
    local runtime = get_runtime()
    local cache_key = '__first__:' .. table.concat(paths or {}, '|')
    local cached = runtime.nodes[cache_key]
    if is_ui_alive(cached) then
      return cached
    end
    local player = get_player_safe()
    if not player then
      return nil
    end
    local ui = UIRoot.resolve_first_ui(y3, player, paths)
    runtime.nodes[cache_key] = ui
    return ui
  end

  local function call_ui(ui, method_name, ...)
    if not is_ui_alive(ui) then
      return false
    end
    local method = ui[method_name]
    if type(method) ~= 'function' then
      return false
    end
    return pcall(method, ui, ...)
  end

  local function set_visible_if_alive(ui, visible)
    call_ui(ui, 'set_visible', visible == true)
  end

  local function set_text_if_alive(ui, text)
    call_ui(ui, 'set_text', text or '')
  end

  local function set_text_color_if_alive(ui, color)
    if color then
      call_ui(ui, 'set_text_color', color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_font_size_if_alive(ui, size)
    if size then
      call_ui(ui, 'set_font_size', size)
    end
  end

  local function set_text_alignment_if_alive(ui, horizontal, vertical)
    if horizontal and vertical then
      call_ui(ui, 'set_text_alignment', horizontal, vertical)
    end
  end

  local function set_image_if_alive(ui, image)
    if image ~= nil then
      call_ui(ui, 'set_image', image)
    end
  end

  local function set_image_color_if_alive(ui, color)
    if color then
      call_ui(ui, 'set_image_color', color[1], color[2], color[3], color[4] or 255)
    end
  end

  local function set_ui_size_if_alive(ui, width, height)
    if width and height then
      call_ui(ui, 'set_ui_size', width, height)
    end
  end

  local function set_anchor_if_alive(ui, x, y)
    if x ~= nil and y ~= nil then
      call_ui(ui, 'set_anchor', x, y)
    end
  end

  local function set_pos_if_alive(ui, x, y)
    if x ~= nil and y ~= nil then
      call_ui(ui, 'set_pos', x, y)
    end
  end

  local function set_progress_if_alive(ui, current, max_value)
    if not is_ui_alive(ui) then
      return
    end
    local final_max = math.max(1, math.floor((tonumber(max_value) or 1) + 0.5))
    local final_current = math.max(0, math.min(final_max, math.floor((tonumber(current) or 0) + 0.5)))
    call_ui(ui, 'set_max_progress_bar_value', final_max)
    call_ui(ui, 'set_current_progress_bar_value', final_current, 0)
  end

  local function set_ui_model_unit_if_alive(ui, unit, clone_effect, clone_attach, clone_material)
    if unit and unit.is_exist and not unit:is_exist() then
      unit = nil
    end
    if not is_ui_alive(ui) or not unit then
      return
    end
    call_ui(ui, 'set_ui_model_unit', unit, clone_effect == true, clone_attach == true, clone_material == true)
  end

  local function tune_ui_model_if_alive(ui, config)
    if not is_ui_alive(ui) or not config then
      return
    end
    if config.focus then
      call_ui(ui, 'set_ui_model_focus_pos', config.focus[1], config.focus[2], config.focus[3])
    end
    if config.fov then
      call_ui(ui, 'change_showroom_fov', config.fov)
    end
    if config.camera_pos then
      call_ui(ui, 'change_showroom_cposition', config.camera_pos[1], config.camera_pos[2], config.camera_pos[3])
    end
    if config.camera_rot then
      call_ui(ui, 'change_showroom_crotation', config.camera_rot[1], config.camera_rot[2], config.camera_rot[3])
    end
    if config.background then
      call_ui(ui, 'set_show_room_background_color',
        config.background[1], config.background[2], config.background[3], config.background[4] or 0)
    end
  end

  local function set_percent_pos_if_alive(ui, x, y)
    local player = get_player_safe()
    if not player or not is_ui_alive(ui) or not GameAPI or not GameAPI.set_ui_comp_pos_percent then
      return
    end
    pcall(GameAPI.set_ui_comp_pos_percent, player.handle, ui.handle, x, y)
  end

  local function compact_number(value)
    local number = tonumber(value) or 0
    local abs_number = math.abs(number)
    if abs_number >= 1000000 then
      local text = string.format('%.1fm', number / 1000000)
      return text:gsub('%.0m$', 'm')
    end
    if abs_number >= 10000 then
      local text = string.format('%.1fk', number / 1000)
      return text:gsub('%.0k$', 'k')
    end
    return tostring(math.floor(number + 0.5))
  end

  local function format_time(seconds)
    local total = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    local minute = total // 60
    local second = total % 60
    return string.format('%02d:%02d', minute, second)
  end

  local function percent_number(value)
    local number = tonumber(value) or 0
    if math.abs(number) <= 1 then
      number = number * 100
    end
    return number
  end

  local function format_percent(value)
    return string.format('%d%%', math.floor(percent_number(value) + 0.5))
  end

  local function format_signed_percent_pair(value_a, value_b)
    local total = percent_number(value_a) + percent_number(value_b)
    return string.format('%+d%%', math.floor(total + (total >= 0 and 0.5 or -0.5)))
  end

  local function format_signed_compact_number(value)
    local number = tonumber(value) or 0
    local sign = number >= 0 and '+' or '-'
    return sign .. compact_number(math.abs(number))
  end

  local function count_entries(source)
    if type(source) ~= 'table' then
      return 0
    end
    local count = 0
    for _ in pairs(source) do
      count = count + 1
    end
    return count
  end

  local function get_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
    value = tonumber(value) or 0
    if value ~= 0 or not fallback_name then
      return value
    end
    local fallback = hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name)
    return tonumber(fallback) or 0
  end

  local function get_hero_level()
    return math.max(1, math.floor(tonumber(STATE.hero_progress and STATE.hero_progress.level) or 1))
  end

  local function get_hero_name()
    if STATE.hero and STATE.hero.get_name and STATE.hero:is_exist() then
      local name = STATE.hero:get_name()
      if name and name ~= '' then
        return name
      end
    end
    return '英雄'
  end

  local function get_hero_icon()
    if STATE.hero and STATE.hero.get_icon and STATE.hero:is_exist() then
      return STATE.hero:get_icon()
    end
    return nil
  end

  local function get_unit_icon_by_key(unit_key)
    if unit_key and y3 and y3.unit and y3.unit.get_icon_by_key then
      return y3.unit.get_icon_by_key(unit_key)
    end
    return nil
  end

  local function get_hero_unit()
    if STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() then
      return STATE.hero
    end
    return nil
  end

  local function get_player_name()
    local player = get_player_safe()
    if player and player.get_name then
      local name = player:get_name()
      if name and name ~= '' then
        return name
      end
    end
    return '玩家'
  end

  local function get_hero_hp_data()
    local current_hp = STATE.hero and STATE.hero.is_exist and STATE.hero:is_exist() and (tonumber(STATE.hero:get_hp()) or 0) or 0
    local max_hp = math.max(1, get_attr('生命结算值', '生命'))
    return current_hp, max_hp
  end

  local function get_hero_exp_data()
    local exp_current = tonumber(STATE.hero_progress and STATE.hero_progress.exp) or 0
    local exp_max = tonumber(STATE.hero_progress and STATE.hero_progress.exp_to_next) or 1
    if exp_max <= 0 then
      exp_max = math.max(1, exp_current)
    end
    return exp_current, exp_max
  end

  local function has_pending_evolution_choice()
    local runtime = STATE.evolution_runtime or STATE.mark_runtime
    return runtime
      and runtime.awaiting_choice == true
      and runtime.current_choices
      and #runtime.current_choices > 0
      or false
  end

  local function get_growth_weapon_level()
    return STATE.gear_state
      and STATE.gear_state.items
      and STATE.gear_state.items.weapon
      and STATE.gear_state.items.weapon.level
      or 0
  end

  local function get_growth_weapon_item_key()
    local slot_cfg = CONFIG.gear_upgrade_config
      and CONFIG.gear_upgrade_config.slots
      and CONFIG.gear_upgrade_config.slots.weapon
      or nil
    return slot_cfg and slot_cfg.item_key or nil
  end

  local function get_inventory_item(slot_index)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() or not STATE.hero.get_item_by_slot then
      return nil
    end
    local ok, item = pcall(STATE.hero.get_item_by_slot, STATE.hero, '物品栏', slot_index)
    if not ok then
      return nil
    end
    return item
  end

  local function is_growth_weapon_item(item)
    if not item or not item.get_key then
      return false
    end
    local growth_item_key = get_growth_weapon_item_key()
    if not growth_item_key then
      return false
    end
    return tostring(item:get_key()) == tostring(growth_item_key)
  end

  local function build_growth_weapon_tip_text(payload)
    if not payload then
      return '当前没有成长武器数据。'
    end

    local lines = {}
    if payload.subtitle_text and payload.subtitle_text ~= '' then
      lines[#lines + 1] = tostring(payload.subtitle_text)
    end
    if payload.cost_text and payload.cost_text ~= '' then
      lines[#lines + 1] = tostring(payload.cost_text)
    end

    local attr_lines = payload.attr_lines or {}
    if #attr_lines > 0 then
      if #lines > 0 then
        lines[#lines + 1] = ''
      end
      lines[#lines + 1] = '当前属性增幅'
      for _, line in ipairs(attr_lines) do
        lines[#lines + 1] = tostring(line)
      end
    end

    local affix_lines = payload.affix_lines or {}
    if #affix_lines > 0 then
      if #lines > 0 then
        lines[#lines + 1] = ''
      end
      for _, affix in ipairs(affix_lines) do
        if affix.title and affix.title ~= '' then
          lines[#lines + 1] = tostring(affix.title)
        end
        if affix.body and affix.body ~= '' then
          lines[#lines + 1] = tostring(affix.body)
        end
      end
    end

    if #lines == 0 then
      return '当前没有成长武器数据。'
    end
    return table.concat(lines, '\n')
  end

  local function build_item_tip(item)
    if not item then
      return nil, nil
    end
    local title = item.get_name and item:get_name() or '物品'
    local lines = {}
    local description = item.get_description and item:get_description() or nil
    if description and description ~= '' then
      lines[#lines + 1] = tostring(description)
    end
    local stack = item.get_stack and tonumber(item:get_stack()) or 0
    if stack and stack > 1 then
      lines[#lines + 1] = string.format('层数：%d', stack)
    end
    local charge = item.get_charge and tonumber(item:get_charge()) or 0
    if charge and charge > 0 then
      lines[#lines + 1] = string.format('充能：%d', charge)
    end
    if #lines == 0 then
      lines[#lines + 1] = '当前没有额外说明。'
    end
    return tostring(title), table.concat(lines, '\n')
  end

  local function append_non_empty_line(target, text)
    local value = tostring(text or '')
    if value ~= '' then
      target[#target + 1] = value
    end
  end

  local function append_non_empty_lines(target, lines)
    for _, line in ipairs(lines or {}) do
      append_non_empty_line(target, line)
    end
  end

  local function append_multiline_text(target, text)
    local value = tostring(text or '')
    if value == '' then
      return
    end
    for line in value:gmatch('[^\n]+') do
      append_non_empty_line(target, line)
    end
  end

  local function build_growth_weapon_hover_tip_payload()
    local payload = build_growth_weapon_tip_payload and build_growth_weapon_tip_payload() or nil
    if not payload then
      return nil
    end

    local lines = {}
    if payload.cost_text and payload.cost_text ~= '' then
      lines[#lines + 1] = tostring(payload.cost_text)
    end

    local attr_lines = payload.attr_lines or {}
    if #attr_lines > 0 then
      if #lines > 0 then
        lines[#lines + 1] = ''
      end
      lines[#lines + 1] = '[武器属性]'
      append_non_empty_lines(lines, attr_lines)
    end

    local affix_lines = payload.affix_lines or {}
    if #affix_lines > 0 then
      if #lines > 0 then
        lines[#lines + 1] = ''
      end
      for _, affix in ipairs(affix_lines) do
        if affix.title and affix.title ~= '' then
          lines[#lines + 1] = '[' .. tostring(affix.title) .. ']'
        end
        if affix.body and affix.body ~= '' then
          lines[#lines + 1] = tostring(affix.body)
        end
      end
    end

    if #lines == 0 then
      lines[#lines + 1] = '当前没有成长武器数据。'
    end

    return {
      title = tostring(payload.title_text or '成长武器'),
      subtitle = tostring(payload.subtitle_text or ''),
      body = table.concat(lines, '\n'),
      icon = payload.icon_res,
    }
  end

  local function build_inventory_hover_tip_payload(slot_index)
    local item = get_inventory_item(slot_index)
    if item and is_growth_weapon_item(item) then
      return build_growth_weapon_hover_tip_payload()
    end

    local title, body = build_item_tip(item)
    if not title or not body then
      return nil
    end

    return {
      title = title,
      subtitle = '',
      body = body,
      icon = item and item.get_icon and item:get_icon() or nil,
    }
  end

  local function build_bond_slot_hover_tip_payload(slot)
    local payload = build_bond_slot_tip_payload and build_bond_slot_tip_payload(slot) or nil
    if not payload then
      return nil
    end

    local model = payload.tip_model or {}
    local title = tostring(model.item_name_text or payload.title_text or '羁绊')
    local subtitle_parts = {}
    if model.quality_text and model.quality_text ~= '' then
      subtitle_parts[#subtitle_parts + 1] = tostring(model.quality_text)
    end
    local bond_name = tostring(model.set_name_text or '')
    local progress_text = tostring(model.progress_text or '')
    if bond_name ~= '' or progress_text ~= '' then
      subtitle_parts[#subtitle_parts + 1] = '羁绊：' .. bond_name .. progress_text
    end

    local lines = {}
    if model.bonus_lines and #model.bonus_lines > 0 then
      lines[#lines + 1] = '[羁绊效果]'
      append_non_empty_lines(lines, model.bonus_lines)
    end

    if model.effect_body_text and model.effect_body_text ~= '' then
      if #lines > 0 then
        lines[#lines + 1] = ''
      end
      lines[#lines + 1] = '[吞噬条件]'
      append_multiline_text(lines, model.effect_body_text)
    end

    if model.set_body_lines and #model.set_body_lines > 0 then
      if #lines > 0 then
        lines[#lines + 1] = ''
      end
      local set_title = tostring(model.set_title_text or ''):gsub('：+$', '')
      lines[#lines + 1] = '[' .. (set_title ~= '' and set_title or '激活效果') .. ']'
      append_non_empty_lines(lines, model.set_body_lines)
    end

    if #lines == 0 then
      lines[#lines + 1] = '当前没有羁绊说明。'
    end

    return {
      title = title,
      subtitle = table.concat(subtitle_parts, '  '),
      body = table.concat(lines, '\n'),
      icon = model.icon_res or payload.icon_res,
    }
  end

  local function build_draw_button_hover_tip_payload()
    local lines = {
      '[左键点击]',
      string.format('本次消耗 %d 个木材', bond_draw_cost),
      string.format('当前拥有 %s 木材', compact_number(STATE.resources and STATE.resources.wood or 0)),
      '',
      '抽取羁绊卡牌，相同羁绊会自动吞噬入体。',
    }
    return {
      title = '抽卡 - [快捷键：F]',
      subtitle = '',
      body = table.concat(lines, '\n'),
      icon = nil,
    }
  end

  local function build_reward_button_hover_tip_payload()
    local lines = {
      '[左键点击]',
      '打开已吞卡牌列表与羁绊图鉴。',
      '',
      '羁绊三选一与羁绊 tips 相互独立，可以同时存在。',
    }
    return {
      title = '已吞卡牌 - [快捷键：I]',
      subtitle = '',
      body = table.concat(lines, '\n'),
      icon = nil,
    }
  end

  local function build_kill_reward_button_hover_tip_payload()
    local lines = {
      '[左键点击]',
      '优先打开当前待领取的进化/击杀奖励。',
      '如果当前没有待选奖励，则打开进化总览。',
    }
    return {
      title = '进化入口 - [快捷键：H]',
      subtitle = '',
      body = table.concat(lines, '\n'),
      icon = nil,
    }
  end

  local function build_fish_button_hover_tip_payload()
    local lines = {
      '[左键点击]',
      '打开存档面板；如果当前没有可打开的存档界面，则显示运行时状态。',
    }
    return {
      title = '存档 - [快捷键：P]',
      subtitle = '',
      body = table.concat(lines, '\n'),
      icon = nil,
    }
  end

  local function build_consumable_hover_tip_payload(slot_index)
    if slot_index == 1 then
      return {
        title = '属性宝石',
        subtitle = '类型：消耗品',
        body = table.concat({
          '[点击使用]',
          '可选择一条随机属性强化。',
          '英雄每升 5 级，或完成宝石挑战时，可获得 1 颗。',
        }, '\n'),
        icon = 300540000,
      }
    end
    if slot_index == 2 then
      return {
        title = '快捷道具 2',
        subtitle = '特殊栏位',
        body = '当前用于特殊功能扩展。',
        icon = nil,
      }
    end
    if slot_index == 3 then
      return {
        title = '快捷道具 3',
        subtitle = '特殊栏位',
        body = '当前用于特殊功能扩展。',
        icon = nil,
      }
    end
    return nil
  end

  local function build_attack_skill_display_entry(skill, display_index)
    if not skill then
      return nil
    end
    local lines = {}
    if skill.summary and skill.summary ~= '' then
      lines[#lines + 1] = tostring(skill.summary)
    end
    local damage_ratio = tonumber(skill.damage_ratio) or 0
    if damage_ratio > 0 then
      lines[#lines + 1] = string.format('倍率：%.0f%%', damage_ratio * 100)
    end
    local cast_range = math.max(0, tonumber(skill.cast_range or 0) + tonumber(skill.range_bonus or 0))
    if cast_range > 0 then
      lines[#lines + 1] = string.format('射程：%d', math.floor(cast_range + 0.5))
    end
    local base_cooldown = tonumber(skill.base_cooldown) or 0
    if base_cooldown > 0 and skill.id ~= 'basic_attack' then
      lines[#lines + 1] = string.format('基础冷却：%.1fs', base_cooldown)
    end
    if skill.id == 'basic_attack' then
      lines[#lines + 1] = string.format('攻速：%s', compact_number(get_attr('攻击速度')))
    end

    local cooldown_remaining = tonumber(skill.cooldown_remaining) or 0
    return {
      id = tostring(skill.id or ('skill_' .. tostring(display_index))),
      name = tostring(skill.name or skill.id or ('技能' .. tostring(display_index))),
      icon = skill.ui_icon or skill.icon,
      key = display_index == 1 and '普' or tostring(display_index),
      cooldown_text = cooldown_remaining > 0 and string.format('%.1fs', cooldown_remaining) or '就绪',
      legacy_cooldown_text = cooldown_remaining > 0 and string.format('%.1f', cooldown_remaining) or '',
      badge_text = skill.level and ('Lv.' .. tostring(skill.level)) or '',
      stack_text = '',
      tip_title = tostring(skill.name or skill.id or '技能'),
      tip_text = #lines > 0 and table.concat(lines, '\n') or '当前没有技能说明。',
    }
  end

  local function build_form_skill_display_entry(display_index)
    local form_system = STATE.hero_form_skills_system
    if not form_system or not form_system.get_active_skill then
      return nil
    end

    local skill = form_system.get_active_skill()
    if not skill then
      return nil
    end

    local entry = form_system.get_active_entry and form_system.get_active_entry() or nil
    local runtime = STATE.hero_form_skill_runtime or {}
    local cooldown_remaining = tonumber(runtime.cooldowns and runtime.cooldowns[skill.id]) or 0
    local counter = tonumber(runtime.counters and runtime.counters[skill.id]) or 0
    local trigger_value = math.max(0, math.floor(tonumber(skill.trigger_value) or 0))
    local lines = {}

    if entry and entry.title and entry.title ~= '' then
      lines[#lines + 1] = '真身：' .. tostring(entry.title)
    end
    if skill.subtitle and skill.subtitle ~= '' then
      lines[#lines + 1] = tostring(skill.subtitle)
    end
    if skill.summary and skill.summary ~= '' then
      lines[#lines + 1] = tostring(skill.summary)
    end
    if skill.item_desc and skill.item_desc ~= '' then
      lines[#lines + 1] = tostring(skill.item_desc)
    end
    if tonumber(skill.cooldown) and tonumber(skill.cooldown) > 0 then
      lines[#lines + 1] = string.format('冷却：%.1fs', tonumber(skill.cooldown))
    end

    return {
      id = tostring(skill.id or ('form_skill_' .. tostring(display_index))),
      name = tostring(skill.name or '真身神通'),
      icon = skill.ui_icon or skill.icon or get_hero_icon(),
      key = '真',
      cooldown_text = cooldown_remaining > 0 and string.format('%.1fs', cooldown_remaining) or '就绪',
      legacy_cooldown_text = cooldown_remaining > 0 and string.format('%.1f', cooldown_remaining) or '',
      badge_text = entry and entry.rarity or '',
      stack_text = trigger_value > 1 and string.format('%d/%d', math.min(counter, trigger_value), trigger_value) or '',
      tip_title = tostring(skill.name or '真身神通'),
      tip_text = #lines > 0 and table.concat(lines, '\n') or '当前没有神通说明。',
    }
  end

  local function get_evolution_quality_label(quality)
    return EVOLUTION_QUALITY_LABELS[quality] or '普通'
  end

  local function get_evolution_runtime()
    return STATE.evolution_runtime or STATE.mark_runtime
  end

  local function get_evolution_hero_entry(def)
    local unit_id = def and def.hero_unit_id or nil
    if unit_id == nil then
      return nil
    end
    return HERO_ROSTER_BY_UNIT_ID[unit_id]
  end

  local function get_evolution_hero_skill(def)
    local entry = get_evolution_hero_entry(def)
    if not entry then
      return nil, nil
    end
    return HERO_FORM_SKILLS_BY_HERO_ID[entry.id], entry
  end

  local function build_evolution_skill_display_entry(def, display_index)
    if not def then
      return nil
    end

    local skill, entry = get_evolution_hero_skill(def)
    local display_name = entry and entry.name or def.name or ('进化' .. tostring(display_index))
    local display_role = entry and entry.title or skill and skill.subtitle or '英雄真身'
    local summary = skill and skill.summary or entry and entry.summary or def.summary or ''
    local lines = {
      string.format('[%s] %s', get_evolution_quality_label(def.quality), display_role),
    }

    if skill and skill.name and skill.name ~= '' then
      lines[#lines + 1] = '技能：' .. tostring(skill.name)
    end
    if summary ~= '' then
      lines[#lines + 1] = tostring(summary)
    end

    return {
      id = tostring(def.id or ('evolution_' .. tostring(display_index))),
      name = tostring(display_name),
      icon = get_unit_icon_by_key(def.hero_unit_id) or get_hero_icon(),
      key = tostring(display_index),
      cooldown_text = '',
      legacy_cooldown_text = '',
      badge_text = get_evolution_quality_label(def.quality),
      stack_text = '',
      tip_title = string.format('%s·%s', tostring(display_name), tostring(display_role)),
      tip_text = table.concat(lines, '\n'),
    }
  end

  local function get_display_skill_entries(max_slots)
    local entries = {}
    local attack_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots or nil

    for slot = 1, math.min(ATTACK_SKILL_SLOT_COUNT, max_slots or ATTACK_SKILL_SLOT_COUNT) do
      local skill = attack_slots and attack_slots[slot] or nil
      if skill then
        entries[#entries + 1] = build_attack_skill_display_entry(skill, slot)
      end
    end

    if #entries < max_slots then
      local form_entry = build_form_skill_display_entry(#entries + 1)
      if form_entry then
        entries[#entries + 1] = form_entry
      end
    end

    return entries
  end

  local function get_center_skill_bar_entries(max_slots)
    local entries = {}
    local limit = math.max(1, tonumber(max_slots) or CENTER_SKILL_SLOT_COUNT)
    local runtime = get_evolution_runtime()
    local ordered_ids = runtime and (runtime.ordered_evolution_ids or runtime.ordered_mark_ids) or nil

    for slot = 1, limit, 1 do
      local evolution_id = ordered_ids and ordered_ids[slot] or nil
      local def = evolution_id and EVOLUTION_DEFS[evolution_id] or nil
      if def then
        local entry = build_evolution_skill_display_entry(def, slot)
        if entry then
          entries[#entries + 1] = entry
        end
      end
    end

    return entries
  end

  local function get_attack_skill_slot_display_entry(slot)
    if slot < 1 or slot > ATTACK_SKILL_SLOT_COUNT then
      return nil
    end
    local attack_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots or nil
    local skill = attack_slots and attack_slots[slot] or nil
    return build_attack_skill_display_entry(skill, slot)
  end

  local function get_pending_choice_notice()
    if STATE.awaiting_upgrade and STATE.current_upgrade_choices and #STATE.current_upgrade_choices > 0 then
      return '强化待选', '当前强化候选已出现，请点击面板完成选择。'
    end
    if STATE.gear_state and STATE.gear_state.awaiting_choice and STATE.gear_state.current_choices then
      return '武器待选', '成长武器词缀候选已出现，请点击面板完成选择。'
    end
    if STATE.bond_runtime and STATE.bond_runtime.awaiting_choice and STATE.bond_runtime.current_choices then
      return '羁绊待选', '羁绊候选已生成，请点击面板完成选择。'
    end
    local evolution_runtime = STATE.evolution_runtime or STATE.mark_runtime
    if evolution_runtime and evolution_runtime.awaiting_choice and evolution_runtime.current_choices then
      return '进化待选', '击杀奖励已到位，请在二选一面板中点击完成进化选择。'
    end
    if STATE.treasure_runtime then
      if STATE.treasure_runtime.awaiting_choice and STATE.treasure_runtime.current_choices then
        return '宝物待选', '宝物候选已到位，请点击面板完成选择。'
      end
      if STATE.treasure_runtime.awaiting_replace and STATE.treasure_runtime.pending_replace_choice then
        return '宝物替换', '当前宝物栏已满，请选择替换槽位。'
      end
    end
    return nil, nil
  end

  local function get_notice_text()
    local runtime = get_runtime()
    if runtime.tip_panel and runtime.tip_expires_at and runtime.tip_expires_at > (STATE.runtime_elapsed or 0) then
      return runtime.tip_title_text ~= '' and runtime.tip_title_text or '系统提示', runtime.tip_body_text or ''
    end
    local pending_title, pending_text = get_pending_choice_notice()
    if pending_title and pending_text then
      return pending_title, pending_text
    end

    local entries = STATE.battle_event_feed and STATE.battle_event_feed.entries or nil
    if entries and #entries > 0 then
      local entry = entries[#entries]
      if entry and entry.text and entry.text ~= '' then
        if entry.style == 'reward' then
          return '奖励提示', entry.text
        end
        if entry.style == 'warning' then
          return '战斗警报', entry.text
        end
        if entry.style == 'rare' then
          return '稀有事件', entry.text
        end
        if entry.style == 'positive' then
          return '进度更新', entry.text
        end
        return '系统消息', entry.text
      end
    end

    return '操作提示', 'F 抽卡，I 查看已吞卡牌，H 查看进化，P 打开存档。'
  end

  local function build_status_text()
    local prefs = ensure_preferences()
    local pending_title, _ = get_pending_choice_notice()
    if pending_title then
      return '状态：' .. pending_title
    end
    local damage_text = prefs.hide_damage_text and '跳字关' or '跳字开'
    local effect_text = prefs.hide_hit_effects and '特效关' or '特效开'
    local pause_text = prefs.soft_paused and '已暂停' or '进行中'
    return string.format('状态：%s | %s | %s', pause_text, damage_text, effect_text)
  end

  local function build_station_hint()
    return '按F抽卡，相同羁绊的卡牌，自动吞噬入体'
  end

  local function build_hotkey_help_text()
    return table.concat({
      'G / 强化：攻击技能三选一',
      'F / 抽卡：羁绊三选一',
      'I / 已吞：查看已吞羁绊',
      'H / 进化：查看真身 / 杀敌奖励',
      'V / 宝物：查看宝物入口',
      'Q / W / E / R：试炼入口',
      'TAB / T：属性面板',
      'SPACE：打印状态概览',
      'P：打开存档',
    }, '\n')
  end

  local function ensure_overlay_widgets()
    local runtime = get_runtime()
    runtime.attr_panel = resolve_first_ui({
      'BattleBottomHUD.layout.attr_panel',
      'BattleBottomHUD.layout.right_station.attr_panel',
    })
    runtime.attr_panel_title = resolve_first_ui({
      'BattleBottomHUD.layout.attr_panel.title',
      'BattleBottomHUD.layout.right_station.attr_panel.title',
    })
    runtime.attr_panel_body = resolve_first_ui({
      'BattleBottomHUD.layout.attr_panel.body',
      'BattleBottomHUD.layout.right_station.attr_panel.body',
    })
    runtime.attr_panel_hint = resolve_first_ui({
      'BattleBottomHUD.layout.attr_panel.hint',
      'BattleBottomHUD.layout.right_station.attr_panel.hint',
    })
    set_visible_if_alive(runtime.attr_panel, false)
    call_ui(runtime.attr_panel, 'set_intercepts_operations', true)
    set_text_alignment_if_alive(runtime.attr_panel_title, '左', '中')
    set_text_alignment_if_alive(runtime.attr_panel_body, '左', '中')
    set_text_alignment_if_alive(runtime.attr_panel_hint, '右', '中')

    if runtime.bound_events.static_attr_panel_close ~= runtime.attr_panel and is_ui_alive(runtime.attr_panel) then
      runtime.bound_events.static_attr_panel_close = runtime.attr_panel
      runtime.attr_panel:add_fast_event('左键-点击', function()
        local active_runtime = get_runtime()
        active_runtime.attr_panel_visible = false
        set_visible_if_alive(active_runtime.attr_panel, false)
      end)
    end

    runtime.tip_panel = resolve_first_ui({
      'BattleBottomHUD.layout.tip_panel',
      'BattleBottomHUD.layout.right_station.tip_panel',
    })
    runtime.tip_panel_title = resolve_first_ui({
      'BattleBottomHUD.layout.tip_panel.title',
      'BattleBottomHUD.layout.right_station.tip_panel.title',
    })
    runtime.tip_panel_body = resolve_first_ui({
      'BattleBottomHUD.layout.tip_panel.body',
      'BattleBottomHUD.layout.right_station.tip_panel.body',
    })
    runtime.tip_panel_hint = resolve_first_ui({
      'BattleBottomHUD.layout.tip_panel.hint',
      'BattleBottomHUD.layout.right_station.tip_panel.hint',
    })
    set_visible_if_alive(runtime.tip_panel, false)
    call_ui(runtime.tip_panel, 'set_intercepts_operations', true)
    set_text_alignment_if_alive(runtime.tip_panel_title, '左', '中')
    set_text_alignment_if_alive(runtime.tip_panel_body, '左', '中')
    set_text_alignment_if_alive(runtime.tip_panel_hint, '右', '中')

    if runtime.bound_events.static_tip_panel_close ~= runtime.tip_panel and is_ui_alive(runtime.tip_panel) then
      runtime.bound_events.static_tip_panel_close = runtime.tip_panel
      runtime.tip_panel:add_fast_event('左键-点击', function()
        local active_runtime = get_runtime()
        active_runtime.tip_expires_at = 0
        set_visible_if_alive(active_runtime.tip_panel, false)
      end)
    end

    runtime.hover_tip_panel = resolve_first_ui({
      'BattleBottomHUD.layout.hover_tip_panel',
      'BattleBottomHUD.layout.right_station.hover_tip_panel',
    })
    runtime.hover_tip_panel_icon_bg = resolve_first_ui({
      'BattleBottomHUD.layout.hover_tip_panel.icon_bg',
      'BattleBottomHUD.layout.right_station.hover_tip_panel.icon_bg',
    })
    runtime.hover_tip_panel_icon = resolve_first_ui({
      'BattleBottomHUD.layout.hover_tip_panel.icon',
      'BattleBottomHUD.layout.right_station.hover_tip_panel.icon',
    })
    runtime.hover_tip_panel_title = resolve_first_ui({
      'BattleBottomHUD.layout.hover_tip_panel.title',
      'BattleBottomHUD.layout.right_station.hover_tip_panel.title',
    })
    runtime.hover_tip_panel_subtitle = resolve_first_ui({
      'BattleBottomHUD.layout.hover_tip_panel.subtitle',
      'BattleBottomHUD.layout.right_station.hover_tip_panel.subtitle',
    })
    runtime.hover_tip_panel_body = resolve_first_ui({
      'BattleBottomHUD.layout.hover_tip_panel.body',
      'BattleBottomHUD.layout.right_station.hover_tip_panel.body',
    })
    set_visible_if_alive(runtime.hover_tip_panel, false)
    call_ui(runtime.hover_tip_panel, 'set_intercepts_operations', false)
    set_text_alignment_if_alive(runtime.hover_tip_panel_title, '左', '中')
    set_text_alignment_if_alive(runtime.hover_tip_panel_subtitle, '左', '中')
    set_text_alignment_if_alive(runtime.hover_tip_panel_body, '左', '中')

    if not is_ui_alive(runtime.big_cursor) then
      local player = get_player_safe()
      local hud = player and UIRoot.get_overlay_parent(y3, player) or nil
      if not hud then
        return
      end
      local text = hud:create_child('文本')
      text:set_ui_size(60, 60)
      text:set_text('◎')
      text:set_font_size(28)
      text:set_text_color(255, 233, 158, 235)
      text:set_text_alignment('中', '中')
      text:set_z_order(9380)
      text:set_intercepts_operations(false)
      call_ui(text, 'set_follow_mouse', true, 12, -10)
      runtime.big_cursor = text
      set_visible_if_alive(text, false)
    end
  end

  local function resolve_attr_row(index)
    local row_name = BATTLE_ATTR_ROW_NAMES[index]
    if not row_name then
      return {}
    end
    local prefix = 'BattleBottomHUD.layout.left_station.player_attr_list.' .. row_name
    return {
      root = resolve_ui(prefix),
      label = resolve_ui(prefix .. '.label'),
      value = resolve_ui(prefix .. '.value'),
      delta = resolve_ui(prefix .. '.delta'),
      icon = resolve_ui(prefix .. '.icon'),
    }
  end

  local function refresh_hover_tip_panel_position()
    return
  end

  local function hide_hover_tip_panel()
    local runtime = get_runtime()
    runtime.hover_tip_visible = false
    set_visible_if_alive(runtime.hover_tip_panel, false)
  end

  local function show_hover_tip_panel(payload)
    if not payload then
      hide_hover_tip_panel()
      return
    end

    ensure_hud()
    local runtime = get_runtime()
    refresh_hover_tip_panel_position()
    if not is_ui_alive(runtime.hover_tip_panel) then
      return
    end
    runtime.hover_tip_visible = true
    set_text_if_alive(runtime.hover_tip_panel_title, payload.title or '说明')
    set_text_if_alive(runtime.hover_tip_panel_subtitle, payload.subtitle or '')
    set_text_if_alive(runtime.hover_tip_panel_body, payload.body or '')
    set_font_size_if_alive(runtime.hover_tip_panel_title, 16)
    set_font_size_if_alive(runtime.hover_tip_panel_subtitle, 13)
    set_font_size_if_alive(runtime.hover_tip_panel_body, 14)
    set_text_color_if_alive(runtime.hover_tip_panel_title, { 204, 226, 255, 255 })
    set_text_color_if_alive(runtime.hover_tip_panel_subtitle, { 255, 213, 96, 255 })
    set_text_color_if_alive(runtime.hover_tip_panel_body, { 222, 232, 244, 255 })
    set_visible_if_alive(runtime.hover_tip_panel_subtitle, payload.subtitle ~= nil and payload.subtitle ~= '')
    set_visible_if_alive(runtime.hover_tip_panel_icon_bg, payload.icon ~= nil)
    set_visible_if_alive(runtime.hover_tip_panel_icon, payload.icon ~= nil)
    set_image_if_alive(runtime.hover_tip_panel_icon, payload.icon)
    set_visible_if_alive(runtime.hover_tip_panel, runtime.visible ~= false)
  end

  local function resolve_center_module_ui(suffix)
    return resolve_ui('BattleBottomHUD.layout.center_hub.combat_module.' .. suffix)
  end

  local function ensure_runtime_hero_model()
    local runtime = get_runtime()
    if is_ui_alive(runtime.hero_model_ui) then
      return runtime.hero_model_ui
    end
    local hero_panel = resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel')
    if not is_ui_alive(hero_panel) or type(hero_panel.create_child) ~= 'function' then
      return nil
    end
    local ok, hero_model_ui = pcall(hero_panel.create_child, hero_panel, '模型')
    if not ok or not is_ui_alive(hero_model_ui) then
      return nil
    end
    runtime.hero_model_ui = hero_model_ui
    set_anchor_if_alive(hero_model_ui, 0.5, 0.5)
    set_ui_size_if_alive(hero_model_ui, HERO_MODEL_LAYOUT.width, HERO_MODEL_LAYOUT.height)
    set_pos_if_alive(hero_model_ui, HERO_MODEL_LAYOUT.x, HERO_MODEL_LAYOUT.y)
    set_visible_if_alive(hero_model_ui, true)
    tune_ui_model_if_alive(hero_model_ui, HERO_MODEL_CONFIG)
    return hero_model_ui
  end

  local function bind_click_once(key, ui, callback)
    local runtime = get_runtime()
    if runtime.bound_events[key] == ui and is_ui_alive(ui) then
      return
    end
    if not is_ui_alive(ui) or not ui.add_fast_event then
      return
    end
    runtime.bound_events[key] = ui
    call_ui(ui, 'set_intercepts_operations', true)
    ui:add_fast_event('左键-点击', function()
      if play_ui_click then
        play_ui_click()
      end
      callback()
    end)
  end

  local function bind_hover_once(key, ui, on_enter, on_leave)
    local runtime = get_runtime()
    if runtime.bound_events[key] == ui and is_ui_alive(ui) then
      return
    end
    if not is_ui_alive(ui) or not ui.add_fast_event then
      return
    end
    runtime.bound_events[key] = ui
    ui:add_fast_event('鼠标-移入', function()
      if on_enter then
        on_enter(ui)
      end
    end)
    ui:add_fast_event('鼠标-移出', function()
      if on_leave then
        on_leave(ui)
      end
    end)
  end

  local function hide_tip_panel()
    local runtime = get_runtime()
    runtime.tip_expires_at = 0
    set_visible_if_alive(runtime.tip_panel, false)
  end

  local function show_tip_panel(text, duration, title)
    ensure_hud()
    local runtime = get_runtime()
    local final_duration = tonumber(duration)
    if final_duration ~= nil and final_duration <= 0 then
      runtime.tip_expires_at = math.huge
    else
      runtime.tip_expires_at = (STATE.runtime_elapsed or 0) + math.max(1, final_duration or NOTICE_DURATION)
    end
    runtime.tip_title_text = title or '系统提示'
    runtime.tip_body_text = tostring(text or '')
    set_text_if_alive(runtime.tip_panel_title, title or '系统提示')
    set_text_if_alive(runtime.tip_panel_body, tostring(text or ''))
    set_visible_if_alive(runtime.tip_panel, runtime.visible ~= false)
  end

  local function refresh_tip_panel_visibility()
    local runtime = get_runtime()
    local should_show = runtime.tip_expires_at and runtime.tip_expires_at > (STATE.runtime_elapsed or 0)
    set_visible_if_alive(runtime.tip_panel, runtime.visible ~= false and should_show)
  end

  local function refresh_hover_tip_panel_visibility()
    local runtime = get_runtime()
    refresh_hover_tip_panel_position()
    set_visible_if_alive(runtime.hover_tip_panel, runtime.visible ~= false and runtime.hover_tip_visible == true)
  end

  local function toggle_big_cursor()
    local prefs = ensure_preferences()
    prefs.big_cursor = not prefs.big_cursor
    local runtime = get_runtime()
    set_visible_if_alive(runtime.big_cursor, runtime.visible ~= false and prefs.big_cursor)
    show_tip_panel(
      prefs.big_cursor and '大鼠标已开启，鼠标位置会显示辅助圈。' or '大鼠标已关闭。',
      4,
      '鼠标辅助'
    )
  end

  local function toggle_damage_text()
    local prefs = ensure_preferences()
    prefs.hide_damage_text = not prefs.hide_damage_text
    show_tip_panel(
      prefs.hide_damage_text and '已屏蔽跳字。' or '已恢复跳字显示。',
      4,
      '本地显示'
    )
  end

  local function toggle_hit_effects()
    local prefs = ensure_preferences()
    prefs.hide_hit_effects = not prefs.hide_hit_effects
    show_tip_panel(
      prefs.hide_hit_effects and '已屏蔽局内技能特效。' or '已恢复局内技能特效。',
      4,
      '本地显示'
    )
  end

  local function toggle_pause()
    local prefs = ensure_preferences()
    prefs.soft_paused = not prefs.soft_paused
    if prefs.soft_paused then
      y3.game.enable_soft_pause()
      show_tip_panel('对局已暂停，再点一次继续。', 4, '战斗控制')
    else
      y3.game.resume_soft_pause()
      show_tip_panel('对局已继续。', 4, '战斗控制')
    end
  end

  local function toggle_attr_panel()
    ensure_hud()
    local runtime = get_runtime()
    runtime.attr_panel_visible = not runtime.attr_panel_visible
    if runtime.attr_panel_visible then
      local chunks = build_runtime_attr_dialog_chunks and build_runtime_attr_dialog_chunks() or {
        string.format('等级：%d', get_hero_level()),
        string.format('攻击：%s', compact_number(get_attr('攻击结算值', '攻击'))),
        string.format('护甲：%s', compact_number(get_attr('护甲结算值', '护甲'))),
        string.format('力量：%s', compact_number(get_attr('最终力量', '力量'))),
        string.format('智力：%s', compact_number(get_attr('最终智力', '智力'))),
        string.format('敏捷：%s', compact_number(get_attr('最终敏捷', '敏捷'))),
      }
      set_text_if_alive(runtime.attr_panel_title, '属性总览')
      set_text_if_alive(runtime.attr_panel_body, table.concat(chunks, '\n\n'))
    end
    set_visible_if_alive(runtime.attr_panel, runtime.visible ~= false and runtime.attr_panel_visible)
    return runtime.attr_panel_visible
  end

  local function refresh_button_texts()
    local prefs = ensure_preferences()

    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_exit'), '退出')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_setting'), '设置')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_save'), '存档')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_pause'), prefs.soft_paused and '继续' or '暂停')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_powerup'), '强化')
    set_text_if_alive(resolve_ui('top.top.left_buttons.btn_hotkey'), '键位')

    set_visible_if_alive(resolve_ui('BattleBottomHUD.layout.left_station.toggle_frame'), false)

    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'), 'F抽卡')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'), '已吞卡牌')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'), '杀敌抽奖')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'), '摆烂钓鱼')

    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button.hotkey'), '')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button.hotkey'), '')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.hotkey'), '')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button.hotkey'), '')
  end

  local function show_growth_weapon_tip_panel()
    local payload = build_growth_weapon_tip_payload and build_growth_weapon_tip_payload() or nil
    if not payload then
      hide_tip_panel()
      return
    end
    show_tip_panel(build_growth_weapon_tip_text(payload), 0, payload.title_text or '成长武器')
  end

  local function show_inventory_slot_tip(slot_index)
    local item = get_inventory_item(slot_index)
    if item and is_growth_weapon_item(item) then
      show_growth_weapon_tip_panel()
      return
    end

    local title, body = build_item_tip(item)
    if title and body then
      show_tip_panel(body, 0, title)
      return
    end
    hide_tip_panel()
  end

  local function show_skill_entry_tip(slot_index, max_slots)
    local entries = get_display_skill_entries(max_slots or 4)
    local entry = entries[slot_index]
    if not entry then
      hide_tip_panel()
      return
    end
    show_tip_panel(entry.tip_text or '当前没有技能说明。', 0, entry.tip_title or entry.name or '技能')
  end

  local function show_attack_skill_slot_tip(slot_index)
    local entry = get_center_skill_bar_entries(CENTER_SKILL_SLOT_COUNT)[slot_index]
    if not entry then
      hide_tip_panel()
      return
    end
    show_tip_panel(entry.tip_text or '当前没有技能说明。', 0, entry.tip_title or entry.name or '技能')
  end

  local function show_bottom_status_effect_tip(slot_index)
    local entries = get_bottom_status_effect_entries and get_bottom_status_effect_entries(ATTACK_SKILL_SLOT_COUNT) or {}
    local entry = entries[slot_index]
    if not entry then
      hide_tip_panel()
      return
    end
    show_tip_panel(entry.tip_text or '当前没有效果说明。', 0, entry.tip_title or '魔法效果')
  end

  local function show_battle_loadout_slot_tip(slot_index)
    show_hover_tip_panel(build_inventory_hover_tip_payload(slot_index))
  end

  local function show_battle_bond_slot_tip(slot_index)
    show_hover_tip_panel(build_bond_slot_hover_tip_payload(slot_index))
  end

  local function show_draw_button_hover_tip()
    show_hover_tip_panel(build_draw_button_hover_tip_payload())
  end

  local function show_reward_button_hover_tip()
    show_hover_tip_panel(build_reward_button_hover_tip_payload())
  end

  local function show_kill_reward_button_hover_tip()
    show_hover_tip_panel(build_kill_reward_button_hover_tip_payload())
  end

  local function show_fish_button_hover_tip()
    show_hover_tip_panel(build_fish_button_hover_tip_payload())
  end

  local function show_consumable_hover_tip(slot_index)
    show_hover_tip_panel(build_consumable_hover_tip_payload(slot_index))
  end

  local function refresh_battle_loadout_row()
    local growth_payload = build_growth_weapon_tip_payload and build_growth_weapon_tip_payload() or nil
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), '物品栏')
    set_ui_size_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), 92, 17)
    set_text_alignment_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.loadout_row.loadout_title'), '中', '中')

    for slot = 1, 6 do
      local prefix = string.format('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_%d', slot)
      local item = get_inventory_item(slot)
      local icon = item and item.get_icon and item:get_icon() or nil
      local icon_ui = resolve_ui(prefix .. '.icon')

      if not icon and slot == 1 and growth_payload then
        icon = growth_payload.icon_res
      end

      set_visible_if_alive(icon_ui, icon ~= nil)
      set_image_if_alive(icon_ui, icon)
      if not icon then
        set_image_if_alive(icon_ui, nil)
      end
    end
  end

  ensure_hud = function()
    ensure_preferences()
    ensure_overlay_widgets()

    bind_click_once('top_pause', resolve_ui('top.top.left_buttons.btn_pause'), function()
      toggle_pause()
      refresh_hud()
    end)
    bind_click_once('top_powerup', resolve_ui('top.top.left_buttons.btn_powerup'), function()
      if show_upgrade_choices then
        show_upgrade_choices()
      end
      refresh_hud()
    end)
    bind_click_once('top_save', resolve_ui('top.top.left_buttons.btn_save'), function()
      if open_save_panel and open_save_panel() ~= false then
        return
      end
      if show_runtime_status then
        show_runtime_status()
      end
    end)
    bind_click_once('top_hotkey', resolve_ui('top.top.left_buttons.btn_hotkey'), function()
      show_tip_panel(build_hotkey_help_text(), 10, '快捷键')
    end)

    bind_click_once('toggle_damage', resolve_ui('BattleBottomHUD.layout.left_station.toggle_frame.toggle_damage.button'), function()
      toggle_damage_text()
      refresh_hud()
    end)
    bind_click_once('toggle_effects', resolve_ui('BattleBottomHUD.layout.left_station.toggle_frame.toggle_sfx.button'), function()
      toggle_hit_effects()
      refresh_hud()
    end)
    bind_click_once('toggle_cursor', resolve_ui('BattleBottomHUD.layout.left_station.toggle_frame.toggle_cursor.button'), function()
      toggle_big_cursor()
      refresh_hud()
    end)

    bind_click_once('draw_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button.button'), function()
      if try_bond_draw then
        try_bond_draw()
      end
      refresh_hud()
    end)
    bind_click_once('reward_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button.button'), function()
      if show_bond_progress then
        show_bond_progress()
      else
        show_tip_panel('当前没有已吞卡牌面板可展示。', 4, '羁绊进度')
      end
      refresh_hud()
    end)
    bind_click_once('kill_reward_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button.button'), function()
      if try_evolution_entry then
        try_evolution_entry()
      end
      refresh_hud()
    end)
    bind_click_once('fish_button', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button.button'), function()
      if open_save_panel and open_save_panel() ~= false then
        return
      end
      if show_runtime_status then
        show_runtime_status()
      end
    end)

    bind_hover_once('draw_button_hover', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.draw_button'), function()
      show_draw_button_hover_tip()
    end, function()
      hide_hover_tip_panel()
    end)
    bind_hover_once('reward_button_hover', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.reward_button'), function()
      show_reward_button_hover_tip()
    end, function()
      hide_hover_tip_panel()
    end)
    bind_hover_once('kill_reward_button_hover', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.kill_reward_button'), function()
      show_kill_reward_button_hover_tip()
    end, function()
      hide_hover_tip_panel()
    end)
    bind_hover_once('fish_button_hover', resolve_ui('BattleBottomHUD.layout.right_station.card_panel.fish_button'), function()
      show_fish_button_hover_tip()
    end, function()
      hide_hover_tip_panel()
    end)

    for slot = 1, 3 do
      bind_hover_once('battle_consumable_hover_' .. tostring(slot),
        resolve_ui(string.format('BattleBottomHUD.layout.right_station.consumable_panel.slot_%d', slot)),
        function()
          show_consumable_hover_tip(slot)
        end,
        function()
          hide_hover_tip_panel()
        end)
    end

    bind_click_once('gold_trial', resolve_center_module_ui('challenge_row.gold_trial'), function()
      if try_start_challenge then
        try_start_challenge('gold_trial')
      end
      refresh_hud()
    end)
    bind_click_once('treasure_trial', resolve_center_module_ui('challenge_row.treasure_trial'), function()
      if try_start_challenge then
        try_start_challenge('treasure_trial')
      end
      refresh_hud()
    end)
    bind_click_once('battle_loadout_slot_1', resolve_ui('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_1'), function()
      if try_upgrade_growth_weapon then
        try_upgrade_growth_weapon('loadout_slot_click')
      end
      refresh_hud()
    end)

    for slot = 1, 6 do
      bind_hover_once('battle_loadout_hover_' .. tostring(slot),
        resolve_ui(string.format('BattleBottomHUD.layout.right_station.loadout_row.loadout_slot_%d', slot)),
        function()
          show_battle_loadout_slot_tip(slot)
        end,
        function()
          hide_hover_tip_panel()
        end)
    end

    for slot = 1, CENTER_SKILL_SLOT_COUNT do
      bind_hover_once('battle_skill_hover_' .. tostring(slot),
        resolve_center_module_ui(string.format('skill_bar.skill_slot_%d', slot)),
        function()
          show_attack_skill_slot_tip(slot)
        end,
        function()
          hide_tip_panel()
        end)
    end

    for slot = 1, BOTTOM_STATUS_SLOT_COUNT do
      bind_hover_once('battle_buff_hover_' .. tostring(slot),
        resolve_center_module_ui(string.format('buff_row.buff_slot_%d', slot)),
        function()
          show_bottom_status_effect_tip(slot)
        end,
        function()
          hide_tip_panel()
        end)
    end

    for slot = 1, 7 do
      bind_hover_once('battle_bond_hover_' .. tostring(slot),
        resolve_ui(string.format('BattleBottomHUD.layout.right_station.card_panel.card_slot_%d', slot)),
        function()
          show_battle_bond_slot_tip(slot)
        end,
        function()
          hide_hover_tip_panel()
        end)
      bind_click_once('battle_bond_slot_' .. tostring(slot),
        resolve_ui(string.format('BattleBottomHUD.layout.right_station.card_panel.card_slot_%d', slot)),
        function()
          if show_bond_progress then
            show_bond_progress()
          else
            show_tip_panel('当前没有羁绊进度可展示。', 4, '羁绊进度')
          end
        end)
    end

    bind_click_once('battle_exp_bar_evolve', resolve_center_module_ui('exp_bar'), function()
      if try_evolution_entry then
        try_evolution_entry()
      end
      refresh_hud()
    end)

    refresh_button_texts()
    return get_runtime()
  end

  local function refresh_top_panel()
    set_text_if_alive(resolve_ui('top.top.金币.image_3.label_2'), compact_number(STATE.resources and STATE.resources.gold or 0))
    set_text_if_alive(resolve_ui('top.top.木材.image_3.label_2'), compact_number(STATE.resources and STATE.resources.wood or 0))
    set_text_if_alive(resolve_ui('top.top.人口.image_3.label_2'), compact_number(STATE.total_kills or 0))

    set_text_if_alive(resolve_ui('top.top.金币.delta'), string.format('+%s/s', compact_number(get_attr('每秒金币'))))
    set_text_if_alive(resolve_ui('top.top.木材.delta'), string.format('+%s/s', compact_number(get_attr('每秒木材'))))
    set_text_if_alive(resolve_ui('top.top.人口.delta'), string.format('敌 %d', math.max(0, tonumber(STATE.total_enemy_alive) or 0)))

    local notice_title, notice_text = get_notice_text()
    set_text_if_alive(resolve_ui('top.top.system_notice.notice_title'), notice_title)
    set_text_if_alive(resolve_ui('top.top.system_notice.notice_text'), notice_text)

    local stage_name = STATE.current_stage_def and (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '当前章节'
    local mode_name = STATE.current_mode_def and STATE.current_mode_def.display_name or '战斗模式'
    local wave_name = STATE.active_wave and STATE.active_wave.wave and STATE.active_wave.wave.name
      or (STATE.current_wave_index and STATE.current_wave_index > 0 and string.format('第%d波', STATE.current_wave_index) or '未开始')
    local phase_title = ({ get_pending_choice_notice() })[1] or (STATE.session_phase == 'battle' and '战斗中' or '准备中')
    local threat_text
    if STATE.active_wave and STATE.active_wave.wave and STATE.active_wave.wave.boss_spawn_sec and STATE.active_wave.boss_spawned ~= true then
      threat_text = string.format('Boss %.1fs', math.max(0, (STATE.active_wave.wave.boss_spawn_sec or 0) - (STATE.active_wave.elapsed or 0)))
    else
      threat_text = string.format('敌人 %d', math.max(0, tonumber(STATE.total_enemy_alive) or 0))
    end

    set_text_if_alive(resolve_ui('top.tophud.layout_2.curlevel'), stage_name)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.curlevel_sub'), mode_name)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.gametime'), format_time(STATE.runtime_elapsed or 0))
    set_text_if_alive(resolve_ui('top.tophud.layout_2.wave'), wave_name)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.phase_text'), phase_title)
    set_text_if_alive(resolve_ui('top.tophud.layout_2.threat_text'), threat_text)

    set_text_if_alive(resolve_ui('top.top.scoreboard.title'), '玩家状态')
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_name'), get_player_name())
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_power'), compact_number(get_attr('攻击结算值', '攻击')))
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_state'), STATE.session_phase == 'battle' and '战斗中' or '局外')
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_level'), tostring(get_hero_level()))
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_equip'),
      tostring(STATE.treasure_runtime and STATE.treasure_runtime.active_slots and #STATE.treasure_runtime.active_slots or 0))
    set_text_if_alive(resolve_ui('top.top.scoreboard.player_swallow'),
      tostring(STATE.bond_runtime and count_entries(STATE.bond_runtime.completed_root_sets) or 0))

    for index = 2, 4 do
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_name_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_power_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_state_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_level_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_equip_%d', index)), '-')
      set_text_if_alive(resolve_ui(string.format('top.top.scoreboard.player_swallow_%d', index)), '-')
    end
  end

  local function refresh_attr_rows()
    local attack_value = compact_number(get_attr('攻击结算值', '攻击'))
    local armor_value = compact_number(get_attr('护甲结算值', '护甲'))
    local rows = {
      { label = '战力', value = attack_value, delta = '暴击 ' .. format_percent(get_attr('物理暴击')) },
      { label = '攻击', value = attack_value, delta = format_signed_percent_pair(get_attr('攻击增幅'), get_attr('最终攻击')) },
      { label = '护甲', value = armor_value, delta = format_signed_percent_pair(get_attr('护甲增幅'), get_attr('最终护甲')) },
      { label = '力量', value = compact_number(get_attr('最终力量', '力量')), delta = format_signed_percent_pair(get_attr('力量增幅'), get_attr('最终力量增幅')) },
      { label = '智力', value = compact_number(get_attr('最终智力', '智力')), delta = format_signed_percent_pair(get_attr('智力增幅'), get_attr('最终智力增幅')) },
      { label = '敏捷', value = compact_number(get_attr('最终敏捷', '敏捷')), delta = '爆伤 ' .. format_percent(get_attr('物理暴伤')) },
    }

    for index, row_data in ipairs(rows) do
      local row = resolve_attr_row(index)
      set_visible_if_alive(row.root, true)
      set_text_if_alive(row.label, row_data.label)
      set_text_if_alive(row.value, row_data.value)
      set_text_if_alive(row.delta, row_data.delta)
      set_text_color_if_alive(row.delta, { 131, 210, 255, 255 })
    end
  end

  local function refresh_hero_panel()
    local current_hp, max_hp = get_hero_hp_data()
    local exp_current, exp_max = get_hero_exp_data()
    local hero_unit = get_hero_unit()
    local hero_portrait_ui = resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_portrait')
    local hero_model_ui = ensure_runtime_hero_model()
    local using_model = is_ui_alive(hero_model_ui) and hero_unit ~= nil

    set_visible_if_alive(hero_portrait_ui, not using_model)
    if using_model then
      set_visible_if_alive(hero_model_ui, true)
      set_ui_model_unit_if_alive(hero_model_ui, hero_unit, false, true, true)
      tune_ui_model_if_alive(hero_model_ui, HERO_MODEL_CONFIG)
    else
      set_visible_if_alive(hero_model_ui, false)
      set_image_if_alive(hero_portrait_ui, get_hero_icon())
    end
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), get_hero_name())
    set_text_alignment_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_name'), '中', '中')
    set_progress_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_fill'), current_hp, max_hp)
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'),
      string.format('%s/%s', compact_number(current_hp), compact_number(max_hp)))
    set_text_alignment_if_alive(resolve_ui('BattleBottomHUD.layout.center_hub.hero_panel.hero_hp_text'), '中', '中')

    set_visible_if_alive(resolve_center_module_ui('exp_bar'), true)
    local exp_ratio = math.max(0, math.min(1, exp_current / math.max(1, exp_max)))
    local can_evolve = has_pending_evolution_choice()
    local fill_width = math.max(1, math.floor(EXP_BAR_INNER_WIDTH * exp_ratio + 0.5))
    set_text_if_alive(resolve_center_module_ui('exp_bar.level_label'), string.format('等级：%d', get_hero_level()))
    set_ui_size_if_alive(resolve_center_module_ui('exp_bar.fill'), fill_width, EXP_BAR_FILL_HEIGHT)
    set_pos_if_alive(resolve_center_module_ui('exp_bar.fill'), EXP_BAR_FILL_LEFT + fill_width / 2, 12)
    set_image_color_if_alive(resolve_center_module_ui('exp_bar.fill'), can_evolve and { 255, 177, 37, 255 } or { 210, 38, 178, 255 })
    set_image_color_if_alive(resolve_center_module_ui('exp_bar.fill_glow'), can_evolve and { 255, 191, 58, 150 } or { 255, 86, 220, 72 })
    set_image_color_if_alive(resolve_center_module_ui('exp_bar.evolve_glow'), can_evolve and { 255, 173, 45, 210 } or { 255, 173, 45, 0 })
    set_text_color_if_alive(resolve_center_module_ui('exp_bar.evolve_text'), can_evolve and { 255, 226, 58, 255 } or { 255, 226, 58, 0 })
    set_text_if_alive(resolve_center_module_ui('exp_bar.exp_text'), can_evolve and '' or
      string.format('%s/%s', compact_number(exp_current), compact_number(exp_max)))
    set_text_alignment_if_alive(resolve_center_module_ui('exp_bar.exp_text'), '中', '中')
  end

  local function refresh_center_module_cleanup()
    set_visible_if_alive(resolve_center_module_ui('challenge_row'), false)
    set_visible_if_alive(resolve_center_module_ui('hero_level'), false)
  end

  local function refresh_challenge_row()
    local gold_charge = STATE.challenge_charge_map and STATE.challenge_charge_map.gold_trial or STATE.challenge_charges or 0
    local treasure_charge = STATE.challenge_charge_map and STATE.challenge_charge_map.treasure_trial or STATE.challenge_charges or 0
    set_text_if_alive(resolve_center_module_ui('challenge_row.gold_trial.title'), '金币挑战')
    set_text_if_alive(resolve_center_module_ui('challenge_row.gold_trial.count'), tostring(math.max(0, tonumber(gold_charge) or 0)))
    set_text_if_alive(resolve_center_module_ui('challenge_row.treasure_trial.title'), '宝物挑战')
    set_text_if_alive(resolve_center_module_ui('challenge_row.treasure_trial.count'), tostring(math.max(0, tonumber(treasure_charge) or 0)))
    set_text_if_alive(resolve_center_module_ui('challenge_row.climb_layer.title'), '当前波次')
    set_text_if_alive(resolve_center_module_ui('challenge_row.climb_layer.count'),
      tostring(math.max(0, tonumber(STATE.current_wave_index) or 0)))
    set_text_if_alive(resolve_center_module_ui('challenge_row.realm_progress.title'), '存活敌人')
    set_text_if_alive(resolve_center_module_ui('challenge_row.realm_progress.count'),
      tostring(math.max(0, tonumber(STATE.total_enemy_alive) or 0)))
  end

  local function refresh_skill_bar()
    local entries = get_center_skill_bar_entries(CENTER_SKILL_SLOT_COUNT)
    for slot = 1, CENTER_SKILL_SLOT_COUNT do
      local prefix = string.format('skill_bar.skill_slot_%d', slot)
      local entry = entries[slot]
      local root_ui = resolve_center_module_ui(prefix)
      local icon_ui = resolve_center_module_ui(prefix .. '.icon')
      local key_ui = resolve_center_module_ui(prefix .. '.key')
      local cooldown_ui = resolve_center_module_ui(prefix .. '.cooldown')
      local label_ui = resolve_center_module_ui(prefix .. '.label')
      set_visible_if_alive(root_ui, true)
      set_visible_if_alive(icon_ui, entry ~= nil and entry.icon ~= nil)
      set_image_if_alive(icon_ui, entry and entry.icon or nil)
      set_visible_if_alive(key_ui, false)
      set_text_if_alive(key_ui, '')
      set_text_if_alive(cooldown_ui, entry and (entry.legacy_cooldown_text or '') or '')
      set_text_if_alive(label_ui, entry and (entry.badge_text or '') or '')
      set_text_alignment_if_alive(label_ui, '中', '中')
      set_text_alignment_if_alive(cooldown_ui, '右', '中')
      if not entry or not entry.icon then
        set_image_if_alive(icon_ui, nil)
      end
    end
  end

  local function refresh_buff_row()
    local entries = get_bottom_status_effect_entries and get_bottom_status_effect_entries(BOTTOM_STATUS_SLOT_COUNT) or {}
    for slot = 1, BOTTOM_STATUS_SLOT_COUNT do
      local prefix = string.format('buff_row.buff_slot_%d', slot)
      local entry = entries[slot]
      local root_ui = resolve_center_module_ui(prefix)
      local icon_ui = resolve_center_module_ui(prefix .. '.icon')

      set_visible_if_alive(root_ui, entry ~= nil)
      set_visible_if_alive(icon_ui, entry ~= nil and entry.icon ~= nil)
      set_image_if_alive(icon_ui, entry and entry.icon or nil)
      set_image_color_if_alive(icon_ui, {255, 255, 255, 255})
      if not entry or not entry.icon then
        set_image_if_alive(icon_ui, nil)
      end
    end
  end

  local function refresh_left_station()
    refresh_attr_rows()
  end

  local function refresh_action_area()
    set_visible_if_alive(resolve_center_module_ui('status_text'), true)
    set_text_if_alive(resolve_center_module_ui('status_text'), '状态：')
    set_text_alignment_if_alive(resolve_center_module_ui('status_text'), '左', '中')
    set_text_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.station_hint'), build_station_hint())
    set_text_alignment_if_alive(resolve_ui('BattleBottomHUD.layout.right_station.card_panel.station_hint'), '中', '中')
  end

  local function refresh_bond_slots()
    for slot = 1, BOND_SLOT_COUNT do
      local prefix = string.format('BattleBottomHUD.layout.right_station.card_panel.card_slot_%d', slot)
      local icon_ui = resolve_ui(prefix .. '.icon')
      local icon = get_bond_slot_icon and get_bond_slot_icon(slot) or nil
      set_visible_if_alive(resolve_ui(prefix), slot <= 7 or slot == 8)
      if icon then
        set_visible_if_alive(icon_ui, true)
        set_image_if_alive(icon_ui, icon)
      else
        set_visible_if_alive(icon_ui, false)
        set_image_if_alive(icon_ui, nil)
      end
    end
  end

  refresh_hud = function()
    ensure_hud()
    local runtime = get_runtime()
    refresh_button_texts()
    refresh_top_panel()
    refresh_left_station()
    refresh_hero_panel()
    refresh_center_module_cleanup()
    refresh_skill_bar()
    refresh_buff_row()
    refresh_action_area()
    refresh_bond_slots()
    refresh_battle_loadout_row()

    set_visible_if_alive(runtime.big_cursor, runtime.visible ~= false and ensure_preferences().big_cursor)
    set_visible_if_alive(runtime.attr_panel, runtime.visible ~= false and runtime.attr_panel_visible)
    refresh_tip_panel_visibility()
    refresh_hover_tip_panel_visibility()
    return runtime
  end

  local function set_visible(visible)
    local runtime = get_runtime()
    runtime.visible = visible == true
    set_visible_if_alive(resolve_ui('top'), visible)
    set_visible_if_alive(resolve_ui('BattleBottomHUD'), visible)
    set_visible_if_alive(resolve_ui('GameHUD'), false)
    set_visible_if_alive(resolve_ui('bottom_bg'), false)
    set_visible_if_alive(runtime.attr_panel, visible == true and runtime.attr_panel_visible)
    set_visible_if_alive(runtime.tip_panel, visible == true and runtime.tip_expires_at > (STATE.runtime_elapsed or 0))
    set_visible_if_alive(runtime.hover_tip_panel, visible == true and runtime.hover_tip_visible == true)
    set_visible_if_alive(runtime.big_cursor, visible == true and ensure_preferences().big_cursor)
  end

  return {
    ensure_hud = ensure_hud,
    refresh_hud = refresh_hud,
    set_visible = set_visible,
    show_tip_panel = show_tip_panel,
    toggle_attr_panel = toggle_attr_panel,
  }
end

return M
