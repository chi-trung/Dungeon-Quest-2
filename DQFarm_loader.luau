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
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/145a6739f159a044696cb11a5f1e000bcb7a1c1d/DQFarm_loader.luau")
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
	{ seed = 3874345052, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3868569674, exp = 0, plan = 0, hwid = {} }
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
	"vYpsMiZIYLVlkybAkXDXxz75gEG42ZklNlFsANz9k6PHM9r2kDuBQ/mrlN1D4doJVYoSWxMcL4AVn5yYozVX/Nj27iSb36e2SPDM" ..
	"v9a5yxg3itlRSBAIRSf2owBfUih+cQfNZaqRWx5u4hlT51QxEnKK+FRaQuXzbNoMKAyWFoaqCSdFnbPKv1zc2eLQ7d3+nSrFBkBf" ..
	"k/qieAbrFgyQAQtLMV3bJiRyftPWxrGYfy1vFhH5gf0R0iujv0mgc6sFeSgLDUutx2tD3+fQmpWsc45rBpy3UAmQ1ta86iYP7GJX" ..
	"VxgijVhcGr0IoJ8S8BIIxm2g3JIKG4Q6zNuOqRTgTRQdtaUE7ZfCPiH1yBS+MjvRKrnAybo3FrwpEKXzSsC88cAedcOE+esk5dp0" ..
	"YlbG1g9cAtXdVfgMD+nHEkN/7R/cTstWZzB8EJxtdLVH0sCrU+RJ2F3w80CGntkMXTaYbbce6kQq44onbHfEuc64X/vYpakRXp2w" ..
	"gU/tZaViS+i2T7s9JZ2XY/Is0n6fN/ZWt0rEGQ57wr/Fel7A0q+Jn1V9e/mSr2sU0umJSZSf4Imp4DhGuD5i1JcHfFbDJOGTVwok" ..
	"fkyKzLkZdda0RpHttMk3GQum/XbgjOcxScxZNj2Zz8g22eIAJegQpZFGyqUlyHAunZCBtP/supA7pDTfexYn2ohkA8WLSypvkSy/" ..
	"hiU201oTAIgX0esSWxWSiBJdHQjWGwDzOUiGcdPulZuXFMMb5Vuk5gQg4PSTEnDcWGi3nm2YBy9rfpcr4HD+NvZoMN468uuDa5Kd" ..
	"C1bmqheNj//gSOHNdF3HAoGNLOLGLH9gI8rvDq7DkITYbw0uGMdrW9Y2ld1CpgCPowjPB47ucY/uzlBcokWzj+UDpMRHgzxuHMw7" ..
	"ebZUnEdP+BPSipFu1sIoJLUCJD5Yc5vXHy5pkTbThnDZPNVRrYDx4YOfzPHZdx7lE0QTBr11AUGKK1w199f7660ZFjjUZYHjiC93" ..
	"sKBl10eGb6Hk39FRanE8jX0Ai9OW4ARCVz+Vj3d1TcLbGwfcYBK6V9ChQ0puQAsPduqQsjZA8UooG+kS5QPb63ylQrermwvU9KYE" ..
	"7cX3+LX4Mw+RSOcKAwWGbOB2Qi3lWtIyl+wxc6fExZq1G6sSeSm4nT4rX4NbI94INbUCrjhjz6xgdBxZYINgL7WL25ovmkfuxtoD" ..
	"ftLzK+1dt5ZpV9mw6UtGLxmva28QCR1zCUCd1DR++qh/WnbfQGfEd+x8YmQeqTPI2yJ9HjtkAv0aLCfuGVScrgLMKJHYvYyZlq5o" ..
	"G4btriIYIV0kl5KOuy4Jtvxpnjwr+fTyf0U7Ws7K4lcwTtX1h70VDHLt3NgIBK3oRhTKUJlNprB6fM61T9BuxujCrIk2eRdwE738" ..
	"dhVl0yDvQouhPIo5tBSIaqY9HwIFEBwk+cftu55kvfJ+JjMxbLXQhImpq3eRqwmMzA5VjWqw/k00BZHCDcm7iO+l0HsH/4yMXWhI" ..
	"CANUqPSaeZAC2FVIy3Ty74X4p4Szvh9NdfoZ5G6NMQmjWCBRZfvE0ELIN4hnSp8TteD7RWVmcl39TL5azlAUwspwnejl5t092VpK" ..
	"6GGzaUUngucAvPXA9rw8mSDzpy7bQscsKKpSeEFETI8/1Lm7EdHQRmayk4X2QjZ4Z0ZCKQoCEUWA6BIxuVLKD74zFoSZv8Lk+RJv" ..
	"TyTjSOCSTwmcyS9GGp9fmiPeqTQlitxp/FDY2HRnob2aJrN2WSftWYPJfYSynO1gMX6LnIN340qm7VmlWLaI76AuZk8m1SvdN0XU" ..
	"4qmE9AOfzRBFfgBcFbMHsVeQCX9iusOU5/3J7hY3t0uTM+B8PGAs7kEaDpb6Ed5WGeRvoOh60kHpd+zePXLJPLA8Na7/0Zz4xgU5" ..
	"AfOFT7+K+B5d/LTFgHN+5WTuUlswa3Woyoeb2INKIiBaw3jlonJnkFqS3qIk42u/OvdTtE8oAx7bvi8qtzo83iH58W5TYSqj5xgv" ..
	"bd5arSVHyWfdbUCjHTP4uhm77uC3HpEFwiYV4XtsEdOhEn35LjCbN4z0JXSnfQH3KnDUIR54jA6uo0xvVcNWvy7tefs2ubQHdJvA" ..
	"lO3XPeh877mWmERCw955DesMJzNPuZEFYBRECY1ENbv+Xt5Gq+TkKbM8+Q5bltOtBJx8FVwJZR/jBrgwnrMidAfwtx1WMDILWKs1" ..
	"3aQk9eCBLgQZP5b3niJ5hs4QLKmra4xTt0Q9Je94j2QiKQ5EdDcWQW/JLX/isJMP2VCe+aQQgKAR4oysSae9mafw0BZmj0Mdr/ro" ..
	"09vkN/cKSJ5a77aRn8o3LdNSyZ5vNo21dJ06/q7BCcl/zhncA+kWmGppZooLhFSwzxkKNjfmRWE683uRO9ITEVLmryiz3H5GgupV" ..
	"9nsW+3c+tnx5xf3YuYCsO+ytGRKo9zxvxDRMTHEWi8DLarqeb3HGZTav5lKBsxMWsE8qcvJh4fvt55LZc0wXOScJmJEcRGOX7uSu" ..
	"/YlKXfbLZl1673cpc3Odzym58F6t5YmiGiMxpon/nTt9c82gws37a8ZWJrL5ltSUCogtIu74PMW8K4MgZXV0PDerzY+S9AtXzTLA" ..
	"TD/ffvaxmKORebYmV2tN/wzIxsLZ09EYKlnBjbrkao+1Ju2NR6I0e+sXWofGxZdXzYbuw549LCb6mGLXd1wbWloPzji37b/Kg53i" ..
	"CbZMseS1lsJL3PwoVVz4hFqJyJatBMR5D6PQvi222elhZCRnSokEzrmLm/8a7QvV0SxYyZx8MVgOjn0gYRcw1UhQmkRoop0NPE2q" ..
	"YNhArXCQeSKPVFquAr86SQubY6zZ+XlxlHz0ozvviaBKaRS3BT/T6bSVBYAj4ijIncybIzs6+YnuouHKqUbdNJTLWOkzIrafDYo5" ..
	"rXfzwCtqSS+ugDSHlW2N3K0KdWAzNNbW3bdgSz4fI+MT0X8tOFnHaohVDYjBsQL/n5m0LHdHUbUMOOSNupEcL04apyXIlwC2stZ/" ..
	"7PR5JStUYaoo/qCNvnnntGlaTDVFZ5382hecG46jUZ0ro6XMHBjj+jilpLa+uQhZvi/pm4a1w8OxljwcXdRxGxe/DL/A25COftZT" ..
	"S7Ie52+S9xKQpySifk8uSCEhpxIqcgzAatWIkvVrM52RPq165t+VCABeJUSK4pyYw1VcYlSub//URkD4msD8oabyN0mlSvQWkc2o" ..
	"ggmvxC6C3CaxFR6eclwpdEnlbT/sCd1Bg+lr1SeeAZU2HxXjuBubM27S0z+p1AU+gZebnaxb79pij1b9WvyGg1SnymxrqHPIRyh7" ..
	"f+SbxQQmTy1nCaEp6SfUD8S42UbxKZxQH4UCxSaRWkhP0mtJASSVDTfYUlGMqYsdiknUyezBnYwykfuOP7q7Wk668QQHyIf4dAaP" ..
	"JHqaiFK+3MhvtB7lS/1iqNluvtOjxrEPuSAkrNAQGo44KAfk2TWFEKzd5wNW+iqFRYPXGLLax4yWMssuJQ42WoFbuygZn0XqV1VG" ..
	"f6/CNl1a5zKg9EVkbfEC/OLL/wU9Vp9vD+OAqnOC7Zm+hfk1Ppa5KdumZ7MsNOd8Voc4UtaqTKnCKnM9mOdvHPWcqRHQcLO3JvT+" ..
	"cFYjKIqqMXxuABiEXVGa5BuKdFLHLkGmE3vgWmh3LrxmQ2r9TxpsqCO4jbEkwpUVQ4sws+tlzwu+cy1ms20RNOGX9DW7UF+IAotU" ..
	"gjyKE6w+Q8NuLId3/WQOsvP22fY23qZWP4295ma/lTdxYX7gknRnpiQ9k5i5HQVBNxS0DUDz7Yx00EvmkjiXwxa7mFmlDFKT4hcG" ..
	"sZeIGMO3488xR2CsB8dreqjAp8I2fzE7yBldthJGD6lKyFxw4BO0dKGs4b1Fb7YzymAIjWC/YWswkCJV0I/97YI/yDmIuSYGqDsW" ..
	"gukRYimNmYqsXABjFoo/Cr1GWuL3G5YjPhJowdWVcVNCacRU1mLbPYtVWyqs6H7lYQlULjUvX6QmRy0A6u93dU2HCSICXLhZXHyD" ..
	"exbLjuSH2Fg3DcWPhazPX44kmjmKpwee8v4owngQTsPHDFtuXx0qrVYGgjiC2aEnpYHoDMVBB+vpRGstocl8d1YV3TxGzt/331C8" ..
	"OALbi/9FnrtiswcoeNQOhaUTlIkmCSKmgvmWxn4A3yXsCgDCIZf/VZvucTWFytPfFEZg+7bYu8u+qZe0Ya994PQj/AI34GLPcJmz" ..
	"1r28LyGzgDmFQwPAWeVF5+j2tDR0GPZ7ku5lbg9MK/OToips7OVeugqlIfAKr8CY3PaJ9fbBzgdgAVDr4nMjv9mwg3hpe1Wm8OqQ" ..
	"P3bBlMCqXe0XrwjkAZbdDFrUEL7IKBX/vXvsM/qtNOD7oU0Rxjle2BdllRifSW3qzCD1jFqggZOmNHIAOsqrKPmqjSM0S7TN/S8c" ..
	"pbt+jSPZDBYc/vgw6KF4t3hbQQlb96CXg+Uc0p98gThO5pmcgeG6zoutKr6k+MoVFBBy7JyDMcSUIYyqY9cLCzT41fExe2kmJnMZ" ..
	"IkX6zBnxenLtyqsuPq6aQYx5I5WaS5rGLNbQqjf9iflVouTCSXmEYlg4D2kbWn6+PQh87lF7Oc2m9O2VHR/RNMjAgMk44LY8GRWM" ..
	"Q5lmkMYO2PJ3/ZtYNHK6SSVMkKfjYj1tXBNBHRNWCaAySnslSNt31/YoilYwYdprCGWSfiLC5bo3kxNfvkNO9Nm9ETcYgM3Af6dG" ..
	"PPLYbp+3rH4sKmkxTF7yu113oTmzrhRSvHPFqcBoPjEenM9fYtm8+Fs3x5ilD/HXm2SqBmmDuZPeJczPFZ3HcKppGGBan03jFkcE" ..
	"wAZ+GnBaQh1WFDJf63wu8+EPYguNn8V7qOoZ9YGG7h0wknyecVOi0LBEpclYzLmdTWBnWy1ZSaQV2UdFIWMxjMljmQJVeTzGF3L3" ..
	"KR10mIG6LBuXBDmkihA5zR2v3kMaAliRL0XO1ZJA4fSFKCbx/SmU4i/HOYq087iyTEriOOznTijUeKe38KKat1KdhIXk7FDS9JIj" ..
	"mcHOMO72a1PJjQ90JBCWChGxShPPeE4JKTunZsbGld7sbE2P9Xl9TCnbWleVPtbOFT6JEMZ+OGGi8cyQ8m6POFnK6QEVtazrhVix" ..
	"hFGHjJyoTcMpjGcuoyQ2MsDCOwqBtM0p/jGZnfjO3KuK1DcxV44sOXSU2wK1l1YNLbTdxbWba1HiaP5Xu0IZlbQXcoxY3euN6NTG" ..
	"cGnIoAS87/kCO6+Yfitlgsf/S9Y4uHChe9NzT2i8SaS/W5FMpL/YDn+UbUEAK5hVcjswT/sfCHkVcZ+ly6HjD+fvLFmHYAXZpyRQ" ..
	"K3KQD87VldrruJNWwxC5qVf67YKcghWdmsKLeY6t2+e88+BvZ1+hDHvqIpuxv4hq5rLBOHhMMOxssrl/vw4ycy6HyO0ZubOyQPHV" ..
	"xVx8Tr4n9UaAoqwsKRTE6W6v4wVNv7Uhw2YGUI7Y4ol9+CwhNddqcjL2AP9mxN8miu4LlMXWNxdWdG2f6Jr7bjvVb3zHzqy77o1J" ..
	"bNMn0+qKMgoM5S1eGlZZk2eLFFmeo6eY94oWjxdNN9Xt9vd1fVTQ4JTZOJ//SCwjw2RlElgRf+XokpuOn0a3t9Dx/y+chrqkR7yk" ..
	"xYrxWyMMHRttT9Y6L1VCPft2vuTJGSHrzFQoUiVveswtPr8ghDW1dYvV5UdA63nCVuUX2KyCxbLsjVf7gruhTYNpd8DSCAPjLxYF" ..
	"jpyJFQ3qshiNDgeZ2Uu69K2sPERzlAhrj2dQywbxRMs9Hyd7ClE3YoYVnH3+cZERfm55iSExwg7xi64HC787GX2N5Mr5LTwmH4L5" ..
	"gl1ls0QUGTTcj2u7V66x5KADQj2Cbu/d4gZg39H6FGGILWhHaT2D8F+Nko5ZB85VCPaofITWNlksfMZ1r8MkiYm6FeG5ERtvqysM" ..
	"0+Ehrh/e6flwq6NOby3smqVLMinNWq9e4ffbOFiFJWLyyaU8lUX39MytrQo/Kl+a225yA1Yk8mT64+Nqgbx78P5DRSKKXt83BRT0" ..
	""
