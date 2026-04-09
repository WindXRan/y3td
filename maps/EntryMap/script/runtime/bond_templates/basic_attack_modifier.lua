local M = {}

function M.activate(ctx)
  ctx.apply_static_pack(ctx.runtime, ctx.node_def.id, ctx.node_def)
end

function M.deactivate(ctx)
  ctx.clear_static_pack(ctx.runtime, ctx.node_def.id)
end

return M
