-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("lua.melt")

describe("Declarative Engine - Error Handling Tests", function()
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

    describe("file loading error scenarios", function()
        it("should report error for missing defaults file", function()
            local config, errors = Melt.declare({
                app_name = "errorapp",
                defaults = "./non_existent_defaults.toml",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = false
            })

            assert.are.equal(1, #errors)
            assert.are.equal("defaults", errors[1].source)
            assert.is_true(string.find(errors[1].message, "Could not load defaults file") ~= nil)
            assert.is_not_nil(config) -- Should still return config object
        end)

        it("should report error for missing custom path file", function()
            local config, errors = Melt.declare({
                app_name = "errorapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = {
                        "./missing_config.toml",
                        "./another_missing.json"
                    }
                },
                env = false,
                cmd_args = false
            })

            assert.are.equal(2, #errors)
            for _, err in ipairs(errors) do
                assert.are.equal("custom_path", err.source)
                assert.is_true(string.find(err.message, "Could not load custom configuration file") ~= nil)
                assert.is_not_nil(err.path)
            end
        end)

        it("should handle malformed TOML files gracefully", function()
            local temp_dir = "./test_error_dir"
            if create_temp_dir(temp_dir) then
                local malformed_toml = temp_dir .. "/malformed.toml"
                local bad_content = [[
# This is malformed TOML
[section]
key = unquoted_string_value
another_key = [1,2,3 # unclosed array
                ]]

                if create_temp_file(malformed_toml, bad_content) then
                    local config, errors = Melt.declare({
                        app_name = "errorapp",
                        config_locations = {
                            system = false,
                            user = false,
                            project = false,
                            custom_paths = { malformed_toml }
                        },
                        env = false,
                        cmd_args = false
                    })

                    -- The current implementation returns empty table for malformed files
                    -- This should ideally generate an error, but currently doesn't
                    assert.is_not_nil(config)
                    -- Note: This test documents current behavior
                    -- In an improved implementation, we'd expect an error here
                else
                    pending("Could not create malformed test file")
                end
            else
                pending("Could not create test directory")
            end
        end)

        it("should handle malformed JSON files gracefully", function()
            local temp_dir = "./test_error_dir"
            if create_temp_dir(temp_dir) then
                local malformed_json = temp_dir .. "/malformed.json"
                local bad_content = [[
{
  "key": "value",
  "broken": true,
  "missing_closing_brace": false
                ]]

                if create_temp_file(malformed_json, bad_content) then
                    local config, errors = Melt.declare({
                        app_name = "errorapp",
                        config_locations = {
                            system = false,
                            user = false,
                            project = false,
                            custom_paths = { malformed_json }
                        },
                        env = false,
                        cmd_args = false
                    })

                    assert.is_not_nil(config)
                    -- Current implementation silently ignores malformed files
                    -- This should ideally report an error
                else
                    pending("Could not create malformed test file")
                end
            else
                pending("Could not create test directory")
            end
        end)
    end)

    describe("error message quality", function()
        it("should provide meaningful error messages with context", function()
            local config, errors = Melt.declare({
                app_name = "contextapp",
                defaults = "./missing_with_specific_path.toml",
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = false
            })

            assert.are.equal(1, #errors)
            local err = errors[1]
            assert.are.equal("defaults", err.source)
            assert.is_true(string.find(err.message, "missing_with_specific_path.toml") ~= nil)
        end)

        it("should include file path in custom path errors", function()
            local missing_file = "./very_specific_missing_file.yaml"

            local config, errors = Melt.declare({
                app_name = "pathapp",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = { missing_file }
                },
                env = false,
                cmd_args = false
            })

            assert.are.equal(1, #errors)
            local err = errors[1]
            assert.are.equal("custom_path", err.source)
            assert.are.equal(missing_file, err.path)
            assert.is_true(string.find(err.message, missing_file) ~= nil)
        end)
    end)

    describe("error recovery behavior", function()
        it("should continue processing after encountering errors", function()
            local temp_dir = "./test_recovery_dir"
            if create_temp_dir(temp_dir) then
                -- Create a valid file
                local valid_file = temp_dir .. "/valid.toml"
                local valid_content = [[
valid_setting = "success"
                ]]

                if create_temp_file(valid_file, valid_content) then
                    local config, errors = Melt.declare({
                        app_name = "recoveryapp",
                        defaults = "./missing_defaults.toml", -- This will error
                        config_locations = {
                            system = false,
                            user = false,
                            project = false,
                            custom_paths = {
                                "./missing_custom.toml", -- This will error
                                valid_file               -- This should succeed
                            }
                        },
                        env = false,
                        cmd_args = false
                    })

                    assert.are.equal(2, #errors) -- Two errors from missing files
                    -- But the valid file should still be loaded
                    assert.are.equal("success", config:get("valid_setting"))
                else
                    pending("Could not create valid test file")
                end
            else
                pending("Could not create test directory")
            end
        end)

        it("should not crash on invalid input types", function()
            local config, errors = Melt.declare({
                app_name = "typeapp",
                defaults = 12345, -- Invalid type (should be table or string)
                config_locations = {
                    system = false,
                    user = false,
                    project = false
                },
                env = false,
                cmd_args = false
            })

            -- Should not crash and should return a config object
            assert.is_not_nil(config)
            assert.is_not_nil(errors)
            -- Current implementation may or may not report this as an error
            -- But it should at least not crash
        end)
    end)

    describe("edge case error scenarios", function()
        it("should handle permission denied scenarios gracefully", function()
            -- This test is difficult to implement portably
            -- but documents the expected behavior
            pending("Permission testing requires platform-specific setup")
        end)

        it("should handle circular file references gracefully", function()
            -- This would be relevant if file includes were supported
            pending("Circular reference handling not yet implemented")
        end)

        it("should handle very large config files gracefully", function()
            -- Test with a reasonably large config to ensure no memory issues
            local temp_dir = "./test_large_dir"
            if create_temp_dir(temp_dir) then
                local large_file = temp_dir .. "/large.toml"
                local large_content = ""

                -- Generate a large but valid TOML file
                for i = 1, 1000 do
                    large_content = large_content .. string.format("key_%d = \"value_%d\"\n", i, i)
                end

                if create_temp_file(large_file, large_content) then
                    local config, errors = Melt.declare({
                        app_name = "largeapp",
                        config_locations = {
                            system = false,
                            user = false,
                            project = false,
                            custom_paths = { large_file }
                        },
                        env = false,
                        cmd_args = false
                    })

                    assert.are.equal(0, #errors)
                    assert.are.equal("value_500", config:get("key_500"))
                    assert.are.equal("value_1000", config:get("key_1000"))
                else
                    pending("Could not create large test file")
                end
            else
                pending("Could not create test directory")
            end
        end)
    end)

    describe("error aggregation", function()
        it("should collect multiple errors without stopping", function()
            local config, errors = Melt.declare({
                app_name = "multiapp",
                defaults = "./missing1.toml",
                config_locations = {
                    system = false,
                    user = false,
                    project = false,
                    custom_paths = {
                        "./missing2.toml",
                        "./missing3.json",
                        "./missing4.yaml"
                    }
                },
                env = false,
                cmd_args = false
            })

            -- Should have collected 4 errors total
            assert.are.equal(4, #errors)

            -- Verify error sources
            local error_sources = {}
            for _, err in ipairs(errors) do
                table.insert(error_sources, err.source)
            end

            assert.is_true(table.concat(error_sources, ","):find("defaults") ~= nil)
            assert.is_true(table.concat(error_sources, ","):find("custom_path") ~= nil)
        end)
    end)
end)
