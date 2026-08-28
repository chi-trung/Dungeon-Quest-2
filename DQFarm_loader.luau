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
	{ seed = 1065198327, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1057342177, exp = 0, plan = 0, hwid = {} }
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
	"1BAo6PxFkxiRWCMledueZBz8ouMTOtiyK5xivuIPsB+xCZSrgZuGmyY0LHD7tIDL/Hnsz2gJ0NmpBSH28bSie1k81CeYWhjfAkOg" ..
	"ne64lXb8m+3nnN16qbbbTroXq7jlRoR03qnFrKE+ALT5N2XL/DuU9/I2ShkXoiaA4dwVy0BPDulvidv0Kxo+KOc4qDyaUNnT1aGC" ..
	"wZan5szHatv/V70rU5/G97vgxwgcoUyBmEJbUPuyYxn4o76MaFEhcxP04gUQTuKgyC2ikzi4WVNGkuQSeUMzxWihYex4gdiP7GRM" ..
	"uAce1ZVz2HSNVJfm8OLEqGWzhh3FZYgCHLSFIzJtH5gRZfm0+EDZZQqlByGUsxfrYSwuKvPAqGI6ouHVVN/itrcm1L/kGEMhxq6M" ..
	"Ek7VuWJmyREEgWmwN8ZZc4JJea4ddL1NlgLbobryDQw/l2btMYXuTdztGZ9kukD/vjkGm2GMPDU7sPwJGiz7D0VoXiFrMTBryMeH" ..
	"jXBiQIKhGwzm1EmBQVExNqPqjDg98O6/wbVV+956KVxKMnhgbHueE8k7LBnS5vXlyMDVI7VZQAAf6to/OChGjN4Osf0Gsg6NUvcs" ..
	"3ScBEunp/Aw3amWLIxUmLNWqShlyUb+J0hsUi+B7zOaPuJ7q9HNwmfcHbGw/yhQjXEI0vLRpL9qoaLWFVmJyiti12pFGP10p0NuJ" ..
	"lySDs6FrWqk/EUmUplcjhcL2wrKNYc9puyXuTfn2FEtPwG3EWycOcWjNmDzawJ9zHCD6ivf6VttHUmp3Np03BMBIf9GwfwrGsxYp" ..
	"NpFZdA4obHga99/vJUkkGF0u075Ep8yE7Yxa0H8sCcZJzhfS3BfNHiiKmFkIoy+0An0bfsG2y+KBghWs9Sqm/7VwqcCKfwesrgVg" ..
	"w+x+89Y2hre0mDyag2qXep6WyQD0LBCt5Evc6QhiteNase752vpefxjOvUHsufZ3ZT7ncgc0v+KVMTlg8WbEiatamIPF9OQJARy+" ..
	"U7mkg2T/Z+7HIKxxA1wPo1b0V/GbIfA/Z2AWIJf3WWMU831DyjIHiKy7IFcmHEkuxFyDKftoCbf2FDZDGoIDSaz3JuFKuZiVhoXK" ..
	"j0H65mpkt1avSLzQZ4VHTju3YHx7Q6qF3g2MPI9Jz0CF6EGKcLsQjHmIHB9oFPhFvdVfSiuw9JQRDh7rW09qc/ytJR0wT9Io+W00" ..
	"ASpVm81X3nmy/cYgLOTB2taiLpVNGvGVCJh++844YEZNdecNr+0g6B9rdmVuPQNCXTTHlZV08YAzJp/aU8W5kuAYYJE7Nv4SkK+k" ..
	"MG4Y1LiKfl3kLUIIRPR6PV3fk/uifUOJAF/ATEFyCjR3LHfP8MbAQ3vnpXuFO8UCN0cnXSmaZ8534diEXOQk8iZLU18fTQvDA4kB" ..
	"KohyCCkBq3n2OK/0AGqNREiGB/N/SXWfu4YhHTxZKguVD+tKXwVSHQYAxeyfPcpBbXKIec/DBc8X3eaOd5YnSqITmooUs1kQ0vK/" ..
	"02IU6/kUTj4x/r/xmqP/heAfP5+zlKn9FRuAFV3j5ZhAbV9We8S7ikkty1URHkA5rnonyR5H0pm/zidVvEVdRtZ4B0aGETaNgHdE" ..
	"ebD1yhN7lgN4p35ZHcHiNVmI7qHbde6sFUeJGfThLcJZZw15OedeZ1U6YwuFAJaRLavxeyA7OggHASCBXBs8yYgrnxHT5WTWJtLF" ..
	"dwga13A+h7IIVa7hdeXM9t3oF7TXL/UiWcZgy3iuxcJW4gQC+CSifihjfNu39LbLziY1lKkYYxJSV5oagfe9MNLrFxuhpeVpGYeh" ..
	"th0uCFKnv4s5FdVUuTBKX5YkTptzQv+ztf2CNriiqHODkF0UKeoTnHcaaHx7FcDrKmGrEAMlL21DoSXDOQpLi3k4N8kOkIizybPL" ..
	"GLol91RhEBzyIMklRMTH/ZibZJuKsgTpnYVtgMFJewgf1tpPgSfGguHRugr9dwM9hsJ9hD4LaGDVaM/Or0EAQFvjngZRpY8VtJti" ..
	"8XnPw5YBwd6HenO/iXyA+CMxfN+iq8Px3SY29T7YYH65THHBMfNG1nn4BUf8c2E1uDEzxFXeOFh0JSUNEwdBhU8SsT5TW0nBH9/w" ..
	"qLO5QCz4Qcizp3DtFU7iYaS9NBQEXO9a6yzwGO45ekM4Bn8Ve1tlAHsrkzmFTgDYcG/cp+TAtiHOc9nE3NgVjMHFPQZcue8PhbjE" ..
	"RaLtbWcJjZcOpWLBIs7sZG+0wX3YI98T1k6Hz+1pujkwnqJHa13vzHCgCiTS26tBSAQB+EuHP7oJ8u9zSeWK8/gFFzyd3iqKkuXs" ..
	"F83+ztfBFEFkcfLzGkIeLlVwrOt/vCETbKif38ZwJhr8zjf3U+l0w0c5jNcDxiNGDF+LFWqBhGHV7INovfT+7PlrnMWEYg0xlSPO" ..
	"eM/AczuDZripw3Rhv+XSFvPWtbaJX/Y1c0CmLBhnzjJJzIBECRPn/dpj6H73GTmzgmhvIDu2T0xQ+3jlYAnwR+ZLJmbYsQ/Xp4aO" ..
	"6J7pjJzKrfHce2HZwcB+ecIfmmV626K1vVTNhE7C70praoCAuTCAEBT68W7Hx3DoFyJZ5HwFezykNhXyCKAJTW+SV2vuIIrEGK64" ..
	"xyVBfP82UGjBd3edwMbBii6FZEj/O1VOZc+bLwGcTF+jaD2Xt6ijzGzecqISILXoK797tFWSnRQ+e6t78vTfCj7m7cw4PQzrSnlm" ..
	"d+UsDbWrXJKX7y2ZewWrUUoIY9ZzSBmXh0AgOT8gjV+ph3vjJxBPH5sQheOvMof3j6Uz0EEPrUNmitYyFMV0qO5lRS4BZ0ZavvtH" ..
	"/c9eKodRDrGbJkTtFPTZvLARuyw/ynIm+NsFaOt9vYDyBDSZJSYOiST1IgT0wqIdx4b605ShnUV7IQTE5RI+GXnYzbSIQZgBs/BR" ..
	"5TRqZnQKOCTaiaY/8IwdYVzMCSgxuLIDBtayQpXCbhsQ3Vxa93I19dTSeD8Y5gi9OGk0cOIkAAWUktBFnavYczluZyexXYvhBpiF" ..
	"oRUpqq0kMLoWVlwhSeRpyJTOR+NzY0gIh+xEYMRRjyVfKm2yiy0cm21/ixUfRE2Rxi3SBSfBPEq5/STCVfVRRo7Jih6ciTSV8fok" ..
	"dG+UG+eZ2ex0wTbc4ZC2yPsosfiQfPi53v6Osjto1ePm1Ir5aingcGI7+IYsyB7JF+TBmJPnE9ekcTXCLl1rAxHnqt3i86owkPNy" ..
	"uBHw7NmBh1W9if+MFxfRplcK7xwmeO+6fCE8TUTBYWNuUeSf2qPNro/6fFREUvWG6FMCOVMuJ1/wGJvMj1QiQii0/r5jOtx5hTcj" ..
	"R4Ft+NhLR4GDxDgSggQKWNwZWnLnS6jZjOcITeMqWdEehfOnuYCWFIYAlhRDfN+ceXPudHO0zRpUA3kZvYpwhOt3b+mej3yXfpY6" ..
	"LrWHPvyR4t5D7F6Q2H6yvtOzwfpwrDdVtiEbnO/QgnFjm/fzRyxTB/v1dfsGGUwXIUINzKlG5WWy8P4ildVK8rJaRbNNm2/lNoQD" ..
	"WxWdBh666+6uwcdfWRk5jfevx1lxzn6NOT1VdfLmowvp1+6+JGHDur1dwdXqR4sNELDjcBSpv/XFRdr5M1XrzSLr2JghRWIWFWFn" ..
	"HJC3EobHq3EsGV4tINhqNjYrGr0AVzPUsQ4j3GWVjF/E+ko0emI0/Pxbm3IXccisBEvANkdncCLl+q1O1DSw8gx9391tnXn+6B8s" ..
	"CkAw0iqc4CBFkCIKrh/JPKvVTSkF9kAXZ6LscA8PG1/iLp2VHOPo/Eia1CJTuiNNRdT0G2Swv2PuYcCYsEIMqpvMIBwqLFOXy58Z" ..
	"koayE6oVQB8xPf7s0vtLaEY86DuWfcz4NJ1A8JgA/cX57NuOlduf44jnDMu23AphthKJhicg3ClJUcemFAQb07oJYubV7TkHZhYz" ..
	"fEBJys4dE3zgyMlbLQgSvCSFr9TvYhek+KS/EeF5z+511sf10xFYb2c89LCISKWdqbbUOmsfyDE90w+bdxyWxw4y5Z/uFQtn40J7" ..
	"/8HyPZ430Clfze7cjFG/e9/Fri2qCDZIwlTvy35l14Oh7K8BRccWF09rTMxeKAT8JklWngEasdwd7XvHbxDY4YMipElwFSWXDFPP" ..
	"ogbiJhr3CpR6WyqaS7OIkx+P/dFlXpwdkH2Mol7rSfc98vw06YhuXUhVsY4f1+kzRG05zVKmJkCeFn5Rfaf09vRAQiMhqnq6MvFm" ..
	"mpyOfe+q2XLFNQCdfL7CZY9qCi9M65ulos5o+9ISJtQUMKhC4IEQM+MFKBbncNwbmZAYafkVN2tOef2cdCwFnfhAgbHhPQOYijS1" ..
	"p/YHBnnJnMY7bR0R0iuNWLf9ST+vvk8z16OcbLIGBXl7hWLe10iMoavPLeMVI5GX/rU4nY+BaRgw1dMQYIswHAnC+5QoUW28b2QE" ..
	"IQ3iZWesRZT4ZLmt7IUbgpiCDI4J+bp6J4HPjcX582FKhzRPRhYH32syO/alnfDb0haK/OgnUJpHbDzBMI03Gf6O1FE215tTZLlH" ..
	"JEEi2L8L4yekFOVRfvlvMbOs35QdcBdHIuUp+TuFhRFVMUCIe3DNHpNsrE5af1iGb6lnPRtqOjn4gvC65N7+WO9bfp2c/HuYja/B" ..
	"howsMavgMfop/2pNAPMWZus9zI67hggoahAQ9BvQnaocqVhS3dz811a1a3rQfhe7LkS9fE/X7+ZLopguAYNhq4ATzTY/u+3s4WSP" ..
	"/INp6KvNqONbkd+drf+40tkc2HMHGWf+X+/HTQ6o6lIKHJHFeB8ZqfjisJby+dKrlCH3NbhGle/V8s++9VeGDLHNu3HGNkLpKpqS" ..
	"9J89pZT6prMipFfAXG6etfwcuEDugjYIV7siITPLP0FtlDTReZzXY4RhuSZSgKSi48PL9Tql291u0LForn9BHppXgBBKlzWHfMXs" ..
	"9hsS0kO1RG0t+ju2Cmhv5Q6r7yQAH6/f8mMaPcjeGUf87DvPL63Ov8Dbj4BKTToDVlM8IKV6IoyLBoLLHA3hmQEoBNf1M2lVQhvq" ..
	"+QvAICZrlja47ONWrpIdEzAcpcfWG2VTD569NsKgNCEvREIPvWC4F52L18k2xIhfL++MU3iEDHf6bmDLc0pA+nqgIZMNnCB8M3lu" ..
	"suQHVzUdOlNPFZWOxDfRpt5SjfgBgKk3qQFjAZ1ek0NReNuKLtgGuqikTsRA/21radnPfEspw0UpxJkYDHCFiZvvhOALrXa0nG3S" ..
	"qV/rvOFAyl5zZfv0ximtfsxVrqYtnXuOxmdwxUxApsNX8wB0xchycJb08JDmxDWtWlgr2Lyu/PEVNi1ymdYRAPzBtES2FrRRgb9s" ..
	"1bCUsPAJj37HPLx2b29lH5rMsUXicxhDbnTwwzBPk8H8ws1L2ic7rxFYlkH+a9nlPHloHwWVBPHRNMapf62CC0PuxzbjBb7ToPGJ" ..
	"qNR3phwPihoWs5Fvfd+8a9jaa6NUS/FGPd6eup6x72xPfcqstYNb7LkDcUGmmelSZX8U5H6fS18ps2+d4xTkvB+lBCGVh75Jiunc" ..
	"6uFxZQgM/ZjAVyBihA6iMy0rZsxiJRffe6gHwTImZkSRn64ynp9J4w1p4KYNT9tstzaOtXL+wuXLMeQAyXePzmLJ488LLlbwzS7m" ..
	"wBnQtFSftJanc5yQQ7JcniclO2s2DantP7j2fN1y0XmU+P5RElqj8SVz2iEUq+vnJra54NzIypEDYcMZZEfHNIfFvl7vf0TB06XK" ..
	"2xXqMZDHWrANG7eaPcs00ZIZbPkrnxowu+RL9RNR8a0WUIU64fDt8TZmBG8qHWRegph/mQlXe1dMVGXaU6JEgJP9Tad0bHfK/VWJ" ..
	"Jdvc/V0ce6IBEa1NqPfhZiPNhQbfKuGHRdRw9h46uBNdKdzTb9W87TE3RhIjyr69T2tQ83uw2Jt4xkZJy0C5Wcaj3gUMMdoZ3Bop" ..
	"BAU6AkWrBojShivyHavYK3nrwg+djkUMWbSoLe2QQZcqWbC/VwNLK42wIxivcuFBO7tQN/dpYzBBD0rMatFj4C/+OqIxGsqzr4+h" ..
	""
