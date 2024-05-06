local ngx=ngx
local Object = require "showapi.lib.classic"
local dkjson = require "showapi.lib.dkjson"
local type=type
local ngx_exit=ngx.exit
local pairs=pairs
local ngx_HTTP_OK=ngx.HTTP_OK
local ngx_say=ngx.say
local setmetatable=setmetatable
local BaseAPI = Object:extend()

function BaseAPI:getInstance( )
    local instance = {
        plugHandlerObj=nil
    }
    instance.enable = true  --默认启动
    setmetatable(instance, { __index = self })
    return instance
end

--设置对应的插件
function BaseAPI:setPlugHandlerObj(plugHandlerObj)
    self.plugHandlerObj = plugHandlerObj  --设置对处理器的引用
end


function BaseAPI:setEnable()
    local args = ngx.ctx.req_model.originalArgs
    local enable=args.enable
    if(enable=="true") then
        self.enable=true
    else
        self.enable=false
    end
end

function BaseAPI:getRet(ret_code,remark,tab)
    if tab~=nil then
        tab.ret_code=ret_code
        if not tab.remark then
            tab.remark=remark or ""
        end
    else
        tab={
            ret_code=ret_code,remark=remark or ""
        }
    end
    return tab
end

function BaseAPI:render_json_str(ret_code,remark,tab,status,headMap)
    local ret=self:getRet(ret_code,remark,tab)
    if headMap~=nil then
        local header=ngx.header
        for k,v in pairs(headMap) do
            header[k] = v;
        end
    end
    if not status then status=ngx_HTTP_OK end
    ngx.status=status
    ngx_say(dkjson.encode(ret))
    return  ngx_exit(status)

end

function BaseAPI:getArgs()
    return ngx.ctx.req_model.originalArgs
end



return BaseAPI
