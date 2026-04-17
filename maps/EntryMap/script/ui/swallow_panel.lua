local ui_res = require 'ui.res'

local M = {}
local EMPTY_SLOT_IMAGE = 904138

local ROW_NAMES = {
  'layout_2',
  'layout_2_1',
  'layout_2_2',
  'layout_2_3',
  'layout_2_4',
  'layout_2_4_1',
}

local SLOT_NAMES = {
  '羁绊图片1',
  '羁绊图片1_1',
  '羁绊图片1_2',
  '羁绊图片1_3',
  '羁绊图片1_4',
  '羁绊图片1_5',
  '羁绊图片1_6',
  '羁绊图片1_6_1',
  '羁绊图片1_6_2',
}

local function is_alive(ui)
  return ui and (not ui.is_removed or not ui:is_removed())
end

local function quality_label(quality)
  if quality == 'legendary' then
    return '传说'
  end
  if quality == 'epic' then
    return '史诗'
  end
  if quality == 'rare' then
    return '稀有'
  end
  return '普通'
end

function M.create(env)
  local STATE = env.STATE
  local y3 = env.y3
  local get_player = env.get_player
  local message = env.message
  local get_consumed_bond_entries = env.get_consumed_bond_entries

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function resolve_prefab_node(prefab, path)
    if not prefab then
      return nil
    end
    local ok, ui = pcall(function()
      return prefab:get_child(path)
    end)
    if not ok or not ui then
      return nil
    end
    return ui
  end

  local function collect_icon_slots(prefab)
    local slots = {}
    for _, row_name in ipairs(ROW_NAMES) do
      for _, slot_name in ipairs(SLOT_NAMES) do
        local path = string.format('layout_1.image_3.%s.%s', row_name, slot_name)
        local ui = resolve_prefab_node(prefab, path)
        if ui then
          slots[#slots + 1] = ui
        end
      end
    end
    return slots
  end

  local function build_summary_lines(entries, max_lines)
    local lines = {}
    local limit = math.max(1, max_lines or #entries)

    if not entries or #entries == 0 then
      return {
        '当前还没有已炼化仙缘。',
        '炼化后的仙缘会按“最新在前”留存在这里。',
      }
    end

    for index, entry in ipairs(entries) do
      if index > limit then
        break
      end
      lines[#lines + 1] = string.format(
        '%02d. [%s] %s',
        index,
        quality_label(entry.quality),
        tostring(entry.pretty_display_name or entry.title or entry.display_name or entry.root_id or '未命名仙缘')
      )
    end

    local remain = #entries - #lines
    if remain > 0 then
      lines[#lines + 1] = string.format('……其余 %d 条记录。', remain)
    end

    return lines
  end

  local function ensure_panel()
    if STATE.swallow_panel and is_alive(STATE.swallow_panel.root) then
      return STATE.swallow_panel
    end
    if STATE.swallow_panel_unavailable == true then
      return nil
    end

    local hud = get_hud_root()
    if not hud then
      return nil
    end

    local ok, prefab = pcall(y3.ui_prefab.create, get_player(), '吞噬界面', hud)
    if not ok or not prefab then
      STATE.swallow_panel_unavailable = true
      if message and not STATE.swallow_panel_unavailable_warned then
        STATE.swallow_panel_unavailable_warned = true
        message('炼化图谱预制体缺失，已自动跳过该面板。')
      end
      return nil
    end
    local root = prefab and prefab:get_child() or nil
    if not root then
      STATE.swallow_panel_unavailable = true
      return nil
    end

    root:set_z_order(9890)
    root:set_intercepts_operations(true)
    root:set_visible(false)

    local title = resolve_prefab_node(prefab, 'layout_1.image_4.label_2')
    local summary = root:create_child('文本')
    summary:set_ui_size(1100, 180)
    summary:set_anchor(0.5, 0)
    summary:set_pos(600, 34)
    summary:set_font_size(14)
    summary:set_text_color(236, 242, 250, 255)
    summary:set_text_alignment('左', '上')
    summary:set_z_order(9891)

    local hint = root:create_child('文本')
    hint:set_ui_size(560, 28)
    hint:set_anchor(1, 0.5)
    hint:set_pos(1158, 790)
    hint:set_font_size(13)
    hint:set_text_color(188, 210, 236, 255)
    hint:set_text_alignment('右', '中')
    hint:set_text('按 I 关闭')
    hint:set_z_order(9891)

    STATE.swallow_panel = {
      prefab = prefab,
      root = root,
      title = title,
      summary = summary,
      hint = hint,
      icon_slots = collect_icon_slots(prefab),
      visible = false,
    }
    return STATE.swallow_panel
  end

  local function refresh_panel()
    local panel = STATE.swallow_panel
    if not panel or not is_alive(panel.root) then
      return
    end
    if panel.visible ~= true then
      return
    end

    local entries = get_consumed_bond_entries and get_consumed_bond_entries(#panel.icon_slots) or {}
    if panel.title and is_alive(panel.title) then
      panel.title:set_text(string.format('已炼化仙缘（最新在前） %d', #entries))
    end

    for index, slot in ipairs(panel.icon_slots or {}) do
      if is_alive(slot) then
        local entry = entries[index]
        slot:set_visible(true)
        if entry then
          slot:set_image(entry.icon or ui_res.common.empty)
        else
          slot:set_image(EMPTY_SLOT_IMAGE)
        end
      end
    end

    if panel.summary and is_alive(panel.summary) then
      local lines = build_summary_lines(entries, 9)
      panel.summary:set_text(table.concat(lines, '\n'))
    end
  end

  local function set_visible(visible)
    local panel = ensure_panel()
    if not panel then
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
    local panel = ensure_panel()
    if not panel then
      if message then
        message('炼化图谱加载失败，先用文字模式展示。')
      end
      return nil
    end

    local next_visible = force_visible
    if next_visible == nil then
      next_visible = not (panel.visible == true)
    end
    return set_visible(next_visible)
  end

  return {
    ensure_panel = ensure_panel,
    refresh_panel = refresh_panel,
    set_visible = set_visible,
    toggle_panel = toggle_panel,
  }
end

return M
