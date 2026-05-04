import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
ATTACK_SKILLS = ROOT / "script" / "runtime" / "attack_skills.lua"
BOOT = ROOT / "script" / "runtime" / "boot.lua"
LUA = Path(r"C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe")
LUAC = Path(r"C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe")

SCRIPT_PATH = (
    "package.path = "
    "'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;"
    "maps/EntryMap/script/?/?.lua;' .. package.path\n"
)

COMMON_LUA = r"""
local attack_skills = require('runtime.attack_skills')
local damage_log = {}
local damage_values = {}
local projectile_targets = {}
local search_centers = {}

local function make_point(x, y)
  local point = { kind = 'point', x = x or 0, y = y or 0 }
  function point:move(dx, dy) return make_point((self.x or 0) + (dx or 0), (self.y or 0) + (dy or 0)) end
  function point:get_angle_with(_) return 0 end
  function point:get_distance_with(other)
    local ox = other and other.x or 0
    local oy = other and other.y or 0
    local dx = (self.x or 0) - ox
    local dy = (self.y or 0) - oy
    return math.sqrt(dx * dx + dy * dy)
  end
  return point
end

local function make_unit(name, point)
  local unit = { name = name, alive = true, point = point or make_point() }
  function unit:is_exist() return self.alive end
  function unit:get_point() return self.point end
  return unit
end

local function make_projectile(point, finish_kind)
  local projectile = { removed = false, point = point or make_point() }
  function projectile:is_exist() return not self.removed end
  function projectile:get_point() return self.point end
  function projectile:remove() self.removed = true end
  function projectile:set_facing(_) end
  function projectile:set_height(_) end
  function projectile:mover_target(args)
    projectile_targets[#projectile_targets + 1] = args.target and args.target.name or 'nil'
    if finish_kind == 'break' then args.on_break() else args.on_finish() end
  end
  return projectile
end

local function make_system(opts)
  opts = opts or {}
  local hero_point = opts.hero_point or make_point()
  local main_target = opts.main_target or make_unit('main', make_point())
  local extra_a = make_unit('extra_a')
  local extra_b = make_unit('extra_b')
  local hero = {}
  function hero:is_exist() return true end
  function hero:get_point() return hero_point end
  function hero:has_state(_) return false end
  function hero:set_facing(_, _) end
  function hero:play_animation(_, _, _, _, _, _) end
  function hero:get_attr(_) return 0 end
  function hero:damage(payload)
    damage_log[#damage_log + 1] = payload.target.name
    damage_values[payload.target.name] = damage_values[payload.target.name] or {}
    table.insert(damage_values[payload.target.name], payload.damage)
    if opts.kill_main_on_hit and payload.target == main_target then main_target.alive = false end
  end

  local selector = {}
  function selector:is_enemy(_) return self end
  function selector:in_range(_, _) return self end
  function selector:sort_type(_) return self end
  function selector:pick() return { main_target } end

  local skill = {
    id = 'basic_attack',
    damage_ratio = 1,
    damage_type = '物理',
    split_count = opts.split_count or 0,
    split_ratio = opts.split_ratio or 0,
    explosion_ratio = opts.explosion_ratio or nil,
    explosion_radius = opts.explosion_radius or nil,
    boss_bonus_ratio = 0,
    armor_break_ratio = 0,
    armor_break_duration = 0,
    armor_break_max_stacks = 0,
    cooldown_remaining = 0,
  }

  local projectile_create = opts.projectile_create
  if not projectile_create then
    local projectile = opts.projectile or make_projectile(nil, opts.projectile_finish)
    projectile_create = function() return projectile end
  end

  return attack_skills.create({
    CONFIG = { damage_hit_effect_enabled = false },
    STATE = {
      hero = hero,
      hero_common_attack = nil,
      basic_attack_animation_names = { 'attack1' },
      enemy_info_map = {},
      skill_runtime = opts.skill_runtime,
      attack_skill_state = { by_id = { basic_attack = skill }, slots = { [1] = nil } },
    },
    y3 = {
      helper = { tonumber = tonumber },
      selector = { create = function() return selector end },
      projectile = { create = projectile_create },
      particle = { create = function() return { is_exist = function() return false end, remove = function() end } end },
      ltimer = { wait = function(_, fn) fn() end },
    },
    round_number = function(v) return math.floor((tonumber(v) or 0) + 0.5) end,
    message = function() end,
    ATTACK_SKILL_DEFS = { basic_attack = { base_range = 600, damage_type = '物理', cast_family = 'basic_projectile' } },
    ATTACK_SKILL_VFX = { basic_attack = opts.vfx or { projectile_key = 1, impact_particle = 0 } },
    hero_attr_system = {
      get_attr = function(_, name)
        if name == '攻击范围' then return 600 end
        if name == '攻击结算值' or name == '攻击' then return 100 end
        if name == '多重数量' then return opts.multishot_count or 0 end
        if name == '多重伤害' then return opts.multishot_ratio or 0 end
        return 0
      end
    },
    get_player = function() return {} end,
    get_hero_point = function() return hero_point end,
    get_bond_runtime_bonus = function() return 0 end,
    is_active_enemy = function(unit) return unit and unit.alive == true end,
    create_attack_skill_instance = function() return {} end,
    deal_skill_damage = function() end,
    get_damage_bonus_multiplier = function() return 1 end,
    get_enemies_in_range = function(center, _, _, max_count)
      search_centers[#search_centers + 1] = center and center.kind or type(center)
      if center and center.kind == 'point' then
        if max_count == 1 then return { extra_a, extra_b } end
        return { extra_a, extra_b }
      end
      return {}
    end,
    try_trigger_hunter_first_hit = function() end,
    notify_bond_attack_skill_cast = function() end,
    notify_auto_active_basic_attack = function() end,
    notify_auto_active_skill_cast = function() end,
  })
end
"""


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


