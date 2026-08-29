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
	{ seed = 1906059351, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1910786113, exp = 0, plan = 0, hwid = {} },
	{ seed = 1911368740, exp = 1788089514, plan = 1, hwid = {} }
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
	"7gixsezqjaW1wN8e4Oaa7QmzV5mjeDe3VP2cIy0CkGiyXiouacsCEWMrqb248+vV5L6cARRKp1f8Rb8ndeybKPKUNdqjbCrgwUOB" ..
	"KOCbnDsAl+dnwl+/icZlmUxHOZ9NwRCqYrNtzrlA05y9nuennXfyHGAwQE+Aj6OjCDN494VnpHjEI4WnLGKp5DasAj6fUnt1zjYr" ..
	"vC/8aWtOWgpIlnezKpIOQQRRm6YDMAypsj1PUqDbvKjHNIyaVhA72e4mMjsdABKp6m+njqCT57rrZHIjaIlKlo9yCSvnEWAxfvs4" ..
	"KlelR61ASRdXpNNAp3G6wIEPmo1WkzFXMAVLcTtfo6+hzn+EHBdGNuhDSNcXRA6eqBYYsrWLckPmx0WwXZ61wYtU28wfmH6sECgm" ..
	"DV5tyl9FB2iQPtIHIxRxMYdhoxpImqhVseQHHDWnCP3GwtJWKch1NxhLQbgoF62fsxzl13yiZQaV3ktmG3SarbW3NEGt+p/fQZ+r" ..
	"IZ0yXbiAQHfvLSmTAj+K9hrHfKRhYEtLkpmb9ej7JSmyuKbUitPBA1wu1q67XDyVLyG/ZausNd4OvwU/MEk1g/NLTe+WDObTp/Im" ..
	"J3to+3nXFpX43C2Ju0QHin3UQ4OCqqoF3xyMt6NP6thItuTFhg+N+ipqT9cUwJyPq3d6W+/YAifHpMt5Z7yjp93O2dZ2wRE7wXr2" ..
	"5i4PZdZwAt3cvjPHhuWcX5da+mRuMqQMb3VfC3u+6TVefsBj094KK/vx6pkCire2NEh3Ie++krr3dRge0CspDBaN9j5Q+KIUqeZg" ..
	"Jih/CAIxYM07WjrDAW7wRl7cW4CniXdzlYmYDwe9WuD7unKku9jhApLZfo21cPXMBbkcDnQ6QbPh5OIep+4spFBF8xn+UcVzZEEC" ..
	"VVrsUyvgQSwSINTm0zyV0OSa4dTtuKJguWII5I8VsTZmZ/Y6+kCOxM9Jo8iVIDR2wlNH4OdvubCBDOiG01tCcucAaYh227vtONI4" ..
	"lVr3+84iB4b/teVhBBFtZq50HNclwiN/zyfX/zZVz4Qw75YElrhJNb/D9al8eKVcv6rlKJiUt69KCKGqhvjSNi7MlZE60qc3rQRk" ..
	"pZLwkvnw1CoLWeEaLpI3lRxtwBoEb8SrO7gz3WUAH/05Ha0qUyOSZn8EfwieyMLoLurBv5SvYl1rYp0dVmAzzi2yfuORegFqnm8X" ..
	"bi1gI7n0JV4Aiv750zWoguIs96SV91tFlxyfP6FoFUbMdn26VpenPK693kQnsfIbnyOgt5/6jdsT4GM1pNftvk5BPkrsiUN40J54" ..
	"BUADz6w+HGYPVQE1F+Mjyl/iHjUP2drK3/wVGHw52yiBXJhD8QaxkHpfue1+tv3wENVI8KIx/knvp+SeNi/UZqNaDcsm+Swad8SW" ..
	"n6oVV7TL8+c//RPcY8eUYu0TJv4TEntpGVuqqH5PkFsMmZ9qI5PP3QxGpUxL9RYV2XAmtO26v+Ve7qzX4dm8ZVJH9BYwFlyQb3zo" ..
	"ty0anzu6hbzaOF3z4Fy2A0msky803wmYoiNQWrfgLr2FHRs/uYw1T9Ou90lLS7/RprVuxH1Ny59UGEYH/371++slee1Bl2tLqFt/" ..
	"LtSuIPtgd+IxUkZRyjugrKD8CY3ev9AMHhfwCu6s+lCxgOd41yOvWtnw1KESQVBZ2UzmerTnwPTxlYTKKZEjBezeDwVlGPOACcKC" ..
	"1nNMX6RNyBcoaD1mr+M+zYAgAQuT9BrTOd47FUVRf1qyEF5SreSfdHMfS5fuL7dHK5p5X5OF6gDIJBHCUuiIDWbk9DhwIAIgiBlN" ..
	"9Grsq1krYOfVXxqPtLuHE3MGN1ui/QxvFN2cymam5RYg1vVI3txcb0NtDTuE7qkBXThKkOAJKeMA3FRuG+qz35bCAaaLNj5JJJqP" ..
	"YgNCF2pkmzpBWKELumzp0UFW/dhKCvaewbKKPYuD0k2fpI3ozvDZ5793q3SrnyWaVyi7YAHKn0V4nPB5Pg+gdOeCHeiCWA0xDArS" ..
	"TeSxnZ5gCMGeTPbnzsO5vbMZv7AYSekBrDDafqD0FMIGc1mY+zIox1Y+w93Dwu/rhlXecDkMvzs42YTw/GGZ5/k5yiAuo69WXhjy" ..
	"1sA9kF3fHaGiUVTrtZ7Lxs/xJLhc7j1vi6qEdiLCKF8+WNr+KfaF4ggrpyTcxrxjV7dHZgNPtWlxkzAvCh/VAYu4flvgSX7d73Bv" ..
	"t5tIGdEhI5hgZnzo9aIQzqdIJ68ojMmrs+NzMJ+wg/g4Bu4NV0sTL1hEQOO07aO7fiJzext0xBpjx3Ld66VEfkkA+iqmPITNv/rT" ..
	"P227BV/Xb/7iKMgRJDQKl/YWMxKimXzasCwj/CHUfIZlxDnVGVxwM7fC3BKhkkipS7UaPmmIYX7rA0TimWuS5m016Ae0lL1vkYKy" ..
	"dqUJW/aaByCEjfihS+90ho0oOBguf4u2eEI3G14jtYgd6rapm21guMAEZYHQaucIR8x9viKgZ17oiaZUL+p5+kRzXsSuTKbxCeKP" ..
	"b+piS9IyZvaEf9SjxF+i5YVzdRCqWtcKvg2VDyrVGaeciph+WHXB6LM3+XdY5cknlri0/KVp0cl3scv2Q2MwtNZNZfC08lCxBm1u" ..
	"LfI+Qb+QYavFj3inMAgM0qrK+vkgm5hZwGPd9zKtlnBkFe87RVj8pRRycuJItUIeXH3/btzyzfpHQf5ehDt0zhaXaKyS7OgOOi16" ..
	"0ZjPYR4llH2DvA8p2+Z4hzeEvpg8C8bFYdmpd3nEEoD4/0EFFaZdHcxPXwiHJIFygksL/3elR195st8z92LMBGwFQUPxzCTTxJzs" ..
	"ZxqDO4mvz7/q0YjxYey20jeQe5RHramp5ePabPcE8dumIwJlpezDQyGdpDCm/9Y6TEDTADgn+5PvIVEKk12unY7UTT3t1wxECiDo" ..
	"cz3zJaNqvRQ9/pZiXPTs6fwVItXGxqGGRWmXrGARzyGImOXXxDrOVZ5GzHkQVIs96MwaWSsZe9gVIY1g0YhIUFHRlb6V7oOK4R5n" ..
	"aJyR27FuJxUPRuPSb90OlVlMDJhvTu9GgMbtcDlkc0pFp1eamxMf7MSrddJ5PgPBoPr6TK2KIcrmK3WJdE0z4Di4g36URGi/WnJp" ..
	"eMoK73qf0QRb1S6GDXvvcXdGENqc6YjHJ7ZTvA8Sx1JNxAEc6Qs2WPQJFjQU9ilNq2Tn3A7v10/Jn0KpPGgL1M591UNtJxn3HZZK" ..
	"md7s2Un1iq5elnaLVF83DXc5KknjMIQQEZMfIl6/eQsyWz1WMoyt5McZYA2XkiX3wUeClnDFEsATn00Edg/zQ7Az2mtEfmyCoF94" ..
	"1O7/+v1D25Ob0iGq3JsaymgPfhnMnXpm4H9lE5kinpJi5rt+dY5W3QWFIuvQSOkehatqmJAcKVagVhS/jf1ejfPkN9hiMC7XhfDt" ..
	"4AFZKddqRFuqBQudWXydAp73puPDXhUajGV2h9TasWQRlbhHiPP/8dlaDE5sFG6hYPTfQThkwSskvMlJOFQdZVFDQc16mgFMqmS5" ..
	"Il9w9bNQ5BMDkE9OFkw0wTf3zpl3AyCaOy7oOi0qdckuvUo4Yujpfn2JAHrtLhYDwgveIfZ3sosJQ5CgS8a+QFEPVyEsIjQfPYwI" ..
	"yOhQTxYuDPV0K7TWI/OEXqLxkybvr16iwPsXj9BwHdD5Vr1orji7BpqvDHFyoxwIt71pFr57qpQQ3j/Q2J8jYfD+xfDyNMg1Q+nJ" ..
	"OwXKc0i2rTwMOCGAdOAILOAWpwLMJnxj4988/oEDdBO+ySChdeaFNvlA4v97g+wS+kkhEfDAqxZCWV4AlKE1G5gnQllUj4esvAZh" ..
	"s8c66Z2exTyTEBIblTS2WVb7JUJLF143xJl60E8/rn0QzTwDt2WWuZSvYapD5Dt7c64CdGLEoy9M0lrhndr99BtShGiWlBfkxr9z" ..
	"7/TobKHQhdM2LNlD890lCI8fU7mIzRwRjM5eNSMRRfzhFYnsQLprdHfX7RwsWPaqo6cOLAyw8oG7aHlz3lBN8CmLt12y1xLZPgMI" ..
	"R5mTD/lFJngTh8XxRyLS65dXVvB8BblEIuOsu658S5cOB7dH63luCEL459mXaCT/WC4l3oJp8VoWUMcW5MkioCq6mWXHeYIdgI3d" ..
	"UDviYjXmkBtupMhYChycJSB5tALWPTBUTtKHIr4Nj5/3LX0Z3napBOnsBjJ86pAzCLYEhpF0+42/HntVqeVclBT15Hh9tOzJKfgq" ..
	"xKSEXsmLx2bcSvm54WhiN+mbBMnJ8DBYKQupWSfb7yCnKUMuc8Uvxjv1DwIufazruJpKErgGVvKeLhEGMNy0K3Q9sRbSpy7obVVr" ..
	"9ljgt6s1ymP46Mnkdr0stvAwL9SzTyjs9iWe17GiXetbXiyb68PuGApo+vwhrCfy74QA1z+/ACjiM6R5eqwFaNz21gsT2qjDkxPY" ..
	"rseYNqElCXTB6YCANUz3+e5r2+jhcEaCHFiCdLBj6YL15v4wvTASo4CjNcZw6TB0JA29mXPh4YRVFRE9NmJPp6d/2OGpF2Nuy7pj" ..
	"iVMr5Of5KmJTSYsC5nGR2a2Kz6Zoh4tXFBaVbDIcM2j2uvtrf7wsHHnQmIdHgVbRubQ2GBTmvqzRYW9wWV1hWIpOkQQR4SjTxjjD" ..
	"jUEgnIs2wnBTdX0jcCwYibfvVeZeNsFgibtYrVNY9Dn8ciEuhDSBqDFnYFXWsK67+UlIyQ7d6dtixOvUaKk1E1FViXHfIDBp27yx" ..
	"sq69B4SxNW6c9j8/h6jQsCN1zUa5KubFrPH/+vSkEZI2uZCpvX9jp9TZbW7VwsD+kU2n8xZk6fxsLQqvZb1HiPT+T2lbRw/VMQfb" ..
	"3Oa1e1Zz3+zQAaT2RjNCYrd+6inP9OnE1miUy9gqx5rUVCdRTiCBPWT0mergWIR4dt79MBQpV5KsoG6Rrht3BhhSlTGxxidfRhve" ..
	"K9eSJNgZ5PD2KYQARQLzjyziLYLsyrtDX8d4u4AkyAzPYZhqb+QgeuYIHwh6iYaS9hC1M0ccfIttipG8hxnOYyX+KgRkofFdmY+y" ..
	"cNOVd62pLIoViXubxtyScT1R6Q0jiqaUh7hqvN+5HI0k5LOTGcJeFoSlQsnQ1T0qrIc2XFrUqL5J1hVC1iYVUZF9XO3/ig4MeKqv" ..
	"gLd5Cj5VO2UF7Nzj5j8J/38DmQ4WJFuQ0YcvoIo1W0kyYgasnnYiVBXeooi9cdoU1PHs6RyI5+TpyIKmAPRdzSN3/daAGZjUcLwN" ..
	"cO3eLzO4AtgwlLae7l9JzmOTWW/6ji0SfCNMVZc9zK7xGqnTLe99w3oFQam/5Apw6BFfVN9F1jOYeaLiRDe/3nRg/I7qBLbDwQCE" ..
	"t7NvcLf8LDbBrQvB9eTDBFSrUdn+Qd9vLYTlshiAwDkfcxuKwxes8jCN8f/Fvxl1143KkocFQ29QGyuh3xzLRR81nXaqpQjGw6Jv" ..
	"8SsD7M/JGd3FKCCXGwjUzEjqhoI8p1YynKSOgivcxAzirL6RL/0PYKjwbK57XyKjKW7SfpANJmXYSdAwYffnSONKfeh0xx8cxJmp" ..
	"DaZXPgD/Gcw7hLYJyIqEFkrb80HjicWmY3HqUML5Pv4B5M0rN3fAOPpaMwz7OhFMYiaDtlC6b5LMd7FtDCHAIlgO59+pdHmtytrK" ..
	"YJz010xgzdHbPTiu+8jhkgi/0QpYpbY1JLXGmdiztXtjOgZrrrC5T+KV7JW1ztbw8O77ZjJ3eVX+lVu+wLdvwBUSTPUB2n9Oh60N" ..
	"fOE14iiEEe8n1DunhLnOvfYzdcfUawiYbcs+hx+PyB/ta4qJPPpZs+syCBCUZdx4CdHaP5CHmjvIXcaPehf2LxeqHyZzcSocKKKn" ..
	"F9k7hzfqMBXJkcuO7wuzRZqCnHher6ErH10EGjX7hqrLfm/SXCwElfhgyTuzBauazWA+dSN4kPYYQmupT3ynOZqiPA+AlFEq1w0Q" ..
	"TdLKY5IFZJRVKRF++0b1pBbBxEcziqFP55otrWVyOKLcC2lpZG9PRrBAMBkvVqsl+MNPFOnj4Dnae5fkvrJ3JuVS/RLZzqAwyCH0" ..
	""
