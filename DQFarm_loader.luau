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
	{ seed = 1076389293, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1078986171, exp = 0, plan = 0, hwid = {} }
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
	"8Yb6IZWqKK9Jhisj8/L6ljo7js3syDwL5slG6/e4uCOvHwdA/CYYyYabd7dVuEy08Se3iAKoHNcn/ykguqQXv0xKPU+5fzgAjXg5" ..
	"o2ZZQEBFtx76AYTxPPFHO6qgwNdZrZp+R4I73f1z+k17PZkQnR44x2VCvdxLzkv+risdajIdECjsb3kBWxrKAdBT4EwhFoTOxjKm" ..
	"X0Y4BUgDeDRFOcG2VKVZJMUK+hLxaoSg5FRYRL4vxri9hEdixeCd4+xDWBMNaL0kQLZLy4lfHV60e/LpNqa2QIEDJTdN1FCrMINs" ..
	"OFefzYULQ8iFS1e35w197m8ntx8YG3xoIUQJOfAkR+7uYYAB2dCBL1zfvR/G3tPpOPLVkonsu4yIPsyK160oEWePUR6uTq+/aDg6" ..
	"dd9e4lFMd7FPnMfsuThHAka/7ObwUCG/sQKkh9Sj5jl2NSfG4n7qf3dM2w9mrMpl2HhM6w9juXqEkX9fvb1ihUP4OFbtGSmvoDy+" ..
	"sxaT0EFfvD393+/XWlFQrRv/EMTuZ28tXVt0s7Kjbf8TRcKin910+4ehpk27zJVNolsmiZavuT21RmsChS5aBiisWx842kcduIpw" ..
	"9wPQAWW8gFGh0HxiCiYAXmqEAjDgGIl/GK/OOPKz+A6jmZPdxDZtMq48KH1nm1Mp09b8hZ8wCv+m0EOTXlc0qYhYz+V9fhN+P5KD" ..
	"f+AdOGjqO9PCZrrzaRomAdh0OWwFFlNKOB4ik3G5VUBoVW9NeVlSlUPxRAw8Y8QWqeqDv6bKCq89XVQwzOmjwF5EZQLMbcyu2VuZ" ..
	"7PH2G+Y1171mvqrGQu093sI47AZuC0GGu9D9IQu1Yo6py9XlS4oP6TO+/5n1s6v9lVtuDaddD7PydqorFXK+dMN0agaVHhKs9rfI" ..
	"VQ6cBC993ekngsafvpy6B10WdiOUhSb7WcrLX7sCyfcIKlMCRpFHpbXzltunQ6URUxFV3G5IIp4xPQl186ssns70UcOh6DRx1y+A" ..
	"5uCHX9n4V7YGbHqXLNRe/Zjd6Gxb9Ucw/kag6JtTs0fNNa9f2G6cOF28tHdpeYqwEyoLHmbZKg/x2ORstbrh5VHsBPv3LnCc/6OD" ..
	"flqB5fsbAMFwLpA0mWSuJ1A0jVunV/loaPQr4MMbu1+kG7i/A2Qhru4gmq7/UT/FhHOA+j3gcnt+hrY1mzjtQIzs+i4xZszxL1wB" ..
	"U7Zi/F5Rpvrt0egk73cB2xVOs1BfFxMqO/2EunFFZxwhIyOF3wnXhi0p1vOc1IAByoSXJ0GOSomnL7wT9BQ9ZYUjCUE1reiTtntw" ..
	"iCDS7CnLTNyOTJpppHSazM32KX3jE85fQZ3A3drN2m+3xP3QsxkIuPQ/1t88k3BNguLVwPn+zUkj9R9LB4ltS3Kg5rvhZE74m0gT" ..
	"uo2Di2KXYOJLHWKLDFXDxuunULtbVNtZb3IDoqPjF/og9UMTrKRVi/BnlRx97wzAAVdhPSOmMHNiRj4UnYcq8DHTOe/KM6QubID/" ..
	"druAqT85Q5NEkrndKQIXC7IDwwF1s2LlLxmmu3lZTCN9i3AjtLjCrA+uGzaChtL3KE4NEviXZeauErhQDsebaL5QmtIlOww33hLZ" ..
	"O2mDlrLWvuAvxHylpatFfdBcwkH5QsTauTBIjrMRAduybSTjjJVosLsqxt5UjZl5sni7QO0i0H5QXAA4FqL7PtRrssywDVo5v+y0" ..
	"Xoa0iycd7I2Kb3AtQaIZ8gDSln1sSsppO3Mrt3lPS5RT/WAjuISMYFOsJVVznnq4+8RBOdkzlpQnAN6LkU++ZemC1Ppxj1YRFcIt" ..
	"fO9av2TXmplEE1Np2GGIRQA7Wrr/xPZCWfN7v38lX1GSTDPRYSskkxHIp6FnVHvFkFBjnRcT40YhfqmxHGhGLk4bIZzheMfbpHoT" ..
	"a3jYxvkHH6X98mEJUPILZ/Lj4VxrXLzFAZNCxMTjTvLSAEpCALaF1RxdESuXO9FN1kAy7zPWk2iewPQuHdFDs43mSEjeijbyu9Fj" ..
	"iKn0jmeP1FnUcNZ/vPY7MNseEqFCXOTDSyZ49iew7LSErnJmi1VQMZdAhAzsIMi5eztdQTadqwNMxYrK2gd9vDiBs4WDRggf23vk" ..
	"fgcRfGqqxFQYMEg/czzB0qSsnZwHqegtMKptgNPYk8yqdbE9jsPsec06XMrcXwO/b4tiArIBjPYaDIY3BRO/icfOkpLrOx9d+GdU" ..
	"n0FEzvX5HABD3kmoQca1quTzkFHoIJdtKmrfafcmdMSegsoTSje4r5qjno7T4ppe9xaTC+fQb84W/RjW1RPt5qSEvioTs662SF+Z" ..
	"vwJbOv2OFPmt1lJIXw4I78vBhkAVdkG3AoOl+b9yaHe0BwBwX3GtI6GWIrYai9xSF6hCWWB2AlEx/+Eu7h51LqMdx2VYAcd2Q5N2" ..
	"P0NsGlZ21W1sMmEXgx5/i8asab2cPGXS3JFeIeGCBGGnGtnrNNHvZIS4NSXFduc+s7HovBNJE1ty4hE6UB694p31ksDDW/UOPb7V" ..
	"hlgwOFoLzTorVGuv+yCrbHdOYa5wafbKx4JJ9DcfwcxTEWRikJBQScpAVSV2vreqfGkJwWRri+yf5SnoBkCIRvDOdfTJxcHRcaTE" ..
	"yyWS6NDXV9my1nus0tdwsbCysCO6NvAS2QqM8Smy9kJDIt9et3ApwmoFjXIz5od3y0fywIOUKQfls9JhvFT2Dve7wiJOaItPZNjH" ..
	"MjHoRV2lZqA52I2LbNx+dcWInX0fNr7bX2bMpcR5RmTXil7UiOeW139wMfuSJoopNlOEI+ifchOMFhWbGXwkO3HRllkj5QlhbMYR" ..
	"De75dmfYLM2YSLV+x5OQsldbgNe9WbGgdegmbRFAy52SUwHQ+9T+R7My2IPIC37TvLQlBuhCdo2mNz7pN6kgS5twyIpkkxF7gVPG" ..
	"x55hRLxtxLKZ/1E0tKMify0GaoeSMgcAutsUE8qYkWy2KZTApoz/GytrPN3Cz+VhcOD5xXPtPPTriSzGi6QO6XS4U3CV3fWWLQ6O" ..
	"pGz/XMIW2urKYwzxzqXXoHz1DPIDXIYk9mEelZN/AcZ9CNhajlQpl41sP28AoGhPA7Ww/M0WCwR72j1yQqc10U/ZRYYZOf8DHlFP" ..
	"NRz0zhnN6d3lnlqmWulctXJF/KZ2VVbfFO5LG4Wd+c/ufLwlqYIJPovze+HKwFkHCmVc0IJRzC2PkQUx9JSjekL8RJon/z7QqqE+" ..
	"bi9Ry69pEqK92KArI8xe8kIlxpI00JhYc2YDvi8SlByV7Hn7+h3kp4m6MX8iufLMnWtLA4zv80Q8XpYaSs4HiKLL6JASBY1vsQLN" ..
	"+jR3Y5xKDgBuzf3DABzVPa4rof+Kkxt8bV8EcxieYE+oE7s8wSxDBFWXI3DjUOrGNhJgpli8SvEVxptHHnuFJW6pI6TDgaPwvmTO" ..
	"pNFAYuxEI7JOUZNtvoO8wzKzePNMmFOh1otmTsU9u8NeHrA1uRgQaKpJBJycBcYtS0yeMHERR1dui8QaEgdVYC7Tsw3Ra5QrXzej" ..
	"7wMO/KMpPGvhptqE9kTqOZiqdKL6OtyjI7+NpapoTFC4F4vTcUbOk/Q4Yumhi+n6UT4w6+7x9tap4zwpIEWPK+q0VCKrG65MST6F" ..
	"XWPz7RpW4HHP6PW/GlJLNMu0dxuXnfKOlGnQSxj5VFoVCn0RH1tm2ygXcmF+vQOjPLUysImm0KWOyECwk6UyYYKvR5Lmp49B2QUb" ..
	"v9W2npyT+aw1rQ7ZxuajZ8fYJdCAmp3HYWAReG/oAfE3icQLSx3KBeIqkqDrkIBjS8MMZgOAIjto8vGHDU+YIpS7p3F0CNNhHS2K" ..
	"YbE5JWfuqWdIuvfMH4Yd6+0gXWXF3UdSUxUayigzlfC1ETLuqc/uWfEQ++TR+yt6H1dTbsU8Fqgff2qOcGJwscMNbGokY7Z8mRve" ..
	"BXZ6F5ygE6I86wD14lmY5S70ad2O/izGS/qJV4pUPWy/rVBk/mLMu3GVo5qBUF+ulRfZ4psjUpiCzC+RyU73eohG9EL2LUoFRGRS" ..
	"Da8j8TvKbr3nGfddvJphpZ1yQkMu3zGLyiX/NZYYkglfRUvt2iJBpVB4pLte4N0FBnxopOwEj71Y0eo85KqQfNvBq1TzPgp1x7Bb" ..
	"HJg/dmBZn9e1QWj6UBo2uDTGB3Y4oWmwrBXbPbOTNXcvZ7EQ1llY5x0u3b7KaFwOHP2hADpvmMeK3+PJr/DHDUcs9y21IlqaMg+X" ..
	"+F2qPZuGnKvWWvdbG31TCB1vVJqXpeox9UEgPGODwO/bLwt2OOEJYqHTGvuDr16HGIvC7NB4bvcam5JcgkeINeZjEyOVgiNMRNNN" ..
	"U/m4OXM+KRjqIv4sjn7M403iwuX0RCPFXgm47Lq3MFxgajXUed8OyQnn5KbJ+0jcWaCXLOvDf4splr8B3KQgxQdO62oUPOpkKdzK" ..
	"biVrbRikQEFiYVco48cneZExkuY9HnaVuq91NcjbGztUj4ANFNF71l7lIuNX3oIi4KuF3uIOue4lXxflBX1uKHO6U1j2uOWA+h2W" ..
	"vrvtF1Oe4tyvsz6x7YEWKJVCdGMeiTRU+GLUQFmlUMhBUZEm/Bi2Gr5jDGOHoaHFEY/lI48r5n9pUwGMjrsss1o3ppti4YpM/KxB" ..
	"utBU+Xb7MsaPa+Dp6GIBW+ZbDw2aU9ZRz8w8xFKkEBtPGZm1UCTCUNuvJzuZ1RFH/vgjWsa3oa2f7c69QS4sn+BbZpgTY5ogtOap" ..
	"ZQ2D2ALc2/OLUqn3Yswa+WaBULEFE2I7vY26Yr04bk51J+nGlDuRW8RQr7ihNbevXFxH6/zjuoXu8ZDdM1VcPmd3HsFP4RJXsO/s" ..
	"RWOEYSYHETcMfg3buSRg4Wnir7rWmjKcaU9qLwMKAeYovplNdFTpmHnbIGrJUf58wckfsfAH5DKk7eWOU7OldS0kSAEatIyqvze8" ..
	"GsMg6pDDOqc29y/MUQVxyx7Qll1VvrYTKMaHgPlYgTfcOVtYjqSi3lmYb5NysXjrmBrlRML/mpJlPg8BZq+vmrK9SQEAlbjQ0Ugp" ..
	"V+F2fQE15TzSDZbskZERs3IBGc+n14F1C4FJbJDXPUOr3gxWTdx6k7DW5z7VGJ2wPF8j5Re0p4iOGQtAkURXFW2fqxRvJ62tlPRn" ..
	"hab19MDBvyn736M0QjSYprZCiY7+du8A3RZEY9zWHp0LI1F9eEsdfK8o/WGrN4fG4P4zkqN0hF7vmVmlY0+qtZEFBYSucGOgem9j" ..
	"F6QqzGe3iCRbr6FnMBz6RrbrnGO29hQ/o72+6zlokGe3AlX/0Qrga+5rSx0C1n5e/keXMbOXXu1h9ax3XDHDptUGzutufCiRdnN+" ..
	"dSjtV5gYeRyMjVBMWs357SG6V8g4BzqQ8TPksE/jlsvGetp4yvrIQrIAO2If8DPjvOIAdXv8Bg5BPpWRKJwfabCHyzXJMbPoiDj1" ..
	"XQuCXPAAMGtEQ98VzueS4CVqrH9DTdsHrM9T6bs/7Rrvy/yJ2TWXTzpYEj+mdUmrqJCXujhVjo/JkzRUzPXDCs9zKkq0eYW5L4N6" ..
	"yUxZaH/5XkvYFOxbR75CwNVVplV0OWhMYqrVN8+C95ZsCl7+Jxl82Rh/usC5yWFC5xA1k6SmqBfBisRgGqFqjh07JiCCjXQMIvW7" ..
	"EvBEyDVJXdHFMJAEy1j/qAypfv2LFbMb9YS5RSNjDBCDK+SsRMUnCyE7/7vWYKa6YleBznWIh0tHK6mV3vpRWlJiz8qYQ4TrR2H4" ..
	"A36P8QJ13gcwBobYonT7LtYF5RLpPmH3/dIdtEq99Zh6fPN08nzKWfAqL3sXLVbFMczvkcDA7jPTTyvUsdASS68pqWwGPAjFZ2+e" ..
	"yKYM/l9lgNIISxyGivcUPnMyIHmsOw+dQLXZwsAW/4f7y4hhh6e8FcinqRqTcubQ3WlQHoj2kEdf0aenycP2KJ+5J5O8SFH4ct3Y" ..
	"7QJPqRnkPDfEAhiQnx7JAMGGj+O9SCCGaF5u/z3tDc9tY4EK3gF7JVsc9OWmFFbcLbqDia6eW+vRpryF+DMgnhxtxL1JmZ0WSqrj" ..
	""
