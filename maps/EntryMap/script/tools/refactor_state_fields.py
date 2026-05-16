#!/usr/bin/env python3
"""
STATE 字段重构工具 - 将扁平的 STATE 拆分为按系统边界划分的子表

映射规则:
- STATE.battle.* - 战斗核心状态
- STATE.subsystems.* - 子系统运行时实例  
- STATE.ui.* - UI 状态
- STATE.session.* - 会话状态
- STATE.debug.* - 调试/计数器
"""

import os
import re

# STATE 字段重命名映射
STATE_MAPPING = {
    # ========== 战斗状态 ==========
    'STATE.hero': 'STATE.battle.hero',
    'STATE.hero_common_attack': 'STATE.battle.hero_common_attack',
    'STATE.hero_spawn_point': 'STATE.battle.hero_spawn_point',
    'STATE.defense_point': 'STATE.battle.defense_point',
    'STATE.all_enemies': 'STATE.battle.all_enemies',
    'STATE.total_enemy_alive': 'STATE.battle.total_enemy_alive',
    'STATE.total_kills': 'STATE.battle.total_kills',
    'STATE.current_wave_index': 'STATE.battle.current_wave_index',
    'STATE.started_wave_count': 'STATE.battle.started_wave_count',
    'STATE.active_wave': 'STATE.battle.active_wave',
    'STATE.active_challenges': 'STATE.battle.active_challenges',
    'STATE.resources': 'STATE.battle.resources',
    'STATE.resource_income_elapsed': 'STATE.battle.resource_income_elapsed',
    'STATE.challenge_charges': 'STATE.battle.challenge_charges',
    'STATE.challenge_recover_elapsed': 'STATE.battle.challenge_recover_elapsed',
    'STATE.bond_draw_count': 'STATE.battle.bond_draw_count',
    'STATE.defeated_boss_waves': 'STATE.battle.defeated_boss_waves',
    'STATE.basic_attack_ability_bound': 'STATE.battle.basic_attack_ability_bound',
    'STATE.basic_attack_ability_warned': 'STATE.battle.basic_attack_ability_warned',
    
    # ========== 子系统运行时 ==========
    'STATE.bond_runtime': 'STATE.subsystems.bond',
    'STATE.battle_event_feed': 'STATE.subsystems.battle_event_feed',
    'STATE.effect_debug_runtime': 'STATE.subsystems.effect_debug',
    'STATE.evolution_runtime': 'STATE.subsystems.evolution',
    'STATE.auto_active_effects': 'STATE.subsystems.auto_active_effects',
    'STATE.enemy_info_map': 'STATE.subsystems.enemy_info_map',
    'STATE.hero_progress': 'STATE.subsystems.hero_progress',
    'STATE.skill_runtime': 'STATE.subsystems.skill',
    'STATE.attack_skill_state': 'STATE.subsystems.attack_skill',
    'STATE.reward_queue': 'STATE.subsystems.reward_queue',
    'STATE.hero_attr_runtime': 'STATE.subsystems.hero_attr',
    'STATE.attr_choice_runtime': 'STATE.subsystems.attr_choice',
    
    # ========== UI 状态 ==========
    'STATE.runtime_hud': 'STATE.ui.hud',
    'STATE.choice_panel': 'STATE.ui.choice_panel',
    'STATE.choice_panel_hidden': 'STATE.ui.choice_panel_hidden',
    'STATE.runtime_overview': 'STATE.ui.overview',
    'STATE.runtime_overview_mode': 'STATE.ui.overview_mode',
    'STATE.runtime_attr_tab_panel': 'STATE.ui.attr_tab_panel',
    'STATE.runtime_attr_tab_selected': 'STATE.ui.attr_tab_selected',
    'STATE.gm_ui': 'STATE.ui.gm',
    'STATE.outgame_ui': 'STATE.ui.outgame',
    
    # ========== 会话状态 ==========
    'STATE.session_phase': 'STATE.session.phase',
    'STATE.outgame_profile': 'STATE.session.outgame_profile',
    'STATE.outgame_profile_save_enabled': 'STATE.session.outgame_profile_save_enabled',
    'STATE.outgame_profile_save_warned': 'STATE.session.outgame_profile_save_warned',
    'STATE.selected_stage_id': 'STATE.session.selected_stage_id',
    'STATE.selected_mode_id': 'STATE.session.selected_mode_id',
    'STATE.current_stage_def': 'STATE.session.current_stage_def',
    'STATE.current_mode_def': 'STATE.session.current_mode_def',
    'STATE.last_battle_result': 'STATE.session.last_battle_result',
    'STATE.game_finished': 'STATE.session.game_finished',
    
    # ========== 调试/计数 ==========
    'STATE.debug_ctrl_down_count': 'STATE.debug.ctrl_down_count',
    'STATE.runtime_elapsed': 'STATE.debug.runtime_elapsed',
}

def process_file(filepath):
    """处理单个文件，替换 STATE 字段引用"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    changes = 0
    
    # 按长度降序排序，确保长匹配优先
    for old, new in sorted(STATE_MAPPING.items(), key=lambda x: -len(x[0])):
        if old in content:
            content = content.replace(old, new)
            changes += content.count(new)
    
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✓ {filepath}: {changes} 处替换")
    
    return changes

def main():
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"处理目录: {script_dir}")
    
    total_changes = 0
    lua_files = []
    
    # 收集所有 Lua 文件
    for root, dirs, files in os.walk(script_dir):
        # 排除 tools 目录和其他不需要处理的目录
        if 'tools' in root or 'data_csv' in root:
            continue
        
        for filename in files:
            if filename.endswith('.lua'):
                lua_files.append(os.path.join(root, filename))
    
    print(f"找到 {len(lua_files)} 个 Lua 文件")
    
    # 处理每个文件
    for filepath in lua_files:
        changes = process_file(filepath)
        total_changes += changes
    
    print(f"\n总计: {total_changes} 处 STATE 字段引用已更新")

if __name__ == '__main__':
    main()
