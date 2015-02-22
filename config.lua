local logging = require("logging")
local jit = jit
local base = _G
module("config") 

global_is_jit = (base.type(base.jit)=="table")
--global_log_level =  logging.DEBUG
global_use_socket_ev = true
global_log_level =  logging.FATAL