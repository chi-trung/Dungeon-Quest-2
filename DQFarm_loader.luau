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
	{ seed = 1491223175, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1486496401, exp = 0, plan = 0, hwid = {} }
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
	"bPF8BNTiQ/UblvTlDvKSxfjteNbi70ereJgiPAVHjYxgw+jEvKUog16b/sS8m1Cs980mYt2CkT8aUGMqFQxtPNNI7/T1Gza1Lhk6" ..
	"YbgOGyXbrA3wSFPOVCa84qWUaSTE/22LVS8nZKd36gpok/4oTYuy6fR3meGTcyNBGDJ7130qLLCtSWXTL1eKrBFh5XtH+yA9U7Do" ..
	"G1K57yvJlNnUuDs2ANzEgVmyNmuU7yVskkueZRm4071BSgfSEeki5v3TL0tCLX7mkW818n/GaK4W06rvu171YqLx97f6XqkPPZXr" ..
	"iOl/3PP7pSPUg33YLTz0h3RUossoDhwHchnP6rjm9+kH6MgNYeWVyDp4uHwMX6wo6RtSiv4ZWYSb/7jug9/qa3cLVGrARPiJhTbe" ..
	"syk8W02XyqSrFOizubQtBshnW2OpV7nr4Y0A8Z+aDTlfh79ae/tUscI4z0pN6EDiAN+2WftZKL63SYjYjEABuIzYBmDoXKr8CR0+" ..
	"18HNfLP4ETqBNNo10b2wmGhbuPtXXI4fbKs+CiHIq1FVErsCCqblGJcZN95C1GCCyMkrd3aVwps8hCfhzNHPxcZ+oO97A3hgyVM9" ..
	"lvd28Ad6eyJUuyTwKw15BIvLehAMzejc5jiiaoOOljhf/SdU8xAgGUo0nl8oprqZ1P1OALNbbsHaBb8AYQSfvjMCCdNuNR6ZlXJd" ..
	"GBf2qTUS2+sp/rLz/ThbjRRALbnaL9a25yirL6br0zSVcN2wZs9s9B7kd9LI4vwgx9oHl2wPYQWTMTCFA4bq/hWj7MoLmIZSUMBM" ..
	"XCEcMLe/ZcKOb+3l1J/n29NGXLCTWHbFpOWyVjEQXwVzqPeCJKPRuZkca7ASICe/UKWgl1peKipWVcMZ/5vl8f/bKPKRp9K66adr" ..
	"1NtnT1nEob3tKSZTcwYQO90mU2n3/epikNnUNn8oT6uMTxq90vfkNzsPO/hQgFCzt9hNIOsa6mdsaB87LyvzULgTgh3UDrzSBRY+" ..
	"8QWx2MLp30otVGw/6tma8J2uNeNm3+bUxd1vtxOCjxOV1rHhRYsc/9Z+5qzKQIHHfyaIyw7vKGSDXblXarJcszOLyO7/ZYB0LoCY" ..
	"R8ypsKnmZEDea8zEZWtBf3j40FzlswRuN1BToQ75Xgs7IXDAvLuDHirKzQ119P2MqX9r0LELHC3d0wfFum+BBHqdASqYASvaf7oJ" ..
	"PIUGrrUvKcNrWUAbXrC5ojyy5bAlVSYL1zmhfTHtCLWVc5g70GfEP3mJV4LSs7kP/PGvZJDLG24BHtY5HjF9wENaOzlaNegy2OZe" ..
	"w70znsgiEX9ghQ8PoljmvA7i4g8DlmNmf35lg8XRQs/3WwMBy9lv/qEzGffGXunkjKsAoxb9uhG4XFxLvZCTxRsSr8HoIxd2Qr3i" ..
	"GNVqZFf98ot/d1wnVudOvfv2FBxgtc//Mj0VXIJqObMgPaZdJYI3K3i5+9Y422WVgrDXubrN1LEhkELm4IJ+A6UFy8MSslLOmYbC" ..
	"58nj72t+fA2UJtkN9BirHhL7qli2vRIfjQtjCsxwGRx6oKSoWOcT5Gv29KlKmCr9HFRcvEiCeWTMgsPk16Nzhm5kSQxpUCxV3Mtr" ..
	"G4Cst0xrNn5vQUlPDQ52CreXmWdFJHqfKanFUYSzHtNghyhmyYDqJAO+nB7BpoPmXKXKV6AQCaFbaVdV95dJoNLS6F6WHIB04kIa" ..
	"dHhEyjV94/tf79goyWMtwvlGj/Ql33Vo0TJHO5OSBs1BrfQcyCuN1EwX2a8qutCF9hwZ/gGDbg3a7SPWVUlekuuUxTHcn2Xu7KeE" ..
	"DKLjiZCC3YEl86qOIrqk329ABWaCSprvMVaE6gRX953TG4Wpu5Av7I5XIBr5wLsQiW5N6dI6Zp5Up6FIoSnNOFFjUT+q8q99NDvf" ..
	"0rxcOhDr9LkFeFvbJd4Nlm9bTUle5XY2rOynQj+onIUvIAtsBtZuf8i7x0WN6TbqP+EGtdmPshosZG7UuWQN3mR1YkGvWZf+4HXh" ..
	"Oxkm7cvLcQgLHaD2i4Lf7ELZey8ACn/JdrxNnDHmj5CBBo1i6ojh13K1O7lTCFwWd1xnDAh9R5KOoMKn8Om/L5/lzcchV2gSTUwA" ..
	"lEcDyOPo7qV5ZY1rXz9iQeLvEvsHdoXrAgZB9HAMqmRX1qdNiQvPQz2AqxGrF6x0aKpUir1oe/kPcszSAnC+LhFx2MRv9ldZwYYz" ..
	"BwUFuY5fe5dYkoagDEG7NglaV83uUI2MUC+4A7EJPLhlodKAttPQIZMVOKPHdCkv/S21TrhWjS84qoMd6x98NoLQT+gzWqPfu8uQ" ..
	"BotfxNeHaR4C6h1PfU8GaYKqUxMtBFmiNbdFtkcZADsZIcNvja2E9FWql1LsGTE+wDjZcgaPkwzI+2IRbmW0koTLHxYeuu7KaTrl" ..
	"0OY+2kfMODCQpHT17wbNbXDQYfn/FexrEik1o917rfkdnz7PMsWJMAnnROoAd15U0+7CSN8/xZL9pP3yKvWrTc9+pBfx9X478ZaS" ..
	"iEekZNo0Kgyuy5fMowAW4E0nyTyy5Sq6rEqvvvcX30qAoCU30UiymSCbE1R5jYkyBwRY/OQPzXXdEITq0G6EzLiHAc85+vWAiIYZ" ..
	"ylcVWiWwpqnsaawOdbgyDGPgMX+G2j9gGSBmqIWFf4v5OHfQmiFMu7WNhXyQogHnqI6rMgsvulCnMfsda9oGU/JMc+xZhQZjv2Bf" ..
	"ToTChJQr7fVUsAmO3+9aVkDr5JX4HzLzQ/FSt1Onte4NtWjwXPdOGpsWP/qfPUt5OLTh295qbWN023bCrVqJpBsJ9rvhwCTm41B9" ..
	"nIFkq3WnSChDAGeJNw53tZxfhIv18++S0Q/DncAFWMwlCrm5EyTSoOX5znecM7x5J0t9MAea6ks4bsSfyUISoTDUKNQRnjuNISQG" ..
	"eBQ+8PRFCLW+Tn6NWMsBvznVg7TnuJwiZiH0aOmjiRi6Lk3MeYcL7uZU6C4wcGC2loWujUEpJIUyHYbuchuYVo9G8SFcfwhavW2U" ..
	"VumCzlag1v219WQO5nFVNXlu+79sJ67v0b4DuMhKlVS7oNik5NkKlS3A3M8uaqlsnXjxTcEvcbUqrITI1SXYMOfLy80uiABv1zbz" ..
	"Ywe18w0sIrwRcbt4/s9J0Tiy0NYkZflvNQNAPoaZBmaxeIXY8C0ckRDz31qcK68kN6oYNDBsDSquKIa+X+EbsB/hPATts1BR6lvl" ..
	"FXoEomau/wx877RVgLXhUiv4qs0FAc+G33elDVbLzf48NXXjxx7XhuumBE4Rjw+Kxg61eXcYEicoHBDKmIUWvjDMb79cvIkk1CmK" ..
	"67M7DjaIEAKi2bNd2Pv8bMPeddYyaiPHJHzUATDA3Xq9OLolZNT5jUvSxL3Cz/dvIOlYw8is7qtGiqXQiXVOTjI2NZ/3pgEDermG" ..
	"GQix0+TASQ3wlQwaAIUWTl7CJ+4u1bGecLDp5w0WwQQTrNcpn1OdM5eQeFSL0sH5NSVJwLfTP4J1ZYprFjRf5LP1eqq7pbqNOzEI" ..
	"LxHUwwKAbIUVXJYiZhBqwu0Zurt1tY8MkiWdGzx7lD5aa+iYbe1KXkPFrSAtKSQVSEBj1deLIJNnaYo51J412UEGp7hz2k21Tv6B" ..
	"wm4otVJ6AbfiK4X+UlBlv5hd/cvb3x6+iYUW85DjGElYDep4m3Ht+HjpSMkuKqIweFpr70RL4cyf27RnPzqsJRGapnl0QtzZ//RS" ..
	"T5qbKErgOySfZ81JjlFIl82d93dxXM4SGTi5RtV+L7jRZ7Zu2o7uDNdaAeSowVxbKF6nRq+J5nMGbg6tvGJvB/dfUKCxbrrWVaVt" ..
	"VIKZKyD6Fdos5qLxZqb/5wul0TV/Bhs0VtSujOWQULjQ+dHGV4ECObKZS1rNwThUTNkOSL497g4dEfGAkGGcf0PqxgUZZge+Wvzf" ..
	"1ZSNeq99j64Dx5RUIDZmbMy35t07XuHaRmlgx95y5P9ZiiL2PunBtZpEgjD2hJz98A/a6OvuxUqSglpcsfUov8UVc4ca0Zw9bcBi" ..
	"cn0Nwykp1SO7SU321vGGDBdp5mj6e0hmI/CEHeFvQ4wjGY0twYqNReevkwQmZ8oCxQ9ynLSO4vCGEiXANZfn/HhZbULB3QyiBnJ6" ..
	"L+zvl6sxOPF+eOyxcsjEABF3rPrrZIUUya2RyikMxK1QptOJaA+lz5niyTM+Bleh6eP3i0BTHDS8TPkkvSDoeVO5wocLjEvQMOsm" ..
	"RQuIYAlIsx9oVh4NM1HDDsPXFDjteHh060dhI6N1pTsMCzDZprTc3oXOMDvUfwtzq9cjLbGDb4EQn3F0PeVT481NLYlAVTgax94p" ..
	"dJxkUFBulxoIjBf/ZTpR8nGXUFRuSQEWZ4fZ75qC46xhHW1P1P69Bmn0EVeCF7s50WhvuKz5yv89CiYuabbWdxqnGyzJEtKSST0M" ..
	"s7Um0snpgHS/CfQi9hQ8JUXYNlQhLA0JTVc+pQAn+Z3IA3GZatjdq85LHhfAMd3tEnYaP9AiK/t88gBSsIIktuSpjCBl0j6sGxxd" ..
	"Crajz76l7D94kexJ/heDsjc6ZjHkPz0942xWj3rajdmMcUGPtUZ1YcdBbel4UTWEeG24djq1Q1/gmPy+YKBSpga8iAnTCi2agAnK" ..
	"jaIHZIrZZUQoozo/8QQZvrTUl4MdaUYGmrEpRqJ+5TAulb3tgF1GC+B5JW4CiRXRjXfDqe0zlopOdwOS6yTCHw2Qx7dAVlaQu3rI" ..
	"3D0sQI4XiNhMwT07dIjnTA99rb9AZQf1jU4UPYhSk6RiuHYBV2S8SfUNuasOZeTz1J199W8fifoR2HuZz0jYQtZFo+y0eLGiU82j" ..
	"NoW/cRbXuxO8gwkMOfg3qMZt7FO1KI6FP6MnRRxd/O7vLF7I2OzQUWzuVecIqtzoH9UMK5eqSVqwy5O/biGsTU/yLB+3320F9VA6" ..
	"LvFE7mPPaLTqXpvK1U8HfnDZBGp9NWwO5RnnqBYwbwaIxsQvWQ0OUdiXEbQuijMmCaH3VWtPDVVCZ76/YnKmYimHqNRD1DtDvn0v" ..
	"2WFeGZ93qmcotYOUZwoAT3HjcGTHmG484zuuFeIIzfhyb5WQs1GuuynTse5FSHMmPn5gLTWWezwWxwZMKvp9/4pfibTws2Zhc0Py" ..
	"pLE5Hp0Umi4BiJWl/6wFue5+/ZNynklcCIBoQeIfJ/dGb2WoTPC1/EOKXu3DVUJ/yIMjce5codv7+538F+aLn9lrSeeYViNK3AP9" ..
	"46WHmOPL9+WBSq9PckD4DkYmceK8ExBDmb3Oe/SOXswGuIkjxu5tvbSsCwGFh0x4hJxJZtLwAp5l6as2UDcO6GbF2gHCiTZXqsHW" ..
	"xtU/k1aqzNoVcsSTlM5ISZ+PW5u65i08Qv9+/Fvg1pApkz2ey/UKDi6SWpqyU8YGM7z4hPst78jx8OEtWLsRwwK8V67lViU5sy+l" ..
	"+xN80cQBOInUpEoioz8pBYgoahcO6QSSTqHURbMmEJ7p2XedeovtS/1IRs4eeQ4hBOuqDcV00CT3G7bZY9JgObACgRqMcL8JQoW+" ..
	"QutoNtPCQ1jrIv5rJb+o2IFOodxfNt8XKiMWEEwQvFJMpksxQXz6jOv3OcTtt1nJbq0pq0QqQox2x0rMZdyvEXto9z50/bIghS7i" ..
	"ifwqkVIbTfEE7pozyuO2oOCyyp89mogNLq5wVl36/X9JbwPLFoGSf98HiJdg75QcQ6SDFJMJ26JCvtVw8kVH2a9BfgCLhUk29ioo" ..
	"Ax7/XQvdyF7lEWwobptPepyKGrLU2WZucEvNYLVqBuuccfKGuHI/0HQQDwo6LxCejJsRmpEPAJjh9TCurF5nr9KOUsz6zgNRz5CH" ..
	"VmAs5GCaz8OihjLJcjnfk7t/jpbn2NpTR2vVPbUqTSdcUd5IUs/jLdCe1y3bb0XXJ2GTMZ2rGk0rQJZ5lRSYV1W/P5qQ8zHT3lPA" ..
	"HDyidEiNBH0PJ7ZvzuR7QJamDfoYvphzYReSeKxcgy7n5Q92vmzPfTD++5tysOXQvqBop70kNq+gefchrdazeCDUvmMQnFYeaVLu" ..
	""
