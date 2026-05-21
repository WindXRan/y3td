@echo off
chcp 65001 >nul
REM Y3 游戏启动脚本（自动生成，请勿手动修改）
REM 如需重新生成，运行: python generate_launch_bat.py

cd /d "D:\Program Files\y3\games\2.0\game\Engine\Binaries\Win64"
start "" "Game_x64h.exe" --dx11 --start=Python "--python-args=type@editor_game,subtype@editor_game,editor_map_path@d:\project\_codex_y3td_push,level_id@309531409254744034707401852601208640004,release@true,lua_dummy@space,lua_wait_debugger@true" --plugin-config=Plugins-PyQt --console --luaconsole
