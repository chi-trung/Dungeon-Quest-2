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
	{ seed = 2968173474, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2962414516, exp = 0, plan = 0, hwid = {} },
	{ seed = 2962997201, exp = 1788089514, plan = 1, hwid = {} }
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
	"v3u2F/+k5lHnYiIXSZceyWN9ZbLgunJALlyTYzuLw4rct8o2RAYG+7iRoNcRbNnBKhgFQWsoHiU9sN3O/G2cv2Y5mvlcW0O2M0ND" ..
	"ABGbiUD7D7tcKACeWYkCCVGxer/kGFrDf2//7TmRc5f1uGVzrjNDcdU9Os1vTmaNL+0UMRnEP9JYvXQEQcUE1WKahigtyc77V3pH" ..
	"EQTUkTJ9tD9Eu/zHYiAIKJK2UIkpTVlSMPFBMGa9mvCSuHtQT7p6BK068stOPNmCmb+wvLZ6LaUcDcP0vJNqQG2r9rSFXkGsMrvI" ..
	"HktQxpvybxUjhnDw+q6HarF5N283dkZcZLhC3vwl9hO7VRINaTdXwQ13K4q2Yz26kWT1ilQ8M1cWMsIOkjFe01KEfrwc2JRATYNm" ..
	"8cMXoqd3Uff/kvN+PCmxYkR5nJVtuRqx6JfYbLzV3lP9dbqjIkoIy9609egCcugIasOCs1PVWKN4v66lLUdmTVpgaPQX1whJxwf0" ..
	"85aDphGwOSVHDy7qWVeLbaun/dTxdGql8HvF/aIXzje0mCye5mrEIUiBy84cfh31nfnK8Wz8cQfXJgi/PXP+f7C0R9Opd6e19Dnd" ..
	"j8WWhdQCllo93nHVVFYwW0uDW6OLZLiJJuahlnvONkYskZu5Dih3Gr5dPH2hZ6n8vC0wINfVY1wjNaPwkuUKXGx7gfN5Pfdm/A/r" ..
	"mDLAPcr+aZNbxdotOGMmAtUG7XyUZHKzRuBM4hsKuvYor6FZLCTXB0grSGGEHaNwKo7JO4ut/VU8ghV87LICHaC26RyRIfSidYEH" ..
	"r0Jrk9+TkI3qFb96caJo1VzIAbyw4wC5xbLDkeqE/8fJ6OTe9f3r0lhxZjPr8M87HKQjW3D/g8dMNj4mFrFQvLtYN21OtEgX546b" ..
	"ndckqWF1b7jCV62h68KS4keYnYwpxZD1ujjM8OLV0VJdOU7skDMPppr7xUXdFKD7JKllxj649Wh6vs7xry7DUQZ3qR1AtTGifTUL" ..
	"5fdWh27iRrZ4YzOE4HEFNlwZxrUQZBqNAOu9NuxRS+qpFPBqVgB9ckdbTR/LvtBP2ew+MmB6a5Vuef0JDDpSsuy2d5kYpLHCRn0a" ..
	"DpGHuxL7GnEu0gkuMHe2jF3W6Glz0/ygcEs+YrdslR9kXbq22R+Rxax4dIW/afX8sdaKfzo0VlAwJdAjCPQs065bWAKE+mBpgbyp" ..
	"MFMbzV6h9Az+FKA0eszDMxTCHGc0chz8BciIeyQFolDlCDQuA6nmM0Re/mUosvW4k6t73eAqNV7ohEk9dLqaMvcZwAhZDDl9c5Pv" ..
	"YhHuXtbB+KKbhR+6tglOhYikSX9ChoSf69TEOaMl4JK5HqyfKtoQW9X+RerAeWO6ndvB+XLr/A7jcX1TYinHLctgVMwLY7qR3fjz" ..
	"ax8bSxwZf1DX/dP69OlH+bPxrVl7d2yp887nTBW7AQH/qJ64hJ5U1aHbU59m7LnShlSKSUGKLowLO3/NqSVbryZMac1hnZF+GSy/" ..
	"B/vysuob9AKjc0gVUE9YK23RjY+aIrRiK7T3j28dfYZZPIEXdNUZMr6k4N0CR1Shx3g8OFTymJwyEzicXD8hOH8UjLm7J2Ocv8X2" ..
	"SmZyxDmUcykjA8ebcno6t1v93/H6lkrKSkkxIWCE35CnpTSnAEgj9h6XsIRBRnHalqA/e54s5Vn3h/+pWETRHmbj9bReu+/3JRqS" ..
	"m6HZugoyrF5Sm2JvmYNpOF6Q/3SsCge6XARE8yLxDKg6ohzsiDG2IR7GqnpaVUUZDWMMjJJcf7ELRmPPp4BitzVxxlg0z3ZOSpE4" ..
	"b/OMWk/GPktFqSU0mIInnaH0sfvdHjd58IH/ETbUSv51AY9CngMqoGpURgLCeFjnl5tdnog2mF++p4ZddPLVvnZCVoP4XScfv6CG" ..
	"qfMHNhKJpLJADXqZHzY/QLMJ4Q2xqCnzemR1aIzHEru2K8gqg1cherpQGjfOSPH6eK+iJCaEFq+O9YNR4lKX8RbT+ApGhLeLiqWM" ..
	"dsKoJ09Tx1xFt/bZhKZsm5gXra0ltD3xfzFFP7231NM73nm4S6O3LPOS6fy6UyhAJaa7DDS3r8C9g6oN9pwI0MfiH5uzv6MiWrF0" ..
	"Egqh6rKk0Rt9KPbcuJRtx+PO+Ks+kgnzznwXCJoiDm8GQhjg5sW58IXFmX1I23KstZNOnLDJ47ImCDc+/t5d2oIz7P044i3OvX/y" ..
	"ioZf5+iRHcCNkZ0M/hPXywp7IuQvgwLMKXydhMOUgpl7h4EH1tMTrFBt7hlp+booGsYKj4lJ3SpOWU3JCt8QHW9gleK3hM1jTcDm" ..
	"mNSppwJthn7az3bXWslffXIM+uQ3O0dqjgy7sIM9U61hHgG/DxtAO/Q4DahTrtSDCZt8ghllWHRHQslzySzxr3wgVy+majNsGfrc" ..
	"cqngcDjkAzZqI8708U/sxnMlWMP/GXZm4c4x8yIgB9dqiVb4JuoC7IvgGWd4YfsezdYlUVmV4oJLgGbZP1awIlzYey8Vlg9j9R8M" ..
	"hHwZ+eEhpoJaVkx0MN0PUBnd0FfNTIGnmnBYQDf3sHG7HBW0J1NHBFWT7L5xZ7Gi1h8yFWQRZ3bVkjb3sXGsEV+HeYTDOAHeCVeL" ..
	"DLF2KTJjLDqnCHBlPTdRKNQ5ZbaqrRj3bu/sDDn9JbG3p1eJFcy8IOuyux5lHsqkII3nUlNdzCRe9dmGg+6GYIOqnP1Z6pOn+1cI" ..
	"2tyGyfPltUIbCwsnvuwinJnlla5F7xdawrEDltdCHFHFZLRFilKAnSqZHhaZCtcqD/CysQ5dbSOroRjyEfh0B5nW48yZF4UD8Mep" ..
	"XUTRHLrtBn7WHbVNRgy0Igm99d1kcy7Y7SVlWrcqu/V88oEJav0WAuX7HCsZSyJTt7NOE0KojGwmk3eRw2aO2vJid1LclcMkJXJU" ..
	"Bbt/5zmjRaKzXJKmWJZuhZUSlj0JGcI8tHQBOGfwiccBhmw4jjEavbXVdzGrkI1jZnvOanqOGyWfGqohAhRT21ENLsv8wl7b9EJO" ..
	"BdJjpw58l2pvi97zvLjFnLXfBQUjUyhFTwooNEz7uxjBTJM4MjilN58JDtFVATbt0idW/27zGe6ir2YuH/8Gu8UwpcHD5jh3HGgD" ..
	"uC5PU1fboeyCSINFhgsvjAvjJPlCvgny9qrMrzwA0AVm+5nLIFfNGE0DW0U2yC+h7zb84EbnaEmhkxW5NeJUJ8s/VmQl8klQgZ4k" ..
	"g8kgArvVFsdQEVMUr3oEBNlLJgsSHYdhP0n5f2zqrz7pNlAPJdMhVfzOhHL2oUbrRLxncogYmPqlPZe433WyxZA8/Ln8X/AJpAlB" ..
	"5EN51dJLlw/XGhdG9wCaqy9qD/uaFSJFu0Ji5R4wGxMf0vhY8UQ6XY7EsOKsFiSTvFF7nlrx6JFe1ulxxUKkwCmHEveodx4Zeyqw" ..
	"PgNt4HVBpJ+vGrC9KYo5rQjKvoPfgCklXb6RqMjl94q8V6PUyM7/aXax71XqUcPfjqcgdZU/VoE5M18S0fRIKqrArEmjsfoFzWga" ..
	"dnKrSLakXxYYkD1YhjiLWSMDmv5DYMLkoK7kTJxe1ql27dDltm0SSo68an6PSQkvMVgs0HGrTG3wiu3If5N3Cv94KLACnxmMJ8Xa" ..
	"4L5BLZpjcPNHOkn/Uf4uzuwz3Z1kLllajiKun3DXSCm73XRezhfpW0ktKJikDg3zsGfGBaWTer67Htsbyfuqoh1v8UXeniqvO21m" ..
	"5el8GMx9csTtDDkT/oSdB8Olpe45qDExSAM1K6f6N+wTFfwKhVN5x/7k9DGVpPhQGj3PSJk78MzOVaM05gPfL2rAib3YLNYBT6t0" ..
	"bZxZkFYQAUi4COgRIxeRuLWxO2840vPuG34UQ7O8UiAbMjidH7qvXMMwIMUFefo5adGRRa0N2zgm6l6576ISde6NhcC0IjVLLjV3" ..
	"nYhTfXYGgulib8bnlTF6QHMAgnQBY/+RnVOlgUIIH7/kIKhDOccmsarxmixKRyXZh0JpWOciTvdVYjon2vtz5miNfW0Mu7b+rS8Y" ..
	"9tmxRWDRLYNnLp+0TZg5ZmI6L7xEaLz7iKR1FmRmlaN2+5//nbmRh+nKfhWJurgT37ChpsDJ/2pFKjehKKvAFm8ra2SxNDPLhL/f" ..
	"daRPs/sYRPKbmxnQb3y0r5O1AIpcwj9bvGPbON+IVhce9S9tITXtqutrAE3xREYAFpZLAMiq85h7VYYx1TYzi7Xu6Tev7pJrvYuA" ..
	"Cjh7jHZ3BSi7HiB7vXDYA294qR12VwZFDkDUxW6HARDzx5uulBANQ5EYvzWh7nPoGTXzzUvkbl9o5givsvFPs+sLoZA5BLKJ9b3+" ..
	"H9tlPr7vlB9mlwzj2elmtbngFtAFPnqFf08JnMmsgDbwhlFe+6mNHfW6rL1nk9IBhH1Rh4mQspG0mE5qqcbUz6HPRTay/lrYgB2U" ..
	"U14kONszoHU8oUl0eIH64mDJ0J/IUc2F60WC/MtfV5wp3ZTh+OeAUox6gJ/kBhYijtEOJLxhVYsKMJsG9WUQHN0J2Ln5hrjm1vyg" ..
	"NqrdKTLJ8HPxyqygAGEkghKg7qK+teZdyAbtmJIIrPoVPR+XIZrlHQtYhetDIWXNkTQXDaIyEzGAkhVrbbKFJ9EahNaA08XUfh8a" ..
	"RaqW6EDrCI8x1rnv40wGz6jz8YhAKGtI+j1wswz+m/bTm9YjSBR1AJrdZ0MJxIyplVf6ewk5l3HL4X2lx8/1dP3wNCvcTyuHk0v7" ..
	"zAjIyJAPTM5twzOAvoGhGf9VjjrgoJrH6E6Sfm+7KFUQVobgvMJJjdgUxCbk1T8ofCoY4h5zf0H0XY5DAKSBOsqOsqieE+Bh6lSC" ..
	"OTRrjWfRT2JILxemgaVUv40lkYfQqjynFJiv+s/RE9KLHQlbVcoRuxHvzRp5N3g/aY+OjH2vYHysa9PvQ5UOqgaG+q3KWmD9LAMq" ..
	"PemVqazvB6m/i4GjTollFCf15WqbJq8D2++6l+9R2hE5PE7aoYLKdqbbbMJqz+0FXUqAGfK2lP58oeaiqtQxLkwIL4uNKaWA1+w2" ..
	"MtUKZE9u70hsIHZEJnEu53RdjAIy+ex7WtLbhkoSq5gisAe6UNtaoDfPGEr21puI/g8tHb57hMdTQvAm6sBaL2QIXR/BLbNbfw7n" ..
	"APP/5s2RcwHsFpUouVtU46VEAxhZofNUrB5GuaVEXktAI4/jwZyzGD0wg5DIIKUuCokGwXw7ZNL+3GnRxz8xJwItrOFogTx/bl8k" ..
	"JGs4/f873mGh2BprCI+c5JFHK5uZ4oc0aJazYAmV5lOXcnqaWgkvay/1nib8y8VDsd4gDsiI09n47Mgu+l2m1HzvDJGfn/c4nF2m" ..
	"0BoJ9EeoISnGdOEgS38EpfJwmTBIB+eXI0ThfFrYqv7AwT9EKzCy6Ptx49+nncrBs4mqb5PgLk4MSA6YibFadi1ecqNJ/gNXJ4GL" ..
	"3IbKoX7YkXZ/iOK4VrrOfLdtuzwcurQ3VnPVXe9wSTB0e/6biubbJFNz9OXOGkJLcT2fkf6dbYt4Hlym67U6dqXmMjFsqGv5LP7M" ..
	"zZ/sVCMVxWLkw9dOKorigUsQNIeLHjCrFWTjCmv+amuej+WZeICrbJifwwQo50dIC6qpasO2FReJSWYT6LmWKd6//Pi1wQ0NZnKr" ..
	"OTJk69g0f62muJYOMxD5L9AT362Ez4wDUF/7kbsmhfIbBiJ2HYhVqw4S5KVEOSY4z+ZTPyTglfg3FGa3f7UASkapGjciWfra2sh6" ..
	"5RSa4oy84RxBw3WcXWTuTrN0w7xlQDsfWvS5mGWnwrVQ8S+vUSgOKqsQnSrnt5Z8Ruo0D3PLkhKN8G1wMNMHxtsOCk8CYjCqTy3M" ..
	"qegBdGqiqI4GNr7My+YeuLlfQZwpRglMknrpBIXiPLZgcJN+LJDlaPXtwL1K9VYlVf2pKdB8qog2Dsyeh4fopL55oUDgfY27ERRp" ..
	"i/4TkP65Hm7JL6lpI+JXGyxC5cANVo35yE0d1D53a9y8iH2xDI23OFcFx0eIoY540WYPY+h2Flwfg8vFudqENUZ5rA+90xO01jjO" ..
	""
