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
	{ seed = 3610103971, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3612717237, exp = 0, plan = 0, hwid = {} }
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
	"rQvbtaTdGv/fnJcjsN9++Ln1stdvrmi/hqdSjeYs/I08BOIa8rYqaCO0VXzIK+M1mGdSuzeDqzhDlpUXo+yM0mRF6iCuZGFYLPnc" ..
	"RydmltW/DO3NQr9Hkf7EOSZJ6m2hGU35zCfzhwZqSOTTMeR8ZiVbk73nPUdMz0kmlj7Z0HscZydWjU9tC6NaUkcqedkEUX2HIB26" ..
	"8Up8GcV6B4+ZzemSvJM4rmbloUrOfsO7sP2UdleaxCa0XZj14NazdOmJhEutCaLkE2ybesdj4goNWyl8hdTvNXruRqC6s++p9GKz" ..
	"GR3Pnv4iQ5jAp4DHc7g6b8U/1+4duEBdJ+giwe1DDonKjAn7UbJ+m0oBN4XCLQPRWNHZAVKFe7tY6XQ8afZOJoTpwYRZZuCGRrhG" ..
	"Lz+yg5XZlW3EXrfLOTRrnqGh1qau3pGybMXlhYba7aYIGLNxCRiQfdybqy+vU3FDXx+42SjMZ4m2KQAQz2m2kiSWUPtHKX1s1Lrb" ..
	"FqofwpxMLB16w9wH8DjCsJ/VSLAbBTHFRg30YUVWSoIkluJOrXYz4gh8ovsyNE3h8kF4533uDZIawNG9jS/x7nGw1/21Egx9ZAKW" ..
	"n5fPVyuqXtZjWd/JMJgN8K+JAT5RK4/2uh//YUYeVvu9yy6ZNJVWNSLsSbe/aj9QAxljg4hB7nKWTYI1pAK7f1jeIsYxb6j9LF7J" ..
	"F+uwL14Plsq+3SAYPVODA1CU55H9eWB2vxnaBk2+4szl0FiUX4DvwCTMvo2ASfSMumOJuyQwAuCwDh/uf43//gaZFWtXUSvIUSrB" ..
	"k6sqkzR8ZS6BTgBcbrDn/uadEXzPA43xaSAwu+43BVjlTp0peAwaV9BhZaCBF1uciPrAUtxaZHLFxqMeFOeopfhPzY9DURR99u/x" ..
	"Z71YJQXw74Ibiws/eHXwqhWEMocOSmFPKb7KhJoOaHzBKNPskD4hGCGBb8jd0sLdFwU9mQUBB1BKDZr1fdW8zqMQiuvbLlCjCD+D" ..
	"dJ/qR8nCCI4Xpgtccv5zbLXfYhrhKQH82pg0vR1HvQHuY62Tw5qdIGTY67eJj75jmTW/qyKSmSN53vM03oW9fOEZTwAe2aCqb0Ok" ..
	"1bWJgZS6c+N+k3yhDijTTJ6+Jq520juX0sH44jtnvC1XV/MDpWhb70pKMYQhUdIE2XMB8E0knuyB3Tyz1IbE0XwFp5esgiIiu8qW" ..
	"YT6xa1N3qeaXqg8bEx246QF9Ty7O8FDdurXmREna4TArwS4ZR1nCLRpXYUM6Cq2txEgWhxtVMEb9iEipC9a/ZAml1SZ2JgoFAUyQ" ..
	"z9nG2bZup2wn5EmUkiO+U4cJhA8AaZskVFgfsorMVnmxmM2L89XICoymSemsLLpBeY79zfBwqOGLkKMs7MyCJyXhSE8q7CsYmG/9" ..
	"SrDjbmW3XyHinhTwXLIhslDpd1DPA1dsRAXukopVDjW7MZUdRGo5Z3nylvW/KZgIrQeqtWahZv1vN+tqIBNE0F7LYboHPNmTCnm9" ..
	"JrM6hbArtQskyyvkq+BJOqEG+D7vPhJ/d0Hallwc4Sf7yEdPKP5bTLejQfvOeHb5eDdJP4r8LA5JoE69sDG2+g/OZJ3rSWir+ySx" ..
	"/3ck7LtRk4oPntVfvSRNaH68dm5bRmNeB7eOKoBmA+TBkb20JrExMPHPCi1bNo1IvY+ao2LH5RynKC99wdtsdWF4tG2eWdzj8d8g" ..
	"SSQ3lsVB8z+3ZH3aYRwLfV3rcxFkI1eZybO3KcHI1CgcRy03VpqdTdVtqZyMbL/2y9rlkPZW0F5FFxG6aPqCeqTml85wLf2vYc8T" ..
	"fpDGkvslrMXm/1yR2Zz72cT1J39RtpoLktZTwEArQ60PMMOQDdqjbmg96XgxsXLOrTXtUCmXN6ch/rnpCvtokz/PaxpUD6lwxGtc" ..
	"HM4cQxcwEGN0BGRRouZc+rpO8dMoj5EMs1WbBLr6ZCwdoRb1awWd6DYY7NhC/itZOoJci4rZugi9aTk4EaATFMGKWBVq3sed/hxY" ..
	"X66qiZnrL6EFh3eWCxuKAIZstKCxqk3rO8hNdLNOud4owujVBuBXPApmAOBM/ZxCsxiou9gDwxmgH3JvMNsUKOIrcFHM6ADIoNj8" ..
	"SPgxMiENSbseZv3sh39cK+wm+yMXL3/2NGn4x00hn0NRPfCCFN5GboPiR0vcdyYfzmNSpQY1ZCzYsuWpIi4PY5TrPT6psLutASn8" ..
	"XNppfjsJZHM5eP8XR/lfUhMxAaBxkDL0mcXACtD6r/p4+05LdOGqN7+xE0GLuixrzsopEPq3l3Qcxwq4vCA/Od+pIBJAAmWJXOpE" ..
	"orQCBc8LIQwgmFjSTupDxoaDgp+Saufe3zHULUurZ3m14uPZ5cu1lqqiWTyiO5BXla+zATV9MgAqgNIT/3cGWHImd9+1ZSPNH1Hb" ..
	"M8LLu2JsbCkVrX57bQc3l/5D4kqBbM+XpbCzIBlW0Bp0WbWvqHtY0xvpD1vrmRkulK6EMhORUIkqh/O4I5luLmw35NZi6WuZDn0O" ..
	"VXPHGGWGKLJ9U3lzsRNC0t1oAlho/ce41bHw4ZSZFnod5rf+2g52gPSmcX4OoT96gtFBy8+ZRzmg67cAuUN2JbNatjhVt+sN9Fz7" ..
	"eYmTAi8gPA/pOFMfVaQExYH+GJ8qqEC9HWV1leYovhAr9LrRc2YihNjIp7YG0sBKj00WUd8aUePm7FTUoBAt0IDxXor0eoqwTuaD" ..
	"DUhodf1KPShCq4d1iQNabwaRmu1dCXXwq0Fu9vjKVB482a4jLcJc/o+6GpiJ9aAv+xMGwER5X5Gu0WDyz5nZdphoJxmcsYj6ibdP" ..
	"GPNcnLT+875CQYUPanyiLKYLewBRIsMrzm2BaMPwbLwnlEaaGZKod9lBRS5AP3YlUbf78Ffi30PNAM61mabtA5no9RO0guwPi4pP" ..
	"QzUQphN2xyoKmOQPFK78k+OAUO2M2tbk7G8AkTCnf0wmvpovjjW3UTF0aP0gZ1qAqJaz1UgtmX9DV07t5NdDIqkAGPd7mJt644fe" ..
	"wVuwDUtdrkb/GGLqYp9lKHd/o+7s0vuxrOrkUeRkJSA87gtVeV6E7gHgBqte/xO9q+apXe5vhlzRV/LVBXNstiDE9AJmgHiodi0F" ..
	"gJROUCRwpTl3hVqnipfIvvBb385taDsBBghTpnm0fbi5pMPe8tkH1eyt62r13vLl0XI3qovgwd1zLHY9hDXTdemIe5fvbOklypqk" ..
	"V5usz40rl4YinwBwlp/wM3cB9ooWSNtsLpHd6slQwbfN2ZTEV4K5mzptbjgPK5LvNcN0UXDxqo4f3M9CT99KG3UBU/NwFwzZglxN" ..
	"edEN9XfUstLdCRXVy7nxf5Zhmhr/TJHVN6ok81va+hdM948KrfTDPPDAELkKEM3m++L32kAnijR1ICiYAs6oq28LFvPfg23+zKbk" ..
	"I/qZ4je5paJhEE3f87v+PubhS+J2SKZSTv9mn0d2qZf4sKAOgVCNVKSD+mVwa8Py8LIlJ3FhChGUOroCgCIQ3A0g4VPhoq4OC+Pe" ..
	"N+YlWLcVP6iFkwqR9Wl+8gYty1McTF/WFB1eXG1BRc6Eatgv52W4xhYEq7lb2WcvjXvqI6NgqcWOXKEBi2S86V8hL4rybJGGFloo" ..
	"S2XC3idaLX9cqN/7ZvFXK7m48jB8EWfegbFNssL9Dgq5n+5kWCplBx/2jEn8dRPUfTbXVI7J9kyuCGQcJ3SkWUrqZ8ejwJn3vr/I" ..
	"bouQ4NIOGVsF2aO4Eexm5lTs0G7ycptm9gc7x9EBW/jtXYC1M3c50xQM4hFI+VSqE7wp0z4fhsu4kiOR8l68Oyb2M4ucvVJQXOmh" ..
	"IcDLinjVXQ3efB9jh3O2Ha07403aT2eGcLB7lbCb7jMJAXlpkdyY11AqIq2YV2knAHd1JXwettKfPRdvZcE3ut/3qm0aVMqZpvzp" ..
	"OqGzF4Yhra+0WtI4ez7ud3nbO8U3ao+VomF4r4x4h6IOgUU0aPNpyMlZWLDhd9mV7vNrYHES4wqkH8C9B5psL5rSAC+k32pawcD/" ..
	"5L88h2XZHyP5pnlgs7DuAIhGbHS3878MhD7jfYd2ovD6UedbDaq9HdzhOvi7c2xrNU9A1yHTMy4FFxdAWIOA11GtKdqpeSCMViRy" ..
	"Fbkd2Tkc+xcKvbp4HRI3IZUkVaLaA5ckIq1W+SvQKzQcnRNsv3Mk7uQpfKqGadqxcM7tMNv8oX/oAOnreZDIB/gdz9w0G/dLj+zE" ..
	"Amna4Gsdqbjk4vxwTU2dIhHhQ5n45tF/FzdUY1f1WAPtO48iKkywi4MZuS/2GY0mRTDv3Fq7bQ1hdQK964NDKFmdeahoS1QZ0hiV" ..
	"IjgClhMlzi451f6fzAPOnwQBbM8HeMQyLpc0pRrfm4vIVKIdSNvwgNPd8yhA56DMEZnctbSnxaYGKkN0oFPxnHcnU+CqfcTEZBG5" ..
	"jntwMuGITvq6TffSZdFj9GbHApEb/gads5Hsp47udhjCrCwXBom0M3TVxtxldsB1lAUlDZycvX5TCbsjUMuKGxhmoG+kdDIkSVFM" ..
	"2E31GvCr9IRQEfb7CqXESxt7FfJ3YvgojLsraiLcRTc5azknz5jooFdSmZ+N+0TLMY6jI3RgIHCQKnSSMM2DMkcReSXM8MwKsW2f" ..
	"dY3KgKGxeAZhCkJNX26ImhxpahXr9MhTxDMVlRs3EmhBui+7R96rCan+UtPavjaKB41tF1sF0HH4Kp4RjxohXW24UQ3J+dq4yK9u" ..
	"Bs0TOlol2kz4VJzhlnrfWBDTl8w3j6suUFGYssfm9vggE3q3mZeisigL16EQeIioLeDTfjZpUdz20PX+gyQw5oApv8ZX9bYp7cp4" ..
	"ipqSoeW2kecH545aehkmJN6fu0q62qvYiJkOXOcoGLH/JJWRfk0L0LG6D1Jmg97ndHn56Q2/MiFiyZhU823PO7+tQAXsTztWlHY1" ..
	"p2oZV0U++ERrDVxu+pLNeyjoLblAZ4E/hFk2iPahQRnlCb0QcgsFwCsOsREa/Os/B5BZGonnT8Q21fcxfvKzTZItuwjXs/KiMUIG" ..
	"jfF2DAmsS888wvw5sdDOReh3LAV35I4MXE9lFAKJazsSEYVdCZ4XwMgIpbydzsS8P09EH9praHaNO2P9xowSvMQHMdWTtYXrnoUs" ..
	"Nejgm3FGPmd5PqKisV1eh2wC70u115F/CfPnjfBKb1Qli/w4z7CiJKa3FqlGnB2xaOYiPeVl7PjXhHMkywZ7hrpPr00I0QrwK4BZ" ..
	"8wZFf0/7JRfguUXWlBLYokbWNLG1OeyfUFdDLXeE+yfUGdEoqNwXp1qbumJmzD9U03BCnXW9EADSaI7XqEk+Ti3nH+cGdUVS/tNP" ..
	"GBHB2lH4ZD5+MtvxLCDLKRFU2VUy9y8HHz7tbLy2A6eQ+Me7z2F06TRJJjvI3XOlkDww5LpQQ5sWx0Q3nvCmzD1U/jztNMO3YZ/I" ..
	"RmgFR64xs5jAM25sq+HGTjCbnPNxIPU0tJ9C21zEceqSQz/x39b+S+lPUdtzac6bDrtKfKz1A2bQw0Q9jc/GeuPotZ0vJhFjOLn+" ..
	"K7aHIKyidQ5ipKjRxLToVstW4dKjrrpHc5iiMaqOt0VLKL5HexT/mzIH3J54HpIpk/byFQXe7yqMDqfn7v/DJqN4GejQuOhak72r" ..
	"9abR9dhvn2Li8fksgFIeCWN0Q8KVibCv8gxvHlQhJGlcbqNHr5JJjuOymqUdoP05WztVeC07ZV038IKwMj/zWBIx5a1/1LbPhQRJ" ..
	"ea4l6Nmr6YZo3ArCezQeJbt2CLzydFp9Xn5C+VeJEHlBhiTsDAiAnkm4SsXTx0iqlwLIeC7Z3NP+PHTBPyRwmLLVwCtMSoPjog8s" ..
	"nvO3xC/RlJLHKcX+UfAZXHY7x+Qvt/lAHhLcM0iFBoO/2ywuFL7hMP3TIdcdlr40CYvJZBoIcz/340U656Y6MNcjrTYm2fJkWTcn" ..
	"odMyGjcDR6nZeEMRlvdHsbvWliCwCXYpqZ5TRftsZx9jJEpT9h8GnSszc7BuUjWeHqhRhHF7uIxWsRFb5m65onROqRHo2tasyF2C" ..
	""
