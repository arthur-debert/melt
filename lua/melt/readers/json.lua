-- Attempt to load json library, handle if not found
local json_status, json = pcall(require, 'dkjson')

local json_reader = {}

--- Reads a JSON file and returns its content as a Lua table.
-- @param filepath Path to the JSON file.
-- @return A Lua table with the JSON content, or an empty table on error.
function json_reader.read_json_file(filepath)
  if not json_status then
    -- This is a library availability issue, not a file parsing issue.
    -- Return nil and an error message, or handle as per project's error strategy.
    -- For now, let's make it consistent with parsing errors.
    return nil, "dkjson library not found"
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

  -- dkjson.decode returns: value, end_position, error_message_or_nil
  local ok, val, end_pos_or_err_msg, err_msg_from_decode = pcall(json.decode, content)

  if ok then
    -- pcall succeeded, now check if json.decode itself reported an error in its 3rd return val
    if err_msg_from_decode then
      return nil, tostring(err_msg_from_decode) -- Error reported by dkjson
    end
    -- If dkjson successfully parsed to nil (e.g. input was "null" or empty string)
    -- we treat this as a valid empty configuration.
    if val == nil then
      return {}, nil
    end
    return val, nil -- Successfully parsed data
  else
    -- pcall failed, val here is the error message from pcall
    return nil, tostring(val)
  end
end

return json_reader