local PAYLOAD_P2 =
	"d/KYW0EvX/PYkPIr8El4hkyVycBADHMgmQ3VFJza+rFByGvmA2rWiDNi5TF0nVFQb9pBKA77fmZIxcMNDkG8VFOvxO12TKSQ3F2p" ..
	"9ttVAcaFSh2xWoBVXSa9vxLnRP/rJv238TU47b9VTYFHaTyyLc6pQYOaG28tnKQomC/Y8BEul54zs5AQbVxMbxufvWAl0BIBDLEH" ..
	"GrEaDtreEKSmB6dmKxIDrEjO4aVJ6ur//KXyM2/ss8GiciwvqZQ2VYCaoOmWlXGwEJ6q66sNKK39+R0TTHJMLPfxdIUct0CJN9Fg" ..
	"5BV0ttNmj7TC8JdEqpE1UnL3UoRmrYtmXJOo23wwhFxAwKkyjx4q3wxD70AJ70nPUzYJK9gHEsOL149UJKahfyXDz4phxVn6Gzz1" ..
	"tC4IAJtMo/r5vkofgjvxbbciAhz5yd56wNIqmrpQC/lCrZBxlZSPdQQKCjmnIxywStE4tE5Wq9sfT2b+pAjsSVIxnEYSe/u7r5Im" ..
	"yJMDvIWcPpsywgwgGHB9LUEQiW3WdMjAFoKdRjb4GcJF7/5a9E9dQ9iqu+mMYxwJOrqEqBE10v7duqnnH4C6gCek265vkDzaQD9U" ..
	"/R173PJaisMhaUTHHyx1b7bqUWuHUyS2/VDd/zYeMyO2pl/jpeyyFlw0UMG0L3jJAr3e8Sn57PX0Fd3I50/C0lU2LM1bCp7+AWGj" ..
	"xfIZsFM+zfEP8/NcX1Yz3Tf/yFDy3WiLg2WTHGNSZVPcywz6yiU1faXCntNGcdIAxqGCMGsQU0j9slctcj1W0DJ4rguQRPXdR2Rx" ..
	"MlGHF6XSjrHSBeamGrdMv8HbOTmNz+eGfMILIwFjmAANIjDxs0E+GXzOJxbiP+Rml4V5kehXze34tt+CvyTLFRUmtBHqC+ztQQbO" ..
	"3EHtJYFnYF1Ps3aHG1IIK8AacOu7KOU/k0c1/E1q3CNshIyRbEis1hFiAVPozwwcekTnVfA7H9E8iZrsyM8rEIkF+44QCJg/bGZn" ..
	"bGD2rzCEOY1nB/ffN2c2siKTS6MRlm4gNyWP3XwcAZ9B8e/+0GMkZbSkXRS8lXsG1BVC36IUP7goxyaA0+OkBJ5oFd34BP76Wknt" ..
	"PtpTYOGJxTUsx8whJL5ydFDY8YesJGIufCpATAIif4M3xUH4LtININWkcXWz4nXrRe4j3R1XZYvjm78JfmCacTObhctlDSNy6/TY" ..
	"kBD9Czzj5qic/UIFRDktTNN4CSsPZliQnbB8J6VJPvDS4v5pFqlupkmyYp+Wh1MAV6u6cmBiLh3v0ZMRYF+ioyjQ8q8X8ymu14Um" ..
	"R16uFPumRlMosIS7zRNdF5/pt5t1BLD+fse40+AWuYGFeRxBIlg65dVu34RdQPOnl0jStx/CyH6LDww2QHLKiHpP+GpUCylE/HNj" ..
	"pCWz/qzYJEvMb/BMSg9T+SJSFM83IVkZrfcTvRijm9+ov+lo5X1ViwfxQ7sOmfRlVAYYF0qlhU2BgOoGFLdepnp6YWgiRDDI2gA5" ..
	"70q+xrTcfC+ZfsLn+hHdOBail7QccSuOulMcOeqGjliHsG8iEzOSQ5ynwxUvoxyAM+A33zcngGnCq7FOfIQwaSY3/fPDfSeY5kcD" ..
	"7ubUbnkX2W1J7N8AtYk0b4HDHX6jPuO4SkEib52wMXXvlFnaSiAmlz6XJphBU+82q9UVVBaIu38BTRfh+27XRJPJGROBKJz0rUPZ" ..
	"9L1nYZzx0lmqGd4TzUfckMFIH1Ag8U6PwpVbchwPqKUqKtYmbY6LYhJEU9BiR4mFyJoQ+H9TK1TGLLaabn4Lj9hx9S8e5/1WQtgq" ..
	"EAuual0a1SsBxIBNlGZeQ0cu3ag/4AFZYGzaj+z15kllzCz64JSFVQ8AM5uZ2OqYrpKPjhLqUwDdd4XpWYPW6MRqbTIuX7l0sn4T" ..
	"MNjYf4tQzXgsm1DTOREgoPKB6j9wjxUIFsifVRI5IRZhdzHOYr7t0u5LTFfrP9vbtRi3+nKHDv8u5CpeIKYcGD40a5KHMOunM1v1" ..
	"s5s6s1NsA+agUTJaWqNKcS7x9reJX0xGV69joI+Ymndlbz9zK7T6xFcGCYybUmaYGTHbvXx0T86knoVL0TSLUEgeZVAUfQ+iIde3" ..
	"JZ0zWm7VUo6IrWOj80T709rQiybzHd/nz55olGqAAq8qEvu0vdnPuQL9qBmDi8U67SXUOMJI8smh5nRXX8m6AFnR31w+VCcSjpiQ" ..
	"amAfRG6sZRbrc1RIBGYy18HChppNNOPyW4tnvSNRlBgK2pIjUNstJteyQN1ef8FA9H1m13GD9yYAtsbO8Tgc2fbJi6polN2NJM4c" ..
	"YsTZGwYmCIcc6SOYKgiyt55idq8jwFPqvOVejRk1FHsr1/+epGpgJVnJtGnRpgV6Y13QJnaoGQ7K2ryZCHuRMdb3Lyw7NWu46ajC" ..
	"rcNsFzBjPJVaz8MMHstUxVzVHVyGxafp1DS+9xKSAAspfUJF3RmCccZTZvOXKDTkZsowkFTXMylSLkHgRFRk9q+sr/KtAzyB/FSJ" ..
	"QSVF3O6NUApdQfXHlLUDmtekcmAAN7o44WWEQleddshBKTaBi5dntWZtt8oZtfyxbSuOrJlihHW4aW2LZg5csOe8Wv7E0VPDiGH6" ..
	"U4CORFA3gqJV+Hu4i1ox/WVCGzr1Bm7cwlO9FkuJqAQhaD2VQq7Ym/Plju48hRTUyJ3oFLj6J04W9srnyifs/sKzCDTv1JhIY5+Q" ..
	"01W020ybi6wjuY3lCeVjBgBrdUwWHcdO8q1uc7+N69Xf+4MCkeK5QDHqkoa8YAbdL9L8hsWt3sDMQMMvTub6ROgw9BHsN8JiKGjU" ..
	"nQJucj2ZMV8G+ghOLPcW/gm4FOeBFuRUM+dp1sL6K9Movr/ZMOWlPkMZ/YJchCh11UZXrBo1Yyla7JsN5ygItBIKIdKT9mHraLo7" ..
	"AhgqpyU8mWGr1d+tnASF6CKVcTkWU/P/gi1aHAevaXPZxu8XPmFO+tSizYNJ9U4BIZsWJhtxoDwiNOFvOzBKMmkE4hG9+qdn1zaP" ..
	"1VwjabhaAiyQyv+jLMwxfseH1J8xhwv/V3N7M/+3OMcF/uKT1IELW7icEvyOV6Jw25awjAnMiOAfOHEkqhxwZBZpyidaMaZid0Dg" ..
	"y7U1bl74DmEhR45l4CFJaMTXHWncIYW6hKp5wTa99sGmkvEY6RYXmRnyI4bB04GwDylFntbiPEtxO49h77nWm/RJ9nN5n5H+VCzJ" ..
	"Ne3KlBtgH1lG6IanIQGGsj9mcDG1nt55LMwKZiQygL6mWbvTaLFL4sKaRjUp7G02+c8k4IM9FRhWG8vgwIstT/4bDk0IUbIwI/fg" ..
	"MWKaLlaHde/1rDaH2UZ6Mt4LMynHS2n0r0VFVV6RG6Yu/hvTaJFNopR5dxcfMxxR0kynfV3yUiqClCJcFw6Rskvq8XkXm5Tvdveu" ..
	"g5Z/8870CxFCukB9bLUMkqvNfZ7/x0twbg98n0R+mdCfNK6YdOBRJX5E8q2liZtWfFNsh2HdNtmjjnj1dDgz2iHI/6GYmgCHE4wT" ..
	"xfMtFAOgGoLmhnES5k43KlRIlA5JODgDAj/1iEcvO9m+lP677DO13/8LNr7xnI/jivAAD0F2EHm6KcYw5RCiP6+Tgq1Dh59Nqayb" ..
	"M5TV+A//c/xepmhPMPsRc4uyeb6rErEVKAcBlcEtbYVcEC61jSJzGRCT9CZTJBVzzUf/iayKIUoWRXfxg7c2lvBUKJuvc/91svay" ..
	"3CGaT+sk2yPNZWW+94en9lkzEa34FCAZPHCjUdpoOjQI+cUnmbfXsSHNPVWZi9geQPqQDaZluU1f7rRoF5Z/EgCQADWePbrPclM2" ..
	"2vGDB/9iH4eA9/ooCDT2hK3uJK5UXPJfWFfGDMsYJeRQlBnQGAcwrCZbrxTdn9GkyyntF9GDjA6OS3eyJmJCMuGrCsUELRi1uCdC" ..
	"CA//zh0iQtWFS6SrK29QxUcTwzrUvl9jc/oqC5HW2vkJHqtxJKMiZgCndtumHqbroZkycryire4WG8WjQYfrVW+sVd6Px5Hkh9Zz" ..
	"Ct0/KJGcsOp3pqh0gS/cVL4NYTNHlshSPJBRc5LRitAvaLpM2SZPMtF34p7fu+H1l/eGgOrq/L2/7kLu7x6sm6JNNmEhCBwfM97N" ..
	"WNhlTaTffnL2GoqnzbtJLF832YKTlQDaYjYbthTsU5o3SA6B/JvwqQlqkhhDR8RfDXqlx1vsvJX9JxEh87kO6oUSAVZwOwmUh/k4" ..
	"MJ2GXQRKnmRECAJjFdik6MW1o1hArJV8R/Gq8aHpGpokP+JS7Fc+Dm0wCRpneLHBEoiWaMnHUtARUdxv2I834TQvs/ZraKucfW3y" ..
	"G/TBdLOrz3RZk8Qkk4B7qdGph0/kkgA+++A/3mFqy8yikJT9y288MP9Elkko5BmlaDjrxwm8ZPfeKe02ILxOlMtx6MppH84ANg3F" ..
	"Gy+CCtbFn66qsAoetnw3kH8giS/22CoKmslu87gZt4IbhSdc6EplblT4fJ+trAEJ0TOqCVvmk+vI8Df5EhlNJbP81dk/yj/FRIdb" ..
	"ggxMxCjCqWCTwYTuz8y02tZ5lxhUpNzRYkh8zmVGbkLNS02dfKdrjsy6mDvZYENrKgFUj6eFTe0EN+sdZALOSdjJ7nMkn4zq12OS" ..
	"QjrYx/8ARenxnAJdRFQiJo89fkvkyOoMfEtma4TD01HwxWqBs5LK3p7M3OTS1BGE0wxOWRGK1GhgTwqyvMAT6ZVBIwLTMFchmcoe" ..
	"JqRCfsuzcw3Mx6BW2SuqvV6xN620VLM/vpeagUZhIRVUaPdJK2rjU6zTigkHzehBxTT7UL3XcT5bePROToO3LBk75LeEdjB9Rpnn" ..
	"eLcMB9l92i5oX0Yn14+h1ogr/qzdyyChJpwbzRtsPN3IyPbGn4ctmHNAriWU703NWe4dqvdrn/ajqbD9VT78dIj+E/9hP3DTaEJC" ..
	"eQCHzh/Ui2gXWQBrZ+Jiqv8CF6J0jvVJ6hrQ/nAUXj8Wpc0Wrdx83LpFHdxcJiLmzLbLyOaMFpCVgaui+vqtJd6X8qk+YczzE3yJ" ..
	"9c3WMt9wTz1hm5dt5iE99mgpPqZcUubVsBquSNUGHgKyyEHtOct1wFDuNo6ja1Br4AbyehPtXB9q3Jibw6NCrGD4x6TyKsGKsx97" ..
	"ASysfVqwT6kjzuH+9CpuHv5um91vQv+XKXPQ6imE302iNhTC/nVcs6yVHMKA50rZ5rUjNVXCH+R7sfWpyrkvS4A9DECMeKtYIPbP" ..
	"yQkRIrPfHRyWkXqe8OFMciCS3ue4cQE3/Ny8zOxh9q+xNyPyoQS8hVe855akaV8M2KdqBQpEz2gnQQoJ3C8snnR5J4yiDA5Rrhgy" ..
	"EX6m6iaGZBy3Jo+wqfU0KwFupy8pqgws0PCtvbDEjFMu8h2GA+52sjn0xyx7lWE06dbrogSai3LzZlR2DduxCvNa4piYWPzTYLqa" ..
	"kHLI/zFuwY2QLt0HvTV3OaGtBFkksk6AqCgSd92sjURfcEkhyUtx9ylrBmHWwh9UUvhc9ktd0UAy8rESl4y97flcxKqtHot6bk5E" ..
	"IxNJcn+oISZ2hCMJ9jzCtjOCObyX+CE+5Pw4lhJESM/dMCl1F2CnMUpylZGQUwYqVnhPaIWUp4KAlkZWSd85fqGqchsnyZS8ROVs" ..
	"gH79F2hzteZbEhfC0OQPnzJAujoXxUQ/fNg2erCsRjvPLfmUT2aD8e4Tj/O/bKEPrCrRQWFks8ybC31BVnEvdTGVW0WjlH4wJ+i8" ..
	"g75zbzMQ+emqHdx4ACBAP+BBkv4eTnslh9bQr8vHb88SURXYMGh1CVpu5MSIbid6WyyZMMy017MPN4QnywHCfzcxp6zL4fsJ0l9b" ..
	"NC8+7LRH+6EdMsBcUVWe/4kFCt08gpGhomUUZSfdi/vZNBBVYMRt0NguUXqTjsTSdKWD0HaoOqeFzsIRRN9ZZV4HfUOJfinzy0jX" ..
	"whfqnxtI3sliBqNs/2fpzCFyh+AidDpZh42tEOTpUV3SdxXeEHx7ULgKrRFKtV/pJkt20ytU86r7J7csUnEzHC+Fv3ZDti7/Yu6j" ..
	""
local PAYLOAD_P3 =
	"+FKNeL5R8MP+sdtiBxrWjsHOckpYtThr+Rprarr8JP/o1LNeEkUE4+fZdMmOkP3xbQ1Y6O9cfVCRWjlFMtWRJQ/5imCk8FL99MFL" ..
	"XjG/lZGIyqmH9urveEj9peqsFcKvBtAFKIzdb8AdqtPj33KKun+OWrK8h92i6MdpH8nnzSzYbsofcT4KvqGTcItOLYyLojEkz6VU" ..
	"G4YDWDYX95oYetyNhfDfwZ72lPjGQJt/57e/GW/S9n2qdPbEzNzPcT588M5YeKuFWVQGQyc4Yw4BrVAOtHXvZ1TxTprxpdk/AgMM" ..
	"RR2gSxgy7DeXn/sY2KrvWsIoakIrhmXAYL1Z09Vw2BwGhMoQpYJUB06recObVubA/mRvN/TIycGOitZJvZeOPaReit8oxHHX70ZW" ..
	"MxehQ0n9HJIoV/ek5gbP3m7dPP2N3rsFnhTOQXJivr1ZkrEX3GZ30hIM5U52Foy+AeAMmXD85vfvtayegNspde6oG4VqjYNYjfPR" ..
	"dmBzwbG9o89LDGkNUzGSVMXEMIJvV3h51eso/zNPRNbE/SX8/C+iavW1ajIN/2L+J2a5oHjZS9kOjd+RPZzhwJ9J7m86jnfn2SbP" ..
	"7YOKMuYhmjT3J9rtxrvInMz47/LOBoozWBpiKImiV744bgnFK4sfSxUzcxoAkynBvmW0nWv/F0f2UPnRlpnnKx/+4y6mCq7jc271" ..
	"XvmHbQSLd6zj1b05dhPf/cifnm+VwRmxPdQXr1eM9XqbfPp38rwBzLCDCTwsJWf8PkFOLPTAiXacbkaVETPBQiBfNtE7BnMXawCb" ..
	"dmg3osupU67dye9vzTATn6dZ5+OE7saHl8qVQe9u85R3zvaYugkjG0g3VR7xcEAUtDyYnb7qT0pHnkgD4JISP4rCe28UxXIxJuq9" ..
	"Ahkvo+tYRjGtjYVDgXOJ7sqlkjzuYWYvTf9vCPUyE4CGeZBofeL92BNHRaNMace011OxurUUK5E8g+wqRo29bWTs+F/rTR8Bw0i3" ..
	"BTxngJxEE57LRnEYCMST5kXhFxxdqzBMNhWNcfK+uzOGWFAmNnzAyK12Jy6WDCeNrDS3MZqojKEVisX/xEhhYDeDSGKshMAAggJ6" ..
	"f0cbAUhLqUONiafHP30UXbe/R4DE/rctFhxJKxT4yqosL1yOSGbn7WPjBhwWDA062wTzk0s9BKZRMWY5lOuPdZS4QVbB1dsaNdia" ..
	"h9czaCdSuh2vkfs/E5E7norn0z3N+inN85vXxRw3bTSfff9hxur5BJtl3PDmNjlbuW/3HmtgrVbyUf2Rj7diQpp26DrvudRsD2gD" ..
	"8mzrR4/pKLyf6pyTkmXGzYDiPQhX059juAwZGEkfV5NFdZEw+owr0FqGF9m3q86rVq9iDThpyEAjoVNF5/F0qVWVS0chuLOHV2Q2" ..
	"OmT46RU826XjXUCgnSKukKg4tmHrwafLdmQMGojnqbaKRf+k0zPRceJBp9TeDp0axrCGoXzqr3eh5me4it7Yo4A0IIUJYA68IiR3" ..
	"TyrPPWlSCEB9ydt2MX4Zvko0IPiYttQehXYAzWuEDwbvcf6Pl1u+Zr3+w6l7+csqPJkPrM0Rc7QQZbUKMWZYGN7BjfPPChpYoM9Z" ..
	"i5vvweY90lO+aiZXF49CAtFuKXLZcsDWiBI2KIJma0SZfxmirUt2z3Gb0eDXTd0kA3r1xhimUrll4iA74T2YjComaF+p3U7vxOHO" ..
	"s7uMoFAXqIoAoEiC2q+sd9X671xD388LP0ONiuZ1J94LSidsvkWC2thLePxVElfqWoeGP5zk+1OtEn/sobFDmFIMO2ee6FVnUAeL" ..
	"bqNB4cudhDG3uzE6/ZUBL2hwov83nomUBiqE0BYgtGCJxqntorTFP3Aw/W6ZbbfspLxplrzQa1Oq8j5q0YrYPMzWxjeZoCMIW7dG" ..
	"7pbADNDbKgKyIjWvkaUJu2wCXp8naSbWEiJIaiJwQW3DC7+FfbJMBRNE85rSvevRIkhFwKmz3jM7URq31PeSbttuX90LnnWomeNW" ..
	"eFXPWixq5OaE04MbhxPsQgxEZ1L0tUDfCUtPV+qjD1lZxZaod1QTnrEiZlpeo+WyQH/KkI1M4VoJyhN78HGc7oyR75pZGFbUdFAq" ..
	"NAHxzMZvLBOV+zarA9ZZ22I5+Tlts9pyTwAtLvzkcEwuPVIumhhyJ86RcxCe3MApzOex8colY+SqcuU+50G2RCsgHdFgowogS+iC" ..
	"8kkI4Njo5K56EAuneT5vH7TkED8zGWDcHSEAS4bdNNOVP+JsjhC26PqpX74fim3gRGbIyU9tXXPRJmH446X2zTwghVy+vDbZbEGG" ..
	"luaPbgq2Wwt8PvPkvOesj2TgdlQz9c5uj0yzDea0fYnB0JS5gVqiXRq6x7KmxxqZUyNBolkM6fwFaRHmHR+x5r/djespDunrzcTB" ..
	"flzPQ3kPI2tHGnM1DIlC996bI/WTjb5Lg8BuFBwrHAjEKempQLuEXoxJC1EvsFlYDhjrKR1CrF2JJhbS+G/AA79FRO97o7uym5Bl" ..
	"rBATwI3wRLJU1ZCvrJpkLQIxvPirudTBrelVG44nTK99WekbRV95FKJyT7AvaZZnLt16we8GNN92iePa510u/1WoBiYfRW+3jM5Z" ..
	"w5IC+pE9VhknqK48DhNEaa3IyAh+sAeJ/8uwk0LQJCsm3Xi7gMvD83vBDSFUcA0ntoltzCaaLpiW8fvRQVgml1Z3z2lR2g9B995/" ..
	"CQMJvb+6AfukqVAnBhzf+I+JMEtNY7mHh75mr9FPCbk4DpAXzUHk5E9+BmNn4NZuGBeaX7h0tVxFFxIrI5x69ngs4Ld2kUT2zCk9" ..
	"uP4cHJelLnxM29E83LNVnrzHL3XH496nAYwrcr/0Er0XtHuN96cHAHuJTSDQvag2KHMrqaZodLAc/IkLP0pvJGTI5+aytLCRZ+Ul" ..
	"8bwyFCpk7WgXbIf0YUKnzFdmtSsub3fHJCKxgbTDk1mcMn8X8h7L/3Jzm15kDK3pNMh8Ozo9OqtExhSqgpOoHs/1egVcmfUXwgo2" ..
	"b9D4Mdddmc9bQGK18dl9itTbERqQ5xQPN7/owmK02T+zDmdLOFkhh/KbgGPrR4LPn9uvo2DyfjWvJPq1tsZUUVC580O5cz7k8kDY" ..
	"Ctbp6LRBBD6U8x2FSUq4NT1OdUW2PoO1txHFX293w3e9gjV/K+9DobK+YulGVNM5AQGzTFckG3JBY3aY6IWObGCLaifIn5n9u3Vj" ..
	"JXWSyKw4vO8nBIXJt4LTzrNXkZwytdHiU6LjRd3PTGu1kbYragZWhJpCjOGWVmFfiWHetcNXrEBb/9MlwMmf0Ct24l/4JRc6Fcdp" ..
	"J2M3v1PpU0FBcLTZ1Mj43FZpu2Dhq6K9pxKs+PTTEzumABWueISGYB4F3tgRtcvTKpSC2oH0X5z9siyhajPQUGNC1xgPTAjNncsk" ..
	"YKYZXLrp8Y7z58s/lkRK8Ixn74vTDeEciGU4yp8DHnA0+NMoIJp8ThkNLx9rEWgU4mCE7bH95/diw3XzQ2/q/luike91Tv7hfQI/" ..
	"RgGDCYhV+hAn+yWjYavQmmYaGbQnaYYZ922UdDEOAOCpm26d5AZOAoNGoiE3EPxJ/tWRMYBK48WTB567oA/3wFiF9XFtDy0SUhFz" ..
	"+IDF4RQFJBM1eTLSYsnXIpDDmLdjAFe1qF9+EZcdj4Dm/91/q9q7i62tvclSTwM3x7kmO6O4K8/1YbeqmMtLRThRh2K+JyZbnep0" ..
	"FCK1kMPwsuxFOYxzUINge5mgYxR/UTaSi4QdahS9KmEn+5qyIidHJpx3v5JsrRf8hnu2vvWuQNhv5l96ln+Co5P2UY0zf5/AZx6i" ..
	"u3Jvd38TqkcWSWuTkG7A22VkArArhAhUbh3QG0+dvpEgsctrTFPtYfFxFK2j0MgHBwASkIdn2Jk23HhiWlbhnEEn+IBiG/egWcBH" ..
	"Ikc659DLvyTKJh3Cyf7MOf2XRCvoi1UkbebpF/CEqxHcoRitOXd0O5A/y8HN/sYUpxXQTabXBT0jvEh+FfCpU6Fok46KSD1YLNm9" ..
	"dwNlXOwSBHnK1i3dTJvlHVXColZqs/x95R6fBEw6hDvh27MYO562g5P0bo99O2hFzRimGd5ZbGXmeojECSYs0q7OvhsLmf2Vr/w7" ..
	"p3K7uXSvRCAiY614Q7692F59LYxk3x7Zmj80o6VTK2v0HUxbf4WS03396hGgr10Z9mM6wnkjtmhvxSF6wlY6Qjv3xmFPt/CDuAOX" ..
	"1snhl/wo42EkOkpvxdY7psAtgqFv11ddojljZJl4wb7igD4KOxg8Sp4tHnF+580ZRLGkd2gXsFdcA0BXALUN3Dp5Ut//i/tgljx5" ..
	"cor/fwJ8pSyRjeyXa4raZyV5Hwja3xAD52ZECJr+pLYgC3B5o5HObaDWFNjqQXodYqGWDhtfvl5JeLgTbZMnaqJoPXTCcCNlZS70" ..
	"Zu2wJjYzB6Gf9OrGIe7USnciivMZujEXbKz6x4a4bErJU+DhKLtyy+1iC0UkazqYWsxx6PnFQXOpKtEYnA5t90jQNPOF99eSQGtS" ..
	"gCosulja/cunPsp31eB6BDxmy2j3LCZoFz03Tm9EQ+w1Z2wiwHGkNs/FOHngC1X1Mf6p83Jgb0vQjjECMa4G4EWR+oKU4vcNUJqr" ..
	"TNcSxand45CFENycARF5iyPO2eScIRolnjqCuPIb2cAelsjAsxETytXo6Ntq11K6Qh3B99d6fQUnl9f9BVO/W5Ky4GxA9tyUEFqD" ..
	"CyCpIdW8nNzKcrWCXRiyRz/6twp92ME+Fa0sD4++SkrQ6ltPX6jmz6ScbG/VI+wTQwoAqF3iaNu5jO8p9CvWdUJMI9ezvd92exD1" ..
	"RSy9EpuLQoQeAA5Td7j9MaZzhlci91mxuiar97zj/zKyUCRdToqxaTFHQ9KYvdHmxuUIz1QP2L8n7xrWxWa8dH0kvdpLxZYb/5Yw" ..
	"gBeEZ19c3nkJNlR7IH5FPhKy2jkZpoAzj/HJS5MPT2HCB3h/3qULva54BJ6MEz+lNTtcLQ1kp6bBQbC9CkmbmchqYXY8FzaKSd/+" ..
	"X7eUoelITWJohaglkPp2u7Uf2fMpcHF+Czv4GPWwekv7O8IdIzVbsvupG1lkGyzJvb+4GgR0oXYYngy+83SGwKQ1eOv4gqOOCR7w" ..
	"kLdTSF/CQ8vm+8xWI77lptmiEroVccfibJ7hAiYwHj4Y905yQPkvf7EiJKMTcdl781VQndL3O3dhaxiJB649MwK5X0xH+t6CXXlE" ..
	"wn+4ZOy0c6/y3G+6ctKky/zlfAEanSX+SDx/g+utNzJaVI8tPBtGOPsLKknAA+UTdcLT2MPUNBHHCaaaA8huCE9yfWdy+UFDMNZ7" ..
	"Ox1kr5Gj9BB46b9c6DPMGJm8g8CFDiLx7WEhopoXOTU4yJeCQcbB06nSAwoF34FsKzWtu/p2lsofsbXWRZF5MOHpPBpMZNZIvIUX" ..
	"aweIh+lwKQKxi69IXeEvGgxoOEsv8+DxHXDEH4RKw19FxBiFw8bukyZSzQsknWR6kRHW9+7fYT3DRdvuhCKIFMtLW0NBEQpN4kHI" ..
	"xUMOPVeOr/Cu0Cy1Bxr4pi0n5DKoQgFaSbE3LiR/jrQBKysCUwiHRpCD8nBJlEdjcVBZcgZwfrMoLtOD4pRt3N9IsJAvPftn2cFG" ..
	"vIKQq89+sraN0utcNgmfcvgH7iBb14kpAWtcb9w+BG02E2wUJwXBUfMoMW39PXBXdElp68ErEaBWSWHioNKtIODnxl6Z+/4OdNYb" ..
	"6LtF9IAv9X1aWULylAZP3gFGB+b90nMMzQvcuwZ9JyFE5eJqPAMFnuT5gI//GKoHA5aW+CZMIutdkF6HD9lg38zSBZGqJTBXKXsy" ..
	"AUh6YDSSxUv8pyVA8R7aH/MRa1MtQDmUlSAFZVX3D1aEkNB9RkwnEmllmRxQmgqJqv74CXru33gbqMydUJ6vtGc21I2CYmcfXBhf" ..
	"FrlKq6agAECB7I7iQD6mfqPj+JGWVLUEapV3RrFcGJjCUHF6KS+9PeDF+EY59h/wET2qCJHGrPSL+vKSbwIk8EpDkNYV0VoCRc5v" ..
	""