local PAYLOAD_P2 =
	"fb/wIv/ZTLUe6re/VaRdb1ATslEZZr/fJnj/HnPR6ldxsCVVD5w+rM3X9SqEdPKKAOnmHtZW8wLUnX+lJIIVje/Mg6ss/Q55j20z" ..
	"g1YKFxurlGNaR0ROC09vtpsrpAB1VpAJ7qIxSJ10XCGliD28pq5+glm9HEMoQdQZ+bC9PTI6TJnP+4xWCFAuE2BXTRSm2j64D5+f" ..
	"BH13ra2uPbA65GF9pJ2KU7DRAHZSvLCx3HWTN7s1vGHNdMX9gXOWj6kQENCzOenWKN7507tcB6A5oK89sZhUSTlICOD9bUC8Zh5i" ..
	"8BHVbkV6a/OnQTTqw0EbwiKyK/guFzPh0rgcSTd/O/hMhReDKmeUVqVmcWpDDXEvj4KL59yVeXCCCq44BWprLfguCUhLOjfyANZL" ..
	"DLUIHEkXkaIK08fNFN1y6nhvR9e7t0qu8sRpoO6T2Z485+ShilJo8O9p/+glKGiu9a4GZAhT9L5xvwwn43g5fX81vUTqXZn2K9U3" ..
	"IkTg9Y7d/9lhMDWxjQvlSCXIKc3yD+i9oj5dP3EBRKW2W+6o1lCnqT5CttHIuq/+hl00v/6rXwP4D5alqduXPM9Cy0gEeV3YNFB9" ..
	"mXyi9Udg+uwxV2hL9jA/O+3cFjPNmVUoxPaTBooL9czkfYuxWcKuxixtNBh8mQbcibXUE9quKiHGNnj1mXl7DqM+Ip6jnbINWWTh" ..
	"ABNJvMSNICoiCRYJPI0eaX4agdHhPcLTTYDRhy1PJRK6PiPynuDVn4BXwDQJ2W6mtdoU9Nr9dxJ/hwRccqhCP42UIFhPx3pYY9k7" ..
	"Zsht+BvLbk+Pt07zdbQGP44v717aS5nvFzFlatlmH7V9QypVFfEkIiA5jzJlMw0/S6FVJkLtrKHLW220RKWGw2C0G4zCKFcl7NEp" ..
	"Gkmrxv0Ry/WZIc2PeatEO/R5cZ6Pl2Hzn4FvD9LTLKtAfwzSCntGzu99UA/SeHVJMa+bxP8NQ2Kas8nVYtiZcxZSWFEbmCT5JgIk" ..
	"YDl76QDNvu96lIC4juiNmEuC64kbdYvFKC8k/a3FR9gkBBpZnLY3bgeInsCGcwMT4k9fpbgPtAOlwVJC3ayi64t1hfJAu1HT48lr" ..
	"USk1AXU6th6zPC9joMEkft3c9bNg7gqRiwAi7Zy9BYIDkAEXiPwDL1gN1N/56CEDKwrLvVYQB0dB4SnU3r0lbhpFCZdorzS5WjgT" ..
	"XRYH8UTLF3diAAT00g4B4DUUxv3q/DWyQ/nHolOsZNG9w/CPGSALH7d8nedZIwnnQZfNFxsmHtl6idwkT/pOW5zP45UM15mJ/mw4" ..
	"Wv3iyU8D98A1ySqcthdtEVhvTb326ouFjH7EEU7Wox+YSITeM3i1F07cqGKdE50wk6LXri27ptis5XshgA6DgT+SFSzjZK+hsil/" ..
	"mt9Xt5uhywEg4cVIpqPHy6ysWrohIw+nG42Qb8UP+sBwedb04Of2ZNPslxVeUCL+GqsTBrvYrUI64fsvShhQo2fkIipue9xVlaq5" ..
	"oCHxLrGhw86nE2n8n+jeSSxyLsGQ0CP0vLEt5iyFl3T+XLeNgKy58lcnoVUW0oxQ1UQPMpKCKm1x0UB1S2NZnDYFEScFOeCa5g3+" ..
	"0JcC9izmJv8EXAGFKfKrzlQKSq9DopJZzSqBfU2cCB63KVzIZfrFhH6ScH2Wnox6qRf2SxIvK/ETkNZksEUT03S7nweJ6bzpj008" ..
	"Zd5EGxKT7Eyya0x1pZpsUl1yb0GQ5jLF/l/mfuKLLS5yoIUWUdIkTHYmp4z4Z1bqIeLgwyFoUmJx+Bzu67Fdg6WZOSmCupELFrry" ..
	"/OUevICHO2Jwuei/ZO/2rXOUYWk8uyUMizICn6ezRRd7z4J5zYXoKYrlC0iwvVDN/qPtpLr4ZJcqVb+rBxhVtzgITyxngf86RumQ" ..
	"GNHiNl8kq7MDuasEF8TaO/syJqG4xbO1VmVN/sKEjGGZg7fcQPX+7FByrPBe4cr0lC6BuOKDGer2fSqv9Ger9zORoSeJzvC2JqBX" ..
	"4wUz5aeBXnM8Zeevz+GlKsuP0Jk1j2dGwVyMrEb6UJ4O/clmiVvQWYSGoL1IHKZswi0nchWXAgZXVfTi/aw1JwY872L1gXH5Ydny" ..
	"WHXpUDQCGzi/HgVAbwZJxv2rvDa8TL8Ihiuze8pQjw9q8nfF0TE92/QqJo4EaWozcx5bkYfrOh/HxQc2ZFtyrdOIkQyn4TYTaaEN" ..
	"3HSU/iQOwsVcLJZniZM9/Q6z71McGTrQXxdxL1v4bKsqZ3mmfLn2k3JsUFChZEN4s2PIKLJXd/Srb8xmPztt9Q6ie0sC8czd1TO6" ..
	"Xl8WqpXB9rVmzHK/BomkTKDZ2R8btAlPAoQ+H9oYh/z3Afooq+rHUhYXq7WbjcsnPBypq0Irsr8/Du6SFIlnCSFs1VIvzbQn9efP" ..
	"KTxEfDBWr6CSyUt2vP1B4yHwhPt4F9jF43WE17avC2Fi5gO+KvRGM6Z6hBKxXZUJ8mRS+c4u/D9XJ8NI7diZY8BjpDiAGeQ3Vy00" ..
	"LaQZYZvm0Lmx9pvHcMk1Smz/jS7SJa/t1GIqGLECuCjbci+Ev2MR6r9oPAHMs5/EAplDN3qVtDmGueGD5I2/Q5osX1lIuPr727g/" ..
	"9aZCfU4Ij0MKyLLqI+KCINlb0H8fcShR1Us730gWHRumaVmgbMvlICYNAk/y3LrS+HegPbHQvAE25Slmk5iRGukcKAbqqWsTz/HL" ..
	"NUaL32xS0wKTukSddmjB+sdYkPDFcBShO0+1G/g/98nMtd+cqgDkwePX9r9O1Lrcj3SgdTJwZvQiGO8iDOSNWjo5xBSFFmFpjL0c" ..
	"WjDuVspcf2Svuzm/YZO40TTmMpcqbm+/NFcP0yiAOvSKdRbeHhilDhjTYeEXkWRdPHVdS0E10Ax5+76HZRLcSpeZIZyYUnaNAAXQ" ..
	"iKxB6P4SF34znwjLbyFEj4clkt4TPnOlC66y0Sy3yXnoqDslsbnrFMQSF22SgDVzEljP6NmLmYLOGpvNLUxhfBRHKod/3WFExMCK" ..
	"VMICkbiXZoLdO0HyREp5sws+9fceqRwytmHDAcF39i1bchwsAttVAje5r56uvJkYl9Iu8K8TwPqNwFFEIawyg/vT1LirsdrzOx3h" ..
	"4f+SkeCtuEoaoKTSGC/YjELP4fLE4171flH3hjLtpPNDzcXEK6WSvlBxI+MNMU2cUR2rahosCse2NiOiGiUJmYcWhhf4TbLddM2c" ..
	"nzMfJt+If9NzDlAPYXvDUyyKgNWVvdH3SD98+mmxd+SAcCglPkxJTn9Ccbpb50/iazuu/1cmuHoK+hfZ+yE7Hmtstm+CSITjOAwW" ..
	"ngxLT88mzpSnryzERvR9Duib/UpxJ0R37bu6mpbPPbL7k1o+kHbwVIOXhz2bKcPM8ySmNYQnaO1sdqXvotDLGP9/QONPHpdxhY8e" ..
	"P5BMpbm53eDepn6V3BmMQUaWxKyI133pEfIIM1kjhYBNW/BMFsZZoOR6YSmJXY3ZsqvTdp5hD0ahhRpOHW/iZ/O5heyeyJYBcG45" ..
	"oMQhAihsjXJp+0Xl5k9OXfxeu0TFV9cfcbD373D8wMzP7Rf4wqtjpbwIDVvBbwQJnShALrR4G8dGqvqsZ03ygSlCKT2qoFzl0WeJ" ..
	"rb2YmEszyiu8jzq5GD++SnotBNJJYJ4yaxnQ7GHHz03jw9m9E7WgpTeAHskvkB4iEWbzERsOrk3TWEccJ69mnUFu848CK04dYUDN" ..
	"ufAAT34c/6K4oEEVIhfBiid4KAjpc3+t1lC4Hg6qUQJxPawbAL1z+rUDBJkvrts8RVGMd4AgPtFsCYkA6UTkB5mCmqKYK+9d6Y03" ..
	"ZKosHm7J421D3BwGe7riaKZj1Zkg/8qyZ9SPcSyDiiswJIfoy/qHfkJ98Fj89a8UPrHaZVI8ODrBZ6+yFYsYon0GeM6FEcNw15b5" ..
	"HAqKfCCAfymVW/KdkZdPiAKea0uuJcU3A2Lzvc6srx2UckNOjrXo3uAoqm4LZwmaM2AhU939mVQ3jSwDBd9m+94tOK7/SJRIGnMc" ..
	"hTi7vkq48wf6MGRSC4eVrEef5sUx6lsc655KIWlXiJZHVMzaMsndehEhqjYtkBcGLRbZnS7C1PabonkyDpFUwDPYxFuyctCALyXv" ..
	"GuPJBd8wvEOBGohfTGS8oyxlGo09DzEHYL3o7A5RiuPMvvpbE+lb+v5FrFzF08G2Uumf6NDdhv42icXetfR4sFNDy/k1VDQwAIb9" ..
	"6giZPqSVmTtA+tQ+1+eTDDJ08GyoxFdPyl6Kldr8B6bKKc98gMH2kSRovPuoNoYHuhu+Bcki7Y9TqbQQ2Ja4DbMpEO4mcU55tXI/" ..
	"UQQEyjfmVMSSneHQW4iwogjpnHw2JygBBhGc6IqH8Rq7Sb0arFmxuo0P88JVI78ziE96BTLtDQqpHs+fYYlX6Bxa/whcVMdYgy1K" ..
	"cp7yIA+ZDJeFQbiQuEGoHxujXSHNQGe+12j2XFJ3IuI3mxkRAthp6OGctENVuP4hhqSa/SZ1V+YIaRLAOQJmbXPS0WTPm1o/skV4" ..
	"RFmpj6HfWhbOAmxsIN2QaLgou6+XR6Nxo9j3FoXf5Qwgkn+jnnVvgNED2Be8PwZZxuNPrWNwEjQ8gFycHtqVDiPccJwpO/cUitXJ" ..
	"FMcVoDHuukOaxdT0DRTUqINDnLEI8pnKzaMN8xtfl7nIXrXVZ3/rXlfjZ9JtF4TWzUHf5pUVFKZirB+TrvkKu1MiKtLwkc/5qSgL" ..
	"jYY6k0lYc2j7Py32v2OsnWtRVW670pXxcLdAgn47LtiqpXk7a2CrFE6RwLIQynEXBAMco+jls0E6o2Kh73MeJUcY9F4P5ohma92/" ..
	"d0Fk3g93gdFfhKPMdtB0BEoHDRLlsIbl/++FIeeGheHRBxu6OAxk0YKa/h5mRfHonUc2AN7qJPELyTQ2ch2Rsy9+srZfFqBuUfOu" ..
	"3/x1nuNTAY4fUaBW12+nG7sHcGws3DR7Z6H4R88Ym9CVzyjtGpMhHGLGYkfa1zvlyq4+cQMpWhnKWK9FLL1w1zz7C9UQpD1Ezcgv" ..
	"Np+ZbaS7g1uwPa4v/2eDURy8aWM0Qp8+yZXcEADnIviGMFcrji1DLQwO3pA6Bntubv61RYyIvwzBda1mtEmOD7/ZqVZYz3nFF+5H" ..
	"hXpp4Q6ykVPmHno9TWdZgiX+RJi0k0qVbovg/jw0CIz8aSTYFCEQUIi5sh3bZO4z3wq5cCcoIJDwdkSO2pbhrGZD6clvgGmQ3OZr" ..
	"jY7r3IITvWStDDtQRycIGeqMwxd5d54PqfzPfD8p63JNawUYX8mDlc9Sfyi1l+XRig2sSg0cR36hngWEmsMVZXxljCfqgakRTqap" ..
	"cS6L7yE7FGcsS9MLNPOHm7W4GaSW6xKsPcxHJQDlUtG06SPNzgiXr5FRbYbQ81G3WlWXir0Idw4zxj6nG5UBh2vIOvukKz/t4Xnf" ..
	"0LBnrq8IhMbpBZ+563ga8mZB+s5NJ56veWmAHttm8avb0oF5ixvRP9BY8WSSQW0LX52v0Bj0KnnM+Ug2go6QwlP7oJWjzkkHEBn9" ..
	"jt8ddUP/guMnTsSeIgam8eNglZaP6hV0UlBaHTIzV+NZE1yb0z3k2+WOv9KEOBMzo6Cc5VDXiLgDbFIjrdLl6JI7rtMbNgmh8OYW" ..
	"svmT2RB6EVPABG7oxkx0bCrwpOuVT6QnrFKkLVt/ooq70sKodToRjS0kBvC71htYXTdhGM/HMv/Eb2OBkPQKjqx/szFNMlYmPI7R" ..
	"SUspq4gdXf0/ci0XqdxlGZGkKWe+xMdQTjbkYZAttJja9rt3etVS51i9YaqTTyrxwQYLn2Rv7+0H+021P0cCaXMIKGA5ApeCDxoR" ..
	"bHK6v4+AV94NTP1Ha5gBoNZT9YYVnq12xECZCflg6JUkMvvLDb1xafx763XDx2x/hJVmgpO5GRTQFbR++0ltGh2q20yJkcBsA/KL" ..
	"bAyDYNDKEtjqbNjPJSWTf+jHX2r0ahq+aQgZxvNr07vxTrzwv5WcIhgnIJVHGwehwoRooJ3WuebolwdQ9QgTPcwk8q/BSuFpwS2a" ..
	""
