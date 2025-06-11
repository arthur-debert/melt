-- This module sets up the logging system for the application.
-- It is responsible for creating the root logger which has:
-- a debug handler that outputs all messages to a file and a console handlker that
-- only outputs messages with a level of warn or higher.

-- COMMENTED OUT: Removing old logging lib (lual)
-- local lual = require("lual")

local M = {}

M.setup_logging = function()
    -- COMMENTED OUT: Removing old logging functionality
    -- -- in this setup the root logger has outptus and pipelines defined for debug
    -- -- messages
    -- lual.config({
    --     -- this has to be the most permissive level, so that pipelines can filter
    --     level = "debug",
    --     pipelines = {
    --         { level = "debug", output = { type = lual.file, path = "/tmp/melt.log" } },
    --         { level = "debug", output = { type = lual.console },                     presenters = { lual.color } }
    --     },
    --     command_line_verbosity = {
    --         v = lual.debug
    --     }
    -- })
    -- -- there is no need to return a logger, any logger created will have
    -- -- the root logger as parent
    -- lual.logger.debug("Logging setup complete at %Y-%m-%d %H:%M:%S"))
    -- TODO: Will be replaced with new logging setup in Stage 2
    print("Logging setup placeholder - old logging removed")
    return true
end

return M
