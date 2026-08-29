--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu), 1 (1 thiet bi)
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
	-- LƯU Ý: BOOT string luôn fetch /main/ (không phải URL pin commit) để mỗi
	-- lần teleport đều nhận BẢN MỚI NHẤT. Nếu pin commit-hash thì chuỗi teleport
	-- chỉ tải bản cũ hơn 2 bước -> fix mới chẳng bao giờ được nạp khi teleport.
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
	{ seed = 1661270692, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1669110450, exp = 0, plan = 0, hwid = {} },
	{ seed = 1668677335, exp = 1788089514, plan = 1, hwid = {} }
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
	"fvkIGdAThnn+9KyVvYhty9xSQBdV0eiB1Z0PnV8sG+vr6l8ucK3XvsZjit+9kJv/OP9c/Nt79QxXjsa/8XdKFO7LEEqfOvSWaT6J" ..
	"mMDArQso1QXFcf4kkPWbc5A49WV8b+DPrHIO8AJiKXc+ktZLPQjrptMwfjManCkD+jlbhUdvkLGUcOVaWqLJMRfZQQa19cX6eGdo" ..
	"GSKApDbtRVQj/mUnFyCom/Z1B8aXPpD99rLkx24gkYkrp+usWt34bks+1e4EAU7NBCoWSzExbWFXyUsYrGl/zIL2EjabeCWWGEKV" ..
	"+VnpoPFx70L1vo5HEhtMHJ6nhh3Sz2U59hxcy0xLK7IYC1NcQjFNG/l3Cb2y4uSSJuSC6uMhFwZXEZmPN5b/TyckdICJq+GIbrVP" ..
	"wzgU4KOKl/LLNOZDTAFO6azAw59MjR1bDJZYka9FPkEiuhPNctZStr7Wa2IW8pqksoxRRhx5+cJ26l2p1ucir+lcal1IYcw+q5Xt" ..
	"kYuLZ4BEM4gUQ2hJwW6KXf41TDxMPwo1eY78egPMb5KcxP0nltzCqEkwtdhrSPIRq+fxiNIZgnu06Uynhm5pYCMnBD4VmOVhviV2" ..
	"D6VCvy7ugzJvuCF4FiSYw1NSWNF6cONyYXptYOG+qMCqhk53yPVHLHlS2dQ3DO2VbPvATJKKja5V/pY9DI9qMKhuVvJTsJWBcnE6" ..
	"YERwUa1jwyoM8aeoJHS8N9hn76nKuomimywXcf0an4XXiRDJ040cvvz/zxMTbwt0F5XowwQ/6ctUOXoRH7d/2TNH1wqJE/7wtw+0" ..
	"QbqOUgtLJa8l/pQwqNA4lTX3VMLLeXtaE4sLpdCyEUecgdXovoXWI6mk4/tl6rCfBGxhcGKv6eXdGDY3OYONez64zhFUvZlXw9eE" ..
	"Kx/H3BFFiOFXH6SkuiQR9vTf90sGp+fJGir+S/g+W/t0kQgLOabnnuqjY/NEB0jF5BWeewT7DUrqefApz7RW5sp4S0/USpQjWJOH" ..
	"OEu7SWvr49vlFdCToPn9Uqa/wD10oGZkyir5ETWO+zSz6nbN7NDdZLW5mD1/MLg1RchK9MhHi5pzoR7pUKoECqWqJV9cmYOBABqS" ..
	"8ER6wQtA/GNs8NhHa2ildPpQiwQY6UOULsUhZ98taiZs9PrUYZx7SE1nVXeB7irlUbktoDeWI1cqC9aWvh+xKi0Fhk4GxoJlYnMP" ..
	"MolS80QMLsWKmIA0mQMsYw4oGzcjM06Pz/vjfGypZb/lIt4vOB8/4a9zpgxP2LTyjAkcW6AEaH7V9opHjRGvtyU+gKitpXWmn1D5" ..
	"aGjZvfDbHx3XXIQuQCB/mmWn+gOBSHeooBN0dLPcWyhigBhh9yJVfLxYZvoLcvqwtBSIVud+W5G6nGSic4xMAUmY6LgBvf3rawwA" ..
	"RJiZ8kw5w1afvc5QzNOWl3up4CWWANSXu5+w9G/4bj1ggQ44KpzsYmF3MXMtpRinYcKixMkFKX0qnGENI3SO5U2H2MS+ubk9ut21" ..
	"Y6f143JLx/JKETdW99+A84ANn38ZbrlnJawZpOYb2C2d+iqEs51MpAnoPnI0LxRlQMLWz3eCJPr/RQ95ljVvR9IrfETmIriqbFDX" ..
	"QbEt4caixDHhvjaQ1hyBzwzsbPjPjjZC3zNvyCZc61HjXzR10be1pdHhcqBqsUR+NIh3kHxUPFAlr+cw64Q25kJuNcNLbh6Y/U4W" ..
	"DU1A8SiEz93p0ZDMIpbidSUB/FMsAdb6xkB2Zwo21PF9d0pELXWQRiOJIJebT9QTqKeb2W6vTMcuemELGogKQ4kYPkJsAD00KAu2" ..
	"EdE4N5zs+FTEu3+r9GsEl0Jo+YY93RpL2R6DrKjw2bt8tBuQod3ssq/35WeqHKx1AmTaMxonPZAMAEiVDkS1oipNTLlEnEQhdsFw" ..
	"JJLsPDowJAbM80bKKiaSZU4jTUy7rta8wBq/0MAR1fUGBNZrGOVEIJf99VPjGn9D2unFRnZqsAaLtAr/N1LcfL9OjjGfBlnb0skU" ..
	"AsHzFJorShq0MliSUFV4KyOmB8u9KQYWtBsaMDSAD3H5rm0RdSxIydJfl4OGrvJxwVhChf+xyW+BpZ99ap5RQsZGjF46eOEztnfT" ..
	"WxUh7hM3LkaQOR9X6pH1yhgrgSwW2p2GkHCWUED2uHuFeA+18qS+86CDjcP9AdaTv5jh4Cr4KlRcxldPqBTn3zvvB9U/5e5GgyRH" ..
	"Z3y2K5dbhQsQiplPH0kVNoXkAuBKXs/1ZOdf6Fvnhxp6YDCs7Nd9ScgtwBL5BY0pislEGngaqjE4dziPtEfkYJKu1ebGsQLRXonw" ..
	"ZFVUL0Km1e8cHwkfo5av2V+2FSTQ1zG9KGreuPqvYeXGQ9G0nWmF0pUkc+iCR+2qXYJnSwjZZIRtzDzeJC/pDmmRYKUEfa1+Anmg" ..
	"H5jXDcpyeBa3Sw+YdhAOOzOdXuxUguEKvWYYmcVP1kLtd4d66hTnn+BFz5YPtL8+JbZluiUdyfKI4ZCK+Ts/nswCniBVCAwS3ebM" ..
	"tUgSAOY6S9aAMmbGMQA/cT+c3vNm+Z7N/0WPyBguIvPu9b8siTGxIECQfd+6vsI55lu/3GDS+UmEYe0PvCp8VL4wN2inSbOkS8Ev" ..
	"BIaCoT+VNHKwdaWraVMGCAgWVxc8DMAcFofm19M5hxNYnR5k5M3vuxZSubASsRrCI3hr9FV+rGvL5W5xT5x8kft55C6CBzCaqppd" ..
	"lewbLFO/ZgIq0FivLtmargfEOBdw+WRK42oTq/SECQlvp84SsnxrsvwedCIM+4WXyejUVyKoHSkFgAjy1D+HE6I25NerD2iMItTq" ..
	"9KM8jbdp5VGTOgMf3ROE//XqIoyVW3nvxOk/JNef2JS07TRmojPzbvRiMkdlKhqAaSzrlA4pIdxrl7uCb022DpUU4DaRTX3g1XBY" ..
	"RcqL7rFSmuIMRrvMACLxnQ7HskKaQN6KrXp1urc/yUBprybXdAUX+F6b4NYiqn/BR7QozSAcPG4vIPBLZDpkxhDV+5rsvQ7cCfrX" ..
	"GvnHHPQW+e8TH9ZwMSVwXYNxkZ6GokHCU+OKXxGQXJSlcg1D9NVqmSV/S2sbjZkOyyK75Pe2MSUR/FtHITpIcRYiK7Ij56zSPdGZ" ..
	"L2sV63QK9d69PB8LL3p2o5RQsUq+XVsjAdYUkLvPjt5LuIzSHUGRrIBVvGQKFI9RrQhq+PSo4Dyd8ri51pVFcNt2roN8983INvga" ..
	"O4do3hBCGNyc+n3Wdp+rbjBZAAW2h8RMxez8piz72hAItqIR3ZV3Du5bmmwyO8eT8x+8blt931Mi0if0JYno2L5fQR6cWbFDK63y" ..
	"sCPlMr5sRsvp/hpSEi6k3C8m8XapntqFtUy7oJGF9pDyRGSdU2KH8wHjr/JiMVeeX1mNmraZYI2ehpBD4WT1/bKiBqoBqimneCF4" ..
	"pg81h+72XFxWObvxM54oKRkHWntIVKI1yr8H4FA+g8o754669VL2/nuyoZDitu10yENuue8qJDUovfJjMBcH1Esl9tx6pnSczXx1" ..
	"4CcxjC8M25XGk2yFXGIAy5UrCx9sDZ+eM0AeIkip2MMgL/E/+gI50Rvfo+D8YKeDrX8LsJJcoKvkaBuvTBMOxkyoSIi+U8QUI9VT" ..
	"5HPzD7oNyCkcYvaoNn7kjH1klxfXsXkj5oAanOWmCsb7skBKEaOdkd1Uy7/F5P8BIWYU0Rwthm8+ziVnc68vEjX9alKQQJkx+Jsg" ..
	"h4po9oZLCZJnJSKpac61fwyyqlX/0wWfoIfzmkpGFoBmheGU5tWCxE3ZYXceyM4Sxtvr0wDYgWY1L7zNKQLWLbrRYzgtn0Xk2/Fj" ..
	"LezhykGsSha+yDid4i3rusQT+wjR8nVmj9ZuTuE+v+7RJSs9kNVnhhtey4NmV3SuIadEgOOhYDPpXNpz0bUcjPIgWiz5j9eax6FB" ..
	"MXb+Bt6HRKUpYdEDCdBLsQrkyX0Box4Fi8TApEqX1cA52KSSDfUgw49b/z4SyQIPvhSEW+z3m1p9zSWS3im16ZAgD6BfXgkX+QbD" ..
	"cGit2jEdiQGjj1fx39F96QsybZ1OSG4EVqxvZoghcbyge08hbGkQ+Pm78p9sU09FIHu71GYzeMxT7nv0jfY7y4IMtkAFlo74WATe" ..
	"SpTDWiSfnyfjfkINvwHXb/7qZJyg/Usbw7Ayjc7phMVlF/ebHwW57nxiEPjl+EQXCmX6bbU5+xlEqSyPTGYKWeIKgXYH0vB9yNKt" ..
	"z9SiVs8QcB7AyfIS9T24Y7W/f1js3dDxEWHLDk8ilWSiSx4684gczpmAGPgh3jdUqy3HmSQJMWmgodJ6lS+1GlYko3pUZZrkDXoK" ..
	"8OWDV81ax2ZWXPOOxa46ncsSzDIGXgF4F677VdMSCd82s/lI3u2d9JJMg7Sm5B19rVcGhw2KOjGBoNJbnSARbrISFaWbf3AzXeIA" ..
	"0UNzid4wBBA680cos97V63ceG0YBk0+SzxTMTNQ+yAn/E051lHEv50+ejWjfD2RpIw4Esrk/qIEv0xFkc6TjGVGDWtlR3XWxRgH8" ..
	"MF1bxU5bogSs6TVxHy8SAtYMXnn9TdbMrVF+MwGZrhqR29Zp6xpkuw/kAmoZyH6NQW+tOKZrDT459CPL+N1shKTWTo8Kah2tIAew" ..
	"IWQdzchX7WNeal4L7JmAJuesgbC+WgwMEWNQ4/mavCchHXXMaK8lTZCxMNfSl6nqPYJcOCTWmzuBzGNX3omC+4jFpNSIG7V70GId" ..
	"M6o4JW9Uhm6bhBPnj/uMS8TCqoaj3DDc3XlrvfRdWwFKFnoCU1bwWlNg3VgaGyw097c9qGEjS5eunROSNY7W9sLLfujcVeo04pux" ..
	"NT1zRKi/kfYflgeu0VdGi7E4u31I4eYuiaJ0b1Tfq0PucGcXdq0xdKBDwfg3uwRXmlkfi/hb1i/fsCfCuMEVUPjZW7YA6Hm9UiEo" ..
	"Mmaoda9IovRwu+cQzTnKGTaeoISXJ1ggPY9nyOCSYaD95VGHngqdQh3277SnDyTIjVezDIcMKaltl1RsqTWpGXEbWHX8HAGE3GDw" ..
	"jO4y898Af/qS9MhVt6Da3YC2rJf6NudPclp4s6JVn8E2/wL0G004dCUUubIAGjsdSc9A6jFb+x5u8BeRMaigyFUjIscsBhC6ntCC" ..
	"Clrt9OSJ+fxkw5pgGeugW5hy2+st6M3zm1MILc426v9yiw2vu1MUoxJu4c+8kn4j/hJi2Qwvxx9iNRhkshTXXOBcJ5z4u6K/DBmz" ..
	"C65mxAUZriF6Ei0815puJzSuvb3NXxlRh1ACW4bF4WGsH5odBJ8W8Of5kGHqc8eNglDvULTUWZp8VkIC0gAzeOTOMBoHD/ZXYL+b" ..
	"6YmWa0ND0gf94WE22+hRkpatP2xkNGPEGtZ9gJbqVOuO8q5WyEZ2nIgkBBMUpKlCM3usuSlmuhaavnGzWdnzT374JNCEh/1qANMN" ..
	"uORaVBjRdDk35E+jXv6XZHrnIlG4kWRSHBUyiLPriNNIjRp4SjHNGsKtqr52elhb3L3fT8qaAl17Pa2A1RcdK1s5cOmmqJDZtNU+" ..
	"2TRsrPJSIqlkAQCgwBtnmIv2C2Q40jJcsjIZnY7A8S1KTGKDgTjpdCIPLdD64dXxegmIjfMCszpiXVZ54UaD3RCibYS9yUfQ3lUo" ..
	"/7aQDrDBVmyk/sBESDo2An4L6DqKavw3Yy8eHUhkZyB92msDGZnd9zN226Racj2Phx/4Ex2ljG/M2glR5JoU22sbSFBiosW8S7rf" ..
	"pUWCpFXquvy1qO9BAqvEb+0jqC7dR5twOJ+IS6K3qF1bd5yp8AFm3YEuFiFDhF3F+AM1P5qIixSevaMCx11uGZdYL/hPyWWh8mQ8" ..
	"saBnaav6Vo7wekZL5Tasm8e6GHfMceydaydibXUwVzHJEUPSg5Ei8JYzifJkaOlMxDqtX8aB6lvN2MhF1IsXTMCxXVqQZc5usds7" ..
	"pncDA3T5PkoCOsJPFNO/XO/ZNWKa4XYckEyBVTBZHIj/Rvt8MCGRNBtmKP4YGZpakeGP0RQp35AJmkY6rumrw5VU20wyXCtvtMKz" ..
	""