local PAYLOAD_P3 =
	"Bwynf9gZmLLt4hbhoWPg/yMJmkte5RqsIgwHUTqJzylUKsOgLKPHGh0me4O+V65vYooxktBUByh6PjYZ25sEqu0fzG7Ar+OzAwh8" ..
	"gmL67jlvo7/5fu5bsW5VD979Wz36wn8qPFOqDsDLeAzMxy2Xci6bm96LOgQyjlzf64H2lis4bY7Jpv6LtOrEJJsqtzcO2Op3Hzg/" ..
	"r1+lhWbSzVpRurqtaIPG8ERvUXEeNSfc3Olzc8XNZK7VbrIwqm+ySdobUgmpgu9nB3RvAgucQHMa5oxaCSasOReY810pm7dtVTck" ..
	"/+UwqhupVp/ZZNxYU5ieOwPzMPjp1sHoXY0Fu5S6B98ihIxG7MDuoNNT8y6RSX7d2LRpZvSsEd2YgMvY8UNyJb7BwVETNQ0YuC57" ..
	"HyycRBhF8h34BO54qq9fV7hd09YSEfEsN8/fE16mz4L9qvPgNRxM4YlO2lIuCiQ5CKXrZ0XPh3NtdBVrzRdpKk0mh/JzosgjRz4s" ..
	"Ii/7g8p+l1EbKZOmU2OFOeG57bMAurccF0gqknzPppEHA9eWbzqpHPBRr+Rnd+PFQrJ3HMnK0YYEPYA3KLPOswe5RxISTELE8rJz" ..
	"tTgVT8ptByDOHf4r65V+8ec402j3NI7zVlfkR6irmeB8Q9KLJD2oghnyfWBYBObHHFpSDCbIsGAhfr3AcY7VZLBRuA4v/snhm07S" ..
	"QlidIyRCu/TOh8OID+mhcZygdWHD3NjpMRQhTmkpSrlMH8lArdMn0rF9u2FVM6jYJhLMjlVJDQp4SY8GY05Cr2pyTT14ArlZ7Bxm" ..
	"HNcgP/soVi3K62sgwalDuLFitpr7fayJ5behi6OcU/bMipCO9DV45/EbOSSwkGnDhVsQswDmCXesYy4J+EcQMLRTbAh5Bw8PxXla" ..
	"cUkfafbhVKpNh4z7tZTdK5J5R9NMxjJ/Zg/w0QWKQLFG1z+8w4wKUGEqSXqi+pPWBMiSDnJ0janAUz7fu9AeJE5L6uNk39S71vsB" ..
	"6Q20DakQSJV2Mxb04zfIVngadnRbfV7u4PG7YAhYG/tXgt6GFBeIIxLPq2UK/TIx6TcNIdUSzFlkvkqSG7dkJvfebWkdvlaiHZT8" ..
	"PyuWSu/pT8F5nUmY6a0Wb8DZZO+e7hVcLVawpL81T8SlveStZsz9kmU6paOKZsuzCXW39b8xM20/rppJ5s2vHvrbMBgmwFlupA89" ..
	"TorFAY4VvW4w7x+DuGtINXvGGe7pKQiI5P9sdr7lf82/+WYhyxQ1746RJWSf6/m8H/u3hsgCcTgxmLD7uj4QbQ4tGsD8yBNypXpI" ..
	"nQFYTJoHrqgMx36F7PLfrffAz1fZE2RtxCF0tEjREgw42SN2a0NO015AYVCGvnsebf6EFslllzWk+El3Yk7IcNyssie4dx7FkbCx" ..
	"2Nc5dWBPEGUij3qqHTq75YugOjst96GsaRn24z5fbwhCkXnxx5PouQ6PWIQQ0S7Ufb3VtX23U6JC3EMehiXUse02o2e0oN77URDC" ..
	"tImIv2Q/K2VybQjYkb664ubgLfxotZo3Rpk+9XyqYVMZTuuhsNKlSRintAtP8k44m2WfHBeu2K9pRL5Al78eP0Ocjd8BpwN3vfG2" ..
	"0qIsDBclzJPYJKzb0FN6otf4lkiyJ8sp5T3oRs83iuRNY4cZp8Gw9qeG8XxvVQN41vYJqAj6Xgw4GDFz1wXc8mB/pIZ3PrFAMerQ" ..
	"F7epzN/G4VBgYH4zPSkWbt5Oi0WD8NPlSUa9G+wqCJd5EBBFu//x8RBqwQMSoW0olhOD4qXe9VleTz9k0NRaicSMNNN9ne8y6Xbt" ..
	"ioqaMdKCy0QpbrrazaMT9kbmoh7LEjdT2CnLr7v24vgbmAfGqMXw1/9jnlsae0eaUbyt5h9Y14BkZkzG6yngIa3X9bt49evQ9+Sy" ..
	"H/r8xWjR5/ZYFvYfc1JrGQwE+aCzJAXUknnvHOo6iAxoIhHm8R8jNo78S6s+tOO0tQZPvm9etZW0zIzL40uKTBm+gptSBIn1AgLu" ..
	"pcqZZQSH8AqD1HDZntCsnGiWCcHhdcF9k9h9kwx+7nR3rOkyuiTOh3qohqF1uwQyHl0l27SCNSj1GKFjeluOKA3z/kEW+LSTt0zW" ..
	"Sp8SGLwMVolUmTLgAglExYckOuDenFhhM8tFSRth11DBrO2dZ1RsMbPMM/8/75//B4DgiqyipUxsjcPMGu+kWLDBPm5JOqHQptnw" ..
	"OF7GreHBP3R0D0hzz65l/ua/cBF9WW+9bNbSvvsXE5mfnzkpxwvsl+AhRpo6WcQ6omDqk90cRa3D5DlcCEKaUHLPkTZbCEsISQXM" ..
	"/CXM1iDbDpE3R1+0mvyjG7YDPXaTQo5e/DbunOWvb3NZ4hSYprzKJ2nJwt6y403ZS+ik4IIttP01MrlwqC+sQODnK3ap1lITmPJV" ..
	"50bK7db1EIlRti2dNfhrNKvahge6BE+n6NQRFzkG93m2Ah3ZOz1VtpHHOxCN0RQwNWzN56XjvaDXe7rAgnmadOzxcSzE4mG38xG5" ..
	"Yeoa+oCAdODsg4MQrhNrTI1hGkgEefPyRoZDg3UFcKBRR3HSuBt4rcbT5S3/o64fGgIFYBKIjLuVeFH/z5tZdYpKHenDNf3eoSDl" ..
	"xtSITUmvh9mxlAy/E7p7ckR2ZzTUDrmS4P3gDOmlBLZlQEz3tTA3pulK4ejHBmBt2ucOvWLyRx/+zIE1wTs0nZToc71b7rgUag9Z" ..
	"axXhz65L96UP8tZ25HgE+kNuwNt0nK0I9tdQNXkqtpfr1nX5FhUTpm2vX0b8YHqWOLATS6LpdZIVZMYqJTW810KZU85ah3D8hqM8" ..
	"khWp0J3jQ0tt5SBTqWIRLQkako2MUcKyKVax/IRtqGSjRdacnHrIUfWUYMsAjEfWnakeBbDXVwWYL0w1yBxH3b4Ujn0hyu+b5gYZ" ..
	"bLGwj5deWdYsYFmKi+DXN3V7t5xalnl56W8LYu8adlU092X7P0LSjX6Y5UELF6/nJDxiOePXFL5HBD2pSnIslrkPS/6pXdRgOoQ3" ..
	"Bp9vIYe+bvfXXjYDg/UMj1NFj94Sk6hD3+8Hxjm5IVW9DjzrKHylOdu+6yXCcNa0wvEGKC3Ay5HFoMvOlopEA5e8YG9RGjxwzJ96" ..
	"Rt+qCutTJtrG8//5iZs1wKl0ndvqpawCRuNLYANKMbr4dDfo0JTkCocb2VOynROO8Y4qTbU4Q32XN40dsdbyEhtdZv7D7MD6+LDL" ..
	"EPyHLM3soPv0GMS3vHJwZS7g4cwkSC2HVpl9Eh66CKcUkhHeuWns0wRNWPbJQ9p90ACeSEwIijBnJxHedfdHVZuLwBHks/IUTLHa" ..
	"qVvGsu9wzY+U3q0WKI5LfRFAtvweldnAF10armH8wJ1hZF4L9OzVa5PPcvS7T75QQRMW4d3DRERRB0gV2598Q1CsmNFjFjwvT/sl" ..
	"h1whhtqcOQ8OkPin6dmQq6RtXHOq8C/E7ft4XPw8BbpJk9Ok9tCkcCWLfZkR3HLlY7IP5HftYuxkz6OEpvnzsRMKsnmnIuxN/W7r" ..
	"FT9w1ZZjRaiCsaEY+MOD/AkIN0996VCyL9b8BVvqqCwLE776Cgc5wwYKAAjG7fkOLTFdwr0WmcppAIjK71Wmc69+y5Z5FpZlSIkO" ..
	"4bNx5loAJghhE6BNQoU/gxRb/AOonvPjkDsSkcTpSa3g/GWR9go1L+HyG9jQsgZA58LQMMxmsq5SuLSejOc9jIP81GYQIGGvsJNd" ..
	"925UcQsmE9QY6zHVTktDpLu9n0ZCGYWPE1gF9JQtRYG/q5S1n6OD9/EkcvK8/9wcC7iIRXsuRrw5B78spaZ65o/ko6wi/xoBxt3O" ..
	"6KsjupejRZnWm26jycGJkNloNLoNgBxJUfwEehtp9d16HlnhGqZzkvpwe1o3aZBtVnyTdu/7SFK2kSYj+yDgLLQT7vg5S4V/AFSR" ..
	"XjGPdQIG8LbeZ0jaCPfYpUUBylBi/9FsiWCxm77JHwuswnPSyh+WFMUGAdk0QBHbClCiDBRZPlM4Rw5hihzOoLroOCTWQ0fbscwi" ..
	"0bMv57s1ktEpqzrfucEtAnR3BHbKAJ0MEnQqWy4Ljbjhmr3I32/ckt3KvQ/k2xVQ82kHZ9gdm3JRu2LPay0BrCQl9eOvq5A1d3ms" ..
	"1JWuSLN9H6LK1/pdqMXNt1dEEWJTMnIa7eNOhPDCgywfdAzwj575WmfvmDVUMVxjknZqu8H9sKOqDwLfJmB3BcAle8SRHC+bv1yh" ..
	"E6ErU64kSSxMR4+Chmk4u91m/Vjp2sQOoIGfHsBtvVVCBPlh/0C+5xk2YAfpZ5hTemiDKbq+Nh6n38y+nWLZkNwlu+LK4AabrABK" ..
	"1QBG6I7KqS6o76XKCQiRrLgZBsAUruGI2cMOFtOVI/rlB/V/fic8GItmfzM/evlV03hCp54xKxCPiPFJIecXa3+82kK9HhwrnPiA" ..
	"GIzk4c2p451Jd3EH1xW8p9KXkO4c4tCt2jAtfU3w09v3YKpwsEBFlK9PQcubSyNFSwXcpzqFAifhVXkhOUsnNCoStQyW29X/8B5I" ..
	"sKVR6E7VJGKimvOfz8JwFieczpxQnS7/NzNyAQhu1D0Q0EOOXUj3LbJ3oq2NINA8lhEbFKJr7yp36b3+bC3aa9nV00D9RSSLU82B" ..
	"dD4x7IGIc/OJ0h7b0baVxQ/5R67RrLdIZGwFJYlkRxyCHISt53915Nrab4mwYWRjNsRRW3IG5b1332zHfSZkWZI1C0RoHzVcYNUY" ..
	"LJmEb8pf0WSxnTt9I7n2j7DjvcsAXOKOm3Ke4ToCQef6badmvg91Sd7YqXyytPOz7N2iVT+BVyuKwCzDzE+V7Pj8kR2/1RSRT81m" ..
	"H24XSigwahiWflcP18xiXT6DJyyyk8Gqz0dBeMcEXhh9XZT04z296j9c13hIXY3hYTiESDPXG8N5mZJUU4/0JDQvhvRvHCpVmqUH" ..
	"QityC/3Ne05QzZ0uV87wQaf8lSKCAu8RIPPqCZNTuQcx3U1yrsJYceYCWWceNsRnlXZlTIiXp+Y3ql7fmnWC4C4mLcBhZps/DMz+" ..
	"Earstmun8Ae6eauC7qR1k/gyoDrKA3Qz+QBgkPsKvRcVUI0FBcOdSmX8687Wbfhj6kU1mgamRsnv4Ay1YJb4D/IwyV3m2lMl7YDu" ..
	"HPy1mu6w4OS96vRh+L78CXgt09RZSR9fmcIRKPD18xU93sAMSwFFjrqYYd5+RzttSLw8McC2f0i5RmuOnEWo+Zgojmrr91SDzTbS" ..
	"moe3Pl1up0Y/brwBAcrigZbO4/cnhvPkNulUqSds3V9kydXB+4K4C95TVFecjnY1tSSWzOCFztRSSLndoBjBrAFQEWa6uW/fng66" ..
	"QH1uKq9PoPE6ARDYbbAemErCyBLBpKTAd3vUQOwvCDPXwCAz7sfShymS/pwc63eVlEZpOak7kCwRPvA+9K2/7jzcopudKT09Ph6k" ..
	"K6OmqrF7zY1skFm749BRCcmdqPhvilbvWQYLu6f8P00iDeWaQy6TqnB79wL3NIu2HfTzhjWfjbWPacGt+rruugxO8Ikm0a20eM9B" ..
	"W/2B66pzXK5DHAs1cQBhNSgb4jSigUSZrFqAcz8bwqzmwD6nVZzyl0/9Ty37KNaE2J58fI2Johh2CCViCITIA4lSdr45IkQZ/NRo" ..
	"7Mv1D1aH0022IJElikpA2oAWufDHnkhMNXGfKBgaYRqdKFZCjOpO9R/3h+GcZHQbjmqAXpb4NmiaEMLkbxW9LshNGgT89BNnPj/9" ..
	"uKzKY55QEGwQ6LkPnUMifS/Jl/X8YmkUWYxM7+3Lvcxy/HqT0vVPscNvXLXfIEmp5LCJDDY01uqGOt15MzMaPocfaauzFdee44IK" ..
	"NmRAlu8Dyrs7Gw+Y8iDhklPDDNZDnC0ENf6i1NwU64EgPTImVsn8FA2BUcIt//OybpLsr12ZzV2u9XPJjXkOtFqrnFn0tlvnPk12" ..
	"+qtjvUmnsctkrXuH7Nm1pnj0BD7SB1nIlmT3F4Kb7czUGyaHioCY7UscuuNa2VCG5tjcp81G5oGD1COkORSnM6U8pLq1TaXk7ibM" ..
	""
