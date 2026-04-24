local M = {}

function M.create(env)
  local STATE = env.STATE
  local CONFIG = env.CONFIG
  local round_number = env.round_number
  local hero_attr_system = env.hero_attr_system
  local get_current_wave = env.get_current_wave
  local get_boss_name = env.get_boss_name
  local get_hero_progress_text = env.get_hero_progress_text
  local get_reward_queue_count = env.get_reward_queue_count
  local get_reward_queue = env.get_reward_queue
  local get_mark_runtime = env.get_mark_runtime
  local get_treasure_runtime = env.get_treasure_runtime
  local get_treasure_quality_label = env.get_treasure_quality_label
  local get_treasure_active_count = env.get_treasure_active_count
  local get_mark_active_count = env.get_mark_active_count
  local build_treasure_slot_text = env.build_treasure_slot_text
  local build_mark_slot_text = env.build_mark_slot_text
  local get_bond_runtime_bonus = env.get_bond_runtime_bonus
  local build_attack_skill_slot_text = env.build_attack_skill_slot_text
  local build_bond_slot_text = env.build_bond_slot_text
  local build_bond_choice_preview_text = env.build_bond_choice_preview_text
  local build_bond_progress_lines = env.build_bond_progress_lines

  local function get_active_challenge_count_value()
    local count = 0
    for _ in pairs(STATE.active_challenges or {}) do
      count = count + 1
    end
    return count
  end

  local function get_challenge_charge_total()
    if STATE.challenge_charge_map then
      local total = 0
      for _, charges in pairs(STATE.challenge_charge_map) do
        total = total + (tonumber(charges) or 0)
      end
      return total
    end
    return STATE.challenge_charges or 0
  end

  local function get_challenge_charge_max_total()
    if STATE.challenge_charge_map then
      local count = 0
      for _ in pairs(STATE.challenge_charge_map) do
        count = count + 1
      end
      return count * (CONFIG.challenge_rules.max_charges or 0)
    end
    return CONFIG.challenge_rules.max_charges or 0
  end

  local function format_attr_value(value)
    return round_number(value or 0)
  end

  local function get_hero_attr(name)
    if not STATE.hero or not STATE.hero.is_exist or not STATE.hero:is_exist() then
      return 0
    end
    if hero_attr_system then
      return hero_attr_system.get_attr(STATE.hero, name)
    end
    return STATE.hero:get_attr(name)
  end

  local function build_overview_summary_lines()
    if STATE.session_phase ~= 'battle' then
      return {
        string.format('当前阶段：局外 %s / %s', STATE.selected_stage_id or '未选章节', STATE.selected_mode_id or '未选模式'),
      }
    end

    local lines = {}
    local wave = get_current_wave()
      lines[#lines + 1] = string.format(
      '层数：%s / %s',
      STATE.current_stage_def and (STATE.current_stage_def.display_label or STATE.current_stage_def.display_name) or '未命名章节',
      STATE.current_mode_def and STATE.current_mode_def.display_name or '未命名模式'
    )
    lines[#lines + 1] = string.format('波次：%s', wave and wave.name or '未开始')

    if STATE.active_wave and STATE.active_wave.wave then
      if STATE.active_wave.boss_spawned then
        lines[#lines + 1] = string.format('Boss：%s 已登场', get_boss_name(STATE.active_wave.wave))
      else
        lines[#lines + 1] = string.format(
          'Boss：%.1f 秒后登场',
          math.max(0, (STATE.active_wave.wave.boss_spawn_sec or 0) - (STATE.active_wave.elapsed or 0))
        )
      end
    else
      lines[#lines + 1] = 'Boss：当前无主线波次'
    end

    if STATE.hero and STATE.hero:is_exist() then
      lines[#lines + 1] = string.format(
        '英雄：%s  HP %d/%d  攻击 %d  攻速 %d',
        get_hero_progress_text(),
        format_attr_value(STATE.hero:get_hp()),
        format_attr_value(get_hero_attr('生命结算值')),
        format_attr_value(get_hero_attr('攻击结算值')),
        format_attr_value(get_hero_attr('攻击速度'))
      )
      lines[#lines + 1] = string.format(
        '暴击 %d%%  爆伤 %d%%  吸血 %d%%  射程 %d',
        format_attr_value(get_hero_attr('物理暴击')),
        format_attr_value(get_hero_attr('物理暴伤')),
        format_attr_value(get_hero_attr('物理吸血')),
        format_attr_value(get_hero_attr('攻击范围'))
      )
    else
      lines[#lines + 1] = '英雄：当前未创建'
    end

    lines[#lines + 1] = string.format(
      '资源：金币 %d  木材 %d',
      STATE.resources and STATE.resources.gold or 0,
      STATE.resources and STATE.resources.wood or 0
    )
    lines[#lines + 1] = string.format(
      '挑战：%d/%d  进行中 %d  待领奖励 %d  敌人数 %d',
      get_challenge_charge_total(),
      get_challenge_charge_max_total(),
      get_active_challenge_count_value(),
      get_reward_queue_count(),
      STATE.total_enemy_alive or 0
    )

    return lines
  end

  local function build_attack_skill_overview_lines()
    return { build_attack_skill_slot_text(1) }
  end

  local function build_bond_overview_lines()
    local lines = {}
    for slot = 1, 7, 1 do
      lines[#lines + 1] = build_bond_slot_text(slot)
    end
    return lines
  end

  local function build_bond_progress_overview_lines()
    local lines = build_bond_progress_lines(8)
    if not lines or #lines == 0 then
      return { '当前没有可显示的道统进境。' }
    end
    return lines
  end

  local function build_treasure_and_mark_overview_lines()
    local lines = {}
    for slot = 1, 3, 1 do
      lines[#lines + 1] = build_treasure_slot_text(slot)
    end
    local mark_count = math.max(4, get_mark_active_count())
    for slot = 1, mark_count, 1 do
      lines[#lines + 1] = build_mark_slot_text(slot)
    end
    return lines
  end

  local function build_pending_overview_lines()
    local lines = {}
    local pending_kind = env.get_pending_round_choice_kind()
    if pending_kind == 'gear' then
      local runtime = STATE.gear_state
      local level = runtime
        and runtime.pending_affix_choice
        and runtime.pending_affix_choice.level
        or (runtime and runtime.items and runtime.items.weapon and runtime.items.weapon.level)
        or 0
      lines[#lines + 1] = string.format('当前待选：成长武器词条三选一（Lv.%d）', tonumber(level) or 0)
    elseif pending_kind == 'bond' then
      lines[#lines + 1] = '当前待选：仙缘感应三选一'
      local runtime = STATE.bond_runtime
      for index, choice in ipairs(runtime and runtime.current_choices or {}) do
        lines[#lines + 1] = build_bond_choice_preview_text(index, choice)
      end
    elseif pending_kind == 'treasure' then
      local runtime = get_treasure_runtime()
      if runtime.awaiting_replace and runtime.pending_replace_choice then
        lines[#lines + 1] = string.format(
          '当前待选：宝物替换 [%s] %s',
          get_treasure_quality_label(runtime.pending_replace_choice.quality),
          runtime.pending_replace_choice.name
        )
      else
        lines[#lines + 1] = '当前待选：宝物三选一'
      end
    elseif pending_kind == 'evolution' or pending_kind == 'mark' then
      local runtime = get_mark_runtime()
      local choice_count = runtime and runtime.current_choices and #runtime.current_choices or 0
      local pick_text = choice_count > 0 and string.format('英雄真身%d选1', choice_count) or '英雄真身抉择'
      lines[#lines + 1] = string.format(
        '当前待选：%s · %s',
        runtime.current_round and runtime.current_round.ui_title or '真身进化',
        pick_text
      )
    else
      lines[#lines + 1] = '当前没有进行中的待选轮次。'
    end

    local queue = get_reward_queue()
    if #queue <= 0 then
      lines[#lines + 1] = '奖励队列：空'
      return lines
    end

    lines[#lines + 1] = string.format('奖励队列：共 %d 项', #queue)
    for index = 1, math.min(4, #queue), 1 do
      local entry = queue[index]
      local label = entry.source_name or entry.kind or '未命名奖励'
      lines[#lines + 1] = string.format('%d. %s [%s]', index, label, tostring(entry.kind or 'unknown'))
    end
    return lines
  end

  local function build_attribute_summary_lines()
    if not STATE.hero or not STATE.hero:is_exist() then
      return { '英雄：当前未创建。' }
    end

    return {
      string.format('等级：%s', get_hero_progress_text()),
      string.format('生命：%d / %d',
        format_attr_value(STATE.hero:get_hp()),
        format_attr_value(get_hero_attr('生命结算值'))
      ),
      string.format('攻击：%d  攻速：%d  射程：%d',
        format_attr_value(get_hero_attr('攻击结算值')),
        format_attr_value(get_hero_attr('攻击速度')),
        format_attr_value(get_hero_attr('攻击范围'))
      ),
      string.format('暴击：%d%%  爆伤：%d%%  吸血：%d%%',
        format_attr_value(get_hero_attr('物理暴击')),
        format_attr_value(get_hero_attr('物理暴伤')),
        format_attr_value(get_hero_attr('物理吸血'))
      ),
    }
  end

  local function build_damage_bonus_lines()
    return {
      string.format('全伤加成：%d%%', format_attr_value(get_bond_runtime_bonus('all_damage_bonus') * 100)),
      string.format('技能加成：%d%%  普攻加成：%d%%',
        format_attr_value(get_bond_runtime_bonus('skill_damage_bonus') * 100),
        format_attr_value(get_bond_runtime_bonus('normal_attack_damage_bonus') * 100)
      ),
      string.format('Boss加成：%d%%  精英加成：%d%%',
        format_attr_value(get_bond_runtime_bonus('boss_damage_bonus') * 100),
        format_attr_value(get_bond_runtime_bonus('elite_damage_bonus') * 100)
      ),
      string.format('处决阈值：%d%%  处决增伤：%d%%',
        format_attr_value(get_bond_runtime_bonus('execute_threshold') * 100),
        format_attr_value(get_bond_runtime_bonus('execute_damage_bonus') * 100)
      ),
    }
  end

  local function build_skill_runtime_lines()
    local skill = STATE.skill_runtime or {}
    return {
      string.format('普攻追伤：%d%%  杀敌金币：%d',
        format_attr_value((skill.normal_attack_bonus_ratio or 0) * 100),
        format_attr_value(skill.bonus_gold_on_kill or 0)
      ),
      string.format('溅射：%d%% / 半径 %d',
        format_attr_value((skill.splash_ratio or 0) * 100),
        format_attr_value(skill.splash_radius or 0)
      ),
      string.format('连锁：%d%% / %d 跳 / %d%%',
        format_attr_value((skill.chain_chance or 0) * 100),
        format_attr_value(skill.chain_bounces or 0),
        format_attr_value((skill.chain_ratio or 0) * 100)
      ),
      string.format('医疗无人机：每 %d 杀回复 %d',
        format_attr_value(skill.medbot_every or 0),
        format_attr_value(skill.medbot_heal or 0)
      ),
      string.format('火炮：间隔 %d / 基础 %d / 系数 %d%% / 半径 %d',
        format_attr_value(skill.artillery_interval or 0),
        format_attr_value(skill.artillery_base or 0),
        format_attr_value((skill.artillery_ratio or 0) * 100),
        format_attr_value(skill.artillery_radius or 0)
      ),
    }
  end

  local function build_economy_bonus_lines()
    return {
      string.format('资源恢复：金币每秒 %+d  木材每秒 %+d',
        format_attr_value(get_bond_runtime_bonus('gold_per_sec_bonus')),
        format_attr_value(get_bond_runtime_bonus('wood_per_sec_bonus'))
      ),
      string.format('奖励倍率：金币 %+d%%  木材 %+d%%  经验 %+d%%',
        format_attr_value(env.get_treasure_reward_ratio('gold') * 100),
        format_attr_value(env.get_treasure_reward_ratio('wood') * 100),
        format_attr_value(env.get_treasure_reward_ratio('exp') * 100)
      ),
      string.format('被动收入：金币 %+d / 秒  木材 %+d / 秒',
        format_attr_value(env.get_treasure_passive_income('gold')),
        format_attr_value(env.get_treasure_passive_income('wood'))
      ),
      string.format('构筑计数：宝物 %d / 3  进化 %d  已结仙缘 %d',
        get_treasure_active_count(),
        get_mark_active_count(),
        STATE.bond_runtime and #(STATE.bond_runtime.owned_node_order or {}) or 0
      ),
    }
  end

  local function get_runtime_overview_model()
    if STATE.runtime_overview_mode == 'attr' then
      return {
        title = '局内属性总览',
        subtitle = string.format(
          '按 TAB 关闭属性面板  当前战斗时长 %s',
          os.date('!%M:%S', math.max(0, math.floor(STATE.runtime_elapsed or 0)))
        ),
        close_label = '关闭 TAB',
        sections = {
          summary = {
            title = '英雄面板',
            lines = build_attribute_summary_lines(),
          },
          skills = {
            title = '伤害加成',
            lines = build_damage_bonus_lines(),
          },
          bonds = {
            title = '技能运行时',
            lines = build_skill_runtime_lines(),
          },
          treasures = {
            title = '经济与奖励',
            lines = build_economy_bonus_lines(),
          },
          pending = {
            title = '待处理轮次',
            lines = build_pending_overview_lines(),
          },
          progress = {
            title = '道统进境',
            lines = build_bond_progress_overview_lines(),
          },
        },
      }
    end

    return {
      title = '局内构筑总览',
      subtitle = string.format(
        '按 B 收起  按 TAB 查看属性  当前战斗时长 %s',
        os.date('!%M:%S', math.max(0, math.floor(STATE.runtime_elapsed or 0)))
      ),
      close_label = '关闭 B',
      sections = {
        summary = {
          title = '战况摘要',
          lines = build_overview_summary_lines(),
        },
        skills = {
          title = '攻击技能',
          lines = build_attack_skill_overview_lines(),
        },
        bonds = {
          title = '仙缘道统',
          lines = build_bond_overview_lines(),
        },
        treasures = {
          title = '宝物与进化',
          lines = build_treasure_and_mark_overview_lines(),
        },
        pending = {
          title = '待处理轮次',
          lines = build_pending_overview_lines(),
        },
        progress = {
          title = '道统进境',
          lines = build_bond_progress_overview_lines(),
        },
      },
    }
  end

  return {
    get_runtime_overview_model = get_runtime_overview_model,
  }
end

return M
