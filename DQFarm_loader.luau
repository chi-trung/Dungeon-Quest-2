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
	{ seed = 2137699647, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2131940649, exp = 0, plan = 0, hwid = {} }
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
	"i+mOZTYK56DvACGugg65/gQ/lw5z73FTsMEiabq5WnfRDAwVHzuWm9Aqpkkm1eOejxtgYoCzLNjcMuTXZOMPnxAakG7Jn3W4GXsc" ..
	"HpBeWyWyZI0PB2YYfN1ZLiP2adFVkK5mss8ACUb7BiTQjEZaMLvAFGU1GhR375R15/nm1+EUNWp66lUZG+ADPe7tbE8xknQ+p6ax" ..
	"TjMgwnC6LVb6wuh4ILtRQ9tP5l89lZ1nRxOFMCJOD3lKuNU9XvlittM6R8yRm4Qqe2885MEqCPOek0Y/x4Zqn3swH4xtgg0HDGuh" ..
	"AkGBV0AKDLYBZVt1ri6FotlCMjaznPA33xFJ/cmkTank890dYFGX2f6utfhcLfg28ao2YhE7u2j5iDNIS9xZt/qpg4gLt63CO0E0" ..
	"vFG9AXLaFe8RYssaKbLiuEsYJPX25sXJ8g8k0hlqM6fw0fdF9vL/omXxnRy9sLQTWO8jTvjjsfsR8YlOeloSzU/EpSCVIHWzdTsh" ..
	"QiphaxYZ7pGKeQ2x1W83ILL4RIZqEThafcfrMuRmFTQfoB+R6F8DFaF8soeXt15bjR9lc0YSTX/FRnB9n7wo28OqIHHirjHgS66Z" ..
	"fmX59Xx1ZrvqtM214qJzPG8aT72N3ujwVm1CnIeqeqRMyXV9jFWBL2BwfbyiU/3pYI+eHTEelNoeuqDmduA+dorXb3QVzhvE3uIQ" ..
	"iBB24VcemAq8PqINRBpOaiDyeOCRzidGwIpKws/NNhZgAkLqX1+i88zn6uuvM325eQwlWq0AAGr7aDitYDiZiMIs/aihiwYmf/Fj" ..
	"LKhmnwV5P9eFkrQdiWKB5uiDbd5zw5QdzWOLiQD79T0era9RI5lBK7HKH/cSHXjVLvKjBCXsoxNKWPUQvms0f+v42MJc/vI/+mIE" ..
	"es2QnoYWF53Deq0T1qgEvq2SQaQsYrhYdlZV7e/+4EJ5zqb2aec/p06kvyzGdIkOgUy9WhUQdK12vCzFcRmAJ7Pt57UFPnFJHPKu" ..
	"y2eVFsdDL7To/aml0RD8Kh+6VfgakXHA4UgTvbpOVdIXCfZcS/Ts/WSUf0sjp4zIsGKlRe3xgn7Kg0k865mjnrP7kj0VSn1nitXE" ..
	"0YT4uraz1keq6jwvdcWGt9ll/sgNPpgfaKZPap8D43HTtJ4/juaD6KOCxj1RXN6PTmPKSMQBCM2jWlGh0AS1lqBDvvE591bSh8lJ" ..
	"x/Ex61wehYWrfd6Y5LkbZ7UmH2ANoYVViYKjPGSsoo+M339OK4G0ztLAkSrCdB6nwgLCdf8+5o+O1vT9vTGViBXbC2PrvA1QyCx6" ..
	"YTUEAw3E8+0BoZWnPFz+/l/ifSG7GUZBMzSdn/kxlH8UnXS8/6iVVvRWD4u9I4LmLoOpSE4bgUHgZdhotbkiJrsjaPfCnBSmuhQ+" ..
	"BimAoTtfKacSHtBxFzTTkQUD2epYDO3C5kHwZxLE6Ka2qg5zsTAcEiP30iLMuqpnsrxUdt5twQ+WFaMSgGo0w9z/MT9aPo1KR388" ..
	"oG6QVN1s+5WeU3A6ZaYdc7vsIP19+22EbErmPkbrPjAQsGkyEsq6qkXsXqQlRXG8+1rFQA6sSyorF5IQYc47iELJ4VDGlHOxyDb7" ..
	"vntNFZFCmr9WjC9by7Gz4gSe7u0zXI1w5zYzEqdjJKSkJeDBw6983ZKBFX+ZOq4GqIUlVwnAGqO5ml7zlruXWEe9HxPINJ3rgfId" ..
	"fvR3TWnkk//Ksg47M8IG2RKCufBhZlfbIjZZ2+/1sBY2pDQiFfV7BQQXoRnjBR0jmM1oc0begst2BZ+452AUqyTHgphSXqElSUTa" ..
	"EgpgM1lCvwkDHohA5dy3cd9o+oJg7fATkoegEizj1H2iITK0Yzwm1Pqju+mZ0gplhubNVSOiHN4O1ka7+qCW+5OHCblOpeTGjLN3" ..
	"EPDprDygigar7jtUVcCn/NdD4oXL4tXEfwCZycjdEgZzYlqaTMeqgVkezQWswxEzNrUf2LIMn2fXVwMP0Yu1xUrfSSGriQCsHzGB" ..
	"Y5eltsVTQJU6GwmsaJ5/M51a3Nv71VqYfzYFVdU0a0cX/LOKYmGC7CSm4t6QqQcBRRv7KzUJ9TQFB43uidxRX5PrmcI/4xZEh3o+" ..
	"pr//QOjZ9kWjP+3MaCOlVBZjkWgrkQE7sL6NWsPxBgyOSHW9HXTvqjW/nWasH/nzKDVZBwkJUjk6kJXGBBHRwOC5XOBi2gIAKPW+" ..
	"upWW5ph42eCaK82GDuTCyFHB7f3iQN3bCVJJceOVMn8XFFJ71zgZc+uzWuVeUKL4OfVNGyvDCq8Y48R++OKQhvAW2jcx+/4pUI36" ..
	"rBymrFenPf/FA80vJ2GQfJRxDaf1ke/lxiauFIelEcGLiQFPEza947G9qTBBByCPN+21Z84W39EjG6F3VYgmvcT/mBkRR/DzZ2eh" ..
	"fEX70NNhv5UpTYsswf45nd4/O/aPlVQ+zBBi6g72q8ORkpeqR5PhdSS8QINMNdaIoFaw0b54OEdHFhUlUCHNvGg+6C10vJ6PrCkR" ..
	"foxAcLnlNSEoXkcxT0u7gaYiUqFkDdXA7eSrfbFnHQuEoWK4CWysDm/9h3X6jDuP+rj642loUV/jEJm2NM+X7cFNlCaCmk6uRkxs" ..
	"Oj7TTdBut4zmpycCkiwhMyDaIQq0CZ/7dbFksIyUMuMRxAIoBmhttxDM2F2DswwqDpvULnI+V78Mb7EdPDafM7EIIKNuW+vUrq9G" ..
	"f9GSzv5VCo/4PlSxMjXxk57bKOS+8q+4uIj6PL7kyDdjeVnxiNfiQ7aHgGUVORaartT9wy4G/4u22qWYVOCTUihnc4JuostuBYwi" ..
	"+JcR3cBdRX4ENdM3g3hKy8562tcH2WS/ugub/6ynod6RqnQG7SOMbYij6n9NvEEngUe3Vq468hLPMPnzdAS8Br8gwWU4AwDXWf3S" ..
	"VST3k6Z4Pbl9bsMuab9odnXtO95EcRaPa+kse4EIXbJ51x07BAN7/km77fbuErBHuHaXvCNROEuyNTu5zA8bS/Fj44HOTKUUD+Ev" ..
	"PLg+t/uBGBUZQM6sviMeUZ3sMmtiu0BkS9af5p6ncFIEFvZ4P6JU25grzDUBq6qXI7ZzjGzwpJR87/8qDIH7XuHbD10ISSTLMqav" ..
	"vWmR5+TEskT48sjSL74ZleO6OIpTIoaBJ3/YYJsN7opx2S7BIgxBklVnUQ4c9OAjXrbve/KhYeNZOzfxHTjKDdeaKGlF0UQmYGQM" ..
	"dAnLkmaRdsdVBNmFgcgen6UwtgupJo05zxB/4rdGLfyNy9Ea782vsNrzNd4UOxRl61ycMeZK83sa01O0g34FQeoKMThVm2kgkzw6" ..
	"tOk7mLsTDgxQilvwxUT2B1vVRyhkDvy5Zbrh/Z1F6HAEDncEe3aM3ER8LRbr+cbFf4R+JstGvUy9/PhMPNeMBqgo5HxiOUkdg2g0" ..
	"/JQdleFtYo6znN787RL/NSSDVQokQjHU6RGnDYLKQKVpzvvb1AEUC5vcbRQ3OgwdOUzVrVBaVhH90Z4EUfqgXs7mkzjpSKqRUwOH" ..
	"0w/eEbvgztLjqu9pnGMxm3vsxZFaVck0/IaoYSqREcQIjm898murE0iqFf7tysvsai8W637Wl0Ko2UcQVlTG0RkHc2bRJsv/LGUf" ..
	"rY5IdSsSVvrjpO7yjRjeyUFSiqkPv6BvnIsdmkyRtsxkp3BIS3kXQgZwIkTqN80i/csNpGNLk6Yto5g/55sWwfjkrZ0mwHDWcUUX" ..
	"CU/Ph133O074owss0Vv9r9CcWwgIYTmxwP7T/G3C9cpKWq8xgq2raRffBF903cwZUjy3G49jwz2tUm+HIDVB8R251SjB5sWN1cpA" ..
	"BxM2x43O8mqhwj7nM4TbSfJB0j06o9eqrYuAcBHQsGGjDDChKTcC3rOcwS1wD+dYkgrP31ON7C2Y3RUpiujYyQzy3BasnIbOPyv6" ..
	"tUjIPN7hiKfJr3pK0SPV6k7Ul6tYDTf9b9XoTnYyxNUfNZvH7DsGwwQkB+fZEYyrOp14mA1TIrMEjzt3zDaGFTLl1Rg0vCeh/yJj" ..
	"4qut72HDS6V4PY2TjhU5jar/li909kPvwo4nokR6ASGHhSfRUeaFYFigugIf+2s+jGZJW0lR+lUnuGh7P/Ri3qYwdNh9pn8J11e0" ..
	"WeoxdYwrANHZDZvBWV6b6uX8k2HU63s25TisCiutT+tZVCaDtMGYkLn3+z/AsuA42eLQ78l12YGT4dfPFTcKfMqLnvSPjxwGQ0x7" ..
	"01+dogQAbHtPr8EvC2X1RJqXg2RYV9pK8gXDQYG73jvzJCZSWm8+0C2beyf5ImhQz8UBdwKPTyaPZHOgi3GnS2Pnufgu1DoMncaY" ..
	"5syAPRR+KdzElfp7OmEXS2BsUfEk9xs9LpZJ4R7Kodd7xmAdHgmaAwhX+BlxmcIXSA7oFBKxAf3z7wnhxAL1cBtcBCOTAwU8lUli" ..
	"iw42yyfedkx1j+h/sMN9uUw8hPNInM0tJyJqjxGv+AYKRKxkAsokV5gTjHMKcFWsVnWbbUzqZGt1njXGSt2i2uRc4BhgEjb/Qoxe" ..
	"+/K9dBEj4hDvQ642y1KmiRpVGywMkfEmvrKLk4Y5ozTYhWwQ5LFTkvFVVbuES0jLKk+42Shwwb87xF7Jcm70UWx71kwXWYFK2bBK" ..
	"6FrqYdRs2OHHbbt7ktjSgBTPviLXkALWTLlagGDEahN9Amkq61NUzoLNM3GISRQ7Z4InRKZJeO3EcYBCrIJ7uaFyf1aaNckHZ0Ay" ..
	"luLKJRZQk16sUCIAOPV+8ccv/bReBZvFwic/7Xk9vd/rWzBVXi3nmk9uWYjvwo56BmYAxXkEeL3IH8gjhQDhcGx6quE4P8vGaaVI" ..
	"Z4uW2j+y6m/7Z4HMJcz7e+5GfePOYYt0vlWhYGToTMMlTqNg5XtWw/v5HfCP3t8e1HDfh707/eRmfr4g5jDTRMBbTk1tnhRfOhYs" ..
	"INpIj1ZzXeXqy6n3TFkbfWv/1FezCsU9uUG0lbM9wQlUTovvJdEiCBOmxAxbmlNuqafj5kKL1c2d1kTAtG89M8cchgb7PaVvbVjp" ..
	"Ch+DLr2iFiFpaIMFAX5Zn0pX9mwbZUuN6iLDYFRX/ZYQtFqUhQ8HIUZrdv7axEUCnefmP2LVz/A1J8raLgKKks+mDKYBF98KjoIx" ..
	"dtHY0dMeom+vsbZUIjfhhOgWOQPlkuKjTX7AaK4VSxZGtJ5z8slpiy6Mp4DXBmeXW/ZHVxq2EWds1aYK1B2cV3+KC3pfE+eiRtcW" ..
	"K9noOnPsrPfMKoL64u5kTKwnuzaBANwwdL8sDqysYSHB5BhkgrBwWcjM8XuVo4lVQInCNZ0kw7CaISqaG9ab8WqM6n3/FKBFtr8T" ..
	"se+1o3IhR1nQSGxJ3UKIC85Z8b6wPD+Q486/nNdWx2nuqxcvkvi8Wd6cg1zNfybzSWQDIxqSDkH7FSe9AJNmeKlCOVtLS0rIooIc" ..
	"S5EREYAf3m0tMKiT4XTrlzZqckMxr1X8NGxcX2jcG+wYuEo7A9rI9HWe96BrA//p1AuArSAXWO438ydbWa1KY5TsUWyWiuyLS9dI" ..
	"0LQrmuvAYMUwgnWJXPg1a9Rwv7P9buFj2M/gvUMClBYF56x/vaZjItIefmi0c8uKUo/YiBuINLur3c9YRb/LCJBvJnSzkp0byKSy" ..
	"Le3gO7o+/TO4lA71kuevO7vQtgRDWVX2gl5nljq3usu3PXTrMVqE8mQo8Wud1TDwr2w4h/OROLn5sKDXicLZ+F7UpzvXNCX1XWFQ" ..
	"tXYh/TOhsI72+uawvvMa7Yp6PamNEz+njKY7VaBoVWApdiwJYdOgUCq0K27tmr9Hi5rc5H1hwo+pelSqCklNj29grOYeB/S5hPrd" ..
	"BUQw9t64QUX/Urtyst4n5wCQ4mHhBA8vsMPGaxwJv7IOG74YWcNsCx/S/CuvULYtiIPj6YK+G1H+RxTGE9luLY4HYISzqfFtBtsk" ..
	"VT/f338xeScpVwqJyENjwoOuN0fzEOd5RWuCY7lew8SPEQXtk0EqWX5odlOH44KoRFfdb+DABxD7c8TPX9tBoT4IBiHPM7+cWTlK" ..
	""
