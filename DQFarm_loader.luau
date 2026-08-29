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
	{ seed = 3424651988, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3428346562, exp = 0, plan = 0, hwid = {} },
	{ seed = 3427864231, exp = 1788089514, plan = 1, hwid = {} }
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
	"O4OY6BbTKjO5toJyH51dktHYkRHKEkbIJoRflqpywB+pVKVgHczNHQDpb6OLgOyvO1Cd6Zy/RJVkDhfjjCB2ratnQvxGGe9xOAig" ..
	"igtX1qmkVgNIblAKzabJrtS2AB8dGO5LVa0d2/Jt/8kbULoxBc/Eoiss9MS15lK/c9w/U5grCo8vlgW0Wsiy9KbHzyWwo61xsd9L" ..
	"20DrOvxo8piW1i9TdcRNLPk3w1/8xuX8eTjAXraA3cFgVGxAy4JelTxhPhgMc6+CWJU0SsuTLgHNZ14/y13A9pStkRzyV81+hdbE" ..
	"OsUPl4ceoTWq/OIY68dCjkSrqyKr63TiU9McdmnrulamIrKmkCbgR0YEBEIiOuND+GAuO8A5TJHfuopR6LcUFNeXFvTtSBYXUyxa" ..
	"4mM34gwOT4sx2KCW+dzjehc1H4uC22AnU5Jh3WaDManigLTYxxxEn6b5OaDORTtu+gDR8pQ08s61dZrq7j/L0julchr8lrp4nx+H" ..
	"C8lMuwNxvhVXBvzXBFdP49qJBTmmHHh3I311jOyU4mce9X78mkJKqk2rPBYfd/Fqu/vEG+98NWRUCoQmIUhimJPX4fIP7Q2j/pot" ..
	"v4ogt0ZLiWPKLQXPvyfMGjXT6jxvyfjtyc5g4AJmNYBwTrmixM03E81WAeUg//m7hul6iC+ZRkyr2FoI8KrmG7sxtXsWLwXDJnBy" ..
	"Qm8J1JCI+NdAD3iP0UAA65z+p9om3sKDQdBitedpZwTOVn9rvzEAzPEQEEG+zao+OUbr3c1Mcrelz4cizS3UL3tgmHARj/3FrSth" ..
	"Jh8Aq/tOEuiTYe6DYuewQNhQo1ukFZLBzKbjQUQaFcSCXjlzBpPaG2ASMW+JrLl0iXIENMZ0ECTBgS156xgbl6ydAA/woNkd6sAX" ..
	"nw4OhATU5sLCCT4Ab8/3DF58Vs1NtUr4NZiaOmDOkGj+ZopB08NzQPPrU7+oTOJ6to4/YEfeGrycG/2Qxctfmo5osbGH3lLNRCLX" ..
	"QtOrnNdLcJbTZ9efLbwpvEnAsLtcZe48NuQQkT7CUtaIZ2X6I1pMAN9mTLlnCvAws6wlk18tQ0Y+afqoZP+34v+sVTD8n1Oi5iXL" ..
	"eHM6q8T+bkztA/D4xZRfSXnMXD4tXs/PpmeOPVkcN1wenRHutcqg3274NPOPsplc3hmId006a0GKre2RTO6UveIPOf9WjTWqpySl" ..
	"Q3lBhkbS4MIZ+hU9l/r66lWyCQZnjv2tDrvHKeGwv/68fk4ewBlfGXV6hMTnVuVE6ghVe2zQLzhiB6HjxCydhfTFrelP/7XB3dus" ..
	"pVixJFjkKBd+QMpN7bRPUD+xIrVPgaUDxx0jF3mVFLKuiIiUVcAbraU+tJanH71sULVpNapZKtG0IQoFpwdRTUQJiagZk6FB63My" ..
	"9zW01aajCB/SHLtiuDLuDFI5Ol0dyHKxxNxNoUx9KPTJAymNKMYmL8LPhMzkobt5DqCBtx0wSEp7d34ZcUHfBULbIZk8XJ6m6seQ" ..
	"wTcg49jQw8q2he7wzfH6H0BUT/3YvmihkRRaq04/bLjA3QSn/9XWtC+hdtoPb9ADy3MtwdaMrKn9c4FV8wyFo+ZNfB3BiBv2aVYj" ..
	"MsQFWIJbbNmKNxCrfODWX2R17HnPGSzNxiT8QGypkZhESnGD354sW8pFsRR4dGDCAofb6+FEcUeqthl0VJwqqnCTolKNtzUH+cyI" ..
	"8HzQJEXwtG0cVTJQAccVYjZReti94U1sWyF/WrL8FAdUgp1hlGzQzdN+bhhJx1yDOU2ljtme0NWYo0YOURNlAeUDT97kIMNkp5Xh" ..
	"1JlJf3Ag84NAwMsOtPVtaTq6etY15y4GGJFr+IZ1cf+JdFDO8lhSV/2fKvfPKzSUZVEL1GjLi0qofgBOk3aV+BDYE7T91yfzZqYX" ..
	"8ZUKI0iE7Phl2qj/bJO2po+cVcICGDsqxNvofNt88CFHmv7dAKY7ACLu2wutLBxfKhtCvMWkp2lb1hH3gkvGaXZ6wBarqRgt17DO" ..
	"8m2KxqAVY9O0fkdciXR1gJrdaEWbhdijtJ5GV9vbn0NPAmPIl0HCFaukZPJDteKUuHKugdt8ikjkp4s4ab7Anbf7E2UFPOnY89M6" ..
	"9UnNUIoraT//ClELzR+qYwzTdbbxZUcFgDMrZeUw0xXXiBwBCEpu+see5PF0ci8XCmfwxEXvOsa6kYft8Vxb9IUcjr/GYHmdVsCS" ..
	"RRdgP0ORh+du6ekvTxm5NfrqJ76cHWehbqFXUSFI0pRJltUvT2p3kHGcasSR4gCgWQpIlAL4aUHg+e6SRPFW/Q2nIxzaoLrRfRsj" ..
	"1Z3f1m+epd/O0arGz83FlrYxYkz34X9fHvwYmsGBzHOIxSH7Ltu1mQgzt9DFD++mPgnIOST/qIryKwVGcRn+2X7EMsorKgch85I/" ..
	"v0A18QGWlXg376/qXbd+5iJm4u87m4yZwqkfDuY37WyeDpussMQVbCiVG6gupbYK93Y5OAe8GobmnzvxlGwFNBRsqOdJGpyRooNj" ..
	"GHp992pBGddwX2Y0Umrkw2u95DTQZtdRWmQU8R55h+8gkFKIs2sKxsa9kfPLnzHuXBntRqVEv/jykiOK6QxTabNhD+7F+xxibYrb" ..
	"cUk+zgTauFY8Cc3GueYbZTRPfKR+DMZr8FGB++MhQYoHwv6Rhs5iTlQD6ENLcGZSVgZOjn89bAKWluos8lrrhHHYFQZXQn4upnhl" ..
	"Xvib/VqTFQ6pd0frdehZCPleyrfcyji4418WUX2e/DonZFv1BAAqBm8BtgG2NGvuCMFiD5M67k/bf7gyenihKftjXPTpOiQk4vCK" ..
	"jZdlYEo5kQYvhVNgX3wpq2CXcEG6DWptszLnqHQ0m7sTyjoy4pMnz90ub8DtfOHE66MMi7a3YBQbWxCBBgZMPFHj0zLmmbtVWjS3" ..
	"gGNVetXcrM1IJNkHKh25Z1CjTLNKxWH6mda0A2HQNYlROS1UyZ5w02gIP7xndjwmYzl7tmSg0V+jEnaGF07miTVxIf+uv7mjN5G1" ..
	"siifBr0dmM7Q94Mfpg3Q9Sh3BHb/OOJzoHip6soB5XszjlKeB6nYDCmD41C568T7mSZGIi5Wz+E/OKOokQD7HxCA0YB23CEPO+Pg" ..
	"iqOsaejfijMciJ9jK4/vsB2FHHSkkzga3cYy+MJUwylrg1SECvm/X8k7a682oYY3iTN8fOF2cR4In4DUELjnaubUZCVkQuq5Cl6A" ..
	"sErM/gVpwp0r1cv4s+oDhvCGDIP2hJIB3fyasj/c630HPkoynLnb/w7NOd1+9SZeAOMaLIDUAcbEbgc0MD3BYMmgvgfrq5YKYRMa" ..
	"jAvT5/K0/0jvIxLUpVRMhUNWYZVJWazeuKz+XQDDc4sB8FnjWUSIHxaNoomsXvfV2YhWSa5SpIvaD7esJOt7/HM2HxlVgCnQ3rhc" ..
	"D5LSodxakXFkZcQxGtdC4hTPkwQ1N3cX/ZxitLhuaFzg1vuk/SfQsIRTEGgAeorUhzSOL4lVScdf/rg2qjO2ugx2u1N+uAH3S2GA" ..
	"QXQTBshIndnlosnO9+vQM0kw/1lGXieO8Aujc/uK78cHhpqcFN79/SM8Cn/vQEh4PtSrFok6F89IdMg5CEHazzYLdFZ8CsVYpWR9" ..
	"7uF95PVJ5D4Jce39kzaHP/8FIw5HpqIKvnq4j1XkySEcnCm2wegKWqT7Cnb+CEua6nwvEmLsw6H8PEeGjtfRv/TByIuQLzB5URGx" ..
	"0ntsXgU3M0YQtzlDu/5v5wkQqikKXKthGS+DKybvYKxkqpsIvEamqfOfX6Aby1703ISKY//fkosEHV85WO+Cvv0s/5l3OLb1/wJk" ..
	"jyoQ1rVm2uYBz2vufHpceAvzXaVt6Y9ktDk1qcfBZXc+LYss9RNJO5i0iznx/4zHnLzGzGcgFJL7ZhGtKMQxuQvaIDecJvAGR+Pm" ..
	"8Dy9mpBd1Ck32bTtB6X//iN3JXe4mDSeZJmvjGXLGDzLGvz/IC5P0VtvEHq2V+EAs7Y41Dw/6xImwOsvCGelUzIF5zT7v/OX0AFF" ..
	"MbNpC+aDHEZIP8GIWGezDGhyJW3B4PbA+FOhnsGmp6nfvbCrR1FdO5OwglZZXTVZSxfPcMq+XluuE+dY0MZfdYz10YJ5hkYLCCkM" ..
	"yFdVS0UyuOXjL/fDHGm1LwCsS8J9YtIeC0AzISgCFCBsfGLXsSzPpEN3I5hdeir6o7pmv5WyduowkHMeRdm3QVGJqWA1aDLFTYYJ" ..
	"uINWq48VzBFNJVL7MsTD17x5vTHZAA0OZYawFTb4LYRfK4JvVHHH1VN71cdM/V3zD60bvfb74Shx5TWWKXx+MW336bXa72eVRadH" ..
	"CtSLwH0mKrxrLQmrQZ+b6XqZmmD5SU4nWGc3OLhIbYqUgFxmNIkr2+zJBB5fkSHvzGaclrjBHygILI64upIHDdtO+24zdZDZiuDD" ..
	"3wsli4J/OPZXXp9I/vVb7rheX/XI9YTzpI6wjrb3N7L4O2OqgbemEZ+UpL/TwPaLm3+uzyQW6C7KSSLrAL3cbd1w+T/MJrr/0+Cz" ..
	"JxTRAarFDPwnbV8mYoTB/uap6vMp/I2b2VOXZTJ3/xtZ/5ZRIp2qmbg+AKSmbCkbf2F9rCrmx04WVHkHV1Co1+W/AyCJEo87zrBZ" ..
	"TDh0hDf3aeaHL/6gXXJJUC44Nmw+1sCqYItPunUreMMnjpS6cscppQ7Hfd5qhEDDMnCIr7RbyXV/X8H5I9Q1T5LJWrlGacY9HBGW" ..
	"kTQN89n4SgH68mK+rVapTyvOqpMNWLoYUs3bhi53hoYIx7c3tthwZqvPRrEYYeNwNioUD/QY7C2u2uTalvGM2ofJoJYyiFXBG8ml" ..
	"Fo69hgFgaTtiwEVF+Z++32j6gvL+rm7uP/+PvQeIGGsUWvUn1RvXhA2GMAK/9zq4Hgu+F5+Z/wYvkWYP+7Jo7+HC1NNbLK7zXs6P" ..
	"Orl1MRJkb0xXkWg8xns+D8I0eZ44jkFsPpTdh9iVAJl5E2mLw3y+LBIVVLciTSdDy2grHwMM8pR7V/f6NYFIhkqckQiFxEkWpykB" ..
	"kRugmLGwdK81mnTYuYgXPF9jZ5sHWEPeqAXwLBMP+LOofRjNsWEGAQGYWcH6uEvHI0xDT510RewEcTGkx3Gi63818Jauyov/pVsr" ..
	"z2ArYf878AmW2PiBr1KaBpo8nFpqdQGJGRLV6ZWuCAzwqGh9PXTkH4rNzdCHG32KUwr6fP3nrcwzKb8LGC/SnrWPDsii67K9XRDB" ..
	"V3y4RPH8Nw/kQIVX0kRjgXnKFLfWrLx2zUY/3DienDbZAocPe8JvCOX8DaoFBDXCHSFmNTz6/w1C6I7mGs99ZWSRvrz7vfPmEObU" ..
	"GO5MTM3Zd8KtbFlQSROWtlGosOle+Yn8PvUWyYlE1dhk532tmA6Ce1UDYLZYjXdx9QNfDy8gpLG2UrDRDlRr24HScFbQxepWETdq" ..
	"Y7RlE3hAy79nyZ1Cv34f5zdBeE/7Bnx5ak0baV6u9u8yrdzjpb1vqt4cb1i2DQ/7uJv3A+aap1lJpDLI2IAB3Mdo2IjPQHO+vehw" ..
	"9+BQx/6HNy1y5ddGe0MzU4A02JPvUqV430bm/CN2xYbGhS1IUVkysv1ApOb/6AZzkKxEFwX9LY9Ot14Oy1J168HNPiaVoD1601bf" ..
	"Nf/bkjQ1eQ9XHxxVISfOux6YM+X0eR3nwHA8k0rordeoANry+IyNOKNoCzvdew8EVc+5U88wJvp+cEiNiX+ZVadC/R+Lt9AHlPG4" ..
	"rMLT3nc1jzo4EMqb5+H4iv02vOjAcv3F+jsjadPt+oKjBMOS680k9sz8d7YDU5ZeRNCyx18V942VMGLjWyFftWJC1f5m7NQhUdkD" ..
	"k4nk6qr3qHcHuCLJHARRtpNAZ4XIeVtWXFZte8vu1CIFoYr0JDi6QEP+9MTO/UdN2pzWqAGldS0Ch5AJsDDUric5bXAfNvFHaau4" ..
	"lRS1eDBeLHcwhfTTeSuhbrJBVjOyLghOD7sgp8iqfCVwt1YoElndFJwrdZW+zaw/sv+HmTzay9WnEZ9JZltc6yM3L+HFgjZfTSpB" ..
	""
