-- diag_hud.lua — 诊断 HUD 初始化状态
-- @run-success: [diag-hud] done
-- @run-timeout: 20

print('[diag-hud] start')

local has_hud_system = _G.hud_system ~= nil
print('[diag-hud] _G.hud_system exists=' .. tostring(has_hud_system))

if _G.hud_system then
    local has_ensure = type(_G.hud_system.ensure_hud) == 'function'
    local has_refresh = type(_G.hud_system.refresh_hud) == 'function'
    local has_set_visible = type(_G.hud_system.set_visible) == 'function'
    print('[diag-hud] ensure_hud=' .. tostring(has_ensure) .. ' refresh_hud=' .. tostring(has_refresh) .. ' set_visible=' .. tostring(has_set_visible))
end

local state = _G.STATE
if state then
    print('[diag-hud] STATE exists')
    print('[diag-hud] STATE.session_phase=' .. tostring(state.session_phase))
    print('[diag-hud] STATE.runtime_hud=' .. tostring(state.runtime_hud ~= nil))
    if state.runtime_hud then
        print('[diag-hud] hud_state.visible=' .. tostring(state.runtime_hud.visible))
        print('[diag-hud] hud_state.nodes count=' .. tostring(#(state.runtime_hud.nodes or {})))
    end
else
    print('[diag-hud] STATE is nil')
end

local p = y3.player(1)
if p then
    print('[diag-hud] player exists')
    local hero = p.mainhero
    print('[diag-hud] hero=' .. tostring(hero ~= nil))
end

print('[diag-hud] done')
