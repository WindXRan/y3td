local M = {}

function M.create(env)
  local y3 = env.y3
  local get_player = env.get_player
  local panel_root
  local title_node
  local subtitle_node
  local cost_node
  local attr_title_node
  local attr_nodes = {}
  local affix_title_node
  local affix_nodes = {}

  local function ensure_panel()
    if panel_root and not panel_root:is_removed() then
      return panel_root
    end
    local player = get_player()
    if not player then return nil end
    panel_root = y3.ui.get_ui(player, '物品说明')
    if not panel_root then return nil end
    panel_root:set_follow_mouse(true, 12, 12)
    panel_root:set_visible(false)
    title_node = panel_root:get_child('shopTip.basic.title.title_TEXT')
    subtitle_node = panel_root:get_child('shopTip.basic.title.subtitle_TEXT')
    cost_node = panel_root:get_child('shopTip.note.note_TEXT')
    attr_title_node = panel_root:get_child('shopTip.attr_title_TEXT')
    affix_title_node = panel_root:get_child('shopTip.affix_title_TEXT')
    attr_nodes = {
      panel_root:get_child('shopTip.attr_1_TEXT'),
      panel_root:get_child('shopTip.attr_2_TEXT'),
      panel_root:get_child('shopTip.attr_3_TEXT'),
    }
    affix_nodes = {
      panel_root:get_child('shopTip.affix_1_TEXT'),
      panel_root:get_child('shopTip.affix_2_TEXT'),
      panel_root:get_child('shopTip.affix_3_TEXT'),
    }
    return panel_root
  end

  local function set_lines(nodes, lines)
    for index, node in ipairs(nodes) do
      if node then
        node:set_text(lines[index] or '')
        node:set_visible(lines[index] ~= nil)
      end
    end
  end

  return {
    show_for_anchor = function(anchor_ui, payload)
      local panel = ensure_panel()
      if not panel or not payload then
        return
      end
      panel:set_visible(true)
      if title_node then title_node:set_text(payload.title_text or '') end
      if subtitle_node then subtitle_node:set_text(payload.subtitle_text or '') end
      if cost_node then cost_node:set_text(payload.cost_text or '') end
      if attr_title_node then attr_title_node:set_text(payload.attr_title_text or '当前属性增幅') end
      if affix_title_node then affix_title_node:set_text(payload.affix_title_text or '当前词缀') end
      set_lines(attr_nodes, payload.attr_lines or { '当前无直接属性增幅' })
      local affix_lines = {}
      for _, affix in ipairs(payload.affix_lines or {}) do
        if type(affix) == 'table' then
          if affix.title and affix.body then
            affix_lines[#affix_lines + 1] = affix.title .. '：' .. affix.body
          elseif affix.body then
            affix_lines[#affix_lines + 1] = affix.body
          end
        else
          affix_lines[#affix_lines + 1] = tostring(affix)
        end
      end
      if #affix_lines == 0 then
        affix_lines[1] = '暂无词缀'
      end
      set_lines(affix_nodes, affix_lines)
      if anchor_ui and anchor_ui.get_absolute_x and anchor_ui.get_absolute_y then
        panel:set_absolute_pos(anchor_ui:get_absolute_x() + 14, anchor_ui:get_absolute_y() - 6)
      end
    end,
    hide = function()
      if panel_root and (not panel_root.is_removed or not panel_root:is_removed()) then
        panel_root:set_visible(false)
      end
    end,
  }
end

return M
