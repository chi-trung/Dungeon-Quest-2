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
	{ seed = 2781185921, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2780686231, exp = 0, plan = 0, hwid = {} }
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
	"CdFMwBnaNSFhiOk0EyFN+TNOLtY3vpRgB25l3SE8ii//3IcVKZAfxk+lu7ZfFVNpvPdtA+JpOOlrZ5zaZfxJUkeOWFNTx2xOwaUp" ..
	"gBxnXUrodemTRoxZZZc/eE3XBpLVK97MET8/VU18tRgY0U8I4bM/pHsY0fBE0qYQWcQns/Z0B1d0kn7I1wicKUzwAImqbRsfH12o" ..
	"3ocO/4IWERvJTo8duZHmipfokfwfxRaXgsfAczzpDn8VjuwJDymbT+CDI1zgkzrl1VERMFaznd1YgXpgLcEcMtyYdBBfbN0J2GBC" ..
	"xHTCqCt70ZM4kaePkbAnXmdz19HcvUEW1ppWOryj2NwooOsqWP28Y+VUx5YHHo3WU6KwALtF2aMp4KUztEuI10oidT35T3dfGZKc" ..
	"5wJ2ZfABAwH2xEZytses/5f6EZWBjWiwltYpzTPPShS5niVj23z7pr7cSzkHIzpYItDuOKvFJ1u0wtRe7A/emxsw+YXA3Y6jlNck" ..
	"aFny2kv5hK9TwOR9IzqBpwYVTt/WYx/0LNOzkZ8EtF2njd6e5LTGWlz0gT/d2NFrxjlqORqtLpG0aciV+Dv3MAlF7YqbD40+DenJ" ..
	"NVns0LBHZUk2I/RGevT1P/TH0j85hQQYtP1+riH/lyc7umAeHW5ifY5jgGDNgCUIRk2vOu3ZeXtdRSx70Wq/Bfss3IyLdmFDpX4S" ..
	"l2qe22ZOYkwrDQdvXM04Do8K8qC77x1AWVHMF6XD68Wdq38niYk4rQVPXZEbRjTEYDC+Mowgcct2j2D0SCWmj/eL74LcxZ4GwJib" ..
	"zBHDziBiW6uj7jOeoaK5/4lB7KAotvdZv81k3tjZaAfUJXtsMAgaXKbHUTuxfjTMxlvW6f0FT05Odq7i1iHN7SL9+wmIGvwtHCje" ..
	"MrbswzGKNTWEDzoZp5On7m+HAXq5Klm1pL8ltp945gfDuk/5k94cP4cl4TCfP8mWWT3NMVpd8TW8uHfdqffcZBuDBrZv94TfiOC8" ..
	"N3fI0CQqwhOEyT7mSzo9yAJYp7nkfjrb+gNoljoGHZxRP3t+SdtzSahgAazK1/EDH/UzvrMwP5NwDqYprnpaNU0sOHbS0n/4LY44" ..
	"l1hPsRMXqt6BoAD6hUbokhppIc0Fjzz0kWwWnP2tx/KH7OtSg9Hk2gxnkkBlNAhxPk8UCAtJJtvjWHK3xUPOPmvEukCkvR38j0b4" ..
	"Mr6v5/J01kLFy4Qx83oKP548REdTGrWp/a/8zPZmhftW1xn/TuBHDqEtZWTRJYS9fDVJxy/f0MbzONIFymb/RW59JaMfocKSefBu" ..
	"/L8K3nGk1Rr3k6bk5TFQtnjGIsJ89mlogrEV0q1bgEbLBwFuvLvSjvAEkuoThicv41BSXhZo4Y3lIg2ZrACcowhe93PJPrV6p4dQ" ..
	"VmfRYF1BxjZxYP5ILD2vFdkenPmPZ8HQmt4tqKaJrYB4xVVREK8TVGuIhcdEbhSFls5WRQEmggMYqUAfnG9P4Omhec9/iKw0x+4C" ..
	"w3de0HKaekNXKujnm0k622jBBM0zKglTbvNEBdsYhV2ic1EWBxIHSnuAHQvjx6H3MbEdAdqATKHIXYTHyK/CPTBOXHqClVjzAlHJ" ..
	"hFDzhavc0qAofbXi9790BORB/Aolim17Nkm9sPb4eGPsWGqrC3WnyYbk1ed45Kw9w3nGoI40Q7KEzR0sv6WQiRN6QuTcZQg4388V" ..
	"PMXpBq9/wpmEtuwltKH+OpI0l7uMiMZh8nyqIIsree7qha+KaGxlCdfPYrK+dD5aBN/OiTUNBMrAlM7uTIwr6oq2MpCyNxoa/Ys3" ..
	"j2iBAxH3mJW7/siRHZyfm3RhLB977PspRU6X8vbfdAdihK6/Tu76uqoDDyjiHW0a+OwP/zQzo+gPYScVuF+ioNOo1a/eMvUM/d/d" ..
	"iOgDqS1bEM6q/NoQba3pqB3nJ6Ajaw4eraeLp6/+KBNcl95mzJ3u0iyXs/xyKJ4H+AWN9KI4xArmekmjwWCdSzk8AYse+R1fU3fw" ..
	"c9T7Q/CJEIvn3DM02LCiZ1cHh9RsU3IOZY4FHjCwD5YBaJ+7jXpYtFWsIPYFFfRZ1yQ0xtlF1PWkW3sGC8d8yEOM7H3dyYM+AS21" ..
	"BKGd7fTpLuwj4IyyOyUfc1qs7HzBfVKRomxB9+xMfIsWyYHD2otOeBgLptRWzIW5K5C3/Q1aUwK0Eou+6kVvjL3aBng8PRXUuDJA" ..
	"ICy+r0cSJCTf1PR7Rkau2UDf0JFR4ZsqBxmtQGFLS42vVQQNkQrO8alvvXXzT/t+uzfhyns2I5liUI2c6ZMkL4bHdZ7RHvOZ7kgY" ..
	"X4in+9pwUX3OTgNhAIL4LfhbXGkuk3Jd2YAaEv1nl3YMtzHqsvrNAHHb85PNcwgKl3MfRQ//XkNwMGcnzYkpLcZ87AqUTt3aJu9X" ..
	"aQOORIGcISaG6JAqGH3aY/7pQUtsyAOz3q6hCtrzV9UNjGSYYWDkNCgMsWr889+liVUZdlEknbEtZ3/HVO0pUduMkz9/xdBPyCVW" ..
	"EoURLem4oe+r4aWMu4bWG76arQKjdUDteb+s4bgr0AlvcAl6JfWQpQSNB4qrfGjHLuPX4VmjtUVSb+lJ1GqULvIb4wcK3cuvbjuO" ..
	"FwYIgf8uauA5iICbdBcjI9RgJ2IOzec8ZlJkkU+I6z12u3hDUC4uutUG6piFH3t3GB3N+MJM1/hgyvd7ImK1Wv6OGfIVgZ9mkkoS" ..
	"KUKjzBlqFmNxMQuOiHYoA8zTtgRL4B2U+bN9jjLOa57+sB3o+3hQ3djbCSpiDBCqN3Ath5r43o5pfq+oy4IGFBfvAXWU4TBdjrgT" ..
	"GPL44+4mUHB7WMMraBsBym6SQTYsIKs97pfKUGBpDtoDF8gGthEVbHnRdVZwqjYisaYJ5o8cqG/+Dsk+NVq4Xlxl5GTq5ik/xZ5M" ..
	"EthYfb4mEKq43l+Uv+c7uSmfYA4x+SOH0ye91FTS0Ww7dPPikMvyyW+SeQu8iJmsheMB/lOSC64TUsmrptZrxCPhWeRTgOU4d9Jc" ..
	"Lym4uMkbCTgrL8MsZlhgZmCg1xsrS8g28fF4cKCE7OFAyWCwWV+t2gmOdQYqoqT2RISKXo7RhTBw294z4Eg9Gkxz+pppJfBIM+gl" ..
	"Qezs+fGjBzD0vgLs60uOnmMdNun/VZUrY8OFj7jose/5zEfYUxEAnhjrk65Rcz89QlbvlwdA95Y+vZEjklUshUstS8F+DqLc4ZSB" ..
	"8flNR65rmAkdQ39ztWyjkheEJwD5OO4hwNspT3MZ2hZxW9GjHs4R7kuoxSt670X1N0VoJi+c3dx20wR0kU1RU9eqEaNQUGpndSrK" ..
	"nNr/stVyvti548N/v6FgnQqltkswHqdrXqi0kKAQ8pxfN1pKSsxb24DdXT+JzVMLQPuu4fObh6PbdvnK4JtvWlNfkwjk+FNB5ar5" ..
	"zQPKlDJuCkdFybsFodjZvM17ofQI1PHsJo4lo+I6jEaC5Y5CnCVHq2hzXnAqmmGVC9WGnmnj0lNjDA4/2aR6VUWArwFuekb+MgzK" ..
	"1jF6Mv+MWcaIh6mSzR8kL3Ia/fks2Uo9yhKNGRKIeD5KdrzqePrVuqIhWsRl58SmACzBIhfvcGOD+ExUWK0UbKaQRtvS5UOElRMl" ..
	"8Blz2PsOveQtSPm1njjTgxB8GFiVQ9Youjc/i1iQa49SURvXmM0tGkDelZT7oH+JnVzyIxAKAsYNerTtMu/iqZ7t4zbkxqV7ZVRR" ..
	"k5n0ZV9rGjucFj6wf95o3A+7NdCyk0gaz0ctb1VXhZB7794cGMhvJmJjlK8QhWcweUKYhyUXyV4MDQqC4yUXBMW2X5rDHG+S8Ffs" ..
	"sSjAbNrczclM0gieUYO9eejPJY8+5z9OH9HQuWBPXYbnZTj/qji6zJeHmnSAxRMUg/EWJVT+MWgnkrvZZrMb9f8FVdKGBR3rKnUC" ..
	"SuxLSKWUMvz2fNmd1mhL75hsU5BnmtDOW0YWe28IYhz9CtlTZI5JALJ/l3TOWv8SI2dFU/S6BVshzluxQ0ebCxLoRf3TEPyzFnV+" ..
	"jpH9NceM4jGLe9eztaXM7JX3gYpi9PPowEe32SBPC1Y+OZXI0SNFjZIl5vCXiwdO5RlT//aFELJtqQFo+HIlrewbKoXt2eolKWkY" ..
	"LAXQEVFKsfh2WANFbijGlglLBx+gSaPi+WPc7JfbCWdifhNghEixNPeYUGj61pw9OQB4E0ij8V+jNy4w9jXV+C9g7ZniuWPbVFhv" ..
	"l0oX9Efr8obwXIK1PRiH+IKLX+DloDi8nFS0RVPe35Ua21cxownaw31Vh8tLJ0zsuXaqxrBy0+KBKtPJBjuYn970F+bRwdIJQuSm" ..
	"dO6nYs94JafTeJ4AhyUPpn5fqIzJ7XCMTOIca7mhnuC9EFaXt2VJPYlRp5+DyNHT7oJL83sIX/LpTGWfTBpU78dDeekh8JQx+x4V" ..
	"VRGoxT9SvV9ocyTqloR5s6RcRD1vZZc5uUtSrpbxSQJd7Gwe37/nIQbe3MsYj/q2grt8piSS2GmPcZODwNh5O/qcecDt3hkagPP0" ..
	"B32HQEVeWMVRcsCuVeXBfW9B6NJwMfuhF3wi95dy7J35676ULvJylOiVD7FmBj7hzAPj810RdVur53KGGcUpN9lU0yk59kiJKgtb" ..
	"Gms52q1opxH3ElArlAoY5tSHMzJBvoZbPDDbLTkM/61OL/Ps6DqrCg2M5n78VKgfmoL+7bm6oW3FmMRZpLTp0ijShMhjrL22hY6H" ..
	"ZQWfH9HBxI/4KGMBZzmaMiBt31gaINTaWIz20wJMXqj96EiDnlmUt7tsgmUAoUdfOPofLPeZYu3kEbrp6YcS957b2SxDEqvH30Ez" ..
	"if70TEmlqT8jvNut/7WifYE3KNchvVnpsn5qERMkVMcv2C6jZSz6YW757UIqSplOUWxxuNem/jaZ3rwVEqWAMgovZEAL5ADu0sBI" ..
	"yHWQ/10/AouO8MZpsgk1Yr5nGbbdeONUmOAIO0srojRBPFZ9gNF73dOYAdwnv4HaPXF9GLu0rWlTHG7phaTh4qOA7Uo5ylF6RgOc" ..
	"hv+mVfIHHThkMSM0YHZQkEe8alerfIFLrlXJoLgg17stKztB4yz0+4NYj0gm1Zp9RNLlyOez4ul8fiW9klaWCrCG0hQ55M13rOH9" ..
	"1U/N0cCwMwvFPsPFQapF3A7RuPMH6quhYi/m6cwIqZUrJ3AnNVOCHuXNJTBosJvksPfhARdIyWM2cAVxI3NM2DVNDQKBHhCcSIxr" ..
	"HVqIKjdPlZ8dBZCppZnACfw+SYJxD2hs2xB7gs/FbAKgBRBPAh8zFTJ7r3wznQv3yJaYfp0dQLqgUMWuD5vmvej+c4j1WESBqz+Z" ..
	"3X07onUyvW5ud9RrWS0OeIEfi3Z9KDsOh74jO4eQVNGf5YeOaljZIedustXOr9NTfuVhacoMsd3Gkq/e65qYMv0LiLh9HA/MQuTf" ..
	"niWkTw3eI48zo3p4Fs46KZwrscN0S8EH/XXE6h/ESXZvXq+E/sPb/M9SzR7X064GY2nuBcsBPz51nm1m7R59I9s8h6fJ7dl5aE8P" ..
	"/1yDNQn/h3+blsYDGSqYPIsgGkIjkGWihG1fFzj2zz8H/r5NL5Wc//mkyo4ifuR5wfQhAy4gXRXkVHCjdDsttJ/5wP1DaLYqCOLM" ..
	"UyngcMrkan4rkyCsJEACBTuLEQQaYIi2MsXnIkmrktNWPpig4BukEFw1n5VPVrbnbRlg6jcnSQJ8QpHAYucG2iG476/VKFgrRjrC" ..
	"dafkJyCzrX4ACX/a/XvbavWU1qRN8hiOtAzfcgWh1uho1sZx+N8gZfgWEkJEugC51feRXss5DW45dh25DsLRNDm68eWDb+qnc9Mn" ..
	"SYKE+LBz3PHIztaBVuXue16VfLc26hVOqBs++NbqHIJirQGvfHB6TwXU8Pz6CALwr8tf+ruw7ohxLJiPUKO8oUtudQCrF6DPW8TW" ..
	"tpWMA66ISyBmBkDkuHNaWhuCUMSB94gQd8SRK/OCguvz6ND6oNXK8kARClgbA14M7te+9wd6MQFIZPTmkVaRLoW4LvmivJaCUa+V" ..
	""
