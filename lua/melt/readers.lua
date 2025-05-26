-- This file is kept for backward compatibility
-- It re-exports the functions from the modular reader implementation

-- Import all functions from the new readers module
local readers = require("lua.melt.readers.init")

-- Export all functions
return readers
