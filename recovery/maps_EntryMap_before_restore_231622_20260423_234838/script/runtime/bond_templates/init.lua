local function noop() end

local EMPTY_TEMPLATE = {
  activate = noop,
  deactivate = noop,
}

local templates = {
  static_attr = require 'runtime.bond_templates.static_attr',
  per_second_growth = require 'runtime.bond_templates.per_second_growth',
  kill_stack = require 'runtime.bond_templates.kill_stack',
  basic_attack_modifier = require 'runtime.bond_templates.basic_attack_modifier',
}

local M = {}

function M.get_template(template_name)
  return templates[template_name] or EMPTY_TEMPLATE
end

return M