local PAYLOAD_P2 =
	"syvniMzzdiImLFxtZF3KD3UFw/HLApMqNC6xw9kw3X45QRBHmrni1hvbP8F+mZiUZ09YvqtzvhpsBSURbVdGpVXUWb8UKRkA6WxQ" ..
	"0XIDSvVh2ikLefAkS6A2SdWbUlBc4RTBdX32dKSDIeFp5WMLurL5GF6BNJaQLzrwLtlajJ10F6nlt8ut4W2I+CQd9ifWMriAdzOw" ..
	"cu5/xcGltYOJrHGTe2nBHJnBnsWL3XAt5RyTOBKYHK02ueDv+aKCpbbf+ytSGLO6lwI4TCQ6gEF0KzeJB0kduUcSdYmN3KM6NrYW" ..
	"/U/Dn4xL5uumL4glHHJTcSp+p2Tvej8dqukHrQaBYuUPVeUGuPr6ehQwSyI1/Fcm3IUY/beaoOr2adNmuhXYp/vGa1C2tHfksadG" ..
	"gxlAewWrgBSdRjasSzwxvH/hnxxLQZMNzen+94k0YWXm3CA2LjtsIpNVWHir/Lk6rNuIVGt6y+Fr2j1pu/XQZFIgj4uMKp3AAZWK" ..
	"mhufWcm/MMILeIyoefVnykifzoCmvtntCcjrFPsRN9q8dWdVlLFVWPkoCMvoHEngN4qt7idPkOrvhfb2j4G0n+NYtycJxi5lSDT7" ..
	"Z+qARa8Imnq/40pKxRw9wBA1pcqjzHsClhuNGuo2Qwjw0rlffrXyBPhLkq8YKkDJcHLCZmug+hM0F5c6BiXTsIOfXwX4R24Tot9C" ..
	"VimfXiSktqSYdfTvwtu5FWO+xQTcTu4/o6xQosWpGYKbXB5MhxmpINvXD3O6xEPWv8sdvXxlh2pkddCxzGCFDtJB1b+HN+nJ/Ime" ..
	"RMOdTVdmt6ftlTcrizUDOhUyrU5x+ys1THYAkd4iRgrgdr2tXas6QfAWvVE+vGE1Zx0Q7wWHZzctl/0Mwi8liMfW98TR375QDZ4c" ..
	"V4N3U6NLxEGgtDBRMBcPZcnp5ITXtQ5Lg0jI8nZuJH/4IFpAjil84z6MNgLanXRMPSwa1STGpNaMzcXj19bjEh5zKGApB5vojjXT" ..
	"kWkQjVjalmNC8+c9Tn1ASFwyFEn3kMkaoUGa0rnNWL7Mcd8MPf17Pvsnf2FDSU+OItgfL+hqAEnV4PjFAsVxeSLJ9xBPKBjKHgV0" ..
	"VskOc296DLqp71vrRDZc6j18tEDP8OzOs/pyktWDhozc6u6cmICPj9b1Ohb91/t5mqa1/ZI0y6knqBSLDq+5GSMX27W1tE5SF2t/" ..
	"0o8YHtIZP/ea1BRXstBOElJ9DiJrYWv3K+RQvIrIRSlDBlCZGFdg3yy3EoizsHRXf8kaph9BXrEzFkpvozwnP8GFrlsXAZhKyxvW" ..
	"WggCrVSLZ5vm6w52E9FhHyrrkUGiZ3frmzJExtwCEPEbvzryekBVjZ1idDkx7Xr3q1c6GhUnRwxtbAnhIa0pC4wGR/mBUD84yeau" ..
	"HNjb1vuD02EITVYdfhPvN8RcuxC88dbXTQ5JT080SxClKmRx7rgp6OJEjmnmWlDCVU6vOS6+JxORJxsdzei99Nd/oDnhfyMRmsXi" ..
	"7t0sGu0OFyipprkb00nTrBkjmTwfjCEZMa/VUulSkGpZbZiwHP0/RL/I4PEwGC6faoz5qMhecZEUgh1Huh6Ola4g5UKI+jtxMIIb" ..
	"5doKNSwTH6TcO/cxzEK9+Si7S2nG5s16siQnhXAuS3jIRSee+bJHm5Hg+I59LPNavyF4VlgP4EkoNLdwyEa2DNxXKd3TaBnocU3a" ..
	"WXDll21EzHK2SPB+0AzBpHjUPxYI7uKEt+6JWVdxi9uMfH9bvmW6zhWjUcnwuAzAPnb13qIysBu6ji0Hc1xI1ZLfZ6hHMOJwCk56" ..
	"cw6AvH9Uei+QyfQ9Y0shoYh38xz6UpVkbJmjyve+5t31oBx81umgmxgtNvz7p5FTR5U7/O8mZvyGNsXyTkDrNXY1w47pK+2DcFo6" ..
	"h3PZGBamrhLWfDypwCI5hDWjWHP3HFIj7BwCKo+RyFmCPOp77WTncVfoR75xdO/u7tx+cukPWDRDPrX5uuj4Loc3yXQY9165rTfZ" ..
	"j1udN9NJOBIjV/m3p7x27CoXTcj6uL1SuZDsi9bc2kNOfy5Lp6OYHuShT6H7MccPU9n0WkfZbwVUExYe62ObPUcZ+p6MRaAd4Qur" ..
	"QIMYcZNxVpn3XvnGmu24YlQaYT2rla6hvAYN+cm4bH5f4UsyWaUpE1G5e2kF7pqBC7AkOg4Q0vx/es4fnjfzPJrUHlfWt9xyZjtD" ..
	"ZVjbgCSA6wLii0e/I7Qccp9XGP+t93PPAGi1iVRtbR3HV0EjyDD8CH1epO6pJUrS2mnXRdG0SIijOiOWEV2k+1UQsA8O0PKfATlZ" ..
	"htiv0KQVl70NKxLF+bUO9dojbZGYh+PU+GgY0J6MzqFDggMo0bQely03xnG2LK1qHX2sXLlyVosWJOWg2p6OOkV5TPyDZyIDGcjN" ..
	"5b3lVWaH4IXAKTc3NxY5fvFH96g8ZkcOisc7XcqR+RpiiXprRkyrnznOr0YCbekLavnnP3ulAECPT0EeD797nm25cNU8SbnvkA8J" ..
	"u+gH86bBbl0488pLmlpmR/pULw6TkwN2/1pzpi8q+O9v7tYXAYavG9UTR6Ujr2m1Cw+gy7zqahl0vzo+3S2NtmB/D5m9sZJCmxXt" ..
	"B06IBLlry/KfsIJyelK8cyQ176kpiB2sisNM88BJY5JZu9a0W9AIRAtSnvXub4edT/FDRNBVnoek2cIMIRTj5nv3PYzLy7VbNG9w" ..
	"n9onsZm+KS/KCwjwnlzp6ZVqv7fGkfz8fymzAtUatXKRCrvzHi/pg+LgcGyKpp5OtTXBoN9tsZ8ws6sK2DhFfZWiUFIwEdIJv+qT" ..
	"sfoxLv3XjTqdm7SjY0aPlU7rKHy/wZoBlrQap2YNUBrcPv6eyPxIQ7umlJWZdp9UdSB1d3SBlVbZjfDk9Z/HZI6+zKolWHjGkln1" ..
	"2NarX8yAGGIarEKJicVRGQmcKhotSYylbQwXJo0FC//jFlN9iUMwyxexFJCVj1oM+7Wz1XGG0sKJhpzxzaoJRAkRvWLni6ZLJT6D" ..
	"U0I9cuM1q3/19eCo0tTIUVNtWiltfEjLJDDUuyET42Lf+Z3ie1qG8oXx32l7c0OMWRFa7e5iXUleLQvU+KdRhU1cH8R+BCGxOboH" ..
	"Fqp2kpZaDOmO0Vd2kvRtrM+yMcmSLs7BsG49juLB5RaS+I4icoEX4uNui3tVvsCdCqxokgaQMldxfrllNHBGPQNHsVY+R9VoDlsE" ..
	"QxiICtrCHu3om0MeziYPneJyGaX9q4z7h3gzLVjCRdjvhF/jEEo1mCP3oEhcrujahifOyprwxckV4H2m8GoRm0EAQtJBdhomE23U" ..
	"EQ1Hfvuc/uSiaj99H/+YE3/c0Jn6Z92xIoCctyYkTdogkRaR7UwiJVB+AY67ajPGMH2WC/Cte8r8DrzAEK4s3yS3aNL5iylUL9h2" ..
	"jjaOfPzqXZHrE5/Y+OCecuXRW28/+9delOjGaEC0kEM38/OCv9qLa5g1Mikun7tG56MdtMoSXi7Rg8TTIBwPQtE4OA2qzXxebbOr" ..
	"/rQYNwCOj8NJe1bfYIWrtbQoJc9fax2SRQCyPIRkjprRrUh+T/VH/D6I202zqXEa5N0M7GZsEQbNyuc9G+GwenSY5Gq0ujsqU7re" ..
	"hbX1wEHy2U5P+CPRVWiQKkt3bBAMG+U9gvNW0QwytYUYMOgyuQp7BBZJkRmBzMRbcoad8e5oWFGszNYRjBzA+6guYIWHR9q5tLG6" ..
	"N1g2H+6n8NXVwEmYygP6Z8+6AiClfVXJ9MOIfBv9UZCa7CsoOF+hnZ713gYL1bEoXle4rOmO6If6jWqFr3Qu0y51WZ7L8+xL7g7y" ..
	"WnQ0b2QVF/LpxOyCjs5SL5CCyp4szXpQ5ksLSrAsjvehRX46EcOxZbvQ/TxAfc1EAqDLm2sAOR/IAzGvmjBe5bTfxE4fD6bq5K49" ..
	"NfvzZmORhcu296Om+MJRiy7UkMwdVW69oLVvowqze39BfApf6VjN73zySzgp3kYdDnFV0n29hBPGxyZ17EBITQ9ptWaXEHKArphr" ..
	"Q5fuHTEGLqugTqEG3YwwDSHWRg1oBX6lR96HX6aUz6T79EWOaIA01uycEm+SUfiSdZWLKIihfc24BUja7Pwp7R4bgY8Rlqnau2KU" ..
	"4wY7XhFirM9dXcTJl81GoXQSc7+aeZG4llBF2Y/T9xrdEoDGJyyubf/poGHBI4fiLNyv6s+HmDkWl8BIbhYoFR3F9FkSS6VsZTOr" ..
	"JtI8bgtQesjeLZN48HQUJ6wispE+IpFaMNt17QvzjZMyr0Ht+8mplaQeI173Qi23hoYGcAbHAqjYzzY5Zajs/W6ApWaGcry9q/4J" ..
	"z2cap1nIVJXYEN4rFPzqXPMoSjMwECoPGXj8nBlfXPg/0FmAe58flUxHLEcXX3A2xTTHlTvlu/RbEG76GYJZ26XntZbefsfvfB31" ..
	"gq/ynsL50R4BofkV3epnqJchr55k2uOv82dMhbwwzwGJUG4Nj7SA0XcWou9oi5cVhNxGTbaYwCLKmxEtao5aSiItFuH9sdn0mRWp" ..
	"lzYjY+FfjjUC5fyadrqDLNfuYR5mkiteDDkgzrNXHvY2pl76ND7fw32zrTp/0OK/DHGHIFK06d9ou8fXgmXUf6AyFwDmpfZo5OVv" ..
	"UG8wDAZ/RE/6u9vmsOO68TtoVCK6BWwH3TxeqrE03/5NvOhMixSfXER7dd//smxbolGIhi+LYqv78sQ2kYj6GjmmCZfGyrYwtZTg" ..
	"uRCDldhgaqEGE7SSM16FHgc3brKaSgnMu9Aq1NWe8sFIO665yHPHtQtOpJRDKmByVx4vzVCjS7U6FVzMZG4SJfF4lZ/7ugXyaHuD" ..
	"PuMPaJp5JTGkWlxm0OUmWphX6I0YlUKAcaQlrMu3CHC7nP8qvYCbZFmtDUOrpVwYcQfKYJi3FoTPKGZJSl1MaGoZBYs3dgU0MpI9" ..
	"yP3Z/aJnuyIiCNNzjwLJk3YjE/hk8ciIXdOIcXykQyi4GarZhq0TImoHZwXtkZ6UO9/Oahvw8svI2Lb7ZYDyIg+922eiaPQ6nMsM" ..
	"GPcu3hctOIbA8pZuH03z+Dk2nd+BqsHrjdmjBtbvxZbfxk5dY2eJ9nbmSV4YtnuH9NoSdzyF0fL5ZdC21bgRB0kv9AvWWNmE9xDS" ..
	"Zzq0HQZwaakoMpUdiP3G+34WvRjAwjITFl4HZFiInat+j8pFR47eeGM3OvWapygAy/KNbk+zrAPPBRiBshzIyFr0OizavQF4G+EW" ..
	"rOerjcPEK0lcQO2mEI35bPvil0alcNIDijpmZxMOEr+aRRFxEEQSVdsOYNC8bEZ0yL7/8wC8JEfzDjUvo/2GDNoSEK062vZERbcP" ..
	"aWIvO35Phh8QtfSbskJfwcDaW5NCk+gVCUYn4sA/u+BpC+7QwMe+lDsLGzUEKqCnzzx1urzVLjeQCKnLqJWdPNCttUSYmQcAL/ss" ..
	"FrmL8ATs3LCXN9ob5ufgJyT3e2m0teJEnSYa7kaZwjKPclm7gaBVLQ4+6+4kj4ja0awlLmd6uL6CIGu6F6BI72sCl/QXdT7/TrFh" ..
	"nTgGIpnS9LPYwzFpR7Ha4SfkR1aKd2gwG9k1G893m/Ev37L2p0dmpx5ZAB7TFMJx28AneRwgPLJ0Ib371rkUPwj9TXt5wneyjKQI" ..
	"YJ2p2nnfAjvYQFeBF9+oE/zyH4RQo9JXJIpNgPyK2ccl3wEtyhEuHXR80L973nP7j+68klO0x6HQ3jprZmf349IIzHI5F6acc0gh" ..
	"yKP66pB4+24Kv9f0DXPuPVxnAVDJCGDTDaaeANYj7Q/lZc+/dgfU2qPmZehLxO3OkmR3TTvwuxNGBHVXYQpdWuEmsRmMs4dVY6Us" ..
	"4W2eRSmmE4gRnsDOlo4BuAby/5Z0Et1OXHY0KSzl/BSMPdEMqsBS/8M7Tr9mV6LGEtnLKIZ70uJlAdFzgbFYjlnsVzXEtthEd+Xf" ..
	"SMXw7anT408ZMbsSKKFNjctMpEaLF2L2koU8RrKV5Y1MFWmEKxJygnrgfVcNEhX5kNlR+NpaRaJVhZPtBKRT9s2KourUqnqdMVhG" ..
	""