local PAYLOAD_P2 =
	"n5E6O/GDgkE/l5FwUdaQqftw8W2Xj7/RzepBZxePBZja21as+UouVnJob/yKsaaVwNS7hghDI77rd+AtLwH6CfgxRmx9Sybo3m4i" ..
	"ptQR/3xjaEPn0qSKltiSVQQG6CwgoIqdSwocItIL01mKpNj2S3zQb8XA2zJ15tJfxqO+4Znh1Th11FpCkxB4TMx/Es7jwnAyKL/P" ..
	"6eL22yYnjOuBG43ka/BLwRqCPy0dpajqXBCCPmCxwH+DEfGr6nXE9j+4hSr+wNNd8nuQI6kMzfinXpXUmreV1mUnvUbeGa9Cw4Mx" ..
	"KPaiybJCL66t2gZ2PzQAiq2AT/LHjHoGEXlsZHO6oN0fyKbh4wWRpO09l+fSykkLphTgwYUtNwtfVLh+w/FWo3HNLAe4TxyBXgU4" ..
	"MC6BpNVWvGmab3AJieMRJ/6JT3m8UyClmNUcbLD8i7HuK30o/G0/vlec0Xr3nTWv8MO+y57nGDvuKbuPHohXfvudbEjtNHgV6JrX" ..
	"b3k7PWI+bPYYy1jbNgMQq/ldj6j/1EtM+Lhc/HfCEkhaEH1GIi94bQ/z+KjcLxOVw1nE8V8cSX+Z/FRfloqOkR69xprzmq+wLDJY" ..
	"6FznYx5gaV8kOr2OftKoF3IZbQF0c7zHxKSnuDNPN6Y5vVmNayyzn+JUw7Q2pWNR4MjbbaI5ZoedT9yGU48HNq5y9nVFCyLS9COy" ..
	"UHuxE3qZGxT7CQTtoMP3fcLk/2LDxS1/ccxtRmfZwU+mMyI86xh4/rRBH+oZmP7X7ZP+xdnOd+XUKVs8UznveiD1iEd84Ij8nJff" ..
	"skf27RjSRL0an00VMc6ebdjcZIYQofIDpYPllnwYmfTDUdHk2vupijL+8WwTffK5rOo4peq12s8dbRil6jbww6BQF9p3ChwKRzzt" ..
	"RZ3plJ+jiLsOPKIoaGTCOdOg7NooWPmxj4FKmUEVMM3pki1YLauiRFdhrgzzYsesRQ2PmSOjPS+h/RhZJfEE3b9tGGdN1wn0lS02" ..
	"O5sOne7/6nEs0t56dJm7CdrtkONpcjG0Iz4R2hQAtBHFgnX/GlSeBbBQp9zIamyOwoQSOscrn9NvaOkVdRicBJg+Xng9YySe1q4q" ..
	"K1YCdzbg6unjQdBYMsPWv7ZR1Af0SsSW1edux/hDNI7SiLix74eRFO4Mj9XuXrKbgTHPKAlpDmR3FL0UShOSXIPIOsDaE2s6rbZp" ..
	"MCH3bCdk+kyGlW9SUxjcs7eCoyRexkSUHIFeYhoBR6V8KeVrzoz7bMwRSCA+cSxkC/FDG0AMaFyeH8LPqzBXUDgl0UQHwyxFxGvI" ..
	"pwjga3Z9FNU8dJLrCgG6BedtSXBzQyLFwBdc4eJuI4AdvF0i1kLdjG1RFM2GJ4+mdQUQ9SZs4wxi2nRBEv2HxzmS/XEPzxOMc4e9" ..
	"hfxJ+5mxgNFZ7S+1MyfsU75zFIyPU4TgWDTiNj6Ci3Lz36x7fxGo90sOnNzxnX1/IAuzLUe9bekdhDa1+Y1hW3U9suutUBk1aQbu" ..
	"GwoB/Zg4dFfY3i7bPG+YuYbTw8mdtTsUYm9f1SrUtsHgANBK/kxfCyPvklpqZmkj7f4p/xM96nlfKYh0xAWqTThTyJ4qWCtGyZYk" ..
	"BzqSQKMx5ClJ4kwPEZTlGpS5OcRFqnO5HhUeeqwVxvYMADi+UOoeKyc0cFKk3XAKDZN2yVGtrXKtg4bosucG/ESMgLPuthakOhf9" ..
	"thUp5J3DYSrwsPghCfM7xkSrTmiiigx0hGcX5JBlcgrbdOUNhqK+V0OLBA39hoG5FjDRxBUSRQkX4cwX6QkaEWKnGTc5o1YjYy6f" ..
	"oq3kBeOGjnRyVLgun9Kcn04BrvMbYQ3alXxEW+BuWhAlrrM7o//dIqyG6G8IHIMf8z+Z9XyIY1SCA6QRNHNtbQUK4gJmnzQn9jMD" ..
	"xYFLDDJZLqZxByKeA/TSVx1ZE7FqZfdt+PnjucjpIZsTwfvOesZf05tBcfudRdDKaFefSSvq+LtjIKJa1ZfGluMlCmHIDs2VFjQo" ..
	"F5m3z9kjrIbpLA3sJOzVmLLPDJRJDNse8AKR4GPNNeTrJJDeR5xZkZzE5RvKqqWLeCSl2azi2i7GuInl68h+6MZb4wSXE4oCn7gg" ..
	"JDydSD2ALMzGUxlmz4jGQOdke5ZI3M2k8dCOnTI8G56fi19g7+TU3J1pC4TNWzCF+RqovUpgd5dfEDTj0B9Klbdw+RuxXVtMvCYK" ..
	"tvR8eZrKOZgHI7DC31ad7sycP32XQLz3P94kHpFuOS+naZFEsK9qhXISzzj4Iv4El9KuQvNKXVL9npsZy01tkyoEyNjYJyqUJF70" ..
	"NbqwoVRws10sGeazkxGv4GS2uxoGilbBOBOFqvpBvPnAMtWaUifdd2e82RG4LupHAh3KgZfHIHu10EufYLlhgz7MX9tMzuEgfNDi" ..
	"a7sZNpHTVsWXRB0wCFUqK4YGm/PPrAFDXsYpNh1WFvdIl8/1+hXEAXeGZNFRUtPUrujgXvmFRaY348dvNBLYPAcmhv+scad41UKe" ..
	"TwhV31w6pGaGW/aXNIWDep03eFhYmHtew/6tjKZNALSfhh+AqKYjZRMnsgJReG54ok+ipe7Yt8eF/KCQKKVHcKoAU+2iV5esFUui" ..
	"oHg1gk6XUmr+IJrQAuzz68NFP2SStPEReYeGocJDs7GU7g8jr6Vy1lhDpsOlugd1DiC1li2rkDig4j1M94FW664lBO0cjAy2cynL" ..
	"l8KLq23Xif0+ZyRCl2605Vxp5bVxbg6x6P4ITBDcVbLvqT53rw1n6EoL1KMwrKY9wz1Th0jz7KrbvLipdg5KTvF55TXaH1AZdz0N" ..
	"wlUSMmSZgRT8SlJ9ObTX7QMEbESbHfXyA/vid986FcyvWr57liNjyRcvpgfwxPU15716K4SBD8JTH1SwTkZpO5boadTvjubvFSen" ..
	"lPsETKG8gjTc3bOL4ylbt8pH2bns/8hhr32bQUR+OvtwqrPmyOCorMbT/UlTvejgPIZuFvQuCcj24c/hmP6d2hzS0ipc3BT8lLAO" ..
	"SSuAGRpiQ83OcfkUsw1PbzpoVpdaJJyPfZn6b+gXMi+qNuz60LkSuA+GSSHs/b8CfNnSjS02BN9CLqnlcI+GU13fcCWJrxVkHtAy" ..
	"YaGwUlpzlfENIk3h5o14BzLbWiJDlOrOvG4P5h00ryzRcRB+8hUQMQcRk0WfuEKzggsyizfmvX+A/BDCPrD87H9iMiAyfUjrQ7a4" ..
	"ND1UUKT/tL+4xhPjkvl0aP5EmYAhQVlp1SPKmMD7B/FFZBgl9+CGmYCYo51HjsztftGDjYSF5pfgyoLjMIuZotcED0QwEf9TzrBM" ..
	"khO1ITkifo9fNDfI9gnsScoNBIYyYTVedPEXe2nqudaghlLjKSlF4dxmeTo0tjjWfpQBpEYX3cByyuCf5VJ+5QqQojuKh7e0ZrTR" ..
	"im9F3SyvQTyKT0W8Di3vcMfgBTLvMHCoUacXT9JmnLRlVAl+YBNJ/O41Yul+iMgufJcypFZYES5X8wDhER7VFeVFC4TAPVt76z5j" ..
	"jKr08QV9Rw0bQKL9b14qhcDnKh2K+1M6bn49ewZywsDHAQpSDETWFf59anc2z4EGuRNoEqQgAeftPUKvyqj1LSp6Hu3LDJSRfnZw" ..
	"M8UCep9LUGsM8Si9b+QPkTZpgoCysRg91YUDWCG0mGZZGGS6983HC0BQoNsf6MzCzGE87MNeJ/0Fo5NH0K4CBar57Z1NQizTcJ0v" ..
	"zGFK1TS1sjoUg9MR6gnCCGtKQrwOdufjRpGETzkc5PvByoejxa2g6O50v7Z5mahYidqcpNjFCdbf9bxoaddAGCR09+HSyJzw1ZtD" ..
	"R3OqXxtIMq4yT7T3C6f7pMn1H3RfEUgGYL2kROpvF3Oidx/JkjHzfOSPLWIj20w8Z3c/hPKKQEOrggqlFA2BSEbzd4wtbUiyjzOl" ..
	"wVXE3u8Rlf/7GO0Rq/nKHAtcPuoQIrooBgot6Z6y4Nd+XkyT+dOdoRdBmybTg98tNJk5RMbuvpM9CFNjGD9WFdnIkbVOlYpxK5OH" ..
	"lXOTv8Dypu9Nccr59AGgm6yDRuk3DdXovY/99WNUPXYmctADiZt786HfNkjCIMx5GhHZq225O7IsX4XFrY+Qks82xf6fkrnz4wRD" ..
	"LuqiTLUQnx5IWVRQu9Iw1bEXIIj7SEho/jVn0fXHGyQI2gyBHZkxrY6oUfUJyfLSWD8OPNzwQcECq85+fM3dz6zS7f8RixneJnZW" ..
	"CbsBli7a0Pm7klbCmhkfwxTm5+p7LuXBxAWMOrjUSrpQE2BB5/Mdi8kHqAvqUjZJCD7CErsXbUlkkMLzvs8clFpNI5EnWLP9GPdF" ..
	"EzG/5QfdRo0WuMhK+Gi1i+UwKUNOddxGPq3xvrC6nIaJ9Z8Wv8eq0qW5aK9wb7Px6M6giQjvjdFU49LwSUx4VYZzgAG7P4S1EXxH" ..
	"3cCSFvWSk3NSZO455pw2bS5nYbTOoU4A2vmxAps+GmTRwSIZii+GV/zTno2C7UPzgiu/0NpyBuN/KUdRT2jnT4zlCOVsG4MHQIUc" ..
	"Nvurgb4xG8ODdOVu+5EzMWeRBhtLDzR1DyYPJsRRGJRsgNR0GC1pWGL7CUdnxVN/ZQurvWB+Km65yybZuP7KU5v4IMuEyMneY/zv" ..
	"4Ppc17RYrjlTE0ba2JV5rjtZimcDQL0mdhz7DCChTuIOgO1eBrSe5Rmn2Rwx2lePjOtUGk720wNitBSwGw/p6+2HnxzPmbSiXGkS" ..
	"z31iIfaWtp2cQWASdJzw+vB4UkYEHQqUmbh6TU8JxKRs4YdRtJuD5AtRws/z5oRXDUsKkyTxYBKrkisJVGZsxXX4COrUT+eHN4TH" ..
	"jSRzJr7vfhs2MPVDCOfCDl5p0iTDqpAnRdjZ+qjXl9+HV7pZPZAuiQzwi7WkEAABQkur7r5D8O6c9KEHhbgE57tmcfPBbM87SpAF" ..
	"jr2Uvf8L+QajZH/oOwH/lAqYsZxTHzXIZSwhlK6yTRVonF93dERJDJsOSyo4KI3N/xu+JSIjPtbXRc7fYdDwevIDx5LlYa8/V1/c" ..
	"c3VFMwCL06yayToa0ncUhzFTEgrWSsZT08AddUzk3Eg9bKb1+443LV6segio93Wr0S0VbSIJeww2nLYY5CKEbVEBPlybli+ao3nC" ..
	"anLYhSwZEB/P+gOaUnUwagSpRDO0qLdsEbfCxklu/SlW/6A5tpvszHwQog7+tIfgz0dG/xjstjXrqPmI9tk+vqx3hQ0DrgV4zjLO" ..
	"A9x3Vg8Ei3wU4lwVeutfBfW59DaT0E1QHG2ZS872bHxTmmvhzhUYglCv6C4VIs5GzIU1kktkEelA5apjdMi6SE5arOYnPQrlu2Bk" ..
	"86byrX7I1Qqv21hZmH34wWe8UFQqwlWZjj6tvLtJitIo59XmvHXqg90yu5OgQs1xSXzzxR2b2xcjMwJV+mFn66XpJ7hYModlLwFX" ..
	"KmRuc0x2PZs/EsW3NF6iSLSvyrY8dkd/+YOabe7mpSnP8DwM3foq0Xk68mre5oAAVyfxLsdbaCp7Of0q5CArGtS15JMqY4gh6p9R" ..
	"BILa0WbWkc7GnHKij9ehC2Rz2X9IFWEIt+j6Mdyh1a0/ip32OlGXQ0SGEJnIWalLHoP8LLvZAqmEFRZll0fUVb8dgZwzFIaKbla/" ..
	"bjhlDnPYKO2HBTNs4pHHNwE0MshBFBbS90BnlP5Tyu2rcHZflXCLqZmRECmVUhCMKwceAGqlBBbAwVn7VZEw07TmF+agVZWdyCXp" ..
	"YaPVKOouIYpGeKAYNS9x8FaVZETymaPBUL6WKC5H5rn2yr54hwRrLM4Sf2nd9mozHs143aZRq0d6Z+8XIupkqEu7m3dU4dY40IRw" ..
	"xwtVfbONESrvN/Nq7+wPofKUP0xsPAGWnzqGIPNO9+fCbDTvJIcjMQjfzDzV/HobX/17fWwGpENuAUJCte8lEJdrfObiKZlZjl2H" ..
	"f4RfHkjPbHez0y9rONatQtEcQY5uS4WWGhdOG9DyVuDKWNTUJFIvaVjGm1Q7DyTZAVZj3ssRvupf7BN5pel2+DvUIriELNQ8w9ae" ..
	""
