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
	{ seed = 1606939597, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1606390747, exp = 0, plan = 0, hwid = {} }
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
	"IHWsVKcdjB2JIWkYapk5f/zXtE6uLNYmPqxBTxBnak2kxmJkwNVZIVBT7c8A8iXDU0thhZ0PpDVoO2aQszVsXV9vV2H4kfVip6A2" ..
	"sYPaXAbMoS9ft9WAdewklRx2saRdlB/JscwgewW3zXbtGtKtJmNGHIjcB4yOjduQyLJTTbTf0pJdmxIBPcfjaezy8vD1XIF4fn7i" ..
	"SWU2SUaDUcfWqkH0xRzqQleDs7NzB2jmlPP3EDOmypRKy2fZCmDGG7c6TIFS/cE2IoLJmLeLQ0YRQwWWMLjS5zW1ZRXd+6E9zSNw" ..
	"AAn/SGynp2g76wwYrKdWuHQumPx+k08EDIi2A5scx9nEmLHVO3yeioURIWLzoKB2OYEeM4zZyYICUUBfIEMjQ1n5W09oXZhp4m12" ..
	"47LKwkHxUwi0jck9K1gvYU62j89FReyXeRvDI54HwMU9o/SC97WlLjy2tWPiEmcGAY8aX4pk/g4gKD7Bs0yVo+TM59jjTbUVG/QQ" ..
	"3K/Tl0uWaDDSuvrqu+BubaSreEt6X+O4Zt/R/Q0qPqAsXEHTSA/sp4JMSJRCJhdX9zCtYyLuU3LJ4TpfEEPUDQU2gLa1IlEXor/a" ..
	"V2MbTum8woxL4VNMrsaJbNdyTGvJvjgiD7jTniKQtFCnr+/L2BLQzog/pmOTu1uBvtVeDKKcRF3NcwOLqFmhpSstEbNsnFFL/WdY" ..
	"fgOFBdP9TAbzP0dsyLI8f2Aa8plRs7uc6Nlm+LN2UbOCf7UyJQfl5909cjokksfvRB+L5hWC8f8jtfIpmSrQ+2pvBhoTF3hv23Iq" ..
	"OILdMkJ2sWUYN6J7FMhYfiOQVBQlbmUCCJKGlL4nB+h7ieg+XGIKPouUZAixDjYdSqS2Akv/SEZtbl8hn271eSWbrffk2XAO7+3e" ..
	"DJxhJOvUKyr99TBHih3TdKeVSlar0VCUubuvv4F+YnVrUNJMYC/nEC8t8aYzqo7xqo+zDmkJnzqsLM8/qZrarvSK3X3phgJyF9+n" ..
	"Quwf+hwBg26+xVPWZBOC3z4zbM0cXYDE/uruQODZnhDOQfut4T1z3199FfVsUpJ1HAnAKNtVrCtsh+kVMJAovE5eWStVAfxm4Mef" ..
	"EHuGsk7vwGiXG88QA8QTNHFgyyPRpuxD4P9fJ8qwoXB8UshkO870W8ToT5huhmgc/mNxIVc4J8zo/90smC/lRU/rd4v0esm6v/Oa" ..
	"16Jli//8WHLBgqvFoQNQqJJBmZMC4p1zmMnthexzyR9kx90WFaMk2kGKf15hvbG6swPc9OR6rczSd39vJC1MO1Te6MbcoduOwD/k" ..
	"i+fBwPhccv50ZYVdVKR5QcsbFoygmCZqe8NKhj3X5cMmWy/YUdgDfa+4b24uqWBix39gcyNQXPvQe3YBJmGsU7/K4qp2WuACCj97" ..
	"djGKkBzC4aVV3xsy9T8wicaggVGxRlMx4n2gdznvlLvXXjVwinoGfxW9KEejQOPwL5OIJTWCtmotF8Or0+Ihx5dqrkeqK27rBbfC" ..
	"4qz0dUoCf0pzao1owQ1c+C+xMFCKX/ou3PPTHerpTiSWNrgd/uz3yoicepxF7ilDl3OOhYYsb67nSecNb184x/E67WmZ2NdGfU4q" ..
	"bCUU5JrNPBzJB5gUFaIZ/25ZHl+zb5MAQ0J9z3f6y7Pa96sroweZuaAGxoLal6eX65mjo2Os9KHmLbr94dIuNquQ2hLMFqyWCXJW" ..
	"g8hqWRrmOIL0998pJVJsY7p3kogDIPhsSQitz1NgDPd3/hzsfyxaoEpqlWOrhJcK86/egs0XG2WFFMfUzzTJE/3SEzHWgNvEgW7j" ..
	"CPT1rLOzUoRGBp0zXR5xv97QfW8IOZDPi72nAryk/k8rPsWtf2XpiofdvjGsZOVvcVoYUy7eG7GTu2xCAafvIVCbDwbWcil6iLbV" ..
	"osQmYVd0Uekb0DKQwaeIRIQfVxiu/MSsxbsfW12y/8q8GXGsB/5b1bb8QtF9kaxP+prXA7I3p+Bk1edOfcxIwFDf5fSbaHRdEeB6" ..
	"97W3Adh1zzQ5esqttdtDyXrFLsHeT2p6TCv6BSmS9FVjxqyyd0b2OL50dSTvtt0XLZ6O/aEO6A3sjiAQHuc37zjBavlCT5JZEILz" ..
	"uI3mYnnAYdVtrw+GZx8/gAtclATbThU2TUh0byb/Uwugk5Dx9spG8pZ8iXscyS7pooKJQYiUwNoUx9g1lXfg8VSmEftILDldhEkb" ..
	"yBsQaLGi9OdeV3Dyu+FJ5/vqAK7J+797D2qbkguTAF6V6eSuv0uR5apGPgTmtXEqX//ql27aHfnikEij2CqUoXPNMeUiN87KQxzr" ..
	"tfi1wti7n/k1poyJqPlOLAsyg2Od4uGHkO9/rUaP2IQJuivnj9xOqfq48kBMOmm2JN0CNsKNDGoo7iRsEWD15IFVBMoA2nv7+r17" ..
	"I3fie/C35QFtOgSkMXuZNQvidmhPe3koPMDNIEuvwLXLFsHzSIeeco/abzLgGRvSBXUjwCb7acZYmdKf9MFwCAal+No52mCaj5zt" ..
	"H1HeRn3AuNV6HfhFDvJOmRepqc1wDWihe6vqwrrm1XXOoESiWfQqY6QWv+bCizhv+lVaBNKmt1goNudXI9cX1dotdP1ovBCJNDsI" ..
	"CywAhQeBqRN3G6FwrJ3WZ2lj7q6ADsJOjW7IdIHgTRDA1703RfHQyOnIpfUnw5KrIN7iFZiceQdf5U0Vxq7vwsbdQOLAlq6uBhEc" ..
	"mq5GEkvJil3ydRIkO1bwaFeSiZqtQjMSmMhK50ZX39WCQHkyIVSS5KIrdAX4ljzHvj1B9TGL2EEVF9quul/mzpN/l4kYvnQV6sUQ" ..
	"3/fZo0PTBFGsezDAPYao0DaDi8zYAuUQ7LZ2T4OXVEL3KtNcJ1R1h+rpx+6bb0ul7L8SNB0iAycMjRyO+Wi8t3YVDVJpYdUByR+j" ..
	"TvbGSMUVcFl2vMAehCG8X8kNBBL0QIDvU4fp/AdNyfCSl/BPmJMHCW8yWsN3RwcY/3NPlD4IvN0S3N+/SpzF8rZLIc5C1GYBl/DK" ..
	"KdmNxX59y4nuYDZvv5BRBBKrHT9+uZHpkqHcPp6hLO/afa/Yeit1ndHkfqDkSINKtUjjf6TA4y0beyPFhHp0KkDTF9hClrzHhjXs" ..
	"f7brjGR6bHGy7KdW8n0Wxm6FfXlcs3Xt7ok8GZX+gfo4WdrbiYFBJybF5AOtYiY4gfBa5O1GFmD31qaRAJw0f3V7qDG3MSflwvPv" ..
	"y3CHmAdzWxVLg3wllycDIB75mZNb2IHh/WBIW+CKiiZIdhGNG1kzX6G8riGUa02m287Em2sVrXK6wLfqjKb6oNRO+I8jjmSoCtMf" ..
	"VGhjd9IpvoEUo7IYACkvo5iXxdrU7acqAQirzufQHt5h9Gs4G2syknfkpyZkr8JaqjeFRMLtEBLe5jJgVnntIvjKri1mO4QjzOrd" ..
	"d/R/j9S14Syz1rqITeOAlXDVWp+GfRH7cAKEYToaPCClu+h5VEPgbonUv/l4+Rs/odhntHkOyf5Hh51mfVUw0YnXZ0wbXyzFBrzG" ..
	"DQFIOkz6nY0ngLaRcRIx23q/ghrSTBCgIgWAsDD8RDzhQ8DH6LL0Qp8WkEVDBCk4xxhNgVpLay8CN/rUZn7HhJoTaGD5gAehMvOT" ..
	"m3Y8G0F+OEJatg6J6ZVmx0cXGjvp/+gKQpBsb+n1VAd545zQ5juRnTHgjgPOrNG0XlHBoVh7yRbIP7mJL/1fMyF+7OPWVRF9j6rH" ..
	"np7MML3pIEMjrkHUrd2lKqiWO/v760+E0xtvtEDbaRP2rTS0AhoHSfhNCsoBLupVIl/5GIHHsCXWAe64MNLp9XHI5d0WLXR/Dthx" ..
	"GmQb3F6aCNckLpSLSAH4F47NwK9iIPAmrmPL3FRiHA8CMubAlu2Gd8oP96KSXaEPD9jEOVghf12+ElqddocnuTNAEb08J3J5liX2" ..
	"QJtoCehQk3CivU6XM48GExuu/yCrSv60YCFTSJDnUEPkNx0rnTy9wzz7ITaHYtO5Tt/BcKFh/SYj1sHvVPk7W223sH1Hv8fP/Gyb" ..
	"hS1ynWrg5zWbZLdWPNuSR6a3WyEywnqWiYFTvcI45b2N56a0XZN1lriHZQRtCiutMdiioGnpSI2RpuIftWx/VZ5vGfk1Bmh1QYdl" ..
	"6Uz7f/dX7C2R/s/BFxyOkvbxNnt+mp1MCZJsFYRFzVLys+c3zQJ6nEdVgyUaCuL3lWoqfE+eoX1Ww+F3a7r9aWDnBWbXFBN67GiS" ..
	"aLO38whSVBho+L5acfhP4RKmkFN732SvSY1P9rTHSj6GyCBHcAKfrSDC5+lXutKOWBgJgScP/a6tQVfRMf84nQxKX3JDB5SkiR1u" ..
	"w7r6ZrpInXdKbEyvRHM6mTM9dK5Kxs4D4XHUGHdDubCY3KnOnKmvKHI0DPRw3tvLdHXtUNXD0z0csdOoGAbYUuRf/qQyrboyirrB" ..
	"dhx7rm8QByrrGCbgOkGOeEs1oyEj0ttYmD/wDnOqFxT6/nrLfIr3N/47LmNAtP47WuXqR3xEoM441hy3aC+Ndoa+CYbpvl5Cvg39" ..
	"G84uwcaQCrOo20LaOGqzDFzbWfDxABWkhTEaeXudTuWkI0ozNpXgBOp8FC+dnHWgYj8BM9ZBjoxcG67v4QCTwDD6HkL19NLAB1M8" ..
	"iljO5hlKfFxggrXaRlG1EY7BmF7hac4Tp4ZQzKwI+/I54WWT3y4tCzxsM+neK3PDYWNNbz1DknXsE1vVk1Jxo5OQeli/5BF/7Go9" ..
	"AIgEb+jTPgHiG5B7GYKHMSEJwobuNOAeqrQj0QvNbe4IDRglAukqt08bm2pEzkJyf1jWECyioII087O4tFGrVD2a5k/42ZkhEAej" ..
	"Jj6ua+W1c1K1ch2xaqp3g/267DQEyD1rfnHMmqCBcehFIlrsZ7B3I3Jd4CkcBHkgE6h8JCFKBIL/Khp7aZrk0ojHKWbr4yGX3D2n" ..
	"gbsO+AOTG32JWKLDBrDq02+CvAFBW/g+CZwn9C3abayftih5rpC/EJRn4UIHfonnQ0awYHPsLE/um2k3H5rtgWHATOFGN92oY+ZV" ..
	"bkCW/O/YrmMZqSr9lZLl7W6zpy5bZ2ab/pGA708AiuN2KjzLH+xm9GZ833p8T1cd+2RGwG/AOulrYCOp/gE6ChaPIMEGjIWB3ZSQ" ..
	"8IMOJ4gcHTjcEjWcEJSfOSmQlHmvEXRO/45hiJ3c7cGHxnw/5NV+m5V9tp+Buo5/W5lKyMd1PZsYtjSFxaXDUrqxc0ly7qb6fKDz" ..
	"QUCl61NZtwWRPz6IhMuSKjcuL+nLH7tW2O6DF+XeOGwit2Ojk0cTb7c1wngYsSm28N4nFpJNxug/APhnWM+4qKcsEuK5ZzhVN+vq" ..
	"9M/QXSs9xKv1xaYa80Ge+YZwQJ9FifAsQGFFu6HjFri4Fnd6WPDOPQaCyBNkSLVnKwlcCk3VAg+mvs5DJbBq859MuoR4vLp2fFmV" ..
	"y6vkcnbLwfxTTTNHi3iNSCmZC99cMZPM0INAReHsF8GmmGAk5KysqjgiZj9vU/s8R4ctu+k9CrkjVnG9HB7aTPdPRhiVWuwqaIZC" ..
	"00v0eoMIEVwjzoe4jwbj86kVLPphkUyiSKveip6XQ7Gpgg9pZPoGSjueQ24umdOaw0u736EBXLJPb1yH6/usMxKxOmk3mVJdiHt2" ..
	"QJVYHD15Wyx35XT314VypQI5a9fsFhClr/T+cIr/GslJrHQXfraydKRD2riwung4ldquDIYbufiErIFXTiSrFSl5jOPqPYgqP5qV" ..
	"UUVtZIzzlqEEWVVIQYa6R6+gBFDU/1Cb965mwap+IbbtTIqyFATgHCxiHTpEHVOO7szhK3lJLe0K6Pn/gnImJpC9BUu8slORbDlU" ..
	"stsDQEisOpku1Y+WjBVRCPhGaNh1eqsORIWs4r/LMcrTBkDQSjVczC/pJetyZJrhqlgOdII5VGalrKmIjAqYApRS9ThyWyOo7eQp" ..
	"lz7rwe0h1QjPIYabDGn4dsKdVmfs9NmzQrHvWLHtKKIxwpgbK6NMRPMAS1LDmRcZjkw6fzYZyc7VVR8am6+mt0m2yTYGQPvk0q4x" ..
	""
