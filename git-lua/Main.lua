package.path = "./?.lua;./?/init.lua;" .. package.path

local Interface = require("tui.Interface")
local app = Interface.new()
app:run()