local PAYLOAD_P2 =
	"njUGTe017Ze6eTPVMP/nHFZLSaRO/fknF8V/PHqC583zbcQsZbCTKXDw4T24nuCgaaJGsFRXfA/vpGeEE5Qn0BnBRRg3YAD9yNyN" ..
	"xHCFeLrlnJ16XzymXCAxPYq5GD2SZx52jKC5XXEBAyXia+P3MZX+rELU/9HlRb5N5S+bylqiq6FuxB9WySoHY073QczeVOI9KRzr" ..
	"ATB5BrGxqc4Ww/iMA13zYnTRdCTRAv/RCFNm7wuC6f4of5JkgR0Wa9+5+Flg/8tP5BH8N2GlUxEKit7NJ9GLEkOMgTw3G4DxbCgQ" ..
	"Fsx2SKFhbGaJMTcqgjhocz8yDp1blj9E/JDOJCevKB0r2v9C2qKLg4ZlV/QHRuYTA/Tr0a2X+GSe+cD3mo/CL3uWdiL4pXmyf/Mm" ..
	"WkdLuLrDa2LK90PcJHHth8YRm+G0UkmXWM+fnzJ9FPE4gVDJxVx0cARZ/eHLJiJeGvWYYYomVUE3pR62jpUEHtoD89hFh0zxlgzM" ..
	"geI1YHNG/Thx85JQr2bWv49NmL4dWTDDaHQI9Piy1InuRYk9U/apltBHBZvao6+HzVhFinnfLD56Ld16Nu3FzFcmzoH1gsIZjo3E" ..
	"q5fmJm16uKE2oylwBiNkIo/TQ8YNB72EWXLgLlOReC3T93G7QqO1F6dx/ANXTd6H6yIz8D8RFTWmB8aGqlNpHdn1L8Jl/QtFU3aS" ..
	"hDe8f17cOmRYoMgXavGW5bhUsnl47KReMJYVH/FrVjQUdTFtbFLnN2VmLix1jURL0Kpi8NIKIctPHNIofuHJXxrKrsymufZlL/bF" ..
	"cvy/9clb5wamlhfqPcMDpDUtEUwPMUcgBu6yYrYmWgAe2t1ioLIPfTAWZkg8ErJFrnD9eMj6rdC23RYO3IPp83huASTViokKGzDb" ..
	"P9VwfMPx4bSqAaV9F+MaALMblwgTJHAWvS/wP1SO+lU3+H5br9rQh87lprbDq3zGmVfNdZ3kkX0jfexFfbJZAn3zFQAvxXotNeXo" ..
	"BzNyT5ccTegGhu7mxvW2JoY892TAYi3IF/tYX3p/Wcakj8hf3gjG6jKn9L6qiUK8/sdarqDlrVmX6/RI8syZR09GMvkt1D/Zlfzc" ..
	"L0Yvqn8PerkpFgJ7uhZ+/uqgHlSKJplIY18nwcrUl7oTf12bQX4w++f5J47VOGC+Dio78y58jJOZrqr83R9QObs0u4CYQGpAnvK3" ..
	"ul15nx/Dcgjfut+AssmOPPovpkCTOp2GfZYmthOw2NiP9S19iDv94uRlmITHybXZbxHwvOpvpJzOMiJTbwjqg2uFSqhdR7TliHhu" ..
	"Uq0m4qJPnT4QE6lPJ9JcHWgM6aAACgtKv1MygVFpFsjRdqETkJrjG50hSnSE9H3Z+5lxUuyGeZa5D8asEdmHqEm6N+BMnnSet7IQ" ..
	"PMneB5ZCPBwZJAcSKbP61pMMnow7fODZctplKKfjni/TykHXPRUkCI2/IPGPsL4kPoVb7k1e0twLAhCxsjTEwP3dfE3xN0xb2vGt" ..
	"LTPq92E9G6Ax3YNI9CEIxsdXSaFAjCRBFvMigKXklmySIh4ncrc97UOev8RFMd6q9sFuKALJaDu5RK0DEoEid+pBToRzz4bThOrZ" ..
	"25/BVt66NbQEYx8VcCrmSxUIONZk1OzI6bE6yEZ9Gp8AlIvkfM575KEZJSa9se229WHA5CoUyM3HiVBe/vcDfLfalcNa5KsdwYQu" ..
	"b+tEQSz7S89SwDzCWDgdDzeIGdEhgOw10RQ0oKe4LaCTvitAd8VskgIDb/Bbz5nsh9RpPlmvTVlMSZaBUpNMlR3laeDfuZHTcHke" ..
	"0QwR4E8z1TJJjlTtS4PEq9N51+cYX6aCTHpb5T/VKXmuF+hsjCDN5vSakOuHWyrR1JzwOJAuAyQlOzMx/bTuIJOoWXS5cskFh9A8" ..
	"nbCuURbowkxY/4fN1uSoOkXDdJ5x6AJ7gokapoQtweM4toLQAmRKYPvQQTsdP38HZzssbUwpHGV7D8nnTvPYFKu8SXFfzCtWUKiV" ..
	"JFsCt0nS7Rd9RXG8sGtybTK3aJgkWFVkRvsM7ZroGHqNory6JWxelpK7zUH7PR34b2yD7mI+5gW4AkEQEMTM2776OQPb8Prl/wNk" ..
	"SJ8CL5A3y1bfoa00bhxOJESylLNvtw+3Ebb47ot5aw9ssIqFlG9NyK4loWyBz5DM5yMNVePV8xTcUJue6d8nqlo0IS4j19fynn+n" ..
	"vE7NwgwIJ4XJ3XCUgRac9JvcRR54nNJtVYypeyfVQ8+fiUUYkdhTzzp7sUQ3QNfI/hOsbWa9/SnJa8Ic1vLtwEKZCmvQvr5zfpva" ..
	"PTjdBBBAkt9uHi/aBIvgyf0I4k36gHDzCePCnElooFeOTJKnhaxeqrV3eW0hZEk3MUmogixqqqYGKj4MgEalMmEJmURPWuKlsWEY" ..
	"3JsGlkpWsxZFY+FUrPb5J55TYznvatHBR8o0hJWop3wx4I3pv52Ynh84js07hwumacbPGdbstHztBDI6Lpa2tjsZRPPoqpyI9IXZ" ..
	"FsdBVu9mZrqUBYYg86Tlw7GUXombM1wMhl0T8654wla8g+lkpnysHLu/vMSwKkygxq4SztHzQI1jvxtBugbwnHKa3xwluv1HkKnm" ..
	"/ZAEIJuybPoCNEnHTPXQ3UrBT6yGUg+Gv/RieG+YoOlyoqpLHzjSFf7ELbUBHPoh7+qEFAdNP38HECQImN4tcsuMjInfS65D7DLp" ..
	"p09G62WLTgYR++aqElfL0c0ReiYWkXTCaNd/TXRuNinkVQNMK+Mwqvjn6ZQFsvmQ0uaKTQHcfI3Glv9FLTsaieYrIx/Kj0mzImjR" ..
	"KN+BUOv5mSxHu2WfgepPuBQNf9dEcjKzTggtTmgWsFIU5RnHfxIuhItiH12tBZk3336KcqQbatNFBTx+Cbj//4rrfsB04IAxQ3Qf" ..
	"68dlMI8MQkvim/vUtpSU+6bOTTwASxFxqR25I50OE/jOaSlmaTVJ+9rgl0cdWB3dfWz93ARsNi41HuLqrV4oH+y7Wn3iP9V1DXwx" ..
	"qvq4t0JwXWjSFeTAXPp3HfPThVPd0CsHCCniDD9MncKTCpKntLKNynhA7GKc1v4iNg4ZlLzU+LYu7nyZzR1rehQEUBBZ4O+eOPLK" ..
	"w+SJGbDiqWgX5iLUkLxk8OliUBXL8DlNzJuaSN6ODuoRiPfvjHII53V2Y45Dlt4hyN3pSjR2vkLr/L+X7uEyU7DMwO8mUBSeYE8G" ..
	"vBS3txc5gMrDqMsqpJZ1Y2IjENMunBqlw1pObgHaTe7ZbPdmQJbDPokC67CXkcCOnxN5n79C46A3adpYT62yQghiJG/sfRp4D+3a" ..
	"hAsZaW4ImcwVcjG33ykpvtjyVFEVwcsp898P8n93OuTW7tjRDh71xjWYo78pYpeYn0Oni8bVI+bP6RDaR7jZebDIs4SPlXMk0mIf" ..
	"A7JaOGoaERLzLQbDOkoXIDEB4nyFP5Rwl/qd7d6pi9xIHzgeDh6rNfvhsSJztQiRaMEZHS0gN99Y34iCxAMqM2tB0dVc1kD7kDQe" ..
	"C3snQbMBRyQ9U0pAysV4Hns4BTMn9ATdlWuL7lU2mqSdlCZTmJIH6eCzEVJeTSR2oFfQ+IyiWK26sHP2YFN4siDOEmqdGGUdK+Vi" ..
	"2Zl1KViBtoF0TQJeJ9BJ+iu34uEKlN+jgbLX3npCipmWt4QAZ/EBa0KBOCEi6ZDZn7oukWV5ZH7c9RWGtSkZ/mkZEcBY/klhzvjV" ..
	"LFqaCay8LA7JHrJHXW7FmTQtkh08M9wX7fYyLsFWa4rxUcrEM4XEN6Mm3Waypl70Pzl/ZusWCRDtrEgxCR6NtxHAvXR8AEXXC/Dz" ..
	"F0vnAP2EJ91/STsMINA7vGL31SIc1yxS0HZW4zq32vokC4MJlSlm5v5SjDZK+Ie7eFDRCV//jf/2tUJ460xa9Gg429WbnfLpHrOt" ..
	"mav2YHOh7tW7DKy2p10okCodoWLoIbRSL2g33GHrieWKke4AnEHzmXmPhGYytUPHWLqvsm2uBqboi3KNodR9mD2C2nuZRfPXB044" ..
	"izPrAZbBPtJ6N+30elhe0lh5WEFLJpeAlpPMG2Mdr+ZcIiHQboX5qR3c5Yvi4IByJVKgbjUMop/wN/7EiFHxygln7f90mnyaTUW6" ..
	"OQBPpKVoKR4Nl5blDNDAJXDEWfcL9RtHUlU3GN25e1hZG2tBsFR1vT2ey6KF+/D5tkJHKZaNHJETD2Viyn8cfOn4Cs3GV9Oxwgz8" ..
	"Of5B6nZ7adlWT7T8AQ1zkYvbd2z2xLNWu/6ue07ijZpXRHYxc1sRS2BlZu1rvZOIAVJP9bdWly5xg83eQG4v/BwBKCYizPG6i8Ju" ..
	"iuyK5vIKbVM73aO9QzVuZmjMi2RNa+rX8qDtp+aROFweKomLhEXOaT4zNmF3GpPb5sAZvLR468ca7HnTX7atqXiGu+CtJBcqseXv" ..
	"QoyhE+GpIHh5yn+V82r4c7uuVvgqkugaD46rwDuOmGh2BdkiFcsMR9znCPYQH9s/Fgn3BgmV34aumRdbKzYzz+MAeCgLdwMVp2az" ..
	"x47oxvvfNBPiUEQo+HLDgVgLtp/Rg93qOfcmlVQF+a+5oMKz6pXORh7xouUxJSZawygT0Dlv+ZUCh39g7X9ADWXbTFVwftosaruO" ..
	"leQ9mo4/clzBMq6DTE7DhVe7/OwWczFuf9AJOpsNfjYW61PgiUR4aoO5KF5fGswlF93ovRwJH1mN4nZKwHnfPZo36Kp5gOZyTS0A" ..
	"RyCdo/OjPfeJt4Qmtys55VC1SFqPP10jy9MsAKpWwEVfTlQKMXevOGSs8YUGaCTiWmRyrukBQh8jlv7UPP2dKcoyuh7CgBG1XQtW" ..
	"0JL6LG7tmdUHVX80qf8XzKM9O33aqMTKo76ctUMzhDNQEdNciyTjbSNb/+jr+/jaFyoZRRBooF9+UtRFo0ETHJjP6U1/bgdMO2hd" ..
	"5jjYc36iZYdNj4/tspTOZtl3YdbB6SmbeufpoNgyzkYBXOHia1DIHlkX11yDdjV/17CEotFkMnB9ILhVqR5eruzGrN+fqimSvuj6" ..
	"Ly8Lx4bwcuI0aRxz0M/EfKr89pPbBE9YJk4AK9W/qnvWBgTVHTysGoiDo7IeXnBiwRc8AIq82u7m5Y/cZc5Yxp2d6vMmpkGqqDuU" ..
	"kYVAEb5CmsQaDxeVCUFyz8VQmanzAE3qy+gsEUFpd7sC/ooHLlZcDemeT2WOafJIuK7EW6BkvuFWcahOUqxPjq1rkj/xnTxwcyCF" ..
	"yJMPyHdHNlzDEUPFUCZf/PgTBEKNdr/I0ZLBErxjDBvUh9E1sAC+a0icf2i1IK2DaknAqAfcXZcoixtqTQssnQyb4FyT2YnZzOAH" ..
	"2vXeOivdOVDV9EQWB5gSsIMf2a2O6Z3drMfcLLVeAt5H0+6Gl4jB9TMpBxae+ePy0u2YvVX94Y8C++Tk1CVb8ty8yApLl2sMhUcV" ..
	"EMFev+sgoW8o10h3pK526X+rr/N/5w6xGfHejWBmO5vr1QVWELZ5h/cGKMVIWzp9LgI3TBtpvomXpTAuvSUl3LGUKpgBEUSFM0Pp" ..
	"Su2EUUV4nkrsMLl90imQUnb62FdXAO9ZvWp5+IXsXflOh8bs41enfMF43gVZd8wexc2RPcXCRs1ErnTz6scZZ/q5L5P7ATzAu1q9" ..
	"MEZFEE336+BW9/+Grd0b6v8dqfDYhxXpUIDAXt7eoqenPjUfp9V0v6ddDZ1+MU4pV1nOr0y2sVa+zjSyzMDFiwy4qFnrd2PoCjkt" ..
	"Pa0jrbuozQyH3ujpC4ZAquQ0M3MEY2qheclX8/O4YUeHXEeD6zLWuSF8Y5PFXJL8OKwblHWKVWIqxibWiTsY2ptfDVViMCvHrrzx" ..
	"M7P+T9h5h5rOlhFsh52EbCSHVP71qmu29pOWR6zoh9DhrtuYuZo13SfN1YQANHvMNarSeD3oSpuoJCW1v3pBKQBchrp6AJfPMLUU" ..
	"2bf/UuY5g1Rr2nR0p9mDB85/KYjy5bmloWyVNsJCIrauNbfB1rG1uYnZ8MOxtAEx06fMCf0NGZk5JhNCZpnmc0eDwaS+XAzCH7g5" ..
	""
