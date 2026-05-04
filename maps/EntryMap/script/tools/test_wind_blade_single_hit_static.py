from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FRAMEWORK = ROOT / "runtime" / "skill_framework.lua"
GENERATED = ROOT / "runtime" / "generated_skills.lua"
SAMPLE = ROOT / "runtime" / "sample_skills.lua"


def extract_block(text: str, skill_id: str) -> str:
    marker = f"id = '{skill_id}'"
    start = text.index(marker)
    next_skill = text.find("\n    {\n      id = ", start + len(marker))
    if next_skill == -1:
        next_skill = text.find("\n  }\nend", start)
    return text[start:next_skill]


def main() -> None:
    framework = FRAMEWORK.read_text(encoding="utf-8")
    generated = GENERATED.read_text(encoding="utf-8")
    sample = SAMPLE.read_text(encoding="utf-8")

    wind_blade = extract_block(generated, "wind_blade")
    tornado = extract_block(generated, "tornado")

    assert "tick_interval" not in wind_blade, "wind_blade should not opt into repeated pierce hits"
    assert "tick_interval = 0.26" in tornado, "tornado should keep repeated pierce tick behavior"
    assert "has_tick_interval = cfg.timeline and cfg.timeline.tick_interval ~= nil or false" in framework
    assert "local hit_same = skill.timeline.has_tick_interval and tick_interval > 0" in framework
    assert "local function get_unit_hit_key(unit)" in framework
    assert "handle:" in framework, "hit key fallback should use stable handle text"
    assert "row.id == 'wind_blade'" in sample
    assert "built.timeline.tick_interval = nil" in sample

    print("[PASS] test_wind_blade_single_hit_static: wind_blade pierce hits each unit once")


if __name__ == "__main__":
    main()