local PAYLOAD_P2 =
	"Bf3xonf29Yx6xMZ7sFSPuHFDsS063eS8KilxV/Pdtx7sJla2xLtFjhCdX2rcSqmvlt5Z/SJABIesMGWjQZSAOsvbpR4g6w8v/+5I" ..
	"hrMTvqe2N7UNtGlBlJLbYg8p6T9MFoKtYjbQk1SsKSQrBTMoufVL4nVtEkbXzF3KbgLso0lDixOUPBcvAvrrSgYDQe1bDsCKQWz3" ..
	"GA+qPn10DP3BGJh5zfZfsIvg3NbobQFEats7WZfkLUal9gwVpN4G9OhERCD7wdm/hi8EBLyKwZUqVQjCJ/ouBNmRfIXN2wVQHAT+" ..
	"tRmQvPEq5XOIfI67ICpmBtXdC4/ASSWYczGQtNrdDlXKX2xwZLb4MtGFcOsSa5JOIE8736AUkhTj+QqgDwn/6DXxvgpVBZpv6F0S" ..
	"6CG9tHdvyVQaGWRrzwnqVAKnArH/jeG+aMdv28NW82ybfpa7ynCu5+x70lXL2ukCHM8ZQAnMfER/ZxcefctjBoqTN1sjxJ/LR4su" ..
	"pqzxCHxvBcdM2zgI75s2hlDMu317qD+pUyBLJJ1f/aVmpmhEVc1xNrVahGhv2Ro7HxqfeQMrnH17EDPqFd2u6Yo4NH9eDdXxLBe0" ..
	"eX36eg/ojP0hmcVNWG0989aYAfNCLfm5oXvKSKKJmGcRK7fli3MM6TxTBYsvJXmhqdW5I1ugt2gmgt69u3w3ZrQXEgdF/lbNQKqR" ..
	"zpMMsVwnuCpZwL2F/i0QDucnKhI1tHfAM7/7PUgF2xm3LSYZBxX0c7OwgUQLDg9q9Y6ta8F8Mm8Sd8H8HxYb3MAFwrhJNZ+SIdf6" ..
	"hv3cXaMO8xHbTAeruTZCsusinhvG1IiWiqLoQHTr9MyiUrHWov27BeDaZtiKG/kKaWKH/8MlrYxcxc8WND4DYnQwSK+q5wbhQJhy" ..
	"8vPsoZzN5BB4RWO2uHFYf6ClWJUGuVyEmjQHvjYKT0XxmQTw+ApCgdOi3FKX707eB1gKGw/o5JpBQIiYZFIkqSlZA0ANrn5j3ufO" ..
	"cpAJGxmsDlpbbqxSdcpccYWrRT9qIpKqONYdMbraX5PNSBvho1NVtCGlf2Wb4TJLP2xmTWJoXNlhwZU5YK9idBXtu05aoH1dDjoJ" ..
	"gVvKNIIPLV5WYhlcWKBOaPD6oUA74V0O8RLvv645bzsCvNfHfkAeSn0bmgD5KRQBWLbFcmubb8feMXKQTUDXI4pt2H5BTqX40TyD" ..
	"GVQ0tsk43XtQM26jMCTaMxXmrE9hHwpiYQ1O1XpSX6FuZNYei/o62/XNqw7vo8h4Wd27gcFB2q2nSob+IxWMiVoQuichemdEqqYj" ..
	"8APfz8h8/NTt/SefM6x21b4g3lRu5f7tPipZlJi441q58QxuukheIDLxLxUWZFYjq0cOu72gcdkpoFl8b4PFZIPjfz65x/d/wX/Z" ..
	"poh26n1P4LqSogCl0zdVn6Xdp1PKmUnhGHRyZDjlV0gmiKIMtdtdw2W2enGAfZBC9disgHxgSotRCKdO8lGbH/alkIUY8fl0hgJa" ..
	"+HlypNAKRkfoYRVuMycUpPVS85kI28EhireRJmLguS3nXp7J5ICqcAmUvd0Q+GG0LEFWW8xq8GTBwvQ3rFDIvPacoByuVvlUg+/c" ..
	"qUvZ/YtjH7azwJGqsVvXXvwjGuYZfDRDow6l9VFmVa0XUNW7czJtAaP8F/5LlF728OTKbCl2ZFhkdiU7Ijqc1y3IBaHxfk2wFlta" ..
	"fk0/x7kfgodljsZO3USQrDS3sQ2Yy4AR1zVHb9LbnQmZapmRf21fxIXkyEZZIV5ugyVx0FE66psk2W7Er82BdZJjLnbIguAlsqGZ" ..
	"ciVNDgg24Sr5geYvrBdxn8dKTv5zERKJU3Hc8DKLfx2ZsplZewRvzrupv1uLtzlujn8LHswlC2vgRlkuaQodI7aI01yycdoQmJpd" ..
	"5YOmKxGZL01+J+bz6ljAkMMhMP9lO8PJoO+0hl/NS/Qhw9qPL8/l2Y1BeL8maepk326CUwnY9YsI1JQ175mUdDwpFdrybQI4jSRr" ..
	"zi0fOH4qJpd1d5qXM2myDL8eF6xJYtxnYvvQ6yc24wx2eyvAc3+Oco4vBZ594aLCbmSh0v+ux+VcRb/Vt28k+oFZDQG8NjJjiDsm" ..
	"8a98Fv1pklLDhFnFDnz+Qsg8JeV6ngVN7OPuWFb6Zu4I+N437OTXPqEKsqCOkooqXVQtJedgSeTTI/U2X/spiVNUp0SBB1X4kpjZ" ..
	"4fssV9VxxR+mUuSidfCJ0w7NEnazkZwn7Qxy6ZSOfaqTb9u8i8sGayqghf73p3FAMK8OpwqTAi4JXdgmhxccm0e27Ku5HShbAhp8" ..
	"t0Dxa0n/9Lq0nbqQA5DlrSZ92/tS63w/eJ5aGt35R4qH2SRlfYgM1KPTQ3YhzY1LOLnRRHDvwc2nezJNcMic4XNvlu+NfdIIVLAC" ..
	"zHxIBmSA3SSKakQ2gRi6N0Oe/PtQJoHZtBiZyEPTUQEoTFyHIiJfzIHsYRU4YcqWAVjYhpv4LgmKFdGk4dLo88wxLl8Tt8uyJvLy" ..
	"mGgQOQ3+xePduMKdgaQKfwAjMxWtMQJdS/zH6oKFX5EAr+qSksIUKQrwBJwPf6HY7mK6AOtCdG324TP56/wXZ//FYO8yIf+hw+8x" ..
	"E6EgkVIEwxI89kU4SmKsd7aFIMNHQ+aHxMPRlDEvMVTLI7NRhOIGD7Gsmxij0gcPQcnyQIfyc7zqVnU90/2nSFoGKgXXU/5+xvTg" ..
	"97fSTvQCdmMT6fMNIAyBU3ysuK66iSxWfsinagVA9j8xfa+jH+wh5hUMAsdOkCgroVXTixJ+UIzQnBwcJl8QpgFQf9bxUTqjhtDt" ..
	"v9hMMY8a4VO4Ts79eQNsMkymxHqfXj4qKv3AZs4cVlHd5qReEiLeB9RYRWI8wmtgjvqjVIQ5ZRYb/AYVmPe2FqkF+dYnARZuDP/V" ..
	"SnKFL8D9ds0+8fg3qiDlC0OPEIEzYhMfYS7XF42ZNgoOiJgB0KrmLgJiQuUgwNZPj65JoUUJvcjZFlevnKV+5ssS9vB5kFVFI5ji" ..
	"PKWr/FFmqmMaorGfUJ5lNSe65YRfTliOMp+CJovNooODc5/+afInLXfi69BJhLjRCRMDpGxIN5GIj1H7OpNY/IbdBH0896NhvgKz" ..
	"r6FkV50S40I7Uh/N5Rwp0o3UY5wIXF3tUpanPBrjFyrBPYu8Fa5yjoISYQR4qu30ndBKA+2Qy/p7doMX+1GhhBxJbH1fYsyu180h" ..
	"SDuh7eJvvhpNMVonEbjMelTFDZL5pl0N+76qcb/ujPsomrPJQGkAQVWp7ggz9UK2C9rW7jXIKoYDqcrZT5sy3g0hpy7eZGHiOsV7" ..
	"/hDqJKxlZzmu3uHoT1NntbI8+LcPk0V8AdPq3nJjD0ppDy7bQWTKyS2Px98CSPjk7JHHFKOHPk/N83JASnT+mXOlveqopDHh8/oe" ..
	"BJs/KEOVCu28rflWYwYmfYCiceKArNEqOUakRsuIgi3ARte7NoXhIDTeRMfxOGddbdFy7mrG8KeLyXQz7hllqkay9FBm0CTAqXLp" ..
	"l3JfsVUil0lONygh3YwIppC1hCjDcJOn6IYoHdIvInFqkMVeA5Dyf/6sb267ia01e93xkCqgRYjbVvfqXPHP25HPMgHiqf3Gz2K5" ..
	"BBgygj1itR7rbmf+Y/LTbP50HKxenso/zhIpfOke8nVwbkQ54KGYaj+o8sEm0ldzz7w966sb6pfQts317ghtIIOgkSYgqaFOrSPa" ..
	"wmx/MFRWjSlTFl58k4DePoFK8OXSplT1rAXlv5gJ+ezK0JVHfCcUrdmjpQ2XvEdo7rUuWUKuaAltkU7CarQB5Qzx/0wt+Hcwv/Jl" ..
	"dhz9e3R6KPHB1iJpFOajr1vwXZyQMiMLWvxCGI8sPw5rOpLbkFX3POKEjhsXEJtQQ6uRpjsNjD/b9CwNrpc2pldhpCW64boqo/mS" ..
	"oLrEhD8DFpAzdZfnP5HtQ0WnMUVetmvoQnQR4Bj0NExLYp5bTr2CBfXCnK7fmSXTVaG5AX1Wvc1yYTZgjN/++qZIWTmpQ0jzJffs" ..
	"6SROtZQVrmCV7plMaKHZ+ZhKmGWVMAHCsVv2xjMRILOuswtuda6lipCv+HYonG18FjhJ4Y8MAJLroOK66Y2rH/btUWgxicrzzV1v" ..
	"thadAIEwx+tN5MOVjYvBHCtdEh5X0IOF892GgAL5ZVmaR6AfFK02dc8/ialksYXiBZQxBZhN0ZxhgbCbO+zQHZ02+lrcAx+Tqkjd" ..
	"B9RDd2jnQmOffQ/seEBQPMSeomCVLbmtaiJ7bt7b8qPc6MjOrr5u8kSHwA0IwKy49y+RL5IUL10RUFNNJCjN5CDk2mo66UTD6SUe" ..
	"zmXUyz8jsXK1+ILKt/TfEPJU1K8pq1XrVf7wb7xljTTFycl5z38wHnhUfk2XlGghKoErUXivVZJ+aWhaIk7EJsgtbQ4ErPc1dA+9" ..
	"2T/ZM+oN0es3CGKOQvX/Ht52ktQxo1egehKorN7iKD5jthbvQszlwV8ElEUzw0wbaOP1RX10cp+UjLk8qPxOap9lMfomipgeLwmw" ..
	"YwjsuXmt2RUqkpiXflYA1xH+Vf9tfrGe0yyhJnfThw33R0s3o/Hr47KDuF5AHNM0a8Q3Doahm0AkOa5UVGlJhbaniIE0jEBa3jsF" ..
	"9sin2MwrkW4wObC2sxeOu/33OWtOmwHiP7TUhvPTybZQmFv+/H+ARPs89xh+98r/+XtXiv9w1X8cGiGTHlG/B4YjBzGb0+rIKqa1" ..
	"X0Mn5yVRxPTi7IxU+PGm5YVBbU5fhk2Oth8xRqP6a92VpwAOl+pJjqsbJQ7VU7YQqfFsqu5kJEqNr1KyTBFFNP1jga/3gNbt5g1Z" ..
	"Bt/wNz/ZL8Qp8WyJWUVfhJMB6TULUZWuszgK0gCjDdupXruIBqZ4qCLay0CWgEwDSVPk23PDdOoDS4KgLxbizfCsbRZnCPSIrXCs" ..
	"eJmmAVSe+0H5T8IxGbRBw1xBXe86p1rXV4fpvSSqqKkY0qNTTcS4iAg12Kuc8v/hmd0rj04ip9LveaJYWnZlIXQz1Vi3RProw8TG" ..
	"+v5L9Rl+jSOsAHnnikwEbOmbmotzE/K/6M493cQBX08S45WDRhXP/Kwod2Ss6EbgnQFZtnCUGCg/YASxF9laKFth2pPLoY3+iZt6" ..
	"pgN6nS6oiGKzbCM0ch26+oQXkoFK2Y50oqtlZp/v51TCFOvRcH7OAz9u26WlWzJeXxjb7gP9PHgK7VpqfwIAb5E/Hn/33C8F59KB" ..
	"siQphKviwHx1YJl4HWA6wGbCtoDzMkKD702ZgeJsbZp1KZCc4tVoxp/AR7ZzSOc8swztnUZ/UvMsE2/QWaCuuFMqVR8bqzSel3dP" ..
	"aPZ8PAcq9UULZRsN3eNEcCkq43AGjO+BZDCumHFw1QD4NbKUp8Y+g2y7CpDkbxkYHsDINGrYLCn7UgR0dYBgnPmEA7c83B4c4gls" ..
	"XhYLHWN9TFL6HS2ovDMEpJhlyT2NojG0aSelsIQ9cU8Z8CjHUXtTnwS5nW7aEXOsQ/NV6sYmV9Zc9R3eVl2ZxjOjZxhqCTTlQ8Fo" ..
	"1OaUGoQJj/ot8GtTX9VkjH5tp5vPhNbceLkZijT8gRUeTEEcRK+4AKu2/1bylOBsW881a4FmiSFLXyrDuNSybCFn/qndwwGRs/38" ..
	"srIrzR4DBHWeEnSf5nHgqt4ulp1j4Fp6pUA1o8gvJBkiDJjpe26+w0jVhHlVDHbDh9B/0+7XGNnDmJX6bLbgLMbB15oGQdTzL2AV" ..
	"m+gSdkni2cFY0iEyPYRSMy1D9xIlMG/cb130UVk1Zq01y0cUar9hCWRqrjRQ2tZi67ECqkbPPgSylQRiFlzJF4RQI6hU5rOYOZyC" ..
	"oT5UmvGm2lW3E0ZtMq/rPYGOmHgbUdTErkxk+ESVFnWzGxOguJa060Nt+uxCP+VxUHpY4PfHxl/HtoFVg170I/bGUojxV6k0kyW7" ..
	"NHa5Skx3YaBN+ogoScsan1J4sVGpne1SHwqKuFXGtQsoRltbbSrY+ST136L6UeR9ZoIfllwS45PWo0R+eLRmDXK2CilCqamGb+OE" ..
	""
local PAYLOAD_P3 =
	"dIPb91QGzAR++x2FRI4hET69+ybk8MScPSzlGpOLJbkVhJAU86Xm034Xur1iBJ28JzZRoqaIMi7aAnabqsdGlRbB092qanCSRLKl" ..
	"u8V3PU36O3AFEuS7ieUMIKXDp0xpeiJH2AgQ6La3GUuOQsgQQenNpwz4TPOmqSZS3dKb+39+/YGb1U85Q4fLoJ8wxZjuF5Hwbqgr" ..
	"794jPKI4novk78cQltihYGNLDVZ4Awt49qOK4oX2k04KIDN5jaclR4Ki3knZGB36YODa2DWJ7VZrO7UBbZipnVmR0w8iqSCgItT7" ..
	"kidPHKEYPM8nECMieKIDPE+76pZ4hNst9ZjyUfFZyoySzmfsebFne9OMRazlY6ZZnjh6OLKzuQYzK1K0hJDIFob6bAQ3vjqpP5a3" ..
	"EpIiLPPdGcp94CcdcHqkUerLp05/3ckqeYyv2MwaU3bhP1Ofw5YyOsG0BLLLXUggYQs20sc7kGa2EMYgq8ShXxuFgRdyyCwp00/P" ..
	"epFw7e7UltvkvzCmw09kNgQO1CklpvaThL+ArztIe4jkmF1TWzPJS6HzYqtToPcxVJdH7w4fir6ZjyhlR76lWTh5gFaOY8wBFr4f" ..
	"JI7xt2pycANVNPs+MfL+FNjTDDK0xidWduqhNH1EXoYE3Y4wOlJUuV/EZ7RTZtekzx1uVpveSz4wRd3A4XTWY7wjtu+Qap15IAd6" ..
	"CY7RIobVSOFui1d0hwCoOmb/QPAIvjQEi8mjIQ+z+VDeS0flhF3Op/KWtiEtuyjqCTh7Dd+V32Odv6kBPm8Da/Whhie+w2tSheju" ..
	"Su4V5P8KMs6/ibF1RVVbv6DYP7FixJnJ5/uXd+QDjufFSKXiRR4dEpGeQYroTKiclM+XJk5deRv3EiOUoIpTwc80Lcmb1Qslq8B+" ..
	"0FATD/HkIv4FJMT2G1f80LLgbzYLKtuRwNdAR8fTpinOHCtvGPjoShMYUzbQDQLsgLBcjOAJPMnClSMeG7MwRYuGU2ydDM3kJBHa" ..
	"1rXAHv9y3Q+QsnSomyMKS7xKBn0sxwyivzveAbJd6x6dQOAj3lVH07iJs/zGSBkoVucE3rHrq+XlWz9hraoGVShY8lPJPdvtJ9ed" ..
	"uPdMofGZokE0DijdxNVlwIliOlP/jqR8CsUMsE5lJ4mzR5Hnj/WLW/Q9M+qaUaEvee0ZfwwzBgzemQIs/BGaqaapqwDpXJthBCqI" ..
	"et79+OufLoLThWF/nftXOxDIUcpZ332Of942eagyTcXA3unsdFcgOhpVPpC6zKWn1AHcxGtSvkQO9NlFi5JmG+FI9VHeXiRJCbSn" ..
	"euQNgp7xApLCdY/Yt+iDEYEwSyYShZ197LkLzQ2kS3R4VJOwhh7TRAHdG5spflYwVj+LKKhqXWJ4o/bSO5QMBgd9wQSlDpTnOse/" ..
	"4yoxpjxv7Qxi+2uKydoc0stCih7y4lPiTJd96GJYPuQwJRyCXfuoNFPLOzW2mQf4hID0j6GfpsRYSNd3q8+3dnXQ3ehIfc5ZYlSV" ..
	"IoDHrbklFwH8LdWNrnSHKSdaMunEhkGp6OPibAQ37NpxlNA7qjzJMeQ5C2py019sS1dkr4OczaK0sNH6Xdxl20ef6OMsyhLonOhM" ..
	"yGO4ql/XaiCY7COYXy4vyjkmww1beHG8Kaj9RuHhkuYUfStX7/USk1JMiaaJyVYzguNut2MYaLcU+GddECxANT6jp6E8vOKJGtzq" ..
	"3wDrp3SXvFcw9C7JDODrqsU9EfYIsjh9bourmEiWJIoIAuEmkhZgwVhhNczbZvMAmVa8e57gRS3j8D6KzyILoX793eqdRCCUXV8H" ..
	"jguNSwVGzlpMf8q2dLRgevMBH+wMHjHPQUdN+3qr8PO3nbPZUap7chBBvwL2CIkJpY/3uxdYs01UIVEKG/9MoEUuKqud7giZk3nS" ..
	"mOxvpacbbB+qEfkeiHRtumF/1b+LZydN58nuE2Vh9+PRpNE9NgnqTeqsG8sFmAusdBRZaiCWBsmaQDkTTfUUUlyItzWMBhjA86t3" ..
	"aOWWD7e2qGzYxO0CrkemG1ublA9nOh7IwiKuUb+IVFNscwpxHB9h1sGBiZ0V6Zlyon60sTMqc9qfWLezT1yZ61K3zIi4xZ8XB6BY" ..
	"Nuuk0PamFu/ZqZWPfVaOobWCxNKeA9E0qtiHSGUXcqXHu+Zzn+C4X92DNmbWc6d0sW5yNcJfr/C/L1EsYBaAddwCViNiol1VRSXz" ..
	"zJujFuWb5mwiojUnxebz4ft3dtEJq54+WCWlNvPDyKPqXjewMlMFHQZrG64jDSWg6vjtp/wCxlZiKfrD6+XDBTMSgBTn4xzlH60w" ..
	"hbALQMoI3cNBzby/z9544+xFD9tDHRqanli2d1irZPrUX2xiDLQt3Lx+O/PUaSE+vt5/O5JBzc4pi7kLKtVoNKFgi/nEuIz84eac" ..
	"q3qoGfbdogy1bdQ+mVjcHFp1jN5XxVpb7PTovdzylxB0TE5H2jqTdPi4e/jtJo7A/o2fZvaU/SxJqfnue3ppGjVFCQ6FeCZmR9D/" ..
	"t4xTJGfnyD3qZoOIhacO/N9wSOcI/dHAALb0IiNO2x+vXFCe2O6B/TCDtrq3k8HXm7Z1P3t/eSQ4YvlDcu0weh7pXLsayo+W2Y1p" ..
	"Mt6Mr3C5vx2iCS8d+oNSNPEeZf23pLJq5SOxjZiAaYeHJaZRmOFQrRWxojzuAnocqCWIvHNTLSX+VjZqUc35CP1Rgkq5A4UQqIkP" ..
	"6bsj22Q5PIm9wJVT9gPAenG0JbGkUlX6MyZPZtmEtpYbpqc9ry7Cbl7VcQKDBCfpukTyGtcaVcj3658gBjF2Ad+QZi7+81xZ+Umb" ..
	"QNcVbeGp2XKCC+1AGhhNp26tIDP04EGP1V7uR2drr6j6ornc7c7hxRWZORAms5GI6Qo/D2iBqqns18HoOY9BxRRbhSyV6FDazfAC" ..
	"afXvkwrfZ5YXz339OJpCKrqq4xIPYL2vF5baPpBAcZej/z9PtR/rhj6qBtHtIoL/GIgTTCYholBtU5xpjlSx9GhmgWhzBEYTl+G3" ..
	"PmHKeqc4cBaNEW4Tm3WwnxzkhlgZmOM7DY1QOxg3aseeY6Wcie88gZ9NRWagFKZLprJwd9HEcTReu74C2+6X7/MpVMfDpfdB9UgR" ..
	"l+FSl3aKc9BCuAsLsFQ79Vu8VZPS853Iod1G/Ov4ojjyql68Y6EjmpE0mNS0h8JLHcPf7yuonX0pZK914Lfe4Vu1GyMMHd1Qy9hD" ..
	"pLkobex1aagbUGBdxxeH5/fKlHDlnTGTZEch4MeKGhxDZP9r2DHhdSMSyJDLG7HCkPXJYAKViYP8mWKXHIBIOiJW3tNkMWJm/jg6" ..
	"dbXMizCWG0d40G0L9WLn1PEH6TGTcQW8bIYJelM7wCPOqpPiSEk2yQyOqMt+Q/jJ6KnzYjn17/MhzJc2w/wv3FQvcUYKZ5XGai0I" ..
	"EXNW8Oot6AgYf1LDLr2JJBtw4ABIyK9PxokXEhSdv9Ye5cOx7uFR8zUQwpRAXm4E8ZaWBcha2zofDCFpeQRTIIX0BPYHPofdAIs3" ..
	"MdXCMOYKYjPD8HPOTx/GSMRrAriHEiK7oiZ2FoudSJU0IqRjHHTNzOSSMr1zB6SGiTGgH+lzc2PxXfRvvQyZCq4FH846mlWORTHs" ..
	"laOdgZkL33sHahUOOgjPzbQTYkuv1uVS9u91uWTszsRY9ixvq5BH3BPyAwvG2CC2RihsI3Rjrtho0ZDKiXid1EhqnGGh274/Vsf7" ..
	"kt/ZEy3DkQwIhGge8rrus7BOrXs2LqIPNEmkTB5WPAgA4EGOtBNI2guG15VI2x5E17WwEKi24J/ixn/6RKwjfNjdiYNB3AN8UZtn" ..
	"GyWDDOSQDNN+AXiF8RLI9iSB5SZnN/N70KqmaWRn0VIgeECup7/apsLY1q4NdjbeJgHCHI9PUGK+4H1XdiQPrIXnvEheTOjotJMp" ..
	"VYkfDIGnTLkDa53Spa44qDSx4MAq0wcdt53vyrsjORyDrRHOZRqjBKwBZmTtRBFXj9Kadii4FWwjhdtG81cfctQdd96nCav+kuPU" ..
	"kp1ZgEgpGwddLWzIjnzzEIdtmqBiXp8c+uig/jjO/7R/7WGS8YzOHgx6bB4HSegPyABkK6ODM/xEyOGJi96vskMgLHxNar9MghzK" ..
	"/CwZMY0KI0df3z/OR1zXIIIlIU2UsgYePZgXwKs5AnPu2iLaiTETsW7YU8QDe06szvEPsU4fwhP7batdonOp4fxfs1GdOIa0ZTIL" ..
	"NrRfBK9MiqSDxREiSLaD1Fe4dCgjOOjbduitKMqhhAgX5XvG/74I/PRJa3bSiJoRwPB21pAAQr//GyKzN3dH0B096x7k51HSm/DF" ..
	"IoKM2jYf4HSAGOq2hWT6mGezAcubkPaMTfynkKaVrqJm1R++tMtQR4ShcgTDx+dBeS4cB8fT/vjhHzsmDYv00JAugfYTFEcHHJxr" ..
	"LnGLSR6ryvOhJIGXLRexGoBk4CUDA7wXQB/GmwDQDPjww/18hfW/2kBKvsKIdTDRspNgFCCcvboBALr9kfgQMeXU/bmAzbrR0nLU" ..
	"LaQBt0TnumUyZmecPo4LHMj1/K2gbeOEuBpnXBql4B+ZJ6KoDbUgOWCE+klicFAkekfHx3FwNjRdOrR44bvnrQiWWKS1vopt6008" ..
	"0yfq+v4pJAWrKrYhk7DG9qtLNpNDgh/BE5QmSydXF9nfjUQt1inXcUAp47mio+21kfhF25JMb2UU6GVl/56C/9gMgNv69qowz2MN" ..
	"4NCMC7ZIXtgKq5FTv/PomXxf220ibypSiN6o2Ya0LvPir4FlJgIgij4zil8e67h3Iykq4GDkRsv8wkXZ4G/IfFPZXdC1mcz27LCH" ..
	"2UYazx1SiynBKjEbtmYtsFg/xuaqoE6XUT89rQhKqYP+7vliTKf/LovmYWc+4xM2omcSLD5ZLjXjyrs9vEOYu4t4Kv4HKrMUSoEo" ..
	"GNOLz0lMe0tBDDW1VbRhAoM3m0zeWCKUxeQN0epB3yhVkqwq83N48D4rqrqN4oZdJQpfIOq7yjWZ1+DDamdMFjmv692v1vcUWQvr" ..
	"jAb9uOlNc9XBZ2hpbyVsZ5i5atTAj0o0AnwSgRnK+sEWtYViaH0n4j0Cmoa3g9IJU5motkxmnH+NabNTIOfinmCfLCFS5q9kxo/G" ..
	"1/NkGbUmFS933bntfpBuxr8OqcBn4yKoWnYHDd6EmaFJ4Kw207LZa+WByM1ki1n/6RPqbArDAGeJMfvedlMjBuNU7Q8kDCEOhjoB" ..
	"zeg7aMltiQNK9pwOMqd8IMcTA/aQ3oQu0SeqKvH1ZnQBrILjp/Xw3DmTa0EsKgPQrSzWPuFzS2WxFVSxiRqTWpct5M6krpq3bPay" ..
	"PnDEos1ZfMg83ys+x+m/frS3sGCpyrrobDKOJyuDu3LmQf5GV10J6UikrY3x8l+1ofl2h76s8YDhOc5AQ+B2GzO5+ga//nz1cNC8" ..
	"FsgOU8HSNFEnCyaZBJ1w/tAhXRH68zEuKEmuGReMhpy90s1KIw0kQqjFGz7aQlM8BC2RekRn4NnrwPqa7bX4s/vQZsESFnZ+LMD2" ..
	"2/yBCSG4Vtm8dH/y7wc+FmpWiJAt+FwyYE9oqOf/7Qi0tW9E/SV/H2RDiUvag7okVWbV4eYp8txZvE6UtyY3vni94BSrOGjk+uOh" ..
	"Jpbg2krcdRvO3QmZsvz3x2mb+Rea8flKgKiXvY8t5xri21QQ4mboxs3dMf3Kvq1QkG0tmvKILyKTlU9CoRVakrPAzRHsHGL1m5i0" ..
	"TRMS3JSd1pLA5uW9+s/jK2NbXJBjIYR/WBAiHx/Fkg95JYCpkk53E6tAI6G96ThrlCXefRtp9xvFqcuNny7ARKLHmvc6fbrio9Z0" ..
	"P0+eQaD2XXsnQQK8EjpizaWTMLZQDvlGC10uRiE+eSShSQM/0C6EQVKFdNWf57/P+RSk0D3nQbesP9PuhqbULNMRiv55jIBvfGNm" ..
	"Qwf7XlgGybrCg/Jgg1oxrOw8IUY9FKtR2ZF1X5kNjIJODuY2fR53NsaxRc11oRxJKlfjuBA9iq9qcEjSa7DlgCuMTGe/9dUtsX11" ..
	""
