local logging = require("logging")
local jit = jit
local base = _G
module("config") 

global_is_jit = (base.type(base.jit)=="table")
global_use_socket_ev = true
--global_log_level =  logging.FATAL
--global_log_level =  logging.ERROR
global_log_level =  logging.DEBUG