local PAYLOAD_P3 =
	"hYUkPk1Uqd0DJPA03BgzfEy1IQghUhnZmDR5uZS3DtX99VVZn16hb9TQdtcs9wK09S8KmlGhC6VQFza0ooLr7kG/CLKaoZvfppuL" ..
	"vC3pfoWaV5Mg0gqtTxkwB2i5lvDO4Ebt0+Ztn7BQCAOV0cbb29JEEdAH+j3eN8awSr5Gbc8Jjz81RTfo+Ox4y8XEiO7oHWfP5HrA" ..
	"IH32uc4Kcwo5Phi+IluLba8IDBR6kPPmLPW4+8PsZaQu5Vwn5yGP8g7wNhkC8FhLXtSoSYs3awCga8aAyzPbmaY1GKQ6nPIYBM6/" ..
	"uWwal1kqnfnuNjMFOk8/C1odBxFDg/LiJ9Nu/gs4PUWj/1QlAIqDu/9/cD5sHLnXKlAoETD8CZ3CVzcy4bg9r/VgiNCaMthnxeE0" ..
	"YQI6RAda+KP5EESIJcfwOnKemFL6VJGzSgJmpmEu7Tr+NXvcLcYqW20HFtMtgtv2HOvW/IOE+Dj+7gRzDxBR4TRAEt3/d6TzcKlI" ..
	"77g0Wsv5vjL5iiNQQXSOk+cr5qGzW4fIkqb42YDScbI4kDxUvrxMsfmtPiVDRsiVg6HDcqeIYZI00fX8cXEoY7/BUBeDLYlQrk33" ..
	"hWCJh49cNAWJS31hYOsl48awHWp4sW/ZiNua2cbjhN0uqSnHTHeQQAxXF4uoCgy8D0TwMCjK0+ModulvvZd0f2KKYE5eMg9pvDdW" ..
	"WFnEGwx+WErhgGrJjGs7uxBwgAcbfWWQulr30uLuoSHYGHnvnV0CelhanhvvLcuojOUhQE5mJKBO9mGy2WCbSA8cSpR1pBsqYy2w" ..
	"FO7lO81BwJqdVzTsferG4iav2OhXLPcytaAMcikaADIdLPtkNMFdF0FzpnkBAsV72gWrwP+lwuFV1goJqEwhuBbCecYuu2GCEDNH" ..
	"XKX6l3HYzB2CTAYhG11qoUqNQm+kmG7J3VgbF9xZQln+BwMx5mF37HdGbVgrckGUlDUGz0XZ6BEDrymlwDH+YkV7CWb3wRL+OS0N" ..
	"3azn0UpkeggCMIFlybstD8KOpfzPFlzLHpGx0HKjOX/ebBYSZbg3v2uEBzAYOFhu+7yeEVKzuccQM9iqlh8ZZrG97QUVGU/jbAur" ..
	"JxE7lXEelKAs3ShvvNhs93r8l8oioetPqFzwQDps3svEfk8qFw0gI/BucqSiPkPWhizcflqHV2NwDGeOurHdRhVDbacJmkNRMnzO" ..
	"T2Tpj6Z5LRVG87++nKj4GIMZDpcyKJRtS8iUlCXZ3MXEMfxTDk4RK2TjcuWTNoM+WBlTlB3aa6ZgbnFft2Cy9MJS1RK+TOghkzUh" ..
	"uIJjGYEzZrYNxYirKW272IpDsqR9BstTjMjmFbwDB396Khpyssgr89U8WSAdxlykrOqyrimTclGYfGQHXGgm55ZBik1g582UabNZ" ..
	"3im0rPVhWRjH3zHqvRl9KjR+C0Up640TEnLGdYyO5uTdUsXH6vLfbM6pUtzTAQrf5W7NA3ehDHL2l1juDxJY5y1U6ViLavmy95iN" ..
	"weD6fp6LAj8TtG3wJiPifRgH4kGeTx9xVZ897v1ql5HCgrv67Ijjg1rU6Zk2vjk4E5Wecs5eLGlF1dwvkIdcEGz9AEhcQmPK6RmN" ..
	"5zw8ILhmWm39OeGwqOkM/BnfWsUDHiB2lQKtY3zHB2w1/IH3fB34MnuI08WQ+1/GuZwSZ2YiBPkSJzribOlwN7TvFNuWF3Tzhv/o" ..
	"dNAlMJsQhFcC+cuVguwUfpaw98LnYLVl9B0+8XfFefUF9Huy5O3AmS7O0PxMFJnQxRDTAOCvO0OOurU0NVDtIaTyzL20WKkZurxG" ..
	"UqpP2/kRTIVvgtSUepuiB2dN4ga1vToJWQcXjgS7bqPKQ86b2uvoQNVmYsYv3OVol8vJhOopuwvLNmyzlAxeOcS9Owk+S5HusOKc" ..
	"5Q80JOZjtEVKIZNHEIKcC52ZJpUM/ug9igFhiKrC9PwB4MtonmL3ySgpSnqdlfVwufcANNfUpkS+gxd62vsY0KWuqCfVkLbobbYa" ..
	"0pQhNd9M0d8bvO857qsSxqhLp1OhUnJaLZQx8Z+nJHcrylVE+ElZMj0DWAOIX2RQa8YWBggpHB0LHJI+TOPIOQ05nzzN4wqX89ve" ..
	"IbGVuHgVuNQuwEWatJwa/oAfysQ+NjBAM8iKckAOKfjdYnEadSiTkCZBPezMTlUkhmtOAc0Q9GvAC99qZs0vXNJdYNs/NRJeBsWp" ..
	"iFhIbu4WqN8jNcz4R1U1fXx5xVkdjTVZuafogFfa+irevHX0hA+A34uQsYYiVjEsvDBoYSGIPoS1QK2upRVHtEU4LNyE/9yn7T40" ..
	"iONRfxar2K0yf44SZnQrfRvMoCm3QB4jOj7FJdQ/7HoGdtyqKpGBwf0BvcSSpQXVOzezQjslYjCCwps0tAA1XaNEynn9zGggJZdM" ..
	"vVQl8Ykk5MWnJ2usPadLZgv3/sT9whScmcw+MuPtsknsiZqZCV8iISlIFmJ+yl9fv9/A4lTNo6SwBwa45DTMDg7sxQzn8I44OiZ/" ..
	"dGBjfvX8rXzCm9iBX0g720RfzyNXms4y5pgKdF4U2iVyZ2a505S3VuHHQLC7Sa1kZ0Q//u2UC0YJvShZ7Y4p0QvyjKt8H5WNlIy/" ..
	"PJGDNYK6Tgx6XMNBRJd7VvsrXe8WKDF11EbrDH50697iCcDIuykKXObtBH8fKhYWPCAhUL+AB4iKlvQvsaRDhy4O0xnVql8n2egB" ..
	"8VGbXu3yWwIjBTszJ1IJs9uFovIbyQ4kTLws+jx3LSr024na0oBBYujVI7HSglz/zXXy/88az2GSbg1cH17ntjTBjs1iFThsT5KR" ..
	"EevAqHiwlQTXREhetbY/4towmHx2KSDCcNznnIcJNiLlGxAwBxbaZQIWJjP8LrArPSpIwy1z+B5F8SmgVL1me0hjLyrdIC3JwgUV" ..
	"fejVEhif1pjckllhjNnE64uI2VDIcLlNAoJ1iwls+X+y1FplP6lXVXCPDetlEqTLO+aDWndlcCFjCKTP3dh7hPTvq9unqn000HCV" ..
	"Qh+UZqZQeNjBKN+33fKWOX5G3EgWVWOWxR9SCSC5332xHwESEI88WDmfU/BYCnXBHMBXqnB1NRZk6EtZb81Kgv8aln1dUNv5JBvR" ..
	"brB1ZuWwvEllxWRfDEs0rIp24KcFy/5g6MJOUBdGMU+TjgFXRfnO+BvdT7p5FWqj3y7HdDVY39Hh/vgr01qhPVxoQqdzUrzM6ZJR" ..
	"sHvUt5atvjki28tXl+TgiXDuMt3kV5ac5zbM4W8acP4GzEq+GIatUNDwBSShy24xkNuv2uKrMrngBnFq1J6JnfgRqPUH8WGX+72S" ..
	"7fH6QKxU74mnWZMasB/Ul18ETRZrWp9VKDxWFyFWVuNuikCAhSxpTX47cpwAt1qNDs9VAsnCQn/li0a3h+WrXL8EgMgpHPaBHVvd" ..
	"ixDZ2u+njgLrl/jmI61ybk+dAaIt1xCbYELMWKpYQUvCnI4reJ+pVCBLVKBtMhbXhMx6UDlbpqbnLlPdmw5APk9FChmGobvtJ5TH" ..
	"DSDgbH7yOQrNwtA4G+kMorFYGdEO4oPJRG1lgGyzJHaiHZ/QupYoK/1UHP9pnj41N1bwKPj+JjpACnlRIgaOvheb6BYPgFtkxlpL" ..
	"deeBZXn29vN7dpvP3lOQ/g6FH3Sz/d7HFAuE79qtXCMRifEJV8wnOwcGIElY88u9OMHYK8c7lJhp7iqbzKpqXO+XtfOtA4zPLzMa" ..
	"HcDAzeEBrSCGPrASqaBiVcR3rbxBlbPSfSpI9aagPMhhqcltZpjsVUu7orifM29dM/qaYr74zQAhsNOjKHusl19Nbe3CPcrB1aGW" ..
	"6rBYmlc9fD2MhGlICc8mhiTVwLjd1A4tpzU/4hKRWK6osJyW9mN/6g4so+gZ59mg+IKkp0sAa6DHIuUoMvUiBQvGm1u2SjZfxXiE" ..
	"medJv35onCrtBLd5A8kl3tvBs3woIntXEqL2sIS2pCqKnYvGKFSmZoi0v6bpx1+ocAFJPcaw7yxMkZ60ezke23JkClzupHEh9ixe" ..
	"w98OUsfbKddeZ2wUcxfupZc0yMSJWeTQY84c7hf7JwkqIsEBVavl7CiJtazYbpHShhreW8PxfFEtg6m46V+95qOV/499RzialsiT" ..
	"d4LYVYes03QXmF8b39IcYmHo6OVaiXETiD3TrpyyohZvZgJxcit+Gr4iCvqKxwgksCPtgJoF1zGYfos6QcIVF/PBCqGKIxqJNGJK" ..
	"vXX66Ri0fbc1tKpoyIwTKJtNU7TPkAuZJxL0qSXZ5a/0AlpN2s4YbDN9w34JWsKD61MT+0+sFI8+hS5YuQ+d7ZClFAEx+F95WDf4" ..
	"0vo6BKE4btzc1ubSKYHSRTO3bdbSRU7qduaid9O9sbQDoUNhf9Jx3F8D0OSvK4K+7/CkNauOIVNs/vMcYQbl/VMmvt4IDXqzS3L4" ..
	"4Fj9goJWqeDLkt0iCt4wZ2aZKczoqL0FOxurMbK+0l7XQstWFnRSCVTp3vjskaj9xFK+969S6iheDmCxDqjcDL7QLJSl0wA/ZwMa" ..
	"pfCBU/LLc4U3NmYo2PjoB6vxs8A8thus0iryCwzXesJlWgMOkwbyTKzz6HAP2F5CiCgrPKwA5TBp8Yq0DUkFcIsjmaeq2yyHKL8v" ..
	"fcUFO4caLcoSfiU1EcpqWW9LJoVhNAi7Rf1AcGzcbZbeh/QDIPPITjE5kwM73D37T3Wxo4dbIFAabHEwpE3kciYuJ4UJ38w9lEQM" ..
	"wg5apIzBuCuVhBAsT7D4p56m05KjETw8GNZO+jQWlqr9saGcKycRNtKNiva2Np2fNJ5WX+CH9ucc8nDzwtwnNuFP2jeBQ4JKNizM" ..
	"11y47mjV+yOESfKfJGY0FWYCCJ+TReKY9HYTCTa06aIAArfPx5EIN0UlN8myrzF8028eepqmgtiS13tQtNzJw0pZ8tjI71u/z4TU" ..
	"hfYPhr65OoerD1cre+3v6oU6Q1K+pXCIqG2GK1edf+62Xp2Kk1NTBajNab/uFg41p+BXkcrg9Y07ts4yKTnSPWKsPSUB6FbMdXQ/" ..
	"U68lu4NyY7D5KPSt+1AXb3a5FjIusOtA5JDsKl5usr25w6g9+iGsBLKEBBoQOLTdoIYCn3YTHl+Q2eae5mC2AjmrYAfbhYrk3BxZ" ..
	"llUYvEpl3m9P1s1xC7gFTJ7NdpmrcW29822+HwjdbMt6OVQ1nshBYqIjbo1cK0nxPzFeMYtPIXfVH4UiI96fUppjE5KZJkBwjIuo" ..
	"5RV+C3vqluF/ixFIrhj5u0EDiU7sOv8W42IwN5IZFaagNqVHPQFT6YWJe08ZFmf0kbPfXxWh7pWYdkgza0Sxq3xft+ikrAT9IzE3" ..
	"vVd2drpn93RbK+B8pkJqkwaqVcDqmbOkPtkzF0ddiNDlJyMO5aKaxA7N2lHLxDvzdYDiMsqa+rPICOc2hMhjYlXk1Ll9WQTfMhMD" ..
	"tEWywqVY+f1pHK4oyq/GWy2Mm7RFkdrrURWk0iNK146OaG/RXK5uIgOEpck2koUwrZWraQ4NMEbVqdospFiJ1NLR4L31aYVR2iby" ..
	"eWLBxaRIXLn42CWqfSvEw00N9FzFy/fhDpcljX4UBck3GeDyGmRYtWqchglNXCwovCJC+bE2wLKBphlkk2PnAtMQOStvTl4fY5jW" ..
	"8nvjHe5/JQ3kAt61jnN55SzgMRJxvtToCVrYRdlup5UHW7akgW/nJRvkHUuWmdhLBUuJEIpxnQ/krC7tUr3A/qev180/jyip23B5" ..
	"Vil+Xv0FgHpAzbedGhPwIYI4Bk2z1QldgLEUv8L3ZbyCEw4+h6xXT9KGGamkAV6rh2a2mZ/M8+Uo+w1LhmwFlfOUIdfRyDCK4+ux" ..
	"LmU38TJtD6M5HefOI0FS9+4Y4Lno9iH7rpIZgLE4Qa/MKE4XgSzi6QB3AEbNy7jtQ+W+O/n3HiHXQbluvUr/OwSGvCnPOeIHfX6r" ..
	"0yPJmLwdgKCuJOVgi9Ot2zt2Yf/k/nkJ7LqT8P31EweP61cE78I4kmoa8ei5rcgnZKnQf8GAMUQO0P1jDSACDRVOO9Scno9hlawI" ..
	""
local PAYLOAD_P4 =
	"gkDNO6TSy7/fKeIc29UUAeJ3/iTIa77YiXWNfOm6y7fokrSbyMPjwvWZCsWNAXrOS146PhI9Afr3ff9aW2lbn3t+/K2Vk9nXRZvo" ..
	"soQGv5HXDoZ+80sfTEOLvasTbu95QGPkjeqzgSDCCyVCqNgWnzxBV5xa/c2ADMN2dDGe6pEgG0Qzma7O4Cm4CKVMccKeXJZR4vK3" ..
	"/kEcuzVnHQxSUxxNdjA/C1Ot7uATGFpuC40W7+6HAVzYsudbHO3jRytml/Yc86F0pAb1FU9MNTc0IuKc7Q9FqZR9y3czFWGIgPjP" ..
	"1ENN7m/ewQtwXoFjr8WazWEthH6SujlBrIYTIYSOoH7olyx3MN2KzHlbCELEuF+rIIupHZRBt/HoCH18iC6z+EwbO7zsyiGUJX5J" ..
	"jkCCqrJmJ1hoCAeCmPuBukYHM/ZecKTtZ2QKz3DAoI5rgtEL+48Xjazd2H0LV1gX5ZXE5nLfK2zc7HkplQLL9rKbbOCpRtxLSqJS" ..
	"JDtCyM+eeIB+7wVk2fe8xSxiI4Of9em+JpFlrTpUn/MfYZv2trXHN9H7klOT0xopE8SlkNK70dUjvPwW2ZntFLd9Jvf4v5BfYqBP" ..
	"e4RiCxNbUmhb/Dv720w59PlQa4QXXWWYBuLNI5wa3ECWcHuQyLf/D1hzuDUwLBH7BbX1XHiVNcXbWUOi7vHF1jho1nFo1n4x5wKo" ..
	"2k280AIxolA7WpZJTq3IWE0LPqdtgCKni5WFhh8uay6H7R9N0xbtY41fuvuu2E+V0q8FX/oHM6P6E49LBigc+cv5E6j5l5ZOD2dF" ..
	"GKMaPV5pwKpt+6WnrTgVfetxmhenTu/DOII+eMmyM8B307N/qr3w3I30LHrFxeo0QiEhlUyKKZopePhIwjHjd71HoSrok+Cqquud" ..
	"FoF0mPFjgIlz7DmvLmAw2BuWNpwWIUPjLzuXjyVsV7Kubz84+UTl2g/qi64qC8CyaseANX4pYiLavmRH5HXtO90qU3DoP39bBHWa" ..
	"CZri6I3q81vzBo/emsCzwvf43FqkMHBgR4aKNaGUl5w2HDackSJS+ZUs1O02WFu2Lp8Hn11XzE1Pc/eN07lMROPWtqoHJ/bK/uOX" ..
	"YJuqNRgbIyrYGtZEmMgwigECCSGPrquXcVNoOsXPT0D8Ggi22YyjWuUNw2QrdmkwT2D4kikZG51VbKc6xS++ITCjiJ2laO1zCOJD" ..
	"2h/cw6m+eeYhjfMLQTo7v6nU8RKSiyfujV0QLRO+hK/32Q8LHySBB4mrDhWVSQjCBZ3T+LGR46Nnvow0HWxyYKCp7+zzxxf55VDD" ..
	"0XIvSgFkgqKphMb8Nyk1FYgj2DoEWicNFG2GO77BMLnxbqAFJ9iPGhfqMEPKGjdaE20AW21NcYJhVkgSyqN06Fp6g5c3aMoZ+8XL" ..
	"nqvyURbzbOAo87skuVj5DByzQmwCqSHFGezG+vgbfRr9KX5YqwUtANrBjx/1hCauJse4WKgG0Xcv4O70vFZI7XuwE2ZNFlsGoWGN" ..
	"DgRodkULztsiyubSeUt7U9/BIhH2eGWus38VgQui0VJ/bC5ad1vaJjBGbPHM6r9+2W2KqaPfFbcviu9EqVzMU1TgkB/LhrB5uv71" ..
	"FSlsNprRHo23mdUOa9xtPCBwdAg6iisLgDI+pMGGL0AaqkCN2gH3FEiF7ld7KAsVx9N4TGqffQHq7hIVdsvpLgoV9JCOVlwn2TZu" ..
	"eMIEv+RAK5wuH9hFk4S/8SDuV+m0MON6eEGE689dkoi85X7MqYnhPyqldJqO+79M63CAUgw7qz762wZ6MfF4Q4ki1QpUJwTUDR4a" ..
	"IRAQe0t9PmPspcIRJQaL91q0xzZZCmttW/luD/Qhi1On1g2hx3VsC6aecbByBsQQm26T5ZmQy1ZEYxrsNan1IYqJ9Gnci+EXPhGQ" ..
	"wu0O9A7A2rc5S46mnhT0e7x/DYxLDjqX8/Sm3SmbevTai3NBo/xZxmHqgaWCfxPNKNWUv9FQAvTD7jzTQNwtBJI0i4Rn82RVoaGM" ..
	"SsGZrSeOjUDoVb0/us7Saa0n72ptarsazs08SW+UgFRz8inMoWoFkxnm3J+496dXmkYt1zCGb+MggaI1FUhBxfzns988by/TvvQN" ..
	"BsIJnKnhCgEZzwK8+TmrJAxtpHDN9Q8XDujT5XMmWVWXB9ZbJWYgSCNBb5Vj7majGunXSY8w/BAhd6jB338MYqVctXeRby+NkZBp" ..
	"aDwqdk/1w/uSRJFipQyMbk1gvHGMWKyIyQjKkGHrEasZ/yNkj+zJxfdJkg3kW3xt5DsjWqRrt9wD6JBpijoj6HBbzC/0VQY2c5vv" ..
	"zb1/pQNy/N0haN2buCut7Y13l2ABsVYrrZ0hYdFAL1cy29nJiHlQQ/VhgfN786P6QoOBf/2X95HGn2sIazbMJTqVZSbQnUD8M/Zh" ..
	"2XtYPytHKC/mCIw2bhaUcu4fzT034By3X1Fv4Une9Rp5RDftKiKe/NXMt1DhZR4b+KHFwC/NV54tC2CC6sO0/AwqJvPqJvHDE/t/" ..
	"r4P65ofFeEqt42luPLZLxCBNVkk8C50rmxgEJdhBesOunpQyOqIECZ4Al67Xu4HXgHVS0do+hCYJQ9f/+oPdNLmSprAuhL4QyzLq" ..
	"x7abR5WZRF2Yd18EYekUdbBjzB68A4vxwhR+nDm5Yd3pnh+8Q9l2pO3mtnMuG9HPY98rTd8y9NWvtBEm0oarBAdTtMTsrcmKVvUv" ..
	"QFsktcva7yT5WRMCrNJTLYzhksraQS/Fo0Dj09kkFg2oTVCsZ0m6bEE4kID844uZBAgr/y4GxjcTtQdYPGtUkOUetebos0vmm/h9" ..
	"SIZzv6quQr2TCMjrraWQnxKzVYjp2cfZTjYhmF2YVIQoZD66+dYIt4shovS+z2OI1BLgoGuiAuqgv2X2XJ13q2zcUGinGoi76XVQ" ..
	"xmo6NmSwMMQ2h/RBmbqKIGZejrYM5N52lpOrG1ZoFKKB7vvDfsKd+xyb8yBAi9zIJ5BxTRlyJ5wj+lBo1if5hS67bYIHfCnbZzZo" ..
	"H66dg6If3rzN7kiTdFHaM5mBYzlddOqTJvFjNuwfHV2S2aJZ+b7+32VBCyP6wvz1Nn3mPlSrh4NkZvc1Mn1E9kbcOlSdtgHbq+h2" ..
	"KjpJpyxBHhwIX0w2pG8NAYGKXeSyEMO8JDmW72jHcnChM7CwKOdl8wqEuCNkwkwgFr2znD/kPJaeQgbsnErqBd4a0jTmk+YOp62E" ..
	"5vOTp4Sl+sTYRf9wOQZnlYxkBVdaAbufeeIqh1xrzmovW1VEZGuC0zr9mD8Zd2Mkqv3J90g1BkjjRbpc3DuwvbrI2lDiJQGQTvxK" ..
	"CqLm/OkivGPhozRt+8b+Tqy6Zo4k3Bjwl8+yWeLa+xfZqI0I25YD5s2hRnVfSasDwqIVkXittQeBmcShf1kZGRte3YCCcA0T5CRL" ..
	"Agsc+gI+e+R7PYB8MO+SYQOmSk4lifgw0uFsKzKP43N0a2abhdr7RK+IFomLlJ1pApHTtC2wDZ/bAo3bhFKki/Pve3BjHmsd6nFP" ..
	"lIZeFsd+tx7DIixvqnoMtPcfBcLP0bD0D5D/jNdGMtuveRhUzu5FnOyxAC/Se8YPNQCnjwTmZEg1YLbyvOuHeFCY2t197bDdYFhO" ..
	"Qj8D4IpHpGaq8L8O7E0UuAB5eI6vJrAlaYfsKHsf+5MUIeK9lb6aiPebI5oikNOntbSOK1CoDGOkPB6CTduIAs8c5FPG0hrB6Zzq" ..
	"kSfOMMxQlqi7RwCHxNtWT33guAQsQhnwPRISzMVF9fwyctQ8TigCFIWWPqaBE3hOs3MqpIhaioBxxlw8PtAqmfkhUOl7LnnR9vCX" ..
	"O2hbB5vkGYpqJbVpHMW+8ifIlDEmzkyI28HX2PjZw0TMkamcclacJUzimLpnznrT+dXapWDWW+spy/roLkHe1m7S5G789esUy73S" ..
	"RYjHK0tWJDM2TU9b6dbAz+JcZWsvBHz0TxSBo42r/SQJxboNFt/k0UuE+y5vLVjEj6GiftFx/jM2l9kQ/BRVwl9VvYlX3ZJzkJS1" ..
	"CpQx95T3liVkSeC/OGOi5DAo2BZQar9GJ0LJIaLtIVREyHiCfv6A88b9xQxm9e5dfTgPRmYs6XJ3sgzulEp8IvhmUp8DS7gmEr9L" ..
	"m0+DChipzmn73g8jTwaa7SjipRGuMpnuFpWXMK/yaGwOEVxyJsUlHeLgkhuJQNwWmhliEBqpXObN1cDSjQZ+IpqCGsv7O8bknEI8" ..
	"KjJDexzfcUa3ndpJfFjAazZQgjgq4De0wnyZElqYjWsC7MnIx/NqgcX/RaY15ERIMl3UZlWAYGKboAdwbgDVJbIaOfoKc83gNVqh" ..
	"YiTRVdXK52XyzTsk3S0GQW2OuA4YvSuYqfHrHiF7OlpS8lISgSWJl0Fja3Vio+/i6Zn52jeyqsItGuiQeD7MHZIuhTG61Js6Veg3" ..
	"2jE+tUihe+0HS7/kJ6///88B+hQ6sm3ps7lgVHxi5cOPwlkmrRy/Ox2jKrnqdD+7sxiaBD5AGb5RIdOhXTlik4Yam7yXiyhqOPb/" ..
	"9uEo3RMBjfdfJfQC++oVBxdg/9Xly/exFmz+zta4oi7y9g6194ypNM/kPcBFCt96bLczDUxn3XGGkj73NGwTALk/3re0JICd5KGA" ..
	"ldmbbReJCCfWdxsxIGlgZ38FzXhnZAvOqt6iDyhD9O8JvOJRm9OnRutCwaOEvTjvFqEDbcYgDydNDiDoK5QVIE1Lu+7Hx/0DYLu7" ..
	"DavRBeMveqBtnEdvIuBVx+uJOIIIrxsnTNYMzpHnW4Owc/+nhwpA58fVogq4rlyyLAj0+UVDxDqlPebH8frPmL1jWGm1FJOjWIxT" ..
	"V0IVNzxtx4ul/Q8mO4EyyM0NISr0kmnczCUB60ezii7pwvWcRJroDnWojh8YUJfZFDSlfrfD2+M3/+ECvHf+CiOKqa4q4e3fO4Ep" ..
	"kLS04ReUdyCnWWhwVg2Q0RWrFSbEc1EBzLAQFgIjxoOnnntOZrtrL0rAEAFEJMK9gV4FluYPgvY03zLRc45HFS9/5m9o68U1rwIN" ..
	"hiANvVAr/KeaFKMtMgTLEQiK3FarUP6MxYhuJ2cqT+qj/y/zQs2Kw46zmGIauYcfN6d02KI1XpEDmITsTFpmQrXB79lVAXaENBBj" ..
	"SGbUSArh7ZFSXnYf8548RDnuQ1i5C8ibalR5YykEp3v/roOj53lGh70aoyERNgwHWFCrgfIrn3YnVMeLNkftO2bipAewIalMOxNq" ..
	"8bkyqXKpa97EVw3g0vgvaklgIzZ7RoI6+hhRAsa34J6S940vmnc29y1L/ywgVgTvcGqTwvI8BMrMJjM2e/4uH+Sqe1guL29fCtsM" ..
	"5z/0kpeiHA0Zz5ApwN6aWj7ahOEfV46RgvoDSXvNmBdQSr5S+7FkZV1JVS4qpWn8V+Fjh+Rrwa20/WXGqpM9qVRjZP7Zpz56/SiO" ..
	"V8FfAeolGMNXjZ2QUqf/XdIjnxTYZy8wnOnvqvrGk3gaDrdWDU+Xa21saoSRpMpAB556QNusFUknZblmdFN+KZNI+EwhSNXvxIl5" ..
	"rV7kXtGfusY9hZ1is52vgl8WVAItGlc0iEQzLf/DVsjzp6DdKewIYNmE92rrNHTHtv3vsAl6b4DpwUQ7ztwXyCJ8UZ9hlKgZTqx/" ..
	"wiLS40SdHbS82fO6eKumvgddyEci5RA5iMH1b/PI4LhUnhWUORSIhjQF1dKsqGjU73hd1PUf9eTushAOfe+Tql49TAH/3oZnP7ZP" ..
	"PWmEMLXH0jCX6yi3qeXbm4H03dnQZ4YRX+9yaH1qnPhsAXV3X9mMbY85xhFSyLNIdkPsqVok3hMiEpaDXsNIry5rtxWektpkbna7" ..
	"6bEvY9fBD7Cq9iAoHm7iLQ1f3hQznEfH89fFn24dtpa+2HEpSSJa9eZ28qLNl6DmUBz2KYDwkzfY/JYCkvelQuulwYCNUyMpdJKB" ..
	"tJpbeFmb2QjQvL6WfrKRfDYvTQEjIdgQGaBguqf1d9MZzIM3dNzs6MxGXJ5f5xW+bBrWDyhbwfLB53p0Dath1ODz5CwTUuOy1eVP" ..
	""