local PAYLOAD_P4 =
	"EeA55/5/NKdNGOr1L1p7rJ6vEtOMtZjTNHg4F36aO2vNzC1KDqEcyekg2OyUjYsLH1d1u0PsIRxxj2GoLi1fRqZU8sUKp3sR6yDB" ..
	"qWKiqwqdIlpTUWIovOx/P145p3abb+zBz5d38R+UFCM/jkCAUUqpjGumMA7WW+CzBvrrE27vYm+a/hS0BFSoLb+ziMYnyzrrQKfE" ..
	"3x06ccb1SRbK7zUYlOs/PL3QAmYl4nFgaNrIokr0xBpO/cZli54uhFf4DPCu8KjJhOdlK/40Lr5OClUEmbEiLTjuLek2MVpLn/Td" ..
	"ufuVqFz++D+7oiLLr2U+vZnbem4c/Q6zbfOZsCMDOiCH9A8ArYcq4Oiv617pO+WdBGpyYxfFCX7JGDtMgN148rMLL3O/dGh/5feq" ..
	"ni38+DWSkPm4L3RTHB3i8jHhVDhnbuBal2kSyz5IMytBhE/PMzluTKUQcO1r9yUIYmNqzIVp2hm29zlDn0+CPleiuA+a6fSzKxdU" ..
	"0WvvqCQqcGLUZ/+avtIZjUcBhp7A3+Fk75oEx0RK4/ZvcqjIHc6NXHS6RzGhVZaqQy3JD0Ht/NuisbihHR2upnwVjUPoEpotq5+K" ..
	"k/1XyfXh4RAmW3rRXtJEnuz6+Uh6W7Eb5fjnyg2GdV0w5GFw/wQ8zjGv2Xx1MSd966dEibUhzrPn+z9DjoCgUmzbeA6RFSMzWV47" ..
	"fOqmqNhyhqjhNFS678xhCQinUGSGubEIf43eAnyR6Rsryf4w8qNsdVeqlshUqS9gpa396RerPoFg6Chx45mXNtQPwtRUxPiWtxes" ..
	"6r5+EmpMjRQosaoP9mbU+B0JNlwfvDThNhA7h2CRD29GPVA4+hs7VSGp/9gQhokCpToloEDrbvkMWlakuBMSKAZJ6fAMddrTV0OL" ..
	"Mj2A/eyaIWXTECjf8gPXAUW8/9YBB2Gq3hOGXVF4vqIZIGgQvpIXKvSrd8HztdimR2F4X2oBQHEmLhlFnwWQ7byWNC90lBZRqUnX" ..
	"8eMB5HhqoOFBApJiOOZDk35K7QNH/wp6nhnbKtiEdKmDa8NW6SP3etoa2u1mt7HxrgmQ08K2XVicg6F1T9liH1X43HVG2d9Rt5wO" ..
	"s9tItWnkLMTqImdGwno/NMSb6kJLphYOMKSUKKg+YdBa7HivzOEwRd2tTvBBjDJX3DXcbfiq5yp6nAibq15v/n0CSSpLj36U0gC0" ..
	"q2+6kob4ES67TMQ1Fygd0VZIX8y0OyPb+XLj9c+6of8uL59ymkN0OTElYgf8IC5daLKLCE2/j7fcsg+a8AaN9876n6SXT0t7YAwq" ..
	"Bi9QgEg61ZXlcNdzGLxZxwBLZ92pFBd5h4AGv/PNNUo0vdfPv0FVP8H0gWyaTHqohKXU+wwn4ozshrJdXJfku47ntHp4Olve+0Q7" ..
	"2B/dKtT+TZY7lc/3hXudTAHb1j495FZgnBzw8OJh51dgUDgbxvjfF9arzZhnrhpY/qE3wL5p0xLLd8Ze/w9ryNr00Nl1/EhAi2k/" ..
	"41IlsNTWr5w3RXYKN7/Fm2Q3nFfB3QihQLRQbkdqguHAk6XpCLU3DrFcgN1xTFT79mKJn7a9yyU+cZtcNbbZtH2NOOahBFc9XoEK" ..
	"QKGU1LKJV131nJRYu+wVlyxHZI0qUAT0iwAktvDOKnPVWTj0SW3pCPSib9AM/8idq3rVKMeILomyTistKA0WNmPPbqGy8V3KZAvX" ..
	"UZU/gVcC8g89npBNQ9QVGOOcIvmpLX/OYmlMEU+IgqVXOoyaur+BOXzQqvkPr1RR4Js4S2vBWpi9pMcxkc37WXTxQTCJGM8T9q6O" ..
	"CBjVlp3P9S132u0j3BAL8hvwjJ51h6th8gYreOrjhbrZYZ1VB+W3sWSnYXqfHRHc1nbyPZ83G6qHeq385YSDw0UdM48VlHVrezzl" ..
	"wOzfRzpwPJ3poOaoH5hOoALaDBaEh8Fwzpv/LKwcC+IlsPB0YDksYRqj94NbNOS88Rx4flDlJMLNHux5oCwT0gWCuTlDxYn0YGv7" ..
	"UlccJ6HfaKcI81f5MYIUBTFyclivA1hxPypAGxDz/0oxBWdyN8m4Gq3DcgxrVwUgIwFui3F+4+LqoXG77TBNx5oQXRmHF6aRPM8g" ..
	"dLB3Mvoy2FgJh+5YvNkJD8raU7ODlhU4p1aZKfh7vc4wa+Q9X1xz4RxlgLRR68M0IYpk0b/bkctCWhzJp/U0AAy8+9Elf2RRujps" ..
	"OVJ40EMrkTQuJYPFDD1mm7yV9KFuONhiCAx/oKeL3Sg4zP4kf9yRbb97IQR3Me7kbb7W6ynfdI2lOuCv9JgAaW/lylPRXwetzLka" ..
	"lZotgFPa1Jv0VvTyaO7K6GW8T1sius5kC7fn/JPL6nOJ2E/ZXgV2BQfX1A7/3gDM8yxnyGMjGLkwesw7k7M/AcxrxX9F9dfGkmAB" ..
	"SI6E/JrumHbQ2dp7ZTytAZearaa3DX2T/t53jO6zGl5v1VoQycgssE7JUm27syl/gSonE9lV14ViD6r6b+G8BiHTb8400JxxpRV6" ..
	"fFKYj2hZrYIn056rwh6CtyR5a0bPRfFw8n37Ibf881WA2F8HqQgV85DuQ3znkmWBDseD90kDADIwg+wMJ+corEZCSshbftsT5839" ..
	"RiH16aHCyfwgMMcs8hpJ0QgTArOht7zJXuXIiDXMdyK9g28qt7evXzaavv+Ngaxi70odZCYaNO2gDeOYTERBGyr/7g/yWCnLGbEo" ..
	"LnsjclBZcdd/OA6bdGkpDU7ftZbRcAok+OinEZCgv1YgS3cMbyRhy6MOJQAay6qoTgrl5IXz+wtY2Nr5YEZWUiWSk0h3OAHsOSak" ..
	"z/UKTw91Tm6uMCkfv5ADuVm0XIGlhjk5jSy1Z1DsqREWxuC0RlFXKCylXqIkoMtXTynF7nwQEpIDNSE9TuAeGRjlUBBqCKXY0xA2" ..
	"W8fTTlMOnRXSXx2Neog4//uIqftF0nBaL5t8dlP1bX/xEHN7WBUKXcLbLusfA9+TFG+pC78Pjug1jzM4uWDtuHyI8NyatbvFE7Y2" ..
	"L+lm9HKmswwZlb1z6cKKU0e5EzGJY5WpEHnyHN+A7GjlInClSQ6Z5yECRNgMBr9veYuHmk7U9KN9xcYSCjDDKkL00ieMp2J6/63z" ..
	"swOopx0KGptWMV2QH93QATCdXJz8+zYsMr1QfMTVklVOGEFIEu7YltvQn5K4HxPn/vr1qZzhwQS4MeTv3whIo0aOFVVdxwcSRPKu" ..
	"Ga1fKDbec7w4bQ5CArb6qgVEoboAYS6sMms+eS/rTCxdgXlsLEIaOIEIYLz/lHHKr5lIo2HbWq4OB8HFwWJy8H2xpRI7CTozSIS1" ..
	"h2Sk0UdN7VwuizOlO6ldsgnF0zyXaTOh5RAj58lV6/bi767MAT4TP3cK3pt2BnyQuhYKuZgxL2C0Y2+9KQJZPgxytrfAcVzdv7Pz" ..
	"ZPjJvs5yjsKWDb+rZhSR5SMzClAKo41Wn072jncxYb9qGpQEh5ZXa8FPBJ0GDZ7w/u89ellmSO0niuLqtIkyWYVoai3PGoK+zjm3" ..
	"wW+nyXndCewWgQgghdyBDws3LsRNkZOPVYRfsdJOZsOKfOc+bE2fszoBljiKWgmZHsoeHYCslJIgHoUx/GEThE8qQzgCIOHknyjw" ..
	"kXKSBnthunxV6eK24axqLzb24byRUOn1GTjXgB5d1l2myaitLhBRQYsAERWjCyaMkF2lSYUZW1ftxXq+yYnXdCakS/S0kFSficy1" ..
	"kB9rt8HRqB6m8TYnP/wFa2V//K+KPOhPpi8H3rl6r7cJclcBN/g/1UxWKWVC0MBMPEzIIcDShPV6ShbOXyEcUlGAWIil+ynTdO/0" ..
	"s0dTqhWnAfoW4f+alatSet+V6Euzsn9uFtGA49xs7qBGf9yPyIJ1X7kGg3PrLqXBNq3OUzmsE2q2jSFE33wDMJMEIGVLbexKnmpf" ..
	"dhJzrlrqmTzb6gl74GnI5N/WzRUQTbIB1YUTpkBMTRp+mxmFtu/mmJ4fFuMOhomIqku46XFKuo/PXQdM6KzN7Q30o9XYHu1JQW9v" ..
	"Yu8ve9WW5biXI2XHiUY55QwamXSlHYz/WK9ls12vyIR5VCkhTAiObOqk96HXWW/1pk5paBtjk7/LsicoNDcyiQhI34S/fzyoYcCA" ..
	"Y8bWFtJPZKVGANDFAasrKdqO0LUR6VTRLmuMeHp86/hYusK3TFQGj6geYjKtRCZ8NKOMa1zxpfbCjwqMFkID9SfDvO9fCAbbmJdT" ..
	"SA92Jr2n6/x71jdtPIG4D/m5bk79j6Q9ApacVH922FPxHF0fXpf4nl2pbKjwOquQalNWEWJ/FniZC4M89s4LF/iD2auy8TrPVBGE" ..
	"2UW2XDk5ugp7+SBeUhhUu7I1GeEVkMSOnSVBdRnoFfC8RvksFPbUHWYvxUVcOFAKWzCJ2a0/QWX5vI/aMX7l/8sl3rnTBksKv7zz" ..
	"UuDeXGljWKhJ6uz7KHpRX4yzmnZ++1aHepfCHULZP5vIUoMkkoUhB2SfK6LvTqzsOFGchaWk2/fHXZLb/kWAC0lpzxqahAN+cef0" ..
	"nojeRFzOnc22kQTBT02/LT9ingv6KEJimtBw/uf6mXy19og5QcZaSdg35jG56V4agtxmJl0iDnVIJWxw2frTyODzvWwPst6jM3MS" ..
	"l2xzzLQ49xogof1OInrDvpSBifbrxl1pxAhv2y9Wqgue0R31uUuOcTvs/jAng3g6KTr5Gk8iMxF5KwM69rouoZ+dOx5DhVs4Qsmw" ..
	"b+hndhDgxVKYgzjuwNDGwKuqGjpJ4XwC+0px3sf3G6M5MOCptHANEAYgduqziy63tYNr7qA1UJB5puM82abQRF8L0I2cVhv3Kzc+" ..
	"CiXVHURxMLkfXFm5N9h0rza+7IJqweMIKLTjeTt8IRffV088MbNOAlXRep1ucaPzij2Yz9ADS29vp0c1iuA4RNnmYe7CI7aOOdzg" ..
	"CAdm7GC8Z7H3An6y+7pgfAFxN+wRC8lgXs6Q31/fsqGkrgblNjM9Vx1PKexTBJnBJH4Mws3JyKqSF3ZO74f4YF1/ajGl36cAqGGr" ..
	"pMURqSJkHm9gvn6iNGWrYQfstONE+7sJ5Q5bap0yuNOal7CkudVKPw6ngBFPG7gqAqr2fiBVqXmqVDeSFnlB3N8JyAOrDWqoG3FQ" ..
	"wg3uU3ARtWGNYufKNRK+q6tjbPYTbUks4wSLYsLh/TXiFfnrxNkLCcMR429Gwm1iTQugIX348rd2b+PI5f5iLMI1w5/7IixF/E0u" ..
	"bQQXGHFjAv975o5uV1ZQEmUP/A3/SocBBpf5fPpVGifkv0lrITXhvlBn+o1pZhhYldrk2xzO7HGTYfzixbSoaQt7WptJ6sUWErFZ" ..
	"UD/y/ZSSnmt7ZTNZRo5QZxaGhojc9iFQbhX+er3RVQqz5pDllyIOw+GbMbbLofhkjawVeucrlL9OuWyFcgC0uFvPo3VxDFw3pBNu" ..
	"j7mysk7m5naZvkG+LnpvZtmkZHcm1dVfHVq6/8S7KkXPyB2DnR//C7p0Fbgu8PYQHlBc+CSJQtuOm2GLbH309hSFmtV1REmsjFpu" ..
	"6JKLNKWs0O/A90A7s4WC9auDtqZaaZ6srD4llxug+ngdqNo5Vd/SxR6wwIputOz32bbBt9BNN2STFqex+hMVFDYX3qolr4Oq/4X8" ..
	"pVLxYcP8U78+FADitLgiPPJSPFFHfGbo+Nu3gRUKH2WmkMn+XlOZfmXOPpcamQobGqSxvJ/8FPqUPmfIeAISdH24ip3BqzcFkcPj" ..
	"zFzHyBHQZ80hRbwaTGgxS0iGtgJ/WPrgU7CFxzdEVxGfTgCEhId4xlB4sAZDyJ6zpaC8BhiCzy/FmBabpyePNT+UMkIg3JTZbhug" ..
	"N9Bqm65y7p1qog3ySrmrnQt4DVDsVMuvZrqRl7nLOQOZoUbFpaP86g2zD8LvKEc1BZ0l9Hh5+04VKSjTak2KsM1rANuYd/qoyN8o" ..
	"nsEp42GwHxun9wWKFDENk3a5dyp7f45T4cVbO6KH6boSviyQmYb8Bjl+V4d8zv2nYjcxfg0DIQsWsNWLSHRCXekLwtfkvoMTc89H" ..
	""
