local UIRoot = require 'ui.ui_root'

local M = {}

local TAB_ORDER = {
  'summary',
  'skills',
  'bonds',
  'treasures',
  'pending',
  'progress',
}

local FALLBACK_TAB_LABELS = {
  summary = '英雄面板',
  skills = '伤害加成',
  bonds = '技能运行时',
  treasures = '经济奖励',
  pending = '待处理轮次',
  progress = '道统进境',
}

local ACTIVE_TAB_BG = { 58, 88, 125, 255 }
local ACTIVE_TAB_TEXT = { 247, 251, 255, 255 }
local INACTIVE_TAB_BG = { 34, 50, 72, 246 }
local INACTIVE_TAB_TEXT = { 184, 200, 220, 255 }

local ROW_COUNT = 8

local function resolve_ui(y3, player, path)
  return UIRoot.resolve_ui(y3, player, path)
end

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function set_text_if_alive(ui, text)
  if is_alive(ui) and ui.set_text then
    ui:set_text(text or '')
  end
end

local function set_text_color_if_alive(ui, color)
  if is_alive(ui) and ui.set_text_color and color then
    ui:set_text_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_image_color_if_alive(ui, color)
  if is_alive(ui) and ui.set_image_color and color then
    ui:set_image_color(color[1], color[2], color[3], color[4] or 255)
  end
end

