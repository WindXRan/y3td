import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAMEHUD_PATH = ROOT / "ui" / "GameHUD.json"
PREFAB_GAMEHUD_PATH = ROOT / "ui" / "prefab" / "GameHUD.json"


def walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            if isinstance(value, (dict, list)):
                yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)


def find_by_uid(data, uid):
    for node in walk(data):
        if node.get("uid") == uid:
            return node
    raise AssertionError(f"node uid not found: {uid}")


def test_gamehud_keeps_0410_top_hud_anchor_values():
    gamehud = json.loads(GAMEHUD_PATH.read_text(encoding="utf-8"))

    exp_node = find_by_uid(gamehud, "b49def45-49b7-4c74-8855-9dfdf3b9e82c")
    hp_bar_node = find_by_uid(gamehud, "c4a1f7bc-69b3-42df-b5f7-c6557af7aa9e")

    assert exp_node["adapter_option"] == [
        False,
        True,
        True,
        True,
        127.9699,
        -4.9999,
        159.6685,
        -504.9985,
    ]
    assert exp_node["pos_data"]["items"] == [400.6685, 3.0001, 293.1649, 2.1588, 1, 1]
    assert hp_bar_node["pos_data"]["items"] == [563.0002, 29.0, 57.6254, 18.3544, 1, 1]


def test_prefab_gamehud_keeps_0410_jiban_anchor_values():
    prefab_gamehud = json.loads(PREFAB_GAMEHUD_PATH.read_text(encoding="utf-8"))

    expected = {
        "108e384c-856b-4a20-b2ca-92d24aba8dd4": [-77.7777, 50.0, -77.7777, 50.0, 0, 0],
        "6a76c7e4-a020-4733-989b-347943b4b25a": [-77.7777, 50.0, -17.2598, 50.0, 0, 0],
        "77adcd24-89dd-4127-887f-12af827283ec": [-77.7777, 50.0, -17.2598, 50.0, 0, 0],
        "cf79d629-75fd-427e-85e0-68f105609e33": [-77.7777, 50.0, -17.2598, 50.0, 0, 0],
        "462ac7ef-6a73-4b67-b09e-913f48f9a51c": [-77.7777, 50.0, -17.2598, 50.0, 0, 0],
    }

    found = {node.get("prefab_sub_key"): node for node in walk(prefab_gamehud) if isinstance(node, dict)}
    for sub_key, items in expected.items():
        node = found.get(sub_key)
        assert node is not None, f"prefab_sub_key not found: {sub_key}"
        assert node["pos_data"]["items"] == items


if __name__ == "__main__":
    test_gamehud_keeps_0410_top_hud_anchor_values()
    test_prefab_gamehud_keeps_0410_jiban_anchor_values()
