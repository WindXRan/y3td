from pathlib import Path


BOOT = Path(__file__).resolve().parents[1] / "runtime" / "boot.lua"


def main() -> None:
    content = BOOT.read_text(encoding="utf-8")
    required_snippets = [
        "local function build_choice_subtitle_text(kind, choice)",
        "return string.format('%s(%s)', bond_name, progress_text)",
        "local CHOICE_CARD_STYLE",
        "local function apply_choice_card_style(card, selected)",
        "set_ui_text_color(title, style.title)",
        "set_ui_text_color(subtitle, style.subtitle)",
        "set_ui_text_color(desc, style.desc)",
        "STATE.choice_panel_selected_index",
        "target:add_fast_event('鼠标-移入'",
        "target:add_fast_event('鼠标-移出'",
    ]
    missing = [snippet for snippet in required_snippets if snippet not in content]
    assert not missing, "missing Choice selected/static snippets: " + ", ".join(missing)
    print("[OK] choice panel selected static passed")


if __name__ == "__main__":
    main()
