local require=require
local cjson = require "cjson"
local fmt = string.format

local BasePlugin_handler = require("showapi.plugins.base_plugin.handler")
local _M = BasePlugin_handler:extend()
local pcall=pcall
local re_match=ngx.re.match


function  _M:init_worker_by_lua()
    _M.global_plugin_pool=_M.ApiLine.global_plugin_pool --做初始化
end

local render_json=function(ret_code,remark,status)
    local ngx=ngx
    ngx.status=status
    ngx.say(cjson.encode({
        ret_code=ret_code,
        remark=remark
    }))
end

local showapi_dev_flag=showapi_dev_flag
function  _M:content_by_lua()
    local ngx=ngx
    local uri = ngx.var.uri
    -- 如果是首页
    if uri == "" or uri == "/" then
        --~     local res = ngx.location.capture("/index.html", {})
        ngx.say("this is index")
        return
    end
    local m, err = re_match(uri, "/([a-zA-Z0-9-_]+)/([a-zA-Z0-9-_]+)$","o")   -- 参数"o"是开启缓存必须的

    if m==nil then
        return render_json(-1,"err found page  ",404)
    end

    local moduleName = m[1]     -- 模块名
    local method = m[2]         -- 方法名
    if not method then
        method = "index"        -- 默认访问index方法
    else
        method = ngx.re.gsub(method, "-", "_")
    end
    local plugin
    if showapi_dev_flag then
        local apiLine=require "showapi.core.ApiLine"
        plugin= apiLine.global_plugin_pool[moduleName]
    else
        plugin= _M.global_plugin_pool[moduleName]
    end

    if plugin==nil then
        return render_json(-1,"err found plugin  " ,404)
    end
    local api=plugin.api
    if api==nil then
        return render_json(-1,"err found api " ,404)
    end

    --ngx.say("invoke" .. method .. "<br>")
    ngx.header["Content-Type"]="application/json;charset=utf-8"
    -- 尝试获取模块方法，不存在则报错
    local req_method = api[method]
    ngx.log(ngx.ERR,method)
    if req_method == nil then
        return render_json(-1,"err found method ",404)
    end
    -- 执行模块方法，报错则显示错误信息，所见即所得，可以追踪lua报错行数
    local ret, err = pcall(req_method,api)  --要传入api，不然在方法里得不到self

    if ret == false then
        print(err)
        return render_json(-1,"method invoke err ",404)
    end



end

return _M
