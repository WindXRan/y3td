local ui_res = require 'ui.res'
local ChoicePanelConfig = require 'data.object_tables.choice_panel_config'
local BondTipModelBuilder = require 'runtime.bond_tip_model_builder'
local HeroRoster = require 'data.object_tables.hero_roster'
local HeroFormSkills = require 'data.object_tables.hero_form_skills'

local M = {}

local function get_choice_refresh_cost(paid_count)
  local index = math.max(0, tonumber(paid_count) or 0)
  return ChoicePanelConfig.refresh_costs[index] or ChoicePanelConfig.refresh_cost_default or 0
end

local function get_choice_badge_text(quality)
  return ChoicePanelConfig.badge_text_by_quality[quality or 'common'] or 'N'
end

local function get_bond_quality_text(quality)
  if quality == 'epic' then
    return '史诗'
  end
  if quality == 'rare' then
    return '稀有'
  end
  return '普通'
end

local function get_evolution_hero_entry(def)
  local unit_id = def and def.hero_unit_id or nil
  if unit_id == nil then
    return nil
  end
  return HeroRoster.by_unit_id[unit_id]
end

local function get_evolution_hero_skill(def)
  local entry = get_evolution_hero_entry(def)
  if not entry then
    return nil, nil
  end
  return HeroFormSkills.by_hero_id[entry.id], entry
end

local function get_evolution_title(def, index)
  local entry = get_evolution_hero_entry(def)
  if entry and entry.name and entry.name ~= '' then
    return entry.name
  end
  if def and def.name and def.name ~= '' then
    return def.name
  end
  return string.format('真身 %d', index)
end

local function get_evolution_subtitle(def)
  local _, entry = get_evolution_hero_skill(def)
  if entry and entry.title and entry.title ~= '' then
    return entry.title
  end
  return '英雄真身'
end

local function get_evolution_summary(def)
  local skill, entry = get_evolution_hero_skill(def)
  if skill and skill.summary and skill.summary ~= '' then
    return skill.summary
  end
  if entry and entry.summary and entry.summary ~= '' then
    return entry.summary
  end
  return def and def.summary or ''
end

local function get_choice_default_icon(kind, quality)
  if kind == 'upgrade' then
    return ui_res.hero_prefab.icon_1
  end
  if kind == 'bond' then
    return quality == 'epic' and ui_res.hero_prefab.panel_decor or ui_res.game_hud.unit_icon
  end
  return quality == 'epic' and ui_res.logo_panel.logo or ui_res.hero_prefab.icon_1
end

