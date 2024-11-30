---@type mod_calllbacks
local M = {}
local ffi = require("ffi")
---@type util
local util = dofile("data/scripts/lua_mods/mods/ce/util.lua")
ffi.cdef([[
typedef int DWORD;
typedef short WORD;
typedef void* LPVOID;
typedef int* DWORD_PTR;

typedef struct _SYSTEM_INFO {
	union {
		DWORD dwOemId;
		struct {
			WORD wProcessorArchitecture;
			WORD wReserved;
		} DUMMYSTRUCTNAME;
	} DUMMYUNIONNAME;
	DWORD dwPageSize;
	LPVOID lpMinimumApplicationAddress;
	LPVOID lpMaximumApplicationAddress;
	DWORD_PTR dwActiveProcessorMask;
	DWORD dwNumberOfProcessors;
	DWORD dwProcessorType;
	DWORD dwAllocationGranularity;
	WORD wProcessorLevel;
	WORD wProcessorRevision;
} SYSTEM_INFO, *LPSYSTEM_INFO;

bool VirtualProtect(void* adress, size_t size, int new_protect, int* old_protect);
void* VirtualAlloc(void* lpAddress, size_t dwSize, uint32_t flAllocationType, uint32_t flProtect);
void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);
int memcmp(const void *buffer1, const void *buffer2, size_t count);
void *memcpy(void *dest, const void *src, size_t size);
void *memset(void *ptr, int x, size_t n);
void *GetModuleHandleA(char *name);
]])

local info = ffi.new("SYSTEM_INFO")
ffi.C.GetSystemInfo(info)
---@diagnostic disable-next-line: undefined-field
local page_size = info.dwPageSize

M.post = function(api, config)
	local old_creature_list = creature_list
	creature_list = function(...)
		---@type Patch
		local patch = {
			target = {
				0x48,
				0x89,
				0xd6,
				0x48,
				0x89,
				0xcf,
				0xe8,
				false,
				false,
				false,
				false,
				0xc7,
				0x86,
				0xd4,
				0x03,
				0x00,
				0x00,
				0x00,
				0x00,
				0x00,
				0x00,
			},
			name = "no material regen",
			range = {
				first = 0x140000000,
				last = 0x140000000 + 0x100000,
			},
			new = util.join(util.rep(util._, 6), util.rep(util.NOP, 5), util.rep(util._, 10)),
		}
		ffi.C.VirtualProtect(
			ffi.cast("void *", 0x140000000),
			ffi.cast("unsigned long long", 0x100000),
			0x40,
			ffi.new("int[1]")
		)
		util.apply_patch(patch, page_size)
		io.popen("Z:\\home\\nathan\\Documents\\CE\\Cheat_Engine.exe")
		local num_mats = ffi.cast("int *", 0x14022b420)
		local mat_c = num_mats[0]
		num_mats[0] = mat_c + 1
		local default_mat = ffi.cast("char *", 0x1401d5d40)
		local materials = ffi.cast("char *", 0x1401d7420)
		local new_mat_ptr = materials + mat_c * 0xa8
		ffi.C.memcpy(new_mat_ptr, default_mat, 0xa8)
		ffi.cast("int *", new_mat_ptr)[0] = 0x54494f4e
		local num_usable_mats = ffi.cast("int *", 0x1405e1570)
		local usable_c = num_usable_mats[0]
		num_usable_mats[0] = usable_c + 1
		local material_counters = ffi.cast("int *", 0x1405dd570)
		material_counters[usable_c] = mat_c
		local spawn_rate_cutoff = ffi.cast("float *", 0x1405df570)
		print(usable_c, " ", spawn_rate_cutoff[usable_c - 1], " ", spawn_rate_cutoff[usable_c], "\n")
		spawn_rate_cutoff[usable_c] = spawn_rate_cutoff[usable_c - 1]
		print(usable_c, " ", spawn_rate_cutoff[usable_c - 1], " ", spawn_rate_cutoff[usable_c], "\n")
		print(spawn_rate_cutoff + usable_c, "\n")
		--[[memcpy(Materials + lVar15,&DefaultMaterial,0xa8);
   uVar13 = IdStringToId("BODY");
   Materials[lVar15].id = uVar13;
   iVar12 = UsableMaterialCounter;
   lVar14 = (longlong)UsableMaterialCounter;
   UsableMaterialCounter = UsableMaterialCounter + 1;
   MaterialCounterArray[lVar14] = iVar11;
   SpawnRateCutoffs[lVar14] = 1.0;
   if (0 < lVar14) {
      SpawnRateCutoffs[lVar14] = SpawnRateCutoffs[iVar12 - 1] + 1.0;
   }]]
		old_creature_list(...)
	end
end
return M