local PAYLOAD_P2 =
	"y7oiISz6tj/V3QzU4X8hxhfPkmEd9RzAvONIZPCWpdMOrB2jz2NWIdkafKx4UN6ZQc8W4ylm3ltgitzo5o5WKoWeFcI6XM5hTMCv" ..
	"uYVqCZVvse3p99HqgSdKrDOoC/hbrVS/tT5g3H6ahSSnfwoLJC37PsrKb/RCTsok+jkS7w4dwpyb5Ml2o8/wTPDYeQ6jKqFVbujE" ..
	"2u47L2gQz9gbJOElMCk899kKM9BoHCHTp2cK/oPc5Lg4A604ZcjbyFud9j9/WMeJw9yOcyteSxMRg7g3MIoVHh2F68OgXHsO/eh0" ..
	"T1ph4kgqwhnjE0SS2x5X1mqMC6kpBdVJqEfDb9jGwPkj3diRgKPPUFUJVt9Op2s/anUgszY7UxUFVgjdn3x7ekdm0vvxoBqxH26Z" ..
	"e5OSvNsHPqEyEOC+uCYZhJz4wz4ME31DVJWfC5iVqUy5aW4EG8BRjNhhEQZN1P0GZ2a2LHjHJlSsvd91Lj4nG9IEzlvLz+Sf14PY" ..
	"GmZmnkjjfi6Uhfi74p9tbbxVQod1WXq94W0gDdfD2NIlIGlkVzrPMc+4/m3b91cAVNgHxOubNh3GYzU/69jHFghv2sf0MxrnhXW9" ..
	"EUZ+3MrkIHbYWaAArCxywgnyu1euHqmYeG965YsFZNU5H4n/jJDiBNz2C88Xr72rPnqtladRV3EgxJsldoIb9Ch1XVd3WeEzJpY/" ..
	"IPIA3H7Ndp2R2AsgXzcsesuGkUv0rubJkzMhCOJC2cjP4lcSWGgYsPmp4ildF96KBh1HkpkYqG7M8oBYesoXpEqGgygSKJCKlZXF" ..
	"KR+If5Oq9MYGPnlnIZbaHP4YiWTtip659KSWk8Vrv4ZhpMG/uXkUceOy7E/DBFWYyiAqSgVDxOgCMgMurGiXglv+lvoCbr6QFZSM" ..
	"whReVu+81mGskU6mufqPCNmhFyW+fHQYijrZuvgIQ1tWLdSPlRcJFDLNa8O1CKlECZ56uJtPCLYZVE/y4LVQJZJWTXzfuSxzdZQJ" ..
	"Icbx84gK9cSxooB17tIxgQEr+qQ80ijXhk464pxxt+Ksps39S7LD14HtgXtHyi3XqcCSEJfGlZFxX7WftanvFFrBgGfMJK9fOkL8" ..
	"I41IuVNdniMPMLYryriDDI/+il9VAbYVpG9kudCw1xZ667ht0udKAC4uryI06ZEo230b4cBTsOjRSSuR5JiNMuAmExue+E4BW/Dw" ..
	"vnHJPqcf2Vw89mcfDm4gH4BNkljQ9n9c71qGsP8Po0zeMuVHlrd98YzRF2vSwwEshay+epS6Nf0Dl2R0ZXgvxhqZ9udxZMXJG8G+" ..
	"AYpMOUkhRofrfVQWqGl8slU8XmjhV7DSswmXc19rda1JtCPttIw/C1crRLFcs7SqJQ68yyBkptAyc2G6y7O/flXIN35TC+JMMJCX" ..
	"MpX5xxSLO0Zt1PgBWHfNriy53V4mnnpaZCjzuMPUA82vGDYKx7Dk0/g5Ocb7pCtlUjdTgQ/214W98OvbuxRe023mtg6Mhk2OelBD" ..
	"qPVy/sz+K0eWT/e89wBZtPTgeXP2sRWD6hXpeHgATGANCKfEUwDXl8GxAZluq289gDAoBQd2pvv2ZPMNi6ruxXHPVr1DboLUglqR" ..
	"TcBY0LXvWWqcFXkxaN04cAmOCqjo6WoVOXNp53Ua8IQ904TY0pVZlPcb+kTuvzCHX1x+oCYsPvEMsKo2Bs1UiIix6DDmL4PtKqG4" ..
	"c9lkoFpQVmIWyUGMilYIxM0EFDclv6plScgqJKFlTAh505+OuJ80Du2ExLXVaOu/92PQphnWU/whFWPK109S2dHDjtyvrH8p6ac7" ..
	"VSNdjSSEMBgZ4hANZwZb5Da+zGxqmjgiupBazXUQFYWupV1IEOfZ8v3Sw8rF1a4vtUrO2DmQpgPjsvsfPms8WZFuKWQXekYunyTq" ..
	"Xd8wSB5TuOfOSJ73HpjsUb+DbPPAZzHz634KoUkZaXollZyedVaBfJ8yeWI3mB8/3ls31DnpiOGIo46Zb/IjbGrB7JxmKYAfSH5g" ..
	"dmBqG5wPethfmODiPIZHAKArdCZldCvEE9J3Im0Dst6Yis+nLk2WJkLKJOVYccBTx+SYWvem/ioMd79kTSN3+ahhX+k7kqal8W4M" ..
	"g8c2KyCK8aViNotMK/fVxC52zcMB0XubwwYsZb/YngGi1znZnASsi1SFas9Xrx2SWgOw/HCxGHwzyChOhXNxI49zidbvjKuilfEk" ..
	"lsyYjL9imyYA5arfiRlj1WFYEry9SIoU2RMgXtfa0rAsmzDZ2vULzuGaVA92MOGhS4jb0j60foyQmoMo9PX9Zn6qFc+0hM2zpYuZ" ..
	"P7Fd7xZFbJZ6iTuB3dbqD/Cb3xKV7ycaE0G1/j5aUzOYv7E00B2TIhoDT114lO2Pb3UJKAZ6qk/4o7Y1UMeETXbrNH61+tbMuuFB" ..
	"fWg1tWpIRT3hgDwnmHofXXwAugGe4nVkv4LRyuAZwt0AqcCoZAGoSpOxWCltfSwsfOdaba3oMNX7BRX+48hmNqyARO/p+yxob3hB" ..
	"ysMB3/t0PcgORCU6JjXCLnzWqXrYVryP1osv8XcVNi/V/xTwJ1L83S45m1dlFCReJfNEcH/PpkSC8lqfQYIwnUTtyv7XmaNs+d0L" ..
	"Fvb78NRJkdubprRbWUyIiB1fQ7Wur8bS2GQHFMtu/y3v/+mYu1EbSlvkhIM6HAzueEsZTEWViGlVtDGmpYBbLsBfeUMuZyPLuqWX" ..
	"e/T2yMRXMX+lLSqcrsl2AS+SzzTjjP/pwnjbc0mtqyH3rtZF41RqtAPH/hwuh9AXYgQFOy9QjsE1ghLz5HPJhWPPEpkHJ+a8WZQX" ..
	"gl+0E18kKIh1Ddfb5COJCIqr0ymH9AtPF7giSkjFQMMy/MpykMMQYfpbnz4YfyvHtBXjkHh0vv9I799MIVzqeaPkDO7bIicY8J/V" ..
	"A+q7Anak7efaKC7ANXibzutVgyJB+HjyJMBoMRn3ilm9dmDBAKPkUNv6WvjROoUBoajCRBAlE7Cbstof+7ywZQciwcQdvHm9MSYV" ..
	"3N64YKUIFfrnQIoP10RuIpk0OupyCKSE5YE06Ekdotl9RFNJ28GrGZJ3LoJIq0nDlKfccsGmEcTngwmgJSfoawba6mTUN0NGsCak" ..
	"rd6OE7Bue7GKqVB8vdqhw7iwTqyNe2AS3QmaKDcbQBu1LCyGd8nBvl1Gnzaq0kZB/TZPdAgKjqJ6Yc5ZVTl0zAdTpz02QXLn9GaC" ..
	"NLR2tYQHWPmsS57ybM2T2ixPKc2GqMWk4NwERjKW7XfJabQi4VF/ZFmKVm5wBnI4oib9FlVzmQmdPCvJEeI8Ze61/1QiZFVagoR1" ..
	"C6zIN9Ejbfraa67ngJUcFHOYaPAaHURzivtfvrcXkRkDDtfTCkl9G8Rd2o3uf79hJcbMku/XMwbS6IwROj7ZR1rR9pRSji1N8GWl" ..
	"biJFzgJW+9NwMIvQ/QSaMPyMZIHoCKMZMBPv0zvFkx3wfSbQ9Ah/svWagdsJgdUyobZLoFzmJpZoJjou6eTjIwD+zq4YWBWPYbJ+" ..
	"nUti2z2rK/fBvLZHCKEjAk6NFtKJap0xdTLpnIk1hDPDqID5L6unKjWX8kWQyzelRM0sdJVvyxy1Qp36uNOveCK8Z4cP+cgNEAEH" ..
	"QFg1hxPoiXdHW2jgzjn9nRmvNokxh/p+W8VGUv6hWwFpELGkAmHEb1vJbJj6QqCmf2cUgpJjTdx+gn4R7pWIsSTOnI20AgIm1SYJ" ..
	"oZZ6oIactPTk4DjosiOPCEfW+15oGtes0W2JvxAvuu5JVZkqla0tw6vPUJ1m+kMeetMqoU9pRIosP7QhrjUWHrZfUqo5ulcVzU1f" ..
	"1zxDCwowR+cbTltFk/sRyBHIo/biIM/LFrDKpfyj6u5PH8w1DnHH5QhNuGSQQzsQzl4cOwHRtNWfey0+QURieRvSu/XUmKyRBh++" ..
	"UMW7KDb/PL1HpzeBh4H361GtwVzSqp/eiUqy5X9GFvvB3ZvuX2cP0XL/oSoJtHnv6rj0kkhE2T9A21CZAKS9EzBF6dIxtd9qq2KP" ..
	"YSUGxaG40rc0Z15JhJrTS8+PMNt3jHPhiPDEPtSg5c6aeL8+x7zfe8Y6UW2V6umb8bafFjuRs+fd4sB5UV1GZNfXusI+ijazseCM" ..
	"FCG7CJH1s6YOuj1oOxh1ijHJoX7OA6vCgeLM65aAX9sw9fSxR4gvrXixQ/05Gyw/+7q4Ci1MgN7pq1tIKz9qjOitaK2CK8DNU3Fd" ..
	"9R8PrK7X5QKsyxmya6rY3t/vvyNUwYV138VMgjxvOqNC5BaN6mAToEOD0BnjjhM52WKrL+2iQaTmBEAcsRw24nzTX0W4wrE2D56o" ..
	"u74KwTbbiimJOqnqzIGsAqb2cMdXOSun+lQX7/WdbEOxClecvCjlqN/r9aAz23ChwRP4JWAL1nadscXfat1WGpUxFabmqFBtUew4" ..
	"4qZ4hAlpjv3e81KMdml4w+hk3ItdrDCO4xGgJItMdAObn2VlkbNTb3DbR3D6NTpBOfMf6OTgEMQXqHIz0D5DXDxx+GSk6Kn5Q+qz" ..
	"VyPDbpl0EiMtE++TmQw9QKQvJhxKGE33v2HG3X8JZBiTSHhdlFgi9hFS2GefDQOz3LrCTT+lGKYw4G8Ld+H5j7YVWZwLc8Mea8k4" ..
	"Xhsd8mfgf2IleIRbJvTTSIfjUywn8SkgyF6U8nGxHoD7MRE0O0mpen/LnahQQS7JM86LAdxY0bHz4p+Qhe35PKHuvJww3EZHV3iu" ..
	"5safVQTK2vujUTCJ66EbTndegJFtQRbewN0rzAMy82Bwc8tkGDJX2G2k+7d07Aix7gZWOIzAH1eGZV9+ctv5uQF7/DJthVfjxa5p" ..
	"lW4Wew6x5ZVuu+Uf2rvv1AuK8+AnfyaxoZOgB6YNhLFPbrhqfmkxSKGx8b1QQyWgJXU1nQNAw+YYT+T/jPEnosRCedRBN7F1gbyK" ..
	"oh1DXEdSOnNudlhGxEq5bIJ1m5yAJRIUVzfMRXf7r58F+pycYhmta7Fu5NnB7P2jJqdfoOmxcHjjSz9LxQYx+YRphDC02nRiSPyx" ..
	"ThJnKnMxFT/vRVkoN9iUDMVrYmvc4W4Dd6MI4LBEgxLJnDcwwccpXdSsh9O3aPm6PMeIZWSO2uz15N5K45qSM5h1cbIrVJ8480XE" ..
	"MwABUnvChiCzceaB8A6IO1hoe8Xz1t3MtARSURiNdVjKwIZvFB4BgLXNJ2ej6chw2+E4vWxJbydpagER2KZGa5Qx6ZtrSMcO19k4" ..
	"Rpe5f1OUnMuzS1aOAT5UFD+SlB5gEG8DHBkyQ1mqejni7hITwGDSiLpa5JunjaWdh5jRBW6VNvyzgkUOH6lLVso4rb+ubX6g+jWo" ..
	"l+vjXADPXSf+XQwrvY2BUKw/GLiwzhvmH5zw357OJLcb9eRJzFAy/3mx8V2SjSmbfJg22GVMX7BQgNlbX3fbVVDhPHhBYJoAfaNK" ..
	"VHh3Y5fuYy1GpuyVsCX15kI02KE2+wTML/JP2u7aU5u76nMEi4iv4RP/UnGxG8lArvp15gtzmV0Yj3vWskwBoJzfVGkWkh41ZOBD" ..
	"3OW2y38VXkL1citd58hcHmjN5dymcCDxKTl0/YQLcG6EdB9FaKRare0z8UYykQaMjGngV4rqs6HbYQmZXrong5ttzXKOVrS9mEtx" ..
	"NIJvjJ2HSBJx2Hx1hnFOj2A+X9lAiKwULmt6tHAN7fWW+Ag7ujyjsFZMEt/pQzmIFaIJ311UtE3D6rnduqgbFPrxOb9mDbbrW4g+" ..
	"unP5UuaZfHM80n9agBjcaOawSUZrhBq1ZbJKpcmJHhphBnRppe+DeYXM1KLH2iAXno7TDTWJP4ZOALPZBQpB5veJ3GBUkktr9VC6" ..
	"9/V2MmCEg1+SBCK8afJ/1lhZ6ae4LUyQ6TSNR/NQMLlhXr72Jy+XuP+IxNLuoZrTJUyiQQs405kHxfN/z7Po5fKh7GZvZXzl689H" ..
	"SR8JL3QlEk2Wq4Lv6EjfF9ODdggm4KtlyAa1590B9WcQfwYJL2UAg6WnV+1aw2ZcDICjteqmJaB1JaBj6OxsaoP7Qx6hK4k8U2kN" ..
	""
