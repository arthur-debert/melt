-- Attempt to load toml library, handle if not found
local toml_status, toml = pcall(require, 'toml')

local toml_reader = {}

--- Reads a TOML file and returns its content as a Lua table.
-- @param filepath Path to the TOML file.
-- @return A Lua table with the TOML content, or an empty table on error.
function toml_reader.read_toml_file(filepath)
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

return toml_reader