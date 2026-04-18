local UIRoot = require 'ui.ui_root'

local M = {}

local LIST_LIMIT = 20
local LIST_ROW_HEIGHT = 46
local BOARD_STAY_SEC = 2.0
local BOARD_MAX_QUEUE = 5
local MARQUEE_SPEED = 120
local MARQUEE_MAX_QUEUE = 20

local LIST_STYLES = {
  neutral = {
    bg = { 42, 55, 74, 214 },
    text = { 240, 244, 252, 255 },
    icon = { 255, 255, 255, 255 },
  },
  positive = {
    bg = { 34, 88, 62, 224 },
    text = { 234, 255, 240, 255 },
    icon = { 196, 255, 214, 255 },
  },
  warning = {
    bg = { 122, 82, 32, 224 },
    text = { 255, 244, 222, 255 },
    icon = { 255, 220, 156, 255 },
  },
  rare = {
    bg = { 58, 74, 126, 224 },
    text = { 236, 242, 255, 255 },
    icon = { 212, 220, 255, 255 },
  },
  reward = {
    bg = { 78, 92, 36, 224 },
    text = { 249, 255, 228, 255 },
    icon = { 232, 255, 182, 255 },
  },
}

local function get_style(name)
  return LIST_STYLES[name or 'neutral'] or LIST_STYLES.neutral
end

local function is_alive(ui)
  return UIRoot.is_alive(ui)
end

local function safe_set_visible(ui, visible)
  if is_alive(ui) then
    ui:set_visible(visible == true)
  end
end

local function safe_remove_timer(timer)
  if timer and timer.remove then
    timer:remove()
  end
end

local function safe_remove_prefab(prefab)
  if prefab and prefab.remove then
    prefab:remove()
  end
end

