local config_reader = require("lua.melt.readers.config")

describe("CONFIG Reader", function()
  describe("read_config_file", function()
    it("should load a valid CONFIG file", function()
      local data = config_reader.read_config_file("spec/melt/sample_config.config")
      assert.are.equal("CONFIG Example", data.title)
      assert.are.equal("Tom Preston-Werner", data.owner_name)
      assert.are.equal("true", data.feature_x_enabled)           -- CONFIG parser keeps values as strings
      assert.are.equal("true", data.database_enabled)
      assert.are.same({ 8000, 8001, 8002 }, data.database_ports) -- Comma-separated values are parsed as an array
      assert.are.equal(79.5, data.database_temp_targets_cpu)
      assert.are.equal(72.0, data.database_temp_targets_case)
    end)

    it("should return nil and an error message for a non-existent CONFIG file", function()
      local data, err = config_reader.read_config_file("spec/melt/non_existent.config")
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "cannot open") ~= nil or string.find(err, "No such file or directory") ~= nil)
    end)

    it("should return nil and an error message for a malformed CONFIG file", function()
      -- Setup: Create a temporary malformed CONFIG file
      local malformed_config_path = "spec/melt/readers/malformed.config"
      local file = io.open(malformed_config_path, "w")
      if file then
        file:write('[section\nkey = value') -- Missing closing bracket - clearly broken
        file:close()
      end

      local data, err = config_reader.read_config_file(malformed_config_path)
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "attempt to index a nil value", 1, true) ~= nil)

      -- Teardown: Remove the temporary file
      os.remove(malformed_config_path)
    end)
  end)
end)
