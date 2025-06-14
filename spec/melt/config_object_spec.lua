local Melt = require("melt")

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true

describe("Config Object and Chained API", function()
  it("Melt.new() should create a new Config object", function()
    local config = Melt.new()
    assert.is_true(type(config) == "table" and type(config.get_table) == "function")
    assert.are.same({}, config:get_table())
  end)

  it(":add_table() should add data from a Lua table", function()
    local config = Melt.new()
    local tbl = { key1 = "value1", nested = { key2 = "value2" } }
    config:add_table(tbl)
    assert.are.same(tbl, config:get_table())
  end)

  it(":add_file() should load and merge data from sample_config.toml", function()
    local config = Melt.new()
    config:add_file("spec/melt/sample_config.toml")
    local data = config:get_table()
    assert.are.equal("TOML Example", data.title)
    assert.are.equal("Tom Preston-Werner", data.owner.name)
  end)

  it(":add_file() should load and merge data from sample_config.json", function()
    local config = Melt.new()
    config:add_file("spec/melt/sample_config.json")
    local data = config:get_table()
    assert.are.equal("JSON Example", data.title)
    assert.are.equal("Tom Preston-Werner", data.owner.name)
  end)

  it(":add_file() should auto-detect JSON files by extension", function()
    local config = Melt.new()
    config:add_file("spec/melt/sample_config.json") -- .json extension
    local data = config:get_table()
    assert.are.equal("JSON Example", data.title)
  end)

  it(":add_file() should load and merge data from sample_config.yaml", function()
    local config = Melt.new()
    config:add_file("spec/melt/sample_config.yaml")
    local data = config:get_table()
    assert.are.equal("YAML Example", data.title)
    assert.are.equal("Tom Preston-Werner", data.owner.name)
  end)

  it(":add_file() should auto-detect YAML files by extension", function()
    local config = Melt.new()
    config:add_file("spec/melt/sample_config.yaml") -- .yaml extension
    local data = config:get_table()
    assert.are.equal("YAML Example", data.title)
  end)

  it(":add_env() should load and merge data from mocked environment variables", function()
    local old_os_environ = _G.os.environ
    _G.os.environ = {
      TESTAPP_HOST = "env_host",
      TESTAPP_PORT = "8080"
    }
    local config = Melt.new()
    config:add_env("TESTAPP_")
    _G.os.environ = old_os_environ -- Restore

    local expected = {
      host = "env_host",
      port = 8080
    }
    assert.are.same(expected, config:get_table())
  end)

  it("should allow chaining of multiple add_* calls", function()
    local old_os_environ = _G.os.environ
    _G.os.environ = { MYCHAIN_ENV_VAR = "env_value" }

    local config = Melt.new()
    config:add_table({ table_var = "table_value" })
        :add_file("spec/melt/sample_config.toml")
        :add_env("MYCHAIN_")

    _G.os.environ = old_os_environ -- Restore

    local data = config:get_table()
    assert.are.equal("table_value", data.table_var)
    assert.are.equal("TOML Example", data.title)
    assert.are.equal("env_value", data.env_var)
  end)
end)
