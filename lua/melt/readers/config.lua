-- Import the ini_config library
local ini_config = require("lua.melt.lib.ini_config")

local config_reader = {}

--- Reads a CONFIG file and returns its content as a Lua table.
-- @param filepath Path to the CONFIG file.
-- @return A Lua table with the CONFIG content, or an empty table on error.
function config_reader.read_config_file(filepath)
  local file, err_open = io.open(filepath, "r")
  if not file then
    print("Warning: Could not open file " .. filepath .. ": " .. (err_open or "unknown error"))
    return {}
  end
  file:close()
  -- Use the ini_config library to read the file
  local success, data_or_err = pcall(function()
    return ini_config.read(filepath)
  end)
  if not success then
    print("Error: Failed to parse CONFIG file " .. filepath .. ": " .. tostring(data_or_err))
    return {}
  end
  if not data_or_err then
    print("Error: Failed to parse CONFIG file " .. filepath .. ": unknown error")
    return {}
  end
  return data_or_err
end

return config_reader