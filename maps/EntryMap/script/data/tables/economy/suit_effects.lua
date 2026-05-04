local suit_catalog = require 'data.tables.economy.suit_catalog'

local SUIT_IDS = suit_catalog.SUIT_IDS

local function get_effects_by_suit_and_level(suit_id, star_level)
  local suit_data = suit_catalog.by_suit_id[suit_id]
  if not suit_data or not suit_data.level_effects then
    return nil
  end
  return suit_data.level_effects[star_level]
end

return {
  SUIT_IDS = SUIT_IDS,
  list = function()
    local all_effects = {}
    for _, suit in ipairs(suit_catalog.list) do
      if suit.level_effects then
        for level, effect in ipairs(suit.level_effects) do
          table.insert(all_effects, {
            suit_id = suit.suit_id,
            star_level = level,
            effects = effect.effects,
            description = effect.description,
          })
        end
      end
    end
    return all_effects
  end,
  by_suit_id = function()
    local result = {}
    for _, suit in ipairs(suit_catalog.list) do
      if suit.level_effects then
        result[suit.suit_id] = {}
        for level, effect in ipairs(suit.level_effects) do
          table.insert(result[suit.suit_id], {
            suit_id = suit.suit_id,
            star_level = level,
            effects = effect.effects,
            description = effect.description,
          })
        end
      end
    end
    return result
  end,
  get_effects_by_suit_and_level = get_effects_by_suit_and_level,
}