local PAYLOAD_P2 =
	"+VKoWJ3qYAka910zYEA9XAtlyr+ZXFkVy3WV6EHdSJ3NqaByA4sYPVym6t2uFCvLeNarbtJbb2vmpEuC08BbBpfKq2uRejuOkqN4" ..
	"StbFC0Jn4n0vSwcyO/TOKkTBu8Nqwuc5sOXQguVYKz+WNsH7EdwtURhUrWJw5CaVv4u5hwF6c/dcUxMIyBaPmWGzNGyRB17NOeUa" ..
	"tih+6sZb9xu8i03sHk++O0eYAbAAL8WdUAL36b9Gf1rJSjsz4nEiorG4p8KQvuV4SgWmRuXhFHt4KqXFcOSgznEa+0vas3gipGbf" ..
	"YTd3n/oBN/tF86hOetDgytu5EkOZyea30YGN5Ng1pHEg+FCifWdA1JS2iwVs8DAPwE4tgGFCa4+iSE9pJ9GR1pb9c1uCoKv3Oowy" ..
	"R1w1qcLgcBFUPuECg/Hdtw2KSkV+5nB+v1k4qYbKUgdngjS1//mPkeWrxLPDMYCySvU95OSUKG4Jd4pzmUQaBz7lf0t9Ex0ywi/I" ..
	"3niBQfnrWckxtrFgxmRS8ZsPHUesF9EyKrF2Zq8jg31bNQ1aXU5P4qkHuzNjnn8re2eWSNcogyNf1xgmg8pYIk9hOz3zhjNNWxxs" ..
	"VJiGL7nmE097Q+zBzdA1SoVK3SYvj3l+kgIPKtaobjkToQrB03e9mTsX0ujM9GiFRTZNl2IytE4qWxQ18hjjsLBpWgdTli63mWMi" ..
	"9QmPFEHZi5+St5nyXWWNTHggbaC+B/J6lB5NjBNwH7Au9R92BbAmIAj87aXRvk8ZPWN23aGrMPSzkhsoVGQmAgDbkTT7EpeNRmCp" ..
	"ARgcjD27z2IXs+ZyU4ZPyalqu7hyeF9ep6cVUcu4n8xsKCpOeSYSkNKZzpwyi4kZDtvU4l6FtdS0cKZhS7NrxQ5npPxC/lteoDaa" ..
	"rqn9RsXH8jJ4JQIe4svQ//4Z388Ifuh7t/NSsS24nsloQX5E0BgfJZ4WZFogNeq9czQoLgE4fho5CtFGEtrRr26qs1uLYln0VkTX" ..
	"b9D9P9nsF/wgLUGEKF47q0Qe7CtloXhhY9hNUlpB3hgt/za9qEN/bmLGy6MaS+asQpYjPHULrBYYyGBn3iSINyvwixhBF0X3Ilrr" ..
	"wIF3qhGxaaj3YS1uzotK4MG1l5TDdGTjRXR0orGMznr1HH1v3WDEtXbeN+MOvAQYX0O+iapgzXw6/K2bm47l1ULYE/Es8QVRSbiU" ..
	"GKIDZ1roVVZZIxRjCAOitL86m0TW9kTaAdfloEUoGJySO2r+geXVmISyc+KWjh2n6/lywwvx+NiiWW760DSg5jX+f8yEmmrDvVd8" ..
	"6DNrffX9zcQ87JlZLiOQ0PeUm6WUJK7u4RH2P1n40Z2QGG91QroPakW/SaKHYMpnJcPFCn69kb4PiitzOy6i3GxrQiotC6VdKHL1" ..
	"4yXf6F06aBkzy8X2HvQanWj1TC5HOkIUfMY609Vv2TGvuXuQOJVNkZcX9QhSEn2bqR1BBF1xnks6KTzVh9sgymtJpCidmr3z+SxP" ..
	"+ZCL3BjLKRAyuWCaLRClowLWY02dYpMlMtvlyRZzjbisMObeLhdmwT1E23Ciuhf4jK93QP1nHJ6FZ0o3LXESpYBngIvRrFAns86p" ..
	"fUI9VfFTdwVMGFl84vHucRU3XOw05iWy8Qjdql6ZsqyucYKcsNmtSa2P/bfIOjocUSJNP/5hj5rIy+l8oE4vbZD0jCi7XoIldz08" ..
	"b3ACGHPgUMdeQkG0hFJPrrEn96Kl0SHDNEpqcXnSYK0e8qMNc9MdAK2redRcHQTeSfXOV97Z5h0E1VESsgFRyPhF8tKcBODgNnPa" ..
	"3xnsfWN96YWdRhewJxxUoHpLaV8HpCZNzx5c5z693aofNhTxKatf/8UzaQd0tCFq0NlnrBnx61VYWsBPgKpDZrlrYtNTdaUs7hq/" ..
	"jZoH8iM8dD7p5qPq4mhH4ppMHefrulPEo96uuDhMbLznRLK/Rbe7IuQ8hBoG1kVVdQUfBc9lb0pMRoXtWEGnoKtukEABgUv+vKAx" ..
	"0tIsC8kYnyF2sa9gP8RbmUnNRrPSaQptZBnVKKdrdmuY0f6adsFF+9xyh/7tRWClOUWE7fBsdEijdttuEI3UxbTz6dZcJKzt43Ml" ..
	"53RA3FTeIe9gA7hhi39UPPIul0yv94ZvaOi8EiPnLndprCYG7MSdWhb2LXElBup4W3KAxVRyEXKRdoxGPQWhNc7Rwd9LxMUgbvmj" ..
	"9b3ymAbmdKblE6KvYP88JT5kCFYdjC1jjpEJUEjXLT3ycLzHghcGbQR0koMKqzEfJjVxQo7BNDpPNcHOT5I/KgRBlbWHlo/HLPHF" ..
	"7rOi1QfRB+xpQXhfV9DEi3ZXxK+r8jwwFR5b3Cg8tOBJwfWzRtgCLldrcNNCPkSh4aTjm5G0SvTJ4pZluWo2lqGeV5fmJLxqHXqU" ..
	"sOBbj5HEVDkeHxVmHnHnoyjQTTCgNoLpsyuF63v76/3rFe0PArq5qiAdz8mUWeeBSbo8OtWGeSuk1xvji82pkuvqk6pwbGEqHHsd" ..
	"gkLCmZpAvaIMdWbW1/YWXaO076LQkXyAd5GLZ7K4EW69IVjayDaZ60Ce+zsDAjC8Wr09O5+Z9W4jqeIYIsFoWupDYj6UMVa1u3/G" ..
	"KR4Ptp2vNcxV9PXtVwqDooVEudGYYyiaGC7eIITdHPAylf/GpsVFd9TADSmujbMn053GoR5XXjFYBZa38vTOwdRWvelfGJraj82l" ..
	"/QpykvvL338tST3SwQS4TE0NVKf+H/HlyzqXJRsSAOKm46oB8MVgqnfH+7GDQo2haPV7c0B3OPzUo6H75uTWSKdlaNuFy/IaPtPH" ..
	"bD43Qb/1GqOHBZSGhdZRkhjnPz4E9YK9smZXD30XjaXdggBD5ObjsEBWBu0wSRnyUuHLw/DgNedWgtD3Q8ubTT/pe+RO0n/bJ9vI" ..
	"oZdgzRmk1B7gnfrHj5MfOfl+/yJzA1NLmwVcNWk/wDl6JY/XT9/80bV7PAn2rTRO/Rhx+DW2tjRn9hyCSwwm6vumfGfIecW6b5yj" ..
	"73Kwwhkub30Sr6eliNPDhy7IR9pyByfiPCNYOEHy2XFYrOHAznbcPrp5xv/32QqiFsnKZZkaP5S3NRxSLyOA1M3SZKZNXnVHgL8h" ..
	"R03nFStl6blsFzO2Qr7g3pFb7gKdY+mpXYc+AnSfH8XbCycnh0/2xs4mX3Q0FC1X75Hk6sZ10eRURXhuA6hMv0EwosbyPoSjjpl0" ..
	"QYUTHnhX0bJQZFV0YmqCSooQDcpXBU+ysr6RXs9MQMywa/44BznwKs8mVoHtlxqqUS/aKzIHSEC/3uP9obJRPWtSn/s2TfwHPqjq" ..
	"hNs/LN2zQ/YxK6FcAWiXBFkWRC0u+oAar1d3pMad2obZiFDDl2OCD8aZnaXzmOMlR4icgcShSDauwXR9DxbWO4wQBhFlGE8SKH62" ..
	"C+My/k1Ta/NjpOC033Ja24Bqj/PVptRpEaHbEgx8T7FFaHKkCHB7MvEb5dDd9uzohN1yk1dN8VgLAQs+uuZu8j/ES0kJFWU0WegH" ..
	"iF0g1ddlf5G5dfDvs9rUEmcu5cU0PFWfK86Uz1nP4eF7MT4Yjwf276M1sG+1vXmJAp/SLI3/nSYs14BZRQxKMVHe2ALvdPpZ8pcg" ..
	"A/4ExLCc13YkXupUJUOZctikecBoMGq1CvcMD5s8pO0JfQuah8P+yKKn2J5kXp+Oy7euPx8irJtnqRtGAEql7XVUOgBQbEouRfOR" ..
	"05Tr5nbvt7K1vNXHo2eOvicWQosCjJZHfVB1dAZDuPOn/WKXUt58iNyvKyx7FtFaB0Px19YVMmNJUe65Uo4qlSyJpUF2paD00cwT" ..
	"MkDncZA08FeK6ujhlq66xtKvStKL95kM2pQvk/ocNLAO/t/8Geh1FrnMSGqaVJhUKriwm0jGTmN+De31yKYS1QpaxR7aWn4sohS0" ..
	"74LSyRvQqbW9HpFApXMdN4dbxJt9p6xtuKBzLW1R2nLyeBw5haPXAuCnMcWJIKfbOHxASSERQoFq+LOnYNos+5Ca3+qZBL6ZiEUw" ..
	"QLqoA8lpSPPj5jdaPJKB91b/aq0QVSNl+0fU8wpOJce6OUjlZBtoq5LSHUMQzFs7M7fYxfXIeYN/EzCRa4XE7dDVWOfR3n5us3Ak" ..
	"wnhpdSVtrtiPmSxBjSCWFZNGAYupPRJmJzVmouNrDACBizTyqxH2aSTcggzKwjVuMQEi1BJlRY8F8Y77po8ZXBVI8GhyRGCcCl8H" ..
	"ANe6Gk02SOOCmS86w3NSmOrAHJtSkcasSGQkYqTGjOXHvGwogs4KXsaEq6Q2vjaYbqrVXGJ3xXBOsCtmgOQgZ/zLGyYPL18iW9MP" ..
	"BWCHAE2nBZywQ47NmYc09jKj/2ER8kzsY8qgcc7u5et2nBf7KrByObvyVFAQ335/GQ8z4Wn+ztI8ZrKq8wDP3MdQl57J2jhRBFP3" ..
	"kj2bYm7wHNSDkbdDRFnX3/K557I3s5g+JyuEDNN7gHeSgrNZYspdRhFLmF5FPL1ybdicB+/Ndu+rrTN9Mv6mf9RdomsMiq6X+sa6" ..
	"i23JvUIi4afB7DDoZbe+YHC7YUuY8dC/CN53Rn94dhKIfy/c01mT0VVEhfEq8MBfVTqYQCYEzcvhObd8ZtM1hCJ89PD8MDql8rs1" ..
	"Znt/bqunB8ZI688uGIM8yE/w35rY2x+YJhyW6ygvE2aDx64WsORfy3UTzxxolHhdbo8TjB7vE1GlfOHP4uMK4jJ+W6C3wMZIbVsu" ..
	"RmnRIpw8kN5KDZQa3dl6bH7bRcmfwoy8dGL70BeLP0ieO5ckn4OaVRIqEPIAMNz8JAyI80Iacj0Awvl+iEBQHCGMkaMMb3S7WQG4" ..
	"LchXojUG2ARhWPu3ECo9TFSMV8E3hpdnuMUuaTVCftTpKVyd4Rv7mzKfll2TeL1B9tlJ6XSZyGyqxFui9rj7mbkTsonr/3A+lawd" ..
	"PeDmKieWY90L/A7Tlsh+WyB/QElBk3opSmYEqD+EA1dujNLue0jLe3ODBGTMWXfjx61A/PXMrxopBQ50cseNU8Gnpf7HgvnAjFwb" ..
	"vCB2UNBP68w8JtoeTR/iYOvui26ZuranomxxHVdn5ErHOUiBw6ZWgY2FbOiOI7Y6Rw2sDoFd2b4MmpE32+Dk2oBf0ujzfan2OJad" ..
	"lsAi/Fb3CisFRe9VL+UhzwpByYa0jwUrt09Z+Nu//gkqnIf6OD+kk0pgEn5MpWNITuavnOYGJJYRjdEZCeJS/9Iul1Pu0MDiI6N8" ..
	"Xm7BX03FuU2P+VwJ5ojeTZMBAIsA/k/Hfq3NnVYcuTrPltW/EegvPkHC3BLtSJ76jDTpJQx19FNQF9E0K7UbMulMTjN9vS8UNik1" ..
	"Ja2uQhcK7ePAdm/P/EclUKRJ/QiQ/IjrYSyCk1SocCjlS64QzlH0mHkQpAP9NvH7QeS6WMdiy6deiV8kVKXlhaqQp74KqURd3+Tn" ..
	"6Hfi4d+qsT4nHCl3Lr1J8Wk8W6eBk8vJymc8ItOqXR9SslTOerMB2UnefPz/qG8VSOyw/EcydkWSetUfcbXkpksPxwB+ryYfZfRn" ..
	"5hjFpkmdDzlWy2Kbnq911zCJF3Y1rIYKiQGRr1XsAfK7UDvQlX+COtOd7QO8tiDKnkEeojKILkFsmriU9F1CS9ZR193dn66XNjTC" ..
	"auRBXW5hu9cDWLj1/27vNRnsiPul45mcz54KiaBy2xzrausARgBZ199Q4eoCqALgQDjRR3NeSqk6l89GSLmY9qRtNB65bAFL8DbK" ..
	"ww0YB856jdGJl2/tEMaJ8elYoXABJEV0nYWSTonWNgBdDKzZ3byR61D2+6mHhuMwHwOtxgo99NFsTocd27MT2rKjrUKZpT2IKwLI" ..
	"CMwwSv9Z3FSogNGHUHjQYNx1DgTrLHNfunrMTZEHRKoFCwHRye8xWH1p079MJqKEtudC9w/nVofECNiEXWCwVLqPQZdOlzqm5nwb" ..
	"glePo5GcDLqPqXZ2il6fP21FSuMcSad/HZuzUEQbcRxd9lUNDya8TOdbMRGDjULUw1E77sVQb7pzWZnA/1KBlBqCrqOyb6mRtHxq" ..
	""