local PAYLOAD_P3 =
	"EAFkDkdJ8V8W7ZCia2pNtl/IKhlAqvWhDlHpSnWl6w/1WMTwCFqEp+oy6TLFJfj3Wrg9L/WXRci3ZJUquaC3I830TeFKgirl1ODq" ..
	"6b0nOy9OX3OBMejEkGKi20UofWnjaT1mFnXyjrGrgjMbS78viw/Ug3pblWikUuegizxwzz4QWgqhiF+iO1CFnzz721f2G2KmjmYF" ..
	"9IxoVhHGjJr5v8veoF+Z0uxg2F7KiWkl0bfq8uNXtgBMU+hv6cmwEy1dnD5XYDtPXvAvLtsrBppL6+Lksz+7pqAiJ6pbwC8KWrI6" ..
	"VsO6ZMLCiwTxx2pg/hFIwhgCm63AKX+OcqP5x4NqIqUs0+LEuX9VEFLb79kEeIG5MQOcIO6/SW1HYyyUDvOPUjNpCNphihBchzBq" ..
	"T9o1Cq/BFEg05qo0EyNUX2TXsmAsgTYfC+FuQvX3hKlvDCJEzEZCxxH7SFWbqulCT6CGAv/H78iEQkCTHKneD1+F1M7s8ycEC/tr" ..
	"B9JXmAaNaMZ+ZVQr9YTlSrQlZolV0seYE7b+5EF0H86OZeqwfasKWTWRrhMRuSN55dptZ7mUzMGAp9uYIJuPN7SX+2SR1b83mo+7" ..
	"jc2GPEgbPIyoHHL3B+uw9eDS/DW697OwiCW9Os7R7WHnRsCSDdoga2co4Sw+FWJmPdnXmzYDetmEeMDE1mIJSQeOO8T212wn6gTR" ..
	"5XJTfGd3Oe44Aed3+hOkSj1Q7GSKI2FISFEDkzR6rB8aSLHDLznGFheplVYSwkSs0NUpeshCB+bz1VoND8KBT8Ajq0L4e21NYH1e" ..
	"ZpQV5p6twLunoATNQ9coZo2XmD4oggchRtH92vQNQwv+surcyiqra3XyDVYaLMQBN5vVQ61DkqPO/K3KKKWbYOYlzBsXg+qSN3SA" ..
	"rXHwHInWt8fOu9eX8sg66IoRpGfAXtm44U9tMnEoh88Q++ng4k8S6q0jjx+5FAu9AbhwjL83JF1hBQXhSm6Fi11a0yvIOAB1w8KD" ..
	"a0rxnl02fAkZUS3/0G4GJHB/9JcsNCkS0uXf+ASlc70sadg6XfyQGmqeIslcVLKYWtfqnWe0Ba4zuPJQOcB+a0opbLrv9w79TD2u" ..
	"yCDYZJBIOOvsyY3G00i7nlbeojX15n9eEvohLKcmBCtvXwFur1TIN+pawL7t9sTHGOeyrMXdsb2krGYr2cPffuF/IxQEPA6UggEg" ..
	"TJrwmW+uHxSok4ID7dRazpyqfGAq/+wCP2XDB5MUy39wDteVYNjJevYijDhgYb9mnHd8L9QXf5iKgpJc9wCGe9DMXVvWUIPZv1vn" ..
	"/in6N2GDqDMrTBU552REVJujz+kXU7R8LgTpIDSmh3voIq8j2ALv9j1JPpMP3fjNo2Guzo0efVSgzWSoEfVfFO1m8ZoaEisWR7oK" ..
	"qwbIXmgSl6fmzfxhaA1O0Icz1wLlyjJRREtKd0Jmv36Q5pI614dkm/xHvKbBRT/MLy0fUOBnGXBYCKri/rG8hv6hSnhvUZtd1ns0" ..
	"eg5WLdKmYSg2uUi0IucnFyuOG9loN8UJqWXdYGS4TC/cbVJkkmNsfQ90tpqGIwhSGnXyWj4sa+g56ynnUEGZgDsDIObcp2pa9zaU" ..
	"eeLvmYJG5IwJ8ivFmS+7JO8gJKQAk4ip1P44PSO6207aI/ua5r5CbM70LtqOiVEILBLXF0kYEmk5DNIQetidb56i5hu2/y4zuNBV" ..
	"waK5bDGJ18/+AkeUoAW4hgEOITK9w/N6bIK/Bb5OFjlYRSMhl72/OHypVLHmP7DjOh69haYJcOByYVD/rVSm7bt0Zf9HLClmdtDZ" ..
	"fjBt8H2SExMI3Mx6M6y4eIRYogg1ozjx/F4G8oIPN3QnWfxiXVIkZlV3jIa5IlfOOVqdPpGyhwBXBeZSx1PTZUU3844HJ6wM4vCv" ..
	"7KMnIOEaNKtFmLMcUh7ZiSy9GxWJKdLIZU0yuBVE4VAXBnv3bGYX1fj3nf827B3l1ZLbGdDTJPMi3U9lcnDUSiXd5cBcbemrF5on" ..
	"52wcYLGkqLKBl/fQYP1+pDfISrQbcJXl1jDg2RPkuqrdBmQ+wD7JM5kRafVHAUGRTRMQHI88Fq+QgVq+dBS9zUCrrbKTeucJrVIo" ..
	"J7gnKa6U8ET80Nefc5EqnhwKSp9yHc0k5pjp6JgNfyYU5nuwgLVHsWJkDSrUGeuaVjD1mzMu8BQIZ4dOdNRIWX1FfCAs4bmCS1Es" ..
	"b8aapszN4xg3SdOXq0ewv1dv40+f8pRjWtEapClCr/2653AQKafNZQ7QBH1HA5K2TG0LT2/HDn0soyu1/Nw0mU7e/jAqnrESqpbW" ..
	"fOKFBrIk8+QHq0k4uet9jRLjyr1O/lS2rlQ2+g0dh4xyG485w34tWvM0EaA4XKkhdU5Je/pq7VPODBPkxQSZgdpXMd0zcBmzGtdL" ..
	"N+jlcuEiWC9NV6a4NeEwB9yI9esueGwCPiFxyN8IxeyUjdhijib+L700jShMpL31Wx8pv+YjwWCCReSVb8eNaEVz5OY5enq5f0LC" ..
	"x6xoxw5PgT2PAEQ1+sTByybZRiXywxdeAAhEMPZzRcQqtVXkNiHb7kV+TwVsCEpB7XoyXwIP+vyeBYJ7YrVkStUl74J0xmOC4MI6" ..
	"g5XwX9olhgzVKXVleUMfZ+d+QWV7qQIUA1exS/h1X3N5AhRstT0LLq/IG6iGkpzBZocDFFqmLVFrjgA0ylW5h3FYPouKRdIyCxnA" ..
	"LbHWd988AaY8IliWFQiRVuV43FGs2LH9gIyEigkRPklwwCbjf9RrySOlZJh5E7QdYE/hOFHtxA3CBud6vzIkkxCc0gscVspYKo+V" ..
	"YMzuqWR2EGVcUCb5X9UJsWjntjiluoBvM2h5PtTPwt/CVHhMO/PlWQrGRCNfT/DFc5IxouYlnoDAT2/O+8NhSX1O4PKYYE0XfnV2" ..
	"9pi1VFa8V7OZLu7IuTxS0Z8nsyU3pRdjNgOEAANPw97IiCgvXi7gA0Rch2jqN5eVRyBVRVwrIga6Qdjg41r8F3ziKXN0i29IXV+m" ..
	"n7BdjxjcWHjXTqN6MA5uTgxZSFtZjvMYVY85OH3yLPYef4ekQ6YigzSpesH54ilrfhyKAjZJS8yh+f3mHKUaOVkHzXLpLDEpkpxa" ..
	"acWXqhbwKqC8VukzoRZ6dvB7NA/pkpk9pX5EWznLt4SFxjylmZdMfHM04zn0+DdrIoYmswah/9ZNX3fYLlNC2iSVlRroEHhKXhIN" ..
	"CticABTvm/QIjYqvIOJcPX1SVEIKZAMQuneyALFoBCd6yCxoxmC4zjYWp8FE3UK9ZKWwl/td1LjMcFGYa++N20UlRl8Ze06C1fjA" ..
	"LLl/SFbouii56wJoclf1v4GkImhHAuSKBaBni2pdeRLfKaYN8pmdfI8T79JrLDYZTbT8JTD6RvTHDTL59xpiwxTeb9LVKN42rdEf" ..
	"7f/ruv/GjE8D+UqttlUYMNXNN/L4I0yhoh74dKhI07GZz0IlJtKE5R8pgPimZElIZF+cQ7YC2iy73uq8IBF/0GT++fvi5aguix2H" ..
	"vlSj19ZQc31jIMS01wIQStnlY2BCt2yYBWSGMFPaX97irw7QbvN+xlYirvjh6tg3xrKIql1XPosQz4ksByGFJZQu2EJXbAsafKAv" ..
	"poyTEjXLcwDeLp02POSMyEqWK20Mka+SIHdNd78X7RZD4wwnJRovF+PGeI6GqODvLPlTNrnEg4bs4udqdxLF0VcuSKR+IzGpXOk7" ..
	"9sRgspnfz+Ee/KiIQS1DqubZ3y0ny+BGT2ov5JZkp/RysjmEKbAy74zoIfg1ierD6rBBW33UZrsMSxlteeNuuU3QxIfxQG3xK8So" ..
	"oFH56xYagPqo7ZX3UZhcGIF7USZ9mINPevlaVkNWMwqY1rZG33YPHLjdkm6rsgfhCxegde5DpMqxk+SpU6zzescVqbJFDykRDWGk" ..
	"e5YVSOCK14SejqbkOk4faWw0g7IdaZRVbX0BxTeqOWFZ7e6RnMDrbeyJLKsBjKYdmtFstFTfp1wHc93534tj82YtWa3Gu4XcIvAJ" ..
	"aI0dsRNSuC4j9evNoycWmbxpGGP4UVvBKjhn5KQueE51q22acshRoeTxC+Citt+ZL+TA8GnychouZUPMoMCr7coVmUAsLUbiUp40" ..
	"wF1wA26zGHJZasDNMFMm2KZfg8lohz6OrkTDhTI11XjaIcERWG8Rjui1HmcPo7FH3ReRN7Z4hBufwx65M+/5fBwW/tGmBIOaBURn" ..
	"jAyLujH1YEwQV7axcnJY+RaR7R/f/Q4UYn5xANgcsAKmSMbXOmY1ADtVApiiEaQntWB5JqXBR42X7KTIGuztjuH+zV2DAf36pshA" ..
	"5UOkbvUYDdZtHYVI8q/6VqamMbmk9RiZwV/7afKtDE9kkgz3iB81qtBBx7KXELFjbYnd3ybUlLNSSzOkVuJHGEZ5ST5B/DEJWqzv" ..
	"tMWWswsKq5MVujWRhe24+wk2AhsdhyqGWL6fX9Q31vdnNCu0OrfECc4qK1TEJLUB/DzqxaWtMNGe15KheH/zRC+FWIcVJfYZbhsp" ..
	"LZR7zdTgaXwJJeAmy6i3u0n/LC1seFa/9C2+P2qgkRryuVvRsPrIzsgfBtc7Uz0W3yA/d+BuqPhVicWG+KcDWMLePT1Y8XCYKcm1" ..
	"lYy0Fc20CN7NKwrrT+gKvk/kTav+omYQ2iM5boHl3YV7AdMWtvMTyG7HXd1hYeq/76sBYTSTpwORzjPSHhEjpeSoTa+GIbSC2QW+" ..
	"/83BoPPGbFVwT1rqAmPbLJdMxHOVG2UU770bhmU4nRomOVJWMQYjXMAbySGMbDxU93SOewV5DOYtSxsRPOYk+vifooOXt0O93v0K" ..
	"+z1pi3fTy8xArpOLhBEicbc4yYJ/4fD8UpU/LvWebSMVx0WGilnvZov5ZlftXO2bHSqE18ERiCofLX0X2u+MrYZxRy4RCA5ozh3f" ..
	"HEMtbxDPQBK07pj7RH3mZwOZIN2XGvTlD2xQpvXs/l6u8s9293/gF3k6kg7Sbs8h57DKF8QNtzOfxzwfuslZELJ9AZQgg9wNQDgz" ..
	"n9IEUzC3t2cF3k8NGxSOBkX7q48mVGsxWfh0QM2VMs/NP58I1hA9OD4G6hQVolbeMH4MBbJRfieLPGmBe9ua/nRLbDaOwd3Vdnds" ..
	"jnocYVkkaG0eenD1217U2kJtpDtMft12KTtUX/irxc6UJaQx56ABSZZT9wBDQhErToV5rBdt69wCBXl63GFOlNn2A6SxfpFeqDEq" ..
	"abUsCw7D3rw3rhfnk+X7Uxj0OeoozY1xGDXcU9dUmdNW+4ToUjl6aqU7DiB8IzyyLbwhsltgDowLwy9RA+dBbb2864ygsOG1/7XF" ..
	"TMtaOfE/rXlqGHSGQKlNCPiXfRFxJlcJSzLWGvomQCH5wAlD33ENYqXbm92sE4UH9bOTGGlTj6Rx35ccipqRDFY5Fcc1NqLXdns2" ..
	"cUksxhbB0MXMxiHSe4Kxp4zZgnEuFWy5SZboLXIgfvcwevTlaGnI/XWNraTHncbv3MMdUyHx0IAv6wuqlqK0+WMElnhv1q1Q/V4v" ..
	"WhhR+0VUgaphLc59sUVaxnSA0UNVwidvwfJaZtT5/DHluhUoqCQa9VtQCxWiOWpATLVe/Ast6pmDuE+dR+pdctV7LOI1/a3lWmjm" ..
	"Qjw4Tn4WQxUNUvY9BZkT1UhsQEaBQ1eJWvpaLNG5SkbEwfcBWwc8sHcXsEnptPVM8bS3aPcq98bnyTAN13MmSIH/TpygApzTD3Of" ..
	"2QCig4dteUMtQ4xA/JgfEgA7wUw//YTKXU9eyWrgetWhf10KkSofBxd3NMvF4gEioE8wnq3KDbzsUjfnmwvEkT8OUrs2+xcgjMfj" ..
	"8ZAB+kicE1UE/PuX/glSEAUQ8vI3e9zSnwZZf6rEPA4HzEy6Q2GO1Wwvg6U/Z8lgpcFL7x0sitoRTqIVTuowVWI8D25da8EwKsU5" ..
	"AuTmGoV+My73djhr/cX3TnOKcGF/s/u1KSZlAxZGHE1xXQ1/aCUONNkehZejvTbSAgeSi58FxLWdj5mQyAl77Xv3P+wxaJ5E3TBW" ..
	""
local PAYLOAD_P4 =
	"QDidOhIQvw1BA1Lrax8M5m31u1InmGbVsq7/8e2m64v7NIoCkxe6gGnljf0vAptAnnA7A7SE+T2YHSX6QQ0IJJ/cD2Z4sX7feJY4" ..
	"maEwWMz1Ms48nZ/C0qDbkZoAY9Ew9EGCEb5i4xDxr1x75c1wnWkdP+g9qGwjCdSiPfrzFZ0w9GT5/eA4y5zmxqNe/KwdeunZYbbr" ..
	"50AaIIUHlTWNYAn5X98pYsJWZNvVVrn22hh2AmOjiVl3SuMUFlRpVxYjnygd9wFHJFbnEP9dPrcF5s4Ct2260VyYgd6vF0wXFsz4" ..
	"QoVc7NWEbyqVnuqMEucfQRdH8mjeezA/pUTh73GJGjDhUsONhc8JVEx5Fp+sGeB2Izunpkjl7MnqI0wrXCYKBNMmDZ39mgqYp7NA" ..
	"FxebHPVE6afRynsQozyaNQ8QS+WO19TrSQzSGtUJo2w9g+c74yVcuHetqCC4Fzz67y/0boICQ2NEVn+Zt2KapzWfr1nqgXREajJY" ..
	"FnZgsfDsVrGGwIhA/3X2AFUYem3CO/sVUDZl/aSOsWmZX5Ky1B7vAx+R/OPnM6xpwZ32AUSBUu5ChzfavNR3XfBmAd1HZWLWyzMj" ..
	"IF6aJHTOTpZLH/mdIhBRL9z5OGdql9RnDiCSa4N1nrQJ3BnXuml4JSK7tCHq+QSahO+FpNYaMYNMIipvIgiE4HTw3qxvk2E8FbSB" ..
	"UdkBZ6+Id3NNkGlp3LICQTrrDk07/KVdEekg1bY19U3bh5eGt61ER/pee+55UqHqTGwVwXYuD3ao4zCYO08qLWOTPlwLVVvJVNAV" ..
	"FnOgFgCAoWaQ5l23uekLE1J0rPEgWKNwOZ3BLtP5bU9Ssp8TnDN4FfDUum0jZkpV8GGNW08GB9NZjdsWekuEtmGrPW7I5ZFJJdvs" ..
	"EepnWz9TxuMIy4NUE4QYXJEGnGEb0OrXBHuVkvggOvAQXH+kEKIX4U2t0jjL4soecEP3H69k+OwfzcgEzaQR4INJf5HxYNYmwViA" ..
	"qwo97HeWj/mKBOn/tcpX8ohwSJzNuw4S6CMWnJ1tdBjeiqnSjdvxZR19el+uqky3SlnePz85B9Dl+0SPDnjelT13N0lFQygPTzyV" ..
	"8kYbwSpJe+nPh5/6PoV9twliD06s1gS1l62V7WTwPluYrUwIN08J5UwZPZqBmw6lIe8i4VRwZYsjfAzxykmbJorc5k9R90VQlHtt" ..
	"xQ7QEDcjDR1ydcTOAZBG3NxThXUhs+YjoO4ldx1EQp1ZNRVC+JVz2hAr+0dHGSSPM4vN0GwLGvcUGJrIILIE0VKf+IqVCDyowlyc" ..
	"PzuqS1FjN90nL68uMVc/JvkbOp62//iVi6RhoWtKU8IDi6Nwgz89ZFKjCZ0p1+sg90MGrn5hrSJiTgEGmaaMGt4UvNw2InzJ5cvI" ..
	"OhMyIqj1i7mQ0PJxzoL1aWd07VkoYKc5OrvVMEjHNFQg70GFV4rcIbpIzCn5prgNi9T08psoewUEADw7yLRmx0P3VGIDB+glPjUn" ..
	"0dqUQgGoyiTX+uFIJ5ApnbHVOaXrtLdZSneV8IP4QjWY6aUjYHHNozeJ9DV4fl0AYRRuCqLrkXp4iJ/VSCYl/hmnlrSliMfUA4iz" ..
	"aNajW6N0lGEu+AfHFJoBf6qMyYT6nrHgu6JtSr/9cT2f7EkUv9bMKMogHMCgSFsjPAfKEMZkDQX+C3qVue+KVlSm0XrqeYHcCV72" ..
	"u1mV604/jPhl0GKlYWsDrwOpGzHCwzq3ac/c9LT2+YnpZEs4mtcuBK5GOym0/CAcrsoA3/jUnQ6jkfC763Hfaa6tngvioZOGkv2x" ..
	"mZLny9wV6DwHOOfLfUn1/oGBQKit7G5/lwJw4FloAgBO39TAgLQfSsWD2JaDL5nMaMMvET/GH1k2J+sk1WE2Gssp0L34Dji7mmQt" ..
	"7zvlhBfIRHzT/JqjsdVYgjdnNsBqj1XfLOV/nY2dVQi5QC3Da5kA/y8hUcDS6cf67jGfrQgFQDhHZ84TniO6Ernk7P+p9eOCy8Zj" ..
	"8C/mRcK+hk66NaL6c5GIKzF+fEo84JlIUaIsv6QIuDco7cl3ZYQOcj+d1lE5yT4kNxXSj/rQl9OeADewnNsNuISpL8NSB4QDzvjv" ..
	"v/0oHx8k28OiXZfSuLa3docYyzqy/EmZpSlK4YbBGf4CwWQfG7DXzHUG+dWIo5lwD3Xv/PCWbJ99wSE2MXrn4xH3sIjX9is2gNqC" ..
	"8VZQiXIKWPnXdc6BJ7uX/P2XKk5X2A1yeAV5iJ61ZVbWvPHE6kGeL3Qb0on3Sso2h0sO93Q5VSjU9f31df8fmBxLYoWgAFHOxVp3" ..
	"16ylaBu5GIzz+8fZTf/LedG2DPiya5XR+k82VI6Km1tK4ac0EX+ZbfQNkWyNltq7xgXiecFMRHizCJKt8+AsPac1L3tyQ6swYa0I" ..
	"40UI9Ua3z4RijcyZwXQMyFTWmaDNWJ2ynBp5ztSin+IIvVSYKc+Y+HOdYP2e7LVaRiFzf7B5g5HvNAFEwUdRrWJmAaYZyMvaUUGU" ..
	"YBQgNGAvu8YJix8gBhnG7/M0ROr7UGlBEscZlHNDNZxYn6V3JjnYXpCds5q49tSguqSWa4qH8Ujvz9mBcyxwdn1jRGXuufcHxWSo" ..
	"lOWZDW3whkr4yxZ5Nnhx8VE7x0SMCmJIkziMMqcsZsZWcKZYQQyfqLQZtkKS5WvyO3xiox8I/XJjjd4JqrypIq6sDXy5Utp9CJs4" ..
	"JAnHXmnyam9PYkkvM+ACDcbogRpm8jmJKIX37ai7or38t58F1GOt+dGNn12XMue5gAzka/jPpnKCEf6Rc6XMUk/QPO8Vq2nKJFIS" ..
	"K1JBnO5Ahbb/F4+sBls2BEkzYjyiHKhFxl9xF/Wea2YbcTotJDPkbl7FCCjufdx/n5wod10pumMBCriwibuyF+DzKwefJypHR6jR" ..
	"p6CC8KOJE/+5UQOxRuz2dgfQkpwcQmurMxo8MWcISSDIXq98/IYFk0tegZRXe3FTH7ivo4jKE0RgeIYwTeboVWeMAnvmpJV52our" ..
	"StD0iyNTnfbMZSiu6vEKTEQ1iEm4Y9WxjHkz1lal6tq0y95T+vpSnslV0zBsHu/m8XNCa0t2+DjOVRq5ZmyQ4vErOyxeFNOOTk0A" ..
	"7Bum9RgXl+V/BR1Q0iX/Cq89t43TkxrhlibZ7+Nyo+7tKg6ui5VoBmxzvx5/Bh1QaktouumIMkmeQhMFcqDpF21un3SjHaUc7e/Z" ..
	"39m14SuS76PtN4StgnHEFOSvPg+0+yPVhr8qftVE1/ArfiXX9oijeydxs5MvqA/EzsWOn0MnG4ZPtSWdcYUx6uO0nG722N9B86Cd" ..
	"KD2PFyncdqYbHAVbVKZKJIy5KyVnYSiX+dQM4Y6nwqftZ1n5fH1o80NcA4awQG+txvy7+eE9ZYv55cMUuCQbKGNwGvGKoegxw3z6" ..
	"fIA2DlyWiDbgBcyfDnhTHk2sr7C1OocQ5OX/rAHg/Y6+PH+LKDR165xQC8bQOqishvY2L2ekq6fW9kWC+RxwhBUGqeycp1aSfpFW" ..
	"iNBwG2ktgxRTfg+FRJRFSMLr/P0h51Rmo4QEiOdalEgX0l/iIaWa10grmQ7tmlwxSIU11NdAiAs5BY/DKmTNjFVgxacHCADR2Su2" ..
	"zm3TayGTwVgFvOrbJNJpSRpnRcoGsDHs/KI4+JcELxcraxIBluShU26XYiB+0V+eW19+WGeq5uemnIj50BRfsemyHUoDXScUj/ja" ..
	"0NpGZLsDK0pdzdz/ty5OqXc2zX+SxWkkJHGzSJLjwqBtM4unYYDiuKeNopzNNx1x3CXrQiBubQmYhGU9JKefwMNfLbRyMysUzoTf" ..
	"MGavItu16EpCfJse4cHHKvq7xKGa6RmdQFeZUMu2PeGRN7of1lln0jWADcfZWwmbNIRtp2c4HV9C0UFBu7kdyvzmeNyRwYeTMiOY" ..
	"8fC+VGAmvo8M7rXl2+bGm+kE3Rgbbo8rpohI+Xu7UN93jHq2ZtIkkNUuxERl0q2VgvDIgbriEWOgpbHJt+jvGYWGCmGppfa/Z3i6" ..
	"aSXyGTl5D6h5bIuzweFwuZNIn7XqakrwsWOVMtGJyy56sxOZWwcSbkV2/Akc8E0VNJ4/zVykFdW+V96BB/Byw6I6NaMNDe+4s9Ig" ..
	"y0ec5o8OiGhNjsKT+Do2vrTx+U9dPanGu14yn8+EgPhBm1YPKTgx4WGSXXiDHqmixoqM4JwG4QINRwGPsLdNqoRAkxfNKQaSdjg4" ..
	"Ry/w+vuUmMePX57hdEHGFgPBfALPwIoDOMhQsMfPx/LugOnF80HnLHZp2P67UNlsPP1PFLisFSQkkcw3AfxPACQ74M4uv1TKwAzU" ..
	"ESOcrkNQ9J+EYd8dOMTy5swIm6Tux+Tl191J463MaFHj2F7PwsdoowqPftwp4HUiiuuBlmJhjmBhbax7OVnmdbk96aWUk5mdqzDQ" ..
	"/TQ7wP3lO+nJ4ZuhX5pmou/ztMnnD8NIFvYU4mfncrnqAeAjxzE6XH/78fSplqDeQrgKaFlYJFXfbLoThy+JZ5gk+4ys7TVCJ0oZ" ..
	"g7YAEOjHx9kxeqir1vVUGkVDutDVoQOJ4NWLfB56Ec1mTfNZcz/T2DoYyFB6dj6KTszSq9qkHoVBYf7sJxrtT20bmD6wIz7Xq9Jm" ..
	"v2ChosQNLd6hZ9+vrPlrBxf0ojAyXWrFm/Z+2L9LtEBNFw27N0QRrKT7rM4lPYzOW6inZ31LVgc89xMcwFCGcRu2Kzutss6VBFO0" ..
	"XQwRMPE6SCBfZVIhId0WNEghbPInWudFse/vULdkGRSFveXZ5eaGRNraZoXarnn8G5BLEYngoVAh8srb/uld/HeOB1/+Eug2nT66" ..
	"DXDNLAP8I/NoqTCfCfNYppm5+IKIaFM91CfHZ3Bj7hrn3yWSfaj77O22BDopj1xmzvwJAgEvjxXPzlYxzudNhanD6aysRdQvFPh4" ..
	"ksuAZOkcEdQxE3D5UMTl+4URUSFEHR7lgv6NbTCc/64qQ9qxBd3AMrkyVHr2i+hh4OdM9a5p4TaWyW1+yRyX3YB0OpUXxuOjT1QH" ..
	"D0mu5NPF4EelcZCdfJRVeKebi23uWWZ+dtpTzN7Gs+lKE4aC41Qo/m+LfAKgaX7a147Am38ChulXpwMPHnxAwbwfL4ZpNElh/FCG" ..
	"jBg6DPdyuHRyevjQJNX48JSk52YK//gucRUPzH65iUWcdZ9rsIQxrvf284031FW9n67TlmcWevNxtwouaf0uhDzsQRm/2FGKBNHC" ..
	"3UfTjndJOlZNahCAUOECc7vJCf/MaqJFACZCVSQ/WgnnhwoEzXQbmvRuaRq73NVByeFraeZ+ms9hXwR8U+GbzV2XOelSUNDo4JAg" ..
	"wLLWhj4hvlMH30QFqHTAycAGwrF7ofbKPakmv4QtLQkqs2i4GeHkEVQN/HT0tcsiYRo9bZeSVIjU3Sof00tcIl9L7zMFBOLyTPwh" ..
	"+1eXzJ549Oz3kAo4RH41+H+GchIaFYSPGoeYMEk1y0TAwuizJFaaNEjXKMwPlucjaNlcMst6181+i9FL0/jQamGqP0ll2/DpMEpR" ..
	"CVrDGY2F42VaDbI1Fun27XJNj0p0Jde5+QMrWfhGCkVccNxj2apCByfWzs2tW3ocMgA1Quax9zCSRud91AhdUddHpxXxHYON9yqO" ..
	"734mPpmsyJ4XTUbZw7vVomycNDp2jkfotuQfHPWvMqxDtgjHCTPfFDubtnrge6ZDf/NJQyuFTlt8zA2YZiht/6KXI86MHvPgXm9W" ..
	"dn1Z0OXRDrmilkbdJ6w5Ix/7OBxQnn9l1f33ZuS1RFqcN0SCmKoe5CGxE+AQgxl6elZboS/Fd5XOUkyOQ5wk41u9OYJpoW6WwNPI" ..
	"3aavlPw4Y1fubrnkaD4HSXwscMgR96ub6eP3jELGyM+4sfKnPvUSRpkEd7EBC5ACAvcxMCOKqggfEhHXiPptmjGOcTcMNX0eksZG" ..
	"yqP6kM6ES13UmXvseBIaqNveFqDE7S/h4EK4L/CnRsE9tc8LZMTvBHSho75abRDtDvXJhws74slrIYu6sFnTeivgPUqN4SYAnipx" ..
	""
