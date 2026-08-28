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
	{ seed = 844640115, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 840978277, exp = 0, plan = 0, hwid = {} }
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
	"2oGXlQayQN2DfU1evzF1m1bzwJW7Wv6umFRI9eivmYaOfIMZykmiqOnBVGsEogPKof4AWBCnlgoutsw4E9K6sx+1GTDJs9C6SLC8" ..
	"NQmB5GRvBoU6SOvGkZRZXm0xWOOpkh7ubHrILKWM2lOc4w+p5+3PzGPImv+7I5o8U3GqxWJn2NxW2nUKO3v7OTFkTc7A15cPxLTf" ..
	"JsKrsAKyH5RVvM1D8loYXr68fjjPvzxqhg5XCa3e6oPuUE89TbR9w4MchZ3ZwwFskcYkB7oREjWdzcQg1IgHZjdiuMylgFoycjuh" ..
	"mDMBcmxPLkSMO9bOuUiDY7KAX2DVUOnhdGcq+gdy4fWW3PEQQuimhHLxN2j1THa0kHhQ9OVON/o4C6g63NaDhklHCZkTtQ9aAgcH" ..
	"174fg0owb1bu22mVai7sYqfXigyzLICpwjwNW48+hSKbjlXGSypQ0S+4UZlpKs156mw6HOY7u01aopNPZ0g0Xd970ZVJ9hckPs6t" ..
	"Oq9Sy+kwaKfpM1zhmv++MGlwulhEgVTVnKbarDIglbYke8/+BQ3EbX4Jaoi97ztOgldrzufTz08QErJ1c06uvKGaCADOe9Iri3eF" ..
	"kwvhcy7dmprmmPJm8rdiu7RiDYE0kBh9iJCcGDCkj3wWnKepmjrpsGbclkPISbAasTHTZGxVU9Bf/Wt5o1ualjYxiQ9GN6SbmyXg" ..
	"jo1gsiXaM/JYFWh+5kM7SFOWKsLQfVZY2xT2rOKzxcxXD2uAl6gymUnL4NJTQKcPvcuXr8nVSTx0jKoHvKS1qRSMMEb26GjoZFTU" ..
	"W+xpQ1uqskyqpvctou8LTL3iBZQnEjOhNWfuWfjWjzM2zl/9p2w9rwpizhonmtaS4j2NE3uFKDl1vbHJEoqBcj/A/LulPqb5tNP4" ..
	"hpeOtYtQX2tkcbk5+H0vNtzs9TjOc5V8lPKc2DbP/mTAeVwq01i8qgVf5Z62MILI1eCHNqgo9hWUVXvxdLp1qcDOzyn+jxGD5p8u" ..
	"eP4N1JLaD3R5jIqIVdFzIBGjzoAcW/pyUz7ejSz2FuZG00iuKIEFHP/kh8pPcWrltNLbPETCzkdaIDxIZtZGbp3AFGIqu0SUUnnR" ..
	"ZutkMmFh2pOc71X1XLyh3G4gWvn5WBSByjZ0LFa2EE1jMa1YmheOnnSG7v6I3rITHrNG37Mh2ku4uAahwj14jnXKjQ8Rs2E4JvGh" ..
	"PWNe1LaD3wFmqUlNwI8CXQ4m3goD4vS5Zcom/KUp+zlSUXbD8hw3Rp4YOfqYhbkT/adpQWRGkX0TewAmdEEBpjZi2Hig35mvRgN8" ..
	"31Jr6lJcUkTzCO9BhY74YDM0uawlH4utnheE5C9jOP1mMUI/vTi9q263mEC0vPRq+s4IdzFsNcXsZ+1Ao4MbzkCxvN2EHo5iIgAr" ..
	"suyuexxBZeSCkKdG6TaYlV4eAeOzh6kyQex2nhb6QUjncAbelc8Y82QAvX6YbPsNgDtw+KZis6LQuXk1T56O8yx+0EO2A9X0lkl/" ..
	"8GfnVIzHr1KUSrFwgBDnDSNmYU4eqJZ75WxM0qUmcIVw/zpo+BGGgvXvo2zkiAcHaYwXXkVlKIRUGw2RLvqcQ6SXmCtw312jhO9V" ..
	"HHNB3alv3teGWc8HNg4Yw6eHqDBkAjb5dbgCJPKM4ilBrx5/jXRuflRjKt9vhz/0oNSsQPYA3voo/cL6Nh/KzkIYGJpPKngoEzOr" ..
	"p6WMMvg+gZSdgmwBe/sFcOb/TqZd5YEbbqBspX2feABvI+Y5KsJGhFztw4DI9Uq0junszPD1PUJs4sC6HLREyOoKzCF/RoPTu0H1" ..
	"Pm4+xaMbWoAwtgJ7kOeMwF4mkMqISu4ietde9x15vXFBF/AZN9vP4R2kU9sPDNT35YOKHS+v/2DPxkqL8a5p4O5YDDSiaBpe3Nam" ..
	"nU/LiwD8Gq1KtkBIDPPBRtk1hBC+ww0VARHJb/2o6e1kl1+unkGPfAEWkV/pvPk2PJmcFNB7R0hx3dUMyctOO857Za+4S+ZdPG5Q" ..
	"gd2KDgjAMoph7pL8tzh7Jmpz39M3gIh9y0R961vkQ7OqgsEDddBf0oLCaEpEqLI40S67JkTdHNmgO7s+mhhShNX+gLq+qB3V0Tou" ..
	"LCp7cKGDajC6Ns0qNKB/siPMvqDlBFqX03F1ZjYmGZeS5NeglLQ/Y95YaTslH9rKTDjTM4jiQHg5XY8fFRqAQieBa1mveT5koB2X" ..
	"//ZygvCseavggag0Yq70HfnuSoFGakQos8wuz32WWkqfkX5zD+T7Z1cYoWMV7F4IUlldltWxIrD+8Q959iljXsCiXiTxTh2O1Izb" ..
	"Fs+f79fSkZGpMwNhC5Pu/KCvSpKFj6lVzqjhfjX1Cv/jOk1mqVDmA/wdE5ve5YV44EANxo5dm2LmqcWlOir4npQVBQc7R4XKG3PE" ..
	"9UT8OKDYOZAqBcKPUZJd7v6hjSQI+uUzYVdGKLPOk1P582ITIIhGZzvcykAICVospqgy+aVeuskXrSlZn4JowYxge+XGOaI/QQub" ..
	"v4fy0CoavDXoTFU5sdePLegrzv/d6jts75sMeAMPv1TrMQQ2D85Zsoeo30yHRfgbX0LUhPMNz0UKd84SzKy7MzhUD9wSGfIqUQKu" ..
	"uecWj4vOxYLL/UU59ro4WeOyJNU+q1Ibt+0+qwin6McI7oVSO21ahdqHKP7AgSlRO4ppF+Rnz6IdD+HdPFf8mNFH6hb/tavSJfPd" ..
	"nGvb4H1C2VyQhKIunpCcel3SOkW9JeuSAX4yTkatF3BB0CLGaww6Q36hEZXdzAqAr5MEumclxuOsw2tm1LlpOgCyUPFZTNFSWmMR" ..
	"tZ2GwoKFHBTwn2bU4U7nXnRAd4/AtlcQieKTWGAcrs8gTidD41cCZ05LklPblYQ7Gtos2kMpvjO5Gg3deu4AiJf1rD0zaMlXleZC" ..
	"CjI/A/8U1qXdhh1atTyEOlWjrwg7LNgt83YQ3SUvI2zln7pARuJ2M8B9FBqUwmBqI1lfLp4azhtSGR5YvIwROh33H84NzlXiWRcJ" ..
	"/ORTxJ9rEDsC9CjSbCIrh0nrIP3RreiNHvdUfDI/BIalfb6/UBme2WLYjkq3oyTDp6wRl3Md5WN1u0BJcFrxg2cXrNjLl1qd+aYM" ..
	"Rcwbh+mYC3CgVXC3cGnYA0Kf36peKNO9KFfxhPZIowEZABmZjry1Pi15C7d4137otaRP/2nkkhx4PrW4w1SN66ToYxXDpvu78NEo" ..
	"t4rSHk3i0colajbU+QMx4OA7Jyz/9L9oLbiaiToytb3R+UlX3lA+tlhF/vQ5KCdcoiOOW4VVbZ7k4L6Pj+LTS4AFVFolVRHiJ2hn" ..
	"alZcvwicoJf+Of1HnOXQuKoYpxe4SsLc3BxQcIyCaYq437fUCElYMVtWQdEZ6XfXQum/9Q7bNlotHcnKXn/Njh+q8QdikFlmtpIl" ..
	"iNLcn6GqxRvjkqLArmWpDGdSfIzptbQkzm4laKRRPZXBXMTxCqipNCX2te0kHtPFrnS+hxjTmi6CtWDed4FfZCTyEjSp91tFrkyO" ..
	"n+UPsVQJFWc5q60NMt8sYz8QTFg67mBgXHeCAkdMr1WuwaeF+6orpsP4HeSZxFjBSjcuLuewcG+NHItH+VAmLOfp50wGtW5a2YFy" ..
	"zerx5kXoSVm/NeDHV2xrfHzRPGATtLv/YjXzHMU7H9yeG/bAI8/0PC+8k3ND31AqlZBObHy9HRs2ctkqxyy9nIiAcQ+bLriX8m/l" ..
	"SRAHDtzcdsRbMsguYJlrI4M2HiZut9mzyevhk6tZFgXnyz81YQc+eQnOTl/HHnIaX6kAqWO6sDJrDUFAOwj8SeQcbPNOjoR4MwpA" ..
	"kFhlGOhKJ/9yYPy4eT5C0+g7S9vOq5s7NRQz/2VhS6OZrQoUSowSEpnmSe5UScIB+xUfgNT3/keBJwE9gm+9sTvfPP9mBnri8N5u" ..
	"cDJw+j5INSafy7QDyjWCqRXExOQBiuZpjRmRtOJ/M6A9pnKCQ72aIRJWyNnjqI3qKYbuLV+dMBmjzFSJRuBWCOMfxwlYSs9Jfsdh" ..
	"Bl9nU3CpYWIFTMo7P0jbJoy+MYK2eaDZqPsLWw/mdfy/8H0RXbJuSmPgMc5BsrFfvHJ01C9qQkQVWdciSmjwPVls8CS5P0QrGwNp" ..
	"lk/fHCqGJPIrE9KBYZhoMh/RGuLcSHTzZQLJDCl1ANsBf0GJcSu27ogRp/lQgj74OwbIN3jd8rHffSCdY68/QGJQ5y7POgBHwEMX" ..
	"Fm1XqnXEr03pjXfun9DPHUYKRjtEai5rrmKHLGZnPATvNgQxU9Bams6PkIWXaRsymNRx8KEuVKd/0V9c1Hr7OdSG7qNDK1F4lHlQ" ..
	"4BRDwKU3l69/TJfhX7H8G/5daH5IAfNdP9qf56FkUYrcOJxFtON2eWqtcxUksqWMo1tm7yf0cLwoyTCzrq6ZKkJty7xSxOxla9i6" ..
	"OC5SDDpSgwQXKJdGezL2WocF2GdRCwONepNgGkNdkxCzQItj4ICCPHgta9WZSmsSbQOaSLyff+FewdmZ2aQb2UaVXO9Z7PnIsM39" ..
	"fKHJliBexXwvZT4JfFXlHr1UYKLzwbCe8zinLH20qM5i0H7IYaYZlq7Pb7li6PtQuPuarF5sjWyDAfjHPs3ejLJCSAmpxY34+pne" ..
	"8JTMEtEC1WoqvlXmncH2T51PEIdNGOggwNeuK04aIcTFQtw4JNT+YU2soPhnXQP/NWIK59ngNi+Ruc6B74Z7IenozzKWlFIAv8ew" ..
	"sl0TXl7cyhIj+Sn1vNCL5Eb9W/H3c9xhSRt5+ASHGN1yZJfbwiv5/PBkCuUHDlTthE+dbOR5QUaGtR1sedXAu2qJlBAvc6ZhiYMG" ..
	"K8c24ktFyWq5VHHMiB0kQlCO7XPXnIwsEllYnz8KlqXFtAd5n7+s8zRmHL4yuXsdADJmbuzCeaqQnPwLcUtKJoYj0OEp6DH63Iti" ..
	"s9MuCk0cv/k69nDgpHuu/oyLdRAVcfDOaOCQYH9X6j+1h1jeDZkowXnsma6I8MNZfxImaL/hIPFz94IjQ67PFzoavuMoxXionxMp" ..
	"c5cDXJzCM+qOU2WfOlsIUKlYu8ke7i8Ynu+ydhD9PECGP9tzl6bargAbJ+OTqomc4TjFTsOvjHQDIpwHZrwBJ6TdZ8WZKD0/BRgm" ..
	"reocZpCoOOM4GZaWScYgVLnN1YAHQzF2ArqR+iwu8gM8HSY/R+jTKEV3LMwfU0H+GHQyWcmzEvqWAtsc+sYcek2YM0vFG7UNRWfr" ..
	"uSIf+GkXWhtBFRFtkuKN6k0QRYzaMzFvDaoU9OIBf8a2mHPPh0PPUybH35HmgaGu8OcSfX4vOxL3qRtuAg9a8l0QlbK0INwplYP2" ..
	"bG2fZYsNVUn1+jCWZLoS57FkliOZ19L7+knyTM6gFXmALGGIjX0c43VofCGrTmuCD6pE5pdvNUKcGunRuMcrvtl+xOPyJDuD6jdH" ..
	"pU9C5vYNrDAswagxBPhToXYydE7gOHgIoaadhiJC/UHgm98vrlLi5YVmv5m7CGKbpe6+3iKDiUkV6ESnduSD8cfjRPafUA5aXs9M" ..
	"rILZrAdXrWB4sCfb5TsuqLAAfvSm4JLRyi1N8GkU3cm39joC3FwOyJgZCqCXzPzrLzNp8LdIXoWA9q/ROgv6GvaJzX1yZHsEc16q" ..
	"WyW1Szx6Egpb6s/EnOI8wl/qNTg97rWeh0/YomvGjEMSaynwee2+PpFJWHK6KrNSau2Zj+/fB/jLctL05x5PP78jGCf/qh64uk8B" ..
	"s3s44BlSM/pPlcs6zesKgJlQo5O4yyCq56mvbM5NjqPcG6wBPBVqHRBLQJDJqSpVk/D3P4ZxzxCpY7zLcp1MUkwddEE+v6IqwqBa" ..
	"kZ7HEyvcNdTN+Qig4gQwUr9pM9TCoMrCfbZylzpNk/2Otf9lja1pYeQXYlTRFAhLggrK9A/XgM+VmfjxwPAvLXFt4k9FxuE9Lf2V" ..
	"EBz7VmWlwd4RGoXbBaVgj/eKjgT22YKrWXASy3pcq7xId3RSP9NPcyq5rK7mw9rw2TCs1r3kX0cYE1gfuRzoSt3fsNzAkzJpAeO5" ..
	""