local PAYLOAD_P3 =
	"4wIk5yubvnAOn4kKIrRXnaMiY6lEpO2syLqqBx6tKXJVLK1SZoP8utg3Mf7gM8O17ptwvrAYpqv3uExZyD4YjSFFpQCsgMI0khxQ" ..
	"MwOEYGbhxS4HyvMSLJWHLdByyQ2gStAIVuIvIGmFxQCg2QoYt4LCAQ02upaTicfzlVF3/hNE6KbKWnUsmtnrtNlU/h+L9IGQ5x1T" ..
	"Qp8M3vHcz04BJt6E6pBPhPrM2Ip8S96PR7hgZTuuSAuWgzJyJivGRsMGu/Sd3ANZfw80keCANRRYFt8ZqDCcU6uf4rFmRfsunv06" ..
	"YHGaUVRl7wxY5wC0GJfZLJp339IjrLmhMldF/sM2mtYm3P3wS4NCQKRNI10Ov/PyDLvuN1Pq+aaq8uizuMfjyZKNTK7RjoM1KcW1" ..
	"CaNhJoYx4IYYFHjDYaI4RYKdvllGS/JW3snog1XV7f6w71dqHs67V25PoCdQ4k/E+znFWw5bVYU6CXYdrsXA1jG+GRlCdKqUqkAh" ..
	"Bp3HiS997mPgNkkBtwltGy8Sh0RdQNhMl5rV6EzXW0Me4L2+ME42+AiGY4ZbcESflItlKBFYEoGjecX6vUIgXP5R4tMVc51e+I8W" ..
	"q+0IyciJ6fURWJ58nf/V6TXfrNHzageTKqIhFxARhIgB/Hhp1D0OnAFG2O6Xq8kgwBNpvQF4gCm4K226ule+rENDTpJarP+hcSUd" ..
	"ZS22M6YHKwC+ZrO1FKLGpKxL57I4ZarAK3sKzCieSA5Aer7QwuHOCya1nEensdL6YRNSm4jHU++Mo2kO+tRpVcYKMBQS58b8vL/X" ..
	"lEQABPippues0h390f1qK7Mz4hNLJny5ECaL17F3YONQ0tpn19fC8BGcI+DQe0ti2kGsJ/rIsbFNLdrksSFQeXC8eet8SNDFG7Lv" ..
	"DeZLzGYSko2lVlwfMjZMX9b36c1OK+t3wKR7tNHVF1QZOY33oEE7kom9klTUny7KORlYhhzUg6Fd3kL0zSpJ/EsfMgdNDQ6+AqNX" ..
	"j2IM72GyLXh5ZgIWz8mR3H8DuzWvFnLDyqlUWtLFrMHYpkp9oideDZb/e5juPAui2mb+qEAlMf0d0xdmQSXl3b2BkGa6RkxTpPnE" ..
	"zl8flmHC4RFo8qR3Hrjd/R0RYQ9abIrnyqpPoLev/CynhwShSCcrf8ZEo4j4g9GX/+ybZv/GlPGutDR+fKm80f93KLAT1+BIwgDA" ..
	"L6vU75e891hMNFqAP3mH+UnKDm7a8xgSFnDGzUmJr6I+O9UZP58rqL6jMNhUaqPYO8O0GWYxarpZBWkBfyLdTKTnolZfIWurCfLc" ..
	"bElWjJnnWiT+7l6oQJdNGB3o388wCVrmBzC0ivI9I95gJ+6O2Mr3YhodaoB3cZyPuqEFYKEhiAkYAajNdr0rUJJqGh4aUMk9CyLA" ..
	"TQDSGKJvP/nnZKoQV8YdfQWUWSqLHtQKkQI1HB+QRagkVNoOgusjNUM5b3YKHTkCs4CXz0+6KDq3AQc5R0b8Bg0s6mL0+jWJybZz" ..
	"DbmPofeEIIlcyVmLPXlSfo0A+DDSqQ/L/ywFPIjy3XAkHhn01fo6irzttIJyUaVK9SkThvNFc9s9u42fKK7cCGehOrlO1O/B3OVt" ..
	"QOmFJo461Y2Pb4dOeR1TZfvWf0cQeKFgyTmjPdNc3VZWhz/k6Y9ru5eWOKMxu74E0O0jRTdF4ciHcBIMGT+eiC2d+EDKT4egHD2W" ..
	"Jo1vMVObSsmige2ZfrzjgL+bVIfSr8UKXjpERZTIW9bfqj/w4QXaYUosTIaa53vjDyan8ChJ/r+bR1+bQvBcL8tejYttKykhXNPP" ..
	"xndsYEUtUKwMNXsu86eWUJ4Rs35rdE9S/6rzWMxe+i/0/dCMMD5f4UKhpLxxdXxCJhtWh6/f+Fvd7c/FUCChf8aTCn4PRqk+mxQC" ..
	"IVTLbKSnkTW2lQHth6V9avYvQQACtw7lObQy1AODzr3XAFMY6h2y+u8t78sn4bU6+fuzf+nvR1x/gVSXsnFVl8nOvWuJEnMwUZNy" ..
	"lIRpo6EC78OwlAjGcAlGSspKdntpcBVAei/7E0A4SV6xu5V0iRdBsG0+/9r94JAxP2McHsyVMyJT3BlNqJYecugdV9uCTyHpS1XS" ..
	"O6Meg//b4GXwGpunrmIrfvEo4MTy+XlBfFlr7JEvmYvqjhT4oVHyWKhA4V51y3Y9KrOIQhk9mzwpu9C7DuxXWxsDz7d7JPoSbEok" ..
	"dh0f1HrSmCvSXKx30tDQ8E1R9V4UMXl0TSbS+ZNhptW7H5aKaoEGnWv9Nyqmoyu7ve7JJ/NOzFxMPlGMgY1pIGvIJPOVAtxY/whW" ..
	"giJ6vuCnUzXXyMMPeBhnc13u9A9rYxOoZHWMnhYW3hvdqjSTP+yJeKIShkZ0J0J+DdzlX9Zl6C9NfHbQ6RvyoILrB/++jefCsiG1" ..
	"NwLwOvf659/Deng00iuLsaToQvw2XKjMU/XrAKre4Lnhw4Iw7eAIZ9orixeCRHivl3hdPIsfw9v33jdXNMhyCHSLGFUArJr6fVzx" ..
	"f1QUSqyNE2CFuoD2YrxO0YBe/za8f5gYlE7OBvsZxhezpIOgPgUIfmaGmXjE4H37Tmf/0vNjSSa1BKMtwRdfdF0xyxjdCLlGMXJ0" ..
	"y/kd6nk6G3OzD1OQ301bRooESp1wqC31iCTucF5o+/uPcBDBTev1c5sw3ORXMwTtktDvUKs75u+gUxbPbuSwkhlVkrj+fjbXmCMB" ..
	"56SXOZPaeq0ElAqL422hu0jFdtzgTGPAvsnccC2r7WA2whB505PLZWz55bKwrY18/Qu5LhSUgQ2QEigLcp07mrMreGDCp2bV5hjB" ..
	"N2Ahev7hHi9XVNSvr/NH1nIAoCQTgiKGXizT+HL+ggOKF8hGC197cS6GZ6skjgcYFW7flmU6GpdX1tzBoaIvzhUAEL/l8E6qL51r" ..
	"cKerr4qvJz8CP55OvTsYsHlxO1mWG1n5gCQd+aK9PG9DbLa8eCVz/BkIyPOKsIRWHPhHJUqBesEGIuLX7UMCTGfpQ+Z9vwPXsqdF" ..
	"nDGnuML6/5t6IEXSy7HQHbAhIKSZOJe1ZzKmVi3G548XBJzeiMlsJoAvg7p86fMZVfvXqUTcDU0mtg817Ox6L8IYdyKj1oULl1AE" ..
	"MxYBAbjGkFM/+LGzRYZaxxoOQQ6pXbQi7A74DP5XMlmQZLCrXn6aqIF92hYAw6D35zKzocrdpSg+Axa6WfiXUPKKzcyu1htajFXp" ..
	"MTkulnkWbEzgm3SemJis92wLTSktzY9l61fiSXn+UrQa5wX1qCZPO04SDQh29Jmco0mROrC9VHVCrOoyze1KDLY7+mvqAbpSqdg6" ..
	"SZp6blpO+hwIs+9f7QyhqeCsTHcb5y3JQKZVNQ+ncN4Poyu00+H1G+6Du0gjaE0Oa1RMSmqqg4mn/knTX+Xmj5dOPoU3TAGwTCsM" ..
	"XDn96njAeLgzhZWYum64Rgbola4Np0iOWU6jXeRV+vli4Cqr4RY6IYYQogyL1SvE+3c6o6V0rFTRshrW5x7XOrm5Wg8zuhm4hIV4" ..
	"8LO9TEvGxxnXqa0BCD2/66Th6FWYaxRJDt9pPULRt+kUfrlE9XpFe7+QU2ZVw/eqQSsRXdVGJZnkRObSQ8FCnw1nJS1etAlgAI9P" ..
	"RW2V6ZpVAM62ogWab7bk69UGTF2WSemrzh8HaB7tTco69fgKsQ5hmvS7HzrCy8czN24ts1wpWcAkiodtnu/R0PutG9va5mGBpXoX" ..
	"+p/yUzSwuBoSJo7p3Ffr6axnON99iJOzEx98ND2QbS9799QxwROb4km6VkMCW5FXvX8Qdd+CH1xRwQ3+umeR1KyNGo7vgtEiNU0X" ..
	"ahMJji4RIYtEIUZ8/Zrp3UuZb8JDA0m8D7p68kI0rBEU+EjCyFu4KO3cuP1twjmRuXLrr4dRwicfm627NaScIIV2Ss/U3u/fHIVl" ..
	"FQqhQC+XvC6sAS84fvZZo+yqPm6tylWlFM5cv6BJwpvRHUaCAI9jcSlMNbIlG18lJPjXTnUN8uponvn6AwC5iWJ4DuLs3jQ/7mqj" ..
	"TuXIdaiXodHyIpEXm+htvfC8dDeXRuh49tvUP3Xf8graA120c+3MhjZ2vnnRdn90SwMDauLAH2wGPixPFk6hUXldKlIxBHQMU9wL" ..
	"J6zQrgu+PglQXdOELyGCfunf+knkw6SXU0nYGcM3eivc6CLIhI5CoBVAlQeWCaGrP4Sfk4/KUZNaPE8VRnnPaXRuys5X+pMG3kiN" ..
	"+hTqgYJfORetVH5iRO5JXlOgwDLTcLEdB1WBhq1tATBdou3ITfGfkhYeKnpafsyxlEbGEOESLSH7ySKiDRdW4dkg9zSVmgaG/HSa" ..
	"OyND1qNtncU29voSBa/RbsgEA+CLy0jlslDSB6PxsCNmVMUZ10dkrcb0x/tgnwBBH0mvbr2T+FKROYgThNfveU9MSzvx4kDvj4G3" ..
	"RaVf1slFz6XO+4EXHBqWATd9OneeK+iST0Ho3bIKyBwUglyZUqvxyf4eUD1xkWiiz5NLFZoEsVPihdzZWNljTxJooroPLrchxaKI" ..
	"8et5HIe6jyopbBSMwBg0rnRPNjfGPy3eR+R1j8OcV8JEvs7O3c/QqOuj0Trl3BJQyaLCvKRYMwzsIo5c99w57yfmG4IaoNUYsQn6" ..
	"XXbiJ3ecVnwIvXb90JJhY3TCZ2sadqHbhLK9YaV93Ex8jOFn2bS3FgYSPTkLPmyChOK0gFiBfo1iFEkIP6ScyTpeSy2XzQQp2O6a" ..
	"foP9x9a675gZLFg/k/M7bWD1vEkV8kN3ezQ4AVE2x/8mQ5PbWKq7q6oMH8CzDu4woVSD+xgojvqLkNLh3M5k7iiQgVoq/4pputci" ..
	"EfW32Q2DaDgo0jIm3V3PWIVEzYHfJPmkUNL+GSV95DsvmJ6f/kmwWQ1xzYG23g3kIzq7uCx2xJ2Uugpgam0X0rCqyKPKKV4C/5Wb" ..
	"VxGJ/whqME2n8vMlyB7linghlR8MLV3xIPpsrfHBxL/PsIYIrBUtqVC5TXtIMtVMPZpQctStx5tr9SV7lukTP6UJTalcu1TBSpYF" ..
	"zFqUZLu4aNYPOyYVXINRQXpY49OFLK0QvnGxUUF+40hEv0zTNtQAVMvLNULTf4hpHX0/n/Y3i4voiiLb+Z9WuyVBDmJlCM82PoxL" ..
	"QZfjIggi4sDwR+zkZiBYLrzBpchWjvVl1+LAy49aWBgCInJLOM5Q/q1ZWgCpZEGCVdW68jiFGNwV1atkudYqvAGEekA6qzOpNbiT" ..
	"bq75MAa/clkqfGZiTlnOQi3prryatB/pBnSl/MtdkkIWOFSmkVdqB8XECT/oU0+FhRs7/Pyv2VAJ+5nJdqtjFSvMeY6cShcJ8qhl" ..
	"zKSTYW8JhTaMmfk6u6r6k3TJkbbb/lXYXS0PTUqapjC/TrHn73fYwwoBQjTh1SJX2hvartZVlQoRH9uJ3aRiXTIWDv1WpYL2q7sZ" ..
	"67ySOww4Ehgzzwnlo0D2vSNtguVpqI/ETvdLgIwa+/CSQwEPP9sqCM30OR+lE/7mECMMxDhMCDcgDdu4yz+2dxvX9Z8R1Y6fvyE/" ..
	"1BJb9fGzykg0uOuMcUz7+LMTx9kLXX8IetdkIN8MS0G5+Ys5Ry6hTc0/QpCgtiOCI4kN24fHHosuBcsY3tZwhTFv3Oxa4VxDrgKs" ..
	"rdLNHLKWxyvtay4yMKfezXHmbYyIwsDybrLXFqa+3AFBPXr6YKe0C7NLr6ITvkejsmTlb/hPP+3vu2NVuOOZNVqOj8RTZUzYubup" ..
	"HXm1hZ1Zh4JS9kO5le6CZ2TvG1pEEbUlRu1r1hLYJSgqWBXwRUlQiXmjlROl15gz7QSwQFuKG1CsYde5cU/yX1WyT33X8/rS5GGA" ..
	"fdlkQJ7KIiIBkySdtZU4DcQiYnw7z/uUmJLatdYxP15DA5hwqfGv+BMnww09oZN8TU89kbtDABXjbameRgdYhGwYnkGic/ryuJ+o" ..
	"qaCzafGN0LoZ0NDuWkEO4luCzQ+flQAg1mcNIZ0UMYY10+gJmQyzfBXEcK9Lcf05HuPh9wVV5LGKDtcIm49RyChcAhtbrUAdr9Ll" ..
	""
