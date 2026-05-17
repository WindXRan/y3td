local M = {}
M.list = {}
M.by_id = {}

local pool = {
  { id = 'power_strike', name = '强力一击', archetype = 'strike', tier = 1, weight = 10 },
  { id = 'quick_strike', name = '快速打击', archetype = 'strike', tier = 1, weight = 10 },
  { id = 'precise_strike', name = '精准打击', archetype = 'strike', tier = 1, weight = 8 },
  { id = 'chain_lightning', name = '闪电链', archetype = 'chain', tier = 2, weight = 6 },
  { id = 'splash', name = '溅射', archetype = 'splash', tier = 2, weight = 6 },
  { id = 'execute', name = '处决', archetype = 'execute', tier = 3, weight = 4 },
  { id = 'medbot', name = '医疗机器人', archetype = 'medbot', tier = 2, weight = 5 },
  { id = 'artillery', name = '火炮', archetype = 'artillery', tier = 3, weight = 3 },
  { id = 'gold_bonus', name = '金币加成', archetype = 'economy', tier = 1, weight = 8 },
  { id = 'wood_bonus', name = '木材加成', archetype = 'economy', tier = 1, weight = 8 },
}

for _, entry in ipairs(pool) do
  M.list[#M.list + 1] = entry
  M.by_id[entry.id] = entry
end

return M
