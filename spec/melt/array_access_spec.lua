-- Suppress luacheck warnings
-- luacheck: globals describe it before_each after_each setup teardown
-- luacheck: ignore assert.are assert.are.same assert.is_true assert.is_nil assert.has_error

local Melt = require("lua.melt")

describe("Array Access Tests", function()
    describe("Declarative config array access", function()
        it("should access array elements in nested configuration", function()
            local defaults = {
                database = {
                    servers = {
                        { host = "db1.example.com", port = 5432 },
                        { host = "db2.example.com", port = 5433 },
                        { host = "db3.example.com", port = 5434 }
                    },
                    types = { "primary", "replica", "backup" }
                }
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Test accessing array elements with index
            assert.are.equal("db1.example.com", config:get("database.servers[1].host"))
            assert.are.equal(5432, config:get("database.servers[1].port"))
            assert.are.equal("db2.example.com", config:get("database.servers[2].host"))
            assert.are.equal(5433, config:get("database.servers[2].port"))
            assert.are.equal("db3.example.com", config:get("database.servers[3].host"))

            -- Test accessing simple array elements
            assert.are.equal("primary", config:get("database.types[1]"))
            assert.are.equal("replica", config:get("database.types[2]"))
            assert.are.equal("backup", config:get("database.types[3]"))
        end)

        it("should return nil for out-of-bounds array access", function()
            local defaults = {
                items = { "first", "second" }
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Test out-of-bounds access
            assert.is_nil(config:get("items[3]"))
            assert.is_nil(config:get("items[0]")) -- Lua is 1-indexed
            assert.is_nil(config:get("items[100]"))
        end)

        it("should return nil when trying to access array index on non-table", function()
            local defaults = {
                scalar_value = "not_an_array",
                nested = {
                    also_scalar = 42
                }
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Test array access on non-table values
            assert.is_nil(config:get("scalar_value[1]"))
            assert.is_nil(config:get("nested.also_scalar[1]"))
        end)

        it("should return nil when accessing non-existent key with array syntax", function()
            local defaults = {
                existing_key = "value"
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Test array access on non-existent keys
            assert.is_nil(config:get("non_existent[1]"))
            assert.is_nil(config:get("existing_key.non_existent[1]"))
        end)

        it("should handle complex nested array access", function()
            local defaults = {
                clusters = {
                    {
                        name = "east",
                        nodes = {
                            { ip = "10.0.1.1", roles = { "master", "backup" } },
                            { ip = "10.0.1.2", roles = { "slave" } }
                        }
                    },
                    {
                        name = "west",
                        nodes = {
                            { ip = "10.0.2.1", roles = { "master" } }
                        }
                    }
                }
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Test deeply nested array access
            assert.are.equal("east", config:get("clusters[1].name"))
            assert.are.equal("10.0.1.1", config:get("clusters[1].nodes[1].ip"))
            assert.are.equal("master", config:get("clusters[1].nodes[1].roles[1]"))
            assert.are.equal("backup", config:get("clusters[1].nodes[1].roles[2]"))
            assert.are.equal("slave", config:get("clusters[1].nodes[2].roles[1]"))

            assert.are.equal("west", config:get("clusters[2].name"))
            assert.are.equal("10.0.2.1", config:get("clusters[2].nodes[1].ip"))
            assert.are.equal("master", config:get("clusters[2].nodes[1].roles[1]"))
        end)

        it("should handle invalid array index syntax", function()
            local defaults = {
                items = { "first", "second", "third" }
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Test invalid array syntax - these should be treated as regular key access
            assert.is_nil(config:get("items[abc]")) -- non-numeric index
            assert.is_nil(config:get("items[]"))    -- empty index
            assert.is_nil(config:get("items[1.5]")) -- decimal index
            assert.is_nil(config:get("items[-1]"))  -- negative index
        end)

        it("should handle array access when current_value becomes nil", function()
            local defaults = {
                path = {
                    to = {
                        array = { "value1", "value2" }
                    }
                }
            }

            local config, errors = Melt.declare({
                app_name = "arraytest",
                defaults = defaults
            })

            assert.are.equal(0, #errors)

            -- Valid access first
            assert.are.equal("value1", config:get("path.to.array[1]"))

            -- Test path that leads to nil mid-traversal
            assert.is_nil(config:get("path.to.nonexistent[1]"))
            assert.is_nil(config:get("path.nonexistent.array[1]"))
        end)
    end)

    describe("Config object array access", function()
        it("should work with Config object as well", function()
            local config = Melt.new()
            config:add_table({
                services = {
                    { name = "web", port = 80 },
                    { name = "api", port = 8080 },
                    { name = "db",  port = 5432 }
                }
            })

            assert.are.equal("web", config:get("services[1].name"))
            assert.are.equal(80, config:get("services[1].port"))
            assert.are.equal("api", config:get("services[2].name"))
            assert.are.equal(8080, config:get("services[2].port"))
            assert.are.equal("db", config:get("services[3].name"))
            assert.are.equal(5432, config:get("services[3].port"))
        end)
    end)
end)
