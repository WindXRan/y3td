local profiles = {
  default = {
    cast = { min_scale = 0.72, min_time = 0.14, socket = 'origin' },
    impact = { min_scale = 0.96, min_time = 0.22, height = 12 },
    burst = { min_scale = 1.08, min_time = 0.30, height = 0 },
    terminal = { min_scale = 1.08, min_time = 0.30, height = 0 },
    charge = { min_scale = 0.86, min_time = 0.20, height = 90 },
    chain = { min_scale = 0.82, min_time = 0.18, height = 0 },
    sustain = { min_scale = 0.82, min_time = 0.20, height = 0 },
    tick = { min_scale = 0.82, min_time = 0.20, height = 0 },
  },
  eca_projectile_hit = {
    cast = { min_scale = 0.76, min_time = 0.16, socket = 'origin' },
    impact = { min_scale = 1.00, min_time = 0.24, height = 18 },
    chain = { min_scale = 0.84, min_time = 0.20, height = 16 },
  },
  eca_xianxia_sword = {
    cast = { min_scale = 0.90, min_time = 0.14, socket = 'origin' },
    impact = { min_scale = 1.08, min_time = 0.28, height = 18 },
    chain = { min_scale = 0.92, min_time = 0.22, height = 16 },
  },
  eca_projectile_burst = {
    cast = { min_scale = 0.82, min_time = 0.18, socket = 'origin' },
    impact = { min_scale = 1.04, min_time = 0.26, height = 18 },
    burst = { min_scale = 1.18, min_time = 0.38, height = 10 },
  },
  eca_charge_strike = {
    charge = { min_scale = 0.88, min_time = 0.22, height = 160 },
    impact = { min_scale = 0.96, min_time = 0.20, height = 0 },
    burst = { min_scale = 1.04, min_time = 0.24, height = 0 },
    chain = { min_scale = 0.90, min_time = 0.20, height = 0 },
  },
  eca_line_pierce = {
    cast = { min_scale = 0.80, min_time = 0.16, socket = 'origin' },
    impact = { min_scale = 0.98, min_time = 0.22, height = 18 },
    chain = { min_scale = 0.86, min_time = 0.18, height = 12 },
  },
  eca_beam_tick = {
    cast = { min_scale = 0.90, min_time = 0.18, socket = 'origin' },
    sustain = { min_scale = 0.88, min_time = 0.20, height = 12 },
    tick = { min_scale = 0.88, min_time = 0.20, height = 12 },
    terminal = { min_scale = 1.08, min_time = 0.28, height = 0 },
  },
  eca_nova_burst = {
    cast = { min_scale = 0.86, min_time = 0.16, socket = 'origin' },
    burst = { min_scale = 1.14, min_time = 0.36, height = 0 },
    sustain = { min_scale = 0.94, min_time = 0.24, height = 0 },
    chain = { min_scale = 0.92, min_time = 0.22, height = 0 },
  },
  eca_chain_hit = {
    impact = { min_scale = 0.96, min_time = 0.20, height = 0 },
    burst = { min_scale = 1.00, min_time = 0.24, height = 0 },
    chain = { min_scale = 0.94, min_time = 0.20, height = 0 },
  },
  eca_ground_burst = {
    charge = { min_scale = 0.90, min_time = 0.20, height = 100 },
    impact = { min_scale = 1.02, min_time = 0.26, height = 0 },
    burst = { min_scale = 1.14, min_time = 0.36, height = 0 },
    sustain = { min_scale = 0.92, min_time = 0.22, height = 0 },
  },
  eca_moving_field = {
    charge = { min_scale = 0.84, min_time = 0.18, height = 0 },
    sustain = { min_scale = 0.90, min_time = 0.24, height = 0 },
    tick = { min_scale = 0.90, min_time = 0.24, height = 0 },
    burst = { min_scale = 1.02, min_time = 0.28, height = 0 },
  },
  eca_control_field = {
    charge = { min_scale = 0.86, min_time = 0.18, height = 80 },
    sustain = { min_scale = 0.92, min_time = 0.24, height = 0 },
    tick = { min_scale = 0.92, min_time = 0.24, height = 0 },
    burst = { min_scale = 1.04, min_time = 0.28, height = 0 },
    chain = { min_scale = 0.88, min_time = 0.20, height = 0 },
  },
  eca_charge_burst = {
    charge = { min_scale = 0.92, min_time = 0.24, height = 120 },
    impact = { min_scale = 1.06, min_time = 0.30, height = 0 },
    burst = { min_scale = 1.20, min_time = 0.42, height = 0 },
    sustain = { min_scale = 0.96, min_time = 0.24, height = 0 },
  },
  eca_persistent_field = {
    charge = { min_scale = 0.88, min_time = 0.18, height = 0 },
    sustain = { min_scale = 0.94, min_time = 0.24, height = 0 },
    tick = { min_scale = 0.94, min_time = 0.24, height = 0 },
    burst = { min_scale = 1.08, min_time = 0.30, height = 0 },
  },
  eca_return_blade = {
    cast = { min_scale = 0.78, min_time = 0.14, socket = 'origin' },
    impact = { min_scale = 0.94, min_time = 0.22, height = 16 },
    chain = { min_scale = 0.88, min_time = 0.18, height = 12 },
  },
  eca_seal_burst = {
    charge = { min_scale = 0.90, min_time = 0.22, height = 120 },
    impact = { min_scale = 1.04, min_time = 0.28, height = 0 },
    burst = { min_scale = 1.14, min_time = 0.34, height = 0 },
    sustain = { min_scale = 0.96, min_time = 0.22, height = 0 },
    chain = { min_scale = 0.88, min_time = 0.20, height = 0 },
  },
  eca_seeking_projectile = {
    cast = { min_scale = 0.74, min_time = 0.12, socket = 'origin' },
    impact = { min_scale = 0.94, min_time = 0.20, height = 12 },
    chain = { min_scale = 0.84, min_time = 0.16, height = 12 },
  },
}

return {
  by_id = profiles,
}
