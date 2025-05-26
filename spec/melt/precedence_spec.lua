local Melt = require("lua.melt")

-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true

describe("Precedence Rules", function()
  it("should correctly apply precedence: defaults < file < env", function()
    local defaults = {
      service_host = "default_host",
      log_level = "warn",
      unique_default = true,
      timeout = 5000
    }

    -- Mock environment variables
    local old_os_environ = _G.os.environ
    _G.os.environ = {
      PRECEDENCE_APP_SERVICE_HOST = "env_host",
      PRECEDENCE_APP_LOG_LEVEL = "debug",
      PRECEDENCE_APP_NEW_FEATURE = "awesome",
      PRECEDENCE_APP_TIMEOUT = "100" -- env var string, should be converted
    }
    
    local config = Melt.new()
    config:add_table(defaults)
    config:add_file("spec/melt/sample_config.toml") -- TOML has service_host, log_level, feature_x_enabled
    config:add_env("PRECEDENCE_APP_")

    _G.os.environ = old_os_environ -- Restore

    -- Assertions
    assert.are.equal("env_host", config:get("service_host")) -- env overrides file and default
    assert.are.equal("debug", config:get("log_level"))     -- env overrides file and default
    assert.is_true(config:get("unique_default"))           -- from defaults, not overridden
    assert.is_true(config:get("feature_x_enabled"))        -- from file, not overridden by env
    assert.are.equal("awesome", config:get("new_feature")) -- from env only
    assert.are.equal(100, config:get("timeout")) -- env (converted to number) overrides default

    -- Check values from TOML that were not in defaults and not overridden by ENV
    assert.are.equal("TOML Example", config:get("title"))
    assert.is_true(config:get("database.enabled"))
  end)
end)