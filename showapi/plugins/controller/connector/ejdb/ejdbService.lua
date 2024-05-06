local objid = require ( "resty.mongol.object_id" )
local cjson = require "showapi.lib.dkjson"
local pcall=pcall
local ngx=ngx
local date = require "showapi.lib.date"
local table_concat=table.concat
local tonumber=tonumber
local math_modf =math.modf
local ngx_now=ngx.now
local string_sub=string.sub
local fileUtil = require "showapi.util.fileUtil"
local md5 = ngx.md5
local fmt = string.format
local error=error
local lockService =require "showapi.service.lockService"
local ejdb=require "ejdb"
local now = ngx.time
local su = require("showapi.util.stringUtil")
local Object = require "showapi.lib.classic"
local type,pairs=type,pairs
local table_insert=table.insert
local re_match=ngx.re.match


local _M=Object:extend()

_M.wait_queue=ngx.shared.wait_queue
local pref= ngx.config.prefix()

local function makeJQL( query,returnfields,sort,limit,skip)
	local list={}
	if not query or su.trim(query):len()==0 then
		query="/*"
	end
	--需要对query做apply和del的过滤
	table_insert(list,su.trim(query))

	if   returnfields and su.trim(returnfields):len()>0 then
		table_insert(list,su.trim(returnfields))
    else
--        table_insert(list, " all ")
	end

	local opts=""
	if   sort and su.trim(sort):len()>0 then
		opts=sort
	end
	if  tonumber(skip) and  tonumber(skip)>0 then
		opts=opts.."  skip "..skip
	end

	if  tonumber(limit) and  tonumber(limit)>0 then
		opts=opts.."  limit "..limit
	end
	if opts~="" then
		table_insert(list,opts)
	end


	local str=table_concat(list," | ")
--	print("========================================")
--	print("========================================")
--	print("========================================")
--	print(str)
	return str

end


_M.db_holder_map={}   --用于db容器缓存

local open_db=function(db_path)
	local wrap
	local parent_path=fileUtil.getParentPath(pref)

	if not su.startswith(db_path,parent_path)  then
		return false,"the path is not permited"
    end

	local ok,err=pcall(function()
		local real_db = ejdb.open(db_path,"w")
		wrap={
			db=real_db,
			db_path=db_path,
			lut=now()
		}
		_M.db_holder_map[db_path]=wrap
	end)
	if not ok then
		return false,err
	else
		return wrap,nil
	end
end



--清除过期的日志。过期时间为day
function _M:clear_outdate_log(day , instance_id)
	instance_id = instance_id or "default_instance_id"
	print("---------------- clear_outdate_log  ")
	local nowtime=now()
	local del_day = date(false):adddays(day*-1)
	local day_str = del_day:fmt("%Y%m%d")

	local del_list={}
	local allFilePath = {}
	fileUtil.findAllFiles(ngx.config.prefix().."/db/"..instance_id.."/log",allFilePath)
	for index, dbpath in pairs(allFilePath) do
		local m, err = ngx.re.match(dbpath, "/log/([0-9]+).db$","o")   -- 参数"o"是开启缓存必须的
		if m  then	--说明找到
			local file_date = m[1]
			if file_date<day_str then
				lockService.callbackInLock("db_op_"..dbpath, function()
					local wrap=_M.db_holder_map[dbpath]
					if wrap then
						_M.db_holder_map[dbpath]=nil  --移除
						pcall(function()
							wrap.db:close()
						end)
					end

					fileUtil.file_delete(dbpath)
					fileUtil.file_delete(dbpath.."-wal")
					table_insert(del_list,file_date)
				end)
			end
		end
	end
	return del_list
end


-- 递归二要素： 周期体本身及延展
function _M:trans_vlaue(obj )
	if not obj then return nil end
	if type(obj)=="table" then
		for k,v in pairs(obj) do
			if type(v)=="table" then
				if  v.__type=="array" then
					local newobj={}
					for k1,v1 in pairs(v) do
						if k1~="__type" then  --不要这个字段
							table_insert(newobj,self:trans_vlaue(v1))
						end
					end
					obj[k]=newobj
				else
					obj[k]=_M:trans_vlaue(v)

				end
			else
				--不做
			end
		end
	else
		--不做
	end

	return obj
end


