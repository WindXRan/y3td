local file = io.open('ui/runtime_hud.lua', 'r')
local content = file:read('*a')
file:close()

-- Fix: standalone 'y' in function bodies that should be 'y3'
content = content:gsub('ui_root%.resolve_ui%(y,', 'ui_root.resolve_ui(y3,')
content = content:gsub('ui_root%.resolve_first_ui%(y,', 'ui_root.resolve_first_ui(y3,')

-- a0 -> hud_state or evo_runtime depending on context
content = content:gsub('local a0 = get_hud_state%(%)', 'local hud_state = get_hud_state()')
content = content:gsub('local a0 = get_evolution_runtime%(%)', 'local evo_runtime = get_evolution_runtime()')

-- Fix remaining a0 references
content = content:gsub('([^a-z])a0%.', '%1hud_state.')
content = content:gsub('([^a-z])a0%[', '%1hud_state[')

-- a2 -> player
content = content:gsub('local a2 = get_player%(%)', 'local player = get_player()')
content = content:gsub('([^a-z])not a2 ', '%1not player ')
content = content:gsub(', a2,', ', player,')

-- a4 -> name_list
content = content:gsub('function resolve_first_ui_node%(a4%)', 'function resolve_first_ui_node(name_list)')
content = content:gsub('resolve_first_ui_node%(a4%)', 'resolve_first_ui_node(name_list)')
content = content:gsub('%(a4 or', '(name_list or')

-- a5 -> cache_key
content = content:gsub('local a5 = ', 'local cache_key = ')
content = content:gsub('%.nodes%[a5%]', '.nodes[cache_key]')

-- a7 -> method_name, a8 -> method
content = content:gsub('function safe_ui_call%(u, a7,', 'function safe_ui_call(u, method_name,')
content = content:gsub('local a8 = u%[a7%]', 'local method = u[method_name]')
content = content:gsub('([^a-z])type%(a8%)', '%1type(method)')
content = content:gsub('([^a-z])pcall%(a8,', '%1pcall(method,')

-- aa -> visible
content = content:gsub('function set_ui_visible%(u, aa%)', 'function set_ui_visible(u, visible)')
content = content:gsub('([^a-z])aa == true', '%1visible == true')

-- ac -> text
content = content:gsub('function set_ui_text%(u, ac%)', 'function set_ui_text(u, text)')
content = content:gsub('([^a-z])ac or ', '%1text or ')

-- ae -> color
content = content:gsub('function set_ui_text_color%(u, ae%)', 'function set_ui_text_color(u, color)')
content = content:gsub('function set_ui_image_color%(u, ae%)', 'function set_ui_image_color(u, color)')
content = content:gsub('ae%[1%], ae%[2%], ae%[3%], ae%[4%]', 'color[1], color[2], color[3], color[4]')
content = content:gsub('([^a-z])if ae', '%1if color')
content = content:gsub('([^a-z])not ae', '%1not color')

-- ag -> font_size
content = content:gsub('function set_ui_font_size%(u, ag%)', 'function set_ui_font_size(u, font_size)')

-- ai/aj -> h_align/v_align
content = content:gsub('function set_ui_text_alignment%(u, ai, aj%)', 'function set_ui_text_alignment(u, h_align, v_align)')

-- al -> image_id
content = content:gsub('function set_ui_image%(u, al%)', 'function set_ui_image(u, image_id)')
content = content:gsub('([^a-z])al ~= nil', '%1image_id ~= nil')

-- ao/ap -> width/height
content = content:gsub('function set_ui_size%(u, ao, ap%)', 'function set_ui_size(u, width, height)')
content = content:gsub('([^a-z])if ao and ap', '%1if width and height')

-- a1 -> cached_node
content = content:gsub('local a1 = ([^%s]+)%.nodes', 'local cached_node = %1.nodes')
content = content:gsub('([^a-z])if is_ui_alive%(a1%)', '%1if is_ui_alive(cached_node)')
content = content:gsub('([^a-z])return a1 ', '%1return cached_node ')

