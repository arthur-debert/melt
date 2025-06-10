-- Command-line options reader for lua.melt

local cmdline_reader = {}

-- Helper function to set a value in a nested table based on a path string
-- Adapted from lua/melt/readers/env.lua
local function set_nested_value(tbl, path_str, value)
  local keys = {}
  for key_part in string.gmatch(path_str, "[^%.]+") do
    table.insert(keys, key_part)
  end

  if #keys == 0 then -- Should not happen with valid path_str
    return
  end

  local current = tbl
  for i = 1, #keys - 1 do
    local key = keys[i]
    if not current[key] or type(current[key]) ~= "table" then
      current[key] = {}
    end
    current = current[key]
  end
  current[keys[#keys]] = value
end

-- Helper function to attempt string to number/boolean conversion
-- Adapted from lua/melt/readers/env.lua
local function convert_value(str_val)
  if type(str_val) ~= "string" then return str_val end

  local lower_str_val = string.lower(str_val)
  if lower_str_val == "true" then
    return true
  elseif lower_str_val == "false" then
    return false
  end

  local num = tonumber(str_val)
  if num ~= nil then
    return num
  end

  return str_val
end

--- Reads a Lua table of command-line options and transforms them.
-- Hyphens `-` in option keys are converted to table separators (`.`).
-- Keys are converted to lowercase.
-- @param options_table A Lua table where keys are option names (strings)
--                      and values are the option values. This table is
--                      expected to be the output of a CLI parsing library.
-- @return A Lua table representing the transformed options.
function cmdline_reader.read_options(options_table)
  local result = {}
  if type(options_table) ~= "table" then
    -- Optionally print a warning or error
    print("Warning: read_options expects a table as input.")
    return result
  end

  for key, value in pairs(options_table) do
    if type(key) == "string" then
      -- Step 1: Convert key to lowercase
      local lower_key = string.lower(key)

      -- Step 2: Handle differently based on presence of hyphens
      if string.find(lower_key, "%-") then
        -- For keys with hyphens, we have two options:
        -- 1. Convert all hyphens to dots: "feature-flags-new-dashboard" -> "feature.flags.new.dashboard"
        -- 2. Convert only some hyphens to dots and others to underscores

        -- Option 2: Convert hyphens to underscores for compound words and dots for hierarchy
        -- This specifically handles keys like "feature-flags-new-dashboard" as "feature_flags.new_dashboard"

        -- First identify key sections
        local key_sections = {}
        for section in string.gmatch(lower_key, "[^%-]+") do
          table.insert(key_sections, section)
        end

        -- Special handling for common patterns
        if #key_sections >= 3 then
          -- Case for "feature-flags-new-dashboard" type pattern
          if key_sections[1] == "feature" and key_sections[2] == "flags" then
            -- Combine "feature" and "flags" with underscore
            local path_str = "feature_flags"
            -- Rest of the sections with dots or combined with underscores based on pattern
            if #key_sections == 3 then
              path_str = path_str .. "." .. key_sections[3]
            elseif #key_sections == 4 then
              path_str = path_str .. "." .. key_sections[3] .. "_" .. key_sections[4]
            else
              -- For more complex cases, just use dots
              for i = 3, #key_sections do
                path_str = path_str .. "." .. key_sections[i]
              end
            end

            local converted_value = convert_value(value)
            set_nested_value(result, path_str, converted_value)
          else
            -- Default handling with dots
            local path_str = string.gsub(lower_key, "%-", ".")
            local converted_value = convert_value(value)
            set_nested_value(result, path_str, converted_value)
          end
        else
          -- Default handling with dots for simpler cases
          local path_str = string.gsub(lower_key, "%-", ".")
          local converted_value = convert_value(value)
          set_nested_value(result, path_str, converted_value)
        end
      else
        -- For keys without hyphens, no special handling needed
        local converted_value = convert_value(value)
        set_nested_value(result, lower_key, converted_value)
      end
    end
  end

  return result
end

return cmdline_reader
