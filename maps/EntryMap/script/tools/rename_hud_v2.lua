-- Safe variable rename for runtime_hud.lua
-- All patterns are literal strings (escaped for Lua gsub)

local file = io.open('ui/runtime_hud.lua', 'r')
local content = file:read('*a')
file:close()

local count = 0

-- Escape Lua pattern magic characters
local function esc(s)
  return s:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
end

local function replace(from, to)
  local n = 0
  content, n = content:gsub(esc(from), to)
  count = count + n
  if n > 0 then
    -- print(string.format('  %s -> %s  (%d)', from, to, n))
  end
end

-- ===== LINES 1-35: Module-level =====

replace("local a = require 'ui.ui_root'", "local ui_root = require 'ui.ui_root'")
replace('a.is_alive(', 'ui_root.is_alive(')
replace('a.resolve_ui(', 'ui_root.resolve_ui(')
replace('a.resolve_first_ui(', 'ui_root.resolve_first_ui(')
replace('a.resolve_child(', 'ui_root.resolve_child(')
replace('a.get_overlay_parent(', 'ui_root.get_overlay_parent(')

replace("local b = require 'data.tables.outgame.hero_evolutions'",
  "local hero_evolutions = require 'data.tables.outgame.hero_evolutions'")
replace("local c = (require 'data.game_tables').hero_roster",
  "local game_tables_hero_roster = (require 'data.game_tables').hero_roster")
replace("local d = require 'data.tables.hero.hero_form_skills'",
  "local hero_form_skills = require 'data.tables.hero.hero_form_skills'")

replace("local e = {}", "local M = {}")
replace("function e.create(v)", "function M.create(params)")

replace("local q = b.by_id or {}", "local evolutions_by_id = hero_evolutions.by_id or {}")
replace("local r = c.by_unit_id or {}", "local roster_by_unit_id = game_tables_hero_roster.by_unit_id or {}")
replace("local s = d.by_hero_id or {}", "local form_skills_lookup = hero_form_skills.by_hero_id or {}")

-- Constants
replace("\nlocal f = 8;", "\nlocal DEFAULT_TIP_DURATION = 8;")
replace("\nlocal g = 8;", "\nlocal BOND_CARD_SLOT_COUNT = 8;")
replace("\nlocal h = 5;", "\nlocal EVOLUTION_SLOT_COUNT = 5;")
replace("\nlocal i = 5;", "\nlocal BUFF_SLOT_COUNT = 5;")

replace("local j = { 'battle_power_row'", "local ATTR_ROW_NAMES = { 'battle_power_row'")

replace("local k = {\n  width = 108,", "local HERO_MODEL_FRAME_SIZE = {\n  width = 108,")
replace("local l = {\n  focus = { 0, 0, 88 },", "local HERO_MODEL_CAMERA = {\n  focus = { 0, 0, 88 },")

replace("\nlocal m = 260;", "\nlocal EXP_BAR_MAX_WIDTH = 260;")
replace("\nlocal n = 12;", "\nlocal EXP_BAR_HEIGHT = 12;")
replace("\nlocal o = 122;", "\nlocal EXP_BAR_X_OFFSET = 122;")

replace("local p = {\n  common = '普通',", "local RARITY_NAME_MAP = {\n  common = '普通',")

-- ===== Module-level USAGE replacements =====

replace("\nreturn e\n", "\nreturn M\n")

replace("d0 or f)", "d0 or DEFAULT_TIP_DURATION)")
replace("1, g do", "1, BOND_CARD_SLOT_COUNT do")
replace(" or h)", " or EVOLUTION_SLOT_COUNT)")
replace("get_evolution_slot_entries(h)", "get_evolution_slot_entries(EVOLUTION_SLOT_COUNT)")
replace("1, h do", "1, EVOLUTION_SLOT_COUNT do")
replace("R and R(i)", "R and R(BUFF_SLOT_COUNT)")
replace("R(i)", "R(BUFF_SLOT_COUNT)")

