-- Wire hud_core.lua into runtime_hud.lua
-- Replaces old function definitions with hud_core.create() call
-- Run from maps/EntryMap/script/

local function read_lines(path)
  local f = io.open(path, 'r')
  local content = f:read('*a')
  f:close()
  local lines = {}
  for line in content:gmatch("([^\n]*)\n?") do
    if #lines > 0 or line ~= '' then
      lines[#lines + 1] = line
    end
  end
  -- Remove trailing empty line if present
  if #lines > 0 and lines[#lines] == '' then
    lines[#lines] = nil
  end
  return lines
end

local function write_lines(path, lines)
  local f = io.open(path, 'w')
  for i, line in ipairs(lines) do
    if i < #lines then
      f:write(line, '\n')
    else
      f:write(line)
    end
  end
  f:close()
end

local lines = read_lines('ui/runtime_hud.lua')

print('Original line count: ' .. #lines)

-- Verify key markers at expected positions
assert(lines[36]:find('local function is_ui_alive'), 'Line 36 mismatch: ' .. lines[36])
assert(lines[68]:find('local safe_ui_call'), 'Line 68 mismatch: ' .. lines[68])
assert(lines[92]:find('local function get_player()'), 'Line 92 mismatch: ' .. lines[92])
assert(lines[304]:find('local function format_percent_delta'), 'Line 304 mismatch: ' .. lines[304])
assert(lines[307]:find('end;'), 'Line 307 mismatch: ' .. lines[307])
assert(lines[309]:find('local function format_signed_number'), 'Line 309 mismatch: ' .. lines[309])

-- Build new lines array
local new_lines = {}

-- Phase 1: Add require after line 4 (the last data require)
for i = 1, 4 do
  new_lines[#new_lines + 1] = lines[i]
end
new_lines[#new_lines + 1] = "local hud_core = require 'ui.hud.hud_core'"
-- Continue copying lines 5-35 (after the require, before is_ui_alive)
for i = 5, 35 do
  new_lines[#new_lines + 1] = lines[i]
end

-- Skip line 36 (is_ui_alive definition)

-- Copy lines 37-67 (M.create params setup up to just before forward decls)
for i = 37, 67 do
  new_lines[#new_lines + 1] = lines[i]
end

-- Phase 2: Replace forward declarations (lines 68-82) with hud_core.create() block
local core_block = {
  '  -- UI 工具函数层 (from ui.hud.hud_core)',
  '  local core = hud_core.create({',
  '    y3 = y3,',
  '    ui_root = ui_root,',
  '    STATE = STATE,',
  '    get_player_fn = get_player_fn,',
  '    HERO_MODEL_FRAME_SIZE = HERO_MODEL_FRAME_SIZE,',
  '    HERO_MODEL_CAMERA = HERO_MODEL_CAMERA,',
  '  })',
  '  local is_ui_alive = core.is_ui_alive',
  '  local get_player = core.get_player',
  '  local get_hud_state = core.get_hud_state',
  '  local ensure_ui_preferences = core.ensure_ui_preferences',
  '  local resolve_ui_node = core.resolve_ui_node',
  '  local resolve_first_ui_node = core.resolve_first_ui_node',
  '  local safe_ui_call = core.safe_ui_call',
  '  local set_ui_visible = core.set_ui_visible',
  '  local set_ui_text = core.set_ui_text',
  '  local set_ui_text_color = core.set_ui_text_color',
  '  local set_ui_font_size = core.set_ui_font_size',
  '  local set_ui_text_alignment = core.set_ui_text_alignment',
  '  local set_ui_image = core.set_ui_image',
  '  local set_ui_image_color = core.set_ui_image_color',
  '  local set_ui_size = core.set_ui_size',
  '  local set_ui_anchor = core.set_ui_anchor',
  '  local set_ui_pos = core.set_ui_pos',
  '  local set_ui_progress = core.set_ui_progress',
  '  local bind_ui_model_unit = core.bind_ui_model_unit',
  '  local apply_ui_model_camera = core.apply_ui_model_camera',
  '  local set_ui_pos_percent = core.set_ui_pos_percent',
  '  local format_short_number = core.format_short_number',
  '  local format_time_mmss = core.format_time_mmss',
  '  local normalize_percent_value = core.normalize_percent_value',
  '  local format_percent = core.format_percent',
  '  local format_percent_delta = core.format_percent_delta',
}
for _, line in ipairs(core_block) do
  new_lines[#new_lines + 1] = line
end

-- Skip lines 68-91 (old forward decls + blank line)
-- Skip lines 92-307 (old function definitions from get_player through format_percent_delta)
-- But keep lines 83-91 (the non-core forward decls: toggle_big_cursor, etc.)
-- Wait, lines 68-82 are the core forward decls. Lines 83-91 are:
--   toggle_big_cursor, toggle_damage_text_visible, toggle_hit_effects_visible,
--   toggle_soft_pause, toggle_runtime_attr_panel, ensure_hud, refresh_hud,
--   set_hud_visible, show_runtime_tip_panel
-- These should be KEPT - they're HUD-specific, not in hud_core.

-- Actually let me re-check. Let me read lines 83-91:
-- 83: local toggle_big_cursor
-- 84: local toggle_damage_text_visible
-- 85: local toggle_hit_effects_visible
-- 86: local toggle_soft_pause
-- 87: local toggle_runtime_attr_panel
-- 88: local ensure_hud
-- 89: local refresh_hud
-- 90: local set_hud_visible
-- 91: local show_runtime_tip_panel

-- These are hud_main-specific forward decls, NOT in hud_core. Keep them.
for i = 83, 91 do
  new_lines[#new_lines + 1] = lines[i]
end

-- Skip line 92 (get_player) through line 307 (end of format_percent_delta)
-- Line 308 is the blank line between format_percent_delta and format_signed_number

-- Continue from line 308 (blank line) to end
for i = 308, #lines do
  new_lines[#new_lines + 1] = lines[i]
end

-- Clean up: remove excessive blank lines (more than 2 consecutive)
local cleaned = {}
local blank_count = 0
for _, line in ipairs(new_lines) do
  if line == '' then
    blank_count = blank_count + 1
    if blank_count <= 2 then
      cleaned[#cleaned + 1] = line
    end
  else
    blank_count = 0
    cleaned[#cleaned + 1] = line
  end
end

write_lines('ui/runtime_hud.lua', cleaned)
print('Done! New line count: ' .. #cleaned)
