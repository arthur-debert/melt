-- Require individual reader modules
local json_reader = require("lua.melt.readers.json")
local yaml_reader = require("lua.melt.readers.yaml")
local toml_reader = require("lua.melt.readers.toml")
local env_reader = require("lua.melt.readers.env")
local ini_reader = require("lua.melt.readers.ini")
local config_reader = require("lua.melt.readers.config")
local cmdline_reader = require("lua.melt.readers.cmdline") -- Added cmdline reader

local readers = {}

-- Import specific reader functions
readers.read_json_file = json_reader.read_json_file
readers.read_yaml_file = yaml_reader.read_yaml_file
readers.read_toml_file = toml_reader.read_toml_file
readers.read_env_vars = env_reader.read_env_vars
readers.read_ini_file = ini_reader.read_ini_file
readers.read_config_file = config_reader.read_config_file
readers.read_cmdline_options = cmdline_reader.read_options -- Added cmdline reader function

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


return readers