replace("= j[cH]", "= ATTR_ROW_NAMES[row_index]")
replace("k.width", "HERO_MODEL_FRAME_SIZE.width")
replace("k.height", "HERO_MODEL_FRAME_SIZE.height")
replace("k.x", "HERO_MODEL_FRAME_SIZE.x")
replace("k.y", "HERO_MODEL_FRAME_SIZE.y")
replace(", l)", ", HERO_MODEL_CAMERA)")
replace("* m ", "* EXP_BAR_MAX_WIDTH ")
replace("floor(m *", "floor(EXP_BAR_MAX_WIDTH *")
replace(", n)", ", EXP_BAR_HEIGHT)")
replace("= o +", "= EXP_BAR_X_OFFSET +")
replace("return p[c8]", "return RARITY_NAME_MAP[c8]")
replace("q[cq]", "evolutions_by_id[cq]")
replace("r[cc]", "roster_by_unit_id[cc]")
replace("return s[c4.id]", "return form_skills_lookup[c4.id]")

-- ===== M.create internal vars =====

replace("v.STATE", "params.STATE")
replace("v.CONFIG", "params.CONFIG")
replace("v.y3", "params.y3")
replace("v.attack_skill_slot_count", "params.attack_skill_slot_count")
replace("v.get_player", "params.get_player")
replace("v.hero_attr_system", "params.hero_attr_system")
replace("v.message", "params.message")
replace("v.try_bond_draw", "params.try_bond_draw")
replace("v.try_evolution_entry", "params.try_evolution_entry")
replace("v.try_start_challenge", "params.try_start_challenge")
replace("v.open_save_panel", "params.open_save_panel")
replace("v.try_upgrade_growth_weapon", "params.try_upgrade_growth_weapon")
replace("v.show_runtime_status", "params.show_runtime_status")
replace("v.build_runtime_attr_dialog_chunks", "params.build_runtime_attr_dialog_chunks")
replace("v.build_growth_weapon_tip_payload", "params.build_growth_weapon_tip_payload")
replace("v.build_bond_slot_tip_payload", "params.build_bond_slot_tip_payload")
replace("v.bond_draw_cost", "params.bond_draw_cost")
replace("v.get_bond_slot_icon", "params.get_bond_slot_icon")
replace("v.get_bottom_status_effect_entries", "params.get_bottom_status_effect_entries")
replace("v.play_ui_click", "params.play_ui_click")
replace("v.toggle_gm_panel", "params.toggle_gm_panel")
replace("v.use_attr_diamond", "params.use_attr_diamond")
replace("v.get_attr_choice_runtime", "params.get_attr_choice_runtime")
replace("v.apply_attr_choice", "params.apply_attr_choice")

replace("local w = params.STATE;", "local STATE = params.STATE;")
replace("w.runtime_hud", "STATE.runtime_hud")
replace("w.ui_preferences", "STATE.ui_preferences")
replace("w.evolution_runtime", "STATE.evolution_runtime")
replace("w.attack_skill_state", "STATE.attack_skill_state")
replace("w.hero_form_skill_runtime", "STATE.hero_form_skill_runtime")
replace("w.battle_event_feed", "STATE.battle_event_feed")
replace("w.runtime_elapsed", "STATE.runtime_elapsed")
replace("w.gear_state", "STATE.gear_state")
replace("w.bond_runtime", "STATE.bond_runtime")
replace("w.attr_choice_runtime", "STATE.attr_choice_runtime")

replace("local x = params.CONFIG or {}", "local CONFIG = params.CONFIG or {}")
replace("x.bond_skill_runtime_tuning", "CONFIG.bond_skill_runtime_tuning")
replace("x.skill_runtime_tuning", "CONFIG.skill_runtime_tuning")
replace("x.outgame_attr_bonus_config", "CONFIG.outgame_attr_bonus_config")
replace("x.outgame_top_entry_list", "CONFIG.outgame_top_entry_list")

replace("local y = params.y3;", "local y3 = params.y3;")

replace("local z = math.max(1, tonumber(params.attack_skill_slot_count) or 5)",
  "local skill_slot_count = math.max(1, tonumber(params.attack_skill_slot_count) or 5)")
replace("bL > z then", "bL > skill_slot_count then")

replace("local A = params.get_player;", "local get_player_fn = params.get_player;")
replace("return A and A()", "return get_player_fn and get_player_fn()")

replace("local B = params.hero_attr_system;", "local hero_attr_system_ref = params.hero_attr_system;")

replace("local C = params.message or function() end;",
  "local message_fn = params.message or function() end;")

replace("local H = nil;", "local mainline_task_system = nil;")

