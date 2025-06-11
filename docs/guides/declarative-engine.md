# User Guide: The Declarative Engine with `melt.declare()`

`lua.melt` offers a powerful declarative engine through the `melt.declare()` function. This approach simplifies configuration management by allowing you to specify high-level options, and `lua.melt` will then intelligently discover and merge configurations from various conventional sources. It's designed to reduce boilerplate and make common configuration patterns effortless.

## Why Use `melt.declare()`?

- **Simplicity**: Define your application's configuration needs with a single function call.
- **Convention over Configuration**: `lua.melt` automatically searches standard locations for configuration files based on your `app_name`.
- **Automatic Precedence**: A sensible and predictable order of precedence is applied automatically, ensuring that more specific configurations override general ones.
- **Reduced Boilerplate**: No need to manually add each configuration source if you follow common conventions.

## Getting Started: Basic Usage

The core of the declarative engine is the `melt.declare(options)` function. At a minimum, you need to provide an `app_name`:

```lua
local melt = require("lua.melt") -- Adjust require path if necessary

local config, errors = melt.declare({
  app_name = "MyAwesomeApp"
})

if errors and #errors > 0 then
  print("Configuration loading errors:")
  for _, err in ipairs(errors) do
    print("- " .. err.message .. (err.source and (" (Source: " .. err.source .. ")") or ""))
  end
end

-- Access your configuration
print("Setting from config:", config:get("some_setting"))
```

This simple call will:

1. Look for user-specific configuration files (e.g., `~/.config/MyAwesomeApp/config.toml`, `~/.MyAwesomeApp.json`).
2. Look for project-local configuration files (e.g., `./config.toml`, `./MyAwesomeApp.yaml`).
3. Load environment variables prefixed with `MYAWESOMEAPP_`.
4. Attempt to load command-line arguments (if `arg` table is available or a known convention is met).

## Understanding the `options` Table

The `options` table passed to `melt.declare()` allows you to customize its behavior:

### 1. `app_name` (string, **required**)

The name of your application (e.g., `"myapp"`, `"MyGreatTool"`). This is crucial for:

- Deriving default configuration file names (e.g., `myapp.toml`).
- Constructing paths to standard configuration directories (e.g., `~/.config/myapp/`).
- Generating default environment variable prefixes (e.g., `MYAPP_`).

### 2. `defaults` (table or string path, optional)

Provides the most basic default values for your application. This layer has the **lowest precedence**.

- **As a table**:

    ```lua
    defaults = {
      log_level = "info",
      timeout = 5000
    }
    ```

- **As a path string**:

    ```lua
    defaults = "/usr/share/myapp/default_config.json"
    ```
    If a value is provided for `defaults` but it is not a Lua table or a string path, an error will be reported in the `errors` table returned by `melt.declare()`.

### 3. `config_locations` (table, optional)

Controls how `lua.melt` discovers and loads file-based configurations.

- `system`: (boolean or string/array of strings, default: `false`)
  - If `true`, searches standard system-wide locations (e.g., `/etc/<app_name>/`, `/etc/`).
  - If a string or array, specifies exact system paths or directories to search.
- `user`: (boolean or string/array of strings, default: `true`)
  - If `true`, searches standard user-specific locations (e.g., `~/.config/<app_name>/`, `~/.<app_name>/`).
  - If a string or array, specifies exact user-specific paths or directories.
- `project`: (boolean or string/array of strings, default: `true`)
  - If `true`, searches the current working directory and potentially recognized project roots (e.g., `./`, `.config/`).
  - If a string or array, specifies exact project-relative paths or directories.
- `custom_paths`: (array of strings, optional)
    An explicit list of absolute or relative file paths or directories to also load configuration from. These are loaded after system, user, and project locations but before environment variables.

    ```lua
    custom_paths = {"/opt/custom_settings/my_app.toml", "./conf/extra.yaml"}
    ```

- `file_names`: (array of strings, optional, default: `["config", "<app_name>"]`)
    A list of base names (without extension) for configuration files to look for within the specified locations (e.g., `config.toml`, `myapp.json`).

    ```lua
    file_names = {"settings", "app_config", "myawesomeapp"}
    ```

- `use_app_name_as_dir`: (boolean, optional, default: `true`)
    If `true`, in standard locations like `~/.config/`, `lua.melt` will look for a subdirectory named `<app_name>` (e.g., `~/.config/myapp/config.toml`). If `false`, it will look for files directly in the parent location (e.g. `~/.config/myapp.toml`).

### 4. `formats` (array of strings, optional)

An array of file extensions (without the dot) representing the accepted configuration file formats.
Default: `["toml", "json", "yaml", "ini", "config"]`
`lua.melt` attempts to parse files with these extensions in the order provided within each directory.

### 5. `env` (boolean or table, optional)

Controls loading configuration from environment variables. Default: `true`.

- If `true`, enables environment variables, using a prefix derived from `app_name` (e.g., `MYAWESOMEAPP_`).
- If a table, allows customization:
  - `prefix`: (string, e.g., `"MY_CUSTOM_APP_"`) Specifies the exact prefix. If not given, defaults to `string.upper(app_name) .. "_"`.
  - `auto_parse_types`: (boolean, default: `true`) If `lua.melt` should attempt to convert environment variable strings to numbers or booleans.
  - `nested_separator`: (string, e.g., `"__"`) Defines the separator for creating nested keys from environment variables (e.g., `MYAPP_DATABASE__HOST` becomes `database.host`). Defaults to `__` (double underscore).

### 6. `cmd_args` (table or boolean, optional)

Controls loading configuration from command-line arguments. Default: `true`.