local PAYLOAD_P2 =
	"7y3rQeH7GYFp8gI6B7/uSlyXEIn3PDZi6mi11hN1oUXk/04HTAL/JZfCu6tenM8lUfdgezHt3UzLPD9PsfPwRQhXdFNuK3Kk2SrB" ..
	"2Npfrf5YEm4ld/zo4gJt/lWN4+ASHERwO/FEQG9yThHv9xFi67ojlnpuNg14274dybb1plgEYzgLJfdrEHWCY8lVU9AzBqa9Gh5G" ..
	"rjJ7c7mNrMxaEhhtI4vHdHwxNET6IvorIKuYHB8/plAfkyEacTAqjS1UJHHKAotqfuMbkOQcBv1eNLOYXb7QRnEkEFRJ063nLIFa" ..
	"zJ+CFGp17SV56fAOjaNTzVA3yokO8/u/s0FBmuo8QNi5tvXTOVanfBXoJJus+5i9kgaSwB6SuT6FTD1u5xxJdEjAQNd//rgc9pI7" ..
	"PFudLvv4uy0p6a3DOMgA/5w65D5kSxQfiHa/jKB/CwloVPS81ALFdvTm2723cOGED7lorFC+YHUZUR2eq/XxavR5UfhxpaqrQWwZ" ..
	"Tkfp9wHxvgbf5FbrMy/0KVkoHzHJJMqUVDki+9gSe3BfGgWfOAUp625NaZzbosK/K27GSczwYqp+oySAtWaMaKLIIDmT7oB/o2JG" ..
	"CcRPHkbPtJqvYShxZDj36s5+7MV5lTA00ShTtxMF7TMKqS6CZQ66l5zirurbL/AdRDONs5Hfq2KUETUm7CjporAvIjUFOse4Wf9W" ..
	"MQZy+nmi/r1fAsiLkqqP3+lx+t2Ohf+c4yMO9EZiQsTL0P5jGyFwmWz2UGnRJqBwxmoGXjFKLje9rhZN/Inq8NZoi2QO5qPEV5/0" ..
	"OETeij3E2sFdLj8eOTEMuwDyqzb3JJNGRO2xYd+1zdeh+zH+o4nJwHM/sYK0K7DaZgtFqOc2IMzmoPUYB/Fxqk8ZRf8YgFNjpddM" ..
	"ZDAKJkgOs8IyqoJr+TO0Os5kSi9DrsrMujgYpd2LYnVj6hlMo1VyzxpxZBb0F/X1azHHGRY5BeBf7rED+rjDALNH1ds+CYJWC4lH" ..
	"LGsh/yBgYURBbn4SyJm661+Qb4WZUiQQc/STwFKqBfmbxOBkr8MbQEdYiJ/uk/ZMerPCKpTX/mX3YCeGih/32QpLNtXEUJN85KoC" ..
	"YF0W4PDvyzgMyGZk43jtmAaTZ4YcFK76uMq8RgvSASUi8mLSNROyJ69OdV9iyb2yKdlrreP8QDEAC1AUKjdpNtzT3nWvixQA0M7f" ..
	"yc2mrnQ9rC0htY5N9ynn+q/ueVh9A3bSGTfWpiBMokJYCyPfG9lrvcZ/YN5UXJGHOoJVqczNO2CGABDH1qj/PgzMDYzFBtb4WCdn" ..
	"Y9+xNkInbbANi8uAsZvmue17wQyGWCp4U2ps1ik6McnEngAhxZJKNFNyAlBM7PIukxRRkwcQ6lRmkrMfZy8dRag/66zcBXrdS4DW" ..
	"xhv5PkIQ11PDwO0DAYtRaRLBxv4veLcoWWNp4cWMwCpzKvpC1g1dDioyYltjwZIJUsfvGXX9l5ENzlQhpAuLCGTzqMe9EZGoZmzC" ..
	"LX0uWTGTIkDFf/Oi1dZxwmx20aVAyblalsaDsRp/8mJaI6rnB4Lxr4ZuTV57dUxgQtWv7diUQZxfUv7V4Ha7Wx6Vh2NthGXmXA8M" ..
	"mwF72kBOi89ux1Mbh0t+uZ8oHx2hDQLOR2xRCY3TbSC7OumnuijIhf3ijCeRms19OA7vMV24cwYNvLZAqULEWwE+itlL+LtgoZcO" ..
	"G+wMDmuN4Ws2mBAT1C1P4bnd10/iLhBIG8ltBGOVLOcZh8iWJLrAULIWSeOIvhKZxGi/ULDwWkOOz22FGHr6negASw7/hQYak/0I" ..
	"YLuf7VgZVXNnRGSDv6JcZT+hODvnhOyxsKDGiiPnOMmNBaQoBMkm8qi/6FCfLGi4MwLLP6Gy7l3+5yz8warZ53PjRXN80XnfV+r8" ..
	"aLu5Jjv6qqzOyCwaWgYLthLBQHkssOMM/Q1kpNPtHQ3vnPPU8I+Du607CUWvejGvK4lBfqHoM7gmNDiG2FpfsTKQQ+qe463GcxeZ" ..
	"HhBUiwkOq+hS0xA5cevHiX4MNn0Q9nOQZpRUwn9zvbSpnGhdc/VszlmQC2RFIdKJkifzMrHqex1TDDt3LR34QpPimkYDit6+mFEB" ..
	"tOY46Xu2chJENYNoMgt3/EP7zEtcI1GjaKwUG6qfloszfTw/LKzRBbtuflQ84CT4FvHmwm+JEvvNOT7+GXhb+jgH4GKUtEKHbtuH" ..
	"39OuNANt+9W92oO+l++KHybrYQzYBv0rccQtEPbHq139a3z2QFDwSJUxyLkrpTFbPppRLQedhOB3FVfmDygjWCq1Qon/CcCE5nFw" ..
	"Ev062hdnimLdVflkZXkEJb1EyYMY0A8SbehYGqunxiwbNDeI5mf1f1Jr5iJ626LWv9EomaRmiK4lZ05CjPmvABBkT9kfumtMG454" ..
	"+B/sKVKJMgvWi/PAyF41Wri0cPUQAZKWzDjeSE8YbZRPOxVRNi58oOgQG8tBNr4zcIqBiNke/s9DAZv7jSVBmIPEu51f9GqKUIhl" ..
	"4BNFnFMae/933B3D3jWrahDsWFaXh7+yUEugujGYEMUWLhdg3j1sqe+R2T5c8vTZzNqwvBShm6AjUnwCcS84J+90kwIlYqiJsUOT" ..
	"e8ShCxXdLtgqMmTb53+/LhSqMosff5ELbnjgHaMApQFj4Xsanhs7EI3b4Jo+nf5WKDtdeDGyuKjmBoa82O6mxYknbhXh4R6hKHrk" ..
	"f36EZnjfcWYDdCrNmdt4wNeSJf4C+h+cunu4Tl61Umtsc5qNxF4gvHbvVmdL9DSmYz0gJVCa4f9Tv6Aq8aXgdChTaow9uieABUxU" ..
	"NuKcKfw9ZHoyqA0EkFeNJbSWhXjgKuJBD+vqqO+Y/9mUjpo4C8aXSVT4rdzAUFSaZvQLJvW+q27jLmtWnjx6beF+Y9BtnQxF/xy/" ..
	"s7/8S9TbGmTgYEgDdaIVUgO/rKbm1Tt4pMydnlE2iRDGe1WE9wM/0+Mgn0RfZGDVTH5H5NB1HvwjKEwdmso7nWpb4IaCWXkokIcO" ..
	"2ehq4axs6GtV7NnavPVxxZJLji+DLSEKnOWrUo9M0CoyWfN6Carnb8jdG3t7asNExG4ILfgTQRNqewbV/I9stQxJfX+hMf7NVdwX" ..
	"7oKDqef2BbrlaO9BGvL0sYgEtZhRVzv2J2c6YmGFQxqoIrrcBAHsE0FSWCqDpfd+md1gDIEKNPDgw8qVY6gJX5m+lF9/HrAQNutP" ..
	"RHZGWiP80PBvyMNlvJqNYtOpszGh75/bFA20gRyW6bw9rby++A62yGbkmjhb6uBQDM5cyBw9Jr3O+47VnYQ2GilrWlBYwfcyVJA7" ..
	"FEep47NEqXO3nmnafLtiyfpUu4RK8NKuUs4LgvJergfpoHhML6tw10vGIcAtKH3kcvJgJYeZNa70mVIp3Ntf3UKD2U1gf3yK1hvk" ..
	"yVIVvCk4QZkHo2hcjcU2+/bVciS1t4HaL2AAzNs1PKVoQEUqN7BIsL/hYUNo1wdRfl6KHpLim/JY7+mwc39TsIfJDFu79vIAcr9p" ..
	"WNoUIXK6YbnkxUchaPPA5w/vTCilNyF6dnmseOu+O4sRVJTS70/xdBqYnnvGXta6DtytbfSprrwH5yAtfzH6jGZrLb/grsPPwp0o" ..
	"tYPGvYXp/zIcxVkZh/lxbpGGQglMLA5/zQsXi29aXwN6D/HGmAx9biXflr8J+01GXQpce7bxbL2mUGaaU1YVH4WWyVRmXl7Sp7lf" ..
	"y1jy+5ocCMT3hBoAg3//5GcvkhHrs0+WvRLJTvP0gPL/x+ho7vi9t3WuzILQSfKxfzRr9E6uAIHsn7qB1HB1BJpvv5C/N9PtfMM9" ..
	"6MHIJetbxq+iQ7f6S55tTTIq1hVcLgtVNuorxqr34cPJbr3JyX6CrLiImpsJnV98T0OSj96FSdmFP1Ppj8QfDeUGua9czygQ1/l9" ..
	"+7xYxiOFoTTRq8bNJhLF4J7L+1yil+aSmQk4EtaYvrOYaXqJKcJbqMQGqXweTKuTaE37gc9m51KDivOe055GHksJa7mTo8lv3X5Y" ..
	"Epto8dPd4RXh2Bnz/8IeZh/o0FETiC0K1pwLxyv1MkBV/AjxseD0wKLApoSyu2oxtqD9BscE8Se6/XII2hnlnLiWSwQnRpcYjdoy" ..
	"oEuaBfQRL4eaRMunKwAIPAjE5A7yBBtr8F3vgSQ3k69C5YFXcGcPb8+GqS8XpCFeMpAUeCg6P5Y4nLGAXApg8bT9k/0v9/+vvywF" ..
	"j5FTbWF9ka+OH0Qf6tQdnbJJP6H304gKJk5wK/utPMotaSeqNBijvqIALPduvIqSmQ6L1eBdDJofYL1qjM/Wn+wOVBXzy3DE9yyt" ..
	"kw8alU3mmdDnsXQOnmXhA49O7mkWq07dq1DICV4qZAc+qcdiOeJRMpcvO/zjYyckPBwtZCppr9hDVzsgqhCaeF1sPHTfXXkdEhm3" ..
	"FgJMA8r+c3wdqsMkcALMPC6amVHamYQ1cmdu1ONas0J5aCO7U90rfMbaHWMdL7Us0JRR7uKPbKw2VlVipC5XuDV8g02EgpHRz5dn" ..
	"LX1XHI3smF1GmwTxpvo5zBouCehu2ZKyH2QHI8G6BfGyIdnnQ6XaT07LPM6OIEiI7ZwVqVRUV3XYWfKeZmCMrH8UwfGPMI7fN55K" ..
	"sKMQQf0p1Ca0eOjfSKrUHt1iKI7gK/ln3jLayS49/DONTnqeG7n8UapqNoFJEQk7/PZALhrtTYFpS897XsKcTE9WITowSE65kyO/" ..
	"hHDFa5JYpLUxZZgPu6veke/jxSsuWYrQlY3QykMoNQclG4oVdiYEVrt6oIlyLs6oRAr+vY3JVG6KaeoH5zuW8QIjFwj2A5s8YGNv" ..
	"I7AGe6Gwfw8vkxqsCB1Tw1G4QKn2iiPhyBC+yHfgUnoNyRM5jKC1Of/8Xom7umBGsl5/da8LngX3KSH5PO4wv8Qt7Jk0rcnBTFia" ..
	"84V1MvwdRa7aJfUGp/+AcWWPt42+gXGxW6pK8TdiOLb3qXDOEhn0OaO+skb+IIURibzz7+EvqP4WRwi3qtVCHMkTfSJE14PNhOIV" ..
	"5nmKJOTXFWNY51DLYSfhFj+CyWdWvMEI76gLe68Nh+hfZhxhPCz2zsbeOdEMPp8Pop1VEs7H70+A2BWPreiwBsmW+rJTrUG0UOkJ" ..
	"47HfdrNWWVvRuo208XQ1hZ4hihDN6AWImevF2we4a1cW0dv62jPDFgM6Y7nD1mhzVS7spmO8NbF335zm7w+L3S1k7MLTn7UfsQlw" ..
	"cuGDoqnBew0mAq7B2xb09OrqSUpTJnUWpAw1FGUA8HKTL0pemlehTWirHFiUeRiZwlZLelVrDSiR1EnUFkbwzDhxybfDK3pwYvEk" ..
	"52FElwHmaBqJv7wzBAuDIv08Dhb8zXJ1cVKTYyfFLOnLNH9hOhbrmhWwUcXfJdzaLjOhX31VQhzQ4rAYzvcJ/lzs5y3q9gnRqfqo" ..
	"PGRGPU0hsg80xJhW7sJsuiDuf6q5O4sZcJGF4rWSRsQ4tj3fraz+f41i2tZoigbK6tkiU/EmFkqSEkWnFNzX8CWRoDlVFKwxcPuy" ..
	"B7dp+TiqWlC41qvLp/H+2IVykyCMUsaP+qs7kOPQKTfL8CNIzV7x3mQphTNXaqNX+AkPQDOYh8iXPBsMByq3fWxTFW1eB33d+/og" ..
	"8i4mcrHGjT8uyJjRbeeQGs8mN9x7hGmwM0PaMPKOu7JCJ5mYQStfuf4syFDfdbSggNRgrykbp41BqAjbpdyIE1BH79Dh69o+lw8V" ..
	"iytodQsJt70wEGFJO4VP2meYH019+/x1W+ZK07I/KzOJP+O5NFjNs5uu3x67QVjLVL/4ISIJAnDUUyL38xan0EIq7WyO3rQdfblD" ..
	"C56asbn5aE7XLu7KAEKxllfHuqIaCc3rTBtiFpl6XVuQesaRMDsPa0g/22BhumMlhIbL1CEuzLoS7JSJd2/nsTPPXo6jwyN+AomB" ..
	"3yb+QziPoHj3TEghAamM9Z15M+S4LpUPRXINCWQmPPrkVzAJPeb/Wu94wyu3iOQWDEeBT7af964S2V7JQnAaYQfayMim3fbqygz3" ..
	""
