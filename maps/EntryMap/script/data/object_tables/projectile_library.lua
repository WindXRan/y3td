return {
  by_id = {
    [201392001] = { id = 201392001, name = 'lib_phys_fast', ref = 134267104, particle = 104656, model = 103014, speed = 2200, time = 0.65, target_distance = 24 },
    [201392002] = { id = 201392002, name = 'lib_phys_mid', ref = 134267104, particle = 104656, model = 103014, speed = 1600, time = 0.90, target_distance = 34 },
    [201392003] = { id = 201392003, name = 'lib_phys_heavy', ref = 134267104, particle = 104656, model = 103014, speed = 1100, time = 1.20, target_distance = 48 },

    [201392011] = { id = 201392011, name = 'lib_fire_fast', ref = 134268883, particle = 102877, model = 103014, speed = 2100, time = 0.60, target_distance = 26 },
    [201392012] = { id = 201392012, name = 'lib_fire_mid', ref = 134268883, particle = 102877, model = 103014, speed = 1500, time = 0.92, target_distance = 36 },
    [201392013] = { id = 201392013, name = 'lib_fire_heavy', ref = 134268883, particle = 102877, model = 103014, speed = 1050, time = 1.25, target_distance = 52 },

    [201392021] = { id = 201392021, name = 'lib_shadow_fast', ref = 134237871, particle = 104964, model = 103014, speed = 2050, time = 0.62, target_distance = 28 },
    [201392022] = { id = 201392022, name = 'lib_shadow_mid', ref = 134237871, particle = 104964, model = 103014, speed = 1480, time = 0.95, target_distance = 38 },
    [201392023] = { id = 201392023, name = 'lib_shadow_heavy', ref = 134237871, particle = 104964, model = 103014, speed = 980, time = 1.30, target_distance = 56 },

    [201392031] = { id = 201392031, name = 'lib_arcane_fast', ref = 134248973, particle = 102780, model = 103014, speed = 2150, time = 0.58, target_distance = 24 },
    [201392032] = { id = 201392032, name = 'lib_arcane_mid', ref = 134248973, particle = 102780, model = 103014, speed = 1520, time = 0.88, target_distance = 34 },
    [201392033] = { id = 201392033, name = 'lib_arcane_heavy', ref = 134248973, particle = 102780, model = 103014, speed = 1080, time = 1.18, target_distance = 46 },

    [201392041] = { id = 201392041, name = 'lib_lightning_fast', ref = 201390901, particle = 102780, model = 211057, speed = 2400, time = 0.55, target_distance = 22 },
    [201392042] = { id = 201392042, name = 'lib_lightning_mid', ref = 201390901, particle = 102780, model = 211057, speed = 1750, time = 0.82, target_distance = 30 },
    [201392043] = { id = 201392043, name = 'lib_lightning_heavy', ref = 201390901, particle = 102780, model = 211057, speed = 1250, time = 1.10, target_distance = 40 },

    [201392051] = { id = 201392051, name = 'lib_dragon_line', ref = 201390901, particle = 102780, model = 211057, speed = 1450, time = 1.00, target_distance = 48 },
    [201392052] = { id = 201392052, name = 'lib_dragon_burst', ref = 201390901, particle = 102877, model = 211057, speed = 1300, time = 1.05, target_distance = 52 },

    [201392061] = { id = 201392061, name = 'lib_universal_fast', ref = 134267104, particle = 101175, model = 103014, speed = 2000, time = 0.70, target_distance = 28 },
    [201392062] = { id = 201392062, name = 'lib_universal_mid', ref = 134267104, particle = 101175, model = 103014, speed = 1500, time = 0.95, target_distance = 40 },
    [201392063] = { id = 201392063, name = 'lib_universal_slow', ref = 134267104, particle = 101175, model = 103014, speed = 1000, time = 1.30, target_distance = 60 },
  },
  groups = {
    physical = {201392001, 201392002, 201392003},
    fire = {201392011, 201392012, 201392013},
    shadow = {201392021, 201392022, 201392023},
    arcane = {201392031, 201392032, 201392033},
    lightning = {201392041, 201392042, 201392043},
    dragon = {201392051, 201392052},
    universal = {201392061, 201392062, 201392063},
  },
}