local PAYLOAD_P4 =
	"J0l/O0d1wn66P3ZtzmWZPZKgQRND7twETZgTklYeNw5R/sBy1v/uI4JlUSaQscOTv/zSmZ5hKRYQVeJDEdFPMSPgxYPWvpwOEIo+" ..
	"bY4BwA6IoT3RMtjYtw8eyr1JTJ3Wd2X/6jGsuBiQUxeqdQvfIIeubHgWOFulwr8z6mEGoWGbeofjPMYW6Ws8Jv3wy96nKJY0B93G" ..
	"ASabSjonNSkA+6O7lApQCiuJOpBfuhX/srcLZaT5q/UUR+4o2oNqrdov6een4qvLCDrMYAUKho4S7taM8lKfCwqZ2A9sK1OyM9rc" ..
	"zlOsmG6B2FHhQuZjAcqLjP9NmrgO2nS6zn1T5Cstvsoh2KTtu7UaodQIrtjUK0tYtiFX3X9mrJj66uE0UCIhovKh8dFG4O4pALF8" ..
	"dCljMKjFYWMI+QjSzexCTBMrCERLywFnF459YlpuJK/xsiBDHcvlhMAKTWO2LDfp3HuKkM3RA9r78W6eW4iOttGrLBsHlbF60Qea" ..
	"X6g3tWmn1uRAJbeNbF12ZxbOoKlw4iD0SG7yjxPzAP7TmYbXuUjjQrWwd+LToVlCNE0azbJLdvwSFlRKxZefJ6eBnN+F7wxUml0R" ..
	"oYg2wx+CmzRQonCxbFeMADD/49ju74/HtCgsDRYAA1l4aZ09x2Obrym4NjHUjUq6yLDZInN3fG0jeARdjgNXPI8oskexL85Lclgf" ..
	"oa9eo0qTjTlUSx7QF9taTCIlDSq7MhbMX6EDtvyj/cHbOuqWytLNEM/mfGDsujQhwkYc+RbkeXnGBS4+gYtJcceti9vf5RTvtELc" ..
	"udt2MHJWzJ1gAEPL0jIhsBNJGZ979MBTLYqbjYHNUSrYSjORPPCj8Bef9jpXn3H+TsxLKsSsXVaAOHmROqx0LOORlmML12GGtoVn" ..
	"Vam3xtTTRFe0g402JjFpuGxwhgCgmvsTcY6EtOZhZwfQuv1pMuhDahpyJMEeL8relTSPoGUpGr8jG4H/48YF1OjAhHa1MCxFPNww" ..
	"QZ7mWlGheLnPNcRb1VYNu+cWXDXk/MPHqnLKh5yxpxTBR7Q/iTAUZpQjzgywZl0YuogzU8BegDZjbg+v22KVdoA1SHeJSuFPkdL3" ..
	"9g+Y/ZpZJSQQeN7wb2nn36lrEz37SD1PqjGRMmkVcg5XFDK3mJ1wzwXY17z3YogDQGiqzi//Cb85+E/rSI66E6GYDGC0atsk9lBO" ..
	"mWOx/XdZH2hrhxrDfq7l39H5KZkOAdZ9q9WvJrvWsqU9ZAL5jOlRr9v2GVM7LcYcFS+gveEpaDBTo9Wi2DXr2rsjs1gBZCm4dyJv" ..
	"jWPUCa9OQkWXVqgYKwUSgM6jUIDSL0tZ5qCWZ0eBrczAoQ3R8p7fQvzLEjZXtDgAYlPJrEVpqEc9BE9BJj+Ldp5cyCqIzMpxQogm" ..
	"IsErclPj64XSGAQx3UMviW1e7ODdbL/ViyIRBQ0cF9nPmuIKqzsE4+wNhKf/ek9MlO8aZHli6x9VvDeEzlf3VEKAdvJnp6B2Frte" ..
	"nnPMu+L/NaWxbPKzOxFAHreA7B1cyp/KjYvJTUbHJscJfiu7N+CNg9CUYg+rNVVqVMQ8tAg8BYbWmNEWMtpn+lFTeA92MTsid/Ox" ..
	"niEHthRpXcAWsEwcvxPQSpHtYNoxJvb+TCPFVvDEAa6hMNlC8b24tqi6pW+aT4EiZ/zaDxta5tuTqSPSYHrAIAhPlaXWeEhrQs4w" ..
	"z3UHe8qzVGixHLsN63PDvdSXLVOsFZdXZIuTm+RajpINdKIEo30/BJJHMJI4avSpw25pfuuYQEruL2RobLxrFRdkGOjiF5dUePfT" ..
	"DYbo05LR4yMNzlskWvvi0U98qvKob+TiPUyq4MaLAc7nAJAevmwuF6AjRm0Jw4+UYF2YkBtp6oluzZA36J5CZIbv1XZADGOvjnA9" ..
	"QPUq4GXGqQIA760bk2iailjfJKAGAQcSo8XXoIJtEAIeURbwC2PurSMBS16N0dfEehnQuSYyK16k0kWSc30FEN4hwD//Xz+68DoT" ..
	"FEHcuZu5ri1EoRbgco9bhGgoTTYNiM17diGFS2CTgzoP7SlnRi1IfeWVCgGzFQ+DzuSJckBM7xEZXr+CoSYIdFO4W48TASbQNjXV" ..
	"+csk4q5g6MGk2Wbg9ayITz5L2gmnc1VRS91kWVlNoEJxB5XmbhoIFxlwV4hzeJPgPuR9oyHzhjEd1WIMvJGRiBTw604u+s5kJyaR" ..
	"Tuc5yPHMQG0YtbzxG3a/ymZMoiVuLf0UcVrTrP8h9keYdnwLAoLqQt6a1QV3U2uStIe3TwifH6Fv3dM59BVI2jvkSinVWc+amcle" ..
	"ej04mcGNJXSe74qRevt8Bqyp+iNUblgkG8v4UGo2H84MMIOvBCxGUtMnl6Tnme5juadh0SeCI00crLDCoTzpcrmzhWqQjD5LAg8K" ..
	"6jNilMzNjdXt2QR2EOfPJUHWao0LlRtM8mccbnI9fDgaSaAX4nSvQMYENCV/SEgYfigEF/c1RzE7IofCm7+DOne4xtKVEifg+PEC" ..
	"56Csan6lMagsaq9br/g2x4OiQthFisBhvU9KHnHUG8nTJRfuTUgzU4bYk5cQsDdaJlC/HB1gdNI0b3C4xhbiKvuoCOyF2MaPdAru" ..
	"/0tEqMnKGvoEHOYlcQley6b/7XE3BZ/ZlhQKqWTnO+ATUGQYeD0L/rJOH+Vo+8HussAUGr/Mi1gCWYnzaznQ+ad6l2i71On0fz0e" ..
	"vUbWnRvCUELSMS9UD8E9mKRDSnBIJIkjrnNuN3C0xBxS6jntqZtGCYJcJi/TbOLq+pHEK0dINmQhrrg533bEaiRe6CrtIhZZMr42" ..
	"iVPMyWOFb3s2kpsnDTm6579D12wyXuvc1keRsAa3ehvqhAJ9iHnz7VhB1J0KMpJZRoAybWawmldFV3TqAsegSpSpLfwB4/hEkdlD" ..
	"6jaBoRhdNx5NB2xJHFMi9+OZKTc3ebQ5ClFlD7vLFDAk2sFgFnf7nY2C/aol2vuqe+pszwYFhU26Yk3ePf0rdSu+f3YZfaXMP37Y" ..
	"hHP3XFJ8Bzd90aPSayzmHGtI1mfs2xrS8GX3gTKoUpEiP4Y2uicioG20w7HeKk6iIz5QvEyu5mNkPMbIKY/kd4glYgFtAEQ6mrnU" ..
	"uHiY2EfADpKOqi2nDSf5+U1OYQS4CB06UhzO1Ly8zvzapiK6aIRwT0KDh33kOmt4w7W5zW/Nz0yW7Kdr6VELDXaqjxyrW8/z2f8a" ..
	"ZvbB7YBA2ETXclcEd9WkycJn47/JHWB7aPeF9muw2b56Y4PUxOw34D0FqggZTzsuW0oRaeBjk6+YnnPg/S661K0yS6wuZ7UR24z3" ..
	"Bgc0TB+t3Y1p/Ll1fOESQiY/iC5yoNOg81sBMePNCW0EjaMbpygQI2llKRAysKA9T9ttFGUk30Pc7gVBm6+syBhxgLLOPA6mZyFZ" ..
	"MOFOcWyKykmDKmGTTlHQc+FS584kOVqscjmQ5qTr8QIsEpo84HZ3bamTUJnu18dECHiCj4+dlEfKG5VMj5RuEiLLx7+d+dQleAIL" ..
	"9Bx3uvNcd/KNoTWiVxKCrwAdqQKqRAaIbJ98t+ugFS8bYWmLMf+hFvO5CpbSZWaizVPr18mS3X0BMW6z6hmxf93n+/FVk0OrLjXO" ..
	"jvYEdPzVebVrsB00/CG5y17eIhNVGrWT9w5LSPR23V/eSdkqH+APHddo8WG515rTLJz8VMbw0nawbnzWdNIRwKQccMZKrlzmI5D+" ..
	"3ciFCHpMucs1X3Hu1s1yW/ynWqafUCJFIxOgVQr+m0+yghK7QBkRKJfON7pO2NPmBj3UjHhC7IG1O5HDcwz2yQ3yyzBH5sn8Kxu+" ..
	"fz9z6sBTcIJoofy4OBnFs8WBQWLJWy5ZVfZMtuR077Hi7XIpx1458rzqskChAXCKA2DTbkuB/tAMD86f3oxWqLvmdQc4mEgwk0C5" ..
	"g6sEJ60upLCHvKTHXk2kIy2UvFnxg2jwSFAddKedzEAb/nZOWDvopfj4cq/ZtT0Gd1lE8o0kc26unrSVWirdVtwniBti7AFHNDQp" ..
	"/u8nup+UjpraMTy11Y8CeCBBYZREvwl8KLHUQWp3nPE6QMw4RJvJlnPYMEs8oweVQzF776Tp/VAGC9qBMDDq1Kcq4B5gXgqNgGN+" ..
	"JK4fGJ3BlmktkMHSwnQiBP3ZpaIARh0Kyzcw95WU6DbSkDwBK1X1OGffv8MCNsR/zwqn9hqUPjB6iEmV6ynqx0J1zXOmYFkDiiUD" ..
	"Otef3ibRsy/fGrDymUDdNWnb8nUxANTXz7iyqEzPKezOrp9k0run4RJNm2LufukYQTONiCd2o++0TRhW093SgdihItKPW7LcmgK5" ..
	"siYn7OKZ/eGaWqVXPOK2VtAKlNKIK5aXg0Tgmh9prOqbDoOQgYYesLmbpS0H/AJGwmOk4qqXJFhSCjckJUNrB2apFcgZjV944B6N" ..
	"khIyfsQoNKfvwmoCq7d7lzIdV306BM6GIX1w6teNb319ugm3ZchIfbE8KSukE6A3CdWa7zb/DYUJ5ThiGE1JbsFhqkHXzSVmzREg" ..
	"2KkpnCAPMF1po5lQK84/KlIF1B5UmUoU8pq7J8sBNk7M+E+TkTrNkhE8stslr/laf5sgNdxFkwqiS2Hoa1ECQBbh9L6Z+h2aGrb0" ..
	"blJle+o4Ojy5Q2f9Rlv8Q2of9owz1boLiIImeaoPytfaeXUnCW9e1Dv15CLNIKtHgOm3TnXnrWHQIjDNQIMPc4olfhrbc/ce7lB8" ..
	"xypUXm26EQ/Gu8QNVWZv29cjZ6Rvhy0hKbsT5GbrjETlxjc4V+tPah79vCQj5LQc0QwFWdi7hPvUZAmuhYO4n415xFRdbOiXWoAQ" ..
	"AxsQWy308vlJSU6QvZfyVd9G/Ig9rg7UFPVFjwdXi3+n4uc4OS41d0oj0FHvtLCyge0QIdh1mQySfao7qfhXzbIM4PMj/NR2Vs5b" ..
	"neRUOyERG/JAW8lf5rUNSEdXIi+x4HtjnHdF/FTHMnT25Dd9OGKtggyTBf8TLiD7gG9iw9Cz3JBWYl6Up5wpodlOpMcnj1M+62cK" ..
	"Id3XKGNqRkT4d1WyTHfX5dlOjfT9RBtF5nXcacZ9aGH8XX/mxApYYE/cb/a057bRgCrO4nSeLxiKTbvCXrXp8J63RyF0oWNpcnjI" ..
	"JW7kkonoYk+j3xmFAPN7kqNrN/6igKIUiun1klxDnbyUcxUXyzq+XKxNvKkQu5QSMPOCszD6HfETkkSJmKsy0dNEdzBRt8j6CP7C" ..
	"0AxWRLL0N1I8y2iXOuLrJ+F+x4obhylGYQdJS0McYrkrdgSa3y2SidNryRjc2NSyWiTa0G67nUeg90U/Jnb8aFHQe2CYiRl2N32i" ..
	"SMONflQsAL+kgEsSoVJATvjYMAWp97KCAlN163p6FKL4rXPVot/IQAFoFNXDP1gsD5Xjs8qMdutOp5JAIJMZmkG/jU3PgCGaj12V" ..
	"TK1b9F1DFPWL0UbuS/x4tGqH5OGlouyB1cS4eKHEQ52V4qO331tDRXqpTSWHRITTHR0jNfvRVqnyRyFOfT6zT+ZYGzr3e08tHqUx" ..
	"JQtiQYWXMdM0kEJEL/niLY/Y+6Cne1TaAj8WMY7PFT0RnZJcQSDU1gMauT3E7KwTbyEmuwG8rFtkaKsFy2AhsG5KlcwnW+U9FSrQ" ..
	"rLBlAUy5tn+G143tsCv920YiK9ES0XMdINPx376F3P6uFrb+xWVaQqYvdYflwzuvv+X895fB2fvp4juk+o2Fm6CmcAsdzholDw3+" ..
	"vde0vY7XsXD6ynAf4MunbyC//rlVf2EVojQIaOp7Mm3CnSQxuxSJhg46jr8KilY7JQyMUC92ggj9Hp1vZPBcc5jZIvElAIHg00aD" ..
	"PoprWKKbYM1seocQRB9Nf7T019ng/p/UFO0XlZE6EuO73ZB9dkfi1EQshkFxOt82V2l+9n/usl4JIXYtVWE8j8hxcRhTnk2DDxGB" ..
	"J4lW7RWguMCATO7TIvSO9mO8yHTrcofzIubV4GfP7wMow1deZkWAecqi/u4dwYhPFmogDAFn+OjfBhogTiMI6LjuKnP/lea3Eb+S" ..
	""
