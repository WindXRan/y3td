from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "data_csv" / "attreffect.csv"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_mainline_task_attreffect_uses_project_damage_vocab() -> None:
    source = read_text(CSV_PATH)

    assert "source_type,source_id,order_index,effect_kind,effect_key,value" in source
    assert "mainline_task,1-5" in source
    assert "物理伤害" in source
    assert "魔法伤害" in source

    for banned in [
        "physical_damage_pct",
        "magic_damage_pct",
        "energy_damage_pct",
        "ice_damage_pct",
        "lightning_damage_pct",
        "wind_damage_pct",
    ]:
        assert banned not in source, f"unexpected legacy damage key remains: {banned}"


if __name__ == "__main__":
    test_mainline_task_attreffect_uses_project_damage_vocab()
    print("mainline task rewards damage vocab static ok")
