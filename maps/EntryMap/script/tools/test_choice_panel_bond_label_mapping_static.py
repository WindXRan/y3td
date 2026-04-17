from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "script" / "runtime" / "choice_panel_model.lua"


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def assert_not_contains(content: str, needle: str, message: str) -> None:
    if needle in content:
        raise AssertionError(message)


def test_bond_card_label_mapping_uses_single_card_title_and_set_effect_section() -> None:
    model = MODEL.read_text(encoding="utf-8")

    assert_contains(model, "local function build_bond_card_labels", "choice_panel_model should define bond card label mapping")
    assert_contains(model, "local function get_bond_set_effect_title", "choice_panel_model should derive set effect labels from progress")
    assert_not_contains(model, "local function split_bonus_headline", "bond card labels should not guess single-card names from bonus rows")
    assert_not_contains(model, "append_affix_line(affix_lines, '当前效果'", "bond item desc should not render a separate current-effect section")
    assert_contains(model, "title_text = card_labels.item_title_text,", "bond card title should use the single-card node name")
    assert_contains(model, "progress_text = card_labels.progress_text,", "bond card progress should be mapped separately")
    assert_contains(model, "bonus_lines = card_labels.bonus_lines,", "bond card bonus lines should use de-duplicated lines")
    assert_contains(model, "subtitle_text = card_labels.top_title_text,", "bond item desc subtitle should start with the set name")
    assert_contains(model, "extra_subtitle_text = card_labels.progress_text,", "bond item desc subtitle should append progress text")
    assert_contains(model, "cost_text = quality_text,", "bond item desc should expose readable quality text")


if __name__ == "__main__":
    test_bond_card_label_mapping_uses_single_card_title_and_set_effect_section()
    print("choice panel bond label mapping static ok")