local PAYLOAD_P5 =
	"RaAjLd5kcMykKumdG1FwaR2Dg82F0bWJOu5Vq0KPS1Xg8NCPtyNgtlpGXWFmso0byCkomtcd7N+5vSaEYGhwmdQat79Cnoaw8eFS" ..
	"OkUz3j4Njd9FdpTrTo2u8BaxYUDk5zDOoFZ4DEYDRMnvt/kWKQm1K/jPhNcS1a4RiHklEunB5f+nr1VCd2tvcXYQT27O8lZU/JxU" ..
	"iqt7++KLu7l3Fyt5F3SAQDgssiUR2thpbf18vhjeWvTkxwpuuSg/tMGrcXb6/96mpbRU1XYxPuC3vrmTtksV23Sv6PFjc5ZECZ2H" ..
	"3b+b0f1smbFHnMmQUHVWPk0oCcUhNPE2LPJaybTQQxEGmUbzkQ2Fz6gqSEWUjRcWsdBEcPBRolj87V8PYlckurWFpRH5R6ULK4VH" ..
	"01BL8LLMN6/5e8LpIaS7/mPVQ4jXab9L0ayACqHG/YFfGCyN/OSqlk9JL4snYxg4xLZP/qna31L0FJQFhW5WOIUUumGZ8bilKewh" ..
	"G9jySor68TvOuPs3rn0mfR7yzgF+B2GmMs5oOMJxlmd20QnfksUqQ8ujZgILtQlISJn2NXTHwwsenG5zP8bJ+GklXUwj90py1FsH" ..
	"9vVzApeb8Sfg876IuPu3LYWpbESz71m4ikwRLbGWyrfA0Jr8N1V+uBdL/HDT6CQeA1egVKTqSJv5fA9CNEvzejJ8HrZgm6wU2Qud" ..
	"ODhXwkClW/jRlRLBpwido4IlplfZjwc51B80eNIj2/MRJ7mzx/e+15pE8I2ceyP07QXLx7wES1Dg6Y6Pu8Vr/PiKG7sIjXLtRcXG" ..
	"dSFMm1IxkhxqmtIb69zfg9TXd0H/QaoB6PajzdT9Cydux3zwgTdXOiMwJPLpuHqV1onzOfTAfab4Sa34b+qTtgdszoAfv91WHrtn" ..
	"OCUnm7TCT50B9/PvsRPOpOtnHIwhn2MN8ZGRaRk30y27Ez3IdaAgVMWKAf6WlPpfllBlZfrBMUpkaIKT9JcMM4TZ1tZbgaYtRtI9" ..
	"KZ1eAAmZYnnvGcqmCTIm//0t7difqovasYoS6cIl9m6cvFFBAGHM9Ur6LQBf9aJwtZ2gM1Q+EXKaZW4T+No/7F0WEVP1dgfFCcax" ..
	"QpZo91zw1E1lBTw2Hk1HzAJ315W2imlWFEcMb8BEX21muli6Xhf4TEGeCGF1Qju+e4wgA6nOQzMBASOUYA0YcjMBgP/d7kSEMXmf" ..
	"/wjHRdf5VN3mn9fqCKoTWAbH1eUVGgi6Bmg9QZmnQqO6WEB4X33Hj+P67l5U1NQmoOhlpqTeAZGCHKrQAqL9OlYLjkEcWYaqmv+H" ..
	"i/vM9sni4SmwBiazccRuDVMPIyosLiik39uxLaxsyRQH7QuD6kyVsJ7DXviSdizdxOcauSrnMmA80YJD5ZspKi8EUfg8YRhaZM/n" ..
	"LD1QvEaL0tqZWVbdmxG2HA2rPTaD8+PLEjj1ZA8UVHm2GpLy5+NuCgETbK8yrTP+gCsewMWgWAhv/UEFSB/ympLzfZiBnl4prhuu" ..
	"d6Fw4ulS1IhaJGLe0mg9MVS5DRQisMMKesEos0sTAizhNjL/UN2LpyCJZid+0EbBOMlxGa5HEw1Ir5lbEFEwbyH8V2ptRsB234TL" ..
	"bjN0MkUnpDBIqWapUEyk2PgFLLn4c0ogTbg4+UsNKYlXbBAcYsyn4s+4gXpgxfGlacVGVC0vWe7L0uBpFlIxG/rLgBjXGiKVYPvo" ..
	"OOlmjFRRMOXmcTJOllA91gH5u7zK8pa4Ar4BtouGmxNYJ+w6McG6PXvuQw4VY4eH7oRaF0n6SZ3mh56B7EA7LCafrKpbfGSRnpnt" ..
	"Dhtdc2eFhctmb8OPX6CgG+POZV9sLb11iHjzMwVFnAX4KH77cwqieC38doubT8xsH5dyzwdb3+1zmvP5yS0SlgE9v0MW+x6iW7fz" ..
	"Zmh25NqOVs9Myznob8E7X1aUGixMhOhpix3PruXJoTTe8wYMkoRXBkiQ48Lmmk2gsp9AU31N+NE3QPefVTq1VCDAh/L87/i6nCEa" ..
	"UJAvLyxCTe/dgfW2xvBgZmdkGCuxhpWKWtgaGQHhuY/GbC94RZyMsLR7jYEmj8UNvuhrtip78AI6ffsfqA0EbfXPexNEcFU1OBkC" ..
	"ra9IZV6bsV3dlnbbkOskTv4SAgxYfu2+EAEJmQ5AvwC78ZIak0MeSwts6rDYmSaLfzN2vIQbSuU28cmc48cG+Ryx0OwlatrpJHqa" ..
	"pg/6dernbZf8o/mBmmDjyXu7nTBWK1QxZA6fwGNCdg1BV1BD/wM1iO/QE7lRiZVMwPIggFDhxa1RnDIH80sfIpiZe6XzKK3clrNE" ..
	"sd53ILQHZ2Ra+bjGzyKXv6TyuXUNMXEmzutE7/xpnyglya2tkUmDrsKMytS65Ou15OI3IG7uhVZNrTse7hEQs0yB+19DO9TbPubb" ..
	"pzxHsSB5GcBdf+6yez+/0hGHEV+x5QMeV7zKGSawHQ0MvAtijsmcRMqyhUUp8U6dFtAoJZlBgmbfAtt3iEZu29mjUv6RhZfOju4u" ..
	"M3oGFyQ+VCr/Ex4on7+Hh9BHNasYMdmQdapiLYP/J8+6P4GH4ZZN4/p5EpUg91ktWqejUhg1FWibjq0CfvrZedE9XxGcnc6zvNQU" ..
	"2b7dW9gUNepp31c9ZgFGPKoAHeakc0T0Beaz8OUezKYQ09LNDpbdFaJA4BP+kZIFEcTDBKQZtSQ1CygQrEOHbtHwhiMWQ/gvLXPk" ..
	"0sj12c7MZsn+7h2Sin5pN1BU70Q4McNd74rHNKFVlMCZcOcrq02yOSbn5zsuHd5IwhbZqGIj/U0pUTee1+IGxdOy52XmLYUcYy4O" ..
	"rNjqi/Y/4ikWi6umpsJWZpee5pD2kcWu63ISBgKb2RpbT4cR3DEtyWNsWZ/Rdbm6omM8KCU3Q38B1tIrVC1JJm8D+rm5lpCqMt5l" ..
	"0Tk/K9MaeNYRvILMB0Am6uMEjQeidR2yaCarAYchNuqtCVckIjI5dL9XPFNtn41YJ05BSt6YmL6XctV3v+/guyyYno+Kcq558xiY" ..
	"UFrF5kCQzt8cntNhxgAO7iGQimp8SH/wDAEOgM6i1TrbUo8b3wCq3OMY+N5/r+hXrzciBpHbG+tgs/JFtZLBraaWm+FAS0OhtKqj" ..
	"3t+IH+eaIDksBOSGMgeYtLaneVdpc+d51LAKD/ADobJDqKOo3H6tqJ8B/AuiJlPm+0BbM/TJ7Caw5i1bp8J4aF5uOwh2fNy5oGhZ" ..
	"e4xbtUTbxKX7smtDCmfC5/su2SWPGYWIEt+VFayzHigfooBwAv1wLxPlFMIaJKFXEBWboQf4nZC3AQi8rkJUFYSFXHd0rkzrrHVh" ..
	"woAlxAnE0vQ4ji1YVJfqgohDQePQvOKSis/SHiAH+xp8e02un5F2ZPc72mniBiEZv8d49bg1uftWUlh9fzZdKOyW/XP19pA6UJTG" ..
	"7fzv4RcH7e429zxnWahbG/ibpxr46BdBAq2S3HRAc5Fl8vh0NaXDoHii1xGjFcGGf0yQrnoB/o827NSy+Mr+/lDqBY4KssJRYfpx" ..
	"UAmd5JOZZSYyeJ2G3PcaTcAZHmqMzvYmKtXwCUEI33gG/kfKEAzvGqtTHOjIFbxwUJaMddDL0wSmm3vNxJUbiHvDJXn/BuhBUP9n" ..
	"gbraZdL6VS70OM8h3fu2q0zQFHht7CBPN/NiBK9NaoCvk2FGXHoCSrNTg8ihFwqID2bYF9+7SFiTHepiShuiVY85TrB3SHuXe96z" ..
	"hyUMpH1dgvjDp3R8PG0qRfdf1amwsIEY+op9AyBbpwKmhXDUfMXWffs/6z6R6B1cxzSvVKMdZAGUq+O8O56tWH/B3dKvhrZDj3nx" ..
	"/OXXs+A6EF7FSprE+GVYaHiS9Vb/iAmSvYpEqmsHcZfVpflf1+2uVatv8m3u1yhRVworyMIyv7ofiANSdFJzC1GreQT8GLvqbo/9" ..
	"LzE6llVTyl4+K5rqQIcTaqP8xMh6e1mvqIEGhNgrWnkikL2br95wgsgcsL172AgSuFS1/XdY5WyOzjU0cXZDCrQpS3IgFWV1tgmg" ..
	"mSlWmQm6zY6G3kFSS5m8A/WDnWjiK7FgefNLfPTJ6rGpzY4gQNKQLc6aEhFzGHCvbz3NiJYkOD4kUnvjN0Y4P8vvTq021FyUNgNC" ..
	"FmZkG1OQ2OR+W6oCQyOhfMTbXHZCY9WPDsADtThJkmSaKHnmZZln+0e4m0WtTAOIM9rv3GU42CLObfKVU4roOGZgttWkyZPNwEQl" ..
	"AVCyjoM1sAjeQ7ipIfWBNfUVFMRkMahshpYFOK1gK5DBeheD1yaHfeJOwOUTBb5xUqWRLrX714wsE8qi2D26BfWDpp9vQgzfNXpS" ..
	"ivC4QhDsUFE7vu4lSzeof4CxacX0ge3FK+ee6/z4wXzWmmZKY39SpqTyGX+rsYXB2RY/G3Mvgid2KD04l+5pDQqLnbwwf1WXoSek" ..
	"Qb2IJP7vSL2Y+AC9S8tc/1lTbqMddLlbYVqf/VLl/N3n6/UjTu2pvpUZyHOx7MZWBn5soaVANretXHs67QTWv+CzwgvSUK53fjxK" ..
	"ke4dIieweMoA5YFnvVwF2GE4pL9tkf8N10tmW/nIpqF+CKE4PAhMxJmNqlx6Qy9TcgTZ/eA6lA66skJ68y9g3FZVy5wp6Y6+K14Z" ..
	"M0z5io4wmF6mZNfHXn5eSuujuvtUffXRfVYSSyNryvsQ3gnJHiEiNEWMvwds5l+7fwOLMQM6IZKp012iu9QZgph5sJtEgtrAulGd" ..
	"/vgxwh+z1XeOxEf7liy4Rdh7SuN6AgTcS8gpQc7pwDGSlO1BsCs1kHHqYl7DX/AKAjZ1+CdKNuiV7GmS9efVTX6V2j3m2uaDHoiN" ..
	"UZpEa0l+rprRUscQ0ivOQHGC8IBjEROdF45v5nCcbjS36DdngF7Z3ckUmyMYGN4U8tbRsnoHTH97o8l6FHtkXCArNFLEZ6JltTYN" ..
	"9xiLvvunY8z+p8309qzHGNzQT1mFytRCedwHHQ/9NKhkU2rafHVaECQXlXE8+dyNoquVw8iAvAUd13ObWukhXuQpeiizSmX8HUJ3" ..
	"JUC5M7F6FWSWBXE8B1xe7Q5D4LXp0ZoOuAyCPM/0Grz0qzp9SLbiY7YE4xN5LFDIhCqRosdBeBTqCc0Wia1GyQ71evxIl7wwGheI" ..
	"kYcOZNuV1BXyZbm2cwNFoNCtU4bFt61vohv/Og7E48GTFyDlcvJQir2/vE9q1ciZcgaFHRrSjBIJRGKqxofLWCF55cfqx9YNGLWx" ..
	"zLUFgvZ/lB/JIhGD5DWWKLM8DBM4BjUcRifFJbBYfTrnVMoi1vrhh1N9Vk/slgj8XWn9DY2fBg0Pf/9urzwJPRvH2ixr+yn7CSPZ" ..
	"399DEC6Fpx2fnOW6JLmBhC2kD+6gV2kgTkhrZ1r9bWJZlvGz/4n9mhHWtVtjeiM9kU5+kjRWuoqP9h6aIgF5lKdcxI3HWthXND34" ..
	"rtQkpM7Czg3joPnKep39Oq/lPFN4cbAu3fbMSsQbYoDUFcy4WPMgvolrSvvzDjZX1qGWDRHr5pUyhV1/JiT8J0S9C9PPrAaYwpTF" ..
	"Vp2T+YsH70sY1EXTVdqOmxEqtctRnVsQ9n7gXgL1LJv9pB3jcfj5L91SV9PMgzDXP3iJwBFHVu8xgTMdTb/fJJxmQUDo/JVDasxu" ..
	"nf12tt8g+OGwGHI1euJFbPy/N62tWdX67zvw2tYgoWuwYaw0WwUmYcsORwJYMKYdd7yMWyPv9pFQ9mp7CofkNujjQ6KCMr/1hUKN" ..
	"gB8uf4xUOvwjrnF6rluUvFyGP8TXtlQlZ4H4UAPZWo8D0lnUC/NANfY0XxkFsEGdlKPgpWuRl+9aafpt4hhGBvCSwCMT5SgHXLed" ..
	"WKuYkqyxHkKXfd7PLLPV+wxpIPy6Ja/3oOvyG4dBwrE5H/CNBBYgVc419LrurvjzI6kNgrVUHfYEyRbCR2FMjJ8vlP2aASKnd6Hq" ..
	"WRhwhImd2vidv3GmNPcs3qIlb5b9EhFZ6Vg35lfVj9rdips1FYbYw4l9xk9NDwO+C9eZze0frT0wgb5fr49N0eE5KlK671Fg6/BW" ..
	""
