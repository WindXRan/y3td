local M = {}

local function read_audio_rows()
  local ok, CsvLoader = pcall(require, 'data.csv_loader')
  if not ok or not CsvLoader or not CsvLoader.read_rows then
    return {}
  end
  local rows_ok, rows = pcall(CsvLoader.read_rows, 'data_csv/audio.csv')
  if rows_ok and type(rows) == 'table' then
    return rows
  end
  return {}
end

local function load_audio_config()
  local config = {}
  for _, row in ipairs(read_audio_rows()) do
    if row.key and row.key ~= '' and row.audio_id and row.audio_id ~= '' then
      config[row.key] = tonumber(row.audio_id)
    end
  end
  return config
end

local function merge_defaults(config)
  local defaults = {
    bgm_loop = 108960,
    battle = 108960,
    boss = 108960,
    ui_click = 108960,
    wave_start = 108960,
    enemy_death = 134278073,
  }
  for key, value in pairs(defaults) do
    if type(config[key]) ~= 'number' then
      config[key] = value
    end
  end
  return config
end

M.AUDIO_IDS = merge_defaults(load_audio_config())

M.AUDIO_USAGE = {
  [108960] = 'default audio resource',
  [134278073] = 'enemy death sound object',
}

return M
