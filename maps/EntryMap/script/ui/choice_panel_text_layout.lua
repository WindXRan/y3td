local M = {}

local EFFECT_TRIGGER_COLORS = {
  gold = true,
  dim = true,
  white = true,
}

local MAX_VALUE_LINES = 2
local MAX_EFFECT_LINES = 3

local function push_text(list, block, max_count)
  if not block or type(block.text) ~= 'string' or block.text == '' then
    return false
  end
  if #list >= max_count then
    return false
  end
  list[#list + 1] = block
  return true
end

local function join_text_lines(blocks)
  local lines = {}
  for _, block in ipairs(blocks) do
    if block and block.text and block.text ~= '' then
      lines[#lines + 1] = block.text
    end
  end
  return table.concat(lines, '\n')
end

local function pick_value_color(value_blocks, effect_blocks)
  if value_blocks[1] and value_blocks[1].color then
    return value_blocks[1].color
  end
  if effect_blocks[1] and effect_blocks[1].color then
    return effect_blocks[1].color
  end
  return 'white'
end

local function pick_effect_color(effect_blocks)
  if effect_blocks[1] and effect_blocks[1].color then
    return effect_blocks[1].color
  end
  return 'white'
end

local function split_body_blocks(body_blocks)
  local value_blocks = {}
  local effect_blocks = {}
  local effect_mode = false

  for _, block in ipairs(body_blocks or {}) do
    if not effect_mode and EFFECT_TRIGGER_COLORS[block.color or ''] then
      effect_mode = true
    end

    if effect_mode then
      push_text(effect_blocks, block, MAX_EFFECT_LINES)
    else
      if not push_text(value_blocks, block, MAX_VALUE_LINES) then
        effect_mode = true
        push_text(effect_blocks, block, MAX_EFFECT_LINES)
      end
    end
  end

  return value_blocks, effect_blocks
end

function M.build_text_layout(body_blocks)
  local value_blocks, effect_blocks = split_body_blocks(body_blocks)

  if #value_blocks == 0 and #effect_blocks == 0 then
    return {
      value_visible = false,
      value_text = '',
      value_color = 'white',
      effect_visible = false,
      effect_title = '',
      effect_text = '',
      effect_color = 'white',
    }
  end

  if #value_blocks == 0 then
    if #effect_blocks <= MAX_VALUE_LINES then
      return {
        value_visible = true,
        value_text = join_text_lines(effect_blocks),
        value_color = pick_value_color(value_blocks, effect_blocks),
        effect_visible = false,
        effect_title = '',
        effect_text = '',
        effect_color = 'white',
      }
    end

    local folded_value = {}
    local folded_effect = {}
    for index, block in ipairs(effect_blocks) do
      if index <= MAX_VALUE_LINES then
        folded_value[#folded_value + 1] = block
      else
        folded_effect[#folded_effect + 1] = block
      end
    end

    return {
      value_visible = true,
      value_text = join_text_lines(folded_value),
      value_color = pick_value_color(folded_value, folded_effect),
      effect_visible = #folded_effect > 0,
      effect_title = #folded_effect > 0 and '效果' or '',
      effect_text = join_text_lines(folded_effect),
      effect_color = pick_effect_color(folded_effect),
    }
  end

  return {
    value_visible = #value_blocks > 0,
    value_text = join_text_lines(value_blocks),
    value_color = pick_value_color(value_blocks, effect_blocks),
    effect_visible = #effect_blocks > 0,
    effect_title = #effect_blocks > 0 and '效果' or '',
    effect_text = join_text_lines(effect_blocks),
    effect_color = pick_effect_color(effect_blocks),
  }
end

return M
