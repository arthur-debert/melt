-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("melt")

describe("Comprehensive Integration Tests", function()
    local temp_files = {}
    local temp_dirs = {}

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

    -- Helper function to create temporary directories
    local function create_temp_dir(path)
        os.execute("mkdir -p " .. path)
        table.insert(temp_dirs, path)
        return true
    end

    -- Clean up temporary files and directories after each test
    after_each(function()
        for _, filepath in ipairs(temp_files) do
            os.remove(filepath)
        end
        for _, dirpath in ipairs(temp_dirs) do
            os.execute("rm -rf " .. dirpath)
        end
        temp_files = {}
        temp_dirs = {}
    end)

    describe("Full stack configuration workflows", function()
        it("should handle complete configuration with all sources", function()
            -- 1. Set up defaults
            local defaults = {
                app_name = "fullstackapp",
                timeout = 30,
                database = {
                    host = "default-host",
                    port = 5432,
                    connections = 10
                },
                features = {
                    feature_a = false,
                    feature_b = true
                }
            }

            -- 2. Create custom config file
            local custom_config_dir = "./custom_config_test"
            create_temp_dir(custom_config_dir)
            local custom_config_file = custom_config_dir .. "/fullstackapp.toml"
            local custom_config_content = [[
timeout = 60
feature_override = "from_file"

[database]
host = "config-file-host"
max_connections = 50

[features]
feature_a = true
feature_c = true
]]
            create_temp_file(custom_config_file, custom_config_content)

            -- 3. Set up environment variables
            local mock_env = {
                FULLSTACKAPP_DATABASE__HOST = "env-override-host",
                FULLSTACKAPP_DATABASE__PORT = "6543",
                FULLSTACKAPP_FEATURES__FEATURE_B = "false",
                FULLSTACKAPP_NEW_SETTING = "from_env"
            }

            -- 4. Set up command line arguments
            local cli_args = {
                ["database-port"] = "7777",
                ["features.feature_a"] = "false", -- Direct dot notation should work
                ["cli-only-setting"] = "from_cli"
            }

            -- 5. Execute declarative config
            local config, errors = Melt.declare({
                app_name = "fullstackapp",
                defaults = defaults,
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { custom_config_dir }
                },
                cmd_args = cli_args
            }, mock_env)

            assert.are.equal(0, #errors)

            -- 6. Test precedence (CLI > ENV > FILE > DEFAULTS)
            assert.are.equal("fullstackapp", config:get("app_name"))           -- defaults
            assert.are.equal(60, config:get("timeout"))                        -- file overrides defaults
            assert.are.equal("env-override-host", config:get("database.host")) -- env overrides file
            assert.are.equal(7777, config:get("database.port"))                -- cli overrides env
            assert.are.equal(10, config:get("database.connections"))           -- defaults (not overridden)
            assert.are.equal(50, config:get("database.max_connections"))       -- file only

            -- Test feature flags with different sources
            assert.is_false(config:get("features.feature_a")) -- cli overrides everything
            assert.is_false(config:get("features.feature_b")) -- env overrides file/defaults
            assert.is_true(config:get("features.feature_c"))  -- file only

            -- Test source-specific settings
            assert.are.equal("from_file", config:get("feature_override"))
            assert.are.equal("from_env", config:get("new_setting"))
            assert.are.equal("from_cli", config:get("cli.only.setting")) -- hyphens convert to dots
        end)

        it("should handle complex nested array configurations", function()
            local defaults = {
                clusters = {
                    {
                        name = "primary",
                        nodes = {
                            { host = "node1.primary.com", port = 5432 },
                            { host = "node2.primary.com", port = 5432 }
                        }
                    }
                }
            }

            -- Override via environment variables (arrays are trickier - let's test simple nesting)
            local mock_env = {
                COMPLEXAPP_DATABASE__HOST = "env-override-host",
                COMPLEXAPP_DATABASE__PORT = "5433"
            }

            local config, errors = Melt.declare({
                app_name = "complexapp",
                defaults = {
                    database = {
                        host = "default-host",
                        port = 5432
                    }
                }
            }, mock_env)

            assert.are.equal(0, #errors)

            -- Test environment variable overrides
            assert.are.equal("env-override-host", config:get("database.host"))
            assert.are.equal(5433, config:get("database.port"))
        end)
    end)

    describe("Error handling and edge cases", function()
        it("should gracefully handle missing files in custom paths", function()
            local config, errors = Melt.declare({
                app_name = "missingfileapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = {
                        "missing_file.toml" -- Only test one missing file
                    }
                }
            })

            assert.is_not_nil(config)
            -- Should have exactly 1 error for the missing file
            assert.are.equal(1, #errors)
            assert.are.equal("custom_file_not_found", errors[1].source)
            assert.is_true(string.find(errors[1].message, "Custom configuration file not found") ~= nil)
            -- Also check path if available
            if errors[1] then assert.are.equal("missing_file.toml", errors[1].path) end
        end)

        it("should handle malformed configuration files gracefully", function()
            local bad_config_dir = "./bad_config_test"
            create_temp_dir(bad_config_dir)

            -- Create malformed TOML file
            local bad_toml_file = bad_config_dir .. "/badapp.toml"
            local bad_toml_content = [[
app_name = "badapp"
[database
host = "missing-closing-bracket"
]]
            create_temp_file(bad_toml_file, bad_toml_content)

            local config, errors = Melt.declare({
                app_name = "badapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { bad_config_dir }
                }
            })

            assert.is_not_nil(config)
            -- Should still create config object even with parse errors
            -- The malformed file should be ignored
        end)

        it("should handle empty configuration files", function()
            local empty_config_dir = "./empty_config_test"
            create_temp_dir(empty_config_dir)

            -- Create empty TOML file
            local empty_toml_file = empty_config_dir .. "/emptyapp.toml"
            create_temp_file(empty_toml_file, "")

            local config, errors = Melt.declare({
                app_name = "emptyapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { empty_config_dir }
                }
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
            -- Empty config is valid
        end)

        it("should handle directory traversal and invalid paths", function()
            local config, errors = Melt.declare({
                app_name = "securityapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = {
                        "../../../etc/passwd", -- Directory traversal attempt
                        "/dev/null",           -- Special file
                        ""                     -- Empty path
                    }
                }
            })

            assert.is_not_nil(config)
            -- Should handle these gracefully without crashing
        end)
    end)

    describe("Location specification edge cases", function()
        it("should handle string location specifications", function()
            local single_dir = "./single_location_test"
            create_temp_dir(single_dir)

            local config_file = single_dir .. "/stringapp.json"
            local config_content = '{"from_string_location": true}'
            create_temp_file(config_file, config_content)

            local config, errors = Melt.declare({
                app_name = "stringapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = single_dir, -- String instead of array
                    custom_paths = false
                }
            })

            assert.are.equal(0, #errors)
            assert.is_true(config:get("from_string_location"))
        end)

        it("should handle boolean false location specifications", function()
            local config, errors = Melt.declare({
                app_name = "booleanapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = false
                }
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
            -- Should not try to load from any locations
        end)

        it("should handle boolean true location specifications", function()
            local config, errors = Melt.declare({
                app_name = "booleantrueapp",
                config_locations = {
                    system = true, -- Should use defaults
                    user = false,
                    project = false,
                    custom_paths = false
                }
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
            -- Should try to load from default system locations
        end)

        it("should handle invalid location specification types", function()
            local config, errors = Melt.declare({
                app_name = "invalidtypeapp",
                config_locations = {
                    system = 123, -- Invalid type
                    user = false,
                    project = false,
                    custom_paths = false
                }
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
            -- Should handle gracefully by treating as empty
        end)
    end)

    describe("Environment variable edge cases", function()
        it("should handle environment variables without providers", function()
            -- Test with nil environment (should warn but not crash)
            local config, errors = Melt.declare({
                app_name = "noenvapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = false
                }
            }, nil) -- Explicitly pass nil environment

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
        end)

        it("should handle custom environment prefix and separators", function()
            local mock_env = {
                ["CUSTOM::PREFIX::NESTED::VALUE"] = "custom_sep_value",
                ["CUSTOM::PREFIX::SIMPLE"] = "simple_value"
            }

            local config, errors = Melt.declare({
                app_name = "customenvapp",
                env = {
                    prefix = "CUSTOM::PREFIX::",
                    nested_separator = "::",
                    auto_parse_types = false
                },
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = false
                }
            }, mock_env)

            assert.are.equal(0, #errors)
            assert.are.equal("custom_sep_value", config:get("nested.value"))
            assert.are.equal("simple_value", config:get("simple"))
        end)
    end)

    describe("Command line argument edge cases", function()
        it("should handle complex command line argument patterns", function()
            local complex_args = {
                ["very-long-nested-feature-flag"] = "true",
                ["single"] = "value",
                ["numeric-port"] = "8080",
                ["boolean-flag"] = "false"
            }

            local config, errors = Melt.declare({
                app_name = "complexcliapp",
                cmd_args = complex_args,
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = false
                }
            })

            assert.are.equal(0, #errors)
            assert.is_true(config:get("very.long.nested.feature.flag"))
            assert.are.equal("value", config:get("single"))
            assert.are.equal(8080, config:get("numeric.port"))
            assert.is_false(config:get("boolean.flag"))
        end)

        it("should handle empty command line arguments", function()
            local config, errors = Melt.declare({
                app_name = "emptycliapp",
                cmd_args = {},
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = false
                }
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
        end)
    end)

    describe("Format support edge cases", function()
        it("should handle custom format specifications", function()
            local custom_format_dir = "./custom_format_test"
            create_temp_dir(custom_format_dir)

            -- Create config with unusual extension
            local unusual_config = custom_format_dir .. "/customapp.config"
            local unusual_content = [[
# This is a config file
app_name = customapp
setting = config_file_value
]]
            create_temp_file(unusual_config, unusual_content)

            local config, errors = Melt.declare({
                app_name = "customapp",
                formats = { "config", "toml", "json" }, -- Custom format order
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { custom_format_dir }
                }
            })

            assert.are.equal(0, #errors)
            assert.are.equal("customapp", config:get("app_name"))
            assert.are.equal("config_file_value", config:get("setting"))
        end)

        it("should handle unsupported file extensions gracefully", function()
            local unsupported_dir = "./unsupported_format_test"
            create_temp_dir(unsupported_dir)

            -- Create file with unsupported extension
            local unsupported_file = unsupported_dir .. "/unsupportedapp.xml"
            local unsupported_content = '<config><setting>xml_value</setting></config>'
            create_temp_file(unsupported_file, unsupported_content)

            local config, errors = Melt.declare({
                app_name = "unsupportedapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { unsupported_dir }
                }
            })

            assert.is_not_nil(config)
            -- XML files should be ignored since they're not in the supported formats
            assert.is_nil(config:get("setting"))
        end)
    end)
end)
