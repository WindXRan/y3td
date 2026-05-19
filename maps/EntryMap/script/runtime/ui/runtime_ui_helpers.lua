-- runtime_ui_helpers.lua — UI 辅助工具集（选择面板、HUD 切换、羁绊吞噬面板等）
-- 自初始化模块，require 时自动设置 _G.runtime_ui_helpers

local y3 = y3
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers
local ui_root = require 'ui.ui_root'
local QualityImageTable = require 'data.tables.economy.quality_image_table'

-- 暂未连接羁绊提示模型构建器，使用空桩
local bond_tip_builder = { build_from_choice = function() return nil end }

-- UI 标签常量（暂为空，后续从配置表读取）
local SKILL_BLOCK_TITLE = ''
local SKILL_SECTION_TEMPLATE = ''
local SKILL_SECTION_FALLBACK = ''

local helpers
local STATE = _G.STATE

-- 外层依赖（通过 _G 读取，require 时需确保已设置）
local get_player_fn = BootHelpers.get_player
local get_hud_system_fn = _G.get_hud_system
local get_pending_round_choice_kind_fn = _G.get_pending_round_choice_kind
local refresh_current_choice_fn = _G.refresh_current_choice
local apply_round_choice_fn = _G.apply_round_choice
local defer_choice_panel_fn = _G.defer_choice_panel
local get_growth_weapon_item_key_fn = _G.get_growth_weapon_item_key
local get_evolution_quality_label_fn = _G.get_evolution_quality_label
local build_bond_swallow_panel_model_fn = _G.build_bond_swallow_panel_model

-- ============================================================
-- UI 安全操作工具函数
-- ============================================================

