local M = {}

local function seq(...)
  return { ... }
end

local COLOR_RULES = {
  {
    color = 'green',
    priority = 1,
    keywords = {
      seq(0x81EA, 0x9002, 0x5E94, 0x4F24, 0x5BB3), -- 自适应伤害
      seq(0x7269, 0x7406, 0x4F24, 0x5BB3), -- 物理伤害
      seq(0x9B54, 0x6CD5, 0x4F24, 0x5BB3), -- 魔法伤害
      seq(0x6240, 0x6709, 0x4F24, 0x5BB3), -- 所有伤害
      seq(0x4F24, 0x5BB3, 0x51CF, 0x514D), -- 伤害减免
      seq(0x653B, 0x51FB, 0x901F, 0x5EA6), -- 攻击速度
      seq(0x653B, 0x51FB, 0x529B), -- 攻击力
      seq(0x751F, 0x547D, 0x503C), -- 生命值
      seq(0x6280, 0x80FD, 0x6025, 0x901F), -- 技能急速
      seq(0x529B, 0x91CF), -- 力量
      seq(0x654F, 0x6377), -- 敏捷
      seq(0x667A, 0x529B), -- 智力
    },
  },
  {
    color = 'cyan',
    priority = 2,
    patterns = {
      '%d+%%',
      '%d+',
    },
  },
}

local function sort_matches(a, b)
  if a.start_index ~= b.start_index then
    return a.start_index < b.start_index
  end
  if a.priority ~= b.priority then
    return a.priority < b.priority
  end
  return (a.end_index - a.start_index) > (b.end_index - b.start_index)
end

local function utf8_chars_with_spans(text)
  local chars = {}
  local positions = {}
  for start_byte, codepoint in utf8.codes(text or '') do
    local char = utf8.char(codepoint)
    chars[#chars + 1] = char
    positions[#positions + 1] = {
      codepoint = codepoint,
      start_byte = start_byte,
      end_byte = start_byte + #char - 1,
    }
  end
  return chars, positions
end

local function collect_keyword_matches(line)
  local matches = {}
  local _, positions = utf8_chars_with_spans(line)

  for _, rule in ipairs(COLOR_RULES) do
    for _, keyword in ipairs(rule.keywords or {}) do
      local keyword_len = #keyword
      if keyword_len > 0 and #positions >= keyword_len then
        for start_index = 1, (#positions - keyword_len + 1) do
          local matched = true
          for offset = 1, keyword_len do
            if positions[start_index + offset - 1].codepoint ~= keyword[offset] then
              matched = false
              break
            end
          end
          if matched then
            local start_byte = positions[start_index].start_byte
            local end_byte = positions[start_index + keyword_len - 1].end_byte
            matches[#matches + 1] = {
              start_index = start_byte,
              end_index = end_byte,
              color = rule.color,
              priority = rule.priority or 99,
            }
          end
        end
      end
    end
  end

  return matches
end

local function collect_pattern_matches(line)
  local matches = {}
  for _, rule in ipairs(COLOR_RULES) do
    for _, pattern in ipairs(rule.patterns or {}) do
      local search_start = 1
      while search_start <= #line do
        local start_index, end_index = string.find(line, pattern, search_start)
        if not start_index then
          break
        end
        matches[#matches + 1] = {
          start_index = start_index,
          end_index = end_index,
          color = rule.color,
          priority = rule.priority or 99,
        }
        search_start = end_index + 1
      end
    end
  end
  return matches
end

local function collect_matches(line)
  local matches = {}
  for _, match in ipairs(collect_keyword_matches(line)) do
    matches[#matches + 1] = match
  end
  for _, match in ipairs(collect_pattern_matches(line)) do
    matches[#matches + 1] = match
  end
  table.sort(matches, sort_matches)
  return matches
end

local function build_line_segments(line, default_color)
  local matches = collect_matches(line)
  local segments = {}
  local cursor = 1

  for _, match in ipairs(matches) do
    if match.start_index < cursor then
      goto continue
    end

    if match.start_index > cursor then
      segments[#segments + 1] = {
        text = string.sub(line, cursor, match.start_index - 1),
        color = default_color,
      }
    end

    segments[#segments + 1] = {
      text = string.sub(line, match.start_index, match.end_index),
      color = match.color,
    }
    cursor = match.end_index + 1

    ::continue::
  end

  if cursor <= #line then
    segments[#segments + 1] = {
      text = string.sub(line, cursor),
      color = default_color,
    }
  end

  if #segments == 0 then
    segments[1] = {
      text = line,
      color = default_color,
    }
  end

  return segments
end

function M.build_highlight_lines(text, default_color, mode)
  local lines = {}
  if type(text) ~= 'string' or text == '' then
    return lines
  end

  for line in string.gmatch(text .. '\n', '(.-)\n') do
    if mode == 'auto' then
      lines[#lines + 1] = build_line_segments(line, default_color or 'dim')
    else
      lines[#lines + 1] = {
        {
          text = line,
          color = default_color or 'dim',
        },
      }
    end
  end
  return lines
end

function M.estimate_text_width(text, font_size)
  local width = 0
  local size = font_size or 18
  for _, codepoint in utf8.codes(text or '') do
    if codepoint <= 0x7F then
      width = width + size * 0.55
    else
      width = width + size * 0.95
    end
  end
  return math.floor(width + 0.5)
end

return M
