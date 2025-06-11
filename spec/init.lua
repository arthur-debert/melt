-- This file is loaded by busted before running tests (as configured in .busted)
-- It makes busted functions available globally for all spec files

-- Print type of assert for debugging (optional, can be removed)
-- print("spec/init.lua: Initial type of assert: " .. type(_G.assert))
-- if type(_G.assert) == "table" then
--   print("spec/init.lua: assert.same is initially: " .. tostring(_G.assert.same))
-- end

-- Define globals provided by busted that luacheck might complain about
-- These should already be global if Busted is running correctly.
_G.describe = describe
_G.it = it
_G.before_each = before_each
_G.after_each = after_each
_G.setup = setup
_G.teardown = teardown

-- Defensive setup for assert.are.* aliases
-- This relies on _G.assert and its fields (like .equal, .same) being correctly populated by Busted.
if _G.assert then
  if type(_G.assert) == "table" then
    if not _G.assert.are then
      _G.assert.are = {}
    end
    if _G.assert.equal then
      _G.assert.are.equal = _G.assert.equal
    else
      print("Warning (spec/init.lua): _G.assert.equal is nil. Cannot create alias assert.are.equal.")
    end
    if _G.assert.same then
      _G.assert.are.same = _G.assert.same
    else
      print("Warning (spec/init.lua): _G.assert.same is nil. Cannot create alias assert.are.same.")
    end
  else
    print("Warning (spec/init.lua): _G.assert is not a table. Busted's assertions might not be loaded correctly.")
  end
else
  print("Warning (spec/init.lua): _G.assert is nil. Busted's assertions are not available.")
end

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown assert
-- luacheck: ignore assert.are