--通过回调方式执行
local stringUtil = require("showapi.util.stringUtil")
function _M.doIncallBack(instance_id,callback)
	instance_id=su.trim(instance_id)
	local path
	local db_path
	--if( stringUtil.startswith(instance_id, "ds_temp_path|") )then--仅用于本地分离ds数据库 , 所以不考虑instance_id
	--	instance_id = stringUtil.replace(instance_id , "|" , "/")
	--	path  = pref..instance_id
	--	db_path=path.."/core.db"
	--else
		if( stringUtil.endswith(instance_id , ".db") )then--日志操作时传入的是db下的完整路径
			path = fileUtil.getParentPath(pref.."db/" .. instance_id)
			db_path = pref.."db/" .. instance_id
		else
			path  = pref.."db/" .. instance_id
			db_path=path.."/core.db"
		end
	--end
	--print("path::::::::::::::::" , path)
	--print("path::::::::::::::::" , db_path)

	if(not fileUtil.file_exists(db_path))then--文件夹不存在时先创建文件夹
		fileUtil.file_createDic(path)
	end

	local   wrap=_M.db_holder_map[db_path]
	local ok,err
	if not wrap then
		lockService.callbackInLock("db_op_"..instance_id, function()
			wrap =_M.db_holder_map[db_path] --再取一次
			if not wrap then
				wrap,err=open_db(db_path)
				ngx.log(ngx.ERR, "-----------------------------open file ,path is : "  ,db_path)
                print(err)
			end
		end)
    end
	if not wrap or not wrap.db then
		ngx.log(ngx.ERR, "open db fail  ",err  )
		return false,"open db fail  "..(err or "")
	end
	local nowtime=now()
	if nowtime-wrap.lut>8*60 then  --超过8分钟,加锁
		lockService.callbackInLock("db_op_"..db_path, function()
			wrap=_M.db_holder_map[db_path]	--再取。有可能取不到，因为被定时任务clear了
			if not wrap then
				wrap,err=open_db(db_path)
				ngx.log(ngx.ERR, "-----------------------------reopen file ,path is : "  ,db_path)
				if not wrap then
					ngx.log(ngx.ERR, "reopen db fail"  , err)
					ok=false
					return
				end
			end
			ok,err=pcall(function()
				callback(wrap.db)
			end)
            print(err)
		end)
	else
		ok,err=pcall(function()
			wrap.lut=now()
            callback(wrap.db)

        end)
	end

	ngx.log(ngx.ERR, "ejdb doIncallBack result is : "  ,ok,"   ",err)
	return ok,err
end



--	保存记录
--  item要保存的记录
function _M.save(db_path,coll,item )
	coll=su.trim(coll)

	if not item._id then
		local objid_obj=objid.new()
		local ref_id=objid_obj:tostring() --先生成id
		item._id=ref_id
	end
	if not item.ct then
		local now=ngx_now()
		local now_str=now..""
		local misec=string_sub(now_str,11)
		if misec=="" then
			misec=".000"
		else
			if misec:len()<4 then  --有时会不足4位
				local dif=4-misec:len()
				for i=1,dif do
					misec=misec.."0"
				end
			end
		end

		local d=date(now):tolocal()  --可以优化
		item.ct=d:fmt("%Y-%m-%d %H:%M:%S")..misec
	end
	local ejdb_id
	local ok,err=_M.doIncallBack(db_path,function(db)
		ejdb_id=db:put( coll, item)
	end)
	if not ok then
		return ok,err
	end
	return item._id,ejdb_id
end


function _M.findOne(db_path,coll,query,returnfields,sort)
	coll=su.trim(coll)
	query=su.trim(query)

    local one
	local q_str=makeJQL( query,returnfields,sort,1)
	local q= ejdb.query(coll,q_str)

	local ok,err=_M.doIncallBack(db_path,function(db)
        db:exec(q,function(id,data)
			one=_M:trans_vlaue(data)
		end)
	end)
	if not ok then
		return ok,err
	end
	if not one then one={} end
    return one
end


function _M.find(db_path,coll,query,returnfields,sort,limit,skip)
	coll=su.trim(coll)
	query=su.trim(query)

	local list={}
	limit=limit or 20
	local q_str=makeJQL( query,returnfields,sort,limit,skip)
	local q= ejdb.query(coll,q_str)
	local ok,err=_M.doIncallBack(db_path,function(db)
		db:exec(q,function(id,data)
			table_insert(list,_M:trans_vlaue(data))
		end)
	end)
	if not ok then
		return ok,err
	end
	return list
end