local PAYLOAD_P2 =
	"uiCE+TbO72A0/SV37R+cDLm67JU8kgp/gblZKfCDTtEzE537ksDkj8acuqGDHiNGqa6b2kUQ0nPHVI7vjg7qr4Mvj+9UEKeiRtQX" ..
	"trkp64xd4YTxb3YbwsVBLZxDQY60EAS4ohWTWuQGm+hyrdSslJ8GAxzLEtSZsOU3CcbXFVkAPoOYPaBVhUpnenNrZ83sdgYn0kdk" ..
	"XqojEo5+9nCO14j64Qsz+KGPIegqr7Sk0Jau7K/8GVgYq02cC8vldv9CO0khhupPDQR19lbvd7Z8P8lOTVtjkhHPM/VZ2nHYUmYB" ..
	"DBo36uET1yprK7TwQx/cAMtIF/8tVLzpJ6tXHqKTu4PzSvWbJBbkZx9pa55wiju26hHF1C7kYo1A1M3sW5ho8AjtQhImv69962s5" ..
	"9oLBQ0eLrPVGkSsh6osjpqSO1rMWSRlMVwtCmTWPTyCuckxQsww0NKOvXK/1Y0seL+IB+JxRakDYu69nIHVZIptYv/tAR9TlK8GM" ..
	"eqndCB//T5Da8e7T6p0lAORGwQiCjy+GpRWXh/UTfIkm/OH3eDiADM2OYqKzWMWe9nNg6YROuyYaMA3iOKscOCto6/Iz16r2pnJT" ..
	"up933wyUWN5wUoyEUS8cx028GST1TdREh5n/InPxors5DQP9VtzlgefAHGQU/xmcMXShmeFUOcZm1hb4qPBBmhrDQo35i3vQau5W" ..
	"+KVo4bdsxfmbQYu1pjVG8WzbJYBrp+hL7OgAhI0GZ0cp8+Ed1jQ9lMvI1Ana4AEGso5IkxeH2usKJQsaP/iy0imQZ3P4zaqmw0QI" ..
	"R29X9iGLKrHPt1ps+Q7MIliZ3uXV0JTpyKOfoWkEvSfAMtvMba11vqm2QdMtXAh9RWm5eJ0E/OVZSXNqplhNr04fakPeiCTQIjk3" ..
	"Yk/gdL5faBdP1UsQcxHdT7Ih1RAGPcbDydaFZQTIns/anim9JGpb3GysRiP4s9BH6vh+v+pZGcLRIeR5K0fAjVWqvJ9bV5/LU+G4" ..
	"zYczidgWtNaK9CWYE5i8lTQ+MIg7DaXii7pUibPJWlOCGKxY18TtZ/TC8Df9XZoKaP1svG9Mm7wXantqHsQkJO3DUt3K+v45jPiV" ..
	"pLWMx42NsfJjVwvuR3r/0QM/LWFTPsQuk4HdAbU1fvpH0TJDSePZCPNNWZuUYxnQ9AcheE5rC/Ptm5sP4PKLIAabEMLOCpnMT7RC" ..
	"HrX7s9pnnlpwPBM9gy2znsScy9v8p9s0yScNhWU5VwcxfJFdUITogEZrfSZiCspZChcT2q9QozKzmV/XtylF7f6WD+UGBv0nvfBA" ..
	"LdnlVRCjyYjxPRIeG6ppUHd/f1V91bE6PnYtwKBQipw3dBYuh2OTeWf0KMY4aF/aF97Z018YcZpmRocHEZZpDi7XdRAEX1TAVwl+" ..
	"SXZz0O2Y3IuAgtWMawZd+hNLSgpEmaxQql2tS+VozSY91Eff0+fEWWxoHmkkc+Wsa7wg8lSob1F3mANf/fLFDkFv8a1uZA/tskPc" ..
	"+Zx0/i0jv56sJaFb7nCSSAdbY3UruCVyAzHnctS7fNuFPT8Q4PqnIXUeMKZqcIniO7ijPGMYNq3n6/BHOaBkPuPAb2xf9Aup3gQP" ..
	"UKz+evXU1e8sPN7ZbJdP7DOVTcF61ZdYyWNqqgfYJWSXzToTwsCRSSha2kCDMo7CN/n7ntiIGCrU53TS6etmH+fYTgnqIm/6DH6s" ..
	"Ku+iUajXzc1W9qYbezG1JlFrJVLtHy4buDgal4VCIwt0I2C903V4L9EfVTi1UD3PwvnfGZ89+SpUB39WC7PID59kWV3UCkVagBbd" ..
	"blKcsrQu5uEehSj7RJYyMbkZlQHGtnT83zS/vVe89g503LLxgrEQWfPDlBLQ8aiO6FIEdtQMjbeLTRF+0kXBd1k6IYpYCso/vbov" ..
	"LXcfihjx0ctGbFmWu7VZSuObluLE5Iy9nV1RM+0bDJFhuWnxuJUyl1El7eLYBCrxji20dlinXawY+zxTMV4KANrNbaRnX7kvQdWq" ..
	"zpcUFNUGA/GH1rmu3ghoCZP6IFzuBGoYJ3KPkAUOU+RE8shFXZ4HNC4egEW1fpTuMmg+x+0xGzJKIw0LSBvt1ImzS/xaRoKFRU7+" ..
	"Mn6Vip3RxLK9risGQmnG88iwShE4XiY0PumHcqR50HD0smi+QlJIlESTVC1+FL3quTUBXGFVjHRC8W7RCHlRIFrhcqME9d/nDJH1" ..
	"4yaznJ5QgCK22nhdwPppcK6+d8BVgTusXYOFOqGQz0sG7PISD3dMJNwka3cGba/3nkvERl+wC8/ZxJCwVIJgLTmMpfW1PPOejqjU" ..
	"XGWl2cDujRzqpxk4Q3Q0HXZ8jIjkq89lLFzL95cZGw1V9nZmnt2E6ZzKnYqTsb3VBgfCE75Nqe91hCC0rjNQNTSixRnj1+UPyHF8" ..
	"eiUmNhdE6QdP8WrufxW/27tjBD8iudvN6LGcmy9eFlWzdv7m5vMPskMdEXZ5X/yui9P8oIe+H8E0e7jVPWPj6Gin+VP2Wi/110fY" ..
	"8dwYRD1MQJh3ks1FtkeTF5zHytc+owRl2j44H90HWOlB9j8PZwMXn7EFqZr3DkWBUq1zDh8Ys/CznIXqffGr80SkyqdXNNiFCpyL" ..
	"ur1nlxaMQ9FuR5h+d0sAen4G4uBi1/P5Et4UxhHVkADWm27u13F5BszZNljxPF+PGQNSwUXXXYsaVebqjkvnSUUkBF3PGLOXSYcp" ..
	"8VSVtlAQGSanMdT6RlwGMBLTi+NUXT4D0u+9PzFDUFcIqFAg9YGFi0k/MPmunB0p8Faw8hw5y4WG0PwPeS+pumIFf0zTn5DYdsmT" ..
	"dy/yj2VQqRI1jrDqecfy61WU3NW5ozrB1BtSvkHnx/GKcoKJ5z3QgUvc8KDMEod8rWZr+rDgDxtO6QGbord3+rIOSob/7x4/OPr+" ..
	"xiC2jAKsQ8h9q4D8L9Nc+LmECVzasWkmVL8z4EkUcWkH3p9EP2O2w5o2huZcbM5nBvFkVHjMiCP14aHhPlVDnnbHake4GyywxuTi" ..
	"n5Ar/yzYUrjGVq852dV2EyAEvXgDl/gVBsGfRw1eweaac5TYKR0XJ2HIUNXJYnTzKLzIyoD6IHhFjoGiWx/gmoMs5Mkeo/vMeml+" ..
	"5NiVbKxLc+ibbfRo8AHT9yOabfScPNGGoEttzmNiRrRdhPwEHCpOeAkbrrtmXVkTdX3+8DgLYpFMKMHKkmQhgC9GW1tQXP+oZJSz" ..
	"AxRphkaaHzoSTb7TH24VnbwT4h2AE/O7mMqmRBmWW4rVBdkgMhVQioAZdZ+0MBOK+LVYRDwX9HomnjnFr0rQbv9PTcww5Uk7DUuy" ..
	"dCLdkixebQWtWlc8sr46Div5KY8J5H49kaeVJczLR+e1f5CMuwz4CFV2FPhcVjDslSefdLNhElmrZaO/9ZlJEv9yPSmALEfYM8Cr" ..
	"ONfOCLoK1QbA1Mm3gnuFlJvqZ3faELl5+Un5vz3NCgpuKTx0s+aZk9H5tGOazCFnKzcr3WvmEggQ3riKJYh0T24ZWeu4A5OKNitg" ..
	"recnqsTKZjr7trWpjFa+WNVJeeOGWlpKSAR1FylMS01PpQ+1GmBwPuOdiF4sYkRTKDt+knupQu2VoRkPsbI/pftdBfyuAu8H8gKA" ..
	"OlOUGN79vU5BD7Ti9ocQ9VP3kYqew2ZHJJ24tjz+3ufLKx3Y4ksro7BHhJ2iBMihnDkXxz8CWVaEbCOkx66ZkCGxDN0sdE6Ox3uV" ..
	"nX1SLAaAZPqyKQZCdS3dql4E0POuGWNebjUhK0hWVNFl4MB7FlIHmgUXJUb/Hafl21qNJ6mMcLCg6JTKD5XwyqTyhiqGMefvUhr9" ..
	"90FLbNztmV9tLIeJE7h8NjQRRw/VytpcP7eLFIMfcmAtPw2iXUinIFJ3088sytBXr41ZgjhUBYYGvYQVzHFRulXA9dy1IjOBYZNl" ..
	"R/Ycq0numnGKuyDXxUFQ+UidzSoeqyukgksKQ/rbvBwuK5NWUWQqgYZEbuiR3m8qPYX6NEJ6OoAtPi1b2flgG0Y9ul/VO36MkwFX" ..
	"cpGATvttZML9eckHcaGKVRk2YM1ddeJWBcTNnOZeWjYHilWkTpjX0aHgwvj1N1ljmRxvSeqfSPTyVSwKuq/+OVFESdRAmSenCgki" ..
	"sQ0on84emCmY0zMYM3ewe0Z9etGz30Fouy9XrR2Jchnh4QXkHkr3825WK8j+Em18YYrRKb/wGcRQwkeCTpcK71jdu+86dvUbsS9F" ..
	"dZJk0Ke4Z8fYGvQu/u5p30cVI4dcH3dJNsa1hDAaVSZRvRAkk1rxqgjjXwU6WK+YqpCnH2Dri3ssqBj6ITNkT82hQeW7yrNphxWs" ..
	"peAAMWzdPltUCrYW9aeFsEI3mZGX4nvHu0wV2ZmO1O++jlkLk0HExotaIm/tEQwSJIsg+uraoFM3ZaB/A3BY7SI+feYDT5Z/KZ9c" ..
	"PS++nEGO600Fjz2oObDZ8DG2Exg9zNxNR/L1PHwCV2MlxNrhtKZ0IaqCZ3P5wS2CjsHTHcfNyUIVijXxN5zPIrZT+RjozioYYI7P" ..
	"+8RghgWItRz+FT0cuEuAMmlVKAd0dmm5JGO1DnVt9aYC5CeigMYVs/CKB11lAsB6ZI0W0ue2Lh9/gR7vQH/FbuBkUChaihFK6HsK" ..
	"tQpELY4lgxMUDvT6cSFhiddu9ZMLETUtDfKKsM/nbvC3KHdrOeikJTJgeu3kJwF0RrDtZoPYBLQgIuSF7eyV8HwCtSd8lOnYzkyK" ..
	"5r++QCTQRFQEu6MPtPzU2jcKlKiYC0jX80BlshMDgBFkERgekivhd7pOZIX2ti5zEnqpyUlG0L9WtuknRyGdoO5CEx+d2akbnCL4" ..
	"dmUz1wjwkI4aTACnnvBtr8SgUPSEeGUOouPD1oZSkTFnoj2M8/QgzI7OSnMx5vQxinsxBAvi7xYnK2weUgs+zOOZemIPS24tmc4U" ..
	"DAOHYYJSJ2R+DHroavWcnqanb0KSHNWqFZAKoFu7SHMykz/lz6/CFiS8elwvevbudfMcRyx2w+auWDHsq1LKs/7nzExa2PU7Pt7S" ..
	"38Nz5Gkv9Q3+R0IAtlcioluy9D/fHHvr5w0TMlYjNZfr72u/wkqP85fsicrNObmMgzWJGfN6I/lPkT5KprhVPtS+g2TivYMKZP/x" ..
	"ot5YBGdZK73Ui3+ILieG+l/Fu3eh9ejkSHyvc+r54pGM2cWjDnB0IRG6DykMCQa4MFftaSp+FPjbvwVCmCmc5jAEJsouAmfrezPW" ..
	"fmrw+4FKnP9hckz6lE8GQnZW/gGOtEjvoMLoKNO6NeN7dsOGd20IKugp49B+p9CafsfBTXo577d3N9cjTMVfeDBLJ9S6o8SOytEC" ..
	"QphrNGtFhzvYWwkC1xeRkYAm641VUj9xkCaMd3DBaIL1iM3AvXmxsSr7swOz1IV0eNZnc7R+okF+2+K7vhXo6XKuV3+yoGOl5L1z" ..
	"6WvK3Kyb3pPrAy+PIy3tuVheKa7QZPJERU3I7C9r3YckxSWB3eDnWqlKMLTBV/bO/lwlYz56XurigbXkxryLj5SkNncV20UKNm4c" ..
	"awkUoR4qpZZejSqSXJ2WwN5CIoBE9Ra/nlie5uY0411nnOT452undptXTj+13xgRF2UC35Tt7RMDO/6NgoibZm+cH9W1YRVWLduZ" ..
	"h7OJ/HKBw29t68FGx5P21M2ovUGrvPxeAennEGIniVigM3pxQwHUT96DEgpMUNZgSkzbs/SGhxrd8ddfwLCBnUW//EwR/AtDxrzn" ..
	"jPHahVLcTEeHgqY02wadzrNcqrQRqUZLzScdnjv3JY7zp+dMyX+dHlBuzMhXbQ5IkriM7pnYcoeNZBGl8GnyT+GOGQeJnn3sY2GU" ..
	"TBAFqSTu5wVFz2GDB7mLLURppKOeSzlvW5cHtu29wbUPv9t1gc6UMKHfLcwuK5jqZQ77WUCdWlQSwksnnqhQadAgVk458IpuIGzs" ..
	"DJXgdtw+63raYeSX9bd+xwCxwzbHJy+UnVSLTFNzwAe6sa0ZAIloxRQefJhsM7uOKES+Tx5Ov33P3Kj18anxbUEyPRVH3TH8Locv" ..
	""
