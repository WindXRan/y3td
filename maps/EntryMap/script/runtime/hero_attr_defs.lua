local HeroAttrSystem = require 'runtime.hero_attr_system'

if HeroAttrSystem and HeroAttrSystem.get_defs then
  return HeroAttrSystem.get_defs()
end

return {
  categories = {},
  aliases = {},
  list = {},
  by_name = {},
  default_values = {},
}
