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
	{ seed = 110662449, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 115405607, exp = 0, plan = 0, hwid = {} }
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
	"/F/i3rtNk+QzeCVvCFOFuSrB7l77eB4LKxjip+C0UPIZytVoAOwkQnn8iPfAe3dnMu6cpKK4Yinui3WgK6AADjcyRo5TI20VPY4n" ..
	"6rUHuApeT0h2GTAddjt+7XROzcGDSSKZzRPBDOC3bcb2meCyEqK19AKJzicyKu9oCbtNx6PzGuo16VRL6iYgSjsOKPK9c2PTMSTm" ..
	"yc1f9GNbz/y+sfaVfx19HXaSf2LqkViqt3+EgQYlRwKEs5VIwaaz3v0EmPR+5nbMsu8tjb9LzQ3fBVK0O9KQVakBTdyl+HzLytAa" ..
	"DMampgEhv9Go46gwkrdlV5AsgX/DPCKQ8ngWxhTYXUSOpN0DIIi64QAxZaOrCaBBLhE8uvFKEjBByt4Iq34jV/VU+pcXs55uetaB" ..
	"xLpZ15z3uXcp5n8cG0fA3NIVGP/ESXQ0VLW1zOmL00BA8WJjkAL2KxoIrqjlEow6yPUH0v/HCfdzilenUcf8Cp/EemxTtAyRZs5x" ..
	"ASEDao+iiauDh0lghzceNnKt2pNYOzA587YulnikQYs8mFYKWGrFl/GMzRMicw4GsOGQa3B4KvAJ2UWfnjlMjZTZwtzV/0gTkYLE" ..
	"aQtVpTrYcwXLUJqsRVepxsHgd75v8+tL6vL6orrHadeE7cFn5fkYfJCUqmJ3nR/XfT/d09pkUjmpscd85TcSvk+OIq8LhVoq67qS" ..
	"BK6MjUuwI9kxeutIYmU9xr32sS++irZEhJTrN0DDywul696V/k/0lm6oP56SOHCIMHeMUQCZmpVBq7HJxvA3HM8B3pz50AMwjk69" ..
	"nJoHDR5quqQEbwiA/8q9clFNehIny1fCgLVlKzI+xB03OSmceNpyZ7OsCQdeAO5dVGRMW0nspJ4MRyQ4QPGXpcMf+fxv6kRN8JZb" ..
	"i7uUh5LSoQ5SbE41bUZdCUGMOFCTRHMJafWzm2qjDj/MTBA5/ddhcumUxRBLRNXpya56NEST5yZFAR2hFbJ280qHxBtn9sdLOjb1" ..
	"3OHKlbFKywcuJXmAXlqElck+3Fm8dmVbshN2J8S5VKgW+HcY70UVqPzFuIFBtg+kc0rokMjPFv3qE/Y6vTI/CV4gcwNmWhsVet5V" ..
	"IrokHGkYYlME+6vyYT3ESN0ass20TzUDdMY5Pu6iAtTG3jbKy9VW8xMz7LHAum46gjj8lguQu7Wa/Tj/6Dy3Vjlk9uWc1ShQh49z" ..
	"SrTozjz4MwX+JyIn8VfznFUF38A1nAKlqKaIj5FskKTXBiIrNeUDAf5AlkVqVuDmH5ih/bfrn7b4kcldXyyXUkbOiZ0GoqzimyTT" ..
	"+6S1cdT7sYYNNMF3nKMf11g/TQdwrfyCmzfWvB4t56t+OCDEqJ8X9HFI/bQ33shmbXcM/lPHuUNFf5nYuvHAv8DRUY0LVbmrLYS4" ..
	"sBTv5GnxkVuyd3a1A3Zt693f/3l0ExyJSUOlsIWw/Q+LmQEmKF7KZ+VM3rnRx5be2Li/Wx3JA1zBaGhkINqdbp8nt72Kv/NnDY7T" ..
	"2Spiuf0w0vwZaN/4h3RkcN/EIeJHdJFq5VyO5WZCxF8zndvRlfzQaS0HU2ehHchidurFZ4KTlof8x3TUXD6Jo0/wZq+suFGwHoTx" ..
	"u5PjdmlBBES20HtxY+G5qpFSrz+uoeDgwhjUcWto4vzJgLDLZUZsTIHUTeCLoVg42lGwyHSflmGtPByrGd51VNgV5a96Ax91V5Tg" ..
	"0T5bZzox8thpJ49jsCCeT7cFlztJpcuzbLvhOK2CkQuBIyeVL8s0ke0wR1ubeSi7DcCDgRvnhgK9dQpKEFfl9jR3gpb/J2gQ+Bl5" ..
	"1KXKh/dO6hNf38mt0cPwu/tkblpS31V6bNcl5qZBtcwWwGZ1guAuGkbnnI9CCm7w7Z0LuHU3tEOPJ7CK0ShR6V4ZjCOrcQoC9xXz" ..
	"saZCgQ6p89eYug73aFzNuzfEAgcep0tlmVqtDs3T5rL4SkHRYZGdgx3IjxkAHBGcHOMfZfHAJG4Zzd2k1+kKac7G1amNUNM8ew/l" ..
	"riWVhCmgmQguOjEg2eFYbbIj+wN+bsbkYf1bdwP0AeaR1WWd8DRGACL6E3Qx9Aq25e3x7rbeMT6A1YEYWk+V9knkvvuZzjtTpU1j" ..
	"SW4pwULlglrtE6dZN7SgdyDyGYDwAQ9eCKXLpq77j4+JpDD5GGa5pxugJNnyFGHz4BRxIe1WnWb9v/JUHo2LqI1hK3eEHYl1eQV0" ..
	"HD0dECof4AuLY92XmJtCKt3Mri/v4sDdjA9flNR+jBfPcyFQ2rmtpXFeM2N4Z2atrFBQ1TAk6mlTmBZELr5Ylyq98uQzQcpc0Eaw" ..
	"3Y7R9L3BDfEk8DLJWHqAtIzE3r6zisE9me9EwKt4x0SxrX52tioxXjv46bs56PvbRJ5Kv2F2Fme0shcfnUd6QA1VnpIH5vYeTQWG" ..
	"Ik8Gb35ll0lYfb2HzLeyv8nJmdlM7fTaSVhjuJMBveaUk+tehZEMGGNUvFd6b4vPDOZXEzOMTBK5Hc1+/pwAf5R92r4dTTsUp6Q9" ..
	"lUy8cudop5qUVRVRjxhGA5hbWpW+OvYbpGvr2BR1U2cZyz0VYvJqVCLxLGAXdGlHfBsE6wIFsgalIUTAhx3kDXL/bdfNSxZB9sah" ..
	"MMZO4MnoIcfV4PcyPFVuLPz4eJxG/AblefSEmj1gO3ErPFG3G+CMWhIpvdDZN31JQlt6GDLttydhIza/uWPT61eG3lvH4UBQvYTh" ..
	"JXHSG47nUV5eGqokZoqAKzOeLNGP5ZIA1UPRGx/NgrOf9kDMyvgkirkkMI6L+9wByJDjS986wQvC3DNBJVQG4aAsM+p5+lks2wpY" ..
	"Wit4xZY+sv/zQl1fgqBW4S06vR/1RNQF6BEbTig7cy1V0LN6jv+uDhK7tMntdt7G+m5Dp7ULK1bHmY18omy3l2tq80OmBsOOL1NX" ..
	"3yHZzbwPtCCp4QvlFjnfmj2Y7s03AOx9pLWUwwXMgZNRR0UjTqBp7SoHu/8SxqsI7zTTTnofax0M7ROkZ/TICwVYbKxOIhLUEFAX" ..
	"Oj2Z2eIPph4G50jSrvc0SxcP9cxyMSQWFSmwdnajns8qZJMhYpa5WCLuVbMLrbeJL9jWU0S2TKv9w1Fmn9jfUMug/QoVARG5FCDU" ..
	"qkYPzWpAWf7f4AoSnTgIv9XXbBhm7Fic/Ad9TiP19hnII+zyzTmpLh5NP0qm6quDz8yx53CozNjIXyQ1Pu/3QDgTnX1o0A7O3yS1" ..
	"wPeRCkHGZVvW44lE1JOfDldvEkghkEAm85OYcTSWPKVk5+VTjLaymptepEkhQ6h0UgYmf8s0I4yCi7xeNbEmhYNYBMX6uE4eQ0jn" ..
	"BGID2s/S+tjz458Z8i1dxd4YlztJNM4XAklpRhFdcpU1UKujS3zRqQSCgNnvsPTk+R11ut3nFMvEaZaBhZVbOOG85tkuw+JQfHTX" ..
	"Y+Sn+Fan2tdaz4KTwDOzabItYL3gkcf5BY8K/RQXOhFoRU2OBn/dDPqPu9q9lSlEXo2kP7PyoblJb2GwWQpUmSq/5KUeQlRMzjPk" ..
	"fBYECyzG4w6qQbx4/1pfO0sE266KpY38GAQBaiAE0CT0EVZVe+DzI/G+8L6vIPKKlSRYSN54B4YYl584WycZjjBTu3PXxKaM+QcP" ..
	"vY515cQv2SmIxUNtaAkGNDYCDSmHK1JV/GTjV4CQmywLNHc4D44mxAEwLdDsW96jKFqv9uMPawyTPInBqzBDmtj93BbOnSaufAz0" ..
	"eZ6Q52yOYR78rHghVEPopyDu/SWNBzJXP5dUV06N7sAyUCTnbgnVn8adHHt2ZYV8BRNBcLcodmkczRAQt0A5bXwXfpRIJRPRKVJT" ..
	"9gG9ZgYkZP53D/XloBWNSIEecPe7TZWf2LQRdh3hzhEmhNMWkOzCJy+2DhHaydsDQwqLbbuB67zDwJL9x2QF/WBLER0/2jI/VASj" ..
	"aj2bdeIoVw3dxCfuUyfBUNgdCos1h8ZSCblJT3Yi2Z+xnW8qjc+da5vROjGl5TXhgwGxKGpWWdQtJPbgdH1Pe3/wyWx6OBvZ4Cr2" ..
	"T8IK14A8idixaJZ+Zbfqw0NKelqXNh6ud6AQJG6vOg3n4qUsn/zAsMzBF9DGGaBBU4Qwiy0WrPP2expGOHm3lxLY+MkJdtId4qHU" ..
	"VlrJa1fgw3o4mpZeYPQuyw8Cpkc0jNlDLzKg/eQCGQv218xinpfXXAEcrsBQwXM34n/7QwOrF+iJFSk3znoQN0j6v2XZdmfMckkH" ..
	"RoYCWeUr9f+uIZ34ARu8QHhwYOeHp8Xt6R7uMwq4onnp+fuIg3oG2lTC7GlhM2z7IVoZ8PO8078EvqDGrrvPVFsqD2PEPJvF2Rz5" ..
	"LcblKfUiZyKNSRoQSlAWg1tPbc6vnwhHuE8sBPcUhypI4Ka0UPoqwWIISvOwrbPI8L6jb5g6SuG0NHR6/yAv3qwtP9YdUKDYWNll" ..
	"Tl5342uBbHqWlB8kdVSWNac6iuS3MgrZzjtVBJRAdLOojlNl9kCw1LJKzGZbJtsXbt+9ZBufhTrEOvSHBLF9381EiKvPySI6N1Si" ..
	"QVheXpDOmls9ePwVQsR9yaQ6voTvxRrQw7qEmP9gUYncSEpfKP3cMO2dfCBdb6VSHnUAFD+azXLReZ6hqgN4Yfw+/3zUktZ3FeOO" ..
	"x3CPdJJDM32ko3qIGScSMhOdtgkeH4y+5OeukKH8ZH4+dQM5byyEPY0n1ios6YtbSnhrCydIB4oxo34XfqqaiQ7ESeoUuqgD+PaN" ..
	"PVd5DSgfggP8ZB6WyKd61/Syb8LXVnzGOaZrp7LHhKCna41oHLHUm5AOOYRUItr6KN3hL+WBUchoy+TxluKMnjW/lf0ns0x1qRJm" ..
	"sEM6m7z8mNdK+JKAipVAJb0xGfptZs2MjzLgLejpj/YimM7Zk7KEu6hDob1W1MBJyWG3Q7Bb8kjKtV8uxOMsCOnVnXSKlftEc244" ..
	"DwDpffbPIPE1Ovg8SdJwiUivZY/eIRWmgBfUr2F44GrDliVC2spKm0x39Da5t1zigj5W+zvEC5ugW0hzNFO3Sv8TzLotcr7U5JKq" ..
	"T31AHbYNeITOPPcVttTbAvr5juFIn2US/cxfXATMR6mEWO9BzKPltLPjE+VauqmudvKVyiS8BsdKvseBLlBZJpmb8tjN37Z7gFmv" ..
	"gXN7ROsdhnZSPZDTr0SQYPd33bnhjuyq72iDHwvsyESuqomqeluAjuR2Hx9RAHYwJzL5VyNvx5j/9Vma8hTSHcFtGPSoA6hcC3iC" ..
	"TH3iF46368AZPiM+Od34VS9TXalAnnJXRlBodFsaa5taus38N8woz5dycJqY2MoL8gR4cv5Fn2vHdV6NWPBkp0GNSMTMNDkwro2V" ..
	"T6DjLedG4ZeXtiM9tyrdSwQQEeLYU1qEkqYowmo6warPPub20Hi+Y96mK/zvYNN1aeR8KC2C/eQ+0p/KXUdhMVpD6vrJQtyMGXBp" ..
	"EUjBITb5s6OagETvCZwfznVqxroxiwZCbgLrQnRw8slV1c3XTDhuU2Gm6EpLGkhG11m20imotzIHyJ0//LsmBVr5zfZgaodg1oJL" ..
	"I5m02eg8FBOz+L8puZZKSgCUB2fa8qs4hf+LmjAl0RVf6Wd/s8W/5WWk/v4agm7RbdvVPVkG0/qUjomrQZuWS4NrBiIGqpKtydUR" ..
	"/jzb8dc8QOr8mXZfF9oefOOhCkbsd/4jGhpp4JvQt2RIa0zl9TIXQ+m1Uzc0thZj912xzmb9fzsZmWvWxu7iS1ZDPBotZsIdzVzF" ..
	"fMTqOsfiv/GQnVDD1/jfLwd48RKfIvGlkgcrr7QRi4zYyX/WVa4ORSOg0ESPfAyEXMr8tiKUXUILq4Nj8+lN1clIvSnfTr9jhwI9" ..
	"2oO/wFgrzCmQ9Rmme00g6VQqN8X4fo7UZT83aaG6ae4podPKruFqFeaHY8WEG3sotUEs1a1lVZFO4PzUyOUAFclam8g0xhmd2X4P" ..
	"p7HMjVWRJ+fSeH61+QpgBcjY/nicdIaLi5Bo0QSQmXVoYhwE7PNqX60zdQul1uAjITmNNHs5QrxE6UPX/nyS/2rRFMqBUxJaXbL8" ..
	""
