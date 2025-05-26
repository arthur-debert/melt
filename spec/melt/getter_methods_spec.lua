local Melt = require("lua.melt")

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil

describe("Getter Methods", function()
  local config

  before_each(function()
    config = Melt.new()
    config:add_table({
      name = "app_name",
      version = "1.0.0",
      server = {
        host = "localhost",
        port = 8080,
        protocols = { "http", "https" }
      },
      features = {
        feature_a = true,
        feature_b = false
      },
      empty_table = {}
    })
    config:add_file("spec/melt/sample_config.toml") -- Adds 'database', 'owner', 'title' etc.
  end)

  it(":get(key) should retrieve top-level keys", function()
    assert.are.equal("app_name", config:get("name"))
    assert.are.equal("1.0.0", config:get("version"))
    assert.are.equal("TOML Example", config:get("title")) -- From TOML
  end)

  it(":get(key) should retrieve nested keys", function()
    assert.are.equal("localhost", config:get("server.host"))
    assert.are.equal(8080, config:get("server.port"))
    assert.are.equal(79.5, config:get("database.temp_targets.cpu")) -- From TOML
  end)

  it(":get(key) should retrieve a full sub-table", function()
    local expected_server = { host = "localhost", port = 8080, protocols = { "http", "https" } }
    assert.are.same(expected_server, config:get("server"))
    
    local expected_temp_targets = { cpu = 79.5, case = 72.0 }
    assert.are.same(expected_temp_targets, config:get("database.temp_targets")) -- From TOML
  end)
  
  it(":get(key) should retrieve an array/list element by 1-based index", function()
    assert.are.equal("http", config:get("server.protocols[1]"))
    assert.are.equal("https", config:get("server.protocols[2]"))
    assert.is_nil(config:get("server.protocols[3]")) -- Out of bounds
    assert.are.equal(8000.0, config:get("database.ports[1]")) -- From TOML, adjusted to float
    assert.are.equal(8001.0, config:get("database.ports[2]")) -- From TOML, adjusted to float
  end)

  it(":get(key) should return nil for a non-existent key", function()
    assert.is_nil(config:get("non_existent_key"))
    assert.is_nil(config:get("server.non_existent_nested_key"))
    assert.is_nil(config:get("database.ports[10]")) -- out of bounds
  end)
  
  it(":get(key) should return nil for an invalid key type", function()
    assert.is_nil(config:get(123))
    assert.is_nil(config:get({}))
  end)

  it(":get_table() should return the full merged configuration table", function()
    local data = config:get_table()
    assert.are.equal("app_name", data.name)
    assert.are.equal("localhost", data.server.host)
    assert.are.equal("TOML Example", data.title) -- From TOML
    assert.is_true(type(data.database) == "table") -- From TOML
  end)
end)