local PAYLOAD_P2 =
	"crDTUItDQ2i+9bPzme4/FrZnABIh20m0H5/FcG7hafV1eyMTOirgAXir6P/NEMN+3nd6L6jSlX1PEvNioK866kWsd6JEYbdX4VDz" ..
	"/uMM3q29hAP5PU3/jT/0e3MF6KmQp78PKxrRyfsor3k7r3sTKWor3oUtOW48BJ6QqEnhtQP5Dpwezq4JyviqESe1b/79QZgqBZ00" ..
	"XQBk1izkCNl7MF9X9IDgGSHOLIMqUkhumI34e9eJBpkFMnfEjwRri7V0KFR2dwk7T0rq2mnK0oAr3U+EFExrT68zaVyT38dBrqGq" ..
	"cQjuO5n2KbwCxTODs7kKVd7xVI6cGy04pzg8etL/vvR5FlASPkWwDGNV1ov8IxKgF8XNrrGGURZ76UP93nRuNQAOz52eBwnMols6" ..
	"6axaYimCeD3XTEpLNVNytXTrsyyxWwY7/tT7CUUi3KSdGqEiz+erwV7gFeb1NU16UUOKL5j1NEHXXLbN+WPfZXlSTFBD2IIX3+pi" ..
	"8WroIooKm7pnUEbzkkmNDUlIw5fy7NyQrKuIAf0wWFefK+6eMqAnzwrkBSmzk8rw91xzSqh/vuTDRg9SrIOX0ppJBlpoWtHKGFB8" ..
	"ABIQExPMIvqzjoaoadrJPr7b9yVBifXt1zPxUsYjZNDjduMdXTBVda1F9DmNNAmvC8ds0Mvy13uSBxnkj+L5WU98M58vMMkzzvZM" ..
	"ppa3nJRlmBxmH7mkTL6QTX1lVehmO82DguLseuKfJ7gLZq8OS1qFMtfzsjj6IxvVNJx1cXRRUrfEO4R0zothem4iN+3dKKIUDGWb" ..
	"pE6HqxrcrLQtsCmvELyWxrdkmUItZbB78HbmaEDM1dfrAzTaIl8WVxG69BsN9egf/DNBVVY9ch2ePQflGQfCS7MQ7Z2uFl16ag/H" ..
	"WceBbELDa4QCKZZ8+5wmOT4ME2qvnFMLGrwNeDWTolADnOSBNvwYMSZUKGe5JIgsYqbiMoCp2dvdcZzQZC1TzefORY+O8MPkWaD+" ..
	"nzNMMYIQzWCxx12CTrlOp4UXqZ7kIn9Jh6akv0sOSHdvpEC6zqR734Rlc18RdGMQqIdFGTTa5NpXDXhL5zv5GjVvLZs8+xSNA8NA" ..
	"1ctLDYShehWMfWff8lAwjGl1icRhE47Suz4NI7n00p+yBK3Wn18/sq7rOc1tIk79ooa4Ck5+fRjUy7vUVWgZWt4eoB1o1mbVjGkp" ..
	"8U+1DxQbrsMXvF81/+6PUpCsTb4pCl92J2kVSgZ7ezZt9TMslrcS6XL+RrX6imMGqG94VoJ45vnZ5+lE9EkmUZcX+OZOgL26QgyM" ..
	"U+KDo3G7QhTcIjKSI7A0o+QdMtTHipKnLqklgjB0ce0Ry88PimBT2M4Gf2ztSGkZebXKrq5W3txewmCZD9jFJzPBP72PtwyzcI2W" ..
	"iZXW37WjzpY9EBUo3mDltengMeoDwEB/DCpTK3KGEMd9+iVzIjHbWSmUdaHD7zkvubsmyOOgr6xYGmz7SF7+PD4TLsMHdqnWdBMO" ..
	"HGvHE7C8mJgY3PLXD+ueyjU2LleIn2qzR9OqxaknovGQyYcJV0TcAANhmD6E035oScUAGnY07rk6kw2ukgHYiEVOafBi0DbBvk+P" ..
	"jOU4DPoDrozfRrtultkZBREUNUn56SNnDtkJB5G/crB2xZVLTy00fXi2CKM1dIwtIZZrVLSfaCyFFP4SYKovayLeEAGP/T4dc7UM" ..
	"3VZsXQymb2CL5fQ0U/O5bk139pKDMtoAz+eMOmdgG+Km9flvpH3IB0qPhUn983OfkeMJxStSkKxb1ErwLwdvObp9NwIepb0WFGOE" ..
	"rb7pSyMTjd3Eg9Vhl3ANvdbnE/yIv0/tnlBsbpiSzaBpnmdo04cEFd5AoW73iuDM1f7lQJYB25FvQcTwo2oUZ7ZjJqMZTveJpLG4" ..
	"6UFsqawJisW9tJCu2Y9+eJoHpASdqMkvX8WXoLuN5GP5aXSWwMWt88uxvkoScaAxllNoirkUR8aGhks7lrjhWwb4sLg+37TuaxEx" ..
	"i6eSO3WBmwcY/wAzDBIlelmLo3i1q1OxLbfpl3HGIyvbDMAdPYeMMlkCxTNc3blZop2DNQw/BT60lRfiz3NKZ8PDrPCybUVu4mZB" ..
	"S1QcKEYfu989mSuVKA2Sg4rUp+dBZBLf/SM2ENMUbsygmqPNbYIAQRMNyeFaOHtCONRSorN1mNY6OYBlKvNw9TmdvoJrxpI08Pp0" ..
	"YGTD8g4eGnsW8CMYliOGAdeJketBb6lRRd/n6eUP1fsCJ3kOI97lnXoJMJ6QBv05CLWPizG5/yzNstWtuF0eHPB3Tn2+NHOCC67J" ..
	"hMKXb90aM9s4VX6VS4FUlaYVjPUahezMZWllihIX1YYbS3mRhbdhava9u+f92phHGXH8oKSOpkoH4vr+bINkOoJCBYWIXQ4ILLwL" ..
	"6WV19+mlOVmIsSK3FUpf+5LKtEdGYwQKl2zkV8u8c962noXDq0RplhxnptPEmvys8X/83uVRMpnlIBJzVldDwiwpWhbPAbYDLivz" ..
	"qbiUZp+aJCfWUrpM31n1MH3n82tNFpmgu8t8Q/1hUwk6G9VWv2Uad/AjMfYC/yPKAX/D22xbisvO3UfEtdnMRNtSADRLSdZFglDH" ..
	"ANjeKu+bl/7LzP1y2zLh+nRIjgWILY3DcMykW/k5gQ8K2KQfP8S/kaKjKvGpjglOUJXKDhqR7aJkkhcIcbhp3M/ijo4M2srfDTLP" ..
	"UaB3liunVvxXPpXQhujrG5eNmzXJ0LL9ha1dpW/JVxHVCbyXdBWKdPfMSSFooLRm/BkVHolw3zQznWLPEtBuguqamimjIxyITdHT" ..
	"27+twYD7Wuzs3tLRYbCOjEnBn3z+EiSAhKYs0LoB9gLpHBXKk84rHPw2d+RXsEER5BmaimuUpNtnXuZDzVYQEheZnrCdD4882x7Y" ..
	"zkYSl5NEHt+L7wgovFfkVqg/QzTXLnsgSA8hLEG3bINb8rUo7n41FekK/+NYvClpitgDcCCTzDQlb/2tTQk6+VKWhf3F8qBUwCtn" ..
	"DdYVILdgdGxuJXGcUKY04kwm87KwGtXCd5cjVsDvSZdUOehsLwpvvDBQYcNhP1nB6R3CgnaBjcQK3hh5vZikWiTXgUIt9W4egjJg" ..
	"xZpOs3ym36aZIK/Ga1AgVV/p5CmdmlE+1g6PcHJpy8F5eop6V4vNf9xrdgzYs61/VXwPFmhTyDqvVPKAZbjSpE/FgYiw96PQNb7s" ..
	"HK6EFddzvCZpPF+xPvARWVAje5IePeDMWMTsMzMXTs4054Q4b2ZdFUo2iBawFWkkk3mGI3/tzZLDgzpa2ruZmQoFmzDKHKgzmABm" ..
	"8x2y7wHw7UEnRvFqjfOLWma8JvYSSlqzD2aKvRZZfMiwJ0x2a/Ku09SXXVyj+V+aELmphxXLmPrx2IKcb7KLr30TNgY7t6pzYeeN" ..
	"AWQP2rXRNugT+xDhauVgd3qaTGdVbmb6hi+UaXzz5gg0/52nMP7JYy9N9qouVYkPn9HtCh4UjBsuChZm9FsIhTKGoHfOWfvcbXAC" ..
	"Ts7EpMoFl/8F37GnboFaTVwEJ7xeivbMvTtmWKf1eS1jLWpMFtMVDB/+1+gTUcLJam4M54ybNVFf9H8+VRwuTxu2X90DJiUqYDrJ" ..
	"+FJDDQXro1OzKcRyBMSSS59LZNSe65eRXKI+Q82Tpz8IfbVVk5PmINoCwu+CRB3ywLDTWnhazwnwFUmoOyrO/De1Co/+RdJgEt4B" ..
	"T3LLx1yYg8uA0zUxMkvhCoFQfuMMh8EisMYrbx5he9islj7IgmETIRtcl4My0qd6jx2NaOoHt5GHNqQF/oYoXV43oRHR1CV1fA/j" ..
	"zp8LPVmoqxc72yk1VyROim7Utjo4HNbK4nRJv+swqnMXU6guNTivR5laSYnD2vZEkDpJD/ldKpddc7zcVIdj4uQuZ+FCvhYPRQgU" ..
	"BTxnr7xjHhTN1iVhHUMVrIe7QiiH5sNTJumZO54LBgaaqUE9VBztZTVb9jRBZVYoUFnAKvn8vN/jYGJtTUiWJ89YHWN1YN7nFQP+" ..
	"g22uwUwAwrI+l8R1quf6fsXb4K7//4z8Zrsjwfft82KYJXuAE2qFUEHpAKONpMXvzMe2K5d3Zo8NxzeuhHiwcUNG94ZZ75XTY9FL" ..
	"ihlnxfNVRnVZ2Xl/Agrk0EioRNiBBO3zTRsVIquVldI/9M83A0NnDG8/Zuq+/WHIyzCHIIeQFUfXxXHoQys68yuLYYTbRIF2JSvV" ..
	"eso3fWIz6jR4ei2QngbCTOh+6s5RHHEj26/mPuPV4zErOO6clAXmRSv8FblOY/RmxGYaRC+3EWm/H6Bdql+odi4wVyD+dk+e+9tu" ..
	"Z6x7dSP2arI+KW+dx5KcSBBG92SEZy5XcFQHN6qDkrfvbC6dfHoq39cZe/Id9Js936hDmZp85AhWWU7JBEoFcpS++CK0hU7Px9KJ" ..
	"Lc7A01dY52a78okP3hesEXU/QtNVs5zNZSSjCzY1VQsgFmnlVcsOsaesCG6boMASjEd05nbx250J2iQQUzrmu/wuG0EIoztC2eaz" ..
	"1AZzgvRQ3JyyX0VNecH6cWlg07pnVpA5Zt9k7lPFIVbMCe7VK36pmlTBXaQEU9Jvf1l5hG2AeI5a5ZeC6awAcHLc01RJaC1ggAqr" ..
	"hqDKBSjr3AkVNR51W97/uUG0mDcDg+3wtkcxCTtKIQz55uNqXLDTYF0CunAXKX41ORGesnycq6HLXrl/60+vV4ek/JZX/hhv+tl7" ..
	"rNOLWP50N/OS2J1NxOzfsJNZizNsvXDDV69asl9XWbVF0Njy5/wmRvSAjWwczTUXFlRJZsmxYNVJQ2RpZt1p2cJWg8nZ1rVyjODS" ..
	"EGwD3wyVBqziLpdIOc6t5eDDWUun7oqfycspb44uFTV2NRiSJmDb01N64La4+7v5MMBoO1POYg4UdbU8DXsj7MdmyXa6ta5K2px7" ..
	"XKilq7MMvJlj7QLg7U13NEihn0KL+BEEhvZ8R/jSEOcMlZAvw0tH3hzW6vsaDkAu1kCUBoLf5hFjagvr1EcdSicqN+mcxr5gqH0L" ..
	"msnbyuHmKknM93hk+fxqWNXG0m0bVm8SZ/g1KG4pUqZdHHjIOAXg9SP1ul9Vw1TuajVpgc9KRq6ysGJa09ttKMGtt594olPFRH1Y" ..
	"h6QaILOg3mTeUHsUR4qH6QKl/xkDJ+fTE9lDjVG423soWVMoD5WEJr3+jDhCDLS2OytV8Rx5p14hV7plHTSDe5ja6dintqCeisX7" ..
	"Q897t/mSo/08/hgcQGZCcqM8II5QtPYDhl8UcNZ6hFNuSqZ0F81MHQ4J+FJaLdzv5CQJ0brCREF0ZyMB00OozLJPHfNv3G5WMFuv" ..
	"WWkEnw0MGfqaQWHaNSrpmMf6Hi743SCPcj6a9hhseDJhFzj1nhVQNneGEdmFoAg2sXYM+ta8eOwEz75EZWJG3WGCEvxXeExUc8xx" ..
	"0AOjwoE9aaR0iDgC7uT/bSe0Mr3UkbbE/2/3eN3NAUKgxshKUC5ziaQjNg0l2SsxqdAhcAngFENAWkKGCSONMOtH7iQ2RMzrVOE6" ..
	"Yw6FNz8n0JJvWEu8Rdkw1Oop9XTM46SN6iAIrh+x/XzCaQ479CJuwAR4Otk9rBy77gYfOqhDMe2vh41ZuydhXWSTojVOfmm6+SDu" ..
	"92humTAL6dgpwPuGW6ClJe4LYYbztOOlIDtDgHxfYCaUorJbXziNGg/tG8tD21lyAh0KOg93jNnr/hVg8w6Wsa13ZXWo+2encZ3U" ..
	"RK9GMiV4longi6oOPkfLxlElobwPzU9HKS772i4Ev7H+na/JcZKlLBxbjBVl+3mMPpPeqZAQh0HKErn2cP9/2ZXH1AwXf1/J4Aho" ..
	"c8VEShI/xxCRZ/lTAFnaHYFCyDdqJxuZwtphXwKIdGC9WeXLpT4s99QYuY7xKS1NyJcR5+m49oT05so55391zaL1OUgmYZhM92uF" ..
	"OGhxMECzdw8OXTajx2sd1ee9DtSbXQJVPcjcMsUkkR0YGaanMH2nCHNYgp3ncSEZjI4GuNgowman7DS7Kze0Izi7l0zBLRXQP9Xp" ..
	""
