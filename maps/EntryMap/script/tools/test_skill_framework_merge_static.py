from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def assert_contains(text: str, needle: str, label: str) -> None:
    assert needle in text, f"missing {label}: {needle}"


def main() -> None:
    framework = read_text("runtime/skill_framework.lua")
    skills = read_text("runtime/skills.lua")
    generated = read_text("runtime/generated_skills.lua")
    sample = read_text("runtime/sample_skills.lua")
    attack = read_text("runtime/attack_skills.lua")
    boot = read_text("runtime/boot.lua")

    assert_contains(framework, "OLD_TO_NEW_PATTERN", "legacy pattern mapping")
    assert_contains(framework, "VALID_PATTERN = { projectile = true, area = true }", "two public patterns")
    assert_contains(framework, "projectile = { base = true, burst = true, pierce = true, chain = true }", "projectile burst support")
    assert_contains(framework, "projectile.burst", "projectile burst execution branch")
    assert_contains(framework, "sub_behavior", "sub behavior normalization")
    assert_contains(framework, "function api.get_def", "skill definition accessor")
    assert_contains(framework, "function api.reset_runtime", "runtime reset hook")

    assert_contains(skills, "sf_projectile", "projectile base skill")
    assert_contains(skills, "sf_area", "area base skill")
    assert_contains(skills, "sub_behavior", "factory sub behavior passthrough")

    assert_contains(generated, "OLD_PATTERN_SUB_BEHAVIOR", "CSV legacy behavior mapping")
    assert_contains(generated, "row.sub_behavior", "CSV sub behavior parsing")

    assert_contains(sample, "env.skill_framework", "external framework injection")
    assert_contains(sample, "reset_framework_runtime", "sample runtime reset bridge")
    assert_contains(sample, "find_sample_id('projectile', 'burst')", "fireball legacy alias should resolve to projectile burst")
    assert_contains(sample, "find_sample_id('projectile', 'pierce')", "legacy sample alias should not depend on CSV order")

    assert_contains(attack, "active_skill_runtime", "formal active skill runtime")
    assert_contains(attack, "update_active_skills", "formal active skill updater")
    assert_contains(attack, "set_active_skill_ids", "explicit active skill setter")
    assert "STATE.active_skill_ids" not in attack, "registry must not be treated as the active skill list"

    assert_contains(boot, "SkillFrameworkSystem.create", "shared skill framework boot wiring")
    assert_contains(boot, "create_offset_point = function", "line projectile offset helper injection")

    csv_path = ROOT / "data_csv/element_skills.csv"
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert rows, "element_skills.csv should keep sample rows"
    assert "sub_behavior" in rows[0], "element_skills.csv must expose sub_behavior column"
    expected = {
        "fireball": ("projectile", "burst"),
        "chain_lightning": ("projectile", "chain"),
        "ice_lance": ("projectile", "pierce"),
    }
    by_id = {row["id"]: row for row in rows}
    for skill_id, (pattern, sub_behavior) in expected.items():
        row = by_id[skill_id]
        assert row["pattern"] == pattern, f"{skill_id} pattern should be {pattern}"
        assert row["sub_behavior"] == sub_behavior, f"{skill_id} sub_behavior should be {sub_behavior}"

    print("[OK] skill framework merge static smoke passed")


if __name__ == "__main__":
    main()
