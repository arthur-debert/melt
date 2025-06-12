-- Debug test for declarative engine
local Melt = require("lua.melt")
local logger = require("lual").logger()

describe("Debug Declarative Engine", function()
    it("should debug user config loading", function()
        local home = os.getenv("HOME")
        logger.info("HOME:", home)

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
            logger.info("Created file:", config_file)

            -- Check if file exists
            local check_file = io.open(config_file, "r")
            if check_file then
                logger.info("File exists and is readable")
                local content = check_file:read("*all")
                logger.info("File content:", content)
                check_file:close()
            else
                logger.info("File does not exist or is not readable")
            end

            local config, errors = Melt.declare({
                app_name = "testappdebug"
            })

            logger.info("Errors:", #errors)
            for i, err in ipairs(errors) do
                logger.info("Error " .. i .. ":", err.message, err.source)
            end

            local config_table = config:get_table()
            logger.info("Config data has keys:", config_table and "yes" or "no")
            if config_table then
                for k, v in pairs(config_table) do
                    logger.info("  " .. k .. ":", v)
                end
            end
            logger.info("debug_setting:", config:get("debug_setting"))

            -- Clean up
            os.remove(config_file)

            assert.are.equal("debug_value", config:get("debug_setting"))
        else
            pending("Could not create test file")
        end
    end)
end)
