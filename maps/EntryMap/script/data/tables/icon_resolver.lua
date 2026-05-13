local M = {}

local PLACEHOLDER_ICON_SET = {
  [131414] = true,
  [906565] = true,
  [906900] = true,
}

local function to_icon_number(value)
  local icon = tonumber(value)
  if not icon or icon <= 0 then
    return nil
  end
  return icon
end

function M.is_placeholder(icon)
  local numeric = to_icon_number(icon)
  if not numeric then
    return true
  end
  return PLACEHOLDER_ICON_SET[numeric] == true
end

function M.pick(...)
  local count = select('#', ...)
  for index = 1, count do
    local icon = to_icon_number(select(index, ...))
    if icon and not M.is_placeholder(icon) then
      return icon
    end
  end
  for index = 1, count do
    local icon = to_icon_number(select(index, ...))
    if icon then
      return icon
    end
  end
  return nil
end

return M
