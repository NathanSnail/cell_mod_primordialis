---@class util
local M = {}
local ffi = require("ffi")
M.NOP = { 0x90 }
M._ = { false }

---@param values target
---@param count integer
---@return target
function M.rep(values, count)
	local new = {}
	for _ = 1, count do
		for _, v in ipairs(values) do
			table.insert(new, v)
		end
	end
	return new
end

---@param ...target
---@return target
function M.join(...)
	local out = {}
	for _, v in ipairs({ ... }) do
		for _, v2 in ipairs(v) do
			table.insert(out, v2)
		end
	end
	return out
end

-- this was ripped from noita engine patcher, so some of the design decisions are a bit strange for here

---@param page_start integer
---@param pattern target
---@param pattern_size integer
---@param cap integer
---@param page_size integer
---@return integer?
local function find_in_page(page_start, pattern, pattern_size, cap, page_size)
	for o = 0, page_size - 1 do
		if o + page_start + pattern_size > cap then
			return nil
		end
		local new = ffi.cast("char *", o + page_start)
		local eq = true
		for k, v in ipairs(pattern) do
			if v and ffi.cast("char", v) ~= new[k - 1] then
				eq = false
				break
			end
		end
		if eq then
			return o + page_start
		end
	end
end

---@param page_start integer
---@param page_end integer
---@param base target
---@param page_size integer
---@return integer?
local function find_in_page_range(page_start, page_end, base, page_size)
	local len = #base
	for page = page_start, page_end, page_size do
		local res = find_in_page(page, base, len, page_end, page_size)
		if res then
			return res
		end
	end
end

---@param patch Patch
---@param page_size integer
function M.get_patch_addr(patch, page_size)
	if patch.location then
		return patch.location
	end
	if patch.new == nil then
		patch.new = M.rep(M.NOP, #patch.target)
	end
	if type(patch.new) == "table" then
		if #patch.target ~= #patch.new then
			error(
				"patch " .. patch.name .. " has mismatched target of " .. #patch.target .. " and new of " .. #patch.new
			)
		end
	end
	local start = find_in_page_range(patch.range.first, patch.range.last, patch.target, page_size)
	if not start then
		error("patch " .. patch.name .. " not found")
	end
	return start
end

---@param patch Patch
local function apply_patch_state(patch)
	local ptr = ffi.cast("char*", patch.location)

	---@type target
	local new
	if type(patch.new) == "function" then
		new = patch:new(patch.location)
	else
		---@diagnostic disable-next-line: cast-local-type
		new = patch.new
	end
	if #new ~= #patch.target then
		error(
			"invalid function patch length generated for "
				.. patch.name
				.. "\ngot: "
				.. #new
				.. " expected: "
				.. #patch.target
		)
	end
	---@cast new target

	for i = 1, #new do
		local byte = new[i] and new[i] or ptr[i - 1]
		ptr[i - 1] = ffi.new("char", byte)
	end
end

---@param patch Patch
---@param page_size integer
function M.apply_patch(patch, page_size)
	print(patch.name, "\n")
	patch.location = M.get_patch_addr(patch, page_size)
	print(ffi.cast("void *", patch.location), "\n")
	apply_patch_state(patch)
end

return M
