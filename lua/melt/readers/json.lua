-- Attempt to load json library, handle if not found
local json_status, json = pcall(require, 'dkjson')

local json_reader = {}

--- Reads a JSON file and returns its content as a Lua table.
-- @param filepath Path to the JSON file.
-- @return A Lua table with the JSON content, or an empty table on error.
function json_reader.read_json_file(filepath)
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

return json_reader