local PAYLOAD_P2 =
	"LOliCXlPsPfIwO9mpWVK1Wk/U41YjH72hN/v0n//UCv5JwekRfKebnjUZD4lnStn/BgrGB+EHClOFa1bnVMPl1p7cJZvM/vsX+Pc" ..
	"yrO02VSFX/W/3mkXrczhnnwz8l26b3qphcdTwCDbCMID7FqcoEHh1jO24GIcRb4aytABkwzn0po88enqElmFhAvlCjTbOla5kN6h" ..
	"nw5ZHAqPpXpwAiZQuRYuB1Ilw9RfXRi61fF0iCBCT0FgcxJq+9Mc/I9TPqyVDv8yos04BptZ8KIgGy3O+qy2B/RsgKSIJASJH+Hk" ..
	"0u8eCFoLJI5xJ+T55gqgifxig6ajJOm/m+vXHQ8a3wgS3F5XoOaDKv01MbWVbxDxwOpRrLp3iTI2I4bBhxiKWNEumGmcahrbFpyR" ..
	"vKfKSuX00xeNy2rQwv9n8CwVhqiGLdsBvLefUiiCg4+jYWN3pxabv8qYZXSHIwUCv+diH9kpXVxw5uoOVcxBtrCnHFoQ3/YVkb9P" ..
	"uQieiczpNG+i+oatwdwmDil/NQAEf/A+W3E1V8oXJsE8CiBtGpuCwI5I971mCEoLtuyeimgyN6oauys4Cd2/2TGVJZGf8I3pqSnG" ..
	"U7hM8LAkpfdlU6Jf6S2k4mC3OYQ8Bl0mRWarrtLsNX/C7HPqjbu+VpF0pK5fKIWiYvSR8v98Eb6iHsjdtTwpetbLHDkwProR8e5a" ..
	"cQjZMv73aKjco1RxKjePLW5tpYqswUEL2a5lfMhkRowOZrSW5tWGALIp1yUXfHqGEPfFdLE6WsnJLNLIOVzefmy5yz8+qd3BCvJb" ..
	"cD7mQak+cqyS58yZCq7INpFoiBZhGbKSLNwId345Uw+DMKmL99XwVeob1/Et1e2EZe99xtFBlYhytuixtSFaP1oYoAqmyuiqX1iU" ..
	"XXpVjKnZ7fFvVfNqAJCvymFePWDZNS0DTVusMSJIS/k8XMUo5UgCqGscQJle43+kywMwg2FZMa2Z821qyoRIJUo+3EgqsDA8UoMb" ..
	"a7lzWGpdxCngcNy4t7TLH01064m7JtgMgmZlyDjP61u6Zp7mbUH1H93zNapayENfR2YxbeBiHx1cHnju4zYDwXvsFKeZH/33ws/0" ..
	"AOyV8OBcCiZFPFz6jPeB8O6Q87YDROSkTMUqYR+Ah421UNhfpzcrZHOALdB32js29wa3d8z4mfVKqn0rTEHw5OKogGzSqzLojmda" ..
	"TG3CKCTJWFrtnfVrJjoh41puwi7lYVkpc0Mv8Ie6CmYHIZazeDDtMEc3Aau998xqOKcWdw5MBlgb4oFrPPxlx3qEHBHGIy80bqaJ" ..
	"szO1qZamslgSx6bUtnpcObrPpAOUeXUqhOZgRERbSVzwCWUgKUsqmGp2nFF4RjR/g5ElLOOMFbh/zCtNlNR47SXk8yXqqIhJFAH3" ..
	"n8RkFv+5V37mKClaZ7kPH7Jrq79mFMep0+Df+yQ7rE1O0BNUVKlAmdS6UeA4YUYwrNFj4E35b4R6Eop7e0JLPIB7jIfzXzFC/gEm" ..
	"b8N5q1lnKz6cGUBpGqqWMKX+KgSXXkk0xNF5kmHBqCoxlzaZE/u66OFH1Mt3bLoWCcvgpFMVjDR2nkMgCOQmG8oTwsC15ObBPqlM" ..
	"Q146ivwDijF6Du5ckyJmm95XDrHMccztXh4B8FtO4lQq3EpmZfFlzMsh0goKjd/v8jVXj3HXkn+w2WigfLwVZ1Vk/+XnWqVpBD/U" ..
	"N667LYwKeZi+VRHqYK3YHmwPGQiNDKe+qT1J2BYB4LIEZ19MwyUhhr5WfWbzzWjicugl0rfTyaH2nUCypc1ZaLYzlPNIWjdZYHct" ..
	"R8AeOwsEvjWFlCJLbtTOXNU0Uy+EgSS7sSSwDKJJywlJ8rjqDrpyaiWjjzlJx4LLth9RfGqpb3EwCFkTE+W1SH7apTiiyuiEG0q2" ..
	"+h9V03/GF368Ku4axXbg3EfJgvp8ECVpTkq3txtx6u9UIuAUznYbIJz+zHMn3ss1M7yueWI78qMmCYZDsuWNC3TnudpeTn8dN7Gk" ..
	"KOdeyOmSIGUq/6D1FRYxxB6T4/AVTdl/sJLdsoxopmDcu3aDMXiUdIFYgHDpVG4Lytv7fmVbae8RH4aDTRqPaR9fa/rnYsOP7+NW" ..
	"u78eRvp5YXQNRArtLFsfgKwy2MLijuXAQnnKyFOnVlY3f9GIJQZZ29x5HUXWKabYUClpBc6whXpxvRJJgMP0tCGNnLeoO/ulS1Sd" ..
	"UCg1X1B+9NvIaaR4ocUxXABk2F1DuWsh8vrBvmltbCuNjPyZloe1Hric8zRhmNsvhFJcEyBsFEguAkvpkOTAKmCQeqUajdBS9TyZ" ..
	"7A8Pkmy30ei1KUB7ZEHo/4SYFwy9iX4fz/m6KsF9AUJODNGDiMLZqOe41A6A4edg/5A4JKIYz7WUjRJ2iPzXs6SipXe+8u10KPyy" ..
	"l1UC9l+/3O8aN88wcpYBcUJj6yiA0V/IUiTQFnm2tnez0lePQ6qZtNq4gg63EmSktuTQ+P8l4YM5CJoGAIwMHV4tr4x7/u8RjfPb" ..
	"ZPgRofamCqgMYBktIUjXJQmmti9LFQKnUnJ+n/YnebT6RHiTz+QLlVZ1q3A0dlxylwO45OQXpjj+Paa6plY7SN0AO+H1s3MzManQ" ..
	"EVEy9YZ9yyzLKbtqIVtMRx1HCBoiu/4IWUPRXAi0ozgIkYieQXbytfTcuikriZQ/a4HmJsChuu2DHg27/y61UMCR1tOJiVbyzpmf" ..
	"tUxiZTkOe1yh25z9lJb4Adk886yGHAmJm568aQEiN6IPFrlbFNpdyxCD/gDEXZgktFzFNX0YRumwRS34V7t+faPUtZpfxzIPEK8Z" ..
	"duDIlbh5iDLqc+2rLWNR7AxcZDG1rgzLjhwj4A1dzuOxvi7qMq01MtGUpxIt81NKBfvQQvdGaAi5vxC9Xiiy8l6nkNv9pAf//Vfm" ..
	"k3INSL7ubj8XFT7BamBjIO1mY+kUmR3GOlL7hzEE7TJa+57U58OnZrxTbf4S2bTH48P7fs8UYijwjrXo1+jlzeXtC+cObcM8ANOJ" ..
	"wonwei+kz2f2iyXr7NIK1uhX5tHv+VvpEJNBa5lbaAyK/pmB5m/9VlPmhnXX991OQpn/B5bezmneT+PGlzxJuczUMEXGzPlm6Mjv" ..
	"rXwOGkW50fvm3U0G1I7Mel6USEv20jaSP8Msn1Cy7jc+dCNZkNzohPW/L7BmTwwWN5PqDsUvd/2qV8mKyL3rpdOzglpgTkCLzKMZ" ..
	"6R2regFabjTGic8ca5l8bDNtbV6j04sSbjQVzgCCDaI5TMs8GSyZUQO8Nu9zikDp/+ZTAOsmfQ1Ech7JeA1L/OT+qtfrXBOmCLHD" ..
	"2x8CTFB3YARWrWAILO+eapvfbwAlyjvWT3Ilc+PZDKT/MHh88xZJQqZhDqcIH34wkcYc1WDlkfi8srcMGEJFunBZGsycvMYwObvj" ..
	"lZHY0CHdceOHjCzK7/zl/IdDpRIMLwrAqchDUH0xENuM3WglhGKMlbEixUIPC3XSosFU+XvNUzgusLBWFVkFOGVJKWjsXybsX1xE" ..
	"3Ntlkap9io3ygOT10xaeJcrBCCw0CvLDG5qhjBtMbc3oVAD2LgBkfnkCEExnVgPS+fDdumIlFX8TnkkwMRvXPlyfOjb8Mlx5rNAn" ..
	"uUq+pgNxWLTzgQ7sDjcjo4wkoQFJwjFwAPmp3vHSHuec8z6JMDlSrCgNDpcxu/0Xv3O36MDdGdSBRUZoY83/ymX+IV4ifnLKw/M9" ..
	"sjuwNrBOMkFZmMDViqyMniyq2W1VHyMKIzaq2Ga2/XURtqR5VK44+MKbYKqj/kS3JCSjnsa3yVC5SpMznZqOV00D5M5jtTi2gRvC" ..
	"DHsV5u2qYplPGS0oZRiI2Bb1Wt2u563MdPJY4sHF9GoaRDt3UOomLXxvfC1LnodHLtZ4b/Ck3LlvnxvZlPKDz1mg6vmoYsNOTJAQ" ..
	"1VYC+9sjpNtRAYIj5a2n2WZ1Tt0M/C7Y6hcv1E/7p81f8aS8tiDRzQpvvbO17InvcQCdeuNCjyOWRA46TyqGw+7rThFG+ZJAERAH" ..
	"1nR7rLz0YR62vBUbebT9chDXwkZZYaxjDoTFmCgbXBzuL+P4xKrD7eQhXyRn/wtiJHcD2cdjiADWvOGdmmwCnThepWhDogRfBCxO" ..
	"zaulaC72PqavNtu4nBAqU1ZIQoFu74fsnTLXgyVqhdLDF422SLsFNvbfW7Dr1t8TDIesUV9Zbp1AnrH9L2+2q+j36whtPf8gug55" ..
	"i1GzWXCf/bC2bxHenoB6uWagmBDh0dI2nlMPGYwjtH6/M7SywOEMrXQTUO63R5wN2mf1HHpa3PEUoaQ8rcqXbqgZ1uaO1iwRkh7U" ..
	"k3+pzWUvpMhYZrOBiWTwnCdOEq43826mVVbNAPeZCIUg6+8dAYEgSaW97Khvgt+iP5VKD2hHn9qZvNd0gYO6elIKaaQNKOIHk0ta" ..
	"2sZgrYlf4to81QoXGb3BsbL+lPSJHN0kD/Y/B8gzUL3DAL9GBKlKQf4MqCG92SbfU+CVEy5RIdPmwNso8RSnIBH7Y/0BnAm7O4zn" ..
	"sKUOLdGiryLU+Z0TN2qPUAvzXLCwWRV9eU/J4PDTP5Oga0Cd4Nltl4HNbeCinMocAPBxOSs1Cuamke9FJH/qVFLvDjqj7PilZPLL" ..
	"h0ib4SnrYSlZggNBYtASy4lZKv3sBtDQljR19z+b2zbH2lo20Q27ojKWBGfCh42g6jvStdkROlVzfx+oObm9e3P/wV42pdt/iS/Z" ..
	"530PiN+Hm7o+H4oNI/3rNzRwEOhdYld2SubC83RBbJkwgNz/hfELwgRmlJ1dWfkN5iJa0o6XOeYFhB9TWGd+TVbQy38lrB8R3ZdX" ..
	"rgTtg6Op5jRD4dopmWVlIBB0w1zdY/QGuJSiY/e/HvThRqCOeDcWlo1pX/cnis/eiKaTgYqeVAgGBBZjEj7xiAnEQromfbAXw6l1" ..
	"x/qkmLfdRhZArBJt8NNdOOi0/6A7507eCPult/xnb1hX6nTA2JV7/xMrv2wJzmwWVjrHqVANtpFzLtjpP16UHzpTlXvwsdaIKpMD" ..
	"NzstYr7aD0Icelz4X0cGwM9apPoegD/PdmCtSPYJWQURrKXQ9ss+B7GUsKRnEPB/U3Cki2UJ2AwoljXAbQGB2yqBjUo3AyCex14q" ..
	"B6P9IeRZS2Re330SJfz3GtKbGag4OibG0JPONg0JlKNy3NAgeE8b3qrmQ5YwR588FvyeAdEt5VZ7s9mnKS5dUtmzLqHqGlfU7hx9" ..
	"IZ0vsE7Hn/at5IA8sZXtRC3GT7ibuZTHf9heK2E23oP7vrdlkYtJsV31/gZDG6w9KpyJzJdntaKpDKWvkc8I/LWyLOfvVs4TZj/o" ..
	"47yIsACAJUXgj5LVWb6xKKIFsNNoAtSHjeKu4aJGnXvkw5YdlmXvhNyzCZSMIEBVmq2amhyoCiXoLj1MsFg6vrJ1+T6e7Sze7n2Y" ..
	"orFFmv7POw3mT4cDD15REn9bC69LYD4eKcKEwpZpyyYnlKNNFwuf94WIlOhNMfbmy5Z2gNoXpHh860XUxeeyF8NaH2d5NacgPDA2" ..
	"Y0sKrW1iwcYxk/9u8RprIj/+h750x9pOkcL5UAq13tBEFGEiwJt9Lr9pzHTaAHORLo9TrGLBZPBcyn8IQi073glu2R9kSMwaUycX" ..
	"n+qV5tPjyacVQxt5EXO03tDJeXMjU3LIQ+MYLjEHJoAqLpv8n5vCJDbrE4ZF7LmmBBfqhapLm0A7q2WPXz1EcMO+v9husjSgeGz8" ..
	"84QFDLMG6fIBn0n1Gi4HVLVXqxTTYHks2GbKB9kNN2knQnN0iGFJvQKd3UsC024ALGg+jQ9E6V2Gs7oB7VRwKEUDQsW4zeLLGl3a" ..
	"uqttGLqHpUC52aWwzB21i4/st5r2M3cLgt9LrC8qy4O2xV9ve+baBt1TYOT1fJvlc9aQBgNKPDUZgJa9yeJ6kZmB7dXU20U8GlZM" ..
	"5yzfdZ0lp3TfXyJMlgH/K67GkmdlgeyCtueuDSI1vZAKTOqg2kuecI2+6pMhc4QTOWHXvj4y60MU4SYoEdJcjNMZhG4CkXoNvbuZ" ..
	""
local PAYLOAD_P3 =
	"8wL6vKfcX5nVmb/DyHMXx34PPpOAVRD1Hc8Cppi7TZ+ZrmTIhCYNY3B6oYzH+cAzSz8lTTB6wJLEmmo+wXaz2TjZAAZYzM1LQKLA" ..
	"zG0F5ZwncWWGlrydmcRYoocZpAQoTns1uhT5Cb7qY46vkKC/pIr0RSf/JyH2G8QB2zEWPpxi9kz7JmtVik3B4IYtUyifrU0SpxeC" ..
	"kyCPmUxGMz5E2SEKx4RgjygPIpVvkhsB3mhgtp1kBq1DcNOW11gsNYSNuNVBnmlPHCrPkfo+i7Inyrf0uNdJAcpQwi5Ni51LG6E2" ..
	"0p2JOYceOaEG//T9BqGZ4OUjfAZw3vOKmxDS8e5oPtr5/iSsmVAszXKOG+UkoJ2jLzSSJ4SmIzA0kF+b/ra2AC1SnxyQEBfi9Jzv" ..
	"cYlV39IBFWngk6c2OwuOxo74Og5xmXVy22Wr8P/18TFOJQ0VvA0JsNJSk7ux33yKbh30IQ/rQ6bATL2Mc5HF3N/OCtzfoDF0d9JW" ..
	"Rx0z3oxJtLsnTPQQQUz4ysFpSfWlbbGyVp00DeJ6C4dNvEf5AjFNWQTKCZq/StbJj3v7ka3P2d6wFEoSQ/Q0bY1rAeVfFGQdupBj" ..
	"SpSGfIDnaoRTT9YVbv+H1AhW5f7fsUVTSH+KuA+0rCPjuRUV3nNDZPlIpPANvcEQrpuFDf7GcFtM1SKnZpDnpR8pE0QDaRqAMEu1" ..
	"/GkLAJwNbdAd+MUC5Vb3ZbCbI0vSZ0QSPMECBZlDl8O8C6h60OKILjrpEON7yUQl7dYTG99rE7TmwFJuvyGJdcQoSqqSbKqMBr72" ..
	"zg0T4snoPkmFwvUPOajjbWtodXBsFbXu1X4JW84i/tkVvnGrcnDnl+7Ys3C13qiIeGchZNnZ8IaIJQ9+6ODqOEqD539NWWIB25e0" ..
	"rgyozoC7TIzzXKrPPmwXFPe6QjTp033Jl3+WLaKaXj5IjPdS9jCrqWLS/YwCi8yAd0PXFdz1E8/ei35obJxa6LvI3oOGr//NeBne" ..
	"OgX4ydv4AqfCqXX5OEfxoZuyg/k73eHfMK75dmXt1QO77Lup1QDIBEL4n7idKc/SGyJIAGO633/7VTzM7r9473DwAHy3Uz6Ng0Ut" ..
	"dmbNn3BmJ62gzdJQJk/Gx5ivucnnnEkE31vFj5LZTugXL761+/Bwvs1RAlshnYvObLm0nG4fIdeJ9eQk8GRHuWssjpx4gn6EX8Pz" ..
	"YD70QxoMW5rOYsLuuyaq4rToRh4eH0OUDvw4TBXzjWVz0z46+yQfWeuKWka+Y9/fWxrMQxW9M22c+sDPhT57h4cXE7bWLq1GTees" ..
	"xL5RzRKHfyiOn9cAQn6Dl4YI761vIWbGlITTVzqYjJpGVzLQNYibFCoyIu+6wMzdVyjyQ/SHl0loRPQ0zhDNYnvdByszSVrUCIhO" ..
	"5TGhRSvVndyFWlaXUDObEyTYN6ypeAiPeO0HjB0BAT5f6sHMn+ae0G9NrygjK2NfH/QUoNI6O/Hg80aaSQkr4KFdEsdlwI0yeUMF" ..
	"ERQ3p7TBNw+1MnMX5XQg3AXqBA9oL+CdIY8l14hIE4cvMVj3BAu5L+ljIR+WSwtxFr/0b/lnaSAXFPMiL4CsujJ2we3IEE2HIX3l" ..
	"WkyWgML8Wjr2f79WbzoImAF2xcvsBlItcfqWgOTdECUVyDzayZSUIxs6ZIDMf6S1x/WQ/DcGQ6NyUB+GgnSAei5/ZlfxKrCokgjX" ..
	"a6ReH/cgB543DL7SGTeIIvCcwPzyUdIPzq/Vch1yKIqXLxn/2ClBSu7yFfoiNoxQX3fdCf1JLGypvcuJZ0RU5KIVhpEHacBpku01" ..
	"NZMDfVlsCnNc+4zW9wyJK87OhqyLxv5y+xN69YDsP0WdRPVaM2XuSy51wGIrPgfK7AiOXFw/vQ+wFFkDx9nWfS+4/c4bYrAP7jFP" ..
	"zAj3vtgx24/PwD0AUia+cRnOFD29wusnYmK5Kuejt2DtTmwlgxYB92Ah0LOEzidhsDDpJkWQTeE1EFOCWI6mChZvtfXsoe8Jstjl" ..
	"ggSBdjfzExnC7sNn8ZyDZonQFLs5QQtKb74LBNqBftlpdv/nRN6KtQAw95CStKaRpk9JnXAJcP5GrVVY+AQ2PPXYP2g0LdCtYHbM" ..
	"NWguB0wUIEoiQjR15lXeoFxlpqZwDLX2ehgkUYHj7UJ4RfaHU8qeTrtnQ2cX6lOY/eK6HKtzvW8cS7OEo9u6Sw6IP1k+IXosgBab" ..
	"8bPNtN8aN9Q3i9GwHYjhJ7Q6MhP7TaZcpi8z3UsTwjn4uwMDMZ2gy8xU6Wyrext8Kyoz5YF1J5VhEJBRCG4hRzLnQ5DM/IpD7htZ" ..
	"JkH9YOZHBOfxy4PK8YuQQshnuS5ULV63J//6WffGYNsiKh6WDIPjXYKbyhF9yDatr8s/hYNr5wm/4q+DUSVYUaHnuSeDSHxE0G6t" ..
	"2Fuw2XTKWMW3Nze2do/98ci/b4T+11xPpjACcBBNVIZ7YfO7tj5d+GmvX1UVPul5rPFyEoemGSl/qcAkWnNVx4JleYRPsJOhcq5Z" ..
	"jQt2Qnhhc0T4XHdJszLbrFLHjA0N+48BQPziPEwRH7kkhl5g/ZXLxblNF39iMvwcpVsqyGtdG9Xi4ddD5ZQwBLxcHxft+9NQpZ5I" ..
	"4Pny80kVR9LsdnJDljYOcs+oZqx0HEomHYPHecekDHCrFPXGEJOIs2Pknx4fLrdRpZKz0Cj19UQskINv963xZRHtFEBfZSG/jHT9" ..
	"YRyAL0K7TqspH47MwYX11jVI54pEWKfE5Cfcojp8OiF7d8WQ5l0TWdR6ZFR0nwB45uv+XunCngtjuox1GHe/AhZaKTX1lqR31lZn" ..
	"grVP0sR3Z6be3xSaQxn9vP9HH62lo76SeVv+CxFS8OHA6Hd+7tP930WzVfBmJwL0jTZ5p8r6Kv66RnV0zWaYdGTol7IGOVozbPFP" ..
	"42F1tHEloJ6AifTUgI71TmMeIma+kRHGGU8iyjejQic7EU9erZeDW+Ep9Td0b/xMjoertb0wLMm0dG/B7Vy2PDL+dftgTKY4XgPD" ..
	"Hk+CXEYsJRo//tEdnSZ+BmizO3RliVnIQ3p7avVxRB/4WFeY8KuZBdSjGPKCIDZvpe+R7cloJ0d6/l9h5rhAr80uGHEGglTM3m9Y" ..
	"HIZsz3MRIG0M8iXvhgAkbTmwzya2/s5fVx7NxfUfm6io+4J5l1OH+ZI6Wi7ZH25VFrWRiyW+CQCMxm9n6zTf4kzBxPAMg823C2tv" ..
	"mX5XlAKrZ+t4ha2h+Q8Pss48YUI2qPC5LUroTV3eX2dMA6MdCNbs5hn9m7FhYrM9I8GgPP65bMyMgkyKIUql0o6yXvs/usKDtANF" ..
	"mIL0mGF+87tKMODIxmss6t2n8zf0PqlWnqA0GqDXCXAsGEuWq5RFGJyVHVa+bSfgThbmmjEjZLKH5cwx6byoSATtxS9qR10MDfhr" ..
	"5HHlzEF8x72ncCP3XBXspgVbuKio3XCo9w3VrXI33yb/yJqC7gn1NYYmRfcQlur/T6ZvmS2OeXaa2h2PkpXW+5qDuyS+UDpVxPEj" ..
	"R+5yYHhhjuTsNBWqhsOZabnWPzbNkXETzunUz8+LNOVAg01w+Yckjza9ZxqB+0fBDRItk49Gk3JHCBwT0Tv7dlJdW8AbGjme3w6P" ..
	"ex1T6IdFDHwvesZm54Xg+owxmZwREzotxSKviWrmOlZIAuin/Jk3yFQbofZgeVtKlru0sxqmr3BrUNc/f14TuGSVuJd6mGm/qGEs" ..
	"ILv+AxfqOJVnDUve4hx652hQCYZNvuSikR8e/OcFeh2kdmmE3kFhGUa0CuBb1HIQ/yzu3R35oD0CU+rbYma5AueZiMh2OfVwt/Mc" ..
	"cdtPKC0crHN04gyUcS0AxzUNlPftBRBUteWXCyJENjPh6iWhtpv0hCHonyDu1WZxuOnwSZxlHD+CLuXK1fg/mlqvHyqE0RG6HskK" ..
	"p4M1dMzPMoib/OX45y7knNGuj09Ha7iyraBJLCqbHUR9gBCdp/eOkPMetxoBf5lh00ZpvHwtJDbXY1GUa42ufWyM8WpO5eQfBkRu" ..
	"5CQ8KUIjYF02DoCNfSUIx5g50ZSI+OpddO+0NjJpPzFQfn9XRiKjuZ2HP0vYEOZw1RS/1GPRWklQvIISK6mEqlPhfA8LQOT20csG" ..
	"42oOcXbNiEN66s4s0jTk+D9X/RQ5EqY3TaMrVAQqy60q1mcEiQ5etZhoKP9Sst9vXa0D6Runkhum1VNSKpclS1vvTXXiHqM+Bx82" ..
	"RuVHj79YzRTMbfxN+l/bz9fXJv2CFWY8E5zpBZq0ESFkO81ebpAef8EyQAD046Xzdib5NFyCxnYoZGJJD9gu+0ciVQUKhczWMONz" ..
	"T7n1hqrP8HHH5CmH9omJgEg/xJEM6BYN73rMZsaKwDjIgqsIQmNFhKRa3XZ9pkZG/9u/SeTCIDcmgSsBdkoML763HCDdW5/9qo+R" ..
	"azG6aYeqE0RwMyLqzCnIS2C2pAKcWUzNHtfw3yQY+qXxC2hqVhGJJ9V9OJUBazjHonmD/o1awX4zfR7O5w04YMJOHzvK7WYOuatV" ..
	"h17D/+temjTVXGkvpCWcrCIcrclDXWNJjK6orCQT88kwXbTm7WfxyhKmiDkyoTdfsjjUYPJ1KGec1X/moZVQKU/DJQALCzXm1o4I" ..
	"bV0ZmsLYkS7IZ+vtY3QO8k7dNalsQa3Ia2ZbS3NZr0H79j98p9+8/CbWnFCfv/SthUVbAhguOpBr8FaTFcPjf6CRKNCYCRXOvioc" ..
	"b2GhJbkaBHL6Mn+kMz5Nz8om5GDwzvmMdmqQ0OrMHH0BGnzI1bU3cercWZqwwI/4rvrfONNF3ZBz+65qaY2UWEyOnzs+SySDTMQr" ..
	"026xOpEuDIFDA4JhJzbEwkgIVdUFes+cvC7uefsU9g964l6dCiNd1cph3uK1jc/Vc7oIqQquR7N6430vrCST9/gSBfIQhp7BYTF1" ..
	"965YV/KmvPskcfv9EvnJg9QbeNCyM3uy+u4vDz3kQgEbi5e0lzh4vzQOdRg7epWLFBKvUtS2EEPUZb4mpdxiq5M71JkgJ9ziGThf" ..
	"ORVhHt6bQ3xD8wP8r7OzdhpDubnhCeLswHy9Q/Fcw0L1TMHO1pqhi8aIbiug4rZFIkgfGYKRrNvWaBidkS/UyHUyRg1PBOTjHFCP" ..
	"JdEDjqMqOr0rjh2aISVFWHYlC5BIp0dstYI9VI6+2ueFGOtnQs9fJDojfrDVhuRJ3cImefnMNfp/8m1Ts8wHxbt1+0b0W1GFx7rT" ..
	"AsKCGHs/4ZpT/6JoKQll/8b/ag/GqgUgt5hle5eN2ZIru0GzPrtdAGs3dYfSuZWyKlcS+niOm9FsOFgnT7QQ6Mt6kD83cc5jW+4P" ..
	"NDSzaPKWWReYst1BjlkLs1zyYPn202aNXFV6pk97oBCFkrQwfMOISDmsDnkbYeFSfA27poi+W9w8QZU8/aaC0DzHgfNdKoK4mY3i" ..
	"DfdD21OBTPfs6gwW6tvgfVrXz3m4aY4esidqS6UlX26v2SRgDYCUzfsXCD4i9+qU2Ue6PaOv5z+aabbQWuqlp8UxwO/8KpctMbwY" ..
	"TxDOnfjLoB08Yc+RuRS44qmRhcp0dDTkJtbL0mTexkeMEbLtBdPmN9iRHkr/NJ/VLwJFK4AJEOxPGkJz/iR7TpYU425vUUu9r05l" ..
	"1at/+bx08jnoqxFWooNGKE0UHZvREp14iCMZrV2i0BIj9DgligRV5jCq59PXReXLIlsBhF9VL4siwo8o58K94PnBojVLB9N73h9Q" ..
	"qVA1/iZvTfauSbkqA7+5lIin1HEZD2hO0UySwK794l78B8rFUn2UCaZZBFJyauQVpK/DJKOijNVLou96myDMDERNQ5lCe+ouBGDG" ..
	"HUDUEI4KWCFNp1DbHwXazA3/OtHlXp3tepD43NXlTlkxf2QCKWJ3nNKv82UU9aqM/GrF+ymSmrnPBMthKEetjkvgPOk1tb23MQ3R" ..
	"G3kuApBfOCV5lGdC1EW2iAw/0zyxHHvuhbyvd8zKU7580lVBKBAeRnP8NV202aARmo2GX18UN8/PklCWGufa61ACAsynK0goJjuD" ..
	""
