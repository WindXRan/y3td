-- Extract UI utility functions from runtime_hud.lua to hud_core.lua
-- Run from maps/EntryMap/script/

local file = io.open('ui/runtime_hud.lua', 'r')
local content = file:read('*a')
file:close()

-- 1. Remove is_ui_alive definition (it's now in hud_core)
content = content:gsub("local function is_ui_alive%(u%) return ui_root%.is_alive%(u%) end;\n", "")

-- 2. Remove forward declarations for core functions
local fwd_decls = "  local safe_ui_call\n  local set_ui_visible\n  local set_ui_text\n  local set_ui_text_color\n  local set_ui_font_size\n  local set_ui_text_alignment\n  local set_ui_image\n  local set_ui_image_color\n  local set_ui_size\n  local set_ui_anchor\n  local set_ui_pos\n  local set_ui_progress\n  local bind_ui_model_unit\n  local apply_ui_model_camera\n  local set_ui_pos_percent\n"
content = content:gsub(fwd_decls, "", 1)

-- 3. Replace get_player through format_percent_delta with hud_core.create call
-- Find the marker: "local function get_player()"
local marker = "  local function get_player() return get_player_fn and get_player_fn() or nil end;"
local core_block = [[
  -- UI 工具函数层 (from ui.hud.hud_core)
  local core = hud_core.create({
    y3 = y3,
    ui_root = ui_root,
    STATE = STATE,
    get_player_fn = get_player_fn,
    HERO_MODEL_FRAME_SIZE = HERO_MODEL_FRAME_SIZE,
    HERO_MODEL_CAMERA = HERO_MODEL_CAMERA,
  })
  local is_ui_alive = core.is_ui_alive
  local get_player = core.get_player
  local get_hud_state = core.get_hud_state
  local ensure_ui_preferences = core.ensure_ui_preferences
  local resolve_ui_node = core.resolve_ui_node
  local resolve_first_ui_node = core.resolve_first_ui_node
  local safe_ui_call = core.safe_ui_call
  local set_ui_visible = core.set_ui_visible
  local set_ui_text = core.set_ui_text
  local set_ui_text_color = core.set_ui_text_color
  local set_ui_font_size = core.set_ui_font_size
  local set_ui_text_alignment = core.set_ui_text_alignment
  local set_ui_image = core.set_ui_image
  local set_ui_image_color = core.set_ui_image_color
  local set_ui_size = core.set_ui_size
  local set_ui_anchor = core.set_ui_anchor
  local set_ui_pos = core.set_ui_pos
  local set_ui_progress = core.set_ui_progress
  local bind_ui_model_unit = core.bind_ui_model_unit
  local apply_ui_model_camera = core.apply_ui_model_camera
  local set_ui_pos_percent = core.set_ui_pos_percent
  local format_short_number = core.format_short_number
  local format_time_mmss = core.format_time_mmss
  local normalize_percent_value = core.normalize_percent_value
  local format_percent = core.format_percent
  local format_percent_delta = core.format_percent_delta
]]

-- Find end of "local function format_percent_delta" block
-- This function is followed by a blank line then the next function
local end_marker = "  end;\n\n  local function"

-- Find position of "local function get_player()"
local start_pos = content:find(marker, 1, true)
if not start_pos then
  print("ERROR: Could not find get_player definition")
  os.exit(1)
end

-- Find the end of format_percent_delta function
local search_start = start_pos
local end_marker_pos = nil
-- Search for the pattern: end of format_percent_delta followed by next function
local pattern = "return string%.format%([']%+%d%%['], math%.floor%(aN %+ 0%.5%)%) end;\n  end;\n\n  local function"
end_marker_pos = content:find(pattern, search_start, false)
if not end_marker_pos then
  -- Try simpler pattern
  pattern = "return string%.format%([']%+%d%%['], math%.floor%(aN %+ 0%.5%)%) end;\n  end;\n\n"
  end_marker_pos = content:find(pattern, search_start, false)
end

if end_marker_pos then
  -- Find the actual end of the block
  local block_end = end_marker_pos + #pattern - #"\n\n  local function" - 1
  if block_end < end_marker_pos then
    block_end = end_marker_pos + #pattern - 1
  end
  content = content:sub(1, start_pos - 1) .. core_block .. "\n" .. content:sub(block_end + 1)
  print("Replaced function definitions with hud_core.create call")
else
  print("ERROR: Could not find end of format_percent_delta")
  -- Fallback: try finding just the end of format_percent_delta
  local fallback = "return string%.format%([']%+%d%%['], math%.floor%(aN %+ 0%.5%)%) end;\n  end;\n\n  local"
  local fb_pos = content:find(fallback, search_start, false)
  if fb_pos then
    local block_end = fb_pos + #"return string.format('%d%%', math.floor(aN + 0.5)) end;\n  end;\n\n"
    content = content:sub(1, start_pos - 1) .. core_block .. "\n" .. content:sub(block_end + 1)
    print("Replaced using fallback pattern")
  else
    os.exit(1)
  end
end

file = io.open('ui/runtime_hud.lua', 'w')
file:write(content)
file:close()
print("Done! runtime_hud.lua updated to use hud_core.")