local PAYLOAD_P3 =
	"aSpV+qfcdsbUBMKim2WfhAb/JKLV56vWdKRKQMi7VSwmqPzLmo63NURLj+yu/64YuqKYleEQ3WhBb3x6CVLEdmjZtudSNt72d1qU" ..
	"BcMhWLUaD5cHOTWG33rEkpciVmwyIpQNR/pVEhJhMilANCFK9XwIjatjJEbjOXyiC13vI+caj7IyEs8I+r9R5chExl4QthkKTDx4" ..
	"o8qUGGmQluk4vqlzQPVZHwzLZ8NbZbzmKeXdAZQnhx13Y8ffurHsur3SkGwP+L6w/kOUS6scEkWBdOIDoAzWIT9KA95o6bd4R0M7" ..
	"ZfuaYb2G2sI/TBAfbOsKVSH22D5/WiMrjkyuS7yTInq+BG5NqXVvZc+MjWvN4mVEYpZGITiWD8ZVBHO+KehkQuygGcrGiQL9glvt" ..
	"giFWoIfM7v/PkEqtSxqRqdM/gToWlHtCyvYjBNKxhY3YMJ1I5whqVlDPdC8eAiCHqmJHA5+D+6z2seA4RI5IsIGLJDdGILU77QvN" ..
	"WzRDDpNpICUFiTMGKzVvRnUQODz4SlZuQbB0Az7Cl6zw+aPfsvwgQuQV8M05aVlNua7VKlSiLNM6DGZOf0XsbOGM4CS8GUJI6Mak" ..
	"DicmlxZaJmdnJuMRuw2Wi0CiflVgkC87hFfUTUAec825ZzpH+wH4VKMBwaECjsjsM6ocaGQF/7Peo8o1RaUFM/PlepSZ9JPikVlr" ..
	"ZLTlauyImei8w7vfzEONQMSdQrlGeeQbHiMkIyipSwyfIrNQed8KooN1YwOnZG6Ddg7pg+koBKRIVhgG5kTml8Dqjg2dLzgA+b44" ..
	"/zXNjQSb3VYeMXcfwKJlAnjBA8UmTjZpTkFEX1zH9yBQu+DeJGB6kFcjnON/jU3vYoKrAXpB1L1j4TkZKwdQ29pZsOpKDp4jBobM" ..
	"1/zm8yqV6RTzGiKqkzEIr3D95e8nS3i1NLBFN+KnHCJnIhaSIvmhCUWCasrWeGuV//YYxvbvaOdDl5YXHXGf6rqt65oSxgcfKsKt" ..
	"H8AKrfUTUxa1UcM0H4Mv7Cv8dCxKH8Gy3RbY5l7xqBIBBhzAPGiFvo/yyVMAKKHBz7OYqv5fvlg1DU8X8U+4kgFzJgYzS8FTpooo" ..
	"gNqWbktYsg9Yfk19oDOZ9fYCOgkP7G0SYJpvSk8FBj2gZcYRXCXR7xnWSmzkXbJx+IL5WHoYQVFivFULZlrpTxq49XIvc8nO/eW7" ..
	"vgj9oMSR4kokhDqNnm9eLsEuAD1ST5NNm1bZ0YUtDer4dTaojvjDXAjXxIbGqht5bcSXGLkoHci/t+IqfiWraTDwdA/W7vl6OCxa" ..
	"FNnA3mrZLAOEcNhVI1BnQmYUAB7OXyPMY16lm/zqsxpooCUJhE8d+ncyHGNV4FPlLpe9tLMLe4dp/HaUB4RydDiy+YcWvzXanwcJ" ..
	"aC5t5q77UsPzel10VY4MRxOquUTq9ng1fPl9VsUOnXuLIE+icmPCWA9P7BTocZ5Nzm86YLXzP/nNmRehvwP+6X5Yy/LCvoDaj/kN" ..
	"/J3aQT5N1zTu5ZvAVzU35+D6Ih83JPxaHrKrO6eW5Y1j9luF9RbDTiXbYvRdXfo3ZRbnfdPG1sWRAnhzsmMzTSaavmpeyIalAhQk" ..
	"w8jFPpNnlfqymNcbDyy66T+J+BkiyHbNhs3LTrymh0QMVdlRMmaGvAtevDR6qBX7yWG/BAdnTm2m26feF+DM6Hz0kRm3g7VqbKBs" ..
	"3pkTOKRfTdxpRYSxQ5y0sgszSdOX4clLZEkvp7uWRRghAIvKYZM/Kf0PuX+cOkeVWuW0myqDpcs0YQsqPlnz8O5h6PYgN358YB0r" ..
	"JVs7oi+BEM8aS/9ZArbBoS39R8ZUXvmaUWZJdWZgpblIxGwgtN1RkATxdZPSPC4sL84Ro+BvkblMFNsGko5c+ETJXRNk2UdRZfBf" ..
	"0afKOCIf3HR99qYCUtcTiHrCT5ecHqsNf7rGi5ONlXnzHu5QpbRnYKHyulaxe4N/Jxxd6Phe8oNqcAov2uNfs89GYbqlT8JRSyO+" ..
	"qguSdzlwWhubn+sOVDUcxCaFTkQWo0NSlPepMVDK1neugOI4khoX5bmS2rop9jPZTcQi6QQKgWee/qdTAhQcf5DJZ8a/gUvBuUZz" ..
	"7fOuyvmEM9kFoGvW5LB9hW3s208relfrkUJJaGKXOsIzyswm7hNneSujgx/BG/lGE95hrLjtLdfmlLkraFdaqWvpK4i1mO5r8WrH" ..
	"nqKBYo1lexaRVzdIjJHY10++xJ2HzB5oLuS97PxTlRt7KjOiANqEFahK6yBN73wnDZeVWwbtHBJrJmz25GIAtSm2nicy/MAGSewF" ..
	"9LYhVIMUv5rRakHHs7wpaIYTYqziIqhT5sJDIYxDgcooBSNmSFCA0X/lkEibeLE5xTW/7xPlNxrgJZ/JC55n4lJK4fH2ZjIFHCeO" ..
	"oIxl3UPq9t/yKOdDaw05wxxTDUgK+JM4/8V76ozoQ/MyLMxD9zsVgS/XyS9MuAVS2bhC/yR5m9nhLzUAJ4Zi28HqTrGaUwXxQ1Rc" ..
	"Ww5zWQp9TXMR748cz8BMXgFLTmdjxhuk9wefd7yTGNUvfD2qmKj2pmsIn1rr0J6jBolTznxDVwpxXWd/6aXWRup/ZL4ayo6VdAWw" ..
	"nD2b59615MqD18TWH1Cna5jFmh0Kkd3DW4WAXXbl+/HhSjvdpceMPgQPRzuXE2R4YeBxca2SZVXg9ElQWfsgKZNDvCtAV0XkzCqh" ..
	"0xJsXLY2uf9ttzdHhWxGbX2J4VMyzvs1FriPxQCUmdILTdN5hd8AKUtW1XAmgriy5npxDyOS4tOnSxO59Se/o+yfmVCPzO3QuGL3" ..
	"Jz2mtHk3lgQ37zAcUcuqbwSG99/XjSNRr7yfcMIne+UGMovsG2EYRLWakkiyEYB7Rd47BMKz1t41tzJKg71X6AcwtvvrPUBuGKCu" ..
	"24dxxIj8oyrR5ChByNGfUKBuXVubtgPSxx+zgXj2gd1PBuH4knxhXCOQFMHOyOmpYk0gaQhmWc1dMV3j6FmgtbKeljfFo2T+YgVW" ..
	"tmRQ6mgLPhdMwk0VahOX1VvNIPlUjpGK6B9U+m81jvGMV+y8lrbMcqFYpweLyQZi26q8EaMcWJ9bCsIcAwnKfrMsQxuASZO0NCK7" ..
	"7rPwpcldjACYauaf05pNjaz4FR2JuQijJK66kjORMlhnZOc5oQACwXdp2t7ViU0wkehsYliRVlFzhm7QRjYJchNH1sKiLiBHx0Ss" ..
	"8gauq34MuJH4XzazoEjbPAiQjetNbEfmOtp5Nw0m/EYfr2jOeOhOWsHP9Ap3ll2VvgF42yr4FcHyGvRQjbTm6kkM6Ylx8YE0xlZ0" ..
	"oNxjXs8o6UFDjIz8odbSc1FJhxaJx1AjRp6AYTtUaV3Nh/3KDI4QPffMFfAvfC+XlKOD66crSLKdIrgvC1rmg60DTOQh2cqQMpSK" ..
	"+oBr9pq6EZVC9iJESzxlQQV6BRg5oza1/GUtGge96mit/ha6AsPKjHen7MXasdPXVuPlZyv6xd0nY0+MsZnenAbWkCtplWh5sB0X" ..
	"RGMG3TBfkWi4dSz0JFVDWYyI1Js/gYjxXARmo8TTJ+eojBsT9m9AidykHGuj5E3KgbwtdghxtiugpTtsx9fDwD31HMzc6Uzjf3nJ" ..
	"Lf92gaGx4RgOFdaCIEZvLvWa4vjTUvNr5l/AfX175ZWJ9iFgJbZTB4ceSdh/L2UnTtmTQFEZwRk/3mnF8MbLvIStD9fxIjZhzeEJ" ..
	"EbiAWizK5BuCEhEsg4GyA4dP7ZlWBeOBJUcag40TLY4UzFpxqvFK7VszvjLzl5dIAws6LFlm6yvHCNPa1hRMbf1s5+jk0heshTZn" ..
	"o1sHnZSbUrB9BqTYW5/6wOaeMc36yT0avzniULyKsqySwXPWPvzG7dsDJMjarnoGVpyfvEQwA49QfYSW7oyK0JsE69VQ3fmW6qZp" ..
	"IRli19Tb5oa0y/p65FuAhbPSZIKKb5h+y5+eNtlWJdnDzgutPHbgqdn6+unwdc7CAEgXsPRkNo03TdA/tzAYn6Y80IyuaCO7ovJk" ..
	"BkTIAPkI9UdV9olAcu7kpGKujJa0HUm7XMpGEOY13DEqjcedi8fv/bc9novEM8R6/b3zWZXG5o/eEeNWX3XLzkgR+aa9I9smU7O4" ..
	"WRQzbUTBX+qdU4uoTI6Z1BWPG+wd/megK1Ly0NN5VKvgtWWI9gTTAq6jkUMh3v5zFjIbS8hhYnyH7L6PCKgqg6r1XA33yA/nJ/RF" ..
	"XXvpOZTCxq/oQjaRG4hV0aCO6GGMTqcYyVbUBQg4JPyKUJbazSDNLUsdqC0shsQca2AtnctrNPE+r+A/Ifikrq6eHvthPd+CwyAR" ..
	"0xZNRa3VGtZurdkvAOeHDPzO8cKmapCVhmkj76OmuR+osia4cd45h9MzOnl3KG9uB8FVIhmKtswmcehI89bEqdF+4ercA4em+Oh9" ..
	"8CVT661kiZ1yfz0FhLAaBCZtNwT0/bXGX24jLRUn6BZKfQpS2MmmS0tfnRyxq167MSfbhajse7KKpszfbx/kyTJ3e2q7hnkIJ/DQ" ..
	"yL6/7daokqUtXhNFFr+RwtoOuRaM9yzonEI/GCYSiueqgaMPcM9XmWfgHVwCT6WgM7Y8GdBbQCziQUsevu9NxlBygzLeNaSCFYpJ" ..
	"2lSheOeTlFvIN0U0DCK1a/G2NKqSgxHOTmv5FwFWzerEbgM0SVm3i52telW1eJfruTqQOzAnbBbBz6fU0xV19AU1V1++W9u3Q4DZ" ..
	"4WH37rRkgtIFZ75mUggvND32NLjgkXec1UaK5oxYDCR+Aus9DS6jFfMxqchnDbji+C89KKfUUfDIQeMYesRIdl9Nl8wbikdAcVdK" ..
	"zTs+zsX/8fBHJClxe1as0NqaBWeLFvwQmRSnbsMK85xPvn7Hn0C7R/HAvxNDsBopM5Vd10SazGaxdthVPFNTfvyKy1psKUZl9Ucx" ..
	"M4IOu71dg15i5Qp78eZGKE8nVaQ9hrv57GIJjYo5Lyd7bQ/lxxE/Zzm4U8PtgIkOo6gE0GH05nv2a17COi4FqYIbVNtH0lo2eq+K" ..
	"LPd/Kzqyo7w6zvbk/niAeecH0jw6Ek5t8hnfDecsps98gHtI4JBQx/tOMcx8YBgNBzQ2IxEdrZGbJvFvkeLesX/kcvpVC822G0i3" ..
	"BsK5Q9HczNQqnpr70h2NkUZfKWBebYF/SfuYRaumeMQVy7L7RQOj2Bmx32m9sKjdcb9WZZj/ebWMdci296/f9qFRqyjlscmivfSb" ..
	"MDWKfGCXsZ/ys6B/X4Jm7WDY53itPN7nN62J0aPhd7ptYz1DUXm0kZoOF4WM+Pg5up0YlR0GHibLUwC+aO9wkFzf3YSWdym6iJdA" ..
	"Mtd4PGhDx0ErI3nuSZz4FL0/PAikFI5HUmmHXou5kjXSFw15W7CrlJRiRO4doaj1cHxy3a5vN2fFm72HQ5qyYw5OCX48WqNyFFwN" ..
	"IWMEzTMHb77cbZEbOvhOMAnBPfS0bz7ovUiI/e1jB6Moc0EyWsCVaSEVOqMiMI461MsYFQv2wrnCx5GNL5tck0zZXoj4H8vmHNQo" ..
	"X0xsdV/b662BALftZMT/wogDE0L0ZcXa6dSnJnTolhFoQilVO7WP9ZsQCTXNpjw3gDI8ndopHDIY/0+EngkzSYIbZDr/I8BqcnXT" ..
	"ePfWuznu9i+QTn3pW1C0Ad5M4hGP0gom/4+C3aQeDP3TymTti5cjY+XQRoaADqhcXZfwxc+9xULv9vKWpmWLUEwqhf7Sge/GQJcz" ..
	"/hxkgxrUmTAIakXgdXeB/7WmMJNEer35OLMnOsOiyqkcP3oAXdFAXefp0NOI9o+6aRrU1hhyQGhhOto3vwUSrodvk4wQ/rqVGbk2" ..
	"2eV1LhUvij9X2BsrGuyINW3g46ZWrwJiS1rZmyA0hJBSLak4MKsFL1nnf3svYIOrRaa+wyt09TVAox14kQzhUzQSbRIGo3zRzLhN" ..
	"TiNNBGouI8kzPh436/f+WfBQn4rnVC1Uru9DRBVJHIFT9v0eAsIxq0/QCaHj+HIOxFd1SbTr75figZFm8uQtdMkziBmcUsfLemzU" ..
	""