local PAYLOAD_P5 =
	"+8yJq2UZ/F74CtUapSt2BGtLmXpK9rI1wz0S3CURqAEUa/vvUXFxdWl+s8+Tm3EXuVTVfAEf5PROgXwF691xuEsWHJKSHIG6uRB/" ..
	"2JLm1baw7LWk/3Jna0acwqtW/kYPiEY0rUMZaN9NSGkfCBXM7hKgqofC3qhvnIO9r6oO/OZnoJ+RNKabALaM76DWNYbxIdyoQyNk" ..
	"QMEgD123Rx/sASY/tWWDPdHYgHanqDHC5G+X3rrcTrvr3kTnUAbjQ1bvRv/clf4OdZz8mjiYZ/+un0pk0GvkNkNXriLneACjs2y6" ..
	"jW/jUeo6CxW1pTYMMyDEDWNFG3ou8Z6VhKJB56l36q5WB6r4cMrjarYfXAxqDwWO6U3wC4sFmiW0ZovRxNEnPUGyytqTiT53XoDJ" ..
	"c4XaJL6U68bBr/N28FBvWa8x1QCvswXmINcfNxU4KQHc+A9qbAUnO8PM8/HROHSpyFvAp7xrIrefikxNEuW0wGyXa0AEf3bhLpcT" ..
	"MHtzqK/vHUVSdpiXr70L3/GcYia5P0sylS2TfB973/zqfFPWXbz1JiFxyIrIWFmb9KWNPeoYYnI9aR04CSkkIHW/dKkNvVPgnnds" ..
	"qvbQ/t50srg9mopgM58AiMdxphKzL2vIxmxanF9CfDsg8UI+XNY1iwcHAcuHlI7lumEEtYZd2Vl47/jIZYMEW2KQxbk5fHD6cUjv" ..
	"7KAxWINOn2jhYiU9E7twk8D+F6UzvcMJb9N8p41oJjRrNVSXct72/yfH8ZAlwWbv2gauGOvagatIwOYf7EmdiSdkBdPSrJNyhb5m" ..
	"+uWIm9gFxJ1+u70D00bt4hW8UI95AwZIHDrRHK+V+8qDzPFwiM5O7veqo1qEnJI4nD2qLx8uAobGa1hw0Dzr4NLmjX5XTUCj/6dv" ..
	"iiVvZc12NwFw5cZxulnh+s7QzFnh/o0SD7HivxL2otIBi43mOOzIWJLpiLrkJIPf9Ll0AYo93wH7Ki4jDMWAkFwxs6feMLrY0M5a" ..
	"R1NWb5WwK9v3UfpRKPNhK0eTQ6TuCnGRlrp2Fod6Nhndd64QuTdmv6vlnoCJypYh+NEC4PjkscCTmOjzfO7E+4efOUiNi3yRqbzU" ..
	"39XXGgkzrORkIA72pWeYiIti9/iYLjiVofFvljct3cDvOc9Ra3qv3aovlXec6ExDnW4zTgDOUBIKSKfYwrrad8NxOC3x8gVi6RN1" ..
	"TcoiQJKo/UzHZlhiG6GjmaDEqMeF7i5colSvPhPh3+gR/i/pbWxLnqxBGFq+mmatsS7hCmb00uttvm/6pH2T7vXDkG1wsVsZPCZo" ..
	"jF6+CANGhMWCFfaycAXS3Kwwtpk2xc4rBFktDnRpwezza6GGzFC4UaaqlRvVMf3KvH/2sodSVhHkIZvcwtj2yj5cxnL5zaLcEsmz" ..
	"WZAhYTF0HeepU/TAUonh7dR9MTwinlkjJWwhgokBsYW8cFWf8Bjsdhd/EsXEW4h4gvPcsXBOZh5RV9+z91yTGnvJHjj/Ul1yja6c" ..
	"sCKRlvNun1uujXlVQXfvuxGkY3ghX6ikwYVVCkJ5IkJvN7FQmZCgmD1WPygDOpc/tWStNw3YMMjYNLCZZB5dGxcFElyXnHEGE5Ha" ..
	"yX+2dtChRaYY3ZO1pKTO0OQsL+TJlppQ1MhHcinYQJakDYIfGGYDyk8ElkO3P3EUg+qaND32HnNpBHakbObvPXr8HTKLQZtm1l76" ..
	"yJveaahVu4Z79sVQXtzY2seJ64qqcijXPf7mmv6HOUG7M2a+/iHO6114k8DAs7KhE5jnITN9h/9AwXbbz+XJTV7uSDvUjy5ST5ZZ" ..
	"ZXlyxcQbSeeEiRG9OpFV9zpNeZPMM074xuOmGOXmLiNNHNffVsF/GmGmmDY0Nn3obeH/+L6aI4rblH/mUNkL+LJNNyLiA8Jau8z7" ..
	"P1h+ogTsL3/cpNzdkTbkY3ynCeQg20uS3s8I1qo0Q0ipyxHFBbAc4LORN+bH91qPMq323JZVJ/SoTyRpLnzO/d1wewmZNd64r2BI" ..
	"Y+P8KJbIQx3CdPoVxADN78CyCES5uPG2xCJrfVM/xRO14TC+fTJybOtQJmjfQ2uZpS0NCKxeJgwrXq1aIXk74tcXyc4MHUplGQ42" ..
	"HTjYpGhX1CLoSfHMn8YJkTQOsvn21K5BOjg4ZZtJj/Aeibs1T3COcdto4eQUX+3qns2nIVn7MlKvZVKKQI3oaQhxDU9a3+1P/mph" ..
	"XZ8bB4PguOXKP51sqydFvlRYk4kwavYNg3ZDfvDwBztRu6YvQk1AHzncpgNEtRiF98v2D7Qzc8jjzp8LodPzjuNwhWh/pBY3HvAv" ..
	"2CQA60ROyQMaDDusTQmwsBp7f0MsdpoAxjs0F/S1KqAgG1r9az+wqG13CFoH/+cWpag//VPtfEkGTc2/lDGCFo9nI5j7lCT73H3i" ..
	"5u9pWvv4JAcBjTGiCs6O1QBQ31RJ9gDJn/bHa2fbHtJNTJvk+8EWz7vARor8xgL7CaIXSBsR5sN5XxXmLUMou7iGbycoFX1Yon9z" ..
	"ePhTHO7Wa+oL72WdDVb3Ee8aHDyFZhNJCeqSqgttjVb9Ebkzf24uqx1YUz5zLgvTGIThsX7JzIAJ8uUxyMgR0mBEAo8YjudmmATO" ..
	"VbFNoz290TQrG5gZmscMoUVuldRFVc3day+bOnIgu8F4S/Diea3zn+bqJoiQcyMTd8vYfi9WuZNrKRkUU1yfpjD9F/2sVZTUm/B2" ..
	"D+Q339e6SYFIsBqE74D4IHXnvU1tqHliLYXpDBH7B2WXDFN8wYbH4jCaEcx8KA/CWihbz1ofQlSxNeCf0bSKIlGv0ZvMEh/F3tDB" ..
	"V0DCm3/XMAXTxQFDIfITXFEuOAU2MUenO+tgZ21RMnDYBIed5pxxBPdCrEa4Fb6vrgYRkld1CDHrXtf3odG3nk6FUeWkT3VMmULX" ..
	"/PvN8SEmGfGXLSVAwuKFkK6bdTwt8xo78TWgES2Lc338scHTlJr2BoMKpVRcFjfsayWNeeVPMWU1sqhXFa61aJmJuY8UAuwlGqdR" ..
	"Yk5ZB4jr7sVqhm6uYjQd4yJ4x4pkwE7vZ1eCNsZZY4ca4x82qMCrR99L1QKkH39OezvCiHbRLUpfYsR6+vRfmjTpx+235ivKdSCF" ..
	"HMXobXl1fGGHBtpWF85kA9TCpPFifLv3TAzJGn+IypKOIs8LNyUbdRHGeEgE74ZFx0w0FQFW/CvNOJNJV5CQDbsR+6O4YgfhOvVZ" ..
	"azORroBgm8eFWu9Z3fYFqtThDRKvSrf5ltjAOuAeLZhtO8n7oxlOJ7rJRnX18k/bl4X310p8fmtfbM0JCRt2kMV9u/pScNaHgAar" ..
	"GLCNNGcAsP+5QvZCjKjdCJhd1lEfdZFxxxArh21fq3mIUVQY+/5RRWVhjlax2D0Kvtdeedh9bQzbvpYn76ttr/iN33y72t09mCie" ..
	"LnA5wgDdVTcf+zkuJTk/F6ceuLzweC4f8Vi32RCLg6Te6c2x/rjrXK1vQtTeKjlJFDIeYL0z9KEl2ich+fjhVvKDKskYacaFcwdz" ..
	"z+anzeGxab2G8ktKIPcMpXE0+x9/sax4hCBtf/+I0w/QQ2R7BLqVGwD9ZgHVwbcouJOyp2RvdUs2wfe0FqqSiNPvgikum7eTXnnw" ..
	"w/p7C6rw3+zqUIiW2vHN4iTacjcF8n+lfE4tG3whWVFod4ejHZf83jtpV3Uj5r2qLI7qeqIh9lNFJm7zVD+BTkmaabOOYzETDSVX" ..
	"1GPbBayWhPdlNgGryChYOwmQH9N1/MK2z4j5eWJezPiYQ/lEu0q0TbZTgY1xTFgTfiZYdgIOH2GvfxU2o2xEXjC3irmUfjoNTAng" ..
	"FLm5XqJKrktIWtrmR7h2fDNTIOwH4vhgQXheezRvxZWV/5lkAMQe18T4HV/hA3iZVnQ+RvD0StOuo+s0jH5lHb/P3RVLAUViwlG1" ..
	"qMUlYFjzKN/XdcZqRch8mDDQTC1ExroMOPCOxV68YrRG1VLBwGNtL4vr3lbBbbKZboD1ZFrDAxeuQ+IupoTmwLB7vPrmquRxYyN8" ..
	"n06fs4E8/NbJbI3xupWDrQcaSomzfv+Q9Zrq8iZ4HpsWHpsxMILAiLyVG7AsQM+FkxSwswvr3krawzqmEHWn3oO0poZjgDTwwV7M" ..
	"8dEGaGH8xxe6hemEBPRlh6R5vXuL6hacqN/wCr0PS7aN2wZ5z+lihaWfe5tn/whtTWLNhDe8EyRZDwVdfEjFLqnxcLGbqaPU7MoI" ..
	"uaTW1lm17TnGbSQquXxbYaIyoHHYBE9S1B2vXDgYersrT338LFy2wnaelKEZ4OpasnK8QX7h5DW7WWX84CAez8U2HwwqdFhYNvJB" ..
	"TMo1JOX3ZgOJg5NO2YgRGorgoywQaOmfaF4dy8Mf3ly4ytMIOpydymIduhJfSLNmTFLzTm3LqMv1W0pUiZGhkfJvO9J4zTSs2n5u" ..
	"v02SyRWhoEw57NTCFblmLqjXQe9dyuaeLC8zcXoLVOYX3GwGfOTtHYM1QLTk5P97/pu81M+YlwGmFbamG8AneJ7MR8xIIIW4icKV" ..
	"JxEZcTVB3EXJWVuydVH3qXJCXuHV/4YuTHQVrivFvMxbywKIzbWGsuRBxIo8fAHEzPPro4WZYT1JpwNhSAo2IJH41JBm9twYmGVe" ..
	"0CQS6QwqN0bzFUGvhp75yRYDBr0FN+MpIpnd9RNhd0JIsTG1JFLUvH2TgvgK06HTPY6q0PlRmj7UQqvsbrUiTmNj58km5ktue+Hi" ..
	"qRuE9r01p++ehlio74GX/Gdippys6W2Oel9tMYKYErnUMcSMRaF6RvJFDDBBSOk4JyMQtR/gHuZwA1roFoab4lwN1/zETcZFkx6Y" ..
	"j6T5H0+cUkjbnlLXxiD0pCHhLmkVivpd0auSNl1504o+Fll0fuk2xXO8T2v19C4Bp2TDxzst6eg8mRBnkterMrXwY7oAyvB0q2gS" ..
	"sUqULdXB4AiPggXY7PZMSgmy0XChNT0CW4Kekrc1klVTD8TaXfVgny1cecCpynuIyO/Z42RsIYrAACqgLv/IUGjIMHHVEWhHMvtl" ..
	"+4u4pWJyJnEajkIH1YDJpp6V3DotvhNTOHF/0zMx1VCADDqngY1Rz/nBx9TfFYKmTF8mqU+s1r+k1fCdldYcMxwLJKlakC0W+mWx" ..
	"n/oX78JvUHzbgt5o/38jsPAqGquTkLFau0br6d/hwqQaXRyKXrKP1jI/8TDtIcwPIqxFquKFKa451gFjxULydxeZ0kPkawMM3rqg" ..
	"9greTpD/PAKIfjBLj0hYxMTWglNCycpgZI5+F8FooHCayHOp5fUF09QIL64J2BjweZmFuwM8wFia1RZsdtcONfh72ZSueIitjjwy" ..
	"3bH1BdmDXKTTR7rMRE7Vlp69N13cYp6FoM/PuY5WmD3min/JJf2LYsCciAHWRNknvpqPEdLAbHCgn9WxTqO2xRJk5V6QSi00oKhU" ..
	"gVc6oihBj3c5WjSHc1gLxCwHTLEtkvjflQlcqhaVquCOMMmYyeIWPC1CRcBAgQKPyoslclenp50CBdHBgV059QFWm4On/tuhXcdu" ..
	"gSMS4ZXc8VZ63clU4DCxIDZx9sRktJrYFShKWnjlqFmyhh+p0LcmdkDIbqWG8H+2TbViNhi90Ooe6vpc13xZo5tfkaMje1sxTKGO" ..
	"0tJBJuj4yEmIWHB0ORQK+qWlXsUUuALTYA79e2RXMikVpW/9PEuk9ATte2n4GZUN+sRdQp+VFn2i9eaBnXchbnn9Arm/8CBOH6rU" ..
	"y4DA9skc0WqwoB1xgd1FPsEBZhUYEMnDthGUELYV2AeY1PZhsCnkW40BDU6it88ac2KrKEAtc8xV4Ai5D1HWbWN9uNHG87icpHCo" ..
	"UhMwLWJmL5TZRQD16yC8PKbq+IJu37POQuLnS5OVAbyfVnB/FeOo5sOPS2O7uiy3jbOl+qvtnkTKAOiwcM9Mw/Z0mgp/VyUoWZ4g" ..
	"DAOp4Ton5xJbx/vvhYg97jVdxCaldpFnmJ5Jw8k+466z8RC5JfuKV3CTlJ2OfWc+8+10p4sNif1PgLIgE2DxFB4rssulvvn5iVC9" ..
	""