local PAYLOAD_P5 =
	"zLkpQUyI2xRnNGpdQ4DT3FYaUytQV8/CRTo3luMG4fcgjRFfjG4nEMGuIZVf1Y84sfnOJjH9rzjP45eNHqURtubadyG+kjafVz02" ..
	"V5QXqFoNo2CE+ESL8wogQEyMDOJai9db8umDcDddNLxULk6BGeA5MqBJdM7hN3aXZqh4Tv+MzHS4rl0/b8cyEUSZFyc/84obRROo" ..
	"Yk+sjQvmHQUVMIDTbhn3eqDKLGhj3I6tSssCJ//PWp+6Md6142GQt7CiHN8F6EEL5Ca69umxSNX47hB6iQpa6ONbBq03AnDVVN84" ..
	"QhHvCW9tPesOUj493WEjZXB1H6D5oTvQVP3ulxiQDma9CP8TRYuhpMUGEeAwNfINl0a2mSr6HsmjQaDUgz1af1HHgmmhzR+7cnnB" ..
	"nc3F6oSGoa/mePwq7tjNM6JbxIfhXGTpIOOI6O1/1ocA+T7kktDoy+kZWhCTxOFYDYdv9/HvYqgsln0HpcvVEEC3RFl0VgDa0XHb" ..
	"AZbFIkHWd3AAQLZ380Akza4dgrmUyNdO0xx8q3rYsn6Qo0cEct5+gv8Bl2JrTSeLqQ6V5PxaxdnhzIOqDRgMR9jNDYnYAfyXLHZ7" ..
	"XpLzpwtjIP8R8qnVEwupIGJdu5wNe13ldw5/n7Jgtp56rBYGDHNsqWx8WTK/TtojulFWc+OU+hJ9QkGJgqkzE6MUBSxd1ypOqdt/" ..
	"DMsQhNnnafeEmWjYfTS0ShODF5mLzn/qzmtdajOeqWQ50Nb7+csc5JnAKuYoBooND1Z7gAHpESg91KY7clMpGSFHrZtIX5JwGHtR" ..
	"llJIn/i3LSckRNmbL3F4x+bfdEpiEnbE8jN9sGK0XfvEuVVjT34Yl237UOmyPffw+2+7VNjhbkol8GO5P+qYpfL6KbOYYFaZUg9i" ..
	"j6ji2RbdO+9DJVYwBBWAf9QZ/ePKmyNRuTH9ofIqLFBCxr3BLSn4nXbr9bTc8UPtdhagTPn7ptDZB7jYD3bHo294WYS+KcXmRG+Q" ..
	"h7afa3elMpSU+00xhWNh3T5KSSg2L2CApjyqyE89/9uJmuZ5bVEHZjPxWFLTY7MtKPdgT8u9AViBDMa8wJmbZiCAKzMzODKrU+zE" ..
	"RqMlxvZgYV/f1X9QGcYQlug4I8CS5nEyBrLycDPwVxO3YppDrBT25jwpPNhTLWNpJtQxX0Zr0zmOEob48CHpy+AoJ8u0LkR+wr6k" ..
	"pq4iN636OIbOVKB2bhHQNbTAUIaJFkCX8AP2yPVkD1f4enF69ZKeSYeHbY/hEJ+psrMIIV64NhnAairloZGiiczdyLeQWkGRLrq2" ..
	"nke2CibGVYjPoC//xTc9jtAD1KhH8BmCNZkRa1auxyNvVprk4er7eA0sl1GMxmKYo1ayJZo7slnK1G97H9qlrXM/K1nsn1qcnID4" ..
	"lfxEmsP+7Mywe1Pvy9x4NKOQabg+TYiX6IvM6hu3EJw3wa1qyVmuL3zz2xNWo8HO4fmvX52YwMlbF/7NjZdV+TdzwIqDwOCPdWgx" ..
	"fSpqJjGb07wLVmpUR1iOJMyjbs7C19Gt7ogrxYB4OSdRWex5CATmcpsrOGxer7OLOlbrEzcW5rzE8Vh08yLcHku/IisPypq7L2wS" ..
	"lc38MjjlpWB64v24i1n5gBdR21ypTVbzT7uWnNo0lmP6yRyBBcpCXg8YsJ7rkK7xr50mQHpZby40Y1g9x7pSCrPnpMpTqakTjIa/" ..
	"UAkmQDobNbq8rLk6rKN+tbP/yezRqs//gVT+re4bfmZVbVQNK1LtSSpvMR2kKD+h3NIQjoEvwKlWwXzrUXItOls+tzWYU4ZWsuw6" ..
	"wEtQmL3F6K8zu+nYz/HE3zFnmrokfGm+QJU2Hhh6IsW+hOjuo8VVJe0+F2mwF7YxWOm7LpmDFKVinroN6yCDS9XHBI7M/ZjwzI+T" ..
	"jqBxsno7ZjwgctoG5iC+GBXGnHin9XpevrvYsh48DYxF6+XX0cnbusYd27LkAX5O00r7WhM9sBGRL5AhqCjoml9FjZLE8gR1OspV" ..
	"uPb6PP0lQZ4F8R/nHVKTve0KxCmbYQR3SLRTZa/VWn02HTHbgiKHaRH4AM4P//cyXo4hKYglFAcOJKE7jEevevy0hjlJL+2XGCt+" ..
	"03MrchaEpxeuwsXllKCt8iHlVJ5XP//YAWcvylxH6yX6HQeBo16I4lDJHicOflelC24Gb0HpJXQM3xt1mNp9IfWClv/p3Hhqph+A" ..
	"NDVvJmZK39nJx6+O4VE8mrmuNSx6d4YN9qhQ7+HsjnF5gMW3S3pbmeDBUU/8E9C64OCfE1MZsBQiRy7iBmOZzvAT9AsSecs155F4" ..
	"aVk1FW/inCi6Ut4fecvQ/ejEgAqlAYkXUWpRIu66OkBSY40UMnOzDxBNEx1rG6rf6NQKiDOXbzmlID7iBFRcKhZT1Zqzx9VeqYQv" ..
	"qHr7j1GKbn0qQBh/BKu4QDsI8fe1XqOKG8XbiTIermiUiQRyg7ZaxDmfkE788ohvVf3KTf5LVXn3IT8rim3LbCTdImX6K+oYn6EY" ..
	"GncaFzvE48bGbYxm8pjReGydBFDpY/5dSKhn3ZCTkmtREgFGMcCsDkN2HQYu2B9sRdKBTyjPiOKIV5gNSF5FF3mHfT59/ZGMJzXZ" ..
	"Nl2+JtrZ5nIYTA88SCFdD11PfdwWqtBFt5Xa6ChlBdOl/c3sMbev1J0BNAgupmm9L68Wc5EBn2u/GAU/yQ5aOPWIrYmhAT/MQu9R" ..
	"J2Q8J9iMznONzBqCLHYicbaYBTFUaNdz+bGQ6NI+Tkq9XdgZb02NurCJs3HYs5CpHobWH1lwCin9eDrQ+1p6r49+zt08aNPhlmL6" ..
	"WfR+XuyuF/yl1TbI1bA2wqiIZT1gGV/x6wU5eeR5v0rxTojafzcWkx40e8zQqeNoF+t7yY2G4UxAZCDzf44q6he6wkZXsnKxhCIw" ..
	"y3CeByzOSz9HKyh3QeKz8h26dgQZDfUu0za00/VxII0prv4ZGyOQrmfs2Vz4vtrArqy01ESjNFWfNjvmNfgPkQcR+gprik0UE1r0" ..
	"2CvMe7wQJ1Cjyep3BnDR9HUF1dGcRsyeDcptjGSiQRKXIW+0vmK/yro8rg5QDU7XM663YxDB5nukZnNyrTaE2y5yPRFWCBvOR5TH" ..
	"YSgYMFmhV69OMc4aRInpwJSaBTaL4og/f/6r8m9VBPDw2NV7kw4KZUik7UR7pGYVnAd0By21/dICw3u6FYO6j7bunGnjz2Ben4Hy" ..
	"2rtzN5DPCfEx6ORUvBnUPB1LbE8iY7C0QRSFbtnRO/rwQF1ZNuiHAWD/TMCoZkMMnj3vld8KS1Znkoj4N25rB1w4KnqREE8b6jQm" ..
	"YUBm6ufZBrsN8Nw59g/FX4fpDDWFiPyfUqBVc9lkpoPoM0s8YH/tZD1nD6Xezyjx2eMU2UGzcKnE7rtQYG34qABQH8QlVXlhOolU" ..
	"Cb1b8MGGrSAThFBjowU5Bd40JeqNkoZDLuW49kdP0AKXI5MGjUe+HHtQhv8RJvamIJ41kzkdIwEQy/aSZ8XKxxPlUoRjoqn6ca7h" ..
	"nV7v5IBuJDphvrIBBT/ToL4sBHatFUqwLWB/izRQb0qDLC0Tq4IFGZER/iEUf1D0g3xEgr5NXZ24E+XbEDN01y+9/ei3bwEfaa4n" ..
	"5TO5XSseS65Fxkk/1KVv2tvT8qgr9MwMUY2Amdzh9un28x06TVlqsbc0dBog8sghLXL8ZBrsv4RFQdJo+Jw/qA60BjP0DIwPmP3z" ..
	"ZC3neDA5iDmgkHzdIY5QQoQcy3ZZ9+WO5jMJT0DlQPgCYbs8XS0KxxPLRZZBFl96GdWwalqV+xNaUmym8RP8hlQyy8GoQyjRe4tn" ..
	"05RoddEI8KhOeKfO4/353PDzIvaNkqU0ncAbbFCy/QB3rvceOpf3x6I1vQOPeu+lwETLQ75gsjPYx2gEcvxCdNUO7cmmdHiLwQi8" ..
	"DnP2KIx7OyX2J6mUcVhs9CxD8JqrbGr3nkTBnp05HKkL4DAIPz8KW/u8WvTe7O/VEOVeJE2BgtI6fAe0GRnxX68/bMy+aroNICHA" ..
	"0BzUk2Uy2rxqAGgCS7lgcSgOmOtzTDrrU27fm3/fD7x5wqORm5Q7r/dMtiiWdCPZ81pLkNpACwIhKb+Uw5Y3U6O2xebvArjlk7FU" ..
	"ugMZvrycQIhtjYITavqgTrklDuHgYpwuTKCqtHM7HkigBxIATZVXjMib6TzZ7M6uaNkahmeXbxWv/ziadEZDQIHoDO5llxYe6gSs" ..
	"0ZTFJFkuBlvMtexgc2VQH9Z4vtCHKsuvMjEsCqiy1SCgttK9vSx+uKYURcPixh7Kiexq7U79OUA+Zpw0zsn6votTk3Fxwkk70Mo9" ..
	"R6+c+l6DfBOmIFHERkJ12o9aL+StSoT/wObYrf3cYOHDeQmCv7bB/HCNJGfYEvhS625KqgFrtcHrjgMvOB+wvOhUTAgfjJWNbS8G" ..
	"XWSeCMV8gILRwsZQErkFvQgmPezwDAVz7prGfo9YpTHvuETYH+AbLGYYGn9FQv9x+UeSuC9sTXnEYj/UWxQM8UZnabukXBeTQ7bc" ..
	"gZix7sRYkkmGylh6Tf2W3WNBbocSPrpDC1bMNIkUr+0LY2PABi/8V/SxeyvRAEWvJC5CKqWQjn0WpGiWP3yypsQKOByrlNMTNVw6" ..
	"zFOumtED17VG0/2gAA/ioqRUDUvLHPKbxVjSyHA7G9UEWxsJ0PbeU5hasDDg40DGtA33Zvn6dhS9vbWTlrRDvsBKaaPhlvMdTcgm" ..
	"iDbJTt9NuHCljH5EAKlIkPt/UZ1g9YAGqW5sByHHdGYH+S0RJ+Q5/phaTLmwSWq4Bv1z6EC7tfjyLky/FY3NTx9AvmHhNTezG17W" ..
	"De3Q5rMHYDwQyE1dE190WcnUfHCU8yN7HNBUJDSF9mhObfCF8H3Go5G/aayNCmJ3Bu1QG0Ej025gaJ36sRvkZd4KtOwk4RPFce/N" ..
	"Q5EdJwHEWaF4SFIztsdCvbzJcsSL6guUEh9ulThGfubtoBraWFF72PSER09zB1SqKJDtbuNaHHPC7+hHNur+IiCwpVWfFu1DJJvN" ..
	"qkSIcs7NdL+m/UKrCp4u2/9o/GdCU04HsfUAL3c+nD8Ren3y5jCQhnWNdtMwFtW2vs40XjssP/9tV+CFhMd8rKHjXDU5Bfm1jLzk" ..
	"pHbdukSybZn2Xn7oRcLmrPIJD6fmUoToUveyxxlWNDjVSQ98iINaz4EQbJ26qHCAiff1CLNoYAc+RNQueEI0spLshBGDeUQasYNi" ..
	"QgCZ38qgd0N4+JgFxKfh0JaynEtrNNZz0SkjRRtVOlj331TEZBrYJbsDgn9rHyjfXnZpk5BRuT4Ici7JbtZLv9IBIPyQpVM8BIKU" ..
	"SgLL5cjrmsiVtuJhi9wIGgHKnaCqj7RQGgZcwryGBUKJluA4rAbgcz+K27iiU3wBFINAPIUoZLFuagAx5/7HXcyCqcq1xH+DJJgw" ..
	"j4y3D5pwng4h+PlW9+2X3WfcQ488LP0/OVe0X82buAT13Sc83CVObDxXgFwQuvFlLWHKVTnPO7Byjlm3XJo5kV0GDvLs50JsrCHU" ..
	"zb/ioPRRMiAmEU51jihymBRWRGEe0/mwy+912S6714J2oz1fXnjZpqijDQ5K6akHOG9g5FAAXb050QjbcrxSTHx4ZI7S0iauH6i7" ..
	"S6y04hnzY3OmnU2/KmZFB94tri5A+YAAgyiGRYXlNVqoZgpqR87mzP66i1iMwJDVCa62kbCdBE461Ea2+hwYUO0qO6SYo6qKkNnF" ..
	"mLhFBsxmxW7u/6Nby7K84wyX3bHuB4xTqfI53oBjnaZynFG64n1n4/P/HFBNDzuIesOlVMg1HGRFycW+w2g98EiTG6CtQU6Yf7Fq" ..
	"k4e05NVyur9BImLkwS5llKEJ/LDY2fLsLXmReCfsP3z1lzX6FTvyFDuH6smDubdhNkMuZ0s30axjg+iC1vanubVrOGtAlgt9Q7iL" ..
	"fo7Hc5WAj09w0U7CjEJkw6m8InsWGXdIi4ENTthHivAgqwH1sj+/rAxNES86SmABm8BWHsrFAdSp7sed03e9Sh7UnAXY/Xs8JzQP" ..
	""