local PAYLOAD_P2 =
	"dYiReoZMGiwwB91NKzQf66pQLa/JVx6/8D3sNKfOmabHK/+0jta5sZQWa+LdMCwS9+kYOHnCb5H6IjBmwyVQdbrELTal+f0ldP7T" ..
	"vK6eIzx0qJJb8GWr0qOmGQrdq8h2Kl8rk5c+MKO1I5k56XDwUjxWvDcCbM0Om4cBUwB2zKtOclUHOrtpnMdfZ0cjFG1NMQgpuo2E" ..
	"dC3Gr3eqMwGhFtL+mW/K1CT/m2YZAnhDVaHoViDUvC3WgwnDSPNi8tLlLbTwhThQoGGYDB9O+0idhbOK45UQvsMFkbCMqgVjtvDS" ..
	"oIMyJTOqF0onXuAEEg2BUm8o2YTo9asgg5om+XSITlFFlUhCgmm1LmDAP6E6zHahjFq/j32vM/90WcXqAal/r+AItRJqOukg8tlI" ..
	"zxApqCV6LvtwzbLPBl7PoZA8NSmxUfbwHL8fU8lFDombEfbYDXUsr5Zdyyhhvl1RJ+r64LgNPg+39DFvz7f1ybDZkaYfcMGthc8L" ..
	"NEMre/IMArE3JnP+0BKrxL3a+w2E4+8RkwFhUmhUGqcT6Uetrq/i7b3U20zk8s5n4xYuR6ZwZSwmqR4AiLPE/2t+PO4NP1QkSoOJ" ..
	"RNxToCArZglBoEakft8ConJxrOEnBe5lOfT2TXT3AGFFtYXxAg/JWxTQuSwxlRRR54Odr1Vl9eq52JOt1lUpasBrlH7CK7iLbysi" ..
	"vkOHjYIwusmxVGCoUNVAL8q2GuvwrdO/dSGrKFeEBFFXOAEBIxfEJ1nG3c351IUlTkTjC71RAeJB1ESqOXJ1vtX69dCtEfhcPeKe" ..
	"Co8B/26kcnw/Ig/TuIy+/1zDJiHdkzvyzbVQUcFB38Blr/eVlqqnyc6TjNrRaQxwI075qj2i/0D6doyBovgogODUSaLZJjbOHImx" ..
	"eJqiPbjj7wyDspbVq6a42uxYQ2pmn7S/qsrp6upiCTyOBfA2MFPh2hCLR6Xuc56XdbCIm6u2i1Y/GcTXVsFskADa5sU5BLrlWX8e" ..
	"CzPnGLrhZ23O4sBW7ggvo1Xnpa3DEl2WyBEX4q2wqPHJ6rlP0EKrUZaOlsBTGMDPMR/geFP+U+pXrqyDdaW9Bcs8/T5v15VIHjZh" ..
	"a3yNMi4ubEt5pbQozxhVsR5OaP9cuksMnRVX7k3/DULv/5F/ywj50V2gm+0gNdn8VOkbfP2Hy3bg3kFlUM3mXGj6Mthc8KJ3oc7C" ..
	"DR3v5rMWZAZezR6trx936/bZCzOt53xDEeBmzYmpfsy8fVmeDgkmsYDfdlWBEQyq7b0uh36yzT0fC+mksIS///OEH5X1WWZTZyVc" ..
	"q+hhsF1rs7CkYKf8YqeOl9KzHybb2aE8xOubRhGn9WPqUbaRqDTRzsAguk8Qaa5nP1jUMNCA7IoiktUl1sX8QBCqkrtXGtbarRWB" ..
	"ZaKFcH5sgMD3NnkGSPr7jKZ0mNDTXala1XpUI6NXaMmUtvIJVGbU+fqpmwNse9SF+WkPtV7uuuRQesgmFAsHtNdJyXYkPwm01WQQ" ..
	"hE2fazKaX8rtnwROZA3S+FoBmVXNjmM+l7/f6BpaVz4k/jnZWb1/lPOZZozVpxbw10vZfpPivLKO63P3vtWnGlrJiwAYmY/8VukL" ..
	"WT2Yalv8QGfVmI+TYZ6LsNe0mFgiy7VDIo1NfDw5QRVRYv5uyfkCSbJfVa/iH6FrCP5k6hYq4u47sEACYsGkxH9THZxp+Pji1yWB" ..
	"EQrYlgd7PFZtCiF6TUuGwN7GLr1DQFdnKer+NWFna8azv7CCRk1odbmbXUk4ojXL6qCKET+9oLMNP6Fm8yEgsuYutXxfaqiNoSHm" ..
	"mIdfhBVWiu9DEMezsS7WwEEs2ydkfnBfhRNBvJQpwSabbKOqrgRgu8+LSDoWoFKnvkISx3lYWQv9O0X2cTvMo0iSWTx+MloA3TLM" ..
	"dMv7xg2MQQlayUW7pGfULKsonOu8/nfd5pX91OjgAt+jgdtseP49qpUtTFWaqLxeLUSfNfpr4w/YYn7ougA84EC/HLlN+Wp+xS1c" ..
	"pZ5kLoGjq2YxZrIUKyhxmuNrQSemvXuNacvKvHRBkNewLCzhxpVy2CbYTB4EVud/2vJEXQiO1lvaRYCSdCuln4EXbktd/0z3zr3i" ..
	"/ESk4wijkcbp3pUCP6+6gCiA4MNob629Za5CghjDwTFEcnUinzCN1BGhOFhu0Mxta3ukpAQZImrFK6ynQVlHXOD89I73DGCk0dSg" ..
	"eahS2E0KtzBXIJNkb1Z82jLui33bxM0+3bZevOqVqmGd9/vSeAMpm73pJyAE8+x+DRWHouZFAE0Y24G2RwaeK78BjB34ztV7Yd5G" ..
	"LDgcwLVWZqe6kPXapdui6oig4TS7Pje4E1Ot46BZTf2petAOyAkmXf+t5eNKiInbwTMR+2IhM88HmmoV1lzTX3cUGWu4k402APHy" ..
	"w0XV9NMYcVE02CqPZQgcgq8dyAVK/P9wP/Dmmko/k//9rBvIz3s6/+T06yajCwYJlif2tJOQiPN4Jmf4P3SiZneQ+0GdE5/rFrWs" ..
	"VW4xeuILAw9y8SyWJRPqAV/sewTjBRjC9AzNSCDN11Y9uxaBgSobSq9bw1IJMm0Ce5sy35/HtDZxOuXhZ+UuEF0rDpa4IllgOthu" ..
	"KEyZg3rDRfoH/MTGXWY6i02PkTWTg8Agd51+nU6D6nc37k7EvvqG5pxjlDEgJGX83pk1y97GJ8jtKeh0mgrdHnBC7lVmJIBLkjJb" ..
	"jdlMa4+h13jXs27k+6EO2KhVRxqij/bmVHKpaYF+lNA8cJAknyOsRas2Oz+LHra7YWI9w7m7kkiE8fYGDR7ktnWjBa1QmgWFuROc" ..
	"hjTS1yuRKsZONEDUQ4RAIeQyl8WWa2tReKLmSTyB4fgewKWcMBK/tKwWe6gRGwfAqvHJzj/WcEPhA8u9/XyBbCqriudbcwrf/foO" ..
	"hggTNbenfHB+J8a32CFlUrr/FTBDynjT84aCQDCrlaDe6oiLBnJJtYaDzjAaqoI8quiE/qOi3WicKucDFzKTnlfAZWSDIG3w6ekF" ..
	"mDAVeJRhQMudrnic11oyh873Bl2eibFdoJNcRqDoWJprVeGNWJsnTuMavQOnfj86dVge43p6FfnLAvpiXKgoWosgcSU59TVXIwca" ..
	"gGYo+tqGMpll70xJxWgI272DTMrStnMWnxcPjwfLvPv6PJ2wF3pkztk8oSanXxcZ68K3ZGPgCrv2AAwIO0hr/SKNMM78X1Fn+448" ..
	"Cpl6AIzgqI2H3bwfdyLO4yiVfIDpj+4pkeoYKd2TdEJUBEhTrpkTT4z4IJ8T1ma+B+WQMrxh7KhIP7FleLvNLKtzVWPHECmyfLEA" ..
	"8KYkRI/yyWZ1ynvsEKPKff8saN6tqbLzGG7dPTAI4T/XXdvxDUDk2FcY5NBiL2zuvSB/ekMgR4ztKeXL/MYHxZdLc4i2MkN5x/vf" ..
	"P4guPTovFKLcqSgT1HNUVe0wc3fR1AoSIIKZIN7IJ1/XqRYlC9DuE4pQBDpJ/KNMFRFIL2SCqp/5KPWAG7TFai7RP3PvJmAgpxBu" ..
	"mxmRTxs7nR3WgIgwOfDucUbpufrgCh4NMS6SF5D/H/hgCd1HZ3Kp+C+u6kB/1Xp/drDluPld7h30gq2zqUDnNiEvyVLxJT4lKOT3" ..
	"dQG37wObU1XESof3QOG6dKoBELAoUZ3UbGS1bs0USNJXd+vd4K501meRjgF+Ky/fqYxNO2PfHEvjKFnG33GwfSvzPNZrcR1yzBBF" ..
	"9xUPp2JocVfqFeXYRyyYCrvSrHPx1haQw3fpvqei/x81vpjxvwlbDjdkx8bmzgIMcjNHYJIkZYzanYxPgG8RDtOgIel4PR2gSgcH" ..
	"LlkJW0rpboVqIB9lA/JzuAY02u9sH3yAnCFRekpKognIL0Git0bnlabFhVaOL7I9kPzX4u5rxrD5tw0xf85PykWLr6kXu1DlyeHe" ..
	"ucydFeM6UXPSdcwncleRwg8i3YCrcDTBKKTxgZc/5BA0S4SccU0aZ/CYD4V54G8FZGWHpU+8bAcu9Ru3AfgDb0O21XH0qelzF3Uf" ..
	"+f6VmvDQPnmnLG6SzLcR2Hj9nETZat9pZiJ1DkNjb1rrujopCXOfBOkiNWZdP5vQa5gN17UafacwPjeXmnKpoNczo5EwRPouLb8E" ..
	"gwVB9kQsmmx9q7fyCttkxIsIG0BKSOhYBTwS1GwZPP7srZLg4aIVF1j2pDHX0uYffzhRATvjBK6QZ0EM4oqwViNBel1NSVoEExOs" ..
	"oJ6bCjyIFGiPP6HB8cu2qHuq9+i/QmaR9kyXh0Ge4y+FV5AwhUmXqhv+rBk+JTi4XT89wcn4I1hOoGWct+zcGrN3VtuwvUKESD7y" ..
	"KcGVjOrCRBZ+yf3F9/NPQCaHH/CZmtzr8sQJUO1LyHvpZxWxmx4bH72bJ/cCc7AlgrQd8isyb4E3fixqsKmM2cQte023M4kjKeFz" ..
	"5QLSEyZBdcgjbo0ttpiNNvmkmadVmv2plBnahGkJwWb9PI5M4BWkMShYLdTFAzJJqv7O8/Krh9b68ryjP23RYh7xinsC8PHdMmwY" ..
	"1BcEy/rBtW1K2DSoxchqcZ6tK4FOJf7s+bHBHx0FGN3mmGTsp2dWY/4X3HiuM7P+jZz+vfF1ntwqL7vxzpyeXJNn/P5hSzfauD6N" ..
	"of/mTmWyPtbGvw4ks22NgJ8PArJuPhmL2gFmVSjWn3aJqvJRtdBqqQoGzN23TfkAfpbKkbNE/sc+dS3FRHp3gR8Q0AvuIbVXAUOZ" ..
	"+saCpy8gdqqlLBXqvdKaJDqDr9znby7Cwb7emIlKIHw/5dvuQXL7+3dPlQ7fQqhVQlLKs2a+ghUKDTvARa4BpIXEZJ2erXIhXqOq" ..
	"yGYWZjhl7exVYDeqSh/+csVfvfB9Ugyh0aVOO9am8bRq0oSoTunJQB5mSbK2GQCTOM1h4Jnps83TIpxn2wxt7TY3PWLuORTxt3ok" ..
	"/mLb+RSkKWEon6XzIjsYkEZEHn67U95ArFJYOXcF4iRBQ3GeprKyYfAf5pnYMQuAmHK9HIdPDUp9Z4y1i8QpoifiG3PKLSNAhUce" ..
	"RfwslV5RunJNAfF4v5H5r6+kQM/2RENPEdt6dYp/GL4t9SYvZRkkRKGnAzAcDP0cXBGa5TvpYEIQH9izJTI6uZhu74uglcmgYnuO" ..
	"rVuMyfC5XUJOU6MDldDe1/pmW/XTpreTH+ncZ3LJfYQ/19Q6K02zGbCqnY9xZNz6HYFo/j7CF1ukuLE5B3GXzckLe5OsSEnDF3wI" ..
	"NEpaSIi0JZNZJcgIYwuWGmPBdbIrvcqCSNM6VKR9UHUe/jjaRL060QwLNZUevlU0wUVFohKxyf+/yZGtwEWUUWFtmRV43Zm6TIxJ" ..
	"LFoCG9D9ucuDjiUbo5XsrfLxdngsdEaWgkhkSDcFX1IDdIy51qXxq2/cDyy9TB+lsDmj/qPonX7pwInEg04WfrmfV4mH+aAmNvgx" ..
	"xm27rvJZdRlLuLamrM5t+RO/JbANrhbNA7XJbeowIh1rZzb7LRlbj5CnBOKPlNngP1Vgn/WJ/aSu252rV3NekhFHrAqSw3B1ZNNM" ..
	"LqV05NjnxsUs4AAtoZVN/omaZOKBUh2h1hiEMaEnKiI+1QLDM8hxGR+Hvl+1K8Iu4HF+asMjejDM/COMVAt6iH6Yh1JV195NHjb0" ..
	"r2kytNkAZYvWc4IBHJoMxrU11O6BIQZNv+BjeTdD6pG97nF89G43jj97hri5RQsnD9ZIrnsItFqALY0bnIUCyLmPB2yq96HTt2ca" ..
	"3gEDne7+mJIoFWEyLreheu3ZNiWTCfpA+AmepghOh3mIAC24D2a3w6J1dOFu5DQxBNgJ50kKJQt1e1thsn+XOD4yCFAzedHa7mbu" ..
	"fqFp6ZiQQlLsp58IZsryBeD/sj7YWZyKW4rqPdELkJLHWGPIio8oTUFtWj2UbvgEciXIXznRxA4xStXngGAGMF+0KPR0ECufqAsl" ..
	"UVEmK4rWbY4xDuMNojttYjCKYUOWgAl/Xu3v0Sj5INLgN+ZAPQgDo+/L/KmVW/gA+uyvYukzfY/Vurt4R5KFoAzJzY+Co3GHndmn" ..
	""