local PAYLOAD_P4 =
	"C1Ijzz6pv4sNl77uTfp7Bg1k19oeEiAFyPHy3gKo56Q0L2sYASSHcSuhMiUauXyUxpsR/BguDKmGn0/2Yvxs/4KlYG+wYymUqFyk" ..
	"2MsfgmbZ/RBNjrktyDwFj8z5Y4BAx2COlEX4IhSjnabWBe2Y3PWZUm7fpSX8gTWAoVpi3rS9ySmBhPXsZyOvK4X3CeAijJ5sbF7q" ..
	"qd/YALWo5760mnI8Ci+urIvpcUyc5v2k9Lh/kWj+j9E/5BHZFOgCl3KNrUMzy86+Cf9+2d9sFIscsK7OfrQvZev1jQgoJRk3EKzQ" ..
	"o1VpJ3GyxGcDEQAP8+US4GcCWf8WoYwC2MNpNVnvAhxhGyuDc2cjPTpM71e7fjv01lcISmEqc7S7eVsnfutBvp0LU6eoGG4n8m/U" ..
	"vN+cW1juHIV4tpu9QBMnByucEds7OhtXlCLQmGdcdBbpyjPXFOQN5h61MzxB6dKDmrMC1sbPyfHW/KVywjKrJLTlbiLgxccyDf0F" ..
	"Hj2qTQz29EYNs92YnxMAjchy8QngH4uVDFjBwJOZjTtRl6Q3x3PpFsesd/swPn6njjyBGppSfVuZaUAOBAVY7fUNhK4P56/aAJZ/" ..
	"wKhW8oAAIPucmcWJ+jl6/9JRoIcd+pTSBbFwNJ5EaDlNjKPUJ/j5AJW+tscQyYqzvtyoZisf688QlejScjD3j0gzsnRYjhl/Isd1" ..
	"H505VqjvOdXPea4tMLY4aeBsVGmx6ZoTvCX/kEj7gfwtj44ic9HodYnTz5CVq4sekbfZr3SBrQfUGNozXkP/mamRG9+1zdFukvRB" ..
	"Hn/Flc4rSzJ6BOIC9DAiZDMSWSz6bYa5ZSeTTy2Gq5TpnxOuTiUiJ14vFimJ5uWlmfb1xH8AVUYxP7d3+jIhgGv6xGPq6a50eFAe" ..
	"V5NDmwdKpbyqF2kC1qw0016KnMgMvK0G6L1Jx8DxI3U+g5fhet9eT1hbZ3Av7tdsYkuYlruVg9Wr527bRUQJbQdLsOcijTnMagSG" ..
	"qMV+ghqRBDoG+M8uqVjNtdOnzcdshodt+8B9h4sZXMffbhGo2OLi+8zhnh64bvltwTPMhKQbViyEwwWwMMq3HLc1BC8+U0ek/TJl" ..
	"4wBtCw+9kJdeNiHDEQYJkFT3wYNo5QCumlrF7LIV6E/EzKLvpQuXVfRfihuh4Ei3lgB5m9kiAUKBjNRka/S5vLg++W5V19b9eJMW" ..
	"u1VHoy5QRfM7ZGeeHQ8GxUUE94F+66+7uHWIR7xJ6hSoOY5JGS+IAA6YDZe9ZktXnqNNB29QHVp97tea8c4UeiG6fcPLotCCIOze" ..
	"QP2SNGUQXubBiZJMWcSFw5getSSWGPvnuh57VN0JZubNRjh7EfUwLuQMv2K1xwCyRCQe0PVbXCAC14Qe23V3FWoYtiAO08lhNqQV" ..
	"YkgI5kirSQocAg21izum8I2i2LmN0nt5isFvnU863/ywbhml/YDL2he+8+fUnrnjsbrZPDWAlKXxc3XRYO3EhE6YXvJdHJijJyKU" ..
	"+FMLRd4Ysp3OU72R874+9UhY3EEzXztM1Kd3HY7oRyxNegL6MavQlFDooArpcMMfn65WilPJzlkFhGODFaqNxh5c3C7Nq/pDS3Vg" ..
	"7gw4HdQFA2wyBPG7R7I2AL4QDLlG0ONDjyIakG0JDNbZw/ikwmf2Nno8BpruQL/WhDSJ6p6QIzbVuRqU4T5aAUywBFZte3RNTsAJ" ..
	"W9hEThnOLTYZOtUTLX1TJ9hiLneYNupJzpkLooS1YeCchtaaQccCKsUiZnLh4EhHO7csamzu0MQmQIBT/XvkjZtZpI0/ZidqtMLO" ..
	"BLCXbbztss2FzfZdT29C+OaOLL1L4nKiMulMyVwA3Zf+RG1BGjoh6PouICSYrslKCwaZME/J+mZmoJJoD7qmlx8k2CiTE2kUBCkR" ..
	"75GyXsxiHA+8rNtA0jYg5SdpKSBvXTkYH5eeAowcncDG7QhLtncCuh/ArkERq17zxjwlr8G8S9146rCi5DDfjAsAh3/25Lgz251c" ..
	"Nva41qP7zns4uK5zcdSkl0wJLP825XV0TeW8lZ6uw3L+Ua/sdgfnGEgc7l6SnMiU3MV4/e8DNHD1mnYviIEPR37I3I9WNABGv9PZ" ..
	"6AYjyDRH0EAg40SKrc0ZwTFNkW2YKuDAKgoMqqZSByTHXarG5In3CwBdM2No/sKTpc7P2rwNMzAquOYcEvH3NB+Q4DzrMcoWy5nl" ..
	"U9Lq/Xtn4CydsDV/O/TODbD0o0M3DUblkEi4RcCv+t2Qn9AkdTkXkNglMJGc6nohyhDQq9GW4CaMxHEijYzf4JENXEjlWqxcmKYk" ..
	"VcGTqxoUZOJBoG8iXy12GcutiL4tLzQFLpgIYv70WyRd1QorrXfBZBFnlVKSqd/ofqQhTEy/3Tz1whjKHFPNp+mdtKv2JfJA0UwU" ..
	"hMEoPq5Cur86LKynsiYVJeZG/wZ8cemct7r2Cqc5rxf3CivYjmYH09omaiLWJjTNOqdu3Xur0VgAU2qPiBjl597W8KRgOh/q0Bn/" ..
	"icbdSZIu4+ovCK6C3b867VSiPdvBwdWcE5naFcwvn9L2UX8/AY1AkyHFXpExj8ZStin2xqIMi8fpTGwQAQ1aGiNLOAA9eObHs2bF" ..
	"E4CC9J5nUWwQMAo3wlh7iesrIkr27bg7QPqqCX30Qp3/D/neOnZxznLyEGUncV4DBKHt/NBHEfFvOBXWbgoWv3Uog062/NgzvCDD" ..
	"2LEsZlwh7PYIh6ZEk0xz4hmZtX0BgmfYNrbIXOJJsquVRswAgLas4tHrjaf9iIdhX8xEKrgbsIMqP2IiF9Ze0yBmgCiWTCDxY8Sn" ..
	"16ZAD5oJpQT8vHOAbeAxJ+yzxAh/qCNjXIPR1JXVJHYoZ4M8qJyfiJYdwzG0IaJwyAIPI82IAxdZ30tKVIVg9Gnuvdd7UuIURpC4" ..
	"O5SDmLFfU/JiUpqpsk3XSu+JqyJeUVgDheNY4l3Jl+q50yGa/hx0yqu8MeMGyU747Jow56GqOcPibJ3J/ydogcjXcKkPdJQOJeZL" ..
	"hkG58mxy2jwR6PVbonwg/YSprXrCoZ6dIaO/Mer7XiISyMacfKQYHpGC0jkRDqcollwVQEWKGhCmm8LfSj/8e61DNkZZqbZ56PY8" ..
	"dKmMbRgZcaFBrifZblNNKkdwiBaZlfiO+v207SiFzzxFOgnAb6ajzB1yhWYPqVaCrdGuRaKPSvw/CnXFYPmtYAmqgTmplELsLWjE" ..
	"Q0C99LkEuXXX4gRBRYKp5ePNRNJf9Fs/pFXUOMB9JsfPIx+08kv0f9eLpccI2o5TUtnvlrOokBcxSjXPShrYMKkwxenEySR6m0d2" ..
	"0rrX+WVFY1+grzGv60QBv7G5UfwPBeunz68wgpnpqT2z5XSxkwlBYFohW6BV4RIst+cewhsIYHvx9UDssvMQWI71RfiHO+RDllT1" ..
	"bH0CvHfFj9LOA0IZxyxlJVLItPpJeente6amM2ET/0l0Cr8VhA7CcgJG4FUxNF7L5QuKqccXoY/2hkoVdxEieIjNQO9cBy4ZmT7g" ..
	"rN1W8u3QnuhDt7MNaYdG/B5PUJUJ1okluEb2fQstw34DoZrA9dqQUDDmN2pRbe4ky38iW2AmKOboYw+VXkGCnJwF3hS3c1H4robN" ..
	"lgfTlreu6fAKO/+NJLpj1HkFcFI+KS7/DoPBuzdJzH9H8HfDgiJcv+3lNuot5wxszuNVDNeoIeBJqaQrczOI460s8PvisS7tcCtW" ..
	"ToUXj074TcD8PXySTSB5JKNkKV4sqWiKxoC9XgO3CIapY85iLQDPbdlIuj6oqJ7SdkLhaIR37cbiVt3wz21sPnPxnSsGuK/Fguor" ..
	"mrhZB2Hw+zNFqdXw/LxkttTuIMc0QPfnCDcM9LCXkK8CPRHQ3enIthqyOCbe9Oz3zrhUEXzq8RZw0ExM4mM4AQHEVDKYKeGYsYDL" ..
	"l+1XrmyC5jz8RaceTqqXx8hpTFfMTygIjkIyu5hjcpTU7J3yxznD/n9+OzkfgVLiAy5/PvaxDFSwZFXwRPNQw/zruWkwXn28KxwZ" ..
	"PFtNDd3e9ZigcoJnL8zaAGQk2AD7K/+yPaDuG87PFRQx6hJA6fTtLF6xU687P3Lmlf6OL0mJbBNMJQzwa7PxVTLZahPfYAz2pDIR" ..
	"aEbFHSt9HOck1gHoPkeZFULHHtxTIb33/um/O/0JicBKsWPTpVgPGd10fZ0YcBK4yzV9R5glGeBfB9gsbSErEGBKjrB+IEAGlvPa" ..
	"no7VTqGPXoJHIlQsALxbHDlTWKEyjlApxWRx+uyikDuNUJFS/OfaFeqdJ277zTymONADjRaG7L0vdidca/2Kz6xwsAxwBNjpofRc" ..
	"onDr2gB9FsSxZk4r1VeyXeoz8twWLJys+qi4EXxqSIlm8nkHdMecXkFffREgXmQfZ8GEltcB3BortKqUN45rItQSpZ/TlVNGIDaO" ..
	"0Vr07s0s6VyDKVSlhJpnqFcjH+uehGFjrdNZEmOPvO8+D3jnBbflTdIqVzPxPnZ6yA0q7Ebt1YMEB8dbQ5w787IEftR45JE0wNxW" ..
	"bWAHlVvC+mgPz9C2jmedJ54tID+cyT+vzGFXSKOpjwm9TsKfLXVpXVMiBRrldOJsjRjySlW46hX2KmVF9YJi0wwK9jQGfANnw912" ..
	"ztItQof1DRD2P+kx6F6p6XCCyA9YWgWYX0mdY9AnFuunBLoNUWYHGxvrsMnAKkm9cEZBIpt7pzxhoUsBoORlOyEOaxnjN03jJkBf" ..
	"jh4x3u/0pEN3mAeaEBp8kWURLLMKe++rnR7r4SBD7TLusTeR56lATFDGPlK/AFr4Jia3BROdD7jdxzIcP2ChFedKWMhPazWIXgLX" ..
	"18hM+Afgw64oPLmDrCgjy0bR22YN8kl744j4OTqXz0BQNOdb2M2o0UNM2ldBzripjz203+96VU5L/wZTv3qsJ3kHLL7OBaoAlRXU" ..
	"QasuIKpcv1dixzgyOpzyO096suWyWsjhhUPQV2QJAB8Arlxb1tbZCl7kVGzIVkHhBdp/g/3bDcSZ42n36zOBQsLgg/EPPv7X28F6" ..
	"XUOklha+L5Jq0QcT8K1qC36p07MmdOifbgsUdbGYrbV3Q+2jxRlwYPhblKrr/3P8PSHTx1+OwlLj9CGNdUO+gSlmWkPZgggqC5bB" ..
	"BSEv6O9xgJUfYn5JuFkJhWf0S73o0e05XnNqnlvLlC5JJMkkU5hDCz4cNFizwvS1OJJW0wGkI+OwPyqwY7AQ/O+IpIOBnVNA05/X" ..
	"W7DVProHMKBNIog0FStiylvtkqj32ZL0lZtkVAoipvYolMnhtBkrrzemW8C0UCtHJRo4BvgOAn33dh13IaIgMyPMoqYFwbwyoq5m" ..
	"j6ZKkKgyOPORLnBexGiuwpnYBHb0ag/UkG+IlFCk0LjH3+Vt8IaxiOKiPep6AyI7x7ZBt9Luri7ohJLglNpT/96R9SJwH5C3TX4m" ..
	"kfxz3XBbJn6+XhD9/TrxgnsvrNToEyPK8jKzp2lwaf5y9odyf6ib37xgK10Rp2oid2Wn1PN1Gm35jv/r7yg9sEDcVcKDahWcnPZd" ..
	"zMBNqVrFKOTFJjrNcxSmwdBiVjZuEBuhw/kPXE06f3uGGBuS2XlXOk2Fw6XLhUe/ZkZ7amgzPl9kpu8bHgh48t0j4qUm3Si8TrWj" ..
	"hxszWyGDJgY5DDNE2lBZhcCjnXDXT4VWwVkykOC+JxjfjWNUy0TGnJlD/9IRuPYSDxl+C+ollSbcQbUjlFPUMn7lQ8CZG3UxkUko" ..
	"odbLtti8+yw0WGPL9WufZsGs2vuHhixxicLX4VXcHvhPB5HTLkQkVTCg8+nhZGPRlrtZkSOeO/rKPTgvMoDOMobf7PTidor/kwFQ" ..
	"vCmhBlt9l7KcUYMqU5PcgOAaQNqDA9s9pKWzbZrx0DwTk1rTQ4YtXa8KNDM8U1sqw9JuWRvEKuL0AZxUewfIIhDRkrvpBjpxWzWJ" ..
	"9nmfFc5qYgyChbKStCNl7IzaTx8FZIm6EHlYeB3UNtaFlvV/XLx8SaV8sc5q1RVFkLYHUky+bjNliSf7+FKL6+RXeXCegNTmDGMG" ..
	""
