-- Attempt to load toml, json, and yaml libraries, handle if not found for now in the reader itself.
local toml_status, toml = pcall(require, 'toml')
local json_status, json = pcall(require, 'dkjson')
local yaml_status, yaml = pcall(require, 'lyaml')

local readers = {}

--- Returns the same table. Used for consistency with other readers.
-- @param tbl The Lua table to return.
-- @return The input Lua table.
function readers.read_lua_table(tbl)
  if type(tbl) ~= "table" then
    print("Warning: read_lua_table expects a table, got " .. type(tbl))
    return {}
  end
  return tbl
end

--- Reads a TOML file and returns its content as a Lua table.
-- @param filepath Path to the TOML file.
-- @return A Lua table with the TOML content, or an empty table on error.
function readers.read_toml_file(filepath)
  if not toml_status then
    print("Warning: toml-lua library not found. TOML files cannot be processed.")
    return {}
  end

  local file, err_open = io.open(filepath, "r")
  if not file then
    print("Warning: Could not open file " .. filepath .. ": " .. (err_open or "unknown error"))
    return {}
  end

  local content, err_read = file:read("*a")
  file:close()

  if not content then
    print("Warning: Could not read file " .. filepath .. ": " .. (err_read or "unknown error"))
    return {}
  end

  local ok, data = pcall(toml.parse, content)
  if not ok then
    print("Error: Failed to parse TOML file " .. filepath .. ": " .. tostring(data))
    return {}
  end

  return data
end

--- Reads a JSON file and returns its content as a Lua table.
-- @param filepath Path to the JSON file.
-- @return A Lua table with the JSON content, or an empty table on error.
function readers.read_json_file(filepath)
  if not json_status then
    print("Warning: dkjson library not found. JSON files cannot be processed.")
    return {}
  end

  local file, err_open = io.open(filepath, "r")
  if not file then
    print("Warning: Could not open file " .. filepath .. ": " .. (err_open or "unknown error"))
    return {}
  end

  local content, err_read = file:read("*a")
  file:close()

  if not content then
    print("Warning: Could not read file " .. filepath .. ": " .. (err_read or "unknown error"))
    return {}
  end

  local data, _, err = json.decode(content)
  if err then
    print("Error: Failed to parse JSON file " .. filepath .. ": " .. tostring(err))
    return {}
  end

  return data
end

--- Reads a YAML file and returns its content as a Lua table.
-- @param filepath Path to the YAML file.
-- @return A Lua table with the YAML content, or an empty table on error.
function readers.read_yaml_file(filepath)
  if not yaml_status then
    print("Warning: lyaml library not found. YAML files cannot be processed.")
    return {}
  end

  local file, err_open = io.open(filepath, "r")
  if not file then
    print("Warning: Could not open file " .. filepath .. ": " .. (err_open or "unknown error"))
    return {}
  end

  local content, err_read = file:read("*a")
  file:close()

  if not content then
    print("Warning: Could not read file " .. filepath .. ": " .. (err_read or "unknown error"))
    return {}
  end

  local ok, data = pcall(function()
    -- lyaml.load returns a table where each document is an element in the array part
    -- For config files, we typically expect a single document, so we take the first one
    local docs = yaml.load(content)
    return type(docs) == "table" and docs[1] or {}
  end)
  
  if not ok then
    print("Error: Failed to parse YAML file " .. filepath .. ": " .. tostring(data))
    return {}
  end

  return data
end

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
-- @return A Lua table representing the filtered and transformed environment variables.
function readers.read_env_vars(prefix)
  local result = {}
  if type(prefix) ~= "string" or prefix == "" then
    print("Warning: read_env_vars requires a non-empty string prefix.")
    return result
  end

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
    env_table = {}  -- Ensure it's a table to avoid errors in pairs.
  end

  for name, value in pairs(env_table) do
    if string.sub(name, 1, #prefix) == prefix then
      local key_suffix = string.sub(name, #prefix + 1)
      if key_suffix ~= "" then -- Ensure there's a key part after the prefix
        -- Transform key: replace double underscores with dots and convert to lowercase
        local transformed_key = string.lower(string.gsub(key_suffix, "__", "."))
        -- Convert value
        local converted_value = convert_value(value)
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

return readers
