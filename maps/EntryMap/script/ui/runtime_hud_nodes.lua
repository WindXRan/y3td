local M = {}

local function resolve_ui(y3, player, path)
  local ok, ui = pcall(y3.ui.get_ui, player, path)
  if not ok or not ui then
    return nil
  end
  return ui
end

local function bind_button_bundle(y3, player, path)
  local root = resolve_ui(y3, player, path)
  if not root then
    return nil
  end
  return {
    root = root,
    shadow = resolve_ui(y3, player, path .. '.shadow'),
    bg = resolve_ui(y3, player, path .. '.bg'),
    button = resolve_ui(y3, player, path .. '.button'),
  }
end

function M.resolve(env)
  local y3 = env.y3
  local player = env.get_player()
  local base = 'GameHUD.hud_root'

  local nodes = {
    hud_root = resolve_ui(y3, player, base),
    top_battle_cluster = resolve_ui(y3, player, base .. '.top_battle_cluster'),
    left_shortcut_panel = resolve_ui(y3, player, base .. '.left_shortcut_panel'),
    right_tracker_panel = resolve_ui(y3, player, base .. '.right_tracker_panel'),
    challenge_strip = resolve_ui(y3, player, base .. '.challenge_strip'),
    bottom_action_bar = resolve_ui(y3, player, base .. '.bottom_action_bar'),
    overlay_reserved = resolve_ui(y3, player, base .. '.overlay_reserved'),

    stage_text = resolve_ui(y3, player, base .. '.top_battle_cluster.stage_chip.stage_text'),
    timer_text = resolve_ui(y3, player, base .. '.top_battle_cluster.timer_block.timer_text'),
    wave_status = resolve_ui(y3, player, base .. '.top_battle_cluster.timer_block.wave_status_text'),
    wave_title = resolve_ui(y3, player, base .. '.top_battle_cluster.wave_medallion.wave_title'),
    boss_panel = resolve_ui(y3, player, base .. '.top_battle_cluster.boss_capsule.boss_capsule_bg'),
    boss_name = resolve_ui(y3, player, base .. '.top_battle_cluster.boss_capsule.boss_name'),
    boss_state = resolve_ui(y3, player, base .. '.top_battle_cluster.boss_capsule.boss_state'),
    gold_value = resolve_ui(y3, player, base .. '.top_battle_cluster.resource_cluster.gold_card.gold_value'),
    wood_value = resolve_ui(y3, player, base .. '.top_battle_cluster.resource_cluster.wood_card.wood_value'),
    skill_value = resolve_ui(y3, player, base .. '.top_battle_cluster.resource_cluster.skill_card.skill_value'),
    challenge_value = resolve_ui(y3, player, base .. '.top_battle_cluster.resource_cluster.challenge_card.challenge_value'),

    exit_button = resolve_ui(y3, player, base .. '.left_shortcut_panel.exit_button'),
    settings_button = resolve_ui(y3, player, base .. '.left_shortcut_panel.settings_button'),
    shortcut_title = resolve_ui(y3, player, base .. '.left_shortcut_panel.shortcut_title'),
    shortcut_list = resolve_ui(y3, player, base .. '.left_shortcut_panel.shortcut_list'),

    tracker_title = resolve_ui(y3, player, base .. '.right_tracker_panel.tracker_title'),
    tracker_objective = resolve_ui(y3, player, base .. '.right_tracker_panel.tracker_objective'),
    tracker_progress = resolve_ui(y3, player, base .. '.right_tracker_panel.tracker_progress'),
    tracker_reward = resolve_ui(y3, player, base .. '.right_tracker_panel.tracker_reward'),
    tracker_hint = resolve_ui(y3, player, base .. '.right_tracker_panel.tracker_hint'),
    auto_task_checkbox = resolve_ui(y3, player, base .. '.right_tracker_panel.auto_task_checkbox'),

    hero_portrait = resolve_ui(y3, player, base .. '.bottom_action_bar.hero_core_panel.hero_portrait'),
    hero_name = resolve_ui(y3, player, base .. '.bottom_action_bar.hero_core_panel.hero_name'),
    hero_progress_text = resolve_ui(y3, player, base .. '.bottom_action_bar.hero_core_panel.hero_progress_text'),
    hero_hp_bg = resolve_ui(y3, player, base .. '.bottom_action_bar.hero_core_panel.hero_hp_bg'),
    hero_hp_fill = resolve_ui(y3, player, base .. '.bottom_action_bar.hero_core_panel.hero_hp_fill'),
    hero_hp_text = resolve_ui(y3, player, base .. '.bottom_action_bar.hero_core_panel.hero_hp_text'),

    exp_rail = resolve_ui(y3, player, base .. '.bottom_action_bar.exp_rail'),
    exp_rail_fill = resolve_ui(y3, player, base .. '.bottom_action_bar.exp_rail.exp_rail_fill'),
    exp_rail_text = resolve_ui(y3, player, base .. '.bottom_action_bar.exp_rail.exp_rail_text'),
  }

  nodes.skill_slots = {}
  for index = 1, 4, 1 do
    local prefix = string.format('%s.bottom_action_bar.skill_hotbar.skill_slot_%d', base, index)
    nodes.skill_slots[index] = {
      root = resolve_ui(y3, player, prefix),
      key = resolve_ui(y3, player, prefix .. string.format('.skill_slot_%d_key', index)),
      text = resolve_ui(y3, player, prefix .. string.format('.skill_slot_%d_text', index)),
      meta = resolve_ui(y3, player, prefix .. string.format('.skill_slot_%d_meta', index)),
    }
  end

  nodes.skill_button = bind_button_bundle(y3, player, base .. '.bottom_action_bar.primary_action_cluster.skill_button')
  nodes.bond_button = bind_button_bundle(y3, player, base .. '.bottom_action_bar.primary_action_cluster.bond_button')
  nodes.treasure_button = bind_button_bundle(y3, player, base .. '.bottom_action_bar.secondary_action_cluster.treasure_button')
  nodes.focus_clear_button = bind_button_bundle(y3, player, base .. '.bottom_action_bar.secondary_action_cluster.focus_clear_button')
  nodes.swallowed_list_button = bind_button_bundle(y3, player, base .. '.bottom_action_bar.secondary_action_cluster.swallowed_list_button')

  nodes.challenge_buttons = {
    gold_trial = bind_button_bundle(y3, player, base .. '.challenge_strip.gold_trial_button'),
    wood_trial = bind_button_bundle(y3, player, base .. '.challenge_strip.wood_trial_button'),
    exp_trial = bind_button_bundle(y3, player, base .. '.challenge_strip.exp_trial_button'),
    treasure_trial = bind_button_bundle(y3, player, base .. '.challenge_strip.treasure_trial_button'),
  }

  return nodes
end

return M
