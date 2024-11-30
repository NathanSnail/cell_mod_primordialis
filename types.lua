---@alias target (integer|false)[]
---@alias generator target|(fun(self: Patch, location: integer): target)

---@class (exact) Range
---@field first integer
---@field last integer

---@class (exact) Patch
---@field target target
---@field new generator?
---@field name string
---@field range Range
---@field location integer? this is set when we find it at runtime.
---@field enabled boolean?
---@field data table<any, any>?
