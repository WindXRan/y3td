import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAP_ROOT = ROOT.parent
ABILITY_DIR = MAP_ROOT / "editor_table" / "abilityall"
ATTACK_RUNTIME = ROOT / "runtime" / "attack_skills.lua"
PRESENTATION_TABLE = ROOT / "data" / "object_tables" / "attack_skill_presentation_profiles.lua"
ABILITY_IDS = [
    201390001,
    201390002,
    201390003,
    201390004,
    201390005,
    201390006,
    201390007,
    201390008,
    201390009,
    201390010,
    201390011,
    201390012,
    201390013,
    201390014,
    201390015,
    201390016,
]


def kv_value(entry: object) -> object:
    if isinstance(entry, dict) and "value" in entry:
        return entry["value"]
    return entry


def _load_attack_vfx_effect_ids() -> set[int]:
    effect_ids: set[int] = set()
    for ability_id in ABILITY_IDS:
        data = json.loads((ABILITY_DIR / f"{ability_id}.json").read_text(encoding="utf-8"))
        kv = data.get("kv") or {}
        for field in (
            "entry_cast_effect_id",
            "entry_impact_effect_id",
            "entry_explosion_effect_id",
            "entry_charge_effect_id",
            "entry_chain_effect_id",
        ):
            value = int(kv_value(kv.get(field)) or 0)
            if value > 0:
                effect_ids.add(value)
    return effect_ids


def test_attack_skill_vfx_ids_have_explicit_dependencies() -> None:
    expected = _load_attack_vfx_effect_ids()
    assert expected == {
        101175,
        102498,
        102541,
        102543,
        102657,
        102704,
        102705,
        102740,
        102750,
        102760,
        102780,
        102877,
        102988,
        103008,
    }


def test_attack_skill_runtime_uses_presentation_profiles() -> None:
    attack_runtime = ATTACK_RUNTIME.read_text(encoding="utf-8")
    presentation_table = PRESENTATION_TABLE.read_text(encoding="utf-8")

    assert "local PresentationProfiles = require 'data.tables.attack_skill_presentation_profiles'" in attack_runtime
    assert "local function get_skill_presentation_family(skill)" in attack_runtime
    assert "local function get_skill_stage_profile(skill, stage)" in attack_runtime
    assert "play_skill_particle_on_unit(skill, STATE.hero, 'cast')" in attack_runtime
    assert "play_skill_particle_on_point(skill, center, 'burst'" in attack_runtime
    assert "eca_projectile_hit" in presentation_table
    assert "eca_charge_burst" in presentation_table

