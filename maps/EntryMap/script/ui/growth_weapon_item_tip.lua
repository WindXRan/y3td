local M = {}

local ROOT_PATH = '物品说明.物品说明.shopTip'
local TITLE_PATH = '物品说明.物品说明.shopTip.basic.title.title_TEXT'
local SUBTITLE_PATH = '物品说明.物品说明.shopTip.basic.title.subtitle_TEXT'
local ICON_PATH = '物品说明.物品说明.shopTip.basic.avatar.icon'
local ATTR_LIST_PATH = '物品说明.物品说明.shopTip.attr_LIST'
local DESCR_LIST_PATH = '物品说明.物品说明.shopTip.descr_LIST'

local QUALITY_PALETTES = {
  common = {
    title = { 120, 255, 126, 255 },
    subtitle = { 62, 255, 68, 255 },
  },
  rare = {
    title = { 138, 203, 255, 255 },
    subtitle = { 40, 149, 255, 255 },
  },
  epic = {
    title = { 226, 174, 255, 255 },
    subtitle = { 198, 120, 255, 255 },
  },
}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function resolve_child(node, path)
  if not node or not path or path == '' then
    return nil
  end
  local ok, child = pcall(node.get_child, node, path)
  if ok and child then
    return child
  end
  return nil
end

local function is_alive(node)
  return node and (not node.is_removed or not node:is_removed())
end

local function set_text(node, text)
  if not is_alive(node) then
    return
  end
  local value = tostring(text or '')
  node:set_text(value)
  node:set_visible(value ~= '')
end

local function set_image(node, image_id)
  if is_alive(node) then
    node:set_image(image_id or 0)
  end
end

local function set_text_color(node, color)
  if not is_alive(node) or not color then
    return
  end
  node:set_text_color(color[1], color[2], color[3], color[4] or 255)
end

local function get_quality_palette(quality)
  return QUALITY_PALETTES[quality or 'common'] or QUALITY_PALETTES.common
end

local function set_list_lines(list_nodes, lines, title_key, body_key)
  for index, entry in ipairs(list_nodes or {}) do
    local line = lines and lines[index] or nil
    if type(entry) == 'table' then
      local title_text = ''
      local body_text = ''
      if type(line) == 'table' then
        title_text = line.title or line[title_key] or line.text or ''
        body_text = line.body or line[body_key] or line.desc or ''
      else
        title_text = line or ''
      end

      set_text(entry[title_key], title_text)
      if body_key then
        set_text(entry[body_key], body_text)
      end
      if entry.root and is_alive(entry.root) then
        local visible = title_text ~= '' or body_text ~= ''
        entry.root:set_visible(visible)
      end
    end
  end
end

function M.create(env)
  local y3 = env.y3
  local get_player = env.get_player
  local cache = nil

  local function ensure_nodes()
    if cache and is_alive(cache.panel) then
      return cache
    end

    local player = get_player()
    local panel = resolve_ui(y3, player, ROOT_PATH)
    if not panel then
      return nil
    end

    local attr_root = resolve_ui(y3, player, ATTR_LIST_PATH)
    local descr_root = resolve_ui(y3, player, DESCR_LIST_PATH)
    local attr_nodes = {}
    local descr_nodes = {}

    for index = 1, 6 do
      attr_nodes[index] = {
        root = attr_root and resolve_child(attr_root, tostring(index)) or nil,
      }
      attr_nodes[index].text = attr_nodes[index].root and resolve_child(attr_nodes[index].root, 'text') or nil
      attr_nodes[index].icon = attr_nodes[index].root and resolve_child(attr_nodes[index].root, 'icon') or nil
    end

    for index = 1, 3 do
      descr_nodes[index] = {
        root = descr_root and resolve_child(descr_root, tostring(index)) or nil,
      }
      descr_nodes[index].title_TEXT = descr_nodes[index].root and resolve_child(descr_nodes[index].root, 'title_TEXT') or nil
      descr_nodes[index].descr_TEXT = descr_nodes[index].root and resolve_child(descr_nodes[index].root, 'descr_TEXT') or nil
    end

    cache = {
      panel = panel,
      title = resolve_ui(y3, player, TITLE_PATH),
      subtitle = resolve_ui(y3, player, SUBTITLE_PATH),
      icon = resolve_ui(y3, player, ICON_PATH),
      attr_nodes = attr_nodes,
      descr_nodes = descr_nodes,
    }
    cache.panel:set_visible(false)
    return cache
  end

  local function position_panel(panel, anchor_ui)
    if not panel or not anchor_ui then
      return
    end
    local screen_width = y3.ui.get_window_width()
    local panel_width = panel:get_real_width()
    local anchor_x = anchor_ui:get_absolute_x()
    local anchor_y = anchor_ui:get_absolute_y()
    local anchor_width = anchor_ui:get_real_width()
    local target_x = anchor_x + anchor_width * 0.5 + 18
    local target_y = anchor_y

    if target_x + panel_width > screen_width - 8 then
      panel:set_anchor(1, 0.5)
      target_x = anchor_x - anchor_width * 0.5 - 18
    else
      panel:set_anchor(0, 0.5)
    end

    panel:set_absolute_pos(target_x, target_y)
  end

  local api = {}

  function api.hide()
    local nodes = ensure_nodes()
    if nodes and is_alive(nodes.panel) then
      nodes.panel:set_visible(false)
    end
  end

  function api.show_for_anchor(anchor_ui, payload)
    local nodes = ensure_nodes()
    if not nodes or not payload or not anchor_ui then
      api.hide()
      return
    end

    local palette = get_quality_palette(payload.quality)
    set_text(nodes.title, payload.title_text or '')
    set_text(nodes.subtitle, string.format('%s  %s', payload.subtitle_text or '', payload.cost_text or ''))
    set_text_color(nodes.title, palette.title)
    set_text_color(nodes.subtitle, palette.subtitle)
    set_image(nodes.icon, payload.icon_res)
    set_list_lines(nodes.attr_nodes, payload.attr_lines, 'text', nil)
    set_list_lines(nodes.descr_nodes, payload.affix_lines, 'title_TEXT', 'descr_TEXT')
    position_panel(nodes.panel, anchor_ui)
    nodes.panel:set_visible(true)
  end

  return api
end

return M
