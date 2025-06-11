-- Debug test for declarative engine
local Melt = require("lua.melt")

describe("Debug Declarative Engine", function()
    it("should debug user config loading", function()
        local home = os.getenv("HOME")
        print("HOME:", home)

        if not home then
            pending("HOME environment variable not set")
            return
        end

        local config_file = home .. "/.testappdebug.toml"
        local toml_content = [[
app_name = "testappdebug"
debug_setting = "debug_value"
]]

        -- Create the file
        local file = io.open(config_file, "w")
        if file then
            file:write(toml_content)
            file:close()
            print("Created file:", config_file)

            -- Check if file exists
            local check_file = io.open(config_file, "r")
            if check_file then
                print("File exists and is readable")
                local content = check_file:read("*all")
                print("File content:", content)
                check_file:close()
            else
                print("File does not exist or is not readable")
            end

            local config, errors = Melt.declare({
                app_name = "testappdebug"
            })

            print("Errors:", #errors)
            for i, err in ipairs(errors) do
                print("Error " .. i .. ":", err.message, err.source)
            end

            local config_table = config:get_table()
            print("Config data has keys:", config_table and "yes" or "no")
            if config_table then
                for k, v in pairs(config_table) do
                    print("  " .. k .. ":", v)
                end
            end
            print("debug_setting:", config:get("debug_setting"))

            -- Clean up
            os.remove(config_file)

            assert.are.equal("debug_value", config:get("debug_setting"))
        else
            pending("Could not create test file")
        end
    end)
end)
