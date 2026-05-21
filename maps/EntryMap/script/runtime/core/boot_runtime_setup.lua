local M = {}

local function create_dev_commands()
  return function()
    local debug_tools_system = _G.debug_tools_system
    if debug_tools_system and debug_tools_system.register_dev_commands then
      debug_tools_system.register_dev_commands()
    end
  end
end

local function create_bootstrap_sequence(env)
  return function()
    env.ensure_helper_signals()
    env.reset_session_state()
    env.register_runtime_events()
    env.register_dev_commands()
    env.start_runtime_loops()
    env.setup_post_bootstrap_ui()
  end
end

function M.create()
  local RuntimeLoopsSystem = require 'runtime.core.loops'

  local outgame_system = _G.outgame_system

  print('[boot_runtime_setup] _G.battlefield_system type=' .. type(_G.battlefield_system) .. ' ok=' .. tostring(_G.battlefield_system ~= nil))

  local runtime_loops_system = RuntimeLoopsSystem.create()

  local register_runtime_events = function()
    if runtime_loops_system.register_runtime_events then
      runtime_loops_system.register_runtime_events()
    end
  end

  local start_runtime_loops = function()
    return runtime_loops_system.start_runtime_loops()
  end

  local register_dev_commands = create_dev_commands()

  local run_bootstrap_sequence = create_bootstrap_sequence({
    ensure_helper_signals = _G.ensure_helper_signals,
    reset_session_state = function() return _G.reset_session_state and _G.reset_session_state() end,
    register_runtime_events = register_runtime_events,
    register_dev_commands = register_dev_commands,
    start_runtime_loops = start_runtime_loops,
    setup_post_bootstrap_ui = function()
      -- 跳过局外界面，直接进入战斗
      print('[BOOT] Skipping outgame UI, starting battle directly')
      
      -- 先隐藏局外UI（使用pcall避免UI不存在时出错）
      if outgame_system and outgame_system.set_ui_visible then
        pcall(outgame_system.set_ui_visible, false)
      end
      
      -- 直接调用开始游戏
      if _G.session_state_system and _G.session_state_system.start_selected_stage then
        local ok, err = pcall(_G.session_state_system.start_selected_stage)
        if not ok then
          print('[BOOT] ERROR starting stage:', tostring(err))
        end
      elseif _G.outgame_system and _G.outgame_system.start_selected_stage then
        local ok, err = pcall(_G.outgame_system.start_selected_stage)
        if not ok then
          print('[BOOT] ERROR starting stage:', tostring(err))
        end
      end
      
      -- 设置战斗UI可见
      if _G.set_battle_hud_visible then
        _G.set_battle_hud_visible(true)
      end
      if _G.enforce_runtime_ui_phase then
        _G.enforce_runtime_ui_phase(true)
      end
    end,
  })

  return {
    bootstrap = run_bootstrap_sequence,
    runtime_loops_system = runtime_loops_system,
    register_runtime_events = register_runtime_events,
    start_runtime_loops = start_runtime_loops,
    register_dev_commands = register_dev_commands,
    run_bootstrap_sequence = run_bootstrap_sequence,
  }
end

return M