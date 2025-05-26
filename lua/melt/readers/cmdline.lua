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
    -- print("Warning: read_options expects a table as input.")
    return result
  end

  for key, value in pairs(options_table) do
    if type(key) == "string" then
      local lower_key = string.lower(key)
      -- Replace hyphens with dots to form the path string
      -- Example: "database-connection-timeout" becomes "database.connection.timeout"
      -- Example: "max_retries" becomes "max_retries" (no hyphens, direct key)
      local path_str = string.gsub(lower_key, "%-", ".")

      local converted_value = convert_value(value)
      set_nested_value(result, path_str, converted_value)
    end
  end

  return result
end

return cmdline_reader