local PAYLOAD_P4 =
	"t9iOXiXTV6x8D6As65qt960VP2nzFP7wnX28ZDJQs39394/H45A3bxGiUo0nxi75T1X9Fg1ghlgfx1zMnHKX4/sQ1zvoA5C5f3qO" ..
	"J/caSY0YlE9L6QcpI/4d6LzeBkvr1B7Fe9Cp+d959utgiIjG+yZJgXzvF6A6j9j/CLS1cn+WdqUn46KJ4h+qmVzm0hMAuVWv8jHQ" ..
	"z4XVFpFsFa/7+hPefZy2c1qaXPbhHnBe29mor3Uc4bF8AGlK8fDGWwToR5sVkpevnwDClp3Vi30P1SytFWaaSnCvVqLIjV4bSOPM" ..
	"JalHbH9e7gy1G/P4SKi7q13jucG1Y7FywKoH+xhyYSqz22+9iK5sxkdztqk7W49dDJP1SBacPXHK+1yv/sF2DbStlsl1+joHdJcQ" ..
	"HG2PxYe7zIOtiEuvBEcmAoECqWEuL+BUEDXZgjWj8H+uL5kFrU+C2t5kQrcXhJyUwM40sGpQ6K6eB8hOsaRyDh3REh8AxdHNWReE" ..
	"jprv/EEDmOgI7Jdf4GxjpZ6C3fpaGAS2eoMQ+1m+qfzNs4NVwvc8b9T8Rno/nDfMMf9hp8fjkws0zutQ/Klmp40Qyu8nN9V/++nI" ..
	"K5q8/DamyqIUbEUJtNpDAQyDE9+QJMb7lrGbETfdOlYZ6XGrfA2NBgJtANInaaQ6XbN1HrAVaTVO3GIM6z261zYhydLvReUTcFou" ..
	"sTEKN3EBetrcWT0hDKhfAM6Ed13gwhiOmyey7d4TVcZ8BCGUMhMybxSAkZEnHvaL8/akrTfI8VdKFS4Yw++tQu+fQm2oXm8a8xgO" ..
	"NVEwyLWlkyymDk900iAFIZHev2C40hj/D6H3/fWxgkjvIFPjkY9EVRC2HBR2YgMaaKJBegRGQI8tnXfBzKT6AIImbjjc3+jbE3WL" ..
	"cGZGdyw4XiQsE2b8T2fY1ob2epznAeHu8BRbGS6MelHO+Ju/IrBjpPBeCornoDHiHQhbYNyMkb0FfYBh47xqfVc9/QUZHRl4v2rV" ..
	"xz9NW+wRqnCqDQhCI1iNaBeEd8+KTv4Cta4Atou39AWXmRVXRwFx2Sv6a5jBghInRBcxC/GmQStpoIoIKzUAB1gTkAXOW+eqPXeP" ..
	"WaAkAeHYeaClgsHYlAeG3MBy+uJCVN3XQU8B+agykKrkTBCeKQJ9uiX2kJNq0ws+zl+g9JV7wM9ZzqTOw2QrHMz2Hx+yz95KeTJe" ..
	"V/2vmtd/ZpOgB+JOhzFeUKvUwUmNvpaDeSsIaQy3OMVbEmduFeo1S/iUYR/OVAwDITFLSbeu9x5297U3o3ncSuaRUNfj9uGuwRaT" ..
	"PGepjXmZWcZzx0nJrngHenBW/WGYsNv3jFvn0EWqzCljgQHN+PzydNAIKNMQC7fYFFxOneja7Wr9rgaVHTt5n357UoR7X8SF/auy" ..
	"WLwhURkk2+XlYG5pqhpueF5W/s+f9XBgWgNqmalh+Pe8XnRDlh/8fqE70fHbHwR30yLC8qn5anrF607+DcxxTmVhf7z1h5vVGkme" ..
	"TuJ1x/O7WE5DKvsyrqmfe5ue8+2UWdLb8WTeZrltx7OpnykGLh/DJlgRg5a4fPZavmioZfGO3y24nveT7G1OmWuI7xBd8iNRQ42p" ..
	"QL4ALmGDZqCuvjdAa5eLhBj08HkoBlFL5pU+3tE4G9nSPQkYAyQjFglN6odNwkTnBP95GlgxRYM93Rt0IOKIwvl782B8hedcRH6f" ..
	"ziSWuIef67Uqe8cyi8mQ87j+aGn+zOo6wqCUb1n8mOTwxA/dmKxnVV+8o2oTNLSw2esObXhsD5DkHTHRfmDh6PFbir9tVgTUTSh+" ..
	"BzLHZTngc/NlnEgESyds16uWvueqoyWlhQ1Vl21lFz6MxpqQl/Zp8cIrPbS72SZucJreiBUy0lFXISq9/bWqGzjeKcjQNCqdUfmf" ..
	"yQTrb6nJoQ3WEN3wfqEg8FqBeXQnuH4iCcfOOz09rLjPrskTknCXPi3VSNodEnL7Np9fjVGkCXWHVrRbPiTmrfFb/kAbGYS7hXXC" ..
	"MOfo5Am+PRIfzemQUegKMPNEfsmVTp3mfA4vQvaUAOG5UJTunQEXVwgjB3+zxGOpZ2zCbiU+TnEMZL4LWK2629wDuNre0owfQ8XN" ..
	"2crPnuwNHgxm6A1LaJe7iqaVx9PYSfK3vZ2HNWZLfz9k9+4zITBbVBFiCQjSkNlmtzuIB9wC1UITk3/3cVM1zd2eWh17c0TnMxR0" ..
	"KHF46ym9ZZ3tazHYlikWeQw+uRCAdjZcmBlFgPNfpENwt/nkcF0LWNvSWzD/gN3pQybMJYeR48Z7lvqi4OzP0TkwYiBzWhO6+phT" ..
	"kns8CydL1/8wVxPzxW2DNGi+bFAM4pXJkDd6PEklXCD72q8/NLerAx8cgMh8WteqVXKWQY+ZIEeRLEhEBdJBd4tmEzcWmJ1mOmrr" ..
	"O2qvefrNo8UhYYgurCVWpV5MGZaMeYZ2OeqI10Pk+mUefnPn6iultOSUKPy1LNL7uWnReAxaZ39xNyyVcefifL0VoGxuLhC/clAf" ..
	"GntsAvLDSjM7orSfakse5hUsE3c+P3XuuEbOp54WHyOR0SLu71FpZKeEOeyqBdRc8K0nfa6a+8mW/1t7fcBLQ5I1bCDO5k/O0nzO" ..
	"CZ66GBoUoSmAFyxFNsX9nct4VQOgjNmCenNUBNnbgGhL0/sjoH4ru446p1CACvP3WNlNejbfzfKdWsej3BJzsoX6OKOMuQfOnom0" ..
	"UAOCEjY8GqGEZWqkV9lxeQjpak4jH1R5VBEy9goOhVCcMf1fgbaGF1mVsp2fBy3nIvEYeQsC3qoJEi7KiZRsTmFt31DRrNS+fn9r" ..
	"28mTUiqp/oMsVimBAHSzUj2PDllWN+LFeWetai8mfchwtmRP1j5KYdN+1xXsvjYvA5vCgF/ViifpIwvCJU61aPizEdR9Qehjh7RW" ..
	"Ils4Wf63d50sdImAbKPHzolUZLUGSdo3/DT7440X14w00b2q/QF858LpqKWfi+zqSsakA6Qe6Kjzn6m6EoQcqGDLkaRbCnjGsS5v" ..
	"mbNnInQqKkbEhxuEhPrH345ZNo86ffXHCd1IhUl3+pTG4DMS4kqjyFHnLbo0Z/bq0IklUo5ANYxagYmi5jN23sr7ulTCKs5ogQK7" ..
	"RsxrKKIOVp+W/orjG1lLjRA+HIfSpUEQjkIZSfC8A3zThf9mrGwWBIqig98PwXVX0pEla4eKBjYHgs0piz58toWJ3Bz3FGVPpsyt" ..
	"W8UUMN8BEc0jj4ZK4k9xNARIwVkKeFbdQfow2v/ghSIaTbhk+1lMVoftehW3OzJvL7edxSChZJfcCYw+wThGJI7LWPomBv4+nwLg" ..
	"Ky4ip7tDZCPzJKe5vX/5KEI/cR+nMjjvNhLgwPCQU0ZMPGUugZGGk4XsLOwrN6ARYJSFZQJ7jMsxY5oKoB1Uy9DDlup1NaooosZ0" ..
	"YuY3JwXNGrHVRRvNWzUeJV/im3i886/e8dBsIqgKJMtkDuSbIIfURQdpVw7za2hIQZWSrdC5Di7DNEa9PbcMOxINk5UfDTbSrCkP" ..
	"2dbSFfpr9cs8Qbj2Xp5MQHau9lskJJxDkebKBw/Du70zp3s30vNuRKSdFZR98MC/hYyDzold25cwL7WloKwjOe7wDzAHIMhg1GyQ" ..
	"9+pr1AmcrPTS9Emr9+TmEgmVDBeSn6djGSxkklu54+kWqe0ha7lBhuL5P2QBh8kGfaDLMfUhNnR2M79RM7qKzBQmkypj1CiCJAsn" ..
	"nKNuDDOw1tQlB2i1KVdz1oQwzwXumphle+2fL2D6hyrKy9tQF0uIhksBuHsp0YfPiMVOYFu3hqz25Msqkn0672SzDgGw7PgDsxmB" ..
	"1uXM9nFTByUgsYzgxClq0q2HgbXvqbPrO21Kz3BgzE0WfvgnKMuwGAgQESL5kL5J+QoMWck+NL4XxBU4rJb758trt6P/iLE62y8w" ..
	"phMskcSjeKizhUW54cIS2Ra4+Mev0zVGJDa4bMGfDJ5WKiWsscC04Y4XXdMECKnRaelN6Sg73oifvSOfCJjeC+UGNJEgYGfuNXVU" ..
	"fzGH4QMcAfq2vndc6WBEHY1aEr7luVTSGjM26Zr8fGgv16N2tdXQtpH9tpDnhzPs38kzgBEjLuBUpw2P5adQceEzhTxYzHk2mQ7C" ..
	"CSgt7QVCnbQJffktbvXxiNFKT2b+hpo6RJm/lNNpSrqiplhChZCo8GE/O3xc0TuNgH3Q2r3ZTOA/YQBw12XblZJ4jy1yGYT4I+WK" ..
	"qMDpWMtijVGo1i5Y/m/5e6L35pLwwJxnq+jP35AB8TSLuTRc0rxUMB2TzL97t+ppko7tCTp5kJa0525wGbA1Z+L3vyliqvure+if" ..
	"w3XzKLYPe+hkenpFHAFuoI9fzEfIm8sgUOqXXkyvHQ3Gt7RkqHTqQG9M5eNNQLeNMcXM45lANo8Y8+XbcsGdkF1fTlJ4rMKpufqR" ..
	"QC02zuA5I5sHc8kosKp2p9g25UWYa6j2l8DAuOsWAeGdpxWKEFwdsAW1klrv96u1QKbdeM3Zd9GRs3spSy0sC2KYcvHghf67FoZg" ..
	"IUxizt0mnlTSwIHI8iyrAT+IACRvHvP0jFSJHbi5wUFEielTuS3rhZckboBvvXUgCdWR2xe+QhrZbb+2DzV7QCT1PKHY8lRikXMk" ..
	"a05M8+OrgXu+aNdw1httFR8QnfL1pLzoWSBJwvFnNWw5vL9yKLMmM/cIYWKoTLutFNkzXhuKPjQGFT/oOny8I1eEHrysJTlUaugN" ..
	"Z8/yt0pApGNxUTpuRurMk9aMP8akjc72vytHsnwVYAyUnRCTeDGJRNU0Kp4QfwlWEdN5ACmHifEKcgEGUDToAmCnL5H58Zl3bwKP" ..
	"idG6jch3WNtVsTvvcL20eZYGqQvcsEbiPb744vL3hG0reSEPF3hLOe0ZS9ZKNt/dyzQFkyRq2C5NGYRlhM4mf7F9vIRdhUFkPwka" ..
	"3NWfLs+3vf0yvdZG1pgcjW5wPWZNRfbIPfwE6pWFpVABmcFjCy1eKCG4FCexlM6CqyVUNM7PzDGzwddiL8riUrddugjrV6zfnjHW" ..
	"O2LJkzVfmfJVmvyz3HDNyz7v4B1J7EHLSilSG6bz9R6BoIy4Be2aw7jDBnD7gUoymM/z3VDIwkzU+hiPLrBW852D1D7qhFIOGJj5" ..
	"y2RFpPwwcsVQKZCiVNBygYMc7tVURQlB70B6tJ2XENUBU6WaU53OUfUIYDp3IovSwO10UGkST2ojTiYerofHVBF1TA4iJmILohpZ" ..
	"QGUNs8lRnXtoJHEaLNpI1gJqQJKV3vMVFtqw5FoWXLaHlgU5QI70FlioSpBWu1o+1cmbnLkyl+fvM9j6/7rdNf5Bg7waZ2e4teGf" ..
	"TgN8txbzJRT7e/9xGIKkdeScPGwz08q2F9gOEqLnBrrEGXuvQaa/FgaCZnxSkc96cNVbR6JykFW0ctanu+sBDmcoqwq5IKsvhixV" ..
	"rN277U3l/FevPkqTxdMkTS7dx3sFJrUT3nR5TsKpRMF52vpUOzK5NNFQHsq6KP9JPFk6/E05ubGPZDqMDZUzS8n6cWdOeq6pZgNG" ..
	"q73rkxknm0vWVBWPGd2Jy7x9DjxVA6i1R7TBMEUbmIKhqolDqDHb9fC73FmGwhp5ea7K9UWn+qY4Pz5LWF1cdoWGzp1p+wJYCpRh" ..
	"fMAPx9miCKokKpDM+5h6uYuVWTo2YGfqMjpQenLkUXNpjNFcNihkInZ+b9W4uqO+BZ3FETV8nTV2p93cOcm1UxttEnRSuL3UryQB" ..
	"KzYmZ9llL/6RXtUfQP/HtxAoAtk64vG94syXMdmHmVJ3bbJu86o0J3e96tJAPZz5fJ20FvbTrTPpudagHRvit4YKHuHuf/R8NMR6" ..
	"UJDjmctktaLthImt14r9JZsGomzXKso+9WxD+A2Nx+TiyZwMsyxE2uNHj8aOg6XRvliVgJNT1w44+72Uu6LBO2e9hn3BiT4sR7tn" ..
	"/qpiAmk+T5jIbCA+mtEZR+ZDEYDvgs1irWN55zU6If1P2hT8zv3BJiZBoJIt/z97YKX09K+YkGHugY7ViS6aLJHWzhB/qmnBLU1w" ..
	""