local PAYLOAD_P4 =
	"w0z/2ZFvN4htAnu5K4Y533j4Xe1fjWNDXlL8nL4lTn2/IMmmCaAwekwZh/cAx4oqg5iJ1MHWBzNKtVqaChd/HJ5vXfkiKWfm9vJg" ..
	"b407zi3pQ6yk3YOevVE75wN8wnfCgzmy1Sf10hx9/Qi1cW7NICuiuHeFSFwO35IYXc+i0LYtUBzX79vVGXxr1LBQylLHX2RpVzyA" ..
	"b44p8mocJ/dHolY+1+QFMeGIzLMMiT0CWYPmG8sVgEHZJIfV/NcLnTekdz1xp9r6eHyr6QPXfjyiqtK0rSlwkLpnmTWNdHKVpUyo" ..
	"XzHyq8dE5NlDsb3TO7i1OADHCzlwvFUcRvKZg6PPXTzDsG1CZ8xmOz0nZbQQdYpEPG5qEV4So5WBXq8glSDyhzFnr19f+5uEck7K" ..
	"8We57TzQ28s3oe/6fbnPk7Ca1Vi8meDohO866VG0ThMhJvSA0HGvh2VsuKdfYryrT0xZe2Ta9uGTZCKn6nbS5Bze0NQAsH5cji8r" ..
	"iFoE5JtgcP3FGp0FkcZSL6Z34CctuRk30w+uf8KajBL91xzocJ4IvN57yuII5rxa3VJkBF5D0RHt4x/A2MeKuF7UhXsLUCW8SunN" ..
	"dqh6JRYMZH8z0ltQCiWQbNUCSs5vDkj5gShgQS0+XD+bfUYAu0u3W0ZuSfgpdeZ6QBUTQM9YPvIraJQDkGQjAjzaB9ybsUAVe8Ov" ..
	"Cy+oqfYIHGMk4ypGZW6yt7Uq10J6FTzeA45bMIN+S8SRQeTHxTCsvWr8XDkX2IOhld3v3arWK8F141LNRFLhzs0KVMe1b/5inLx8" ..
	"dEGNjIEXs4mrKWuOHCFm7XCCge+EZjHdgnnz+lRdkIVUCmzJ9RigL76bjVu4biPjF9wHUG0xzWkvZEUyh8iU3R3poMPA2+doqr+U" ..
	"l8NEVa0Tvd3/8uTWI+UrAhKgR+fWdzxHmNkiQmliLG0ag7VoLsx0B9dMKnmxLOu/S9DsRiPVA4uSo30hisMBtvNLs0DqoQss8Gqk" ..
	"I0YEopTahoAmY3kLOiRhJtdjfuy41mZyQdxtaXlvKPFwm2vZSlBhGqA4X6b3z1jcxGolML6E3rlibjHvRts/s88hynkGWwHu8zxS" ..
	"9XZLCtJsc/61kBr+vVDFAimjSDvhsHrSToIqbF6LHg9sh1UlAubFmFruA9Qpo/32mWsK3CUMCWEr7eUOAUyP+YCG6ITxKnPnmSKx" ..
	"Xb77d9NtJJT9onagLlBArHhAIi8MtCWZu3hhfGTVqGjyPJQZUtA1kIYo/3Y/twrJ+zM4NraCDUCLkF8yBsjKjFEhrqnTeIEho02j" ..
	"xD0j4neYjX/xZ7euv92ZMUla3KdL1LnIAxTmxYq9c9lX4gw8+90McQIiMplzk3g8vYW9lPXYCXTUmuv+esFfVdR7XaaCyF6HgPtn" ..
	"vzR9Yy/9dXwlAYoMCkcnSm2sIZa5uaFFw3dgnlA+80OCn7DBsYtAa6HVijGow5tl8WOUF2JACC/RBMnHJbs6DAsBvKXRYyOklSzm" ..
	"S+HwAN0nOlw4Wj4CXP98XmI4ULAMu+QVuU66z97z3ZA/Zg6GFANe5olo34wE5WGZLfpQQomIwF4GX081Tce45j9Nc4tBn8sycs9y" ..
	"eDl7Yd3Q6sl1Nq5iHc34/IgJlfvDYkTtCiZC/ACpUNE26WLrBq7Kez/UHq3HofUWjO99MxwBJv5+rS20RwcrJT8ySILk15MGxeWI" ..
	"nV5wwHWbbN+Rv/8WwTCPvQOKFhzCjzCPPI4SKK0Rrz+0j/DVVK4wfGOfHkbBv1mxYmE1vrZlgvj3EVfG9YeeRKXuqdWYQA7kiGRi" ..
	"vS/mfOhzxbH3Xw1BjkvyNvUiHGK8oql0PFJjXmvNDACQnDdNrckBQT3hSYf/gorp47Re8iQnHeNRH7gbmqkljZRObApAbhVtwUAi" ..
	"gVYaT2YX38zbPUuqK2xWqHXvqb6hHDEIToyJ+rbQkx37dHA0vcGk+XRjPxw/eXqlGhfY4/oJoi6rmyZBT5JgVF1l3yaYyCqmUzoE" ..
	"Stje53eA4XcUsVh/oEtd88VKRtEdQLvKnK6FXHinLrHJgw3xm0xnlybHfnWM2QJR08nA0bFDW8IXH1T+h+GKOUzRmUfihZ0lqdQM" ..
	"LbA1lU3gV2sTONNq7opWD7rG/2wYE4Kv30U9e/sGW6smtgTRfSqD/h9P2ZoD+KrYqZcGOYIcCz/cPudSKsmrTYAifFXW84T1P4TW" ..
	"ri+CM359EQNI7yNLoEM+j31T7QyPULagnFnSDvmHYbSuDxf1adFUbcF/Twp7bcvqL2j10189txZ5YiPqr1FGO+it0ARa1X5T3OjJ" ..
	"Sne5cXX3SHZXCHtYnnIP0JUzGcX8WWvO8lhShJfELsi3nxcXcBBZqVVgW5wIj8jBYTzJH+5Qd0q0hhcXbg6U55YcGo6gdVq7It0c" ..
	"ndqndjt8WOJeMtJASj+T1ZCe541cOvGP8M1COq8sShrA8Og9h95BWfm6Qk95IwSXDKa14s2Gc55kLOUK9KfEB3FNzyDPhb/JcBI2" ..
	"UKAuw7eTG47gh/fRLdQL/ajixAfvjYhoMwSKQ45GXlQYQcakrdFEsExXX6bGVOOMkLtLAwJxXq/bj3ouuFttAovVSUUJFMHO7Ass" ..
	"w6CFykmFQsdLkbl/IcbnL6SpYqx1CHaUn4fHvSS6/WbgtOj9I7acrOqrfwEAs6jvkzMXbv2cUMahK5ITgyaxIppfGQ9f499NQxku" ..
	"tD1uD6uuMf4noTRDsEnzoqR3ywAFq3BSutdZ0EXtUUMU6XvllkBPSQtwwk04bFifnnc09hHifBzKDlBNngVDK4cDnJqRa/NP4eX9" ..
	"LBBMC40Y+Yd+/MvHjTC6xS7S92ZJQUvTRpiZgvdX1QJ8b6Dvgpq10oYt7gTbWfXlLCaIEKtIfzq0mBwxWwpwxtnvodGHyWyy8OUH" ..
	"SbdPxIC5EBucu+5JybGqhPvw2GDmzI+PhAVgohgKJQ2jRad3Um7kOQw2derp8qLvp+qaQN/0TPP8v18gqzdQFRn+p8F0GCZF5KAt" ..
	"iWQmwVrrfjXAsQ5uHm2R+ByoUHjhloJM0hyJfYzCoMCwyAa5ln63kMwUo+cMZ2LOn5M7hhTKSxMbrT3FZRl6agyC+BfrP+iofpbC" ..
	"J//iwVy9+OSY1izhJZdlYJ3nMoTz/BWT1ZYNMZQCyWkQz6HF+JwqN/xo4OlbB8E9NRnQLN0ecjEMMiQ1z8+Hum6y9/SzrljCDWWa" ..
	"6LlIQ34EjrguyLAPYdPE3z/8aMMhj1FxMq8PdiDXgrxTpU8A6ehmWRNIaaeQqHEBSVjnpBueVDTOnKMM6ABR8vxi4DCAZLFctS7p" ..
	"Fy0DTMVbIoqURNnoTbDjeJdA715SJHObPGIsQ+23xF86NygYnJ6adOrE9yifiWLALF8t16RrVDVBH+lV8Vt1nNlmvrYEdam703hv" ..
	"uXg/JDHQEGlJ/FeCE9yb8vsmHxs1j3NdBcd/J8rGk1zIirZw12/tgWCfkBCfLVAeTH7GrIv7ulDGuZ/5tF4jg69iy+0aFE4Z11Sk" ..
	"YIT/etOymIfPr9i4VEyt5Cyvf7o3mnA629nkd/RzulGGBGcueN4ORg5sPIRNFr6yvGDDEQxv4+b8wfL1HY4pNWJdOUf3LC53ovPa" ..
	"H2EkoR10i2OGQpen5MZPRqqfk8ZwyCteGpTyaf9+trrA+RXEK0bfApYuvBM/5PjmEHzjGHkLZjaiTJD21t4Pofld1+li29vRXJ4n" ..
	"zFEBsFJgkQy0L+oJNIiaXJ9OU+3xo/nzsF1bsvQdABkdXbh+72AF23phVQAdduhofedG+v96abMegtjnCAdNYSmOzPVcBeRcStew" ..
	"EpURP78CSmXmaM039KAsh3PWU/fNtYstNNpT/WeV0ADwsgfrgBsCsigDFSy+r80iA2sBsBp6vZLPzuhpF1BR4Mk7h+i25sJUyuhA" ..
	"TH5uaaXPxG/Zjvh3dO5KdTiqkMmQPvjdZC0BsGBSSp9Hz28shK9Mt8UtDo4zCyI+lc8iG3IyoxT0BRpPMc5M8uNbl7PudPtQGGF6" ..
	"jMIfrRcP3rH0efQ3yB/Ujrd2ELWmw8Um8vqjryxDnaxZIsm2AYazLlD7RiKz+W5wZ/2iw3N14T3RXenvX/RMX94TeahI9SY+Pw09" ..
	"k4X61nAd8Z1CIoIe4TC/Z8jgnyxGYofpnLmBZh0+WSh7lQ3dZKzLzBB+dZTZHz5vRF5mLyKoWO6o6VqbywlUn99tMQnAlW/zvecs" ..
	"75MqbVPIlk5LcPwSQais7gA+cZr11iYW2HKySW2lyx9j4XRCLr8CX3osNJRNP8LFiHDnC8kavvsGLdGhKhu9JBD9MaoeufsncmnL" ..
	"kIwVXaiXmpox29Ux04pugZ4d/K+BwN68zfNhSh1sKrBZsbOc7fTeTtqTS3+DhomYdhle/XmEak+N5ChUY7P+af/0b5t5IZtLuTDm" ..
	"H7WGzlldBLXSEBrpz74HZ+IWnVOmSi/xEh6Ps8MfCC3adB4V7S97iPxVoRbnAL1wyrR1jMdwleVOA7rJssnMeV9ZRBlK+toju2DB" ..
	"P0Vaajt5k6TCBbrGGJheKGvG0PDltqlIP4Bvj8i2YCzt6bMrW4h7zGXo7dzJZ6F0UArZXlBE0BG7vnEltFPJ8QHKNRXpc6TSQ6AY" ..
	"/PTfClVAhD5t0tLeOspkHfSqwOQo1LvT8bwJC+sLDWMluhCgv/Tfd3yhUlEYGTueTLJjsZh3AK+dGj6Q3N+cKHt5QD3frhHl8xZV" ..
	"7Z+FTskIbnQVjsdhczBhmFaRuuEXqOmNgt59aEjDuXyn+ZsWvNlF/dHwZp1KyySeRGg/dq9YRqxY++Xx6rtuNfz8SI9fGq16duMK" ..
	"5krbpk1JquDiWP8AAMSESdadauwcdkYvEQ7i8sN2JX+Xee4EopevMi/RyW63MBjOVuXXMNTY2GV4vohbKePYGhxpsM9yt4xA+CdV" ..
	"WQnFIApgJxb8HvCqHqQeIIb7nrBfhO+YdrRdAkbzsV4cS6D1YavJqF0LMKUT7H2U/weVLxTXFY+OulLzCYZPTTLLielTkfDRfS27" ..
	"pbE8m5lLiHIQAAFvqvycx27RNhbyKEg9xRa87+If+OEguSO4kC+Xy6J+7Axpc2Q10THUYh5ye/APZtmZ0TSaaQr60sdSbUTj2GCv" ..
	"xP7CynqIXY7zylPX7ogIu830COOtfnA5mMAIGBCZ92JORPwtBTruvi2OT2L+XrSnEp+m/lEYYH9z8kYpavmlZIce63/aplg+YK91" ..
	"+NAHQTDaqBT1D9t8UhJqHVzYxClTi6MQW6afWN2i0DCugx1fnzFv+8q8lJbCn0pbs3n6JMvlE81H4/XA8u65u5z7ETTKm4IQiw8u" ..
	"/2PR2jD0g9ypQ0BNjrhmWxOT1MCwQyBCFT1c8Rl7O4NvJ8uC1NcrkOYPjtFq1SXrv35dUn93mScSnptGviii4qjKwDb1nYjHpnMA" ..
	"7Mpgl1yy0m/lV9QJERNDEOSjG63mEe/x/elALv2cnEzARoJHDcGjl7TWFz83yBCU8MHyPySxexfSX0/xSezzkX5ysQu7XTiIZZyd" ..
	"LK4EVGR2F1gJx5oVDXz60Vd8ZaTG3+GKuURJXnyG7KP9BRRjbe/3+gqdMMXHcz02GC9tDejH21SD5WiHGiftnA8NaVDYywhDIoNR" ..
	"qon6d4WftGRWE7pWfUq2rUcNzp1iyyc4ytti6B8PH/whsbTCnFsd0IdJmua/affZXVCRAM1ImpWQbuDk4VPNcY6TDyrNyvDfrVKQ" ..
	"xv5RH1arQHzxqMbZNEuaFRMUH9EKKmKJgoOq7VH36wGusidEfFvhxGUdomsRhtrpsL6K7auI5FvqfK1HwZi4SB7kgP/T5G5Pkbah" ..
	"5wN/uGUjKwoIjplHWETmKL1MXUwfZgPeB0jtYMJsFMfjNwTZfdRUmCgfMH3ahBoaeHJfozgAM265J5RZoSxEWjY4683FE9mTDoW/" ..
	"fDVZriS3mP06LR28i9AOMc1wXe58rams5Q9vOYnMDaWGh3dNS3Cz9G8WHqcz2VSjDHv68qWigu9zRD2yXbzhm8F3ZK0692aUQyDS" ..
	""
