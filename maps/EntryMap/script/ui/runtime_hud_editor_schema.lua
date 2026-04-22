local M = {}

M.top = {
  root_paths = {
    'top.top',
    'top',
  },
  gold_value_paths = {
    'top.top.金币.image_3.label_2',
    'top.top.layout_2.金币.image_3.label_2',
  },
  wood_value_paths = {
    'top.top.木材.image_3.label_2',
    'top.top.layout_2.木材.image_3.label_2',
  },
  kill_value_paths = {
    'top.top.人口.image_3.label_2',
    'top.top.杀敌数.image_3.label_2',
    'top.top.layout_2.杀敌数.image_3.label_2',
  },
}

M.utility = {
  hud_path = 'BattleUtilityHUD',
  setting_button_paths = {
    'top.top.layout_2.存档按钮',
    'top.top.存档按钮',
    'BattleUtilityHUD.setting_btn',
    'GameHUD.setting_btn',
  },
  exit_button_paths = {
    'BattleUtilityHUD.exit_btn',
    'GameHUD.exit_btn',
  },
  legacy_setting_button = 'GameHUD.setting_btn',
  legacy_setting_panel = 'GameHUD.setting_panel',
  legacy_exit_button = 'GameHUD.exit_btn',
}

M.bottom = {
  skill_slot_host_paths = {
    '技能栏.物品2',
    '技能栏.物品2_10',
    '技能栏.物品2_11',
    '技能栏.物品2_12',
    '技能栏.物品2_13',
    '技能栏.物品2_14',
    '技能栏.物品2_15',
    '技能栏.物品2_16',
    '技能栏.物品2_17',
    '技能栏.物品2_18',
    '技能栏.物品2_19',
    '技能栏.物品2_20',
  },
  backpack_slot_host_paths = {
    { 'layout_1.backpack.物品1', '物品栏.物品2' },
    { 'layout_1.backpack.物品2', '物品栏.物品2_10' },
    { 'layout_1.backpack.image_4_1_1', '物品栏.物品2_11' },
    { 'layout_1.backpack.image_4_1_1_1', '物品栏.物品2_12' },
    { 'layout_1.backpack.image_4_1', '物品栏.物品2_13' },
    { 'layout_1.backpack.image_4_1_2', '物品栏.物品2_14' },
  },
}

M.legacy = {
  gamehud_main = 'GameHUD.main',
  inventory_bar = 'GameHUD.main.inventory',
  skill_bar = 'GameHUD.main.skill_list',
  inventory_slot_root_paths = {
    'GameHUD.main.inventory.equip_slot_bg_1',
    'GameHUD.main.inventory.equip_slot_bg_2',
    'GameHUD.main.inventory.equip_slot_bg_3',
    'GameHUD.main.inventory.equip_slot_bg_4',
    'GameHUD.main.inventory.equip_slot_bg_5',
    'GameHUD.main.inventory.equip_slot_bg_6',
  },
  inventory_slot_paths = {
    'GameHUD.main.inventory.equip_slot_bg_1.equip_slot_1',
    'GameHUD.main.inventory.equip_slot_bg_2.equip_slot_1',
    'GameHUD.main.inventory.equip_slot_bg_3.equip_slot_1',
    'GameHUD.main.inventory.equip_slot_bg_4.equip_slot_1',
    'GameHUD.main.inventory.equip_slot_bg_5.equip_slot_1',
    'GameHUD.main.inventory.equip_slot_bg_6.equip_slot_1',
  },
  skill_button_root_paths = {
    'GameHUD.main.skill_list.skill_btn_1',
    'GameHUD.main.skill_list.skill_btn_2',
    'GameHUD.main.skill_list.skill_btn_3',
    'GameHUD.main.skill_list.skill_btn_4',
    'GameHUD.main.skill_list.skill_btn_5',
    'GameHUD.main.skill_list.skill_btn_6',
    'GameHUD.main.skill_list.skill_btn_7',
    'GameHUD.main.skill_list.skill_btn_8',
  },
  hidden_paths = {
    'GameHUD.layout_3.main_hp_bar',
    'GameHUD.layout_3.hp_value',
    'GameHUD.layout_3.hp_recover',
    'GameHUD.layout_3.exp',
    'GameHUD.layout_3.zuobian',
    'GameHUD.layout_3.inventory',
    'GameHUD.jiban_list',
    'GameHUD.main.main_unit',
    'GameHUD.main.item',
    'GameHUD.main.attr_list',
    'GameHUD.main.main_unit_name',
    'GameHUD.main.bag_btn',
    'GameHUD.main.main_hp_bar',
    'GameHUD.main.main_mp_bar',
    'GameHUD.main.tips_node',
    'GameHUD.player_attr_list',
    'GameHUD.hero_list',
    'GameHUD.game_time',
    'GameHUD.bag',
    'GameHUD.store',
  },
}

return M
