-- luacheck: globals describe it
local cmdline_reader = require "melt.readers.cmdline"

describe("melt.readers.cmdline", function()
  describe(".read_options()", function()
    it("should return an empty table for non-table input", function()
      assert.same({}, cmdline_reader.read_options(nil))
      assert.same({}, cmdline_reader.read_options("not a table"))
      assert.same({}, cmdline_reader.read_options(123))
    end)

    it("should return an empty table for an empty input table", function()
      assert.same({}, cmdline_reader.read_options({}))
    end)

    it("should handle simple flat keys (no hyphens) and convert to lowercase", function()
      local input = {
        LogLevel = "INFO",
        TIMEOUT = "300"
      }
      local expected = {
        loglevel = "INFO", -- Assuming string, not converted further by this example
        timeout = 300      -- Converted to number
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)

    it("should convert keys with hyphens to nested tables and lowercase", function()
      local input = {
        ["database-host"] = "localhost",
        ["DATABASE-PORT-NUMBER"] = "5432",
        ["Feature-X-Enabled"] = "TRUE"
      }
      local expected = {
        database = {
          host = "localhost",
          port = {
            number = 5432 -- Converted to number
          }
        },
        feature = {
          x = {
            enabled = true -- Converted to boolean
          }
        }
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)

    it("should correctly convert values to boolean and number types", function()
      local input = {
        is_enabled = "true",
        is_disabled = "FALSE",
        count = "101",
        percentage = "0.75",
        not_a_bool = "TrueValue",
        not_a_number = "123x"
      }
      local expected = {
        is_enabled = true,
        is_disabled = false,
        count = 101,
        percentage = 0.75,
        not_a_bool = "TrueValue", -- Stays string
        not_a_number = "123x"     -- Stays string
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)

    it("should handle keys with underscores (no hyphens) by lowercasing them", function()
      local input = {
        MAX_RETRIES = "5",
        ["API_Key_Value"] = "secret123"
      }
      local expected = {
        max_retries = 5,
        api_key_value = "secret123"
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)

    it("should handle mixed hyphens and underscores in keys", function()
      local input = {
        ["user-auth_token"] = "token-value",
        ["log_level-main"] = "DEBUG"
      }
      -- Hyphens create nesting, underscores are part of the key segment
      local expected = {
        user = {
          auth_token = "token-value"
        },
        log_level = {
          main = "DEBUG"
        }
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)

    it("should ignore non-string keys in the input table", function()
      local input = {
        validKey = "value1",
        [123] = "numeric_key_value",
        [true] = "boolean_key_value",
        ["another-valid-key"] = "value2"
      }
      local expected = {
        validkey = "value1",
        another = {
          valid = {
            key = "value2"
          }
        }
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)

    it("should handle values that are already non-string types", function()
      local input = {
        is_ready = true,
        max_items = 20,
        ["config-name"] = "my_app"
      }
      local expected = {
        is_ready = true,
        max_items = 20,
        config = {
          name = "my_app"
        }
      }
      assert.same(expected, cmdline_reader.read_options(input))
    end)
  end)
end)