local PAYLOAD_P6 =
	"Bv2KhQ9IfL7O6PyFTKG62MjlwBqiXlHDnT+6F8A//bNDvceegmbtcEsier/BGnilpyd+8aBqNnYGULjY9VFKSRGDpZ4PAQlmvSR7" ..
	"XHaIsicn9pOp64Ez7F8R23/oBBfpJNSQUb6JPDMVG+6rpT+SQ8frIyRjoSzUUlE5VS/fIYH0ZDV6WSS7QwwhZJj9abTyIqwrrnIa" ..
	"KgvDDtSJSP9zahosyqN/gXa9p/Q+DR+yVcvsu4LEX5BaEy0QF8s7T/f5EXla2lgRq/TuruTgh7kYcxZsgkm71ipcEuAv3pX549f4" ..
	"gUMswfMmJLV+iAb90zBRIS5lW2BaXx+eNRE+fAN6dY9QllFeIngXrs4e5lLDd7bMNwhSj3v4Mhp1BWefobxCHRklugepRw9quFTu" ..
	"F1pDQ75aTn2TjvsxxKODfgVrRaXWTMpUDuHbH4m0Xg0BfwEtAQwVq6t1xJGOSTP0Xe7+vZWBZ5wVJ5jQsTQamDKk9xGq+rC/Sgzs" ..
	"TbQ8ermgTOpAQXVuRxEtWPVdzwgesVlm55+KSwaV8H85a9NOpqpYWw4ajCDnSn40c8V7N+VqGmXsjMuvi2bu082k0HVTrm9Aqn0r" ..
	"5ER+aGh55X8zSO0tpsq9iSemI0oRbh39np1p3bes2qz3qEPU4skwRbFgcPL9mVe2/n5i51joOmCAzzXfFJgjd+hLmtw5BrEbk8jn" ..
	"o3iEGUu1BvfkOA/kukvbe1LpOEY2Ajae+gw9H4O7/zQngo1aiiAycfX1vIOnWoG7Q0uUyQmXH1Qoi0RoG+ydV8qCdlxoKkgY+vJB" ..
	"94rxnGziSd6vpsz/kYxgBor+q6isuj+dscPkXfSjQsxgxvdgzQDlMPXMOwnhFraFN4WkKtNBDTvA48eK5h0s+n1c2Mf8QbhpMD1O" ..
	"sUb4IKvJtgiowyoAKgnzYVdAGKoxE8eS1A/oV9HH5KIDkQYzOeGAwKXeITvTfDLsYx6O0InSh9XmZrgW/K19PIttXF1B2FQiaBM1" ..
	"iwU23eV4GDjUKPEviVMLwUPBYxfl49csCcl6F9Vtd+vivp1hyfiZUqcEBh/gfRYwuvf4KZhEYM77u+VS352VxbcyKAK9ItiJ4oWZ" ..
	"g6l7bvyb6A5r5uMkuFGXhhUegMLP+DiaCabRI89LPUfW5HMfo59qMPtQd6kcHhngOcH32h/x4+FQiIfC8G/SjU4yqajynAQsVIdO" ..
	"zW+ohmwrYKhq1nLrCFYAeKAUJWBaR9AX2T6hM+GA29tH2BcfOmIUJQF7ET6Qr3hclXU1Bk2Rqw+78Kx44dIjrNYigWzWAM9bhmo1" ..
	"KF9LoktKETMAuhbXHG3Zf2XI7KZBSwYECJAl9dkrxECHa6Yp2ClvoKfDkRZsVT4xI0zPky/8FVFv5+0N/PKjjPqzfJsJhuWMi3zc" ..
	"8yYaPmBjZKoamZL0tBYI7ABs58LJj4tGbaxkrWPSigvxUbAwR59B9m9KbjCSWHss2aCH+/sCll+pUUStLICYaJF9XUQFkkKdJqBk" ..
	"mBfL7TRBhDelhgjLxWxq3ViZH5p9ODdP8lgU/6h5loBfdfybVYPV33E4ELl0E2Kr6nFZZsvK1Y/FBqTLEbUKd3RjtElCi33m8bDN" ..
	"EiW7GvAke350iTJ7aaFy4gr9Qpc8a7fYO29wtdZpYu2wDpTj2XJwaf9NPIMNBZ9ubbdFzorXKNlHWjSkQ+Gwo2XK7N8hS8q/tBL8" ..
	"jujyEi8HELCHzEgK9sysRIZu0oiufP6plmsCYOg04R0jhLgR4jjq0FiJ2OVNGdRB+TZMiHjIZIJxjoMXvRmIzVVLh626GUiZoGTv" ..
	"TM8P9iELgKEcuXAemYXXJERWFgTvjgMQinniZJqdUDAkYWWxqE5Cj3zZ0UUFdXWpOWgd3uhmGVuMBomx9ZwGykefHF5yN7a3DzLm" ..
	"mUxA2EULqkkM/m/JkzncStA+pD8MEZ6MBW4Z5kvGxhjRlyItnBUhi4lGAGmvs6uCk+ALNsy4Hfny2gt2imtAfmZ2W0571s+gM0kJ" ..
	"GHIxK5GAXDL+O+Hu1e1Ajwhz/HfROFz/P9I5Fmsr8obpA3RiQMqTWvh/YBnBEgG3GeFuFhjoknr9SDkwrVZ0ctj8eLe+49sOI64P" ..
	"w2B6fLyUKsO1Cr9xxo7yzaf7eKRIwUq9a4CLNrjwhe5XN2xB1Rdj+RVUca1GguHO+uEnyb52wPN3Bsfz1yhs4d5Rpk7JotSc8LqQ" ..
	"zi07jztksnIdSZ0fWp/rHrD6bcuNQ7jRDoz401ITw90P6HX6BOwkR5sJsje033/0bHgZk+Hx+K7nM0dzY8z/DETkU6KTR2VuOrr6" ..
	"4YG173at+AGWZCjFU2judzcypfrjDpHP6EjQBmrPt7c177M50KCVnVZU7GJmMoAE44Tor+y/Hs0DqyCBFVi7PqY7jo/EORDZzD0K" ..
	"vd/WBXhmSxBP5tcY+IrARy+DwL3y8Y45cwPFL0Ow7UAE0QucMKo1J/26aP+nwu6sk15DA5XKqSVSoP7LWdOQN/F6dhFHkoALJQi7" ..
	"21xb7MZ7+ed9YX85Yc/4dY2LxEHuBMZ8qhJ7KIdr+ZP3uX0WLsxZu66j4ja4CNAmHTo7ulGLmIGQ9CRHyYxD6k+yDqGuOPboURKN" ..
	"k80Ki+cQuxV6qxSpqN4TiELCG6zOkQuTniF9qjSN/xbcBFQne89OYBTT9gw+pgdpRTtCLCirvhLLIdY4pPcUaOC6HSzdIe0ye7E8" ..
	"EJ7cfWnFNvIqbllg0xYCgkKlhvXlO8kkFTpTF3Jnqcbuq+2D6U2Kbi7CiqUXkQ718vs3+oEHcrD2rVukkAvUH71brl7dVpMIoNc1" ..
	"h7HImw6wO/uinFSo9OS62PNrR+mwkrAy9lOIdrWv8428ZU+E8VtgQCSltTHm4tkwFsZ5taZxZv1r1fRN3foKAVGiFhcdDL1SzqTj" ..
	"NyE2GlAjT2oQRnR4BW/4m/JCTnvrQ3m5/HINHbQUy03i2e2WWTNF4+i0B0fXsxX3pW+Y9lXNaJSs25Ygxb86+jSxK/zm58dMenix" ..
	"8568G/2Iwr2hjo0q2+suLsYowBRWs1jAbkkFGcB0PHGha5PlHQQzn/8BzhsOM6Fw9CJ+MnOvOH0Ss37s7IpR/bA4bFGuPYIwHv2a" ..
	"lslD0HJhIwhp4yBr1v9VgDk2+iuW6Q+M/ElLL2Iks3Ecj/hx1Jhj6cY+GQ+UUkOU/So1QaSsCTmqe8nkZqVqPM8uwhu4UoUZN7Q+" ..
	"CVzdROjqxunwDOlhaTtV+T2cEYeFUPzPTa0bH5m+ZtWmObs/DgPHCO9JAZGzcYlnfDMNILxhoO+g85V5OYfJZjoND40xGJo5jspU" ..
	"IUVC7TIxMtfxkNa3mUTM7GqpwrDfzKJnuDKieN9QuAxBSpHdc9hKAjPc30nQ04gK1sUISQa4sU4V+D4Fb9LchVIKrzHEK4SgooUu" ..
	"/4bZMuWHrMYYOfWKQatVAzlMPY4DDDzQ5gvVuFnv9rqpX3ALY2KN7k0flCMoYA4vbLbauXuo/vzS12diAFXxTh1dhBtbvaHABSyT" ..
	"vIlnHnbBpNoIRYv2YOeaygIZGGFNDWlDRpt872fO6xUlAW14rM3dgI2hK2GB483WtdG4JjibplM0V0FaJkeQ54YSwyy76FaXO0OL" ..
	"Ug1eBkDPLdYZnfNxjvtvtJB/L+Rm9fieylyQGhClfH1sXFbolw5SqsV+3pn6RmfKxhg1ZyjPtFKilHvaTy6iQzoyhdpCCjWeADJz" ..
	"mhUtcRhDSxOfxpbolGohIfwSCfxQyK3n9jfqfwSFg8sUuqlpIwGjlaojuquie8M8CudDA1ceP+VJWeBkj0VpPt2piPIeOwLbBt4v" ..
	"gVRYniuUDxcRsL07AAdoaBp54YiNpfaDHLzyVHMhLZKyf9n/yQGkGfrhxFNTUxuMTbYBoLHhLASZomxRX0N1/SynDTNNcVbfvPH1" ..
	"UM/BsUWMao3BLNrdHsQF6No9A3+872zaJs+i0RXh7kCgk6ln1TSXiQhL0BkDJECSvEpmL2NziyJxuWxGJkI7VTiX7VXDmMa9aj7u" ..
	"AGijbpscqzsTNnuy7J2aJbCXx2ZKI3n97dU+xxvXW7D0xoqsoCWKzPWvisju/NmNZgO+wOZt1YiRnbGdrtQ+NhZn/bAJRiqJACTU" ..
	"P+yxPiUVUryl032vNXGNa/h3RcUvES84dzVzqfngguW/LWgQLDh5fHo0MUsbZan0VMcyU3EjncbwF+ExW2+9U3BviMGoq2dnMIV8" ..
	"JeOiZ1o+sSOu2mKNbpP3i8i+0PqEFdNWPWxcyKrJkswIRVebd+R7oNDfCpUPQF3sq8rEGcpPdye1Zqk0KWmBBfkHg33Lqt7KBCpq" ..
	"l9kWMc3oMdzYwGe5brOlA12rQWXrXbMsy17Gmc1SHAx29jnTff/QskRfc3HVLVygG7tSXXuFxfJM3jXPit7NSL0B6Sc73LKMlcYd" ..
	"o5+Kv3UICp2IsRBc3uy9L2EzzKppUrnEg84WeMafvZy26wmOyXll3rdnDQ/FL08F85NId7MDgGyfzH3RSFUshMb3gBNVUoUvtAuB" ..
	"ndcwFa2ejbfVIkiAFFlCbi9TQC4+Y9lUWSisDiTXEFMugpOB9+TcMdDpBFaj935LlsbwaGTiy1rKZXIr8YY/MJnqHktIvGt19d8/" ..
	"Dh/kIpkcuadZvy1wnko2F/5zAnzki0NdYtRCcuJZEQxNzWCi1utBceGnNW7DHWgCCqos+H2kLHzv651XnjIZwzBa8EpXOSp6Xhop" ..
	"JtSzrCdMVdDHMSyQI71oIeo/5WjGDj7kYU1KH83cttZeD5hCIdePV7fY/4+oYvLsYDbiatiBTxeZ5V7aJ0+kOmIhQXjgKH60eAtx" ..
	"Slux8Q5T78cJTMHldZQ3RnovrUylN1awn3jty4knJOTAwTPABVE42mCpLIBK5MfC+eCKDA94PUaY6Ut3i0eJDMwJj3YbD4wef3Mg" ..
	"kz6J3i63I0Lu16ocROSOttXrELj8u6WmF514pFOphSjIBUlWB1e9E7icfJEz3YeyzpJD20SebWcovfOHWBhf7QgebbcgGf2/HzAf" ..
	"1AmClB6zDjad74/oDKd8efWnxqsZ6XKkaOcy/6o0HixRHky1KlwbnLEj4rFUuShn5vyrX19Fo7QdBjEuP2PqX0kZLHWlDB1cYn9p" ..
	"Lko1tjGUYhztXPoIuctfVD0dR0fOj4YAwYEO/PEyN3E/HR9oO/Jzu4OHzd6taHpA78AsgPRPT2QmK0mdF2bbDnC9VFYKUqzNtrXt" ..
	"RkJMW3CJPzCt3PohfWaTEssYeVEVxKz4x2W37fvJdtmBFv/22En28Ez6/IB1C+94BR363ZRTcZ4Ny39HCZHKMsPrcbYXvzxrLKVe" ..
	"E3RWOIKG1XE2+277bHMp58Xqphxa/KrYx+oCNSld9jt+1rO2RKSkpfXJh0RUOCuyVJht4XGTP5n/gqn9ur5p7t9iVZZnUUtF+3uq" ..
	"OnEKiLaE8r6rUHZ8F0VUYQyWboIev5Er37dt90KcgpXUNrE6yx/6cDfw+NR9mPZ84Vv9luVWQOz1BEYPlNKPUgCpe6Fhbi1t5bQQ" ..
	"hp6o1X/nl2N9RGBxbjsPdRsBo6ObqAcjJZkwq1o9grfXactLeSSFhx+TLaiMSwqUseDE21NE/XacN1khbJh7djHe52ZeJEhMsgWI" ..
	"L3NLhZoiqjBCUzIh6dednVYeG/lTBPKLaThNKN9KhF8Rj9aCKCo/xNo4599E9A0TSOf3u056oon9pK8HfFHHVJANXts1Bg8jzU+x" ..
	"CFnBuYWD+yy0XK2sMqejljZRqk2przSqN134tUWxx64IUR8ApIAIPH6Y7OLj3Vs+pzEkDfgUU6Zk8Zek/hq2giz5XjuKawkn+wOU" ..
	"uiI13Y1XUIS34mSflC4NtY0pxYteHL0tOD5WubASzWn2+pJk60voQeq/RhAp7ofwduz1fhobLUWDmJMRA510KbxQ7Pe3YpjhXfSE" ..
	"WJA24t3vSlfe2py3yL2iXogk2ER/2ayQ96j6hohr0y9ZWVwqmQiDm1EY4cI9s5Y9i0xewvH2YV60J3gASBU2xNl3mstF2TDTv8ix" ..
	""
local PAYLOAD_P7 =
	"PsbpD4iqvLO3kl9aA06y12rWUjLq7a9kKM6j3DuArmekBD3CJQfdYUtjQ5ATZtl/V7cif42AcA/Pg5825DQBrQ0sYKHHG0n43J5r" ..
	"joxu2A1n+gnkCFW/BpTitEpEpZq1G5WwdbWgJuXPyGGsISnVKjVMwDe/wSmBP4W1KFInflKV1UrH5e2MXqwBvbyBY0f/6s3nDUwO" ..
	"3Hzv7q9AVzlNxYl05HFTPBrduEHOBrh5vkfEwUs3Nb/iRwcnqxiPXnGmVaFjM5/5rjxkUTo68TgNyChRLvqQlv7w71DZeN6nK3bk" ..
	"VpQtcOYUs41qQ/rehFFJtJ9cDKbATrfqYWrLlJflcndVITI4xTyKdngrPrdJRiyazS2eeQ3KUyUSo7tYB3kKL3MtiglE8eIsaM9r" ..
	"9e61mLpXA+pS2Yak9s1Pn/pnPmfYt6R8T0VhnDnoi9KEEAoQo5f/GLSIZDvEJTZDBZvVEjzeLJFjklwhNoW2mklUdiHxzJtwneZP" ..
	"pFsW1VuEWVDy5E8xrkmBREpQpi7YiLcQ01m4MhGNhNpUbhwybyPhEsZVLM6330tT/7uNCtwcZ7MyrdDOFdEe6SjjOc9xnK/xiMzW" ..
	"ksYwBYg43+0T8NTSl4aTmE6KFb9C/1GEXaZL0pXtcIA4ZeTmjM7IHqoz+nmESsUZWkuNKmHXWYXayiXZ/jjX8FyRdx/Cp+3DPheG" ..
	"IJzFg9V1hkrZ3t1NkT7WeCSy4juv2rLlg8REl/pKGGSSRqVQIVASWU4S+43MiHkrnz9r5ALlS6HXCEajFqNtrIFpXCcOSefjnkey" ..
	"MCGqVQckZ8I2EUFSU4acg+Is3e0hu5fyZY701mneUhezkAdKmAotRqw8ml2pWNVbqUXJ2PDdZxGM+dj6wN+GBhiV7/DwSPqRm+O/" ..
	"OT5N5A3ezxqvr2gnh5lh9vMdIhkgBBbVUPw3K59IivnhC4p5xJnfST2yqoE3C9HNeF/HN1qzPUdONskTJvFfoOnw3kBR9SdcFKJE" ..
	"bYFxzc+dKuTgbeTBU5EbM3aiS3mwencU/5gzzj/A58OcFrRcaJ1OrxPgWL/uRemUOJCnPuh5uGFTw+DZGY4H6DQKOQ2QVboM3GeE" ..
	"8if7lGLjVhj8Q3LVHzNSVq4pIiOHWeMoKog4WTkJjJEP3EvzSpxcq7yfQ7fhMwDqCMoN20Kbl6Q9JV8dX/0KrbwYkNVcuEbevT6e" ..
	"zbCmdFugnwfObMeVb/VaTE+oP1SmIQMLfT7gs9AQI3gaiN9kflZEAIve2Za4nxQvXME9edAvgNhzfhQRLdLDC5In/X0MY4t1plbQ" ..
	"Pwy77Qa1iyGQiU6dckfvdCIW7+zpRazEuNbU4gYZD9MVfMDEcQu5z4xWm8d56xOY+xh2P4hVJMZiI2TjVJtfs/7fB+3EmpkqRxKS" ..
	"2bP3kGszkLJl/eOsBloNTq0/I5Sf9F2szyanmn1j2UoH94EcqnnSMsNYJyqwvQ8Uu6/dHvpYGXkrE1x4A8izDV8BgjzLo9diseS8" ..
	"Zw7UtljyyGHz/UP0Aan6JCSnxGsgSpv0wZX6Gi6kO63beka7dV+mgRoYQ6jCBR9WcOR+jq6oQz6At52OJy8+TF15lS1+NyYAd+EJ" ..
	"uECkU7EMgleKD9l6TwMgxDvHnST348vvwKmE+00n0SXvLMq8D2XPDK6FhgZwlODgjKwaTLwJUUoCGlG97S2fHJFPtHMIfysPndfs" ..
	"4eZG1T6Yn3jdDbrgTZx5ECqJ+uOEYLsmNvf/uOhR0iY0ED68Cqu1XqycG69SftJdxqzRZP1XHIFJSEgbI6IUplGJLwQj9OK6tkvT" ..
	"sUE7blEjwI72SS4wiI7VaQxn1//gr62eOHR4UsTPFqR0p7hADLmoTF4O7+6ZaY77tZ1Z8G1Kc6zHLERN1gi5W+3hdVAOKY2jNOxf" ..
	"gHv1xOmcNZax6DBKhhpXVB5TaI9vXPmXRhD2CuxhlbSEhoW4BrGsHqm6WIdXOvjk0DjDleSS49uMx0zT1Kz6KtNRt3qEs1jMPZUo" ..
	"wjTNj1yz6t2pLnSddFVAnyV6QCn3BIZYQIkbnvpvxJM0fau6OI7Lg5oTggaiLd4Nnf6vqc3PocDpUXaX/euI1M96kvroke39RJXo" ..
	"8X9Nm0U0iI+sG7Ptb8JtnIdqd/giHS573IrWpank/Hbk3XYjm1tmObRrCjyxKFjWqXUHzKgQk0l65bYatUkpdWMz2Jlf9sSmusxL" ..
	"GQBMWox80GZbmvdtSOkO+giIUNlebHj+JXVGVos7fd2B8pjD/DGxAIUtRg6M7rkV5GCSoRFTPuwjNF4Grhxt5JhV3nvsh6HVJrEO" ..
	"8UtyarXy7nWN4FXHA3gfTAuTlQFb3BKMZe6LpnUUB1suau3gweYHWTP4ZSsoHbEknNLTIreHy9f/8AXu2PlSUGT3uoriuW6Me8BD" ..
	"3sqkJOImZief/UCBfc0yK4Bh9VcLLQ/Leal1mqWr1VWzjPqr5bj12WmvXXU18LaOOMDmH4v6jFsKz5BnZ/75Y9jfiKYxzS+31IGP" ..
	"jOVjbXzHsqajRkxC5kwxl2a95c4lpic05EfTlafjIiKY0TPX4MrgiiSAgXGlUXYVouyWfrxcethwfILc4J1a2ksPO/ZheSWvVtoT" ..
	"NgH6YHao7S8dUChjo6KAeCE5bW4ieROxqgfE1vyRlrFzJBfBscQ3pWuGC78BzSel1RhoHXEK+c51GXQASJlkBE8GNGQPEStT1w1Z" ..
	"Tp0DYV0x2x/7KukaFMobX7b049+AryczJcEhbn7wsIQR+QZZKaMpBySn9Uoc5gosQfjEDxJqFU+3OSsnLfpu/Yz32BFjI7s8Zkwy" ..
	"NPH624zG0P3Jm9eFEKm64DFiIf9DmWzZsPHkY5uXmP1nAnaRLxjw8Oc+EaDP9QsRSo4LVjMei3yV5EoePUP3C3QcIaEVbE3Ca0LU" ..
	"YHLDzJJCTupRUQ/Al9vWC1wNeraw9rYPvJ+kBdph7bQQ0kRMlwN/Y8YkTuYA173hLqiqT8MLCUbwKiShKs4pv/NMHS9JczuO+N14" ..
	"fdhk1wyzsPcyhX9W4DvD/f3hJvL2JQzRF971TEEEplWzG5Ew9pLdV8WtX2odevbpPyAH1d2PfmOyfwZXHIYG4n5bwwB21p92xyYX" ..
	"gdCr5LXaMrL9W4YRcqHDZ6zgewJZYdsERFsu/cKEkDrSgKjtU6WWLocHMN+CXpcj4GA7bCrw4NvmwSKtOK2CQSMdwVaBobxDqKUG" ..
	"C9gAEE+KgdofD/nloJhWoIE8UADG3AfjdXy6jQYFalJw89ATNL5kPIw08tXPE082T3reKLx/dQIrwV4CIoY+YyoAU5fNB7bNigmt" ..
	"FMoM2ae8iKPEdTozgl5N7FrgpTkkDkbmg8lR7hnJXp1nPiyIGTD0S1NV+EMabeiWblKMWfRP/Lle7fAhfIBLml3fHhiUq99/WPYd" ..
	"Fx0STDqEwTBdYHohlJFkaD/YXRvM6lb4COP5mpHtLxIGTFTvD4gaYtPXKA2Lh9G4/bGyNeLcIwyt0G7/9Fh1NZKnrGHRhbCPJlng" ..
	"rn5deupVSZ4D2R0iwknm+oYyZVmzvUl0gIAbkH9XtW9Lr6KINSTyJYeJgf62YLaCAN6b2CcpP3kBlrjCTCk564W+lpltiAq8TMvD" ..
	"TMwOYrUh3IU3Q/7fj5MIOhyR+PcoIr6L7E0h89fqO5Zme98vWriUF0Iu4Jezjc6KMXLLuyXQULcfisQIDvvKBlmK8Df3blBOi2TF" ..
	"8vCipstYMagAy9KMMw3YX7ekghWmPaZmPk8gS0LAvWWW/1OSFpHW1RlvN/o6s9YbUQae5IV9ShCar3LGbe79tbqp4u9+KfonhAn4" ..
	"JDoXqWawq+riRM55NaNdgxXGNjeep/1BFx/DZzoS5bxp374yfAZDqfYzEAlRQTbW+ElrZ9U1GoXTA5hJFpAgcCnW1+Azc0tj6QZB" ..
	"n6UYZ9JuE3ZsinMztLrKJ3slwreLj6tO+QfVVUcN7C3vOKRP0QDCeQF6zpCiRxsNIArPJr+P1vY2GXXQauAK9mn+6pxdjMBSJDmi" ..
	"vS4Qtz4oMFqODQSd8fe/kVnzVFlR7xr3ElIacmiPMQVoVxITgS1IkeAxO+TYda80/iqNQn8P2XfFggRlzmlNM0tC4cS8O2jVzjZF" ..
	"tiqkkNEK2NuseIYOjjLfS6XIYMCiLTIEx6sgNQvtv+MwGWSD20z6RjIgYnE81joh5dhr9i9w/zb4CXnWGPV6HeiR1PsIK0tDCXWj" ..
	"IrOZwy0zVd/DPxnjIeW6vRYHmz8jH867uOYsXb/1N7rO5aGTXlpDIfRoLPZ5p8aHBdHwyROClRHCWrQRmYUrgNfsOrLLhsxElzA1" ..
	"DyzkaO/1QgWiox+AmiNC1bPHFPhULTWhlLNBoqEn5ZPRdcyfASr/9s2cWGBzBonSMsbvFNJQ9qgwqbhTH4Mg1VbyrTDOGUgSa7/1" ..
	"bQfZ9rbd/taJXrVS4N8oX92YLq12eqP9r04pXqakL/1LRsFBTjc2hMRTiml2F5of9e5jWqhsZOi1ynAk0hW49LCwiGFZtDF8GvBg" ..
	"S3AjuqT/x270BdTCeRtkPbj9iAnfgciUA2S8icBv+4R9nYOGDcf3IC8wGjzp5Qm9/vzE0r0OeTTLIuz7G6nOkH2na9bFNQNKySqb" ..
	"c930QBq6JHjnVHc4sXcYcscYQTuknuVQxd2XHeCKAYX4AXXQUHJhu2U9JuMPdgzOmFcV2fKN9/ifHtVOOIomaPXA1kiYrx5AZbEW" ..
	"uvOqc0lObYfaE5e83QcgO90RKPwElJIGKZvRWgGT7brI8/XTnLY5OejskNA+6nt/G/jF1vyTFfE5mvaaRoMjDrViXJ1xtHzE4l+9" ..
	"rWEbjX7cPTDv8nfujNgfWQmPrbsNOyDRuqJ666cih+CLctvGdyTJ0Tzl7uYzU2v0xMCkGd71A0qIYaiiioc74D74EPtKDceGxlyS" ..
	"5oI0FmlR796cvmXJkc9chioS2bNRb+3wAffOHBOFJG8byZxl/dWprv6RLV7q6Kg4RE5Nm32lINkNKQ6PasyPgwm1CdG8G7+WIVfZ" ..
	"ub9/PE6b5Xn9bQLFc7Kvngc7htd7kh6XrXl3xwK1DI3irIpKAyUFEqZZ+C3U8Z7T0CqUIpYAgFb/jCZRdByJjtr10ooo6ZGgUXs1" ..
	"POdd+4XcN0N+J3rUFYGQr2vjIuiqCJdyunRM5UDCp9W1R92+hLPytblQvp6wO63aWFEq5wsoImO5W+wnG9pWWlviPbEmVav8YjSg" ..
	"zuKPMUhYpYE/RJNkNA11yjLF5PT6Ay8MKyp9xOSwRx39OYZkXrms/eKBxH8ePDvEqlYziAFmB58XXkDhMDcsSOS4hizfolH4pioZ" ..
	"7O69A/GimzmQZU3HeNUmKIavyyhIIHHpOY7hEeULqGVunSCP8PFikHaNLgd8F2wGyV0ND7WS+J9wd5xnyHcugssu/0VzgE0VRme0" ..
	"8jn7HfmfEHKHB3pgg8738nwYlG/B4UXnHjDE7b8p7/ZVdqHsvOvM0BDjYY29CqxneEHlFHAOxhx0WSnczxniPyyQv+3gAdc/au2K" ..
	"k/kriNMHKDShD4ky3O3sFWc3MctkCtLdY58zpcTZ84zeQA5c45BcnDfNYCl8TzVWTNLCMnOGgbPS9Rmc/NmYGeJwKvDR96Lz4jYm" ..
	"Zl/Yo6c4kby4ZAFJcqOsCcdxyFbL1WfqfWfHp4tZ6kyohS6TrSpMkx1WPtTIcZJXhfjGT3NUA2XmNmZItojqTjcL7fbn2UwOPOeW" ..
	"3zCtljkGgpdP9oJE+TXixe0QJqBuBDhNzabmY68GTFIg17IgO7YJJ0WAOY+VKCPyWTzNGRKqRU3bUjtwDIV1Ye7ZfR+1dCkhwpST" ..
	"7GyVcYsOw1O1kajctT6bq1jtxAKAZKtJjFsupevqwEMi5zbSg8RBJLM3KgJA4AOZLRa9oMvCiqEtMgGNTnJEF+nuRn7qj7IScwZ3" ..
	"QZldEYoyreqFrUDR7ea0y6CkuXbSgTXirbsRpkEjLokC+qcYrm66jitqpPUUqRN5H1jKP298olSCuRS2J1TZGTjojj4RoVw0QJTJ" ..
	""