local PAYLOAD_P2 =
	"blozZzQjF+gPLEa2xynaPpY2FfRLMV0ko0GQhNp8gH56hMoRKKM1fnKAVFfXcVAdu+Mg5FLmmMijQamckKTVBgbA68+ceAapyCj1" ..
	"j6LHBzaNWWjLAR7kLQneR6VamoMp9kcv6yxTs1/Cjtjcj33lHtuOXRuJjaIPYFPFY7BxDvfVyojd3bahslGzYOMiPEEbC92SxAU5" ..
	"dKGTOdrakdai5GE/7zPWSJTlVti67nA9/flr5BAQN9jPOPc2lzX7aPCyYPbSrYGZ3AmrUv4a6xwgLFRWGPBnrb+lKrhDGHfKZRe9" ..
	"8xOP0ruQ9vUBceTJJLoGFD79Hg8qcSekHXFXuMlkIBfXbVrsYbefeyz463hmKnhPSh6nrWKLOhvgidaV7eRR7UtvA8IEphF/r8YK" ..
	"uGIrXUYiZNjUZ5B/kPYNnF+JOX+KPK6dO4MiYwQ+LDgHuNXJoGf6EuxINdAmL9OfIlMSAfoeFEGbyq5BHIlH+nDsBeGeGHWapA8D" ..
	"T2QvEFGuTfywCk1MNOFb7dHSF5POAbWmt1Da+VsjM59iM6Tix/839x+egW7kYoT0okdw9aw297iWDFkNSvl8BIuRTopDn+UudPHb" ..
	"3kwgsFTwkCMDLz3bVEa0zfcDrRI0nFweZZIjXrjNZaNnOInBvl8hdA0rnORcoRhrPxKGYMVa/fC6R8ncqkXMJg9K61egNKoLyP7O" ..
	"5ycpFhwap4yfe4/H6bMI0/lBO4IjAsJMNui+cvJxUT5pbBsBsX1KkHZlLBCBrUhEFSvka1oCLU9Qof37VgPlQIF9WFF2GmGawCvH" ..
	"O3EiDsYzaG+lppHa0676OrY7lcJB7w1/4eKlAycIWRikkb1r1XvINsN1ENX71EclpC5CpLSvDFjI9WzpNtQeQ6GJ1RNTnZlLMaZW" ..
	"5R8uyRisRGk7Pyb1P4R/YaL32bigSpdtvw2E7PWlTNq0xzYk+4NP1Vx67FnaSEK5Xl4IYLRipYbuUjsLefdYzf9quYDzvJe5kxN9" ..
	"c0c809IsMqFIfM5OJ8PW7LwacgaEXeJmjVW73C3Ko4Am0bny27YeGXMtFmklVlcBavdJ6xQVQRYoHLnkmvMNxckRkwI5zFNMNXqa" ..
	"YFT/YeXiYFJxEjURdL2aSxKEnTih412JLuwqRI/SGZuVek40AqRLYgMwYb7gGOeTu8qTpZXlP1ALndMSuCxsRXFgJOdQr3/FzkkR" ..
	"EHgWS8tJZm5pVhwnJrjpP/XaHmE5kheaX1X8IKNeBnGPSSD9B+L6n6bpPgS4l7agt/TijORK8ujoiTKugS4bTkAcro7yjhg6fIAW" ..
	"qDJY1Pue04DvGLXunBS75UxH51W4D+s4zNcwjo+MJupfVi17W/HOBrwjkwGGGtqfR+7hz7xfYUEZVn3qLOSMZ/bdXjmbDJvzpYea" ..
	"l7Psv0yId/heWxIcH/qoy9/DlabPserIdlqJTFaZQ5Zh4RPdEfL0MhviKc5XdA4MIzQV9SODqE66AU0H3mFZ2QQFTQzHbg2H2Ee0" ..
	"dDFgQISMGI7WLqNvUn0xquZhyfJI+VzVZhQ3Ufk+jq9XJyjGGerN7gzPVdIdTz9579SY0r0XQMqcjPJdzTMhmGWqGoHCKhp02hgS" ..
	"yUp6IAxUcNYXA8yd6KsOZmQysGnhcC2kBgrpIHVQJqWep24QQpRMP5dPROOtcngmgPZWW1lXnh4GwGvoR3Gb2yNZVsAjKPVhswqb" ..
	"jyMfb1IuYvfmrB+LAw7Atl1sSIWbD/XtGa8Aecsco7gC714wUMgdJRCpownFTHbhQ6JU5/8crBKWU7rqwMDEojzcXkDSeC4BwixT" ..
	"2qPXBQE9dHrzx8LQA5hkiLaBu62U03RYKq7dYMTug7aq1f3ChAsG1JzEIzD796IM/lKfji3fVCRO5sMXhDEH4dtfhVL5xI0Me3vn" ..
	"g/HpNVEpid6cbV85P72RmFWhq3QgnahYK+0c7Me66FiAWqwmzfaRnV8p9SR6/PmjLAzL58H/S632fl52usvqT2TI2+gBEV6UGMpH" ..
	"KOlBD0A+77LWGpenNhPGm7mLyB7B/UCPtimqQfjSvKBTqEUtLRcXkFPwnyJd78Ak1Q/UN5PV870SgIAXHEFlSADnwfYfpU8KixfG" ..
	"ee74ZEyjll7VDiN0t1oP+7dXd/wXaFtEL2lwKgrLMpvcTBbgpxCpkSI+CIkgjWbbX+niIis0PlR8Xe/nC9QLOuSaPbmwCFR7b81T" ..
	"yiNIOzuKiUEFMhKFU56IiMn6q5Q32odA0HSqHPL4sfAhIXmHKc+Ph+RSAXehL7Qba3ZK+L2ldyOi7b3E4uLdviitVtnGScv2Kt+Y" ..
	"E9VhyNoq4pygoOpb9Bhle1m0FhVm+C+qKideVYBr2Ic2aQdtJeVIwRUrBEIniusRr2sQoxGJD3v3HGfv/QTPQK8bjgYKEKbDgCdN" ..
	"v3qedp64yJd8OXNcJhfUk1ayfbvZhwSFIo65XRr4++ZBwj45+b7OWk6gvZNzYiVlbopGY3YLCNI9dcBpXyDA7LQ9rNLuPfmH3wiK" ..
	"Sw8jyNyFnomLcb+e92lSpCRTrARmzvZqPPgNouasgVbmk1kXJX+bxouehIKu74gbfnU8LyADx6nFFda5tpnvQTa5uz1eYxlekCxW" ..
	"BNtmQ5R1Anz/cYfvmfV6NZjVgDITcK/up/gIEbslr9BbkjV1R+QBwGh2GOj7eS39IB+JSIqup5PM1ouqpL46NQOTmZUVGb0lvDMD" ..
	"vD/cwkR69jZ+kgh8I/dfJVY+pzbASHqgcrk7D0qG8DYd9P7OTBP0yOLWRoMPk2SgHXY+uL+L9zOKBrqt/osWkO0zuEPG1eqVBXr3" ..
	"WXYZORhzMjYNOIFms0uiP6wsAcRJk80+3lOiwEFOf7ixmzgttoSscGK2Lp/OKHPIISCg4QScGzPnedV7pZfo3lFb6AO2Bk9xbV7e" ..
	"IZuxbKfBN0PFx417sUHHDwGY8mPxDnLfMn+niioiFYfHeMoc8GBbZnCIsFi2JFGOjYxxTylqW5CSYOSKj2ajtBngJdxbsHHMm32i" ..
	"lg+T5d58EWm7mxnyv5CkrQSFCKfKK58m+7FkW6KFYtfDJqUTqgO92K24NRpd7QpjI9oqVYCpnXGfA/kfnAP5GygEUOANjtDZ6rH7" ..
	"jYRUjz4cqLK9ZQZD3BMf8gEZrS0mX3+2RRZudx8JnIk5IA8qM5Iu+EZ3IBMfBwFf9Pb2Fzxgu0scZ3jtysaa6js7yIg1GdDG9OtP" ..
	"4bB+gj1c0pqws+afGEKaXhnRfHi+emYacKlat/xmlUMiRzJnYV80FRRp1FJSnbvJVKuBfK7dO+2BPtCkZk2YjkG5NyIk8p3ktJCt" ..
	"srH5rIhSVMXQhHKmQ2Z/Fkp4OZJD7RC8j7wBQJTBf5plOC7KYtNWj7HNa4re1fQxaHpWcGe965kZJo5ArNep38SIxS8DSV1Y4JCA" ..
	"6ihJ1JIv71tfgCNr6Lch9qXYM5Fk/T5n9Rolo8hB3bzFuzcn5hHD41JGsxx9e/z01vVqLYK4ayT2GDHfVxuBSsaFtwkoVGQPukSF" ..
	"0syxbV9vBue+lX7h0mcN6UhVHSV8kRZQIyZDYJFWyzPlyE7LgmI2yBrbprS5Dc8lZortRTH5stbWAFaRlOxnMayhUZn2bvDLY0rM" ..
	"CjRk7rVp/rmzIB4DEZrHJjXBtiVE93UncFhtE3vjjTyej+lyObMLsXzjMU8RrP52DAfqVLxgilTjUgJGCpNO04PDn7BXpj9byTTL" ..
	"L75FfmZwimwSas+gKjK1UewSQmAOljrOs1G2Fjbs0O7KTTrkL4bAbBvbDCtjgxxKxZXHRWbruXzYaMPqMG+TVGBhLKrlBKeWQR5n" ..
	"seN9jNb2xdnAStwzqUcYQkbzkYOyxkNUYMdJ62jRfgKQ3MxFFWM7Ip73m6DEjJaAiP5W1fabAKgjR2ifWf4Kgzb0wzDrrksndtFa" ..
	"p2USvnJCaTG7qUvT+cI69dx4hgmMFB9Ju4mlxEN3D/CpYCJqQcHgfm0p3BY6Z6WCLccN/iTY7hDZdG0Uz3mw95boOU7To0o0XGBi" ..
	"vqGJ8f8NjMHNy4dcT2qyFAK0fSBGLimCjjRjl24orqe5nSL5erR1tN+RxB7OylGmihf2OLTraLwHe88Z0d3t6XFv66vEfWkW7FwP" ..
	"ebnH9qozddRaX4xZW4tOp5qhE0GDRKa15oLech6HVi74nWNiiVITrTTVuA8tbr04tYKtSIxr6puJSWYRO5r6yBnZvaJHn6Ixiz1C" ..
	"1Z6PIThG/xOKtC6avYkCmKO1SOi9ZjEwlqUnigXLC2Sl0NfAJuOXrIjHHge7ezfCQEUdQdlCGdFw1j7Eo9zK1IkXR8lUYohBCeMW" ..
	"4Gjfw+BnzE2k14B6cPrm4tFQ5tN55DW/IuiDGlYh0VRjcHTVLc4K4qEe/KwzkPMBxjtFxuEAmp2Z7DwgHXby1e9M3q+O3i9Dks22" ..
	"d3hfInbR8qsvqe84qxDDSyKIE4BxxHIfkki2TikamhFC1UaJhP+fG7BmqYSAbeGmPYkHOVIr50K3P5aGUL5n6g4m4QrwZz5lUhRb" ..
	"Vhg6cASqTUwXf8YBmarsZ3BsV2prfDgvR5zGrO/5eYvaMer6MY570zv/vtPnkP3gZ5E7D8SFw/9pBKWJ8/Z2dC5VNAxNR8+caE2h" ..
	"sfBx00OD0RY8QCxX8Et8XZrxVbAzCJSmJ0WnG7l7bUYDEMkcWzAAmGbPLVPcn4b71JjzXsIGHiuPW0++aBeca+1Ggxcm3iU6w/kh" ..
	"x3edPFP2mODknbCqR2pVM6McQGPStpARMyRlHBXkD3HtidLCcr62Us32bnQzaqGiUQAUsFYbGDXnkIReWe9IgPSk+Y2H2Q1VjFYu" ..
	"I75BlWcVoY7Pl00rPLFj8+psjrueMDpZJqCYOmW48AsOE+JYjEEyLwaG40yI2Wfc59hYNar+VpfB3YHNJP7zJMuwRPzffEowV3mi" ..
	"Zf0uUPvnUbBOwj4uRx/TGfUo4bLyqQiH18pjJVyPR4WYUsPthDV+xR6LNTpsKCn5YHELpUDtXjr/Ay3yJeYPVJIN0FU8jtDHRPZF" ..
	"O1NJulcbgjgVobHEwl80iCDRJFVrKLc9M1H+QMWQkRr4JxJMjVGwK5VzMYWc2KO/rdzKfAkgWmzDK3L9qucRN2Hi+Rya0R96FW82" ..
	"+PzB6tw+oxAzkXXVu4DxPUY2L8LHJY3LD9U8kHZqTMl2yIHcSPkvkrM5nvp9hcRK9AKzkVZX17ANcf1eQuNQn6DJHJRj/MFk4A/c" ..
	"vWFY9gHVRgziSSEMPjTmUwDpFhxiIBoLy/yCaq1qzcTbFBTedYToAFoD7sEaSshJ6JyMYVFFnOmhgNGO3oRoR7F4qQwfSS3qotnq" ..
	"8bbqXlNO6bT8GP6LBMhHuekI4hHrDAuF+LCWg5xLKm2osRY6VQQQTW2tQimrqIMr7efx6scpL1SscDmnv/ARmqDLYSd9PmadhmHN" ..
	"X4/wiUrFtT69F3THoludr+0DzXqRIExadXFd7Me1E8PVnvxGtybi1t3ziDS1WnsgzrzDwLv6rPBHCiinnCTLyEW3yXq6fWpsYALQ" ..
	"nuxdUdCXmgbAf7sle+CTn/yF9NkbREV4ODfJn5oBmda1DnwhwEkH4240tVlW4WZqK/PRKUz24kNTQLhUaldxCATw8xs/bxi04Cjh" ..
	"QEgIcZXAlqo0KzlYKfkp8VjNDed0vXYRybUi8rECGbLyH/TjSl4zwhsMDNIshqEofujVobQVVRpQxcbLYt3rhWdE6WUUUkWjO69G" ..
	"Ahtf1NsqWok6GieoKreLUAuXch7VAyh0eUM06q0mtEnlM52RSa51EH2ArRfeQAh3eZUy3rrtGP8GyAcw68AaMhEwOpOxnOLvpmj7" ..
	"gLgEkHkHQKktk7C7Z7XmkgbVm0NnHdijxnjao/va6tr1j59DosNwge2bCgC9V3n0M2ZWU6DeiguoJniT8jTKuoUqrKapAxi8sFNM" ..
	"9MOv5owQT2xULFV+FgzFDzg4OBck/LKvAdMLPetghzWKis1KcnujWvF81CE+uM8csowTsKGBn7ck0ySNR8SM9Zjfo6s6EmdT89S5" ..
	""
