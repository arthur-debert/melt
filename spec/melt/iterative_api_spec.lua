local Melt = require("lua.melt")

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true

describe("Iterative API (Melt.merge)", function()
  it("should merge configurations from a list of sources", function()
    local old_os_environ = _G.os.environ
    _G.os.environ = { ITER_APP_FROM_ENV = "env_val" }

    local sources = {
      { type = "table", source = { default_setting = true, common_key = "from_table" } },
      { type = "file", path = "spec/melt/sample_config.toml" },
      { type = "env", prefix = "ITER_APP_" }
    }
    
    local config = Melt.merge(sources)
    _G.os.environ = old_os_environ -- Restore

    local data = config:get_table()
    assert.is_true(data.default_setting)
    assert.are.equal("from_table", data.common_key) -- Will be overwritten by TOML if common_key exists there with same name
    assert.are.equal("TOML Example", data.title)
    assert.are.equal("env_val", data.from_env)
  end)

  it("should handle invalid items in sources_list gracefully", function()
    local sources = {
      { type = "table", source = { val = 1 } },
      { type = "invalid" },
      { path = "some_path" }, -- missing type
      { type = "file", source = "not_a_path_string" }
    }
    -- Expect no errors, and valid sources to be processed
    local config = Melt.merge(sources)
    local data = config:get_table()
    assert.are.same({val = 1}, data) -- Only the first valid source should be processed
  end)
end)