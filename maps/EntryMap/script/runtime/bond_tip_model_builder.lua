local M = {}

local function trim_inline_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  local value = text:gsub('\r', '')
  value = value:gsub('^%s+', '')
  value = value:gsub('%s+$', '')
  return value
end

local function sanitize_bond_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  if string.match(text, "^b'.*\\\\x") or string.match(text, '^b".*\\\\x') then
    return ''
  end
  return text
end

local function strip_choice_prefix(text)
  local trimmed = trim_inline_text(text)
  trimmed = trimmed:gsub('^当前：', '')
  trimmed = trimmed:gsub('^后继：', '')
  trimmed = trimmed:gsub('^进阶链路：', '')
  trimmed = trimmed:gsub('^终局方向：', '')
  trimmed = trimmed:gsub('^终阶节点：', '')
  return trim_inline_text(trimmed)
end

local function trim_choice_trailing_punctuation(text)
  local value = trim_inline_text(text)
  local changed = true
  while changed and value ~= '' do
    changed = false
    if string.sub(value, -3) == '。' or string.sub(value, -3) == '；' or string.sub(value, -3) == '，' then
      value = string.sub(value, 1, -4)
      changed = true
    elseif string.sub(value, -1) == ';'
        or string.sub(value, -1) == ','
        or string.sub(value, -1) == ' '
        or string.sub(value, -1) == '\t'
        or string.sub(value, -1) == '\n'
        or string.sub(value, -1) == '\r' then
      value = string.sub(value, 1, -2)
      changed = true
    end
  end
  return value
end

local function is_transition_advanced_text(text)
  local value = trim_choice_trailing_punctuation(text)
  if value == '' then
    return false
  end

  if string.find(value, '已凑齐，开启后续分支', 1, true)
      or string.find(value, '已凑齐,开启后续分支', 1, true)
      or string.find(value, '已凑齐，解锁后续分支', 1, true)
      or string.find(value, '已凑齐,解锁后续分支', 1, true)
      or (string.find(value, '已圆满', 1, true) and string.find(value, '后续流派', 1, true)) then
    return true
  end

  if string.find(value, '我要玩', 1, true)
      and string.find(value, '卡池中加入', 1, true) then
    return true
  end

  if string.find(value, '机缘已现', 1, true)
      and (string.find(value, '抽卡池加入', 1, true) or string.find(value, '卡池中加入', 1, true)) then
    return true
  end

  return false
end

local function escape_lua_pattern(text)
  return tostring(text or ''):gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
end

local function split_title_progress(text)
  local raw = trim_inline_text(text)
  if raw == '' then
    return '', ''
  end
  local title, progress = raw:match('^(.-)%s*(%b())$')
  if title and progress then
    return trim_inline_text(title), trim_inline_text(progress)
  end
  return raw, ''
end

