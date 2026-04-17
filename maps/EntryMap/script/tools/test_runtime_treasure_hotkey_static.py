from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUT_EVENTS_PATH = ROOT / "runtime" / "input_events.lua"


def main() -> None:
    source = INPUT_EVENTS_PATH.read_text(encoding="utf-8")

    assert "y3.game:event('键盘-按下', 'V', function()" in source
    assert "try_treasure_entry()" in source

    print('[OK] runtime treasure hotkey static passed')


if __name__ == '__main__':
    main()
