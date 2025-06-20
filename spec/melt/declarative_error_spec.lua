-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("melt")

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
            assert.are.equal("defaults_file_not_found", errors[1].source)                    -- Updated source
            assert.is_true(string.find(errors[1].message, "Defaults file not found") ~= nil) -- Updated message
            assert.is_not_nil(config)                                                        -- Should still return config object
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
                assert.are.equal("custom_file_not_found", err.source)                                  -- Updated source
                assert.is_true(string.find(err.message, "Custom configuration file not found") ~= nil) -- Updated message
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

                    assert.is_not_nil(config) -- Config object should still be returned
                    assert.are.equal(1, #errors, "Should have one error for malformed TOML")

                    local err = errors[1]
                    assert.are.equal("custom_file", err.source, "Error source should be custom_file")
                    assert.are.equal(malformed_toml, err.path, "Error path should be the malformed file path")
                    assert.is_true(string.find(err.message, "Failed to parse " .. malformed_toml) ~= nil,
                        "Error message should indicate parsing failure and filename")
                    -- Check for a snippet of a typical TOML parse error message if possible,
                    -- e.g., "expected '='" or "invalid table header"
                    -- This depends on the actual error message from the toml parser.
                    -- For example, if it contains "Expected a key-value pair", we could check:
                    -- assert.is_true(string.find(err.message, "Expected a key-value pair", 1, true) ~= nil, "Error message detail missing")
                    -- For now, the generic "Failed to parse" is checked.
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

                    assert.is_not_nil(config) -- Config object should still be returned
                    assert.are.equal(1, #errors, "Should have one error for malformed JSON")

                    local err = errors[1]
                    assert.are.equal("custom_file", err.source, "Error source should be custom_file")
                    assert.are.equal(malformed_json, err.path, "Error path should be the malformed file path")
                    assert.is_true(string.find(err.message, "Failed to parse " .. malformed_json) ~= nil,
                        "Error message should indicate parsing failure and filename")
                    -- Example check for dkjson error (errors might vary)
                    -- assert.is_true(string.find(err.message, "expected '}'", 1, true) ~= nil, "Error message detail missing")
                else
                    pending("Could not create malformed test file")
                end
            else
                pending("Could not create test directory")
            end
        end)
    end)

    describe("error message quality", function()
        it("should provide meaningful error messages with context for file not found", function()
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
            assert.are.equal("defaults_file_not_found", err.source)                    -- Updated source
            assert.is_true(string.find(err.message, "Defaults file not found") ~= nil) -- Updated message
            assert.is_true(string.find(err.message, "missing_with_specific_path.toml") ~= nil)
        end)

        it("should include file path in custom path not found errors", function()
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
            assert.are.equal("custom_file_not_found", err.source)                                  -- Updated source
            assert.are.equal(missing_file, err.path)
            assert.is_true(string.find(err.message, "Custom configuration file not found") ~= nil) -- Updated message
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

        it("should report error for invalid numeric type in options.defaults", function()
            local config, errors = Melt.declare({
                app_name = "typeerrorapp",
                defaults = 12345, -- Invalid type
                config_locations = { system = false, user = false, project = false },
                env = false,
                cmd_args = false
            })

            assert.is_not_nil(config) -- Should still return a config object
            assert.are.equal(1, #errors)
            if #errors > 0 then
                local err = errors[1]
                assert.are.equal("options_validation", err.source)
                assert.are.equal("defaults", err.key)
                assert.is_true(string.find(err.message, "Invalid type for 'defaults'.", 1, true) ~= nil)
                assert.is_true(string.find(err.message, "Expected table or string path, got number.", 1, true) ~= nil)
            end
        end)

        it("should report error for boolean type in options.defaults", function()
            local config, errors = Melt.declare({
                app_name = "typeerrorappbool",
                defaults = true, -- Invalid type
                config_locations = { system = false, user = false, project = false },
                env = false,
                cmd_args = false
            })

            assert.is_not_nil(config)
            assert.are.equal(1, #errors)
            if #errors > 0 then
                local err = errors[1]
                assert.are.equal("options_validation", err.source)
                assert.are.equal("defaults", err.key)
                assert.is_true(string.find(err.message, "Invalid type for 'defaults'.", 1, true) ~= nil)
                assert.is_true(string.find(err.message, "Expected table or string path, got boolean.", 1, true) ~= nil)
            end
        end)
    end)

    describe("edge case error scenarios", function()
        it("should handle permission denied scenarios gracefully", function()
            local temp_dir = "./test_permission_dir"
            if create_temp_dir(temp_dir) then
                local restricted_file = temp_dir .. "/restricted.toml"
                local content = "restricted_setting = 'should_not_load'"

                if create_temp_file(restricted_file, content) then
                    -- Remove read permissions (chmod 000)
                    local chmod_result = os.execute("chmod 000 " .. restricted_file)

                    if chmod_result == 0 or chmod_result == true then
                        local config, errors = Melt.declare({
                            app_name = "permissionapp",
                            config_locations = {
                                system = false,
                                user = false,
                                project = false,
                                custom_paths = { restricted_file }
                            },
                            env = false,
                            cmd_args = false
                        })

                        -- Should have an error due to file being inaccessible
                        -- (permission denied is treated like file not found)
                        assert.are.equal(1, #errors)
                        local err = errors[1]
                        assert.are.equal("custom_file_not_found", err.source)
                        assert.are.equal(restricted_file, err.path)
                        assert.is_true(string.find(err.message, "Custom configuration file not found") ~= nil)

                        -- Config should still be created (graceful degradation)
                        assert.is_not_nil(config)
                        assert.is_nil(config:get("restricted_setting"))

                        -- Restore permissions for cleanup
                        os.execute("chmod 644 " .. restricted_file)
                    else
                        pending("Cannot modify file permissions on this system")
                    end
                else
                    pending("Could not create test file")
                end
            else
                pending("Could not create test directory")
            end
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

            assert.is_true(table.concat(error_sources, ","):find("defaults_file_not_found") ~= nil)
            assert.is_true(table.concat(error_sources, ","):find("custom_file_not_found") ~= nil)
        end)
    end)
end)
