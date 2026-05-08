-- 统一的 tip block 配色与构建函数，供局外存档面板和局内 HUD 共用
-- 每个 block: { title = string, body = string, style = 'normal'|'attr'|'highlight'|'cost'|'list'|'warning', visible = 'always'|'owned'|'not_owned' }

local M = {}

M.STYLE = {
  normal = {
    title_color = { 255, 232, 44, 255 },
    body_color = { 178, 183, 194, 255 },
    body_size = 14,
  },
  attr = {
    title_color = { 255, 232, 44, 255 },
    body_color = { 44, 255, 112, 255 },
    body_size = 16,
  },
  highlight = {
    title_color = { 255, 232, 44, 255 },
    body_color = { 146, 219, 255, 255 },
    body_size = 15,
  },
  cost = {
    title_color = { 255, 232, 44, 255 },
    body_color = { 255, 196, 92, 255 },
    body_size = 15,
  },
  list = {
    title_color = { 255, 232, 44, 255 },
    body_color = { 220, 226, 238, 255 },
    body_size = 14,
  },
  warning = {
    title_color = { 255, 214, 72, 255 },
    body_color = { 255, 118, 94, 255 },
    body_size = 15,
  },
}

local function trim(value)
  return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

-- 将 attr|value 对转换为 style='attr' 的 blocks
function M.build_attr_blocks(attr_lines)
  local blocks = {}
  for _, line in ipairs(attr_lines or {}) do
    local trimmed = trim(line)
    if trimmed ~= '' then
      blocks[#blocks + 1] = { title = '', body = trimmed, style = 'attr' }
    end
  end
  return blocks
end

-- 特殊效果 block
function M.build_effect_block(special_effect)
  local text = trim(special_effect)
  if text == '' then
    return nil
  end
  return { title = '[特殊效果]', body = text, style = 'highlight' }
end

-- 获取方式 block
function M.build_obtain_block(obtain)
  local text = trim(obtain)
  if text == '' then
    return { title = '[获取方式]', body = '通过关卡奖励、活动与兑换获得。', style = 'normal' }
  end
  return { title = '[获取方式]', body = text, style = 'normal' }
end

-- 属性总览 block（多条属性合并在一个 body 中）
function M.build_attr_summary_block(attr_lines)
  if #(attr_lines or {}) == 0 then
    return nil
  end
  return { title = '[属性加成]', body = table.concat(attr_lines, '\n'), style = 'attr' }
end

-- 消耗/价格 block
function M.build_cost_block(label, amount, item_name)
  local body = tostring(label or '消耗')
  if amount then
    body = body .. '：' .. tostring(amount)
  end
  if item_name and item_name ~= '' then
    body = body .. ' ' .. tostring(item_name)
  end
  return { title = '[消耗]', body = body, style = 'cost' }
end

-- 列表项 block
function M.build_list_block(title, items)
  local body = table.concat(items or {}, '\n')
  return { title = title or '', body = body, style = 'list' }
end

-- CSV 商品场景：从 attr_lines + special_effect + obtain 构建完整 detail_blocks
function M.build_shop_item_blocks(attr_lines, special_effect, obtain)
  local blocks = {}

  -- 属性行（绿色高亮）
  for _, block in ipairs(M.build_attr_blocks(attr_lines)) do
    blocks[#blocks + 1] = block
  end

  -- 特殊效果（蓝色）
  local effect = M.build_effect_block(special_effect)
  if effect then
    blocks[#blocks + 1] = effect
  end

  -- 获取方式
  blocks[#blocks + 1] = M.build_obtain_block(obtain)

  return blocks
end

-- 从 bond_tip_model_builder 的 tip_model 转换为 detail_blocks
function M.build_bond_blocks(tip_model)
  local m = tip_model or {}
  local blocks = {}

  -- 技能/效果行（绿色属性）
  for _, block in ipairs(M.build_attr_blocks(m.bonus_lines)) do
    blocks[#blocks + 1] = block
  end

  -- 收录/吞噬条件
  if trim(m.effect_body_text or '') ~= '' then
    blocks[#blocks + 1] = { title = '[收录条件]', body = m.effect_body_text, style = 'normal' }
  end

  -- 流派精要/道统真意
  local set_title = trim(m.set_title_text or '')
  if set_title ~= '' then
    blocks[#blocks + 1] = {
      title = set_title,
      body = table.concat(m.set_body_lines or {}, '\n'),
      style = 'highlight',
    }
  end

  return blocks
end

-- 从 gear_upgrades build_tip_payload 的 payload 转换为 detail_blocks
function M.build_gear_blocks(payload)
  local p = payload or {}
  local blocks = {}

  -- 当前属性（绿色）
  for _, block in ipairs(M.build_attr_blocks(p.attr_lines)) do
    blocks[#blocks + 1] = block
  end

  -- 词缀（列表）
  if #(p.affix_lines or {}) > 0 then
    blocks[#blocks + 1] = M.build_list_block('[当前词缀]', p.affix_lines)
  end

  -- 升级消耗
  if trim(p.cost_text or '') ~= '' then
    blocks[#blocks + 1] = { title = '[升级消耗]', body = p.cost_text, style = 'cost' }
  end

  return blocks
end

return M
