local ffi = require("ffi")
local tonumber=tonumber

local _M = {};
ffi.cdef[[
    struct timeval {
        long   tv_sec;
        long   tv_usec;
    };
    int gettimeofday(struct timeval *tp, void *tzp);

]];
local tm = ffi.new("struct timeval");
--result like   1535552984.4344  ,the unit is second
function _M.current_time_millis()
    ffi.C.gettimeofday(tm,nil);
    local sec =  tonumber(tm.tv_sec);
    local usec =  tonumber(tm.tv_usec);

    print("aaaaaaaaaaaaaaaaa ",sec)
    print("bbbbbbbbbbbbbbbbbb ",usec)
    return sec + usec * 10^-6;
end


return _M;