local PAYLOAD_P3 =
	"VdRiGtybXbnqkMWJ9N3KJZLhFyLvSGdBwsHfFj9suAlRxNXrsd7OefoGrRUNFa5BZ8YxptFkW2X48C4B0H4vLqY29liQNEe8mQyO" ..
	"hck0plW5FhHhIEwnrdFost4raZVy8idqnclnsuCo7HZUp1l4inc9iJ0dGkQoP/OfnaTax693aGV0BpUr1Ap+8E/858WmI+Bf02Vr" ..
	"v2G8sYZIk+r7X1KyrU5Rz/rpx1LrK//puX5ctMS30+gODwNX25vSV4gjmIw9iOnzNUZ9zp06YcI+HfxBmsqgndpE+TKvieLrTAQD" ..
	"T/vsJB/EaIv14FrhJ9mPO3PqhVn781b7u9McoqUTbIYDzL7BIpM4vrVkr1CHf3POMyGY4Sl3HqagwmX51ULyp4VMYNkU71be2pI3" ..
	"2Soy1/GYpIsXxhSeOJkrgOzXpiQloGUBv5+czLx9JtCH1kdrR7SwltTHA+KCbhiuunAV4yI3s7rTdaA78pXHr9kAX6t8kgMrV1+6" ..
	"lnsBGgtKWlazeudMcHvUcq0XuyPDmZjfR3AHhsTsVTW/KhHbo09+qtHdtwLtfJf7VQthGjZbvqUc+9iOMpRGfWkGzMzemFO1SHlm" ..
	"nmTIkJpnOeDiDUi2V65WTfclN1Sde9h2XTt2/4esLH8Nbnn82vJ7Er2DOgcUHxbz3IBcI1zSAjb3lQjO39ZWOjysYcJvn9IqV0ti" ..
	"fE/OMyPPf269fXFnp14QIEQ1F4opPJr3Ca33Kju5WN+6aPabGwo95HPwad6o0SwAjU7rR6cDAG72q8cU89EOX13J4LJflmzHKJ0b" ..
	"I7IZfL36pW1bdqRnLgT7a0iUTYVMa6SVancr/5ffroFFB9qIeWG7aHNJ1hyBrjLyJpOHiPqBEwCVEKYGOl4WyT8HPPvJXutvlplM" ..
	"Lza94UrKv0r9IYCoaQ4p302sfPSjbC53vrZ8xSMEWKvZKgIpKjF9nG27YhOZNPjlfZd9layj6p5g0eGx73+3pk0BVpW5iAa3dsJU" ..
	"j3JidbWt7N85R79pKAk6zp09U6XojalJi5nLds3/LxUbI9o7yIT+FbT6m4DiBQwpHuUKUUhCL14qV4s9Z9Lg9LbPVrttmdOdLQQM" ..
	"s5kTnMHt80hrcHphBheE3qUAoR7Gu125msW9cO4jFNq7EGdyKY4KdZw08FnMlVINDuJgDAXJhit6PcmxnS/p1cGkaDs81C82AR+s" ..
	"dmNoCQyzzEODEGrMsMRQPQ+oD2WAm8HkAML8InJi6BAxu9g8wOvus1zgIw72ph2WwLazoc5Hzt++5JCkSiRvg8kfshhxE6M6b6dh" ..
	"XCjuyBeem/9Zv4jFa2KU0uy4p1HCCe9+U9ukFl5ScCSX0XwTAemOl70umilvpRj6v/hfDBhCqYbDwdKFS3CHrWskwgQHRKFP3QSr" ..
	"5jgA0mZfNI4lVqu6mOm8W4dCN0kQKlsAkPl9XthfT31Fk32qLh+UY4pA4JQjhXHdBkwBgPUQZik/g/51yCnCJDDfHQlr/8gmDna8" ..
	"I6Tw0JYU4rYVKe+7fy2fikChTxn4W33qxCjpCU8WUyf2h9GBVhRRjTQgFvna9uFo3nuVtKtxZ31mPZGdqB42T/9YlPgnHAcpWLWU" ..
	"rpHkZX6ZRNPJaF4XbAsdMMnHL+8UvIVC6x3GqVcurs0cAwwQ6vKvUqvg9/oVJLK8Nxeslfk5kZMkCNVOcyZGTXb9+qlKTmgJc6qZ" ..
	"weBczqVjN7KqxdN+9MDTvSqlNigH8eMaIOoNJfWM7NZ0SlpeXoEMbabiFCq9iisyy8zfZkdxWOMY/FY99JAD1argvXDzYZU7Mk0o" ..
	"T6VrO5rw16cF5G6UFEZz6+1qGvdg8nJPvJpRBhROJTujaUjd7s+blPHXZbBdNlkn4b7ux1riWxCwEI2OTR9FIPaCLyXuET7VllYG" ..
	"a1GC1fRcDRvlBx5QBwGn41XJXeh/1xYDgzmdT0qc7qPP77oQXHLf4ZE0f785R6r2JgfehLsLSSI53ZNoz/wZxqqXQHUREibnKJfO" ..
	"W4Fi6E+wtimtkJqlvqEu6VX83oQZ33nGRQioCZW08oPWHgPhV4B9KnMjMFNVJksqYswp0VK6wQnhx5wNzpWcrYoSA7vwLlg/Q91e" ..
	"R+enDtMaAhOteMdZyHflWVWwNjsaPCq59yqg/V3TCr1jNEsyey+m55HZmnSwZghHgMJykWZa2K/AYL7uwERBdBvfQ4vbLpNJDGIe" ..
	"uDPQY/wfSBW8JVSYGPwx9GsO+pkdQLGBETNanG3QZTnWrSPH9XAxSjFHYgO+XrJYTezj2MoeMzei/69EMtXDHU+oEiecwAuHtomX" ..
	"9/0ZBeC3I2qGty0W2b2Ix6ulgaEURfu6Tczorg6/1sg17K9C49VjZvF6+jQOAkZcmJ/nz9jFBeDnlRuCiHMBcrGpd1toUEg8W8n1" ..
	"l927gTfXl6paKBt+Cv0YBQipDcLD/i6SsHCFBAfrm2EjskZj9Q8R7T62I/v4VyQoimpxH7fLcMM9WO+gMdl1qBwWu1af0+1/wYRv" ..
	"OLqU0+nfPpW1BjA4WHHc89N9ZbrAgA73TBFqwt+/Ha5jffskEaG2vyOMVSI2xLJZGK8ANeXU0Y5akf00eC+YVyUwRC3/3GNeEGMP" ..
	"maH0+p3I6ALj46RleC/Tcm3TExWTJpYRXfpIk7Etb8oVetbzN/1SE/r7o8gSnXRNJ9GJ7ySYdtlfs6VmyF8Y6MswmBaWDms8yUgN" ..
	"C+B2hAcUtyptS+7uD8dzLskyOyvVmQuvbbcvRvN/ikoiw5t5zHGYwpbqq8uNo7vdUHsNAHJcmfDGovt3tqAxsTTjyJfMkrOMWelO" ..
	"ZN1/DfBxRb59bN6oJyXC8rxxcuTTiiyGRJ4onSAuOwiwDwL+ZRBymlD3nl6o+5t5no8r2V4shLSKWVvVmNla993o5KJFymXPzyMe" ..
	"kU26mUfiy+vTOzHlHOSGXaNZ83vy/yTdjwGDicHEELt73dQZuPazE/baJ3XhMNqLA5LgQc+hGIjrbTKcIOOBScKe11S4DKAR+97T" ..
	"JLJntsBpX+klFRnWCtniHXoa53uDr2EQOU9WTEvgrnymAPdYQSnsOFLFCVkusJUubpPQZyN7CBwjm0njM3hCLCmIJOKrIEmy6T31" ..
	"L6CJ8WETprc1TqfTGeDDsgrbXW3hRk5m30ToySPml3oZkxmmVK4+qorJ6dLHdaBuSMNWfE6LMa/LTBFCe8G0/OkE6ZLmNfHkzih+" ..
	"R5E1zf6ykZBH0xNPQruek3ORR+oKNI6vRpW9Ez7IpVoCmTsU/35yDjzQ64kTSWCDyF3sScEBEUYTv0MwrwdpjGBkgK5gvurDcAq0" ..
	"5Ufd/8dJ/SLXDno9Lq6LF97KyuulXayGfT9ejqDeu72B/6vDfcS4pOSYkuUuEn3wwQLvUcbr93yhe3P+YUpKFnqwSaVWwZmwHqy+" ..
	"0qQmJxs0k1Us0aKigmS/HIgtkazjElm4NIqne+gG5l9aTOokstibF2xr1w50Qh0kR2wm0PNBNm7R1vwVPB1LL5H5523vMNKZsz2v" ..
	"7nN6OyueOVsynFwkA579ssr8mJlLgnoWOlZzyDfL4Fi27XKZ3m/BrzeDZ/K4qBijrdEaJ/402CMhC3XsgEUjTSNP+36O0PELG3TH" ..
	"f1r01bCzo1nZIhKrgu495rD+6i5EtNRUSNqoBqUogsXFqvpEWNVT5gSR60o3TK9VFhOdS/vxkATucFRwpk+HnlWzTDi43pmrhuXN" ..
	"CuHS6PVECuXfeHutPLrcMFg4tnn4a9uJniNTkPOy3BOajl9YWmIzQeDiw2RkxdCUty6hr0d9Ni1oRvPDL8lEe8cArDseidbSFGMp" ..
	"TgLXJ6k9vOdIHfUaqn71eRnaS98l+r0rSUc6UYgIsnJKd+AP/O62jB4vFKmjnDs85QQrihhLLw2Qe1y+BBgvis7wjfTtvPaahRWW" ..
	"59fU53rw9/psN56W7V3BjlphUfYKdp4ixU36SMiiAwz5QB5Pd7SUpZK+1vwiLwFWHG/JYozlZiUUF9lnW1tbKSyhQWLUaTqhdc/4" ..
	"uS6jCbl7PX6jF8qs+VkyvBRyEPtSWP/tD8zTW+Py7JTnBEzWagHSAIFukVMYU27YpGf7qtnl53nJR8aKb3qtasg/Qmhw4qwVTQEM" ..
	"SiuJCtgWLlygSjw2/ha+MKrYMk39dk1GzncXwjl3d5bnVvJfQdFqtTldXmEYB/3eEOXN3Dsdl1kLadmn7wbUVyr0b6nbj734eHI5" ..
	"YpRiEp5uW3ftrFvVyZknD4erQ3HNB1ItN/sMkvg5osuwucYy7rYDjMNPN2xwdQWscG0favepaKCw0KACBLpyRGyeixyWFcSNk4XU" ..
	"Jiha7oww5JTuPr/jF3FNnXq/ehigQVYznn5/N9Qw9HdoJxAygeImoqctP8+NMXZyiO0353lFWQabF8fUxXj2giqK6uG+xhBrmNCn" ..
	"SGGAiEtylx/UE/iBfm4II4id25Chu+JahF8NVNSs+K4k0umzJZlSs6HyZNw+rPmdcL4lw19wc7vsl9jSODUDwcpFKp28KxISnhm1" ..
	"Ugz2+9IatoBSqu4CNugZ43WwjOCNlYgYDSV+u74X0ExAEnvS87PaWSMt2ANxYa/8hx2yBjF5Nk0Mb+vIQ0UcpNCO93DXkOuofIRr" ..
	"LKADIkA85yhClwKcufAQ9q4Tx12N/KUULGwdDjvUbZS7UNaHGvAhZ+rk1juRIGePZNbAZ5PfIVyYqiXuUANSGd+f2yjQbIIOPItm" ..
	"ZhUEM8sC+MnQZp55wSlmk+61cbyJbZJVZ6HyTbN3393z1xaywesaBb29m8UpBvv0KwGRg59PcBL57I4RKqIiz908sENDROao1R9V" ..
	"i5BCI97yhsIeqeo+HJe1NNK0a2M+2giGQE0YfOrFrvQc5ypmmumm2v3LJsH5gWiaT3dceLnIN2Gd5/YehkDskT1qCHqwyDJVCRFc" ..
	"Yf/1sIdeRopSnXOxFWWWLpm+ZtDAUH8ZfvHN/IG+36D7nlEDi0RHWbtiVimc8eCCKPVCDXZ3DQkve/aP8Yo2yEhEDgNPEQgyjb0p" ..
	"0cEaMAbe1MMmC6uK2MQso3RXfBizCV3UXdSpr+jn7Ltb+crgHmoUF3/OzFepw0QHEcqlZgzKY8YobuczhIy3NW5WJPGxZC9fi/1I" ..
	"+1OUI5f7zey62HWMqhDflLloxU3tSDotkaPyEwYak1fZjOzhaua7xQdyA22XhNaW+CiXu9JuEQoqqxE32ZJqvwZsulDUwrTQx7gw" ..
	"bdGoxY36XFmngj6p21MQDlPqkeZkmti1fIMoVFljz9C0NnPFgXmUHPaoimhEnEq13d//5LYZ5e7I+4D7ti4uHtvu5090a4uvxy4a" ..
	"RxpJqZ9vuHPVZAYMNRwvyjymlTOkmGL1gBBQMJbKViHaq5ppJZ+CalcStdgYZIkuBAy1IWkqKpR9LJpcCCjB7OPSRFRtuqSy5rde" ..
	"lFwsi5hQanCmOLUb/R/CvT5QE2be6JXrgnjRGW3uWcqVwIvISDOlcjzDPpzf9Zkawvi4kvVkA4jJRgQbAdlPNHiTxXfcRafkPe5p" ..
	"TEYlfoUytmljGz3mMdsOUxGMG2zVRkmVdvw0jCSsC5Tw7wuRFSCl0t/aUpbUw+J9FyUe9Y5ixHPYeDsT91tNaQiXoF1mdyDuLYy+" ..
	"ii4Z74eVgJODKYks5SG1GCYOWkH+4Xawu1W1GlxlbO7HWy0ugkqAExa15HPJKtVuYBROAjP2M37eeoWHGulgZ65Unl4tyUZVAv1x" ..
	"sDbEDIp2WDNWtoqfiXT6NB7xp0iJsEhR4+oBi56g4Dy9e5vuJ9pzulHcrjyFrNGxusXjsYPymCG4o6A+qmf6drSE/clAPvyDcayB" ..
	"lYFT1V/FZJWsgbkxKdbhwn4FiyaXBRBfqQy7qTJnitsUMAXOIcr1zReQqxzsKhU9S8CXorj9zoXJGG1Lq/NPWvrFNg32WEbt52/W" ..
	"+xHjYTWxLUpdLZiRMgzBKZH4hBH5bWGSbgim9HNkvYzIZEV5s2EJ2vmw9qtxPaumRiWWwIWkqUquAOcFOzEnWAsXT02TktX4ZYu+" ..
	""
local PAYLOAD_P4 =
	"0+1XTkucNB7TTlbOKvdVX5lSOPjerqAaItXsUYZTTcBIfs6llIIg2/ZtikrIW6WU6tMWvCb8zim+oDnG6ZqLdN15whuOKslXzZx7" ..
	"PSH7wG4X7kAt1VY/Aa/IpJoJRIlIR4zIjpGaj7jy0S7fzNA+Ht6apD3YXHk1VUIGVInmnU/FRiOxqE3AkKQD11uudxdeeEgnEowG" ..
	"mdfucJUBACJqzK+EDejf2WPeFZKZ4B0YG2C+NdARL3VHxwgE8DJazcIBNES0vPZMG4bNwGoBw+nF8x7gNyF7C/NaKTAXAwVt+K23" ..
	"T856Zee1/Vy9bFjIeKQVntNjBuemsNSSpBYLSm4SuzgVf327QIlDHJcnBCYDFT0rJykOM4aqB+pJo+bZtflrQsTARbOG/ri0SAuq" ..
	"NYpJVDejBa6faKxQAtRh1Rw0aVzC47xT1cANcsNRWSpTbAsrFlm2zkQJyavHplz7APfkHIp1g2/bAx0cQ14VFrgcZW/9PJsEBapf" ..
	"Q4nqd1hddokmzt7BPpV+NVr2/Fvscl+tt0b9lYrYqEow6441zuqjbH6CD9tQUFoAvOWRZbyC5XdQI5eMDkXG7DcO42xaqfXWLM4+" ..
	"MwrWxqcyDZ8v/3SKrJ7yzbuLOscKW+YSVSoxJFGo44C62TmGKk5CGQlUxTcHiDJrJVmvAGzG9Pc976PlcIfD+t/arMPxf5ZaRU0i" ..
	"IusD8UEpGemIuFrdwyPPhPp5R6fBY4unfBCXzU8zwprg7o0itJgpyyAEkCj6fZUVd68THM7QOJmqbA1Mq/b73rGEwXm7kqVSq9dM" ..
	"z75K9XQiRB27lViF8ucETZ+UvWgVYVqJa4tvdFbcb5ck4vRkQq3cheA8TuKIZpnFcz3ehxDk1u7rYf8+vaqDd1Ki1wZwZ9F1jh/D" ..
	"sd5hCqxhNyJ19eGWmqfXpm+bssYzfHjpPGb86FSzu2r1ohrgPbWxlX0n8EUqJQQcW9BB43tNo3OjCP68sCMW4CSo7xpX0lQ4s2AR" ..
	"dnjPRaC4hVY7YnWeJ9lCN5CswG0gIlz46putskw/u6u+L9xxd2tTa5onI/URFUlzyHQy5rrotxmxqVcdhi2Bsm+HHwzaIjQkPKjb" ..
	"LWV0I+vLOrubRfV9QMKGOk4KtwBwo6fJVNSZHRA52TGS3HIiJS4jIVQp+nRq/WgTeo6vN6Lvbvhf+IaQtRcUfL+QN8ovWQ0caPIR" ..
	"MC7pdXzCxYrpOV87sf8elLRkJ5Dn5Xh+EZ8cTYB6l1O/VSLDX0sxatex2/EZnjGNNkhaW0JMofG8oKwKzJyfNIKPXeRuAJ8CpQR4" ..
	"uskiU7rOnfP5q2Qv/DdtuAOYupkVhAHRDeqgasBgpaFTRvZ0aPHIt2Xk7lEKnEwT97RUo0RnM/BhbrYCn7tQRFpay/Y7fOSu4Zui" ..
	"SmFvhK7i4kSNG9Zd7+LVZDzOPhww9MjYoWSYAhTvz5zJds/I/RtwhbY9DUo95Xsqay3b7p1hwiy/lMRGggFaGTa1svW+9Ok4ohBT" ..
	"LhKEIahHYye4kpfEChkD7XOsHzM7Fw6Nd+9I9fs3MpMsHMWFzprhJ4AUqu07VqVbN8dyfp9+qQduSDhjqNQgLBuXC1z/gXUxU06U" ..
	"rXji3Zp9wfc23UlqNng3fyE0C7QS4MiTi15fa/N01k3uGvI6bSVhx9imWbuQHGHmSjAYy0qsRE0K2gxDJ2QUlqg3iP1GyQNa6c1f" ..
	"wpFpHbcnbyTH/mO3Jbp+gblwe8bJnhgucdeXLDhkSOZjQBSJqYOB35LZZ9vznfh1cifVthyF6QIBbyPHe2Q+lUbBxitcw3XMXp/T" ..
	"N2HaaLaW+diaP+sQtOeDl7fGVvSHKhkgPFoMieMrzfdqNimORl6KmclNgI5KWIqxbGEF2s78dgS6NsAdy6BniTUT8iUyUgPgsfdW" ..
	"GgpxRJYW6A2T/WWkt5oHHT572GvWnIraUCeJXdz5tUGOe0CYKc4mk33EwfCpqDWaTtn9s8Fq1WagvAvo090OKPq7+D+M8in+KaC/" ..
	"uDITKJNo/1JJHeCGp1iLce496yYhlgnFf22k5LxrrPuzp6hfuVnr+wOl3pLTsB1jKOHZrj7o/JY3d0ExGJpiDaQjnxSxh0avHGha" ..
	"/TS6bExbPAmOsc3O9Q8N7ajwCZLoLrZ5eFxt6o4dpW+s/8jaUJh8KJGkMFyF3t4hjK826kPCCB8m7OVLecMRkSyfSS92/sK98b9M" ..
	"nOLQ6gC0+Nf6alvKkFuZfXdvO0CLDRNZxcaQPoJpuVB/xQR1KJM618ZjcgRmqWGLD28xVdDIEX7FJ1mcSsQydafy0v6UrLmjw2Gh" ..
	"nvfjE4WkdcDXKghHM1n3h1HZSThAt/TNkkOS+lsyUoTV/FrCimR2DMb39h562EvG78Fz8VGbZcSlPs1JgnRwDnsEJkrRIJpemzmc" ..
	"9m/dQEVn47/nhcuH/85nLe+DIM8mKRkWqMECcSEldQG4EhF+l2oK6KcGvk1n5oy5iIpEpFVHQdVQGehmYx2WO+GAqCjGE8NH21Ft" ..
	"L14O31WgxhYebQViJrn1WwUcO2MhRwIHU+PrzKAk0+hjXB6eQEZ0/+AssfNRwF58CsymCCVuZtLX9rrr/h7L1DzOFpN2xL6Q0obu" ..
	"029ZjmdalFK8lyl3qUSEaJYA6EadIsdDtgDF+vaANTwATCms/vxsTLvhvXrpwqkRm1slSuFB/STzhIUlT5ouHoxcLzY1m+l+JAru" ..
	"1A6NOc1ZC0HS3x55TqwU1pKgQPNEpHiVQnQHasj7fhpTY55KtQz2ednOX4APOXrt5KU5faStrBjG1Dh+axM7ZS73QTD3igeQMb7d" ..
	"REQZR/0x4u7AJoQav5a4LPZT3zVUV4EMHDXDdK/C8zPDx9i8q9rUL1CgyoLsitzxCeD4Url0ljROB+xAheLAF2Uj97/IcN8vFtg5" ..
	"9ajmBieSAj4qw+yEvHxwPvDbCcGaTBzd57FcaCgWq8Km+eJt57Dj7elF+pq9UWAvJyOx1h1i7xN3FiAPSjgpgnETvLCsIzRZD/Xh" ..
	"CqJr7ZOzat/KpEn2rYVRUmHERxYneBuFhk0Hk3ErS6lEiYi23mMUxno2JODAhScdp9FjO/dIex1gdJQ4cEn14m6gS30DxnkMyib4" ..
	"xTcjlLBs1hWKaXRO+IIZhV+prM2BWdBvY3/g6iJr9d/02Dhpxv9EI0YavT4LGroqevX8KcA0NW4QCkablU/g3Q9gfJSJvs4uNjvi" ..
	"FyKvrB2XrIMHPnM8EIxt4SdGb9U0ug3A/2SeBWft0YnW38A6Wj5dy5/iZK0wij4woka4m8xf7ac4urU9Ml+e8c9Gd6bOOLdaFHbd" ..
	"jqfPKpz2f4Dl/J07Sv+HpU5tYrlRq/wwzuv8G8WF0StTfuSAu89AuVdeGT4FRS1eY3FillX+TNiShRkKFBC1nUyEiTZZhgbmJ4ij" ..
	"j5BbXap/E7Ht4fOf4bPFmvrKnxgTCUAqZamM7YgQ81c5kiY6exR0DRsEg+QJ21JuOfLUD1DJGXdJ3yjmq5gczqliRGBlTIGl93EQ" ..
	"hnX2XJM8YQgY1+CoobaDOMdY56D/KHBlh4jXdikT3bqNixLKLEEYvDcR5TqDzoqdlEaNkBl5+L0YEenWmGgTa6w1LM84m9vJKxHQ" ..
	"ssV4pI9jMFwVN8pgh/brzYs+aA97Y5DByaS/XgEfRXGK6TBPgy+//08X1AP07vJFK1KtCnktNraNQip+yD6m424Xj51qluhxL+3C" ..
	"h37SS5WW86D8IbsCyVqV2vh3ITuObkX5wU4Q360SFAj7yKK7yK5Iu2bpQImtktch9m9kFKuO+aEpKYlGRYUvqpAcLoieABpPy9GX" ..
	"mNs02k1RAd791KjyCy8NVqC3288D3UpMhHK0ERVCJQ1loEIAkjOprd1HHe97fMZ5ywBPZ2qNG6KaKHFLuGy345RStN8OSiejNWOy" ..
	"mGqw0kTKnjbxtZzhdgCT+h9/jHKbF44akjmaWKNHbgG73akjQ5P0V+BzpeUi7RnrQ+JcdHH2A28h8WRLAGyDOZJvrmRP5VqMrBqf" ..
	"ve83DO0wL/CaWL+mYoDCpIb1PGZWnfd5i7Du1BJLWimFykpOiVU/nPpQ4f32voUkxn4AxetmQ7yGAeBkjFM5FGsaBFMksLgGx2Kt" ..
	"FwCsSN8vEbzVguEPlB60OdHehVI+dCaeIKGQ6LMhWCMkeKn5ohvBHSoFlw52iqK84+/c2QyEkO7B5Z6cN5/ZSrCF8LlF0SYsQiVU" ..
	"KwcBl9RvieWH5C9afNXQ/DaSFNRA+N5emhGf2xCIBdSAyON5XvFFzP0J4J+5V2jT4iQHLF7mi8wIz0cFUbohXJeClCLXpeTToa9B" ..
	"dstGrd+4Kw4Rqh5TSLAIVbfLCvi0JJY5UyQyOLgPdwodpuq8LjaGAPtR8JmjI5rB8xTGXoI0q8KlGksDzkkXldSms4KNTXk63PWO" ..
	"kfoImI/aaXSvt75uqyroKiCFO910qONDe1NKXnnCrxszSEWj9xHGhZ2QdqMVHCJiwrzBGSed7FvcXsmKU3k4KQXK92UY03+9WzVw" ..
	"3D0SGABWpglK4EYM+QULH5HdFtz+/zZPZas+Vqt/HsbXLuocnPP9lQlkfG/ZwaXtMWLgcPxlLDZ6vR8lh46jyrRYcwJlqXRAXQ8T" ..
	"o2zYWB88JcTr12GdsJjNXIBFY0Gh1+w1rPw1P+frc5khGbSziy/VLGXVxcTMQyn8cdwBpxOxOho5+gPKJw72jG/w88WyqljwLHqg" ..
	"zvw0LYmbdo2V7TitND8ipWxVzX87iydZiAe5MCQiyL2DwtI5XVNW07QPfu5pBAZHRPcYdNq+zXYjATd6sExTL0JW+LBqI1IscFwb" ..
	"UpWKev2m0NdD42UR5HKGQHpJOwaUGXLFUg7K7JnvkppUjYhJeN1YXmjWg1+gNX4DsM7GYBJcwAuiPe14bvKOooGWZV59Nbl2OmNd" ..
	"FB+VANTLw8QJyUsAnvJfPllWAQIBOI8z5Fm/w68tHz8NXm9BBkLh71C5wgONNrOuwT1Nv33w/S1cIvnDgd+ppybSG1kZJALkGb1q" ..
	"knuX86qZffw8B+hcglCKBvghGyCU3GdvDcIm3itmoCQG2zIKWkrzoPwL/4D1xIrdTaQkjlXkQbolMRbNbyyziTJ6MkH7Hkpt3ze4" ..
	"denC7FnpOD7LjR7G3YVgZ892T6Ncr1p7+c0VpcNpED5t/7ON8RbxaNrswYLNL5NYmBEi6YGt9kglA1a0BAYx0m5+MXhHrxEC23tB" ..
	"xX0J+NFtCNsCiPhdhaOFJ3OxSPrfjZcjVkBSe2jrI1rx5Usg5vIHCxZmJr8mh+SeM3MxPJI2XiHa2q6swEmNInz5TEY6ywJ+51jx" ..
	"TmiBHlgYGFCiHkFpkZNFuyBzebYx+9yKWsu1h9uIZVOFPX03RPujvlwUzIYEX15VyPOdT7vYc454S/H2OgAds1VBUNpi6SXacgop" ..
	"i411aUUxZ/1+0wdQBKIlbT53ZYQLJa0cykRNtFVh5hPsDi+sO68MzmwXdwjXKCdwE4Z0tLs2qM5lL/1XaoO3HUQ0/BTdb1DqgyOt" ..
	"zHwHCEor/FLAHK9ly0yoiDUWo6mxiRGKgVrZIU0cRSBnSNoaCSELrxX6/j4PdmA60enh+eEUvZ5S5xG2DvTV9+ePn11l4yrpJRQi" ..
	"1746k8o2Fx8V5+jTCa7yifKi9BYyqyWzziw6LluVV5WEa9zp9wlwHXRZod+BCslKnaqaPLMpAxZHJaybUT6WboJFg+TOAFzGfSdC" ..
	"BgAr8pyKQ1j7rvt3+xbYraZOVV5TLnJSYN0J0me4eFP2uBzagowvjMBfnYyC6oIzYHLxSOo2cOkGMdbcskzVFy/SD/XnH4bIEhJp" ..
	"0z6VTyc0/fW+4XlruBSYMA1zu/Pj0tro/V6FY8EWcccsFLgac8OyFG5DMCym0XbOZAZylvodC38LRkXHhLFW+Rvsgx0F6/iQojeM" ..
	"YeaEIklpYYFugtM2QgqS4a2qWlZPfxdsWvga+6vgAHQn6MhqO2TN+2niUUO/CbiJlkAVSr7Uevzh04jmljFw/4MdvIcucad15x4T" ..
	""