local PAYLOAD_P3 =
	"v3c3q6q2b7RUiGpYrK5/vSMr4saNdtpldB40nlUH6tCm6EbHvhxIDcdFcUckwYZC5D1LQFejTUuZGPm/glQsa7yBszUHISYSbs4D" ..
	"lVTAVYR/oUdNPOnlQ2XDb3HacPs+rUKzFHl8eN/SBw336aasfeLD9jwPuCKphJYZUFl2ooHVrLHvboeXuEsArgCdVIaEa2gJAp4c" ..
	"bkKh8bPoh4IhQvifUDyFOEtFLBtLdXteSQrQtLNwv2BFZASPKWSXaFhxcWTDkvUAccvBKI8+/3pa4qYxRRiKno3emhYi38R8wvKN" ..
	"h97zfWPQrZ93iNGwSTBl6XSobxEMwr0k84DG6ifaIdkPHquFigfYuQRIEGymVRKDfKNyx1gCGv8p9jppt0p0+wLiFQgqvv/LErc4" ..
	"E64vRQxD/zONYYL13MxqPsSQgSoA3f2Hi5TmKnoXG9hyGf2iZA2F5XV5ho6OMyENHa6jePuRjdtZ4GR7XygqeJYu6z8jk19ubdvl" ..
	"czPiGdbGFBTlks85471ycBhkSYAX0QMgS3BFUr4r3T6mYGoj1hfh14c0IEiho+IJXLAdF1smHoeQKZSbXpg8ehSAklNSvob0sXGL" ..
	"22twI/aI8fNceHpCWPetbsXdX+YQqfI0Nt8BzmU9gX0wgNy8JMciyN1Q+N1a4QCMADWCmIfoDBcOz4G9b01LBuAoXnlWByo2OkhX" ..
	"4eQNCpmUJYEXK2KWq2H423e/2zk2pWdqXi6ttM1wWHIL7/cvnzGSovzHKGJxFx/pvoBwjljH0MMzyBYNnlUUXnmWBPlYMOEfSksr" ..
	"tTtPLk/0T/fVRbbXt7teCG+Wv9LRCkomD2qzK+BqY7azsv5laLPKdxG3Nbd26QLcQ/K1TD4ckLf4Az41xv1bkxESuGWX7ncj8tlH" ..
	"jf/F6su9dyXd9otLhqCF+e0sSWMzPZwDR6vBiqxVL5oGkGVDjMru/a32Sk3reEap1KkwRi4sc72Ku7qin9NHu0l2KtUUhk+IFHfM" ..
	"MqyAkSiCVMFG0V+a6rmk4l0oMY+//AgkqNZAXPbO5ho3Q4Bw9YVUFxAUdBxond3w/s6VdXmAwmKMNaWuKjqNYuXK7qcvnbmG+lQE" ..
	"cbr+zlb90e81h/8SmNZD4wpeqpBQswjFY5xVnQ00HmMczSla4STezMO9Ga7FYmFHxYop/je+lChIuEUv/ZB4KpRwnfuzS2scWPjt" ..
	"HSvd0zdoq56uGoGEX//z/Ys68qTmlcvHor5vr5Cgqi/Fw8LeyUFPmCpo4+Tb1sw6AdwwhZ/vL2UcUkXttEuX7V0ddNSVYSzZQ51b" ..
	"A+w0nCwkbWhXNMuEcS0mNLRp7hke/7oh9OAK/yN58XVWOKJlsiZmBiHqi7IfivPBeVIaWigoZNE92ZIgybZwyM6lBRV+2PODe+fk" ..
	"JHMQSFAoK955e7iVXLABtZir4EbuzhJxp/Uh9+6W1C6h6PaMPTlkBrLAfAeqq5jHfjhs4SxI/91qIHuN+6utUul1kJIIM0Fk2L26" ..
	"P75YzlJ4UIxB3T7ctgiHEf5MlJgAiDnih8axss6YNcWMN8zGFeeJP7VBOuEmVikoQALS89qMp8zIhsDCMp0ELxWvcIPdi4zITyOj" ..
	"0/LPwihw6hqx92N3mfqpvsvUhHRhobud4LNb/XDS9htg/v7TmGqP/8o2xBL0/KzEZL1NAGMfuhw9b1t2a8CTiJaCrHqraUlgt2y1" ..
	"iIP5kvizHTwruT1rJR3oUTCvWnBAad7mHUs4FUQJGEledxPdox3Vtn1UTrJptvJHgt9k27hmYYdOeUZEmjx/C7xZEGtN/+41CXzk" ..
	"77omuPMn1rJH7hcq1ysX81KWvyq1+UV/9KBXKH1rL2pAZtYf1ZXnXTkVFcz5wyzPApn1g2a7+SntsXN5KC7o4Se8N2haTwGsrVCA" ..
	"qjsGUYbeZRLdOY5wylBPhyBY7+g8pKlnLFNQNzpg5+SRKQEWXbfeLgLFLLQV9GloAiEKrqoanuqBjlZX5jr9ptbCkIJnPIvhXfpF" ..
	"2xasFVuYTTGaO+tavGAZzBnFI9E6qu9oTQlQYnOhri7UoVYUV8PvNUmJA0ZRzooxPXJ9UyBv/tbUUFJ6/JkulEJGaV5Q6Ioe47It" ..
	"80tr1TiGPe8Qm/zxwH4JVoPgKTbmXrLwCAAo3O5b8UJt6wP5rvRcmcihmKZr7NVp2otsCAhXynT5TwkpB9B3RrebrIbtpqnrmK5e" ..
	"YJrxcILevU3GSDJ9+P6K3JRFuisfGNQwVwZyf/WN/Sx9nDrIY9bNPbqPGeCzgJ3BAdbCkRXjJN6MkGVX39qU0BD/c2zl87aVz3HO" ..
	"sLQVHqFEOdH63qJJByTOO/vEOoJPMFHjJwHjw9MOxjX0hNrANzmT35NUbN6V58z28sIF8noHaFu439C8SHg7EGW6LBVtYsOWWl/r" ..
	"Di8UVN+41I+3t18EPZWQUt0qrmPnf290PeIkH8FtrlvwMKDFJE/Znk5QdL/y4mN6+HSU091L2TpXGaay6yrW2q44ftt6vvXHZt9w" ..
	"jpgB1cIQLMXlwEWnXBnZAdawynx0ei0KCWmMCo1UWbzpE35qJa35OspO7lR39jL1olFzBFTI2s3UOshaCrPMzRfO5T0qiUgYomR1" ..
	"YlNW3NyYloVN3u1wQJxLKD4wAdFGfg8Xt6prPLbWL4eOpu3zZUv4wrY0gKlsydlEvcdafmTdBRaw/w/3FtkRL+GQEx/XCKCxSrQ0" ..
	"nO4dcF5DAvfyRxlDOuNHZfrxzbYN5wJ+QFfpcCqgoS62Uv22DHNUl3hBRr820m5+K5VciOs7cqExHpbgHEuKeRDHbmKSpzxvX2eW" ..
	"4SPs1vlwpToD8ngHC5Fsp9zbBvCtAHW0vXhm74TaOUSDS0lop0B7zKTIedT657yxPUegl6DvCKdgXEqqvwa4XTdTDUoLw2fV6LR4" ..
	"D9+SYsVXJTfX5Un9t8R265otQCKJcdj8Co37hhWtZEi32e7axUqBM+cjVDYWU8DXgbQlHqHmxqo5NTQ3vs8XqZ0MYyU7SJAV8CEr" ..
	"E1RJ+mKGwFObJP1+4Nbru1le5+8RDp5zW/FOTKO50j2zhJ8/DIInIX7FA90nL24OMZUKFxoOmpR45IEVi6EIUrRqtx2EPoQFl5yi" ..
	"ovtZ2RkCi4sJGazgwqLtx/Bh2AMO9Fu1MknRGVvfuJN88g3k80QumyFS/bFOHnncH6G7gh9UoSXKfXNFFVKoSMoQ2t4bDnQ1wIks" ..
	"w3vDWYoFgz7/6xtjjorKKh71g1RzSr4xkOhtJl8YFXJLzKZzwHA38UUvNknvXHDylmNlpxkPZwEGmxwETcXiyUQsLlA89RbybqRp" ..
	"Qkf/doefKjN5aKkgj25s3GJXgZsCm0r1isWRbNjPeusKg1jbAXMRMmivo5bVXWsAG6Qs2caB8TsQ6XNcKj8+33OrzujN5clAE4Ez" ..
	"6TSRxoMa2tzgf8MJCt8/Xl/it0TQCeWGFl7FBC9KNprv7FclLTc0NundE/7Av6Jqrc+pFBoHtXHzRQF33j37gewygiRaWgPNp4XJ" ..
	"cMC0riWtAHtMW+bVmdp7XWQXmKjZauRuPGRDDWDu4xjBDuaIldISHEbpU5fLcYx8UquBPQExiQ1WGxU5urTSMYExWk35CfQRjqmS" ..
	"Wcx3XW+sQjsCZUs8jY7TU6WDfg4VoCKVLoSuHJqHzyud+VEWPY+RaqWbzvnxj0Gh7HAnPCYGenVYKEqM3x7sYFJCq0k6MGcmoLbz" ..
	"kIfmSvzuy8/Ag+jv3CVsUJQ6CSKesAwSU8GQLp3m8YWwJAcVeqUGbdWFg427Vb00xw1CMkTGuTPmjoyNFP2j/3wt2OnKwmLc0BBV" ..
	"YPCqndWiTwAxxaImSdsmvL4iLNmYNPDn1jPhqqlAsc9zyz1zmpZa9pkaJLK4G9C34qIUrcu7I+ARaViPihhMcwqbGtY9Pj+kA3xh" ..
	"UAoTQHbOoDpEyyGiCbTHnf2TkdXjPXYIfCxhyjn3LY0ckk3wLRyMZ03K0hQ7RzU4K2/C5erPvixJU0I0u0YsSxrVX3/11ceAcN+F" ..
	"LYNJh+N+ngT/kFGFxgIXSv0I3S2jtNDEV/YNTfwjg87lefNjd7AOyvbzpshtRHVks5FuHkgsmubMvFTD/ohLiMU257qzPgyiaW4P" ..
	"0ThwvhWa53nsVhgHYqZ//7Xfbbmraozxxp5K+sBDTPg4s7byUuYKQwRkNkO1SJlB1+XUZmsqHoDkuIHlGiYtSuLNF0teR2SvXehT" ..
	"SR3mRbvpJxrTsvcOjvua+QSzfat8f7XnsXxRznQr5y7ZNj47ow+eaEBBrMVVfL+g7LHon5a0Np+tuyl4btihbM60hQo9po8To127" ..
	"rHnvgFo6EHySVdJkRMnT3F5xB+yLm0mfPmriiPF75FRJ0HhO5p56xhdYuEKpTpLRX2G+KElzzwOqPU+DzypxxuVe9jegfCeTT7+I" ..
	"3I1yvZ4Bc1FvmoEetFwBtbwoFYkbgrDpnnZS/AJROj0F/mvMSNP6F3Wtia8q8p7hecFRMXuVzmGC8eiE7kqMKnjbbHccgO0VwP8j" ..
	"PfhngZ6GUsgEsTaHkHZbXurHRqUbQl/nZbu9D0h+w1i6CK77THAvZUgeJHQ0LyxLrAx2hqAIDSLKerDQKjaY4bPzA7IYIH9TMlMC" ..
	"iQte0+und+cIn+M4dmn4csddVRKKUiZdHJUmwh//5j0nHVLyhkHnGE1EMXyvO29O2d1L/1O+uJ/3BRYfJRMW7B81c9xYLNNsvA1P" ..
	"bonLj8U1wLnwxFXwAny2ED5Wyg5WxJjyQO+mj/wp+Y2gj0h6MAIqmCmUjrAC2kwuyHnAbtQlxsbhV4oizYWyhwzvvGxQbX7Qul2a" ..
	"6CzskfRINj+OP1n2pOkfQNKvYNahxgZOxmdfaUNuBf+pNxQA1BRCFCTNdsZLc74Q0ALpK2mZWZDh3AN69T+pNoCZWbEn0UrnT0Ln" ..
	"2/0TWDYxGaeKla3vXPTSFMdjAc8al33EjIScanLFHjTmdUops76snnaUVfB1z3S9IxhHXTbkwqN+CFJRRTUSUs8MYjS+GCleBp9M" ..
	"SSeYc0Qy9GnE+8PMyRaZ3twN2FkyMiceF/5FBXzo41aIOEW++e95VjPG4uLyf1hjDBW5w1S33umaMqo+/9Selabx80Z7ivCQq1TY" ..
	"lb8ep8AD0eYDoWBtiyAI09sBElDw9h4clPYgyrEiqLxdFpFvTr4T9ccekbn8yw+2GakVd4Zty82su7a2bU0dVIHMmjARKnzQiNAD" ..
	"IrUkorwd7q7yJQt1rNlc/wQssj+a7YTKThfKwM4Q3Sqs9rTIGCdS1TqhmddvUbrO4N5fFhz1A6Mks4XbOCzZqhBFZJ40+2tkQ1RT" ..
	"M6nQexocDepuuwsi7fZrRvcX0xTXP2obHn59lK+3u1bvjYYKPMHYocNDm8nQhzzEwSPpy+oHQFwTrU+iLMdb2wYFD5LC1SrkThD+" ..
	"rqIkL19VTRvWuacszCoquk6ECHBI0uGyqpNilmSXs+Kuhq2+E2DV5KunhQ0bltPPkdLgWe7tYM8ZbJBf41NlmVsYkps1mUFnUwqX" ..
	"KMO38P6xkiDW+b6fNHFrEt49pPECImPTqbAnpFDUZX+pp1mhjcSycnX/RKh9wOQddN8sueDhGrRWPxYG9F5BcSU6NDq0LHfHA5R5" ..
	"LcfYb2WxmVBi6lZA3GrYhfVXg3ta6v4y7wMLVlYfmy44dlcmZXm8UQ7a4vRSSKdLtd+uuBWmeloE1Kw2i2OG9fXcox/F1wWQmLXQ" ..
	"eN2AKD0+rxiOPJtgAqwWRGc4Ov92n8LRn37J13Mf1iyxpWB9wLQAMYOD1/dGydNhg8xJ4QmlwcqI48h0rg5sySgpS3T7xLt6Xq36" ..
	"B6j7PIICh191NInaUA/z62hmcu18nTrZwCVETYl/CLvJuNzUN9agkJtzshgCazChpbz5ayAEDj/AsSw+rGS2aJQPS1Y21WenasIO" ..
	"mdeMcVRq6dNI+8fI8/fCk6mBRAWXDLMQ7bZla5Wt78Oo0xx6rhVGhX0fQsBGscfXiSXJlJ7LFN5gWahjbAUCyoxcQ3VgdKiznXD8" ..
	""
