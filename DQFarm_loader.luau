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

local function armTeleport()
	if not _teleportFn then
		print("[DQFarmLoader] WARN: executor khong co queue_on_teleport — menu se mat khi doi place (join/leave dungeon).")
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
	{ seed = 1982248815, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1985927033, exp = 0, plan = 0, hwid = {} }
}

-- ===== base64 decode =====
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64VAL = {}
for i = 1, 64 do B64VAL[B64:sub(i, i)] = i - 1 end

local function b64dec(s)
	local res = {}
	local buffer, bits = 0, 0
	for i = 1, #s do
		local ch = s:sub(i, i)
		if ch == "=" then break end
		local v = B64VAL[ch]
		if v then
			buffer = buffer * 64 + v
			bits = bits + 6
			while bits >= 8 do
				bits = bits - 8
				res[#res + 1] = string.char(math.floor(buffer / (2 ^ bits)) % 256)
				buffer = buffer % (2 ^ bits)
			end
		end
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
	"OJZ2ReZVFEoeek/J8ga4mCQLGo7tphlmR3I0ipYUQQdiA3z79BMg5Y4WJXgdXZo5TSSgV7kudYbK2ZHACf+dWZmF5M27fDq6/umn" ..
	"G8r2MzRPNiVsWyyyilXBiobMuLRvMhN24WNZ/NoI3ADxpOgVpyAbQWZGC/taj4V2aLlVhfWu50uVOKLh8St7ynqQ7h9CiDw0+v0W" ..
	"6rU2C918K2AZZhLRj9v7JuOMhXbj+wRnwjIcNf+N1F66zHLzcG8mymNE79IUTCR/oncV0kwk1+8WupbIfkk6usBfoUBPo4Cbv/yz" ..
	"yKruk4hOuurXkTtVfUOAYyotP+wjmaOzjz8eTgvDepqFB0CO3oS4Ffo0kJ6VtOTX6g5WsRfPYwQAz8O4WYqh2jbXVjNEN4oMMHNG" ..
	"0n0/gqMUCqkR/GGZcaTplPhCaWQYAOlH95o95mqlwd22diS4k+CvRZLmhdXF5tZLJBeDeqsUNfceQBbf8ZcEJbwM1MnrVx02aYnm" ..
	"RQMpW7D3Z5nF1G60v0AX+/kM34wcrna5AHLy7spzuQVrZMwQSZQcq9xdIn4k0AO4XHOlQ1iQ/a/tMlPOpL7hNTeuBhr68P4tujQZ" ..
	"SNFnDFtIJz8C8a+GPEOWKRPTTbz+q8NP/YyCVBxJ3zBC3BbtgNLwsaHjqVPKgtCAiqoQtajzzH/7XL5naGAwKFUBzNgpWiZWDdnK" ..
	"Ml0yNoJrHUJN5c2n0tqqXtQNJNWJnb4Fn+a1obL3kBaJE/Id9l8il0s19T3OrzoLIcgHFYZmtYcRJFLrkYlMDmg52vV+6n8uAw2Y" ..
	"ivx8HUVa7XT2iMm07taJ0cxAmvNLSw/LVILiS4k2My/mxVj+zVJ2UUp2QUUo5wDesS5YTSB1V52giY2aLX1cKxn6isB8ii8XeVWE" ..
	"871QHACWQlW6dDXh2FNDv4Y/aJanDMHGP18cyNa/8JG+Q1u7XoUyvSdR4MQrrIq0ccq9A8/lgxzCaReMd9Id0cXu3bs+KKZs3JrW" ..
	"QdiIBBDgbe1Er5/w+fBCLLpbDxpzTp/k2vZGs14FgW7amsjIYi3M6helQneoqZho5PnH5JwBkO00SwrhnMhg7wLmjRSLn8wXhzBz" ..
	"qUzugY7vkQkxQ/snjdB3IVQZ0c3uJJVr7p9pQuk70N2NMG8AkkWW7rUTzzrvq06GndsCzcC+715X+UaK/5X6yq0Df6oKdrfs7DPH" ..
	"aMs/2STyIeklqq0wJREca3RuADgDA11nXYHV3nxM0DOXHb8QE8uHedpTWS9eGlzAJJFOmb98WBhkgVA0QKpujhas+g1aSnfeGlwa" ..
	"9YlI/wsHj22lNt3FxCyE+MMS2xA1bKfg8P7FcwBiZFDQCNt9P5DG8RL0KTNN0QJk9nVV2gy7FujTPHj+XSNCVpdY1BiXXIocMy5+" ..
	"weuayIPh0egxMlE16/j6Qd7gIND2Ccy6/grsrH90iIsTZZmLGibIwg/mftP421sLMJzvIrhiyOoNQBN5OHZ66bQPaVgfXjfMie7P" ..
	"nlF0bKk8HIA5S2nMV07ZiuPtr5zbfavk4kpnCj3leZGStZN2Edc4bMGe1jetZTNufWPPmgz2M2C75D0DvPW40v3mRPBhJE8cVD9a" ..
	"X0EyZ6m20sYVfoIGE8RyyahiYaxnx8e+1Z467uuNeXA/pvk7qlG48zIRYoIAoYTyEh5lMgXw4V9vaX1iG7J3eVfnVx4EnpUnrXbi" ..
	"d5n9yTPmKvFFBSY2YY33CGOCQBcjs2xxy419EaIgwPTzt54mOw7gW2SurTjUiFdGqZtA/4nNVNBoDh8PZgBrG9BN6AHJqZr/X0Hg" ..
	"trlzVzlfyKx+nvK31LnK+9mZsMsTSTiiPTtmmx9wM/QIz8jx3ErFPE+B4q6vSUalIehV7WRcuigNq/ShtCDmurSo+ZrDuSnKSCS4" ..
	"X6beevLeX4kUhgaMITvSV1P5/HloEm8QgnVmXFBdbtUL858VoiSPf0eKB8KwlSlLSYq+DJvWOzr1rzTFKKinzl8i6IxUKYjsbxgK" ..
	"2JS29lzemF88EXCNVNMd0P1aLHr0mpSczLv1ip6qrgCcAuIebT7JqfBR+EUBmUbgs7Wef53ShQNfQq7+6Wf1Mvsc66Wx7UlLLw/e" ..
	"PjKPhebMzHketUSLn+tAEdrckjluuJhdRWAt4gXYPS+rJmnol6A3jl090iBbYdyX2dKshUQNtVFpggBKdpqhbyjCezAc1kpO9Ts6" ..
	"cgIpmjU5BrauuWnquGv+eDB+hOpTP6S5UtDMynVYIhpPELYHsrXw0c+i1PgEHqs/nmEDaZ66DLjso9FiTXqR3rrU+OkHff0d2Jpc" ..
	"kmPEVsnIy7HVxDQ7TJRIW+A+2/AzYgmaGVV/7V0NpXn6XP7CyrnKYb3gQ34/dBu+SYKdSctQBxDrd4xzUbCx6h4HdGVnl97sc+jZ" ..
	"5Nzh/dyg7lLnuSSUW8Wkz3x4nXL6X/R7Zom8z9XWgKK5GZ8m23on9let+HgetrbLiZDTLHX0JL7xfxf1gNG4JZKyJWXBDibcTAI1" ..
	"V6Amjufbx4E/MTuS4+WJYdjYp74QBGCCYIvvRB6pWc0Gl7EL13lSkY8RCQYCl0W5sP1Shex/u7LrgC8gxybbNuHjlg4rmJ3zDR1b" ..
	"8efSl4YG3sgPs93xfjv6A6kcmtkHT6k7Nvt7/Xsbmm1C0uVtaqPD0lxKWuAheuunm7sCtGxQQv+M3pG6sl56oqmsW99taca2oSaG" ..
	"jpwEquyhtJX/gz4S2sxORK6srrY4An/gqYh03e2yHyFS/5CMif0RhqPJ8i/kLHlnllJeqYf37esQcQfNjBmbpgcrFZJ+seJJsczf" ..
	"Q8tk3Kg1q2yud1TYrpiBAGJKIuYMETPskwCdOqEFx6jocDporXCHZ+Xnkwy5NewuxlwtklJFQoAe0GYlXmm0ivSiBPGuRABPbYwa" ..
	"ZZvgQ+rP8kYscDfFA5AGeeRw6JFNXiCGY0RxXqxRQvyRYr1q0C46l36yIymMZ6jxNbIQlYGexCro1tn1630PnDIGeKJthCkK5WZD" ..
	"J+a9zFj6hA6W+SLIiu02epZSt7OPZR3e3tyCiOKNsJaH+JCAGlZlyqXM6airzdyk+AvQji3F6knYIjXKQlwvkp61yPzzpsqRIaQA" ..
	"w90PFWRg+x3YeZG9BYbc8Lhn0oIhO69C+UCp7+ZJLw4miavZEFy6pUVJJNM1nv+lujaJPLhDWjUq7CAdqajU2ooNRKatIROfGvIO" ..
	"RqK/nxYNOucambKqUc5oTfbS2nT7Nq7udmpG57eQTIxjxMmbiyKvcy8pCxDryGGb+MkThN9TIRt8DFfNf5T/IsbsvwyuH66WxUW8" ..
	"+jSZlLrpvSb5b6+Wd9j2Rw9wpX811z1TJGU6gPs8jlO5mUD2or2BPVsIJXkKLs4KlcMO3fkw1t23h+iu2LG1fTv2ZREbiMLEstw4" ..
	"0bsGVTkD+D1NaRfddTP22SxZ5zOQupIcdFTTBhBarP/8eDdy4Iz1h8FDYmwBfC7+o1lrtgwuVlCqhzzF2eUdywgAr9ART+QrltFL" ..
	"Qoewqen+HHQ/OMto5p/ijfkjhxbx46f3WM7ny9eS6SPtTm7uXfwAXgVn+fw9WLUVaMKA+dbZ7mn0e4buI2gVSZ18dakyaMPAiQde" ..
	"vPc4cBch97knDQhKocAxUWc2VhTNV3wyEYqsUmWcxgv/rN4HMPfXONvsn3EguaXdtMZwHHCKTdt3YI+gBB73ReapTi19ajmJXg1y" ..
	"az+wSqi3S3k6GHTbBhp3A7OVM78EIKIF+UKPShfCO0hxn2v/VHsKYWzOc2SFsoJ3D7mvZmhuOfCI8DW6s34aNBhXcuy/D4y3bXYQ" ..
	"l4n3S+qKs4mFgKBkNy3x3HdlD5tq87FtBmSsl12PPXHs7L2qh9ermlGfW/EHd1UuIIVG7QXsRkaG19gyE6E4kylau8zjK/rCcyzP" ..
	"cSmHdn6xmqRQHARWrIlp3wHmNGa0tmF2r0ORA1RnmPrEJl+EwArDsDdoqyYhMHm+LNsAv/PJFZCG6H2FwnZxULAo6VqX0DVE0o5d" ..
	"67qUxVgTbvv5xsNUh7fzwx0EFoHc9RavvD+iocqsRMvMwSfZSw1Y4oJZgid+kPSv9PhP2WcZ6eH0YKeO/x1B67T4F65pDNcVIX6K" ..
	"2M48nIqiwmE3gwHKCkiH0Ky6URbycEv+lptp8BvdBAiTcIIIOa/vGDJ5vVi/uBPpAH28e5y/Y7ivsXTpyIpQZQbSNnHhjodOl5sj" ..
	"c3wg9h5wRtKoX0K9MADk0ubLMKvErxjkgL1QJuzaFFQ7XjY3zNY2rE1mdE5vMun6fhu6AaNAlQWTm2s4ptc6o6Xr5XhdljF738HZ" ..
	"7kcgX+k8gXz3bGnnLS2HKwAxRqUZlCf0YYlhODDgAtFw89NqcA8HOH7cTKWaAvJDZBRsGIYDm7+AMvKqWqt6eQyvAlfZIwBkuWOa" ..
	"vvSNQslhc2HhiGE9rqwvCgV6bh2FsRyOYiEP+sHkjArGaoRGtSLFcRRp03BIi+A6+aNHxRXpf8G+irrDLKQ/BKooYE6Yezdrfp5V" ..
	"v/KSv7PwLAYE4RPtfXwcKxOsA1Cj8M8W8XZgUbTUSWnDQEzmgrVNs966ckR2WLRpzJjFWyUtRsJNbFF2FbFX4Uq1O+rR6fxJ/x2k" ..
	"pGdRfzUH7yeNrugnjFVxvZ18tOomrOvS5+4fYJlI0pT+/32fR4nhH6H7Itqmpz6/STy27ZgpkEUMcUiXxQkrxfZCu0U3q7l/ApYr" ..
	"mJE98IIu2Zm8i5o7FGmLIKzM77XNWMU1cgYUvng1r9MSGzdGvRe/fNxgaBFyq7Ngqx0eGdfoSmevRIK13tgtHEWKNu5yQjTiZeGd" ..
	"Wvd5DOqNBqiXaXRkJA7Krr9Hf3T5faguDH6J6deXzjzmc2waSPNOfoBL0wCng9sEEPnJvqhV00UajFngDM43spzesNMJNn0cz6qn" ..
	"LdAyC1zxpVCSCq5E5CIkjcBlwjuss3jDZM5R85BME0Bx1M5T+KdaNSZiti58MBgNijrmtT78nBReaHdIUuUkbKl1DU0AR0ZJXA9a" ..
	"Mw2wlCKCQeXkpZXyPd0ZrLXERXpmMQb6yB1IrRPLqZ3PJHS8RwkQ762vkl7Z9eUDLqejM/31t7e9s7JTbShYx+pNPHhZz7DB5olp" ..
	"EitGpJA+5kTg7NNOaCTMC+gkZWXUu9uHdbOUNDCu5UDwizMTBTUTzaPuwEcbK0aS25vlOERExgWRKoSgf/ZOLMn/Au4du3B7F9LA" ..
	"fjZzN2rB0/Iz8lcyrHroRsIJqdW819RqAh4FB+mtBfmS7IABEf5A63wa97u1+wzNekeTadSK/DYIq4CotNG5sccHzqNSU0K6K723" ..
	"ED6F2ftMdPhokcRf+XNpv5wqIeX22qTzjMT4ogl40bTLcYa2d3IKdKBHwkPUgUCNPt7GQhd5kmIExfZpFIOsDexV7FdHyS/NYYQr" ..
	"O/kBOMRJ+8DPCMld4hOw/1J7DQReRJG7UNCoAyDWj70XNOkXKkf96ZLImY5GaMlqG/pw2mBAkc/Yd1IqQGZX6kA1eqvnvwHG9W83" ..
	"UEsQGfPKuSwYucl30ZqBwrRQmcsYIBeR8TMPeRPCp/m4Vp3e6/jj7PfIpxsBdd5b5UJixBtxvx1VGfDB/rziUsva//IPvctcnViY" ..
	"7V0azH31Ul6holxJ8aL/QtPsNaNa77uGepJQc5tIzxpZYu67SwRHcqRC10b5BoJ7NkXGv+v8GGKTAAu/dUdDjK/ntkT0Icy0/5/M" ..
	"19MAGFgHu1XGQCT2rB7FsEcrc9hu5+3puxhWzC0CUngj2n6v1jDYSL0F59ZMVhNrMR1S5oiTzZG1v+9oPZw6wD00okNtIMCDHyJA" ..
	"NGhfqikt7r/FNrbx1rrbfOydiQ++B40CP/tkVtQAeLWYc1ljwKRcMGtqo7hnqq4vOs15XilX9AHqXF0Lvfjx/LsK4J+HiYklmiAL" ..
	"u3T4+9PGbWkUS43xYdNFsbVs8vx3rlVzUMwMPd5lbKqXIMOVwzya3yH3aM46GcMxJk1j6ex3K3hLLOXYZ3TMaim2GJoYqQayqHDh" ..
	""
local PAYLOAD_P2 =
	"B2dmf8UD7PnkGQ57qgW/IjhrISr+KwARTeh89hw/4kKcUlEbG9yAyEF2xyMO87R/wbSTIW7eu0yBq9uoeNNoE0R7Pa76N1KEnN13" ..
	"10dT+bD5FVhiWKHXDtVWDTRGKEJ/QIF4Gt3dMFWbtSZzhPdt57MvfAeWG+camIGgzHbNzdKCkAu1xwrlokSh9ONapSAvFSwCv5Z7" ..
	"7W/UJkpppyrLS4gnO9YW0taKLmP89zdlVAhGYgyO35QAxQT+zaMc2avxtvriILOm78Ol8pMIT57FmsZT4pnE6rBu8Q+SscMLIcnh" ..
	"f/pcUtGa/yeZwbNFeBLNljGVJ9Edb2wiu8muuIUpvjM+SfXwoQoL8ovt4JHS03wxqIO2h2U71Ys3J/6IrBzwJSwCb9va9VenxpRC" ..
	"w/to3v4scwpVFIxwNbrSMhTE85bGdqPimRuljpqPN0YvZML6OoabXzOeKK99at5ZRa1N42FTmEoqvemcH3gcKZY4pAHG+mlqaOra" ..
	"gor61pfjX1PSXSY5VYGjE+UG9nH3zEgD/Gom5PM0vR7D2bW1hlh4FSKtgDoKxPQBW0WTKULxDaZ0S9/RgK0ks/hVq6Il/BfmYMyP" ..
	"ioxTJLRR4m5u8gHFX+h2hcWnVRZYse64xtMRcFjtGBYFnyNBoLtDMMK0ehGJx+QBGg0CuVRD0DDo/Ld62b9QooaHzTom7QwWioVq" ..
	"BBwK3c02zUzLfBZNpZqOBClIcrInK83rDWZNMQr+6jnUDzsswS/jBZy/xNZQxlRpiGX1U3JwTwJzF9yHGKHbOE+QxD9KfoUSTiv8" ..
	"GDLCh1Zly0mQXUGu/OAp29C9GUpIRhWoPl5psGC7zqW1T2c+cWjSnqW6qW5m1gkTiqMwx5utnfUqmhPGURxB9/StKSHYmw7oP5ZF" ..
	"6cP42E+kbnB5CNXiNVH4TXmCIeHDa4odTNX3j/lCm5SNnWsYQ0hvjK9AwpV3FWCaoAlhHS3Km1WxGeLdjNkz7LWM3tM8LfVSc0qV" ..
	"dfKL0CdWbBoqptBf3T5BfTSewH4YtT5fzxiZq8oBtshuMbeeHl+9tSrqD4/k2D35HmI0EXqghEAwafbps4P7Qm5sRa2k6Uboua5S" ..
	"2SDv9ET+MKbIo0QtzL3ilANCF81qtZheY/y9uAG8MIlz9v/OwSYuweGurUyvuwbj2ajIx/t01rV6bwdTZnRY9UavGyqxUeOA3DsY" ..
	"8MAsJ5BM/dvCxA6jaEmYodZjfa5Mjn9dydi5Q1o0vgz8QM2Lv1VRXDeoxIgcLWZjSjmSZnQLB1+Sae63bcKKtKKygFj1+NGPQQEx" ..
	"Dna+zekOGUl9W5WdLZlRPnrwP6fFjpBmZHbroaHXG3P7b2akWbBiLwELxY2gGYw6nZFD8eFm61eKHRHmseh9Ja3RAWZz9yeUchD5" ..
	"HMsFFWMq9yC5UajI1ebhQhYXqy6uTDL3b4cx7cC93HggO2IAoYAIY/g6BCK6CYnoBY5vjmtJDpMTPWjJm4k5yiY2AIMQp7aA77nS" ..
	"ak7irGe52dYXKXIgiiWVwrd11nbqpORG/tK3eni3QR5NtCdg/LlA6+TRu548SHG/lkRyLYnBfSgYx63JDmLjPB4ID12TK9fYxkyl" ..
	"zSU+8Zr4TGD6yQeqFuRu4hul9juNxq8wmP2Nu2Bancyuq2tWwOHexBfUo3AFw264jdLJbwdb0INpq9MZSeQ2OFnGDYSHuMYJbAV6" ..
	"fDPIHoOY6FCcxef9YLh0XJK0Qno3OekkHXf4V+KF1YOHsqVtq1RTjtG+Qn9RfsPn5vswTNMlULL1CPXS/ZQYaxiQ/EFDohMoQBC0" ..
	"nwVptdtPo3BgiCJip3RiZLE0uWkHOCeIgDHJQ5GHHsQ+OSwlEZ3eV3Pppl+nHgtiwa93lJHj+Oney4A6vJREc10KyT7EB2vSrSWJ" ..
	"dQw1v+Cg7bnXTNQOJPECHQAflv2klXrG51ajW1EtsjLGvYsxDnTTCj5t2ZHtxDVljZjNOnkYPWcpPptvTarRfhTf1Uhpg/lFqn9h" ..
	"3/ipgbE1jCTxYjx8LiwS2t7g6isOpZb8HDfwkFS4nilfGp1YhOoB/PjMNjtbSotzImqSs6jPKPDvHQYescT+XQPILyIWSTZVOV12" ..
	"FvwGCymX4bNKa6EZQnLkK7gRmK6S1Mntrgbtq8HAZAV/hmVyKtjXANLfszET3kx2HggzCdtAab1l+Tf+FFGoRcL6jIF2HpHoRQ4o" ..
	"Y2ZPH4rosH/b4IT7xUX08ihj2y8guWQssjrGxkJkTTgkZo8OLaybvA5PUIjULxgGR8wHmbNQ+PMi1r/Y8zVUfwRBqoX5JG+AT0Ix" ..
	"mjyBOmk+Hqn6CbgGF7vrEdYLAUkTdqswf4dbFzV2oDQcTUepY4TDyG2bAHP67lcqeOIudsTaQExVJhni/n3VK+H1/BFtN8TJigjB" ..
	"nWHEIiq+bnKCfgf60Ym2UQvhc04Ypq1BMWf2MRpB4Ocomt3DqLPMK/i4ODp1c/Zf85a8YJ31V/6m7Z339cBnHdTihLY6EPLErsVk" ..
	"OZjOvvdvyL+GFu9+bn8uYhVAaiUcaBdmyLmydPFMVcqAP/3I/8F+OTawE4F3gRvNEZoDhCui4kyCIpztX0XLGgsrdZhEFNkwCJ6N" ..
	"FRtmZgkuy1NpxD0FCxlE364w81aYEIGv9qsLfFnxCkAyF4HsSTkyXiaptkRRM7KxqenxVfi75maTHVLYTqUH74nLGHHwE97+rFcy" ..
	"vZStb4+Yjiaa/XxLJflwWeDQ8WiwTm0ALTgxKmrT/rMkBZsN0kFhK5xpMMlrIjsV3GZBwRXKaOQXZxsjmYwKJxR5aZYpnLJZtQXs" ..
	"4oZ1+Ewir5ftOlLVTpTXDARfDG2+YiUudZq53rQP1fT5ewSi8r2AMp/GQzuvUwJ2JLsIHpSgcz0/NFMWkHJb4w5/JXlTClRKkXoN" ..
	"ddFe07njFwomNkCGAvYoMAFCQOMYAP7HlDbAqLnux4/wwiU0J88OfkWr8PiDhGHhlO7/JAVxt0Q+36xGSeC8bLNobcCaohjr3XWi" ..
	"3BRc8TJNiuoqkVzYaHMPZB333eOz2rStBnmgZmDtoctz9XGnrMAC0U2PC4edqlBWwbY6+80bp1WIzWYpwFs6jyMUduUH0XisEIoN" ..
	"OFS/b0ppSgW2odMmZERBzjmRrv7RWh6yIf8Zuty+/qsRtEjLmkabqtEeWNRxeKkbMlXvfyKJebu3bnAHsFlhMElbM7XcbxpZfRxz" ..
	"LhXBXQhH5SVp7foC2nawbwSqMvuQiUpJ6OvESipX1gPtT5dvqB3/ex4p8X+5bUcQU3ZuqjmiDrcnd+jh2tDtl3WH5Oi11ho6BfXh" ..
	"BDWfVVQ4axGFkQn+gNNfQSdeQFUIk6K6fKMRRmJhNDbr2TqnC89VVcyrF9U9f6qrPyQ3LZ3fNQgZM5JUMYXntQ4JF07YhahNTdaH" ..
	"Z6M1heNfbvzT+c3ubgOjtDwtCSDBz3i0742xTsz7de+a7zWbD92wJd9oNdghaKnZqYnITL0W6M1Rk4KQ92LxvoxwvRfGfZ+pAQa2" ..
	"WK+Zre9U4PwgvmcRoEoSBJyJePmqUYJdVgyBLj2pzfdFMUJewnOZbktYh1rY6oxm7DfVFpGodUnVadjubBTNtP1h47CRGX2lAgS5" ..
	"oC1t6lOTYyExG3ybkOb+5wP+w8xiISf9lvg/1hE/1jsN34sQF7t32L862/QpgxzT1sPrGSTM9MXD1C8de/bFd3gJOzM/ddPzAnMp" ..
	"3ulsg9t0pCJzadW6A0NwaMK3qwdkpUJkVcC6PwI7n7aLOx08wHSX58DG/UBrXsPnCivRxe5Nc+srz8i3kABdi7s7HGhrWf2QvuBF" ..
	"SNzqXDMAwfkcG7mYYqlzCTqGetHtC28/q5dESCdH2x5vpPqf3pEmd0UPkv0k5SIe+6fXBhxxSl2uHvLvgbEsv0obgxArqjl9inOv" ..
	"i46mtQr/A67N0N9+2nutPHZoXoGhoUJ0kJjtqjI6hgUPR/FbzqP+aLX8VTL2NMzAgsGIstT3fpnD9SHrUbF2a/RybjKe5qPXrbhM" ..
	"lgbUsRtiDHHF0YUPKihyW9tYZEouszXdnxuLNV6aLG3vlq2GNLcfJjSSdaial1ifpQ6a8EuYs8p9fmwfL7cclGb+rPIm7lRP9Nwe" ..
	"+G5NTlDp7DzYenUkcdhZcqLaupBhn+E7E18PUVDnXOEMui5NruMXY34dL4GO2tMqBzAyOg0+sApBszagRXDSOIUjVzQju7EUQTbJ" ..
	"JAegBEsQpEmROFrBA2D3asYhwuQubcpr9Elp32LzUsslBmvkUMRndUOADdQSwCpkYjFaBlo1/lMw7IYycbLOKg2V7vHvo8Ri2Rku" ..
	"LK2EvXkUyhQHssX87aefS0O0ZaXHpBdo8PwpQwy767jpUCur1xPIuNPD8tfr3zXErng+HWYd2R7HmPmukRtuwnTC6ncXosHBnEBr" ..
	"8es0PqmZYRDYw5wMklJxyif/Sd7UfVIsObvIpJ9oHDrri0ZaZt4qPEeiqnmCuCXj6GVBig/6SKTlGBldAob0PIInEqhvO88dSCNG" ..
	"mp11T/bDeUcQsDWQQrE5vb2czSQkUzJwuEDDrQSTBrGFUJ0wIHFWgymg3X4xxVbfy7LCEr0EQA/a6tkQD/14MEl7U4nVPLEUVTvn" ..
	"5//gyIN5sYfKyWmXkwE/4ggL0IkH+DpB7+/Tfa1KHSf8bahDUt7BThEOB/GUWb6X39n3BVoFjN4ZzFZiJUqkqBc5UPhpWYid9SUm" ..
	"70byGI17/QEwHsbiBfRFxTs7oJd/FXqgyFoM0VyIpaWpcF/A+zSv2bTK4I5RK4raPnVhvzbsvlTwfbgudxnNWJw3vu9VRPj+DcoL" ..
	"fUD9B+4QjapyWhu5ulyRD+RknVXBJDlLM7zNtPhqaQNlDxG/vKcxLNJiELppIRgtznfjq6U3gKnC6Wb8cHtuCo3V6UjkU7+YtQyr" ..
	"MVR9o5VToyFyiWvQpNxaCTzrHxkRYSVtksDYxDNRJKz1XRqJNV5fmmhOfyvkZpr5hIusDMDTME7z1WikDIZHOKhWIZszRL1HzqDc" ..
	"62sE6Ab6HDLsZuRho8eZMIw8WSdxcSpz4zFVHPbZImBdXmTcvJ5NIhzekCUVMSlHXY0z4RkQpx/yzkH+RJi+8qLjrcRBzIhGpbMI" ..
	"GgRnKP5//unUtizWb8RS7l9vYZKlPAEjwUlW7NoERiyBJxWHI0fBvqmuB3UGsldUhs410T42aGGRqrAgPCDLsKDqEw4LIAdGHQRv" ..
	"IJtSuFbdY5rb+PKlXU1KAkklTrUShVJ44VE6ttPK1AwC9nlGFEnZ78HBX8fonk6fByiD0OoIWyg3jxtVIUxyg1CGJ4WK+rv2lV7P" ..
	"Qw7LBaEF4yyXXxP6vBEpA4YX7qztug3M1cC/zWP0Hr62kL3vHOLsCnDTu+UjawMRN+J3KyDCaU6sbrsblVwpXBgIIBVowJHr0yKY" ..
	"HiQU4y6+Na/YMKYmWNGn6M6Pq9zLuDZxcXuI5ooANMVFt821rj8WfdoADkH31+s6gaCcpZiZAYo0vC0lzmxeUpTldcLOFbaj9c94" ..
	"HFRE/EtBJps9+QIn1qRMMuMFk82NxQW0+fWxxNe9RnBo2qO7HTVzgt0VUwO0gB2aIqy5oYdiqKUd9Vvy1c97J93UeQM8LakiU/nf" ..
	"Kl/oqjSeFK8P1jklKpa400C5Szp4ZwwgVTnFQi2+Y6b7fgY4OtuNmPIbHAxvCPd+tNyXUGZysMrGN4Lqc4ISPB3hHPUYKoRgf9vz" ..
	"bdOb6lc33htuzu/kbPvh6QRwSqaLuDcXY49XALhyWqEdqJ2eyERYpsR3incx/bqW3R3KLCC+fOkfxAaZ9uctjtn09C3xjPny1yrq" ..
	"9PWOGLP/njG7P6Eip/wepIytkC6DD89yyZ7iHc1b4AI9l8dZCY+ovFH3sDHk0u9hhzG4PyZw+mpvfHMRu/U6hCTw50tapinzMWlt" ..
	"64+vEjMyxGWkLa39EAYWAB8kVB9Ph+cy7YGtX/tVT0Nkda0UQo3EFa7T74dAG1FgGeWJ1GYqILHT8BjLAYQ+NYfRfjU4/ITqeaNs" ..
	""
local PAYLOAD_P3 =
	"x3eTRm1Jw/iGlk2eGuA7z/Gb/PpW83WYRT0dkdIldjFBeG2mnN7LR/YMKuPXC+xYDm4MRHArpDWzSN5FAolBixmZ10CcYXnAmbn3" ..
	"YI9wodKofi6KLdv1njH1Xhuq7hWV3jGw69WTjjyV5pzonhl5jml4mDGX/fpNq9727C7wDpb4XTMM6uvIKELDRNABOxZi4hyGSBi+" ..
	"WCUF1nQgk/PHNZrH+N1oqcFW+cP0DDWuU8/b93ng3tOviVuRK1YFUjbiGGOAsIcFU5bJw89XWvut8uQOomB8vqsmXAJbw2m9GGro" ..
	"rvDxVAiXba6mVEUkATnwoh03BGYXurnSD9zom7IaRxUA8sO/N1Ap9XvDotI8/HCV9F97lJgjQhoFFR/VnGP7EzrCi7Xd3o72GaIn" ..
	"E6qVhSSouqsk+MjlBPqag2Xw7gO/vadX2NGk3bjOY1k4KWY30RZR5gkBZOjfEy6vjpHtIBQGr4o3Kg+cs5X584blmZMHtT+4Q7JY" ..
	"kU15H61i3ZmwWZrQQ4wvrVNzPFOV5NBaz4FMI82V/Nysf/837PlZgLvD0X7hiQEHhLWM7o3f25aaYawPy4uV0eN2wPWDjzVlh28v" ..
	"ZnJ3Z2op2ztz+LdG2jfeU7owyaruL1Q/6mNLh6ZxBJZg2vDwMhX8LyUgcr+PvQFo7CUDoLIKOC7mU+HoOzjajV7Uq7hg0zA1EbXY" ..
	"Zetuj0d0R8SAAYE2/eLbupKjL7eHZsvKMJQt9sHj7Mq3U3VqXmaI6LstOUVHS0m9mnUx2N6FYI8JZr3O1dqV5SnPsAWd0xfMFJF9" ..
	"DxIht7diy6SUkAwdTYFwByXcSjabQO0RipKTTnI8HUs8rfciM+HA6nH5+G5+U82+dwJ2/mqCBeEF5F31OS/Ij9GZM7ll1G16s809" ..
	"dD5XVf8UX9E+PjZRIYhxjL+9bZwEk3swDPePf/CuSVq2XlIlLADg84dSz3AxF13nOcyPqwXymMkM0SLJrG9PlVS6kdzCzUwLQfCs" ..
	"AWSzd2bpZVXHU2+3DmyXs7kSETSwEuhagRbNlHo/xWqDGzbSeZnkxKisJfoDQSfS7NjzYwS0EhQ07Ooju+p+6+bF6ZzRY4xleArb" ..
	"H9P6jlzbOXZCwZEn3YOGcpo2Ugy0xaDlS63gVhJdmy5TAGzZU7NSVv9WbRAsqAnEDkc8zJtc+6glhfoc6jNf1bd71ny5sO/XFHod" ..
	"EJzdZF95APh/Xs4IqGc1HsIElIZQAIvvePUf03HSzr8p5Zo+bBkP1u6eDSXP9a1qn6sjSMSczfIzL7H8kcgKzpoYB4ocyRIJ2Fn9" ..
	"6M8JQkuI0kKmSOPAIuefSVtZqs39F6H5fNuO5pMxyF4pHU5zSLwt1/KYI0nCbcBrohsmv2ldAnp8u1+I0XvbE0KxPGhBQ4Wlbl1D" ..
	"WSBbi9JlPmY8AlxmsAFOvi3wONW8Td0QLs4f+Yz6FSnp23SLMjUqF4n8a6lF5T2zXC35QqcA7JojKsHkarzLOMqByiFvy+1IXT7Y" ..
	"HoCNJWDLdGs9UhKs7Xp6RAbCJUzyHnFbt3umrh68ISFdSGQm3PPN53ga8oNN9AXPNYs5WxiDgdsZeBjHU/Dn/TG381kzcKXn+aj2" ..
	"iUXb4lWI+we9CTn0i2s/1sGSInWk7DEvNa0bdOtr1RgyF7+MFzhnTwT7eSu/oD/IqsbNhHIrIBMtRKO9HV9Q/t1YH67dXQEL07Fr" ..
	"KgLI3WxmRtDZIoBzlw9TkbtAuklHLJpO3lwlOkFoP/IOFgn9D2PiQSPBfITlXh/UFK5Y56KLGzzewozFo1Z+bfoh3ZNpX6dC5hSO" ..
	"pOK82HX2efASG3ghBgsQNSLiyiTGT9c1xIQJP4YEuNNTrVFCNITIsDVw63RQviKKJ1hHXHJTEaCDy2IOoWIjnDRx53GSHNDU4GKH" ..
	"1ft/Hlga1ijOFqPYNCsl7viKEoBtc5WVMOcet1RLQqe4OPyN1vvnZyTrGs/iN63XTKAFeuHXLLAEfeE1bKU4szOCZJLrVdgp6OgQ" ..
	"UDx2xksd6mso7mJ50KHH20RipmC8nndOHF4WSu3zmGzmDxdDownu1ZBtntFaQI5KFLaKw7qbZAnb2G+/lXsed38uYPbsUU1DXUF8" ..
	"xbrgD32Z4MlqKzrHfXBuZvXAO1YOYt8YsyZBV5VBqZ7iV+73MSYvp9y40W6CR8PUJdtofbw8RF74tuPfoXsdlDWRKXGi+9WhgXej" ..
	"SJqS5sIKcb3+MYBk/GAg+bsPaKM9uVbCXs/Cs+7YsdxgkAk9ZmPw28+JuDtwRKvxoVIXq1FxQxBWL//9s6K7oaZvtfMQikWyf/kb" ..
	"IEzfiWN3LqTc0/b2JmucOCm1BfnBjRGhdRc+mBFlHdN57xh0VrRMp5eKLB1+cLo+xEZE4dSZyni2Hu+xjWDM5cm4YPRS9oVSKGmj" ..
	"LtQepBKoVJWPilL8vRdqHPFTAdDQgRG4T6uuX/1s1xVh3J/2Fg9USpXz9Ggd49YrxMKI81HuKiDGtd4efrzagXKq0RWGMFWbfNh6" ..
	"c8l2xeTMvL/TBsXck7sAGXSSTwEyChFRFFgaQSH2SzIeikdExzQSTqjsKbToXCL4PRQJ1pb7MoQai9a1YmMUt7+XIKvADwYWkY0r" ..
	"NLm2KXqGZvL6wwVPrQr0z4E1Gw32saL9KRWgJb+u6d7LgMR323FcKtn4ie9Ci6wP51a70FFLAYV51rX++ftR+/Tcb4jNTj8WHaQE" ..
	"1Jy2DKxWN2G4Yjj+GZufXJ8z+4q7QQLThxbYs50XLKayjJIVJNbmeBdEZjZucEByqKPJX4Bb3FKkICfeqEn6IeSL3rb6SkTtc9WD" ..
	"k9frR9z4lBSvq7bQuqJVm/MACsClu7HK71j+PWXjkbiUEu6QTQxia52+y++NkqxsYC2G0OseYWP8D7WV3U6L2wRe/HaYfJjg0qC2" ..
	"Z26Q3H4Lj3LbtBCLLvmDvgtd6z/YG6J8277Rh33OZghAFsZB2PD2fZipC4grMzD/kpUDAyqhFiENBv3bARwgXIiCL/VuwNQoCCVr" ..
	"A/OW67kpXxLPK0jxXXeT0y88/Hw77V4c3wQl6irenp8rDyo9DqZsnFt09TdslovswwKONcPzW+HjyYlLcLJzoYSYR5L4/+nptWkf" ..
	"WKAaGyP9PO79DmSm9tXKlj0PKmQBHB/BMoa9PCWDNVxIg7IF+RGYJWdldE4QtYm6A/jno3M3n7jPfCan7Bs1/kutjIzl9NXISy6H" ..
	"4HIS+yGwdr9M5lhhnBY0wDyKDytiCRqREl5HZEMYdORURHe/jxb2uTOvtwlm3NKT/V5hhxA3r1iBlqjdj9Yig656izC2YC+M8sPz" ..
	"Td4wMGQL1s//TEdzQICoovBzE2H06nZXnWQzq5i8yyG0NBaV9OEqiqMgOOLs5Hs+tHqQ9GG5B1gA01SGjVZ+MGvv9HUjYhiYIaby" ..
	"56pK/ast5VxTs42INBOFgpfX5njeMakpMF0b/60SbR162ut/e2lhVLXQXAD0yuT6QwfpQ2XHH5Nj3TjZ5jADTIgQZfeq6x7mQhne" ..
	"u9AFiPQM2aOJ0yhjA38SZn+Ypq8ykHAdtQeI/CpYi63ytTw3sZGEh2FT8M9MQ65S5fjMO2T+J7K041B1Hmd7Mzh26rmkNo+8cOdh" ..
	"8SfeIqvjLRvqoE9CLB2xz7/75BYKgc3J1l3JeLLLO32G1pCSDSWnIDkVXKo2qnU5wL12KfrV6qGG0qz8FFm1faStCZ5yriYIfoHP" ..
	"+D0E71/ZMmKM0j+mVkY0e3rGVs3QjzrrRO0ThZaVkz4k7M5UU1HNHK8ND5HyNBSUK1O3trypr1mChxBJXBrHHyGptD8zZttM8GUZ" ..
	"YcfxqVuwPxAyDm5EvBRoDL4yM2wRchY+YGBhb7xhAwVHVAJBdMyLS+rUL5OOlIdUGgJWXD3v90KBgXsBxXQ7ClxxD7ndBsEl8/a4" ..
	"gEW4lX1B9TXbeojZ6DkTDJpWp2ejA0PlCM3cS2frYbAvShLcOYN92Yli/G/54uxvq6IYM7ActCczWW+QQmm4U4SWrt+TLtWgrUB/" ..
	"J9uVbXm5PM00zQu5ZmuNg4cvSdk2gkFHMJW0b7gbAQNHGwWOMzj8g74VVOulFOFmn4OKi+UnlnH/ICBsW+NiynJjfXB95c1s+b5D" ..
	"MXRVQM7nH/GiCnFgGhL0Va7H9WNz5GqnNpCNSlzsSHUJEa4b2dRxifU5kxglp3gf6A4HWymq9rWXHhiTMUhpI53DOCrEgjcUogkz" ..
	"2Q2Xc824/6fd2+R0xRKEXoqi8tABwsUzyoQKYmayzeZJk97vTgafVRjSQMLzAUKhJ//AyISFfIWfotk7S0Ebl0FnqZ0nkKR1IEs/" ..
	"Tc3/v7L4CaW0T7MWNSp6LY001hKiBrkjHSiwgAngJZUzxPw9IwH8vu93xVl/zNGxg3iEj7CvlBji37Gkdx4TOYBV2vZVxTvjAY02" ..
	"EL4IvVBZ+5LlzoIeQ2vTDVBbtqFVZ5TYmiL5Av5gA0jtRTZEd2cd0F1KZJiEcSl9hd8rhya/OzIIlUtARwi75xN9uczisokZZIyQ" ..
	"o0hQuPNwsy07tJEglN0NydqzbiL6zi8c47eybvFsrqfrlkbxRjg81yspxSeiDgiiF8uiACncQo0LhNpdTNohza4uiU6w708akuE7" ..
	"foOQsyK4FxXrHhzHj9TihgKYcJizRJZKhZ0K9smNO8rK9eRzo24oAzPPjl9HyDnGc62aDWIyCCD0gmWyURiiVZwTejR2fldTlg3Q" ..
	"AGYO6mF5eBdnhRJOs9V14IYGva+wrhbn0Jr43agHWN3cou9BiVnlRNBLIEbK6QXhEJnprfb2qRscsurXlpq1eqcahj7csweKL7ZM" ..
	"MBFCtv4SDC+0uXMYS4pf7M/m1uYDLlSHhLZb887pMkntb5pPm1aWAu9L5fplVeMeFGwFpHbBvK4fLkQ4plQFg8cA7qRj2OyT9k82" ..
	"ZdkF7SGp4e/be7FVVtN5hasY3HYaj9wSaVaJfmxii/A+C1rXfBFoNt9xHNfnHNUqalTRvI8EPAWUibXtqRX0wHbTamK2Cm/pSEL6" ..
	"iJYdiR7R3Bk9288Vj6bHXJhnjSHgfFwmSTYAoH91Tp0Y1SSwh/Jgl0HFJFm5dqzXF3jYYYCp7fVwLLnR4o/xxGXgJj/2b4JKyZry" ..
	"L6VfhA7/+7yDaEDhgyai8WC/qvODVUEUefQWoayLqz6rN6KvgzZyE7NBdSxbN/SQp62fS5OiutGlHYe+Q6MnEv0zAgZoJsR9RaNi" ..
	"9l7njZdd15CwynWRSojSiLb3sLcIy4XTR2Fpvoog86iIvWNA/aKKfShiTD/85+UPydSLl9TVCapQzps4yXIbAkmgA0RkMYghTvYl" ..
	"oOWoLx3iCrr/QIGen3pbvZFw3rRcvigJVze+DDCHpuuDd2bxAEdBHPnwVHQaJmEcNyqGQP26omZibZGhIM1gCqFUN3KdgDxCh9oX" ..
	"FT+QvzWaf9P4TKi4gmeGWlAZaeLtU+MXpz1S1qLkB8S58T2qK/4zqDgbsBBupkfK6TK9kYQVbBW5EUtcO7cGrLcTsHbZR5xHqSY9" ..
	"OhqesTMP98uek/6LMtnAZcpxwfsPWcjiYTRre3qW9jKRXaevO91mYdvpnyZaU0ClOP8TQn7gkZiNobP6iC/8x54wU60ZbeqLEASp" ..
	"o01S1yjFsHhxUod81Dh5hjF1Jn5I00SqI6NOWGRSIQpJlipUF+BSC2wXM5ye7RjasWot+IHABmUPVCv52yauhEVHzdKecpWLQCVh" ..
	"x6mC1BN0iK0CoqaSjwmHhd0KhKhtF7G/dZu9VMkJVVqXBVoGcI5Calpov6siCFF/PD78F0aq84tvjvuiHBf8fZ8FIV8zdOWx6blw" ..
	"1wEZbuqnNeBZrMroCrpXaVznwNci6YN1Y0EHnX8fipBRZcme5mBWkKF+kkylm5/AN/HUpREcH63fIBeRenbc8NfdnCGmVK5T0lIo" ..
	"aokfENzC/eFswtafk+h0fxdzEpIh3KxxSwdv83VlgtU3ChZ+CQVEuFb9hvLHLJN8laUjfjd2CBtHHnMjobGcStzZ36HkfMfhJlT9" ..
	""
local PAYLOAD_P4 =
	"GcGW1MNzMABe63ZT2thfMa9QaiT10/Ocpck/0HKcDgaj2mo+3YuFx5bEmkkUnOdsTuV80akHrjKtI7uWyWLvg6QsmYlWkYvmtnKG" ..
	"5NPe4eJkHKKPHfw/73Huo3VC/vK0tgxivd/7vMUIKRLYVZQPh3Qfl1h0W8xNwP4ltTVjEHNlc0sVSZ6bBoMQsjgihSZdnS/pIb9D" ..
	"RnFbeRNnbvnBbrYuixTNHAQGS7RSeRhcWcFt1IsITPVHhW2Ajb2nI9pKe8Z78Jm9NvY5HXHsWFRpDFh15k8hfta8FIe9wODjLFmi" ..
	"W+wu4GxkWi/ssC39ky6oX/USTJDjEd8jFlqplhSf7Nx0R0XM6Kv/xH7RwxO5+W8ENnUb+7g4ymaleulACZ3RLKhC7w0MzXEs6MHz" ..
	"++piXtJdHsAU5GMuNySP8xLovDlqzz0gN+SIksnMbEf5nWF1JfyeLdb+R1XYCbHfy6cxYnnMda1GEYmKdf0p5uh7zvtoc9g/6EAH" ..
	"propwkceE22NOYyE98sSgfegBwUSl4WOE6Sl/Qa8vWl8CL0pcu374S0sVm0Vk92YBjsHoHX3+ntPknELukLeQf6MSEXVvT90a7t4" ..
	"PknCEjoFvRUiDRzd/GhPqitt/hT23WPMLm0BZqKKdRWiY8+84+JQEP6MEMzCv525FEHX76OyAmBiS7Bd3/580DuMZlu9eOwUpgUn" ..
	"BZ+mWLzjamNk5iAuTHoAt0wPp/WahhH0RVwr/uKWBygZOIPUuHuf2S23YepEXzJk17M4fP7t1dlk28pFqW40vIr0J4ObeTeIIF5Q" ..
	"TZ6x7rCcgK7YBh+Myy8Dh4YqioqRbePsFirW/xydvlvHLCRAtqjq5iiLiEGXkn/UiVnBvOTgHVeXPHt1mDTYDmFxWyThVC8E3il/" ..
	"m3wJGvvXtYUiTjA0dK1XtaX0nhIg2cMh2s2+DpoTneAHIXHkx40Lod02fB6N96gmdHQ2EO4d/uGAzU1CKd+zVRHEKVAlwdugXH0U" ..
	"E38Ei0Pzja7s6Y6ECLvR1bBRY3+ajF8+HhdXoxpPSF1zd+9cq3KQjpm4qzwB/6R8lZt01h1BilipKDbxHXMCPPWbBittQ+ATh7yK" ..
	"ebRe+63Mt4VlqII+FjYWYWvuwcNj7KHpRrA2qpWmMPQ5nZjoAvy/I+B4mL0OlbzlzeIZQnx5ibmCJ3eWZkUZk0+AxqSsFqLzACPY" ..
	"/IxSVlGws9+/IGwU2spHumSAn/qiFTRxBgu1yPrL+FvkaWctqmJghHKO0cKgX1mRLRHpZbY1KRBFdiJkavt2WJiTWRiVc63QywA8" ..
	"dok0dLcj5doGAUaHoTvzGgR9iUcdOX4g3P6BSphiscxdS31+Yoy0Kf4bgTz+togENnAnr24CltFf1O9D8chjDbbvMZQ8oJLkCVbH" ..
	"zJIZul/6QEO9URllJUk8fM1+31BMZtSefSpx64OnNLpALmlb4sEIVSnR+IF5OkNukVQcxMVABACAv3ij+cHqlfQ0SbqqdBW2fm8j" ..
	"Be8hQT1zT1aqKaR+0T1F9ciHxu5x6Yf1RCWZhpHXJ+K5K5sIDUc0aj+Wvnhr/hG0MkqOsSA1p8nxZMmDmJ8hRKyKC8Tl6eV9ero0" ..
	"Q0XwOri2grdrO57HSbvrLb4I8knqmzQY9fFRHLyrKX6mHJo1pwCu0GV6AzVPRy0icxkeAv5xoaiWo8W2UR9SwuDXeSbUGb44kBom" ..
	"q5ex81ikHXSDCU3cfSv8wbU2ru07VQeKIvMcuzHdBQXgsEX7MgUWgWKAsWz+ZCKdeOABHGCwh2SPK5MFnvoGi/JD+NxsgJgmx16w" ..
	"YjKNcYr/E5mqp7k+IGqIL1KDTaxB3J47eOPdQmygSxD++nI/faORgKBs22XvYrulysMRvw1dIeG6fm8jQLfCaz/VgpExLHd59hSy" ..
	"WziktKODarw52yej/Xw9Sg2QLX6fVxduf2+/rr/bcASjINHmd4a8drPnbHL5GMN9MdVTGHCh9dz7ZIdlJzjZ4opvd3zO8bCINplH" ..
	"Ez/77fEjKKbN+IelLcG4c4nrsbCLjL+L5BXBfzaocji1jJEK9UQxTDYVrrSU3Ov+uZBs/58TevN9r6rVnfyaBxhBmnWAUXAwx++u" ..
	"0J3Xvln4vh1jc7FFfDMjaIJNHa6/iNjQJKq6ify1VU0Xvcd0gDnUlb2PkI8qsKmDxCvbvBsIL7u9d6+S/f3AflDnv+f7YI8bOWz4" ..
	"VLxkqvDJm36mDOpkUIyvERC+M9ADEy+Qu34mXTHtrovpi+j4w5H7s9wjnQxCNY3XrE1zkwm8dfjtR6VboK6XWn2GEDhAZFhGIvqM" ..
	"FNUd60zFGD+x8mizoyr8T3hgBFZZXAKshsccDpBCbBQpxsDZtzhmx61D7oYFl2zC3j+Dyl+vQUpVxskXsLrZz3gNOt3mZjWG1nAG" ..
	"xTD2ETQkLTMaqA1Bgk9900uclUAGqWgsn7EzsFzKIAxTq9l/Mg53SF1CC9xNp+14omtYzV807HhXjMH7uyurAB1ojsEKdaSpKl5t" ..
	"yI3PCO1AZRlEspwpwxsSMUP1qbANVRy11uWcRDf8t4/GSTNI/YC+0+qg09KFSCfAuH31mcmSV2kL/LMJo9ky+WtGc+I9ZMoC/zS7" ..
	"pDr5+wRNKIXGVfeKo0e6Q5LLYqUM08ErwGkfq3zGwDTMECNS9PFDNgp1voZl1fM2o0PCohis/e6UfXchP5J3VIBJB8iZyeOzI2+z" ..
	"/RBkm3SwC2ywwBdFnfgSN1S7KlXV05XNbce1cQGds1HephhA0R8b9534n8KX3qw3msRP5xaexUcQKAZPXW8QHlWP1Z4RSjWtUvSB" ..
	"F/r2Ekb00KRTA74q6VLhGguJoT9mNxraoWkKB0eG+tJccqnxRzoNVwiT/RbNsxf+e5W953N9uMI39/iWwBTWpcLNzOewxXwexWfU" ..
	"5BBKgMT8kqBW03rVr13dmr/axhUBIUojVTIj8CSE33bJGgIdEieylI11gIvYEV8T+8IBG2ch1ZKnEkPhqe6zsOtu4b6QzUjrg+aL" ..
	"hbCI6z42czuCEep5ooNMvequHi0JfAVawMJnzzVsKFRNi2/k0rpO8rHdabOj+3/4r+Lw9zyL+7nFXwbi3Q22kwyW1zFbOxAzfYDU" ..
	"iIBiqrkb2EX95/3s/aaRMxQZLhDLTODdViD3YZKqomnNqwAVeWeXPGZwJlt7j8onYAu6odRyS0s3ajJn/ADssxuKLdYuK2as5fxc" ..
	"XpocFMlsUVyFqfVp0tKvXXNwsemTYXmB1xi694yZjHDfsiFwgGkAg8aXg3Miu5s77CC+FSHSJXPz1jIv6hZvvaN4tXnty/OMZ2po" ..
	"WiyisNVce6XBAU+2wHhvdCBKKTdgSsgQwEypkrXIkN5rFVJKrgdofSl2aX4disF9E7/GXRSkVbjFn8FbNyuq6ElYkc3kqKGSpcEM" ..
	"5NAupS/Sl6DuaU7Rl6Q4mvFuI213NIpXADd4Lmf1M1bV7DilecSmI8ILFfQLSybhgh3SM5mHQAXgQLmtLaevoR5qw6vimPLpcZIv" ..
	"KbJXsSujyyqmtgCeox7MiR7LuoHPNNC/9ekZOmIrZ/V8ZeGqWsy38wjxK8qPIAZmVb09MN0Xf153Tw15Hb/YECsjD79av9ywcOBh" ..
	"19fLjMj+X1nojJZyFInAlwpQWJdVoC6ICLUyD//jyf1B/+Bj/Z0aJwcu3PXx++XMlObOhc5JalZwE9tIZhOotnPKUWygd3Cx/ne5" ..
	"PFCKciu4fVbzLJ7MJqmZpZyo237XVPjW3gna4wa8oaHHAXB2YXl8JxU8y0HgEhK8cf5MN4jkpsdrzDtN8DoAr5Hr+TehL3Qbi71c" ..
	"GsVr4X4TIflwscEZ1de7eye8fFly76szkRtd5oc+WNEKEu/d/a0vI3TgryMm55TBIZ8y2abxdfwIrh8TIQ7RrbdQaqoVCmApmed9" ..
	"UEhdwWD3xJLO0RhEM6JebPlKn7kxWNqkfk4JM8XIk1A/YffN2gzjTLvieF9esxPJDNBlFx8J3NVysO5k4IPb/htr69fzXKzjU5zw" ..
	"glJbX3nGREUVloEKDF1HD2nv3Qincui6bvdi7HJeh+b5KwdAxs0e8Iek3TOwuT/DNj9Dv/+qK5UXySeOT3jPFUYKhNKaqIGXWPn7" ..
	"+36uRzYWR2mirZ9URa5PLp3zkd8N0eyO5Sjfsjm4JNFcAQPHMdGi2KuWmFoKpGlyhP3JwVgMtqABveLZ3FpHJuxdDy2nPdAAbVV5" ..
	"ywwVyzNDPrrzPKwWVw/tSOGpYIOPX/3YEfA9HCdtJkuZKYikjSa3GhHTe2Kdf0xMeIQ8+b4Y4rS26WWYBlNEnkHoZGk7V+Ux4znq" ..
	"Zl+xaVsWLVKuxHEcFdiaN09bhEyr6GCwZJwREt+nZV//ocvEgVwAVhCn0vz5kbOKqtaT5LDIqYJM8mnc2NoY2aXXsbyS1bPpT4V5" ..
	"X3KaC0fB8Yina6vSEPnTc1EDKLDWrskyxxWbUYLAPj25QYtYNyeo8AFt3DJmJBWZVDJRkD9iUhV/q4ctVtWVimhQQwvztWaRuFNA" ..
	"8gj2CxqhNMpc7EM8ETJiIo5VIkmLQG8La+joOlMRMsCPnpMv/CfcQRlFnpp+HslrVxg9/Q36Ywg+STwnPb8h3uFMcOpl0m2EbIsd" ..
	"HXqFlRGKN2fZ33ZnaY1t31QYf170zwOjVPB78JoC9nMW96X1Kh4G+819HBExK3pJw8s+LLsOpzzaHwClYq9JQB+PPdVis8jBwJxl" ..
	"ss+ZamTKb9C1IF5iuW3EFHNOjRZ2YuWD2eHafDxYanW8Smirldjo3hwoOPUxXGxWzOoHv+Zr4Pot1XBgH4CMkf7125LB/zh62v1V" ..
	"VK74Y4oaGfz+2uZg9togth49W1JqkAEmZKkMz0heNKEfWo6NzcVvgY1Ttfz9sjv1Af4K4wDAn8HfqwcyhdqAKA0nZMjhjHHWmxiy" ..
	"diieF4trzJLxi6jksqjIbhFJqC6IJTjMwZxmAgAl3E+uL+ih897WnUjgKtGlKU+t3Xyb2jdt59hmaJD4ku4vFGgAdnCXGw0vOE3p" ..
	"Wo56xviQjqrmYsJrdxbPMLIGgIq+Axx2OkTrtCShtFP262DcTcgQYaq2JM2fwSvx3mNKV5G9avIDRebRmCrk3YOITXeO7Iwk0rG2" ..
	"kQLDY11RojsrGV8uYpLKIhg70nas6dZCoLU+pdN8yYaeZOhQ6JR2244SD3nMh735dkv6sMDXIarhZ3wjO1YzXfQXUHX7SHkW5g0Q" ..
	"UiWHA+XexTnuYewCin4pWD1HxynJkVt5vclemvJI3nI4dG0U3bj3jEblc23X3ECZZ2JPV9oxRsC48ptFK5yWGbfyhwqwfh8cRhT8" ..
	"BbgX1NNxBi0akMaNZOOUrlH6dMyEWtkRUiQpGGJB07anC40Mzo0SdsrHDj4A8r6D35TcvDEw06SZ1SvmH2JsvPDDcnk4N1VCra2B" ..
	"9F8wVxx1GjwYT2DDkG8eSFKDehCViYEqtAKJ2VCiSmoi3LRSsOQYtvpq7MVhblFU6ItqFuEMqtOj7df9RiVj6VQeQqIMHUKapBBJ" ..
	"eIGeRlDGwheMlAl3wVJL8TO+V06Qkwc8nuc6ebv00B4EOv56iy6tOp8x1XFYpSPcemD6YpNXC335ztY7mn6Aey4748thYzqeC1vd" ..
	"z6tnMehGqR1E7XFt4FZrgpgg0MQE/y6Hql1SNd7ZSmGyGHsgG+1HG82u6ERl2gzLLw/bBGJNrkfrisftOhdxBWV1ay1z/1vVG4vg" ..
	"GUXpiX12bfU7iJopUE2tZfzp+/LLrj1YrQVvkIDYvbUl9rgKWABPQ4g67a6aMlmCQ/NnTrmgG9Kq6G5ShhtWaez4zta7yuaonlvq" ..
	"38Q4qiB3YAJZ6eW5DKQb8sn4VSKEhWlszsChnwTlABEf7FSX8+ShkXcu1UgEq4i7jHNU0zgOw/c+rEE/vJmlxhzueTAj5fCjTKRH" ..
	"c6c9iHBBsMEX4YnX6TjFleDGAsawaxzJ+p/wEfxFFnhRsy8sZH/CF21Jry4mRun6PWTrAqQkftVqrJ8oVSfZS0V2T/68sdud/Ova" ..
	""
local PAYLOAD_P5 =
	"CO1ziYj0wm2Xu0G+wIRkVmxkC3EwQqxbJxOAdaom76MqhgnM+yaXr6OicdF/6utg6O5Fm1BudgkChG4kHs1EfkNDaAHLzQ4Z700+" ..
	"eVO60iEDj0fLmhjspbE52MoO01/fGv8vkD16yfY2/bW4hAmgSCsQT0KHX3CoEnttOIAOMaluDY6bFmhuKfCF21hS2vxooBXR7qgf" ..
	"xjiLbYW4O0xmaoUqL2IodXRM4qi3nAyJ8T9GfGVkO3z8o/PzT1P/Vp6aLcsoN3FcZqaBchxRz14aC1+5sj1ePcaPkkS1V8mpxpzh" ..
	"deBLpkhw+T8BhPaSbnG/psQsNdQql6Tz2Xfu/NnwYpVeHL7W/2+VeGQBj3fcgUmsHQveLgjKGUnReOB2VCH6rlEcUuoC8ZJl6iEK" ..
	"8usZtPd5Sn8gKSJeox7J+0Vck0IS9Ml0E+wNimf7gOc7p+7aFCwNXVJoYOC5GGGs0+N/5Mc7+rhp3U+43st80FhaDwdFQkGh6K78" ..
	"z3qJsAJymgzZ7solQ6Nvuq8ldySOMugAmYUB4wbhBPny18TSpTRPF8Td/Pmt569+ULMXjSwq3/yU3Up0eTTGdLQUxZ0znghYRCbl" ..
	"/PpQ46k/cihqy49fRq9EHVAu8ZOWigQqxP2J2Asrc7VvashwMu4lM9/zRU3Wop/qTH4B2wIaAkMU+P9MnY0CN1Bgg1W3/XcCfvxZ" ..
	"bONSOw9ZNRZF0SEfDTaC6erUCx8+Ze1RpxoTuX5jZt5HC44MOeeedjpoCTIPe4KUvLYjjdQ80jkn6V8wSb9ugizTKb22QHn70TXz" ..
	"xZ8iVe+1DB96sKLDuauFoAZ/OMwi9xv6p6/YD66HtopwzEOoCCXCDEZWJ/71dYWyn+o7k0B7p81lqQiVWqAc2ZGxOcgWNkplsERf" ..
	"Bjsl16w6ilEmz7q0OPQPplKA6RSWcoC2D/mw7oq65QcF4LeisBbhWSHlGh8t8O7fwi75Pojj1gHtKAIGmSi8A1J9d/XROKEqFd0N" ..
	"Qu3pGbyr1mq9Yeq2+bX1TK0mIFF9Fo2ithToBA+IkPxTk1x2Hi20Pti3JWkIXfW7K/IJryB7VBLeZjOZOmgtgUy+zKR68iV5XhVy" ..
	"UuaP49bsmbVViVoeBw/X5L/64QVP278FneTpWzv2GPeui+/sL0Mj3nITrWW44YUcnAlSUcN4CW0EaQhum+877Peyp6hbYxFspzPm" ..
	"/qQq3ou2FtUs4YS9AQaE0WSwVBYEZwrgZ/BaOHoYSU79dtdUfOqqGVCWZBvrMl7Slj7BNQwHS0qC+T0wZ6EIlIDGMxSqx5escP2W" ..
	"PgeaVX5bxAws2fUYesPx65U4nGuLY9qD4wzyyPyi1TUsTuZnUW+zx+Q024/nGEjMWyr9nc8jHsmQfuh2llVTcKkIDKGsBc0XAmo3" ..
	"0yqErMlba3plELLSHD/FtAux56B5+aqR/e2v6U1RqX7KYeiq3BCYb5+vITBXGvgpTVWxO09+MrIyNDBZGlzEmLuJhWnbdD8+zwQJ" ..
	"/7LYaYHs0UIxX9I7xM8pRBlm9omOGxC+nrWp8TwYubbxoSfPTswJ0Xt7uAgg13WVYzETyuSHL3sp7NP6bGLwqrCwi9mNwXcZhExb" ..
	"U5gcDzZIqTD1T0NSY9qJsGiNsuKM1zUUSSiLVGwc99EwO9EQa1b78Tdcj4D2lXsL75zJItCFU1+u9UZkL1CMTOV5HmUoc0w+BdWq" ..
	"GO+ddjzKRJHlckpWP2Tk3jORhGoyDxukaRDBLG7h6fPlkwXnoQXE5CLkGvD7OlN1XFAiskAMWaTHSIhJVatKE1PeQ/mH2dx/4oKz" ..
	"slHr3e1PNvMW9sgyJfn1qzlXtRKw14ibnyEa0tfIZeSZCQaWHcQ1il5RFZciXkl6VPb45798XaiFhriUUepKN/BdzBiJADmfMRLq" ..
	"iIE0kcrVKAX+0EQbUoeZbMMSQ1Iqqwnk7atZOb/KoS5v7WboEc9oR0wIOF4fKSMDHt51AqWbBLWI2PqM5OhQ0aXfbxc4Er1oomYG" ..
	"eL+Ikr2sK9Gib/LfGeEpvYbe3GRog8nt9rQRs9rAK7uT34r/xixXvVUdDZb7qsPAMyeKL4hk3mXCw6qGLbih6K3zUA7HyvceMQla" ..
	"dW3cWSX/1upPp/NZlxw85rgL5sE8S/8e2riZJTzbTo7C7Hqw3Slxw7MH86IWRhfMxl7GSyznrw5+7ayzTCY7P40XzJIfFhPvBuY2" ..
	"kRzUGqx97esBi4Vn8sVLQ12KMbb16ysX5U6UO8rsEBOwNlhHVvE0naqAqdlELnAfH6IF99W0mGzIirEEMwwKLvUxOrd87zAyfKBE" ..
	"IdTz7+hDLPQOCvCxbC1iUAXTOEFSKlsQPlHdt1e1Y6SRhdA3eERUu33UBGlC7OQI2ZZ6oq+1hbEUheck4DPJ5K7udAAHmf5ajLMP" ..
	"ST068SCvrguHJ6BHMHpxuUKXAiyY/V+zjR40r1bU3xf+HPFMNE2MyIlLv5PsFr+jZ5C0CTyXPjvp1F67JmU4X+eS+u3uCOXUjG1i" ..
	"W0FrynGfWpq9gZ7M30OfN5S/ssdPnxUqbqtzRZJxR4t5AltHi4v13/TtJvFrwMQsvd6JMch3N+292OiswiRsnHIReVd7BIwQJaRE" ..
	"1wBtmv/W7ALWZpNpZFVNm89aIS7C2zyMyCVl4XM3YR7x1s7XsVvYVYNkdXMfQTNXkUdvc0cJJG+PDdQkVXYmsu9JFr1bNkSPOPNp" ..
	"P/6OmAodLYAryXzS1ks5e4mB2GeJ54pcbyRqZNxJWawYw60hz/u52+/bduiGtfSMZFrFM8hArkcbxXOKNt/QaN5rDoFhu9CnM7Rx" ..
	"4pDUayaT8UyqfHEPcZCxR3M/T5L4MklmOEkei/0lJ7BeB/oaN/mg00S8Lj8oNND7XblNrc2IPVZvL2kKMyRRoYt7pxraxfl0AuWd" ..
	"B6gA3SpeRlUzFViLOyXuBK+bYCq4SE5pwRpPfD6PoNWymFwz7Vwva8jH2qjwcilOmXk4ijjVVfjIpuJF0SexKh3nbbTxQWhF6n3y" ..
	"869TGxhhEFkupXHc5AfC4VaJxLUhwEOeuZJ20Gzs6P90ht6fNVfscH4LllkQDYolS2UmpTl8JVP7kyoLyyVv4pG3MgBwiHYZ1nl0" ..
	"Wb2z7cHyvfDq3qx8KguMLWFI6Hv64lF+tvoLAO6HkMF/MWNJf8eqnvlmpgez1JgnU66zVDE3YQriEyIoKyMxBo4JWFwmsNuBsYR8" ..
	"hVj8sxRPwd7RbxPAdWFHlM7A0WDMnzoc313DxdTNftzktKtij6UcHFmhS3NGEa0iY5fowR9M0DXFxULzjgk0QEYMDIxqGfLdbeu9" ..
	"+B9rxx27wlLiQTdJBGiAFYN4PQYxtGlgzfA1+3pTfJIlRteM7Dr2lSBYyHjyzBOGdsUxhjXKcZ5M70hzne6CYeKhocyV93/27Zgv" ..
	"fWOoteWZlUu0i4w7Gukbr79GPkJhXLWVSZNBLK2F+0SdWJNfOUJK9Xl5YM7UGaLG19h+P7leT6tGQJdF54hLdJhbZgatn6F9NvWs" ..
	"uj8IH3WCyX1YYEVkFlUVbkhsnfnmPzWnDnpZ65JvqcXf9+Oz3hlTa6q3+dE/IlFic0FYIK3Z+GS7lKSWZDZh+gtihCYO35viO5Hm" ..
	"4bwBu6e219XN3n2XEw5DkRRO/HQE3aq/ts4f8aTzsXEz6brx7h+8KVIZtg93SL1PY2VWs7IuqfIVG0KVYG4/bpb1q2jUu2huYkzi" ..
	"JrR2cCazp/D5q4Z9hZSHCSPxc0BGTJmG2GUWEcJnc3FCaygvpMxux299sXi9nc5YzWEjFzW6AB6umeJ5HoqiI39eQZNf4r2LcUku" ..
	"Kvdil7S3XsZOMIgTfs0Orxx2aBNnuMp9xc8VHtt0JXRgXlw+/FZu6PrdcX2JqINslZK60dafI+XcINVbpMtabrkrzjmSRBSGldOu" ..
	"fS7w0XKfPdwX8jZELr8hEG0VLM1ApvYHH+C/K+2bhUWUB0MA6+1dqQ1sGCdS+kxMJZQ1F3jdJgjNpUPdfJP6Wah90vMqhWxNV4K3" ..
	"DIyDs77SPeV6QalikMHsgxOUJRhq7jPNNrhYHYr4XnNsIgFf4xRlnszgdDVC21fyn7Cy9a/yOQTiUdBsCEfDyWWNgccjvX9GUGly" ..
	"mq9AjmlI8gdsXOVjK5qzjoIJlikj8U6wvh9J6l2vBBFKfSRwW/xSUCnosnxDm7odBIw9isEq56DNKMeKn8LeAP9I6HESf5kaBA+8" ..
	"3PJR/8OPJmdNzBB/7Dj0BA/z+ATf5Wmcz9PCZP/Eb1zlDzbuLNOZ9bWaVNIQM/L1sZ/MC+0+Lm79+Q52/ff3wRLY60WUQMbtBKj9" ..
	"PJ7duJmeriPseXYx07NjqphxyJEGeSnwiSqr+mpKAbt8jZqkXO+6n2A6hlpTA4qGA8IiVFG+GH62kDbLLtyyKtP51nJpLSCTqIYM" ..
	"pSffjlFFs760o0sqoPyBD6mW5RGRwK7lUU3F5AMXgdJmG2uN5YKl28t5V9ea5IwSwy2jx790iVw6io9dtP5crLUlPbdPbauo5wlk" ..
	"JV4tmfe3lqZ+5AbKfWeydqqnaqWEzyy8j45c7RyJvC2O4fvkETqaThRhzc1QEUQIThcQgftZWjkQFfflmw0qaHwuYlIqAxSl5ax8" ..
	"JyrhuK7F0gZSwhBvUNZkiKKGDCSDL7e1USML2GaF6I8WhB2VLz0Rk9Utj1EdkftGJt9RlMb0ZR9KKa+8uC4655sw3UODcI4zINtn" ..
	"505nfJ2BEyET9JkO3HdqIh170jaWaS0VfoOAcJStDJYjldBiOlsF6Eil8SMJGRmoUISq9iOVg/IvlvoM6y6DXmQyfCrT+awQTYbr" ..
	"zkZQeBDJJVcgDWu+R4vyyTeVtOxtMr3QzbQCbyn+McE8cuv3uHRkd2jRh+D52WFeaG5bRS1xDUh/9LfSbXCXBdSdVr1fyQdy5zKF" ..
	"PpKL/DnVH4oZOYBB3FO37NW990FesyNHU91G8ok3U0IbleDpCa/UOh4KckTzZmJexE25BBPLL/0gsChUgxHTLfAtrkFrhfHqtmQ9" ..
	"+a/HoKgTj8g7hseINJ6jxiTcvlO0f1HOkFy6LVroH5HOE/7mPXmx0KptMSgDVmg/1qbCy1DwluxWqylqII4FN6B+MNBshv3WtJIT" ..
	"K6gk9+Kfeca5EBSgTwm4WWqIPzBrnlNin1GwPbqDdTKUwy0MsKCRhXAbtmSqnOxK2wnDUbWO232Lt7PeBAYkPyQ9EB9ZtkfK3GuT" ..
	"tI73FzEJXuA+tJBdqhz+/mVXu00ZQ62CmATmh5mYP4RM+Y8tfw/kBZXvSk/tY4wQ/RnNFBogPI5ESSbv/tqxtlCNUY5ewYOlxZKD" ..
	"44rwBxTiFnYXsNNxlv9gxhc3S9EDCSAarYNujWif7FcHSyzhgSfjEe8F2pgxGEUdbsDY3l76ArLEBNOCz0rrTq0+AWiQ41bnRP5L" ..
	"QXLtpsWOMqTdOGKSV/+DPfRhBWIVYw+Ca5BVWtptlo7VNO1of59Ow9Xx/VC0HnK0Etrdb9qjl/O+seUQZg1fTtPY6tyIzxbLmo6s" ..
	"qEy33JH4Apzvo3HH7EYcNGWkPE37As+9gXFbcLfb8PgU1DbiqiMyTnoC/9Tk4egNd4sg7YhtJ5//XaUBRGRCSXQg1Hc41cO7R9OX" ..
	"SAn6L1WcrcespFQD7F8LmZ8Hyu5sVQAU2Amc0XNFUpQ/ESEGxO65XfNPuEDq5PXwI/9mwulGRTZU9Tjsb/83iV2GGzxXMIfPnpYr" ..
	"mBQYh8zHRO/Z02Y+QXjM5SFvhMTApdbWhuZQ0lvMT2d2hwOw8fHYat9Od5SAJH8/C3CB7Gz8/3niJXZD/AXFEp6U8LPW3R0Ok67b" ..
	"+nnYIC/LXsppQ6540LAxJw0kEiHxe71SqIMb8zCKie7xPR3kaW+6v6MVAfOOm0BDX5fAOBZMlHfXY5aqBD8fzapgC9iodnXmhXPW" ..
	"bgD8cz/AEfTbyGOAl+fP5ym1iDVqCL5T0gyqytUOulN2PZL1NvZa+S9z0TI09Im30HWfGBgBYes1abkqW6lTeUMrS8HK3b+UIrHn" ..
	""
local PAYLOAD_P6 =
	"yA6MrDIY1CfAKEFS4x6JjHSB+ZO0nPU1bghNLmczqo7kLTudLKOcQ0TwfueEsAZcS3RxFfIwDIEZO+TkjeHOoCjOPJC7xvtqgp83" ..
	"4M8kXG5JdMk1YWIMe5jQF+kKJWhQ/afT1m8dW4JAfqpnn28jZVTJQns8dfLuRwGuSrYrIqDAI8WlPlHa5ehtGc/iivMVKqovTyju" ..
	"tz5NkYnUl8r64Hhlam5s1+RsvTuEsCVrOWIIrx6fgz4HvkeUdi83BukwnD2CGPWvQAtpGXtKsJSA9brKxEsQZsEXt4LrOeCybrhv" ..
	"iiu6nIB1fjvPprPgtPkvchyDZ+M2wTspU1USB7861PgdN/pynYZ1QMZI8iKpGwgRyEZ02vO/wJ7nVYcnIBple9DThcClFmjiCi6B" ..
	"OGzijxpMraclDm6sE4o/Qpy2ffI8MfStKk6pJT2y1bbsURmL3WRCrA1mPYj+eZ9XSDAYkcT85eQE4rjN9whk/yLf5djUZYa4u/hU" ..
	"JCPZ+doxL5Lj6aIxveNIEeqb+8HtT2lQqBW+Y7AXMjta7ZyYW34yFUBhI9Vu7OxlClptJQLjdZ9bG+ji0gZ8AScJNLjnQ2mLRjwr" ..
	"wbhJtcP7EjyXcU5VWEXO6M6kVHOfHtZsYGalOw1ClU1t0nBtqtcG4DHO3sjboJkMuf5ByI74i6z2QA99JI6mrQFYYkhVf3dNkQmj" ..
	"+Pf9sCHWOuJkX4nSLYFzK4CZhxlR8T5UcwpA6ra3s4KEt9OL7i/1rD61HNF0stYWxoLFK+rUMdGC8OJuSCxYHQZcvMPM/e6IOAtz" ..
	"o/BV/vX7h59qqKETWK2ddZXHGHgu11Tsgiz8eflvYczaeqGlEfWLCoLAr/S4aTvhs1Dl16iNbVz16VKBK4b5dctSaJTzWxxeIsSR" ..
	"uR1bpOKnRYp47uOR0Q6JMWcBTW/9vAQ1KY7aI0mKyEuwMR7r8wqKCixxlp5pqJ62n425doPlDmaOn/X7VjCyO9fpkKGNgSiIuA0F" ..
	"EBH+RRDLkplw8bW5K3QzsJ1Xi1qI3V4uZTd4TqLmxzeTyVqBYlylMGhDbtqpyJfFU1YZ1fzDhc04CxsmTsVkLZ1yPyd/uBkEeOe6" ..
	"OOmzfsRVN1+CzqtBDaU2VGYp+sZ9j8GrNNQSptJyRMIMBsftqs3HqY7tsHv5oZcs1gbFHcyQjeRZPY8TXl3H02vT6ShEoztL4qVI" ..
	"OXSy9WXlqdgmOTjIeyuN2JJMNZguRQvhbwG5wgGY+CZre9ZyFS/RHeY1uGNGewNA0nkjBfi8B8eOmjj7mZ4hxKRhN7Bz3pYXBqAm" ..
	"Ep1Ffop1ydEvc5k9FVqOFLDSdt2a96c3j1GkKkhOUfFAWGOTRETEaQxoi0nYpCiMTc2oBmRAv0tQNvyaz51jLqDEawqdvNcOCGZr" ..
	"et9OyWGeeyjhhrgMYIFqmcFFNO/ZuKpEoX3EHQ1ZS/iaPuCJGP5mq/Y7nHdTCeYZnzZZXRiuoUEYDB+aBmmG8AhHT3BNgCn4Nhit" ..
	"86CVEQaeQaDZuuohVh5SCyx1PG4YgfmX2kzFcNPdTpl0rlnxfTzmITA6wvab8iKG8FN4i9kl5bnfJXhQRYQLn719i59GayxIiT34" ..
	"EafDIVhoQUEOGjXT+s1G8sj3x5vf3K5CG/XG0kZMBiUOHZt7w7hfn/tLXR0nI45RX7TrXhBkp5KTIpecK4eI/qg2r5EKyK6a8WFP" ..
	"ryk/iTwonwU3qfQvp/ElSDbXXNswd6L7CrByogChV8afsWZzGjGyeiA1YJxosq6UYLMSRSR/mJdEj5bsrXiGTMq5BLp7SndXeHcK" ..
	"5tCYUMfqlWXoYvPTX6V6yh81C4ZO3SoxTdSJiAP3GnTBwPSDO+QX0MYGw/5NFrbax7FJhIwkrRhjw9gkU6Le1XonE08bMFTjgAm5" ..
	"aRp2ENqw4tFRn1Cqn4DK6dc76VoWQ/AsAkER1aZ2tCeHjdZGaAxjSAwWKnokRcKryhZcxspGYcNFM97ct61XRv7BkQNDv94oBWW/" ..
	"2dAyY7RRIoIAethEZdYws4AAEswTiLiNQXM55zRpE3kPE7bhtIxzHd2UdWF1v/qRb+1gjsNR4yhvUzwRSESlv0JpAeZJ30IJWeai" ..
	"L2bYddDjYGEaFSjzrVHKEILg2xFyT2i+cLcndS0VM2v3TvIoOo3DC0AnF2rWWTAdVnl0NZ3M74c3yl2JCS7aDHiwpdxXsuoRVPqB" ..
	"nLm/kvSIpNHNdMvbrnLfrpT12nDnKE1PFgl2PTLbVCrV1QHMjX9WYSeB14mcIBZFB3+6cCcGfknn2avRFJDeubPH4J2pYM5pHrCv" ..
	"09AQPGn7twa7IK2coTUlW9nq1BNPMG93zl5k+c1AhGJWMSIJkrgzSTCeWFJ7qpKPHY693kpmXAE3QwJWfiSBf12JSdh2iY7dIkZN" ..
	"QbYnkmFZIC38Ejo79Y7gr69NHj3Q7pp+d0GUhvrkcfJKaO/myiIfpZ+xh8tSfO8sduAWzBRLtdwEjDqAW6JS60Ir1sJKBMQ4J1Ji" ..
	"gO7YTsOHLZZ8AZTxrHRX+u4Inn95IK9wZI80oXJgi3E4n2E5AJxBOslsNljy2aHRRVG8ZFC69E5TX9e2YgE+GNwBSkpo7zFG0Vzt" ..
	"B2buvSUGxk5DyTkDB1t7/mLWGlF7NELBOTtQParMDicc2fMg0saI7WjxYpYR2/XxJHL4vzpSWyJ79u8zkx9rrGG8vynDO0atTO9p" ..
	"yQIT7Q7ffST5YuJrP0Q8AoHkoFZtEanCCLytEpwtK+uGZaD6lKrX1IY1wSVE3jJQchWcVfIXFg5ArsKq1d5EITMs6cLCOtUxN+C+" ..
	"9T5L2A4Jv+6F9UmYt2iU3LcmzBK3seP7lYkydEJCegtuqZnNU514LvD+z9h6sw4qnFTCg2CeZncQOsPLVR8FHTUAXU6rVM+J7ypr" ..
	"RXTbFVxV8ePvQR2UDNGMzuMy53vDbz0MeMHCwc6mwj6ytOgV5OJmv76SeE++jrGyrqD6PwNZaGE34UGJeci2sHfdUCVl/ifCeiE3" ..
	"94TSEgo+yqMoycEcZhgCuAgE8VU+SvoEsqMTCzqiw6ShGkx0wa0uaJYLDdbmQOFEMR/IcpHIQQE5G6mXvrM4BdbPUXTjstQvD6Cl" ..
	"GWZdO+rz2Zbfan6TaBigHrI6mbS35f8+UHQHjtqrGW80QIsyrPWfhGU6+ySfuWJtYNpmNWvHmBfkBmDze5/izn8CWOIwZf8n/g+O" ..
	"FK6lWgD15UCRTVBjzIC3ZhGa5Yl+rmBUNjKdTWjAFjlWUfMkAy8+l531TufF2buusa0Mdjd3TLyjtCsb0eYH3XyFL9Mg8Mhk1D0x" ..
	"czAk7esCPsJdx5YeqZc4EaNBH1kDVZEXMHaQ1r4y5i2iC0JTDBGh1AWyyjyZbgRN5a1F9URno+sL2US+dC9j4Kqv4sDCBN3T4PAB" ..
	"QLXVcN17L7B3eoRrN1fUlKGp9xcYZ9qt2rUUkpYs8B1/zoqVpYaNkJ+xzw5WC0vWn+2urOn+TzzI6U+IqGYlvUns5dfHoauQnBkC" ..
	"s+0nR9pTuqlQ88DGiGqoi61Qv3VCW4o9Gg33pSR+VKUg3PQcABiC4hqeJbJW9WCNgi2tHfoW9LogzLUvmuSD2cenTpi2QWSoFi00" ..
	"qMK4cud+Rn77rUMooQVMq5Vv7KsWSJhOTiTTCQ9JZzj4I5RqLqaWqYlVRC54EX/NANTlKASOV1V0kkfJSF5uazorNqLTIosaQeAy" ..
	"NL6/9ECwTKnGrB5s1EdO5/XVOWczQCUcI6vkBpnqbTK4PFh4zoxyjy2OS1cOWIhhdfsr35TVn0Z9qVj7Fb4IsbnDu/KzCTSIDK6p" ..
	"YCqebNmfd0I7d6x7JNgB9H3RdIutem7XNpAueJIWbXdbda2nIPx67VzHYzMLW9f5ctivKyvvNLUGAl/jdd9fAmxeXFSkoTfq4ntp" ..
	"cwrWsXFsZOwLM5MtdEFj7WGfyGmg3/AfeimiQfGKXp/C4c06JrE9ud6sBbfBFIgW8F34fGQlOtDdtKGHLU8wegsV3+g78EM1JyVz" ..
	"q308L7qanZzrUgMTnkqgd9BwQ/3cJwdOJQO/UtxF6DP2GXcMXuUKKmHedZBTK3VZhtUf2BIaRUOslE8P4999SyAyNrvGr2VTICkv" ..
	"m41iiWOdZDfNnBQlQOE6fDjvDS2vu4o6Q/YCuO0rFYXMG/oyJSo9ewWZazdEjfPyPyALybfNbkBQw93MnG/F7fhKTLNloER97go3" ..
	"mwKMTYT42SDogqL9d+GL0EWN70UcFxRjQRlhZ1yEglaerXTbXoM65zbpzv3RJ5gCN14xvYqDtIGz5miKAcVRc3PFV12L+/R/Gp4o" ..
	"DfETgfeCbmYhmu1NTuu7FC8qHEEPLKaQ8ELlvxgQ89MZtwvuOCB+vrUt1LaXQrNTo33PyS5LC5ORtDBlJDsCY+txsZRAPxFIRLj4" ..
	"sofCy3JBAyaN9r2CLUzQ08KyFKV0LYElJ03lEuRnh04HeLlP27wKOFuQ7qJ9uqUmYatVxxxI+ST9uJKLH5TwlQD/kSnWKwZVzRI7" ..
	"mlld6kCb5ghKK2Pi/24rBaWg9C3nCYrc8akKYxxHNq+7G3tHt6sZUFfxT3sU50vzQRH9so9X2HXpoV5fyEeoeTvFuJmPbA3EqAL0" ..
	"d+XB64GuvlpMxmoI4JMUcFdgAjxEHSdScpBk7x5Hm/N8jqr7ng5+2DC6BuzxRDu1ji7Yqi1E6/4hReDiSlIMLHb1Wlipj+vOOXfY" ..
	"Kp4cLZ6Dw5lBJPiW7Oj845+aeOEjunj1rSN597K6VdpoxyrItFjFz3UudZsmV7eRiAadEVUUv1H8VxNX+HnPWw1EmShjMPTn6NlL" ..
	"+not9wxJdGao8NcZQjbCf0cs0MpeViwU9b64d6tDpnaFwg8I48ewZt83bcnflTTp7/35Cx085FLRyaRBy6IrYqqr+ZdEQFDplXKT" ..
	"0ioVO5JrrH8aeAgahe9JFdVmqJQZtGrrQYb8fqe7VdTTDygEulIFT7ubbjGN/uNQVqHz10tKuk6sL8fMS+lBtG/4KgIi9j/h+0+X" ..
	"No1pPuhaDXfghxV/nYOGBIX9vTnqswACWfNS750SPlgVnK5L1dXzDkxQWxLHi812aowI4BoIxPQB3L8j66pW2CL8xOLYksEUSWnJ" ..
	"x+q1jpORkZZ1lta2EJ0UF8stJJhtIw8msH8kheWF05c02wVvCFlY4/5S77cqzR02fgzO1jprx5YsE3IbEjCIasx9wyysRnlSddmE" ..
	"Ed/fC6aP8GH4R7P5s0Ked0mhaq3g7x4bZt1GEWSrY4A4f7dqMJJJhrqBBoDCgah/UhxN3SDLYW/l9Cdszm18GSn6lX+pAXZEBcok" ..
	"w/3mSNpucfUjL/MIszXSrmXtc7dpJSVezCZoI8FDraDE/bunb6DL96s5RJuElK6jZaGddQeZTS1BDSGgGkmE5tv1iuDK1dZGcle4" ..
	"y0Hzc3DmABf0SKrRhTLEVwUwWsGSPyPtYXkiTbffUx8a/GrlyCmgr5GVKFKuv6UNmSfjw9Bgj3o35gTdVb+mnxfEoSQ55b9CP+V/" ..
	"FlE/LS1HarwyQLAI+s0b8MlioqnsAhVoHoXU4WJyJSjJApSn7ToLO9tKnTqtvjqL/v2+tq+gsGX7bJG0GQ5K/7MCUC86jat0aG6n" ..
	"b8wPKtyZffv7pRr95js+pmqOq/QagsjrgZG3sHIg59i0kyR3482ZPtyNQIDGS2BMWP7Q0ShGJlrG+8LEy1ft3S3IMJDpVxDsEd+4" ..
	"vPQpGLA9/5Y6CrX2QGJ1SpvzOqj2j6pwmstNE7Y/HuI3TPu0xBfNkV9q+hEVre3Tn1KZ5cQkIQyU/U9ghRH24wn/F1WmnIIjvpBP" ..
	"ukAklPHdQ0oJjoGg8QKpwhp+l1paXVq9pOFUiObq3/fgoFFFKjEGTHmQXdAlBqkGLe6+rj0Wxz74ACmr53Y3jIs541egmOYHVqYp" ..
	"1bdUTSdCPOZHRynJDotQPYOpB3nvT9zdno3V0wjVpyJ3JGZAGxzdlHF71l3BJcVoVZvCpTAKdEijCv6hUsSYFJG0zUEpiHZQKXkk" ..
	""
local PAYLOAD_P7 =
	"q6kZpl4DxZoFrjoViVe8PLOntTc19WWkRdVy5J7ZUJI4AvgVvzZSWm5Zxwd+EECjQ6jXL19yB/Yuu5xGu2BUGHF5stTgCp0h44ds" ..
	"Osuk02qliPY4HiFPQfQOGercMPPOZQNUkFueKdYHd0Uj6insyw7usjoWoWHCjI47RwYyjTnprUFZCQSPS5xoBZJlqa/mqmRfjV33" ..
	"aYR5RxKRufbPX3RoeFhPkBBzqDeyNPzMvAJXJVhrzd6jm6ESyCN0cNSpGGELrRCMSBEUJAQmw0HhYDRKnJ9Ruqv00eEuARARY5dc" ..
	"AkbSgIaEWwHgNEcvp1ESFl5w+RCS2Tku8f6HK2LKW3+zxXci9YMzSFl7/6TfTWduIhYDYjCfV0DTSzBsg+ER7EHWHtcqvYHFZ5rM" ..
	"FrTBgdpHPhSIX3BQVClkOtJge4bU59n3irGDE/oeVOe9RCAAvdhloXY3SGUQgI10VErhWXuuTbDOtACSRikwolnNXQKUvaw5Dz55" ..
	"WJMFZ2Xm/7j7YBfPMU7Ixfe66AA1BphIHZWCmQLy8VnZTbTtoX/cVyx1tNIg0cHBuNsWJY10KZKkfvj9FVgI5WglJ8PpSrjJw4aJ" ..
	"1/rQ8Bcz8C0U+1Sp2Dk+cIS9NqYprTAmiICCkbm85VYxNRZ2MMaTozL+J5F/NXx7HwWpcwJh6cUr5rVr+UDdBPWX/g5WAAz4q3vb" ..
	"XZkl7xagJBpUNBfg9YjN6OC/w1yJQJ/9DuIPQynOei3HZFWV5qauCH4jiQAEsUD2R+wkBIQfeDKHpWA9/bF3eeGqOHmSfogfWXvT" ..
	"K/kk1AX0E82nsNe+zfNHgUFzca/+9SkoywyQ6+gQ7HGmzusAth7e03PJdG/5TNleYbuMiATuKB36Lvs2M/6CZjfTLFOjaPVYJ1ZA" ..
	"EJjj5Vz6JeII0FHovmLWcUCUKCKWH4kJwG3d0dCmt0BvQ8OOFsukS5yKo8ahznSDm0qch9m3k0VMMniAawn8j8g9B8MflifI2bF4" ..
	"kOXYVPhBYUc/NebHeBwuZ+M/a+cJH0YF0uTiDYiEKB8ULTjowt+ulVoqxr1sYPx5k90+jU+XW+bfjzdw2eT0v87Ac/6k45BnVLyM" ..
	"LCgoOwZhLbSOgtpesgjq/XPdI0XO9hVnAIdkJQAT+61epQ7HirWVp0L9HtHSvNIb/j5iGxq2Ke4X2w2f4XMq6gYGKqSTsWGx4AvN" ..
	"ODJmlqYcrdclB+elSVt3EbUd159mtFE134ORxkJc7i1ncxwsu8toxPSRoWOauSdegvcSI9kNNPP9duaX7LTwetZajGvilRXM2RSR" ..
	"72w2KHGWphkN+GLUzvjLOFq7BpPv4esV9Ub9JTRKQIlKDyq6vV9fggHgwcdjb3UiU693gM5TmKOaXynf870UZx/cE88xbD7RJzE6" ..
	"3+y/KXS/2e1Aa8AQFBdPf6mEqEwDlO1d46aj3R9rdEH8xNWtDfIVRIRHylMW+EoikXWQ1sPDRXBEuMeWiKAmvueUCmwhg+PvGrBD" ..
	"2iPxOQHMlvijnED0mwHusYU3FyFH5SWYBkx1ScgfOEDSs5ZKt7r9gH/AFvdjpDe+dfyk4AQebtc++XkVmj90mxqq60Y4zrvNf2Pw" ..
	"SAGuhTyEdIkAzHP0Xu6pEqirJVHBU/InEQlQ5Dy1ZpcZZ2zbTeEcmqy/G7vDIIko5Co23LOzkgFTG0yIY3x+wY9P6GmBHyrbMiQD" ..
	"a5pA8SHdO0Vh+msiIz+s16kvOZAQrseSKHx+qTlTK4l6duOhKnckBI/Uo0U2KeRSseC0cn9bmHs4kgb58472EURkxI1aiB2mTgPg" ..
	"tEvxhTGJWMHwmzT1RvPBlRReAXjX4+sq8Jy3h7rny63oCwMxLadbezOWgQzTsm3bGhsv9aLBFViWTat6jZbtjTi1nwW4HaldFCEj" ..
	"BgSFPt9ON873q1Mr8Ax2DErfHlfSxqHlq5FltCtUD6CELCSVhavrtqPb1KwNQVRKNNbXBLpmhz0LMw1Y/Mvkg6VCrbIVyvS4ncVS" ..
	"BQFHdebAaAIhb7vbS+um36CBnhgZyeDGzgqDiPDszx2FPWpLA58VHQqB+tnQL+JnBYm7JU6APwB5TBeGOz1yWn6Rx/DqorxHo6Ak" ..
	"R/DnErPobZ4Tf9IQj8QJBHaqQF3P9K3JpB7SALPKByWjHg++9RhenSvdfk/xAw5a/QmqhCKfpYMRTO4RW6Zg+JMonrsGMlmhNZMs" ..
	"IJzMIoKxa37weAA28gv3pOZ3q20ZVQdEKQsqbCGwJdq0drYSWlU7kojnlszovdMPuuO+xbkaG9Z/5dxQnIH6t/IaCzYUyf8baqJz" ..
	"atIjl//u+n7UMLR+w21JYLA682JxNnjGvO0GNubtn3pxZt/gbzzsaJltkWQmmor8slVe5baezuz0M+nb9XTOXj6CWCHL3V0r49u4" ..
	"ecqn2yZVUeNkrtyfeo+gWlSzk5E5pAQxlVFKqnhsLkRzW/c8BEzAutAkPQPOIRKIv+/wknTsdOBRTK4PIVfnkWcEjfp7nX8XIOVM" ..
	"CFkOQZ0Qo5PbgTek6ScZCWppdJkvTat53Tmx2I/y3Ffh3hRwDoG+YiWjFwSBknmiB1AA99AJaBfCGERXOlKPGSx3LWTNIohFB3aN" ..
	"bzWG8kgmcER253Mras2ebwfbuexAKIGcFpNL61RezrRUZDfvPvafqZ9AsSAZZQRAGAYYC5mBHvod+C4hBHJvFolpKB9ecMidk5pE" ..
	"6Q+yoCzd1/EJ76tVL6xNGWaxXfrZEplWWxbdwfhensAAq9yxAyo2FcMLzOpZjtQGVMQW2BKmu9XXNTY97HUBzjDaUB3Kqe2MUar1" ..
	"7j1FPFkd3IZ/b67Gtk1pU8PAyE2/uL/zir6G//toofVYLnij76ppgFgGP+/PbKl0sOcSIWbKWDs6J9G95PlpM3cFKLq596bWZMDu" ..
	"iozfSAlwRC9qE4AmMSfLTBssDxSnGx4NyZm7cZWnCsDliXyEYtk7Q9BFPf6DWXzhjZT40k8QoC9x3vhQQ2YMr6YyZ850RB827epX" ..
	"TLNa+OTD8KbJXqxUEh/Bc5tusxatA9GtRC7xu0RtgBAWk6HCvl/phhLnPajh9gTVkVH1oenU0/xt2645te+P3ZXkfDoOqj4OanCp" ..
	"/boajk3EtgOFf9U4gq5iw5rjAd1un/dsueqbF2UhVpAemjZRt23fjKmiMWOD9Wn/QbvNrKhuZDqBZ15cjpAqnsNOMzKrio5JWlGK" ..
	"bM6JpcT9fmH4L8eNdbLsj4HyaSpSQSkHA0r5eOMQqK3EGO9QhUp/efIj1NdlN/HOujA9cIlLJw/ICji9sGxCjDYTwhSfPSo/QnIW" ..
	"NzMB4DoszphL8ZJasOzf17LoYlHhYEPuzW4YKYbB+hSfP7Ydz3P11eq6cQYpDDQz7j+dOK0TX64AyrqS+yLoQtA5zC1FBV9VXte2" ..
	"B+fnvs4dc4iqcmzn08lhvtYpAQBENY0hVv0XVfHfwkXSopSNb4yLPJ90kw2OsBL0WsSI4xjR35B1OxrG6LrST7rTw9y1XhT+hPcj" ..
	"/G2qtbhtMb6VJTXHU1BTE8d8PP72WgTkP6V+W3409i2+S/eZNIOryZwPd4pYK/hIDg/WlPSJR1l5T/u0f/xHXZLRITTgcfFIyUv7" ..
	"mfkF9ptLGAaA9VMIy6Dh4MQXMTpWHrXGESds0UER6ftqWyCuTLtJcrO2aARR3RWcUBXDDFv6o27g7JhHmsoT9wc9iF13z9bSRIvi" ..
	"nOOkfouY+M9dzaclzkcrfnnqZ/Grqu/+tsMPccC2V/q829MladKRNib779ks4HcHbdvk2C1lrxPxN0QyydpwE23yx5xu3xhIHtbw" ..
	"asNEhtWyPsa+6vDfu/slwsHzqZtZzPi/pNUwN5ftJSsMxQbtJvAYYuHb9PDUuoJPGgXSAN0EStH64oN2I1+odbJmnVDgdz4Exdpi" ..
	"FFbUTl/uOkpa7j3sygOgIYkSToUbePsYOgbPMIuHz/pvSczk1OS0xKyVqGl5odgywLbk5dNe8tK7w2VZ+PVkENoCdu20g14cPvYa" ..
	"nwDo913wPhQUV1Ee2m5qQtEp/tQv4X8NIwBP5wArSYyBYfWViSuUN/UJ7cmBKAP21Hz/GA/sP3MzqmLdOg/ncMDlPUerEAj7kXKQ" ..
	"m0TYn9s83Ntrw7m6CpH4bjcwBw6yFAsZW3sH8Rwje2lpH7KKEcGtHu4JPFhAWcEvxxsbHQjuohGlwKaOQTKsX//tqmEVZyv7TVCx" ..
	"C0c0fwIer9Z30c/SENMjI7TaHADCysSrXoDkJ3dBLc+rZc5WdEY2l7ntCuYu65zR4iktHyYsUeJQHGuaTWg3tRzN0nxXg74DKk6Y" ..
	"QouJs8mcpChk/JTM2aoKB09IWv2mIa/Ptytxvf0AXtQwxDfcl7pbhW+hHABh/AJTDaSlRpnHyfTu9fqxU4zjTdIQtPNaut8X8HDi" ..
	"h8RNM+9XJ5fAJee5rykaswqpoNlyciXcYiBkPVRs7dOaD6pL7Lqy1qBKcOOTlDr61Etfqf+LMd0wsV3Idbh0iWhNdSs0FxQNny5Z" ..
	"3dgDGu3kMMmF1pC2236Mcx+nFOAMhbQsQTEMT7XhpJIRHVSQ26daNHgmcinrkInfGu3Se4xkjIrdE575J5uepdA4MDFU5vXl/XyL" ..
	"wRAKfrJt3L1k/Df0ECuozpr+Z+8lOzj0ndjlLhnlXuaMRaT6tUC7RTkNK4mFXboGyUUMQD/Y6QUfLMp240wMO9p2v+ntNjV05xcC" ..
	"EZXueQXwuw+U2N4K0NYmgs8J1/r/XKhE3gOy7ClhP6pzQ0tVU0ToWQQXDKSNlh2beHUYb/FJ6riQRH4mA9clncSOGkpPiJ45IYN1" ..
	"I/OoK0DFT+PhmlgX2TKgHMmj/O2IEL1ShbmWXNKMgR1NhIPo1X+bmyn5q+hJcfKfeDnmZl7Q25wjEC1OC568TgKakTtMam7kDW+9" ..
	"gu52rSItauyHgjkP4Qwol0AU3Ik4JzqEPXNpKzQcpUbNooLDpWvaz2KoYCbq9+z18U26Il7nJ9SmkKR61rxn3uruh26F2iRokmp6" ..
	"2aH+kL12bbwVdCLJuqB9T1hmYmaUnmnDnn6dKri/ocVU7kFU+76hiKRv3YiG4XlyyX8mxcXWIQOrpq0JX6exnFrqLkLSwLvwSWwj" ..
	"1byZTUy8jSPwEL/e/S9oPevbM2h7RVLbwlnqpqac+DGRwxlA/eE48KXf37iCxbItqRmCcj3vQIK0+km5lErRKYEMpxJdI28LPp3D" ..
	"2Dlg/ZFr8C6hd5JO44GOk8CgBi2nzTYosSvYsgn4iPWW9uVbsk0BGWEv8qiQ0I/qHg/V4W7SaM/cw5pgdEKC5Rgf097w0Z7tIHFT" ..
	"ok3Cu7zeRLbCKyHZYzXJNsOR7W+6/2uh0T8RbeljojWI1sR5RjBiuvfwefFDfexvmUuT/+d5Kn23OKpqHiRjCFqnlGUSTnuCTQW1" ..
	"dYuAEAAnUV2/evULPuLtfYH/ZMMGShn9CDSFhjsCAhK1JdrT7qaPrzyrLe0oI9d+ejIrIijKedKlZSUVbCUwYa5Ubr1U3gr3DPD+" ..
	"FQXUZhU8AYMSLv8MuuO+demjY66LA09BL9I8mL1Fob87vILXeRMRMfj+WVGQOYREkiD20AFfDZ90aplCX9EPLvinN5L2A/26rolo" ..
	"SelYtXAqLuDAHM1BkdIZidWISMY/wY0W8EDTy1Uyd4Y1Glw7cF1J3nuDJvHO9f7RgKYqfTfhEPVYedZZED2nXSCFNwrwf4ZwrjU5" ..
	"CvLnudIQw54V340MYrUwFmIVPO4tj91WYNyOLImJcDF5RRFG3kxLq7oqhBesAAeS7mo9GROZdwrP9H+9F1SxFmuBv8bjDwYxtHwV" ..
	"eO0WtHbp7Y6V/m1mXGiTYAFWzVR3jux9baUwqGzM5UAKX/1TzIOf6zCV5/WRsndwADJVKtTGMJt+3CsVn7RMAqROKR1c8ptUqtSm" ..
	"R+pbdSy7mPhLMbIPItTg3P+XGw5crskcA60/kuFJDia9q1X591OlWFqy33VUIJwZF6Ri3KHEnGxY9gwGamXTaiohw046pyShODdW" ..
	""
local PAYLOAD_P8 =
	"HBZN4ZuF83qGELqCt0IhKp1Sek6Csk/GX1+oQdzWwQHrEAmZELYdOPzrx+ll/lPUO8DynIkSI0XaM1lUtkI4htusl3Lwu6/jx8K6" ..
	"OirhyO9p421wXFJhZvd275JVjA45DV1VB8EyjN5teQCbIfmQbckVGoUWLiduiDEH8CqNRS1LNAdFzpFpOfgJ7Pav7Be8Wlg7nxTh" ..
	"IZzDkKC1smAWEBrnBDW3OMCCY2SShwZPttFCdB0iCPKhHdujo/r0vEd+UA2GHude9blSMBsIUfz54QecitCfr4gkPCtn/4vXV8P4" ..
	"EYgyh8q54PxsTvDV5TRpmN7r++whYPbllT4++XrTDtMROheucd2m/fM1iGrLNmAvpUbZpFIlesWWoY4ywDj3a+inP99oSywbxk3G" ..
	"gCvuqsacfvSur2kD2XUpPETHD02rYsNRG73SsL4LLYVJlrAq2vGzE7snFAayW/+HoueRDWBjABzFPoqtoNkj2f1AW2ODLnjombtu" ..
	"dLJAh9mt8xpJl6hso03U1ub8OFA0q+APDQ3aN4tqaU1vLm92UArA4o5RweHeUUkBNYTUp7ToMsCT51ojC2S/YMO/2sOmEEJAcJA3" ..
	"1YoWnigJLL0NnO3UqwbeQcix1wC0V/9baRVBIa6gPbok47L3vTcKKYYd5Q3v4n7kjMtS2bBTER8nQNfX+krflzpMEU9GtoGvhsy9" ..
	"AO4++05wszU3vqXCYipnwf/SUXlOM/uJF6nUCiHQWu5XkNPpWsu4cRT7rkJAekrKVycq45AFuksOMUYbeiBIXYpPBHKdMPqU5AFd" ..
	"A52EJfZeoSCeHSElZy5i/AqGe/IAv8zCLNJMICBLP5TEq+p6aUrnxaJckA87NJvlrVE4+wW778lgmXrw3FpW9CB5s/VNyDbg8x6p" ..
	"8v45Rj+NmQy09DIKYF9tbVma0KGPysesX1EKTtd17tlBYOqBrKlqp5KsdOUWVH3/ve3lsrzN3PMrwqIzuTJVLZUSJQLAKFzH/SMn" ..
	"sHJ3OUNr+iQ0XXIOehYVSYrCN9sTFYrxwKC9vv0b2ONjv9AwwxhL0MwLK1Sacr/dPjXNZk/PEcja8K1aTlQjSi70D84Pj/LH+c1L" ..
	"RoLwKLIHw/wc3WRjdv/ex9VgU2thIrrFih6zahqfJ6Q2i21jv5iMPaYsJbYBbsfCDnLiyvq9cnckZc4PQRF8v7tL1IwtDeoC6fhj" ..
	"tpx6caXrLS8Jk6JFRmbGHlkzHd4REX5AgAyFKrwa8opek5FYT+ZA9ty6P0tceNhXtBFruywRVpLVv1g39FAJWaQ5uOBlYeOcuA7E" ..
	"pbcPDHQQg/D5qsDTvT7tzwvPKpOX6PvMWaSKz1HL6A3UZCqaBgnoQavHWC6GgigGXg9uMPvFufHCFKk67wLSo+Pm7yH7o4U/2iY9" ..
	"MPoT79fKGziVZ41jQZDLFUZdsX1WPr/UkyFv6BEtGzmLLdaWUxOy3ymDn3lP2K9s4lJKiNK7BgW5GGq5W23pcnmsgDntDmQI23uK" ..
	"R5oTgZpbOghFPPfl1/lut0WbmxKayScwENmv3Ax+hrzyqctRlj0gAvhr+61BN+kP1Q9S3IIcxAF8kPK9N7XnsJ8+UAebiY0RoFkP" ..
	"zo/ErwmUSYHULLHOswe1jwiL4WMqahN/1G8EYg35npKo37ysngTK1ZGdWrnHj9mlw0ZVIEwXNn81rFFuLVjZJDV8aGdp/xvvloIl" ..
	"gVO1ZAJaBOLNMqEqK8zQ5k2bSYKg7dG38QkCiR90GEDVPGFczZmQVXdqBhB22qsR+s1rkB7qW2ClkhDw+nN/9i5RMz4rGTZpgb19" ..
	"XyVYM3ZSOvx6nXSVAxBA9YLyVnpP4vZp7ahGx+6xDezrrUAp/pz/uriIiXRfVYv/DGZgxNqeh8Z2cafqpwhDcRBSVfoHs/BXwEV6" ..
	"3KUCgaDymWqdeL77D81Zg+GnE8JAf6KkNw2NuKq8UQe4aMsoBhOvKQ0zPQZVpc03zxCvA3AeS2oN9RU6+5q+GnY1dtLyBCR3EEuP" ..
	"DqD+CEOhJNiuFHKG3HsawPIL1OQGcq9t2IsnUKCKfHOP8nlS0mFNErqTINTI9nNu/U+lapX3GHw2rhl3avS0/Mmi1cLd2Cld4Hf/" ..
	"iAkorET9TCsaVCRPQ12e0rlJhImxKtIvlZ+J+xpTHvgRWD/A91IxOJ7dD0I3fWgjfkLTToC6pgFE4iPDV1dDIC5GIhKT5UopLKsC" ..
	"bfQGjV5dS3KszyMw52fB6LQja410cGSqYj6sVJHJxTVzZlVNT315knqmygA/vUXWMB2C+3NRJxr/wV1GVeBzo1/4n40Plsd6MvJP" ..
	"02rBgTFy7xEtL6J873NMdJsNC1rJ7yKbnK+qmyuCgtmR3OuM5eOd9HZIWZZiNdzWKVFvEIEQvCbE+Rr0TGs5D1xbAtP266U3qGV0" ..
	"LxTPbZMKJwMwegoLW14TCvSUNRIDZwCF71GPUJYV4WXdGExknxmWmooOTpFx3+TVMryWlWzP1vpO1MU3JVwXCwc7rqwMmUhn9R4U" ..
	"ZtQLe26QMfaEmZ/LBKVPNjeLS2B0B0+S9MK6ffW0tVBQ00UvyV0WRse/R/9YE06bTnDHiAlKgrfHhuMauyu+6SH84pCEsp2kZShb" ..
	"LovAX/7jdF77bfsCSNFd4S5+yHa7T3RASM0pSy9uMcr1xPcLr+WfO0Y73Vdp1faZKUs+MwHdZ0oJZBYsff2RZNcOU7w1Wv9sPY3/" ..
	"jCzHDw2aeIX/RDazeSTEut9nB8hcY2t5pRTRIY0jFlWagzUNJY4VzT+EXoylZxJNEw2HCp23iMwb/LOBfJyuf7FrAufobtwlan8a" ..
	"g1TGfDVvzLLJhOwaUMzBzf7cXVnhRscLU7F1paCU9WXwH2FLLRLX60Zdxc0CCPlGMoNhTHyxmfq55rvF0rr7G4RysIAXqKkv25aK" ..
	"OTctqYRlfw4iaEkZDOTD1boWyR2AtDA9jbCxYVEcIwGGiPr1IaYfT7085DDsZmOpbvhy/UZZy69a/G4XlXMDCDfSVbSSlnWlcZ5s" ..
	"oVJVMTYO8IiBI3eQQBvN/91KNuJnTe4Mwd4prtLG7hu2/pM3YyLG+eJLZxaLZUnqONZfB9iTa5MsoCh6myh7q3iBMsrb9C0jJip4" ..
	"UxemNvPe2a9wmp7YkBJ2H6DfLImqiAcIPYR3QpDQxefGlrgzGpwDjwMXGGVwCsirKXmXQVzoYHqIFv5poFHp/3s8rV/Xiunegopf" ..
	"yifKH3w+ALw9nEid1alXss7HasG646FqbxnC78sQjHEg/0wyYzyGAThdfvA+1GS12XqT47TpGMb0ojJaS69bjXsylhW0fK6W2AcK" ..
	"InV3db7DOSYmk321CcrOFIWrg6MG0CoVxLA5A+CZ/bO+6rfJgV87nOgIGhm58+DpXwcCyz9Vin1w2yp0//+8z1MPcWpivDE8G+T+" ..
	"Jnk08sXad3UUSjaJWno4RV2gpvi4wdPchDIQMW6/URCAxuZdtepG0Ec9rP6+u2KoumPWbKEkNJW+dZv2qmXB7nuI+s9oPZH1IDi2" ..
	"CPr9x28ZN9XXbAA9WGXthmDLoRenAPJG188jdaWuYRSKTZsOaM5BsYvaPhO4KyLFa0uVK+iiShBTz5DEBmobIhyHXK34eaTbSZYy" ..
	"xj499Mh4KbX3U5Ra5NtZV1iNONqjxWpiPWbH8y/9vY7vzIP/l6OLsqNZQsy6I7Eg+dpPZdBaJf8q6podXS4mq8VJ79e0zhZfKSX+" ..
	"hECDzQq3rFUZndT46YiWe4AVuj2VtLh8miw6JoizSpeBAw8ddXCQUgbuIkFvuT8asdJecVuiCVFNbde+El2hLI1x76xsgjP31mz2" ..
	"RvmA/dXoD9Iyc51v3oekYfCxFdIJ433TBefI6z0gme0Xc3W04VQ3qmp7utFuzyNHZW8vHfqQ6dq6PH04yhZK6iu7pnGIjEI/k7I3" ..
	"JpwYdcEfmi89rWT0hhJHLMbCvm3TIk4NWOMd3NGFPAbnQ0vMu9vgHImk2ITAuO5xlj60CfK04OQrsHM73DH/iopd8izDCpUDBx39" ..
	"rjraxCvs2aIlA7RewUJy1RxAkI+BNN8G97MILSOnYWB0yXpC/SaN0yVV1rIxTNbP0Jw6MAPi66OR8lPjGTiAY281r9Jv7pTIVGSS" ..
	"Wg66dv1XSLk6JrBAQFqByAM2avOqcjkRpBh9xG6nfekblxzHn3vJOo2COBnEdaO0ad/PAIPQcndqhKF2RPf1rGzU8QrAwJFaLx1Y" ..
	"9tF+EjdEJJtLUwkE7PCI7oryukyIbU69Vrw8xYYNrS1xdi6OIjFCFW8/6vQmA+jlBp/yFCd5gMH7DF1xCg1F9VZDGwrNo91pHymT" ..
	"3CpiqdNrXaPDDphi/VhPze14F0i9dpEM/Ahz4JPsabmLGHzLkoaE9WIDXBYIxDgEuMeFiBulBDAf8rlUvyrG8m7BSm5LGmOtbCQp" ..
	"KVxAod+BtIWEGcDrW8Ax4ASU8fsNcQir54fHE8VfrTLPytXWA59LG1DjH7PUqTu+M54IJaPLWx6vzV741O6Hc1B88eBd" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8

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