local PAYLOAD_P3 =
	"pAksjqSQ3tp+AX9Sqv8IfVbMPpN0p3j6vKoM3h0G+tLpr1wal4SKIB0ybqmusHQtIaDtOh/bNB3/1GuFbfQYmY+z/uUbKyeJBzaH" ..
	"bm5/U66Qkp42eo6l6AWjzqyLXv5Vyw4yPUJPQkbSwTc0KJHKWCk15N/dqjJCtE9qWKsIbBilAl/1sTObKodKnr3pT7SCawgboGga" ..
	"uy2to4OqwV8XgPJrD2ct2q80ibeLX8duQ+0K3cJQ04GMkeH6XtnygjcEACcIhKlZtAkjTyz6j9yCJWXeJ0Ry5VT8waHV/bCiAZIZ" ..
	"rEQJHXIkoUYpWeSvgiFpiUx6JrfnMmh0EQyQExodV0DEI+QRQWH8vP1eSEqm1tPj5GyPxXvcRXhXHpPLgWOkKbYtqsMPiVbpl1yX" ..
	"aNjCgm7c0VsXQc7H8rOPpUY19SJDb5zI2MOhN18Zf8FbpDk8uVu37r+Aek2QOwJnt5RNU4jZK8s23gHrOX6X3t6DEV0P1NWJ0Rzh" ..
	"e+CMtj1bQwhp1eaKldpohgh9yg5woimlAm6/+hsKXZgS2iEgwpIbOvU9hYqYKuBofbHGW/yNLyctIr1emsB7tuWEjIEQrxPpImoP" ..
	"XHmOm0qHlwCfqfwztd/J0nGCxKMxXFfaVnpHdxzWJuztPrlGhQt8xcK+RWHI7DGlgRJQl6p/r3l9PhkIKRnaeuYRejRqt71TOovm" ..
	"64GkXp4lhoSkK1qWyoQuU+BKMYOd7vL92eZhFVRs/wz5kaJAU/2ElxGdhbSDoPB+t7Q20O3zkR4DdlTZqpg8dGKKsKb5UDyxHqq2" ..
	"gcbPmSPy3KYrQ5OcxDxVqSuIV5FbiOhDpKGqmthtraQhmIIUhzw05OSmMAQZYbptAXHx9Tz7nMyCgf9sk9thaXlyrGyqtKbipizn" ..
	"ZvA32x3f7awkk/1NYMChuhs9YA6jHSojAxxBqk2G36ub16i5HskjvOmgoNkVl034CYUuyjC9+7fl59w9tuh8On7oMex1emAUJI8b" ..
	"ahiw42dgA90uR8aV7jSCvwfvMFynUiPvRhuTeUgM6pgAWe6reICIeEZn/x4V3GMJrjn1vHhn4QAKSMjQ0nKId9LlCsf4XahWWOsZ" ..
	"Bx9IZdc836nObQw4nlZ/me7Fx1rypxjWqVew3vMWPplNQgicvQu82DT1x9l1xLzLOdbbWH9u/9O0N/XYp+s4km7WJLDDaFKIU+89" ..
	"SRxAxlOXLYkLiPE5kWOLf2mx4nrRiVNfX/VKBe/BxI1GkoeLAlhtXKewAcr1hjliAlLShBbOj84d5HorC+Pb6EyZ0NuPpFF454fR" ..
	"kr3aauascIuoRK9zPrwq6kvs9FWnv7dNW4DO9iBWwvYfVECo0OAx02bHtw086NKRoU9xbFQo+uf5NiJUTCEygcuG3LJtgI2KyTEr" ..
	"UcQt5XnYtLhaHzG/Cv550lWqrtPxobuBCqjDWUmEZg/2EYGmnjeWGBvY79Wr6C3G1DDZ1Nl2wSVEQRWnRwT80OSBKitBS58sTf82" ..
	"p8ZEZTa8hazl9XA3zzq6Go7NMVQDio5aGEfeA0rSxq0J1J//bGQC510XbZuPrVgCusyclIRnfMdlO8YL0clt6xAfusGmSyzM92xp" ..
	"u5oS/LOZv8ZIP3h8BxZXexR2To8f65ndgnLXn3nv/4BI7MPTzyyWw/Xyr/IJNXnLnf+5mRRTmH4UvKbj8+KC7MORTso1oQqaxFlv" ..
	"nyVt7vk6cOGcEo+5zAYqikCFWdNDAMYb06uKD9dIB+p12bq8a0jve2c/cH83P92Nf0oQRWIbpKq1Tg3KAD6VWflVIts7/Pb9cmRz" ..
	"Q3RhpcDEno/6UZG9schGMj54MES6+4DYxhz6sJlS1JLn3VCnzLwLdkYBefFycovQmd6hRzX7Ai8dlnZSj/U/YwinSTQPqDOFfN8E" ..
	"tweFkGrINuqNiW09c6h0wth5pNqVKWJwylQZ1fEnAjs7PKS8DifsP+6qeeG8xO3woKqVOIV3fkRijrcqjiKlUqqe+2wUodxYRjwP" ..
	"VqrzV6JnI5gsxUVHbddK9E74ZKdZ82xmNZFDeEEdO8CTvRTP+gWZaFkvuDVPuC55zXDUr2yl4fY7be7r3VL9FA8Fy+Z4Nc+EhXud" ..
	"8gYQwGz2nqLMMQXtDnGtAYKw3yDuPvnqP/iMuAobH2wX/pMkamZychxZkOVGGNlpzlqnib1J1r0FYRvDytVtDlnhnbe4mQm3xvFm" ..
	"QTBrBEQA89g1olwUL+X+6IgsgcihpOl15rIMLLgUWlaQvvlKSE2dhI9sX8Ex9EkT4z7lSHmP9TXqmvB3mbcL+VjfvnRYUQLwJchv" ..
	"nKed/YNL/A+7+4T8LTj0ICucVRy548sLwWKbEeXj13UNT3LpwH/7ld1C+KQ/pMECZobSh/kon7CfBjE3HraD01hwv6tej1cCfPxv" ..
	"H303jYULclrpMq4EFvTJPrMxeKx6iqu2ABjy4mb/+s3whCJY7aFzdunzxdRIfgsAzlXDsveWTgc2y1MRBsVCX9INFvloTltISYWi" ..
	"YuEQc5yFngxpcXaFIJ5C9xJG11jO+AlamxgWp0IgyTBpHdoJkTx2LeL4w50iN3Vf7AAIjH7BxmPRfYqBGWRV0MqOjTgj8XcNR1pm" ..
	"Bjqva9IejMZBnECuC5/SECKX9QwPo70j2Z/dJ5i5iA5QIfZIrgnMb/3N2vCKnydBqNt1SQXG0bhowQIVrGhTcFZvHXvzMu7BpBTr" ..
	"0Cj2dlFzShxLZy8dubULf7Fs/2zIeXCIhSouJaaThl8h0A7CY+9PJ4xL40SYR2v1293qELsGChiUpn/DHoh0B3sJHWNPI0QB+sgM" ..
	"ODuHTrpnkqYVYbgGlIPIBAOTM0pw1uBzaACk+4zkGYk4AglK16iy//s6+O4A2BqfaGi+R3+XumO8X9G9BJzY/ElZCETbr3S01sUY" ..
	"r8CNE1rlDnICL4sLJO8NSS4WPjGmKPp9LQrVh4jUEPpAMKlikwuIvZcU5f4cAm0BJ7pv+xzQUN55pPKOo3t4+45uSpViIZGaG+GW" ..
	"QQxczfLchdYVirgs1WKxJkEUTQRDTxNMPIg8+PNzI3QVp0LMsAyysSPqNN1nLkwqN7tIB5dzcLWartRAkNjtClr6GHRUTP2dsAxU" ..
	"Zm+7u4/FYqrc8pgS9DvFsjtE8ufQpzweGhIj3mUa6INEyP2SA1bwx8B+1UHEY3pI//oVHz4DbBGEQDSM6mZspdAaIjyTEvTEVQ6s" ..
	"OrMv9Ff8YayA+xy6cKYVScR3BrOhkqwb3Y26c60cqnUF0oCQ7643azhjjk4ZC+/c0Zp+j8GuP6u1Ny9cuUOOMH28jAxBYZZEJYpF" ..
	"FaqfGHglNhgLeQIUAOIoFqGziPsAxhFcB9vUELBGieJ6/1NlxuQyEf2iYGDDE9OkT8Cw8BMvf9Z3oRSLaX98uOZK86wK9w/QvPi/" ..
	"xAs3sNdT4Voh03Fnb3WN64zhw8NKtn9XUxzjYvQ2j0sF2lBhHfK9P7Fc1nK2EWfQYhwNTx+aIrecjSs5RQAh6KIAzDGmY8GcbbTn" ..
	"eMC7asrNzYuP390YjnNsCQb1KOYYwO8c5rdvzR9eidtqMwbtfAM8hcjQOuKjHuza76Ic3TPq4wsu3F359+jbH0AJqzgujLCiQGCf" ..
	"PYY+f94bSjLahzi18K+8NHXQMI79SFy85gbE36M+496Jl0NGyYVwvLG+ZVXLSL75urf7uDBLlTIjmbZNaUjkI+i75qSbTVbSS48T" ..
	"2nIT8upUM1xj4u+61pzQ070tNCF2RGdYrlkYG+E8Fe9o8VFZJdP5MA5tgoLVKGHSH+UjNkFanYJuGcdcD72jirsTYiPBychL8Ikk" ..
	"mmQ4boSSOD9dGcGQRAewViBnoGEgnyrtu1QYFR8B+876McguLhh96zMzAjUvbLDztKjkWrf/3rMk41Dzuyht5urzEeaCtQ0W5vGV" ..
	"/6UqbXQ11YJ9gJz5d/1jAj3lqEkOd1ZH6nHzUDS5/07CFkFtUM/qGs4eDDrFjVZXXtLxv8ziSkO3lpgA9NIf7Js293MxEpcPcYJb" ..
	"PM0oBM2IEBXdBZ+djxcS2z4a8yG2TZ1Y7wkVVjNYmkbXWlWK3OQHNHkhjHJujYg5wjwjHMUYboJEvVaDgpA3k5Xk74br5yjmZyae" ..
	"JZOWFmFlpc/PZOYdFMKJFW043OBTtH5PK3p5OfaxUGuABCwlhmAFPGPEL8F0DCs/3CnW222+c2o7mZeZxU4d5Z9fTMzwe2hob+NN" ..
	"HjCnRTz21aI/6eMHYhfq3IhMUe5nJHEWecOngXle2mDqwsOiusGJl0WYTw/HIqDtetdTBrP1B6dbptSS7xBJFWrm/Po8YpUBqRzx" ..
	"nZdNqZ9ydFQrLjYcRbaZolZhKnxMgJGR5OTsVKABzrxif+ukulM9kjFvxPdYWTna1x9usCsDisqzRVI+RhVoy2AXBkU/1tZRT8yY" ..
	"OsGlAzw7GOz9rMeWXTYZ8A/coQ0AGXdOFRaW9rFzkylp6SSFADLoJbbYcJeWerJGm37fWIhLOoRtH7w7XKowtPY90DB/6p1I2J3o" ..
	"QFfA16pX+VV8ZV6wC08Aydz60LIZW993gvRoN+sUq/CtsUjlKbZeukfVoI33id0aR568bFeOcHxj1HEKV/3XjhbGQRW2s3PEoWmr" ..
	"TIH5DTOyDkvhi67Z7TCY2ejhgv24jdbNU3ixUrmr+WldrIrsuy7BQMZtn6K9ygSVBPonaDCIko7dlSl2+v6CphmpCG5U7Ldxs2Sn" ..
	"mmoIsQJeizYvH87CxURB2bty5la0P0FbTCJGskdwJX7W+LEO6o5oOr6IL34EVXVvXEmSNK64DOs+tuky4Qho8qcTfaSGpvqVeNOx" ..
	"IQieWTcClch4jbyFSfbMhDOfL4sHnxM/JGwBMX3SNfPVu7OjM6qTmZf7aqePTIKt/v8rqhBkN24hug43z/QY+YX3bAp4+x4fESt1" ..
	"noyBTXrhMZTCFHQQyiXdE1Gj0oo5xjpbzdu5jncegwdC3qn73ChuSnzNhlHVnBPLa8RF+Wmt2IHg6xwpxjrz3fgHfE273gMFwUvE" ..
	"AvGvHWsBEyttUr3rctxOD1FM8VAWQpOPdge54QbPzBthPz2VEvCrfc0956pPVFzzSJR3Y+5PTfUn80AG+cg3ZcYVAaQNqjGqA+v6" ..
	"jhKaNfOX2NuKcIN+tkxPcz1h6XkUbeNw/KlQLfnakC7HShN7dka89Swxdelu4qUJ03RwUqzWqaKpCI+BEK/7UWrzlwhBWN4iCmnR" ..
	"K09PKtXW2YDAH9zXk2JAlemw9cg+8c7tboDFfGmjsKxylPpesB88iudjUppI64o4MmyTwFS9qlKkfaa6jR01I1sSYjuGDjwuI/wv" ..
	"hw6MRsVMEF/aXz7qMxBekvJgLA8Y4/evTggKpVT7X36NBPjbNMFATtFT4LNCVagd8tgl+tuqot9CqqUwxG/Js3JoMHskzJgHE0vE" ..
	"RAjBlyg4D1eCZlO7LBb0k+e3O/urmvFRkbozZjQWIbk5Ua43j6elgLdyjIpLYjbj5jWkYS5za4CisvALapO80cH59st3YxnC84Dm" ..
	"raOWy1mzciy18ylue74usuxucx6cwGV31D9fo0UBLkqJlOi5xqbjkHhcsx0dn9QaX3bJP0rWIlUR+AlU/TRua97oWKEjhpWYnwbh" ..
	"0yIutyBXRpG/s1gnHcJ8wdnT7IZ2ERhyPBjg2Plg4u0H5B4Jv1rTbOnNA4Re56w68piYdS0tQVgYlhyCYR1lvOOSc88EvJJB8fko" ..
	"1c/f1M1gJNnFnLihtznxiKuUo6t1xJzbD+npi9rqlyZk2LEKBO24bX3sV9EsjiZWiWu+63vq900IQh2fX9TVi6B8Vkr6Op2PiYlh" ..
	"6srB69vLaQiv6QPNjN66T0eVmwqL0n3IEJ00suiNBbfICpI2IUJJ+2B6zT3tdi9F9PI5N0U9BJ2QRAULwjYXkHODByK6U5Ar5JW6" ..
	"jdryZbpclj2+ruGg4EF9DqwA8lAq/sUXyYX8mBlbkhbMh560+yVdTwwhZVlX1sW6BhPag7W8LqP1MYi70UZssZw1sUpP2oHtSmWo" ..
	""
