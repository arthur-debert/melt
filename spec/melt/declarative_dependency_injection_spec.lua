-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("lua.melt")
local readers = require("lua.melt.readers")

describe("Declarative Engine - Dependency Injection", function()
    -- Directly test the readers.read_env_vars function with a mock environment
    describe("Environment variables reader", function()
        it("should process table of environment variables", function()
            local mock_env = {
                ["APP_KEY1"] = "value1",
                ["APP_KEY2"] = "42",
                ["APP_NESTED__KEY"] = "nested_value",
                ["OTHER_PREFIX"] = "ignored"
            }

            local result = readers.read_env_vars("APP_", true, "__", mock_env)

            assert.are.equal("value1", result.key1)
            assert.are.equal(42, result.key2)  -- Should be converted to number
            assert.are.equal("nested_value", result.nested.key)
            assert.is_nil(result.other_prefix) -- Should be ignored due to prefix
        end)

        it("should respect auto_parse_types option", function()
            local mock_env = {
                ["APP_NUMBER"] = "123",
                ["APP_BOOLEAN"] = "true"
            }

            local result1 = readers.read_env_vars("APP_", true, "__", mock_env)
            local result2 = readers.read_env_vars("APP_", false, "__", mock_env)

            assert.are.equal(123, result1.number)     -- Should be converted to number
            assert.is_true(result1.boolean)           -- Should be converted to boolean

            assert.are.equal("123", result2.number)   -- Should remain a string
            assert.are.equal("true", result2.boolean) -- Should remain a string
        end)

        it("should respect nested_separator option", function()
            local mock_env = {
                ["APP_NESTED::KEY"] = "with_colons",
                ["APP_NESTED__KEY"] = "with_underscores"
            }

            local result1 = readers.read_env_vars("APP_", true, "::", mock_env)
            local result2 = readers.read_env_vars("APP_", true, "__", mock_env)

            assert.are.equal("with_colons", result1.nested.key)
            assert.are.equal("with_underscores", result2.nested.key)
        end)
    end)

    describe("Command-line arguments reader", function()
        it("should correctly parse command line arguments", function()
            local mock_args = {
                ["simple-flag"] = true,
                ["numeric-value"] = "42",
                ["boolean-value"] = "true",
                ["nested-key-value"] = "nested"
            }

            local result = readers.read_cmdline_options(mock_args)

            assert.is_true(result.simple.flag)
            assert.are.equal(42, result.numeric.value)
            assert.is_true(result.boolean.value)
            assert.are.equal("nested", result.nested.key.value)
        end)
    end)

    describe("Full declarative config with dependency injection", function()
        it("should use environment variables from injected environment", function()
            -- Create a mock environment
            local mock_env = {
                ["TESTAPP_SIMPLE_VALUE"] = "from_env",
                ["TESTAPP_NUMERIC_VALUE"] = "42",
                ["TESTAPP_NESTED__KEY"] = "nested_from_env"
            }

            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = {
                    simple_value = "from_defaults",
                    other_value = "only_in_defaults"
                }
            }, mock_env) -- Inject mock environment

            assert.are.equal(0, #errors)
            assert.are.equal("from_env", config:get("simple_value"))        -- Should be overridden by env
            assert.are.equal(42, config:get("numeric_value"))               -- From env
            assert.are.equal("nested_from_env", config:get("nested.key"))   -- From env
            assert.are.equal("only_in_defaults", config:get("other_value")) -- From defaults
        end)

        it("should use command-line args from injected arg provider", function()
            -- Create a mock arg table with pre-parsed arguments
            local mock_args = {
                ["verbose"] = true,
                ["log-level"] = "debug",
                ["database-host"] = "localhost"
            }

            local config, errors = Melt.declare({
                app_name = "cmdapp",
                defaults = {
                    log_level = "info"
                },
                cmd_args = mock_args -- Pass pre-parsed command-line arguments
            })

            assert.are.equal(0, #errors)
            assert.is_true(config:get("verbose"))                      -- From args (flag)
            assert.are.equal("debug", config:get("log.level"))         -- From args (overrides defaults)
            assert.are.equal("localhost", config:get("database.host")) -- From args
        end)

        it("should respect precedence with all sources", function()
            -- Create a mock environment
            local mock_env = {
                ["TESTAPP_SHARED_KEY"] = "from_env",
                ["TESTAPP_ENV_ONLY"] = "only_in_env"
            }

            -- Create pre-parsed command-line args
            local mock_args = {
                ["shared-key"] = "from_args",
                ["args-only"] = "only_in_args"
            }

            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = {
                    shared_key = "from_defaults",
                    defaults_only = "only_in_defaults"
                },
                cmd_args = mock_args -- Pass pre-parsed command-line arguments
            }, mock_env)             -- Pass mock environment

            assert.are.equal(0, #errors)
            assert.are.equal("from_args", config:get("shared.key"))           -- Args override env and defaults
            assert.are.equal("only_in_defaults", config:get("defaults_only")) -- From defaults
            assert.are.equal("only_in_env", config:get("env_only"))           -- From env
            assert.are.equal("only_in_args", config:get("args.only"))         -- From args
        end)
    end)
end)
