-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

describe("Library Loading Failure Tests", function()
    local original_require
    local temp_files = {}

    before_each(function()
        original_require = _G.require
        temp_files = {}
    end)

    after_each(function()
        _G.require = original_require
        -- Clean up any temporary files
        for _, filepath in ipairs(temp_files) do
            os.remove(filepath)
        end
        temp_files = {}
    end)

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

    describe("JSON library loading failure", function()
        it("should handle missing dkjson library gracefully", function()
            -- Mock require to fail for dkjson
            _G.require = function(module_name)
                if module_name == "dkjson" then
                    error("module 'dkjson' not found")
                else
                    return original_require(module_name)
                end
            end

            -- Reload the json reader to trigger the library loading failure
            package.loaded["lua.melt.readers.json"] = nil
            local json_reader = require("lua.melt.readers.json")

            -- Create a test JSON file
            local json_file = "test_library_failure.json"
            local json_content = '{"test": "value"}'

            if create_temp_file(json_file, json_content) then
                -- Should return empty table when library is not available
                local result = json_reader.read_json_file(json_file)
                assert.are.same({}, result)
            else
                pending("Could not create test JSON file")
            end
        end)
    end)

    describe("YAML library loading failure", function()
        it("should handle missing lyaml library gracefully", function()
            -- Mock require to fail for lyaml
            _G.require = function(module_name)
                if module_name == "lyaml" then
                    error("module 'lyaml' not found")
                else
                    return original_require(module_name)
                end
            end

            -- Reload the yaml reader to trigger the library loading failure
            package.loaded["lua.melt.readers.yaml"] = nil
            local yaml_reader = require("lua.melt.readers.yaml")

            -- Create a test YAML file
            local yaml_file = "test_library_failure.yaml"
            local yaml_content = "test: value\narray:\n  - item1\n  - item2"

            if create_temp_file(yaml_file, yaml_content) then
                -- Should return empty table when library is not available
                local result = yaml_reader.read_yaml_file(yaml_file)
                assert.are.same({}, result)
            else
                pending("Could not create test YAML file")
            end
        end)
    end)

    describe("TOML library loading failure", function()
        it("should handle missing toml library gracefully", function()
            -- Mock require to fail for toml
            _G.require = function(module_name)
                if module_name == "toml" then
                    error("module 'toml' not found")
                else
                    return original_require(module_name)
                end
            end

            -- Reload the toml reader to trigger the library loading failure
            package.loaded["lua.melt.readers.toml"] = nil
            local toml_reader = require("lua.melt.readers.toml")

            -- Create a test TOML file
            local toml_file = "test_library_failure.toml"
            local toml_content = 'test = "value"\n[section]\nkey = "nested_value"'

            if create_temp_file(toml_file, toml_content) then
                -- Should return empty table when library is not available
                local result = toml_reader.read_toml_file(toml_file)
                assert.are.same({}, result)
            else
                pending("Could not create test TOML file")
            end
        end)
    end)

    describe("Library loading failures in declarative config", function()
        it("should handle JSON library failure in declarative config", function()
            -- Mock require to fail for dkjson
            _G.require = function(module_name)
                if module_name == "dkjson" then
                    error("module 'dkjson' not found")
                else
                    return original_require(module_name)
                end
            end

            -- Reload necessary modules
            package.loaded["lua.melt.readers.json"] = nil
            package.loaded["lua.melt.readers.init"] = nil
            package.loaded["lua.melt.readers"] = nil

            local Melt = require("lua.melt")

            -- Create a test JSON config file
            local json_config = "declarative_library_test.json"
            local json_content = '{"app_setting": "from_json"}'

            if create_temp_file(json_config, json_content) then
                local config, errors = Melt.declare({
                    app_name = "libtest",
                    config_locations = {
                        system = false,
                        user = false,
                        project = false,
                        custom_paths = { "." }
                    }
                })

                -- Should still work but not load the JSON file
                assert.is_not_nil(config)
                assert.is_nil(config:get("app_setting"))
            else
                pending("Could not create test JSON file")
            end
        end)

        it("should handle YAML library failure in declarative config", function()
            -- Mock require to fail for lyaml
            _G.require = function(module_name)
                if module_name == "lyaml" then
                    error("module 'lyaml' not found")
                else
                    return original_require(module_name)
                end
            end

            -- Reload necessary modules
            package.loaded["lua.melt.readers.yaml"] = nil
            package.loaded["lua.melt.readers.init"] = nil
            package.loaded["lua.melt.readers"] = nil

            local Melt = require("lua.melt")

            -- Create a test YAML config file
            local yaml_config = "declarative_library_test.yaml"
            local yaml_content = "app_setting: from_yaml\nnested:\n  value: test"

            if create_temp_file(yaml_config, yaml_content) then
                local config, errors = Melt.declare({
                    app_name = "libtest",
                    config_locations = {
                        system = false,
                        user = false,
                        project = false,
                        custom_paths = { "." }
                    }
                })

                -- Should still work but not load the YAML file
                assert.is_not_nil(config)
                assert.is_nil(config:get("app_setting"))
            else
                pending("Could not create test YAML file")
            end
        end)

        it("should handle TOML library failure in declarative config", function()
            -- Mock require to fail for toml
            _G.require = function(module_name)
                if module_name == "toml" then
                    error("module 'toml' not found")
                else
                    return original_require(module_name)
                end
            end

            -- Reload necessary modules
            package.loaded["lua.melt.readers.toml"] = nil
            package.loaded["lua.melt.readers.init"] = nil
            package.loaded["lua.melt.readers"] = nil

            local Melt = require("lua.melt")

            -- Create a test TOML config file
            local toml_config = "declarative_library_test.toml"
            local toml_content = 'app_setting = "from_toml"\n[nested]\nvalue = "test"'

            if create_temp_file(toml_config, toml_content) then
                local config, errors = Melt.declare({
                    app_name = "libtest",
                    config_locations = {
                        system = false,
                        user = false,
                        project = false,
                        custom_paths = { "." }
                    }
                })

                -- Should still work but not load the TOML file
                assert.is_not_nil(config)
                assert.is_nil(config:get("app_setting"))
            else
                pending("Could not create test TOML file")
            end
        end)
    end)

    describe("File read errors", function()
        it("should handle file permission errors gracefully", function()
            local json_reader = require("lua.melt.readers.json")

            -- Try to read a file that doesn't exist
            local result = json_reader.read_json_file("/nonexistent/path/file.json")
            assert.are.same({}, result)
        end)

        it("should handle malformed files gracefully", function()
            local json_reader = require("lua.melt.readers.json")

            -- Create a malformed JSON file
            local malformed_file = "malformed_test.json"
            local malformed_content = '{"incomplete": "json"' -- Missing closing brace

            if create_temp_file(malformed_file, malformed_content) then
                local result = json_reader.read_json_file(malformed_file)
                assert.are.same({}, result)
            else
                pending("Could not create malformed test file")
            end
        end)
    end)
end)