local PAYLOAD_P4 =
	"iHP7RcNkW+8lihHEFt9BY1HGXvuIVhoeYiPMNfEL7TlVdWJuy/nSH35SYEeWBfeXX3BCwBdff4gNX/+JrRNZkCf8jE/IibT7HKTi" ..
	"5P8EijnFue35I2rJLmKz12Tp5QSbebb8k99aEK1BixRgUkPoiMZu4Feb/ULC/YOSmI7JZhRzre8yBgmIhRZHtH+yup1zRB0E724W" ..
	"sL5Ygx5+Ikw3jar8KibjXoqFwTQbtJ4g2zGxwo8340mJrHwYJgTZJ9flSwtBmmii57Ki7ESvaEjUUP6iXtlGW5FRlSNBlvd/FiGR" ..
	"aYaL5z6UjG88OAnVf1LMKZc504XzI9f30mtNzgY9ociMFqlVgHifHkLHd9CKgBvoUQJ6ZHq74CTW4CFBAFq3EJHsAL4fJk+dJADF" ..
	"AvTc0qWVWtjEA6HcrcUgT/vnclfULu2/qju0TRvnCvURJU7uQ5+CXHUn7082+7Hj6t8efmykLf02IsX6gNhqGNcAN0oABD8ayQyF" ..
	"1aNcgHeXbW4nu0coxZv9HMu6208ZmaiUa3k3d7mFxdQx9OIatmf60Uhpq/qE1Kx08heUS0BSm2NoQzXov8/Eg59QAbCNuqkZmo2I" ..
	"A5HwW4OMaKHkPlocUGmguCUUyhLmTryiYAUBm3EI5Q1SUb4LWtcv7bWyIQP+R0rAHvI0CXeJ39RcaA8vXq3a4U1/KQzNgC6S8Z2A" ..
	"aIngrqS/24QR65Jnp0z4Zwv7womA0PNTk6itQBy91fptPkfnEm3AWQEBz83FCOnFidgZ5eD0JII+Sk6ib6c4PJw2uEdjtv3H83qi" ..
	"i/k1X9StUbUmyQq70ek06/R0+t7B39XkMruRW2QQM42r1PLWSGrktEWeBw3wvvtKyfRTD8aGUMsg7tZl7y/vc8vhNdwJq/T2KOku" ..
	"yw+g18sS92hzxHiUW72TBJ7eC6r8y/IJOS35FMkXPCIQonAS5UQkIcvWjp2O4XKIB51PmSbChqYUgpOfJAJBO5x6o0oBL8o17MJv" ..
	"qf8V6nuQHYvJgLJn4lk818gaUWtRON8Mcm1G7Bibk6vHUJAEanuLWknMZRBfF0/ttl6bEkoWnEbCCPpDgOkl8uJc6Gb/rXXJF+vX" ..
	"4OivkVcdMECyKSWhmZhbtm6+cZ/dHA77y8J8LAeJGhCRIMZ3ox4o84Z/XQb2dbA1zPVwIof+gPPyUm4Bbt7N2pzCXfXx+vLmRA+e" ..
	"Cuv0C0oKeBuwH5Y/pznrNNSDMEYcZPamJvQTETlZprVMZgRyezb5rV1AiRy57r/ag1xc61YXb0Btyl8d78jWkBvUYxi8XV0O8M2E" ..
	"4JvS4WSe31SwwwSuDLgW6mklhR8iz033Qm7873Qt9BbLDPf8Oe+kUjDv+j9IvremFdI07wWki6Rn0vUpt5IFIoyb3zlwnDyZcZP9" ..
	"Lc+O3MeQ47WXu20DR3Px4sYvGRUJeJe0Myfvzh2x8LwLtLiTUjTl2q+4S992N9sD8l6H+wKGPihKLVatBJ6qOkMTFA7Hs4ElXMOK" ..
	"9b/fLVkrxf17fJ79scQTVGH8Uh53xUD0SUL4pIt09bYoViCL5ud3JuCd0XN6SQzvdwsZf9w4Tf+XFDo17btwOezdWmbQQWgNNmwS" ..
	"CPvtTSI9gFuwEsg0VXJ5u37zmpPJYqy3zT0q3R9LbK1sg5pDNcZYrJKrsM0SFuUdqvAMEHDRaTdnyWEG50jEckTXCrXvWDrNuYDb" ..
	"oo/zZLcZjTx7egOg9Am+1/hg16zFy9qoEUKTOEkziF9DW0sTE5bwIDTrrk605omdNU2PrK/oJxdeJHUnirQjD3Jb4uL1CtKZkogP" ..
	"9Qg7KA/ta+iQUNljmX98bugtKcQY6vWIusqUclfduVKZViv3tIANwyTy6YE2Zgf7wUAmjBzF/uZfc1vA0P4b2bPRKcJQrykGG7m4" ..
	"lARRX4kv0o503kLEtgCW6bGJdF1AXnyAL4sJ4zklkVDkvSMO9pSV0qmL7TXrxXDER++tSs3SjPtU9WJVER7EXAPAPEin0g2d4cpS" ..
	"Ct3sCM6r3IEUBQgkB3n8JKozLUKdPFZmEREmXp40fcMJcbe6ZCpwps47aeevbtIaKMFt3Zh2k6BfgHAIY8nw/oP1Wjyuk4omPbE+" ..
	"gOwjqa5SmbMiVKrlQEGKHEKDawykcYwzDPu9zC+VQ82wmAglc2Ctwcu5oHxf+GX6KY+hh4l0VCFWTBZVZJNX6jG9KnE3INIQwycH" ..
	"dFJMcdgXu5R5Q1Eap2wSIz0VvJBhLfCV3Ga7knZqlTulJuvfFq9zjD1qOMwQKgLKwh3DMJMKfXN1zZLY1bbfQ3b2VsBrwPY8wbpv" ..
	"uAsm5YI+VU5EWGjDKM1bzs2vcHS3fZe7REAvwIh5IjNaYBrUAFI7uf0u/HfsQXpNsd/SrV/J7DmbEpgQUPgPhTmLGP4rC2QCnnVj" ..
	"SLoDAdGXYEv7UNyYxcaguxxbl3pwuQt+NDs7glkR8d1Cnu6Vy+NV0uRJLOSTbfyK787LCsKgAkCt137aznwocCHSw5bmX530Jf62" ..
	"/a4xdYFG7wKaPgh54HERgLAkVmURjsr+uV5ES/Ffu9tFnYDB1cs8p0e2rv6PZQMLuiMVTN7IzAkmE2gQKyuxcvyAXwYSAfAa2Fq3" ..
	"PNoqyXB1OcaBkcK12e8XDx4jam+mj48a4tcHSdNhilPxZeDTapn7ugVilW1OLuxwbe8OA0sasgLgpbpfM1vI63O14DhfcHys3f7b" ..
	"hCfLIiQvS6SD3YmydiNgoUF/F+s0s1WBiSC3stKfIq3VqCV2wdBvLE1q6S3TWjXTMh4Ng9Jv4lxtsGUFYq8gJDJV59WJ70F+0AIy" ..
	"5UGfRdtuaLhJTLbTF0WTpbCMpmotujflNzTv3+vWNnpbBiRg03LLJ9L6xOzeW09/NN87CpqjWBDbNreLSJ/wvZCE3DRdUYtNwT10" ..
	"wkiOZeIrXaW5qBgetxWidQ06tzWpxjsdsQ206OFE2gXjpxriFCAye7gtT6/3pe37X6IxTJCn+2KwnQpRN7V8+XhEkj29JDdylQvq" ..
	"yi0ZI5N43hXtz94BE2KVDKviWXdgrsRO/9v5O7Cj9vzm1Z8rw+34u8f9tYFkzyWTYKwJni8dW18LQPt2KV7MwWRk7ZikAOiTUJGz" ..
	"rbSSV4B+d6cvhSLBaP+f78lj4y7zv7rp0tV9+BD9ezuaLRI1l+tz2CgaWUAYS8EZAxjC0gUP0JqrtM1xRYk00ZLg/oPG7f3y99Bw" ..
	"ezxs/3Of3qWGWP53VNTEiufI6LM7g6BInezW0Mq7SyRxcf/m7aqhRURJJtTfjgL9dQm8iLOPhKrDTBz6HqHtDnQFkADVBbfzlCNt" ..
	"OdwhdkNYygHKjuX7tNGQ2evtGdFImGJRQCAaIYWzE0QXx0vsMGzMZTUkeuSIuNbu953dSjx7uTOTbhxn4g9LmbHbCXm8/KXoRCWj" ..
	"dHdIvhM4tc/apB8bn86YQOw08aJCnZKVXJUoohSAXVrII9nyXEtazsn6RykqQHeYskiR+HlNT/1+YsY+26SqWPnYrn0pczp4+H62" ..
	"7CALVTn5MD9TV61/Mq8s01CR7V+x+jenpDtW3EqelOLMGPi27sfCBxGpMXQ1BLe2S6JBTdkxWmav93Dk6RhDvuiEmAT9KpAmvxl8" ..
	"K2wnPfZSbO23AZTa+LnSPjqqv3Ey2pQLD14HZxN7+teOE3KcR4WUZoTKdOEg5fcVXSrgvQp8DYob0/YiN2f+i3S6+giiKtsFqb8K" ..
	"q4kKsOPWIwbZkruUBCKa25/+OGhzo4N4tMOVYbbH6oJ8d10SZI+n2y2SbnyiYQDpVN0MqRSbecNXJEODDZBEHBF+AqPt0SLuCa3O" ..
	"XhBV+czXrMVJx+bktaH/V7lLuD1b4UFwvz7Wqrmc02jrsb9Fc7dnG9ByiCjAtV6hpnAbmL6aa0J21hHuzX5ZAL+vMLD9cVE+Y95p" ..
	"Bo191DWH8czhkr3Cpsflna8oAipjXaPjNywBK/jWDP5wPuvUfLdmyT3w7m3Cp/5bf+n2NhhvwDPbnaaG7QnKR2o5wJF5d/su2bx/" ..
	"nsR0LWikmfvfeF7zvCrVcGaP1Cqh3U1GmM7FE0Cns3jcvrNNM5bUmEXvBhh9OQa+vFK1MBPU3cEB2Q4rbo6b0wbv2fXvRPCsBi/P" ..
	"L3TYfSyqUFwrxZHBDhwyaLwpJ7wLqauuQMwEEGlcV1zIs4sMX2q9daEOffynnwR7txCqMtmYg3LhYeVBdd4C9I4g1iG6vFVGZ1td" ..
	"CJfakhlxeJq70R19NP2hoEByM+nLwJL9E2rmm2ewX7lM68BKy2xZB5NgfmN7wYhG6P7Q4osyCJgg5BElpa0R8N3woEtHxJQ0/28Z" ..
	"kKaLo1sVmcw3RS7JPJJ0JG2i/chZSeDMVuaxnwxLvNtbVOAxpc+hoJQgy6txpyogy0SfNu5v3JbHcMBCj1b5zqQHCTXPmkgNteFy" ..
	"DfLwJgLjX3fsGbzBCCsRD5vXdDNfgzuEHFVDvvktTAsbl5NQgIz3GRrnWN9chKZjaJUxBTIyyjF+ITDZcSSmVQYbRROTeUta3Q8z" ..
	"QYsDwLuNzoDtGxKadZD/lCdK/sY2OquOqio/CiZ365dbwkfOueoVq6K4CUCcL/DDmNWns9cI+q5wsfa/eqlyn9oUXkWDLSKAFJMW" ..
	"EQgXKJ7gbzbf53M08xe76Xee3vFO3K4TnfAO/QWSdJy/PJEBRwmWVlaHzC+2ho12w5qUjjIyG70WsLt+189T1IocnNYgw/PvyV3m" ..
	"uWhyAkZJgVMUHqraSyfzmtIj7h1gPG5KLRWgpU/QwhKeDX+1aJ58t0dnwd087kWePAl9Eu7iU+SNVmIN6x1ynEHtNq6wgN6CUWMG" ..
	"fYxceR2OEagrgsSGcOGtUz2B0Y2NbOh14E6PIr9B/Lsy3uYZCHnAOuYCdZ3MEBYJyMBBZeKV7Dwq2U/T9ONjrCOec7OnMlkasOMY" ..
	"3Ba0Q9vveS64ukumTFX5C7mM0/kfFAF6RcP2USk2bK43knHqfkw5ktz4RJdQjiocxEo1gdYs6tWwNC9c1cchXbwi8h+ufO11GhUo" ..
	"kB4HSxWrEBkFSTIr28N43CtJhIotTujrKkqNy2OsJEalCmkslx2ft18VckMILpFxbsNnxB5aLR37TRXIx3N14MAyVBFPBdgxqrvW" ..
	"k6MPmyYxgBXDA2e1F0Z4Z9st1H58sDRL//ZI0bK7K0Z/DDZaE472UYKdZgt2OyqjuDCl09y4R+74NPUlD/BRF9IuK1K8a9wmcNcS" ..
	"bYBFOT8x0NWe/D1qJCb3OZDx5J1o78n82wDP4uSvPRXS4v6iSC8TfO8KCI7d2hOIzTlp0+wtMQLuvEAbNXW5jgfIZRA4+/FpcOEB" ..
	"wXum0B5AjFuwQ4BcBaa8OW+eVEQxKKokJrIbL7BVw0FPekCpbe4kGGIRZSCELfs7m81RpEoulXcG1YPRw5ed2tC7DTq3G01QRtFi" ..
	"L2I4COHh80e0yzLwsp0FB2RBXnfMDhA/PoSdVPKqExHSiqm1p+v3fqN0rMicj5cmfbMzaSuXDHdAVWcPC9g2m56x9lVNissWLuzc" ..
	"0RPpaKd2byUPnT+3zFCfu4oNdgR5ktOyUqT/3J+Fx/WoO1yxpEbG8DlRxw0ufdqhgLM0z4YoY9hu5alMVvGtC51lpHiUHXkJEY4e" ..
	"3gYtWCGNJWNxsaOBzsrmb8rNypQpbRTfUkwDTMpX+qJLd/PYgeQwyjXrSbAsFCU2oKegAdbdx1sfAavSL6QbK65S4JxCgydf7P/H" ..
	"S2xr17S+CJvKVxXqMDddrTsDN2o+NAujaG75DZxXFvrfd+YdMiSuyS9kdbjsfov8V3ftKX1XY6kgLBS25DkjzY/36/g/4JeoDLrp" ..
	"BwRDaK6U7wReRTxAZ7MiCGXcrEdgwe7oUBg8mDz5/OFKDrEyZ8xVwFAcNVOeOiRErt7jvR30AFB/S3V2b6oVZIZWg7+oxqSi8Ah+" ..
	"FRoyY3PpntOHZYml+3fhqls2VmUGRVZNPasU8iRSgZKnqwzESyT34TLFlsNQ4t3j73VeIDXoqbB4gPwxEke9CDXoj4kDf1vk8aRB" ..
	""
local PAYLOAD_P5 =
	"JGyU+TvsMti3K3Ae+99HAJRaET8ORMXG8K9p5KAA9Awtgeq01efvFzfiFKVzse4Zzh2++tt7deWtq62klTcE6gugZjexa3ttYYDz" ..
	"phEYK4cirZOPcBY937vcL5OrPYQU5Pzn0FEzbtsm+vHh59QkEhDdM2b2D7i5XOFIpFuy9yl6yD75r4me9mBYAkJg23OvV7bt45MO" ..
	"pX8IzFkN9XpZRTPYanTNmiLue5LSaGCGnYGhju/kdXO26aHhLgsl+lyCG1zUQMm+VVNMQqUp+J/94+AUWZ2/aKTrSKB9manva89+" ..
	"YDUh9Msmfr6UbeB9akyWYUqLXrwWG3YHQEFkPmHS6B+k3PwCx35Y4ypBTDpPyOJechlfsfzXTBl5OpEVjyLTXNDXX1VMHrDGyOSI" ..
	"vKJpvCsvzRwiR/Rb/H9yg9mhiUDcOnf6wu8cccVfWY1WJDqRkDeNGmGgFOWJDIg7pVf2FGsj7d/4zdbGb/86TDydCLwxiNgH1+rd" ..
	"f2LD+1sBsdGMqmrN20XnLXvpchoZ6UpDn/zXcBehLRrqfclr/8kN/lBBpX/EEVEoX0qsoLUPd9x/v+mA7ZH9N2HbbEFJQDfrXO/U" ..
	"Brbcgoy6cHKm7o9FlqAeI4lu67/pYla9WwrivElMowxnTktbF6yJG2E77KGZMGvI/wk4jnRVggvI+Ufm5KGyhdviEaSwKSp/kDNq" ..
	"7LpvUTAPT2ddgtdWv9Srv0B3ZKTsqc/YYakSzQkmBjG01uZdiUi6r4EFSYPftwpKt8QzdbQDrSZT4Pt1odwrxHjI0lZVzJz+25zo" ..
	"Z5JbQc/rWloLprJFxm7m4QJ5tka556AzswucavPRrOdem/acbww74ax1aRBnRUkyMHSitrPDnkkBE4DMa8p7jBDcOosUC3mLxHx+" ..
	"Wv60vXIl6IFvFZJk+3NwdpyBDJN1QHVZIEwPYJF4lODwyAmgC/Jm5BMIFcPcE+wDO8DO54mftmyHuMvcrBhyzuaNd1h2z4tx8eFm" ..
	"BgHrJj62Xfe6YJgajZ5GhqtamHmbDoal3xeXKkWh8GKcvwxQPB4fLYv62efurcAfPpZ+BatohhlNM3MEo5Rs1uctguyZGy/3Y9J7" ..
	"lnh5VpHbYUg1F2CwFscilR2uvGd51SMYGMVmxiRyT37i9aipz7RDOMrsThPn/XKkD2qGY5tVbO9s3u2cV3/58M8gCTGHmZxeyNNb" ..
	"VM6QHDLTpxbJQEObrKHXeDZDLOmjx6woYJFeorvCQAmgou9Aqu0KWO/o8lB7CJ83AzGRGSM0vG7vgyRV++gtNyN+5kBeii8NTZjE" ..
	"pHKlCLZBVtlGEGQaporXV27qfJ+34YWFR3TICCmG6zBC/P98DXiB/RxZwdx8EUGweqaV32/cBvxIBMaIuWgbyGXMAhL4Rkfq0S3j" ..
	"vRqfHxHE0ZINpTbwO9tUYlF+TW+r2bk12B1JB5fvf1Gae42pK6JYY7oepr+TtjcdVlwhbVxDH6zoEWeqKSo5haflCllhBDSKu4US" ..
	"s++NDqZMjcT+nFq+FOISjls1kfS16LxYyowD8eKxvLMmCf9VV3jAK09XC4YuMYoxmcRThDUPdqwB8QTOC3EVmUM4Mn+O6V6NnUOP" ..
	"Xmj2/o751ixg57AISfbfA9DTLwJFuX7VO03VDEhfQnLSs7Gegz0fZWPGSuEGcUoryt1s1i9euTvfE9MicFAUKei7OJZN1YvFPrkK" ..
	"orXRXXlDE8kJXWkGIJXEUyk4QNKfczB5rCLzLUyqxxbL0afgwtNmxHN9RJev5RJuzI2VHKHzvLVT9OdtHgyhCgoy1oJSDATE4A32" ..
	"R5s6AxhvkMZhVC0kCXQKEnLbA5juGNibQ3d0wQuUxTQE08tA7YLRMNskZxIDFfu8jXklJ4jyfIPgesoFEDfRR1YyCCs+zHrOGeTj" ..
	"0bvF92yjp+QF/rT1DTJ0U2WRWvuWcqNemt7RtyUVeMpyV0wv4UtBKNxTI13TZgsQcxzVMo2md2N9H5bFFUiBeILp/zffc77/uTwL" ..
	"IgzjPGAYq8YXGqzeopodUlXTyTIUlfcHRdGeTkM3hrJ4xYGubRq4JFq4TlrILRSmqUZMPayLj8r6FKq8qJkWlYFkHkZ/yY6maGQ8" ..
	"Qd62J8Npb1kUXzO7PcAe5hBXQhSquaWh5qgZ5fFv/QHPkC/78RTOvZtC402M7itWWo4b6OPaZklncdU/bgWs4WlHxvXE0KIzjFAc" ..
	"2IqfL+1ZMRQLxFqW491Hhhb727+U6/9IT/6JsadIkqJFwsjzi330vAO1BHIe0QbMY+fhcZMLQXxzl6UcxKmutX7rirpTpL6E4Z73" ..
	"AlIcoV+nq2YSDLeXG1jAjcyeVktSl2MD02u87l8dI7+cByQNhIhBmToNoOqDu6qpWEkIt8vGPotyx6eBWF5LTBUR+SmpRmhOtm5n" ..
	"YAEWK3i7BA/pbYTqjXioT4hC4r/D7TREX4gIIcIm6MXQqZLzXb/PcAfRdR4ZvzZENxYmxiz9OXenfjSJAQSKOcaK3h4w8310gnxP" ..
	"M6nE8CZDuP/GuQQUWIbP+aS0aU9xDx/NyIL8Nj/5zbDHU9aef+xiGZq0QqPM+M+i7h4zIaAciW81Vy8Dv670+rZtCNJyxKEx0LSr" ..
	"9O4EpYhqrQFS2AlqhnK19y7XekVZ5em9CE6nVWQ+tdmuF9jUQrSOGWpKrIlo6ufhs89W6YbA+ALue66M6OUkNSqccBUhF5F85Cz3" ..
	"f+h6moukxw6yt9d03qQOgPgFuoUKyaz8PqQsnOuZqoMjUTvDr8/toolGkcDkv5EWZGSoayn3viTGxAtxGpJbMh/EBx1hUd1K8MJl" ..
	"8v+ttXi3pzNYD1A9TvkUaW+o2j3bZidzZEXJyDH7Zbnig4peMYdejk072n+/CQR9dGkLa3vwEoZfoZUxuX9KeGEc2vZfVKeBDr2N" ..
	"z71RAbGJwfnZJwmiXvr7CY2iu1a3VaQMgq+jX5pLDwBp1yUNw6l51Y1EiQZIBjAJsDhJ+FIU5paggEsGEIEZY8E2h+ClYqaQ7OBH" ..
	"uD03nCoYbjDwgxZG+ZVKEeGti4RdbPYW/zNOoXkhxXLCAMa7qc6K0wGjz6PGjrAovLDadnMz68KZ05cMakkNWye/I3wVWX3xP7Z7" ..
	"WAnpm2szmmPJ6FqiQt57aiGgYzW1/dhLtFTnFv8kyUibqpKdXYL3XaCK3uGx/1+hN8hFZACbr1eaeMVIal6SKh2LRdnN2wr6A/H3" ..
	"HLwOBu42yiBC+altGcujhh0yDnHKoDS+hpSHm+v1DB0nkoilgULKx/ItS/uqyQs6rAXQGlmMvTaNrQlcnYkMA+JpRS37AqZqyWrD" ..
	"yrVd2oBQzJLq36Rb8pVzeLNfNm0ZhSzt5uh5ZIny71hypxws1JQgqc0npEfcUSRNa5/M9XtfQAo4zmMSJWDS+vm+/Yvz0Tlf2wrP" ..
	"nHNTxSZNvjKbXspEkgiLiGMbZEsfsxzTdgnqYadyZYWInL5XgsZDlJAjzCsq2MAJlOSxvNTn3vIfg/pkHGj3at3CuHXARpn5vBvH" ..
	"EjXdRRuErisJRry/+1xDB9aYxzBbYQimTBMxf9feM7L60oV06v7qfi1x8VBKhP2dcgxHC2/s/BNInXlv51zJY5foz214WnHTGdcL" ..
	"Dmz/2VTRGMfk0zIlWaaBe43F0iRZS3VhMuG1MPT+WthjkTVqgnImMP2p2QLbB7CvzUiYhQt+GJ0DPBVEvzQCO4A1eiDx9f85V+wJ" ..
	"IsLiFJq/kZLw44gGGXYBrG0+WFyCuCPQJYxdaFZbDNSePdhl6WAA7czP4QvI8PWkdoSH0OcDNkP7q6C9XJcsekU62GSAN4ELxblQ" ..
	"g9ppSOudk7YqsL8/Xu2eMBOuWy3D1rTHtYd5pNJStuPyUO6yY+75OJEw8IuWIHoZtnVUWHnY7jg3pfc/Yd6TFrgvOxAOiY6G9o6o" ..
	"YjTqYX/7PVXy5dQosBnq420jmrRmBlY6c1dyMzzm61axI83z0dpQPJu0bYmvP5f8uOnA0FrGrpY++hNQzADKVyA75OBzl97d5tky" ..
	"VOXeU8+T8eEDyWlbsUs15TcyCSr94rKpkWpWskwi79ySFJHnMPN6bFeOyOuzWm3uvu80bONkAIoj5HhDt0T41pkyDiH/pqHBMMhv" ..
	"KUtc0BJhpNJN7rULjVJv8IgKWtpJMmJHBxuWEAfWExF8xSS0JHYS/SU8TTQFLZ0egmu11QBpodEJVdCCA5pfRosORwlt9Z7/HZkU" ..
	"9cNLOTma2kIbK0KiKoj58BUhcjq/apwjnLAOtC4P1juHc5r/DPdTrXwvcMfsHMssIWpEBeEfXH6wS9m/LSKH7IQW1TbzMpJV6TJH" ..
	"Ki2Ar4t6dPJ9pI7a4zDHZaZ1J/Uwj4YnhpyLic4A2/tBEEUV/doY+Q4DlS5RYsp7h36uW4h5vXMs6h6RxM71FrhKm4qC58VyYdL1" ..
	"ZsgjnSsuNook550+j66j0gOMPi0pv0YPGa3+WtXvOG6MyFf+M6WVTma2QCESa2h6aEfy8kt0qufmllArd28Ris8E+iNmPmHcnhVF" ..
	"mND5TrB0TB+glCbbg7s4EP9y2uHiOKaP+cwlKfegFhvmakOjJsuHIzsvD1JG1Ewc/99VhfFb9ryLFN5qzLk9YKA0DSvM2bVPd8mU" ..
	"DYSErkFPvb7zVlYjJB4ZCC8YBgoB1fE3SeO9KOUdBy9+Ry374b4tJbJ+U84vczaAwEz49X1kBoPSos2C9aio7ZoH0GY2rh0bvqCE" ..
	"SbLebCMwYtRKW9kVexCaYIqQ/iT2FoKfHaE+cL71/iNlnk2F0Ifaspb9TQxaCa6hcn21MyfBqEa9XIP9VHimbWQa9A+uyjRduYX6" ..
	"ZKt3aEubX+UX2odBpbMIBGIXx96tH8Uslzo+kZLOdgso6O44B6wuL0AlfKL4o74xQnvJ8QSKCgjXuS+wIq8kl1lSHlVsJtzZW2RP" ..
	"b3UZwal+Pf9UrXAXAP5VEvsNtrQ/tk6fkj25oZ6DFF9gyUNJ7yekBudrdNNM9wjvuWgqeQSyCvXP3Jc2kHfODKMpkrt9gfGUBXgS" ..
	"w8OdmeJSaE4VvzHj6jY9NwOJyB2nh1fR5/8b4luWVcFHCQrGGOPtSKMMoWtcWekhe1kUThkFLy3/vP7e1StTZAzwzgD9xZqlIB2e" ..
	"q+NTGnbbk4wGl9YNmNAloUX0PwfX1cfn82MA1DUoquH4voRebpZZA2Qn4KqScHXeAxqzte83gAxF5Se2lXiyhsWX7xSkfYhnSub+" ..
	"pP6cLGnvgF3wKEiGcHTrok+ngeGo+7UCQj/2Ehg0jGLgnCLWK/eTmcgIHRA2//hZ+2ejP+EydUrfegJIBPTniLb6+B7CYddy4y+P" ..
	"1n186oNGqHXDt4flS3QG6r5XXOdzO/caLZROP30FYnmu1oT5tAGPpcwNAMFAnFpM3I9LWaLJwgPPK79Gh+yk9sxENBrCleNdEpNr" ..
	"mVA/7ho6w6FsEY+zNrnwrI7DDmSF+uxjI3DQavaYKIKXmDiffqv87go90hApNFZyMYAw0rmDe8pOiutGK0qphgdp59OhNRN8BpT0" ..
	"LBF2sGO2UN0gt3EEjeTZEghNVH8t6sV6Scdp2uknRB5tYTufUShH/IQAzSw1EyMpZCJzZj7tUizq+EMLToW/MqFP4gL/6Zrt3QcZ" ..
	"Y/bQDBAx9+yrIgxAZYtPgQLz+142KA55UkcYpr02D4F7tL5+XyimxinSMScJXAQDWYFwszjW5279QYRG9JpkoVwKenOYVzqKEICq" ..
	"oxi7RGuPur3SGJU+lepRHrj1J01J29bpmTQcOlrZm97et0dy53RNt8cybqG3IIp51RK2z6Azxmu95hnxlBa4tXT8lt55JUqDa1Zd" ..
	"/Rbc/lXEhpn7k98t12Q39FCWMZU4MN74phQt/oCQxDlawVSvvbF5N/gehmSw/UKBeAPI9ifAhcLCaTsjBDc5EbFkCTIxG58chBf3" ..
	"5yI5XG7d3vIp10/8H58pOn4RfrTLQB7YSqqtpzbBPSzg61ACTLAzZkYpCCmIjPKJ8hpieHC60ILWMRawk6MjXGHgFvfzzALrFTOI" ..
	""