local PAYLOAD_P3 =
	"ND25kkpGV40EVz7Y8knB0hTyN1dUVo+PnASJvD18GERmkZicJ3z+iFjIMq2gz19Txa2mo2i6QrXFNk8LKFu6lNRyrlzSYNSuYM+5" ..
	"HkzCMem8gkRHHXyaWw02WUOV21V/X7c5bdnKKQfZHTFq5Iz8FJzdqcW1hltbdgLBjE/tgEufCsFMf1BeSVguilvVPMURzpO0u3JB" ..
	"oO5wATHD5UIZwpHlIvz7FOQcdxwhEyyVhmE5553YIkQjhOmNKNhjnOIVQ42ayvDuwH0mNw5In3Fl9JHlK5forlfJqJTaM4uSv+Rv" ..
	"K5GFSb25T1iJRzAK2+DkpwNZd0/mIoDQi2aIhDRVmI/gE4f61rDmnQRwOoZK8q+Tw41pyqcUaNR5Pdx4YthROafY8n4d6eUV+kzp" ..
	"aQeU0M0e2Rxl6KnP7kXYA7C56LJ1xRbqm3d03GSyIlmxgI5g8NYhcqE0ZQj1ilWVr1H4HHhwlkQBJfaomOUdqoWRXPdJvi1oDXfR" ..
	"4hTrabNNxRrRFqw8qjrf2CGigEiQH0tVVoIo67l+gRVbfRTz4yBZnpK3B137a1bZHwChRJHQaau1uI8i733MvaKvXAuMlmG6j/fW" ..
	"ZHcpFPMWPNmSCjfSMgsnwd7HT8IYkRVuuSGwKQRk8JpHtL2oqKm1fEO53a/1Fdj6XF5/ESPeMD1gfurXHUUux7MhkhmoHDzczhCD" ..
	"DDtFfraLk0xZZnKI6HbsAL+pus4JgfYpwd3BOHgEIIoFoHgwgmRVUqHj89M9EeQoOWcj8pqJhRWCENKxxFYz7ekyMYVr9sIyUrMB" ..
	"QacURTNZWnI1ZKH15RE7n+80xINhLVX4Ps4bA2izWIXJbTzI/BUpVIwlPcLv2KzXo/wuRLjcaQ6D1hJ3EF4oz2dpRn+Y2k/Zdwpa" ..
	"yKAegEvBSmd15q2wqXV+iktdURKf6dRD/jaqudZ7QyGdEiSTMSbVCg9YOL++FjrsBxDHaV9aogdYSle6oH2lrjaXfnVxDETC+dR8" ..
	"LWg8k7BgwVI81vwaIEoLVONuwE6KeY1BOZNIKtXjWuhHi67MkPLMVCYPKLdVy7Lo1z9g9SvXPWp6TIZxetLRDMrn7iIqvgtzpCda" ..
	"1AY66omsefanvLf95NZ8dWIeF6WqjFGjRDscoWwLqJiirXN7T+P0euY4wM+xpr1SLZS+2iMOxwOk03ZNFytKZQG18ZrN7UdQmC4Z" ..
	"scuAKInxqRPyVYbXbPJwL0HvSsQLb2ZacAjfJVsvSMsfp+rdYHRsQteH3Wrb6VCxUJ4fapV/aS68K78mtCdJ1jlQFmrwwMIAHY02" ..
	"+a7GiL3BGm4v1L0Vx3ufwsq0B65HGn6B4oXRytIqnOFxoq0oa+XWFO4drFACr3zThPJj4RKwt5S/kfEXCawFsr/cBVdY6BGLt1aX" ..
	"l4tU1pwf5SV4ek8asS+UtXaJ+Lz1eEhIxcqtc5VleTpa19p4zTmsU+j1EMwLCb2nerKMQXgI8m7msHvOWjskdXtQ5MT9uNsGNv3f" ..
	"tWi9+4M+X+G9+Vlyw2M/JuPGaY9e7Le9xSdP//Q3rqyTizUbTHqt6VEp8vqfe8KbgtdSriFTFlkWNM/wmL6ziWk0EmpbR+iNN0RP" ..
	"mmHCENPvCJ5tVRDtUldGZyZ6oTUjiGYmALvAUkP/27f/JZ1mMk32S0Y3vmBB6bx8ay332GvY4ziVItnYbfbs3yQ8Vsi+Ibsh+Rn3" ..
	"SqZOd4cP4eZ9LGZbPbC2BvUwkMlDyUzlsZZ6brLfzvnBSx1HMqK8ncNkek0RSjjp/qhn486rkksfHfB61KdewfDUhT6mqY0ORmv/" ..
	"rTnBmKHmCOb3OxCAYbU6LdDCxBa/RICGq/E1DgyFczEI7xTU8tpnEVgyLcaF/tDX2IMJIxEHCM7vp2yJlEcvsvqLd9GnEAMCQNIb" ..
	"ErFW7mQ0dngNB39yRjp/lEZezS8tsZYek9NFUezRs7bzxE2Cn64bp1siHRKdXX6IVLpbNgr1PQHdYBI8bdYs+xsVVd33UxHHeZCA" ..
	"uDaQ1GyPfXVaDQ9lPAwsgTLurUtLKJstRqCm4e0/LkI2x5oA8EVEsxKpnyoiv7Fhhk+ZMV2kYDS4dhgXI9H6UiBxqUA2Y2OfLNfL" ..
	"UV3X7e2tjMUXPpmK4G/VOROCQ6yMC4JlLts+So8DRU7ev3K29ZImStHhYxjn6Fsefb/do6RAZtUfXjenPSQWt2pp/PWNVH8zZ0Si" ..
	"0E2L5Mh2HH/tiWQd5NQW3GsNShCTVFaKfwiZ2LnSWn9jPHXxm9p1cxyWmU8UnMZ+hMFt8BulwaPzu+2j+JzjcpfEc+CYcWmL50zr" ..
	"jvgP6RPRf9zkiGDomYuh/7Ohm+9IpHW3t3qGtDiZbuhN1/1rB4CzqL8DZ6YDJEN3qYL5t+qS+0vdqdWeilvYcEdLmSgsC7Dx+Ci8" ..
	"wvsgqDOqZs/9OrhnyfU4r55JJ2yRyFWgzzd2ggSH7mJYwORFnHruN35vTdpBr7AD13aYGzT/DkADWvFvzQ24RzdaTmIVkOzWyjmX" ..
	"V17TYQnkmkGT1Cm2C79s+8sHiSrGQktxM8VEpex0JvG5JZjtzDr6/GWHomsAAE6gb0qQUm2mHVsv8iDvGgtPKzP3DWKXnJJHKjqJ" ..
	"+n4Hk1NDsFGnIZwdYn9yE6iqDrJMzlQkeTdV0fR3pfmSe4LPzpHOUA6ixp3o6fx04QA4UONewunEz9tAbj7VFrslKbWFpuoX0cOl" ..
	"e3ddlP3R3wbBjcsq5cdIwWJuHh/53HGP9C+1qDziguW+aj+LB6CF28EAfB8+tBWcD8eeMHqUZVKvMSy4QVt/J1hwj7Ixbs3Chggq" ..
	"s7aVVcYjDiIxxneBXi0NU1R5z1DymDWsehH3cNrfRSKhS7qvYXpf9FxrWyGJ5dq1LI8KzWzASDXckcheWCVXNQJqfKjjjHZ8bszZ" ..
	"s/UmfM9z2RRuCPadkoNEcpDwwxo4UWedQTv8JOYi0ucNTmVZyq9qIByWp03TDdJ5vAOMjog2RdgyWSpi3UVLr+WuRsvUotwr4T/i" ..
	"JdeOahFGwoHLpdRBrcmIycLt2Qw99zFqU6+9rKxn1pmhw+GzkM/MZIm+hqqjZf1UgNYpQuHRXHHucgY9eefai7WDseUbn43YOHNn" ..
	"3eDdUl61otqv8KABDVB6j2RCJS0JrYqkAm/ouJs1DlTBJIl6L2VHT1V55ogPuWATYAZ5GjiOXjrON138p+2RriVO2iB0Qq6Rwujh" ..
	"lK4wZIsIHL3scByIIZwVjhkFUe+4ipvr1R/DwbKikTpxwk1RRqfI3xd5MIoXqfmgEqWhM6rl0lcCiPm7vuqsyPExTO6x5A/7OjhL" ..
	"pc+ISl7IOjFwqfVI7a9HRsLK8QW/sDrpDYayWupixk1rHxGTVqpaCuh90CnxmFq0+rqbE7KksTvThyf49FCJxJMyV8xiEINMLFv9" ..
	"vcgMPNfgeuPIgwovLNXhnsHrnWHaJWQztKhefyiM88D+NCXUt60UjpVcc6ztdnrR606kimSLYiO8IW9wV7VOEPMXr/b9N3ZnTjww" ..
	"4bv3bkA/LcyBoKEaeWIzoKGUuvpQ6B6Tiok9zOsUSsP2C/kp2w4oyyGYI72ySoRh6S83E/nUEuOevaJM31ZWd+8DSi/4992Qv6tz" ..
	"PnZL0l5iGnnqzBNxEg8bzrrsWfPNGrPYTC7xaz/JsqPmrMh+wNVJyVoXz81W95PWHD7tOwEbiQgN7mw6p5U/lwg/jRJA6la+lWOd" ..
	"kaOHu4y3tZQCt+cSSrohXl1tCfbOD8qvSJyxiM6jW+KjT4er+5YgobF71+OAfVfQ1xoQYXF4hXk2XYQVuhu1Th6Ij5fvX7uHA1lG" ..
	"TjzrG03t+8lt/c8n1+ih62739NSY3X1c4O2KtgxGwbmxseeJ4Oq8icLu+JDYY8vaK8Nqn8xECjGyjZ1o17mNnCRkXjbLDZfH2eko" ..
	"uMkOkLFC0wKjzFu1SbKrsb/W7MB1k8gJDqQptxpEXfmJ2855qd1WUMjvRpFZNYKlGxyvfcoAanuwAwvFJ+zRZCEFd3r4pg1rUOAF" ..
	"E15P2ZWxKuFufWiXyMjYgxxVzf9AOkvn4nnS+JBrKbBhF9uGAtJvPon9i2WkXC9JWXy94WWrMSYN5+M2GJXFknAzf4z7J0vaY8Yf" ..
	"jL73qd+NRQoQhTnlFyzXC82ijpWQQrJ08jGGofkBGHwQsPmnkmNfEnQifYji/4KDJ/UkbFPR3/9FUEQMpgyUX9TVGCz+blZ56XdJ" ..
	"0cRhoi5oR5Jj2FaquDoQ7FzWJHQPNjyJrlJfSZtxVpUo0NAiV/sds7LVgST0dqA1f6VTYcN/l2Egl2CUZ7nIMynF07HB3TdQxhDx" ..
	"rf7bTyYMnrZgJl8bLzv3vlhbPweMYNQxTONuosZnIcnsxa4MTGuJzrWTDZtyrKMB4hrwzXjbwapPZ3EMKqud29z+YaRIs46zpcPC" ..
	"0vrO5yrCa8h3gXhJAIVxRfNBaFJkKS9aMXHT1of3r7cRvlagBqAtWmJ534QFB87P8gzkw975HaSWGIPO2B64jI63dGYVqpRx7ID/" ..
	"hQGI3UbDc6wZdJbdPnMWh4nqhiXkHxSac/O6QYfwWV/SDi/EL1O2l31q2jMlZWtb7TnSDnVPuI6R2dlz1sHwJrme0rU83oOwBszR" ..
	"diY4k7pK/0POFWwCqsrNV/z3QpFdq7Rl8P5eH5h41pGzWmoO79m9skfg0W/DzgCW9x9kxm6QXEcqHMfLAXVdkjc5ucT4j0wrVUaD" ..
	"FvWiuOV1C35wUdxJ+/M+Quw6bT9praTs0GsaQEfqA7SvsskO0Oot+96hmblYIDLrtw0fTQRK1ywOZLYEUgRIOZE7/EPSUyJvjb1r" ..
	"riyWalgmKnPULpT2e+MEKcygsY/ULbEQX2Ytl16kT/iFbhg22Fcsefj7Kmj2M1KSClV6z3sTjvl5lsSHitVFwmCKKTq5qxumBJwT" ..
	"oW0w4GUmt5TfrmwvmgnNB7mY+qrXILCTypXbZDXvy/haS53TZWO3QRrm/edR5u/N++IFVPCElinG6tM6OWHWGsJBw5xAl57W09ew" ..
	"9kzur6aK8AInuES/tywwpE/ylT6XzDRoQGGttVYcaq9+e/S70WH/+qfpItQt02DEXvcPkEhmEjTFCsHTl40pheOT8iU1ObdPJp0+" ..
	"kXNLe16EXdGQ5Ix5rOLic2cbwrOLxWjKLXMMQB33Dpm7DIhYE7E50RcaHH8gxo0ys8llZe4B+XkYi5GaQHkTlic++4/QPAmKC081" ..
	"5bOthf2qUkFPklHJHkMdypMCfimA5tb9LbLZiCdbwcXvBLl0ivjuRJEwkP5occ9LeD6lQj2hzKow55kPkBSY78UxYU2Hzubr5NGs" ..
	"0l2JpRQ11juxBWFBQqsZhPOibDLuNOkjse8lIyw4zwrkbQDmYEi5xS62A899YMDj7AyygouCch4nPTx7C5l/6s6tupOERzDrYiw6" ..
	"sW7kSXAX6F36sBN6ribANcFqVLnFcWUQNN+VVwty+tVJhr+dKNr14Um1gufR8F1YADmD8DMAOk25BG/60Jgpk2+4nKL+CT69lke1" ..
	"ZTnniKYGa+78GrIE5afoWkrHfAyKhJdj5JnZG3wl6T7lbK9L9CPs8PGV9h9f2ltOF1mvLKu7EMh2lmrPFKy4RTZzSGO/kmuw83T4" ..
	"Yfy9rTZ0aBdVyI0+rUHgKHKC0lVdE8Jz3bzgj5K2BiKP/cRodwijd5GRMfdb0hXeU+EdaUQ1unl+/p3YHsWh3ImV6fyadNz0imuG" ..
	"TsVPZjktUtfmtxFkfwK14ow7qCT2jDspZ+UsKTS+RygaslxAk8BAJS0E1rlnp0nf31VEctbgRlJSXIRGdBERcP1FFx5oKytJjR8T" ..
	"asFXZ+7kAu/A7Vf9n9tik+oER+vbpGczdOBLyvzWoSqb+xNDpsN2nJk2+ZeO0duGBbtcPK/1zaOCKfI0Cg7DWguinZS+Je1CStbe" ..
	"+Iu/S2xm9991OIzwLaOadE2KfW2ix73bNBpnjgQ9buFrf/XWyMHLvv01iWz/7GUEIzxiStQ6p1W3uHquP9FLulACYukyiw4y3uZI" ..
	""