local PAYLOAD_P5 =
	"Fq2zXCnnpU7fsFnuSbKba+nWntO5LT7aOR48pD1a7EaHyWyuO0MG5eryHbegRT0uCh5sQrJUHR01Oitwgp+UUqexxCA7UB5p8wnV" ..
	"Qt2mFPGADVwRG5v78PrUiG92RMzRWav9hrra1T4wJCGbJyrMZl5VvnTBGXffxujZ/c5FI3safGM0qa/rsOpPrly3oNB5N8S2ugQp" ..
	"2gw4Ob6VTEP6N///LFZ9yCVJtmZolc+pLondvpzkS7iSfFz4AERQAhljaQtWAMcE7+pYIVlMfPkntifSWMF2eOnO4oJxv7/2Wts/" ..
	"PFZ5+PNx38dS+tLOa0wP15+Dr3/FvtK69uezHi6Pn3jHGMW8ffY0r00+PlsuRjJu1fEAKvYblQGLk9WlUl0WZIM3xqzQUrK7k6cv" ..
	"tcN7AbpwzrUCSPhFYjNrV5B20gu8xW/iAYCp3/86qMW1mwpXNBGomZZktvNca2ZQtpgZVpGkQkVGe2NRpVEKp7BFN8gTF/EjrM5M" ..
	"DqfgiMHEqKHv2PRd7SbxAlV6N9qJL1CjDxLUykeKs9r7jcfwU2dPjA47R2Avq+5P1RKAFnJoJ7kHxcWQVtDJitkSxdFaNHc3L2Q8" ..
	"MbMviL9xZAMiY6W5Y0LTSFXNoIMWQr7wbJ+8NU2QbGpc/v+m5N6R7rNnb8FVXz/x1DjplXufTE95hZMcpPVfiJyRZ87J5vIjl69y" ..
	"9POuHJvj5rMalxzWFy1n8urmo/cH318BllXmADqLSpJe1mip+6D42/9S+6cG3ED4B5Y45oCCgmeiV0vEdA951TwNgwKpNQRTPPvz" ..
	"e+EkivB+Tdj968Sh0hf0caVHDpr8yqcO8yNbgCHmUTa/Nuy+MgKlJcNZSkWzsx4WSSicTR2GOa4tUdCFedCA+Gs+V8FPKTUdsGQd" ..
	"NR9PaAPibNevAN97utNZ02PWTXOG3BmG/a4bOpNevcgutcFUconmGKCXXjO0VlMeanhW2AmAmRZIOH8OnQ3HnOLBvQ4b1L/Z26eW" ..
	"I0iporG72X63ZNrHJ1cde1iXFFsNwHtgxgbZ8W+EkmO+lRKDBDP/fpferiTGeBm8//AZ2xozrN/uj97IK9phKGN8D+0iYFNXM7Pt" ..
	"Yg6TnSwSFbhqFXOWNh5xkrmlSzfb+evEK1qGQrii6hkqbXxz27XTC2hCL+ApulDQzX2KXrNjvYYDIGkoQydljl7a3Vvl9yH9XpdR" ..
	"6uH30AS0qKizhfSTn3/JiouF69wTyx2Gq8r/1Nt7gb7Osgl4OlwpR/eeyCCIlG/lsTYYaGrGfBIXLL8gAH255G0w5NpMCGoXiibV" ..
	"4gIJ5ZKIP4o3G5fEUpXhRvZjjse4v5xAA1knxO3e3CdALAWz09Jwi+HG45T3T+2Pbpd+QvqU6LxIZ5f80pNZizRz9jqToKkxnq/v" ..
	"/gjHqKnNWWs1UdavUpix3kGRcUgjqu0mM5LeZzwEq6K+UaQ/bWpNu7mabuKUG2Hj9sA4JLPDVrzi8aZM+IFHnj3+Vq5ZQ0Dd855E" ..
	"fhLSsXqSmUWF2tzjAq9dOrDl9L4QKJTBjIvrE1TXEfePoRzROlShFtB0mrkhfyeEIJcDhboJ86KdkCysNzm1yF40zkde6YoGN73y" ..
	"NLs5RQ4wKTvw0pq2OWDIaFfCbuZantGOk+W11yzt7r//jpAooUJgQ8XzLxATd6wHv9LXSoUU769Nm7FIEOui9y/tj1PEHBB6Lj/i" ..
	"nAb6p9J6YIxaOd3wVpfZ52gC4ecKMX5HVGYg0XLiYeWuupEWvucZtsFJrxxpvAZ5w5SwvfuhKYd8I+pFG0Pq6k9kQNzi4TW5SRf8" ..
	"kvhdWW4Bt5lGn3RuvJGSbbcoklu43nkAknkBJET1pHajY/A7XPTl7n6hbwAkG9gzaR0ML8eE/L7cjtF5p6Myiz83syueeqf00V6v" ..
	"Exh5xPu5BRLQw0jv1A/TC493uqNDucWaoFU/F/+a+OqcuJk5+JZVnwHQwXplIFt8aTqFn5MVLAUREUBBXxSK8ew/pbhm/oGLUtRr" ..
	"Lmr7sUvkMGKsybFLD8XO8l3RO9ezucqE9YPGLUEBu7+yJk45Ks6XX+8oN/b+ceOKjugRvtdl7ra8f7sRedNuP/q1fD0NoKZYseZP" ..
	"DKQne9V/dfHq4K9eQtdrdDtN5xyTOhw2biVwODIJoWqYy3HoJ6O0Hf/PW8MmRm5+IyZMfQ27KGXTRPojK4O9cBIoyRUyQDDUmOak" ..
	"J3tvX91sFCfRYkYqNrwAIdCXOQ550iCJWfoIqA+7qK9NENiUpB5JuRhrEPq01Ig9iksCbXlJchqcV5pbkj0uJ7VI5pSJU+9cwI2b" ..
	"ZOlswfFYFPyufWKMEav+FD+yI+9DoNlUWpS/kjOtJVhkmwUMOy5ulW6TJd/1qfaf4BfJA3VzRwJ0GJEO2KFNCwmuDvdumO2uP1ez" ..
	"b5uItVleaUDUfXEZwiuXz5LN3Gl/kS12haVEBQaI5gmxpcMtPcLnKtClk5LPItdhYeBZGxcYg689lC/Ud1a4RJT2I/E3G73LsWkk" ..
	"nOnz8E3PnEzJPzN8d5/i3knvroIZow/SNFM35brv3aMZ+yTbp1iNIKGqD6SA8JfarUk3GOIhN4OFBjaxUQUnE+xIkH8z+YI+RdWh" ..
	"xcxmzRzopqe49W8FfhOhwmm6+6joT7dk90qJ8Qple0yftvT5Z8VsuklknUqiOkMuhA9V7Gp9OzLSJGysVtNEtQT1m+TbjuNgHISc" ..
	"dIrcryPlZKY6C2Xsa7pFh4Brg7oEfq/wEkyujy6DkWrMrGkZvVhZSfiL4pyLpkYp1HHiQDkeex6E0K8/D6BjW6Jr3156OijvfqbF" ..
	"6pui9QuY3VGcis823m+Sn0eDaoL7DXWQqURy8a2OpKD69URmIeE4WcHqlmaj4duLDotT7+n5kV43oa70rbjvhIqbFARJMg+vESl2" ..
	"6c4IIjAKSs42aPFHGmNStgerpi4I/ApPnBU0g3WyfR71XVM6b6h2er7WAdqzZ1iXqdOoHX1KJLhAvWLk3zxSP77owKWBT9Vr526f" ..
	"FUGkPBMNd8mlv8X3WKQec84fI+ALZuA4IGN+grXBBLksk19fYcebArpWzjYP43ID6NxzUitIcZhlNyX+Ema9JkfJRxaMIe7KIvtc" ..
	"TY1uBNQ5YZ87viz3fhUlgwXPeHU6okg60aqqsiGt/YkDU55zLTNkQqeoYoc0BLY9TCJXpKydXUUpEof1uaYj1qLEQq5e2R5QJ8bY" ..
	"vONFMMZwjIc1A/dkjN8eqVspyU5CUO8KP5emPLUttYUhbuz/c/z+cXjg6YzGHHwf5zg5mU6f1RpgBqcsBNZ3Ox3LXbFq0isutsIr" ..
	"z/KH53j26txZPWniJJmnT1xDa52PPS+xr5kixczYU9WDZuEVzWoDCiHVrO8Eon3YKsVXw3l6JlvqbPxihGmPGojtVaTcYPNBsBTX" ..
	"E1BFDYh9TUseVAs5IKB5lE/KsMvq0M7xPuhBY5kUGnMRBnxmE8XR9sNl4R5jDsopzQFR1uaPWKLA9AG0mKWgNsR6MEcrt6WTrHjw" ..
	"ZvPuGb9EUhrUKJnxVeINmLOYLXQtrzwwDx7glgDj78Cci4vukhRTl4GAas8MKWtnMiF26oASldSgC9nnwmG6cl2XFqp1gMtuGIP4" ..
	"2EMMvRygrALxUzppe5mWrh34GSDar2N9C3jZF9/WYc/IhlY0DFSNS2I5go1DhoDzJ+2ungLOTdn2mXaBh5iibGVz39MlUKZ9yFRC" ..
	"HbFKbt9OvuwSyXRG6XZbZ7NhguBNzNqiOH8oKvmOXeXc18h2Daa3aNqL0yrCoIfBD5L9DOxW4JlEvm3hbCkQppe+gcsyDWHserJF" ..
	"oRqXNMMSRFZ0/xK/B8w/QNoHrJGiMIAptO0qKd32NdDWxnKz3VLKUhWZ1//f+qIHkuXeFcTCz+oQ79BMlttF4w61v7YY8Y+1PUom" ..
	"abgttttBNUj0FiCs8iMg1AbvfC5yOetqPMxcq12vURQxoUlD84wa2ke/jzsetE5Utdr4x3DOWRWaOAyZ+R3mfqbzSOHdiLKOkhee" ..
	"fwrnG4NmVgBXtIFH+rU+zyPQ1NA41iI5lCnKhCbzwdEZ9BI6ul2fnAomaGcyW96UZ0PE1hRLGKn9cb1k7xf8wMPblLAT+a2P2piv" ..
	"2b6dRoD0lAlSPbcYuVZ234zTjttCMFHFQyVk2dPzBFgZAZBN06ylyawjGpMjZHokJGRYUFOWax+YH2taU4w9ChpVMB2j3OrJAm4T" ..
	"YyED7SEdquUjZ2Hqiedh2Rq20m9fRJDtsctbBdCtYe1jFhDfMPZuXwhR2lUER/ZX0I9Impp0tGd0THaaaofAvxHriSDozxe6jqz9" ..
	"7q2yXdkujKmgxpCniyU+fna6ILEi8NrNQicgt/2wdgkCIgR6BmaG7LeMoB50Cf4s37Piidf2EAI5UcXW3GSPvx6tc4wYfMEBbk3d" ..
	"SshsdEv+zuxcSw/e76z2jJ8yGZNvxbUXwmaB6h8wIm23rtpwtZffGi56Ms9TzRuQKDfWBBE+aUuqmeSNgm9K8BeeVWqntUcKQT2/" ..
	"kqCntzaHWUDDKu4fCEOF9W6/GKoS77o0eEFPXkVrsBA4ViYdaR41Qn4GuGM2uejGbcU3wwfZR47UlLIn0+3iS8llQimuYWoilsH0" ..
	"ob2jt42n1arpCHcyFreu7iRCGfaX/OeHgs1gj5W2B9DwhZ5hVSVOQTo3qksVlsvTo0hM97voflZLNSjx3FUmCTThiwtC8wvw/Ye4" ..
	"Mtsl9SZ4SQa3RBAVwtFSXHWUdtN83URpFTjRl8sP1/mKqTNvkm1BvYdOlR9LCSKoLZqULqz6U+5sTUuIE9Qm2V7u8OfCdI7no7kx" ..
	"Qgt818jB3cQLaW6gtCOsgp7vJ0RrUm1EBKPvAIjB+RdBkefhUuDTqH201e6TZgcdsWGSpiVPZqYOdo39c9ddH0dh5LoG2/gYHFOR" ..
	"6930Xb8eRKc3XiPnuKDba+Jzpxih11Q7bcEkxvjNVx3sUNsnmy/ljpZOpwNZ9yaDMT919nuL7Yp0RFvsz4/brIwnE5mpsL9VGTbJ" ..
	"oABdHqQD0x2oGK6apljGBRwfeoAeA515hq4Sw9FShhpTt3O4CB+KiQdExwQkV3p72WgQIsN4LUsvg8dVmuuNe33uLkUTpBrsbCVe" ..
	"DF/IbrSaVoPdmY5t1CHS6b9GRJNbyeoDk5ZAG9NS9MzAhMHHG0LtSRxBnOUzx6aYfFHPiYTP4PKrwAmNAR3X7qaubVUqL15GYqMA" ..
	"Hbt1ZX/t3qqzbHbVLPbc4Z0uWleT36ldOrGvj3ml0my60wyferKKUe2W8+3KRRr2750rxRJndvGW7kfBWG1x2ij5PE+xZdlfxuO2" ..
	"Fw5arjXYyLgJ5TjRv7aFioF90n6hDQIX88ev2VXCiKx9uNpVHJwbzKlK0vRkcQpe6WAxd77FaJJbud0v197vrw4wsf5WRf1QY+/Y" ..
	"OKJglq8LKBdY/xYZVKl2BMatZ/Tan/YGlQKhOav9N23UMjyye6hSw8WO+GZ45/WGDduTlA4n0gWPyFzQzX0tj74tFnS9P2XqtHLg" ..
	"6lmuVgJzS0Z1P+BaHKbXegwg6bjvIMuedgn8qfWksTa+kfY2X19krtTbYVbak0rtSBiqaLShunR6gtAEdTYBF36b5i29HUowfHaQ" ..
	"kLQKzorsroA7k8M6lVgKpoq19Q7rLNTLWaKMxbbryhe+ArxXP0UFxmivnyDjEB6br5sJAGPLgxis3qpJRaRSQsQHglqRb2XUqqnD" ..
	"nbio5raJ9wDpImajhbTViHwf43NxQkV8WTpRN81IExqmt5XqosDfBoOcusYe41dClWinwj0Mrcpww3obsvvwHMQXy4UHZ4uxKzDq" ..
	"PWDCfpVCht0V4+4owrHhMOxPAkcmlDvjg415Ajxx+TQuACqg1S89Q9Zr1jmTOvmSxOyp6z86ug5syr4r+NkQf9d/19MHjQLUDtld" ..
	"dd3qQsJtc69+uLjd+yeFuF2M5tMVMjbnZGtNwp5AcXFraa6yjHxzhKw2bP2iK4Aig5CZKjqkhW3cLefmfYE+wVmK6tGctIaUs/GL" ..
	""