local function build_display_title_candidates(...)
  local seen = {}
  local titles = {}
  for index = 1, select('#', ...) do
    local value = select(index, ...)
    local title = trim_inline_text(value)
    if title ~= '' and not seen[title] then
      seen[title] = true
      titles[#titles + 1] = title
    end
  end
  return titles
end

local function strip_repeated_display_title(text, title_candidates)
  local value = trim_inline_text(text)
  if value == '' then
    return value
  end

  for _, title in ipairs(title_candidates or {}) do
    local escaped_title = escape_lua_pattern(title)
    local stripped = value:gsub('^' .. escaped_title .. '%s*：%s*', '', 1)
    if stripped == value then
      stripped = value:gsub('^' .. escaped_title .. '%s*:%s*', '', 1)
    end
    if stripped ~= value then
      return trim_inline_text(stripped)
    end
  end

  return value
end

local function split_non_empty_lines(text)
  local normalized = strip_choice_prefix(sanitize_bond_text(text))
  local lines = {}
  if normalized == '' then
    return lines
  end

  normalized = normalized:gsub('\r', '')
  for line in normalized:gmatch('[^\n]+') do
    local trimmed = trim_inline_text(line)
    if trimmed ~= '' then
      lines[#lines + 1] = trimmed
    end
  end
  return lines
end

local function split_compound_bonus_segments(text)
  local value = trim_inline_text(text)
  if value == '' then
    return {}
  end

  local normalized = value
  normalized = normalized:gsub('，', '\n')
  normalized = normalized:gsub(',', '\n')
  normalized = normalized:gsub('；', '\n')
  normalized = normalized:gsub(';', '\n')

  local segments = {}
  for segment in normalized:gmatch('[^\n]+') do
    local trimmed = trim_choice_trailing_punctuation(segment)
    if trimmed ~= '' then
      segments[#segments + 1] = trimmed
    end
  end

  if #segments == 0 then
    segments[1] = trim_choice_trailing_punctuation(value)
  end
  return segments
end

local function normalize_line_list(lines)
  local result = {}
  for _, line in ipairs(lines or {}) do
    local value = trim_inline_text(line)
    if value ~= '' then
      result[#result + 1] = value
    end
  end
  return result
end

local function take_bonus_lines(text, title_candidates, max_lines)
  local result = {}
  for _, line in ipairs(split_non_empty_lines(text)) do
    local normalized_line = strip_repeated_display_title(line, title_candidates)
    for _, segment in ipairs(split_compound_bonus_segments(normalized_line)) do
      result[#result + 1] = segment
      if max_lines and #result >= max_lines then
        return result
      end
    end
  end
  return result
end

local function choose_first_non_empty(...)
  for index = 1, select('#', ...) do
    local value = select(index, ...)
    local trimmed = trim_inline_text(value)
    if trimmed ~= '' then
      return trimmed
    end
  end
  return ''
end

function M.build(fields)
  fields = fields or {}

  local title_set_name, title_progress = split_title_progress(fields.title_text or '')
  local set_name_text = choose_first_non_empty(fields.set_name_text, title_set_name, fields.display_name)
  local progress_text = choose_first_non_empty(fields.progress_text, title_progress)
  local item_name_text = choose_first_non_empty(fields.item_name_text, fields.display_name, set_name_text)
  local quality_text = choose_first_non_empty(fields.quality_text)
  local effect_index_text = choose_first_non_empty(fields.effect_index_text)

  local title_candidates = build_display_title_candidates(
    item_name_text,
    fields.display_name,
    set_name_text
  )

  local bonus_lines = normalize_line_list(fields.bonus_lines)
  if #bonus_lines == 0 then
    bonus_lines = take_bonus_lines(fields.bonus_text or fields.current_text or '', title_candidates, 4)
  end

  local effect_body_text = choose_first_non_empty(fields.effect_body_text)
  if is_transition_advanced_text(effect_body_text) then
    effect_body_text = ''
  end

  local set_body_lines = normalize_line_list(fields.set_body_lines)
  if #set_body_lines == 0 then
    set_body_lines = split_non_empty_lines(fields.effect_text or '')
  end
  if #set_body_lines == 0 then
    local advanced_text = choose_first_non_empty(fields.advanced_text)
    if advanced_text ~= '' and not is_transition_advanced_text(advanced_text) then
      set_body_lines = split_non_empty_lines(advanced_text)
    end
  end

  local set_title_text = choose_first_non_empty(fields.set_title_text)
  if set_title_text == '' and #set_body_lines > 0 then
    set_title_text = '流派精要：'
  end

  return {
    quality_text = quality_text,
    set_name_text = set_name_text,
    progress_text = progress_text,
    icon_res = fields.icon_res,
    item_name_text = item_name_text,
    bonus_lines = bonus_lines,
    effect_index_text = effect_index_text,
    effect_body_text = effect_body_text,
    set_title_text = set_title_text,
    set_body_lines = set_body_lines,
  }
end

function M.build_from_choice(choice, overrides)
  choice = choice or {}
  overrides = overrides or {}

  local title_set_name, title_progress = split_title_progress(choice.title_text or '')
  local set_name_text = choose_first_non_empty(overrides.set_name_text, title_set_name, choice.display_name)
  local progress_text = choose_first_non_empty(overrides.progress_text, title_progress)
  local item_name_text = choose_first_non_empty(overrides.item_name_text, choice.subtitle_text, choice.display_name, set_name_text)
  local quality_text = choose_first_non_empty(overrides.quality_text, choice.quality_text)
  local icon_res = overrides.icon_res or choice.ui_icon or choice.icon_res
  local effect_index_text = choose_first_non_empty(overrides.effect_index_text, choice.effect_index_text)
  local effect_body_text = choose_first_non_empty(overrides.effect_body_text, choice.effect_body_text)

  if is_transition_advanced_text(effect_body_text) then
    effect_body_text = ''
  end

  local title_candidates = build_display_title_candidates(
    choice.subtitle_text,
    choice.display_name,
    item_name_text,
    set_name_text
  )

  local bonus_lines = take_bonus_lines(
    choice.value_text or choice.current_text or choice.desc_text or '',
    title_candidates,
    4
  )

  local explicit_effect_title = choose_first_non_empty(choice.effect_title)
  local explicit_effect_text = choose_first_non_empty(choice.effect_text)
  local advanced_text = choose_first_non_empty(choice.advanced_text)
  local set_title_text = ''
  local set_body_lines = {}

  if explicit_effect_text ~= '' then
    set_title_text = explicit_effect_title ~= '' and explicit_effect_title or '流派精要：'
    set_body_lines = split_non_empty_lines(explicit_effect_text)
  elseif advanced_text ~= '' and not is_transition_advanced_text(advanced_text) then
    set_title_text = explicit_effect_title ~= '' and explicit_effect_title or '流派精要：'
    set_body_lines = split_non_empty_lines(advanced_text)
  end

  return {
    quality_text = quality_text,
    set_name_text = set_name_text,
    progress_text = progress_text,
    icon_res = icon_res,
    item_name_text = item_name_text,
    bonus_lines = bonus_lines,
    effect_index_text = effect_index_text,
    effect_body_text = effect_body_text,
    set_title_text = set_title_text,
    set_body_lines = set_body_lines,
  }
end

-- 生成统一 detail_blocks，供动态 tip 面板等场景直接使用
function M.build_blocks(fields)
  local TipBlockStyle = require 'data.tables.tip_block_style'
  return TipBlockStyle.build_bond_blocks(M.build(fields))
end

return M
