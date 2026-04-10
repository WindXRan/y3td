local ui_res = require 'ui.res'
local skin = require 'ui.skin'
local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local layout = require 'ui.runtime_hud_layout'
local RuntimeHudNodes = require 'ui.runtime_hud_nodes'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local round_number = env.round_number
  local hero_attr_system = env.hero_attr_system
  local factory = Factory.create(env)

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local set_percent_pos = factory.set_percent_pos
  local get_hud_scale = factory.get_hud_scale
  local scaled = factory.scaled
  local runtime_skin = skin.images.runtime_hud or {}
  local refresh_runtime_hud

  local BOND_DRAW_COST = 100

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function format_time(seconds)
    local total = math.max(0, math.floor(seconds or 0))
    local minute = total // 60
    local second = total % 60
    return string.format('%02d:%02d', minute, second)
  end

  local function format_compact(value)
    local number = round_number(value or 0)
    local abs_number = math.abs(number)
    if abs_number >= 1000000 then
      local text = string.format('%.1fm', number / 1000000)
      return text:gsub('%.0m$', 'm')
    end
    if abs_number >= 10000 then
      local text = string.format('%.1fk', number / 1000)
      return text:gsub('%.0k$', 'k')
    end
    return tostring(number)
  end

  local function get_hero_attr(name, fallback_name)
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local value = hero_attr_system and hero_attr_system.get_attr(STATE.hero, name) or STATE.hero:get_attr(name)
    value = y3.helper.tonumber(value) or 0
    if value > 0 or not fallback_name then
      return value
    end
    local fallback = hero_attr_system and hero_attr_system.get_attr(STATE.hero, fallback_name) or STATE.hero:get_attr(fallback_name)
    return y3.helper.tonumber(fallback) or 0
  end

  local function get_stage_text()
    if env.get_current_stage_text then
      local text = env.get_current_stage_text()
      if text and text ~= '' then
        return text
      end
    end
    local wave_index = math.max(0, STATE.current_wave_index or 0)
    if wave_index <= 0 then
      return '主线 1-1'
    end
    return string.format('主线 1-%d', wave_index)
  end

  local function get_wave_title_text()
    local wave_index = math.max(0, STATE.current_wave_index or 0)
    if wave_index <= 0 then
      return '等待开波'
    end
    return string.format('第 %d / %d 波', wave_index, #CONFIG.waves)
  end

  local function get_wave_status_text()
    local active_wave = STATE.active_wave
    if not active_wave or not active_wave.wave then
      return '按 Space 查看当前战况'
    end
    return string.format(
      '本波已持续 %s  场上敌人 %d',
      format_time(active_wave.elapsed or 0),
      STATE.total_enemy_alive or 0
    )
  end

  local function get_boss_display()
    local active_wave = STATE.active_wave
    if not active_wave or not active_wave.wave then
      return {
        name = 'Boss 未登场',
        state = '等待本波开始',
        bg = theme.palette.accent_soft,
        text = theme.palette.text,
      }
    end

    local boss_name = env.get_boss_name(active_wave.wave)
    if active_wave.boss_spawned then
      local info = active_wave.boss_info
      if info and info.unit and info.unit:is_exist() then
        return {
          name = boss_name,
          state = string.format(
            'HP %s / %s',
            format_compact(info.unit:get_hp()),
            format_compact(info.unit:get_attr('生命') or info.unit:get_attr('最大生命'))
          ),
          bg = theme.palette.danger,
          text = { 255, 236, 240, 255 },
        }
      end
      return {
        name = boss_name,
        state = '已击败',
        bg = theme.palette.success,
        text = { 232, 247, 236, 255 },
      }
    end

    local remain = math.max(0, (active_wave.wave.boss_spawn_sec or 0) - (active_wave.elapsed or 0))
    return {
      name = boss_name,
      state = string.format('%.1f 秒后登场', remain),
      bg = theme.palette.warning,
      text = { 255, 242, 214, 255 },
    }
  end

  local function get_recovery_text()
    local max_charges = CONFIG.challenge_rules.max_charges or 0
    if (STATE.challenge_charges or 0) >= max_charges then
      return '恢复已满'
    end
    local remain = math.max(
      0,
      (CONFIG.challenge_rules.recover_sec or 0) - (STATE.challenge_recover_elapsed or 0)
    )
    return string.format('下次恢复 %s', format_time(remain))
  end

  local function get_hero_hp_text()
    if not STATE.hero or not STATE.hero:is_exist() then
      return '生命 0 / 0'
    end
    return string.format(
      '生命 %s / %s',
      format_compact(STATE.hero:get_hp()),
      format_compact(get_hero_attr('生命结算值', '生命'))
    )
  end

  local function get_challenge_button_state(challenge_id)
    local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
    if not def then
      return {
        summary = '?',
        bg = theme.palette.surface_soft,
        text = theme.palette.text,
      }
    end

    if STATE.active_challenges and STATE.active_challenges[challenge_id] then
      local instance = STATE.active_challenges[challenge_id]
      local remain = math.max(0, (def.duration_sec or 0) - (instance.elapsed or 0))
      return {
        summary = string.format('%s %s', def.hotkey or '?', format_time(remain)),
        bg = theme.palette.success,
        text = { 240, 248, 226, 255 },
      }
    end

    if (STATE.challenge_charges or 0) < (def.cost_charge or 1) then
      return {
        summary = string.format('%s 次数不足', def.hotkey or '?'),
        bg = { 92, 66, 42, 210 },
        text = { 248, 228, 198, 255 },
      }
    end

    return {
      summary = string.format('%s 可进', def.hotkey or '?'),
      bg = theme.palette.accent,
      text = { 236, 244, 255, 255 },
    }
  end

  local function decorate_challenge_status(challenge_id, status)
    local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
    local name = (def and def.display_name) or (def and def.name) or (def and def.hotkey) or '?'
    local hotkey = def and def.hotkey or '?'
    local result = {
      summary = status.summary,
      bg = status.bg,
      text = status.text,
      button_text = name,
      shadow = { 6, 10, 18, 110 },
    }

    if STATE.active_challenges and STATE.active_challenges[challenge_id] then
      local instance = STATE.active_challenges[challenge_id]
      local remain = math.max(0, (def.duration_sec or 0) - (instance.elapsed or 0))
      result.summary = string.format('%s 进行中 %s', hotkey, format_time(remain))
      result.button_text = string.format('%s %s', name, format_time(remain))
      result.shadow = { 22, 54, 28, 150 }
      return result
    end

    if (STATE.challenge_charges or 0) < (def and def.cost_charge or 1) then
      result.summary = string.format('%s 次数不足', hotkey)
      result.button_text = string.format('%s 次数不足', name)
      result.shadow = { 58, 34, 12, 140 }
      return result
    end

    result.summary = string.format('%s 可进入', hotkey)
    result.button_text = string.format('%s 可进入', name)
    result.shadow = { 16, 42, 72, 150 }
    return result
  end

  local function is_ui_alive(ui)
    return ui and not ui:is_removed()
  end

  local function is_button_bundle_alive(bundle)
    return bundle
      and is_ui_alive(bundle.root)
      and is_ui_alive(bundle.bg)
      and is_ui_alive(bundle.button)
  end

  local function is_hud_alive(runtime_hud)
    return runtime_hud
      and is_ui_alive(runtime_hud.hud_root)
      and is_ui_alive(runtime_hud.top_battle_cluster)
      and is_ui_alive(runtime_hud.left_shortcut_panel)
      and is_ui_alive(runtime_hud.right_tracker_panel)
      and is_ui_alive(runtime_hud.bottom_action_bar)
      and is_button_bundle_alive(runtime_hud.skill_button)
      and is_button_bundle_alive(runtime_hud.bond_button)
      and (not runtime_hud.decision_root or is_ui_alive(runtime_hud.decision_root))
  end

  local function hide_decision_panel(runtime_hud)
    if runtime_hud and runtime_hud.decision_root then
      runtime_hud.decision_root:set_visible(false)
    end
  end

  local function set_text_color(target, values)
    if target and values then
      target:set_text_color(values[1], values[2], values[3], values[4] or 255)
    end
  end

  local function set_image_color(target, values)
    if target and values then
      target:set_image_color(values[1], values[2], values[3], values[4] or 255)
    end
  end

  local function prepare_button_bundle(bundle)
    if not is_button_bundle_alive(bundle) then
      return
    end
    bundle.bg:set_image(ui_res.common.empty)
    bundle.shadow:set_image(ui_res.common.empty)
    bundle.button:set_btn_status_image(1, ui_res.common.empty)
    bundle.button:set_btn_status_image(2, ui_res.common.empty)
    bundle.button:set_btn_status_image(3, ui_res.common.empty)
    bundle.button:set_btn_status_image(4, ui_res.common.empty)
  end

  local function update_button_bundle(bundle, label, enabled, bg_color, shadow_color, text_color)
    if not is_button_bundle_alive(bundle) then
      return
    end
    bundle.button:set_text(label or '')
    bundle.button:set_button_enable(enabled == true)
    set_image_color(bundle.bg, bg_color)
    set_image_color(bundle.shadow, shadow_color)
    set_text_color(bundle.button, text_color or theme.palette.text)
  end

  local function get_hero_name()
    if not STATE.hero or not STATE.hero:is_exist() then
      return '先锋英雄'
    end
    local ok, name = pcall(function()
      return STATE.hero:get_name()
    end)
    if ok and name and name ~= '' then
      return name
    end
    return '先锋英雄'
  end

  local function clamp01(value)
    return math.max(0, math.min(1, value or 0))
  end

  local function get_hero_hp_ratio()
    if not STATE.hero or not STATE.hero:is_exist() then
      return 0
    end
    local max_hp = get_hero_attr('生命结算值', '生命')
    if max_hp <= 0 then
      return 0
    end
    return clamp01((y3.helper.tonumber(STATE.hero:get_hp()) or 0) / max_hp)
  end

  local function get_hero_progress_ratio()
    local progress = STATE.hero_progress
    if not progress then
      return 0
    end
    if progress.exp_to_next and progress.exp_to_next > 0 then
      return clamp01((progress.exp or 0) / progress.exp_to_next)
    end
    return 1
  end

  local function get_shortcut_list_text()
    return table.concat({
      'G 技能升级',
      'F 羁绊抽取',
      'Q/W/E/R 试炼入口',
      'B 局内总览',
      'I 已吞噬羁绊',
    }, '\n')
  end

  local function get_tracker_objective_text()
    local active_wave = STATE.active_wave
    if not active_wave or not active_wave.wave then
      return '目标：等待下一波战斗开始'
    end
    if active_wave.boss_spawned then
      return string.format('目标：压制 %s', env.get_boss_name(active_wave.wave))
    end
    return string.format(
      '目标：清理本波敌人，%.1f 秒后 Boss 登场',
      math.max(0, (active_wave.wave.boss_spawn_sec or 0) - (active_wave.elapsed or 0))
    )
  end

  local function get_tracker_progress_text()
    return string.format('%s  |  %s', get_stage_text(), get_wave_title_text())
  end

  local function get_tracker_reward_text()
    local reward_queue_count = env.get_reward_queue_count and env.get_reward_queue_count() or 0
    return string.format(
      '奖励：待领取 %d  |  挑战 %d/%d',
      reward_queue_count,
      STATE.challenge_charges or 0,
      CONFIG.challenge_rules.max_charges or 0
    )
  end

  local function get_tracker_hint_text()
    return string.format('提示：%s  |  场上敌人 %d', get_recovery_text(), STATE.total_enemy_alive or 0)
  end

  local function refresh_skill_slots(runtime_hud)
    for index, slot_ref in ipairs(runtime_hud.skill_slots or {}) do
      local skill = STATE.attack_skill_state and STATE.attack_skill_state.slots[index] or nil
      if slot_ref and slot_ref.text then
        if skill then
          slot_ref.text:set_text(skill.name or string.format('槽位 %d', index))
        else
          slot_ref.text:set_text('未装配')
        end
      end
      if slot_ref and slot_ref.meta then
        if skill then
          local meta = string.format('Lv%d  %.0f%%', skill.level or 1, (skill.damage_ratio or 0) * 100)
          if skill.cooldown_remaining and skill.cooldown_remaining > 0 then
            meta = meta .. string.format('  %.1fs', skill.cooldown_remaining)
          end
          slot_ref.meta:set_text(meta)
        else
          slot_ref.meta:set_text('等待解锁')
        end
      end
    end
  end

  local function refresh_fill_bars(runtime_hud)
    if runtime_hud.hero_hp_fill and runtime_hud.hero_hp_fill_width and runtime_hud.hero_hp_fill_height then
      local width = math.max(6, round_number(runtime_hud.hero_hp_fill_width * get_hero_hp_ratio()))
      runtime_hud.hero_hp_fill:set_ui_size(width, runtime_hud.hero_hp_fill_height)
    end
    if runtime_hud.exp_rail_fill and runtime_hud.exp_rail_fill_width and runtime_hud.exp_rail_fill_height then
      local width = math.max(6, round_number(runtime_hud.exp_rail_fill_width * get_hero_progress_ratio()))
      runtime_hud.exp_rail_fill:set_ui_size(width, runtime_hud.exp_rail_fill_height)
    end
  end

  local function create_decision_option(parent, x, y, width, height, index, scale)
    local shadow = create_panel(
      parent,
      x,
      y - scaled(4, scale),
      width + scaled(10, scale),
      height + scaled(10, scale),
      { 6, 10, 18, 138 },
      { 18, 18, 18, 18 },
      9450,
      runtime_skin.decision_option_shadow
    )
    local bg = create_panel(
      parent,
      x,
      y,
      width,
      height,
      { 38, 48, 66, 236 },
      { 20, 20, 20, 20 },
      9451,
      runtime_skin.decision_option_bg
    )
    local badge_bg = create_panel(
      bg,
      width - scaled(42, scale),
      scaled(104, scale),
      scaled(64, scale),
      scaled(20, scale),
      { 68, 82, 104, 238 },
      { 8, 8, 8, 8 },
      9453,
      runtime_skin.decision_option_badge
    )
    local badge_text = create_text(
      badge_bg,
      scaled(32, scale),
      scaled(10, scale),
      scaled(64, scale),
      scaled(20, scale),
      scaled(9, scale),
      { 232, 238, 248, 255 },
      '中',
      '中',
      9454
    )
    badge_text:set_text('基础')
    local title_text = create_text(
      bg,
      scaled(18, scale),
      scaled(72, scale),
      width - scaled(36, scale),
      scaled(24, scale),
      scaled(18, scale),
      { 236, 242, 250, 255 },
      '左',
      '中',
      9455
    )
    local desc_text = create_text(
      bg,
      scaled(18, scale),
      scaled(32, scale),
      width - scaled(36, scale),
      scaled(34, scale),
      scaled(12, scale),
      { 196, 208, 224, 255 },
      '左',
      '中',
      9455
    )
    local pick_text = create_text(
      bg,
      scaled(18, scale),
      scaled(12, scale),
      width - scaled(36, scale),
      scaled(14, scale),
      scaled(10, scale),
      { 144, 168, 196, 255 },
      '左',
      '中',
      9455
    )
    pick_text:set_text(string.format('按键 %d / 点击选择', index))

    local button = parent:create_child('按钮')
    button:set_ui_size(width, height)
    button:set_pos(x, y)
    button:set_text('')
    button:set_btn_status_image(1, ui_res.common.empty)
    button:set_btn_status_image(2, ui_res.common.empty)
    button:set_btn_status_image(3, ui_res.common.empty)
    button:set_btn_status_image(4, ui_res.common.empty)
    button:set_z_order(9456)
    button:add_fast_event('左键-点击', function()
      if env.apply_round_choice then
        env.apply_round_choice(index)
        refresh_runtime_hud()
      end
    end)

    return {
      shadow = shadow,
      bg = bg,
      badge_bg = badge_bg,
      badge_text = badge_text,
      title_text = title_text,
      desc_text = desc_text,
      pick_text = pick_text,
      button = button,
    }
  end

  local function bind_static_buttons(runtime_hud)
    if runtime_hud.exit_button then
      runtime_hud.exit_button:add_fast_event('左键-点击', function()
        if env.message then
          env.message('退出功能暂未接线，当前请通过编辑器停止运行。')
        end
      end)
    end
    if runtime_hud.settings_button then
      runtime_hud.settings_button:add_fast_event('左键-点击', function()
        if env.message then
          env.message('设置面板暂未接线。')
        end
      end)
    end

    runtime_hud.skill_button.button:add_fast_event('左键-点击', function()
      env.show_upgrade_choices()
      refresh_runtime_hud()
    end)
    runtime_hud.bond_button.button:add_fast_event('左键-点击', function()
      env.try_bond_draw()
      refresh_runtime_hud()
    end)
    runtime_hud.challenge_buttons.gold_trial.button:add_fast_event('左键-点击', function()
      env.try_start_challenge('gold_trial')
      refresh_runtime_hud()
    end)
    runtime_hud.challenge_buttons.wood_trial.button:add_fast_event('左键-点击', function()
      env.try_start_challenge('wood_trial')
      refresh_runtime_hud()
    end)
    runtime_hud.challenge_buttons.exp_trial.button:add_fast_event('左键-点击', function()
      env.try_start_challenge('exp_trial')
      refresh_runtime_hud()
    end)
    runtime_hud.challenge_buttons.treasure_trial.button:add_fast_event('左键-点击', function()
      env.try_treasure_entry()
      refresh_runtime_hud()
    end)
    runtime_hud.treasure_button.button:add_fast_event('左键-点击', function()
      env.try_treasure_entry()
      refresh_runtime_hud()
    end)
    runtime_hud.focus_clear_button.button:add_fast_event('左键-点击', function()
      if env.toggle_overview then
        env.toggle_overview()
      end
      refresh_runtime_hud()
    end)
    runtime_hud.swallowed_list_button.button:add_fast_event('左键-点击', function()
      if env.show_swallowed_bonds then
        env.show_swallowed_bonds()
      end
      refresh_runtime_hud()
    end)
  end

  local function prepare_static_hud(runtime_hud)
    prepare_button_bundle(runtime_hud.skill_button)
    prepare_button_bundle(runtime_hud.bond_button)
    prepare_button_bundle(runtime_hud.treasure_button)
    prepare_button_bundle(runtime_hud.focus_clear_button)
    prepare_button_bundle(runtime_hud.swallowed_list_button)
    for _, bundle in pairs(runtime_hud.challenge_buttons or {}) do
      prepare_button_bundle(bundle)
    end

    if runtime_hud.hero_portrait then
      runtime_hud.hero_portrait:set_image(ui_res.game_hud.unit_icon or ui_res.common.empty)
    end
    if runtime_hud.hero_hp_bg then
      runtime_hud.hero_hp_bg:set_image(ui_res.game_hud.hp_bar_bg or ui_res.common.empty)
    end
    if runtime_hud.hero_hp_fill then
      runtime_hud.hero_hp_fill:set_image(ui_res.game_hud.hp_bar_fill or ui_res.common.empty)
      runtime_hud.hero_hp_fill_width = round_number(runtime_hud.hero_hp_fill:get_width() or 214)
      runtime_hud.hero_hp_fill_height = round_number(runtime_hud.hero_hp_fill:get_height() or 14)
    end
    if runtime_hud.exp_rail_fill then
      runtime_hud.exp_rail_fill:set_image(ui_res.loading.progress_fill or ui_res.common.empty)
      runtime_hud.exp_rail_fill_width = round_number(runtime_hud.exp_rail_fill:get_width() or 1214)
      runtime_hud.exp_rail_fill_height = round_number(runtime_hud.exp_rail_fill:get_height() or 12)
    end
    if runtime_hud.boss_panel then
      runtime_hud.boss_panel:set_image(ui_res.common.empty)
    end
    if runtime_hud.shortcut_title then
      runtime_hud.shortcut_title:set_text('快捷操作')
    end
    if runtime_hud.tracker_title then
      runtime_hud.tracker_title:set_text('战斗追踪')
    end
  end

  refresh_runtime_hud = function()
    local runtime_hud = STATE.runtime_hud
    if not is_hud_alive(runtime_hud) then
      return
    end

    local boss = get_boss_display()
    runtime_hud.stage_text:set_text(get_stage_text())
    runtime_hud.wave_title:set_text(get_wave_title_text())
    runtime_hud.wave_status:set_text(get_wave_status_text())
    runtime_hud.timer_text:set_text(string.format('战斗计时 %s', format_time(STATE.runtime_elapsed or 0)))

    set_image_color(runtime_hud.boss_panel, boss.bg)
    runtime_hud.boss_name:set_text(boss.name)
    set_text_color(runtime_hud.boss_name, boss.text)
    runtime_hud.boss_state:set_text(boss.state)
    set_text_color(runtime_hud.boss_state, boss.text)

    runtime_hud.gold_value:set_text(format_compact(STATE.resources and STATE.resources.gold or 0))
    runtime_hud.wood_value:set_text(format_compact(STATE.resources and STATE.resources.wood or 0))
    runtime_hud.skill_value:set_text(tostring(STATE.skill_points or 0))
    runtime_hud.challenge_value:set_text(string.format(
      '%d/%d',
      STATE.challenge_charges or 0,
      CONFIG.challenge_rules.max_charges or 0
    ))

    runtime_hud.shortcut_list:set_text(get_shortcut_list_text())
    runtime_hud.tracker_objective:set_text(get_tracker_objective_text())
    runtime_hud.tracker_progress:set_text(get_tracker_progress_text())
    runtime_hud.tracker_reward:set_text(get_tracker_reward_text())
    runtime_hud.tracker_hint:set_text(get_tracker_hint_text())

    runtime_hud.hero_name:set_text(get_hero_name())
    runtime_hud.hero_progress_text:set_text(env.get_hero_progress_text())
    runtime_hud.hero_hp_text:set_text(get_hero_hp_text())
    runtime_hud.exp_rail_text:set_text(env.get_hero_progress_text())
    refresh_fill_bars(runtime_hud)
    refresh_skill_slots(runtime_hud)

    local skill_ready = not STATE.game_finished
      and ((STATE.skill_points or 0) > 0 or STATE.awaiting_upgrade == true)
    local skill_highlight = (STATE.skill_points or 0) > 0 or STATE.awaiting_upgrade == true
    update_button_bundle(
      runtime_hud.skill_button,
      STATE.awaiting_upgrade
        and '技能 G 继续选择'
        or string.format('技能 G  剩余 %d 点', STATE.skill_points or 0),
      skill_ready,
      skill_highlight and { 56, 128, 206, 235 } or { 58, 84, 112, 212 },
      skill_highlight and { 20, 44, 82, 156 } or { 6, 10, 18, 110 },
      skill_highlight and { 245, 248, 255, 255 } or { 196, 212, 230, 255 }
    )

    local bond_awaiting = STATE.bond_runtime and STATE.bond_runtime.awaiting_choice == true
    local wood = STATE.resources and STATE.resources.wood or 0
    local bond_ready = not STATE.game_finished and (bond_awaiting or wood >= BOND_DRAW_COST)
    update_button_bundle(
      runtime_hud.bond_button,
      bond_awaiting
        and '羁绊 F 继续选择'
        or string.format('羁绊 F  消耗 %d 木', BOND_DRAW_COST),
      bond_ready,
      (bond_awaiting or wood >= BOND_DRAW_COST) and { 92, 112, 152, 235 } or { 62, 72, 92, 208 },
      (bond_awaiting or wood >= BOND_DRAW_COST) and { 18, 34, 58, 148 } or { 6, 10, 18, 110 },
      (bond_awaiting or wood >= BOND_DRAW_COST) and { 245, 248, 255, 255 } or { 198, 210, 226, 255 }
    )

    for challenge_id, button_ref in pairs(runtime_hud.challenge_buttons) do
      local status = decorate_challenge_status(challenge_id, get_challenge_button_state(challenge_id))
      update_button_bundle(
        button_ref,
        status.button_text or '',
        not STATE.game_finished,
        status.bg,
        status.shadow,
        status.text
      )
    end

    local treasure_pending = env.has_pending_treasure_choice and env.has_pending_treasure_choice() or false
    update_button_bundle(
      runtime_hud.treasure_button,
      treasure_pending and '宝物入口 继续选择' or '宝物入口',
      not STATE.game_finished,
      treasure_pending and { 152, 106, 74, 235 } or { 128, 90, 68, 232 },
      treasure_pending and { 46, 24, 12, 150 } or { 34, 18, 10, 130 },
      treasure_pending and { 255, 244, 228, 255 } or theme.palette.text
    )
    update_button_bundle(
      runtime_hud.focus_clear_button,
      '总览 B',
      true,
      { 58, 84, 112, 226 },
      { 8, 16, 28, 120 },
      theme.palette.text
    )
    update_button_bundle(
      runtime_hud.swallowed_list_button,
      string.format('吞噬 I  (%d)', STATE.bond_runtime and #(STATE.bond_runtime.swallowed_cards or {}) or 0),
      true,
      { 58, 84, 112, 226 },
      { 8, 16, 28, 120 },
      theme.palette.text
    )

    hide_decision_panel(runtime_hud)
  end

  local function create_runtime_hud()
    local hud = get_hud_root()
    if not hud then
      return nil
    end

    if is_hud_alive(STATE.runtime_hud) then
      refresh_runtime_hud()
      return STATE.runtime_hud
    end

    local bound_nodes = RuntimeHudNodes.resolve(env)
    if not bound_nodes
      or not bound_nodes.hud_root
      or not bound_nodes.top_battle_cluster
      or not bound_nodes.left_shortcut_panel
      or not bound_nodes.right_tracker_panel
      or not bound_nodes.bottom_action_bar then
      return nil
    end

    local scale = get_hud_scale(hud, y3)
    local overlay_parent = bound_nodes.overlay_reserved or bound_nodes.hud_root or hud
    local decision_root = create_panel(
      overlay_parent,
      0,
      0,
      scaled(layout.decision_panel.width, scale),
      scaled(layout.decision_panel.height, scale),
      { 8, 14, 24, 216 },
      { 24, 24, 24, 24 },
      9440,
      runtime_skin.decision_root
    )
    decision_root:set_anchor(0.5, 0.5)
    set_percent_pos(env.get_player(), decision_root, 50, layout.decision_panel.percent_y)

    local decision_header_line = create_panel(
      decision_root,
      scaled(520, scale),
      scaled(198, scale),
      scaled(944, scale),
      scaled(8, scale),
      { 54, 104, 168, 72 },
      { 8, 8, 8, 8 },
      9441,
      runtime_skin.decision_header_line
    )
    decision_header_line:set_anchor(0.5, 0.5)
    local decision_caption = create_text(
      decision_root,
      scaled(90, scale),
      scaled(212, scale),
      scaled(140, scale),
      scaled(18, scale),
      scaled(11, scale),
      { 132, 168, 208, 255 },
      nil,
      nil,
      9442
    )
    decision_caption:set_text('当前抉择')

    local decision_title = create_text(
      decision_root,
      scaled(520, scale),
      scaled(212, scale),
      scaled(820, scale),
      scaled(24, scale),
      scaled(22, scale),
      theme.palette.text,
      '中',
      '中',
      9442
    )
    local decision_subtitle = create_text(
      decision_root,
      scaled(520, scale),
      scaled(184, scale),
      scaled(860, scale),
      scaled(18, scale),
      scaled(12, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9442
    )
    local decision_hint = create_text(
      decision_root,
      scaled(520, scale),
      scaled(22, scale),
      scaled(860, scale),
      scaled(16, scale),
      scaled(11, scale),
      theme.palette.text_muted,
      '中',
      '中',
      9442
    )
    local decision_options = {
      create_decision_option(
        decision_root,
        scaled(layout.decision_panel.option_x[1], scale),
        scaled(layout.decision_panel.option_y, scale),
        scaled(layout.decision_panel.option_width, scale),
        scaled(layout.decision_panel.option_height, scale),
        1,
        scale
      ),
      create_decision_option(
        decision_root,
        scaled(layout.decision_panel.option_x[2], scale),
        scaled(layout.decision_panel.option_y, scale),
        scaled(layout.decision_panel.option_width, scale),
        scaled(layout.decision_panel.option_height, scale),
        2,
        scale
      ),
      create_decision_option(
        decision_root,
        scaled(layout.decision_panel.option_x[3], scale),
        scaled(layout.decision_panel.option_y, scale),
        scaled(layout.decision_panel.option_width, scale),
        scaled(layout.decision_panel.option_height, scale),
        3,
        scale
      ),
    }
    decision_root:set_visible(false)

    bound_nodes.decision_root = decision_root
    bound_nodes.decision_header_line = decision_header_line
    bound_nodes.decision_caption = decision_caption
    bound_nodes.decision_title = decision_title
    bound_nodes.decision_subtitle = decision_subtitle
    bound_nodes.decision_hint = decision_hint
    bound_nodes.decision_options = decision_options

    STATE.runtime_hud = bound_nodes
    prepare_static_hud(STATE.runtime_hud)
    bind_static_buttons(STATE.runtime_hud)
    refresh_runtime_hud()
    return STATE.runtime_hud
  end

  return {
    ensure_hud = function()
      return create_runtime_hud()
    end,
    refresh_hud = function()
      return refresh_runtime_hud()
    end,
    set_visible = function(visible)
      local runtime_hud = STATE.runtime_hud
      if not is_hud_alive(runtime_hud) then
        return
      end
      runtime_hud.hud_root:set_visible(visible == true)
      hide_decision_panel(runtime_hud)
    end,
  }
end

return M
