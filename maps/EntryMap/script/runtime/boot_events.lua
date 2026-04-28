local M = {}

function M.register(args)
  local input_events_system = args.input_events_system
  local hero_selection_range_system = args.hero_selection_range_system

  if input_events_system and input_events_system.register_runtime_events then
    input_events_system.register_runtime_events()
  end
  if hero_selection_range_system and hero_selection_range_system.register_runtime_events then
    hero_selection_range_system.register_runtime_events()
  end
end

return M