local PAYLOAD_P3 =
	"uG9AA7lMydzCvhK4ydr38UfVWWpMIdTWhdLFWyR2FkA56Noed/GMS4aXRXLgIDE8pUsZakW8DD7XDxEC0qhor7zr/snlAg0DnHPo" ..
	"czUgaigyVbcF/VRDb8oZDemQjCF5b6ipKQg5HdVw9MVPzzFCH/mfLhYxFCsbA0Ir+OzAHX/BW7szHeV00F69AJczimU0Y12lYPzD" ..
	"7L7QEXisIV17qBPKsexl3tL/AA9cq06nkzgwKCWnC7xzo6xSD0yNDrP7VWL0UYFrNL6qA+lYtDr43xIBqjzYQyw28tovjoUiM95+" ..
	"jeYAzyok4aO1Kir+8Suxucpc95zSH+dp0fh+CU8OiDTMJw99qfJdxBAd2PhAAZzBXdp4iJxRMmLWp18vZR5a7y2XX+fbt0ysiEbQ" ..
	"tn7G0/RRg0XppPPVQD9cC3Y9cKZnXqNxHAEKlZ8f5UjjXM9x1usLoMrd3uCGInTKAsw/nObhtm52Fjx5G0JHw1BNqqMp/92O0WUa" ..
	"sw/blfaD1waSBWMAi+gU2uGMgfeeCc6lVw7G7kMJv/2AVVnxYTVL5/i5AyH42+CC8lFKCcTwAimJDPcep3goGVfGWB35PW3adeKg" ..
	"2168MqunAA8XPo9jyYZkp5IWkfdXhBU+UlYyZJxeDiCUJ2SpbWCkWYeUR05gHucqNNk5cVSmkDkGD7A3oF+epkxqTpQ43IRrDwqp" ..
	"vGEEScusf55n2BpWH7lFhGHYVdunlhst0YSOavcMbu2qJKukfXG5RRcH2CsFiXGnvZaDaB+gNLYI0FaleQ757i6ixZFPEFWGbLYE" ..
	"Hxs/xEeqkeMwdGv5G0Po4csDx5P/R/8CjuE3rHzbaCg5xaLhwT0mXLusSA1x7gDBxd87eVriSfoRWJKR1L3OYzoOUuEgCe0h6iCT" ..
	"qrYTQayIsazv5Z10t+5+GYlNo6Rv8vvj4ZAptGqWpOFuMtXOgFoWBArJBXXIW0RY88rTtuaLLuC27wRQvFOCATjgso++3zKvVVoY" ..
	"n6qjCq08MeQCpJKyZaJA34Yj8qU7BOmwtw0zgPVv4m+mBlG0Kt5z9HMMvUhj30vO1V6lDrLlxjGugQqCQVpixpo8Gz+H0XBbpkAC" ..
	"L+CR1JAyM2xE1QfjGZJ+MXlykRlwB4OiVwCxQudDqEYmkl/X0SxHbRNSFRFIhXhusFxegz/6m+aunr0w+gPwoGvaq9QpbpNMuggu" ..
	"4+ZZ3ePKAg3kQo67ixicNXJ1FPmSFriiBG3QiJce1PhomBVx7St7AMuvWisiQPWXS8x/Rn2RwG7ZxiHeiaIaGxr/7dTyDHzRuQQf" ..
	"YkuYC5oR8HyatXbULfaSFfrjIQq8QrhxCOJJ0KppRZ/TomahxWXHwKbu10KPYPwF+Xyp9S4dGgQTLa2CYlKlgGp0uQSx3s1IKIEn" ..
	"nPOy3YkSLtFx/C+VKoXzewNISTfv/L5KfII0HqiWZD2ABjt4WwXjJsg1U8PW7WJFzHEoaefj9FS6ZV/9B7tcpveV70T7oiNK5LfW" ..
	"tsZxabbTAMtYESV65dPoLVJwLuDLAuCxxByy56/pKzNL47lyTVoEvcbgUcWeF7mNEF7u6RE9Nve1v/dN6eElI60fxS1fi1MJ61Yo" ..
	"xefTHutz7/tXp6/5Ud/lkQbc+Ka2PgJtJC9MXVE2JtUd4NIxB3wLuQwro3Gr9NWmWMZhR6LMUkfto0POKgERgYajYguO5q5iCmET" ..
	"hVv+5HmfEavmqAFqQSs4rRyxvMU8WpEpyn/kR+NM91X2MOwljHYsHWcb7Fu3GJDxL03HK3sskWCDgZprhnlwjd90h1/1DBjQfxxv" ..
	"77/zIoLzLpXvlZ2l3t6KOMxIoDtaDxwoo5LrBxKoXWVX8V89fBhUMObey03HBOWI6aSE5jC2q8njwS/y+oNoE9Aoo2QlMI2AiS96" ..
	"k1lLP1gUpSm3wp/xDxX6mqwGd4xZc7B2PxgHLkBw0mNJsas/2E0OPc/ieRhRoLXIaXlNwtsAWz9gN7xTFA+0lZ8Kak/oTKYsnkSa" ..
	"/QG/EgBEBpYDD2sbp6WQyFWXvDo26Q4LZtkoJCMjDHGnEAeIFiEj1VMh9nl4kOFGqnZMK9Hgxmb5ypSokI7UMEYH7cBffH5wyKJ0" ..
	"VHwKbX202EQje97MTzU6vXDyl+4aGQAvPBy6f+rKgrQHria9DZc5WnzMsX4ruM3st1/d5YB6uX4Rm8qAzjMRX39aWXk1NFIiJFp3" ..
	"VXrb/2xdVKgqlcpoNA4xGdGOEzM3OYw0kLoHikiqiG4rc1eOONPII7mo/U7zhWhCdA70PlfN696J9tbW699ZPFl1AywcL2RLdHx1" ..
	"ZkMR8o5sYrJBcwkLHJwXgM7xRBUA8E9oPROreHxAA5LsTdHXv73a0hUDN2k3MjsIP5IU0SuOG5Mly/z1p9dDEeva8hakgTgQr/T7" ..
	"G3UiEg+M9sFrAT1fo+5/Tko0DVTePC3Fztf4WmKsRGU1OzJ/ExSyyGpE2WK8ld8cx9X+wdWGeIk2VAyz6srX4YXuQXInL3R2USZe" ..
	"gqM0Aeh6d2OsfuTFxRK6GSuMR0JCN4PMB76KtD58keuNr78041nDWwlPmYuU4C2ogTP/rP2KuUy16nkJQApdQ5/B8FHuB9NwAN2S" ..
	"IKANTpZzWC4sVrY2unogemax+vh9nFXvDjLliADrMWFinyHeNPu+0+ToH+eelF9Wt3ORWgTjozC3LjP57pyzxOvlWf1GUmuaCN1i" ..
	"Q6vyp4tCfZrUxEKbvF1WwKOewG3K2Nf/HJn+uyKQM00YNPsx55N+4Hijel1z/RCsJTbehbDarwuqXw7CcepzoMR37nMLPkYz8BXM" ..
	"hnLBnj+WhPf3ycg1T0maeHYUpB5JA30Yy7vh9vYXy5uAExH/SJIf0D3hsknDH7uPOOHAHuFRx9uTnndDHjBlmboG4AXRJ4mOwKxy" ..
	"MYPQGMjLslNfTJ5bT26dUySPguLrEm3HbEqy7TCk1HAx0+sQs0OZc0FjldlMtkOABGfQmq/Ait8JAQU0tqhBNmoetJ5S085lN9lA" ..
	"TsXPKIsLi0ehoxEVBX3LiGgQNfOLQvUqoZbpbYWTD2M7yOMOyf1rm5n8YUS4HIHv0FqJNTJAWEU+uDSFDizZxYoEySFJWLboYKjN" ..
	"fdp5ak6cFXpMxit+bT+yN0GFrrsOqk8kBLJH6hmfl2+V6ITE/qb7U5i6FkbgegnWw81hsWAwKbfXDg+zy+j85m4/XHttfC1sJVIQ" ..
	"uNnVeTOd+AYrvi+vFPkULfHa75A++EWcv68s1VPSix8Hf++gsaKqjUYF974H7uLw6TCx6VABR1KMzkhFR29GOYhLZOHwaBGJCuL3" ..
	"zEDdp7Vk4xBulaj1X0dV6T4X4aEb0i7jAemORtfG3JHylrPXubVWEItWXLP+k3TA9oO2TBoKusVFYGXzIe4id1ueT5nMmnwm5unN" ..
	"0f3ImbVYwItFl0Mb8GpqGc2AehfcJJXI8tm0r68ZeRO44DYyiS0uXcUE0EaK8eQW1bKm0L4TwdW+USgtTbulVVe5v5RfWz0iTIxb" ..
	"YIgr8zweYkbK5cZlBfqrf21WYpDY6EQQXlDdqrsg5ZjR6j5aUCVy0sP1ZyidRxtQo6cY+P4AnlrybcHirZkOHck4H0K88dqs8l5Y" ..
	"WdWmK3ZLAZKG2cFGYegI73H3WVhRG9litCyUQDL+SISZozJMvDAx1+fCpgfI+h87zAUhQhmpnz0G74WHZ/2fbXuFE67V0Buo1Xq1" ..
	"b1N6taD0QCygQI9pP+Bixg2boZZndQ1w6EHhnAznm3h25lMCTylaJUGkWFCCy8swJCiW9uXP38XI89p1m9YDaaY9QSy6ITPHbB4d" ..
	"vCGafM653+aCSgTZtqoXXDaJwqX8Ayh+OUWvev6FUhrDL0U8orgVwX5QeBYVwmbatNWgXtDkQd2sC4YOupvzEGWDdHkQtA7DmQW5" ..
	"K0k6mnpdf8LvTML+w89tlLwv4nHdX8HCy+/39V6eRXWan2i3pZJ/c/nkL0Sb03iom0IX6dLb1L6RXEc3AIMaFw6VtivIe2mocJ9s" ..
	"SGam3f+AvSz8rFlg27I2EKcJtsAxFzFHm6aEhpy0qBUIlAfYEvYdlVUyI9/meCX7Ftb2IpUNYBlFYtI9i9RlWx20u/yAIx6HbPY3" ..
	"bJP/X0UYiuOuiitkqNE++7lv6ujeuMr1Dy7HV5LoFWmJmBedWOSd4nPjVsKLVYUpj16sRiOfQ0MuQtvf7wgfQ0DGrdQTUJIxIevg" ..
	"1mJi4FRtfJUvoVoCR6toyJvm8qKD1gCwq7e3wAzOXskD5GczpHE/Fjp12jnq2MlssPq7NO18mGe8dmsgqXwZ0XVgNCYwBdfPGKqh" ..
	"RqoxAa/Uija+RytFcgUFktCPohVMpNOUuTpVx9rxPg+XGiFKTUXltx8yjyeKNCVB38wjMqa3SFLrPEmcaw/R4GGsR6OErqwLmwjY" ..
	"50gtmS3Mfj1YRCKSv1wFNZy1d3oTAEhmsfQSj/E8TRcsuIpzA4bZFQGVcZsKlDz5jT7lU092rMPm0mJcR1sCc8/Q0gBrL/WMwJe9" ..
	"48O/3mqctgN2Fs4m9zWJxas4IGYPaXgN20NnvVIHKGHNDPE1Cv/ZH1XN2p89mBrwZ0oAi4JaZ7SRbcbXtFRmlajGz1LSOB0VP4Fa" ..
	"Gq1j9w51Zbb/Juo7SStXgiXq4kYrc0T2KwmX0J4GyrTk/otn5AASFy/qugipgB5V4u/tOrnvifJbyrAwHHeXZ2DFrXhcnAIqybFF" ..
	"lx3Kf132tsvrc1yw9NKaiTR1VHb2XeU/RqpkEWkL69bYZoqxvT+QB/m1EFOq7vf0nmmv7pTQAPtlssO+2OxKjJWYZUG0M7/FPRvL" ..
	"Exukz/JrKd3637PvEDxqdsEZRHWBBGlBqnab3Ci2YBjiIwvzLWXTgGoIZ/08empkAtFP6g0rNMOvPPrJMt1BsUWFvjqo9bP8GtWV" ..
	"puKoo73tAhgheyGxONI+5ng7WXZcmbFiPFPe2TzQpGx3rMh74Sv0zVuDHzYxJCJAhaY80O5YEJN8CedkH4R9tMSZvA97c5YUgwgl" ..
	"8M31sfuRHD5gKtyHPlc/WkjInZdt7CDx+vB4eijPSMhKp3onq3/uQe3s3n6HZRiSu3oz3QPpOT+POOUkrchORUdGW6h4TmfweFl2" ..
	"nYSufsH8uSI5I9DNYOKmGYOL7qBNLrMDSCoZhtsopgndh36E5lH29WScLLtdwe+ufADFCsODrrx+Dfb17CO9TK4l0dt0nrwhODA3" ..
	"1FQp5HPgtmp4kJ6JCx+Z4GU86xmmwVUSclCpriysX5VW95BZx94sGWhTVkBnC2lpu9+Hb53WjEG8AIscWDlMfnlwDHKKiy6O1ZNA" ..
	"8vOJVTK+XBbzr09v8iQqcew0Jma9vSIRwkS5HljYfLWFmw+b86iUwMrxTVmoMfh78w0PZ3oeBSsIEUOJ35N/vSWHtS8M8IWIsyFm" ..
	"3A9JMWKqcrGmuq735yc7JFl/Q5bUONuN++9yCU2bUJk/mzA+RzSuIYZvcVfHRfaxccm21lEtCDPlIwuHXJQyJA1q1Pw205FM0qpK" ..
	"mRHSkUc2P41Nq8Hs9Fw9DXiv3CT/fF1qtAA3e0ri1DV/tXrC9mXtQZ58hA0z+NXOJi9qHtbOve4/aFIAM5eXCa00w8hY9SAlF6kF" ..
	"giD3LKrQf51uOatBKpQIn/P9xlKufmoLvNDM4sXy3IhXIbZOSmQEn4H+v/wA5oXwesQWUoyvb5+wQuQINv8xfyhH+t6t6H8EgvV1" ..
	"OLxtHmVDqG3I9O5wPd/a57adcDqgtuZ97f5P0nVd6DLFI8jYQ692YkuMTIUU3EJ1Zki8lZqtZdeYRGpp1c8rfm0jFj1AX9dy4K4K" ..
	"6PWiBeGiO8XbAU9FY3xi1VTdv3JxmhRqf2c/apjZnUKj23WD5g/h6GwiRVlzfXvoXpQkhjpuk73I6/nyjw4TudXlk0b7JOU0+07r" ..
	"isDhWCGDDk0Csorn5QPyIu1v4/gQFDsiAyoPl39Hdk/l0BptLl9KohHBew4IM/xTu+/9zIX2GlKxtk07XM4phYcJRUJ1foHeUW1x" ..
	""
local PAYLOAD_P4 =
	"aIAfdVC99bKXpaBSqq0x1UGt/szOQISlWMCMSnv9qwXHQR9IfjjZ9jLNFLG4WVOd25qajRJEJ8GqesOGb2GdKdy8afCpkZbCKhO/" ..
	"gof7RrQGIgMA/YS55MP2nPSnwwqCsdWy6CcDSe2Qlr5LAACYVDErKkJimdgLrdVlt3uYkuQP62ySggpIbA7kojch/Lu7uJvF58+j" ..
	"rvIkmIuLFpsKCDqOt2jpkvalTZ1S0GNnYyqi3P9IMwpRfLZQwcOUKOoEWxFGZ94sO3wjr8jHUJe8xbKMNmMb0b6lIlkMKXHsGA6v" ..
	"1VbtTQ6mWrdbiCQueSNcZa1d2AzAuAelULEJal14h5PEoPnYAAVCW3wGM718wq9o0cYdiKGiS7AlCrEofYDPvB6QOblMZnZqgX3G" ..
	"nk/L3qjf8xP2nIxt6Pp00QX5tiVIcItqWE6xZDCqHBUCUBZ+2rcMku3vCqIwfo6z1iIsABByo7XYQ1yi0ugWXdBw/SJCO10w19y2" ..
	"PpP6XJ+tkOvyKi676u2ROLvfPP0+YBb540qHHZK5UDhdfbAukJTjO4Sj6NP3WtJOX8leipilkIQHDRqfgGtdd9Wp4OkgrHJooUJt" ..
	"paqsK4auBaAMr2+6Whrk0EeFPPU+fTo1qEtV4EyNyQ1JADKMi9W8oSwHlEHqrNB9APPQhMCbWbrv00tvkaJcxfAh/EKgmZA8F7iz" ..
	"vwxsUznwDna8NNqaapCu4iVMe8h41vlKHJvJ1C2vSj+oluJ1deO+a609nYwfh4pUorPkv2W1z9HJ8UAAIsr4ZJGLyW+wDNYo99fZ" ..
	"ZVO7S36/Shmdt4u0tqv6FW8rm5yDY5B4X9x8aGf+qhTBsDaWYIex64F3oA05MB2XVi6pgaM5nxHwU2WLrqvQhA5HH8fzzMLXx7Al" ..
	"0o5trEpF2jP6WFi7jKEdUJv6oRMbiYAJq/LS1bBxK8bHvD3vLfqazuG3UasW1L3btrO97KWlUh+JsujTKkWHai1I6+QTXSUbTtRw" ..
	"AOTpFUr5eASG1Z7vA/gQ2Y+bsOENXNkPn8bZT02CpqLXlsuexMEhNF2DLmPDSj/mTySKO1gPvOXJPQ6lw6vfoiROrqaSMe5bnNFV" ..
	"VAItKsQNbzLqJ/WLE/0da3LdfH0/PpTGJqCMZC7kv9IDdmUiJwjmI6RURiKE2U+Z3risS26nulWHPOeuK6UzHBTjC/xN/9IcQfH4" ..
	"9VV9QVe7hfHWbMAeqC5LnH4qMv+JHB9PTqlTvzcNM5vjcxQt3qc76h8woBlINp6QSGSlfUtlQJ1nOcXFmQBXIEaqg8rNO+rfns1d" ..
	"fuzOUP2JOxpzw+TUFUjFC08FkuGkOprFAxf/G9GnS6bz09l7q+sixS4hfH2imPijQ7hQ+Xt0bNofZQlgrczdB8ojIMgMd+31po1w" ..
	"k23yRoxeyCLBfj33gAFPwdfjYQw4Cg0ep0aa9AK0e8s9S9O0JOMDZciUppLDrjOLjyZ879j+BaRyjS3xgXjlpOseMjF9E7ERgnx9" ..
	"4kL75EJQAajc5LRo1OnUWPWZ2cJVokyF+GhEdXJpznj2DrtPWGHYaum29repzwPED1dwza+FMsDOnCdFlK089cXUGqPRtrvxaS3l" ..
	"KkgpkSFqO7FGfDQUHqvzi/GXZXfmL2XCoL9jfis1r7xWzrgVuP1l24Hl5M9ZzIPolucdHub6QT6eymuiUf5GkfUyWGTgS8rcA3KW" ..
	"u8jy4xfjB92FzsTFWczzHib3lKbawXhFIbS4Pl7Khv4J5L5CVwTmaW+gdXMDoqKJWNkQ2wrIC3+om6yv1hCwLRxKqiCeT8zNCTvc" ..
	"YS0Ut8MFTRwljfs7cMTU49hCWPpngIaQURa6UWZguoaHHPmSuJ5quS69twzE8jihPBzG6Sms/TkcD/I8xwAEqWz6dwvlZiFn+ZxC" ..
	"rFwVvQ0Upe3LkDz4p4J0pOym5VnfaZWn0SpoJLpEoPrmNPagZ90g6Qx/Jz0opcgwbWDQBd+2wf8G7Xlb24BhH96plTgiMSowLgL6" ..
	"uLkeIu1NnZB1oVlMDEfbQ1BhMSGFlL8zXIvNKLVke9dR8KAXQIehSpDTx6tLpxPpMuOetIa0HiIPrz/6RdT1JhXB+qxEzHlP1ANB" ..
	"TyUn1540VI83OcZy4HVZPmlQ8vAveCAqdpbRyvwRhl1vNP21zNkZkTW4N27sh+gdHZgSnAh4y9uxIE4idzL1yTyqusZMfO1tLB5T" ..
	"zDunIv1EDjJT9M6NpGBECuM7Xqm+J8VS02tBehvnc64o8w+c69vm002zOB5SHajTq+KFO/qU7augqzWqGrJE+HM1qGntxUy8q8CU" ..
	"q1/TMWzMsBauQXE9iSbTWH6zRpQ5Ikv+K6GJkJH0YKTMK8oHJ5N61arQvj33F6V9C/ecxAqNi1qtaAYN0r1neNUgmv0xR/mn/pkA" ..
	"mhsGCqQ6qi936UJDPmqhUy2DkRDcOk8ghdyf1GWlcz6aoBY+CsjzepNG3nvBQSeWlL1okvzMXbVt9jUJwDgPCLuOPXES0fE0xK/N" ..
	"uhw433xfrVPW7et/Qp/lpGQkdAZoTcdx07IrG1PF/wiwjxICplxhRr28rE491BORvw99NLOarLY/ZIS7b770Ip7QRL0cUG5BY6GB" ..
	"sKQTVqW2bgzv0htk7VqdrvBkc6W7lzi/nlAj1hJAP6CKKRIyun3EJlyutfeMUJ2a/aivg9Jb0tlgt3d+DBOHsOvG5eXn50exoJpb" ..
	"j0qDW4gJIvJQrwpVPDGuwcadCCkbvsB2ERiPknqZENZst5Rw4IwPdjSmWHN21b5v72RJK94g7obZAAXFora8MvQ06vPdKC8ZfPMN" ..
	"yVSmBJs624K64NKh0MzREoo5Jc+3eHE4/YHhmCq3nzch4W1hMMvlwS1mLh1/3Fw14rULMGR5XqJkjBgBMnaOZlPMnW2M04Qe7Xbo" ..
	"imU7rnnCXQ+5V4mYPJFm0ZxndBSJelKl1hDE+TqW2zbuNsVifmAzpIuYSnH1ufgX3GkF8oKK3UdKOO0IDSQBE1o61ts4uTpVHgcn" ..
	"TJRDJ6HOd1uj+RoPO9NfYaUwZHs0qD1RURFBibSBqTB19fZMmIc+jiXX8KOqZTEeSNmzOMGAylKHu+9WV4tAErS8LE6FrD8Vlp5O" ..
	"uKrlemDTgmHIBUxKwBnHnGDCvz8TH5M7UMsCLuu4m7hSbHdAj1tUycWpx2D+ESR+msGP+EY7A+GgTvXLMuVrNQisihlzZPGaNew/" ..
	"xCQ0YGznl2D5OTLoz2+u1Q5JrTKwI5eCYFoRJYoJZd5RNKrX2gL1evRPdAOwIsRCvzsr3fpJuwJmYc+aQ5o7ITenl7M149VoRol+" ..
	"0Qwt5rA+wy/aG5hENwhF3s7zgPpjskYfYzdHtu75YNrOqzFk+6TrRSXMoWQyPr6fJNaISUHz++LOdFbEh+PIPXXo0ESUv45LRddv" ..
	"N230IA/CVePWaNm7g07QxGQo6mKGieObPpqs0/9lZyZQ8fUaDRaruUAPGRA7fweACYRtBqdAfvpH8GDUod5Mqu/0jVPpfYAMCQoZ" ..
	"eHOhZ9cO3500mF2S9edRxEMyFutcuNMA4/p4CG0+iSPfB4mrLHe3Zbv7IDMm7Dxis/0OCGFXeDAij6Cnz5OLb2izmHCSgXCOMAYd" ..
	"YCYKhnKQORVmHrvJZKH4DnsEaFKwSGCV5rzXCreucbIrKzoogjjTDD28Zo4eZHf8/rBD73aQWnrSz88zwcnYyFTWCFsu7HiGFpj1" ..
	"SJfuTeks8d7WGgSm1wLAbDj41rrvjUxXk3xI69Jpj9GVKTOLVsIX0pHjU4qKNy21Lb8dcf606hC2WR4bzhXcIph7UEQ4a9UubS9C" ..
	"/yed1y2YZaX6jrI+xUZ1CR/kYAl75cxn42DJPlCb/s9/dsqvagYS8dfIhYYQQmom7p9sUkngi7gFXMf7k6abYUtSCklUe77c+EQ3" ..
	"F/bUGPjNiC/1+feLK1fZSxs2qIyiWNny15y7RHCas2NGB47FUjTLJRi0YF5zLAJc0QpI1y06DpijaP8l1/wFXQtvU/UxeRiRsH+P" ..
	"+isO0DRXPOHf2NyTRiZvRbM86LQr6jnAU/+b9dSP49uTENLZD2Rp3NTl17DBjMvC63jQ4E749y2LASl8M5L86qd8sMHTmhBedE+J" ..
	"sJjQfMdaLRdxatROdAYlM4RR0bqjw422g3cKUK0lUK/UTu1SIcpTx8pMQzJrIXRQgKPEY9q9bhUWLxSBvKBN5634UUpxQ86r7HKw" ..
	"B9y8RWTdFjaUvS32IylOOVVGD4F7NuW/9wGO6zs12j9PyWcQUuodTsUiT/pKliPyZoJNNYfrax2H6sUX9cISjjte80wHBQJhNMLs" ..
	"DSsxpbryNYbY9Kdtp47PCfFc6UkGhoJtO814s7eXtLNgFEkmhVUsP+FTI8L8X1t6TT6mIlS7Y0voyqTNHmhNzCJVpWTxNH/kWkxs" ..
	"fWDuZlN+FLhk1zqKQI3vNNM/2DRwfn/EMwMQWUk9KRGUrTOn3LO+iiXEgjiB29pO8zwBu7MJju+5u1ZirL8sL279yug6IkTFUPbz" ..
	"JPsNWaUW3wsnZXXxrgeLFIv4t2yWucwDN2/FobeAK3habSQ1UdJPapa0NBEj7zRLoa7znDQ1oHoweApBwG/0khQOvDsUxjE7Unyp" ..
	"OtbHhA03WAUDMAbSm2928UIDVL1bqRD+xXza1+ppqWGyKqvFecGUg3+VtssIVNSdV4vTFZtVZeOA+POpOo/g4SWg88XMZjakx/6E" ..
	"QHRI1XLReHd4EnZUpPFkbVvzk7sL8crCaqllVcY/azL8BGN0En6U1l82TnH42pF4uvcz84kE/MgzCw2nZrSlWuZhnAVhggj/Xxxp" ..
	"jYamjXygqf3Tmlx1zsAma/F5kCZSaUWRXolFPinIRD3eEx5ZUB/lc0zKVvAxD9oyT3rQMZPM34PrX5UzcnblAj7qdM+olZ8znDMC" ..
	"/nrWClBbTPSqjJBBE+MGNFyjPKMfWEKHzsBOayCLaUQ0X41PZBmPEgJNZcE9k9mTnQzIA0JaTgFWOqfIYAwHPbpO97mlbRMEHta3" ..
	"+GUZYpBQ5keBCXg7r3zs5sYnpj2wNTQK5ETQROovrk4Cr6zmotxDMV/jz3r5V2X9yJ5ErGz7lVVPlqfepvfDNMvFfRM1nV+s1JcA" ..
	"3mPNd3VgFJqmZCTjK0L9WyJZmvbsWMsf1bfpiBEOKY6J6iQAjDnBLgJm+087Tq0+zfrossEMPe55d7I5OvCxz+sElwfrlAVzleUH" ..
	"8Cm/2M95IRC7+GdewgduWpZgR+PHf80qyjcWX1wFs0VNDykNKSK77yT9JEZW96Znnqia/icEiUEk+6pVePn3LmuIfimH/IwjBpHR" ..
	"m6qV0BLBvKZNgfYYo11cakGvDPnR2Txu3BmGhyVZ7NXmJNyNOcCC/9e1bTKMNqFq0wmlIMA9O8OmLs2bH/J1WWCpt9bzQ9i7mvsE" ..
	"eo5PnUg0SPq3HlY2zmcvOdYBCylbfvJEIdC6vEpBbD4fwYulxKz8PCx5P01YBt5XHW++/rt4RndIM5DBCEA4U/6vVx8fMyxTtq24" ..
	"oC3ZjOhajmemCZ30MZ2Jadp9UTOOv1pAorkxl1ZwEzulBj10DbcgRTkspBqq7d2r5gI1WiiOOSdIx6+SUXcAajp0cmUoOyQwYdYq" ..
	"a3lVrVY4iMGYY7Dk2Zoc79x4utwRGkrplQY6/IanSstITeSdQQYHUrbnTGftJmfhTTgNBooaSdTpXKB2w1JE985BVmk/V3H1QgK3" ..
	"5gqQuqvrFJ1Y5TzxadtoBfWpor8evLM7YJizLoPMvMRDUo1z/iHcUR8YtDVVth+grkGkRHCa39pQ/53LVOQCOlIr0FF2ZIavOCqo" ..
	"889ylWFIXl4U/eRpSOKcM38j6BcfWFZEV3nAa2WCegJL+mjXgkrOeaxyeRBFaQcQ8VinP/F7C8xX17Chnq6mLJNJME8DBB2e89Nk" ..
	"9nFrgNTixT0pBJqQUHOVvfQLLstVQsd6TLHFnabNxWHc0Dw6sLfeXopmJvUFuIV/0pwnYaitOyuB5QM0pmD8nE1ZOAHRPqBQp6F9" ..
	""
