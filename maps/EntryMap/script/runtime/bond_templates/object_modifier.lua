local M = {}

local function get_modifier_key(node_def)
  return node_def and tonumber(node_def.editor_modifier_id) or nil
end

function M.activate(ctx)
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
end

function M.deactivate(ctx)
  local modifier_key = ctx.node_handles.modifier_key or get_modifier_key(ctx.node_def)
  local hero = ctx.state and ctx.state.hero or nil
  if modifier_key and hero and hero.is_exist and hero:is_exist() and hero.remove_buffs_by_key then
    hero:remove_buffs_by_key(modifier_key)
  end
end

return M
