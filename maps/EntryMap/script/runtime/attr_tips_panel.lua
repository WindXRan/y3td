local UiRoot = require 'ui.ui_root'
local HeroAttrSystem = require 'runtime.hero_attr_system'
local AttrDefs = HeroAttrSystem.get_defs and HeroAttrSystem.get_defs() or { aliases = {}, by_name = {} }

local M = {}

local ATTR_LABEL_PATHS = {
  'labelPrefab',
  'grid_view.labelPrefab_1',
  'grid_view.labelPrefab_2',
  'grid_view.labelPrefab_3',
  'grid_view.labelPrefab_1_4_1',
  'grid_view.labelPrefab_1_1',
  'grid_view.labelPrefab_1_2',
  'grid_view.labelPrefab_1_3',
  'grid_view.labelPrefab_2_3',
  'grid_view.labelPrefab_3_3',
  'grid_view.labelPrefab_2_2',
  'grid_view.labelPrefab_3_2',
  'grid_view.labelPrefab_2_1',
  'grid_view.labelPrefab_3_1',
  'grid_view.labelPrefab_2_4_1',
  'grid_view.labelPrefab_3_4_1',
}

local RULE_LABEL_PATHS = {
  'scroll_view_2.label',
  'scroll_view_2.label_4',
  'scroll_view_2.label_5',
  'scroll_view_2.label_6',
  'scroll_view_2.label_7',
  'scroll_view_2.label_8',
}

local ATTR_GRID_COLUMN_COUNT = 2
local ATTR_GRID_CELL_WIDTH = 150
local ATTR_GRID_CELL_HEIGHT = 33

local function is_alive(ui)
  return UiRoot.is_alive(ui)
end

local function call_ui(ui, method, ...)
  if is_alive(ui) and type(ui[method]) == 'function' then
    return pcall(ui[method], ui, ...)
  end
  return false
end

local function set_visible(ui, visible)
  if is_alive(ui) and ui.set_visible then
    ui:set_visible(visible == true)
  end
end

local function set_text(ui, text)
  if is_alive(ui) and ui.set_text then
    ui:set_text(tostring(text or ''))
  end
end

local function set_attr_label_style(ui)
  call_ui(ui, 'set_ui_size', 148, 28)
  call_ui(ui, 'set_font_size', 16)
  call_ui(ui, 'set_text_alignment', '左', '中')
  call_ui(ui, 'set_visible', true)
end

local function format_number(value, digits)
  local number = tonumber(value) or 0
  digits = digits or 0
  if digits <= 0 then
    return tostring(math.floor(number + (number >= 0 and 0.5 or -0.5)))
  end
  local text = string.format('%.' .. tostring(digits) .. 'f', number)
  text = text:gsub('(%..-)0+$', '%1'):gsub('%.$', '')
  return text
end