local PAYLOAD_P5 =
	"OBQT3xaUzdxKzXCjx8pIKUqO02jaMLCUC6dGOrtP99OQaI0401KsgsD3VxrjgE8AMI+kvRw44yk/nM5GUyVVEEdbg9gWTgSpzJJ5" ..
	"8YBeTjUkNaT5CBydagIdU0pKQmf77gHi8JS46HZsXzXcXuNDQyr6SKYhrug1sBZESbALGsHO6kCfGZHjt55nKs0V57TgnAPqw/m1" ..
	"tvtNOunVvZ4hskG/N1d1LfdQA8MHWNPG8VgpMRIE8TA6lYY+9F3uDXUnDREeqOPkQzJm1nOwF0rxuJHIf5a8nLQ/gQtrx+dswUHl" ..
	"DcWmgNWpcvwoZ3861Th+9cH9mmzB0E8qwCZFdI6LkSuSxOiyaKWE8O8Khi6JxYXtTxJG4De8/rJf7cVqwj13xAjGQIK187OynmbM" ..
	"btkqY/qM7ACDc4xoXKIt9SpnVeIw3p/d4NBGLPSKNcEoTP44nRE1Snn+jFW6ffsj0klQqr8qG74bbak3uWBVrAAkjRZ7tlutK3Dk" ..
	"C+kmCdIvj0zD+wrhWIb4wdV69OHYGhLkgpT59lI2LyjYdj+axh5vBkeX0JFoceyMH4UO0hngWcRIUuk7lZAEialqk6CB1x7YPnjG" ..
	"k8vubMGN2IQ0dKvO1oSRoGDFSmoEjP38OtSd8usPB+M4T3PNpfZ/YiGX5iX7gMpXAfhpJFtcsYBjGz3rPls68LoVkyLMZ9S65YKf" ..
	"pnIsnPlpjs7VtLdImoDXOSA1BFbcK5AkkyT3ok3GsuKMEbww19tZFg8wHG7jxFR4ZSKS9IqpLi0cUX9G2MEuCtdEcVy02fTNY+fh" ..
	"Vs4dKDwNFwkUOiAG6LP683vtpK7Q+H7odbj9eZP+tp3+dfxRZEb33aLRJeIAp34RSOYkrikKB4UN2G0igGuj96ZlHrozMPAIxhWY" ..
	"xahItYhwEqzZkvyVw87/vh/oJQKTEaiaXhGp6mdDNuX43STv5lySmo13BOjVtyGvpSITVelZYgE0DR+CKTpz7WL+EJEhPLVnIRjv" ..
	"gnZ1BphM3Gh4jFy86D+bp00N0yS7MP2hygRXda5TVC2YR2fOtDNI11FKNUP61w6BtkAL7+uwJL5B8t/+BACkZvcX5eRoiRbNa+eB" ..
	"vVMp2HRgLZuiruW7Wv8QCm6mCC3P2c8r9FWB0/PxYemU0lT81eXrccQfKEXagq/3LE53OvBzVCaGsmeggDA1BonWWVUo5Jm7pnp/" ..
	"Vjuc4yWL1LuW82diL/j1KtoXjh+JhR30W/5mnAALUJ410AFzrsJdS/cXfszjKKWkeQWd16IuoID1SZdzArnQkpJXSCoQ/1KtT4Td" ..
	"yfG8OMcM0f+KKFeMVDx889NYNElBYHYj5d+pOtc9stmvDhuXolKNYE+GZLQkGSUwdHC+GC+/rwHlkusofCXbIaHqw2gB+eykwp++" ..
	"hh6MlxRpzsDw+6PmxoQGxbf78EJA2i6FNi+ppSLpOBKOJIWOLQAEk27RbcT+RPxTekb2LtFzeDBGdjaok67w8wQe/ICAwJ2tfKqU" ..
	"NpbfYNzdgxcO/fwBBiOl+0Q6ugWXcfkcs0umjZxf2R56kZthJZsSRL1c0ArdxOVpSHSjyfeQBxUIyrS+exlRHIq670w8KmV/pynV" ..
	"0fY+64dYa7ylFJIKhflXntuRAcggpoPACfd4lAnyCQW2LT6gRFH0jAscHCV6ZfOBQGEi6hjm/JTWyVmmzjE9xOa58Ji0RQkZJ51W" ..
	"P9sXCeJ35zTQlRBHNuKGHEZYb+k1wVfdFXjFP1tGtDQX34q+BZwKasnY25VWkjUlEeDixz0A+uS5IgK4+H+VfWb/4JK/OsxfTvt8" ..
	"CEPgAUgAiymCbqy5BfJKTlqyVEAab/U9nsUf7ej4jcxlDqqYwjErz2d0ICZgXX+O+MwhtCZUZSwz24dAc887yK16epeBkMXw+2yn" ..
	"fEGDcfZfFGfHviBzKCEac3Z2CN5+g9eVT2v7w3zqQb7Knzp/8kYsUACZLxv9PeOuFdlRjfULCLag/XnLqpjT9Zd4cBL9Lf9W8R53" ..
	"bEJhumh8WqVrfaltw5BilasNY693oCbWU9obCCegVJm6dTkrNtib17WFZH2eBTkrGqExT1DQ5FYY3VUUKQ2MdYKFBomjwzpNWwcr" ..
	"IIVGzDPmlMI3fXCJkfDUWLUSfxXZCz4tgws219A0bZWuG/doJtfdIYHH3oMTADHETa78uGSj/5yIi+Mt6+JhSRkHHOAIKYRaYkI3" ..
	"B0HqAurwllITf8hhxqk8Sf+VMA6ybu8khngRY1xswbicfMDCmBUfBUprhsVPccNhm3Z1e8cZ3t4dvA5khzS7NuoLWCqdeok92624" ..
	"OnxO9NSQcLaXL0FlThkRkAPQvQHkwtLSNiWdyLjdCA+eBliikeApRFXYtxpkEAtWQbN7yDBKSyxA+n4WF5/L9UBhUuNm8vnM5r97" ..
	"/LT+2vP8uCcnti1v3LQyG1iYtJZ0Q0ciwI5VP4o28OQ7xPFnFkI2Nr2MB+7KwERt3aSCGJSalnawmMrkKtNW0qUqZRshI8lA/SxV" ..
	"fFjoXzYp+uPrpluqUbAnJk5vPz+kIo5a3tEY8aOLdKC5f8ANTptMqKqMF+9wc7ttSMLHnYP/eqz5SchjEHGyLTUmegE5PQjaZBiJ" ..
	"0x/X2yNOO0YJMMrqZk2F3/YmxlD9qS+syhwxCpnc0MS7bzmz2BZfykzBO0XQB+2hXXh8KbiXJbz3A0gXY6doY/SOqaJTwqY8OfBd" ..
	"8ihStmM8UgkkZn+ry2zAGdHCsaqKU4QeahKd3uZZwiGmre0WdOnDfmcBau42q0SdCVgt+Yqnzmon9e3+RZQ2whYDVMCK4hVM3KCp" ..
	"fVDu3n7+qqJyiIv/VYAjJ5guBIuMAZU0IB0rVm7Nm5ieGzp6+/4+798ZIwQaK2YOeWMx9pNEBTlMgC2kqIw6wcveuOuoGKoYt+Ef" ..
	"fuTfGwEFZlh261Syf/E4SAvSSuZ9Pq87ZkCMKnDAKoz6qrXHpXf89BS6ixPgiQoxYGVLGL5tHCHteU17vUg0xElycNN6bygpiM9p" ..
	"pDrIMQ4ee1FEbNCrmlgT4ge8fePyKinorj5h6f/7/tTROCufSNEc5aLCP0tDKalaWEhCp+9lOyxob8nC4qq2S/D52/GxqaJgXHLL" ..
	"TF2AMJ9Cl5ednXR5rJuVg1TYDrt14DGdKHu9prC9+GWJKAvMyk35HiZl0m2ifm2x8oDtUGiHhmJEd7xZqi3qoAM2M1KKII30Q63o" ..
	"i2oIY2Py4UtjQpchf0IyoRXCH/HBZxRM1Y13x9v8QaA2bYfbcqwrRqKUKVCfqRuFuP0yEeR31JgePk1Ysju93iNa9KCXBw8essAq" ..
	"9t5nLveaaGAzkdip+Qu7a+6YlKs6Tawj9r6h6ETk0RwcdfML6jzaV7yTdX1X1YHrdNezQ117Dkeo4CMOwTw38mJ1kWaMmHZh054i" ..
	"PyZ8PR+OmFs1Fo42lV0mT7G0ZeQWPWIyFlLVJABSUYk2T0BvAT5S7ZhPf+tvNIN9fpEZI0Z98mLqjmDOFEOHu/LOE/T8ETOSc9/G" ..
	"TwFHWpylSnq5bDsY4cf4sD7sOXIf2PfQzj1T3+d6eE7ZLeIdk8WbDZt8vLqXZ70MaHXJWsPRMp5pre2nWunlqBM8c+QV+k95rAYb" ..
	"6g3PPUfP2XjscZYcu6r6zp/0wO/76YDRk0LGSDNkw8HDbf4pXwg8XCsNAQ/npmE68nzVLNFWAf0xHkXY/fKwoI7mJVj0FBxFC00C" ..
	"BwiZ8fDoMOSIHp33oreaPYv1jb05cYC366lXaC69Xg4jOCOyrTlzBrpnEGjT8FJlsTJgafSuuGfdXTsiXBwFMQNk0k2EjgWnfaN3" ..
	"gUvZSXeftQRPnW0w4sUg420Y84SFsJ1DyU85DKopa+oZFZLAPcsOsWmbSK9kI/je5GW43gJArqNT3MwlunCCcqtFC9OUKSFRFM60" ..
	"Eg6zqvsypEwCkeaKOW0RoWZpLbYHi7dVH6R2PDQCaDHKiJRHA2h9+3Qw5p6C6IG2DnPZ6xC3PnZcWV9iTMcZBHfdUbeMx8CKS5mh" ..
	"B9WoWDlqdc1sa4r7bNBgMBHjibiNGiYNjqO6YTT+QSljBs8JRjVKsBsl2XLM3OfDfImuZOA8LreqxMnNH3tvkZOuR3YCd2UvQkrA" ..
	"KdzXF0OM07RwdlUOdYbHD3UEabrp4VtgOdBKyiUDuiialxgGdcWk8vxVG0edNzkKEvYQ0o0Zrt33P5bVZavUgpP0S1U06Y7A4Xpy" ..
	"oj+Qf6+E7Z8MypFxj6OhIaIh3d4up+n6FkFLEcpE0WWzkiIjQJBDZFKzrJxL06g4jpdyBCVgNDpDe55mMBgTjHK7oFRtIbfT/Qrw" ..
	"EfchPkMDucWRyFpPSo9/qpvmTuR+kAuSyEk+Fo2jD0cdc13D5Mi1YIgszaIRtkhcQjHgaZQUObvga3akwIK2xNjzFqZr8pMRg/bf" ..
	"l4bqUSSmHjrXsvXcTPQr2+JLAdWdCYDlxHWcj9ob9P391ke2a0THZesKIfJe3I8DL61VJzx5m/EX3i5W7VoVP6vwcnRNnEvHfA5C" ..
	"w0/ErT4rJjLpG7S1NVLPDuuUBahZXaAaAKlyheue3Lw0OPbfNYRho1IF8eTSAslfG+hXVNbb6zOU7vKz+hlhkemkUxMMt1/Kb2QX" ..
	"XTOkvTaE5VyKIYupKQf+dcgak8TRyD/AtuixhLAc8dsxXyQxp8ZG/OWu7qoYo/55C7VhzFAQuB6POF9+/ccNw2khpDtHNJ7/V1cE" ..
	"1B8T7LfTFIL+WSjOyRH706tam7K4p3Qd4aDKCW2z4qDCjXoXTiXoQ56PXYbt0SaY+zug77X98Vb5IhdpBx2q4+CYUHXuEnC0UQJH" ..
	"QIypB/Y86gknQyFXJiRIG5qMrKT5he6BXRMp6ElGy559hihUKiqLZkJFxkZcCWnV7hF+5H6z8n7qgvGJdyi1mQ+xxoHJdzFlSNFI" ..
	"QW6P8+6G+7hrG8XZvoabxQ9ZLGbKGzTEmsm+fFCMqKctB4vnSpUpgP4gzllaxuz+nQ2vv9cTMl3akhk+MVVHwHfCCZGoWkpfREHI" ..
	"Ra4suT+xFjcYKU3dWvohE0vvCicqcTBIMVHsWkP4nCxPXIJmy4qBMwHmpBHypJyKJAVIgiXFZFO8aiLWw40iW5vAb1NF2442LsRJ" ..
	"bLt5OXe7L9Py2oJFdEo8g5521lLLHOUHWsg75VMKGlUo4VsW2lfr9EuNDE2s9HQY30qRAnsRsZuMc3Ss9XNJgx+ACtj+gUVwgmTc" ..
	"uPLRQh1x8qMgyKU9xZdEtjXmgyoYJZvp7tYcbkTdIzi21eG725K+ER1diJ1WztlK2B9EH1CEGNxwgQhg+qg8936v1DviGk18GNGN" ..
	"8w+f+q2d5FcVtCiRfynLn6JR9inDRF37o80wA766J6uGq6hh7UxCHQoN2mVfCxmnTjpbZCO5Ovg9ap7/ns/5VSBYPUvWW/4+pLDu" ..
	"l6K6koX/getrWz2wfjyu98V0zsE1WhvFs4CxJJ+lmXGzXn/rfGd75wW+gpS4DLTiNAnJw8UIze5orrtnLr9jxNxDzqCdOf/HXEne" ..
	"nvPngBZufazwG0PfS4XHVXXT/THeZiF6tkyRtFDGVwSzXkBqtyOVTSHIxofR9Ag4pYZ5CodU3bfWNAOlP+S9deRMi3vd32JM30is" ..
	"jHsm4EZnbtgY29JD6xHpUWHvUNOM4ipFYx94GdT8Ecajym5PkqP/+SXA3lFvvO7LOXRaik5fzUtMgLWLOl+Qpn5jRQ4vKIcWmol1" ..
	"Qg9vYEkvwDRIEcJR7JHaoCyaSSPCdJpyuE90QJQniQnNMeDoeA3l1PGV79DWsZ2hebG2Q4KC14V5OAynSqyVyHnlIHVLB3z//bJU" ..
	"AlXftnLuzxjX8e4Aa3toJGctjAxX5FqMRS3yRDivnju+b1Tw3mqn6GMeskDbBnxuOrjGjP5BIW3pKSrAZK00YEeMnZFHp7PD7BO4" ..
	"+5AQz8oUo1f1PybWk66ZWmuaKrGw02jrUxpDGo66dUaXVYYc2OfA/i5bjPiNA383+tR8kQAiFS36qxhEKAywHFWa9AK4Iqnqy51X" ..
	""