local function set_visible_if_alive(ui, visible)
  if is_alive(ui) then
    ui:set_visible(visible == true)
  end
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3

  local function get_attr_overview_model()
    local previous_mode = STATE.runtime_overview_mode
    STATE.runtime_overview_mode = 'attr'
    local model = env.get_runtime_overview_model and env.get_runtime_overview_model() or nil
    STATE.runtime_overview_mode = previous_mode
    return model
  end

  local function resolve_panel_nodes(panel)
    local player = env.get_player()
    panel.root = resolve_ui(y3, player, 'RuntimeAttrTabPanel')
    panel.mask_bg = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.mask_bg')
    panel.main_frame = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame')
    panel.title = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame.panel_title')
    panel.subtitle = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame.panel_subtitle')
    panel.close_button = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame.close_button')
    panel.close_button_label = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame.close_button.close_button_label')
    panel.section_title = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame.content.section_title')
    panel.empty_tip = resolve_ui(y3, player, 'RuntimeAttrTabPanel.block.main_frame.content.empty_tip')

    panel.tabs = panel.tabs or {}
    for _, key in ipairs(TAB_ORDER) do
      panel.tabs[key] = panel.tabs[key] or {}
      panel.tabs[key].button = resolve_ui(
        y3,
        player,
        string.format('RuntimeAttrTabPanel.block.main_frame.tab_bar.%s', 'tab_' .. key)
      )
      panel.tabs[key].label = resolve_ui(
        y3,
        player,
        string.format('RuntimeAttrTabPanel.block.main_frame.tab_bar.tab_%s.tab_%s_label', key, key)
      )
    end

    panel.rows = panel.rows or {}
    for index = 1, ROW_COUNT do
      panel.rows[index] = resolve_ui(
        y3,
        player,
        string.format('RuntimeAttrTabPanel.block.main_frame.content.row_%d', index)
      )
    end
  end

  local function bind_click_targets(panel, bind_key, nodes, callback)
    panel.bound_clicks = panel.bound_clicks or {}
    for _, node in ipairs(nodes or {}) do
      if is_alive(node) and panel.bound_clicks[bind_key] ~= node then
        panel.bound_clicks[bind_key] = node
        if node.set_intercepts_operations then
          node:set_intercepts_operations(true)
        end
        node:add_fast_event('左键-点击', callback)
      end
    end
  end

  local function set_tab_visual(panel, key, selected)
    local tab = panel.tabs and panel.tabs[key] or nil
    if not tab then
      return
    end
    set_image_color_if_alive(tab.button, selected and ACTIVE_TAB_BG or INACTIVE_TAB_BG)
    set_text_color_if_alive(tab.label, selected and ACTIVE_TAB_TEXT or INACTIVE_TAB_TEXT)
  end

  local function resolve_active_tab_key(model)
    local selected = STATE.runtime_attr_tab_selected or 'summary'
    if model and model.sections and model.sections[selected] then
      return selected
    end
    for _, key in ipairs(TAB_ORDER) do
      if model and model.sections and model.sections[key] then
        return key
      end
    end
    return 'summary'
  end

  local function create_panel()
    local panel = STATE.runtime_attr_tab_panel
    if panel and is_alive(panel.root) then
      resolve_panel_nodes(panel)
      return panel
    end

    panel = {
      tabs = {},
      rows = {},
      bound_clicks = {},
      visible = false,
    }
    resolve_panel_nodes(panel)
    if not is_alive(panel.root) then
      return nil
    end

    bind_click_targets(panel, 'mask_close', { panel.mask_bg }, function()
      if panel.root and is_alive(panel.root) then
        panel.visible = false
        panel.root:set_visible(false)
      end
    end)

    bind_click_targets(panel, 'close_button', {
      panel.close_button,
      panel.close_button_label,
    }, function()
      if panel.root and is_alive(panel.root) then
        panel.visible = false
        panel.root:set_visible(false)
      end
    end)

    for _, key in ipairs(TAB_ORDER) do
      local bind_key = 'tab_' .. key
      local tab_button = panel.tabs[key] and panel.tabs[key].button or nil
      local tab_label = panel.tabs[key] and panel.tabs[key].label or nil
      bind_click_targets(panel, bind_key, { tab_button, tab_label }, function()
        STATE.runtime_attr_tab_selected = key
        panel.visible = true
        if is_alive(panel.root) then
          panel.root:set_visible(true)
        end
        local refresh = STATE.runtime_attr_tab_panel_refresh
        if refresh then
          refresh()
        end
      end)
    end

    set_visible_if_alive(panel.root, false)
    STATE.runtime_attr_tab_panel = panel
    return panel
  end

  local function refresh_panel()
    local panel = create_panel()
    if not panel or not is_alive(panel.root) then
      return nil
    end

    local model = get_attr_overview_model()
    if not model then
      return panel
    end

    local active_key = resolve_active_tab_key(model)
    STATE.runtime_attr_tab_selected = active_key

    set_text_if_alive(panel.title, model.title or '局内属性总览')
    set_text_if_alive(panel.subtitle, model.subtitle or '按 TAB 关闭属性面板')
    set_text_if_alive(panel.close_button_label, model.close_label or '关闭 TAB')

    for _, key in ipairs(TAB_ORDER) do
      local section = model.sections and model.sections[key] or nil
      local tab_label = section and section.title or FALLBACK_TAB_LABELS[key]
      set_text_if_alive(panel.tabs[key] and panel.tabs[key].label, tab_label)
      set_tab_visual(panel, key, key == active_key)
    end

    local active_section = model.sections and model.sections[active_key] or nil
    local lines = active_section and active_section.lines or {}

    set_text_if_alive(panel.section_title, active_section and active_section.title or FALLBACK_TAB_LABELS[active_key])

    local visible_line_count = 0
    for index = 1, ROW_COUNT do
      local row = panel.rows[index]
      local line = lines[index]
      local has_line = line ~= nil and tostring(line) ~= ''
      set_visible_if_alive(row, has_line)
      if has_line then
        visible_line_count = visible_line_count + 1
        set_text_if_alive(row, tostring(line))
      end
    end

    if is_alive(panel.empty_tip) then
      panel.empty_tip:set_visible(visible_line_count <= 0)
      if visible_line_count <= 0 then
        panel.empty_tip:set_text('当前没有可显示的数据')
      end
    end

    return panel
  end

  STATE.runtime_attr_tab_panel_refresh = refresh_panel

  local function set_visible(visible)
    local panel = create_panel()
    if not panel or not is_alive(panel.root) then
      return nil
    end
    panel.visible = visible == true
    panel.root:set_visible(panel.visible)
    if panel.visible then
      refresh_panel()
    end
    return panel.visible
  end

  local function toggle_panel(force_visible)
    local panel = create_panel()
    if not panel or not is_alive(panel.root) then
      return nil
    end
    local next_visible = force_visible
    if next_visible == nil then
      next_visible = not (panel.visible == true)
    end
    return set_visible(next_visible)
  end

  local function show_tab(tab_key)
    if tab_key and FALLBACK_TAB_LABELS[tab_key] then
      STATE.runtime_attr_tab_selected = tab_key
    end
    return set_visible(true)
  end

  return {
    ensure_panel = create_panel,
    hide_panel = function()
      return set_visible(false)
    end,
    refresh_panel = refresh_panel,
    set_visible = set_visible,
    show_tab = show_tab,
    toggle_panel = toggle_panel,
  }
end

return M