local PAYLOAD_P6 =
	"adnW1RqmV5sCI0qnseC1PoJUKw2kdFhnm8Qlwj7SZJxqExctqynwOxuYDpRc3hXZPct0kGh2El2zXSCeCuDJD7s2o7xC7mCPrm3p" ..
	"zXNQYpcg3VmwPhiIM8GMrZEenOJ9eMx+W4KPzVr+QZAB0YMCDj3lYIiyHOki18AUOz0IFR1J0del0TjXKiPVcNFjo2ufYcW6P4Bi" ..
	"HP8mboTGlgj9NFBA0S0EU3wl2x66QWfxWvsBeDmaRC6Hx6dgPQPe0jiGMXWV2SxAjxXh+2alMQMb/zqB6f98BkYLQnWqAYqlc6dT" ..
	"mb4lbtuMCJdSIkTxwepRfQ8WlEJ4R8cFZZtJiBWxKcZmMX+bnBnCgWiUEUi3eMXYlk9RINoFkS4h+dKC75i2X9/in7Dr+YaoxexQ" ..
	"h6n/QVunvUWkR3BqA1uwS+O+20AP6GENHBx0TRJOUlRMKMWfG3JAQsn8m7Iso6SL9Zxzd2L3UEMnVoBeUglopJ0kByrHrZ0VbYf1" ..
	"/WG5h18jxCzSWIYeMr7LbLIWNHJ96oNvQ4VXmMB39NQ8KpC12cFNyxGoqSQet6qIq5b4eqg4DpnX5u5izBEtbHuGZaOpymrTOoGS" ..
	"hACRaKNGwpWeW9KxsjEIXqgJqx6R1UX2cfP/mJ5w4NHNmrQDwfzrILRTxwC8eNuRzI8/PJt/YkLotuRwEavEbq3N0PrGvOlvwKJw" ..
	"JjEHX/PRmwS9hrmP6vp++kVtC+YT+1mGKXDHUxzR1pFI3O8OOFyYHrkDpIMWw0stKp1Pmi+4dl6Wf5isFjadYij+CL4j9DI0s87E" ..
	"mLd+T0Wi/QxSPT+4/Xw2inym2aclRIEcipjFXHWeU3JX9QS8ia2HSoFxWpFuiGTQ6glKUn476Ri8CB6123liezq0X9m/kVxKZQjz" ..
	"mBDdjGdipcP1lnJ6/OMqTjWg8+jpz82XFOWeiZOQJLE7QQ26oTpra6i9RdbIY18S2jZImgkf2EOk0nau6IpyWQHqpa3xm2VfFum1" ..
	"QUxErGIuCWPjkcd5Cjtd7imlxQ4mgLxuNEns668PMT+JlBl0MCIKwlNCqGwd//cFFoXZ6g4bUUU/Xmeij+OM3PmTRj5gZJsj/arQ" ..
	"cspYMBfwUqOVfAjeoUc3HBmbtoq+1kqBxoeIgeqEerOTN4u1RyRDhzaVh4NNMDVpD70a2bE9aj71fvSaqkOeXfBQr7b14Wq+FDtZ" ..
	"/nQevSDqvMwRK/TZgFdIh1m7clGYy6GlBYkz+C46Iv51Bmj24jc22sm5f/ZyqQVWpoE8E8ni+RkpWPXRJmLAfXTd5EEea1jYrSLC" ..
	"mc1Rk2C9+sN/uGKjS37E5xosVEw/LLOTiiUKDtd8YOumKM7fmhh9KSWZjRx+nIR/iWAbmJtWOH46s4tTV9ZUF50QRqCekNUvH+LY" ..
	"k4Gb0x/6V921p5X3ORVee9UJDVb2UvMkzvQTpp74kZnsDgz+N2kO61Ik+jy7BirpP8f+tHSb30iS5FcMKXWoyJy2Ad9D8jWIRc7O" ..
	"bDCmG+8uaikZ6RVq3+HD3M1RguzxeR9IF7VLtcYg0WjwBz1E/JIVnW8jWZ9TebCkkWG2zkf01/JT5KdlL0/bCKYyYpu89aDlnqdK" ..
	"d0NLMfKZYrr6MRcVqlCjL3pJCqUti1PWgEd9FI2a10SAllgzpLx0J6u/lwQezgjiKXKdOh18M6F3y8hm8Jr7cHYhO85+PkpYWEip" ..
	"g3WwNja97lMSrNGfRVIHKeAdlgE/o6h2lULJ6990BSXc/KX7+MKolVA9sg5dALjm3MxlpEC+YVjddPHJNlZr2pSekGvqlxIvR2lN" ..
	"YlRo+OB64SyA/5GTDjvsYLmJkFZ1mhgvStQExezgOoMydInDjv90rLe6+QbaLTTsjSUqydIiOCxykLSWG6xuYDchlwAZ7RKoiKRf" ..
	"ciLwo5tN5L8LZ05xP5oyUplzy5Nvr83MQMH0iRCD3mg6VH3vXqFrJ3YgPxxokuskbixCg0U0ZJkj92/x04SVGCG/Uit/zJhIS9B3" ..
	"NVxu74Ba2ANWIwCAo3p17YOLj4/woIy4AVuB9UgwdZOstg1VfWYw2qHCbg5AaOhMKc/zI6yrrT3iMP9bIPLdboIl5fVogCG0dGr8" ..
	"Lm9qfP2XNyeXntNMVDeXAaC0TPkc1vXchVMD8xTuR5P+9op2xThz+c7XuVIynZTGK3M6IIbGkUIi4GA1xPB7yBysxgtCGU9+VQjc" ..
	"vThRpJOYUL9TrmeUgPwDy460FpHyBvtF47HqL2tGQZEnR07saEpCghA61G/RPen6tWO4+QSdXhV3NKzgMz0u98Ll/gs88bCrsGDf" ..
	"mDhButDgGabbNk0KMdK0YwbqTtCsabrKVIQwLYZNzUbUBwOaar6xpJLXGXMGKgX9pwWYlYslaxgnu8OEcYBPdrFyaimQzCuD1k+H" ..
	"9uP9+XBkFCszJfgi7aQmtU+EYUx1i/oraRcOxVquMpJz4D35Raolb2OlMog7pGKR1woKclBomklwho4E/bW3HD9ozemakNFsg3Dq" ..
	"O/yvOiUzjM8G9BkbbK06lyr4KuvInYNLGa7wzRXQQWEPYrCiwY03JpTMLvkV/FgwVxg4FQkeC+rx6yslaPZJlcw9bQDLgabKHGM7" ..
	"kPvoXzk0PVuNeq7EYp6LI/PNeOxBAUvhYCO3hWULIGqvLvidxUQa6ZbRIDZhVCUXLrCv5B18ZFsV38SON8aOFsSxHB8A3s8aOTOo" ..
	"WqTPr2NxohaWaiFfE17dq2fRpdqmuftZGT6AajVbH4Y6j4wHXv7g/f7ZNjqE5YYkxEeqpmnLKpV44D4356VxBg0pBbEky/M3ctPN" ..
	"7RiDk5EgKRzBdQgM+ZmqZ9C7ToWIqWQK6j29cu4xlwLqqx3COSnSHaDvXdFaRA1LZMOG0y4+GIRvGQ1Gs5trUlfNtqOg8SHq6vCC" ..
	"Uag/CrCJBHBh5Wbyg/b8qdsOgoFR7datDK6lCEgB7fMSrI8j9tag4/lf14Td9A2P4fAIcSto1b8uz4ONXAPow7oNH4bkuZtWfz6W" ..
	"zV2lVP35x1VvPevB2wuJ8LCtkh9sVQOn3XB+BuM54Q/PGjUSApmWddjVaixurzPPKFZJbxvgcWhphBeXKU1iUS0zLkrWJfVazDs1" ..
	"FrHHVMJ0LN68ZlCEg4jT8K8B6vtXIyEmcZJACpbaEkSRz1BfrJNCAayoizJN9VqeP3czzvO6rlzJ1Kd+El8v2KlU1iUj16B0sYAn" ..
	"/eg/ID2m9WlFCAx3nok+vsDuXUWUom9IEyJpPldzcObOpPf/n3YBARPTJqqZUdzg1SQTfwQSDdGU8OGDNziIVCbJ5S8GMIURH+e8" ..
	"2lzaR8c/vsb5JAZ3Wh0c51NwqgjSjAQm6aN01QISXLMfNn7GDyzubRlj961KfO4JGQf5g5CebBnLgYQ5JXDoPM3Y9g8E1p3f76g8" ..
	"C8Lwlz5Kurqv1uGd5/ZI2pM8dxPmHobWdbnsj2gPuoidiGRMNj0WzSMrPBigoPBH24sIqhObE+AiqhRQdAFHNfJjqAkLdxA7ypyA" ..
	"ePapl8OACjhnMQ2OSz0uD/wbYYBinh86CXKIObIxGI1Wls5MWjKl6RMyGXSw6IGNbzEw0aZcI5AkUwhSsSeEkARkNpbzogC+tSay" ..
	"QOJHsAkUJ4Za9TpyznAnCVc4Ut5cVM2u7TcvpT5soEwcMEj/1SAo9Jr142ZLBH4Sbt7NMRYGeVqzxMs2Jqq9+7LjK/+Wid0iz25b" ..
	"+YwvgsbnDVY2EMXQjDQSFRaLZMKtqIlAlWTY8Cn9B125RlWzG6V8lYZbkkwfHXH3/Yo2H6sB4MPb0LpsuIYSvFMqWCKmz1n9QwTJ" ..
	"pq3k2H95OPNSaHdEbbTNK/YztEDHOsjgR3NCq43fAMOWIJo6Z7A/BUv/E5HRA6ZrAK9vs4mpnc1tQvM3aBSTdEBk/cbJCrjUIsj7" ..
	"DeIzqB1fI8ym6FbjYG6kh2JKEWIxo5Vcc8dL2m6oLLxR0HCTIlh2hBwcTzfuUZ+G+3tQpvkrrTH5pT9803ab11TDTLoiYp1BQIkp" ..
	"w253OOL+7y2vhUxGVJBjuiD52tjTo8/qwndz3YRaeq/xgsvdRpFRkbJV+omu0SbdSg395/OblQ6iUfKu+9ZLyAwB4kPEy8KfZCFP" ..
	"6MtBS4CCNNr6iYF4MvYOtfuArLicjam5E3+/JK3OPUQwwcj8ifPnbTxZ7VsMqOMwr89JH7sHfjxJuJVhFH8SI04jmSxHa2BtvBcH" ..
	"EIxuadoFuj4h6AvbC5icxQhvsE8CT01yZlsdBWprl4b31RYdASXJkeLoh9uX099djPo3/NYQL9iWeo/HMX2lPvQOtDvkpKEDQBN6" ..
	"G+kg1eCzGXnGxgBi1mXRokPfvyLuEGma7Gv6nxBHwQk7Wm5ibnzqlk5JoUbIDc+nix+FNj2sWQY0TS1QVhEn9dBwIbGlwHiKxAeL" ..
	"bcFRTcX0jBhWWx40uLWH5+mgr1CNjT5Ns6Xxq5dKsUyUOkAkBw+hGUqlTJ2d5Q7p8GLGxEOo68PYN/QjsBi0KbkueaL9FN6+fGWK" ..
	"5ildS8L3JvqMHe0p+1y9yBbgVva1WMy/OpP+ZDd3NfQ2dBXyWxJuU8zqOci0h/gsaa+Bjp/ui7BKzg5dRRa7TJGiY9GkpZdCLCLI" ..
	"PlJXYSiCqrkcHlFttg9fCAQUjYJJOB2RdV4sE5qERBySgGSZk5rIPaZqqun2Ymz4BXDWm7LvfLq3CC3pxKuxvY/wYeXWIkI74SY+" ..
	"oobvTeGnvJn7qKvvS0T8xZVaAr+J0A2eDYbtkBRkmTGKpp/WNPf1HxuYwroiFgNQPBq77rXDQwrn3ssxH27ED9c+982YA6hnSpaG" ..
	"d9ML3LozTyw+xx3p1NKSCNfBirXx3hJbKavE6evUIX3NVzzTXXRy1+p2VRzq5WF3rVnL1wq4pD6KwCJBsp0JtH5Q9GD0OlRLtlv+" ..
	"ScEyJstbwcxd72Y3fvJQtCv9g8csux4uuELs0tDtxm6zQPuUxlZ0S+HjAdAyuRDIkgQdgu2XQJfcvTPb2e9bpPAe6nydNvOGUrCT" ..
	"Oa2Zr1AhZcnN8KPvmgsdeC3O8/QcVao0RCMXKG+NREGzzoG3PujOG38+UwsLzKMttOITIBNDHkiddvrHdTYC5iweN+C66l0te2/B" ..
	"WipOF38NJVr36CjLCxbmgFHaAeJCLWdHbXQM/0scndvnJx5gndRu515vCZNQlpo4f7frEhpLkPwpxwcdjzJfJjWZAlQFQmuuOaFb" ..
	"Uy57e+/3G64wXnNcQe8Md0yk/UdN34jLp2/fEjwTbQbYJAwzydFeWCsDpKhFgywnykGbYnr53fF4jGFZp6VXRZrM4Ec3855blQXm" ..
	"iMx+K6k3reXu+jQkrM1l0T3vzrIBzGuTd/my/PRnPWAGAoUEjkQU/bnfO1Kn+r4wrugRqthpyHEn1imQYViV2aLM1bqNyEcCdqwG" ..
	"LyT/pzgpswE/m9TeoEL4+HiAjgM6L3pV9he0xzVO49hOhsIdjXUuujS36qDYsRRI/qQpD1NxDVCu4bRSQgivDQECSx2icy0c8RPh" ..
	"/YECA5BuhV2iRiQ7TvyzwCJqGwuxjuMgs72XqN5msr8lji8bV3wrUNhKNhpt7KK4nE+AHqIUGewO8/pZ1nq2qiupW6w0h6uhMVxD" ..
	"zgzm9SqjHQ5J/S7g2Ng5UteRgh9jKHkhRsiG7hdmlJxn/Pjlf5SmhCSrNW+HGRFDvdEJR813b49qb/6aUmFMskSFvNAMdPEpkERN" ..
	"gth4VX9o8Mqie7W+XqXgAjLPEEvFWkpk6M5jeyYOXvj4or2HzO+FY5H/8qI1ZzR99/EAIHTO2gjeWddUukf/HfsUdggelVc8G9z7" ..
	"AqoOYgPpgfc6/AeNzJtRRGiVDtPz65eQV/fRBg1NLW9HHKDWfV3SVcOjOKnCK0r1Q2YK/bakBCZQ4Ijjj8X30AIhVbfO31fed9vv" ..
	"DNne3UQA9Yw33nH4wmWVVtAYVbOj7MRxUIpf+vhf/aIEuKgxCEUSpapnxFxJfWg8zhrM6n9vEToZb6EFYjyM/hYlK7C3L46VM/zB" ..
	""