local PAYLOAD_P3 =
	"XKRxrTVUTOFYyEU0k/grGR9Y8rSGnLBsvU1f07WE+Fj9uQwNWU3T+AjDQvVwY/9ilSiV25038aaQwmP3QTzPq/WbGVVRZFF1klKy" ..
	"KhD3YXURgdRAKgUCBe2y6ySoZlq91slS7qGrr8vgLv10wJu5yF4ur3ZCdMEg4zQlgyoENVLVeWjMOCDYhWZmktc0VrsyRYqzO+/X" ..
	"ZUCDS2iHcladZKy+Gg5wRMR+oCUWjS0xfedzr0PqwqZCFcJRDZOWfmd9xpRyQ/0AXEcldkynDf5IIATsjCPohd9cdFu/eDrYCC6p" ..
	"3ePf8grwCW65uTIvojm49KxFTNcWB/HJygCXGgzdAByPmDhpUOKqYUwSHMrWX/76e4uRA1KAw7nEpkFS/yRvYL+O47dVkcTpeI2E" ..
	"uP/e5L5Y5kieXie8Law7V4qwmh+G9hW+AKEgr1ZkT+BY60I3NmoSueKRQJuYBTdXYsMTEgCg0e2NEnpLH8Tj3OcPVKgRWGcZgoxf" ..
	"B3BR9QQaj921I9pEhoCPmwQgi1IpzYb+jFUWsCaIVDfEJ2Lbhy2KD3J+Sm1qJtqOmP2CH8qfC15Roy7oGDK211fFSKIBpwQnSxu3" ..
	"/RY1nKG5XvyV2oQj+XqSMUlteoChbR9FmCi5o4yebn/YaOH7bmCM1wNaH/qC6+TeF4tpw5Jx0cgxfi7Kn3oxy7rr5FYIJlCMV10L" ..
	"e5ikCVNt1TmwnGYTyWzFrW0zTonyFXyBZhWi910ewU0RX+5tIqzWA8UzlfU3PCa6mP7uvVyTRwtAQRoO5k5aMVt6yeRQtoLy5JU1" ..
	"9Q+D4BNs7Z2XzVRUlKtoYrvYFIgYk3T7l7COx5Rd7N49BZL6Wd5w29ztOitgnqGD54nLnsm/f0Pxzt8kGTRcWk/x6v4+pCDx6tME" ..
	"EmQL2Qk9ozeYC5ldkz+6uPpb+t3XkxMA8C1apZs7SEivhKZZ83WGo3iiXtNwKWzKMwwnrclSqGd1vUieY5RhPzYRh4g8qZ1tKkgR" ..
	"eAkTBWa5b1a/EPBx1voU0CbMA2C9nreSdEvbo7W4HvQDryUhk5udVS5khWiIc1vRkcT54ZKmPRpztY7GS9Wfjak1u6Qd7Gqh/gUF" ..
	"ffJwe7uNoh5HNR1LqJESbja9NCrwxcXgykOxRggrOhEpbbH5Alra1m7Agpykjx0ByUAl85k/omNJczT4uN7ljOGcb/5HZ0D+lz65" ..
	"rBEQCYcmNojPc7ei4+nGr9Kc66pc8RMHk58Af70F9/u32cFkf74fp78llKD1gRxgJoysy7TuQKA0KGGZLQ9+hjXwoTPvaUVg4Beg" ..
	"kXD+qaMB0lZfEaujqFjiV9M0meei6F4KRp5EAGnkm2LEVwaUFcTelOzRDio+jdzJ/jwGUhXJekqCmOOE2jG9wm5k+gU6pKK+B/Sb" ..
	"vZJaMIopjagaG+TMEyHB2ef9JV49JUDJIPbS9/JeQlOb5358c7FiNIb7mWtdQfWPaft+rWtd5VmlG2UJYeCdrj3+GDB34hAjnPpo" ..
	"MingJbjogNVeO4r1WZX3I+ef1l+/qAjkU1hoxyrV8bYBQ/7be7+y94qUWU8HiLjaCoBPyc8hkWn0TFyKInkuYcf4LTpDGLKcuUrj" ..
	"mqJuJAxX0XTJDOTsXZmQUg7iVBnOxH0xkxDh1FufO1U5YvkcT8NdgAleW40hvUwkPCYKnxyC87U/dP50flT+w1c9KoXSepey0/Ll" ..
	"LRfR2A7jfGHrUeGopWR/DjA9NywK/3opzbwz2YtYQ+2zSy8WHkyOiQqwPPLrSLricL/8HK6FlcdAG13u2auD+I5RaEgPguOjhC6A" ..
	"bTMu4foOLj+sMdGb/2X2PhWxK07qcQPFszMP0N0FlvrHRcZ/PtyjrUrxPK/cAvIGB6050jH4S7KzcYovMY/W3pzITlMY618onnK0" ..
	"x32JQAduP2kRDXGkyhXTwqpdJ1Qwzfl+UZIecL1ohMgjHt6yrAIr8mSSwqBvmcg7BjzNsQ+iRaU5fZO7GENnlv3Bz4P1pBPpPJJQ" ..
	"W8iVFIHMez4mnO3Noh/TFSL8q2FD98OKSsZsj2hrihB6LUUs6LRpUkan8SewaioTyOjG8sXXYRa27601Ek2cLnqQfoUdnB5IAU3l" ..
	"GpQoiPJ96dmOPekH2dnrNMerXBGHGWsFz74d4MAsC+5+1xy+vgJ9tlTMpJtWqX1EYDwjv25szvfbY0IEJlYhoyzhQM+xx3t1YfdJ" ..
	"XLtygtOeyMN5HxyX2AlI1Rramise2+KaOl6cf44Hf1dmam2a4w8c97JjTgRXFZwM+vUzDl6juUjUjj/UUQlXWfAcnpb2cgr+IgQE" ..
	"8NEWDkSfefiLPMp6x4liScjAbhlHmSNHdZvAjUit3uR1sGdsIVEXPn7ESzIpqsJD/U8rCATtq6Rm7rYW+bpbsHcG9GoQdcNJe28j" ..
	"wfoiLX34GVoTPBRoWwmpgUB17wk4x8vymPuhQMytDf77tOyHJLoqAeSz2Rr2KuEqvoxiDOzjxxD6wOUPyWWk6Vs+wiL6uxf6he8L" ..
	"Wl+y1ZAscS+i84BWaiY1f5AJLpffaUZlXsaFg2/WHsR5nvieBHFRKKYhy6DKrTtiATyb8TxxC9CBECK3erJGvgA1nWzJpWb8j3Xz" ..
	"95y/jlmpKvje7Ny9jVm3RGD3Vp4Ho+EWUaQESqvZsBH8i+rXI7MR6NzNHDT2vZ4mqBk0j17CzHNCkttc6DZCzVwUR2YK55s0yc4/" ..
	"MZJgrZhE/jED8mfNR3jWTBnOqdEVTicEZ+wry8KdvsBy4X7f/M5jcEstr0+AjTq+v9EFKuSfzG3GkwtP2CztehCKyZe3p3f1D01u" ..
	"vFIV81zfi3DelpNIM57+/Xfmjg9a2ASTmIBn1cFrV11rL3zLq/GJXary15X9iGawfSfmTd5BqgyZU/vhUhfzg76JQjz9/Njdn2JL" ..
	"o7rRqVWQ837hDwgyl1beU6zK8GAFzICW3V5ZCiewBLum+myhagonLG5p0tp4W7RPtPOdnVWXM+sgAk849d00Cm93RJLwXS7V5hmd" ..
	"dM0IziXjYBuXLHCCjqvCadMK4bt7TKiVhtoPxwPYzVzeuDAm02mhMpVn8PSDhuY0SXfnda9Q+k0Jz12zDWDdibW4dVo6+f0ZsK/4" ..
	"d9/t2uoeZrEzAta4p9X68VrvLovMtNhy3BptctN7i4GNA/V9MunQlNitpSWKAF5IlSHYv5PhBNX8AWw7i2Z/7OO22uBYjnjk8rNl" ..
	"PzhwDy1LTsa/uZAX+BYnGVrQPKUtSmhOXDNeo/vsjN717rG7J7wrzYjfw0TJCZBbSANK1sHppLllh34Q62dpTTfr1MJoi8DENs5l" ..
	"5ZvOjANx1pt5lI5wbNWYYb7/hftOtZ3yJNMSkcVgu1hnJofKecnKLvZznTwI76N0wnrO49u31uhyl5eiz7EBqP/RdHX1KOwc9EnL" ..
	"aVrqeNrY1egSebX17Pi337AfL+t4FRdMFqLAa2BnZ17hVKRD2CQcALlzqLJiAuAjrt/fgNau1aLHQRoedIXTCtBKN/EcwWwhiKNR" ..
	"ec9HTm/WOfsDsjJMrn1gIYBCD9F6kUTbfDbr9qoCkPqCnUhl5Vn7EVLIlwoYzHc+7ijPszXDGIM4l1TR65EsogVXEcNXadrNR/HY" ..
	"wPCUpjmHtvj7CkdSRqEoyucRGDB23vFKFH9mHFT8MVe+F47+LSADgSujmFS/ePX713RnvnUaRPD8sXdruaywocEqhSvW8IYRD16f" ..
	"Ta9qzfCIzK3lZGrJ64pHC3heh6PZpWp9RVGyPetEVm42pD89Hc/kdmdQLRT0sQEOTG0lbOIPaj8PbBlb+Lgu04sjRTHVPGWytf7X" ..
	"H13TqT4hEjvGjTpvVL/pP1IuBQn79Kd63If91hXFGMmD9Tg9oaefyLuUtMryFsoHE8J6N3appqdtxRvVmhU8zxHSEhcudxBR3Jkk" ..
	"566UuiJ2xyCEZuH8dL6B2bF/en/IT6SstdZt5B2OCx6frAyVQXQx5gJ4am8zogT5X+PXjdU7vYaSHPJsvo2Krhh9+tMvxHZjLiUP" ..
	"8sbdgXNN5B8xaneHg4UTLoebYFfZJafMbGVFNMsnTEZ1JKx9/kUrBzlKCVzGETEEIWybuHKxllXJGewYbyJ+crsCBL9lPjJlaMhY" ..
	"KpTRDy1A0iq70sdOqD0HWMJP53pIVPS8lim499hjTcnXvc1623tecxvOfFrHmHmXW01gRfLxqDbGeV2gYV1jwikhXjeUco2UZUrP" ..
	"p3IjAW/00105vK7WM918H55ppLsFVWyxLMEeeR2pZE5wrEGMoAMR3tBIVjML6S0yv89rdRBdhKqgitZBAw/dbFUkMfXdZ8E66PO9" ..
	"3MAcV/zT8XjtgiI56krKf61eVTxpnFr0N3EXCJjBVvOaPbiovMZk/hLZtyrUOiFtReXILwbCCzVN6ktpSZS7hFCYPPN7IpbCAJY9" ..
	"ptHjP/PBSOYd/jsCrhhMPylrMdrtrEVpKunukITE9JiW+SIQRf5nJqU7wFPLmAOj/1lGFsWt70/BS2yCSl2JegLtqYrAEhh6xnKm" ..
	"NMkqEh2Sj4sqHqIjiZtqp1lO3GQ4j8F20RninD7ms2Zc0DnuCV70wADr471esomfG6qesll1t5f22ueZdz+xjtXIpMkaVaD11kHN" ..
	"2ZPj2vjFVW3/K7hlh6Y39jfjx+ZGeZzQ7UhRrbJOpc28cVPyBcqaqAS57YB/b6yoqOxPje/pNfjE3HAaJostj8HJ3r99WaK34Kus" ..
	"zJayiWNEinLdAqtqxd1cb2oQyuUH74e/jiKkpwvih7XYFhTpNY/sIErhjbCRy7FumdaQwUGKe5dfKQnGlKWuUDW4OKQx2LjxMYSW" ..
	"+oEsJfTb4sQcSAFwWGQZytix7+0tilemt0WX2I6RIlii4uqcBMypqGJYd/iLZfZHunWq49SGDItY9AfFI2Tif9bsxWKByefkRRzf" ..
	"xM58Y2qLMBwA6oDbyalg+TPoF4fYAl0F1PCU1dnYYJ9RVA9wOkLEkECdk/D10KCELclZ8b0P5Uce7TI4U+x3u3NuDiSoM/fFhpfb" ..
	"zT+YO/gUcushCR4+Li+tk8xN4JYWWi5oWeOG+eo6L+XhOhBdL39vOkuINtufyk39mXtEGcEgSqK8HwzlU+pFNu94Wq5D1bRul+d7" ..
	"5EaZWxnJwE3mRFtPuQOtZHGgLfZtA5i7BWuUlN6wDnN6woTrHFaTbjRG3mO6JfccDnN8yuMa4oR2fxaeZsol3XeB4MdPr5Mfq8v8" ..
	"gOViQF0KVf9qdR61ixUD55ZXUy8xxGn/cQbfqtvWrQK/gFe6brVjFo6ZhHoIox//24LOHiKsotHOot6rpkkHSknQaVhMNIbVWWsh" ..
	"X8D+3H83tYolk6cvIMfydnQc8FYS/HTwXukG4+T/Xv1ASWg96I+sczG/sSuZbZRpHAPFn6JNmnuwurLIjy8EluEd19D3KAcKre29" ..
	"tOxPrwN6G6ayYxVau5RrEKIhikWzqrSyChGyPGaiFQIQ13Kry2TSWqBpXrxq96yr+MOXGS2mOknfK/9vgkG8PAjsy33RCM0RZ4N9" ..
	"K/RZvShHStKR1tsDxm5YpbTPQW0xkroWiqv7lCCZOvwAj+Km41bJHpxrj8L9i4V8Npkoe2HMMzSGppDqUqxNml3E5ag36ohYz1pY" ..
	"MdWwaUZ6zuHvCrnb1zWPYhwc+UfrT1iGPZMQzoIE4bDnoThkOj4bSlbE9QaFdv0ODIEoWNYBB93h7mVhOLKdKozK9gsI8pw6yMyt" ..
	"CsF66i3cGqguuOwVg75drBe0fz8anFcGq8sci53dNkEQxmN7vPVH6ogwElGIP7MQPI4EwQqyxlIxkOfcMSHcu2StkRLJHvVh7MaQ" ..
	"9prQOYDoD2+K7EeSeWI0hLRax5tGzOy+Xtz9XJXFEFwuzx7K8I23EfGmn4zoT9YU/nxkDe6ibb1BGPbcX/7LmZ2fEH8fctpkW0Nh" ..
	"qnBnCtBVwMGLajdZ4OGi+/5xIIcd55jrLn9Pnmc9bJGt8lnJl6TU3dJzhDWpexhRKs7Q+JqhWNh0/Xx4RbiChuQXAA/2nJdgg9DR" ..
	""
local PAYLOAD_P4 =
	"iIUDiPBL7MxS6dd3mU6Oeu06DFP6UL1mzpqp9RWR7rP4qajR+/g7YfZzN+Bk9O9dJ5ZeCX8lKjGQI2NKE20UFQFoT1Z7WQ+RUKSo" ..
	"UL+6sl2j291SzRSU5MDVRYbtQkczHRxJLF9NVhSw299hq2Rx85dxps3FcrKlGSgFHD5qwY6F/jlh5BpjMs/8yVk0bueXTX8XOaSh" ..
	"SJ1hfoUu8VH8JmTZeD4mNPCH73uOLGCDkzI4z+n3pzZ4KQe1BCjIKWL3UXYx4bhj7FaUUvjGIligXnfLdm0f5xYWqj4hnvucIRE6" ..
	"AmZgRes5PioHtGeDAtXysDThfVeXqE6loOsIP1JPH35KuqZMKUEqWAJrUzwX9JLZ9K5y23e4a5KPJ7u0AFC8wMuyBG6xzQ0hlBEJ" ..
	"rcS4kpgX6lL/9tbPd2RUEeNx5rA0wBuP/8EauFF2RAFmWushRJB3tAG8FAvL9y7UVvvg5GwRiz7+lhX+rDGY5t/KcTNz7NWmyrnB" ..
	"TKCcErQL/xpLpvws6bmhVsYmbFJfwW7awTntlCXk3Vh9SGDlPyzRZuSPZfk44SXv/nM+LBLlrRpj0vH1cgQqnAIc13UZBl6W/hxx" ..
	"YQC5JpL+3jElJC0Z/CsKcQP2gNaOJMi+biiDP27lkuW3MiN1pG/LCe3rEsnn4YZdfPR8bC3rdB1aewCVAzO6y0zVOXabchP6C6at" ..
	"HT+gkV50kQCAHuaZWD6eiZMQWVOS+ihKU8WURNgevvK2l3Kh/sodv4YxDQgr3sbwTFNEm1dYBsgxOJjqib0gdyZCxFEwlTvohkMZ" ..
	"yOqBl1Xf+//gqmkfGhNoAGbePOBo8WyAdMTj5wSFZ6IgDjfUBPd8DG/sOmIH3XbtOqbRDmQJOBiXOtGSLFw6Bq/r8hSqMnGuquzU" ..
	"OagcoHkmT6DIuC3xnKdn4K225VZaXGUGqZJO6VPBjBU4xnCSmK3wR7nSEt9vTXkqcvEQIRzMqQ5BP2PQGwyUseJ05qTDOE9qv0QO" ..
	"G768Gjxam1P72PWCxWBj5JZT8SPvp92MEMnV24OiokH1Tvp1mleFfXeer+aB95Z3A7y/BPl6cChalVg+hhnc94MrY1m0KeIGWC6Q" ..
	"v7c1MQrmN6oW+VOBGhRcKxX3J3eN2SHBdmID130dW9kriLykXXhggFFamGrCzKCRZ9lUf3Jo4wtvogELscETYWDqXR0MWhAV7c0D" ..
	"py3kDwRhs/baaxrtSs2LS28Xi+YrfQHK0FtgTsVNsrfBGuUn455ej2Vbre0K2E/LEnLi6X9tqj70urhQHLUhTZlZUXil4aRMJfAu" ..
	"3SkLl68qm+RIpuuzbiLtYmX9vUnUuNaQL/Fx5yxrwEZVGyYUgmkS+G7Ftzfqhz9slVOQl4th3G5jBPNOts8scFG3BqU9r1mQvkvJ" ..
	"jlfzboIW3isYSK8CB2OueO0Em4BKNTCutZTre8O/9h9sgj936lpg2dszXB3vP8yCPzYJkFr8GqJHeB36BJoqvQHEDaxqbhmRjCwQ" ..
	"HxUFXPeSm+fzDKPpxy73h3Ht+qOGL3Edz3lNie8Gi1wQEang4Vwe1vUy1nnbXmvzcGe2q1EEwpqvET8LbWUD9F1mog4rU8ZPNzM4" ..
	"6BkFsBAO5mY3xA4Bhu0NIpDiVBsgGnLZATIxkOCSR4geEggrgFHn2uelZTwX8RAgkFV56nqYz13SjzV/Jt3ogZ0LjDdS7uNge6no" ..
	"nl6plpJZnYzsb8pXemmNlqnrQHbRGfvgfxbuLG6ASMM179xruW5t7pwRQGdMdbAD42zbkWP41Y1dgog+ynOpZQ+3/Rf7NVWrYj4k" ..
	"e8WtHcHJb2nSaazVmi7Mf1Gv2LzRgx6YhcBiaeaM6QIuOsOgKYpBkLFk58YeAdvyP8S4Z4AFx/Ch+pNhXMbHtFqngRfZFmukHPcA" ..
	"XckzsOBau0flNsYGDF316wtw1oGAKYE/J85vOnHuIy2klmO5Zdz65bwHdw6UFDvGVQebh0HbbHpQplwuZjDe3Mjl+H94mpGCKPPZ" ..
	"l6d0wGxYmhFK9TQYE10++3NT9mjFzojC7Hw/yNHaZq1gj+8bxhqjgfS2dzIh5dlAUom5RCaRHfqx14WJHTd4nxVQWg2bvzfHzRDV" ..
	"/0H26z4J+z4i61UixvC/Iv4UnR5LzVQ8c0t/y9Ls5ESchoT9g4o4kzEpwCBd5Zh/n5dGCtbM5hjr/WqQdJgEWo7aX0K3f956bL5+" ..
	"veTNu17uCjkiRqZKPovycWJOJjTuu+vTFK5o5Y5qd0wyq9v9dgyXSxOwJLKQB/Ebigxdx8yterOPu51MsRqUfg3QzcriBlMonHoq" ..
	"TZPI18S/8Cmdp56ExsFFwN7pYGbkbp3vZMKnKURFLjn+ZSjdHtGxj3YRl0m2sEbxgeimewh2EkyQrEn8LYnqsL2aBJ7BrRd1PSY4" ..
	"KXAqqXsODT5Z0hvD4untgWgRnn1olNXduuRFwnwPFYTKS2VYqRazNNUQX3l2wBG3C+wEG3a9Ek/xBFInvfZyRJp99L1QnyVpOxf6" ..
	"Qsch//elyxupV/LFgOU+9qxhztDuZSym5BLTm1qxnzHdrDEO4NwM781QyVYLG8nan69MBhIQn1WsZYP1b/VX1ysLCZJptQMEya91" ..
	"F2WEKTrftiY2AHTJa6+Sgw1uRZ1bchkU7Aym/UusfWtCfr/N70jcO2m6BOzrD3oYv6n3DSCyhcWVmfeAc1HvxfARvprIfgrJdOw9" ..
	"0xQSvP1uef4N7e16YKIputpzjcdvtKVlQFL5QukjGA41XlLuobLu2NfBHCX5ahAm87UepuHNp8MX4dE6ZLFoEjdkBFp7/J9i3G9k" ..
	"jjNeyBdhym/EG5YoS1pZaLd5ilTXhhSkQApHlhqRFG2P25OMXTyS+hVyHt4EeYQ7WYq4OUGibI8jJSTNVKbS2GphgJ/GjlDVuuB2" ..
	"ty5jQWhigFiM7A29FFuARNNRSNAoOHaajWUR52aMiQ35I+fO2ZFv3bcGfCpr6mPtRWmqYnlDM+wgSKp2DixUEtby+YQJkqO45l9d" ..
	"HwMBv+c9j+Ybmg+A1I53Wt+PCjVjhG4L7ihGVbvwCe5JvxBydDkpe+pnp+HjJTxGxS9o/ni49oKt8Yd5Dz7wSFBfibrQlmFQ1GBe" ..
	"czl3w2gAJWcI59Q2pl0xDnzBbhMngyCqbrAH0FB/X8y3bc4oNm7B9WnbCQzxCiHR50kTJTmmg8AA0Qz/olJXLNXmkOEkmoOSlPs7" ..
	"0aUBBUmPad5pm/jMI15PJo69MTurZ8Xf4spM+UxWXTp5QTx7kp2XD5sY7B7qQj4+7qz0unWXnhJdGlDhdKAJXpRHA4gLiHwCru2x" ..
	"uQVUm09sQYi/o0kgpZdaTWtC33gAbjbJEseO9tJivFXcTBHFe8feXgqcYcdSzHHxdmwulmFPQLAIC2ZNnvgfNFTykxSYhcMAxbQl" ..
	"ues0IKJD5xcjJzOxyMnIHDg/mL9H9S8ovXH/KceC/guBheOBB8BY4jvCp37ecIYR4sWMbfw1JOUrPO9duAlnD+zn6HCKLxG7Oi84" ..
	"m30ECsFyLSDA0YmzQyR7k3AuK+tskh+8ifUZuobSboXdt7V8A4858e64U/OGOg05LMAzZaQUCA9GhvVsnVvcwhOR9Fm5iihjoCp9" ..
	"khRk+G7FL2w4WYXj+R1qW6E0bcX/SWruS3ZPUnxAvG9fXqZPDm1EgcsAqeCzRUqOxzO+ckUsFQ0bkhVD5JS8YnrRaTaiQdQvfN5P" ..
	"x/nslNqxWCP76FBs96yeRlEjmse6a4bVygedjmo/cu4p2BdL4FhdgBAOW/0uILyVVxFjDf6lftrIdn207fqCxz5rTqvhNRPY9oqR" ..
	"F+vPRxuV0X1RWtQe8ANF5snpnY7P5HzaccV+t7ud5J6BZNdFVcMetRLVuDts7sIFaUynGHRTY26jxS7qDfk0oHTTxLOpPrGAbrdJ" ..
	"k/XkMGEF4DJBbB2gsUjz0WAcfZvEi47KWLrk2KuGCY7qQ/Os1FOdOCkfXR3t0ZCAfQKQRlOHSdDrcKURhcnPO3P8jBIPS/SKoTEl" ..
	"cOngFJXibMExE+qMvOTD35viD98gar0qJZTRz2LmNx8T8nneGIrZ7bseNNy/yAAtV/EKrNzyn1lCDEJgBAHnS/NE3Ch7s1UBrrQP" ..
	"ynFA0mVPDn53jH2t6sVErhO+zp0+R+nkOuJAITQSKzIndvD8QRk6QN9BIta6ch1Vo5M7RCBQ2CtyO5vuYPshd6iwEDS2FtXyCjd8" ..
	"CnzOymG8Ytg0Ms7f1K2a7BLGulVxqOCn2db5atwYbfdMWE7MUaUpzl9aMqmHXYxuwDKWxarRTkioo92LB7okkPTeOyv4dPsWvHC1" ..
	"x1Lvh3t6lxj9Ho3QWee/7rRF1tXP85BNYdLMSIbzGZUIRWrEi9Vh1ona+dOX2j3R7snLhDX9OfpfKCnPbT/7D1afkuSae/yhdEjL" ..
	"1WoMGOg9HbEcEQUFHncuu/8pqM+nj9F2Nt0Ed/OTMvU5XNJ9XHdFayVnfr5P+OQq7y3mBunGQDVLAsOJF+/kGH8Ho8msexLoOfoF" ..
	"hg8B8ArFa7TemIkE2gUzg+QQdFrbT1ySCrh3jIxE0jplqE7lsml8sbdZXiVDFfO2DcLVSBIsXky/JD3xcO9qOxAXbG6He7S6kN/M" ..
	"TtjbC2vMrGVpj4SWVO6xceIfj2vNtTQWwZo0jDNIMqEGWsj1bRdvS8lKMWloLoN208o5qWI+Q9b369S+LXnSSPAVcSp3IoG56vo1" ..
	"7Q16xtKSuYaV+mQkaGjCvfSTrrSJjlh1SrMCQAwpQHRehjcNpc6IC22IxrmDRcMoiz3pWEDp0ld96hqysSEWNc8bMJdQ5M8p8Cu3" ..
	"fNNER/utKm7XUia7bIwQ1OPAlzQ1FLEFPG6KMj0GasSnrPPtTWk+LiqMAsu/GbK4L0IsUApRPWYUoF37HvI3IGobLpDDsCwibEui" ..
	"1KbTtEsi81LotkkLshI4lAxIBfIsYoHz9OaGKgpTnvrHPpQo8QO7QPw377qDDhg3AvJpLnS8BI89zOPvdCwxhHBfYWPyYM11LMgm" ..
	"luZFBnShJ8qlrIFJq0kVIbRhxvPkPpV1f8oqJtKsKhCbK7ezlaOiuN4vUrVzo0zthmbg4VWd/QAgVWctrIbeWTrcogFYV85sQP+4" ..
	"PMS2PSuEMLW4QOgG5K9Lomnf9XjcfMWuceltZt6cVD8ni2EQEsWiHEpD05s5vKGp+UP1zvrU1ue7iHohdwO21CrhPLdAmpep8+z+" ..
	"pEN0nQA3RRfHyanDTX7u3OGvpweAIrTkQhv7TBbOH5GLxngyQiN+2yEJFxo8ejvI469zIvcrvDG+OZrbWJmk5/UjiuvOxkAptENA" ..
	"vd9GBXcFh2u29R14vK/kafX/X012LFJaXjo4//nqjUx7ocKVRQNc5+izAou3XBEZRfqe1UdtYTP090HST43n16Q1sWP/fSXU1BR/" ..
	"aS9W1a675XjjrhZ0PqXjkZFutGFyY6TwKPxoDBs2S/8vDuQkeOMr0ta6ezL23orT35HEynOuggq6SWpYIbRpqJc5KL+YBkRrFICm" ..
	"Mx9z3bmb6myllLbmYTZtJn0c7GgX055Dv63bwEqE954cdNqJvs9v1CanbzBBCJEZ/sm4sTgxXhNyE4+HK3F2HifEVCD4Gyh93IxY" ..
	"KR79aSK8rBZYlzaqbl68pB/7TK1JHg2FxCKseoVGK9XNcwUvGxBK+AkauaIQXgAh2hvkSPVVVHr/oKl/BvAkqJSsn/M14iyZ6D9m" ..
	"7QUQzlfTaMkKK4b795s5h5mbD6YLQSb5FW2YMoTZs/BPf8y67OAh6SOG5f8psqUkF4O3pGH5kr2EZceaHz/86sdWtleBP+/6ZjoN" ..
	"EB0zY0bKfpj2BuQXf01bg5s8K8548YaC2c0UyeRRgMqp8Y32+0AsJFbOaOXKyAfNYFH/Nz79jPynJRKpFRyx5c2YWwMjJiuFdIxr" ..
	"s/v4T8FuQdN0Xy0KpW1JgJfJZQzJTQ06wFHRuvE+krQSzGFWFYsuGU9DFWQUkzRcynZCmvgMird9RWJlAOAMHSCxg6ly7XXdpBS6" ..
	""