local PAYLOAD_P4 =
	"I06RsvLt2k2wfjj2xiKWXKmjagM4ThSqBt/vxJ8LF2D+pydS0AwB2TAHOS+iMaaaO5mnnj2bjMWJYYEBObzwVPq53PyeDy3vW58a" ..
	"kVo26msc55TkKSujokBDDmwWUg5gH+cvZp3k/mt/sJ5NY/zPVEbbwPPVWY2LrtLpUJQ89ubwY4rukcwPcNrg7n+kLCMxQN5w8NQy" ..
	"L7uHchQG9YX3aNHPCu/M1Dx5vVISPr/GkqbfKCgA0j1XEbEVhL89YFo1aXfsIuO6Db0z62yQqqhk1hF1v3AeuF+9lwaV1ou0rTZu" ..
	"4ut8qlGQu0QmCE24pztUhSkwLSBfnR4rx+V0ipZoo6OJrMHU1b2qdBw54x7DNgjQRE5ou0Zmss9yI8RFEH8Bu310fZy+2MU5Gav1" ..
	"UTgcQbEebIlk1WM8ID8SFaEjYI18vUiZpoVyR05fGZdo9RBvgRvpWeVzmwf7R+D6xnWp2CIZSbKsCGdq25a+5g3/6ABNVsVkUqID" ..
	"4vB5oMKJUGRHUttRZ4mwFXyvnoSC8zb3dlVr2H2QT8txg0FaM5gEYGc18t/2gWUqO4NRoZraL0jvZFWwZiKNk2tjnUwYp0LOpgzf" ..
	"M+Geyh2DOF831bbr20VIfYjPqNmtngLSiL+Thdj9ht1G3nrYkjNH56e2BpjlAJ+2j1vu7rxOkyijtUUhpnEKoWpyYa4HsbtQ9u5a" ..
	"udBE4sZ9M4cYRCuUEKQTjXPilqedraPcaYh8x3QYU5KZP9CMTD4tS6sLW3K8wwaRukoYFyZEpBB3IxjPGRVNIhHIYpZM45Q+yks6" ..
	"CtI2JuuFwsYELlD4Q+NRbM0v/+HwIpcARYOr+wO3AT02vYfWAtHghvELu7uUGYIEp6qZQYwgbo4DEhU+0P6ukvJKqgDR0D/RP8El" ..
	"B1G7F+hAhteHXA4bnFVaVGUuEWMwDxUEFqCJNmaxu3vi4FqOx6zvmc+p8oADt3LeZSJjFtQKi6Urzer2GIQoAW1dfMxlEpWNV1rD" ..
	"StUiUorQDA4jJftKlLcA/flbRWSrrtii/cAbPzt+wf5VhwaVBp5nFUGh7t5bpZtmcdhtLZIjsWlFdJj+oqVqGHwYAJa/W8TZwq8Q" ..
	"O/kPuJWd25GzG5tJjWJ5t8zk8SMnLmlK759DrAUoLbcqS4Wyh4VxzH59T9dpyfLnzlebsA4Bs3QD1441sHGwwhJizJ4s1LiNlesB" ..
	"dVPJ6xl1e6BwIQnPI++SaYzaEz1uJeS5//i0HJd2y0Z9qiaQtdxVebiC4AvEnLz3XzfRa/Z01DjEUwMcCI5mXL1Y0N4LtF2CCIjx" ..
	"yQQ1aWR1LX3V43Fmb/w+URAXxFCHRH58f6XKB0bKgK41EAeU8rWt212He1SP+V8BeVlzn1wgnKdi/s5iXwlSDuXBnJtAWPfXDf1Q" ..
	"qkYDszDMB9t7bXV2q/7uDDUFMoaI+CwayGHjK0C4/PuwII2rEQzN3Lxy8QPmdMnubgnnvU+4LH0so9Fxap4Ll7dFSnCzNjITgmrA" ..
	"/eieT9b8b6YntSX4JlyJ7g+TOR09NyvqYyuvpnzjJRvL8ReKH5Zb2GUZD9iB2nr07FcW19WK/RXSVcsgwHgz+5FHQxPB93Z+nAbA" ..
	"MakCYv3+0hDZEyvW+OIwqOs/FT0ffYAKhn02SaJvio4oN2SSLXou7ZEA9XStpvd6n1eCjO6cNKQp4onDyIz0ZM/denLUZ846D8Qn" ..
	"vc/2rlTA7DQ3pRsXsuaouHcxkxyOGuS7a6XE3IZrm7L/jx/3xuEjFO5f/9dCaRc8AszzaqB8e0UEu7xww1ZrVXqf1cwWucclZjvQ" ..
	"dBypo+vTayx8ezrs1K6/NPgw424nOF8/jyK43T6xuKLEkG5oQMUS1QjtwMH5Wuer+GKTxIzOLOk3LPt4OMe530TTMgGg/TVsWvMm" ..
	"DgJSUUV1zzhJ9l4eCNSCbvwuJogkyFwnIvB+UY+gcSW5gPM1ap+Irj78511FNEXLygWCfjj+oF/4I7jRKIFLnhUid6XoC1Xjfq4J" ..
	"zjfoz3SqRwVXljFcpNDfamsx+yrAwtsl3fWLr2IvaI3M1ltfYGlLvfsCEIPaMGQQqcVydSJKypaZ/HzdPN2AX9AdJ5DLdvDLzlZd" ..
	"RUWoIETTQRKHV/9XleJpc05/A7qUAv+v9WwQzPKiDcjeRJWJpL5kqS2tvaGG8ukcW+7tcvck0G2JB/XldKkm+gnfmhAovfEcOD/5" ..
	"YcMOPzuMdF9UDqMK9YUlNONTQSvbAlN7Dn6rOXF1l+uUfXwldPjOreQpeb63OvV0brwTEkwV2QPoe1l9NZtSm1I3UGdD8Jy7/Cit" ..
	"RsUnkk7VYhd2tgNDQI0u+RM3yJMGgSyK3CvPpztrBKeUgJUhIJhx2ZirDrm+4/MQc3uvOw3faaPaYwA/lTkXTo935jWWhkuEL5Je" ..
	"/jswhomM20edLQpk0Uhf4r4m+k2Zdl9F/fVyEQsOEoOsK6mgQmFjmnPPc0ZM082BogDemb3K4CkAATPLo/c13EkRI1/HaTT67HQD" ..
	"P8RagF8lN3r1aZFctTGqvmsf/WEv1PIopZi2tX454vcKNqxcNtSbSSwgD3GVnqbVTpC3GTYo1ualCMX+PwAnUZGrVFqEN8D8KyFQ" ..
	"hG/JPdyQf2xKuwkPB3XUr1YtedDgSamuxLsz1t4f80sxGse2ckIYy0qqAXQMKWGasfBOh9qwbFcI4I593Ts8NFhdLeb8aNdtWxsr" ..
	"3zY9olo98earOFeyBmeKcxYtcGEhubUZKfajRU4C0mwurieI8r5CvvkraRVbx4+9lFmUOYkdkUxwkF1zy7W43wD0ZQCR+NdJRqpq" ..
	"JIMNNedKZbkyrCQP8rmGh+eJ17R1okFKTN4s5oQvckyJzkn7eKrLnOf12whjK+Kz0shXZyIwAGjiqy61wQkg4HbagC2uYN9rNuSD" ..
	"ZMrmqYRylZob58/Tb+vrrqz9ZjwTNLvEGhERtAzLxbbCD2LpxyQW4gBmXz3Hf2AYXRSrJZTUPyek68rGIkHahVkIEjvqP+EdqLSV" ..
	"r6ODDDt1Wfpx7iYRRUyOLku9DJPgTuXHDuSlQcuhCrRS3Qj1Jt86kDzGhuEfpG6dNHpaNL5jHGIIRhiKAE/SHPi0G8QokbOmtg/r" ..
	"UBWNfcg4Lqa1Feww7EkF2eZjXna/IJxIZFs9duYgjk4IWfaD93PyRc+MdIBEAHW0bxKFljU+bSZQrM+fLtzQ8eO8Q5MUTrv/z8gw" ..
	"gEQm9CCyl7BX8Nm4AmQFmPY2Mdqieva11uvW9gNFlSEU9E9JSLQZqa7tyfEZnelCPpKpYwJUzjh2hhgqagLUVTqANBXg9OhGg+K8" ..
	"PYtFc9F2BI0JVnsJF2xxMgGIH9CBbkS10+C34bx00FiJWRwFoicXfBwwGe9v/nlZhIlIQ2Cj1tZbrmpZgOye0ITgMz59C+4yJ11q" ..
	"ZiPCC8dylPNFDrKDNmS86LBCudc8O9iRDqOaZTkUW0bhjFHW06O0yKcTDWhaOOD7yfpCIjXip/GPdATv426ioQVCHy2v7UXbpktp" ..
	"ERu9bcJa5NPx4Gfj3DRJl3Pxhl9fhQxi421Xc5bNAOpQEvNJQD6pIQgBEJ+Z3BnRXWjR3OQ0iQrHoCWwrlz84+bAp6JTHcwOGjje" ..
	"j4JW64jb5eFXSJbf2fGTY+dW8DQlaEC6YMBG6cspds+J9if8Pgn9UDJ5TmxmmCk1iVXHhWL3xneD1V8o+B/momW1G2fbOK5HbxDd" ..
	"DKkbSN9VWcx1r25I9uU0m2unlC6enTPtcUD8p/xeqdUXNlD/2fLxM4wHek7Sx6u6h3EC3xXI6OorwJ2eHFGMl6jcVJ3AH/Adr+o6" ..
	"4zNPQOzol9GYNi9zAcrVmA+TW2KSOF/I1opAB1CtImJq8wN0nmhaFVReiUJ8V9OkxeXziAgWYq3btGcJ3TRQg5BlAyns0hBi1+bg" ..
	"hvcJyF/2Ctoq8Tl/GduiZnBT0W736mR6jp8PQ9AyYEQJ4W9w+cUtaJlK2r/21Uc7VwryMYcJOeQ5JBLLjZB8y1hiGFrNRG/b77/f" ..
	"wpF5xDgn7StYvTdMxfCfm2WX0Ae1O9GLS+nXVap/EFkkwwkosjursK0EDYB6b5a6dbSkiq4jVHAZ0Yhu6HtbUuR0tKxVWMJwBzzT" ..
	"qoMdK3qCfTjcwY3N3U667bKDho+PjWNzYD6IO5PMZIzaSqt5BQr/XVNoEVr3mIfz+H78VqAkakXTp1ntfLGGLSA7iUAxcuSWcWBo" ..
	"WpApPNNkAqZf7nT8n99Qf+4q1chzdZoBAF4FnT5vgBmWajoaz5YEilRODP7fAKHXtrNGIFB23R4AK/hBFFarMWtuUZ5drPY7OKgw" ..
	"WY4/IqOo6IEhtmieMFr+mFA21XXbH9wy2t+HTwe07h1PIL7oyDkUkvWx1pqnkZneYDrPlDMsh/i9ffaSWrCBn9y600+JQbNc68V9" ..
	"3CiI/T9u0YNEHy580LdX9g71Kt8HEh2v9/SscCg2y5OLrR6Q+on+rQHzpjs0CJvfs+B9mU3mTFCj7kmMQQ2xBkLSauhtyy4eesPc" ..
	"+GhFyFJy4vpG7BVyHkMNS7G1wbqz6AnH+0JWdxWoADIdDm9vynDBT+bVQujekwTC/GVTWtqBVr0qtxCI/ffXa8F7oqqc0tmXoSGs" ..
	"mw1GMOAn/JwqYMLoQqsDpQOiyXAZcRYDbTX3vysBPwyORBp7e1UZKtISFl13k7xyLYiHxWxAgjDQq+6B6uYkL/aDB31eQnX8miFl" ..
	"Rnzj3gae+GViT+QZyWPvy729IQzXR0D+lyt+1yNJf4abaKMv3+G3xx8hnFp0QnqywSaYguf17uQkFS+KhUIMf9zCyq3B8yM1TZv3" ..
	"gJmixpmaJIVzuQDkyw5RSgrFmjRUTZNXmFUCIkC3aAd3FS+5JQMkyO5Cesf/L466HArXyL7wCwpCQHDTk/hzVWHuq3Ag8VTTxKHF" ..
	"ZdTxZzE5fbXuFxQrQa/oJnS0wvXkhJamDWpNxfk9DQ0Xj2IQVNMcU5A91vgPM7JShfxz7flaA6bMNsn/2DCCzUjAxjJleoD/4Qsi" ..
	"qIT5kDfhGNLFEtr6u3BWWkwkUM7Iq95uthXdOqBggFNZg8INxMjdd1AhrfunPTARfaDtmLjNfv/wOcsgX/RG2Dpcp8LO3JTzZ6Oo" ..
	"Omj8cF/upbEA5osZNTSBKZZqISDNLFKeYyicv03m4Z9CcWe8D++JVphdFerJjhy1oTBa4s6YOdHezcS/oNhU8evszzsFFF9Qr4Av" ..
	"flo8PvOFlQQvTkRDmrhElJuWS9NrRMTbEknV/5oZD95kfY1fsbA+TBL9+FV6tWLLX9iM7TUB6x+AWltc8qAvEbvnTMXGBH1NF2vY" ..
	"GyIlu6wALnNNIYtl5oFuX9duP1KVZ0AOIOqM+f6rIEfSz0ivVK7yH5BZWjwC5W0qv5Q4L6Iik8W41t4d7IekOFJ4VAKs3l6EQjVL" ..
	"kohBD28Jug+rxv57luoDrkxoGj8zWU0nS/TNJizE9gAgpK8JtTy8qFendz2sf/JP1jdcI1mw9nhDw3RY9ODoJDbmZEYK3ldv4jaB" ..
	"dr4aMCU2zFKdwUe4iH8Vc/A82zbgkoMP1D7DNAZFp6nhJiXpWegs4pmsGFK3OC6jeeAZgN9/J67yBYGUp1IUN0h3v8rZPO3+HOt9" ..
	"c5p+od33pkoL11lbZ8FuI9ozphtHCBV4PyWWPmQUmWz2gYv053ssgOpPLNif/0hYZO916oqkXHZ6YNAkMFWu5LjF1sFUag8I0kj/" ..
	"sfzYPnabep5Zv4VwwSvxicW4r5tmQg7yXlP679T9na+cgKC6EP29oZSJTbzmWJS9rcMiGc/e2sqNvdeUNKBg71n7mor78Hc4m5R0" ..
	"mOm3JVTnWBVtWzLVuifNjbeD2XDsuptu/tp38vlIQESSuuOM9cX9/TuM8DJXCJoVeeZAbs4986YUv1tiDAXWVTj1tkLjY3nInZy0" ..
	"W1Mqli9Ie5QvuDhiKaV7xd+QscLUX5i5t7FfOOE17he4DCG31AYQ+tywnlMqSb76t0acYbcYxH39WzWlh5J0WmiWFH4FeFKb61HY" ..
	""
