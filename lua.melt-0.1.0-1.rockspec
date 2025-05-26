rockspec_format = "3.0"
package = "lua.melt"
version = "0.1.0-1"
source = {
   url = "."
}
description = {
   summary = "A Lua library for hierarchical configuration management.",
   detailed = [[
      lua-melt allows for merging configurations from multiple sources (defaults, files, environment variables) with a defined precedence. It supports Lua tables, TOML files, and environment variables out of the box, with an extensible design for adding more formats.
   ]],
   homepage = "https://github.com/arthur-debert/melt.lua",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "penlight >= 1.14.0",
   "log.lua >= 0.1.0",
   "string-format-all >= 0.2.0", -- Package name uses hyphens, but require() uses dots
   "lua-toml >= 2.0-0"
}
test_dependencies = {
   "busted >= 2.0.0"
}
build = {
   type = "builtin",
   modules = {
      ["lua.melt"] = "lua/melt/init.lua",
      ["lua.melt.utils"] = "lua/melt/utils.lua",
      ["lua.melt.readers"] = "lua/melt/readers.lua"
   },
   copy_directories = {"docs"}
}
test = {
   type = "busted",
   -- Additional test configuration can go here
}