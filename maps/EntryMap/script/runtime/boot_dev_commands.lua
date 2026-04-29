local M = {}

function M.create(env)
  local function register_dev_commands()
    local debug_tools_system = env.get_debug_tools_system and env.get_debug_tools_system() or nil
    if debug_tools_system and debug_tools_system.register_dev_commands then
      debug_tools_system.register_dev_commands()
    end

    local gm_bond_effects_system = env.get_gm_bond_effects_system and env.get_gm_bond_effects_system() or nil
    if gm_bond_effects_system and gm_bond_effects_system.register_dev_commands then
      gm_bond_effects_system.register_dev_commands()
    end
  end

  return register_dev_commands
end

return M