local function insert_priority(queue, message, max_count)
  local inserted = false
  for index, entry in ipairs(queue) do
    if (message.priority or 0) > (entry.priority or 0) then
      table.insert(queue, index, message)
      inserted = true
      break
    end
  end
  if not inserted then
    queue[#queue + 1] = message
  end
  while #queue > max_count do
    queue[#queue] = nil
  end
end

function M.create(env)
  local y3 = env.y3
  local get_player = env.get_player

  local runtime = {
    visible = true,
    list_entries = {},
    board_queue = {},
    marquee_queue = {},
    marquee_slot_index = 1,
  }

  local function ensure_panel()
    if runtime.root and is_alive(runtime.root) then
      return runtime
    end

    local player = get_player()
    local root = UIRoot.get_message_root(y3, player)
    if not root then
      return nil
    end

    runtime.root = root
    runtime.list_root = UIRoot.resolve_ui(y3, player, '消息提示.消息列表')
    runtime.list_container = UIRoot.resolve_ui(y3, player, '消息提示.消息列表.总容器')
    runtime.board_root = UIRoot.resolve_ui(y3, player, '消息提示.公告板')
    runtime.board_bg = UIRoot.resolve_ui(y3, player, '消息提示.公告板.背景')
    runtime.board_text = UIRoot.resolve_ui(y3, player, '消息提示.公告板.文本')
    runtime.board_flash = UIRoot.resolve_ui(y3, player, '消息提示.公告板.闪白')
    runtime.marquee_root = UIRoot.resolve_ui(y3, player, '消息提示.跑马灯公告')
    runtime.marquee_mask = UIRoot.resolve_ui(y3, player, '消息提示.跑马灯公告.根节点遮罩')
    runtime.marquee_bg = UIRoot.resolve_ui(y3, player, '消息提示.跑马灯公告.根节点遮罩.背景')
    runtime.marquee_nodes = {
      UIRoot.resolve_ui(y3, player, '消息提示.跑马灯公告.根节点遮罩.公告1'),
      UIRoot.resolve_ui(y3, player, '消息提示.跑马灯公告.根节点遮罩.公告2'),
      UIRoot.resolve_ui(y3, player, '消息提示.跑马灯公告.根节点遮罩.公告3'),
    }

    if is_alive(runtime.board_flash) then
      runtime.board_flash:set_alpha(0)
    end
    for _, node in ipairs(runtime.marquee_nodes or {}) do
      if is_alive(node) then
        node:set_visible(false)
      end
    end

    safe_set_visible(runtime.root, runtime.visible)
    safe_set_visible(runtime.board_root, false)
    safe_set_visible(runtime.marquee_root, false)
    return runtime
  end

  local function layout_list_entries()
    local panel = ensure_panel()
    if not panel or not is_alive(panel.list_container) then
      return
    end

    local container_height = panel.list_container:get_height()
    for index, entry in ipairs(panel.list_entries) do
      if entry.root and is_alive(entry.root) then
        local target_y = container_height - ((index - 1) * LIST_ROW_HEIGHT)
        entry.root:set_anchor(0, 1)
        entry.root:set_pos(0, target_y)
        entry.root:set_z_order(9700 + (#panel.list_entries - index))
      end
    end
  end

  local function remove_list_entry(entry)
    local panel = runtime
    for index, current in ipairs(panel.list_entries) do
      if current == entry then
        safe_remove_timer(current.timer)
        safe_remove_prefab(current.prefab)
        table.remove(panel.list_entries, index)
        break
      end
    end
    layout_list_entries()
  end

  local function render_board_state()
    local panel = runtime
    local show = panel.visible == true and panel.current_board ~= nil
    safe_set_visible(panel.board_root, show)
    if show and is_alive(panel.board_text) then
      panel.board_text:set_text(panel.current_board.text or '')
    end
  end

  local function start_next_board()
    local panel = ensure_panel()
    if not panel or panel.current_board or #panel.board_queue == 0 then
      render_board_state()
      return
    end

    panel.current_board = table.remove(panel.board_queue, 1)
    render_board_state()

    if is_alive(panel.board_flash) then
      panel.board_flash:set_visible(true)
      panel.board_flash:set_anim_opacity(235, 0, 0.25, 0)
    end

    safe_remove_timer(panel.board_timer)
    panel.board_timer = y3.ltimer.wait(panel.current_board.duration or BOARD_STAY_SEC, function()
      panel.current_board = nil
      render_board_state()
      start_next_board()
    end)
  end

  local function estimate_marquee_travel(text, width)
    local chars = string.len(tostring(text or ''))
    local text_width = math.max(180, chars * 24)
    local mask_width = math.max(320, width or 640)
    return mask_width + text_width + 80, text_width
  end

  local function render_marquee_state()
    local panel = runtime
    local show = panel.visible == true and panel.current_marquee ~= nil
    safe_set_visible(panel.marquee_root, show)
    safe_set_visible(panel.marquee_bg, show)
  end

  local function start_next_marquee()
    local panel = ensure_panel()
    if not panel or panel.current_marquee or #panel.marquee_queue == 0 then
      render_marquee_state()
      return
    end

    local node_count = #panel.marquee_nodes
    if node_count <= 0 then
      return
    end

    local slot_index = panel.marquee_slot_index
    panel.marquee_slot_index = (slot_index % node_count) + 1

    local node = panel.marquee_nodes[slot_index]
    if not is_alive(node) then
      panel.current_marquee = nil
      start_next_marquee()
      return
    end

    local item = table.remove(panel.marquee_queue, 1)
    panel.current_marquee = item
    render_marquee_state()

    local mask_width = is_alive(panel.marquee_mask) and panel.marquee_mask:get_width() or 640
    local travel_distance, text_width = estimate_marquee_travel(item.text, mask_width)
    local start_x = mask_width + 40
    local end_x = -text_width - 40
    local y = node:get_relative_y()
    local duration = item.duration or math.max(4, travel_distance / MARQUEE_SPEED)

    for _, other in ipairs(panel.marquee_nodes) do
      if is_alive(other) then
        other:set_visible(other == node)
      end
    end

    node:set_text(item.text or '')
    node:set_visible(panel.visible == true)
    node:set_pos(start_x, y)
    node:set_anim_pos(start_x, y, end_x, y, duration, 0)

    safe_remove_timer(panel.marquee_timer)
    panel.marquee_timer = y3.ltimer.wait(duration, function()
      if is_alive(node) then
        node:set_visible(false)
      end
      panel.current_marquee = nil
      render_marquee_state()
      start_next_marquee()
    end)
  end

  local function push_list(text, icon, opts)
    local panel = ensure_panel()
    if not panel or not is_alive(panel.list_container) then
      return nil
    end

    local style_name = opts and opts.style or 'neutral'
    local style = get_style(style_name)
    local prefab = y3.ui_prefab.create(get_player(), '单条消息', panel.list_container)
    local root = prefab and prefab:get_child() or nil
    if not root then
      return nil
    end

    local bg = prefab:get_child('容器.图片：底板')
    local text_ui = prefab:get_child('容器.文本：消息文字')
    local icon_ui = prefab:get_child('容器.图片：消息图标')

    if is_alive(bg) and bg.set_image_color then
      bg:set_image_color(style.bg[1], style.bg[2], style.bg[3], style.bg[4])
    end
    if is_alive(text_ui) then
      text_ui:set_text(text or '')
      if text_ui.set_text_color then
        text_ui:set_text_color(style.text[1], style.text[2], style.text[3], style.text[4])
      end
    end
    if is_alive(icon_ui) then
      if icon ~= nil and icon_ui.set_image then
        icon_ui:set_image(icon)
      end
      if icon_ui.set_image_color then
        icon_ui:set_image_color(style.icon[1], style.icon[2], style.icon[3], style.icon[4])
      end
    end

    local entry = {
      prefab = prefab,
      root = root,
      timer = nil,
    }

    table.insert(panel.list_entries, 1, entry)
    while #panel.list_entries > LIST_LIMIT do
      remove_list_entry(panel.list_entries[#panel.list_entries])
    end

    root:set_anchor(0, 1)
    root:set_pos(-18, is_alive(panel.list_container) and panel.list_container:get_height() or 0)
    layout_list_entries()
    local final_y = root:get_relative_y()
    root:set_anim_pos(-18, final_y, 0, final_y, 0.12, 0)

    local duration = opts and opts.duration or nil
    if duration and duration > 0 then
      entry.timer = y3.ltimer.wait(duration, function()
        remove_list_entry(entry)
      end)
    end

    return entry
  end

  local function push_board(text, priority, opts)
    if not text or text == '' then
      return nil
    end
    local item = {
      text = text,
      priority = tonumber(priority) or 0,
      duration = opts and opts.duration or BOARD_STAY_SEC,
    }
    insert_priority(runtime.board_queue, item, BOARD_MAX_QUEUE)
    start_next_board()
    return item
  end

  local function push_marquee(text, priority, opts)
    if not text or text == '' then
      return nil
    end
    local item = {
      text = text,
      priority = tonumber(priority) or 0,
      duration = opts and opts.duration or nil,
    }
    insert_priority(runtime.marquee_queue, item, MARQUEE_MAX_QUEUE)
    start_next_marquee()
    return item
  end

  local function set_visible(visible)
    runtime.visible = visible == true
    local panel = ensure_panel()
    if not panel then
      return nil
    end

    safe_set_visible(panel.root, runtime.visible)
    if not runtime.visible then
      safe_set_visible(panel.board_root, false)
      safe_set_visible(panel.marquee_root, false)
      return panel
    end

    layout_list_entries()
    render_board_state()
    render_marquee_state()
    if not panel.current_board then
      start_next_board()
    end
    if not panel.current_marquee then
      start_next_marquee()
    end
    return panel
  end

  return {
    ensure_panel = ensure_panel,
    push_list = push_list,
    push_board = push_board,
    push_marquee = push_marquee,
    set_visible = set_visible,
  }
end

return M