local PAYLOAD_P5 =
	"JEUFnX9t8lOpebaT6VSF+bIXOacsUUFcJAv11VeXXn1aaK5dZ2MTaqgiAuvxfvvpEZ8TQXAKLC2lkm/RcSi2SyUwphnwI27HdWsM" ..
	"dR0T5yU0g6m8Iu++N5xXGa7w9+SiYKzbtHcpjTd2bMHI+jCH4WekTtUWZLCnnEi5YrJwsm/2ngkZl6Y2PD0KxGOecJYxtji5vFTV" ..
	"4MPBmhBPqSgjpsLC6m6K0oAPln+vQzTfwgYfodS/aumdOs34FtKkUaJZ7n4m2ZgUtYGOoqTFgtloL5iFSuq4JSOPnt2KjmdNL3Bv" ..
	"7PLkusl2ykXHR699h4q7rtjlvtjfzBowU/NcFc9kUn3PnRc8vwRzJBbD+oK4UwnFSxKZIPp/nN3gDp8R87S2wGss0amhNoBfnFXC" ..
	"St0AZJ1XxnYoqBN4q98dSDc8/b+zS3LCgttZBJ8N+0bmtc+vWjaIJIHCIJ5a+xqH2wjjfh2RunrDYM/BaZrRSJC1pD2OL2fOrt3x" ..
	"k2S+Bq3fUhs605eMJ3+q7i4BycNrHj8qxrao5cLVL5KSa2X1j7g8qXuw8wzRYTdfM0y2/sskuA/UfVFkVejSqbuFRA/4pm5+gUIj" ..
	"KAzihgccqZ+fYjl5HgvaO0VVNXOYIhvRfCrClaIMyf0IVZl8uCJ9IwtpepB0kjC2AfdN3Ttm9NuIKbVX8Fu6O+TybvuCozkUwdCM" ..
	"U/rQY9DpHyrjjPkwlQ1PUl9crjfYpdrglvoEttwH0yjJWLXc7CNyUsAmd2pBZJ9OvIRwBYWQkcDsqouWp2Vg5N8o3DKpzPwty5Qg" ..
	"hKo5paaVj0yAxiIJQIvbCvI75jw9T0WI81KThi8ojGyx68/zpJC9qMmZDvUZeFyk9W91g0AZKOiudN9Mk+g0PoClITI4E4Hr69DA" ..
	"iXIZr8ZcK+doLf1YUNOE/uSwduy1/gi6XeZhAz4yX8cUclezwLp0h5GIruwEinuJlZg/015wPRGdM41xQqiCCtzCH3VCuZ6d6bUU" ..
	"QN6l2ZVR0qMmNadEEZB8nU33HuQsluN7iNiosRdWMoYUU/wQv8LPyZLAqeOhkXgnLKrdeaBRmeAAjELo6PZ2bvOad0gVW3i8pJoL" ..
	"aBhW68niUqQCPCz7vUSlaRqmq+ShbrgOpwaQSx7bOY0nCnTMiglCU/QuGD2NjpMqNN0q2IPVS+m0qlkGxvSXr5XIbZDmHWS4n+2n" ..
	"Ir6xpjpBXCSwECXK8wten6tndhiESJEI932RFM8SCUMyozqHQtfEyRFjvlXTnXQDlmxEgy8x8jThJ236wB3jMVEsrRnKZ1HavXP1" ..
	"bID5ZkqkAl8H+wQN+xt3li3HCA9NnmTU1zfZGcwlgKJphydf03tlF0rGTs03WmNIAoPw6kpfmqTjUOfLibqgaWMu9WsrKhLnzt9Z" ..
	"E8JUSRvITwK3bsTb4JBqWyb174y3l7j3euJiFkSjZafJrlnKDrqBSFbegPW0WbyoMqxRuh3pIfQVQa8XDT5XxR7XsyxxFh5jRBLc" ..
	"S9RX+Cmn7eTJTyl654KcibzWuJlcUqW2w10tQBooDtBY1FmLUAjTjc4uE1hq9LNplZtGpHw3KpPJ1zs9SIT1iV9owV7o3B7XPxWK" ..
	"rqqroaW3dEQ8bRMYBfudlP9sMpyvJE+RXe9wAq4hiqLb37jbrQZnvalBDNaJA4ujQjJZpTBqhwhTI1GkiO+BwmcjoXeq5aR87rwh" ..
	"PBnaAAjdLoS0M1Gmvc2y97LX2lCCK3zF7Ffa3DG3vg/uFuKweXhMvCtCPPawfpkyjoSRxVBaAbS45UEnxwuAvJ17T0iwRkyptZmC" ..
	"xaekrnum2KI8k1x2+VTDs9SfeF0VHv8rXWV5UO1AG5QCoCywoJfQNXi90NK6C48YrVOcpgauAihJw7DlfZOlEx8EceBoVDXasz6s" ..
	"5vjFhQ5EBDB1xMgg1AV+ttJJlz8R8GH0yGOSVP9OBvi2bG/Gv75y3PPVw1hc5vgrrIjxriHMChzASPxCl7T8grhF6WXpuK21O+ZJ" ..
	"9KyeaeRPbY+QoXPx3gsDmKF2DEE46RxiBBKQofldancAob79aV62eBmsw5Cbd2uoEl9WFqFOG/VEByMVs41CuHtyN/cjjKX+3swt" ..
	"ydNffrPNlBbFCrDzcP7gXgkbVlxRKyDU17U6R2EkowGIG5cPFCsy7D+Meg5MRCkh4bvW+rmVLaER+U4xiuBi754Q13CbHHS1oPVx" ..
	"grSptJGYADiONcWAo8zhSOapVZpkdnoULjbkmOuFmd1hXRi4EZaS9cP0NOFXRvXRzwPpFFzchFrNhb3yIUyoYnwugQvHodVBR/Pd" ..
	"Otc4OWHqjhr3tqy2uEVr9RaLb0i7JkJN/Xw1bL/RWvuIbCDgBhCwIhmf7exPoT2LJqkjQYpVlUlZMw83Lw2HYm0bY5CdvKocOuwO" ..
	"O/76Y9tEEwTX4+03ODOQe9cJ/v5C1c9hxtmTlBJC4ih3Ryy0qI0VwJjihqcfQFjYax4ZXOfkd5exprrcFwR01X7l462IhlYsOz/9" ..
	"R9c1C7ZvUw3GhC4uhfN0vb9L3CBi44DdKBgFxL9uSLZrdaFGdTbDTcx8U2zNVTP6ciSsD+VtHAswWu/EzTnTCw+K9tn6CBH6P1zA" ..
	"IzT9/hHCSGLg604+2runS5l03G/Z2RLaOdhklzKNMTPDcWuOhP9coxaQRVM21iGHlomXe3YtRoy2po97u1GCp+Qg8Epy+rz2/lev" ..
	"I95x9J0Qfg+qESgW3AxW4JAwxPJ4d8j4wZHTPY0XSzqVO6Pqb3UT+rkWBou7cmwli6n4HBe+pH1/TNV28M212C3UJHKhO/Gm5xr8" ..
	"I0Fcvj15oq16aXnRDmeHi50TB7ryzJvn2uj5Ma96kq9tkyS8mMcvhGA6AvuEnTxMXTkt0z37GRe05M9FzYuE2w/GTLHiQFFWXnP5" ..
	"j98MXROZDkhdjV+MsWFWiTSW3hQO2PRQfA+AlGlziH4rE7N9nW99ux1/QRMU/aJvMj6bIhNjNQYrs96gflht60sSqIQuItMchjUX" ..
	"ozkIMVZ+fsXKuAPT3BrxVawYajygHyCppYFJ95n4h3l9rp+M2jU0fc/NrwesyRTLvxHAaySU/2m2e1j7OgypFmrHmYDQKrsEiUnu" ..
	"mT4o0irwTtPYLg/wMDvmeSWbHJubXAdryzSRFEzv+Ja6vMgWee6lgdwBpXkNPoVc4uh9qSTQjmwEOBJHNbzsmB6lxKI0LhNchA0h" ..
	"R+dyTl6xLTU1eFyj0I8h3+BoNJzeH/utyrlfidev7sqpYA6NLjuu7zv8pzVFQYcffpR7jDOFa2V/oXNqDuRCUIcHuDMm8tTzOWBM" ..
	"bqmtM0/26WoC9opA6kjurfvn+aCMqGMd6Xz7KULfGIqYCWOAw2LNJ7b2nRCe2FvfBIQl9uNmM6mnJ3NKlT1s1xrAnzw2iKeMvD4H" ..
	"0tYNopmd8zWGW5UK3vd73Ow4rRu7ielr8mqWUEmKEAnKL/jYqDc7AZLdMzFbPF7dUeJGOy9uggyHK/JvAyeDlSSOpPE9Odses2Z0" ..
	"OeMpF2g2i+Cb5HVJM6zkO6+8vMPNN/Yj6I0g0HI7bcy7IF46Zz9fW23z2FiEjMVMquJeXWYUq+abRVJmZHZBCeP5Q2/ajNH9YTVK" ..
	"zuxCUkbMahNvs9z4Gg225kXOd0zDQgLKYgY3UKZzEB1XG1sbddKP7GJVAUUt/TmT3jy+WUhjh/6wGmPB+yTnOKrexmXTAPKdRoKX" ..
	"v8xCi+0DpTYSVYSet5tvBnrae0UY5FkW8na0AZ/pn5ZWs8fy2O+xhEWmPObFdjgYxAfwyx6d1FFXuLkDCG797dKsMlBLehRMDLo7" ..
	"KgEy/dgF5ydM2D5uiYTom4k9BK9rWcL9je0i8FksrC2mLgZyk2jjT4ogfdskI7vS2SiC7GUBwyAjS4iSOEY+ABVDO4600+G7Zbh2" ..
	"VMTYWwsp2/ngjQyDXGQjojKva3pcNInlt+fogkrVNwFfLxyfHCitLSmQdr/uOulEproDZYJT1nCsD2iTYRT0WZbG/6ct37goSyh4" ..
	"4JYwXzHzKsdHrxT61EHdfBNZAho1FpgiRklT/ZyBQTDd1iuwngxrAuNJm3fujXmQE8ipcIjbk8J1ByXv7D9/zgP1CX2YzgD1POd5" ..
	"SStnome7jTCSeIadgqu4YROlmrcBoCkhVPnBMoPiBdg8QP71Sn6uspdULO07j18GEl8a27Gc2nhdx9v9OAXv8xv28FSbIxbfwryF" ..
	"KE0zGs26Yz/6EVH14etkSr0uXTsP1c0zB0wtBf4a19vl96LfNNo64YpZYK1GaVljJ+Cgbd+ct5ahsmURR8mtrO4luTwe/o7rHZLo" ..
	"amKJmBuRNGgeeAf2X902sXgkoC/5O0UgmAObih3A8Q19a/dpeWoy6wQksCsDlkaMMjJjaXXv+ALPSIFhHEgBgUOI4fiKkChtMte8" ..
	"Rl3SMZ6gRtAEqaAm3/Bt+MN2QMBL5bKkucqbrDrxQ9g7rnFwvcU7+GGuXjTsElYVsvhdRbuaF7T5OeYx9CKGgzKWy4ImoBN7XxfY" ..
	"TFvukBDFxTp5kwI/gaKMFYszBj/Bt1q0zpVg2KzEmhnj04CrmxI7j0iymz7QlofJvJSPaVg3gyEuh50JKmq2nl7rGwxJN2Z7pO/b" ..
	"p2OL3IkR92u3nwVMQy++u2UonDIfF9yT5GIYMRsl5M2o4uK/Gt/nrldQ1Q0u1om4Dlp7NKRdoNRNN1biOQpzfKb8GG3IxraNKDzy" ..
	"wQ58BelRs7NtIFSu7E96mdIg148YSGGwWXs3pc0vSdyDsYQiHCo3GEyCAW6e6RMg4tilk45TfDXXxibiEDby3cDsL1CTtlRkWc4V" ..
	"PwtpYZWWwzHMKHYI8KMBaXmPL7GytxJph7pjrr0dd8D4G7U3NfaKhfOuVWzx5S2wShF+RcFwNRBQw0vTkqpnyLbw4PAv10epvN3r" ..
	"LD/TdjIO5wKgWTr4R9jWodgnwQoAf6HLkQRTPq23o3RJFjEYi+hSvECL8gnseQTx6PDfKn6Y71sjy8JNYCEKL9v4F3ZXcPljETL1" ..
	"U3StbRdWKXPuD9IrzhS6qbIM70AKUU2HAisXWcitKNCkDGaVh33Xfsir1RWJhvnBMDX5POVcCmeBfV/KreimUvNTLT+h0Gdaii1S" ..
	"o2PSu0i3sn0qBlaz6jo4lJ6k3apF935Gk0NLgEbxSvXBqlYyaBRjBquWbrFW7X4wiqzEvtI7RvCZJK3jLZS5NCXH1G+rTeWweBwQ" ..
	"VWI9lADSAuB1T48y3/3vKZnxwc3oDOwaMh52I/EG1hvrxYMfruxxsU28wMz1aXXJydUhyZG0aQGUztaGAes4kchcplzLadLVii9X" ..
	"Yb7iv4whWpmeOr20dg8ZtCUA7XuHhYhMK9pDuTt2MJ0Plp1xx+60e22qT+E6+f2ZNpaEbCDtMWbkNiafQmaZeQjg+iXr2ryi2qSH" ..
	"gQs2KQxeEuc9razrGS2NiJCFdLs9lqxJnFg5QL8JEay30x/TrqTja2kMeadIAgm0mL3HeuVeXWxsVmhYQ4r+W0/sJycWit34d0a3" ..
	"9jEdrRdA7MQtqFNxvQwkEayXAlT0veRcGvmXTtHYFFwJ68rWkjRrtiQjOUuULlNFkI5FZEYVQlW8V7A8Rby5dlIEFHoPMe1Ypwx9" ..
	"c8P+NAUbiRJeieQQz7RhqqnVLmISRbDyu04NYCFJRKrDVMx0XBgVkCM3XGCArp4AdIV31yt55v2YmDy2SSn8si8fgDDNuyosPf9o" ..
	"Pkh7ibmJKcrBX0b8nJJppOW+N9JQ6SS9+lqgq/LRkMI7ITUJDx6AlSLPelOWUckZkxbktx80vsFSjXM+dlLu//7Jmh1nXUVDkeQG" ..
	"RnzsVSFRyG+Y7989cj6XeIOz2386FEMQZQuGO9dTJ5nC0iH0bScp1Nw3X+zRSyzRPL7fWlOA9yhEwJXkdxvlFZ1AxRI/M19zXuLy" ..
	"XsGHEudKfsRYkl8zRYXWKeDjgtPe5eePpIl9z2AsM2SXVidTt2CYiBJp3i6sDoWkqn1FAqcoRuKWPiEqxc5JnBMzpjKLFP6miqET" ..
	""
