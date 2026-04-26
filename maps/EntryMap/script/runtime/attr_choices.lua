local M = {}

local CHOICE_COUNT = 3

local function round_number(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function add_pack(target, source)
  for attr_name, value in pairs(source or {}) do
    local number = tonumber(value) or 0
    if number ~= 0 then
      target[attr_name] = (target[attr_name] or 0) + number
    end
  end
  return target
end

local function copy_pack(source)
  local result = {}
  return add_pack(result, source)
end

local function format_pack(pack)
  local lines = {}
  local order = { '攻击', '生命', '护甲', '力量', '敏捷', '智力' }
  local used = {}
  for _, attr_name in ipairs(order) do
    local value = tonumber(pack and pack[attr_name] or 0) or 0
    if value ~= 0 then
      lines[#lines + 1] = string.format('%s +%d', attr_name, round_number(value))
      used[attr_name] = true
    end
  end
  for attr_name, value in pairs(pack or {}) do
    if not used[attr_name] and value ~= 0 then
      lines[#lines + 1] = string.format('%s +%d', tostring(attr_name), round_number(value))
    end
  end
  return table.concat(lines, '\n')
end

local function build_choices(level)
  local final_level = math.max(1, tonumber(level) or 1)
  local attack = 10 + final_level * 2
  local armor = 2 + math.floor(final_level / 3)
  local main_attr = 3 + math.floor(final_level / 4)

  local choices = {
    {
      id = 'attack',
      title_text = '攻击',
      subtitle_text = '攻击成长',
      attr_pack = { ['攻击'] = attack },
    },
    {
      id = 'armor',
      title_text = '护甲',
      subtitle_text = '护甲成长',
      attr_pack = { ['护甲'] = armor },
    },
    {
      id = 'main_attr',
      title_text = '全属性',
      subtitle_text = '全主属性',
      attr_pack = { ['力量'] = main_attr, ['敏捷'] = main_attr, ['智力'] = main_attr },
      body_text = string.format('全属性 +%d', main_attr),
    },
  }

  for index, choice in ipairs(choices) do
    choice.index = index
    choice.body_text = choice.body_text or format_pack(choice.attr_pack)
  end
  return choices
end

function M.create(env)
  local STATE = env.STATE
  local hero_attr_system = env.hero_attr_system
  local message = env.message or function() end

  local api = {}

  local function ensure_runtime()
    STATE.attr_choice_runtime = STATE.attr_choice_runtime or {
      awaiting_choice = false,
      current_choices = nil,
      current_round = nil,
      diamond_count = 0,
      next_round_id = 1,
      applied_packs = {},
    }
    local runtime = STATE.attr_choice_runtime
    runtime.diamond_count = runtime.diamond_count or 0
    runtime.next_round_id = runtime.next_round_id or 1
    runtime.applied_packs = runtime.applied_packs or {}
    return runtime
  end

  local function open_round(level)
    local runtime = ensure_runtime()
    runtime.awaiting_choice = true
    runtime.current_choices = build_choices(level)
    runtime.current_round = {
      round_id = runtime.next_round_id,
      level = math.max(1, tonumber(level) or 1),
      choice_count = CHOICE_COUNT,
    }
    runtime.next_round_id = runtime.next_round_id + 1
    return runtime
  end

  function api.ensure_runtime()
    return ensure_runtime()
  end

  function api.grant_diamond(count, level)
    local runtime = ensure_runtime()
    local add_count = math.max(1, math.floor(tonumber(count) or 1))
    runtime.diamond_count = (runtime.diamond_count or 0) + add_count
    runtime.last_grant_level = level
    message(string.format('获得属性钻石 x%d。', add_count))
    return runtime
  end

  function api.use_diamond()
    local runtime = ensure_runtime()
    if runtime.awaiting_choice == true then
      return false
    end
    if (runtime.diamond_count or 0) <= 0 then
      message('当前没有可使用的属性钻石。')
      return false
    end
    runtime.diamond_count = runtime.diamond_count - 1
    local level = STATE.hero_progress and STATE.hero_progress.level or runtime.last_grant_level or 1
    open_round(level)
    return true
  end

  function api.get_pending_choice_kind()
    local runtime = STATE and STATE.attr_choice_runtime or nil
    if runtime and runtime.awaiting_choice == true and runtime.current_choices and #runtime.current_choices > 0 then
      return 'attr'
    end
    return nil
  end

  function api.apply_choice(index)
    local runtime = ensure_runtime()
    if runtime.awaiting_choice ~= true or not runtime.current_choices then
      return false
    end

    local choice_index = math.max(1, math.floor(tonumber(index) or 1))
    local choice = runtime.current_choices[choice_index]
    if not choice then
      return false
    end

    local hero = STATE.hero
    if hero and hero.is_exist and hero:is_exist() then
      for attr_name, value in pairs(choice.attr_pack or {}) do
        if hero_attr_system and hero_attr_system.add_attr then
          hero_attr_system.add_attr(hero, attr_name, value)
        elseif hero.add_attr then
          hero:add_attr(attr_name, value)
        end
      end
      if hero_attr_system and hero_attr_system.rebuild_derived_attrs then
        hero_attr_system.rebuild_derived_attrs(hero)
      end
    end

    runtime.applied_packs[#runtime.applied_packs + 1] = copy_pack(choice.attr_pack)
    runtime.awaiting_choice = false
    runtime.current_choices = nil
    runtime.current_round = nil

    message(string.format('属性成长选择：%s。', tostring(choice.title_text or '属性')))

    return true
  end

  function api.has_pending_choice()
    return api.get_pending_choice_kind() == 'attr'
  end

  return api
end

return M
