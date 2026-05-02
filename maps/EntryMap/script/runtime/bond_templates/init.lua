local function noop() end

local EMPTY_TEMPLATE = {
  activate = noop,
  deactivate = noop,
}

local function get_modifier_key(node_def)
  return node_def and tonumber(node_def.editor_modifier_id) or nil
end

local templates = {
  static_attr = {
    activate = function(ctx)
      ctx.apply_static_pack(ctx.runtime, ctx.node_def.id, ctx.node_def)
    end,
    deactivate = function(ctx)
      ctx.clear_static_pack(ctx.runtime, ctx.node_def.id)
    end,
  },
  per_second_growth = {
    activate = function(ctx)
      ctx.apply_static_pack(ctx.runtime, ctx.node_def.id, ctx.node_def)
      ctx.node_state.tick_count = ctx.node_state.tick_count or 0
    end,
    deactivate = function(ctx)
      ctx.clear_static_pack(ctx.runtime, ctx.node_def.id)
    end,
  },
  kill_stack = {
    activate = function(ctx)
      ctx.apply_static_pack(ctx.runtime, ctx.node_def.id, ctx.node_def)
      ctx.node_state.kill_count = ctx.node_state.kill_count or 0
    end,
    deactivate = function(ctx)
      ctx.clear_static_pack(ctx.runtime, ctx.node_def.id)
    end,
  },
  basic_attack_modifier = {
    activate = function(ctx)
      ctx.apply_static_pack(ctx.runtime, ctx.node_def.id, ctx.node_def)
    end,
    deactivate = function(ctx)
      ctx.clear_static_pack(ctx.runtime, ctx.node_def.id)
    end,
  },
  object_modifier = {
    activate = function(ctx)
      local modifier_key = get_modifier_key(ctx.node_def)
      local hero = ctx.state and ctx.state.hero or nil
      if not modifier_key or not hero or not hero.is_exist or not hero:is_exist() or not hero.add_buff then
        return
      end

      ctx.node_handles.modifier_key = modifier_key
      ctx.node_handles.buff = hero:add_buff({
        key = modifier_key,
        source = hero,
        time = -1,
        stacks = 1,
      })
    end,
    deactivate = function(ctx)
      local modifier_key = ctx.node_handles.modifier_key or get_modifier_key(ctx.node_def)
      local hero = ctx.state and ctx.state.hero or nil
      if modifier_key and hero and hero.is_exist and hero:is_exist() and hero.remove_buffs_by_key then
        hero:remove_buffs_by_key(modifier_key)
      end
    end,
  },
}

local M = {}

function M.get_template(template_name)
  return templates[template_name] or EMPTY_TEMPLATE
end

return M
