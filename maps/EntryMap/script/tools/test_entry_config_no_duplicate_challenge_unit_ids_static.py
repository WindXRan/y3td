from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENTRY_CONFIG = ROOT / "config" / "entry_config.lua"


def assert_not_contains(text: str, needle: str, message: str) -> None:
    if needle in text:
        raise AssertionError(message)


def main() -> None:
    text = ENTRY_CONFIG.read_text(encoding="utf-8")
    assert_not_contains(
        text,
        "challenges = {",
        "entry_config.lua should not keep duplicate challenge unit_ids config",
    )
    print("entry_config duplicate challenge unit_ids removed")


if __name__ == "__main__":
    main()
