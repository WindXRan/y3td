local config = {
  choice_count = 3,
  include_group_choices = true,
  weights = {
    node = 1,
    group = 1,
  },
}

function config.get_candidate_weight(candidate)
  if candidate and candidate.id and string.sub(candidate.id, 1, 8) == '__group_' then
    return config.weights.group or 1
  end
  return config.weights.node or 1
end

return config