local PAYLOAD_P5 =
	"R7DQi4aMf4gIw4kTyto0xLdm18fzvPvXHiLpincPcWluZP0XMg+u0Gs8DzKOuKX2iRogUJ8dIM5iiINgl4fmEzEwc7eJ+cgeckC0" ..
	"JwDaepZcRnmVBZsB2Vq5TnyFOsbcOXPZ4a4AvGepGhIHrUH9AlAkmvVlEHAatx9BheyrrM8pIt5sHO1+qfgl9Hx8M8RaLOW2PMOr" ..
	"flwpeRCQHzCSGXqgxzgMFIjlHXZpmaCUB2dU3RgJ3K9f8ODz1OE2zDAmjPe7SnhNw8irDGFI9zpqaRSnIn5QmsMHcs47lB1V0Dsl" ..
	"LA/j8Yv/HPrsNu+wYv3XSUyTYgiwEXDbnNYRrA/ZKEPT2Vz4Oa6H4awa81ZwfM72QSsaAY11PPe/wNGPQblnEN7zhkAu9135kw2m" ..
	"uJ47pFVgn2xi8Q3UdlJdSIsXuenQRLlIDxjuto9Q4OxWfdvYw8o+7HpfcyyS+5pdZCcBdCyBPwcICqCM8ZKucggZI+2GonNQg5lX" ..
	"bSJncrBpe15DR+q3cAm//iK6pqk2soKwPng1OdVpLy0YZgy4prrg+PJevJFG1n00bVUAibPaGifnuyPD+5h8hkWwtDShAWTWwHFF" ..
	"VKyucFeM8Yhj34aniZablA+luKqaVvN/diZE9aBKu/I7FV9m2BHmpchkTWL/qUSqTF2ZeG5leNG62U3v4gSGBuj5bUlBuaUemJvO" ..
	"ZgEAbMhmcb08GxXH6jT2dapL556Mg6W6Rp8U54sWoye4vfh3ocIi2U/qcir+OoMICauUW+gPQ/THjwlk6zka5xdDc4vwGNEpiMFB" ..
	"vaRcNcYha9jdwfI8b/GsKjOQUcDCiafLkmL60mWNT3OArO/Ff8F67l9rl6RDs0vjsa3ezoG9qCoqnnZrLfLLpKgXdme6LjVlSGvP" ..
	"OQM1MwB2BNyfVh8J8Dr31nyjRDjdmc0CfApBjsZvOrjhv/mLI+XPtFn00K429wBlIc6eWteuZj/tLNWflp1iJuE0ua/+jiDh7dnb" ..
	"tlnObdNY0GIvgltiqkBwdVlq8+G/ph1IgRAN8HFX7EuTNhQKvpoZr9j6FtkwCyv83pO4gpmhKt76mrOUiew/9leFX9HObBwgIJ4F" ..
	"Yu6Ry+NwBmOnxoIBPL7x6hoD7dubabOFCBgWoZUoFh8u9lFhnes8WRpOAhirOezOcevukkNGGOZMJ/1Z9co//5x1p3xuhx0kfUw8" ..
	"c0al1BTa7Z0hMgvzI7E4b8mpmiKiZuMRWXNpV041+Uke2yv62hEBOj0/NA/JKMErP/5KQW/gV7GNX+d7Q3FTNupg7iA0Lo2dLJ7I" ..
	"vR5jSlvVc2adxY98bk4fXIY31+DPSGgt5KyyM092f9nn+3Q1xxJKCNsVCJLOWR4Z2hez0+x2VQ83teUJPkGYWXr66OFAgWD1uLFG" ..
	"vYZzNSmRb7SuUazLuWMZUTs4l373JtkW5M3OoCJEIg+WHQf++/EnJ4saG4uEmZxGp+jILeJVpLNXaR8dTtM7PKY9keCqf5D1K9se" ..
	"wB9719WDk0xe8q+TeRR6fLR6Jdo9XD/geYdPx4hxDvgd7UfBufhcBVQS1WGhrZv2gZbXNX4gw0tTSIfdRYHmiV1Dzu+nZXLMDk8S" ..
	"qYwrgiaMW8v1pvb94ngx2dVT8p4+loBeq33nAQYEb6EM4CadMwaYDtyI+4puOLDCmVXsJMQ7ZtgI8qxLwfWzSUt8yttNVF5j6BYN" ..
	"iBful/6+UHZvNt3ofsF4jHqLcxRZyHVYV0y2aOaaSNFdrhSWW57bfS98fiPadsbQSitIFJnh02Hv/rkwHmsUVKy0ildlpSX4asws" ..
	"PIjxTrW3ZpqahhGdAZgRFP8NOgcpBL/fZSitMvGI7MZjhFK8pAM4D4FNojZOZ6dMkBrHMtl1rQCIM0kwr8L88KMXA0spTPsWJjbH" ..
	"/XP+7/yrdu26wrTC2x70lYObmkCCY3+7/Uo1TEco5Az/NsZhyTmN1QVRXaQZo+kWDwxzpruIyTpekAjzbeMUX4sGk/IZDq3hsFSN" ..
	"cKm9tEExRM6CLww5Qr01YYEQdt3TgWHRTbfYYQ2lUnKLPoU9vYyKcZzKbrsRd+mGr4B55he8lCXbp5il7eCJaXueYM4CCOtetRtI" ..
	"mRFl3awWc99plzhMCK18OgR6mKlKigqdRw97KvWagoy/TcG1dmx6ep5b8LMmtMM2Qr+ZRleck1cdgDjo6Tt7WrZcAtkEcpJKqZVm" ..
	"nQfFId+uCdF7VALNzUhf8pSyO3cB1CnJvnADsVB7jM5xOQzCSAlQp9zwiCHo1KCTS0JsPR9b3JaE68j7OHGOeN0QnkYnLrTtlraY" ..
	"Eag9Hqhe+ODjE7q8/atnCpQVvOV7MvHtcPZw8599Ejj35nl+fKPdlRJIGTO8+nQ/1x6vx96DRrvATpfHe39oewzRiBo2d07bxKxo" ..
	"FG24fmWt6vSID8y1+4ZLC6Yp4Csdqt1Ym4tgb+kQGbbbAni5gNPtUS7sb9TdgGvVzgb991HelDAuk+Yae66gHMYz4Cz3CzkjMXHQ" ..
	"Ja8ex7dlIrlOkjKkII+Cn9wTsvGym7fuU8ue54oYhJCOn8xROexfKN8u/E+xGV/dz/MqC16AIxfzyBUfnk755xzX92VXotHfVgW7" ..
	"geayJUqnkb79RZ80lJU3qJA3cBPYwJDwKqBc7I1pwFLAHMHDUrdMXSbmcKHKjFh8+pQ3H8G3nSD893S0+vuRxcJQ2WXbQx4aP3lB" ..
	"ipwWKabciylWw3W6V1meQOsqTQEfQwolPbZe5rjJtYtwdRPQNSW1u9ZxLJNeNqHzf64kCSDoYv2+KZi2BEHnMtCrkNSk1qrCWjS+" ..
	"oDmrRPUenaw8CCqcbyaHBzzXT78zkgkpRgJumKRxDR8D5poow4+HWDYDj5P5wVtzUdekuJrdieIz3chV0MkzWA2sDMvvEttXnM7D" ..
	"mmyAbZmie5Xm0JqA+TLUwLhooXp348NXt669M7ap9h5pi2gCjtkTV45eyhiESUqp2o7CX3SPGuXoHTpyVV3G6wsZllBDybi6zq+g" ..
	"wMWC8fmuS9WZE5jsB87B4voS0G8HojDfOVsN2T+v5bZVTbAFHz8GAolnOibQJY00JhS15RW1TkPsuCfjNaL3uDP7jGGdfEL8wqqo" ..
	"W09JspUHs1DO9F8AL0rADpLmbA0MQzzPjG8hMyZJZqIj8Gy1hJ7AcAOdrzBNCZtDaN9QEAXxoZbS1+aDCSZXOoVQMubNj7E6nNN+" ..
	"bmWzFO3hD/qMEMfJOAaFsQwl6E5ruBXC+qzD5DvkrVdV0YRsvPfkcdwzcJGDdtZ9QmGq8n4hEpoINNLRIFDy6RLttO8gKPxM+40C" ..
	"FdUJeFOvdsqgB1fzwb10lbhK/s3YGolm3Zr1H/IZReopCx+sDR48dI3qEils6lCPuJ+jefOcly6ELjcbne203RdKb0K03n5388gm" ..
	"WNqPWUlMfFUugsDdsMlaXzG3ADvP9Or2nRnG2ONdebILt4tYc27J1A88gFFPtjgKXDDV3MP+1J4iniwhWiM01YATPPUZxMizqhYO" ..
	"XHWz9O30Uh5MJ7/G0oAIJAri6isJg+Kag/Gn/7khzRzXOnVhuvbcNpWeQf7AEYnoyKT2VeD7ij1r6TbTs3WE7fonk4fjF8QqqSpn" ..
	"N+uBkNhr4gJB98SUKQT64DZITmxYozcHUduB9d8aP7GSEJDELydZiZqGiAen7BaqHOMCh0m2TqzvRxVLaQ8LgQeWdJA0lZ5mlips" ..
	"S1ZONN9iSoOqeRXgIbcWlCB/AZ/7Yq+LNS3AY+DT1Dbxtx+3mgVWpXUGCpOymfDfoYjy6/wyjvc4knKWisFHiOc0+tr/sQ6vdRWy" ..
	"OUpOmABoGc6zNMG3+yFVnHuAIRvp71LW37BbuuGFRVIArGqW0r0KUp5LM3aW0m/Xu8ciJKnfCPtoAbafBCpJVn7CDx9qEpmFpFNg" ..
	"rtaMm5lzPBs327Pu3F9O40B9zRcOn3A61wYHg5kyJta5puwopEXpKFoEvhvNXu23IdG1vBy4L1mWlSfoHAk1wzBncJyERfohbi1j" ..
	"mbmO/cEE7jdSOKPFx95scEHE2OknytjB8B3kXe1YaBxKd4ER3nsgAJXPc10YleEJuaPf9Ast+PWzQNa9Xxt8vP9cgzauBVNMywfy" ..
	"gRhoimedNSp99RANXHqHRtsL5U9OkpyHUNGe9oYroBBkb1+wjMbBAIMfni7y5jdC0GCPT/nJxOdNAgN2wrnJrvUwPufmVYec+PgW" ..
	"Gp82rEE4PBK4oxzI797pHScP26S1e1nYqyzdRmd8xUvmALSww9aY9FIowaP2+kdd9SBDP71k6J4xAk/AR558a4G6GeC/h5LjH5he" ..
	"OMaiLNgkAiyMxUfe8UyGT/+uyDcLVjIGEgVXxDcVW+Nx0q4JEQJdKCq7k/ToE3gEGuacGzuaAFeAoL+ZSi/+9ztgAW+cH17wLFQu" ..
	"I5Po/jBYOYi8EMCPsaEWIol3pp/2OY9OYULFpALPYzTBerm/v95jMbw0v49LP+u9VDp625TZYV1v5PfOfKWXqxLxG6uWhTxRNdCU" ..
	"n8XmKo/cuOH+R4ZgU54prM+dF6TRDuqU8p/hEPYiMBshGXmjXXbASMHaNtiudQL4apy33loghnfNSsSXOou4bDZzt5UfgjVFQAqQ" ..
	"1Ajmnxv7p+fBwBxpI5Gek8x/mlN0/eMZjkgDnSR+6IjnW7FYtxXCjGQHp+9KqGm/SduVO+zFJXyvFg6YHaGymJEg7uIInAekiXQo" ..
	"y+ZUe26KP6kz2H7OS4dU5IBwF+UTrrVyL8I742Ie2VOo5crMn7FfxtxXz1TLYRhT5tewEPNOdMOebCBhuNjzDitGGbCMQWZT9DBg" ..
	"ygoi24RFJQHPKFRxPqTe/Oho+BbgrGj4Yjpmrno6swswo/jj/v7gDXvo01jRvEC+tXH+7gklY2TxCrn0d1ZA4OxbjM0gIDaITUxu" ..
	"z0d/Lspxh03AEpvATIx6vA10GTLwnbRflhbdJe2F1fjn+PIURtA7Q81bazekBcVxNZF1lzzr1ro//sPQ8EhxUc0cx97l5C5esgF5" ..
	"oIE6WpdvG46hxY81TiH/8z2gzNKLEfVP+YdCXmuwI2QIN4kQzhIxH2KW1Ht5mHz/eeG0RwKRYIgIYYKTwD72g4gTNpQBPoG/nQ+X" ..
	"4nje1L2H7T0kiRyjeqlAqDRImCM5OymgYczpUpxSTyRlsnh20p77XUMrNRS5zs/HGvPRQJQghhlqS7UFWG1yUmStu8cSgJujQ49A" ..
	"o3Yz7RbKJhngHGXBKfoOqWTL8Idbb+uUVeehuSWBMHXYZzuXO4264yUbSjD4wh4UGKKY1m8ekx9meMGUm2UH8f92+oAQJgQ95308" ..
	"3WdtvqRifSs0TIbdkN/ZjrK2d4z3WYgx4s7Egrs21igQclgOvEbnM/cUcvEiGr9B8RJ6CivKhvNrDHB4XjLXiZDNYdJOSLLNPW+i" ..
	"K+LhKN8QjqCI4jUKh8+n+IwdHlxK3v11xK0hpy30M6PrQrKkDg+pShmSRCAwT3KdbNOC/fKv+UPkkS6c2l1RptUwI107z7FOyk4r" ..
	"C+ZbeWZU+V0KXn3olNxg1hPRz2V1oOl++ti/2VnLlPHKi1w3JpRuri+jPSt2/HTiFNT2UeL8uVtQCpXmKQ5wLNyzaEEpeLsuHrWS" ..
	"CB+trXIdBIdeO4PfbpLW6wvgZudyy/5jlcnRisGR2aLZKfYdJq9lMcZF2DX5v+IvJxMeYqmafo3UPOyn5sBn4o3SfR08Z1SOyUN7" ..
	"LSaYWAP1zErmtp0urplbzVKaXzbqeRKT0JmFFJA+/SfkwvPRYlJNeXdzmSMUkuRVkBZPeWgZaWdDGNaaL3waVOPqdA+aN+iim6vm" ..
	"mIpeZlhVk/3KnGKLmdjCBPAy9iZ96CrXdC9CUCOEHIjOJ4HxuEK8KjUSK+3np0MucYp2y7TzrzgS75fwbf99ED2e24eaXwi+6J5F" ..
	"DRcnbDral69tnfWCK62MbxDVawiHYH968c8TUDERztadobUsNITGuaMkM+QteGn3EyJG9S24kth6NEmU/LFK4jKjqRKtEFyl6SIs" ..
	""