- If `true`, `lua.melt` might try to use a standard `arg` table if available globally, or integrate with a known CLI parsing convention. *This behavior might be refined for more explicit control in the future.*
- If a table, it's assumed to be a pre-parsed table of command-line options, exactly like what `config:add_cmdline_options(your_parsed_args_table)` accepts. This is the recommended way for robust CLI argument integration.

## Precedence Order (Lowest to Highest)

`melt.declare()` establishes a clear and sensible precedence order:

1. **`defaults`**: Values provided in the `defaults` option (either as a table or from a file).
2. **System-wide files**: Configurations found in `config_locations.system` paths.
3. **User-specific files**: Configurations found in `config_locations.user` paths.
4. **Project-local files**: Configurations found in `config_locations.project` paths.
5. **Custom path files**: Configurations specified in `config_locations.custom_paths`.
6. **Environment variables**: Values loaded based on the `env` options.
7. **Command-line arguments**: Values loaded based on the `cmd_args` option (especially if a pre-parsed table is provided).

Within each file-based category (system, user, project, custom), if multiple files are found (e.g., `config.toml` and `myapp.json` in the same directory), their internal precedence is typically determined by the order in `options.formats` and then `options.file_names`. Generally, the last value read for a given key wins within that source type.

## Comprehensive Example

Let's see a more detailed example:

```lua
local melt = require("lua.melt")

-- 1. Define application-specific defaults (lowest precedence)
local app_coded_defaults = {
  logging = {
    level = "info",
    file = "/var/log/myapp.log" -- Might be overridden
  },
  feature_flags = {
    new_dashboard = false
  },
  greeting = "Hello from defaults"
}

-- 2. Simulate pre-parsed command-line arguments (highest precedence)
-- In a real app, this would come from a library like Lapp or lua-argparse.
local parsed_cli_args = {
  ["logging-level"] = "debug", -- Will become logging.level
  ["feature-flags-new-dashboard"] = "true", -- Becomes feature_flags.new_dashboard
  ["server-port"] = "8080" -- Becomes server.port
}

-- 3. Use melt.declare()
local config, errors = melt.declare({
  app_name = "SuperApp",
  defaults = app_coded_defaults,

  config_locations = {
    system  = true, -- Search /etc/SuperApp/config.<ext>, /etc/SuperApp/SuperApp.<ext>
    user    = true, -- Search ~/.config/SuperApp/config.<ext>, etc.
    project = { "./.app_config/", "./" }, -- Search specific project directories first, then CWD
    custom_paths = {
      "conf/global_overrides.toml",
      "/etc/company_wide/superapp_settings.json"
    },
    file_names = {"config", "settings", "SuperApp"}, -- Basenames to look for
    use_app_name_as_dir = true -- e.g. ~/.config/SuperApp/
  },

  formats = {"toml", "json", "yaml"}, -- Accepted file formats

  env = {
    prefix = "SUPERAPP_", -- e.g., SUPERAPP_LOGGING_LEVEL=warning
    auto_parse_types = true,
    nested_separator = "__" -- e.g. SUPERAPP_DATABASE__HOST
  },

  cmd_args = parsed_cli_args -- Pass the pre-parsed table
})

-- 4. Handle potential errors during loading
if errors and #errors > 0 then
  print("Configuration loading errors encountered:")
  for i, err_info in ipairs(errors) do
    local msg = string.format("  %d. Message: %s", i, err_info.message or "Unknown error")
    if err_info.source then
      msg = msg .. string.format(" (Source: %s", err_info.source)
      if err_info.path then
        msg = msg .. string.format(" [%s]", err_info.path)
      end
      msg = msg .. ")"
    end
    print(msg)
  end
end

-- 5. Access configuration values
-- Values will be from the highest-precedence source that defines them.
print(string.format("Application Name: %s", config:get("app_name") or "Not Set (should come from defaults or file)")) -- app_name itself isn't usually a config item this way
print(string.format("Logging Level: %s", config:get("logging.level"))) -- Expected: "debug" (from CLI)
print(string.format("New Dashboard Enabled: %s", tostring(config:get("feature_flags.new_dashboard")))) -- Expected: true (from CLI)
print(string.format("Greeting: %s", config:get("greeting"))) -- Expected: "Hello from defaults" (unless overridden by a file/env)
print(string.format("Server Port: %s", config:get("server.port"))) -- Expected: 8080 (from CLI)
print(string.format("Database Host (from env/file): %s", config:get("database.host"))) -- e.g., set SUPERAPP_DATABASE__HOST=db.example.com

-- For detailed inspection:
-- local inspect = require("inspect") -- if you have it
-- print(inspect(config:get_table()))
```

**To make this example runnable, you would:**

- Create some dummy configuration files in the expected locations (e.g., `~/.config/SuperApp/config.toml`, `./config.json`).
- Set some environment variables (e.g., `export SUPERAPP_DATABASE__HOST=my_db_server`).

## Handling Errors

The `melt.declare()` function returns two values: the configuration object (`config`) and a table of errors (`errors`). It's good practice to check the `errors` table to see if any issues occurred during the discovery or parsing of configuration sources. Each error entry in the table might contain:

- `message`: A description of the error.
- `source`: A string indicating the type of source (e.g., "file", "env").
- `path`: The file path, if applicable.

## Conclusion

The `melt.declare()` function provides a high-level, convention-based way to manage your application's configuration. By understanding its options and precedence rules, you can significantly simplify your configuration setup while maintaining flexibility and control. It wraps the granular power of `lua.melt`'s manual `add_*` methods into a user-friendly package for common application scenarios.
