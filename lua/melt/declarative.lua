local utils = require("melt.utils")
local readers = require("melt.readers")

-- Forward declaration for DeclarativeConfig object
local DeclarativeConfig = {}
DeclarativeConfig.__index = DeclarativeConfig

--- Constructor for a new DeclarativeConfig object.
-- @return A new DeclarativeConfig object.
function DeclarativeConfig.new()
    local instance = { data = {} }
    setmetatable(instance, DeclarativeConfig)
    return instance
end

--- Retrieves a value from the configuration using a dot-separated key string.
-- @param key_string The key string (e.g., "database.host.port").
-- @return The value if found, otherwise nil.
function DeclarativeConfig:get(key_string)
    if type(key_string) ~= "string" or key_string == "" then
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
        local key_base, index_str = string.match(part, "^([^%[%]]+)%[([0-9]+)%]$")

        if key_base and index_str then -- Array access
            local index = tonumber(index_str)
            if type(current_value[key_base]) == "table" and index then
                current_value = current_value[key_base][index]
            else
                return nil -- Key_base is not a table, or index is invalid/missing
            end
        else               -- Regular key access
            if current_value[part] ~= nil then
                current_value = current_value[part]
            else
                return nil -- Key part not found
            end
        end
        if current_value == nil then -- Path became invalid
            break
        end
    end
    return current_value
end

--- Returns the entire merged configuration table.
-- @return The Lua table containing all merged configuration data.
function DeclarativeConfig:get_table()
    return self.data
end

-- Helper function to check if a file exists
local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Helper function to check if a directory exists
local function dir_exists(path)
    if not path then return false end

    -- Use test -d for POSIX-like systems
    -- The command returns 0 if the directory exists, and a non-zero value otherwise.
    local command = "test -d '" .. path .. "'"
    local status = os.execute(command)
    return status == 0 or status == true -- os.execute might return true on some systems for success
end

-- Helper function to try loading a file with different extensions
local function try_load_config_file(base_path, formats, errors, source_type_for_error)
    formats = formats or { "toml", "json", "yaml", "ini", "config" }
    errors = errors or {} -- Ensure errors table is always present
    source_type_for_error = source_type_for_error or "unknown_file_source"

    for _, format in ipairs(formats) do
        local filepath = base_path .. "." .. format
        if file_exists(filepath) then
            local data_to_merge, parse_error_msg

            if format == "json" then
                data_to_merge, parse_error_msg = readers.read_json_file(filepath)
            elseif format == "yaml" or format == "yml" then
                data_to_merge, parse_error_msg = readers.read_yaml_file(filepath)
            elseif format == "ini" then
                data_to_merge, parse_error_msg = readers.read_ini_file(filepath)
            elseif format == "config" then
                data_to_merge, parse_error_msg = readers.read_config_file(filepath)
            else -- Default to TOML (or any other format if "toml" is explicitly in formats)
                data_to_merge, parse_error_msg = readers.read_toml_file(filepath)
            end

            if parse_error_msg then
                table.insert(errors, {
                    message = "Failed to parse " .. filepath .. ": " .. parse_error_msg,
                    source  = source_type_for_error,
                    path    = filepath
                })
                data_to_merge = nil -- Ensure no data is merged on parse error
            end

            -- If data_to_merge is not nil here, it means it's valid (even if empty)
            -- If it's nil, it means either a parse error occurred (handled above)
            -- or the file was empty and parsed to nil (e.g. empty YAML) which is fine.
            -- The function should return the data (or nil) and the path.
            -- If a file was found and processed (even if it resulted in an error or nil data), return its path.
            return data_to_merge, filepath
        end
    end
    return nil, nil -- No file found with any of the extensions
end