-- cl -> skill_slots, bX -> slot_data
content = content:gsub('local cl = STATE%.attack_skill_state and STATE%.attack_skill_state%.slots',
  'local skill_slots = STATE.attack_skill_state and STATE.attack_skill_state.slots')
content = content:gsub('local bX = cl and cl%[bL%]', 'local slot_data = skill_slots and skill_slots[bL]')
content = content:gsub('build_attack_skill_entry%(bX,', 'build_attack_skill_entry(slot_data,')

-- cq -> evo_id
content = content:gsub('local cq = cp and cp%[bL%]', 'local evo_id = evolution_ids and evolution_ids[bL]')

-- cb -> evo_def
content = content:gsub('local cb = cq and evolutions_by_id%[', 'local evo_def = evo_id and evolutions_by_id[')
content = content:gsub('if cb then', 'if evo_def then')
content = content:gsub('build_evolution_skill_entry%(cb,', 'build_evolution_skill_entry(evo_def,')

-- c4 -> entry
content = content:gsub('local c4 = build', 'local entry = build')
content = content:gsub('if c4 then ck%[#ck %+ 1%] = c4 end', 'if entry then entries[#entries + 1] = entry end')

-- cj -> count, ck -> entries, co -> max_count, cp -> evolution_ids
content = content:gsub('function get_evolution_slot_entries%(cj%)', 'function get_evolution_slot_entries(count)')
content = content:gsub('\nlocal ck = ', '\nlocal entries = ')
content = content:gsub('return ck', 'return entries')
content = content:gsub('local co = math%.max%(1, tonumber%(cj%) or EVOLUTION_SLOT_COUNT%)',
  'local max_count = math.max(1, tonumber(count) or EVOLUTION_SLOT_COUNT)')
content = content:gsub('for bL = 1, co,', 'for bL = 1, max_count,')
content = content:gsub('local cp = a0 and %(a0%.ordered_evolution_ids%) or nil;',
  'local evolution_ids = evo_runtime and (evo_runtime.ordered_evolution_ids) or nil;')

-- More ck fixes
content = content:gsub('([^a-z])ck%[', '%1entries[')
content = content:gsub('= ck ', '= entries ')

-- cv/cw/cy/cz/cA/cE in status functions
content = content:gsub('local cv,\n%s*cw = get_pending_choice_status%(%)',
  'local choice_label,\n      choice_hint = get_pending_choice_status()')
content = content:gsub('([^^])cv and cw', '%1choice_label and choice_hint')
content = content:gsub('return cv, cw', 'return choice_label, choice_hint')
content = content:gsub('local cv = ', 'local choice_label = ')
content = content:gsub('local cw = ', 'local choice_hint = ')

content = content:gsub('local cy = ', 'local damage_text_status = ')
content = content:gsub('local cz = ', 'local hit_effects_status = ')
content = content:gsub('local cA = ', 'local pause_status = ')

content = content:gsub('local cE = get_hud_state%(%)', 'local hud_state_inner = get_hud_state()')
content = content:gsub('([^a-z])cE%.', '%1hud_state_inner.')

-- cR -> model_ui
content = content:gsub('local cR =', 'local model_ui =')

-- cI -> row_name, cH -> row_index
content = content:gsub('local cI = ATTR_ROW_NAMES%[cH%]', 'local row_name = ATTR_ROW_NAMES[row_index]')
content = content:gsub('for cH = ', 'for row_index = ')

-- d0 -> duration
content = content:gsub('local d0 =', 'local duration =')

-- dK -> exp_progress
content = content:gsub('local dK =', 'local exp_progress =')

-- dM -> bar_width
content = content:gsub('local dM =', 'local bar_width =')

-- dV -> model
content = content:gsub('local dV =', 'local model =')

file = io.open('ui/runtime_hud.lua', 'w')
file:write(content)
file:close()
print('Deep rename done')