local function is_valid_ui(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function set_ui_visible(ui, visible)
  if is_valid_ui(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function set_ui_text(ui, text)
  if is_valid_ui(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

local function set_ui_button_text(ui, text)
  local str = tostring(text or '')
  if not is_valid_ui(ui) then return end
  if ui.set_text then
    ui:set_text(str)
  end
  if ui.set_btn_status_string then
    ui:set_btn_status_string('静态', str)
    ui:set_btn_status_string('悬浮', str)
    ui:set_btn_status_string('按下', str)
    ui:set_btn_status_string('禁用', str)
  end
end

local function set_ui_font_size(ui, size)
  if is_valid_ui(ui) and ui.set_font_size and size then
    ui:set_font_size(size)
  end
end

local function set_ui_image(ui, image)
  if is_valid_ui(ui) and ui.set_image and image and image ~= 0 then
    ui:set_image(image)
  end
end

local function set_ui_image_color(ui, color)
  if is_valid_ui(ui) and ui.set_image_color and color then
    ui:set_image_color(color[1] or 255, color[2] or 255, color[3] or 255, color[4] or 255)
  end
end

local function set_ui_button_enable(ui, enabled)
  if is_valid_ui(ui) and ui.set_button_enable then
    ui:set_button_enable(enabled == true)
  end
end

local function set_ui_intercept(ui, intercept)
  if is_valid_ui(ui) and ui.set_intercepts_operations then
    ui:set_intercepts_operations(intercept == true)
  end
end

local function set_ui_z_order(ui, z_order)
  if is_valid_ui(ui) and ui.set_z_order and z_order then
    ui:set_z_order(z_order)
  end
end

-- ============================================================
-- 羁绊选择面板缓存
-- ============================================================

local bond_choice_panels = {
  BondChoice2 = nil,
  BondChoice3 = nil,
  BondChoice4 = nil,
}
local bond_swallow_panel = nil
local bond_swallow_close_initialized = false
local refresh_bond_swallow_fn

-- 事件注册表（防止重复绑定）
local event_registry = {}

-- Z-order 常量
local Z_HUD = 9500
local Z_PANEL = 9560
local Z_BUTTON = 9570
local Z_CHOICE = 9540
local DEFAULT_ICON = 999

local REFRESH_COST_TABLE = { 40, 80, 100 }

-- ============================================================
-- 品质框图片解析
-- ============================================================

local function resolve_quality_frame_image(quality)
  if QualityImageTable and QualityImageTable.get_frame_image then
    local img = QualityImageTable.get_frame_image(quality)
    if img and img ~= 0 then return img end
  end
  return nil
end

-- ============================================================
-- 面板系统清理
-- ============================================================

local function install_panel_systems()
  STATE.message_prompt_system = nil
  STATE.talk_panel_system = nil
  STATE.inventory_panel_system = nil
end

-- ============================================================
-- 获取羁绊选择面板
-- ============================================================

local function get_bond_choice_panel(panel_key)
  local cached = bond_choice_panels[panel_key]
  if is_valid_ui(cached) then return cached end

  local player = get_player_fn and get_player_fn() or nil
  if not player then return nil end

  local panel = ui_root.resolve_ui(y3, player, panel_key)
  bond_choice_panels[panel_key] = panel
  return panel
end

local function get_child_ui(panel_key, child_path)
  local panel = get_bond_choice_panel(panel_key)
  if not panel then return nil end
  if not child_path or child_path == '' then return panel end
  return ui_root.resolve_child(panel, child_path)
end

-- ============================================================
-- 面板名称/路径工具
-- ============================================================

local function hide_all_bond_choice_panels()
  set_ui_visible(get_bond_choice_panel('BondChoice2'), false)
  set_ui_visible(get_bond_choice_panel('BondChoice3'), false)
  set_ui_visible(get_bond_choice_panel('BondChoice4'), false)
end

local function get_panel_name(choice_count)
  return 'BondChoice4'
end

local function get_section_path(panel_key)
  if panel_key == 'BondChoice2' then return 'bond_choice_2' end
  if panel_key == 'BondChoice4' then return 'bond_choice_4' end
  return 'bond_choice_3'
end

local function get_panel_suffix(panel_key)
  return '4'
end

-- ============================================================
-- 字符串工具
-- ============================================================

local function trim_str(text)
  if text == nil then return '' end
  return tostring(text):gsub('^%s+', ''):gsub('%s+$', '')
end

local function get_quality_label(quality, kind)
  if kind == 'evolution' and get_evolution_quality_label_fn then
    return get_evolution_quality_label_fn(quality)
  end
  if quality == 'legendary' then return '传说' end
  if quality == 'epic' then return '史诗' end
  if quality == 'rare' or quality == 'excellent' then return '稀有' end
  return '普通'
end

local function get_refresh_cost(index)
  local slot = math.min((tonumber(index) or 0) + 1, #REFRESH_COST_TABLE)
  return REFRESH_COST_TABLE[slot] or REFRESH_COST_TABLE[#REFRESH_COST_TABLE]
end

local function get_icon_by_item_key(item_key)
  if item_key and y3 and y3.item and y3.item.get_icon_id_by_key then
    return y3.item.get_icon_id_by_key(item_key)
  end
  return DEFAULT_ICON
end

local function get_icon_by_unit_key(unit_key)
  if unit_key and y3 and y3.unit and y3.unit.get_icon_by_key then
    return y3.unit.get_icon_by_key(unit_key)
  end
  return DEFAULT_ICON
end

local function get_growth_weapon_name()
  local item_key = get_growth_weapon_item_key_fn and get_growth_weapon_item_key_fn() or nil
  if item_key and y3 and y3.item and y3.item.get_name_by_key then
    return y3.item.get_name_by_key(item_key)
  end
  return '成长武器'
end

local function get_growth_weapon_icon()
  return get_icon_by_item_key(get_growth_weapon_item_key_fn and get_growth_weapon_item_key_fn() or nil)
end

-- ============================================================
-- 文本行拆分
-- ============================================================

local function split_text_lines(text, max_lines)
  local lines = {}
  local str = tostring(text or '')
  str = str:gsub('\r\n', '\n'):gsub('\r', '\n')

  -- 如果没有换行符，按标点拆分
  if string.find(str, '\n', 1, true) == nil then
    str = str:gsub('。%s*', '。\n')
    str = str:gsub('；%s*', '\n')
    str = str:gsub(';%s*', '\n')
    str = str:gsub('，', '\n')
    str = str:gsub(',%s*', '\n')
  end

  str = str:gsub('\n+', '\n')

  for line in string.gmatch(str, '[^\n]+') do
    local trimmed = trim_str(line)
    if trimmed ~= '' then
      lines[#lines + 1] = trimmed
    end
    if #lines >= (max_lines or 2) then break end
  end
  return lines
end

-- ============================================================
-- 选择项数据模型构建
-- ============================================================

local function create_choice_model(title, subtitle, body, icon, quality, enabled)
  local lines = type(body) == 'table' and body or split_text_lines(body, 2)
  return {
    title_text = trim_str(title),
    subtitle_text = trim_str(subtitle),
    body_lines = lines,
    icon = icon or DEFAULT_ICON,
    quality = quality or 'common',
    enabled = (enabled ~= false),
  }
end

local function build_bond_entry(entry)
  local current_lines = split_text_lines(entry and entry.current_text or '', 2)
  local desc_lines = split_text_lines(entry and entry.desc_text or '', 2)
  local lines = {}
  local seen = {}
  for _, line in ipairs(current_lines) do
    local trimmed = trim_str(line):gsub('^当前', ''):gsub('：$', '')
    if trimmed ~= '' and not seen[trimmed] then
      seen[trimmed] = true
      lines[#lines + 1] = trimmed
    end
  end
  if #lines < 2 then
    for _, line in ipairs(desc_lines) do
      if #lines >= 2 then break end
      local trimmed = trim_str(line):gsub('^当前', ''):gsub('：$', '')
      if trimmed ~= '' and not seen[trimmed] then
        seen[trimmed] = true
        lines[#lines + 1] = trimmed
      end
    end
  end

  local root_name = trim_str(entry and entry.bond_root_name or '')
  local progress_text = trim_str(entry and entry.bond_root_progress_text or '')
  local tag = ''
  if root_name ~= '' then
    if progress_text ~= '' then
      tag = string.format('羁绊： %s (%s)', root_name, progress_text)
    else
      tag = '羁绊： ' .. root_name
    end
  else
    tag = trim_str(entry and entry.title_text or '')
    if tag ~= '' then tag = '羁绊： ' .. tag end
  end

  local name = trim_str(entry and (entry.pretty_display_name or entry.display_name or entry.title_text) or '')
  if name == '' then name = '未命名单位' end

  local ret = create_choice_model(
    name, tag, lines,
    entry and (entry.ui_icon or entry.icon) or DEFAULT_ICON,
    entry and entry.quality or 'common'
  )
  ret.source_choice = entry
  ret.tip_model = bond_tip_builder.build_from_choice(entry)
  return ret
end

local function build_gear_affix_entry(entry)
  local gear_state = STATE and STATE.gear_state or nil
  local pending_affix = gear_state and gear_state.pending_affix_choice or nil
  local affix_level = pending_affix and tonumber(pending_affix.level) or 0
  local quality_str = get_quality_label(entry and entry.quality or nil)
  local tag
  if affix_level > 0 then
    tag = string.format('[%s] %s Lv.%d', quality_str, get_growth_weapon_name(), affix_level)
  else
    tag = string.format('[%s] %s后缀', quality_str, get_growth_weapon_name())
  end
  return create_choice_model(
    entry and (entry.display_name or entry.id) or '',
    tag,
    entry and entry.summary or '',
    get_growth_weapon_icon(),
    entry and entry.quality or 'common'
  )
end

local function build_evolution_entry(entry)
  local evolution_runtime = STATE and STATE.evolution_runtime or nil
  local current_round = evolution_runtime and evolution_runtime.current_round or nil
  return create_choice_model(
    entry and entry.name or '未命名专精',
    string.format('[%s] %s', get_quality_label(entry and entry.quality or nil, 'evolution'), current_round and current_round.ui_title or '专精选择'),
    entry and entry.summary or '',
    get_icon_by_unit_key(entry and entry.hero_unit_id or nil),
    entry and entry.quality or 'common'
  )
end

-- ============================================================
-- 当前选择状态获取
-- ============================================================

local function get_current_choice_state()
  if STATE.choice_panel_hidden == true then return nil end

  local kind = get_pending_round_choice_kind_fn and get_pending_round_choice_kind_fn() or nil

  if kind == 'gear' then
    local gear_state = STATE and STATE.gear_state or nil
    if not gear_state or gear_state.awaiting_choice ~= true or not gear_state.current_choices or #gear_state.current_choices == 0 then
      return nil
    end
    local entries = {}
    for _, entry in ipairs(gear_state.current_choices) do
      entries[#entries + 1] = build_gear_affix_entry(entry)
    end
    local round = gear_state.current_round or gear_state.pending_affix_choice or {}
    local refresh_left = tonumber(round.free_refresh_left or 0) or 0
    return {
      kind = kind,
      panel_name = get_panel_name(#entries),
      choices = entries,
      current_round = round,
      can_refresh = refresh_left > 0,
      disabled_refresh_text = '刷新次数用尽',
    }
  end

  if kind == 'bond' then
    local bond_runtime = STATE and STATE.bond_runtime or nil
    if not bond_runtime or bond_runtime.awaiting_choice ~= true or not bond_runtime.current_choices or #bond_runtime.current_choices == 0 then
      return nil
    end
    local entries = {}
    for _, entry in ipairs(bond_runtime.current_choices) do
      entries[#entries + 1] = build_bond_entry(entry)
    end
    return {
      kind = kind,
      panel_name = get_panel_name(#entries),
      choices = entries,
      current_round = bond_runtime.current_round or bond_runtime.current_offer_round,
      can_refresh = true,
    }
  end

  if kind == 'evolution' then
    local evolution_runtime = STATE and STATE.evolution_runtime or nil
    if not evolution_runtime or evolution_runtime.awaiting_choice ~= true or not evolution_runtime.current_choices or #evolution_runtime.current_choices == 0 then
      return nil
    end
    local entries = {}
    for _, entry in ipairs(evolution_runtime.current_choices) do
      entries[#entries + 1] = build_evolution_entry(entry)
    end
    return {
      kind = 'evolution',
      panel_name = get_panel_name(#entries),
      choices = entries,
      current_round = evolution_runtime.current_round,
      can_refresh = false,
      disabled_refresh_text = '当前无法刷新',
    }
  end

  return nil
end

-- ============================================================
-- 羁绊卡片填充
-- ============================================================

local function fill_bond_card(panel_key, card_index, entry)
  local suffix = get_panel_suffix(panel_key)
  local card_path = string.format('bond_choice_%s.cards_row.card_%d', suffix, card_index)
  local card_ui = get_child_ui(panel_key, card_path)
  if not card_ui then return end

  set_ui_visible(card_ui, entry ~= nil)
  if not entry then return end

  set_ui_text(get_child_ui(panel_key, card_path .. string.format('.title_%d', card_index)), entry.title_text)
  set_ui_text(get_child_ui(panel_key, card_path .. string.format('.bond_%d', card_index)), entry.subtitle_text)
  set_ui_image(get_child_ui(panel_key, card_path .. string.format('.icon_%d', card_index)), entry.icon or DEFAULT_ICON)

  local body_lines = entry.body_lines or {}
  set_ui_text(get_child_ui(panel_key, card_path .. string.format('.value_1_%d', card_index)), body_lines[1] or '')
  set_ui_text(get_child_ui(panel_key, card_path .. string.format('.value_2_%d', card_index)), body_lines[2] or '')
  set_ui_visible(get_child_ui(panel_key, card_path .. string.format('.value_2_%d', card_index)), body_lines[2] ~= nil)

  -- 品质颜色
  local title_ui = get_child_ui(panel_key, card_path .. string.format('.title_%d', card_index))
  if entry.quality == 'legendary' then
    if is_valid_ui(title_ui) and title_ui.set_text_color then title_ui:set_text_color(255, 184, 64, 255) end
  elseif entry.quality == 'epic' then
    if is_valid_ui(title_ui) and title_ui.set_text_color then title_ui:set_text_color(208, 62, 255, 255) end
  else
    if is_valid_ui(title_ui) and title_ui.set_text_color then title_ui:set_text_color(45, 176, 255, 255) end
  end

  -- 选择按钮
  local pick_btn = get_child_ui(panel_key, card_path .. string.format('.pick_btn_%d', card_index))
  set_ui_intercept(pick_btn, true)
  set_ui_button_enable(pick_btn, entry.enabled ~= false)
end

-- ============================================================
-- 羁绊悬浮提示
-- ============================================================

local function build_bond_hover_tip(entry)
  local tip_model = entry and (entry.tip_model or bond_tip_builder.build_from_choice(entry.source_choice or entry)) or nil
  if not tip_model then return nil end

  local body_lines = {}
  local root_name = tostring(tip_model.set_name_text or entry.bond_root_name or '')
  local progress_str = tostring(tip_model.progress_text or entry.bond_root_progress_text or '')
  local max_count = tonumber(string.match(progress_str, '/%s*(%d+)')) or tonumber(string.match(progress_str, '/([0-9]+)')) or 0

  if tip_model.bonus_lines and #tip_model.bonus_lines > 0 then
    body_lines[#body_lines + 1] = SKILL_BLOCK_TITLE
    for _, line in ipairs(tip_model.bonus_lines) do
      body_lines[#body_lines + 1] = tostring(line)
    end
  end

  if #body_lines > 0 then body_lines[#body_lines + 1] = '' end

  body_lines[#body_lines + 1] = '[进阶说明]'
  if root_name ~= '' and max_count > 0 then
    body_lines[#body_lines + 1] = string.format('收集%d张 %s 后可自动进阶', max_count, root_name)
  elseif root_name ~= '' then
    body_lines[#body_lines + 1] = string.format('收集同羁绊的 %s 后可自动进阶', root_name)
  else
    body_lines[#body_lines + 1] = '收集同羁绊的卡片后可自动进阶'
  end

  local skill_lines = {}
  if tip_model.set_body_lines and #tip_model.set_body_lines > 0 then
    for _, line in ipairs(tip_model.set_body_lines) do
      skill_lines[#skill_lines + 1] = tostring(line)
    end
  elseif tip_model.effect_body_text and tip_model.effect_body_text ~= '' then
    for line in tostring(tip_model.effect_body_text):gmatch('[^\n]+') do
      skill_lines[#skill_lines + 1] = line
    end
  elseif entry and entry.advanced_text and entry.advanced_text ~= '' then
    for line in tostring(entry.advanced_text):gmatch('[^\n]+') do
      skill_lines[#skill_lines + 1] = line
    end
  end

  if #skill_lines > 0 then
    body_lines[#body_lines + 1] = ''
    if root_name ~= '' then
      body_lines[#body_lines + 1] = string.format(SKILL_SECTION_TEMPLATE, root_name)
    else
      body_lines[#body_lines + 1] = SKILL_SECTION_FALLBACK
    end
    for _, line in ipairs(skill_lines) do
      body_lines[#body_lines + 1] = tostring(line)
    end
  end

  local header_parts = {}
  if root_name ~= '' then
    header_parts[#header_parts + 1] = '羁绊：' .. root_name .. progress_str
  end

  return {
    kind = 'bond',
    title = tostring(tip_model.item_name_text or entry.title_text or '羁绊卡片'),
    subtitle = table.concat(header_parts, '  '),
    body = table.concat(body_lines, '\n'),
    icon = tip_model.icon_res or entry.icon,
  }
end

local function show_bond_card_hover(card_index)
  local state = get_current_choice_state()
  if not state or state.kind ~= 'bond' then return end
  local entry = state.choices and state.choices[card_index] or nil
  local hud_system = get_hud_system_fn and get_hud_system_fn() or nil
  if hud_system and hud_system.show_hover_tip_panel then
    hud_system.show_hover_tip_panel(build_bond_hover_tip(entry))
  end
end

local function hide_hover_tip()
  local hud = get_hud_system_fn and get_hud_system_fn() or nil
  if hud and hud.hide_hover_tip_panel then
    hud.hide_hover_tip_panel()
  end
end

-- ============================================================
-- 事件注册（按钮点击等）
-- ============================================================

local function register_card_events(panel_key, choice_count)
  event_registry[panel_key] = event_registry[panel_key] or {}
  local registered = event_registry[panel_key]
  local section_path = get_section_path(panel_key)

  -- 卡片选择按钮
  for idx = 1, choice_count do
    local btn_key = 'pick_btn_' .. tostring(idx)
    if registered[btn_key] ~= true then
      local card_path = string.format('%s.cards_row.card_%d.pick_btn_%d', section_path, idx, idx)
      local btn_ui = get_child_ui(panel_key, card_path)
      if is_valid_ui(btn_ui) and btn_ui.add_fast_event then
        set_ui_intercept(btn_ui, true)
        btn_ui:add_fast_event('点击-单击', function()
          if apply_round_choice_fn then apply_round_choice_fn(idx) end
        end)
        btn_ui:add_fast_event('点击-悬停', function()
          show_bond_card_hover(idx)
        end)
        btn_ui:add_fast_event('点击-移出', function()
          hide_hover_tip()
        end)
        registered[btn_key] = true
      end
    end
  end

  -- 刷新按钮
  if registered.refresh_btn ~= true then
    local refresh_btn = get_child_ui(panel_key, section_path .. '.refresh_btn')
    if is_valid_ui(refresh_btn) and refresh_btn.add_fast_event then
      set_ui_intercept(refresh_btn, true)
      refresh_btn:add_fast_event('点击-单击', function()
        if refresh_current_choice_fn then refresh_current_choice_fn() end
      end)
      registered.refresh_btn = true
    end
  end

  -- 稍后选择按钮
  if registered.later_btn ~= true then
    local later_btn = get_child_ui(panel_key, section_path .. '.later_btn')
    if is_valid_ui(later_btn) and later_btn.add_fast_event then
      set_ui_intercept(later_btn, true)
      later_btn:add_fast_event('点击-单击', function()
        if defer_choice_panel_fn then defer_choice_panel_fn() end
      end)
      registered.later_btn = true
    end
  end
end

-- ============================================================
-- Z-order 设置
-- ============================================================

local function set_choice_z_order(panel_key)
  set_ui_z_order(get_bond_choice_panel(panel_key), Z_CHOICE)
end

-- ============================================================
-- HUD 可见性控制
-- ============================================================

local function set_battle_hud_visible_internal(visible)
  local player = get_player_fn and get_player_fn() or nil
  if not player then return end

  local battle_bottom_hud = ui_root.resolve_ui(y3, player, 'BattleBottomHUD')
  local game_hud = ui_root.resolve_ui(y3, player, 'GameHUD')
  local main_panel = ui_root.resolve_ui(y3, player, 'GameHUD.main')
  local setting_btn = ui_root.resolve_ui(y3, player, 'GameHUD.setting_btn')
  local exit_btn = ui_root.resolve_ui(y3, player, 'GameHUD.exit_btn')
  local setting_panel = ui_root.resolve_ui(y3, player, 'GameHUD.setting_panel')

  set_ui_z_order(game_hud, Z_HUD)
  set_ui_z_order(setting_panel, Z_PANEL)
  set_ui_z_order(setting_btn, Z_BUTTON)
  set_ui_z_order(exit_btn, Z_BUTTON)

  set_ui_visible(battle_bottom_hud, visible)

  if visible == true then
    set_ui_visible(game_hud, true)
    set_ui_visible(main_panel, true)
    set_ui_visible(setting_btn, true)
    set_ui_visible(exit_btn, true)

    set_ui_visible(ui_root.resolve_ui(y3, player, 'bottom_bg.bottom_bg'), false)
    set_ui_visible(ui_root.resolve_ui(y3, player, 'bottom_bg'), false)

    if battle_bottom_hud then
      local sub_paths = {
        'GameHUD.main.main_unit',
        'GameHUD.main.main_unit_name',
        'GameHUD.main.attr_list',
        'GameHUD.main.skill_list',
        'GameHUD.main.main_hp_bar',
        'GameHUD.main.main_mp_bar',
        'GameHUD.main.inventory',
        'GameHUD.main.bag_btn',
        'GameHUD.player_attr_list',
        'GameHUD.main.player_attr_list',
      }
      for _, path in ipairs(sub_paths) do
        set_ui_visible(ui_root.resolve_ui(y3, player, path), false)
      end
    end
    return
  end

  set_ui_visible(setting_panel, false)
  local hidden_paths = { 'GameHUD.main', 'bottom_bg.bottom_bg', 'bottom_bg' }
  for _, path in ipairs(hidden_paths) do
    set_ui_visible(ui_root.resolve_ui(y3, player, path), false)
  end
end

-- ============================================================
-- HUD 刷新接口
-- ============================================================

local function ensure_runtime_hud()
  local hud = get_hud_system_fn and get_hud_system_fn() or nil
  return hud and hud.ensure_hud and hud.ensure_hud() or nil
end

local function refresh_runtime_hud()
  local hud = get_hud_system_fn and get_hud_system_fn() or nil
  return hud and hud.refresh_hud and hud.refresh_hud() or nil
end

-- ============================================================
-- 选择面板管理
-- ============================================================

local function ensure_choice_panel()
  local state = get_current_choice_state()
  if not state then
    hide_all_bond_choice_panels()
    return nil
  end

  local panel_key = state.panel_name or get_panel_name(#state.choices)
  local panel = get_bond_choice_panel(panel_key)
  if not panel then return nil end

  register_card_events('BondChoice2', 2)
  register_card_events('BondChoice3', 3)
  register_card_events('BondChoice4', 4)

  set_choice_z_order('BondChoice2')
  set_choice_z_order('BondChoice3')
  set_choice_z_order('BondChoice4')

  set_ui_visible(get_bond_choice_panel('BondChoice2'), panel_key == 'BondChoice2')
  set_ui_visible(get_bond_choice_panel('BondChoice3'), panel_key == 'BondChoice3')
  set_ui_visible(get_bond_choice_panel('BondChoice4'), panel_key == 'BondChoice4')

  return panel, state
end

local function refresh_choice_panel()
  local panel, state = ensure_choice_panel()
  if not panel or not state then return nil end

  local panel_key = state.panel_name or get_panel_name(#state.choices)

  -- 填充卡片数据
  for idx = 1, 4 do
    fill_bond_card(panel_key, idx, state.choices[idx])
  end

  -- 刷新按钮状态
  local section = get_section_path(panel_key)
  local refresh_btn = get_child_ui(panel_key, section .. '.refresh_btn')
  local round = state.current_round or {}
  local refresh_left = tonumber(round.free_refresh_left or 0) or 0

  if state.can_refresh ~= true then
    set_ui_button_text(refresh_btn, state.disabled_refresh_text or '当前无法刷新')
  elseif refresh_left > 0 then
    set_ui_button_text(refresh_btn, string.format('可刷新候选，剩余%d次', refresh_left))
  else
    local paid_count = tonumber(round.refresh_paid_count or 0) or 0
    set_ui_button_text(refresh_btn, string.format('刷新候选%d木材', get_refresh_cost(paid_count)))
  end

  set_ui_button_enable(refresh_btn, state.can_refresh == true)
  set_ui_font_size(refresh_btn, 15)

  return panel
end

local function destroy_choice_panel()
  hide_all_bond_choice_panels()
  return nil
end

local function build_overview_text()
  return ''
end

-- ============================================================
-- 提示面板
-- ============================================================

local function show_runtime_attr_tip_panel(duration)
  local hud = get_hud_system_fn and get_hud_system_fn() or nil
  if hud and hud.ensure_hud then hud.ensure_hud() end
  if hud and hud.show_tip_panel then
    hud.show_tip_panel(build_overview_text(), duration or 8)
  end
end

-- ============================================================
-- 全局 UI 可见性切换
-- ============================================================

local function set_all_ui_visible(visible)
  set_battle_hud_visible_internal(visible)
  local hud = get_hud_system_fn and get_hud_system_fn() or nil
  if hud and hud.set_visible then hud.set_visible(visible) end
  if STATE.message_prompt_system and STATE.message_prompt_system.set_visible then
    STATE.message_prompt_system.set_visible(visible)
  end
  if STATE.talk_panel_system and STATE.talk_panel_system.set_visible then
    STATE.talk_panel_system.set_visible(visible)
  end
  if STATE.inventory_panel_system and STATE.inventory_panel_system.set_visible then
    STATE.inventory_panel_system.set_visible(visible)
  end
end

-- ============================================================
-- 存根（未实现功能）
-- ============================================================

local function toggle_talk_input() return nil end
local function toggle_inventory_panel() return nil end
local function refresh_inventory_panel() return nil end

-- ============================================================
-- 羁绊吞噬面板
-- ============================================================

local function get_bond_swallow_ui()
  if is_valid_ui(bond_swallow_panel) then return bond_swallow_panel end
  local player = get_player_fn and get_player_fn() or nil
  if not player then return nil end
  bond_swallow_panel = ui_root.resolve_ui(y3, player, 'BondSwallowPanel')
  return bond_swallow_panel
end

local function get_swallow_child(path)
  local player = get_player_fn and get_player_fn() or nil
  if not player or not path then return nil end
  return ui_root.resolve_ui(y3, player, 'BondSwallowPanel.' .. path)
end

local function init_swallow_close_button()
  if bond_swallow_close_initialized then return end
  local close_btn = get_swallow_child('layout.main_frame.close_button')
  if not is_valid_ui(close_btn) or not close_btn.add_fast_event then return end

  bond_swallow_close_initialized = true
  set_ui_intercept(get_swallow_child('layout.dim_bg'), true)
  set_ui_intercept(get_swallow_child('layout.main_frame'), true)

  close_btn:add_fast_event('点击-单击', function()
    STATE.bond_swallow_panel_visible = false
    set_ui_visible(get_swallow_child('layout'), false)
    set_ui_visible(get_bond_swallow_ui(), false)
    hide_hover_tip()
  end)
end

-- ============================================================
-- 吞噬面板动态 UI 工厂
-- ============================================================

local function create_child_ui(parent, ui_type, width, height, x, y)
  local child = parent and parent.create_child and parent:create_child(ui_type) or nil
  if is_valid_ui(child) then
    if child.set_ui_size then child:set_ui_size(width or 0, height or 0) end
    if child.set_pos then child:set_pos(x or 0, y or 0) end
  end
  return child
end

local function create_text_ui(parent, text, x, y, width, height, font_size, color)
  local label = create_child_ui(parent, '文本', width, height, x, y)
  set_ui_text(label, text)
  set_ui_font_size(label, font_size)
  if is_valid_ui(label) and label.set_text_color and color then
    label:set_text_color(color[1] or 255, color[2] or 255, color[3] or 255, color[4] or 255)
  end
  if is_valid_ui(label) and label.set_text_alignment then
    label:set_text_alignment(0, 8)
  end
  return label
end

local function create_image_ui(parent, image_id, x, y, width, height, color)
  local img = create_child_ui(parent, '图片', width, height, x, y)
  set_ui_image(img, image_id)
  if color then set_ui_image_color(img, color) end
  return img
end

-- ============================================================
-- 吞噬面板动态 UI 管理
-- ============================================================

local function clear_swallow_dynamic_uis()
  local dynamic_list = event_registry.bond_swallow_dynamic or {}
  for _, ui in ipairs(dynamic_list) do
    if is_valid_ui(ui) and ui.remove then ui:remove() end
  end
  event_registry.bond_swallow_dynamic = {}
end

local function track_swallow_dynamic_ui(ui)
  event_registry.bond_swallow_dynamic = event_registry.bond_swallow_dynamic or {}
  if is_valid_ui(ui) then event_registry.bond_swallow_dynamic[#event_registry.bond_swallow_dynamic + 1] = ui end
  return ui
end

local function setup_swallow_grid_view(grid, cols, card_size_mode)
  if not is_valid_ui(grid) then return end
  if grid.set_ui_gridview_count then grid:set_ui_gridview_count(math.max(1, cols), card_size_mode) end
  if grid.set_ui_gridview_size then
    grid:set_ui_gridview_size(card_size_mode == 2 and 184 or 84, card_size_mode == 2 and 42 or 82)
  end
  if grid.set_ui_gridview_space then grid:set_ui_gridview_space(8, 8) end
  if grid.set_ui_gridview_scroll then grid:set_ui_gridview_scroll(true) end
end

local function create_swallow_root_node(grid, entry, index, is_selected)
  local node = track_swallow_dynamic_ui(create_child_ui(grid, '按钮节点', 184, 42, 0, 0))
  if not is_valid_ui(node) then return end
  set_ui_intercept(node, true)

  create_image_ui(node, DEFAULT_ICON, 92, 21, 184, 42, is_selected and { 255, 212, 76, 110 } or { 72, 126, 190, 88 })
  create_text_ui(node, entry.pretty_display_name or entry.display_name or entry.title or '未命名', 10, 22, 118, 18, 14,
    is_selected and { 255, 235, 135, 255 } or { 224, 238, 255, 255 })
  create_text_ui(node, entry.progress_text or '0/0', 130, 22, 46, 18, 13,
    entry.consumed and { 255, 214, 90, 255 } or { 168, 198, 230, 255 })

  if node.add_fast_event then
    node:add_fast_event('点击-单击', function()
      STATE.bond_swallow_selected_root_index = index
      STATE.bond_swallow_panel_visible = true
      if refresh_bond_swallow_fn then refresh_bond_swallow_fn() end
    end)
  end

  if grid and grid.insert_ui_gridview_comp then
    grid:insert_ui_gridview_comp(node, index)
  end
end

local function create_swallow_card_node(grid, entry, index)
  local node = track_swallow_dynamic_ui(create_child_ui(grid, '按钮节点', 76, 76, 0, 0))
  if not is_valid_ui(node) then return end
  set_ui_intercept(node, true)

  create_image_ui(node, DEFAULT_ICON, 38, 38, 76, 76, { 255, 255, 255, 95 })

  local icon_ui = create_image_ui(node, entry and entry.icon or nil, 38, 44, 48, 48,
    entry and entry.unlocked and { 255, 255, 255, 255 } or { 98, 108, 122, 150 })
  set_ui_visible(icon_ui, entry ~= nil and entry.icon ~= nil)
  set_ui_intercept(icon_ui, false)

  local frame_img = resolve_quality_frame_image(entry and entry.quality or nil)
  local frame_ui = create_image_ui(node, frame_img, 38, 44, 56, 56, nil)
  set_ui_visible(frame_ui, frame_img ~= nil)
  set_ui_intercept(frame_ui, false)

  create_image_ui(node, DEFAULT_ICON, 38, 38, 76, 76,
    entry and entry.consumed and { 255, 204, 78, 110 }
    or entry and entry.unlocked and { 70, 165, 255, 85 }
    or { 255, 204, 78, 0 })

  create_text_ui(node,
    entry and (entry.pretty_display_name or entry.display_name or entry.title) or '',
    4, 10, 68, 16, 11,
    entry and entry.unlocked and { 230, 238, 248, 255 } or { 128, 142, 160, 255 })

  if node.add_fast_event then
    node:add_fast_event('点击-悬停', function()
      local hud = get_hud_system_fn and get_hud_system_fn() or nil
      if hud and hud.show_hover_tip_panel then
        hud.show_hover_tip_panel(build_bond_hover_tip(entry))
      end
    end)
    node:add_fast_event('点击-移出', function()
      hide_hover_tip()
    end)
  end

  if grid and grid.insert_ui_gridview_comp then
    grid:insert_ui_gridview_comp(node, index)
  end
end

-- ============================================================
-- 吞噬面板刷新
-- ============================================================

refresh_bond_swallow_fn = function()
  local panel = get_bond_swallow_ui()
  if not is_valid_ui(panel) then return nil end

  init_swallow_close_button()

  if STATE.bond_swallow_panel_visible ~= true then
    clear_swallow_dynamic_uis()
    set_ui_visible(get_swallow_child('layout'), false)
    set_ui_visible(panel, false)
    return panel
  end

  local model = build_bond_swallow_panel_model_fn
    and build_bond_swallow_panel_model_fn(STATE, STATE.bond_swallow_selected_root_index or 1)
    or nil

  if not model then
    clear_swallow_dynamic_uis()
    set_ui_visible(get_swallow_child('layout'), false)
    set_ui_visible(panel, false)
    return panel
  end

  STATE.bond_swallow_selected_root_index = model.selected_root_index or 1

  set_ui_visible(panel, true)
  set_ui_visible(get_swallow_child('layout'), true)
  set_ui_visible(get_swallow_child('layout.dim_bg'), true)
  set_ui_visible(get_swallow_child('layout.main_frame'), true)
  set_ui_z_order(panel, 9560)
  set_ui_text(get_swallow_child('layout.main_frame.total_value'), tostring(model.total_consumed or 0))

  clear_swallow_dynamic_uis()

  local group_grid = get_swallow_child('layout.main_frame.group_panel.group_grid')
  local card_grid = get_swallow_child('layout.main_frame.card_grid.card_list')
  local root_entries = model.root_entries or {}
  local card_entries = model.card_entries or {}

  setup_swallow_grid_view(group_grid, math.max(1, math.ceil(#root_entries / 2)), 2)
  setup_swallow_grid_view(card_grid, math.max(1, math.ceil(#card_entries / 5)), 5)

  for idx, entry in ipairs(root_entries) do
    create_swallow_root_node(group_grid, entry, idx, idx == (model.selected_root_index or 1))
  end

  for idx, entry in ipairs(card_entries) do
    create_swallow_card_node(card_grid, entry, idx)
  end

  local detail = model.detail or {}
  set_ui_text(get_swallow_child('layout.main_frame.detail_panel.detail_title'), detail.title or '未选择羁绊')
  set_ui_text(get_swallow_child('layout.main_frame.detail_panel.detail_status'),
    string.format('%s  %s', tostring(detail.status or '未激活'), tostring(detail.progress or '0/0')))
  set_ui_text(get_swallow_child('layout.main_frame.detail_panel.detail_body'), detail.body or '')

  return panel
end

local function show_bond_swallow_panel()
  STATE.bond_swallow_panel_visible = true
  STATE.bond_swallow_selected_root_index = STATE.bond_swallow_selected_root_index or 1
  return refresh_bond_swallow_fn()
end

-- ============================================================
-- 导出
-- ============================================================

helpers = {
  destroy_choice_panel       = destroy_choice_panel,
  ensure_choice_panel        = ensure_choice_panel,
  ensure_runtime_hud         = ensure_runtime_hud,
  install_panel_systems      = install_panel_systems,
  refresh_choice_panel       = refresh_choice_panel,
  refresh_inventory_panel    = refresh_inventory_panel,
  refresh_bond_swallow_panel = refresh_bond_swallow_fn,
  refresh_runtime_hud        = refresh_runtime_hud,
  refresh_runtime_overview   = function() end,
  set_battle_hud_visible     = set_all_ui_visible,
  show_bond_swallow_panel    = show_bond_swallow_panel,
  show_runtime_attr_tip_panel = show_runtime_attr_tip_panel,
  toggle_inventory_panel     = toggle_inventory_panel,
  toggle_talk_input          = toggle_talk_input,
}

_G.runtime_ui_helpers = helpers
return helpers
