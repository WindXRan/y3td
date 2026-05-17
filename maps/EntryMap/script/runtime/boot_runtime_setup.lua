local M = {}
local BootDevCommands = require 'runtime.boot_dev_commands'
local BootBootstrapSequence = require 'runtime.boot_bootstrap_sequence'

function M.create()
  local RuntimeLoopsSystem = require 'runtime.loops'

  local outgame_system = _G.outgame_system
  local growth_weapon_item_tip_system = _G.growth_weapon_item_tip_system

  local runtime_loops_system = RuntimeLoopsSystem.create()

  local register_runtime_events = function()
    if runtime_loops_system.register_runtime_events then
      runtime_loops_system.register_runtime_events()
    end
    if growth_weapon_item_tip_system and growth_weapon_item_tip_system.bind then
      growth_weapon_item_tip_system.bind()
    end
  end

  local start_runtime_loops = function()
    return runtime_loops_system.start_runtime_loops()
  end

  local register_dev_commands = BootDevCommands.create()

  local run_bootstrap_sequence = BootBootstrapSequence.create({
    ensure_helper_signals = _G.ensure_helper_signals,
    reset_session_state = function() return _G.reset_session_state and _G.reset_session_state() end,
    register_runtime_events = register_runtime_events,
    register_dev_commands = register_dev_commands,
    start_runtime_loops = start_runtime_loops,
    setup_post_bootstrap_ui = function()
      local gm = _G.gm_bond_effects_system
      if gm and gm.ensure_board then
        gm.ensure_board()
        gm.refresh_board()
      end
      outgame_system.load_profile()
      if outgame_system.set_ui_visible then
        outgame_system.set_ui_visible(false)
      end
      if _G.enforce_runtime_ui_phase then
        _G.enforce_runtime_ui_phase(false)
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