local PAYLOAD_P6 =
	"qfmbyhHcdQJF2/H4s8caXxcPJphviJ0NwAIeZgoGPek0/b8UXomILPweXFh8Ya08hTAuDRj5FcmdRVe0Y5K2qYL+0puDF7xA6Y0o" ..
	"R4xqJZLF+/y/ehkUklVCOMgpcSpx0qVPbl9M4Dp16bhqzV2qtz4QrY8+cGR4jtfexeW1FZz8yIsT+MinwuP31iEGxFsiu62g6hFN" ..
	"oF+wXMQAswqn189UaXVAD0FF4SH/UdfcUlbNU8LCYcbie82t0icQqltDX2yIqlaUzZCucXq5sVigkSDbSsES5IVCw83XzanpOp0D" ..
	"gaA+l3Qn46mcbBK0oHyx647fppiiTfLag003qvEXLeU3L2FYovehKa91gxiAXXl40BoECGRhvoJx/rl3ovVgZeDqvX3qvbM+bq5b" ..
	"aF9Bmx+DoefcBumGN67hD8B/QaFbJFs2JlPRkQXjybk4IGCyviEW0IKcTG9MzA529mFpQcxUJpMAn2RrJaTCZ/o7HzqA0qbVAu/H" ..
	"o84Jbeuzxk6W4T4j0LRT2TJYnPQACch/shByYi7bFEWxFmJWprjCNX2yz35yETMwTBmwtztqNKooAPzGpWzwlspYVa4eRb75LJTC" ..
	"nKFoWo2REDM1/Hc17tVpTxVTEufov0KYnWUM7TlID7ZpL9dGDhJppdEkoWp4Ysfv6/cFg7XzhhC1sCG7nO4Fw7ZFTMX582ujgTkk" ..
	"d7U5eSG44t8z7+6OLk0j+M25QDHRkLQBuOzgENEJyvA2Th6QSnW5ilzzoPYEABO95+kEqrqk/W/E5KXy2IEjy0mYDn7tsuPRyeyR" ..
	"c0kK7tYM1sD0ALYLZU1T5hiU87F+hHmwBlhR6TByGCqrQuuzAzg6bFYzCOoj3MFVk7TqFoP3qKBYTicqjJ2kgXCKZA0OTs0S6Pwa" ..
	"cEA9DEzFWLZnvAdoE5H4/Abd0hkoaiF3TLSPVcGgio3bNA5LlNT13Eh+zSwZ3qRTsIsJwvGhAvYL+LCSjrmGRc/7U99UjyQkS5O+" ..
	"MXPQLei+BLquiBHXT3IYwGF4WkgSBT7SOfpLntds1THzcKXszTIW6AF3ysUipbl4dNd7TTH8Uos5do0O0fklLNDqJdte6AOofe7+" ..
	"Lw/c9SG3o/4OuN3Lhs81a6U3dkIfgzKI8QdtD5IQA70ACs10sFwEu16pMtcFysHBFSq22TFWfCkXefOPXg7ZfdcFjUkNCSK3haQa" ..
	"DtFizqWKKB+D6x8ODzvLN3eTvRKggoRLJJewhYH68MEDRrB1VvhbYSZ/quV0Jo2t6zmXa4AX58B1zeHHojuOXxxtXY7ZtEBiVxJA" ..
	"MV05dzEEDHzf+XqDBTaXkS9p1cnkz2+jrISKEVj2+5pXGzJjATkoh1MYG8BxXvrTTQcQ/7EeYbF83ParCAhcKS+UnDYgAWsc9sGt" ..
	"mzWMveZ5IDwkjnbcL7OZZ8OfTCWcRYgSmyFEn/0nafka/LGn9b1DPd7dALEt2tJE4p5Cbc4rBbRkIOmmXpH4H/hs1BQegrO0Qct/" ..
	"hvhDb2pPJWSPJn+6t2IspLzY8B2TOrZ17pzJIU4PUav144EqRxfQNLf2Xls4t3qiKlzlyrONkYbyOAdQmMluFATRf85mJqKbEBhx" ..
	"UZWrLacsCAj2gJkksv4+wn/uA21YgkJfIn0AR/e70gzKZPqsGAUrBk67iPHekPI6qZbfOaoXzvDw7Qlkd3SCYxltvE/46fTn+ajH" ..
	"mix7fWjSQuVarhrD8c0NpGD64HmB9p7Rt6RnwDW9r6fGD9ozyoDPMEuJDuX/BH6ZavM7mlHvJ/VronpvVw9EOw0rOse6RylJewSo" ..
	"hJ5wrRGK0EPnTY4fJkRz6DcEkg4NJhUaV4TNZ5/mRI5rkVWAeTdlxMbmuUU11d63QL1S+YSJzskT4w5dRgIcwlRoJE0g1WX7visO" ..
	"owW8lK++Mni48Cpl37LW95zxqFV4sXO0aRdmpq9r162x48R7eYztQxxKAvNABx//UxS548H9tPiUuPlIQ9l2WpN/B1q9mmzFttH7" ..
	"C4BSWHGhdMpSIKiQsUwFRsIpanepMJx2scP5oJppJKfUn7vhyw91MFPOvpNPxdyb+6bJNQ1g3y/yoTrsV2DDZCKsRDVq8pQBjnge" ..
	"bqhU9lOqEBfOFbVgaR+Dwl6t+NLubNtdMH7cLUmHTnqdHwQx3PU/KR8CQymr4k6T6Sr4bQqY5gKKeXm+RnkjNBX/8JF+aWTgrB/S" ..
	"vRa+8QFd90tVt2Lbv1gfHMUcEAaS+00LMPS6XLrPXfXivBKpzw4Twh1xK6P6lsqTsqekyJGwNEy71E+hsnFdsRRvSZOuFPkDgsXR" ..
	"Ca7g9vrB7npBonEVi23m36HpjR3VLX+lasi3YQeYvJ2OvazcA1aQk3C3xTAB/pzdiS53q/nFkVODiPbeBE08mFBajZC9xD3YRsm7" ..
	"hP6mKMiGVg1vcwG+nIVWknRkOIr/yerldA811mASCsBlMrokGQcJEhzWoDFumDdXwMLeXQlJh4dRB9XaSy1g6jkMWzwMVFjpIJ+7" ..
	"8Khv2nZh4iglr7jOS5p3EehLlqYbTfs+PJMx0hl5swA0GHlUfO0rvZ0tY30B9mGqwjqspXB3qnJ7VpMRWOl734v/3MrdQwtGpkv0" ..
	"tYLXLkVFHtdoe8qChdTxnRQ+wCwkpVb3vtNJpFyVNWXMccfq4MVl+Qp8sB5sUmFosh8D1NAWaHQKjj54cTzyBOmkFKERtoTQgnE3" ..
	"i+1snP6CfU1RPmzH6jJPoQCTamvUefL3NrJHKOTSQBA2i7FaXoDzILJLHYZJ1usSG/z26XjqOHzWhALC4e+KuHFkzlVTW4x23YtN" ..
	"eGafYVUuHuzAyLnJ45y3ZwmYPYCJXdqKTAnAJb/H8KOkosSsBVMVmgGpi93xMzgeVYjD5VXFyz/yh40SchSrliD0eIoj+zs6SwN8" ..
	"smizD2L5HUnsvtXp1NaVlZV4ZQ8IuZGRfdFSEKrkGjOK8lJsavyJFohuETaskhNiWpK1Xe9pJzJyG4FrtRtdnsQSu8v5v380of0Q" ..
	"SZSLRVh8l+sheoYB6LSVzp2qRl21S4gDq7KOxCqyWT2t35LeOMF3VM+kMxzmtVxr4t4LEw9PkUEUV655UqhQuC10k5RWpJb7xKyH" ..
	"RhIwCfg5wlyD8UifZS399fD/hXoqekc16orJiqHvdx0UQb7+tI3IHMF8hcGnQrhHd1ULjc6ljKRwqdDdSeJuVfPCQ2jYSTQGnX7Y" ..
	"Jgjp4WmIbxWvt1O1csLezxKAbSQAfx7F+XNTiIFByTIBF3WjrMpcIdFO4xjfr+7WHwMjin7FfhCzMXs7K9ufTwY98I4M3TKcdEPY" ..
	"zRPivdgp8K0nOfXbLT0cio4QbN5tNXmCxKK2QPJzGSOB5XVWqqWNitEwiJK/ED6rYhv6J7grhsXfIehrSMucq4IHfZpsgJdOZEkI" ..
	"R4o0ITBO7p0bqopiIScUP3kEP5fwDhk4tQeY50lQ7V4NqzbRsKoApD6J5OxQF5yt7mfx0Tn/XzbYDXd+ZgjPtF8hev0nhI4W/7kk" ..
	"niykiMv4WcZhyx2J2hXN0a1DuskyJockI5II/04UWcEtS72tgwZX1Vwn2OtB0HxprymjlOCXACMagMu7zz8hFTS4KCLxzPc6eigJ" ..
	"3KKA6pCrCEvDERsLLPORKjWzFFLDGjCaDcp9qoin9HtFY60RGN1mYmnMqSm53nOGQi1GdPZSe1/QtSB7QPEMra6MaFYSQZuLJV/C" ..
	"hrdH/ZavsYt1LbtENbn89gN1liu7jpxK0+305GGVnCm0br8XPoZbECXuGnjbO8uj7iiHz0RH9fZJMXE4kxsokmrIo7lKnPTWcddH" ..
	"Nz8j6BO/EzPtOG0pZE4n9lrVarqgdyjyWZZubBOoDuAE+eEI7bMLkqDyF8TDXj+yJhpHbMQJhNyT+YCLDDolGsmNQmqSKWR0FRmP" ..
	"pYp4VY1HR7WPOusWxKYwukvdWdBVxnp7s+aePHyc1Zy3RTQLykoiZLGrhYjbqqz9SurIJXdzBvGuLZbFO6feLxyjdCJatw9Xn/7e" ..
	"sMAOVaiFRMuO29PuOd9GH4fMe0JSYbK+/lUWFy8QH2TA2xebVt1t8165juVkd21Fkt8o72FUeDBVmAVkuhR5RDLnOeKFSfkRn2W9" ..
	"S7XMqcKSFDbzxPI6FtJKMi4KUD1FY+jMnDAEeVltYgyJ51zQNUdalsKJV/daTUspzujk6ld3pKuHs52gjsyZ+pNLgaZuh81DzY6h" ..
	"su0f8XI/v7e/aulNCb1fTeboTLe9ZCkHo5frgXGcbou5dKN+vtlv4CMPdrbxWw8zmYUeWXKDx44VVoyUBX2CJ3jvcNvo8JipZRMu" ..
	"XUA8QRDHlJvsHb6G4pm9Qv0QYEts4b7vQ9IQbuTpbkk5VWQtTXvjlZrFoxWa0xIYvQlqo6RlGYEwSUSKCz+IxH685i5Z67cjqgEt" ..
	"0O6IjNsrjyM3wj1GZnaECCmgFbS58qbQ8XPkve29qXswt7p2RIvsPUZBQB4NvYxuqWWsSQZHjWmNwLewM7Ymra8gqfmoNve5KLg7" ..
	"6TNwVEHc3xe+tisxvdvs6HpOb9uuY1vQC8GTcJZ23Xq72g9BfuOHDHotDW2Mc2c6TbgrPUoDXpg4a9kt/LXpDJ26VM/Vwg4OwMqc" ..
	"Ug1UcEmp3OmmU2tc3DNB17WTnD8LpYOp+swcok/3vwyoDFKUM4hhzrOnV7OrVkPXP9y3V2GcSydet68ybN11P0YkKnODEJR51IIb" ..
	"9PgU/W0RPf0vuf4KDQz4Xwc0erV+SpEJ7VhnhSaGhVQH2zcCIWRzMh7BGzYd7r8003aiRCfdb0GLEc4rkWt0YlB1MBYDkeAn6auH" ..
	"Yvg1MRguz01alfe8c73hdJ8WiRRlklWty9/lsrhYeayvnV+RhjjzLDnf5RzJW+Tu374ghHTI1zj6LqvaWsGIlkSnGEG6za1mMhoC" ..
	"Cnni4rByBIpOqrXGt46JtBUpNJpPcDvzFHLeMvPA8tSIifHo2Ghu0NyEuaTXzWP17MenIBM9CbvfyV+qejL9M8h4SrmGOA0UoIgB" ..
	"z6F3pynItVah715EcdSnihwnLn5iRdBzZUnO1Sq/yBPazWuQGTpZbAQ3+mdvI89xDYUl0cxOWtmTb3RKuD2gP5c+b5xdn65del7z" ..
	"iWhucxjoOK01OlEIZJAXsR7olNT697w84PZMkS3jRabPn9BitUl6rbfxfi+tEg0uLZWnj1EuTv+qYmT0D1lj0oFi8FKywzLyZ49E" ..
	"qJfESGh8387kVSkHFAs1z/v3JP9i35ktVHdGp5gxWWB0kpeosXdIHfOeC27bCzRiQHhHBFY26IKHnS+3azcbldQseQWIILNFm3oo" ..
	"qApB7cZI1rV0A1Cmn9b72G1IRB/cPJmxt1f5RQOMjf7uQ3k98JP64OxffbM0kn0Goo8hnc2OgoYk2+TKiJHPFBE7v+H+LZjGn0iE" ..
	"LZCiSTC3zsI3Fo4zclqTmwwet0GmM6/AqXAQxkzChP2iljHitV5KD6naK5e3URkwFqyUuqBMAPZwaWCjb3BTNgQuCtVANjLUWQcG" ..
	"4Jtt3+7hyHUypqFLkvxsg4Pc27Rzt7oyj4Z9E4v+RRYJeOZyi9cTl44Eqwdowdc3GFqlYuqUjVon8LEdKMA8DHhI6ELOcn19L8bW" ..
	"LQu7aXtm6jnMw35Ur7hd6jcwQmdjeLCP1A7iI8fdF726L0nYKiEtqFfNceS8jxHbyLN8Uc7SWxRD7w+vZbNG+znYuH7srysNS3eD" ..
	"VUHDr3vn8BPaSBQTlrQYId+/VZnTgmXhoiDH9sKx7Ge8SnGr5nRxkYCKgI29HDzSZG4YrN2smBzgjl8ER/k9lViuV+rAYELQdSRQ" ..
	"4Nhg+bM93buNfFzF+oZDk9ERHL/emEbmkCuxL9EMlacDhqp0OBMt+UN3fV1uzn91qyqiinfOloflFC/NcFYriafdUdqyXkuZnTLP" ..
	"dQDl/ExVgAuD38BAWM5G8BsD+5DgRSHLqjLcZ5j+aX9pwbY0XMILLKtSzQ4b+0qutBwkAnI2KpROfEDa0tbcAbh8bOSIHvMj2lUT" ..
	""