local PAYLOAD_P6 =
	"UMl5PUKxV1iOzrNwLpvfFDr5vd5NuL8DmRlnrJRjNQYdQIwg6fXlRhTX72nccNkiEMhnaDwrHtvIdKhzLhf3vyaY/qg1n7puK7dX" ..
	"LKkfCK8FH+oGbEjDmwuoxRLE6EWgcCmAJkqBfwVduxSd5xSf0tGuNDLks1c22WcviDOrG3sOPRI6S7QqSwD3Vh5mqopiBWmS+yPM" ..
	"U5OIM9Iq2LKVrqfqtv8xPCC99EZUZlpL4Hi4HFFwb8xkNR/OwNZnAMQ74gctQ0rVZ0Gwgn0EtIAJoxX/xYcyvebyTwbP0m8itDfS" ..
	"p1CjSLwSoSCs/UJutlciw1eHXvfvvN4WkLU6AdnYpusxyoyad8KzpWFz/5gRtsBoNjE2CKZQuIxdCg9f5Oij3czS1GBUSLFJ8h+m" ..
	"u7tnhPnz2dvi9TwKZmqtTCAxnfEiEOi2Hh756XGMXn0j7izJtx1jXIUC20uHFsF+Kj6xWnu+AZbxPdEwMN2Im8A/001ZEcnv8QOE" ..
	"8XVfFnHBN6UJAWKiZazhsX0aj08eu86vRenOXth9xobRCemxQ0Ku54PJbIhzk/sBfyC+SnCtDTCGiJP/Tyeo179eS5fc91lbjKpD" ..
	"1VEIXYlx4hEyOOWfEtwUNgJUJ3o5OdgBv9JD9r97fLkezye0Kb/Q7UMORHrxAGpPPP93lCt51xhvv9ORrNmvFE7iw9KiKQkbaQCl" ..
	"//nM7cJPh05ZHgFKHyZI7+p3rW5lBCyEy2JA8N2LwAetao1ChL4Aktc68Btd2nxj47HkWq0nIpt+RIEd8JtUuJV340uSSKqUzulo" ..
	"3vtYUT558ca6EUX9qEt4yh731bPoCJcmrtnoHE/u2QgIRSquEMStkkNN0JGg8ZsXx9VSi9wMJSx5DNsWz+YLfibJV6te66BGeQNP" ..
	"r6rBbp4jwUajIlPKq8H1jYeMzTgYv7QPSCyRfaDfX/5vxxvzB1Ru1JOGAay9zlJKBL5mHD2ln9BeLY5RIYt1ZtAxNYVQOjbTQjqj" ..
	"h/b2GwUAqpDxTwYrG6zHbpshRGtRem2K6FEaIMvZt8TOqQlFhoWzzteRXt77LcZXOnqSpGZKOcA8dlWMWy1AcwlIKi9O0BRyD1tP" ..
	"pa8AJy+4MaIMwep2Q108V46BPYBC8ihJAjTTAkVcQQSTZT/n2tJ3IUcBvZ6fXEJSHhRkyZ8MD6PH38qP36HH1IbsXIAQDdemftaQ" ..
	"0BbYbEaLVvUqu+Ewz8h7eje6f7XEGOjhzgUR+i1wECiYjB+zL3uFjyQhIYVoYosXxYihamoB/lLs8iZHb918L8jtaeMLzefHk44O" ..
	"ghTrn/wp+TV298pjnoB+XpVToh8xGu8JjAYZqe5+Q8hDFNNPDlp6Rp3tJ0pwQqZpagnS7bGX/kkvKfDi/EUoMxbwG9ELsSXIFIG/" ..
	"yJKLqq9gr0ygUVDrjposcE1mIHGHmGrY4E+fXxsPRwRW3FYwtLCMOMurqbNEAukF45DKwxxYE45Oa+kKMjmyvFmnRwDNV8sl45SC" ..
	"yoljdrezDlCALnV08vz6ceMkoE8ISOrCPGmxniKgIajBVEgGjvR3j4/gUQix9OeahnU1PUi/gINlUgMzk5d6aOGa067QGno0fBZ4" ..
	"jYdMQzhc2hc8YPFj54QnRzYcnMKAZIqAibvFlVh5PfJOmm2GcBjiVrlhDof9NVlmM5dohKKeJDtJIXr36G+oV80P7Oo/VEtoudc1" ..
	"1m79l7Azdc+CkDbWc5RklKUPAmS1twrT2X6APKQKtxDX6J7teLn0I8MaRgnwrEClzYkdGmEUQ2oANpX8aj4TquW7xeoSexbzak35" ..
	"FJnNQTljh5NnIfKEIViHRZvt1PfrsjbsYmFC5cpSAulgBSBG24KJN4MaGogGUQlgKdStd7KJmBLDmPmtFwjEl658E1cB0PYKfFaw" ..
	"XH0okAXqScAvS5hatQRcWd7FDoL430zj+Xb+E0BngScHOjXclhBU0Mwmhw5dC7jSa+YDRpazaqYATYAydm7KdsnxmahwS7yR6mBc" ..
	"6+NewLAv6Jat5C6cCSFGeifIe/QqVKThA7+hCYzjK46qSFz7vUZRuDWBs2NgrHxH+ZUK4J3mjJo74aDG4GNbe0eR8NIjEyPvp9oN" ..
	"uSXLChwIyXSy13svSetFBmmu8WzgTg97xtllamxeHddcJ3OwbZtjveLwwGlpR45cQ3TFBCPSPhUtOlO88a9zlw93SjjwPwtlo7e0" ..
	"s4bWIZtuE4bRuHrrBMhWRou8xGEUwTPIYOOTxpDUtTKZoP7zBmT+aypzTBI/svSvaudgmuPY6C8GE2uYXUbz12ZoZucLFsMoXf1C" ..
	"FG5YViV5LLB2IUPSD+H3AQsijShOjAztjGTFtKPlZ9D72MdV7ueJoGidx2tTtXOxj3fbvffwvLD49J1Ak9TR8X0Uy69DS328BOiV" ..
	"yjeyxIntkTDbzh6W0I0d1zvf363vLfpB1H5RzIzfEUBe7uB0Cj1D3k7pwN/N/5CI42y35IgcLos13RWrR4SNHD4fSYMeeUxhTJ2B" ..
	"8lTbREe9uTje3H+8l3ihtxl9nJwoOvDoQxBQnmA4VgMzcz7o6q833it/feXXd0y4UlNgImNbDvWXBa3hGYwmqHPkpdmNIybyzeJi" ..
	"qEvrelGiag9QfhU3FWPPMhyzMHKd/9YhEX+rphZww4k8aKI5VNocA6eT1qTO7x64hdFzrG8m/HFU7tSmRs2X3Uu9sS3WMfs5kSp8" ..
	"ne4dLBkPA2nAwO/Z6/cYRlEpEzkaYO9jKQ1lDd28AmRX+umkpkuH8ly1j6r3yrGiwnqTUSIUg3Fn3KqxNej+MKi6TdoAyVy8D4sd" ..
	"fBBrvFzBWpJJXYEFEkjqx6inuWh4ltUhdOVJAN8rKePX6gaO4x2kVsqXot6Zr3VCsg4bRiDYYdiW2ovLv/BpXWRDzAq903Vq+KyA" ..
	"hI1aMqzpxDUMYyjoSvhHVYAMRL49018doDVJJzwZhfVJZTAIqBjIAjsYvpSQSbETZcbL+LHsUGIVuLZ/Ak8JNM/RmsE8ZX/sQVeJ" ..
	"H0I/Q49a5O6huBMjAL16RZNVCNdrKPIo+TW+QOc894eyQxaWnmfi0GWtJtQq8XTadC5O44AW/UmVfcVDO0h3ewbzWqrnZf7LY19w" ..
	"0G8G4ftdMAC3pBBmZ//TtDvxwCz/i8y703PzCqqK7W5N0lOb0xhBAmzKO1gDna9X3Mitpo3tWu+WdbQb03f/v5IcXTnbbf0L/YFm" ..
	"yjsKYaBTyMn9nU4udNSRGpofxwEKOCGHmLLEDOHYXunp9/5kabieq/2aREc/bjefEc/hfhRgFLKqmpzt5IJ92V4fAdM1vr1+G6sG" ..
	"dMGN51JqlE9QVmt3U6WAX6GDYKiUYByErYgo347f4hn8cHz8qyQTceBUKPR+R+xGhJ+wsAmWDYWyDtx/0a4SCSx2iyU2PBzwlAHZ" ..
	"/Rqo7lJ0YJjq9QT23OqpvcsRWStcWE7R5X7AWqqhl8B+mP3E9PvpV1IgAEw3YTksCXpTHFlOaV1wIQ80gNQmI4Guh+Hx8daGHnJ+" ..
	"hJNUUFuTOOXnTyW8bfLt86adpEAeM3ChrbS/+d+SO8mx/mx0pizrgHTGOmzgBlXaMuxDSrDcsk05XJlYqZjv+7I7JSiZrAD17DVG" ..
	"PqvWu3uZLGm7Ibfyz20ZOdyqBoQqg3UMDEC0SZ9HBDjgPiO3hGCaFt1Qb2eiRyO6Ey0xkqQtSykyTinfQS1NqM6Y6bg8O934bTak" ..
	"qKUbdNhc4X/Uw7JX/VYR/aLiHt9DudDdLXGkIa7EOM3D68MZZDVpsNtMdn7HvKtr6hG7GpSAv9VD9F/yjN+y5tqapGE6wBlKRE+x" ..
	"7tOIzwYJ0oGuSx4M6FgV1CKwsfX/+Dz6CqEy81RQ0KLxgZGu0KEXNG5VFdrQA69KMaYr4nXBHactQbaphu6t3YaiAK1YdZJjqzA5" ..
	"Ep6ZCktdz7PPpjPgc5NcLlL6GE2iA6jL18lDBHNzhSVORJgxgm655YtXWw4IMNm5RbJ5V+52LjPhHhDQEBg5j0E/DV/qRox3HRPx" ..
	"dMAj5m+Kyo6ycwz300lxUFf/P7iXBgUAKkXIcTDaANOMnMZwIj6zL6BgOzhbQeV8BkuKpQsKQEwL4Uwoy6iEDsawgisGU7eOXZuo" ..
	"oLvW6QM3qLusNoV7g3DoYbXV2bfc+0Arh9HOzRbuoCQFWio/n//4kBS+hC8inqzbHyjBaBIvcSuh5KENle9ByqNuMX4ytqzLdKEM" ..
	"hm5y7xqP8zC0ZfyuOPLK8R/sItdZi/S1T+icSHkC8szfU5Gvu0kD2b1BYNIfH3UuOodRvrFRRcNMepuu1Ro3Jzg0p1Uttbjg4W9S" ..
	"Ev/41TUF2kXYBU+berPhKVYlXLBjPNG1Ka0lvQV4S1gcA7eF7iCjPaOkUc7MZPig45bwn92QeR/G9r1YtqRj2gXOynRFBzua2w9K" ..
	"9R9+g0dCNDzGVl57pSQ15+l4YbHa3C4wO67akUyh6Um52BIu/kPcUahs1EY7rmYhiDUTilFcTlCSNDHnIk7gRcsYovnEXOguJYlh" ..
	"VaMTeLdmrSwVLglAEubbPt2xVLyhwOO8yoB7whkAbKRbDtxt33ZeY+BXs4CsLNfy6ALE9pTcPOByC6DwAXhE92DXEN0DdvRkjJLX" ..
	"G5ULVDRjra0cizzpNe8XNTfl0LEZBaYGn3AOKxL+l+eBPgw/ube4wEsBGoLUB53T3jeDL4JsnzFH6Enm6sis/1XOjTXo1aHEinkY" ..
	"HUMNqpVk0o48jJM7vEFl/pd1Ak3NF7MU+aLHf+i/cDsXhgs8AfAwozJYYiOsC4IaN/APVrmzzWXZKaay+b9tTdZg9UqrCg4MydXz" ..
	"UasvuIta/2TCJg7pF72P7u+1guyNPGC30ndrpVORv52H+tdrkZFsiDMRdH7MlXaml4oDp3UM4++amhYacy5hevTAEHv2CtxAUsSu" ..
	"ZHPoODNZ2b5TmqEZRyvUZJx+jYc9Yk0KaUbd7xdXs98vdi/URFxpVwEulCIx+Y08qmYlD6qIal9MfSlgGnPkSrNmgrSQ0Pxxs5kx" ..
	"6fLg6a3hkKVGX5KrwexhdFiw+MDwT63uXJYFIOth89tfDr1y7DXtfHjPrUq4LV2udgAelbisFEfi4dXQFnWDHWw5A05yfjHNpK+O" ..
	"/NgKu1fuc444hCTDlogXrL9jlI/+bUZnmvi5fD+TYOUjsH8RvMEVEeZHVyVXfzbYFy2UL5F3D9UHqfysPaDW8LlKvM19+2P9aaCt" ..
	"1LeKnAAagxxLJWdDSLbOKTj/OL2AcgSnzxm1s8MJWE1ZvJGHfR0Q8T+kFnTjX3nb3OP41EJhts7kdfqMU7QNuYf4xWn1E0JRLxXL" ..
	"g6Ly4MZcatN1vQ8v780+NO7wP7HAk5qprUfOLJMCSwEIyqj2AsDdZWdT3GVGTjnxAHM2Vfa0H7wJUE8enV4lkb+dU73l8semhaQi" ..
	"11aGMrjiRQojkRECfn4Wn7yYMuemFYlWhQRAqmumzLXWv2dXhjksTUaZg/1NmXJ7zSHAxyRHTSOJ6ocay6K9W/j84Lx75JV4vZ2F" ..
	"17CyUmZQvLo25BgagFRJ2+CT0r1zPl07/0qFbh+8Qhlm+LqHxbbxOqVa1sQ630sWryeh7hrmO+qiyG8E0wST5YLoHfjkSq1yG1Hk" ..
	"73OyQKv4slpdnDNwgO0MthBWYOpDUZczHfBOnRzJlSvZweQ+flGSK/+Mn/DVHwjVK6YYlfjKdPsNyN+8q3MwxQRgyL65h9aiWpkw" ..
	"y+G3FlCvmkEY0yCzFc/9IaOSFSD07HyzYmSPMNvQ1UDDr65hOJdgpypMc+Vi87WVGopnpAfRY/PNgSdfM/RL/HX1TAE0z7aFh1ad" ..
	"wFZwuZoXpP3G+x7+Q3zpd5qjHvB8Q0cpKb5GsuUojPgQf6INRKj6B/+fdRDo4IGSWwImaMmaH6veEJKlH2l3k3VKkpFoSvVLqYi8" ..
	"dCigQIA0uuj8g2Tiengohbc42PfCMst5mRRUtnVYcYx0wPXJ/fDp44fvuMZ8c9toISXZWFBiwAbYrqRQoraCuzC5dNAtk0p3+Kjv" ..
	""
local PAYLOAD_P7 =
	"zFeqX4j6asjVCvtjO5hnrnChXgeMvdfmhATKUwaNdjrMXrEpoh1+Q22ulMYrdND92kfIUZhWvQMGPmlSKgNte3dGzW4iJnl2FPlM" ..
	"T4cylVzw1vfQkpd1CDOe0j0H/upslMgHPzzG0CHX0Pj/J3Pik/K6qxOxbJgHCeqXH+9B2Ohg9jesI4ms6uMTbmj4kVkbeEQG3L2F" ..
	"Jg5WL+uw57ndYnf2OlL/BmMErYnR1tR1NayzNYrourlSdmt3P2b7GoK7GV4s5YXhPooFxxHHqUM/zjVavPSfK7I4ykLKVHKw296/" ..
	"TWm/qJCoNsfxg7qZ2JjHdcGCh1zDfO8du33it68XQ77aUZhtG/uTPst9Bq5Tm1WuspQOjVntb69osz5OJd/8wFBNfYbgr9UGqiw5" ..
	"Kiw5bxz/zD0mtAQp/hybVy7b3DN5knPvQp5GMZ0B1iZrfoMRVya7wPDL+VxA32Dq1wHOQ/H4y4gGenSbHWYS+GVC0BZ9ix91WZVo" ..
	"dm+RVtHTYtNeAt0TzSqpqNON9nmYOidVTcICIZdgUU63WyEAcQNOYxPDTJnlREBsKHBUfXm53lH6zlIqClXgD6M4trhvQEICWJXa" ..
	"QkJZnBbMzuNA4Jn2mh0SVSSRs2fw1jvJB/5jyDQH7Yxbiu85tvj/M2W7xz3DzqSypLUuNq78gTnarLtUVVCKkO+4a9LX+xu5vKZM" ..
	"4I8YeT655/Z61YtUdrMKtP0yYp6PHFcWHyDpZxpkJMxrjM4qnB9oV9CVA965mTIw+ilI/JK9qHeBOxYKS6vVVzA7bDFplnHj92zt" ..
	"IX4kMwAetcVl9PKjJhj0l4DXlVjdBlTTnq2Mu+Qq4k+ucqRXyKIzg8GD2nzf5ABcZ/rWzJ+5/6rq90sMOMMU58mjTcp4tygvMIos" ..
	"E95Fn3EsVVNphucURw8TiVxmOs4o2pkN8/geNygw5KkXa/WqQCxmTVsTF+vUudZnn1eppmCPcO55/pTsfEZavFvQMWICwCV7HhN7" ..
	"5q7e99Bt0bFl2/KE6CMDayEXA0xr1ZWqAcmIQgQf0memniRA8pYE8eXgejF5JOrT2Om2CjIpULZeV7c3qdL7tdYeyVaazF37rkJI" ..
	"s0O/do/yz8T55+putk6hgYm+vL5iCm5IJtfo3FEYKJF1NMdCrNNrnUOWalb3CaCeJTSRQuNg0/+Re6tjAQbw8I2tDfC6l2pmcv2N" ..
	"6pPf6qP0/7XtzfCb5i9Du9pbKff4/rh4oVBH+i443VLVwweiezX0O9z3ITFuYkaS+8sRY4mJk2jMqKekiJMOeOhvPoFWz3BrPs4T" ..
	"jpsQzHnoudr5VBDCS05gkuE0RdsEIVXNbsha6G7WuTMUhvImmOqYR4WNAjdo0RR3q6W4Hm5kbmvIK+grub1OYmj5MCwVgtq4lHEb" ..
	"a0/EgL/4N3d7PvMKN4FGnLhdpGrSKdHMbIEVRJT5ncXDfP/E+bYO6aBWvsqp2Xzc/7Iro5xnoFlKirlrpLvYTf3vW7lwoK22ntzI" ..
	"3Ty+B323bDp+6/cfYk0mh6cL7iW27ir+f+J6rj5sEvRWYKLOsgcHRcf276s0udjPUblGfu/ZfOJjRsGQutxzHmR08BXht1TaDvAJ" ..
	"QmUaXPKzBCmw/JzdHHgr3M6O8IljgbVIDQ2kl6DhsTgMl9fVYN92KMxuyE2DhcKyxISvJBQ7orSFPat6oya5/z8wH496O8pgp/xl" ..
	"2bD6gQDffhiK2PFHRbxMEYXpLp21JlVPJ3buHEte6/6x8DNgpDdmn7HE+AH2QH8n5Nkp6MhKcoEcuqYl4tCBeqEhDLrw9bCijDL9" ..
	"SbMqXJIzamNgddIcPuD9YBwI5UDZlHcJfsPMGD2bYoHbCJysVyMnyCb/+8TdpEg8P91BOGRuhyYXF5gUqYJGhICaUtLt10ih/xdu" ..
	"vDozGP867ElwGxU8rPgLJv6LsmEN1L9zEN1KSCk/ETK6N2qhUjRGreayM50ClUa/L80T6gnkslM1qpX3SnGdPyv5OuDA1Ia/M/4C" ..
	"vcVZRXGeSdSAf30nodUyvAOmN58qdbU0XccP5qi7xqlZ1xOxIBhhA+aPjjQ2RdX4aZrVyT8RKmMoqNQ7uSyRHzjgkCJAHp/GC3C1" ..
	"qDmbPm4HXkPIOhZb6bgY/IwaooQ2CVBac5u/3HBTsLWGTip0M0vZmeVD/hUv0k+kYuAFQR9cSyiENLtOPJiqfBLhbVOseXtcAIlQ" ..
	"bXGiFjHl7Z5qu/QjWLafqdTvXByMwMpsPSkiVm3bEwD78imTHGADo1zVrQJxWCgHNbQMFsf6YzwQQ/Xsf/c1bKnV+qUYSFYxOwXH" ..
	"+EpQBDGYznUN+Rd1WdewYUvr/ySevzjFMtt/uDx/mMoNhyVNhYQ3PvrvEuo64oomY9bi5mNyEP7BUrQSsC8PdIn4lvpA7pd8Ll2o" ..
	"9hxnxrx/Y7obhOwYHOMJTleSKVYw0Ulv2Xud+K5HWLRQhST7iAFv9HiLvHaUqHDfRL0hYgG3DqWmw5O2JysnhRLIg97OmQ5DSfiz" ..
	"ECy7ApbC58dtDIR9/zRnyosPiB8IyQUExDOlklVbDzVc3cREL2qm5FP8VmeFKszxJIbA4rixdpi/0bswTSJP+aL3eG8L+rnH10l0" ..
	"F9c0ZLtym8+mbU40KLn+06C5pVsDIKTCfED2zn6i7w/JbL1R8ETRCDafJvA3UcxC0MCG2OTBOEIImcGGz5pKc6uYh4OvYAAkw3US" ..
	"QJ0KTq83BxqNHLakDG9fX+/6IHQrA9X5CUh2flFhvcrQZwSGeJXCbVBAELOhO13jBLVdDIaiBDoSyfBHZxJlfVK7ZN1pxuWzhT+N" ..
	"yFe6rSU6rMFd6EztnUzJfB4tYhaoiW1jAUSDcjFXQJ1l4APk/SWuz11di27/bsMGZM/zA/pCHdrj9jmcoB68tO3Mv+1j7JKKS2Tn" ..
	"6venj1ToB4KEdQJ1kN+WRaM1tbryzlCW7fikQin/LPp43I6P6lvtrFmiI8TArmqL/ZGu9Aoi7nVDuLCpKrDcBFThDxBDzW2YLaJk" ..
	"PpMfGFpv/YmF32hdXICbsURhTyWQ+66Jbjky4HqgPSB1aPrLCA91mUOcZRCCE1/mrdfwRQSIyATC0WG/O6BWl8lOriq0uU+E7iY9" ..
	"j5HBYpyKPdo64PCnd7knPm17cJDNxLuoLk+j6TV7Vizmj4bSmp6/SnZ/pxOkkn9vaTL1ciIiJVrBIa9XMh9EurrriRKSphTPiPC+" ..
	"7HX9UfL1DdJFYqljIvHnzqDUQxVqp+78HfSeHaHpwHSQcQwP232YHQ4GIZyTg4JA7X+6P7ZzOljSiwjLjOc0h8+e5264rRAfz9CQ" ..
	"ipWCWQz5tN7zR6wEMOwyXiMvdd0gbQDmLpsarGgeYZmmVNEbeC9ZX2840/pVI/SmQq5M8vVgZpHh4Swvz6OLVclJgbbVZmpueH6T" ..
	"iEFCFQsamsVIbvbjlklN3RrV/pPMElBKRiFto2wYD+WOLD8WgdmdSDG2Y8O1Qc+a5i8FGW4v3C0SJQLdyS01O7qE4/AuXHFNaXXy" ..
	"xXpdWpvRhQvhK5AQuMeCcpf5o27G7XWC2TWzUj5MKq/twnCbwDqZhIU1Acy/IMF4gGw/h0o2xEInHu3gjGqIpEL6q73S2gIgN3Ft" ..
	"xjdIFaGcdPtbJhI/dPf7GbIq7ssdBxqsqWgofB2GaHRwAa+9KvU1DuBvZtRMmeUICm1sRYEW3t+kg6szpTLk7SJjP5zeKmB9xMuo" ..
	"sKTOPgzBgNhbCg3TBsoGJXCwwd1wAiWjHOAtZ7T4dV12WI8ktlGoQ45XeBvdjsAB53aqEYu48FVzh7H63ubE+GrLTx+WGMnI5s7G" ..
	"Tx2B7WYGd0wklFH7fe64WxkEObKINFXMtcJxCFbeHQj+soch7aylu5Ke+ksirYxKsWCPrABkIg2KqJxt6zoXxlEFV42YeZySckIp" ..
	"IMN0Jzaq466+72YYXbig+GF5QwrbSpC+Lh3iNNGW2hGFxJTX3Vn6Sm8L1/demN5fEAKo66aEQAsMynytm4jgbG1kX6W0KCR/0r07" ..
	"/ExDhyR2d1k85mqq6BlBjQ+r8vS50nP1zJC0KBNqQo3hpdlPWiY17TeljePLNUFqTeVZaQJoHY7tpNhkSKEXN7G2igs6YGissDB0" ..
	"E8+3Gn6ItUNi78MAF6l5rLAzdYU0HSnQwLZA+5xZ1YsjPnWHHwAvWP5xgl2sbbTKTqTEgGKS3B3P1vGvFzEEgxBdI31Mlnia2jgk" ..
	"u48iO6jAV5+ehs3xBF5ntiRrgzLFlkjw7AZOwNt7YVgsiKR1UZYAyCCesFCHUNLqqPchlb49p1/CRyZZC9X5MkCZ9MX8+ocvCP6v" ..
	"mLTrtNOQJGI+eJHu4PCRFv8G8yX1Fyi5JnDm7Q5sreaLN//oFF06H4mNoIlS4y7T+XTU3tWO/nZg8+wL31bZXuRLj6E1ZazFr/o5" ..
	"6mM9rla7L8sypd6Lb3JbFhCmfwkTNmhWuNgLeyUn+lE+x1lcMPkle8PeVVPtZvpUqKa1qUEKoJyY/0swrdF9WZJp9OZiqT5FJOjO" ..
	"LyPhUZ4/ne3G5WEnRl83oXigO06z232V3fqtzr3b1Mrz084AnH8vo6aQh0F8hbuk2EvajnXEnDOaEv8mKY/MJtdt/32iRv09TQNg" ..
	"WKCCwIQcTrz+wXFHt5Wi89a5cq2X2apUnM1jXVclAr9nsHw3ykIBzpDoj1RxpGOnGodJGnFo1NwGYGRxLmPCZPCcbXDjVkLcJ3kx" ..
	"g+K7kvAkfF6W+IcPNTDIXBhpd6hGIntRl9e0wEAXS5ADn7ji87gJAfxKMPJv3bKGhn5B05dd/rYHsK/O2trXMXo9MG5+3h/298HL" ..
	"0HU9ndruzIlOtklxwLtoTFFPwz/kLlAeQRxKV7mRTIr3ypzIi1mb4QoE+a5eRHAGg3OkFzXHPoCmyuZ4+1BO3Hw4/cr4+giJNux8" ..
	"vlWd6MmQ8BwQZxUF1+zvgz3mPTV09IbEiibVyb6vF/gbCfF+8tbrkfJsYKpTV6yN9zpdsZANCndKirwh2ZTCsAxUsGyz/eJsjVzS" ..
	"VWD+Q+7TC5d9iPA8pEwWXo7ImlnRiWZxAwnOK8e5SEusfalpZvAgph7wdEFA7vsUsptXctz5DmeXG6ZnyVwQVSsXqoL07yzqXl39" ..
	"8u4+oLWtCui8Be6DCC/WMP1inJhH6z65WVwCK7uR73L8ESBqCqnD3N4bjs3TdPTmSze+RLxTZbUYMQkQO9irY5B+f0PB7sbMMa06" ..
	"7i3i9VHSgydaiDomQhHbg4i6QQohYW6lQtZELeay3J9Nqab4tr7gmZIqTPVEbflrd5Rtj6l5lEz/32LoNBnZwPLLs8KBSc7aFr98" ..
	"7uhYppINxwXsaeMNoxep8NjCmZJkRKFSVeJZWU9leGmm/9mNGF4+3ts4NIh50u3RKReGEBGUCvlc2e98mLpxUsDrpyzA/+0w727a" ..
	"V1WB7NqUySAbdqmQ+ylxIrneC48hJH/XVGM7rHrqpPKS7nsoAnoPPS1UhnnyeblPMnnrHIf4ZqxbPqqgbieacp3Hx9liVXWrbfux" ..
	"V1yGokxy51unetHSXjrweyvnmOFbMWSV3BM9ewkeMS+FwQm9hs/Qy1WQ2JTAq8vgBuzQXNh5DjL1Sz8ZtFyOPjZFsqH8n8sInhFa" ..
	"/vhYtV/LHmsmBKSou9H/oDs/D3w7orOZa1N/6X0br9MBu2mTnYyDS086T8BIT7l4rFVPDbFAq08roOeGepiZvYkvfqeemMSlbypF" ..
	"UWjyIo1Pu82om22DLxsCvC58E3/E+WEH196xJyLKqw6yZPkoKIvzyBdEFsnOmFw23hS0ot5D8zrGfXaoOsssPDa40iDhubk3xDMW" ..
	"iMHUudF8zXbAJAnO5DeTupv3J4MGUyfazHjcVLRK6v0tQ+bpWCVNTxR1MDlZpR/uoAEi05dWcq270i7htamDnPAd3zyUyyETqJLl" ..
	"i7U7x6z5eY/0Rwx1z1BYgDZT36mXCa4kcLVFPHXc/mbSzTraza0R8RdjHJ0xsOCT61a6OPxG2BWJmSoYZxxO/YOiKDeOQ2sdAkJ8" ..
	""