local PAYLOAD_P6 =
	"rHSMa5IyJYmSurjx/myz1uAMSRzTnI0d2q4oXORdZd4mmuJLBQE1lfpPMIRN1DPQbzn6ThP6GUS5/A390PJ0Htm6I8OCk6yq8iTE" ..
	"p0TJu3n+4g1VQ7w8S93nLYUI1utMMawRqK+cn5BOspyDWrG0eigUfwlpQN/juFrD1bzqZty6R5ujSYaL75iCP37F/y3O6wLIesZX" ..
	"zTZECH12UNZZky5WsH343Vp1hXqL/k4yenE/Ke9JsOTs3yiufkpOqnvrsPC5qtFTSuO/q2NtJvNU8MRZD3HLCQu5HGZ9HmAeuuMB" ..
	"67JInwqJ9lppr6y4loeHKd4C+2ydj4YRFOLYwjx8mFqq7dqTZNv4odn24GxClGk2EkAP1cqwLTmlNQ7kBzs81y8C0NGALsqeY7SK" ..
	"fKjkb4sHgjLHVQ2lc4Vgvva1n8h30YcnZ2J8BIE4etlU5ytaPcCc2VHnEF1tRsTRjTv8RVd4PKERs9L20rt38bmIXaPu+xlkyVx4" ..
	"UMz4RCmLno1QtDTVV9P2SWnIBj0qId325X3yAEfp/y4v3OnVJ9gyoHNu+fZJnTshPVSHLGBn/dW3tCzXiXof8O/6TK/IWnSK69YA" ..
	"9I+JVoc9mhwNYSZ4BaXgX/S5nUdkfe7KwmPT+POl5iXqYK2ZUf7egIofUn7QMU1yePa0tlmg1c4Ejr4fWwAgzixtiO3FHrXO1lxZ" ..
	"UySU6zTk6f+UZ0PfMLFHNYdlu6214R3W9spKP/bbkm3iCxM+jmQgaEPF/fudWx1iWUpwvuo+SxJp1hFkl7t0qBNvXDtIQtLTXXno" ..
	"XO5985n/3CZ5CmWCDtWhfmmD6fG95vrEb2PwISxbQXleQ/jHNLFRfeVVd5e8RDAaiCy8P6MnjDGRXSFzn8pBWUQNdwXfgKbHxexy" ..
	"34yAH/L5Q7UK1JF1/S/d9il+IiBBT5McmyaRBbybo8fDTaL4Cfv9HDmzSxUnNtow6Frn5Al1qeMjtO2QhmhrxBEF062cd2MY/fHW" ..
	"l1vzrR9URZKiNMurJLuzPPrW0ThZg7YWRI0EBfv8ECF+jeVdEt/OCvCCEehmOgytjbSr3u5YiZ93dWqHxJ7EbSIUln94F4kX8DBl" ..
	"eHY7lUFZEYPwwSTObHOyNxzRdaWVhjbzt3Lzy5Km0NETZpKuZtx9a2ZzkQQJEixmmb1GMAHQali0l16AHCHVbkWTRSRUizbtweoG" ..
	"g22Y2QvmJ5+pEGrwUvclvGLWbmPrDQKhJN7UQaHP0rsf5FEZ4D7YmdVLmJnTnGW1hDdtzgNGjPM9O3uOHSgHpvGBTKcwINHfVY6o" ..
	"y+bC1imxqlEfcA5AwVuz5khI8b79sHF20TShgIMB03ZjPyQLDyQ4hTSfvTIUcvAAm4tRxRBVdUCD2NC96bajPD03lLd4zHb/q9LP" ..
	"EW+Rvc9JuNjadpcXuVWxhjJrePjxojxVAOUrk+o2BMBRN6xk8x7fgZHfJjpr1JhmFzNjR1mhc40XonT0Dh/cAwE9R7mi0KqbjRvb" ..
	"Rc30uEa1j0Y5wvSiC2jdgY46JI2hzgogYUxb7Hyw0Vi+ul5E+Nf0lvyTbZYFgO2Z2i3Fpo9MdrmNsssTeY1RGFbZNqzDn9VlG7bp" ..
	"0FfiYhxRUJRn6qawqMBmpucBpq9f+B2bcEj79BDOZ54IxmDzYzhEPUHXACRmkLqGblQCTkRWRc+QzzBgwnoZtKIAzzRAT1U5Kt0g" ..
	"BDm9GiH9byHtWaODhZzsaoEAsZ4yfxtHjzvc0KiI+4AbK+Lr6vjTRaA/ruKkBlSHVXLJRaFNKa9mmWIC3IlIR9RIzvD7d0frXzfG" ..
	"Z7gSv7ZotV2ctrfMPAx4gQG4zhtVQKg/t+XaQ7DVybrimrjFo9IPVHXj7FfZU2jR1iaPpf2aBv7yLCzVY58P1z06bjwQSjBGss72" ..
	"7d6fUGLUSSwF0Oo+TGfAgD68r0tCNP+r3xK9tNJV8mQvTttaS9PiCtfM4vFxoqYSlXWDZgsXqBSND1RXBfOMFw3Y4VZN/+DMhfUb" ..
	"NXOzAGp1rkdIq66llJWBrsK1S1TVr5NdcSvqT1BlAGAN47lVCZ9P4z3dEHhuRzN7sSWNehm4CXjLNRXfrQTwxdigxmb+cMNiM1kb" ..
	"W677p7pml+SbDuO84iWE/9gafCJWfgpWMDxfPx3F9rqfwGBHdw3yUPWPvod6QMHwd4Kg0x7UhYoD60Cmh6rIAZyhgUKAGTuetjTA" ..
	"zus2/3YpxV0USMSAzUFmnnkY5aXjJY677JjNCTbrGxcfmMmW6UB2ZKkv2rTSPn3iKLj+Lxd9qjX7OTbGn5fUr/7k5WCQ4FFOSsD3" ..
	"iilkXQ2Hco36c/YSCj8+l04CHZLTuDiE9ctRKIPqIPTzeal/C3dZq7iV4VJRgK9m53fRZCXTYmaxDeCqNnkuD7upelWhjH+1KoQV" ..
	"Qz5X77YNOyFkeIZkgR9Eny3Ycbt/oQwL9q0IEnFOO31kFMPodpKV0E1OLDY2c0XZQLy1cY9tMEn0lWL1dNI5TqEjlvOoahQbXOEU" ..
	"sW3kveVQg0nfyz+7GSaHplhNfOjUnxZ91oD8YULLIBk+PHiwtLPPQvS3CKPTgShwarrcEwhFgftV47Q8Z/T/pmYyxYEBM610o38N" ..
	"iVre0G5sg+kkEzFddcWCa0YiSKET6HPX8cv8yYeOEixea3M2pUmyNK8HyrDLbZtP30xsf5jkG1Viq7kV6OwKQAJzl46V0LBhahg7" ..
	"2MqUZebfpMXYuthrG7F3RW9eCVY+sUq5BtG4OJ+7UpNHiXCk5grJGFkAI6YpmIsiapsGqjxvH1xQu/V/1yMv/kROzBt1wNJ+/io/" ..
	"VXXhLYUqbw3Y8Gci5irjSXDLZbVZLaG/I3bSmal/QCIMCVTSTdRLY0W8pJHsOCLG/ebjhTJ1YFA6hHJwq540s5X1XKU3RsyqbKvx" ..
	"og+vEu2zjAQOvPpeDrVtYEfC+Oezu4ODChbVimzIXcElJcfVXkl75zJ30uJhIgV6d2J6y3jjlyiIxvJeq4EdcmKHhEkNGTCLpDUi" ..
	"r3yjRdoLKMrm1pHrqetCjbLQJN2VhAJgJbyL0WImDkGfsyb3ctyX0d90thVVrW7v72bz9vLGTcux+Wtp+Nok6rjKdxtxbOXM/CUQ" ..
	"anAU/TJyQEe0kDlC607a2HMgnhOYlD49JMlCqvR4mkEtaZUe/M4TWvI2dkP0P135iN0SCzTNCK93Tc/DHXgiDfufdyeI4AJ5n39w" ..
	"zU6aoqkFX5BT4TAJ/cci9GrWLWZN5EJ5VLXevHqccDv89Jy8MARCX56J4biXrqCxMZY5LlZIEvQAVSxX468GEbPB88Ot7P5bIsOu" ..
	"sneNCLreLmYhU9YsEHocfKBBQ1qL/ucV/RVLaQyx/QeAkKojl1aCYUOGjXfd/e4QZkzxIKliHCRExL2wLr+/HT9KS06eUg5e5yjE" ..
	"rnOM8aGgRpX0fPAcVWlyMPUOZfxw9Tbmd1bvsnP+DOqclQvwkHcqmK0nXGjaiGZc0Aw8g/dfR6cY0hMWJ0BRBIXE5nKWVnwzybDG" ..
	"9cWaziS9HtFrAF3v0EMyvz950JqYYJsM4wa7iX56XPv7s7RCSp0Q6ZXME/2X6Jje8q+9a/Rtq3PYP+YPKrbczYqajfdfmZZZLunn" ..
	"EH6XcENQIqwGT6nnetMvyVtjDfsJt57QeyszP5onNTIuWlCEVgqZgKci06tIhJ38M8wYzGrniQ0WpbwK0WwsKK94D0NrDZKBkKZ4" ..
	"XInN7eNhArNVkvTR6OUfbLBH17msRTeAURLTI2dQMuMO82ZulzH1HlZoDEKtNF6Oa1Ll0NJJL9ENOefkE+QWsTeIjRWRvEVcXC1r" ..
	"B4u9Jf6dBaWvnSKUevVbPq3Dn5jgVdzfwFiBlRcW4z2OhvPO5zu6rGzTgSpqMhPo7EL1calk5J38/azoEvZDoGtkzunaa1+uQnSB" ..
	"y/4tXyu8TRpSEJYys4KwAdsctWMu7nPgrhljagk5AiU4UAI2RiFFWQDrr2wRs52wIdBJUtdKJ4mtBZcbZASzZN5CEQVjrbKIFlPU" ..
	"3I23ETxHBcyqwnlTwEeZ4J8JXzHgqNpSQmv1gY99EoNe0wy+H0gtnWLbKQ9s/htbwMFBltnkm/FTrbx/rI7l1xTamMpUp7veD9dI" ..
	"AR9P2d469MrSGqFMafFUxdSLjX6DoKCkwB7QCkFkNWR13tCnjg02ZxitOkrVN/k8mOa9rUrXGcTKuyXtcZ3wxbSJHxyymGnBHTRJ" ..
	"LHeE7U7KGgDJdRjqzgAPw2s0L97OoqtdLFlUv976AwSOlYSm2x+FDjZ/Cw5QtpoLw9b+lV5pHLlpX6gKx85gfP+slC4xJDaSNpVv" ..
	"cMdj9sa03ElAj3rOGaNGeMn0aohEZ07VDQ5KHyWOFNKtRa7aUxxmyFndhx3GyXbbDoXl//UeDSWTUPjYCPacrle9Il7VXDdHh3uj" ..
	"EAzfu+lf498esIGAcnHUbUYnbo0kFFe73BoYhcgXKUUwmE0Kvq4HdTL0qtCC/xWzJ0oDnmFb32J/oUDoXzUbzq2TKQ0mToYZGWWi" ..
	"5l7uQd+heIEmqnp0/ohF8IBVajGkek19OK4pSeOf/G3JbVhbUWWfGREh6maMApAq+l6/jobsECE5+UJvRgvFUtAP+f5TnUA8CVDH" ..
	"vUiNxuBmAABbTWTWVS5RVFGsaAxHforkKrc8qfub+eATsHMkaXPvvYHaFAmTTLZR2CRQcneGgZjJxeP/v4410L4PqU2DBniG4Ybm" ..
	"XOFu0wF4fcVfac1F4fkxTzoeHCJRsVkqJcJPgLPzGpE98O2okWxLTY+myHfibdM2ZMcK+Z42mHnjNxZ1hsw9IuXdF3gZ9ymaJzoN" ..
	"rS0MDOXePU+U/yQ02qtNOD8Xqzj391aFA5vrv389MqW9wmhXBxJQ1eMTmSrSNCS7oox8UJu3goLES7Hl6/1Lv1eZtwKM5JjYudXf" ..
	"CnW2c5NJhmVJ2y7caM9cdZRyxUiUcgacdO0zEt9q3506GoBVP1YQRpKswK699nxxn1PqLK+oPL0J8BNWNc3LrhKm3uf2Djdl2swF" ..
	"kZJONMfYfglKID74Eeh2+OPXLQogwhOcLgux++z3T6VA1okpZu1AyrJCfwwYdlitf462sqz7Q2bp5X1yQMKG3K4Ug3cSUP6Ip7Nv" ..
	"FDQE1FcliI50ysznCsRzgRntNH3X9mkCbfvZ7DLYrSzwGhwCAFzB+1gj5kr9vX97CaRfYRSwcRa6CbGxOfkTRA268PXxXDqjQkJ9" ..
	"uDHXbWZJbQqd9QZYMr6C8srBMg2N/Jdj8sTbzIBC/r4K3dQz+BzO2BjZ4/sgckOTfx91zUpBQxtOaC4e6rXLKFGq1IqhKld5T57g" ..
	"GOzBqo2e8NiVC79ueGC/TeVCIJEvhu3fZY6ix9kh7xBepdtdo4hvXDyu0nKCsau1NaEEsy1UFvEScSLHDyxRIMgPc3ioBwI9MrLC" ..
	"uRHBFUusIVEe9ekwuny3vj/DYgXxEf9dIWsuApPZ+j67jxaGOgKn+LDYZAxZvQZzMxNb9WHtDMSEWHeJapRD9K/R/cBcG9oWSsdQ" ..
	"AmZKCnTYel3ZvdJHNKpLXvlDr6jYIEIQdqgfoYBmI6uICdzUTJj5o3Q4/LsDA/Ph7HTMZuhAE45uIfA5QoqqrJgl5QNYpPInY7F3" ..
	"I4u5VFkwxBbVfcORmTtCX7iwTsQjjDwRZXciy5gcXpMRxO+ujS9HS0o+RXiEIeNl0wv0wGYqqa94CAJm3sbnKihnzIBuMpVrUeEd" ..
	"LqL6Ad1O7ApYqEWO8PtlDMvqRdHvoiJkeqkuTp6/W+NPG4FPFP7oBeSCllpS+ZS6q7IMYFyKExKYotriO2dmctUo2bHbawol0TIv" ..
	"4EAYjkj5LyORZFHIo6tBZjApSP70ZpuJbE/xJdm/46pRkjCloWtu+fNJHdS80ATCQmdO5/5wdNUkZbksYG1+MAsCvwoAqOPtleau" ..
	"tTmC+ConubxECKs51yzoJCObq2pMJV1Jlxo25xD0zgwmcvbDovAxiFnIPNTWOkbl0CnVn4vi/WvEy0Q8r06WTgayMurU7dyg+bjb" ..
	""
