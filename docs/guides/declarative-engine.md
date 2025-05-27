# Declarative Engine

Currently, lua.melt works with a more imperative api: you declare exactly which
files, if the env var and so on. Since there is a very common use case and usage
patterns, we could make this even easier for user.

In this scenario, the user could specify a set of high-level options, and
`lua.melt` would intelligently discover and merge configurations from various
conventional sources. This approach aims to reduce boilerplate and make common
configuration patterns effortless.

## The `melt.declare()` Function

We propose a new function, `melt.declare(options)`, which would act as a smart
constructor for your configuration object.

```lua
local melt = require("lua.melt") -- Or your actual require path
local config = melt.declare({
  app_name = "MyApplication",
  -- other options...
})
```

This function would internally generate the appropriate list of sources and use
the existing `Melt.merge()` logic to create the final configuration table. The
key is that `melt.declare()` handles the discovery and setup of these sources
based on conventions and the options you provide.

### Core Idea

The primary input would be an `app_name`. Based on this `app_name`,
`melt.declare()` would:

1.  Look for application defaults.
2.  Scan standard system-wide, user-specific, and project-local configuration
    directories for files matching `app_name` or common names like `config`.
3.  Consider specified custom file paths.
4.  Incorporate environment variables, typically prefixed with an uppercase
    version of `app_name`.
5.  Integrate command-line arguments.

All of this would follow a clear precedence order.

### Key Options for `melt.declare(options)`

The `options` table passed to `melt.declare()` could include fields like:

- `app_name`: (string, **required**) The name of your application (e.g.,
  `"myapp"`, `"MyGreatTool"`). This is crucial for deriving default file names,
  directory paths (e.g., `~/.config/myapp/`), and environment variable prefixes
  (e.g., `MYAPP_`).

- `defaults`: (table or string path, optional)

  - A Lua table containing the most basic default values for your application.
  - Alternatively, a string path to a file (e.g.,
    `/usr/share/myapp/defaults.toml`) containing these defaults. This layer has
    the lowest precedence.

- `config_locations`: (table, optional - controls file-based configuration
  loading)

  - `system`: (boolean or string/array of strings, default: `false`)
    - If `true`, searches standard system-wide locations (e.g.,
      `/etc/<app_name>/`, `/etc/`).
    - If a string or array, specifies exact system paths or directories to
      search.
  - `user`: (boolean or string/array of strings, default: `true`)
    - If `true`, searches standard user-specific locations (e.g.,
      `~/.config/<app_name>/`, `~/.<app_name>/`).
    - If a string or array, specifies exact user-specific paths or directories.
  - `project`: (boolean or string/array of strings, default: `true`)
    - If `true`, searches the current working directory and potentially
      recognized project roots (e.g., `./`, `.config/`).
    - If a string or array, specifies exact project-relative paths or
      directories.
  - `custom_paths`: (array of strings, optional) An explicit list of absolute or
    relative file paths or directories to also load configuration from.
  - `file_names`: (array of strings, optional, default:
    `["config", "<app_name>"]`) A list of base names (without extension) for
    configuration files to look for within the specified locations (e.g.,
    `config.toml`, `myapp.json`).
  - `use_app_name_as_dir`: (boolean, optional, default: `true`) If true, in
    standard locations like `~/.config/`, it will look for a subdirectory named
    `<app_name>` (e.g., `~/.config/myapp/config.toml`).

- `formats`: (array of strings, optional, default:
  `["toml", "json", "yaml", "ini", "config"]`) An array of file extensions
  (without the dot) representing the accepted configuration file formats.
  `lua.melt` would attempt to parse files with these extensions.

- `env`: (boolean or table, optional, default: `true`) Controls loading
  configuration from environment variables.

  - If `true`, enables environment variables, using a prefix derived from
    `app_name` (e.g., `MYAPP_`).
  - If a table, allows customization:
    - `prefix`: (string, e.g., `"MY_CUSTOM_APP_"`) Specifies the exact prefix.
      If not given, defaults to `string.upper(app_name) .. "_"`.
    - `auto_parse_types`: (boolean, default: `true`) If `lua.melt` should
      attempt to convert environment variable strings to numbers or booleans.
    - `nested_separator`: (string, e.g., `"__"`) Defines separator for nested
      keys (e.g., `MYAPP_DATABASE__HOST`). Defaults to `_`.