local function format_percent(value, digits)
  local number = tonumber(value) or 0
  if math.abs(number) <= 1 then
    number = number * 100
  end
  return format_number(number, digits or 1) .. '%'
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local hero_attr_system = env.hero_attr_system
  local nodes = {}

  local function get_root()
    local player = get_player and get_player() or nil
    if not player then
      return nil
    end
    if not is_alive(nodes.root) then
      nodes.root = UiRoot.resolve_ui(y3, player, 'TipsPanel')
    end
    return nodes.root
  end

  local function get_panel()
    local player = get_player and get_player() or nil
    if not player then
      return nil
    end
    if not is_alive(nodes.panel) then
      nodes.panel = UiRoot.resolve_first_ui(y3, player, {
        'TipsPanel.AttrPanel',
        'TipsPanel.AttrTips',
      })
    end
    return nodes.panel
  end

  local function get_child(path)
    local panel = get_panel()
    if not panel then
      return nil
    end
    local key = 'child:' .. path
    if not is_alive(nodes[key]) then
      nodes[key] = UiRoot.resolve_child(panel, path)
    end
    return nodes[key]
  end

  local function get_attr_grid()
    if not is_alive(nodes.attr_grid) then
      nodes.attr_grid = get_child('grid_view')
    end
    return nodes.attr_grid
  end

  local function get_attr_label(index)
    local static_path = ATTR_LABEL_PATHS[index]
    if static_path then
      local ui = get_child(static_path)
      set_attr_label_style(ui)
      return ui
    end

    local key = 'dynamic_attr_label:' .. tostring(index)
    if is_alive(nodes[key]) then
      return nodes[key]
    end

    local grid = get_attr_grid()
    if not is_alive(grid) or type(grid.create_child) ~= 'function' then
      return nil
    end

    local ok, ui = pcall(grid.create_child, grid, '文本')
    if not ok or not is_alive(ui) then
      return nil
    end
    nodes[key] = ui
    set_attr_label_style(ui)
    call_ui(grid, 'insert_ui_gridview_comp', ui, index)
    return ui
  end

  local function read_attr(name, fallback_name)
    local hero = STATE and STATE.hero or nil
    if not hero or not hero.is_exist or not hero:is_exist() then
      return 0
    end
    local normalized_name = AttrDefs.aliases[name] or name
    local value = nil
    if AttrDefs.by_name[normalized_name] and hero_attr_system and hero_attr_system.get_attr then
      value = hero_attr_system.get_attr(hero, normalized_name)
    end
    if (value == nil or tonumber(value) == 0) and fallback_name then
      local normalized_fallback = AttrDefs.aliases[fallback_name] or fallback_name
      if AttrDefs.by_name[normalized_fallback] and hero_attr_system and hero_attr_system.get_attr then
        value = hero_attr_system.get_attr(hero, normalized_fallback)
      end
    end
    if value == nil and hero.get_attr then
      local ok, attr_value = pcall(hero.get_attr, hero, normalized_name)
      if ok then
        value = attr_value
      end
    end
    return tonumber(value) or 0
  end

  local function attr_line(label, value, formatter)
    return string.format('%s：%s', label, formatter(value))
  end

  local function read_gold()
    return STATE and STATE.resources and tonumber(STATE.resources.gold) or 0
  end

  local function with_default(value, default)
    local number = tonumber(value) or 0
    if number == 0 and default ~= nil then
      return default
    end
    return number
  end

  local function build_attr_lines()
    return {
      attr_line('攻击成长', read_attr('每秒攻击'), function(value) return format_number(value, 0) end),
      attr_line('生命成长', read_attr('每秒生命'), function(value) return format_number(value, 0) end),
      attr_line('攻击范围', read_attr('攻击范围'), function(value) return format_number(value, 0) end),
      attr_line('多重数量', read_attr('多重数量'), function(value) return format_number(value, 0) end),
      attr_line('生命回复', read_attr('生命恢复'), function(value) return format_number(value, 0) end),
      attr_line('移动速度', read_attr('移动速度'), function(value) return format_number(value, 0) end),
      attr_line('攻击速度', with_default(read_attr('攻击速度'), 100), function(value) return format_percent(value, 0) end),
      attr_line('闪避概率', read_attr('闪避'), function(value) return format_percent(value, 0) end),
      attr_line('被动概率', read_attr('命中'), function(value) return format_percent(value, 0) end),
      attr_line('护甲穿透', read_attr('护甲穿透'), function(value) return format_percent(value, 0) end),
      attr_line('物理暴率', read_attr('物理暴击'), function(value) return format_percent(value, 1) end),
      attr_line('物理暴伤', with_default(read_attr('物理暴伤'), 200), function(value) return format_percent(value, 1) end),
      attr_line('法术暴率', read_attr('魔法暴击'), function(value) return format_percent(value, 1) end),
      attr_line('法术暴伤', with_default(read_attr('魔法暴伤'), 200), function(value) return format_percent(value, 1) end),
      attr_line('射箭伤害', read_attr('普攻伤害'), function(value) return format_percent(value, 1) end),
      attr_line('物理增伤', read_attr('物理伤害'), function(value) return format_percent(value, 1) end),
      attr_line('法术增伤', read_attr('魔法伤害'), function(value) return format_percent(value, 1) end),
      attr_line('最终伤害', read_attr('最终伤害'), function(value) return format_percent(value, 1) end),
      attr_line('最终减免', read_attr('伤害减免'), function(value) return format_percent(value, 1) end),
      attr_line('召唤加成', read_attr('召唤加成'), function(value) return format_percent(value, 1) end),
      attr_line('经验加成', read_attr('杀敌经验'), function(value) return format_percent(value, 1) end),
      attr_line('金币', read_gold(), function(value) return format_number(value, 0) end),
      attr_line('绝学伤害', read_attr('技能伤害'), function(value) return format_percent(value, 1) end),
      attr_line('小怪增伤', read_attr('所有伤害'), function(value) return format_percent(value, 1) end),
      attr_line('精英增伤', read_attr('精英伤害'), function(value) return format_percent(value, 1) end),
      attr_line('BOSS增伤', read_attr('挑战伤害'), function(value) return format_percent(value, 1) end),
    }
  end

  local function build_rule_lines()
    return {
      '每1点力量\n增加5攻击力\n增加1生命值\n增加0.1%最大生命',
      '每1点敏捷\n增加5攻击力\n增加0.1%物理伤害',
      '每1点智力\n增加5攻击力\n增加0.1%法术伤害',
      '',
      '',
      '',
    }
  end

  local function refresh()
    local attr_lines = build_attr_lines()
    local grid = get_attr_grid()
    if is_alive(grid) then
      call_ui(grid, 'set_ui_gridview_count', math.ceil(#attr_lines / ATTR_GRID_COLUMN_COUNT), ATTR_GRID_COLUMN_COUNT)
      call_ui(grid, 'set_ui_gridview_size', ATTR_GRID_CELL_WIDTH, ATTR_GRID_CELL_HEIGHT)
    end
    for index, line in ipairs(attr_lines) do
      set_text(get_attr_label(index), line)
    end

    local rule_lines = build_rule_lines()
    for index, path in ipairs(RULE_LABEL_PATHS) do
      set_text(get_child(path), rule_lines[index] or '')
    end
  end

  local function set_panel_visible(visible)
    STATE.attr_tips_panel_visible = visible == true
    set_visible(get_root(), STATE.attr_tips_panel_visible)
    set_visible(get_panel(), STATE.attr_tips_panel_visible)
    if STATE.attr_tips_panel_visible then
      refresh()
    end
    return STATE.attr_tips_panel_visible
  end

  local function init()
    if STATE.attr_tips_panel_visible == nil then
      STATE.attr_tips_panel_visible = false
    end
    set_panel_visible(STATE.attr_tips_panel_visible)
  end

  return {
    init = init,
    refresh = refresh,
    set_visible = set_panel_visible,
    toggle = function()
      return set_panel_visible(not STATE.attr_tips_panel_visible)
    end,
  }
end

return M
