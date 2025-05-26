-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil

-- Main test suite for the lua-melt library
-- This file is a high-level coordinator that requires all the individual test modules

describe("lua-melt Library", function()
  -- Each test module will be automatically loaded and run by busted
  -- when present in the spec directory
  
  -- To run all tests: busted
  -- To run a specific test file: busted spec/melt/utils_spec.lua
  
  -- The following tests are now in separate files:
  -- 1. utils.deep_merge - spec/melt/utils_spec.lua
  -- 2. Reader Functions - spec/melt/reader_functions_spec.lua
  -- 3. Config Object and Chained API - spec/melt/config_object_spec.lua
  -- 4. Iterative API - spec/melt/iterative_api_spec.lua
  -- 5. Getter Methods - spec/melt/getter_methods_spec.lua
  -- 6. Precedence Rules - spec/melt/precedence_spec.lua
end)