- `cmd_args`: (table or boolean, optional, default: `true`) Controls loading
  configuration from command-line arguments.
  - If `true`, `lua.melt` might try to use a standard `arg` table if available,
    or integrate with a known CLI parsing convention (this part requires careful
    design for flexibility).
  - If a table, it's assumed to be a pre-parsed table of command-line options,
    similar to what `:add_cmdline_options()` currently accepts.

### Precedence Order

A critical aspect is a well-defined and sensible precedence order. Generally,
more specific sources should override more general ones. A typical order (from
lowest to highest precedence) would be:

1.  `defaults` (coded or from default file path)
2.  System-wide configuration files (`config_locations.system`)
3.  User-specific configuration files (`config_locations.user`)
4.  Project-local configuration files (`config_locations.project`)
5.  Custom path configuration files (`config_locations.custom_paths`)
6.  Environment variables (`env` options)
7.  Command-line arguments (`cmd_args`)

Within each file-based category, the order of files found (if multiple exist)
would also need a clear rule (e.g., based on `file_names` order, or alphabetic).

### Example Usage

```lua
local melt = require("lua.melt") -- Or your actual require path

-- 1. Define application-specific defaults directly in code (lowest precedence)
local app_coded_defaults = {
  logging = {
    level = "info",
    file = "/var/log/myapp.log" -- This might be overridden by other sources
  },
  feature_x_enabled = false,
  greeting = "Hello from defaults"
}

-- Assume 'arg' is the table of command-line arguments,
-- e.g., from Lua's default varargs or a CLI parser.
-- For testing, you can mock it:
-- local arg = { ["logging.level"] = "debug", feature_x_enabled = "true", ["server.port"] = 8080 }


-- 2. Use melt.declare() to set up the configuration hierarchy
local config, errors = melt.declare({
  app_name = "myapp",
  defaults = app_coded_defaults,

  config_locations = {
    system  = true, -- Search /etc/myapp/config.<ext>, /etc/myapp/myapp.<ext>
    user    = true, -- Search ~/.config/myapp/config.<ext>, etc.
    project = { "./config/", ".config/" }, -- Search specific project directories
    custom_paths = {
      "conf/override.toml", -- A specific custom file
      "/opt/global_app_settings/myapp.json"
    },
    file_names = {"config", "settings", "myapp"} -- Basenames to look for
  },

  formats = {"toml", "json", "yaml"}, -- Accepted file formats

  env = {
    prefix = "MYAPP_", -- e.g., MYAPP_LOGGING_LEVEL=warning MYAPP_FEATURE_X_ENABLED=true
    auto_parse_types = true
  },

  -- Assuming 'arg' is populated by the shell or a CLI parser
  cmd_args = arg -- Highest precedence
})

if errors and #errors > 0 then
  print("Configuration loading errors:")
  for _, err in ipairs(errors) do
    print("- " .. err.message .. (err.source and (" (Source: " .. err.source .. ")") or ""))
  end
end

-- 3. Access configuration values
-- The values will be from the highest-precedence source that defines them.
print("Logging Level:", config:get("logging.level")) -- Potentially overridden by CLI, then ENV, then files
print("Feature X Enabled:", config:get("feature_x_enabled")) -- Boolean conversion from ENV/CLI is useful
print("Greeting:", config:get("greeting"))
print("Server Port:", config:get("server.port")) -- e.g. from CLI or a config file
print("Database Host (might be nil):", config:get("database.host"))

-- Get the entire configuration as a table
local all_settings = config:get_table()
-- require("inspect")(all_settings) -- For detailed inspection if you have an inspect library
```

This `melt.declare()` function would significantly streamline the setup for many
applications, providing a powerful, convention-over-configuration approach while
still allowing customization where needed. It effectively wraps the granular
power of `Melt.merge()` and the individual `add_*` methods into a more
user-friendly package for common scenarios.

```lua
local merged = melt.declare({app_defaults=/var/lib/app)
```

```lua
local config = melt.declare("myapp")
  :with_defaults({timeout = 5000})
  :skip_system_config()
  :add_custom_path("./special-config.toml")
```