local PAYLOAD_P6 =
	"WTEeO9dazldOfPeqIy4zxOOtho48rAr/38tZ9KvOUM+3I4Qs2umSGUSqr0inNY4rOLPSgWGBZ4oYgPAmBJCqGHHhRmd8qjF8iY/z" ..
	"aFITcuEP8q8Av0q2jyxo9XshOjHZwgUhs20lDBgECaCPNeZI4gEN74Af0lN09uuni7Zb+ZNBUyaPGTdB4xYUCyZZjro8Mm3xfzJ+" ..
	"WE0TdnnEsGXmuzlCdA4ZgM4Chw93kBavmbvb7mFT7gmdKyn4v5cLaZFbxywNoYK6HjC4UAO7SLp4zP4e6wCztKUY+TLe7OvYOjSI" ..
	"RG5kSx46EXTWgnty6kaaHjRq0HNQeA8wGPHYEC6AUj6e8Zytd8PMAfdrbDkqzl+Y3jtQdKbwIuCAfyh6xsWukKa4TtZCYxadFUII" ..
	"DHlbHkGVAYOiJWO6gS17JhFWXL0rjn5nPgCBk8RNk+9yi3I6AT5H3GAK6biGTavd7EnJVDjewb9bAYvOf3UxUEggsLjI+EBxlYfW" ..
	"Dof0SI5uEcArWMgsJnP/7+ezb7ECBTyV01CDDDCv3fwOatK/7O8ESK4GkKowDUCU1WpN92HmMT11xY57KNqM2KqqOBHky3cOSGzc" ..
	"meShGZ23sU71h3zdYgh0Zt/dWwzAj7lhQMvcSuwqk0g4m0WtFEafG2FzRotOfXttEyjXeg91ojk0avWhbnNk1kTeeIwIoaSZqqFj" ..
	"s4BryGSUqfbU/y7rfm8h/xuSZBL6kue5t8eGP51STVPiRNB40VEKk9lu7rHxM9IFPAorQ9+++0SVFCY7re/EuE+FL6fIrRzJwx8K" ..
	"aDvHl+jBFVVxZmvqiMOuv1tVpRcSK40iKXS8xLPEvhOM1PpSMdZZpyXHWg9UWDA5n1dEtQAygAlYG45YKh4n+qrPQm4qQOkhEViT" ..
	"ozfd31hXHPjJMBF0QImxzjRnFsC9qi1rNE1KSSKNXhR7hbe60/SLl80ROTyQHm6d++EdAjUtOvxHd07n8aMiDdty9xlBccI6GLQ7" ..
	"ensKwAZ/1cG9P5tT3R9m3uFS9+gEEI/5n2ZZ/etvoyZUoLB9bhdIKeegti764hudhnkkuJytq9qMzZcvSMhVTVmjBtMxuBaMD+MN" ..
	"LESKhoad+++BsOyp9XaFFgzzxM0iAFg/ZVtYKeHKhfwBRuDVOIYG9/+NTw97/Iugo7DOvfnUk0PsgFJdITdWu6YrQWY9EpMvXD4S" ..
	"sot6NNq0d3W0Qp9vxFfj4wQrd52ilrBwgb6iZF8gUCy/IzheoAZIPXNP3nbYSI7CNVQQwJOQIVvyru+zyR8nrzxd410J+uFCl8a5" ..
	"69ydmy4f7X3SgFbgq4Di7Vp3vGhHRzYKnY4in4NuwogLypCgeXwRhKnBX6UIs0dEXac4Op5pKe+M3MwKyMgfmPjLXBcQMphNqzqX" ..
	"0N7ftkv7WSi877K8dZ17ulB+Wg+2ZqOVnGyaGyYVFPVqoz59yLruMzra1wiuajA5riPfa9YpJ19sl58P3i4VvkTfYlc6d4BdiCK+" ..
	"t9nif6cV2s3vIL2S3grset9GLkYDT+iUADvJyO8PdkSq1RXxEOXEeuR8W3PxgkunlTsSrqdnVToa6pgriN7NbZ6YONni/TXouqYk" ..
	"r2JTFpvnr3gFNWbbYYRA15k4TDN6benjgcr1FXrmuP6mlz20Ouk0F5lnCKUCd1SsE2mfC5OOhy0aaVxflNPmur5Tt+GWb/PxFZZ1" ..
	"v1wkzzkkQUyB4Ka4qc+o+PJIuk5YxMO4h9TVUPLyBcBQXFk3J5PXEVR3gFUyH+ADxLVZbgOirpjSSCPWCrBRqU5YkdrX26LPVGtk" ..
	"tgIUVy6qSJHPTwRBiHIeCoMaHZf77XnJ+Ftx499IAaYG1nuGXZE0ZyEZepm6iSVapGCmWujSZxS+MFH55vZhR/OVEwUVNrcq+KKv" ..
	"k+rQlO1QAmQYjA23DBtWCj9rMthcbLBDKJxrDkT69UrGtEunUzajLMDacYBB81iV46tc8qf5TjU3eKOIwZBVXnxu64HIJRVqJF30" ..
	"eQv1qS4mnfVz9JescSQpVbBetWHgl/bDPkCX8UfInVIKVSw8VaRhbU09lbemaMtkBNj6c6LHX5cwfZmkI6q5IGtBjLXaWIWnc2Tv" ..
	"StkDfM1+U49m825kuc4nqgdxcQEiWYinF+VOqfoA1w1bSm53g/TBFNdoENKmtW3IgUV9XKmlamuu5OpcJNQJlG4xrVKOVD1QVD7B" ..
	"FIDzHTuBPkCaHI3O+wJAkMlZwttFCaouS9Na0zT0/LlHWN5/r6hhCtTnjONprtjMOG2UvGR0hRVlhZmve5l6tdAU5OFP9m3gpZzV" ..
	"KuiFCLTQ5m4B1OtbSre/HsFCrvHbrBHkE7rwQCAawZGZ1o1dwdmc48jdAUWhXczlWLQfnFcrJF0JuupK1NLmoxmf8+/26704j3Os" ..
	"gRpTmZY76zju8RPrDOyDHcVs8umRJ1+jnSsOHyCQsDCSV15XIVNnpDVh3stxeOM3DyUuCpuEnZDSbrQczestC3HzjqfW2LYNePIV" ..
	"9G9JfLg90kYLZdJJDZtJkwdCaY5Q5/wZ1vNfvcxH50ygsrqzT3s2/Bzr2FTz/vg8Nd04EkyCiA1SnnHimboywrXgDXaogXM4uued" ..
	"Uw1YE4D9DyEqlaNujfPfoLKvVsXBMJKD5ZonxQDHHBQGylYfvvB54S3VRFpXW4TfzSqfcrDS+tV0YajsS+9FAglFgDf+AmY4eKLH" ..
	"2teYrbABZ/9z04nEWuoWzwUHDr1+Vk2w9uAgAoz2NrcBjH4dnZJE/n1NjeuYoe+69239js6CiTC0PsRSIbEPFzYJASEJOwWoVuvo" ..
	"b/rDuk0vhLF8tR9lIwG2/adV3cSL6lZPwSlispkPXwYnaoV0HXlxPJ1JoX2tVzdhOanSEpkBsoqIPwTnK93cSqEvV8mmGbK/VGOf" ..
	"5BRWtnpLdl628uDRTzIuSTWy/DO6VgeFZpfApzprVr+H4cl/YovP7ROJUsY1sW2x5jnRCrY1lXEyDWxlEeChD136i3n6BLQlWtC3" ..
	"DBmUGTFTqSZrrpdoEQKQW7kPp1S50m0McpMT8AUE/7AL4VEIF/ysL+MVdTEAUBiKJrD04Q2riKyWxEm2/TCJbSJPQlrpFbxKg+R8" ..
	"XB2YH7NKNZ4Pp+jsG6uaWdX9/LBhK9cSAYNyv951O3/3SHZ+puUozywhfFIY8Y4LnhRLcBSfYjNecDPd/jVkhIO6wtc4u66xe4b1" ..
	"U6lxsQmsSnXmlIv/5iYmqzSrrruh9fE42BQpTArXDBxMAD+Rx4sD84y5XBcBklRBDWhm941myb9qiyX0G1MbpMpmoowHAGin0soY" ..
	"E8zsQYq6qE6hUIunxHCwjirE1IEfXgl+2gD6cxoQl2Ez2IZGsXqfTkCMTlbtOJMTZdrIyW9gHpAA5zDGw99WZB/CRJGuZonew1Ol" ..
	"GM9gfi0l2PgN+oqCWa6Z1NqKOJFDipf6TOWbB33gdgnlCbCzi845zcKEujBgxyrXw3imt17lltR2UcN7fNqhJCJ5rANqxQl0pZK8" ..
	"nof0pcaKXABBTMcvGjKwVJEQRLjvInrTqnh9mukSKVl+pXnrVvLgHxIY8bYGnAp+DIcvsxJzKMnfbtpOG+g0qCIifuisV+WDsJul" ..
	"KoCPAD2h/rdztnXf407iRAsONc44UdRa9cPsSzFaq+Dz16jkEZZhLQXmzPOTweZaHOFAopRjU/BWq/PvlSadHNakj9aHcGFOl/nk" ..
	"SV3UstYF48Iw+iBZspF8SETvVgqP2C0JJvcAgEj0/GqBOChdtBwKn004D1g3zVVxlfAvio7LDzf82Up3ufaEqdH7uHcAMiv8DgBJ" ..
	"C2F795gDT2RTSqbcaEaK4+00w5EWVsL+SpMUuC5VqQMCY8AfmQswPfLfVIyYp+pNULbStoPG8YPwjX08y7XTw6HGhrzAVXt8T42f" ..
	"1Eu2NosD2WMW1kCjHtkIT06o0e4S75vcTI8K1WYbRajGAMkEcdf/0+NXb9qP33rp/IhdhvrSSauEdC+ZrymmE9gim1Sjbk/s31la" ..
	"M5O/w9Uq3/9CHhICPYg1H3Ib7yHcgo/hET9Jm+EcVs52OYU7G56Ba2MPgtdRYI0dVeo1akouG9e91gzO4jiKeZLyHsBFa/g2cel5" ..
	"egSoe6ZTv+mab/8nMOCZ1OUPWka3/l/VngBVc0GeBlmcsYPkiLwitx78QKAtgMmCc1+NyfaA61US9shNeDcgdXlODQPMMMQ8d2od" ..
	"SP3+Qbbyy80nrIIjQLzUXoxKOYGWCLBUR3raR3TJ3Smg4MWw21fO2QEGr4G76qOq/38JGsl7gDNE4jpI8UvyG8/D9l/N5P9FL+m/" ..
	"IT37dV0MmZPAgN0J3nxvmcdEhwwXL2BDBdCxRim1fBRxpdWmqE7SaSSqE4jza3t9SLS93F1Smtb2eatYJQjYy/pBKg9HYLwMwcn1" ..
	"GvW/WxOXLCk6Yc+DlincebuN1H+p8RL3XWBEBdHNa6J2q1O/6vM3As4ibDeOvt3+Ba4fviVkXBiz6CIYUNkLsZ9D9vty730SMb/0" ..
	"3ftYPu8dWoCs9gtQxuXwI7HlUtRzzraYMZLEoAuBQi8Sv/AV2VO22dAP31DxVNi5+WkDVM08x8rYbJvTVXV6lzzYNp4qDwkH/Opd" ..
	"gl8rv/M32VfkzaVVPJLPIg6l9O9qpK1lGgYKjxBQTUE0g4sDlOeSH5+auoINKvFOg4V/s7LtgDb8oFXQsJY439v5q0aYN1WtPLX+" ..
	"fAsfKxoAJDu75mCTMs3eu7mtiaflX3Mpi1MHUr7wh/fV4Xew0q8tT0ccF7z3Fhxo4cpAdDSe2Nmf/wVfsi2KDeY3FON/UqcChFbO" ..
	"H35lfY/ltgph5ltkiUvlcYC/6GpVmWvLAKSEXBnq1BNl1k83t+MUQRtyUNSTWEa2Nf40Y4a8iqtekUQ2LfbdgS+WCmSBME/ptB8v" ..
	"9Qttj1RSMuiDO8AUTCVJvuhEDJ6XMZVbfXBexh4eA0Ut+4/VxbapDZElWMZ/0TLsmaBBiyXy619nSdMen0ZYLLUoVCGr5RdfpZOD" ..
	"p5m3TUcko77tOckBzqzAtIIMNgYSXCVv6sb77HkKaYsRj6k+DDTzrd14abmirwBgmRnebYp6Sm22We2RM/CCWvC6rHi+IEY1CSjP" ..
	"E1ZHvJ+HdWrrNEYFuDSqQPboHszfVKJY2K9WZRvDzVpGXTxt4qkWfhmrbZjMnc8hZJ3KPk/Di7oZhd/IhBJtpu629IGo8zROgPxp" ..
	"jkVRaCJh7Bu/gun8kQFp2YfCTdhLn23mExGewtqV6CIlveLzDHpUMssYgy0bWLgUWMbObOThEkoG7J/gdov79ariyXaypJpNlegu" ..
	"LstX3yRv56mQfvnmxuQNjx2/kdbqNVsQHqaC0eI4FvSMb0yFZvcmyRQSSqVxSmu5/xWLVC8FCZ1VkE4XyN0zK7EnV38tc9ZkL/5e" ..
	"5cVOaKVxsp/0xQ6lrlTDlrldkaJbIamiR0AdDphR8LGDoYOWHOEgBEcJE2XcaQkxiChUNyRsvkOJ8dCPgv/7rf6uIW+Oqr+tpY7/" ..
	"q6C4SFIUIoSUWpWrH8qKvmug7wO5xEQbp1wwF2VdSZmptAIJDKZEYJyEhKCAELyQwxKT6WRDUsF6P/C6BhnP7hlhtDBlBqLq5KhF" ..
	"cj7LResM2XLLcT14O8n8riUThyawsJR+/zcmztrsl0HpKsrJXl1CczL1I6CdeV7KzEpL0OXDrGIqSDIFY26KugMZhzxkRJRQbKGM" ..
	"26+0qeI+WXiJcq7PiKSPLkF24MQbINUxYkuMt+vCZH4Ah+YaFrqF/5q9935F7+C6L0BhWhZuy1k3Y2DPtXL+FzHD8TnF+tuczMgY" ..
	"G7jndNpCHkwGf/SYstiIsqmx8pU+Fb3OTqlo4f8iGTyR2a0NhHYLhglfg16Wd0+pasnZkOaDeXZ9L7vn+NVNq9LESzWhTameaQkC" ..
	"SBtNGwHI6dhKQSZcNZlR8hNorlbhumiEa++5qukcBEC70JJMPz/jfaZcrN8hQnXg75TmW+DqWWA55sTs7Esuk/PlrkEhM/58RKoL" ..
	""
