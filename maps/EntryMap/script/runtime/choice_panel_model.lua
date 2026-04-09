local ui_res = require 'ui.res'

local M = {}

local CHOICE_BADGE_TEXT = {
  common = 'N',
  rare = 'R',
  epic = 'E',
  legendary = 'L',
}

local function get_choice_refresh_cost(paid_count)
  if (paid_count or 0) <= 0 then
    return 40
  end
  if paid_count == 1 then
    return 80
  end
  return 100
end

local function get_choice_badge_text(quality)
  return CHOICE_BADGE_TEXT[quality or 'common'] or 'N'
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

local function build_bond_body_blocks(choice)
  if choice and choice.body_blocks and #choice.body_blocks > 0 then
    return choice.body_blocks
  end

  return build_choice_text_blocks(
    {
      text = (choice and choice.value_text) or (choice and choice.current_text) or (choice and choice.desc_text) or '',
      color = 'green',
    },
    choice and choice.effect_text and {
      text = choice.effect_text,
      color = 'dim',
    } or nil
  )
end

function M.create(env)
  local STATE = env.STATE
  local message = env.message
  local BondSystem = env.BondSystem
  local ATTACK_SKILL_DEFS = env.ATTACK_SKILL_DEFS
  local TREASURE_DEFS = env.TREASURE_DEFS
  local get_pending_round_choice_kind = env.get_pending_round_choice_kind
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
      cards[#cards + 1] = {
        index = index,
        badge_text = is_unlock and 'N' or 'R',
        quality = is_unlock and 'rare' or 'common',
        icon_res = (upgrade and upgrade.ui_icon)
            or (skill_def and skill_def.ui_icon)
            or get_choice_default_icon('upgrade', is_unlock and 'rare' or 'common'),
        title_text = is_unlock and '新技能' or (skill_def and skill_def.name) or (upgrade.tag or '强化'),
        progress_text = '',
        subtitle_text = upgrade.name,
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
      local title_text = choice.display_name or choice.title_text or 'bond'
      local subtitle_text = choice.subtitle_text or ''
      if subtitle_text == title_text then
        subtitle_text = ''
      end

      cards[#cards + 1] = {
        index = index,
        badge_text = get_choice_badge_text(choice.quality),
        quality = choice.quality or 'rare',
        icon_res = choice.ui_icon or get_choice_default_icon('bond', choice.quality),
        title_text = choice.title_text or choice.display_name or '羁绊节点',
        progress_text = choice.progress_text or '',
        subtitle_text = choice.subtitle_text or '',
        title_text = title_text,
        subtitle_text = subtitle_text,
        body_blocks = build_bond_body_blocks(choice),
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
        cards[#cards + 1] = {
          index = slot,
          badge_text = get_choice_badge_text(def and def.quality or 'common'),
          quality = def and def.quality or 'common',
          icon_res = def and def.ui_icon or get_choice_default_icon('treasure', def and def.quality or 'common'),
          title_text = string.format('宝物位 %d', slot),
          progress_text = '',
          subtitle_text = def and def.name or '空位',
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
      cards[#cards + 1] = {
        index = index,
        badge_text = get_choice_badge_text(def.quality),
        quality = def.quality or 'common',
        icon_res = def.ui_icon or get_choice_default_icon('treasure', def.quality),
        title_text = def.name,
        progress_text = '',
        subtitle_text = def.treasure_type == 'tactical_temp' and '临时宝物' or get_treasure_quality_label(def.quality),
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