local PAYLOAD_P7 =
	"QIS3UCBh/z8xnqor2Lz26dFLqRuvOCpkG8L0F31k2ago/9oHYNjUPAda3q0e8jDXoahUncyqHzMSS1ecD/YfowPL+pxqT9Bnrtg9" ..
	"gsF3NH+m53SOzUE5Fams5Osa8DAZ/jH6KKBD/ZgosmT+x0slxCQ2HWWalWxbN9c6hdqJFvACeXUg54a4sjGbzESBjT0YGxLiChic" ..
	"2FsBNNYoAnGNJ3GvXbB8i3yEHCU2Wi1jGDH0quODT37pzObXAiXjQXG6gF3gdmZo2HraNRvmnAOBs+VDcxbnX/9XJdYVInpzvJLa" ..
	"MUblFKXD9VBDRHNKXOYkuJf+UYdSI6nsOO0gPAn+9xB9JWeoZt02JtBzgDVUJpI1SjlQYBYZdsMDVf9C0JyOrYyoaBAzBwNdeIq4" ..
	"RHL6pCP0RH0ZsfMjltAg0i2s1YHDi6g5x+uQ90WzmqW9/B+zOftM+yFmB3UgTwM/tUV/9X3ffZpwkerDFOxGGZ7UJbZY5/IlsXOC" ..
	"Rlc4hcfCDAcbCX3nsbRXOAO0RVE7bcE3NDvqADTPfVWb06lQ+CRhrWoqypWJ4zC4DYZ9WCHZv6g2YXcsZdUELXoFBaVWvSACJ7VH" ..
	"tPZdhhLFElS9aJ1jDZ3AwldtWPoXWMVKiwGimK7eWIFs8Obtpk5TWe9qixW3TaPHWZPSMb6jUiYqFVDoL+rjZ1Ve81U3X6tq5MpW" ..
	"YkGyK4AmjZDkLwRaGkbhKT4W+yPDT7N6rhl5vi5wfwIBATVeSEYVeBeEWI5HLlGgnmzQejQR7zi0qd0Thg3pLbRB7n5JlWcvK+C/" ..
	"OjG3yoEIIHl9IJeeXYGlD6DAQ5Wr7FSDV1+IhfvvZ+uE70ryTGaoZ7P5vCvo5KnlAJGWr5P3rRxxU/ogLWIdECZtGjZYnEA0nT5U" ..
	"12LEUylg83msb18u6UrYePgJfL3iWMbJeQ7anP7IwIu3b8M63mBavlpd67SQfBfcP1U019e+0CiIJdi62WNN+Py6Np8GH5XSV+58" ..
	"bLHkGBo49PfaQWvdLoZYfYy5/2zQLezJ4OnFRA3cGitfF3AtMrkw+PHbKnjqRe1rVGwiYKfE4VUZpsf4NvUcZsjzsKamP/qUMjWo" ..
	"FDau6X4qrMKPoHsJTG9aV8K1JfLAcav5GE9JmLcdUiKLlS7JWrT4e94enpl9T2v0DgD/EhrRLJ3EQz7065demlqZEK5NEhdh4ZHA" ..
	"I3EGXsg+YnSIVb8nGHKsk/S30uwLii+me4ABfQ5aBzLk35tSWOSpU1O8CY5SK/j/3k/TPDDr4gEyWMKxaB3Dc+8tjmnz7LGiUCDC" ..
	"fyj4oVdeD9S7h9y/DL+uY8ST6Vdyt5eEy7KINVYHiqD9UREqEb+yVtElIpQw+SUZefHFHn9hv1682aSsQAI8ZQwIazuOA69MIH3C" ..
	"Y8HVOAzALvj9PmfQ/Yc+igKKdz0jj71o9R2ZyURwurvcqTjiY4hTlb+JAzwXsF2mMTSbMFaVMT1Db6WVvvKTgtzuI2DBdW5Rjl2D" ..
	"Nr7Fx5xkT/scoWiSxtsBkDTQhVIZnTJVLppwOK+07AGT+lJGqTwzryw+K6Pxhg/MGaKW1FhcJWEF66P+61agJf6Chq+OENwtvECJ" ..
	"uvAwx9pg5PNQobjxMiuWYvvQciKXC8be6zz7ntuRa/UfdifC1apypUGB+M1hXapuRv98K7wvpjqNyM6JfZXt9HIrQFaGJs8v/AeL" ..
	"NYN7ewnPpjdkkyPt7q3Y2br7kIu7/0R2PVwbMc2kxrX11DREYJCfTxN8V2wAyYNz0bKvzCjt/GwqyNxWJhxxH+Mt2zcRKBIU113l" ..
	"W0/H/6YIDgEc6dujiElVRGXqBUdc98B3KdliAzqGkz+WlbADgKvMnwW6JkYH83Xrh0or6XtAnf1HajhUonSsV6pc+5O/VLXf2Mkf" ..
	"+Qi00BwkAPeqQp+KWy0e2hi5/AHw7OIG4hCKjSARvHNku/1UKmp+ZeYAYbJs4XJ/h1zu0VBYn97cWfvividEI0TGzLDGojG2BX6d" ..
	"wyeG3bOhYVym/fTbEgViF0i4rzsRgK68A04nsSlMot6nDOfXd322l/+Jdek4dovYv+peUSYPayHEHdyrBLLfug3YzjzWMde/a+9Z" ..
	"IAGj55EkBHisMBdOzdPDmIokNSRbiCi3jhRElgqrSB+ukeja25oSkPmLQhYV3cTeDkECQdPX5xOM/Om7wjF2pxE/xTpE55q6lTPU" ..
	"vmd2kV+t+K65+jpF4ZQpPjM5BNOyNxYepKH0Gtc2JwHnGDYTbS4BciwoKbp+KU/icUlj8DLKGkX6vbYDcOMdmAlyQ6Ua0aAv8jip" ..
	"8wI9gYgO5FSwbdmBVwtjFKop4Op6CMN5G2OZCoZsO89D/ez54HYsaT2c/1sQAucalbhq8lUCL0G5XkAZanhdtVwvETJP0LNDJhCu" ..
	"EcBLKOenAJzpRXnNHGnQamMx7f+Sdynu/rxQYfS6evo32L9MFSpfKnqnHRRj1kkwYJbO8w2I7eM8PwTocs8Bue/0BxJrq4lJ795g" ..
	"HIv3zlUYaBzKt8+EA9qWaRSLeYuB+u30DEivLluRQh9IRJL5CbA/EfkB0f6eaVk6cGstIKNxweDUpoIoLH3w17/QSC3DJGhS8wse" ..
	"eMXhzPAj7mEBtztosDqW3CNuAMAqyTSz8Z5z5TTy3wCX7FgLd9Ad1GCsHwwyN1X3HXA+5oxj3TPsdZ+Uu5emp3gFYuDaProlcM2Y" ..
	"A70by0fjz48IUYs5gTUb8IiuME+jR0JiiIK5cM44QrdcD+/JgcKsMH9xCXSpyJm9tmeRFmyub5IhIU5I5rsQWMcVFM7/0cBZB4zq" ..
	"l+D2XVdIGzgL3DFFpFI5AJvL3KL1aHWZ6z5R4c40ZS85vxSCHw2kBXMbwvd4BJDlrHojNvZn0CHm/DlSYgM61wQSaS5SS4E+iTzL" ..
	"YJ839CxfWS2m5pBLIUZM0oRfnEuFgy04/8o0KeLWrqWpgVF37Z+e3gLXYMK/3h8omfUk3iUmpLO9IOgifHwaMIq4DQAg0cAqHwyz" ..
	"b0HghJdKd8o4jwLr2rSDmNiZC/ybI1WRhqQtbZXhaekqi427RvY3Vi0lqIVzYI43kXklRY90jNtuS/REsuPEqi+NSxerz6p2E4Vx" ..
	"8q/SulvsGTXjfWXnq6/HaploaCV1WhH7seIlKBK3auUZY7FyDWQyMOGIoE/+zN6CD5Lj0XD9OwXFCxoKPRxD1u/h7BpVhRDcxAgE" ..
	"pGZ55jRv4lxoLfmrfGEJDH+B5GrtHz5W9UEAwQVkJKOEn4zQ+MFOOUS7IuWlhAcdQu4TL4Vg4YEs92N6+FYrgQmEI4y4GyQTs4Hu" ..
	"K8zMSdtPgezCBtr9ichmC/zb0rA3b5MC7dppIAX5gMk+mefyPZdrea9JDzZqpftbr/ebTartcZAMLC9FezPzr+3r+Tg1IsjAHP/T" ..
	"9S14lKivEIBPshrrf+17rDp0XorhhSyEzGNmoP+NLv5x1OFGMHBsTWPIY/WyndUt77luy/XANqNaA86PFC11J88YSXYCTZxXetb4" ..
	"8hiVOvk56CfSd0p8tJnFClNb0nuKqjjxiAN+Lq597Xkzp7K32BNfFDGXnOq405q/kXWZIEVVkcJjKL7gOuy2BDhjyTwWl62abRLw" ..
	"URHJKWi1koUuRastk70vY2tNwCLwNKjtkQaQGcn/Z8jxyWFYIGEQc8xh0A+gfqwysjQKpj5VmzRykPrMPkDs/+zYAiM1uSqbT931" ..
	"zO6pZ9LNK52CPcewADil4WE03R5VbrGD1t9L571a4aRjFbRL3IHsOeCU9os/Rd3F7iQljqCMysQf0MmrDKL5hLqDxo3osRJBXMYM" ..
	"IFFm2qgufz9w6tkKqsoeCn1ifcx9tF8fSumbCitiN4K/QvZ4Fk4yWtLo2RPps5vLWwio1w/TaKMsa1jpRZ9HkfAdsi+6urtcRKBp" ..
	"8o6HMLPSggt9aGr79yxRWS5gt/9/IaZ5KxD0sztDwi3BV9wZF+DR9VPTVEC/u/YykHAgVyzirNj5XM7IIFSbPLEs+xSDU4dkoXcR" ..
	"Soj4UzShO5RQVy1ip1qPYdmSb1nF3TKVP0dG1qkU1oOCDBoRhOerOZv7g1ZR6Sj+zZ0DIqJcgXhLvdw+Lm0TvXJV8U9b4wzlqshR" ..
	"nKSD8K/3r4wGqVsBduTAhM2XAY8gXIEnyVlKuN8ic3aVKDs6nf4mssD3YxKrnqze3BuxkxdoxnWnLFkqPkE40VHckVaNpzxMzxV9" ..
	"r1hpxOq6dQLbn/uqX4RPDaVdSLsGr5l1jLRipVl3WZuI0m/GkHy4Lij5W5aj38PhiDnxiuiWkJY+yFeHuWc4Njs26uBMr8GE7uWA" ..
	"RKhzYb4CiK3Wgf8sPNTpuCjOECJAl9dBcfqpvGGQKrBPKBRBLll863ebk66cMOfYi+pkMRGtabrMyq5YgfOidPHDohLfo/NSQcfj" ..
	"TYG9H777/5xBwcBWNUrs8LOh2vfS+tXjM/mAheR6vvHxQqjW5cAX0aB0FfA9KrSJMwuBJyS2660n3ND6gAdWP+zH5062Tgj0xLdG" ..
	"jKyunY77us0eZkivDlywtKftc38i+vs8YzXNEtPhZI3WBD9SITRWyNV0aUw4dPgtGuVwvrx07GwYfx2AbeuWsGqjlEygvwhQPDDD" ..
	"B02UDnDDCseVVRjfNCeNAvGlre4YZYMISc7uxTzG90Ab4SwZ3udTjBNp+Sot9bKFaYL8EBoDD9MC8hJFUcEXkKZqlreq77C4qXwS" ..
	"beUzK6w3PlgvUWNAR3uQudwuLYRGPf14tv3seY46lSrxEfs+xw+qPa3GtFLOC01StgVWiaUtXy9K/IaKJ+LHZ7Vnm+FSV1g0ofS4" ..
	"YkjctZvaF49hghCC/V9RHa0ANIlTRGlOSLwxTn7NbBBQ6wjq7HFDtkw+QqWmNt0G0iMG9pjOpIhmwxyS1wrNWRSwwD8BmX2deD4g" ..
	"hJPnIkTe1T6BHhuYAEsG1rm8RPO7XbRK67yqkvarfSVFBDEgWDLtlzdNnt+2P9SKlq53wft47vNpD4dn6QcWpDTCkow/wxD6AyTL" ..
	"FggISRq1qHsHA9cUvtBDYaxT6IF8K5iImxwxuU0mhV6eyzv00nrOl6EIKH0sUV2ab2bPxf4/83Qu29N+xT+j0xXXfFnP777Fl1ee" ..
	"v830BxkfEdpcSVyB/aD27cfTEHDccK469xvJ1T65dxbFUyK5m3p48Q7beG7HMNILW6YzWnKGQnRY/i+5HcwcIP8oapWOUQs7ubzI" ..
	"WYkxI5bwGTThO41YY89mZiQ+O4++7Lcj7ZwrxsNig2sSTvNVoiDrHzjEnL92vqhloCJiaGrElZX13rappgU4MMdzW5Q04Jycjwpd" ..
	"uCaF6voPkYEsEltxf8UYwi4HWaCNXPyAK2hh9/gwPL7HF/FB0GckP5tmZdnzj622aUszFFQkybU0iP69PqfLmHmnp82mR0j4WCG2" ..
	"c+LlkJcWL+7xnAH9EEIbdGDLAjw+4C9sx2EguSG/psK07pKeoGD7BjW9hVWQA0aDPpW+NM0tPT3rasmiRL4NBoa67OdAkZWrXL48" ..
	"qd0uYLlasbaktpljru8V5oSvPmyi6pPXhfTBuyGjWPbEYJsGXGoptGHFlJrSbw4q8F497Wn7AYcD2uClSlQq9RTWMR3G9goFYS5i" ..
	"PzZ3nKhtz3HvePziXfXfkZkTk3P2z6c4GleXK3T/hzYuzR3Ieuzxjd/FN6I4VO0fZiYvtpamFRdGGinOw/Tn3B+W4CB9yw0eqZ9S" ..
	"GU3C0Y2r8voNG5PvPyqyzdRMDwplUSB5xL6Rl6KLsqejSbR+NnxEoA+AiF1zFzdx+SoSO9blvUjKuNtgKHLaoEp4+qLH/+KGkCYB" ..
	"/h8HHQqIjQ2HZLDhTcZXFAKT10NAdqsng/a89FjqvI5p4E4SM2GEMMYPkMXWGK4e02uLPn/S/R74gPx3Fv4eB92LtK4UZFVOK194" ..
	"8jiIt+SQ/l5nDMlcnBPRZOuKb/c0qOW1ImNMoI9KNlh19HqWFlLE+7PlG6KMCX/UPDj6eezYDxZFDF3Iyio/9jJbXgdBTiRGyNKV" ..
	""
local PAYLOAD_P8 =
	"eo/WnwDe6AxgvJCecFtu46ZGH1fAtIIzYFIysUYW60DspGvbnGDYbUQRWlGd4zasMXRM/NleasT5EqIocFkG5+8Sgo6l18rdUB/g" ..
	"KTpgtbL6tOGWV0OBv8hPi4pwi3bU1WZMlg1jGPxTj5PS7dIwRYKKv0GMP3KfaD1w/qEM56Gj3uL3aoNT/d2Mwb+8c2f+u8K+VLTO" ..
	"DUakpbvHUtTBjo9Akimka27oXzYqhYi200J0FWB3245ddXJ8NokxJ+NiQaEv3vKyFFdyKmf4owskpYCm+/b8vr+eAg1ESILAIHEh" ..
	"UjFILHfqDK+JHPQemCTFOv0xR4gn/h8LLGYNxbLkfsi54hrRu003fOr0oy9RQ4HSPJgN5GQXYtsQKkEWiPCKNlIqNanjp6bo30m9" ..
	"oEy44TX+28umUmdbXMzBUpSwtBHKZwwYgbBWJa7I97oUSIfkCZI9TxHOzbxCyvTXmu+S9t5gJ6dl9iV8rEtdHV7pm7beCuuC2zNG" ..
	"B5oA9uIdxBCDmAlCwiDOhg/er0ESpmfgw6BF/gw7hT1u52V+W/W5JOZ4cMAx1wJvXAAX8ufYrOpeR5uElyfp4gi71RGBsj45IqLd" ..
	"NCbPOpa3SEB4/x/QMaJPFUKvcNKnqm8fae1ts+06vRTkvRREy75D9QN62pSui1fB7T813Y9dY/vTRfxNjCEfZ6Vk/WR/nnFagOoK" ..
	"nm95apgZGAEiNiRZ0jkgSspWJrsKwr4pBkmUDHkV0t1HkDOawmk3uEl/PY0ZkMPG5k8AecWqhduo61BDj91l0xv2YUqPuFVuUakm" ..
	"Z3L9w1SRAfFl0NFLYTIz2haizyhQLX7vvqmpcodHVx+4rzIa3zgUnhhOf9rm+wJBTWSfPLNWP1jfCmsd47qMjudQcDBZ2csWO9Hw" ..
	"8yOnr1DLFcqf2h5nmcrN4c7yEdRlndz8+Yjg0PJEWW/MbQJKhRsccZ/WRtTBexiASaF1x6+BeV9MCa7je3bNdK0pV73KGlXRD7fS" ..
	"BXgDmyDi6/6TvEsO7zzA5EYx1s5xuHOacTBfGg0vCVy9mzlDTSe1Qtc/0a//tQNgvKNJByMjjvcTiuXinaAbbPZTEEP0/GD9/IFp" ..
	"+9PzUayrJ5xfcKcSEMNMWtA3TpDOmMJdsLrvkBUzErhQFD4sC4t3t1by+ixe/2sC5sQuU6iaJLig2KqH8z1EFBHyjTQLBsLSOWIU" ..
	"zSPmqHFr+YdilEr6gCMCcRks7hfAppBgl1XIyYS+k0InwLtmcoP48s9zplknVLQLizK/b8kaQI4al8q4QZn0PNOXIZg8enZl8D96" ..
	"MtuWET2PFMETOAKWSqmmBkeXBVsl/V8daHtt33CHOXXId34NmuYHSDDOsFG4uPjPRFmaJeYYEym9c5/qPOg0Mw01wvppIlZt6yw7" ..
	"o/c2uwYeGkwWx3CQZxXziLYXzg4AoV7ji6LMmIevTwo9N9waHhAyEES1yv+DVgh/8bnIDf43i+Y1KLKk9ckM8EdFsLjDXbHWso0c" ..
	"bdrBFKSFEc5KSPqRLy6ZYH22032F6DFAdAUNaITpCDgq+5hv/U5RRWwDNn9ZRtrwsVlIapTKujAMf6DWiH5uAW3rWc7PJbC43FxB" ..
	"BYUIgE4o3AHvIvnyaVtHbCQ2meaGpbPpjO+E25YjXmyIds4kt4+fM5tTOX2mFkdRdfmBJFz1+ArTOj23JEJ+KLfb5TmvxctHcuNq" ..
	"G2f7ri/uTlLCdvxqPqPRfbP1wXzDH2B7/m7Gz96CiF5NIuP2WOJPde+S2D+M4wydx4LGNC1chTYpv6iOPP+nZyjvsBXiZYkKscJE" ..
	"sfxD03jykcIgTzy7Sz97D7zmNBS43lUn+ofvyT9VVSqL9qPjpCav0QyNJV60HI7xUqE4MY2Tpltnlb+wH3ypjGx/nK9YvWtGce9K" ..
	"HnSy1b7/Pr/3IpImEI2bS0cLuG/SJZoK+weCaMbo7BCViQrPdleCZGkWoUIoK70uLCp787syqT+lUF+e2VZ42ZqMzG/DS+RDHsQF" ..
	"AhActQKhOtbMBzWEkZT8/hJvAtdFjKOpvDAYkqp/5EBl0AoIxbMiCPeRL2B5rg98BQNhKNBMQnLqGauDsSqxVnUNJN7uOAKwXw5y" ..
	"JqoQkQb0lI3vMaSk2gCpC+RNSAbT1GRj9vTC8ngske58Baf4MLtSosQSjwkwIObO+/q627GU2e9O2OCO01LG1ZfJ+taJYb4y19dz" ..
	"C3L8inmsz/8lv3l3kdA75vcDXSMOiyAU5JaxN8ocF6h/L5G7di/5Qebn7R9xdWqk08iMtnFCni8z1MRROW6pP3VgSZTqeVEt2cjx" ..
	"RPy7gEYyGYhOPES/cZs7lyfNWMN+ieZ7ThUh34C7Jg9ZCTBBZ6HseKUqJFjBh1W7WsaH1n1TNdby+hwF42xVJ67HItMgpx0EorZe" ..
	"VwK11aYo0W1lF5Z622884vMHDcm/VeRw788XnwcGA4xTffnFNYTLk+vZt9yKlix+3e94wiGEWYE07mAR2yZIqZKJEEEJ2J8w+/Ei" ..
	"Ms1LicWWan+TXxeX+l/MahWQllY1CeKOIFBh0C6ltuyVh5cpXN3bdpa7ZEk9mGYb3sQ2jNtDC8Lt8BLC00XQ4g+aafIWgE6J4DY5" ..
	"hKfZ8OLSiN4Hxu7MFvwqIHgHDkZRxm5jEGa7GZBfasb8F9heqjte8DrEy5gZ+AlVwfqoVHT8iMFlv296nD06qlz/qUsnt9e1iCQD" ..
	"EHmWV7YOSqoRuNTZrrelmoOEFvT1CDzoiVEz0N0S6WpcO+RhtH+pkwCi4jw3P/0/njkyCwWm1mBrxqk4nsUuFi+x83OTE0SxEy/3" ..
	"QS467Kp5splQD0jXCOm0vJsxwtW6TWXQR3TgmHzIk7YTbelPqRZN9KiOSQtuTT3Gk6h6mb165z3IOSCtDEaweYEOv7NLAwK0M5SQ" ..
	"TpliSHmVGs/DvR59ZyYfbsSOdUZa5BhWxNUhzhpiBsejJ09cn7FrEz7F4AQfwiY625mz5gromzg/YaYfgNYjsUQYoofFZVNS2P0Z" ..
	"/JQ5l6U9fa+TNNOAq+JKA6y/zou6It73J7ZPcab9mpDyPTK2Jng7VLuDbNtRhp4DJombWdJfckh6QKiygntslQoOUupuEJZOGpOL" ..
	"OQ03nPRUhWoxmj7LAMLtGyGzmht8gI3Q5CypS/RTeF6Tgtq+yRwNTwmGnMtK4+F68ozzL4fGo3n935yAGqjvM6NNlDHZaUf31jZs" ..
	"Cl1n9jkepW9v/vrfgT6PQreRJQ813SSV8M28AEArGlGo56RdLJy8P6YbPAk3W+tziceKjAmBd3/SUOuKLhJiJrtRBx7SMS6epsW7" ..
	"VH5cuhCOBM6zMU64w4QwaLdLr4wz3v1MCK6jcNw4GTsvlaGPz4JuOQNh9hZwjZUi0ZHGl2XvwTvPfj0eV3AdHrfQL5BxoSUD7FpD" ..
	"Kwuyn9tiuLXfHrn2EaFT9UjjH4cnRhQAZdiy908mMmcMOM/gZLuHqciYLG5cB3S8Gly+oHtbNULjXYjspyNnBL1LgVSlNJaoNPEC" ..
	"gV2S7IYEkcUt+J6RWEWe/Dz2bzLf4jwuLVUbUogfp+Umnt3+rYM9tYR2dwRFjra+/T2Y7gM4VFh2X9B9ze5ubFJbYQQsdHO7svN7" ..
	"o6LQjR/a5lx7j7KZrcZj4Y5rCq9ShpV1evicvwS1eAM+jF3BLCmczaGXREw34cWOl8vuetuEe2bXoqeLpnURwSeFw9uTuRC28oUi" ..
	"FQUGpqlD0nVPd8K5qCYeIH8Ib2mx49YWEd2Ca5mVlCpD32zIecKDRmsO+Tl3u82I45Gc/8+x+23yONtODayejD/W86upsrCp5MRb" ..
	"dHBnczJfH/XcQGCaBlG3YJ0VM73RfPH1ZbwilrHrd12o7aNRUQdi0fjruZMy+IiKwA9jMlt6l0l3Y6a/eXPvOtq6FIlGNRO/vcob" ..
	"amEH8Gjx75ev3cv1yFkgQ0UAzfAM2nWnA/xbP8ddsGtJJv7bQv2Myi5wmwjpqQ4rpqnj9B76MkaASaqQ0DqNaNNUNPBcTDKAwmAw" ..
	"ZSXnH2GY+EhC0vm9zv2jKQzNSVOgDzB5d2GeMzdtctVe5Idtwda6nJbQdCxGamCNPoEGAojHt4JG/2NZSrDbfGEq3WHc5kLZ2YLk" ..
	"tPv1RixlhaVYjssFRpQ/pZMy9pxS6O61WzafCFNlQv+Stee79FCCqRYdPI84//6sHJuLT8qJSbAPQAJwf/OaLDCrn5aB7osxSi4E" ..
	"e3J2ou9Iw/hW66dqScYVnSqizoH35vZYeyGvOXuUy5kJd8KUnSy+yFIlgFZGCITBKcidldeX25s7xnsS8KnJVxJPkfg3G8c8CXA8" ..
	"OfBsxh0TtbB3QKVa+tMCTrH9u826xEnLkIu3LoAh+poVJplGJonFTp5eFxZcVjOG5RFlQWug3YJnoF38LS7z9OEZHiWSQxoiuA9K" ..
	"mjtLietzjTxildOHI6vR6nMbvF7XEZlWaYpZOjLVFnx7P+6acxP8XORBCyx3F8+L/aTcC+oy4OXaIrh7w2FVg39opbkKQ9VGIE7L" ..
	"QFBrPmchN7C6K7y8Pg6JUwK+irJbo5BWd2TS7nUsKRO1cVslheKc2jWApx30OleTiQvQv/G/YBWIq76bJtOC9CMvMBnBYIbRIFee" ..
	"dmAW2VGEBTXH69J+iZ7PcdTeWP611HTaONYWzJ7t5dtL5rXFQlcGI2UkgbTZBrJuhIr51SS1U8W1jXdJ6zkXWvselM+PbvPa1TAB" ..
	"oQdxT1eA0KIVqBrznV6rbXabKv2NhKYae7XKYd5KX65c7lY8NRYMJnCyPYfeyM9PNdvlMkuk0ecXr2an65ZH+WGUcLuhOcaNHHiK" ..
	"ANhSjeY/8rgw1Dc1a3pxKrbZxhGCtb+uSvTMSDmrVcw5wD2G2t1lvLiuUWWeBLmBb4g0IwdQhClCeMFlCjDAn1s4VhW0SaA5ZYZR" ..
	"CzZUanfRE6W0jFo+OSDMMxArFIiv5TouSpYG5H2LiDUigOIrNNfJ1az9Cf+hNRpHBX2H7nYh8HVi1ylcleaouIJ+PyqAToZrqpXf" ..
	"4/WbinqI8m0SFH5i3qF+vuLu6j8ZVTON1e5m7+w32X73kfgX/0FVrfLoCqDWU6j5vakGq89vdEhu7M5ST/Df0Z33BR1CP5X/LQKq" ..
	"yvUjvoshLnzm9zeQXLS2/DPmoVsDtGdxQ8jT2O7O+It/+8EpaoIog5Dc5EvnsUAIy94Kg9ux5w/uJa7ZwoErV9fe75/8iSJlX/7R" ..
	"jzZ3Zix0zV83NonD7aRsIQO/IP5tKXAFwEebfMHSYoQ4fbpa3QwXR7qG0KJ2fw/e4ywM5NyY6KpmuMGFg6N+hqXi05Kxt6PKVZ4D" ..
	"O9BqvDv5zkv3yrOas9wJcPQPgVWPTNxRgiHepBIp1n8pa4a3tVcsXngB323X+q/GYV/oTAbFiHbT+TCT3vJXuVO0/y0kOBDJfnCH" ..
	"AbimXh/+ese8uVzplieoERzzaglg0Vp955KZKiw/tuAim4rj+HH99Z5uHlZDfJL/w5wk2nuKVjPyU7iCv3q9I04payApERXaOTQO" ..
	"UGF7HWMhMseoIjcmFPSysq/VtCZZPOygEF9Ybk31ADN04pRsaKclGislCh2ncatPtzjP8b9lcm021R1aR7FPCSCaJ9qU3v4a2nE+" ..
	"5lUmvVphdnauWyxxlrdaAOiesCFlkUcv1mYUALE9+J1+400WZ6CBt8Qt3hdUwZ90D9KyGz1KRErSYeoi8WEeBzF3p23KfVwI6yfM" ..
	"XZRgwSvtQrtKerrwepsfwG8u+5AJuVuNdt5hUr3gCtGFDOuBoQdOt8v/4Gh4lOzbF3Cy1meslRgz49grSQK/ZIEVu2exxRcyY3Pj" ..
	"CMMLqooSi68A9WfRmiAbC2BWFFRtGaydgQ8QoaEJKVY6KCZjIUQh5HHaR9Obs3DslOu4LxKOhBxICPZlZi+JcYEf9ndJlw8NjO4N" ..
	"jyuQRvKN2NrNk2i+4Fs4l1e/xIVv4CTYMq7AbJ2vJOATrLIiFl//h6eH09PXuk6La2UdL9Bv8jV/z7F7EJx/QUQ9pX96zi/v/nuw" ..
	""
