local json_reader = require("lua.melt.readers.json")

describe("JSON Reader", function()
  describe("read_json_file", function()
    it("should load a valid JSON file", function()
      local data = json_reader.read_json_file("spec/melt/sample_config.json")
      assert.are.equal("JSON Example", data.title)
      assert.are.equal("Tom Preston-Werner", data.owner.name)
      assert.are.same({ 8000, 8001, 8002 }, data.database.ports)
      assert.are.same({ cpu = 79.5, case = 72.0 }, data.database.temp_targets)
    end)

    it("should return an empty table for a non-existent JSON file", function()
      local data = json_reader.read_json_file("spec/melt/non_existent.json")
      assert.are.same({}, data)
    end)
    
    it("should return an empty table for a malformed JSON file", function()
      -- Setup: Create a temporary malformed JSON file
      local malformed_json_path = "spec/melt/readers/malformed.json"
      local file = io.open(malformed_json_path, "w")
      if file then
        file:write('{"key": "value", "broken": true,') -- Missing closing brace - clearly broken
        file:close()
      end

      local data = json_reader.read_json_file(malformed_json_path)
      assert.are.same({}, data)

      -- Teardown: Remove the temporary file
      os.remove(malformed_json_path)
    end)
  end)
end)