import json
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
BOOT = ROOT / "runtime" / "boot.lua"
ENTRY_CONFIG = ROOT / "config" / "entry_config.lua"
HERO_UNIT = ROOT.parent / "editor_table" / "editorunit" / "201390301.json"
HERO_UNIT_RUNTIME = ROOT.parent / "unit" / "201390301.json"
ABILITY_DIR = ROOT.parent / "editor_table" / "abilityall"
PROJECTILE_DIR = ROOT.parent / "editor_table" / "projectileall"
ATTACK_SKILLS_CSV = ROOT / "data_csv" / "attack_skills.csv"
PROJECTILE_VISUAL_KV_KEYS = {
    "entry_projectile_speed",
    "entry_projectile_time",
    "entry_target_distance",
    "entry_strike_delay",
}
ATTACK_SKILL_OBJECTS = {
    "basic_attack": (201390001, 134267104),
    "sword_wave": (201390002, 201364743),
    "arcane_laser": (201390003, 134255909),
    "arcane_ray": (201390004, 134264830),
    "frost_nova": (201390005, 134254402),
    "chain_lightning": (201390006, 134278613),
    "earthquake": (201390007, 201364744),
    "tornado": (201390008, 201364745),
    "electro_net": (201390009, 201364746),
    "meteor": (201390010, 201364747),
    "hurricane": (201390011, 201364748),
    "fireball": (201390012, 201364749),
    "moon_blade": (201390013, 201364750),
    "lotus_flame": (201390014, 201364751),
    "demon_seal": (201390015, 201364752),
    "flying_swords": (201390016, 201364753),
}


def get_primary_projectile_effect(effect_field: object) -> int | None:
    if isinstance(effect_field, list) and effect_field:
        return effect_field[0]
    if isinstance(effect_field, dict):
        items = effect_field.get("items")
        if isinstance(items, list) and items:
            return items[0]
    return None


def get_projectile_offset_z(effect_field: object) -> float | None:
    if isinstance(effect_field, list) and len(effect_field) > 1:
        offset = effect_field[1]
        if isinstance(offset, dict):
            items = offset.get("items")
            if isinstance(items, list) and len(items) >= 3:
                return float(items[2])
    if isinstance(effect_field, dict):
        items = effect_field.get("items")
        if isinstance(items, list) and len(items) > 1:
            offset = items[1]
            if isinstance(offset, list) and len(offset) >= 3:
                return float(offset[2])
    return None


def kv_value(entry: object) -> object:
    if isinstance(entry, dict) and "value" in entry:
        return entry["value"]
    return entry


def test_basic_attack_primary_hit_no_longer_uses_common_attack_visuals() -> None:
    content = ATTACK_SKILLS.read_text(encoding="utf-8")
    assert "deal_basic_attack_damage(skill, target, damage, {\n          common_attack = false," in content
    assert "particle = primary_hit_particle," in content
    assert "force_hit_effect = true," in content
    assert "local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false" in content
    assert "if options and options.force_hit_effect == true and not is_hit_effect_hidden() then" in content
    assert "local hero_damage_multiplier = 1" in content
    assert "if hero_attr_system and hero_attr_system.get_damage_multiplier then" in content
    assert "'normal_attack'," in content
    assert "ability = hit_effect_enabled" in content


def test_basic_attack_multishot_now_launches_real_projectiles() -> None:
    content = ATTACK_SKILLS.read_text(encoding="utf-8")
    assert "local multishot_targets = {}" in content
    assert "multishot_targets[#multishot_targets + 1] = unit" in content
    assert "if #multishot_targets > 0 and multishot_ratio > 0 then" in content
    assert "launch_projectile_to_target(vfx, unit, resolve_multishot_basic_attack, damage_ability)" in content
    assert "deal_basic_attack_damage(skill, unit, damage * multishot_ratio, {" in content
    assert "apply_armor_break_on_hit(unit)" in content


def test_runtime_disables_damage_hit_effects_by_default() -> None:
    config = ENTRY_CONFIG.read_text(encoding="utf-8")
    boot = BOOT.read_text(encoding="utf-8")
    assert "damage_hit_effect_enabled = false" in config
    assert "attack_skill_single_effect_mode" not in config
    assert "local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false" in boot
    assert "local basic_chain_particle = basic_attack_vfx.chain_particle" in boot
    assert "or basic_attack_vfx.impact_particle" in boot
    assert "chain_lightning" not in boot


