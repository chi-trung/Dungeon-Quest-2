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
	{ seed = 3789439201, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3785761015, exp = 0, plan = 0, hwid = {} }
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
	"ckv2w0ltDhnc2vh68e9y8eWql//Qsd0fbQFn6vUd4/FGgAtPCqlpRLD6JW1Nhuxca7PYUJ2LBrZbXA2Py5RAbGJpzHkTTTA1nR6c" ..
	"HgADRvCezDyXNC2KcYbBRh5GIXwu8+pF9fZQ6kVgUcD2Ck65agL7KqA+dylqpmPkmsuv7cjc1fXmNwEPmePJDj6md8PKmL6dxn+0" ..
	"SYxePYsumxo28F/BqdVaMfCGcVV04aNBjPGujpBai3fZOxPJpIaI+xS3aoPgkWqvMmsYHheqap5hxB8BgrA0iGj1vwJJjudhbZ+T" ..
	"uFpXng781K9J5zoWBnfuA3xccdYrfAgCDhikP6UtppcLt87HQC/8v80LuyaPr4eGo0FE0MGdb7uuBz2Jbu1skEkFB5se2xc0z0zF" ..
	"baU0xqqD4zLgw9uag2BWXPTM9AUllvKtehKmYkZu7ABxB2T1evgnrdM+xKau9j8sxoZ9Xio3bUE+XBhNWoKdcExxvTR4rC1cgOW9" ..
	"tn1Ud9IcJ5eZ/qw9dBkzwxQFYXTZtoCXUminSdzysfN8bn09firmUwrgcwrZZCz1vA9VUQIF1OBuAghz0m9cFFSkMtGK02EeKASP" ..
	"KYviJoqLPqwF8xnNcsMQPZXhQQKNpRXk5874LjLHcRFXKNWv/k49io1GKltmk2++gNPLaE3pzrDeYi6HcewthymCtyYPDyIc8YtC" ..
	"U4Ez406aGmCOLJptJ0kXR349IqKF1nd3+O5WQzjeuGWE9utZEJWS6hR8CtXtQJxshdbJogxh1YnkGQsVSyqX6LcJmh1QrGfKaRMG" ..
	"CcDy58FuRSIonjsNl4XJhFTtwsD3KCAEFxWTqO+23qrXC4ji1FWkoHp4obTvamPs5Yl+nLvgW962sgUPooEl6Pu2+MMIv3UZlw2Q" ..
	"pjx8yJ8zZUgaPc0ZnJAR0yRTzZgxjFkgEXsAJmJLpOJqzIftpXo1lVH/N00wA0r8SXL+kzNSdr9cluRrGa416xCD8yDuNm+KfSwv" ..
	"VfVPvvjW2BVGT22D87VTKiH+MX8S66iVuT0/bqTFC/O2iKfiLerMqLJ7FjM0nwWWS2jZov/7YQDpssONtbnVvoOD/qs8VVtvNnY6" ..
	"EuBZswx40m+ShoGuZJ2+MdmonT+V/Se6DI24tOoyRN3Es/3A01mI9zIAUm3jn7/pqDIK4r6KRJ9E5HujzlOaEfOY7qeVxFtA5xYr" ..
	"mld44gzg7H5Kb8DAqjpZHDXj3UMGBk5Urdabv/gExJwb4Y9eGs+ODaWnngYmLDjpCd+YoSO7LRLzbKMGml9rmL2wbQUXNjICTaTx" ..
	"ruHU/hSNFY/brmQ2TxFYRZn2eHuRQnME3NNCdtCHbysVvGbCJgGxxqIfsy2fXMwxqGAwfWPiLBlvCwXOvrTTWNWq+zaZDNMKp0j/" ..
	"OnUxV4iFAZHlCw9ym+QHNp7wM4HKn2gwrP9kMcJ5IzW3Jj45nNPan5Vzal6T5xe1csng/IXFss2SSF90wBYENUjqtins2TQCc80L" ..
	"PYzSqkmRq3QPiW7K38653Mzjqtrj6ioYfWEAm0TCUewhEEFsrd2VeeeZF6FM4McNLTNgMBX0MmT8jwKLDecvg9F71X1gs80YVJSa" ..
	"CPMcgAxAk8xeOTuEx3u6lZtkGsKCCG0fIt/tP0dfZwMU/EZMrJhbcCBxiFR32UCycI0Pbo5NvEonOIOKOEhsM2uHjHk01ptgwenp" ..
	"RGzJFNV1Cd2F1rVY7OMm4BDDSIBNmu4VMet3w+hhMNP7djLE9+zhviVDaP/Jrnb8cuWx9n0j46/sRDzSDesNMyGpx6itCX67x0g6" ..
	"/aoZyZ2czdk5s6qv+6khOdJM5Z4pZzy8115TpCOpiYD0CUBglYvhxq3rLv39VEaRgm5aBx3AuJTe5xAJPzspYemAG1Y2R/4KZgiK" ..
	"32/M0aIO+zaC94/DwB37haM+kUbZKq7VmqdjKy5rzHL0MLsny6KcJe8Olb0Qa9Nhx3xDfOKmJL3HbHEtHnWKhM8XgkvafZTAnsvi" ..
	"xm9uHAbHT8aDQ1nYqolCSyxHOCahyDHW8K2h4BauEtWx8fmCoYIAkn2s1aRUGmg5jkMrXACb49BmNfE55yfb8N9iJue78/8hAd/f" ..
	"bsyilpq/Svo01KWK72a0Zm3ps+y+KPngVHgWmxVwvc053oJSYcUi98G/l5Rtgx7zDdHMCWdiBUGvzPJEnRsfWwrDRDT3+iNY5i1W" ..
	"lNmeRF0GELEokkaOYMuj0WgY7A/3Xk9Isx7W576ELERYzf5Xj6epS+gvZ7/W9nBgXri8tcJrgk5b352be0tRk960idto83KRdKFg" ..
	"8eFFcUuZ9fQyySpF7PBcIsuiNbwp0JkXb/zkzuZh5YskfsDF5uIC3wnpuGhxV27E7fjtmSEEQcZa2H1lqYI5er8jr5AhauUu5VZe" ..
	"otV1IawbelpPoMa2oI7xHAIISAsZvlDtpZkcfwEA1n4Cw/iu+deYVPIDC88zS8PkxkU+7MdIRqfG76eFGWm9DaPBzWL6j2b+V2lF" ..
	"A4Fjc97cS86YnCjDRbEgNXVrWzeRwHei7tC0e2z+yUaxBNbbIcUGD+sqa7PiBimgtwV2aYxror0M+cC03GVCBpwv+5m1sdUV48hP" ..
	"Xj/1EJifIF7QdF5PIu1m30lRKOnI8KkIgGhnHllFgr0F1SNdMOYiAkHmTY8Kaq3ljgTa//f8sO+oy3+s/4rHtfArj67Y14Gx6N/G" ..
	"OOAGjbfYfJ+X4nH1yb14uTCmKlRKSST9Nf5bhHg5u//8jmr8AkyKcbH8X1lYEsP1vgfrfAFL8tsCaQBg9AtlwwuLf/vm2Nr7w7O2" ..
	"G4coQQGVFffgNpbt8USMQRMVzVtQyhxU+GSnre2DVzIr/PtCT4rxYTZwyO0LTboTQA+Nn+7siMwfHT0tKVQ7q9gMYKBdjNdKJDl/" ..
	"iWwZRi9VTuUkF7QpIl7t+81HrrY6oMv6Wt2aO1IERRjJyBAxP1Igi0LAQeNovRoU4h0QDg1nuxq+ljndHlnTO+kXMeM/b72Y58i7" ..
	"spUIIpX4yoCgmX3qknHrfqUFMvpT/WovWzzqHn5WQmb5GdSjOKTRFtpN/n4hbYbLo1RNqee0S82jyb+GhgyQL5IkqKQ7R9OWzPBg" ..
	"VN5Jvcy+QkSZHyswOX5XXgXBZn1/OyYY+vx4uoPn4Om82VP0qL/eRi+x2cQvNBLc2KNkIfnN9cnqJuD83/jyoqK7hB951Qrugv9n" ..
	"40AFcXOc0ypOPgJcihGttzkrQCeUl78UuDf321D4qo1mJt6stTNH/qlc/4zVqWMDENC4P5Va/OmXDieG2WfIAZX4/GzmqohwW1+B" ..
	"BH8DUUYKkxg9Bvb8zN0k5USLKL9Qv4D73PRnJ+npyjkF8xBW7ZOniE5o9CIjWjwnfWOvcmo6t9HzuiRI9tX/NSaZjedlUi1SPNAs" ..
	"2r6cVRbMYnEgK6OMehcW/PXsWMZ7zE3yqTNMrZk2zp3GLJHVUoy30hIUFSyho1qkHAuye6VfdY0w0rRGhZQahfNwuuAH4vLu72Qn" ..
	"wzGHaI+2GYJ7CJremTPhVEmJS/lQGrOosJ8IXIOZlindauIcYid57CiaN5H9P213dsaQaq8XZgHWXa+4aS3cgLrAKakc7GbQ+nbf" ..
	"p/auKdxIKwXQlqW3MfjzcAqbqCyPbzPrFdCHUrJG2QXOReo5ox9ewOUW0gKLm+pmVzEjUGLVqpRf70wrhsCOej7xPlUQ1nRrJ2R4" ..
	"e80vtihbw41rID2qZ7FeRHk8UMRc1WYi/y9uJek/NKJGFiuDJ7+aqSLKc9jWZo5/fF1lZq+yCu+JZrWEfsYyXerqPrKvyh3ExzPl" ..
	"3PHjoJNkU1mmhoBvZZmUiyMbWmZUMeSKh780tScv3jImZ2HbopfFmG5HpUMUF/ezY9iJl2Cz9zD6U+f/9xvrruSNaxG4Tw6mT9WR" ..
	"R1kK6qml1oPKlPfNrU4+3mIO6wy2vWfCyrRpzdl5VNFASbRxhzW1P8fyFpCmbq+2ObT+MJMcfUbirzdgRvbqL76CqhJdmANbp3p/" ..
	"nhlDDvewYdKGlHqDuBRwEuuBi4ZmybkzWh9kGFsdpWdRK7AFuE5fT7jG48UqfqhU4bEYTf9kFTFl+wjAajhj2EvVe52XPK2e9SX2" ..
	"6oLc0fd4l2VIu5Vbx/OZxWt28xBcMjItq6y5qm2j6QMxR9iIAhuPq7l6aH8vQEkZP21AlYVWUK9gIpul48DVlOO/jqkWd9g0fXka" ..
	"gvd9gnrYndC4S0bDZaDMCOhvhAcqb7gKTJ8q3pRidhhfih+fQr7T+DLGf/jEpycWFZ6geufLI+jAu6Sq/GW5hRq33P934tpILWlq" ..
	"YzOQ0TPsIox3U4OduMflG/gMpktBBrrRCY0iK6pQkPJnsufocQvGJN58Z/ikppksBLUVB0cN2IJecBU7VWQyr+xhMtWYL6shirvK" ..
	"bfRws+Ql4gL4Zk0F1x/04XE6GcfowJBg4eORGht18tRDRtBSH/AfovINpu6E3E++XSGXIi3mzYGIyXM/MUJhhdtkND0AcTdFFCkq" ..
	"Vcg7mULsqee7eeEugi5OiaSBtPY/XTjRuigbvdzg20q37dIotE9QwSUpEdOB5UNT2/nGEZd2PKjG+DEGDSopsne6E3ZpuY3MkbsV" ..
	"wk72AnS2504lXXc3aLFxNj3qJGxYvekN8EGoHJm15fN4DDdVTg54QoWrlBCw5awooOW8SUKKFLtgN0ELPkRhhZxByTzsV7TnX7il" ..
	"rfVbhQQ8svYaXVsTl2WNkI6hc4RAW6wIlZuyG5qcr69pBTaOHxh9vfsHHPTFuMrjXmWTuK1SVXFgb2tp4byU4OOdGGzBIbGiT7P5" ..
	"joe3u0w2VGYC+BCEn/LgQqTXyJQatY0zOIqrhdy34Im0Y9fSAHeiQgP5N4TI8rZ96+PQ+TI8zGcoslUgnJrOjsgfH1SekMSLQoeL" ..
	"SFzk10itXgGO7SgBD0BYcF1TXS2uB5+cXBA0H8bsy0sVMLbDETBrUO+L4UwrZVs0R4GjtA+tp53DtsR8N2o/XJvPljARCK+aHeFN" ..
	"S83HXZN8JApS1zjJ3N/hC5Obvz4q+7VFQPWAYswLuLbUzzYUGdsJ/wWG8DNbzt9mtpvY1jby1yhqb50yxk3yHP46g40Sskbq38vj" ..
	"worS1rNYGOV0/4kEtcZcJyl7OHdipRwfTwBNK1v/tVTIOlQEL0UklPKhhcb3/2oaxpQJZm8GvpT+SAX0gPhkDslFKF+GTkS85wxh" ..
	"wRKoCmCfRZQO10UZ5QZbQ2BoAqingQ6Qg1TSZv47i9+ZUKRfJGphnKdz9S8vNVj1g+nq8+699FJMlUuuGW6bh6ScWrweKMwe5QnL" ..
	"QvXXvmbHuneRcpcWnQSNOIWMQ0WGQ/ZkvlB2e16x2rwN/SJX5fVh2MmVZNvJEM+7kkaz31vgDWj+BSO3xpNy5mHO9uaR1rg58OGz" ..
	"avdR2ilW9G4TucZWK20b06uUQOQu4iSP9f9B27z5TC0AVtBjGQ3flxkeVEtCBOBK5gg84KHc8Yf2bhqShFDGNp+3LuDjg98JjFES" ..
	"NgpXIyRNbiyfK7Dr2lVIWt+IIMBzVu2ES4yQ7SxpxXpYtboK0pbMi8aGhNerc+9tQOc8q8E4T1gIP3+mix+TAg7ub8cxhxQyvcQI" ..
	"CXOxczRNUSWezjw1WqIMUvuqSzfs3JG9AmkfGr0rp2f0bkUs/iZtholoh9ySmHYkfy/yD/hitiNob5tYSvt1Rc7hUlS7CdVkC+Eh" ..
	"rVoHMSu0Mff2neAdiw+CP14hozQIvBYx3ivYkp7HMQqSaVPYTn6BHS3YyFfRu87V9mtjW8dGiBI5AwYFZrFTfQjv7eb01UOj/53v" ..
	"IpQnHBD8K9khAkCJD7CWe3Zjva56DE1JS0oFi+lo71mDX0Sw11K8aLM2RhU7Hi5digFeu8sUxJEUi+PYOfgIWkRaFGjLAg6f2Hye" ..
	"V9qe8SIO0uix8/rxmlPipw0ex6qYKZCqgtXCYDACu1OWGNFnmN1z70iM/0nXqv4cMioUIxCGMyOmhRp3rzuYnwipSEV5TXcdugsV" ..
	""
