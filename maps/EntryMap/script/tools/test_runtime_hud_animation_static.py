from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / 'ui' / 'runtime_hud.lua'


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    hud = HUD.read_text(encoding='utf-8')

    for needle, message in [
        ('local function update_top_center_fx(runtime_hud, wave_text, stage_text, boss_display)', 'expected top center animation state helper'),
        ('local function play_top_wave_transition_fx(runtime_hud)', 'expected top wave transition animation helper'),
        ('local function play_top_boss_warning_fx(runtime_hud)', 'expected top boss warning animation helper'),
        ('local function play_top_boss_spawn_fx(runtime_hud)', 'expected top boss spawn animation helper'),
        ("runtime_hud.editor_top_bg_root = resolve_first_ui(", 'expected top bg root binding for animation host'),
        ('start_top_center_breath_fx(runtime_hud)', 'expected top center breathing animation bootstrap'),
        ('update_top_center_fx(runtime_hud, wave_text, stage_text, boss_display)', 'expected top center animation refresh hook'),
        ('local function ensure_growth_weapon_slot_fx(runtime_hud)', 'expected growth weapon slot fx bootstrap helper'),
        ('local function set_growth_weapon_slot_hover_fx(runtime_hud, hovered)', 'expected growth weapon hover animation helper'),
        ('local function update_growth_weapon_ready_fx(runtime_hud)', 'expected growth weapon ready pulse helper'),
        ('runtime_hud.growth_weapon_ready_pulse_glow = pulse_glow', 'expected growth weapon pulse glow cache'),
        ('runtime_hud.growth_weapon_hover_glow = hover_glow', 'expected growth weapon hover glow cache'),
        ('set_growth_weapon_slot_hover_fx(runtime_hud, true)', 'expected hover enter animation hook'),
        ('set_growth_weapon_slot_hover_fx(runtime_hud, false)', 'expected hover leave animation hook'),
        ('local function format_growth_weapon_upgrade_bonus_text(next_level)', 'expected upgrade bonus text formatter'),
        ('runtime_hud.growth_weapon_upgrade_shine = shine', 'expected upgrade sweep light cache'),
        ('runtime_hud.growth_weapon_upgrade_bonus_label = bonus_label', 'expected upgrade bonus float text cache'),
        ('fx.shine:set_anim_pos(', 'expected upgrade sweep light animation'),
        ('fx.bonus_label:set_anim_opacity(255, 0, 0.45, 0)', 'expected upgrade bonus float fade animation'),
    ]:
        require(hud, needle, message)

    print('[OK] runtime hud animation static passed')


if __name__ == '__main__':
    main()