local PAYLOAD_P5 =
	"E+ZZ4R1E2loHURL5aeivyv8pNs6QH2a1fDCohlCGdk612PaT4yoAM93KRM+VdzmG8Gvh5OSfXKAecCrlXtlqqaTzJNGCKwSwL03q" ..
	"pGKL5IfGuclFBgyEgYNOG1TgG+8KiaXNSKf4yX+tGL79dLJa1ruGmvJHhvyHo5uDau9zLfT3FN4fZiT7Z9Iy/KCc0bKnvMpNa1px" ..
	"cI4Ogh0q7JWnC9WOHfJpRMM12pc44qOA6CODmi2jl9cMWsQDUhpcAV6OKYSJh3/PrEaWP0VEYcxf1Chn92BhEIGxPRAZ3Xl+9q6F" ..
	"FVxnQuFM0UnE96SSLYblDFbabaLs09gIHgJ1v6eoycPr3YiNTO8r0N/Bj1uNcMyp8ygai2hKYaxJ1YFegyhvRLwPoCpDWrXtQIHE" ..
	"evcbipDRqa1g/GATR9geHA/Z4nDGYGAPEJS+k2tuI3b/fTvZYwHrlUInBtdMyOJKFqlAw4JLF41f7TTjGosV/GXE3w9ZD/hAV+aL" ..
	"dFlGyNlHh4WS5g+StXrqr0joCU0JCOACBlSsBk6TWh/OmQmXJ28gs14Sq9nRsoWHtmEZCBSGCrlgH2uKEb7U8VUcJg84maPgUP0Y" ..
	"AzwGN1MJF1347woL2FtN3BeeSugqYZHB3yf7FoiyyvZG5q4vYeaoZZQ5Rngo5CZ/c69Z80rVnozWNPJt6IxpG1ER79Qbdr8Ir5Y/" ..
	"D9HL4tvrPcvWoe15JOKkBFsNLDHXGV5JxnaE7p7rbNWDE9c6FKAFHXcXBlWxH+R+sLlL7M3SyWlNNFIcGfI4nXOekK+bzMfWc5kr" ..
	"LoW8knYpzUSRIkdKiiAAhV7FJxp3jOBL5hSGbDSicgIEPcNHm74YOvFdWaxOen98YrKKOq/trDQ3wJSlHXLF3VwBrdWIVLCVOE03" ..
	"ihrRb77CnUzjN/qNQbgM/MUK37gi6Rum+1+aEjABdo7Hq9tpfFmI6rltT9+++hEYOWeOvhEKUGaN+S3663vnnUJ3IPmAB7hiCKuB" ..
	"iZUmq0C5U2en9tZcxPV7ifD9H9b3dPIqhCSnJi7bi3xuizjLvGKLqZFjS7/B2BCaZawBCoBftok+yvjcPbnyDGnqfUvzcQRpQUQQ" ..
	"+26NJN+MY9Xcq+Tjw3DmHTp5zOS42yzGj3IX8KMGoGLfeO+Hrd1avKiMJqJsRM723BtNxZ0d917g/MksuaNQcxMr69rAle6+4yFg" ..
	"SR92Emjfa2j/g/QPYuED4iFQWkXyadddHQXn8N52OxqFVP2e1XMJ0vmx0RvdNIOOA9G92eCZs+9tIRq9VxbRUdN9RLrN8jsQHmcA" ..
	"FB2D/UapQHbKv9nW72shV+ZDqodOrpIvzUwkB6SQb5oHAff6N+/F2Vy81wzr/8CxDuAmH+QCyBD2w38xPcz3cWaaaevXdULVprf/" ..
	"s1szzrZakePce6yDprJvbVPA8PL9vxq0GF0XEJ2QAMH2XcH/OtUt26oT8r5jUjjSvYe+CSwFSYLktTMnDWP0d/cjL43llnoGJGzW" ..
	"ljxTLDW4iM69kvnO7fZKvfGEhQS2DW6km5GYYWP5YqTK4BNygx1xySHqJ1bB3Cqae55ERpc9+cMdU2fP3I2HupwqFAgUp9wDPg8g" ..
	"GGCMPp/2l52Ge3uv8FG7gIZRiSbKmg1M3ucvV+J1LihuDq0kgiBqUu5hJFNZ59T+CrE2XZycC13XlEV2yS/lZQjjHUdzKGwVg05/" ..
	"0okiXWEsUFntUk0D5njIGxoVIqJHM36mBe6sTuKA08oISU4/YUkPPVQ+gOj3dj/JCa8lj1lzL2qPLVA9I5ewmavcl6b6hPNnJk85" ..
	"PEafm8SYtnvelpA9h3oXYbwdZ0WeyPEtPltXATw5vWNcvXZzQZMSHvKhp+wGJbFpvoL2yBZo5zR+76C/zYYDdbgbG42Jvsi+b8vu" ..
	"vKzU0hYWnQnAxfAgGOK4Ub7allNfNImv88bq04hNzo5R/SLr0DYLOJIFVw4El0z4LQwTrN+sy30cE9bt5TadhnVJpk2TGepcl8e+" ..
	"+Zd4PPG2vLQvSz4hUwVTftvW5amGgz/mH97dX8GNwKCs9n7hbz89Jmxs/KkvQSNXajYaX0dcEdFELDgL5oPl54o2UhJOX5Lhvzjb" ..
	"Wi8j4eFkZf9vBdOtXwjDN4l2ozYVJBv9iLC3rsQaQztdRYNWOk32jiY7EXzVykl0/SHDuwjpIo23ps9RHChDB2D+5oG5qaytvlB0" ..
	"MoRjb22PkSH7/157sbrZIEN1okInTc3cLJVTSxL1qI0qw8fs+pNluy2WBDgvOIkzxhhia3jrOHAOpoKCVVhBaucr4/aAKUEyHoaA" ..
	"lXT1B6aejCyYbX81axjxvve1i09DuAD3p4RlGDILKJmBB0neGYg+Ef1iOSRbbtCe/BjMt+zqkiL5C5uUL5FhBP6jFxTppkQ0STaQ" ..
	"ctL+2seZY74nBFUfrqojTcJeCz7rdeQwTAZmqxrkpbHjkm1K0PfRjbb5n+bKw/D/+OupRsw81tKFTl8NTKTwyQ0j1AiovnnCUroQ" ..
	"JMLXHmyYMYA0KGYluTaP1/tmK6u7cyttO+p1sH44eIY6lFsOMqcVIz970OcAgYMberWOmFbrQhOTpIN7XKK0tKxwepcoqv0lGM/m" ..
	"RuIc1rZwXagL3YkvXWazC4EMMK8QrsVPheXmvIF87DOOlXQYlKEIWntHgy/f3rPEFe4riwUzKEY7vTeMbywQBVGQK2OqpO4O7Gl/" ..
	"Th6UtpwbFpaYPBSz1UsT/T7uOlaDjlgdz7W3j5WxUtG8G7tbsAfTIrziur8hFEEKepbVjMCWXssiX8Onn7Axx1W7CgAD14d/3gZ1" ..
	"kySQrhIvHSCOZnSp1gWr1k2pEEhGskbYRm+7Z/XioSt5SznUokPbc3S30ieOKdV8nWD2uYqGUQbTgoVwe75Oo/ZyK5S+PazGWLP7" ..
	"J7zVcAPSdNHTxN66NNN+fT+sJeNypW2YTDkD/epDj1FtzKgGzFmso9Ci1WoNtQnXarapAZSpcv7tpgXbMxC6xLWKT4kgLnVbzLwD" ..
	"F8sYcMGt4Hm7akjM4op8JwDj7lSfpJt2ljNMEzEbeV7NzkObfoSlCLVK+wH2RRf+FITKbb2rUgaqk+o7aRpVwdV5e5HezlhlZzwc" ..
	"MAhRIm66zxbMcfLCBaRAi0Stzzf8cGvzzbz5ySancFC9bPTnSYx+5YPktKymXEJ5EM/DrfJmReMRisM1zTqKGDGuwfGV/YcxWh39" ..
	"h9efZIz9Q1h6WrWKAaNtKJZBRimSlSfwxFNCbzgams/1+FRfbakxR66yhrLT2cDMugwBvwfzFzUN+1lf279jnkUTnZb22h+GwQKL" ..
	"wgPMZmKq9WpWWUpDgiYXATkLpa09jKYOrjjXrZBgwx3ZdnTrz8RQVSQE7nW+N/cKhevsXrA0kixmlOsMQTZnZfGDAwCQa01TwgKg" ..
	"hL2tQai9Iy1Puu/UgNN7xfX+J+PmuIPCDlSZ9gToVio33GTelgZzscLki+KvmMRH0N5gGWFzS/wh33X4wUW/FCGysd3D0uYXp6pO" ..
	"/asR/EZ/UNSh4VQ5jauVzOyIyaCsmfNjT0khW2sIkSJZPKwKawLT10Gu2bHaj4obOBIXWHTtVXubB46ozkt3Whnl0C5aDQfgVMIt" ..
	"pN/JJls6WSs7dGl436rXzNI4XZLvlgWcZmuZMmw0T41gUhRUN5YFHtaJp6lIzV0NjRWrgsFuWjJM1tRnoIwjDgrWkNiYHsG28qxh" ..
	"GzjZHoJaoySH6DCtF6mjQbWU/l3TUy59Q0zjfNy+FtEl0iUI9H/GdT3lXIjvOzXRGuIgLJC8/s7IqfLEISRamUKbFFVDqSlTPFxg" ..
	"G3sFbgSw/inDl2iEOjZJ78zlSLJ/k8fV6BHfg9bqPO8OrglHpaDI3TUQx15wKvdsR9Pf79dWu/HcQDyO6djN0G+MnRGe/JiPiqIH" ..
	"PngQImS35HiFCPoCcCU7S5aXQhEq+7d3v7JQ2N40ggmUWe5R5HeVmQ1a8aV9LqNUf5MZEMe2SQsyIeBFeFoHw2Zw36acThCTs+19" ..
	"rYsanQRmV7lQzSoFYCrvvTvCgxiMO8837bLMCj4QphDkSOfdCz6cubJD0HYPMbt9hDYoiZ4ReTj6G+v+c3Nw6cHJ4+W6woy7eqFj" ..
	"QP8ppC3GOIelDnLNxi/MVpsxHn1uPlXOPCYDl8HtJFrv8RTBqR20VF8oXRqDHbv9QfxZfNYwUfvuH68bSLRNxmG85QCqwu0q9trR" ..
	"qs7BtzHTY9JiWbmk4UlV9hj8z/em1mz8O4Mvu3X4rTWaLPyOOk+qE5l/fbyP5WXtN27mwEBYeq39RbNGEchVRpKMlabBxgjxGRSB" ..
	"IxnyKjr94zx6F0w64r0SDeFMP94ZPUYqT8Hu3cm/N4BLY8XDpVmGYZph+LPbXbtqWhl551tTXVo1WVq6txr+cIICPkjGjuBiILWW" ..
	"Nm/9upDycfy3kw7Rgc2oo1/z7pS2L9qOCqHpydvt4rryPkUUvqpSc5HL3GQpDbvhPk3Pm+K9er+o2qtwncdTAPrdZBBCIwdcN04b" ..
	"L10N1X1J7U42zP6O6H8kuXSjoOj+zmum1//GNnPRqXR+LnCrkZPOK6AOPI2Q6Iic87sqLLFNFi0AwcK2hOLtziLVn4ZE/xDb82ei" ..
	"gj0VvCtFGsHcXT2R++Yb+CAZ3EZjrQ8HjTduoT1Y6mkcNbLJVibork7Ek26wIDwtsOBipsoCjC7Bau3RRMJNZqJeVZUriHULnPVC" ..
	"re94dn0bybX14SeUxnn83/C/IBIKI2qifegQWLJkc10dIclvCQ3gXR2xSKKeJWE1kjWkPUI4MD7GSJ78C2T5QAneau6nCbV2Mfis" ..
	"EgSyB8y7ecbaY4aKq9kzgT8tsPM8T1S3wunxLHUcYQOYp8NYIqhPxGmaY2my+TnBcI8deM4kvyHTQ0HaHFxAQvOIgE0W/GwDghZ1" ..
	"/Ag7x0VdLteHWOybVN0NuNZa7N4e3o3V1FALBVj+xRaHU0pOUTxwAgBajuwpDuKaNjJmlFpvc2ZCR09IkiYaG7jJt9SSj6NN1Jhl" ..
	"WHmnNZQXrYV0HXrgz/pz4KUml2ZEz2mh2F75FvDswYy5Rl6WYy/ahLcfzD0Yjo4PWhyN7mD5n0eDjgWQl8HrW5HVtMUOem384eZ/" ..
	"BFPbMG2hSyXs3B55P7Yb5NHJ9Nye0kL2hc8o1s1NWLXq22jdTBAxvmVbwTY25c79gcYtc61WvaZQRDmiNfWmaF7WbxPkN+RWmeCZ" ..
	"4EUFB6lEBzql1Y8SHY/7JBENKPIObitKojvtMnzIZMDu+cZ517rze7JRMZkdNpcQ84pKtesnOAJyNmMlItnun1q9qsHjSUwFogBW" ..
	"MjqCokZfX/gs0S9b4nDDG6dp7a+NTPqLxZ0k8z0eUjT2y2wVLHEEEEdXVSBrPjf9eoMFbwxSrc6UxKk64o/DVhDSEnq1uNHHv4WZ" ..
	"6BIGPiDfuwRaBvQHYsJmlY5jowxHCWeaE6ISiYwYmq+XHNbevIXNDUqwkZCS79v3ABCE5coO4gAF7//S1bXQckGU70AtMEz15S+y" ..
	"4CYtwuqeLqsbzCH7kGbVbPzFFazImtmeGNqvAUnNIX7rObGCZ3SZjt1rI02tHKbYt/oVOnomcle+A8IpZ/GeLfKD0vQ+8I/iicyO" ..
	"EeN+SWZDiokImtDjPy3xDwpvOtyc8s8wTpU8yjVU3Go4tPIkzlPU22n+5Bx6QGSDeYLl5c4n7sZ7QBUVSCTkJuwGV2ZECU1o87n0" ..
	"dpsi46ct80N1/D9YG19wI7t/Gw5SGL/fEMUrZ8QJl05onbIaHOSpuYe0ivsZApobmSU8kFxSHNBRibktlZtpV8+HGM93fbij4PWa" ..
	"Wn+uG5GxkoDzl8Jd599finAbY5arNL1MaHzTpSfEcLUr9uxIS0OIV4SOmiav9YEh3ud9soZ8bRh6IgJEXvEGaEClXcYQ2qMUUWkK" ..
	"wob76KsZA29D2R8Ziu1hZ++WzbxxCda9us4guUf8U1fQtGI1Jqf0UR+xGrK+7OXMsfx7kCl8ZTqljjlydCuFRfTzGZJ6plj+ZprQ" ..
	""