local PAYLOAD_P5 =
	"D3Ss0mFUnvJYATmhlDnRM+YLPoL5lmgrToTZGXGwNRZZqT4YereL9cbwtdPAjm4chMA1L+UBZn8d4VHuSxyyrPwGm7VIP6FeIh+m" ..
	"M2Iyv031NdCGNTS0+iXBq0sMnv5zYV5LneOwJjY93Pu2KOO9vIq0rXq6trF5xoL2ni6v0hr1bVFzCI/Nz+fYBJzd7a/7cIQz90Nh" ..
	"n2dIYx4bSnx9/dAzpUCMjt5LxG2cIxGDEaWCJsocioLyVQV9bz0+Zh+vCRA9hh4CSj0d/CIZ95fE6Q8PA2vX7dtC+nA26pAezkXf" ..
	"K6j1OGYAP2MOKVf21R3iWPx6B40rAX5s3O8N1Bvu2zh11Eh9tfJWOjM913vnZeGTJSflozQF+17ZXc+IDrhdBB5mEgJ6cOZO4FWJ" ..
	"abynCOvBAEn0PiL8/MRHnDhQqZx38t6LZE2eKLKSa2MNJb/a8DfkxCllg2Ga3vINAFmhbH4I9rOWWfvI+Hv6oZN1yXbhzAfXOO9+" ..
	"1NByTvBXxvPJzeR2QSXwUZxZxlMYUmkuMKKGYlk03jDpzRMdDoT9AkpQfE2ep4qBpRCHOOEM+hT8URVN33AgccHeBekkt7BySPr0" ..
	"IgLRC7uiCBle5+sKcBx0aAfe+zL4J5XXhvKVAGmjai2ydBRhqja1BFtPBI0zF6kXbxkp7qoq/KDguHlr5qtK+Bv116UP3xEOx5hI" ..
	"+RbzGjyP+Ba5aO5K5RDhMO6wyTd58Kpyx5j3FzGCxilyzyAycmZcK8qRb6nlvOaDwF+9tAYcOK7aUnvrrry6V8zHq9Lbr9qBCa+p" ..
	"xORoZe277D8SiVX5ytifOTxyQOdnH5LFLwLZuNpM7OKOkWcXyras8zgVrXC0zFcNMfT00nV3pGmo7xBh0Q8+Q5w33sdEgREhX4WI" ..
	"XYItSUCxoImYSeqVwTsffE9r74WBE1TYdkVg4slwjVJZUY1/fO3M6WDuuGBlnzRT63z8bgZA+8t1HU71ZrjwcJfXK2qh0LiAPXzf" ..
	"xylHDOIMmHrFAmcSrTLi84nKh1z80+4kWIsqGYWPL/0bMVN34U9B0sAoj2vEib006L2GvGavuxN/e1VNQjk6OInPcO3HyRCAWsnS" ..
	"Jbf/ZZsnybD0FSIswG91RfSepzfjFgXdZTPfS3jqoAZq6yPU37+5wImO8plYR8OeJrzHFcwmsweSlpgtZhpeR9n5soNQCHfJAIiB" ..
	"f25WQmjzpA1wX2Fh855lFx8w2/or2wxaoehWaoCX55ctjRcWSyCC8+OFz7PIdwawfGnCsNfgm4nc4LaffxUN5oSMnzxjAg7UOqwO" ..
	"XC+zV2rPgAam5C5Lid/cZecFRt8nsNtggc6y2ioc6DfIG1LUfv2VdSvYEUoZe5jpRtRAZ78Z3D0HTncUFdzZPueX6vDdcJjZOwRc" ..
	"ngflohZ4JWTLI5tFGkX75Dgctpz8l0xfS0oUtsYBs05V8Ygb98wh3xazfZvv3JRsDLDbfo9S434d9OpN8hx4EHDnKfhOIghFaycT" ..
	"H4GhLCMvzvaIqZ9qup24d8jgTqDCp86eWdT+gHmDIsyeL97Wpt9cLYaOmM6JrQ4eOaPLYRzbUrWRI0hdQkLkdPizfAbfRDm/95nn" ..
	"IiMT513+O1xYlbz8hWYEOwHIdWxjs+4EhPgD3PWH6Oeu6QSov/LNTg5UZSN79kAmUfUUVXwMnVC8tJAtGbHjpaA7WON42UzkIJXe" ..
	"4E7AdS9n5qhgf9uuNYZokOE5Q3YIfC8bRHqfLm+hl0WN2/cO+LmXF4QAv6sooFeEe2erHibSVwp4GRQ/KzZrIwgbJfy99aunYr+M" ..
	"tkb1pTdWzVI1o4kq9QjM1OAO2Aq4YlLNLmWVoxLz4K2jn0xt7RyxlMZkRzODs6pTpzWnzg5pYg1HSkWCuCoe+a2GhikOJM2gcaqC" ..
	"2UpMQ7ANTk1+B6AV73rBJNbZnAm6r65yqReXLu39AGZWLsmRVf2qFWeYnvOKily20RTcEDDMSdLA+qFwMT7zX/WFnNarYxR6u/Xv" ..
	"mO/8nOWmXTeX4cSJoCA8O+PlcN9B9GS3lYVmSC8zVkLZwTaTy0ToejKmty4LtHZm+X8kiehktp8ZhxMimaNABc8e7b6wmTeJ/GNm" ..
	"g3tOnqDFMt8pxHrxKSFTfB/foJMd3ykhOZ6FdiebpndCMTP9msmlUTC3QnfPMyqf2Ba72ip0/LFmE62eyou4ddrHC1qfmjrYOMQo" ..
	"yUnUoncbvNhuvKubeFMnBSph4VZ47HXnZ8/9LyUOzJ+kQCjB/A/ZdOycR1NZpSeLqsK6R9LCEI0BVqG+VyjusWXCZ9ery9f80P1D" ..
	"kJTa12DYFkJuRfDSoEzYQ0TsZ3Jgcc8tEmFBtK8Ispj++SgBKG8dkIGCnBlogv6TB40iEqkNtUc/CC+yV6/WehkNSUi+tPsTRoYK" ..
	"UpUQpT12REKfmY05hVlMgfRNAj4TKcgNuVF+rqxhRE19neqFiFEAoFfe6IHU1VU2Pu5HvXpZqVAdC8mkXVsB7Ivqkrm8G7THaJZ2" ..
	"2WxryqYiYfgVHBFFG6C+8HBNR3WZJR0GUw2QsQ7D4ORCms1OddJnAm7DU4cOajGzsiGd9ES3PC5XzC7zlr3ardBy5phPClD8crcz" ..
	"jaH/d40LXP3u/EO7o3alkdngYuChKHFctxbBy4tENEiyetDvxgdRcQJ00yoUiU9uLnn6GFoBj1Omr28TeVbXaSSfXku5mDc6P/5t" ..
	"SocoxDM2YJ8FX6ZQx/aj4qkRkAjTIZYJOXt7wMwGyf00Yojba6pIWmi6ISq38mZXnnoO7+tfmtNhWyvmuLuRfMYhSlVn/C3FyUQA" ..
	"/ave3fBDuhz7vFd+wecbpJf5Yv3tRFcF8TAtzEqx41ypwz5FQdlNeGo4XPdpfF0OaYfLgMYUOSsFwnocy1lpna44EfaZnXcQ/yoR" ..
	"ws9kyKaGC9lTPPB1jRcl4+VC4b9YgSq4nWaaLmVj0ymKaQodk/hNtkZ+7u53jVRIC50JBrvUyJ4JIkrQlUqacRO7Sr0l1l8Ps35D" ..
	"5Fou8UyqFX88XobCJdDSHy32SCtLbhbzV3cKuWzoAyPo8dqhgHx7Beb59DgpgpgXNzqVY9F5A1kbzgmSGQakwYdp+1Xx1qTuLyP6" ..
	"zYk58xNRcZoAt3Awcx8oQ+yy5dmijHrgmoV5FopGgQif/y8DaZnvJ1czTmXJtujX6cJ8abDbEdArTJlxpGx0UMe5pK+vx/30qSM0" ..
	"1L7ybOJPpsMncVN0sToFEIicgNyHrFfW6R+6y1d71OPa+bbhAvdTIEZ3bn+ursfF2TX+VbwPV+FFTvSnGC+6cVv9nDeVJMVou2z5" ..
	"PA37ReUyeQqIOpQ2d5qKs1UfpMjEPQospiASs4s6OF8Z81rRGa/STqpd9wanFzM4edMw2o5SrPEdFQOR3KfO5RHFFghT0Yvdk9/U" ..
	"AWTcUvLb19nWj+8d3bzCb+6OfCHzJdyQiHM6bwHRcdOE0veKeF3+yLY4e1FlFsdjelQStgG/0h2dNGBeKa7jz4Wz+RgNHuwqOr7G" ..
	"U2/LafvcUAcjX74xl6lnMV+jUh6T/aFyeZ5uzdAx3ZnCdf7EexilWK+aG6BIFjvdMWttg32dQLd6vRXYa1iM/QmvVTwQJTLdPPfu" ..
	"OMyNy1d6aupzNyBdIdODA6ask9Z60WkBMs/Tbj/l1cqhfaMn/TnsMu8AcJuieJxrC9QjX9TKalouyyOyPhFF3Rpgfw6uBlnysPqq" ..
	"x1xvg3mal4IMceHPbnydHXnJ698K/gMdpHYQXQHr8Dig+TTnmMa44405gv8ZYc4noV/askZtQJbZ9piT0Np4GLlBtXXMaSaMBNxO" ..
	"L76OdOMS4w4DrWZzl8XCVkqWeBSxqc0oWfZ5YOAWmwA9HeNixRDIsOCFlKuMhT0hi2X1gm1ZDjRLOZ4FFK9+5TetpYCKnrkOvlfA" ..
	"blfp26XKgiOs1on58DtZLbhahgLhxiC/frAWFpb7AWna0vzDFZd9ds//zz5dX2FzDczAbtePoN2XXALdz2BqsE0TmqMlwp3dAHPf" ..
	"FR4MrZ7utPiUJS15fqP0GGy9vWvaV6A6IUQv0TsLSkW/a7UsrmveUslezKfMhwndqv3/UX712SuvWz6ep8P0wx5TiUeV/xaqWaRh" ..
	"b76pWO6txnGk/iuGJCv4OqKqoLmo7CRzmcnqyoghV2kZXENyNDeJw8MFew030stoZtLTNdeqnjs0tWCKckpPW2jtjJWvYrRwTV4k" ..
	"kWyBwoEvO59XRPCoXxDRiFAdOvs+TY5CaUYsyfvF7LfwUJw0ZlSXqnHrpTa6eGqTNz5fqdl0OX0i4B2VHSbr/RivlpPJ0TaIeFkD" ..
	"ArMO4U5juE+Go/xTc2kaq5BCUkk3tffOw+qDjStIQT91NJ0SXuIZjxQfskrMpld+9AdxY2A0UQTEYbzPnHAloTvlOzyCqX/EwVxq" ..
	"2oGX07G5WTclJ0eyEX2Bmlbiol4XW5EDBhE2W9mmVC6eIhM0o1SZeZNAIvuCzQlUey1GMor5xH5bYq3fxnjb9kmUpQwvDB4n5EIk" ..
	"BpxEy3coDSJDG4ODz8TjeCpoeDmBQidc8nO2c+pxtwtGt7BPN+NWwTI7H+zljYFRjREwkfp3V9umNI3kl1FmbYPZKSIERUW3l8GB" ..
	"xO9lLcdPncqRnM9224OEt3Wz5UL2ZBjbef3idR37SpgCJGlRbK6PFtwydVvLMaUS4Xe0bGMW+wNghx3u5VXcIK7r1KjDLBGlfwW1" ..
	"UjC/A34VI+t8lnS9ee3N/JNoXf2amA6bgNnwi4tw9DdDG9PqGzlqpnRorQpXcTZomyNVh45v5yk9eVmmQEIjhwJO4ajerDx6RLjr" ..
	"PB/3ZvnEwy0Y/doVmsdNOsHCJ90dgtJChDU7D38jtxnvziM67V18+ybpl+v7Entqidn6J1Q4MLEPfxsqO5/Fw1GbLdlnZzs09LfB" ..
	"4Vj3hkqVLqYYGPvjdVg8XVvPfCVfNzCHq+KD1Jdt4pQMNhpZaVuSUW903NRmNq5Y7vyc63phDmL3y7syBBuWVpEXU62HSX4rZgNU" ..
	"NXmlo6SP3P7qX/DU34S9T+PeVGZ8lxJKusN1ciTDLkpAH3aVNqO5asFf73v7xv4lTkR8NILNiyqIeM09fosS1nMNLiv2KW29/pQE" ..
	"QMfTFFCensW+VLpqYpWLwuim+GHLxYTNQZJHScSu1lb36GwGl2wBiSUULMp8aMLuaGX+ke0BvHREXVsTFu5PVTK3E8p+jAcup7AI" ..
	"v7fGzSUjNBtjOqzoUs6+m9gg4DQqjbV1fcGXeKTRnH7g0M97cvEK5A4kJcilomCx6yv/NKfczpVCT3j9sDecm7UBjDSikRXnV2iQ" ..
	"apw/dUKEey/JaxeUiCHITZy0TipRLsLXtjCeBjin/xwUtUabicppbfK4bazFr6tvuS/kVDqoXsyZqS2XgZE/eHwIvYzEQ3zJ9rIh" ..
	"AYxSTH3kcX59D/PNvl/uZNemCxIZaFFSXPK+/95MZVcZ+cF+MOQazVWEhcRBczsSjEQEW/4RT07Y7/TFBUwU4jbIDPiUd6EZvGMe" ..
	"70bFKHIF+yL8qtQTiqaT2zntXUJH/G64Kumatyc8Dkq/icHo/SZG/PSGmDdHvUzIqPwBWiCZGDK/XOiw2AViA6vLbQ5aZ3VmjvHW" ..
	"c6xTjSIb7LQobjx450QuxRGWMBNB8tVZoq/Tkr5D05i0QwCzkB4mQcysvba7GWCCRXSuI0lvEjUcflFbTc/poEDERXXBoxE5WOkc" ..
	"aFL1xoq0kGaW1cUirkOtU6gEvpNj1yt/lndHbNQhVwoqxOsvSHZ5fLRVk51naH47zfC2uzv4cs5sbiPrW0BGvV0ja2y2wIPmFtrl" ..
	"kxucEEE5EGuoTIjhYEvhrZACOj0UdKQ27vstiPFd0GPNcsEWBJEeTzPNt8K6XwOvU+wdbuRkQXgN4OXWjA4Bg5mRazAIkEQbp9uq" ..
	"ZAf8qJIGik/in3wMg3IlxPOUrhoqpdHXNj5n5ktqiqIPutM46iQySLdMdoyrb2MzoOMnY2220RsnntC2Nm/kcCdy2zZsHuZWf4VE" ..
	""