local PAYLOAD_P5 =
	"O3z6bHtqDkIb407/kArcwK9cHQtE7pPAW/l411VDwNYKSBHQW5FVxouX0gvCeG1evBUZZqI92kOYBiKWlZMw7COhPyPgUS4e4uv8" ..
	"Nu/ZkXbwIlQHDtv79w1KorTzEXTqodmyt2AmyMiD1YB16CM06mT6SgG3M6WHWFnZUviBN2kSEyrZnGsZEuVV9PapYp0+7tQgxv11" ..
	"SBqj2nKkR7y0TjRcKP7cRKgSDho6KlTsTu/4afFaVe7vFAdlrd2JI2fnRtbXGbAs24EAnwa0V9pNq02HUB6BAKHBe5bFcRpLqm6N" ..
	"rjvBux5EwsuuFastxZ12U1CMuhZYC5peeXbghEczlctha2XdZDMy0oEMDzAS0AhJUhVbJlWNFv7Td30jgb/c77EIgzxhQeL/Y7CC" ..
	"0JVYRS2srxAb5G4DKEMMdSBvRZNWhTiyYLkb6AqGJeOJ7YyCKk6nhWEC9yhbWvJ3xBVrN4UO77hoDZiLTdZoOlsuoy2XmrGGCUop" ..
	"hsKMgN+zeLCZuEWyDdUVG4aRJm+4Occ6yEnmXZoctR8qna9ACkzuFhxhdhQl/VUf2ibOiaT0o0phxxU9hgiaTSqK4qNVe74xAUgS" ..
	"tqb8QXxigqALXVY+ZHXWnnW09cxq8MQTPmK7qLUyEmVRF8xrWsDxQR5WtpEkUVfObeqb7H6v8rGo9/evIuBqO5uvRg/70qVj0jI4" ..
	"0yL3G39a7Un8vbi6Tcox5YrrznzgwpDQTW9Mx3N5mjJTC70wKy3uNbm5GHxGqcmmscAKenSwN0wSRt7poeuRdpXurVovSqbbnq6I" ..
	"VLPVx7qyhWpJsGY8p5HV/zvpqdnkaLVs3Jcwh3pqVvT3GpGmVHrH/Mq04ZiqXcPlIQso8eETtC4PjqqFPNTJPc+QA5DZ8txKuaov" ..
	"HZYaK0pKfOO5JLLw9NG5bY/xutAvC4yqBHtB+GijcooOnZW4Le6nxoFzBHYq6s47p6qx98CWvJ47YEGcW5tfaqYDpIMeVfgh+1B7" ..
	"bNYHpZB4W9tKb8UUZj5jGz+O8rSRRP/qZAW4MBopgCtu58xRL+bujncT1isa6F/Q0z7fZ2FdSnhMK9DlJiJiZOA2AYvlbR6aByal" ..
	"LnvjK2O7cnMWjsWUcPHAHMShR3Lqz2AVvsBwmqBSiYnlIVa820uKg6bkDSieGH4lKBr1F1WOWq8g9skx+D/n+t6M6nvH9k+Frzk0" ..
	"IDh4JSaR328A4JZsGtXz2ewJ0H1tbIR1sfIJJWlNQ//dgBrPPO3EY0VFnBBZNUl/BMg1dVqP5GsgNHe7dqhkPgn24GiBKKduRWJg" ..
	"QvdqMbvbaHFP4B9SvF3MaB982HHRsP/goEJfT+ouG+5JmHMnPrqI/LVDHAgtbCyL36n4C/dQFRo5oTjwh6+OmeERLp5L7Y+2dxim" ..
	"DD+neKQpVOiUBlDcj+zGCWGy4AH7pSv1qCM3oWqeXOSbTZfOGcghmjHma2ze9mNMfJW4wP2cPyjf4I0oJupI55fi10EtS05eRLHS" ..
	"nGFcdmMtwHwxt/ZSo/OYZ6Nx2OzDhVM6dcvjQjnrUK1CUxG8N61ElC8xSrMfz9qWkzQUQ1a3BsbJBSVKRW9XztI1YnEg1GaaPKrM" ..
	"oZqSHmv4ZhNIh0VjsuAGiLvE+2L15B0m1AoNE4Cs29PuDICPDvjkpti9FtnQFMQGUuOldumZ3gqspOmxOX3qjHK1jufPezfj6nDX" ..
	"zQVPYbQJPKU/Civow23rhI1FF5fFfhzOFWGt0ucTSd+K9K63oBsEzMCDszgV6P1BXdcR68mDn76OmviuX7Wdvdf8Q0DMVtwCne8f" ..
	"ElFH97Ex4hogQvG/MqxLd3jI9k1bt0tVviiRWT4+0dlW0NDFUNQQRg1qSPt4qlsVVzKEmFvJiHDNNXx7Mp1ax+fVrJs06m8KQYYF" ..
	"SRD3Y6ZAqyIF5b0lGGrRlgjVE7HkMw5wtt1wk9cn6kjWB2pP7vlLGsdlnD3U/G+4WnPnL/PbwreF6ukppZhy94Ra4p/4zGzRp4lA" ..
	"4J5Iewq6SMem1C6ILLz1n2mmS3/ZnDDjjgtrjtOx6RKSqw0tO399NqRqq+99PLCwed0yy4I4vMrKXMQK8j1rg4tsiKuLTVdSzGrQ" ..
	"oh1Bmp+aY/26OvrIW4KxHM5/MGHUzCqx1H44kXYppAYMrV/QP33SICR4yL08KIfXeJLlQ91MXRILtgfW8cgUSkDj5luRU6DaWIma" ..
	"TSpWFtBcHVuDH0f0Cu9ofT8ouVuJWmCwnbaHld4gWrsCUV8HRjs4QTYK9zJTaTXJePyWb2EWr1RtuTK2cqf/qroZA6s9ZbiXxLVf" ..
	"D0fHbMXO4kwoQqye3qkiwA4zF2UuqvorwFGOO/o+i2c7Hfwdiqo2JOzrZY1VRcOzQuhBrEuHpQWo0wmXr6/W5Jbaw6WfygMLnLFd" ..
	"HaL0WES7/F6jCA2hl3rE9uyuMrxrPYqx0urlju4dCnaeGMDxgrU6v74HXgQpJT447ULPC2L8UyFfPRKoKPFvTIJ6BZDN+yx4lu3K" ..
	"W/gv8tcTOA790/HVieNXzbt/vGmJ+k5sd5piPNvEoQ2A/9QnUYeWtmpmevqKQBCHdwNvozNCQScMyBKo0dySJD5dy6MkGLQIbMN6" ..
	"iRKHH9xEm8iEk5fLP/pI8zY1uhfyEiXCQG8Ub5dYYRxBj90gjrkY1d3keIFsfNZ1WC268hFS9cENiB1xpZoJ1mqdY0o563Ur98+Z" ..
	"jV72LnqHpLAyO8h5+ssPIciuqwXvV5p2LjltF3Yr2u3ub8yoXfrpZBR/aOG5H6dvmJyV3OTBGucmvPKlLD9bEGLoTKyJTzipeTN4" ..
	"8km9sGrmyFKeH/KnYyPOsyD613/RA1g4IENc5EmUxCXCKuRIbRsjgIDSYjjBObu7XoByziyzhoAl2DGHBqkaNILJxAaiwWKgO/0v" ..
	"SEkQbZQkLgCsgNic7Neq07KAUiGyftAwKZZENy1rnl/y5jSq3/l6bNOZeh0BussjC52DxtXthhcOameRDUkBWxhcUcZIkvU9wv4m" ..
	"UZ4x6ifkV5B8DHhwveKiqbj6FpTmYQHgeW0Dhk61XvqwBb/7mZ+FVeAEw535FGUgb8wWbqogT7AFR/w3tiOgsBNNNZbry8IOjQI6" ..
	"0xiZ6bfYNBmiNYQkggveitn2UD289kds5xmBnPHBoH4vgyV0TL7qBJzy6nChOc5LbGKI0+mI68TdfLUXKYF3atqpcj2wMMcYIFk0" ..
	"ZYQ8cR2XyERJbPJmrUSW+jA682wYJ4NlAHrtZwT3jcMdrMe3wFRlHmCGNWjHhnG4i/ggrfIcDPLAB03stkdTWvTFQKSMBxDVR2Wn" ..
	"BU1ULQUz7NWkk7Itym4HGWiiqNY4Bv7ecxngqKFau7/qyLQf8iDNmqPkQ2ox3WX6WEWjK3XS0b9n6CMbOJl4NlpfjZqdrPPhgvhm" ..
	"KLTIEyAqRhzsCfcI/eJ5gBveEbI9OJK5HDvWBjw+emTKpF5OhE9YiuyHTOQi1tpP1uxAl20BGeTG8oRe3nAvP54IdH0KiXvPqq3B" ..
	"LkknS3/dnGVozRQEQHUeGYehGauaRnNBsrEbOHUlChfWgFIqtM0l/1Uxeh1yqKIN6U9MNdAU324KZu2lUCRSm/u5+gnio7kKBy2Y" ..
	"L4CpdzmkrBGAgTC1z+SAOpUaDXL03j38MWHX2jD9xa2Eee/tsQiMliF7rddETzT8QUALZd9v/lj41+xBEf1ATXe2eneAVBfsLXQx" ..
	"3ZEw14YUGVs6a1Zm8dOJ/Z65wgS2B/1J2gAFkly/t29gWzq5yHWH5KEj1j7BdU4jgwP+Gw5N7MtMet/6PDZ8pizUSsyjpLn/jXpY" ..
	"ChNhF7Wu7UwWFG8WX+nRP5cHia+d12qSsqfhq+PHq/pxm8iHXCwwVNUdvLNCOdWf9KvYXxcn6eON6VhHAyPqMgQZumYsFApbWsDk" ..
	"CzG56l/Ju0GZ+1v3y9fKWBO26k/69nRrAUC0ErCpg8ehY4IPkwMPkxl1hSU1IGMMeieTUG9+0yfccur8VgFGdEKdy9JwGKWcxbZG" ..
	"uI10Xs8ouGOUP8wbeWpjsPRndeqHO/ZSjGrPaTAfrDLd2o/z3sCoDupPuRI2CZg5GKeX2cEf2vDfiX6ntr+w07oAloTVGLttN5St" ..
	"ARLVne52kV/mngJMPnLH7iT4W38RN1VvDYz4tyrKUkzw/+2iG/3rou2ZvPLrFHg6mLzOg6WGIvGgx7EeT3w/rABKrpOLZks7sI82" ..
	"T5Dgosov1ymPVasBZW/UD2b5+QFyBobjmfjjQhgqZwMFRdh/zgHlBq0oks9KLsT8Nxc6pXZP4r54aK5QrE6XuBkpFEedHUyYDIah" ..
	"ornzOL58AjVo3bBIgv0sWSG7pEPgX+9HTGtNY+TCZZHs4mBpzngfjy8+L2VpN3grc1jDYstiimYVY8tL8WLG37SfDPKVzQwzxkiV" ..
	"CQltP+f3GC2s84XITuvHjMOb2s8IjB1J6/qssGj3leeFIx7kPaR/mvcT8TdUOKrreVi1gEXy48ppPy1BZrSJEXiejboHrYm205hk" ..
	"ZJ2MbKgB50i1beCgxoeINKmVZ/XHAhS3Zr4HbwGb9ujimiEUMgjomiy41G4xS/tmj/tP7bLxcjRm/7zpXaeMPCT3iyIDjiVJTLrZ" ..
	"NDzErYEpFpqrKaTfGpGguoRfcazMCqtw/Ey0ENm1Bx7ohMN5T7Frxn0Hc5rhbMEkoFUHJB4saxx/GjAND+QIW+WmkMVJs7VIJPIC" ..
	"txmMZt/isZgEWtHDTNPWcPHSZaGekCh92gmqXwH90biqdtMlU+meLSMSw303YxRa//VpUnsyutNcvDsl2Xj6P8ft4+tRTtE6jfWT" ..
	"xpxRXp34SQ4Jl1k4NPB/l1MVZi/q+uWd3RsuSqRNJxL9/IDQuf+TsNfIYerWgsbp4wcITCPhgWFLX2qm8UbY4WAoty+wI6ram+i0" ..
	"bfrZXOByYAt/x9oQtuyNwdTDxxMh4Z+Fdv7VLRewAmFsnECgRJASEM47QH0D6qSyQ/shPpjViTJuCQ9muJLMBcHDka2MWPw+QQ75" ..
	"AMexC5lNOOK5hV0yhm54iG/+cNZDBHgiik5zQNuGExtjNk8uonzPr2GQP5YfABRtl61twA0RwGb9NQ/xcf7cwVMJhioLTtWuXY6V" ..
	"lAFC4U/SQQloqxtCjdhlsKS+ofQrWwDcEpMYNT8HUfxJ5PJNxRGaSmNhStQ5LHd5WiH3gFea/Rgh9gGfPMJJhNnfoQzQMRwMr8zK" ..
	"2RA73XUxPcxwGDy3SE/ZzlhlZDBhbUF6j+rVLNza8GLzVv1HFtVoicwuv4J2VLNcWlYGX11/NBK2/cQ9DMV60RQrwKWDKogzy4fC" ..
	"vdpIz/eyc3eX7BsUsDdDZLtUCMNUfe2W52/6QVxVv4zaavMd91hrUDefn1yqEimqQ03BxMBy1uuHWaWu9O49N18qqqCPX7qTXZMv" ..
	"EJ+qDwZyD65zTifJ2jFT9qft2O5n6uyJA+7dvWReUyDbAE52PQO9wUu1QpxpeyO1/LO+T1eSYOIf+9NPaG2+jJKFmYV9ASOWZ2J5" ..
	"4veObtHt1ck4TRHZXwTCj5Ywy22+DxGM9DEX2cJ5rJUECog6A30s8H6WEPgWwgtNKo9PqRNj5L9Qu6/Auhn9evHpTHuYBXTn+CTB" ..
	"o4VqXCS6nv/Dv1zkRHY07Ai66y0Q2nit8tuuiMotALr09b0MmQclj/8/pdGHNx6j0OaW6CBrz1EcPCaSu0BINuJdsiGTvZ2b8m3O" ..
	"Sj4q4jj4YqxS1y+CiP7qxM8XFDpGkWlf1+FtmebWwNobFtbeCIdfRKGdU0NIHy+e7jwczUQOtiW2TQQx3kpF9+E40y36SkcY0Q6a" ..
	"hyFLboChXY+ta97bLZCXCy0ZWLujnsnKXibkauTpaoLnbbkvqWMJHONomKjukELtET0yt7hxo+FS5ufeOm3MxUiLlFnL/JnzIIoE" ..
	"W3F0u7NmiHhBkGotPtuRIQ+uLcTpDjLEALX+4UAn2P87EmGpvy1/GgfFuS8B94yF00XHghEGW95h2ywptp6RR7uKrinoR71x7dif" ..
	""
