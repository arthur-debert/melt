local utils = require("melt.utils")

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same

describe("Melt Utils", function()
  describe("deep_merge", function()
    it("should merge with an empty source table", function()
      local target = { a = 1, b = 2 }
      local source = {}
      local result = utils.deep_merge(target, source)
      assert.are.same({ a = 1, b = 2 }, result)
    end)

    it("should merge with an empty target table", function()
      local target = {}
      local source = { a = 1, b = 2 }
      local result = utils.deep_merge(target, source)
      assert.are.same({ a = 1, b = 2 }, result)
    end)

    it("should merge non-overlapping keys", function()
      local target = { a = 1 }
      local source = { b = 2 }
      local result = utils.deep_merge(target, source)
      assert.are.same({ a = 1, b = 2 }, result)
    end)

    it("should let source overwrite target for overlapping keys", function()
      local target = { a = 1, b = 2 }
      local source = { b = 3, c = 4 }
      local result = utils.deep_merge(target, source)
      assert.are.same({ a = 1, b = 3, c = 4 }, result)
    end)

    it("should perform deep merging of nested tables", function()
      local target = { a = 1, nested = { x = 10, y = 20, z = { q = 100 } } }
      local source = { b = 2, nested = { y = 25, z = { r = 200 }, w = 30 } }
      local expected = { a = 1, b = 2, nested = { x = 10, y = 25, z = { q = 100, r = 200 }, w = 30 } }
      local result = utils.deep_merge(target, source)
      assert.are.same(expected, result)
    end)

    it("should handle arrays within tables correctly (source replaces target array)", function()
      local target = { a = { 1, 2, 3 }, b = { x = 1 } }
      local source = { a = { 4, 5 }, b = { y = 2 } }
      local result = utils.deep_merge(target, source)
      -- Standard behavior: source array replaces target array if key is the same
      -- Deep merging arrays element by element is a different strategy.
      assert.are.same({ a = { 4, 5 }, b = { x = 1, y = 2 } }, result)
    end)

    it("should not modify the original target table", function()
      local target = { a = 1, nested = { x = 10 } }
      local original_target_deep_copy = utils.deep_merge({}, target) -- simple way to copy
      local source = { b = 2, nested = { y = 20 } }
      utils.deep_merge(target, source)
      assert.are.same(original_target_deep_copy, target)
    end)

    it("should not modify the original source table", function()
      local target = { a = 1 }
      local source = { b = 2, nested = { y = 20 } }
      local original_source_deep_copy = utils.deep_merge({}, source) -- simple way to copy
      utils.deep_merge(target, source)
      assert.are.same(original_source_deep_copy, source)
    end)
  end)
end)
