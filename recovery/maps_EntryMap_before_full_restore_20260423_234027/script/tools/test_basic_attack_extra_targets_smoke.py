import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
ATTACK_SKILLS = ROOT / "script" / "runtime" / "attack_skills.lua"
BOOT = ROOT / "script" / "runtime" / "boot.lua"
LUA = Path(r"C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe")
LUAC = Path(r"C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe")


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )


def assert_ok(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{message}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")


def test_basic_attack_code_uses_snapshot_center_and_bonus_chain_attrs() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    boot_content = BOOT.read_text(encoding="utf-8")

    assert "local impact_center = impact_point or get_unit_point_snapshot(target)" in attack_content
    assert "local splash_center = impact_center or target" in attack_content
    assert "get_enemies_in_range(\n          splash_center," in attack_content
    assert "local explosion_ratio = math.max(0, get_effective_skill_value(skill, 'explosion_ratio'))" in attack_content
    assert "local runtime_chain_count, runtime_chain_chance, runtime_chain_ratio = get_basic_attack_runtime_chain_stats()" in attack_content
    assert "local bonus_chain_count, bonus_chain_ratio = get_basic_attack_bonus_chain_stats()" in attack_content
    assert "play_skill_audio(skill, 'impact', target or impact_center)" in attack_content
    assert "local function deal_basic_attack_secondary_damage(skill, unit, amount, options)" in attack_content
    assert "get_bond_runtime_bonus('chain_bounces') + get_hero_attr_value('弹射次数')" in boot_content
    assert "get_hero_attr_ratio('弹射伤害')" in boot_content
    assert "local basic_chain_particle = basic_attack_vfx.chain_particle" in boot_content
    assert "deal_skill_damage(unit, data.damage * bond_chain_ratio, basic_attack_def, {" in boot_content


def test_basic_attack_multishot_and_split_survive_killshot_center() -> None:
    syntax = run([str(LUAC), "-p", str(ATTACK_SKILLS)])
    assert_ok(syntax, "runtime/attack_skills.lua syntax check failed")

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local function make_point() "
        "  local point = { kind = 'point' } "
        "  function point:move() return make_point() end "
        "  function point:get_angle_with(_) return 0 end "
        "  return point "
        "end "
        "local attack_skills = require('runtime.attack_skills') "
        "local main_point = make_point() "
        "local hero_point = make_point() "
        "local damage_log = {} "
        "local damage_values = {} "
        "local projectile_targets = {} "
        "local search_centers = {} "
        "local main_target = { name = 'main', alive = true, point = main_point } "
        "function main_target:is_exist() return self.alive end "
        "function main_target:get_point() return self.point end "
        "local extra_a = { name = 'extra_a', alive = true, point = make_point() } "
        "function extra_a:is_exist() return self.alive end "
        "function extra_a:get_point() return self.point end "
        "local extra_b = { name = 'extra_b', alive = true, point = make_point() } "
        "function extra_b:is_exist() return self.alive end "
        "function extra_b:get_point() return self.point end "
        "local hero = {} "
        "function hero:is_exist() return true end "
        "function hero:get_point() return hero_point end "
        "function hero:has_state(_) return false end "
        "function hero:set_facing(_, _) end "
        "function hero:play_animation(_, _, _, _, _, _) end "
        "function hero:get_attr(_) return 0 end "
        "function hero:damage(payload) "
        "  damage_log[#damage_log + 1] = payload.target.name "
        "  damage_values[payload.target.name] = damage_values[payload.target.name] or {} "
        "  table.insert(damage_values[payload.target.name], payload.damage) "
        "  if payload.target == main_target then "
        "    main_target.alive = false "
        "  end "
        "end "
        "local selector = {} "
        "function selector:is_enemy(_) return self end "
        "function selector:in_range(_, _) return self end "
        "function selector:sort_type(_) return self end "
        "function selector:pick() return { main_target } end "
        "local system = attack_skills.create({ "
        "  CONFIG = { damage_hit_effect_enabled = false }, "
        "  STATE = { "
        "    hero = hero, "
        "    hero_common_attack = nil, "
        "    basic_attack_animation_names = { 'attack1' }, "
        "    enemy_info_map = {}, "
        "    attack_skill_state = { "
        "      by_id = { basic_attack = { "
        "        id = 'basic_attack', "
        "        damage_ratio = 1, "
        "        damage_type = '物理', "
        "        split_count = 1, "
        "        split_ratio = 0.5, "
        "        boss_bonus_ratio = 0, "
        "        armor_break_ratio = 0, "
        "        armor_break_duration = 0, "
        "        armor_break_max_stacks = 0, "
        "        cooldown_remaining = 0 "
        "      } }, "
        "      slots = { [1] = nil } "
        "    } "
        "  }, "
        "  y3 = { "
        "    helper = { tonumber = tonumber }, "
        "    selector = { create = function() return selector end }, "
        "    projectile = { create = function() "
        "      local projectile = { removed = false, point = make_point() } "
        "      function projectile:is_exist() return not self.removed end "
        "      function projectile:get_point() return self.point end "
        "      function projectile:remove() self.removed = true end "
        "      function projectile:set_facing(_) end "
        "      function projectile:set_height(_) end "
        "      function projectile:mover_target(args) "
        "        projectile_targets[#projectile_targets + 1] = args.target and args.target.name or 'nil' "
        "        args.on_finish() "
        "      end "
        "      return projectile "
        "    end }, "
        "    particle = { create = function() return { is_exist = function() return false end, remove = function() end } end }, "
        "    ltimer = { wait = function(_, fn) fn() end } "
        "  }, "
        "  round_number = function(v) return math.floor((tonumber(v) or 0) + 0.5) end, "
        "  message = function() end, "
        "  ATTACK_SKILL_DEFS = { basic_attack = { base_range = 600, damage_type = '物理', cast_family = 'basic_projectile' } }, "
        "  ATTACK_SKILL_VFX = { basic_attack = { projectile_key = 1, impact_particle = 0 } }, "
        "  hero_attr_system = { "
        "    get_attr = function(_, name) "
        "      if name == '攻击范围' then return 600 end "
        "      if name == '攻击结算值' or name == '攻击' then return 100 end "
        "      if name == '多重数量' then return 1 end "
        "      if name == '多重伤害' then return 0.5 end "
        "      return 0 "
        "    end "
        "  }, "
        "  get_player = function() return {} end, "
        "  get_hero_point = function() return hero_point end, "
        "  get_bond_runtime_bonus = function() return 0 end, "
        "  is_active_enemy = function(unit) return unit and unit.alive == true end, "
        "  create_attack_skill_instance = function() return {} end, "
        "  deal_skill_damage = function() end, "
        "  get_damage_bonus_multiplier = function() return 1 end, "
        "  get_enemies_in_range = function(center, _, _, max_count) "
        "    search_centers[#search_centers + 1] = center and center.kind or type(center) "
        "    if center and center.kind == 'point' then "
        "      if max_count == 1 then return { extra_a, extra_b } end "
        "      return { extra_a, extra_b } "
        "    end "
        "    return {} "
        "  end, "
        "  try_trigger_hunter_first_hit = function() end, "
        "  notify_bond_attack_skill_cast = function() end, "
        "  notify_auto_active_basic_attack = function() end, "
        "  notify_auto_active_skill_cast = function() end "
        "}) "
        "system.update_attack_skills(0.1) "
        "local hit_counts = {} "
        "for _, name in ipairs(damage_log) do hit_counts[name] = (hit_counts[name] or 0) + 1 end "
        "assert(#damage_log == 3, 'basic attack should still hit main + multishot + split after main target dies') "
        "assert(hit_counts.main == 1, 'main target should only take the primary projectile hit once') "
        "assert(hit_counts.extra_a == 2, 'extra target should still take multishot and split damage') "
        "assert(damage_values.main[1] == 100, 'primary projectile should keep full basic attack damage') "
        "assert(#damage_values.extra_a == 2, 'extra target should record two follow-up hits') "
        "assert(damage_values.extra_a[1] == 50 and damage_values.extra_a[2] == 50, 'multishot and split should both respect their configured ratios') "
        "assert(#projectile_targets == 2, 'basic attack should launch the main projectile and one real multishot projectile') "
        "assert(projectile_targets[1] == 'main', 'first projectile should still target the selected enemy') "
        "assert(projectile_targets[2] == 'extra_a', 'second projectile should come from the real multishot launch') "
        "assert(search_centers[1] == 'point', 'multishot center should come from the target snapshot point') "
        "assert(search_centers[2] == 'point', 'split center should come from projectile impact snapshot') "
        "print('basic attack extra targets smoke ok')"
    )

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".lua", delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)

    assert_ok(smoke, "basic attack extra targets smoke failed")


