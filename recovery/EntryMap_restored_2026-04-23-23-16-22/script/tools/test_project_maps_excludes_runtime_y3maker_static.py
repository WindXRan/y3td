from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
PROJECT_MAPS_DIR = REPO_ROOT / "maps"


def test_project_maps_directory_excludes_runtime_y3maker() -> None:
    runtime_dir = PROJECT_MAPS_DIR / ".y3maker"
    assert not runtime_dir.exists(), (
        "maps/.y3maker is a runtime helper directory and must not live under "
        "the project maps root, otherwise project map enumeration may treat it "
        "as a map entry."
    )


if __name__ == "__main__":
    test_project_maps_directory_excludes_runtime_y3maker()
    print("project maps static layout ok")