local PAYLOAD_P4 =
	"4K1l/vcgoXkBsYS6iZzAu1rvR3Gk3Q+R63dawe89yJR27NY8XsMasabZNlU/1vdv1KuNejpZIhsBFVADulElMgB9Z8U9MwZgY/wX" ..
	"QbAykalScBmeXBJgAlkwnkHQYP1yd06r07OQj0iT2/Sx+2Ua78Usb7jNh9b4bJSJPcwuQ4sXgKqCyDJ4Mh6aUAePa50odjOhQf1g" ..
	"gozylvGQoCnJFk0Yf3xz4u5m1VPnm4xtaVxZSZar/71Y1xa3TpV8MWiYsttU800i87YUwe6NlsI+al6n+LmkwYWRdscHAHFVI1I0" ..
	"G5LKSU0u+jjYm02wCAKJKW6LHZ7kLgxqxmE40mtfeOgfnFwZXa5BHFLNbmfJP0YLre4z8sEro/NOXU+0oK0UP3P4RGL82lICRd3g" ..
	"b2TYnq/iIyTAcUMt8nK+Toe9R4K6cNi+K1CnOtCiU3UlQz5jYvFaZTdTLb/+ieuhphHlwSFsMPrfEg/6ss6LhvQzbGaYUfGb2tdo" ..
	"sTcfYipupyty2wc1Mv+mucO0cuDcTV8ZA5+pfiZmZCECGDvJ3YO/IHe22EG/MKbs3U5bwzXTPpJaQGKg2HKud0XsNLvyRQx4SFx0" ..
	"cPCfnwK0um1Kt9JxCn3sI8mz0w7sOg8xmxDxzitW3n0DvCZ5rszFIQBI13TfstlE3cCtOGzDpDj0Ch5Pb1aeaIlhDRm4DgOR489n" ..
	"7Y16U4dErpubsTdUnBcWMiK4xWWu+t5KPSoUEgq6VF2mKpbbXHUPmA3nyzXo2bv5yBIORBzPUeL/S62JPSP1grTEKhrNNofnJYkG" ..
	"JDgSx/nmRaJ3PeBcKjKKsM/M9UJlyVwCsXSpJ+87ncKRbYPfojUQciIiVAkXvwZdeOup+6o1wOaI+nF5c+xpAbljZYR1WjdcrTVI" ..
	"+MkE+AX7XRKFbQvBRuHMOZ+0AsdI6pusZTVJf1Zpb7m63ASU70l1fYeHp1hXTFytbHIvdeRzfcaQ5/jHamoi6itasYjMxbtc52PM" ..
	"O8rM/KqQlqy5yS69MOok8xmRewY2M212pY0e2fFuK5NYe7d/LkOAF/TUHP1VQZAwnZ80XVHVEZdg1dYxY6UBxQNEJctCIx1aRFr9" ..
	"uHoKzwCjQYob3LbLG0VsAG6r0F+MfuYnnFGxJrQqNWU7+OefCE3RrtawOS4YbORP3RD0kBiJcUrNyRNK4Ir0eE6BMXIyqWYyEZOm" ..
	"dPopwE3KuNH7dkcQu6+BOFI5utquh9ODpux6d40NkZePAQXsBZ/IPvbSKUcd3IadxbicZc8RmouMB0kOta8WzH0tccWMSytXkIpj" ..
	"zxg8c5lpR0kAYuBuH/PuZAdRPz816BedruNldzi+yQ++Uyu6nxJYaNcEs08m1y1KEHWhIVZjHAOBxlll51C1ffnubAva4/MNgWuN" ..
	"GQiTptCOEpRRPTe9FT5tIguZ2JJD5ZQGkUh90ngG2DP7tyRAw+e/r1mf2BAoaS8pm7mMDWltRoXGHEddIhJ8Spubm+LlzPOtcWHf" ..
	"FN+QrGYKRJVh67NYZLwDlUrksZCzVzzhbE69LhMOR3k6gadzgRlwjfODe6fGCVtZnbc9ZnFai57ZstGdUQ3FtRwMnVeEV0K4wVhx" ..
	"JJDt93mzGxuOXIjKnbU07S4MtI8e+K2xx/ITu8dvgIZD25aCrcvDyUSPNsLzqxQ2pIyquT8JbhLWjsnsvoGassDaskQ1CmhsKyzn" ..
	"vofpJEwQiePb5bEipue8uJ8HqUcMRHv6m2X0HQhnFXYPWhCN7Tkho05Viajt/9pZnSPvcu8NTgptRxdN2UMfs6S8lAp9uSc1d0l+" ..
	"udJru9OodHk1sTZHZ7u47NWVqri8OTIrrRu9xSFVtFVtB3081gXlgE+IzhV6TmhcuDY0I77WQ7EpZl/qEBQJI1qCIiZ9CsJbAIax" ..
	"4/tSjFU2f9Id8sbFFwQmEnCXtUvALRlIJHMjbqVCehT7j5uxKg+dSzmfQO+NFSJ3+ff5KoLa56fhgr8gwpUaQJMpG3V+g1qnvdnX" ..
	"bSmqhwBKio+y0fTcqpl3RXtTVrgpY4bvdXn4E5DgpCzJcxrnx9Vi2VZo2DCOcKy0tATk7eSHY1d8Ok1jR+8Ke9d/h0qNDRvTNagW" ..
	"jIR7jDvEg6pJHmg0+EA7aK42Thn65SreCGM/7x5MmUsbnPOzmFgrvJYXyFmtJQdk8984FaSE6BIWl8iQKybp0hlgt0ktvq+3S2sW" ..
	"K/Cus1Cs8s17NZfyYnGByCarzNNa9Hdgs6vg8/NXqFVgHXOqF6FVUYwchE+ZvBtKOnycnXmpBST+Z+68ZHm8FgYuMY9hlzVRJHxf" ..
	"OLwyEXg6OlT3zqF7AnAZnq+YQcxL3e5AMplmyJyHY3FFh2QfxoY82omBACENOL0CvEqItzhpkiYXd/s9KFq/NS9kt+1NOFwMfUiC" ..
	"o1g0vZoEkj6MXE+SKuVF5/E3sESlf3q1eix2aGhCrmqtAtZ9RfVEJCAiDx3hBkw7JVPyWdaaylsBfQb7XWny5XlJSO6lliikFq72" ..
	"mH4dwGl4cjzm9ygbc+6HEbF7/CmADQjCVPXUSR1MXd/osS7hf7ggErNpv4qcJ+W9Vl3NaIGNhPUgzB//y0TDMTmzAMEl5t/QsF+E" ..
	"ummOKdd2NKKvJzTgB+cohvFW3if8FpFCBhsNmXXEaRA0ITWNNdmfwnhTt9uwiKDZMY55yTHhnzkxJjlC7Dd75lZYsvy79kPfaCdT" ..
	"WNYBtLReESg/YzFvGQ/jTU/0TESzVV3RPgjF7pzRerqEZoF4FltR3dHoVdPT0nL3AH2dKMsiUJy4xVTsz57bzIlNgHKUitRaW6zL" ..
	"ap7pm/luwvk+c2ZCZbTqA3d5wPw6hpZ9tD9o8IdLXdCLGjHdj1VCvkBok6TptMPmWHaYRUcNjm0Mz4L/AENHdk2aC1wKnYMknHyW" ..
	"u7cfdyYJoqXBfyKjH/HaPwBA9ijcPKT7ijwWa+T46VbJyc+49Dc29x8PKWG++KhSGveD18BrJAN+kse0txR4VIJ/Ati8XRaRP4W7" ..
	"9xBRHt2hW7ZmN+APfNZTXie0jTvmIG16pk1h+YnBn/PilaJc87gAEG9pyJKXrpY23lQLP/TF3DWCQ3jMs6RtO+Gi6qDxWSTJTW4r" ..
	"hMRVNnHjbwu2yD71CFMjGt8fH0zTdoHE82/jvDFYmz/cKw2smef7z9pQFKx+DhjtM84SyeuJfwHTgWfQHrIHuPGLas/KTKHv3XUe" ..
	"m1m7Py24EGC2Mom21TBzxL385e3cWzG6Cz6y21PHO7peUnrgATB5vSQpY2Qn6Mf5xKx3KPz+TAonOL6I1kCPI4XQH04x7+Dqj9ND" ..
	"OwEz+ckAy0kuhfT7qK+GQf3oGiWzfBND4bHROKZyMOHKgTwUkAtjD68NZmbxoSdsuI8Szrl7RKATp7mEBN8Ft1VDYGqaoGzoxxw0" ..
	"XfcJYGfnDDgeEyDTzA7u0A4j+Sh/eLYC8z7ULb907rWNEWtqtEYGb34FFC5cuxqVWUx5RKcXONqGak6Zv6pXzNgQVdpygYQ7OBmC" ..
	"7T+sgbzGa1Hl5x710dWOenMq4BfuRGM1jo6uXpLlVKD9ZlVZyfX20nR/5DwSI0gjRkTbYidPKNcCPEkQzJ++i6qs0itSZi0qzsLr" ..
	"lhxhmewOVthTCFwU+84dHfx6jqkQpxB5DzRlIR2ReOBQ3ZF68slsHvlXF1Mk8WmWQWQZdUGdH8YbVdV4Zy3VayCRUlES6xf1qhm4" ..
	"PC6JND3bmo12Apo+Pvsc73SO9ghBtXQsP7abzqShser24sKjg/0/ineA1QG8BaX6L3NMwrpr6V0BluxBIKtz9i3IfNnW5qYFnkGT" ..
	"yZFuHuujPP6+geTL3PMreg6vKFeCNtFiTxChq5Z/50R0rNWTQbkJJCSBJHnh87YpQ+QNIHtVFde6InUoYn4/I77rn0bRTpUjkI/5" ..
	"WYBD0PLzSrO/aKFBozLhGhObf3zVaogo2fRCPFK2xwmstHBc7xIcORXl/VfPGJF0xewum8paSd1iBHidMtV90mav6O9xJA8B7+Ko" ..
	"vYj+WWuXmudnwYBPBYuuGNJrPPPHJeop9aq3EVBmWiPYjNR4eHWP1Bev9DfGIbQq7mD0b2A5b/KBD/11E+Vzj5ag+/YBEL1WajPk" ..
	"KP1JAoRifmSBsulwH6NxKCEXG3/kY24GfHL9vpjBo+LB+W1RJ91rYdJSQ6nplDUGOXV3G7PfkCThzWpgWvKn+d9V9qasSLfcWa6Y" ..
	"5BoyDxzQAxbsqVKVaaZiXzhd+L8kkT9Wyd3agQZ9Zw6gkl0eVX7rZBzuIW4m9QAlEcBld6tMwoCEY3sNIg52jeyHL014fiPbjOA9" ..
	"M3poHYG9OQShbODroX4926hJKG8GR/FGlf+9SJ5rkbH8zrUcrAu9C4Hn3IMexfzzTVWUzeJ0NAxfXU76rMoU3lFtheqbfySswzt0" ..
	"yR4wlKlJeJ1dKtgT2QpBbJpyMytORgeDf3Oclt2wqZHIPPg5idG1wuxZMJMPa7skVCkhYY+bT7CasVhUQq6CpCmW8Ouju2orZgl6" ..
	"iQi/b40JGTTqLlLH4Jr/zyqNPrEJHFuf9ZITp9oJSIAhToPHBzM6KGAzT+OSd5tedE0CFnrpCR9kzuD+9mc8AjuAISaH3PS7WSDo" ..
	"vl7k27m8Awre/J/rOmkRwgg5iGFbWPl+pBqAmWtz8U0iNE/RpM9QKg35Hskx+cG973dWWS7LvPK0lP/+LfufDnwUnR+Dev8NrHJa" ..
	"0+iGLs440w2s/DE8eyIPOb+8fKLw08Vf6der8dURMNfVGjJZBkDGWNnKgrnCZC6Jadha7ooD8pMpB9L1/Z4ZjPLxvG8taaV8dO4B" ..
	"ILEKErtxgWDKeZMrJmis88Q7nEX8xwapy6Gh9S0VGuM6sNgeaS+g1Ny2/BhJfBXq6rmV5g5SIo+dF+MVWNBP39h+0EwdVZdEDDZW" ..
	"jMCQg21X3qR5ZTxm8df9m2eZ+TyUDqXUukSL/AW/VVZefF91U/kyuEFPn1xLgycMR1PM5suRkYvI9nH1tTkkUVe8lFes+9QbOxr7" ..
	"Y1zUhjRguczt3MsoAX4etjXAQPEwuazFxUlrbaoNfL/ggAgaXGwt5kBpIVktTL0DMPOqqcl/GNINEalJJ0mn8Uor0IOPiJr0vXH7" ..
	"BbM6NPRKs1qDK2HJuMMGfN6YHYCqA2NP3qisYEgCAR5nI3xP2k9Ak2t56leygpN8HrkPnWfM2Eju9rQ3Typzm8eEytLEJQQbmI+Y" ..
	"OoeB3OiGsJL9Eo/7s/TzTZmL+rSZlMw0HPeMntm9OrvyCNTUudNIjqAX4FTQYbT5o9WHNCHQPmVA0hGBP0O05g8XyPzS38KTkxdL" ..
	"M3YMG10U5/b/dgfZzIv/fBuTbVYRJBk6VrsxbuMQECCempVJP/75Lcm5JcznjvPLPLwPqKuugvNj9RQWLhnK5KdMn6hSNtV9ETAj" ..
	"g/eE0DlZ5apScDLiw5DrCWgNJ+a+66pZ7GZRi77jqrIahmMqcduYN+0c9NzYEmwHG9lVRryTfph4kVU4n/FiBFFxSKhhJmXHz4ey" ..
	"fJsGNgbW+FX0ZWELWbIAhdn8xnTau5+NulshSHapCoD4Ul9WEHVspiG5OOyDdf7jmbek43sGrmQ+GYKVyKVlzyiY8NcE7A3U+2eB" ..
	"G8KxD2Z5Fpy7eEYqP8VmgzQkybP78So+7JYTyz/Q1S+V9PF5RHcpHVI+dqzb4LNxQlSvIdqmvDAzHaeMKMQef6fPysA6wqjhtSNK" ..
	"rGhR81u/Wm1aw3y3dy6bO2WJJkCEMOcInW4ppJni2SDvJxkLVzTEGWBdsfAV2eEKFK97VJgPXtocfXpbQqnaa+cZdrXWEtaYX4Oj" ..
	"MoiRM6zcFNq1OeACtppud6ogr49nt+hc1Wnn2hOYV/qMcTSWGcDREM2ngwV7ShKugw25YIuPKuE3oTutP1GDKusBlUuWV5lLSHi1" ..
	"ONV4A3zN8vkb1VAzwkF+NblYhQ9+nGaZiSU7iTgcYDYh/v0OCrtl2XPPslCH9owdWv5VI1XAcba7Hj3WMKkQCzEeDmOXfdqd4u1b" ..
	""
