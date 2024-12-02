---@type mod_calllbacks
local M = {}
local ffi = require("ffi")
---@type util
local util = dofile("data/scripts/lua_mods/mods/ce/util.lua")
ffi.cdef([[
typedef int DWORD;
typedef short WORD;
typedef void *LPVOID;
typedef int *DWORD_PTR;
typedef void *HANDLE;
typedef void *PEXCEPTION_POINTERS;
typedef int BOOL;
typedef unsigned UINT;

typedef long (__stdcall *PTOP_LEVEL_EXCEPTION_FILTER)(PEXCEPTION_POINTERS);
PTOP_LEVEL_EXCEPTION_FILTER SetUnhandledExceptionFilter(PTOP_LEVEL_EXCEPTION_FILTER lpTopLevelExceptionFilter);

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

typedef enum _MINIDUMP_TYPE {
	MiniDumpNormal = 0x00000000,
	MiniDumpWithDataSegs = 0x00000001,
	MiniDumpWithFullMemory = 0x00000002,
	MiniDumpWithHandleData = 0x00000004,
	MiniDumpFilterMemory = 0x00000008,
	MiniDumpScanMemory = 0x00000010,
	MiniDumpWithUnloadedModules = 0x00000020,
	MiniDumpWithIndirectlyReferencedMemory = 0x00000040,
	MiniDumpFilterModulePaths = 0x00000080,
	MiniDumpWithProcessThreadData = 0x00000100,
	MiniDumpWithPrivateReadWriteMemory = 0x00000200,
	MiniDumpWithoutOptionalData = 0x00000400,
	MiniDumpWithFullMemoryInfo = 0x00000800,
	MiniDumpWithThreadInfo = 0x00001000,
	MiniDumpWithCodeSegs = 0x00002000,
	MiniDumpWithoutAuxiliaryState = 0x00004000,
	MiniDumpWithFullAuxiliaryState = 0x00008000,
	MiniDumpWithPrivateWriteCopyMemory = 0x00010000,
	MiniDumpIgnoreInaccessibleMemory = 0x00020000,
	MiniDumpWithTokenInformation = 0x00040000,
	MiniDumpWithModuleHeaders = 0x00080000,
	MiniDumpFilterTriage = 0x00100000,
	MiniDumpWithAvxXStateContext = 0x00200000,
	MiniDumpWithIptTrace = 0x00400000,
	MiniDumpScanInaccessiblePartialPages = 0x00800000,
	MiniDumpFilterWriteCombinedMemory,
	MiniDumpValidTypeFlags = 0x01ffffff
} MINIDUMP_TYPE;

bool VirtualProtect(void *adress, size_t size, int new_protect, int* old_protect);
void *VirtualAlloc(void* lpAddress, size_t dwSize, uint32_t flAllocationType, uint32_t flProtect);
void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);
int memcmp(const void *buffer1, const void *buffer2, size_t count);
void *memcpy(void *dest, const void *src, size_t size);
void *memset(void *ptr, int x, size_t n);
void *GetModuleHandleA(char *name);
void *malloc(size_t size);

void *GetModuleHandleA(const char* lpModuleName);
void *GetProcAddress(void* hModule, const char* lpProcName);

LPVOID TlsGetValue(DWORD dwTlsIndex);

HANDLE CreateFileA(const char *lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void *lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
BOOL MiniDumpWriteDump(HANDLE hProcess, DWORD ProcessId, HANDLE hFile, MINIDUMP_TYPE DumpType, PEXCEPTION_POINTERS ExceptionParam, void *UserStreamParam, void *CallbackParam);
HANDLE GetCurrentProcess();
DWORD GetCurrentProcessId();
DWORD GetLastError();
void ExitProcess(UINT uExitCode);
BOOL TerminateProcess(HANDLE hProcess, UINT uExitCode);
]])

local info = ffi.new("SYSTEM_INFO")
ffi.C.GetSystemInfo(info)
---@diagnostic disable-next-line: undefined-field
local page_size = info.dwPageSize

_G["hello"] = function()
	print("we are called\n") -- if we print too much the logs buffer will overflow and we die
	ffi.cast("int *", 0)[0] = 0
end -- this is the cell hook function