-- Helper function to look for configuration files in a directory
local function try_load_config_from_dir(dir_path, file_names, formats, app_name, use_app_name_as_dir, errors,
                                        source_type_for_error)
    if not dir_exists(dir_path) then
        return nil, nil
    end

    local loaded_data = nil
    local loaded_path = nil
    errors = errors or {}

    -- Normalize file_names if not provided
    file_names = file_names or { "config", app_name }
    source_type_for_error = source_type_for_error or "unknown_dir_source" -- Default for safety

    -- First try with app_name as subdirectory if requested
    if use_app_name_as_dir and app_name then
        local app_dir = dir_path .. "/" .. app_name
        if dir_exists(app_dir) then
            for _, name in ipairs(file_names) do
                -- Pass source_type_for_error to try_load_config_file
                local data, path = try_load_config_file(app_dir .. "/" .. name, formats, errors, source_type_for_error)
                if data then -- Data is not nil, implies successful load or valid empty file
                    loaded_data = data
                    loaded_path = path
                    break
                elseif path then -- File was found and processed, but data is nil (due to parse error, already logged)
                    -- Potentially break or continue, current logic is to break on first file *processed*
                    -- To keep original behavior of breaking on first *attempted* file:
                    -- if path is not nil (meaning file existed and was attempted), break.
                    -- For now, let's break if a file was processed, error or not.
                    break
                end
            end
        end
    end

    -- If nothing found and not using app_name as dir or fallback to direct search
    if not loaded_data then
        for _, name in ipairs(file_names) do
            -- Pass source_type_for_error to try_load_config_file
            local data, path = try_load_config_file(dir_path .. "/" .. name, formats, errors, source_type_for_error)
            if data then
                loaded_data = data
                loaded_path = path
                break
            elseif path then -- File was found and processed, but data is nil (parse error)
                break        -- Break if file was processed, error or not
            end
        end

        -- Limited directory scanning fallback: only enabled for custom paths
        -- to prevent parsing unrelated configuration files in user/system directories
        if not loaded_data and source_type_for_error == "custom_dir_file" then
            local command = "ls -A -- '" .. dir_path .. "'"
            local handle = io.popen(command)

            if handle then
                for filename in handle:lines() do
                    if filename ~= "." and filename ~= ".." then
                        local filepath = dir_path .. "/" .. filename
                        if file_exists(filepath) then
                            local extension = filename:match("%.([^%.]+)$")
                            if extension then
                                local format_supported = false
                                for _, fmt in ipairs(formats) do
                                    if extension == fmt or (fmt == "yaml" and extension == "yml") or (fmt == "yml" and extension == "yaml") then
                                        format_supported = true
                                        break
                                    end
                                end

                                if format_supported then
                                    local data, parse_error_msg
                                    if extension == "json" then
                                        data, parse_error_msg = readers.read_json_file(filepath)
                                    elseif extension == "yaml" or extension == "yml" then
                                        data, parse_error_msg = readers.read_yaml_file(filepath)
                                    elseif extension == "ini" then
                                        data, parse_error_msg = readers.read_ini_file(filepath)
                                    elseif extension == "config" then
                                        data, parse_error_msg = readers.read_config_file(filepath)
                                    elseif extension == "toml" then
                                        data, parse_error_msg = readers.read_toml_file(filepath)
                                    end

                                    if parse_error_msg then
                                        table.insert(errors, {
                                            message = "Failed to parse " .. filepath .. ": " .. parse_error_msg,
                                            source  = source_type_for_error,
                                            path    = filepath
                                        })
                                        data = nil -- Ensure data is nil if error occurred
                                    end

                                    if data then -- Successfully parsed and data is not nil
                                        loaded_data = data
                                        loaded_path = filepath
                                        break -- Found a loadable file, break from filename loop
                                    elseif parse_error_msg then
                                        -- A file of a supported type was found, but it failed to parse.
                                        loaded_path = filepath -- Mark that we processed this path
                                        break
                                    end
                                    -- If data is nil and no parse_error_msg, it means reader returned (nil,nil)
                                    -- e.g. empty YAML/JSON. Treat as "not loaded" and continue search.
                                end
                            end
                        end
                    end
                    if loaded_data or loaded_path then -- Break outer loop if we've settled on a file (or a parse error for a file)
                        break
                    end
                end
                handle:close()
            else
                -- Error listing directory
                table.insert(errors, {
                    message = "Failed to list directory content: " .. dir_path,
                    source = source_type_for_error,
                    path = dir_path
                })
            end
        end
    end

    return loaded_data, loaded_path
end

-- Helper function to handle string, array or boolean location specifications
local function process_location_spec(location_spec, default_locations)
    if location_spec == nil then
        return default_locations
    elseif type(location_spec) == "boolean" then
        return location_spec and default_locations or {}
    elseif type(location_spec) == "string" then
        return { location_spec }
    elseif type(location_spec) == "table" then
        return location_spec
    else
        return {}
    end
end