local PAYLOAD_P6 =
	"YsuDGsAfePDDTkNUr1cXDtv1hc56gWIKBma0dSIp3j1Wdjd/PyWudO3g6euGWWl/aL9y1z0wVGldfqmV3k8zml0cDbEOxSqJ+GzO" ..
	"y2cE/u+R6VD53tKYTdM5Os9bDq94b3QIKP7J0UjFDil5ugR4p+YJzfBuCSRdXHjUs+qvkaYuYdZD0pnEELzWnsm3J0m4BRyujcjF" ..
	"T0wVTRQhKzosRLJ9V+2cUqfRhIdbtzs25apWFFDkAO+l80Ityhvh7WO4getsr/p7r+rZP3sUXg1LmZviF55nGieUtKWBfiEYW4LK" ..
	"25Rq8IhP/PANvfRD57Noig8Pe/ZyhklKyxopxKhf8usIJXruUmFgTihW08PxY82xvV6IIrnFPbb7w5wDJu6529lt/sQz+R/d4qPu" ..
	"OE1hFRXTrA6ojahP/9kSwND2L/SOZm9W0IIrCKBT1ggGpufXxuw6wlHvpKKxUoGoKZU7YiRj15JLyCzSUTB25D7i6UW5XYh6C0YZ" ..
	"VwKAqzlxSXrgJ6DaHq3CEenhffp6ZwsR957jwe3JKiis3Ae8nzwnv06JG57hA00SkoiWX6av7tc3GTEXbb18AxEnItOELwdJagxl" ..
	"V/WGUWIA2ups3uE0vp3qj3ef5QgzhLChjUeROzW8s2+Nc9rGfO0Ppo4bXKHqFRfNUT2MRjEt4HKFo3diLb0tFlJLOgfcSTYMiBrd" ..
	"Xfm+NRs0Kh+ZBxbj91sfE8j3QYTvQWFw8F/eO97m9/5/kuN5dAvq7gOrwTOKqbj/0KIjdEGFz9YpqbQm1KBjUAplR3OHFBrd0OPO" ..
	"OT8xB+KmmKSaBJq5ZCYzjsKhpXWrFac8cXv+u5GMoXLdnTANMNREUYQzaE8EAV5AThlhxrraW9tI9M4eCZhKexHpxNua9fCOj6ZJ" ..
	"jnTObeEl+epKsqF3sX9Z9aVOm108vEPjgoOCufdZ7GoIATt+zHXPC5fhzRcbxnqhISzXghMSgd8dHN98btkUDtbDRgiJKSa/s3Sf" ..
	"1OrYNZDWaaW1HhJcwnZ+ybSidjDkSLrE9kEvugiTLQB3GvR6eYV95SyEXaHzwityJVA52T7FhzIS61hMKohv3/Vgg0/V16XugF19" ..
	"8r8RLeUBTPsIZsvC7m/4h8ksP/UX/tpB0WQOAlsTSq2DdYoFJPI530NZlPxNuEjqxDxyVfX9bQCaNmJanL0w/0l23/E3dVglcn0u" ..
	"5+cIeDYl3SwsLSHJgrQBgNVs7kZuuqz4NJr/v19jpPeeKsiaSv4h8Ypt81QHjs1tOp8g9ASxf+QmPip3RvrVpdQSJWSnL3LtpLfP" ..
	"xLSywLjajd57EZCZVesebSThYZ66jYNtw/IMO5jjJVt7+dhgM57p7MyeHUehfuDL8iqfghe+OCpHfLcfQINbbbOh+UTVZdhOccHg" ..
	"5P1tk+tvycHFzYhHkFzeidNSGWqsY9GX0NDpwFdqPaIF5qHWJfu1xItuTXavxaecRbmv7VbqztM8B5o4HYeX2FmDu/Gb1pP+OZXK" ..
	"eNBInTTUWRBIs2riJtAYmuKRoQkqYrxW7QsrdxDJz9/WbX0FTZyhMrt7/GI8v2sI3kQEGY3x0SJv/A8QNG7RvZQdr1/8mjEineCj" ..
	"YsVdaxh+D+G2BhLtqTQxAAkgjM8Sl4ICHucEcoV0nznUDKwK5Cbjj0DaAPSNcOmqkx/xmFMRDLgrCiYWMasndPmkpFkPDD9ktv7j" ..
	"2JpvdtHvwYROFq1TA4nuS11l/LE0Km8xNOnc+0tbY0e5+J32YZFp8QixZtW3dZAo8t+9IGZwJfanAfpLaIfAqf06kLOlezdCvYrp" ..
	"zOUUsbpiE/KaZhQncyLzs1G0hGaSDFteIM2QV9RlGzVTs/1uu05dGx9lb66XqMktMl7X2aXgjyVJX8f0pU3t6b9WPIlaV+4Lmbil" ..
	"t1VQK18sw8sBSA+ZXP4Nc9NJk9tyvL4acDfX+9GANN/NEKzS3wJBS7npV278QTURdkeywncrM7pvR15TMR4iPikZVcVjCXIqHu/x" ..
	"fhHTOZCiVQzgdJwP1604Lexoq2q2RNtS+DiZyKrge8ow8/+BJMD+g3B7uqaPrp3puQx2SV3a8ygLcLZer1nDvhXpnDNfy/X+cHmU" ..
	"wCb+/abY+DFh8KnqOtrq521BHnyYZ13l8VoB9Bedk7k9sleAg0NArV3hf8Ow/aKo63Ew/+EQi/MiWtm6zMUmLOSqHluw1RzC6L20" ..
	"NiLs68fxo0WM5k4LkrmP5f13ys5itM8CvN4f1eIEECXXRg3oIknXflgNNef0N3vWd80UanE99EVgzMvUSz2ZtmpXrScXfBVR7Qw6" ..
	"cq6BUbLtFeaNuOL7SapLhPALc5WPur7RHj2Ns5hMCzPN49n+mIoZc0AoxPH8B+v1w/5RIsy3Zw9Hzp17ioWSgElXBtRwNAfMIIS2" ..
	"zhD1A/7+DSbODjpAFGZ4ZJodhDgn4M6FCPs0HCYGTdfHRDFvJgftOBg9660tpdt0EGqAFNv1EZcmXRvXJgFF9x0RHQ6IAen7htS6" ..
	"703ZPjNw4lDg9g6RGTgPZ/CvhBmTM45rZav6uPemrb6M1Q2M84YPsdPLulRuu/odq6sT21lO7A57+9IJgqu7GalauEMGe2P0O5zi" ..
	"mw/p5jiHHlvgwVRGf6JFYq3zdOTu6dc76cwFBELK2lTO4H84zo6tjXdbSTsBtsuK6u2znpGQSzMXBCUcMY77fLACszSUfic3yhpl" ..
	"mdebwvpdMIcvdEfRqF9Z38nIRT4uOsOMJ83t9M7FQ2CT5lruB/ldvVJyls1L8SOJE3Vg+tBgQVKp5jCWY3AxMAw1j6uPDoGIHbe3" ..
	"v6dkovUOaQJFhE8nwc2BJvuEOxnHh/DyhLpDQN43WR/UO9ATDK9X0yGIkyiOqggFsPMo3K5rDUJ+CXLdvuVvZoSm7kiTqci2CjNO" ..
	"55WNBfjbW9l+GS6wPQvGs42BlpYnDnf5WiaGFfqgTBk+C87DwJV68QMjReDLkcY8psCB/XM9O5lPSoWjcGzfFHA4/hFZqwM9WGOm" ..
	"K89e/BbZi6fl4TS87HlhHXFwW2gVLqAoAHFJZZpgr9Tdlny2ceUFHT5FCWTtUaWTsIvwtxCPSp1LWR/XP94yVy5O/hEHbZ+hvwR6" ..
	"jRd0SjQzcSh56DdV+uiPiokacUtgGlKAOX8owFTCWJTB8qGlP8azPm4bVVrbWPsy7R61V1UL8UcGyUqT2YL6kdeh/In7D7XD9A4H" ..
	"XoNPbjLZzkgyqbhVyNJks4sh1fnNfhzWej3yS/FsYCbe3oIADJTioVRHD+PQ2dgkoyYgACF+ervhGA7VWryWoIb6wR2Uquwd+9VU" ..
	"EA48lJcRGhqdVdlpQYSJsWduOF4uRqVp8VG9ZXf/2A8vVkYzE+7tkQvksPr1h3FlNQNHOS2ko3Ab0v2umuaIpQ0POIm/h87TVOMp" ..
	"3292M6p2BmfuMqujRm+12hHrIGdPeOyH3LyTDJvM9lvXtkhwo/fFpLrgAMfkkHL22HfYRjRP3tQftdfLfqrx46C426GhM4sIMnAr" ..
	"M6yzI37fKymIXeG294lLIEerjtJK7fhvly7KPOV2ydlMpLMAAXicsZDTTkU9a8Sb+MFQNPO4imKx0BJCAP2sfFFFkVlQe/0SOp8+" ..
	"t4s+ySNeafOvtmEds2/eC/miBkchwFuK3E44NEVd3x2jaV0cGPUahwtGMluJI9UmtkVlLg3gYBtfueXzisFZjcKnaxc1Kd+HZyRM" ..
	"MiaBXkgmVq/wAxuL4E1Q3P59tQ8Xa5nFvJN/bYqh5M4in1nypuaaaVPapR81uW/Z6AO0Yqo58j65ZX6IOCpzYdDX5Xd3QYjtV9s1" ..
	"H3M0XYE9sELQbbjKsB/SPiyi/e8vvRQnGJWFNqKdXgiwGtaUPkc0Uo1XdZlTrM4dA5Skl8NOXBDhmek3G5RP1KKZ0o8aono3mbli" ..
	"2LVGffbaQocZHYXvZP0TNT1dCVfHf6Joi/M3T3z6vagFwuJptxaa3523agNWFpBogzv12JokJyJwLO2GksI2xFEE2MqYQXDJQ4O7" ..
	"wZyXhw+B6LW1KyAWU57bVgBVsULrVJCITrBUkHkFnaucKYVyufUxU469a4ElwUUqwJcHp0BxJ5wqQ8RLIbtX/gTVsR5Qu1wM96b2" ..
	"eBg5WiK8QCWPBvtsxb7qSkbRR2pvJKDAz5UEJ6nHcjxyv8XZz+E2TdOd98QDOuyuxMvBGhpB0WyJ//Hj5mTaeOZXlpY6UfbO75IM" ..
	"2/9mTAWTHeDLWigvIe/hLxqrKviqDIlxa+avdra/X6i8oU3fk+A3AAIlLOmo+onRu9oW3QZRa/QKGmfPDnTjjecu8m8hiE2qCFPw" ..
	"gZnb2xqOSgc6hFnySAEw4Cb7AJVikaSJ1I813jAB9AIy4tzAIsYp16UA7wQvT33Cp8Ak0LLZpmrjodu8FBZrZObMRn1/vY5MYiJA" ..
	"y7iU6bKmlFP0QKWX+VaIobDJn2ge6kCA0S1/QUT7dDDtLsumHo0JrLOkTWCKJiWjYHcXR4GfEP9fBzHhsVyU07oIwkcztFIlDiZy" ..
	"pWRhWulgj9eohs1Wa0P+0lt5XO4ctfh7HgMarsrVI4zRAQrr9KhXkiPmAyWzYGVwiKMDk9dI2oHOvTu7AdANIf+xAEd4mA4SEKJG" ..
	"5sKb4nKdLJpSGBZO8W3HJLnUb0qYPJrkEXSwLdby479BnVc6fgdp4vCM1oBJxJfW7GgNQ0qOHkz9zNSYsfbhgkxxSZuZ7hvbpHnL" ..
	"knvyu7LT239EzYx7lBxZ7rGl5bn7zDFmAemgCCNJ5bpGJt4kQixGJJp20aBFIUKzIrpT1ShLM3oo2T9OkIsrWILdvSRZGblBzMLV" ..
	"JLTDWMB5AMdOF5tuqt0DkJYts/Y4sv4e94tWiuX92pQ7t+H+72c087ixec8d8VTbg2q3FmwIQGz2i1fPHQOL+8i1FC7ynAFi1Sp4" ..
	"uwFcpEz8d4PCBHrcUT6mcr0ab4JgvbjiQZ52ckrTgn4oxvUAcTCye0fNu72661W757MGiIeS0okyoa9HWoni2nz4BO+o+k13c1oa" ..
	"p/APEjV/mO/HVShUncMgvUyVJqiOqrZe4efb1mxHVEgyYtuYeSWlJ1qvqiDq1/53RwNCtdwg2Ehqjfq0PTYfWNlwjpJywV5r5CTK" ..
	"urK8IzQmpMA/VgVhcR12JvrMR6jIr0+gn3FoUNMrYZMcKb71Rlng0768hiRTKUA+IHx8Z/LSAdzEoOkE9XWA+Bd31GCu6sx11DtR" ..
	"UF5YpIBQpEryXrLPBY/QGMQiFuoUKAs/VGFtdOwff8S5/QTvPPW52cKa1zWtGy/Lw8A2nns2gt0hvRxvSi10CXTCVSKs0rwVkqU0" ..
	"PQqkHNNbl3SkNAnu4w6oZNEw+K/F/w3+ageriXOVV0Y8iw26+gfBHg2RWGeMxwzCHotDek4gd8XhIy3T1R7dQH1lC0JUdlRaWM1W" ..
	"4rIjDMLqdHTb0+OhZJhAQqJAWO+Z+nNMVT2jAfh5iU6CdxXp7LCghrlooks4k2SmjTlFudY1NuiaKn68bFKAMIQ64FFLqA/7ib0b" ..
	"7JhpXcgSJe3tfO379C22cEFuTSMDLS74AF1ohSQeNglwn4AgjObJRzMpepb+1invJLiDzeTPhrrXFBpccFSfBZneWx5lmJ0N5aBR" ..
	"SM9wPl5ui3KsapooRPgD9j3O9SgPw3u6dn5MhJfnjSXmfN8jKyUyfSr8EcgHYIQQx3drZ45tkmuDX7ISpO3MhX0XjqydGBbfOhGv" ..
	"SHSMz6dJpPKiNEZe/2pjJDWMbmFYQ1G+M487mDi0s/ofL4JQPhkprs4bHil33tS+JJWe3c/KyEt8y1fLJ0XBgM9mOc+/r6k/gzqq" ..
	"TIrwtjV4YrML9BZmPK+fOz4Mj6DpqpdIx3zW1NEGP0Nj6bvxHkTzILRNbMCDlhCME08Rbgj4X0xcxaOSi+GHOontadKI67U2HTua" ..
	"zXw/h2FTNbBngvrpSs9O49atQvMPYUlraFehBU/8d+304k2TpLwwZsskwlaW2LNUFcSgqvNc3FklF+xb1hBS8nlX8RFNbJA1CrEM" ..
	""
