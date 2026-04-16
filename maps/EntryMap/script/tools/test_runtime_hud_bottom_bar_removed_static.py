from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD_PATH = ROOT / "ui" / "runtime_hud.lua"
HUD_NODES_PATH = ROOT / "ui" / "runtime_hud_nodes.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def main() -> None:
    hud = read_text(HUD_PATH)
    hud_nodes = read_text(HUD_NODES_PATH)

    for needle, message in (
        ("local right_root = create_panel(", "runtime hud should no longer create the removable bottom bar root"),
        ("local skill_button = create_button(", "runtime hud should no longer create the bottom skill button"),
        ("local bond_button = create_button(", "runtime hud should no longer create the bottom bond button"),
        ("local challenge_buttons = {", "runtime hud should no longer create the bottom challenge buttons"),
        ("local trial_label = create_text(", "runtime hud should no longer create the trial label"),
        ("local action_label = create_text(", "runtime hud should no longer create the action label"),
        ("runtime_hud.skill_button", "runtime hud refresh should no longer update the bottom skill button"),
        ("runtime_hud.bond_button", "runtime hud refresh should no longer update the bottom bond button"),
        ("runtime_hud.challenge_buttons", "runtime hud refresh should no longer update the bottom challenge buttons"),
        ("runtime_hud.right_root:set_visible", "runtime hud visibility should no longer toggle the removed bottom bar"),
        ("get_challenge_summary_text()", "runtime hud should no longer compose the removed bottom challenge summary"),
    ):
        assert_not_contains(hud, needle, message)

    for needle, message in (
        ("bottom_skill_entry =", "runtime hud nodes should no longer bind the removed bottom skill entry"),
        ("bottom_bond_entry =", "runtime hud nodes should no longer bind the removed bottom bond entry"),
        ("bottom_gold_trial_entry =", "runtime hud nodes should no longer bind the removed bottom gold trial entry"),
        ("bottom_wood_trial_entry =", "runtime hud nodes should no longer bind the removed bottom wood trial entry"),
        ("bottom_exp_trial_entry =", "runtime hud nodes should no longer bind the removed bottom exp trial entry"),
        ("bottom_treasure_trial_entry =", "runtime hud nodes should no longer bind the removed bottom treasure trial entry"),
    ):
        assert_not_contains(hud_nodes, needle, message)

    print("runtime hud bottom bar removed static ok")


if __name__ == "__main__":
    main()
