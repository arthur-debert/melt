local env_reader = require("melt.readers.env")

-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same

describe("Environment Variables Reader", function()
  local old_os_environ -- To store the original _G.os.environ

  before_each(function()
    old_os_environ = _G.os.environ
  end)

  after_each(function()
    _G.os.environ = old_os_environ -- Restore
  end)

  describe("read_env_vars", function()
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
          flag_x = true,    -- Converted to boolean
          timeout_y = 100.5 -- Converted to number
        }
      }
      local result = env_reader.read_env_vars("MYAPP_")
      assert.are.same(expected, result)
    end)

    it("should return an empty table if no environment variables match the prefix", function()
      _G.os.environ = {
        OTHER_VAR1 = "value1",
        OTHER_VAR2 = "value2"
      }
      local result = env_reader.read_env_vars("MYAPP_")
      assert.are.same({}, result)
    end)

    it("should return an empty table if prefix is empty or nil", function()
      _G.os.environ = { MYAPP_USER = "testuser" }
      assert.are.same({}, env_reader.read_env_vars(""))
      assert.are.same({}, env_reader.read_env_vars(nil))
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
      local result = env_reader.read_env_vars("APP_")
      assert.are.same(expected, result)
    end)
  end)
end)
