-- Remove old function definitions from runtime_hud.lua
-- These are now provided by hud_core.create()
-- Run from maps/EntryMap/script/

local file = io.open('ui/runtime_hud.lua', 'r')
local content = file:read('*a')
file:close()

-- Find start: "local function ensure_ui_preferences__removed()"
-- Find end: the line before "local function format_signed_number"

local start_str = "  local function ensure_ui_preferences__removed()"
local end_str = "  local function format_signed_number(aI)"

local start_pos = content:find(start_str, 1, true)
local end_pos = content:find(end_str, 1, true)

if not start_pos then
  print("ERROR: start marker not found")
  print("Looking for alternative start...")
  -- Try finding by the first function that's still defined locally
  start_str = "  local function ensure_ui_preferences()"
  start_pos = content:find(start_str, 1, true)
end

if not start_pos then
  print("ERROR: Could not find start marker")
  os.exit(1)
end

if not end_pos then
  print("ERROR: end marker not found")
  os.exit(1)
end

-- Find the newline before start_pos
local line_start = start_pos
while line_start > 1 and content:sub(line_start - 1, line_start - 1) ~= '\n' do
  line_start = line_start - 1
end

-- Remove from line_start to just before end_pos
local before = content:sub(1, line_start - 1)
local after = content:sub(end_pos)
content = before .. after

-- Clean up extra blank lines (max 2 consecutive)
local changed = true
while changed do
  changed = false
  content, changed = content:gsub("\n\n\n\n", "\n\n\n")
end

file = io.open('ui/runtime_hud.lua', 'w')
file:write(content)
file:close()
print("Done! Removed old function definitions.")
