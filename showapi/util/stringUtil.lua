local string_gsub = string.gsub
local string_find = string.find
local table_insert = table.insert
local stringx = require "pl.stringx"
local tostring=tostring
local type=type
local string_char=string.char
local tonumber=tonumber
local _M = {}
function _M.trim(str)
	if(str==nil)then return nil end
	if(type(str)~="string") then
        return stringx.strip(tostring(str))
    end
   	return stringx.strip(str)
end

function _M.split(str, delimiter)
    if not str or str == "" then return {} end
    if not delimiter or delimiter == "" then return { str } end
    return stringx.split(str,delimiter)

end

function _M.replace(str, old,new)
    if not str or  not old or not new then return nil end
    return stringx.replace(str,old,new)

end

function _M.startswith(str, substr)
    if str == nil or substr == nil then
        return false
    end
    return stringx.startswith(str,substr)
end

function _M.endswith(str, substr)
    if str == nil or substr == nil then
        return false
    end
    return stringx.endswith(str,substr)
end


function _M.empty(str)
    if str == nil or _M.trim(str) == "" then
        return true
    else
        return false
    end
end


--16进制串到 byte数组转化
function _M.hexToBin(cc)
    return (cc:gsub('..', function (dd)
        return string_char(tonumber(dd, 16))
    end))
end

return _M

--
--local a = _M.strip(" abc a    ")
--print(string.len(a))
--print(a)
--
--local b = table.concat(_M.split("a*bXc", "X"), "|")
--print(string.len(b))
--print(b)
