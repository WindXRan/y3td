import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BONDS_INIT_JSON = ROOT / "tables" / "bonds_init.json"
TEMPLATE_LUA = ROOT / "script" / "data" / "object_tables" / "bond_skill_text_templates.lua"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def _trim(value) -> str:
    return "" if value is None else str(value).strip()


def parse_bonds_init() -> tuple[set[str], set[str]]:
    payload = json.loads(_read(BONDS_INIT_JSON))
    rows = payload["table_data"]["data"]
    headers = rows[0]

    bonds: set[str] = set()
    cards: set[str] = set()
    for row in rows[2:]:
        data = {headers[i]: (row[i] if i < len(row) else None) for i in range(len(headers))}
        unlocked = _trim(data.get("是否初始解锁"))
        if unlocked not in ("1", "1.0", "true", "True"):
            continue

        bond_name = _trim(data.get("羁绊所属"))
        activation_desc = _trim(data.get("羁绊激活效果"))
        card_name = _trim(data.get("key"))
        extra_desc = _trim(data.get("额外技能效果"))

        if bond_name and activation_desc and activation_desc != "无":
            bonds.add(bond_name)
        if card_name and extra_desc and extra_desc != "无":
            cards.add(card_name)
    return bonds, cards


def _parse_key_set(block_name: str) -> set[str]:
    text = _read(TEMPLATE_LUA)
    match = re.search(rf"{re.escape(block_name)}\s*=\s*\{{(.*?)\n\}}", text, re.S)
    assert match, f"missing block: {block_name}"
    block = match.group(1)
    return {m.group(1) for m in re.finditer(r"\['([^']+)'\]\s*=", block)}


def main() -> None:
    bond_set, card_set = parse_bonds_init()
    activation_keys = _parse_key_set("local ACTIVATION_DESC_BY_BOND")
    extra_keys = _parse_key_set("local EXTRA_DESC_BY_CARD")

    missing_bonds = sorted(name for name in bond_set if name not in activation_keys)
    missing_cards = sorted(name for name in card_set if name not in extra_keys)

    assert not missing_bonds, f"missing bond activation templates: {missing_bonds}"
    assert not missing_cards, f"missing card extra templates: {missing_cards}"
    template_text = _read(TEMPLATE_LUA)
    assert "继承触发方式与伤害逻辑" not in template_text, (
        "special-effect templates should be concrete, not inherit-placeholders"
    )
    print("bond skill text templates static ok")


if __name__ == "__main__":
    main()
