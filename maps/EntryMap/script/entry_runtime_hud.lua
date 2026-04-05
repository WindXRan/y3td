local ui_res = require 'ui_res'

local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local y3 = env.y3
  local round_number = env.round_number

  local BOND_DRAW_COST = 100

  local function get_hud_root()
    local ok, hud = pcall(y3.ui.get_ui, env.get_player(), 'GameHUD')
    if not ok or not hud then
      return nil
    end
    return hud
  end

  local function get_hud_metrics(hud)
    local width = round_number(hud:get_width())
    local height = round_number(hud:get_height())
    if width <= 0 then
      width = round_number(y3.ui.get_window_width())
    end
    if height <= 0 then
      height = round_number(y3.ui.get_window_height())
    end
    return width, height
  end

  local function clamp(value, min_value, max_value)
    if value < min_value then
      return min_value
    end
    if value > max_value then
      return max_value
    end
    return value
  end

  local function get_hud_scale(width, height)
    local base_width = 1920
    local base_height = 1080
    return clamp(math.min(width / base_width, height / base_height), 0.82, 1.18)
  end

  local function scaled(value, scale)
    return round_number(value * scale)
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

  local function evaluate_unlock(rule)
    if not rule then
      return true
    end
    if rule.type == 'wave_started' then
      return (STATE.started_wave_count or 0) >= (rule.value or 0)
    end
    if rule.type == 'bond_draw_count' then
      return (STATE.bond_draw_count or 0) >= (rule.value or 0)
    end
    if rule.type == 'hero_level' then
      return env.get_hero_level() >= (rule.value or 0)
    end
    if rule.type == 'boss_kill_wave' then
      return STATE.defeated_boss_waves and STATE.defeated_boss_waves[rule.value] == true
    end
    return false
  end

  local function get_active_wave()
    return STATE.active_wave
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
    local active_wave = get_active_wave()
    if not active_wave or not active_wave.wave then
      return '按 Space 查看当前战况'
    end
    return string.format(
      '本波 %s  场上敌人 %d',
      format_time(active_wave.elapsed or 0),
      STATE.total_enemy_alive or 0
    )
  end

  local function get_boss_display()
    local active_wave = get_active_wave()
    if not active_wave or not active_wave.wave then
      return {
        name = 'Boss 未登场',
        state = '等待本波开始',
        bg = { 42, 56, 76, 228 },
        text = { 214, 226, 242, 255 },
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
          bg = { 100, 34, 46, 232 },
          text = { 255, 236, 240, 255 },
        }
      end
      return {
        name = boss_name,
        state = '已击败',
        bg = { 40, 94, 64, 228 },
        text = { 232, 247, 236, 255 },
      }
    end

    local remain = math.max(0, (active_wave.wave.boss_spawn_sec or 0) - (active_wave.elapsed or 0))
    return {
      name = boss_name,
      state = string.format('%.1f 秒后登场', remain),
      bg = { 96, 76, 28, 228 },
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
        bg = { 56, 66, 82, 210 },
        text = { 214, 226, 242, 255 },
      }
    end

    if STATE.active_challenges and STATE.active_challenges[challenge_id] then
      local instance = STATE.active_challenges[challenge_id]
      local remain = math.max(0, (def.duration_sec or 0) - (instance.elapsed or 0))
      return {
        summary = string.format('%s %s', def.hotkey or '?', format_time(remain)),
        bg = { 86, 112, 52, 228 },
        text = { 240, 248, 226, 255 },
      }
    end

    if not evaluate_unlock(def.unlock_rule) then
      return {
        summary = string.format('%s 未解', def.hotkey or '?'),
        bg = { 66, 70, 84, 205 },
        text = { 174, 182, 196, 255 },
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
      bg = { 46, 88, 120, 228 },
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

  local function apply_panel_style(panel, color, insets, image)
    panel:set_image(image or ui_res.common.empty)
    panel:set_image_color(color[1], color[2], color[3], color[4] or 255)
    panel:set_ui_9_enable(true)
    panel:set_ui_9(insets[1], insets[2], insets[3], insets[4])
    return panel
  end

  local function create_panel(parent, x, y, width, height, color, insets, z_order, image)
    local panel = parent:create_child('图片')
    panel:set_ui_size(width, height)
    panel:set_pos(x, y)
    apply_panel_style(panel, color, insets or { 18, 18, 18, 18 }, image)
    if z_order then
      panel:set_z_order(z_order)
    end
    return panel
  end

  local function create_text(parent, x, y, width, height, font_size, color, h_align, v_align, z_order)
    local text = parent:create_child('文本')
    text:set_ui_size(width, height)
    text:set_pos(x, y)
    text:set_font_size(font_size)
    text:set_text_color(color[1], color[2], color[3], color[4] or 255)
    text:set_text_alignment(h_align or '中', v_align or '中')
    if z_order then
      text:set_z_order(z_order)
    end
    return text
  end

  local function create_button(parent, x, y, width, height, label, callback, font_size, accent_color)
    local shadow = create_panel(
      parent,
      x,
      y - 2,
      width + 8,
      height + 8,
      { 8, 14, 22, 120 },
      { 16, 16, 16, 16 },
      9400
    )
    local bg = create_panel(
      parent,
      x,
      y,
      width,
      height,
      accent_color or { 56, 90, 138, 232 },
      { 18, 18, 18, 18 },
      9401
    )
    local button = parent:create_child('按钮')
    button:set_ui_size(width, height)
    button:set_pos(x, y)
    button:set_text(label)
    button:set_font_size(font_size or 17)
    button:set_text_color(245, 248, 255, 255)
    button:set_btn_status_image(1, ui_res.common_tip.btn_blue_normal)
    button:set_btn_status_image(2, ui_res.common_tip.btn_blue_hover)
    button:set_btn_status_image(3, ui_res.common_tip.btn_blue_press)
    button:set_btn_status_image(4, ui_res.common_tip.btn_blue_disabled)
    button:set_z_order(9402)
    button:add_fast_event('左键-点击', function()
      callback()
    end)
    return {
      shadow = shadow,
      bg = bg,
      button = button,
    }
  end

  local function is_hud_alive(runtime_hud)
    return runtime_hud
      and runtime_hud.center_root
      and runtime_hud.left_root
      and runtime_hud.right_root
      and not runtime_hud.center_root:is_removed()
      and not runtime_hud.left_root:is_removed()
      and not runtime_hud.right_root:is_removed()
  end

  local function refresh_runtime_hud()
    local runtime_hud = STATE.runtime_hud
    if not is_hud_alive(runtime_hud) then
      return
    end

    local boss = get_boss_display()
    runtime_hud.stage_text:set_text(get_stage_text())
    runtime_hud.wave_title:set_text(get_wave_title_text())
    runtime_hud.wave_status:set_text(get_wave_status_text())
    runtime_hud.timer_text:set_text(string.format('战斗 %s', format_time(STATE.runtime_elapsed or 0)))

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
    runtime_hud.hero_status_text:set_text(string.format(
      '场上敌人 %d  挑战中 %d  待奖 %d  %s',
      STATE.total_enemy_alive or 0,
      env.get_active_challenge_count(),
      env.get_reward_queue_count and env.get_reward_queue_count() or 0,
      get_recovery_text()
    ))
    runtime_hud.challenge_summary_text:set_text(get_challenge_summary_text())

    local skill_ready = not STATE.game_finished
      and ((STATE.skill_points or 0) > 0 or STATE.awaiting_upgrade == true)
    local skill_highlight = (STATE.skill_points or 0) > 0 or STATE.awaiting_upgrade == true
    runtime_hud.skill_button.button:set_text(
      STATE.awaiting_upgrade
        and '技能 G 继续选择'
        or string.format('技能 G  %d点', STATE.skill_points or 0)
    )
    runtime_hud.skill_button.button:set_button_enable(skill_ready)
    if skill_highlight then
      runtime_hud.skill_button.bg:set_image_color(44, 112, 186, 235)
    else
      runtime_hud.skill_button.bg:set_image_color(58, 84, 112, 212)
    end

    local bond_awaiting = STATE.bond_runtime and STATE.bond_runtime.awaiting_choice == true
    local wood = STATE.resources and STATE.resources.wood or 0
    local bond_ready = not STATE.game_finished and (bond_awaiting or wood >= BOND_DRAW_COST)
    runtime_hud.bond_button.button:set_text(
      bond_awaiting
        and '羁绊 F 继续选择'
        or string.format('羁绊 F  %d木', BOND_DRAW_COST)
    )
    runtime_hud.bond_button.button:set_button_enable(bond_ready)
    if bond_awaiting or wood >= BOND_DRAW_COST then
      runtime_hud.bond_button.bg:set_image_color(76, 102, 142, 235)
    else
      runtime_hud.bond_button.bg:set_image_color(62, 72, 92, 208)
    end

    for challenge_id, button_ref in pairs(runtime_hud.challenge_buttons) do
      local status = get_challenge_button_state(challenge_id)
      button_ref.bg:set_image_color(status.bg[1], status.bg[2], status.bg[3], status.bg[4])
      button_ref.button:set_text_color(status.text[1], status.text[2], status.text[3], status.text[4])
    end
  end

  local function create_resource_card(parent, x, y, width, height, title, title_color, value_color)
    local bg = create_panel(parent, x, y, width, height, { 22, 34, 50, 232 }, { 18, 18, 18, 18 }, 9401)
    local label = create_text(
      bg,
      round_number(width * 0.18),
      round_number(height * 0.68),
      round_number(width * 0.5),
      round_number(height * 0.22),
      round_number(height * 0.2),
      title_color or { 160, 182, 208, 255 },
      '左',
      '中',
      9402
    )
    label:set_text(title)
    local value = create_text(
      bg,
      round_number(width * 0.5),
      round_number(height * 0.36),
      round_number(width * 0.76),
      round_number(height * 0.32),
      round_number(height * 0.32),
      value_color or { 244, 248, 255, 255 },
      '中',
      '中',
      9402
    )
    return bg, label, value
  end

  local function create_info_row(parent, x, y, width, height, title, value, title_color, value_color)
    local row = create_panel(parent, x, y, width, height, { 20, 30, 44, 214 }, { 16, 16, 16, 16 }, 9400)
    local title_text = create_text(
      row,
      round_number(width * 0.2),
      round_number(height * 0.64),
      round_number(width * 0.25),
      round_number(height * 0.2),
      round_number(height * 0.2),
      title_color or { 154, 180, 210, 255 },
      '左',
      '中',
      9402
    )
    title_text:set_text(title)
    local value_text = create_text(
      row,
      round_number(width * 0.64),
      round_number(height * 0.48),
      round_number(width * 0.52),
      round_number(height * 0.3),
      round_number(height * 0.24),
      value_color or { 238, 244, 255, 255 },
      '中',
      '中',
      9402
    )
    value_text:set_text(value)
    return row, title_text, value_text
  end

  local function create_stat_text(parent, x, y, width, label, value, label_color, value_color, align)
    local label_text = create_text(
      parent,
      x,
      y + 9,
      width,
      10,
      10,
      label_color or { 144, 168, 196, 255 },
      align or '左',
      '中',
      9402
    )
    label_text:set_text(label)

    local value_text = create_text(
      parent,
      x,
      y - 7,
      width,
      16,
      14,
      value_color or { 240, 245, 255, 255 },
      align or '左',
      '中',
      9402
    )
    value_text:set_text(value)
    return label_text, value_text
  end

  local function set_percent_pos(ui, x, y)
    GameAPI.set_ui_comp_pos_percent(env.get_player().handle, ui.handle, x, y)
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

    local hud_width, hud_height = get_hud_metrics(hud)
    local scale = get_hud_scale(hud_width, hud_height)
    local center_root = create_panel(
      hud,
      0,
      0,
      scaled(1030, scale),
      scaled(86, scale),
      { 10, 18, 28, 176 },
      { 26, 26, 22, 22 },
      9400
    )
    center_root:set_anchor(0.5, 1)
    center_root:set_relative_parent_pos('顶部', scaled(12, scale))
    set_percent_pos(center_root, 43.5, 100)

    local center_backplate = center_root

    local stage_panel = create_panel(
      center_root,
      scaled(86, scale),
      scaled(52, scale),
      scaled(142, scale),
      scaled(30, scale),
      { 36, 58, 88, 226 },
      { 18, 18, 16, 16 },
      9401
    )
    local stage_text = create_text(
      stage_panel,
      scaled(71, scale),
      scaled(15, scale),
      scaled(126, scale),
      scaled(18, scale),
      scaled(13, scale),
      { 208, 222, 240, 255 },
      '中',
      '中',
      9402
    )

    local wave_panel = create_panel(
      center_root,
      scaled(516, scale),
      scaled(50, scale),
      scaled(210, scale),
      scaled(34, scale),
      { 44, 82, 124, 230 },
      { 22, 22, 18, 18 },
      9401
    )
    local wave_title = create_text(
      wave_panel,
      scaled(105, scale),
      scaled(18, scale),
      scaled(194, scale),
      scaled(22, scale),
      scaled(22, scale),
      { 246, 249, 255, 255 },
      '中',
      '中',
      9402
    )
    local wave_status = create_text(
      center_root,
      scaled(516, scale),
      scaled(22, scale),
      scaled(250, scale),
      scaled(16, scale),
      scaled(12, scale),
      { 170, 192, 220, 255 },
      '中',
      '中',
      9402
    )

    local boss_panel = create_panel(
      center_root,
      scaled(888, scale),
      scaled(52, scale),
      scaled(204, scale),
      scaled(30, scale),
      { 108, 88, 42, 220 },
      { 18, 18, 16, 16 },
      9401
    )
    local boss_name = create_text(
      boss_panel,
      scaled(52, scale),
      scaled(15, scale),
      scaled(90, scale),
      scaled(16, scale),
      scaled(12, scale),
      { 255, 243, 214, 255 },
      '左',
      '中',
      9402
    )
    local boss_state = create_text(
      boss_panel,
      scaled(146, scale),
      scaled(15, scale),
      scaled(108, scale),
      scaled(16, scale),
      scaled(12, scale),
      { 255, 243, 214, 255 },
      '右',
      '中',
      9402
    )

    local timer_text = create_text(
      center_root,
      scaled(516, scale),
      scaled(72, scale),
      scaled(280, scale),
      scaled(14, scale),
      scaled(12, scale),
      { 188, 206, 230, 255 },
      '中',
      '中',
      9402
    )

    local _, gold_value = create_stat_text(
      center_root,
      scaled(38, scale),
      scaled(34, scale),
      scaled(74, scale),
      '金币',
      '0',
      { 188, 176, 116, 255 },
      { 255, 243, 194, 255 },
      '左'
    )
    local _, wood_value = create_stat_text(
      center_root,
      scaled(176, scale),
      scaled(34, scale),
      scaled(74, scale),
      '木材',
      '0',
      { 158, 194, 160, 255 },
      { 225, 248, 224, 255 },
      '左'
    )
    local _, skill_value = create_stat_text(
      center_root,
      scaled(716, scale),
      scaled(34, scale),
      scaled(82, scale),
      '技能点',
      '0',
      { 164, 188, 224, 255 },
      { 236, 244, 255, 255 },
      '左'
    )
    local _, challenge_value = create_stat_text(
      center_root,
      scaled(836, scale),
      scaled(34, scale),
      scaled(96, scale),
      '挑战',
      '0/0',
      { 210, 178, 132, 255 },
      { 255, 236, 212, 255 },
      '左'
    )

    local left_root = create_panel(
      hud,
      0,
      0,
      scaled(760, scale),
      scaled(28, scale),
      { 14, 22, 34, 154 },
      { 16, 16, 14, 14 },
      9400
    )
    left_root:set_anchor(0.5, 1)
    left_root:set_relative_parent_pos('顶部', scaled(102, scale))
    set_percent_pos(left_root, 43.5, 100)

    local hero_panel = left_root
    local challenge_summary_text = create_text(
      hero_panel,
      scaled(378, scale),
      scaled(14, scale),
      scaled(224, scale),
      scaled(14, scale),
      scaled(11, scale),
      { 176, 200, 228, 255 },
      '中',
      '中',
      9402
    )
    local hero_progress_text = create_text(
      hero_panel,
      scaled(74, scale),
      scaled(14, scale),
      scaled(180, scale),
      scaled(14, scale),
      scaled(12, scale),
      { 244, 248, 255, 255 },
      '左',
      '中',
      9402
    )
    local hero_hp_text = create_text(
      hero_panel,
      scaled(688, scale),
      scaled(14, scale),
      scaled(128, scale),
      scaled(14, scale),
      scaled(12, scale),
      { 214, 228, 244, 255 },
      '右',
      '中',
      9402
    )
    local hero_status_text = create_text(
      hero_panel,
      scaled(560, scale),
      scaled(14, scale),
      scaled(140, scale),
      scaled(14, scale),
      scaled(12, scale),
      { 164, 186, 214, 255 },
      '右',
      '中',
      9402
    )

    local right_root = create_panel(
      hud,
      0,
      0,
      scaled(668, scale),
      scaled(50, scale),
      { 10, 18, 28, 154 },
      { 20, 20, 16, 16 },
      9400
    )
    right_root:set_anchor(0.5, 0)
    right_root:set_relative_parent_pos('底部', scaled(132, scale))
    set_percent_pos(right_root, 50, 0)

    local action_plate = right_root

    local skill_button = create_button(
      right_root,
      scaled(546, scale),
      scaled(25, scale),
      scaled(112, scale),
      scaled(28, scale),
      '技能 G',
      function()
        env.show_upgrade_choices()
        refresh_runtime_hud()
      end,
      scaled(12, scale),
      { 58, 84, 112, 224 }
    )
    local bond_button = create_button(
      right_root,
      scaled(430, scale),
      scaled(25, scale),
      scaled(108, scale),
      scaled(28, scale),
      '羁绊 F',
      function()
        env.try_bond_draw()
        refresh_runtime_hud()
      end,
      scaled(12, scale),
      { 84, 100, 132, 224 }
    )

    local challenge_buttons = {
      gold_trial = create_button(
        right_root,
        scaled(70, scale),
        scaled(25, scale),
        scaled(84, scale),
        scaled(28, scale),
        '金币 Q',
        function()
          env.try_start_challenge('gold_trial')
          refresh_runtime_hud()
        end,
        scaled(11, scale),
        { 126, 104, 52, 224 }
      ),
      wood_trial = create_button(
        right_root,
        scaled(162, scale),
        scaled(25, scale),
        scaled(84, scale),
        scaled(28, scale),
        '木材 W',
        function()
          env.try_start_challenge('wood_trial')
          refresh_runtime_hud()
        end,
        scaled(11, scale),
        { 74, 118, 86, 224 }
      ),
      exp_trial = create_button(
        right_root,
        scaled(254, scale),
        scaled(25, scale),
        scaled(84, scale),
        scaled(28, scale),
        '经验 E',
        function()
          env.try_start_challenge('exp_trial')
          refresh_runtime_hud()
        end,
        scaled(11, scale),
        { 74, 98, 146, 224 }
      ),
      treasure_trial = create_button(
        right_root,
        scaled(346, scale),
        scaled(25, scale),
        scaled(76, scale),
        scaled(28, scale),
        '宝物 R',
        function()
          env.try_start_challenge('treasure_trial')
          refresh_runtime_hud()
        end,
        scaled(11, scale),
        { 128, 90, 68, 224 }
      ),
    }

    STATE.runtime_hud = {
      center_root = center_root,
      left_root = left_root,
      right_root = right_root,
      center_backplate = center_backplate,
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
      skill_button = skill_button,
      bond_button = bond_button,
      challenge_buttons = challenge_buttons,
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
    end,
  }
end

return M
