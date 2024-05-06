-- general utility functions.
-- some functions is from [kong](getkong.org)
local require = require
local date = require("showapi.lib.date")
local ipairs,pairs=ipairs,pairs
local dkjson = require "showapi.lib.dkjson"

local type = type
local pairs = pairs
local tostring = tostring
local string_gsub = string.gsub
local su = require("showapi.util.stringUtil")
local http = require "resty.http"
local ngx_now=ngx.now
local escape_uri=ngx.escape_uri

local _M = {}


--输出值有可能会是list或Object，需要做json处理
local function trans_value(val)
    if not val then
        return ""
    elseif type(val)=="string" then
        return escape_uri(val)
    elseif type(val)=="table" then
        return escape_uri(dkjson.encode(val))
    else
        return escape_uri(tostring(val))
    end

end

--获取url和post提交的body体，有2个返回值
--1返回url
--2返回body体
local function get_url_and_body(oldurl,para_list,method,bodyString )
    if su.empty(para_list) then return oldurl,nil end

    local bodyQuery=""

    if bodyString then
        bodyQuery=bodyString    --直接设置
    else
        for _,item in ipairs(para_list) do
            for k,v in pairs(item) do
                bodyQuery=bodyQuery..k.."="..trans_value(v).."&"
            end

        end
    end
--    print("aaaaaaaaaaaaaaaaaa ",bodyQuery)
    if method=="GET" then
        if oldurl:find("%?")==nil then
            oldurl=oldurl.."?"..bodyQuery
        else
            if su.endswith(oldurl,"&") then
                oldurl=oldurl.. bodyQuery
            else
                oldurl=oldurl.."&"..bodyQuery
            end
        end
        return oldurl,nil
    else
        return oldurl,bodyQuery
    end
end



-- url              目标url
-- para_list        提交的表单参数列表{{name="111"},{age="222"}    }
-- head_map         提交的头map
-- bodyString       提交的bodyString
-- req_method       请求方式，GET或|POST
-- connectTimeout   超时时间，默认15000毫秒

function _M.http_request(cfg)
    local url = cfg.url --监控地址
    local para_list = cfg.para_list or {} --请求方式
    local req_method = cfg.req_method or "POST" --请求方式
    local head_map = cfg.head_map or {} --请求头
    local connectTimeout = cfg.connectTimeout or 15000
    if not head_map["Content-Type"] then
        head_map["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8"
    end
    local bodyString = cfg.bodyString  --请求体
    local url,bodyQuery=get_url_and_body(url,para_list,req_method,bodyString)

    local httpc = http.new()
    httpc:set_timeout(connectTimeout)
    local res, err = httpc:request_uri(url, {
        ssl_verify = false,
        method = req_method,
        headers = head_map,
        body = bodyQuery
    })
    httpc:close()
    if not res or err then --连接时报错,返回false
        return false,err
    end
    return res, nil
end



return _M