def test_basic_attack_projectile_miss_does_not_deal_damage() -> None:
    syntax = run([str(LUAC), "-p", str(ATTACK_SKILLS)])
    assert_ok(syntax, "runtime/attack_skills.lua syntax check failed")

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local function make_point() "
        "  local point = { kind = 'point' } "
        "  function point:move() return make_point() end "
        "  function point:get_angle_with(_) return 0 end "
        "  return point "
        "end "
        "local attack_skills = require('runtime.attack_skills') "
        "local hero_point = make_point() "
        "local damage_log = {} "
        "local main_target = { name = 'main', alive = true, point = make_point() } "
        "function main_target:is_exist() return self.alive end "
        "function main_target:get_point() return self.point end "
        "local hero = {} "
        "function hero:is_exist() return true end "
        "function hero:get_point() return hero_point end "
        "function hero:has_state(_) return false end "
        "function hero:set_facing(_, _) end "
        "function hero:play_animation(_, _, _, _, _, _) end "
        "function hero:get_attr(_) return 0 end "
        "function hero:damage(payload) damage_log[#damage_log + 1] = payload.target.name end "
        "local selector = {} "
        "function selector:is_enemy(_) return self end "
        "function selector:in_range(_, _) return self end "
        "function selector:sort_type(_) return self end "
        "function selector:pick() return { main_target } end "
        "local projectile = { removed = false, point = make_point() } "
        "function projectile:is_exist() return not self.removed end "
        "function projectile:get_point() return self.point end "
        "function projectile:remove() self.removed = true end "
        "function projectile:set_facing(_) end "
        "function projectile:set_height(_) end "
        "function projectile:mover_target(args) args.on_break() end "
        "local system = attack_skills.create({ "
        "  CONFIG = { damage_hit_effect_enabled = false }, "
        "  STATE = { "
        "    hero = hero, "
        "    hero_common_attack = nil, "
        "    basic_attack_animation_names = { 'attack1' }, "
        "    enemy_info_map = {}, "
        "    attack_skill_state = { "
        "      by_id = { basic_attack = { "
        "        id = 'basic_attack', "
        "        damage_ratio = 1, "
        "        damage_type = '物理', "
        "        split_count = 0, "
        "        split_ratio = 0, "
        "        boss_bonus_ratio = 0, "
        "        armor_break_ratio = 0, "
        "        armor_break_duration = 0, "
        "        armor_break_max_stacks = 0, "
        "        cooldown_remaining = 0 "
        "      } }, "
        "      slots = { [1] = nil } "
        "    } "
        "  }, "
        "  y3 = { "
        "    helper = { tonumber = tonumber }, "
        "    selector = { create = function() return selector end }, "
        "    projectile = { create = function() return projectile end }, "
        "    particle = { create = function() return { is_exist = function() return false end, remove = function() end } end }, "
        "    ltimer = { wait = function(_, fn) fn() end } "
        "  }, "
        "  round_number = function(v) return math.floor((tonumber(v) or 0) + 0.5) end, "
        "  message = function() end, "
        "  ATTACK_SKILL_DEFS = { basic_attack = { base_range = 600, damage_type = '物理', cast_family = 'basic_projectile' } }, "
        "  ATTACK_SKILL_VFX = { basic_attack = { projectile_key = 1, impact_particle = 0 } }, "
        "  hero_attr_system = { "
        "    get_attr = function(_, name) "
        "      if name == '攻击范围' then return 600 end "
        "      if name == '攻击结算值' or name == '攻击' then return 100 end "
        "      return 0 "
        "    end "
        "  }, "
        "  get_player = function() return {} end, "
        "  get_hero_point = function() return hero_point end, "
        "  get_bond_runtime_bonus = function() return 0 end, "
        "  is_active_enemy = function(unit) return unit and unit.alive == true end, "
        "  create_attack_skill_instance = function() return {} end, "
        "  deal_skill_damage = function() end, "
        "  get_damage_bonus_multiplier = function() return 1 end, "
        "  get_enemies_in_range = function() return {} end, "
        "  try_trigger_hunter_first_hit = function() end, "
        "  notify_bond_attack_skill_cast = function() end, "
        "  notify_auto_active_basic_attack = function() end, "
        "  notify_auto_active_skill_cast = function() end "
        "}) "
        "system.update_attack_skills(0.1) "
        "assert(#damage_log == 0, 'basic attack should not deal damage when projectile breaks before hit') "
        "print('basic attack projectile miss smoke ok')"
    )

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".lua", delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)

    assert_ok(smoke, "basic attack projectile miss smoke failed")


