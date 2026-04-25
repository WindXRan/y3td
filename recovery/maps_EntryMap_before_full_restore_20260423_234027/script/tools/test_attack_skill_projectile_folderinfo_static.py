import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOLDERINFO = ROOT.parent / "editor" / "folderinfo" / "folderinfo_projectile_all.json"

ROOT_FOLDER_UID = "AtkProjRoot20260418"
SKILL_FOLDER_UIDS = {
    134267104: "AtkProjBasic20260418",
    201364743: "AtkProjSwordWave20260418",
    134255909: "AtkProjArcaneLaser20260418",
    134264830: "AtkProjArcaneRay20260418",
    134254402: "AtkProjFrostNova20260418",
    134278613: "AtkProjChainLightning20260418",
    201364744: "AtkProjEarthquake20260418",
    201364745: "AtkProjTornado20260418",
    201364746: "AtkProjElectroNet20260418",
    201364747: "AtkProjMeteor20260418",
    201364748: "AtkProjHurricane20260418",
    201364749: "AtkProjFireball20260418",
    201364750: "AtkProjMoonBlade20260418",
    201364751: "AtkProjLotusFlame20260418",
    201364752: "AtkProjDemonSeal20260418",
    201364753: "AtkProjFlyingSwords20260418",
}


def test_attack_skill_projectile_folderinfo_groups_objects_by_skill() -> None:
    data = json.loads(FOLDERINFO.read_text(encoding="utf-8"))
    folders = {
        tuple_entry["items"][2]: tuple_entry["items"]
        for tuple_entry in data["f"]
        if isinstance(tuple_entry, dict) and tuple_entry.get("__tuple__") is True
    }

    root_folder = folders.get(ROOT_FOLDER_UID)
    assert root_folder is not None
    assert root_folder[3] == "技能投射物"

    for projectile_id, folder_uid in SKILL_FOLDER_UIDS.items():
        folder = folders.get(folder_uid)
        assert folder is not None
        assert folder[0].endswith(f"/{ROOT_FOLDER_UID}")

        mapping = data["d"].get(str(projectile_id))
        assert mapping is not None
        assert mapping["items"][0] == folder_uid
        assert mapping["items"][1] == 0
