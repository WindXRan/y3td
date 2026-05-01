local EditorJsonTable = require 'data.tables.editor_json_table'

local M = {}

local function trim(text)
  return tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalize_quality(value)
  local raw = trim(value)
  if raw == '' then
    return nil
  end
  local upper = string.upper(raw)
  if upper == 'N' or upper == 'R' or upper == 'SR' or upper == 'SSR' or upper == 'UR' then
    return upper
  end
  return ({
    common = 'N',
    excellent = 'R',
    rare = 'SR',
    epic = 'SSR',
    legendary = 'UR',
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[string.lower(raw)] or ({
    ['普通'] = 'N',
    ['优秀'] = 'R',
    ['稀有'] = 'SR',
    ['史诗'] = 'SSR',
    ['传说'] = 'UR',
  })[raw]
end

local image_by_quality = {}

for _, row in ipairs(EditorJsonTable.read_rows('quality_image_table')) do
  local quality = normalize_quality(row['品质'] or row.quality)
  local image = tonumber(row['框图'] or row.frame_image or row.image)
  local suit = trim(row['样式套装'] or row.style_set or '1')
  if quality and image and (suit == '' or suit == '1') then
    image_by_quality[quality] = image
    image_by_quality[string.lower(quality)] = image
  end
end

M.image_by_quality = image_by_quality

function M.get_frame_image(quality)
  local normalized = normalize_quality(quality)
  return normalized and image_by_quality[normalized] or nil
end

return M