local PAYLOAD_P2 =
	"fOubWBAn8259vYqLSbea9V4C3EenojP/WviSjTm5WpBfy5T91P7ppYRq0pbICZnoZENtMRytlX3LqW0k0+T685D8OF8PwygJt6Ut" ..
	"BkCooZpvQ/N3gv5gpxsLLbhQ8nVVEZPKnwu7dp+bVE5wCkMD6M6q+xxmqnhQMWWwRE1pg2cLaUqymI7lNjBtqT3jRtkogQ1jUQjR" ..
	"uRVKBTFH7b0mcIcAHd9C73PbNwMh0wQmzRHZf6sykvlSH+NJEowkcfawMUOr1Bxb5dsdYbgmXRT2RQ3dNB9tYqyOxmYU5gZFFZOu" ..
	"dcoLwz7cD1OMPuXtH7n2EXA2ZvgUU4qY6I965qqPuDuGUQvLjCPWPr6HOmFIvSHuGXxHtZ4l11psA0ocv/XcvfLPeqN5JTIxNA48" ..
	"+S+P8EW9m7aM/UlE0jt5lytVsVZoaa5N6VNP6ZCoTcnzcuFtorH67aG/kFpgXMsnxU8LzMTy8peSVnNcEhEktruTDEvHnZ3VfJvT" ..
	"rX7GXr0IU7VC9BUW0XSvsSWIQ8aJFxiZOSN0bOFyyrSqVbHNkyBEeACpkqCcQjBpLhpeFiINBMVzI/+AAAvLHFppOZq4Q42UR2aa" ..
	"pVsnOY9ZHQH2d7ER3VhbMyjxC6m5EPlRV65XgdZLFP3GRBPnvQwfsoNOQd/W4q50LABUxjL3zcS+pNv6GWmN6T0bPmpUAL9bo88Y" ..
	"tnZFp7pfWa9XLmbJ++72TBzU8ZMAmrlnr5IelVPleup8vqfaaBjrBKt8MaWrv7ik5+rdxl1yaj+D31hyJfCp6/mIvbfgA0DHij7d" ..
	"ZFlYkNvHVPJVO5Kufv2S2wHTGSit32OZg/CO7jkWr1WTl8B7wmlhxhNMraUoNxEt3H1R4iYLXSIBl5C6SRaxWETufiQPF5/YkNYz" ..
	"TAk/4yYFYyALxmWBkoo7WzX7UiTXCEkqysOYU2iTW/vXpud3r8uLNgsRMTAptiUxYAJdWXYACoU1aqwoJqxEmytVT9m4+pfQW25u" ..
	"QsbYc+YvW0fxJImMQiZcG0ua3O1N+0C2G0gwUbm2M1eEIGdOnICs8iJgCSK2/7C2oQ+Ly8F0B9A2MN4ytDrZy1V0iaCQXkOEeOij" ..
	"ALm1T/jdBwnvYh09bLtPzQPzY9aabENcW9O1doRFTJXKNct7p6MTVUv9jRAwkYYTevlCaK5RwGKGiudgHbKyHqttyQawaAmJgKLw" ..
	"7UccoDL/Ds8kTUCh7jKa5UgtyNFgJspNflprtc7HSfSOjrNWmZDKAsOOsJnHRcNaVF2xIjNh55BqxB2sclGIx6wEiaNQJo74TvH9" ..
	"6jl4dl41DDUy4+ovSXMQVp6Xgw4YwhUQB2leJhvKdAviDb1XyHKnOi2gg5szePyz4dwm/wbLSwtwM7pDopyNNETmWswOFVZYv2Bu" ..
	"J459sGhc6l0FZHdnw6G15qH365uGSO6cv7GDPvKe2ar3jhhsgTB8zm0uW9Ukf3u6z3VGOFXqPBLIKF1QXWSaJdyPxyqNB+Q/ctXK" ..
	"/ERo4m7DNdxc+SIQkupUZV+Jzih6MsnLm7uYd4BhM6Nm/okoUHzYwzhXRIa7atWMzhjtT1dsqgUhuY6ZfdyDehNLR/2gqzsOJ1rx" ..
	"zyO0mNqcXpWEEr/NfQm+QtWt58ZPoaOsJ3ZfPPsACB1YosYEuUJLlxadDd7XksxH82VbcaQ+X0EMctS3GiPUetEpZL1xU33pniHB" ..
	"mMwmMbWKj3hq/WJdws3iqa3VWxALDOEZSy1/NPHeeE9WHtUG+ZbuVrc1l84/JBcIp9mgS7Enuze7OWUYTpUqBEDb64WF1Sjukhvj" ..
	"XIe2nbj6jSuedxChXyr3T/H8fXrqHLMufkn3a+LM7eluYcdVM3XJZtYF8RkpkH61lKrVTGpN3CUTgzEYoF9DQj/hnvyvUYiUo/BX" ..
	"v2CVAdDw5VZYRUu4FVpzWiyrPEcXX/4rJqJQUNI+ikmysAUp1TIM6SoF0i2V1NRhj+JTobUT764dDS71X1lULoX+B7QB0GfryQE4" ..
	"qUUAD9ju5hec7GXfiq7yrXquko4jlug7BN76Vr0i7MqtkzhI/+F4DOFugVMKXsYHwmTw252h3HDq9SamuoWCLTNQTu9pidHMrCyo" ..
	"1/bpjZJYnZLoniWnmAtEyzl46k9vs4yBoT5QA2mumKkiHhlwYkRxeFmTMiVy0NeR4S86W3nog7tdwwSqBB14e05JYSjcX5Mko376" ..
	"hQ+DItMci+IkeQSTxEq/A5OE7pkuPn3fIZcgiud/wk4Qfmla3YbJzkCnJ60oVKQgtMME6Bx8bJv7SvGEWO0Yx+ux80QSnJPAUGZN" ..
	"cUh8lezWLvUcYcCa0XpuFfaOZ0DeRIrcDXE552OMt0x8g1w/M6tIeqFt16DjVGjevt2D0Go8xf+wA15HN9fIeH7dtHV5EizElmof" ..
	"Sb/ScmOrkTuvaYKVdwmgoC5bJuC9iFv2U9gwZ/DvSO42XKH3m7kyjS9wLjSve2diGFdW1xsCzw8d3BEw4tIgmbef8JhpIG95Ymqy" ..
	"ld/Ogol0Gt6Pp0rYkIUZqlmI26ZBI+wuiaVzLIBEMy95Fnikle8NafaaRx0cKDNU7TieIRlBafVmOaD1yeWRUS9i0k2HlpU8UQ+q" ..
	"d5YWVym7X+71sK0nTB39SK3xhVG1v2q+IysdU8JzUzBu63RDQmTqYJQJut/qGY8WCpKNE+c3dB6Gzg0pgRLXk/N1RbZk/4rK3mgu" ..
	"E+M+dC6LHqpxJd6qgPbTOBKa6qz5K9i88VCnP8BGIufmuG++6or9cjSWlfV1zwLaWLcPdRveFZbma6FiyrskASBcdTUOqC7YhcgT" ..
	"uMJ1ki+DOelFIzM/tLzOCGrwVAa0quVDwzURCIaEloP/2GzNL8p5NJhEQ0CVGN9ZS7rOIrB0FGfTSObG+7AUgynnquusvyTVNX4t" ..
	"vmvNXCq8AwR98vSGBJLAYMw1HBCqM2E/jx9e3FrCJKsqcK3cicqYQa4AcHwGQU/6b7CTxQWFTVanG4y3XIOLKxLMG/rxM4tOLg8m" ..
	"a4Exgt1N5x2A6cBaeP8W7/o/WGcVhccdGwS3JzYgcMAhDC4IsCxfztyD7mml0O63ErxhrE8m1HHmiKSJ4VnnapeVd6imTzYHfrDc" ..
	"PQJmgrlX+2SG/hqDtKmRCJewFbBnyGz0q4zHZu6Yt+BhydT92tK4uTv7FgjT9wNU0NGGs6Vb39YWDbsETgwGihE00wSgjBX3sqfw" ..
	"+KyY/+9ELT465cosopmUPbzZpDkdpacdRZIkzoD6r/Wbiofq6nZr5fcYUFhhvJRc97t2IDELgwOuOPddJJcO3R7pwSI+SDRHXo4X" ..
	"SwPK4D7Ta11ZB42/fHgAWJ5kplsSgyt94OFvBq1FxctVOD5bukrtuxd5rNcs/WxY9IXu3mRYYbrAZX4bAdt7aGyVtASfB9o26R3Q" ..
	"w6UQT8Jm49YWVh0ghbcWAf6eLh4bGRTgL8ePFb6f19P0ROyy6m4MzugN2bGXRrAZkDXiiI5C1p/Hv4ywF8rU9IGJaZIixIOJH/zx" ..
	"HL7pKnUZqqsvUJAUC/hjc1AhBUjhJP9+sZwYPzXjpLlfqoWeh3RRuNjBFst6SDeYbxCqPOwPuAtKINwq8I/vZF5kvKWRVptU3aKU" ..
	"/6GevZcEK6IGDesln5bqXbALQAxyC+lef69irn517jUM3Mq+3bidHyypjYpM85Wn0nD9vnZkHUGQeG2CkgSw8Zd7REZtBZTMs+0q" ..
	"lPbScRvn2m2zDVlQQiUKe9bq448K8d6to0MHh4jU+TkUfHALYeu9O+Wz7F3JxMgQQwad5LP9W2gnXC1ytcm0JErTEQfHh7V5aJAI" ..
	"I8Lhi6kdeJq3B7nlYaLcj6/sEt1QSXr5JyeNAGhBXkdePLfaxs3iPenw5+GVqGUYl2oDCvk8LAMjNfcfd8x0wIPI3QL5CxSZyPhu" ..
	"FF3pNqDe41ZhL53LPgL6fVuxO+US3S6jQarZALejRjfdTUwhINC8nDDS0kuz2fWtJQ9CCI34HOWiU8CXmtbs+RTQP/NI6B28TIaW" ..
	"AnaM40szXnRLsLkh0v3iqjOxrf2Eeq/9SlqrB8lyuZ/pQ2Z9CkzZNDfp5sAlqiyjgjHHhSQlflUdBgKoUN72BDjtNIia65jrI8gk" ..
	"PgA3LnZMuIel2xIy4UKT4jD0TK/1OI05HVMkGQXFVvJcIvDYPx9JqG5r61SL598tYyJwcdVy694dZVOaQwjHTK58ps+kET6P5TUL" ..
	"EE1F69UM3FOuKbhNssas1Bbop/WtXh+W/RTHJ8KYDaHV6wzcOxwLM35aIjN9QO2tqj+XDiDfVNMNuykDXvROoSU7nFmeY6dB+cI3" ..
	"3WAKjAWSKHkz1vKvcnAKJIzNGNg5bzuQQnHk38vBeCY7zq8fnYedPzJcM4x5rudF0b76pMqYD/VPV3pqNYgVTok0Hrl3amuoDPC+" ..
	"nSSgTBdBLG8fuoFleOJk542MlmEUXTmIu05tzJgMReOeUwD3tRxO/G/DPk4Twd64fp1Pat+qFXjMrvgVIk8yL1fv9whKdzZ1jCWt" ..
	"hoC1I1490dsz0LQZCpNV0PoFlb0Jd9Yb9HXnJf3AENp9UhxuBl9n+zDg+2VS8bChtmS+yg2PV4CdycA8OokdWDuaYN5UcTipy5V2" ..
	"grfBhm9rpPLjRIscQ7i9B6AV1EMvJ72bu2XI8x5Mu558aPunZ/WZshpzC8OaK+hr3Lq6fDGN8/0xfLccDlZ2D0kxN0bDE4DU4Muf" ..
	"UwZDKab6qHylgL7pfMd3H/W1wvquDtE6h7shbuALmvgKK+cZCtFpda6nDInxhB6aiQyxdNnR054tyz3+qOddyacBOqpgB6rs1JYw" ..
	"9f16t/TW8wb4/Y2GOaPYFixImSHOqcg+fe6N2U4eUCX2Sokswe9nKAJA/OzJtQ5cv7LDVH5eopJmD9cdvZQjyttFA481hM7tT8aO" ..
	"zlC6PtmuOBZQstNtBEazpujFXneLbGkEDxW5tE9s42d7cVXxEnB0Q9H8IBcytRuTl4b0h56DQ28Bwi49YKA7IxPu1NoCb4ZvdWN9" ..
	"W40N9KvscgT1ie79NPuH9yePnhDikIZUsEUKetYJDyg4zQEaV6vlp2aLkB+QwU2hj6h4nZeXjLYWW32Lmb8oVs56j+rSN+3Ig8t2" ..
	"1/CC9F9wZKQYT39TyauzokAXSjcZmhd9G60GkJnupiJtOImy1wXPdee1uZu2CXZZtz0jZsbdGmbY6m6nCAQkxPPE7Vm0Lu3Yjc8n" ..
	"0W2PS8Gug9hZ9plo7flrbF9wUamsRVxwq3Q/bMB9G5KatkS/d4E7L8tzO4kUXa/QG72fmu0OfcVz4orZfELEq1bY0iDhwh/C9PeO" ..
	"fCDTqAfqt3TDCTBkctzHd1GfQ7pBQMlnrEm1tL89S/4a+gbYVVcXbrNcpDo0teGSbFw2er4Sw10fn1gMZhXi/uX+yGi8u+lVRZcv" ..
	"j8eJ5QwZZch3MgOD4qdWORIJrPGqOXHoTEhq49edxNa95cX0eV8lY97MzbQ08+PKEuGR40o7a/t32Qm1H+gn/IK5XaoT/ULGjBVW" ..
	"QDBAw56fW/gRk3xcgjyzsqJZXmqBuxcbJoUOCY0H40Ksmq6n4xvvH3X/Oc7X3dI00fUJK2X9+u3Da5FDsr28/9/MKbxsIyhgKkwV" ..
	"Kh2qaoNkN006pcOfg0wYzvH4pNSXCPBv/UwuTAQ+oaxUsNaMLsV5ggyJAdy3MuUZbKRAy0sVRHvrD98jo7ez1gm6DbIWFsFMvlpX" ..
	"qTSHfZld61bUsGVICxkcIe7xUu1z4WKovA+UU/slJDA8sqDLtRDkhsbVBqeNdL0Sn+BTNbCbH1W/MbM/bLa4526Zl/KX72L387//" ..
	"7dAogEoCyCd5iQxR71NKwAZWb6E+dXwYU4dqBWHnYynHztbVDSsMzEjwgaJcQcsaLZAB0eVxGt2GAPgRvaPQEhi1NmhU1XZyKqdg" ..
	"ijfZjSWhAgqcaAFZ0ixbMpR3eyaSwQwf9Xz3GbU9lMxTGGvvesev6LArVnwQkV3DHrZMyK1hEN8JCD3UPgaY+vG9C/CQKjLJFaE/" ..
	""
