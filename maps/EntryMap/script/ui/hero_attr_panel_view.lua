local UIRoot = require 'ui.ui_root'
local HeroAttrDefs = require 'runtime.hero_attr_defs'

local M = {}

local LEFT_ROWS = {
  { label = '攻击速度', attr = '攻击速度', format = 'attack_speed_percent' },
  { label = '每秒回血', attr = '生命恢复' },
  { label = '每秒经验', attr = '每秒经验' },
  { label = '恢复加成', attr = '百分比恢复' },
  { label = '装备加成', attr = '卡牌增幅' },
  { label = '攻击范围', attr = '攻击范围' },
  { label = '冷却缩减', attr = '技能急速', format = 'integer' },
  { label = '暴击率', attr = '物理暴击' },
  { label = '暴击伤害', attr = '物理暴伤' },
  { label = '闪避', attr = '闪避' },
}

local RIGHT_ROWS = {
  { label = '护甲穿透', attr = '护甲穿透', format = 'integer' },
  { label = '物理增伤', attr = '物理伤害' },
  { label = '法术增伤', attr = '魔法伤害' },
  { label = '最终伤害', attr = '最终伤害' },
  { label = '最终减免', attr = '伤害减免' },
  { label = '精英伤害', attr = '精控伤害' },
  { label = 'BOSS伤害', attr = '挑战伤害' },
  { label = '金行伤害', attr = '金行伤害' },
  { label = '火行伤害', attr = '火行伤害' },
  { label = '土行伤害', attr = '土行伤害' },
}

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function set_visible(ui, visible)
  if is_alive(ui) then
    ui:set_visible(visible == true)
  end
end

local function set_text(ui, text)
  if is_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