local PAYLOAD_P6 =
	"3qPV/YMskOkA6EV0uVB/Wmx5S89AQZQqVP11wc4r/3Fze7UrNMAuk1wh6s6+OCosyQWuWLE9cUnVeicjT0j6dDjXek34IZCJcZt6" ..
	"klhXSF09dyQXA4M7t7AnC++YPIF0yMeHF3700LPCQns83RbVXAG85cO4cSF8WJsgJYeuQs2Al5Ie0dk2tVCh7q5TXXSsJwMHDgUr" ..
	"cnaTZTzbtGFaPsQM14uElsV9yHWtDTS5FQbCa51JPwN4qmz7rRzPC0pkx1xAVH/rN8TLzGcHmcxTt8WK7Ts6YX4XPsNMQ8nXqnOo" ..
	"LdE19CGVrOx3rFqCgF5pysiPyOpRgiZ293SfT1L8jAXY8M3fQ4E5nPq90U0bpf7NOQHWSDLmzCTrSXIcSO3z7y+AI2pzfZvEdiK9" ..
	"7kGKTGAPT5/wqunxDHHgS/CDApCDlwPUMoOX1sVtafWCSLTB8IZz4H+JkmXdc1ui8vESrNm6qHAecSPsovuBTt80n726Tq9Ainm+" ..
	"L3qFABJvCIslPCT05UcpbBEmF2zugo4YXGcKMn2FVV1vFZM4X++I3BbIrJ+1bOWsisj4f67NdfpEJOZEZb9TTyOA5e1GP85EvTzd" ..
	"7ilg70IyXSsA4tSzAlf+n5JUmRz/Ir8NAT9hBrLNpZx8HFTa5Ft8xmkRQBgaO06LX8EFnAc4294QfjRBkjpb0vZXSTh0u2/bNPiz" ..
	"WzqUexn9yc5hseDugCEx7islzJ+nNPdGsVzCZXrEY5sE8o5YpqdeY+0is7EIguc/GKy4ST+m5+KjzobC0OUngm6+imioGQJFEdTm" ..
	"oojahXAzeceWPvqie9ByFX8iuc/DqSjwMEy+1xHMmw3y3aHYYfWTp+pr1E5Cza2wkbMxnsEYSpNhBKmDJbedOpPUmBJod2614S4e" ..
	"DXrkh01um3ShbxJHPjughBBBurvbFJIbno9xDDsInZpKvsPQ5xWGrCYHkBE1ew7+Iqm27epawhgI6Et6A/bW9S1t/r0wM1PNIQ9r" ..
	"bjq7meJuAOV/o8DG4tRlS+F537H8xXWEnXyDfQqXkIrFi+BgfWBCX83EzZHD4KrHy/QyZmXF3VEaJrxWDIVnN3dnv4NGWjvdHSu6" ..
	"N2TMHpEeEAYb0n3KRJh1IpteubYgDIKIAVyJMdTIqpyxdSItBOxpsoq6KpJT+fC86chtijdgG/uvb3vyNDPfRmN+OnsBckbNsSOF" ..
	"6TUYJYlEg0s2M4AtRftwnqiElquAbn1gkoEvhALAZ1w06o8D0xSUVsKsk2dDpAMtql9t7X5BeMdThpC4Xd5weo4jniI1X/DIGuME" ..
	"TRyoP4O1hVH3b3gzriU+2Kei+3JWez7rvMP28GB30YFh+8r6lKgihyaxAuyDlpuU229jVmAaVdw6TF6U+EGkqswjESTlIz7ZISK7" ..
	"5edQz1EmKHGwof0YsdZMAcAAk9Z8nMDmmQlyUyAslxO46nZoD1Bn872u1iUUZpWTMR3YKdpympNwNum7jecBeE3LNZ8XuMGMcEIS" ..
	"YL9BmCcsq6HN/VdBvgardRlA6oxuW4dRd098mROfFlfmldTX5d7hxtYJ+BMRKW4OG1aAe4fvf14ZS8U42FaOPtAPXy9X9XxF+jTt" ..
	"3taRxNglncy+ZieedfVLZO4HBrzcd+D5v0tWamnsvz5cYHOdPQ5o/xlmsVJTDCgQQ0LSZDhm5qgzS421vMHPlKx3SXoF+L2RbphQ" ..
	"SbNjlIshAQk/SMRg8dsZBsxlwB+GAOZEWwfEUzpPJgxUJenQUdT0HfaHiXWLJRv61Gd+drQK7kQzCQOEuUKOANPUbuDnficnuyNg" ..
	"KUnhxQV0n72D+DnEqk9mjSV31L/DhOrxve1mctOc1nG2HhA3e0EPanD21OZHf5Lcz8QUBPfP72DLCogfsc/vwpsXP7ve+EM+GU8b" ..
	"r4A1ps34YROPH7OgUIoR51bdg1Kl0X9Fqs099NyQ9liOqDJZ7FqhuiOtAqVqYsAtmLaEqzH+Y749T6jmrb3boDR8WV8pW+v++79E" ..
	"q0hiKJnhzwyc9rLIapmkNSGo1g3olSEVoWZhnVTVFTY3DXXEhd7rB+2SCO3s6FtUKpHYT+uApo51DkY7FYbWGG+4Pq8IdGcoryut" ..
	"Ycg6HHDfcSPykB1bbqQHvBBTVGdVKvEjPtFLpiWXD99aeI2p8dgfZtXj3BwdWobGC4q+FHcnmDwKfeTr7bceXO4Pb81FOYEZWvpH" ..
	"sIwM6FgGvNwgrTs6ZCCe3mEEAc4YkzPBBWTF8jsdZz6Hme4AwkoteUGNLEa76JdLsuV6TaJ5MUAyU2BdngHm1PTpCWcoZwGY0+4K" ..
	"db9OVr1erM11Kj/iJs4ip1X1UkYIyafMOtKYXLHRZyp5xaw/G+5D45XD2W944Zj7lLGupKGR+1L591vqnm3E3Vl8ZIFJ9Huesqms" ..
	"A/76w8KbNEF7X1wvmNo9kFuO6h8pwH3SoiTG2kM7lew5L2jFGH+asmqcCnvyG9mKzgZ1Yq2QlmJDKhVD9gyQV1cucz4o1Ijl9njm" ..
	"2LPUuMI1ZPiE91imfqfWKfCCS8qzdoSyz7c10NF4KlkiVb7T/SXMITm8L8DwHwQsIzKeDNjlwJelNjVWwoOTLYp2CMwE0mgGVMce" ..
	"aTRsHyZ2V9hNljlCo8tTut5d1WjKJ1ZdRcyJjNBEmEYO2koV89Fso3vE++QOovwyOLNFV/Ffg2zLD83dxdqQzW6WaK66uS+Ck6OP" ..
	"BmLxjXqBaKEdS36SvqwSXGMuikDonzh5JevSaryCjOeuDVSDLJT3VWuaqalysRHM0xb9BZVBN/dn8Z/+2sDhOFjzYdfzVbcUCOWq" ..
	"xF3Hag1X+kjTY29kTbU1wVi60ILs/8GPJ6TY4+F1FvAekaxZXd9/Njmt85/6izD4ArSXL8i/3uCJmL8N6cycXH55sTf+9Za3blty" ..
	"3ROEXIQBa9ldJukmMpRuEtCs11EKcw4tlHU7AW66kpdBT25qaUyC6AuK+UNi4SIoBdjF8LdCIgSIvOsOITVuS8FkUYtM5q7kMRxC" ..
	"hXeiIq8mGXpacGujexbP1MDexOnKoRkU+AcBG46W12aC+bQPyqE5305ig+/fYqMZRqOlY4f4FD25f7P1/sJ/hvMrLZE9HY/oSn1q" ..
	"gyZ2xLpwddilfDs0V8y1bN5T9pOOeiU/ExHqJ7vZcPHt8hTXfjEixbco3XljEzIGaWz1u15KgCeiXFl6ZNfycIUCo0vSzdS39Ar7" ..
	"mn2/q3Xf+IbbO2yOu87kwJQJ8XtYNiYyz+WWeQjoc7TrKRwqfRQaHuSXqB024D12xoKDaljeGqwvqvETLktteIli9rQepWeznX+a" ..
	"KD7UZhe564e8Wq8MtYkf4MEHQS+ozGrPd731tvfUxwdVEmFVi/7yQ6fNjykNNXvX3Kd2A7N6U5M/0S9hCO+V7rEA5DRoDI84vf55" ..
	"yzweaLakdD9pQHs60leWhMhFneTOV2XyKWQqDjxlriky/zQWd/9AggcYzTJOzl/xKEVPIJnDwM/c4jFOfPkX0KGDbsuvcSQhZ1yJ" ..
	"p66UkA02wbD/4zrKWnOPTUOLpEeeIFmcP6Ft7HkvrXH/AXEc5qfn0k2eqi8DjyCIAy78lonWnidsI1Z1OMXi/wVWff68YTRxNKnU" ..
	"GcexHRLirKAiKhPud4AVGwJrZtvz8n3TxwcPVUwNBr44jm5QvmmICKpn+rXUDm0Q+Qkkubed/ltx6azgx0AJlW60/nAwANXsKOX3" ..
	"L167pd1RURV82jIyhpUlLqCscX3gfDW0I7C6tgq7Xs4zeJVXYEyWfte9YxI6A/Iy+If1iVqh/7UdTr8VABpt+T+83ZubcOrA5MPF" ..
	"uxwAjlnRrEkYGslz8jlWOsc6YXJNd4SEfkJ7JT5ZgI3R8YxJ3zNwfrHv2UMglPb/g53AD6G6KNK3cA5Pn4CzVk368N/rSI2ZSSs2" ..
	"itCWeMk9KoYQXQtb403Lk7y/ydkZ0jzgSZtWnHcbYZny307hAxQXy5Rs5CbS4h+1waZn2O5sEprF5zTGjfLBvcPBT18S3un9wb9X" ..
	"Hfd4xFkpSohh/Do/HORO79imuURIanJnl32ifP1tqDM3i3qdkXXudojyFEBCYsUQkIUzoZUxTIubD6PWeMiRRU0UZGcZTWsk5rNj" ..
	"p2yhEehn5H1wjzu675+NAz1xdSh2V/EIIo4/sQewAG4b3/7qeDoIRIGFy6o5z+o5jy7dC9/utODFgVfnDQzSA5nfZ2Mg2l+KVX9A" ..
	"/30qpJhpmppdpkpXVdpsDn/Tl9mzf+D9byypgfRDJp6+vdDWdcikd1YcAUNquS1bU8jYSy+4HlXjpg3IkG73rsiEtfWG8OF/P6EL" ..
	"bPQ6bX9Jef+7nMfFhCwLT4qOXLuxyRp5GB/wFQ9SMbPHiaeZ7XF8d+QzeAxtijw4UaolhKR723FLWrfQ0hwWWGZdG3pwavjzC5b5" ..
	"DDL0eGWmmsUwr+Tro8CavNqtHeHSYYhmRzUjOD3tdHyBio7cBzteah6PAvY8P+xlqjLSzbs7w1v4iOxWQSDUigZgCBaQXxrFU9sS" ..
	"W0hgqP4R1BhUVEfxw0AxC167ou2OWf7ZFZGaK8UMImP3DyueP8h6FUNlxM4WZLEnH0RLXCksjMg4SscPsP8uRzAa8JjMSBvUEkWS" ..
	"VTi3RRUWmrcC9AnZ+cAAvomeQekoiYKMhfLJy5pWxqg6DH+rlpihDP4MCPxYjQFjJ1EN/NTtzeyvpej0G/pLdAZuxFw6ylHjsIGn" ..
	"mwi1dBJ2TiRuYlnjm0TqkCjdHCPi6fec//jyRc8EJx0UQ7SYjKZtg2ZipS64gt08bRYzs/kypSbV61sUgKC85snGRvbopSFUnUYy" ..
	"nCtTLe8O2GffyxmzyVoYxNTY1tMzw5+V2FXAzFhFr/3Eg7Nd1GdGPQp7XLDy1Gnag5JEOvwQSL+OQ7srnvem38Lf18g96TyNyZ8K" ..
	"hN+3qRLlYiRUqaToPkwBqUzEYfTIsmnPet9GKfriWgXLN7Z+y3PO2pHdqZW/IBxTk3tqSODO35V87IuK+NNdkPYyBB4vO3smISia" ..
	"ZZj0Ufo5WggHiO8G/bzi3add2K3UPk+Fui+e4G5RcT8vwKYL8F+13pqNS7Ahk+zDCgXM4VL9cVFG8dby7EbjO9EGi8lzyzb4cKzJ" ..
	"VHaAtRPu8m87GdmFfqsJXSNpf4zbsovra7IiTWzFxKVi776Qv4/AHxv+ALNyYM/QfC984+Eniy8hPhtQmV181Ai0YcOgaq/Nrygy" ..
	"Yy7EkVTEQwQzlauzn7N3YRvK9NZxccZ0NsKaldFYWBnzj7WzjUXsddlUKPwdgfwjs9UOBnywS+2qWtngKOLAM42ezH5peIUxn8uP" ..
	"cWb/nfBhAC7cu5XGxM/Fx7uZw1cA5GDoGUgn7uDd234fwENMRMI4PZRPRbB3F++V0YhVYWOp4o69HuNu8Y9GZ/uDWLvOBG8Rl7e5" ..
	"El+u42ohZ/I8Y7kB7LJHCQnlgA55eW/ezvEUjGgeOTJzl8zlGtxOOHLG3F/ac6dWAsJIOco7fDRx//2cSSlHo2hLP6qyz/dOlaMG" ..
	"P+JSCyQ3hztpk3lFU8YoldL4asllgXaAX8vNgZad0/rLjXs/pnaE/m3Mp0YRrPGnHT/8PvTQCcV+ykuzHtG750+DkOxoxL8f2/yn" ..
	"SkAvdzJ725DymgBTBMOdf6VuFPCAiZHrBxKA7CuFVUrQlGeswI2EdRxda5iAGFynkWA9WLvFyPn4RlYxNc8AcuwIX9Ny3vFqGn46" ..
	"NPeAcFVjg0dDyy9VfI9mLoMF4MzaRgT7nA2DAvdyZbbmrWcYopS3UObezIAtmd/+Zdf8Vi0sZx4da7cGZmv5jgM8JoFpBHW44Bs7" ..
	"eYeKbBvAFbxNh+66DWBmEvoUKqhRoLo4ZvyTuj3N5XOkj3aRoUw95q4mIyXDAnDXBb4nUOvGjPXBc1NQTNzpDlk6bFinZ2171LXO" ..
	"U1QHijj++3YWbRSk/3Xz7cYJTlcYnbuYBp3oepQFbiRbc+PTBZqcWnZo6Ei3r70bDir/hvUff9IXfPwMGNxjQ59zJq6gf79KUE7W" ..
	""