def test_basic_attack_projectile_break_near_target_still_hits() -> None:
    syntax = run([str(LUAC), "-p", str(ATTACK_SKILLS)])
    assert_ok(syntax, "runtime/attack_skills.lua syntax check failed")

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local function make_point(x, y) "
        "  local point = { kind = 'point', x = x or 0, y = y or 0 } "
        "  function point:move(dx, dy) return make_point((self.x or 0) + (dx or 0), (self.y or 0) + (dy or 0)) end "
        "  function point:get_angle_with(_) return 0 end "
        "  function point:get_distance_with(other) "
        "    local ox = other and other.x or 0 "
        "    local oy = other and other.y or 0 "
        "    local dx = (self.x or 0) - ox "
        "    local dy = (self.y or 0) - oy "
        "    return math.sqrt(dx * dx + dy * dy) "
        "  end "
        "  return point "
        "end "
        "local attack_skills = require('runtime.attack_skills') "
        "local hero_point = make_point(0, 0) "
        "local damage_log = {} "
        "local main_target = { name = 'main', alive = true, point = make_point(100, 0) } "
        "function main_target:is_exist() return self.alive end "
        "function main_target:get_point() return self.point end "
        "local hero = {} "
        "function hero:is_exist() return true end "
        "function hero:get_point() return hero_point end "
        "function hero:has_state(_) return false end "
        "function hero:set_facing(_, _) end "
        "function hero:play_animation(_, _, _, _, _, _) end "
        "function hero:get_attr(_) return 0 end "
        "function hero:damage(payload) damage_log[#damage_log + 1] = payload.target.name end "
        "local selector = {} "
        "function selector:is_enemy(_) return self end "
        "function selector:in_range(_, _) return self end "
        "function selector:sort_type(_) return self end "
        "function selector:pick() return { main_target } end "
        "local projectile = { removed = false, point = make_point(120, 0) } "
        "function projectile:is_exist() return not self.removed end "
        "function projectile:get_point() return self.point end "
        "function projectile:remove() self.removed = true end "
        "function projectile:set_facing(_) end "
        "function projectile:set_height(_) end "
        "function projectile:mover_target(args) args.on_break() end "
        "local system = attack_skills.create({ "
        "  CONFIG = { damage_hit_effect_enabled = false }, "
        "  STATE = { "
        "    hero = hero, "
        "    hero_common_attack = nil, "
        "    basic_attack_animation_names = { 'attack1' }, "
        "    enemy_info_map = {}, "
        "    attack_skill_state = { "
        "      by_id = { basic_attack = { "
        "        id = 'basic_attack', "
        "        damage_ratio = 1, "
        "        damage_type = '物理', "
        "        split_count = 0, "
        "        split_ratio = 0, "
        "        boss_bonus_ratio = 0, "
        "        armor_break_ratio = 0, "
        "        armor_break_duration = 0, "
        "        armor_break_max_stacks = 0, "
        "        cooldown_remaining = 0 "
        "      } }, "
        "      slots = { [1] = nil } "
        "    } "
        "  }, "
        "  y3 = { "
        "    helper = { tonumber = tonumber }, "
        "    selector = { create = function() return selector end }, "
        "    projectile = { create = function() return projectile end }, "
        "    particle = { create = function() return { is_exist = function() return false end, remove = function() end } end }, "
        "    ltimer = { wait = function(_, fn) fn() end } "
        "  }, "
        "  round_number = function(v) return math.floor((tonumber(v) or 0) + 0.5) end, "
        "  message = function() end, "
        "  ATTACK_SKILL_DEFS = { basic_attack = { base_range = 600, damage_type = '物理', cast_family = 'basic_projectile' } }, "
        "  ATTACK_SKILL_VFX = { basic_attack = { projectile_key = 1, impact_particle = 0, target_distance = 28 } }, "
        "  hero_attr_system = { "
        "    get_attr = function(_, name) "
        "      if name == '攻击范围' then return 600 end "
        "      if name == '攻击结算值' or name == '攻击' then return 100 end "
        "      return 0 "
        "    end "
        "  }, "
        "  get_player = function() return {} end, "
        "  get_hero_point = function() return hero_point end, "
        "  get_bond_runtime_bonus = function() return 0 end, "
        "  is_active_enemy = function(unit) return unit and unit.alive == true end, "
        "  create_attack_skill_instance = function() return {} end, "
        "  deal_skill_damage = function() end, "
        "  get_damage_bonus_multiplier = function() return 1 end, "
        "  get_enemies_in_range = function() return {} end, "
        "  try_trigger_hunter_first_hit = function() end, "
        "  notify_bond_attack_skill_cast = function() end, "
        "  notify_auto_active_basic_attack = function() end, "
        "  notify_auto_active_skill_cast = function() end "
        "}) "
        "system.update_attack_skills(0.1) "
        "assert(#damage_log == 1, 'basic attack should still hit when projectile breaks near the target') "
        "assert(damage_log[1] == 'main', 'near-target break should still resolve against the selected enemy') "
        "print('basic attack projectile near-break hit smoke ok')"
    )

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".lua", delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)

    assert_ok(smoke, "basic attack projectile near-break smoke failed")