local PAYLOAD_P8 =
	"gsS4aLFWTcN/BThbV1qBsqlmBZwreVlOT0MG7EN30g+fpn6/9XV9jRLgAzE0be395+pEBuke0gBvBue2P49saWAqUpw+IgHCJ6mp" ..
	"OM4eet7au4+FM550DxLc12Em2MU4HeVWb7jkwb46HWmEmu0yaCDeKemFmDTi+fAhJH+J6Obujh5tkPbWiyBzDD+ZJlmyXMDBtryC" ..
	"OVpySNNm2Fid5trAW79EXzVb624yeZ/2XG8kqrRTAdBYN5ksaQ7DCWyHeiz/AdMpiBGTSBrK/wkfNL0Lc42BpTjSNcW6APG4tjW+" ..
	"La2omJdyOLhuRldjt4+n/YZSirqJUooU4NCMejDAP43/Il3aVf8+v83UKHPMp79qzjgwO+Lm8NiBZNIhgi8y2vEWJVx0Enn2KHF2" ..
	"CaYcHgBJii4WbjBHjPqBrVDbUaJLnUtKnkVFwcL2WppBD/J3GKo2w/SFN3vhYMaWtkMxfUyOVc4eQY1/S4E/0CgatwQcD4ofmOuf" ..
	"xNpv5D31y7qTT+C8ZuerealzfdiIpw8U2ZEAbmc2gRB3oTdINYKLQ+NaGBfpHp2LJMAQQ2wfaV+5PJ4OsSDn5+b35DLucUR4ZwwC" ..
	"7+BvMrfobldH8k2NO0dxOmUUROIIHnE8nnLrjzjBcnfabyhSk97Hy6WGextUplY9c86Ea4cYonn7wKJAii7uSAsHtceRQOOtNU1G" ..
	"E+FUSXHazQ3/nGGdQ52NR1WES6R92SUL2kiNnP84+MjjDTXbxhq2NKPd24h8rrgzU8Zx8oXosTr2fnd4Rqqb9Ar90tHNXmMViRc2" ..
	"AOXyo3WFgQOd2fEwweofoz6IQd855ZxWg0R9cnQfvb5wcnWNAQStJPIFuoB9r1+VZGKK5vsKyzlu5OejF7DRW5xGrXMNJFXEMXwb" ..
	"qjiyQslN1h1LmszHtxum8+jbN6v7q9jEyscdpyrtUo7D9eYZWDijBJwCFLCv9X+4DjSCTqVkAfx05EaIa0U7tvBo1S8ldKC+GDO+" ..
	"24GRna7kx8onIBcwZXvaF9oSdM0oF6xyhzTd/6hdU4kH9wqIRmJnv4ErGuViL5iv79aegTxidX4FoF2adIE9pox6x5j/IowPDXJR" ..
	"dpWYaWRVrnygOXhjHp2ZMi6RjZphcd7lEcztJDYeJ0e2UyCOlr01KpWKFx3gEM/EexggkrRGu5xAEzHy56mFTyku2fCsWuAVAhfA" ..
	"wcXVBwlf9/YeF4eVNsMVFYHhkWtsRHuLvV8s2OKXuhUBgiRM7HMDQj/8ImUL3ctSXMXEqubjn7c7/5UEQOEMh7L2U7zCCkjdMc/G" ..
	"wU8bsOD65WV14YaD/c6WHom3budxzPsqvsAJ9H5dJjjPuHEC2oOQGiodqkd0hbhKAXi0HatafyaDZ+Tr6M1PAmgIBKh7yYuHLMgF" ..
	"90+DFbFGfVdqY4Im+T8K4+kxttnfGLEhcWSj8MitSULuLAcQydcgdVlm9IZ3pP2rCNIqfiiPPljAZPGW/bobhXp3hAbSipfIGwnA" ..
	"6ii65tZiyUJV31mo8tqWyghUZkyTQ0Km8KXtyHhfq5SVQmIx8cTB66jgnr5+9PiM5M6ZHqgyeyIKaS1cE9VbinFbh2NFAsr7TmEV" ..
	"8NDcmf6KdLuiskHQB9ys2YESM+3XZodOzHM7NFi2dv4fo4fvt7TV1ho/qWzsDLaRHQSoqqrTNIQ5AzFxqI5/E692/h1M30HOKJNT" ..
	"Sp0QiqlWaG+DFdd7FvQ65kPJVgOXQCHxR6rch+KSmUPXYDtutC5HiD+6Zyjq3qfVsZdWErjuYfPm64YVHEdk58+++MtpBDnZ0u4e" ..
	"Wg3RO4s429u5z7UlW8oThQpARwXcLftQu8hst/HAu4JM7hw5S3EwvUiqXFuugo7w0vdgRK33CICKLcwOE1b/+FOnfDVJm+pkvhIW" ..
	"6VhrAzZfB3Abf+JF8QQbRJZ9Et1ACR6a6NJK18XF/HKxLmLTp3Cal/cxtsSV1OF5moaAsalfTVILaI+0loSqb68lUu6WxehnykDM" ..
	"VelfBvPplt1Qt7/GiS/zSHgJOp1xsZaUPKS4zSGMNUKASOu5oVC8NIzzlO984hgU67GaX/MtFCHRcdVOSOKhCiEaD1LXThoZbEj+" ..
	"ZX1BHAeupqLSzr5GK5rR/Z3RWjjW2zbN7dScRLekwBvua18ZNvlmEnACywOXYQlLXZna6H3L7mg0taB/BVe7B4fjAPsAvBRkeKU4" ..
	"qvnZ08jmEUVUAcfmvOtTBMWqsFrCOgxxBl089fMJX+ZvbQt9S21jOrWKraJYIcG+QiltWNoj04OSrKft1ZSwWTo58ZWDHbla7JCd" ..
	"9gXcsYEJAcXKqKL2o4+cBYTq69xmr0LgHXs/MRhPv5AdrJ45HBfIKo/7Bwcu8UvXxMrOUJpm0gA5m3W3ec7LrY9s3NlLlDUIMo6N" ..
	"feZCAXxE4xawcF1KN/VT9Lmf5IEdp12GwrrRxBOgA7l/aDdcXNvD37NF6Qx+/Bo81ZJKoWTnedPW6mrEUn3D7AIypfGS9Xnqrd12" ..
	"QOzpotPhbdMb9DhnQS6zWD8vQk1z1coemEBXm8PpNMIcc3X+5XUiZs56NueWlxRC4ALvhYwUJMfijFrlw6IkQx8Fh8bygZGdoRus" ..
	"QIC2T0Qo1j17A0UX1Jnwiz8SOXKakvfubMM3YTRcHBIfvXMGTe3KIJlfqEygWbyEsru+wzrdndSe6vcqtH5kDGzkVbVCzvUuzS/S" ..
	"9JQibhZvPLkrP6z0pE4i4vy3H4sCug1SdPlq2jiq5hGSgRDqwB6I8IoIQGLBmWm6Bbpf2fJoCMo9Myj2856wC9uq+v/zMhz+zwgb" ..
	"yRfGDO+7SLXqGbLUUAH+MQoN/WJ6wHxJ7pmsP+wuI87i/OfIQRUPFI/1INN3l+OTD0m19teudzbz5UcdPWG9xKoretMM8gSu9ySt" ..
	"99Iwa0miiBKoc9QCHkiyfMpx2lnNgZfJONO9/46rvodqA8oSbJ/uGj4FOO+6B/vML5t3nsrw+9yiyP5Tb3uaFDy98xZ2I41OHRjb" ..
	"6gA6qbl6eb9ODtWITYCUaTMuRjRt31ROYzVtI0bBiK+rujFaMTubjDAGI9l2sNbj3JtAwogN1hkq8e6AScXv5/bqEboxxV2y8LKP" ..
	"s71qvnZZeVtyWLMOEvpnbmJSopwUFCKVp69RkrXJRymmY2w8u0B3vONl6G1FpThQNtJ6Q8/Xze083PghdRByZC3bAajk2ajxkedc" ..
	"ZpKS4epv7/2haZG6GzqTfgiKMPZQwKFRa0feejqi+2ky/yGxpXqKdHTHfMgisiMIqcH4u6oYdmptCrLmA9b8BHuowdTYkM9OKEXR" ..
	"Q3BmWAhvtO+g7GC6VW18uh6LJaNyG+g52kHp4KiIPb4RYK76wrQeAQSg5aX05S5dZnqvggIA9AKhyMS2h5egYwUPBLf0K+zjg/+2" ..
	"tA4kox6C28SUQpcUVRj07FLHsTGkRWpjb5h17SPjdR4I4zj2JbfLMDDQkAFZLC/j/LdkE1VC6rkUKEnYpoaLqhGU4DrV76UPYnhT" ..
	"s38ERQksam72x2xQNXfQth+tz3Rb37lkCwEozvZc8/Ve/VShyoLQWyFHifF3j0LoDc6bGTAFdLdp8E9js46+JPD/JVPAFbMKcNXm" ..
	"6QL0f/dGFrNsb5T4rHN4foltVzlMG3Rc5MROVPzXbZMT6PPMjQibzSXrR0COqhuuLWBqU2v/ABMZTDdz5sHYIBdJCDCOswHz2coK" ..
	"nspH4lCT+qbK7gSlci39DBbSkLhmSTiGvhKH5mrkTExsYgCxJcDR/9B9yMU3MLlXcnVA7ASUEKHtUvjyBe28Ryglgy9M/QFaaFxw" ..
	"giPHFd2iVWJlOpPIqVw40tLbimXPyW8sdi3oSi1s1HNtk/lqnHauknAmV+34a3vwyEI/3ErG81hj2xqpWNVUgjLxZLmTOkFYdMkL" ..
	"H1WeIxLs1E5x87QsCcLRq22LGjzePyJpT/ZyroA8SodtgPLjmVa4Lfd03sf/GoueCCL3jY9AQbylLVKpKPTDAzESCCUdLY13jtVB" ..
	"b7bzEWStcS/z4J1sIx6RcZoiFuDVtCrFcn7XbpHN1DXGaOgvYHs3GXgfYD+98oj0/23rzhQ4t0LZAnOjfBWGz5TTRGWWGyzPopkX" ..
	"vcpmVjUTrrT+kxCBn5be4qVBK4MULGarWdoxoBm91+01t9iLIpw55HEukf9mnrU3J/LqVdaRw89qH0SB/gao7NvD5fQ4AhlfO/rO" ..
	"mYWjwi8gQOTsZGlRWKWtq64tg/fahB3JiWszwr6+ok2vO+8SOI8n5BJil/kg5rKpez5E5trbhUkEXcydCGawy2WKD/2u4bMDMQDT" ..
	"6Gr8oQv1IFrrqpt6An6ah+hOmqbFrhzc+FOYHUKLbmpBoP+GWMARCbf6gLmB/NvD6Z7BpSuS4mmB9d1r1+DuVftjZi0JBkYOAR5v" ..
	"BLAoTmAc3urVeERUj99eick1d6yxZwmBjSopxNgASaRMWbY+Fi/LbTPVVtHwf++GrwvRRFmnSfCn/L09UoVcTBlMjkD7NGyZtawc" ..
	"IfzeI2YpIiSbT70mlfxG23Y0Afvv/svohREihZGExGdevL93pLbHGHv8yD0pQlI/U9cHvT/eVSwbDtfmtNsupZYjLdQ+6ipNidRk" ..
	"XR/o+a18xycXqynIR+rOKPebEULArcH6jdIGrzRG+Nfm2rPCimCY13i5q5m8QmZVKM/U87373vyYP/3XVGUGy/GhtXOWO8HXt7JP" ..
	"RpvTR95QzuQsuNU066le4d/cxrIC0oSUhtxXuiYUza/jg6zQvvA2YgfweDgeJ0eVNYsO16GSCz/Safxx5l1ui0BlpFElZtW31/RI" ..
	"9C0nq3S5cWvE8Vjmecc5wt7DfVab4Kq5FLeDt40I8E4e+GunyLu8OyjUrq+BS6QADNd8M2xi1Ouh02i1Tg1dj3XPQPIU6gJLWzKk" ..
	"MkEO47t22by0N790m6B6itSK+nBBaDNuViVcfeDeRDljrp5HeU6Rb1hCR8MSYjQZm6jof7itMZeOctZu0n/3cuKP5gMtxC/DSGQX" ..
	"0xvxPE6vF02715h6FkAOJq4HGOylHkYSPI0EwqD6Bb9oY4go2iLULfM2V6aiuPnn/Br769UXjtofHDvDpiTsXhNXPLUtND3EM1aQ" ..
	"aFQk9r0VbHTUvoYde8SFgBc66yKM+hawHKRvXN1tbEBSygQj4RC5Zeb4qdPdxfsglbJtCm8uBNiL1hAJj3m/+2r3+OwCl5mLVqm5" ..
	"DkR68M1Y7z+wOEUtzrlXKtnamo2ccrZVgiu6lAxfHRGWk2r3NY5HKrpEJ1k0F15+xLv9atmprYQxmWH8w3fYJ4ll9rX/7v93s/fi" ..
	"IdIKDUtSKtz0hYu/Ms6KtrASB9/Y8UIQfhemd1HLaMsEZWaOCphmo3wT3q5zqvoSamvzhlxigzl4FpeNrrYXI5bWn+ipWlJLUKrD" ..
	"iXUXqQXi8C6n9f4sgy9mAZXEEgGz2yx2XvTwXFbDaF1RS7IkgWcQcsvUDYh5vZRmXwa7OA1zU3jeMz1GIhHOJ5LD37YO0J1rCSIa" ..
	"xmjU2SKzzPsfbIQSTmcMrki1hbstJByJNoZa1cj/rDkdoQoZ4QbNQHfwuaPgsSKQPk+zB9d1goBei/B7oSQ6tccmPHKmBJ7LrTx9" ..
	"svzz6v5dRcF+gBCyQOsbXKfJA3RiLckmuoScNVtPKVr4CLgRArHzzn0190O2dXcYHsjD2UklEtMZ6kY/01q/zBDjMr2o1cmhbrC9" ..
	"l9XE/JCsUr+cuvhLhwYTashVHD0tyaAo8dpCdpRAMMBUkLZ31CmCPnkwoTPZh1+HFAzlWqY2MjAWMWTju0qiMR2EabkWud+5GPM+" ..
	"zNaPHkF+uNeoG36B0DJuvYutQevcufmMsPF272UT1+ChNzv9a8nm92K3k/5VKYhVu9+dn3Jb9bOKAZXbE8xUpYoNBocjUqJtkuDV" ..
	"XDPfARh21le+EwirkqAEI2ntH422zND3bxoD6Wv4/VHLFI/BHm8CQtPPiDM60tpOqrfVlG48+lpbpP3M15kPfUcWm6I6UUEZz4gW" ..
	""