local PAYLOAD_P7 =
	"QGXmqFVQ5N4oSDmdsoebtzQ+G8ne+2gLScFmzoDW2Ul14vopK66iEKrBOywry0ZHm5IKDJ8zaYbvH+bQflAJFArwJK2+5QnSzMqi" ..
	"3fqWHWHNILLgx53dlnwD8Tqh06m81dRFZXrFgdgDqtxA4B6CmHc5HR/SYqZSjt88XPSHYgApKlrHQEQ0hfbusD9odJFhtLj8dmP3" ..
	"VToL5iEtwgBE4bydTtZxCWSBsZjT+6RZMlyQcaGpRlWEY3bRGOg6ttH6N7Xtuf02wLDXl1HekaSZFaC17FGUUbcPN8LkZH2mMS16" ..
	"BqXqyXDVEZ4YzTFegKM6Dixp9an1MVPtd9BSJQ37qpkggnBCqIJZisKRpZkh27BQERKZ+m15Ou+odKA5p0o89ALlaETawdKCyUTJ" ..
	"WhD92ecvWeNumObSshFW1UUjAvKAeR/wlekPduj0mbs75cZRVFFCR3u3EPziG/oJxtM4wjBkLqY+fw3KNFbIvw+NWGhwXcUlDkeu" ..
	"Y8GsAxY0b57BxFkVMwoKMfdP8/iONO99rCElE0YrKjI05mjaODA4A2+93sNOyu6mBNgnEaW2atQZOA0WLJS1fzWPySsdewpSVeOe" ..
	"vVYUDWDLw/JHTCuXxY3UPXzo8W2Kua1adXH9m9dxSsqHqLZBN1Rm23Z12ItbLY9DROvfDHhkZ8FePigCFVP8DmBHWZ2crcfK+7xq" ..
	"lyuAjbJYfGTEJsVUP2OCzPmx3Qj0e2oemY02QPjmZhET5+H050APLXeyHJ/XwJfyHBPx9PaIdgBtT5G9C74VgrkxuED8rHkuJBM7" ..
	"eQFDbBgVNJESi8zb5CAnT1ANLwZScCKst/5UoUZtBFPyLy9pID0/yRFhV7e53+pqi60Tfb+AOF5BBhP00sxxEOHCUEGqLxtc4q/r" ..
	"F7wD9qq6U7JkUCfCIODkV0ljH95D8bS09jwqo8w9GRhLLiH/TaMGWazhtSM1ddrHcnLyNhyjVhMFYRJ5dBhfqH9ansk+v/mivFbE" ..
	"0kB19S6K5LxVLxnPqBxuvW4WjgJUhySM0olxxiw5rzeBDvoMz4xT3uUpDEtWOre2vJTOHzEjAGzQ6WLSCajOPNcvT9gEOn+qfA5O" ..
	"6P/pLFQQkEQk+koVA0zTqtP5h/+GjBeHW0Ajh385/iEMu4BnExNJrRJLVNqzzc3GQ50GZ+RYdq9HK581ULlqSypCkAUUj/nG/VSG" ..
	"m81kyuUaMMu6MQrDGIPneWhg/KfKliDTBBuLlByT2ZRXMRXOew2splVGq1jl/lpv/IO0689JaLxJ2mS8IIs8abKOWdUaUl++ZX82" ..
	"Ft9Gvd6Wdhs8vVJ7baFn7E6WHTb1dosRJeoIld2kJExdC/rhByVJzXOuEdJLneUIK1pD0s2Cu5/JrkRtLS38vqTb8na5E9tHm+nI" ..
	"n1HLrFZb185fZv0XzqtaEQRGeOg7WBP7cgkLPEXtaAs6IeW60Re6TxzJwbjnIbjvHDKXCshSp1vEgw9kwFts7nqyJrcXQSBlc+yK" ..
	"3ig2Ll7WbgSPx7Iou8EQswMu/QhOZQUpdYhR6Qnuy51kqPnJXA5spX8lSBfPFehzGdmkOU5xCQRmM/payCaDT//XBGn4QgG6IVZe" ..
	"jxk9eVOHDpFTAIYce2hU1teH35hkz4rNQuNmyT9lA8VNCWnMl9faQNuMxXhdWoMUBRgXLd7IuuJgqVhBzXCmcZixtSwtRuS0aucV" ..
	"FMrZ5vamhLp0QoQYTucyWuQXDngZusa3vLBipo5JvaPgXltIDTaeDyUTteIrQY3/kNGnhtq1YInRgBHdV7h6hb2TZH4Dnzjdi8We" ..
	"TIR44abHKaKATk1zCxhhk/cMjvFm3bOGYpyvzR7oi5yUXG+01SA07CMIriZ4HPKRknJgLnDf9zb/io0sMNWGxX1LhXQhzcCO9uu4" ..
	"875yVhaCxlwXL8FEXFomqyl6KJTeeHJaZXLjNHiAtg/lrQG3OA8wig9bdbLpSrleqd5Pz+jHAXGaDjhhKewvzUhURw+LtjVHmXvK" ..
	"jzhPQ0VUYeUJZH5UmNI9az+skBc0oUrl49MGTHZb/SFqz+tuUfKa1Mk9pNzHTLGEvKQJmskc1u9gZrYPCpzWnkRkiqgSCQ0C0b8N" ..
	"yYeM5eBCIPf/9Ub5LJfg44GXiB2Ref9672Mb8PwAV47SmZKA8d8/j0NFokqfEUCLCdnqdPCx7RCu5F4UZPlG0hZw0x252R/MHSiP" ..
	"8vjdKhN4s77IqB2yoklGpWkXzIetY16HKLXPMGLljv6qcHmYZkG0l42QtUCfGD+xFHKF4XnQyG0KIMsxSSh4UPa+fWeZ0YJmmk8j" ..
	"VhwuBuw1iTs9QDo+IyrWd6OBm5HFAX4p4m15efMrsAhKNigXEWmI0fwB3R57sbswSHJE4nb6Ebo42dvwD3wcQEhuUkgtlWhoENVr" ..
	"MPrnaJBykj/7yt9IGZ+sp/hSzvOIPQgQXdwIMjW9qbSDlMeoV1IHgGH3i3sV5E2RmguMqBW2M0w0bbcnzNq7lGhPN072KLECp43m" ..
	"7gCDxewKCdv6+ZWZEjs0vj8ILhyiV5xkzo0e7ylmEq5rrK+Jh8XppUZLngay/bFjKxwZkTJWQXSrOUyykVDLn8hof6jTI0fU8Czt" ..
	"Sfv5ubNnJ2DnrLo/BSuxjtebbNULXiwgTQOotdxQuzy88+2cv8r/bX03EIOD33yHzAjBgo++Ros5aY7V07UOZ5G5p1U4MU4jyIns" ..
	"LHvcvWHbBmSgKuEsWDGpKrN+ktDps+ClLsSC4sLeLRSK+1gbiiQJkO4urVGEXLv2sSpmroh+UmZoYhZbyM5Ah/aCEFyeyK3dadZK" ..
	"so32idKR9TTEAAWr28ZtxhIacVCAimcLEUZITjGtskjgduc3x9PRVCylYomaF3fEF5seKh66YIvcld1XngOBGhYEjhSwfGnaqMt6" ..
	"clfEy0dEkJFuqBDuxK49ql6dx2UT+hNXoDRzdldfkIkxOiHpEiHjLsKhk1/a6Xqs5ihHRWS/YdGv3xsDeJmSeUFgWEcVuKWtYzB2" ..
	"3nJjOI5AkWM0HkLdtvS7cMtbyUwNmoN8NWV4IdIj6DSpHBMWuqfzx4fe81yZyqw751FPd/1BWML6AkGOOmhIYPBQSvDA0xW/Xi5u" ..
	"baGVvEUR3eP4cw60WAcP7ZErnMcqmjzqq+zUjqYS+3n598T6DXRYSxALjTfAjlwHd9hU28/IXlhc3ovTwI/+K877jc2qHCpLeIqn" ..
	"Jhs3zk5wB1yw9+JCXxdM2VFN5z2WVowUA1kwdRYcOpwLTjiTYDj9lwibonuVnS6D8H3WLiiZDovipkL4NrRHfZ5Wix0iqsJO1wzH" ..
	"rupyawcXDPW0yYUx5KwYLp4Ox/GUDoukSThR5ocbBd/nGw9ODxgXFoOPemn+o6Cb9KScoIqU/++5z5midwvzttDXboRIT6BiX1vY" ..
	"qtEuvczVxsEZUhcXSIMFSGHlglCXNdDotc92cVyqED/70jc0uTAICzvMXGIzAPEK1f3ds4dpuGmhaJLvn4ynKLAH5GmtQjQiqT6k" ..
	"9S7sNGifrO/dR2ve6/RabskzTiiyTEDBXa6J0VxZgIkvoMluLNsKczfhPesyUVZi5HGeaKWEWR7ZphJT0QPzzAIGWyzdwCrwqdEZ" ..
	"FSsnDyiDI31mfGseZzN5Zob/5L9muZJTNxhZv5Ac0AxWlb9V7zMnh6TlfOM0keX4yI2JK6USC23WQ+kWVClVwU7X+sMCXdIsxl1s" ..
	"L7XkdCvWrlMUJDvro+OvcPHB9I2jF/7DKphqUFZKBB4iyH4o7QrdUjHAV9fLZ8BpNrKTzt5qM5pyN0FRO7vvFRXbDdsU2RYfdct9" ..
	"AOQnBk8Tfcl8us57VjHJ16cg01+vV2CxLAyeZxpHSCkvM7hCghN+rAsqRPO8PTzxyCdzguwumn7sQeR3jdEV4EhOwfuxoSaObVCX" ..
	"c+ilm7sIy+TXdAbyRutUti0q7kOM2C9OJLQIN4Xg057KP/McmOeFzGrg0Fl0cy+TfncNwcTH6TuU+qc2usDuCO6/xrqC963W0unn" ..
	"9THwtwYR2yY0HsuzAuYfKUQiZdLrB+xyfAKj35lI3ApeapTMd7pJvwIrlaGuvwyE1iAXy07hUBMQBSQTUNbTf7MP0twZucgpmane" ..
	"aJzfDpb57wvNl6JoAHPeq2G70Z63XknZJ62I6wYVX0MzTiujecv2y744WWiQHRxkkjZQHuPGiY2ZFliWbla7bsKTSOgW1LlDEHBF" ..
	"7Ee5kWtok9+KFv6Q3U7quGOLDeEP+IULUt09g1PSjGekQraprMpM4/AzahwjaJZWukMFrl7kjjIU424uXxbQ5kS6GO+MzXHgDIy6" ..
	"xieUbtf+C4Y5Gpc7VuYhvKARlbP+L83omnoC0q2bdLKkLnCkNSzPrIGUdqyOjdn/Gcm77vJE11PK4ekrQefJFvl4UU4hM5QBzubt" ..
	"EhjqXYe1ZDkcMONJWxw1VKU4XUXzmT2XWZAlNQcszXhyG6q36RBm2X5BPaZZBAKffBPTBF2KmkDPcIkj0H+H4tSUL6SPMUNf8l9r" ..
	"Aox6lX4Tnyhr74Wxj2tZIT76cl771DkQ+HknTtQHGBamXQ7eu8Tq9gPi0aa3HCiv4EWV626z+KOwP11gTqnxDLMsWxsfaC7J6qVt" ..
	"VyVPxSOMD26EYa55hgCyWY85rAkTwgnRvntfauNaBp3DNDUD+BoDTStbiaXOwu1Yq1oABgun2476LuFKHHwpENYG/fyWBNxuHbnJ" ..
	"pSd8uy/AgZ6MtEvHE6MiNp4W6dB9ZRym1RJZAWeRTr+CcMTc09KNFNeB7yAcqTUVCzb0b+NVfWy+mLQxX1PoFcSoh81zyPNG3N1F" ..
	"hYa/ywMJSKsnFLFaj26RpYbAHGOSe5mhHudPqHGIAhGW8RYVSfpVsbMTmMHqElMwvmi7qsUDZ062AReEbNSwNXq50Hk0qVI9tfW+" ..
	"EiarZszueuqhNcEhn0QILIA9ITguycpUouz0P1KeVc5mmrSJTgsm/HditE+cloPoaIF+13Dh0A2+mRjYD4qO9Aamykc43T0XJy9S" ..
	"TnyY0RW8v0jL5y8YUQTISowsLOhtAVfPHcmG8hJdAeYWQvbuuxrjRjZV243iXs/3ZPkLoS7jKeFZ8RBrVq6bHxYaBsMsk2Z60x2P" ..
	"iEdOeMdpCGtpKrFVXLs+FWtSIzdCM9qZ4q2+oU/0fiSnFWrP6PeGAhj93zl9Qhjmir/CZTl+95sWHM4ypY+BAhuQUinbdxcqUFf+" ..
	"srZAAN2sKsjyQYedkqqPFwL/R5y4G11EQa0aXFlWPhLf5ll17iLmtZXA1eGgg7cK1Dn2WwKdUvT1z2U3sVGHTbuQTXJAfG00Qorh" ..
	"895n6PxROZqTG3JaAHg82Go6rSEXoafd3qJmryvYsCS+1/RAJ8pmPv+tuH0O2f/w9JBLhUpCPMvZ+tgYcnGkmARli0JS8+ucUzTE" ..
	"2eHoB1Fa9glM2nPdPQN7LccBU5WelTDIVrw0QCfAEF9DvfQKesTgqYTHKXG6mopZhEVIMWWNGd4Vuo0ssJ1CtWFAm1BwsCK4pbjZ" ..
	"/dZPNtrr51ZhnZ0aV4kdfOFGYoxayC3OaO0Gd6/CsMSdwCfl7lR8ylP3FRsY8eDDktOkBREdlH3ztQXEFdg4eXgG1DFTbC7kF0iV" ..
	"gaY93gEVOTbVuPZvYdiZsHh/KfaCPc25Jp7NAIC48G9PT5exT9PSxFWHGAPlGo+4Nktx48Lgpwze7EQbsSXoJPgs44fYlPFHHfLg" ..
	"i1ADElnRZFriTMu6SSNldUgDNn276opMVfwHRpX10DeibbqYMYTua7HfktlD/Gpfc+Y5AiGVogRRElzJ9eH5KIK9OfcWs8PYD9y9" ..
	"Xyz19l/G5YKJSCgrKZRiksLu6/rWoB+OiO7ydrU0etDwmlC+q+IzYis4TtBxKoSQ226xMmXitFDXRh+cBkIKgdNxVbzUkSy26WFI" ..
	"po8mfAlF2FQgZgHGqnyG0OmxLylQQxjA1jYe9xgrNt6FhyMBf2kvvGBwUzWuHrpv4iL8YOhiGftYfPfGb2kjnQPap0wkF4FFSmrF" ..
	""
