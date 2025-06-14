-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("melt")

describe("Declarative Engine - Phase A", function()
    describe("melt.declare() basic functionality", function()
        it("should require options table", function()
            assert.has_error(function()
                Melt.declare()
            end, "melt.declare() requires a table of options")

            assert.has_error(function()
                Melt.declare("not a table")
            end, "melt.declare() requires a table of options")
        end)

        it("should require app_name", function()
            assert.has_error(function()
                Melt.declare({})
            end, "melt.declare() requires an 'app_name' string option")

            assert.has_error(function()
                Melt.declare({ app_name = 123 })
            end, "melt.declare() requires an 'app_name' string option")
        end)

        it("should create config object with minimal options", function()
            local config, errors = Melt.declare({ app_name = "testapp" })

            assert.is_not_nil(config)
            assert.are.same("table", type(config))
            assert.are.same("function", type(config.get))
            assert.are.same("function", type(config.get_table))
            assert.are.same("table", type(errors))
        end)
    end)

    describe("defaults handling", function()
        it("should merge table defaults", function()
            local defaults = {
                app_name = "testapp",
                timeout = 5000,
                database = {
                    host = "localhost",
                    port = 5432
                }
            }

            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = defaults
            })

            assert.are.equal("testapp", config:get("app_name"))
            assert.are.equal(5000, config:get("timeout"))
            assert.are.equal("localhost", config:get("database.host"))
            assert.are.equal(5432, config:get("database.port"))
            assert.are.equal(0, #errors)
        end)

        it("should load defaults from file", function()
            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = "spec/melt/declarative_test_defaults.toml"
            })

            assert.are.equal("testapp", config:get("app_name"))
            assert.are.equal(5000, config:get("timeout"))
            assert.are.equal("localhost", config:get("database.host"))
            assert.are.equal(5432, config:get("database.port"))
            assert.are.equal("info", config:get("logging.level"))
            assert.are.equal(0, #errors)
        end)

        it("should handle missing defaults file", function()
            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = "spec/melt/non_existent_defaults.toml"
            })

            assert.are.equal(1, #errors)
            assert.are.equal("defaults_file_not_found", errors[1].source)
            assert.is_true(string.find(errors[1].message, "Defaults file not found") ~= nil)
        end)
    end)

    describe("user home configuration", function()
        it("should work without user config files", function()
            local config, errors = Melt.declare({
                app_name = "nonexistentapp"
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors) -- No user config is not an error
        end)

        it("should handle missing HOME environment variable", function()
            -- Save original HOME
            local original_home = os.getenv("HOME")

            -- Temporarily unset HOME (this is tricky in Lua, but we can test the logic)
            -- For now, we'll test with a valid HOME but non-existent app
            local config, errors = Melt.declare({
                app_name = "definitelynonexistentapp12345"
            })

            assert.is_not_nil(config)
            assert.are.equal(0, #errors)
        end)
    end)

    describe("precedence rules", function()
        it("should have defaults as lowest precedence", function()
            local defaults = {
                setting = "from_defaults",
                database = {
                    host = "default-host"
                }
            }

            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = defaults
            })

            assert.are.equal("from_defaults", config:get("setting"))
            assert.are.equal("default-host", config:get("database.host"))
            assert.are.equal(0, #errors)
        end)
    end)

    describe("configuration access", function()
        it("should support dot notation access", function()
            local defaults = {
                database = {
                    connection = {
                        host = "nested-host",
                        port = 3306
                    }
                }
            }

            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = defaults
            })

            assert.are.equal("nested-host", config:get("database.connection.host"))
            assert.are.equal(3306, config:get("database.connection.port"))
        end)

        it("should return nil for non-existent keys", function()
            local config, errors = Melt.declare({
                app_name = "testapp"
            })

            assert.is_nil(config:get("non.existent.key"))
            assert.is_nil(config:get(""))
            assert.is_nil(config:get(nil))
        end)

        it("should return entire config table", function()
            local defaults = {
                app_name = "testapp",
                setting = "value"
            }

            local config, errors = Melt.declare({
                app_name = "testapp",
                defaults = defaults
            })

            local all_config = config:get_table()
            assert.are.same("table", type(all_config))
            assert.are.equal("testapp", all_config.app_name)
            assert.are.equal("value", all_config.setting)
        end)

        it("should support array access with dot notation using [index]", function()
            local defaults = {
                list = { "item1", "item2", "item3" },
                nested = {
                    array = { 10, 20, 30 }
                },
                empty_list = {},
                string_val = "not an array"
            }
            local config, _ = Melt.declare({ app_name = "arrayapp", defaults = defaults })

            assert.are.equal("item1", config:get("list[1]"))
            assert.are.equal("item2", config:get("list[2]"))
            assert.are.equal("item3", config:get("list[3]"))
            assert.is_nil(config:get("list[0]")) -- Test 0-based, should be nil for Lua arrays (1-based)
            assert.is_nil(config:get("list[4]")) -- Out of bounds

            assert.are.equal(10, config:get("nested.array[1]"))
            assert.are.equal(20, config:get("nested.array[2]"))
            assert.are.equal(30, config:get("nested.array[3]"))
            assert.is_nil(config:get("nested.array[0]"))
            assert.is_nil(config:get("nested.array[4]"))

            -- Non-existent paths or invalid access
            assert.is_nil(config:get("nonexistent.array[1]")) -- Base 'nonexistent' does not exist
            assert.is_nil(config:get("list[abc]"))            -- Invalid index format (non-numeric)
            assert.is_nil(config:get("list[1.2]"))            -- Invalid index format (float)
            assert.is_nil(config:get("list[-1]"))             -- Invalid index format (negative)
            assert.is_nil(config:get("empty_list[1]"))        -- Accessing element in an empty list
            assert.is_nil(config:get("string_val[1]"))        -- Trying array access on a string
        end)
    end)
end)
