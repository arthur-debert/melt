-- Environment variable reader for lua.melt

local env_reader = {}
local logger = require("lual").logger()

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
-- @param env_provider Optional function to provide environment variables (for dependency injection)
-- @return A Lua table representing the filtered and transformed environment variables.
function env_reader.read_env_vars(prefix, auto_parse_types, nested_separator, env_provider)
  local result = {}
  if type(prefix) ~= "string" or prefix == "" then
    logger.info("Warning: read_env_vars requires a non-empty string prefix.")
    return result
  end

  -- Set defaults if not provided
  if auto_parse_types == nil then auto_parse_types = true end
  if nested_separator == nil then nested_separator = "__" end

  -- 1. Direct table of environment variables
  if type(env_provider) == "table" then
    for name, value in pairs(env_provider) do
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
    return result
  end

  -- 2. Function provider
  local get_env = env_provider or os.getenv

  -- 3. Use _G.os.environ (available in some Lua environments)
  local env_table = _G.os and _G.os.environ
  if type(env_table) == "table" then
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
    return result
  end

  -- 4. We can't enumerate all environment variables in standard Lua
  -- but we logger.info a warning only if no environment provider was given
  if env_provider == nil then
    logger.info("Warning: Cannot directly access the full environment variable table.")
    logger.info("This reader might not find all prefixed variables.")
    logger.info("Consider pre-defining expected environment variable names if issues persist.")
  end

  return result
end

return env_reader
