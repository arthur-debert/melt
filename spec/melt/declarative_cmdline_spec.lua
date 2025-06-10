-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("lua.melt")

describe("Declarative Engine - Command Line Argument Tests", function()
    describe("basic command-line argument parsing", function()
        it("should parse --key=value format", function()
            local mock_arg = {
                "program_name",
                "--database-host=localhost",
                "--database-port=5432",
                "--verbose=true"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.are.equal("localhost", config:get("database.host"))
            assert.are.equal(5432, config:get("database.port"))
            assert.is_true(config:get("verbose"))
        end)

        it("should parse --key value format", function()
            local mock_arg = {
                "program_name",
                "--output-format", "json",
                "--log-level", "debug",
                "--timeout", "30"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.are.equal("json", config:get("output.format"))
            assert.are.equal("debug", config:get("log.level"))
            assert.are.equal(30, config:get("timeout"))
        end)

        it("should parse boolean flags (--flag)", function()
            local mock_arg = {
                "program_name",
                "--verbose",
                "--dry-run",
                "--feature-enabled"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.is_true(config:get("verbose"))
            assert.is_true(config:get("dry.run"))
            assert.is_true(config:get("feature.enabled"))
        end)

        it("should handle mixed argument formats", function()
            local mock_arg = {
                "program_name",
                "--config-file=./custom.toml",
                "--verbose",
                "--port", "8080",
                "--feature-flags-new-ui=true"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.are.equal("./custom.toml", config:get("config.file"))
            assert.is_true(config:get("verbose"))
            assert.are.equal(8080, config:get("port"))
            assert.is_true(config:get("feature_flags.new_ui"))
        end)

        it("should handle empty arg table gracefully", function()
            local mock_arg = {}

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.is_not_nil(config)
        end)

        it("should handle nil arg table gracefully", function()
            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return nil end)

            assert.are.equal(0, #errors)
            assert.is_not_nil(config)
        end)
    end)

    describe("command-line argument precedence", function()
        it("should override environment variables", function()
            local mock_env = {
                ["CLIAPP_PORT"] = "3000",
                ["CLIAPP_VERBOSE"] = "false"
            }

            local mock_arg = {
                "program_name",
                "--port=8080",
                "--verbose=true"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = true,
                cmd_args = true
            }, mock_env, function() return mock_arg end)

            assert.are.equal(0, #errors)
            -- CLI args should override env vars
            assert.are.equal(8080, config:get("port"))
            assert.is_true(config:get("verbose"))
        end)

        it("should override defaults and file config", function()
            local defaults = {
                port = 9000,
                debug = false,
                timeout = 60
            }

            local mock_arg = {
                "program_name",
                "--port=8080",
                "--debug=true"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                defaults = defaults,
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            -- CLI should override defaults
            assert.are.equal(8080, config:get("port"))
            assert.is_true(config:get("debug"))
            -- Defaults should remain for unspecified args
            assert.are.equal(60, config:get("timeout"))
        end)
    end)

    describe("command-line argument edge cases", function()
        it("should handle arguments with no values correctly", function()
            local mock_arg = {
                "program_name",
                "--enable-feature",
                "--config-file", -- Missing value
                "--another-flag"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.is_true(config:get("enable.feature"))
            assert.is_true(config:get("another.flag"))
            -- config-file should be treated as a flag since no value follows
            assert.is_true(config:get("config.file"))
        end)

        it("should handle arguments with special characters", function()
            local mock_arg = {
                "program_name",
                "--database-connection-string=postgres://user:pass@localhost:5432/db",
                "--log-format=[%Y-%m-%d %H:%M:%S]"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.are.equal("postgres://user:pass@localhost:5432/db", config:get("database.connection.string"))
            assert.are.equal("[%Y-%m-%d %H:%M:%S]", config:get("log.format"))
        end)

        it("should ignore non-double-dash arguments", function()
            local mock_arg = {
                "program_name",
                "positional_arg1",
                "--valid-flag=true",
                "-single-dash",
                "positional_arg2",
                "--another-valid=value"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.is_true(config:get("valid.flag"))
            assert.are.equal("value", config:get("another.valid"))
            -- Should not have processed non-double-dash args
            assert.is_nil(config:get("positional_arg1"))
            assert.is_nil(config:get("single-dash"))
        end)
    end)

    describe("command-line argument type conversion", function()
        it("should convert numeric strings to numbers", function()
            local mock_arg = {
                "program_name",
                "--port=8080",
                "--timeout=30.5",
                "--count=0"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.are.equal(8080, config:get("port"))
            assert.are.equal(30.5, config:get("timeout"))
            assert.are.equal(0, config:get("count"))
        end)

        it("should convert boolean strings to booleans", function()
            local mock_arg = {
                "program_name",
                "--verbose=true",
                "--quiet=false",
                "--debug=TRUE",
                "--production=False"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.is_true(config:get("verbose"))
            assert.is_false(config:get("quiet"))
            assert.is_true(config:get("debug"))
            assert.is_false(config:get("production"))
        end)

        it("should keep non-convertible values as strings", function()
            local mock_arg = {
                "program_name",
                "--name=John Doe",
                "--config-path=/etc/myapp/config.toml",
                "--mixed=123abc"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = true
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.are.equal("John Doe", config:get("name"))
            assert.are.equal("/etc/myapp/config.toml", config:get("config.path"))
            assert.are.equal("123abc", config:get("mixed"))
        end)
    end)

    describe("command-line argument disabling", function()
        it("should respect cmd_args=false", function()
            local mock_arg = {
                "program_name",
                "--should-be-ignored=true",
                "--port=8080"
            }

            local config, errors = Melt.declare({
                app_name = "cliapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = false
            }, nil, function() return mock_arg end)

            assert.are.equal(0, #errors)
            assert.is_nil(config:get("should.be.ignored"))
            assert.is_nil(config:get("port"))
        end)
    end)
end)
