-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("lua.melt")
local readers = require("lua.melt.readers")
local logger = require("lual").logger()

describe("Declarative Engine - Integration Tests", function()
    local temp_files = {}

    -- Helper function to create temporary files for testing
    local function create_temp_file(path, content)
        local file = io.open(path, "w")
        if file then
            file:write(content)
            file:close()
            table.insert(temp_files, path)
            return true
        end
        return false
    end

    -- Clean up temporary files after each test
    after_each(function()
        for _, filepath in ipairs(temp_files) do
            os.remove(filepath)
        end
        temp_files = {}
    end)

    describe("user home configuration loading", function()
        it("should load from ~/.config/app_name/config.toml", function()
            local home = os.getenv("HOME")
            if not home then
                pending("HOME environment variable not set")
                return
            end

            -- Create test directory and file
            local config_dir = home .. "/.config/testapp123"
            os.execute("mkdir -p " .. config_dir)

            local config_file = config_dir .. "/config.toml"
            local toml_content = [[
app_name = "testapp123"
user_setting = "from_user_config"

[database]
host = "user-db-host"
port = 3306
]]

            if create_temp_file(config_file, toml_content) then
                local config, errors = Melt.declare({
                    app_name = "testapp123"
                })

                assert.are.equal("testapp123", config:get("app_name"))
                assert.are.equal("from_user_config", config:get("user_setting"))
                assert.are.equal("user-db-host", config:get("database.host"))
                assert.are.equal(3306, config:get("database.port"))
                assert.are.equal(0, #errors)

                -- Clean up directory
                os.execute("rm -rf " .. config_dir)
            else
                pending("Could not create test config file")
            end
        end)

        it("should load from ~/.app_name.json as fallback", function()
            local home = os.getenv("HOME")
            if not home then
                pending("HOME environment variable not set")
                return
            end

            local config_file = home .. "/.testapp456.json"
            local json_content = [[{
  "app_name": "testapp456",
  "user_setting": "from_dotfile",
  "database": {
    "host": "dotfile-db-host",
    "port": 5432
  }
}]]

            if create_temp_file(config_file, json_content) then
                local config, errors = Melt.declare({
                    app_name = "testapp456"
                })

                assert.are.equal("testapp456", config:get("app_name"))
                assert.are.equal("from_dotfile", config:get("user_setting"))
                assert.are.equal("dotfile-db-host", config:get("database.host"))
                assert.are.equal(5432, config:get("database.port"))
                assert.are.equal(0, #errors)
            else
                pending("Could not create test config file")
            end
        end)
    end)

    describe("precedence with defaults and user config", function()
        it("should have user config override defaults", function()
            local home = os.getenv("HOME")
            if not home then
                pending("HOME environment variable not set")
                return
            end

            local defaults = {
                app_name = "testapp789",
                timeout = 5000,
                database = {
                    host = "default-host",
                    port = 5432
                },
                only_in_defaults = "default_value"
            }

            local config_file = home .. "/.testapp789.toml"
            local toml_content = [[
app_name = "testapp789"
timeout = 10000
only_in_user = "user_value"

[database]
host = "user-override-host"
]]

            if create_temp_file(config_file, toml_content) then
                local config, errors = Melt.declare({
                    app_name = "testapp789",
                    defaults = defaults
                })

                logger.error("Errors:", #errors)
                for i, err in ipairs(errors) do
                    logger.error("Error " .. i .. ":", err.message, err.source)
                end

                logger.error("only_in_user value:", config:get("only_in_user"))
                logger.error("Config data:")
                local config_table = config:get_table()
                if config_table then
                    for k, v in pairs(config_table) do
                        logger.info("  " .. k .. ":", v)
                    end
                end

                -- User config should override defaults
                assert.are.equal("testapp789", config:get("app_name"))
                assert.are.equal(10000, config:get("timeout"))                      -- overridden
                assert.are.equal("user-override-host", config:get("database.host")) -- overridden
                assert.are.equal(5432, config:get("database.port"))                 -- kept from defaults

                -- Values only in defaults should be preserved
                assert.are.equal("default_value", config:get("only_in_defaults"))

                -- Values only in user config should be added
                assert.are.equal("user_value", config:get("only_in_user"))

                assert.are.equal(0, #errors)
            else
                pending("Could not create test config file")
            end
        end)
    end)

    describe("Phase B - Multiple configuration files", function()
        it("should load configuration from multiple custom paths", function()
            local home = os.getenv("HOME")
            if not home then
                pending("HOME environment variable not set")
                return
            end

            -- Create multiple test files
            local custom_dir = "./custom_config_dir"
            os.execute("mkdir -p " .. custom_dir)

            local custom_config_file = custom_dir .. "/custom_app.toml"
            local custom_toml_content = [[
custom_setting = "from_custom_dir"
shared_setting = "from_custom_dir"
]]
            create_temp_file(custom_config_file, custom_toml_content)

            local direct_file = "./direct_config.json"
            local direct_json_content = [[{
  "direct_setting": "from_direct_file",
  "shared_setting": "from_direct_file"
}]]
            create_temp_file(direct_file, direct_json_content)

            -- Create defaults for testing
            local defaults = {
                app_name = "multiconfigapp",
                default_setting = "from_defaults",
                shared_setting = "from_defaults"
            }

            local config, errors = Melt.declare({
                app_name = "multiconfigapp",
                defaults = defaults,
                config_locations = {
                    custom_paths = {
                        custom_dir,
                        direct_file
                    }
                }
            })

            assert.are.equal(0, #errors)
            assert.are.equal("multiconfigapp", config:get("app_name"))
            assert.are.equal("from_defaults", config:get("default_setting"))
            assert.are.equal("from_custom_dir", config:get("custom_setting"))
            assert.are.equal("from_direct_file", config:get("direct_setting"))
            -- Test precedence - direct_file was last, so it should win
            assert.are.equal("from_direct_file", config:get("shared_setting"))

            -- Clean up
            os.execute("rm -rf " .. custom_dir)
        end)

        it("should respect the use_app_name_as_dir option", function()
            local home = os.getenv("HOME")
            if not home then
                pending("HOME environment variable not set")
                return
            end

            -- Create test directory with app name subdirectory
            local config_dir = "./test_config_dir"
            os.execute("mkdir -p " .. config_dir .. "/dirapptestapp")

            -- Create a config file in the app subdirectory
            local subdir_config_file = config_dir .. "/dirapptestapp/config.toml"
            local subdir_content = [[
app_name = "dirapptestapp"
location = "in_app_subdir"
]]
            create_temp_file(subdir_config_file, subdir_content)

            -- Create a config file directly in the parent directory
            local parent_config_file = config_dir .. "/dirapptestapp.toml"
            local parent_content = [[
app_name = "dirapptestapp"
location = "in_parent_dir"
]]
            create_temp_file(parent_config_file, parent_content)

            -- Test with use_app_name_as_dir = true (default)
            local config1, errors1 = Melt.declare({
                app_name = "dirapptestapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { config_dir },
                    use_app_name_as_dir = true
                }
            })

            assert.are.equal(0, #errors1)
            assert.are.equal("in_app_subdir", config1:get("location"))

            -- Test with use_app_name_as_dir = false
            local config2, errors2 = Melt.declare({
                app_name = "dirapptestapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { config_dir },
                    use_app_name_as_dir = false
                }
            })

            assert.are.equal(0, #errors2)
            assert.are.equal("in_parent_dir", config2:get("location"))

            -- Clean up
            os.execute("rm -rf " .. config_dir)
        end)

        it("should use custom file_names if provided", function()
            local home = os.getenv("HOME")
            if not home then
                pending("HOME environment variable not set")
                return
            end

            -- Create test directory
            local config_dir = "./custom_names_dir"
            os.execute("mkdir -p " .. config_dir)

            -- Create a config file with custom name
            local custom_name_file = config_dir .. "/settings.toml"
            local custom_name_content = [[
from_custom_name = true
]]
            create_temp_file(custom_name_file, custom_name_content)

            -- Create a standard config file (should be ignored with custom names)
            local standard_file = config_dir .. "/config.toml"
            local standard_content = [[
from_standard_name = true
]]
            create_temp_file(standard_file, standard_content)

            local config, errors = Melt.declare({
                app_name = "customnameapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { config_dir },
                    file_names = { "settings", "preferences" } -- No "config"
                }
            })

            assert.are.equal(0, #errors)
            assert.is_true(config:get("from_custom_name"))
            assert.is_nil(config:get("from_standard_name"))

            -- Clean up
            os.execute("rm -rf " .. config_dir)
        end)
    end)

    describe("Phase C - Environment variable support", function()
        it("should load environment variables with default options", function()
            -- Create a mock environment with test variables
            local mock_env = {
                ["ENVTESTAPP_SIMPLE_VALUE"] = "env_simple",
                ["ENVTESTAPP_NUMERIC_VALUE"] = "42",
                ["ENVTESTAPP_BOOLEAN_VALUE"] = "true",
                ["ENVTESTAPP_DATABASE__HOST"] = "env-db-host",
                ["ENVTESTAPP_DATABASE__PORT"] = "5678",
                ["OTHER_PREFIX_IGNORED"] = "should-be-ignored"
            }

            local config, errors = Melt.declare({
                app_name = "envtestapp"
            }, mock_env) -- Pass mock environment directly

            assert.are.equal(0, #errors)
            assert.are.equal("env_simple", config:get("simple_value"))
            assert.are.equal(42, config:get("numeric_value"))            -- Auto-converted to number
            assert.is_true(config:get("boolean_value"))                  -- Auto-converted to boolean
            assert.are.equal("env-db-host", config:get("database.host")) -- Nested via __
            assert.are.equal(5678, config:get("database.port"))          -- Nested and converted
            assert.is_nil(config:get("ignored"))                         -- Should not load variables with other prefixes
        end)

        it("should support custom prefix", function()
            -- Create a mock environment with test variables
            local mock_env = {
                ["CUSTOM_PREFIX_SETTING"] = "custom_prefix_value",
                ["ENVTESTAPP_IGNORED"] = "should-be-ignored"
            }

            local config, errors = Melt.declare({
                app_name = "prefixtest",
                env = {
                    prefix = "CUSTOM_PREFIX_"
                }
            }, mock_env) -- Pass mock environment directly

            assert.are.equal(0, #errors)
            assert.are.equal("custom_prefix_value", config:get("setting"))
            assert.is_nil(config:get("ignored")) -- Should not be loaded with different prefix
        end)

        it("should respect auto_parse_types option", function()
            -- Create a mock environment with test variables
            local mock_env = {
                ["ENVTESTAPP_NO_PARSE_NUM"] = "123"
            }

            local config, errors = Melt.declare({
                app_name = "envtestapp",
                env = {
                    auto_parse_types = false
                }
            }, mock_env) -- Pass mock environment directly

            assert.are.equal(0, #errors)
            assert.are.equal("123", config:get("no_parse_num")) -- Should remain a string
        end)

        it("should support custom nested_separator", function()
            -- Create a mock environment with test variables
            local mock_env = {
                ["ENVTESTAPP_CUSTOM::SEPARATOR"] = "custom_separator_value"
            }

            local config, errors = Melt.declare({
                app_name = "envtestapp",
                env = {
                    nested_separator = "::"
                }
            }, mock_env) -- Pass mock environment directly

            assert.are.equal(0, #errors)
            assert.are.equal("custom_separator_value", config:get("custom.separator"))
        end)

        it("should disable environment variables with env=false", function()
            -- Create a mock environment with test variables
            local mock_env = {
                ["ENVTESTAPP_SIMPLE_VALUE"] = "env_simple"
            }

            local config, errors = Melt.declare({
                app_name = "envtestapp",
                env = false
            }, mock_env) -- Pass mock environment but it should be ignored

            assert.are.equal(0, #errors)
            assert.is_nil(config:get("simple_value")) -- Should not be loaded
        end)
    end)

    describe("Phase D - Command-line argument support", function()
        it("should handle pre-parsed command-line arguments", function()
            -- Use pre-parsed arguments directly
            local parsed_cli_args = {
                ["logging-level"] = "debug",
                ["feature-flags-new-dashboard"] = "true",
                ["server-port"] = "8080"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                cmd_args = parsed_cli_args
            })

            assert.are.equal(0, #errors)
            assert.are.equal("debug", config:get("logging.level"))
            assert.is_true(config:get("feature_flags.new_dashboard"))
            assert.are.equal(8080, config:get("server.port"))
        end)

        it("should parse arguments from provided arg table", function()
            -- Use pre-parsed arguments directly
            local parsed_args = {
                ["verbose"] = true,
                ["output-format"] = "json"
            }

            local config, errors = Melt.declare({
                app_name = "argapp",
                cmd_args = parsed_args
            })

            assert.are.equal(0, #errors)
            assert.is_true(config:get("verbose"))
            assert.are.equal("json", config:get("output.format"))
        end)

        it("should disable command-line arguments with cmd_args=false", function()
            -- Even with pre-parsed arguments, they should be ignored when cmd_args=false
            local parsed_args = {
                ["verbose"] = true,
                ["output-format"] = "json"
            }

            local config, errors = Melt.declare({
                app_name = "disabledargapp",
                cmd_args = false
            })

            assert.are.equal(0, #errors)
            assert.is_nil(config:get("verbose"))
            assert.is_nil(config:get("output.format"))
        end)
    end)

    describe("format precedence", function()
        local temp_files_format = {}
        local temp_dirs_format = {}

        local function create_temp_file_fp(path, content) -- local helper
            local file = io.open(path, "w")
            if file then
                file:write(content); file:close(); table.insert(temp_files_format, path); return true
            end
            return false
        end
        local function create_temp_dir_fp(path) -- local helper
            -- Use os.execute to create directory, check for success if necessary
            -- For simplicity in test setup, direct os.execute is used.
            os.execute("mkdir -p " .. path)
            table.insert(temp_dirs_format, path)
        end

        after_each(function()
            for _, filepath in ipairs(temp_files_format) do os.remove(filepath) end; temp_files_format = {}
            -- Ensure directories are removed recursively and silently
            for _, dirpath in ipairs(temp_dirs_format) do os.execute("rm -rf " .. dirpath) end; temp_dirs_format = {}
        end)

        it("should load .toml before .json if specified in formats", function()
            local test_dir = "./temp_format_test_dir"
            create_temp_dir_fp(test_dir)

            assert.is_true(create_temp_file_fp(test_dir .. "/myconfig.toml", "setting = 'from_toml'"),
                "Failed to create TOML file")
            assert.is_true(create_temp_file_fp(test_dir .. "/myconfig.json", "{ \"setting\": \"from_json\" }"),
                "Failed to create JSON file")

            local config, errors = Melt.declare({
                app_name = "formatprecedence",
                config_locations = {
                    project = { test_dir },     -- Search in our test directory
                    system = false,
                    user = false,
                    file_names = { "myconfig" } -- Base name to look for
                },
                formats = { "toml", "json" }    -- TOML first
            })

            assert.are.equal(0, #errors)
            assert.are.equal("from_toml", config:get("setting"))
        end)

        it("should load .json before .toml if specified in formats", function()
            local test_dir = "./temp_format_test_dir2"
            create_temp_dir_fp(test_dir)

            assert.is_true(create_temp_file_fp(test_dir .. "/myconfig.toml", "setting = 'from_toml'"),
                "Failed to create TOML file")
            assert.is_true(create_temp_file_fp(test_dir .. "/myconfig.json", "{ \"setting\": \"from_json\" }"),
                "Failed to create JSON file")

            local config, errors = Melt.declare({
                app_name = "formatprecedence2",
                config_locations = {
                    project = { test_dir },
                    system = false,
                    user = false,
                    file_names = { "myconfig" }
                },
                formats = { "json", "toml" } -- JSON first
            })

            assert.are.equal(0, #errors)
            assert.are.equal("from_json", config:get("setting"))
        end)

        it("should load only specified formats, ignoring others with same base name", function()
            local test_dir = "./temp_format_test_dir3"
            create_temp_dir_fp(test_dir)

            assert.is_true(create_temp_file_fp(test_dir .. "/appsettings.toml", "setting = 'from_toml'"),
                "Failed to create TOML file")
            assert.is_true(create_temp_file_fp(test_dir .. "/appsettings.yaml", "setting: from_yaml"),
                "Failed to create YAML file")
            assert.is_true(create_temp_file_fp(test_dir .. "/appsettings.json", "{ \"setting\": \"from_json\" }"),
                "Failed to create JSON file")


            local config, errors = Melt.declare({
                app_name = "formatprecedence3",
                config_locations = {
                    project = { test_dir },
                    system = false,
                    user = false,
                    file_names = { "appsettings" }
                },
                formats = { "yaml", "json" } -- Only yaml and json, toml should be ignored
            })

            assert.are.equal(0, #errors)
            assert.are.equal("from_yaml", config:get("setting")) -- YAML is first in formats
        end)
    end)
end)
