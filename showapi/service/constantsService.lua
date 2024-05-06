local setmetatable=setmetatable
local _M={}


--取得client请求阶段数据模型,是最原始的，没有过滤
--整体系统有5类变量
--1.headArgs,urlArgs,postArgs ,用于存储定义好的输入参数
--2.allArgs ,是上述三个变量之合集，元表实现
--3.reqArgs ,是urlArgs,postArgs合集，元表实现
--4.originalArgs ,所有的输入变量
--5.extraPara,额外发给后端的变量
function _M.get_req_in_model()
    local originalArgs={}   --原始参数
    local allArgs={}
    local reqArgs={}
    local headArgs,urlArgs,postArgs={},{},{}

    local  model={
        headArgs=headArgs,         --前端发来的合法头
        urlArgs=urlArgs,          --url传来的参数
        postArgs=postArgs,         --body传来的参数
        bodyString="",       --直接 bodyString
        allArgs=allArgs,          --header,url,post三者合起来
        originalArgs=originalArgs,
        reqArgs=reqArgs,      --是urlArgs,postArgs合集，元表实现,辅助参数，用于lua回调
        uploadFiles=nil,     --上传的文件
        isUpload=false,      --是否上传。必须isUpload&&uploadFiles才会采用上传模式
        opIp="",             --客户ip
    }
    setmetatable(allArgs,{
        __index = function(_, key)
            if postArgs[key] then
                return postArgs[key]
            elseif urlArgs[key] then
                return urlArgs[key]
            elseif headArgs[key] then
                return headArgs[key]
            else
                return nil
            end
        end
    })
    setmetatable(reqArgs,{
        __index = function(_, key)
            if postArgs[key] then
                return postArgs[key]
            elseif urlArgs[key] then
                return urlArgs[key]
            else
                return nil
            end
        end,
        __newindex  = function(_, key,value)
            if postArgs[key] then   --优先设置postArgs
                postArgs[key]=value
            elseif urlArgs[key] then
                urlArgs[key]=value
            else --如果postArgs和urlArgs都没值，那把新值放到postArgs
                postArgs[key]=value
            end
        end
    })

    return model
end
return _M

