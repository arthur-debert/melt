-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("lua.melt")

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

                print("Errors:", #errors)
                for i, err in ipairs(errors) do
                    print("Error " .. i .. ":", err.message, err.source)
                end

                print("only_in_user value:", config:get("only_in_user"))
                print("Config data:")
                local config_table = config:get_table()
                if config_table then
                    for k, v in pairs(config_table) do
                        print("  " .. k .. ":", v)
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
end)