local PAYLOAD_P6 =
	"lb8+4r22NGHRQYXGaZDKFFG3ZoXnD/0g4dMLKU9Jxs6V5Q7G7ljFCqdiPMZn10M7liYnU1jph3kv8tZ6ywIiCsZkhJ27HyrNlXaS" ..
	"jbziRMAG9GYZrWeHpIUIOICPpjJDRP3DtFaqVWf5ZvCXIQmlJLqIkZczUyxtN8df5CDpKfEU7jvnVrAWr1OH1fH3U9b4HHt3ocLN" ..
	"S0ojo02u+iF95AKoXaA0fgrbDngouIS5fwwkRTaJ6lEqTYAZLm/Dk2ZNSCuvYKMwwAVG819TTyYwQy+J55/ikcjdlrbEX5wVDDWT" ..
	"waYZXcezH2sMNXb+UV7twIM9r+UP9Zd2pjApWK2ojEAknssFcw7jvH49cEryJt3Ugl2qLDoKg8oMKsv30P0wngRSeCbwJkY43+Hg" ..
	"PQk93e9DC8K7R/Lq+QFZgxcnf3LeTCPI2cTNE4/4xvJ7Ew3P8jye43TLgEn3yAlzpAuz4e60FAB0dZwBAFEqLCDrUDIPj/XRtOvS" ..
	"VI+DFwC45v4bsFW4FYTN9l/znH2A+9bn3BV2Pha0FdhSv6gPBtMEnZoEyvyswvpRyZbU9D2OHTjV64hUcbTJrRuaVRcy6riBIlUJ" ..
	"iZAJ5VLXSgEe4IuIV5gyeSkIdlqPXF6ukPAktp8e9bHQ8OrD7UDH8E1x5MeDex6gleVEzsmBOE918PTXoJgSuaxQv93l/Sq7KLs8" ..
	"6PgtgYP3MlfCUCzNWXaCEdOzy1nm+qqZeDM/E0Yy8ZAdPFLu2EiYqp6p+oRzl+V6THXsQSC/WTyY81nUVJzxhKAarerObKwn1XeY" ..
	"V6MbFT9JI6K3q0c4TaA8fkV03I/wj2JXt+qAFPY5EljxNDbUEr+OzB+tT/t+axlbt6P7CuLN4uWblfYxyXM6zqZywP1EFMNzKB+W" ..
	"VJK72/RPWapsoVZZgKWmrJEVSUvFbnjIJypVgLOeUpY00mGNrYv/hbkd833D7zvyc3O1hNCh0phiZM2I5UCAuF/Ub9gwD0qwX5AP" ..
	"pwUgK72HJo8z9QV5oPOkw/1S54UxRGB4aBUJg06br2Eo9GfYZIa7ffRauGhdgxfxwqEBsN8pg/iMriomVGRmp+TMrFOzxR8oO0ec" ..
	"p6fhAEVF4ba0z1V9sPkFe/3ajo+bEuZ1hkd4kFOJqBqQV5GobBAqPgXG+9DWElV/BrTDVJ6eD7Uhi0HAl+8APijUkVtvPdfy51J2" ..
	"NFlROz5NHhAxkcm1eV79/SWlPw8kPiAQ31tD7Gu1b64Pyac/Zbq6pOx6TR82im7N9DsjnzLX5QILQyMhSDDEr9bfJm0aAmqQHvNw" ..
	"eNLdm2xW5YXU+8rGqVQcFHCqNLlLhCiFuwRAPUH3KCKZzpGd5HaqUtv/ffSsyJd6ngmLZHwtBVppVpyM8ZN6x4MRT8GschBH6kxL" ..
	"xQMfgF1ZRVJ0WiTqUdAPi1tkKXEoUtCfx9nVVPd9Y2NLRsddsf8ZWatlGbOb7huqXvkLtK3LyQyN+pbfeIYNK56wAyDIDkuR1fUW" ..
	"P1BOu9yB75RQdf/JJ/6HrTmPgz1EwEREKVO/eVQ8sAX8OfRGoRFTb8kHdMvhMp0gs8y8ru1r8Czd608t0HHZuQPFb38UzXrHIWfn" ..
	"oOpxwdr+jMk0nd+vfoqSbCJ4po/VIZ8N8GDwQT/OuPvizRs2g2oWlxwxCvOK9wpUg3F9c3SihRP1mdWc5nl/kR/xIyQQyx11r1sJ" ..
	"2y5a0dNUwT/Lra88gcfq2SxvBvHoCoyevODfuHIW2vuC7fmjQCf0YemdtQCg1X216PZ6HYP0wvxkrjdTZnpMeL7ZBX4Ae6PNh+jb" ..
	"FzgkNGEPEgDb4EjfNp8y7/eF8E/i2HZqFz7e8zYEGsFrlCi48+X2mGrJyZciaXH/Nqgc8p9SqckSScR/ytmrukPPCyjIuoJgEoB7" ..
	"bd96HvoGjFJOCXh/FJUYPO40xMOacWHtIEsLkTSrO6BV2RCc65lrzNoUicyf33QjZdOwHD9W/dJnro4by3w3WS2N2WX3eno6sRL9" ..
	"4li0ZPCJlNBu9+gnCVAJz2sB4QsTh8DtAp6/UUB6Qs1Od3rWnZB5k3eQmZkFbtU0dVq6Wtx4PpFpGfJmfwPf2QRMvqxGNPBj2amN" ..
	"h0/eQrNyZfyoiEClAQoY8nHosucJF1gJiNrdFmve9cssa8R+xPk7HoXiM5zmMeVkYRQrTHN8RnWtIqJBTiGLQT8G/aWehNY8jokp" ..
	"LIIFrqx5yKZPY2SZmQ9UKzo+kf/k+y+BtvsYihlAxg1VHP/LsJJQW0gRK0RByk2vV9W6+jkMpK5o25moC6KIls5azX6cImTxZxrv" ..
	"lM6qcaQ+NSxW3I/NYIbYbGvLMsJgbpZCVGzxIa1g+D8dVre9RWEUM7gEc5SrDQzE7A8hfI3dv2naiViZanDXElhiyNlDH4fm3uE2" ..
	"dZyes+HkwB6wznShNJUVtlx5o8S63XlVyj0VJGBUsGeVzR9465xeHw+5br2I3qwjE+FYdOR9TPexo2QuEdzIyNBZoorpmJw2sdQX" ..
	"oFGCSs/NrH9jDEgkLAcNyPSF2X4ksVGG/kGJO44OekgOHIy5ngIisHB/iYquBwEqM2j1XBT/rHWMvxTLIhQK1nbzYg/tebU4y+/D" ..
	"iwQNRjnej22qg7aHn0qgyRlJcSQaG9u0SsqXe+MR9xiHtEpSLYcNUNdNHRWJz7c14zvN0oVpQIc+7xHi6W5DG7L30hyWONa1UQzP" ..
	"AqjFrGzGn6kae91t9myfOQ7MauzTWX+J9NeVlnH8IzOkgZtMu3EJ+p7pShpxtLMnfG8DoK3ea8bCGWNz3GZq2GjeQYUeoSuAMwhZ" ..
	"9fC5riFXNIbEcPWCFnl/py6RzeU/HlArv54hnQapzH+IacB61BRlDJoLkXzvwZ6VT3CWwuLcxvjjmVfzvJbpQs/jipx70HS3V2IO" ..
	"HTeErvrKvwCLKNVPEaXTgnt0bL9wVU7dCYZgpMUecvhB5341IOqsbBMJJ47tU4F+GRUZFzwIFrJI9YpHV1m3lkaxNBY5doZkVpWK" ..
	"xa6FWkIlGC/Vo3wDO2QH5airh0dTKX+cxY4NqnIulc/NKJDjYfiFa6jYSNDC9eNRuDr70Ex926gaW1Ej/2qzdoyrAZAykdEpLSii" ..
	"7huPFstO1mPQtcgT8kZum+rFjZMWELGme04Zpartfle7asR3juZc2IZSjKA0m7O7WLusTfpOaR3kawHdquFIDhCvobpV/BhxbIv/" ..
	"q/zc+Oo8QWAAzI3A+XiDELPxfZQ8rGdMhC74lwJkduM6+Hk1mILP9U9FCWkzQ+kA2FKVLSuoYgIGzlPNz31JqCTkDR0I+RFfBb2+" ..
	"+eYJBHHaITM/Ow9pu/XNwUzBiTHQj4PwYjcNxO7jcNOEcvrt4d5u+t0OHF7M0J/fUQfgYMxlgz7U2a0LAWJIm/zRbSh/11J0/gjn" ..
	"whT4sBewHbIKPWAFxeTzdKgAKqCG9jkLgBp9Q6Pivt3j/tSeR7JyMqBQimGYEdU8tey6bnKVvWKXfNvP+4S/kcg8NYbP25PHdYgN" ..
	"+LxdA9mHEbW+sgMUkbNcz2WaPEVk4R2g0eTGvrOVnSy8IyM0bMpaBwvATc77s2Yo48cy1F95BLI6J0XUUIxJ/1YW3HPtf+HMKT+c" ..
	"PCj1SuJeESvteuILcgL2f6AF5Y67H7WVnHY6sembV8R+B++nyDsw0d92QDIoIGfFDLViWGjGPKhBdseFXl1R85+UqTrCPKAk4ydF" ..
	"DR6L8A8YPNDndcLXeq6FwMSlvmZGXIHsfzkgDWh1dDZsW/Pa8nZFaK3bfUWVlw8Lx5bV1glgVn2hMJijeYroGyTnwDWRiBDYrPUd" ..
	"VKErtXNh2vKCl2Tt80+m5QYw4qvcSTHagC5XpSxqLfqlf4vBb178ygNfXwWVleLt9RPsHYBMHl/UE1c9tqYoGTDHyLDd/dPe4fkf" ..
	"m1Mu2px9rzIIomOXezjJEa32mx6ZGKJfl/gAibBs45KJUbea0FTtSDktvDSZtvpZQ/m50W1k4hFXq91TeiDTQkgHV8m8uC9j8bVE" ..
	"A2c8NtwwyGX7mPmo2mB5mv2s9tiZbKfmtctmOoxrWkHM+3RKUt6S1QECbGg85/1ewvTnkjBsMEL7QaxSLMxI9D3F+49upsyDMMkw" ..
	"vqSRM587mfVPsh5+2v8x3aohinlf3CRi9OPHbqLg90LmAv6nbtj7SF0zF2ujyqhvHXQA42gGfNTm9jHJjLsAaUK7rlXzHhaPVZ0O" ..
	"3ScRLn//E6mUM0GxQu1soviziHbu+RDJ8I37QElaRT7hYbQ7+FsFhYLdxm9c2XAzKWCX/kQ4wpGtfbdLr4u3DG7OrrhCmfYvdGdW" ..
	"deiBHWklAigvO+awzQStfrJeEI8XFeci1usUA+dNk/kg9qrV7ynJqhS3VtF1zHY5w/0+CrAFtvscRxCtF+VJuDSUoC9QXhCB8Tct" ..
	"6dqDxpbDL69N+a+tOvXe/Q1W51HkPBrtsZF2Zqy2h/IXiqnk/82Lg7UI1szzYbFZDcUt6FHzLRJ0kazIkvV2ebzwJCGdL0hXMEEK" ..
	"ope83PO5DmeEbbDhJmjeWNSqD3nJPO+LqgAh5XIvW4I1mVlukuPF23Hipr3KwlbsOERzyOcW41CYIEL4fPJLCilXqrshyT+/JOeG" ..
	"6uJmkC2E9yzx8iQpkcOEVz81+CDhiSL5UMm5R4T2AHxco5YE0UCRB32wVLML0cTX9hC7ASptxGM+3UqZsqG7X4sHalRR2QIMLeFP" ..
	"kfmJg0PL5sPv7WgkWe3/f+Bj4Onj6TDm9ldQ7oxuxtUraYgnzl6SjSRPAAc0Mf77TSJxD98EG33e9RXiX6qK0/ZH8kdoNWngLkEy" ..
	"HjahBi034vzoUCLBSosLQJOMYGEYfBMx0tBe4cFCw7b+LaL0+Wqe5ipP2jU5peWVCbm4bNTMSAkglge2q06NvJ9uPE7EaRRQCzPL" ..
	"Uh2GQh8Mq1Oc1bNrt13/CznNPfPlTL9/V20458q92qLOP9Whyk4QsARFiwxkPIKimB/WFxHdqCxDj7iSFgTM9qpypjrKfqWDM81J" ..
	"bjvfisA9+zzIMF1vDAJQwJb7v1pWFyU5z4YhR1VEZ31/wFmiXR06qGAEmGbztogh5aV2uAWlzF4B5mRbU6I9CNnahwYOgCpZ2YAw" ..
	"HBcFnfEEsxEn18CL3fYjtNly0INHiewOtur2tVFr4JAkrpGWcnq+MRCe8DL2l4NZ5qPTJ46QHXOpMhpuURX14q1yEymzcVIf1uBO" ..
	"qE8Dw4ovETFyk+n3QdK6cjad/6TBnxW1pPOqGGtbdOgpo+bjJy4C8dmktVrzzbTjzmD9d7gh0afYnQMHch43lchpPz6LcC9U1IfQ" ..
	"GFIGuA36JBH60D0mwLPEV8fBXJ8S6FW7FGozoY9oDkD/llsEF30AnExWP6j9e8nudMEPfL7N0XoVe/2n5dVSt2oC4M4qu2493Y7P" ..
	"N5Rf0LVX8zZTckRbbL4F67KmkwykjVFSEgIiBWc5PklPTLnUP2bzJVEukA5VtHUuccf7ajHn2RZv1KMMy2j3zIOA+zX/7gHiD78Q" ..
	"v4cqmb5v9S0DUAQEgpc++RpVkCF8DToej/laZBLYZ25FgTdw1x3n2FMfnFFWche8gz4dgPJti8CJ+YL6knGvsk2FLhbnhSZNZ/Gi" ..
	"eU7OSWSkaBsOE1aBI/8o29TpFwDLiuI5yBcHMoifcsHrKsvOhadqP2XdStzPx2uAnvvSuidAgXz7KuSzew9kSgUN3AoLnmHLISJh" ..
	"8w/hfEMa5kMZ5CFL+dN8E90vu44U83LkfV4rQo/P19q8pcMsAK9vrd+/cUR90RrDfkJz6j2eGRHd312Wi4GOlgQota+0ZjeRdsRc" ..
	"Gi8L8zBPsBdodfhcp/h2U8Sc0C2RLJ4DXE9sRw5W7bNrZondTDhfylpa5MCr3DuWF1GVC0Erv84cs+At3fpKyGj8NNUStKdYKDvj" ..
	"JwycHS9jIOqUwsjfhjkgoIAeCvBCvfvicrphF4VmhGly5xj5cvX8UtqPTV889DPV+WhI9ug63pL34OWlpwr4e5ElTy8qXzkS/HKh" ..
	""