local PAYLOAD_P9 =
	"6F+j36E1A1x3QUpAL8BPliP/njzBBYpToYiHiEe1Q5tJIZNZb+17rP3qJ9WhJ3gsqT83QvF0MGuwHSN2Xp+JuWOXkTqg8a+PSwg5" ..
	"iPF3EhKHpRqHmo+xGwiRiiPAvWCUIanH5U5MuhtCs2LtBhk89+c7OMcxE+0YQnPWzj6c9bdKlrekHRo3GCYDf8VF6IsM3yPVlhrz" ..
	"v21l+KyL4E21HyxBKRtjZWYBadEW6P5UNggLxETtaVpInGaGEsPI5CBe4exHbbMpLcYE1qJhrYzDUpNqkmezubMseXD0uJmNcLEQ" ..
	"SmIFbn79QBQPZ/icrr5etKyIYFKGIAoT7KS1UnXCX6zaZFl7AlM02F8oAWv27VQy0C/RdC7hVNdQpnbuKmm+ca1HxkTeVMIf0zZ+" ..
	"tgH1rvPu6fTK8TSO23Y/Qx7V5glkd2C6nFRZC2eljEHSGsWJIFsOPjwrj+OF0Kofk8lNhfDoJz1lYCWbtfdpXjH1sqhOXie96sZ5" ..
	"4JEw5ZpR6zlmv32jtPEKhUkXxjR5lqfWRLPNSxG4bVdv+wPwhLPE4eYJEXESqQg0d3a7xt0/pcdLFA/AXVqQHSo30/QHnCI2TXKJ" ..
	"cOUOO9KRbUykGSLnKOuC9abvHtjNVYdUALsQerrvNsWvIb/mmdL95NDBDlj97kdHK00yvIA5fciktyRgIAHnd5/L6Ql3ehcp8j9L" ..
	"eh4i4Nw8mtCpzj6jvfMER90IWbpTpArjUc4Yk8M1VWUxMUzaUAVE5IpWheeuB68o1jum/skYtvIG8Iu/sjbCREmB41AgYgHwCDPA" ..
	"fyKVXv1q3RIuWj5JKfHRnZkER9kaTA4IdgrNoHh+6rFOicM+44M5Q6QhldS7qFPHjMY5c3++HtNXnUFoKc6FepCfwTYcNNBinj3r" ..
	"eDyOko2ikKbiNMdeQeMD8TOyv6uQYfBcDrCQ3hxopl97nmw/4DEpdlkR6AHnIrGV5zV3EI4+kbyl+UNbZec4ewJ7Ldk+FCpB8zAp" ..
	"EmYrkBUwAHDaJSbbwt17L4fq1xQ/IchR44gnks7LYft/nRseAWyCOJ6hJuYTFyr+hM7syREiYPLFFmuzoYKPISihfKcdN44DDfO+" ..
	"s7njjD9bPR1zDyoH49DDFuKaeJoBv1li/IybTu+IQCC9FfOxptP7jkdUZV/T1TqXO0v7Z6HmLe+FoDV/+yA0JQWwVLbkjHwc19W5" ..
	"sg71uj3nQxkB0S/4EDtcDffNPssZ3fCKLVSCaYm6AP31JlFUNhuK+VCk57DY0EdXrHeje9zEuWa98mm9m3hKDn1kFn19BDiUdpUS" ..
	"KDKnuc29jDHxPJg2CN0WSgLJ0WWh98URTkNuMwmdD39ZKShrscWCyeYGPrp/AtveELh1vft1isjeyJp2DhLQb3q7ktM4a8zVv8Ra" ..
	"RqHDbwUSIoi1fSJ58glNP2oTI1pPNzBQ5kJR/GBUpOMHQhxVn7D2/SPtR11F5bK8FEAdJ2hXtMhRDWMRL4/3FQDLKNNSO6CrLohA" ..
	"PO0X27dE+huG+5CMi3qu8pnLzGIXQMQNP+qJy92G2fIFOPIy7oIVNu1qRWvHNbKEMC5yNqEJEHxuRdjrvi40ksJryC6tXczI+WWO" ..
	"reyXMD2aFsNpAmnSLx10DFA+jUfJ6N+ko4VRBjyrYQolKRYROtaA5llf9jDd2O3/++m9EL0NGGknCk0t1yvH2BtNWrYK4V5hhGKv" ..
	"nArKwGl8kKO/NC3zfzhf8JZ/QGAQGyQq5uYgysDm4aLi3qMkRFUZ3AuX9rBq8d5b866v/AH/ENkqKOKuJRqxyNH74rE0mH9ClXxw" ..
	"H0wM5CvxcWCXhKORbV8/qFsk+ILU5izNW9Vjihj28eNCcipdQSxezbqj/khucW0WwRinaoHft/tpoCsrL+wjgzyTTw5SY3jRllWG" ..
	"G+vIs6OlSrE6FgPRhrJQm9HcZ3I1o+BI3WWoFn6X+5vJe1YJyOOEwX/RjbGd26G9WLVQGjrOFFe70BPc2NOMloYgo8MJrqKdC9kW" ..
	"GoHo1ltbuYx1o5+7arHhDps8osZxqLC3gmwkuJ4nPEliqXDZTP0IvsKYrUV3MSPfVqZz/O3JwyGoBLKyX0LAR5+WIOc3RYndwkD0" ..
	"2rdQsXOzVKZ2WXUOCvoHdqN5vm8rBtvOcMDzYucMH7j8AcAwNqw8FdVAcj28+OEzPghY+lUUMaxTRuoDJ/haIQKl9XmesCnDKB8+" ..
	"WIW587PuxhgtS2mQB+8bW6vnLLX4+Ig8E0c2VaDZokWcXGLv19jb5luhmdApB8UNRnJfKPwTAs5PYYgW4cL28Mix1CbZYxLfljut" ..
	"OiF5piiVezgycPltuV5TTNPkyWNZvIG+BGIu7uFlJ9K5oememtwB4KlQ/mid6f1/NV0U6c6CEA+SenGBSOW6mOEyu9hhy7+gCVLj" ..
	"w+j6p7j7Gf7Vmt6hxX9gjY99tExDH7oa8ekSaKoZSPsjgtoX2goCEC2TrvNY5zyZW0Bd4OkTfCNXLVU3QQRx2bl0tcVZU0NEV8Om" ..
	"YZ1APMRBnWMsWkQlYZsqemH0i6mg5B/zi9Xja55kOhAn6B5K1XUkwQEIcZys6ir8zpIyEWETquoAPsEP6rzEvset98TzmXImDRmW" ..
	"GwEvXVnll6xmntPRFQnLjQWo14hne34Zz3tHo7NUsiCZHNund2Uz/T5mAd3DlUesBCIwgK/fGG5k80IqH6KZU02TylSq/FDcVByf" ..
	"GGjw2hGLnDG6Oy9WpE3yFndUYbRJ+vho4NbOe8j8LzZo4uoQnDScN/Px5BR95/98xip1OVobTk2H2hScHZKf8i4WikLmw54hBOm9" ..
	"JL44OHDxfOYOUQpnNfxUIMJA1J8qLwGhwn6D23x9VSLcVkcDvC2szJUjEcOMY/uXeAZaLmKFsLtuXa83TTfaF9RssQVRdJWg2gyu" ..
	"ApY7FMzylY8c1UYWVJH8hHKdJOq/NnGRmUwsiSqBVaWev3ri7GFsI/YQ1bXlIAjdQ11BbmX22M/J8nVgmOfNTKOuzmvS3ErHAFR4" ..
	"Gi5zMOH2wQqFI2XRDkvXPT4fPacXS0DvOmsQWFxoh/PG2U12OZFbdP7U89PI+XrMAqRKlgpm40VrXsJArcZCyZ6/MrlgHLOoJ92q" ..
	"DZm4V9gHSXO5dxVGtI6kOZWFeIzDMd1GMUrGEveBSk+JZdfUnMtxZeiwilGutxoFmdn0BEIxwNFuwPkbr0CA8DRSm6OxDfLLm3Xz" ..
	"/V3fcm0etr2U16bUUTNO3iaxEfZYaT+S/hm27i90tNkw+rf97SxQc6u8Us/8eoeIMuOj0f5bzc9ofAiVyujyoIw+LiyCQI+PCgII" ..
	"GvW2qZFLJVbdPcTp++nTikhrpNNJIZVBnw3IWpwRWtcaEKjbtxUMvL+3wzBOZ83jueb0R0FpAttoTHNA7moKY/G9ga9yEnqt5pD+" ..
	"q4RFvJFAxOyI2uMYvUPjfmDpkSNzy0tgKGgsJzP6B4zCqdQWdP7WeG2V7RX/URrOPSWwRfhvKImPSXWsTqPMKxff1V4aS5gmuzOO" ..
	"/CxZ11Dz6udk0PulERvmht5/vi13U4YL88NlO3wcKvMzYcHx4WM+h8BKwcFK+GvNwn/MzGqiyrrxFOPNWsW6GBpuCiT6VUVhbWSz" ..
	"GRGDOEQ27RhIPd3gpndcDTrrSEoITo8HQlgTEz4yPhoUXhXRQhp2nA8UxSiIyaexEGJpiwG4pnIt9P3sVwGVmA1m7hREuTvp1k9G" ..
	"aV7smR0AVPs50f6nGu2nCad9HW60Nde301MCvfPSmyez+XAsi1UKmVX8b7mY91re97Z3fT57/Pfpy9/QK9oK5hQrFQjGZVp5AoFq" ..
	"7N1xf8bIDD3jPiuv2igBk41v6tGMDV3dDVdsmR+JTm0P1Fps6YJ5NoJDnVnyXxdU9Nc1UuGOqluN93YqaV0t+Z8kZyBHgtWbQbbJ" ..
	"6HmTsvewifM/g4/7YKXyZAZhrkp07FZ8rcfaR7HuluUmZqjM2haPqNq/yNRum3bCa1YOpAOISjs3JrvibtoXG/uC666v5Yibbp0L" ..
	"GmYniDio4nCFeb90tRyW2EvoLt6su9sz/rIFm04rp0mMVGjbVLZIwXxyTrDexGZtlFsCTzOIXT5T6YgLJXi9xHzT+/GWC1NXTFEC" ..
	"rUWEcWFw7IpL3CHNkgr6fYkJWYboh2cFPFzaM1LsCHTx+jtVL5bbS4mTj9J3jsBS2j0on6nDqnEZzt4qLPTNn/mBiVMACYJXTSjN" ..
	"HeR4p2LjtaOU8m+KmvxuW8Cz+B6fiaPShxpSYbPNUFQ26Qk1CCITqXNwNdHEKNQ83ABdzN8ffWzVB4QGA8UBS8TvE5MIL1kCwNIb" ..
	"nbueMPLI4HvRFZiqdDZbkgPdySi7R0y4AnkIEj8ftp9QknprTSUQAuB5sZcf8yLUssgReFySHlfR72z9YiK88Z+Y0Jnz3o4eQgOR" ..
	"JkTF693hNwIBX9tnb35rpwjS+L+UhNDqOwPNQJARwQwG6NbWrjazZf1fOLGJImjUZ7uOyUBfp77KUwgdru2zTaSjqcxck6PHC6He" ..
	"YzGSgVEy4iOa3ydFg2CDCGOIqZkvnBpD2TZFk42JqeVZVnf6yupUSsXXIslxi9DVLteXNAqA98BUDYrzNBiNwwTFRNXJq10BTXzU" ..
	"1pqp1vR4xliZ8kGZZOMr/HCt1Y4SVoUsfxirHUAz51HXiAso+iucycKYPDA4Lp1FvoA9/O8+zbdh4gwa3k1Cm6c/F1pXL/doaYzA" ..
	"RTQi7aNw5ZMSZMP3Ear64uStJH00f+LssD/sMano/8mFPyF21hfOOu4Nh/SD4p71gNBSpQYGs1/zal0WNbMl5igrINNEefxGX7IA" ..
	"zdX4qEeuHIzYhlOvLQsy/DnUs51sUylntp4ZHGClRK+tczu9Gayjm3evzWJwqXO3MmeJ8jrgk0ssktcGXtaQlcHVorrn0tlrKhMy" ..
	"Qi4kJ4XpIbC2JcgcC+OXQw0ZVQ+xfyZ5THAP7jHQ1eUsvja71ZMRtkmfiRa07X/oDgBpeQzsX7j0y8pkOWZgl/qMWmP/rLQLyMVF" ..
	"aEtnWGu7ri59pJGrRz6SN1TN4JE9drZA/HJNJaglFahNXlf2syx3nhY/5gEhFV2eAlihKgITQOmLi1HFh9VyY3FijHF84ryghrZ2" ..
	"+K7uTBGPrsRjvqMpetmeeWoY5d0G6oZfJ3aHEpNln128AvfDHugTvIKWldiq9FXIo+BuBEL+lfysu2xoAwCyTtskGW6vgJKSg+dk" ..
	"sgjdQ0M9OcXwhoe8S9lsFChdex9b8GNRcF+Qi4Eh8RHo1WY/4AvEOxKjNOkeJov89TXsef9yTHn5CyDT6nqrT+G2gUTjAekk1pab" ..
	"3NYAN86xAIMWk5lfhELbeQRxQ2wllLPmfC0MsM+8A+do1tyQqGxkn0b3/qc/Zlkafru2jKLdDYm4i67n8/zs6kaU/EFL/rPxj+Hj" ..
	"pZZW7gB+1dzdhjNiSPLTahIpM0eZlqrM5CUDoc0inMw1S5r0h2ygsjHDGVuJLke5/p1e6y0Bk1Qeqkc/F2Neg+1Mg9yM6S62suO+" ..
	"uslzcUmeW5C9bEcgAIpb6bS2EFiAYcQU+7O/cf5Mcl3pX5x5kPNFZGSlCAPdw0Msh63N7vJuSFO9DIJaM1VMlbG6vrgwXKxjnr8o" ..
	"H1gtBtIoV8Xd2OCU7FUpUhunsyu3ZyqvhCG/n8EjAtKVRNR5Esxm459W/bIPkHcCzzd/89r5aZhuxAyJ1uG/vrhPeI4pKIFtHXYL" ..
	"v8XAkajlzHLtpT7tHtFU42TgzNeUtexpTG/jM0NyNsnrq3qPf2L7Px1KaC4KGYqHbxq7ywCsDTsNY5PDI/7+drOsVtKn6te1CgMP" ..
	"Tg6V+iXza8ceXuD6BY77hV9wSxj/2xKNlutq03RV5hMBufryZ6CpZQ3U2hUGz3TNW+cgi2DlyZOTDWRNSgKZSFEKG4bktc9dvsJz" ..
	"RisgIBDHZajyh+/yjkeIwc5ZMuwcdAehuuWWjQktdaUq7dF1gkiWLxoG7VLI3f2iUinKAPJMzmwVuN0IsK6ThdMXzzVd6BqNK0tf" ..
	""
