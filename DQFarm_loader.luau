--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu)
-- Paste vao executor cua ban va run. Nhap key khi duoc hoi.
-- (c) GnurtFarm — source duoc ma hoa, khong hien duoc.

local DQ_ENV = (type(getgenv) == "function" and getgenv()) or _G
DQ_ENV.DQ_LOADER = true

-- ===== luu key theo thiet bi: chi nhap lai khi het han / bi thu hoi =====
local KEYFILE = "dqfarm_license.key"
-- writefile/readfile co the nam o global, getgenv, hoac trong bang syn/fluxus
-- (nhieu executor moi chi expose trong getgenv, global khong co)
local function fileFn(name)
	if type(_G[name]) == "function" then return _G[name] end
	if DQ_ENV and type(DQ_ENV[name]) == "function" then return DQ_ENV[name] end
	if type(syn) == "table" and type(syn[name]) == "function" then return syn[name] end
	if type(fluxus) == "table" and type(fluxus[name]) == "function" then return fluxus[name] end
	return nil
end
local _writefile = fileFn("writefile")
local _readfile = fileFn("readfile")
local _isfile = fileFn("isfile")
local _delfile = fileFn("delfile")
local _makefolder = fileFn("makefolder")
local _appendfile = fileFn("appendfile")

-- diagnostic: biet executor co luu key duoc hay khong
local _exeFn = fileFn("getexecutorname")
local _exeName = "?"
if _exeFn then
	local ok, res = pcall(_exeFn)
	if ok and res then _exeName = tostring(res) end
end
if not _writefile then
	print("[DQFarmLoader] WARN: executor (" .. _exeName .. ") khong co file API — key se khong duoc luu, phai nhap moi lan.")
else
	print("[DQFarmLoader] executor=" .. _exeName .. " fileAPI=OK")
end

local function loadSavedKey()
	if _readfile and _isfile then
		local ok, data = pcall(_readfile, KEYFILE)
		if ok and data and data ~= "" then
			return tostring(data):gsub("%s+", "")
		end
	end
	return nil
end
local function saveKey(k)
	if _writefile then
		local ok, err = pcall(function()
			if _makefolder then pcall(_makefolder, "DQFarm") end
			_writefile(KEYFILE, k)
		end)
		if not ok then
			print("[DQFarmLoader] saveKey fail: " .. tostring(err))
		end
	end
end
local function clearKey()
	if _delfile and _isfile then
		pcall(_delfile, KEYFILE)
	end
end

-- ===== teleport persist: menu tu dong hien lai sau khi doi place =====
-- Join/leave dungeon = teleport giua Lobby <-> Level, CoreGui bi rebuild
-- nen menu mat. Giai phap: queue_on_teleport (neu executor co) de chay lai
-- LOADER o place moi. Loader doc key da luu tu file (dqfarm_license.key)
-- nen KHONG can nhap key lai, va loader moi TU ARM lai -> noi chuoi vo tan.
-- Dung string (khong phai function) vi la pattern chuan cua executor,
-- chay an toan trong Lua state moi sau teleport.
local _teleportFn
if type(queue_on_teleport) == "function" then
	_teleportFn = queue_on_teleport
elseif DQ_ENV and type(DQ_ENV.queue_on_teleport) == "function" then
	_teleportFn = DQ_ENV.queue_on_teleport
elseif type(syn) == "table" and type(syn.queue_on_teleport) == "function" then
	_teleportFn = syn.queue_on_teleport
elseif type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" then
	_teleportFn = fluxus.queue_on_teleport
end

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport — menu se mat khi doi place (join/leave dungeon).")
		return
	end
	print("[DQFarmLoader] teleport-persist ON — menu tu dong chay lai khi join/leave dungeon")
	-- BOOT string chay o place moi. UU TIEN fetch LOADER tu GitHub: loader se doc
	-- key da luu (khong nhap lai) VA tu armTeleport lai cho lan sau -> noi chuoi
	-- vo han qua moi lan join/leave dungeon. Fallback: doc source da luu local
	-- (chi khi GitHub loi / offline), luc do menu van hien nhung khong tu re-arm.
	-- Chay bang loadstring de an toan trong moi executor.
	_teleportFn([[
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/main/DQFarm_loader.luau")
if (not ok or not s or s == "") then
	local e = (type(getgenv) == "function" and getgenv()) or _G
	local rf = type(e.readfile) == "function" and e.readfile
		or type(readfile) == "function" and readfile
		or type(syn) == "table" and type(syn.readfile) == "function" and syn.readfile
		or type(fluxus) == "table" and type(fluxus.readfile) == "function" and fluxus.readfile
		or nil
	if rf then
		local ok2, d = pcall(rf, "dqfarm_source.luau")
		if ok2 and d then s = d end
	end
end
if s and s ~= "" then
	loadstring(s)()
end
]])
end

local KEYS = {
	{ seed = 2258642189, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2262320411, exp = 0, plan = 0, hwid = {} }
}

-- ===== base64 decode =====
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VAL = {}
for i = 1, 64 do B64VAL[B64:sub(i, i)] = i - 1 end

