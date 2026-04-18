import json
import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ATTACK_SKILLS = ROOT / "runtime" / "attack_skills.lua"
BOOT = ROOT / "runtime" / "boot.lua"
ENTRY_CONFIG = ROOT / "config" / "entry_config.lua"
HERO_UNIT = ROOT.parent / "editor_table" / "editorunit" / "134274912.json"
PROJECTILE_DIR = ROOT.parent / "editor_table" / "projectileall"
ATTACK_SKILL_VFX_CSV = ROOT / "data_csv" / "attack_skill_vfx.csv"
ATTACK_SKILL_PROJECTILES = {
    "basic_attack": 134267104,
    "sword_wave": 201364743,
    "arcane_ray": 134264830,
    "fireball": 201364749,
    "moon_blade": 201364750,
    "flying_swords": 201364753,
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


def test_basic_attack_primary_hit_no_longer_uses_common_attack_visuals() -> None:
    content = ATTACK_SKILLS.read_text(encoding="utf-8")
    assert "deal_basic_attack_damage(skill, target, damage, {\n          common_attack = false," in content
    assert "local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false" in content
    assert "ability = hit_effect_enabled" in content


def test_runtime_disables_damage_hit_effects_by_default() -> None:
    config = ENTRY_CONFIG.read_text(encoding="utf-8")
    boot = BOOT.read_text(encoding="utf-8")
    assert "damage_hit_effect_enabled = false" in config
    assert "attack_skill_single_effect_mode = true" in config
    assert "local hit_effect_enabled = CONFIG.damage_hit_effect_enabled ~= false" in boot
    assert "local basic_chain_particle = basic_attack_vfx.chain_particle" in boot
    assert "or basic_attack_vfx.impact_particle" in boot
    assert "chain_lightning" not in boot


def test_attack_skill_runtime_short_circuits_stage_particles_in_single_effect_mode() -> None:
    attack_content = ATTACK_SKILLS.read_text(encoding="utf-8")
    assert "if CONFIG.attack_skill_single_effect_mode == true then" in attack_content
    assert "return nil, nil, nil, nil, nil" in attack_content
    assert "ability = CONFIG.attack_skill_single_effect_mode == true and nil or ability" in attack_content
    assert "if is_projectile_only_mode() then\n      return 0, 0" in attack_content
    assert "if is_projectile_only_mode() then\n      return" in attack_content


def test_attack_skill_projectile_objects_keep_a_single_visible_projectile_effect() -> None:
    for projectile_id in ATTACK_SKILL_PROJECTILES.values():
        data = json.loads((PROJECTILE_DIR / f"{projectile_id}.json").read_text(encoding="utf-8"))
        assert get_primary_projectile_effect(data["effect_foes"]) not in (None, 0)
        assert get_primary_projectile_effect(data["effect_friend"]) not in (None, 0)
        assert get_projectile_offset_z(data["effect_foes"]) == 100.0
        assert get_projectile_offset_z(data["effect_friend"]) == 100.0


def test_basic_attack_projectile_uses_clean_single_effect_payload() -> None:
    data = json.loads((PROJECTILE_DIR / "134267104.json").read_text(encoding="utf-8"))
    assert get_primary_projectile_effect(data["effect_foes"]) == 101175
    assert get_primary_projectile_effect(data["effect_friend"]) == 101175


def test_attack_skills_use_dedicated_projectile_rows() -> None:
    with ATTACK_SKILL_VFX_CSV.open(encoding="utf-8", newline="") as fp:
        rows = {row["skill_id"]: row for row in csv.DictReader(fp)}

    assert rows["basic_attack"]["projectile_key"] == "134267104"
    assert rows["sword_wave"]["projectile_key"] == "201364743"
    assert rows["arcane_ray"]["projectile_key"] == "134264830"
    assert rows["moon_blade"]["projectile_key"] == "201364750"
    assert rows["fireball"]["projectile_key"] == "201364749"
    assert rows["flying_swords"]["projectile_key"] == "201364753"


def test_single_effect_mode_disables_basic_attack_followup_damage_chain() -> None:
    boot = BOOT.read_text(encoding="utf-8")
    assert "if CONFIG.attack_skill_single_effect_mode == true then" in boot


def test_hero_unit_common_attack_hit_effect_is_removed() -> None:
    data = json.loads(HERO_UNIT.read_text(encoding="utf-8"))
    assert data["simple_common_atk"]["hit_effect"]["effect"] == 0