local PAYLOAD_P4 =
	"cQ5yD4bmyHmFKhGpewy6Bh12/0YGCkWHYrQzM6qh0E7gha0DQJXpDjGeKUe+kICphoacBfiIqMk5w1XTFGK6kuGK6k0pWAwHKXrW" ..
	"O0Y5j3nXujP5LVGd59S0A/vTyT7KcqlibB0uSwM0ofSIOXNlwMrPwEJpgH6fjVWKB1FuKhuMMtx0t0GCCLJIwBEsBZMP5K3tSF/L" ..
	"z/vjGHtyucoY4RjyiGaEJCrcvZpMVa+M3y1o1+Jlhp3aphm25lCrigPMVw+7O7paXZbvKR+DDaydbOgApXsMapUtrBaeADC9okon" ..
	"feDWnu5WNPOfcBQMUCYT8L++PpzCsHTMaEipKsCKSc6jrn3FR0uZ3lKDrsk550wiKfOa/7kfXJ3Zqh8bt2G6FdMX+N6MJLb/B2cP" ..
	"9cZ4FjXg6Pn+2u966333P+mvyCPB/zM+mD2BxxE8y40V7/CcDo+sMPMnMOo9jRU1uNeUrYg6KjResd9/NiAUwezpsmkXPwkIeDg5" ..
	"oZp1hIWv7uNfqEZS2fpMJMhTvMglQYBoSujbRdes7POzJLCkBsdmvv0sw4+td1KtcROljdq+X8vWHemCG2BPFBy1u+EXx0DjODJk" ..
	"+wpu7VNK2JSWcy7Chyk1TqqwvCW6V8ZdoGVFAFXfjaf9rH+T1iI8MSJRt+CA2ya8pN5mFedek5/e/xT9KqDrtV5rbNu2OZAnf2Zk" ..
	"5LbT23mMM8XiLv5ds2Jy2W1wBt9N1Vye11b+jjWlNY5oc7SL3dXK46IGMLEwDda6wzXPx3m9DUAdBALfWlofgD8NAPEvWgBP9oJN" ..
	"Ph/aztKZP/sf5qDEQxsEP2FH0Sy+O23XADK28QoLHNe+ZwWDccEEv8L3k+fBqocwykt83Klqu0teZ5beLvyrOuIaB8ULkko+BaxP" ..
	"NSVJlGW/dhNTdDSXKknh6lrpE2iZtCgK9iu+EZmOqUiC9QvYQEHFIbMKHEp+a9kL3MbLWwS6RFNhHvKNSNY241NwRGE9Y2FIZE9E" ..
	"Qlg3y1EG0hF+Zkz+jCpJT3wl/trHAYq1rn7h/tP7k+F8UldIF8SG1HV05aKNu6cI1S8srkKGEI4/VFjXPe/uVTTvdDBN69PYGjcU" ..
	"90PYRgUCitLhTaCAuTWSc9Ae7XLjvTwr9Jpb8SIPC484cRP2/97SLl2DeHXSJS8zQKHvR7QWUFMz8uopHLV+4sxmUnOUNacrXkSG" ..
	"kk19JcuFD0m/KrN4gv5vZQtnm0aulPnZuQRMpO8ENxMC/eSEMocXNtfHTUy+YVSx30YajzLFz416xdpZrCYPMwkJlDfwXSgYOuhd" ..
	"9+94gUjfEbb+/euUcK37yebO9cGPKxyVkYYuonTqdsMcF+vCvAp4aNeeahc1uItVUAr31X3QagXrJN2myWUtGuGdXtc8cVIjnGBM" ..
	"qGEujM9ftlg3oFvTuM+oiG/9hgUVtjk/MWtPHtuVdStD++h9VScNuh/eC1mDS6nia1K+Unfows5QRlqwMdZaVKUcayYyxtkjiDoe" ..
	"eCXiE3QTfo3sXz6CfAdlkGBgzbPlIJT0LD9YEfAnUnkUIrpJPaTU2QU7PqXPbBY8hT94GpF2nLICYztm8iyu6CxQQEkiu3vzWUqt" ..
	"GMtuWQMmz7SzEd3zOk9G6iBXZxNd/zHoFUPjSsKtRninN8EFP2mDc3rEKARKUSS0xUY8e+HXVwXvp8YTEHrpmYZSiGzJosMCO1Sc" ..
	"98nZhuINGdwBDM4SNyHRmVSAGJrKQ6bpnS4GsLTRdrZsgwuljMts6QYddE7ZnIKxVRuOBcWqANsB5WG4F9iwXeMBRzt+AkZXDPD7" ..
	"a7qoa5tIFGg9trAShEE3rIBlWG8tn2AhIg6p5EKnwFiguc/Nkp+GXsgIwhAAkMzjlPKXWpBweW6x2ooSH2PXEq132aU7bw/e9rGt" ..
	"IAI0xlC0hlrP1glFBbxcS0Cj6bRJnUlCWrimZzdnoTi1Vb3KjgIWw2Hm7KI0J49RPAlrfuEATQdUpan1wA+Woy0DE2J9Ozgkx0K8" ..
	"Koazyxcr1nVopn0EKXSaJPL6xx440/lkO3wGfcVBHriNP/TofOxAab1WxC2PJZ0UGyOL2IByh7FCRqTVxsPt+UPiI1ACw/+Qki5B" ..
	"7YaWxSfPt3at+qJenjRzZrMY6qCwLWpOGjUnBURAxfMBA3uJ3I1EmRhUXbVLYphRT+c7VBOVA7gwvNyaapkTgnRC3u99xLpslmdb" ..
	"dZvBjQSH+KgxSVlnL4nGYN4/UKMrfyVHqmm7HL9DrXYin83CgFFbOX2iAgXBm+w41MofLVfthdaH/mj1dvH0QefsVBt+A9uMQKdD" ..
	"sxi++Lc6857jJGdZUkq9xgouY9+uG/t7kQc/3ILheqN0j+STl2/O9STrUiIU4XnmN7H9/r45QuhIZkRfuCaOHdJCKYpzxkTir84V" ..
	"HJ9J4eBDX//onM73v67CM7WWiLxt6lM5oPimYuFyE27j5CrpDnmhTFarF1ANkpHBYrNh852q/u2Z3rP26vxogWSy3c2zGVjllwUw" ..
	"OOGo0L/zDMaUvA5x+8VmlEtcM1urgczp1K/+QMzzpgkHATIDAuRxEpy3EljzTgwbAegiYFM+oPp1HAQ47rzKBJJMoxIt3/yPBJAO" ..
	"+SjdsZgMRv5c6YX+HQnGf5ND+oKbDE/9vq0/dnKqSe8XJigy+fg2GBnB0dTPHpWNzTwWWFiDEJ26fK/eS3srBhk0DsWrXPHNdAcF" ..
	"e1zFipaCtXzBQkJSc0zS70j7MIOroCjeA3l3VBeSF1qeO7X7X6Cz6ZTTBnztofRIqtmXUK8pcRiZSe/0XXwsIsgtup/j5xc0oeft" ..
	"a6ZQoZHKrtZMgjLYUQ2jFBD4zn+qhg9r96zubEXI+3iBzmLi4pZDqqIyHHjpli9UP1ljJ5Rbf/FC3TETbJ78ZkKS0R5SK3yIYffX" ..
	"cA1zlTMVcWQRwiSdALeZcwegEEk61saraimHgONt8VENSb1uR9d9XPNjz6dieBaXJK1zJy6TGZOkf3a2kYSdkdaiDBVoV8ZvN7n/" ..
	"ntl6T6rggs2L+3PALAh3zJtAF49UKX4VZj75IFUZAOrviQSsSwrY0m/Yrhs3aGVRW9XhS/ygEEfg+WKIZxqKUsABqLbX7ESM+aKW" ..
	"59IbDvseAkEd2pbnzq659l2QUZH37COfd6d5Zo9IhXhkWl5x8GowTtLgu03fWAVX6ePzwetM2ZNHD7+xcBfAfMkK6tY9gYwzKwnn" ..
	"90xk9nwPYBU7bO4FGhdwyNvJaPdSOhC0DUhiM3tFIGofKwe4p0EMkV4tyf4CzD+G0knp5SVfK7dPPgTN7oWGXplRSqAf8qGnfPOa" ..
	"wYFNxdAelrmEEO4PvLb9yiiLhsb4tEWZOZ86WTW0hD2/PwuIINn/LnWyu1hDTwJgM1PocV955rd9aZwTUF4pGADUWJZaBbVS5jzw" ..
	"xPNM/S/sYhL8Hz9VVOjGHKdYZv9PiG5a1ybClktRm8Vaf0GsSNYXMFoUZOWZlM1l0lh2I64K9KjI/hHJy8dBC0vsy2+MRB/mtolH" ..
	"x21u8/IS3JGbbNCcs9VumhFhZxHd1L8fz9+fsr9TFlNMZrQ+DOli73j4XpMftqACtU1iMiEthgQlsxw6Ln1JFyf/WFlVdSnNp7Vs" ..
	"SsSMHMFraTZe5P8QwLOkqtYLCCK4d9gwG7e0r/uIMURzAmYp95dRjNxAKoM9dx34+L1aAgxkuRZsDRAAF4KuP2UQuwpz8vn0Peet" ..
	"TGmRD1HSTZ5XXPySy20SdxbUPdpeHWC4/V/Xjwu6ujN1iYJ3b1+2RstKRekKpCC82vM72axdBeJQWdT4Yh4MfvbCY9mV9WEejXDO" ..
	"1hChgNWNgETT+7fKOnv7ZgEsJR8P+FNak5/2JJythGm+bS0E4WXBgRE6FL/h22lH5G+AnTreNrCI8dUSfnNGDfLcvOEnbMCAkRRj" ..
	"NnuZpH2cZbz3U/1ZK8dbB0oWwb8WVw23ZfnGzO2sCb4EXTW8Ta0kY5YLx9LE2+Z7M5gumZ4INPksB8LLijAOVSvGAPkGq+EKpV57" ..
	"nEPlJjjzTZlFdXF3pw7AqVy4jZ3hYL1SgDfDSvZPQwO1RbxudsfRvpz+u7J8r7BA/V5a9BrHFxBHIIeLIeCr+W+0uHL2PbYIEZdG" ..
	"tlCOLvaT9IwLEIilaW4K6487BxMJJFRrlsOtrm0iuVXDRcD2OfdrGretLPU5G5c5f+jLHAXKYs10ssW22L3o3AVuKkNyTZS/lgZc" ..
	"duxy2db+xAvuuTsewUQeuqvA9dXpD+wyGHrj9rUT046FtiizLIRXmAPKRcN+DjeXvEjuyTyswk2j7j/56eZEvDxHx0JxTYAItLJ+" ..
	"XAf+ctakUf8uvolZFIlqp/og6xWKGguE+KxMAttxwu5lWzftvMTiaP9D1ESrUBBGkrF8GT5z3AjNDmsEAFOnrfdg8ncjk09oNcRS" ..
	"5fDp5ipGoNHesfRqplIUpnWfC0uDlkYtcPzmqF9A4cuoq16S8I0uLD41rLijlAtSXPU+4up0zZDmcvAYbsh8eTsljspSyBXRqCQ/" ..
	"wkP7L6Qy+W9T2U+1o82pGApV8B5piPbTzHE0QKYf8ZZLVkFTiJiO8q6AuPexq3UMMdbPxTzm/i3zjjOF4khWAA7klrD6W1i8+dVg" ..
	"OpXJX0V2XrFHzKxk7Ckr5CX68aB9Qe76s+L77K7BxriT9eub9EWi4Wsutz2ZwBO4SdaSLGXrL3NJsCjzA7cHOFMSl80fjQTVTgwD" ..
	"soq2uYEDU8ZM1Ef0KzH8R+RVidn3brcp4FJ7wIu3gvBBtglrnBWTXNWuAG0t8BnpTus+JYsgZBJfxAJ0em2ok/O98ce7PRV70Yu2" ..
	"ZlxRfp2tAFypnT7fLwat/nge2ov6sf9QAsuUQ3X/n9DPYwfDb0HcXidRtS7ekGBLmNUm3c68s9uZ2NxSOnlCW0FUhCFVuU257tmg" ..
	"QNFXvazwsLVFnfpDHvDwDn7pQRaZsu4NgLKMdg+vpUdyeHezz9YMkjKM+lxi0nZXC7zUJKaeK3EJC0soB2Ab5Ke5+CLpB0qN53IJ" ..
	"Utmsy4pHnLXBLGVb1iOMa2/M2x+ATMyDSg9zDwnMyoXBvxzuOEtDPRd+m26DrRLukt4D/sLMkZHYb/xgmH2aaVpRg1qaWoWAuUIR" ..
	"+WsGHxLqTliqGyAbVb1LqhkzzNr7BYz9wrdTgkiqZiDG4Ma2hIIMtGNTshjOu5EDlGP99niuhkhMpOwaCn+sXIU+sbIHDBbYQ5a9" ..
	"VWQlErw/BRFO1VRuvwgkvo+rZ8vkAA2vXUTfuHV73uirUbSkpEtlzQFniiNGfkh6V3rXMYVqXuHaYp6BcSUy0egp65uMEvka08M7" ..
	"ed13TacfHoA6+Ax6dD4/4LU94ShCIJvRwRp8QTlPHWn4f7u6vtTICnDWAqN0vDYIFdTbR+kIm3f85lEOOaU11BbRnZda0XPixaxp" ..
	"ahmB8q6ce//2ytLZDKWvx6/uSBGU8sOlvKZ/2scaJasyy4l/VT2ASn3xYYlvqbP62NxrCMzZSqjPJs355pyLJoGz4AJoR13qz8Vr" ..
	"aZ/JdVlJ9Yu41EVpH8WESoRmM/QFCrnlKYIH27ZKn90h5VXS5LFptKj3j2dvKEBJk7UWZqgQ5ZCgxfgy/aLhDP1dJd4exs7aBszs" ..
	"SCoVUI10qV21ERgzvR+W3bbZiLKGewDcSXLWVNnHGVnIiTLof+NgqYQ7HScgdxqXGnckN4SXc5QaMfle9LElqyPoGWguI9MrkcSG" ..
	"4ZqnOzB0CCQ4in7TE99nCekoYDOMvtySXidy9WUGllab+aX56N9qq5i1YPB2lNAZ9RHTMuaCjUTQwk8izGRL1hwOXiTs1oGKMl2R" ..
	"8N5nPIdcNbVjpj8tp53fBnYrffliHzpLfAnvAJ15k7RXRwktIyfQzXi/G3yLzhJle7xSJZtesA+utBsKuq07PZiOVLFiNRlD4UIL" ..
	"PSTSfmF/oQjCkyvrH8cXtEv0gHsLphzDvyA9wZTx401RZqaHb0uC8fy9Q/mxx2ooQzYjliea1TDjQG1L3oj4rP6pwQWwazM8KOd1" ..
	""
