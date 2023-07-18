---@class Event
---@field dir_path string
---@field item_name string
local Event = {}

---Create new event
---@param dir_path string
---@param item_name string
---@return Event
function Event:new(dir_path, item_name)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.dir_path = dir_path
    o.item_name = item_name

    return o
end

return Event
