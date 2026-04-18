from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "script" / "runtime" / "choice_panel_model.lua"


def main() -> None:
    model = MODEL.read_text(encoding="utf-8")

    if "终局进化" in model:
        raise AssertionError("upgrade item desc should not keep evolution copy")
    if "skill_def.evolution_name" in model:
        raise AssertionError("upgrade item desc should not consume evolution_name anymore")

    print("choice panel upgrade desc no evolution static ok")


if __name__ == "__main__":
    main()