local PAYLOAD_P3 =
	"POjrIcOGF6C2TvHpLDStGH4U2fIdYofu4Q7x9auksK/RXHQtCaVqbk2D5+7dH8WRBtl3UzVnzRvB60ZfksxvrfNY7FXqxOhRF3AO" ..
	"ZpZIKr3ENMoZBvGmw5bQANyQW/ku6IThBt2Meub2oVZfsODVZA3wbBGVkvlN4K5M4h+cfE88sm+jKFZClMszXi7/EviEN2rXXNDZ" ..
	"lJM55ZicXBcJGrObm7L/DytrrN1/YJiBjNMTSirNLQs45ks7h2JvD/8KtLBKURx0XXgOh2D25Ok0cF/tXWFgLUqhRa4pSqOOMWOQ" ..
	"+89oraSBsNoAowgX3BvOrKpjoU64a+3fIRJCG6jVLUfn933JU/axZJUv436eMzzgoIokgBcNzgt3pvbRB4i6tdhDnRtStn/N1fkh" ..
	"u7ODTt/IAjcYgY/jjzB9MjJG0A9RqG0oRQTU3IwnEBQSUccjfYYcOoSTh9OB2WNNYJ/rKMGuPkmULGXgvH5dAo87GZ2YEb20Nccg" ..
	"+8IRPslsqx5Apter9FnGdPRPLPcyvd9TKrD/ZpyW/48gd59WUF2bRmyoVPl0EL9Ve0yInsJTrhNHyFx8Cq22t2FX83w+frEVUH3Z" ..
	"PhWD09T/zwkGc5LDqQVXo//xRrnvxp9CAbUwMJTRFxQhsG8sZRYTmsiaNmNPdGEkQYUmdLQSucWBlC4ddjNrlONljwwspzFcla3e" ..
	"+2xngbeUBusVpPue5gDFdKmz9eWV+tEsXCjZFi4ALxxocoYhQO0ApRrm8GV9zpATT1H8K0VogMVskk9bm1KiLaYQtARxq2SztqYH" ..
	"Pv49+OuCAjN/3S86H3ZobKMvO4a0vH8Ng0SuDqHQD3NVqUuHYoIj0fmG60NXhL/bDoedIHQWHawo7LRptnfLYfLZu6Xg9gKpvrUB" ..
	"aJBKof5k8i4t1AxwCwmq4r1h/l+aT3Y8bdFqvnL4SDQSFUjRqzNmwc6qH+vXlOQEcMTyt67P0MBnPLN4dX+HJ60JvGzdp0Zfi5B1" ..
	"I7T5SDAgygB3j0B+Eu+Qmj1v4FY7b7ko8/bQ3MSTdX0BxmENoUGH2WDC7A2Wa/Nb7ziI63br+0iiiXxnOoMhb0QopkS//h0XgaAf" ..
	"SWECAT5Sgwnd+N9s7uoi+NtWm46bZCZqskAMjpgDwFD58R4J6exxZ352wrvWx7zVQFmY1muFm/Ry4GbUGyruY5bH/tp3dtTIEtlm" ..
	"mdTvYFuwhNCoGAhnYjKi0a1ZmYMKH7nMVkKQGTU15dLNMfDfF+RL7xVTXTreov+/ib9hjusKljgawZGzkTjcZiZTQTPLsxkppXLe" ..
	"wFH2EhgSoIMc7ucBdesnCJd1jFagbo27WHQExh2j3kdlvCXQxgrxgIdvZFfMEowshJIUxmmoH/273r/hxJ/H+crIeUNmfWUghwZ4" ..
	"n+njzfhfMma9PTbFx53yFZYWvFm1vr52ZdTNyFFdqNcyLDsF9f0fenq4BQeHiq8AO15a6hnNv7hYzPwik2H/8mnVEbHJovRzEikS" ..
	"GWeXMcp/56X8fQOnG6OsXzz4cqLkZuLkz2tqWJutFevtkbNHwSq0KUT4c3VHG/B17X2nY5nho50KoEehVEGDA8h5LTIdjsbwErLN" ..
	"uLcn5BTcEhr+EDEX0Ld7UtHS/HvJiyo9Xk+2IIkEcpTrO5fY0RrYfSHylJlnbLVn3GzrjhONMq8SMD6LmeYK21GWsgQRbauqwRl2" ..
	"jcVGtyVNK8efX1aud9HkXCBdDC/bHcnZTroSHVh5cgj4RoYqBVzgec+lvlOhHZ0+zB5KJJsgDa0zeI7FJDsvbabRp0VmDju68kWQ" ..
	"6tJ9G6L4BTh06ioYO5AsdCPueUGAhSu5mHHBFm862KP+rXkRlLXad96w4gggqcd7p3UcvlG7cqfXmh/J2dvG7kWe5mNRexHGoJZb" ..
	"qCxOtH4k3CaNuFpctiKxaUORUAsNr23eJ909h+gdqe8nlV41pOh6S9uD2PRA+IASYpxnabzGJlR5rpiMzYpUi+p66WfNA7Zgf4p+" ..
	"tisJvdE1ry2nP4Sf3oPdQokwJ15PFhaJS9vjpKh931ueCg2rg4EyB4yEMSy67shxUBn9pvs+gFpT2SgEUBIxjQp5ay9WCZLDJyiS" ..
	"16MvxEDYB8lLqozkGMCdiC5NH0/Rt7nVGTOA9/4U8csM+/ZLlME1vQrY6Qhkfe5TrB2GXjG7Xzn0r4bST7bo+i1m7XdAsLPt8vMo" ..
	"6LMYLuoojHxSUMIX2aW1dT6rW8dMs6pDVReBq4v0Gxg4q20SWGSsfuwYvWVuQQjRPpbwwziiQXqfUqg/U94Ub3YFMGaTv+amPLUr" ..
	"kAjFgfVuq2WhXPb67RUNFdooKhSD3ZJEFsjXodhM8bA56umYWBF9O6aAScAaR7/WpoPfJ49MJhZAgUu9Iw7BdcUbM30YZHQAcvgc" ..
	"wNOvY8JqG2Qra2pcoziglcKwaxzb+mFqwL++VYWMmeBmXpJlcZloRtZjiGM/tU8sLC3dBkGzWclNLFo4bI3EybBMZufEMHtKUjw4" ..
	"Id+7fQTlPj3VtlHL9HVKcChFx2o5i1UzHs/WxbO7QusYTcWMeYwOfj9SzhpylN0kL2scRX5wEpqyISMWO//S9OZaZ00ASXS09/Sz" ..
	"mNL/5inzLwkkqvY4nf1tsp97vvy3ZHAPLvQt6PtAI0U0eDQSMDI/wQhEfTgB+YgX1H4WOBCidliNEeQs7CCqpIlgbx3no5mFnTuM" ..
	"k9u8Lu7LI14fy/tfuVPNz3WL4IJkhWhKV0pTXKZ0OzNqez7dgY75dpZvqB6PTMJX6O3LdW4Ux+PfURvCfpe2bR5A7uMtjetn/l8/" ..
	"p5IL/eRiPyZOSKAfnJnST3SZr+SwPgHR2WJ2yDMpKAVo5RCQ+vizmE0fFBhMVplqACTOMZ6dj+V6FHByFWPVa7RLRW6e/W6Bkt3a" ..
	"wiWJfEkoS9BtzKYNnRn3zBswRoGC0+zRsNRbpNJ5swu+6W3w9qRywyK4/soskb8cwJ9b++5RSWZeNAEYPu+Z7SZ62TcG+PLFhq9c" ..
	"TbE4WE7x0MRDpnMKJ1jyhqBMeV17xUxLRqUqFhO9ugZYUCaGWg0Wsb8sxd4LdaoXkazUnkkEaBW7bCoB2HkJiyVP2XpFBYYhKTm8" ..
	"d3zYVwUPB22YA689bO7NFOfe+FnmtUGt3spEHvjTEgj7Pje21Mf8UryHZFAI9cM2kJOKVrUb3/V5GA+2IofrZ/hRNPWnnhoLgRkH" ..
	"2ZqjDbhSZWDsr6ai/AJBn5xw/1eHvvOlIHrhsPQI5g0wVQq9D96FTWMVx7pBQhdQzoLmvopGiaJhJ5HDFSi1c/Fv+HrJrr8gvO6e" ..
	"c+EiKRY6XXUGyZkud4gq6P6BD6Ka1qF8lEJ9+6xkTTB0akYADSONoDiyZ8I35EPEMApwcWrTsPVf5BFOBInHmRFyJ0aKYM6MGMFy" ..
	"0XhWiqfeU/toeyIn4KP6eIJ6lVg98gLaPdCcaJ7M4ZYpWIKUUqLCx05tFB/m4tuWveDwG7TaIb7O4GqRRO4EYd8rTG1BOe+mVES3" ..
	"4T/s+Pw4JXTaCKf6GSJ9tNLyjn+SXk1zLsb55ZA27xj5l2MyE0aK9zwhW19+xwJFKBZ11mg1GS3NuaOnRJ0IUMyd3a4xec8lMk2r" ..
	"Xtli/2tAjl6v4ya3lZXTuOJqBvRqWKVnjBsTetD3g0a1m8adO6MSyKRUWpb1eZB11QVOmQEkflJnZwZbcnCJ0KAuhxveN+UWKewa" ..
	"MhbTLFv7nZVJ1xiOhDDUizweQx1US2I3JEvoguX3FQIEGSBFJFXgDbYC/wYUQJRHDws6iQ9k/FMU9ZKdnNj0tLvZ6vZS6X/bD9Rw" ..
	"3om6XFwJQmCPpP/9RZvRsK2TRvvvu01cynRr4t2gWMZksCKF8K5z/6NKeWk29XKZWhyB3DBuDkU4Q8qRP7NjjW2abclLLxdq5pW7" ..
	"ZnJ6GqkqP4Hvi9JtQa9DSQ4QWKfnILA+SLXnJFe7obC/znnINJTMlZRfLMx4kDvv7ggXyGGxNkcPNo0a0XVicOxC4X3MR1AfnPXS" ..
	"A+6SyomncS7zDoGsx2h1fC7gen79VAq3otkzRePLUIZ8sC5YlmGptzNkR6E5khwRRrKOPyWk1CkpjDD9MJTRIifvKxIriyVMqSvs" ..
	"TuCRRT4fzn1u6EHjgKYKjN+6orui9Gr4R+8qDed3Om/6fdMSU3SZ2xkLr0rD6BBw20vrVXH58lPH+Zwf8BD6vmEyNgBnZcXS1OxN" ..
	"ZnZmiPBVq9W9Dr3AusOVvfxbN5xsQUkdk4uTZ64IMoE1kzXeT2Ykiqghv+AnmuJQ/7hjBywBDPMPZXGX5dE1TwEm5+LyuHPNpF+N" ..
	"ME1ANgH7PYwaLSNctUsEQFXFJnkyywMO0WpQ5YS4x+J4PFded0o05S3zRYw4HP4+DmaGconp/5jACIPx+E6RS/nCvPHY4nG0BmYe" ..
	"ccaaWhWsgpNCJTD1LEFip2Qx5E3ur6dS6F+aR5MY9I+a9cDhSF8cPvodCOberu9hDJScadhg0Vt5m2xCdVPswegpeCZ76uK+v1m6" ..
	"64OjDk7qoc2qs/G3vtZqyFt0FS2esWyzDDQA++PZPatGP0yaDFaoh4JNtL62Gi0OJCx+CxL5Yqm6Dkqp3bsJWleHfpwJq06G5MiD" ..
	"v43s+bzblSDJKLObMgPNePjJAou0DWmaRTcD7Ev02HMcs04zKUNHJUY9Ca8QAf71731+VXdTstT5Z6KRTuvILz5aSJqKWYaDXuW0" ..
	"VG71DBKh3XDvQWKKy5HQMkJ6poAPNIvoCSC3HWC+ltpK+nZK1PodvGPaOc+VI6wYFLu48pUK0DFKsa68LUCtk2M+uC6UTI6ZEozE" ..
	"0XVHcN1eZJ9ha8fafGAeEr1SKrkGyEUaZsAjfW57uc7PwmOPjeoqSvWddqXs4kQ2M5KYC2owWhRNaameAK0iYXYJ27T0wprH65cE" ..
	"dZW2oTlLvpRuuPTZS5AQlBXLr03i0Z4TvlNdNpq4OwztLk1RLmrXY2VbCGo/PRyQ5Nt3WphTQvkkITdtacfpxKmCNNqwPxDjpVQP" ..
	"dZAczPhYXcpsxpQHsR+dc5IfZAb8Pws5DMUZw1O5IsGgwRhgjpN4Shn2aZ1cWD1LTRubPjDTtPzdhZNLdbMLzykGJT7t0YnevTEV" ..
	"mZlw/Ur/L3Vab6WDpOXTyE92Ow+y9WNW9js694EwinDLvNWXLLwr3+7b964f3KhA0TSsWZ9PrhMHg6qcbILg4MPyYt7g+kreymHh" ..
	"f0CWmXHDUBB3t7KZ9bb1GverFqbIFMVybgj7CpGitQ3lo5kRLbX81wvdF19eC86ZRW/Hozx2x5T+mNgRnvLAEu8kHbwkMStB3YAw" ..
	"EP3banEzMyc7i1MGCvJD/qkzj5TQx8Ri+0/OpzoAANZ/JggdYJFV07RUtvHaxHX1J+PaCuD5qcldjnTwBLAjg9vH8cW9acREhfnP" ..
	"gGyVIhaKUeQKgmyEPxXKeoraSWV27w0u3VpYFV3ZU7nTjvs1WmB2X5e9eYu9QwwxTxaTglrnNB7umIW+K3bTGoNQsrmduEivHUXa" ..
	"qNbOw7s2dVVS1rCfgIFxD8fTuXZwhgFI67qQkppZNunknp6DhkM+TMZSpogVml/5qMDZN0MWO2ChqpL1XT5BIlWRyQMLQqlfiefF" ..
	"S2JXTWUhOcCWko6mYuZv63g4SC96M9hnJii86l7AJNYiEqUsztP9ysCeDTsC5ewY7nDtKk9Az44cQeVw2NqLwkM81z4BDBpnnrqI" ..
	"ZmfDYi11KntB68Yv5/HGKHVZSq3k3BtzZVUffJ39cw2aJEbjYmQN6VGOZ5/B9T4k2Q9zKeyvkYaCC6j6FF0/A4Xyk4q5xlCnxxw/" ..
	"RgwSJK231jdprzK9L87TtPi3e7jJBH5i9EoXR0vVb/HJY5gGWjR67qUPPeFb3XWrq2aYborleqC31vHxp4tMP/jSfzuo76ed43+Q" ..
	"NVmUIfjAMdYMoKAs1imMop0DqEogPzyDBKSHZ/E8XYhZ/O11uZv1v9Y8xE2gHRkExos2u1nqiSDRlLz0MQ5RPlGphoKmVKJrHZVp" ..
	""