local PAYLOAD_P6 =
	"lHhbjPhUo4oQDZvfTr97KfMSJuCmAqf4qFcXhXUdszL6e0F+JeJw7xcahR5MvozZK0Py+5KPmL+gN1+qhN5fKcNr7h8oyDabB8I/" ..
	"S4+5oRipDCyLe1Gxcqun4l5lNY2QW24MGcTZc5R6AGpYeuAF6v0MWpO2ipLKMSb+Rh0Q5H9W6BUiHha7c+5qoOEW6uZ6G4FOYDSM" ..
	"J4YyzpMNuzyEDWXG0qy7s/vFjWYoEFOoAUHkeXHoisrAUcGydg+2+l85QvGnqeE8wzzOzjRTwnQEyJoYrSydDa/wnRn/ZimKuVS0" ..
	"PlsG0Ye0f9JyINVt6xYsszQgWVRYhKiLk8q6MFcCFiYItOs3+BCrZXhu6RFJkpk+8IIg2+wQ6ZKhvuk2el/cbuVVnZJbfzIHa35j" ..
	"dqBzKuBTc5KHFHPMjLq9+ERZJ6ZwMj1MW1VffXkaJz7bM5SW2vkPez+z63sLBzCceI1sP0Vufx8xPyhZ4vbKOhxMSf9Bu87puKRm" ..
	"RhMysWqRSXug/yrOwAadPe1LmkVz7O4S6n75hIrGCNlFf7L6JlXEuqTXCsqT3xOgiqtNjTqmsS3ngwlUwHPvD3t+OJcthGZT7eNV" ..
	"yrnpXZABsIXHU5JJ5Tv1124fPt0KVy5VkwZkFhmNM6Wv0YsuZt9GeInVytGZnn19VTxU093ZGzigkBPqgrSRA6mrYMkBZhdJkhJK" ..
	"/ZysAnqpep6+br20lHTcudxNVAc/AfGTG/A0iSRnh6qBskxoPPkTDjvXVVKbWvD34ZWVjNI4vfxEIqRk1Okdj/uSlDBgBLcufIjk" ..
	"fjQ7W7rVRKtbEaVaGDZ4M5tW6Xkv4C6KeVWqLGnZfvEvXslTcZ7/K5DmvdsczOgkZ2e9sUpZg0Xjj/3W0YyE6MRvTS26DxSjsw5s" ..
	"C2+g20zybNzw2zzpTVPwhwEKqk35LgldeBmZbHXUjePkkHEtU4Y/Jx/VstSJ6DTqd0UQW0es9VmV6nt8CK3M0IdMvNQHYJf1iYs3" ..
	"R3cVh8l5mWF73uy0rUWGC5ZAjQOQi2Ahzlio2dw4rBEwtgWQ38LQHUiGE6WOZrh9c9d0kH+oqejFzC4m3hmEKDpXPF7vNk35Keqp" ..
	"gpkrnDx7wJ+NRGmz4PBJWPKutOg49Ybt1NIoHqSTKfQozStMPmkgYcHkoSh9d/YVt8SL7LwvOPpmzOHOhZBSFE9lUdmwI6bH3I+M" ..
	"OgLheoVjTniUKQ0nLJHUCypcVtSvEB0kgHylCHowRyyNIg1aH/+Gu+oXf9oTlepGhl2JwV/hbLKXhhPLtZ3Im0avOX+pqEBlrpKs" ..
	"e8X8AEf1d0PefJ/KoJogQxnAigoDtVcXI02YLweQr0qFZ/4KXoGxqHlWjALbDOfn8GGpWHTAtXLCnfj0HMJPF0nfUvoJURdtPBAK" ..
	"6e2FTizjcadbzLF8/OJLt8T6MQsFxvmUzZqRosIuDCGnxTyb1ThYPNvtA/9EQ6uPDxVzzHcaGbdONXd/dDz9jr2CPu3UdHw8/z62" ..
	"OiXHSz7qu395Ue1AAH1wOfcekt36/VI/lhsnOm8Ig03PEORToDBE9DSph6cKZqt0a+3eLWtb6WZOxEgU7XX9tO81AmzCI8Mdnx6n" ..
	"rDZKxZriubVop/5IKMiyTz7klNEa4KWe91JwP+B9ee3MlA5AH0mNIPDxWfFrEee2lsy6RFxoaSuxUMDK3w5x8ySMlad9EHE4pzPu" ..
	"JvoN9i/5Y5SlG9MPiCT4R3XtZy3nHEeKvmrBN0HFn+R1H5qKQdkRHAPNwHmgnOfz/dfsMaQwFnFzIuKdZwfLRU7pTy/XOpBFRX9b" ..
	"G0wjs1V9ZcTg5B/yxcLISXW1tyx+6fEPmKfRyytdu8jca6Vka3V6X/Ic8v1kvVSiwqJ8vrj6/0WSii6i2T445z/vgrrzNn9CIDBw" ..
	"TTZOMfZi0JE+vWoddzvZTlp4JwBwY0O5Kc1LvcY/LsfdvYEq0vFIaPtoLVFPa4d5RBHLu4mlmmXD+aQOCyfi9FdHNeHkBruKiFD/" ..
	"hIxXUrBqxFAZfT+R+ojhEX9nFCSauEvmTFfzflDskAmzzC8KGIUd+UQkDh3KBDLCwUBM2rPbF/pbeBwV4Xceabb83G7tKvF7Dbzh" ..
	"5XHEf1NYsDs5ZtOvVGRWQuBjudsQlUHYOt0qoTxsVUSc1Qy5TX6Qf7ChsYbdKFc+aARH1gOwOX5l0nCAKCY/OtQCLlM99rn37m56" ..
	"pHKy1VwngIhZQaptjBZ7r8O8tFJ9cs60Tz2n9F94JeXJC8B+P7A+6cyoLR9XkSjK/9KrAj4kTprS13GJHRh1ndVc0tnKHtFAlUSv" ..
	"JnKaqyU2H4umXxEs61GGvO0QbX1w8e1ntcO6nS1ORhW6zZLDN/rpSQpme6hV8aqL+HqRi5wn/Syj5vAW59LptsOZC5168jyoCY0u" ..
	"59YDYL8Jg5ZpkF/WfuWbhF3ovB+1bRcNbEDraHIJ3tAl7od66k0pwojTDmDJr7vequo3jG+70PBT8ZR6TOLr7hj5eg+HDmujF0sL" ..
	"Yp9MrXbp6r/S+nNX/gTM0OmtTEO74yuts8ZwMjz78S6wAEAjYTljwVU54Dy7HpA7md3EBK19G6yGsNc6Q19VoYTgaU/3HUXNxgCZ" ..
	"FyT1Gza1H02DA36JQYgKV9at6/lu+JNBEUW8Je6MtaxwK+n+6IYbGqzPbn+bcCrB7bhmYHmdGafSAEC2ZFlyqkHWYvcYuA4DHdsu" ..
	"GtTUE77T099h233USr7HmvSAEiyRkittTaDMM5Mmp1uFXydJNuwNXRQMI1hhDqgpCaPFNQeTjyCOSCYs6OrlSJ6WuuMIEUd1x5ta" ..
	"vQd4nEPVEtQU9KOZn6N7bVWZG7PEWyQ1frFkIIbNLOWnTgqhEJ69Z2qfWXIAnQmwORNYigb4DMT/jdfARWPVQ3Du3+5QGAorWcyA" ..
	"0dtMRPfMIzccOhv0iez+K7b+gCGSa5Vl5V2KFBFu5gPwnkJqKGeP4E0e+8F3ofTdkIe3elNvctnvZxNB99rjzzIHaB+tfBH40/aZ" ..
	"BEEint8qdQpwFlW5lKO0BNwa8HPBpACWP3rE14alc3EOO/l99zzHvltBv2WWW0YGYLcDWeuUGalOIXgy8LcAVirPxxiMVaGtqLOz" ..
	"GJEIMMljZfxJwzj0L8WnWNVBkSLOtbEi2JmuUuBOxywW5Ur0BzebW5OXNSZmxxz43D0iu1LZ5BSuQCPYGtkZsW41vgmQynGlkvUC" ..
	"Vu7XEk4UPqtCWk2LKvuZhjDAw6auF06aftLtSQuylQSetwVc6ZxD4lFOuGIh5uq6L0U18Gy9QhrSLlo6NejGsU1QwKa1ZgDZVgWM" ..
	"gEi7Xp/05TV+tCkRZeNa8Iq67tslr/dSElUPjtt+3snLzlINgYXIfoQI5aDy7ZUgKo5DyHhxpvH0a288K6q6xK2dcOjMIerAVlSq" ..
	"WKRpqdmeFbzmEOshDpZrYCsqIY0Td+CoFcx2j5XFGb7N+KBuHNyA9UVarjNtSO3fK7nAwqbTwDupeK2hqE41SMs7QVu2e2XpV4EG" ..
	"BDxT//7YsHlvrgHToWQlYlXfShx/HEFQClKqPbimTvQIzrzK7ngkI57SM9osvpiAYGEZrCZ+CGZvhhFxaPbLC2asszCwJY6v/20f" ..
	"MWSoQOri96pikVUXybR/4UQjSAEKWUqMtLo0SDLizE/h0B6Puknu3XHr3Qb0tPSctbJC0Ep1fOnXET/T3nj15FrWtJyp65INYgMy" ..
	"ZI9wUmYsFqoc75kEX3OrAIZoVc7H8AbquLnxd8QxmEq/xKVH0+EO1slFKpq5XLzSAsC7hG5XA269ajHy7mwKTHHAyQRaiwsL3plg" ..
	"9yDUI1XcmJoPXrnIYuFaOoCfeXF8L5qCN5kws4TlmE/0XBHQy81SvsrJm99CNJGNwBh1Dj5b1h3oIY2X8mz3KVmuKCBzPlfkUMYY" ..
	"bAPTuCsk0RGEtVlj3C7qT65lYNiXF56f/hOHu9Bnfumn0+W+NfEJZyD4EEBYqy+wwFdMPurpi2O6wxvv/B9TkLk/iqx7zJPPQ7F0" ..
	"P2jR/Sw0C2wnkT3s8xGKTU2TFv0QErxsmUXEZOXUmwCJWuOAXh6EtF5ZmVUsZGheQdVi7xOka3qUhPWCXHxsYv9gVwLnBwMLBuqu" ..
	"GC6WoH8KNgLcU8CDf4ZDjjmzspHW+1JyPzVyW4I7aZDNT6AivpWtkTLjrynGa8QMQGooTrToCL/AUtGh0JTvw5ovnbdyw2cjCrXB" ..
	"4GJFqirDZf76ypZRKxwXAzcVjzHgwk8h7rkNKKDi9Eat2V/Gz7ncLOs7Ib4/C2SojNPmIwTSY93efTLWa6hlcWkwYKUV22DdF1UD" ..
	"n2O1pYkK+wijQUJ91blPwEK5Ek/+HA3Qx3ugJ0Nfl/iB9lnhrqIZL7+avUmx5XvswUGkaK8/CTpJXUxZI4mb9S/DOsFPJ/UaO7aO" ..
	"EDJe8e6LuG9ozPiwEcuKQRbRrkiuxNjn6rOaW18nxYO++k7vz8CnAzQg8knETu2GNr4NscN6i2UntU0AnnB3Rc1OOPyEebK//Qh5" ..
	"9GR1ulVmp/vU1ckYTKyAvUUyItolc+lXQxLQUvDBeB0U0vG1FRyonzyDD8jKA02RXRwAGJdLgPoleldAVkXa1nDss2ROOcl+MSBj" ..
	"ZVm26z+cf2Om1kckTmZHE3FTxkZ8HU9d4iuQMGxa5vJ1oXsEFK0BMjCpk4b+jzr6FZNEd9SR8a8jkGA/OB/Ft7VtatAObicFEm05" ..
	"w5GBlfLB8A2vVdncfEUWxtQ5yfdbX7Bch2rurXoZxdvcoik2FgjgvXE/vumJ0O3gniydNICeqZGPyPMHZYyib9+iHIFsIvsccs8Q" ..
	"002a0SV8vBa8AtGxXYxQtRw2PBBH3G56tdNzcJMivlQN6Kb0yjBelgVdARLsqISW1XeVqRLV0Gyh3rDywrcINmffoy4Fz1msh57D" ..
	"Sr7F1iRDPPHcKyWGQ8teHPSiZ2pRfLT7KDDaTDoXWQmOlAjniRnMfgTYjFqVT1wS7q/erT6TFFqhH/QX03daCOF/ENVRzaHmgMfP" ..
	"ALLfmVKkD5VJq8ZP+u5SFAMsEICfoWWsAhj9XNzokc15f2X/3Kq1vSdDCExoPhr3pNJloNTE/wKDnBSbf3YQblmR8VvhWsx5cWp9" ..
	"v9zyJL6gf70W8Ufm9sB0BfOO+P5JmCOmGJG1ZU0ZnQ5stI8ywyYGUe0H8bt0IV4fxH2we6/hdYv/u1MTCVIMtJGUdPfNiIvgekTF" ..
	"+mbVc2hSxVaji+R36km59d48jzRs+8BcrBX6rOyE6BYI+t0V4ZVfDZXKsC9iFo1Q+QplOEDn5q2obiC0SJLlIKiaGt4S43HwM3R0" ..
	"/maJAqMtCNLPJ8gEnk+sgnVQ1F1a/SxwAV8h6IJn++Pa8v3ZQe5CdU7b5m4v/7XjAokAcVsJ92f+pjD0dzwP/r0/3rHj+H7h0yfK" ..
	"AJVJ/nfAqLwRtwTzlTcgr0gJAHJOlFHk9cJDeBNoqSI6MOtoRbKaUAjB3Ku5TWnqcELKCA3MeKfYon0t/vhHXtRVKgRw1ugJdvbj" ..
	"88R5N8oxYqVpXXOR8F1Wpg2UL+VnxHrQ9SWZv5R8r6vl9M7mnNq0ZIbZSfNND8r00QpLR+gbwZ18+V2j52BHV2zwpvcFhyWp37FT" ..
	"bCn5iBftNMCWqcJucxYPxV1AJvg7GPVz3nWrwLXoWb/8pix1bPAdDhidwcg0youFUy3UX0meu0NwzNbywoHJlmMHsWloPL2xrQLN" ..
	"25eE+qPIbjgfCM6+e1ajUJdI2wXaREe1lo/P/s6yf6UUpPtChbfc9cGe1fZo2Xk5V6eaA2KE2wCiI6kHyew3NFogaDHpZU10ujt1" ..
	"XpGncKMnCUKhZIPY/no140CfTUjWcKj/4km2f94VreCr9Y38d8A6k6mwd5f8/AAqARDGLJjYh8quM47OcXTEsyrfAkUuRmqLnhnN" ..
	"aVPyDZ2EimOeKXc/wVrQplimxTClmnyaP5ZpCxzK7MGQAxEthc/9DQGeabq+8Co3wtiGLb6E8GgD3MqtnKLvxNj/KuIBQfQTufi+" ..
	""