local PAYLOAD_P7 =
	"HAjNTzchssJ1zVVtWSZMVskYZAC9evWJvsild1WbaKKoKMnGFANFVaDX0i8NdbqnWgm06MFm0GP5M41wZ/ziee9G4lnvPBTar9Wh" ..
	"2+j0kdQPRvWp1wjX6FNm4I0qVm91z+ORV/GRCoYmK6pCG/IjgsUGhma7Ko5ZFUkut0uLG5oqJ1mS5PjNhONWq7ENWG4HGfPG5JO+" ..
	"SDpGmLf0aReau00uc/A/CxHd/hdanjoUx/hcb2oktkRcHcAhaLDLNb097Y66soceS3E/723LFVePboF6PiYPtgqG/cPaTIRA3nN1" ..
	"hyJr33O/ffVoyL8GSkDvfPQs9eWW4uwl2q71KGkOvTu3mAVc5RJ/a9BO5HlF9zrF7RyzvtTfQLbQd4qHhAEoEjc+Os9KqyXvObsZ" ..
	"AuvoWGd1WMWGg7fDtXms+u84NT7Dj2iGQISI8PyMyVaH0cSFUi0PoX5I+XN7YtNwM+bmyWw3kll73EBU5oK3cYNMDVWINOdUCXsB" ..
	"fzOBLkAyQW6acNCjUHpbZXlbW1h3IKxLBYctG151OTEfAUQFUJ1RBRVJdzu6z8ons0S+5Hl7QXf0+lEOQ06KCeW2vHvyg8fTl9Qx" ..
	"lUga4zhC9N4ZNmXebdV2isDfDRwzWAQhAtO6vGvgYsgPaxFwyKzw0/CusN7P8Wzp9LsK5ub6zES2aUxGVW92/ITvjyVk6vSHWpxq" ..
	"NNX3fVJn5L2A17Qd/a+HnPDBSkaSAFZbWf3qxBAighsmbedU8kONdEHe0bwzFv1u6cvKDaQ1HQC3rjtISR2esz00sd/gvk2nzUoW" ..
	"SL6/xcVKXUwXX/y8iP5PWJ3pcF3kpkjFaifDEdtam3ym2LAf4xXZ2UFGBP50IUl4zcmEeIn+BWLvy87+kaBoNANgNOO1xu5wfQBJ" ..
	"yuQ4aZ2pbb2dRp9e7wGV7dmhCSkh2aDqjXcSGzmEIevhtCRMM/Kx3TVPjiVrSzpptE9VFjQH9FOztcyK/7ly8gWvYDArw8JpYfQV" ..
	"qeaACbRFXs3fw+sPG9DwU3SLA6JCzg5tDGYF54tEXMBy1sHT/h9I9P3ZzLZm/neOmL+H8KsuKCorkGAQPh5YLjIa1e5iF8I2rLov" ..
	"YKCmoYpAAJzgbV0/R1Rd3p9jAam1afzFWeP/+dVxOzbD2eEViEUk8tqL4cAMyA/JcOj1NV9CJ3oRooKi/SpFbZL89XV/y39EEUQE" ..
	"Mj9fCcHtnWtnQ5chQiP/M777+68WDAwaCfqlNSpWEHDZYDUgoP+Oy7ooyDjAVHSzC5+SkowtfD8pc9u8lM4PLypdg+cTbXTB5m5P" ..
	"ArzP2sSWEuhM/Wqwjkm4Lz3tL4LC2/JfNyk6h+ZEO+3vHjgl6YiTwd4Uo98lx7ZCg3NkJgcD6OaRJkVQFVItGhMa99ftOu+A/9Hr" ..
	"y2SmWkXTuqOCea6yTbcZru11PaY9bJVemUaH7gLMRH1aHRIE1zaaiYfQXJrSFO1Vh5qskk16LwMLzR1dMCP3TEAbzFIuWPOBEM5D" ..
	"S7qaGiZ486LaVQYr72mSju30QoY9/bZW2MEPXB9yrcksq9rYoqpBYcDIZWLoIOoILyeLg9IiIC/mf8umsDe/9s1ucjY4IcN5w+Up" ..
	"DqkO3JRNQIk37K1v7cJ7kf+woSHofzJUpny65fewv6Kgp92IrfNS67vRBgzNWl61WQrq44zk4Q1BueM9P4eKR5UxCpZ/LFCb8jBw" ..
	"fpRQQncltWs/X4WMMvIei+3jYgh49eFYFujD97RqYrMgC4nY/HwNDhECQUtua1bV42C4Zp0nOlNk6ecOQk8LQadoj4ih6VCtKZ5v" ..
	"boUjbJVPTjnPi0xDZ40Yby+iu72P6STrz4kuCfplIV1QlTvLQMiMj/+FJFWSSbw+d8PHGL4fylZ3/OYvZ299K1DR40a9KZRyz0Ib" ..
	"DUq04271+SCWmvVPOavdL2NTTfdfyPrL3MBumTAK2rt9rTcIIkH/CRaD1KFaYLRpv/RDQQo4yLDlrs0W5NK7XueGEFkj7e1mRHEG" ..
	"3KfFtpUqNimUGX/QeUEbRx2fMQpHxcn8JVGwTtlP8/09f7VQFPNP6WInKozO+M8Xc6DkFe0g4csnqZ7zxv9IzDgFEDO5Zg3smyXa" ..
	"bDP8ZhIGwmCi9KK/GLYC4RcoNq0/aRx3q7albjtn3lI4nVpYtNnpdIv5yjnSXOf92TORudxsqCyYgTcu8AukoNQtjU/w5VvEv3YK" ..
	"Tqv2EFlk9iF1+yyBermKG8DvEDpT4oTYkMPV4KtH8Q+UKb0Gdt6umy2RHoK8l7WEY/QHOlYNQaks4kY3NwVRMEQ6czH37Y7kWt2X" ..
	"mrDEGlnKsW6NQ9cjoZ53MEVWoY7y4OZGAYDSkpOFwr87HP0jnTWGk5JfRMCXN43xO6fHSzCLRpsKCctLo+jUFK2EiOMH7Khuv4io" ..
	"ofpXVP9cJWBbfrysOi3oMB0ggnJCmX+gHtZUVg5oWXwVp3sqygV0Y960txeRCeTP7vBXvZ0hRa+YWQJrs8Mv5GdxEw4wFkwIppNa" ..
	"GJicYkfqIarKfksa5ClWXBKsFcVT+9Q7fmZAVMKB9XzAliF9lOVBeY6MctcbHy4xqDAwQFKFpgZncmJ5KKK/qOMg9Kj3m43WrelP" ..
	"6eDM5MR4q3Y2S3pSOsUXnyTNI7B+E2kU4dvPo6ryCNCTnbXg5EgIdWQmsrw5d5AUMd1kY2okmTdnOdK6Pf4s5NSgAYrXTD7aBdl8" ..
	"c3DBBICMHlntvpjHvyWzAMvbITWIVXByQZK9BgPg02s7kjV4n3Vz/AxK49X2IiZLwZ2RACB8Kg452KCMQCzfqFmyvr0roSf+NwgX" ..
	"AYGxcFAJInz3kGfZYJledg7kP4OtI6o5gXz6mIM1nLUwLP65diZDEX1wW+AHSfdIgb+Z6x/iR8TbRyXmVyyZYYIqnm2ow0QaPo+b" ..
	"FMqzNCKyWF9ggDUHOV0CfevfLaBTxJG9+qMA6lBWTbU7zLBxRR6UHvIRCqEoYHxqfdJbS/gGBB8Ej2Em95rTCI9X7Cals78H199G" ..
	"XM1o9qurIHfM+43a3EWpHFh4VAZfCjs9XCW1gW6PvodXKUiiFTvAe9Ll/LlWi/dNeWKvEXOy1lA8kSKJELybXS0DkCy98aCbS5Ss" ..
	"SsOZH9a4VfWt2IQMauekokMx8k8zEBmvsPGREJX/FgF05et/8gLiKZ1Q1fG83fTjStrvEEc77VNRTAfHCFn8SjSsYi7Zatdod9B9" ..
	"UuD7gphDfK7NSmbkjaX1bWYBR8cOG2apE0Ky87QzUist8rGHPpxoq3lkrI5ZGBXJJKjyWsFy+j5zTGZb1994ZELynqy2UgSYcyiM" ..
	"yuZVdDzhDdmutncPUN+q6aa0Uztu+qOHlmdadOFj8ORNbS8snPhc0GsYFJ4zM5u+A7xSNSr4kbmrMvScbLRk83PD3hYKX0Ctymd3" ..
	"ouH6V6E91lsBQJSvPWHWdxpsxurNfyu5BdjNTjxVSFbgqX4ycBcaptdXGsZYWS7jHjtSJDdE4lkqClR0hs4sgK8hKaHZeMe9LKIa" ..
	"fE/g57kCoO4N6Vk9Hi58UOFDHHhrPx9CscscOJrUS4FKQGbW3RzRloFVA1pBT1oY8lmFSsyvhLH5KB9fRdkX+EpSP6dQXNOnYmMV" ..
	"7kVP6BBADvo20B5CQQchjaocfGpSPIprppF5DrOEpr7GVWQghdCnOBhGhyYInU4Z6tObyM9MNsXdNU8ua720S1W47fqZvBQdP0or" ..
	"CQKXAsKsd5D4P31mGMphqwtsO94vMpMn52HU3BdVqGav3XNNAIrOqNyHQ85X8elsr5ht786QOEXwjcr7bXw1G5kkNaNDJfRrHfkU" ..
	"JDlvZXec4Pyvg/eu8YbHErdahSeQOU3p4shPv09Dc7P0heolNdusfa2FD/F+fKwyHyz+BwZAmMP7Bb04NTSkxLel8Lp+0ATBqGGW" ..
	"jA5kzEW5wsiJdc62VB7XfyKyGSJeczgV00wKIxRVCsERBKW8R1UDAqDLkpjWWXmHy0hlHGwR+cLsH2PE3tCA7DwOBHgJX+bxD0cR" ..
	"h+HscW5PvGfc8U/h5Ivd3686tX2XK2VSKztwd+vguGTgutcFHMo4ikY7HiEIfM0zluCb+J12g7mHgAT8W9kY8xCdiEM5Kop+sYak" ..
	"gJxr2TIU19FsQYNzd+8mlQf55N2cFmSVakw2hz95jjLx8Czs3ZaJhLSDUzuuUeQQwbGoh5sX09VnLgLNPf5/EnSgk03eRNwulO07" ..
	"5vrrZiampZNBeIW6nUrM1P3o1DqpraUvsPry8SeP4lw37/abW2LKQILRndNwiVk8mognq28ZccWAeGVXYUGJ6EWkifrG/tzzlXGq" ..
	"cbuG4vG3/y7UxiXmAL8A55txF0VZSMpwGnnDYhZHvFO9nGTMAeefemQHzNEPALBA3TyyN2gEM9EROsY4+lSxXhyCYvrKo6mzdtF0" ..
	"H1TcoxJIfsMUfyjzVxTKq6F+Vqs4bQ6PbMWoBxXMp4XIYI1lohZ4Yd6ocd3tkQ5FaiEZhPsvjvX4rp0i7/rdwkWl/0qNejYH1Mik" ..
	"EB11pwyU3M7EVtbm/4RZLGUFg0ukYfIqvGupk19eyEumkl9N5TZxU2u2N9mDI4/BUbEwfdttV0EK95+BVZ3G1Uv7oEs/kH7ZYleE" ..
	"HtHFVpQDvGXWSkUVHy6SBTF7XtXZx7fYHXL47to5dtT/hYUm2B0d9Y0rX7Yam/9RA9Lk4+BsUG+IoZiXhwVSEWWyENmNub+tIgFC" ..
	"s8KnF1nM47qkq/V9I9CwljRxtbu65m18aVTd/aPxsG43hKCB3HG7sOzyyy9QMkATcyRPOToJoVwKhVmJQD+j9QhbeJSrwHJjx+lt" ..
	"Jm7E99y1BotQ3vgK9gkO4qPrxb2khjKdQdH3KzM4hueatVnoeG8CSgz5GZKyzg7ffkRT4TsF+M6AZfitgUzAixEmXCKNZygo2XsM" ..
	"sdnMjxdqWd85bwAiZPd8HP0MIqOQc5Vbknmh2de+XAreAKx8f9smUcvGGMRl69FuG08l3oGpSiUCiJI6aIlpLm7hErUkqz8Ys6S+" ..
	"pAGo1S4oy/n39OfEHupFo8lcc0Rll6K9Ad12/QhP3jvbZIGCf2NYhJb70R9UWihQJXpbHeUguqV+/wq/Vf9DO9YVnLs5cjJaHSB6" ..
	"L+9jDhY5da9oE2SGCPSAkhqMMibHbhVJlAVzMeY/DE5eU9reZXavTOrRWVtTh55veyHKJ0l6rINBOIfcP2wMUGtMIag5Hg95SNKi" ..
	"w+Xnlsl1kJ8j7z0KrN77IctRJ2czKGtZl8U8vEBzJ8+QTiufVPxMSAzhdfv++uY5OHfmCieHBfgM3p2xGvSfjvNdVcJ57WWhLOVu" ..
	"L5MrAx+EAoUlhrqMdsLxrcaGUGBawQQ5lOBAi/In1htnONQ66cM9d5Eatv3ot++cX1Xfr1CHP4yvp78Td/uJPpCKL/OdVLjpKa9I" ..
	"K1aWcqK3cBkAXpPNld6FJVLvoHht6FYAB8JtSGOPVbAMoiwNbDiBt2tmJf87/RnWqrM7Fty8vsL9+/Ys/QPgnu0LeHktcPb9KXVM" ..
	"pzT/CARr89CifQIAdJsWxpWqnJNkxXrgnYdzC04SFPQTjO6lugkoLviFQ7gO18no/Hu/A0uP+VYzK2rrCBxog+8eAj9EwiB8D0pe" ..
	"LskuQDA1dnUWQ6MUhJ2y8k35eXQqRl0yXOKJu6puRIw3HNTkoROV/J0bNUjDUhQd44Ld7VxsvcanFTYBe37kAS79pd5zOEZEYV59" ..
	"NBfFZLJeVjCYHQCbogwF2aXOLSwrOFNF8BU6ZsXAkMwoWq6uVhG3ugnKdRcsX5Ewi50RDlyOG/HQbpaXq2UAWru3i2/fYDGUQ1cR" ..
	"R5fzAxIOC1vyrAunissfVYv2hczdo9/BlwLMi3yORdFVzWzYid+y3K2tPDczQHdi6VGYiZkl1kzwngCJWpmL0rLwhGFUKvMI0Fls" ..
	"Q5NJZ3GQbSlDmVK0sNDP0AkVULos200r5VNPwvuAMi6pat9tU9ygz1N6hF+hScJYBD1bU+W3BS/siP4r8Hw/ud8vlg8QMd89U7C6" ..
	""