local PAYLOAD_P6 =
	"oM+jCEh64sK85TBZ7fIVaDH78towQoXbsFQXcMQ7R8jlvKFMy1EgtqLnEOgRIZV9mYRUzZ2EMgES0miQJvyr7pX/2GCPB2dir/L2" ..
	"lCgZxUWHVX6MkBrVr4VUSrP/bHtEm236UEoJOYuyPaN+CSjsjVr3IEbp45sO7xDoWcmzMqDmmag9m2HlHL0iyqd7+GeLgHqlXc9h" ..
	"KnVyrQEl7qNg8OVV/yK13QYpdgQo0Sa7PvJMsECLTrfESAukRsSuPM2fjy8Dz2bEBg6MdFaBywQD3w20IqSX7Eb81Id+j966pm8v" ..
	"PuiY7p5xt7fp6+3b2VYAWTIEA37WdU9MYHBlJGHjmFfNdiQgZ0iZpiT9s5haJ5vyk1X/Mvf2Qzk2eJjqoI3qF0i/DiWCI0YO3TQQ" ..
	"JuIJoQ1JDFNJAuel+ZakJc5y9MUEIOU7gjaYd97fkqDbUhGsQSGbMPQSYuyptkWao7iwQcp072cchggSKrjdoUmMFngID+tnqBWe" ..
	"2VmrLg5oscVRZwi3gEV8suw3hVPm+1PHDrBVQ0PSgB4OWibUbCGzNpnLetbp8TblD+7p8kw4k95yv5dbUiOEmwFVbvsxAjwUDCJ8" ..
	"TJjpifmhzD5QZE4/UqaUIe2aRSWLrGhrOI3NwwSdUhzMXqV8HYUTCBYSiAucTfAOeafX0ByBV0zh3PdZW7Y+57XP7gI34zVKm+vx" ..
	"pVf68KN6tEuOP34dS5awTw0d2iegUn25GGmVP97oO0rZbSOgfrZly9RRtql2dI5Tk0ac7grDFYNbQP8+NlB+EbQWH0GCcOpgGu3F" ..
	"4yA94s4d2ibcv7R6SS/dTpv2wkAX4r7weJiBfwxfokacmz2xz+eGj7eySeN9XetfSAxLpkr6uKIN3IpKsgkEyVPWNNyr5aWUjR58" ..
	"aLH3kW1j0Bb6okt2qsZxPSBNoxUKLKg0F7FYibuBp3I8yqL1wot9J1Ol77xkAa2UhE9Yp/ldwqQX/ha/om7nGzMzGSpsYKHjTfQr" ..
	"t6e7avBzmNF59qf/zNJ1bUWyXCt7/QKhiLEVn/4k4PAlpiu8corIFVow9MkbVW5OspOxf+Ec9yDxzEVOC0tKLx06hgPAfXQ1kgoK" ..
	"RKp1KZqFy84ClEDvAh9zoXhegw/abcITw4W0E4GseJnwJ/2hlMETbbusg3r8stvf8epVOgrFH8DvApA4pOtikjgUaMlp2lUuzbhg" ..
	"vpypDcQTAa2OP3gUtOiBTnTzDt0xVqNJcTNYsV1uyaZ0Vvy9QosgfeARfu8b+XqqLsvObn0k6d/rtLr3KqiRLpTocywwm18kHSGX" ..
	"5a4paETFoCWuqtQjvFBJDo7f/+OIkFj+hw/polrV/g0Wu8k2ZTAi2RgS+eJgo+x9VXTLLLCsnhP2cx/Z+hwjIWnDst8zjGTXHVAb" ..
	"rmJheLLa3LL3gkjEW36xxnnhNxN27keSmyXxHQ+bNzzMkt+ncgt6N3lqO56W8L4s338GJFxOyK3V6OeSyj786izNwK7BljlN7jSl" ..
	"PCt0xmJhz02ZkFfvc384OMYp60DaS45GBXOLLHRyHmfbybPRET2o2pp3nTfIyYzCXy8N/IsZ42zmKRECb+/y42NpcsQtYj0gQD+o" ..
	"dFPntcXNWuHdqe2EgD6zr8D3rPnoargynLn+SlSAM29SRHp5KwAXihtqun2KpMVgO2nRikzAMBXgnuyNFOslCSxzsxlf9ZfYXuHG" ..
	"GKmYWhWWh4SzZZgOgyYBHM78nae5A8eRBvjtjCwGyGfUuFpsY1xHYcuvJXaXO0WO0k9OTy9i8O9+iA1BO8ZCY4kkTy6E1WLMvWXz" ..
	"59V7rWPcC3LZM16MDgO+osGIpIe2hemDB6fYNPgTlsApfIi+Kp8QURsdQ3ruf6O5UOXNmtutdu9125zMGS8WpqunEejmpBJxVOdj" ..
	"GGbN/RIyfvXwn8kAKOBACj2r5Febg+/vJx6bnjaS2cHISutzY0ilX4qZu5xNxm3oKvtQ7dmsPkcaH6nuUfKvD1bR9XobMUZd0VaA" ..
	"TjYdf3Ca93hgq85w5pX8CCM/nZQWycL/06FCymaMJ0QoyHKYy7fdJRMwIUEYia0vdqs+b1e08UwP/ISsff+QCjLiplLygf8Q20kn" ..
	"uysVBD3sUaS1SzKU6XVqgRsm0JbhkYXInONO6o768pEJ/tKaj3Nz5LE7b5BMVnqtLf7BcDf8p2KfP0MO+01qETESSHqQ3ZLqHA0w" ..
	"52IzugfvJ3/Y1XdFrnumGNDyVwyHd2zoOi2K7omvyzCMD7Ur4oHoWQPTz/Rd2aD4932Y3MEvZmxIi44kiuSYqXYA5Y5V6+3Jwf1/" ..
	"Qc4mmNqUaOtnRzUVW/qU3YhFNBwnpQSV85Ci8Sf9Xg3J6pEEAnuiOlkr0CMu/S21bOmoPFgJ8se8EFKdsaNuhfi5fbpa6IfFcINK" ..
	"5yGzoniG9qeIHMHfzdm7VQveImNqXLeoFy9QpHNZl9AflgTpIJVRZW3+UW6dEfOUC/BnSpVYZnwWw8I1ReNno5v8YseSuvBVxHC2" ..
	"aJlHWs5Bf1vOGuSvdoma3++kysekJya+v5zXlEpbYAfEgelRizYve4pR+U7HglOOjdTCTx9+bsqWA5SFmIGZwBqg589S9RFnqfpc" ..
	"DlT2z6TvhhnbyIXC+9flpeIIaBKEn5b/FanaURYRKWA4CTaLoRoCY3IjoWywPQMxnGk5Q/87hZ5Wj4ZZNo75AMtoA77x6/tb3yRS" ..
	"1Ao3WdPfoZa9gwD1wkbebO3itVZSwcML+49jcQQ0MAmGLRnj5XuLfeFFCAfHBNjiXlk+QiFZCYamoyguiwJWKKi228B+k4BPD9hS" ..
	"4ZnzbbShpTXbnoxSnnDcBALgRVBbgT67qJ5lx/VDN6KOGhFWZqKdj7Kv35KEJJvliOKrM4fJPprbRdbZOi9xE9bp5ySZhM4sf+lR" ..
	"k9dyBvKaVAeAHYEoximdLciJwb+ReYoCBKPG+MbSyQJa6FjaMt/AVPN/GPq4XjornoIa8qGS4y7TDKoqqvjSFpMITbhskDE6e/9Y" ..
	"UWb1lzyzqAH+LFI3YwI/BnsFkoYc+RSe0Qe8W5YOWj8tvuXQ/fGR8R4HQFrfodlDFmXfNO1IfOJyCzz0nQu4wrqRt4rIRkWf3+c+" ..
	"zn0UfLfIgRLWqn/UuFeUEqxHC/Zc/b8vdRVWycZIdgclAENANfgr78S9VW+gYVnRp+/6nxGna2+xkmee1u+6NTAgzknCWGy4KydX" ..
	"yEW3r4eliY8K6dRVEPIsZk0I7nkDBVgc98xubJ/2SdFC8Z49Nq3f/eXECiw5pahk5CVpNZMyDY5Y7X7GdFWfwWsJzd/pjsTl2mW9" ..
	"AvnPTBF/8zqA8TZfcX1yWq2CMr+/TjawQBP6PUVt01HPIudBT1dEYk8Hxb2EJnHL8YXLc7gVJv9US+EZblFAEMCeA+K1c/h0k0Yd" ..
	"lO4rlLFw1DkIjgXBBGAlJe1btwR2UFCB0VgAgXINwxUh4YLTIZFh1g1SQRpRHzGzRgnifioAXE0feUuVhLA7IjESnxDvpWiI+rX2" ..
	"S7mnknaEm/tZcFjgbKq4uihaYZH2cNKBCqwtV4w/0UmPTxx94nCr65c2OD9kV+dMHR8k9FuSzX6aVKNPJRk3w6l8f+6DylL7ZCLq" ..
	"7HhAK9vpamhmOKES+bVmoQHHRgrGqmE1XO4xwTaRkxLCVipEByzEseO5QMIGvKEu8POalMGBidQsCBh4J/BOyK1nVZykyxiwoRuh" ..
	"urkJuhz+JWxtRSlGEMZdBse1W3G8XFAppKZdissM5k3FkbFgkA5gMExgJ29v9o4LQRPRphzdftB7W6qtXiGcJ4R3H8dRBRQ6EO2P" ..
	"52W/Xgw6Qw3Arx3js9OnfzjkVMP1bVWiNcX4YaxX/vpTFM+NXpG6epqnwH5LJZakYW3g3no7NUFEeScuT/UfZC8A8vnq5x0WpGCk" ..
	"oXUzY5otMU7t2EXGsUUMHMmJVfQJisycJKAQG+qE9v2mamQkaIB7zMXAjy4+SPVDHrH8U8RxdLc6XnbFmBZC4G54aLe9cNeMe/Fx" ..
	"BMlQo+hK4gxW0oAkeosDdWSOZP8/sh/KJXyQa3gNRylwk3R2boP4/TtySeLtvlcuLfIrC3VTJLWEoXDMYq4qJ76So/06DOE5YLG6" ..
	"YDoaljD3vaZsGeCD/4eVNkkBYpYxgka7d10hOv4myH3LkL/Osthimakb9BroICQbBlBs6gV0k2Xlpgp7QO71IRMFiLa1uVSKQkt0" ..
	"iwBvqK6cd+QQgkC/06RK83kmiEv8IlVcet4ciNrLATKqPhSBAx/o+lsAFSL/GdAqHfMZIbQMdhXMRy3/9jby45wAfeqb5eUNahnH" ..
	"AZ23Ur78h/d2ORKDwAxOhuicx15q0uUPP2YzPHfP2f2202XaX/pEc750X1gQiIjz0JLdrhlfTnDpV1eNdMX3o2XRMR4bFMMe0C7P" ..
	"Y104HcBh2uhQ+8XKSNe9KF+v9XXBJoXZJ0xLD6AjllpB1M97Ooa4Iv2K0YbmUxX0+MNqThC1+HmgjedvQ1GpPOQF9y7RFqBh8daY" ..
	"eaFIZKh0BBL05+GQBX39Z6ns4uvj/zxD41B46ow7XzrS/7NnZIE3vpiOYNveL1/jVFQiNpiJWC6jUVSolAypKHoYkAdEC/qdEV2Q" ..
	"UP7HTRD7EmNvnQ/YqF8nFNzTuJ3Ba5aFHS/hYroZeJXCbQEBx9e0JlDGTUNCbAL04J9V/eamI3zO0lGwWlBteym7voYO8tpa1QrJ" ..
	"cPU+fA/7TtPhQ9M2WksCRz7UYVoaRl3CbvfWwignkuY8dNKJq94rrk4kW3dP8zm1+whPCMF1YF8ZynO7YmSl20ALO4JMCHeYtZdr" ..
	"vqxGllZ6mP3Y5UnMc/Lup5iqami1tT6Gb+F0uMAtQYBn+yeAugTwY8R1eYaKRd+IgiQlUjjuOeUFcuvO+tz3rkJppkeOJcKEsoRz" ..
	"VamfYDXNaFl4rlJICw8Z0w0/Zw2IwdhWhVQTGz1ZCDsQhn6ZohpMlrmSmL9zRMsKHnaUGOi31TkSsNHlrzi3GLfthxEnGp62zSb+" ..
	"gLLyP6yUfzDnEqhqTTt7icqykcAuqrs3KgL3c4LsOKAgNOYFeiDhpDHEMemJomFvbb/Zy05ZEJEvLu/+m2Jht5S15cgyGuLlizNW" ..
	"T+g2nXUyNtv5Bt9GzHtvcWDJ9x/zWseDmzSVA/27PiLENsce2OeHlIoiX0j0ZhH4FTGm6C5FRIAJfYyoA7JcHLNzEb4rHAmClnve" ..
	"6Va7AmjNT8Gy6dhGZHiFMW1osJF00IAcHjx7vtvouwIzLI5260lrh1d0E+X1aSD3AQoX/8v0z6cpJ+EIGRJBZ1866aaaH1h3z+/4" ..
	"sdGRDoUfojFPOWcXCKUMCmAW+NPUqRZjlksdxRPtmdJo5Fwaa9vxZybkRivIASTtK+xAa+HUiPAAIq7c18VOXXH7//brt1mbpc3B" ..
	"tH2cxcxs12ih00PT5EDyGXvQMESCf+pTeMAycfaYVd4zXGcr2OMHjaPOGcPB0N0ig0GWdikcpHD0AzUXAjFv2pVfI+jR8Hb14rzj" ..
	"8CFqDxhNr+8d61LHqE0Xr6Rk64Ym2KjZ+uE4DlBymCqRLq3ix6B6S9bbGLKoHbYayRAXxTAij1/S05kWukixC1k6A+H6nU4cS45n" ..
	"PgpfOSzVFu0RBZdfBvq2oCRvrh2Np9JW0JBFdPuiu5Go1ufu0EDb/dA96dy6T8RCTlFXLeYwXL0X+wPRhGhqYHk0vGt07CQ3C/tb" ..
	"IUGJ/Oqmjwh7OTmtp395Ozc/IiKfGK6xSbQZfMgRpElfP9vSN1m391SIzegIUPqt6jiU4EtjfIAfa73lw4Z5GXAdvRJCsY6EIzgC" ..
	"DxdbyL/f2uV+fMy9RnjC5mmZ+F1D9IGJSkHt4sn7EVb5DbS9i3yQ04+O9Dge9gxu+eOaNUl21eqlB/6r1nH9ILnqqW0NmOCV6FhC" ..
	"g5zBrcGR1jHy5d+ORPU9xT2psWTHmR4aFJ54KtP/OReUo1sZVfTAf8aXTNBHmgDYzNSUutBaNj6SKaofHwr5pbrY86BVSvWCRivG" ..
	""
