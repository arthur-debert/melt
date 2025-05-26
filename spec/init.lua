-- This file is loaded by busted before running tests (as configured in .busted)
-- It makes busted functions available globally for all spec files

-- Define globals provided by busted that luacheck might complain about
_G.describe = describe
_G.it = it
_G.before_each = before_each
_G.after_each = after_each
_G.setup = setup
_G.teardown = teardown

-- Create empty assert.are table if it doesn't exist
if not assert.are then
  assert.are = {}
  assert.are.equal = assert.equal
  assert.are.same = assert.same
end

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are