local PAYLOAD_P4 =
	"85qMplCqCS9I5DRvG5RGnXbGCScYFOYo5beTseTbBogpyJu6Dr7yxaiXKizY8lhgxOf2Rq1G4AHP5yQwMKN5B5osSyWFl4F2nBFQ" ..
	"n0XBj2iRmjrD8NfMRy7w2UIJGukKo+AbaHRA4h98MC2A9goYA706xi7VyX8gs6okhhO7OJm+t2W1YXmM37BiWwkFLwsspXQRmko8" ..
	"iEEYFrvSz2LjEsfhIWQ8pLVvlXH4aYazt/z0B4knX5vUaU3GgEWiPXhNdN4pAxqcSoEhbkzi8B/zi+AAC/DTLO7YKqz0i0mWrpsf" ..
	"s2oIXYXRNMknobmAOg9ky51BSUrXMBxoVg6q4klA8rYIs5kOVBwkLzzInKee+XF/g9dSLCE7ZGiNaczuann3eXu0EAyp3iO174nx" ..
	"BOpZ0SCjDhTaq7VJ/sH6CtTp+AIgubJaOIBaxgxWyi2YXpMAMze+jv75NeI+OI2IJLWdqY2AiJ7mZE9lwidxek2RwH4++m7dVgec" ..
	"f9SETskFauZSSaP3aWLJ6aM/15Hty7jmP3IuSri0ERgWf2S44lUY9ta9vSKuxjqFBKIy2XDQ+BXRxgBY2MqPBL04yIwRZMfnWTbY" ..
	"Ioq2ikmAotJ0/1hR9b7rnvqYVWmVrIuw+Spsc0j0xNZMe1H7xXvOhddjbR9a+45IOmzug6QM6Vz/61/YA8RRztOYHcjpQ9ZTA0Ij" ..
	"jXSL110crVfQGglLB7vDpPp+ZlfbwXyd2r8X8dL4hqIKHnvIm9BClt2+RiPa/subsN0rD5dgsw8EhpRu5Z0VUNTpgmdqY/TMQd42" ..
	"0pYT0qyLxDMliamOcQY7oAHzeOxcRo/PHRaVCQ68ueAR4/b0v2czNcAA7mi/TDSWsbuQgdrR1us006ENpLFO2DCeyEQHBoorFmnw" ..
	"pKg769oyc98BxriJX6SJn5cMGmxqK/p00tu73G6rHVo9RZTstRddAdfmquB8DHWSZN0hFr7YcfUoZR+ykypm56oG5j4vn9XcjOZT" ..
	"SFPEAz6qrqM/lQ83JB+fJlkpeZ9Ne3ypLpatzzWhoJdgONwuwk/KU2lUfKPdx/Mkhgz4gQAVh5r/2K06mOPuB00zZ9YkATz8h+6B" ..
	"T6Dv02W54wHSKFYLBujXlm1aB9N7DhcUteygSlTJdz4p2K01VSm2BcdyU8yeeAWTx6P0YalnHoK1upIGtwKGqvnb9QMhXk2BbZQ5" ..
	"wMtAnGwECqaG4abav93AI1kiD/25xIHlGfFoQIIe4fEck8nYwbTTMlwuOA2dCAVWm6WOW4Or4kc2XhNNuAB7BqYWeocUswJP6A9J" ..
	"bzqhabAmEhuZUvZVq7RS+iwPHL0UcOIVKf2i01v33e8eRTUGaTGTwxr80JUGe0zwWqGlHI8LQLNjpGYVIEX0M1iKfqF8Tok575OR" ..
	"ovpkUyQYOTAfjQAxgMr3/TQJEHUx2Y9KXldFjspROLj7GjQKyXxH8hdWl5eDIn8AyOsg+7/83gtG+JHu3AU6pb20/cY4DDZJdqv7" ..
	"a7UT9b2ObSnE2dawHCAQz0ghmXG4uWFfGmrKlgkdQYvPZ0CsUXKouOK1+q1viEUmXblGxd8nPFcsErEwUXV2Cgdp4jn0MZi2jwAa" ..
	"KIf6FUcnxvg0DRfSg3mUDdj0HBZdvKio2RWp3mukSbB19P1vdTLV/OOk9b3I0FjKuSDqmrjCrG+yOe8zVsixhKViRMPiAcq6ON7R" ..
	"1nIE4TBnOYkV7yKNQJLwC0v3AGBbEeWALWRVK9ZAdg8tYl/H7Tu2T/q8hYBsx3x3tNzFW2c5r3/JA4WTBGTTgwAP1lRXFgwGkBQY" ..
	"ivldHY28X+A10/04vyr2hHN0j+z+XOnYxSmwzW67A+rUaE3Gxzz4lzVVe/rQtqpnQpdSUn6lvAAwIs6hNL22ZfOOTM9nGLIQFS2G" ..
	"bX5D3kFIq6cBegZaSFJhYwvbCJ+s7Jm5wyOZj8+p9nC48D75rHaPucnuFs7J5PwgzaowmSa4unv1G9R5FXpSQZM5AQ+Te+/aPDqf" ..
	"Mmpdl4BWV6XCo5qjlDCf9A57coPzqJxbqSs53hL7Ia6H6Qa97UZ35KYEQq5BrFO/Q829hYi3grOQswWpIxqTjJUETlPt7YeBIQ9B" ..
	"mRWiVFxiqlUNMwt7gCbKiJ8SlachyunZEHvhz90i0X3yZnad9p7db0G9ix7TULNdGvDWn8oMKrjU4nIEySdaICgIDH/xiCLdoJSr" ..
	"KWpeHgqOVJf3i5HkyG4keyh4Ie0izx7VRcLSwS/WKCj3VeB9pikftyrNxZN9Gknfvd92nbNvhx5dj+QRJ8cPbkacoVrWPw6e9ymK" ..
	"T9sYHuFONrjvNSrDdUNCYu/jHCzMmtRZv4M/3h9Tf5SpApLi7qCawtpR5DRDmIdrZnVwwpN8+oWhRMmwqtg/o8CKZ6rTODfvFlbn" ..
	"TR9x7AfzVcq3sNYnVG0cUkgjsIMNCmANWrqKErAZ3sikFDePIQIkXhGQQVWcqnidAjL6ttjzgudLJIkZ9i4s698WrDY/yFPLCgia" ..
	"nRa8fwwnVgSx5fG/s3pBeAI20pyjRVGFTAYNhmjtn9z8JTOBT2gUn0IDAy/wnx9W6hXYM2JbQEw5ZV4bAIN5Onfdq+MhHMOK5ygu" ..
	"gVH1DjEX9Ia7GlvrDPjncml/H/b/a8g4/GiulOVTwvekDn/YTpGtqVWgVuraX15Fji65pcUXzmrbC0AkaXh6Vllt865PKFoYyYns" ..
	"FFXRkqVrVdiKgn4SzWTSC+CKdg0/SP6mmhnExlU3KbX5nTT2NsOwMbTdXVMap3s3InfWLgfV8gGzg0JGdrAC0thUuEN0dxrGWjxG" ..
	"Bsezfe1B6j7RoAnwiUdeTvJ5MW6e8r0H0UdK834YiOt27bs4JQBAqudkgiVCMlCadBYkXzJIjRWGmk16+/TGV46e9FlK6fqvwt1x" ..
	"iihjwvEhJRJJ57O78IBYVX8noqwAlCGwDGu9SVi5LfHGEFRn9HsokI2WJJusQGNbAbwMfe2VKbEl4QWqYB06Ab7S+M3CLFZi6KEL" ..
	"0ZaWfvFKs53Mhn++WIXd1mRapjsgoRERqTrKBOIgAAnAr0NBw07TI3dzLHeOI1F9OlgUKV2FTbJ6lfm4wzMqLcdRcKdQiMfhn0rT" ..
	"dq+OWdS8X3xQIcL3lNE5qTZYs4gaRVvEOCKe2/GhNLy3lxHSNea4Y8ilYDRXqLHxCbCiHZ+u9PNWe0hrbIQzM+ssEQSmr5unOey/" ..
	"Uz/E/62TMxpDAgpkw79y/tU0usMetnN/t6eOUkb0NDRksWHT9/sJGuL77LgCm/X5fFwjcH52V1xOcHDYPNCiNPbIVVGjuUo7depE" ..
	"S8TuIA4Koe/UwTbFyP8UJ0upSqFVVdLWXuI0bmY0WnwRbuus4Yx3KetmUJaDGNGgDgDHSSur29tZNnES3C5FFX8LQVGEtx+CkkOm" ..
	"Mq9SwayPoRD746O20LK+BB7viPLDUzRshlIQxOFternP4unfTHy0O7C5LwgtKA3bSTuDQRO0IiVX+/9L8ilO3mcO7ym7UvULOJ+m" ..
	"JVPJm0IMr+iuzEwLGE8oFvgIP4ToWQ9nalg+OzbX4zGtVlOw++uvI2e4QxuzhpT5x1WqwVhSKYitaRpyjM+IUodKi0i/5w3F+4nT" ..
	"HzZR/HmDd1NE5v2RUe+nRolEPAgEUf1BoxD+Mvuaedacglm2pQOfXqCNNxRIAD/UgxEB/vFN3kRcZpIGy3LiwdRrUqba7Yzt4gWK" ..
	"Joz7w+S/4fxY9KCVaKGicYeLlAPyLrbRk0Nh6QPPaW9WfDvjFzKipEyuyd499o3Q5lBeEY6sV1BAzMMfMUDRhEw7TzgsaH+v+SBz" ..
	"5WLmCY3KGFm9rtg/xprvIBkK5+OElymbRltgAtXfZ9wabHgQoflO7ePo92xTYSnL5QqgnWg1qP13MSs4L40y2/tWWICQ5JJij28w" ..
	"5UBn4r8wiiKx3ht1HYyDXjK4YOYdm7d2KwdjS2M9pTPVPK48L/5S/cQwLNh74hYOZSLJ4CR95BhE1zugRHWe1+FpszaginCOE7Hu" ..
	"kqs+0WPxiCt4DyoaVzl/0rPS0EbcIp9s934qub075zJJHmE/iACM6yxNzX3nD08YE7MYacNwwb9NnZtLiumaV69EXcr16WPAiJy9" ..
	"DPkwUMldv/BlCoVpXdu8tI3rNuF5ZfuqxhEUs5oqWDG835Adi+n442aGNt2VDj8WRYdpEKKDztXvaCjrjlxu0EXx6DWRKrIvh8BU" ..
	"n/UsTO+LfLYplCGeB1L9t6CRNcSggnUFoiz97TdohgkKgyXwafpjDHQP5byCSV1frVi+mGK6uFQYhg/eUsznFdnBmOwrpXXPTBzW" ..
	"pHKFxY4qXJMg7FjukRyEGVf1cryC2ff4qlDERdjNtJPg5jSab0kMCpaxRKwOnqPxkVNsaH3CSXM7qL1OdhgXyoFDO5n9VG3BPuPx" ..
	"92DlBqnV5le/LxBzbrUl6BIk3fijrrRCf/J8pOzxdtqxRH9P2dd7MRfgOhxw4cv9lT3ZrnkbXGYmReaRU/d/liZVGU90J4xkZl2A" ..
	"k/MOyU1Y76pA/OL+kFq+Y2kVx5P9Ns5u2B55V+pjFJarinbGy1Q8K7Blx/fEYKuGtlAhgOVVw8XYdPv1SADiPbb8oi1QOFgBYQkg" ..
	"6WieUFm0pX/L8kmFhmTmITnRYVjwrhhlvrLWmhFmh4RqBvyXtabmh64FiEzL3pQE2RMKtp0ghFKpRLKtibi+kW4gsFLLJlw0H9of" ..
	"BxqBSJXEZ82y6OZQ/AGl0LIGR3XChNxdJuhHRxplCasZPnJQVBEt0UJqvU8J479xen4duUj/VojnriXhrEvY39iQ0SkV4EyPjkK6" ..
	"T+1AGRWh6IYVn67Zo0NlYuSAm14P9lESQIM5Ckx6nYpcLmm/xv8rKw+WtWqfMshrijNZCDbzi4uW1gV/n1k6XeNdRrDvXXQAr70X" ..
	"2bu3imFAeTBsO/Q4kDjJCpFTLN6sH+9qhO439mfrAS9CNpG71HL6+7eXudXaL9f1N3VrlFYg5KDHJNqbx/68tfLGKwZLnPBvOPxy" ..
	"5R8xlSOGAwuLuT4ouy3zv6ie4vpFZHvsy9cwZuTtyNnpX93Xh3LqDpoeTbB7IAJ+oS4HzaGYpQIGvmkTKO1Q7L3UcAuTsx9AZ9bY" ..
	"Uc/p8afgWULJKCMOBp5eE8Rajx0WjMxbwLkAPF2+6n9Y5NvnnH6Fcyxlwtjq+BZsXREGhBMkPaJGIkTsCYiJRTHZRNDCg34o7m/u" ..
	"mtLDEIKjeOLBDwXsrn2+ETBKixYf+tYCh3sebyjHft0oiZqir9bofH/xwoRwGzLc/R+Sszp4tGRDTR98TOja74bC9iDhcHw7K/N+" ..
	"yQWT1PezBQoIufTEdr2WHqwVyPGgWnNZ1mYWQO7gf9cGsNbdB0UpMOGay6EhQU+P7dthll0jX6+jwIPaoUUuoEy224HienAwquQ0" ..
	"CXAuD3qb25Cnzs3w2YhdB/ZYSqGdXK61j7rX2M6HTCo3BvU+kq8uxE//PFRWc7FpJYWt97NFRTb+c5l54znBIxtyA8e8krlLLLDZ" ..
	"SPZd6MKZy/2LTqJRdKtDXoJmVncPEU+vV48oqVpY55zG3kqCc1TqzjDf6cDtV68hDFlaz73TD2fkabsV1UmryCE9hjz1ydS4SMC5" ..
	"XhXtyYoqpp/hbJMRUfzvh3j8hzTDf7OK9aHq3yjiKfMgDXWOa8xQ1+yyYBjFCR1zqgACd3fkbVor8tNyGD6iQzGdiRV5l27DhOGe" ..
	"qMSpBH9Hhad0O31ELwAKB7YTfUXYlQhAApAXV8yVtrg7lxcFVnwTtNTcBVHlLoxu4JdmxpXj5WnxQkvLKJQMjyHn0K9F9pV/fjMC" ..
	"ci8Nmy7PRRWvJ3Ht0f6yP00IjVuA5Qa1ZNaWAmXA52Er2Ihm874oSgCjgEmrRXkeXupWlkPaFhD5CJ69fvWzsTw+AZLwF4wbD230" ..
	"j5Q4/DUhd9yfJJND5mDG/MHg9f05/CxRqqxPxs2vvOycLcMiTRRvoK7nesU9ihLy30z2N8xhMaA243LPZ8MGYeKkCCdBDaii1jpR" ..
	""
