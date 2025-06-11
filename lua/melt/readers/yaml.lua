-- Attempt to load yaml library, handle if not found
local yaml_status, yaml = pcall(require, 'lyaml')

local yaml_reader = {}

--- Reads a YAML file and returns its content as a Lua table.
-- @param filepath Path to the YAML file.
-- @return A Lua table with the YAML content, or an empty table on error.
function yaml_reader.read_yaml_file(filepath)
  if not yaml_status then
    return nil, "lyaml library not found"
  end

  local file, err_open = io.open(filepath, "r")
  if not file then
    return nil, "Could not open file " .. filepath .. ": " .. (err_open or "unknown error")
  end

  local content, err_read = file:read("*a")
  file:close()

  if not content then
    -- This might indicate an empty file or a read error.
    -- lyaml might handle empty string as valid empty YAML, returning nil or empty table.
    -- If it was a read error, err_read would typically have a value.
    if err_read then
      return nil, "Could not read file " .. filepath .. ": " .. err_read
    else
      -- Assuming empty content is to be parsed, let pcall handle it.
      content = ""
    end
  end

  local success, result = pcall(yaml.load, content)

  if success then
    -- lyaml.load returns the parsed YAML. It can be a table, string, number, boolean.
    -- Or nil for empty input or input that is just "null".
    -- We expect a table for config. If it's not a table, we could treat it as an error or empty.
    -- For now, let's return what lyaml gives, assuming higher layers might expect non-tables
    -- or the declarative layer will handle merging.
    -- If result is nil (e.g. from empty file or "null"), return it as is (no error).
    return result, nil
  else
    -- pcall failed, result is the error message
    return nil, tostring(result)
  end
end

return yaml_reader