local PAYLOAD_P5 =
	"QTJW02rsJPwGiK0f3BOQ3Nx3yQXdL8P3wubR1HqxU/zF8lcmXiNRg4EKoX4t+77tkSAJRotg/dXkj2+8xgg2H3Ln5CF4AXcux5hI" ..
	"kz1JNxG+U7SaZ+TxFgYRlAIfgLgqEl6AbAc6VAqkNEVWS4RADmxOmhesJ/7C7xm0eidK982PrX35L4jlGkwZqvuz61l2+35RY7V4" ..
	"xcpwKaXU1sLntryKzUZSDBjFeJAcEDAlNntXbf+89D0FJU0ZsFeqhqWBko+X3yvzM5eoJKWzpsEfTh0lXIEo6ITj/TW2KAp/xIDt" ..
	"Zapj+sy2KDIbtMI11XYeWwTM6By1LywA7krPodWZl61RVU6mXl6RL6QJqPWaOeJJr9XwrAB0rQlIbU+CaKdv0t/kAqY1DuC7cOQ4" ..
	"z594IlON2pJrk5nWU3Fjm7mdH7eZv8QuRLMNY8D2IKQ71Nm16CfFS91XwrkMLv2XNFEQGV4UlfVslIb9C2gh6858r4r9KSUXsE96" ..
	"wgmUSoRdw2MLe1rGI2Iny3yIZykRqw7EsruDOjHVncK0aYREmaWQN9IitSghF593R/vtTwULyboyXSjUgcF+Q8GC6FmAWMWjP/p7" ..
	"BsAtpN1uZ5Np0LrBOpMk/aAQZPeMA7JJq8WsNlhyu3I5TZ+j8tLx776Afrhx0aF6AT0lB/rZtNjU3ad01HIPw4FSyoTq8MstkI9i" ..
	"428RDhKl5yH4HGYAgDugNNU5zj5Z7gLkdQmQNacrYIzVuTw4gDiCDskLmyr2MgV9VDbRvLTizXBjZzo0JsVT0waUxI4Cxgkmqlcw" ..
	"ixmlSIpiUBjadOrBGe2khdqqSPK2gtJdPXK+ZA0bNNOXjPQZZDElqLg6CS3OmQz6ya3yoLHCP5A6SmjY/aAhHuxiGDPjeNqzKQvu" ..
	"9m6QVhOJsYZRwhZGmX8H+hpKRr/bQCkBOv/fgoPK3aoDKWiaFY5Kgx7mBLhpwn1fE2ksfcqCekfMez/EIo1CX8hI0aW6X+4ZI2rA" ..
	"4Su+OjAeBSSzviLo0laA9AF7Po+aR1hjQbL9sS43pd4A3s6IHHBY8J37j3hhEVakLkVMGpy3uNLfF9OyyEbWlAX2bJy3pbThYwV6" ..
	"82BeTvnD1jVGA7TjZwPMfc9mVxxNWxiGKAdI3304S+2aFOHVsQfMDvpoUZrxcUMy1Y3rWF6lGhC9rIBIaqmf5ilzZi2AHWyfgKgl" ..
	"fuoMH/Uy/3zz96UUzlUd/j1sGar1vqFtMsjjeO/0Bp7LQGVuwxbT2HHp4pQMR/Xsj75Xhy39IyFQORKwvXHLfy7IokDSC2bTdYbq" ..
	"+2QkuCeTHlquxcnl0lj/03Jn4Q/oxkE8IFjk6gLtXg4ciBb4KUihnYVZezYoBK5qE/DrN2LtJn5+TLytj4GO9/ovvDLvms7YmZ/U" ..
	"PD6QVpcT0UjpPUJv3fj/eRsyUQP9d2RxlaedwYvWQqCJpakjFxXEMUtr/Q4QiuZwSilY6Qz292b9BGsb/iSD6gz0IfRxBM9McCtQ" ..
	"lx/HoK+Gl3MdQQJZcGd00I770/KXLvjBGYj0EK9eXwX2FuozWdMkszfHDF2KwJzxvlUNVXIJ8Z42SLNN3iWGECRfUTvKlWoh6nCr" ..
	"wNJs/pqHYykqpQboaWSSFzy2uqm8tofS00JrPztiR+EeE63T50Nv9wkSynm8XXam93/aYVbOt7tD6/modZoQkKbQwR3uSef6HhlP" ..
	"3bxKPcW6uc9q9eScS7dFyUOYe+jLknbu1uXrjNdCaKZukmRjETDWCSSaiIuXb7hUzLEN51+fo2r0ZouiSnMG/gBTJWqLSgxQ1h8H" ..
	"Sd1VRaUJPrDCPEAbMx22XAKU0YUcno0TBWozyCsYSk4cA6hOgrptG5raN2pXSrVdPlGEuwdrOUeTNaGyFws6B/De8KbGORJFtFbz" ..
	"CK1wcaJB77LEJbQ18jhpO3c8m3NjL/J0aDl6lBk3rpxL5WKHxC0W5j8Ug+/7909yixzcoHO0ai4fcug9fWiYPw+ikOx1pcktTgMo" ..
	"+PtC605/bQ+uhMf4rGuMc+OT2ZoBE4c8UPdy3ltUiqOw65qjG5hUCnlFkPgSpD62X9HIiPv+TDT2Z/ZOqzZQIzotUk1CbKu8Ez5f" ..
	"/4u7Ws8DmQItatTz1FBe26LHjoBTDgSzqgZLtsLLzjolfT2/EmJHRJlPGKjIIizLy5ojs84K0/hczK9Hp4NH7n77EAQ95TG/UMBo" ..
	"J96LGIhz6KJ4AD0q2NH2qoOh7UP7cnJhEZfms4GB3QVobH9DRBKIrpPrR5ZBKyLmhw2IUYF7q+2OLphTpzV/jHMcDlJxxhFuSQzk" ..
	"LVUbIQssgjmuu8S/gl8OxJUVggLbaYJXrdYr4FwKQfD4N+gptrPO2X3ZNQ0bASuh4l4pJj98VcLBlV6uymKWCfPVgaQKxYYAfcP7" ..
	"CT4Ikgn2qKqQbCZ+XKBrY3EX719I3NUt125OLVerEoy/Z6fevJOgo+OLj8KctdHJWqpieTQX84I1lPmyNSQQHjtdZy86q/MiSYGF" ..
	"NNubH73Z3uvkNl19aqQO+f8IaoViVvza99tXKa3RmGbgBhm6+WKOik1Im/6QK+LvVKRzWXdREdfkI3HVWXBEa/2M5vU9IznCSET8" ..
	"+1wlWF7pnQmdqxekWvUQpimvFWdQMvn08BMjhWY4lfzpSKHYG+7BUoNmMfIHj78dfmIeeoaJ1SH+Mjizt0YaesP7b7l7bfFyr7GV" ..
	"bFU/dNfj9BIf4dPO7OBclzuNy+EkgNrmWfTH4Fa2Nx2geSLNjo80CMb8xiaLXrMgsRfDY9oWfjQW/LDvU1sFDc967uHkwiDnie2L" ..
	"b0tdiLbjiYatC90WnzII8t7tdUQp4x03ZxowCulyIhzRHo2oLalIWL1VT3pei0X3As6wX260qZjOg/ExZzYS7+AUA/rJCQc4ZPr+" ..
	"pY4NUTO53cRt/etxJfbnD/0KUbPWPsmtbz1UMevAmuUfhYdIlwLA9MHFwIBoWVPH2eJ3E4bo/IuSJhQmizVbzjVc0/owmglvyqaW" ..
	"u3Ile8s7OcovHNArfBXtv9VYNSgrKUsvZFNp3QsLxMPOWM1ifb9e8CDkiox76F9RhiRVkEqVFOFGehW2DETisBmCEbLYBNacJgpK" ..
	"y9xdDu9ihnBFN2dhGiktBffrlmj6GjE9OkoAmWSHDR2ApWg0Zvwr6/RwqOij0/uaZc8Kb+HpmU9fpgSjjOPN0aEkggsilUuDHVvP" ..
	"VnLcLOQThIH1igC+IOoPGNKTkPB/lsXFHvr+pO+PbK6tNThxd3GwPC5FI3Aq/WlvAZu1HDWDcCW+w7LSdKAfWEUFkdzK7ixBNqna" ..
	"PZ7GJAt4a+j5nXg4w8ADej1uQmqyh3Ggl1DLVBlsVWWuSscy/JFpxZ9P0o9Z8CfEoVTg32mCRDDfSBWN0kj+JY2Red6sbyXzjXbG" ..
	"ZkzIfU3K3F5Vr3zpvhpRVUmtqhmE4S0ootvXcIEEy/0WjK6JBBO69C5Q6FeC1TR8VyxJHUQSLpUc2RhXCaYrYZ71K+JhLAzCngvv" ..
	"5VulmxWOtA0eFjAEQIjkRINwXxXOvkhtgGl9iyThfAC17kYPtWaryNbBbNPpcvogkoW1yXCGhcbv/j/4SwefDQbxTjFmkrCsgxcM" ..
	"D0Symy5AYK2OcUIEWBvi6BfNxe4cVDBQ3BmQ05M61OzuJVwJpX1qmnixOUlQbwjGws5TMu2c1BB8Pwy0ZaMbVwVEmOGVJUu7WzfX" ..
	"3ZO4FV7cAQLj90aYE641RC/lkxYKUU5mnEarvhaxsXFPcjtvpibQUq27NL/p+78XCEm7m6ZlLFbD8jrXIxhaFS6+EoIoeYWcwkOS" ..
	"F7S33LG7WKfqBKaK41qepHXbNkwbZeiE1smKPBt43+GqLLs8q3bzzSq4ee7igONwhjQcjrPPyc3ryovKi2Wr2LNDtGDSVzHBZjyv" ..
	"aJy1vj6AGGakuHkpd0ts5eBZsYs4KtRadWdaBeAWEEFBU4xxwpjb6It7z+PeEXSz9lrIMp7MCha+clqivWEkwfaHaLTmecBA5e9t" ..
	"+ffIMI7viz2PsPAaIpW8cRlMqMuPKSXs4gCF14Q2h4f4zZGm/vAa3wpmqkO86ofG0FT7mRsci3Q706GcFW6756UzkxIU28PJw/0y" ..
	"nmDmXJtPtvv90FSC6yJIl3YW75HUDanuesIXZO/DHRL2kY9GkwJTANneAL3wVnGMmXFTQJScWCcAPOf8BuczTeOSL9iafjM2g/oo" ..
	"2+O+neZ6o5aNjydTptatCnf3kmvWtqyipa7pJ0lBVvdP66ML1xNeQCR/WrHigwdlG7znRGxUEvhLqsCEZh827qcvBBTbcyjIE2+5" ..
	"ORwt5TjTGb+RJj02vk/JkriYhNypQMPKRx6kJw/N8rxn67rsS6nIaJ9v8w7KLjlFMQLnSVjVo5OI5lGh+KD/F6qP5IOFue0Wjs/P" ..
	"aKziv5MqWSc7vvGfbrjKFicbucjl9XC80MYFSkkUlrJiAuhgG1xSiQtlbNlMpuj7NnVVIka9f+DmiMbCHjTbzYZWN4bDjXcegVyI" ..
	"fR3Yws0awit3XdTT3mtkjW0iIYkAwjGbrzGKE1dQLzUdadDofraXizQkqzDsRL/YsUbLkBa42I2utK7YGZQFhwREfY0JBsB0o9Mm" ..
	"O6sV5p/g6chmSG1dTXyf/hJO59BxOri2gxLD8sB6LX+NaYGpEP4SN1OzNZADOWmZK1Q43nc20u6qqcIz2NGSCY4AeuYgKAGi4AjQ" ..
	"ZZ/Oa8rOg+y0+pemQxS5NAhyu87isqeYjKUmxF3reOHGBjSzkt2zFoQr/AQMudM2a4AOAUCDb7gOY+afD080CIBcfjekI4zkdn/L" ..
	"ISqEu64REJt6TZRf56VXm1eJoHT6E8ZBVOpyNmK42vnJoPSj8zhUE0E3vASHErr9m+hMKct8WmXjpPDqHBK9WH0a7RHALsrc1MJW" ..
	"+1jpn7+Dx4dztxRUv7KPxdjL/TiGBYstgKPqZUO6dvVf92LTynku3jIObcf1Qy1A4eNDHI/z69HOxGss83TkL/8A4i1Vdlb37xvX" ..
	"mm+34smcR57vFa02+E0CLIFmpdxQZLbusX1AJd/VHUKjax9fuuK18MXFXrFSPSxEX4rtmSbWXBeYsm4mZIOFn8EmxoNlg2AgNZBZ" ..
	"tA7LudwQd7Nl0GUfmsQae4vnPRIHa4RqR3vrk6nbbbuwixJqx281N51zTap0NGTQBAIuO+6lXaARByuU3eJxvpASsStAGx0qGv0U" ..
	"U0gzfdUqHHh3SJizG/Z7zYX7BYK7BJ7QDPapyh0ftYl/EasenuVfQVfCyqZryFg3AujByo3mxK2sJX+7S/NC/g4lIFDuyrqtlnYZ" ..
	"k6vwJS8DM9xWNkqUz2h6OWmV1bW3ZY8jFIA6nFHAt1ywRhfQFPtWTcpS/YEqsSACvW//XpDr3j5c+acntrwpcndsbsNbUzngP0Sv" ..
	"A26vE5twAovCrm9QbYIaT8JeJ6wVVgoIOaf+IQLWrJFLiS2UCbMM/Cw/dpCZlH4CvV9tor2RSkxMNd8gYopbGJ8i51D0rUaCAVby" ..
	"l4lr8VXU20ma+d3gaUVNbasp3DXQ9hHTp45Po8/2y/qeVl+3J5tDqX1bmHjYsx2WqjrB5jwv2I341ADiIb77g5161yHzUCZvExwx" ..
	"TywVp6F4bipZWIeH/ANwmmTC5pF4HsdO/DB7JVMSCMIirjVqajmAeSnueMRNYRPJruE3qRNjNZCFTdpzHeofMY1jqFTnm4b7KQ8K" ..
	"hd+sTWNaRSlUe4MvvXzAzrt1QAlqlnxJq62Mk3At3wMKmeSrRwjGe3KlY/sIOHORUwvIOJYVAN4gnIIn5+j2uxjOM6sJF0ak4yIi" ..
	"7mRrAmvrWBJtvcTVZDTGejPa5Q/XLWdOv6odj9whNsk1572DwnaJlxFm15SDJb8lSqr55YInoSSfx47RhzcmThU4TIArdDpucfb7" ..
	"teUHOCJmMexOdxFmANqcQbSGa8XatM7gcLFsEECugldyxyhvFBqRPIV0SvzByWQvvCUsksUe2vqCbtWBZRBRTmr6ICJHbmHDa8Us" ..
	""
