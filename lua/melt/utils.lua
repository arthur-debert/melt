local utils = {}

-- Helper function to create a shallow copy of a table
local function shallow_copy(original)
  local copy = {}
  for k, v in pairs(original) do
    copy[k] = v
  end
  return copy
end

function utils.deep_merge(target, source)
  local result = shallow_copy(target)

  for key, source_value in pairs(source) do
    local target_value = result[key]

    -- Heuristic: if source_value has a numeric key 1, assume it's array-like and should replace.
    -- Otherwise, if both are tables, deep merge.
    if type(source_value) == "table" and source_value[1] ~= nil and type(target_value) == "table" then
      result[key] = shallow_copy(source_value) -- Replace with a copy of the source array
    elseif type(source_value) == "table" and type(target_value) == "table" then
      result[key] = utils.deep_merge(target_value, source_value) -- Deep merge for map-like tables
    else
      -- Source overrides target for non-table values or if types don't match for merging,
      -- or if source is a table but target is not.
      if type(source_value) == "table" then
        result[key] = shallow_copy(source_value) -- Copy if it's a table being placed newly
      else
        result[key] = source_value
      end
    end
  end

  return result
end

return utils
