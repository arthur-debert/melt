-- Import the ini_config library
local ini_config = require("melt.lib.ini_config")

local ini_reader = {}

--- Reads an INI file and returns its content as a Lua table.
-- @param filepath Path to the INI file.
-- @return A Lua table with the INI content, or an empty table on error.
function ini_reader.read_ini_file(filepath)
  local results = { pcall(ini_config.read, filepath) }
  local success = results[1]
  local data = results[2]
  local err_msg_from_lib = results[3] -- ini_config.read might return (nil, message)

  if success then
    if data then
      return data, nil
    else
      -- ini_config.read succeeded but returned nil data. Check if it provided an error message.
      if err_msg_from_lib then
        return nil, tostring(err_msg_from_lib)
      else
        -- This case could be a truly empty INI file that parses to nil by the lib,
        -- or file not found if the lib returns (nil, nil) for that.
        -- For robustness against (nil,nil) on file not found, let's check file existence
        -- if our library is silent.
        local file_exists_check = io.open(filepath, "r")
        if file_exists_check then
          file_exists_check:close()
          return nil,
              "INI parsing resulted in nil without specific error by library."           -- Or return {}, nil if nil is valid empty
        else
          return nil, "Could not open file " .. filepath .. ": No such file or directory"
        end
      end
    end
  else
    -- pcall failed, data here is the error message from pcall
    return nil, tostring(data)
  end
end

return ini_reader
