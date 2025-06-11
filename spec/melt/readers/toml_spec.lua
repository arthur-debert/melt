local toml_reader = require("lua.melt.readers.toml")

describe("TOML Reader", function()
  describe("read_toml_file", function()
    it("should load a valid TOML file", function()
      local data = toml_reader.read_toml_file("spec/melt/sample_config.toml")
      assert.are.equal("TOML Example", data.title)
      assert.are.equal("Tom Preston-Werner", data.owner.name)
      assert.are.same({ 8000.0, 8001.0, 8002.0 }, data.database.ports) -- Note: TOML numbers are floats
      assert.are.same({ cpu = 79.5, case = 72.0 }, data.database.temp_targets)
    end)

    it("should return nil and an error message for a non-existent TOML file", function()
      local data, err = toml_reader.read_toml_file("spec/melt/non_existent.toml")
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "Could not open file") ~= nil)
    end)

    it("should return nil and an error message for a malformed TOML file", function()
      -- Setup: Create a temporary malformed TOML file
      local malformed_toml_path = "spec/melt/readers/malformed.toml"
      local file = io.open(malformed_toml_path, "w")
      if file then
        file:write("key = unquoted_string_value ; anotherkey = [1,2") -- Malformed: unquoted string, unclosed array
        file:close()
      end

      local data, err = toml_reader.read_toml_file(malformed_toml_path)
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "Invalid primitive on line 1", 1, true) ~= nil)

      -- Teardown: Remove the temporary file
      os.remove(malformed_toml_path)
    end)
  end)
end)