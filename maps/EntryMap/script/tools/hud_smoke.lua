local player = y3.player(1)
local required_paths = {
  'top',
  'top.top',
  'bottom_bg',
  'bottom_bg.bottom_bg',
  'MainlineTaskPanel',
  'talk_sys_panel',
  '消息提示',
  '背包系统.背包系统',
}

for _, path in ipairs(required_paths) do
  local ui = y3.ui.get_ui(player, path)
  if not ui then
    error('[HUD_SMOKE] missing ui path: ' .. path)
  end
end

print('[HUD_SMOKE] all required HUD nodes resolved')
