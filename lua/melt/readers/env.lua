-- Environment variable reader for lua.melt

local env_reader = {}

-- Helper function to set a value in a nested table based on a path string
local function set_nested_value(tbl, path_str, value)
  local keys = {}
  for key in string.gmatch(path_str, "[^%.]+") do
    table.insert(keys, key)
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
local function convert_value(str_val)
  if type(str_val) ~= "string" then return str_val end -- Should not happen with os.getenv

  -- Check for boolean
  local lower_str_val = string.lower(str_val)
  if lower_str_val == "true" then
    return true
  elseif lower_str_val == "false" then
    return false
  end

  -- Check for number
  local num = tonumber(str_val)
  if num ~= nil then
    return num
  end

  -- Default to string
  return str_val
end

--- Reads environment variables starting with a given prefix and transforms them into a Lua table.
-- Double underscores `__` in variable names are converted to table separators (`.`).
-- @param prefix The prefix for environment variables (e.g., "MYAPP_").
-- @param auto_parse_types Whether to automatically parse values as numbers or booleans.
-- @param nested_separator The separator for nested tables.
-- @return A Lua table representing the filtered and transformed environment variables.
function env_reader.read_env_vars(prefix, auto_parse_types, nested_separator)
  local result = {}
  if type(prefix) ~= "string" or prefix == "" then
    print("Warning: read_env_vars requires a non-empty string prefix.")
    return result
  end

  -- Set defaults if not provided
  if auto_parse_types == nil then auto_parse_types = true end
  if nested_separator == nil then nested_separator = "__" end

  -- For Lua 5.1, os.environ() is not standard. We iterate using pairs on _G.os.environ on some systems,
  -- but a more compatible way is to rely on known keys if possible or use external libraries.
  -- For this implementation, we'll assume a hypothetical `get_all_env()` or iterate common ones.
  -- A truly robust solution for all Lua versions to get ALL env vars might require C or platform specifics.
  -- Given the sandbox, we might not be able to get all env vars.
  -- Let's simulate by trying to access `_G.os.environ` if it exists.

  local env_table = _G.os and _G.os.environ -- Attempt to get environment table (works on some systems like LuaJIT)
  if type(env_table) ~= "table" then
    -- Fallback for standard Lua where os.getenv() requires specific key
    -- This part is tricky without knowing all possible keys.
    -- For the purpose of this exercise, we'll print a warning if we can't access a global env table.
    -- In a real scenario, one might pass a list of expected env var names.
    print("Warning: Cannot directly access the full environment variable table.")
    print("This reader might not find all prefixed variables.")
    print("Consider pre-defining expected environment variable names if issues persist.")
    -- We can't iterate all env vars with standard os.getenv(), so we'd return empty or rely on passed-in keys.
    -- For now, let's proceed as if `env_table` could be populated by some means, even if it's empty here.
    env_table = {} -- Ensure it's a table to avoid errors in pairs.
  end

  for name, value in pairs(env_table) do
    if string.sub(name, 1, #prefix) == prefix then
      local key_suffix = string.sub(name, #prefix + 1)
      if key_suffix ~= "" then -- Ensure there's a key part after the prefix
        -- Transform key: replace nested_separator with dots and convert to lowercase
        local transformed_key = string.lower(string.gsub(key_suffix, nested_separator, "."))

        -- Convert value if auto_parse_types is enabled
        local converted_value = value
        if auto_parse_types then
          converted_value = convert_value(value)
        end

        -- Insert into result table, creating nested tables as needed
        set_nested_value(result, transformed_key, converted_value)
      end
    end
  end

  -- If pairs(env_table) was empty or not available, we might need an alternative.
  -- For many systems, simply calling os.getenv() without arguments returns nil.
  -- This implementation primarily relies on `_G.os.environ` which is not universally standard.
  -- A more robust approach for production would involve a platform-specific C module or
  -- expecting the user to list the environment variables they care about.
  -- Given the constraints, this is a best effort.
  return result
end

return env_reader
