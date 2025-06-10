local utils = require("lua.melt.utils")
local readers = require("lua.melt.readers")

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

    -- Try to open as a directory
    local status = os.execute("cd " .. path .. " 2>/dev/null")
    return status == 0 or status == true
end

-- Helper function to try loading a file with different extensions
local function try_load_config_file(base_path, formats, errors)
    formats = formats or { "toml", "json", "yaml", "ini", "config" }
    errors = errors or {}

    for _, format in ipairs(formats) do
        local filepath = base_path .. "." .. format
        if file_exists(filepath) then
            local data_to_merge
            local success = true

            if format == "json" then
                data_to_merge = readers.read_json_file(filepath)
            elseif format == "yaml" or format == "yml" then
                data_to_merge = readers.read_yaml_file(filepath)
            elseif format == "ini" then
                data_to_merge = readers.read_ini_file(filepath)
            elseif format == "config" then
                data_to_merge = readers.read_config_file(filepath)
            else
                -- Default to TOML
                data_to_merge = readers.read_toml_file(filepath)
            end

            -- Check if data loading failed (empty table might indicate parsing error)
            if data_to_merge and next(data_to_merge) == nil then
                -- File exists but returned empty table - could be parse error or truly empty file
                -- We'll accept this as valid (empty config is valid)
            end

            return data_to_merge, filepath
        end
    end
    return nil, nil
end

-- Helper function to look for configuration files in a directory
local function try_load_config_from_dir(dir_path, file_names, formats, app_name, use_app_name_as_dir, errors)
    if not dir_exists(dir_path) then
        return nil, nil
    end

    local loaded_data = nil
    local loaded_path = nil
    errors = errors or {}

    -- Normalize file_names if not provided
    file_names = file_names or { "config", app_name }

    -- First try with app_name as subdirectory if requested
    if use_app_name_as_dir and app_name then
        local app_dir = dir_path .. "/" .. app_name
        if dir_exists(app_dir) then
            for _, name in ipairs(file_names) do
                local data, path = try_load_config_file(app_dir .. "/" .. name, formats, errors)
                if data then
                    loaded_data = data
                    loaded_path = path
                    break
                end
            end
        end
    end

    -- If nothing found and not using app_name as dir or fallback to direct search
    if not loaded_data then
        for _, name in ipairs(file_names) do
            local data, path = try_load_config_file(dir_path .. "/" .. name, formats, errors)
            if data then
                loaded_data = data
                loaded_path = path
                break
            end
        end

        -- If still not found, check all files in the directory with supported extensions
        if not loaded_data then
            local command = "ls -1 " .. dir_path .. "/*.*"
            local handle = io.popen(command)
            if handle then
                local result = handle:read("*a")
                handle:close()

                for filepath in result:gmatch("[^\r\n]+") do
                    local extension = filepath:match("%.([^%.]+)$")
                    if extension then
                        -- Check if extension is in the formats list
                        local format_supported = false
                        for _, fmt in ipairs(formats) do
                            if extension == fmt then
                                format_supported = true
                                break
                            end
                        end

                        if format_supported then
                            local data = nil
                            if extension == "json" then
                                data = readers.read_json_file(filepath)
                            elseif extension == "yaml" or extension == "yml" then
                                data = readers.read_yaml_file(filepath)
                            elseif extension == "ini" then
                                data = readers.read_ini_file(filepath)
                            elseif extension == "config" then
                                data = readers.read_config_file(filepath)
                            elseif extension == "toml" then
                                data = readers.read_toml_file(filepath)
                            end

                            if data then
                                loaded_data = data
                                loaded_path = filepath
                                break
                            end
                        end
                    end
                end
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
            local data, filepath = try_load_config_file(options.defaults:gsub("%.%w+$", ""), formats, errors)
            if data then
                config.data = utils.deep_merge(config.data, data)
            else
                table.insert(errors, {
                    message = "Could not load defaults file: " .. options.defaults,
                    source = "defaults"
                })
            end
        end
    end

    -- 2. Load system-wide configuration
    local system_locations = process_location_spec(
        config_locations.system,
        { "/etc/" .. options.app_name, "/etc" }
    )

    for _, location in ipairs(system_locations) do
        local data, path = try_load_config_from_dir(
            location,
            file_names,
            formats,
            options.app_name,
            use_app_name_as_dir,
            errors
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
                errors
            )

            if data then
                config.data = utils.deep_merge(config.data, data)
            end
        end

        -- Also check for dotfile in home directory (e.g., ~/.appname.toml)
        local user_dotfile = home .. "/." .. options.app_name
        local user_data, user_filepath = try_load_config_file(user_dotfile, formats, errors)
        if user_data then
            config.data = utils.deep_merge(config.data, user_data)
        end
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
            errors
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
                    errors
                )

                if data then
                    config.data = utils.deep_merge(config.data, data)
                end
            else
                -- Treat as a file path, strip extension if present
                local base_path = path:gsub("%.%w+$", "")
                local data, loaded_path = try_load_config_file(base_path, formats, errors)

                if data then
                    config.data = utils.deep_merge(config.data, data)
                else
                    table.insert(errors, {
                        message = "Could not load custom configuration file: " .. path,
                        source = "custom_path",
                        path = path
                    })
                end
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
