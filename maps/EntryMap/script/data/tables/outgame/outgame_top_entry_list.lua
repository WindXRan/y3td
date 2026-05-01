local M = {}

M.list = {
  {
    id = 'archive',
    slot = 1,
    label = '存档',
    action = 'open_archive',
    visible_in_outgame = true,
  },
  {
    id = 'hero_growth',
    slot = 2,
    label = '英雄养成',
    action = 'show_hero_growth_tip',
    visible_in_outgame = true,
  },
  {
    id = 'hero_book',
    slot = 3,
    label = '英雄图鉴',
    action = 'show_hero_tujian_tip',
    visible_in_outgame = true,
  },
  {
    id = 'start',
    slot = 4,
    label = '开始',
    action = 'start_stage',
    visible_in_outgame = true,
  },
}

M.by_id = {}
M.by_slot = {}
for _, entry in ipairs(M.list) do
  M.by_id[entry.id] = entry
  M.by_slot[tonumber(entry.slot) or 0] = entry
end

return M