local PAYLOAD_P8 =
	"qfEW+3QTho3VJ5LbD0EeTDmK+4ka0uP1a9V2Ea1WpXeh0gj7csgOiB5oo3TQ+TclKPAhKfSuoO8j2F4tvIqubFp5p7d4hLxtDFmh" ..
	"ZnaUZswTS42II9tC8UkOxuIdmPgAzqZ/OHdNZgEOjNFUIlhtOFOVSi2u/hX0MILDcy4FZx2lIlWIH1HM6i3pRv2OqFSIIlNt6Bzw" ..
	"5D5o+mQSuYhAi5X+B5meb99vAbOFw4RzQuErshViZaltN/D8NPXBkshIB6j9GV459f6lSCMOk+HQ+z8GrtGNi3n+l7f0zXu8NfkQ" ..
	"0MHh1i/xC158fcFndVRbLdu8HyWRyWoBV/rq4Sjy3TRB2ljXWQ3p3MU9CwLSmJMEDIOIKQFzn8kCxvQlOysjulSxOi4ENboo9FJs" ..
	"zcCPcnKqOisxB0pZn9oZjLJaDus3R5YnIlEQbfJ+afXUuGQV5LcuYi8xBqh4oE5AYw1mstKyGq+Q5ZTPF6vdrDtL8VCxBZ0H0AzG" ..
	"gXdZyWyxMG1TWo7fPbXPKviK6O0QrwVj+iTqkc2asmsijdKJG20cvGX9NVGn8jYfS/hIjzBQxq2DDBqL/uLwLQPaFA6NMOOgkzRT" ..
	"zG/PdOQGRhmA1i3jOV1MshPrLH36lMsyQULva4ZjuaQwBfu2nFEcaNik/aJuiO8xSm5LRkz3NjH0vO/9VdPqTssv7qOUy+E+Iz06" ..
	"EBwQgLaQHeMLpN3UW5kmfDQkVMjTK7j+3C3FzcIoNLkXSlW/MzOWl2XKyIaOWaNi6KaxeAxX0xz3bD9rSVPEnp/+WYN+frhgz0TX" ..
	"62nZxMAy4Sj5o7nO4+cVp+0IeMybN4otpuEQUHvmIlBVBpkz5HYv1W06FzYiRpfmxHi/vD5A4YpBSAovdahKaUV3nruTQCWcUhmQ" ..
	"iCC3p9HyCHlsG2KwZmdhy3reVdGNKIZ5MCc9OAUZUd+pPkgn8OJ52R75XpcnQMiXWa9vaTPZmkPqQ8k3vENZLVk2OoUYHUB51Kgq" ..
	"WGER+0k5ryh+YwQ0XBITrjXgjdy9x3RT2ChvhyE20VmAxWd8Wf5i0y78fB809PtDvv/rH2TU/5hFsBwtvDU+Nnpwm3M8nJ27HhPw" ..
	"tS0bE0HNnTF7SiRovUnBu2yuAc3rIs6eDsPvY7bMdgXZI+s6yNLbZ1reSIAHgxa8C9PNrMaOTGU/eDs1iKyj/f/acRo/LQsyHdH8" ..
	"rHk57RZ15kNPSv70tGW3MlQiP2kymwD86GYQwC6tb7JLVmHMP5oJpOgNfFIKf0qYklXvzVg2HB24XpqS/lmXkf86jbZ/iPME4PIO" ..
	"sJ2nYLe8242TMK8bHJLwIjSv01f/SFlLUG1iaE9ZjUwUj29g8e6ssB6ru75sS+AIYcMl/E+lHrvvWIFgTSZa9vOsCsWvytYFmOni" ..
	"P+Iz0haJuHsHI/f5XS4MUGZsTmvgLrN6Jr9dHen/fbcIpTWRo2c/TY01b0ryVcWpf097pBiw2k19j21pKL5qjPNIYN7BHyBNwmL2" ..
	"3Gp1qbrnUIsHXpUhuP0OLa0Aj81Qenht+GRJq1v0dpAC7w0LH47Kjkk+jQNrpIutP5zRlCojNhAp37F9MHQiz2JmW0fR+HxCeIFd" ..
	"GpKHS3c9/poL1ilY/e9lDFSI75wGdnmkrJxpRY0lwGHxOhZQQyv3hn4L9JM028S8LDC0lCkwSYSdCc1lXOFodn7B0t8gX7BUDlZS" ..
	"zClcDV/X5+B54xCFCSE95UAlyJcSH8BZ8QphyLIoCYsQrZtXWqVC299H3NcukzxompgxyGNJdzVrxoi7bJ/k0BjaFYIblP8tUwpF" ..
	"mnVnNSG9fLXmoQucQiDK2uLmQHQ/OkfxPUvP7hOHD+vnz5qOzL17Z6lQX1RNz2Lxg6BfyN20ub5QNCQaEdUM2HM+IpU87HFtD7xN" ..
	"QtI5R+wQ4QhqYEUy5aCo3pLDxPAP1YbdjXRSOTbwmw4cFe3dRZ0TzcIXyIzF2vf9DrGZlGdYKpyvLKODDgYwgv24Rnx2+EmkMgq5" ..
	"s4YQrmXvBrVnvMLrRRdu7hXMwlt8jymo3BgVQVDGRTgOS2C7rV80hMYQo6SaUvFeBhO6rQ5Hxm2zBeMBnUPsDICuMbxsUor2iq+w" ..
	"rVcr89dtPow1FrOIRl+9MsiuLSPltuIXy4VdpX5o+K2IHn09VgiPi/6DlfyR/CpO4VO8U8sa46iUfm5Vc5lPbd9fNP4J9Nb5RY8G" ..
	"UhjggVrOVVb5hrL6UGgqYH7zH6LjQvlDHpKaf2qCSjMezgc0EE8//g7HFAzWovvonCAqA98BNlrz5QDUTdaqYgSxfyvIRnUqVSpL" ..
	"f6VZMAHyn35TnD+MbQBSjM0ZLR/I8+a/Dim9O4NmSXR9uYhtbQ11/bgA+zC8+RWIVfQxb2G5siQJ1KPUg/oxpnIYOnXqzo/JFUD8" ..
	"1K0ShmDO0h8P6/XQQD1Ts7pxDREqARA0xQHj4ViftJY9Y1FZvB1KFsURp2i/MO6Y9l2rvJkat5pedARu4zbkpv4Lp0BgvA6cxxQt" ..
	"jRZHJOrOTN7CdPKqTrI9/ghcRFlol5vkIol66cOMqjBgxW3KAuMl/7K+19NBggrmyHIwZUOuAg89Q8uzbyrF+CAr9AqafY/ecbG9" ..
	"1DanZyq2Tn+8sdoOAFxu5uvlQ/IFb8r4Qyf5vGtbP0c9ylajnsVHNLOrWxvEpXMZxRWk4oMcP1y0s/3pNfNnM4h/p0w9tcvpMDj3" ..
	"Myyu1+VL+jG7Yh0jsMTjprN5Cg0pD4DHyQ5uF7/6QvKIi1r6fNeWgeSWLym7T2j0Ui0gG4HoMWxX+37IigFGltfQ++X2a6kE7hPw" ..
	"eXiwzkpLTOHQlHvOh/HxhTWS1U08K3KeqZS2p6g3/fFVIUrUohDa5i51lwxzvMR0WBH1gCBNX9JXSec0XeWDnfIJCC9i6kMKJBCZ" ..
	"UGVjFsnMKswEMoK1ulBIIdiKGneOkBmrJw8+kaA6MtfOQfsQcn2rUfF6nHiJ9BpJPv/QDPQFP5zx41gPQ79GBVy+MocDQXd46pj9" ..
	"7/GA/MQNNz4129kElCiTL6spjV4QgOKzaNBNJEtt/WnwLeCts1VcEGNbJqPPYNxA+dEL4mQFqnLT0NYvkhdKLluRVaLK4EA7S66d" ..
	"vrhseSK0m8JmFHOPg0ki2T5teJ5MyPvg8uu33rQMuNeUUba+JWj5dQv17t68WzKSKtLK9fudWf3BJaqEGfcFgLEU0PROGICbcuNJ" ..
	"zkGWfnukGzNWAU/9EFMjest+JwFjBYP5SY4ms+zyEX1Qzynwxxv1+zNrzGM2tYEoBSbk3wJ26grBvbhcadL7CBEJMED82YlZv8Bt" ..
	"FWJ4/mNKEYbiJfzCvlX2y/zgk1t6pKoN61GLQCpL3xhCrzpTq6ZBLkLK55rPCd5LG6u2/thj18FNmX6UGPUMnoh5YDIot8GnMHyG" ..
	"Sh/kUI8Lj0SuZEqvJ9snI1MRqyIEEYqfXQruF0DvR/OzfFVHS8LrZI/Rtc7zE9riCLdM0wHun1mBW8hiCFYLD2/qpPCWxus6i+BF" ..
	"/5/7UaxherIpb29a17rPEPUnB2Yjfq5E+5GyEmxIIWGamuKjjX1bqgRLBg9LUgiJTSkcN94zfFfKTA6WQNpUHQ6+8ZK9KPYAv4WZ" ..
	"aQOxD2p1hxNYbK4Q/98ntvWC6UuHIavTa2U0oPr4aIxEJSqTDjFP/vc8mjN4ACpmxNo3HajX5FScCZaPrhe5zPhXJWQih9qapehf" ..
	"jL6iraapnw3s+/ANjpH1cj3H4qmv7xIJe5dDQ3TcUCVhOo5/u6P3cIx1sK5moq3lZtSduO9eeEgdJ6WQZMn8QKTse5R/B7YqDxit" ..
	"BXyQRwSv9t199coGg/Sln12Q4L6WryDwELuMMCxgTKKTKcs2AK1nzKj/lHnBE5WfRH6BEFjXIwt/0Imjrm7iFhCU5htDQgBLIuz6" ..
	"cIThMsp0V/kLsLvIxkqow/m0memfsoDUwrD/aK3q0tl2Lb6cyZ5tBCLEoLDTMi5tuBaSY/dbTZFcLfu+cmTausVPzixT0I7Mn0rl" ..
	"Y8O79NSQ8w/GpV2txxE0z/BJPyvCm7Q0nIaCt0utbcenbcmQq9K8rSJdP7+cpXljQUZzBCZ7EHZfn3AHVYtmnVKQAm7MsOjjPJaG" ..
	"eT6gjIvaXpkCo65ErDNYLxlLOnG36nUKqW1QwRkTRZz2NLRuV9O0QqqvCsuPdCdM7LTeNQ3eyN2N9oct/E1Ic3sGBmEwhOH/4gdq" ..
	"jCl1XExL6L1Ouy985gkU63oTe561FpuNGiqFU3cpTCFm9gqHotA97c1F82fCnmZ/kvj5JlC2aPbg99hp1JLTU89i8YcktmtpzLz3" ..
	"/fXGNo8R/qDZ4EYUg4vCobQZlfbi8uu6CJBRH8WqqkbNsSiYVQ6NjrWmLm/MiRz1clBnrabw3Jujz8fV4NpVccmJG0vHkgCwVRBm" ..
	"EeDYHJq36cyx+CDbseY5gPczOuOpJCwQyNT4m7mbrx7fADUz/+U0fghXAVpDBwVZ4jaOuhq74ook7j60m86FBwGWvRPA4UFaEgbw" ..
	"TR3Qmy0bFuDwkpavKFefbnZgiNcU/5e/BApmjl8qs6q8BNoCWtaDMaKThHwd2cBnmHXYs4W/Bpz1fZYmSk3B2j00j1HZ0nXkGWRI" ..
	"Za6e7X/o58aYD/9YKGmeXs7vRywLE5lGxvtjEtEglI1FBmjlDXLSNUX9QOzMPRvY47gRVkoOqUoepO+q1eJRl7kn/JfMvbDws7Cn" ..
	"f/YOQsmLCXrSoQyy38uXwu2QEENhnCdwRBMw/64iavOoEezKMdsA5mgBbzeEuGin/JuKys6Q2qd7Y0MeRpK1DDW6ZDlTSs1le+Z0" ..
	"d9iNmY3aXntQHriZm1LYycEdI0cj8PUco9qHLrdR+ceOUaj9O8swk+qL4KxQSRKvEifIetm8w3pTtvKzfxNgpkmwCH2ZWAEMj5sX" ..
	"jC968xKJzEsxStJzh+rqw2ZrHKyPMIsovbEwlIZ4xY0htY+yFNn7HIP5J6T/vuUUNeFDY7YctUJrDOdp0lwE2eyoXkkwDGJaMa8i" ..
	"yYh7ZQGjdWY+l9mEZVjs9G6q5g3sTd+u87fvyUWWYcLIFMrhUKGk5E8kWV0+ukZ3c89v7ARxFJ4DuF0XAHcMuQ9GDcY4JbjQ2L+I" ..
	"u9Hygb70o8OPmjkfqMnnf/D79VHWRpyGPJLkYPVKW5y9XoQGK5krhyykTPysNfhHV4kCilN1hxBv3A31CUVQvZzKyHjMNr0KvmUf" ..
	"1L6hlGdMXt2ToXDY67t7REcBv8LRfoqtDZKPt4eQ/8zWWejbPIYkz0FRrY1U+XqThfxVI6Cjk0jVlUWFvSRSXaPAlWZjGBvCpXUs" ..
	"FGGI9DKu644kCDY1SRwPe/E9CosLTiF8HF6qyVk/kpov4+ei3sSILw7ktOH6fm3YCZVJDGHsHRGLnlafSjyPj4QCMQiwZcwsyNNz" ..
	"BGN9YTEfr4x86qtnWFGa3v64gXTevp5uiAmDR/L7DNUtQoiznMcY9TPZBlCdGNGTjv017VyS0U511Hlv8J71N0sLPhL/1SMILMIG" ..
	"uDsG4oxVg2variZiYeGEOFYPkcHKTKZgRx/aX3FfhyWrE2/M1r6/wVkQMw8qkhUXuXvx2CXpe5dqPCjAwwTn95SVN09UvzgJ+MZK" ..
	"OdRb7gjHdvy0zNnzAhNKvHhUfbFwkdAWJX1kHCiju38155vgjVtLteWUQ2mevU7aznp+ZI0S5B/nsYqoptmZzH7Utf3zBlqIsdeG" ..
	"4tBdpfuPUkBSJ1yfFeay6+Ky0oxuaRGXs7FoynqjgqbnSKSnA4BySw820mjvmMDLVOeVKbIZWOi8s/yfoex/tFgEB+EbsXoAcj7O" ..
	"02Achw09RfXetO6AuN6HcPTG+gF011UJ9jeAUEH/eM00us7azX80afiD49PXd2OfY2+8KUY2LVoXca8uPhIq2qZq8nKNRqrPLgkh" ..
	"YaaJ8WbbVbBqKb6lnG0b5agf01/gs4P0w0EgXa0RpXVTs5vu3dMDI1mwPSq6u58t/JwO/eBjDExSJEpPJ0ewAs/FObqhiNmjUfV4" ..
	""
