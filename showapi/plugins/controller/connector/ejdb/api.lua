local cjson = require "cjson"
local ejdb =require "showapi.plugins.controller.connector.ejdb.ejdbService"
local fmt = string.format
local su = require("showapi.util.stringUtil")
local tonumber=tonumber
local ngx_null = ngx.null
local ipairs,pairs=ipairs,pairs
local table_insert=table.insert
local date = require "showapi.lib.date"
local pref= ngx.config.prefix()
local stringUtil = require("showapi.util.stringUtil")
local fileUtil = require "showapi.util.fileUtil"

local BasePlugin_api = require("showapi.plugins.base_plugin.api")
local _M = BasePlugin_api:getInstance()

local showapi_dev_flag=showapi_dev_flag
local db_path_test="c:/temp/ejdb_data/aa.db"
local coll_test="user"


--  http://localhost:900/ejdb/save
function _M:save( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.json_str=[[
            {
                "name": "Google",
                "url": "http://www.google.com",
                "list":[1,2,3,4]
            }
        ]]
    end

    local obj=cjson.decode(args.json_str)
    if not obj or obj==ngx_null then
        return self:render_json_str(-1,'json_str为null')
    end
    
    local _id=ejdb.save(args.db_path,args.coll,obj )
    return self:render_json_str(0,'',{_id=_id})

end

--   http://localhost:900/ejdb/update
function _M:update( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        --        args.query=[[/[_id="651b8cfdd5d2091834000153"] ]]
        args.updata=cjson.encode({ list={"aa","bbb111"}})
--                args.updata=cjson.encode({ list="11111"})

    end

    local updata=cjson.decode(args.updata)
    local ok,err=ejdb.update(args.db_path,args.coll,args.query,updata )

    if ok==false then
        return self:render_json_str(0,err,{num=0})
    else
        return self:render_json_str(0,'',{num=ok})
    end

end

-- http://localhost:900/ejdb/save_list
function _M:save_list( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.json_str=[[  [
    {
        "name": "Google",
        "url": "http://www.google.com"
    },
    {
        "name": "Baidu",
        "url": "http://www.baidu.com"
    },
    {
        "name": "SoSo",
        "url": "http://www.SoSo.com"
    }
]
]]

    end

--    print(args.json_str)
    local list=cjson.decode(args.json_str)
    if not list or list==ngx_null then
        return self:render_json_str(-1,'json_str为null')
    end
    if #list>200 then
        return self:render_json_str(-1,'The size of array must <=200 ')
    end


    local _id_list={}
    local _id
    for _,obj in ipairs(list) do
        _id=ejdb.save(args.db_path,args.coll,obj )
        table_insert(_id_list,_id)
    end
    return self:render_json_str(0,'',{_id_list=_id_list})

end
-- http://localhost:900/ejdb/save_log
function _M:save_log( )
    local args=self:getArgs()

    local now = date(false)
    local day_str = now:fmt("%Y%m%d")
    local instanceId=args.instanceId or "default_instance_id"
    local db_path=instanceId.."/log/"..day_str..".db"
    local coll="log"

    local all_str=args.json_str.."#ejdb_split____#"..db_path.."#ejdb_split____#"..coll
    ejdb.wait_queue:lpush("wait_queue", all_str)
    return self:render_json_str(0,'insert queue ok',{_id="0"})


end


-- http://localhost:900/ejdb/del_log
function _M:del_log()
    local args=self:getArgs()

    local day=tonumber(args.day or 30)
    local del_list=ejdb:clear_outdate_log(day)

    return self:render_json_str(0,'',{del_list=del_list})


end


-- http://localhost:900/ejdb/findOne
function _M:findOne( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.query=[[/[_id="64ded81dd5d2090840000201"] ]]
        args.fields=""
--        args.sort="asc /ct"
    end
    local one,err=ejdb.findOne(args.db_path,args.coll,args.query,args.fields,args.sort )
    if err then   return self:render_json_str(-1,err) end

    return self:render_json_str(0,'',{one=one})

end



-- http://localhost:900/ejdb/find
function _M:find( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.query=[[/[_id = "60655fd5d41d8c7c3c00011c"] ]]
        args.fields=""
        args.limit="100"
        args.skip="1"

    end
    local limit=args.limit
    if not limit or su.trim(limit):len()==0   then
        limit=20
    end
    if tonumber(limit)<0 then limit=1 end
    if tonumber(limit)>100 then limit=100 end

    local list,err=ejdb.find(args.db_path,args.coll,args.query,args.fields,args.sort,limit,args.skip )
    if err then   return self:render_json_str(-1,err) end

    return self:render_json_str(0,'',{list=list})


end



-- http://localhost:900/ejdb/search
function _M:search( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
--        args.query=[[/[_id = "606563a3d41d8c7c38000126"] ]]
        args.fields=""
        args.page="1"
--        args.pageSize="3"
--        args.need_count="true"
    end

    local need_count=false
    if args.need_count and args.need_count=="true" then
        need_count=true
    end
    local pb,err=ejdb.search(args.db_path,args.coll,args.query,args.fields,args.sort,args.page,args.pageSize,need_count )
--    return self:render_json_str(0,'',pb)

    if err then   return self:render_json_str(-1,err) end

    return self:render_json_str(0,'',pb)


end




--   http://localhost:900/ejdb/update_overwrite
function _M:update_overwrite( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.query=[[/[_id="64ab3787e13823692000032f"] ]]
        args.updata=cjson.encode({name="111",age=222,address={d=6}})
    end

    local updata=cjson.decode(args.updata)
    local num=ejdb.update_overwrite(args.db_path,args.coll,args.query,updata )
    return self:render_json_str(0,'',{num=num})
end

-- http://localhost:900/ejdb/delete
function _M:delete( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.query=[[/[_id="6066950fd41d8cdc190002e7"] ]]
    end
    local num=ejdb.delete(args.db_path,args.coll,args.query )
    return self:render_json_str(0,'',{num=num})
end




-- http://localhost:900/ejdb/count
function _M:count( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.query=[[/*]]
    end
    local num=ejdb.count(args.db_path,args.coll, args.query )
    return self:render_json_str(0,'',{num=num})
end





-- http://localhost:900/ejdb/get_meta
function _M:get_meta( )
    local args=self:getArgs()

    if showapi_dev_flag then
--        args.db_path=db_path_test
    end
    local meta=ejdb.get_meta( args.db_path)
    return self:render_json_str(0,'',{meta=meta})
end

-- http://localhost:900/ejdb/ensure_index
function _M:ensure_index( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test

        args.index_path="/ct"
        args.index_type="s"

    end
    local ok=ejdb.ensure_index(args.db_path,args.coll,args.index_path,args.index_type )
    return self:render_json_str(0,'',{ok=ok})
end


--	删除索引
-- http://localhost:900/ejdb/remove_index
function _M:remove_index()
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
        args.index_path="/ct"
        args.index_type="s"
    end
    local ok,err=ejdb.remove_index(args.db_path,args.coll,args.index_path,args.index_type )
    if not ok then
        if showapi_dev_flag then
            return self:render_json_str(-1,err ,{ok=ok})
        else
            return self:render_json_str(-1,'failed',{ok=ok})
        end

    else
        return self:render_json_str(0,'' ,{ok=ok})
    end

end


-- http://localhost:900/ejdb/remove_coll
function _M:remove_coll( )
    local args=self:getArgs()

    if showapi_dev_flag then
        args.db_path=db_path_test
        args.coll=coll_test
    end
    local ok=ejdb.remove_coll(args.db_path,args.coll  )
    return self:render_json_str(0,'',{ok=ok})
end


-- reload本系统
function _M:reload_openresty()

    ngx.timer.at(0, function()
        local prefix= ngx.config.prefix()
        prefix = stringUtil.replace(prefix , "\\" , "/")  --windows，直接替换符号
        local parent=stringUtil.replace(prefix , "/xapi_ejdb/" , "/")
        local cmd
        if(package.config:sub(1, 1) == "\\" )then
            cmd= fmt("%sopenresty-1.19.3.1/nginx.exe -p %s  -c %s/conf/nginx.conf -s reload",parent,prefix,prefix)
            --cmd= fmt("cd %sdev && ./list-reload.bat",prefix)
        else

            local path = prefix.."showapi/plugins/controller/connector/ejdb/reload_code.sh"
            local str = "%ssbin/nginx -p %s  -c %sconf/nginx.conf -s reload"
            fileUtil.write_to_file(path , string.format(str,prefix,prefix,prefix) )

            local  a,b = os.execute("chmod 777 "..prefix.."showapi/plugins/controller/connector/ejdb/reload_code.sh")
            print("aaaaaaaaaaaaaaaaaaaaaaa",a)
            print("bbbbbbbbbbbbbbbbbbbbbbb",b)
            cmd= fmt("cd %s && ./showapi/plugins/controller/connector/ejdb/reload_code.sh",prefix)
        end
        os.execute(cmd)
    end)
    return self:render_json_str(0,'')
end

return _M