local PAYLOAD_P5 =
	"TcSgfyxHZWzr5AKLTiBQftOXW7UWGAoSN0q1g2G8KDvM8yZo1JoH7JlkVve9Z79YGZsIPcchxQ1fyyezf6tI8gJv2WfXMy9BjDRi" ..
	"HQF98NvqG1FFXuIzIFHi0JJbO/Nu6qQQk4GMkbnNbnYbWQIpz4suUrMWMXsSaK7RrKxRNy8Lu4T72n/rc9kpu/TCzS/hPOyBC54P" ..
	"x7c+XHHVuI1wbEQ194Mm+dow/+vxcrj5XCpeTO2UgKnanU7XCPR2xNA3CIIPuqj4a6wKM7vgiEClzamYQmo3M33yVOvX+yf+oXPP" ..
	"kPYVwmSIVB7dL5sNOVRya11E5Q0qEhb7VA1cup/J+r5aiLwHcFYaYdJhWpQLDUY2a4FJTHBN+tydWEScMc4tLWFJ7w1nhGT3cTf9" ..
	"MCxr8UnoizlHdK2kghuaRV9SvPrZOEpSPYaoVzWOE8nmHaDqrRMsIfVlRhxAugU0tEB1YN2nzSMu0Nxt+eqPn8r9j7rZR9JJNpwD" ..
	"L6yIE40F5paTwBZikA3rpSH+gRYnChhYUvjKpL18FpPdGplz1EfILdLSKfK9nGBbh/tHoIBlAKtnyEl8QNwlENtBk4w+FwnEiaXb" ..
	"03eQAN6IT6Z+qy0D/U3p6S+qhPD2bofZW99tQdi0CPBaTSmzxAYWW/NWlzwYMtd+2tuA42wsOUDso8Nt4Ump2HBtYQE0jYSNWb0r" ..
	"YhhXzCLE/4Ry6j/P5/dzw/iy9Jfede6uzEv4EdEy45ugvfGeaWKvg8tzECmH01qr1BPv2avWpvDPHIa1vQ9YzousFGnxasQZshlS" ..
	"uSyB/nGxR5btBXDswQ+nfYkrMyuqSsm5sLBnlQBiUcOOpwV4xR7odzvbJVfSrBZeGhsSSVAh9rtRpcT9Hle0+ZVU9Sogi9N6de/f" ..
	"AWZsqbSKFlQ9OKlrsM5fWBuHMOfZTlR8InRhhTsloVLoH7ZluVk1fkWbzqeey4oMEVqGIbgxors7I51aEWUWcB6ZF+R6+ClBwcH1" ..
	"Wr8+KIFrVxnJOCXxUDKuO4qN1PeV+eiZFVtEMB8sehEnz/VpZmWSkfguPu3nWfb3YD8SGIdOAZm8BtVrW4r1vgsSwzYeXYbjkxo4" ..
	"KLu5cPj5ldAeyAjpwAM75iLejV+MvRKDEg1TEzeOIEaEGUvfYBoDZqChuZWotMGjgEXRl/mVYFrxVc+hHV89lxqTHsYgA8M0NjtK" ..
	"PMbMsYY1KnSdIAyPOOlgCzvl9WRUFBJpN2dvHB0QNnUzX1Ga2NA3q1yzRBLo2co83FzE0EsuSfEKJfdtF5e0HzMTqbGWs7Y6XUx8" ..
	"9/hk+8Q3n9biZnG7d3pGY25X29iWBj2aliCDvI8GBnWr/8TSl1Mtk60LKoCCEfFBIFxFvAbO/e21SZOWNERwvEGnxl0FvhJYJXVD" ..
	"iwlD2SW0wQBvp3V6+LNl+XkXUV98mat/OAT8ZNgJ6gaw9ESUyuvT/4qdSxUyBV3LLwOwkOtV7LbgLC1suQxeqbzPhfo6d5lFMxVo" ..
	"K0mBM3ehID+1wJ2gr90r+atj1fwORNp11oSK6CKZLkmn+2NUwSYYQDHYbPfEsHcHPX6ekTOLYKt7beXhbF+3WtFbJIPMHNlPJUF/" ..
	"27jxa/E+W/B1XItCR/z7Auomit6HB7hnokHPur+uGBqOTocv6TUCHVUvjK6s9BP7aR3ESg/DhZaG4CVEX4qsdEipl3m/2CHOGhvP" ..
	"FxnDayPlPk8qcuHSImff0YS1Z+n7p0sTTwQhKMm0F9J0VcHGspvn5XC8Eg37VKUgJs37sBRICeduuTMpks06SG7ed1vTuiqkWosb" ..
	"T2G7/ZFOSpbjG6fmZilIcxX5KkTNcuLldH1aTeeGAdR+du6WUVVliDHgfWttQuGwKeYj0S2Ho4ZdMXXoud5GCx6zEj5ZIAK0oUwm" ..
	"4CHa71Iqbqifpzb3MHufZQcPBx8xZjqemNgHP0g8iB7jkAR93/7XqHB3oXLI9Ei9tdDUIe6iMW0jwlCEbkjSQ6kDW5AxnKwshWyO" ..
	"wmpkpsitkzBEsMouLgu+ZJrK3xEPusxKPZuNTc6LfnzsgWdTLO0sBpnegB9BHbw2kkBqocs9bHipZsmVmeAoeZ3Desy4Dk7hK17A" ..
	"7Nai+iw+Hd7O5KHv7d5b2qfGKEm9JnVxRvcflW4aelyMbxWRnL3o4ULmMoCZrvYF1G+NjUsGgSY8TIOYlMHnPTKgVuDnTkvgHq1P" ..
	"tpSVwcQgkDbEgWNFM+GTCAhZ3iinSq9EKp0AxTgQG+wPHgPl3VUmf4/LrKCKHCIu5Xj8RSFCgIEWIAnIN+j86u8EHucj7LUQyAD3" ..
	"iWoMAXBlv7RBiN6iUC+mRVEM3OSlXTkSMZcIMXyRqynYyqONUxRvT+J/RRjcRYQw7vf1PoCDz/jMITvxthP7cxBeMfZ4Fs4lsR3j" ..
	"R7oA3RJQXNz3H8N9qLMMf2rQsyQ4+lNpf30B+PuTiq7Gh/HQBg3htdqzTSKCS4ycuxeDEcQMyQtfLcr0i2hueaXOpUg1VFtOYXao" ..
	"LW1dRXgS/iCE1Tj0ACsJfpAw4mSUdNr8opeTKwQHOesnKFxxocRvk9W0MdNXtr1ec+rd9m06WivvgFMuP619uIQF4NrL8CgukV/Z" ..
	"fL/JKSixcGYYdMmGxPRvQF0kYSSFYf9RPk0lb2a5YtKTslD8F2pykx0SU0veFX3+zh0eBys6EyuN1bAHQHM+8kEoF9B79P82QI/h" ..
	"b+rtGnRNBnyADEg0DgvlSqwiWql97KjOQD+NnO9uROZPJ480vQfNITOhkHZ0cfirXc1zgRWFLcCh6ALp9P7gWLm61N9nEriyAny+" ..
	"3j7d+VS+XfkkANtXOEGkdj4T6tCOUubZY7AjUr5ObC5USujiMoPKltht2Rk9NBUI5f20gkhWe67Z4hxAJsnQbzDaZ58Lj3ARiuzR" ..
	"YmzUALddbazb379sYRMUq8pvHacndtNAp447ux3yKD7JT5iCQAgXJI35gs3CokVDg6QuX42CtZVPzNsGPRcynpSt13lVUWkzXP5a" ..
	"4h42Oy9sDHOiZz8PGL8+K3RFk6tVwwm3UlSxo6PxSXMq1zjF8JUGuGUwHs0l2ZzgE+vJX9HI/gpEWjUZurlcWUvH3BDX17371Woq" ..
	"/QfKHnfThn5ynJ/G3NrfnBOgosZWA1i1ZPBJgfcRYx5ecoLkSkU2IAo6iR+gsPPMjmKeFU+0bY/2K+DT4CP9DnSMbVtKIpXI3ysc" ..
	"qsytOL7r6CvIAc6WHg2bLm90HFjBd9cf5sfBUncxWzcq9yEalJrc8UNKWeTXz7yWZMenhDo5qFCWhMn8Dv4HSCNU5VuaUsHVlTGF" ..
	"3fpno5UN9Mo7CYx0W3EeR9rE8SibhnZUjXjRmp24T9I3KXTXWJG0F8/rKJyA1Q2GLkBCmZOjFbGdT1UbuYLiO0+O9FhrmX4+4ruq" ..
	"s0kc84RA3tXV9pWUDtguWTheobHgbliWfpuOaB4UqTQzXSSsnjT/yiQSA1VHLLKnI8Kpi3ovWzXV4hG6mAHjP2ZiLFGHR87xrAoH" ..
	"DI9OAUHr+yi9mzcdwaUwX3qpC73tcxML1DYBpHcyGBGqknuFvwu6qPStxaZlz1WduoJRUzQzATZQiepEYidPN/+kevYPsgnmSqiW" ..
	"w8+K2BGklYUAikKOUL39CpD7gErOG/XzJBDEmhphiumiAfqZVcKWe8oWuQamyIFH/is8ez+DbjIATs8nbB6G4AOBEvm0/y5hxHJf" ..
	"5EwECIH+5zZhFq/ZvrflymHcmPnZ3e0KstaaT6lzyImHWyAoUA2xmaS9Nx1ErOa3LXIzUSt7/V8tQG6yeHJE9S2vDnG+cIw0oi63" ..
	"l7j97tBdwHojQ/pioQOybQIQLcO1jVLhWSF4J/206iEVobLS+my/VUNi8FCwy2CAjbsEZtAP6YN0MwyO8OvtLgs8K3P8rRzVJlZy" ..
	"8yGeNgGxRTNFX0hMGk62AV3Y2ZeACD0JDPPW1875/lITkm7ilT0QF+Y/EP9gg1Leh3GUUuvyVucwElR4qkdb+gRRK425/AlwxE3I" ..
	"DZj6sHS//gp2PKZKqMVTqwWOqtbOi7fqPUul+H/zY8qsO7QvpmluxABq9Ug/pB9eNK/xdefHkHjT5NdgQOmOrt1tj1k15bnF6KQ/" ..
	"S6x9s2xuiVoP1w4jlVj9aZJ2/zYPFHKz+91ZPMo3g1nMYWV39EjeSiNd0F0UtjVmzAg4oNuQfj5TY1qPwKmsq5PwA0BpcnP5/mfO" ..
	"ug/1lasTjd4fxeXSN6grxZnOR1C535b1+G8aCWP9U+rSwnp96qUlNhHa0UGNozWzVFeut1UmAc01f8aISwly3ZO5THcCLp/k+zIw" ..
	"vORAB4Qr6ULOD3UHNYqACW6O/+pY0mFAqt4x3G7AvGb7GDZaixSwni+hJopfufsIkSiE6Bb4b9G1n5QkYQTExLHHhLou6RapKBpj" ..
	"e/KV7tQV5+5O4keMBmLgnegyDbL3LA9jIyMJTF4F/REsH+/yb2SEZ/qs6I7lhHh5f5lIPS4ZWjrAbFVM9eEUTjNuM/jsWpzGMap1" ..
	"oJaC64Woo034Oq2z0ThFY5ySHfKDTisF+R85YXhHfXDXWbJQNJOqH11THqOnAA0eJTkJTVI9bFjORWwYpLoxzTHL118UjhumYEAy" ..
	"jc5W3Mft9aFWfVGa766VL7BRgbS8ldcE8ZNWz3cpYIoWdcOEnV258/Uc/ytdEU8KjZSFgrJ5/PtvbNNhkYSyaUXGM1AWO+uWmnfz" ..
	"djikVP2ZL0cMq5Lj1Wdqf29wX8kOT31xZ9bNpejp/8MkM7xRLJQ7VYNUKKUJMDaZslMIUbX30AVFv1uXei2lv9K6jJOb9eCLMPCH" ..
	"fG6dZBUe4UqIt+n3xswcBFy8lgRyrajmfUM7l0D1qMrUbcqWcJ/uUlAx22l7xGUxa0EBqIhedn5yPojJCIKCvzPe/TmnOyGK7FR1" ..
	"jh/M9PLRCV1EdrfwkcSMWbVFkUzE/zvSOvBpWAml3x7+qUxc+36uTEYU/1XxPgkm5iyra8ruEWDk0DL2C5Gq9/9fo+E16vXw4tkX" ..
	"Miz8f8e9OkY09FXmdxpkCo+4xsc33fKaUVP/QC2Pep6LwDw7YWmAMMTmfVHT08cDGQoyY9tIFKGLm7HKZFAT8pQL7KUYQnS/ceFi" ..
	"rs600QNkHbKZN3l871F7EaALjIiDyeADyEZi0rM4CqL7SJGjt0A2Z8ZCVWQxqAsjbNPCT7nIc+eYtdaNMa8AinlUf3MX2Q5v1bp8" ..
	"dD/H4Sc0As7z7hAnukN314jfGNawvChoPnJOU4VHfegiXxD5t+hAgt02JpS3mZ7xVnrtyWsZaSV+05rucRIhNtsD6KS+Bq6U6kjw" ..
	"W+XsUpBhKYHXOIpd2aWZ1gN6+foYM0KACumse12lihsbHR2JjeaSQy97tjbUpSzdx2u72+yyyXPmXKAgnpMXHGwKuocAMpfIZUYY" ..
	"a5TY8kNMOrylzE37k6Knk7EpP+meyLnb1p9TRPx7a29JQDrcFjerD3Cz8EBUDktm1zD4fnCu9TCi2g1dY9LJeH7M5/QxET/Kyvxp" ..
	"F+bqqpblsCw3vZV+fG3kqhJCyMmwoh2PFJeUpR917SoOgJ2SvFPox1XIqeAUggFcrLWx1VzKeqtuRsuhJpJQptr0u8LmfI0w5/yW" ..
	"FLiVb1FhkKwEGvA1QtUK3iH/REIRuPFCGE9CXJarEpv2FRbFlhIqbByR21bt+cwhfdpw0wOfbP4XqSo5k4Gazi+cFk+HWGEEA5ig" ..
	"SCZoK4W6KDrcAquJL2fXUwllw9CpfplEtzqX0D7eYqhw9N9IdHMVVFaBF/1yWmlbMtIEnsY/WlLqst/9kkjDTBTu5J9RIch1C5Zd" ..
	"jA0zop2wv0HT/9J77Vuv5adUaX1s6XhkaxTYl/PKFFmQA23Mye/puPacbn8PBv0vK/xexCVeVy/mhUB/B5Yl10tu81t7rOD52Nf9" ..
	"SQbpR7wyjXuMuoUqXQiebzRtBbn/kg1jSpEkgHLy0el9CO+I0xzr8/dv3Ka4siNNQ/6K9vazSjyMstn98vlV7m9yqZwyZysjaPgS" ..
	""