local PAYLOAD_P5 =
	"nLhsKnjTYKGvfTtpw1z2SQfpign9fcSpSuEqTq3BkBrbluBiFBMcJkqEPbhUTDupvD78SElvLYw35EMr2IIiC1IlRbPklp2PMGE/" ..
	"CEu3FAb96jAi11skc/ClSvrduZi8x5bYdScP0avF50cmIiWaACmJILqDKrb2VSd7LENQWHTnkNLO9pzREZ4hibc7oLrPIVsH8wqz" ..
	"O43XeLVejJZzr2v6HzHaP+AvYl4cazAwFDIf4GnSzZpW25YO7COk2RqbnVRhrk5WfMupLDOfGlVMPN70UwwqM63VA7ALqza4qlYt" ..
	"+RIe1jjs4601xIU7Av9UGBPsEEnvQDQvHZzsnO9o1mn+1WpjpHrTd87M98H9bRBPCvPofPnyRejhnhUoJcC6I4qacDuPqLTxzX3/" ..
	"voTf1of1RXOoftojvINU0C/tkCUiX6YXYLqK6dhpNGpN4FeyAnW7GNC2EF70sNecGFK6KSB2ZgOWFp6OTEHYuOjvdfKWPW78ZxIf" ..
	"YE8LrtMJquo3Q2saGEde0uOjObExIU01lWCHGTD/6trBagnf04pQRJinfgtuq15UZ3j9voioF3RARmNxXHIUVnobKeai3IvashPm" ..
	"2wUbTuygRFcZeZxJ1kl1bQufmzyRreyr1w3YVEZBdd6aj+Am7FxMSEV/46yvvVZu/ozJkLP54OhgS605TvLej1hBj7I0ePbMntIp" ..
	"ho07JfAmlSmPoKkOlDJh68dT23i+n6lt0f+xCxVuEg/vL7/uvsg0KX6LUHOa21r3k2RkZRwiZWJrGpEvhwju6v8qX4MofKVoN4Y0" ..
	"zZ7lIUVPxM1tCRw9oQ5M4rZAPKokofGxfrOasKclO1riyBI8sohQdyWvhRY/cwz7Y7CGIMW8TpK3HWV495hecuctQY8KDuSTEv0g" ..
	"imdAKT/ypC+jHs8ZIcg+eXsOEVn+cCGRg+WFsnixDBq3Ervc5T6/hEXzu8xAKgJbKZPT+Aemy/Ywnf58JQjVlbR0zc0Ce66X4Lmz" ..
	"6Cdhm6ZnPq95uGeXrixHa1DSV2y2mwIAGnXiT/KWgLjp/wl9BtQnOzr2RbtL83zhDOyHo/qylJib2GRiVoxStQX19SofM2Ha3guV" ..
	"cqUEdBi1PlQUlyy1lafdSC2Fr9oL4hdOteGlkjpr6qRHJ2k0c6t3ar0zSma2hVaJOzZGOL9nled+16IF1y8R0x6DdTRcKx/NdBny" ..
	"jmDm93R+hTQu9Q5i9IjQYlln5p/s0kFLPad8S3LAQHhBFx0FwVa6///l8q9AOJi1OilUczHHGGb2J52aPKCaao8yue5RaTyBhq/V" ..
	"/VUIyAPvT5yTpiyXLxk0rtvgKtEgMPPP9UdipU1RGlXkiINeEWkMuougdaaXGEuFczyux1o43m5ppkCi/GC5l6NlxEskDEiNgwQo" ..
	"ZxUTT1v89XM5pWLNaWa0VFhFf2Su1Gck3hfCaBdFJvaDCKAUfSad20aGbYh01coGDPVoiS8VcTkaNGOV9QMU0XkoKxQ9qxkgCcYd" ..
	"f1ra9j881g2kITR2biSfjjmNFJZVAKd1UpbmGQqYTEKZ1rOJluozjKa8pv0jkA+kpe4gYiBwQPFVwRu4bUUp8iOxESuzSHb46Bj/" ..
	"EdJavtm7CgHMJ/2yFxC0Z1gJAVzVM1ObiFMjetoXp7p1lAx8URmDfGhc+vv2fXvNsdzVmk7CDbiOa6qSbdGFxRqkdW0N1mq1nRxL" ..
	"E/7sJErjmE/a8JBD6FjiCbgqBaxeETm10K+3Z07qr6kxRNxXg5RhCXBNCLf+fqvJhzTquQ5NCYZgOsqee6mBfzRxvrdPU4KkxeOH" ..
	"O2d1x5o1majraA9Aaam4BO+T/AvAsqN538tC4tOOxWMpe0mHgLJmmiUS+FGN2v1i7zzF+N7pIw0SP0XqSUl/2ZOZVcoICx/eCh7Z" ..
	"2/IwRVtZg3eG6O84D7b3JijlYGMIrQ2zQcSLptrFEvtlrCgtnS1EdpJ8RUF7tQRuLJfw6592B5UqVJ4Th9qA3lIV3gvladvOQn6X" ..
	"6NQuRT8Q5zJYHu4ECXd7qOOyi68Yv9pJi8sl0cGe6568bpX1xmdpu3rxAaWxnM0pEQHacDNfOuILwcWaCB+7AUzH3cgo/DRifFU1" ..
	"1Ya0/uPA9eD0KrN2nb3ZYuXkGSoDpp3eg5rnKUkvh4beT6Rx/JEJRiizBuXffFDxh5SUtjICaETmmnPjIA4mUQoOu/689tYOib2B" ..
	"juqUVpUjAMnqOL4e+rT59sMmM8livflBjfe1qzT30DAH+rpRVErlK+FZx4kVBt4gfoBd3E/fE/5tUVpsrN++XvlnoP03KJkUa2GL" ..
	"Ci36rCrUdYAyFeZM4gQjYzwbWh9t/kJBZctRsvhAa3eMtj3/lkdSwv9RJpTeRRHQXKJFKIJhtWE6xWeeFcOQ6HiIgfPpQuwlFxry" ..
	"zzZbS5gIfuDT2iWTefmIuc8RUfETp5awsvm1tJgcVhMpb/ytAjfZWB2xMQ6VIfDuwZkop7yk9Vo2VAF3R8TTvj9S0oqcGeXHMDet" ..
	"mJCKZqnsfVLgEuFI9qjSzGg3yy0wdXwn+jtnAMsY/QIVTxui9f+SwKLeBAac4uSZOWW5Nh3hbPn6y+JR11zFuTtA5dyZVlGTWWju" ..
	"/kf2cvQGKKvTPEIn9R/Hj292A41G88R969e6dCSAjjHhkeRoYHxAOT3xzKWYFMpyoYOuYBghLG72F1YMbrvgfZYRB/Sq7DdDj8zH" ..
	"nrdMM3vg1RGO+WQTMGUCJO7oWyZi2HIqiLpHoqlZjviauGV54KakAv+d8gQRPkEvoTiFohRczj5BPrRyCu7hG4oxKiBm012lQsy6" ..
	"SYQ3g8CWJeX7ol+l8ZEkiplehWms9A/vaafr2iZuLKTnxAmxHQYM4rxlElAYiU2O85t8QY2mwsL050v4ZEaQbq/+hpgux5Z5f/ya" ..
	"35DJIzBPgb6MAPKuVeEZcXhCDnyI/Hc0Sc7teAZx3TQ0gL9aNTSOkuZlqYc1P80CIIfxHmpabFER4BjRu6RvRGMieX3An6/ZTO+W" ..
	"k51urBPHfsYfQ4t40CErOHFSwV6RazjXHdQOchJA9Gj3hijsLQswZS33hBTBmJIPB+51C/p8Q+YA22lbXz83UPnP/TsWVl5bWDsF" ..
	"fK48GqG9WAX7WGMOpy3f1UTNuCpa7kA0KqImiwv/r5SzUosPSfyPhHKhrU8Lpd0apHQFiGPh/0BYlHFIfh+lamxMgoAqtpk/l2+o" ..
	"FDqt7xvAQcZ+jx8GcHYndht7j0aPfF0m5ebnQHL9L33u6Ryh6e4TX7GjkeuqFttVqo6AmvTnGwt5dw7WUXwJB22FoO+H2eRAXeIk" ..
	"QHjc+L4IcCoNCiCXEdrqJMQK5zUiseoZrsQKls5yKUjlGzTzn5fq9M4wzkFI7H/TMJfYhMkwpN3S48LnD4vsn5j3PLPuS3icbg4L" ..
	"aCwq9m6w/iCGk/0S01p+XIuyvX8VFxZ8hDQadoxZW5IdsZlIqg2ustxsvuhbPiUq87sR/Wy5hy9gaUdXEiXl/Vq/I7ex3jAMw7Pi" ..
	"JG/Ovvx8vUH5H8G0Mdy/CuhkQQChSlzQLCZGylkxRVig7BPZO2QnmTNz2MC8bw+EmLPCDshfzp/fGskF45Q4Z4k7JHf8SQ4HTI+R" ..
	"3oLX/4Cw9BZ/PJ4+/Cz9HVE01iUeCFWH3At11C6sPhc6xE7D2C+ULzb9H/GEaYuzsQy6oX+Hw1A683h9B5cqFYTG/V8pvf14IRcD" ..
	"PSqc/x5Bc+83b3VgHqUN+7w/ahdrEAS0R7gaNAW2JGams7o5sQPeep2975XmUvZ2xOcrX+KS6L17vUaGKdYQz/oh3aVdEMbJTH4W" ..
	"yiTuI4cZmLpDRMx/s3pw7IfHjvsOPm3S5mO2NAFFYFgaaf7ZJE9TcoLvOAKNZMIa+oCwj+PlNzvAYBZAIzXZsqrHzTwUfT/EunnW" ..
	"+7hpNFe0Yv/dc5jlsaW4bj5pSVaaVB9ReSQVo2EZ6jTrRMxJNBGm3cws2DV9tUDHEblWJ4ZMpSeN9z9nlprVONGi/zj7D/8RMvcb" ..
	"gVDBTCE2hMoc0AeLt84pAXn4oeMFcRJc3S/EAHvoz3sFyni5aWtuGcdwAuIxD8WyuagLo2jYb+ZQkXJUjOGOh8aBzSdr1T9+16OO" ..
	"AgvaMZ/uPIST+sFspNB9owi/YxED0QSzWKdtVj8tz9E1WrbSf9+BXw8Hdm1sLnfgX6+nDykBdp0qhg/nb/AEaFot9Tf1p68Dk/SU" ..
	"oIl5iXBtJNtubSwW/+D321/yEYoEB2c7z3+VQDF07+7tRjo1yH8FYeknBY38iv+/m4f+hgTfRHr6FxJKZeHrZqriRu4xIVJcAr++" ..
	"qc7kiCwXyPUrx6WoQ32zzAqLt4rugy+BRiIOsCD6Vx4eOqCh7rlYpoVDZPW/dkZAPLG3CMoy+dA8V8TR2RidPqYBqx49vPLJIuFD" ..
	"QAk/W8fQp7PJHJbGyJRncAl7GfqjjAIFWtxlp8nZ6zjx/LCUXJ9qct9UtdDdH4zsDFGKzkBI7+6KxKtd1OGjk4c/BQb5gUeJMCNp" ..
	"BcMLX2xWYBNDLvd1xHthz0Q8Kl5TAX1R88nZK+5RVjS3nXxdmb36Gb5ZSWQulNvnXYJO4mKdcFZFTnisFDXVXPBhfRkc8ATpIaiD" ..
	"oVuKa341sk6K2FOgjVsJKQfBQOLEiIQiovNMcD0dG9nUMw7OzHgKSScrHG5nO3y4k5RY7H6E19X/DIvIqGTabfDmJ35Pgm7MOM5b" ..
	"9k7rZ3Hcpw+QXtwVn9rc38ERgCGLvuRZsTnnBhURJ5mNkkI7O13pT1xNDDye+tzITEPfXdIDGuW5YhKqiPpR2x4vE5oORMg54pO+" ..
	"DuVhvgs2KqqdIguvjbi43bLYOtPckTN4rsbxiSlmeDhnr5h03eQlYQEj4+PIqEVAOKbrcWp/Nwo5HEZabD7eR2DbjJ01Gp/K5W49" ..
	"uAgaplBucYD7svXs5c3URzPU8WHmAq0x+MAQPCePplBx1P4yZVNY+Rn9ty22pYmF5HZaUfYwK2hjvY19I809HzkS997VDt3BB0pt" ..
	"Y6Jz8o/2r1KAnGsQlv/3zZHhJO3gDfoJN/iBoquykWGlbxAH9ZuQr7rrxGQivOKYEXJGcgtDQ4srG8zDGjSiZrOtHApZSLxK/Rir" ..
	"jOS8IjdreDP4276TvNTOIq2UiHNg8EKNQx2GObf3k89bvZQHv1ZdpemOc4p3E+1ffnxwf2E49KCLFNdjTPPsp3ye5WdoO7tgeF0J" ..
	"lfu7Tb31vKbCYmCPzqSm5bs/ZEMR4T7CZsm8NtR/XYC64XqFhWL/pV06Tkopr8JHPsU9BT69PIBYyOtuMEcQXcSS0ivpePX6uV60" ..
	"MnhJjY8Vioj8xVVvqWZg/dqcxAFcLs8SLLH2dz1lmZ7ukzB3d5z3/LHJN8M4QrRlmEJpBGDCECLM2fY7BGu5e7l950Y7in7QLUwv" ..
	"INR97JnTSmYucLlDiyvXt0H9HOOkbEVH9fDXN1+snY+/hpOJq8o+2ojR1jyWaRa0ZSLoGOrczv6QurdAD6YS8lRrLK0kmSI/cb3g" ..
	"iiRJjbGexWUfIRAJGEe9R9WvxvGMAODqlUUd/jZHCTGRgBebav+4S/F7acQFwCoijB4G56QSSnKbvvM0UTu0Wn4ghJ5wgJyylbXb" ..
	"gQR/0GZWvML3l759JYmHY7QODbShcSz7/3v6TvCrudsns77k+BOqCkfAS3D51Nezzum4BsO1EZ6ng8BXmtsu/R0zH/KfB9+ykUoK" ..
	"ri/sx16tqykGzztw7NrNCTk50Z26Av0YnPFezJcSSlzYUlfEWJ19MZ3OygclTa+SOt9ShPLkL+rWSB66K3+KL1H8G4/PRiq51l+E" ..
	"ol5k1/1LWG7jWzCJXSSOxghFb5qZwWYSafpf3wqGqMwhWKiTF9q30YcAKxTFlSo4c4m1m23VKa+ZoBGqEupCVDh2N6udy/EcZl6R" ..
	"nLgCRF1uWQREwwWCsauGamjy6RoDZ/mwRUokX//Vlmlq/ofgoTLYVD4W+P7w2eCf0vd8Tmd+25wRDt1ZBTAJafSFDN6hyBRjM2yx" ..
	""