local PAYLOAD_P7 =
	"btaqBBlaELyWi0ExGkqypXAh4sJLgSBlUkcQaR9iycRB5ahkr2E7i0Aj1UVOof/stCosR/v5dVOb+W6LbYPHongJmyPUbhnpDB+7" ..
	"/HYq9f96VR8Uq0Js8hXwt7sasaVAJS96gYzS1k9UM6ybDnDHMVCXyzCrqB4fzzsLWVxuC/lgXICH07JqLmhThSOCW5bJmWSapHY4" ..
	"RYmeyig6GkRLcj7tV7ehGoWqJuLgn4lbbsarHuLIL5lyyc8CoPeu17RWBmSIxkTi+YBYdig78zDCOWTJBJ2OPECvqBMJdjBSF30z" ..
	"T4cw6oPROqtbacWx/ney5eFSnRFrBap6fZXjkDbdKYQ96i6VvbrRC4gSIVxSmAOZG+y3W09GOnZa6NZ79euqrK8bOTUkTVWuDu1K" ..
	"xjAXnzmeeOyWHb18wT9L1pOTHjLgCukBCJDIM/EWiZVWBB4cpD/K3pPKsBCIw1+tcZBObn+r6ZlK19VT7eo31+OoKwvINB4HpEjr" ..
	"4rB/bQHIZ/SO9izt3DMYiJxJ5JJME8OkyiBBqm4GX1ra13xOvg+FuAkrWVWUuM/7RgUQrxlxiW5mZrut8nw17qi+GnEwGd4hv1EF" ..
	"NwZix93MIzHgoPZqlUuoq/gmZYhfpwAPj1AOCfwnkKKn0iLU9lcBOuCP+CEcZ0dXETHvwpKCajal7isVbW4LznEQX3b4NlKaUJWS" ..
	"rdEmPpaOQlRAgNccZxV/AFJDOdv9ACgKW8R7Zu8EqEFDNCQCCFkPRjTF6X+vxF7LLCk4y3aAhZ68ZlDXd3LIWB/YEhKsWBOE8TLf" ..
	"zZF2EW1iVbXNfqZ7q+Oav79Q9U6Uvz30kjpj/EQPdp0ad8ErNgzAZwnluxyrdfwBjSIZXnCN34zd56lpC2gT9l4XjSw1aatfzQXh" ..
	"znW5Utvar29UDkX5gJ3/gH27sh+583SdRVJvV/XG6KEkKSQRg/JTwCRNLWP1YNu27v8hY5aiaOvOs17jL79btvj9aup26Pijf9oP" ..
	"w3eYIf9DnUfTuz6belQci8GtGfBztyxygiQFvLQ9qUrA+rqA7nDWYOGWGvp+Lz59ahSzh7l/nthCreAq+xNjPXCTtlg3wKo1S8+P" ..
	"mZbc5j/S5TrmKZg9ytP+WNzbWrdGcaShH9+ygtdCb3Ck78qbA+QIhVihf8G6bbJEguZNIml2MxR2xJb82B1Hz5GgoGtvshkNhHQ0" ..
	"5CvLRifJZg5DkvJNaZwe4FoMKPGz1QxHBhvYu9f2lrdvF0RlrxXFKBnkl0T8YLQJcAC/8EMNKgCsHyYd+TA6RQ/dg/K4OrPFtQJB" ..
	"8c+9MjYrJTYgv5xkdiuHkNZctZZFBvp30dwtFLv2N74LztT5uVEjUd9sQM3nhKrKTyz0lGOhMkzzHaASUeQQMLTjxr9HssRsZ7KQ" ..
	"H9fZZCBHbteX/5mmpKwXH5lY3XSS7dICjEA5x+JDFx0lIqyCTFXBdivnx9Qy10BDWZS7u9ED+GVLMk8NbKcE2Sm1JiCyVj4/4pVM" ..
	"zHfuZIZQv5xvMPxIPHZqmv02zd230n8KFGYNC2f+hHnNSLrSskEJqqNFpFeZM91Yl0O/hRv1Sed/bdbTDDu8m+ouYMZDIKGhiu5o" ..
	"NWOnkQ1wZDlmF0d6/cLGvzNIqvE+ao4rBCTcmcZabH4LN8MUUnUY0YqjvjwJQrYXHQbovquSdvazhCtlSSPd+m8CXgSsLJ9oNPcT" ..
	"U2nnCVstKQZyy86Z0JPzRKCv6rOhQ6wFPZDBiohQ3pEkEJ5GRObGqekqKUwWdvYJzyakNY/IE8//Vr3cr0kKqY6UZMVLEvnzdym9" ..
	"zvanAt4XYHwIji2qKlsyugmr791Phynre8UhzL2YuWNcP0kq+9HSazaYu5AUx9WQge3nGjZ1zs7kXUIZrEYxHGi7239vD622iGJg" ..
	"NGw1enYU5xEBMXFoYZncGaxKefTvBzX2+q1n5OV7Bs+6HGd8ShgnKtGRaTSd3pemBhQSEKVMpPnIS0sI9sx+Nwlv8TsxPlfkvJO3" ..
	"BLJcdq28mTSpEfakeVjES56S1UJ5bfWkjG4V5e2H2KU8lyHwd3NJmQ+oLwgeTYHRFTQF8kO3iOy8t1HD/jRCodIoH2Z5a3iVJCZc" ..
	"YnlwkVzVniVz050bUEsuHO45tbGz2Fo4tOJB7SYN+dx2Uxd2FNs+hyuSC0LwCTL/kR74axTSILG4D7ylxSl+KXfiwkQSAqztFhRq" ..
	"bFgGe4GPbkPtWV9FRjsLVE1Lk28tkIn4Suj0DTKSBrIB0i1OXZ9PLR9ZoEwol3Somnms54dHdFmeC+TtiwXd7Sz3v/mbw9oDuJ41" ..
	"wn05NMAn8C9TFvbz5U4bbsIsgj4Bh1yOEnBD54MUjx1qeQF4+A3zLPzjgaTbyXPj4edddo4aS8nV0AlO0DrfoZYdISlu3vOf+HO2" ..
	"JRjptwbQafMpmeAPYAiPTgpSYtBwBz4R1olzWO7lGCKtpnzpUuk3eyQEfGrzQV/QMqDfsLODW37HeF34fwGji5wOI/FtfxaaAebY" ..
	"0NXpGBfMSlhQCYLtzFQcKTt9IBJX7aaPHVENY8ZQP5/gMccE4VqLLI1p7WGxLskqwJDYiylrinIeVPHr1c1/qS1M7TiaaBvM0GNa" ..
	"0RQskZyPhWJWuGX1wgsv45sPlmO6iNlpfYftcng2nISrYpZpzT2yWyRPlEsWWjrly2m7ZhpUNFfWjmS/n9LXInOKo9rPZTt2ssXF" ..
	"pnl5dVN9NvffFbIlg2zff/kHdjSBGKlcoL0XVshtIY3riBc+V69lKO9EIvYU1Rj9fsV4g/CYLjVP+Nm2S7k26k+fYMImCHjMXG30" ..
	"9zTM2NRyBExu1tdyotOWbRXb7KYaen0D0Hl2bjTieFQb6oBvH+EwLftqDXksEQM0tOd39kziGO4resIzZrDW18N/yaK8RaGbsTir" ..
	"VWXuNrxB9cBg1CaZFad4NjGIK61NaXHSXFOvPdJPu0lzXozCf1e9EH/k7JVdyTeSqWZIEYjzGudaIDrErGH8HqiFDfs/j0r0KCvb" ..
	"5bl5HFoUGPA9rAoBy+O1UIqAwvq1zHR2Et5EF4xrL0yDQI1RrX4G1ARceYzysAqnNhefIAEBFVL3JQmfiqm9kQa4qdZvvvyFg1Q6" ..
	"34cM9yb2FBntLefPBO6T9014wbgE8c8mFDqp+w0zQT+QGTcbWyBzpON69cuYhUWkpG4Fss6KwM6yKPgq0ysriogZamPi4uVKn+kv" ..
	"aORjwre+yKNuQM2z3RV7hW8apCv/N8Rf7tDIRkX3Drch4LpYEM6B8xHn1nMXKNXDDsh2QWlKSepLSlSnTbG0Z9Vm9rkrriszkUku" ..
	"ChIlCy95MBKtpWNz6qAM/ZkAS0Fu/ySCYNk3gfszJrrY3Sw5VwYIEdPk3WlYeaUzGfXxLQn/nbC+uHLwL+lmk0/QmeG62qq2JWkv" ..
	"NDLo7coFaOmNfm3UVZpJZHezVQUq6UeMCRr2l8KbIp5BBzZ8W+FLXKvqcRn0VlojA4ZRyYY/kWc7wSnoqrqsPReo2K7ckTJviJBN" ..
	"f4TzRx4S5a9mih9EuMjd8R+CkR4EFqL5PypNLZv/m2M2nCIbOtsrG2yh5nK0p+EQNtnEpKrS5i5BJiJRAqJ9+L+W1qNK7PTkIr1y" ..
	"3tX8UA19h5VxO7BasPlZU0HUvue5T3eEfO8sxOlYirEuN8iWD11mpbzgkCiV2kSzv9wiXlvlUeI4dRLskMWA2hDtaSsbhKAMYZMR" ..
	"YCUhovW62zAHJUuAhn3MlujjPc5EDomKA/wmIWYF9wmDo08PUDoOxbPEpWQO95KS1XDa7hceOLFUeAGYmiDjVxmJYJ+Eq+54Ty2G" ..
	"kiBB3mPyw/DRWl4D4vrNd8U07ap9xV4ga00uAYEqP/TD0Kp/MfAzxPnPTg4sDNdu7ytyiqIbg/Zg8iV2r2mh9Ywyh3Z86ciXSz1f" ..
	"VOz5k96mLlP424DWtquntub68tuN9/egGJegZWkYfcV+gDSk+5DJGo+J6Cov4SXQYhRM2oGvg3WI7kxgWoogACidwR1vQcoI6c47" ..
	"0oCRbxI54JpJgXc2IbibXuxQwjpzC26AyXkLAXBJoVNIZYQidXViQOPv7OD7daioPYGosPOKeRCZuqecw1mA2B2ySCb4K9pq5eWq" ..
	"1if4t6qszXnpACpmguMmi/Kpfxm/C/NxAQZ6ycQ/Z8HEfFTC0fVmzZSzMpxCoGlBfysO7xsrrJZP4RU7NxEI5qy3mgBSV0Z0SSeF" ..
	"ApGv762kQwwGiI24UAaLzP1EKGXLhsXFYbu1wJ2b9L6K04xpUT2WrFISUZ0wXLe78i2VdV7Nx8WUBa+aUa7tSyy3WNzBTKDWdGKM" ..
	"T8lTsRwdsgQtkm85rr05eGPxFcz0J1bm3IDz2JU1FKb11WwV9O+5Vpa1M8qMbJwFTsjv4SxxKH8T+MhXLNax+mu249PeClsIr5V5" ..
	"ZzwfnOputAwVycVMOaILMqDWkMLOkXnLDdgcLUBgh2eib263fG3pe95cjpRaIXwVU509GyYkpyt6UCan6D5FReEHSrR4LRXjhQyO" ..
	"LlNktwp/2X2K1e/ziDE7O7I33N3qdW6WdqSRW2nEdSfxoiEmolc396DwxXxCu7JTfzPLbDTu+X+HNwpSlvItL7Fx5ajmgQFF5pA7" ..
	"3VbwCfqjuzDuTL+0PVt70PZYIFRlYP8Nx/bnZFqSJuOrW+4RjCvJuc45exs+PCFuNnv7Hl0rtx2ayufwp4SyoI7h8quCIobe04/w" ..
	"jwUNnUcMitoYLfaqgQ9BpxA8uILwoWfkwTSOIWejCEvXvfi+X05PGJE4L+XIGucmk5vDBjfxEXdvmpko1g52nIJaFr6AQgW/JvQr" ..
	"6F79mTfmVLB+SO0ZjmgrirXJiezQlDES7/BMP+RLMi6uP1D3ZZZpFpd5VIBJxCmITAi22jvMXkWBWRV8wSory71vcRaqd9l9CDA/" ..
	"P3/2gL8Tbj26WYDrY7rzJGYNYWVMC8/zgr2rQKm1yrdZpj/9QEH2slX65gI5JRUoxttqfHskKw4NDHGZFhbT3FPOV95nE9cHIm7Z" ..
	"BdP5mzWhFEcrwVo74jvybJBwep646D29RXcefUBGpHrkuwho7OF6WmfwiqzRWerogBw6BZ+q7NhnV04zKf7HDU6RfW7ib+WXMMV+" ..
	"A8nT/1PIiT9/5ilewL0aeLgGUOuclEIPAkUNUvEoitLayISpq9RmGKHujKZtNJjicx+6t13cfRi7P4lt6KHdU6ZowI1YQhkOnF9S" ..
	"VnORUHfTAiA9mE4iq6Czhl8n96IAC1vgCFK2kpjSs4eNn5MmHs23cja7dnX12hgksM1gLHZgZPMQDtNcMICIlUFcBAhN3CyILhWH" ..
	"P0wjkT4OVJp1p4TdcWpPURbdrIYEoxKZJ5rf7OnwAdaquBpUqGC/wObwlyxATD0UbQ4OcJal75f4VUIG56cBVOu0WIzDrVsOYCes" ..
	"WKr6WbxlpP7zMNa9Y3sKoEV8eFfevm/QPXl9n/g6EWcRLyoWSUzHPEfWHxBfQuSL4Jz1V48RJsxCKpxe+cOTTltywWA188X7qgoy" ..
	"qwK9PzQXYWU1qJAiIZvrR/77wrgF0Le/0l3WZ4fEzmGfJsfeZ2k60/w+ym07yauZ1ji21AY+lrelbuj6zAyZdYPkWc/2bIUy7Eje" ..
	"eg5QY/dVJkpdJOfut8kH5MGZ2+zDN91GpldRljCRX/PG51wNkvrz/C2SnHLWqJQiDj6aHxg+oro5FccZaaH+y7P0JN5fmVFtrDkw" ..
	"/3J5oacsX8mllqPQaP4D7OE4d3O87uEWKroKVt2aozbO+hDxH15G44vEbYvoA3LME00Tq04OMmJr6t0IouqMLhN3hrtaZi4cpgG4" ..
	"HntPH71389ai2QGupGo+fxjIhpjVggnEXoRdqlsdR02er77+KtbeNYtUy9lL4robft+Oi5r/AuewNBkxP/J/9Hwmh5NZjnHmQsUs" ..
	"RtZ/t+PceORMZpB2zRGw8K/58hcYXGhuDXjNNG+5wtXGHE26NxQoLU4+K2YWYUhm/YWQM1l2p3bGTT5j8c3CCcGjKcHyMJo1D/X4" ..
	""
