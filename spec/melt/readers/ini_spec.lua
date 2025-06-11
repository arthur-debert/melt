local ini_reader = require("lua.melt.readers.ini")

describe("INI Reader", function()
  describe("read_ini_file", function()
    it("should load a valid INI file", function()
      local data = ini_reader.read_ini_file("spec/melt/sample_config.ini")
      assert.are.equal("INI Example", data.title)
      assert.are.equal("Tom Preston-Werner", data.owner.name)
      assert.are.equal("true", data.feature_x_enabled)           -- INI parser keeps values as strings
      assert.are.equal("true", data.database.enabled)
      assert.are.same({ 8000, 8001, 8002 }, data.database.ports) -- Comma-separated values are parsed as an array
      assert.are.equal(79.5, data.database.temp_targets_cpu)
      assert.are.equal(72.0, data.database.temp_targets_case)
    end)

    it("should return nil and an error message for a non-existent INI file", function()
      local data, err = ini_reader.read_ini_file("spec/melt/non_existent.ini")
      assert.is_nil(data)
      assert.is_string(err)
      -- The ini_config library might return a specific error for file not found
      assert.is_true(string.find(err, "cannot open") ~= nil or string.find(err, "No such file or directory") ~= nil)
    end)

    it("should return nil and an error message for a malformed INI file", function()
      -- Setup: Create a temporary malformed INI file
      local malformed_ini_path = "spec/melt/readers/malformed.ini"
      local file = io.open(malformed_ini_path, "w")
      if file then
        file:write('[section\nkey = value') -- Missing closing bracket - clearly broken
        file:close()
      end

      local data, err = ini_reader.read_ini_file(malformed_ini_path)
      assert.is_nil(data)
      assert.is_string(err)
      -- Error message from ini_config for this specific malformed content
      -- Check for any common error patterns that indicate parsing failure
      assert.is_true(string.find(err, "attempt to index", 1, true) ~= nil or
        string.find(err, "nil value", 1, true) ~= nil or
        string.find(err, "parse", 1, true) ~= nil or
        string.find(err, "syntax", 1, true) ~= nil)

      -- Teardown: Remove the temporary file
      os.remove(malformed_ini_path)
    end)
  end)
end)