local PAYLOAD_P8 =
	"YOBYIACrn6Ih3kQftZ3jMxS84g2qGCC6ouYFLl7jEPAxHZHS63xhJ7SjOOYt/4PzqSsHYDxsjv0wqcRoLjMHy6HAfRDJJwfMGRSP" ..
	"/UmapkRJ9xwVPpV+d860o/Wcnzt4X1bZ8maBlw6a8HkDNmiahlcAhw0fWgCGrwQUaqpncS/eG+/iljoZHR91Zw4h928EnaqN1BRd" ..
	"FzsMBLHqg38n6AWGYsUrZkPQZEDdNoQoCERZA7pr+S5DJUsY2U4brdiiRZHvGlMKy1E0bk+Km1DjYl5D25+0Xw5UkaUGsJ9POce2" ..
	"Ljg/YmUJdDk3Lh6NwoqjlpDL2JeaJXWn/wdM4CHoiv1WTLvRstwTFZFKFZvJSLjHLL46pYUAQd8Z9fbcfyr6CBveVpZgUqpNDuZh" ..
	"w80V59FeAIqKO1PI9A5sJI6gZ9/NFwTFFr3FHEmYtvDx07emBi/9vZy7VKQeeMX2pJtxz8r1LxLxUbgGm5olpIPWq8/5f6HCzEbU" ..
	"HzbtB7P1xs3wFR6rY+EDDSlleY7RhxKLW1NP1sPG/pC6ze0tYRqHVa8cXQ2WG1gMMKbyT9RXCeLfnEMGBKNdkfyFsHoxkgfn62dl" ..
	"SfqPFRNghOnAudpZPK0ezOwstI6budALp2apPQNxUu6zPcDtcvMGblXp5kxQjE5qDjeEhBNtlic2M9e9ISqv5E9//l+KcydO0cLD" ..
	"mc3eHcDRXNB9eVLshUvPkTclt6jHrJZI3bKf8ZU3gjfDBUsT/7IkeWecCpaaTA8/o01R+XukBfDCud7UFs+1kh26w79+5MZ3nOcw" ..
	"YDREcLF91HyzZ5A7OtVHikBPvU+3KWib7MkXmZARkiY+Fohg7wSe0Mu7E2q3+FeEPgs/3VzU6sv0LvpNH+D9mYeBfnSHr7sknq3v" ..
	"rmvBlT9Y0y0mNOoHpx9ijjcXnoCLT5qVC/uKIsdTTjJDYHlw8Xj87UzMwvHsjU0Fi/8mQTqz9Q+1qY9E9APEwIs1rIOWlWpJSR5O" ..
	"baUwLoHaRKqPD5AfqDIiSQPePRvpP+xYS3sOpkOEa4xH0yBYixM4ZFgPbxMwEM0aiHJzbhoh5tVh4LPs3YbEzDJBSfWHAME0GO+d" ..
	"Fbz6b4xVfPJde5zWNQYQ4esNv5pBsDLV84OoNaKVy0zuVRMOYh4qrGefeP2IJ2sU0zQqdCerajF029+hw/Eetf/5YDb8eAAVOmof" ..
	"uj4biOTxEYj0hBDdXdWVxXa7cqINZ6sJ2HbGnTF7H2nYLNc9+3F7ey/E5VyLHE+lpYf2zegZ6Jz8A//+HYQ9stf7EMEwwVZ3z/S5" ..
	"DB/RSvIz7RD1Q6N47wDeiB3sl9B80HO6vKX+U51ofL2yYbf3H++sikBrHY3Vt+l7nxjhmOniv9x1NG4dTKe07EnevUwsRJUVySuN" ..
	"gmgbcH3yfasu1ZsfaiBexFMSf7lLJ5Zluulx4/pHTLS8uve5WvtrfasCuYWjcsMClgBUGq6t4DW7VnmzKxK6+OGNj/vqfLKF+Uzg" ..
	"B5b2KqdrqwhPp8DfL5dMcrlrVUygf9kVtlcuIqNOqkvi2esCqnCF1GRJlozIvel1bxtQAAuYepOwtvVvaWi1amtZMFW7MLtzHVho" ..
	"KBd08ZMacorUejyvIsnzwa8COfz51gb0mEGCTELYfTquMINBe3RC9DQa/xbSI1NeruR7ttWaEucTZuiGLCXpetw34dgJZgnoHC7X" ..
	"mXCM2IkeIiSQoQ+sLYI26axPZb1h2g+LLt2rxmw34fjEZM9YSaVfIr9yQl8d+lTyOHLTkz4N43tkzcPdelP7N3tnYGKDoyzNlddc" ..
	"8nb0bMeC9rYr/C6Uc9/QVUZA4lm71Tg8RVYMQkXAnKrHPw56Yj7Y4zMGl1k8B753AM9JIW377klDHl1sgWqNo+Rx8PHbdF9TTjEk" ..
	"rlR2JR87Uc61Vj3eJ2abjszit0Dq4YASn/zXzOIk906u57ojuoDcLshepk763B0GNJWpfh1B6ukW/dW6K/HQ3MJ6e5dAzVDkFEZg" ..
	"TaJP9xKcq9EuC7RYn1nv44Vwf4oGE+5N1eQrkxdIer/3oq1K+xw0rd43qZG5pcMu9g8fpIfzj7PQXl9CVTcByboz831RnuQaGzXN" ..
	"CWURLgLkC0RNGOdimMWawi5iW9/5yo5q6uO6SpWzNGWbK0DX5mWc03SXbSad6GntIbteHeIexIc5fY3GMR5nyQpxHP4OUO3dvcVM" ..
	"Sm53UyqJrbQc3GbXbIqnc5+po4uZP0hkLKiXjgf13KNEvlCGE4moCMkVA2mrXmJ8boAROajwC6383rj4MwPyLKmICjrUkBjhZfVu" ..
	"d5SH/qqCE6WRuhh1+rZqB2KMu+T8xOltMLoFR3XkaaORH5Nh7hA/5aEiltXqGGvSRBtVwY8snUCXayIzhrkhkuwgHOJ2YgVCdHpr" ..
	"Ge5++5vYqIFeoZCTu3jqg0m1J+xCoQYoBud2sADJc22mHwKu8LRjX6cOOiqKrilGumA4sXeleFEIQsMiWwMRc0wYYXmj8di52ZU5" ..
	"mpfqW9fcouKBE/C3zDCWQlHG3RgEMx/AMzEUZRB77qvIW5gHSWT+uwTv7MbKAPr43Xo2uC3Z9ZDesCEgTBM9YbGWlDrop5UlG3yc" ..
	"jlTL8p39QgvapEKhdV4K3OdRsOwaKslIU+ePypeZjTL1g28Ot2p9A8HEVSOyxwFWGaPnd4eZQTs/tMa/C4oHmqGK7+v+WoiRVsUt" ..
	"vOhCHeDLgPsElmwHKCLNV0pO2syP5juaH/LYl4SonI9UT32EIZz6NtAGyk9BlYx717wX54S8Q3ENE7Bb48YUr1pq8oJj4jpFVULZ" ..
	"gWZWwsGsrrRzCggJpn5D/nfRZi5wc08KpU24R6TisaHeKRM0CFVqPoSz0N9atcbss+NgIyps3zkcUgeUifBqS896cOj/oaIyWb85" ..
	"tyF5ERoVdHPZ9jdUfmoFCQeuKwKUdGkQDurwCpTrdYX9NAgt4BDRlbdNPeB5rALDSTSce+3b/oyzvyb+mZvuUoK6fUEWA2ZS6CVU" ..
	"rMaAWuRzDIx+yxJsXTn2bpp3j9ZtcXvrsuWAs8lOnDPvzlhjb1jE1A46/sAtDKwoFB3kBNihRoWbw14ZFAKJkilcGc5wd0BOuRTT" ..
	"lCpJvlY7zcs138QVJyIzVD47p7147Q3y2qv0AOVSkYR6+bJbg7oxMSbcmIRrUpV9pzvjI7l/9+QibyFhySmyQIn8qJtv+dnnYLKj" ..
	"DbnegMSu86I9NFuZ8Djgtqs/p/aMVzHzBVvauEItTC2LkR79s52WDaU9ilofv2svW0s3eTw6o+6f4VgPQY3uy2nU+eSVW+BeznZm" ..
	"8lVJ4x7cpV6WiKOVOnKmEkrPBkJ64fXKnfEuCuHageNkk6QKbmBlPi4VzR0jQNe6lGyHCvFqr9DZuhUQxm3Mnxcrx3mtHorwr6Xx" ..
	"N796N3AjyLw93bWDBJljD/CBP15FpzDfYshWvFoDVfevfZlNpazRJewIZfR/xXJYdi/5QQj0qE/bYmHiBeakwkzPyBQadSj2X/ei" ..
	"Q4OYbGPkapDqTG83xNEO35RaLbXE1o17uXZxjxxjEqyVg2TU+yHO+ALRME28RMjkEfpDTIVj2qfkcBYl275WWrytb6lk1mgRyQcf" ..
	"I4MAreccaq+dcXhxcs2TKcCXzOCfkAI6JA3ftn4U+h4ItSi2jAIlPpcCWAdep3jgnz+VYzMzYJLgU9YPpmlATjQ55CjogS2kBieZ" ..
	"KAHE2Edf+YO0dLWN7Tas0zmen0lYg0QqoPnuMu4D6ptct8o96b7cCkAhRfuNgO3vy5ouwXYL5HHc2x+h+7x+hLHbLmIklgTq+N9n" ..
	"jTgWBq5WFVDGrCEOCvPfnFMBh6rK+dhhwNmHyVwZazsNAulxA6XS6EYZMaVD58QaPjsxOwtqOI3ndyiY3JpG8Cbrknv9tnaa6enO" ..
	"Zj9qj/+Ouxn3Y1Z6HKY/VmtIlD+83R74wDZqe41Ecxo621AsUguQNPlOIXzS61jV4l4IMMLoe3HSn2T7EnZSU3SCPx9C0RtDlvEr" ..
	"Qn7wEkQ/32BNKmSYkEyk+mDdwHFjZAgbSGDi56oyqoizdujZpMOHpZpYV+6tVZaQhfwvxeKwoRzpEDnB26Q4pbxBYJ1ghrm70TqP" ..
	"59CWtQB8uc9t2471SDnfl8JP0qD/rmq7jdFNOzbn2Hnq39f6gp/v7Fi3khh/FP1Xe/X4Eh5t3JIbzi+t8Z1TMYJDk7WtI3TNADv0" ..
	"tOjnVBoYTBAhaxcX7DJmwlsU/AUVAitinjJQdZzenH5i0PVW7+IPCiGYLhzukPYsjhARs5mijM4KQlbKPhm84iPArB4LKM/IPjTa" ..
	"3FY4FD4jIF/cGFXARwDduI77PO5/XcUIwV+QEWSkB2jMfmOgvDWBJiQzE6b7wAxWIEC4kkrNytvu1laMQRisp+9+k6ejQLMcTsVk" ..
	"9K9lmLnivuu9CMq+AUtl8I83xiMQnhf8suCVfIYhfDnRyfa1/hSlpqdoqN6xHQgHN7050qhTC92dwilOxYcbNEIsPXhPIw2abR07" ..
	"G0GLwr60Al/0Ibhc7zCp2PZBy2t6pPKz7W4XQvbIfbgR8xz6Dp61+zaGxuT2EcqaOYQLiy7CJxiVarCkDU96TLlFCnjzoIyF6QBG" ..
	"JsFHF1xdmtcAU9PM/aKki7HQLGH4L0SITjzAZ4ExwXfE3E9feemeAUaLzpz5H+2EInlkliB8NtJrtXkZqgYrpKn2qxCzHQOsm9oL" ..
	"dml9cNGMk3Z0PneBRknGGs5sKT9DzkkPpXyGJJDYluPEv5ZQgxwx6w9NiouUWal1QcaF9yL8dou1jJjeOCv7gF5pSwZk3rVrY2aR" ..
	"V5V9uphQTd5Pq+3Z1M36eKQouRGqKW14+aCU6ZZECE0dXI8zMAhIY9swcLYHPjhS4EbnVx1UqztJa89RJoVzkqO37iI7oLDzQv6e" ..
	"hSur6WYFaAWGwG/4xLfZaMF+V64EHCd+0I7sFC3n+BEFVYZBfVstt9z8HTHtnIouRUgh7UQTophKBoVJ9Vll6YcWE0tHpDdklxZu" ..
	"zXBQwyb/F8AKL3bzNmOC3TBTZuK5uYVAYldryKdaGiP+OtGe35cpX4Xq4fmJfXhdpoTVY7roZvDtfCkMO0tx6wr3fWfTSLaejAXZ" ..
	"Z9zyrjIPX/Zd1JwBnG3a1SOSFlCyYMh0nV1w8/2TMnPv8QGKhdY4dzkT2uz4+J6QqouDTkdiDmNDgPbWqL/2DMqKgk7BkJ5e7f7u" ..
	"XEWEGJuQxYhCyIUBt36VfV9MONCCAbWYXd52elQKj7iAg5LBMOGtrUKp5omruCiDevAKj5cTm2C4X6xGi1X/POvXbcL9thxdakG5" ..
	"pJ3mxa4NZh+4FFJ1r5H8W4rPjkFFYhfLN+f+ZLsCKult0q3j5Wgx0IlWSaWws5VOg5PpnLU8Sh7A1sQ8dnJAjdtqE9ZTk5cTWmGx" ..
	"21mjdxeyixIg1YtAKjZXXAsnFaeQ+fesYnsAcFATSBdJ6cI2gscPmznZ4JaSkhOQr/9U6yB5kUe7WUkf2MrtTL1JQc6pPYXbTdlz" ..
	"Fv2f7+SLOkqbSWuUgEYW2g8XDxcFcYAjilX09sZmFzcYjaKZKx2Dg9p4x+k2NYCw0k+i3KwsdRtj4xC0zE2GsUblA6S4THYoWYE+" ..
	"7JGBnSPi69vaCjsTcpV8OjygAcAti7Hlgi9Jmvtg7YCNcwBzEHxLgwolXM3nJVmGZa8a9XCegf6jRwpbQPP1qrpUATQb0NFmELuJ" ..
	"YjaOMOvM5emYAxvbIdInPs12bFkle22lx5vebh/EWuty5eDvq70ZTDRy9IFPoNGuzpEnAG2h+uBqCrpU9T4BpBTFi0GZXJMCcLaP" ..
	"cWRY/gqAPtha0BbZJDVAjA6Y0UVmuVAPT00lv3qRu2W1P7+PWDO2s7w68psbOCbg9f1mOkcwAkzA1MA+U7WGtQB0n+jyS/GCs5G2" ..
	"82bbc/3q4qgDfUfGQF1ZyWuhRXkksXlN+fOhv2agzo6WjyrQX7DIZpAxRXoM2MVDCZO1kkq1fVnBknHA3ljeAamaVSbcpnUxbg/v" ..
	""
local PAYLOAD_P9 =
	"W8PbyyFPBYMbd1kzyxeCnkeYWarEnKW/P9foVEy5uisXwSeDMNK8d1Eb/lhhzwRFyzbhH9IBYKQ4HOSBlqW7C+mSRybx9ENBQvHY" ..
	"Asj9RIHn9G9QwLVPPTT/uZS6PlV6TG6NEmW3HuX3H+e/wnYmBRRe6POSXWpRLHqAXTSfvMpcHn36cncH3kIwy39+1Bq+v52RbpIj" ..
	"nGxnaTYnl1bgOWOtE/UKfBv6mWxKUOPadArvO39EHhEzW9JuMhDOlZe+ZeRJxAnDDevQNW9lwfzt8V6bz8WFVJF0EVwG+V68U+JX" ..
	"lcceVZhKSkdXOXIXogQE7ARwbVHBoT80kbNjbhYlE6ciZlJQaMxRgogdqJWR1BL4mHbxTThOUcVbW4bsModUAFaaZrF7duf66FEH" ..
	"uGy1b1jifjFJDpDYhbp8nFmsis6KesVbr+Oc8gJ2Z1xIcXlmt0HycfWLhOQHEPyy51uD57cWEp2b8Q35lCHeCaxIZsfLpOXWPgFX" ..
	"P3DfY01dPoXl9SxVerSW5N+5yGf8jVp+Ugo3PIj3J8upQXOf6mSqzPzGOCHiHrVJdyhLmsiDcQhSpHFDSbpRkqd7EORlceqqZncJ" ..
	"0rqMA3+nVXlb8XHLlvY589ysfXAGymemU1BQyw+Ej0KxH3OH84LcQhl7fPksREPRuoZ+oW5nmwm1vVBMsrcgVc9fba7YVtsD+TN8" ..
	"YRKS4IZ1M1ajF65fIJC8hzGrocdNu/62fHGNlZokrPOH7wNeJLzWF61PMjcWLjC469SvFCX+c94a0GQGeZpUE5lzWIRRVoSKbAZ9" ..
	"rKAB0PnY5tu5YF8ubXOEPgO+WpOp5NEhafoGaz0vMkfQeRSkmj8fQNkiSCFUsxwOO1G5X4I/2jueiT1h+yucBKy2j9VCW5r8MVU/" ..
	"xVSIZBseZ40e+CIN/I/LaGQ/U1y3HCxw34mB7ilG371VJENc6dh8aHT3i+7cXK7Ri0R37UCpV+duciZzG7xr7LDVmkPc6R5Q8xiD" ..
	"aDq/rNtRbkJqBGC/coQ/oxYg/7r5uj3/LOLHwW7E2p6NkQShy1Xj6MyGQCeyybUzMNBy1Vv2npWkwkmbyGDNHuyjTH43JZY/IyMq" ..
	"xh0B7pJMM8TJuQTTGILSXXUZ/X0SpkMZe9zdnrV2Tk6ekIFG8xp4iTCR4p9wGITGKy4WRhRNFUnKMnTeduzCuA5jaiO66rLZmmRw" ..
	"dQKIgqYlSHSx2X/EKsP4BdNia2vd4tF3qjbVBiP1koIdXPdlgmc1Errt6jXy99gnCWhOqgAEDcNF41QIPbqW7LJmG6AcAcsWukwB" ..
	"wb+9OAwLtfwjJF+PvdkkHxmgqJCLLwmQvs56eEI8BsIUhCcFEwZ1N9brKdkNGSoQi7+WOOh4UGpwWZu+kz+/M0Es7gTDu4BOqC5W" ..
	"RVI9jbjDdpYiQO8O827JZ4UYx4Tsjm+3z8ERCHwMKzjgxeSKQMpHr00yAJHGZ/o7A1gb774pB12TvUZeXzVlEQP6PulHZmmIszsp" ..
	"oaKrH8Ry3D2qj+4hrJlFa07K+7axkImNw8uhARwcVzRIZwzeq9FTd1x3oSBVkHQica82wPwqOfejk41AmctY0LK8edG8tIzOKdm/" ..
	"JKl7YhB3pyZKbl/UKZaqjpVm3x6Kf2MWS5fHOwEj9SH26sk71oTabrYwhRe8p4Q4tVV/73/XVllcsVS7fWEXLfDfqiw5K6+aCcni" ..
	"BvYVDFcE0OI7Ogj36ErK69fUOzg9kq1nSfMDQ0etGgKUE/a+eVmq4egl1ZETqD8mssIbZ5MkNjpVPWEr4WkmtjU1CyReRTPzEY9D" ..
	"VD+NTYDalWfo9BN3hn3w3NHC36QShkC+7GC0lunSur7reTfck2vruPJpKL255iF3pZNKe6Mih5SupOv48rNGEH3XbphO1YxcIW04" ..
	"eYrvrENawtc5nvDYiURsS8yOSys8wNZtxPh2gTuOYtD3feOEnRJTWxPomF2Vu1D/ck9SJZmlo5hFSn4Kjwl+CYI7I7QqZ0w6+nWR" ..
	"SPRaxSMHSBPrw0vYQ5+waIgvOQntwGrW/L5E50vU3m2P5PDg4h0yOlUkiIjPJ26j4rNxSDM9pRdj1YHQJfQfCfnB2GUAZJCdHgzM" ..
	"UDPXZ9Xyj8KXnmH/RJzRDjduGMRq67QapuKJlBDbCFSde2Fonmo4YLC6n6yrodmLnIUkTHlHRPNBv6j1udhk1euGoj/BjjB59/Xg" ..
	"XZavJVv9Y7qbPsq8BpO0IAgmI2CdiOoeJenDHEuesUfnQVKVypJPVHH1A66dMJIgCPhK2STJ40EPTc8iFiD2ByfawzAHP5iVHsww" ..
	"M9m56QpsEbKA1pCSlqL3mKfeVyf7uO46FEwel9nvtk9yVDH2LTryuq82JxyUnq6IYPYjAjT7Q1KxogWKyaUVFL+837N8sYWr846s" ..
	"m5S2IEq2dgpfI0z0Xc2PdJkEjz1yFYm0ZHsk9XX62OTqmiZatupzzFVlawoU51+DEy5fAKEHtiofUlCD01uHNLmPaz8Ym/Dsx6dA" ..
	"XfuUSWkN2q+wrniSxjSMXIyVclEwVk5aGhKAoiEQUFWFdh1yRniOIIaEl8D2IUFVV0IYWvkvOJ1YjZnVgxKim2JxLI3mAqVmXkmi" ..
	"O/qcAVgijJkWxgwLEI99mwsetIlMpOo/hlz8vZnicDjtxe5B8VBga5hZp5hxb6IYNnsRTW6lQ5ce0oCHreG5BKWXwD688p7AO283" ..
	"2aV554VqsdYBZwm28zpiLjPKK4A3G937nky3NYW7hn9LApN8r1vd+BUMjmgCpgLnVy0ZJfuEmX0JBbhpu/vIFBoEWLa/lbgJceB7" ..
	"xW9kXUeK3iNbyntXpXb+X4iRPSGLv9HNiNWug2KQQFOnjqus2HWhvOwwnbRsEaTLF08TxfnN4YBR5/g7kBAXJMVuW+/8CccUnj8a" ..
	"fp9BZ80KPHpNgbcnw2RRtAZ6bYwguJ8WEs0kEcRIVxejtlu1RfUCKU9lQtRha23k2ka9yKpq4GAufXE/35JfTkkuvw2q8n6y/H1f" ..
	"bicuOCSG+0z7EOMtvKfcsg7igJ+XtBjRVzEmjtXhZHsQBjhuKsyAMu4R5BqUb7SLohcDkYe0bNzycHRMXAI+XDtMT4nObaXRqv5s" ..
	"rWzWRMSOZpqxBaLbjkogdJsKX9DeDouwMJVbvgN2PMW6TlA/Drv4g6ZYM9wrjxrxmoa7EZ8hEx8+JP5YbV0xBxaJ8/xfEQEarKbi" ..
	"YZjXECFgYuKSQHfjQs79LbqZn3gNxPAUNcgHBF0EZoYWb/UqrzdXCrKsiFrsPb/nZgNMIaK9O3n36pBRDND7YZ5wKOSWzPRi/jK9" ..
	"VDxW6ifIRH3Ay8VMGBNOm7Xww2rJ+j99WDDFfokXIe4rSOxsxulFoFhA0/Cja26GYw22bl4ocSFzOFyjQRK9zXyiksogp8FpDbuV" ..
	"V9xi2RDbdKxb5zUDi9lQktyMTlhjxeEXu1Roo+W59tN0Hgb5QvP6S5HfmqwAU39fMLGbIQo0D65ILFraiRKFmzcGPPifsJ1+ujik" ..
	"4UwgXMu+5l/iEtndXWs1b/f7S1ZrnhavR79bKLermI8RpzL7vlUEBkwsodTsAm463aLoHFD+zr/eq+jh/vsMAdckBmMPdIghRtC3" ..
	"hNM1Vnqgo4GEZ+f3UBBvsdPpwcE1xCMdL9B/jW0029T7CwT08RrxmylWwTAor48NbHTN/tcp5HJVbz/G9UJJELNoTtPFVDELrHad" ..
	"brkm7EpTG6J5BS750h63zOlCEVvdzaTFYm0h+ip8KgbihuXCWjmsXtKYb9dP2FzDA2F2cyPUM21k4MoiFMGLPxOD51r8iBHeYW55" ..
	"r0FRLajZMSp/Q+XsdOhFNQ1Smfib1xpkp6cnC8gJ+TdPMmzbQ9jFh2lvDy2qzsJ5B1xrmKESZFoP72DdlZ/U+ydPKVztfoMniwTE" ..
	"26sgurAXyEzvCCJORouktlwf0waLneMPusMXcZUkDCiKOgQe/ekwQ7oGmU7QK1aOLpyk+sBuAr3BXUQKjGAcDUPe7Stj0fVmIIA5" ..
	"gLAI7WCNivlO3lA1cG8pQb6H4RNoc2vY0esrbe/U03PscNpYNT8pw6bYOkdgSa+FcVhQ7twLLcd9jqzDefFEIhZm3YDQKyFxmRBZ" ..
	"AemfK4Y+uJXyN18OfCDtEbAJZsyTOKhSA8sZTfUmC5d6ZWlRX8/Mmamp82+tGn9EltWy0yL3eWDKWb9Ts4t86nVwqASxSOhSszmY" ..
	"rgZRErR9b2EN5o992yHjCPr9aW7sG3QvuJ8Zh3LnQsyz+r2PeHqAApF0+iIN1wkXIE194T7Nu8S+ZRgE2LQSLzuLS8aMTiSXuWy3" ..
	"G/TQoy1Q6fZGQ1cizjgJ4EHPKUC66mu+05uCixrzxny83ZOWJsZfGj0jTWZhbSkH8TRJSlFTRM1nBD1sjVUHe3iHuBKLxAms+6E0" ..
	"E7+QRxszBc+aFxDZmXPPSe9NLe3kQvK8+VhRlDnqc8xPcuGjHx0WRqfSrKCRCpkBzETejkQutTaN8GAi7oZpImKkMRFUM/qnePet" ..
	"eAYXNtY77t5vNym5RkO+LW052jlkzVYmPmVQ7LNpHMgCmUthrUbvI8ukxNeMRmaX0NeUkbul/i4FnMMfRMX7uiDyQ/bAXJT/AWfH" ..
	"ZBy40dEVcCldYev6vAgY/VpKorjTY0GbLo/7V5bzr3BV+dfxQ7IVAUjoPohFFq2Hq/LPxANFRaMORrClswZnX1b3lKo+hxgBoHL1" ..
	"h4W+GL2ZSz14ogIR6fCApsyIcwuadipK6p0LE3e791huAtjBA54o1png3nuZAJUveCZ6ubZ4uoJf4yRRBXwErqVnI7q+A8Gwqnkf" ..
	"5iXgXGSOf0q7gHWjaex2GcfY9+Ox3Pv2UKGA4C1AYjitsaYm4HZF04Ez4oAOocyNLhFVxucdEpzaXJKDRs7+2shMB6BQrW3ON+il" ..
	"iTgH1SR+ED/6yT9H8GjmXkxvbJWjvgFbMmXw6xWq/K5G3QStMhyuy9HgxuEU9KxNdkXbxIosB3RYoSPIHXBAOd5DXxHq/n9tF2bw" ..
	"svzvnmg2cV6kjGiQCCkSuy3cBk8KtBa2xyVR6RyxJUtPR28gGer9l0mTc5Cx7GxNhXS56q2pGLbrCkurPQUnG1snBfkTLtxbMMkT" ..
	"DE71io5PuZRZF6e+4gor1dgwcT5skEs0wqFTLrcGZIjjizYBqfItAAjBTtrFNV8HXgX77yjbCMDLIVoikpggK6NdJD04wVCg8gUG" ..
	"Mv2VNT+ngtT/IK5YJQ5TDanBlI/f8zJh9EcxpIsFZNsMhM9PO8mFzBmH5+7R1hH/6jgGO5z54QOJy/IbwCl50PdTPwss1WifK6IC" ..
	"jtnuJz/EAD9pnKWn2iJUMB+UhGb5LpZMc0KKC2VUIL17YL540f32KrXtnfn0VyxogcUwApy12A9Agjk8Or5IxSodf3fk6PJSpQ2G" ..
	"VzMVDALeSzI1mesW2zW01le5eLcwLTo35Mb1+luTadEqetLR6q+MzfYhgZqRS+dCSjfCeyDU/Mh9LrMJkuE+wGz7fF/pFREkcZQT" ..
	"r8zQNnqujGBuZAd9opX0KM7U3qZtLWtyn8A9zF4h3pBaMwsR1rq3oDQC4H+Ly1rtQ5qHDoVNr23RJqQrnf5dAYgCvFJ/uTcl6Xw5" ..
	"Sdvg06fd4z8sHf0zr9/dl80qLPFrqfI5jqIrOfvPXYrhobiMYkVEvOsmccdgaHV9qU72kvV+QVQqRnpuMMyT2MhABfsz+OFgD1jf" ..
	"3mbXi1X0+w3IxaOd4z91fvdpK1uBfVxeNlW3ErED5kNmtdZ9KyQdXjGmp0f+Czfa7cgj2wbLnsir+jhfEjNb4qv8y8WslxuxB2pD" ..
	"Q60abCquDueAcEHdZTHlwia+GgG/yRYNCOPrzQAI+r3wsO6Bcx1HgnJwPWnef+CtYiL1M8ThU3V4UBvjxs+7Kz9i/89wJvMCOTlt" ..
	"ZEE4Nx/j332C4cr6cCbhmTkejXRHp6/o8ELYn4f7FxATvpkPDMfuJE/k9lZl/HsQHL8SjizW2ng3/b6aJq3kDIehqm56hOEnBNkD" ..
	""