def test_attack_skill_runtime_keeps_stage_particles_and_bindings_enabled() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    assert "attack_skill_single_effect_mode" not in attack_content
    assert "is_projectile_only_mode" not in attack_content
    assert "ability = ability" in attack_content
    assert "notify_auto_active_basic_attack(target)" in attack_content
    assert "notify_bond_attack_skill_cast(skill, target)" in attack_content
    assert "notify_auto_active_skill_cast(skill, target)" in attack_content


def test_attack_skill_projectile_objects_keep_a_single_visible_projectile_effect() -> None:
    for _, projectile_id in ATTACK_SKILL_OBJECTS.values():
        data = json.loads((PROJECTILE_DIR / f"{projectile_id}.json").read_text(encoding="utf-8"))
        assert get_primary_projectile_effect(data["effect_foes"]) not in (None, 0)
        assert get_primary_projectile_effect(data["effect_friend"]) not in (None, 0)
        assert get_projectile_offset_z(data["effect_foes"]) is not None
        assert get_projectile_offset_z(data["effect_friend"]) is not None


def test_basic_attack_projectile_uses_clean_single_effect_payload() -> None:
    data = json.loads((PROJECTILE_DIR / "134267104.json").read_text(encoding="utf-8"))
    assert get_primary_projectile_effect(data["effect_foes"]) == 104656
    assert get_primary_projectile_effect(data["effect_friend"]) == 104656


def test_attack_skills_trim_redundant_runtime_manifest_kv() -> None:
    for skill_id, (ability_id, projectile_id) in ATTACK_SKILL_OBJECTS.items():
        ability = json.loads((ABILITY_DIR / f"{ability_id}.json").read_text(encoding="utf-8"))
        projectile = json.loads((PROJECTILE_DIR / f"{projectile_id}.json").read_text(encoding="utf-8"))

        assert "entry_skill_id" not in ability["kv"]
        assert "entry_projectile_id" not in ability["kv"]
        assert "entry_ability_id" not in ability["kv"]

        assert set(projectile["kv"]).issubset(PROJECTILE_VISUAL_KV_KEYS)
        assert "entry_projectile_speed" in projectile["kv"]
        assert "entry_projectile_time" in projectile["kv"]
        for key, entry in projectile["kv"].items():
            assert kv_value(entry) not in (0, 0.0, "", None), f"{skill_id} projectile kv {key} should skip zero placeholders"


def test_basic_attack_csv_defaults_to_single_target() -> None:
    with ATTACK_SKILLS_CSV.open(encoding="utf-8", newline="") as fp:
        rows = {row["id"]: row for row in csv.DictReader(fp)}

    assert rows["basic_attack"]["base_explosion_ratio"] == "0"
    assert rows["basic_attack"]["base_explosion_radius"] == "0"


def test_basic_attack_followup_damage_chain_stays_enabled() -> None:
    boot = BOOT.read_text(encoding="utf-8")
    assert "attack_skill_single_effect_mode" not in boot
    assert "local function trigger_td_skills_on_hit(data)" in boot
    assert "deal_skill_damage(unit, data.damage * bond_chain_ratio, basic_attack_def, {" in boot


def test_hero_unit_common_attack_hit_effect_is_removed() -> None:
    data = json.loads(HERO_UNIT.read_text(encoding="utf-8"))
    assert data["simple_common_atk"]["hit_effect"]["effect"] == 0
    assert data["simple_common_atk"]["trajectory_speed"] == 4000.0


def test_hero_unit_is_a_clean_archer_shell_without_voice_payload() -> None:
    data = json.loads(HERO_UNIT.read_text(encoding="utf-8"))
    assert data["_ref_"] == 134274912
    assert data["common_atk"]["items"][0] == 134262581
    assert data["common_atk_type"] == 2
    assert data["model"] == 211017
    assert data["sound_event_list"]["items"] == []
    assert data["hero_ability_list"]["items"] == []
    assert data["passive_ability_list"]["items"] == []
    assert data["simple_common_atk"]["ability_animations"]["items"] == ["attack1"]
    assert not HERO_UNIT_RUNTIME.exists()
