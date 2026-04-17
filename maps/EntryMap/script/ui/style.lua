local M = {}

local function is_ui_alive(node)
  return node and (not node.is_removed or not node:is_removed())
end

function M.apply_text(node, _style_key, value)
  if not is_ui_alive(node) or not node.set_text then
    return node
  end
  node:set_text(value or '')
  return node
end

return M