local PAYLOAD_P7 =
	"tlCEbLSw1sF32vdlVrP1BhEQtnZy2+3Hx/kjHwOd7uEkvlpil3rcO6xHNHsanrU8JGCMyYm5U2ulpJgDJDKo0SmmY172KzCqXgvg" ..
	"zwejG5HCpcDbnfzxO6ZuDF8D/6z0fj/DMFGwdjblr98jumUhQQAdwCs24zNUxpaElua6+0qk5bKAg1dsVlRCmEa8TQ63er/duQVT" ..
	"hm//JqhyxWL/+ewiTU4yIiRoNRMHcTJh/iXrJLFaosHX6gcolh60zbmWoeiw6kqTaYBdDY2SVtYuk2+JAPvMp8MQCB5CFRiwS2OC" ..
	"np3Xiax4p2ID69qS+W1MYbdmVdLOVmt37TvXeSNEQSl/FkuE0IFJvlhkJIpcCbqhNTzhA3I8jwWkmdLbcIID0q09Ug61pJtQyaUH" ..
	"kfcxEvWrmXhCdrVuW7OuSXPi9DhWz3QQSoJIhK+FT8sVoUcQPCz+SbqcFxEZDVkamdfZLs+6ytQYSMAiYmJsq/5Qg64pCaslqR1/" ..
	"tplXFHbAMRvPYVofHPDNXj2H9pJIlVOH0tMdVkgLDNwgC8uNohUBEe7TJffyPNX83l4C6jCVitEQ1/IVxFWg8aGAawlN1FAN0iAB" ..
	"76y7FoOul4MB5d9QJd5b//3oSeoVMx0FP0TWj4r5yucUFRh6JqRuV/bCJWCuGortB0dQS/QnhdbKUX7DNU3LxCfnIDW/MkbpsDs5" ..
	"2vjFlKPcivRzqfwWO6Wuek50icN/Ioc+XRCdNSGWkIdEL5ceIbJWNmANEeuxOg6yswZHnKrDDS3xODq7a9Muq6zVrP9QCgDE6sfn" ..
	"0KvRWxvHcErQUxMmH6hEr8fH/xDbHIqt11GwtJ6PqmhEwtzzQSiMNgw+tc7p7gi4eseDEyYQfQIBDJG8OMRh+cSxXia3KbUQXoZd" ..
	"etpe+UUChPlIVwfmXcg3nWBUD2ETUM5kHmw8H9cbff1oAAl4HH5GDVsgdtC/LC+5MZBfv1Bfc08H4+8wXlxkrohe/n4yPUFtgBLH" ..
	"Dm4u86DE88czw3qZsIktkjwfljSnM2jzd8sH2WHNEKqpDJ0ZofmdLQJ8VThB3Hfv77Epv6XY+51MLc6Ieco54IIiB+QaCPAdA6iF" ..
	"bGAUC44j2SV+LyI+Iup6/x7zu3AJnXXrMQ1qQ8xwPUPtlvh5/9MjjLhI1ZVqwYgeYj9D6mmM6Uvz7OWCqWxb2302UcVVUbzIhQbz" ..
	"xjgRHeZ9K49u1Ja1V4Zkl7xY5vhVjo+WZNfZ93SL3o5rI1HA7GZaPTAOLAyrKVByh+pbrbDXuecZvvgHRqxIplvx3otOOnOBccn0" ..
	"b3PamofJSrG6yMrWHNCnQNw0fhjNrUlMlAkVd0xT2rs7kzz2obzaoxX40TkEYPFylceezyIbEALaddpZ3j+whzIkkd+cvOOlPWyl" ..
	"kRC6q8W4OtOKRHqzGPembWmgth+Nk9bYbi64DP3mokY5rijFEYA3ZhlC/J5N5NG8nqhJyJwMbXNRYyotw5VUq6nXVMfKLW4StKDi" ..
	"aOOVwmfQimHSgsbGbEFhcePG1A0O7yppp1m2uxwmTXY4RMwKX2Gt7kKiF+wmQsOTHjiyaVZ8KXmnNdSs9PymvWK6gKBleX0sEPnq" ..
	"CeuHOVo46ENpoLn3u9EmlHu3xztWoeLxptBxI0Q1gXNwNtG2tvvzq10kNgluIfqvrMeQRvNYd45kRrE3dLr0W0ySiojQoaCbm0bR" ..
	"r/b7vYPZS/HszKdhS0dQUwAf4Zk6zuOKg2WIyAPdLdLZvgDbYXiqeAbxcy4uCHQkMScwIVo9ZM83gSKbEQdL8z2G1NtSpLnYhgqU" ..
	"zQHouz0/EXSiunlx0nWJyoSFyswFJZt3L21+BMeCplS5S04CZ0PC+ZckVnv9WYeNb3OUoSOe/Sg/s9xqrR8GCFYLthckLx4+8AZN" ..
	"uU58hpG5Hip6ddwGFYLU4chMqGWRps+RdTIuZQI6zgdfh7JavKZYbN1Dx0gUm6wZxiMRxS2E1zF3tY1kAl3jO6lHFRXOfoMShB3Q" ..
	"RkbxIgeqFouqyxxoMUkCYn78tzgXr6QtJ/g9YfeO/OwpMtWDfuEXyj7sgRaA+cCB6rtkh21pp8cxCF3xiMMhuap2JXzrvAlB7H7B" ..
	"naSWcJ9uoHqS33tvUQ4xmkgvSx8+MUHwdNZvIJEhUux56XcJ0ZoyL6TeysH7jvNSCyjtSVREwSmD/84KkqoiIQBvyiCsA1BNKiBq" ..
	"r7NbRCB8JDdEg+R59qJruibK6xnSQ2jd9FryM31rs0pAvbyk/HVggOrL6mTWfeidzgstltaL6tq9EcAZgNPrqjScanGjx7y6xSV6" ..
	"HrdUtMrIfBRv8j+iD3Se0AS7JXdoKXlj86VMETtkx9g9Rjho4NvyX9EtB8x2RV19r5Qoz9AwoB5TUwxVBj+PtC8CycXfi2MUwvFw" ..
	"pDuWYFMuT+SpStS/OQuozvwGlcUhMEla0KxRE19yXpWeWcUwiObWcbG4AVPSBh/DbSZbw6xI9S9L5eQE8oMU9xpM1kZNayY5Q9zw" ..
	"CHj1+JN+2XsVjgaPqooI0b2tKJG9+BnrEuBnOAHvZUjLxWmxMtmAfQ0hIx+SBhoy0iT6m7v6qAbvKZikcScxiizM16HhV4UDt32o" ..
	"iKQw2QO1TsReCv8bgk6Qeb3OyXPsDtYAvywbHPnIw+7/1zvjf9mB1tqV5fe+IxdO/0QiYFiqvvrbJTmbpQCL75dfXJuJ7g6Ske+L" ..
	"jGjI01HnNCLVrCszVHEMNyVCva9kGsghd20qDEKldVFAwnPgVfnGHv4doO5/Pcroq7ZYHcKj1q/BqNRv+GCSafAFQptd+xDlbJ2Y" ..
	"Wh5YawVCPssOZg1rl7qqc17KKqJOnbObxcxj0jzkc8MDP/14xQZH7IIIVFXNQPunpOsXTAPBhx24+lJgo3x7zFCYdcLPb9SgYbbn" ..
	"KHoyp1O7vVQmKrDViTjE4iie1mZFsmirTTWL4upG5MFsVDtqesemCw740zHCTFLxk3MysAgW1VO5nnMMqD+KGEjW+2vQ9fT+8YKu" ..
	"8q9Y0UEpCWUgd+eUqJh/m1BoJWyfFdwzbGPgd5OLU8bhtdIH5Ak+TlooQ+AusogDrebOCUEteVFbDbvJka58Rvyp6EpJ3AW3B8pS" ..
	"y5J9OkTsI+Zem60yNLKv8wtnlK4M30SMbQB88CFs09FbZa92RaUm0Vabt8/HmoSHr6+rr8blqE86wvcWI71/eEUhb4d2rzz8Y+J7" ..
	"VzVS3UVKOr6QGJ2f+GXz5l/khPpZcCn3ORn91v4MXpbf2pruMxXk1KCyS/ZyxqsfP5y46kYLV6p630z4LjfeqQqYgriV9iAycaPl" ..
	"xeGvWKRVuCVXaTIIV5OMBSGf1gFRpofBm7NoQwpWy4xoaoFbB8PPgZFMZgdXwDhcAhCWC/uH8xjmX0+S4EwvBVGP8N/9E5CTD2K+" ..
	"bjwDvkKCbHtVq5eRALcDd1yQOq6Lcd2M2vtbNiyB+WsjO3fr3SZ5bpP/a0gSfXDJwmDxeqDgNRuxbEhvUKrVGpWpO2hfIiLVMw1Y" ..
	"H0iPfo31544zy6+9bO9GzmVjzZHdOnDwYLdy+rpPIIpUdcIJiAZ0/2hSO9mDEY3adCZAY6np55rrqneu4D4ZuA7cTmUPmEqJVsuX" ..
	"uP30Lwv66+uSR698XSSlAoHuwpmlyaiLhHeXskqGQK7HHrr8wKSvRJjy5bC0ELfFTUSPNk+qsofVtafNkEZ3pW0OHhQaD4yyfUem" ..
	"Qur1LbXZTX6exCOdnQYcw/kjz6GloG+Pk0RDL77nfeD/hi6efZTiho3Mlwqrmr+gkE9UgXGNgFsgvdLxQhFShDmbKHN5LYh4Okk5" ..
	"nQ0KtdPZgN4zW8mIM6tQHLDD5E3uTgWI/S9SmTR0a2PvsrpaP+7Uv5I0VlBTjYwtTVYlbAwDvv/99nsMIFBFVP+/ILefSmzvz8jC" ..
	"WXHqaLCiUgrrt7/kIeFn3XlhvMWo63r4cHV+IHx3rONLsLWKqnLijKFKRh2Gc1GQsaXB81/1JnzmhEfFMeLrdYhujCBLwSCkqVGt" ..
	"bESJexWRZcT0m5m6Eu/B3tE2B7GPmddXmxw6k+GmAQwVyDpYWKPfNoXhnMZml6r4/Qs+9pjaJKW29CF/TFErosX/gM3THJq6Djdd" ..
	"gB58IWzvwvqfuvodaPeBsJJmZiE0t82ZTRQtq5MAaN1Cc8ImpnaOlnqFt3GZesJluah5kkWrvdbHOL/0f4w5oX8c47LkGMid5Ebn" ..
	"TBGhNxEYKG4h3nhIw6xVfn+u0bpLeohGa+CxCBYxyuVMsEbZ1FqralQ0LcEJKvI2hj3Q5/U2aCIvPhsbsG/ISYqEFvf6d0dPIeV9" ..
	"wG7GW66sn9VVzUNZx5g5USNIPPLHQK6E89FTTIBdGArubK4V7K9CaRQGZWcoCN4b06gKHazmMMTQolreG5Hlpe2CdK/PTBnOa+Wa" ..
	"94HNZ27fU7wp2wJUtpfiJlUWK6nkVhdwseXnj/of1AbwbOM0Ms9jqvMPaC7ppsF2Ewzbnlc0VG2UzU9hgOZWPHeLlOujm5revGSu" ..
	"/1zDAgJCgBsdu2S5Mu/AfC2m6zqrl6JLhFRXTmIzgmYLaAX6vP4bIrFcOyWa1NTbsTXcyBuzDs5oF0sqpA89lPe1vP1CBk1WAkIz" ..
	"5E/hTDOFuh8PRnSp5f9gKZloLeJOIuB8ihoswooofg3ikdC3EKZNdaCM/ud2SKCZN1ElX8CL1jKI17FGgze/e3gXGiKFCnVdQiqW" ..
	"YKm8oqVBFjrfbms5cMePxUGDm2iD12VP/8yVu/GS8eZrQNfaG65+MFTsIaG/+5+geY9/iQ68rcrZ4Bg16nr4427mCzrH1JGdsUed" ..
	"f9qRuv1mcVQcepBj7z3rOlLpnYDtZKUyAk2KUsAfeaSj47O5TZ3L0UCYV0UDzEWi8OmIyJIFudn5rNSezYYAnsaAbJxouAKSPIOn" ..
	"gJ9L6voGnbg5+3C+EgN6QTHx93CbFrlWiStqAd5M387rDvSyWjYu+zMLRyns0ysj+SPAKm0NS2CXsuCgRI/Xk8tkqb6e+bm+OAjQ" ..
	"T1G5uwJ/Ne83QWgUcblCOSZ4Hq7Nc3FQh5IO+AUFTXuwLvHqE7gYbWkWWgDIsC/qkXWnQdncE+LcX7aL3a/xs+Tq4fib/g2krJ3n" ..
	"0CZv7y8XHZ2y8OOjFZvb4jVvusyj2iOSnHSmpX8wcMFslDDcz8roSP+Uoicr1j5E/u9MWPYQeiIhDtL+5RQpyGRgBVO8lF7iyUmB" ..
	"yO8SmIFT0mHP0OAwiTDcQXboqVjFSGuftDaEBiioZBPIQXwC/IcoLDh11K6qk7Y5XQTqQENea6rd9QHK0+5BYvYyGhXCf6OzZggj" ..
	"hJJK82IuDZLeoB8iOKy6L2qSUPALfFC6f4wtTOjNfp7fs3w7UAC8af8VDT+hY5RGJesUka1cemTDZlayUZ7FISQdYgfsoW42cuGr" ..
	"ilSXwfUwKaO5xA8ztVB0+61+K8pimti5cVZKbP76u78I7iuIfEhRdoJfByAPldqf1Z8aHwYn2AgpuEOOOX3pDWWzPIhhtimH51DM" ..
	"fU1THAqpC7DTXx2PGIs2lA0PkDfbFg3QM4t5sTks1ZQ3u8rtKjWhKbXbcrLBV1y3oGGExPwQChxi7h5AXTJtPEHccM2T4OwZfM1J" ..
	"MjWwFbfJ4CcX3OPp8AZ/4M9rLGkRlKhWzYu5/ybg0vfYlAG1cJFq11DxXS/m25VbOLyVPhAEf/68eSsKfR2EonNDR+/6OlDx19MM" ..
	"X8ZOsb/0Jr6KTI5hrfvKs8wbcmk8upS5t929pdKlAYbWcr6JWFfO0YUtu7PyFKnc+6xQh1m8lAZcVQFBpDQfobXTrKi8MfBMUzUR" ..
	"aJJk111pmco1JpWCA29hf5N8edtVx5/Rlx2vXVZ/d1L9yMgSfz1mFxSDvNb9kwGYmIOaFT63wUrJC4xbAfgMTgqgNzPlpg+lgOof" ..
	"h7f2BQQWloh4Eq4xvZoles+X6tQa08m2nY7dbmYUX84IHUsFbgLGPoBkKz+2JzpQUP/xcdaxp3qVXtOc90eTiNo/45FbOPxiOCfL" ..
	""
