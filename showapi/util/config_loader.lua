local cjson =require "showapi.lib.dkjson"
local fileUtil = require("showapi.util.fileUtil")

local _M = {}

local pref= ngx.config.prefix()
_M.loadConfig=function(config_path)
    local config_contents = fileUtil.read_file(pref..config_path)
    if not config_contents then
        ngx.log(ngx.ERR, "No configuration file at: ", config_path)
        os.exit(1)
    end
    local config = cjson.decode(config_contents)
    return config, config_path
end


return _M
