local require=require

local BasePlugin_handler = require("showapi.plugins.base_plugin.handler")
local _M = BasePlugin_handler:extend()


local function init_event()
    local ev = require "showapi.lib.third.events"  --只能在此request，不能放到外层
    local ok, err = ev.configure {
        shm = "process_sync_dict", -- defined by "lua_shared_dict"
        timeout = 2,            -- life time of unique event data in shm
        interval = 1,           -- poll interval (seconds)
        wait_interval = 0.010,  -- wait before retry fetching event data
        wait_max = 0.5,         -- max wait time before discarding event
    }
    if not ok then
        ngx.log(ngx.ERR, "failed to start event system: ", err)
        return
    end
    ev.register(function()print("this is a demo event") end,"showapi","demo_event")

end
function _M:init_worker_by_lua()
    local uuid = require("showapi.lib.jit-uuid")
    uuid.seed()  --初始化uuid


    init_event()

end

return _M