def assert_attack_syntax() -> None:
    assert_ok(run([str(LUAC), "-p", str(ATTACK_SKILLS)]), "runtime/attack_skills.lua syntax check failed")


def run_lua(body: str, message: str) -> None:
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".lua", delete=False) as handle:
        handle.write(SCRIPT_PATH + COMMON_LUA + body)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)

    assert_ok(smoke, message)


def test_basic_attack_code_uses_snapshot_center_and_bonus_chain_attrs() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    boot_content = BOOT.read_text(encoding="utf-8")

    assert "get_enemies_in_range" in attack_content
    assert "multishot_count" in attack_content
    assert "split_count" in attack_content
    assert "explosion_ratio" in attack_content
    assert "chain_bounces" in attack_content
    assert "弹射次数" in attack_content
    assert "弹射伤害" in attack_content
    assert "on_break" in attack_content and "on_miss" in attack_content
    assert "chain_bounces" in boot_content
    assert "chain_ratio" in boot_content
    assert "弹射次数" in boot_content
    assert "弹射伤害" in boot_content
    assert "chain_particle" in boot_content
    assert "deal_skill_damage" in boot_content


def test_basic_attack_multishot_and_split_survive_killshot_center() -> None:
    assert_attack_syntax()
    run_lua(
        r"""
local system = make_system({ kill_main_on_hit = true, split_count = 1, split_ratio = 0.5, multishot_count = 1, multishot_ratio = 0.5 })
system.update_attack_skills(0.1)
local hit_counts = {}
for _, name in ipairs(damage_log) do hit_counts[name] = (hit_counts[name] or 0) + 1 end
assert(#damage_log == 3, 'basic attack should still hit main + multishot + split after main target dies')
assert(hit_counts.main == 1, 'main target should only take the primary projectile hit once')
assert(hit_counts.extra_a == 2, 'extra target should still take multishot and split damage')
assert(damage_values.main[1] == 100, 'primary projectile should keep full basic attack damage')
assert(#damage_values.extra_a == 2, 'extra target should record two follow-up hits')
assert(damage_values.extra_a[1] == 50 and damage_values.extra_a[2] == 50, 'multishot and split should both respect their configured ratios')
assert(#projectile_targets == 2, 'basic attack should launch the main projectile and one real multishot projectile')
assert(projectile_targets[1] == 'main', 'first projectile should still target the selected enemy')
assert(projectile_targets[2] == 'extra_a', 'second projectile should come from the real multishot launch')
assert(search_centers[1] == 'point', 'multishot center should come from the target snapshot point')
assert(search_centers[2] == 'point', 'split center should come from projectile impact snapshot')
print('basic attack extra targets smoke ok')
""",
        "basic attack extra targets smoke failed",
    )