local PAYLOAD_P7 =
	"/iBTqr28mXRtxRj4qvIm0SPjJLDmODWkcarPA44b4KnoisFc2di5XoU9m79fdY8lprSeuyPE//iWl5y/ZQkMX7rY2ULelPWOV7xT" ..
	"gWkWpzq6D9pgTkFiVz/euwXK4gdl7VnGTbX0sPyMzjJuTKHqEd9wPU933zpqbUgxtCNzN5OCxg8bqUetlelMgHPFrkx8WHsP3b+Z" ..
	"9IgAFzV+DADbxo6HH67EXZ9EkAIrRHzfAB4PR6mKCTpbKhbqPa211cPXV4Y5I4Jo/EvqldfSWKw7MOPQhtUev8JrpRN7jGhfmK70" ..
	"LahKCx3x89GEq9KWq+6J1wVi3SYq8cn+YsUe1ZJaIzmQAX9/a0onnAG0amvQf5rPAVZ1/oCe+HKXTdPF9+Bbw+FSLTQaR8ia9GnV" ..
	"3VpBJfkTgg0UKX5mcKGXZe2P81QBiwhc2m/9UJpWdxMdBNWKi2ahoeKLgXWOMeAbJjnnv0RR83zsv9/JqFBfkSfDHGHiCV2hzFbe" ..
	"d14+Vriw5gazy5DXIFPymjbwzUhQq5LzbBPkpvOzUmjX0iM4EWILl6UYWXe+40KefnSkeU9zeqcBfi/+vEeF8eQ9TrmwuxUUVzFS" ..
	"RFlsj7HIEVmQZyE/t8AIYfu+YZCYOOb+qDi2NjArI4H0c52cRoKr7a/CEs8dCkRRSuwPdKjrn46W2D/XMGth2SsXWBrDwMRdMQAp" ..
	"0uDSy9Sccohxu0GMg7k/jZpk/h+Nlq/4RAdwYVtHnMU9EKg9CNrW0wheG/WqyxhGdNs8YU5xlp8TN6BvWydsdul9fa9yLSit5YO1" ..
	"fLEBbkcnsf4gdR2JvJEgZMxnOeqI8WYqsepCzFu6wLOCzNeWTe5LI5LkrlynDjUNPWzuFIwLnfQs9jBmPYaPi+d4FZvwjWLwho3Q" ..
	"Sq27sTEf6+A+qLscoNGr7wGoN9NS0NWH9BKZ4+OomsiRkXYlqz9JDhWlJOCqkekIoj2+HaO7NRTYlspxwjBTYXWuaSp6SWiwWeBH" ..
	"xYPIbPeTxCkOEasNqtfbPSNl53ndOoGmNsFBSyp/6cvryDXLu0qmtiiwbsNbScqlnBPW/KQPLIwTrX04WqnpXAjC/PLcFYCfMwzN" ..
	"oTR73b69qWCcaGs+8m1nVCfUaqYv/Fg/u0gogdlPCdLGMQP6UdT0YXa18TecuCgP4DJGbUQbsRgkSaAsgWi/evirfyPKwvygj0hn" ..
	"SO5CnhgekCn5j8pe3tEwg1EhH3kP9a4WNYP+6xj27ltljuvAvuLjKVVz8U2gUgNKOzo3HTu6Z6bpS5Pj9EnGgRD15ciRZtTZJQc6" ..
	"XvVERKEIgLlajPoj63x7aMJzM8wFIVWPhyxYtY/xiSzq2qEZ5+zx83q0el9DxDqYWwcYK39c8GDKgC5/ltGQcR0qd/WXaypHWmqX" ..
	"NF1l4lCrbJ+rUmIlHuGKFiMIhvljmnsGnRdlHv6LIqYSGtBj7EUg1FcTno8vr4Ls8rk8i+MUxTc4t14DuzGp7Id2RtRhs4+oBoJa" ..
	"/ydEvzrvF6FSecZhpjevCldOk0vQBPfq7w4XhRDXCCrAZiuq30+3Vu+JIPftuWzi8sX1EJXfGKYdf14uKe+12tblN26qzZo0jVSA" ..
	"4kBDsW+Gdp12+C+uiptfbcKx/kTtcxKpwr1D1pzQvMn0SlLNajJasgJHIIzpNefkntEeiSJ/Rv+SSQDgE3OxyvUejs/R5t1KSOpu" ..
	"kJZESeKIzcb6sjjO7ydjFlJGOET8dV5JM4JxtRHTWbBIpdPGaX6gunuMQ5v+KHhc9H11emti4MooEWb5mNX8doUm5IQFO9kEwZq+" ..
	"FhXmKkDb8H9DhrrLcLpNk7m1CngUdfvYNiQ8P9f9DRgnpixqraEfCRKK//1dn6f6U4NoQ+FTHf2qyPR8T5RU1Q0Fw9KJuB4rvGYk" ..
	"47Dj4C8VH+oZCm3pZmxqmGGV914fKS1uU7csGCNlIGsAX/aMCFJxe0AsxtSSsWTZgM86JVQ3QPoHa8z5hm6jxFWZjAvb9J+71AlM" ..
	"JCqxtcfcd1stPBQIddQGnK2VGGhSxTHNttNx3t3jmhie7sKqcWVKyD7p2l9m2ofVfNVzyen9ctWXUhWD64l6iHGtGr5qjyISS8SP" ..
	"tNtqRJSJGrFs8q5zzw5BQ8+5F3YWM7qYePe5N6huS8fnMqjxhjhhT7m8j07CmvzmbTTR5yzuCO37vxhGyQV9PkjKjASnFDrFB0cn" ..
	"LoTUkzIIaQjBX5fmGdF0tud/f+zwm+RUXkb6nfZffK1tHFc05O2twsV6IsJDHfP37cOunjpjOHrc7MnQ7JCBDVOjnZme4XaxWTku" ..
	"7V8pLHoyE1V4LLSMqK8OmMBho82N3H6lxq5Ctg/GPO1RwwkxNjEzUHkKM+yOpsz7eEp+pFpjDl7+ZZRpAJUED4inJVHF3Hrr9WjD" ..
	"RfpUVmrBeR4nlUXiB6ZmJrb9vjx8FBEaUCJoQ3uaHBrgov3WbRFoUzmDfGAqDtSbCydNVSYvy7VrA6YJqxreqR6F7R1YWMb8zFbi" ..
	"RH5jEGfb/NVCrNoOI8jnCd2ocpZ6qNAy+vH4SLqtnvp4CszCvKSsxaddodGJ0QrPyW9QkUgcuf5brf5RNPg9K9x7sBylsgFmIh/J" ..
	"21XBZKZaNZWQaW7vAPCt7k9GUPAZFrZ/gQPfWomknrhhFPti+UPuUA96RRwF3vZU143qnw3dE0hwI45CIwBcaa4wgdmg0ZNenfRf" ..
	"pAXiHKDTU8tTqKuv+5PlvTidoxcMFw26mG3Cus+N1TB0VwKR3DHL/OuiuH3ViLUgZgNhd+cdfWbfpOgHPfulEbwMXpTk3Gvp1zlM" ..
	"NPaXiC7jvCfquOZKmNQLkriqRAdzefSOnWzzmDy43e0Dgl+X7oXFCdM8ksXzGfDTfUf2yD7BkFiRWMCPhwgYT23kiCzHhZIASjWo" ..
	"lA1vVUO6z9iKRtt8BbK4f7aS3MSX/WQ8AbehvS2xWj0W/lU0ORx0rI4jZ+YbDEeFwz5I/sI/5aG1Rgl9hUwUCcCssC1sBEWiZmJw" ..
	"WSAMTL4kpHad0p+LbNMFSm0cVDiKcLpftmkEclhkbeDIjkNesh6r0ixgu2X6nlMwVgljCLezbO5ABIT6cY37uMvvXRRB5b6JKfDL" ..
	"7FIrD8Tu5PjfMtmcd//gtfST21N1WctEbcPWLt4QhgmitJiqTOxkPB9R0nLgFuKk6/EhLud09nWoX6gVqRBXepT64yRnqaPPkHra" ..
	"i9gkoNQEdbcZJfN73Na7C5YCwHsZ1ohPiQo4nUbDzqER9tBnpkkRNXRHVXywqXoPxQGxr6ZB5M2ubAl33WOsY370yjjEomfh4+Oz" ..
	"r16is422M351QkS6UgOZfBbrYXuBuDLRToT/AUyLm8C5AE7jXP3Rpw5yeudU8/b003LoZ7HtUnrDUKZETX87/pY1fIAYJXIkUXiS" ..
	"9rWYk8moW1J1z7jyO9UZbn0TN2XenXzoea+l5qUxZQQXUrrIAydoGazDQ6n4T77evQJITjHwEMusDUJiKl6/tjvedS+PKuTbvbEC" ..
	"gOeKAwmuSqm7X+9vcPRX0yGQoFJCwSXLvxNdjNgJPI/He+O3F/ilabUzzEKSLRskKHiBssVV8ppBthfGZzbNStvEP1tUFRrvzWya" ..
	"EXp5KuYIO/vKi800Qn1s/hB2UP1vNWpL+kEZxBwxX6wfhH5qVr3aRLzosDbVVIeVcuA7srwhRsi3p5qCd7ogtlYSpEjtIf1TDaoo" ..
	"2FmwaJFn/dVwM5gscLCRCRdu83lU3z4vLOEGd/zmybNCOjBwJJFcHqk4/P7/R4K3fRsaQsc0S+dTwkOdyj2NlDJn5CzZfjfbJq13" ..
	"BUfPUjnTPcjEdJalIFryO6J9VqLqP0jOGNfsg/KXR3b24ZgWQSjXCQuA74S3U3gLVsljWGVXbiIxtYHF59xLq1NBz44iifFjC3uo" ..
	"1JuSGLWNjE3h26Ru+Ap5r+KRMNGI+PiBRiry4NrF7opDxvrNRuP4qbmNRKNrch2t367AfTgtULpM3Hip4EtbVRcqgeKxNjIwNV05" ..
	"rsGL2q3H+JGtRCdiROrMcFObvpd/8ch58kQAr869rd+ckhmkrMw7iyfwwONQN5IYWUg/vhOcK26OlLZKyX8WAaaLgmVIplQ1egC1" ..
	"zGqg7MdFWClQmm19Cfx6LfN1kydEehTqUsGVYILDUVGPKNJEz+mfk4M5IbVTR4BdvqROAPJYHfi3aqSt/3QNLYiqnSfckyERtaVf" ..
	"TVzwsvS723IuPSTQxn0IyCwDNYBpuHgVTG/1mmh6kn8llgeXq2smxmRK1YM6ETFJD7jvFImYaiibh8Brjxn0ljccACAhlvhkBLso" ..
	"DteTnL4e7XIl0xdKATX3bpJZ5dVHJGRWJD9cO/eQ+yC2eOPpvkm+So/ami9jgC8Wnu+oCiHfwCKHFsG+DgsGuS/7VdST5+nskLDM" ..
	"6HSyj8n96swZ2rWfQR6ZcPRrdMLlMaKUoKkSaYEnlllVTucu9M63FYjg8NuX8tpzrZdCM3tMREYmQlCe/DlTawxF+b/j7JdCsMgW" ..
	"pxsjZtvxAIhKKHtpwOzGruFOb2pnOLq4hbAtuJGNtwPLEp4aDHNCU8aftpKb6wRd7e7gDHmeQhjJ33pslVMO+ZcScUxmiBQKNmU6" ..
	"QO11k8lyBB3DrabxxHMkbZZP8eK+ULDkzg4LWJvwvPNqprJXggJhKqeVHCYf/oZewyc9TYRcPSav3R9IovAgesvcQpdMY/3QpgbJ" ..
	"/I5ippZMrWM0CsPU3aeL9/0PAn21MtG+T7r9rIwW9LHN87wkCoLBIILhWuXSfHLXTnw4Cxmr+gOoVMexNo9gMtbsKv+jQGM/IShy" ..
	"bLJBJ7PlGzHtmHpoZqVEH9CWe1XqZLgC3d0Tlz9rx8f5ipsjIJMpXws/NjOqYLR+mjXSd0RoLnkoUT/bNJTXYHZ5/NNbqAxb1UG4" ..
	"mN2D7voqtpTm9wDoYHRA6MFE0SOoymO3biV1V3RerWxoCXdoJttwXKcNQwNrBgRwwt9hpYw8E5iG/TCawK6Wum4OrNnSUa+u3xvJ" ..
	"jyqnrPDX/S8ZaeI45Sp9nxgTsKoEsigmCanFZVrnMn7AfJstCZ9/JOxaBcnfjpgLdSHsj1SaOw6iz7XWgZ4gJfPNtgoJzQu1rQsL" ..
	"biSWVxEvJYF3WSU0LTuLUOJ6WYI2Vd5/vrMSXX7dgdoDYx0rQK8E+Qjy5iqsY6OKPgutSklmHptFXwP9J/7NAQwy8DCv9WwRMcMk" ..
	"c9DyTuw9KQ2iEBeysmitNhFu1Hr37thfIwbCU59eRRADjVekE5h/abOb90aKtv3NKuYWaySRd5GVph28lPd5vqZ4Y6QPr8JBBJGL" ..
	"TAzutC9t8HU+siLR/sbB0dkMnDktC5Uto1NaS/FEN4q3KywlaQLMj5fXg3mI5mRUPOxAkwXwDSv+5/UPq76lyknDPKCgmMzPkLNu" ..
	"fYNGrTAGak2MxLtbee4DeozcHHJBgs6iUAwxzffRPZ9cYaqqUvfeoc2tdDhg0e/co5SdfIyCd+XrrrYkKgBnv/rJmRSvrsPw8/aG" ..
	"yvseTs/PMG01U6tvHIAAC/XbjVgQ6IgzDBYozL0tpfaNw5ESGrRZduNQG6zbxMPOPzLw0Tg/LY2HIqZnzW4v7LfZ5zyIFrtkzy76" ..
	"Z9ZQVpShYFS4FoqoP4icOa0Um1nZSRZNbJUG0lKOY7wQ+pIq9AbfclDWFFDjTV4PcU6UmqUgWXVQdJfmiQbNiHDOiHFs+B/M8TAp" ..
	"WUBgXjh9gImVepUW08ldkbSoSKMC3n1Cy98xR2iHB5XswbGTDiqFi1h0A3ACzuwI8DRdrjRdWtyM2FEXz3tcVzw7n8YEl5LY6N4R" ..
	"mxODyzA/1aZyCRH4+ZyPfD/9T45beiLca3AQML7i2R7RY2mTmjouj0ZhqkqmyXKrb1oJr1XbmNiJufM68ZbqEjs2AM0w2Va5gRzz" ..
	"cX70IyhF9YzPbDCfcsgWCmUNIp/hdy1w6JjLRjqK3+/mrFbI6Cveg1ZtfH1LTVjmZx38ACbb5sr//zip4b+gB/VCpUbMYZCqDkx2" ..
	""