local PAYLOAD_P6 =
	"WRNCcnYavl6WboH775u7MKzNaYTZgtw09qxprjH5E7CgGSrOOOx2CrwKfBSfNosSkHtkWOONhcxrxemxXaY0uUDxVgh0F0ywaQlZ" ..
	"fh1/Qzlwb8/5DxZMoOJoqLF8+5xRuy0P9AcfGHCDZFhvzzHqSmbuZ6VBOb3b+jgjHkyU758gO38+26ZCWIm2lvOBysb7rr9Pnb66" ..
	"OTj+uunx4wEhWggC91DhW3s64mTEpU/raLoKxB1CRHUwYX2UOUJH85p6qceiA8mgoNGhADIpGeIggglDYHFLj5pqfY2bUMt/f7Ui" ..
	"AihfUZVNWlRplfWO+aA7CvEfxCtg0PqBhcxh7SNIStPt07m0zd5O2X3uAkDF23u9svOMW6dDX7ArDVMZTAom9h9H/OkapTSmQyAq" ..
	"9OuC3PrkR3f39HZWLHnXdLWtE1u+AIna0cwo5XJcrBqkZe3iu/i/r+rWjPSttg08Yxpd6xfZZKerALRY1D9BZ+wKJ3rdDghta/Qf" ..
	"I3x4ozrLJfrUGNis4WG2awPNsm1HXrfn1637/fJ7mJWuBPipY0l0l5uXi3HXr9bga94uqz6K4EHi2Yjf8sLJJr4vQqOcB7ztzRRf" ..
	"po649yDBQdbabyR7U/bQHRGDAzFYixMfKEPnYQtjwdQtz1S6e95uDB9ybHiSHR5j6L/DEP2KDkOyJYv678L+HQePAsW2VBJ3nfhV" ..
	"SDNb7aGncAx0Ltsk0GxOQLJovSOQBUMGOuVQOPStl2ZZUjpmM4HZtsMvfIJqJ6MTAGECZmE0gb0/7KrnDVkm8UktE1vYoLuT3Lyy" ..
	"ELjk2qiXUf5UfIk3uXtt58ckL63FLy07ryI08GyS2POS3H1vLESONxPQcLSAPI03ZJX1vkwVtnzuENOBj8+Nm6ZhVx8vPrr+j0Hj" ..
	"W3rauCvTzzjy0Cp5nyUwocVJxERoesJ5zC3R+b/jbZMkJB5b+iYTZU8xaWFBZ6/X6cJyFjRtFtfJehDtwsArst3wl/WN5Lf9a7Tx" ..
	"liNLfQ5aaRf5Uoj1nMTF9dZ7sKIWN4sADQ44OKPhTAgKBAAkuuxadTxxsBtgs0maCuNs6CYyfcQao3gXrqRZoUS7q9e89vkdfsKp" ..
	"9U8fL9C8CscHviPSKA12vku8psZhAQ2iw28wqPR3gepzK5/H2YKoIoV4zrGk5Z74JUJTMQ5Jd0TvpJIkJfEnImJ9DAXZld56Dltf" ..
	"bUO5D8u+yAUr3zhEww8z6hW/iaRzX5T6hfjYzZV+80qvlbLAp2deTczIeGvCGiiNqaVqT/AdqOtYi+/TvxYJFR4mG4M8mMkYfDQE" ..
	"mZ/+EibpbVA2mJkzrxVmnRuIkrRM1N30meWvdqw67wPcyBshTN7GcRdZWyfpNDY2glc7POuOh/DQSKfpldy2pEH54hdrK3LnAu3l" ..
	"bnuXkXtuamM+aRJAasA2HCrNa7fuIvzRaZ4Km0xUV/fq1gXI9dxlDOR5Gv5y8X5Zwv13OShUJLbk9ObwtjFTLhF38h+IF8fSvLCy" ..
	"vDk469keAs6ce5KIXRyJJhNb85RuqcdXAcGtCW/Sl/XMJNkx8z3bmF0hNsm6Q+McVzSLJ6Hij5nl7LP5oUy5Wn2WcomxR6odxM2V" ..
	"EJj6NUhtw+BhBII6NU3XBK5D1S4BuH/aBEOD5jbeSU4KFhOOWLe809XqTwmn1HOFvbNTGgu7erq6WYcgi6R50fpCjOpqFv+QWveX" ..
	"HhGGr4EnEaxWt375JUcGnPx4V23PkzH522d3rdxWr6Bwx2dpVHgtR5bKMsilnancC3u28eXT8t+NCcWr7rcs3Z6Ss3jeH3X6Ivd2" ..
	"rJfR6VyTM/t0GoCsZeOWzCpWI1n5ySjnfps+uhh0WzX/C7I8iAlVx2rTh2TmmFCjpHKE4fwqlwQLjCfhkFvpbfv2a/+Is6mbF2fU" ..
	"Ld7T26kWHLkLqhjjIAWe4gJoOlAzP/sjsnm5XHyq78gq4Cep7ZYKgtrBMQPq3wpbtVI6T92D3LLeW940p9gW9vB3iEhTmwUtEmFa" ..
	"rmCORgpo2x7Y9OyyksMubqhIzd17kQkzfyu/4oiQi98e3E5527/uO8auFjb0oTeMD48s1HHEXTEweQq6+bC5NTNhGUJ7B6FSnQ/a" ..
	"M/+9B1ORGgNksACv7JwTrdQUM3R8UR7q8dj9zTWAawAIxxVGSWXVArWt5j3z+9wS2eIyY87PsIPCVVdug1lKDXBnkGojnkwjCBtE" ..
	"2C0i5e0pWV3E1c4g5mj39BcKnjUExxoOhHUfCrH2af0saxo3okd+w29G58apHgiqZUZMzl8nRzHEiZg8bWCQQiMEEVyq75t1Ege8" ..
	"OethLFgRfQ+WqRCLZrLeLIlCBE+8gz32ciR9VGj1XFhbNXh702zd3WDbbtY49j+nFebYi/2sVaLs0y08KTTEqWRXY9RxWJyU6jCE" ..
	"GH8aWMJ3oYqtifleFaHn+3CDlC5BzpGSeSG+1GxZECGsd+JijUggdNIuZvPLjhvr1iw7h5dUIM7E4P8D2RpM8ENqt214ntAe6bQH" ..
	"RsfP1uX9RebD/e3qNqPrt1GrCzffPL6/6totbXAHXW/fEOmIjw3n2zIzjbiQQwAmz+0b2PmO4nBQUmY/k1pWBzf7fH6MHjWZja9f" ..
	"UJM9lvloeOYab+VH52lh9ijRRtjDgo7Hs2OB9UqSyY3SVhF9njR0MxuKs+8BKu3XIwh9JARmCh2lUAI+YSTRbVZL8267wz/onUPF" ..
	"Q+daUs0V3HGvSbLeBYrX1WW5hOldAnAi8tF/ZI+RSrV4xj7Jpct0VBj+yFx6kBdIBsElL0UAOEeidaTOjueTUC01+ygmzs+L0fR0" ..
	"qh+34Qy2zoVETyAdVJFjaNcsxXHmqsiBGdo3jf3KgZn8XQYZfZVHUD0+57n2k2EaKFpqltYyVsy7TxBpzP9IBgQIfTGNQ0P00gI/" ..
	"HMAZuq3oTb0vP8KSmkbfxVEsLUHon7Wi2QzPWE5rVsQX28+sAV+tzCM3pHXeF6kRgF7jaljDOlIwb3nnDUpRNRl7jwSpRcbHVBaw" ..
	"KH1/afVbik/bdDrOcYF8/zeIb0G1hD4Fqeue+kQEB/menes8hIpsNuxTSrhyQamgOKckYY5Il2eUPHarXQ/sbs9oAAn8XWGl4lLG" ..
	"gPxq9rO1oufcojkQ53NcGJZ/r8iy08Gj7euDlv9IX4TOXN/fPXjUwInC8zuIgKmXC+eB2Eso5dH7j9aX/8WjxHw5k+fhilloN2uk" ..
	"pL7i81jwqlFyw5JlN1Lv3HV4I/GETnn/dzcxpIdPGPqS+RkznM+qClfZmHF2Jac7e39aG3qUWGccq5lkXWb/8dHPmVEFE2TA9Mc8" ..
	"lyWY6oeJUqX00LLkAk8EdMGADIlU6j0GtqioxKkEiSp4gqKMs6hrhhfOl/LF/TNlafUpJgOdFydzTG2J5w9SzKFJmIGop3FJbHhJ" ..
	"Yy2Zu5hpPEcju+n78eyXqFiCkV8z34GDFZZkpPSaXp146b+VgAIsNjVD+dlXZtZU1l7sKXAuXC7JUElL7ntI/XHLuu5CqzO8JGev" ..
	"8F0dNDNEFV4U1SPFFqtg5e3Qtu2w1ka6K/WVIeIXKeZDuKVqA7B7AfSNyLKzqsEJE9lDwAYt2MojhNRwtTJelTueX5rrNR2A6JPy" ..
	"h8JhaaSdUKDV+VH+Ckqwt2nsulZXF27qUv1pz3qtghJrYWKUtAY4Cb3nroKc4ZyGvprpMMxHhTBZj43xd2+1bcIXEsc8cA1iqFuM" ..
	"xP4JhVWbk5uyU/9DeRmTfh5l5t2MPtRqFx92YF3tYQY9SaAS6YCgjJJjtJE6NHRChKwyC/zrG2xV3V9Qr4tmduUakA7jyctYecJj" ..
	"gcgM5inxISzaMz+c057vfWkYPA15Mocrc/DCJaSkyVlPgCg/kkGvmOwjUH3C+3JU9fxHkQ9hOVIE23LKc6s2Uhp/arF5PHThdzv0" ..
	"4SPlZFs8Loz/0MIdII0iJERZA11htPnznT4jyF0fJa60NfrgaccrSD1+cXUcR4DJsAD3CaOsy9urjqHqOruGa4qE/81/s4z20b1t" ..
	"rlKdWXB/7yCM7XzM7azUaqBlv4kOYK0V4PXLG6PDdjWDIzx2XD+AfQ5n9aEDK9CWegvbo52EzccJo+wEVqrTOwDIFN/MflO3dFBL" ..
	"JNj2/xFyHgB7+ymfXrMFqbrpgHIgONvMrdjJvh21XztSq8NCvwutYVs1l5O6F1gKlxnWa5CalRpWUPYOmXONwhi/w6C79YDAvCyi" ..
	"TxIeZrLyhgJvMvnobDPNxDcoyYuFmNhNYnzW6PVQ8SDBMrH3qO7XWr3R5QExtG+3xl4xmOY/YjOO+2wiqboZIK79O1jejgoh4SLd" ..
	"Lamz3FH5JRdmhkpu4vKdHFLu4/pYwr641s/LXrn6Q74ZUy0te4xx2VDlBNCGPvv57Jt8AqkhFLLn9s7t1YtVMi2oAyhBaGWbu+Bu" ..
	"kb9C5uUjxMGC5/pHdI2WDbgoPpDrGKdGIFev3b04YTs6q6+zlA5wRlXUzm1M/F3l0Z0kL6bRVLRSqpq/0yyCulXqYhJ5EtGwaYjm" ..
	"rk8QnB397nHSlZM/5986QxVZla1k9/bqVrVWiDcxv2xru/b+C/NYkenWxEBd8SzdtVBylw8mT6dgJNTiGfcDw5UQn7pJYCaFvBBu" ..
	"ZokUZfcJG1crSXvq2VOCUo0YTYqt9IcBYva+00vXbrsC7anFU0sVVZ+nF9qAFZyJK3JfqgO3inT+ijzni90a+HldijmHaGgreRmg" ..
	"odaAntqI9N5mXLW3+bO4do/wcMkNxU1DDqC2Yh5VmLqozQuq4PMpLyHjDuXRtApmpGzNQacZgUnyHbCraR8/hS55yg2PhjJb0KYK" ..
	"D9r4MAZcYJBZn9XcY0XZY+81JwXErpjqDE3sD5qEoECOQEYg1/KVJm06JceSe9nGIx77XZHYF2xN0bQlx/dZqBZd2k4XZt97rIQ2" ..
	"kBqBJSUkiO10iCrRnkJBps6fdchtFhobQxMC6RAgSfHdn1vJm8rzXrPQRHTa0kLmec2GDuwT0I1svNDCNScvWV6KU2n7eg8e8QGP" ..
	"VRDeWObAvmLyOnRFmcl5QOwnP3eJ5gySsrtLfkLJwB+gXlkmrgxyXdWq7pRyWXASgTnsBwNgXFe9DwgF/Oe8+NP8DhgmTEuB0sTJ" ..
	"Mx5sL+OEn3TfayIYJWk4vIlhvsky8yAYVut2MPtfvdWtvj1L7NpSFaRBDdUxWEYk4BXMskwUEAvEFuvnFar+RLZgcAke4JxxbFww" ..
	"6mFEZW+HPhDVcKQqtQ/W4Hvnhgd3Qurhg+PKj+sLY96UeoxqUBy4iMoDGJOEwmmPhSzvL4SwkbMUyB5rPCiwSxpl56o7j6j4CJnj" ..
	"7hVyRy6LYaJ/SBxMM40KWLzPBvw1R8VRO0qeprbFqRcv2jA8kRbWJFzcN8uHj7kH3gpQ+Rno2prXSCQVuSBkL62fZErfZZxtKBIg" ..
	"kR9/kfsFdIT4/5BAFDEwIV9/00A4HncznhNwW+lF0R35mtkHJ+rpzQetQsEE0Xi5J3CXWo5+zJhGVoluNkD2MAU4h8RVBpdByjia" ..
	"bphoSUUvy8WDC/HA/TwOF3PE1PA9j6L/oweLILRRsrWg/Pne6CsmZw5jF+sgPbtxgGB2l5N6zoEHHL4PyGQrhXmH1lM3qr4ZhKMe" ..
	"h/MqgGJne5Cj5e+cxrtNHwaK37K91Q1fOxIJC3ExoT3OiwuE0sjGwUmG+5gdoFV81hB6VC4DC05bOsMip3TozKYwSVHJrxrpG2D/" ..
	"IFSQ68LY1lkDhABV82CKsUBhfeS2xbhL5vsYt9WEF5adi8nQUsZ5P2h2w0HNRIZTmcktROk6+JEZdXhS4wfIcEXXDmWEybr5yeYj" ..
	"Ns4zmN8EycyeSnn1Rh9z6UGFNwwDg6GJZSfvHydo9CHZoE9OkzFkv0lh9pBkpnbi+NkPG2/VmCLVkOXV7rHon1MPgSDIuHvu72jD" ..
	"QjOTwIbNoF+mqxoqZsIGBLYQHLq2Lg1iDSp05A9DUihNxgxfMYrjMf/CP4LwuXI3b6zQBUQbr+tlQ6CVrWds/CaavllFhLvFjkuC" ..
	""
