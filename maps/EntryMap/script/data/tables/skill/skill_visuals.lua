local CsvLoader = require 'data.csv_loader'

local M = {
  default_particle_key = 101175,
  visual_by_bond = {},
  visual_by_skill_id = {},
  bond_to_skill_id = {},
}

local function trim(v)
  return tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function to_num(v)
  local s = trim(v)
  if s == '' then
    return nil
  end
  return tonumber(s)
end

local function parse_enabled(v)
  local s = string.lower(trim(v))
  return s == '' or s == '1' or s == 'true'
end

for _, row in ipairs(CsvLoader.read_rows_optional('data_csv/skill_visuals.csv')) do
  if parse_enabled(row.enabled) then
    local skill_id = trim(row.skill_id)
    local bond_name = trim(row.bond_name)
    if bond_name ~= '' then
      local cfg = {
        projectile_key = to_num(row.projectile_key),
        particle_key = to_num(row.particle_key),
        icon_key = to_num(row.icon_key),
        line_particle_key = to_num(row.line_particle_key),
        template_ref = to_num(row.template_ref),
        projectile_speed = to_num(row.projectile_speed),
        projectile_time = to_num(row.projectile_time),
        target_distance = to_num(row.target_distance),
        projectile_line_distance = to_num(row.projectile_line_distance),
        projectile_angle_offset = to_num(row.projectile_angle_offset),
        projectile_motion_angle_offset = to_num(row.projectile_motion_angle_offset),
        trajectory_style = trim(row.trajectory_style),
        projectile_parabola_height = to_num(row.projectile_parabola_height),
        projectile_rotate_time = to_num(row.projectile_rotate_time),
        projectile_init_max_rotate_angle = to_num(row.projectile_init_max_rotate_angle),
        area_fx_base_radius = to_num(row.area_fx_base_radius),
        area_fx_scale_bias = to_num(row.area_fx_scale_bias),
        particle_scale_bias = to_num(row.particle_scale_bias),
        delivery_mode = trim(row.delivery_mode),
        motion_mode = trim(row.motion_mode),
        hit_fx_mode = trim(row.hit_fx_mode),
      }
      M.visual_by_bond[bond_name] = cfg
      if skill_id ~= '' and skill_id ~= '__字段说明__' then
        M.visual_by_skill_id[skill_id] = cfg
        M.bond_to_skill_id[bond_name] = skill_id
      end
    end
  end
end

function M.get_by_bond_name(bond_name)
  local bond = trim(bond_name)
  if bond == '' then
    return nil
  end
  local skill_id = M.bond_to_skill_id[bond]
  if skill_id and M.visual_by_skill_id[skill_id] then
    return M.visual_by_skill_id[skill_id]
  end
  return M.visual_by_bond[bond]
end

function M.get_by_skill_id(skill_id)
  return M.visual_by_skill_id[trim(skill_id)]
end

return M