local PAYLOAD_P9 =
	"BSofso/+Hi7hBAWhO7ARNbrev3df2Gc9UbF1QRHKd8oJl2tVg/QOo7yV9kyeBawHNuda5kshVh+SQtg2O+rmcigLrxxML5Ot4KNa" ..
	"KEv/HHczZMg8dkKqyp1N5TYQBIpcH/bXv26HmjAjEhmmI6eFkkgzsb5B695wYy8RlsDDvfVZGIAJ1stV9c9xXNVGGs5rGzeAiK1K" ..
	"b1G9Uo3Qy2nW/lw3y7wV91qQ4mNLLct+VXzgwXokmMOGzjPREJTYbNYHkpg410K5PYbvEr9BSjEAp56hIjjiqAfwXQ5c0hYosZXl" ..
	"gGfr85n7Aglf165nwiqzzVWBLBv87mRFCeblIWly0fmTOXRJfNch5kwtFOQJgyFTXdrZvzDrQv1g3GKZKMprc7lO8iJG117PoxYB" ..
	"vdfaFwOQtYxv3FY58zDd604CXWV4s5WJt7fD/Lc9d0AnaH8eeevuM4nwwFnonlzMAtHEk9njjKoQRfEIqRtdEcFXx2yLSVqL0wEK" ..
	"YVa2L3dV/4THS6pyxA06uCS9FXhd04GUMgiVQzpanT5g4A+ejT3VF/MiepzaiYkt3EY6cS4pXppS/Zl7NVCpbn1lQZQ4qOFS28Lt" ..
	"PsZB1QOhgLQVFnYH4vPbZ9f9itBu+KYgpZzDJNkcaE1plrum+7NQqkcO1ReHDqdOVHihbpLyTKnbAX+YvGoKdS8wableyi+uR6cn" ..
	"NUgRpo9Ok1vviexZhbd4YSbIag3x25usxyYIrR4vr3vwcE7Ov1a5pbbsTin+4ik4CCXXRG35rWzjTgem2ClVpbAysfwiStPNcPlF" ..
	"zxvGlo0yy6Zjhik0cGh96+Oh+PExPFNMmwMRwphcLgTElVuQQjwsi70e3uZavVv60KfKyubmvlsS1z47uh3a27ZXQy213jfsh2bX" ..
	"DtKle8bV+8efPwMDn/XA2RqBoQQykDHf4EQNUOO89a0j2KUyXzVQ83ushfSkFLGVQxRmdxfgck8/y5dABrVEJm/grOTfDr8GG3/N" ..
	"Mc5jp7Xfw3KbksIGYEfy/7hxY239ockvgvPiFrnCpydsufISLpTUo/Pvh27noHyD3hiDep3Ksqigil24q320TUaykxwFIsLrSFuV" ..
	"Nxq7gn1mxS48YC4YnbN+YM199UMBOe/kqTT3B2+SRBWkJ38sMdEo8TirLPdIgvQsq8iEKZiAZn5PK/qpctskM6/tP7w9Bi+a7ixI" ..
	"cp0VjKKhhtpFjdt+gMVQ59ibCl6973YFaAmeNMCg0pnLuREryVpp/q5eVZbG4NSxJOA6m7Y4+xfspDw4e7gxOnj1Ilmzv5x7EP9y" ..
	"cPCUM+1pGYMNAiEOwQahMDzZX8TJJwIYCSUoRUZ855yjqfVBhYjvEO0DojV0IXuQoA7wU1NdHe+ncqEXyFeCIXFI1oQxEhMMH0ts" ..
	"MxKpYfr4kAUZ3h/2hM9dNdwGa8MixG5xXy0KzN9anlgKh4P8RMdk/U8Fx8zPjQ2XWuvxf3B5t2WJJKp3cjqePKVtHWqe5H6MnZLb" ..
	"i+dpj6knmSpyoAlT8tljdllC71OiMSe1GQlu03SK/ArC7xNJdXWAIeIOyHSgw6lyLZXEsWOnnW5V/uJsHzJgcDVbzICJ7HiV2wKG" ..
	"dZJfHzUenpywiuHgers04i7dnGdn1viaYfQr9buojWlH5hFbraQhysV0KbWtRktE8ocFdD3wQ67mMohfoZ5R8xazQjiR1reameWQ" ..
	"GEnm97L74AfSw5MO3oUBeltuYaedKRDvXbUOZOkjm0dJ+rTvUq31yGoZ50Tmdl0dGqLpcHziJuVMjkrW46XH9QqGCAC0m3LTbDux" ..
	"Fyztiske4zIYnDENO9MnytO2SmsDVNYjihKYzlesqBoi+C79IK/BIrWd6VXwmtxrfO0WAIj65vMnu87bxX0JWw+SMyMs32u+9sR3" ..
	"MEuS0WMWaABFWon7HQDAl3LAg8SQF7NNKU+cy9q9pFmOiksoAU/Iy+oC0GSTqdxUuy27MnUEz79TTaId6bnChyvqSybX6lhBvb0i" ..
	"SJOV8eLVU4ABljcK7FtU8ExeHdVhs6czuEDG+c5dTz8bAWE91YsF2VgrXARsTeYZzb2Ent952sE+AWY1lkY3pbt9R5KNBSonxIxa" ..
	"2ar3sdGUbnkkBCTxSx5s/ZlmHOhDkTBzJ5MWzBEklDw17t6ZEirLFeKjpG0YEJ/JWV9GWXzPLm3GP6eDdB0dOdU1LlsLasqp411H" ..
	"zXAjzZGgjZxpFJ9NuoQ76nqzv/8POf9Z7XzgeFSJcq0zWakFsZ2Coh70z1P2sf6Kw5YcAfKVkVbzyX9YbsiqvZvoFP6xSpvgs+zl" ..
	"8p97yI8bLuwY9Y8PI9htLqpfLDyHfINH+5MaqTj+gTPfVt+wZEoP6FKw7pgYDqATRN3/mEhKsKFKb7RK0Hm2VSSLFAe+figqJ147" ..
	"wjT5KuQNTJ5/6HQ/P1UsfAxWh7uo9ms8ZNVWdr38Fagnsn804uvRAfpzpZ2NdvYpt3C/J+Y6NW7E+g4JB+9G18fv7MpuEEEfxAQN" ..
	"acBHb5rwaaO8Byr9audoOEe9dvcjNMRXXAaxiHifzdWlRI14nm6rvxN3gRwn5Ga3E89SqKn8mzrrH76iR4iJ9bA90RurmaAwpTZf" ..
	"/DglQSv32LHOcxtmwu8lHHwYTFMOA/ELCspdZBaEtn93MyMfY56/iROuXid8pjE6V9mH0pZfY9Emu9UQrmjaG/0Xmw9806PY05xm" ..
	"iCNhnm0EvckuhYTEaFnM9ABBD97dlFVqK0KlTgI+wxg+yBnk1pH99d1uDZNK0Gjgl08A0sSlsN2rzw7cACxf9uApWD1/XVEimQ9Q" ..
	"4UtRZTU+wMu9F5x3Yy4jg/Vet93q1Nnn+fnjks+l5MjMlZRnIJyIm0n1Px+86xJiOrsQEFZXUYA4SfrHyS6XfS0elDs7yfWEgnvr" ..
	"ejmo/VKPYmQvMSTW/KAJFPvAj0arViyaxY6JHPfn7siM5je2jcdlKFniwyBZTBnOdi/KugOAQC+B3ZWYBkvPVVlACt+ng2XMj6dv" ..
	"+9HopyyoTIptcBVfurupMfX6PLBa4YF/YicN7N9rjQuVScYbtlTP9IzSmjXS1lUDYyGMp+vSCX/fbblOjzM0se0Ye4CUCI3nELXr" ..
	"3gsbsZ4mnFpwrxqxglJAPilTK0Fg+cPyUG6RWFtNicsIdiVoWh+Cr59gI3yb4VB5/wQcq16JHUOW5HLTWt5q4v1/dtvfv2yOTsae" ..
	"EhGsAEcV+Z7VnbxuhoyANt1vQl+UqVbrBvFVEDkjzxb8j0zqggAfmV+hSBC/aixSODWkAiRKsDHFum8ZQe3Oyrch/in26rkdqbzx" ..
	"0VPYbDXkb1dkKAgLeo7u9tZUU2zKsG0RKejC4jNWQxCSXCR5up5oeTjy2GtQwZJQHylctTzhbzHSDK98bbxpwnOMCI9X3tokq1I5" ..
	"2HW/8IXTGxmoyucgha4EA3VqHvhsOGJwsygQaKAa98xK4ItUdMnaJkABb7Lm+9HSALF9md1p32hAGyIebnPZg0miHXyOXXSRl3mg" ..
	"NpsELe2KIXOAsaLqUQf6i3SJRPno4h5bPOlRjiMt/8dSAOgZm0crO3eQeGXXSB1vTTB7aji+/Hkt3qx95PDjq2EA508TxCWUt4bs" ..
	"VVOiFlZ+Pz4FgmFUtdSEC9DCi5TtH+ltFKi7rX0cjGxEkAEKzUTII3KC8s14RN+dLFuY3ikovBkNft2qSrr1znsa9OKGrGahsdsD" ..
	"kE8ppFzJAn5tJfN2vVV1HNnpun/M7PUsAdI4wsErgc61ccWUvWiBXdIsxvS2+zoqObZnOOgbrghkFh6aWJqCmmi9fcUPuAuQyaiV" ..
	"R08JxLO+IdY2zGVM8pjZuTFcZs9fNwT9Ve+jHqS5qVb+AK/y0rS5MVYEzggu2ngy89qUqCQM6SxVZcgxMJHW7y67RwGXYczglDxx" ..
	"rkKy/NIuQFX3TZB7oM5IxvOqPA5ea2yhvZ9Y7BwmVx9Z5Zp6yW9KhZsb9AN/ToOQ2mXDyogywQSTKLDDBBhaAQ4lbfwYiEiRlNe5" ..
	"GUKCEtKt/rZXZlE1rjT/5dlgp5YNiw/jnr4Eittmic7EIvfPBruTPfZDnh9RvE4QfY+WwiUi6SIYu1iC0BSnzaUtR9bAF7IC41w2" ..
	"XKIi+iagg0Bve0D22bie289/J6TQdFg23TPatQj27t02F3VT2dNIOL5QOAnjaAE/mbwvy0Na1gIFUrL6nBAucKBEYAOxuz81DKc+" ..
	"y91nlyqrD5UlcfTCL5FqdgsvWehb4++cy2PWK576yPjxDJvIkAfybO9XmpJADchSKBqkUQnTwZPyZknYkjm4E81VX0eVprbZGDi5" ..
	"HYycVN1vwl/CvpsKKd5mEDlIVhrM3jsc9jR+VkDOHl90GQkz0Rxz6HXTxjJpkzk9gq35PxOpcfmwpxGDeyRyOS7bfG1vi+v1sxoz" ..
	"DSz40SAOT+0G0phC04ApoRxDJV2aiwpSR4UGMGqMDYlH+18kK9f41neUEa9sqyNXEN/1on6G1kUq9x8SlE+DaoBTuF8xeR7JhtcI" ..
	"8Iq+eMhjcGcwL2snIYUzYeePZO96TBmnxExSXJDmwbf2o3WZuQvh1Gr2eZ9AfCzWGHHLIE4b/tHwjcbMCbOmj/8qFKbtEw1InQGW" ..
	"3HhaKnPeIiLLPG5DcwGAyBf/TFJuLZ0T4FhJQAc2acRDbv/lYUswU15lB1zJtxIORUA56XGJXsTaBaFRe1bltC1qVL2bAK9yFSc3" ..
	"rfYOyMAnEG3mv5f0euwdDEKQG5hrQaamO+sKAz3MPCQpXDOR75UMnSjPPTGj37y9vslI4vMJyqA6q3usE7kU8xZUE7J2iXxdpZhD" ..
	"iVTGW+Fgl78IKEIsUMG2MAmYLwUdXxTQ5S1a1HEilpBFtuL5NKFdLydvfNsgH2mqQ1n+te2exa1NurXxSSgrtP+u0XwiH/qmscUg" ..
	"PNq0fIjMYmykpGmLUmbGup1XXCoUUa5BFxWHm4vWJ0yuIdITWJnV2OIdGN958pIeC6uzIcgETVVnOTOHuXI2iEv29usQOpgbgcK5" ..
	"q30+sftTyoCldX5AlppRAlvz3Whyw618BOqgZA8zv4PkTjMKC5HOJ7+bsRKYqmGp4zVtXKAHd+UlLKlE1CGAUKs6OEfLcU0YUGJp" ..
	"8lY/Qyz6TjMCGblQnTFTZlGASLH4rpvY3Fqrz/iB5jqTYePgu7hQHVD21S//2xiHXI7DTV9sWoVWH8BXcXyrNSWajj7iQ2AAi9wZ" ..
	"AXwQi0cDZczG3v5kh3CBKZBR4e1m2FRr+1Dl/sUxRf/HSBYUhxy2uPsr2hb/riQflIqbMkflGNVce4cRq9zQe/zum+gAINVMUhGV" ..
	"SFl8loTqyJEl5okXy135zuf0fMzgEMA0DO3wZVLCrPbLrrsdgeAu+hrdq1q3ot3l17f9/tzVsTSDFLiNRp1/mYlojRB88sRvIrO/" ..
	"ZWKQU3HAzT1owPb0QvIeRtgFffEhO8xVAu8F+AGaIt/PN6R84s2C/jqqrt9axigkq01H0EBeK/MgvXAnTiHw6BZL23cF1/RyPtoS" ..
	"LEf45kB3gUeBBbu8Mw7d+va21z4vZ4abY7U8wOYI6fKq0M7Y5pn1vFBj4MtEWUPkOsWvZfyPMTVeVwLBv0lk4OfD/MNi2bI0jANz" ..
	"KEdK1huFzusfMfNGaUNNXgtZA+PfdTe2JTt1BS+rWKr/IfCR8QTFznBsEF/zEcTQLOej8R4G9MOx44d3Sl66quKwltK0/ZiRbDGY" ..
	"FbCclRmeTbxSKwNvcT8Aa6JsSfNrIbBt/QUFzj4Vq0G74FOb6zggoTmGgSZXO8IYFYX0U76pivNUohc7ryzFbeLs5COxk1enY5FA" ..
	"YPEOnmOjXwSXkOcL/9WwGheYt0i4DBlrPULwKQOL68LHF7MQ32ijS+fkPpSH2SGXML4mEaGCk6BYLYpcoG8l8tWFublW/TA4kduq" ..
	"Zow7eMcs3DB7szedBhKQMgxAzExXqri/pUVIncFgF+azrmg+yBdYRX2Rfkcr0wcw8wFX1/JDGTq/P/Bm0DVTHZiMf4Acg2NYWJkv" ..
	""
