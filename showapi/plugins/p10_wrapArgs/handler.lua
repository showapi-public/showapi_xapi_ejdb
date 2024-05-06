local date = require "showapi.lib.date"
local cjson = require "cjson"
local type = type
local tostring = tostring
local fileUtil = require "showapi.util.fileUtil"
local pairs=pairs
local ngx_now=ngx.now
local cons =require "showapi.service.constantsService"
local req_getheaders = ngx.req.get_headers
local objid = require ( "resty.mongol.object_id" )
local mediatypes = require "showapi.lib.mime_mediatypes.mediatypes"
local mt = mediatypes.new( );

local BasePlugin_handler = require("showapi.plugins.base_plugin.handler")
local _M = BasePlugin_handler:extend()


--取得当前的时间戳及当前小时(用于统计)
local function getNowTs()
    local secends=ngx_now()
    local secends_long=secends-secends%1       --取整
    local diff=secends_long%(24*60*60)
    local hour=diff/(60*60)
    hour=hour-hour%1+8               --取整

    return secends,tostring(hour)

end

function _M:rewrite_by_lua()
    local ngx=ngx
    local ctx=ngx.ctx
    local req_model=cons.get_req_in_model()
    req_model.headArgs = req_getheaders()

    ctx.req_model=req_model         --放置输入
    local begin_timestamp,begin_hour=getNowTs()
    ctx.begin_timestamp=begin_timestamp
    ctx.begin_hour=begin_hour


    ctx.req_uuid=(objid.new()):tostring()
    local ct = ngx.var.content_type or "x-www-form-urlencoded"
    if ct:find("application") then ct="x-www-form-urlencoded"  end
    local args={}
    local request_method = ngx.var.request_method
    args = ngx.req.get_uri_args()
    ctx.req_get_args=args   --存req参数
    if "POST" == request_method then
        ngx.req.read_body()
        local postArgs = ngx.req.get_post_args()
        ctx.req_post_args=postArgs  --存post参数

        if postArgs then
            for k, v in pairs(postArgs) do
                args[k] = v
            end
        end
    end
    req_model.originalArgs=args
    local opIp=self:get_client_ip()
    ctx.opIp=opIp


end

return _M
