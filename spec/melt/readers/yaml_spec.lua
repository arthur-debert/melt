local yaml_reader = require("lua.melt.readers.yaml")

describe("YAML Reader", function()
  describe("read_yaml_file", function()
    it("should load a valid YAML file", function()
      local data = yaml_reader.read_yaml_file("spec/melt/sample_config.yaml")
      assert.are.equal("YAML Example", data.title)
      assert.are.equal("Tom Preston-Werner", data.owner.name)
      assert.are.same({ 8000, 8001, 8002 }, data.database.ports)
      assert.are.same({ cpu = 79.5, case = 72.0 }, data.database.temp_targets)
    end)

    it("should return nil and an error message for a non-existent YAML file", function()
      local data, err = yaml_reader.read_yaml_file("spec/melt/non_existent.yaml")
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "Could not open file") ~= nil)
    end)

    it("should return nil and an error message for a malformed YAML file", function()
      -- Setup: Create a temporary malformed YAML file
      local malformed_yaml_path = "spec/melt/readers/malformed.yaml"
      local file = io.open(malformed_yaml_path, "w")
      if file then
        file:write('title: Invalid YAML\narray: [1, 2,\n  indentation error') -- Invalid YAML
        file:close()
      end

      local data, err = yaml_reader.read_yaml_file(malformed_yaml_path)
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "did not find expected", 1, true) ~= nil)

      -- Teardown: Remove the temporary file
      os.remove(malformed_yaml_path)
    end)
  end)
end)