local PAYLOAD_P7 =
	"NrJ3PYS9FdX93STCHzYr8k5kkZKMxtfh48FttpuFRfFwX7DXUSGM+pZzxCSsC4MMh5dDju+aTk/wf3/DCODf61VqxV8OUCn54RQS" ..
	"uGnBmP5NrtpXneRnlr7e3CByZSO0d8unFcNgL057+/YUtGBb2tvl7+k3ExUdSdtKoZyUIHlqJSptfIdUFnnoG3hesTrJ7EFfpTWF" ..
	"TgdaROBTWkV+AGkct1WegrZ/5ukIgiWTj3cE/NFYIrPd1Df2dAp2plQMKf2+GuRROljXR3RUMh+9uOpX66fTme7tshqDpwK+nHxE" ..
	"YnMwy660OoITLw9dfgYZwZAX5iJACvm13KILa1SI2oMpi7DJfzhoDqYDMYlIRUxa0gAJdtcxryOjFPtV/MZuzkU8yLuWLTov+0AC" ..
	"XUHZONxKxiUi0D1rl2S6j7chN8GhNpTJULNzAXsi5XpDtf7J/GLOKRli16p5LUIZRifpi2S3biUmeUYTbUEh3ckHwGdCD+ng+qOa" ..
	"woqqYmR6YYlhpbqp4NhuuBNWD9h9yh3mAf9xuGIlKLmVBJ1Abg0oifhvgmmDByRWq1fCg6ScS5OkzNUYpcX5aI+Q2giDSf+xMJg9" ..
	"7ScevB5ycYocwDLKHeS0u394xBbQNKYB8YTvltih40MbnKp0xuYCR7KuO/FguDPf0Q4s9Y+t7Jth9japvhsgYLHAn7io+Gu/db6g" ..
	"x1NGjMUbM656fNIMaN4GQ+GJugGiNG3XwqBdO4lF2Hdt1mEk/1cKE1PJlEGmBlNze0oqGQoGzLltiIVXyQfqKN/RHX+70vTrREQJ" ..
	"MNJCOZQ0aZ87zOF7Xv+5esFRIFCuoRv3Wpn91dOYW5ps18X7HacdEwYSVmXW5gxJyRjwc2p8j9lQneVDTuphTeF21vnmrf/W0PkZ" ..
	"k8MavNnAcwHOqjyDnMUlk6WJnKMpwm6Z4L+T+mVjUONK6XsISLUeSVhZKRGxR4Tfnalar4WqgaPsmTjpJUue9CasMnPjptA6I5RE" ..
	"MdbgrMSX95MXvoMYuPyoZ1lruv2yCh8cbvo+Hqw6U60JJAcUe1k5UNlXo+orDSu0P+cgNkUjnete9rhH1Ce+AcLiuXBjbPOBiYB5" ..
	"vbW5YplKAPZNWUA+SVAendt7uINjt5CUrjUodqGGSM0qlcqCkBb+l87bFXYhxvzE94kodSbyqmSq1TXJSBGe8zLIm4vQNlYeGbVD" ..
	"hVQw+CaBjYt0l1nUWYLVEyvCRZAY6IoBiotp6rTZsLeSC4drMP3KVqoqWSFxjUprC0DQ+sjbvMt3mssaX71gl0zN+4Hx90HJfVN0" ..
	"8wwc62lO6zGlnFAJAZFcPfvNnxcoLXLTcuNxzVqtKt+bXh9Cxq0hbiJ+O9iRCRxisct4nqEUZP634wAM3PcBEj61ykTHPrReA5cO" ..
	"vuzJaf+/SIyP8r1SDAaL7Ah4eu7WCm/GfhaGIocoDr78rk8hwE/aQa089Mi8NrVbEmaulL69mqkbJCQkA5sGaMakjXIW85F5Iq3x" ..
	"rf4Mo+2yaw4g0HWfTi6/wP5mBM56arxhtJJI7U5/BSmEVEueMGBMaPebQjpzVc4uNnA537FK2ZVz6vS+0mipe/yb74QrhcfcRS2c" ..
	"ZN8EI47B1MYinR/2bgCFn17lnuSsQl/efk6bcTwyYME/R7DhS776XA/gUIrC/A2sWSRvHJayG3StlbBU8e+LM7KFNTkMTRtsaY2Z" ..
	"e6S5qd7tKIX6dVHf8cLA0QwZF93mQuo/MWjKD0Hpj5ZAWxInGN0GQ8tRMCHI5GffVJ+crPRhJF67N7WwJsi4LI9LQuYh6lZDh6qh" ..
	"KNbMWhKM+zKQxn9PmmksgweRogrY52h8JGO1WjwT/yHCoNBrCIlUf+b8srKdYxIzM5UALH38wtVw4m9SzYfHs2gp/zO4nk034PVG" ..
	"zav9oqXNTgRf9s5U0f9OmqRbfknq1GvTPpTTcViQHzWBZOYcbJLDxmfXaJLt8bmXWHRHthhnb00o6FnQGjS+dg6R8lmUxJYJj2kt" ..
	"8VBq+/wLCMdccehOXxSXAMXyl05b11g1HF0AyzND8Trlo9ZQR+QaCeWpcYlep2imdY/Xa8sxXOXaFi4vraQomeiCcdsQ5xxoXuG5" ..
	"w0/Zky8xtF/EHjFDXM11lnDgjZ99gzwjcGl77UP5NCgON7M6yMi6d14wTGvXGLIpGzmVfUxDsHe+YqzjY+XYz84jRDgt7pkusFiK" ..
	"j0mGPFIAvDeg5tN3zRH7qY/RZn/eYi/LJGb7qk3DBQzlRAGMS3PzkbdRA4ziCxk9NGOTs47s75MdVUYnnTNnYjk2r4bo4tpfBf8k" ..
	"zZZvwE7ZUdcoGoJ4dwMl4qQoo3Aqio4U2cxDuUUXjbYHX5noSQjTjOfrs7Th4fAnih0QkHy85myZOfDjIFM5ZsBCzFR3LmZ03iSS" ..
	"tsRKtkeLzMvDpx4+0GkQUPcTabCqF9IM4CmSa1ntazeiL5AE4TCfzkhfLBFQAXTUComi/0+isPTPZsYtuKJv0PhyaSiEjXJtRtOu" ..
	"Q2ipznMpkaYMNxmZUX1mrpZlTD4e/8IaK/hONTLienqF1eivgMUn4+Fk/RsmP8MceZgmwE88EY7iLERQpRgyrBcxvA+kpxKh2eKp" ..
	"zMZxs+Y9Exbd/reI1VN8JBj/IqReCuxeGASLsDPl1yw7Yvm0ImL+pWSgsriy2pIzBr13apbinmMvhP5ARf37K1vnJpmNKUIzbE4t" ..
	"q2t9yCIUPcmGbVrQIYDNQoNdizn05T2kQxMCgRq3CAuwoTrwUG45hohTiElqV5CTm5kMtJ98j+uBKKRg5DS5Vwp/3xXb7rRq+T4g" ..
	"ihGR5bIjqw73SSJY/Jf4Y3gvvSprtqD0TELIsJJTUK1AFLbem/MzmzxEk8jhAlvxDEfCAJRUhhX3LVk7PMh4NON1wEgUjoCxNGRd" ..
	"Me/uNFvFaV1dWMYp4aM3K/MGiUbsr6az3wabbPvG4Ek2ToO8rXU6qpcFk20731zQXIOy142MZnL7luYZRsVRIwTfHlB43DNLoqft" ..
	"ptyKhp7f2BrmcHWY15C0KSQ2wSbD31XIc4IK/bOR8olPBBQYEhzxisYfetiWm26O5IsBrugas0kDmsj1O7oO4Mkz62F4MdOn4nVl" ..
	"Cyurum7TPCJf6SUBJbOhmli8vLsSKqILQ8G6tR80jiwe/qzfaEa5ILjP9GP/4xLJEkCke0RliN32pQjowgpsYvAgcdS0JhE3KzWV" ..
	"09eRa31nwBqGBkffApEeIROLkqkILTVbiiNt5O4reaa10i2QpInMolU4/sVfxpVxUYNRhdyQIJ7+uZoVNtWhUQzRwjdW7ho40p11" ..
	"GcbcvDFhWMyyaYZaafrtfU9nErkqLc6h62ofLf6Dul6mGxa+UdLMpS5R7AX/8TUmrtRPanD1q5I//0VmfmIztWQDtWS5nQqbmaHa" ..
	"K7jubcR6M/grylFoyt2RdoR3nDUpI8MimSp4xpOJoIXOgbrDzb7LwNTFks0SkBpak9R6ejX7WV3k9FCSL2VcBK7MSrEhdZrVZcqY" ..
	"Q1FhvJInL/9yQ/GPHEVthnim7vQw34Zn1CnmM5XUm2W7rsh65pRafs/yd+mlmcyEREw38nu49srheoD6vJQJvG+ThAHPTpvjHyR8" ..
	"s+ws/sy3Nzno+4VsgT5Mp85u4RmHNdubOBMJI7K4uv2Qks3u8SQNkvLQVR21o8gBDVUYHOUxiHVE9pFfAEm47SwxQf5hqUeGwYyl" ..
	"4zV1E1cLMtg2wU9sp7IMpHrz0uKwomMhbSErOUjxEzwRGAYmAhdU3Td6OvcTHwaSLegFNvNQCxdJBs4hJRiPWJKes0xRQaG6wuEt" ..
	"72hK877cD8k8kDsiKfyISlBw3bDle446hQlw71oUuva5xPp/ODmqZnm7t10CqFm3zhvTbTX4G9kBW9fuoyKDPdSJ3mAoyYKy4gFX" ..
	"DD1NYXaom4VQ3BrFRAsOakdaWm/Y7F4Toq0WAaVlWli3lTGmtYdEdtwQTljhcccFza12rh8pEwNZsY5vSnR5wdf+nrqk8e0yNiBt" ..
	"pQ4Xk7pHWbfv+79MuMgZZcFKtDgUTFIPf6Mh+cYONxq4PAtFsIaJSn8fq+B7eT1xaAtiw1AN7qKwoRuabhorZ9eZS8T73eUcV9PI" ..
	"l53mOJpzUmB4LVALHhKf/We4jwURQKCL1lEKxDZimFOUdX3d81hagrdlx/9LLkg5Uc26hNSEPeGlH2KTlVdK6BB9iKGr74W9zIEo" ..
	"5CNy4x6sJzBcCm0tI0keQT+ogue72LJcRG1qMjHJ2oQongGwpVllBu7tK8YL2rNyDV0JKpAJTzbZmkHOzjeu1edL7BYS72ULWFUC" ..
	"5wWxfWHr1wyPZvrX0JRaQhI93opaO9Ss7z5IFLVHY2+uNqn5QOAKNj7XBObZ8A6iWcvSQnRG9S6leq4pmVGIBqjAHP5giETzaO+h" ..
	"ZkIWTWKK2cN7qsx8MmAAdG+FPvy1S5dfVON0bgAnbPSukzELN5Hy0uXHX8DKjw1oqJ3PgSA469Pf4nPU+AGkJzsR/8TE0TpDgOXu" ..
	"736ONZhOWhG5u8Y3KjtIel+e+/KOyIsHAo93o8WevRaCacQj3CEG+q4Vp/pww/VY5WfjsNimkZjPfPJqvJGS8n98phWwGdo70LAX" ..
	"7k+zu1Yiby84/TTDBRlPLBfPfcvtQguhwepeLN1Uu9G9XFlgQGgouWXSTWWRsNmN/Q6rd4L7TFsUY2BXwvHCK+lcwLv9Lx7ZjJ/b" ..
	"jkJeTuIngs/9Z1ioQ7iVWE1gEOB3r0+8yd5pYA/3Pex4LDzxJFTvvMIVqBaFvsrqbNiKZ7Zm++yb8JhqI6DRSrYm6g2ht/+/qN2E" ..
	"qGqKdeJaE/Do24gv9lewzf1jyq0iXOLomnCXOT0Vdls5mEFlvDjq8Ol9U4sa5v98Qhdsan4XzxsjmvUT3qS3xwaP5PcjsPMCsROP" ..
	"gKritvZRGV6BvdXcge22JUE82Zu5eccs0yWEXMgK3JdhckfB8IJsvIhCXkTYGqFrfuk6Uh7Glu58hoe2FVLp0cjY5EShZ2hxfQoN" ..
	"LRa1NkKRzRwMAyK3Aep3iPh2CPxVfJ9w5BmUtx4AHhicP+wCkJMjCcN7NqGqQs2idwU/iYRLdRk3ZdjJjruAO4jlUJ5ssPRuOG9L" ..
	"sTgWiWBTSBBsGTsSrlf0hzLJc0b6cGBwJAzLcj1RYigtNkq8BeTlWMb2TC2CNx49ihDE6zjckCJOWHDbhJr1ra2IGIOuGsK5FChl" ..
	"fIK59YBZsM5toK3L6KIK45wlWYG0Td2NwD8wKok+yfCgg7FMDNkidacsDv+ejs/kozUO7mPrZENcBI4rTO0vzS5kSFGY90V9AodE" ..
	"NMTopnVXTFmhE+xVGtJbiobFoWuIWDtxGbmVpX70Ij0QFepzU7v5sWDm84sKjsK+O4/07l/Qz01jtAsJbcYTe2jfSODKfiSdyjA3" ..
	"U1dDZAb8/5kiCMMILzr6SLoZnJl18ZQdPAvgmaKxQ+in/zzype4mwiCvsrAjpu8b6CAGBw7skWluTaEj8PE5kDlsYC+krCXRoWaf" ..
	"g34eBrDPTpeY9cCO25q3ayUFoHSC3eAPDo4pahjbi417TcASqhodxqVQoChu8qDGOZqQ8pEPWt8XH32EKeUEdz5uI2BSXgDqI7ol" ..
	"s6LRNQFkXbUmONjnq8IgKl0+Lhohgh0tpCNYHsBab7oYBvn4VgLZp8ltWKnGMFMaoFd0mbTUx03bB2YjaoA/uwkbaVYTh/najmap" ..
	"HXyDjK8EzjXzHcimGkBUa1BS6PKbJ2VIFVh2bZsMF3RvJLXn/Hjz88P50RDak94ZiAWPZjwv2Wk+ChmySrOw9NfDkakJB03b1IBl" ..
	"OqgWM2DtJujB1oKjI9FRxAgWv9GL6pEgrSsXFjV/SgMU9AqsD6lnklxL9TOgSvqBN152fRFvGfa+MzSjeWrENCphtDbsW7mKmJtQ" ..
	"kP+E8Nj1QoOkhZ6BFBep3H1vgs2UQnsnCqCqv616QAqV4d0/zeLL7y84/2OzNgXbjExx02KT/ZSqywSZWE5jmdNbIu1hXzXKASLb" ..
	""