local PAYLOAD_P6 =
	"6UynCF3SR2OHMxXw2JNi9BlrDQXzrjtNeboe/jSyRCRJ+Ivr7XogO1Ka+HLSNZjQ++tOGNhOqStIwMfzf4T7XsJjqFcTwWf24RkW" ..
	"/WHxhZZntDy2jTW3832F1y+NxCegPbBZK/TipD24woceSWymY0OJCRH0nGK3JrA1huxxe2ZpHqSmnud0GpdrZAtq8Gtd6XIHMO/Z" ..
	"IJnAR59LyTrK/T6sDYKyoqcWXrXJ9LHxcBrFogXsJ6m+iNNr0BigAZsswRWcJ+6bvTsjYQFmyignS5LnBKiR7xOnQ7N7YthTKKoX" ..
	"M7jxg6Q5UXVyia6gfXVel5rkCXgnEefQSvk+rHLdjSa4yx+Fhw1zFVp2Ply59bOhiMeHygALRycFWR07iWDmEAvPxRRnFhPB+0oa" ..
	"hwdHAEtcDooZtPp+Q28PXobiCsmahpG92WwBlnfKBwpTlL/mH+vNTOueerM7hng9OgJqEVBx4PFOKJoXVSGF52wcgz7Eqr7lOwUu" ..
	"R5WaxrIrsQ3DilWlOrkykvQ0q1exVefU6/z0xktjnfuYXuGOyo5IjGMuMPY3sC+h4RkT0SPcUG76RzH0amy87QKB5ea2cDdmpDFG" ..
	"nZ63CVmQPemt3y8os15emRwf19T69ffpkIGkTItC+Z71W6tduBAc2VlbAsj44yqtVSCMHnlwKEYkx1hK6V3UjdOvSiJ7QZA1PD5z" ..
	"VwkgVF0ex0QGx0dcZ84Zoo4ZPCuLaEdf87Tau+D6kJ1MtR/s/SOs5Y8LWPAWTUuF7bDgz8aVdEYwy7+Oy11WlZRGoabT0d66QoBG" ..
	"MAkQY1X//wJ6As49LMkuRgGMUx8c4Y0p5pY0qoAk7uCc+oxeEFanyqUOsCRByI9MVowSiVTiFWDrYAqRXbPKJieXuZ6h0yWQpUtu" ..
	"7ZZklxAd4pabUM3d03QM59+hwN8J4jxX21espj+OkO7jTVF3qQbDeOG3XNaz9K3TWFVGZvnTiYzGEf3WGAmZjbpISZNCkOzHuigq" ..
	"fCP7jBbC1HzBikoWA/dg13/ljkxF0CDf+aSrpobLvGFMPTYE+eCy8Abia5RZ643nWfQO8mPbw9obiRA8EZE0OcK+5fd+AipHT5ND" ..
	"ZeERyFE+7i974EatZr/GXfqqYOSdeILWlLP/rvpZNqYDFAN+RzOWZneEX8DJcCR/gbjucCS/T97ls3ioFgtJLpJdi4wmlMnjUNin" ..
	"5Z6WVb9c0Ga6OwMGNuhX8kKDP4WOAU6cZl1vYHtuKwYIIfoBVMuWXI0Mez5bJfZTihVvuwuPuF9bYTxbfzkO2xd/cYslm+eF1dcA" ..
	"0z6d5NfxMEol33KIq8XjVrS6nhYSmCmpin8HqeSH/Dp6QdlNhLEHEueHqdcHRZ6jQhmWVJQ2wmyDTNJZQkOwzzgb05qQYst17wju" ..
	"vrO9Fx/c30GDRIjmW/lkUOlkPRIldiGRqs941TEHC4gzr9dmuravpkjlNtHmrQwm6gGrqu3bIyNitCTRwIKF2C2tHMho93ihI2l3" ..
	"gDSlGpPUpFF61dz+sP7sKpHSClxFa7u7+mySsp9m/anltXgJIv58wJKq1YXkMVg1SSUtg+sqrHVuRXuRSm9CthQugS2m0IKC2FpQ" ..
	"q6rX502k8viFSbrMiLwQgV3GszPLIC+UoxYUCA8NK3JbVV/HoYY8reRTBZ983oc5kMRtPIJRpyk0tKYOJoS05qQpNHARzcRUsaDP" ..
	"+ITps8U9EPx2iKnD4oY31HU1qZDAETUqOYEKErxCaut692LPEBoNB314hoVs2InyPjKcQRl2Y2UfGtyJXL6dCr57rxbu2YPdPgMp" ..
	"gmS3EzM6OuGST8ItiqwZL7ksbl9YhBybY4KPy8p/Cu0eS9eK0plbHytHP1rR2JFtxoh2qEEuVfg7Y/VmxBLN5uNDgnBR8KFpDaJz" ..
	"8/x2ihvjuqO4lVkEjrWr7S4Quf/p0ZJoRe2eZs4uh0DlBeUStfxdUmKbjbWRflrP8EjN39TrLb1dvdnFKf158hBZcw4GjGr37iKa" ..
	"6cjzQHdu1CY2MDeBXcEkHRihwssbm69vKBMVRLSdT9Vu/1FJjphNbWfUbLS4OnEJxGYDg+Gb5Kk27vboP1Ni9hBTvUcQH9AMkTfe" ..
	"iYm5LkSPqVDy3ozBU+s20aUgp7KOqTHdJ2wY/JN+j3YmB3C5TaQg0iXQTG9z6T0NNsypQsNjA7waYd7NN6Kg50KF2Ef/NHZ418ow" ..
	"AadaIsrqZgBXFvwI8D0ksu3CE/z77GT6K69wWpH5r73X5h/EOL4PZbjacnaGXlu85xBUpLyYhL0NWhvAK5RYQl2E1HjIwPkY18/Y" ..
	"AUWGEbrgI+Q+D+YHIOe+fjAh3Qhfs4vX6uC6v9GRvnq99/bXgRx9uKF45TrOeDeGA9V8EJrwPAP6le/Pg7Eg0a9QgqUQjByW2Fet" ..
	"FKeH3ZfUulFfcnpZHKO2ZorR2VG7f0hRc0Ifosu+1lSDfG033++4X5Ld4G6G4IJPVflNuQP3Azob+yGvPNxzZb+se14XItwbYf2N" ..
	"cBGkQGpjpx4//5N/kY/AztGClTOqJRgASBu1RJr9hbf6xlvW04nvYJy/CQYzaGzIzRPcDSx2FE4gdnvBFgvc+JAlKo4Zx7JQHOES" ..
	"qJAXuCC+lmdiF694ZphmY4/q5iSBdyQyC3p52O3YjLdiGZ4LjhSsGxw/mZ4/xmEoqfpHrqgfI2ePY6eKWi0Kx9b3E/p8lkg/xSzL" ..
	"D39BMaS9jPolME1iK+UZFX6eZI7MpCEnQKH/KGutOzmj7pkvGFAI3Mj641MC4Ag7OGCfg6E91tkh858fsQtL7gOL8VdxezIoXgn7" ..
	"oawMrDvjYWU5LPEXX44Bd5SQxtt6A7VcSVogHWIjABVKM0JWS1+Y6V7y+pdxwdtRHetEpkuTXuD9fnYIyU8JNayU+f+eQllwXR9E" ..
	"7yhVTFB4RLDkz32AuoEEs75xmOaC9hrkW0u35OtR1DjPluRyNvhkAVXeXnCL//l7njHIp6uk7j1Xll9pFqzSHBT8hU/btvWXpplC" ..
	"l5gTih9PQkSfZf3y2fS3qJB5y7kb+66eIvrdGdVljGMAHrZgXKlvgpg1cviKeWhucmPBm6ImT9dvbz7sCdjK5v4jRS/y1l8SVPOS" ..
	"GoyV92NL3oP7Tbaz16+Qnvqr97e5w7OFRAlmgnO7neUWXgwDugCqEtUvx2fzUs/nh5YKEk3VrUAZiHqXzrJQ7reWoDjLyQZkaWzl" ..
	"ZKGn59UDQOhPm0Za/XO/o323nvcj0sieI0k7OGo55ZqEzTBCOhkImwnc/yuCMMjRdXIe5G6H2JBx5pV6wZCmskTWUIVYICgjpO3t" ..
	"JZs03lJ3cmXCqyBGC65nU9vrHJbaPzPV0p8Na7Emics8O2AbuqRgoP+J3Xp+0AS6H8UYw94/Wckaa1PmM3GOpuj8oQuwF2m3S+vv" ..
	"+71JD3nXPqSHNHhHaJ5tXo9pKcl9KiAGG6rGnV6q4wt7Peg7sxS/FrsHV2swqHNC2QCdWcayEuzLVOYl3lGHoiFPSJtvHH1EXnXM" ..
	"hohEsVAmcpunIpaNfoZ6XoAQqwqeJ0aG+amlJn2C4KVAMnkf/0BrNzX/5NOBlsyvjD2eTJ8OeZVRuYpvXX6xEUJQFdJI3yfyix/r" ..
	"TiOKGn1B4LVO+QcXB2Y16HeoVODHTCd1wSflLHUNHGg5nlgBVS53ljbr5uqVqEoUrh9vB5Ovw6Y4ctTB0s/BYMdC8vpcZg/zuSrI" ..
	"dBNE3sOmhbbPb2aiWL33P8FLjrmop0kR9DvSYja4D5lGXmKEW6HmYUMZ1e7yrcd6EKHEnTYFM3k8TUcpARWs2vSYjF5MYhbvfS5w" ..
	"/kjFmD0MSgh7UR7sKL1HMqdEMNvJcrmnAOMhCLXywSh1iRtUnWyCjrEfCuDi9Ge/SY9ZB1r1VphI1lpgamjH1OmJWW6A8zkkH8Cm" ..
	"aHTUVkA9di5jXpnLjPpvgeOvYtuvtUeTwd3ep4WWq22WNUhqorG3WakLpu/ST56Tw9Z+wlytKf51BqmFfBP1bs6x7Ve3fppIPtfd" ..
	"5aw/ieDc6d/UMA==" ..
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