-- E G I J K L N O Q R S → descriptive names
replace("local E = params.try_bond_draw;", "local try_bond_draw = params.try_bond_draw;")
replace("local G = params.try_evolution_entry;", "local try_evolution_entry = params.try_evolution_entry;")
replace("local I = params.try_start_challenge;", "local try_start_challenge = params.try_start_challenge;")
replace("local J = params.open_save_panel;", "local open_save_panel = params.open_save_panel;")
replace("local K = params.try_upgrade_growth_weapon;", "local try_upgrade_growth_weapon = params.try_upgrade_growth_weapon;")
replace("local L = params.show_runtime_status;", "local show_runtime_status = params.show_runtime_status;")
replace("local M = params.build_runtime_attr_dialog_chunks;", "local build_runtime_attr_dialog_chunks = params.build_runtime_attr_dialog_chunks;")
replace("local N = params.build_growth_weapon_tip_payload;", "local build_growth_weapon_tip_payload = params.build_growth_weapon_tip_payload;")
replace("local O = params.build_bond_slot_tip_payload;", "local build_bond_slot_tip_payload = params.build_bond_slot_tip_payload;")

replace("local P = math.max(0, tonumber(params.bond_draw_cost) or 100)",
  "local bond_draw_cost = math.max(0, tonumber(params.bond_draw_cost) or 100)")

replace("local Q = params.get_bond_slot_icon;", "local get_bond_slot_icon_fn = params.get_bond_slot_icon;")
replace("local R = params.get_bottom_status_effect_entries;", "local get_status_effects_fn = params.get_bottom_status_effect_entries;")
replace("local S = params.play_ui_click;", "local play_ui_click_fn = params.play_ui_click;")

replace("local X = STATE.ui_preferences;", "local ui_prefs = STATE.ui_preferences;")

-- ===== Deep function-local renames =====

replace("local a0 = get_hud_state()", "local hud_state = get_hud_state()")
replace("local a0 = get_evolution_runtime()", "local evo_runtime = get_evolution_runtime()")
replace("local a0 = STATE.evolution_runtime;", "local evo_runtime = STATE.evolution_runtime;")
replace("local a0 = STATE.hero_form_skill_runtime", "local form_skill_runtime = STATE.hero_form_skill_runtime")
replace("return a0 and hud_state", "return evo_runtime and evo_runtime")
replace("return a0 and STATE", "return evo_runtime and STATE")
replace("a0.ordered_evolution_ids", "evo_runtime.ordered_evolution_ids")
replace("a0.awaiting_choice", "evo_runtime.awaiting_choice")
replace("a0.current_choices", "evo_runtime.current_choices")
replace("a0.nodes", "hud_state.nodes")
replace("a0.tip_panel", "hud_state.tip_panel")
replace("a0.tip_title_text", "hud_state.tip_title_text")
replace("a0.tip_body_text", "hud_state.tip_body_text")
replace("a0.tip_expires_at", "hud_state.tip_expires_at")
replace("a0.hover_tip", "hud_state.hover_tip")
replace("a0.bond_tip", "hud_state.bond_tip")
replace("a0.attr_panel", "hud_state.attr_panel")
replace("a0.big_cursor", "hud_state.big_cursor")
replace("a0.visible", "hud_state.visible")
replace("a0.bound_events", "hud_state.bound_events")
replace("a0.hero_model_ui", "hud_state.hero_model_ui")
replace("a0.buff_prefab", "hud_state.buff_prefab")
replace("a0.buff_prefab_root", "hud_state.buff_prefab_root")
replace("a0.buff_list_comp", "hud_state.buff_list_comp")
replace("= a0.", "= hud_state.")

replace("local a2 = get_player()", "local player = get_player()")
replace("not a2 ", "not player ")
replace(", a2, ", ", player, ")

replace("resolve_first_ui_node(a4)", "resolve_first_ui_node(name_list)")
replace("function resolve_first_ui_node(a4)", "function resolve_first_ui_node(name_list)")

replace("local a5 = '__first__:'", "local cache_key = '__first__:'")

replace("function safe_ui_call(u, a7,", "function safe_ui_call(u, method_name,")
replace("local a8 = u[a7]", "local method = u[method_name]")
replace("type(a8)", "type(method)")
replace("pcall(a8,", "pcall(method,")

replace("function set_ui_visible(u, aa)", "function set_ui_visible(u, visible)")
replace("aa == true", "visible == true")

replace("function set_ui_text(u, ac)", "function set_ui_text(u, text)")
replace("ac or ''", "text or ''")