local function round_number(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function format_number(value, digits)
  local number = tonumber(value) or 0
  digits = digits or 0
  if digits <= 0 then
    return tostring(round_number(number))
  end
  local text = string.format('%.' .. tostring(digits) .. 'f', number)
  text = text:gsub('(%..-)0+$', '%1'):gsub('%.$', '')
  return text
end

local function format_attr_value(attr_name, value, format_override)
  local def = HeroAttrDefs.by_name[attr_name]
  local format_kind = format_override or (def and def.format) or 'fixed1'
  local numeric = tonumber(value) or 0

  if format_kind == 'attack_speed_percent' then
    return format_number(numeric, 1) .. '%'
  end
  if format_kind == 'integer' then
    return format_number(numeric, 0)
  end
  if format_kind == 'fixed2' then
    return format_number(numeric, 2)
  end
  if format_kind == 'fixed1' then
    return format_number(numeric, 1)
  end
  if format_kind == 'percent' or format_kind == 'percent_or_zero' then
    if math.abs(numeric) <= 1 then
      numeric = numeric * 100
    end
    return format_number(numeric, 1) .. '%'
  end
  return format_number(numeric, 1)
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local hero_attr_system = env.hero_attr_system

  local runtime = {
    visible = true,
    panel_visible = false,
  }

  local function get_hero()
    local hero = STATE and STATE.hero or nil
    if hero and hero.is_exist and hero:is_exist() then
      return hero
    end
    return nil
  end

  local function get_attr_value(hero, attr_name)
    if not hero or not attr_name then
      return 0
    end
    if hero_attr_system and hero_attr_system.get_attr then
      return hero_attr_system.get_attr(hero, attr_name)
    end
    return hero.get_attr and hero:get_attr(attr_name) or 0
  end

  local function build_column_texts(hero, rows)
    local label_lines = {}
    local value_lines = {}
    for _, row in ipairs(rows) do
      label_lines[#label_lines + 1] = tostring(row.label)
      value_lines[#value_lines + 1] = format_attr_value(row.attr, get_attr_value(hero, row.attr), row.format)
    end
    return table.concat(label_lines, '\n'), table.concat(value_lines, '\n')
  end

  local function ensure_panel()
    if runtime.root and is_alive(runtime.root) then
      return runtime
    end

    local player = get_player()
    local parent = UIRoot.get_fullscreen_overlay_parent(y3, player)
      or UIRoot.resolve_ui(y3, player, 'top')
      or UIRoot.resolve_ui(y3, player, 'top.top')
      or UIRoot.resolve_ui(y3, player, 'GameHUD.main')
      or UIRoot.resolve_ui(y3, player, 'GameHUD')
    if not parent then
      return nil
    end

    local ok, prefab = pcall(y3.ui_prefab.create, player, '属性面板', parent)
    if ok and prefab then
      runtime.prefab = prefab
      runtime.root = prefab:get_child()
      runtime.title = prefab:get_child('标题')
      runtime.hint = prefab:get_child('提示')
      runtime.left_labels = prefab:get_child('左列标题')
      runtime.left_values = prefab:get_child('左列值')
      runtime.right_labels = prefab:get_child('右列标题')
      runtime.right_values = prefab:get_child('右列值')
    else
      local root = parent:create_child('图片')
      root:set_image(999)
      root:set_ui_size(760, 520)
      root:set_pos(960, 540)
      root:set_image_color(0, 0, 0, 180)
      root:set_intercepts_operations(false)
      root:set_z_order(9500)

      local title = root:create_child('文本')
      title:set_ui_size(220, 44)
      title:set_pos(120, 38)
      title:set_font_size(30)
      title:set_text_color(255, 255, 255, 255)
      title:set_text_alignment('左', '中')

      local hint = root:create_child('文本')
      hint:set_ui_size(160, 30)
      hint:set_pos(650, 38)
      hint:set_font_size(18)
      hint:set_text_color(180, 196, 220, 255)
      hint:set_text_alignment('右', '中')

      local left_labels = root:create_child('文本')
      left_labels:set_ui_size(220, 340)
      left_labels:set_pos(130, 274)
      left_labels:set_font_size(18)
      left_labels:set_text_color(255, 255, 255, 255)
      left_labels:set_text_alignment('左', '上')

      local left_values = root:create_child('文本')
      left_values:set_ui_size(120, 340)
      left_values:set_pos(350, 274)
      left_values:set_font_size(18)
      left_values:set_text_color(0, 255, 0, 255)
      left_values:set_text_alignment('左', '上')

      local right_labels = root:create_child('文本')
      right_labels:set_ui_size(220, 340)
      right_labels:set_pos(510, 274)
      right_labels:set_font_size(18)
      right_labels:set_text_color(255, 255, 255, 255)
      right_labels:set_text_alignment('左', '上')

      local right_values = root:create_child('文本')
      right_values:set_ui_size(120, 340)
      right_values:set_pos(670, 274)
      right_values:set_font_size(18)
      right_values:set_text_color(0, 255, 0, 255)
      right_values:set_text_alignment('左', '上')

      runtime.prefab = nil
      runtime.root = root
      runtime.title = title
      runtime.hint = hint
      runtime.left_labels = left_labels
      runtime.left_values = left_values
      runtime.right_labels = right_labels
      runtime.right_values = right_values
    end

    if is_alive(runtime.root) then
      runtime.root:set_anchor(0.5, 0.5)
      runtime.root:set_visible(false)
      if runtime.root.set_intercepts_operations then
        runtime.root:set_intercepts_operations(false)
      end
      if runtime.root.set_z_order then
        runtime.root:set_z_order(9500)
      end
    end

    set_text(runtime.title, '属性面板')
    set_text(runtime.hint, 'TAB 关闭')
    return runtime
  end

  local function refresh_panel()
    local panel = ensure_panel()
    if not panel or not panel.panel_visible then
      return nil
    end

    local hero = get_hero()
    local left_labels, left_values = build_column_texts(hero, LEFT_ROWS)
    local right_labels, right_values = build_column_texts(hero, RIGHT_ROWS)
    set_text(panel.left_labels, left_labels)
    set_text(panel.left_values, left_values)
    set_text(panel.right_labels, right_labels)
    set_text(panel.right_values, right_values)
    return panel
  end

  local function set_ui_visible(visible)
    runtime.visible = visible == true
    if not runtime.visible then
      set_visible(runtime.root, false)
      return
    end
    set_visible(runtime.root, runtime.panel_visible)
    if runtime.panel_visible then
      refresh_panel()
    end
  end

  local function show_panel()
    runtime.panel_visible = true
    refresh_panel()
    set_visible(runtime.root, runtime.visible)
  end

  local function hide_panel()
    runtime.panel_visible = false
    set_visible(runtime.root, false)
  end

  local function toggle_panel()
    ensure_panel()
    if runtime.panel_visible then
      hide_panel()
      return false
    end
    show_panel()
    return true
  end

  return {
    ensure_panel = ensure_panel,
    refresh_panel = refresh_panel,
    set_visible = set_ui_visible,
    show_panel = show_panel,
    hide_panel = hide_panel,
    toggle_panel = toggle_panel,
  }
end

return M