def test_basic_attack_explosion_survives_killshot_center_in_single_effect_mode() -> None:
    syntax = run([str(LUAC), "-p", str(ATTACK_SKILLS)])
    assert_ok(syntax, "runtime/attack_skills.lua syntax check failed")

    smoke_source = (
        "package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path "
        "local function make_point() "
        "  local point = { kind = 'point' } "
        "  function point:move() return make_point() end "
        "  function point:get_angle_with(_) return 0 end "
        "  return point "
        "end "
        "local attack_skills = require('runtime.attack_skills') "
        "local hero_point = make_point() "
        "local damage_log = {} "
        "local search_centers = {} "
        "local main_target = { name = 'main', alive = true, point = make_point() } "
        "function main_target:is_exist() return self.alive end "
        "function main_target:get_point() return self.point end "
        "local extra_a = { name = 'extra_a', alive = true, point = make_point() } "
        "function extra_a:is_exist() return self.alive end "
        "function extra_a:get_point() return self.point end "
        "local extra_b = { name = 'extra_b', alive = true, point = make_point() } "
        "function extra_b:is_exist() return self.alive end "
        "function extra_b:get_point() return self.point end "
        "local hero = {} "
        "function hero:is_exist() return true end "
        "function hero:get_point() return hero_point end "
        "function hero:has_state(_) return false end "
        "function hero:set_facing(_, _) end "
        "function hero:play_animation(_, _, _, _, _, _) end "
        "function hero:get_attr(_) return 0 end "
        "function hero:damage(payload) "
        "  damage_log[#damage_log + 1] = payload.target.name "
        "  if payload.target == main_target then "
        "    main_target.alive = false "
        "  end "
        "end "
        "local selector = {} "
        "function selector:is_enemy(_) return self end "
        "function selector:in_range(_, _) return self end "
        "function selector:sort_type(_) return self end "
        "function selector:pick() return { main_target } end "
        "local projectile = { removed = false, point = make_point() } "
        "function projectile:is_exist() return not self.removed end "
        "function projectile:get_point() return self.point end "
        "function projectile:remove() self.removed = true end "
        "function projectile:set_facing(_) end "
        "function projectile:set_height(_) end "
        "function projectile:mover_target(args) args.on_finish() end "
        "local system = attack_skills.create({ "
        "  CONFIG = { damage_hit_effect_enabled = false }, "
        "  STATE = { "
        "    hero = hero, "
        "    hero_common_attack = nil, "
        "    basic_attack_animation_names = { 'attack1' }, "
        "    enemy_info_map = {}, "
        "    skill_runtime = { normal_attack_bonus_ratio = 0, splash_ratio = 0, splash_radius = 220, chain_bounces = 0, chain_chance = 0, chain_ratio = 0, chain_radius = 420 }, "
        "    attack_skill_state = { "
        "      by_id = { basic_attack = { "
        "        id = 'basic_attack', "
        "        damage_ratio = 1, "
        "        damage_type = '物理', "
        "        explosion_ratio = 0.35, "
        "        explosion_radius = 180, "
        "        split_count = 0, "
        "        split_ratio = 0, "
        "        boss_bonus_ratio = 0, "
        "        armor_break_ratio = 0, "
        "        armor_break_duration = 0, "
        "        armor_break_max_stacks = 0, "
        "        cooldown_remaining = 0 "
        "      } }, "
        "      slots = { [1] = nil } "
        "    } "
        "  }, "
        "  y3 = { "
        "    helper = { tonumber = tonumber }, "
        "    selector = { create = function() return selector end }, "
        "    projectile = { create = function() return projectile end }, "
        "    particle = { create = function() return { is_exist = function() return false end, remove = function() end } end }, "
        "    ltimer = { wait = function(_, fn) fn() end } "
        "  }, "
        "  round_number = function(v) return math.floor((tonumber(v) or 0) + 0.5) end, "
        "  message = function() end, "
        "  ATTACK_SKILL_DEFS = { basic_attack = { base_range = 600, damage_type = '物理', cast_family = 'basic_projectile' } }, "
        "  ATTACK_SKILL_VFX = { basic_attack = { projectile_key = 1, impact_particle = 0 } }, "
        "  hero_attr_system = { "
        "    get_attr = function(_, name) "
        "      if name == '攻击范围' then return 600 end "
        "      if name == '攻击结算值' or name == '攻击' then return 100 end "
        "      return 0 "
        "    end "
        "  }, "
        "  get_player = function() return {} end, "
        "  get_hero_point = function() return hero_point end, "
        "  get_bond_runtime_bonus = function() return 0 end, "
        "  is_active_enemy = function(unit) return unit and unit.alive == true end, "
        "  create_attack_skill_instance = function() return {} end, "
        "  deal_skill_damage = function() end, "
        "  get_damage_bonus_multiplier = function() return 1 end, "
        "  get_enemies_in_range = function(center) "
        "    search_centers[#search_centers + 1] = center and center.kind or type(center) "
        "    if center and center.kind == 'point' then return { extra_a, extra_b } end "
        "    return {} "
        "  end, "
        "  try_trigger_hunter_first_hit = function() end, "
        "  notify_bond_attack_skill_cast = function() end, "
        "  notify_auto_active_basic_attack = function() end, "
        "  notify_auto_active_skill_cast = function() end "
        "}) "
        "system.update_attack_skills(0.1) "
        "assert(#damage_log == 3, 'basic attack explosion should hit main target and nearby enemies after the main target dies') "
        "assert(damage_log[1] == 'main', 'main target should still be hit first') "
        "assert(damage_log[2] == 'extra_a', 'explosion should reuse impact snapshot for nearby enemies') "
        "assert(damage_log[3] == 'extra_b', 'explosion should continue damaging nearby enemies from the impact snapshot') "
        "assert(search_centers[1] == 'point', 'explosion search should use the projectile impact point snapshot') "
        "print('basic attack explosion smoke ok')"
    )

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".lua", delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)

    assert_ok(smoke, "basic attack explosion smoke failed")