--- Declarative configuration function
-- @param options Table with configuration options
-- @param env_provider Optional function to provide environment variables (for dependency injection)
-- @param arg_provider Optional function to provide command line arguments (for dependency injection)
-- @return DeclarativeConfig object, errors table
local function declare(options, env_provider, arg_provider)
    if type(options) ~= "table" then
        error("melt.declare() requires a table of options")
    end

    if not options.app_name or type(options.app_name) ~= "string" then
        error("melt.declare() requires an 'app_name' string option")
    end

    local config = DeclarativeConfig.new()
    local errors = {}

    -- Set up configuration parameters
    local formats = options.formats or { "toml", "json", "yaml", "ini", "config" }
    local config_locations = options.config_locations or {}
    local file_names = config_locations.file_names or { "config", options.app_name }
    local use_app_name_as_dir = config_locations.use_app_name_as_dir
    if use_app_name_as_dir == nil then use_app_name_as_dir = true end

    -- Default environment provider just uses os.getenv
    local get_env = env_provider
    if type(env_provider) == "function" then
        get_env = env_provider
    elseif type(env_provider) == "table" then
        -- We'll use this table directly in read_env_vars
        get_env = function(name)
            return env_provider[name]
        end
    else
        get_env = os.getenv
    end

    -- Default arg provider uses _G.arg
    local get_arg = arg_provider or function() return _G.arg end

    -- 1. Load defaults (lowest precedence)
    if options.defaults then
        if type(options.defaults) == "table" then
            config.data = utils.deep_merge(config.data, options.defaults)
        elseif type(options.defaults) == "string" then
            -- Load defaults from file path
            local base_defaults_path = options.defaults:gsub("%.%w+$", "") -- Remove extension if any
            local data, filepath = try_load_config_file(base_defaults_path, formats, errors, "defaults_file")
            if data then
                config.data = utils.deep_merge(config.data, data)
            elseif not filepath then -- Only add "Could not load" if file wasn't found by try_load_config_file
                table.insert(errors, {
                    message = "Defaults file not found: " .. options.defaults,
                    source = "defaults_file_not_found", -- Differentiate from parse error
                    path = options.defaults
                })
            end
        else
            -- options.defaults is present but not a table or string
            table.insert(errors, {
                message = "Invalid type for 'defaults'. Expected table or string path, got " ..
                    type(options.defaults) .. ".",
                source  = "options_validation",
                key     = "defaults"
            })
        end
    end

    -- 2. Load system-wide configuration
    local system_spec = config_locations.system
    if system_spec == nil then
        system_spec = false -- Treat nil as false to adhere to "default: false"
    end
    local system_locations = process_location_spec(
        system_spec,
        { "/etc/" .. options.app_name, "/etc" } -- Default paths if system_spec resolves to true
    )

    for _, location in ipairs(system_locations) do
        local data, path = try_load_config_from_dir(
            location,
            file_names,
            formats,
            options.app_name,
            use_app_name_as_dir,
            errors,
            "system_file" -- source_type_for_error
        )

        if data then
            config.data = utils.deep_merge(config.data, data)
        end
    end

    -- 3. Load user-specific configuration
    local home = get_env("HOME")
    if home then
        local user_locations = process_location_spec(
            config_locations.user,
            {
                home .. "/.config",
                home
            }
        )

        for _, location in ipairs(user_locations) do
            local data, path = try_load_config_from_dir(
                location,
                file_names,
                formats,
                options.app_name,
                use_app_name_as_dir,
                errors,
                "user_file" -- source_type_for_error
            )

            if data then
                config.data = utils.deep_merge(config.data, data)
            end
        end

        -- Also check for dotfile in home directory (e.g., ~/.appname.toml)
        local user_dotfile = home .. "/." .. options.app_name
        -- Source type could be "user_dot_file" for more specificity
        local user_data, user_filepath = try_load_config_file(user_dotfile, formats, errors, "user_file")
        if user_data then
            config.data = utils.deep_merge(config.data, user_data)
        end
        -- If user_data is nil due to parse error, it's already logged by try_load_config_file.
        -- No specific "file not found" for dotfile, as it's optional.
    end

    -- 4. Load project-specific configuration
    local project_locations = process_location_spec(
        config_locations.project,
        { "." }
    )

    for _, location in ipairs(project_locations) do
        local data, path = try_load_config_from_dir(
            location,
            file_names,
            formats,
            options.app_name,
            use_app_name_as_dir,
            errors,
            "project_file" -- source_type_for_error
        )

        if data then
            config.data = utils.deep_merge(config.data, data)
        end
    end

    -- 5. Load custom path configurations
    if config_locations.custom_paths and type(config_locations.custom_paths) == "table" then
        for _, path in ipairs(config_locations.custom_paths) do
            -- Check if it's a directory or a file path
            if dir_exists(path) then
                local data, loaded_path = try_load_config_from_dir(
                    path,
                    file_names,
                    formats,
                    options.app_name,
                    use_app_name_as_dir,
                    errors,
                    "custom_dir_file" -- source_type_for_error
                )

                if data then
                    config.data = utils.deep_merge(config.data, data)
                end
            else
                -- Treat as a file path, strip extension if present
                local base_path = path:gsub("%.%w+$", "")
                local data, loaded_filepath = try_load_config_file(base_path, formats, errors, "custom_file")

                if data then
                    config.data = utils.deep_merge(config.data, data)
                elseif not loaded_filepath then -- File not found by try_load_config_file
                    table.insert(errors, {
                        message = "Custom configuration file not found: " .. path,
                        source = "custom_file_not_found", -- Differentiate from parse error
                        path = path
                    })
                end
                -- If loaded_filepath is not nil but data is nil, it means a parse error occurred
                -- and it was already logged by try_load_config_file.
            end
        end
    end

    -- 6. Load environment variables (if enabled)
    local env_config = options.env
    if env_config ~= false then -- default to true if not specified
        local env_prefix
        local auto_parse_types = true
        local nested_separator = "__"

        if type(env_config) == "table" then
            -- Custom env configuration
            env_prefix = env_config.prefix
            if env_config.auto_parse_types ~= nil then
                auto_parse_types = env_config.auto_parse_types
            end
            if env_config.nested_separator then
                nested_separator = env_config.nested_separator
            end
        end

        -- Default prefix is uppercased app_name with underscore
        if not env_prefix then
            env_prefix = string.upper(options.app_name) .. "_"
        end

        -- Add environment variables using the env_provider directly
        local env_data
        if type(env_provider) == "table" then
            -- If env_provider is a table, use it directly
            env_data = readers.read_env_vars(env_prefix, auto_parse_types, nested_separator, env_provider)
        else
            -- Otherwise, use the get_env function
            env_data = readers.read_env_vars(env_prefix, auto_parse_types, nested_separator, get_env)
        end

        if env_data then
            config.data = utils.deep_merge(config.data, env_data)
        end
    end

    -- 7. Load command-line arguments (if enabled)
    local cmd_args_config = options.cmd_args
    if cmd_args_config ~= false then -- default to true if not specified
        if type(cmd_args_config) == "table" then
            -- User provided a pre-parsed table of CLI args
            local cmd_data = readers.read_cmdline_options(cmd_args_config)
            if cmd_data then
                config.data = utils.deep_merge(config.data, cmd_data)
            end
        elseif cmd_args_config == true then
            local arg_table = get_arg()
            if arg_table and type(arg_table) == "table" then
                -- Try to use the provided arg table
                local parsed_args = {}
                local current_key = nil

                -- Simple parser for args like --key=value or --key value or --flag
                for i, arg_value in ipairs(arg_table) do
                    if type(arg_value) == "string" and string.sub(arg_value, 1, 2) == "--" then
                        local key_value = string.sub(arg_value, 3)
                        local key, value = string.match(key_value, "([^=]+)=(.*)")

                        if key and value then
                            -- Handle --key=value format
                            parsed_args[key] = value
                            current_key = nil
                        else
                            -- Handle --key format (expecting value in next arg)
                            -- or just a flag (--flag)
                            current_key = key_value
                            parsed_args[key_value] = true -- Default to true for flags
                        end
                    elseif current_key then
                        -- This is a value for the previous --key
                        -- Overwrite the default true value
                        parsed_args[current_key] = arg_value
                        current_key = nil
                    end
                end

                if next(parsed_args) then
                    local cmd_data = readers.read_cmdline_options(parsed_args)
                    if cmd_data then
                        config.data = utils.deep_merge(config.data, cmd_data)
                    end
                end
            end
        end
    end

    return config, errors
end

-- Define the declarative module
local Declarative = {
    declare = declare
}

return Declarative