local PAYLOAD_P7 =
	"I/QGbEobuiQHRQ8KeVnP6Q4D/VAHmSXnd2vsABv4tgGWITJ3Pwcccrm03yieavDVdLOb/wGbngNOV3FVrPi0e4L0+AH5xbi2ficu" ..
	"2D6cVVM93xC6CB7sF/mkQ+lRJ6H2Nxk5bcTylHjxbzjh8/rYdXig+P83x0ws7tqur3ryQXVPob75yO+pY7OQsMfPzfnKZZcWX2E3" ..
	"fls/V5qoHySAqNvzNEC5ebrQ6YxLVaVePJgiNA+b6rL11HopeCiumAAWsKUHAeAlaWjql6Jfqb1+Y7X2qoN5v2zt7DPsiLC2y0xX" ..
	"IxLudn13pseSdcCFgwPs1xCrQjLJlmG/6EE8m6HUZXEA/qYgL60c5aYWja+NY+dKoluDDCTdCd9rwRQ25EJOma1lfmu7ixuK+O/Y" ..
	"4dKb2YWmmJxUZ06OMlKGD3nXsSojGgPgXtWVkAq1wreSk2aXG3HH2LaK923/JLlyYuXXfqlRUHLrGpNavvMhBPsdRQDMkxc3mglr" ..
	"FUewO5gNWFCX7i5ZNBQzNlBR7Vg0TbshUOspXQT64uC+w1+Y7ifXDRUZsDeSBeE25ht11H4q+SeAvKGi5N0pGl8MwHKa99NwJu6M" ..
	"ql4pktZn2Y+Yw+tHgTjG1QFSGvA6J+xUzAiblfKr3vWTrY/qh/opWckXPClIwiyYef/pxV3uDTd1AG/rDPvRxaBpf3TDYRgKc6bf" ..
	"RkBsQ9KVb4gSyA+Hohp0Vb8/e37UsJJVgBYKFOqn0MT17gWrDgZKJ1iZruRltQ2o11wapg9Hr/qoYaHJ9TtPZDrPq/vid3wSKgYL" ..
	"aoVrnP8xmMh0XuimgJgx4u/XjND1nkh2Hft8+YctuPzlNt2R5CqKiUlB4qp378NFoBZH96Ae1fbxkI5xTHVou9IRCo2oO4ljp62g" ..
	"4G3LNVlPrvcg/r3njBZMokBAlw1FusGFRpf2xSF88h5YBJRANe8abuLzSzcbVEYMzTa7U460aBsipsXsf/8oxz5mlDuqWqdaiPWH" ..
	"vTKoNWpTkShOgnxQLPPm1sQofBKxp7xy7ARxbvOjwDc+x8jbWleKFUQPnyN2JOkiVNE3YIft/NjM2xWWopcbjOvSMel7DMoXNv3D" ..
	"w14PpjP1HRYHgyxw6DudzS7aes1y5TcxZplyszKMxaPAipGJ6RiayYemLDV4sqSFuLLACp2jyOgr4+xgRlB3CfgybQvNL8j43pIi" ..
	"lzO4JRsKJ76ndjQtE6SVXuAOt+cg2Z6xr20lQJhwaQLjPrPxku7o9YF1CQmld3RhM+hVOU88FiEkOTd8HyYwqvP+l6aNkmSUbjqK" ..
	"519cpbIZjX62cjd6ZWQ5u+KMuLbECwvwyYSpszJCVfE4+AW7/p7AXXytNH4PSRmoKGe6PAL2cW1T8+iqGHp5pTO4abEclsszuW/J" ..
	"KOXwK8eSELomcwMDcSzsYJ7daZgORDf7lRU494cmg2TmXOHvQ56oj+DoTn+1WAvu0Nb4s7yjq68JKRWsB994hs1U5+jXh4bwVAvL" ..
	"3OofoLqLti9tyoT6DtWiZLE16mcytLjxsCyNNolXJB5WQOieRdemorUvIPO3dttljQNFRqLgFyPzSmC2A1CYcN2PR+hrpDXhzoSn" ..
	"fa6mX+ZhU2TpN4mWDbZT+3re2x4u8V9skGjv4caEu1wjh/9r5fR4j8BUeJyU8YEke05FUbZNbf2Akw3B3KSq4B2yzED76CfENM7M" ..
	"zC66IBq6vePH4oGnNm4yFdgbgKYrMMHF/EB0kbZiM93AnokKIjOBNFFyJdYZoP0HoEiSMxcoYhvnt6J1jYjB/BK98wI36A1Fpkb4" ..
	"/S8oSb2yAF5Fxq0yyfB1lLp5lcUxUsK+BRWe+W+9/VosB8EgbbOL10UEr1n1bEcyg5GenaLEHWinAMQ7giKjC89HzlxZ9vIp+IT6" ..
	"pd4R8ASKzd+57meG62D+WBujZiZEWS6x70UwWaBtCZfgM09iLLUy8+9vrNC897MoXd9dYs7tztVfaDR62gIXu8rFkgDjUmnCd1H4" ..
	"b/e6Ds2pAG/H+ztMGMg/X4Y3+NiEfrIAofnju9tPmx5AJGrm/I+JGD3aiIAFmAql27vwLA2J5oY7VJARulRNZJqPSMUhZA7s9MUA" ..
	"wpbGrcNmyzkaYy2UaqXPy1g30TmHR1tETi1Pshizxg93d7H6tsQ+eoWdnTw1c9sRkSHWI8rQqtKweAMTrM8lSc9GoUy7B1iAUxKq" ..
	"LD4F3RUUWIwTDmrbIosMKrg8i/t1iEEWrsqJIXwy/7KSJ/0EBORbkRQkPz6jGPO6QSAL2rcRdzaXqObzasSihE0jFGdlt+UF1cfT" ..
	"h9SsUazSixJyI2q/bhghcoG/pGuuUy1Yo9Y7P7Xdkr+mgHbiEjmpJdySRjhCw4FxO+rwGaIJKY0AzlsrJG9fhfawdGJxPVUCv7ln" ..
	"jBVPcW+6SKWsrVx4jIoUVvgggqoplbMepz+Wds5K1Xi6RYdYXrogFylIxx0v/IW7mzMxceCFW69DCsTqIaU//4PypZFhlVK/l9i8" ..
	"reYejrUVsSjFjt7Z6h1yvMScloTwelufTJ4+kTWxRrglmNTBYuX6fs348SJwz+Pmuq3Bz8KODqK39XfRRD4Qc/a/4f1SqT6NoFMO" ..
	"rDzty4lWFtLxdm3aX0VTK5RU5VyuOESsynmcVRzFL2CKT1LFJ5YtSgmap6IQ0pUtnKrHiwKFLvmTes3nks7z1/fnd8qEnMXTnJrY" ..
	"DqZNXHCqv08kLBpgmXL9IrPhVW76WFde5VeqgrclBl4bkrdn2NUWWxj4WCg4ZNNuyeO4YNE1kQ/0hDasctCwUoWFIbwydb8eLWx0" ..
	"jiIo6Fb4kVJIo/5OYxPv9LJd2sR9iFUZ5N1YSBpHIWIwr78zytW/+0ImsYr6vNoGtliGXsQe8/zNGvlntwUzg+YNTzKTYKb3mC8L" ..
	"df0BriqT1dKzeBrHhxOYHNjcrpy5hQtLBvKH0SFgSTSSGFqAAOiyNA+ETXAZuDyNWEVtDRaUX3CqITQV2fBdENVs826+MFZBCZHX" ..
	"qZw/RtRd9Jmx/Be9SdYB89UKXRNN0AVd2AVvW2wIGRGdjQzSdmkbzaC1KiaYpqwFoXXvg2LP8jlH0fYm65FvNDejy3hk20IVpvHy" ..
	"QnVrgQl/4/PvCg4hl+eRPVUMaK508GLw4FI19AfDoO9g2kHe7GJQ86CQfqnTcx+c9WZUjbstBn5CUkaJ9SkKBE0TmR7WPiwsKp75" ..
	"TxNL/6TsFETzcJre72o3rBpfFlCMZZDH+sg/LkBq7OhhU5PuaHPo7ffJmm/+9eU2lzhpjK+wxnPN0friZHsGtfpwoBaoGNHYwo1t" ..
	"xmIE5dzXF0yWH/2QBQFjrjLYxPPrXhrIsCCXd4ougIKuWRVeHxGsl4IK9HkM2zHWqSmiwJ14k0YBKM/tm6nWl5znUh8yB6t7Iw20" ..
	"bkDreuha+QLDxyd3TVsx2HWRoG5E6tpX/y6Lds3l5W5m3iNT0zfjsyoUQ2fqvobq3IhsdgK/dlOWgjW9UxcdBUrligiM7oe8CfI5" ..
	"2ovsFjtGV+R5A7z2sFMfxrn4UnjVhT+V40c0Y2UQOkKGUlRJsEg0dnoIaaI073hc/QH/tzvVgV6T8FFAjTWY8aPXPykmEHEJjAsH" ..
	"mfbvMzzq77Kd2NHHMX61BuXfteJ3AJYaCFqEitiWlqLjsf4YR2rOb2mZT3omsqznci6L3MZ9TBaMOGtV9bbKVmuG4RgoHFzy07bR" ..
	"WmkLG3rzzUM9QNXEIQ8OSHP7pG3ExFwSZaakxrj+jrmoVjZMVNs0xVte4TAmpJ1DNy0w/sac3NmYRipV771M5V45UJyxBoizT0aC" ..
	"HmPIgvaiVIVb3GTv3t1TUtx52WOARZRPa4WJljramCJTv/vQUZkx5f27qCo5FDYYm6PfL1cdAHZ2mstK2/hN3AF46uA1k5XtZEUc" ..
	"NHzv9tUzyjuFnY2WtKvlSU/TIlpNFMJOqbiZrJmmI5GLYKRs2b2u1kgTAojxCDoCKKRhHn+ifJsjoBnwwbc/gVYRzT5EVwaWOHaz" ..
	"Z8kgv8L8aD1GwD95Zq7VhGlCimEe07aNmJOLVrppU7WKqP/0AKkc6BPJMqV6+HCX8J6cP0UB07RQN57zFnQ3K/UADmRNjF0+rUEu" ..
	"YXc8EiCJy3EGxVz9NgflxHzHZFDL1ce6vnD9m7deKH6RQGH9BGlxQYGiq25ceU7iG6thOIda/NnzUxcLcbArnMhx+LFENABB+KB7" ..
	"vqERpw15B+owQbevpxJJ7KKIBkwWsME3+V2u5dTRdnoQkqRaCyNAcnx3TqA+uxU1ArzIx9A9rDIfouiA1U11qiaSclW8aGNfHSC9" ..
	"5I3nTSvVMGqpd9k/lMIKC8+elJg5VuqcYPh6wFEoKWg+Wffz6LUlnlWq/1DVgq/uvFZPC71pK8KLqGWiuYQB6kL8QlNpKrXuEMUg" ..
	"o7iV5zpch4bEvWPLZxvhhVO69377hTiOPoXUoXmCgrW+d9utFUR0q1MC0bAa1jiAv6Xn/G9oaYSY6xbd6OyJivgs2mDstfqxbqX8" ..
	"4eubigfo4X1sNnLOxDPl0DAAu9uu0S+ncUUMZIpsJhEYXDJvzbhiQu2fF4H5S4rOGv9cku+SMmpQaLHfxx1i1aaDXdt0UMzBriPI" ..
	"j6lhrO6DBgUdI5EGIh6sXKdG6S4h+TRcsanFI8Htn6oC/z0eALAaHeUyZjX7Rp/9Sq4p1QXGFitFvPUZhvvQFtVVMIqfjsw1t+D3" ..
	"uF4tm7S3nsSevwWUJ4GSSghygYkQ0KDU/ZQ1zyp5Jte91Q2XvkRQv2LmnixO6T1TGOQJgqW3EiQylE8XjCucx2ViMYc49KTf1YAb" ..
	"VZ7KGMGWm2H/wexW63ksNMJANH8qjEX1qx4mie9CLM29QaDio+Fg4SCIIJ+0m2VPKb/DhpZW4SNgIHCWbpnt/AzKdfqwm9daDLvh" ..
	"GPndkZXiAfWeY/xsEvraTVpDD070w/inJhjsTvFxQ2nkcVfsREdGGGrBKyXNbhCbeUdSwHqxuwpc80/BKL2Jn/wrosxizcl0HNoi" ..
	"jPXZ0IKuO6u8eFjGmUuoBc7CktXlqtAVJAaVHi72JlPoMqXmn5IlpWCm32t1ASVaaZ0b8yB4Fp/u2A6xJ7pMyjLAbrgovV9p5JX+" ..
	"HDERomb5u8PQh8rMTHPgbjO+YT7C+A/0sx5p27QUkXsSIVvZdDoFuCRc4JqIzoZjW+omWMNnDnHJJ+CqRevXNbuDyY/To+TNvvzW" ..
	"58E8wFAwaPaMV6GQ4fTZfLDTrTfKv9m4L+hwmcZOnGojDQdrSLqdBDGobX2WB93smIjS6np8uW9vzugDIWz641gzTrTY5W8FLFy6" ..
	"2X5YzDCYDvdpNTtso07GnzvrPnCkL76/UWh2wWdATMxcADtkCnlVwd/N68FID5UsvfxOL3XavUbo6H/3/wnDqku2a8DC2lVCu4go" ..
	"OfFWymb+z2oMVbyEPMTsv9qE4+FkZxG0gMxGfXae3qZtJd6UnsXMfPxHeX9nnmGQHlwU2z2nM48rgXr8e0SymnbS4OkkDk83PB7L" ..
	"hr3zhSBdWIELe9G9M3gyn3XvvUAliZlblP0JiZvXfTY72bp5CETT9wU9i6ihhm+Mm5fFJeRoInihyCq8ESXtDau/6xlJR+2rbcf+" ..
	"r7m70YWJL+qtYwF55lRFFqiaXyguz+4kYM7ywguisdhO0v4oo0rvuO/nrDwrpn4Cky0ptMwos7f6pKnOKkLPO3eVYhPClIfUFCww" ..
	"ZCmTd8sYwZ7RS+C2/C8buOiPRPtXQxN3XA7k6wV1CTskpRHFBzSOGIaJ7c6FzfBOXp5mASpldt0teXNl1Y0mK1mQ1qKvzD+LUTbj" ..
	"M9Pk8W3/Bk60VLl4pjCGKkk7ravqhV+yU/0UWhnUe16EXTh6O2l830CVK0jucvnxuRyrkBanVfWEWtmR3TY8B75fJBvx6P6fxz/t" ..
	"6SgWHLbqdD3E793y/fBwpowuTZ/DUWNApKlfWviiA9qhupNnNBW/tS+uEqGji7BVgCv9jBuazR1ZahYOfcwmNYmwLYmKbIqeoPmz" ..
	""
