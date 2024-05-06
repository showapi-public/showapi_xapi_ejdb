local resty_lock = require "resty.lock"
local unpack = unpack
local pcall = pcall
local print=print
local _M={}


--使用锁回调
function _M.callbackInLock(lockKey,func,...)
	local lock, err = resty_lock:new("lock_dict",{timeout=30})  --30秒超时
    if not lock then
        ngx.log(ngx.INFO,'failed to create lock:'..err)
        return
    end
    local elapsed, err = lock:lock(lockKey) --20秒超时
    if not elapsed then
        ngx.log(ngx.ERR,'failed to acquire lock:'..err)
        return
    end
	local arg = {... }
	local ret
	local ok,res=pcall(function()
		ret=func(unpack(arg))
	end)
    if not ok then
        ngx.log(ngx.ERR,res)
    end
	lock:unlock()

	return ret



end


return _M

