local json_reader = require("melt.readers.json")

describe("JSON Reader", function()
  describe("read_json_file", function()
    it("should load a valid JSON file", function()
      local data = json_reader.read_json_file("spec/melt/sample_config.json")
      assert.are.equal("JSON Example", data.title)
      assert.are.equal("Tom Preston-Werner", data.owner.name)
      assert.are.same({ 8000, 8001, 8002 }, data.database.ports)
      assert.are.same({ cpu = 79.5, case = 72.0 }, data.database.temp_targets)
    end)

    it("should return nil and an error message for a non-existent JSON file", function()
      local data, err = json_reader.read_json_file("spec/melt/non_existent.json")
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "Could not open file") ~= nil)
    end)

    it("should return nil and an error message for a malformed JSON file", function()
      -- Setup: Create a temporary malformed JSON file
      local malformed_json_path = "spec/melt/readers/malformed.json"
      local file = io.open(malformed_json_path, "w")
      if file then
        file:write('{"key": "value", "broken": true,') -- Missing closing brace - clearly broken
        file:close()
      end

      local data, err = json_reader.read_json_file(malformed_json_path)
      assert.is_nil(data)
      assert.is_string(err)
      assert.is_true(string.find(err, "Failed to parse JSON", 1, true) ~= nil or
        string.find(err, "lexical error", 1, true) ~= nil or
        string.find(err, "unexpected symbol", 1, true) ~= nil or
        string.find(err, "expected value", 1, true) ~= nil or
        string.find(err, "unterminated object", 1, true) ~= nil)

      -- Teardown: Remove the temporary file
      os.remove(malformed_json_path)
    end)
  end)
end)