local PAYLOAD_P8 =
	"2k9ipiea+uoiUz5VLzuFnhc+gk980XBCcL82ykfOlW5OMV/KWd/pJDWOETTvzKlK900eVWg+NNZtuw19L1EgPuiFRBfRQFm+xyN+" ..
	"SOSUHalKsFvHVODACXzT7dLyieNSjBuIZGo8cT58JSjXznxWRUBeUD3g/5kRgkclduXzHsfx/9DU5D94Vu2eHQ8CawNMeZXEnWna" ..
	"bDn68FTfhxFNiU56zBgwr2Gk2L5LdiTo85wCVaCZpNku8RypqYh39MgAn3UjyB7t0DnuHZ4t4KEtWGlUUpSYmL5w1ZIvH5hMCLH+" ..
	"3sduiQgAbElpbNesKhNtZQsxeQ0irbs00/vHvx8wjsp8QN1/8OXJIhowfbDX0kV6T5xv8hexmCt3dItKraLBUuZJKdO+Q86JITDS" ..
	"26gKMBJhbJ9nS4pHJIsRNhQesuCxuG1vJrDu4PFI+qljGCBdAV1aYevGv3owHevebIsfCAt21evP1diG76nLE3z3XaKcETsPG/3d" ..
	"JKG5ObMlsJY7HTDBxaJpWnLLWoXvXJPAGeahJz42m61V9a6UINI1oa7pG7SAnRRcHNt5pHWev2W0M8gusw8DPgbNqbGEKyHUyBe9" ..
	"Jk9LIA6WhN2cmGktY3WJUoKKOhwvZYIuPBCqXiIQYPzsAPOBLGcF52ls8LnCSZ2NAURqZVWq+TSMF7Z0k6ckfbkrgvdPaKKrIrXF" ..
	"TGrEovOJrNdTpcwRegOLygkgfHE9iCEUyptAXBMCI9ba0z3rFKCZZZI+G40TQ/ZmzEDeaNQF0eKSScJRbqon4lLO7hbawj+v/PYv" ..
	"LSfzjuOCCCRqtuYi5tgOFc40UpGI0TMDsu2lHW4ZEs4e5olxqgkiPgCZPHXGpiO4EWJCbF+VxgQRVRtm7mWystxAnq/r21ej84+W" ..
	"qR2ms3ImUZhuF7h5rnDjKTLkr1Ga1iI2tWe3FW7pAXrTuUfL/7h+DzwWw7v4YgLMXx2E3J9iSAqGziujFHq7ad8c/sRBbUeYI79X" ..
	"pOzuOx0Vqw0Iwu7sK/4FDV9nO6Df6RBLcAgEaJsXxNNrq4n5BZKe96/rroYgk2HGcTg3pUt9JjBWw1WDLmwYRf4J2qCRtgpLIC+4" ..
	"DlkYVuie+u2pkX8Msk5bFK+/WassQsfKKjRDE8tGBFFcG0PtMRa7E/yMkgie4dy4/G4gt/Plliu4JToOF3RPE7rhOzgaCaKp8GHj" ..
	"4mGnakS46hUmB1nJRbAUmnD9r5L7iES8hDFY+qZp92L4MdC/KhCjrLfuXwrcTtqIIPPqbPCk0gHhaqLj7a7wpuBbLRXqdZXiIaaF" ..
	"PoV1kReUAVU3wfQD2GaxkC8MLqUSnCtVPOuuruL0SpYoOKMrXeV7laq1Axw1ZNJX6HW/LaT+5wCHe5l5LrRP0SPOEFaVFT2bLGwn" ..
	"D3al9aGc2cucA/0GiWMOIV/qXwr3J9iJfnan3ehjOmbUWlF9Tqw17oAd16B1SleRCexaMohWwhrtJcWyN66XJi6rozafW+TXEAOG" ..
	"QKPyCPLyqjDnZAF8TkvYOkkBNoUCeSJEbM1LSU9MVNWCU40f/TIUqrshrshVL2bvJRqgRrcNVDHr5wgf6op0aFTCFM+uct55HoSj" ..
	"Q3slO5b3a8MZpMA3VblTBwHn7tWTaxuKzYmdGotkaQEK4OvnYyqZRmmluvC2y+1KbopsDc56dq0XPMHyQr2upCSPCwgwXW3fFkem" ..
	"oSQ2+C//KaVoLEM2JOSw6+QFvAshBdcmPR/jW2aStkRhyGjg7TB2sSnN4YzmfmAacMSCuKAzHdy6cM3gnD6JIaUW1Fx+VG7oyQs1" ..
	"uEl6gkUX0pmL6ndPeTX9w2y3GMImEQ4cqNxYpnooL2vjosQ/yjbVYM5NErKvhR5JMaslt450rZJVSLXuJBSEiZqLxyHPXDZRDVgV" ..
	"qFjssADg/G9Vp2Rk82b3zLugv+gcGRTZ1W7wCaZdXU0I69/u+cWSlQIcXrBasbHkcj0SODEuxhES10ONj+EHotQWrCZy5z0kASWE" ..
	"GEX2FXK0HOZ3lkjxGzTRSjkCpYhPkOMvuchyfUfznf+YoZWJA4y15RLUO3LDhLEVHltQv/B3uEoM/hXzW7ubaRpTvkhBasqD7Rnk" ..
	"Qia9MRPNZND+tqNUhFweWnaJyINhSlGkax56P0OT2tnEoARroIJvfSQkMrGX5r4vyqIV6PJDlBrpAKXaWpxeWIw0SoP7GqpFcisQ" ..
	"Mpu6ZlohFqu0eOg7UBGiFbvEp/niIrsTw54r6QDtYwp01uM9NrB1G8bddKGWqPqI/pEqpx+o6PoOoIj++Hw64Sw9tDt5bopMnigM" ..
	"B6T+k8bjAEIfMA90XcfJRhcKxjbtkWO+XsuajGFxzbdLUlTBZFValNznZYkMD9G6OyUs9h7z2Wc/f90EwF04BvPLrWTIgYeWqwJ/" ..
	"W2te/jqpb0nmHIt4VYA6UHzk+WCL876oBDFbwZUDzAlToyanHjkWpjDebkXgPqoAWuOlmwAwXd6Jx1n4ifE3ccI21Z/LpdzW4Nkz" ..
	"pfaOlFyCBEcnA9jXl3abb7mO9UM5tDlg/dfCDmYitvyjzk/7MuoBxNt71oupH7TRIvUFWBAteQxo+EO5bc7XDJt5EBAW4Q0+WuEZ" ..
	"ruW+pkk1xlhZNz9lz+DmwmarJUz7zg9nbJ2q20IWx76yWlo4lDmhLlFXcs+71HpBZEkE0emEATMRVEqON4O/kZPMfhSd7CyDn2Qp" ..
	"EzDQlpfVvw2gm/qw1074GRDoA/XI3L1qSHwxpebITLpdXM0y6SCJsy64wQcDr/OEWxn51lacytdWSDpFgvVsBb2QmNtMyLQIsxyV" ..
	"I7Iwb56lnEIR69Hw01Y3O+rCzmjoB8R/kAyRW08ko1VCICQQQUT2VMcpo2Qj24reM6FbesEpVHX+7baUAUfmhYLzjSbdFB/0nQq7" ..
	"tSzUiAbWtAaSdsV856tr3LdnDfYzZfF0bW6YG1pVft/oVbKzWwZaAkOZlp5KGXQH+O1wNDvdzAHrbqaz8SV/oDAEbQs+XzzhlKBy" ..
	"kEYzFieh35HfKe3i0XZzK5wwbZRovGoYTOQduueR4xYRtJIsPgjLe4lla/0fMjWOhHjHpSbHzkpTPqwr8VbvStyYhfB1FinEYPAk" ..
	"X9QviPpAt1ymwZoyGf+qPawFr3vumrpR+7rpZKj5quDZllDrB6bmMW39y15X/8JvKxK1z93Zdmwz4dK1/1nMUJFbpmQJC+s/KMXC" ..
	"toiqKfzeo7GVCI9+TH9YZHrJddKevnUnJ8twew0HnlNfxZG9rKkj+xFA5Wbapqv8cCLLrRBaLzMhazijXtWmLM82ipIvEBQkrlqz" ..
	"cavVlZd6Mvx/RIgHz3w1wgSYU6EZiRFQy/+f+FzbF891Hx+kKECya5nx38hkjaXRv6EdTnXQnH5DnwPdr116OxW0PcaqDOvutR3M" ..
	"fZmeCKpyHFyRABlFbndYlORIVhWj3883GBFFkGP5/maNIW7nuCJ3JlVjLiXBTgri/dtdm//DS/UznWmRinzAZxTBBhb8LK/iqaYR" ..
	"9PijXeq1VfYt1mQQIQ8HdRi3G0Ch4R0iOuY0L3JMfOamS2RGgoaqh3SHT+PdZ4aKaVTE6+7qLW65Ylv8dldQE4oEClioXtB7f4j8" ..
	"2d6+tZK58CaCsHRaf/DPn5/Xzs9GR5eCy2yGEMHSTpBUL/nwppKNfCome9R4TOdTnvlePHn6ZeeuKhvwzKCanwhXePIetZrgaSbk" ..
	"AMQsfIDJdA4eo4H6FHpozovkM7pkV4N5oIQH4vY6m4UWIrwhRhQ3QZNCiUaLt+gGROM4z2dknce8GHvocbugBLWuKadcjk973uoW" ..
	"ZyXlbSXA0RV048cfMCXkg8X1uAEt416XGCDnUhQbVd4N4aHA0vqQXFAxjAycmsImolaEsGMTw0tZVqH0UmW9MUkmZqJroGuf8H7d" ..
	"K1Sa0ZLH3hs0dno3eewTKY/zlvolOsZgIRWM/nhuEbEGJ98VmSu7tAPlHqVPSmNh3EWruo3fLr9SWNpy3gf/lkQOgNzEuND6iwmZ" ..
	"S7HSR+2NTwRkDX/pBjvkTiOc/KzqR5EIoPWiUVz+OMWImDOWNIYiVAwtjDFFkpGWdRtUSJFyRVgZ2DqZwi0g60Aig2KGfQoUEuWt" ..
	"EBT0k6cnmhErwnHvcIVIVtDUmi//qTsI+JRpcINxaGkJUCqeSmHDdL1pbpoxEoWF4K9oDix/m8SqRZSiSbnsXFSGX56eEi7xA++d" ..
	"4MNbgL93n0Ds2uY6SiWavFCNh9lqrP7xBIMjB6QTISX4tQPlRu+iNo3icjZXmwCZtTVgpbjvuzkL7g6cyUJ1BZLvQNv76QqHky7A" ..
	"DhTr816TR7Q7u9eNBAEOrM4CW63ThnOv4FPpbIyYTO2jqJVUwZFoZHWQsMVRZhkOBoK3CmJb78GTT14kXT3tPTtpmikO1W8++ouM" ..
	"sHqWN/MWOMmTdAAnS3+4rmdEpvCwFlM6I8KFgapBDlANtws5Ipy/q1rnXhMOPDVfxqhExzNpD6A0DSAdbIddbQNqQ+0n/TI+ieXe" ..
	"FPb+5mXQNijvpD08+EikGCadqwnrRDXAm+gQYQYgFerluN5cKhyOQ+Fu5LfRHvdvNQPbzQj6dNhfC6R6QLkyPvHtcn6v9IqxQ5C7" ..
	"zmBcqHZP750YkRIq5B3eHRq+BIo5d8L8OoF3jPKSpaYfK1rjd8b7BlmYoRd6D3e7H0WYLZ02ZJcpoy0iDdnj4jZpWcbnRVICQPUS" ..
	"lWM9zMKv/TmQSngeedBAqcqD8Q2O/LB7Jdeqc7ohnfzLdhMSD/Vrjk3ZyE8QX19iH8QebZmR/Hp7AMIBe4mVDLu1C4PYQpkvcBT+" ..
	"PH9EwdG1W53fw2Cld2oq4QJIqweL0Ux+R+TSZ55MAZGghm2cU+jitkjj/9YHA0TNoVaFT9wa7S8rLJOUBAROxktbb54yqJnBy2ud" ..
	"W5XLFJZud/p63wQs2b2YB/pWdRsgD20SW/p8skrmARUmzVrr6loDj3xaSn3016gU4fLLdmZlw/6tgoe9pRFS6+SaAE48STFZHUvd" ..
	"ImiZLn//56KzMU9paYF84NpmJjQnbEntumyFxhpg9z9J2CmB/vR1TedBcMt9lR9griOj2D9x0Th85fryEpHzkCGGIYWEYTgTiXlW" ..
	"/Yb/nfpiwWiXCxyb7BiTPy1ooc4shKwkpAcRLATS2ApYV4HcnB04IcZ75jCN/guDhZM9O7M3z7JKG/goZRaa+UkQeWj1Hod3tAYL" ..
	"nSYPqdCuTk3bKm/CMtk9618yrua4YzHlOWxiOAqC/xmrE4VDhevk78nBypovxeYMdGYdsjb0y4/JoHOqNmrMwyXekIv0Jx2TBKPs" ..
	"ZJgrb9sszCgIWAMkSs4fHqEwQSw27Cgqm52GXoxmMrw/jjNHwMujkO/XiAxcSe0pRt91Wx+SPMgnWCC59rWG3KEhSkRg7F5SiwJk" ..
	"I22+H0eQwu3K2i5ItDKjoMbKbGSF8Xh0dv8+6TPkuiDb0FP6WAPD7UnItR2aXXWynSxYWz0u8HXGZ9L8pSfpxRwDL9m50hrKJvGS" ..
	"ROK4m96O7BF96rMHVZYrq7x7dkTwdgmpXVz1q8Fz5uAVrJgylZFtUo7LUQPHzIl8ICL9R+oJZxp7mZK4kFd3A+dDenBVpRlvpIjL" ..
	"o/E8YmrCxWF97WZhzgGs5O4SKodd4eGZ85lGcQfIdGKg3XykwnmqHMIpLgPDSNp4n34/3IrrSaby+YlJ/F5hxNEX3hEXRLhc0XzK" ..
	"1aPSV/DuoFSn3rjj2jmr7HYYATiNF3cj03NmkviC5ggeJiAmKn/ElpwfoVMH9bq2j95jQxUnhHeQbMxj1jAxg3gBjvseRmvXc02v" ..
	"BSva7zrUutvMHPvtyTtNNE3VnH2ikNiQee0UDEc9XHTxETd5DWV6VepzDuV1AsNiSdtRURkS4XvaNGvj+fjpgJ3fIuwsbG4rqLg7" ..
	"wCCs1BOsU+rBYYoTzRTU6V6HM562YeNZ2nl+UQZPc30+AwAsfyov2zgSW6w4YGcMp+1vbhJqpV8wvanjlosGc4ww/tHLxlfAsmVr" ..
	""
