local M = {}

local DEFAULT_DURATION = 8
local DEFAULT_MAX_VISIBLE = 4
local DEFAULT_MAX_HISTORY = 12

local function normalize_limit(value, fallback)
  local number = tonumber(value) or fallback
  number = math.floor(number + 0.5)
  if number < 1 then
    return fallback
  end
  return number
end

local function normalize_duration(value, fallback)
  local number = tonumber(value) or fallback
  if number < 0.5 then
    return 0.5
  end
  return number
end

local function normalize_text(text)
  local value = tostring(text or '')
  value = value:gsub('^%s+', ''):gsub('%s+$', '')
  return value
end

local function purge_expired(runtime, now)
  local current_time = tonumber(now) or 0
  local next_entries = {}
  for _, entry in ipairs(runtime.entries or {}) do
    if (entry.expires_at or 0) > current_time then
      next_entries[#next_entries + 1] = entry
    end
  end
  runtime.entries = next_entries
end

function M.create_runtime(options)
  local opts = options or {}
  return {
    entries = {},
    next_id = 1,
    default_duration = normalize_duration(opts.default_duration, DEFAULT_DURATION),
    max_visible = normalize_limit(opts.max_visible, DEFAULT_MAX_VISIBLE),
    max_history = normalize_limit(opts.max_history, DEFAULT_MAX_HISTORY),
  }
end

function M.push_event(runtime, text, options)
  if not runtime then
    return nil
  end

  local content = normalize_text(text)
  if content == '' then
    return nil
  end

  local opts = options or {}
  local now = tonumber(opts.now) or 0
  local entry = {
    id = runtime.next_id or 1,
    text = content,
    style = tostring(opts.style or 'neutral'),
    created_at = now,
    expires_at = now + normalize_duration(opts.duration, runtime.default_duration or DEFAULT_DURATION),
  }

  runtime.next_id = entry.id + 1
  runtime.entries[#runtime.entries + 1] = entry

  local max_history = normalize_limit(runtime.max_history, DEFAULT_MAX_HISTORY)
  while #runtime.entries > max_history do
    table.remove(runtime.entries, 1)
  end

  purge_expired(runtime, now)
  return entry
end

function M.update(runtime, now)
  if not runtime then
    return
  end
  purge_expired(runtime, now)
end

function M.get_visible_entries(runtime, now, max_visible)
  if not runtime then
    return {}
  end

  purge_expired(runtime, now)

  local limit = normalize_limit(max_visible or runtime.max_visible, DEFAULT_MAX_VISIBLE)
  local entries = runtime.entries or {}
  local start_index = math.max(1, #entries - limit + 1)
  local result = {}
  for index = start_index, #entries do
    local entry = entries[index]
    result[#result + 1] = {
      id = entry.id,
      text = entry.text,
      style = entry.style,
      created_at = entry.created_at,
      expires_at = entry.expires_at,
    }
  end
  return result
end

return M