local PAYLOAD_P9 =
	"noiOt7d0yn6J7tgmMJesg/wVfXSuGCLxiBgWQZ1zcVEhlaTZ7UrVDFKIVXm1N+cr/ZrdqoNhrHuI7mI2o5J/HJS/4mlbS7pZx9Bk" ..
	"C5qlYNCg4DE694UkSlCBTDqhuGgGIe6n/3VN2ejQpP9sycunbN4q2lZy8OrqqN7xouQ3myecOy/sr71YW0B7D/kmZmy4BJCSBVl0" ..
	"j7aVhk6TLSoqyV5CWUydLrwlAL5h+jthKq1YjMv/zyaVKiqkxNybaX90BNK05kYmKbuUxAiMVM5Wyuk0neYD8s/LLmpHT8efZyZ9" ..
	"y5/geWskfjrfvtUmBBXIKmch5XMQ6gnBJoIWbMnABo1Wj+sHpNJnWkjNJ4KtTH7rPO8JJOV6u0UnUI7/x8FnfJdKOS1kwGZCAsWG" ..
	"guciJatdX9VnC1SkPHnCq9l1OUESTEEu4a9/w/ReYzex+Agu+8SeJ7BwBKjpnnyM1g4LAin888fHU0LvCSM899Hs7hGW0TkHu9ZW" ..
	"Z2agbhMvJSpO53zI4seX0QytKT3G7uB9Dabct0YgsWwlMVgXRVSPXkHSmy/8J0CarJxmDjE/0FT7t3hdJZmTUGZOt/M0nex6E911" ..
	"OYWLmni4oEpHflvtuwPDxKUw/6OnEHrjXRV5V0tfWHsyNyLLuliZjSCScnxBtmb7ri7iYIaIgoxHVJQFXMJ8SIZKoZAsJvoHysh3" ..
	"jvJ9/qDW80BkNCAKAWgcHdSCmgW6tQxSHOVyCuGTBoMwkGrniLs8xgMzrT1lEfAW7b6tYJ5ZBBwXbYUoUqxZv4j0/8R7bFp+TGbZ" ..
	"iI7FS0WWJM8/5la8lrc5HlQqfhdmlhKhLPegdeeLRhpkzk31T4I9ew1CxLjoQHSeNNjYqNlrmXv9FTzZ55Z1MSBRFofHfvAMmT0N" ..
	"hHFCMruQYFH9146YPZtofiBjVy93727v1Z3OjE4sUJ6LfDZCpF03edPE96SZTLIf94lDv8JOLIa++5e7h8H6yHRd1jwhUu0a9wQU" ..
	"tjALr2DGX4gCFWJxqAQUOZjlS5iA9j/QSkL87dra/IP/4ilDoKBuXDYitwTe8p0wVJbk/nbxvkKpt5W+L6+57BsZDl2jqF3HjgYy" ..
	"DmtuxPtAhGBAo0wlxsXTYABKVJ01OpITY0IhtMeVJO8vOx8fLOeCdrgt0JNLckbCiZmd5HwT7i+fNPt6yITU7fcCP07sdi/pH6Rc" ..
	"O1JqElSGl50qejYfkF869qDXCl8jeZSva5R/qaG5fqKcMXEi5iwKT6OTcQ7T8JJg4o+cF6NZL0L3RSqmy2wEYVShYnpG3SSX4YF/" ..
	"txZMIVSechassjYacoelxRsBSLCc2vrOlZ6hYuKVYCq61Axf+/Oh4nq++iG5M/mW1XW0bJEdpw/BzV5RPPYk3csX3G81VJ4un1zP" ..
	"nIAhakgLrgEYVeNVW4QW/Brxc0pGzak1/7kE1MR3cbFeQNvO8bkbbNHDscUVt8Zd8mK6z7+RRoyPJxNMtNyCfyoFJpcU27RwCkx/" ..
	"RGHyIdBAP9FB51Oh7Dvv4W5nH43stv8WBtrdfxVtXiYb1kNuyAI+xuDCKe+BpC+OwJV5RK2qMxPR6/La5WKc68ld8hfL1LucqCLo" ..
	"iTvyQ/9z7lXh6qoEA2RigmPDygnpiQjn3Jup2u6+V/8BgDHovpnbS26z2svPItmpXGMDXfLXgQT7dtMfI9nbQwtLQOrur9sCXiBL" ..
	"25lRbYfKv9/oVrRetItpmF7hw2+ba4Ur9BB95P3Fii1YiURUEhAtIzqBWtstZF6+wKZyAdDMI7L7spz2n4pHnP/yUn0rLWPO0m7W" ..
	"6oWEpld3zZzFqLpAz+2imVYgZUVwxIT9nhE9ljNyEgpUKLnDHTK0conzuBfyOR+vk1hYn8yWHWPAWdEHSvoUPXFdHwk6Y5dc3eKB" ..
	"6CqLPG60cxjKL4tBWlFshDJEK/YaIxabJTqe/CUO8FOjq13z9nk6ZiTVQsrkwyNjR7i/kMzdt+Zs3oYN/enttvVXwoJGlWI6tfgA" ..
	"DWc1RHOtA3draYVrNXdq7VRzm19rgm4Ot8oiZru/5ir1P5iAtJI6XMAbLdeyaYrWZOkJJ4GB8VY2X61O1bWt5UlW7V/pBYAK6YAA" ..
	"CAOWRiSKYTXqxipQeRxsNmhlsOweL+iDAYhbchI/9Qfmt+YUn8JoEDAS3/w6LjjyoZCBHXeIldZEauSPne8qPIe8gNNpjPo7qZ2c" ..
	"QI0mvJoyFuZPc+gc8fjgMowjgfkZkcVlsXLEfEUDVxcReHZlPbB2icvVGfwD9LgbmS5kZ9lfJlaAoB9Y2fZejzzPbdCwVeu2foRy" ..
	"0jCj5TOGgitb684VhITWV7Yf0kWN+c7ca086SfZJ5dTU2A2EU72xFAYYqZgbyU6Z3xWC1HPxC68zHCDE71Bj1rbHyW7bYAQSHm+/" ..
	"SSdjah6EWwYLv2IbylPY9MIM1k7lJxomEAtrrwGsanLaPFAo67Q6BMHi4+3tM2ttjsXPsur4cmgLO5dYjEoM+u5ar1nLu3UPVjLS" ..
	"jCCmkkqFxiOHbeB8Jac3/uj5asD20xUcrwR6FqG33yXpMtbvsj3+mnrahWwjMgPJ0DBXbtRk7Nl1T+bU8IioD4dI65vfFi0uAYed" ..
	"AlQaQmuT8eSZbEnT2+iMf+7AHpQvtW2evcpZ64CERyPhYqMuC7NsCnUCyxEhf/WhLmdQvkDeDjiAPAgpiEmx56dImLOEaO1oB1vG" ..
	"FaBrHquCVJjMYzoLp3ZbMowGsDsL1hhianEgu4cATXUFhbdDmFnWtTmX4RzGo2Epjlvb2nRqKmANv7Rpo+sxiH0KH6is6p9StmtE" ..
	"QPsu4IoF/EK2J4KpQdDvMdRF7OhR5O/OFFJy2jHZRCjdXAVE/UAhXOF5NGGjJG45/6l4jaZXfBp8oNk1TznnuLRBE/uZY2biVSG8" ..
	"va4dYFdZSHlDB5XPDZ0dlsw10CLOa0TClqVotAApQ/0+Cn5iOr0Zm8r8dEmfmYQoKfONNNpbnt724or0LmCtfvZ0slppKrzeA5Bk" ..
	"aB9llRNzXQ0nYY+5Wag/JtcxaVjIsfLZF4ibHsjDitd9y0a4Uw6NomGF7RYWJMfDtesjitb+Dt5AnaEMF8ASMkk6PCeWBvXXWqna" ..
	"htWbdlf8xcuxTByNp9lFkQOb+Di8nhgUviYfpKBasuH3dlZNJxmtBB0apoDjEh7VWWiWWDLeRoJNFElXZOZrLPZ43noeEKrnX0R+" ..
	"+64jIuWoQDXHftNOKEgpX+FJe7QA3Y1ukZoDkD+/iS7wL3eJD0MT4349Ps7ai3LkAWhdlG9xjuGaPMgbvibpzi3A/8S6G1m69GS9" ..
	"mKZTDRMfCbq35Sce1vHeaUgiH2J2BUKCNdoG58cAGeyPh6JvAxp0RW/31KCC4H7T193BtqvwdYzqChvOlHup1vyfoyz2BGJUxlXp" ..
	"L0jBQrHav97HpP/rbrscBgr4J2F1VX55uoawyNvEO1H5Wne7XEx1muSu5GYCFsLLeDKIZ/A4B7LCDX/THJ/ZO0MIFztrP62p3nOP" ..
	"5RQfAVPNMJTK7gI9SzQKcvvusdfNHG2IK9fLrU8HhWY3uU3tXDTZhEs127u3ZFPI/b4HyLlj88PiqcEC3NSgKv9hlIx/byKAiYlt" ..
	"5J0M9cxMJm5+ZcEXq2KRljauRUMVge/tnP3tcq9VnA6QgnyNrBzGdtQBa7TRggcBYu9TLmi/7L5sNLQSFb4qmWR+9u8e0i1sR4yK" ..
	"VmkvjjGFpnY8KFrm+w8jP3dezhq+j+fxpptunyzojwNSWeNWimyah6tV6Ps6Ibh+EK+n2lOKwtqhY+ZrxQPxGy0RSJYEwbSSZDlb" ..
	"pMa+ASpvqXnSsQQefbJp/V6ktT6OA9Jxmb90/LpqQZbWyoQajyR/Xl43onPyTyAVKtB47EmHlsoxxGS0AlkZ6XSrcfH5KpVUy12O" ..
	"kqT4Lyp9WKcjnIVDDnurx07ynCLzNdwa1gs4LsKzEo7f+1w+Qxb1eZIy5kfd3pTX6VzbNhKCyGhlekPuRcGnUDfEUH3UecfJxpyG" ..
	"XpXF8AylT2+v89NOLHoM0edZpuQxIeK0Wb0iIXnXzURb6C/2M46f3qsZcKQhHSbdt0Y+pwbn6EXpS1PBYgSbd2XxUV0NodsgrRiO" ..
	"Rljn1YzPZ8m6tGdWLjspfdBewRt7QOdHUws+TustDLU5WgtQqliCoIe/GZioWpzhWHRAvUTYHd+DMjagLTq1y+IsWTS4TF4HiP1V" ..
	"LrHKdFmq8De9R0cfCU7wWMe84gqultesL5LYYgnaQdc/PVDSHhFNz2cMEGbbTTukytC6W6HqmpdZA0Wv9MB6pIXNa0xej3ItAjnV" ..
	"RG0v4vGYhJu4pavvxWPx/T3tQ/YlYKzzXeZkKRiCR2JklzQ5B7eRs8tVPHXr03PibzIBxLnjTwSwmX4yzAi4mp4iHzDfrrIfuEBf" ..
	"N8slEFuwmqGcaKylglE+pv5m/MqJD+vgMDmdfMT9GjGb/IqXusIkigZZ+yYYd3/ZzZGrlPx5E/Tlnlj0jn+RYXspRC2pfhA559N6" ..
	"nTuBPB0ixnnMiNQVByfZ0C+98D5calkUf/gU5Vs7J+x8gyuwIUxG+abvZbspmaD49dC6jAeOHI8nFws9rgR7a57UK2Umm1pkBq2u" ..
	"0gH1Ap2X8HOP3qIeNywq+Eqop8a4J+jjD/SNzqUhZRX/8x6cjCPwBI+bIID573Fg6UX99Ne82hB7LFN22xULArku7kQvegcRl2zk" ..
	"96/3T9LgWoWT8NvKKSC1NxStewlEZJhyhOiP0xvXGftHeLYloqNTUWOcPFtPdnx7Em0GA8jO7/Af006eaefEhp3P5aq1ss9mld33" ..
	"CcDmRRD9YbOSSrqc7fzVdD21I4ybdcv+JBsPJa7LaxMdcVT1uN71e4+BE91FZxatZncEHf+JlZL2Vs/2Cp1MxcECV/+b1XfnOLtC" ..
	"FjZcK6HBxKLSmWM00rEmvsxuUcW362Ho3f9RZ556MV52D2ZG1iNhtV6Yxbtt5fcWlDDkz9u1WT13IXN4eU9KUQH9nBZqAQAS8Bax" ..
	"D7lVcMWFq2ZH+MBg880cz8eTFzAWUGy7KHluFm8gK+M3UNhDUyQGayLD0TE81YJzzCcknDcqj9etoNCt4UqX+9sf4zSbo4YPxJvl" ..
	"NOG0a7JBAnQpGZVsZvau9OYQyPwuzuaTD340Il716U2mYgweIgDnLHCkiOvYrHGXxLfxiWIfXjOQDVtAPxQcazoJMANEc6IBjBBG" ..
	"XPuBjg0iiepQYlIZDyJibAECUuAAYQd+pjkN2uhIcHoSD0WVWHbnbm0ZXw76ogDIPb2pq9nPE0rVF2rp3dfrGWo2iFCd8cyAReF7" ..
	"O+nEZJ1C/IScpMjQufBFdg14N7sNCb//g18VuamHFrDWswOczNCXNB4N7LJsaJ9KIcNndBy1gPyNfmaFdJvZIErHadbkEf02K2XX" ..
	"5YpByf3O5Gek5toRgCHDwSIjcND7qcJpc2O6BKnO+NNstDmslVTpSEr6xfruE8rZ1qaidU3k8XSTjTIDjyhusitHp84rYrVe29Qn" ..
	"7hfs5lJ7KK46vEJdqwcCdm3PTbSstpok+nhxTyiehMLj+iEwMBN5TrVRbgXtZ55sl26ikWbMRPUNWitsFRcsQU2rbS5IJTgkgKyS" ..
	"q3L+kBW246LyFKhTCCgGecfzOub3pUrQbBxBL7i/J3BzpmHEaAz/Lt2IZPlu4YE/eSrThiFviUuAa9fvJx5bUSDzCXlSixaa+pDk" ..
	"w0mTz6sDdBN8dHcfpQdDsGALVA3sUEL5W/LjfFvfJX+b3+o0s5hEVL+eBbzGy6O6mq1vaoaoTxHnATie5yGuUxoeitNjOBNrtfDW" ..
	"V4xbvVy6mxm1BtUA5oMA58kK/uTllUcvOf77bCpbWFgyJt+eUNTWtYnAGfYn0e44poDEqd1Qxc3NubNQhaNls5Z1sCOJSXU0oJ/S" ..
	"sp2Ia60m3Al6bFoLRFhOK0Cnu/9XOgYikdOreHlOtjaX/6TmuF4J8bZvV7yv0ijUUgP9tc+CPXn69gToSJxkgWW+FwfEmtcNEMl6" ..
	""