local PAYLOAD_P9 =
	"OtDeuen/12jSkpI6gcvjI8hZkCQy6BhRt8TLK7/H2ial4RJdSAyZti/kl214zXgZnySIdci9xF+Z2hXtYXwa6WglL93gMk+hPzjB" ..
	"7/7Wq29JIw236/nheR0GrgpuPqrxb2WT5n4xHsjDCHG3xzqWANdKYXYdtqndL7Bk5UD4JhNfO8WrWrqLLYLLarNWiNI2e5Z7ytQB" ..
	"oIJ9fT9pGinv7HfGXHUto7Vc7LKTvcUfzSGO2bKyjYSbL6F/72ock3DnXTAyJiA+DIpF5DEAaqk4wPqg7gD/1CkCG9FxClilAmcV" ..
	"d1Tndzlz1bMA8BH8mugPnSWsnpybwTg03o2KIntKwOJbaU+eG34pdqxQiOVTZr/HZVutzTHhEZsFOxaCfqszxczZxHriKnBYzPe4" ..
	"GI1el6dwh+TXDSn75W8hYze7cnx+kw9ORl9ZgjYvst7P/yAUPOeCMsZ9UBosPRAvNSSGJ+XzsFH1UUMYt8NDdRKKv39Bhchb+5dt" ..
	"kPJA8cd6HtgX3XtlDYcu43Ag8XVEjMLLXcnIkM7hay+QKNy2WLtAXbgfEaBnPz5y8GWEjXFYxXSRbYk7/Ir76dhyeRorNmrspXKE" ..
	"lmF0fUVonlgXO0uX89PtePVXm6aqTa3hFffGILHdgrU73iuVDBR6f51U8DDYiXY290Cto6sZirOyP4WUMfEm1KvBBOilFRgqFEu6" ..
	"rgyb7396d/mqOBH89L+uLEcFjQ+ILuwdvZr940/dETlSfp4LjLE5+c7dI7+pE3MhnH40DGScrDKfApnzDSNLm0psI4pext+GME91" ..
	"4D51/7+6pXeBzoga563wIQH9KEcAU8CaU6ekC+fNQwZ4VvgTqQPyYt5SN4ffLVqn8UM6gMiuJFUERAKCZp0KLMbIKrB2SrRZQaBc" ..
	"1wpxa+mHFKwQHaKopcRUocQqPZXz5mos6CCHT3l+JXA7MSucZpcimn376UPHnV7ZvRoVuJZBuYR0rRb4YxBlkh4t5uleEz/KFd52" ..
	"ChDOmYIWZh6U7lsdrvrKtT5ufk2Y8aEGl9ujEJb+F0muRfa7ESSY1O0nKX32t7fhWYzjcDPVXreBmS8fKhoi8MJ0wrp9E7S003ih" ..
	"b+50KQ84qn3y8QJwL7+6EDavTnPv4W+61AMZ7SZzeTtokKRnUg0Kc4x7dS62YacbUcaZrprXzKiYTMZss1RXRxJAOn52jCuHocan" ..
	"GFT2SmU2E1P8Ue2NmuRoYvsnXaAJ8rWrh+a3Yy1Er9By43CIbcpn+ZZow5MUWHeiGNqIKv43uMQPTr+h9Na8CQOsVhBuQ5eDJEiq" ..
	"81+P/3/yM75Pivjuz5HweHBxB+rArG5GclaQG7dPX354tN7/MUlE+LCBoksywH4K7uOqH6YDjfLm++mrLUKbCmD391qMVAFj6bcY" ..
	"+9FQP5O1jYHn3tjsg3jjd5vnLT4ylXs/ZqB05iXHVPh46ZhlOiHWpCawSIFoC8oLryAXJzllVDvfKqaYJ4sOWhhe6cFj4dtgcYlX" ..
	"pjvNvmC+L4EfrmphHs5mPmyRQEvwiHlIgd4FPF3wB+fnfTqPOU0DiPkQYOgr2rAYbqO/k1hsvXuMoD+woJ0BAQC8TX5HAdjfbJdd" ..
	"D9nZQMaxIT1pNR4jMctCXvVuq8AGqBzAiGP+5cdxEK7a0rsWl+f/onU1UgftdHU8YSXZfqKM8b/QOrEqtbozevUN1LMHfMxyhFji" ..
	"i087jVyBOPRy5sfWlFnFA7UyjTugK1FYSD9MfazLXCTK+seFdHVc59RqcdzLJDIIn1ifuWa5CcN3zscMaKQSERx7sAOvUj/JEbrV" ..
	"3uJO8WTQbBiutbyPQUuEIZeRxgHqGzBqkV/38bDVBioqVmMkJnJ/BFKOLX7mAxlCdgABB9z+T51O4LDxOakzqLjD212oLaFjloSU" ..
	"MDlW/yUjuapFs8IcAjulnsCnppBlXgwSW7b7SL6+Ow5KmyLVJY0IzuwCiG5te6opwOVmJ9BPqPENblgqaom+nm2zTorWmn2QLaGh" ..
	"gChu3aBYabIaH3QHYwbo/QDnZKc+YOvGwVyYwgsiCxPvbCHImTqGxGm87uWMDgTS3InkLdP5b/eeedDljFSjLxiQKYKnQ4Ge+8/b" ..
	"0rp7/dlwyn9EUM5A6Px0GhtC3ng6vE2oPpkam3ESSSTgnqHT0y85QlXnBb8SQpv9AcBw8vECLKyLQ50LzauF1lhWbw4/ktm2HVxS" ..
	"FgQJEA3kb0m7JL1RFiB/rOOFmWgRhTrAtm2PTU9bOYxr4NPtv2v1XXXXO/OL0/S0Fn4rTrf1JozxAAnFsQxiI09RopzW016/XSKb" ..
	"g7BkHyVLpTrglEl/u4KGz1d2C/UXm39mLD57V2lMNemMJcvlxk4tZGtIHgaSJCYJTOEqefXaHM72OgLTFmutERKZu03KWTVIVsMc" ..
	"d8VpUQYzHYksJrhJsNI6BoGBTTykuMDFYbM+hEaYSXr5608cKicqjD/SrpEtveQfTLIStx5SA/lmCYIqnkAPFHZcyUDHkTc4s+HR" ..
	"BRjq77co00IGt92xF8jLJHEi9ScFatoNdw35IkPyihImo4EtN0HM4tEDUKXwbRdON2TWilJYnnq2eLqY3GZBzqDMqVw6pYszh4XC" ..
	"gtFP+dJ33dPVSJ9Wddz6sKPFCyzJ/UFevBXl85BwSj4ajtuxWN9hEgqyuU1myRAwzfu4Lw/yG43PjhlBkggTsVWEw6+3QXN+MugW" ..
	"N2DVbXCINvvZ7CJASAhF1ZB80ZYTfqRaclbQjBOCR6B+dKHxq3ioutUNw6+ComOZQmZKGcf3409Ke4YlgG3nMGJoet3DOA8WN2WI" ..
	"sg4Do4oPxBdQHn80R/S51iMGnF3944Djd0PpcbBzVdU/BfjFzk3yHA17+pNV/5SRhixujyUrDX4ectcmI45SP763pfoKcXwpJpAR" ..
	"Jh36NVNbe/nGiw6k8+A5neFt9Pl4saKQ+1ExtrvQJ4+4pG+ewqU+cQVfxadCRoNThWYEhZCUgT1TGTU1PsLeEdjAUnePVxui+RKk" ..
	"gYWehD/pb3/mfVVuMqL3ONX60caR58lPFlm6Fb5Z5kGX82c56BOSXE57AkBB99e7ruCtvJl+0GhvI+8ieEAM3yOZ7VTkv0pzRMXt" ..
	"UHB6ux6AeAfr5bVPz+4IuEKmA+QvmSMR71qj66gVeB6sYl4wnVgmBZ8H82ru9Vzc9CFrOBjrRgdzMnG4i4+fobsy3BhKBA/m2DNl" ..
	"qaflM6E/qPNi35JHBPkXsazlMrp525x8i5HS4OK98s0bjmuPOrKTMzyksx/4rBuQU5KThaBOXvH/YYACzM9mjras+I+AvSEf/Amb" ..
	"JUetkHEiyZDvtxBqHl0HH4S+l+2BTtfvPf8DaLM6l6x6Emy1msEC+3aKNBuBwKf8NWXlUrnzsQeVKCUBueKoWjI/uxw2yO47XJoH" ..
	"Bf2R1iIguUBHMSoa8lsHLFBYkEk2MmrROG+KqP8fm7p/Snt1EkXZ4Bw2cVsDUfGhE39Tnqop+QeCbBhY5ZepkayBsu81HzY68Uwh" ..
	"cOfgItJ2bkKn1MwVvEBwB3x3l5yb1V6k3Q/ohxL0hSxzmv0vHxgz4OTFEP7y1/YWD7SzE0W5xL0l4+j1xAavsh57EoGsnNhj3exp" ..
	"Bma+rzsbUlnZvsiCzoLJjnU3X79YIihXBbDBqbvL5gDSh8Eeue5OwnmjpAr9GuDicn6zk9+7yOT5qs5gr1kIPIBupYast1jmw8Wg" ..
	"rq3Vjw7y+BTX9EFML4W6KV8ecKMnfv6UKyK8aZxJ62jdqulkLk7FBgzAhwlbDgB9K/zjuHAQc9mqE7qzDv5GhCYSBMrXAe2rpeAy" ..
	"XdXyZhqLgsrc+47vAnbNATOX4xtbycSpMIAxy8BsTJxRQ/A9FDWhI27qqp8XkaAdLrKJY9bLFO3jk3nXy9DzVptyXdTxd9klhQj5" ..
	"YDW1hYooLOWDq1pIIL/YFEz9GE4S0+uqHNzb/2S4zR5G/SByKd6fw2kMrzeEqxwVjSKD2SqvkrpIKtEFcxEPPAg9s8fBmfEKoKn4" ..
	"gGghugR66rchj+KlqVqSRjxGFrRh68oHBtG27tkQa/1Qj03GhnBMoAJ3cNonTI1PZnDKLZWCRPeuqgMo5AnJNQfUKTd2Z639WLRV" ..
	"2yK+lz6TNe/jO9lgDQbDffypkiiMECxdq+gkb4b+4Y658tjrJbnvglqAQ0JlYduVAtNonXuIpa1CuNUwZUGprgM9HQOQj1WIYudB" ..
	"mV0WtAAPArPAftvxDmWDYNay2YfxhuoKPU0N+QQufKfZUCAgr56XmYBC79eE6hGAj1byIeH/Vedw6UiVWTDPzgaUaNj1iTNkKORW" ..
	"yfGvhE576n1GBgT4tHgNL6qN/dLYsgVKYBXMt26DVb3bT8pogwlVQ2I35vFmxL2ORjQT2n1rX3rzRhcZQ0hPaAa4oortAg004Sv6" ..
	"pqZQek4+rBy7hTAWEuLaLBJTZW4GyRAD2Ma9ZAvU5lbaaFDKAiHTpurWXPGnow53/BGgCLnAOLsuPWAr0vk8+ljvPLcZnI6YVbBQ" ..
	"3UpRt2/F+VTX0tYCUdkEIi8XxyXGqAJVNdpbag/iwNpDSdXqgt5ihPEogrTjJo9VjP+lQJikokT7u/CtmQiOVbyTGnXYNeK1Yz/5" ..
	"G1R9xWpj6F4SE+2BkHEkptBcoS0wn8IRSq8K4eqpVroyUmPqp5N4PZaD7Z1WQgqq0RbwvqXGgzGNuuI2JH2Zhkf6TWZJLfSt71uT" ..
	"VNluo06ZGMCPfhmeL6lU5LTTJQjstluxxmzocQXuH4qOXvmZXO5lzORxaQR/+OqobKtOdQMewDUw3a/jvar3nK9rT2tQcZro/f3y" ..
	"YvrnFIXzQWcaiTCaf2LWA6AIhSeB9lR0/8n+7Ihqa7ek9coYKNci0huTlL+gC6ea1szR+0NAtHO9QYay7r84DOd2Hz1rUNWZ4308" ..
	"ewHTJMqSZqREwSIVfLlV2RazadwqTUZtzc7Ds7ZWTXeUTMHzXfiMJqUJMVa3HpBV84L5X01CoFfqrVdNPRq09wCX+Oie4Q0amUG/" ..
	"LsI6DSw7XmO9ib7VtJTK7ud/7YCIv5BBnBhsuaODtEdK+wVaAUVdGwShsSSPX9z7cI47RLSdiIHTqYx2yZppWauWWF3HjoGSivMl" ..
	"DLzL6FMiXZ3dPFDiOwVOl5XbMkF5EpXQb4i0QSg98acGp/oghecb+yoGHRwyxjrlmo4zfhWftRk/w8GDHIOC86wX5cLFJOl+Op56" ..
	"o9LN6AoKHOJ9XofqcCzHDRl07Ng5HqluOClIEzdlRqMtHmy8EAIVZBKwsB880NOP9UhkshW+dTGdM9Rp3n4s3LuP5RDWTC0ax+dk" ..
	"baqJAvOyj3sGLHPTYIrY2qs5TGidS3+lpatFTaJCrbUWQ664hoFhu1DVTF9q354JZwqHeEiuHPvvS3sMnovbukmQk2AfL/uTGIfS" ..
	"VR06iEAIAcCzxynsqoXuayZSXk+0JZu3LOfknjAFU/20kpJqIM83Z+pjoDp64dKDe2Jhm5eo+auoyQlOTyTn11y0/vApMCegn1Ar" ..
	"AFmyg528PHF42/0GG46xwai2CsA8HU2gd0Pt4/t/YEHsBqYOg4FllUAnvGXWca9RGIH+eD1HkUxGgXDbE1X+NzcXcdR0jMetHy5n" ..
	"WEnafOMfImVJpo12PJ58OwIaESn22/J7OCfFjX7olm8QyB6ZaWCiNZg6hu+UTieXgxii6I8MgUbrGajFhUCfnf4fJciQuadNsC02" ..
	"d9cP2pB3ai00txdbPJC90aBM0Wzgxkh1L7R+JU5Z2oRNN4SzjpFvKFQJJ3xOb5dLJ/pKcUJiyciRcV8WR/q2Xi+fEZJDvRh8iWuh" ..
	"w9fDyOqLdxWdWgbNkP1OmPf4o3ldlFcE5VcqEN1gwdONhzciyqFWz4PAlU6zdyebJriiShCZFQ/T0dM5gFS2niJe5jUtFz8qo7YW" ..
	"dVkvzNg5ayQUM0d7PLqz541GWA3tjZV9DD8q62X3n1Ri8nQIHdUmkCR8Lp6rSKr4441ahiQYRUoxFUt6Sz5h796NNntPQZU8nmIN" ..
	""
local PAYLOAD_P10 =
	"mw7U6ajIgpzsOUyQGrpAcSWTJG5ViDE1HmSvviGTcYQhQVCo6NLw+qzxU2SQbkGYOc/xGM+cRjoxF03uqSParYPgevfCQG5IKCIj" ..
	"Gj1cZZj793PKMtP9rXfr2JVkPEA6/kgp5xTBTk82CDBRd0bMCbBRN5zRuwWSExkGz8mwTtyAMOdEmud9P8VbUaj3OCfup0AzKbgN" ..
	"ZvBHlNWkYPJg2cmOPYnTEpoaDYSLvcwt/mBg7hcSXSOBFQ4O5LlU0MSy4LSBt6FcN8wRsIriFKyU5+ChfVFZ6sGekftOiFbj2ZJA" ..
	"u9OSQwcOQIyEazEav/VoKLBHKdgfRUe0bDwf3yTENkEXH4Cw7uVYypynFMyHxceRYJXc8gI15hCSO5F5/ijpl9AjKU7yu9wm2jCT" ..
	"Zd3885Dqmg/LpBScm/arb1irUEgLy4qO70d3PuYC+8MvxgjqXh8d2NsTmrX30T1feyjOxNIc+ZUk+QofhYXLcLu5a7DDeYwR6O4g" ..
	"iAdoWjup9+ZoGVfhIm5lza8USyvp2YT8Q0L7jDTYgglQbAAz3GM7SH1QeVI0wT5pol+eQo9dLmIO+pKJU5wJsRkKBRJpLoK0z5+k" ..
	"p+jpO2PztmhbhJqx1uIalY9wWJIBgqTUMkQATWF+/PnZJwU4jKtxpYEY9Z+ra6V+Ghq9Efz6UARxd05UhX9Sy3+1qs/vtHmenAyB" ..
	"fc5u2WXgM220z+FDT2LR55VNbEdCYeQKXdozPu0lbJvN5p7YxwB2dN/zzSliJnSTLI96rGaiCE6a7n055n6RH+KYCeYQMm4tSi/E" ..
	"5aOxUb8J10nFOMZlnU9dEqgIaboc/TjPiZN2kbZ7Vwf230NHOahf3A0Mvv4fW4cbWLI115Yb6VZti23cUUegDbuZNM1bc25fmh11" ..
	"Pk2axTxtdHq3cj3uMjxkXvotorogq0YZI4sL2lZL7VEc1iZzYgvNdKZRHublUOiROtwQ9n+ERy7fxaKpKj7wJBdI5Ql+JzybLc6J" ..
	"/LhIQ/KrhLEXN2tvPYcmsz4NfdntOe8hqM2IYS8WK66JY+7qZOpddqDHK7/sX9LlJX0iq8nrf39Bve921eLhYvgmJoHPlkFjFm7D" ..
	"HXwqIdT5gjvX/6teE3gdKwNx8CPCFzKsQmzV0QsWBN5bm7EkbimTQ3rQqZiUD7Bv0qUBtbQENXh5Ts/iECA2YFOvSVQBvP3rTsZ6" ..
	"FHPph4mIb4HSG2m5x6rs7PzvhwkeF5gCkc5Yw8M4sKxRtVgIKx/zFZlgi3gMvhxnFcTspQWzpdQftxocd6G0HLVeJMl1Y3sCQ0ud" ..
	"u7LsHMVBPtksezvFMfzSSnZ6XMB+oWYf0313a0ZcBhggJFUIjR9iNI6cMJO6aerUuc5VqkAdM14NBxBxqXA7x6OThppmj0pPf/Ia" ..
	"jjVD/dEhWGz5B174W/IYfBs/OUw7kAZXbv9KM3gEzm4CmNRURipr0nO2FJ3PVkgcQsgPYKgFrMxf0/rm0N+0yDQEUpEAFmgTAVA6" ..
	"YegF84T7zYmQyWyMT7u3xTzuiir7LCe7UCOaQnLZiKkcIlMoLQPqSkfxSh799q1dBT3coR1yYTTP+VDu34Y3Ca5NudcbRE88+erl" ..
	"HhKR6LW/uN+P8sa0gFUZwX8RtsbY79MNPkpnjWlCfQIf26tUTifHdTyypZpTIHHd6LWLn6lTrb+FCI9KksVHYKjeHI5o+o/CabPI" ..
	"XuvN8DTs3g9Ge4RRL1nbyezV5ZewIO6Gv1grK3ncEgPxC+/fNZWn8YnMvEPLZ4la/aaHN+NHZZAPIwz2Lzfkr+PBefKafteAw72S" ..
	"xrGwrfE9hCKGEHcAovEp/eYB+FcvCpoe/vNuvYzXSblEH8gbgWWW/nVEeolMVmrRIlcREHRubKEfsALldTm51AQlyar95dCHwGVs" ..
	"TbQGTOLbzQGxYc+m9A5wEtO6ahAVqEw5d7xyKngaGUjZYrvyGY8i0IpLrGKMTs0I86dX7/D6Q7/I65RjP/ff" ..
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
