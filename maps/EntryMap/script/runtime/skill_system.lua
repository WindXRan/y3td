local SkillSystem = {}

local skill_framework = require 'runtime.skill_framework'
local attack_skills = require 'runtime.attack_skills'
local generated_skills = require 'runtime.generated_skills'

SkillSystem.framework = skill_framework
SkillSystem.attack = attack_skills
SkillSystem.generated = generated_skills

SkillSystem.create_skill_instance = skill_framework.create_skill_instance
SkillSystem.apply_passive_effects = skill_framework.apply_passive_effects
SkillSystem.remove_passive_effects = skill_framework.remove_passive_effects
SkillSystem.tick = skill_framework.tick
SkillSystem.cast = skill_framework.cast

SkillSystem.sync_basic_attack_ability = attack_skills.sync_basic_attack_ability
SkillSystem.unlock_attack_skill = attack_skills.unlock_attack_skill
SkillSystem.show_attack_skill_loadout = attack_skills.show_attack_skill_loadout

SkillSystem.register_all = generated_skills.register_all
SkillSystem.load_defs = generated_skills.load_defs
SkillSystem.build_rows = generated_skills.build_rows
SkillSystem.get_skill_by_id = generated_skills.get_skill_by_id

return SkillSystem