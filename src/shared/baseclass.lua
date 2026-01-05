BaseClass = {}
BaseClass.__index = BaseClass

function BaseClass:new(...)
    local instance = setmetatable({}, self)
    if instance.init then
        instance:init(...)
    end
    return instance
end

function BaseClass:extend()
    local class = {}
    class.__index = class
    setmetatable(class, {__index = self})
    return class
end

function BaseClass:isInstanceOf(class)
    local mt = getmetatable(self)
    while mt do
        if mt == class then
            return true
        end
        mt = getmetatable(mt)
    end
    return false
end