local PAYLOAD_P5 =
	"6K80ohKOnVD/gyblm7INoOkC+4RoRSM+XnZS/W8tIUBbvwE3lsxp0y095LNIacigEwQ2kj0Y89RlLZBv74F46I4AQEroh/8PEdmO" ..
	"FnnyQDhXiWGQkVbLyErsbUv/mURPXHvgnIhMcklwcKjmqtZfWJyzEckus5mPBgcIsd0VCC+hhRIyqjA/SfOE/3e5sDY+JwNn+0xc" ..
	"GkfWboTCu9QRm9awR/LAsQGh5B6+ppzkEmuyBxv6XG4wqr7qy8oX81o9ROqsaZ2KB5l15pJ93pofvHikWIJQoqwtyyeUYwYr0nju" ..
	"+9cClvC8K7qFXWg5yq8WLOUj73Qv5tRrNDa+uemlbSz6aGqm7c46NBCVQ3L80yW63u0ZhL7vya+kQrDKbj+AS5Iu2ZqYzkSP0piZ" ..
	"13au6lWvH4B4bfgI9JmiW8y++RAgkYFZDTh81VzMsO2PJrZs8tTHfNZyW5k8yM4cl6hehMkwSFsMVpLNrnBG7Svh+Da2YAmvYdzz" ..
	"MR/hacjm0DgS2caQsXO9SSiyg0/qg7C9+nfhm/4csJG1oBUwQILp/6kPR/wMBseF76oPNAxjozoc5H2NjRW+X5DJhyga7zxPjWXx" ..
	"dxP8pZfsWW5rsU2ZcWVjuJ2iIIo7YgnASergWvwvVUCH/hZqC+R/eQUsqf1LsgOUZyF3dhy/TpkZG6M6SVAafPgxtENsDiDvDaa+" ..
	"5sOD/EWHXSBcUXpIbEaimSdMXie02LuSB5lkxav6VRT9+NjnSkIi7fOnRdGdVJ2J6lDcc8dgGduo0HS2Q1mb41BKepsrMfmml4sv" ..
	"xaSK0FD1TGo/H7qVD3zxcLY0HKDcUzna6PBsRlk6yJcY+YoCt73KUy0iaJOd/b4IlSurokeKYOq16mhfV1Tq6oG7ObA4iETMngFC" ..
	"tJpWeEuihqNjGL7mfERBpK82ezI4MXBfLoMIbuN+AB/H7yEqE+L2BdBBwc8dgQE8upGAu5DX+eYvLij3bcGXNEMXVpiXqFFLs0z0" ..
	"mckXRh/V9pFYnR9bDPzHl5oQo1zfm6vRklxRQw1J6r5GGvO1DdweEauJ06o6Bi38RZNPxJK9KiC6iZksT1vMzVOwEa4bUpSJD3ZE" ..
	"MK5kF6BPL2fC63Dic8OhcI3BotHWC6JNLj3txE7EE0hDPIqD/DT1hLKdY5wv96hC6T0HbrD5XZ+WXbMJ60E2qfJUixehLUqh4/tQ" ..
	"OhOCrr0KekzEYLRIIwAn28nYLdryYWlvHXu2Wj+LP7wnjBWWqKvvAg+/vP4isaDhe8DFqIbCRycRzunCx34kMp2FpiSMhK8HI3y7" ..
	"7H2XM3m1vJkmvcfchICNdl5dkvMqVPZh8peBbhKJ9isoyWva4lq6HOIfccUzMrNqUWhx6yaZRnvchGGmHUQjI6nzGpW82vhRj7fd" ..
	"cfQlrmBXur3I0PFGP+dd+ZBMYF9p503H7XnXE0QyQQqYAriQFFf9HeXTtKuOcV7lbeCkhgn4vUKE3pfSsmNZj31SV0nQjQTG6kDs" ..
	"erV37yyp0mK/ZoBbET2gDlX7U+1K5BPG99XgsajX/7Tup4VXp129G6j9SBiYXp1g7DaSexI8XU6fuB+mvFwkPQnF1DdsDDonMiuk" ..
	"OSCkvBXBtY3xed8Je4YUOHOByhAt8O1bGBAPUYJibXj6FS+s5Mycq+Qae/ckGxi9UEhEK8SuypuxlYIdID6jxQJ9tbljSN5CEGSf" ..
	"BjIb2vWZk9p0ll9ds6zo7Q+IRqPYME0OcnlB5rhYKlICrbgxNK3KGkKDLwFBMW9KXEXsK21d11T4ywQ1SDq8hg5/oxTPyUU6Hgg9" ..
	"vMcO3rUQbzJJcETK6wQLViOMOgb2CSlKzLDXtQhOkzXjcsqPxfxSWS9TaPP9USUeQMBZF4UssT41fZyaXFgd19ELvs11wVq5OHU+" ..
	"S+uhtvKV1c/JEIFQ9tkHoDOR0AlN8ysc5WFfSvt3k9TPSAFDOUAAbFieo6n3UvStCPl30TqiqmkR8vkJoX/S3cNT4fK2y3qD7LU9" ..
	"266FzvTadYMAVjPWH0bZIkJsm/eDZ6uKcDwkN9H9VOjetXBqV1jGHsHagAo/oSIUcCQTVfyVoXQD4haDnFdTCPfXQWrEjLSMbZ5Q" ..
	"kkge749OAq9udPJVL60QKVqJHnU9TpcrfqXrvl7LhuLrUL/DG6xqjNsL5GD1Hkz9ipaI8KAiFW1Gom29b+R9P0T8Xb0eZsYB3hhL" ..
	"To/2eA56t7a17m++DGZ/cS1+Oo0wqeDaNT/sj3ygECRu8dYxYoq78mDQncOvnmU2W6qwfMw1bVFwcLY+Ulvl/fTLF6TTPFXIexCE" ..
	"ydiV8q2UHSnBR8CuB9D2elB3Wz2CrjDtxEhZ6JrqHAUeBTKrVkzYwUab3QWlyDxw+O3p9XO3KyuZZUVTpL7CryIGddZ9eAdplHtS" ..
	"/BTyQ6ZfmpzDxwdwpEgE7FCtMwTKlyYT3xatU4zXod31RO939cD6nr6N1gKYuyMMlyFmof8ZfnR6gzAAUDuW+a7A06ieG394YmhZ" ..
	"xsLzYwwe3zfohOWJjOgZqRwSVhuP1u5sSJbvQ5kWiYNnaC7On4m5GfPWjOTunkqz3BYxXsYwm+K3mHfiqm4VcT/NGabxuHP1dxFe" ..
	"DJDBwIStM/F2RV/zzoOfgSoiKL+PuRKzasGJK8/2RsD+IBLhaETtUD+W3AB/oxrjhg+f1fukf/bCdXiltAMY/f8tRzVXLw8JpYBx" ..
	"r4vlm+AvA1/FPmaGg385qdByyPDAzrbuavq0k3rlTIgna4Eo599pycS5+FOxGepp7MQ0Wq6wvKxTzvFB3msnVcxsN4IfuxHCSA8M" ..
	"BDCLHdT8bXRs141h8BzjzM7z1Q0nNbt1bkyYugR3dv2LsD+4AQlmKqy9BXK41Ig6idi1KDYUSSoj2mPJFUbuq4TBmMmHe/U/9wLE" ..
	"mdOVVWUUyP04Q/7cSMRBZw7lekTFtY9W7rf+fq4ckGP7WkebcxY1KtoIgDMR6lGPPH/G2BCDOso4JwPnffipC5C1ExVCG2G5Fhfh" ..
	"yJtSYBBmSuqxY57VTSp9iy5nbp8pfeQdb85exVRqgPG/HE7NX27DETODM8l2Y8E3okNEt9myYyF3RNR+jI3+m8YgsGJe2D9OX8FP" ..
	"QXsg/q+6gHY3XfxKPD2ItXHR5QScNYYzyntfE9kn7bN8hJAj1ZtSvGSxgppwOTsTqsEudISOuiKytHqDyKn5pnHApS4/TbRBClWx" ..
	"JyWnPDSsNjiGY+Venly4ro/a9lwT1umHY1IpCZhTx56NWahKqQtaX0fClpJkZUcjbX2k5XPmjvsLeJ++Siov9e3SEZWrinJJBOQP" ..
	"dNN+kLgq6fUuJ7yXsZaEtp98f+KFnf8ViNPJRRaoVvl061VFJVhdabwWkytxquP0+m1iDCbGALEoK9pD4UKitq/iUEUKx1zZiZDI" ..
	"qWJ9RMjConzEm1QGpnPxHLiCQiicWOncLb+jMqgF+etgs8GzovnaSqKpU2hrSXQCROk6W6CDL+5D2bdiCXhrsrIyDTgRaCNs6T1u" ..
	"aTmZSZ1i7yYijnA0v3699mWZmpnRpGwbzsyLSyGLJQerNyYXiaE9KYQ/NjrNuOYKkIbv0uHJgqmhswbwySPlj+QdY0jsC5JuPShK" ..
	"mMlRWdAWDFTEPMbUyM4lL0PcGeRrqTbnr1qTfh/akCUtdGbFvIrqfPL/gZ+4r5gsaeLJi9pMT9kzJRVPdV3QT7hwZcRfYQzdP3fp" ..
	"hXA10d1vLhMexEvlLkdrwrpEDPfe7oeP4XybbSBwDedeRNnS3FFtWu5Lv8pY37xIZDyJSmbLBBb/TxcOS9j6DDcV2Mmx5TK7mcIw" ..
	"g/etTwGNTs6GbrUQytkVuPk6hNgPptcmVmgAM5OomOaC1Y5RGQ+Z3xzDMM0zhRERcEls/Z/1QS48HWDhgsw84TXRPA9BRUHL9L2t" ..
	"OvZBZ5FkVPAwUw7Qdx0GV/kMZaOsuxUB5RZvjMB3sZid1bIZ3+6GHgr1x1a0nT+yfB4UIISSgvMO2ofG+9SyORBoNwNUJZxdN5mP" ..
	"imwI3A0QP2EptwmdMbJ9vQy87RPxFuDVNu5Nx9g/2qoDSvzAsYjk/lXSgZEcozmGA0Xytdkroz759Ikj1KazRTzItxsuSzCkj1LU" ..
	"z4mExmi8a2C2MSgevX71XwP+6THZP8YTEKri6LVf8aGVQqdSykLH+E3aqnTcj21UK/QkMlS7ro/21qYlxqc54+dH3MJH9cUxkABe" ..
	"vAgX7x9Y3ukypwlXmb5WPdpvuGfNQiw2bJVguAco+i24WEbf7F7N5TxBCwvweYljgQSwZSgpb9FEFiLhKhgB5j3FOgy+UUr8l9T2" ..
	"2eaNcwEX8qkD8km4A4na94JwEjU2Yw3Xv+8dBIU0gVLfFG2oKvOCND9e0od+S4O7xp6VYaNRC22gbIdgVeJKpoipIPb5Ievbh8cJ" ..
	"UX1xGO7uOGrk++Iumy3lz1RTYBN7BaxZKgkucwbrOrX4McNiuKECrUzcKGpmb9/W451JAcEqfVsxfLkgZgO9XEVOcwp7sbYVS4Ky" ..
	"ykgEFpYd6GJKY0uIW5SEnO4Bq0XWE3xuAVcc1XjqRn2s4bmRtTif2dboev52f2ezRLd2ZLStJhm4WAYau3L+Qi1V8+W2a+8JmtZU" ..
	"BbjqDkbpWRmf5ApwZRoaSbDRIa0C0Y2TEM8EHud5e6UgiBn/0uDh8RmuviXigdNSNtE+HuLkAwXXh+/RMPHTExfRjskwPRGXNjVM" ..
	"buKOHuLmQeFjH6u1X07mwyExIPHI5Zx6mvOBpM7edyOgPytjhcqLOJkm+tLPgL1bHs4Ez3tOu0Jbu7kL8QHzUIqg974VmDadvoa0" ..
	"suUDSPV97RIn+DYj5KKCEVXYdh7y4cpJlIgJGI54NEoSmEbuXVnWqKb/mzWocdZccYv6ehKmKvOpd5jwKzEie3CfVG3kEv7vJUlj" ..
	"ve8Z0hMQyNgrQNhM9ZL1MkQ1gXZo8WAzUL8tA3nulrvysVWhl9pDrgmw1/WImEWoGG8IlvjbpOF655yYmdi67Qh1EfwtFGRX2AVU" ..
	"eqmeZem2GnFG2cZ8YL6lX9op1Ny9mUcT5l6BkBw6wthz3KLBgmO8cdIzu3XO2DOD+R2YOi1kYwvOLRBQu1Ds8fCfhFje1n8fSJE6" ..
	"DyOX/rTwqD7EsYry0rFBoogsVslrAMgA2NB6lt1Fn9FJ81Xz8WZ9j99i083BSCguf/cvvtrndUvckw3LWB1q5mcUJl4k6AK8OSQY" ..
	"/EO4Bl335wMg1rBIDH7YE/yznUJKtTWIisdWQrzuxZHFJpZOKM6DqkjgUoU3l4wSCN5iIg6EebSynJOw4f8ThTl024Gn6NIjePB2" ..
	"pTR77WHGGpLfazIE0zeo8MNluEA21/mUkOxeL2uc059ctqAC0YJIs0F+LhR0z2VjoszkyLunT62cNx6HG5jj31RpBrOswb57Lesh" ..
	"T0jtsV1XyYt/B75bzruPTvxjL8JnHR6rwqiBRLCMSGmfagpnNjNNinKu3tpCELC2XunUMgzatBDfpnB2HgVcp7YMLEgzjxCdRBBS" ..
	"3WPHz3cSW6rmGR7g5lcmZ1ZJsx8rGyka7Yp3p9gmjTx1QtdMr/YR7hyKzhIEPS1K5Pxzcm1pC9f4S9v/WUSk937tfXkgaAuiKkt9" ..
	"FqoTwvVSf0ZCDLkWT7xcHu9T2DUcvlqQryRWrxesAoVy4pzmx3AEFAxVX2AkojjVEn94DnjIRtIbbVAlFr71J8RnC/Baand0y1PL" ..
	"+i01b9Uu1myZRYZffL118SjAqNktc6cT9eN5XQI7B+DtW+PpAS6iaXgPc0URUe5g5+mOo2IUON7fZH3zSotQsDxS4LQB+skLeBx3" ..
	"SQveox9pXBGagyV5v7hVMyuknxXtCp6vVxhGKnkx+8V8s60Enbpf9Y0AcUOZ2XgD1kALJVlEgQAQGITU7ktc3URNW6wBhufpu5ph" ..
	"3jCj3eCYvMyTrEM8gIpqJHNpDoYvMSrUg5XHkywyO3IfFneAMQyrIM+0VXa3zDlnfj1NY9qyTOvbDh4RkIBnjyA3AeYRiEhdHqhK" ..
	""
local PAYLOAD_P6 =
	"ITCQe2qCKvFOlYcPaaoVoYplY910NB2BG0lw9hw9Onz7mS1vFu3yIB45QbLazb3l3Uj1F0sPCTf+NDqxN6rt27slQZXhafxjmQoq" ..
	"18DWrcDOgPmHB1sTZllvfa8XQKdrhDWTM3KZONxVIlFmmQrwBywmpF/g2Ha+t3Lfre2NN3yXdQJIIwbXBTGXNZPLjxJFXV6pLo8C" ..
	"1Psvu0ox58jevrTpcF2ti8p72XyMSpCzm+6dfkC/3I6pQHnELk2GH6xOt1dvXMpVYWqB+BfiXE0ItYMmAby+skZbktTgZAvH0jEJ" ..
	"imcFlU9GwxVPdyKA49ZWQOo8vwc0EEsB+2QCNPfV1w8h78h9m3a+qu5fx/oY6P95hVSE0NJA+WTHCotCPmTD03Dd/KiHFVexN8lH" ..
	"45adU71+ED6Bb3+UQ/FFbGaNcAeatVy9F0HFdnDboGRq3ZsJIiH2Wj0BOwn3ea6zqJN+2qiOXD0WkAK3rqws6bhjCAGFReyeRxHP" ..
	"5y/SIPx027Q2Imth8sN2V8UpeiU0nUzpVQfhozbfvYbA2jy7IU0dIlqqhfvle0J34sVQtzhVN9hXDXc6MA6NLnJo4sCLgXuiKvN4" ..
	"3XzFu10WW3+w3Ch40ays7S29q8j0DxS3WaPKxCwNMLucqTINCpU5OeQENtCEhx+KJxWEGRyf6n9yukUgno4XgY6GB4rOIkl/FCmb" ..
	"D8rA5/d3SXd5GlsoF7KP7y37vae1rZ7ACAJQwVybgfXqktPchVqDNOk1scwnvO2vyLU1MbcyoTRvpbZ9l/qBqNsWu7snQlrQ2DfZ" ..
	"qK+01isc+cB1jNr+hJaG1WrJM9QAeDY3iXruNstkJ9Ce7Uj8NeiP+1y1ySDUQ0G0ZpK+GBqBJySwWgWQlV2IPdM7atB1Y1mb6qbo" ..
	"ZVB5pjJqiXqPUQ6WAepmgT86/iQbkCRbwT3OJkwAYNT4ufUUfXpFDUZ5KK3vkTupaesVWWKzRIHS7KaXE3a/pXgDcCURDPjndyqu" ..
	"GGZlj3AKSxRzn6JQtc8cFVeAhQi0yzKYCJq3RkVpG4n4XEZdBydEV2NQkExQ/QsidtkCnwFcHbtVBuVu2KLOVuwQz3pytg2dsKrc" ..
	"Dy5coSOuX800uOEe5UOMu0NhSQljf1diuYY3lLLQWsL2lgw9sFvgsf1k9/EPjClDEiytrxAE63HdkxzqJweBqW0aOog44QIsVmCg" ..
	"SSBYUY96xD422i5KY04l/6AZGLHaRTE0ct98R6SloewFFz+/OkPrvIu9y3qc41eZgt3+LoPOLSn8kBQCUUJFnIH4vQJ0+5Ug9iCb" ..
	"/Wiuzig+PCpZqH3HY2tHv9+XIfBfBgCrA/Nk+P3m34rzijcdaip+pflDo9OCqiiUOOXFFOH5KtuoT0k7NDP7++xSnC+5EQlT75XU" ..
	"X67ybUa+unkZR0qf059mlXRJS8ITd1G99cI2BtOa2TOQwlinryArbGxZRhjQJZDihVOTu+RtQ3BJqF2FYrFYZoO4/wp+W/rVEsxB" ..
	"h3r2lSmC0CICm5U+6H3B7G3gO5dJs+d11d1DbkFwGzUe08otNkJQdpJ065XQsn8p2zbPM11w47+RFt8yHp4rN/mEI6yQCQEcYdw4" ..
	"kLQDRqflKPAPZ4rwaJabh6bL3aL4pqtdMV/Spioh9pNfO4p0F9JYy7qGPfreOPskyyWLaL/Jlx+XpPjNN2L6c8JNXCWfhcbg6ZjC" ..
	"7llWXSR0K+3xslxYl/UuPhtLU1IC8O/UJr86hVOVwwTKcaIXb3FwdhzuK9MRYPAozcEY+ngPobpowu5TSHiSexC8ogtqOOwi3/Y0" ..
	"q+atDdr4fe8dg76/xBaAzsb4eBzXAPpIwreODCCMzhz86wVIiNDl5ZubzdmFQimAAQCWRKVYLYzFVeiV2U1Fmt1g7txVoWUm8uXP" ..
	"THaXsEVBYuahR+BiRPDrV5Gtb8ZSqj4RV4XnFkTDWV/IOqpDVPBKoOfYq572RjL39MG73N6TvLY8wSnfyLperkOEeCknlbPx7rw6" ..
	"jLD2yYhKhREXtk7ZWTaPzVuBtlYBYgTMu1geNW4uFqxJvqSZttd8I7mPXv8rHVOcY35lH16yIRqycIM4yB97RfhnHWL+sxCXTj7g" ..
	"2UDLpcr7IUnmb9Ui6UZGlaUDHoChi/Vodb5UPC0hbC3LL+CUTANaE2MiFqpdFt/PTvztDxLoJlmDU9K0XlhxCyUlgBMhcsl+yDUo" ..
	"uOL8CjrfHRgEmyUVDfOt7OKHAmXzPRG3uGMOYoEAWamGWePQZp7Ewl/mkp7oSb1tavIUOiaxaHJNIseWwtVIoIkgRm+3gDnrRZrO" ..
	"Izv3ItLoufeE1T3OudceUIq9Xfsa7X5hFk75O0B+s7RPexxfgE94nYik/R7MKEJ57qL4bEZFsVuH/W4jBguP9sWE2wAkXWleOJP0" ..
	"O0xAFEQV0iTGUIOufsOEra+ar07IETFnllQ9D9k6HRiSB+I+pjv9yFDTEu/N5Q6V91lkYhTBxEUPNxKqDcz/2/YppFCZvRwv+QlH" ..
	"2h00UBm3wT+CUGew4fi6HUBIhQpan8S7Z2G0P9Pt8x9LRqLu/A3LMcSW7tKrJ1KqStgg/6pjTPp2nd1j28GyLJFt2sWiBuGvpXkG" ..
	"F0eiKtHTRPJ5BQMtQCII79PzgyJgzpKyRxYasTi5DaWH1/YDDLYHWSMdYi3bBavDZvS0/iDKti/0c38LaAbD7+c+nHEkl6hWsqrQ" ..
	"sICC+sWsO+Fb8CctdYNWKvwvyEErxCf7v1rnDcmfKVqtgDZCZw0EQuy2uL0Q2WQSXYKjtZxsq2yudg/MFlybDdW7+nDneTPva4kk" ..
	"q34FWccit4z2RjB9nWKH8O1AzXg9exJdh6//Kj0NGbAtTLQMzbioZow5M9ijRHzjtEtVEmqbbVSK9Qhe3+kFZxxO0qj6DBHzFvWt" ..
	"0AeSRwjI99hCmPBV2dbqqEWWx82sTi8Ok/agWTUBlOSayCwRemIWaOx2uGdTxEYQYpIFQZ+AU2RxD2SyAMZeRARnSHtzyAoZfkdO" ..
	"Da/OXw0Dpf+JTxdsSVwfXfi8YGRn2VCn57Cw4WLNdRnr6snC2lsHjgQBrRLjruxn3aS9mn8Rf0CrH8xUehjeJJYZRoCv4xlce60K" ..
	"LtuCusiKgtZ+NxBQ16x4GhZhzwdSIgNoCqC6utt4zx+z5iQScW2Ky7nODDHjDDqtInHJRVa8oDakqrFRWQfZl7j+5CJ2eTTfwysW" ..
	"3CrRMTQ9TCifCDCN1lXcE+BlCVxz6KJURst3K/6R9fOYuyVwIH3f3o7pGhp7g6jN53igGe5lIzFbhkQ+5W8nLAY1KdFWEwCBGUc8" ..
	"GPpdLGKS3FYwEj82qlyjTjL0eRkMpE2gOUxY6lwsE6cDFIxORoTqIkk/QBkOtwUK8h+ZysrYCK8Gya+AXIEH2dGxZwFzecBDgRHf" ..
	"+EomZn10r87IK5fnKLfNM7LMU6Lzrv/lJyYO1HcRA79ApLmAB50qgQkHo0IQusJYWlhRGkaur6dKtOCBeerFyMgPkKNe018bktJ2" ..
	"eZ0OsI1ofa9xHBU+QKaWK5FkFACDew0/v/5r2FgrOJUdvAbkYj9zgRaL1Dh5hjNp7cZHSg/IF3mDW5kYcqTt2bOcZwZTxG/vFgw1" ..
	"/5EKG/Ai3cHYXJRLP9jXmaE1Kx7A0Nt0C/aGQ/KPTmycONQxSXAfT5z+KlkCEP7A+GfJ746t6dGtgKYFchntDkkBb8C/+/++YKmw" ..
	"VDxe0yNntDlRFIJT1vvak5B/uWLweexd6Nw1Q1P9Sa3KMWTcVoO2bGSU1fbhfZUWIGflfDQhH/FSU3MDYQ+yndWX9LKGnb1USZ9V" ..
	"sS3ZxdSfecEo7sadYRoXTXWGxWAq1bV2P66y120HYUqWsNVRefam8fTq/YSTGCommgUmeyf59cfQM/XbEr7qccGV9KJiNBWgqu0d" ..
	"QkV8AOA5vESIFat3kY+t8eHa0fzF8KACUWhCqflK44RSBCiCxri5AcHwcu2jfQDOQ2jCvYenX3TQxONCGYR9JS5cIDBiphJmqZ4o" ..
	"RF0JWaQIw4CMc+GhWRKiw0oxBEBnm5rp5AYCSgGYx7OtJMEhITqsS6z6ld6gFKdLkC9VR/gGgBOrJt/lWrgHmUVbwlYx1G0BzA92" ..
	"UZWoPLlKTVxLL1j4ZmWhw11kinW8XdzKb7jhufiZ9q4UORJdp9PYLCJnZVzD2RopSGY90z0zpuArw3/CfCwruFCqR140wMPAKhsB" ..
	"4fXGpjgbjl0GUC/RcUiU4ik4aS4ekcNnMkIjXIOwvhSMgADGEorNOEMTPxcS7WO83W7b6ufViFoK929Ewk1HYrMYo+4U6ptwxPNC" ..
	"TPAqsock7YnLstbxQcqvsi8VuLX1UQDXly4oF7K1iF7AS2oOhQqIH1Cw0nbkrvP6A88/ueheabRCVnY1Wyg6sOI7KjJPxpUF5yhj" ..
	"Rb/sz8LZtvAxSlF+1KrMA/CsNO8dg0/5LmLwl9nlJzthuNQYlYfGQYZy/mVnWw1j8Lr8byD+geviPDppCkfN2zt+GbldS+I6UsK1" ..
	"cinYKg1SwI1hBoa6WXF7NmuebnJq0lx91ivcUFXvnQmNhmal4tO3qY9tE39MMKLVyzavi+SqwiJKRo96jsc9gYP3xSVTBvpxpdMA" ..
	"MyigmNadGA96yVgzKiJ5D9HO8QkkWHcRCPM1mIo+n1+c+3zYwlwRRVZk2MwFq0HFi7RfYnIrheJUzB5dsMtzXfs8rneIZhYFVvdj" ..
	"Fc1axOlg02rFqtEmtzyvxdvowWE3MWsThglwbYCwQTkr36rnzwoUQmPuIgIPhOrnxM73+VL8/iINnsMhZKein9W4d+OeOUouo2+6" ..
	"LY1yG+VRDkSnTG8U1CRSBQ7RxR+D6kG1dhLZSYXJBgjB9RAVMvocN7Jb1v8T/v3rauq8vGY/NT6V66e++sE1vzPqG5uUzMzUF2Uh" ..
	"ZH5+uPyAs5DFWBEOKGcyeG6TxQsVbxjZnUzrlZvqUdCwR+Gy4iL3W8D0ItG7xnvJi3QBw4p+QQBF7ThWVaweejk4Px0/feKvq51Z" ..
	"SCo2TysP8XS9UQbNE7mTRbOT9c+vO+MuR1EZUlaYRDli061iNdQX37hs0hKG9PGQ9ud0LDCUx9zBur/tRAkoT3n6z2DunFnPMbqk" ..
	"9fWkZH6BfThBvR7Pa1z7pQ9Us6xfB1uHLLV/AGBmeYliByjcdGiYkM4B28NrEgdAuQYA9wrrq9BrQchzwgr0eO5hgivokBAqqWqy" ..
	"7FdIXO8TJMAYB+nAd7MAib8r9HriBrWWeUSk5YCQYMZhhdIEbJuxuwDyDjMfgsQVdEkaEDoVB7y1kjS0nL0aCIMTMdY025cLNU3q" ..
	"ZOA4AU/UnXlYCwjJpRrq+HWDTdSHxrAtlXj1ybZ4WXXZClMKWlwtdHjwEDXrglsayd7tB8XckuxMJtGsAnCVgWvTbDyIPhRImRhs" ..
	"rGNUDS8tmw+0kues95+b0MVcRXrmXedHJo4TpFCaAdw8sclWGa1w9n4ceKWPeTIWm78dl5srlwk2bmgq5qaVAfR2jANR/Gs9CPu9" ..
	"oldJ6lbNGh9i84EDUSxUQmnWYQRg1yKW5H4DWv4nc5ldGJ1NSrud4fspCdNbmze65RtTf/F9EsPNHHe21zgQBOkKYuzc0wxnKfd6" ..
	"RksE8vNS8VzDdTgBHwSnuMyQSV9tAEZPypWyDRQKwgI/faar/zXuDvwjHXQlZ8hZNRYBl/mQYF3McQ8IF/mkTeWrnB5MY014sJ0b" ..
	"KIHPCrauKsFmm2148RV4ZTdD+iyFnPGY7LY2L3iLyv4CSPAgtW18vmlTz/pvEeNrE25gKXu8HnypyDbFIf6TJEvSDvt3dXq5fS9G" ..
	"Ndat36HiT9+LDGc6XLnM9X/k2OzIa0G8uIqZpIVzn+p4/gs+Vr4seYVysiHIbBhT5+3I7K+/k/W5yLz6pUoXGpE8cnklZUN5XXWQ" ..
	"MRfKWO/tZDecT+ffwIiVBpnnKkC+cwP9BX3vaAO4yAGLgPV6bxAw4RtmFe1R45SeO5v417FVWR3D0ntUDgO4J7ol1TOFdCIz10E4" ..
	""
