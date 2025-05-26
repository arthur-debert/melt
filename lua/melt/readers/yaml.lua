-- Attempt to load yaml library, handle if not found
local yaml_status, yaml = pcall(require, 'lyaml')

local yaml_reader = {}

--- Reads a YAML file and returns its content as a Lua table.
-- @param filepath Path to the YAML file.
-- @return A Lua table with the YAML content, or an empty table on error.
function yaml_reader.read_yaml_file(filepath)
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
    -- lyaml.load returns the parsed YAML directly as a table
    local docs = yaml.load(content)
    return type(docs) == "table" and docs or {}
  end)
  if not ok then
    print("Error: Failed to parse YAML file " .. filepath .. ": " .. tostring(data))
    return {}
  end

  return data
end

return yaml_reader