local PAYLOAD_P8 =
	"vR2zJg7T0FeDgVYMqInKnX32g/Zg3Ofz3xPbdHpjRsD84VpOOu23tlpQ+qeFyZYV20t1WvovOrfEaftmEv58K1u2dA89oUaxUyIN" ..
	"A39P/vnlvQet07RJvNMknTjsvNgZesdA9yiMAUR8uHc8qCKW05TyCFJeY+To0QUoekfe/FMFLEK9me0z9ckLHbTdSkN7Y7LKMIfl" ..
	"IVWgNkd7tT4m+kYYobhNa1RX1uXB3CCg+FCdN+W+7O0dOr7rZva+nzItQhC0Nu8wy4IgT0eIILL7s3CcAYj8wh7rtWYUiZgYHrDu" ..
	"+vP8CEqsHq+X8UK/BP3tfrsveiSwrYlzXZzfKijedPCKJsI5f+U/+zzSFL/Jyjq92jEBdMGVUz7I1laWewN8LwscjTlPfRr43xre" ..
	"iiSJcFWJzKrw4KkQkgH3YarDin+OJpfSHMInRMddDU1Tl3k52WIiFzw8YXT0lcqVHFSLO8n6kQ3lBkAHIjudfJJGrXViM4RkBQRe" ..
	"9JCcdByx1ClB4/IkRwVaOqSw7Mgfi+0vIUoJmpouYfLrrULmw4D64whFcnktv6Oqyubiz35xZ7IkVKX1hfs6ELNSRR/L9sci+NyQ" ..
	"t+nmz22nrgtnfkPOLy+yydkL8MJ+upbgOhZBXKH6XeUKFBbdLjBRkXSuEMxOawJRlKd9pRYJHjN4IqA6IJ6+cV4wueXaYdgERAfj" ..
	"QVltKpv2et0a6BuFHKB5ilhqUMnYSOnMTrYrwSNN+f0FVd+f5TbL+tcQn6GId6LJ/u5sRrMlOTauJBF30aGTHX/9rIxK227lU9g/" ..
	"pIWP5Lkcc5raUtRR5hEWlwXg0pDYEDWXDY8r+svRDe9WlysXBGxqVIhPrXUhj07A/oIsGJSJKhVrZD4tLhDK5DJ85SZN/2Ma4YcH" ..
	"428bx+d2eZOxzb75h980FQSEzcBFxXvHv+5FQa7RiGbfqgYgCChbMiu+2J60Wqoa8oYzPhcMFrfs0q4HSxo5iQi/XIg7CvQI5j2M" ..
	"gS4l483If3JTQi85juMhcKfJPTwjtkVq+85xkRun4IfUPtHw9ZLRJnAi/026PIdwXscOA6vfCkeUTi7NQ3LRKLV0+ee2siaDdlO2" ..
	"sOGva5yORO4guvpRmh+EsZ8VztKWimH9nl44bs2Rp4Y7iiC5+HMVwSxiWJa69Ukdfg0MUPXm9SnICNKNhh5I3ADidP35UrwqCuOh" ..
	"VRob/C+NOpPut19CJOlk+NwpTPKke6vP66f7xBK2OVDGxAeQCyfLEyf7xZbY8ux1En19XU5hkUvJvnrHdE7/HTvaCWh7SjXMUTEJ" ..
	"iCHMknrzKsm+SBM/T/6AzBQvvzyMTkW3mL968CTjb9M2qu7g6SBPqrLJWbKQMgHx7Pjpm9Ud1C/k1NSlPv3d1P/aWnL+9+prEfYR" ..
	"reGvgpFg32BYeqlqojJdS3Zxxju8tegIwV8C6gx6MTvaMBiNZpcuf3vNkTXssrMxr7FGj1zHMc3bJAXSNfO+KRYHo5kqq8PviFj1" ..
	"3PiUhA/GGhs3rmzTXG4ofmCP+p46oP8OZ5OdxdGK2t9oyF50hG5WGN6u9G87+H+BDTckZWGEnTDO6txniKUKypTEo13aRi+ZjO7g" ..
	"LtJrtn8o7CsY1IXYQBXvbQtmQZKvA/ltv0veooAStmt3oMzEsq6rSwIFGoHo7Dw8A9nXvwlDlpl0ppChdUdTS7NAvYsJBYKPQw7F" ..
	"bbWel5Utxy01qLUzeABBcfsyOpmsaAp2pYDr2PQ+eD4wkWNu7RJG9lz4K9GX8TJeVFWe0+cr110T3HQ9MmqUcZ1oBzryACk6aC+l" ..
	"eKSrMt1MkLcs5lqxStZ2ckD0dzNouBprlOiQJMEPeERpUsq44btlPa6Z/LxDsNn8U9HVVysTrICw7GYPl3jHWJ1+TM8BzCXom/GR" ..
	"GeXK8oK3l2jfrF2DmNCgbt0ZUZy6Wq7CGMF3mfHHyyH6jzwuLYv+GuLpPqp07E8x3gM2CMooURl0UJJOuo7dFeKwZ6754AcrV5YG" ..
	"acz4PiXVmm/1nVnNL4rgB9cFtLA0v+LLTLnQXG/IuPAIJh+ly0jTQ5UTPCJ1373r430t85wuPEH053DuRA9JlLseToyEvHTbUP8q" ..
	"A4C3lqlgmcmU14XIT4xO39DzQ3Q17LrvppWQ2xcEtG6Co0aRGlI39qTNbCgbO3DjeYBwWbX7CTnwgAUqK/0cgmmqEVTT9sx2BwN5" ..
	"ymEiIVrc7pGDQtpNF3Kdmbt+C4ADxprTnKCj+uVtGbIoz2Eu8TlD0T0VQSWpP4vcVz/SKj5EwVA/4DQj3nbhq8mxg5cZ1aMlKW1Q" ..
	"sgHXu0AxQ2k/CbmkU7Bs9/pdV3hsTdxyT20wvxw5qRIKJhRrlHABAwjVFBtTDQnrPOEI4e8titdwKTx3cV3K4cJVw9sOTZG4oi6m" ..
	"zpEwdo29iyKvLDcd+ii1XlNey5eGm4fCf1YK2aOFPuXwH154TCBfSpPn66TuI/iGTLrUiifgcpOhfPhGeufpFlNnUBjPzmho/YR7" ..
	"6JAb93+YIlwnGSeazjybbf1o3Y8x77fCPPyrIpuonjicn/T+jKngFqwhVtEcuiMNogqEp6Sl+++HiFB3aF9JxZ+w14vIx4oM/xI1" ..
	"L1Ns7NuAISB85dc9eTfLk0vYfqfAi124BEpAK0xDdwjotgPStdAapwvEHhpLpqpdT6Qbbecc2pcFJV+z3r+BPeEgEU1Z4QcGZZ9C" ..
	"UzJGOKaKAap8cvFNszMA5xI1aCbmngvsA+GmJLpLmVvMm79vg6GrjHrZAyQS80y4XpF0aNtov+tWNf/9DM8SYTjg284M8C6JIV8N" ..
	"Y2rdMuTMGbF1rqjpxvmTPrnL96OKA3Bq9dgGxLkBTTtzFm5L2rPhtc+L+8nmGJMjMGjXSXbDHPnXr4jgMVlvFMFCQ0+2po0Bgv7O" ..
	"Ag4c74voaLrcxjN6ezZTVhxGnKdvnLp/0HlRIOzPdlXocdD1dSFJKsBIRP04mORZnI1YbFv9Ohu5lyv67jmHzV9sOAV8BAGIGRyG" ..
	"cg+75dBBc/i+7+J7raYR753run0pa88Qv4Atk4B3bEYIaeHJwIioSTwOL4Sg7OiJ9yuUdCFfuAKqOgM21795lAorKuX74HxULjxm" ..
	"PDGhEENDpwrQmkxqnPMW/+h2pyKsjd+koCCTXqUjM7pQ9M698qcs3McISpbDkHDgz7HZKdYDWU2CqJjwCup2LTA+dHwWItLF7Zeo" ..
	"F3Y/9hwVna/tKoMXz/aHkETfT9qvtnJx5Bb4/jkmn02ObJP2VQD5LoteW/T24ayjpLHjGArBzHUGS5Beo4+0ZtOD4BMPXeEn8XIh" ..
	"hXSMcK6wqx3amTYwmsIoWDqKLiNdBN1RNFqGg1RiP0MZojBKidgIRP3hgGEPU71rVhNNflzEFGPBrF4Sirui5eahfoOHeYwryarg" ..
	"TivlnmU+3k0r4AoTEc9ZNTqykkgKKtvFj3PX2bKaXXpXJgD57Dv+LtZxO0kyHHl0hnEybtvtOnoTtqqoClQo/uWOdIeLkDKuI3xA" ..
	"uZq2l5bfOiE4wob8SCsBBzuP5P/iwo7n2kOdV7XFsS8F9Z+kzAFXiDGf/0+HpGI3UCyXnNDVEWs3Sxln3qnupJVuauur5+IZBLTW" ..
	"WBkos6hb03iS5kgijBQFPPDtrhkbUJBmh9rFgzSZVrT9erTO2EI8Vt3GTDSsyuAACLP57vkg1tkNV0JzMpKbMTJeNa6D/cZZYTaU" ..
	"6ROhz+u8zZlzWg8Uhkpbg8MnPh2psxJ7bkZzcep7z3aeKcP66CojoXA0tuur5vST/c3KLFrDIWsREMir0Ez1F5r0vZxKepFy7Xbx" ..
	"42cv64jj+DmZZe5z9+ncizEU8JMMV8WT+Rgl0Fl3yuRBh0uzpr0bu4aHi0qxoBdoVCtOlenJ7C2GPdGT5ZvUpMqZVSgWejxd1UvC" ..
	"DI4covJ1fXrAwZEF5IxZjORJc5sUq7fwGC+PxCmeSe8Mu62IeF8pAXB8dLL4pjcjVvKo91r39X17jthHA1uNohHONRJq+TKMCps3" ..
	"FKkQU7lRVHiCfn+UkNFpeV40P5q8vevP9Fa1Uo85sCyT+IELlpVPTrHgPk9oEEnJbEPdq3SrSrUgJugNCgfebGTV5Re27Zzyh0pS" ..
	"7SYvqSvF+iXy3F9BgZB8y9PllIq4e+QdLYuiaLF0yrHYB/PgZiEIfITlNzkjCxhkhWA+u4sl71GD1wRx0o6t1epWr1ugYUqdGARt" ..
	"Kv3QrbClbKFusBcCPG7QZ1cd6x9vq57OzTLvja3ImRoku/BIqyumU2MjXtXSAtyg01IzAdj4eoi5gRD9x8QIQCReRTqUmXTnK8rX" ..
	"atPOv6E717KyxldKZjgT8QesbRe6nmDF+pqxWSAg4kR1hh7tjr9Wk5oLmYkKGUqNfRRyQkOVe7kIveVxQotVDyi3S92MtMwU03KX" ..
	"ZSztDijkMv1WQi98T1YXZbxdgWCJJGhmMyqLD5LNyqJwRZdw3qpwHvzJvyD9JPsdQJ6glevktjRwbeXbC+wUF+8WjfU8MdlSpoBw" ..
	"2MbyF4OVNukbD2V95PHY1j3tXbI96OeiB6uDmmiYTMc2U3Ol3eDgjDzd2vF2ho6OOj5ZWbQcL4x54IK7Oi042KYJllvTm4zLvNEQ" ..
	"NET5GS3UCRvvGGgHQxR7jfgHetUtStMD1+qt+JjXKTozTMAafHyk964A6luYuYgEDPkr023Az5YdMYe1cKyb9YCxleBC5xQEeqd1" ..
	"FsD5dcTRQq4lbdk5R8F5/Zy9fgfQoujKFXzOL8C80/kZaMWuYbjGh18OabvlcexdmAlhvW/bElzxXJmTT7r4uAdPqjKrWlRAKbGQ" ..
	"hsTNBkirFmQvM140QO9c2pj+k2NcEo43Uz1mfVoSwJZDAUI1rci+wJrCkkliAlgVrAtfh7Xrc9sT7j8UxLuoNd88zwRYlha0TVrn" ..
	"ZfiYm8Au70/rkoY8VkTbdTuvI1wW6FC8dqWuvL98AEmUoJWvx39ItH6Be77lyLcv358nAINWqKFsz3kYmSNK8KKQ34aGdjIFBP5/" ..
	"+xG9pZVi/Sr3N/lYahYZ7RbV0efuqxfPEDJytRGmY9BFOYYiOowNJeS/2zelJdRUnLmceSetn5H6WV11IhZ2yoPPkERB7DwdjiRc" ..
	"/nrbNaB2Fa9voirn5Rj/24fi+to9ErITG4K8SnB7Et3USiTrl1Q6jeBYMTDwUitqC3XJ22kEwII65YURc6Wtf+orNsVv2QwiCZsZ" ..
	"qSBpYHjKo06Klv8CIMl8yTox2iKJG3Y9cMY8AUi+PrYtKHjQft4mY7lvSEmefDW+Upf+2NJJ2xGbICNQ1S+F7br8mul0xlW0YqDe" ..
	"diFU2YbgD8sJQpWxQyDR1xS9qcb8IxJOssmkOYtoyYV7TlyzNgzTxdZs2jgmD6Y6QcLBQj8H7tWAfip1D8UklScKH37aD4G4U3lI" ..
	"6d5SbNPeu+nqprSE2IVdmB15U1gCnBsvEKiJdRUVj5HG+Nvh5Wdag5oAdzu3TqVzs2GQKOd4bL1Rx23k8qYSDy7m9L4ldZXmlJ3t" ..
	"RrICJSmJXBCsTJSbmVEfdQpJ3hyIYeqUWruAIwEJwq9r+IDK7b+68v8oGBQCrXKr0nmyJQlBWHJtoB+asuuONJxxUfwV1IbN+vTo" ..
	"JqncsJXhmqHtCLU9Ol8JrGONd9I1E/6abxNIZQYlMPAAlHe9plJSbjc+mAezgylc1hWn7jydSKpwmmNZ6wTajjWGiXmd8lmG4WuK" ..
	"4JFogehO5vvOCFtQbmfB0FwzW3TT1iblsvMQPu+evStiwWuxo/qXhGIrtedvgM1qMO3Ohj/fPXZHXGXF9PPVOHZwDy4EYIL199df" ..
	"i57FleW0Sh3/1/eWY+4s8K59q7A2/LH5SJTge3Jc/jV7HAkIk5joJcgF/BwEPbFxd/pA7p4IvpvlfIKaU7OrQ8xjdWjfAIcGpurY" ..
	"oCy2kOTCUo60GdhAolOEPN2sn2yZjqiJpT3JbVABtXvjokZWr7zuC5TGVwbyaXJl+AlO/7gJODr0SM+fdEQu8++tYyMI2cAXtIHZ" ..
	""
