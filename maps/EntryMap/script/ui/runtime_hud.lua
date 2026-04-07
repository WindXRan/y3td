local ui_res = require 'ui.res'
local skin = require 'ui.skin'
local theme = require 'ui.theme'
local Factory = require 'ui.factory'
local layout = require 'ui.runtime_hud_layout'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local round_number = env.round_number
  local factory = Factory.create(env)

  local create_panel = factory.create_panel
  local create_text = factory.create_text
  local create_button = factory.create_button
  local set_percent_pos = factory.set_percent_pos
  local get_hud_metrics = factory.get_hud_metrics
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
            format_compact(info.unit:get_attr('hp_max'))
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
      format_compact(STATE.hero:get_attr('hp_max'))
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
        summary = string.format('%s 缺次', def.hotkey or '?'),
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

  local function get_challenge_summary_text()
    local parts = {}
    for _, challenge_id in ipairs({ 'gold_trial', 'wood_trial', 'exp_trial', 'treasure_trial' }) do
      parts[#parts + 1] = get_challenge_button_state(challenge_id).summary
    end
    local reward_queue_count = env.get_reward_queue_count and env.get_reward_queue_count() or 0
    if reward_queue_count > 0 then
      parts[#parts + 1] = string.format('待奖 %d', reward_queue_count)
    end
    return table.concat(parts, '   ')
  end

  local function create_stat_text(parent, x, y, width, label, value, label_color, value_color, align, scale)
    local label_text = create_text(
      parent,
      x,
      y + scaled(8, scale),
      width,
      scaled(12, scale),
      scaled(10, scale),
      label_color or theme.palette.text_muted,
      align or '左',
      '中',
      9402
    )
    label_text:set_text(label)

    local value_text = create_text(
      parent,
      x,
      y - scaled(7, scale),
      width,
      scaled(18, scale),
      scaled(14, scale),
      value_color or theme.palette.text,
      align or '左',
      '中',
      9402
    )
    value_text:set_text(value)
    return label_text, value_text
  end

  local function get_decision_rarity_palette(rarity)
    if rarity == 'epic' then
      return {
        card = { 112, 72, 36, 238 },
        edge = { 228, 184, 112, 255 },
        title = { 255, 238, 206, 255 },
        tag = { 255, 210, 140, 255 },
        badge = { 168, 110, 48, 242 },
        badge_text = { 255, 241, 214, 255 },
      }
    end
    if rarity == 'rare' then
      return {
        card = { 40, 76, 118, 238 },
        edge = { 126, 188, 255, 255 },
        title = { 232, 244, 255, 255 },
        tag = { 170, 214, 255, 255 },
        badge = { 56, 110, 174, 242 },
        badge_text = { 230, 244, 255, 255 },
      }
    end
    return {
      card = { 38, 48, 66, 236 },
      edge = { 132, 152, 178, 255 },
      title = { 236, 242, 250, 255 },
      tag = { 182, 198, 220, 255 },
      badge = { 68, 82, 104, 238 },
      badge_text = { 232, 238, 248, 255 },
    }
  end

  local function get_decision_rarity_label(rarity)
    if rarity == 'epic' then
      return '史诗'
    end
    if rarity == 'rare' then
      return '稀有'
    end
    return '基础'
  end

  local function create_decision_option(parent, x, y, width, height, index, scale)
    local badge_width = layout.decision_panel.badge_width or 64
    local badge_height = layout.decision_panel.badge_height or 20
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
    local edge = create_panel(
      bg,
      scaled(12, scale),
      scaled(14, scale),
      width - scaled(24, scale),
      scaled(5, scale),
      { 132, 152, 178, 255 },
      { 8, 8, 8, 8 },
      9452
    )
    local badge_bg = create_panel(
      bg,
      width - scaled(42, scale),
      scaled(108, scale),
      scaled(badge_width, scale),
      scaled(badge_height, scale),
      { 68, 82, 104, 238 },
      { 8, 8, 8, 8 },
      9453,
      runtime_skin.decision_option_badge
    )
    local emblem = create_panel(
      bg,
      scaled(28, scale),
      scaled(108, scale),
      scaled(22, scale),
      scaled(22, scale),
      { 220, 236, 255, 235 },
      theme.insets.soft,
      9454,
      runtime_skin.decision_option_emblem
    )
    emblem:set_anchor(0.5, 0.5)
    local badge_text = create_text(
      badge_bg,
      scaled(badge_width * 0.5, scale),
      scaled(badge_height * 0.5, scale),
      scaled(badge_width, scale),
      scaled(badge_height, scale),
      scaled(9, scale),
      { 232, 238, 248, 255 },
      nil,
      nil,
      9454
    )
    badge_text:set_text('基础')
    local tag_text = create_text(
      bg,
      scaled(18, scale),
      scaled(106, scale),
      width - scaled(36, scale),
      scaled(18, scale),
      scaled(12, scale),
      { 182, 198, 220, 255 },
      '左',
      '中',
      9455
    )
    local title_text = create_text(
      bg,
      scaled(18, scale),
      scaled(78, scale),
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
      scaled(36, scale),
      width - scaled(36, scale),
      scaled(36, scale),
      scaled(12, scale),
      { 196, 208, 224, 255 },
      '左',
      '中',
      9455
    )
    local hotkey_text = create_text(
      bg,
      width - scaled(26, scale),
      scaled(108, scale),
      scaled(24, scale),
      scaled(18, scale),
      scaled(15, scale),
      { 240, 245, 255, 255 },
      '右',
      '中',
      9455
    )
    hotkey_text:set_text(tostring(index))
    local pick_text = create_text(
      bg,
      scaled(18, scale),
      scaled(18, scale),
      width - scaled(36, scale),
      scaled(14, scale),
      scaled(10, scale),
      { 144, 168, 196, 255 },
      nil,
      nil,
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
      edge = edge,
      badge_bg = badge_bg,
      badge_text = badge_text,
      emblem = emblem,
      tag_text = tag_text,
      title_text = title_text,
      desc_text = desc_text,
      hotkey_text = hotkey_text,
      pick_text = pick_text,
      button = button,
    }
  end

  local function get_decision_rarity_palette_v2(rarity)
    local palette = get_decision_rarity_palette(rarity) or {}
    palette.shadow = palette.shadow or { 10, 16, 28, 138 }
    palette.desc = palette.desc or { 196, 208, 224, 255 }
    palette.hint = palette.hint or { 144, 168, 196, 255 }
    if rarity == 'epic' then
      palette.shadow = { 82, 52, 20, 168 }
      palette.desc = { 255, 228, 188, 255 }
      palette.hint = { 255, 210, 132, 255 }
    elseif rarity == 'rare' then
      palette.shadow = { 18, 50, 90, 168 }
      palette.desc = { 210, 228, 246, 255 }
      palette.hint = { 164, 214, 255, 255 }
    end
    return palette
  end

  local function get_decision_rarity_label_v2(rarity)
    if rarity == 'epic' then
      return '史诗'
    end
    if rarity == 'rare' then
      return '稀有'
    end
    return '基础'
  end

  local function get_decision_caption(kind)
    if kind == 'upgrade' then
      return '技能抉择'
    end
    if kind == 'bond' then
      return '羁绊抉择'
    end
    if kind == 'mark' then
      return '烙印抉择'
    end
    if kind == 'treasure' then
      return '宝物抉择'
    end
    return '当前抉择'
  end

  local function get_decision_pick_text(kind, index)
    if kind == 'treasure' then
      return string.format('按 %d 领取此项', index)
    end
    if kind == 'bond' then
      return string.format('按 %d 收下此卡', index)
    end
    if kind == 'mark' then
      return string.format('按 %d 铭刻此印', index)
    end
    return string.format('按 %d 确认选择', index)
  end

  local function get_decision_notice(kind)
    if kind == 'upgrade' then
      return '成长抉择待确认'
    end
    if kind == 'bond' then
      return '羁绊招募进行中'
    end
    if kind == 'mark' then
      return '烙印正在抉择'
    end
    if kind == 'treasure' then
      return '宝物选择进行中'
    end
    return '抉择进行中'
  end

  local function decorate_challenge_status(challenge_id, status)
    local def = CONFIG.challenges and CONFIG.challenges[challenge_id]
    local name = (def and def.display_name) or def and def.name or def and def.hotkey or '?'
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

  local function is_hud_alive(runtime_hud)
    return runtime_hud
      and runtime_hud.center_root
      and runtime_hud.left_root
      and runtime_hud.right_root
      and not runtime_hud.center_root:is_removed()
      and not runtime_hud.left_root:is_removed()
      and not runtime_hud.right_root:is_removed()
      and (not runtime_hud.decision_root or not runtime_hud.decision_root:is_removed())
  end

  local function hide_legacy_decision_panel(runtime_hud)
    if runtime_hud and runtime_hud.decision_root then
      runtime_hud.decision_root:set_visible(false)
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

    runtime_hud.boss_panel:set_image_color(boss.bg[1], boss.bg[2], boss.bg[3], boss.bg[4])
    runtime_hud.boss_name:set_text(boss.name)
    runtime_hud.boss_name:set_text_color(boss.text[1], boss.text[2], boss.text[3], boss.text[4])
    runtime_hud.boss_state:set_text(boss.state)
    runtime_hud.boss_state:set_text_color(boss.text[1], boss.text[2], boss.text[3], boss.text[4])

    runtime_hud.gold_value:set_text(format_compact(STATE.resources and STATE.resources.gold or 0))
    runtime_hud.wood_value:set_text(format_compact(STATE.resources and STATE.resources.wood or 0))
    runtime_hud.skill_value:set_text(tostring(STATE.skill_points or 0))
    runtime_hud.challenge_value:set_text(string.format(
      '%d/%d',
      STATE.challenge_charges or 0,
      CONFIG.challenge_rules.max_charges or 0
    ))

    runtime_hud.hero_progress_text:set_text(env.get_hero_progress_text())
    runtime_hud.hero_hp_text:set_text(get_hero_hp_text())
    runtime_hud.challenge_summary_text:set_text(get_challenge_summary_text())
    runtime_hud.hero_status_text:set_text(string.format(
      '场上敌人 %d  试炼进行中 %d  待领奖励 %d  %s',
      STATE.total_enemy_alive or 0,
      env.get_active_challenge_count(),
      env.get_reward_queue_count and env.get_reward_queue_count() or 0,
      get_recovery_text()
    ))

    local skill_ready = not STATE.game_finished
      and ((STATE.skill_points or 0) > 0 or STATE.awaiting_upgrade == true)
    local skill_highlight = (STATE.skill_points or 0) > 0 or STATE.awaiting_upgrade == true
    runtime_hud.skill_button.button:set_button_enable(skill_ready)
    runtime_hud.skill_button.button:set_text(
      STATE.awaiting_upgrade
        and '技能 G 继续选择'
        or string.format('技能 G  剩余 %d 点', STATE.skill_points or 0)
    )
    if skill_highlight then
      runtime_hud.skill_button.bg:set_image_color(56, 128, 206, 235)
      runtime_hud.skill_button.shadow:set_image_color(20, 44, 82, 156)
      runtime_hud.skill_button.button:set_text_color(245, 248, 255, 255)
    else
      runtime_hud.skill_button.bg:set_image_color(58, 84, 112, 212)
      runtime_hud.skill_button.shadow:set_image_color(6, 10, 18, 110)
      runtime_hud.skill_button.button:set_text_color(196, 212, 230, 255)
    end

    local bond_awaiting = STATE.bond_runtime and STATE.bond_runtime.awaiting_choice == true
    local wood = STATE.resources and STATE.resources.wood or 0
    local bond_ready = not STATE.game_finished and (bond_awaiting or wood >= BOND_DRAW_COST)
    runtime_hud.bond_button.button:set_button_enable(bond_ready)
    runtime_hud.bond_button.button:set_text(
      bond_awaiting
        and '羁绊 F 继续选择'
        or string.format('羁绊 F  消耗 %d 木', BOND_DRAW_COST)
    )
    if bond_awaiting or wood >= BOND_DRAW_COST then
      runtime_hud.bond_button.bg:set_image_color(92, 112, 152, 235)
      runtime_hud.bond_button.shadow:set_image_color(18, 34, 58, 148)
      runtime_hud.bond_button.button:set_text_color(245, 248, 255, 255)
    else
      runtime_hud.bond_button.bg:set_image_color(62, 72, 92, 208)
      runtime_hud.bond_button.shadow:set_image_color(6, 10, 18, 110)
      runtime_hud.bond_button.button:set_text_color(198, 210, 226, 255)
    end

    for challenge_id, button_ref in pairs(runtime_hud.challenge_buttons) do
      local status = decorate_challenge_status(challenge_id, get_challenge_button_state(challenge_id))
      button_ref.button:set_text(status.button_text or '')
      button_ref.bg:set_image_color(status.bg[1], status.bg[2], status.bg[3], status.bg[4])
      button_ref.button:set_text_color(status.text[1], status.text[2], status.text[3], status.text[4])
      button_ref.shadow:set_image_color(status.shadow[1], status.shadow[2], status.shadow[3], status.shadow[4])
    end

    local treasure_pending = env.has_pending_treasure_choice and env.has_pending_treasure_choice() or false
    local treasure_button = runtime_hud.challenge_buttons.treasure_trial
    if treasure_pending and treasure_button then
      treasure_button.button:set_button_enable(true)
      treasure_button.button:set_text('宝物 R 继续选择')
      treasure_button.bg:set_image_color(152, 106, 74, 235)
      treasure_button.shadow:set_image_color(46, 24, 12, 150)
      treasure_button.button:set_text_color(255, 244, 228, 255)
    end
    hide_legacy_decision_panel(runtime_hud)
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

    local hud_width, hud_height = get_hud_metrics(hud, y3)
    local scale = get_hud_scale(hud, y3)

    local center_root = create_panel(
      hud,
      0,
      0,
      scaled(layout.top_bar.width, scale),
      scaled(layout.top_bar.height, scale),
      { 9, 16, 27, 192 },
      { 30, 30, 24, 24 },
      9400,
      runtime_skin.top_bar
    )
    center_root:set_anchor(0.5, 1)
    center_root:set_relative_parent_pos('顶部', scaled(layout.top_bar.top, scale))
    set_percent_pos(env.get_player(), center_root, 43.5, 100)

    local center_glow = create_panel(
      center_root,
      scaled(layout.top_glow.x, scale),
      scaled(layout.top_glow.y, scale),
      scaled(layout.top_glow.width, scale),
      scaled(layout.top_glow.height, scale),
      { 56, 112, 184, 54 },
      { 8, 8, 8, 8 },
      9401
    )
    center_glow:set_anchor(0.5, 0.5)

    local stage_panel = create_panel(
      center_root,
      scaled(94, scale),
      scaled(58, scale),
      scaled(170, scale),
      scaled(34, scale),
      theme.palette.panel_alt,
      theme.insets.normal,
      9401
    )
    local stage_text = create_text(
      stage_panel,
      scaled(85, scale),
      scaled(17, scale),
      scaled(150, scale),
      scaled(18, scale),
      scaled(13, scale),
      theme.palette.text,
      '中',
      '中',
      9402
    )

    local wave_panel = create_panel(
      center_root,
      scaled(532, scale),
      scaled(56, scale),
      scaled(232, scale),
      scaled(38, scale),
      theme.palette.accent,
      theme.insets.normal,
      9401
    )
    local wave_title = create_text(
      wave_panel,
      scaled(116, scale),
      scaled(20, scale),
      scaled(216, scale),
      scaled(22, scale),
      scaled(22, scale),
      theme.palette.text,
      '中',
      '中',
      9402
    )
    local wave_status = create_text(
      center_root,
      scaled(532, scale),
      scaled(24, scale),
      scaled(286, scale),
      scaled(16, scale),
      scaled(12, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9402
    )

    local boss_panel = create_panel(
      center_root,
      scaled(918, scale),
      scaled(56, scale),
      scaled(222, scale),
      scaled(34, scale),
      theme.palette.warning,
      theme.insets.normal,
      9401
    )
    local boss_name = create_text(
      boss_panel,
      scaled(62, scale),
      scaled(18, scale),
      scaled(100, scale),
      scaled(16, scale),
      scaled(12, scale),
      theme.palette.text,
      '左',
      '中',
      9402
    )
    local boss_state = create_text(
      boss_panel,
      scaled(158, scale),
      scaled(18, scale),
      scaled(118, scale),
      scaled(16, scale),
      scaled(12, scale),
      theme.palette.text,
      '右',
      '中',
      9402
    )

    local timer_text = create_text(
      center_root,
      scaled(532, scale),
      scaled(80, scale),
      scaled(280, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9402
    )
    local gold_icon = create_panel(
      center_root,
      scaled(24, scale),
      scaled(44, scale),
      scaled(20, scale),
      scaled(20, scale),
      { 255, 226, 150, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    gold_icon:set_anchor(0.5, 0.5)
    local wood_icon = create_panel(
      center_root,
      scaled(170, scale),
      scaled(44, scale),
      scaled(20, scale),
      scaled(20, scale),
      { 198, 244, 188, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    wood_icon:set_anchor(0.5, 0.5)
    local skill_icon = create_panel(
      center_root,
      scaled(724, scale),
      scaled(44, scale),
      scaled(18, scale),
      scaled(18, scale),
      { 212, 228, 255, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    skill_icon:set_anchor(0.5, 0.5)
    local challenge_icon = create_panel(
      center_root,
      scaled(852, scale),
      scaled(44, scale),
      scaled(18, scale),
      scaled(18, scale),
      { 255, 216, 176, 255 },
      theme.insets.soft,
      9403,
      runtime_skin.top_bar_icon
    )
    challenge_icon:set_anchor(0.5, 0.5)

    local _, gold_value = create_stat_text(
      center_root,
      scaled(40, scale),
      scaled(38, scale),
      scaled(86, scale),
      '金币',
      '0',
      { 194, 176, 112, 255 },
      theme.palette.gold,
      '左',
      scale
    )
    local _, wood_value = create_stat_text(
      center_root,
      scaled(186, scale),
      scaled(38, scale),
      scaled(86, scale),
      '木材',
      '0',
      { 158, 194, 160, 255 },
      theme.palette.wood,
      '左',
      scale
    )
    local _, skill_value = create_stat_text(
      center_root,
      scaled(742, scale),
      scaled(38, scale),
      scaled(90, scale),
      '技能点',
      '0',
      theme.palette.text_muted,
      theme.palette.text,
      '左',
      scale
    )
    local _, challenge_value = create_stat_text(
      center_root,
      scaled(872, scale),
      scaled(38, scale),
      scaled(100, scale),
      '挑战',
      '0/0',
      { 210, 178, 132, 255 },
      { 255, 236, 212, 255 },
      '左',
      scale
    )

    local left_root = create_panel(
      hud,
      0,
      0,
      scaled(layout.left_bar.width, scale),
      scaled(layout.left_bar.height, scale),
      { 10, 18, 28, 174 },
      theme.insets.soft,
      9400,
      runtime_skin.left_bar
    )
    left_root:set_anchor(0.5, 1)
    left_root:set_relative_parent_pos('顶部', scaled(layout.left_bar.top, scale))
    set_percent_pos(env.get_player(), left_root, 43.5, 100)

    local challenge_summary_text = create_text(
      left_root,
      scaled(406, scale),
      scaled(18, scale),
      scaled(248, scale),
      scaled(14, scale),
      scaled(11, scale),
      theme.palette.text_soft,
      '中',
      '中',
      9402
    )
    local hero_progress_text = create_text(
      left_root,
      scaled(86, scale),
      scaled(18, scale),
      scaled(210, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text,
      '左',
      '中',
      9402
    )
    local hero_hp_text = create_text(
      left_root,
      scaled(748, scale),
      scaled(18, scale),
      scaled(138, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text,
      '右',
      '中',
      9402
    )
    local hero_status_text = create_text(
      left_root,
      scaled(612, scale),
      scaled(18, scale),
      scaled(158, scale),
      scaled(14, scale),
      scaled(12, scale),
      theme.palette.text_muted,
      '右',
      '中',
      9402
    )

    local right_root = create_panel(
      hud,
      0,
      0,
      scaled(layout.bottom_bar.width, scale),
      scaled(layout.bottom_bar.height, scale),
      { 9, 16, 27, 182 },
      theme.insets.normal,
      9400,
      runtime_skin.bottom_bar
    )
    right_root:set_anchor(0.5, 0)
    right_root:set_relative_parent_pos('底部', scaled(layout.bottom_bar.bottom, scale))
    set_percent_pos(env.get_player(), right_root, 50, 0)

    local decision_root = create_panel(
      hud,
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

    local decision_logo = create_panel(
      decision_root,
      scaled(48, scale),
      scaled(212, scale),
      scaled(28, scale),
      scaled(28, scale),
      { 196, 222, 255, 255 },
      theme.insets.soft,
      9442,
      runtime_skin.decision_logo
    )
    decision_logo:set_anchor(0.5, 0.5)
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

    local skill_button = create_button(
      right_root,
      scaled(568, scale),
      scaled(28, scale),
      scaled(118, scale),
      scaled(30, scale),
      '技能 G',
      function()
        env.show_upgrade_choices()
        refresh_runtime_hud()
      end,
      {
        font_size = scaled(12, scale),
        style = 'runtime_action',
        bg_color = { 58, 84, 112, 224 },
      }
    )
    local bond_button = create_button(
      right_root,
      scaled(446, scale),
      scaled(28, scale),
      scaled(114, scale),
      scaled(30, scale),
      '羁绊 F',
      function()
        env.try_bond_draw()
        refresh_runtime_hud()
      end,
      {
        font_size = scaled(12, scale),
        style = 'runtime_action',
        bg_color = { 84, 100, 132, 224 },
      }
    )

    local challenge_buttons = {
      gold_trial = create_button(
        right_root,
        scaled(72, scale),
        scaled(28, scale),
        scaled(88, scale),
        scaled(30, scale),
        '金币 Q',
        function()
          env.try_start_challenge('gold_trial')
          refresh_runtime_hud()
        end,
        {
          font_size = scaled(11, scale),
          style = 'runtime_trial_gold',
          bg_color = { 126, 104, 52, 224 },
        }
      ),
      wood_trial = create_button(
        right_root,
        scaled(170, scale),
        scaled(28, scale),
        scaled(88, scale),
        scaled(30, scale),
        '木材 W',
        function()
          env.try_start_challenge('wood_trial')
          refresh_runtime_hud()
        end,
        {
          font_size = scaled(11, scale),
          style = 'runtime_trial_wood',
          bg_color = { 74, 118, 86, 224 },
        }
      ),
      exp_trial = create_button(
        right_root,
        scaled(268, scale),
        scaled(28, scale),
        scaled(88, scale),
        scaled(30, scale),
        '经验 E',
        function()
          env.try_start_challenge('exp_trial')
          refresh_runtime_hud()
        end,
        {
          font_size = scaled(11, scale),
          style = 'runtime_trial_exp',
          bg_color = { 74, 98, 146, 224 },
        }
      ),
      treasure_trial = create_button(
        right_root,
        scaled(366, scale),
        scaled(28, scale),
        scaled(72, scale),
        scaled(30, scale),
        '宝物 R',
        function()
          env.try_treasure_entry()
          refresh_runtime_hud()
        end,
        {
          font_size = scaled(11, scale),
          style = 'runtime_trial_treasure',
          bg_color = { 128, 90, 68, 224 },
        }
      ),
    }
    local trial_label = create_text(
      right_root,
      scaled(76, scale),
      scaled(50, scale),
      scaled(120, scale),
      scaled(12, scale),
      scaled(10, scale),
      { 164, 186, 214, 255 },
      nil,
      nil,
      9402
    )
    trial_label:set_text('试炼入口')
    trial_label:set_text('试炼入口')
    local action_label = create_text(
      right_root,
      scaled(456, scale),
      scaled(50, scale),
      scaled(140, scale),
      scaled(12, scale),
      scaled(10, scale),
      { 164, 186, 214, 255 },
      nil,
      nil,
      9402
    )
    action_label:set_text('成长操作')

    action_label:set_text('成长操作')
    local viewport_notice = create_text(
      right_root,
      scaled(14, scale),
      scaled(50, scale),
      scaled(180, scale),
      scaled(12, scale),
      scaled(10, scale),
      { 114, 142, 176, 255 },
      '左',
      '中',
      9402
    )
    viewport_notice:set_text('界面就绪')

    viewport_notice:set_text('战斗监测中')
    STATE.runtime_hud = {
      center_root = center_root,
      center_glow = center_glow,
      left_root = left_root,
      right_root = right_root,
      stage_text = stage_text,
      wave_title = wave_title,
      wave_status = wave_status,
      boss_panel = boss_panel,
      boss_name = boss_name,
      boss_state = boss_state,
      timer_text = timer_text,
      gold_value = gold_value,
      wood_value = wood_value,
      skill_value = skill_value,
      challenge_value = challenge_value,
      hero_progress_text = hero_progress_text,
      hero_hp_text = hero_hp_text,
      hero_status_text = hero_status_text,
      challenge_summary_text = challenge_summary_text,
      decision_root = decision_root,
      decision_header_line = decision_header_line,
      decision_caption = decision_caption,
      decision_title = decision_title,
      decision_subtitle = decision_subtitle,
      decision_hint = decision_hint,
      decision_options = decision_options,
      skill_button = skill_button,
      bond_button = bond_button,
      challenge_buttons = challenge_buttons,
      trial_label = trial_label,
      action_label = action_label,
      viewport_notice = viewport_notice,
    }

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
      runtime_hud.center_root:set_visible(visible == true)
      runtime_hud.left_root:set_visible(visible == true)
      runtime_hud.right_root:set_visible(visible == true)
      hide_legacy_decision_panel(runtime_hud)
    end,
  }
end

return M