def test_basic_attack_projectile_create_failure_still_deals_damage() -> None:
    assert_attack_syntax()
    run_lua(
        r"""
local system = make_system({ projectile_create = function() error('projectile create failed') end })
system.update_attack_skills(0.1)
assert(#damage_log == 1, 'basic attack should still deal damage when projectile creation fails')
assert(damage_log[1] == 'main', 'projectile creation fallback should hit the selected enemy')
print('basic attack projectile create failure fallback smoke ok')
""",
        "basic attack projectile create failure fallback smoke failed",
    )


def test_basic_attack_projectile_miss_does_not_deal_damage() -> None:
    assert_attack_syntax()
    run_lua(
        r"""
local projectile = make_projectile(nil, 'break')
projectile.point = { kind = 'point' }
function projectile.point:move() return { kind = 'point' } end
function projectile.point:get_angle_with(_) return 0 end
local system = make_system({ projectile = projectile })
system.update_attack_skills(0.1)
assert(#damage_log == 0, 'basic attack should not deal damage when projectile breaks before hit')
print('basic attack projectile miss smoke ok')
""",
        "basic attack projectile miss smoke failed",
    )


def test_basic_attack_projectile_break_near_target_still_hits() -> None:
    assert_attack_syntax()
    run_lua(
        r"""
local main_target = make_unit('main', make_point(100, 0))
local projectile = make_projectile(make_point(120, 0), 'break')
local system = make_system({
  hero_point = make_point(0, 0),
  main_target = main_target,
  projectile = projectile,
  vfx = { projectile_key = 1, impact_particle = 0, target_distance = 28 },
})
system.update_attack_skills(0.1)
assert(#damage_log == 1, 'basic attack should still hit when projectile breaks near the target')
assert(damage_log[1] == 'main', 'near-target break should still resolve against the selected enemy')
print('basic attack projectile near-break hit smoke ok')
""",
        "basic attack projectile near-break smoke failed",
    )


def test_basic_attack_explosion_survives_killshot_center_in_single_effect_mode() -> None:
    assert_attack_syntax()
    run_lua(
        r"""
local system = make_system({
  kill_main_on_hit = true,
  explosion_ratio = 0.35,
  explosion_radius = 180,
  skill_runtime = { normal_attack_bonus_ratio = 0, splash_ratio = 0, splash_radius = 220, chain_bounces = 0, chain_chance = 0, chain_ratio = 0, chain_radius = 420 },
})
system.update_attack_skills(0.1)
assert(#damage_log == 3, 'basic attack explosion should hit main target and nearby enemies after the main target dies')
assert(damage_log[1] == 'main', 'main target should still be hit first')
assert(damage_log[2] == 'extra_a', 'explosion should reuse impact snapshot for nearby enemies')
assert(damage_log[3] == 'extra_b', 'explosion should continue damaging nearby enemies from the impact snapshot')
assert(search_centers[1] == 'point', 'explosion search should use the projectile impact point snapshot')
print('basic attack explosion smoke ok')
""",
        "basic attack explosion smoke failed",
    )