local PAYLOAD_P9 =
	"W2rByawIaovOUaBrvIyMiHWNd6a/Jbq0RPiVwWipdHOKUxEhtSC8qHm5K/QWSOPVIVFI9QrhiuCG1le1XrvKagm+TVdrUbIg5f0D" ..
	"iljeauUm96LRVaWfIucwODVuf3XSt75X3y4L248CtA8ZTfwCkJiIJwsro1GIFSWZA4UsFylKiDjSxYtn7BjWXN2yywvKyWTvp6XP" ..
	"Ssd3CZScVCUbdx1jKNw3d/ZylFGL777gpO8UHnW5n264EpdxdQqYSECy+cmXnPJ87Wo2i4PKbzlyhylsLSPnmaXdIRm0uKpuDUdc" ..
	"PnAl/d/n34I3gHvXyNOc4q/ucgiihC+HQDw3Kb11ix649meGZ4sM13qb+Wmx0L0G0cqRHItl1ELj7AmWkGqcthbLK1YRd6coJlI2" ..
	"XwWdr4Fd5K5wXabInKkRkeCpsPrcJvAZfSCCkZljpV40LJx/QtlVjZplFUy2mOyBmzgrf3FgwoEfZg4ThwMyxgw6vNfTDKLE+uDd" ..
	"KC+aAjxyW2gGV+wd4oVmcQ6/+RST1f1ErzMCMgFjdVYoCmijTC5mPL381FpRKbEGTrEccPTcCmwZIIdTHI2ZJA4Dxs1Krvcuz/B9" ..
	"8nVCrY97Bb47Fg5OW2TBUaFfqf0TolNJF/ldyr5flNn2S4dGBDjcA4oHe0QrYnpNXMT9w7ABYblcJfYPI5puuvTOuCNhpnv5R8wQ" ..
	"uuprkNpx/LlN44q9/LcYS1h0Y0ikpX8YuUnORTIHKd4X3rjzD9tC2kITiz2yHBnMabMn3IhFUf6D9UChRjjXrh5Q/j/2I6Ryc+XD" ..
	"yBOSdNrXaUaNNlqDo4oeQYsbU0VVaJp4b+z8lPjbzdjrD+8JGuJ4jtHIm1O8KsVWvPVlFMRHK4unLkU/hajqgNpwblD8hSQPQGLK" ..
	"8aUMr6DvGCfR89cen92NxBK5YWxFBHI1puPgcU6i4kn8zg2EBUcXaUVWzQI3fa5nQ5Lv6dSljs3p4nolYhTnHj31UGmhfUp9n17h" ..
	"KCRNJaT3twn/bMdbmG6ZRMRs70EwRVBR2Ve+2EJO2eVt4CaeXGe5GJvHuUVd73XkGoH2F7aVWWkc+woMRUrbFOfCjwhVDCIyohmh" ..
	"B8X9cK2cdekm3Gs6UPRNgxWSO0b7GB0mCSqNhKPOnt5oXP27VJ5ZnP7lg8rkTHqil0xvuvCKLZFFvapjmktzQ8OtGHSAjcpusPjZ" ..
	"PrtunqnIJN42ZwRXWrSFwGE9e/2nEtksZZjvIWxefBpFIayMlKNzzHBCMLTdQlB5BeQZAiXvpoLdg1t+B2dHYBrsCvxVa52kMi8d" ..
	"6KoTlF1WCdFU0EyNJASVJr1tNqXYQp7n2dnin1BqoTmISksR/8lvtWQvY0RE9ld9dvFqg19CYYBg+5HFxZ1oVMsL51y8uEoj7enK" ..
	"cRhh+Sc+3xK6Pvp65gTgrMU7v/H7Bt4pUU4n3UQSOq+2EvPnpfkkQ7b/4VL5ME7l1Qcj2EMDz7fqIYHJNrreWIues5zuRdGLbgny" ..
	"tLu3VsO+FIjWmg7i5UG7XKqsh1A45Bl3PhAosMSXnWcF53HU/7zinTkerdLZWPBeFtFncrImPj34hT1TepizAStx5osMZ4WnArCZ" ..
	"UdsN5qcbVWxy0my/zcVk/blvYksY9JUW+nxOOZi8ftSImzMRp9N6IYeSuJ5HBtf0eky3/FDXvo64iDxQUIlDAtLrP0KwXIQ6AgeR" ..
	"RshX5YU1bGazYyffXfFvW2mvnBoP46hDy5J4ReotdPOsNchdgBuYQqrFWxgRPyCRklPhKRiJFiKWD3F6cTZFBRlaHC1epLl+TiwB" ..
	"fAUoc/qOH4O/gypTovvFI4nILDgpBisHByiYklkS22z2gJQoU+bZ2C5yH0Ucu1NWRXWRfm2b3VoNyIGuUVqeEflbCJHEpqHFjMmV" ..
	"kTEC0+m2KbirsjC8Sl+AlbD96zGU5Ho+lcfGzDDQptdDj+fIYQOwRaDdr7Jy6HzwI98aBgiSa20mvo+tV9pMTZyHsvkJNsZxHOYU" ..
	"W/1T1fNh8bS5PRSrREdXj75kdZsuUujs8d4r5NuLAr7MIQJrXF5lqKsraHRFD+ZbIeoTv829tWV01PNT7ODFaEv1fGEeBg4cGyqy" ..
	"sNrvvi1WOKUU2bhcPVsg4eWOgXwnU4ysAE5UodOpjUKfyvhjETCMu0ZKPsp+3QIlpokrhyh/UsAOXeEGFutCCht3MCuCcuQdcYD2" ..
	"AkYsMG1t6XHbeRfHrJehN8cPrOx/Rac5haGL6CsgafkYZ9BfM6xp1k8FGGX4XbMyJmvvsgQjd27gTt2/xaQ72/CuKrmThwCss2Zy" ..
	"jFJOzk7mFLSGC9X9wXnoEeewP8KGlo6LqsG+LqTB9bxy28ZYwRTbJ4xk87Xqk1flA786P2VNl69uVVgLt0o9JpgaARnpjnfH7fon" ..
	"dwxiytv/lFbOanevxDvGxPgcNHsqQvN+cqHS+j1C6gvTnCiSnxFCsj1hD5tRUJOH8WVzGMekBmoT6cq0DQxrdUvkZ/WbyJ/J36F4" ..
	"7yrrR96GG//yRMTAO+IU1DmZcbK+5m7JdHN1PlTx/gMoaF7BfhJns06C1ywDrd2DobqXTqXZbKle2mvWwQKyQojWgu4knIQ+KMdS" ..
	"U2GSY/nqnJUkBDOY2e6f5zuOdRTtUbaf8QItBc9D3+zPUjghseBZ//aSD4cUO3Xx5Tr0kKyK1U6/C4s/uDbNg/pd+ittubP8HLxC" ..
	"51jx2kJ5Hi80kJjWxboJKNl727WeXXA9DMX+emWcH6D4rLu1+skLAI3JhDmYctpsZ71+5gcSfTnx2+kqoBNDq3LszmEQqj5Zak/g" ..
	"1MG7wcG7ijltD2HzT4+6tWu6Y7TKytoMK5LOVDpsOe4T2RnnLGym34wsNS3dKnaDqfHEZnabzE+xu6nwxRpg8fjv1oQfdiFz12vv" ..
	"KDK3KcYJiSU6U01DoxJKFVulE6Hzk+/nW/tS64/BAtGABEkUmirfaoEoKhm1orpvD4T0kCLBsVXRgiFLCXRR6e9r5RBE7uPt/0Et" ..
	"FaRQCVyaXnOfqT7KrUh70mb6xGsNEfbtZLs0r89mMhksL4sVA5ycBshilByEDqUVC5lTQWY2gTe6avAQMj25ye8geQdJHBTFzuCI" ..
	"dJIPR0FQUfxRZe5wrQgNeA7DhQ7C7ItaV9MfayhvpnlapKsvD0EYlpjhKjzfy4bfZY28mw/UAK+LaNMNytZYYoVUKLsD21V6nztf" ..
	"oy91JDNQC6Va6ZY8LShJ5ni2ZbIKdcMpa2h85OyuLVGd14+S/BYreoqcmHtu1gO3s/D4Id04bohfMg0Ajmx0SzUbZjDoF4XxLJLq" ..
	"1p010gx0CX1xML05RHnlJpVYavyZEuVs43LmgTL/5d9BLhsbHRvWDgf1Nr4mArLLJD7H8R2IPpDSdeTr77yU5fntzEl3mLy4USGU" ..
	"tBGD5TDu0CHSbj89rA7N+ifJLTS18MsPVrq4S2Zuxz+YRU0i0Gu4dQmmQxTW+tFjkxrH6Eubk0HwdPAaARkX5oyibKWPq17UE+G5" ..
	"NIlw7M8akj2z1Q+C6XefqsDTkrGjR21TQC4Lv3LIlw69MLf0KYbwrb92/NnSjVg5YN1LjcpUMpJ0zE4eXDgQTbov/oeeUPeqSTAB" ..
	"OVF46UNvwqRgci6dHLMTxCzMERnNYQ9JeNzmv/zp8TmatYrXMlhhdDR28MwWpuSomLt8YL1Ah0b+avT39ru9uLZtBPMYeJyn54VP" ..
	"/gT+zn+BPSclV8vmcs4KEZ71Ul6Q3CXCtCIuRE/WBaJ2avMU4vJ6dujg16Kk/fyiik/uMg2YiTxkcadIXZJD5OVpEKISjQ3uh91s" ..
	"0YMdPjRzo+qhlZ25xTcB34Qvq4OluwnF2qki03wXF3/WM2ZXT/rcQFJPZOvYRQugkx1WIlS2cqWaFK2AlOzLbsIUiF6d/1Ym7G9a" ..
	"I/j41mWWd9j70LYnWADcZiIxidhMLah3bSqHOQlY9a5gRkkoO+uxpFdjNahwBBfPNStLXzPIiqw+yc2Jten2OOk5au4qM6iD5p61" ..
	"4VPXgnxovIrom8X2cZr6eqU0jTjXt8Ouch7uDuz8xOGJ8V+2fhWF9MebFVcd874qGEUI1ECsanQNpIdq925pulpZ59QnNWhVi8Il" ..
	"KoG59JtRYsi/hRcw/YrfabzkouqvVFfQ1hEGtfrzvlFfLr9KP5/nGsEOtd+hMnAZfLCHYCWa/zZy4s7xD0hTeFAP/3MF2kGnyg2d" ..
	"OtqqdFeyzmJVJScKXX6g+aJSDGg1l/ITPQg49V/7LzNk6J68hFUTzM3NunGY/WcUPQgOMMDd9cnIYPwCURbRZTtyAEE9b8A9faqu" ..
	"lDb6HZZitmiWU+dtntH+onK4KamLIRSy9s1vmQz1m6/8ZmupyVsbfO4eYaxjZdXWo0SwLQvFJ769/WCINJeTq6gtvYYN6SWKNM2k" ..
	"bN+k5Vf6WbUaBNqL9u4TN58DMWJAimmIApmVxppTiVeRkfIHvNtoZJixGXvukeEB0wuFRma8j08o5ZNQeWjH1d2rVnJnk0CuaOQs" ..
	"zDcXXFG07R/VLgxzlpwzMUWGrqeQGgyyqqd/2qO/7HS5ZdmmR9MNpoiwebYQFiCKdOihrCnPT4cM0NF5nhvCLDjZxwl3xn9LUr2Z" ..
	"QZcImC2evSoHss1BWSwwXErtusaOhBtq9xgg0Gq3iBsVC93IhsuZyUI5Rop92PMeM+ut9BqY2NjIbcPKnTOybBzHQfpoGXl3wxEe" ..
	"yYQLA2e3a+ZrJCPZfaSnuSb22TG3sCpjwBP6LC1e4l+rEyHCLkbc6IvXaUP402ouZ4cLi4yJsY/yOaeAWh5p4OG6rNp2XxCqQ80L" ..
	"sM8X4z7C8Q1QPLTJyDYX2B/zIWQh0pb+zubcCWZLawCmus7gYOV6+rJojvzPVPm2Ku0YBiP6bOt7cBGjpFpzOI2KOanVDNpRLmTm" ..
	"epYkO0TIOAxhdT+V1EJU5UOqXM6XJA9u4MzsdSxtZtUFQI92BS/63b2HZLO0k2sQagd0mJcbkFhxkGOcyP1brRJkc3sZr5d7ajNF" ..
	"S3EQOPAd0Y3xPVcH6cV+pQZKxGH0vJ2/OB3vpxV1R0uQfttjACl1TMv5+6x5+XgARlHQMtHI8WpHulRzBRhgQIj/Y7cdd+VElHgA" ..
	"Vg8cXFsXgqwbPw0cxSZuuZn0dFv8YGzUPicsQ7dqy8EYdHBM6yq7qOtwSqTdqRrRFczp9lWOe/Qic7Z20hDzThvTBa8zYUyc0Gja" ..
	"zEnwDY/eVEKWBji1NRbGGvcjNg8yCcbgKaE+rFISKJVhbxcPIg3nSUs2XZxApbZkO7RIM45gosWz1IajOnVuyF489YeyeqxrhgFp" ..
	"Z/e0V08cCpPWHbIkflwunlVbX/fHdvxQKMMjfrwL0cuIw8oPZRmkHmKPW1kJBkmECGaWKDnbertP+7XcqJGPcTMV+Fcovcq0EpLt" ..
	"7WNJdMx3w8E86JcYnWadTWnWc5YPsk9AMcX3UFIpIgPSWf0GlBurMBELz2Evxf53jh35ts0yJ8bWlgWrrUDbIEHbyHZvN2pbkBsR" ..
	"ZAneCk+eSBV07eQKTQ1jJxM37NkNETKjQVXGMO0bJ5SWirTeKzJhX/6cBA6VR+BlfEIC4aSeQbnY6/xc/qkg2CZJKpfO25a1qjNl" ..
	"XNrYgoPGmnwDc3E2CtDggG+2c++hFcXkbCbWOtUjpwBdrmb1lqvQWFfdv8H2J0+VVsT3P2J/6vn98iuQhG07+Vo0szTzbFFgG0a5" ..
	"aGkzgnqlq1vPPvy2/UwfUVHQIdDwv3RxzF2WDGZ8jvGzzknief/DKurccxkJhfgpdnOUA5UrrN/0yk+N58xKLoY/WiqO5eJRkgd9" ..
	"b2NC1rZyfGpVIxsHdDm8cng2h6PnoBZoSvCojrGTM3STFALPE+CQiQf5fionxwSMooDeAnOcf5OREGLQPse2R7TFfOspvmpzaaZt" ..
	"bzFFp2/B4mW+ddWzMjFXqFGA6wLqOHQYuaNXqfhZ45GK1FeJn3V9TgaLahOgsSvke22+DZT4Mgj3p+vF17XaY2fRRgApfDlgQd4s" ..
	""
local PAYLOAD_P10 =
	"U1g58V4GPlQoSJvn/rpO6468TLTRMHb3HWsKpKfOMb1bSyB9xtyY36EdmsJkQNuUgNZnmunddPEsxtvXvZyKJQ5d6yic/bNf8X6q" ..
	"gYs0KHgTrv1jp3eUn5seHTVAEI6LQmrglhdy+1l9SXjfXzSkP8AbWRkF+MOkMi2bUhDxB8KH70kvstdPNdKP19w6Xh+tY2oRYe6G" ..
	"LUQiCDOwRJRISdy/Db+olkt0snzmGrDzxYkVSD0W0SQvKhLmyGSX9XmIZANRk0ONxmdtdOZrf+pnx3i7tEk/rA9GgWt82ARref6y" ..
	"W2WVgBXoahZVN9rEBI5Mw367c3OZgTE+a9yx/8hARs0LTIstP6t4Kd9FzoMnxVXZOK5FksZ3ew6/048eXOoyyUU4Ba7Q+t5BhRBR" ..
	"/62wYMW9vuw/5GmyFIw+8sFguMx2lJwVk7Eongc6mf//KlqmRRRnPvtziZN5+ppJOau55hc4iF2bmnBHu6zMi7hwzsaaQELWkrsk" ..
	"apwHm5b0R0eIYD/j/4zy4CrAUdTH8N1oclL9QPWx9cwVEstvnpD6o6Hj7zsa11tkay+ifYAn30FXXhZFYmkbghsOkcrhRAnNG5mz" ..
	"UEkHkbobCNd9a0eF193kz1wzb52IAv5n4bmzHOQTQADVANk+zPXpfqJSnrlKQkgOEF1EY57pA0GC5kh63ZLcQnmPuDDTEO7jDtmX" ..
	"4GRcF97VGxENMfVQtCi77GUg04GGQV/a6escRopsNRlT9tO4nOdFgCWHpauZOO8UYea4Ch6qsnSBh50sxAGUbblLlnOqueW+HFDG" ..
	"wlCyPyUPt+D7pFCShMkVaMHAEvJva2KYegDn/TzoJSbkif1Ppwvx+1vRCfFPc6a3R6gnUXq9GG6SQEYr5A8HDuNyEmaa2iQ99FVA" ..
	"QSVE0rBGPwdyBKkSsbtSPbpKJW+0aXPRsR0gwdpRVKax5IWL55PdQBxFISHpkxJo6Rmre+ALKXt5NLsw9p8aCvISSbdySD+tOguM" ..
	"Na8IxdAb2v37smossMJgLwbN9suIm+p3uFrUzkfZh5Br3wGudiDoJtpKPVQwdlGg/+EvMyEsyAaL4W0NtSULGbJRKRDNpC2xrcsf" ..
	"KOqXV3+DS48xYy2OgJCRt5Zu+AzX30Y3a9BQAXG1tQP28P8HYr7zvv4MBXXjwkjyGAJWuKbC5ggsFrBOBj927EHeFF05qhKH1hoY" ..
	"04qSmPMmhYbA6MYMDe78joZ0TrDgu7htYhJud+NENFANmPXaBxwjDFefAxobMwSOp2FWMhjR9epPq5d8GPlOo97s2JETVMeLu/hJ" ..
	"nC6cg+/6lvYyYz9U3RJczy2v+4IIPsVRq/U5Lo9BIN7rOoBjGqaFX+TgKKgG851pYIbSDSEv8moNjP5L9w1JgdlCVsVFtETcVzuZ" ..
	"rSYqdsyWuRCqrDsvfu1870CKGtUHZsA+53uFHBx8zWzT89HzBbof5h8MXGauFBfpHChdiw34e346uIDGqxHuZp8vQe2YfhzO6OYM" ..
	"sOI92QfarETJ3tZQZhrwG//xtkMVq8qezv8d9Wn+JxUKZcZrsJS0f7jMq1vpVnCXciw4RacqLTlmIy/RLwbXXfLZFix8APb4lp3M" ..
	"7qN20Zm0A750E0EN315RzL5MwjRlJCNejamz9t+DKgRwZiM7XosBiutrJslojWRZrOw0Vn/uWDq+B82rmpGZBPvthb3sOFA0cYuX" ..
	"bYLUpAibfHkiVW4NriIY9ahG7/7U3GMZWk/VEmzWfhK4vp+XnmAwhOek/jGliikmQZZgH7Un+I6Gcnhr4h+/wQuZf67iap+ErcWk" ..
	"pW+sy16qmKH3DW/LyVUdU2WJ1nb9QJIbNetuOI/FdaQ+5O0lr8/fz/OKQKf/K65J7ayzlrU36RdI7seGTDPLGz71I3hLeB61newG" ..
	"8hoyChpHK46talq3TMwVVmUZUAN/oEO1BW2TJYKmmu9bOD6NUay31M7Ie3qYFMsXXD5i9CujZouu/0b2uu0z95nZdUqfMa1Gt3fd" ..
	"sv9L7yg7rnm99EkqLkTOhyurB2sACXCU0EoC3PZdayJBfZXoIYjb/EJe+EPljYp56zg74MnpDMQzCWVa+6/uTtlXRZTM99n4M0Ai" ..
	"uYPSknH5RmgRDB788VrSX5do5RlUvOAkWOth4xEcswJ4zt+RGNx9zl7OYOcgvyarJIwAtYsP+/Jovdj/KgZPhrxryUSmDjcOAdZG" ..
	"zwjJ0HGplvtNFOXLJpkoZ1Qb74BnClcdEG8qOop8mRxjOttyMaLIq7L0dfl0/mM5kPRSmkzMJ4ZV3WOtkXpUCpZRWy/7wMCnYVWk" ..
	"wbyiwbYbd12ZqkdXvguzMNfy4mW+Lv4LpQftq5l3/NUv/EE4eOKqfYDgGlDAc4TCBOwMnCvfWYJgFhBrjsXHZ4UnzYiUPskuLi9C" ..
	"/Kzn2ms5hSL8b8eWPajKKXJz9H06M7hYAs09gu+rTEEGex7i8jrKp6dXuGHuLyeeC/A2V4TuB6WZAYX9MJFe/fjB7g3F4jcN4R7o" ..
	"GbYPO4Oc0rIcZH2LTKG5sdd9oOoDVWOVLFNEr5LvjvSs9jolQiJyyPYJ/LFBbShjD0W9FH1MiB9NDZLCuxNOgJd/4M9V18o3SEFj" ..
	"3+9n1oke1WsPy2Sw/UNArp4Y+knbfi2OiUI/N/Eq23m7oP81fKr3Q8oXCk4nStbKV21Zkq/KMFueemZzt5bJy0+xxBkfYeSoEI0j" ..
	"4KcjjJ4fvGpMNOHIk3N4w/8bl+XTd71+dpDJ7vK/zU5wYJWjFzThDh7yEPxdK+KaPh4QldTiEC1zdRwarUHH/LVJmE8dEyMICQgT" ..
	"dxAzNEpbSIvXYlAKxt1OVRWEPham6hOIdkGmroKv5P0O9Zr7DnCTP/p5i48xmic/r4RGqLuKlQUtKomBijvZ04+pk7CjpbOpczWn" ..
	"ZcwUpOjmr0wYmRqbhk1nZWhJ6oZJdKsiHV+Q56/oJDxXboaOHsF0M5kQMmbrgz76S1hOoF/6awsV" ..
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
