local readers = require("lua.melt.readers")

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same

describe("Melt Reader Functions", function()
  describe("read_lua_table", function()
    it("should return the input table", function()
      local tbl = { a = 1, b = { c = 2 } }
      assert.are.same(tbl, readers.read_lua_table(tbl))
    end)
    
    it("should return an empty table if input is not a table", function()
      assert.are.same({}, readers.read_lua_table(nil))
      assert.are.same({}, readers.read_lua_table("string"))
    end)
  end)

  -- Note: The TOML, JSON, and YAML reader tests have been moved to their own spec files
  -- in spec/melt/readers/

  -- Note: The environment variable reader tests have been moved to spec/melt/readers/env_spec.lua
end)