local PAYLOAD_P6 =
	"MPI5gWy/iXbbLAHQqT3V4NpplXJplvNuoSyXekJq1xJcsH59KPxsX+yQtxQqXPz+GTTPPHLgXFWHtA0vHaqt3G6k9JJejLDmbv3T" ..
	"Yn9gk8sA8q8jyOPdjZIMHeU+ia4GfjZNph41tJ5SLNBa6ILvXeQHuID5tsPu9cFoKAwMlEoPFO2rlS732keVoZaWc/kr0Zqzl0gW" ..
	"cXY/gZZtFC51y1f+vO/rtxlTLun226Iq6Hx1x61/pgdwt468aUQAGTFjoAr1RFf7nE5hdIGE8hWu9MgdvH5TApWc0huNs4nRFgqy" ..
	"t9S88+uwNfUaMsuKFVNb2TufwuqROEv5QSHX3sGTUmNl6tV/K1bFIsEHGAD/JELO8UFzvXMNIV7uR/0BPRCODjPwMjtfo5jQhbas" ..
	"eVml7wRQpN4ofR71s33jqK/wGfENg90CkAlImpeFx8ZtQew2EM5AsTIXc8P/MrBocWERmjQ1oSJavny2olsHzw2xudkNvyx6wnvV" ..
	"ye4wedeocQWWDlTOw0CQZc5uWqFbJlG8P4ivkoKDmsQBC7WKGujsZLdcDK7zuCrgdBfAJAG66cj49/5DfZfhhHQNSNxmWowKHt/x" ..
	"fss4NZ+OZdWllmA2AaNYoz07Meww/wXRNtb/5pmpUK02lHrYF9oN/MC3V8INPQmpxcGKnLV6z1s8vBn9P5RxUUAq8CdpWQ2iC8Wj" ..
	"0/Y3rK1nQ5NEzg2RrurOzR7SYz+3i2Kwpi4AgCMnpbrh77Qxs9rB+iszLgn/6ZAubk4nb6Bnaa2MYCBWV+arxHW/gyM5soq545Hc" ..
	"7tyyv/D3zMZbxT1pD5KTrS/NST+taRjqxypmJEX6trUsMz4iY7tphpzt3b2vmYeh3WptU6c3Bssmfu0ufJE3yi2q5SLMUYBm7u9m" ..
	"uPEPt4WJYMOo4QWvia5BmtOTUXaN/NJJuVkPYHPNbk4q7f8V0uXxexkthmpFXGGIZsWHlfc/eWYVM54l4oux5BcfP4cZLSFrDQhu" ..
	"qoJvgVm6JH8ZbkfnxOAP1twPGquq3Uh9g+ws3NCpprSBTv6d1z+tjjsuql7ZAdSojmjg22BWrNZgidrHXzcEoHbr1bedMoM7X8wd" ..
	"kwFdd5Ez6l0Ezd2TEWYrhqU1ttH4Wp1SVrcmDwGMLA3LtI96e8pP5K1977o41ef8aZDG1VnbKQXqSjCqapvtctuqLLX3nlafpdVc" ..
	"GHZYC1UaMLAaR4Hb5XC6q0etsmB+9nJDZ3W5CBRZpn11sxqC1tDmTAj4k0WSjVPTe5plgoG+sFgKAPs79+ixdR1x/fBnnHPhmivl" ..
	"fM8ttkWZ+q8RcEUevCM2qGyUuS4k9RCamosz4nqui2bA8+zMzCEE5+7zkeVoh3opVBErJD7wCJQi/gsSBd9gYeBimnkL9/sHU9e6" ..
	"TczdG1Kjh7VIlheJBv/6fL0Sc8EtIs2vjkroOEgIoxgBpQ55pgZwORzaQY+5jkTlDYjiD+r1U2CeN4NcJzIQaxzI9y9ID1diSvuG" ..
	"T04NPI45sk0KB7zKuUZ+9wJ5NJmjsD43B8QB6S5JEt5oHUia77jF7oqTGpqt7fAVROhDLa6FfodO1FjmwxXgFLV+7rTSnJEOBRTI" ..
	"+ujZpur1YqGLZpvH1eUE1ToxpVIzG44+KEFZGUElJrQTMjvt9KGWU6jo9oI+EucQsWVA3x/J2vXzxfDf83uMCJXQx0fBbfL6iwXd" ..
	"tnoqHWlF0KGP9yuCTON4Qjb+fhDyTPuE/ky4tCUzv9TsvQBXOUQNOWl6WLYwu6sRZ8J2xRESlJKdLrBDfpNB8DbywnCGgLcDbE4R" ..
	"0FEGPahtUaN4nR6uqiuBvdA/lIkYF53MKOCr8QsQ+08tZemnAMcqVnDE0X/U1yZr69IZQOLaOpWLnZx4W32bjGlrVlMxQNs8HKo9" ..
	"YJL9gKoKqlMwWBpzbx6HT41rR1bovsvF109inf/pskaoDjRD7MmyN0T3pV0EBOIKh76a3xaEUqaYB4s0OElncnGXr0OPMuJSCYp5" ..
	"N2SaTZsYS97nT0Ufo4QFHOrPtKmUuDnyQUSFiDRBn9fkc1JlfFE5OpGD839IM0TCsZrRFjh6RcrLx9j9Xy6c55xJHY6kIzP3Nzi9" ..
	"LzgyM28k6OfMiztj8CNevpJT41CT5d1TtokTFp7E37xfq4LxgXDNpcOjxRv/If+Bj8K0bmnfL14GNgh+ntouW9/DgAkm8U11i4ob" ..
	"NWpzB0ljMTbi6tVR2WQY1TTzsLI9yC1KGOLiF/qNSAMq70qQgJ62Dy520sc6qXkJ1XkN55C0rfmwLVb3YYcjxkuLnn4F2UA8OGLI" ..
	"bP3vW6QEeWwQbo9D9byD5kewt8SPZgP7dE6EmQ7hi7VvP5rmULp7gm/LCwqmBYy/+YTMEHDzb9cE3FQ4XT6mOFKn2ck1UdMMRbyc" ..
	"9rnzxhl00GdkakjjbXq4GEsVQmKJJ5BYuAww5/tqkrwLzSw4AtEqLmQg25YvIoDS3RVij2DNPIzqCo1G4Ec8w2oF8uGd7syJArB7" ..
	"MedBZzllTFb13i8XwZEiecyQ7gYEXuxPGF6SKV5yIcSIa3j9q25ifUqRMEy+CIDRhQciy8y9F8M5hsl59p3h38Dq8XnSO5ruZIDY" ..
	"VEWKkQe0uKcT5M12F/nmm4TyC7eQRqbGdfOY8OIErWylyqBHRxLWNxqYsYD7lbvCQWoIAMfcVGbXujrDJ1R4+Mg61Mx8UKG1A76M" ..
	"k6e2z+4bwfEKnXFOkbQjS2tX/o06iI3+if1pTA1gVBbgukgQ9lmU+fQY1upSIHSONeq7EkLboj2dNKfSV+kSKyMgiTOqgewYj/yM" ..
	"V1pqc6Yj2hm3lKNIOMcJTjYD0QFso5otCUJQkXYzm5hDROAud0yWLHob5WGDYEeXmLrnwv7kkrViwZSCiAyF3pUxV+lFrOA+HrAR" ..
	"Am98gJug+4fes6d1YsXlWe6VcSZqzY27vT0aw9G2e7oKrgBmdVzirsdm4m4kUiM2NlY3b9iWL6x0j/CvdXMI/PLB7CwVUP+IC1ke" ..
	"DPCB0TeZyhhe7FaisvjyrLwUiEdTNoDlhwDZVLxOQGEh+RTCbOrJRiW/i12YmKz3FsgfVwTwQ5q31Zo4c88Lx4fSepuW8OnxtBDn" ..
	"WOuztQKTBL31+JRwIoxcr8am7bHQmFjlDNx6tGFmo8HA8WHJjpIJZM0tqx69lz6hL6CPZVLPjlXzbSff8YyQEsgObu3FoYFoAokI" ..
	"w+kxa1n8JyZrn783ojkx2PdFfxLH2ZbJOt7i4zbEfMzn7J9GpCMsOxpEJR9LM+D1jC5vFUCSg67FKnQpaQaXuj/r2nqCLlssuC0F" ..
	"X2KIiP+XJIkcc1UhcjmZEUeyME5luCXj/gsoRXIkoIe5ZFuGcU3hk7jOtUNfyebKk2LGm7h0sCviYv816VbDFAwgpSZSJZnr7elq" ..
	"D8gOXihVzxl4967DHwNPSnvOphqujRdRRXYcIlXXkYJ/mnvXiA7v3SMOPBMXg+ZPqapSR5AIvF6MBZbNQ2EQUxj9Y/dTteSi37+x" ..
	"+bNRBcaVj+6xR92670TC37IbKdwW7N5ZW4HxN6KGtQI2XFW8P7gY4p7Jsi1EpQnDD/GFdNboz3FKPMJ0uTr6edvx/tkQoBV2mbe4" ..
	"txJdgHH50Rrbp+VKTuZz9vFAPcy5XskL/6x1bmMCfyv61lO+S7oiaLQbXzAUVjxjtljkQEEX4MTAW1hAII6Pb7EFpd/t5diXEFJk" ..
	"r/TCFKGO/GyuF6iQwqemKpaJFrSGU0xU6DbKNuJ7H3Vz9IoaqryEgpLUypnyi9tLijpD2hh5Q7OdFd8mddlUSSKcdkwdhZDdhPa3" ..
	"/TSoKta1Y9N7jJtvbm2ZcxZIRNVnOi38QbBl9qsXSjUFrv1IrY6lWJwK5yN614PFo5fzhByz0LYFOjh/6WiPBOxEN4Fpkx7UKabV" ..
	"WnQ2+ML2nthNWSY683/T8tHmIGXBcqOtjWeH0m3x/RnM02UHT5EGdtXM5hjsUQBP4Oh9eBND5y8tIN31df3Z8SNrxa4MwRYxw7QF" ..
	"tGcL7Uljnl+ekv8h2INoE8Ry3/dFI5W8uSS1K8MLEB9g+mszZ6bd42HGIlhB2v1CXDzZ3zT44xNU9kpQYrJpyWhYlCFL+7nJFsti" ..
	"sk/wMJaLGy8Nbgc53/wkZ2Ag7D4xjcsbzuc3S1Buk96pn+Prly0X4FvhJVj+3qUdWuyp8WNMj/uXoXg/INtwOi+9+SAdEhfPLIh/" ..
	"wAXoxUBMqCr5f3M2SXFgDDi1UlVTeM0PbX6jIvnqLT6z83323llr8kfEO/0HaqfNd8uOBaAgN1Ia8aqprZf3EKbhu7j0yYrCjU32" ..
	"uqN8DCCRcYzXh1rCfYorrdgR2c4XkSXTz1t+jMcBZo1nm7UcoEXerNwHA01/8DyrCsXdxFmPX/tCZ+BV9JMXOs/7U79F7IzUq955" ..
	"s8cz7dJaPP7V5Rndq47ynTN0olDHirGulmRPwOB4QCyE7ZqOaPO8LYPpjR1V+RAt57XUvPyOFYqhIeD9RB+9D3eDy5bt8Mf3E70V" ..
	"457oeKgBXGMZw2hTX3ohzqXD27VJiibhUUsmrKas/Fc96XoNNNTd/zVRLU4ruBMFgWAjntGsc17Te3+ydHx0pyQ/HiWUW9YJ1BEN" ..
	"2fsBBWRlHwIm2YnFv2pinpWJx9WSE0H9Kp7yTXdFK4khxnt1GDK8fJSpZR4hBLuKVCbCamIk84IwmEXce1MqFIYGtgJFBY+ZDNJt" ..
	"Fb1XboGVA9ddQWHw2xphS4vWzqpNo4IY3/xpwLayVc5XlFx5wjSoJWrYSxHjDlTraUAxeMis6Fnk2sckdVzHOqjn/l3+g0yoo/P0" ..
	"1TiJJXKXoQOd6elJITrwUUG6+MKMFOdNHRX7gkLkLC0W9QzkGEMesNb+UFq1G7aZpPKCGoaMKGQGM6WpSQQTTpCHrrcb2jf+uNZr" ..
	"f7cSCxaUR/KzLi55yAZQI+jtHoqlesy5pqfI/HcVEETkB4lw7Xfeu7N3z/RwiSNho4ENl00XOmlmqLfPDh46jDhfIuOyZxcq3w4n" ..
	"lq4CMkyo7ZZmxjM6ijLmiUC2PI9v5q80XXP4xAZZzWNaKDT9haYsg7DRsJa9MAfkjKn32A3IZD4HqOb2D9S/ZkzbA1wS3n4ANbjL" ..
	"HE8/fv3TrF4bWcGYEHkd83b5RWujdGZFJdfSofdEYhgVi6hf4st8MawzUBujaD9s4rsvlNP8RKRzTpaf4oKbagDjemnsVmaaBtci" ..
	"G9X/c/OhjrgK9Rl22PoZJVlTnQDuNETtLuOPri4eql4Rb/VboFkuUDkogBhSA8Nwmg2D9DpP7JIW4OOqgb1EiU0s1nl0URBE+4g4" ..
	"Rgcvod69hqRUz9OwE92EkSB+dEySaWyaAQojs/hjAG2EhAuMIUwEf+fnF53bPkVLxFnIb+Un46GbbpJxdadVCid8pNz3DkIZjkGl" ..
	"vC8PQnxstU3EA0G2+KZLZ34BC/OSAaHq80jrWiAPyoJAzQL2isQbfB8jOs+SHfKY6XXhaiCh4wTQMVASg+xUo0GgmdPVxMBcydGO" ..
	"PM34O/a70/Y9arkWsXnvR5v0amMjsRkIHPK5sCRh6uFNi1zjcsgRFz38di15k1tx8LGpe+xdhHuMLUYnOh5p6XFezIjn+7/6ONQX" ..
	"TNLTJ7DHQPtVSZDk8aFMLJvEI5qLtgfVhBmuVSQsLy3MGBkXq9BV1OgeQ3Li+q8FMwTP4JatI77rK1Ol1VdwpEnXUsrXU2tfrezq" ..
	"li+D6tKltvNri1OgQxIjnxspEgpnPwQdVaqIpRl1jTGWDwyIjSL6O96JlCeJHTq7Q+asQOcHXwaGUsJrtElRaJV+p98fj1DmMnO1" ..
	"3ziXv6zvdXgIH+X1Pegtm7Cg7DY3QRrNGro/jJUgA2k/adgHEmA3tO3Z2jhKLXPTavq9sSSerF2CPIrBQA3nLgnwpjVxi1PWdWdS" ..
	"1DtXpOsZCFXeWUMcOJBwSB6QtXeb1HLG2x3KWNajEoqS2tqPLDSc1g1aG5G/S/u3E3nmqa5HVBgUd6pi7Sb2wYkpRHJ8jtWf4blC" ..
	""
local PAYLOAD_P7 =
	"7WXVo5H4jbMqtLevcl8lEN1rwrGhor3g" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7

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