replace("function set_ui_text_color(u, ae)", "function set_ui_text_color(u, color)")
replace("function set_ui_image_color(u, ae)", "function set_ui_image_color(u, color)")
replace("ae[1], ae[2], ae[3], ae[4]", "color[1], color[2], color[3], color[4]")
replace("if ae then", "if color then")

replace("function set_ui_font_size(u, ag)", "function set_ui_font_size(u, font_size)")

replace("function set_ui_text_alignment(u, ai, aj)", "function set_ui_text_alignment(u, h_align, v_align)")

replace("function set_ui_image(u, al)", "function set_ui_image(u, image_id)")
replace("al ~= nil", "image_id ~= nil")

replace("function set_ui_size(u, ao, ap)", "function set_ui_size(u, width, height)")
replace("ao and ap", "width and height")

replace("local a1 = hud_state.nodes[_]", "local cached_node = hud_state.nodes[_]")
replace("local a1 = hud_state.nodes[a5]", "local cached_node = hud_state.nodes[cache_key]")
replace("local a1 = hud_state.nodes[cache_key]", "local cached_node = hud_state.nodes[cache_key]")
replace("is_ui_alive(a1)", "is_ui_alive(cached_node)")
replace("return a1 end", "return cached_node end")

replace("local bX = cl and cl[bL]", "local slot_data = skill_slots and skill_slots[bL]")
replace("local bX = skill_slots and skill_slots[bL]", "local slot_data = skill_slots and skill_slots[bL]")
replace("build_attack_skill_entry(bX,", "build_attack_skill_entry(slot_data,")
replace("if bX then", "if slot_data then")

replace("local cl = STATE.attack_skill_state and STATE.attack_skill_state.slots",
  "local skill_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots")
replace("local cl = STATE.attack_skill_state and STATE.attack_skill_state.slots",
  "local skill_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots")

replace("q[cq]", "evolutions_by_id[evo_id]")
replace("local cb = cq and evolutions_by_id", "local evo_def = evo_id and evolutions_by_id")
replace("if cb then", "if evo_def then")
replace("build_evolution_skill_entry(cb,", "build_evolution_skill_entry(evo_def,")

replace("function get_evolution_slot_entries(cj)", "function get_evolution_slot_entries(count)")
replace("local ck = {}", "local entries = {}")
replace("local co = math.max(1, tonumber(cj) or EVOLUTION_SLOT_COUNT)",
  "local max_count = math.max(1, tonumber(count) or EVOLUTION_SLOT_COUNT)")
replace("= 1, co,", "= 1, max_count,")
replace("local cp = a0 and (a0.ordered_evolution_ids) or nil;",
  "local evolution_ids = evo_runtime and (evo_runtime.ordered_evolution_ids) or nil;")

replace("local c4 = build_evolution_skill_entry", "local entry = build_evolution_skill_entry")

replace("local cv,\n      cw = get_pending_choice_status()",
  "local choice_label,\n      choice_hint = get_pending_choice_status()")
replace("cv and cw then", "choice_label and choice_hint then")
replace("return cv, cw", "return choice_label, choice_hint")
replace("cv then return ", "choice_label then return ")

replace("local cy = ", "local damage_text_status = ")
replace("local cz = ", "local hit_effects_status = ")
replace("local cA = ", "local pause_status = ")

replace("local cE = get_hud_state()", "local hud_state_inner = get_hud_state()")
replace("cE.", "hud_state_inner.")

replace("local cR =", "local model_ui =")
replace("local cI = ATTR_ROW_NAMES[row_index]", "local row_name = ATTR_ROW_NAMES[row_index]")
replace("cI ", "row_name ")
replace("for cH = ", "for row_index = ")

replace("local d0 =", "local duration =")
replace("local dK =", "local exp_progress =")
replace("local dM =", "local bar_width =")
replace("local d9 = build_runtime_attr_dialog_chunks", "local chunks = build_runtime_attr_dialog_chunks")
replace("table.concat(d9,", "table.concat(chunks,")

replace("local cm = build_hero_form_skill_entry", "local form_entry = build_hero_form_skill_entry")
replace("if cm then", "if form_entry then")

replace("return M\n", "return M\n")  -- no-op, just to confirm final file state

file = io.open('ui/runtime_hud.lua', 'w')
file:write(content)
file:close()
print(string.format('Done! %d total replacements.', count))