local PAYLOAD_P10 =
	"K80/XAcESIpcNoL0C9jfeEVJHvwm7F63Qqh5pG0xHZCBsGQ7d7htyTR2k3KBIYXYeScdF/ZUPsbklzdiF/h0cexhQpPhx+yYL1S8" ..
	"LcccgrQQTbfXgy/vzuKCxY9sAc8UH/L3fzqXJ+rZS5tv5PJpdrzyeAsKlXFXWBXO+0j9BX/GCaOBynV8GJ2WMFpyJiQZJx1AoVFf" ..
	"nm+zXtPX8zEiftFCZBsWL9zzyOVHrtPVEAqN9eKt/b4XUsbTksClEPjuCA2VsTJzFrdVylAYjcKh5y+Bu4ElJTRPJ/3ZPk0kfQoM" ..
	"QZKCSGleBgo6Zdb85drvgGBtg8Ldo1XCabewDBfPy+F+7X4RJVXeIG67CZgO7cZbPUIph5Ie636VcdJHjQml7ILJlcNmwW4dDZm9" ..
	"LD6YFE+9RKxcTv+m7ciMGj3IgMrN96uW9g86FqYwANaEGWAKR4abfG0TNMIVDLIWaD/vNTvCE0fTt0PeHLgp0IkIk47VDq7Iz6O2" ..
	"61G+osXfuq1/wwDEaiwjGe1gBMlVmuev9vs1oyYJPo9wbj3XDbOzJIqik0IEr8L1Do9LnpvSWA+6weQTkzqNtKe+40SqbXt7UXKX" ..
	"VCdQ0EIxa0Qiy25zNQnyhBxOzWzz/YNDmq9VuksMUVE+8umY3pVSs3j+kmpneMH6/woGMzfAY9eAsjNrJ1katSBnGLBTyPHXkGKp" ..
	"dVD9XD7C1OyhrGvdmNFv28iJ9iawr9nJmdTqUGcYnVXAme6gok/9EyOJVsW1Tl3laxLj/AAmfnGhZ/+NxX8PVFEclJkKU3VhzddG" ..
	"x2cc0CIWtM+QDngfpI5jA52iBugyQqIDRlryXcd7LE3rpBaAj9mvml6MuGgMHykCFo3ygiZ+5emdR3YmX165eh0kLqDWhfKd25YG" ..
	"CDCzU16LYbhrCLxnzz/iRAqoEUWJQhg75TSpb3IfAgHTiaYFHJ4/wsw1DXA/kdtXy4zDj1Vk77wYs+gKawZPVd82828czq8plvvj" ..
	"KbLJdwmAsRNNDwfgZJowIt4/eBemd7jK1VDWWoEFo4BAAyMtCsOYezLH+CLoog0P2oLy49p5YS3SIA+uFdKGDXi9fQrQeZBdtDWG" ..
	"VyWiufp5xn7fQQXNaGIPZ8/runiZsJByTLfinRm4W2L24Fw7oO9vLtFATKHBOw7bBIdIjegX8Af3BiHeIbqPhsDqC8ErAd3h+/gC" ..
	"7KKdA5uMhe3P9IVz5exVE8Ty/MBg8Cc5vCyaOsNvnOeHhkQj7XqW0hsPmx08mF9ApW7nZ9g2s+P6H7WKMIFysS7uDo709CeQnlon" ..
	"Ty7HDoaEIluIttQGQx9w9EIUNy3UNPrUy2sMbZs9R4rQZY7LkKdSxCbcIwUMobASHqUwyUZmimp+oPxnTqH4EuemCyPlSx68VBgg" ..
	"UpYwEdu6TjTpz/n4pEyEV8cvNpbm3FYC6zqm5yc9OWb3B0uB56AxuzkikmH+hz/nLb/1KZYSFCzlXjcRv42XqtL1IEbh4Ew+gSU4" ..
	"261SSqi4pUr1K/JbZatJtatKbI8M0uhNcnKpFcohwoejvYgiaQwxHBQFeGaQI5x+x/WfdEgpYYH80NWNzkEMkA/cCBSh6Rnh2Jf6" ..
	"PO+3R+OV1WA0yvg9ADbRsJpwAzfmRxtd0rvweDWzF9I1OwEhdVbHTM0e/SS4XLBqZowFJXu2Bez1iqpR0XnClXWgz4tSqG+S/t1F" ..
	"dFs6G2l4OieICWFBGzhKNmj0Y2vBSbmESPG3UCmwOX8eRY54kC459ix/fucvcskZHpNZEywkc6kdJQJvntDHfWHx5+FMiWf8sNhZ" ..
	"MRVT5PjRSdoCyS45lXfltu6sXozJLVCsfC6TVcUiACkXL/UmlT3J8BEZelsPEx2Ri0yx7eup18yeVR/eXo/EeIroroWnDWebwb0B" ..
	"2AfRhkhScDm2gKJCqH7Q/BnPV3xIqPptlvDRfmb3MdiT5lqiYHZZ9J02RZ10SYjVcnUGcCmZLZMMnC94uF5DrWNztNn5sf6ZlYym" ..
	"EgWTJ+NKr+pxiCsdZpLMi4Pw6hm3Z9YMS2SIuPzSbr26KIqacwKk+qj3+qotoH/1o+cok+zHVJBXtBxwKO9ZjEae+U8qyAHuljk2" ..
	"S3bsFO8onO/LBJwpN5sHyvW+B2795kLOP75F1832fazhO8MFauy+7//+4a3dG5v1odvD7DCxTBMUyrSXw7OjZ7f1l9O1S/vpYRI3" ..
	"BYSU1oSJ1FpORaSjZkpxuBjHYQhEBXqKzU+H57yo9BHsnhIHHLoGcVYeT7p74sUw0u39gaY4p4yCr/jKjAInNWFFm2rvC0xKQ3Aj" ..
	"KMMV5rHCtGSovTa4IlksVBAY60mn5fw7aIVhrERGDEKV9bZ4+eOKRRnaKB/a2XflXa6QHr7oALmHfKXZ7q48kxua0ANyhe0PaLad" ..
	"WFx41CZbvX/npvuCW94Or69BNDdRxFJidNndWbKxBTJ675+sfZaXaKfiucSI2EuYWwH0IAqCWAr4NJ1N9/OaZxnnhcgZ0KpbMHEF" ..
	"JIavfDCF6uIOI7WNEuUltaHDNf8p9hg+q7Kko4e2z0A+kNufoNw7sIPy+Mk6NuswcAaaTXIgcIXQb9+iYd+xSdW8qB7kQGghVW21" ..
	"t8r8bec8nR2JmFGfKIbnc9lptuJr33IMoI0UXI3Yl7XVoRU86/QyAa84Vb+34gC/oEwara1hcwEnUiE/V9DJyEidxkfgJ/BhIPnd" ..
	"jukToXl+XLfw7fuoZbZhHVZKZqjl7YknkI4ol6duQsi/m28lhA3vCNZMkxfKWKDorE5E1rE4QszlKKFEuaykdRdfqgGHA51fHui5" ..
	"m14STFMZs5nANbuDGQuvvP6ZmN2YeYiaIffq2RCa/UpiANH0ZyDD3HDQc7+n4vHB12RtIbHVEM8zzy1WTu0MZCSB14kvUW8TGQ+D" ..
	"HxuDDVqNaWnn6vSwUNt1Zqxuhfz1ddf9d/ZZVd53sZZgB234p/bTLUU/8T+4SIiAEzjfFljhA4Ymq3fQjV3bHoosNvRTT50Q8C3f" ..
	"GQkY8+SUJcgFpqPQqIpiv42vECbRo9EjzjZTQYqWiA7W7B15P/67jRABJtAHCeTa3wpjy81+psM4g2ccRFzu9BOlY4pjbMVJTcbZ" ..
	"mszaL2XXIshpRoG9VSxQ414qVZIOTyZsD+a2D9x/erKixJU65aPRZKWBng1TL5+/UtK4zjD6gAddLhAuidmC4rDRBaUrM/2cA2h5" ..
	"aoXSejlI4FOMb4ASV89S8mggDi83m0hJA7MSstSSuwQOp/4PtyOx01nw3r/Z4r/HGoAIMcPT6VgkJ2LuXj9Tzf5iod1++raObR+d" ..
	"NqexOMI+WO7nntnMd3l+s368Saf28WJjaYYxAapM/qhA8tAJEg2cwuJWSuVv/b+jUpd9CcmBrUbZVBZHejrTKtXPNEN6RP5D0iY0" ..
	"Kldb7yHtoD9mTosGl0o4kla8g7oSP3K8F5N4zqsN706gPdaZe9VC6Q38DlinGZg3cWXq6JCLRLboPp55XXm4bxDn0lpjI7FMrXWO" ..
	"XKZx3O6dPRhSwCK6eYJi05ZBNF01qyudQEGMMnMrTe+78MWciUi7WvXXhB5oWZYR9V7Qnw6ngEJ6BO7LXe7+vByIMvzo6VnDxpW5" ..
	"NgZ60m44F09wrMlFj8CshjHsoZ7/X29Ei9DmWnkhxe01t5vyirEOkMN/x0eqYTM9EOW/0RAfu2hM8wc/JK8UnhHjZE0maAxGb4+S" ..
	"vpE4091+Tr7XIe6Gsba6Bur+ki12dUchA3WP5k4074hDa9JH0h+lB9aG+0vPqIUTNRJGFXDirgo2mtMSIjHIZ8XakxDqoIY2jMi1" ..
	"0Z8fXNT52mS7DCMaOzZ3EZDLZnhIEawUp8CwRsBnLuL5/h7OCrVKaQGorn4X/vpJ4CzeBViQVl+8rDBgRVuhEeXaZaxZSYWpe0WG" ..
	"pP4JSEDzmdgs4R604RrbAwIr3TQC//x3p9iqzCHL/SshuJB8/qmyplyNrf4nnFuG3r4a5bss+lr6BPtYYAJXPR8Cuoc5nO0Jp2Q3" ..
	"bPN/4EjiOjm78ff4VZkH/4wVlP4o0IKudA+KgXITpnSVcoEL2D+jWMip+TQZtvpSi1Cu9plu0nbanz7k3HEn3YRvbZFsUZKbXORN" ..
	"sEvuLKG1Mqq9g/URHR6hQ6uzVRdtPN3kzYRxX8fm3q06Z2mtFwiqDmpkOg+8VnV/ErOYhPDzmEN25kyeFX7V0WPMsojHUE1POpm7" ..
	"ufSUhHcNkcPgIZJILJtzeXxaUshJObbL+bd49cJfTGuvt5lizbea2RhhCM6JZtPwQnEajX8fGQEyavhrX5HfzesFy9pn7FR0gGMb" ..
	"YSj+E3auIdhYBJjNdmA57mxHYmUkjhmRG3C6Op3WEq43AX8Sl2Q+Upt3gs4Jp7BEB2mqM9TTiTQaYIx2BMRx30pxBKYPY6XBbsjy" ..
	"/pIecOOmS1zS4t/TvRT5QOGZy9S25G3Esex14HxTMnchLHPoiol//oZzS2oM7aMTR1iYrkIr62osgRJQ37zueRIUx5YmO4+F68HO" ..
	"mAtSDSbBYrwo+w5TR6wOsETk7L1N9RNKYBFHxDyPQfYKWoSnYHEM21w0cwGO8UToUnBgbMX8OGzRnAgkqHIk5slq8fUN6VIYRa0k" ..
	"9HXZck6ytEZG6K3wQgjZyIaYfMA0ugnmKANH6gxYl4wJk7BAWf3s5T2qfQ+RQ+OGUzSYSdViM55mp0JZTYXdftNf0sy9pyBpd28M" ..
	"9UJCbp8TVeDL1YNiA5lYr5I9rYudkBrS4rRYLn7OoSiPfHg1h4I5RiTBvqKzbWzsqVODVhH541tqVe0foS0nhelyLui1QWSdra8r" ..
	"nAlDCuW0keA6m2tJHdBvnFPzHGA2OeS7Aqo9L4YhX+WTsdEOhS98l88=" ..
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
