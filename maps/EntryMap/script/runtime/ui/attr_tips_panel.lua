local UiRoot = require 'ui.ui_root'
local AttrDefs = { aliases = {}, by_name = {} }
local AttrDisplayConfig = require 'data.tables.ui.attr_display_config'

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

local is_alive = UiRoot.is_alive

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
  local STATE = env and env.STATE or _G.STATE
  local y3 = env and env.y3 or _G.y3
  local get_player = env and env.get_player or y3.player.get_main_player
  local hero_attr_system = env and env.hero_attr_system or _G.hero_attr_system
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
    local lines = {}
    for _, entry in ipairs(AttrDisplayConfig) do
      local value
      if entry.is_gold then
        value = read_gold()
      else
        value = read_attr(entry.attr)
        if entry.default ~= nil then
          value = with_default(value, entry.default)
        end
      end
      local formatter
      if entry.format == 'percent' then
        formatter = function(v) return format_percent(v, entry.decimals or 1) end
      else
        formatter = function(v) return format_number(v, entry.decimals or 0) end
      end
      lines[#lines + 1] = attr_line(entry.display, value, formatter)
    end
    return lines
  end

  local function build_rule_lines()
    return {
      '',
      '',
      '',
      '',
      '',
      '',
    }
  end

  local function refresh()
    local panel = get_panel()
    if not is_alive(panel) then
      return false
    end

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
    return true
  end

  local function set_panel_visible(visible)
    STATE.attr_tips_panel_visible = visible == true

    -- UI controls may not exist yet during early bootstrap. Avoid resolving
    -- editor-placed UI before the interface is initialized.
    local root = is_alive(nodes.root) and nodes.root or nil
    local panel = is_alive(nodes.panel) and nodes.panel or nil

    if not STATE.attr_tips_panel_visible and not root and not panel then
      return STATE.attr_tips_panel_visible
    end

    if not root then
      root = get_root()
    end
    if not panel then
      panel = get_panel()
    end

    set_visible(root, STATE.attr_tips_panel_visible)
    set_visible(panel, STATE.attr_tips_panel_visible)
    if STATE.attr_tips_panel_visible and is_alive(panel) then
      refresh()
    end
    return STATE.attr_tips_panel_visible
  end

  local function init()
    if STATE.attr_tips_panel_visible == nil then
      STATE.attr_tips_panel_visible = false
    end
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
