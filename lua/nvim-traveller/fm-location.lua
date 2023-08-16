---@class Location
---@field dir_path string
---@field item_name string
local Location = {}

---Create new location
---@param dir_path string
---@param item_name string
---@return Location
function Location:new(dir_path, item_name)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.dir_path = dir_path
    o.item_name = item_name

    return o
end

---@return string
function Location:to_path()
    return self.dir_path .. self.item_name
end

return Location