local PAYLOAD_P8 =
	"MoXITWHUCrREttxg8231749JT1FRK195htMlMURU3kyG7jLf/QIrWSQcxs4732eJJ/2zzKpi2fkCGsrJjNDT8jWdAkOdGauX3BCj" ..
	"JO59ZtbsUSS1WYmeQQ/6PcRXb2MZXKQZ9jqlcR3GlQFP+vO7z1RU2M2tK9dLqRpwJHtTsJybK1/3HsLGND6IPy7iP5J3BTAR/tEK" ..
	"YcLxt8rsak30Ub+V6B4ynMIc42thYTKktY+7or+9ksb4gXXU0c4K9+fvZMapXjC9fc9InvNsNLDyAzozM/uhqiMpJJifFW+Ymfhr" ..
	"Rjm98A8D3xVUMDLJNY2K/SatLtOX92Xzxvfzp+OC/5zLAPNJdieFjwxpPS7BXmSJU6/DYj2EjODswxmbPDNnjl/j74BzNx8szMof" ..
	"ikuV11BvsOJdRovpZ4H/Jf2jmM1SqRNu6jD2VPcv6EmFAU7VXYEdjxeBChO3kGy+bcdhL7z3a3hrp60a92ZcAjMGnGO+aFQkdDgq" ..
	"85+wiGPTFcU0iCXpQ/xbpdFW+NihnFzp3Oh02ATUOR/8ScLXqMnhjiOpe42BmTVRWqS93y2dhHqbTlGZ88Kc+uffSVqXkJC6s5bL" ..
	"ja3p4PITdt9oRdYiyV8hAo6jjYIM3j9Io0UrS6E/cZTa+dtGGDTivij/ZEQ6aKmHOdNVJldSA9HUeAYn4zXhyle/swNr4lSwaVxf" ..
	"GbilLdrx7lnZkUAR7ifzi72HUx20E3cLHRQGtcF59F1qQZpX5rCblMDnNFyRfQARlefaw6aqYICOOdbMorRzsYwdBFsQTCXa8xz2" ..
	"my/QKwtsn9Un+qR+VJgyxY7LMGpIma69jtRFi7bq01IJD1ov3A6Qr5FAQdAAgYtP/1rsegrbA+d0H3LZ/gIvk1o4uNK5wiN1s1Bx" ..
	"2z77BTsHOsPBZcYyFWPmP6S1iks+lprAx0YgteqzWYfEVcdLaFc0+zBDHi+ZifOKDK/VodcFKPBJIUFiNKUYRMAor7tAkeTI+DgW" ..
	"EYpvo91kX5ajOfkF4p0+7BvokG2UqrbSvjwDr19blbU0f9EX/rx+tuBcn8yfCNkaRFyOFLk2P/G4X0eBMT/YR9NK8GBCxNL8g7qL" ..
	"u+aaIE3kYTdObQjGNTxlXlxaH33+rl8SPFWLv01PZGzSLOcoMGTWCJ6GsWcBdjgQ3pfJSZqABq6C6aPcs8CkX2sBz1ZbRzZeMVw6" ..
	"8CYZJql5lVplhgfzIV+hjiGaBKp98VWpKkPXIX9an06fRm7HsQcUQXy301Q/07z/ItNFGkbs2xNNQdfG0QmzCdZVwQ86kBxb5Zq8" ..
	"qc6zVb1ppv1L91Cw0jQ/Izd/4T5VRLHh5qSAUhuO0U46HjBpeyB2wa/rbpzxJBzouh/roNl/2BM/uig//EizxoXXJa4bpwb3ULFL" ..
	"hwjnct4VbTguljGeVkzjOFHtoUQCB5LSRtH01sVfWeCdA/L1vVIPvCwUUrbhXpsPKGlcmXwWFj+CxBktCXsFncJPp7dI7cPNb645" ..
	"MY8KsAunMmQjcwQWyYFq7nBBlcp1WCffl0LBnx0QSXLKQX/yuPNSaecUrUecWcENagHxNDTPLFHbVr3XrggMW+rLCXVhPCtA/unl" ..
	"i/e9XhElFNKXoj7TcQobWn6XaSxgsBPKXimG+JB5CHo8qQNEHf6gfH1nB+IciHSlZAgBlGdZL7fezzWYmcWFgLwbSblcRH3qYr3e" ..
	"PUYwhEtrR8QD9q3pgBOA9kVlllv1lcLo7Ar5oex02wjuWodfDXN/elC/R/2LBv3gXzDWquC1l6qCsIGMAu3aW1wPzBljSrQudKhQ" ..
	"AuAGmREs2zpCfwIFzIfXbQiS4EKY1sRhHRjElpIqEOwOhiF46qaWx4HNI+npAp6vyjH+GnbeTmd9m4Qnsdgki3ioTTcO3nQIN1EX" ..
	"UfmrRSKay1eraRea+S9jQE/uOSHz6OVclrHBSBs8s4f7eaLvpjSwuKZT8z8LjkJ1qpXqWZamZIE6Jhb5hnV+cDDyDCqEfIGTBGoy" ..
	"xlWvWbJr+AZ4uIvg33uiDxoRMnxKpdVbCL2VPr+rmDpTQF9lHpPdJksZO8dvjHaWubePVQyspoJUjo2vWZO7/mfFfNTd2MMacujf" ..
	"1Q2YvHBlj6+YLym/fUDl8mfxH0hYnq8EyAJMBSknfrXrRqLHw+pWvoHQsDizoBAvKpt7uzHvs+eM3m3ZvZtOFcaHz1iMAnk8Rzyz" ..
	"yEFNAKasj448blba51VVrxXCWfi1PWZFFuQz3WuJF1zHvXSO1LhjyUv2nnLcbZsJgIzatSIXFh4n5ehI7J3RjjOx1nVjOSdZsFhe" ..
	"nw3qiUA8OTYJKUUfvFP9xKyly3AQltpOncutJcAoj39nx6eKkeR4iD4op7BPoIg8zjb6zLln+Jf+3KImVYWVzWUru2Gza8+nC1A1" ..
	"64VPGIjaddtaJhS9rBsUIhQemNDJorfuLCyPQc37vUza9T5paOyr+egmBMIibCO6b9Y1lbbhGMCArZkQuuOxvMIzsLilIUQFgPbd" ..
	"AGklANs2SFQXv8BGVh+XeXtz2vD/nzpJBCk8M17ec8pYtaM4iIA28kzhKrGqBArYkCGYXg8bI86Qqj0DjU5YVLemDRIbFl21mUQ0" ..
	"Pz3KvS3YvkEHu4j+TUMT+AFK8stSCxkLcdcekYXh9deN3NULyvO+7nUCQZAeftMarpWnglp50RHXbQweeILo/RsSWNIcuwpbXFgT" ..
	"ulJqWzNRKBF25ztF188ndk0qv77j7tjsPlfp4+ZvSCxt7of1fe1tbshrzpdOgGII3pGfERKGJ8dJl/HAfKxmRe+tn7cVoNhom/fo" ..
	"J6eLRhUxEqRfMf0vkxoGui5txMwagR5aGJHpo6t7RutIlSV0Rb0UcSmea03RbZJX+RuFRF0pvbBXQ1rW0w1hN8N0288GXjhCjtPZ" ..
	"U4FyY+AZBp2T/xAnBruCUlqMffSJim+0AO0Wj7TTyyiS+lOlYYGaFD1nukOovXcAlEl0D6mcx2X9/zNwQQRLNWDXJDkaQ73D1YC2" ..
	"CmJXM31oNSntc2YKStvN5i8roljBeO0SaDJTGRW0sdohWeqgjqA6fXYmuCJoykgS69tTveMgi63TDTwkJ1lApbfByT+qCWG4txaX" ..
	"OjJum6obWiagZRFrrYouvhaH5B200eZIgEOldmwByGdPux+Vzl/cEtmaTqBYmcQyXBmXlej46hcjpQmD67SDUIE9DWC5UKFSvVFq" ..
	"mmirpJhqnvc+ZUPp5iOOW/1PiE7xLbGbdkS8wkF/0RTMn1tBc3M33oWg9feAtYrkfPXX/fN+a6Ef28JxT046oxKQBS8EHdvfEeIr" ..
	"JZ8wxzgNrIk5ZAwKsjcuThmgCKyhg1a//QEG1n5y2y7nDRBuc74ewIMQh7Fx/6wkYQ+QWw1piGkWYKZHqt1bjPJixl1Zo7RKjTA5" ..
	"Bb+Vk0FZT6PfVyOd9f394r7TF990nt7dB5i5byZ2Ox8JlGGiArWNQladcVVEQA9CD2EgSgPj8ful1ItXaTXIupZpLnkV0EXRdVT0" ..
	"n2aJlxeyjMvGqWAEBuskSCfPvSyRWmIrwW4XoILVnXyNLEQBDbrH6NhUEjMV6E9eZoXMNfFX+vuxhvZG5PQP9LLk4gO8tThORSFO" ..
	"TLvM9XAEgNV+SA3D4KAu/y67b7VdZYIUQEtUHpwHQ8UkhvJi0pXRSrlvphGx6h8teDU6SAda5+vHR9Pu9w3vTf26ZnkK6io7YkjS" ..
	"MHnKE0EDQfLDWeVNFPgY4kB7rmdUNosyiCgsiUtvej0f0ePHqQjZz84GnkWz7c099EtAY8KztEj+0IEc9rzqtGO3VGyUeNHBhfFa" ..
	"3ugXKtpj6ZPnstZwDydMooL4WbZgjUKoXFtLQn5UeO7H9/MpgIxDY5D3svrldGmY0VX4e5TXMngwN3tN6tuKQZnrWIuMaVCM/Y3n" ..
	"9DnbKwr4ttM2s2ZBxEpo4xNyLPOut9r+Bugg9s4mhOYMh8rpWEcnESypmr9vDWzUT/g6+SgGT0eCGAkve0SCG3j/wKyYnhACJEZ/" ..
	"GKQ0cvHFZiv8TOhT8bqUBYZCk0tMDdD+wDErlFAiL0+PehXPaHU1LrF9uBH06w2SK1zYSz7ZQxIEuYhfeYp/xQoFUA06xl8eVkdQ" ..
	"ZmFTP6q/0FB+sZpvQDEnLUQLRcjxXx0inb9KrinnXZM2vir664XwAE6jw08ZFdeXSPFlATYM1sqt5OLSF5ROa9vvUgS9owhelTm7" ..
	"i+xz16nf+wlF4REaqLDcRAT2jIumvZ53qFTzk4FibrE8RHzgHSnq+EkI0ePdmTtHv+UZV9peDjK0Xe2uZ0DY7f4cAvWoNX1pxl11" ..
	"vF+yWefaPeU7DpBm7S961cQ4lEe4AiD/KJ6astikSRcFE0Fn+dfmMnPwbo/jOgaNV4ymiWNq5+tptNaZ0JxOcH1chRhZ+4/3eyPf" ..
	"Dsr8eppkeuKhCmSeUMsFGJZnojZSGD3gBCUpkuD56uqMXL0hMyQf4IhjEE4dilsnEGlORFRlMTnc6JogzZ2/rdX0K6/P6I9Lj/9L" ..
	"zyIMM/OLid3V1kOa/GIfxsUqCJ5AHMR+srzLSzsb0w7EsfMpvMZZADyzi96yJKbcP9j/MGBkWRbKOYOtjScheXxyksd1rfZC6qtF" ..
	"NEC4T2HMQki2/fhgVkyltBCKmLlP+2xCdFaewiGQ5jqepMx7E1lEoFXsq5Z5Xvb23VujRp8RB8ZR+yaeYE3yUiDjgwo5gcYEHmsn" ..
	"rNIzg0UQbe3NDSYUQEoCmvnzYJlJ9e2yAzx/U62IHQ/XXUHxMv/2DHbt5n3x5TOTiAcd+M0gbek7JD8KCWO6uwefHaVtQNNU8/0+" ..
	"hk/3qwffDdZAJPZUs1FavOyT/92YedzK8RZO2DxqfvCm2N1L4WuysOwW/G23cbBv1m9iIah09a1jqiqAoy5MSeNp0U+kTmb8sX4A" ..
	"j/pTj75uMv3JIGx67tfv9VkIYVtu0BGBE0GsJkyB6LtOPvNCSPmNUbak32Bxcb+XWxwPE80//bEw6/AQoR4OrrY2pB5fvxVtyMw8" ..
	"H/DmgL3GMyfNFiIiWrWzfnaRMZ75vZgmsVH5G7dhtt7z8tVsMcsUAl4LmNVKjttlIDh6pEzZfHJuSZBwlh6MliUoWqcEvhlZ79+d" ..
	"7Gr6flL31WJ02lW0lPvJhzcLiuCNtl+gQnwisiin6RV4gztvR6KmweI5wHFnGScZr0l3/MwR5gf4Qk5XpiAZxDiftd8xLXiVfBkN" ..
	"L1E2ykoyZzOCllbliWhptqzcfFUgZy7XUhKxLJoB/a5qFSSqk3P3DK3FHuBXcXG6VnuUYVf/3s6xlqZ06mT5sD1TZSQUKldTQq5L" ..
	"6axe0ML5+avtjk5bOxMXA8iNMINtBt1TCbn4mFZUEEPnxpEaLrRWqlJ2LlB6rikYyP+yxDFImt+ZfNaVxIfy7pT9dO/7eALtyKSF" ..
	"XRERbYOgM8pvN6CNwM8Jv/VrlKr6x+1DhLJNaGEhyEYbYCRqOwSVkYokLGH8H86ylWhwqrizh8X/Um539Spqm10Ah6k29xGfoCXa" ..
	"pePMJjHF8EJpUvt7PxJrhFcvrq8eHD8NOrHYnM54rQSH8kSBB2fpIQ5BKuglHyqZLW8qqdRTHp82FqnikmznSZJ+PYxGx1qGSRM9" ..
	"LCDQl1Tb8a17yQDj+vv2knNIt2fD1Oqlxzo2irilhqbQKl/rcp5qlGqOXakPwHaG1Yjq+QMtvXxIXQ7u/vlDpWVv084tJFgX/wQv" ..
	"/CCzhimHGPADPKaRrE8D5T9NUpEykxmMnmIxVarlGhgOhJvb3X3om3is8HitxwS717sJ8+pDGTHDMLpjyTokApX/HNNgyND/6Ih+" ..
	"0Mgq9cA3dyGb6DDNBfQDi9Y6VLrsLLT3XWdOldndUcSuP1qSuMzwNDxO2gmpGfOdRkfmRJC1Au5QdLa5CvIMOVVDHIghpJ/hKhqU" ..
	"ia89N4Jtz9IzlKOj0P4oGD+eGnOhpYxYs09d+dQjwBRic4HnSyB0/2bSqulnNSbbJ7gh+c35NMJgWVNLVFPj1WxS4xw/DBMWSnYh" ..
	""
local PAYLOAD_P9 =
	"24A0UA6lL3kxDnUZifozGQaAvd0NIJwe0Unvkqzz9dIbFdiP4btVYCqwhmvBW8EqotwJ7iI8z9zV8JSWh10eFy90DeeoDzysTV/O" ..
	"Lv5qe4qKgMbzku7bpEM/KU3kQiHsJJ72XoAG8sNIPPJhnH50t3NOzak5d+Q68849DLNnCulQDikapJdCVjdvKKa2J2fkJRvgDH3q" ..
	"4vlNRC3FDvrCTRbF9KKESidvKRboR4habTWZwucC7sCExI0zAhQFZLNYzMJuEVXjwGkpgHHla9eWykU9wO0L9nFnb8Vc0zbjpzXO" ..
	"YbLjxv/7D+UDqqc9XeXlAoQHEoZ2xYzLPQambmkdKnnoRpOGrWv9gAFg1MLLPcoe9cYPMGOfSSTZoh0UwyzE9qdPVC0/+Aosdohk" ..
	"LUmKWr4N2XzL+TbVt2mLsUTbDWXnLiZr156zof+aFKpnTXYruf4nln05QvZi45eTffEUmMbxZJUlYI6ijQizGpr7XOeMGpKnM1Ac" ..
	"rLEOfemDl1S06kokTW8yw2hD54GqRIvaQFRJIC8M+ZQyqHjMoZn/ZyRLm2n5R9NUqZzrsvycwwVhooE1HyRo9KGc7CwwlD6VnACH" ..
	"lmr1Hif2I76UbW3DjZEWrHlsmfvt9OvUI5iImj2LAopZ5n8lsy8Y/co3ygAPPN+SrhmVVu5fXDaYb1CMb/nZDzbvreA6h1w1QCA3" ..
	"7INoJqJxp27fjb0UMtDMEXaGHf8Dqt98byhrKybHP4/oqYzXmBJbgaCM0FTwxcx3D4tkU6al/PvlnGiMHLgySycST2duz8zvlG/e" ..
	"nlNBdcTVo07ZI0Ml9jbV4dQSldy55DSBoW4itIjPoziD+//RvU6VQHHgFtqTR8c6r2Xg2p1JxecAa1BUkR1Wre1GxeFJzlndwUtF" ..
	"DrWaf/jRzX/0jrBDAccsvhYMTM0VPtpwvGYXQ4BSlvYoKxg1nfT86UtrkUtjdTQ0vlanfr2L+N/Ex0G5F++tyyT32GZ6c9L4k1AN" ..
	"iaVRDFHvAihwGmX2NcChiXnAnyGFlTbexaLTsul3Zyeuy+caAy5D4sLXLcJ9Lcdt4vMvKXOS6Pn2KkXHYDjMb8HzBT0n4BZ4WIpA" ..
	"ZdSCIO7FF5MJBHyC+TozicZHHywXBK3Nmjd0j/EMawOri+AoA6TmHBSmdv0fIpG2uIxWkk2GyV7n8pUoIWNrnVVAwf/dancagWX6" ..
	"r4x2Qw/HZPDmX9wkBWahylMj/uG1xtISNB97BnEZZ/nOx+ISl9TBztJDmb/MNSNmD0/kcW17M4kl4TE9HVt8Kt5idfWfF3AtrHQb" ..
	"z6vt+9OIZmjVS8vKwbMeRAGFdSLJh5TGR4969TXdHYNWmWje6HAPzZ/c0QBb0C/OepH4gUV5/oLeEtzlGeSyf///+5dMn4Uxw9Ju" ..
	"g71IfRFtCEIROUao0u5hm3y9jS4Hyw6kduVWnWZjQo7HK06rje0PAhtd8MJYXVvbDSR91Z9s46xXclKExBAcgNMnzqH3HwxUoDhM" ..
	"pG7sIr7AwgSgtJAa5qJC33DO6U30E10OWGtp7XwXIwFKaxKs13gzta5m+i5DfPYRglSze1MW/wjDnQNVUmsOTS6P2CAnWxKhAGJ8" ..
	"4yGo7djq0zVTZ4yrmvQoBaSjo5RTKGmos6eQ+0al3i+DWVBJbOivNlbBDvbly4U5VShpeItJnDaXjNrvWfnkedEG8pkTSIdMZmeO" ..
	"whAGc02pnrfvFJfI36YzIrrYze80ZHhe0e33v3dGpBnuhboncH5V5orx7XOfj6GfvHAvK4ZORv4dSyuNAn80yL0OnxPMkP91dBl0" ..
	"n3yyCjaRs/UAD5pO1IYHgiJDnK5krbMi1HmM7OFFTlBW1Hu+gaiRVFpm0hdnCKo7/t09Z0Ehv/ROKrQNE4HGQ9RzLFRV67ayR2hj" ..
	"vyXuEdErQmWaltJNOs/GvWU3CbVXPZow1pCC7RcHBRevbT6psFqsX0vv0Yi79e/Yb59KWnZVjHyMLakOReu1zHTw5yXtyb4JlnrM" ..
	"Glsc9MvH8uFQFdJ+jKSlG1OFmn6/IjUr99usIb/MV6LQa2EJSzdDFSrFTG0IRzPMVVTfDS/XyYYtHggAVvcPTpwYxoZXCv0S7cC3" ..
	"DVnKjgni3GORZRUalCCNLex8ZTJgZZRbM4kuNT5h1q8ALlf2TR2bnFjhdbi67blNN9jJ5TOqvB3M/jA4critFvK4kAedcsNChO6s" ..
	"Y/iir0t/wXaWzpKGtDmAMMi5qVwaHpbZelICnRiB8P9CW6gti/l3KAeARIOf6tX+0NWeaxJNorsXfcGRGQubztoBnjovDgasHYrY" ..
	"YHHM79eXH1RgdQZnPslEhcR4C6N7BgPwtOanSubFvgPGfKbaKDnRfqV2JuwAPS7lglkvHFR1/CtdYBIOpy/gDIeLpHyWFhyS5dqf" ..
	"MMM8EQAVnh9BJ1bvwxWTfuxwIbk5l1+f7OinDjl6Iz8zZYwatea6oQjZDq7lELQUjXGv21zJ+UFwG92jiWB5zz4ICNSYA6/05KCZ" ..
	"YCiMAYOW+y06CoITCcWxB8u7HF6ey6IY5G8bJ/TJr8vzc/PV6tOL+lKhbsj68Fl5Jo+kHDhJ/Mlc74xYwWEvQkIqw+B0TAZFM0oH" ..
	"vHpLPp0oNkPHe/zKheJz6Ql7TW4Jarsy5IRFM5uScddany/f/X5sGPpuM/Tdh8KXte9uxBUwu3GmEKjbMjaZUd9lirrYQFUVgIb9" ..
	"GpuaiNjekM2yMXAKyMfXnVHixqaKEHaQiyvIIPBJZZ48oZBWLccS90et7KeY0dS86zTbiq+X0Wivx+sovxHOxo6HgM7bciY9G5al" ..
	"9loOmbFlIHEGhwicnymfc/ijUtPG8LDcPXGAvzAgT12GrXwgnNg0vH596tQhvpZ+zntakFnlaZvEl72+OYCf5h4Vo/JHWERgS2Hq" ..
	"dTAOSAswxtnTTrl03PUgSEbMdAo+XC+3XFutnYyRAWJpEaPP4w3/+vvQalwsUrcowY/uOguV54alRZrBpbWrgWLB4EEGnVBW6MDL" ..
	"OlG4xzjvZ+SjKmLbaQdGjoGvZ4R8KjCr/OS1Kg9SGgSFZ4lSN/PO9rwYVMAipb9nG965gkbdCGP3rF86eLvv/dghTF0MWG6knlBt" ..
	"uxXeAeyinn9fiR8pXIo/xP3g2QE0cBjhpwRkhIJiDMdT7Ru4v7Tou0vn4bADhufveOyUarDjRHQ7K+7SmaIj21SMRGSjCG/cj/h6" ..
	"DciDvO2ypzZKI6Zu8F1pRxbU5v0YeXtpWaSJLuUe7pCBMf9A9GQzf8xoFqMvNTIBvHkWZrrbhmjAvdx7S1XaFHv/C0c+hSSrlYnS" ..
	"srZHqTEPyw9k0QEeiGgIphZia7ZMGifNPuOrSREP/T4s4aH/4XiP0hQuWFhb8BUcfKLhZfOyV0Jqmvduc9TuzVb/wb69n9Mg7JQa" ..
	"l3tlov4v8c3puZpz1rfatwHAplsRgT5IIQs3UfBVRYFC0Yp9z79aUGAl95DR6OTIl50mwnTteg2V2MFiVD2SmrNhMmSL1TBYehiX" ..
	"y06Bz018XCx/UgmBGZtLzRi2P6FseXwuDtsxJtUeE0EDcH8J8sAJtd8q8yZr141aq8SL2+N2dI7sK5uLrTHQnJ8AdIigoaOWxZ9s" ..
	"8VtdcxYo9cPPI2EA8/IW00CSuzQoYEShSS/Hz/SZaVinwyb3DFE8pcPpw9jn5i6tNfwOckUqfXbiFoGBNVfenn8hvaDW7IF+o5bS" ..
	"+evLsGcc4W02Xu0Rl73V1Ugqd8B/jtvOpLipG+A6kNzCH1ZDjnA96DLNqXEUPF2L+Kx3tucpsBv8CmOs6eLUsln6xoSoLz9728Le" ..
	"Yp1npDEDt5dALdr/o1QZvNffXpWCxv1tUWN1xOJSwMh7p5EpHwBjIXlPsH0ZIdm6ZbcYWQYgU9SHalezNp+UouqvwJnVnAAuxhRG" ..
	"xmUMGLiGA8Dr6I3DOFNk2JK9fRXuHXdqq94/g1Ws6o/Yr81nApenp/k7cmI5Wz7sqCagmrzOZfe54OtKNadG2PFa0dVT2jZ1jCIu" ..
	"GXR98eJIh9CIrt76xpbtSTiOKD5CUksMc4xxUsKshX5oZ9dOGNXxLAsmoVjBGn+aGytbiTHnh6QwUlj/5xERJSSFu1vQXVV3MdGK" ..
	"+Uf+4Fz7LP2y87VseL7vfGeoeaQj3cu2fhG+oE5gKcmodxlO2Acder+kdGGfZgxlUv87NZOnFX2PKxDVN/ZIgEw/FQDLGhVc5TtV" ..
	"ZdEKngwuwsoQ3XuMgAs86kwZlw8CScfqXX/AQ0aKfcI4k+EM+Fm4iQYGd10OBO+arB7h9oHFMsawLoiXZV5nK+0QC+tlDn09ayUH" ..
	"/6r5rrpeMuXx1dyqZloQc+JKBYq1/3DCLrKT/A6LA2WcxU3SemRPORacRV80AAPBEj8o+51bvBVnptt8l7RkYbO4t3XmpEUalPN7" ..
	"PSMRQTtMvDcfza42ylS2AdgEXiFG1r1t9Q1RiaXpkBU7FNPDwD9KceFBreaAti/Vy27mIOBSoWGq+W/azAwobY8/pbGXbmB08ufc" ..
	"3uIY03B81h5VtRZXTJJtq66tP03GCfuOKo9io+b5QHaj5uuuK2H7w+/jpZun64UvuvU1zoo63SeEq79IpACIq8TFymP2m98gHory" ..
	"CSkzcxcKBv9T2KaqY737SEzKJWGnQEdiKHqrZtn3UVQscdApxqo/NvlScZU41IVL3yYqMSucxRQXOq87yz75iPMcZFl4kX0NqN06" ..
	"AOVBY4L9K0X3U3N6hufRADoUtNWqJ6o0SFeSgeU3duQk5mB2sUQMzSwCIF9W6+YnFJbChOjK0gbGI8WgasATjRjZ/Sy8Bqf+HPPN" ..
	"98bKRF/eEfdTg8XCM/z96hmxOx7cxCg8vwBTg8525ALXB4PIPInqDWom5FUGVyz7Mjd3F/FR6gFfMomq6J9QNhtv/L8bd+kEhJl9" ..
	"QrZnr0m1OZIoWJMD2bU5C5Zdw4cfoJG7hWLJGTrJvuKmAbmBYE+ohUlXzds4vCPGdORgf1wdz2eST1DNRzTu7w52CVss7jXylEHZ" ..
	"c/nQ3epZ9HnzybEiXAXj2RFgMaorV3ObN+YhT62jzR2eWU3D53RjSCBLW5P2fUkTVRXZEV3hvY6CiTkiFfslr7vXVKiSgew0Uj4L" ..
	"5YEPEZeD5zzbakQAIEd30LXLf0G8jiawDuJJBreLoCJi600X2MvYK68Ji8ou+BXOJbQ+fHe7s2tBfh62xnAEIdjqbpVAkJC/kpOp" ..
	"SP49zocLiF/U4fPBGloTsDI1XDiEe5erW8TLgiv93Ol+uLV6HcHATJ7UOsR7QQXbxx4EV2XTKuScgou8ltL8HA01TV1saHb8gtOO" ..
	"PZH89/3iTt5tvNuRKs3H5AN4Ob9cJE3pns1hiwTBDNYrgDFR2fun6ed5+TZblv6v19+8R6ISbxgjuAQDsMCQnkSfUKLvWGisMNDg" ..
	"/P+lvUOdCm9GZyDk3Eg0MXA5fNo1pVw3pJdZ8DYteKI3fZf6dMm1bbs/G7AdMMMjcsJIhs63gNsE4q1Qw2Zor9pH7Vs7Qn49epuo" ..
	"xGFjtndUGceqMzWEMQcFpkTg+CC0H94T1/ytEZ+w7engpDNsTOTDVUzxNRiXS+3pOZR0euPNkno2n4Mg9rwktuhgIPsltQfmQbcK" ..
	"82PFWYJhL1QoHbMvUknSHwZGOPKxV6ezWzL54C65oZpOKcaC8TF2hVHeZLnge9TNKHsgT6IxJJO+fYA4JlOT4THxEgvNJHjGxW7I" ..
	"1e39iZ41dG4wWahi5Xks0d+RKwEo3aAv7Ihcf5/u4ZRYOAiRHZbUcjFOeHYPgfwd4bM3cgRuWF/8/5NUdg6M/CBohGEyYWD2SP3I" ..
	"POmvZIo7Q5IpfS+5j2FtCbxnUU/N0AQmENU6B0n4ydQigsak6dEPLRtTyVNIY1nQqq947bjYQ7TaQk/GdYxkYf+GqSBh/llhXuwS" ..
	"P86RI41w8tkRyvAIHPnY7y/MuMmG0KpZ4ZvavB/jRz6irjfG1up8e6evFnHRLy5/S1QTQbU6mFEJ5WW/gOtAr6WT7MPRcCtNLkLz" ..
	""
