import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BONDS_INIT_JSON = ROOT / "tables" / "bonds_init.json"
CORE_LUA = ROOT / "script" / "runtime" / "bond_modifier_core_effects.lua"
SPECIAL_LUA = ROOT / "script" / "runtime" / "bond_modifier_special_effects.lua"
EFFECTS_LUA = ROOT / "script" / "runtime" / "bond_modifier_effects.lua"
RULES_LUA = ROOT / "script" / "data" / "object_tables" / "bond_effect_runtime_rules.lua"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def _trim(value) -> str:
    return "" if value is None else str(value).strip()


def parse_initial_cards_and_bonds() -> tuple[set[str], set[str]]:
    payload = json.loads(_read(BONDS_INIT_JSON))
    rows = payload["table_data"]["data"]
    headers = rows[0]

    card_names: set[str] = set()
    bond_names: set[str] = set()
    for row in rows[2:]:
        data = {headers[i]: (row[i] if i < len(row) else None) for i in range(len(headers))}
        unlocked = _trim(data.get("是否初始解锁"))
        if unlocked not in ("1", "1.0", "true", "True"):
            continue

        bond_name = _trim(data.get("羁绊所属"))
        activation_desc = _trim(data.get("羁绊激活效果"))
        extra_desc = _trim(data.get("额外技能效果"))
        card_name = _trim(data.get("key"))

        if bond_name and activation_desc and activation_desc != "无":
            bond_names.add(bond_name)
        if card_name and extra_desc and extra_desc != "无":
            card_names.add(card_name)
    return card_names, bond_names


def parse_card_refs() -> set[str]:
    refs: set[str] = set()
    for text in (_read(CORE_LUA), _read(SPECIAL_LUA), _read(EFFECTS_LUA)):
        for m in re.finditer(r"has_card_effect\s*\(\s*runtime\s*,\s*'([^']+)'\s*\)", text):
            refs.add(m.group(1))
        for m in re.finditer(r"has_any_card_effect\s*\(\s*runtime\s*,\s*\{([^}]*)\}\s*\)", text, re.S):
            for m2 in re.finditer(r"'([^']+)'", m.group(1)):
                refs.add(m2.group(1))
    return refs


def parse_alias_pairs() -> dict[str, str]:
    text = _read(EFFECTS_LUA)
    pairs: dict[str, str] = {}
    in_alias_block = False
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("local CARD_NAME_ALIASES = {"):
            in_alias_block = True
            continue
        if in_alias_block and line.startswith("}"):
            break
        if not in_alias_block:
            continue
        m = re.search(r"\['([^']+)'\]\s*=\s*'([^']+)'", line)
        if m:
            pairs[m.group(1)] = m.group(2)
    return pairs


def parse_core_bond_refs() -> set[str]:
    text = _read(CORE_LUA)
    return {m.group(1) for m in re.finditer(r"bond_name\s*==\s*'([^']+)'", text)}


def test_extra_card_effects_are_covered() -> None:
    card_names, _ = parse_initial_cards_and_bonds()
    refs = parse_card_refs()
    aliases = parse_alias_pairs()

    unresolved = []
    for name in sorted(card_names):
        if name in refs:
            continue

        alias_to = aliases.get(name)
        if alias_to and alias_to in refs:
            continue

        reverse_match = any(alias_target == name and alias_name in refs for alias_name, alias_target in aliases.items())
        if reverse_match:
            continue

        unresolved.append(name)

    assert not unresolved, f"extra card effects not wired in runtime files: {unresolved}"


def test_activation_bonds_are_covered() -> None:
    _, bond_names = parse_initial_cards_and_bonds()
    refs = parse_core_bond_refs()
    passive_only_bonds = {"刀锋战士", "全能骑士"}
    missing = sorted(name for name in bond_names if name not in refs and name not in passive_only_bonds)
    assert not missing, f"activation bond effects missing in core runtime: {missing}"


def test_lightning_not_forced_to_five_targets() -> None:
    text = _read(EFFECTS_LUA)
    assert "['雷电法王'] = { lightning_target_count = 5" not in text, (
        "雷电法王 should not be hard-forced to 5 targets in SET_RUNTIME_BONUSES"
    )


def test_sword_master_timing_is_0p2_x_15() -> None:
    text = _read(RULES_LUA)
    assert "['剑宗'] = {" in text, "missing sword master rule block"
    assert "tick_count = 15" in text, "剑宗 tick_count should be 15"
    assert "tick_interval = 0.20" in text, "剑宗 tick_interval should be 0.20"


if __name__ == "__main__":
    test_extra_card_effects_are_covered()
    test_activation_bonds_are_covered()
    test_lightning_not_forced_to_five_targets()
    test_sword_master_timing_is_0p2_x_15()
    print("bond modifier skill coverage static ok")
