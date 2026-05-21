-- runtime_ui_helpers.lua — UI 辅助工具集（选择面板、HUD 切换等）
-- 自初始化模块，require 时自动设置 _G.runtime_ui_helpers

local y3 = y3
require 'runtime.core.boot_utils'; local BootHelpers = _G.BootHelpers
local ui_root = require 'ui.ui_root'
local QualityImageTable = require 'data.tables.economy.quality_image_table'

-- UI 标签常量（暂为空，后续从配置表读取）
local SKILL_BLOCK_TITLE = ''
local SKILL_SECTION_TEMPLATE = ''
local SKILL_SECTION_FALLBACK = ''

local helpers
local STATE = _G.STATE

-- 外层依赖（通过 _G 读取，require 时需确保已设置）
local get_player_fn = y3.player.get_main_player
local get_hud_system_fn = _G.get_hud_system
local get_pending_round_choice_kind_fn = _G.get_pending_round_choice_kind
local refresh_current_choice_fn = _G.refresh_current_choice
local apply_round_choice_fn = _G.apply_round_choice
local defer_choice_panel_fn = _G.defer_choice_panel

local get_evolution_quality_label_fn = _G.get_evolution_quality_label

-- ============================================================
-- UI 安全操作工具函数
-- ============================================================

local Utils = require 'runtime.utils'
local is_valid_ui = Utils.is_ui_alive

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
-- 选择面板管理（存根）
-- ============================================================

local function ensure_choice_panel()
  return nil
end

local function refresh_choice_panel()
  return nil
end

local function destroy_choice_panel()
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
-- 导出
-- ============================================================

helpers = {
  destroy_choice_panel       = destroy_choice_panel,
  ensure_choice_panel        = ensure_choice_panel,
  ensure_runtime_hud         = ensure_runtime_hud,
  install_panel_systems      = install_panel_systems,
  refresh_choice_panel       = refresh_choice_panel,
  refresh_inventory_panel    = refresh_inventory_panel,
  refresh_runtime_hud        = refresh_runtime_hud,
  refresh_runtime_overview   = function() end,
  set_battle_hud_visible     = set_all_ui_visible,
  show_runtime_attr_tip_panel = show_runtime_attr_tip_panel,
  toggle_inventory_panel     = toggle_inventory_panel,
  toggle_talk_input          = toggle_talk_input,
}

_G.runtime_ui_helpers = helpers
return helpers