local PAYLOAD_P10 =
	"gfWQVzGQY4JDt9v9XYboIq9DbtlOq2+ugO8BkvGOlYuRJU47xZSdehSXCscZiBBRBmpydjoXENhqTBFyF5mN1/gjMjv0njyuZEHZ" ..
	"uB96GzFI1EHaoGsZLCgXUhEb1ZXxRFcjHuAS2LEBUO9Z7qm8xrNCuQcBklRFEGZI4diYLNesMBbLx+T7NRrgDk6fggAJ6HywboY4" ..
	"wmEzpfxtf0uNf7kH8F6k07fBkgeH1djxu2vGbXjf0giSsOix02jnhuPgijQk/0Y2qWZiMezLAuYEnhpQfGO7EJN/fbM3w46+hoVG" ..
	"F/7JFRHWt5aHzJU7xk3DHw9pHm8XQnzVaF6zLf0q0aHdg4CrGw9l3eTqPIVdADr3+1kHtX7hSLz3+ot4vQLuB+EO1ML3TGmk1qM2" ..
	"BnfE2EVNa/D3ZfyEFZF97Qhh+qtKtvyqGYm8fPnNnX28oNxzZmV3WiY72ttn/KKAEWRyk6zyKgffaORuNV+vgS6EE4LCBV6k2CUX" ..
	"b+8pk/tLmO70ifYeMaSBBaYe/3PpxsqssAOpnd9G7nc7T21CDx2Fwoo+DDSJvnnL7tK7GPRFGk1uR+Dl61tjDbm6AxBhKTw23qn4" ..
	"vFvpZZVAqSaxCWCvuJlRxTsGlnldpsQmw304RQ0cSwWTXNbIdf+2JgjJ0BApJ5QdfoUY542EM6ER007IkWtq2El1BwrcYWZcbEEu" ..
	"zfx53iyWazckucNJugWFs+VuBr5zjK6iCHZX+83eP3IMsbQyybvZ8BZYTxeJcxA1dOQAa/zrjeMx+rUXWkY2miCmZEi1Ep+/zTJf" ..
	"hOrkOvvnVk4S5t5Y5WyYMG5e2HPMbT1HVLdawrsh0lGKUSozWRUokwrn95y8YBtoBawfh57AlJE0rVFHf4z0v3Up+bFOU9Y6wFgm" ..
	"xpmfeulxaH+vAqk+PMrHK6AhdrEsTrnwM8FU/Mi5ZKGKu38A0seRcUMbM+S8esoD71gkhfzNCrFvqgVH1S9icViNFAnT32lyIEUP" ..
	"fNr4sYbs7pkFDTqGia19U6ujIp9WabcQEjOeoj4Yla7ikj0WXsAGaBLAqQGvE6ngGuFj5Ygu2LX2fHqOnlnOBKpa7tbB1SAXU+ch" ..
	"tkiH6/U62kKlyo4svoVQzRV1pmwd86kXmgseXFXABo0Zf1BFMwP4fvZ/RvRKy53EntPxN7X5ugi6kOtQADM7dSvkoUWuI2cq0nmI" ..
	"DjIKvyAST/FQAOpka3wyxS+N51Ckibz1+YfAyq/zozr0/k2wf1NRr2J1wBRFXswVPoeUlbIeyFCVbEhNyTrNZH8D+SLInD+Q9Pb0" ..
	"0WO6lMDp1Xw6zk9sqNNNA2rZ/xrGxK4nMVHWcLSEpqWTc45Hob8ILMpsKBIctzhjdoJKmFFuVCQ7fWdTjTToebb3L8eULxh98S/o" ..
	"aMRwbdNuM3P+Jo0EJW2A78C/34EIfqifotjCO7JTRouOnS/bZ8bibXhOMMKmfInEJ9jufBspcJmB7TCrrER27US7hV9upX3gPs+U" ..
	"s1w3tMQNEMv3K129wi4aPKkbN6XJPUKoEWheUAK8JIpccxlXOOh0aKBtC1r1CQ61kvrGqFX7rbjhsbvUACY54eQh9oH3s1zB8w8V" ..
	"1Z5exNkclm60Zm6DWlUldeNSbwh6rXxzP5+ByOb1ZR/e8X0W38rrcjBuzhYWXx3oxfdXFwbNNL6OZuhrB7ZU5dXWIRmaOzthCaHb" ..
	"822mxsl8QCACuB74GCy61ayItR+LzaDHCDLIug4zQpesggKhuusNaB6oZOKlV2/Hcs2W6LbLKUjfKTYJVgkNDy0HuyiZtr56rghc" ..
	"qtURcueP9pwIoRhj0StzWA00+x9irz/6oPxWHQreckuFJmMgMkeIGz5mOorXqMvx4+iP26CUDsHhrEpS13W/87QJhdLPi2Enh2Y+" ..
	"zMEtg499YUe5nn0/1yJpHvve0HNz0rDw/LQTmeP2bu5jItEla1sZsQ7Fr90N9oV91StBeXFRCmVoBmxs3ynwCbfOURveETYmRmAw" ..
	"RlhFiuabvqrQdavXeGDDzqGMmozmyvv4C1uXz+lK7Cgb2uGYjwz5lhHoUyAS3+ffkKeEs7FXyZBMKDAfrKPGsDd00LhL3X68Pd8V" ..
	"DhnVHNufVX7+w1p8C1xSH0dsVycUacxcuCPwacM9MVnAhOy1sDUkPxRgbsjsl954prjLfOJ/COSsywK/ca1uR5tCPP1uxDMzoWCU" ..
	"U9y+3TIzO58pJtJwCebDziSdqIj7Yovk6MB9aiYGGpPpfT8UpmZwDHRRgbJoXx47GIIAp6oPuETUDD84yiuPbHJIjFrXl1nS/6/T" ..
	"1MW2om2ySxPobmaQHk8PMtlbC70nr/gFtpHTdOkI2+Ois9wh+LdYudcEpdV7E4O6pDEVgf5LobYwFT1POXQzoL9hL9Gtx56MKREd" ..
	"EXg1IC9g/wTam2WtRgRsIPMJtmTj/yhJRc9JiJVDXWmqDYRGhKGg/S9hcIwyY08zsuDk3+CUy2rvTCePLaxwYOafaQxFQ+AcbyW2" ..
	"t2O0ffOLjiPZlAOn2E7aQ3EbcpuHDOePNT5gnShcgxhqw8S4BqbQQe9f+dtSPe/TtbLCYtiGnW+TnHFzyvisJ2Sro6h1r9c9xoUe" ..
	"bPuB6T3mRZbQJWqQOeuyrNO+wfYM2+Vs8Itb+Fq3/p3SsLl0LJrI1SWHjjHv8QsKnMGpvjKgHNDtmSiLdCZSl6X1PslH7Ji5UpHM" ..
	"I/Eh1bAU/fAkqrHaufQ0A5CenbIQ7QObcDUodCCEjl4bgkXL7tU7JJ/iwVYdSlshALK8leH/kDxKec1Y7HHRbkGcdZcQ7qYmtcJL" ..
	"rYjRPSy3ioxriQs6Q4Nhgt4Yv1n68UH53vnUULbIHBhTAc8uvt1HK6gJchBw53TiwNces/oxWjl8eBsLxPy6Plw6Ha7Cg1M/oWb5" ..
	"9jplb1zZyh8oagnaChzCQP/MJR0QiDP05KvsgXHIQsn+6LdXjLVdhEa3xQAK0Z64VKQc224/9HBrRdnbjBWNAIKifgg/INpnEqMv" ..
	"2rfKshW57h+iUb0WQtL9goXPGzgttncwV2KofeK3KZabulF2IT/iGPW87QFnoN+guKL3Zsp1IHNaUCUXR4/rN4bKxiWPOb06Jqkf" ..
	"8onnCu7s1bIc9B6vP94DSI4GEXfokGoap8NCOsDwqlXSjbx07dWY46+4XvqRcBYtu9SY0Wrjnx1Yb9CaaKsoe8m+KE/f7LITEYBQ" ..
	"2Titgo+3Cb6ys7uEUNjz9g8b0U3Y9WMNWSyRj8DFQA/ICMqx+9+dPESzP0B8j7GhX9ah/E0UZaeQxOdUyuQxT2TaG3yVoXSItDKe" ..
	"tilfenrXnTxu9z6SfYYikdGTnlrHXxXXfEPA9BEFGwvqBJ0JQzocQmgRKa8FWBTtS4nV3KKcpq7fHCsvCC8iaoZBGuhXabeBhj9E" ..
	"Y+2rNN0blCh8+Yyh4dJEY4qhwu8hH+ciVv0+KeHcire+U3uSjn+Yw6iddRBhw7HmtW8oiFad77eISKNOtXy6a6QDPir/BTIsf6vW" ..
	"fEYVUWQjNeqmZfyiA1ifk/937HIt+cHBF7AODdyN6a9stEIEWs5aN8Z41FMN2FLA2s2W6eZDA9BbrJSS36Xj5p2JbQdNYERtITDG" ..
	"ymBe3bS6tVgowN9vs2+GklDrL1v2dWhZb29ZR7d4Jvnh9DL3VfFQ9oH628dYe89rbqThwCjZAnrVC0lvDLIHtbMNqXSdzmqbW0zX" ..
	"6IUghEUlYTGRTX8geMOhH3iqbAFpt+CBHYdZkGz2Pto+m4HmlW9t+E+bDBq6J6do/QOqoLoDr2I6DmPFrV8MZ66V5DA7RZWjAmUT" ..
	"tJrWMN9VwB5mU9JzU0T8rO57pugI2nwao+PkrmHDtl3t2jirts7DZuTXb6Bt6MzIhHOmwrUyvLmVp6F2JE+pZjvUlvQGPdVPGNvQ" ..
	"+wViMzmEsv3PX4Z/xbgbWGqoT8JTGSmR2X4dFyvtD0NKlwRcwnQQ5xXsDXm246onGKZWM5PioUM2YHFW9la3K9fiJ1hVncn/GaQM" ..
	"tKoN4hdHOYfXuv06L5Vflw0/47vLCQNtLiaSVWKvEPxT/aw2Kvv0En10fFgudRw7I/aFCAxXqDpDsHX0kzsl80nPz37aenGkAzrs" ..
	"O+GLvz5ny50EjlvTIjExf9KGr/A3JbfpaMKhonnbe1n/UQsWceY+joLEUc5dWIyTrrNmoOPS0E2qD3Iic8oFhdiciV5riVPxlrFx" ..
	"Om/1UrzLsc5qX4l/voghEW1YkV7uLYlwYRyG0OUfIXbVFc0nc4+sVQ4xN7GpdGkMArncBYmL4PFnI1las4RazRMUQ1QtYDRnCGSD" ..
	"XfhiJVFTBDyiLZIxTrnRxIqWdQn5sm5EQwt6IiraEYulCfoYf5JuinDuqcpbSRAfP86zJYNTKygKDTkyBe7sW9zY89CB0bsEwGSG" ..
	"eGPLVWNYIpeAP8ErN2VSwMm1OEnQEK/E/7aCamXTrcF1gMfT6fGS0gNgAek9KAVZ/yYrNHQl01Y2fpjTZ4CL5Ofi9vxRDPOcblj6" ..
	"CKOUVUf6PlxKVDMS6uZBqWEIuJfVLAGyMC+tvK/VtXYcmV1yeMMZDJFrxvf0KZYwk5QqnIAR4qTsgYxP2hLU0iNuPktmPzsnZcEX" ..
	"eyHf6m2RO83U1kUGD2BsVDoGjqaJm3uH6ID9s30GMfCSt2Cpea+JG5MZnMe0qiGkrKtWU0RX+1fCpS3yzPelJgCt3fvOlQP7yVUx" ..
	"b5b2w2K9mI4kY1cvQyi/zs6A9lPL5lsiTXZRP4Eh+jeFxJHUeeMgTvwEu8yn7NeyaPv/wavOvC1g1E5x8fX3OngbC+D+z7Kx1fJ5" ..
	"k6iUmh0iwm9iAhQH2JCsz6gwyHDoL/oMML+m4UtdUNI1ITmsf4acJLV9H0boen86PYWxfkcwS0A/X3FxEO22+fKnQAHfuyIS5LTa" ..
	"9PU6TvmdnuMeC/DodRikVNlF+LQib9YzNQFM7pbOuTbx20x7gpFNh1VXcQxUEwZZVlyaKpiRCf6Q3Rys6HHBHJxyeFEUzPXtVCFP" ..
	"wIETj7y2vm7vlXfL18tVeG4TIlh0oZkazXSF+vpTA425BM0GKIYP9/MnZygX1giiR1XbFKOemWnQv17i6tfH+qsOkYE1whZxGazg" ..
	"5qR93xrYniUoYXnorTjoSVoE5xvIbJpuVxFXhfgaiv7nV4HxP60dxCEqUFkZ2KZlY4hlQo9B1jbRohTEMoQldB+wEtw4CnMUFNs3" ..
	"PbJQzXhVED55d681z1bKdLL5PNfDiy49wamPj1jA5vKdB54XwRPqBTODzXYZOAfRVdr5vVjPHO7cVVT6GbAuNAq4sV+03WGsdqD3" ..
	"RucjA54s0JRQxSemEV49hbzm9Z/hp5hAVFoPhc8XmX5dp8W6Ji4ffXgba/RAz3y5qjU7/wA6m24BPgS3B2dPSzRmANeCzFlKdjhs" ..
	"44+t86cK1DhyN6wyfKRHWKz8BkfD6TG9cLa3HuAzG1z98CBWja4HMqrbMxI5VYVdrV9xOMM4x7NV4LnTdgUOhnlLvmMH+5eZ60s0" ..
	"R70wzZ1hfQN72z71j4jDrh1fHtHQSQis7FNOSN45pU3oGyJZpGDd59VxMveG7dX8bim2S3/Ss2GOIpPRik69d2+mYI4ck8sZAsYS" ..
	"BpllbwXAU9YOiRJYQS7OV9WgwWFIKkRLtx3r+3dWjtwhSXInFkOIgzcD8SH/xU9Y/WXBeev+lv3tqZmm0Fdi3nK9u9dnUapDFUAN" ..
	"RmamhvGWdkjGKAERqqVPm0Vt+rJhitoQn7oP8Nz2dXvIGMsdi4+EEn6iji/50Y4PjHs05XhcMpp5/lPk/i5efUw72rIGLYZhrtsn" ..
	"PrIND/7XhcW6JLTNUbnBF2j0nbHKMsWG5r8tPRlLhgrooleDYYfglwnUphTJs+3yclsVttxveYIvlJfMFgP+b8TZ4RNOMFwJ0sZJ" ..
	"9F7kIAWK77/MzRbQR+wjVoEehR82i86AohygwcGZ2pdNVc9+vPc4NZHL1tpf90KghgX1v4xy1/FOBwMHvujWF08Hn+KYQcCge7dg" ..
	""
local PAYLOAD_P11 =
	"6NNGOPMNMWXET8wlqImnzU+BDHjOdnMP+oYsojKiiRcDGUV2IZO1OvQs0hm5qqly8qMRNa1yArJdA/SV+37F6/FiiHdKcj+prc8o" ..
	"ujQVaZE0OKlxbsFe+hy4Os8MMTQhHXizSdDe86tY8WCmfyn+6lETYuzySFO4Rq2PN5qxLlFSd4fMhLHv3pS59XQBkwB4KKMWzx6m" ..
	"KoCk6584xEGS5nLj5YurGjrEp8h6e/OyOjYIr7Ozwsmel8J3emp8gab3DyGWGCfvA/KkmvCO1ZTNCSXw9JZPT72vGx15m5LsOAKL" ..
	"TKmmiTHdZ6crFIEX3JOIgHUva56H93H/mZ4+9NRolgCG8MYlh/NW2+s28MlDB9UCQ6DbtOis1H1GsEGZmXEM/OtpGJ2r2xMplIM8" ..
	"87V/JgELQ0IcylIvbJSFch3FkXJ3qcrZ1q7gXIFlG2UtYHGSuTyU4b8ZwgST+A57WU5Lepf6b4BmPrMZmqZPmbw5S/+EnGzCjB9v" ..
	"Uk8E199+4pOe9pgP8dApdfOwRxtofkVuj0twQ60zFm/z5OWxcpHcg++KE/HhpaLC0HDU2J6sGJYWk/2wEkKjeadQW9UdP6ynFZr6" ..
	"NpyRjp80nFg9LTT9R/8wedmCcGOjelVVTFWw/l+KmIvVuaTTU5lOBG9j51HZwJcaoq74xSxVvqOQNkXWpJO+T4dJEfK1CxRP/eRb" ..
	"lU+YTCzntgotXQYkZZWHNrmluJhEv+9WE27U9DYYfuySs3FL7406UvX0JSXHpUs3Jjkl3G3JMq4jBgsmFvIygEi2R2Tzufswjp/I" ..
	"H6oxNTZTkBs2s0YOOu4At5zEefnab4njhfpwf1XWcS4JRiA86reOwKEPfXjEuJWCok1BNdxwrxh5sEPSsJX3+zp5XXSeugKogw5+" ..
	"ROc26ou4StXlnPu4NS5+E8ZgDGVdlxifGqJodJvVrD6RQXISVPbryZwfrnnzTRmy2VGEgWZ04lmZ4nc4Lmyx7rMRNDqxdrBMW3Zj" ..
	"ZP4b+WgDnnxIapllDhrae439lfxNOsvEFyKpItv+RSO6Sls9ZFbT3NfUx7eJQtqnsQlhtGL+9uMUB0t7M6X3cYadsvjf3rky6NS+" ..
	"cRJaxv8IiyWuo10EKL0LHBExDrR4EbrP2m3wIqnIfXncH0SgWa9kv14/Uknpi9IpooKmFPhcOskabynDogUm3O1RGEWsWs6LR5rt" ..
	"r5auLcDYf8WL6f9IFMEUVuOTiyhaPErsHsFo06KhvdgH7cpvKKa2bZz0Ay4epWhChCWDnArYgEPZ243AvS2T3s0oKIKtU1DlMtN8" ..
	"P8QKSHvY2+SYQ9oR2Io93r3wwg6IbtrUPQ8nb65vML33SEohnA==" ..
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