local PAYLOAD_P7 =
	"cEke4RTFFiuWpCoPRsKSfENd+IJCPYFcGQy6W79aLdcxqvEHD+KXKKhnpexosoI6vcZJmPSlh8jbjebFm50jv3vMMkFHRFnPMUOb" ..
	"TTfB3FDnXibjTXeenr95+gSGvSXUXWB2yzRI5Zh786xngfZK0jb2VXhVgQhU2ton7r0QqNWzDjtcjSaajUVzhEpLJbdIVuwzs22o" ..
	"j6v94Qw2Lq/KeHPly/MbRsToDwFmGi+JT5cn9vB7mfZYuSwZ7dBVVVUlFGmRbDH8yJNJs87MaaKSqGtUlQDpM6kFXmwtXJGTdcE/" ..
	"IxYYcIWXOl6+a9uKPMUSqJ6g3vt9CVdKTiA9fW/KKb1bitYwtOa3RtKroSYC5k/gHA7skh/TIRfZxzBXpXrHNAItBHRBXJPP5Rpx" ..
	"5rkq0zxsnRgGx8U8Y5LeZB9f9+f/T9LczmJsQkzzYbLK2TWTyXSLG2zZWteJNbyaNEIGQnYpLQI1M4CyQuuVHIxqYCtxzYcPEyOU" ..
	"0iOtpCI7L1kfc11JonmvcSGlSTwxSx1kq5bYm8KEC7DSgPTqq9AuTcUoYMwVL3t5+r65DNWVrDz2DfmUkKUh33232+IMky1ZKCWS" ..
	"MCSwFAXQFBQ8H32j0W1U1Nlh1UgybF858lQZy4DXETIvs6PFO5kYBcYqk73CKqsX685Q4JAp7Au1McBmApEMphdWUyV8KEcEL89W" ..
	"QCKdWwfFxue5N+qjLMgvut6sKJYc7uO/ZgxbehzIlXftwdxUF4pptY909riVpsujNKJaHojiJxKgPodDahQORH0zOZcbaF3iFsdO" ..
	"e4vF/Ces8P7v+xEwd+FGTNMZGKztTdYn3R40XYPIuy13KD3qF7TucBq1XTYipGhL+5ZXAFhyEJ8wfvbwuLNjc8SdMU4UhnWsVHCl" ..
	"tgWKSogldGDNQHVx3W0Wkz7u1DiysMJ2P1tFKnxGo6MSdwz5QHjqXUdnPXg+6GjTFqBh+w+zIRM4l0FSQm63xBvYvUo2IFJoyLu4" ..
	"2A93S2pNkPG+whz1OJp1RkLpX6/+fa7VbaNNozFtpFkYaprspl+iwRhPEacDQE0HEjrldLdRRrIrBC1IJwleQZqAMAnJgoLeuXBi" ..
	"1r1Ma/Hs7JEtx0SuxL9uhNbO/4sNBYK4q4eICdBd4RKT6AfFQSPpERQXUuEl+PxBaV49h4vHonR3bwTfHGa6Pz2No3hmxG1DlEyP" ..
	"iEj/JWaPN6qvBLvGHpH6wI8sveNUoZjsYQqco34bY2o1MCQDppG+1HrOCx8FOzHGD6FpofZ9hhmY6PpqqInOdlvtLe/P6mpeb/Ui" ..
	"qVLa4/+ntPUbPiZUWg9WtM5HN+k52TjzR/wI0Hs3TtGXu+uhrhE32tea27HlDlv4nn5fr5xTreFRb6NA+YYyl5MXWATPAZLZVRkN" ..
	"2IHgK0c2RzS6y4JDMsST7oumDoospwEvOlFeZGMd/xqZZTv3OyYo+uGACo2CYsfSla77lCkANLDehBr/pFl0IvXsHtr3VFQSoexO" ..
	"+PftW1HPnYdAqenjYk76nKupOnpAPEryLVWKXnjm9UY0+vf3Ed4HtNMmVZkRv1QzXzEhvP4FLLeW5b0gLrUH8SpmJzVFs2z7oW7D" ..
	"CYTWGLRpW+1GcVADRmhiYtbUctqmIxzoUUylNhhNQ3YnxTr5Zb/74RSWKE5VKZjaqBv6u+t9t0Y6Q5S2EHuaT7WIwwJy2ojHBIrA" ..
	"ETNqIaC/q6ReAvVkxMK+IP+/N5/VX1/0eabzxjuqbA1P2MjILCzguCgFSuVqmKtaZLwzCcNPFhfUSN8xmQi5MWbyBT0U8EC+ZVmp" ..
	"cdktd/jsqkEmDccM/220r+MjBzSl2QE5UWo/igvwJoXWeunTzfI2itjc3jZKQ6GIOUQbqTtL4UjOa2dAyzEb4H4Rufc4izFUJUbT" ..
	"5+LTVwqjCqKQENQs+5a/mcvhHfsUt7XSGiwyyTye0+zAF7+3f7hbv/30cR9T2ddtwcRWAEHE/QS8mVsj4GdrDVgReeAvMNKHDhJS" ..
	"uM/tMJ6V5pTCnl2PzsaLiB8/F20mz3Yxjf5pBJ+7mHS8WX1z5I5AmxMLgC2FNSnFfM+4hK/s+e7kaqBl3JRS964rbDhiptp/T+Eu" ..
	"vPrRAKasgL8mB/1mK1Vu7P/HdlZVg1pi4qThSHpQFLnmLULMwVovYaaYvOI7IpYh+SdU8QQXPdtGWcmzV33UwjiIrYcclZ+xzpcR" ..
	"bvptXnvK6g/WMcaQD32O8Y4VMaf3sBKAVDL/Ws/zRdGRkAoqd+2MqpzzhSJyIXFxykXlFzQhRMDKK8pkn65xs3HaGiKNkeRAJlrH" ..
	"1fGnPBTT/zcRa8zkwHSErWDza5QhN6Iaz/UhJ6NtWYtUtZYJ98O8P8LdLNKwfrSi8GTsrYYNV1kOk0/kwYUnBrxDC1xpEgMGLVYa" ..
	"Zs02xtYc2b/GEoKN49GkfTpdUoZX78iwhp16Q0+G6z0JcEFO7pQBNQE8fGY0F4qFjsC4GkHJ9MZgT2J2sn0/5LvzgvWaEJwl2zfu" ..
	"LdpeZ6KmHTQSUTp1UiWpiRGcqiizhB37SJc441OgFThNtwHpvMVp52jS7naePCY26LDuwCmHrBTpc5CKPRXRveVdgibX7v7lTg7f" ..
	"91vi/hXcG1cD2Yv92obQ2Q+TVcYCpXS06UPbl4VUyniXNwn5XO2YC09mZUkpeINOzIc8OAv+KFWchzLYh4iAUINeqjejUoc1Xr+p" ..
	"fK62qPivpdSKNbtmN88LJYhyIfM0miK0c9uaEteXfFrPZG+TiYDiqwERU+obb4r7vOAEk16wslm5GQgXhzwm1KYRMNuLGDcKf+jv" ..
	"iQI8bzur1AqRGOH3pFaSUbD9GV55c62E+f553L7SuamJAg1H7TjhTy/aYlSs1SqJbIoudglBw7CtYGWNCcGn4QO/pe3vZNGZj2XK" ..
	"Sk7pldDMgf90fjNPDFSvhim4AnbLtUJh65DhWmMtd6RyFzT1ZyLRo3vqguT5jgJjtodXwWoC9bAUtTGW63RMpFfeHjp03IuQcm+D" ..
	"lgGffJZIkYmchy708Ggf85y+0jbkMTBuqgXMe13mlCqr1SRnlj1ldE/AW+6CqBWeNE+4FBOE4+Kb3t1i1Z1uC/jwMeU9PYvKKVMi" ..
	"U/PQTeJ/h+2N9VDS+DUAYA92ncCk9ceejuUpw7xg7R828SZKbrUj5FC6MrMANnAfljEnOjzBXlc1wz52VAmuRi8lx5nLcZ7o9mWj" ..
	"BdNxmb6kN/NFzgpwbIYCdx+twiVlNNz0rtehhfYoJ2Hp2JC8rG/sQZM4Tm95ncu6AhVUHtUbitFsBMGQA4d37iDKbOKF96HvPdJe" ..
	"dnUD6VkRwXx+ZAt5sqj733Jp/nhljM2/Lq1xxjflnQtHftj/taCk4BHk02/EpuqluQD/l9IDdBUMbuqhQLzOeN+dldvjK2T9J99H" ..
	"tgaVEYK5wrDB3w4ZIzM05pt19Z890fMNvwhMGMRZ6trjvVCCVXpuccdMVCIl8YX9b8CjDQQKGWsdemBzkuDCBZLwdelKoY8l1qDo" ..
	"5fyDTDIlzBP1MQxI9CuCluhiC6etocXan5lIIBYJz0jMqkQ8Pb9A69Aqyk3kv7w+GuvtByLmsA+BsOnKkHYRbNkBZHa/O07QZJzf" ..
	"lg/T8ynRQB5h0zaGAwp5G6ok2EN5dLQ3gh94FJcIxHPAnzSerAHtTSyFGCMamBkEHUv2INLTFsxXjWcuObxvpRM3ozIn9tqYmz72" ..
	"H1Ps/IYKwVFDrPPKPA5geivW+jLNDHlMOityd4Fb4x//vHmW7Wgk+dvfWG4PNCUOSmg4IpCVVUpbxReLWqo7R4kyTp5uyo9TJ4JT" ..
	"IjF0voODYNy5dNZBr6mwGW5N5xbgq382627zdhuYj/2jKaHy6fhTAMV4MRMb/mJxILdU0A5bqnJxf8wg45/hRbBAzKAtgLABsu+2" ..
	"znz8KgEoG14GJUjUHCDt3ek9ZhGTxF88pEegHZjCmXCiX/L3ePf5y3ZBt5ekcr9u1XBe6Uxh/+OGHnIyn8rcRDnnacrNqXvMu5Wd" ..
	"BVjyPVPtalanLf0NmH4LHNE4pxnHjXN7m8ZdLQ7Tg0Ckc7cdQaX4+zDemIqns0H21lRtBQeiMOeUiU5cwiDuJUbgzspN9uS0sV5U" ..
	"AxWlU2pp0QkWxpQTVDBeSTRsDj71t6q3hNGO20Yzh0COhKYhvZ1zChPGy6+1ZqpXltkwi+ddw2C0j0DRip37HriZANaDSaYonVeT" ..
	"XmOi7pqAt7eRwb2upWCXLwORAixkxYMI25NfYC7oR9rqbCKdAX2wsXC+jh37uffgH8rl4o8AsCG074xo7DCHm5ejT1K66ZPMN9TS" ..
	"b/9/C1qdrQgXTXwZEj21clzvcwkBXgscg7QI9XjpTi6Ar6JvWSANiaOsTlA8bNzXgvT9zP0Xgkkf+dkH/nJB0A0ikMcLBHlKksz/" ..
	"IuH2GMACwEKbS3l7BCyLwYFcZNmLBs8iEwnQin+o6A7RX0kQlIKndWzrpIzRoznW4fe4HAhFewuRJsZMjGoWqRor1p6bBIPu+iLV" ..
	"sG1ee9uOhQF0TT3DIeIrxmCETPEtt8cDWQciOFmhh4J1YayJ/ASGk4LoV8lVMiPEdW5zMq4GorXBr+a4vrgx0yk/FzX14GiiaX48" ..
	"l0srr3njuLjg8Pj6es+3yClkSBIVX4DnWoTi+Z6TpjzSMk05i+UVholkS/KbRNiyme2FOeDioew8aNpOimhVoIWoNZz45CFli4ea" ..
	"6vzDLzGxQhe7OFnBDGs1O7l0ea1l0/u1ctVKYhmMhbLu0Duh4EanRu2OCAYWLx6ROCv4RqjFsEcNs4x3kLRBN7oWQCWyWTGzR3Sc" ..
	"XKHgKZPO7gtjG2jfL0TgnQdbqcm2i5zBusHYZyjMXBWKlNs09sOdXzcoWzIuxorFBGWGkYgmkVGGsu9FzsLQzgadnw7MUuZYUtB9" ..
	"cqXC+DYoteIYxvAVKwY73DG2iP9H7aM7WSdjoO068zhg7+AIpaG1z6NI8sIqbbTHBRE0q4UM5Y8KFFkJ1qM8Q5/8Yo1uHC4prFJC" ..
	"VSwn62UWeWKwTHDfVFWSYAn+BnXNN9WvnWtEO3SCEWUmtYvAzCiZqqp2dMB2JXbXMzwrEXVDXhvNwIBHi3+pOwkCwe6PAZ/xo7FN" ..
	"LroDV+lgfx2+5fXxcy3bCPz34xSTPAvl7R20SOOwZbNc1FwNB9gNXxxivQgJoBJKYtV5O1pzMQIRBO2lk97XWrlUaHLyIkFfyb7O" ..
	"AafJo1xsZLaiVmKxX8bjivgFHUqLqn6f/FFakDRJxjtoSLrBZPsJUnLjdt2pfeJblik5XtDz9tG+ZfbT67H3PRhy3kRDS+LTiyl+" ..
	"BDW0Z881VzeCyzNPHpwcYLRj/NhzUGMGeLrnswG165bu/RV9p9HRuYl2jx1npjvF3XolSy/KVVdKX7/O/Fx9tENxkIlmXNuIXhyU" ..
	"1li6Ixp5uhc11EeB+b9fdOUKE8Q9pWUHdIqp55gGB0boptnXY3F+3SDcY9Btv9vprhjsQUumEPE5bc/ot9hOJ4W/7Oy8A9REfSe+" ..
	"4MZfDMHUtHRBdAveVpaYUrHa2GOYqMMJAxVMBxtUsxo38jMo7DeAT1zscYV1nAWtSnfOf6VDNvZYLBIDaaBTooJjSxW+ZOUJsYgS" ..
	"t0uaH95X37uKZVRzScbs5rvTUnrT2944HnYJ1iuDqJyM6sl0yTS0fs6JSmdT5TG/bQzdKBaSVOWMQZ8KujtrzSI7mvdPk1t/C+nJ" ..
	"KRZS0EcWNBsGkxa/JxiEkhNumKmn/M2Ur/kFprJS/kgImOyGN1mkNDoXe7PsSweC9GIy5TfwLhJjjlYe81apOWL8jIwS5o5aguSE" ..
	"XYYK3ZzaSpoa6sjiHI3Q1XULYybWgiZY19AmfkwqTy7JdKYqkWfw97APxvKp8Du34rTYjjKgj84m+lSdF6R0FcfjRWrm3ONrlbaY" ..
	"KtTqAUaDIyTaIEGJ1rM4qb5DhGiWEZ0bKjK4o2sRhe/PwCHzPFtV/LboomKnw4Wh/Y5G+vn6qLswqSXDNUyzolp31jljUoNQ4klO" ..
	""
