local utils = require("lua.melt.utils")
local readers = require("lua.melt.readers")
local Melt = require("lua.melt")

describe("lua-melt Library", function()

  describe("1. utils.deep_merge", function()
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
      local target = { a = {1, 2, 3}, b = { x = 1} }
      local source = { a = {4, 5}, b = { y = 2} }
      local result = utils.deep_merge(target, source)
      -- Standard behavior: source array replaces target array if key is the same
      -- Deep merging arrays element by element is a different strategy.
      assert.are.same({ a = {4, 5}, b = {x = 1, y = 2} }, result)
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

  describe("2. Reader Functions", function()
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

    describe("read_toml_file", function()
      it("should load a valid TOML file", function()
        local data = readers.read_toml_file("spec/melt/sample_config.toml")
        assert.are.equal("TOML Example", data.title)
        assert.are.equal("Tom Preston-Werner", data.owner.name)
        assert.are.same({ 8000, 8001, 8002 }, data.database.ports)
        assert.are.same({ cpu = 79.5, case = 72.0 }, data.database.temp_targets)
      end)

      it("should return an empty table for a non-existent TOML file", function()
        local data = readers.read_toml_file("spec/melt/non_existent.toml")
        assert.are.same({}, data)
      end)
      
      it("should return an empty table for a malformed TOML file", function()
        -- Setup: Create a temporary malformed TOML file
        local malformed_toml_path = "spec/melt/malformed.toml"
        local file = io.open(malformed_toml_path, "w")
        if file then
          file:write("key = unquoted_string_value ; anotherkey = [1,2") -- Malformed: unquoted string, unclosed array
          file:close()
        end

        local data = readers.read_toml_file(malformed_toml_path)
        assert.are.same({}, data)

        -- Teardown: Remove the temporary file (basic cleanup)
        os.remove(malformed_toml_path)
      end)
    end)

    describe("read_env_vars", function()
      local old_os_environ -- To store the original _G.os.environ

      before_each(function()
        old_os_environ = _G.os.environ
      end)

      after_each(function()
        _G.os.environ = old_os_environ -- Restore
      end)

      it("should read and transform prefixed environment variables", function()
        _G.os.environ = {
          MYAPP_USER = "testuser",
          MYAPP_DB__HOST = "localhost",
          MYAPP_DB__PORT = "5432",
          MYAPP_FEATURE__FLAG_X = "true",
          MYAPP_FEATURE__TIMEOUT_Y = "100.5",
          OTHER_VAR = "ignore_me"
        }
        local expected = {
          user = "testuser",
          db = {
            host = "localhost",
            port = 5432 -- Converted to number
          },
          feature = {
            flag_x = true, -- Converted to boolean
            timeout_y = 100.5 -- Converted to number
          }
        }
        local result = readers.read_env_vars("MYAPP_")
        assert.are.same(expected, result)
      end)

      it("should return an empty table if no environment variables match the prefix", function()
        _G.os.environ = {
          OTHER_VAR1 = "value1",
          OTHER_VAR2 = "value2"
        }
        local result = readers.read_env_vars("MYAPP_")
        assert.are.same({}, result)
      end)

      it("should return an empty table if prefix is empty or nil", function()
         _G.os.environ = { MYAPP_USER = "testuser" }
         assert.are.same({}, readers.read_env_vars(""))
         assert.are.same({}, readers.read_env_vars(nil))
      end)
      
      it("should correctly handle various value types (string, boolean, number)", function()
        _G.os.environ = {
            APP_STRING = "hello world",
            APP_BOOL_TRUE = "true",
            APP_BOOL_FALSE = "false",
            APP_NUMBER_INT = "123",
            APP_NUMBER_FLOAT = "45.67",
            APP_UPPER_BOOL = "TRUE"
        }
        local expected = {
            string = "hello world",
            bool_true = true,
            bool_false = false,
            number_int = 123,
            number_float = 45.67,
            upper_bool = true,
        }
        local result = readers.read_env_vars("APP_")
        assert.are.same(expected, result)
      end)
    end)
  end)

  describe("3. Config Object and Chained API", function()
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
  
  describe("4. Iterative API (Melt.merge)", function()
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

  describe("5. Getter Methods", function()
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
        assert.are.equal(8000, config:get("database.ports[1]")) -- From TOML
        assert.are.equal(8001, config:get("database.ports[2]")) -- From TOML
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

  describe("6. Precedence Rules", function()
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
end)