local function build_choice_text_blocks(...)
  local blocks = {}
  for _, block in ipairs({ ... }) do
    if block and block.text and block.text ~= '' then
      blocks[#blocks + 1] = block
    end
  end
  return blocks
end

local function sanitize_bond_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  if string.match(text, "^b'.*\\\\x") or string.match(text, '^b".*\\\\x') then
    return ''
  end
  return text
end

local function trim_inline_text(text)
  if type(text) ~= 'string' then
    return ''
  end
  local trimmed = text:gsub('\r', '')
  trimmed = trimmed:gsub('^%s+', '')
  trimmed = trimmed:gsub('%s+$', '')
  return trimmed
end

local function escape_lua_pattern(text)
  return tostring(text or ''):gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
end

local function build_display_title_candidates(...)
  local seen = {}
  local titles = {}
  for _, value in ipairs({ ... }) do
    local title = trim_inline_text(value)
    if title ~= '' and not seen[title] then
      seen[title] = true
      titles[#titles + 1] = title
    end
  end
  return titles
end

local function strip_repeated_display_title(text, title_candidates)
  local value = trim_inline_text(text)
  if value == '' then
    return value
  end

  for _, title in ipairs(title_candidates or {}) do
    local escaped_title = escape_lua_pattern(title)
    local stripped = value:gsub('^' .. escaped_title .. '%s*：%s*', '', 1)
    if stripped == value then
      stripped = value:gsub('^' .. escaped_title .. '%s*:%s*', '', 1)
    end
    if stripped ~= value then
      return trim_inline_text(stripped)
    end
  end

  return value
end

local function strip_choice_prefix(text)
  local trimmed = trim_inline_text(text)
  trimmed = trimmed:gsub('^当前：', '')
  trimmed = trimmed:gsub('^后继：', '')
  trimmed = trimmed:gsub('^进阶链路：', '')
  trimmed = trimmed:gsub('^终局方向：', '')
  trimmed = trimmed:gsub('^终阶节点：', '')
  return trim_inline_text(trimmed)
end

local function compact_line_text(text)
  local compact = strip_choice_prefix(sanitize_bond_text(text))
  compact = compact:gsub('\n', '')
  compact = compact:gsub('%s+', '')
  return trim_inline_text(compact)
end

local function split_non_empty_lines(text)
  local lines = {}
  local normalized = strip_choice_prefix(sanitize_bond_text(text))
  if normalized == '' then
    return lines
  end
  normalized = normalized:gsub('\r', '')
  for line in normalized:gmatch('[^\n]+') do
    local trimmed = trim_inline_text(line)
    if trimmed ~= '' then
      lines[#lines + 1] = trimmed
    end
  end
  return lines
end

local function split_compound_bonus_segments(text)
  local value = trim_inline_text(text)
  if value == '' then
    return {}
  end

  local normalized = value
  normalized = normalized:gsub('，', '\n')
  normalized = normalized:gsub(',', '\n')

  local segments = {}
  for segment in normalized:gmatch('[^\n]+') do
    local trimmed = trim_inline_text(segment)
    if trimmed ~= '' then
      segments[#segments + 1] = trimmed
    end
  end

  if #segments == 0 then
    segments[1] = value
  end
  return segments
end

local function split_title_progress(text)
  local raw = trim_inline_text(text)
  if raw == '' then
    return '', ''
  end
  local title, progress = raw:match('^(.-)%s*(%b())$')
  if title and progress then
    return trim_inline_text(title), trim_inline_text(progress)
  end
  return raw, ''
end

local function build_bonus_title_candidates(choice)
  local top_title_text = split_title_progress(choice and choice.title_text or '')
  return build_display_title_candidates(
    choice and choice.subtitle_text or '',
    choice and choice.display_name or '',
    top_title_text or ''
  )
end

local function build_bond_body_blocks(choice)
  if choice and choice.body_blocks and #choice.body_blocks > 0 then
    return choice.body_blocks
  end

  local value_text = sanitize_bond_text((choice and choice.value_text) or (choice and choice.current_text) or (choice and choice.desc_text) or '')
  local effect_title = sanitize_bond_text((choice and choice.effect_title) or '')
  local effect_text = sanitize_bond_text((choice and choice.effect_text) or '')
  local advanced_text = sanitize_bond_text((choice and choice.advanced_text) or '')

  return build_choice_text_blocks(
    value_text ~= '' and {
      kind = 'value',
      text = value_text,
      color = 'green',
    } or nil,
    advanced_text ~= '' and {
      kind = 'effect',
      text = advanced_text,
      color = 'dim',
    } or nil,
    effect_title ~= '' and {
      kind = 'effect_title',
      text = effect_title,
      color = 'gold',
    } or nil,
    effect_text ~= '' and {
      kind = 'effect',
      text = effect_text,
      color = 'dim',
    } or nil
  )
end

local function take_bonus_lines(choice)
  local lines = {}
  local title_candidates = build_bonus_title_candidates(choice)
  local source = split_non_empty_lines((choice and choice.value_text) or (choice and choice.current_text) or (choice and choice.desc_text) or '')
  for _, text in ipairs(source or {}) do
    if type(text) == 'string' and text ~= '' then
      local normalized_text = strip_repeated_display_title(text, title_candidates)
      for _, segment in ipairs(split_compound_bonus_segments(normalized_text)) do
        lines[#lines + 1] = segment
        if #lines >= 4 then
          break
        end
      end
    end
    if #lines >= 4 then
      break
    end
  end
  return lines
end

local function build_bond_card_labels(choice)
  local top_title_text, progress_text = split_title_progress(choice and choice.title_text or '')
  top_title_text = trim_inline_text(top_title_text)
  if top_title_text == '' then
    top_title_text = trim_inline_text((choice and choice.display_name) or '')
  end
  if top_title_text == '' then
    top_title_text = 'bond'
  end

  local item_title_text = trim_inline_text((choice and choice.subtitle_text) or '')
  local bonus_lines = take_bonus_lines(choice)
  if item_title_text == '' then
    item_title_text = top_title_text
  end

  return {
    top_title_text = top_title_text,
    item_title_text = item_title_text,
    progress_text = progress_text,
    bonus_lines = bonus_lines,
  }
end

local function parse_progress_total(progress_text)
  local _, total_text = trim_inline_text(progress_text):match('(%d+)%s*/%s*(%d+)')
  return tonumber(total_text)
end

local function get_bond_set_effect_title(progress_text)
  local total_count = parse_progress_total(progress_text)
  if total_count and total_count > 0 then
    return string.format('%d重真意', total_count)
  end
  return '道统真意'
end

local function take_set_body_lines(choice)
  local lines = split_non_empty_lines((choice and choice.effect_text) or '')
  local result = {}
  for _, text in ipairs(lines) do
    result[#result + 1] = text
    if #result >= 3 then
      break
    end
  end
  return result
end

local function build_bond_tip_model(choice, icon_res, name_text, badge_text)
  return BondTipModelBuilder.build_from_choice(choice, {
    icon_res = icon_res,
    quality_text = badge_text,
    item_name_text = name_text,
  })
end

local function join_non_empty_lines(lines, sep)
  local parts = {}
  for _, line in ipairs(lines or {}) do
    local value = trim_inline_text(line)
    if value ~= '' then
      parts[#parts + 1] = value
    end
  end
  return table.concat(parts, sep or '\n')
end

local function split_display_lines(text, max_count)
  local lines = {}
  local normalized = trim_inline_text(text)
  if normalized == '' then
    return lines
  end

  normalized = normalized:gsub('；', '\n')
  normalized = normalized:gsub('。', '。\n')
  normalized = normalized:gsub('\r', '')

  for line in normalized:gmatch('[^\n]+') do
    local value = trim_inline_text(line)
    if value ~= '' then
      lines[#lines + 1] = value
    end
    if max_count and #lines >= max_count then
      break
    end
  end

  return lines
end

local function append_display_lines(target, values, max_count)
  local result = target or {}
  for _, value in ipairs(values or {}) do
    local line = trim_inline_text(value)
    if line ~= '' then
      result[#result + 1] = line
    end
    if max_count and #result >= max_count then
      break
    end
  end
  return result
end

local function make_affix_line(title, body)
  local heading = trim_inline_text(title)
  local content = trim_inline_text(body)
  if heading == '' and content == '' then
    return nil
  end
  if heading == '' then
    heading = '说明'
  end
  return {
    title = heading,
    body = content,
  }
end

local function append_affix_line(target, title, body, max_count)
  local line = make_affix_line(title, body)
  if not line then
    return target
  end
  target[#target + 1] = line
  if max_count and #target > max_count then
    while #target > max_count do
      table.remove(target)
    end
  end
  return target
end

local function normalize_item_desc_line_entry(line, title_candidates)
  if type(line) == 'table' then
    local normalized = {}
    for key, value in pairs(line) do
      normalized[key] = value
    end

    if type(normalized.body) == 'string' then
      normalized.body = strip_repeated_display_title(normalized.body, title_candidates)
    end
    if type(normalized.desc) == 'string' then
      normalized.desc = strip_repeated_display_title(normalized.desc, title_candidates)
    end
    if normalized.body == nil and normalized.desc == nil and type(normalized.text) == 'string' then
      normalized.text = strip_repeated_display_title(normalized.text, title_candidates)
    end
    return normalized
  end

  if line == nil then
    return nil
  end

  return strip_repeated_display_title(tostring(line), title_candidates)
end

local function normalize_item_desc_lines(lines, title_candidates)
  local normalized = {}
  for index, line in ipairs(lines or {}) do
    normalized[index] = normalize_item_desc_line_entry(line, title_candidates)
  end
  return normalized
end

local function build_item_desc_payload(fields)
  local subtitle_parts = {}
  local subtitle_text = trim_inline_text(fields.subtitle_text or '')
  local extra_subtitle_text = trim_inline_text(fields.extra_subtitle_text or '')
  local title_text = trim_inline_text(fields.title_text or '')
  if subtitle_text ~= '' then
    subtitle_parts[#subtitle_parts + 1] = subtitle_text
  end
  if extra_subtitle_text ~= '' then
    subtitle_parts[#subtitle_parts + 1] = extra_subtitle_text
  end

  local display_title_candidates = build_display_title_candidates(
    title_text,
    fields.display_name,
    fields.item_name_text
  )

  return {
    title_text = title_text,
    subtitle_text = table.concat(subtitle_parts, ' '),
    cost_text = trim_inline_text(fields.cost_text or ''),
    icon_res = fields.icon_res,
    note_text = trim_inline_text(fields.note_text or ''),
    attr_lines = normalize_item_desc_lines(fields.attr_lines or {}, display_title_candidates),
    affix_lines = normalize_item_desc_lines(fields.affix_lines or {}, display_title_candidates),
  }
end

local function build_upgrade_item_desc_payload(upgrade, skill_def, is_unlock, icon_res)
  local attr_lines = {}
  local affix_lines = {}
  local function append_attr(text)
    if text and text ~= '' then
      attr_lines[#attr_lines + 1] = text
    end
  end

  if is_unlock then
    append_attr('卡牌类型：初始技能')
    append_attr('技能分类：' .. trim_inline_text(skill_def and skill_def.category or '未分类'))
    append_attr('定位：' .. trim_inline_text(skill_def and skill_def.archetype or '攻击技能'))
    append_attr('施法家族：' .. trim_inline_text(skill_def and skill_def.cast_family or '未定义'))
    append_attr('伤害标签：' .. trim_inline_text(skill_def and skill_def.damage_label or '未定义'))
    if skill_def and skill_def.base_damage_ratio and skill_def.base_damage_ratio > 0 then
      append_attr(string.format('伤害系数：%.0f%%攻击', skill_def.base_damage_ratio * 100))
    end
    if skill_def and skill_def.base_cooldown and skill_def.base_cooldown > 0 then
      append_attr(string.format('冷却时间：%.1f秒', skill_def.base_cooldown))
    end
    if skill_def and skill_def.base_range and skill_def.base_range > 0 then
      append_attr(string.format('施法范围：%d', math.floor(skill_def.base_range + 0.5)))
    end
    if skill_def and skill_def.base_pierce and skill_def.base_pierce > 0 then
      append_attr(string.format('穿透次数：%d', math.floor(skill_def.base_pierce + 0.5)))
    end
    if skill_def and skill_def.base_radius and skill_def.base_radius > 0 then
      append_attr(string.format('作用范围：%d', math.floor(skill_def.base_radius + 0.5)))
    end
    if skill_def and skill_def.base_duration and skill_def.base_duration > 0 then
      append_attr(string.format('持续时间：%.1f秒', skill_def.base_duration))
    end
    if skill_def and skill_def.base_bounce and skill_def.base_bounce > 0 then
      local bounce_title = '弹射次数'
      if skill_def.archetype == '追击飞剑攒射' then
        bounce_title = '飞剑数量'
      end
      append_attr(string.format('%s：%d', bounce_title, math.floor(skill_def.base_bounce + 0.5)))
    end
  else
    append_attr('卡牌类型：技能强化')
    if skill_def and skill_def.name then
      append_attr('作用技能：' .. trim_inline_text(skill_def.name))
    elseif upgrade and upgrade.name then
      append_attr('作用技能：' .. trim_inline_text(upgrade.name))
    end
  end
  append_affix_line(affix_lines, '技能说明', skill_def and skill_def.summary or '', 3)
  append_affix_line(affix_lines, is_unlock and '装配效果' or '强化效果', upgrade and upgrade.desc or '', 3)

  return build_item_desc_payload({
    title_text = is_unlock and (skill_def and skill_def.name or upgrade and upgrade.name or '') or (upgrade and upgrade.name or ''),
    subtitle_text = is_unlock and trim_inline_text(skill_def and skill_def.archetype or '初始技能') or (skill_def and skill_def.name or '技能强化'),
    cost_text = is_unlock and '初始技能' or '强化',
    icon_res = icon_res,
    attr_lines = attr_lines,
    affix_lines = affix_lines,
  })
end

local function build_bond_item_desc_payload(choice, card_labels, tip_model, icon_res)
  local affix_lines = {}

  append_affix_line(
    affix_lines,
    get_bond_set_effect_title(card_labels.progress_text),
    join_non_empty_lines(tip_model.set_body_lines or {}, '\n'),
    1
  )

  return build_item_desc_payload({
    title_text = card_labels.item_title_text,
    subtitle_text = card_labels.top_title_text,
    extra_subtitle_text = card_labels.progress_text,
    cost_text = get_bond_quality_text(choice and choice.quality),
    icon_res = icon_res,
    attr_lines = card_labels.bonus_lines,
    affix_lines = affix_lines,
  })
end

local function build_treasure_replace_item_desc_payload(slot, def, quality, quality_text, icon_res)
  local attr_lines = {}
  local affix_lines = {}

  append_display_lines(attr_lines, def and split_display_lines(def.notes or '', 2) or {}, 6)
  append_affix_line(affix_lines, '核心效果', def and def.summary or '', 3)
  append_affix_line(affix_lines, '替换说明', '点击后替换该宝物位。', 3)

  return build_item_desc_payload({
    title_text = string.format('宝物位 %d', slot),
    subtitle_text = def and def.name or '空位',
    cost_text = quality_text,
    icon_res = icon_res,
    attr_lines = attr_lines,
    affix_lines = affix_lines,
  })
end

local function build_treasure_item_desc_payload(def, active_count, quality_text, icon_res)
  local attr_lines = {}
  local affix_lines = {}

  append_display_lines(attr_lines, split_display_lines(def.notes or '', 2), 6)
  if def.treasure_type == 'tactical_temp' then
    attr_lines[#attr_lines + 1] = '临时宝物：不占用常驻宝物位'
  else
    attr_lines[#attr_lines + 1] = '常驻宝物：占用常驻宝物位'
  end
  if def.treasure_type ~= 'tactical_temp' and active_count >= 3 then
    attr_lines[#attr_lines + 1] = '当前 3 个宝物位已满'
  end
  append_affix_line(affix_lines, '核心效果', def.summary or '', 3)

  return build_item_desc_payload({
    title_text = def.name,
    subtitle_text = def.treasure_type == 'tactical_temp' and '临时宝物' or '常驻宝物',
    cost_text = quality_text,
    icon_res = icon_res,
    attr_lines = attr_lines,
    affix_lines = affix_lines,
  })
end

local function build_evolution_item_desc_payload(def, index, quality_text, icon_res)
  local skill, entry = get_evolution_hero_skill(def)
  local attr_lines = {}
  local affix_lines = {}

  if entry and entry.rarity and entry.rarity ~= '' then
    attr_lines[#attr_lines + 1] = '真身品阶：' .. trim_inline_text(entry.rarity)
  end
  if entry and entry.title and entry.title ~= '' then
    attr_lines[#attr_lines + 1] = '真身定位：' .. trim_inline_text(entry.title)
  end
  if skill and skill.subtitle and skill.subtitle ~= '' then
    attr_lines[#attr_lines + 1] = '神通类型：' .. trim_inline_text(skill.subtitle)
  end
  attr_lines[#attr_lines + 1] = '化形后保留等级、经验与已装配技能'

  append_affix_line(affix_lines, '真身简介', entry and entry.summary or '', 3)
  append_affix_line(
    affix_lines,
    skill and ('专属神通·' .. trim_inline_text(skill.name)) or '专属神通',
    (skill and skill.item_desc) or (skill and skill.summary) or '',
    3
  )
  append_affix_line(affix_lines, '进化加持', def and def.summary or '', 3)

  return build_item_desc_payload({
    title_text = get_evolution_title(def, index),
    subtitle_text = get_evolution_subtitle(def),
    extra_subtitle_text = skill and ('神通·' .. trim_inline_text(skill.name)) or '',
    cost_text = quality_text,
    icon_res = icon_res,
    note_text = '选中后立即替换英雄模型，并启用对应专属神通。',
    attr_lines = attr_lines,
    affix_lines = affix_lines,
  })
end

function M.create(env)
  local STATE = env.STATE
  local message = env.message
  local BondSystem = env.BondSystem
  local ATTACK_SKILL_DEFS = env.ATTACK_SKILL_DEFS
  local TREASURE_DEFS = env.TREASURE_DEFS
  local get_pending_round_choice_kind = env.get_pending_round_choice_kind
  local get_evolution_runtime = env.get_evolution_runtime or env.get_mark_runtime
  local get_evolution_quality_label = env.get_evolution_quality_label or env.get_mark_quality_label
  local get_treasure_runtime = env.get_treasure_runtime
  local get_treasure_quality_label = env.get_treasure_quality_label
  local get_treasure_active_count = env.get_treasure_active_count
  local pick_treasure_choices = env.pick_treasure_choices
  local create_bond_env = env.create_bond_env
  local refresh_upgrade_choices = env.refresh_upgrade_choices

  local function refresh_treasure_choices()
    local runtime = get_treasure_runtime()
    if runtime.awaiting_replace and runtime.pending_replace_choice then
      message('当前处于宝物替换阶段，不能刷新。')
      return false
    end

    if not runtime.awaiting_choice or not runtime.current_choices or not runtime.current_round then
      return false
    end

    local choices = pick_treasure_choices(3)
    if #choices == 0 then
      message('本局没有更多可刷新的宝物候选。')
      return false
    end

    local round = runtime.current_round
    if (round.free_refresh_left or 0) > 0 then
      round.free_refresh_left = round.free_refresh_left - 1
      message(string.format('已免费刷新宝物候选，剩余免费次数 %d。', round.free_refresh_left))
    else
      local cost = get_choice_refresh_cost(round.refresh_paid_count or 0)
      if (STATE.resources.wood or 0) < cost then
        message(string.format('木材不足，刷新宝物候选需要 %d 木材。', cost))
        return false
      end
      STATE.resources.wood = STATE.resources.wood - cost
      round.refresh_paid_count = (round.refresh_paid_count or 0) + 1
      message(string.format('已消耗 %d 木材刷新宝物候选。', cost))
    end

    runtime.current_choices = choices
    round.state = 'pending'
    round.selected_treasure_id = nil
    round.candidate_treasure_ids = {}
    for _, def in ipairs(choices) do
      round.candidate_treasure_ids[#round.candidate_treasure_ids + 1] = def.id
    end
    return true
  end

  local function build_upgrade_choice_cards()
    local cards = {}
    for index, upgrade in ipairs(STATE.current_upgrade_choices or {}) do
      local is_unlock = upgrade and type(upgrade.key) == 'string' and string.sub(upgrade.key, 1, 7) == 'unlock_'
      local skill_def = upgrade and ATTACK_SKILL_DEFS[upgrade.skill_id] or nil
      local quality = upgrade and upgrade.quality or (is_unlock and 'rare' or 'common')
      local icon_res = (upgrade and upgrade.ui_icon)
          or (skill_def and skill_def.ui_icon)
          or get_choice_default_icon('upgrade', quality)

      cards[#cards + 1] = {
        index = index,
        badge_text = get_choice_badge_text(quality),
        quality = quality,
        icon_res = icon_res,
        title_text = is_unlock and (skill_def and skill_def.name or upgrade.name) or (skill_def and skill_def.name) or (upgrade.tag or '强化'),
        progress_text = '',
        subtitle_text = is_unlock and trim_inline_text(skill_def and skill_def.archetype or '初始技能') or upgrade.name,
        use_item_desc_card = true,
        item_desc_payload = build_upgrade_item_desc_payload(upgrade, skill_def, is_unlock, icon_res),
        body_blocks = build_choice_text_blocks({
          text = upgrade.desc or '',
          color = is_unlock and 'blue' or 'green',
        }),
      }
    end
    return cards
  end

  local function build_bond_choice_cards()
    local runtime = STATE.bond_runtime
    local cards = {}
    for index, choice in ipairs(runtime and runtime.current_choices or {}) do
      local card_labels = build_bond_card_labels(choice)
      local badge_text = get_choice_badge_text(choice.quality)
      local icon_res = choice.ui_icon or get_choice_default_icon('bond', choice.quality)
      local tip_model = build_bond_tip_model(choice, icon_res, card_labels.item_title_text, badge_text)

      cards[#cards + 1] = {
        index = index,
        kind = 'bond',
        badge_text = badge_text,
        quality = choice.quality or 'rare',
        icon_res = icon_res,
        title_text = card_labels.item_title_text,
        set_title_text = card_labels.top_title_text,
        progress_text = card_labels.progress_text,
        subtitle_text = '',
        body_blocks = build_bond_body_blocks(choice),
        bonus_lines = card_labels.bonus_lines,
        effect_area_bonus_count = #card_labels.bonus_lines,
        tip_model = tip_model,
        use_item_desc_card = true,
        item_desc_payload = build_bond_item_desc_payload(choice, card_labels, tip_model, icon_res),
        title_color = choice.title_color,
        set_title_color = choice.set_title_color or choice.subtitle_color,
        subtitle_color = choice.subtitle_color,
        effect_color_mode = choice.effect_color_mode,
      }
    end
    return cards
  end

  local function build_treasure_choice_cards()
    local runtime = STATE.treasure_runtime
    local cards = {}
    if runtime and runtime.awaiting_replace and runtime.pending_replace_choice then
      for slot = 1, 3, 1 do
        local treasure_id = runtime.active_slots[slot]
        local def = treasure_id and TREASURE_DEFS[treasure_id] or nil
        local quality = def and def.quality or 'common'
        local quality_text = get_treasure_quality_label(quality)
        local icon_res = def and def.ui_icon or get_choice_default_icon('treasure', quality)

        cards[#cards + 1] = {
          index = slot,
          badge_text = get_choice_badge_text(quality),
          quality = quality,
          icon_res = icon_res,
          title_text = string.format('宝物位 %d', slot),
          progress_text = '',
          subtitle_text = def and def.name or '空位',
          use_item_desc_card = true,
          item_desc_payload = build_treasure_replace_item_desc_payload(slot, def, quality, quality_text, icon_res),
          body_blocks = build_choice_text_blocks(
            def and {
              text = def.summary or '',
              color = 'green',
            } or nil,
            {
              text = '点击后替换该宝物位。',
              color = 'gold',
            }
          ),
        }
      end
      return cards
    end

    for index, def in ipairs(runtime and runtime.current_choices or {}) do
      local quality_text = get_treasure_quality_label(def.quality)
      local icon_res = def.ui_icon or get_choice_default_icon('treasure', def.quality)

      cards[#cards + 1] = {
        index = index,
        badge_text = get_choice_badge_text(def.quality),
        quality = def.quality or 'common',
        icon_res = icon_res,
        title_text = def.name,
        progress_text = '',
        subtitle_text = def.treasure_type == 'tactical_temp' and '临时宝物' or get_treasure_quality_label(def.quality),
        use_item_desc_card = true,
        item_desc_payload = build_treasure_item_desc_payload(def, get_treasure_active_count(), quality_text, icon_res),
        body_blocks = build_choice_text_blocks(
          {
            text = def.summary or '',
            color = 'green',
          },
          def.treasure_type == 'tactical_temp' and {
            text = '不占用常驻宝物位。',
            color = 'gold',
          } or nil,
          def.treasure_type ~= 'tactical_temp' and get_treasure_active_count() >= 3 and {
            text = '满 3 个宝物位后，选中将进入替换阶段。',
            color = 'gold',
          } or nil
        ),
      }
    end
    return cards
  end

  local function build_evolution_choice_cards()
    local runtime = (get_evolution_runtime and get_evolution_runtime()) or STATE.evolution_runtime or STATE.mark_runtime
    local cards = {}
    for index, def in ipairs(runtime and runtime.current_choices or {}) do
      local quality = def and def.quality or 'common'
      local quality_text = get_evolution_quality_label and get_evolution_quality_label(quality) or ''
      local entry = get_evolution_hero_entry(def)
      local icon_res = def and def.ui_icon or get_choice_default_icon('mark', quality)
      cards[#cards + 1] = {
        index = index,
        kind = 'evolution',
        badge_text = entry and entry.rarity or get_choice_badge_text(quality),
        quality = quality,
        icon_res = icon_res,
        title_text = get_evolution_title(def, index),
        progress_text = '',
        subtitle_text = get_evolution_subtitle(def),
        use_item_desc_card = true,
        item_desc_payload = build_evolution_item_desc_payload(def, index, quality_text, icon_res),
        body_blocks = build_choice_text_blocks({
          text = get_evolution_summary(def),
          color = 'green',
        }),
      }
    end
    return cards
  end

  local function hide_current_choice_panel()
    if not get_pending_round_choice_kind() then
      return
    end
    STATE.choice_panel_hidden = true
  end

  local function refresh_current_choice_panel()
    local kind = get_pending_round_choice_kind()
    if kind == 'upgrade' then
      STATE.choice_panel_hidden = false
      return refresh_upgrade_choices()
    end
    if kind == 'bond' then
      STATE.choice_panel_hidden = false
      return BondSystem.refresh_choice(create_bond_env())
    end
    if kind == 'treasure' then
      STATE.choice_panel_hidden = false
      return refresh_treasure_choices()
    end
    message('当前选择不支持刷新。')
    return false
  end

  local function get_current_choice_panel_model()
    if STATE.choice_panel_hidden == true then
      return nil
    end

    local kind = get_pending_round_choice_kind()
    if kind == 'upgrade' then
      local round = STATE.current_upgrade_round or {
        free_refresh_left = 3,
        refresh_paid_count = 0,
      }
      return {
        kind = kind,
        hide_enabled = true,
        refresh = {
          visible = true,
          enabled = true,
          free_left = round.free_refresh_left or 0,
          wood_cost = get_choice_refresh_cost(round.refresh_paid_count or 0),
        },
        cards = build_upgrade_choice_cards(),
      }
    end

    if kind == 'bond' then
      local runtime = STATE.bond_runtime
      local round = runtime and (runtime.current_offer_round or runtime.current_round) or {
        free_refresh_left = 0,
        refresh_paid_count = 0,
      }
      return {
        kind = kind,
        card_renderer = 'default',
        hide_enabled = true,
        refresh = {
          visible = true,
          enabled = true,
          free_left = round.free_refresh_left or 0,
          wood_cost = get_choice_refresh_cost(round.refresh_paid_count or 0),
        },
        cards = build_bond_choice_cards(),
      }
    end

    if kind == 'evolution' or kind == 'mark' then
      local runtime = (get_evolution_runtime and get_evolution_runtime()) or STATE.evolution_runtime or STATE.mark_runtime
      local cards = build_evolution_choice_cards()
      local round = runtime and runtime.current_round or nil
      return {
        kind = 'evolution',
        panel_title = round and round.ui_title or '进化选择',
        hide_enabled = true,
        refresh = {
          visible = false,
          enabled = false,
          free_left = 0,
          wood_cost = 0,
        },
        cards = cards,
      }
    end

    if kind == 'treasure' then
      local runtime = STATE.treasure_runtime
      local round = runtime and (runtime.current_offer_round or runtime.current_round) or {
        free_refresh_left = 3,
        refresh_paid_count = 0,
      }
      local is_replace = runtime and runtime.awaiting_replace and runtime.pending_replace_choice
      return {
        kind = is_replace and 'treasure_replace' or 'treasure',
        hide_enabled = true,
        refresh = {
          visible = true,
          enabled = not is_replace,
          free_left = round.free_refresh_left or 0,
          wood_cost = get_choice_refresh_cost(round.refresh_paid_count or 0),
        },
        cards = build_treasure_choice_cards(),
      }
    end

    return nil
  end

  return {
    hide_current_choice_panel = hide_current_choice_panel,
    refresh_current_choice_panel = refresh_current_choice_panel,
    get_current_choice_panel_model = get_current_choice_panel_model,
  }
end

return M