local PAYLOAD_P8 =
	"a/yA0DF1OIdljz1oxDs8uwzRF4O96YxTUXL67j+JgEVdELtgClcwMl3aLcQtqoORby8FGI96jfB3NQCeln2FlQ6bp02x6gYe71xT" ..
	"iUY1/92elGl2HCujIbn3NUAD2t5q7FwAzpPwYV58Puw3hIwpBenD5/73Djjhbz11I+G9QPmLjqwf+Txi9+Xusv3ISGiH/s1qRVn/" ..
	"dlVTr23YnFdTdo4MK05rfstpnEOokm7DBrs3gKoNLbEqoSqkpXBkxWYkHBiuGBBrGX1KwpCODg6jFhZJ5CFF/tG/gLIOzhtPsG0E" ..
	"SacY02TQ3J81vPw+Ja+N5xsnTBcGAuUzpgBqfsLdwPIgud9oTH7EwFAJMj9ZxFcaq49LnFuhXFYybrnKxAwphEaTwEDQPg2bHqCo" ..
	"bsnhLl670WUhAyUUwxsqdyR41lUSTgQwb321J9aOjMQcGt8LzV61DefSFqplZSZ8Cfz6nC+SDdt/Mn4VZBsUFMHA1LD3y5WRIo3d" ..
	"S9D5J8zEm2RJq9IC8Fq81zThU/rX9mW6mnTwrbVDjui3O2Z9WOIjwrHjt14nX6UIMvWizfQpfR7h+JN/328DuLemF5C5uSS0YZtM" ..
	"6dfzhr9txVeIAU2S3sq05tmlffZNN4zkvtPk5i8xflpNwSJx4DRG8yCnp0oX38461W6XkN3EuK8M7kwmKdczSme2WziqDVlb42nt" ..
	"4RMCkEXHVs3hhyG7jcmKi7JA7mpQQP2K+B3qLLDwq/nIufXk2OyvYKQ96134omIVZ6upmO2WQw4vkkWMQ0gVBzoxXHGDGd+eJndM" ..
	"mJy3M+2R/YIivjw49xEs9N4noUSQnZKDbILG1+OxCS7HP2S6peQXIOBxqSiRECPGKoPnMxIc51paTxlF8gqNtYPCCJGiQfGkRJoJ" ..
	"KjxfZgLIQ1M5+tLv0oHYd/gk4TaVtnlrX+jz8LzDjV/0jwnUtUIPvFz0uwjdTJiyLiCviEVtiNNU8u4SMynuoIM9t3ztMTqZbR76" ..
	"kIvYpftFq7L7VISUXX11d07oqXBmkb0SN/DcmjBJxTUD9LqZAZWsqmTxjiDWIjmHmWxTtnR0vqyIkcyPjuUs33XlmxdT4wVI2yu8" ..
	"5TKhW+qD3gH/tcbUca3MiE+wgfl74R3Jr7B2N0PgaziHq5Yl3ct+JQgjnMbfyh5EyQEERJ+EUrVsTAMIAwAn6QlzYAv6SzDrofAP" ..
	"sGDKFK4GVr4oAbebls0C071x0vdRO/DTW0ib7xbAw9/3WAtFFzE44bizrydcjj12D3Y4taonKFvMxq9gTJIC3CSPHPDwwE0z/Ld7" ..
	"ksA105JucYuLJWFo/ALra0tUcOOyUoYcCdPDZRGc4EvKcuoFxwxHVhzIY0vvGh4g76MEdoW3YWxu9XGnNQBOYuCjq2klAh7ilBDO" ..
	"disJByJpIJcisdXLvx7dGNqdPNOSwb2yIu6Be0lxCBj+5xpJxFeGO1/jMc/ojGmBKkN9i1kEpbnH3a6Dy3leRPWuWfgYqeDGyJhI" ..
	"ZUDneHf+GNUAkq7nwmM7G4x7Mh0nZJc0oNxosi9tdUz7fFRQFr0iabORwqaKpeRrfVVNrp0yXq1F2KgbyIW1NLLH5n68KJIu2FVn" ..
	"SRngDlmyNlIAf26DwTFHORR51ganJo3JSVoAZJN4OeFtorPBsd+Nae+RPAlrxblDkdY31L6CnJo1ncUH37qkvY4zytTyWmqPw81k" ..
	"cncDj+5XTz+I5/IKdjoTMZryKNjEJBcikiv6KOtZ3W1W/LWS111k4tRe3kthyV1l555LuzLKRB1JmOGCKat/ZKZ6Yk89S5B5SLNy" ..
	"/3nf9MTT9jcowU1+mQfjzpjAlh/ghm22Kzymbf2eHX2j14H7w7eEF7ZlBMFlFPJ2Y7jnE3kqh4IujE5EtBjhjIAu/YPqv2XUbQuC" ..
	"SvonUsl9k6KFiJKESAiQknQ35lOM8oIRfNmbrb+5hRz5n5KpyNAmDGE0s+IPH0kS0M2LnYTA0itGQE2BmmvvyrwbVhJut+LyG2rd" ..
	"6Q3UeMm0r32gQkWX0W+YHrZmq65A3l4v92l47QcBjrd40MSMjtvcMvNDcZ5eO4S5CwsuZ37dJ+Mwz6sXFtkaKcRbHxFnMBGacvQu" ..
	"ZQ8ewBi+ECfmgL0RPSxdOsICmyNovwbevtlL/cbsIuzyfx1GLUMukqQcYKcQMvBvhuSbEItVkeviWy6l8WUB2v+KnEJ7XkdP25DQ" ..
	"DubSQXOinPRARCQPGHZYz4t9TZl2EkwKc5GXoXMBjVW01s8JGGOt4ZYgtzHpV+SqkxTEwM841YsQyBKTqFqDF+f4v54bLuJC9wb0" ..
	"xxJ5Hhnz5l/Q8kzFW7LgTxluuErU4AJo9pAAdQWmFb7Jkx62hzjYVSEXTRtCU8mM4IHeIQkSVofo1w3qVlnxxQpzkdvDeFIq2hZl" ..
	"b39D4wiEW9l3rM/8AEDPxTXzKDkbMftlzKj0OXU8xbwcTvn4dvsRjf/G4BCyaC3M1R9VnJQGlJYb3znw20BaFmDBig+aV1BlVeF+" ..
	"u/B4smc87qtnkYjRIl+HSXq51VM5NM1pn+vRHjFBTLVU2q5bpQk88/EtMKZYLARhOO+XLRPtbXMcJJNenf8iN9wqqohmrvI9lgZ3" ..
	"FcHyowfHfGVexJFS9iOEDVRaLsaN3PzjOU255rQILRSb3VgtEfgGUeuRhgVNwSwwfunEf6iBVmh01ISFlCT/DgLbBxYkWtcMOCz2" ..
	"cWiYXuv95WqqMezbs3VsBfl+YipUzdv3TIglJ656SmOJK1TNw+11cDw3m6jmZVJJqyo6TnZ/3yGfvJR+SmOozJkqr6QhqGsWL4WR" ..
	"ajQgUZE3P2vfXvYS/joU7dR9SeSKpgJKTTF447jjN4BNZMrBOVKrKAdLikzzgCXzAh7VKY2HtUVQxlqBxz1LPZU6azhRv8ZeQ0J9" ..
	"Y5C+mv367NkOidLGP91o3h7j5jSvNTGImYUtxscqIuB4VPbUpz2eA7jNS3mjiFCc6bNJdlNgktnIY26PA1hZoVr2HsOfnGvevAzE" ..
	"jzHCeuWiG5iR1EnqJqFckdsuQ/BoJ8FvNQoD050yh4IKl5XLtQicjc5oUb8jQzvoq8Qe3CncwV+u5ZbLKk/0RAfu8KhEjvhP29x+" ..
	"ZsgrJrbs8eCXJFUW1QUjg5mgiVLkWeoaib3CZbnsK5U3HvvdtZHmOYDDym2BNrvT0gmHzlOXcS5vjlHxCfWEpyBWp3rf2h4/lp6b" ..
	"WBs9roF8BMPPgPLoNKyf/XgNiGNjYGxOMOtJNYVRHc8krF1t/+Nd99ftTsEkuDUiKFvSrXJsTMWdDFvUb0SmnnUUQ203/7da2wDg" ..
	"mHOaGk3wLpM0wsXcNVmBwDD3OjHKOXVdUE0QnfLfl4gmXUjX91P/1YUbAbQ4QE6ccPjy+hDceHsJViTvMPGNvCOKukNMQGz7Q+vY" ..
	"0t9PCF9rhmZUFley4Mxt6qdWJAt2bnHwTVP9hYzZlerFzY9EF7t0vJnAUuk2aPlvDCKaKovO44z7GyU3+mCJK0ShFX+532aBoRD2" ..
	"enOtzCYSilHZ5PrM5IPO8/H1nYzyOmyeQ+whuRLj0A78h7tB5A+Wv6ZuQ6u9obtqJPUprKFTh5Wb2RPH7Mo7UCsjTw/WHvCbrMvw" ..
	"ab3ZblrfLWn+/Hvk04uAoC9mVWeSkyxXoc/jmDQPt8wIuq8SAnV3T+GDa40PMI+fQJVT/MyXYjTuTyVLNqcAY6T3uuacnDNSbgHh" ..
	"m0I4/ZuOEEHhyhQTxQh76DfBTgq/thFBjmGyBJB/HLkrkSSmiVwsBiOasLXp+4tlLNI43RK0SQecZNiJMOqHg55jbmA0hNDw3Qfe" ..
	"kh1QCPeZfHrzIuUZ0BCRxXKsifW+kjtWd/UAWCp8FCBwJ6COZfTKJXtShNSfSCtTecFY1eswx64Hl4UAo7v/cBlpxxWrNU1K9ok7" ..
	"A1eh83+VqT+1PUHiPhIVyPtZJYqYCr7RDJXuHLYOW7Zu6rLUzoeB/qZdPjAyRKc/ZfvbjO+2xyJfylDHkQeRom32QpFdidqpwPDE" ..
	"7g7OVWVpilRnYkArnEnQKQhP0kNTdez2ybRzqDaOlUQ5T74a053x76A+1/KgRDthWOHr8WvXTl4YAXW1/lWbNvbwEfkN16Nj65lr" ..
	"l59oW1RlIaD/r2+VXRztupErEam9CCaKmJljCBimqCnpncuaOZW1tlaG9nDcbaui2bgXcnsxWr35QCYREBQPhR6dbAjTmnQN+3fn" ..
	"/8q5Ci67QiKWqJM3nGY8jA/E7ff64jHRV366dDcjj8jylj03NN44OB/Az5AeeOcthxD81chibqzuxM9JWlyzkHBys3L+Ehk4t88o" ..
	"W3Fpedr/C6Q1VMdzGP3jz3p/7uP34/BvOko5QxdsXPuswz9ryrHae8eoFf7EF/TI89xJCMmnrYij/YGaHubF9DZAYkxu0im8+D72" ..
	"Q+oFn/lnklktQC0dDNvOobDgl9a6uINams7pHxMq1SBvMWqQZr/ohonA0+8tZt68Rd44dTN3+GSBAJIwChNgKdEXZe2qV0gYkHAo" ..
	"oafz+sCJbdYP3r1crk0UekUqylK9/2PkFmQAYaUiUllORf7M3nOQjt1ajXvSHjiX0ryePT4n3Mec2t/EXg1A+r8eJFfFiL6Ff7C5" ..
	"Fb0MHpsrhLzNTcXQhMjaNrqVXluznZeyoJZ7HPtBkqO+a62OGnKzAGG+F0KDZJG2PwN6a0GABUvcBqB0ReIvx+1Ck7LGGLtmmTDB" ..
	"vNUaLsK8TR2ZOwecmfVql8+17tl4CKrR1Tg2kma0YAm6D+li3BG10mYYtFrMD2YYPD/WyRu9KE6+PgdyXhXyLe/Hu25OOUmJIKF3" ..
	"Z2PgnXD2B/Ay1UgoCS0rOpQFiNC75NiMlU0EBnjWge3x16lRNFk7kdtsTbzF8p7dQlGoqvky91WBYum99V/yxjnsOY3LvG6FKrNS" ..
	"fORtNhT0sQcMd1TvnwjwGn5SN3tiKBVCag0Z2kk2JGILiq7JRsmWjl2U8cyU5z6zPycQnH90s0gOBwm/fYiz3lYvIyoFWHZshcEI" ..
	"BcpvD7/hsJl582MldZr0Xu2FPSIDs0VPUJO7M4eOCu2MXc+XZ2AAwVxBl4Wk2cjf6BHbWd8CrqGgjjN3WyMZBM/7QZ6Z9VofSjg6" ..
	"WDpNAkP2/P0GuUq+02PVCvrnQ0HFQYzGHLuAGMoXVoCaYg9K+TxKAdZOaE1+K0sjwmMDK+gE39o/tLZpIMUHBX6ehr1R2HMxKKKy" ..
	"QOT9PHnQmeAp9PohDlVR0lGTppQim3DGbMEZ5zP80oQL/7W82u9P4stAjV+tEsNjT2lDDoOni7hPNmE3OBLbJ7dKOZ/qtBKnkBBX" ..
	"lIDwOBXptHIHGBKVgVQAS7unjQK0i0/LQbcA12fdMJ9b7r5HfLGnEf4R8hKQT28CSRX5bDqNHvEWYFJPzmpmIK8pI3gcchJ0pJcl" ..
	"ElVcsn8NUxlvb7S3dpwSbE51rBEqNHfNX73wIr4WtQrMXUGnwBWMYlihG1AcTmVrFWTHQ3vt8XvJyCgs/eeQpr2CMlhp3zHtGBYs" ..
	"E4wMwFZ4mQ+b4oTmHpbmu8V8KupjRj/uFYM83MwCLO7E2YLn343Vyzue4tcNDH9dBEB05HPAIeo3XUmNtOGF96OsqTbBMGU7S1HS" ..
	"SOkuhqj6t2eLC9BwmXzjLjiCLYjsMCZbECkynz/KK7qsTQU4lVtMyI90jM3bd//0fhhATh2Vb1kOuwt+fYtytxVx2X9v9g3zOA1k" ..
	"YkBbIjJEizZlCyfgJuFSNy/uLQXDyHe7kgzN9yjdC78YcP2xENbFm4qyS2DHCxyUagFq0laJ99Srijhnla4PYfC4dPVuSOUaNV+Y" ..
	"L/H6PLoHGvrlr27iCmJD/uFpNY50E9/wnZMTDUWw6kfBF4YvWTZykOlrRtmtoj4thIW4vmi4fH5bqt3Y/i5cR9Wlhk3rLIoZFVTg" ..
	"NNvKBbHaBEW3rcj+LsCzsEs+dSNfVzYxmGVwUNHW0ZexmMFLGEFL0wJXcUOgi4WrKLpuW/AjmdlRYPu6M7/zZVT+he7ulyAUBvzv" ..
	""