local PAYLOAD_P8 =
	"nUXf0W+pHfUFTBzOmddMl8mp0t6C6Bi6MspPulVhoyPj7XDKdSqcBGifqx6Sc/d0vcp5PGeMPAptCdqPc09dj0Na+a4HIO8bBYkO" ..
	"/pypSv5+HONM3v6iYsL3or5oSCwoM4aqSUg20tUVd8YvGc/7mTy/XsfRzut3NAkEW3xu7/zXa25/4lAlKrlGB6ofbxz5A3x/Q/3v" ..
	"it18iCk8AiISuIjLC5RJ0OlHMxy/Z5xJtdC76dH0+ZPhSytCVP2lzNpdz+jHIEKhUJUoNfv/ygv+1EQkaF/qtd1uKnbEwUvz9eeP" ..
	"99JxJbORwFtmPTdzhjar06HGie8+RdVYUvNWU9Ly/AajksJRh+W+/oDWDojThoqq/KaDOzSUopHJwU7poKHTRV4/YhY2p8kjt10j" ..
	"wvgQy8AQB4jleSwATNqReZwyu4t+ELH+xS6YfiLPqvqEZNqp7AvS/54Ie4Z2y8iuqn2/dbRpNxNDyjqyUy6G+Tbnmd1lV5TAOUel" ..
	"hf8NPJPXVEyekDA3epjEZ1e5IDt7Ea2GbjOZUI1OxkR3fgZULbolcrmhWxFSB5jfuDjOiXPi20UWML1vsG+mDjIX9zNX8/bwon4p" ..
	"wxO09yKlZm69G5sJYuEu7gsM9vluVgRbOzNm8Dv+hAo1I5U1mGZnt2xTScWemHL9MK7VMrFD6Pq2/h7E/C1JZVGScLLrRPXPMWk7" ..
	"6BeJ7fSqyxV0fFBXX3Lnq/f45gOlab9usmgublwKdbuWz5ZHhU56r5tJ4hkrG6F2x9KzXBY+K2cCa7AJUeyIEW2hfUDueoeo8CF0" ..
	"ebIjk1lCC4ntgoX2cbdVURGm+jP2PcKrQnDg/puwQZQeBFe8i9IyCW6RtOP74jDLwOCNojqqOMuFoKkIQwg6yGJqVE3P95RaZ0da" ..
	"ofTjXXqe8uO0oKl7nrvyew+3S6oSbYu5xBX6jAp2nwxu2jcYBOw7N7YGwdTtNt2FIkAyEPVPuiZX6whXvX/UCaOjP5+WGjLmurwq" ..
	"Ul7AbElStbIv03o2nN8cy1+DyiWDvnxx/+UcK94j2QK/jmmumJb+TvkBNQY6+ZM/XTFxgZxSTSqoNJpxcatDbOC2wLFIIhD+fc/g" ..
	"BSO/5S/VQcxF6j3dxePQM/8PPrJc1v9Sg8hA0surLSwKiF27PGI44Y9zj8FmA2AzKLJMOBpzA/6k0/j7aam4/QhEZw3PGw5oEuVG" ..
	"CwZvbkJRk4QLcdN/icFvHseCnwiEMUXTJK81fEH2w4FM3neLyMy+BBwGX3FkRz7ZApU66Mdfn2jVTBDCkLGIiZOvRvxAiaxooT68" ..
	"2QFg7IZJOLYBXEG/+VijQpxKgLjl57Z3IOFiuZ2POFcpgHIRSW/uwxwdE7kd09bDVNyyIzsXZdy+/UrRJqy2ELIk3h7l51P2Zquf" ..
	"eZCa6biGacuK2Fu52YKOcP2cRMDO11sm25MCl2hTYOlOIz7RaYsylJyZTs87Bh2BxEpwE7hRLXJZ0a9EnFcRbVVQ7A4NSqwlKR7F" ..
	"ElbJyRk3ReOhHN1AI1H3BNPyuvf7lZjrXpa4VDTGPNug6UthKc+/GfFxkD1FcGUwGi+sWKmS+2270zIdxJl3DcEEgARcVnr7LQJ4" ..
	"/IU226xcz8ennV/rPL/etGi47djqVS/EccHL8L0KgHLY9pdrQpyslGGlrmsOksZrn3d2qb8njDYmyrqZwTTZpBw93xLKhOS6a5MK" ..
	"KAl7BHZsQ4pZ9Qi/2GhOO/DoGzVZGHgwgHZndUAI6BBVTLd/iC1JiZXmu5piQdtTY+WNdnRLQBdiLjgD/ymgMGy3eovJIzgdNzzb" ..
	"MrqadUcv3wjx52HiGanulrhs0w04p8EMWcoHXxANdHQ9Ci9fy04Djh38ZREYIN2ILt2ltQlDModes6IhkwR+GCpU+yvOwBIUVQbb" ..
	"MivOUu1aBaQJ+wZhgxIvoAdqPyd1jm6uu9J7fxdzJbnMxauaz6AEN0A4+NjEEwB1kLESzNc6rk25eE/5S9fbUhwh13fGaiIXWmDd" ..
	"okHnwb3GmcuVjxFaj7LbCpk+9lqpG2DxzgX5P8szc2VHCKv4vjoIPcBiw4K7x28JNrJNM9dWqoTOGWodfj86KCrgv7Rtyh2zcCdx" ..
	"s2ddoiqv+KsQ8i0c1zxG64ARDUghTpMTqMTj+GKrHklVa1CTz3FEGJzEOmmP+WPXlJaUWjGT2v0P1ebb/AbQlKw9tdJz483SH0tP" ..
	"S/oQvW+q9Xkdhi2EiTkAJQCqEshzDNe42EtYDZTnLdkYdkY67rC/M39yktu7UiGjXajORuGBuN3gP8YYAcX/9no6Sx3GkyQMmJHy" ..
	"9by2ewC+bkztax4gSLNCLDfAUQJmH9QlkI9SUFMZkLBgVwTNXwJLRx5KN3EICUTLpotd+LEPTEMPemJr7DeG73gWGvfbKw1bXd67" ..
	"5l5KdXHKe1r/+PV0zDGEgDRB0T50hRTV+jVB1D8gGIRN4bjYCjoy21CWBVnTR97nwJhWjg/eYLUn9Or+rGKEnfS4FCP/aGFaLdnR" ..
	"QgGGvlYwQOxbW5vabH4vpp8c7jwVtB9Gj8JTaOPtSqDqOKWfAb8H0NML3WPyPgSriLEF1EPC9Usm4PMjffocqvRvHdve3byGsH8k" ..
	"tnRg9uzXz+xNQEsQV7uh45rPz+n4fAe6vamMKbzhwaM/DPhM2sZhSuUqDkS/ELJgtu96sDLYjtqSQigjedIg0hwcVCxyPFNND+ix" ..
	"mxr4EtamwL79LZXXgqciB8dAODlHDOm2wyWhmHEAa5lSWmIkaR8WweN/B0wjRmbmATKgZP3hiIRlkSaTeVj+FAJjwp+OiKsD3gSF" ..
	"pYKoiadM0v/BcwprjCKgji3hHI2G95E7qX2q+sRmNWikrfXQJLuv+MHUGM8Lq9vv2YJaBJ+R2yG+VK6O4euhjxmLPrVVhu+wVk3b" ..
	"JbX0q+rzKcGOmLtFhwdiYw/WXTR6/M20EBf3eqqQRHfltFjk5T9qrNqQvvE+bHVXBAjk9Xz8M/joc2gl1jVa3KNe3x2xa50XvOHQ" ..
	"F0PY/YOREepMTm4AaeMvF8arWW7cfwiVOUvufbKXKubjbu380tnxCJyCgX91b4cz1LC0G9cypj9MVMPXsKR7dZz6AyMSgEzRXAab" ..
	"VRiVQtYkPlAzuKuidxXUXI+CM6Xldqjan453AFXsW0SSqXoH32ztC4DUqnXQXg9D1dpp11hafO4hPC++UWnGTewsvj9tB3EUEQV1" ..
	"CcFOH1+zFxAmk/QTWxOo0Vn2V1hVj5ObRi/LzG0p3gQsZZMem8SQKXc90PhbBMO7xIpkRSbNYQUybEA8FCLjT3oAA5AdkcgtBe6X" ..
	"i5Z/p+eKvLskZKPeyQJGfBz6yVSTpXxiELf/vlYxU7gVFDIs6r6W4Tr7U0sSEH4fF2IGwSIHkvGJ5ifHzfHWzuriimRwWrctQsZu" ..
	"anP19zpPtpJ0KmBsuAvoS8DWy2PlOCTUP1GBdQymcIGCe+9lIB6Q7bU2sx9AmP/etb18BZB/Y3sMmeVwAg+wkQXQoEPk87o/ez/H" ..
	"AUmHOOwcGM2dBKSLBX1FSUdKn0jUgP7r1VoGCZ9vmipWZ4q1XX2lN7m5eQZcgmDAQwZjKFNnfw7Qt6edFo/uaoyLDNi/mhqeu7X6" ..
	"3zmALmhWwQRt9VjYwBRewEP5acu1PMASJ9Yp18EliB+sI0eX5q1nY5WGqLQRJx2ZV5qMMKmoP2E3AT39LaepiYb0g0cbnipZdhaH" ..
	"1RY7RoHq8pyDRS0y/lQvu933OhU85x4RzlCadEvUMsGhCkQWrfAq0FxyAfttXfZ2HVSchH3QuEzfOyUNvVYHyManYWBWCkjA2YBD" ..
	"Cb1/wSD5ALPNu18yQ76F2oDZL53wNzUasWooF4F+/ztmfLCgjrCXgjyQ3D+joiX80DcgmydmRakw6l7KWnchkIRk+Et3ddTvu+bu" ..
	"bgRYJca4Hasv12CJWmyfjXu1X7I/Do4z77izRzQV5yxBprNxTXcQbGAInzwfr72xUQT6EwINS62h6TKzuvJwoMoJbt4sK/W5Bt22" ..
	"0Y+l16P8gZIOoXVIOzUHYApOWM7lSWsMVc6/MsFhYBL2I+HexKNvP4fG3cYkcr8f53pQ/dKjogjGANWRnmWaCCU6d141XIraSXCv" ..
	"iCvl17HMHGkXUUP4tdbAvFm1t7Wg49IXhB3zaW/BhZumibYgC5cf5I8EHNnsMzi7KhVu3A7rLihCLXnbYLt/ixrlhvYGuygdafk6" ..
	"6xCsyv2CzOWfTpfo+sPLkdSF1WwN3zIoUqI6Fwgrm86bln++2A0TWr/bbJg7nPHcGgZC6do2HUnLhvmbHkFGUL25ZI1ZekbLkwGE" ..
	"1VorfZr+BQxNR2QqvJg+eLq0S+rOL6zqIiB6/jr9nznTe450EFLLgiLa5vbb90wvR541CAPjBx6aqwwBWbj9QFI+gdapz5Gj+S/g" ..
	"vij396Q+RhCejU5CIM1xVef8QERDw4TWiulw3skeJMF73rmz8BfsXpzTSgpUtkgLQoQrsoyFMlnt41/NVaFaGQdmTRl2WgCGphKX" ..
	"dfysDo6LoJdSV8KyXtx4IAiHZpuOa7ajeERiNeUe3DdBMeNuSh+KeBeSPvTdKkJ4/zbABiTiX+rX6KrIfOleABXhhw3x5HMJxaSp" ..
	"AKnm/rO2iBp/F3iX6D0R+ab9zGMidqTfpcA2HvJlVlM77WVo1qR2lYHIBxO6t7BsYGhby1tF0v4EZ5QQHyavpJk2bl/HOrMI63GU" ..
	"QadQQuELT9MniL6Xa3NUjicZap1GODB2m9nzY87gCjXp3UkBtvtehWgkKlYES3sdekBxsRx9D8+GZElHbL7SJViKYS8qLnk1FlZp" ..
	"WOiY0yEr1Wh5sNQ9hKDo1ATjRwVONJwBPrVZ5FBqWJirI6Txb9yGOLfMWENjX5lDXNas4yKMlMlGuIXGafqvl1o0+JEL8SvBttlP" ..
	"E6Z0Ksnrq9MrZexqJBUGE6jm2Ks+vsfKPVmpEdiXp+KLWCSl9bUKNiNPyLHmLQ0/mUH4D3Kpj74IHZ4ahgCeQrmg1W9c/l3kG64U" ..
	"vIt+15Ycy4XqzxBrOEeX/6m2D/k9YHLnlsLOVM88yeuQ9a302yofYpW678rRhAVZZja3xdtL9vQaTzgjym4Af6Qg74arg96rKjnL" ..
	"YoNoKSmcitmmFLlxEGs+oSgNDqmaSQ/Bn9XLQycu46pnPxz62ZnVJmfubdz3twalD9WN2izLxxrN8PbGuqVgV8y9wGws3R8v6wVy" ..
	"wyZA1qy26Fiy0pG2xa/GBKYgUWWLkq5KBxiPq1ezV0FG+35zgVsIfwtyDWBpVGFeOkiJav3hNbuzQoOjD1hvQOoyzoPvbkI8nMlh" ..
	"hP7M/FvLex/oSX8DffVvnN7Z3aqTFFLabC6zajsviDJgV+61GrpJf7gYwU8Ovowf4nN9xAyaceHOTQUeWLpfkmNwGI4XcjT2/HaX" ..
	"X2Etbd7ECbW79OSbMxs8Fsp4BCVZpHjnCITNBXFENe8oaUe0HDCIPxUAzYQlnMGmqq37ZBK9LpYVsrZIkYxdSdyBfcdPjkFfwOt1" ..
	"0oD6KRdLJJnR9t3CPZgrnNBvyT5XNblXXK+p0jDMK1goYJiSJdcS8Qd2EME4Gr1DgwWSPiALmJbQOmT+9FVa6WwIX0R2gi2kYP2m" ..
	"0aj34sw+FXHMrfMIdD3wdCc1GpbaxJ9MoAQrlVKXqNUvPAXmlB+iG7kwc3WLy8+b2Uvy9XqueQTRE72w0IcLFw8Ds0XlKshIidU6" ..
	"5cN/cvbIqbLpwtPqUDlXwc/nBlAXm+NrwHup+tL+5WmjNzmSj0HVlDJbFPf4eYQxRqBN+LFPETFTjE14EsCKTScQ3syBzTgGRCU7" ..
	"L86nwJsgobax29Q22+Sv65lNrwrq9fNUGgIRyQzmuHKu3WPTAd47WqEprxMOU1yvAuQl1bQHevm0N2BoGQdO2LDnm5J3tibygZEp" ..
	"VJa/80TTmi5wkmS/UnWbjk5L96J39ukvAK9+RBPTfXDWEInciScnu1c9ilJzdsTt6kPQ6hb8POxz+l2Rni96EEyy9zfyZJwCuvI2" ..
	""
local PAYLOAD_P9 =
	"QA31xr++de59PAVEZSjDhW0Un9vxkzujcBT2WUGeW/oVS7HG3FzwxnDa6E+Q8Y8nAuyCig6SwVkP/V090/GPb/MC4u4wGVRUT94K" ..
	"GFqHFXzXdbZTNHq+r6jQa5ZqKAnxh+gRIB1dZRtt0sWVxAF2xJCZ3BCf9bBIFdeIjMQK3duvECWE9JTH9wXi7vUTReVIBxBUYYnI" ..
	"2joJVRbht12aCyCqOsoFzBe1OE1LUA2RuyOnRtiz18FQmFG+vKCoYKs9OBWhY5JnbIFWEhhMR2WOTTFP50HeU2x81Yxhvl2cV9IG" ..
	"pjX6/pV7taI2I55sPZxW64Sb5+S3E6bf1UQFV0RQIFxy2w/1psLMsPupEvBCNUQQdLoCfZSob50lhPCevpJFk40lNWlnLttuSAmH" ..
	"r29rab8UW/ycO0pYCuAVWp86xsiC8BQRa16LG3MbNofFCpy+nev0qCB112P677DkSRG3dddOwcW/m4IUTAxUZTcIA7lzKk0S94u8" ..
	"17IIc86W9PQQ7i/yUKCRptmg4IHqmxMqbecslc9Gye9peh+VU1g2s5Qoq/vOEuQO2Ngr2nr6Iyz1Y8GONlM9FBXaGLIIyp5m1tPv" ..
	"qJvt1SgWqhXbJNrSngR6DZVvN7TFOMaL8CEkn01Nyac8ClHDC0n8IjpmAE28qfQMJaAEoFxTZgvR1RYT5fo4fzZth/gIKC4Hk8R0" ..
	"VETiqGodsQEZi4iMaOXH22h5Yp5+WcFDR3aAZWxkObilISFw0S29+Z38myathNfetu1Y5Ntix2MeskAlTT8hEWjWW7RE6r7vsHwN" ..
	"2lshf+dtKcHgECO1YkovXwi180dkVWM3xf9SDMgmcP3Oftm7E4t7TkWQARP7XfUf+THEOkRHLVXjxtAMp7LUm3geFfOdln6mq8nH" ..
	"JUuV2q2c/khcrLZsrEPExIgXdoFVehtPEW8i8er6GcC+Kvjq/5oFqAPFjCHtfcpUEmZ9PVk+3AMIANNRvnCFtKara1KLSUQqTj6k" ..
	"BN0W+2OgMNKrGLMMJKjzA00PSs4yEsDVHyjPGt/7vs29BgmYPzriNKQQw1duhzDRKf9BTzyx5z4qrtJfqBvm9n+W6WjpQ53jNtSN" ..
	"NB9XzosB7wQIXcvxHD6loaENBymavqpexT5nKTFxc0UEf0Bdd56JL1zDlg59Y6TK9DyJxr9priCsp6KnWiz0m8lsOAaXmZCU0mPJ" ..
	"fEcrSzAflkeOJcn/FvoV3r5XqORxRWQ21bGW0CgQ3Qf8KXUqnjdalFoH8SYZqFYeWYMGLJ4/m0ePPJjPWu3M7EPvfS3vcxrNUek5" ..
	"LHgNW2DE30ZaH3G3vS7cNca0h5HPsDfQwLjUFWo28xpqvAuIkzzlpgITB6uBurFWfij0dtrlPPkEQ/RHDhA8YQZeUyxgLxM+tJMR" ..
	"q3o8F41+Xpu1VMuSeigWxyEwC9FYWLb0HMA5tCyuxzlnN4rcns6WY/L6VfL33B3eSnFdxrW/JwgCqDbINLDscT8kJ3pfEPzlF9H0" ..
	"e/VA2hscZuNG7FklA8Q/zoJ2E6wx4EbctAGhcWgmjCGVslEps/ic74EKd2M1mNPfLBLlVow+hlVC4aaPnxb3WM6RsG2AeXc+Zm9M" ..
	"zmXkqmkYhAeDVryHUwu4RFdXzfUh4yBm82DkOxrhRzNWafcF/91Uy29metZJPvbA8j31h+Syf9qAXXIOKSx1Qhq9s4xE4uM7Bm6i" ..
	"eJSwYk+DmT2rtl8k5QtCsa5loMwPLOZ9wg/EE1rNjnjWHdrTUqeDHl6qw1JjxBeTCAV+Eai0Dw5atRQe8SCuoHZMuSAb4osCF2/R" ..
	"o4XKOS+lWDvPdwK4xGSXxxGpFcmNZTBf1U/76hbbds9SR15ALeVS1CiR3QeV3XOuQT10mCMb7oR5+b0QR5aXQomLoydCMMfooWXO" ..
	"ujGotWu3p0ShbuGJlYh1ee7Wdx9aIuCBjMZDjVq5MnPqhaoqFG8BY6YvPbO2V8WomxMvTbkdnRBibw9pkiilA2Tidf2TIbaFau/+" ..
	"de5W2oE/mLP2jJJifp4XuKmbmzmoxz9wMhPKAQN5U5G7Z89JjXqE2rQdrf+gDHmPNvyOvSsfTRS43whQzmaciSPvg0grBYdHHdPu" ..
	"HMR5ZPuXfiw34k5JK8ailX+/UQ+oKaCTda4wo9GcmnOkFS3jYq8v7yZtYPclUooTmxV61AUgl6BEmp4WthuartHb0X/8QOw0eL/Y" ..
	"5os6hzgWOL8XU/WZ3nvjeMUawWHj1uVviv4Jz1C5oQI06iKO9f4AlKVmRpId/pMKhK3vz+egXy4+Yusqnooh3zonxp5XoYaPhkRa" ..
	"kNkVC9qTYH3rCq6J8jiRuL2FHR4m/DyVPB8BsL93+wnnmLuD3/DCtgvs3/mTeL3UTq0Hh0+WinlmV55rMv7FX1LdC3e/Xvlv3rwe" ..
	"oRAPwD1RDMf+9RvE0e+GjyM2sEKJDP43IerVNQfTcINg+BIbGlnThDjN+SM2KK+/G/EtJTQQ8V3I2WIH7w3J1Lb4ZiYqNs+LDBbM" ..
	"fhwVqkaldiI20ZobAxnZA+jyKNhf5W3YVLPT33hx8xCRE8qAsiCa8lG3Jcr6ktEHUUpOWDAtejPCmwo3UrX9WmHDOjYLIElT5Bp6" ..
	"eF2kqWHFAUymAxK9MQQc1RmtvQz3LTRj6LVtlJJro8wcsej7yA==" ..
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