local PAYLOAD_P7 =
	"0RLj2HyOyDyEZoRybgglji3F8uMC6liqPg3Y0GI/e261v3/knVNOw5LYs9ZnXxJgpErk/b86OjCrSkUL4DD/jqyyw+C+KiRPA5up" ..
	"E5vymrOWpWPVaanhX654wdEAdXUZq/RS0LmpfNXEuMPFSiMjrn4EJT9yJnV1fzbkICbDmBKvMm9AXoVSFpW/jP4odCRSZcUAGPkL" ..
	"4tFPo+EjCbROc17PbZth3gvEwk3eMeJU9q+Vs32CynyIEyMDIUMJ4BKxlTBrurSi+5eDKre+aT8Sy3OSXiC8VgCeFuuDyvp6FaSz" ..
	"XcpyZirN54D18hJ/nRq7wN5LTN97QiuxsSFgpV75JHjB8h5Yk5QNVq9juXm/Q9x6NmpIleFMXZcRFzAw2b+wk09QUZZQ5MvhmQks" ..
	"igR9AwwLlSc3jsM53ZOSpnJ7W5+ZD0sOqocoVZenkHorQQ76AxXlUz7vb8q68kAjstuyv/CkPofjfgSp2UK0HKohKFtchvhmC7RL" ..
	"MWhgSZINiSpAToosPfid6uUwwfkEHP+NEFskJwiHD1K1qfz8SewmcKeX7+1LctvDqYssU803JV+gXX9ytoPAirbTh6h5xZNnFhp4" ..
	"4EiLY+rXlm+yMsRB6y8RyUBWxxl3HpGlWlvcmEQINSfE600Ixd6txuv4vgPn6lc7sU8i+lN504KGY6jB3x5q3W3CueXrooIHCU6A" ..
	"9fpWDznjpHCwlM7frPe0lzwQX5/eNmVQ+xkP3Bh58wJ4P2dDK7IZh/qify8UpWpIHqdywobIbauY+/6abr2An3iD/n8PeTIIK4v+" ..
	"x5a1WQaZ6cZDuvAHBFDmtbN1EEJl0zcXKqkxflILPwBvP/hP++I9Rz8928zwhSgFrI8UBm3ZCFEVZMaK8QG7OSPV9e5SwmwSUxTR" ..
	"l3VGhB9cl5XqdPdG1jPR6LQsCc5ZFZ0+Z2IGGrNyE0RsngopiOpSfBNTwwGpiA+G90KTnunPGVlZmdvkOw6NUfsVJx+fX3aDmepL" ..
	"GB62Z5nLCsVHQ78QVdIZ+p0BziVAEnkK5u4JSEhK4ODZqj+KQtsd3RcrD3S8NvcbMD9GH/U63QJpOrQ/Z/fUGfVFFm6Ht5m5c4NO" ..
	"uInbKkdGlOcMj5AetLBrdg9xVLuViS7SNzPUMGkDut0DNde2+Bg+SBhGLULgrYz0ojRa+CdIXAOd7kdA37S/07/F0M7JXhjUZv5i" ..
	"dkJPO5xz6w/nu4vN3IprKkobIDkgkb+cGVb57QXeXl6J5fW0SnAPpTXg23DKQ0NeROej1FxncgiMVvrSu8bM6t+8zTJhxQXusHNU" ..
	"wNMVMSeZH7KwQUNNGDxa3hKFw14Qj9GCbmkkDEZWekjMGfShU6Xq+wPtKw6Z4xuWMK8MMgTWcHOuIQlp5czJ0ULd5Sb9dOz1hBPJ" ..
	"7i8exR2ln5SQtO7k1uLFgauWgqFyh/MO7du+N9kuTM/ROvBzRE+Lo/xIrp5P56jf/yC0qbfZ+6wD7YvdFElCAAqBx6McI1NE5YuJ" ..
	"ZaJMIIICASb7D2cu4U+UeDLrsaNsty4eDXm5Ei74bkO8dlJ2ArLXNd2MUUU2dOjbholNAC0Gx1NOP1d3o2i1uxyST92/vQ/91FA6" ..
	"P6Pnsss0iv0UC96A1qoUFys0IxHG7RbrCaft667bHX6bka66aLFl9Xr60eCWQiYxyCUVXQ9vQVJIZDd1FOOCf1lU+cKnL9owh5pp" ..
	"zJxVmY+PFYwNXXAvAr76yn77rS9pzIR97nHzDb1W0vcYeoFQULphx6tIPqu1WHirisQ2kcUZjVS0CsWGn4KAkzs7L9Wds0SFsdFg" ..
	"UwscgBKGTTEIAop5J0lVvc8oDkLQ7a/15hn588lC5qnfed9Jt1+u8vzFpWEf8AOVeog/Y7PUR3bJNE4KTdBJ7d/A4ueVW/I4jGN5" ..
	"nPzV8bKZzA+NIeE3OyffMqWOjd7q8fSmDcQJACrWikx+TpXPcfqKL/QhKvlOeg2axk5/HMrcUgSsUglx33P8IkcIVXtjIoZ+UwZu" ..
	"VjEKYH5k3hdkZu2s/qdPMl94aySR3gsDkXutEMiUdDqx1ocDe2Zwn/4zay889h5fIc8Rzhby/YYqEnUba1psHgu5n3al3B8bSOXX" ..
	"zFin8FmP1b6n3UZz3qTuBOAq73ovRgP0K0El8Z1KcOvuxwuA/oUIyuD9ZPAkcNljYBMTbsc5ISRAiXHZRJgBtgj/7aUztaOtvPtF" ..
	"5kdS2EI+4yTgozUXFJbphWnYB+3UeyVjwcxglNM03B8eyDTPavkG+TNAU7++e7G9qOsaOW5pGI1OvqEf/NsnplKNamp1mS9F0NI8" ..
	"YKPzpvNnm4G/fxTZqRGvKWR0hPHcmxSgot1ljuuALq4GPSBCYBOX3Im+KeNwc2lDXH/59RAMB5x2Z1wuWT7yn3PfXjfk10fSQ4CK" ..
	"tndACDcjse/jewhwy2rfP0URTJUSlemWleVYsQEXp6dByL0T07xAxRIaHqMZ/6dhFZAXpM+mPrlJvt+4JJ1rysjegDRuCgQKhB7G" ..
	"E82FeetsA+aO2Uu2XUSQQR0LFPZi4f6pVXZTcaTWsklImO4lpK5/H2XIDWUFR3ZYI1DZSy8HnDT6mciE3hqpEwyBJWH8w3hG6vPv" ..
	"O+2XX3BYzB1JAgjZnbn1peShQ4QnQaAwK8x/btRqgWCBtFiILKly2eeelnRGo4nnwkLCh4JK768yEIGM9/6oPtPee2UL3NiCAO/B" ..
	"L/kevdKY/6wyv2hkN+Eva1/SS+JPd57aWegw4jb7Apd6SiWWU7xl4TJeqVT77AB/3c8DKTwK14hwYKHl+MH8tqcfRth8FzfTvxy2" ..
	"i6iHf2X+FyrgjSC3tgKavtCXyFVi92HFkUXODDx/noD0nqizcWx7GMy0V0lHnMAMeu2ksZaKmFziodxTOAztCVlApmTJgNsLXtdi" ..
	"5UiBmPQ+bdxWdar5U0z6f8oh+fcQAg4NXz2BnZOpexl+40F4bU1ywv3zWQ/THlttGtdL5ds9LjUn1m12H+1cRU8DCw1On+k9Lz3E" ..
	"JzPdBLkYr35HWikzcc/PJ5DJb4Db/QGRN227mIw5ls4yB4FO7I0ZPSiIeB2PjlAORdTrvfGe/1EpXxbaoOi75Gi4CbshUBbfxilg" ..
	"f2IMN9mF4b6/pAKDZu6u+AEgeOP+syFOJswF5h+U+R2A4RIqLyUJ/PC78low7IuGMmAXyavb1tlspfdvyTQHsNgF8wpEsRfi/c6A" ..
	"d2apgzupYL/9+5VCbCgtMaC70dfRjIsfJuhuywyxdC1nWWHvYdBOey1ZTyUM0Y3SwOVb5A/2EVaLwQr8akmcE5BwXwCts6w4DSdr" ..
	"JU/CRS3I+FCwLdBj91U7GRMx0kLriKLJlOuU7bSBaSMX+2ryqdbpxGKfQ9rteA49Sl/fg1Lp8KeWaYLpyTv4wOYg6Wrfj5jyuB1K" ..
	"KzsshBErGxwHJNqbqz3DZLY+N8A+L6Tvy+6Ai9F8jv7JhS/iNzViwINQ3kyi4Clp3c4eSKssRBAcd9D4H2RzJ3c2/zkqLirVAVjR" ..
	"q/nOauEM4nNrD8SVkY9duJJfSLJx35pCJ3LwrdjzGD3f62HIUxEVnJD+PPKzq+RwDf73lBR1WXJuZuBWmq0bUncQO+mFeT8NVM2a" ..
	"lWmTLtUaINfEcw2lZzyqNIm0gbCWHOu8SNFw39P03Vd9AZ+YL9wWBqRysPd7T5Efi+UCbwfUSRvmc1xBKB6WgtKMORyFRR/V0i/g" ..
	"5OUQOGjfB4VnVCsrnJdcDMiFNjVMf/1ibcnpctZ5hudXH5ee0XSzhYuvhgR9TWN7L7Vsq6NHQXnVaFf5Z7LA1sU/38F+0CXRVBwm" ..
	"s8tQdUD6MjwilCLXUEzLMI5FN38erOUQ6MlHuw4N+FXKTW0LYiKxtGU4pO3EkBNRxC6bGb4Lm8k5OcM2jDAP/Dq4J9W4xuGAjBhM" ..
	"wMarf6CxoJDr1vlPLx4TlQjoAPCI0kvRK8CBTl0PjJxlu9/vaDK/OaCUwkH00GYIcojdTb6zfmCYhgm2KMqiLDfRrTpuwbneolhs" ..
	"8uCPPk3mEIypuBciaRnzG/2vZ4+5aClytgmJuABEfrJ/onkfIRYNtZRFgGN0b01orYcrcnB3EjA5EwpK8nrNGLxn44zbQXudsV00" ..
	"XGsOW4Dcsyn2Bo43K2v2eqC+M+ZNqvZfwChdGE7OEWPg2hIWRoiiHMUY8co2BiSTfFTqk3x00rK47CThN6vDcKNBqXOCtzZsafCR" ..
	"9JhrY7QAkEa9K+Iwb1TxmEwdlkCYLV/xLqWP39QTFOYAq+7MpPqJeL5MtKvn+mOEvX7dFLBfsOtuZbIvDfIqzTOn/F1SGHZ/3YsP" ..
	"i3OWO2ubcySFAHH0ykzyy2sJhPWAOBDTjOk44J8noBQdKWG53RaQBEv4J5UgWYvqXBlmhCceK2TNj6eXX/I2Js1AEa5pCX9013zU" ..
	"4hjwDaQX6S6RYhfO1WuOoxPlklceU2t4Eyp4MZZEjY1ESj2ZM0HwpQFziOpy8xmM+0wYo/irkuMU0hUZEO0rhpFi9vulPyNwA85j" ..
	"Kn4k6pfOJbY4mBg5QcxOt9RZSiurWwLVgosN2m2zT06bar3arKYOajZP9AmmMBLdP14cOd9z2SLkaCKreVeiUNJyopo4AeDjdQJt" ..
	"/jmHKSMLThe7k5395iIhHDjHs1PkidOl5Y3AWKkl0RA9/EPvrpipUujd1st8Vcg+6mIHT69ybuTnjmvrSXp+Wc5Ul/7VEqnKXCjH" ..
	"1Oyz5lDvxGrHSduOVPIRjUU76Y5B+ZEoaS7FxdvMPRcbyK3yR4fUHUJa4WBKuLoj/d8/YmP1QB8+RFo2AFrH9kJGboCkEQW7NoQY" ..
	"1dK/gwOrPtVLqnO36UgcIikGPJppLvyA97+kxQ/pXRzoTPdswiZwPDY8i6r5l33bTdljOKanaEv0TTc3EOmFju8b18rs4aHsYzWg" ..
	"8hadRfMtdvyI7d5dc85/3Dd8R4QYsb+K885mQtztkxW0Zzzo+8bZmw+LqtsWZrwPH32JhmMQAFTT+c1N/Gr5EmtFehQWtnnzKUh2" ..
	"pOLVcD/uOjatUN086hjVE8aB8QecWCyceNxM6/1nxtEeck79/c24zWdJ6RONT04B54U5g97Vti7yOxHkAE6OWZrZ1ad5hkanVBZ5" ..
	"F/xAAwATetQWXaxZrG7RNnKVlSQNfeAqE8y8fjeS9sD7JJrmbTKNVPIMzxAQEtF8wO5HMrsagubnHp3znXqcK+3dHQE2KqT1lUVb" ..
	"vO7Ar747jeE/nm5qGiPJXaj0Y7T8TmHhoX8RyY4XUbkwHSgoIqG8uNTPAE9X+9wXLECzJhWCpuLiH4vJ+m9Ac6c8wOiDaAlf/J/D" ..
	"gIvUj+Sc3REZdwJhgPUXTXGLXDIfZWfQR6qtNkfdB5KUlvxo6Om66BWwinPsgLdk1X801VIPt0qILnLPWdf/0Uj325sjkFCsiHl+" ..
	"adKDZ31K3dzRCJgtwnkti3bxLu8Pw8gMu1sAz9QoK5OCDlwvpCYwWgHEn5J2UZp/Cuy1nu1wJaZHtq9sAmUGr0zQytNY6eFM0b/V" ..
	"fXCGNbXa8t4akxmDl2Y0X2d7/Yb+p+isESpYBYBukadskUWr0KrdVqFgPovoq+fuAcyJvT8sdwy2xrtQSD7Iy0ZqdtG9i/bhT+zv" ..
	"jMh8Iul8o2iRIuCVcW8dwkYFQ1m+L6s0SdHzhq55EXg/9RFKb1plk0DtxzqFjxIySy3l2OvDAGcNtje6ghtK+ipqMQs8GiVOwb8L" ..
	"vROIAsRzvVyMoH+hBEW00i6yBrogojU4Bz4FCpIciC8Zp2mJifv5L0sZ8GXAGDJxz6PveeVTRXqJLlqm4Ddzgz2pwyFrzdpr9EwE" ..
	"bo2EwNHVsSJYveoKO6sM/op2OpVQXMZoo7f7DnS+qWwpUnpyhSPfZ299ljaQXqjW8qaoOrsj/ROmbGo7yH+J438cOEC5NoJPGpZf" ..
	"mSJsdyb1OW3Pil0kwPY4ILbF9n0LHOynKlqT0ggWN0FC7sFwDU4r2EuEDh/42sRnXWwy6yPTm8v769oD8SEsz3yYHqYA2xR6Lsf2" ..
	""
