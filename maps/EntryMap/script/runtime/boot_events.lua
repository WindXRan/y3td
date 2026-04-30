local M = {}

function M.register(args)
  local input_events_system = args.input_events_system

  if input_events_system and input_events_system.register_runtime_events then
    input_events_system.register_runtime_events()
  end
end

return M
