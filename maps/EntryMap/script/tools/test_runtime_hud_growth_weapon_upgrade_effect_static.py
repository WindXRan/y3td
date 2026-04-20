from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / 'ui' / 'runtime_hud.lua'
PROMPTS = ROOT / 'runtime' / 'battle_event_prompts.lua'


def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)


def main() -> None:
    hud = HUD.read_text(encoding='utf-8')
    prompts = PROMPTS.read_text(encoding='utf-8')

    for needle, message in [
        ('local function clear_growth_weapon_upgrade_fx(runtime_hud)', 'expected growth weapon fx clear helper'),
        ('local function ensure_growth_weapon_upgrade_fx(runtime_hud)', 'expected growth weapon fx node bootstrap helper'),
        ('local function play_growth_weapon_upgrade_fx(runtime_hud, next_level)', 'expected growth weapon fx playback helper'),
        ("runtime_hud.growth_weapon_upgrade_flash = flash", 'expected growth weapon flash node cache'),
        ("runtime_hud.growth_weapon_upgrade_label = label", 'expected growth weapon floating level label cache'),
        ("fx.flash:set_anim_scale(0.82, 0.82, 1.42, 1.42, 0.28, 0)", 'expected flash scale animation'),
        ("fx.label:set_anim_pos(fx.width * 0.5, fx.height * 0.42, fx.width * 0.5, fx.height * 0.78, 0.42, 0)", 'expected floating level text animation'),
        ("fx.host:set_anim_scale(1.0, 1.0, 1.12, 1.12, 0.10, 0)", 'expected slot pulse scale animation'),
        ('play_growth_weapon_upgrade_effect = function(next_level)', 'expected runtime hud public upgrade effect API'),
        ('clear_growth_weapon_upgrade_fx(runtime_hud)', 'expected upgrade fx to reset when hud hides'),
    ]:
        require(hud, needle, message)

    require(
        prompts,
        'runtime_hud_system.play_growth_weapon_upgrade_effect(next_level)',
        'expected growth weapon upgrade success to trigger hud effect'
    )

    print('[OK] runtime hud growth weapon upgrade effect static passed')


if __name__ == '__main__':
    main()
