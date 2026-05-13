local M = {}

M.DAILY_TASK_DEFS = {
  {
    key = 'clear_any_1',
    title = 'Clear any stage once',
    reward = 'Reward: Gold 500',
    target = 1,
  },
  {
    key = 'clear_any_3',
    title = 'Clear any stage 3 times',
    reward = 'Reward: Upgrade Stone +3',
    target = 3,
  },
  {
    key = 'online_60',
    title = 'Stay online for 60 minutes',
    reward = 'Reward: Wood 30',
    target = 60,
  },
  {
    key = 'online_120',
    title = 'Stay online for 120 minutes',
    reward = 'Reward: Essence 300',
    target = 120,
  },
  {
    key = 'online_300',
    title = 'Stay online for 300 minutes',
    reward = 'Reward: Heavy Forging Stone +3',
    target = 300,
  },
}

M.COLOR = {
  selected_bg = { 84, 138, 226, 255 },
  selected_text = { 245, 248, 255, 255 },
  available_bg = { 40, 58, 92, 236 },
  available_text = { 220, 232, 246, 255 },
  locked_bg = { 34, 38, 48, 214 },
  locked_text = { 164, 172, 186, 255 },
  cleared_bg = { 58, 100, 82, 232 },
  cleared_text = { 232, 246, 238, 255 },
  start_ready_bg = { 82, 132, 96, 236 },
  start_locked_bg = { 58, 62, 72, 214 },
}

return M
