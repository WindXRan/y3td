local M = {}

function M.create(env)
  local STATE = env.STATE
  local BattleEventFeedSystem = env.BattleEventFeedSystem
  local create_battle_event_feed_runtime = env.create_battle_event_feed_runtime
  local infer_battle_event_style = env.infer_battle_event_style
  local GearUpgrades = env.GearUpgrades
  local CONFIG = env.CONFIG
  local get_message_prompt_system = env.get_message_prompt_system
  local get_audio_system = env.get_audio_system
  local get_runtime_hud_system = env.get_runtime_hud_system
  local get_inventory_panel_system = env.get_inventory_panel_system
  local message = env.message
  local ensure_round_choice_available = env.ensure_round_choice_available
  local sync_gear_runtime_effects = env.sync_gear_runtime_effects

  local function contains_any(content, patterns)
    for _, pattern in ipairs(patterns or {}) do
      if string.find(content, pattern, 1, true) then
        return true
      end
    end
    return false
  end

  local function is_debug_or_empty(text)
    local content = tostring(text or '')
    if content == ''
      or string.find(content, '[DEBUG]', 1, true)
      or string.find(content, '[effect_debug]', 1, true) then
      return true
    end
    return false
  end

  local function infer_board_spec(text, style)
    if is_debug_or_empty(text) then
      return nil
    end
    local content = tostring(text or '')

    if contains_any(content, {
      '游戏胜利',
      '游戏失败',
    }) then
      return {
        priority = 220,
        duration = 4.8,
      }
    end

    if contains_any(content, {
      '结算：',
      ' 登场。',
      ' 被击败，立即切换到 ',
    }) then
      return {
        priority = 180,
        duration = 3.8,
      }
    end

    if contains_any(content, {
      ' 开始，持续 ',
      ' 失败。',
      '升级至',
      '2选1',
      '2 选 1',
      '3选1',
      '3 选 1',
      '按 1 / 2 选择',
      '按 1 / 2 / 3 选择',
      '获得一次',
      '英雄选择',
      '奖励已发放。',
      '已选择强化',
      '技能更新：',
      '已开启战术卡流派：',
      '已解锁战术卡：',
      ' 已完成。',
    }) then
      return {
        priority = 130,
        duration = 3.0,
      }
    end

    if style == 'warning' and contains_any(content, {
      '不足',
      '警告',
      '创建失败',
      '刷怪失败',
    }) then
      return {
        priority = 100,
        duration = 2.4,
      }
    end

    return nil
  end

  local function infer_marquee_spec(text)
    if is_debug_or_empty(text) then
      return nil
    end
    local content = tostring(text or '')

    if contains_any(content, {
      '游戏胜利',
      '游戏失败',
    }) then
      return {
        priority = 320,
        duration = 6.6,
      }
    end

    if contains_any(content, {
      ' 登场。',
      ' 被击败，立即切换到 ',
    }) then
      return {
        priority = 260,
        duration = 5.4,
      }
    end

    if contains_any(content, {
      '奖励已发放。',
    }) then
      return {
        priority = 220,
        duration = 4.8,
      }
    end

    return nil
  end

  local function route(text, style)
    local prompt_system = get_message_prompt_system and get_message_prompt_system() or nil
    local content = tostring(text or '')
    if string.find(content, '金币不足', 1, true) then
      local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
      if runtime_hud_system and runtime_hud_system.show_insufficient_gold_tip then
        runtime_hud_system.show_insufficient_gold_tip()
      end
    end
    if not prompt_system then
      return
    end

    local board = infer_board_spec(text, style)
    if board and prompt_system.push_board then
      prompt_system.push_board(text, board.priority, {
        duration = board.duration,
      })
    end

    local marquee = infer_marquee_spec(text)
    if marquee and prompt_system.push_marquee then
      prompt_system.push_marquee(text, marquee.priority, {
        duration = marquee.duration,
      })
    end
  end

  local function push_battle_event(text, style, duration)
    local final_style = style or infer_battle_event_style(text)
    local prompt_system = get_message_prompt_system and get_message_prompt_system() or nil
    if prompt_system and prompt_system.push_list then
      prompt_system.push_list(text, nil, {
        style = final_style,
        duration = duration,
      })
    end
    if STATE.session_phase ~= 'battle' then
      return nil
    end
    route(text, final_style)
    if not STATE.battle_event_feed then
      STATE.battle_event_feed = create_battle_event_feed_runtime()
    end
    return BattleEventFeedSystem.push_event(STATE.battle_event_feed, text, {
      now = STATE.runtime_elapsed or 0,
      style = final_style,
      duration = duration,
    })
  end

  local function try_upgrade_growth_weapon(source)
    if STATE.session_phase ~= 'battle' or STATE.game_finished == true then
      return false
    end
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return false
    end
    if not ensure_round_choice_available(nil) then
      return false
    end

    local gear_runtime = GearUpgrades.ensure_runtime(STATE, CONFIG.gear_upgrade_config)
    local weapon_item = gear_runtime and gear_runtime.items and gear_runtime.items.weapon or nil
    local current_level = tonumber(weapon_item and weapon_item.level) or 1
    local upgrade_cost = GearUpgrades.get_upgrade_cost('weapon', current_level, CONFIG.gear_upgrade_config) or 0
    local audio_system = get_audio_system and get_audio_system() or nil

    if upgrade_cost <= 0 then
      message('成长武器已满级。')
      if audio_system and audio_system.play_ui_error then
        audio_system.play_ui_error()
      end
      return false
    end

    if (STATE.resources and STATE.resources.gold or 0) < upgrade_cost then
      message(string.format('金币不足，成长武器升级需要 %d 金币。', upgrade_cost))
      if audio_system and audio_system.play_ui_error then
        audio_system.play_ui_error()
      end
      return false
    end

    local next_level = GearUpgrades.try_upgrade_levels({
      STATE = STATE,
      CONFIG = CONFIG,
    }, 'weapon', 1)

    if tonumber(next_level) <= current_level then
      return false
    end

    if audio_system and audio_system.play_ui_click then
      audio_system.play_ui_click()
    end
    message(string.format('成长武器升至 Lv.%d，消耗 %d 金币。', next_level, upgrade_cost))

    gear_runtime = GearUpgrades.ensure_runtime(STATE, CONFIG.gear_upgrade_config)
    if gear_runtime and gear_runtime.awaiting_choice == true then
      STATE.choice_panel_hidden = false
      message(string.format('成长武器达到 Lv.%d，出现 3 个不同品质的词条，请选择其一。', next_level))
    end

    if sync_gear_runtime_effects and STATE.hero then
      sync_gear_runtime_effects(STATE, STATE.hero, CONFIG.gear_upgrade_config)
    end

    local runtime_hud_system = get_runtime_hud_system and get_runtime_hud_system() or nil
    if runtime_hud_system and runtime_hud_system.refresh_hud then
      runtime_hud_system.refresh_hud()
    end

    local inventory_panel_system = get_inventory_panel_system and get_inventory_panel_system() or nil
    if inventory_panel_system and inventory_panel_system.refresh_panel then
      inventory_panel_system.refresh_panel()
    end

    return true
  end

  return {
    push_battle_event = push_battle_event,
    try_upgrade_growth_weapon = try_upgrade_growth_weapon,
  }
end

return M
