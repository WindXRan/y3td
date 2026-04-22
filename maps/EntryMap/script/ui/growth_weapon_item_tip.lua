local UIRoot = require 'ui.ui_root'

local M = {}

local ROOT_PATHS = {
  '物品说明.layout_15.shopTip',
  '物品说明.shopTip',
  '物品说明.物品说明.shopTip',
  '背包系统.背包系统.物品说明',
}

local TITLE_PATHS = {
  '物品说明.layout_15.shopTip.basic.title.title_TEXT',
  '物品说明.shopTip.basic.title.title_TEXT',
  '物品说明.物品说明.shopTip.basic.title.title_TEXT',
  '背包系统.背包系统.物品说明.basic.title.title_TEXT',
}

local SUBTITLE_PATHS = {
  '物品说明.layout_15.shopTip.basic.title.subtitle_TEXT',
  '物品说明.shopTip.basic.title.subtitle_TEXT',
  '物品说明.物品说明.shopTip.basic.title.subtitle_TEXT',
  '背包系统.背包系统.物品说明.basic.title.subtitle_TEXT',
}

local ICON_PATHS = {
  '物品说明.layout_15.shopTip.basic.avatar.icon',
  '物品说明.shopTip.basic.avatar.icon',
  '物品说明.物品说明.shopTip.basic.avatar.icon',
  '背包系统.背包系统.物品说明.basic.avatar.icon',
}

local ATTR_LIST_PATHS = {
  '物品说明.layout_15.shopTip.attr_LIST',
  '物品说明.shopTip.attr_LIST',
  '物品说明.物品说明.shopTip.attr_LIST',
}

local DESCR_LIST_PATHS = {
  '物品说明.layout_15.shopTip.descr_LIST',
  '物品说明.shopTip.descr_LIST',
  '物品说明.物品说明.shopTip.descr_LIST',
  '背包系统.背包系统.物品说明.descr_LIST',
}

local NOTE_ROOT_PATHS = {
  '物品说明.layout_15.shopTip.note',
  '物品说明.shopTip.note',
  '物品说明.物品说明.shopTip.note',
  '背包系统.背包系统.物品说明.note',
}

local NOTE_TEXT_PATHS = {
  '物品说明.layout_15.shopTip.note.note_TEXT',
  '物品说明.shopTip.note.note_TEXT',
  '物品说明.物品说明.shopTip.note.note_TEXT',
  '背包系统.背包系统.物品说明.note.note_TEXT',
}

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
  return UIRoot.resolve_ui(y3, player, path)
end

local function resolve_first_ui(y3, player, paths)
  return UIRoot.resolve_first_ui(y3, player, paths)
end

local function resolve_child(node, path)
  return UIRoot.resolve_child(node, path)
end

local function is_alive(node)
  return UIRoot.is_alive(node)
end

local function trim_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  local value = text:gsub('\r', '')
  value = value:gsub('^%s+', '')
  value = value:gsub('%s+$', '')
  return value
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

local function flatten_line(line)
  if type(line) == 'table' then
    local title_text = trim_text(line.title or line.text or '')
    local body_text = trim_text(line.body or line.desc or '')
    if title_text ~= '' and body_text ~= '' then
      return title_text .. '：' .. body_text
    end
    if body_text ~= '' then
      return body_text
    end
    return title_text
  end
  return trim_text(line)
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

      local single_text = trim_text(flatten_line(line))
      if entry[title_key] then
        set_text(entry[title_key], title_text)
      end
      if body_key then
        local body_value = body_text
        if not entry[title_key] then
          body_value = single_text
        elseif body_value == '' then
          body_value = title_text
        end
        set_text(entry[body_key], body_value)
      end
      if entry.root and is_alive(entry.root) then
        local visible = single_text ~= '' or body_text ~= ''
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
    local panel = resolve_first_ui(y3, player, ROOT_PATHS)
    if not panel then
      return nil
    end

    local attr_root = resolve_first_ui(y3, player, ATTR_LIST_PATHS)
    local descr_root = resolve_first_ui(y3, player, DESCR_LIST_PATHS)
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
      title = resolve_first_ui(y3, player, TITLE_PATHS),
      subtitle = resolve_first_ui(y3, player, SUBTITLE_PATHS),
      icon = resolve_first_ui(y3, player, ICON_PATHS),
      note_root = resolve_first_ui(y3, player, NOTE_ROOT_PATHS),
      note = resolve_first_ui(y3, player, NOTE_TEXT_PATHS),
      attr_nodes = attr_nodes,
      descr_nodes = descr_nodes,
      use_inventory_desc = attr_root == nil,
    }
    cache.panel:set_visible(false)
    if cache.note_root and is_alive(cache.note_root) then
      cache.note_root:set_visible(false)
    end
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
    local subtitle_text = trim_text(payload.subtitle_text or '')
    local cost_text = trim_text(payload.cost_text or '')
    if nodes.use_inventory_desc then
      set_text(nodes.subtitle, subtitle_text)
      set_text(nodes.note, cost_text)
      if nodes.note_root and is_alive(nodes.note_root) then
        nodes.note_root:set_visible(cost_text ~= '')
      end
    else
      local subtitle_parts = {}
      if subtitle_text ~= '' then
        subtitle_parts[#subtitle_parts + 1] = subtitle_text
      end
      if cost_text ~= '' then
        subtitle_parts[#subtitle_parts + 1] = cost_text
      end
      set_text(nodes.subtitle, table.concat(subtitle_parts, '  '))
      set_text(nodes.note, cost_text)
      if nodes.note_root and is_alive(nodes.note_root) then
        nodes.note_root:set_visible(cost_text ~= '')
      end
    end
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