local PAYLOAD_P10 =
	"ZLLnu+A5ugzuIEPNCgqZIhm2kdhv6VhT4imB3MIVVKIrDA7Ro5mF/HTMREEUYANrNsgjHjppI1OtcBZipKVQ1fYeF6FNiUwwdFGu" ..
	"ZlMZjng5CfbVYfQ/ClIEWcMUWTui8Dn/fybiHDQBJW5igiBH1c4myiNXjSq0p5SEk9LdP6Gti4IvnFIZZ5GF4HENByCyRcviVzeZ" ..
	"5Nt5bCMYsm7rnaNmdbnYaD6BLP8czF5oa8YRnrFHnWWy4VkV5/Ib0qugEB9qW+0+UwuADhHBOJu+7wG4ccbLJpDbJv8T1oFuN0/7" ..
	"73WYVuaU5FsN8YCB67IRuVDVsIriNcSw/g3O77g0ivhbUtxXXFc0ZkzDsa04AuJAe/PIiXFkc02X1AMJFy8m5oGFagXk+FBZm8DO" ..
	"rw8VegPek3M/zH6vNf6OSab81c5qCOYM9IJUSTyceG7AEPH8U+jRreYth6/SxaabGxuqvJ3yFn/8lVWeyv/sfA6sDl+t8j+ypuPl" ..
	"kR537dS3vKVFmJOb/0qvwm4teDwki4ZyuYszORXp089+rulCBAk48yXZTKgih7bZFjHzKz1eoHBaeJCIv5e1Dn5o4A9NlXdI+Nr4" ..
	"MCkic2YSNQgGcpus0vqwC2tmMNPgo+j1kpXAWWDgjjBhuwI3GYWif372eGQVqO6dpGED/CNrvsxQ7boa2qqvhIj+T+3pgf5K+K7K" ..
	"+w92G9eIYEMLnK6A2GbrniIZKgWjK7qqbhvb96fBPQvoRCDFEescefG/O0y2eb0B4Po63Mx/l/wEzoz3iG9jggtK1PB0W2QDs/Yd" ..
	"czkEiCMXb2qyWTrkyouB7cyfNYBm/CvDsbOQqxkTgCn/TYN4D4EA6NgsB1cdZn0hzCbwNcSs4FC/EeI+iyVz5CgtPPJ0/2GRPCF8" ..
	"cgylSqLJTr6Ekp3I/selH8atHnWpxG8dtwDb67iLQa+T9OtvgAMddoV26ykH+W325SDR+OH89DVtBH7VLITLMJ54mnAb90a5LY5e" ..
	"N1fFQiB09B6CUAntBPhynnSE/868Ue9FHfWuQwruCvzXMmaQsRgxq6KlqINqIXw/BHTxlusG7eWUBVvXF2QotY8gBMXwEDwYMoPW" ..
	"RyLY6313zjVI4bKrYXsy2hckqfnbQ3F0U5ER60OYGzVU8jMMLBrSS/+93mgT9bSFcdFRqvrm3JisquDxyIxPJAX66ME6WuFWcgrW" ..
	"GP7DROGuKeB9TaeVkSnkybMnvbPEF8SAbOZEZuo/osG7yYfCj2iapKC+2NtySqyBjdrUmIsv+76JJ6H2T2RqRvnwtTv0e486/7ec" ..
	"hMJ5GwjSmqBgX1lRAPv6PYieO/X3Y/uV3Zf0y+ru1XGf8r2NiQMaFBoPSQhnEznQV43Puo6P4G/QWvAWr4M3KeJlJTxhvmKplaNi" ..
	"s2KFrmzMoubywsKztzM/RfKDQ4jlSUYK0KChoD/HmzryRcdR5HSKmvoekEOV88RGnSrLaBJpnUo2R4JMzfst1fLO+7Bf/Y3wnKcl" ..
	"uVmWmlb5lLWPU4KoiRmrnYSBDagFgP+1odjp9cP1jOumX4Ns+lrPvlH3bt4cCs0+IsdriBu09GIqQYl06YKQFYJPNEZ0neGwPLMA" ..
	"nJKubnfq1wOjfrJz2tdgfEYfSLn3DGleF/iypZAGVc14cW07bc888Y3iAZtiy4omy9m5RQNq7HpXlQyIv+DTKFEIjjZql0vRamZ1" ..
	"BnMbEo5ku2/vfKISeyGWh0CYptTvV2M3aIMNQ6yg4FOe+DzU9iAmN1a4e66prdW49RXhrVY8V+xw4ARyfVg0+CflAuMAnirJ0Rpm" ..
	"6VhS98dxfothQanNC+ZkxrFCuPSQB0Ny8lc8m1kJ8ru2pURAUBFwp5ax0eEUrwLIBCgwUQoAVcVbVQAIGTxIqbRCtFaOBG8aXsAi" ..
	"vycbKyDTuhEQW0sVCV/zva957dG8zsczdybHsl2/sHFi1LNgLTFt+901mTe5PN1Eoi4AjRoEAkD6V18IEXL8XE6TTijS25YIvhGr" ..
	"6u3jW2rkyXK0fN0H5/wl/kJnp/uQpzCbHRkK+Oe6NnX88iUA0opVooLPxSjm5LEfLSBchcCyYFQqbV45eN0WckRnj8BW07Am48Xy" ..
	"6+6CEcsR2T5vlYNeEXc1kMrJ5eZSuRATKZNzrLh8yeIb/tM7I2me9ScBeIdRoUWafETLkMvwQXtDFf95u1wV4zP4y/weT+6Od1+e" ..
	"/q9QUYBcyPFLUu+/ay4ItG0KgufBpoPZATvm8xEFiUKc3h/X91vs5C1UWPCoQfGP0DB505yzRtsFedygOqyIGabAulCZAH3J1Dvr" ..
	"UhRwGwoOXcJoLfbhjL3P3f7tv6l2txneVQ1dBRB+cZm0qPByCG6kh3JQuio2rXeavCmh9Biij6fVzXYKiRx+fmC6fDy4SdDQurQZ" ..
	"mYCmokhmR30hllB5aCyLBDEpw3RK3dyQaJsCdo9V/JHGkxXZOwf8cMRH+A4eocWr8ia3c0y9H/FvfWzyOOcxFOw4Uypf2kGXx8+U" ..
	"oRCMHR1YyxNcS2tkeJCQ5iKk+edmrET2xFyNmA03fXoKbdjjJMbE669hklB8MzCWwLboF8mcbuErKSR1d1fDWCLCyARr+NHdhkKb" ..
	"9ELwROi3vucrElifxXAtbL8f5GILVsuX1A4LXwiHeWGUZdT13uEoyTGv9zsG6wm/hpEznsFPUXnWYujY9W9sMMQmED3/2W2c6ci/" ..
	"96Io3HjtIdawTDInzign45VQhnwWnabiXN9wX1sGJMd9kOlgrBjUq2+a8zWsIS+l8L2bIHsDHbAwPJSI1U3jFYk0SIgrPzuMj3/K" ..
	"zVALIRvzspmGbn/TnWd4scnRsVnFHSmf5IyYzjtmULt24XYxNprcZy5S8jU5p3K9gQ0/M1LAyA2LC/88mrKKpAiEzLGO0RtPAANY" ..
	"9bQ4tPUZEWqoB3L6xlTG9AfKk3Yelm+CeZPLa7CapR0ff/YmqZ1RFX3+KvAh5O520iTztPBc1esQ0dycvbF/3diA0ZS8+4614B8Q" ..
	"IfLBDWKzrqXCy5RaV7TaXx/Nq10XHxMqYm3NYcQTkNzHM4rW5LwKW5XzYCcp39VMiNvp5gibU8C3frlMX0gB50VdnPkFxUjquGSD" ..
	"KrLgHpxHL/r+S7zcmcjXXkWuPQpLD+vcD3J8MquT5cYeAZNrAYDHfMA23qB0DLVsUP6+KsNX30/ShNM3okXfpegdLpL7RJuVsYh1" ..
	"kp7gH+xCmqASt7kBUCKAheqlvj0dZYf0r8JSHu/K9GfFmPl7tKX3XZhWlgykMJU8ed+AB8C2Y0tLTnvmUViaSKiA5vNr8sFsMc3f" ..
	"DcGLQg+FPY49a9z4V+A2nOP+48oAiX0NgkMJM/cisdPVDEtzPVPthQkkJdqTBbiHY2uo18y/z7/LcFJQl5flsxGpeJKQ1TAXXfAI" ..
	"d6XCHlxBHtQQHRFbvxFQ+jvgRqV3BgaCqA2c+ITdcnuiDh1miV1K8FD/g5Psewf0q9CRYlGMKOJdFAzUOpvtxDF/jHO4YoxnGIh7" ..
	"7uw/TgKEHR2kIj8TYups3rv9g9SPkigul6N+sNRppFGuhWmsZ9VmjrAX7Wojh9mNEWdv9d6HjkAtcWV7Uvn5KHpVuDCMreFcRuIK" ..
	"6r/HQin/VJ/GeYPnFkMNU/X2WufL2uhtm289LXOmwHWcY8iU6VL2t0bKAzt8t+RfBmAvyruAORowR7NfkRSrRMwAQyVmbwS5y0Cz" ..
	"kmTNGYDOFFIXS5q8DtXEP7C3S/rYp/RGyARB006oZKk8wqdwPfkufxyJzioeP2+VPAbo8DhNoDNFu3E8m0dMNrr9yIUEkO1hdT2g" ..
	"NjajSSUpckbz0G3Fl9nC2o6G18PaYsfYzO8399O+yaGtFYQl9TKn1Mqz6MKEzxLJ48ekIuYKmuGq5KU6bXSyhIypC34K7m/IWqtL" ..
	"MYEsqLaIcVQTna+fhRrDc0t1J4HEHJrMW2dCeft+dG8et+1Kv+yobw/5oJkfo3+ymeETgJQ80n5CYXHS3sA1VUnKrWylnVe0zI0f" ..
	"1wdYYr1qzm4ShK4gQIhzQQaTH3I+GC3putlLbyXmS/iLZgkOL31VuGitP6CQgh7QeeDhylKGrNGW2s0p7x1wRt9Td8k4y33UmzGl" ..
	"JLCp8/YtqFyJZFA37DhacNmfaOCFOghpnWxt+vP6zD/5Bu1KzTxx1+fXrJJbIvzE43L39iZtRbIzmT1h93op0jCJFrq5MiLVVSeH" ..
	"32ylReTipnip6eSu4Zx9H4Gx2N5cyvytcXCq1YbTDR/EVzsB8yJDowLFf2D7Ky4nn+C4D0rOidLQPhm65MgLqqbHgQQ85M2XCIF9" ..
	"3kfgzj0elmldDqTo0ORH7eLLlOOmaTlYQ+CPO0E4E3X5eiXl1bQoYuLgOmUd/+EXzUzkkGNySl8NPcvEdxWEwO+nuZ8OMBUOCpf+" ..
	"crwnD9JBn9+SRZz0W40EYSVoigpW5Zf2VjHCXP6PljamY5Q5m1cYTWxPVVQSOfw0uHM7wMSP+eLzbKRPLhexp5jpjPLLwdMOxfgE" ..
	"H/TAbVZ0Si7cUbor/qW49KnFw8eQ2dribMUqCNSfHDKDvMvAbUtbCCG4VBExh4KgXdYC+oWfhWqQL3OGbPMs2S1jMt2Ss7vemoXU" ..
	"TzS+jXHfH9wYNfdaEmJa3/fkXcSyp/aTe5r1WoeZdm3LGBcpYsB475TrR/QeUJBhFN2+KqUaqvevlQZe+9HseikDZ/roJXeST7b+" ..
	"mI/fJsuFApEJ7DLkVUtON4R3xCxff5BWX4erDofUiwiqgl2ICeloW9Bd55AP4Ovh/GzitLJRewWoKAQkLs4cEyGAiyXMF+CCkWGJ" ..
	"14FW7nAVqzSRdtD3aszZQdyiOohGkAywvMoLffHUf+9124S/2gzQebV6YB5DIA3WzdfmMsr6Zymtd5N77Jz8ZjMeaRcEuWbVu6jE" ..
	"I5Fhz8qp0AUMuGolQiSpSz2EJgJlg6cVU3lHH1Pd+A2xvr7joY0tDl+vZQyyxChv7D/UTPTOV6ON5occeOh5muvT7g/TXrYTBymz" ..
	"TBbzgoVQ/Wz+sCeTk7IJ8E0U4ohx+GF1moz3AgczRZgecYRE3eHXkNLDQiHkbEqGgwBzV8BHIujcfoSMQXXz9B09kcqGlhfIY4+L" ..
	"T+0S7EKXlwEhsa9I3Sc0uIYktVV54c9prjzWdoEjxUiNwuyUri57YqKbsiHeZonam8d40tiqKZJ07EdrixXQMxm9QLxF6StfEMIU" ..
	"knlzGLVPIfqVk9LVOnOFhE0+AVKBvoMD2iGVacqUZc5GwzDR0Mnm4a72NegBdAQDhtysUtWAEQPUUgpVE9JXWewaGDPpsicT/tUV" ..
	"H7KVtlmpnHZ6OV7zm+XEWyw/N4WqEtdX065M40OGXCLcZDT/YAJez+/qgmjB3XWSOU0gIkdRK8JAI4CLXfoKD+/vIOm0cQdPXC3s" ..
	"s19CVXLRTCdoqAyvXRh9Ooqdy0JRNPaeVLZb6yx8ofWPEoH5zTuYvj8JGXiqNuNm3GaLAbU1Ae8Ca5mT+8iBiuz7s1e9wITGbt72" ..
	"xsKUuylAwqx3UdWHdahBwzDs7/UZPqr+hYNpaAFXEGlkUEDVloh1pD/I0dvj2LbzwglxJTtbB669yFw7IraeaSdxbf7bYT74NKe1" ..
	"m8ypuRr1z8p55NzcqERysWUwvbS567cnAQsUfQkaB4KPqnsxGEWm2du49V4O0iNCn+eF7/1+F9db52HvZj1vFI2xF6ZkG+a9pFLn" ..
	"egm7gfk4paZp/RO+4bxbXWueX8t5tZubtWbzquUkPm2rMcZ+7Wy5Fi9hYtKN1EPgt4iv35xSQP/HKTkDocxwPPW93lZrmUYSHwL3" ..
	"fbEzgHtBrcHXBsbUG09M3jxpwim+OSiS2LTF78fFgRQPN0ur9CIjD7LH+oDd94tuU3SAfzivB7yJrCqjyxXOElz4GrI3yW5+JdtE" ..
	"GT7tl43S8Rdex8v5153RhfrgnfYzfwEUBD58aPS0kITSlOOw7GvQ4lR4utSgY30D7K+c2u0ORDTaX2DiWi9HEQrrIBiCHvVWLY30" ..
	""
local PAYLOAD_P11 =
	"9zeYCfX7uSpMopUjR9XrEyhYieVkcAK10wA3bMm+9WdW5J8E/a6Vw1/9AO1eNmhhsur8KzCcORSusRhAeGpDF6Gz+62qbEfwdJxz" ..
	"h2uFapQm5pe1OwDJYofWk0Af7UkIaQQEqIEGK8vXilwcN0PoRNYZsXPwmbwGhTbnsPr9uji4/kwSSlMU2Cf+nN4BSdKivmODcGca" ..
	"t+g62fuBijf7prR1eP6WLdop/LbzAinCtAOOjLzCw5MXrNxo6dE7I/uXtBb0FEBb7zBa/tZzmINC7UWqseaMA4F3nacZXqr7nhln" ..
	"ZvmO8/wZ5bb53mp2Us2go+92QgWJL4aeV5JmLyJGrsL1NU7ogvTagcEYXdWKjFLRA8ZgfBFTxKxH7rRw3B3at2rgz4vFRXpBre1t" ..
	"qJGTOExd5rQriPrVnCKqm7TUhntjjvQI+Pom1bOyuy8EXkarJKqFb7wFTz8JSSY3YB0rmuEJEWr3L1KVR4UrVBrCtrwBOitV4vtX" ..
	"0Il9l/9mq1b4HhmDKIodpcN2W8AuJdpqLkkANWIAUl7bYau44zchi1rZeXVrkoBWtXXCMU6wJEm7grDdEoQ5bVyWC6pO1EGlJAW+" ..
	"zxeoUrkoBxJpn+gqe0yD74qSBdr4vSL4zFWjM60Q9xgTRttNX2B7rrmeVrr2Wf3e314BjRj24fgBfc/rNogZKtw4f/YJCDpRiUE3" ..
	"Sw8tku6QP/BvKksHHSNGKyqER+5WH4QhRf75lD3zHaYho5LWPcCBgRvkiK+UPOsswY4NwAJ++8TAJHavjSb2UNdr2JHRpPlxAwaT" ..
	"3X/hM17UfsB6Pw02KTYUEeX4gZZXk4qlBjhcHh3okHyJKMqpsEF3MyAQNX19PhC8JFor77BP3c0Dd2uwMZp7FojNXaEYG4OfB6RS" ..
	"vb0y+bHh7RfD9e/uPwbJvlJhhvYSyoPiq2b/FtyOpjuodM49kD8CEK0XS/sFNpHX0wyrJWLoJ6Wl4GH2janZUBc30pZkfJE50CmH" ..
	"h5O1SVE71O7Z59v87a9Oa6hi3x80pJ2WJSyRba07XW8vS5LjP5UXe+5o4HTfDTmJvQIHtfx7mtN/or2LVSyPTdjve0AtYTzfM+x5" ..
	"qCilskvBENxut1wLaIotdtiaE/vviAN2LbgR1CUGmBIFnMkv4mwdAbdFSWl1PpSmbmP37FY20Xp9wgVnuLNYTBr5q3BZlf+LhT/5" ..
	"YHYymfedN0BdPOWBFZ6s5tf54K9oK74JUlwB2R7wcCaXEHPletvzh8ZY9ix66linmdWQogRU1Hp5FKLtfOu6JwI6IhKZK5hwRO83" ..
	"X/F3CVn83m4cdxDMaPqRv6a0AZ7G/x66nUELlkfSpwNJjqGk3ioiJMGpJ7jsnJGU66HpDR2jMP5QrL8F9NoWpbd2qsgoppfbZZQY" ..
	"2roFw0HYzJpx4H5GDEIaogOqLOa6Rl2SlEaWk58SIDQK3pzB5vz6tawI9wr6NUbRZgQiJNmSjjSVvaEqBr4xmGqOkSp9XBpQg0zq" ..
	"0nx0qh2vzCdHobDZbma8PmNT+wNMcld5CzDu820X+lOkdZjaEmO6OsLy6ATZPGlZnoK5rjfFn1rgTXqKJiAlnppbq0hVttehJmEr" ..
	"yxwo41TxLtyMBWu+ez3l7LaEhDYw8p2QFDrscfuRyUUnJKotD2UjMyKoZhSrbdyrDjCAW16c4y7i1s4BZfMtYOV7zm/TjgLC03bx" ..
	"Uja/TPLVgyome71rhyFIyvODPzSqEYR49bqa7dI19aJ18d2uo0BHygRZQJ9myg+ajwMqQ8fHZuYeD/BsEHpfAbFuE1QNMteYEcGQ" ..
	"bbBSq+f+fap3+oygHcUPdRpeLfV6Y2k4t/QAUdkZjEBMKWSRIfU092RjWXzfaFn6QjkAmcqp/DR33eY94LuJ5Co7V+kLfl0Ksc9o" ..
	"7n3Y/JSNuJV0MZ1tNAokP+31M2/wBFuov7Niq5r7kTRjJb2Lud0/K34XJhGQLEtm0wC2ht9TgwKVrzJCGeUwtpGWglZqJ0xchaIu" ..
	"wA4CKZsRTMFJpksdWFSokM9+CrbuU/0h4E77Bn+cXp2kjgD3fJiA7DX481wvwp0kLZjEJsErV1GBv/vE4dv488nay3pEoVNUQS6P" ..
	"guPogNwqxO283d5x1vfCM+NteMC9jGWMrQZZdcKBs8qP6YhCgN6s5fb2wmhbY/XmWzLOQcJDwlw8qpy2n59vyW4QpgxnkZ3P4EOz" ..
	"NyTfBEN+clqzqIji2T1ajeoAoR0fBj7kPSoENGNSd3+UTrxPjWDvjwAuPR7KUMoKjZSoBNaXQWuDe65nAGwR8P3f6VISPy6nscre" ..
	"maYoY9QLy85EM+xSK+fd6t37++tSfDfgGYsk0Nh7axv33Q+f3gbmLPGh0+KbDEHP0Ly6wPEgw6yMDe5MfoQC9RFNQeTP8vpDH7VS" ..
	"Irb9kexFSAdB5UvbAJNnlwR9NhLPuu84WABzbiuWd11/kuTlWbHywkjw2sC4cNVv0mvm+EBWVd7kKuAtKG6j9LsjnWXE9OIwyR1p" ..
	"+lvjuNYEGQ==" ..
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
