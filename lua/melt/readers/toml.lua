-- Attempt to load toml library, handle if not found
local toml_status, toml = pcall(require, 'toml')

local toml_reader = {}

--- Reads a TOML file and returns its content as a Lua table.
-- @param filepath Path to the TOML file.
-- @return A Lua table with the TOML content, or an empty table on error.
function toml_reader.read_toml_file(filepath)
  if not toml_status then
    return nil, "toml-lua library not found"
  end

  local file, err_open = io.open(filepath, "r")
  if not file then
    return nil, "Could not open file " .. filepath .. ": " .. (err_open or "unknown error")
  end

  local content, err_read = file:read("*a")
  file:close()

  if not content then
    return nil, "Could not read file " .. filepath .. ": " .. (err_read or "unknown error")
  end

  local success, result = pcall(toml.parse, content) -- toml.parse can return (false, error_message)
  if not success then
    -- pcall itself failed or toml.parse indicated failure.
    -- result is the error message from toml.parse or from pcall.
    return nil, tostring(result)
  end
  -- Check if toml.parse returned data or if it implicitly returned nil on success (should not happen for toml.parse)
  -- Assuming toml.parse returns data on success. If it can return (true, nil) for valid empty toml, this is fine.
  return result, nil
end

return toml_reader