--进行分页查询
function _M.search(db_path,coll,query,returnfields,sort,page,page_size,need_count)
	coll=su.trim(coll)
	query=su.trim(query)

	page=tonumber(page) or 1
	if need_count==nil then need_count=true  end  --默认为true
	page_size=page_size or 20
	local content_list={}
	local pb={
		all_num=0,
		all_page=0,
		current_page=page,
		page_size=tonumber(page_size),
		content_list=content_list
	}
	local offset=(page-1)*page_size
	local q_str=makeJQL( query,returnfields,sort,page_size,offset)
	local q= ejdb.query(coll,q_str)
	local ok,err=_M.doIncallBack(db_path,function(db)
		db:exec(q,function(id,data)
			table_insert(content_list,_M:trans_vlaue(data))
		end)
	end)
	if need_count then
		local all_num=_M.count(db_path,coll,query  )
		pb.all_num=all_num
		local all_page= math_modf(all_num/page_size)
		local mod=all_num%page_size
		if mod~=0 then
			all_page=all_page+1
		end
		pb.all_page=all_page
	end
	if not ok then
		return ok,err
	end
	return pb
end



--	更新记录
--  query查询条件
--	updata要更新的内容，
function _M.update(db_path,coll,query,updata  )
	coll=su.trim(coll)
	query=su.trim(query)

	local num=0
	local ok,err=_M.doIncallBack(db_path,function(db)
		local q= ejdb.query(coll,fmt([[%s |upsert  %s ]],query,cjson.encode(updata) ))
		print("pppppppppppppppppppppppppppppppppp  ",fmt([[%s |upsert  %s ]],query,cjson.encode(updata) ))
		num=db:exec(q,function(id,data)
			print("update id is : ",id)
		end)
	end)
	if not ok then
		return ok,err
	end
	return num

end




--	更新记录
--  query查询条件
--	updata要更新的内容
function _M.update_overwrite(db_path,coll,query,updata  )
	coll=su.trim(coll)
	query=su.trim(query)

	local num=0
	local ok,err=_M.doIncallBack(db_path,function(db)
		for k,_ in pairs(updata) do
			local q= ejdb.query(coll,fmt([[%s |upsert   {%s:null}    ]],query,cjson.encode(k) ))
			db:exec(q,function(id,data)
				print("del property:  ",k)
			end)
		end
		local q= ejdb.query(coll,fmt([[%s |upsert  %s ]],query,cjson.encode(updata) ))
		num=db:exec(q,function(id,data)
			print("update obj id is : ",id)
		end)
	end)
	if not ok then
		return ok,err
	end
	return num
end




--	删除记录
--  query查询条件
function _M.delete(db_path,coll,query  )
	coll=su.trim(coll)
	query=su.trim(query)

	local all,num=0,0
	local q_str=makeJQL( query)
	local q= ejdb.query(coll,fmt([[%s | del  | limit 20000 ]],q_str ))
	local ok,err=_M.doIncallBack(db_path,function(db)
		while true do
			print("delete  ::::::::::::::::::::::::::::: ",num)
			print(fmt([[%s | del  | limit 20000 ]],q_str ))
			num=db:exec(q,function(_,_) end)
			print("delete num  is :   ",num)
			all=all+num
			if num==0  then
				break
			end
		end
	end)
	if not ok then
		return ok,err
	end
	return all
end



--	删除表
--  query查询条件
function _M.remove_coll(db_path,coll  )
	coll=su.trim(coll)

	local ok,err=_M.doIncallBack(db_path,function(db)
		db:remove_collection(coll )
	end)
	return ok,err
end


--	创建索引
function _M.ensure_index(db_path,coll,index_path,index_type  )
	coll=su.trim(coll)
	index_path=su.trim(index_path)

	local ok
	local ok,err=_M.doIncallBack(db_path,function(db)
		db:ensure_index(coll,index_path,index_type)
	end)
	return ok,err
end




--	删除索引
function _M.remove_index(db_path,coll,index_path,index_type  )
	coll=su.trim(coll)
	index_path=su.trim(index_path)

	local ok
	local ok,err=_M.doIncallBack(db_path,function(db)
		db:remove_index(coll,index_path,index_type)
	end)
	return ok,err
end


--	count
function _M.count(db_path,coll,query  )
	coll=su.trim(coll)
	query=su.trim(query)

	local all=0
	local q_str=makeJQL( query)
	local q= ejdb.query(coll,fmt([[%s |count ]],q_str ))
	local ok,err=_M.doIncallBack(db_path,function(db)
		all=db:exec(q,function(id,data)end)
	end)
	if not ok then
		return ok,err
	end
	return all
end

--	get_meta
function _M.get_meta(db_path )
	local ret
	local ok,err=_M.doIncallBack(db_path,function(db)
		ret=db:get_meta( )
	end)
	if not ok then
		return ok,err
	end
	return ret
end



function _M.check_auth_content()

	local args = ngx.ctx.req_model.headArgs
	local token_file = ngx.config.prefix() .."/db/token.txt"
	if(not  fileUtil.file_exists( token_file) )then
		return false
	else
		return (args.token and args.token~="" and ngx.md5(fileUtil.read_file(token_file)) == args.token )
	end
end


return _M