local PAYLOAD_P8 =
	"qhg2TlBo0BOTBcCjWzIDIuZzkQjIObQ0m2ijvKcQD/UNmao7WP/+euqyDcvTWNeZJPgDO6INhVAjLQi2KPJDJF/t4De3P24UhyL0" ..
	"XKkhuHAk+g5ITFqZr5kIU1cxo7zMPXrkX9H8Hi0PXhNaEA1dlaIb3KSIiNL7xwH98Dtz7681oCOCKW7NqtBEU7LV24t2qEkUUm6G" ..
	"ZjxPmaMmtKZ3TbQCC7fx4jB+eoteOZzbi6HyikMotxs/vtkcMNeD6TkmXLN93mmsF947tZ4XOSb3vjpsPG5708LBl7FfLZV+SDp8" ..
	"KooHbH6WU9SHHkWHtHg/zdRq2A8QB6KXt3VhxDTg9mc5HenxdOzLn4q25MemJVxFBNuB1x5s34ZPb40y0PRlq/aJh/buWTtnsgr7" ..
	"97njcy47WZpWmRnGgLSuupvw9kl6d3U/0WCz1d9z7dOjjIonnDWApzMeeeCG69xJfwkDpNgdUfa69MyR0X9Uk1myZ8lh+rBFftUX" ..
	"d4j175Eld3w3nds76VmBfbf503pqkbsAtgdT8TxuAH2cLpf+585EguCVoh/rgx+tYHXLEhRUZuivdmwfGhTSI77VYEDcCYU3v99w" ..
	"ae3OD1BX9IA7dfG6gFuJuRT9MTh2uZzzzMh3c6mS7ytFyZ6Lr6HiioVS9vNLYRWTTueOI3ep4WQvmrUDr+/DwlbOS6AG4qJGqhFX" ..
	"IduB7GbGb/p1X+aMpvh3Kdft/YrIIIPv6gqKMf+v0NFAQ3xi4QqVskL5HFtlcvs5hVmvwnbSBC2DpLkypMMy3GHh8Dcfqfi66HyD" ..
	"nACQNZJTmiuelyMso6N/whlPttL5NFzwK4v9Z2JCdejbmKZ4nSbjXUVPkmxgZu+LePny/shCn8mg8y3kNRxXhscjmouqTrW2knYr" ..
	"2Boy5SGu9RnYKQGxUOGGazNkoMJ7l+agM1dA83Ykp73mBRwXSzb6L4RcN7ehJ3jpr7Ttq5dAiF615EZf0nZWdLaOWV9ICgO7w5C1" ..
	"yFVc1tbXGmQ/mqc3moikVZVKcmmPkie629I4EVCcyoVZFzPqce6lklig24/Mzl6uUvfNM4qhblnvtnWUFCvjKNo+U3E62BEa1nCg" ..
	"bSFpQeWLxKvi9uDLbtPX8zHzRQ3wxjXxRbSZC5wszbSNohSvfuDwR6s7gahqLmsIMiOMaGl/aP7H0exSG1ElM8LE90K+VaWCW0nL" ..
	"KCKnZaBlX/1sUkDEbyyID4gMor9YaF5MbnAAY+tHzMfPHhPgivcR8zH/qrx7t69dYcwrtFdLaKVafE7+uSVaQ6+DAB7uwmY/zEAq" ..
	"CtwmzYntloo4E4JPsD3etfkIBztIAZLx37WBsZahmKTjHA1W5cIQTCpQ5qrOj5JDHo6XRdFDJpBYoPyKFYwgEMVnhynGF4ryiyBA" ..
	"/YTBMg86L6905/V6zF0M3OgkZ+XMIPLG2TvVtETQVDoH3NHXVOIIf8LJH9DY70hmHtr44hs5mLoN2qGQPI5euhijdEERRSVghl0p" ..
	"b9XAUqs3RGe2ViXNS1qbd0cwiWWjWK86f5XSUn31g+tXmPbtA56+Bbl2K5c5yQExeXxJWGQTesUcApQsFvvdP7yWbEQXT51VeTlp" ..
	"64ZzOldQb+xctkL5UYxIUnLm4Kd6SUGhs+9eCZPxvGudA00k+ZzmtpHnMbtyxYbjJS+/8P65xiqhHOiqUvBswCnYZcswBuEoqKwf" ..
	"LsqC7UH6CPHb+d4TmN0s6smWSbA/9KGdVMMmra5KLgAFUpr/yyzcb2C9ejtV3+rWoPdX363w2jnXPkNRGvB90e12pv7Y9Re8bOAe" ..
	"l9bpl/a36Zf/I50hKrCtsO7Rs+JyxtVr22ieOByxgHaV4L+/nGFTaFjfovKbkkGwUhNPS+VCxGxvnxzrua2kFGucSYLqXcGY7SIy" ..
	"bLBrwGBnnjHBOs24eIySGNiYayVW5JT+KmzJXNfD7uZgqtarmJ8ieCbDBupApDf1y1s1tFCp//OzHQlA0YYenk1B4Um0CQx+JBsY" ..
	"U7EkhyKuSkQEdwtS+HJ5QlAyNoj3gs26fz4lPZNNGq2gpcstArxBmLou9BHq3csh1cUO8uhQ6z/vQ5QaDSobsKjW1M/+rWllhy/H" ..
	"+azhlyFCNkEdLEPvbVYVU14PBNmIIPFg+m0u73bZhcfCBptJ66equ+R0GDGiztsEBwT4h8piVgAA973ABZX1IR8MSJOnSyLRcqqg" ..
	"+yReOB1S85dAOuXjC9UEVE/hg+NGHNwitxyIJcRRbK3pnmFCVKTwTWkij1/x8Ub4CCw106Uwg+BvV++b4vR/sKBqRnXMQJrTbUIx" ..
	"WVJv8La4be7VhTXnFvSY4FCtRV0vi3xwHfYh1Ed8M8fQiUU0g1CAPGgMen2QaHa9ZTF8Xv01klR/Ot/6HGMu5VV5lbOyCfsRB1+2" ..
	"dxMRB2n8clLTms1TXRKhNvBzT9d9HqDV4MPuPkC3t6b3ZY1z9CJPUTKRh5F5R0J8aswUa1k1E132wQWOC8KkHuWI7LoqkurAXJlh" ..
	"e+ush+VJRgQBvEDUQls+qNTCP64pQ/OkinCEMFaPRPc3rOAO12pCQpFigIR4rux8CUnhgAXaY7WEwYiSlmsFYRTXFT6J8Ae1niM4" ..
	"QNPFKHR6HZAKTNqjMouBLa3DAKEmm2xDmdVVpVHn9s+SSdALiOQmyKuNnI29SQcZaciYNvqqnPScHq/K31syh7uKMevcvU/S7Hof" ..
	"K/viekF7Ak+IrAu92PiCXtebBahe7fOjMfyyZrR1kwqXn+tDU5KAhHnQldpjX23d7LWDJBYt4tuN1cLTOVBMSxb5Dm0vjZymbYzH" ..
	"H1aXT7/JrIC78bqA9NVfDLNm0/aSEDrpY3opl8HoV1OGHdi8H7javK5CeJquEckfMC3vwzeZ4zs3JHzxsaJs7QrfaMgYwlnnAVHr" ..
	"X5YaHUOBnmPwJZZPcmRrN8b9pNz7rhYHWeBF/9ZXagNA6xAa6FGc373QHjQsV4j4Y+wYAraarPpOQHlLLWdgPrQeYT49NeKuz9pH" ..
	"G+Nf6ksvTsiO9Yg67KKxgtQ+NWiuJUIvIaIZny32Dj5JGxON/giIaE2Xma1fG0cUj1ILmlB518A4O+AiRZkflJxcQjg34sfihsDY" ..
	"UFIw3uLX7QpKqfX2Ts1Bf+75tNqI5xr5qpTSZuS52X+maKgUliHGqUJjUtpsPXD8ycAi2EjMMNbrFDW1MXSUvzmN9A63HkjH9qsL" ..
	"GsVpcI5Vya9ESNj+Almmcnq6dInsBau5D9xgEdPjiauzsbGyc9NKbz9vjzVcjIGV8JssY2M1RbIhLZtngXqDbWk/ALXud/Vq9pMV" ..
	"JF2LXiMeQbCINNUbHVQVypFXimJDViFwKOdoe7UTzEqUaF9PGeZaNl3mV3mJ5njzHhD2qn0bvlFuivdEbaR+FvENUB6d0zUaQYaP" ..
	"OctiZlERfkkXJP60EYChbnUuDXWr3c4Hnzt0LkQkBQrphR45joHuHySLF/zOEgykBU8LfT1H40d6Zerzp2RUFf77F6qZkoZtGeX6" ..
	"Fh83a1N+7Ff45zWd7jUXsQ0AoYYGlw0wZeZJXmr/EeKghkW6t/ap+06M3UuH3Ht5s+GoxKeVECRUoU9LGstHI7GQDbS0P/CD/NP4" ..
	"gi8XmS+5y/To4m1U9XgAYRGGNFeBHYjrRZz+mdn8Fbbmy9DFpGmkDosX8Q3DgPEfoc8k/s1PR/jdevZs2aBeEG3BqFQ8JifimMNh" ..
	"lzn8hQ6JAN4m4/r+zWkcG4sPnE1ygoY0esrqQGdI65chXtURvJZ8fLVAzvxTekXw4AuB5+VmunyVY7ycVVa8dWfPiZTVAsjLUhNr" ..
	"Psek4wmTpwb1QCHy3FmX8qyacARHFGn4e8TP55ShETInLIRRdxhxu9yIPamVY8uA8ptCj4d6SNK+givLSOQxGbdjjakfvWHojYmj" ..
	"ymhBSFJ3rhDpqdUGVZjGTMO37WChdFzsnXX+8ccrOluE9IF5YoUfiG5jCBFDgU+Xlh15MS+UPB28Z0rOfFi86NqZqz+e67JkKdxa" ..
	"BIfacUdRuCf5PzZ++sdhEAkmqVesimBLx5JALxSbdxAAXjrP8vxpeobUlOBJg6qJa7XSIx5mcg3aGvxm3+6GALzM2pCMgI5JCS/O" ..
	"4T5X1JUbdzE/JL6eNCZ7Zo/HXpYZ+osfoEslDwcgLF5I2DSLMCU+EkzEODNHriwOS2GYQ0f+L8AZmeCj5wI+PZSuJuDfvJQTznuu" ..
	"Bi+Qv4q1lyfh7I+1dG7t/0IlY7quojvc6e/3eB9cJ0FYCmkBppQ4yPeewtiYAySa6lMfzof8xeY9JGlDiipjkowCaixZGvnrJQWX" ..
	"11+v/JXbJ/o8kXoBub843vGFI9pJPBMhJqkUjYLxRWDyXwlIMZUnFMePNZFljLmI8efIh1Lcgw/u9rE8V/8gHB4ejDDia+LVwE+S" ..
	"+0Qtr27fvajSEQYOtpWFS2gimxghr9bFYb5DYV1QURfDd0U7WvP++JhBk1RGj6MUl1rGlTqUnTlkLlAZ0gXx6RjBnvB8EhNoI6FV" ..
	"3cwoM56rzLUA6Uz91ZlHldo+1Rbh32CagzgvqPdidvb06r7Ib69Zie786pbq/UqmAShiKNfqQ2A9chaiuxpmuoVG6KWYqLCF7zZw" ..
	"s6MfSXP3rsOY35GGKyp02DEP8voz/6mOhYYFwdb/AU74LjcqX/2ruvYa/NKG0HjFnUuU2ZBwkru440xN8qi6qGtPtH88BaL7DNv7" ..
	"qv2ePapFKUw2JZWHjMBGoNJW3ooyONXFd0H7Z5ywX5EXrFICoeNr7tF9dJdbSboRL5P0r5DaYvaPg27ljfupQ1RIlBPiHXpubNLm" ..
	"iJ/Mcgpzbk/eDHrqOOt6Gzqd/Ol/F6RiJwN/b1CyoDdJZxHzT+AtXF/33RfDEHvGNpzHHzB6BdpbEnVHHn6pjxLXMWSIX6sJO4+r" ..
	"m6/5w0Qc8VmtPNSsTHg3morHpXXgAb2K4j2p5le1pWwdzS282VGp0up+NHRvVr6jCV0kmZiCbwbP8I6VDrGtewlwQ2+bPD5lLWc0" ..
	"tr/NoUmscYb7mkFd6/zkh0Y/UpYpPjTZjvtEJIIVh5+AB2SeuVSWxrUcWYBFMTcptwRD7EAGc7uT92Rhlj+1DZKG4sDBKushWRLX" ..
	"VXY9COJ2ijAFSSKGoh6AjGPCpajxB9camgXzWPg1N5AFXm5xLqolupBAKuZ6hxuoIspkzzvAE49GrW3GqSixb/YP8zVlC8/k+m4U" ..
	"DFEjjoJ5ws5mi5DVzX9Kah8RolWj9WDkXm0u2iGyO7wUZHlk3vNlAg6DH13ts4j6mB8qetQJHEDS3fN3kMfxvW6M/sRSPDBVRnnr" ..
	"iVNUgJPTav/6VtD2Bs04w/YgcIKvQf0ed7SEYGkMLK27dlOxuAQOB+gW1fXhod3bPedRh7pBlkBscKzmKCJhwxBml3huFMX+jLtb" ..
	"nwTtO2uQD0SFvc4guHFDRrkvAFPRN3OqFBjtLIfvleZJzjNn127ZAAEpYa9liuPw/3XuvhQ5V7+0KCvQpZkBjJvdASjDRV62KcZd" ..
	"Hc7cWLaHtblCVLjYIGs350Y2EU1zrVU3V6ReDkuuc6rrx5+SdMAX43BDMfvYbWGwBsOi99LzNu4/VZC8srY5HvyymocdBpPLbo49" ..
	"oWxmBtmxuoUCEVNUQ82zLeBJRujQCJ505IbgrsaGDlPD5XuoCAE37tew/QyFxbL3zLMDRY8INWPXrtb2zZpmdWotXTkLu5wwffq9" ..
	"O0SmW9/2WQgtJjtuqJPJUnFuRNCa66Bas/Qg9kgGuAhtduXbpJsdUiul9KxSOS0d6CPZs4rvSEq+VrHQoTTx3+w6GEppN9IInfcb" ..
	"2tsifiH0DY8S0AaOWjRIbn+lqzCK3D6z5CfksqQKPBBpzfrrahI4BbK72rKYSFSjst7eOlk36FUH5c7dgKnibVh0d1Q+I5oUc22Q" ..
	"hRoKDOErwtiuyiV3ImDXnt6tCfgnKZstxC7IWUv+FGzY5bxFBtxergvGRV0z4ptVtYbDwTpHa33ndpVg0pQtrneREjJ57+jWJLx6" ..
	""
local PAYLOAD_P9 =
	"SHMy2js9+26DxpidCGbiOM3R5R6AOZSfhuqz309USQsQCxt+5L+Dz8rFJxByg07oJ5y+cRW+peUN+AD60R7MboGMKTCTCCNE12lP" ..
	"r1hCIIn1meh1diHQXkquaVQydU5AfcXz8WOuW+RtWjOUAKLYXPd4hoQaaS5nU0IlCXGniVTC5mMFmnsx3WjELXGbrCapPiqWao8o" ..
	"nhcH/tRADnHWtMckbcqNcqGmw7uXSE2AI6EtXFX+rTTc6S4s+M/1vT+XXTHusSL8XmWbzlPITMriU7ViupAGBY4Ukw3iiYs0PG0Y" ..
	"Fin6uOmY40khy9D5m5/35blJANgWlIvqcK8LxxL1Dol/TsMnPO+cIEGksBHBIdhzTD5twfOXpJs6Kb20rm0jjVE5oU5j+ui7oJB0" ..
	"cFrbmqMV36bDbtOTbVcic6c5PxX28f0PspY9P/9VINlkZP8mHsEWkR43s8pdHaYdZncDTBeaSFqkPx85IiLZsTd1KavjNR+5/F8p" ..
	"xqJD/qEMuh/5kx6V8Y1THnxbcv45mpXp1qjGytfLOojtWWe1R55UaBCexPmCrTDh+3uOFrCo2BMFcG2iu/uuRT/n2emtdaJRV7Ev" ..
	"qOvXGg/vMG64HJz33cgCjOr7JROmTJbdh7F36nybGUdlBVYRZoCJAfvcEPfrwsLVTTAxKhVHxUQ5Qq5qkzniX2Y73r9M02p/0fxY" ..
	"RcKLMBDvVz0bQ02mWxEpegGr+REj71Y2USd63AjqM0i/nmqIdjtWwKAyn+CDsQCFFUKbBZYpEcivUm6VPdMxrTxR7V0p7h6j9QRh" ..
	"Yw+erfkSEhhYHe8gtDb0OIpFRj4jDKQ17lWFyk3L6JMtaBSbvRGsQ7fDC3m6vunEJiDAFtuwW25oiD/8hpaHZknpAiSvgsxLYdZ8" ..
	"RnjJ0BD9VfMwV2rWx6HKOkkROOUDRL8nUp+MCiK9yGUQsaY1zbK6j+v/qoVJEGZmBZYaWZJX6jLcagcDxBOylAGFvTkpT9tFTsoJ" ..
	"TADyskb3PxLYMIZZdFKzLLv5hcoTWDNmZhcL9wLg/rdXRxnLWyFfpxcfMo86BwJNVu4Cgrb2QdbgTn8XidD4VOZS+bOFgorO6ntp" ..
	"jA+rrUPwWq0uAv4Jzi5/f2advmp31x0eaf11oeetYYV1OpW8OUdi/5RbWqE0Q9skWBZY7pTdtKhbpn1lcmw3rXSLSff+2HcxyZ+1" ..
	"VshFNhW7zQkprx+TOFuwM04tJz9r2u3wHU1ktZdp2rc/slpegroVN8elZBH9PKBGEkBOr+Ek+6YMTighij4gPjURgvIGCcUI9q4Z" ..
	"bM5JS3izSg2nEzx4ldayRYHtPOqU9w6YqFhgGqTwS0n0k8xU8SnOuEoa/5i4YhKQVCE66OSQ2YyymGruu8v3d3hDshpQyP3tf6VP" ..
	"eYwozjmETJbsvH+xIlnZhJOMYGUNLU6y+ya/FfQ1uvwhSqWPRm0Gi1Xum0emNGnO+Teorqj76Uc7/ceaza2WunTJe7hF+KJ0NnuQ" ..
	"t+DKXQ8wjRgcWAxYGZF6gYgwaxdTIHhve8QX8SiT6oaxqQ5+FeJVB5cyGLknc1TZScogdJOENu+ufmbLfxKd0qNfFfy8kne+ao0T" ..
	"O/Ixw9HTrvSStsjakMMUMrLtwew+yTrrL92g5ua75LFd3cqXesIIkRYxY6OHK8x++bLMVbMQ+cygcjlPRgL7KvdbIgyxXg5uWG8n" ..
	"LR+IOwuvKJ5JVks0LPh8PYKEs+KlWZX3z8KU20S8+Izk4GmwtZCXWOK/ls0+30biDFC5QaTKVPAlWzyd5aHfZqs5ODQ1r7pKc9Dm" ..
	"w3eCRAfiIAgdiYLc+Knjm0sjkxy2EzVEv22kEwIIH1OEWpF3tJYPnt/jOjlFWSu1eXKi5Y0P1nOLtue4qSn/ogUn26FqgBK0T3Se" ..
	"S5bTkv6d23FHR4xsxX8tTr7lXfwKIcKR70P2xEbQjYbuozYDZgwik2pibh89sO6S/fq8w+CTgaakJ4gVN7/LQkO518Kqtmt9LQhV" ..
	"CilYucCjmHZqqOE1Ok58CoC01DmPjN2SfwHmRHeOSIosLT1HRrukJ43HbqPqT1tceQqnudYPAFR0AcEHM4fQP8DMdEI+6UX6+Ji1" ..
	"XJgcJhze8tXxi4r+5TwAw4c/yJaIubcreVMBJR7yxrmJMrEJ7qA=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9

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