local PAYLOAD_P8 =
	"JY+T/jVuVy6p6tTakxoh9257aKPf2Xmid1TXYKXqVQ+g+cNNJ9sWgV9CRqbDboRw02qE3gdNZRcZ15QbXkWFoBnASifHPeBUqrqp" ..
	"oz0Xs/hXD31zVAVqrA08Gn4sH7PYVvmONbaFvCOsVK26yA7pyHcpAApZyEnPJ+ntPzSvK2odZLSa0wHQ9isWhFhKq88HJHFHnmcs" ..
	"rjUIKzIRHFg6iZhS0nTN/5WPASqITmtkDP+aAsMyOnJPN8kALQG8IO4Cc/MKH0ETjxW3jZRRy9MGPb+zNznB8G/QaxVtWqk061V2" ..
	"HwhKYlPEeSoj7n1VYC/+oXFs0A5cwQ9pH/tv1Y9ZVfqPrZwjwCG6gxJXycNlb//wLCKngbBUL12LnysMXJSP2469DOsfEq6bgZmQ" ..
	"giGv56PGZpls0sRxxppHc+9LbiWBFUQx0lKI5FJqTOWsT9uaDDOlbHRbx1CJjew1XRnAXuVMLhHq4/9EQOKFsv2tW7NZjp7ln6BT" ..
	"Nu1g0O9vMbv5T+01jfbhGfnTNTgpQ0zB3UqFEvuGTm0RgVrxC6OTVq6900Yn2xsWCTRyAXrxuJRJufImIjzEGTeAT4sXrySrroO6" ..
	"rOiRX3cDa/Y3gQuilTGNJAcQ96iNkKAC857KThitqVIVtSvDRQ1Dbe8f62rvAqddmnRdEaCJ7B+ah4r/FUcqQfAp516eWJRMZzxf" ..
	"j+VTC4lL1bnYmIcux4c7vEChsuNdMtXOxGFDNSrKDLa4l/TCck2LZrgJ8U4Ngav22NAimJJBWGHrNwAVwKrfO6cVEXNnOkYQkPf5" ..
	"Wsv7mr4zaDjFckdhUyLcqi3KE/KWdgl2WXgaAG/zgo3EwCyvo8MUHJnxMMwRMu5biRPqQ3IKDlguY4sZb+7qNDLcrQGoCsp7E4ea" ..
	"duK5E9q4LHTiEA+/kfhAkkj3ihO+56zVaey3B15ECFBdT43mpnKb+kRkGGqg/1Yp3QYLLVQGVSK/VdxcATqF5vWqpxwH3Sa50s8V" ..
	"ESATfLwasoesF17edYJz/ehNgANPB32d0HSUOqMi8X/sKSLKkBOUL2auGcQEUU8WV05YvievI/ngu91mOcm6yYViSfxeYHYIDVsE" ..
	"41Q6m1ZpwphiluIhHd5wo8r+bqrsNvwfV/jeuar7X+63oOn7+JVIQt8GMHhIjTqy2yUoNOtnMjJO0BNNMA00ALU+ewSkisrJZoRX" ..
	"y7w7fI9MHfD2sgmRI+cShH7zw3s2inE3BJ6RT7Ue319B73NDrc9NLpwQ8EyHZwSJhDETPpnbq15MflpQvNDTNvrNoiJzmSNRQRLm" ..
	"2TJiBfJO2p0fMpyniCOmn8bs8mLp4jASmk4RPDov8g0b+KQhmEZGCHRKTweytjfvhI0xqAvk05Os2uYJ1yF+fiEbyB5xM8xYaJT8" ..
	"G72dsjMYk0KZVzQCqGBwvMRXRHRwhzUlMXk7qPLIWKOXAgHchFDJJipT2XBbXpQCW9LYoshuEDVSz5R5TERHSrF6j+VTEUJSMASY" ..
	"+qrOcbxWK1TegciZ3x3A12XOXef1ocNZPvIFeWe4iBTs+sqUansNIxKW+sj4DWvr45p4UqT0TxE6pSl6U9akimVXB37A2fa7gAVD" ..
	"/bEi+ZoujhwNFjJ3eOTTqxuuoEqEQh+QiP1fTZzilrqvKbtuK61dMUaXXF/8SxNTn2gkF/g2BH51YcaacuDrCrpizfJE52bcw9wo" ..
	"5iIylvqfSVnDnWa4+7JRXsegwKYW8QecGT3Ugf9SsveTi8y+VkPkf4kK7S+LplsyIap72HLP0NyDFz7m9mqrjsYDQg2HU2R9IuHV" ..
	"+0IxJvZumTawzXjN+8zHFJXYuYRqCP58RbS2D/+fbivpPFraaWxWHiiDwZiYnJ+eLzDE/23W1SnfHo9TLvXjU9A0I6eFBLOXBr31" ..
	"xbeXBXJCgIECL34IiNjHx7xAvcu0/fPP7K6csZi8oMM46Y2JAlZq8m1fdGqQpMMIiqISs71tttwxWJUwm0OxC0BcFc9kZlLChmKh" ..
	"4T+1mYo+OCewZ1FZWoCSJo+a5XhQBO7o/ypF06M2p70e7mBvByH1FedJMDaG7e3w8U6UNAwcuPSk3Z/ktQJ6QruixFf8+2ni3gV3" ..
	"vk9MxeZVhg0Kr/afubaPHR+P+n83Q7xwpdvS9x+PpGoan5GdK716TJQa9GQ/pJ44+Mq2eh3OTEvfPtxk3ziFg1S43oiPV/0CuY4Y" ..
	"l0VNM93iwV4kd+JpUkEMLPZSEuJMzWJiKzbjb7SzKd1UfMf/Y4T8GNvYECJhI/R1pFfoUVuUhMtsCOiBiQtAMpoAXrK9GNpsigqj" ..
	"+L0HTH6ThuXZzCToG1NUpF1mKRuPjQ/WWtKKZPKBRrvlBsyredHCwL3igar5Lwk4zlv61SmqHxAwRtwwaqKFVyNfRcVje30ErM+f" ..
	"KykTMz7WYXtP83hY2xo8N+ccgTn6DSVBq8+Wqs2fzjWR/NRxNjLybI6JMYyttVVtDTto/1l680rqBI6EyOnyrAe8yQds/6hVM5qw" ..
	"C76809wwxbIbeqMOU2waawdBh3ZisqDT7FoBZTv8LyWOeGMjhqBBRsJf+HgTXZzW3hGGm7sZliQ08kHQssTSz32TndVdDmzfykKx" ..
	"bmxWFHdkhd2NMhR5x2Y5QOMhI4vLopjqDSJlIWFtbvdXa8joeQrUVZ/T5RLBbMHNn+AjfENHn2hgBDc/R68o+d5R0640BegV/atH" ..
	"fR4oO6z7TrDJZBE+4xqyuv2XQA6xHm7GaAclb51KkQUec69ZZRZlgs5mxWVK7oenzLSbHhMaZ/NIWyXEYYPxdDT26Z1wf5YeN2yR" ..
	"i4mffTGS65zqCtxmJPjtYgYcP8O96RsbJY8j4N8R7ulfGodz7af6P563r8N//d8TV+YXMVo9aNTak/1+OHBQbimZdzmgGCgSdh2I" ..
	"4mIplITD70Mao1fAZ6gNMJTRM0OUqsRJdLr+zDFJ2iRNg9dChZNP0kUWPx7byQ6z2PSk5viBzkeYdnGp99btdsHMBCP06A52EQ+2" ..
	"O/Sb0TBj07QDjSyFwZyyzbK7xM86OOffKLRzwGQYp/dF+1NOWYvyQcEg2VCtwqHeugdL+JSPppuZi1vDhDD1faXMy7Nuw71qPuUt" ..
	"qQiLJbqBeXNhsCkTA1UROgs2YPaUqmaHn6PIHX9oqSa0rAY8tQ44Zg2vW2eW+pn7TOPWXouV4lsMvGxhtvkH4yNXwUIapCmeY/kQ" ..
	"oPf1gu0jcJwesSKEL/IQDRXlKBSTSaBRpBVtR6wGltYYj95DOrEUEDe4j4nv8ZkbOkIyjsTuyYBloJoRspN7LNl0mRaKijoY04v6" ..
	"x6JdnpO4ZZ770Pou71Cja5xGxGTUFaIpMNWGgUklcaDOgmAco1GzTjkut/Xj/4aOMv99c+tH8utYj4JfZmai3XGO74tCkf1iTFo8" ..
	"l6EYmtQ5MDGSO/Ugy+IzMgu+WmUzy0ncwhcJccKrLJaRrxIrGQkVBMAvneEQvjL2Pm718FTV1lWXh4MAhytksvqkrAo0CoGE9NJ6" ..
	"AigtmXjg9xYHdZg8U5QB3HDqOuiyTVSaD3zranye/dS+ZQRHLOKDCye/q/ngluc/0LrYogVik76JL7tk62DFeYP5RuT9LOs3PJlm" ..
	"IlOgZGhz9rvCK9pxDRPrzhSZyv+Y1SK5w3aYX5tTUPP7dZcxVDge+GUStjkLVkrBVTzbsx+WoGNtPLpuNs4HvXojn1gqTdZDm6mD" ..
	"CKtu9RvwFSAQXZ/EIld7na0QpBFoewDFYIzJx/lJHmxX/4HzVrSa6N1AmSQ3c4lXZlOhGJRW9MBQfQoYmHRvpkpoo8IY6q6b/Jb1" ..
	"9wEZlkOIEL1MKWm1qL2umxeWXcFfK8cYThZmr8uMs2LsA3Y8rYLi9ALIgQe1ijzfJbZoco6k5YqkULboV+2Wd69QgxLXK6eoeVKi" ..
	"JaRR6ypA3npJZ4Y6RFz3MuU61u1GyuLnjQIXtFeIno/k6vtRsZLIzIE6X3I2W9MUgCQzaiGQP27UxbmEuAnEIRkmoLfQpaLZO/1q" ..
	"0LWdFpsPLNS9fV/WOBS7XaeFn/kexnMqX63B42XTMTCWvyoS3Gx7WzVOfgN5iACXqV+yV0y/xHoSpmF448xU2yDO9EGLbbsapqhF" ..
	"Cttfx/jMNpcp8uyVMYbGeiKXDuHz8Iw8JMkcCEXG6M43SN8q2sZW0439g32dAPz5wKyz5ObiJz30N+fMqvf3j1o2n/VoGOnlqpjo" ..
	"81g17KmpKRQzlMugEYe71GaNnVrVP/WLHeyT2lanLL+I8szdhD8C6Q7I0Vvf+fzusx2GkaUURwwbGHQIe/og1uksZsLIpY26fXPR" ..
	"YcRpEYSwcd30UZ32UndqHL9F/vWOFQQEwSPt/tSW5Z786oLG1WN9WLnr6DMBWQwir1b4BtmpNvyYRaF6AGdD2bfz2NdXUI70ZO1/" ..
	"My++Li/lKRfFA5PfPBkYq0omUfGPSG4aAOuRdDYZH4AAy2cniWk/4nIXEOIOjVlVdHodt0wK2djLUCajOLE2ZKOXahbFLXf2IN35" ..
	"+LIn+QftK5rVtdbDlNx3w3xl4SKASG4ATh4hSH2J/0zxQJ3IuS7lstBMWca1LlPza8edBf20V+51RRLJEWB/G1S2M4fQ/CrTAbFt" ..
	"Jlz1TN7WkmOeJVYkqCqH7VN1irGRZ22+o1W+wDRW5BKxoAisxM/FSrGJutvE0ruw3IPjNgDgqeSq5OdMjJYtzePGKGzvVcsMk5CE" ..
	"HHBWodki3UV7MthESfvyuFBZEC4fjVXx0nXhY9nz0woRd03XIrW+kx+RKoBFDbA6h8pbwwD5o6CHH6bCamxsZrPzY2pdc42CgkMk" ..
	"haXd2r8juklTrFu6QULhxLiHYNyjOMgY5BlJ8Z9X7q9BJMs/Llb1ro9ry26JipE51Ek6IvIeHUmifj1eDgvxPfR/GPWz5WlOP0JU" ..
	"xvXsS96sAad1ubnARu7IOdq3TqmFtDvt4N8RuCBsIvvntmFiNBJAjMQP3yGzeSdmD23g8f6SZIyJNEWVPxJY4XlMrF0BAMEYWNLq" ..
	"mP1P5AmxxwdAB18xPwz57gGTAreMw1Llmv84QllgtQRMtZhWE7msPmmgHnIp9kLUt+PiPMHcAf+rdW9/dkX0ThPOTzhgOGSGR/oO" ..
	"PaFFlAy0J79X80gutwuBiHK/CIa7Ke1eFArCsxAEvAr5RXenOWF1R2lW/PLXZfjyjOj1B2bwKgC8flGM9jO5upcfyU5XxKaGbhKu" ..
	"A9teqhvFEK64CHLt7jkgvPwyonB18BClMbh/1KFntOLPAuG/GiwpXtMrLW6gDXonc+A7dbei1mp+8jIagv+YZnOzY0mF5Eomdtof" ..
	"PIJOQqVBo4SXSVPQAHsg5P50wLIPqPHkuEJ7CNXWtwjdaK6Z3JiSRp3EHt2lbG+Pr/io37yll9oPbdaxqbM2qvO+YLEc3lNzBHRh" ..
	"Ud6ZdVdt2lUNgNpFk83g30RBG/zhIP4Wq7lmg5RJTFJqWkzzcDG+aaCkPY8WsQ3c2yFMrui5mWSbAlONk6cO808Pyhmhj0iM2VDQ" ..
	"kXm890dKG+uFDhfo4aF6IqjGWNrcpNQKNEP+sHtPesK+JKQZTcG0mNsrBCsQjh22pO6rCIHV1DOF6rNuebAYSM779joVadwxbfgd" ..
	"JhbNrvvQg6JVHrQ9D+ZgQy5+loXdc8F1/B8mcUbqObtJaUShncSESHeOkN7eJXRoyJZ+Whyk7KJPKBPR4I0saHlCcuSHCdVQ9Mf2" ..
	"0dG8ACcwkq6aMvRO9rnFmyacu5l2CsJ3gKiq7FtBTfQ0FPMuG6FHQsPwRCbzuWnokoba/rbM584kbHmCFyRglaQRoMkhBaJ6Ncv7" ..
	"MH4MJGFTXT4grWRTrbXe0udHQmE5Dii8hVS2gEklgyaxRnZFqQ979WrcaI+9PvaKvi3BUo27EKYzINScBUj9Zq8V2Wp2gfSKD/aS" ..
	"sIdciuUjVR5opciUE+4Gpl9xyHm1qiC/B06R4Y5UsVtqPVlRKw0iuhwuFrjGd5a+8zeiYbsexekFA5T19Vt6K0df/pGnYR1PbRbe" ..
	""