local PAYLOAD_P7 =
	"QcyJNUs/VSLJzbQ28yizBKpq0uk2ANkcX2gBOi3eQt90F9A5VcCIHFCv9Q1BOnxony7RAKPv/MrrkejvdU4C2JpvBvnrllOq6SpR" ..
	"2BQk1Pf4+D2yYGzHjrlxysEeNDj2kdz8g/412TX67tnn/Kqwiseki2hCqf9dMEBbdy3PzJxf67n/HfgFWJepx+eoTGX4IpAtDGRa" ..
	"joAlSlKIKGZ5UO5iCB74Bk9w1zA2ksSObYwLEtRK7eJPqdYtGpH5CJsqxz2fGGU756os8ULPFnOZNUocHX3FeHGjCWh5hTOwRRW1" ..
	"N17/wjpODwowRnL3BhI1EwVLobreiWK8lPmTfZmVFVV4bTBNX/Z5i5Mx7jwcVmmtCfFiPX1G4q+ARpRo48CLpig/UZ2HnHTEvN9h" ..
	"O4Dx93IkgknUwQCV56V41ZDcU8fizYrqOuZHrE/KnpqBpHjaQ3+GFKZpgY8hfTXqOyJZikZ+fFGKIfDoqsN3sleCfqEiJ8XYGeXv" ..
	"VUBRYhaGZBO+Pk2rABi6/emQTYup7Cfih2pJfMisgSsZqSqdELGFXRZOLmhkZqXZ6JqZxPhnHlhdjfdJPANJ7es2KGmydruAe6BS" ..
	"bX6wHf4nXZqhtTtQgRBEnkQXrXOIorXzEZUu78zKVpGsCA3gdCuycqnFgVuuj53kdo3VWkH3X0r8/mDaJV6uWTE6q/Ve0eft/RjG" ..
	"0sw5kWWo5bc8OzXxFI8HgZ6WWwgDcuYwHA8a9PvJl5FvxUSDIOqjWuzMeBDd7cz0uOzelRk6HmVLjdAq4t4EmYfMf5V+lr2EzzdC" ..
	"mK11hOBrgpc00T1uwrOmPB4+wpT23dX13GXPiNYbA7QUrOKzeJk7AWHBnhmTchLabHgttjOiaNPxU55S45DIrWnEYSKi0iAhRgC6" ..
	"lfim0fyuyBOyunlwM6VnMRD7zR8DizzgbMYdfFc4Zhg/0qxoPMFJtUuKviegybHXHWcwyDxXXaJ8xZTwIufTfXbOntiwPh7zabZ8" ..
	"Clw2cugfsZA1dCrJ7iShIM7wo1gdBotTOqveLMHW1wNpYxQJO7kOUKKTgL/o0sZgs4RuK8EGwOAnp/c0CWCViHBNjgHOcNuumkyf" ..
	"uxPnx8votvQtb0Otl2rOfQ0p4VjRlk+6N9/pBPfOFpxdA5B1qKqY4m63G+5h8pAHsKbNjDns2kb24LziWb74crwVvQAvdzCElpaH" ..
	"u+HHUxacK/uLZ6MqjXFun366ktrM5ge3zEt7Pjqqh9mSKJPNKfhn9RxXICvvhLIAwYITOnF3/6SdZMxRQwgeZ6janhhiGAE9/PI+" ..
	"n0ut+jAboOareEpMsZCFgD+6NgMOLKh0oW7YD9a2CCX0g32NxyGJetr0oKT+8AKVGUMH+w8A0h4DqpOq4Qec0777Pjoz5Ul1VRK/" ..
	"u9SldjABfkn1XKs+1iBPsZehRnRLlmoHjYv4684WBS9vsvgXSLj12UTYE2umHbv7/6NkoQ3qaxlesNbYhFUdlooC4kvz6pbEKPAu" ..
	"ORpvk8cTeX9oYwZNFJSAqvyCp6i7ywvFasehZA9jCfmWKQhKiTQlzooVVgjDRq5pan9bnxkKAVgveO2vpx1RRcB7S4hm1qRC5IOi" ..
	"62p3LDsphuSNNhJP6Qq1H9np5/vDLNvx1MqCZLmp90eNUcWeb3D6hszogQQCFyZrVJFXiqGedtVU691sCBkPfr3rmheh83Anl9n6" ..
	"5wBN6fLQlSbrS5hJkANyz/ZSrJULyHVvZ9kk4AWAr3dmehY7PeckDGbt4IVtyIlgBY7o9O+SOcr4sFuudPbdy/DYDoYsXzHCFIhO" ..
	"DFnGEKyir+s2lSC6bnUosDt0Y4M0HJALQqiZnIXlmDklGh11Mg/QbXe2CxQ6yAeSyUhxYwgq//Qnb0jzMUEdXfOziq/AK2NfqHRM" ..
	"ps0gyy0Am8MP2UFxkZPvP7RzDFOvwvEqp/EPLO0iUnViMnuO5ucLZ0zsT7Qu40xoP6k3b3NHaPt7/Cm/0Iff9x0R0D4Kd9stPRQ6" ..
	"0B16hroVqTE3+oOySZny6OQ4SPZFFmR8xGfGTXYWmEQDWoyvy6cXJ2el58UUMZUcauIeVIiSwTziZ8g9HhqVZ4thfOXOkSB/ZEPD" ..
	"RBebJwPONYhXMclqxiFjOw17i9N1sGibHzZaDvccVjrPzFhA96HMoxzopzGscko/4cuVzBYbPek+2LFRkf+Y6Rh/S98hiKCXK8Uh" ..
	"mU9RrIgCqaVPzY9+UbjzXYsvDIhYRKokqGQnvLpubx/4wtULEl3ksStqdFvBXrBdY5xSSoCQ9pLrNeFZZ0zW42+3J5EeAor1mVir" ..
	"mXJcavHsMJJjK5An5ar6qHpeGZhTDd2owBas628bfbEamdgHiN8MNKe33X3HroX0WTSfJo72uzBs/avmEAT41UaR2X6cTcMrFi+h" ..
	"oR+nywC/6qj0Pm3BuAOxKcusLv3vrXL6GDNrNV3J8nX7ndYk7TKilYDuVUhx57CQ53n74565eKOp7jrz5qrd9uUzEwU9uZYclpAp" ..
	"5K4botCgr9gYH6UYjTbvhBGI8uPRf9MYCllaYhHC37KJ3Itn4eL/5PZbl2mx143/o4iCfPY/uvD+fgMyS3DM8+oK4f2eFh6V97yh" ..
	"3sFt7s76sVkAHfc3putwIcaF3smIab3sytUtAimoTVAQ42YY2cgbxYkwdHBsfmUdY0d0uKXckhLftexEkdqVQfkqyXs96/OqU+Y9" ..
	"v5Nf5APA8abZIokP5JoYYhy0SagdfNjI0OFI579iQ/ILgusGiRkPkf0onV4dAbwiB57JasTCw5cOvnXjmNwGZMHexADGg8lq8OW4" ..
	"JnwFI0Nq4bc2upigDl1Vn4fdI4rIHurECsYhyvdHDLj7viscR3sfQV0Lz/aeJ7QTBqi1C9z8LnttACr288j971SsJpKw2TTdm/M9" ..
	"xRzXh3Bpmroi+H9m4snJ7drMEA4Kxj3+T6xz/15j+k8tXvWST1DShlkZlFxTf95P6rTRvupoAOkFMKrmzAQxLUEqPrA+9aK+Xqbq" ..
	"W9Ki0Z3nWRqN+0DTCju0txWUXis+B6RYj++xMun6DdkByfbeKL4T2XYHi+pYp6Uf5h6Cfjm41mMqH/WyZ1JzE8KUtzSq7rSbdcOj" ..
	"nmlHTY4aDw5SZY28GQ0wtCTUsPXFphE5oGJBW64QFqmTf5OgEWsPo3c00x51mjEfmdfkKFEBTWdsxquKRDDp9Yk8994f6iHwVkUq" ..
	"S7nsCyB+8JDgW06XHHf500XYnxZM3KdjYDZjd2jnq0+6cIZZVsXwRGmwI4EKZrUIuvNxUINWYPwAxyA1tBeW4rRPA78HmZxmCpHf" ..
	"Ncngy7tXMcU3joaa6Gl+mStdQo9MU19tXC0S90tNLhT/lqyCz2/kQ4OUliptzWBQC9tlRoDPYI6KdMQSBICudkJGDdUaCHYnrDlp" ..
	"lUd6SOZ4Mk+wtUAGQ/VSmY4vOPCdvv092UazxLqFqfA0Y3XyUIYdZ2wwLUNm4bN9FwggyeVxZlGKrXmFJLO2bYs0fq0COw00AXR6" ..
	"izyrvoGAHCpymKKuh2RnCOCaFhggzOkPz3K8yX6ZaLI1ZwfZ/rT+QYWWKIxKt4yTHpU3ebqWqwzbrm9JedZem+BCRc0A2lLOc2g4" ..
	"+QhkfWC7nYHA8qigL+A89ItdccGwYO7H7IbKhJdb9Ehp/8OFysFS4O4OU2t1ZXmujAvQstdZNrZ3P0OVyTS0Rza5Vi4PFlgaeRHn" ..
	"+BWKUdK6priplML+pJnAmh+ovOFiAfpMqKNy4WmSB0V+fHkVLaoAIu8KUWsUcT+MoEo7IOx45aXefF2Qg5xQc00onHrq+/LrBTbT" ..
	"uF4DsKvW80FdZOOMNJrimWaF7eptuSBLFxf+An2FIbpP8zItDPdG2xpjM/kpXSl6gTBhMnxOO7j32ShpjthB7Gri7TbjgJKtMWIQ" ..
	"pqRGSO6lXHxu3rVICDon29V5PvpkYA60i3I1/cIbc84U9MzJ6XYTO4524Cm3b24uGr+qX8vmlzVrt5f9KFBG5S5YSbcaDU7bTOZ7" ..
	"5hHqhgkMM1cK+qSRFgkuLSPEk1x0TlE6oJFGRsNfwEwwYI3HT6Eswpjqz/VSt41Hsk+vUyxv856nPwv+YYC0W4D4biwCZ/kWV/Qq" ..
	"bXcczdpQtWNd31ho2NDFLeG00uSAzq/q35+9lmeRB84mHLsut0nvZFP08wPFLEmadYuHxSUhmkGFkxNmLGwxWQrNfXX3S7Tv4jM+" ..
	"P9rPnl4DrmXK/j0Dtg85MumxLQQ7jS26Q3NloUh88IgtjXkrZMW9nzESaPwZbv2LuYTEctmSZhyLV6fFLO9hpqqp4JPGOb4VvmTz" ..
	"o2miSeAIHA6w2rSxb1cRw3DTghyaT/aUeQblr+PGbd59gZws2qqCHgMl9coGB6LmaElhCmwJmnFF40Jm5t0WqqsHg/gZ0KPjqu6B" ..
	"d5qv7MN7fpa9cCV0HFe1WxX0t0XDgo+wLfIVWA+i3Gm1ReOmC6A2VsdQwhyWaMk0MAcddwmhH/XjUZyWbCQ+//hOEfM4iG0L6mxE" ..
	"zFPX11T7MJc5KQdD9LjM6COko9mhoCMzMtKNHQCi28oOQe0DkTZp56Sx0pLjifRr5vOoC6S8qG+7b83Au6pQIwyDDDiLXVzVHLwD" ..
	"GpeXyoBn7kMWo4iS9kJNGCzQ4EodHCuAocdEqYZmmlcsxhuzB0g9MIvOSuHZKxB/atXMIq2DWddjBd5Q6/YEOboufwaDfoCkM0wL" ..
	"43oltS+cHPhezB8pyZyPBpVjRVNe6m4NSb5hE6p3FE0+1TIasfa/Ea4C+UDKytqf+Ytp2JSf49KnKeYvj4JlJ4Y5eINwXBNiTa+s" ..
	"yubJri1EnoTWKN1pU/DZeOW2Pz39pFskr5u5qS/ypf5KDjeww9q7OqaKV+gRA4BvxKwl92N+azyI0kDTkZH+h4Fw5WZXbk7RtU6f" ..
	"bI+FYJyTXUd3eaOcozp05E5JHnoN/GYtdMum1iQngFJwE652J2EwF993bnqhgeQCkCXLxKh/uGv7IvDdPDcrqDm+DcW2WIJQn2fa" ..
	"1AAi3HFT5s/ZgDo4KeOm/dd6TAvXYcq0l0Nv5NBgSmZxgN05E+6faNLfchIjd3XPRtaqQnRIqtebzgbtIbtlxEjObvd2Emq1HPn4" ..
	"2V3rq/nIzqk7XfWLsJ65/nG9N5PlciC4w0mv3W8VZ0GgH7cDxNgvjVLaPT5GRHqlJ2Udps8rjYsrUO9MRsoOzUy07xmyzRC+JuDL" ..
	"S/XRY/cs1/VGzK0UB8Kayv5m24ylfRiHcwc0KVrAr8p7VSRM4RkvkULakNDnJCZDd+UedkzRF5auCNRD9jGbXafESTuKJafTZ3oh" ..
	"SzQ7G1ywLWOOk4vn/ZbYR7NgdZzY681LtP9riJwmZ8G3O4opvTRMJV5qf07DKlP6T3wolRKZJ2FhE61k9CJTMXW+rhfodjX4H5QJ" ..
	"bU1dhaikxIVeZCVcvPelC15p1W4Lu7pgg4FgdCSKYjJ0YVhsxMjbGRfw7x0jBilzab+sS2yGzeFcXdTHh0m/7/YBJEl2SeusI4mW" ..
	"QIFAd9r4Qo2Ke7MnZR5w50Fg89Qxldq2HxRBy3NIQdR3OawsqHF+CXFxAtot5b1fXlmaj7DDUHh5yuZJb5tbS90KwP9IbTJlBfmZ" ..
	"OP0CMMbrYJfjRnd11OM0EJpbN4374IVPEbSIhZxUme6g9UR4FEZQtCYCF0W+vOBNBLsftceYhBcU9M8A1yM8gl0nPHpIsBAZqK1g" ..
	"/qR2N7/YZ31nWbJ1gimjmX1F/neSlc21WR/dkm/WFTcm1W7SEJtLW3XJ1jhGsmiRjquwkLqyTXfI0ADyvQw+QyxC4aBfxH2/3DOi" ..
	"ooGNzFSWt3DabJ2Z8OqFlA2SeYE+9F/nWffv/ym9J4cY8/kWClhpL8UmTO+DX4gulH0tj5/F22BSGspiSmCVXZF3g2zG6R2O/QUW" ..
	"tB+CjILCMdq/I8PCF7WoQKD08OIHmDRwE3NBtDsolpmjBH8Px2bDFiLUdRp4mjqeltK69IBuiEE/nnU3h/7w1oqzK67CjOREYFbL" ..
	""