local PAYLOAD_P10 =
	"ZH61P4NoVd63Cvk/HtaS3jYe6iRhbBgqOYEZJUVMkGYU++dXrnJr2aTrJ9AMG572p3piIAXmtPDGSYBviSeq5C1RjazINI2GGpKg" ..
	"0UTGGKWnyZbpC3sU3aP7yCIjmOY5DFoS6BeRoIXVNb0XiqXgFB6wvfllFx6WKzXgF6jH187VbUPkpc9ouxL/hCZVdZqUnALkhPtn" ..
	"aMaVwXizPV3zaTSGEiMPd8FVtQpMVKpGDygLAaGr1hGXH8bnR4QAO+LCKNgxqoPLfQrvCMmrtmggkCmPuGaGpUUfz/y1L8r67/yy" ..
	"BtPyWR/ulRGYlFdB980Oz88OhCiFx4CdwnPr3BA8R+UvuuhZLQCdroGIG5eALfCJmb87uuIDZg/SnOrDYeUm2tID+Nq49mlr7CCl" ..
	"Rh6/voa7UxkskrDc8obs/oePsy/U6ETWYl0Ka6/P8FLEPfg3S47TD7fwiaO6HQhgcSFG3dR3eqcuK0cu2yrcPhDESasiKc5jIe2+" ..
	"oEvNCOe66qN6lbWZSWvm3SeNNkHwAoG9EcF1TNbtLAoi2WPXtq7mJLLbIG1O3LPaOhyCpcjwZhtmaX4lyj+g4UZWWZy7aE+R7K8t" ..
	"RBT0rKof3BzljPVVM1CwYe6abtTTnPXBmupPqQIxklvqJLIRL6TsWsKx/+crS9OUTi3XBSiaGEQANna1SrG0LpsHCc+gyW97KRRy" ..
	"agr4QYEHCFM5x7g5uhveGWzIuVjwAailSrlqux88Fx3peoCWOuOkrxwmhkwbVhy7nbrB0HSRU+fZRaJjdj8Oi8fsJH5qmTSss5e5" ..
	"KTEvHpciRweTnJkuO753v170oYfhDc0XAUXqzqMH1uCA7BDjPV/AFjaiPfQVuP587uOkynjmy0yRJ+zq5wMcyRNwrzfiILJjXyFs" ..
	"NnQA4D1Nm+22cP7dRprR7yWDvJQWQ4m+4Dy6UcMElVcbHrLfBIzUeIO9r7zIBZ63os2OcfVv20yEfAE0pdEEgK0B/1J9IN9rYUpx" ..
	"ofe8qLEz2D/sVsZq37gwHyK306D4obRllv/1KF29H2+U4cYP9jL0N2Bqnlz7VNf6jTRsP+5tgamJ1qTW/WYxh7RZtrhj8t2U9Rrx" ..
	"f75QG7O7OJSiT3ub2v+cV+b7ltBS8j+xZ/IPkEUbc4Edr6vGxOZDrEaYyyp4cBsTxVW+lJoNWFpFSLkpSqLRMS1ZIeHE45Qs9jIM" ..
	"CZlMao/2kZRD6MwsACu0AHZHFzsLBiLv/7xAcQo+igmc0GAuMXUm1zIEUWVBA1JpIn3MP/iQRZAeGewjyKDP+57L8KvrZ5fjJOs0" ..
	"XnMvdTM5+KJ/+GN/YjAs0QRUYtOHkpMQWNzbXTs1bGWpKi40McYfMFCXmek7EquykvS4K66849GTFQ+Q63dCFnHknR9xzAo3OrT2" ..
	"Jy/xINzVNsZ6fCSCD53hoajk4UMN7GuQeDjQkQxrdJOfngJR7OupMZLMwMbNi5uEsCvToby/mbj5g8dvtbSVwvTmCzd/RpBRGbe5" ..
	"5IgsUtkfh5a958YzewWWKs+7/mv81ZS6DLQcxSyKEeYZK73UnvkXXSz6Ufydc72kDYe8Kl34Hm7oWAA7d33zsMBlxrJBLmt7b67Z" ..
	"XVHsOzEUvnzLZ9G4bHryj0iePn4gYrwKvjch52ivmi8m/fbHhBxz30qz02hN5IFzYXBpTb6axZXAzU6iR40rrDA605t6dFbKRLob" ..
	"IgGrvsXJPkXdOLxm/CEynE3bj5zs9cyeSnE7OXWluA8j/wJ0l+6Nevm0DjsrRk599IWWI2w7rxZqmnkYoJr0ul5ScSF1kTwxce9g" ..
	"Yk80jRAfwTGqqR+mvHuhQ1s1qZ1yl92c6F+UpExsGxlNaBt2ZKvTlxtsvkWhr2tcC11rcE23X/gRed9C8k/9MCKxOoUG2/yF223q" ..
	"o+FJcj9em6VLTdcazfjw5bLmD4wUUbDmgmZ9bL7Z7RtAiqDsduXzLAp8+wpay4mP5kGjO+4gG4RcRWBqf8rrOK8QHjF6XhRA3NYI" ..
	"IX/RpSF0aXvQT+UT9dff751TDoxLslJjdhkkO0Rhappz+JiZGnWswXe6ctky9u2p7mxKt8CiMes/PSRDGH6DHuer5oQRlM5mG0XO" ..
	"ezMZ7OAxA4GwgJgQ1DOqNhfuvhPVG6buoS0wAIzotkSQtPqhdcosPNu05BVuL6mkLz9jnL7FJf7fZ2qpZmSxks19QVDlKBrRLS86" ..
	"EZ+nijGXKIzBPvyD6peTZ0rgWEtS3XKvMdolmk6+Ypr8Nkbwte7DmsaYyRp+O3HD9SqVfseloGw5mp82dROPWe9gwhFEnB1acM0c" ..
	"hZ9s9O1KZvOz4q4q1i/K0gDgys3KU8VFXGn/IWR83qyHYZCJPwshUW1ccLHWRwvop8kBIkjA2mcczJwDNlRzJYKcYUqkc1Sr0i7Y" ..
	"zkDKh3NND0MpSQsTZ+h48HukNYwXI0HRTIFCmCv8pi8CjPe/y7bJYG5m8br456IGR7KC7yk7JM/XrKY/ByNUwhtnUzlhK9eHoivW" ..
	"RJ1qtbMnpw8nZgaBpheZhy0a+JomCMP9XU7haf7cgW+9h9/U+z6TaZTqpo7NggZP6UVBjzYXsh2lua7LXWlg3PnhI3klZGVfp1t8" ..
	"6TYdHri/UpX5bpCY7ZNxRlHREUCMPmY7NEzJwWkS+daZcR+v6/HQcEX1RmGoxqCK7ZlnS7LN+6zF0OpJZNZQFSUJcVPvyBU/uk6d" ..
	"kqnF/JgJqXc8LTHu+r09XN+mnj2hs+4kPcuYrjBB4Km1M0QJwFDKUniwitAQfNoQylneS9dzQczx64MGeP85hRMZb4ce/Vpx2Dtn" ..
	"UUCtBL69xVHlRVaRBlNs46K76IOl+X/WnsUmvXrvGIbEeaQbnMJEixYq+MF5uFzJV9SkPavzLiGfyGquucJpb1BDv5HpmCTevFhv" ..
	"CitVvIy4iujS6HKhpTbuOrqfvJVbItFlcnCWmgPYm9dXkV9OPhFPgKEyMBpYAwa2troGEUtAC3iSkNAAp1b2C1tynWM28io8g57o" ..
	"0mawMC/WOhvKyhMB9lo7+CCZK2AomjOBoXVY8XBIOyCTDf9ay6JaqDTTEHB3+N4C0ko4LybDIGQddC5PlhcAGQPCg0Dqd7TgTRBo" ..
	"vDRbGn8H2WsCqDkNIlPWumVJ8b1s9s9YcQY4U7Ix9IFMuddcHsOo2ICRQ4Lo0aT6VDeJA3x+eFEeLt5jrgVzbLIg54h9JS4bQPCg" ..
	"JCBWvQwNeqdacMjf1AX+RFpZ4oIYiWFWKVKWPgo/0o/8ftzlVX6oIJHjXYY7oin5gYn8qr/zKZITeWpQ7vq1JlnP9ChpEQyLJHoH" ..
	"ukyzlJbu1vk21FC5BVlHWgtJKHWe0QBhR9he8ntGUGKfHg7KzvX0kaXdB3FWQNiApSK/KeZJ3/P6ETUeME2NepotmvnpHvVWYEvB" ..
	"1fRJW401BHKxWINTPUBP3Gla9o6V6A9Z/Fn0tidNbc1xwk4WdzkjEp2c3c06P9ALd0UL1BGz0kai/b6+gEDOfFyrkTRa3K2Q5xqr" ..
	"34HDEMokUmn1TujJSq0xVnTAYQl1ZNZWQBO6ikTa+x9Xlvsra8V7TH1fPMPgPZRriiv56yg0wi16WT2s9ASn1drh6aeC2iJwICVc" ..
	"vbyEoV5fo74t6hIiAKYcLefmQSLEXl9BhjyXOdYTrzYZns85RjHoS6VsCliNxjJ+4v33SQshLN8GeH4wUft6HPfxQzn1E8wJJTgp" ..
	"w+o2s2BsKDDrbtvHytn2BGsz9eAiVLQanZ3jZwSbSP1v+x7O2ZcWmg1LcJcnkK6Usqb6bLT1ZKjaEggM2zWyVFvKeMgJQ6wbRU1B" ..
	"llkBSk4nW9TVg2RCr7rfcOw7X73VU09r7vMVFOHp/SX2GTodQPsoRIWb1TsB+dQLe1D7x5QOsl6ll6F2tZ5pvVyBLMWlTEMQ1hWV" ..
	"DcVW7bxga7gTrjtdNRRlaAY8NEOqNbtgceIU2hYOPHpTGk9bxM2jMe4YFju3QJy5JegRj00FGGcRdXHtsBNpqdYk4AAXyPY7TWHj" ..
	"9x0Ng/041bkpqvN1A44rvHLf70V0E3bFU6Vv47XT5wHqrQBxgnNB7gVZZ+HSxKup2amaWOc+dyQF+kmnpjho0pOFioUUvyBehI+l" ..
	"VbMYd6IrPsbpe3ixBHN8W2D5/B58NvwBkGDW3Bh5FqTAYQwee5NZ9StWf1zTHZ+PWQoHx/+TtQym27uAItFz3X/P6z/iLiXtGlYx" ..
	"Ltp45gJBhh2kSdH6a3sno5PH1j4EUSlCfrJudmAr/WCuO0W2hV8fmKnNEZyNyfGfwwUCkvF10JJ+LHrvwF4Df3DW27Nio2TpXlzD" ..
	"evL2ZQpRYFwsZKsKagL6XwBNsZmk4ofLKEjBXvy2m/6Zo0CUUR09xYW3b7Trajsj0sU1FftTThUWqNdxQnrWKJtvzOL4G2A4O6St" ..
	"rhK8YTweylTL/sfdW5NiHB7tZFhz7k/jNqRmneQVhBqyweIIU8OFi17ojId0Kl9rU589/OQ4/jrVa/NmSltMO6AgYXI11BqZEU1h" ..
	"cTzuOcToy1uubNNw1tcunn/RdrnyDYt4AiIU0tL6lTm27e4o1POgd9xxa8OU88izrjn3qVkIFMt/kUxcM6JvQdneCFKGKW3gaFFr" ..
	"WDSw7+Bi2L/MLxI0xfwcYbVq4NrfO4KdTygMOgmW8mJqEZ4yAH8tLB5JULAO7gapQV/zGIbaSvz3md9XGwU46jxAnOpEfq2i4Zj3" ..
	"kEjdwvJtCoDHC6klWJuGLJ4HFcQbixWB/uyqPncSYFh3mD5xY0SAxIqWiCzH6ouTldNTe54RGhxSuZ1yOFEldVcLGQG+fiKR/MHB" ..
	"ATDOATai32V706fN+G/KEqJ1f4idEkCGUcpxqfRucE7nKGkRA+s1IPJIA+etav7jwNOI6Np0Hm9I3SjrqOwjSu6aEWG7X9UjvNgy" ..
	"pDC/Ua9BfjbKuMHODqYoQ1xSaC4otllM6Rj78VklzSSXVnzb2eAH6YCQXUrtXUM+f7elQ2kS4bDdngRNVzpZYlaZPzxS7xgAyE5t" ..
	"BuBSJSBNkwFgbOLuNbLrEhlyAW3HCpMfyCNzIwRC057UBfyEa9fmmHZuVq+MbFi8ZwdxCyI+2Ywk6soZfIt0ct2qKyuuXDwLpFtN" ..
	"gOziDvpBFN0J9iNdb0ef5sjq/4JGPIUYQHZuj0gfzPikf+TX1jXDLkq/QOcGNrGDaXoCtkzLYTUQbURSj4R5j6w/QkdwDb0iwhXb" ..
	"61+Qckno8KtiNJi73u7W2/Sc75rQwHI/B3NUKRTU12W+5VLxF1BibMtq4zXCpOydR68ZYQ+16GKEIkMhNiHkw3VtSJ5LyJ99swM5" ..
	"X6o6GnUGXdy+owvYrdUzVZVBVXybtq5UixFtC452sVqbr47bZU1kx+FPDMHmsC2EGOS3zZne5Wv6UOUFYXtLSetOTj0bV2x+fDJ1" ..
	"rqYuG0vPk7PzZLpw4ZcHc2C07eAT/AAqSepmaDgIFSMqazEUAOggLt34yAKVkOJrfnt6V7MsdpeWYGtT1TdRy+ad7dm+f7pb8cs1" ..
	"e12cdfWi/XI2BcGQp9YNBR9w9eCNE4S8gETkh9i7ar8utlwEDXPzLiHh5VKOyFDntimHNJhm4Tn1CotN2EeNj4fklDGAaiBgmIdL" ..
	"erAPaOrrteqY/k4eVcB5DkL7wzWqwDs=" ..
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
