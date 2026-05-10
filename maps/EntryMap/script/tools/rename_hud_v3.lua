-- Phase 3 cleanup: fix residual renamed variable usages in runtime_hud.lua

local file = io.open('ui/runtime_hud.lua', 'r')
local content = file:read('*a')
file:close()

local count = 0

local function esc(s)
  return s:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
end

local function replace(from, to)
  local n = 0
  content, n = content:gsub(esc(from), to)
  count = count + n
end

-- ===== 1. Global: word-bounded w. -> STATE. =====
-- w is always a variable (STATE), never a table key
content, _ = content:gsub('(%f[%a])w%.', 'STATE.')

-- ===== 2. Global: word-bounded y. -> y3. =====
-- y is the y3 engine variable. HERO_MODEL_FRAME_SIZE.y has no dot after y, so safe.
content, _ = content:gsub('(%f[%a])y%.', 'y3.')

-- ===== 3. Standalone y in function arguments =====
replace("ui_root.resolve_ui(y,", "ui_root.resolve_ui(y3,")
replace("ui_root.resolve_first_ui(y,", "ui_root.resolve_first_ui(y3,")
replace("get_overlay_parent(y,", "get_overlay_parent(y3,")

-- ===== 4. Standalone y in boolean expressions (after y. -> y3. replacement above) =====
replace(" and y and y3.", " and y3 and y3.")
replace(" or y or y3.", " or y3 or y3.")
replace("not y or not y3.", "not y3 or not y3.")
replace("not y or not y and not y3.", "not y3 or not y3 and not y3.")

-- ===== 5. Specific line patterns =====
replace("if not player or not y or not y3.ui_prefab", "if not player or not y3 or not y3.ui_prefab")
replace("not y or not y3.ltimer", "not y3 or not y3.ltimer")

-- ===== 6. Function body variable fixes =====
-- set_ui_font_size uses font_size not ag
replace("if ag then safe_ui_call(u, 'set_font_size', ag)", "if font_size then safe_ui_call(u, 'set_font_size', font_size)")

-- set_ui_text_alignment uses h_align, v_align not ai, aj
replace("if ai and aj then safe_ui_call(u, 'set_text_alignment', ai, aj)", "if h_align and v_align then safe_ui_call(u, 'set_text_alignment', h_align, v_align)")

-- set_ui_image uses image_id not al
replace("if image_id ~= nil then safe_ui_call(u, 'set_image', al)", "if image_id ~= nil then safe_ui_call(u, 'set_image', image_id)")

-- set_ui_size uses width, height not ao, ap
replace("if width and height then safe_ui_call(u, 'set_ui_size', ao, ap)", "if width and height then safe_ui_call(u, 'set_ui_size', width, height)")

-- resolve_first_ui_node: a4 -> name_list, a5 -> cache_key
replace("table.concat(a4 or {}, '|')", "table.concat(name_list or {}, '|')")
replace("resolve_first_ui(y3, player, a4)", "resolve_first_ui(y3, player, name_list)")

-- build_hero_form_skill_entry: a0 -> form_skill_runtime
replace("tonumber(a0.cooldowns and a0.cooldowns[bX.id])", "tonumber(form_skill_runtime.cooldowns and form_skill_runtime.cooldowns[bX.id])")
replace("tonumber(a0.counters and a0.counters[bX.id])", "tonumber(form_skill_runtime.counters and form_skill_runtime.counters[bX.id])")

-- get_player_name: a2 -> player
replace("if a2 and a2.get_name then", "if player and player.get_name then")
replace("local b1 = a2:get_name()", "local b1 = player:get_name()")

-- build_hero_form_skill_entry: w.hero_form_skills_system already handled by global w. -> STATE.

file = io.open('ui/runtime_hud.lua', 'w')
file:write(content)
file:close()
print(string.format('Phase 3 done! %d pattern groups processed.', count))
