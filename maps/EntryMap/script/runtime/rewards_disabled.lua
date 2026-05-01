local M = {}

local function noop()
  return nil
end

function M.create(_)
  local api = {}

  api.try_queue_evolution_node_for_level = function()
    return false
  end
  api.queue_treasure_round = function()
    return false
  end
  api.show_treasure_choices = function()
    return false
  end
  api.try_process_reward_queue = function()
    return false
  end
  api.has_pending_treasure_choice = function()
    return false
  end
  api.apply_round_choice = function()
    return false
  end

  api.get_treasure_runtime_bonus = function()
    return 0
  end
  api.get_treasure_passive_income = function()
    return 0
  end
  api.get_reward_queue_count = function()
    return 0
  end
  api.get_reward_queue = function()
    return {}
  end
  api.get_evolution_runtime = function()
    return nil
  end
  api.get_treasure_runtime = function()
    return nil
  end
  api.get_treasure_quality_label = function()
    return '已下线'
  end
  api.get_treasure_active_count = function()
    return 0
  end
  api.get_evolution_active_count = function()
    return 0
  end
  api.get_treasure_reward_ratio = function()
    return 0
  end
  api.get_treasure_def = function()
    return nil
  end

  api.build_reward_with_treasure_bonus = function(reward)
    return reward
  end
  api.build_treasure_slot_text = function()
    return '宝物功能已下线'
  end
  api.build_evolution_slot_text = function()
    return '烙印功能已下线'
  end
  api.apply_treasure_bonus_to_attack_skill = noop
  api.update_temporary_treasures = noop
  api.debug_grant_treasure = function()
    return false, '宝物功能已下线。'
  end
  api.debug_dump_temporary_treasures = function()
    return {}
  end

  return setmetatable(api, {
    __index = function()
      return noop
    end,
  })
end

return M