local PAYLOAD_P9 =
	"Bcja3DIYGe0aEmnekRM8i/nRuhbmWE1fn3bR3v+SvjpooObJNRwbkPTXL/8RihKUhirpPzwi8JatonhFOV143R0OZHLJ5PWL8Xjh" ..
	"2DO4Q4lmc/L9AOsFA2CfA0KTM04AyEsoAbRKIarf6VMcnClJPTopV3iksKs2yUA8osGq3nRBSH8LKfPCbeFbgi2TZ8478TAES7Qs" ..
	"gFecV/uCqrXw/NgHS075YA1N4Ro9g6xlZtuzDjycZ0c24zB4BYFHsw8x4M24D9SVIkoPLz7f0pDM/XX7zezlNbMNNsHumPzH+TBB" ..
	"CPKRo9vntoawD1Aloi3Su9aRXeQSwB5e4+qmSE/lAF5/SxVi7BA8fjLN017e7sjC6AR1mRZQINRi4NJlb1rPI0FcvnGa7r2kYsAD" ..
	"wTk2v8FkDyeD/P29Hiy46X17tXQCw5dQQ3Zuam8h/W8Gl3E0o3FwYgQrBPdqfcrE7Uci8XtHHN03WdCfTJxfUM5i8rkElamCWyDt" ..
	"pwt0nuZDT4zN+GdHaaWbDv7LgnigBLVbSp7Idmy+lRZ8JyCtQhqFrk/BgPJBemyn/hpkz1xoY2T9so5wOlC1OL1nX8JftYSbN7hT" ..
	"5emfINDE3DzlAM0ALBjqUIAh9mfV9p2qlCldEB0+QXs15r8DoUybUSnogbXgm8u4kn+pDA3QglgyO3zf4Ns4W3jQpfoV9ss0yE/h" ..
	"qzMrRgMOanFNGWpWPzsCiKK1H3VD6DDyiOvM2+pxyMpv7mojIkXl7zrRph8X+1eqlvm8q26ryTpV1V6GB95UR9/HnL/mzNTMk8d5" ..
	"OS3AkgUcjLjcelM1Y5xRbTy5dFP03zADytIEAEc7eiwTt5i3ZtL9vLTOGtoUuQ/lwIF35Gph7ee2WRb/mjAbTOQFBnnSU/7GUnDB" ..
	"KFlu8k/u4RGae4iAPCn2O/WQZ6coU2tWMeIbHZdz4N5MmA9VGDERP3JAytCX0IazZB4AL+qLEg+7FGpvHYr/n6JoMC9lZA9C+ROi" ..
	"OFZXz/mlP3Dj4UDtB/wUqUUuMF+FSFN56QJuExP/QTq3qmnTMtGOn3jU1oHJsSN2Pdu1rGeKUd15ZgAPJsgnnjvZa9oK9LT8SDDi" ..
	"syNSdIPKmP1xm17tepSPp/NFU9N7CbSu5XhsKQ5LV8xmte1/xhX+sPjH5cUNbmE+NpCU9X5iu38DtA9AalXl1JCR6UNVA16+VJzW" ..
	"H+3LfjlIZA6c4WnLb9XODsTprZgtOgs33DSg6/XoSEK8AVFKBIqVA5ynLhWxljGXS9MTgFZKdPKW76S8i4qen2BfEsLRWylTc/lo" ..
	"9gl0nGncbB0nH9+mbUVfmt0yvbn1rc0TO4QT5Km2or4icHGLHBXCd/dlRyeGLsmgHMdgy9XjOLMiWL5kPZF/XMadwLdfL21BTBf+" ..
	"A9MLHZbifLWS3rX/zb62oIExXMocbPC8QQOZoJaEs+NNsiIE9ydS+iMma1XxO5Ov++jICfyIEnqr+CLylKndtiX/DYO/VqdRzdSS" ..
	"z/BNxXjcQIo1I0A7KyDTWFa6e7P2SDDuejXHjsNaOQ63dGBnF1phT2JC0cHvYuqOa3psHRMW6vGfJFHGtwtNgKv/jXhCu/R4kMar" ..
	"AJ/V9M2WdAoTyKiSBKLT3KxL2Uqo5Lh6BXLluDW5ffxIei0aAhTDTKhSnacJEBupnJ2pWpDtnrS6AXw90dpyczWlROZ/6yKiIEXq" ..
	"wj73YUvcH14I+Vcy+i81m312OpBwgd5woJyczDIA9obIEx7ozRn9fAwMSt/eBoObdGZpfeQ5ZTygnK7C1Xwwt/MrTV/rRyXenbaU" ..
	"548ktjr5dZr2tXF3UwIg6qyakTH3SXDpG1GsYMhGVqsuS4sva1n/pZExaSIZERg+g8e30S+LIJJGUU/aPZz9lU3SOb1c251JDy7u" ..
	"WUadhqJd31lFVCnJdg/6jZERMf0Y5O3IVoAWZzreM0Hmk7/RqYDIbYiKYn1Zi9kgNNdgIu5ngbhw6gGbiZ6HfV+zBkmHYazshknT" ..
	"ZxYvVmeRatXqnd539PgD6IjzFQXhiUNojJCir+rvXpzgEP9E4PYKwKiiVnusDwrpM4Aw0l0ZiRsfTDL8kGdszo8UhhbwhZx0rVh4" ..
	"VA2FbQnyq7H4cypNaWMH+h0wcmki34CGRWuDBMH5XQi3LsbBi23+tDWjHSxPPFe2P/T6t9U6wb3rbKTaHytPa010dB1jYv+Q55mO" ..
	"8kcL0BSvE8NxGWXycss5HLasbyPi7h0cSGT1c+urgZDSXRh3lGPEmm3jl9oKky6A3hZI4DWcOWM/WPrKgHopNjBT2kh5ah5uVdvk" ..
	"CJy4qmks7opHJUZZlpl4+W6i93HN1wkPYng9nzIPwnf71c3R0hMn6sZPm/zQ/t2Xs1Kpsza2FEKF5SgJb7aNGwrGdT5p7IT3IyKC" ..
	"9Lv75Aj7fMTbIe0A9eZ6FZ8xO9k9oxXa9OQVBSpCcznsEWS0htetFrl190WnsoW0ykdaZgNBYOLFUtnlK3Pl10DPvU/u3vfIunQH" ..
	"my4EggTR8NfiQzF96FZ1ELctHOkM7dqwvyPFhNi/MWoe2gBSs3eMCMk1VONzsU+0HDmmJ3T50ca7ts3eWuk7+2LZnpBUFQnbl9St" ..
	"wb10aZcklj+ogIHVnOZ7sELkNoTFY0fAmlfMm2xawHTvgWQNGjUvI+bF8gdBFVaUUmFm4na9hbadeZqVUMyHEfNA0ucjhnj5GUkV" ..
	"K1oc7VKGIwBcItHGI7H/F4Y7PZTAsRoVSligB9dSlnFrko7bXUWDg56Pkr87NRG5lgV5i28vaYm7qBqbYtDTrSIXDWvf/C/fnKnI" ..
	"8Dsd8bFFGMVp7McX9H2W3G3ljLNWeTnx1kfyd+/uLZqs4935GeuZN0B7ElGpGpOI3aPgm5D142tRHB/J0rwuz2OpiXOPUe8SNuJd" ..
	"33sqF1iBEY2qgbXHmW7tLU6wVNJLSh5zW7PmHbWO4nnCTHFE2nWePoNof5KpaSf/Vyd/f+90pluFFwtcIED237diw5a5PskGDJOx" ..
	"BsY/zOt0bpCLnkv/yzuMAEx3HwGDVXKXsZVLG3RwFQuzsUMeYTe/4nbmXH++NISuVYSORGOqSeU5Rr3Y7nn5hEe0/SGDpZvoL1Ep" ..
	"/W9GMTwaMrHE5WsTDucDeqIU1bCMTdt78nW0SYlfz3S1TpCH6uvg/hw/96w/1YSqamMl09VahLbpF74lWWq//SUKUxfKFeec2h4c" ..
	"AdiqLQKUg+ba44HRH+jYoefnzgXF6kApwl/uT1//TQk0/UIwQ2Yns11pJNMReU/k8Q3b9+aFeR3cJZuVRzUhJo+q1esOwnECHLKn" ..
	"DX48maRTh5YbZOFA43ZOf9T1s8V5wAzymhM8GLuI+68E9DthkECnw+pkjALmb6NYqgWteJ+GcYhQho5PNXo2uGAFzoM74dGqlc5C" ..
	"cvRTWuEEvvN8xhbNKWxTLckiEPQUI8/avHuoyvVZvxrz4L5B1jzc3dOpfPOfV4M6eHD2BE6+x+hDIukoBNmFvzySA1ZuaJdvIjU8" ..
	"VRVctRGPq4pKaFygj/Adf/eSUkNqxN9hChtPyxbZC4x90hzfp4oIaZIg4NN0Vg9JO+iO0THvAkiXV2cpHZuRk8uEr45IFCNwgAU1" ..
	"XokyBBrWxIUeEA42SwY4fN2dQJyk8+VUHsdPeMMrG6PdzXBxL7FzW2f9hBRqUuXcCFiiyu+fdgPEGyXf3KjrOTXcpbzu/vRpQyXQ" ..
	"DUQl2tcy2CLvK4ZHRbj9rE+GdMYWYbtMFlNJT7qj2zCfDnPBzs1hznoDvogjlTcH9pgGG4rmhxKKssymvSNiCG2aOb4SJRaquJ3Q" ..
	"8z3XFBqa5kZno6jeBPNubwspbUWHCd6Cl9ty9ArUQ3ld+r3dKJx7qYWZqgTEiVHzIm0NfjDbrjX49kvs1hd03j8yqruqJGZF7WB7" ..
	"sKnB0rKLmy3f2Sb7UGsGl55bsI4BoKwvoM+jJ0x5TNKQjpxIDdPWOPFzfz5xm1t0l9nXlv2xsYj5Evl0deIqqez6laDV6BRaY5q5" ..
	"T+WFGPTKB6OwoJQx5G/vTHbBxWu22m9cZwWlg2mvhRzZF/FMj493D1RoUAlGB/F6Ahr24OcmXdzQd+LG95Md9a2XOTPjmfgPAPQq" ..
	"NJwrAr1LoCwnDl/LxNETxxMNgg6yk8miDhziO8arP7a7WZl3R86n0aorttuaUtDxQeWCSkj3JKLIUekwcTKDOMLjPwmzeMBqrDzS" ..
	"7byBbpGnAzQOAYGBr0bBtoDMrwxsWLfvov+NF279BSki1rjCEt7wFzTsBUTbsVQU2WVhUC0l2ng+aFX9GwBWKexLFVVSSxaxskAr" ..
	"3vlT6pta5ZxzHKQhG5XZBC88TvduPV02vhhv5zc0dalPCaRTuNLuU3Y97plZ+sGTL8XCpK5k/zDLHFt1LFNdHZVZQYObw2C5sM3V" ..
	"CExnSaJJ8qHzOQH7q1e6kHYDPBHGGEmoXu4nAHce3gpJqVy6ie4GFTnrNXLyRdOGN0ZbQmtD5S4M2sIKxmEXbaHr7nvcvEY4gTo5" ..
	"VnXP+qMZnhmaSQXuyD7tSN78n5ETgThlqE9ZHd2eLARic8MQjAs5f9lSvjx7xHffxsGewM1bAuf+CKzo4PfYvp8JuqGJyTk6VSRO" ..
	"QsVy4aPBqZn/zRT/e8DipeNdCR15bHdNRpS2ykYJtCKRm+QTvtD5UW19hk3H7qwEu4WipoE4lSaqmnbjfA3Ca/4c482lfNljjzYZ" ..
	"N1P05yS2F88/8g6wsnqn0rZ13s146VYi32EOXnVLdIRiDvRZCMtpFpMLDgRG4dwEI9mOVaAn6kRMtsJxwI7sGF7goW1YAOTHetQI" ..
	"uctKeEnnSBAUnkT7nv/rKj9orix17Ml4eH1vc4FgJC6BTr/BbhQaFLTItuofg+gPv/ei5TP9SYEI0ykXOVBQAJfDSzEBNsdDJH04" ..
	"FnaC8HbFMERE2TEXFERV1Fv9FXdDE3y6pdPDzhrerVhNURoKdQzQ7wiXshn/FXQk/R5CfhihELaKR/5gUBnb51LQUZX2H8KMaqVg" ..
	"QthBFT+daE33NX0SAkKVhSjTor1xvXMXalPSMSaz/lLd3JY4PwtCFXmH9Qe+z0falIpzW/aqkAHg9tS/hAj1yvwFoG9P+3Lgzqc0" ..
	"Nbd9k4ozEG+Ida8A+/m/eBVqqYCocUWGotYZBEebS1B1/2YgGRuPkb4zgdYmtp/ZSkzYY4o7Rkvk9pPWhFEWt40XmrOZENqWE2kG" ..
	"6ZYYziPknlgQRKa+TsePSfcahYUfmAYANojpIvNWag0sGS71eC46WzbKgRT36KZDrFh7juZBo7tjyyZA1BBxvEq1jh9jWgCUn8dF" ..
	"UNuz3gBNigrwjJ1dJLktjaGE6dLqH6cSSE2yIZpHBUa7WogW8mday0XRkzc/P2ZuJERppg3K3wpwBv7B+tAaYl3mOM6rxPlh4tvB" ..
	"lLOETZCXpXK9yl9+Hu7mDPJQHbHMSUBwDG83os5r1w5nI4Am/lL/WR4T3ZFbNQqkCJDs7P/XF795qw9+YdJzBbMi2Pql43IcPTwD" ..
	"d2S/Ipu4oa6t7fsnIJaPHi0NX/KPjF8Kc/f05OJHMQBUnsSvWnNhlUEhpQMkdEl9YPAfe6Cxg7btWHmjXn59fet/I4PGdfu8LoL8" ..
	"h//4Jdf8EeT7wX0tvkyImXCmhSbYhazIYsxL9j6QtpZazZQHUy6yqWzC4A15QMkgV46ep2qU3clvazODYL/UsIrMKm8WdnUMO1lf" ..
	"5ljXEMx9OklA87/LAUCrKXKX8fW3f/cs1xZlYao8PKzizFQrRFs5p0t0wycQZx+E3O2aE2lakEtDgwUK8BrZFATAksdWYH3QaBzh" ..
	"Y6v1Z72Y/EyI5ENLDGlVTA7RimndQ+7rdZRynjjN8XH6fUUvgq+O7I91K1L1CHp7lxDREhtkhPkYK456F8oVSpJxZx1UTVZQ5HpI" ..
	"gIxewANumzDm5p6hGw57WAbAq7DGIAGP19ye1aQ44vfrgnLrPcT8oLwbU9WBuLPHZy/pRv8aaMQ1LtE9NJcom1SNP+TNIz/XnrlU" ..
	""
local PAYLOAD_P10 =
	"y3SpoOYW1ZdWrIhPircpSAjK6kHer3MbQTSjrek+zmrsoHqZtCUQHRhxPBsha+ElVopOwp2nT/BfpCYFicE6TWCmbzTAt8cY484/" ..
	"8ilYYO+bPSOny4ABv1sVzs2/CBwdl8UV5pEcTw5YrGJW8JP0acSZB1GDmDGy8trCm0NOzu1r6mfL7wEvfTCzm+to4snhFKPq4rBT" ..
	"kL7ZjUaH9FoNUBag6oHjy2b2lIJp/Kyyb5KP4Poi6sdvCphuZWVY/OUD3bneXOZcZp+1jz6PvqHxz4zLAIPGqLAwSLT9vMbK+I6C" ..
	"CNBxcxQeqVdgEGNZzkCJbIRDVN7J+7RbzQmQjzQdMPoKkPqbsVWP0Ai9IjoYIMydahVm5qTOjNPkNYJ68vyi2WmQeFDLx/xQBPU8" ..
	"CSy/bZViZduB3++sC0uEVl6MiL1I8kTk48mIN35ay+LQ/E7G/O2NRUvhmh/sNhxgk1F1rbfqMGMAXQvb6X6/Kvb3nI7VzTKkmm/v" ..
	"pLEjVWcPPJaBAV6Ac/8R1lwz3Xkq7BelpG5NnXILVxx+329+tr+j7ZnEYtNliF/58jFQYcXWalTvYsCh2wav841Izw4R+5xNAfJO" ..
	"7VrfymuDVowHIvznlkSGIbiu+D5GPAdksHYTypffDrtND227wXaXupCmyJn1qZJdR5quwDFrcrRIJtmPfzfR9kcWgXYp5utXQkfF" ..
	"xmwURw0Lkl9mSito1UFfI3Pe82LGDYwbZza8VaJv2lD3g43kCr4th0wyPmJZZWr8Ty5c0wyuMX3LAnFtem4cChLa2dzt+rXyXEFZ" ..
	"Zh2v6Kao3fv54ufpM+g1JAH+u2VINuLLq55omt2bt5JmVgOSQhDY51AIYbCeOuo/x7g7GHG+pdV/OE9BnnvdZ31EaAKaenGz04n4" ..
	"JLylqINKhGxN2pyzgAoXIt8gVtDRdmhr1nFzA/126zNo5Ki8InoF3ugJP3WSt4iBhTJGaa16xMCaGjs9bLtK4L0hjK+aFPhAXbA7" ..
	"wxTjO1zpxISRgyULNS+GWpQWdGyJWvVuzwIiaDkbNZMB8rGArgwX4jfsIdn8xGKKT6MuPCWpqehCIbLaNeL86Dj7OXiQ1VJ1SBkD" ..
	"sAX+cs6Z4yTJZErcg5ZVY2Eeu9kYxOx6SQ838Hwb/vj9Q3h4IGJfM++jLjvb/3emv3jqCE/HOjxtQTMqsyYM1PsO3RfDOpBRH0ah" ..
	"m76of7Q/9RdJNz6J6fhurairntKXDcaMyUrWzE/aY8a56iGJjsRSHCirK9ka/pyjsyZrSFM4GCiFBUQvST5b9E3XDZWcIGyD8ZKP" ..
	"NxL8d4y23pdHfRlXnBXl/OaOru4ePytz9g+XnqM//q0KzmloZfdlL6+M0fqD2N9ThQOxn3rewU25o4dEj0TOHj/SLjXRRAY/l75t" ..
	"VGPbYu5QiTrCx+7DB0NTp1G02WPJNFREpxtMDys/3IcpP0iXa6r1lim19xDqhEuYW6jfEeuMrPk20La69poqtbTNgqXReYlmZzV2" ..
	"KJ1UxmXx4KUiVuJrobzB2kHWN/u4GxSWxy6cmkESJzJdbWkaopsD2pavLM/m8cmOM7ywwT6/JFRbcRDDWwoqpPelq+vTXz0yKHGM" ..
	"V7T+GazrHCsZEP23p02ehkXbGN7pg0yagNsqC+6Try4OZNgR7gKnP2oW9tcfYnvGJfnTDEfeQbzvIliULmTGaeNEpeY+uHPC83EJ" ..
	"Be8YcNEjMKEu/07Ar21ji/vVM6xxWLjCSi5mkO4MssVqey1TEcecHgBqLf535wXtMaaYxvCHBJ9QU3lkTp36rRlVUQgTgAQ+QmtU" ..
	"8w1L8lqKAXerDcukyfw28YKOdexuv99/1+xxCzizqog9MAmdgyoKL1DF6AeIPoIiLSp9Yf5puwfdi9Sh1rwfu+fsK6+7TbnQdkPh" ..
	"kfHbrAmWCLzffildydKo++5c6RyH0pQCUP3gifVIusOSKQ078C0wh1E5ew2N5npBnJYDyaDMgCoO5qtCMO+FtLSSX8YdHADQdmVd" ..
	"D2Cltuqm7H90+LBJan+c/j5tQXQFZ+utVshw5RIMgTa5GQPCdsxUd1ave1GtbjLDheWmjfbTzAtV4yO3mEtey/zN+fQTUvVAg516" ..
	"Gbcx8YJx0zndzscX9UhGMeCbGOSByoHz2cp0r0eKfJJglAiZWH0pWajuJI64od1CcikVtv+nJWkAgT7K7l0yJjplO6VufsS8zAne" ..
	"OD93AFsxHSD4Zy+9XAviWDM4zO6BNKjGOG58HvKEaSTeJ1JhneGKvuUE/fIFzNOrkYUCYdf1PqFnWOzkj3AacrPABny97SnksoWE" ..
	"MpQsY9HH/hvL1LsWtyNd/pp/vOJigNcOeuoe6juHt2bYlpEMxdEBoNLZZHJVhV4+Mgb5RBKDN4WHuRj42keaOmVAY5TVReHa8PvB" ..
	"lnp2xdsBLOMvlF2zKsoGN0ioE+Q/W050K+q/Sio3O0sKdZ7UVzQ7YfZwCFaqsG9ZlRnTGA0M711hkMX0jhBWD675H2oq/nmiByAf" ..
	"diVV5VSusn6R/w1cdBbh6hyQhXIJ5oANZnhivesgnZDCUwwe0I51Pyt1HIscNWi86v3Ut7BfHu0nSIVpHe+7iVLmNXFaehNxJCCA" ..
	"sFcs9Fd0KgVt/UijQh1D5snXk/iJCnXuWDedskRH3HKkiU92qsTb4AWdZU4wj06LieVwGiYeB8RzabDs1h3TW6cGp5ul6vUch5ov" ..
	"1DN4vHhR9gg6k7QOwSZ60nVdxt63mVSlTooep1ZFqbcNJ1/pOzBG6cRSDQx6Z1IsDu4xcEBR3D1nFiDC50DgkvYi1JvmmoE+zY9y" ..
	"tQS9utORJhsCNOZ0LqkWZrYQNekBT5fLA3Fd177s2QkDDJLzP34Ty/eo/cKXuN1G2L70lyPlhOHOdPf7fzfPb43vugKhynI/k38O" ..
	"S93gCbTfmXS1i2deY23Vb040s5Tnr4MJEcoRVPBCFRsqhd6XegAgg6HKBWjTnWnH1PbL7/4DjCjwuOK2xWOoUTcBk/3PZStdtfUr" ..
	"EkcjoRq8jaBAMRYeYYZrnmyg6yJTfZXGn2i6DJ/rxDHZi67mx0BBN5yjVeaUPw4JHDj4cPNHvwBM1Zh0R0LcSw3csD4/hdaFMJPr" ..
	"ePJ/qM1RGKpgtZau8ZlpnjO+y7ZhxGz1aFzGak1FnKNrldXB11rRZoJQQfbAYbTrHRbpRdsbFo3wWcbLfMrvhNdv1VAoUhD/CE7L" ..
	"8TjPpDPKq5AyvdS8Qnjxk6fQf3vm5pNwYM8GocvH9gAYL0HV676q8LBsW3TJQtAjlq81uIZ7FdBZgDHHrIPB75duc7xFbmr7DaYl" ..
	"CjAZWU2x+no59a9yGevwzMOkIzZYyCQRQp01CXDVuao/Gb2RaMlTLl5WSOA8F/VlwfFO8VCpp5Y7s6E9eTAX" ..
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