local PAYLOAD_P9 =
	"M0o5b3XUoQadKRFBINNOCwKFqyCxANlX9Dkn7OHnreZnlhD+aBttiiVNU2kEuCyvpZsRzmEcdr/M2rye3+eK/vauf37myj0m0Fm0" ..
	"N9orD6SIhVKjd8YsirmlvrMnj6NroypIwNoiISnEyDZH/GQgY+M6hA/U5osqLYZZnsrL4Av18tCfz/HbEyUHYDgEkpEFmnRbwRgr" ..
	"I19gYBIkI4SG50nSroeTve0mZSeg4mx/agNYQoAmiMSezeUoN5kT2rFeZS4j8KBDFg1cV/ByjaUnCRCny4XvPZAblLrEpszzt94s" ..
	"0FLNIAZz2t3XjmgGVgH8aS5yHIS0iStK5fb0xs/83lD7R4tvEHy4nODshKAiRBUi1Qq0wglgDbnwePRL0fTiB7utNDGauhzmvW6G" ..
	"ShLX+1aliJyo+75aTC73wATfjE7uqGVoRLNuecPTd5guZa0fTDiIDieJ5ABQeOi2pn5TSMAjk+lN914K75ngp3WVoasKqkYelMMv" ..
	"fE6JCuqKATFb1PtzmCd/nhU/0koTS2lYHflONTBKrWGNFxjdUXZOtee4rp9WWaH8hwsKcweECj8SsbuPtIw02G5GuIqUFojJyl/c" ..
	"V4sLSlkHYcK48hEPsFPpA0Oy5vC/NuvnuCFXs6eS3t8yZQJ4iQG3lHNfy2s2BA8lYIgelmIkTFr5036OrtmvzK2lHyfE7l+G/IeX" ..
	"l1ap4zcj+cdos/SX7BFOQqqOjDRPrYm+0JlDZ1Y2JwcuBe2U251UEuH9EqnIJdueuRGeepOyDXiSmp/RWGAi7PRmA93K2mYHKSW9" ..
	"L09ztGKt5sZP7HS4fJsaItXdMQnvbs9yjbi6Wf9fZFWCF7PkawQN+LbVEzvJQ984pvevR4xjTy498s72sSwQCSR+3utKKhG+2f1H" ..
	"ebsVkVT4eXcFpdiRDlaZKZwnxa7SU6unOJHq04K1eZRUO6dS+iT1lFHsUJh07irbEqLPKqxqxENixFajAOVxgNV47cUKAmwEmMr3" ..
	"b8dnRGI/iwm2QLB+KCNtkYlblBTdqSlwkh/zMW+lMeWP5DrkSWSmpRCFo87z2iQJtz3J6MM34ryHL/BUKtVJcTNTdHHuilxrUCGm" ..
	"KxzzoeFCNUa5aTtZWKjMYoKK5gMf1LrlmwXOeZTswuBQOYSz3fQz00D1fDJlMaDKDlwFrsEPuywTOJ89zEnz16D3aFKjX/AeG9Yu" ..
	"T8rheNa5qQj+CkKPcmHfI7CU0AaiKtgCWqGSwW9C26rGquwxPv3pmfk/8wLLjwEXS77Zks1RA07rHdygrF2XGDsK/q+liBQBpApB" ..
	"nLZjO+ePYXxqHbz8XFFjJt4poYarZHlaOKuhYyU/W4kCMCRBzSiSySUqofvXDV6zKh9ihwU9vyeHJm48rXL8NKytvef9byolChqO" ..
	"eGOEyjwu3FV0GF0veJdiRIH2lacH3dfokC3QeGE1cq63XPVhJZ8+/L/HWC0vpePOW3P79E2PtGF9PcMNjOd3c7UZhFzZ8J8uIpfR" ..
	"MfI+VMxmw5ghEbQ9AZQJmmj4qA0+x6WSg3kVOCaYrKFsltr8WRVlZtEHNpAINWHDkW0434qweq1jrdiBIzHGT9yDhGnqX7D3ELQd" ..
	"HwNOky+KLJEorEchv/yebh2ADieQpf5RXkp/stuhfZ/xfgoem/dF5+O1cUYvdWI08k+UhxxiTaA/3Z1Rl7LpAxcjK7en/crHK+5b" ..
	"jQu7FGw/Y1OBlA4FaD8FkP9bN4Fmc9reusOTV24reYVEJgYg+3PSx+Py9qNprwigxuNXOfdhY0Cot2ZrYbFgBrLD4g6tR8WtIzjh" ..
	"PY8xy/bxql8SqQbA4E9dc8MbphkpYNk1s6C7pX9LJkmlLpJkYHbfy6CGIhuK7QOg34q6S+5bb/ddshqxjkOEHNewayNel+1nIrDC" ..
	"VRs+tnu+pk3MDs46ZpPb7C0MQeR7VKoGDcxcvJKUIJq6jxNMeHeULxk6kfawu4duAe364VjTINc7ZLqKmPqOWSOz/fWUWuH6m5Rv" ..
	"T3a0+MGo5r9UaNnF8gPviwPAblhk196w9L3cYUYJMd+b5y7Om2B+XX9EMXMNUXrCHNG07BzXwT41CiKfS2eTbyZhPfbKSL7rt0Du" ..
	"Dx9vhtsnE3aJMtDkjjFsSMCDG9Xx+GryOUIBpJJbwEFR4DQ40xzRH647V4itvwAxYRhwAYQJGb0AdnzAiLt3jXYPFIzyyqz16k9C" ..
	"nz9QVPk1VRFCgU39WJVlEYAB3pI3nGc9VOnn+2xKgTW0KxqRejoAF4mRqZps9CsBF/pm2nSHS8ry36d5c7VxGuTGInb6dPKUdaTP" ..
	"N8pBYkT5BSEe5Hgir5lkOX1IfwtR0EfErZ8Kdm5Ks+vCGgGEkxHfGjluWQ9SPZH96vUlmLs4MUcdLx68MhZ9YFdCCoJJ74eWKaI7" ..
	"XJ7qPOdKkGyDim8U7dzD0a9RZvIhTGIs2P7qxQy748jMMB/gjoKgUFzGfCKDbpuOqv2nzkw+b2DPRvzJ5q8Nv3oRuwB6sC6nLG6H" ..
	"5FnxymNjpZTZypIDANWNMX9glZ87TnM2+PnsTuskdlxKc61Bd6x/cLa+/OM/K8N1/PmqQsqqbcs1M/hOb8zr3nbhLRNiHnmvH32n" ..
	"zK26WU0KfP0iZEIQppNfICemEvLE9wsSOJzW61k63rW/8NQGAWVMA12FuN0+RsGHhNblIEG5BxbkKT4dMoKQ2ZQw89p0LoR+PPp+" ..
	"moaZsu1QCK5DdVFWUYOOj4YxI3w+d4RHOkzB1P3NaHOMrwBhhk/TBO8gz9t5tbbfN53Vc+s21/Cdvxv0ziRkaQhf14F7baDbzDzA" ..
	"Ic+r0+8vVjvTJOCvpCLenNyxdveG2cTlpiD/DPkE6LvKHmnOMuoSbyxFfZIaP99VwrG7lGHPa25Dm0vMuBrghziUHy81oW2eDhM0" ..
	"Tu96Jsbj/+Q6ID4u/u8sHbyYysHu7MLNtuOr6Ym8fpFxbNEIjGDxPXO8PrX4uWqxdNSRACOASFhXCQkFD/Y/VS+yPtpzkH0hKmb/" ..
	"pPYiqrrfjQdjvbvnjDhSuj35OAuUw4Dw92+AXYNvfw/ufijVTaNNrOIUozpFxrm15RriPHjaM5wMx/2j9vDbYaYqHict7UkZWWrV" ..
	"Gaz/i/JgVhLo/1S6HTr1f3IXZ/PqkvXsq6B6PMTGefq67yeFx16jmvubBdrbPMjTbCeMNMjdaRjmwCI8Uk3r/ncVJYyy9f5PlMse" ..
	"rat5VncgnnSgN7xmZh/TkteI17P+51f6/le0OYf2eP3vP+1OWRrJ9t3wwrVksAV17eeRGw0Ui2PhyVBouAHlPLmaGKpsbNjZrd5o" ..
	"USkUFZsDV9dqrhKbOlf8xdpZThLaBHCW3u55Y/ror+N2Ju7w4RGxksewj5DRTe18BzEnD7nA3nsa2kcXAYZ7/SeglnGBWzAj5BHQ" ..
	"bmPC3dPtmTzLhva+E6sLX0C8FDh8TDUUSpxuEkC6BwM4N3h8cmZ70VwYO/d+OBB6MFwpJy6GCi8mkQvnYHuQVqEGM8UwHt1WXEji" ..
	"fEqbD2+6pHlrAGPPtBTqwCo3PzS0rvtcFsJAOLTIOTX3fIBk0W8ONPWcvUsOACI3M/pL9sT2E9JNRdn7S3+8Tkk06c+IcNPPiNNG" ..
	"c3FZWJgd0LE3DMoiLETYyXvV0lW+fzURmGQFtdFdi+Ki4xBxAPTCUxda5m2HozyjRcIoAw3EWDVyuasQb1ucgcmZKpwzzX+I1zCb" ..
	"J5VX78O7473YJxWnKeS5/+S3j+YYPpFpfS2XjSymYWA9KOL8V15cuJznWuGjBD07hUrVeNmW2a1TNhxDCDpogQ46QUJsvJFMM66G" ..
	"V0gl1MnW6UJy8ROROgi3Cw7ccoHrTYGRBnIhDLfpCRzCcaejOqVBpIRMrDxOh6y480JqWOkeMGCxWCrgbYdVOX/BGb63PRedE0+k" ..
	"RumJzW1OdSu1JfznrGa9R/rYaY/vm0wu9zvQiMgVFPqmdHgHXC9CcztI9rQZmNyqT3q6mPG+D8tPfMnodQ0YpVBn9Jb923E7J853" ..
	"V7uXlEd22GYCd3eq0Wkv6rsMSh+WiajqAalQU88evoI4OEV/z0JH5SHfzXEaiNmGJ5goabNLxbGwD35YfYx5vtu2bgg3/Qgiu/4p" ..
	"qFHYk/Vr3H3GhRFH1I+Fqoo20mZM1XV+0c+o4JVRzNeJFi9IeAIQakNb6Xl6GnCsVIpVDKYl1z/erreuZjOYjRkj+VY7mD2WhZAm" ..
	"CxfkxWILqmfX5IAUk6HHwSy5NPMqRQK3MGFtmHNQfeE2YAQKUbwmHwqRzUZeDhTZs0Wm+qDr+7vPt5/xFKRCXn2arB9yZBfZUES3" ..
	"VD6PmhCWyrPnymvC0t9A43IAzBirq0XYROqPL1hX1Wwc+RO0HLeC2AhNApFbjngHvX7UJQG5mXThf1k+8kZG4AtmYJIKgAv1EvNa" ..
	"qOJ4+KWMiNsFwY1G0UDieabRbdyMW3+OtOSQ4MMqsktd9P6LD++gVxA/2e8RrPX/yYdk6GrpJJ+6JHeLNPScyrZboeg6EUStt+Iz" ..
	"6pRB2S74TABJHk9yR+xwJbMpSailH1R5RYCQgSrMZO2yb/IftqIUx2fwUh61MLp8VV+lEt9okdblOYODgWw9rJsKB73L2FEnHbkK" ..
	"+B6jwDfT+Ny47hn4rkg15m7XEgbRo8CAkA11gt8Pi1DpqmWDHUgndFzSRT5wUQ2vXw+fcZH90fJ9eTVcc7CYAVk/HGWqa10yk3QC" ..
	"8F5ZQ5II4Odo6Bga4BglKagMV0i9yFNs71w8AYQXVwQUfzEfTBqaqdZivgCgKomJUjWYeXxT8ovYw24gH/NAzTD9rcRb/G40Sd3u" ..
	"pO5QsArmjKhOt9s82QS5zQP9IUzoYHH1Q4yJW8BgoI3G0OwFqzzcPkk0oz9xCn9IfykiLUtOBWNUL1PGtc5amRRmzEZ6IH8h9LWk" ..
	"ys4iGxcmSrDEIUNvISUgOhQdHPsKoI9E1t4UvmqG3b3lxmjwt3lDS8dat/7OoqE8silLgumKKFTse/5nqTE8zqldCZgKdPUBa/YH" ..
	"boa2FGzo1WnzjWGleujJUklK9+0pAk22pdv+/YJzaG3cnbUnfCkjWM6GhdeN+FZ26H+tFRcd+QAvffeaNa+SJfTwr9lkUlHVT+ZI" ..
	"dh7Lh9VDYtwKq56AsdqiLodUmY0e6IAJ0UuZ/3a3GI91b90mxxo4lyPlaobMgBflVZUanyc0CgkLk4Du8fGwAyDWW8JiN/twaLt0" ..
	"mjYPBbZ7ET7OwuHGQelgk0jB7N8VUjusP1NDD/M3pNVuJdhYeKUxFXAW0JqlF3vdTr19HHYOruE4+cmdyC1akGrPnRcQIH/JoPiM" ..
	"SJU+pobLtP4Pqfyuh7s1c2CZFmbOw7Rr/HTIWXtCbPXOMNZ4CAYWLBd0dUj1aNVn9rZ9X3nNRZ/YOBblwPNzfEwErIae9R4V1vyZ" ..
	"v+auEW5JyaryKpDQKpQjgvdii7HeSyfP3wqQE28D5yAGTRCgmvTlprp9UwrsH5gAHvi/zADHB5eFnVNiVkb/ii5ADzQPTGeL2owb" ..
	"BhwBDZnEsxC5wuToflJeQs42VeFeweokhe42ZJufcg69ddvsfOSO/m6m2xwbdXPv/3bC89JQe4KHZWJoJ35XaLx7RIkIMcqH8Tqo" ..
	"lm5QEH9BK20uyIF4HPlII8lP65oYKBB9duvOx0XmbvVHWA4lgJCGrGSdqmq5WhMF7b4QFH9acF+m9q9MfIK7aJ+5FwAWE+OYc8Ml" ..
	"NGrvn5hBUMtk5kI1Mt0scojh+4wQssjVPMye56oHHdnVGaL8L4ilwI1LJmENGw8iwL36aMRCLoB5o38V0qskuq44G/euNzUlXR3o" ..
	"tgKIvW+mGmS84eXoAnrNj9tn0mwAmmW0KmltJuBrmDqAjHdkxdpnUacwOF4Wiyo/jHnmw2pqF0a7NtVgQg8WMdRMxU2uVUsSfdzp" ..
	"eN88HF2QcyyYrOuGOArsOK+8ayqGyQk4sQBVtUUZuPbavy6g8aAhS2BXfxM4jQzVniCAu/XxgWFCdTxhHDnB+0t42KgMYb0d9NQi" ..
	""
local PAYLOAD_P10 =
	"5zx5O61GUKxDYyLxBhIJlhvs7J2NKdZRaAOChv2rwD8GU9gFBYQF2nDD48OtChJ/BDUD3v/r4gJ9rwV76Yks6wFscIyoFlaCQ6Qq" ..
	"Nxh95SKWt4SWwot7cyxsvhV6Oyvf2iXwfjNr4GXys47E9STah8gkmgcw/JGn7vITX3X5Aou8bteqoR2vxx5MFqx2PNgh/LSmuKiF" ..
	"ovZgbzLS0j1GzFysnfI4BM4WLQKR3smpMEUfZPa5K87SrXcYDd2z83Q+T3UFC5ACr9Da8eimm7W+3xPh8GCpeSlF0YnoUsVX9D+i" ..
	"8kdoB2yOf3S8hVRGgonx+hOPYj0HlFKERwekOr/NR3VaR1nLulC8O+kIbkVZWMyoVCzNA8mHkBWYMJrcqibNOTecYDnhw4R1ZbEh" ..
	"GAvUKSftD5PKzg6p1lTvgQ999QoKl2/ul6vhldvP9HHWcrQL27Vj2XUnBvcXpHIzkwSjBJibyObU4h5rOiA481ksqEdoo7zwqIwI" ..
	"Ts9lIJ1dy9VhgPcKdPZ6UsNpw8FryqaY1+XBxnlj1BT7ePpKQTWAo7+e9WRF9emfVhOvfB7lLaDNjtW2DWAb0Q+PpDmYxHbQ/Eu3" ..
	"yK2zI8qPkBIQiLgT4TfBwwcOReMdF0ZFfEuhA7HBCJripx8vlqSA0q/pq1UPQ/d4jxzxzk27R94ZBtOgv3o6Qw2hUvr98n39Oa3h" ..
	"v5ttwkm81RqikgtCqGcqdAu7/ulCmlKqm6Jt9dWG2LiAaUIthILl9blf0rtdnwcDj5wwlyhPB2n4FlXChdIubRqkIGnxbMa/Vk+k" ..
	"3mCPPMd2FUQ//+5n1oNQUI7SLow0IeAmMZ7lgAtDl3g2iQg1KBqaAsBJLBQwlTnB+tZzSo5wQRuzxA/557+q60Uw8kn2QpFYkCm0" ..
	"b5eZ00qIcnAa/NY4vp1O8JrfDlBPKLBxc7RWHEcUNa0uyI+/VyIJh5KqrpbvurHpGdCsNJVxUlrHkJtrS9XiS5gGfdLyEX58TaoC" ..
	"lb3Qnqoz6aAbug7OyymBiwSheIrF3WuaJUS4J6r8o0u0ManuewDEek/UMnkzxCi0leGmb/zTCuNWFQ8yFPxL7wXWIOdqNdXR17Wu" ..
	"ftOtAoV2kIom45ul4exVaR1+sgxR0VJOXeBbgZS9d54ylaoNBhKAdDGvR9q/Ve9zV5BasnMDZsuyDXWQtxypSo4esIXQjNuwhyK9" ..
	"hRN9PmSWZTBpGjnT5160e35jZ17uEzkRgunJjXM1hzCS8SiKQpUsa1V4VjhuXrm00mYVwCja6jDkdbzlf0kmVMoiRHcEZL4OZVhj" ..
	"PSw1Ln494mF+I97sWzpJOLzKbZSQHDmW5nnK4Q1d2EY4JTAYPFITDE/vVuLKwCQEJO5b4uOzYR5MyYoe5/iHS6SntPwc3+CulbCR" ..
	"686Q4egW/A3ic1uxyuqxbdn9ZeVE/kOKwNIHq9drmO1nI2NegyQmFISdcHPMAxxAmPI0UPI0KJKnNA/ctPhnOtV1mt76V6C+oukG" ..
	"P5sbre3nkbHJUtTrDHz2NCwDTazcNR4eLPvvLSupOFvaKRv+yScTZ/Gi85LuisZ0sBAxZ5Sf9+RWxVvZQHvTFgiYri6hIabB6giE" ..
	"MsgamY/2buqA4h6T43DGNSaSJlgaM5S25IZeGIdtMq677Lb6t4Uc34g+EicQGHYoIz3gR98Ail6C8YtA1RmttYy4DIWPf2I/2u3b" ..
	"iwIaIWXs9Wu2/HNEwhqbPJn5RdBVjIXQ4ffdOmVL9JqIWKynLVjJQ6mqOU8kWShE6QoojFdXaZl9IOAfPfiNTkxI7uZMv9BlK7Qk" ..
	"pdPHFEb5Yv5I2B/S/AZaXjaZ3uDJEBkbvxzSZfClPthdp8RA5HoE6jBcwumIaEUpF+i/9KAsBpG9txEWGwU6kK9yu1SXJ7VJL6Yo" ..
	"+phvk0VZ4oNMQdLPJYCyjGiueihxTpawlsKIOcv5MNX1W6V35v9EsE5XbQTQ4kAIHBr/RLcsQu9HMzeMEbeZx5Sd4RZm4DDe4eEK" ..
	"onuTxrbaxg6c3LVf7UKl7ol+BtS1SqKj6swco7btYUHmOKqbkwApVhuVYOtdZyWzCsn48/NrhpGvmvsDoBnCSdCbsj+fR1nNSRiE" ..
	"QaH1ebsra0WTaT+mQ4Y/qAOTGNNkqCO97GcgPmDH4o1wG5ReYHM4yALVgpYVuB9W52ZDzyjG3NXoeLtMw57iNcEhovipMxkSl7Lk" ..
	"EPWdaAFOV35Q2k5BoUWRndhBGD1rH9bApNFFZrVYvAHNYOI2KQgnsUSDeGP9fNtwG+UyoZAHC7x469wbY0O5Mxj7JRQTGQBeN/Yb" ..
	"TWuS1E4/gWrEuMgH04Aj/CdjyQCp9yl/+V89k8PbSNR3ZKG4+Vej8Xl0UefaQSOGOq4qrR3JEeDd0BIkP29GJ5687hcMJSXaUIl9" ..
	"RYf9gTpJXNhOvtI0cfiBHISm700dttZMJbTx+MA8yT43ExtYTTAywtbP5bLQMYJ0gBXXXowliWr/hgEo3hJunGpo/2pRlCMV19Cg" ..
	"B4dN0lH3JYnjyKfN8Y6hshWWu9BW0m+bVTETjLZ4u2h1Iba7lIN3HKRXydfirxWf/5wx4f9YLgywXx+Lt0OvdqSBqjJ8ef61cGJ0" ..
	"VrShCkk0Oh1BG1O8NdE3pDj/DWqwG5kEmrHK0DxDfeCNcHkgbPhFZ47Jj/SaO6IDUjhurBdDpcsKa5YPJ/ICqDuXJLOOU0+0/Txn" ..
	"F3rRyRoDh2beeAbSHL7OOXX4H3n+DrX3bkStgv32dZ5JTVA/wDEdCcQb2/W999QuXX1s2+evqxk+MkMnVmh5isOw9L5FMbNB/Y90" ..
	"Gl2jmr5xVyHLq7qigjOzLC8Aj+qSSRmP3NJlckRJ282YQFWi2vH4UmiBZmKTQl7xa5qVw4H8eSW506NtvFDvVJHDPHxuaGnqU+WS" ..
	"iZC7JmSG1YHJH5GirftUNkt3rXPpYjayayHHaWAd8iwqrYgyDfn6i48kdAnVOXDqbbbjXMpFmI/vOAP9bcI4+KJ3aLF635d8D19r" ..
	"7VxrLcN5v9Jy4qlwd8FyDg8XzrH9qkZYVd1l7gVlqVWaWb8Ot4nm+FF+xDHmdbXN7KmM/f3mRMvxSi34+aHh/KpyyamtWGs6WEXD" ..
	"iTyz0rAnz2hXb1P57NFDDkpIDaNtUqzy3Fqi4b8dGJKmedqCdlBwO+Xog77oeGJDbAxdJee136W8b+Bdb7j2iSRg832ZNjcHjGu9" ..
	"cAdq9yGx1lbIpJTEFJfh6hWGb7ikg3RI257tkNKIU3M2xzx9LwA0jz3l3f+v/5HZOR8ukZeCyJBc55t7fOr3GBkUfyu0CqNmC1PA" ..
	"dvApGMQDBltTWN7b0EO21G5LAStrvXHfHRZP9AZsjHX8Mpa0eYrkdKhh0ZrrxF20eSgY1o6hOxr3BWASmgbftCtz5ExqkfqAviG8" ..
	"4Pi9JYdJLYhHeUrJaI8qDb4xxEG26SJJSmHLwuxmE8CArat0o83AhwqO46q+XIr8dpLbD7EZ67QnEsXn/z5rMG7uPq6fdOS2uYl7" ..
	"qZry3n3c+a/53Z5x0zQqkolT0HmZ1q39hhWID7Uh2pYCPit6pJTzmUlFWGWk5+nFgRstpIMoTTWLQnFXLLZDjb243ZJo7cxSeerS" ..
	"K5dwfKk3MR3JnBVsyXRD+/glluQrTIw4jqLHkGxqirIVICXVdZJfJt3smhA353dxiFSjNownGFfejq/zIPcyy4B8k9dUVD0+0wut" ..
	"b0fIJTmZBjRFdT/jQBR8lYeBINrUP544JBOlgHCEdEQft+nVbydDFuZTauQf4fXgwz/TQWnT/b3chKVcAfoAgE8TqwmJ03eWr0m3" ..
	"26lSzQbSQY8QOPZ055T6yYgEZbgctMAD0YqWzKAjBmraaWWxgICuN0HwnyeFEw==" ..
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
