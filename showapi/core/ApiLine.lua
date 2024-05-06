local fileutil=require("showapi.util.fileUtil")
local cjson = require "cjson"  --使用cjson
local Object = require "showapi.lib.classic"
local table_insert = table.insert
local pcall=pcall
local ipairs=ipairs  --取得局部引用
local ngx_get_phase=ngx.get_phase
local string_match=string.match
local AL=Object:extend()   --AL是ApiLine的简称
local prefix=ngx.config.prefix()


AL.plugin_list={}

function AL.init_plug_pool()
    ngx.log(ngx.ERR,"init_plug_pool  begin .................")
    local init_path =  prefix.."showapi/showapi_conf/plugins/init.conf"
    local init_contents = fileutil.read_file(init_path)
    local initMap=cjson.decode(init_contents)
    for k,v in pairs(initMap)do
        print(k)
    end
    AL.global_plugin_pool={}   --这是一个map
    local allFilePath={}
    fileutil.findAllFiles(prefix.."showapi/plugins",allFilePath)
    for _,path in  pairs(allFilePath) do
        local api= string_match(path,"/api%.lua")
        local handler= string_match(path,"/handler%.lua")
        local parent_path
        if api~=nil or handler~=nil then
            parent_path=fileutil.getParentPath(path)
            local plug_name= string_match(parent_path,".+/(.+)$")
            if initMap[plug_name]~=nil then
                if AL.global_plugin_pool[plug_name]==nil then
                    local ind=parent_path:find("/showapi/")
                    local tem=parent_path:sub(ind+1,#path-4)
                    local pack_name=tem:gsub("/",".")
                    local plugin={plug_name=plug_name}
                    local succ,plugin_handler,plugin_api
                    succ,plugin_handler=fileutil.load_module_if_exists(pack_name..".handler")
                    if succ then
                        plugin_handler.plug_name=plug_name
                        plugin_handler.ApiLine=AL  --做全局引用
                        plugin.handler=plugin_handler
                        --                    print("plugin_handler name is:",plugin_handler.plug_name)
                    end
                    succ,plugin_api=fileutil.load_module_if_exists(pack_name..".api")
                    if succ then
                        plugin_api.plug_name=plug_name
                        plugin_api.ApiLine=AL  --做全局引用
                        plugin.api=plugin_api
                        --                    print("plugin_api name is:",plugin_api.plug_name)
                        if plugin_handler~=nil then
                            plugin_api:setPlugHandlerObj(plugin_handler)
                        end
                    end
                    if plugin.handler or plugin.api then  --此插件下有文件
                        AL.global_plugin_pool[plug_name]=plugin
                        table_insert(AL.plugin_list,plugin)
                    end
                end
            end

        end
    end
    AL:run_in_lifecycle()  --执行所有插件初始化, 阶段是 init_by_lua_block
    ngx.log(ngx.ERR,"init_plug_pool  over ::::::::::::::::::::")
end


function AL.new(conf_path)
    local child=AL:extend()
    child.conf_path = conf_path
    child.plugin_list = {} --此流程引用的插件列表
    child:select_plug_from_pool() --从AL的插件池中中选择插件
    return child
end


--从池子中获取对应的插件
function AL:select_plug_from_pool()
    self.plugin_list={}  --重置
    local plug_conf=fileutil.read_file(prefix..self.conf_path)
    plug_conf=cjson.decode(plug_conf)
    for _,v in ipairs( plug_conf) do
        local plugin=AL.global_plugin_pool[v.plug_name]
        if plugin  then
            table_insert(self.plugin_list,plugin)
        end
    end
    ngx.log(ngx.ERR,"select_plug_from_pool::::::::::::::::::::"..self.conf_path)
end


function AL:run_in_lifecycle(...)
    local phase=ngx_get_phase().."_by_lua"
    local handler,func
    for _,plugin in ipairs( self.plugin_list) do
        handler=plugin.handler
        if handler~=nil then
            func=handler[phase]
            if(func~=nil)then
                --ngx.log(ngx.ERR,phase.."::::::::::::::::::::     "..plugin.plug_name)
                func(handler,...)
            end
        end
    end

end

AL.init_plug_pool()  --进行初始化，读取init.conf配置，但并不执行生命周期方法
return AL

