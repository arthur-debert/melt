rockspec_format = "3.0"
package = "melt"
version = "0.1.0-1"
source = {
   url = "."
}
description = {
   summary = "Synthetic filesystem for isolated operations",
   detailed = [[
      melt provides a synthetic filesystem abstraction to isolate and queue 
      filesystem operations for batch execution. The primary goal is to separate 
      planning from execution, allowing most of the codebase to remain functional 
      and side-effect free.
   ]],
   homepage = "https://github.com/arthur-debert/melt.lua",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "penlight >= 1.14.0",
   "log.lua >= 0.1.0",
   "string-format-all >= 0.2.0", -- Package name uses hyphens, but require() uses dots
}
test_dependencies = {
   "busted >= 2.0.0"
}
build = {
   type = "builtin",
   modules = {
      ["melt.init"] = "melt/init.lua",

   },
   copy_directories = {"docs"}
}
test = {
   type = "busted",
   -- Additional test configuration can go here
}