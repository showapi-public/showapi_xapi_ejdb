local type = type
local pcall = pcall
local lfs=require"lfs"
local pairs = pairs
local tostring = tostring
local string_gsub = string.gsub
local string_find = string.find
local stringUtil = require("showapi.util.stringUtil")
local _M = {}

local platform = function()
    local path_sep = package.config:sub(1, 1)
    -- 根据路径分隔符判断操作系统类型
    if path_sep == "\\" then
       return "win"
    elseif path_sep == "/" then
       return "Unix-like"
    else
        return nil
    end
end
function _M.file_createDic(_path)
    if platform() == "win" then
        _path = stringUtil.replace(_path , "/" , "\\")
        os.execute("mkdir " .. _path)
    else
        os.execute("mkdir -p \"" .. _path .. "\"")
    end
end


-- 删除目录
function _M.file_delete(path)
    --local ok,err=pcall(function()
    --    os.remove(_path)
    --end)
    local mode = lfs.attributes(path, "mode")
    if(not mode)then
        return
    end
    if mode == "file" then
        local success, error = os.remove(path)
        if success then
            print(path .. " 文件删除成功")
        else
            print("文件删除失败: " .. error)
        end
    else
        local files = {}
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local filePath = path .. "/" .. file
                table.insert(files, filePath)
            end
        end
        for _, file in ipairs(files) do
            _M.file_delete(file)
        end
        local success, error = lfs.rmdir(path)
        if success then
            print(path .. " 文件夹删除成功")
        else
            print("文件夹删除失败: " .. error)
        end
    end
end


--获取扩展名
function _M.getExtension(str)
    return str:match(".+%.(%w+)$")
end


--解压到某个目录
function _M.UnzipFile(_path)
    if platform() == "win" then
        print(" UnzipFile  ")
        -- unzip test.zip -d /root/
        _path = stringUtil.replace(_path , "/" , "\\")
        os.execute(" unzip  " .. _path .."\" -d " .." res/test ")
    else
        os.execute("unzip  -p \"" .. _path .. "\"")
    end
end


---
-- Checks existence of a file.
-- @param path path/file to check
-- @return `true` if found, `false` + error message otherwise
function _M.file_exists(path)
    local f, err = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false, err
    end
end

---
-- Execute an OS command and catch the output.
-- @param command OS command to execute
-- @return string containing command output (both stdout and stderr)
-- @return exitcode
function _M.os_execute(command,isfile)
    local n = os.tmpname() -- get a temporary file name to store output
    local f = os.tmpname() -- get a temporary file name to store script
    _M.write_to_file(f, command)
    local comd="/bin/bash "..command.." > "..n.." 2>&1"
    if isfile then
        comd="/bin/bash "..f.." > "..n.." 2>&1"
    end
    os.execute(comd)
    local result = _M.read_file(n)
    os.remove(n)
    os.remove(f)
    return result
end

---
-- Check existence of a command.
-- @param cmd command being searched for
-- @return `true` of found, `false` otherwise
function _M.cmd_exists(cmd)
    local _, code = _M.os_execute("hash "..cmd)
    return code == 0
end

--- Kill a process by PID.
-- Kills the process and waits until it's terminated
-- @param pid_file the file containing the pid to kill
-- @param signal the signal to use
-- @return `os_execute` results, see os_execute.
function _M.kill_process_by_pid_file(pid_file, signal)
    if _M.file_exists(pid_file) then
        local pid = stringUtil.trim(_M.read_file(pid_file))
        return _M.os_execute("while kill -0 "..pid.." >/dev/null 2>&1; do kill "..(signal and "-"..tostring(signal).." " or "")..pid.."; sleep 0.1; done")
    end
end


--- Try to load a module.
-- Will not throw an error if the module was not found, but will throw an error if the
-- loading failed for another reason (eg: syntax error).
-- @param module_name Path of the module to load (ex: kong.plugins.keyauth.api).
-- @return success A boolean indicating wether the module was found.
-- @return module The retrieved module.
function _M.load_module_if_exists(module_name)
    local status, res = pcall(require, module_name)
    if status then
        return true, res
        -- Here we match any character because if a module has a dash '-' in its name, we would need to escape it.
    elseif type(res) == "string" and string_find(res, "module '"..module_name.."' not found", nil, true) then
        return false
    else
        error(module_name)
        error(res)
    end
end


--- Read file contents.
-- @param path filepath to read
-- @return file contents as string, or `nil` if not succesful
function _M.read_file(path)
    local contents
    local file = io.open(path, "rb")
    if file then
        contents = file:read("*all")
        file:close()
    end
    return contents
end


--- Write file contents.
-- @param path filepath to write to
-- @return `true` upon success, or `false` + error message on failure
function _M.write_to_file(path, value)
    local file, err = io.open(path, "w")
    if err then
        return false, err
    end

    file:write(value)
    file:close()
    return true
end


--- append file contents.
-- @param path filepath to write to
-- @return `true` upon success, or `false` + error message on failure
function _M.append_to_file(path, value)
    local file, err = io.open(path, "a")
    if err then
        return false, err
    end

    file:write(value)
    file:close()
    return true
end

--- Get the filesize.
-- @param path path to file to check
-- @return size of file, or `nil` on failure
function _M.file_size(path)
    local size
    local file = io.open(path, "rb")
    if file then
        size = file:seek("end")
        file:close()
    end
    return size
end
--local dir = require "pl.dir"
--function _M.findAllFiles(rootPath,allFilePath)
--    local list=dir.getfiles(rootPath)
--    print("aaaaaaaaaaaaa  ",#list)
--
--end

function _M.findAllFiles(rootPath,allFilePath)
    for entry in lfs.dir(rootPath) do
        if entry~='.' and entry~='..' then
            local path = rootPath.."/"..entry
            local attr = lfs.attributes(path)
            assert(type(attr)=="table") --如果获取不到属性表则报错
            -- PrintTable(attr)
            if(attr.mode == "directory") then
                --                 print("Dir:",path)
                _M.findAllFiles(path,allFilePath) --自调用遍历子目录
            elseif attr.mode=="file" then
                --                 print(attr.mode,path)
                table.insert(allFilePath,path)
            end
        end
    end
end

--- 取一个文件路径的上级
-- @param _path 当前路径
function _M.getParentPath(_path)
    return string.match(_path,"(.+)/")
end


return _M