local PAYLOAD_P8 =
	"jOikBaKjbB9868r+jGKAFRjv9iQjjixKHlfQv5ssj9+ihcZIfU9bFURHdJDMwEPntIrxWiThH0MxZ8FazLng2gzsij8piXdjeQ1K" ..
	"VGYyn+sE1da9YLcBgvTCnjBJ5bS4+FeL69uhmRZf2iDbl0PXxWhou+H2XLBDItKY4D4u7qQh264wAf5WFlgF8v5QhFOLBeVudWeh" ..
	"Iq0An1gojoQW8SvKdpWn/sv5rSKYVFiR9ewFw21YVfGWE43/hEC1VNtDjw0R3rc1U1ix79QDboNasLWWZhsGqHpNgVKGElRDC2ir" ..
	"U0fk8Bse688oz7H0a01f94fA02Fi6fTPhEZiRM96zlg15jz7C17eLLBg40GMjsAnnhfPbYlSEwQ/CrjnpGth+50rY5hNPZfTm0vr" ..
	"HEdm3lhu5+yXS19HbwxQLPxdU3wxZr4lHr4fH3FLMPvJhvUNfXF/EsYA6pOrrUrmR6lRHClQiLH7Cm7bPSIeTNVPSuDva7UjyiTo" ..
	"mqpnr4i4A1rrkFn8g8DJxpTryKjKLGjQXoqs56O1Cx8SEcmcS3mBe/YRF77bzpo5W0ohbvwF6Hsj68BwghEvQ9FggQfwJYi/E3Vd" ..
	"WO2v0kqrIm8Su3a/Rx0kUNw8+XgD9RewsyujolrRRDZAiSKHQLa33RW8v1LdfDH/IZ94Pa+0JpbJwMotLzpPx05dCQb+UpmLL+ka" ..
	"wWHnon6OKk0v6f+6don5cNdHfjDn+cbcbQ7s4qtx1r/DOtJtaiAGXafEBdEw1TGPjKUZuaTJX/FA9uj/AseTUEUXnZHdPf6x3E00" ..
	"A15oZ5245dvE9IWyBeuWm5XwcpjFe6l2s71TUsvtlAKa+M6Au3uXRWidWH04eRnJZSKg6vJCsXKAfymyi5sDLE+U9cX8ZOzg1iKI" ..
	"lzF9J+eYA0UQwZeo2UfJYUkOJ1fmbAU13Rm2Pr9mZVUAdRoFsEEhvcMP0mIxkPc43xuqDAMKymc40k7BqN7y9xuCxUMf1lft04Ux" ..
	"3htfA3BEwo6hSucD5c1fpsOSAL0X9ZToUfMy2kcVSPccy7Ho7gf5pm/NC8NjN2lpGtcpwYz9Zeb8aGaDziZ8N+DFtVcZC7oW5hDH" ..
	"TK/4kdA86KYS+bdZ6aA/Wc3MlaA11P6INqvQWe+E5aPteu0e27cbbYKrQRlOJ0hJNWV2ymvL4TkBSHpzlPzILxbFt/IP1Y/aFVoH" ..
	"pC9kxjkKVPbzUofGAtMI5QepVhoc2EKz1fOtCkhWBKouIP2ebOo/dO8UFf3nsAqpp6W8Dpm4T7xCjJ4kj7JELra3J7TnQad2/xIl" ..
	"AJhI36DZ7wcPVYWEU8UQgBigI7pJd83DMwJve2kWrm9+vok0N9GdM62IuJ5pKNtLrPmJGcG1YrY2j2Tw7CMphaNqBBXHQT+A/8tm" ..
	"yq1LHJN5zOiyVyf+cU81e8AYm8PICIyG0ArUi9uWEtMbaE+bQ4udT7SBnBVixuZ/gNjDTqhg08hujmOrZAhDrGPMiHLsHNGvjQSC" ..
	"2NHx77NEjSDMIpsqtFh/mcF0iXuZYufyDpZQImw0fODqm77QsDB5ri7hN0OtvKwUUnwuzJV95SOan1YPtKmskeLIfkhLdzhY+Mmy" ..
	"pAsS8OWUEpPHG2baFwQlXF95YuF2JqSrvFIL1S6aEER3xtZQkFj2OrRpCGzBx3bRDUOSQERvuYCINyJcvJWh/IJfc+9yq6Mducqr" ..
	"mlxRUkvVCTlNMBR70BMTm812CN4WuM6XiBwvaiW+6kvmB9Tfs1tHxo367KDZhswEpkfbrEeqpz5tn8+9AuU5XUUQt4X89CXeWWuQ" ..
	"DvqStFOt+WT4VGJH4548NLL6IAAbtbDDFpYIQ8hd6C3hIDHRNNOvDPPHFlv0dUAg5XmjfZueMkNO9II/askXUbYeFtDlu5OdA+zu" ..
	"FTO71vuMiK/Oh1wd2VUyOBRn3B7nXgF35b1qqIhyyfD27N46NTpuPehwlpNYN7SrgaxdPhkGiGrliIocSf4K8Ru8LIMuSVWdqggc" ..
	"RA6o4IgwdVgGtqp5CUMhcXyQRZboFJ+xw1tz4wGR28p9M2H+bKsJrcph5I8F0bJBpMqicEVY/TEuyOvTtagkXKj4rkm3E6YMo81L" ..
	"vTe3ENBTcUbQC8NiBePM0g6KbWW/LGXtsT64V0Zqv6furvgHgcaLybqFW2PCStyta9mJuhIaDK76Rvgum3ck0uoLXUf0Fi1NAeNv" ..
	"TM/Ee4pGNQLP31Qb6P0c12J8VIRndF8p8K3iJvs5EbmRyNrsr2mAvB/Yi5i+mx3AQ/nrPHAwiHTvY3zP3saPby5/SMQCzb5UiwdJ" ..
	"ovK7g/svVDY99q6OShWZ/fQt/BylmDqk9AuxMVaVFzHslD3iGQBoemPSa9EEJbbT8h7kscGVV4RQQKbqdaVKuzzvWEQ5BwQa/4TW" ..
	"jM5TMnSv2vjkyJTG4YT3rQgQHer+CyTnnVoG2moBJMGXPMGD2baMLQbBs208NfgVmEPq8ll6135laCc7++sFexTaDXyJeMyeeC70" ..
	"QPtwBo9uVIopozj6TamPNqWEj8FOU/Jt8iJYnSv4i5vZQ7L1SoVccJg82XgbVUgOj2xEQfqTzru/E/r6Uo1q2I6gn02LJlwffs0X" ..
	"jNcsqas7HJzcrXvWP+7+79R0I62zpDWoYWgEtoTXjUSt5aHi5+39LHuVIAMiB9aFstac1uuVazooGK758Q/o5EGIGSx2lGygkJUg" ..
	"MJdrnUOQLNRJOGAGKqvFpnJzI4492VAON53EGehPnhUDljw+RqZrDV1xYRtKqrQzVDV2ngUtRe3awPSxXd/LbBgjXBT4oYqJbgJ4" ..
	"RnRxk0U82RcD1suRHnv9AYW7Jz5Cr30HDFnKlT4QQL2Jv2Qpe6o0cSvgLoEwCVmvS+JrKKCDcAvLMupnH4pGdHAOQMw8wpDftawP" ..
	"5KFzqdN/+qwgxArIjEeBYEDzzIR/lJpjT+kEpUhpQpOLNOigr3rtfhkhUBjdE92ffkjinNls2G6OUBw4Nxx9CX8KFNO012UTlKDB" ..
	"/b4kK+vmv8aSGUPSUt/Vy96fsofuw6KdS37H5mDdHlfpV0B7F1EhPILoO4KASuvcrXMHXzYZA66uQhCu+1N9VMw10E0cdXHVxWBz" ..
	"Hi+E6mQ9gkTkzuhu+QmrMLOdTqAnUYpJVoL6tttbNau8JJvjM+OxlLUuJuPsgzaAR+x8UD9g+vlv1NRK9XLrOdSKISfyQ2/GloB2" ..
	"w5WIj5edC5jYBBc+e+fUBxcsH8tG5PSl706+6k2KnfoMWCH2vTNVptIRCuTabhq7qUK7oRI7mbD3KPagya32d+HNAIEp16YD6exO" ..
	"XrsU7dWtHfQzKDFICRx09H7nlXPWBwOFmT5FVX/o0+vuwB2PwOIwsAbgWKQKSpZFnOoOwY9teUVXX+zvsGgullT9pHkdabSJhQ/J" ..
	"CSJkQ0YliBLgO5qC2Hm/ELp5fK8cYkq3bR8Rt9wb8pfX0Psv3EVz5uMkiv4gOcXdXtna85wvsPjuyOttgqTWl6EtTFwA919xhTRy" ..
	"ZSxXz6S+FSTR6Gry31l349eKChfS16dr2Y7g7rSqk/y6yPNLjY1WLW83AFaGYOvlr45Feoww1AUYpsqxrHoLPr+84FWQZ2NYjA1I" ..
	"Su5CFJBYiWE+VK4Tsx9I1aUWtCl8IbfWdNNXd9ZMnETOV5RcQf/DcWLx9Sxf/wICVodiln0EpUvBGKGpLTdxXIvaJDG83W+aPhhJ" ..
	"smw+KiVsiLf9+rWk2F1z7tjloZ7ua+nKXkOt7A3AuH9wEn289k6a8+NSeBUhVXyUvENCxOSaXXTtTlt0NJlPKM1InlJRruMGe+hO" ..
	"u6erLk20XDI6KuzMgWEdcO7wqd6yXJpMg33eGcp2EZ8JW42v8u1gYZNTaV7V1ChUOHAd0qcgKd8SIcP8mgp8EdPZwaPShl3+SoJ9" ..
	"ggcyUUl1taonDh53a9NLjMO+wN10XUXf8bIPVfsjaYEVNVqPPpjd480bbSy0LzZwP/ZkurFxj515gsvHgXBNTBIDd0VC1Pg/NCAR" ..
	"lL8wwWeEw+ySDD4ixIEDKn0i6J9B5eaVmV5hZV0E37W3d+TepKLa491OLb1mvN6s2AlYp3qukilFyLHwgg3l+gIBwtM60yWB8ZH5" ..
	"DsY1k9Ei9Xao2EFt6OtnhQbS8xrqe/sHrCrpcguZongh6nsMqEcCZIbL68QTRso/SLVCmbyHEf4uUtXoRABc7zvJnLHIUPvCCDpV" ..
	"x+fXnPIPp2E6JxdNei6E5h5MsRlj7F/4WuROh4XnYleN8yCZo26SZyHyfKRzIsSx903QE92fGE0i4FbYQGxzuhs95YRb+AEzn7dt" ..
	"LFVsGj7o+/RaNRGlJA4Jtbw+JuRfOloSzTaxeguQ2NSPBrypPrg1ZUjxMiGUudG/aRYKwln3kP/vmVrmu7C+mXc/oJ/EqamGuh8G" ..
	"rD048UAfosr96WhxCpy4JvtZvEUSNDVvvq29uCBlBJq370tmaHCMvcGgnxFZsD+KUW3WndQH8//tIB0k2u+xT+sQ1yzvv8e840M2" ..
	"0irOP6usIdFfifOL1WCbhAT8Mr5QFeJir8LRzVRDVRASwvPXEU4ROTq9xH9041bz4xAnTEcb0HyXY6ymRm88PBmD9mUbksRwcmyl" ..
	"D7SmXBFipmCrY5dP5jKpMLJqVstLVabN9po0rpZdSNxda0mKhTmmcuwcRV1TAq0jvT13miKTugsu+4XjogZOdtmZLmK9TCmmrj33" ..
	"hxDhEAoEt14XlcJmHvsS5cu6rFuxsyicZpUVY+sYRfG7fHBpOwTek6qAA9xhVAtdFGI5UroH3YIucx447C+hiAFFEcVuHqCABJW6" ..
	"R1IzKJh910ltUufnZ6G8oc5T26QR3E5XLAV53tvmehSP5mNOfuqXQGPQKAR81ErR8N7vK9JqmNF2LeJvSXq5TYK3ya70NT3QS6bc" ..
	"VNYavcfN9tcb7ZUeyrLWNNOCTz8eO47cRYdc3XT8GCgbuEhEL4SoyVyOkpL0uu8Ktn4SQK6gyeJXrOwFcklsQiebZx8ffpjOtdOD" ..
	"Nj3JYNcJR3/3Zzk73gkyt4egvs+Sygn8q1g9u92BHq0Ax5KDjXfg5ArIu1h/l6TmymcD7Pu8r0WgzvrW9dwTemyOXtQ1vHTRTAqZ" ..
	"D89eIJvEVyomMNpji/c8nPf5M/s6nllHxuaxoIyZJDhsYpEv2xzQZq3KVwZO9TwWl7jXcWvHWzt6mrad62D5Xh2q4dI1Vlqj+S3q" ..
	"iMHoBbFHGtNzqqGPMu8l9H1xgHQtKB4XgUSAH1N837xl1UjomLztReBJQU7xXu55GQSbnorFcX7ZIvEQMKeWsG2yZXigIy/QTsKX" ..
	"gFwSvzNhpvk8uEwhZ+iVQ54rxsSQxujx6ZvmDwTUXts9l2kjR3XXEHwINPYliRU6vU0nR0By2GqOQc3UqV897Ija4RD+KSfsL1n1" ..
	"8rIT1pEe2hu73izhAwKyG6qYo1KAHdd2HZQE4LbwTe2U3RI4PsQOz37xQyE/IsDjKhA46rC6Jkf9WhCdZ5ONzfQEvxHQ+owrpBxH" ..
	"90B3QDSzeS43YzSCNSgZrK4HetAAd1T45RYd9CU3m4KW3gwxr+Ro3CPVPQyNUDU9HpD1vJfAsdxb7bHqR+jLD6z1AxL9prMspfD8" ..
	"mKsS6hxopamg+kHVBPdDxo+4yzDsfT0893EOVLA2kueXYpcCsYot6cFx3OFibogGOAhsNqK7IIywlBKfAjW4wwoPKCZK6RKR1SV0" ..
	"jXXQU7se1EgGEIebP+96UaCn4N+/v4Mjg3wO+QINTkKoNiDqrnl6a5TFDpOzQMggsa4YMCrveM5nAtzg1x82XrPBBqxyzpme1fw8" ..
	"mBqoyiFIwycnWyk8abDWl7msQiRg5o8nT7hUFmnkEedo5Bg3wx+Y6eIAFCZiItDGbj4273CzUy7cc0I+824X+x0PgPq3prw4BW4+" ..
	"27NaAZZSzC5M7cMRyu2Ahqv8D2mLf3ax6GfWVSVdjayLL6eJ2PWNeTNX7jKGw/a8vHZALEflAF9oTNXI7Fp/g4gYpdRFl383eybD" ..
	""
local PAYLOAD_P9 =
	"DB05e6amIwP9IDAC+JGsWU9Fy+VK1S8WrOfCUq7NlPtfk+J4kFuZUVolsA4MF5VrTpqHgBumZaZ7g+n9dunahGlJswBdZquLcO2z" ..
	"ad4TdfgPA3WRCbR2fxs2ZYrRK6oqgZnCj7PsuhtLk8KVDrr2JX0z8I7dPUFYzessx8qig1C/4kyBtOnW34eaJdBgjPyCbaokmX1+" ..
	"s81UBV/O5vXAc9T2QMmHOkvqQcaMPOY=" ..
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
