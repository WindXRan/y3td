local M = {}

function M.create()
  local state = { gold = 0, wood = 0 }

  return {
    get_gold = function() return state.gold end,
    get_wood = function() return state.wood end,
    add_gold = function(amount)
      if amount and amount > 0 then state.gold = state.gold + amount end
    end,
    add_wood = function(amount)
      if amount and amount > 0 then state.wood = state.wood + amount end
    end,
    set_gold = function(v) state.gold = v or 0 end,
    set_wood = function(v) state.wood = v or 0 end,
    add_reward = function(reward)
      if not reward then return end
      if reward.gold and reward.gold > 0 then state.gold = state.gold + reward.gold end
      if reward.wood and reward.wood > 0 then state.wood = state.wood + reward.wood end
    end,
    init_from_rules = function(rules)
      state.gold = (rules and rules.initial_gold) or 0
      state.wood = (rules and rules.initial_wood) or 0
    end,
    get_state_table = function() return state end,
  }
end

return M
