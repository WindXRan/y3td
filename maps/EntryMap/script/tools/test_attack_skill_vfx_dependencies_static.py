import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAP_ROOT = ROOT.parent
ATTACK_VFX_CSV = ROOT / "data_csv" / "attack_skill_vfx.csv"
MANUAL_DEP = MAP_ROOT / "manualdependence.json"
CLOUD_DEP = MAP_ROOT / "cloudresdependence.json"
ATTACK_RUNTIME = ROOT / "runtime" / "attack_skills.lua"
PRESENTATION_TABLE = ROOT / "data" / "object_tables" / "attack_skill_presentation_profiles.lua"


def _load_attack_vfx_effect_ids() -> set[int]:
    fields = [
        "cast_particle",
        "impact_particle",
        "explosion_particle",
        "charge_particle",
        "chain_particle",
    ]
    effect_ids: set[int] = set()
    with ATTACK_VFX_CSV.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            for field in fields:
                raw = (row.get(field) or "").strip()
                if raw and raw != "0":
                    effect_ids.add(int(float(raw)))
    return effect_ids


def _load_manual_effect_ids() -> set[int]:
    data = json.loads(MANUAL_DEP.read_text(encoding="utf-8"))
    return {int(value) for value in data.get("editor_effect", [])}


def _load_cloud_effect_ids() -> set[int]:
    data = json.loads(CLOUD_DEP.read_text(encoding="utf-8"))
    items = data.get("editor_effect", {}).get("items", [])
    return {int(value) for value in items}


def test_attack_skill_vfx_ids_have_explicit_dependencies() -> None:
    expected = _load_attack_vfx_effect_ids()
    assert expected == set()


def test_attack_skill_runtime_uses_presentation_profiles() -> None:
    attack_runtime = ATTACK_RUNTIME.read_text(encoding="utf-8")
    presentation_table = PRESENTATION_TABLE.read_text(encoding="utf-8")

    assert "local PresentationProfiles = require 'data.object_tables.attack_skill_presentation_profiles'" in attack_runtime
    assert "local function get_skill_presentation_family(skill)" in attack_runtime
    assert "local function get_skill_stage_profile(skill, stage)" in attack_runtime
    assert "play_skill_particle_on_unit(skill, STATE.hero, 'cast')" in attack_runtime
    assert "play_skill_particle_on_point(skill, center, 'burst'" in attack_runtime
    assert "eca_projectile_hit" in presentation_table
    assert "eca_charge_burst" in presentation_table
