import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LUA_PATH = ROOT / "script" / "data" / "object_tables" / "bond_effect_runtime_rules.lua"


def _read() -> str:
    return LUA_PATH.read_text(encoding="utf-8-sig")


def _extract_profiles_root(text: str) -> str:
    root = re.search(r"M\.summon_inherit_profiles\s*=\s*\{(.*?)\n\}", text, re.S)
    assert root, "missing SUMMON_INHERIT_PROFILES block"
    return root.group(1)


def _extract_profile_block(root_text: str, kind: str) -> str:
    pattern = rf"{kind}\s*=\s*\{{(.*?)\}}"
    match = re.search(pattern, root_text, re.S)
    assert match, f"missing summon inherit profile: {kind}"
    return match.group(1)


def _extract_number(block: str, field: str) -> float:
    match = re.search(rf"{field}\s*=\s*([0-9]+(?:\.[0-9]+)?)", block)
    assert match, f"missing field {field} in profile block: {block}"
    return float(match.group(1))


def test_summon_inherit_profiles_are_distinct() -> None:
    text = _read()
    root_text = _extract_profiles_root(text)
    kinds = ["magic_deer", "magic_bear", "hawk", "skeleton"]
    attack_ratios = {}
    hp_ratios = {}
    for kind in kinds:
        block = _extract_profile_block(root_text, kind)
        attack_ratios[kind] = _extract_number(block, "attack_ratio")
        hp_ratios[kind] = _extract_number(block, "hp_ratio")

    assert len(set(attack_ratios.values())) > 1, f"attack ratios are unexpectedly identical: {attack_ratios}"
    assert len(set(hp_ratios.values())) > 1, f"hp ratios are unexpectedly identical: {hp_ratios}"


if __name__ == "__main__":
    test_summon_inherit_profiles_are_distinct()
    print("bond summon inherit profiles static ok")