local dbghelp = ffi.load("DbgHelp.dll")
local kernel32 = ffi.load("kernel32.dll")
local function cs(str)
	return ffi.new("char[?]", #str + 1, str)
end
local lua = kernel32.GetModuleHandleA(cs("lua51.dll"))
local get_value = ffi.cast("char *", kernel32.TlsGetValue)
local get_field = kernel32.GetProcAddress(lua, cs("lua_getfield"))
local call = kernel32.GetProcAddress(lua, cs("lua_call"))

local function create_crash_dump(exception_info, dump_path)
	local file = ffi.C.CreateFileA(
		dump_path,
		0x40000000, -- GENERIC_WRITE
		0, -- No sharing
		nil,
		2, -- CREATE_ALWAYS
		0x80, -- FILE_ATTRIBUTE_NORMAL
		nil
	)

	dbghelp.MiniDumpWriteDump(
		ffi.C.GetCurrentProcess(),
		ffi.C.GetCurrentProcessId(),
		file,
		0x0, -- perhaps change this to dump more info
		exception_info,
		nil,
		nil
	)
end

M.post = function(api, config)
	local old_creature_list = creature_list
	creature_list = function(...)
		local already_crash = false

		local function exception_handler(exception_info) -- do this only on 1 thread
			if already_crash then
				--kernel32.TerminateProcess(kernel32.GetCurrentProcess(), 1) -- if we aren't closing just murder the process
				-- this still doesn't work on other threads :sob:
				return 0
			end
			already_crash = true -- hax to make the exception handler exiting not trigger the exception handler
			local crash_filename = os.date("./dumps/Lua_Modloader_%Y_%m_%d_%H_%M_%S.dmp") -- crashes :angry:
			create_crash_dump(exception_info, crash_filename)
			-- kernel32.ExitProcess(1) -- it doesnt seem to like dying
			return 0
		end

		local exception_handler_c = ffi.cast("PTOP_LEVEL_EXCEPTION_FILTER", exception_handler)
		ffi.C.SetUnhandledExceptionFilter(exception_handler_c)

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

		--stylua: ignore start
		local data = {
			0x48, 0xB9, 0x14, 0x74, 0x1D, 0x40, 0x01, 0x00, 0x00, 0x00, 0x8B, 0x09, 0x48, 0xB8,
			0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
			0xFF, 0xD0, 0x49, 0xB8,
			0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
			0xBA, 0xEE, 0xD8, 0xFF, 0xFF, 0x4C, 0x8B, 0x60, 0x18, 0x4C, 0x89, 0xE1, 0x48, 0xB8,
			0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
			0xFF, 0xD0, 0x4C, 0x89, 0xE1, 0xBA, 0x00, 0x00, 0x00, 0x00, 0x41, 0xB8, 0x00, 0x00, 0x00, 0x00, 0x48, 0xB8,
			0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01,
			0xFF, 0xD0, 0xC3
		}
		--stylua: ignore end
		local new_fn = ffi.cast("char *", ffi.C.VirtualAlloc(nil, #data, 0x3000, 0x40))
		local str = ffi.C.malloc(0x100) -- fn name
		ffi.C.memcpy(str, ffi.new("char[?]", 6, "hello"), 6)
		print("str: ", str, "\n")
		local function pointer_at_addr(ptr, shift)
			local addr_str = tostring(ptr) -- luajit doesn't seem to have a good way to get addresses because its usually not valid if you use gc allocators, we are managing our own memory so its fine
			local bytes = { 0, 0, 0, 0, 0, 0, 0, 0 }
			local count = 1
			local partial = ""
			for i = #addr_str, 1, -1 do
				local c = addr_str:sub(i, i)
				if c == "x" then
					break
				end
				partial = c .. partial
				if #partial == 2 then
					bytes[count] = tonumber(partial, 16)
					count = count + 1
					partial = ""
				end
			end
			for i = shift, shift + 8 - 1 do
				data[i] = bytes[i - shift + 1]
			end
		end
		pointer_at_addr(get_value, 15)
		pointer_at_addr(str, 27)
		pointer_at_addr(get_field, 49)
		pointer_at_addr(call, 75)
		for k, v in ipairs(data) do
			new_fn[k - 1] = v
		end
		print("new fn: ", new_fn, "\n")
		for _, v in ipairs(data) do
			print(string.format("%2x ", v))
		end
		print("\n")

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
		spawn_rate_cutoff[usable_c] = spawn_rate_cutoff[usable_c - 1] + 100
		print(usable_c, " ", spawn_rate_cutoff[usable_c - 1], " ", spawn_rate_cutoff[usable_c], "\n")
		print(spawn_rate_cutoff + usable_c, "\n")
		ffi.cast("char **", materials + mat_c * 0xa8 + 0x88)[0] = new_fn
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
