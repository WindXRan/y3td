from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_PATH = ROOT / "runtime" / "audio.lua"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def assert_contains(content: str, needle: str, message: str) -> None:
    if needle not in content:
        raise AssertionError(message)


def test_audio_runtime_supports_direct_sound_keys_and_candidate_playback_fallback() -> None:
    audio = read_text(AUDIO_PATH)

    assert_contains(audio, "local LOCAL_AUDIO_IDS = {", "audio runtime should define a local sound key palette")
    assert_contains(audio, "local AUDIO_KEY_NAME_ALIASES = {", "audio runtime should define alias names for custom audio keys")
    assert_contains(audio, "[LOCAL_AUDIO_IDS.bgm_loop] = { 'BGM' }", "audio runtime should keep the BGM editor name as a fallback alias")
    assert_contains(audio, "local function prepend_audio_ids(local_ids, fallback_ids)", "audio runtime should prepend local sound candidates ahead of legacy fallback ids")
    assert_contains(audio, "local ATTACK_SKILL_LOCAL_STAGE_IDS = {", "audio runtime should define reusable local attack-skill stage candidates")
    assert_contains(audio, "local function normalize_audio_candidates(audio_ids)", "audio runtime should normalize scalar and list audio ids")
    assert_contains(audio, "local numeric_id = tonumber(cache_key)", "audio runtime should treat numeric sound keys as direct playable candidates")
    assert_contains(audio, "runtime.key_cache[cache_key] = numeric_id", "audio runtime should cache numeric sound keys without str_to_audio_key")
    assert_contains(audio, "key_alias_cache = {}", "audio runtime should keep a separate cache for editor-name audio aliases")
    assert_contains(audio, "local function resolve_audio_key_aliases(audio_id)", "audio runtime should resolve editor-name audio aliases when numeric playback fails")
    assert_contains(audio, "local alias_keys = resolve_audio_key_aliases(audio_id)", "audio runtime should append alias-derived audio keys behind direct numeric candidates")
    assert_contains(audio, "local function play_audio_candidates(audio_ids, audio_label, play_once)", "audio runtime should attempt each resolved candidate until playback succeeds")
    assert_contains(audio, "local failure_type = resolved_any and 'play' or 'resolve'", "audio runtime should distinguish resolve failures from playback failures after trying all candidates")
    assert_contains(audio, "wave_start = prepend_audio_ids({ LOCAL_AUDIO_IDS.impact, LOCAL_AUDIO_IDS.attack_alt }", "wave start should use local sound objects before resource-id fallbacks")
    assert_contains(audio, "cast = { ids = prepend_audio_ids(ATTACK_SKILL_LOCAL_STAGE_IDS.cast, { '125774', '125771' })", "attack skill stage audio should prepend local cast candidates before legacy ids")


if __name__ == "__main__":
    test_audio_runtime_supports_direct_sound_keys_and_candidate_playback_fallback()
    print("runtime audio resolution static ok")