local PAYLOAD_P10 =
	"GNuSXjJvNv6egwNS6cWr1pX+p7rSqwNlUjsnb10j45R2ZheF9JnR8wttTgT8kYGtcVCwnUtOd2iJDRwcMs+JB7Avr6itBNjAL+9W" ..
	"K3F8UqJKyCK600Qtd0qx5raDu9qqNylKMx8MjrfL5ag6Cvi1xmrplb6w06n1ygcS920/H4so7yBL6bZiyp0XHN9G7kskl413LUbo" ..
	"Yr1bxf67uJ+pMGttDK6Q+N8FXUodmLAdT+R3vbO5pjt3Cw7e1Xb2Pe+NdXJ6sjkaSdxfzYMOkHc62xlgwSbJmfCulrmkZ7Rh1sTE" ..
	"m27k4Skzkalxf/kHV/VszAudS8IluVycJUJKS83FTA1i9NkP2GNcXCgCHb2FyYRs/Xop9xZM0xsuhApGH5K1VywapRHRrB5JcDXG" ..
	"Ya+W8HKsgxjchIJVSQUEuia+7YWY8uUoNtq6MLi9aLURTKGsQzlMm49KG5GfkXGaqTB8h7IcS1gtcUvBpE7iqEHevRbjiUsS7jfE" ..
	"t2SZSf/CidpHJXgDCI3sK72XfdUtqDjM8S7Pd7rCDjwvYnVoG4A0pUeyJAbtbnS5TSMFxuKAPGsYgfs7aC8QkbXN0h5lIqEXGO2M" ..
	"wXHo4bsY0Zjcun8ZgnjAm0+IUcCcrm4c+X2sAC9y6XruvnfnRM70cU3gzL0MVdDKHU5pWUsiazWP/rmZ76UQaZvjofz7fxTHC75u" ..
	"PYnZsg7T3vMbG906ORBs1DBJk+bVC6YgLhsNsM4q1kaiQUxrJVM7F5j8yBfmnOmnEbSOxdeD7hXbiqW99HmsV41d/4nxPFJ/LBz9" ..
	"iDpMFH6xwE3NuaqfOvGUjaCyHYYg2s0rfFLsWJBP3816vYYMV1M2nAwVp/yr04YB7NUztvMS6xPBFnYZMjD2VkuVDMvyYa4oiA9K" ..
	"mtrOI1qZ0/y9w4gOnbA7JH21AHftR9Jyo4+ElbFP7pM4Lc6CUuUxF07QpSWV2opjaevPQH4nLb91eWWFbDN+b2v73gHzJpVvmxKr" ..
	"GD1zumqH3+BuJtOhZqpx/BUOznw3QeP7JlLirYjzpHFW3u0o9M2N9ir/EnbWu9Y+bV7ZNkvyOxW1y4utrs4eMc9lPNJK88klP8mR" ..
	"8+NB/Je40f0vO2myKW2OSZ8BJNrB4pQ2dxuqhGzr1xIggSIWbNfuF+9Zvc1k5gImxMxy6RpZkm4ZBDXDX5SQXsjMBhlxRFEoz6JM" ..
	"5MjKvU5HVfOP1T1/GG/T/ViajaIEWEJscXggWwUbFuv+7zlJUHX+1OPIRdEIP076age4t3xpnuPgW52gAToSMi5ev/XeOCPGzNPh" ..
	"cbEcodYX206GcO1K85Rq5vKB1yATWIQTkAqv2WczAwgATG5ca4k2GObnbnEr9jVOuPJKcl+gWqr9fTYRfWrevZRZ1OwiqPR34W1x" ..
	"YH/4lxoVVYgKrC8NFSmo8ChgEcyzKzwPQpAY7YM+Icm+wz97OPsf55dnWHzA5Te2nQFoVaxA8g4g3hKYoof7FcUFslSSVNfMOI1Q" ..
	"BotPhxhSTG62faHX5I6JTyFR0d/bq+pa6f2tDXNEK0SQBBQWjkLS4q5An1RdIHuit1RMv3iEtDnfiTeIsR0M0ocZc1Jd9tBcaHgl" ..
	"eIsqSlD6e8oyh/ni31xn4mW+/sz15t8S8erUNyE10KGBMt0b9X7SxwPuHL1U+nK7ZJlNCOu5dnqiJ2Rc9WVeO+IJ4KQEkoWaLRE4" ..
	"qk8nxDD5PjHGTQlnMw8iel9OzYVyXL8s7I8P/HwIKlyBl9JGgdLoYS/ScXZDWsfdffVm0hMABW1sgxlKii9/Xv79olv8FblpPOrl" ..
	"AhmlkrhMsx7/j2lWRd6+uvfcNPy8Z4NOIB1PmXGxfp2YysGRCDwnBKRpcgxSSQA0OVUbWARJCw4+KOpGyeXrgo7af7VstslOcCwY" ..
	"NDOzRb/eOI1auZi4WHYFrwHxUOpsXbnYZe8Zs07Sx9dhFyCtq+GbIdSMdq/Pylb/rw56JQbkDTUEQWge4ApuD9uvbnpycz8dzz20" ..
	"tRFtni1ayx6WnMNJA5EFfsHbgxXDap4Yejr8cW8pM7NloMY9Pt6HM3ne9m0uyS89PjppXk6SiD7KesJ6Xa/QgNpkjTPfLnSelNeG" ..
	"/Ssgcqqn5l5WPpsMGnkEOOpOhhZPsOtHzPKRpyMZSBZr18wh5YlFj3I6uyefE3Tl9SKMRQrIl83Xw5OTjjJ/57Z7wygaWnPPYv+z" ..
	"q706xLWG3eMwVf/BdWMimcdWxX+7+LU4BSRNrBRibLAbnNy2qhmduBb9S9G2m6hUxP6I8mTKJSDK1QJNN2cS5pI3LYyOr89pxZze" ..
	"huZJDLkSovww/fLNQzdK6u/MzthPG213UDYX86B06nseAD2A+RbqRYlrUlzGLRF6kwBBNMDmasw3ud222+woY/PLuM2+WRZLpMYS" ..
	"hz5go94/9we7LYRBhUAZjvokKktgtv1zBhbG4YJXsEIozhc1Y1wjNIbwp74Y4mh8N+Yftp9KZUVXVqyctnZjr3Af0KjHc9gEuWGa" ..
	"eYs37ugbtyBceBrqKtx7Fk1BOzRCFtRNyQblDhULQS/4N2rVAyGAPl8o2bkV6RHxKip/u5yCwG7Lvg+VRVjj6UICkZGUCK9m0yXo" ..
	"+3OFbOCKw+oewgNxAC3VvSr0y6qd++h5RpM7uvl0QZ8YuA5zcVswaAa7sY3mJZbLPjiVEggSC1zqVsTyy8S7eIbi+CHUN+1yuwVu" ..
	"uOm2Q4/QQHSON60tYhNcSrME90QXJqaRIVip77zItSYnNIQHp1g6gq9MQ80Eb/WvCqQqhJNqaJVeCl2AOufSrOaAWcUe/LTAGxmP" ..
	"V/NiAo0s4T1BXbs6DWiYNtEh0yZAdS1hyfiHjG2NAwdAYEABF0LuCUdlpruWyK3DFU9SfUSJ/O0ueLM8bxYR7+MPPjqHfMZLQrWM" ..
	"UDFmtC1IPq8jZfLT1+yCFP2vvTr8Tk7xKAyXZzPeu49jmp9PIeA9QIbsmpuhp98RLB/9Rs1/KR7/QIU7XtJ+tBRJQ4x+QBr1JOZe" ..
	"mtNG24sl31e4DbMyK5WroFUi7pQuVVEmexU/AJy0UtV3j34DlHc+AShlp+dgr6xU51qzE/dpzaE5o8QgKppEc+IAvy3YrmvjIBox" ..
	"VDkrMhMTap/ZPyE6YqWjbtNPb0LH7qFcYJJ05gx/i9T+8piIIGUOnPRoxqhRYeVUfR+Oj6udXiWGGal3bHERL12YbIWbX2EO0fOf" ..
	"iSYnJp+0ifA0gy3ZcabMJRz2aqmQypRRmk3dJ6CZNLNPrHYnUGTxxU+Csof2DEtnl18+i3j/7Rdh82DHW+c4lgi+kxCnQrg0UM6D" ..
	"bF1RR/r0bj01cUrHABhhPOABENgz/LvxVer20PFJXhp4GFW7VZ1XatormgGvUdduhAZZKvSHPxrJZT+FlWtSWErTKTBCTCO0IHpX" ..
	"Y2TZnhaS2s3wzfsPWogLZxSqzQA+PCih9oZcp8st/rV6zd3q0KXVwigwtQOa58iThrAi8Cgv59wjA8DN66VYVG39ZsYOUAyscGoS" ..
	"T6xBVUMAPGYyDvS70tUSxP/DlEpcjni0JHw+FZ1xbVooPbG+hTkUKIsn46uS6ArvXsyILL/5/o99DkzpgjRQ5OpUNXadHG37R6Un" ..
	"Pk9onnqcxI6VjNMD6gv+ook1VH7aICZiJWB0AixtutyG8XuHJphlZnuVL1PFZP7f2YU7BTrvHkGHN3eaTKcA+VMk79ofAdY3Udre" ..
	"U7B9HDpVU8zfZ8S2tGli8elYweUaOuhoxkKd12SO1CmjJcfX7Tcxsh234FP/Pl7JwhzMeeTfeoFeBTPiKN2ZxM7q9nDfQWVEykLH" ..
	"824kdKsCjoID2LoMFcH1ck8a0g9fpMtZAHBvbo+jx1vy1ixT85++PxGxo9b1WdxahB2yY6MF4T2+YuvfMIT20nszWzn+uCr/3YbD" ..
	"J892Ih14TBMRzacVM1iaeeBOYxMRrU+QByTLhBPoZa/wJfjAw+teJfK00Ctyf6pqQj2MKYjseGO3rhuaWY62f1VIF5a6w/yJIq0w" ..
	"KZJ9PWftENwOcUaOyD8gajKfooZ5N0f+WjPnCEeW6CQkS8CnnqoLN6VJdJG+XVKCu23TZTsuTjnFHyBI95JrexnVIgqHwYjKg/pO" ..
	"lhIX0Z1p7ZC8AL/XFi4B+Nw/lBNXCeoLuc4S0LfKTaEqXXB3WCzdrnUQRalmEsSSDlvWKsbRzr9G/9nVEkr3O1dhuPy9/2FfZBi3" ..
	"nut0pWmMDZI2sEqJxg8y5nVkaLWXwKoGRMruJMBnKMe1Gt1ldw6n2R8NysYixTAJ8uMRKSdMoeBJsr0cY5HPB/ddRMLVX77HA1ec" ..
	"qQ9WOKVkzvA8tQPiCcVS+vU8yCLTUTB9KpzBSYanc8gR8datHACyOt6mHqWT27rlMbgYghLjSLUIcvplPkTr2ianHcq33TyOFzgZ" ..
	"316KmTkep9jUVNf6TG42M6xPmL30uhgN7f6N3UBLxvWo47CQiZaQ9jEkyQ+nZdTGWf9hOptp/4KQyQLyenoGjWA+ax3F9hajXlP+" ..
	"T4ZVIDUkRbFwhXq2fD98WZHhjbcnPdb7hPCRsWtO7udLLj4rA5v45hjomFvj+z8eMH9dj7UROmBEHmns2WPk5zhbL9T35HoIeF8Z" ..
	"RiVHE5iuLjpS6Usxn4XpKw8bjVwodvPdSQSL4o+JBzKcCGj697U2+vSai3pJ+g4xGnqKi5G3MK0bTT/kEZ3wVQt9/E+RKD3nkNLX" ..
	"u9ywRbvf5d+F0afw0fiyT8bxxdBgSVqFBZYFp1jjeLnqaejfcgJaMRPS2w0EqdVBKJqPWbjR3dOP7BFqka7UHpC2DahNNb8PqbZ6" ..
	"uVgoPbrAl2e6A17F7FWAKVmAzLVKcLbf3D/RUUSaVihsvzQcBzakworUhHDe0TbtaAjQqiWR/uJ84SpFjsp8DlM2qRwWR31SRlS6" ..
	"iWGYOzfuCrgxDFRsKMW1GbYHBcvUxYW2BfPBttx1Ic6uGoIgZjtvi99qcUjcbIfY9oy+Pa8d5ws8yXybQ00wkXZhE7O3aJ7XGM4G" ..
	"WEGVEZJAghAfgAD6GUdTAdeMev0ArHjM+q8JUZx+7d/GvYz8FYicyWWIwObM7Z7GVB/RZV+p7g5Lrg0Y5W8R2eESxRJAp+zZXvDy" ..
	"1S6UbaSslLrP/rHOmf2W6/fbgneJgLz4Mabhd6KORJpVk/YAvsCr92PC5Yghk6yjeKAtLOqgImk49DO++v9x6MYJ/BeX/id8PftZ" ..
	"VL8O9yiyahH4sDLF9T7tOACfUwB/oHdvv7v/KVHchzcLBX00ql6cZy7dG2fh5nDS3xaIsCTHRgMQ9qYzz1A6V2uNhTgq00tQv+1p" ..
	"5PGeuXKevIf5mOK62MzA2l1UOV3O98lbqjEi89yOz9vC9wjh/yGS72Cn5avftf6GYgPO0U+LCgGg0HwKgX8hvJslHwUywlw8kIPt" ..
	"TzC/KgMO/UDab5AOsSKzQ9A5tDbueX4epfXFG9xzp/p8UA/vTPLNHQh5R12klTKaAgq6tXtYrjNdmdqcajuZJqM3G5f0hbMExoRR" ..
	"sTzKkKCk3XNSa66Ih8zEaxWfsrU1QaNN1UvxksU/KEkrk+BoPzk2mrYhGtM4QlhmCUUt0+JNV38eUd+yn8EA+TIpAwDDyHbmQdrC" ..
	"eEO66dy8DgmBLKKHdULnxQz2ZUJl1apfsexuSWblSfAnUja7MVxiSgPSiZOqLUzbTLNKruFimurqtfU4ITkQSKy6TCt2SLJjq8dc" ..
	"C0YWIQnVoEH37e78oSpIAIlstNv8lQkqDwps50VlrgFlH2fWLBGKm1FGmuea7Gr9ti3c6Dv9qTfam715kJNpAb899yBdMvHbzFKe" ..
	"M3oZfxMXUdeNfLalw0K8jFQNKISqkEwtAKb2HcUCsD7XTszD0At0e1SjQk9Mw3KUeHhGzNuClGLU/SQwUiOXgk/13ATM8obDe27w" ..
	"XQasQ7BXqBFegwlnvaNaRc1tyD39WMhiYr5RDBlB8doPF0qQ2rpdRz3ZLnInH4LlTT1LrmUchUpv9H1crdZ/cByiS/1nrnL68QwA" ..
	""
local PAYLOAD_P11 =
	"iGNzn2z2CUTS0O1HQqy2CJCi96oXRhl7cBOJ+YVsyD03AFwTQ10goQIxDlEtjHXcVXHjs2jxfQSYUfmZxzkdwgmBf86AveXC8ESi" ..
	"0nRiARqrLa5mAXFJ52mzCIOTg1mzVYQ6wo8AT+FHsZGH9XMpRTE8F85kQpwWbWt9M8xtIDtPpc0eZ9qHwS8x5zpki+ldHeJ7lFTq" ..
	"9YWFqw1Z8Kpev6RrYsctxY6rglOgPk4ZzIu/2mjUPEqyhR8ptRr626jKPjEjawcXEtsFa75ZIa++ihY4ksnP6rD4afA8UtUsZlws" ..
	"WKaWBQGDb7twe/NpkyUiIg6qHP0ZT0XoggmESQNLS5JTQH97RdkJ+4+AIeeaHzCPEtvnF+nHE2+79G28cPqodxObj6puzObdvqj+" ..
	"G9VZ8j8RiiXIsJnDk3awiDziUtZqq5MQaiYeoDwO18/GEWcCTmjVoMAJteVyd7BI+j0ZYLX6UJfbWBI3MXi/vIrCEzJh87Eyi86M" ..
	"049HG/eLxsFJ7G4bpH6ySiBykDmThXYGQyncYW2C3tz0nHD7zU/vqpuA8HXvLtmX9wS72P0qkurQ6LPYbltZIIn0jo+9WDNZqZQk" ..
	"J/7FnfwPYRuB5XXbUdDkU42Tfia6fUCMpGOhApBhNpPSo42d5YgA1F0WpzOuefDm3Sl85c8F5GYA5iXCWQ808bz/VL8fJmBh0E3m" ..
	"9e23XrA1ql4zuXkRYPY9O9eedFTfDZ7Ritj/fL6pZsS1GC+VXXGVqH4OXkgnuzNFu2oDQBuYdOXXKUlI3MzW1IP5aPp01oN83oUL" ..
	"JsVXtxDXOPYupfepQSgusXcCo84+5ls30d9w92VDOvmIE38bQXhyxnilohyQbU8+4bJBEhuml72Ajf2GQ4lX2vUBq7QV0kb5kJID" ..
	"FXOBrYx2nH37lugsblRSg9/n9htpzVeDjMMWw8B65Enm8uu0HO1LHBD0GSQ2z6Iy7VVWVZYPhe/BixeRHCZrDLQEK94HphIbvRhP" ..
	"BVA6IhFJNcT5U9bNVaU596v2RjxELxpLmN6TDHSbyBY5AWhtE20ERoCSKy/WPbgYmDuSYi+LJFlxOeBifIhZRRCyyG5xAJ/DZk03" ..
	"UwNLIA/f4kZrgNXHIN9p6RmxWN3fFBNUs9NZm6RwfJFdbGoD8EJhgQuP4jgxmM7zl9wCr47iNRGkHXJNmWuSrZvX755fGAF70JmV" ..
	"HdFwSywepimY82eWl1yz3HYN0iO545KgzKNmlIa9KcXPZFkGWInzc1YvCPKGifjuGdkzUwLX9LW8IFKdgoQG01GJl2fzGPVF1VvS" ..
	"twu3pdCNV8AlcU/aCiXStFcF65Nyd1D7Vnv2b+0G5omLY27COWr14CMjcViRx20Zmgj2J3Qy63i7FqCt+Pc7DKA6Z4QV4s0rhwyW" ..
	"aC/KUgAx9Mg5NczAf1XznriC3/LstzRRylUA/9RNaaM3SuGC4ZBtP2GvRmEzyg04IFl9gNIsUe0i5S6Ru+k68ogvs87Cm0Wn8mo0" ..
	"6oIgqE7W7l+0K52TcdIJch004eRcnAKf6B/BPWI4bh5imJB5HYbx4SKS3P40siHX+1wBL1KsfFbTi8YcDQHN0dVFszAf2zEEcKCN" ..
	"3Wz4/yQ23I31AUPt3XijRn2aYKiWBkI388GVUmwKgG834nn1pZRNbIK4YGwY7CzsSNayNRPPTMC63myFR1kb6YNYAsWHFm+E729v" ..
	"SMcRXiwqU/sq8SgFFaHUQKUb0xRu4rxL6wm48x8bTFtoR+nYjQIQfi+xoYxaF9/Iwy6EPkQChK8RehD6L1MilgD6naGmcdHiRuFH" ..
	"c2GKJPfQTaWz9zaLvM5QHZsZz5lxA3VLxJvaY0lwaDByhuJ4A1s+eusTe3hSOnPk3ezGAdmXpF50Q6tvjZ+80yg6gug27N3hOFiC" ..
	"EK7h7Iwpu5rOTxthOgO21PBoglruj4/zE26hUM6bfE+G8nxCk2f18DlZn+VjBr4K2Ayus72rDj2pTyK2iwDjidxSml1pqL8AqdNS" ..
	"JGCVSqiEo10LMEuMleUk0b3RN8dB5aF84ynXbp22eJvy65zpQnprr/XZdIzHe7MFICfVAJDg+gJe+XUIDn+txnEXTblhxlZHJaS7" ..
	"qo+8HYlC1OJwQOtr9QRbebRHZw/ljjIrxc6++534jdIzHBsIonsTBY9exsasMg7h+urDRQEnL4C3NOkUUd/T0Pt80KbKTY2mo+dd" ..
	"vdlOOAZU+LWVWMw7uDPD1sC7uImZ6dbaE7cVQBVjbpBZvNpMxWZlJw9URxIJMoWW5h7XQeovHW3SykQDqgCjNDgRyptaQJLnTYQT" ..
	"3v4eHzSykjmijfXiLbxCpHdF17JrqJQ/G9QE3ovYoawg7A7t/GNODGLaW0vTgckGZ1b+pOlfVuDPOWwTip9abA3pujIFBomdT9WL" ..
	"A6POdkb4DxBKpWjUlHyXuAJcgp75wATYpED/oXPFUfXw5MJ4FMK6KLc833KZkce2dApYXB6RTh7cMacOyYyKgbaGW+sRLkHFCat8" ..
	"TFiGd5NnGJuOP2t813bQWGBtC4PIeU7JdHAtQdkQBxHaqFr2CYFxU6Ru539Zr4kF3oKWcmw9zwEt6Les9bk30hKnzagDmctfFUWv" ..
	"NkA+QGNQa9cNJWKqLItW5TJPL6jeHGMbdj91j/UhN9+3113yet12DRB6cuYCEsA/2duC9IujX6D5t3wGouxZ6NBQ9OVLJCwKrywc" ..
	"0STP238OhKC2Y58KqCnbdKVjLJnLRJokGpUj02prdB1LhFg1MadHTrbsKtDz4BPHOsttzPsV1JAxa2RsqbeNUXnEn6WlIctcWJws" ..
	"jB8Rf/GMQwZyqD+PhEE0jELORJD4XCtxNJPwzcCvQjUt1RJIpXATJ0oh043PcTtokOTzgNezViksQ+M+qkoY4vvhAby5HTtgmOiH" ..
	"86qDbP2aUs79jB+1XEsz7V4gQ8DsZRVpTC6EJ3SznIz4lvAzeJnaBqnlepYHGw1knB5bYh151ofvLau1HiMpc5TwNAuAT/+85bLv" ..
	"2h516U07oaHzjqGj2c22BDZ/uYFoqWoqKJIDOcGPby3W6lTNIy8hq8NntfFs5xv21zH6HC6v1fKGEGWsQAizVlwtV1WaO62BV2Hx" ..
	"BDEtuul40DTTX7wYnNazMchtQ0ucROklGIST6tKxeg6RdgYphMBimz8JCzScitn+nDrL2MOTvnq292ujL3Rc0fpkjyQdo7w8DA4O" ..
	"PhPkjv0QuxmvBf28p7PUck9JKBVh9EQ/nJXjX6fWy6CWJGgeQeQbVDHmoCjfiNSkcWConxEk/zdxHfQtdYoJBFjDFlXdxayKEZnC" ..
	"WOc83WodHV0+Q74BOzgaBB2yCtoxXQS4guZw2psz3Pddka47uDV5f9znG7J9nbOCOj+CeoWx4fdQx3K2wR126raLxwWEy9+hIxnO" ..
	"gp8n3RZrf1kE4jOyB3MYbnnvISbVsYUP1bdUvph+dYTZGRKm8FKXvA8VG57teDIS36NC8mwW//nsZttWyJYyl+D3A0+BDcVOCTl8" ..
	"9hVhnJX1RBfDRqD7I3T0JTJiDby3I9LtnCrU+czyqQX27Zmd2GlNR5wdHuX6afifmbadPNSY/za3NnS7XkUzCtDkRzvCzCunmmuM" ..
	"PDwDJkCSZGL3LUAjPX/jNpqYv2V1CcqSFnSjY+iVpM6P1qkOjf45HAYj0eHYsVhXWCqdzkv9w9gbC7CldhZ1qxl7XJcCRqis4IGY" ..
	"+GCKrVHgk7usQ91lunC7hWfIqk39ObAAgWZksO+duRnFb5q2D9tN9IbpIzdQaNCv//Wrvx8zKrhMQzr86pC76OrTXbW8FegD+m7U" ..
	"S7GWFOo++bxENPC7/WHqLab2hNHcTBO7hyXZiCkww+5t6f0sUvz9hohc8kXCPw5wPrw=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11

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
