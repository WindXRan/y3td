import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECTILE_DIR = ROOT / "editor_table" / "projectileall"
VISUAL_LUA = ROOT / "script" / "data" / "object_tables" / "bond_visual_editor_ids.lua"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def extract_model_id(projectile: dict) -> int | None:
    effect = projectile.get("effect_foes")
    items = None
    if isinstance(effect, dict):
        items = effect.get("items")
    elif isinstance(effect, list):
        items = effect
    if not isinstance(items, list) or len(items) < 6:
        return None
    tail = items[5]
    if isinstance(tail, dict):
        value = tail.get("model")
        return int(value) if isinstance(value, (int, float)) else None
    return None


def parse_visual_projectile_keys() -> dict[str, int]:
    text = VISUAL_LUA.read_text(encoding="utf-8-sig")
    result: dict[str, int] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("['") or "projectile_key =" not in line:
            continue
        name = line.split("']", 1)[0].replace("['", "", 1)
        rhs = line.split("projectile_key =", 1)[1]
        num = ""
        for ch in rhs:
            if ch.isdigit():
                num += ch
            elif num:
                break
        if num:
            result[name] = int(num)
    return result


def test_bond_projectile_models_are_not_all_arrow() -> None:
    keys = parse_visual_projectile_keys()
    focus = ["龙骑士", "枪炮师", "雷电法王", "寒冰法师", "冰霜法师"]
    models = {}
    for bond_name in focus:
        key = keys.get(bond_name)
        assert key is not None, f"missing projectile key for bond: {bond_name}"
        path = PROJECTILE_DIR / f"{key}.json"
        assert path.exists(), f"projectile json not found: {path}"
        model = extract_model_id(read_json(path))
        assert model is not None, f"model id missing in projectile: {key}"
        models[bond_name] = model

    unique_models = set(models.values())
    assert len(unique_models) >= 3, f"focus bonds should not share one model: {models}"
    assert 103014 not in unique_models, f"focus bonds still using old arrow model 103014: {models}"


if __name__ == "__main__":
    test_bond_projectile_models_are_not_all_arrow()
    print("bond projectile visual static ok")

