local Object = require "showapi.lib.classic"
local cjson = require "cjson"
local cons =require "showapi.service.constantsService"
local re_match=ngx.re.match
local ngx=ngx
local fmt = string.format
local ngx_exit=ngx.exit
local ngx_say=ngx.say
local pairs=pairs
local ipairs,tostring=ipairs,tostring
local type = type
local date = require "showapi.lib.date"
local escape_uri=ngx.escape_uri


local BasePlugin = Object:extend()
function BasePlugin:renderErr(showapi_res_code,showapi_res_error,http_state)
    http_state=http_state or 200
    local ctx=ngx.ctx
    local service_ret={
        showapi_res_code=showapi_res_code,showapi_res_error=showapi_res_error,showapi_res_body={}
    }
    ngx.status=http_state
    local direct_str=cjson.encode(service_ret)
    ngx_say(direct_str)
    return ngx.exit(http_state)
end

function BasePlugin:get_client_ip()
    local ip=ngx.var.remote_addr
    return ip
end


return BasePlugin
