local utils = require("melt.utils")
local readers = require("melt.readers")
local logger = require("lual").logger()

-- Load declarative engine
local declarative_engine = require("melt.declarative")

-- Setup logging (Stage 3)
local logging = require("melt.logging")
logging.setup_logging()

-- Forward declaration for Config object
local Config = {}
Config.__index = Config

--- Constructor for a new Config object.
-- @return A new Config object.
function Config.new()
  local instance = { data = {} }
  setmetatable(instance, Config)
  return instance
end

--- Merges a Lua table into the current configuration.
-- @param source_table The Lua table to merge.
-- @return self (the Config object for chaining).
function Config:add_table(source_table)
  local data_to_merge = readers.read_lua_table(source_table)
  self.data = utils.deep_merge(self.data, data_to_merge)
  return self
end

--- Reads a configuration file and merges its content.
-- Supports TOML, JSON, YAML, INI, and CONFIG formats.
-- @param filepath Path to the configuration file.
-- @param type_hint (Optional) Type of the file, e.g., "toml", "json", "yaml", "ini", or "config".
-- @return self (the Config object for chaining).
function Config:add_file(filepath, type_hint)
  local data_to_merge
  -- Determine file type based on type_hint or file extension
  local file_type = type_hint
  if not file_type then
    -- Extract extension from filepath
    local extension = filepath:match("%.([^%.]+)$")
    if extension then
      file_type = extension:lower()
    end
  end
  -- Read file based on type
  local actual_data, parse_error_msg
  if file_type == "json" then
    actual_data, parse_error_msg = readers.read_json_file(filepath)
  elseif file_type == "yaml" or file_type == "yml" then
    actual_data, parse_error_msg = readers.read_yaml_file(filepath)
  elseif file_type == "ini" then
    actual_data, parse_error_msg = readers.read_ini_file(filepath)
  elseif file_type == "config" then
    actual_data, parse_error_msg = readers.read_config_file(filepath)
  else
    -- Default to TOML
    actual_data, parse_error_msg = readers.read_toml_file(filepath)
  end

  if parse_error_msg then
    -- Optional: logger.info warning, or allow API user to get last error
    logger.info("Warning: Failed to load file " .. filepath .. ": " .. parse_error_msg)
  elseif actual_data then
    self.data = utils.deep_merge(self.data, actual_data)
  end
  -- If actual_data is nil and no error, it means an empty file was parsed (e.g. empty YAML/JSON)
  -- In this case, we do nothing, which is fine.
  return self
end

--- Reads environment variables with a given prefix and merges them.
-- @param prefix The prefix for environment variables.
-- @return self (the Config object for chaining).
function Config:add_env(prefix)
  local data_to_merge = readers.read_env_vars(prefix)
  self.data = utils.deep_merge(self.data, data_to_merge)
  return self
end

--- Retrieves a value from the configuration using a dot-separated key string.
-- @param key_string The key string (e.g., "database.host.port").
-- @return The value if found, otherwise nil.
function Config:get(key_string)
  if type(key_string) ~= "string" then
    return nil
  end

  local current_value = self.data
  local key_parts = {}
  -- Split by '.' first, then process each part for potential array access
  for part in string.gmatch(key_string, "[^%.]+") do
    table.insert(key_parts, part)
  end

  for _, part in ipairs(key_parts) do
    if type(current_value) ~= "table" then
      return nil -- Cannot traverse further
    end

    -- Check for array access like "key[index]"
    -- Use key_base to avoid confusion with the loop variable 'key' if it were named 'key'
    local key_base, index_str = string.match(part, "^([^%[%]]+)%[([0-9]+)%]$")

    if key_base and index_str then -- Array access
      local index = tonumber(index_str)
      if type(current_value[key_base]) == "table" and index then
        current_value = current_value[key_base][index]
      else
        return nil -- Key_base is not a table, or index is invalid/missing
      end
    else           -- Regular key access
      if current_value[part] ~= nil then
        current_value = current_value[part]
      else
        return nil -- Key part not found
      end
    end
    if current_value == nil then -- Path became invalid (e.g. array index out of bounds made current_value nil)
      break
    end
  end
  return current_value
end

--- Returns the entire merged configuration table.
-- @return The Lua table containing all merged configuration data.
function Config:get_table()
  return self.data
end

-- Define the main module table
local Melt = {}

--- Creates a new Config object for chained configuration building.
-- @return A new Config object.
Melt.new = Config.new

--- Merges configurations from a list of sources.
-- This provides an iterative API for configuration loading.
-- @param sources_list A list of source definitions. Each source is a table,
-- e.g., { type = "file", path = "config.toml" }
-- e.g., { type = "table", source = { my_key = "my_value" } }
-- e.g., { type = "env", prefix = "APP_" }
-- @return A Config object containing the merged configuration.
function Melt.merge(sources_list)
  local config_obj = Config:new()

  if type(sources_list) ~= "table" then
    -- Or logger.info a warning, or error, depending on desired strictness
    return config_obj
  end

  for _, item in ipairs(sources_list) do
    if type(item) == "table" and item.type then
      if item.type == "table" or item.type == "defaults" then
        if type(item.source) == "table" then
          config_obj:add_table(item.source)
        else
          logger.warn("Warning: Source type 'table'/'defaults' expects a 'source' field with a table value.")
        end
      elseif item.type == "file" then
        if type(item.path) == "string" then
          -- item.file_type can be passed as the second argument to add_file
          config_obj:add_file(item.path, item.file_type)
        else
          logger.warn("Warning: Source type 'file' expects a 'path' field with a string value.")
        end
      elseif item.type == "env" then
        if type(item.prefix) == "string" then
          config_obj:add_env(item.prefix)
        else
          logger.warn("Warning: Source type 'env' expects a 'prefix' field with a string value.")
        end
      else
        logger.warn("Warning: Unknown source type: " .. tostring(item.type))
      end
    else
      logger.warn("Warning: Invalid item in sources_list. Each item should be a table with a 'type' field.")
    end
  end

  return config_obj
end

--- Declarative configuration function
-- @param options Table with configuration options
-- @return DeclarativeConfig object, errors table
Melt.declare = declarative_engine.declare

return Melt