local function b64dec(s)
	local res = {}
	local buffer, bits = 0, 0
	for i = 1, #s do
		local ch = s:sub(i, i)
		if ch == "=" then break end
		local v = B64VAL[ch]
		if v then
			buffer = buffer * 64 + v
			bits = bits + 6
			while bits >= 8 do
				bits = bits - 8
				res[#res + 1] = string.char(math.floor(buffer / (2 ^ bits)) % 256)
				buffer = buffer % (2 ^ bits)
			end
		end
	end
	return table.concat(res)
end

-- ===== giai ma payload bang xorshift32 =====
local bit32 = bit32
local function unmaskSeed(masked, key)
	local s = 0
	for i = 0, 3 do
		local kc = string.byte(key, (i % #key) + 1) or 0
		local mbyte = bit32.band(bit32.rshift(masked, i * 8), 255)
		s = bit32.bor(s, bit32.lshift(bit32.bxor(mbyte, kc), i * 8))
	end
	return s
end

local function decryptPayload(b64s, seed)
	local payload = b64dec(b64s)
	local s = seed
	local n = #payload
	local out = {}
	for i = 1, n do
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		out[#out + 1] = string.char(bit32.bxor(string.byte(payload, i), bit32.band(s, 255)))
	end
	return table.concat(out)
end

local PAYLOAD_P1 =
	"34Z1Wiv+WoTNYFUnymk8z93S8MM3FkbBTX6epfe9YasW+71tpRFPsLlx5gNTr9zXl0McEF//CTdBmOYs9DOt1OZvadj2kiLGznxT" ..
	"JJaLkzzERrkHsUwPTB+GhK631ZAHZTKVakbR193kRWsQdcn59/lyw552+wArDzR8Iw4m6c4kYqd3Zl6KwvwoaWBZhEwiZVhqQJoC" ..
	"MV5OwLFh5a22RWAF3qIfoXv77FU2uBHEszbyVJdSGBVETp0F3ZnxItWvAoDEHi8RbG2CIiUesH7AcpipUxPsMkkrK3Poc1ruPmc2" ..
	"j0FO22XLKtxlcBJNBop/ZO2Ipt9iKBvzCEXA1zn6R5e00RPvzU9erNz9Esxv2ckk4wXQ7viauqS9HrnvksaJTp5675IhXD7XMlCS" ..
	"XIxI7qQSRQAjGBWxYAx8pXtUxKHIEGmgY7dXqgUhOS2JwL6p7vp4p6TYoaBKM239WHg8tTnF9rDEY3hphI7sZjtGFqS7zdY7mH/5" ..
	"wEWXeM7vS+YpxQIb7GoIWAFstRgfiwlWJbVZXaw/8r7XzYvo2HLzwCo2qbiJZssnjXdHnfy2k8STCqs4Gu49reJ5/TsP2YKfXQuH" ..
	"kaCUpT1ah2SDGP8/aQL0aTl2zqtzMZbsfVE8mkplkojWGqS/UpTcNcat2Lp9DOzbb2bhBpCa1gi39Vg5ktMiUBuFVj6nLJ1tr+V1" ..
	"DdmLwmVXSfVpnCHiDwExnxFZvVPqFSZD9MlMdbU/tRxhpAjeKzuuQLP+KpGXMyd/S81f7OG2DhDOf7OH4aUcsL01eb056PcdRSOO" ..
	"mbsqIDec0/AzGO/aINSTiEt1EQ3zvgsW21p6SJGpuV0Vwn04lbCDdb3wNWqQLZ2nTHMGzT5DjancYehfJ1zfe9YFkYEIWzPWw7Qk" ..
	"JQ/3uo+KMrv+I1YoUAxe5alr2/wM+Zvsmeb3YmUdXyLb1E6trgi6YbOcfsjoIUWxSH/PXK5gs/wZLV6vBRV0+VP+t4s6Xhk2ea1m" ..
	"9oaWCz3UWEZlG6MnSsfzhFwPJsumRalQxghXjFl8VtKHDR/91wpEZv+/gYbPN6LkRhGk8hJXw3W9Sz/IOwXEiT7uDE0CnHqQAAYM" ..
	"nznMTdGGahw1bg9A3OxCMhhWpOxMOPwiyZGVAK/thTPueJIzRAhPL8tNFgovtgseECCJ7POxvT8fKvpcVnkhoPmClDAVSJq446ML" ..
	"X22hRXeeROtDYACwLSlKRvuxDq79Q/g0QeMnpeQXxK2NNUnLhWPdRuuroU1yvOV33SKVQcFKqYfJLEyM/qGnoVi36+HJ7cVj8yIo" ..
	"9lRjld6WpSG2nU+KcOXum2cEGDBaHV5x0uGIIKhIzH2wyEiJdnOX05Z4VjBajP5YPG5qQ/uIluJQ8SCXtZaAPZPRxp6tskGNe4aB" ..
	"S1Bp5lsGfLjQ6DDmW/+ETwrOBdLHP80ZSfaJrMVzzOeQFAXWXNNR4jifF5DjI1WyMnDYtiiV6N6GnPEIYINPbEhoiETfQ5tdqq0L" ..
	"fsfbiAo10ypscZ85CfQqdsVDt1so1fUykwoPkjTZfOSifwDiMD0ZZMQnLcIFzliuM9uyqtMYYGuYKRDUNAHs7Dp+iPoFJCjQkcHw" ..
	"/EFcA/k2cNU+Lrt5fhlH6w1XXnTcXsdmNsVestUkIVWJznFxAPwvvzWQKBD57XztPFattEGa7wWLQaNLFeRLLjjW0DIU3atYyQ3W" ..
	"Q1as1S1MGJQlfw9Sr8CWIhKDAFn5/5CnsFKgFB27F4JdC0kIjWYKcW04n67mqYNKwYRcrdumrriZMIAHTEgGkrIALtIUQUd/xMap" ..
	"KOjVaG16Nt1Ap/qQOZK/yzZc+MzdmpR/Z9qMHnfHAlODxjah/dTySuHGdUsVznSXDRDuxG91i0EmtvTNncDJ1QffyyUnvId8zCL5" ..
	"boayxaCF0Pcxf+xeYmojSRHCW5UjI3zkOTweLC5JejOpOQyqJJYptGTzWWvjPK8dccdc9BXT4pKJ8IjMjBg9dy5bhjBoLJ5YCDqJ" ..
	"Fw7WIb/R9OfUowLNvXon5dHujEIZF+a43Hy9RknoohrOwbygwVdu7xZfBgKEuEvb2qfpCPp66C1ycTdW3MT3l+uXlFQ3Gp6aAeu5" ..
	"h8Zq52oo9JbCXZrCwmL75edohx6SSIGX2K/n3Q1rIQUHDWjcDybHk9wx9gUUUXKLBDtbPRI2ATFcKjf+TvYg8QGH69WtS/oXmN8Z" ..
	"FR160WL75oz7PHBAYp8vPSViwdXtTVe4jjK9AWc2s0ZzORKozDDGHYGto+7lg/tLjqvqZAqPpplgdjzOfG2ELhTN+S2QGMbqNdcA" ..
	"j1owF+NsnzX3Ztu0Uhm7x9FFCDQKblFlKMy1RTLZVusv6/J6gFk5r/X/xrQy5+6jF0rAN0uj7ZkIvNv4PobV59jgJopxVhWnAFRN" ..
	"rpnuq7cYhnyhDMNc+GPqHTmsre7rVZ/WxtzSoaEtxBT7K/t5MSI7S/L/goEagHRbEKRmyNOnYWtfITwGXRIx628sl1g3kxlCR6Du" ..
	"Xz48rCrOf/msL/gU8AUgIAufpsIV4MCXP+UBZsNHRAYqawumgc5Swz3lPY7Nsrr124mNHGyTjqHRQLbiN01ifxh2C6afr9xoYozD" ..
	"z5SgnOnOld/d4rkQnqb7BOt36H9Wory+g5InlWYJ26BtgEEh1lyXKRlMl+27Ejz981dqeNQr/O+a7aSNNICzwsZ9ho4Fg/AieNg6" ..
	"GKUY1KFMIlp5OalmpYy/p+o9f8vcCAX+WAhx34Kvj70VEFhJ62j6FLs9DqGfXk5SBBvhihjf4E1dL9jZAtLSCUY1xTHuMbsnhp0C" ..
	"Wu63Tah0CWvhLcF22Nw1QQDyFBTUr7TNsmXpbEmpj1bimMuen6ET31SQdkzPIr/L3z6q7DcI5VBfKd7R7/AnlFX0P8ZgxgB4D708" ..
	"F7gXEwkWAOpe3ub4RYBcSGhyaR9rI7GfDXIsEIOhwpqDCcyVCMDENkzlzVg1+tebPetULF7YEf/2oRjNB2d2iK6GMAZO+t7okJHA" ..
	"ROOgkOImWv1ixJRHVhIc0DHn3/uoWtWXyDwjE4us6ZF8ZWNtlcQoIedT7h81mIPA3KIS9XxfreEf7Hp2FqiPSwWLMeOBGJpx2SpV" ..
	"PLCGqVy1tAo7O9v03YD5zylfoFWXBgVb5LU2iu0uQ8T7u9/QyRyNwjHaTGJXuB7RHDLBu1UWrORajaoeJVFaVBZCH+LDg8uDNZI+" ..
	"XRWLdeWqMwIKbNrURi3t0/RIMeDZGdbrV7FpDllfiaVSHbW7GkQfpEHZFPIn+D8a1loNH4931LHLPDG6a4p7VnZ9QF9b+yZiI69C" ..
	"gwCPjGKBZOKNH2hY7SP7MrrZt3EWZMJS4oR4zv5/KyUlBbFRQahZ/s0B2O6XKZh/1paLVRhT6736cg60AS+QEObNsWPsUgb2U4KC" ..
	"Q1Rdqm9Ayv8yz36ZYjwzlFF8oNZpQy1qmnlbX5ndlNSEJS5SpbHA53ikKG/TsAIAePiSNY+fCj6oEDhrRtDSTYcDlOPoz6lhBs2J" ..
	"nDh3rWmXgf5vo7f16n8X4abIVO0qVjQjSCfCWj+snP1V1ToiOkFSzrGONDxtTNUoSNYJc5M5Q6RUY1OPCeKw9RHja3PLpIpEEu9n" ..
	"3KEQAFqMH4oG1o++xxPcij+SF8isgV5H5yiYzXbDJ+AxtahvX9zUktN2EWCK1GcgGi1+hwqIEakyO2gRrL527NUT5Ndzxm0oAJE3" ..
	"drFb99VzfbcMpIlnYEFjKU3FOM63yTuGcHGdLQgJs9XdF9hGtVBMwtlsMmaepceEV5z+2e6/LiZn2fbpwNH5LhYJLb6ETWvWAel1" ..
	"wLimmoJ6zkYD3HepPsbokbPVCOK0q6HRsm+poQdwSTCaXI/tBfJWaLCD4GvmaJYWzBKB8lXGHlcR8nj2ZRnSXQFhF5jJlsxPjP4e" ..
	"9+zDivYESCQS3t7RxdWrgwZVsZJpEyOnKYRQlGknnTGyHpBSqecl34PqMs2xukXkZzsJd6omYnRCK3V1vEPsM+dCeP1le9QjxiCt" ..
	"QPcccxLJ80hlbxwbooETf8qLCWbE7sZCKlH6/KOLeOzV5MkYvog4zD4hFkQrJYJTW2UXwgrW9u/P75GxnRbsTmBq865Quv+7t7yG" ..
	"IQH9zX3vyiqyOlUmtvh3ibD7dXqa8nsrlu8uvJPYTo/0fms7RQpZv17JtMBGu5Cx4NAJrn28c80Awn/AK1snJK08LwN10so+kha7" ..
	"E/J045KGjGGQmtzGy4irsGQnLI/TXvMs3umgxWOP0ulHAfQ1zLtRFcylUf0n2MQp2Ndpf8rri+HArUFzxcrLbKNCn66kR+v/Pwl2" ..
	"IS47CWyCoy81f2dKDhLkJ1NPle4TgUi0Vhj/FoiudGGa7qPhOrcn38iIyT4NgwwzLn0a8mlAY+Pp+xAG8VL5K9sdfTk93ujhDvYU" ..
	"Mi65zNmpAJUxWHkVsAId757iZSu7MTsM9aMQ3/r+jl3Sis6kEBMkNXTp4OA4zJV1B37NwvOmr0D0m0z9ACt19gqrusrBZU8cs/sV" ..
	"7yN9ThwTi8GOLQ+k7bY0lj7KN5VtwgsPN98K9WsOmBvNk1tz5ZoVslXlWbhgZC5j5wkXZ4x2jzyPpfnywQUY/qHza3Mxz7R005Ri" ..
	"5Ot2+5k15SEmZ3P71m8ic2MtHZjWFrOctAScKa7FeCw1ToYquNwHWMzaTIONQpMXIrPLSNjgqMdkkh8Ta1wyZlA/cS4/oN22P9H4" ..
	"Co/18rWYbGJuyqDlOFAHzcNAraeiNc1m6TCW0JTyIF30QUcuW4KqApM1rgKaumlws1ooijh4/6StBN2z5Uta1dVshSMyPE+6MrTA" ..
	"PcEm9Z0ctiJdBWNVt4pbQwhrFmWRrI23VWLsa3JHxiD9Ky219wI8NKsBHea52B1fG+bHpqdcA0ObhdK7eMO7awXlfPlXR9gmZAMv" ..
	"/YgR82x77lrUBYHgaJ2siZpTVH0BVa6CeXjKuFcRP4mIzQjSyES1yystT5CRkWpmwo46cjLTieQ76Kow2PW1TOgeuvyF2wUSoC39" ..
	"WDeqO5hEzhBbbp4Bm2Jc9RWX6/3DCLBf2Ln/vFu11mAMR52yG4bIdES8RzdzxxHCDW5OeZdvWXSBLeZZ7uRoxCNQfV08BaxQoXUU" ..
	"073fEZCT61DN91lK+OuyZUhigRmZ+2HnobVN03jqEk2YTeyovStuoiZLMGgpWqujLKWBbLnbDKQJDUcDRFuNZJC3tnMUnzZh8kXV" ..
	"XqxkTlF64VhiJ1qmSSJYmqZVEdu+Y8smyBCl7dP04GoPSJ7Dq351d/CuuT4+c7mFSAVwxaOeHz5pWxYlsTBMAlCDh3UDpv9Lic3d" ..
	"ZGdju1ryrNfhVZTTpHt3g72V2EvywOJhUSZcs3Osqq10Ho/7ZmEyv9CDXRHC1sFZbwtuoOO9mCTD/D7dzlWkOPLtVatsNQVMVqQY" ..
	"tyZrXULqecc65q5O/9RnZxOdIbetpJe2uDVOBE55WtwgMiwr20K+n8zUQOmwfPGvvb9eiL1p/D9mRQB07PKfstxV5//g8ycAYKsj" ..
	"M/CWHtgIySudXTJbzDh4a65zuLr96UdcqDX0LU1rIfedCDmptltBeCfdcRp8uGXWBer9UgFe9kSFG202+AK7AryVU3i2F05b5ljE" ..
	"eW9/u1N8g/IchimBzRqh4RFLlCW9rIH5wQcAYfLWxNqsGILqqyvtimNceGAfFqWDXyKZmtD+RtTv8wXIIM3GaERqzxXNXUXsgvVS" ..
	"NqsQ8fIQ0KhwMYEu4ZRYm3cSRaNxS1CIp9JZFjS8vxOKyShn3XdiY5HGH177l07JROk8rLIYlVBsKkxz9wPk+Xv6pcgZtt3PPgRt" ..
	"5AsPO4KKCY/sMCoF8q8t7d5VC1qlYDSPVzVyR5LXKoeBaHSuwbBpHzZlJ9diLeXjkR8++nFi5d+b5tBbQiZ6zm1kjhQ+6dLI2070" ..
	"URlOQKxwQ1LjAQ0boxIVi0dWcI9d9S4g+I0jdw27UYrPnLTa69my3raVow5Y+A2UiYwl7mI93vr+1EDZz0bXhDOUoi9VDFF+/7Tk" ..
	""
local PAYLOAD_P2 =
	"lR7w6tmJXuFkw+OI/ZZFOVpNvKrtLHUNta0e9ZyYoGGIww83ziXWck2DdbnIwKtlSLLyIiiYdn5f3gywyod/Jtbfx9a7ydrHapFd" ..
	"U/5Bk5g5lJh90NnnNuW7DPQsTyvm5Ne8yDUXAyL9j27kzh/lzROTIRLBzIjW1YVJNPs0ksnE3DqQtJfr/YM4j2lldhh0PEcLawYk" ..
	"EDxKz+Ka/VvhojWd4I/n+CKV0TtGg7Vs2OhbTR1IIBWFSu9e7mlF57tsczwUac0fQ3TkmOJvCDdUu9FuZBVlhM5dOi82upWqZHmS" ..
	"iRWUF6D4z72cxYvy55BEoWHyNZpOZdYgmhpG3QPtry8WmSf4DN+88dVpM2flNP1eoDLjRV4VGbB+C2zDudDfiY4fnBgJrlkYeTUQ" ..
	"wLw8uxCz8BH5khFJE+GIHXWKReXV9sJFR8HKbWh+mpxqmkt7xuL59HuYCkPobzpb2WXnmAYlXhdkCO68ZzCauH7JEKrx421NTeXD" ..
	"x9Sbpi+t8zASZn43zY8Kr4POfF8jurAQZ6supkB2V8XGmK6DYJtSIl08KD8Cuv4vMyqJSb+JvQBdjEZbQrs2cM2vSa7W2atNUEs2" ..
	"XKERBD1b1uXUt3Gs/N0HrfckHOfDcJyOBnGLoBWBQI6QoIH7eEryfkoDshbUM112beX1BkcJ1yZTT3NqqRSSvGhXuI2B1QZWl4cV" ..
	"I2yvPGb6JDHSrcPQNkMzq6xaHYTuCb74QitRTG9k1iBGYYFlI+p6BEnzq8MMpUCfkJFvOgnMvhZNlHWYdnvfQCbpF1WdPgA9ASC9" ..
	"eSPtLB86QaTyZp/zsHVh/7RciEw1ou9AASS5w4Guy/6ciQOU/N2716/8AHnm7xAxIAm9neoBmWgjK5tg71ATODFTZB6pwGi8dTFs" ..
	"opVkIMzUpRKLJhQ8k5SMYiNRs/4qgAW4a/hbpQwxwEoxeGNnjbQjKfB8AGLyTz/mTNxXvW6Onkxnt75+gLI8dAQH8X6d0uzimH4m" ..
	"6iJSm4fmcEqH+L7Kh8cThSD8MKVWP0QrBr/D9/R7JlZiLR7q875aRaX6KDSs6bSaim0zzqHO9glAu49cMrJ0Ac1yJgpzuzXK8iVC" ..
	"02mt32VM9UqXYs2C8XS3C/vSIaeMA6sLnth034VGTl4WFvCcgKgVB4WC/LMV6sc79sD25WdxScaehhCKrRwRSN8kkHRikVk95zbC" ..
	"xo1x6tB2l60sxpfukCKsaaBTDxc9swg+in6WmRSGYLjgqv+pDgxHNwOVEa4WlvKy9sS1DfsKgFr71+kWpGvGMQHQEePORtrrMMbO" ..
	"K4KnfUG7UHvNlRqFwWsdwvgAStTgtAjzH0GxP3IO01rROA6TrHICu/il1OG+kTorWtpMFSkoMfj0M0KUNQ1Nto1MPh2MvCdTFwFe" ..
	"LDxU2PfKOqEMp1+l5usow5YDDFBHvOwNz8KPbsylfZKl+GkvcHUQqrxZdM6wFvRh9px02jLnXKekkyIeoR3YK5Xs0bPsMuV+TgAR" ..
	"bfNYgGXXubwhIyWwFh2X/UjAZS+t2ILU6QIeV/lO/QmAExwApR2pzlBi1hSls770DDQSE4XXLtBnjNqJ3R1wGY5pAz7s94uC/4uy" ..
	"wrO7UkyISp1/dZIY3Ps0DkImj0y5nahj/iNNvY+m0o89hC0LLzyrnjEO4NYIm/zXcjMeYBFPY2lqaX8PZ6cIl5tCkWlADmAVD13k" ..
	"YtwCuhUijauIK5AvOCv4nOdV+FrRCjx4aNQM5Vg/ZV6UovKjz5bTZyWUIKdVHzd6a9/D2zv3Qelu32f+MiiR/XbM+D1/m0Tt6YaA" ..
	"U6VzDxgf+sLRvcqcCwOibeejujFn9foZgA4odQZblPLmm6h4C38iF665nXkAEnCEDxLbFgO34k6mCzANowhF7MJrMOHCHI7pxiua" ..
	"Dgk1a2eH+/U0wyk1xIwbmMOTVRFGjYfZN8MtXzUMUMGEq80ljFQeLkfW1Q/xLpYYoCHyA3BWos5MVC+qBEQgKFOMIfDl5/+4EFDm" ..
	"HzP+NfsZu23fUgSoPLCXgz7kaWADBDr2E4wy56KtcoNamKAyd2DUShlsU69FIGCT1kRO7hcBXcB9+FFeXzfauwA4YRzMcQHF9/E6" ..
	"Y7GW6qIQSCApFwVB9seTCak+G0hDqQFAepheQqHFxYY1+dGXZByuwHn0HaxQIbI23j9dZEkp9mleekwNuUf4vvNGEbq29+s/qa8Q" ..
	"+NHzw3OcfPWJ4UgF7nN0Z3VS3YGQjzsDUq4yaSl3p9AcEMd1M0Ar4RvhLBqaXpjmPgAaBQ85/nmg97yICoc5ZKjyCL3gZyi0CntJ" ..
	"70AUECINtNtsxteHvbI+s3e6ukPwzlZNRCcu2Tt5QRdQYDJoThNsYRsuKPBGMIRFZ69RJKg0vP3ODCoRpun7pfcm6s7uRamfLOng" ..
	"FhN79oZgIVn0/fvgEF6n743G/PpcT5DBsDsT062U/9Unc4+P82ANuwfvyBPt2deLjn1h0Irx05zXyAW/wgtnWQMxoV/fhgSEdHfs" ..
	"8O0nsNg0XtKJC7TliOfUQCrBiDJwiL55XahYODIyGeUTbchcYOBP66POIkFWSutkXpHDJLZ/8xi8jEiz6X4z56Y9iHvVW2mBvfL3" ..
	"XCcxkuu2bsj0MXAU9cimgiCcilsfIqIR+9BBj+JQ9JP0XIY1OUq1brcwFC1lFV+yzr/VotYuFGL32S0WhukKr02EIOf2rAPvP6CD" ..
	"RYjltjm6yuf3eIznkqH0aZU1mmKh+BIUpAM7LuH0Xgyr3+ZXrZeRZCqh1wxvOiRXGkLQWAlNIqqZEYaCBBY9KrOsrKhsmFyyjF4n" ..
	"qUhIFy2w6mK9I/k7FWPPGgCed1oApihEDj/j6N5DKnbkApqACt8ukZtFmmg5jjX5ylG6l0h38Va16wianm9ndWjLqyKFoUNwMH0d" ..
	"a8PlugMcSX4kFKYLUZa/KlSHXZ2c+jCRfZP9Ia4i0/i1U64uaGWgIj/tquYIqvhwKrQr4RJ8RQZhoXqSTExBpU1REA5zE/rIexei" ..
	"Qh56SFEmz5l9JUzVXcpHPFZh4JLh1DMvaSRcAcfxfovEuzufJ461InrDVHE9O+uQH8RXScK6ZMb8Jb5L5ynJqO7rwNf5Hbbbi+yk" ..
	"EqLLJ14s+5AejHm0xIHLpE+YqukHOQNLtSgp9LlaGjvPognLVSL66XZ2L3qxYPTzJiQJnNpYZ8/B2KyHj4E+m1rsnOdL/c5BnPrB" ..
	"bXlx0D1T6wxksyQJpokXmc18r4MPxI6mBec1Lp767+BTR9W24FYVTsSI76gYz1yQTvagasGUSV+j5F6ElTYYbRPqD7+1DThrxzCD" ..
	"gS0KOHkdrk+i9Qrw5BAtlWQFmNo/iden2f86xwh8F0LjpQqyt3tq/uRPJ9lVwXWR21ApU6JTzVS4jGtpWB2oGv8z2ASj6WtTvPod" ..
	"nmiX+Sn0bVjJlmYF+KOC5tkKgVpjZqDfSmpFxwPyRESjSiF4xaoUUmaxndsl1cloG+jSUr9G7ky9B8P3ysC9RlxT51fk8+yjdhSY" ..
	"6ffZBmH7bC0MipD17kNHca+Yg8+K0vAb9EldGdgV5e5uLKKv2/YzQgS/oT7mBvRn0bLsqd2JHVf0LoWRon5v3Jk8BxegToJmm9Dt" ..
	"8s8x+NM3z4Wi62XqQZWQRwP/ERHznNk1oI9EuJNQnh+G2W+YM1h4AffUv+qR5iN626nRFQScSSxNZ5CHQHZjzb3nhG0GCXjSVXMi" ..
	"nTMzdnBCpZGdzJyuY7IPrH+PhGGFbb3tKKB9JiCPooGHP2h5afW4D2tDxTbamJsWukFfoxqOca+Bcg3dyMOTdZ4sYR5t0RVvgC0Z" ..
	"W1RE5eXNqxIm9F3WyjM3Qk80gTASsyIYWS3v3kNXsE82DXWt9aCQjnfbHvJoMOFAXrzMUVxfhXPrhNhNcAu6cevenGjGjB3Dyozg" ..
	"EtK4eyeYWfSxUgLbNHqicK+Z0hVGLJOLRrFOuucZyIbRgZQJKGbieUTGYsg8OqIi/2SZyLYq6pngyyWx76RoIOxC7Q16JXQ+yL3v" ..
	"SFYl7kRyuwi4nGG8Kf+6BUWxjUqMa05Lydw0mRjPdNpFKixhFsb6fWnUzRsT4HhYqUbrvsxFTL/YQGbXKCc3isXHNYQZ7sgIbqdo" ..
	"hcdSQSbECXMd5jQIgjexjfmdlCIWQOgZl35s6+1FK6pBsaR+lklqkMI+jYGVBfzvLB5KU+/+MAdwTLXhPz5vHSQA6O2oMTJLNYBW" ..
	"t2JXCLScD/4Vu8P7YlxYsvsVw0ifymkCV30j+MdnAA8/tQsDcI8FkXrQS6Yese/QzfTiBC9JsNCWUuDoTVQxersh7jOJgMeDWo79" ..
	"MjiOJLOaP3DNMT5mKV1XpfN6tGFhsani4R/uSYP9qZ/h+2CRTqfuXytZFjdwXZ1U9IX/J8EHdcRoamOm76Aq8XlRC9hrR0zUfZm+" ..
	"hSDj7TOtBA9n1NxO8I067XnsHWXmPdfsdRXhY38F6aTUb+zk501acXOoRGugwx7fc70pBlolJkEGRguXP+QUG8VQDWKghfE//uAh" ..
	"ET2enLY66Ga3B7gSLREhsdhe3tuy4AiTuO22VFdBjh70y+NFCZtvvIF3aij/Q8HXIWy5mYn7msb8z4KxqoYOlBuyMSv2uqldi8TY" ..
	"RFUzPTyDYHwcJCIqgqTbSrJmkVvNN3lMOFamc54keLSyaLA27rqI73zSk75uZBV5xocE8XhSVKFk5u/afsCTzcaze+wwI/JMyaYv" ..
	"iB4INo+wDxLItzC4HLba6XBrF2t4w6EXtF1ipCS+MNp5kDFoG6WSYbZezkVeOYKIAyHz5rsEovwYsiniL7ZRB1kiEh99XTWEqKh3" ..
	"+PvxRJL5oe9r0ZlexMaqvdi/G6l39Wtbd5X271L6i9HnrAx8paDdf3rgjiN9K0bQ2VqkfGS6KsCTbHEUmwY+AxhNwdQFFzuweSUJ" ..
	"uHhvQ6rD90iZ4UpCmozK6IyDKeRMlYRkMeHJ+HKbtgcITvpUDbPDVs3nSAfGLV66gj/v14rrih1kTtJ3okQEM/b6mTNtjC2icLqR" ..
	"QnFhsbqdOOdVAerOmRUdp1mPeRJ6TLy2JB77ME6cn4qvimGfQSP67PpbzDP8F8+HR1FEvfLUchQ9MvP6koq+t43ZCgqgXiKYf4HR" ..
	"bZ/SyPIsWHCAJ9DdIbBEOHOhWo2lwxKyaa16saKuzZLRx2L20uVJNJZld3b73Dt4vmiYVbskhoQ5YAC0XIdgds8p8TqfjhRnVqLR" ..
	"rFHQJO/S3H5ToBnkFNwujLhV0t75bDI0sZdishSRqLyCv9M7EQQmx/myV7LDLnrQNr8nBCHAsxiImSWlfZSouOmIbH8VQDUTQFU3" ..
	"0TImMNSn5jUswtLW4HXm0GVs72lVnGX1uSYiV7ZQBvvMJ/sdYoVLzeQ9IErQWSWPt8SEoxLhytrislzEY+zexzS4IaDZe5eF57dJ" ..
	"uQRjsglCbHiITarnJOM9yr5Nj1NM5qnNzMkClQorjSt9T0NWNfUI24lXQ90+Kpgs/VrkYN/O11hamKucfhoVIyIjcVMfr5e3JLya" ..
	"eEBnfJAR2pM/bH+ZRC659i04Oj3hv8R7TxkdBm4fC5TD2DCW5mku0Dilpw92fmYkqwWJtF9XU5gYp/+mM6u/Jgoxqz4UPj31gZv9" ..
	"EuR/h9d3hYLrZT1JN5q6XUebHLjAMNNo0vdtDkeUEIO05rvLE3hj/iJbmgk19jB2NOnjtobNYZPICvvFW2fWF2/ZSomYujtEF3vx" ..
	"NAu5YSy4YIEbH1uzm+VfoHAo3pgE+Jbnm5qOhrlGeLs+BzwbN2MXmwP2dpYNNpLSmu9hOPobXbRUmIrOU7Ur9fQ3+k1XV3GglDKi" ..
	"SIdDpXpRBes2b1Z4OfB6yhGbTKcwu+oDwu6P0Gw4+RIfIleF4gaTbv1XVhFxzPlLT39jGtpWKE/h7VIegVvMxnTre0tj8cWn5mXE" ..
	"dxZhkjfCr59UcbRb6M1pxnjn0AMJpfWjWCA2Ijnvqfa/TtTRObQpcmei0G7NuRlPLJjGY0Sv2JunN6kBtChwLOmbDzbvwTtweLzY" ..
	""
local PAYLOAD_P3 =
	"ArA6GboCKnl5az0vCnvHdhyZkrzbf6ipgmn2lHG3ZBwwiL6k86B7IPRhKlkjGH7yrAJn37kbOD2CuHvi49004Eyk6OXuy5+8rtcj" ..
	"AUDDwStlXhLupSqJctsuuiQA3cDda/DWSCOIIVcO7NZ6Lm4Vhkwn+H4eZEYRBOZWwzMcxRxwBmaVSa1D5no0QBl0HYoMTKSbaLYG" ..
	"Qkvr3zg2jVwRqWOOR9mf+NpkPogfkv2HbAtHE640xhpQrL/66bUl8AqSCqKw2kPaWo/b6qtj6vSy/RYRul3nOz6x8uhnE3UWx9+K" ..
	"dV+JIzoGBgxxkP2aFXjNB3we4GbAnIfmw7z8iXd2ADzIulu4p26EP2BvdbpdfFoQ0kAXBC34mko1UWoDdCRsrZ8qbsG9QAbNgWZh" ..
	"s9C0pmbgWRL2yP5tKnLMk+9L6Eimg6krcfAXHIlwmRvSESMBlMdvzqGY7NodcwCKGdfGN4mfuGTV7rJVEXZVgcO5KK62pwx1uOVe" ..
	"9woan/CeoOCLH8T2xFVg658umVgP+2qotr/GxfVbo2dQL/CwS+b6IbMCC2WEum6/dowewCxXB8IWL3XW3/vvomwu/S92oLJeMsp9" ..
	"RMsEmyRyaKHXz6WwQRrCuGqusrTm12BhZxc1jAmvL0wwad4Zo9WUVyAQD1F1b6R82pif/P1KJLXJH51Z4zrgmzdWF9jG8uhEkkhv" ..
	"ayhSPmVZYnVJUq2pPf1fxtkQLSuOKRe7F3Imivogp7Y2STg11asmYZS2earHj0f7ngrXfnTs4kW48Q7RHsnVShKCxzDZsSSHhrQf" ..
	"eeUnsnw/t4S2Tdtax35KLzt5t6JGRO40ZM0a42rb0IylYKJps4Rsccxa4IK+sQulor2ZCQexgOHmJUybfOE63I0uAbdkkDBYRUlj" ..
	"44q4lUKlBXTd8rxyb2bhPJK/fGjD0jqfEXdcxUcoFWgWi/whylN1s+H6hSK6qdYIE15O++zqz75YuvocUX6v3eGPynEHoEUHaFGa" ..
	"TOspi+TiVKiMB6R58AhhhRBOhWhFMMCYLJ+2r5ZhgmscII+3eeNlOv7kowjbriZ8N+sB8ScuIVvvHz/dbOag6pdRQMRa3q+4ddvq" ..
	"sU0vJOd6YtxQV/cyy5w4wWxrCE/dRJ3IJZ2RECp7T/74sNdids5brSufpcTDX08bfD1DyCvH7LYFuul7DCqW928HJvwY6sa3SkaV" ..
	"17cogs19NHeRqUYQHA39XkKZLaykoIvAj/s/0OmThA/9j+wCoO4TU9DfiYNoEDFT7khTXhTzW15mmh1ANcbshtwm7VFA7D7G+tBw" ..
	"JJ5De64jC5Dner+Ncjt5jMbvIR7BNXv6mklw6FbbVmzfFkgSSSTZP9/ktuSRRFoWjmP4vjaZFYuy3yPRlKwkeVz9EbCY7A0AS0sq" ..
	"npYlrK0FugNuDW30HXDQrMzPP/7P6//tE437AkeY4NNM9lY1FCT80KG+dQZuy1awZK2BZeRTlKUYu+UsiYR/VXsWpCGp+nw+PdKA" ..
	"fqVx6GLDIdrFGO55L6XhQW0+2JjJ/ZR38OvUP0jIximmIIQWe1m2tjKRS1IEN6VaDX3V4NL2jTDaUW5TaGBJeGwzpwGu7D10IskY" ..
	"jw207nYSy21jGJEKKJ8tZBHFLr9qfEHyIy3+b38lPHQLkE7yaYeTHhwDyO/8O2nIqvwSZRURaEd26GiGEnuWvd67vkENHtmchIdg" ..
	"ATAGL0H96Rk0DBrDwe1sLCRosOkfs6ewotP2gHXPa4csaLUwRwoljEYYQ/nQSFN7eyFWGgjQeGcwP5E4aegK+f1XkhiQS/iaFDJr" ..
	"hjzabPWhaSdi6hMbKVSk+ROosdh7Ig1akbM02F4H0N6qq5VvsLpL5C0AEY4h87XgxE02tpJP3OkEs4Cw3gHd27uYtN46q3oaoA//" ..
	"OThj1EeKyI+xBdZJ3/9whdOPsYxZEz+jTRUo/nIxbHWiN9qSoZKcT1dNVxRGiiDBxCuJyERPDEJvCEDw1bhN4vx0sQ5qffcf6Lwc" ..
	"Eovm+Q7bYQHt5UkVCFEgdGLbkk3VO5Xn20ewtuB41K4QVwEvHV3l4bQt/nqci01I+Izzdu9oO4uDVSr5wPSM6maNpF2T7FA3aPht" ..
	"L8iLyG+jNWyU9CO7pnubK013GgHRFZdhijmcTh0CXj3N18hFZOZs0C/ukylSe54PeGqZZ0by3XjwM0dSN1hhqu0U24TZFms7Adj4" ..
	"UGcvqXfy2qB4lc2P7uU2XImslgJXkC+xvciWlXiYkGz2tcVX9nVCQ0Ms3bDLP4sfWzFBQMGLxl4IPZt7PUjaFjvo8gon9zr4xjsp" ..
	"S4JaHR6szaCCa05V4hpMiuYHA+0csPJwBNx7egrLnnA9goKKblOulyfazcrY/n7VxM9ACz/51Dz3tQrst0T4tJrQaPM1UYab2xhF" ..
	"7uJ1vZrixaw2EPVez5HUuR8I1JkFw0omwdBVelnkpsLf5nDGYdV2yoOFs6NOWWZwJWiILCq204qSIeT2k1qxQAlTxdtzUfODFmfY" ..
	"eeq6aJ8i6Doys6gjIYanh6gwsjW17KFECZNVudi0iij7Z4yd22xXzEj9rj4HhYpXokohiDcZZR7Ha7CsTgsXNBtFru6RB80O4HSz" ..
	"x3lJthgov9bgzRp5T2u/uWeFagMhPHtwA5NHOek9gW5OfVr+lTip6Nkn7DWKJ/tQC14IfBut/VfoYlE/2U8yZu9XnKvV/gqEQBTm" ..
	"V+NM7k3v0ibaSJhgezCyJNqz8Abm1brtMZxZNBRE2wN5+rzjMhuBWBnOVT55TkbDhdQfcO69c7dfWuldNuMqxzb1Yn9X3jLCabfN" ..
	"r58YkwASurnDEA19oBId3Z+gbu08x5lrnyMaWFNt5ukV52wmHYXf88Dt+/KOzHSrYV/zKcDcS+Vq1k9Tj54/Nn2c/1w14/Ss/kUr" ..
	"pMRTP4ApbsAUyxTfptEhONS6HTxyEWtZa2d19MrPGr75ucKRM4lCrUV/0X5fvM3pfjEZq/o8m3ITSK5T+x0aFaXmUuwUP7+iO8Ln" ..
	"FsokUliGKZzoaJHG7Wfd+IWErP+KBU3Qg4fI3mmWCJt6T7FJeNJWJEuwFZ0ZKG59nGx8bXMYOrTrSuTnBLKuxtuuZbkA5x8eWKUx" ..
	"Z9HQOEoIZXhrxzSocl7HEfd2k7AQ+/Jhp7hIbVocDV34MiGNEyfsmO+YOaDpy5AYYe1ll5I960yAvy9TGFudDM5nXbPCiJyX/P58" ..
	"S+CBNafb4FmO3Kgw1mhs8fNWYSkLWvCXpXX0ZpHxfGc+ty08AfopN8Kb1QBJnlWxK1kCbxOObY0HSIXEgDqsBdHzXdIQpm8x91pS" ..
	"1aUjaZ9PI3+F1mDrSQjX2gEZVUsvOJ/DJIuFt4EqTntQpiWibFy3mCVInFXXWuL0X137yCmJ35dVu4JWFUT00WLTP5s4v6OqvudG" ..
	"SMQkfCBUmt/m0arGht/+1fRI2DWO/5L3NIUll9N66CfRs7S2vgthZIbBBjrpCER/IrNzPfmtoIQ7JKvdorU2y4Jx5n5eMF7AYhxC" ..
	"8ZNZkkKRVIXuvIibxrA3+U3KQvMfBZNV4xEUJ9mUVqrTKOtQhPDg3bfmMn4ppL8SjNBNaLzPSRfPQsHs75eefZQ1HZZDrToQj4NB" ..
	"kwHNAHZY64CJ4C/2EYG10bz51IiELyguuCMg+ZRxPES4FtP+DbGUB7J1n+6bNgmMbVrYFUe2wJXD3AZQFH7q772JWZ2CHZZrPbDx" ..
	"iLOCghHIRalHsrp+oLGb3TKmsksn3WveHCWSKsZi6E6AT1my2XWf76SYwcJ/IvRhubVXllmRzohU+fi8NDYKsa01KGOh4WnHchZF" ..
	"YNvGYPYy5N25xSW+ILLwyq1gIhTGPmwMUcLJ9LPP76b08O8xwf8H1onZyu6nKAmbIiIjHWX44EzHG5bxGRCL3lE0i5mQ8AszRS3I" ..
	"RRnO/JL/M+OucFzEHDCjmuv/qOv3RjRyqZpxwzlqtbMaVvTmq/ZR2HwpfBEjsY+DLkQf7k0TliN/OHgibVYl8bdit04kN/qXSrcb" ..
	"AzlZa/j8FPp3ENhG/redoer6dEbmMuB9hsJqABedOj9ECnqCRkLuF8HXvnYxSzU7T6vY7HL3K69BreF0NqzidmJvkRE8M6ncaE6h" ..
	"0eb441n0rYX3qYOAe8Nkw8DHH1v74DIlqMDT/qoj5VwBDsobxkYqrx7aXPrnE3oYxi4aXr9CIQnWJ9YLBffE/oMATGwUYUV2EtLx" ..
	"j3HCL2LV7AMGBMIE82UbvhO8IXlKAb2mNnLZ6ZMwRclIhkwT+TtsEleVSWWT6E+vS+jX1VnZoZUdrN/8KBb+6Exu2K1r5qJVT4ba" ..
	"1+DILM31NbSID7Vj78GvmPC8pcAEDBII8Gux7XA1UMs0wr5cTem9JuGGZJQqEjNKszZJKCIs/9DMUVVVcNWJWiOtW0bExLbvZpBC" ..
	"99arhod+fHrL2tg+rZruTJ/xENerkzOwN+xU3ICqeVnWcSJ6PlQXLE2+ZTOKyGZviqDCyDVjt3BPow5+QWE5zEyaSKjzMHtG2ZbD" ..
	"pl7d8aDIZWaw/tLZQd3qxhNIueeGVXaxM3JkL4U+NjSns0yhHFbsMj7moRWdqLdMHRqnGzQZsmtYQkAqOsPY6IVn6oMyURYK4AhM" ..
	"BFxEAN27SPslQ+Pc3NCGZgiN4XlWD6gVHDRFrBBFVYnEKoZLuA8cWiYm+Ui7azOoFugSWdLQEdpoSr6AAp596MgOttBP0+yvrO04" ..
	"GPAA63YSzRK0Tpn1bDsh6zccNBFRrRYAedSVHny/K8mnEaZl8f/Gyn2cWhjsgEUYp+afZrPx2iu9WvWmrjvHwocjR38HyOnIpOoL" ..
	"jwePHE+gavKV65kqEY/xTEGDVVExjitazCgvs+XXebfux3otOsyUYB++POQ1XTTbg6IoEA5OuHOmWhqwbUmff4t/FUlcAXEukN9r" ..
	"Sq0i7lzHKO7bSQfAIxnTmKEhZ/avuHBwFVewS/oBnXPQ/Fq7QAJU/T0MHBanrVIaYNomSVFbNwfg77HAwunuHVMGnSSCyLeEEBJC" ..
	"JL+v2cq2QHX4N6wLI1kZk5P/TGyQ1PgzOyxNR58vOL8UpNXxEtSMHW4SOBWu1SHsg1VCk+Trf5oCRx7tAZ7DM6VGRd1gNYtu5uSX" ..
	"Uw3z10zmVEquY3Wey9NOERMw5zesqnnUj3aoglimNCj7/nX/rzei9dYu7+oDIVWiylKw6qo0kdtbXT4kVd1dozCxhIlIzHb8NTHR" ..
	"Cyaa3oiIiJasHafVXx46Vg5z2ZJUSc1ttBxLVKRJbb75zdZeW6B7Hd7+7St1tNwUgnn3eDm11se+KPcWuNLuhPsbdEikNnqd3h66" ..
	"KL5BXkbmkN5YXjWsSZvYXGt/8/G2tcxj4l2hu5SaTZZC3/bgDyxIaQo9cTPcantCtCWifZPw9U+38/ouzuqqAaQ6pqqGzTfo6Sds" ..
	"lo7ZPk8CfcCCNgipeleqkty9i+qGsibCBVQKZ57EF/BrFaGQGdJUEBrJtn15UwLFpC+ICj1pgIt/7KNNLsvRXNL7GLuSrl4zzoPc" ..
	"5BIAHjDSM1aqw/q+VdQv42eZyC5wurR/GmPhx00AnH6XUg5bylGF2gsmSJDdndOkFYVqr4W2XGLHIVG7PIRu9EUYBC/Tkar/Q2rS" ..
	"hK5aCOruSaI/1giqraeKq2MPt61no1q0oF9MRSIGFU8mgmyTJMO0Vcamd0zwLmrl8x9P76/n2E3HeKv81sElz1eaGuEcSXvfUuKm" ..
	"1b4OJlCkkeM9YAWnmrThzhKkoftzujDtLD0u6s+zO+oXNaeT5NpvrR0ym/9FMsoq7qlWCM8hnIzPOtn+Sy11MtOp8XaRNctfRg9z" ..
	"+Q3nLqrKmGMzKJaDSae7sWg5mZO7lpJmBnqWdfP86Etl2xt6g8eVrPMmmAAKbpxN8GJaYaTly82XCrK94EsY0ROraoBQucs7k81X" ..
	"OdSOvyB+JG3r1CAWcQa37X8BVeSi5ZqbWv4XhLZc834pMcka4wZP3O9yzwa8bbj6gsLk/0GdWk9FvFqApyvPVQ3LGX5b6udKYNnL" ..
	""
local PAYLOAD_P4 =
	"AGeJqEL4s7k5+HEgVH0r7cD7pZyhV+r+ff9HPIUVjvi1r8W9yhj6kOwlZv3OS0vJrCedri8UlCw6gBai0JAakvfmVwmYAtN+AOK/" ..
	"d7Gnw+ZcZjNg/5djAGkaVZfPn253obJ5Kw5jJmJK3FdGQcR/peWjzEWlgnDLqPo1Iv2U6ryZaqfnaXx4QYMh1UsQY0UMXmlvDuif" ..
	"d6yR0M+Y0Ras96jQrJjshb8pUwnjpveCA0Ax0D3CP7MB0ASBdXL7pjfYuHdB8aLehwqNmhrZjuFBlalvwoEpEoTLmXxIXgc0lr8r" ..
	"9Vy7g02aLYljsMvUZidS7LowvMczXTmd2AjscjgAHBHkJuSS4h0KFVIGf9SyjAEYHl/DpsIBRwZFBkWaywzAWjz2Wws96oH6ADYl" ..
	"Aoc0nVO9Gyt/SiCjwcnuHv5sYHvtZBPuZChdOUv0td494i99YaP4a/3cGILGMiqxx0q2Klh9rjIhRqiwObXZp3/ae10HboNvg/Of" ..
	"piLLzCyHwUmN61wIK/pnJIY9ZKIjfIh5eQHXEG1LRBAU4+76+T0SVp45ZOkvj7BzV1W81yeSVCG4m0o9YAx3qjJc6inRtKd9k1d5" ..
	"vIwT7wOijJ/uHCGzqSvKKwMg2yED7nYb6R2jToG5oDToMcCYltj81aEEZj+Ifjse6KYbgmLs4kD1cve0myyzvMSBtTrS+B5ULdft" ..
	"XnaQ4Loa9xNwI0+SJQeFY38D48a0tC6K1cZQE6SYRfVBaixBo8EPYd2tIkQXrHkyGVNiDMYEToX7RM/nmoxH+1n15RodjfrfZZTl" ..
	"zLJT5ilwXXJVdOeWaV+P/zM+mEH6Fvs/UhIU/8uD2VjDTcVmjHbThMF2lHS2BxRNITJ9Hzv9BFfA7Yle3d9f/ZnioJa+3AUTimgX" ..
	"QMj86QSl8EWgSUCs5Aihp1XrYgRTMgmEoVaPFhV+iCISCPSRCjIeDpq5EVKnNRDXttUDIKR6GkM/qwp7b9HjLn6UpunyRyoPQl19" ..
	"sVGu/K36A9dQT+kYLgHfji1x4C5KC5JJyaU+Q8szHNUZ3ZS63baRvBQkj5fAS3/y+pc3c9WimpmVS4uljhTVnPlIh/jXxcNmcOnx" ..
	"VvPVznpibam0/WCK5ooS+o5J1Aby8IvkVGxa6YRm/DWBCxh70X4/p4fNXvUHYkGiYN7KIhvBzuYAvKZAUGwyu26kal8aq5uYQMRx" ..
	"4uOp6dGmSuWjiwVJWbHc5dZukIEYvtAI4LlFQYSVDYn8bWoNK0JMaCJJutL3DomZfXOTrKAph/ZNVZI96FlBhDYmiL+jtpzgk9Iq" ..
	"63mpvV1fBwBn+F6XeqGB1114Nc8rOrWKoJYY/A7JNLy69aC1WPiZ4hUYceLcBRSWp4cWpy168M8tbYOcfwt/zpgpgM+YSkKO6SY5" ..
	"sIJijvMQS7KHs95H89bzDagDfSU6ln7Hy7TVDJrc0C5BpilolKhkBeqU9vMtWKMbUzp/Hbk/2N0k94z/2YUbIohP+hqIcrHOhUyS" ..
	"sh7b2lVHQ76+8xPYy9ZeDIJTiY5+Jmn17nuKwaABZCo/YAZP5Z/a9pPOifkSTUF/oPCDmT29Jt53MROjEYZCXjhJ7pcufSqAd1ZN" ..
	"WjapTMkSDcTwmR01Emncnd2QpLWcwPg5GMmcerWuxs0eovlf1ob5kc2fRcnLfiHVvz0qpKXy9DY6/rHZWmZl0qlY5aWSdTpI0PmD" ..
	"lTiFaDlokwZ+pdVN07wxtICLpzvskA+UzE5gsQxITykACCjC+RXx7mB1rdHu0iRoiorQgxIeam8vwZsva3zN0y+D6F8kmoUEEk3N" ..
	"ixPzfd6hQ/eCX9Vu35lNHAxOYDIfhfva6fmkgg+KVmpSAOX5SU6+DrrE6LnQYHi3fcMfPpuJ+k5SAJbZ4ouK+GSUxYa1So/+uv1a" ..
	"HgGUszDEvPg0k5yTa2cDNZtRYpdJPjL1HZE0G1dfZUEstFXFCeioWWTUdjrAd2zpMV5Es8CbO077X+LCCN0hqAchV0CrdzDXGayq" ..
	"Oa18Vydj2H6FkrF5RJoS7TPivKLr9/YeLFtJEdPtR8hpvvDXwf+73L+IDIw7p+lk7ON3m5iItbDFul/AoJ/hLWhr7MYleiPjw+MC" ..
	"ErbiwHNNDjJr0Z3T0n2ZG70sOHIwW00VofO1SEYMpR2ueyhs99/dqdcqLedf3uAeZ1QRez1ydqiT/AQNifj76PXOqTLelkSzHVkI" ..
	"raKlwdXOdcywy8k+4Alz76HsG3Gm+wC6IKJBdChjAOZ92elBxaLn2yTrKAXi6aFpZBBzbui2jq/XdqBodMFLoXotHO4Ul/7mTXPF" ..
	"1+0rwOw2VAyG5VqPX4vgqzoWj9Jq9wEnMs+/lDUndSn1kwUgHOnj+aSXiTgv1YRBtDUOJLSgw2NvHlL13aRL37gG3FD2o1GxjfHR" ..
	"achAl0PmV4dewEGehgHasUoBK5T4C8+/u0+cGeZ3lMfkVh2TJ8hkKQnG7pmc46fyq3Zi3+u+tVndb5mLXqD0EWZICtLQ8vKhB8bv" ..
	"uRRhfJr6bTJFwB/1WZ0JXrePR9n/SxFN/2bjrl7fBqTGvuBxKhEJ/muoNYQ07lCYft2RRHG4DFwD7xr6+4mueXq8ajpUP0g9j96w" ..
	"Cm/j5q/gwJwHkWYGLp2StlbVaQTJAS1FnPib+E5mahEhiJ2oInmHEPKQrFP2eM/UFdDS7LJJrfc+Y/2BzuLrTxP/+DXSWYoKnsR4" ..
	"HJrckgW3U6bkxQ2yRwvcNgO5Tdz3GWI6lhyxBs/5IjrfAB7nb+W5JTyOBsztig5BED+EFOqGAIJbxO3BUkfqRw2QD/PpV361RULO" ..
	"3OBjY7++DnpED/NKQhm3t+Ikw1/3RDWrklH8TGVNADT7RJ9qrHWGncj396nlWtuJyARB2bt1BxvlvhbFMktT3PYJNxXQW+iGWETp" ..
	"0TQiKWEFLyC4i/eBRZSLcKceXunl5FfhFrZANHSQvIJRxuRKFFo9Hqo/nmuJadrOb7ebkzdZprV6hwrco1pwPoANDdRO4pUfYNG5" ..
	"JySfm9w0PX2hOO6wahtgBBsxFL5/+cDnBc458rlG2qQfPsgR14MX1UBpy6cvr3lHwIRh3KxWGSbfuDrgWOG/s5HbIJxGIC0gD3qv" ..
	"WQqBCTZqAOzh/iAj7a5u7BhWgTOZYZmjuyj4M6KEkelNuZqptNFdTy/W1SK4szUmdopjjPWy9kKQwdUQDQx1XIITFxY2hQY6SrMv" ..
	"1WcDGNaYSs7XZwxhdYd5kf0reT8P7mSO1KeBAUgmEEOkT3HMY6AUrVotot7daL7Uct2U2yNYeRi2FIZjfs4j2Ab1sKgeKULLKO+U" ..
	"lSkTIgRQltAfDGTdeVjxF9070r6tz7MmkiGJdzXIuH+L6hrFuKWVeEKbpFj9xylfwVtDjteD/fpb/iqSSPhZg1WcRv8hTosuqkHM" ..
	"NlJnR3lNLUSyhQoloeBRUsCM4+5sllk3eE5Xq4IV/67zUi8K7OeLjaH5cfLeyz+A/pXIzyDWo2BVsEMPae4lFRmGNaRPtJw9p1pU" ..
	"XskoiI0/edVvgi3xweMIxHGZtMyXpK0op0zOuWyzIKbHTEfV6wHhyrujjusgU87dIe4kpU2tANcbYyxEi/+OvxuHYZvXA13aKwZv" ..
	"TPXP1s6Bl3nmgI140rLI1OgHzeLWHqlSr47j+Ubh+EPyE0D2XBMEo4EVNSr/EckKoa0gSUTo7Tpc4X0SkhOFEG1mn5rE084FSidu" ..
	"QLdZSZRpSXNLErh9qMHRrfoydzebgja05afz7dA94zhVZTTygQzdXDfUq6TwWtk3n5r4NugK+lOK2CjNH1tn60/X6icCaiech0hA" ..
	"/Zy3ppoh2OiPT6y+/RaBMWQjLf6pPqM6ALQfsux+BVynQzRu7QiE/FYVyqez6mwv0q2UbMDYf55uRC8BOkfBoSBcIXcRnq41dots" ..
	"+Na0/gEOnr8lISQpLHO223upDvNGv9YGLf/oZAa3z9z7fqk0aa6BiCcJ+LlrWs4zOKhXNDYvpoGA8iWhyUP3KfveMOYv1T4eEY6n" ..
	"BpLxl+iGWs2/M/OtDIKz4xVR7bpnkHd/3ifVOLnCp8OblJEjol0USYTBurZgRpjHw9asdp4Ny2NlHJ7zXMU8tM3388sQ0AJcuCnR" ..
	"rOZhF3ut9g5toDx8rW1mXJEzXIAC8kjhtXUIFVl2kjfzeh2AJgnvurlHXz82ptD702qzUil1TBGvTDd/KURbrrU4csKoU4ZGUuO0" ..
	"S7bYLcs7qkoh5qcmzC5xRw4TzKlEtiBgjoVqOzSSpaPetp7Jxr7Oxxf/yN4hS3vnK9zeZtQ9rJMaH/SDFLEY4/7+BdiMWhQkLd0T" ..
	"07ye9gnZ3XkDhT6aFs/+WWvHgcw0pwG5p7YlKkFRyCZGBCnKmrmVFD+BD0uBu5vA5nQ4sCEHmrYQASKXuGXonJ4HItmUx5C48HMn" ..
	"J88kFIvCvtOj6bKFIxtV+siZ/uZ7XA3elvHEgMTfmWwWrz3o4PO2tldSrP1JzPeM49CsOxyxEx8TSUh71YNefGjXCFaZ+oPPTxQ/" ..
	"Tw7Ja/xjWCxTYD1uoWIEYUQ5rTdOEZezvqt151ox/+Ll9Hx2cjXUNkXZu2wrG8X3CDEezCYXQKPQ+On9aW2Omkb1xQviEKUq2ZbI" ..
	"LO4JHK7DEKaiy9SbKf294NKuVMlnmOwl+mC+Eaqx2OduVclRaExKQ+GqDIK9htl3j1e1JrwIGaoa/qnBA3jT9jDBaMUzDl68YVjz" ..
	"WYmGB80heozHHYf5vEMT9VWsWdcLERhKCNZcmFx+ek/c1JNTeLEn425dDjIF4IUmU3TfH7YBXCCOsM1yDzHtoFwURLUBcTmPmHJy" ..
	"0S/xBoJw/TSrsZSDw94HenQQL29jN0OoEb9t7e1VLCbeCQmCy3NzD5ArlqU5vj0QDthXHBWfddHiYQKfLG5rrtI/ADuxj3a8k04n" ..
	"bXkzsFeCMSya1nILfi7WP7uq9Iu3PHaQIDmeAHZMBQfeHvWDgZsV6iyQrkrMfUndeXpSkaxgstK3l5X6lYn+Ppuari0jaCkA/80W" ..
	"lplR6v09Q1Zun/CF98dejouZt/sptTeXrQ3ewwkwIUu3grvW/xVJqRgirM/tOcerMBuX7lew6Mar59KysLB6pimGqy7hJitEMDRa" ..
	"Sh2EqdoJmtdtis9CZ+aYOwUq38QSR5MkkApdpgMMzVOzv7zC0jyjh93v4A2aLJDxFeq2zF3QGyphM+kH3dMFu+HSkjbjwLMyDXSG" ..
	"aHpD5ZLMNVj4hzfHn8pnXSbehGlhYYRcNDGFm0zX2hu0YXRIWh+3WBV6m3+g+S3vN1NbhbxQVZW9hqL3/hSA1KBbryBSKfQX87g7" ..
	"/RM2ZSyKZyEHXgUqJbq+5TDer18CXDKvLHEiH7Skoj9Gz4Z2vk53z/WutnnTc67czK9wVYvEzhIvbWESIdymXMF6dUeQrLCOU34F" ..
	"1LksDu6CPFj/KKnR/T7xkifK2Zs7UdRdaPCan3okGSeYPZz7iByXQ7R9V9Ih72G4wqoxjosE6PAg/5/B2SYlRPIC7iNiGWtlUp35" ..
	"2SrzJsPhx81H4qSXTttxmfwO5nHAGHkw/UiqeRMXN5PdE2MoCG9zabEQlQWEpmEGo5HmlzC+gX3NZvA+qiR/xoRPpbJZIVsAIWWb" ..
	"gC+xG81TgDqbVvjIT2rkBfvJS2wOl6jzm6LWexg0+idP226d/ZzusjJIWYehHCjWUFj3nnFQVqx21OWarkPrhvZ2F87cuGZ4s8AE" ..
	"Rn60a5+xP41EMg3KEqGk1kpuy5suMc4dVazt/LVATtNmyFUALhfEYBPC6/GVox1pRsNwpLgEObfoALJqgkZaiIkG9mKiHxkfdLiL" ..
	"2QJaexq3tvYwO7krtCIJAiU8BHEZ1V5Y56FmF3IC0lCvkODMX4nPII8oa9mpanL/KeA5BuSGvQQU0neI5S8cA1ezsmmD9syu8ywX" ..
	"9yDq5Dt7pnrf9RRIoqhGBsQQ3lNPwZyz/6HR4rvTN+2Cb/O/wCAgJUoH1cX5u/Tqm+iZa2YVGoSvKb2MdhaAAn0ksJpuFsN7D1Wb" ..
	""
local PAYLOAD_P5 =
	"5GQ+4iEbkQBsCghvlHDF+SXnUiRpAetMpaasLMAbQkeDQsfr5HmdbnhXNhMaxSsVvxrj+ZmwSZa0qidu67bfS3VgoaSPlvMykJU8" ..
	"+poF6TZOD01GIMlaN1dTJQjFJZT9P5JbZlKNkUH6ou9+lxFto0vkt+hnTnULdRkQ4pC5MAgGzr8881hCE884t6y4ll7/gNB+fuAs" ..
	"jMWxQeUvej9N2JVxQwdyOhPxkB9JIlc+Jujg1YMaVAZw5D2ZO0+Se7OsA2Uzj8R45zeXg7G23fFGKxFvWfhS47L8r693jE4F3Cgn" ..
	"chaPhkz1caCgRqNrxx3yqlm+5HhP18dqcB9tQyfThcOif/wWVOHRtrFrZ+3L3O5wqhvD2E+BFZkWSFtMWazILGLr8AGYgjQwM21E" ..
	"hGfl5U9CSm2y3/mUZ1swlC+Ol3+RILMrqvyZpsO3mgsu5jfo/hMPBU/j1TgJqrzfQilvcfIx14dbLiVmyF1e4wGwhbv5ZvLVdg76" ..
	"4jNAbbJEUcxAlqeKaNqB2SjAmnvWsmHWT+oQ9bC7BxJscIJH07ZlMMmrzGlmNVPqSK1ISh1NPX0DOPHFJq3VgJUIhHpoDN8i7Xjh" ..
	"JRu6d/TnNfa3gz4k7VUPaerjvnvV4sfEdT8pKUYKHuvI25QjfGSBAa6JFbUSzsSM4oeOuV+2tXKtQO7iS791AW3FHBIvv0WHhVWR" ..
	"uKP+xBQ3Y2cHVAOFSyG+cK/0yEPTO5/nJy++5CmO7UTgvf1c+FIdW4o7T6TGRrtga12XGdI/EFtzr1HK5c9FEj+NebSCVg/SaRZV" ..
	"2PScOBQcfSWeBns++NqwWJ/jHdQmmK+NdGahgzYpu2Xx8yb2sNyNdpokJ0nSruZf6Tmsa7ysTkCRULqkIShylTuTNDitzKhNITM0" ..
	"v/lJehHBmZc+dRR/Ksv0jNpxe4T809+LXwuZWvw2mm/GUC9L6/dkn6aqP+JAZYDxsKpXCnhWIUA9YLmTv6ht2KjpZhm0afOSi1ix" ..
	"7ge7AJ13SCQPxHCAUT0wZAr1TAs/E3xkMhmruVGxf0PgWsx40TF9SSl4T9ZOkPpMGr7lDNFNB/8FD6MC6bAYkYkO5X09wM3Rb8qd" ..
	"JfvoCefOTafbGks2OzMwAxPyD5xobVCDnwhr+De1naQap/aHVWKU5aq3SQOybHFnxl8QDriJYDL6rCaPZY9rQV2Rml6CoIU0CjmY" ..
	"8onnU2dBACJW7M9EeKsr6F/sKLrV7D1VHqL0d7NeesTOYZlt/FyqmHVv8b1ST763b6RLmLLOeScS+MZujfnS3z9nIdLRMUH/FsiL" ..
	"kLMtDiyJq+KMVPK7iWkAqva6pxeMqt6MR5CztOCgja7cxl6VFeSCb7xCF1NMjV3PABcJtygv6yRNWh78wPwsfseAgYh1MbYxKT1J" ..
	"TR7zlOIBa302yujGAOG8IPWg4Nz4+d6Tysuwe8DRfYJe9OG+BJmi9HSVZ4Nt2XgjZQ+YrDWukiQUBww9FEK4kq1PupOn67DTyZj7" ..
	"JO+zYnGE4oOFjvdlxaLmMEE6evuCAtVuou4W1zl0y9blCtntDq59OZlo6+a7JVKN4O7l+4/cfRyD7AK+ppmqNbHpZJ9keY8DIqS8" ..
	"RQpSADzjBa3Q0Y32xX8/rMKU8hoH3yh/7RT/WDcWgRLjXLhjAE3O8JF4Z+0EFZ177KG2bpbM83RlztQmjsIZPgYgvkP830rBbw49" ..
	"1mcEsG0LdM9rUH6L7ZsxavRfsKrsFpuKOMrcwn9QBZWWcu8hMzMEtHI0cJeJ9DVOKTKQLwBfZPLQmoYe2tqKltFxhsvMjegiGY5f" ..
	"r3EwpbgTDDod6h8r52n6yJ+h2H9bA1PpET7P6e+HoPEBanAkHDBAxLNR5wVkcKPEuK0OUCS6cxgdscmkmjk4Om7g4yj0BA7G6IjD" ..
	"25kQMV0JR1zJGRW4qyGp2+tv8SFZhkmjvpNGG2vXHiPhVu/OoplkPC+UzuR6gkEyCwhRUlgJTdyEu7sE6sBwOWWJ1CI8eRnD43Tm" ..
	"9qhxgUi+ofEzrvqkKGp4457Ew90F939tVQqsmY4SNyEcb+iOV3azYX53xW4yeNNd6tMDAzqoUiRBhLpJWLtfig7Taebbnidc/ijj" ..
	"htp28Zy2GSGv8+wtdWWmvJwAwab2+ateXfOHqdto+FokqUkA/a0+3e/+w6lRNRjQxM9kel0j/ddJ7ZzbgzNXUqNxHh/zfbfNPzL5" ..
	"JZ0c571GJ/6AvO64iVva+Rs21kQda1WlLhSBP41w8VFetbmrX1Avxaye7UjiX2bmF3xDkEEggNQGwiufDdOaIpVVm8G4LeAFS2Rg" ..
	"X4ljpaMdGf+sGcbfMWJuyN+knADUxCJ2Eh9Ht25aQGnRU5UMy1W2KDQTsMKpFnK6rikuaGZzcpYwXvayDdNz/KmsDM8D/wGeeNy1" ..
	"sPx1zZiYCnN3iaj6NGNdSRSzaN6837ski2f42+lG20ITWseJ6G687UhKz86n/yX5G24VVd32qGUX5I9x1OOo0nVeSV6/fBFfokth" ..
	"MENDT2H926Vn7ZbF6ikCnrpOFA5ARK6/1DOs7NLRzcSh+/09ECyJxJ66kvq2nhyqAndkRcUMvrk9SXiua5bGdIdLOflvI2oO1Ftn" ..
	"1dHbgYuA0d2tcizXcA/pC2QByGmnK4M008jx7F98surlyYrfoH5ySgvE6Omo0pf1AwaIYeJBJJVkfeDrYkZzmTD+ZkOSriKDZSi9" ..
	"dHo+3rYImiwhXRn8p5Bm23LOiSZ87J+MD6ZUIc7N6f0LK4Pj0X5BugfsvDed41iet3P+95t+FW+8TXTGSRNQ8BrKcVZVxKj++MsA" ..
	"GKzIlcIz+5klEZuOkcZdJ/7SLXbZtX/znvMqntKTojFzO3SvDXL9/XHjtE1kqMD0UyhhwSYiKlS7lPeyIrJNgFzsh8v8HQo2xacR" ..
	"ucYAVOwlkqhXU+qu5aZs0XABw7FLm/aY2gSgGTh4abx2afUQyHatAYLVXLXv2veJLGVSzK76Lzle0EMPyZTLG9BRZG6/8AIj0s2D" ..
	"yOrN1hl4g8NN9HalP1yuuUHhX2PMD2PrShD1Tey5QBDRaML18uSzjUUiM5jBqH98b6I/AkdEoqfD0zb5aHbn+6ZDwh5IfWdM/FDA" ..
	"J5yjMxGWj8joPyV4j+ndK72hDoeDQR081sE4rDBDE/3vnWQuKVQPZPVoC/quMdnfXIQML21JzkcXLiu3asXid0OHCI+v8PkvOnCW" ..
	"Os8/axhkmCsKEDsBkZlmF63fjyRjLEcNuT0hN4PMWSV4L6U63V+xJagffa2rj+RthuYLXOPxowG3jCXmWSgOZGEuIBMGlp+QNAx4" ..
	"2G9h2tAMlmuk/IykfurcTxlPtgW2tQuCO14QcOyLie6MFPVQMgtrgpBYy9sNFyj9oU/GP7y1VwxcXjz6cNqCm4+jLe/VPQdc0+pt" ..
	"W2/OGFN0RmOk08pZHin9iuyyNkmV50I/N4p92nSlN9YS1nl3/9PrWxZ1daDTg5/ZMIz9l0FDPPDlDNzAGj/5zjZHOZ1S+ZQsj6Sr" ..
	"zhieDAVIiTcsJ7MEwOG5Mgv9ZNTHME+PCWaK8Pmux1do1PkrK6IrS9gqSXMa++ZPb+mNVBHFr1TOL1NxZ0AAFKS5T7qadH8tX1wF" ..
	"EeSNlD3zkuDJDjBEJCNcFoRSZC2D4Ki9rAo8x7JbZij1XFQ28YduLZ89rpkl2aGwiOh6d5ysUg7DQeRXNvuePxaWxoKnlotFI8gh" ..
	"ByXvH6MeER5w1SZDKtltHeR3O+pJ4lvkCn/gWlHIFgzuIa5EtA32XgvIGTxvh14oGVXEBvbkAWjUXkxFSzaNT5ptoKTIL61pHxkT" ..
	"BwrsUVYrPT+tKReEanQLjzfby24I2CD4CluWVVthw90Wqytsv51RGh6DMZ1C2t+hkmY6nI8loQHbIkiAZHpJvbBg3hGY80q5xHrn" ..
	"KI/y0pZ73ihW0/rTsLVZAYeUGEbINjT10/4KrPuakthCWACMGJa4DjzVrwbZxCkVcCuqHhZG+6Cuwx3VTqkBY8zRHfa+4WXM0y/s" ..
	"8zfw12YuoYd+33v88TiQFBlDJb3c6HZ0KP28rhNrsA+5Zc7b8TPSkW4nYxII74BR410sIz2pf3s/7qe1Dnr7kH2dzyJgqbm+X/3o" ..
	"OTV8NHin9I5kQeP/EG/eHrjSYImcg/zW2LCELM/Wz/YXvlJatgrAIx9FxNZEG9g1mgl1dy+RCLJJp4LEjeGi54Y3MXmQ4QRj729q" ..
	"ELbaG7swbiDIAM7mO+yudp019kSJRxcDHPioDGyIFBnUiJBv0NGJj396BEybFgCaPmvBUg8g7Hbs7Y++1uqYOuwG/yQldY5HXgHq" ..
	"hp0gebHdwxu/O45nDG89d/BM4fOzjMfAwdgar6ACEl4bYoTUKX5D2cHCNo92/pGle29Q4PuZx4C2sOHmb3gKb5yKe6aCsU5K2UAw" ..
	"2otXNPISMNwirPXjNTUcmJe+0WRimVWaSymZX6N3FdQx+qOs6fx0nggsbZ/4czRZyCoNRrE/OEsipVtfswowTIxfYq0EQ8oJS/qq" ..
	"nScbIW3rqODvGkEk/wGcG6LFaxh+UGyX7PMxb0yKq2d7R0Sqb2+cMFUUpEfqs3WVWs4JWNJowV9g2JEr74oFajJc0bjZLJf9e1JU" ..
	"PwRbRQWbALy+C+POKFUlaxAL04ee/e/y9IA+zp8cw5G/86ATlF6GUfifJec43fHNQoVrOv0ByrqP4eH9u74kAZqBrEGDVjKeCX58" ..
	"qMYOGHAvX20k/AFHY5UuA2MJEO5swDBk5cz47Jt1iLYDREG37PlzScMu4zJpiOaFRpnzxKw6V7U5IV807prl5Wyx7uc1w8k/QR0T" ..
	"daGjzzQkgOQ3D9WuwvHSKEkQ36oFw0unIPAIMe9bqSurPqeTz8PLyncjxMzkSUVfbPr8fIXCW9yh6Em8VTnaiCrsPywnqUa6+hrU" ..
	"EMt3fmW0FgJg8rP2eUJBngtW4thEoRqOBahOOkUzJcq6+SPUhati4x6C7NvFSQwVG3RWvckwl8ACRPys5d8MXCEckxqp4ObEIRmy" ..
	"lkOj95IqO6nV2ND1X7Nt7nA3ByZ59ANJuRZ7HmrbfJJLRVJ9yArJGCE6C/WcOQG3O4vDEF3Gs2FNrcLYwavynYceR/jVS40ClEmH" ..
	"xvQ62zPdM37xESTRoec6g2qkAQ3ZpdB8jM+QLRn3Y3g4au198IQ1PNaszDrIhET3s2ejADyPA+3yeQQ84oRs+rdUropDEwYIcLeO" ..
	"wAzL72nYIXJbTmORGIcqWtH86UAy2KYOXmoFAEP9o10kAWTaS/XdQXsMqXZtlHcXs3Z5mTzMxFvj2S1jHxIzuiTTo4bpvHhRj1gc" ..
	"FIpZVXOtgPKIa1SynKyYnkNkljGgoezf9ryu0Pnf8BJNgBmojoYio5CKTcp+ec1U8oN22w0xMTx0/2BBNjQPaUscz8/ynYisWvbG" ..
	"2lUtlb9zCt+DVDd8g81T5vpJFpZrC+xam2KTRhwCNaX25An8LecwOuJM9Qi/UpzunnABY5+DItz/rhKWZpskw2fuAkmlbyb9RHM2" ..
	"2yP4cyO4/68cwjVFveGpUKtVhztfyfuskjuWhz2Asb1Wg8HmQwLqah8pdCZPLwf19UZUlp+sXm4X0Hfhv60xOQg23iouL+taqmty" ..
	"ZBuB9wPtHXRy0FdqrCn/xa5v8ot+BHHkTYyx5bxgr3MAi/T48TZu3+PvHgsVj7SYZRfRnNQm1PHwZ+aj33b6Xw6badr1LfF40KT6" ..
	"JdWWZkRD7wzmzSArdVmRPKKwjeFPYaM31OlKHOwYnrk/73GtxOn5nzWOvLYNQIXq/G5eKdjG2JEnZNr27l6O3FUfcSXql5LoJ/o2" ..
	"UvTxnyNXK9znLfmxzmqu+088daNyV74yGSDCVQbXr9L3JojOgJqX3cBqsVcpDyK2ogIstCT+p0Rw3IRxmKIkruCiELMv/vmCF1os" ..
	"7oZ7TU2obGmVDd1t6X1xhLlvcodoVUkl2X5z60lA1OMgBL9ppN97QW7+O/xtmUuQnhhT6V2ZQHplRW1mjRmnm3ApqmkB3E8erxiY" ..
	""
local PAYLOAD_P6 =
	"GrY493KPlP358wXkOK8C3UeIoWjZ5yeDUpvMOaitw4HRCQ/2wCX9dKsd1UyFwKDep1jQ+iTIgo+RywekHU95yPyCTsQaQjqTd8uv" ..
	"x8qSHxNnXOlfvycbXEm2OSnKcBBmZa9cjjHij1FLrJVcqaVtVg2uzoGNUFmVHxMz4KH3+mpk3H/M9E7iovOSZYVWbX2SHZj08stb" ..
	"C1FNromobYKh8M5d/chXqQJhTcJB075GWjlex6QA90pxNzTWIaZ3cR+pv3YTJjo+TWfd9NVU7uLhpWGAkHsrnP30NowVEKX1hBpl" ..
	"yhoYuqYLSvaAx8aZ0vPCr+YPNDhEwIsQk9urhLaXke4AnP+oZiHrifv9UkUfqGbt22yPuOQgd4QUnbCpMi6i2YtBpJTLgIl28sQv" ..
	"aSnvMlMN6fa6GMLxb1X9XwA9JnyluRMJE9x4qi4/ZuAUbacIqGPjWyeHUBLo30aBVE/eCzLlrM8WnzFs7nvkjbtJZRqZu16CEVol" ..
	"yCc+Vuhm+d7sF0zsBtdU4n2SEtTC8Llob7oTsepmZMyKE5xaMfVEmRKu9JZwZf2mLBd1E3cCQcQdl1Rng4jhDx7KnMcmAqTb/SnB" ..
	"kOLXOfnHMSETSwDXG507dxnG1R8zbLwAioRZ66PFLWHTWOduOKB6XG5fM7qe3jdHYq6+XWzFkXqX8I04ms5fYesKHY9YX1SYWCep" ..
	"YXxl9IMgl8VXpKJ6kszUHbCRvd1+9qQTeP0U2I2G6pnOKNXGlV685E+BAEm8IyVWnMIvBIujnxF1UzjaNWbdClW5WuHFsyvmNxxw" ..
	"Gm1upvxDwcVmZR4dhv5nwaxBwRwnRi0j/CLloldJm+LpI5loGUAxZVQx2xzhW7zqAw8vhyq4QpYR49m6T80G7ZRpYLfu+qdTb859" ..
	"uY8NIzL3GlqgRX69KhpeKJH3IFdRcroZcdBkxjHa/F443MprIXoHFi7WuN55x+FIew8ZxLhTfwkJbXABoaayA35cRRjxVpgjsiuP" ..
	"pAEDG/Q+JwzBRuvGlFKSlKEbdduru5snlcwqwdV4PyehKFL86q7fdGRcUgeSEzD5ZoPH4Y1vHQm3NFMnNTJZ+JlVwDVcWcX7rNqt" ..
	"GkorMTltlP2iM+v7kM3ag2TEpVSesiS001l1StI46+mBckjHX6SPvpcHw6FS6Jk3OJHwyAj2hpCHgQjD9Q5uIqMbt83HYnUHPu0g" ..
	"tx6tWXb7Eyrh1e7LA3QJlreo8Fhh+tep9e3HQuPpnuEAel6xn7AhzjOkPnEkXq3kOcUx6jJoohcFOLtZopY3mfxKoBHXgFhOVoJL" ..
	"I0RuOL33r7mN71lra9VpNT1TgQ6Diqim0QYpwAAH7v/3j7LVgKckdigMCiWpBdBlG/4xKHrqDVImAEu5cjQtG25vu1ATW+8N5p3r" ..
	"tfIabgLE3Qv6Gn9+PPefIK3e7UBJSrEuMi182OMNySDgTyjRqcAk1hpAUCp2Q31uWpyeW+Taimspj2U1gNaCYfDpPWPXLqa4lD8J" ..
	"nmH53ArrcQXj53J1ihIQp9WRhzZs4Issb1tjqQbt8bsWriDh2HZbS+h7iVFZoAuD82mU5Z69pvcSIDusLcqNg6iE2igIGeua6VH+" ..
	"8GjhzK5KkhMfHvVds+EaASr/KJ+vXLYDAfkguLviuf7wBbGJBi/7lxAqJ0lNyKarRg2MBWKkUKJzU7smlke3FX4yhUsEsPjsGwcz" ..
	"9lgbFALx6C/Hoh5ZdWbaJ4ICKLb4fDwEdS30BkzlKG0PojkY58D/cVCv5IejFA+BfkAsrxtlwkOHYO4aszvVajrUMuzj4Ci776VQ" ..
	"fnHksOr3cnEOa/lEYZTiAYuD+PFCJiO9QWlgTQTR00gD7FywLBU4+O4J85elzwahZ9ntM4YB19a1os5tXu2HX+XAsg96B16whDQe" ..
	"q9iZ7slM7VOofvo0V4zqye+Z20DvqaYJQybl+koTlxKYLYMWFSipXRVBPShIVliJCjp0WKzy9R4T3lXhNh0kp0dHfYbbLbsxfOfw" ..
	"itzYc720ceBwOTzLNLM5QgHeVPxjenRUExt2FYuSeq9lH1LFNyet2xy0LtorqB4RRlT0xEDeOD3fhJBH2bFvkMUCwznRz8bPQo+Q" ..
	"i8yvxK2dMTHUT0gT08zufFcqBo/xay6S2CMFKvtItEnYSMEM2rJOVwnQJV4nvojBzGUg8W4v4+no8D9tLUnM0jW7fa+ePNNvES1o" ..
	"0tJpcglefXh4EFNWJRZfqKnWZtKP/I+MXJEmYYDIQ3IllYyo3t/ejUAo6a2qtufBfpo0m+RT/L3Mb02w6x6QJGXOr86xUqdleVZn" ..
	"gmMe7NNNVUUFFKACjKSrO4m+nMiJL8V0FpPayOAMi9xcQKdEyT/ytoPTF6FZXOaA3UaxeYHwBWGd9nQgbVMGKeAjObn94RWXuSvU" ..
	"KP7OHCGEa+qgz3vCiOBy5f9wKL+NaugE9ySwIr3FW91cxZ2xEJ72i5M5LiHcvOZrukkDRvgOR8Nk8SPQRG1vtbkA8jD4uBim1h4w" ..
	"AkP6VK9IKMwuvwnufVsjRSgHc9g9Frt9hiDOF4E4+4FazHyNCYcz5vK/p9AhAktnMDOzdS0Jo5Xck6LUe47nTDSTa0stjZl73Ggw" ..
	"01V+r1zmLCW0qx0jQ+gCRxJSiLtgREDQOS9AmAjhlZEPYcYXXf4hBRw7+uOT3IuNTmjXy4yxW1AwCTSKqqj1LXLv0xSyPkFVIQDa" ..
	"4T7k+2Ctuc9ss8Sgc4eqNPA7TrKur114Ef3dCyxnnxJuuZa8yahWs2HqITLs20sw7EMyyDE8PsNnLrj7UpfWlza5cfIhh/tCdxXA" ..
	"PILqQqUWU4Awo8uqK0km9F0VJeL/2abeadU0DXdtfYvhYsfdnETLKo3DEPeM2mgFe+IPVxEUOOHVgbcqDqJtWEgQ9XqSyXFuDube" ..
	"0dp2h3VeS/p7z4D148099L2Jua1A9+51K9lNjW/WuG2m3Rva81mW1tpl6hll41AZyugR0OengKlFuDRnecyrQl18eANZrulqH/dW" ..
	"xJJfhNXKM1g20XlBvoE8yL+0wGRE8rA5oVS4R8BkY7EcBlfKpFSJ1jt0NQOOXxr4ngISgZujRxQr08prV8L07Um4LOX8QbEUldcE" ..
	"ZZ1hNQm8HLjqyJ0QqddpP8jqqlRd9j4XyUMBsH3RqwmPu16OJ4MyeJOL7vt73U/ArXn7MExQlNuIHfK6SV7FmnNZ1WJNG5hYxQNm" ..
	"W/U96CWu/3SYFiHRfjSfdHID2aJ0CIdNivNz2NcdPLIcRUtT9Kps/kwGFBO0q8sX5s9/WGLkAiRbdZ4pFRx4H6Cuna/d+Z6fnIC+" ..
	"0r1j0V81W5r8AGyNSuO+eXbqcIOtU1jPb9DfWIC9nZmVQB5sPu1WjBrLf33Bc6mBHRHPpVvCk0Nnh2UgD9o46KhfxLadzCIIGgJO" ..
	"WHi3MumibvLsRNU1koNCjogMuXxmvcOV70XclcelH+X5qTSYplsn7/2VPN02XrLxxr8/m7vhmOayeaq12dH1RiTHLCPHCqw41nJ3" ..
	"GxaY/ls8BH8RheBA5ZB5aad4LliSnGdtsBwNHL9XHTdeEieYWNzlmTdHMRZfaYPmXqAVzDFwsXGt7o9uOyaNI90fvtWjsH+QQNRA" ..
	"33lG2HmEBEGgji13iOgzinj0ZZ9JQN0xsEspc0xDtemrCfsVtZ8/A0zCWhIs7L8RqMlDLkI5sy9xNVFX+ItvrhBvPtcddnMU59Un" ..
	"obh43SCgDD43AMhrD1vfbi1xL1DDv4yF59tqjTFMBM09WjJzCU4CZH5L6CSHUvG1XTTglyxxDpp/Fl1lPSp2fBJRRbVU6aAVPv8p" ..
	"LE+R+j1EFg+zCJJyc9R1PK+rjiwNjn4TJBUgGYoBsbaVaMFLNVjGQdnFlo+WOG8oU9rqCCQlPqM7Opzc5thCPLBE0NKfh5Gas98R" ..
	"R2YlFtov6keZ664Zy/aFCmnBj//zONOBoQFMvIkBpNrnthkaXDRLgf7zz2DY3t0/AkETkxtW1wsy/0vTOXaNpSL20+Siforis6gk" ..
	"wsgR+7MYzjMAVnTwja4muoqxpyxsu2pPiVcT2VnTOTZBriQ5wC8sqvbNbeUQ5jcDiFRIEixogWYsV1w9rcZsyI0LTieSCjDHAfc2" ..
	"r5r6JZ9sjpKdydOf/8nUT6PjW2hAc9LD3O2lV1xuvITk4Y1Uo6Jyq6yzEc0jnDVw4TN1kDTaQjDx3y6MuA8KN3vIFJxGiVw1MXp/" ..
	"voGnjRypeJudDc+LmcTpt34ZFNYOfHQai337TYahvY9Byl2HNFwoz+t011hfGAI/XqYrlZ6YvsDXAIsmm7gAlU2TrOn6g0Ek8BDZ" ..
	"J5NVI2jPulNqBauYCPo/3n4WPfVwShM/qnpXX7sER8/Qc0i20Tsja1uhhVMyDR+Wc/51yknfoRVCWeXRDD1dGaEWsqRdWV0MQqpl" ..
	"97Q7ryZ/uQTe1gSme9UnigiJobhZVSET/EUcc47fFzy4Ia43x9VED3mFWQsX5u6UmkxASM6oHN5iAV+XVbE1F0l5f8ifgOGaD5zC" ..
	"SF9Gk3rZXRg7u0aaHTbLkmUZ1f8VWKPxbxdNNs/ucZr+PkaiPB1CPpVFWYhA5eQ3+gelhutJxeRI6i2/lDZ7To78EBXf5mL+O5qJ" ..
	"5lF9Aln53Bvgtg9EdfGnS1juVsZaNMqoJUNquPnye2hKbfJQBescSDkwXqynzCYR+FtKlk4GkNSrrStnnkIoj9S/jIU7cbaSkNQB" ..
	"WKv8TMJ1ErVv9X0W0QY/RD+4j9bgTdNTZ0O5MnBalDaglmxEDR2Zi2wy34z+PvbxyrzQdS4H6pv9dfRZgjoLV1brjuEQKydfGEc8" ..
	"ZE5RrLXRIK4qbhj1pqxWSAJPuR6FqdT92HhLttAiD/aZBZhyA/RF91z3EsKhZ8hCaaBQA6Enni7MXbhBT2yNxvibjyABuD5kET+o" ..
	"71N7UeduLm/cdWX5LfseIY2dH+i0/Z8iFWygr1jf/Yyr5ANf2u4hGU8KQwseM4TTKKXdHwEQQ9AfefjMjCFtvo3hA2+iO49gv+VO" ..
	"dXC3NpUAd0PZdfKTv3PceFu9ISoJVeu1JvFK5MiGN7sRbG0JjN81Xd4VZA08BdYb5oeAspfkSD91SwRknJXv1XPvATJES1LLnhQS" ..
	"DAiiMmlDZrbKQCRrEUA0Jw1/SMXgMQ13iQ==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6

-- ===== build UI nhap key =====
local function buildKeyGui(onSubmit)
	local pg = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, c in pg:GetChildren() do
		if c.Name == "DQFarmKey" then c:Destroy() end
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "DQFarmKey"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = pg

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromOffset(300, 150)
	bg.Position = UDim2.new(0.5, -150, 0.5, -75)
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local uic = Instance.new("UICorner")
	uic.CornerRadius = UDim.new(0, 10)
	uic.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Position = UDim2.new(0, 12, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "DQFarm Key"
	title.TextColor3 = Color3.fromRGB(225, 230, 240)
	title.TextSize = 14
	title.Parent = bg

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -24, 0, 14)
	hint.Position = UDim2.new(0, 12, 0, 32)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.Text = "Nhap key de chay:"
	hint.TextColor3 = Color3.fromRGB(140, 150, 165)
	hint.TextSize = 11
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = bg

	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, -80, 0, 26)
	tb.Position = UDim2.new(0, 12, 0, 50)
	tb.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	tb.Text = ""
	tb.PlaceholderText = "key..."
	tb.Font = Enum.Font.GothamMedium
	tb.TextColor3 = Color3.fromRGB(225, 230, 240)
	tb.TextSize = 13
	tb.TextXAlignment = Enum.TextXAlignment.Center
	tb.ClearTextOnFocus = false
	tb.Parent = bg
	local tbc = Instance.new("UICorner")
	tbc.CornerRadius = UDim.new(0, 6)
	tbc.Parent = tb

	local ok = Instance.new("TextButton")
	ok.Size = UDim2.fromOffset(56, 26)
	ok.Position = UDim2.new(1, -68, 0, 50)
	ok.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
	ok.Font = Enum.Font.GothamBold
	ok.Text = "RUN"
	ok.TextColor3 = Color3.fromRGB(8, 12, 16)
	ok.TextSize = 13
	ok.Parent = bg
	local okc = Instance.new("UICorner")
	okc.CornerRadius = UDim.new(0, 6)
	okc.Parent = ok
	ok.MouseButton1Click:Connect(function()
		onSubmit(tb.Text)
	end)

	local err = Instance.new("TextLabel")
	err.Size = UDim2.new(1, -24, 0, 32)
	err.Position = UDim2.new(0, 12, 0, 84)
	err.BackgroundTransparency = 1
	err.Font = Enum.Font.Gotham
	err.Text = ""
	err.TextColor3 = Color3.fromRGB(248, 113, 113)
	err.TextSize = 11
	err.TextXAlignment = Enum.TextXAlignment.Center
	err.TextWrapped = true
	err.Parent = bg

	return sg, tb, ok, err
end

-- ===== lay HWID may dang chay =====
local function getHwid()
	local env2 = (type(getgenv) == "function" and getgenv()) or _G
	local fns = {
		env2 and env2.gethwid,
		gethwid,
		get_hwid,
		getdeviceid,
		getmacaddress,
	}
	for _, fn in ipairs(fns) do
		if type(fn) == "function" then
			local ok, res = pcall(fn)
			if ok and res and tostring(res) ~= "" then
				return tostring(res)
			end
		end
	end
	return (getexecutorname and getexecutorname()) or "unknown"
end

-- ===== kiem tra HWID co trong danh sach khong =====
local function hwidMatch(myHwid, list)
	for _, h in ipairs(list) do
		if h == myHwid then return true end
	end
	return false
end

-- ===== chay: thu tung key trong KEYS =====
local function tryRun(key)
	if not key or key == "" then return false, "nhap key" end
	local now = os.time()
	for idx, entry in ipairs(KEYS) do
		local seed = unmaskSeed(entry.seed, key)
		local src2
		local ok2, err2 = pcall(function()
			src2 = decryptPayload(PAYLOAD, seed)
		end)
		if ok2 and src2 and #src2 >= 50 then
			local fn, loadErr = (loadstring or load)(src2)
			if fn then
				-- luu source da giai ma de teleport-persist chay lai khong can nhap key
				DQ_ENV.DQ_FARM_SOURCE = src2
				if _writefile then
					local wok, werr = pcall(function()
						if _makefolder then pcall(_makefolder, "DQFarm") end
						_writefile("dqfarm_source.luau", src2)
					end)
					if not wok then print("[DQFarmLoader] save source fail: " .. tostring(werr)) end
				end
				-- kiem tra het han
				if entry.exp ~= 0 and now > entry.exp then
					return false, "key het han"
				end
				-- kiem tra HWID (plan=0 = nhieu thiet bi, bo qua)
				if entry.plan ~= 0 then
					local myHwid = getHwid()
					if not hwidMatch(myHwid, entry.hwid) then
						return false, "thiet bi khong duoc phep"
					end
				end
				-- chay menu tren thread rieng de tryRun tra ve ngay,
				-- caller destroy key GUI khong bi block boi task.wait trong menu
				task.spawn(function()
					pcall(fn)
				end)
				return true, "ok"
			end
		end
	end
	return false, "sai key"
end

local saved = loadSavedKey()
if saved and saved ~= "" then
	local ok3, msg3 = tryRun(saved)
	if ok3 then
		print("[DQFarmLoader] OK (key da luu)")
		armTeleport()
		return
	else
		-- key da luu het hieu luc (het han / sai thiet bi / bi thu hoi) -> xoa, nhap lai
		print("[DQFarmLoader] " .. msg3 .. " — key cu da duoc xoa, nhap key moi.")
		clearKey()
	end
end

local preset = DQ_ENV.DQ_KEY
if preset and preset ~= "" then
	local ok4, msg4 = tryRun(preset)
	if ok4 then
		saveKey(preset)
		print("[DQFarmLoader] OK")
		armTeleport()
		return
	else
		print("[DQFarmLoader] " .. msg4)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok5, msg5 = tryRun(input)
	if ok5 then
		saveKey(input)
		armTeleport()
		-- dung FindFirstChild de destroy, khong phu thuoc vao upvalue sg
		local _pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		local _g = _pg and _pg:FindFirstChild("DQFarmKey")
		if _g then _g:Destroy() end
		if sg then sg:Destroy() end
	else
		if msg5 == "key het han" then
			errLbl.Text = "Key da het han! Lien he nguoi ban."
		elseif msg5 == "thiet bi khong duoc phep" then
			errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
		else
			errLbl.Text = "Sai key! Hay thu lai."
		end
		tb.Text = ""
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
