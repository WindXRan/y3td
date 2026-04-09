local player = y3.player(1)
local required_paths = {
  'GameHUD.hud_root',
  'GameHUD.hud_root.top_battle_cluster',
  'GameHUD.hud_root.left_shortcut_panel',
  'GameHUD.hud_root.right_tracker_panel',
  'GameHUD.hud_root.challenge_strip',
  'GameHUD.hud_root.bottom_action_bar',
  'GameHUD.hud_root.bottom_action_bar.skill_hotbar',
  'GameHUD.hud_root.bottom_action_bar.primary_action_cluster',
  'GameHUD.hud_root.bottom_action_bar.secondary_action_cluster',
}

for _, path in ipairs(required_paths) do
  local ui = y3.ui.get_ui(player, path)
  if not ui then
    error('[HUD_SMOKE] missing ui path: ' .. path)
  end
end

print('[HUD_SMOKE] all required HUD nodes resolved')
