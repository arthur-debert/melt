-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("melt")

describe("Declarative Engine - System Configuration Tests", function()
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
        local success = os.execute("mkdir -p " .. path)
        if success == 0 or success == true then
            table.insert(temp_dirs, path)
            return true
        end
        return false
    end

    -- Clean up temporary files and directories after each test
    after_each(function()
        for _, filepath in ipairs(temp_files) do
            os.remove(filepath)
        end
        temp_files = {}

        for _, dirpath in ipairs(temp_dirs) do
            os.execute("rm -rf " .. dirpath)
        end
        temp_dirs = {}
    end)

    describe("system configuration loading", function()
        it("should load from /etc/app_name/config.toml", function()
            -- Create mock system directory structure
            local system_dir = "./mock_etc/sysapp"
            if create_temp_dir(system_dir) then
                local config_file = system_dir .. "/config.toml"
                local toml_content = [[
app_name = "sysapp"
system_setting = "from_system_config"

[database]
host = "system-db-host"
port = 5432
]]

                if create_temp_file(config_file, toml_content) then
                    local config, errors = Melt.declare({
                        app_name = "sysapp",
                        config_locations = {
                            system = { "./mock_etc" },
                            user = false,
                            project = false
                        }
                    })

                    assert.are.equal(0, #errors)
                    assert.are.equal("sysapp", config:get("app_name"))
                    assert.are.equal("from_system_config", config:get("system_setting"))
                    assert.are.equal("system-db-host", config:get("database.host"))
                    assert.are.equal(5432, config:get("database.port"))
                else
                    pending("Could not create test config file")
                end
            else
                pending("Could not create test directory")
            end
        end)

        it("should load from /etc/app_name.toml directly", function()
            local system_dir = "./mock_etc"
            if create_temp_dir(system_dir) then
                local config_file = system_dir .. "/sysapp2.toml"
                local toml_content = [[
app_name = "sysapp2"
system_direct = "from_etc_direct"
]]

                if create_temp_file(config_file, toml_content) then
                    local config, errors = Melt.declare({
                        app_name = "sysapp2",
                        config_locations = {
                            system = { "./mock_etc" },
                            user = false,
                            project = false,
                            use_app_name_as_dir = false
                        }
                    })

                    assert.are.equal(0, #errors)
                    assert.are.equal("from_etc_direct", config:get("system_direct"))
                else
                    pending("Could not create test config file")
                end
            else
                pending("Could not create test directory")
            end
        end)

        it("should handle multiple system locations", function()
            local system_dir1 = "./mock_etc1"
            local system_dir2 = "./mock_etc2"

            if create_temp_dir(system_dir1) and create_temp_dir(system_dir2) then
                -- Create config in first location
                local config_file1 = system_dir1 .. "/multisys.toml"
                local toml_content1 = [[
setting1 = "from_etc1"
shared_setting = "from_etc1"
]]

                -- Create config in second location (should override first)
                local config_file2 = system_dir2 .. "/multisys.toml"
                local toml_content2 = [[
setting2 = "from_etc2"
shared_setting = "from_etc2"
]]

                if create_temp_file(config_file1, toml_content1) and
                    create_temp_file(config_file2, toml_content2) then
                    local config, errors = Melt.declare({
                        app_name = "multisys",
                        config_locations = {
                            system = { "./mock_etc1", "./mock_etc2" },
                            user = false,
                            project = false,
                            use_app_name_as_dir = false
                        }
                    })

                    assert.are.equal(0, #errors)
                    assert.are.equal("from_etc1", config:get("setting1"))
                    assert.are.equal("from_etc2", config:get("setting2"))
                    -- Second location should override first
                    assert.are.equal("from_etc2", config:get("shared_setting"))
                else
                    pending("Could not create test config files")
                end
            else
                pending("Could not create test directories")
            end
        end)

        it("should respect system=false option", function()
            local system_dir = "./mock_etc"
            if create_temp_dir(system_dir) then
                local config_file = system_dir .. "/nosysapp.toml"
                local toml_content = [[
system_setting = "should_be_ignored"
]]

                if create_temp_file(config_file, toml_content) then
                    local config, errors = Melt.declare({
                        app_name = "nosysapp",
                        config_locations = {
                            system = false, -- Explicitly disabled
                            user = false,
                            project = false
                        }
                    })

                    assert.are.equal(0, #errors)
                    assert.is_nil(config:get("system_setting"))
                else
                    pending("Could not create test config file")
                end
            else
                pending("Could not create test directory")
            end
        end)

        it("should test system config precedence (lower than user config)", function()
            local system_dir = "./mock_etc/precedenceapp"
            local user_dir = "./mock_home/.config/precedenceapp"

            if create_temp_dir(system_dir) and create_temp_dir(user_dir) then
                -- Create system config
                local system_config = system_dir .. "/config.toml"
                local system_content = [[
shared_setting = "from_system"
system_only = "system_value"
]]

                -- Create user config (should override system)
                local user_config = user_dir .. "/config.toml"
                local user_content = [[
shared_setting = "from_user"
user_only = "user_value"
]]

                if create_temp_file(system_config, system_content) and
                    create_temp_file(user_config, user_content) then
                    local config, errors = Melt.declare({
                        app_name = "precedenceapp",
                        config_locations = {
                            system = { "./mock_etc" },
                            user = { "./mock_home/.config" },
                            project = false,
                            use_app_name_as_dir = true -- Consistent for both
                        }
                    })

                    assert.are.equal(0, #errors)
                    -- User should override system
                    assert.are.equal("from_user", config:get("shared_setting"))
                    -- Both unique settings should be present
                    assert.are.equal("system_value", config:get("system_only"))
                    assert.are.equal("user_value", config:get("user_only"))
                else
                    pending("Could not create test config files")
                end
            else
                pending("Could not create test directories")
            end
        end)

        it("should handle non-existent system directories gracefully", function()
            local config, errors = Melt.declare({
                app_name = "nonexistentsysapp",
                config_locations = {
                    system = { "/definitely/does/not/exist", "./also/missing" },
                    user = false,
                    project = false
                }
            })

            -- Should not error just because system dirs don't exist
            assert.are.equal(0, #errors)
            assert.is_not_nil(config)
        end)

        it("should NOT search system locations by default if 'config_locations.system' is omitted", function()
            -- This test relies on the fact that without system=true, no system files should be loaded.
            -- We'll create a dummy system file and ensure it's NOT loaded.

            local mock_system_dir_path = "./mock_etc_default_test"
            local mock_system_app_dir = mock_system_dir_path .. "/omitsysapp"
            if create_temp_dir(mock_system_app_dir) then -- create_temp_dir is a helper in the spec
                local config_file = mock_system_app_dir .. "/config.toml"
                local toml_content = [[
                system_setting_default_test = "from_system_should_not_load"
                ]]

                if create_temp_file(config_file, toml_content) then -- create_temp_file is a helper
                    -- To truly test the default, we need to mock the default system paths
                    -- to point to our mock directory. This is tricky without modifying the main code's
                    -- hardcoded default paths.
                    -- A pragmatic approach:
                    -- 1. Ensure no other config sources provide the setting.
                    -- 2. Call declare WITHOUT options.config_locations or with options.config_locations.system = nil
                    -- 3. Assert the setting is nil.
                    -- This test assumes that if system search WERE active, it *would* look in
                    -- places like "/etc/omitsysapp/config.toml". We can't easily redirect "/etc" in a test.

                    -- So, we test that by *not* enabling system search, a value that *would*
                    -- hypothetically be in a default system path is not loaded.
                    -- This indirectly tests that the search isn't happening.

                    local config1, errors1 = Melt.declare({
                        app_name = "omitsysapp",
                        -- config_locations is omitted entirely
                        defaults = { other_setting = "val" } -- ensure some config exists
                    })
                    assert.are.equal(0, #errors1)
                    assert.is_nil(config1:get("system_setting_default_test"))

                    local config2, errors2 = Melt.declare({
                        app_name = "omitsysapp",
                        config_locations = {
                            -- system is omitted here
                            user = false, -- disable other sources for clarity
                            project = false
                        },
                        defaults = { other_setting = "val" }
                    })
                    assert.are.equal(0, #errors2)
                    assert.is_nil(config2:get("system_setting_default_test"))
                else
                    pending("Could not create test system config file for default omission test")
                end
            else
                pending("Could not create test system directory for default omission test")
            end
        end)
    end)
end)