local PAYLOAD_P8 =
	"ExoFxonCrTnsCuK9vMaMyb0F1hMcaJQIVF4tVGiDDo1XjAZiokSYq0uUGc2qHCEihvqRQmhSK5FLbL+27+5BfEVdAefmsI37GuAI" ..
	"3eQuUe1D3cW1+RxirPz9EJa4ObOt45WsUXevDd+jM6NqvAPdXn0Xr0O42i5KEkR05Im8WCHJcgAJratzZYNXNg1uu+c1R7X0JCJs" ..
	"dyKm7RUduls/X16eUrDUa2Vi+4npwnGdH2o+iLbIla51fELS2oWAf/x2BEEWceHt+lEYIxCU9pIn+Br2l1wM8lgnoAGPtxNu/lvN" ..
	"3L3n53ytvMx3sdwoCBWg6MfVD2zSnYGiojo8T/a2IQAOQKB2hXcjEEsr3UlxzlVMX3Irp6iLRuyYzYS0Qd+9ioAymVtYVJ8pj0sg" ..
	"5a7BZFVoZGmVbrNcZDCHKtwvlSZqSv/AXHgVhCJQmlSq8yLg6/CuD+6Z77lzb4f7HU6tzm47oMsCMiPICvip7adeetN/w6+ar+Dv" ..
	"ja5BIu9+Yv89nFeEadBzqaQeK5FeR+6PqygijFwoKCmb7ajoptgTueyVW2WJCJ5B48wi5ZkKVdKm3CE+jaGpqhRM4QgMNJeQvsPx" ..
	"Dw/5xADnsVQGF3Q/LZ5MH82Pp/BISr1Z8aZyvyBeHtoDE9zgd8dWZwSkTon4Z6qdxreBWhru5mFDAHQ58hLBUFrlWu/+ae1hEv7u" ..
	"P7Ixaz5udMg70sa7KU9a8rNgTwwiqELBgPrUCgiDdzKEF3k+89Y0clt/0vs9xoUYTpNOv4bvPH1o6I8DOkIuRHlhwYU4/mUzDODr" ..
	"sg+GUbEIjTdOPngrEjr6L3eYOYfCzgL6m//lGKqkdbSa3Q2BE9Lh0rGDaCwrnaIir3+wXPUKdpsnX/f+9hQfVkKqErXlic4CC339" ..
	"9gBIKsewCoWr6cOWqlsCNjUSI7e3QOChX9AJhtNOH7RyqhnPXpihoxQFf5URdF5mP44N5opEQH4KDkXnq+xQjO3fvxwlYy7TkYkD" ..
	"Fm7pgclYAZX6Oavuk/9xf8auufWBAooZvGBwy62kLv/SEoxoZNVDu0iR15tNtHFqhh5E8nJw+QPQ9ItXuqy+G826ynRvznc98Qp5" ..
	"VtbmArsK4yDT/4vyVuv9by9FrtauJhSmDW09F5yhKAQRzlhTVaizDvXefnLLYGRwHZFFS1WnN+1RNcPWumRupydHa+RSuxkPJZ+s" ..
	"PKGeQhTnMdBGAYiyqFVinBn2JXvIjcB9gjRRZyJbyxUZpTx/fLObXR+CqRSCTG+We5Ufiw78E3SBm2VEztzgc5FcjxiCL1c1iSF/" ..
	"VveeSHuogOJ/bhzVbgHrH6yoW5kjO4RP1fuIfduuyoIdyDCjX9WGF+6LJyO4Uy23MxbwhqeDP1kXPUYs2imyPb9hTjX6zqw/Ztv2" ..
	"V90NvdiLNZeXIV6bcdaYt6MAYMHW8lGH8fmGkGrd1RWDtonUvK0zIYGz28fClQE+IZbG4E0JE9NciDfkIGHxYIEGfCPRryTWwtWF" ..
	"nZn9FP0y9RQvUp+he8vj9JU3OIpJquChF7VT2RELIeQawt2+HSwVHq/+VaQ+wB7Qp2ajhxW6ylVdQkk2qJXzQr7r0tKz5lLEfVSj" ..
	"4kRzPOBUgNzb0Au33eFaf3SbIv3XZCrPyPWwOy9+ISUjsR9gNfrQuItuqN+h4OVG8sSMqkJJwd5MBXgUwfCId+HqzPFPZL6wxYxj" ..
	"bAZvDC8fMArRqAPJQ4faByVFk52t/rjBij3tdmc7aFYhgtfnvx6XjMLje7RFgDV7v0CgsH/XEL7Yhj3JXtFejq4I1VVggQOs5HT6" ..
	"hQpN1aXr4Dczp7FZzEYeoqFsY078OwI/GflEe/xhNC0Zq49omostLoS5JHGqr+Dx9co30+w8bJ1CzBvp9bJCet9ViBLpe3DL+l8J" ..
	"58Dg54wIWrlLwLlm22OBZ8wb2itJIuAHTaPzGtLcLM8/oRn5UhBb8RZzHMy11V/HUTcdWnqqMALHan4KZKFGWm4KNyWFWS1furYq" ..
	"NIS7w9K7o2dc/nmdX0NJAsPF+Ia40Tq/dyU8Fv1skG3fx0IhiAZidJm9q8u9+E3IYjh1LsTIHC+gntiktbwcDk0YrYJ0QT8GYGTb" ..
	"325gtI0Jru2iZyChv/5G7zn5mGiPa2TGbnV285+CmYY8F+Glul5FGzTBmrEJNIk6iho4iKAHSOwywCUoVI0KDL2uGFSsIHfDrs08" ..
	"54TbG3kiJdqRCcl5psAO25QSSqI1xHqhbLYEHykFq3A61zAevl5rWZJmg3/qPGhtuLLmb9XpcSsgeR+jyfbeWkbJDFGQahpJrCLC" ..
	"f7laW5YBdz8D/ldPGmSTp3y34EUfNAwxGtLjvpTXX2bFqfLg6tJ2e+qcGXMOtL3Zf4biqcqH36XTs0mBnG0SLLPIYdneDOPCE7KV" ..
	"loLr7tf9J+m/5kDbtPXxAw6HDHE5dPoFR5hKz4GMSwI2vN2lbIGje2EiLv1PPwhSOrzkce+FYRS6l3g25n5pEr4VjCp7oaELtLSp" ..
	"Zvf8MziAuP8lYcTK+0BTscby7o40Q/afmRF0GNViVFDHd6xoQAri0DTr9gWDph1VqoO9uzUQsinDo1ewFsGzgQgn4A3jP+3X6163" ..
	"6Xzb18i9xC/+g9e56v2sxosOoj1E9jYFI8WuqfzsDMyWlKjKFvufnsiC6NbtoRK46/1RSsZnEORZw/1knU1B9nwZkEFYWPMUcLWj" ..
	"56tC2iNAGO1V6pygLdaJtiCblRZ8UID3z26Nw2wDPqNLfz6kE3r8WGaILlAdExKYu2Drsj9K6vmB+glLUf9AC86oUwhV/dQraQrg" ..
	"mBgkRJ6NSxaJ8h0f0s+94j/Vq5FS7C8/XVMs+7Ht+H1ub5kJxoj+YTSsh4siKwimeM735rnpak14dRYvizrm0tPNNV9zoRHoTokc" ..
	"kRB0Xg9vaviXnj9PIyt0ReII6QpnRHX6kgY9fj83INPTjtQ67EtAtx53iEp8UMWYzKwDFxP5JIpzsKxKInW1IfdAkNaWSvHovgVU" ..
	"zF3K6tFwGNJJULR9nsDjK1SqY3ZhGwuRg86GSBXfiou9K56USpHL+UrtAdAK2KRFaO583BT8xK/r98+KEkicdckUwYjGkvZbnQ/0" ..
	"FNjW0qvLv+7LIj7lygftM7+G/ldKzAyWsN205BIKGsRcSzUYZeOEjDREqSpOhL+qTd2m0v6/AAdLmcy1p+K3q62+QZrl6OK0CDdd" ..
	"g0jVpwrK+RcPSWDVh145Sgrxr5APduV04T4+eLwV3Uqu/uJASfm1k9DwhMPABnPRIA6YZE8imjktt44wHm0NBf/nmyolEDfoAya5" ..
	"mqk9qkjMfo29jybdyWXcVsXC0e4tJwnfiX+0ql/jPllD1UqZCfSW7p+J967fOP0pahsaIVUBBWfazd6vtGBjYhZSxhyhfGDriM2n" ..
	"2Ailq00/O9IB31xx/x6ephFzzbOHSXzR2GToI2TBeEv/+1x0nw52bKRVfxqA8Xj0yx7HFBEtSMuAEN8k6L52ev90hEHT04v76exW" ..
	"e8x72GlfteuJJPBeX8jtC3GpYlk7UDm9Cxr9y9HzMCf/88H7nMsJnjqTAfiKGAJNn3ytYIP0RbT4cVQ78Se6E+1mKRnanrLDalsG" ..
	"pf7me+UOpLuCAI22MLAdqQ8nQL+93jLtV4NKfm6rwwscpK/92uQJYVwesoVmzhwWvvV1dqGzcNm/k9vOrvCqj57hnxHS5cJhpPT7" ..
	"NmQTShFf8s5Qb1XqAUa2VNS3UyLJ0SE/MvDc02hBCvbqCuuwcOsXRLIjGfi1ex5YEqIAWDwHQOB1ODAGbCI1e1hO2FTP9ngfq8Zv" ..
	"cI+3b3vwlgZrFeNEvKVLfYuwrOfQ+H5oCt2H+SdFs/NT2i+jJLHteX570HJxeBNC4kpF7Y4Cq8sYcrOck5etvXuHynw09+xtsOyz" ..
	"NC+y2rrR10E0LsRSsqrfarlSKfK2L8i8U2KAXnpBPUFgV6GHXJXAqGEVbqXJ5AubxHNybGA8S+TBo0ZlUSHfqyyiWEAhoECRUX+p" ..
	"ElI60FBNrgUnV9oJwJz8yf9md4ApolKgN+h9Myoz59CwuDFua0pYZN7FCj1CU5Tcz4gbczknrkWJXJH/WOrXXLEQe6zyklvacqO3" ..
	"2GYsNzAtu76R0+pMa51YD9388msoKvezAysK0myKBPbwJ7lsmZtEQT+LFxDZrz9Su5yixTCZ8DAKk1hei1BFNhe7GWHkXrptadhd" ..
	"vhT7GO7epCQRUCiQjpXJU0VVs56IQB662i3mjbTpEU1vuZOMNTvN2GLblcBoGFmw3oftEBAh6yubUoAYuEuQsOyhmhoUHQEJA4oo" ..
	"uRm25VUj+ibd6FTA7ibXUGco1Hs7aQnKjNG1+eQws7SNhwcSXWe/ya83V5MJR1l5Rbn0Ck2Dm7ZmvEQO3GtBMonfNoLgLAaiZZxN" ..
	"6zIG/I+B+Fui1bZaRQEVJxZHGn/pGPFKvpcQirQ6SIUatsbdheDBhdsPdBSjCTm7Vn9Okr4rxxvkNXbeUiPh/jRc1ZMvgHQjkCH8" ..
	"32YqJdhEM0tiqsASOG21HqDGyFlgjHSY6oshYNPQBugZrOLS4WA4aq73MEyoWnZUfIJPLPQhX/CT2NFkMXlQnL7v/O3pk7cnUK0Y" ..
	"YtNah02oJZtbyTtDMc3fOlBHDiQqCGn2TSjYtJsxmcQYAbP/Cy2w/7NmJl0qQiHJWntJ6RYPe/HIaltg/rYw9PaZaMXd1R6If9v7" ..
	"eh2T0uzQbYMeiJrqICO1TkbzbmeYj5wlSoKtN9UXSfWQz3hgo6dJXgG2cFe9iG1TMltt/G/rDSVfddO0rZdkFGr2H+9r9FClC8Nw" ..
	"7FaabUDNx6COZqKkLLaE844GEF0nlLpDnKapt/LGwc3Oa0mbK/T4emXPyEzi4HCxuTZ5NRrCBuWZ1eHqGwyATqpYslwnjbWbbbQB" ..
	"P0nXkGi3KEuwMnfjyjbFpO3b0JfemxXq/IHPkR8YtCnrCKs1Dau8cfCjRYuV9qdimLRwVZ5gTRXm5CdY5yu3vUoQLfL7Ne7rqHA0" ..
	"24lBuzk4vJpAwTZjJEK74cVlsiQ39r5kvLaAOkKGY+/BlsUhm6EhxLQWw4C49j5FBD6zt3D5Q6T5yie+7lN0Ky1SDv35Pi70gJ4/" ..
	"wRh581qk3FZwKYEgQyikvonvp1wxQt/9NL4sIbZw0YRylAbb8e9pFjKHOuVEnjD58VSIwbskuEKTBflZBe6e76PF0HIitBG75PNQ" ..
	"l69yGLmskGN2bx2SnZk6gt8CWiyAIqG+dukCZxpWJEhnz/lwg15pI48GY6JlFX4xJuJ92f92BvwKCjESwXjtTLuZrtjtYV+EBLaG" ..
	"N/0yzQjyRJpLlDjm9D/o9r2u6nJ007+N7X1AKvwtkj5whxO09FehefHbBjXfObaxYLsZ9hXPwqcs6ml8DkMqL+7xLbJ1rmWjTOoB" ..
	"kSQLzuWz46rhZ3nPzUsGL7olnB0ZnL1vQHNMmlkoRmJ1m+nkD+cE+6JEP4yEMc4LRb5m0/q61kkgA6RorN5kENV2by+RlF/DlJSW" ..
	"6ptkgCq96ilC0UzRVJ984GfhXZ1n/KwQZVX7dH1Tq7uB7PvnKvAqSaAlqSlsM4KlyJQfsrfZyjqDh2jerrTpK8oFL3tr52+lY2fj" ..
	"ye4Y01+ZuPzKT7NZOCwoULuWjo8MQBXEdB9d/pS6hIWfGcJZFe277bKtQi5QrRQ65cTI4gOgv/Lf3if+LaVBwHC5x1wlGDGwZeya" ..
	"NnzC2aIWPs7uL7DjLnXoO/QQ6m4z08FyOZFILPHnBYAP0sXsZLZHFlses8evl0UuldbsFopprK/+41D+RYmUq89gsUKMuQ5hBAII" ..
	"K9n0Mh5ytR4cduQSkUO03Ft/9oket/dEK+Rz0wSDBel17itmX39RPvcnF6v58wVuL9/4QDbwQREtJF8Oy7FD4dOPaEaYsU6aKo+W" ..
	"WPbEtYsGti+NTP/kHTdXQGeUteF355ci+0kCt5ijxYaoerh3v01Ajlk6QrXDAO6h8V+jJcenRB2wDqAiu4QuIs4zkqVCIV0I7qTu" ..
	""
