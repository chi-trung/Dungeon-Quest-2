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

-- GUARD chong arm nhieu lan: moi lan execute loader deu goi armTeleport -> neu
-- execute nhieu lan thi queue_on_teleport bi xep chong -> khi teleport tat ca
-- chay cung luc -> nhieu menu chong nhau. Chi arm 1 lan duy nhat (theo _G).
if DQ_ENV.DQ_TELEPORT_ARMED then
	_teleportFn = nil
else
	DQ_ENV.DQ_TELEPORT_ARMED = true
end

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport (hoac da arm roi) — menu se mat khi doi place (join/leave dungeon).")
		return
	end
	print("[DQFarmLoader] teleport-persist ON — menu tu dong chay lai khi join/leave dungeon")
	-- BOOT string chay o place moi. UU TIEN fetch LOADER tu GitHub: loader se doc
	-- key da luu (khong nhap lai) VA tu armTeleport lai cho lan sau -> noi chuoi
	-- vo han qua moi lan join/leave dungeon. Fallback: doc source da luu local
	-- (chi khi GitHub loi / offline), luc do menu van hien nhung khong tu re-arm.
	-- Chay bang loadstring de an toan trong moi executor.
	_teleportFn([[
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/363ff56c09e5b7e92e0bc46f69e2e2ccbc6b2e2b/DQFarm_loader.luau")
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
	{ seed = 2279322000, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2275660166, exp = 0, plan = 0, hwid = {} }
}

-- ===== base64 decode (an toan voi payload lon) =====
-- Cong thuc chuan: moi char la 6 bit, ghep lai theo vi tri, khong dung so
-- float lon -> khong bi mat precision (truoc day buffer*64 la float, payload
-- lon ~2^54 bi sai byte -> "bytecode corrupted").
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VAL = {}
for i = 1, 64 do B64VAL[B64:sub(i, i)] = i - 1 end

local function b64dec(s)
	local res = {}
	local j = 1
	local n = #s
	while j <= n do
		local c1 = B64VAL[s:sub(j, j)]
		if not c1 then break end
		local c2 = B64VAL[s:sub(j + 1, j + 1)]
		if not c2 then break end
		local c3ch = s:sub(j + 2, j + 2)
		local c4ch = s:sub(j + 3, j + 3)
		if c3ch == "=" then
			-- "XX==" -> 1 byte
			res[#res + 1] = string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4)))
		else
			local c3 = B64VAL[c3ch]
			if c3 then
				if c4ch == "=" then
					-- "XXX=" -> 2 bytes
					res[#res + 1] = string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4)))
					res[#res + 1] = string.char(bit32.bor(
						bit32.lshift(bit32.band(c2, 15), 4),
						bit32.rshift(c3, 2)
					))
				else
					local c4 = B64VAL[c4ch]
					if c4 then
						-- "XXXX" -> 3 bytes
						res[#res + 1] = string.char(bit32.bor(bit32.lshift(c1, 2), bit32.rshift(c2, 4)))
						res[#res + 1] = string.char(bit32.bor(
							bit32.lshift(bit32.band(c2, 15), 4),
							bit32.rshift(c3, 2)
						))
						res[#res + 1] = string.char(bit32.bor(
							bit32.lshift(bit32.band(c3, 3), 6),
							c4
						))
					else
						break
					end
				end
			else
				break
			end
		end
		j = j + 4
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
	"lp+UjAMbDwDqs4ansN8Ok14rTQ436RbmHYADz5O9iHrBtcSOvs+9k09O45I9Un/Vk6v1kp5mV9hfvyUfE3lqNYZs8JxvdsL1uMNR" ..
	"k3ei7BM8Q/QH2uRlENSehdocjar5gTPFBvRywPBAswEDfSRlspsKk/OzwShcrwuIJgGNy6RC6ZfNlO42E4lreo/Es8vhG9vn/GEf" ..
	"Jb8/0K7dGEYSbekyJqpxtVxVzdmgM2bQXva5JZIe18ThOQTZK2P+CGH3K/YszMyB3K4YGMLhhi2N4nnRuIiGqLPxRHYCmCLAtqiw" ..
	"1h68LBacKAFOfYe9YJw5TZIbSgwwjdM9Wn5Me0J+rLzWkPSvyMxjR8Cd0RcHB0MUz4HxlyxUKz5dOryEWb/6it3cD45g6XHw0/Su" ..
	"sE5sReiSns+O1I9pbcMnV+6CsycisPQ4QVd3w+H4nPC2FmUPYXIFYBX6xv6RIDDqZPPyNvbOOEr8X46i5Dok+RNc5nY2zGBPHmdt" ..
	"u7f3SwvCY3XUN52jvifn1ZiBjBXN0KAkbHXaVelnbspEM4W08gb9MlhB1hrvSdJpZ46sNSqJf7mnvV4Yk48ubwzo4Cgbj2ak1L4g" ..
	"iQjlTG/ncmqN4bBiArihJ1GJFVRHdp+msgX7kJmRV/Rxi94fTvVjIp9rD4Y8bHDc1de8GRtObvqIv4GvQYiDKvLMSN+ln/MlHNK3" ..
	"In5sii7DYNece0FjXGoBpu6Tfdmy3+vcsNA6vjjDlcObkuSs5LUAnDvXJ5m8hiyJdrqdk/D0qCZckYfPCdOwMaRR4yld0+FFLdRG" ..
	"h0osYNzxeRDNr6Bb7BY37A2AhlgJoR52dIoZNN2CXusEjHJeJD5kN8/kXHDunkQ4hpPhrai6CvHVXwvgRhk0YHpaDDP162mZERq7" ..
	"7HXjTm805vOJ5UL9WzK310Eb834GjHJ7UbLwdjxabJt+FOMFWecwtXohHAUFe/bdShSwMSQlrdrZ24U5XZnEfqgl7VCs/YDCP8wo" ..
	"74c85t9mn8w5rolXUJx75b4pAPOVx6GJnj8xI5lxpUiMiAWHZpM2ue87FR1Sznn+PyMEN4rv/UfRg4KfBCwJDnU4P/yrDdM4wVeL" ..
	"zKhCsk0vCJIa4CMSYQBjyjM5cckOiWEq9Z7TpS8W2wnkBmYf/1VDGqgcvSn+I43ZjQNCcILM8/yn945enWSbL5ctg01SwVxu1Z8l" ..
	"CpXMgz6uU/iZgcvTfyWMaVZQcUuQsASaCfkrpFvyMidNdocbIWZfiEXyduE4Tdc5CvHJnPaX0qBHChJP5IfNcOvzxnR6UUxiGY5U" ..
	"2/mw94DKKFNWz36b3NjsOdcX+RNtyqE88neKI4o/bYOIH3vpYGM4ikvoGCS0qf4fi98+XWAg2Hiu8a7DTAKZDXr47uXDc2LJTpc6" ..
	"KmAYLTgG3Co06IIk23kEMfQAzeqNTV0rNibM+HNBInRtXdrPFuzsp6gBpd1HWTP6aICh5j4t+eooMxbqYMCaX/xwmvQJBPuLlRMZ" ..
	"SCr10SYcVJzg/9KlcQ52JPmUM7PtaWsxBMR8OwGNLC/gEyi9eV+Y46t1PxsX+JyTr/DyXiWwCyVR3PI8rYN8QH9naeu6+Il8KEhD" ..
	"GH/aNQ6fc9GufI5Cpua4EM20pbWSdMpX03oLKNVvkzRSCMTAibneShsQPjZl4jPnGQ3T2IIoDkz1p5j9KRJ42Wxy1dVqvhfvBeYP" ..
	"nP3FyyD5Ns/gzm9dN3899B5I8OkEvruarqsory6p30Y83AXDtAQfZXc1EpRihG1qIokeWHq7oKf1pOAHngRQFxG5j3yVVtqiPC+A" ..
	"6Y+QELPbPN/FOo1QkSaihs2WehNcswEJcnTuWSPcB1aREODQwbtIXPrsrX3zJJbWzKlDGPYdqYa71jfD/s+GLkjNgAsom/pA3T06" ..
	"GJ5MqzakqJKbIw1zeseBkIMSx2K13AKNeG5HH/atk7Ik4IOfNHzvuq0ClJd+LujTWo+uBLuKOWYhiN2ackqfWsuXdLUj4TT3aM9b" ..
	"aEpOSWjM5TVA1zxV3GgBDbYQlsIesebBjhBxmysuquSLm5FMeJJnfcq+SmbCmkr2bDfOBNAgU+jT9mFhmu5MMBZwSu6elVevk4qd" ..
	"OPQIsNAala+v4VX24UllJIlb9uQT+1SmeB09Qa4TpV0r1hZ2Jq8ITuvTBhanmwcxavDdvaHtlDWR3DK6njc+ruXzV0O3GyWyPbls" ..
	"pL4998x1uYaJgNv4o9BkkzSvTbPq1VicxmeKy0aW18lAQzOPa3SSA3v6jspKCxSC4XY5sOiOf72ihRmGJ6jW42INK0QnWEa4Qfi0" ..
	"S9N/a+N5Y/zEC2phuhqRgLNfczKrU9oTWJhdQXlRXrGZVX2KsBtDXjTYiF/r8eBvOm3aO7gc7iJWaGhS3k4n1+d8UXqjwQWTxub8" ..
	"biDAvwUyO92Jkv3xl1xmpLf7ecwiiItsYRuktdOkirrBqCdxPhyXssChewGgc4ALhJ2LMkO7U2ssslt7R/trPaSQT6qdZwoXxpOK" ..
	"KW1bnky3TfV2WVsm1sx1uTC2o581FEPivuI0lnBOECReTetrZ+V69xvRXRf1QkPe1B+sjkDmhTY3A5SsDDI2X8XCjKhCErc3x/Hp" ..
	"EsoABAHmlnO0Eq19AIkKDSN6tUE0WI8NezgWbNjNpPEfDX92SSvq12wKx2RH2vV+qBKiiIUZoYLBvEgj1cQ2utTslKouqZPWG7NN" ..
	"Erk5E1tC21NKfyMkgnmOeMVTzNHPNDy84if7uYrR0YfVrzHtKF6wz0EcVPar25QZtVxDiyC+HTVDVtpms6pdzNv2F/G8bjMWPM6L" ..
	"Uq1AmDryxx9BMMXaxmk+c/W4HB5yjrGXyYfNG5xIRUSuozPRNIWOwwlC4HLPcOrteKe1YeiWrlp8plvHf4OztmVKB5inka/OPd0f" ..
	"V/dszVG4KPC/nhdJ48z7E363udPDbrVk4RiLKLng2DBHB5l+p9kcYtzN7kv8aKr61Is6H7m1nSaSkk7eVmJ1c2ck37JJQIEzT0ep" ..
	"8J26a6HLBzu0OcCEbkU/vjMtcIyNVkZ+ANN1uv1slcxPzMekOYlywmI8sWB6yXaXvynQ35nTti6HCsh+2X6o6slDQGKpf6Ns4ALN" ..
	"NB//B1jyqJz+SEgmdvQ+EWelV+TQoDwzq2hMBE69cJi9cHkjbVxuDLtWOMAAQgIjhbE3RP4qxy5cuMn3yFZO59uTD8JV2TF6lbyc" ..
	"cpQMDOLXTpesXLScMiXztP24qoh0GTD2H2m1NZ+2bUui+CX2gSGUKIB1pBDpXuhZK8BRPIDBbbVUay/5TRzzVGi+PG5hmy1TkISE" ..
	"3+5QmoGcdg7xxQPtGYqciCGntdCs38GeVn3CDTJNiiObN6YopTsHYF1oiUi4VG4Qg2IttTsUcesKJmxEDIvBLPyGmILRE5u5szhq" ..
	"XYzlyE4+PZtVVWpl+/UZXncx9KMfF8km6DKoVO5w7tXEjn+NQBxRRdsmB/OcsYq1Kas23Ncao5J+EL+PxdzesGrwG45+g8/DF4ZV" ..
	"TwGKc16kU6Q1HS7owu+DxhHwBQ8ml/7BSQsT9maZGF15VH+kGIaNhhJTOJxLqRgI7ZfyluWNKdREk9T21vs49XINqkI6x65hny3G" ..
	"CQQxZLjvhSjgxInsYgLrsDGs1mCRKK4YeoUJEWrqNaeshaGm7w1oW2h7R+uMwhSUmQinezF9ZUEGXC8wpJN2LvIEnYvh+znHOXbZ" ..
	"K0w9phmpwVyHmSiMBR9wtUylrJVouEJIczJXGrNQPGXrU5awirjZT4ktLmD4c0MidqkK8IXfSyyOvSTWkec8ohDzy06QuE8UXKi2" ..
	"I0BZjD16LvkcWd5NI9+9+0u9azgdxycMMeNWqgdhbbSERpckFBFsFtl2FHgaZoydXUN56eI0eaIj+hZJFe9QmuUbtnG2Pp79/8QK" ..
	"oJ1atJkZYAWQ0LsdBa0nwpUEGNufIIsj9iExRql4XKGv/NCbXH6Pwoz5w7dSo843YBTT4y5jC7zhard6rgMeKjrvTfn7h4W633vZ" ..
	"vgZKSkEc71rAfrga671T2FMsiifiR4Yy7yKH/bZFzcvTPtYXlLqBnc/b0rp0hriSBKVy0dsgimp41mrC4Yna24TmYDKrPyR4C/p2" ..
	"y4rtMyOtEBifpAydrknpDwYS+xcOIlfYYaRV8MMhmPsYhEo+BO0bYL+vysYgnuwSYd3S6wRU6na998ml7G5a9VBWTeJiG3+ZQT1f" ..
	"1ktnxlBxq01WGj6I6Jrw3eZ3ewKOdQFcnSX030qJCEiBsJRrX5OqhFaiSZNkwyosGODwsgZzbEuaTrAMhL3XtAxaOy8JiMf0Xs1+" ..
	"l9qxsbbq17LWJDklVA9iwDFW2YYUtZBkA5imFWtrIm0T8bNAN+qmzS3jQAoXB1gzh2OCnScpVP40vwW166woJFLvDpYQBV+L9w4H" ..
	"5ghyy/haRdpcbEtnLZ6RlDdEEsqN7xpkra3iDxciriBdopZocRhtHclIT2Q3hGQtKCx860ur2d9gEZEGSHvZpEkQSbnODIQrA6vV" ..
	"uQWaxz3cI5HIEptthC/NAAHVSQNmW9ek1lyka7IuMcrloJZUbwFtkMAISOmED4QORGJM2iVWAa3Aohf+WcXQK9zbzM1NMOgSEK1d" ..
	"5UFNuNTxkBHa8L12CkI0fX9FAOXSh3+vmFolTDhW+y1kfZY3dp6bagtrPG9Q2J8slXnOUyLx9tZy6W+0iDtRzXwK2E8rqPHnBxD8" ..
	"0iZ/k1l4quZLY4uKpjj9c7ihzbH/6dhZpXgggkQiRNFBPMNuVlZEMCmyJVyF61WHBZ2xVP+1swtKPkS5Q3L7lWzOpbAKIYxK9/6z" ..
	"XqLn4A0oytM0BknQ8LbLEaaXFdgQ6zncFPjqFSUurHPml7aMmAMgAvmFJFQEWA+/rPdkUbstgGerljm0dXvdMLTUE08vG5/2+cCB" ..
	"5TuWhurlu1vent5LLar+ogv2P4uN+AaNrnD35UppbBjxysrE7s4Hz3c7FEPfLKZenxBbAU+xvTYodvQyY014j5TGUSDMCovhoZE1" ..
	"lDtfOmDn542Quhucmc5pjgyC6xXyyuM2j3PY7wK0qBU6QFgm2EdgkiYtchCzHxB6mOKEfE7uwWlIGAc+cOfCnbOpYKoy11UU5tY2" ..
	"vGf3zxrZg+vk7fQYN5HV7tEevAUtNQDZ7mMEKeT3RC9b/G7cgWscjuXamWPS9AV6EOde0LQXRgestcEMEWlrrHe2ViBdyeeYOuGu" ..
	"qGdv9gcCuqk/TDV1gYMtESfM+JjHwnymvhzCz7PExX7VmPVZE6VYgG8fJoGAAYniGFLZATMVNmY7rgb3akDviCxvNgosZFW4ukdX" ..
	"DPvjDBmzgMnCCnfedTpe3wKxFSCJ16aPZzC1eTPv0jP8B2/H33EXCmzxHOO/39DUakb+n6SCMCDvepMSG4W1mlvzKcYuYWc+l8un" ..
	"QwD8C71cigq+eFMbUi4ybOkEQ5DCSifC7q78S1SGSuTJyBfopxl2Oo0KUiu2QtppDDfYr8WOw9mbyGES0tMnRkxyOTx6rUmV+cDd" ..
	"IWSrhd7fWxxCRNzLWIQW5iWPSn3df0ZhZ8y+USqQgbizlUWNAtpIxlkanMZy6CN5JSH/Hho26vcAP7q1NUMaQTbKlEyU892DX11g" ..
	"BSO0iMPHadET7XFUmGJ2f8IPkGFtjw1FshQKtkQRmPGtNJ9/dRtQkqPw5NaihZDwduirowqyEFZB6mG35UYBvUQTH+NATvR4VbQT" ..
	"6JjnIpvNMmMm2sg8GuiJU1H9CmZF7CBuL2RpvSRVdU6Qhqv/EkN02KgNahoYgK7fhmraQl+rWhKerAkA2vPlhPJ6dhjYuUeulGet" ..
	"TlW41vQSOhNJUxKkmbOyvMZhtLjznnrMsKqDV6ZPmr5wIrvzREozKyqb7abpgCApNMz2urvOvkbi/IcvOCCJnMBm6+k1wQpdcgxR" ..
	"usL2YhQkatElzUjg8lZgPhyvFMGokbOCg6P9+wxz8JHSSFLF/cDsTiJlZvPbQpRzblvhP+8kCgAbkm1YX4Q2XQwBPJXi7jhaojQS" ..
	""
local PAYLOAD_P2 =
	"4TJTGJoL81Ri69pRFMCOGS8n4DWq/MuG2GJRVsoiclRXMfWISzYP55zRz2n9GI7L8O2TcrSHW4GhDDPFzhzbvwZ4XOKoZ2OX2jL0" ..
	"i0kHPWbj3TMdekaAHeyM0CnRE4l96jqqPtyjo4Zjeya/+vHet4vWNaX+eAWlh4+zDrqlhuf31bmxFpE0jMqGS33oMycwChhzN7WP" ..
	"PYdnVQGQ0r+gSFUnxR4fzogxwQ4df5Mu2Gi6FoiXCu+1WaU0/03JO6BOrLhmhqhA13nO/u0+vFPyrkfjohbgPDk3shJq/LrXc8F0" ..
	"hJWbOb9j/VvGIaEK4XVzqb+Mm5wnaihz/Bj2nioQAqR6Jtkg/5QhAyyYEsGkOxACgWjzXQm4qCFoKBOmLWIVersm3+E05Ngsfepy" ..
	"HIUNyxbRpBzhwPuBlLvny+jmP24wLMoMviH3rS4uZTuU+tx8ZXV0dmSoYFzSCX7hOSHU90JPP9xmYOv+FAJqoTu3e7mu8CvlWnlB" ..
	"zD3QHvQwFFrMHWo6LEZqIoCZLxFG9eL3IAhXTLo+uSbhEi2fgctja01OJsB8KwQhqi02f55gS5VaM61D4zDx6hV5ek5uUx45ALW6" ..
	"w+ZxTOo48wUoipo9hfDPRv1fYCZ3zs1tEDGKsD1sdbXcQfsTlzPzzomMeWMzPbbR+WB/Fi60Zm/OdCY98eCb/vAiy4BJmycEvXQg" ..
	"pSMsYR3rZuxyhQi0zXp2F0ILL/jPUITMA74ZQzb/kjd1Dxlh/EpZIz3jUNmiuUaxghJSS2TfODxxEv3UBndGMaGTU7E+pNG01H/+" ..
	"WER1q6VmAloYEjlhUhY4jRJXgg8IMJxkL5sLv9ymXivJY2wrrnnXddWGe3FeVqAFvsf9i0zlyqVqrDmiGH2ycnK0zTPVop/u+/2g" ..
	"q+0WB6pON7z8catLHj+PmdqIoMMLYL7IZW6D0koQOt5+TF5bHKAu4p3V7sImBPTZadc4E+P8DmY8EADQDmeUUS6d9hAyeRK+DTOI" ..
	"Ktzg7tipL0RmfPlc4S2TjMYR3zUMkIUwc2aTqR6fdDPw5Hbj/AWxPSJERvsvd15MHu6R6WDwzCSmtenFsLFciyDgVW8c42Hu2bkj" ..
	"h7mojNSeuJZm/gktQ9br+KUlJufMdxb1YGro5PgO6BmKUNEDZ2YOH/bkuLlz+FUW7EJkEaTCglra8xyES133UiHUtMYCtKenCvD0" ..
	"QhYub2nigUxCSMI909qDhh0s0p1ubEtpTQbWJbYu9Bs+cULTqR9LFMDb6RKSXoZUl426RlUirBY2T11Z9QoMpXlTQAISaYDLrbwM" ..
	"uNmW71TFzf58JXrQiQ2RPbhiuz/s1G0Cf6zbxD5Tp+kjM8+2tjHWVnl1wWijHMPYqQOfFpeakNVNduCKjLhvuTfoCq8yugF2r8hS" ..
	"7FiiJ/M/yLB5qo2Bd/T6FOVyQQGvWp/RAlu3ku/knVQ0Toepqlo/GX9g/rMY4ERhyX97d8VAphtOnPADglrJy/XxQxd6Ic857WtW" ..
	"SAWlycFdWbYkAm1TM68df11Cph3hTHWe6DhtneWikSKkyt+SdacTLpt0NmO//hkVlovRx10Wcw0arzcyoruWlT1p+EhYHa9uPu96" ..
	"BaBg09Ja0qD3LMXlVzbzcFy7e9Hq9r903W3IAmofVPssULPUu6svi5YstMi3fFQd9d2uM7pmVwHJpKiOxGLu+zKvxYlDvHsR9IQC" ..
	"6mJnhs/ytuCMAFBGZ43drPipq6OtS88oKPQUlNnAk7+OlJSrTXWzWEg6LBqAWQ9ThUvlUQS/7IeUoVeAatU+cYmtkgrtFjEoqTv+" ..
	"9Dw9fFxl24Visp3mjXnw1R4ibqgVSdtyOsl/HsLHGqN4msKiRbI6kM1Y4SG/tvBcRMW94685xe2IjofLugRYh/uHmls4kYJvjAzQ" ..
	"1IHRVITmndZFFBPDDN//8zMbCPZtKdM2Bs9zGAfUaPJ+ORcZcW6u+ErCkvp8OpQNFLPgS5r5QrgJUcYJ2AgT6UTLtz6Tlpc1ChbF" ..
	"yV9wf93xjO/h2LVKFldYUfxVoSyiaiVDYQjwt+Po+8+n0rsgC2//uLnFJ6t/9H99uym6I47GT6x4/QnPfU3jmO8FePNqPrrAhkj0" ..
	"qQcRSq+c9uURLk+3dxlfXXHH8CnHqg/47bz6FMeuZQdfSzj0FhqDPhgmDSEAS3cUEmuQC1H1VZR53HD6Q1J3L8gMPc2OY2rGYVv7" ..
	"1wAyU+Yn6PAxBgJyJd14LhtBAlHtPVNYj5amsx4Q+grcqTimIXv+e6rIxIlOvOrVz+b4N4JJG7Zs+t6BtL13Dr+vwXWrQGe+SD63" ..
	"fc1KqBSW0+L/dZEuSLCWHSWZ5H7lbNjkoRw/NC338aFRgcVjJGUJJUPG9xB/C+eDuW37CAuLNlnjIe0A7dddetACzGxWoFqlOs3g" ..
	"GbPHmwPUXuAzPziIXHR5FDzolpqYDLr9Qjrm6sVsxkNYMsJ6Te0dj2ZMKHVQeQg9X8cPsq3RYCEBIPDONtgvGBp/ru98LnI8D5aA" ..
	"YnmrR0YQYFQeCrViouT2bljjdeqKegWGkFDtc5HVsXAdprnDlnfPGjJFXkfYbD2N6KOeVQA1QFuCCRyO1WK1hyM0r/rcq8g6jREn" ..
	"GP2BOEyH1q4dqXzGCbK1OtEdZf41TJrI3QzGxoN/IfJxfnNQsAWihMb0LKiz63szDScXifLr3JaVQNTn5P8x3TNG69JQZ2h8+ald" ..
	"zqVx0yV/cQmfsOmD9yOlUMsraoR2kF/Hyrv8A7iJmh04w56JZ/cZHZw7CtwSG3flJpdL/icIOr/TMGDT1Njb6j4mjTSmwnMXQ5fw" ..
	"okUfsI2EZmMkLHEB2HWvc2YSDgZqPTs0Md/ZS8oBzO9P2v/hg6z98KSxXLf1ewz1U0rRF6u7M6zx2gtKGh0ymTphE2wnMQRNle++" ..
	"PE2zvtY0HW01g0ltaGEmmKxCDVnNd/cELgm+MbwbZ8DTVHtiHrj/NLEH/4KPUWY5S87Teu23idI2/sJ/vYqJW3LJ74lp/JCPYgyS" ..
	"a9TmrySP/BqqEl2iHK741lZS1YNfMXmOiEz9g/kqE+rnDe44r4dhihDNkf+RwlOOfp/8e/meFMzjuYn+QKq4LKo0fmdUlPXuEZtn" ..
	"ORkRQ0n2Irc6qiSbDcwelZ9CSwJz7aLizenmvyHdjNmj6cXYE+f90EkB24l5HYGbzl1YDNS4FOuR8Bde9aND1x3OeN2tw8RZ6p3m" ..
	"eC2IfomoMnSohO65xTDi8bxnvvm3ZV21JUqPRfm+8h4NcfyA1ZChwXBZR3CJfZ8uTfhciG2kBud6Z1uy7TooRNKvsdpZTdJondLD" ..
	"9eNo76a1JYhP7qnEajh6IV+aCwzJcn3cwXR3u0dPAQVCNzlkdc8Qp6l/6L2J+DDmqtMGgw1J7nEhKcUltbOsG+4UGJxFleR6E4Qk" ..
	"vrkDHZDDG1UVFza2qdRii3PV0Q1oTMh8XIcUwUEHtisAf/M6gALAL/rOflBm6ov/gUnERqmNzTQl7ZxWH1RQZoBvcZU1/Wx31WAJ" ..
	"QUnSRG3AYG6JmZCiiYTY2DmVTKcmF4/pDpUCRgIloVa1V5/jOPlQ6FkeC/beDsnXeUI00UbJH+ZpDkuCz/WpxOEr60qB+LIMkD1l" ..
	"Hc7sqKCu4aa2/1byv0Nfd7MBD/JQTFMJBlUxfnpwoiv2aIDgb+l8HuZj5LvHR/kN11TTNXYCYlRSDyxoFAgV/Z2WPaRD96vEZJXw" ..
	"hYv11/6Vi+cl/9NOgH2EcU8T9dhjr2UPRBRJkdjzMsTMRZWBmLlGSzbjQX/qTewstQ9b7bmfx8EmEq9GtLg8fQiVts62rZLRLaJT" ..
	"SfufGRjKy3I3twl+Y3YEgzEZNVGOKgxrrlecHVUvdAB84FTUxASHDK8k3zUin5yEgyKxBNzWnrXeW2ut7SWGQAYYS88blMTcCJJJ" ..
	"y2O327OmI8kmPeNftoBoTjiti0bfYLY9U875gz9Sxp5yqVYrAbfTHbsa32TzH/YPaZyeov7hi5GqHDHzDr+zALj720OUkoJR7FkN" ..
	"myuywSss3h7iNTO7yV+PgadOrJwBoNigzFd1rqrzzZPoOnGMGw+NRMwfOBRfpr7SselXDCJAVJMtIn/jD5SPT4k3WaNnCE79Urtg" ..
	"f0JxspzJczaHW+VQfoJEx4fwouHwKcCYVops0aeUGAS3xrpnMDKMRB9rijD3HK+HsNezUXKEmHkXkiic8Eu0I4eS2d/b0EUDVJdJ" ..
	"8eDURECSeOh1AU5Dpyzqd/hr80sV+JRm5b5ofXRUvFlSZVTri6gaEf2reW1XaU/65L/EGHFisaLFGjxzNphI8QtAqoTEPrvEyFE3" ..
	"9bu+x0BC91f+ZqolExgHTy6Jnh180KMHJCvn4W7OY+ixyZy8BF03Yh1TZ9ghKRsX/2PwBBSL+aAlxyqDxI0ajI/QBuGgQ3kXSoUD" ..
	"Of5EinLMm1Mwptne4sJgyfUrChSsCIIbne5awFoc5ipBW1o/gW6HL460EXn3HJU4vlxOBQIrGRG/K2JPa0tIorXFBPtLf7YpQHnj" ..
	"NmX9nEwjC7MEOyzW3w7U6EiZDXIzcezmlnKDU1nSQbth7b7VJnsll/LSVjJaf8UOftFmYbDWdMcTvqryrzNElqdYPUzO1WApQJkS" ..
	"yx+SIchOzGd6HWNmQdcLVdWoBwDNBJ1gASLyq0Io3CtRSyLYnOO19q45K0eJGlIbaGzuZw94Btc7/F8neoC64hkAbBY+92ViEjVL" ..
	"EYsm3BJU5B58UItlB2kEKH3OJIF2ttx549kRWX2HISYJnkqWdCQgNDBVt8jRlMHvWkrDgkqV5GceMHcpv8v/FJmbRY1Jd8oSIZjH" ..
	"87ffStEwybJLD2q5zkdSkX9OGlN/t1iLj64iw4LnDUhHmiUsF82zIAy80I5Fg+ougGyr1AaBd79r2y+7vpqfMwhzplfV4l1XVeWU" ..
	"bmcDpp3SHSs0GS9tJs+Hs75Y9tdgQXT/3Pq3q7ym+zfviP4pw5cLkLuEJgmGZ7l0xwYIhcsEU7knJ3TgqFsWCvXSLG/RxlxA+WRQ" ..
	"rxSac/d+GuEauZjnwemSh6DS7B+x5ARKUj4gWE5FKzV9kxM60etSbk/+J7lvEZY9POVetqOgZZwG1qJWbEQYVSM9cxPHG4PN6X7X" ..
	"9IGa7cnraQHHMMh0wiNArPYutG02kicJ5Dnl/x542rlca2LE1IJ77qcEcbCFqWAbRMvXO/f+GhsHYSJxEeqWqx1mnhFPucaSw9Dn" ..
	"FCgaFnoayTaLM6ArJ9KYJyho2F3pzzLcadEoeEVfvBvBelYzHGiHjDb5zbGVTyc4xUPBSxocqbaV1Y5iMJ/HA0BasMvqmN3LE31Q" ..
	"xOCfLXUmo5gnIcQeHBmx5Mw8DWj5h5Gv3cIGZ+7OgTSIEgTyNoxC1TB8+09zOcXUdDnqFIONtrsKf2fHtZkNREu/Jw2Tke/TQlx+" ..
	"mMoJXIIkRYJg6ZJPQJrn3LV0IcqC3gD1OhqZqQ2wRn91Q4GEKEOznJ5mRtfEPy6D93kEWc9yKcSqhSQOAOZMEXs+BKnbrdcJMTI1" ..
	"azddTrOJ5pgRnrZmUQmjJtRXlI/lMq9/tnn6V0l+/xkZyV7uRrwY8bGUtrc+cjF3ZocHASWqodyWeZiJV/R7fp+W87bP2kdnrFop" ..
	"77ix1j0Kd3cj0qEiUsRGPhCQ6t8OS09xenigoqENhOxRZgD7w72aaioHSceu9UMvS2R86lTeyWR6hmdOUj5f7ZepL665jV1ekPaL" ..
	"cZjivU1ragkJ/7IXGRNAAH8L35irgflGsgLdEcgvIVVTxT4d8jIWMrOAWlbJkqisUw33iYMOU6fLfJmD3O5x2j0E4ghWn/IetFrv" ..
	"m4cgPR6BHUiCoHc90hEnLII2PyapTe3DWOYsI/V7E7Hcyc5tSVPM9xApy+UMcWRfycYWGl2/V++9O03gOS3dj3OsWhkA1YsGNeYT" ..
	"VKIKtkT3WuRrRwh1xQCuqpYKWvGabFumW26jF7eVhIAJDFRkTMc2LOPjAk1ZtiQtyuqzcdJrwY660CURbQ+uHpAAoL4L4ttBk/7C" ..
	""
local PAYLOAD_P3 =
	"HTBuQGbumEh4ZIXmm7McDOu2T55CxSf2ntgFvwwiTjgCOEGk9B2dGUDhT/SkpXMqLc7iC9R4xckXQdL2tUWWKeWTzkGAzl7RVcOE" ..
	"8PY0H991nPkvPxwl+siwI86juMLB3/RaTCHoGvhpjTxUPikaBq+tnukEUKrL6/ZtZiY9QG/oLsZrCzuz0RU0b/hpdd7MI+C199QU" ..
	"sHFo9FEqrUDJims/ND0kawVm2lzLwcurbnwiQ9QxPvxXb7Gye+p2kmlCN+XFLgfeo6QvB8+idDW00B3DxA/t2y+eIRGV38SoD6XK" ..
	"6ijhVwON+szjtRxl/6Ywtae3qAIJB8RNO6G1BPRPa5hSjpTUOFSy9irzJ7blTtkB0lG9AlITAy9DnAa/5N98XCMY4mxC0QaZxfOI" ..
	"MAfcWX4/AjpxCfs74Rwym3SShE+xWckmuwvTmbHMoXhShXhKLkIixUJTLGOawGXyhV/lhy3wyDtrx1RyN6ETbmo0aitvsH8CrIdE" ..
	"N1LDqPdj51RjNoNEZD4lsA/YUcrJhiS311KN40PZ48YZvg1ILapdK+bD/UaC+aRBOP1ZWUFkgZbBX3+kxy5KIrzHTB2Lxz2jwcgM" ..
	"0T9RxT01sforI6UjeKASyeGDRXihJlJjtz/IfCUiBS3496UE1rbhmhS9pX7jMAEplvioB+KjimapRFxGoZAV4dYJUlJRAPtwM7QA" ..
	"An5k8EWsWk5oOpAgddhWirCOQtnkpHJj/nb1nQVbWlKzN77sjMtBPJx/5mIA+ljf3MQ61lMyCTjaYAYzzgwFZhIgkbmThkAS7tWN" ..
	"QTU2iYXj0nEswdkwItVG5Bhu5ApCTt1FTibQ62Se/z9RJ/8my8V7Uz+iNMb2xka8k2FW3IsyiZv4dWabYILn/Uf4tmY0kCHjWp3i" ..
	"jE9gCXDrfqjQW4nfbeGwGNH7XZvDN1QNrcUwF1l8CprnvTCH/uzVhWW6MTrz8RGiwt4hklHKzq/jihbQxgQhTsunVyEoUlyIJAVb" ..
	"S+7TXvYI8KGxo/bzlK1sRpAePbHG90EqPcWM7XgGPN7dkoByXaSizyDGFj/RzqwgbTUkscCkL/MC901Ubt98DsDDsfq6eiYtMY7U" ..
	"LtDNULzSuhCy6MKEHKOsPkNQOMbdpgC9YFvQMDLWFrMS0JQmQf6QpphKSZid9cp2T19xjjAX25xOMSpUj+Z+yA26W9l3Gc3j0Emw" ..
	"fsvUGpU/sERMMRYQCnF4hxBgI8BkzDQCc/Er/F7sm+psBEcvZ35+7pCs5z/TyU/DGOC6qM2STlpGZn2FjsGpPer0Vy4Nq2KyJxmv" ..
	"l0Uln8Xc0D0xr9CHU+Ul+Ev+ulKVjNiWrnNsB2XRtVcZBjmvWE9tHm6veMkPoDQ0hduCFXVB4F7bFjvlU1PqBKf+GS0+gk+X2Lsd" ..
	"PLZjGQ+krYkaeKSF1CSvQO2OBzD9wDZ0yslDp+2qx8a0LvekBDqQgkXbw+uebC+oXkFg2LM/arxTo3O5+xP2ulaV+olarLEQIlSY" ..
	"A7yA5OXEL8XPkdV1j2vBrwoXloBSiyU4M6X/JKvMTCRWhArxV+y8kkUf/SBgrfvTfikigg7ROk6Ht5XRfbZqM+E/UvY8IN626bct" ..
	"D/InESBWeh3Pq53RYZBLSd9bJPjqcP/45i0QPtyIVJPYa9nVNRPb05DKiTmU2y39sUW7Cz8KogLYsfVNX+p5o/E+EBV1B3HixnRN" ..
	"yVUS3Slu81fbNW3tDPpt5630T/6keoDUuppy42389CQPvDM0Uv29D/lBqDdVCwXTe0/oXt3AaE2fjjZy9QSfUe4Tul+6Ll5Erse9" ..
	"gxMnarBGlx6udhINm62k5woJ8bHSmqhWSzoyu8oZ460SHOimeGNAq872rHFtYiyYz9Q53AZkksgawneVaDcThDEtjeSFKR/HC1s8" ..
	"ynjJVHCdXXW22iP3G9pXshwyjvuUNpIUfOcMmwKNdyRZoUIV4mZ8Gf+Lf2AqgMo7H/tW+j0rQ9ncK0BC55RjomdcXACPYV/rTI/t" ..
	"aVVjU1OHXsxLXP5fZdTzfinXFVVCwKbe08WkE/b5estx6F9n9BtMYkrX/HjdDRc3qUheLgm/7BIndBV/1MPrRX1AB1fEeiqlONlB" ..
	"Wb4gInNSOXl5/me/5mfZvpLJKVn6X/7EpxmnXg0Sv2nyn0v477MpKPcahm2XGVLujYsoC4iqzgH2o0VOtplkqo/NetkQ4TJAfgyG" ..
	"jPZVSBp4xs1vozVHm78uOmaFcqmPSkaXKmWmJ58NEGC4XYShzPT6XnbTqYa0lHETcJTaJ+3NV35k7IbZr0/opfYD9sMbz51E3Hdk" ..
	"hh2RBrWol53KUG7nzJqF6qFaFbbmgFFhWXPv2t/vpYAzaYwiOq1zYVOscN/6zynNitgmG+/IAV7bcOp0T2Sinh84siYdWNMgsmyC" ..
	"RWDtzR14VMvAwfn8X3lvYuYPry6vIxtnYREDTRrg05aE06lrDCzaGBBrhnkanWfe5DF1lm6KHi3sC7K50jmOOqUOYknnvhWZw3NB" ..
	"2kd8fXV+WkRHD/Is+sscfBSH3Acib5L7eI2cIVUrGmgTVYKxPSNaFJnsDf7h7+51R8Y/wufEdMFjqnkBzMQSGG3TCRlg+ZsNZoGc" ..
	"NkRcnfgquA+DtillTWShUghn5bMF4mZR5+2o9NLin++4ddpIqkK8GN68fkyGtmRP9qKPe7tILQ5ofE8wN/qsfsyO7yF3SQEZEz8R" ..
	"s7AyiuvuKeVKkuc597wvgsPA5YwnS+5kkIm+eURcl8dYbIYD5KgoRVkR4TQWmFLxMBZ385Db1EZh8Jkxj4rG4zY/yvDsGtZ5//aP" ..
	"4JnKW9GuaeS+aTkCuZh6CP3bWw1hgstaavkGEMMC7HTQ3FtripuT/cNiQoPveZ3R7PYdeEMy3w9pdhcbteHFsOTq91ymnJ8/iKpB" ..
	"fvz0AsDZDUhJR/xCUSqX2riDBTCu+4X8jcOlTMwspDZ932+bR98X3PkKs6iJDwF38YuCMkYEvzXgdfwZP2dZuiIC4k8upazEe8wt" ..
	"SX3XNQSoV7V+bseGqNc2isJqgWzzCaDRDDHTfS+t6IibkSWy5nzdl3By8sIOO76QwsO2RTMASxlH+VpFa9SiinwFldQctLmESQlh" ..
	"Px6pgafWChBFiLgUyHJENVMDyvSd1nvWeILR5TgNs5Ady8VbdJqXptWJojRPRtcMZTAxBjEXZVlsmxC/X2dAX8iaF/Ye5ZTROjb+" ..
	"C5L9FakTLd6VRYfrlkSsmEsl40ZfLBMXNQ0HrUz+8ESJiNtGyS7qPDLDPGen7ILYdzpZRmuHBcltRzlQCoCHJ3nZpHpoTJcOt9U/" ..
	"HpAznFuWpF5RlqtsFdBOD9QoZQn1R1YHfArMHCwDgArYWXa5XszBhuGwzxf676GNDMDJOS2CgZCF23MhJPsXtdcq+5H8WIsv/isf" ..
	"JG9Y8Azvs4E8BhDvJcrGC5kv+IBMnW3ykb9gQuc7MEEgKihl89l2FF0zb0PW9MrNqjmXz5NIZzAjYY5nZL7ycL0bgOoDnUSqZtQQ" ..
	"gmT1chalCemUkvN/lp53/a63Q8LasoJHkGHk0+G3D4+LDU/NI1Oh8f5D4Smj4OH3SAsN8RffvjooqjYxDlbO7B8mf4tl5tpX3JoJ" ..
	"KRfwiqb8gc7CTpiwgmij07W2UCVjv1mepUwsMkJ1Tzs409kEZoavFYpWIXbvM6NhiEvdacRPIL66WuAOIheda2TrKHnQVBVk1Hyh" ..
	"/9pCFXIji0axvQJejDVsJ2reZ3EWolBAEvK5JciFSVRnrFujjj36yc3BrvLaxaOccTWNOHUbyQ5AGWqdCcxMaUJkTb7xkvqNMnmc" ..
	"pFg5m8xY6TH0lMrCHO27nm0hl9cTz2Pyfi+1gXU/oF25zzz+wBnDJbWpTuzaQTHbTuewf9enS8piRucblOtRHGW+IQ5iDcTlzX/H" ..
	"ACgznBKLHHxZAm29SBNEb5CrRFwyrXoHc8bMrRWnTqdltoyqDNbtPGJ1ppYOL1cVBvJQpdEAv+WFWQ3l2/Pj6A1W3QOELAMVRTNd" ..
	"hV6gIcbj+6gejvvL1gVK7pTNR5oMqQ8YazWxW/IR4jaFTx8/Cjng8qGgshbQVHxJBii76qS9iWV9CMHNToLeKYb6oSSbZhWdvhKc" ..
	"ici2hd3yUkwrPMweTYgQPfzbKtNafTGeiJ7FhcMf+lGjTbVglgbhzzBrc3oe+0elmods0HPIw6asElayNHY/QqDb8L7v9OmVTRAl" ..
	"hwP4hFbJNUt2q9YsKk71UJZiQozgjrUPYVPTfi4iBvuDwkL+wOo0d5oVpuQk6R6OvSwtwbCay784dvpHkwP2+id3x/VGbEvHYkS4" ..
	"y9QbDHTqI2b9tRwyO2t7yyge9g/w1Uy3qpKJZ497ZoNtbtfu2VrPgxlLw59AzRpv9oRU8EHMpsBV+RI/cJVjeczU8UeDohNlLZhl" ..
	"/iwx2m+kYAoeGa6XHZcvY675fEzPdwfLciuhgjFlJKaOxvw/uew8KTyuNhnbcxwnNkTzNbLJd73wpzKZKyiXDtd7KsBk6K5SiloC" ..
	"DRGqYolEvt0di3MhtlGgh5ZI4bwZNL4pvxTu8nrIoC5SYCfbm/YeEt5JGaZODopQXEIqUZ2qsSfsw9equxJ5M/uSnqXzRz7Jrhg3" ..
	"fcd+09wfnbGINWCqk0Jz5Sr7C6+iGFxOYc7vP2iyZ16B7+Fyrdxo0P2ijsHkCrZRsASKeQX7uhhZPM3DDAn5p9frR5jipTMcqOnT" ..
	"kPQOk1YwTblJpUMGlzMJRLZclwJ20kxkGkyDMOz6hsognXvfa5mPgvYxstEGG+SBBJMCfu3b8HxJBRAL5u4OWVGHcImmqltYPJns" ..
	"s7jNOR73W1Qo+6fvF1En7dhI6XAk7lPOZ5DLngYPelr3OMVS6+Bi+iQmQwf3/dOTyQYhynNI4EDCEhKaCgaVr3/QNIL1/xBglRp+" ..
	"We2UNQ86QBbKuPbiwfpSFsogJK8D/U2nLStOP/TAl9XEMpvoDkHH4By6dMZXpmtJ/55WxaOuf2AnCnpAzXdjsxeeQ1r0zO1aKU1l" ..
	"YBBjY9nHrGlY+L9oWmqgtAL9a0Lq8vAhucpJaLvuYWTyCq2YQ05og+rpn36uFKo/ev27ehEpbOceFrrJHNcKN3waX1oFa+271fvp" ..
	"B5nbWkQgd02SgsMlRfDayd9lg8A/FEn9vgPFahDNHlkqilfS4dMKRxFyen4P8P9/+dB+LFMiLu7IMym5rYJSii5wl05LAtTBVKY/" ..
	"B7KOENX7vXVC6jNEmybhfngvTgqslx2SwJK7NhqA1vq6hQZmr7d8et5Kz497Tu/lHV+S2vK+fbyBc2HZlvfWru2rMpqNtAw8BE4/" ..
	"1mT7vdBpqNRfQBBjFlJ/Mbbo+Mb7ZAVY1cLircRQwJjQGVVmHPQTueW7zlEBcRRexhhpR7hwPmUF1gSwhlyibzXiwIhKvjmBgMtE" ..
	"5Cw9zLCs3ypU21QMyPA3E/OwQawg4ZnwRBFXkaVZ+oIIXy6gFQb6QJSKE0LVml6giK6qXXDSlnlGSgthRQEqTB+0sVZG70oLTBST" ..
	"BhHGy5FlIvGXqEQNW4rNSZtMw9p19kdUDhUxgSdoO5rU/fEp9VNXjaSVNjpp5byswDEMMkxXqNs5RCw527PQiHP647wp3znoCWTJ" ..
	"JRHPFCx9gYcZWg49NChMpOsDqn2AwbsOBZ/3OutLauR66gtQQvU75S4PthvuFX4TNKxpO+XDKOoLhxOAH1XjKZq0P/ArGhgQOK9q" ..
	"vUxP9PhYHhQh/ZMcR1HyYPi8KhZcKxXwHltWyhsrQJAAZNtJo2NiC3+iGAtG0TV5B91oXk20jgp2iX9MoL+Gv81MIlWJWjjcwBOh" ..
	"wb5NF5DNDK+XlDQJRISau8O/GG4alvmAYHAUk52+Sfk6KU+IvGQ6s3UyvHAD0S3AnMRw5eV8HazRN/82W7z7GS4Xv8oSqPDMdwNr" ..
	"hnurDBSdtHQWBG+YserBsRaUEYVblmHDvDz+1n3mc95TSyBQQjuMMWP7PsqNtzxOO/EbLET8LkrRXL+sJadi4FIcqgz38fYJBDOH" ..
	""
local PAYLOAD_P4 =
	"uwRI7f3F9qwFQ4YDLkTH+apPX79R2rKD52Bs024B01laTNVtofDhgoXwBOvprW8MNMKS5IGozXE3skZ16kdzxS2qNA92fRaHCPMI" ..
	"DRoNQ6q4BBgQOjWXyHW/U47D151t99ZI0ROWJmMmWM69xRFiT8A7kwaEM/nr7jl548BHZFmHDKH8kBvq9kS6/EACgAqUsCt/xDDm" ..
	"eqM+doTvE2gO0FVQ+W8A8jZQwt7yEjy8kaxClQc0hNCjibYTLBqst5H5LYP+8no9gJDchR90hpKAbThHtyg9wzcIW8w2mUF6zIbg" ..
	"CeyFNmvJ0U9se2KfMLzSwZAOeHoRfMQiSK/F68sPJJOldQ2fmErmgi9EqCBbKt8GRQcUzhsOENTf6lR7irPKn1XgdKZAoXNu5K5E" ..
	"iH7Yt7FOcANTvFMUQywelPIgsrVGO9LlkYj4OL6Na9jVsZM7jkn6JCp6wAlnyovgq7QW8UyxzN/IJ7GwKiYZJJqIoeoyIsz6Z5Dm" ..
	"o+OvK8+H7YCcM+2wgphyNzuZURayLfVyqDXTNJpYBQBg/yz7ty6bE/3Ci5uKZhAfe43LjEZi9jGuKgq8NnfkF6WYmPFvGSn+Ifm0" ..
	"f2fhOAu7CZFbCT9t7bJ7NWV0zOzioKiG3IIGUjULEA16Ox+bBLxpGc+b9m6Whuj1Eu0EccvK1Rf0DIN7Io4kLy7thjqOYhH2c83r" ..
	"NecrwuZ4cyU/OLWJOm6op8l+ekuUFxHzPMBcI2yqW2j8pBH/edwkNUuGboiaGZHOyglqjc9Ek4gZQaF02cRk2m0JcQSzZ78MZEbl" ..
	"QV5XfAGGKyPS5wJwOEbzlE1cQ5LCnJWOomsb9pjIrfVzgVdLgPRDNiRgLG3Sr+ziLZGoaUVwaT8z9x83DafY7qtHvxYyM+n6Rsau" ..
	"908z6c3dMycb6PnWSNeCFaI6UNe6u19KmrnYHcPNc4V1gdgkNQ2ciKC8V5fiLyhBVwVwQwyqKzjlSeQVB5ReaBcBbgNLEhWKB7+M" ..
	"JHz8n+BgJW2uK8h50gWmljbNijB9sXJwSZndNDM/7chCHu5/OoDIYbBELBWgRGDBo8y5Unup4Ch1l9EKpoeLKZJjBDAaG/n6iD/L" ..
	"E7DjcnCHiPzmdlm5jfSuXwRE0aHTZ87eKlBo1MBM591Cmcb2za7FzaYsbNvkEasqbLh5FIE2er2+4SpL4gceTeCA4gAQOMrj4rnx" ..
	"2B6ssK8n5e8p4q11x9XrlvZY2yvuxc7N9s0Ig2GFdwZz7GgQujg30S5yK6syFs4iFX3i7lNgcxbJsu8E/T3zfSpmDrx6OCPYc51C" ..
	"3/mfXOS8ctCFPz98pqapv4Kfb1krPLdjRTwvhDnWBAllycy96vD8xU+bc+WdhzHvNb8iZOHrQnnzH2NXB+NE7hGAyYJY4baq+9+n" ..
	"ejx4gaUxR74CPHzp/ZcOglNTA0H+d5DCIw1vlSq2lBzX5Fd1MgQGaOk3kDIQeeCoU7tnTLbFsm5cf4axma7hBzRW9BzL4H/KBQnj" ..
	"II/OrU/UztxFGWlyGOkNEoFa3OWKF3xs8t5ClYdhh0njRgY/6tjNDsnIOhTTtCLXm2ROYgzZomdbwjg5wBbDflgbYDFw2laU5Dd3" ..
	"nkApiHBOL4Z1BZaho6fqk6LAlmUO4eCp3Bjsa2Oxsep9S5/9YM7OeS7KiTCgFhD56cyEz1iYJir1in5Ok37sSAKup8bdjalZ3NqQ" ..
	"Izra/KSSEjPPu14GbT1MkTm4Jj3JsG+w+0l5YXvnGDDaPyAG1O4SvB6ISIu1xhbdt+fm/qxy56xDClg5U4nfw+KSieRwCih+4rk1" ..
	"1b6x38PhEGphm5EBLZTZv+FJ7RYDVH6K4Ad8ytdkazyk9TPmNNVBACDypBDn6hoEr26aR9p86LQItLVwsWgUDPrTZFebjtMkt/8t" ..
	"m01x5YjLrKu+Qsluqk61s2PylQ9Z3wXftsaO0KR4ZWd5pz0l1y5ORwEXokb6jGW1DiWFUGTBpcnbkMICTuK9iki0uG+T1bsX7Z3e" ..
	"P0lSJVVsnXJMl4mafVLM4qwS1NLua37pJH9RvxNGLEgRmToKZrekcdgB4jeFDjPhCNeoKvpBOjm6DRE0k0L3XbKMJKPf7gIHuYKu" ..
	"J04vjFH6Z6wuRDXZ+bp/Xx+oUV1MCAWGDx0BeAmLUZ87+50vTbl5Ao01ST11eJO2XORgMUDq7wyybqux/g0/o2gRwQWB4fA62cQ5" ..
	"LFa4IITP7MsmYg3BQid5ySThjVXH1y7SWye0icwkbgNy9Cj0D7uHzsJsWPCcm/RLvVWYS6IgyiRhcYJULv2WhycLi6W8CEiHgzdS" ..
	"RD2jcpSrkGAi8KaOBLuR8VKlnIIXHkbTHCe6cvmOK2/yR7ZBHmtG/WP6JC0I8FEq+pD0Ue4Mw22I2GyU7G7Dg/3srgmsERl3qD/i" ..
	"/mC+Z2pQ4GBS94CyRzLQc90zFUjrGq7nJjsOd92+5keLEWVvyvuD7bH3klyyampaybTtCb+GN/dMWDG7v0TZd8swUsro6Gja8hWy" ..
	"sBgAu/DVeYn23EzcTwaNN0KoeIaCcgxFbjaBi6m7Iq02y59DIAPEWLTDqa+Abv+ez5TBV4/SC7h37OhtGJyQhFG4O4yJKRcWoOlU" ..
	"Wma0x8zlZkULBh9UXR+wxbAZ+dmRofsTcvHdLrtCXCcrjV26b76pX69IVVADL8hTYBGM9DkQEPcf/yttxAxM12bvpKJS8YgPou4Q" ..
	"uZDHl7A6HuNGSB4KgyVqQR+WzEEao9l+xsJ1RjLzMmpl0x+kOdt2qU7q+8yHFoj0751SKv2aWGv4JFSzlxaPij3FndKSjG4OPyKb" ..
	"Milmkm4RJGKhdwKkOEIpfLWlQpskbTOeY09b8YRLi8UWdlb7P+skort7Nc72tldGpPAssFjGDPnTLvIpBeKtlvg/nmbUMasjh94S" ..
	"r6cTjYPRN02CMXPmBjxZPEyOqUaaRwFB7PEmlvCDc+9P63XzeuoXHVjdDojIf3kMngF4I6vXzMr2f03TfP06GYWYSzJyHVqMdMg3" ..
	"QikTxL3Rd/FsPT/0HgkrGWPQwQLPl288pB4ZpU5owndID1wzPHMDY1w8rzElPrP7o6XZcItOtL/wNkqr4bTYmaJcu3qn1o3qpARr" ..
	"vyWmNKjcVQmPoxgrvi0c063u7b7h38yCNV46IUgA8Okkh4gqSaW/6222EFV2Z52ZpEuVAjvJ0R+5UI6yr7zb9W+eDdRUpndlDp6F" ..
	"h31TNK/WRRTynVHmrxe03xQJ+HiVSZ9pzLpnwVaSjG4pWU5vgvElNR6qoe6bj+ns2SmDiBGmRhWBJUGgt4NralQFDvvTuIxbKfPt" ..
	"8JUoBxU+QNL4i5wynSXnFYpAaWMFZ4vJ0dJ5v9biPlj69nGPibjbj2Ah2h345vYlrRCddUWNHnB7riNCOgAdUlPFf40hbQKEeclH" ..
	"5NawPMEUmmWypzoGHTFFnTdxf5OkJhd1eNPREZuXtLOYjnnxj05tofGpaUrcgrypYoCElJd15la4BU+xvyCaZLZB6u1URuDppUtx" ..
	"+jhOzsMRkyIonYorjQwFp2M7U6AEgP5suMFF/AJV7UxYfIktP0HIoHHDArK7QiI19HtxpPC78yux875JwwKbufwNkGTdqdt0aOKp" ..
	"1rx28WotghFBgSH9gzf8MT/nIw7tRb8i9KwyQ7C3/0zalVLBcdUiVGObd0Y+di6oQCzqTJ/ddqvCQArY9S4/Lh6S29JlDhtCl+Tc" ..
	"aQdSGlvVx9w2/XpbHVDH6cy4UOa+Z+T2lI39fMwiYpiDQD18xYLqkP06NsjZtSBvPkBYBz5KolW3+2jPKMA2Rj7f8jZDOJVemarc" ..
	"4R0Pf8iik8Tb1slbzNGpCiN4m70eSQDo+4MQgTuM4s9hBaLiU1NW8STEQDBkZl6MyzyhVbO8yKkgOr5l1MXgHcvtV7xrM/QQ3UMh" ..
	"c9+n6bP306wuBJ7/WOE5NB9alZYFpy350PTnnumXyAUwRcmvs63/PgIWNUsCfpWTA+eUrQFmoEe32V1/H4lI6W1MdocqLC2s8S/M" ..
	"Uc64HRgU3nFOQArPatmKOJq1dSJM+Ya8kM60S4waybZSIOSYHsA9Kd7+Bp9ZAECgJc74ox3Mn85E3AVzBIjINEadTcsFMjDDLkhc" ..
	"jLo5LBbpw044q2qGB8lhupEkmtv0ZBBh6THqnjAaa2HbDiZAZOt3NZkpUTeqO8Yy3XnU0sZwaEkCTluMszTiCZjYd5EnuexUZLgh" ..
	"wyuSbVEuoXnEyFgv/fkGDVXTEJrPRxxzJ5DCH6lO2IngVvaAuYFR7CUZCcua63HDwFrPY8oCN0cGdKabOcbKDBdRkGO+fZ0E26Fx" ..
	"0swdRPCFPuDKUagxXzBUuaPk6RHa4/l4bZPnK4AscP0Y0WWFCMuslHg8+SSsT41llxBMfxy9AQieVBmOvIOVWKWpY0THt+lqRtzh" ..
	"OafH3cbPd5zwUcWB12QIf3S73kYZPR/gVhjxsq3OXax8DrXhERgtadM/6VYOcVyv0nH2n69ceCyTAlxU66NhRz4V3yUV/eGa+IFZ" ..
	"wEP9O36n86CqIHlyVxrCQti1fErWiShU8SRkkVCMGxJFWkA0IlfMgaPGDaH1kvjWu3sW3i4nHAaGV4quqNMI069wVOrflQ2IQf7E" ..
	"WiBlHlusDKHnER2M3iK+eqhWQ5+lWm4yo/ST8pd3kdfeW+zqrSs4zVO0Kg0rvs9Ovj4CBSB9qia0KxMuk//SCJejhhxyhYgCftuE" ..
	"J3bnUHlDN5mCmDLkYpORj0352xDETmJqsqbchCSoFOQvWaK8enNbc8CtyYnNM3GiQOJ27+j7/S+HmryX1A9r5T1PdhoRvxO93yyN" ..
	"+ban0+YRBFcagvo4vSngr13/KmFQYpHoP9mh2wZ2L9aTMlQnzsQyF9u4dKbqQVTHjNIAWgRE/eXbmrR6xvqvy1LrdBDrzQ9wKkCq" ..
	"bxH59kR3dlzIwtkBFuHL49OzMXwecLHu+vyPWe7oKitoFTN2DCO+ysaCc/8hkjfTnUKoui1WAFdx2CQJtg5S3/L7bXg0pJypgG7X" ..
	"s3J/IoCnFRNsREXUDJN4Lh9hIvQFlU8bcZ5Mj3gBmzCvdYvM2TuJXlI1X1kCYKA++8av7/9L6EJFyL1xYk84dJ3vBrTiHgdHyzmu" ..
	"9jwHlltrqfPoDjK5Ia7BfxE8mVYHFGmDysl3WAP/ZB9/F7g2ieoChUiAVNBr0XhUygRz13BwpyGl4I90rSmtDMNtWEbLgKa34MdD" ..
	"ZR880A1WNfApBJN7e5sSnBBuZoiBH7HUz8GZRcojM8X4gdAAgYhI8EeOROA8JD2UAN9FV7RtOko1o6ZluXWytVtjoGvpd8cNTMdj" ..
	"NWs0IH/C9zMfoqgo0DiSZKfGStArz5nAj9UK9Ap+TF6gWlCZa39upu4o+Q1zBGvj11xcGrBzuIwWRKPiwxMWUxQh1zlWEPyXG9vf" ..
	"OKoT6fbaC8jw7gDTb8YzbLa2Js5Bujg0pUCDZnydYW/yvPd82Ov3tGS7yIITRdV/MxSUv0p1lzlpgIrzXwQbMybM4cHScVGbFmoa" ..
	"gCc5LmY9CaaBMDE87hCKDMfwH6ZPn0ksauzSz7ar4FLgb1o3nefAdyWiD+JkeIdoJ+nPXVqSpblFTyI+I1Gnn2wVgE7J7sdY2P+n" ..
	"exE1Pic90BXviuDjYLqpnN4YHOPymLTBwfB4Up1xsGoTyp8dnsZS0rRmFGBApLV8FuqtMyCJnedTsNA0EuPo6QzxYaThfCMKYJ8B" ..
	"cKmxGR31SCOIF41sDm2tFCovBAR4lCvPKxBtV/rDgYxyEEC0X5koMzPs8zCYYLwXvfSi7695Ls7kgf28aL50edTA8gFjZMGL2Qe1" ..
	"RjqdNekeRf6l5xvroDaXWOgC0ynMGHWujmeysc0CWaROVqSNBHNBWiYKS7V+KFXPxJ/Mcrm1TUl+s8jOj7Sj4aS8xpcaNHhe9Yil" ..
	"q3qnXZWN/CSmvH72QgYGolxNfA2LHeIZW7DlpnAwzHq35YCYhxo1Itza9TGAdvjUmrm9gxSIrZ7sK1feet57bQIyRK121EL7nv8U" ..
	""
local PAYLOAD_P5 =
	"d4WBM8kJRh5EPmj6YfUmIdqHP0bmTbQKqfzAMAIN6yJ9Fj9E5kBua1vcGntVhYGlvNJpI5C+vO4Qmu9sqDVoyHCDSS4BeUa14vp4" ..
	"Vhe7V5PmKCC91kAT4lOX+bcpActIL0K8zUzvMGX9M/8Yv8w2KFD7vOdU8PfgO1P7M+0qVldzzvGTr7YZylofsNHAdbaIf7AUsPam" ..
	"kZXzZEpXSE9Bknx5ZhmVaAVsIc9ReaaiBVHOT1pvOdc8kQXX2oN3dSnfbnbDVZ3QcwonF16etjivy0VikQbknDNSTTfS+/OcFdzC" ..
	"By8O/9YNTug+c8swMTitm9KRPdZqd7jEm6Uud0KmjcklXY6F2wlagRHoZdHd4ijsO0RZw/rYGte22ELGUYuvJbDaG6bbICNuNvIW" ..
	"A4lEHJTUO1AVZF4P2NIr9eMRqdDPjdwCrb+0OUgUbTypGKkxCvfXjMp1Gg3hmLCLiPQdq6tEEt2moZufin3KHq38xfbCD/METsWI" ..
	"31o4WGKHEuOdHp7eSvAy7UbSvYKNJ/lOTqyPNFgLtUxw2HxGCKsJIQaNDF68P3+u56aW+vvbGCz1zlx4pFPTwjvuAjGr2fbeEINB" ..
	"zazCo51h1TU9vTdpWrywwgaVx7adFIsTjvXMNPClHEHd0ueo12AbTI5fnYTTPJFz7DvF8F/CW7CZkKI5lMnRt1DXQGjhN91lxg/m" ..
	"Z4iNPMTEyeXaMwyT2sFTzU+IbIB+RIxuujhth+ue/FsiDiiC9bkSlHWMBd8IdM7zWLXOAjvFdgXDqqdylaVu8owsgcHNAe2RXPWj" ..
	"QEASVHRRCAxtrL2I7CyB4HpxhViNNArkgRbNylT3OOw5LZyJ5ofPx5cjrqozPwZhclW+xM5H/i4pP/R8sR//o1mWaG5sYYLjZd6G" ..
	"yZkgHPH/mRXQx5Tzvgz3nhQfILvfhN18wz6SZn62qxgB9SNtFludccR/hroBHzNz5gvDV+T2V/Fcnqb1oKGuFh0qGwX9r51F19Ck" ..
	"y0SLBVyo8KtN+CrRUWbQuGHTeRyM0rso+TRvUkNkUPUQ+yQXywiBaoiCGyyk4zXNTh0OLUPzwxJ4IpR8cec/zSMdikssHNR4FDd9" ..
	"wL5ykRaKLLchPVSNVujCLNwLx7kll/0mNAbF1/Oa33qi2KkK1zLSZDJrcF5LrR+iC+ZwEXOu5fdeRWbeqgbhStFxz3GKPZa02b+T" ..
	"QnWoPFBcG+0nrKezHmbTE63G8UBJT1PMIxRQpnx43pcJOeiL7YXeXP+u85ookGemN06w1rg8fIRp0kbE+/+JfioaEtrXTEqAUgo4" ..
	"L8uWB/ulzI6/PP6R2IuibCIC0nEh9mrYUUFXBlsvMzn0quQ3Ws5xOQqBNLw1MOV9LuP5j7xq0ur0iS+PkW6LZeb6y5Q27pS466pP" ..
	"r6AhIh+0iNbXTLXlWjtsZrYukuky5Opu+Tg6IfqU17blYhpmW/qTcxLnOCs3HSeE0lTJCV0Wk5hmvL23FcZ1fIUvrj4c2g2tEo0l" ..
	"fYl+f2G+7ZtlRr15a+pWcFkrk9ZIxylHVOMco3tInhBEOBhyWpsV/T/xuwp9IhRIv5pfAphgKYNy6eQvD1FEMOgIcjCx5iRzGsL7" ..
	"9hTEhzM1OMisMOacIw7qMvnIliXLQL9KYgp0+FhWkZW6EJCz7V5DK6L9wxekeHqZyyaO8M6GC5wluDWQXfC4ErC3i/PxBr1doN2M" ..
	"xjk8yI3FN4X7w+WNZjIuvXUtRBBc44hOIwccpH4EessHo3tvBZyATJLsjV9TY2yFCLwmZUUhQIUj6t62LYMFbRjM2Yr+Oiyw2wcz" ..
	"Bz3a6km9dbFcDuu5l8tQ+z4W1pChkxYOXrmWeOl+Qebyuar3exJ8NZIQodPdo8wjvuJofZJWh+Tc9y1vCXo4xnupcJYhpsSkWViY" ..
	"yOdkRb/zAHr9xBI9PcYmSt7WW62dYN1mfq/4LLw5oT2LoD8BjDeoXj4Ht7MH2hYpA5JnKvVH2SI0LHpehqZG0U5eaaR3nFHddxM4" ..
	"GVdz1E1HEZr35EaOIuWeVJCoUtVzFKjk65n9a3nRsRo9bIFzHhFA9SQLGHzJrA4xhEEoJ33azySrs8o5VF3nIzA/GkeKAB9452gl" ..
	"4siNxea2fp/b0/RHIvCeE0toFJRa4pgJ8+BGPP0g+i7+XbChdkfLyLgqVk3hoKhTum26or8Idw8ajzoy3025gjWRqAUrFyrJaNMl" ..
	"n9LzMoR0G88eYuLS1tLg/vOaCHHuWDWN7PUZTYsMR4bsfBj9STRNUoUrB6u1At15EvbR7PIgesyPLGYiVQRnnzO5ZdFhZRH2CcWM" ..
	"bjerC/OpcbqGTxZrumWB9u8JJUZ816OdNa7jv13qb4pVkfMuQ2KNn1Hf6ZaoNMQqvQzS6N1lEpka1LkDrAOZUK4TasUA4qX5ZWUf" ..
	"r6xCdsm4YJmZGvA5woazmqBWH8nmWvfU7cdTup8Zvefzw+eAOx2AM8lO70wgI6XmS2gJjqtplPGFMITq4HDzmWw8X9zVms7N17fN" ..
	"hRZaUv0f4prONqUBmazDLed8a5g96l45+xxU3PPHgyOU/wnLGfeRxfCyThqQ40W3uFdg98k6hpJvbK7z3T/CLBH7U0lteo6EKab+" ..
	"R6qpGfZPggGesFXFzGBv3tKZCP8XZZbFId3qoSoPscPbjmGvtg+p+JA0TvWp5o5ZDjGh99m7WBbsfDQd9GfrrMZv8m01+ouPmRWx" ..
	"aBeuV6VJxRjYbkI/o2Z/ZdHjgmxzhS7pPk/ZeUUL07RI42DMeg74kVcI2VGb5HwFhA+7pABW1wz4imjSg+jq46W+savrGPxL9xEI" ..
	"ZDsFhCbaFVBJkTyrMzKCYb84vPzNEnX3pfMjHj8Hjkq+EbZh0FAO9uuFv5mfOpKlz0GlJIs8ctj8QOyKcXG1m2c3Ym2ef+7Z8zJq" ..
	"gFzKbUFo4wROoxXBJCfIVaHs4Lb1yN6O2hlyWjnSZDuIdfgtaKCRAPbPEZtYETu2MSmo2ftj5B9a685IIYP9jJqRZU86mt+l3iCp" ..
	"KrxC/94c+jjjhNc9y070D8rUN0ipRodluboVCL+nDAal5/W0re2a/KhnFihajhTnQ8QxhAvoYLf576F6F8J41WCzDYvpF5MTbPLN" ..
	"tJUis9fL2o30jGyNlssrw3BfRJODYxqV0fVOsHmBg3wa38EGVdEzgPXRGrDfAsgk6fO247eetPqf6JsEXJf5F6tyMtbNbpL1dYck" ..
	"MaAXCMJ5mPHNzMwwFH61OAwmhi0ThG1vv8WOCb/QbL/YjxNNaALhVhFUGTH5aXvAiGCqXKohRSAHh0hX/BobXJOuKJl9cpy2FrHc" ..
	"J2XY5ToNn3mm2aETL0zusouaWHT3SkUIzbKMDOYCGXVafZPgmrB4mmHo16OVT53sVij+eL3gjJMc/98sijb/YSTPGg3Sd4UHZbk5" ..
	"HCV4q/a6MHD+f8QP8RVdSDJzHvOwUsFH+A71TFF7eC0WcXSAzm9L1K5v72olfAHpiZQBFKXj3TDQ40FPZHrXSFT1DEl+ZeQrLvyX" ..
	"MYuhMNDxA8OixKfteUEWeKQnpPeu34CxcibdN5nkeuv8qqA0sPohVmFAT5zrrlNs1/K+YNA1Vy5nuNTx2AZVtw9egjQo8/pkriKg" ..
	"gb3uFq3fLEMCBAZdR6dATS9lnhSpcOgpfNHbRY00gILhPpLT9pG7lUsgO9rjqEbCLga8tJjxzoID9YtwUUVwDMu6q4x9cDUGFRl4" ..
	"oTBXGzLnznx9YBsE6ELWSjcCBRUPfVGCsUvfKmbasiGGN9/US460VRPArz2j/3BkGsL3uqjO1gK9NU0/yUQUQy8ZMc+1uqr4rFdo" ..
	"up14kjpy8qCGLHy/6JO0jNXH8HFcqD0ervbQy7VPvn3pVdFN9IQF4uXlUq/uISH/Py/C4l/q43R3Es+81SXdYWMMZYSEqoxCwKQy" ..
	"ZDbyDd6ppkPQwKcwRQEs8a3o+TIshAT7x7sgfMA8G1AzN56S+aDGTOwlA318MPYxXPmsxCk4KegXOn2tB75cJZTaI0nXhZLdLtIF" ..
	"1B44H5/5x4ARRkc6Rh6JR32fxVEcRIf65K/0sF4IvVq9wZDpcbUcP/o7dM4xHS4OmK+ogucxM5xOrhVhvuv3tv/VG8baIkAcyqO1" ..
	"hE+CByU1v1qIMrjbiFuJlg+xV4HUvIuuEFshTh/63Es0LI4r71BuL2k2bK9ULM1jUxjp+u30vPVNwjgfggYndsKsosTJ6XYEhZDI" ..
	"xW4ZSVPNTV4uEgMkyxKVxrUw4FTpN8bt23SVf15u2k/12A4Lf785bQ8HvEFfd5HB6Wv9a/kv4V5uDnu6sTQqwOj3jqihf/hFWkCn" ..
	"P6TgR1T3Xfn4E6umKbLJBPmXiHOGn+zCNOohcVeR1KjOFOkr070SI+9TX2ZfP7guRJhqppAiqbKrs5JjR9Bn6oXSmdBElOJqVDfA" ..
	"uf1hihXVgHN797CxUmzUJMD1Q994S03HVz96SgJikUdCeahrlP0/6JXDD9+W4Lyk2IC6c5aTX2ll5qqEDeuGEuBUllHfZ8Kcz97g" ..
	"eXLwn6DhKURKZ8ePD2OG7zQfs05KfGm3yUYBi5lKOmz4+a9bwtNywXl1Z6NQqg05VpkMZKvyhTmUC5MQHV5FSXLdT/KULUZO7DLA" ..
	"CvLm6+BFNi6IHYUhuafPzvYWFKMxMu4NgFIINVlr6r0/M/UFMVjfMJkJeLV2rflzrcDyBYp9omxnydvQQkgg1GNuqCQKYYla0Ml1" ..
	"YVnkQ5HSwrgAY0El1rf4ppiUitkkhJD1otdWq44bFLOxuJDs/LkpjcBGt/mj5DUzhRX+/aGlnpKPq32x4LXoWeK12m4DKYH7+/ni" ..
	"jB7At/wUNII79gX2adxB2sfBI/Or9c2Vpcp1UpVKIzfbiB+Ct6xSeIug0wr2nz1BS9J5k50hTpxNNP/YbU1cQLk5etsgwOayzFrQ" ..
	"c2YWI2AAo2mL/CFmNcDjLiOK2puYrFBxFB/AZFyMOVMjL/Sec2Ziv+x0cD5FwrQ0axXLJ8ZhT2sJ7r0Eul+ysNCe7oz7F6+x+nIe" ..
	"s0XedBq0rIQ4rl9nDjOnb1RmCbSznKxNDgvi7VPpAE68q+ZEh3bOloIGqQEhY2dOCqwCr4ejq/gFecR09PAxe3LWZbMoz5XPsBoc" ..
	"8gtvM2I4Fv+cR6pDYW/mBPLZru5RWa5Ns35YNZiL1QGpiEYRiipwWsrpqdfhya1NxvwHL+k3rC3H7AyYvnyFdCT1JrzzV8rtSanh" ..
	"U8rJoLuCcch+8FYSdpRHHDAZpC2DVPF5Cq6urTAOoZrr7sW9/6srYBXBcQ+Wfm48gqSljjDXm3UWHZFjWPHZTFgUWqzcZaIwfqRF" ..
	"CEPBBbeny2nbgyDF9yP6za5JCpPgDNQvJGx7sCUeYhEixPpm+wDxzh6+oiyz+BYPpLGMMJhphH+s+LZv+uGG9IDNkPy6uxMfA40z" ..
	"0E1TYExOdplf7VaXnYpB6IR4Z9N1F3qPreS3jQMK5qM1UjEG9gKKnBPDvM7oySZh4tXzyjHrB2vVkrmSxknKN10O4BIGk8PD5ocn" ..
	"OVpfHze+wxxVyKL2A5g16bjz6VDOyoXCMda5O2myLhy0t6TZ6O2VAzZyG/YslOlLdZiVML8jczBtyXhMUsoGOEDNA0J6zIY2TzVN" ..
	"gIE1B3bAjTAULbkqn1KCZPdEe53L/YiqRJBVZQ5o2vNKgEHNB591Y0tJDSbg3kpNSXjtUJ7yxZ8eH6PnEMJElLr1UfXz4HzuspeU" ..
	"5JcSimREpi3AKg+Hx1OwfMuCaYU/7MUvL22cVOx+7nM9yI/MzvtQ/zKdVNTsQMRQYlmw7nRkuw9hmRux8qxFU13AOfilYs6nasTf" ..
	"XNqcijHg1KSe8rx56PFfrr0jdBbuXnon5V8yC6uzEHp3VSvpxuL1j6f289UAeTuASxIrQxndFplLStNU+Oa4UWEpfgAfYJgDpIJX" ..
	"sHQV/nicrJmu3JtCSDGu6LiToevdN97U32BqTiMrhnHdO9RJA/7IIZcJylHquOzenhn39OsxX/ogVwN+20rgCMpyfy70xOajLKrK" ..
	""
local PAYLOAD_P6 =
	"U1S06khm61dphiB0fC0nd/gS6suzYrYhoIem9KVoN4uAub9QxlEOxps6vhZfNBjv542SVJuXpPIkMWRbaAItWjmcK2cc6ygnf7Ra" ..
	"de0/mY1qxclbpl+BZv54ebxvv1XGNeeEpNXplYPOThAOQJTbj/OhuMs0LAFP3QHsqocbe9RwaYo7l7yD1DBaej4WTlper6OM7ed4" ..
	"lgqsg6SBKu6gvd9A3S0/lRG1i5250spNzK1pdyZz0k6RC9AHhJ6iqVRRrwSzF+AYXHGdU8Rwg+y8TtT0qd8I2AvjaxvcBykNktF3" ..
	"1YKW/QA7XZwik1bWezhAzNkpuDl7ehp1pVGmTSN78FAWheZ7G9qoYvcUtZhG5mn24RuF8LkzPOzZ2eKU1eolmtrJzCeoXUCj3E2q" ..
	"ZppkaagED8AOTZovTKWo9kEGOe26ThKmCnG8Wv/GysB7BLBGqd0xRes3bCBQWsqZ+yJKIHWhgFWPDRcyJXVPrsBapqkbNc52zj3R" ..
	"ZY83rR6Fo3TMK6Jymwcx/yeUTCluNV7uhCtbuFxr1XOJxZ7cjr1AXCutJrGKh7UwNLfofDrfVV2R1tuGWXEY807NOOhXGVxH1+EK" ..
	"jPJcOnULFK+RXaola5qDGjqIb/A8f2oHPOEUTR2+hP5IQbaPG++Q3bopTZG/45odHiQF0d20/AFnxX3j0Tqc6Kr3tsyruB6WPZFi" ..
	"/fk5JJuqevNidq82pX1Neqp5KPx4qHCESFO1zTMNArumFUCinyz0+NuQgfFHEVcuMesx8FS31tPxnBBg8jV3CXizn4kRJolSRAvP" ..
	"NXuU+fTd/V4Izn6f/5+DLDRIbGWN5D8eYhY6F7nk9frPKj3H7UYLhIhhYK1hmMIVRV0nS8APIV86OjjuUD523s172zYTzzOHm+tQ" ..
	"A9Oqqyvray0FeUKzlin6cwr+ixAB0+3nd0261XzLFVg3C027NizxO7DcTTo4LxmQd+QcZkkG/KJI39C0MMQWQRZJJdzmdiAoCn6k" ..
	"Sc0XhxFLubohmia7IiReQfDhAXcwdg7zDljkxbXA5qiswlMhiNVR/i+MTy6SbTLrKpZU0caWTXitqY4RMj/nprJxLCG/b8GgwsaE" ..
	"pA1O+3gaOqoMSDnbK5X5MQPLLyUznU7ODBmr8OWieysfNDA78hVQTPOH0fE7wC6V1BIGjxJ5fA0BH2DZXwb3OrYbfYoNQhrMQ0K5" ..
	"wc6gDADVy4WZcJXnQ3O2+cVNavxUWcARbf8Xvnhmp8s3NY6KFn+sDg7kjH6hDH91qlXPYjM7XCDXytGhzb4Y9MndO9kb2TJmh/JT" ..
	"T0HYcOQz1OimOxHWrjJdrqvLu++XQ+iPLNrfO9Mhxww+/r0TU+bzE9E2xrCOBPEJkV8HKDsgSMt8oYX89ZeDXXnHoj71BBGnA0KD" ..
	"WlD2Pak2JxY9aqlzv/Tdkw+tCoPkFpSg5O8aTJRueDOzuQEWTpZM/3k7pcerDl1LXhClbtEyEQ5FwYD4A6L0qZSqHNPjpbMqcc4n" ..
	"LM6dARP2pGOH+3UuVStOSKwnFu+9clgKhrSJIdl62qR5NuK35kXe5wPKrkmE/7Wr2ALv74GPOlQVFb5LjKXq5ARlzAdSG0VaHvDU" ..
	"Prcia4Z534fwu0JYFx4DAHCrwVXWUNUizKMH78+Yn6Cg41BWkRuVOrOW0Ruw+mpPbKrWSIiB5IMXD/CoKfcjXtdcHBS5ToD9wBPL" ..
	"n5MQTxp0AlFJSu8zVPzFhBoxF5mGg6qWPVuE/PPEt5xbvKZUumxUZ2dYJCKJdpoxEgb7q5jhZrzzS8r2w9DruBeAKiqz2kjoq7wT" ..
	"SUHm3liPooA2igctW50A7Al5Nl3vD4niZtezDMB1SfY3nFxP0L9cGLYBWaGGFoEHQThcsz3rxIy5PrLcCXlXQJsFHhrLlLejNPoe" ..
	"5Eqyjcm4xEm6RKyDjo0ezQArcaEbMblrNd+AIDi5Tz+3wkbadKNkl7GC8ktrmVHUON5kq0DNyR5ShG4tgX38n0Wa0V3HxJ2UsICP" ..
	"1NjTpiglArAz/CKqwoHilcygByQs1vhfNeWe66LFKhEeWtGxg6h9vHNnw+gpQv2lcxW9IyF0wH3wLLND31oexcFmGyWgwCISP2+P" ..
	"UKhol5O6diJ+w/LLuS3d0kdDHQPJ2xCy5H/gYS1287Hbbv04rKBFucilyP/67KC1U9FMDebrSaRfj+Np+j2qvsue7xVz5agAmVz8" ..
	"griFVFYIJE/UYMEBfvJcfFhryxfsQ2vEgMw9R4Anc97YMF4yVxhMUiFw25zOB7FzY+zJc5OPbtYKcTaLw7K7q2pg61ENQ+bjGQUS" ..
	"sYmchUOMtiwIs/QYlW3HdceFxgtVolWOkmWSlI3aar2WhNAMkJaRS48Ot0fJQSOGJJ9OzGdEaH799aUsGKaQ49o+cKjo9mTY9fD9" ..
	"myJeHawM9HF81IU26nl7iimUhNrDEK1wZBCa2mFTmuE9MzcY90QE32Ee3rYQygqUECM/3rDTQHvN0yrGTnQ9eA81PPPP12BnR+7g" ..
	"8VvcQeI7nrkSYVKJTKxKtC58u+FqOFGGTQnxiloGgnLULHJ0lHOYB/kywDKQ+08mOOHTKrpE/xqTW9mjo1hZ/pxAaVxFfFpicNzB" ..
	"HkNdAzoODF+t9cDTn6I+3qZJCJmZvtObO1QCa5kyaRa6rB5ob9np6moEFAsPJoBBNzbmHGPDEzW7Mjt60ZwgjPNMxIO9iZNEjClt" ..
	"C/0H79K+lPJbN9LcVcD/Ie22lSa4x9o3q2XuqLs/aMJaDX7bya4lpz7kVBKog/tdXVL9agd0t6/9kwxHCCfOnferf4qjcAPvVvhI" ..
	"SAISbh/f/fsu7y8wvu6p8wJxJ1+uasxavK1WijdHi1mBpZOKocTOv0E0H4ohHzHQV6g1gRjE2vGsQe/qFpBWllv2uoPkPSU006Ld" ..
	"C1AD4GtrB0UO+cp7X4BJ1gk70OCYEEbUsqjSocdNXVgXoViSLtz9iZORtydti4mgvqDNvPgiExXFhQ2vjsbthcPMG1VfCFuZeEM/" ..
	"GkMWe1cZxp9ezgeHQMV9RubCE33xRGGhaS5/HvmLlgPdFZ2aXqzn5hHtrqonkZ843LW+TVlCZlmOI4Smp6MAGadLzjuF04cmKbgT" ..
	"6a7kmM17zIneE6aN/e5tWNM/H2+Fqe/93xzbS2coW30ciAnXuVSD4g3PluBzhhSmwZATbzaJEL4JLF6sVTp6ntEVv6/ofv3F4Bx7" ..
	"DlGw9VmXeGiDq/YsO4BpsOA2PcquE7kWGZ22Hf16LycDRHspyAF3b+42lW7DPHdvM2vH6tr/15oScJi8dDodOHAFLCuz/lJ8+BWB" ..
	"YbfEKGW/YlxoK42/sfhwDHYtMlZ5g0KGzJ9JatCsCpbZhQ1zF8i950ojJXBqxRO3SsoeKDLcM8C/S/z7hVsvBZ1r+ApiW+DijAGG" ..
	"c364ZZGNTtz7qE0y6u++/dRbWC9iVIIIJdBrF7zFYF22S3OudnWOQXIMF2PCDronHaqR380YcTN08QNmk8V60Y3S6rC4IGIzj7C1" ..
	"/xBIjWwlMvrTR6Shf1n4avCVlarFdWMQ8b3Fo4arMwVsFxLZ3tKhpD5sZrdOzqw1gV5x45zSwRew+YyVB1mJX4pzDNuc05+cl3Vh" ..
	"A8QVSV7NdEqRphWBnoAMsR5zaDiQGd9TA/b5ffQd1gS4EFsZ5VHw5L2t3ORinudsXTpmWD/zexf0t8+V9KUAptz41J4C+wAh0RHW" ..
	"pvPnNK5VFGa+/sgWu+CehmkZW/nIJ6mqEGPA8VvKmB2gfCaCC2P2+lftRqS4SX3fTVRJGATUYscDLU9XEFIqVSvaaylVy3OMXgNI" ..
	"tDQ7r2hmrckw7OeTLoJpGtQ4A4sSWzX9+gSoFoWTPM7cHSwdxiSlUruLYuiGUcgNjlRXupN4PXaNvu70TllNJya5wWwp6PfUmBn9" ..
	"GAYPA4zHJ15MoOJ7Q9m0q/T2jNF1Uvatyw3tWkI/jj8/I8kiZf1K2YOgx5uWuINXq+RU3yTXk4tXSYd/RNS69eZArBYuxEQa079A" ..
	"zICgKv1S5hEdS3kqGq85FlUV2d27FdgLMAeauBT+5iu1jSb8oCV8NArfdvnmufZkwTZkwt+JQOQtZlYDOEdx+0LdE0yh90vnAWuo" ..
	"5RBv7N+aAkWChTI/UADP1w9qJud9RbYK1RfxXVualsm9tv1BfCHSlKI/+okxlRfXjJXkXRCLTCw98m+vqu77IzKHFJ76Af7CQjqr" ..
	"BEG4Qoc/cPULXTkj1EFLnhobxFZVkpf1iIwbQ/7k6F78yDZCiy5rQe3Yvuq7zcwT8J3sp84K5Ckx/7NVp4EyafbijhLU4DBJFIk3" ..
	"cjWTiquzWJ7qBECaCNgebpbx001wMygxbl3DnhG07x5p49Sth4sPpKelIbl963ZE8wmXRHimINEigTlx/50PyMvrBepkFNt1op30" ..
	"G3Gu57T/7fvIiw/5iat87dHAJUqc1CbnSu7tu/t9deZ3gCfBiUSzcoJU0ekh2kHbANSBQNL+U7jkfXoYJ06XQEFXPLupeiqQ0oHA" ..
	"box9pGTlf72xx3e45Cnc1i3/zJ59qooujP3H624t/v2TmV0WZDO07vfgCa2gp0A6/sCTKafZCWaAq70ychzy4qEVEZez0rWhf6n3" ..
	"buB9YHXuW0XpzVJ0FtDUt+LPbm2MpdPJveYQ9txV3y9WbdGCAtiDdjHWdt7ADnx6pQaPpiBrunUqFzxl3XuzewtNlPvUdmvdCyYX" ..
	"wYnF9UZAyW3ekFfHf6IYjHEJ9uahLhkQavUf4xjwId6qhf5CItfJWPcR7yVzyejGmzXoEd/2+F1N0XRafCsZMddbJTB+xe6UEETF" ..
	"nOTHw9cj+tYxDBGLP1uZMcSd8xPkdIibQLncqDHOli6Vgh0D2pUFWE9ZnLPfG6AcjwhJT/8r2FMLGiFDPts+UCdhmM/fnW4OhPmc" ..
	"o1ZWny9XaN8j2ubYLoG5vlm8/mzu38A0v9FlmVfuWm8O4PwQik0ryEgq1ti684SXx8p0vyqawGWKder6ebsQkLtwuar/DE8HX7b9" ..
	"QuzBHG8K7dmbgHD+/8/VGxZ/7gwkbM8UnMEvkz97GEdROHbNlZr/RFUSFdE4pCnHiv2faGrIjW2vNgGyGXL9IZSVyQZ+IulQ0/k1" ..
	"ZXjn9LerCB9hJw3hMEl4S53HTm8GogkeV2Nwp8OxPcpBcK64dSkPW1u0w0n7nKYpzPHoVgWE0l72sVczu9fIY4baf9qnMlFqeJpk" ..
	"RdZolQeXP9uK1KuSoXEB+qUK4Izpv19TWvIoLvlvMbndDE2YftMR/E6u/f+jj/TJWEVauT24Db3EQlK9L3MZRXSkO+TC8JW03igc" ..
	"8K/JyjEPmqZGMoznHdkiZQCnenixYEDZxUTBV9PQD0pVAkA0WdNSAKuFf2Cp73FYEwIi1PG960ImdWdP2fLTA4wECvLyzQl24vWB" ..
	"5juw+RcZPnKe7GItGs6kbcyCxIRpYqhAilc/b4eTBHN0CyazriE6GAEkV5DRQ85Os9d74vhSqXddt5PFEKSBSy6z29LO4dtZpyAg" ..
	"TZkYDWwD89LkeieBRwkqeeF7XTkQgdSO6vwCL/Rksar7juEcluCQyADdvxWrZsnflRZE68ZJPg2ib4ifEK8bQNWvFH34m5xdYgbA" ..
	"ifsQweKQPVEzfVGnCCh21aFLCtui/OGXVXPesJPq5zEUAzzD1RHe16tHZI4QjSKFZz9goFV+5MxxcEFVM7suK5s6uPFFjbX2oojl" ..
	"wLR2fqhrNSxaRoK7e6pakIUnY83RlDw+OjzwflW+P8zS82e/7V08yEw2w3/yEfQgNaf9paZuKwzjnkh+oH8vbeoMNwlEy6i870MD" ..
	"eWT+r9ZXJFGYPxFafFYGQvHozZPjjHODaZ1lcjSBocajrhdjSThYio+i/q/csVzxeddG96gN+/ndXNnSq+xw4ZLJ59Zkk464OyDY" ..
	"PJfE7J5t4Sj5P8Us38+L96RiqFAjyBLeC4HY5Y+za1/6YcjGggsqhXuKAc7w2ePgnXNSzWEt/2PY4oUKz8rYNNb/kLIM8Iw7S4G9" ..
	""
local PAYLOAD_P7 =
	"hm55pnEeBWDUw4MUp9fNFBcEzGhe/6shf3UUiQ/05Zjw8VCxshT2s8fT0yEEwIMhSyoiOaYH99fC5YfxvWOnw5ZApL5jiqI1TjIy" ..
	"7xmEBKei/TymsQ0lvXSGOSv88dYjmD6F59PjSQyHgH7J7xCTHkFIYZ1rUx8CohSWDSF7A0Vp37qMnCuWEKK8IQnQunCZdpWcPHGY" ..
	"xhRoTL0DA3BRHVrxsrn7K5184qsibOhpwyeodPhXEM+G8NrTPh9FWHyA+ZYIITS6g5xVMiBXNPmxxuEYRwmw+pAuz5woV3ZwwfmA" ..
	"LA8I8/YC0r73j21THjth0qjoaWsfZAlzA7NYZO4bK96VmW4FMR/lFpATUAMt4uLyBduC9AOMGMhWG5yRPz/kL5NPos+QnBKqEfBM" ..
	"tGH+GLPMR4v2PtoAJrvwn2XuU5SKHVglvQ9CjKgeM5QhzS4yjlMdK1ui+PMNg1p+g7r9W2d3uPeoL1bODcAacZXuJkiVNTEpUDWi" ..
	"f9WQDMhMTRZBgJ/V+JiuCIiYvgxkXX94K0SEQfgMB2xeaTkRAJMaKhdQ/EPUXQcYYtgKCRCg86kBI1gyOShCO1rubdA8iKNMr+ei" ..
	"nKV4/9Nuy11y73NUERi/mQdh9Z3SdDxrnGQdHlxQnMESsj/lByhGlp3KH/8SDfTWSzL6Jvu+tqcpmww9l8EXt1OYRI79Oqjq/x8q" ..
	"WZlyEFh6vDSUITVTrF3J0M1cot5Cu+pTcAFyIzyCwYYL6fF2PJIV+Q4twe+1M6hkma12sFsIeag7l5O6nTZsRujkSLZG3Pc/gi42" ..
	"JdaqefLMuU+JnnDIZyUVxDMMEUPVI1l69LuOhApHR69iuwCGwTK6E2bQdqN1mlDWjog9OZKbUoA+YT6b9WCt3g+MJ3JRsiCiMAG/" ..
	"GahG8BWUJwdO0/SQKILyeCrop2CD17tskIctto80a+10OfN1k+HH0qDxEuOyDCotzCehdQIRB/8mDtHi0moGCIOnCZk+qVgFsnqb" ..
	"jZrQ984TonN+TxWve2K+bfRoACHdUle6a6PCWZeB5SFHI7JuMtPBpqJN5tpkBLYDxLy4zmC0UMHZqTGEdJc+iDU+V4r9wjIcj8pG" ..
	"u7ewy9kIFkfV5AECg6rIe4XSCMXei/CePF5b9dI5kvfmRoFDFv3wT14cHEEvmqJVQptGDmAhez4P1L1KJ+SMI5NAwKiVPuXkBtBF" ..
	"CEO03pFD3YjhVaMyG/X7+ZDi851kqIVBxhvdIlRZkybw74uYpPTlJo+SgSDoymhZhxtjeiPCx3EFyffS7I5uD6iO6zB1u2jAG8Ev" ..
	"+4IoQHlMTihuKBqWACQWpqhgesEMrllsciYhfNLvMPQfibFjrqbPYWqp45WVBf9SfaoF+5vk6bgBEDRAqSlxPuFlB4V5m7Kw0IqZ" ..
	"r6Y7LrWmSdJAqcd20AHel+8KgeXo1P953Nkjs3sEB9V5VemhQcOFghjuxfX5ndO1yYrgAIz48gVn0NV8pN30XgUeiGRIqqQNjdQf" ..
	"P33ykroYhvc6He236F68aVurQIAr1DwLdimq5Nnmdr7YZLJ3Dinp0V5pH8eaUGMNXTNsv7cGJpo/ngt6y3fv6x6EyOKcjPLvp9WR" ..
	"CwUq1/lQnBcpAUdOcHHkw1SrjZWrywSot8YFSXiNCCsRmeiDrzP+5o/aZAdZ37Y/ihHlbGeaBtVOBt03TkvJ4s6VjsrtlT3xPKrC" ..
	"BcpnuZM1Fp+pULBFUC88heuZ3fHG/djOrpMw3+TPJ59CBkAZqhaeVSCxn1GjnJmcjYXAowErHhlIK5+7twY4hu2Nr3L5u7XexgI4" ..
	"iKkFS9ZGUH/iQ+D/M7NALIaQYQ3WG30QL6LgTUPCFLRjuJr8iLPgSrmrRSDHxQv31CLQivwxcSEl0Q6cjI9FDQlH464eCM6f6nsf" ..
	"rDR9DSx0BxKnoSolhnSyO59XbLcRv4ZzBTyyO31TFnMTrtn7EGulABnm72tCjayDGd46H/t3VrUfVMJD4oJF9MP72frUhwxVvNEA" ..
	"MVQjcUOXcamncIasdZOdzgrAZQpKPShhQjbiKKHGlaiVy63NBAsiNn2NlSo8q2rxoiGxw5wAfz/eBEgGUf4QUwbsHNOR2KeJhs2x" ..
	"Mf6JR3+vVQujUIcBgVfE9fAlqwWzYUv5xsfw36Rmk8VhFfvrpdNhVZJVRF1MzslNRuteX0Sj78mHZNQNX+4OXfcgCFgrATCf4G1j" ..
	"DHKEFWfWD/gCErvKKuD1bxdDlXZn5/s/SCyg2rwZ4y+klgyDn8PG2fGJa8mkxpJHOCGw3OGFD5kDHLfRlCzhzgI5K64Xw7FHHYX4" ..
	"OpZgQsp3EoY8WLP3KZKrzPQF4waSiohZ4U/qUl6Bw1bC+Ymq8CTmu2JS/GvdNvYcwD0jmf/kIoSS67kdYF5gPCTeRwTTy0JuEcHc" ..
	"jkpGfRyhMy3peROIl/2hvKMERvGhMYe9Cbd+xWPrZAnU2bhriThSiqQur/TZqeQieCyjh8jgWNwq7BT5za9IVDy7sdd9ViAq17Im" ..
	"7Cc1GJ8d6UQPDMdKzdlP/kKQts6fB6A8SR3tHgQFeid7Wjy4rCbqb5+FAr4JMHmpExo4SLN7SmQ8LIL11KhrMSuyHcSZ3eqkX8UJ" ..
	"+yCqpassv5VCPWMilzcn2J8ujeNVgD+w4wJaXc44FgVQAq7xd71bT4MHkShWMQZNXS/V7X7MQttacIMu2KRFguKqAujuOk4yLJ49" ..
	"bEwbEgicski92DZ5AF34X0C3XneQi0c4YJajCOjpbpM2GAlHILKlQ/UkHLxeNdoYzqs7nnr78ZFFvnRsBT6q28xnfySFkGE+aSeV" ..
	"VXizTmLMCpJ5g0Knc+xfaxI+NJdDjcLoG2psa1W+uTiPFBRxkb1rJaUi4x1Wl8n9FAiUAMDq7Cyye9+/jxj+IzlrbKnpfgapLfma" ..
	"Kf+YR3EcrCiosC08k/dWqwF8medZXxwXoTf190IdKLuvPZNgFrQRWvNWbZFDJfpupbi8MxIObkZ01ef4SjBGPDQY2EMezvgLwfK8" ..
	"PodVE9ORu4KA6/Ki5tAA1qXCruyybq47noulr+ySgoUSWPakeVNmIkxdJLJcAaKInbbUR2IVQ74lqGOE45MkYYuCBHmKjqhs17TV" ..
	"c+ONxjwCzevFJd3LqGRpabxIPCXf0vHsBIliUIB/UAYhfMpf5fBpfud7QgQ6izuHQhp9Iz6bg+zDK/37yuOqnAOf33kO9BuV9mQK" ..
	"6KlYC/NcrbdkAZqbWBx3jmU0WzK8Lz4198N/JhZDlv4RqFVWbn+GiIqJzpS/t8cCWms1l/BLFxBYxSs3BCS9cvGLeL5+4lTmo3Z4" ..
	"w1ew83WdyK9ftFgvRY1IF04/KREqpM3ArKHZMFPWTA1E5xtabR8Dp5uL9NQPuO8JzzG1dpGVTX3y9h83nqgha+6k/ZkChVu06uQB" ..
	"GMraM6F9X5/iONjoblNAwdjzxQ++XNrfeNUQ94lpkIZLEF2RE6SoF7M2rMEp/67RyAmFhqlM2Hbqq0ZvIdVE1WyefMzrFOCk1U7M" ..
	"nTS5CnW4IamsfE33upm5OrBJUjln68RTtcwU08uSMFT4AABy6xvZ47lOD7mM9V+iQ7BTRUYbFjVRDkv30CBNsFp/2T1M7kUnfNO5" ..
	"HIqwnE/UFVCk7f7OGTZ9Lpn7/mjQ4WFc7uaIF3SLQLzWWLTR+FPTvpyySCYm7j6wEg2kIazmkb2iHYt+mNqnxaoiUyuXgve8AbpU" ..
	"LEpHN5T4jqbgxpotAsHETepbI9tLKH53IW67o1v7e+Mwh+9ay+B/rqBt9GeiRyPGRDT9mPQJ2u4jJzo1D0JTEnYVOpIt+HLsKg63" ..
	"P04BxYga+AE8qo+FyzjVG3lXDy1q498CrS3PGoOJO7fmm0toj/ICsvcK/76xGYBj9JbPMI+2Qzbill8lpoBJdD3vRDsqB+ZEAitz" ..
	"UqQKqkmbAVs9pwOA02azfCy7gkXCzRs3Lbro1zlR8+IvNE+OlRVJcaqAJfb/i2MIzsZ009znpRLOPKtEb72GuZj5YBYKOGepCmH+" ..
	"GR+v1k6soA+Rn1ZjyDAFwXK9oj1RboCHLCHzrvT9LfsRge2q1qL+Jp4HUpdtz9dwQGs5FcQ29XvjoufUurmei8IYdb1So4LoY9oy" ..
	"L0xfjTMmXMzE2gq4tWXDoPgbw/km4+wWf6Fn7GUxCuAnkVFs+4EcQ6Yd59NVGlkQma7jeSay5QPc2VqIxXwlLqAgb5SCzxzTSX1C" ..
	"9B0A2pxoq3uNya5PgZoOkH9lpvWY+KYtZONHU2uURMkehcrAaWQKEjZEkBh6FSo2VOelfFbQjE9EbMRFyRcAiITSTpctH2lEequL" ..
	"rUDq3HQw2VlM2nwmBKKh4OMzW32MhpvVEM+snsKEeK/Q4X/9s66QNeNHV9kVeUqA4J6eVs38LtnElhGF4PbO2zoCFWy6GBYlc3rd" ..
	"l8nobKJ9nzSI2cmbI2flfEDd/yOrSHFlr6ArXtyO7GbwOsOR1ogatU48MigxIqaDOGvQBDkYQ7TTaA247u7bmEvoEXNJbwI+mF1d" ..
	"VwvYP6+LFB27afGEhjyDgcwqiYaIilp6w3nZbPnRNYt156akVa0oqMtAyAyh1GnFSbUSnm+FBaI23y6dlM1EZkohKoZLJTRkz7x5" ..
	"WlgYagcZqw9dWKLre8hd22gohowYiVFlZ8ynzTu0hvCfpo4ENFEb3nlG5/OCC/quxWH/wDSHcs9Sdzacbce1yAkOKHmFb/cWOx2+" ..
	"GehafMBFTzOfUGnt5GbtE90EIJUU6guL6TwdAe04NpD5EyFjya8Iayuynj8zHo5GAp5NHTpac6v9pOVslj0zfV6WOBOPaDdEO9Av" ..
	"cz8eIITlWLkIUxGiYoOYrZn00xw3wJFzWZQBh9ZrN1uSGe0aLNRbOS0qfJYUIjFrqTkDS1ddSsLf/TZ1+wTgJPOFS0HxjP8+khmg" ..
	"jYIcQeRFsek6eJZXOrOgkrMiticVbCs60W6Ll+oc5ZJ0tUL8W25GDUoS0Pa6V1t1de095ABvF2q2WpzJIbi+xPx5tAYJPb1pbxqV" ..
	"RDLGaBbBDX+P0esyFvlcgE8RV+v6rd/Tt9ZL3/fN9zrQXdpKfpu2y+olT2nwCjbb8eYCaoxu2Mba1g0ZASMK+vbV/jpjJaeprOl8" ..
	"mmacB6NuP49VOhFrN6LOFjcrBQNcgieV6iK3dix1f0jVALfDp3EUh/SQl0OyxJJIqQXKD0CgvA0s4Be9zc421rY8jg6Xr2wl1paX" ..
	"wauJFPTCnKxTiV2bUI0QmA6j5YMCHirS5X0lhFV6W1eIwvynBPeubPNxnK5Ec4guFOp3P5PyCMCs/JILKdTx4VlEzVaTC5Ikqm+D" ..
	"zTd/eX6/TSPD+1BxFA4R1cdwKE1sSXh5/TSP6xJuNLSnXON+Ay4GlLWRGIQ8Mtaa/fOcqHKsuHpaqchX+uRgfQFluCE+8pVy5vFy" ..
	"Y6bUujAo3Blt7YO1D8rhSzBP0lVyqiTKiGZs8U2vdHKsVD+BZqZPIBDfqWTRwshajcOElwXKiI64nn5FPg2ZQyVRuBnkS7YPJuFy" ..
	"LEusgowt9z++VlJ78btxH9uCOwoTSBZfUP1Kzn2NeCsO7iWAjctdWPMzW7lT7tsrMnXHvTVyA2WymOCEf9oCR5CSmOdYngKHfMuR" ..
	"8TdLKXG4onE486bEO2SLoahjjv8ioNigFjUSue9m0CEdvR2WGDGQ8PvIL8zffr7pnJBkUr9IZlC7xsijOjps0HzugzsKXC8gftH2" ..
	"GoE0glPobJykK4KYh7JNf5dHFBDAm8BLxbSDu+hI00IOsAsGbpfYaErItmQpQOhwUJiizpRjmEIR7eXugn56E9FbfaL9qvnTz8ah" ..
	"fAnb+t/3n38tN21oboghMUpbDkgYH3PZWxXIxFjptPK0dkUW8PQUp3KbZNQkg93wuXDWsmkMOjekQfd5wvoobBG3MdBWaygjvXlu" ..
	"248vl7YXWilTvK2YATUnkjBEde0LtjuJpRujBBE2M7xvn3lTk14vCQMQ4evUJERrekWB43yaDRzR1niRtbS/jYjmQwu4BMnpXE7f" ..
	""
local PAYLOAD_P8 =
	"CoLeG3UApnfGX39fPnhXqWlgaYYibxU6Mg8X4fgCEsfwpb8oi7zyUfCmQZ5azNOU6TMicMaD3SX/DZwMbqEj9ecu4piB9yY8vfcd" ..
	"IYuHrBC8hOMaZ4QbBVQucjRzZpByZkpFFEkUGIA/DYq1r+cnvF/OtO9PqlKhszHS/6lsQAoIA784YylIKBGb/D3BuOm5V9DMxsR/" ..
	"xi7G1grx49lYvWHclcCG76YFvdzepSeC8rtCXLu9l0N2tyVsfJ+keOJJYO5xsMy1mrhyp47AXLAbjrzRkEMrh/TBSUN7XsB5jXCL" ..
	"BDO2zh1XYiEzXPtfimMvhNlEW/UGYKrKdADUxyaDPNA468l6NGPDNaXCQ6hNUfBE/6619DlBjF9avqDxhM9f/TiMvysRPn5QpXz1" ..
	"pRjNPLsKUp0uN/0vYgWRq6hYKoAI8KlIebOevsxwlFText8Pbr/Dawjjm8F5XtA94azbpOMHIEpYrNRENkOixR5ueiFS1EXnDV8H" ..
	"l2W7m/W6OpcAXzpgeVRgvVxMgU5MwwIbrXtkUS/vaGkEaGsldzfXqIBEI7/BDPVQZp4m6xAxpOfY+CNztxNJEAGjb8vOr4aQ7Ocu" ..
	"MDZF0mwraLzxQXqWp5dzD3aAFFHAv8xBH0NL8UuLxxfmTAVPidVb9bjoiC5+sr2aEzjIYAw+o02W9Cn/okoUt8vWG2aJvSa/fyl/" ..
	"SvjVhblmVQ5FFrgv7LJYltfVmLE4TE8Vd5em0PQFYJtVVSl8H/3eQozanbvH5gWbLps5FcGd9rxJ07Yp9Lx9fV2097letXhzXWZm" ..
	"oJrxjlBmWc36PWQT30l6EwYvI0WZlcArTVGRc7ogNg2os63XGLUq6ncY5ATVtQ+v6sih8TASywHZhRA0GCULWtpsrAj64wFOuYS8" ..
	"8/6qT+VV67sHMlW3rAeu9BDF0mWt30tLPKQpp+cBj9M1fL+8PT/ExNKFIW7CLx+Vkrq5IfP++KHHXSVliR4hk9JjIXjo50/Iew4q" ..
	"gyka/4lggpzR53V6f4S8oC+nqd/g2sRWllAi33E3xeCr35KkdhDnqNYY5h1M9nN1HzHAkinR1romIgFXVcaisobvMSwjArheoH0I" ..
	"64oHRMQr4eL5JcGMJVDrqdnVi5Fy2DSDOTnJMSE1Bos+x2EKgd5/4GSBZX/He/menca5eIzhNE1PME4cf8KJcQEfLv/WK3pesEWF" ..
	"PKmNzhVla1eSj8Qp7py2u4eKG7XTVL7P+h2VHLlTuNaddPiwqyaMUO+1al6zBuVaZj9CGHufZmnpIN6JkjrOPxXY7TA41hrVU6/y" ..
	"4kb8UN5gnaywrmk0Fh+7vyRILfMYI9jZBdtZO3m2gDUXM5KSob0r6COCDJk8KJUaptxlQCDyRLEbln0MbjSTYT7Ze9J6zNwjDIqH" ..
	"E+5afi8Yt2x4ZhfWW3Cx/1GFd64GruRWxs5NaQ67ZUlPt4xlrn+vWYTkBFyCB0eisDc4vvv0PYe5GxtAw/XdNklwjEOCI/thIudu" ..
	"Y0wU14hcFYbY+ar1QFhr/DRNnO9rXEWCu8TrxJslR4cczDGa8W5yLWo424T89Lg4TosM70sMuSZEo8q3Acl/nWxqIueeQOgJ7u+9" ..
	"Yu0oGatPJ2yFMkdCQ/UjtAbvECl9eKcZ6KpcEecRVfxx/6Kkx61PSOd0G8YEOUGAbpWOWohRZlQ6YVZBEpZscialQumCpFtfNohW" ..
	"/w9g6JlGca+kYGF5DlUJW8u69sXOAriNn936JEtxnVElv5xUh1qBsU2QBytArO9eNVbzMeMn37m/FmuuC4WwP6PSQULvFe6lSfE3" ..
	"bRD1anp+gHsZwt0U0Y7Ws4wjxlQwkaWCksE7epV/rCc2DNZe9HFHb3AZ8doWpS4tE6af7i5/RtTQLhnqrKsv8oxngCPyGNoi0U0h" ..
	"bayk68qgssetvtAWAI5Q5734DJsJF+5r5sIEdZ49Q45hr0AFZwte8bbdPw50cXUp+fptaKZKN+A4recpi+5QJKSXLDWXDllsQsUp" ..
	"qnBEM2ihQfuKYUDqoAM3jrwRGdYOUlO3xgLTvmrSsZd5wJmVGnVyFpMLJXJdZdbm9uHNdvJN6yfOYmXjJ7l1oghnGn0wgEaMqMlR" ..
	"ZU0UTXDBWPmRbGg2xXZ8qlKBPR2ULmVBhG3ZuO1M7cd1vU0g3/5TXgb0QSdeG7ACoNLHO1k9aubRU+YHmRKleDuVmbw8woJHhMZt" ..
	"JndqVIsk5Upiz4JIlqougq38SJxxPQkU+YT8KNZWVOc70IcwFgd1LVbOdtMwS3BJkk1xANPiikWvXICxCnTzZpEEPD5yFmKmZ+Qc" ..
	"uBrNmRHrWzTvBqJC3x8reKkw6oxJwiXxpxhkrsNovoIioxoVS33cwAkvVPG2NwVGLqh7oQ7jcGumYVme3k6woTU5JAD0joG55S4f" ..
	"nPqaTjsIwmuQesGj0q0LQDDnRKpuYx2uFPJ22wnoEQsCwxSM0xej8USkz0E0e2oEbY4ABeGtH8jpuga6XRDuWoHDa9laObz/BOD9" ..
	"6so57Rowh5U9tlcF9bhbL31k3fZfpOFhBx3dr0YUJx1jUakEh4r1INVpR/rerKLOLeP3F7i2151AWuNO2upC/oeeXhLdWAbPXUyD" ..
	"XAQu82Uy6xLvhu4dvpHjYjyJvfzh203j360AljL123U0OCx29vjErNI40fGuV6AhZnJuzcn0ifnZsvtygu6zk9UXqavz6EedDSAa" ..
	"6q/N6BAaCT+OlryDDm9AhTt2nglWhJxnhJ/7HZMsC1jsMpM5OKqsU9ZgBeIZJvzrFbqVM4D69vTUzUIg31eHCjS4LpdMKuSig1Eb" ..
	"L05MMQuIUxgduEJOmvbSAylY74j4IDwfOO0+0XJJQ2T8z5OZ/fsahd+r2IWhnjBV1Sz7u34ge/MfXvzPyaEz4HAqGMmm2MdWfMrG" ..
	"tP0Q6NXWrJTJlesNTOsA7dSSYQ+fCSisYSrBASHRPBHkcOCnYiW3ba3uRV4UyxjmyOyK/DLVCccUHNceJwYeTkFwrgKyfzrx7uHI" ..
	"RUk2TfO1LsysbBYUMG/TtzadqzHfn4BgWJ+fzKFn60MKW/TSwUQFj1MHVHrc74EXNJmCkqNQIvhyHKjzqatQMsJg1Cbuy3kUyzgX" ..
	"a8XafAjYoX7iY51y0ZIQQ0/OlCbqvIPtFOYrT+mn3kURIShWL6G2AB2iv8zYpDBXgIYqgBDtRD9bF6b41ThVksYWryplOPU6QFFF" ..
	"bWCydJLJC+db/4NCFFPQODaWGXS2XvBjwmwYuqcgky1PMSmINNm/4ZOj4g9FBH2MXRQ0mfwM3Zho/So+cNFbKJ4Tz6fO5Ux9v0It" ..
	"OxYMYCylfNKknS+OaJpPtBdCj7qgR1Wk/oZL5DUFxK39XxJRIDXLT0HQqqY06B1XwBLTkdiZLDyq8kuoOy+MAI5Is9GWowua4Z+G" ..
	"4bTq4juJk8mFyLujAlN0pwsUVCU5Eji4+dFChu+DU4vdA7CDT6riNabZOEckvLUW3LVczANngEA/IlHIIGmvei1I0gA1nQgchy6p" ..
	"fNqVXFmI57w97xBq0NMEHoFBKZWignPi1FM5FxH1Y859sG9mDpq/6kLYHfwWV7Q4U7moVszBPW9MPbf5l/cki7tNDraLq6JcfmPK" ..
	"VUMDUZvA9UcKgfjX5r8hGnWWzjDyVFwxmSatA+fC1hz8w8s5idasWCPR1jnXIALU48LuSv7Y7ffrq+3w7Pzc2VhY7phpj08LIhKo" ..
	"LHhlu5lUr+FPLP2CIcL4QHaNHFexwJFEYjmGI+yjBOG9xID+sJg+YELqGEkbhuTFrSv93qMfGWWSPc6bq18gbrZKfu3NX89JW6WQ" ..
	"CkKkqBFCL4QL7zk4E7mCt06r4mMz1BZlimuaGhlllhtkTD1HcgMkI5cut72gmSKXBPbh0fFYVRan2hK5Ucq0Ojrx6bfZPx5AwbL8" ..
	"vZr5jlN2Cq3c9NB48pfJIn+QFSrZQJwcR9WFVBLb2PxcZ0iDpYJ1yDrPILybRTunLpWJBtHZ56KXIH21Oe11dD+sz/RkHcUEeOKf" ..
	"9/dw/qnXT/fVlzVYCGQCuiYoOMchNdeksPs84uthelyjQj3Yy+uO02pUO1LuCWz7Ov0NBhJBHipON+X57lHNFDFKzMZZ1xRNIZXC" ..
	"XzEb9Dh0oLzk0JFbnP+4bQQQeQ1pyOJTBMKrwIx7ATssANOzuDMJxBW8CrMtgyRelWSb2KwDdDdjM3DCLPyBvjpYVwnfjf/c8Tw2" ..
	"lY/8mzqehkufszdqlAkOdjsZwn8M4GjWfa0SuhIFZwxP9d0WjQ4r4Dxnef0rTz6WaqXxwkUu1Tv5RnlAU1FApiVQ9ULPE1HBYIjT" ..
	"3x5DczJRXUtZhRed05KMcrb9hlIEfweNsWs1pi15cx/fTx8iVW57KxGM7JdgvoMYl9VrbZXItb3zdPdUVUbj5HLhjPwmsrBpstWI" ..
	"MZsEy2BpK7nqPfQio9d/MNclgWV0c7XguVyTXertCcj4GidNEmxpvmFqRv404f/LuC4AEKrxoEhBnmJ1P+N46qEf2f1W7WFnMl5T" ..
	"MB3o7AmTpsj/1Uj1qIyuBb0+DcWPGqHgmYlg2H921obm2VepHtqQgmzXinJ3QImWaAB9cy6oVU6v0dYCUgKh9g3L0A9msx2b8bqH" ..
	"N9NmQXZOBT8dbzoj97/ABRDKpbCeopTETzNxe0KJAOJgd0X2eOoV7uyFw3TgHE+Ycdl7bcBWiIZ40IQ+CNJZ+Viwg9MBcjgEjYOd" ..
	"lWI2i7tZMntQwLRrorsvmGoOJ1xfZphReGOuE7zXYEepCh4EDFSaui1fPWIVtm7mbK3yb2etTyVxrwwxHde7kXpJFsABiAwnkvrn" ..
	"1/W136mlGo78ZVtx9Rfmgus59RzlGVmvrzH5epYu1w5f/Zc7lhrJinoK9U9BuuITPVd/06bauSj60a+dL1XV+yTrZwB7HcjykOkz" ..
	"fjJvr3RupEL1bPP+llSpoaPjATjrArBihrQzSuWJt+bIjRBdbWAQ3sKndsV3Iao/BI0Spt8o4KUCFM/0XVljLy/k4bb4yiENrlEB" ..
	"N8fkDxt6mokMSyEeCNEhv+d2Z93BPADJ4D3uFBc8tzM3DNHCLv9dxRSbaphcTB6n1sZDPvRBIAq176nZdMnoEUIIz5dJQDFhudYB" ..
	"yT6EK88utP3qmK7gOO7VcV012/9y4XMhhdh307PStyJM5cF540jjlo0ey6a3BCJO4EeYc0+a6ywjBzkI//0PzFrYFyrQ1i/518yd" ..
	"vys2mRUhRal+VlWxtXZoznXhTry8DCgoBXG6HzEciG1wfY9TrIaVm3kcKmfTd0aJrJF2aILYU5vm2EKBvhduTWvFrvUUli3O6wUt" ..
	"4CUcZ7+a1aFRj1kzaa1IagQG58aIx2bnTuf1Flr6nCvI+i7Ov1tLPkqXYWzkJJU8LIKcv4PxJQxhomlwYG2HOfw7aogJKwHJtwV6" ..
	"S6QM/lyZRrZPAxrzQ0OXI6d2xW6r5rorAav80GRZgzm2b6PIxVpy1XsPbR/orOzANxwfCCIFqzAuvIMBI5RVW/kXDgunxu0iw/tF" ..
	"BUeUW6zGj3rvfVTeO7esbvm67h9EOw+cITW0+5HuVu1COGjFeb4Azj13uHTGM2E7IA38tsZD24XtAfu+nHhGmchoE69MhShRjyVG" ..
	"tCJnX8MmZn5uh+p0j1KQO2lLjpUKYM/se/37wCcxU+HrMZCPznPpBj3891xWFldRXgohkOFA+deJJjUpNRJL5vZ5vml3+Dd8Q9Rx" ..
	"0QbnwqQi+Z2fcM+v9UXEECSdmuL4Q/jqCwALzpSq/AjNCEiaKNKPvsYYGkC7kNOK/UvZJSD4cd1ZTpdSMpG+leS4sH/12fV3x33g" ..
	"rTme9ULFAeklwvD8z01HG2stNAgp5Tgi42ggMyFhdVaSuSzusLp8PAtX8EWyusFaPL2iPFEK2hIPTLeVQtjrBrHAs01gVwdVhotN" ..
	"mfdKaCR0U9kl9pv+JZ4hw1ZIUnATascqukSP62bBRu2+10X8CjULCQ1Ox/owfuFEXh/MlfvrHzo8V+ZwhPoOtwkFGi1Ko6TnaybG" ..
	""
local PAYLOAD_P9 =
	"cbKXuBQzZ2yQdCWXq9ZCQF3EM1W6hkGVdW1xWq1n5PH4qoQW8aUqrg/g6uhn2aN9RvmROoBian316Zc4XWYvwEPPGu15uHuxfjwC" ..
	"WznL5rL0gDFHqDLhjA+Kqptdqr+EbC2Zv0i/KPJFbnz3wFy31DjgIFrr8AjKTeUA6KPWi/3VjYJB0O5OORgEW+t71sUMQhhkrY1z" ..
	"Ev/7MLHfLTbN7fFpZ/H6JSWYTMfFtva0/cSozzNKoA15kvA6nuC1//Rii5Y1YWaohN0wW/PTkf03XPqQdoIQe7xuTsXkQS0T6gbD" ..
	"qOna7ApHfvVc3gecvSjueqft9sDBFQtpbOIDcmoUwo14tJkl17ndJs0grvnRWuG3Wm5JiwkS+jpoxcPqu0TewGfOX8FTTpbyw6Ie" ..
	"kb0FhZPm5kDIqXh1hpbY6WVxR3A5tEQxlktQHtSUbZ4Oy7hITGKnbxNgexVzkxPQ5Ps8RYpMZEgA5xUxCmuCAuNjfecHlMYnZUed" ..
	"oZZeVCsIyvpXZMrzutuI8WmKaZUGi8+7Ge2SVdfAoY1UL4bEx9krQbKD7qqNcJ4VQ5R03F3JjsYo9Oa5NvJh89qrsTwhYxyrg4EU" ..
	"R6tbyLWVekIKRa2kK1bAxIl973gKu23KOMZ2LPHz8AYLWHoxQbo0PqkKQKkyEzUrMGw+F7qJQ/ssw14ehz6w5TtImM6bgD/icaxE" ..
	"Z7F/IcfFKHVrBWU9Jk+DTe7qbDTTWtsRmXdtT9vVVLKBAnDuMB0aX4xUL0iBZOv7U/tEecNfVsWn5K3r1xhVkJl3ju7G30nPysnd" ..
	"Q51qKgxyOASnJsYhq06tRA5WyxZVwa1YMAY3lZ4RDQQEQXPUgB8rz+cEAdbweMrSSQ1rkyGP/IIX4ABeFfeylAXrMrGY+7U20W7Y" ..
	"VrM0Hvy27h8bKLY4Sdae9nIABXSrdjb3Dp2KylzoXmYFjW7QFOLz2fhDtPdXwVFlP/4bIwVv9eAWJYcnm5bFXw8kuzdlnbPwkL1T" ..
	"I+zARfJtTuloRuAAhAHaQyiA0DJvlGRc4tOtcODZH/5SuKGtPyD3A1vIeGu+DtQVgR3aiWUkwyqMs9ToGOwp3+bxBm+VaDdhT0bj" ..
	"4k4Onq0oZkZcbaC9FWGb2jB9ESt/d7HxB9aKeAY+EEbns/aB4RN6id6EKzj/PiZrXwuzOwCO16d2zDUL+a5qb0Ods8Vyo0aWNICD" ..
	"zvdsJKsAQY1oE/ey7Ao41ftjfhcbdpvAvIHjJJ9/XwxofHsdP1FyzLLAnSIZYzA8vR5AKXwgNAIGeLTziscoceaGbLz05nzx27WF" ..
	"MoV3rt6FnP5DhNCS6ObsF/6sRo/jBL6RfS3/LB8wIEMhi5OZUzC1tpa44zHrkn6WpSAwfld80GufWc7nrtq8rs4teex4jTNRPxki" ..
	"L9LQlRMFy6FODa1xKHkaRWqjH5ZrzSB+4p16R/6o+Vdn6n4Lx8dCygh1sqwILe1cHgiFihAdMz0Ygjq9FP4asVJxXF2nqxdg99jN" ..
	"eeiIPAYYNmqH/2sQ2szS5LKKXxBywi2bsKSBQ0YHEWp7TTJtAstjjRuDZIMAxcISB+Cbbkfp4397aSs7dyoktf9DROMwf5RpiGvm" ..
	"VX0AZKL1+2gyrrY8LjWpD5p+1OTkYsqMQedKaD2wa9h4D+eflckb/Ysxd0bfacIeJQqjqOEhRLdYjEjS7fyUtTR18fnVIM0xmVqo" ..
	"QAgMV4sDAeCdF8fd4tbshXN++OBS/V8cV/VohIgIt3vrFi2yzhPXc+miHuQDYx1QeT9gYHkA7tBL+ID9dps9heDsCihEqo9lmvBI" ..
	"KSXXq5X1BcrHTEXw3QSFwLenM4pQuWDRfzjQJKIVCAGawjK1KnbBhh1RmqzccjXjz2zXrhehWi0yS2KwiadDm3wGOh5OefyipJqS" ..
	"HTkJ5MxjEwr7tYEx60PHKe5sD8rY6lnCHeCxlU6u5WSQsAJRVibiioo81j8oqTbZR1nkLVKKiBtNoO+mhkiflOrwrKx54VwSKARi" ..
	"CBj/CpVqT3TZBwU6I9R8mBLKJily5O57NYsy310yW6mYk5b7hhp7vJIK+jb059XBhUtsLkyMKBP09LfVB/Npqn9rcn4AIsB5DaTD" ..
	"SzGK82/74J0HC/TsLcTbeCf9SmtSH5Y6IZ5tHLbpHuio+0/LROoN0gckpY5GGaNhaNm7l1qXvb0wU3S5b0tYIGrVOHl9BuUS5/es" ..
	"YUsnh2Ng7hAQvkkQ5gac3PTP5dc23UHJt+uhKhrXq+SxetT48Nt5O9WW/7KS0sEREwbrkJmuaGEUyX/cHCTsHP+IkikdYBwsdXEu" ..
	"qT+I4QFFBhYBFwEKeGD9hT93+1JvRdO5rnk2AH4sy7eUCiXbDlfOO95oVHYiAamgS724dutjgAf2h/Nt6Rh9eaZueGAJTS/Isffw" ..
	"R/nLDclO1DVCxUJXylcatPSSmt1y6Ho1gqjGKJjLSa2mfeVhK2PEQ/izhuOriMEVGSgtWFaRSSWJ1CfXIOx0A8EMFC+tLxDjiHKg" ..
	"UITc74tGTpMaq0J/lrrOba/4dX729cOPh57xzIJWLwSe0UjsTtaZ5aGfNV8saLK4HCIf/WIam2ys7wyO4JJWn9cDoRwoPAlLwKbX" ..
	"v/nYBwtKS7OSom6/dmzLo0u4jXmeICMnuRx5r34QmsfG5FrCoiUFdgZZMXGalgBzG4yWX8OB8EOKbCuIhBFfTVx3zn5vu0oImTSC" ..
	"HSmxMuZDDlHikfFp226s6Oo/lKKKySvItSepnXg+is5ZEjYygxCFm5uAHVHC20wMtsk6QaYtt85MQvRxw1CJjB27FFG4sG6GnJPN" ..
	"zf66fZlAX0hJaEkHFARfBWr49FhaRRFf1gS2V5L1b8rEMFW9/DtczFSjBEnassKolR8myZ1niXjQ1ki1kweUPm8YHgM0TA8kwDqm" ..
	"c+MI/oQ/fV8yfypf3yziB8cOl78rekRYS6Wl/m4S09vPFy7KOy5WCWptTfrJkn/3y299KEiOco4lgYneVbfDqv6KZyp6S9tZ9i8e" ..
	"xaYDplH65np5N7nrjqk4IMIDj2qI2W+SL26TI9SsDNObZrg/4atOhFK1lv7Rh72Un/aFn9/5GC5Bc1cvSQTyqK5r/CwLhGoBS0eM" ..
	"UygR8dXxztf52cfo9iZ+2juxpHgKCjsqS33Ok8bJAZP1G/He8ferTD6sst2xwDRTyuyd/spyjQAZd0xM0SfweeNvxoY3ev+NOXJT" ..
	"737pOhSBchI6kdgNFRNjzcxU+HyS5tFjcpsVzGS5XfGOreiRiR38EfGEMZLTZaoDfwwmSsTuYUczhUhGzj1+Le9bCbMekBNj8Wuc" ..
	"wCPLct/pXP/9yU4CVqNZiskEkxVTxy+khH/i5e/Z2mhTqRFlSmGC3orbuM7VNFEQllgRcSpfVAV3CqTcziXcsbNuDTjyA0M9tVg5" ..
	"BsJPdrAQjz6KDAVYF2lLirRuQTcyZnGuQeegGiUchgJVjPKZiceq5TlPqoaP+XloPoQ/kBsLkBtAuvLeVry2INj1khRnY5ljNSAn" ..
	"jIBXPbjdkhv+DL4ytLtayurrsWaMFdufpn/FNAREheZaqWnprwq6oM0f1Zsp85d+0/DuhRCEm7tl3hQubdA7WXBjBByQSBRU3be6" ..
	"Eed/Ixs62z4D9ur3LAZ0NJm+ubO2DLSvGO/e4P6lDShisEHe+LlxRH/iiqP+hWIj6W1dJ0OCj7hLmAAPbrEQ2Afyl2K9+hMJwluO" ..
	"V8PTjOhyBui2iLmqNePfbwKd+CEwev65JIuMqh1bguaP5oBacMUpcmbD4N2koLKz8a6hJ0IEPO7ePR+v0pj68xSigySF/bSEEuU3" ..
	"Qanh64+coV6CIyQtKCsro7NHqeedO7sg68AMiIa9AleS/mDfSnliAAci282vXhoty0dTNsKoK5n5KQ/GdMAGOKOVtwgwbTF8zTSx" ..
	"BRlfQGTT9hW0dCk6wN3QGxE6zOkzhioT8YpuqKHJP9yJtKJVCNUiOQ7Im4I4CPtDqhtLFlVlRHGefwVQ4yqiGaSf/wEwKZWqFH+V" ..
	"d/nUq6F+j67SlD6TVUBxsGneaBs7FgiQ94mflLm4Pf5Zx4vLEvqbAABCJZXD4qFNaC4uRm3/EHw9wVPzIS9uN+lAk87VKO8AwkK1" ..
	"rXTZ5W/pUqmL/9wjpCi4OTclAY+YeSCaAVq4d3PMXCldy2bJEGgsf5DzgaQ+eQxb1CO2F1lXyb/UW1nSUWGFAKiC3F+DJCbvxzSU" ..
	"18BXKEQUIuuEzDotc5AdNfiCylILaj7/RLdIWzgggzE0Wj1BdAIKYkgjz/txSaHzqxO7yFJLD5bODplF4qXLc2XgO+XFckk1lA6C" ..
	"trVeAZKieIW3Ru+ECht0Rg3bw45lI3FWnUKOzC46xBMCnGH/6M2qZHygzmOoDgK53hAEs6eqbJ/rH/QXEdsBZg389+YLAnRTnlWh" ..
	"t9GyN/BXJqZVFiGZCCZ8yZGrRiC5V5pfchiHLuKe6yY6ORn36e512Y/FJ6O5rPns0y6plezlh9eE6e+j8vRqg9t2gjLNu5W2tfDW" ..
	"eZNALomcxCBf1y4R+hNIJhRir4G7x0sbyN9cob7sA2b8+dCsbvp6bgvZRUB1ZGzkS7j1OIzgs9VKFqZEdsE/LqUpxIrfNA/zeTZL" ..
	"fYpLkv2X9RzKlmbQ+4GOps1pjAkpQTjknoMDz9BwTc2Tr3fUpsD9UTn4tSdqHNTS0x+vv3W+W0yA588cTB7fQqIdsM2xJF2Y+2Ja" ..
	"cstRSXFjrX1s4TS+6nHS3HMxhdm14KEfODe35VjidVp9zLceWRuYCvgsg2iWusu+qcYYmE7gxMTnETkTw50cSVXvYFmNwngc6MlQ" ..
	"ilSmrj2nNHlDW3mARv106wUZeZy0O8I3m112KPoEM2IgB/03RGzQSC+N5alyn5aKMgBQJTvFnzc5isGkjntVbMpkI/S2+SaWc/VD" ..
	"v1baf8ibgzKZ4hKjI3Ivs07R2+RuExMq/ldSxyfsWczAm/MvMgMIHTk9lr88Jts+snCpshkS3Xhnr+Oyq+TzjHhNj3SsHeUelR2h" ..
	"oRSzxEHy0xfB1GrX3JI2gGYOcS4NorPDxM1Y86U8x0WD+D/RcWQL5ki80qR3hvGT3JE4TbT2JIwvMqUcD3xdlcaCTWFRus3IGUCg" ..
	"OrlmHWkXs4oEm1z8u0Fxsf/ccwDLijKs6/WJuG7JeqVWfGD0i6mVlJtTEnN/HwnoWX7qvrJuOTHXwlL/GywCbg2NejVU5s82mHUl" ..
	"Ewzphaq5R/K6zGsJKWzNfpCS4Ba7yNSz9cAzALch5vluTjtNTn22yew9bBItRvPiqHlZ9xOClLc1yIfVeFWNsPAiBYzMIJ2Wytkp" ..
	"9R4dkhnCvREXU4fCAogvob9KXuj9TAZAexSCxMYgu5mZ1wtooqvJrvPA5qUsZZSsfhyvcNZb5Iq+Jb+CZILSNpKolDwMEOedpZic" ..
	"VKFwtMwO4ApLm8iASgk3uo+fQ19xpCJcBO16Gl1HZaVYW6fwJhB/sbRpohtFaJpfBD/jlm/vjrXNNzxypTq37rNCe1kXNahQ7evt" ..
	"utcFo82tKgnt4KdHoTQDuvxfE5f2hLvzz45fixKkDT5eCj0qfzBHYbQ89rYslF/poHscPV4fJoMUQ8Rm19P+xAJUa0xEc1EsOlxJ" ..
	"mHqzsYRX6wqtvmQdH7UpfwqohsNqhbeUcxKC+8RWrtuxQ+rCvmDZa7PG1lGVoG4BQqonT2vxz49eco4e/QTjB9CEce40+LyuEJXD" ..
	"3yJRnr7711euEavWt6luqx8C+2n+ewDN2gZFZZnSEGDaH4fbCvN24IuwTq20qiRNmrhmwiM8Q9avh8XVpBOpkulPTYAyfylT0+Ub" ..
	"qD4QdSV5T+y0SIRhluuytkVqKaUQhx1smWUionxTSjb6x/u8yNHh35TCEtSUS9UA2iCUSPFJHP2wdKaVqsWmVxqECLIhusw83oxx" ..
	"Jo9927morLWyfGl98yyL6YQqiMafsu/xAB5wt1d3McukttnGeiHdw6RtG43EgBVEMmupCG9cjyQWsE4M9csWabAkLFBi7L/10/Dy" ..
	""
local PAYLOAD_P10 =
	"0z1wyfUID/pXdzj17IZCjVT+p3d2/bL+8UuyewJpHex/XiGzups1RFeO7oI7pIms2IWtUALIvueTpaWWCN9D5FkZLkufbuUbVWy2" ..
	"VmMNHrrWUdaoi6cvcyEdvajx/96JMpEYRbEPmQw9ykgY1Duf/m7bJS1pIBt1L01L3wRzvbKkMrzCicgiXQuEb+JLmZlIKpQ/uvjd" ..
	"Pf6uGw8DVXu4ImG3+sL3ce5IB7cws1CVX430HriAtgiWE7rTsB/bwhIMTpgzArqDXNxlx66Kwct87EY5Tuy4k/WRqZYc/kfT/ZTY" ..
	"IB/y3AU28Pn7FYmRyG0cddchyXZCvIuhkbic99Dz3GXFRrnYjls5inBZJO0Xb1Aqjj3hy7Z1lBsnY3qYOq5yeEUrAnRXLg4E/eZL" ..
	"9OzNB70cZEMFTrkE/B1QMJbKOaNLzQ81DaUT5nkqXtgWtLHu/nh+ZJDtEIUVLLrRrbgpHS14wAKcz9Raehtp9bExbW3WqJ9Aofv3" ..
	"3nhdCy0k6Z+pSeS+PmnZq/l6tTgHTA/0Ej+di+/eHBd+4il2oXTG77Wtyyei16l5pA0lS0+OGvu1UA6T/7rOcVS8WqcNjRXUM/ak" ..
	"jWTrMTm77lF9us5cTW4yFhGO5vaOaTWgs+/sV+6gY07EaPx4a9pvfkjhUrZiTUBewV4e22OdGQjQ5g8nyb5L+hfdv9QS1IS4uUO7" ..
	"gRT7diWq/xLPpV3meK43VSsIO4ISZZ5egdIy+N/RQe4sI7zDn3UbNVPalc/wicezIQoUnUqV3NVgS71ojFrPD4ClEmeVMcOHr3c9" ..
	"qDG+81hrlvzCfxVajSeFMH2+6v58axzY5iC66CW6+dHNL1FYL7jokunPagrV+CCGq21CVAtpx2dynqLGwRpsnjVXQXFtOU9/E7WO" ..
	"/IAQp+SDwvRF3D/aspcKqWNjMDeSTMcsFU8SzvES91P92AQOa0uX6PfN0KDYuDRXtnni7LiL/N24PWH+0t+FPN6jAxgOKoMxL0l0" ..
	"UicWfBIRwUEogh4eDi599RAm2lArVQpyVz9c2bGWNt5CLwEJvgu/Eo49K4ok1vG2J4dUG5Bt7DSos4XefUJhPsXu+hK09IsZlljL" ..
	"HHtw411wnuPxLp7r/xymHM4z5Jh+h8oSqXJn9sSQ/wxjDQ8Be3MxUTUlbSMCsJbkcp7aDeINF/CC928+k43T7qgqhxR9WACJrkTA" ..
	"dEIZuY5OuRACnkZda+VjqfUlOf+SoslbI9DIm+g2frd0E0IS1VGXYX3hZkOrqcmVcRoEHHZoPwBG2htIxHIKTr/BMPPw1dEl/HUt" ..
	"KrwgKNCYGwOov6n4ERR0Eya0SNx5zXiQTuWaVWLVwm+HAXZLAkwKHJ3wRDs1ehxmc3p2es9Ha6s3QWLeC+OxFcWGjIWRfPbSP7Oh" ..
	"E4XZpo2hP+egxFQ90lcggRVEBuArThK9B0X5FUyYbR6bQSFatxtbUx7mD4hEM5w7wXckdK4pw85KCYByihs0kWqmui/yasVqonuU" ..
	"1bmkhbcEesZYgU30H1AMreXSE/hSzijMX86+JMMLaGkMG7ipqMOgUKeHM6ke0UP4U2MNJN4eAkMjxuoeKknJVIP+/fuKvNG390Qs" ..
	"73gZTC+mq50R3lu9AhcLGiUWTR1pBb8+9bJ/W4jE7JriekPO89+rljqMbfs+gMRfxjOCLGMpDATuDn+2FbE2ON3sNm5bWeag4qt9" ..
	"14F2Zl8nCIxuuNkrhcFa6CiV0K/UUrCS4EjAltOxUMPBTdYBoDbijMO3l7aeQJ0+DDOfpWKgjcOnA4JzxnvsjuwMuPJqxyEiV7ET" ..
	"LNmSwBV9keYlhz7Joq2wl0Yt89aZKbz+3FoCNcO8n7/k5EUrC7NI7cNGFJ6LFCwfqFF6LeiXmckGgQGGWhJd7PsC56AMYU9cqHwc" ..
	"p6vOGi5EhvKBIUJRq7j0FYYio7kYKghVInyUm2BaBRzrkB864dEYtlL0kGMozrCAT1Lt5XTPkWCCaQwboa1c36cy74VgjvwiSDZ+" ..
	"YKyk07qGekT7tepL1mf0QfvilIvkrbQD4/tcHhQjWUvCGHi+TdXIq+39vkQ4gVw9vvHvYeHERzocg9JSxqXarPlr+hXSI9ifVnrm" ..
	"4vMoSSN7+sIMK1FEYhnrM8/OLQ7uKfKp30ggdwU05ry/8t7M465THEfSef0EUhnQlltQPsEUWLTssPmfvgJ4bGQJ98wAid4AnqXn" ..
	"hj63uBqpaKpME1o+2H2nxywSEflkQ4LKDq5wdUC58nMzcn1kaVYtod8lb/3Uu9Kt4euiYcXbDdjR1jWpIQxBzSs6qOlVam7jIMWb" ..
	"kpI8N9nK7/j5o33R+Vudo3MUtI1gRD1tEc1V9/doetEJzdyLvF72tAso8coDeUicZQMgN2eFF2oOiA8RRyUSBQxxh7p/IZKcOPCL" ..
	"SCOLs+41rImQBYDQg67kJCGHLxYeC1rZzk1+1xqNoJehmh2qbmNOiYRbRf4nv43g7bbrgP7nCL9hafGuxlXXTcJBgULdVacYi63+" ..
	"I7QAUyAlyei8B2devmFdjLxLNfoDQGBRsdiak854eySL0TNZ72zUSRbik9ukwJWrjd5WUBIe5rXB8u12eaRWhYmT6axUm/vxjU3m" ..
	"/R/qrKZIBDJlKCAjAsXP+ua0APOZ8b9Q22dKkkpJI6qC5cZHCFBwFzPou8c7etrK6aAoTkPRaCXKQUKc37gW/id3t7ufbeE3rDRS" ..
	"v6uWksEnV1+UAXl+wr9COfkoDFu4ElRttTpKYy1P6NiS5KqsDLb+Pi+uXLmDFSwtaE8u3a65JxulDcKLxBWEcRZYnx/CKdq4okyl" ..
	"6sL40rr3VOWjb24KnGtFjEgGntF/qABp/VSMpya0YfCQImKe3ypW3SILmFovLS2576TO5Ho2aNODwl2XbGDNi+EHZ8WLB+7rTlB2" ..
	"i8veBDg50QS4ugB8k85U9FLI2+XvoPe1St1vdqCOY3vdzmxa9qmK+505AltJUHNWiXC68UaxbVyJoRaqz122oeB9eL5aPYCSfLkM" ..
	"kQMcKY7AMtjBIYHXHUNjsk12FFw6raaJqHcba6k0RwvorYgiQ8EMtmtMsJO98MYqOwyU4+/KMRee8r/Zj1/PGGesiabEHLEc/mLh" ..
	"PNDPDpJwtII6BxB1P4N5YbZPNPZRJmGgtteRs436z14fWCZFFPxJLCuZFPo0nL+WINDgPUKHe7+gKwCl2R+PiwjpQl+V8fX4iiS2" ..
	"kgZa/SjjZRa0CgQtDehaEd9mQNV5rowN0lEXEZNovf5Sq9GQzD9w/DHBRNb7KwvSgctYw7fn46J0WKJIsH9ympfvxNgFN4XINEyJ" ..
	"J/x6x87UHbygm2WtVE+AZa8hRp7jyTKEloHE8sjRSqX2l9Did0/D7axTDCNB33JUy1mAPhYdOKysX80zStQz9sMCAUYY4zffeK9X" ..
	"MoCuY9/H57h5pytKZMpdIOOrMJrPS9PzZ6vFshWdlwq+VZiraaBqyeVFWayG+CTIlYKiLGv649uB13HAzQI9Z5ERHD66OI3jlFql" ..
	"zLHs58IMsrd5uqj3gtZ4ntbhw+RPMOm9PQTOtjfo2nHRTLKk/Yc8cVN/aw23gbmVhyhncaRHnrfUJbiedCQywBAF7VWc/Mw2jdNc" ..
	"7z/m9w7YQPCW4NmcMpR/frkWgM/1XaAo06OKq6zYluh8dE+XnPZ0qrrPfJZR5sfy4m2wVMRKj5sa9l/CHb7Cyrpd3GA9aaEN7GpF" ..
	"1wMGNYn3X/oVi/Wrm0vbCO5RMHzMwZG8ppGepr2dSBuIeD+Y9PZqxTD56LgeYIEOQFmYtZvuNfON6hjH3dUlqLc4oeFJYWh+Z6Eb" ..
	"4FcY5UF3qd444X8M8v7RqsTxIlK4Ww3D81XiTerOp5X5QQKo28+FdmIzLUodx1n4J/UQMkADEJ0mSo68gqCsXkrZNrHUtaBjScx/" ..
	"xoywvWvb0jjJKgC36s1zgEWqGqRFwhl8/wQ6oxtIQM0cMA3AGXoWTPCoGK8ORDlzcLKUV8LZI/2Wh2NatrOQy6fXDTiV3ykm/Hmf" ..
	"GuGvoOCMi+H9PsyaRBYWwwTENQbD4oVJEkeEndlC7vtLE444jNbbAALEvgRWnHIon3j2fabI8YX6vLHvSrgClEKzxAe6JKA7Nheu" ..
	"D1bCT0VOWKh82kS2ccOzYKaXc5+oIEfeONUtNBU0X1ILXMsdceliQ50uDpso/N82p/LAT2AfS5cjs2JLOqBskKrQpXMzlSvRYior" ..
	"0ZHqTsUMwkot8TjmS4ycrgs7YAXfUglmjKzOXFPnIsCyLsHiOh3s1giyHYUozjMWIh9x9LcHG7kzjLwUl0roUZADrs280XR/GSrY" ..
	"P491maNs7vhwPsXtxSGM2AsmsSbRc2AvKIWW2O9aNHvJJEARVeKHMCQPK1IVefQgIAxV5hl4ik2GNItb6CbOZZY2Fk2DEMwTHC9t" ..
	"DYzDjpq97oJdSeFqpMwIRVZEHpDyeJ51+HskQw8Z1Qi9ysXi/uALa+gOQS6wOR5THjJZevuVjPJ6JQPWS6O980NRN9RSLbNYBtj2" ..
	"9yJF/PK/suKhmIMH2KFJacoYffXWSqhDRPfKqlLPO/jAX3boT4lN3KO58/7uIVjZifZhQkWrLkymVPwoNHmmTn3q06IoGHD4KOpN" ..
	"fTJNjPf8In7QvIp5757O1NdpJPAVYZo3N8+WcMPq7TM8/1t1dCk9KuAArefgDWkT3NvO/t+68MmG2mx2x2YgBIAquXQooUV8FScr" ..
	"Hyqa/SOduiCAm6PY/2dtsuGb4z2RQ9wYkbvBroNTh0J8Nctu69IR0fMx5Li/7JDI0Ml5mhgPEJbS8JZ3Tkfuj2OYp2nAQkViI7iU" ..
	"LvJ4/SGSedOBkAYmFVQZU8kwQHdX2xdATVSI1kxu0R05Q423lDz+5K8wgXB3nT22+e2IrFb6FoHRlqAQUF3qaG2VmCanqNz2i3FG" ..
	"Y8Hp2cv6q6i7dhAP8Ji2HZmzvWxbXBkKo4c9t6tBs/pkPWOC/CD4gQGxroXw8n4hDafP6wl4nN+6mpd1qQBnr4GxvFzy90iUHUMo" ..
	"zmBhAorGbtcwQhfZKjT5GFRSbo4NrSFUezpMThl/0L8WsrL6yjzQdYasyJRj0o94bvxadNhfZ53OogJ1PuAIfczSF3YXG63KEnwx" ..
	"cZyVHBMqJuogSAuNvlQL/qmLTC8k2pqEy3TDPvK38T2u7MD09nK1vRmOdntX2ZLdHvOzxewTPaP1ef3jkIYrDq/GlmuopNNL8P9n" ..
	"PkQD+aB0M+5zoTTQJKymqkQ5GRNMiy3qtt/1hePdMpAxIXqqs/Q4KNoKKQvaGOZmoy38UIPtdFI6XCz2kn0MC7OkYBx55rp5uFvp" ..
	"YMRfOUtfHeCC6n6M3tdlBH5tx45gbLx2WpAI31VrbOfHYae89hrk4GGcQlyDhgVRRGS2YfdD8jrMStvjAFnVIscpv+6qIwosk1e3" ..
	"YxtrTVHrugus/kF/lP6bQWdb85WAMECwoU/xfdC6f38h1DwxuLlEU1aOdSSAvu2B1Gv4pphbcPJkzdf+iyrmjiWLOcCtXVbD+aeQ" ..
	"BZZFKju7oia7cBObplQ3+uQNK5+O4A14GpJSdJgkxxKTJ0erwJBvMOrc0yVUOEcWGTAfMJHrAs2Hw2KKgY4Cznz4Ehk2oXKDPWT0" ..
	"mLEpGl1visT/RV1gEAk5chXqw42Ykdc=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10

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
