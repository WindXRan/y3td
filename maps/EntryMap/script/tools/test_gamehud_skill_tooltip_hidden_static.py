import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAMEHUD_PATH = ROOT / "ui" / "GameHUD.json"


def walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            if isinstance(value, (dict, list)):
                yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)


def find_named_node(data, name):
    for node in walk(data):
        if node.get("name") == name:
            return node
    raise AssertionError(f"node not found: {name}")


def test_gamehud_default_skill_tooltip_starts_hidden():
    gamehud = json.loads(GAMEHUD_PATH.read_text(encoding="utf-8"))

    tips_node = find_named_node(gamehud, "tips_node")
    assert tips_node.get("visible") is False, (
        "GameHUD tips_node is a sample skill tooltip and should stay hidden by "
        "default, otherwise it floats on hover during gameplay."
    )


if __name__ == "__main__":
    test_gamehud_default_skill_tooltip_starts_hidden()
    print("gamehud default skill tooltip hidden ok")