local PAYLOAD_P9 =
	"6MAKseL8ou1Fx6HlwPlG0CFUmZdKJc3hGRiduo2PFPQD/CYMkR83W2tNR96+2aF4JSBHBW9/1h8llPVKW3O92scgPXh30Zc1QUSd" ..
	"Ytjzhz23scnesu159oQC9+ZzY53CXFcH4eX+IHXbBNT4ltTComDDRjv+skJMaOcW/vt/WdafoWk+/exOhjTun8S0UKpfWdVvZmHd" ..
	"VW3oNiI0trjqszPrCjg8FJ5FAC97vIPvmcr9xC7ANkVwqHhZHkX+PEXkRnWMyuxjSJEZ4DMuJ6kyO8dqo/AACLNxpiPDcw69JKrl" ..
	"0Q/LPnJSJOjXw2QmLqfVqxbv3LQ3l/9le+gEDE1D29QQAH+jBlLS594GGFUc2tNH/BV//wBeehtsMBL24imVAZW2joZWNF39cOHI" ..
	"jFEiMNzBpsWJEibLFEdS0BGySYZnbUA/1QcZTqx+PoPd6QU64VyAp6euAvW552fL1NFPgEGRx29yDs7ZAB4MCr+j6K+aMhi/zSOC" ..
	"PgTwBMcbUGdW+ZDr/F2GMVkPRCmpYuNNk50esNNJUMDgMrvpCuAMj90jOgAVtVyWX9uxJHorLAkV2w9FSHxVU8iUyEhiD86nQ+1w" ..
	"1f2TxGGPnTzlbxvrfPqgmTfAi0l30ZgIKKx3kFP8drOYZ3qKfCV5d+KlYHAOmnVle3KzwoqtsMrvzxyngd3dHTf8MTdGNniXpEKg" ..
	"wDvgy7wE7J4iWndH1cqFgySRBDGGUq1FPm56xgmOT7VsBxGA9P+KHcTC/gBCX7wl5TXwTLVdbNzVcC0BeDzCo0NOpZgTx0pm2VyJ" ..
	"zxNSppjKSkD9qJxVTVpek2fQtQiryEa1ufZrOHWaBEmZgPNw7OMltPWyqDi4yV568WP6yBs/qoFto5W+nMqYErobvCbsvYYVYK+O" ..
	"9fosofPP2lj9XGX4uHldnUGIVtX90aDV99XI6W5PeXH5FEBItf9bZp7rbHvgZ+uSfCPWsoCmo2P0Y+Zs90TFYHt0jOpChTPyxrAk" ..
	"PPDZjEqgCJoCQAogQ20umOhqwmqCQSPNRDtXQcG3mR84M5ryJltFAGk4KmdWm0FdpWpVdSVtP7rwDANrM8/YjcsbH64TvV3kr855" ..
	"nfVxCFF9SWpLbUxDVeMIpLj2ivyYD2DRv5Vtbqbpt2hbK/LTF5OqwPPYx0619C4nFBQRLbH3KX91vqd5qDALWlwZCJoxDwJxBvHc" ..
	"e/U3zEg0cP8iJHK8uOd24BmPXA8cnL4V966vV0PDN/XWolJlmKFgvMpgFKrQy1e2MQdYAOdU+FltxMmUcy2pmdDiYo9SCjIZxW1y" ..
	"qIPV2JrdspHidNf4MLO2/gH1YDHwOceFxlAy4Q/JkUlJO+XmvjQT68DJnMe5bKTSt5DKWcbexTVAcRySdGjNPwpBqLO/XaYk0Zf6" ..
	"4k6LrDxNlWhVOk4LL5S6asvXZHN1EyWFrlI7QgkATGCreEF1LbE0CMvHmIPmOvDsxCSqygbl1YifWwOMdt7Z34O6T6X8SEuN9biz" ..
	"PkQVWUVhEDAUem0n1c32oaLKY4T7NaAnJP56LsFiCGVwM2Fqfb2zFlUvLyT3WfOVTIZk3rbRxMVgmbDO8oog1ujGC0SmBIMP6TxN" ..
	"NUDxBFGt8ZSgk+i8idgiUr5aolQgzpUAt3HaPkNVttJmGmc6bLDyj7qdi3IzSf/s/DzbbVOUzNg2/KPRx4WeGCe48f1TDoQ7nPeD" ..
	"j5Ip9pKCqaIqo0cSfIe0amVqUA9zy2k9zDX6Lco9GVON7os6W3NUSI4vRbsJnIDaVsSrI1KgEfsw4Z0p+IoyUDrDycDzyJDTy3vo" ..
	"lSTnLXL8INX/pXRh0z7lp7nkS0KJLdnKNMnNaZFq6sFhpIoMsYZFdxNC8M+BHJuq7o7fGRmciOKCvtnlq6i7FsnQ8IEKREQf9uQ7" ..
	"aKekadO/NDL9ZGo6SxCrQ/iV50AxNjA866s4U/2Z0V2Exj6qN35gO1fRS1/aTXRu/PfQqbeifSqYJnUVznRz8cRAsyd1kCRNCxvX" ..
	"oJaz7SQUuXFIoGKrkbH3xQwjX+BBbc47bgifTaR3bRxjURMsrKAYYlIDBI8SEDR34rsed0b7xhuy+XlNntiTvkStjRfXvIMBgGXU" ..
	"sZ11j6zQDrgD/TZooPgs8echPFbE8Xs+k/W9RRr3U5vCZ45L+/Dqq/bmjDxkHIukCqUFoabPh9jQ7wfVO5/uz4P5J5ZkY2ZQO45A" ..
	"082qRXgBu7DMQIE5U6u8fpOsPX6oHm1Sv2l6nl4p5DyuppfJladGkQ/wmgtmF2aQ9EEZ2QKJnAQM6hTj8Z1rzJlBnXFcbyyMqpcC" ..
	"7tjK/tbg7shjhcDrE+efYLMTBddAboA6D34exVVMEazyRs2nhrNE/dwijd/hrfBnxmsOdJUiBy6ox9KlkJm8kYV/vD7l3Utlwl7a" ..
	"36uLilCSZNNEYdHYwRHGhrIhFTvyJ8/sjArbPd+aKpdXujccEVc0UX8NAGS9RdpGevRiLI4+28m7vIqP0UANarziXxho3LYtadI1" ..
	"b8DuHNM5OkeggJJmGQ6caHgqsDY57aeuWixDUsUJ9I0K6eKCS4VBuvz7cY+LUOvfxPLYFTQaMxAolKd2C2jsguW75ud112Qxh+4T" ..
	"hLv1QxVd0/C4eVLLah2gTn3jnTzXoBJDZMiWqOC4QfY0b+JG8JXjvHA+I91Qv8pdu4FDZ0T3P7J4HowX5PtjV58Y1U4AbjAwx3RU" ..
	"UP1qvD+SQ0HLVNz3TKgf/DuLvkojOJtj9ZUX9BSv9m1hoWRE7/OU8snAnkDbI8HmEZWN6aFoBMQdZI4njUGFzPJSVjN0Cw6Egy+b" ..
	"0UYd7SFxrOggHN8K08guSAKpLQHYfGDlZHJWwWyJv+lTl8zVW0fpon/HUsevt9mw7EYgoPZ76ulXaVfe1kPJdk4VLlAzwLV/p+Dj" ..
	"GzlNBbPR04BFce0e3fFev4fJ+42Kb9MV3RDGilIqwEBkf7+18XLaHuBvJl6ev18EofMnJyuzH0NPFdkf0aMEAG+eyZqAEiBIM3DD" ..
	"LUxFUPsbmmAr1VYuRq06xpglkIGtZCrBdw1KCWUv01njLIsjKwfT9egFZSOiQ11i7Cuf5PiShk1qPJtXDTQR1gHWvKMLEvf2+3vV" ..
	"6wyY/gBkzb1I5nM/AxcbcTFDeCyrlOu3X9nJeizmnGeKU8QrbLBFjcL15Ub6AqXNyoLy4Hx0LGOL7fQZ48Eg7L5i1aDhc5UWsoAE" ..
	"hjnKy9gBYx6riuxUPMzKhMxNWxhxOTcysAqvVwKY1ABl4sW3OcWoWAl7iuEPeduwROXOFUlEissIdZUa5wd2Ksuhsuh1Gz66Ruhc" ..
	"+0qxiY9aWvpQp5GacpbeNoNIkU8qhbHZx0ZnDcnLQkbgOyr0Z7CZwaBZ3X9dBDiVLYKV0VUyf9pBvkV/jCmk8HbjNBG8HBmdjOZt" ..
	"tBPNREnCWw+1p82HXjUEXI4Yai4nH96GPssAsXCrbP8vxFWIWO3yV2c9BVM5B6CSnrb0Xh2hj2c3vpn9gSNoUxlNZfFJg3P0q8Zq" ..
	"Zxe74Z2JT9Gqfj8brOC61EOYRHjGwuZYyXryxQP2FNrnSNMjmaHew9hA3RTqQpiICQc4vtsRJgzG0r2avOABOw6R4hfFT/5eLKx7" ..
	"SW18/8zB4QHVG+goVTEjwG8UrMX3FT+dQKyPfPGRlXOTvR6xDL43NR8P4WENmShEwB0aNt2m5q8TxQ8ygN3UPYh71vMM0Dk4jR0T" ..
	"LH5jninNi/bvWAcjwtoeOVY0Jd+ZqPhmzwTwQR1/Rr4UiokNgEAHQYkWgPqHCSLPgzSC8WYxUyTdP6ZQwoUU09127aKBYkA3YnOG" ..
	"AG2TFseLAtQgCIwZirtTnIY6sPAAIqcMnc7nXCkYXXeyuiURQmHpobcLqsaTpUVHfqg0Hn8SliUT4BdmSEUhyMMZMfIgvPVOJCiO" ..
	"uL5AjnPHFIU+4vfGbX1mpWyPJu1oJ05K7Cya7YZimE4Fyz7tMmtbScW7UkljJcKYsMWvtycSFe1/FD4pnSzuBRsg8uci6WnDmlxt" ..
	"Wj9B9uw7jpXYSC4lGbDepT060BwE1CvHtZctZl1s2li7ONOGwGEYliWX86lWFNAlicgJQSDekvQKJt/BA/3t46fu5VryjQRPsW1S" ..
	"rQb92KR+OdDu++UnEgwCuWF7twMV3Rwr7d5iK4dtKACpmJqoRHhThICfN9h8a6jCTZx1QePUwAbbGJcXB9WuSuQvk+XPArqGeDOJ" ..
	"6uAhGfi02A0NkI7eCLK8A5oFds/yWpSTmUPpLqVmLN8gdU+lkM+oc8OZVIJcgDKFcqOOY96gDlmkA8kkZ00LEysKsIv20BkITZkW" ..
	"3V7/lX5dIDhawNkH0O+gUKYLivjxi0r5hkgopfk85hs6LtnEoUqeBLHK8KS/rqyh4Ua7iP5HtvUrNG9jLvQ3iEE5yCAbxLpbDLza" ..
	"v0Ms2lGY9XFuoBBpYM6v1HOpLHnlmQwMuprHmsF5GGS7a1JaHxFHKZ4b1WHb0z8GHClqBuXDw9a2a6WypVChn4Qrq7evG8ywEkpl" ..
	"tdT+vN7JubE2hCnXUDLwcf5Vt9lwb1B+myiwymoZxyuWsu2pbkkD0Q7IjwAiP5yrZmDaKWLKUb40TiavkWhtPz9d+HZL16Xpm/fY" ..
	"Fj9nc6S8IOhXw4Ddqd9GX7ipz/Q1OMWTC6Aw9kq7QWGwOjI/SwoxOWNAjyDFolORf4KNfHq1Mf5b4QrtRKyUj/O+Lb8bPzMso2AF" ..
	"few7JvvCW4QBBqYTuR8fnwQhbd3plIvhFbaGxDb+yVAfPNx7fffXRnY9UZArBq0Ibgd8cAwT3iFJuqTnYm3k5mygCoJLlzlvmEXy" ..
	"MFg6Waj9lp3+FOHO8XXxVrkgXgwbeFF7blemR0dJTnK93+fmwGL0Lv+eqn8pBXzrH2FT6f6JVitjqzQAT6joMKjICSOgVzsEaU4h" ..
	"1t0E8BsXMvcLG4BVaAsuJTZg4BkjHbV59/5zPZVkCO4StusGmekI9LHctvCC1nl/wgwIQPCcJ1o8o7uR7LOEH7I4QEmPp2UsDnDh" ..
	"TJXSc9/LKiQEBc0A3nhr49JnRxnwmnHJy+TrJ+epLnTbaZWYMGhvLrQ2Jn6PwuDIStzNHlCCEfrkZjc9f7zd1H3stuWTn+HsiXMN" ..
	"bb6hleW9Phq+jui7Itv0Y+dB1k0tOUilUq6KNFRLUTauCKxVDR7ZefVV4xOKjEdsiqvjfB7DOHg9W8o0k762+N9cjUtds0jiqek8" ..
	"sVgn/Zq9A0qYkYDgOllVn32AraflreQxeOPsdktfSk1XhfSOqs3Rd4c1o8kBZgkIqddtTuFSXfUe8wZdSaGKp+Ey/WFevzUg+p9K" ..
	"MQASLAsmUnBkM7l+YjNlw7tck4nwodOYBoxG9cQd3gfpFADS15IBFdEAjZvJXOAU+O09Hgi0jPR0Y3UwyjSFgWlM4nnkxP0FSpS1" ..
	"gCyQxwCms/GHLRQcDmsFGmvZQqlXPwy9lf9LnuPVQ6VdMao5Cpr5loL8gurygc2MNEKQdYYl1B7aWMY0j52S2E/OvaQjd6F3FCTe" ..
	"blhXMDO4SOmSMNHr9u2UNnf3+SgDFAsk+uIgx3DN6EnHizWS98dZPg1rkWQXbLddGGzguBikZNNt0PYvY3D9rfJQL0RYuqn/G2fa" ..
	"rnsFg+UkM8tyZrsIgZ6iUYU940yo0i/2r8onPeVsikQOnV83mGW/MFEWqNQr6HJE9xPP8L8Nnpar3kPs4ha11RYd2UCm+Gq15VLO" ..
	"UFxZ+loG7EQJ73l4Dw3mDwhKSVIekvd2JdtEFUwWdnYzEw5wzv6x+tmct8ChxOYwGfcia/7iGtmdJVAcbYyzGjsNIIVzKlhF4J4W" ..
	"uiqKAkQanFGu5pTnyTTyVIRjOjTz/qsh3ZyJOQnFY3ci5zD7bLLEAyAR4o6kU47iJ3XTNA9eZQhx1zvK11qEsAZdi9W6QKWxC+MK" ..
	"oLfPwcF0tEIn8OAuLelG/vrBx9ru6WziqgS/AfhyYj2FWNx2DqjbESLt9+Y17fy/6MzCzUYV6Q==" ..
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
