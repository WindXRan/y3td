local M = {}

M.DAILY_TASK_DEFS = {
  {
    key = 'clear_any_1',
    title = '首次通关任意难度',
    reward = '奖励：金币+500',
    target = 1,
  },
  {
    key = 'clear_any_3',
    title = '通关3次任意难度',
    reward = '奖励：强化石+3',
    target = 3,
  },
  {
    key = 'online_60',
    title = '累计在线60分钟',
    reward = '奖励：木材+30',
    target = 60,
  },
  {
    key = 'online_120',
    title = '累计在线120分钟',
    reward = '奖励：泡点+300',
    target = 120,
  },
  {
    key = 'online_300',
    title = '累计在线300分钟',
    reward = '奖励：重铸石+3',
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
