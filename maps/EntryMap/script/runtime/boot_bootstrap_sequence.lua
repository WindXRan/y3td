local M = {}

function M.create(env)
  local function run_bootstrap_sequence()
    env.ensure_helper_signals()
    env.reset_session_state()
    env.register_runtime_events()
    env.register_dev_commands()
    env.start_runtime_loops()
    env.setup_post_bootstrap_ui()
  end

  return run_bootstrap_sequence
end

return M
