local require=require
local ngx=ngx
local ejdb =require "showapi.plugins.controller.connector.ejdb.ejdbService"
local now = ngx.time
local lockService =require "showapi.service.lockService"
local pairs,pcall=pairs,pcall
local cjson = require "cjson"
local ngx_null = ngx.null
local su = require("showapi.util.stringUtil")
local date = require "showapi.lib.date"
local sleep = ngx.sleep
local lfs=require"lfs"
local BasePlugin_handler = require("showapi.plugins.base_plugin.handler")
local _M = BasePlugin_handler:extend()

local wait_queue=ngx.shared.wait_queue


function _M:init_worker_by_lua()
    local worker_id=ngx.worker.id()
    if worker_id~=0 then return end
    print("---------------- consume ejdb  queue  " )
    ngx.timer.at(0,function()
        local all_str,obj,seg
        local json_str,db_path,coll
        local res
        while(true) do
            if ngx.worker.exiting() then
                print("out----------------- ngx.worker.exiting()")
                for k,wrap in pairs(ejdb.db_holder_map) do
                    ejdb.db_holder_map[k]=nil  --移除
                    pcall(function()
                        wrap.db:close()
                    end)
                end
                break
            end

            all_str=wait_queue:rpop("wait_queue")
            if  all_str then
                seg=su.split(all_str,"#ejdb_split____#")
                if #seg~=3 then return end
                json_str=seg[1]
                db_path=seg[2]
                coll=seg[3]
                obj=cjson.decode(seg[1])
                if not obj or  obj==ngx_null then  return end
                res=ejdb.save(db_path,coll,obj )
            else
                sleep(0.1)
            end
        end
    end)

    local lut
    --需要优化并发时的处理
    ngx.timer.every(60,function()
        print("---------------- check db_holder_map")
        local nowtime=now()
        for k,wrap in pairs(ejdb.db_holder_map) do
            print(wrap.lut)
            lut=wrap.lut
            lockService.callbackInLock("db_op_"..wrap.db_path, function()
                if nowtime-wrap.lut>10*60 then  --超过10分钟
                    ejdb.db_holder_map[k]=nil  --移除
                    pcall(function()
                        wrap.db:close()
                    end)
                end
            end)
        end
    end)

    --每天创建push_log索引
    ngx.timer.every(60*60,function()   --1小时执行一次
        local now = date(false)
        local hour = now:gethours()
        if hour~=4 then return end		--只有4点才执行
        print("---------------- create  index")

        --查找有哪些用户
        local path = ngx.config.prefix().."/db"
        local mode = lfs.attributes( path , "mode")
        if(not mode)then  return end
        if mode ~= "file" then
            for file in lfs.dir(path) do
                if file ~= "." and file ~= ".." then
                    local filePath = path .. "/" .. file
                    --排除文件类型 , 只留下文件夹类型
                    if(lfs.attributes( filePath , "mode") ~= "file")then
                        --根据正则匹配到instanceId
                        local instanceId = string.match(filePath, ".*/([^/]+)$")
                        if instanceId then
                            --如果匹配到了instanceId就添加索引
                            for i=1,3 do
                                local endday=now:adddays(1)
                                local day_str = endday:fmt("%Y%m%d")
                                local db_path="/data/ejdb_data/api_hub/db/"..instanceId.."/log/"..day_str..".db"
                                local coll="log"
                                local index_type="s"
                                ejdb.ensure_index(db_path,coll,"/ct",index_type )
                                ejdb.ensure_index(db_path,coll,"/user_id",index_type )
                                ejdb.ensure_index(db_path,coll,"/api_code",index_type )
                                ejdb.ensure_index(db_path,coll,"/api_point_code",index_type )
                            end

                            --清理日志,托管版本用户只保留30天的日志
                            if(instanceId~="default_instance_id")then
                                ejdb:clear_outdate_log(30 , instanceId)
                            end
                        end

                    end
                end
            end
        end
    end)
end

return _M
