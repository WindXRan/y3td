from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "runtime" / "boot.lua"
HUD_PATH = ROOT / "ui" / "runtime_hud.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_boot_exposes_attack_skill_slot_text_to_runtime_hud() -> None:
    boot = read_text(BOOT_PATH)

    assert_contains(
        boot,
        "build_attack_skill_slot_text = function(slot)",
        "boot should pass attack skill slot text builder into runtime hud env",
    )


def test_runtime_hud_refreshes_skill_slot_texts() -> None:
    hud = read_text(HUD_PATH)

    assert_contains(
        hud,
        "runtime_hud.skill_slots",
        "runtime hud should keep skill slot node bindings",
    )
    assert_contains(
        hud,
        "env.build_attack_skill_slot_text",
        "runtime hud should consume attack skill slot text builder",
    )
    assert_contains(
        hud,
        "slot_nodes.text:set_text",
        "runtime hud should write the rendered slot label into each skill slot",
    )
    assert_contains(
        hud,
        "slot_nodes.meta:set_text",
        "runtime hud should write meta text into each skill slot",
    )


if __name__ == "__main__":
    test_boot_exposes_attack_skill_slot_text_to_runtime_hud()
    test_runtime_hud_refreshes_skill_slot_texts()
    print("runtime hud skill slot static ok")
