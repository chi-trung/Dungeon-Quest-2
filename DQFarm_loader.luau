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
	{ seed = 3503166608, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3501618310, exp = 0, plan = 0, hwid = {} }
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
	"DPt7W0iEYTZrML2X4yJt+3330tfKKzc9L6cNDym7UL4Yz3k9WMbX+d55V9NEL+/YMTRnb8r73pUJez/7NaxlgqZIUDfkSzQeK3KH" ..
	"rJZ1LovyV9CkSFvrSdooZVQZfzY6AlhKOSkM7eD97CTHLG0AcErZfiQidNB1zcBNCviweCHZQkFV0srFb7XOLm4f0ClCSCUBtXSp" ..
	"kxBi5+lHKSCCZpf7c7Nq+myfSdHS+3qeoaghbrPnln7F2xrpvDpTwCfMpEYiiGE+V2F1fr4TRQb6TmCI82ki11km6MCU7AAmPFMh" ..
	"+8gFJNiMmu8YIoyDDXTx/VnpTmNFJn/FcgDXI5FYEGwpwfnBJ6m/y7As6S3iaO6fAgqfo3MzQYDxQOGK7/o4zoB31hHnL8Dgi9DC" ..
	"UcRMDhhlWYq8zo1Rx6TkRGINfW/Oa3PQH98WgaijVpRkclyzEAJRLr1wKCJOorKvqZMxUe2GzcDzgeXGPiPAV08STR9pW6n3OcYV" ..
	"fK2q5Xsq0x/M/OxrDKr1U0UDBAvBQrbvKemUOhtnpRjmdwpvfmzUhkISOceZIZXN32JI74LTYJ6PuQBGaYUNIBc47DxgR2RTqXFD" ..
	"zW1H6DhTGmFOitwZDrkotIgdDH/E9Iz8HuQXaTkZJZSL4+q1wPOXmNQzHye2uGQZko0OojkuLQjHAAAwegtK8WSEw/PHdRb6sS+e" ..
	"+XejVJUNzvV/fHo1H1d2teLxwnGZZ4uL8PF9w7y+5d9refwPoMhhiBjYMYXI5WKLPsfrAn7pW7Lg0PgX+AtXAn91lLIMBqs/le5R" ..
	"cAFYPQKTJdKzDe32zbxyGlP6TPdehhVtySovYmzqRBnR/j7tUnf54Yd/moJldD4IKb6gEY9KTO+F8FFr5K+gW+TLSyMFTKgwPO+h" ..
	"xIg9enVM60n8buc2HOvF/jHuoDBs5Bibhcu7y1pPFtVh2sAHbW7qmf4b0Dt/m8PjT10SQvA4MlUdOsIcxPWfoQ23kuRNqh9Xoe3j" ..
	"Pv9AXhJ2hrD9eMEIA6SXrGOC7qQglsnmvEGMhJx/2PnBZSA+aDT4WgRr6xXGIsmF4F3yvCG7JtuQX8sZ81VG2JE1a/BEocPCPlkt" ..
	"d1ir3Et4mu+1lOC9wONSUNlvj5tv7KvpsvM39/PyZvTsWmxGM2ixgYq7xkiCyNzzftc8f2FE7f9CCDNf2xSawn9MlPbwmjabGgFj" ..
	"LLYDzI9kAzbwltJbxy1w4pSRf31Dq4ypp6goV0Zo095qs+/p5nrIDYxrCJEFh83DjQhDS3iXvsa/ZfPJ1yFAIQgPOi3JAgQFpIYi" ..
	"+ExLe6Ar6S6vanPysW1jFmOpKYCkKMgrs/47moyxhle5QNzX7zlHu/SP9IQ8rwSO8xHdncNbE+mwvY28INtG9g2jooX2O0NUOjvS" ..
	"bv1Cq//XXCV2sYDsZJj7H/aOk4HTYLtoJYcaVRNHj/bpQTu6Pf4EKYLImH9Brjlms9jzxLPmNqtLMRc4jrgMZqFhmu+8/zxxJOVX" ..
	"WP0w7x7hulv9kccQ5210IN4PgonCTB/GLHecvLrE4/hswErwgfjldoorwS98zBOU9CpJS7wBbBNGdE+8JBepHARi85x5OwRbhX5Y" ..
	"lUD4x75qZV4C0/TaAzYl6AxxV+kfFthKDKk8LnaIvRyHqGowXKxaOkYskZX1BHmVIQVJkwF9Sg8W7wZr0yAWdzYELyneuEcJlTzm" ..
	"MHRWDSbP8/QBHZ8WzLfO8JWrQ+CTkkDdpMT5HIGm3QaT61pwxRzeYpfcVFixJ9pAzVeQtghtWckffgVf80QvmBE3EHwQ66UmaAly" ..
	"a4fwCA7OPq4aRoL1d/i4XpJ7DAGHkCm4wUU1RdbX26feVTsb8Rh4F0PZopir1fNjYSOzAbn9O96cGXhEn4Xz0B4AXJXNg/BkbaRO" ..
	"TkQc1UetKBReNBes/Ucu7U1DlecQ2HaudoGvqIOkz8gQFyWKunupyQ1oydUc3rcP5CcvVrRcbY5Wuo3M3CS14vJyEZP8D76ld4ur" ..
	"hFlrFhERjIb4yBwzU2bW5aOeipWNPVeN/QFT721Wnev0A0SAd4cOmq81OFcsSo1fes1quHU++5x3BX89DcrwCbzJ/Nq++qO6FZF4" ..
	"J1Anveqmr3pQ7ybNQ2P2mrJxzXBD5PcU0o4vyHY82aznEiYy3UVxTENQEGAQYgzuTVvjVAL+RgtVAW8kXYJxF8tugD6SbmC2sduz" ..
	"9BcwtwLMWT2puzFl/s40CTybVXUe+L7/JG/guWmU+9cyyCU7zTf9uIfbLZjztbsE+Q/NAZxF2hfkmxRtWiZCA/Rf8xNFeb0Ib8aK" ..
	"Fo0rQtsw/D66CY7Z/4ZpGjorVyxR1JULtVF3CIuPHuEINiZzPq8h9BeeqidSPtbf3hCj9w1qrCU6OceGSaypcN/3gpJ7lez3tIJD" ..
	"RJWLYZPQL0aonsXowbfgUb+LINp27zhLR5f+jd8BnMiMjJ1dbUf82sTdAmoCvlGgbVqCNV6PlFw6NmbNIY2iMWQHalkiw2/XOz7s" ..
	"NJ0x+ESC5EZiiM97TW1iDqSy74CGOfAsKBLpQLfGSKVSx6R6P/DCRdW/ZErTTj+CQy5w6kefSzNZc6NifzLsbMgAJ8c7p+k9dSRp" ..
	"qZaWMeLs/TeQYGVp44+emBUNkMDQueCn+ZqL5dSzQ8xqsNnCxLxsFaphuQEYA7pGPJSuJO44kdurUy3qT9uSmVebDOlpWkj7u1JF" ..
	"kQvE5/uWdQme8dT+FxNnBBr6DgTMgDefWiCVvCpFKG7quP5OIZa366URN/SPPcRJzMRVJ7f1Mt6YRAGocktAcxDGazbMGavU8524" ..
	"33kPazaYP33glx9sHrM00RXu9Hc/Nx6J2izebNMU7xb3V/G1CW06Hpl/l9Urw/kl4zBM9mAYaYTiRPMkrmIE1pHodsrbH9iUqV0c" ..
	"tk9Nrdai+6+Dy9lhn5HdlqR0VfYHoQNalcRHo9nF9HqCBRPvlcDsTFOV35JgZqUjMPWKdJ9GO7I0WpysD59PyaysFWgwTLs1T3ov" ..
	"hNxbm8AsEY9FLV99dAIjBd3BjLyK0/+oK68bP3kwVc48BPGM8eot20NhOAnXScRzK+b8JetAp9pyBZPAZbD9ZxZNm6gyC79AwVTE" ..
	"wS9EDBpQeD+cjS9OQEsWH3PKEnzOz/zQNy6mc5YB5n648nk/vCtTNALIamTK/c6+X7Oh2v8ZdiXM1p3hp7oJbRS33AYWSd529zQs" ..
	"bnMQP8j/fZiWa+hRxOrO/34mm386xTkqFyaFsJK1aY4G2WPksOKmQThTgRkA5V0hqEfT/69fhWR6vaFzm5TAjmIwhBDQRxJer84k" ..
	"m/pJFwHt6o1ksQz4LIh+Qw8ITymOXGt+MKw97ecRvScTQqw8VWSMm4gKvMx59CBGIWRnPTxWWMzsSUWtIfusLQRnpNSzp6xP0nck" ..
	"V4BpibDrR4Y0OjkqsdVZwvZM7ve6ErSGg9igml0VBliUQgiY2mO6daD8fWWTS2quEc8+L3i2eNEpssuBz3HVK2x2te5ez//DD40o" ..
	"9W3iDXZRD0kCypka7s2xL2hIPHtbGpDtY51cToZevQOWIdU4mwuDeKsnWkGCAq4L2suhDJZde+jn3S9O2zcjU2ToWALqsFsibg8g" ..
	"JI9bu46JTsLOIOnpleG26xbBp1aJi/vDJzFR6O/AiaI5Uake2SInTkKBMPTaztFgm5DIyU7oBKuhLf7PycMA30wS6a65Tyy9pz+N" ..
	"d7Erw1iXhWVWOqU4gh3muxFICvnx/HdIgOoB3fJS/Kkya9Gh1BlzoxzHMbjjBHSwWwTRVob1WF+CC9Rmo2NN5NXArp0recxTc/Op" ..
	"V6+9e4c6zAX56fIIo27XWzFLN7+t8HYsoIj/YXqEtjLCri4uVGuRokCqMTqF/XX4IYiow9twfxt3GWw3fNpS6FP7i7T/nu42UBuc" ..
	"E4DhTTwBzT8QNVJ3p/yV8umH5VdKflfz8z2lj27LURevWHXZe2av1AQgxcyiFviGG50NNET9ozua9YlWafItHjDE5WUzmmFlfCaK" ..
	"vHPlhgqd5ICBN/vktDNr0U6to4NT6YRbr9lC0NkEyE6xVopR4f35RGFYEIaPOuNUID/p6D/bWjfOYUBN9InuqKcauyl1ZIej7kt1" ..
	"ZSxhqF0QS4M73aaMd3nUKGul06t0QU0RhqUExmIkTNi0zt+3It7v/4DgMrXBGx+8o4A6aR6ZA8sP/IezJ64IQ/pDCkFzk09P3Dqn" ..
	"4kxIdFndVGKknoEF1moXpzR43Di6SvSbliVSW50N3Y3K7Br5gsT0vQ+T0otjJqPl5ciwOVTG06YvjR38eT/TX2wDH+PwHnYJFQuF" ..
	"ayGfwtFaAmF25neUDb95cS1BgyKrnFZWIMov6+aV/WctlEGk/Oc51iMAn1A62vovb7T4PZ24oNu/169/QKUuDYi/zWCgcnzo9+E0" ..
	"RAL8wv6jPxormMzL+/ls1LPIKqmUSI34anAd2/qmJU2lWR2FeiSS0ltWbgg0QH1sqvi+Xc8o9z5z5AQAlU4yHK+bFIT+y6qnHVSb" ..
	"uN9+5g/KZEPL0vXzK3AfgzZ7JNiCR1srm8W/lavCctfSsFZvEahAkjW3SyMqWQnRBHN2XAHU31B/rSo4tWIleCCRYfbL0qT95fAD" ..
	"ORvU1MJ+UBhqMeS2cv3ySkDIalpU8fz08jrw3aSeLtTg2VpH9ynxxFgDBu20lrUHS+f92U33C3vXeVwn2P3TIrXiNoIEBAXnFtzP" ..
	"MN0nALju2HhhX2RHq72cqlSsIw4Kf96ZJUMWY3SlFv9qt4cKZ20tC/LLCIR8nhgsCSCirFAYzZtBuy3Q253eluVjRx1F0avNwPbc" ..
	"oAgFje6k0zS2D7qj1USrWwB12G6iRf9Mu2iM2tCYAg2nZB0HxpdMutVwpFM/KeIglVru6GC64Z21Z3Oir3rnFsynaeRQOVKZeHm/" ..
	"kFeebWKvuYY7ZxWXXsl5cdsctz1inzAz8YHPan1IR4Z3M3eYsZiK3ifyO3YfAGZ+LAG18AtbubcG07ZCy+RsAhYn8Y9rUHCQMx47" ..
	"CZ4E3/J/M4bI1wS/uX2K6KojHqR7vnX8F5764b1jCEGDHm/j/yyciMllnfH6Hpm1UQRvs+p4Q7rGrBEp9SPTagiQ2o4iwvVsw7ZV" ..
	"ofL3mxRi1+Jhja6ugGTO8Jj/yIS99pcKrClMJpMKIlEwXGOfWmguV1nqnl+7sSwgqizcTrtFbq3k106qFDAUY+dB6+QiaRLC8eHt" ..
	"wXlV9wATWBY3KCLzSOKjSnkxraV4h8Z+ZBqdc0SARb+AA0cf8d81NyCnwLtxkSg6TL0g6TQDvmIlP58g298p4DqhP5C88MUlxmLV" ..
	"QEIKo0sJi7K4WKyB0pp+cjv2QlmtCkgMwGk/OCprJIX0szC+lvBZ9xPd5dkhE+ai/hbxScnB1O4E7xP9VxnOWNayJb2cgzBhjn/k" ..
	"tVTYN41mq+69OatmdIbWPUQgorpeV1Pb+nPQVwQEtwyEQgKOtYRBGxzpP5UMPzXoa0gJn30PAL4ZowPW0qNWcRxJtrJVxlSj4TH8" ..
	"N3VDmBgoHgHaRqqTplg4h/Dd2h1ZrPIYX41xVzkun/dYSBAM+cQMFlXS3NHfx/BKuBSX2XWXpL9yvq7iXaKZiOUGfU/7YDHW+L0d" ..
	"zbCRydsF4MX68Ovg/AVn24afw8Bf+v02b+LmpN6c9cVhjFadv6v4b1cw7Fi+37yJhOaOxKP5e9IcBAr+c5/arBseOqaNpc4K70fx" ..
	"nonTTwk74SvFS3pZBWlHx+XfWTtD3jQYy1NKVw60zmjmY4TfPtd0s/BwXm9AqWF33vrnQ06+9VsCXjokjI00bTanX85IPIMhuLSa" ..
	"r21FZgwY0wdqwTcHOqiADswbvp+4bM5f3Mt91rPA8p+Esw/wd2mTD+LDuoxuBKMDlAnjkAGm50fVGZ4Jj3iFsU26eFgISDk2kYG2" ..
	"UC9z63tTstkdq1efEgFfEUjDiAMa1c1pMySRwIrq5IVSHwnpYkmGmRO3/Cb6mFka9S+magg4i5wzxcQn1aMF/A2B37dRBtRyGzR5" ..
	""
local PAYLOAD_P2 =
	"Z6pY4iDOZHiv1g3cZuGOfx5SKQclzfHQ7VmNdnXibiYtehpmr32WnfC/JJIUHmqhSy3cQIyKa0Sxp+MVNgPaNo0LrdSfpzIuK0qS" ..
	"F42qdQcIa20Q65z8ao3M6Ag7GQC/z3gmfYM5Uw3eWg3yhUb6GV8ysc/v2uUS2T1+ri0QY14w8Ht2Im+QMB3O7APXRdnhOpP+mqC7" ..
	"w2E5mUuYQjHO3tsHgc9kyNVB65BbcY+BZnOInHx40ci8BP01RuLhws6dKWn5Wwt2Y91CI+wwdeve6Ma4rZdO5KQD5iXPZzw/ecZR" ..
	"UgyNv+tH/m5ou448P9ahBC5cJBjYibkvnaM983T2zv+9L0M96PNtVOj/sEA/fctZUwj4AIPqm2xO5H2f2fb7cTnuSetX9HzHh28J" ..
	"0ivRavY+JXQcDFwfH7bBr1jSImGbsf1DBenjWAQ6HERFXKZGq5nxseRPxmhd6Mo3tAeqJmApTUVbokujEqWmwSeyYCH62yhePQIU" ..
	"j0VnStxYiAJnNKDgVKiC6nmG+NKnYYPW0COFs+YiHqVJyfuXlvrtexdjltEhRUKMHpwtJLfqFTT302GBeROKRqem5W3fOSH+Be4E" ..
	"ur1nRlhdaRxvPCPQItBeySSmI3W/awBz1TQWKcPOvWATXIrJGj73fSm8UqgaWgGgwy5fRVkbw0z333ydRuxVJijiqEpAgOg/iID9" ..
	"033HUICyJWFNI+I92lNH8UIyNYTtohEbVl+86hvS8em+85MFwKZUdaVUZnn2/YVbiX9snrj9YQHRLEEO0LY4TYGiyF9DZFn4yY5H" ..
	"/rg5hmvx8pjrLr2QyWMy5ggNOWii83kCWbPxKGqWur8t+O/cU//rezZ1vbDvDH/5jUJmwPy7bwtOTcmdY/jU0MGzdFn0/6QDmbTe" ..
	"x6Mv/YlVaUhbx2Sfl4BlWUGgPiv1DOy5OZyReriMl3Ic1P7F2AzO6v1pOy2AAJcYneS2IzUuhOWZfd25qyfv+TvdI4GKo27HCMwO" ..
	"s1TBhPwPpaVpVmkl/P8jUW/n4MDYlpWE8gFEyOkTyT9KYf2AFN7NFmXJx2C/0y4YL2p2oUG970HrZ6bkOF9Y9AhK1RXqLCFH9qN4" ..
	"Efq32eRMwjWhl2qR1FeEf3L9SRy8dH6COhoI9CWta1LYDC0pFzm6hmdFe9kdHdBATllndAPWWcr7kYwgGQefz3soneIuVH+TEOHq" ..
	"y1L5478xRGj4L+tNo5bzI3y70SC9sDgx32h3qbBdxsvmPjBqr9TdZYC6+6YWUYSkQHujxJIrMrtynXFBMKyIjgeTmAg+2KOSrw4J" ..
	"cc6Ro4t+g+gUwQYYBRl7n8NjmopQALtQQDp7HEkECJP1vUthbCxdi7CI9wh4zZa4XUNHEPBgMymkAyoGZFHHnqH5V+3o+orlHncI" ..
	"DAbnV4MGAUqdp4dQ1aIG/2WI1WWvKMa9sFO8U+BmPfN/UK7ti67RYecr4VpGPsZxuVjO+JBs39/pDtzLvbXNZO3SB7cEwANUy9Yw" ..
	"DlmuehA1lsl5qw/zykTrA042hQkdYa3SYC+1nC9vvMCc2h/rPKKC0Bm1BXS7NSv0YNUJfyQ4VkPqP+ZyOS7quO+xgb6sJjPMtEp4" ..
	"+Q3PcHXQMMWetMbKhQVAUBtf3DqGbFIc8UYAOsK+HRlnq2EheHBWsv/HhmUSEJ83G3YAQ4FLzJmqctmRMk0lrGnI80Gbjdgxn2xB" ..
	"bqWfolW9TKyMqvrxmtH9yD1s68wvU+UOb0d9Sks7R2JuiyKM7tEvbszfZrCfTFGKWfZJn+qoORy9f78c+WqvKrGFEljdN4oFBtAr" ..
	"5Ylm4meTDllhKuJHPr7DSRkJxg1haV+ZDTEwENga3yL5yomYS+jxvMdrfmqNmrphDqR0BrynTxQ0GmgUFcSbJDU4oIpsiCqGFRIY" ..
	"VwXJolbLidCLHBotApejv0TZrTdZqJUA9n5hxtFPeSjiHp67Nif2XVp1NFtxBM1tXW6BoB+uAzWxa+blWgmtlovf7jzfJ7M9J2Tt" ..
	"p7PJUiGwztID5aUaNQhfCdcS66M0kg7mgzGupj+gxSMF4LMc0GuZandIH6mriJc2iVbE1sk5ICw9RoO7BRnxq0n4U4WQ+Xu0WfWM" ..
	"CYKqfOTGtw+m+vVgPF2Hht5WuobzfwvyvmIT1kbtduH86p06EL4fyd/Az/BLtdx2+glO8UqxUT+zfHgvbUTsSsFtDigRkZz+hR5S" ..
	"GIxsq6ZPCB9QSLSv3tIezt6mm/lwqSB3fYnjxtD3F03kEgUyzGn+qhDWBM9Gx3qeIULfXHOJ7X7ykX06OTaY/ZsrLuW6djCsjeum" ..
	"mA3JK6slxLK+sMB3amICgAMiRduVZI8hXuJLV0HoP+2o0IwIhykKpCWvtgDWR3MRKBxoLPMqccLcHffLf2yRa9o5sp8xcXJfoTUo" ..
	"WK4j6KPjpiEDi3PqeOZI/4akd6ze80gfRi6PVnv3I0itaB2ZHJC0EN8BiF5lsyCRp0cACJqn6zO1misXl+Saz/sx+ZcTkR3BovRK" ..
	"gcaygE4Kj6NJFy9U5NTUaXugzzbZkX/K6rRZXLbfW7C09PNSEeqQTWCPjZ+Pac1c7O8JEjtOA7Lby6MaQteU3uLkip4X7AhzAgXi" ..
	"UbHPMbBnWYRwjMqZSAlKBZiwwYvu91GkcufsVhLoExBOollcyCKhQwkHpKnz9hIAEWv4JG32SYM31vez5sPALiqv8G5WjcxzTIk4" ..
	"jK7rqjXADhumQ7C2MKSu+XLMvBYhmseK704wTYXiSz+qEkxY4npKzL3aQ1dQh1Ic2xnuDBvCZpWJ/KaeR/Jdxe2W9LeLCVq/Qe59" ..
	"UgNAjPzszVYlN6mpqYXHOn6fg5oDr+hn+Y3MLmF0vX5JGXsEQ/4sLTwqwYS7q7WGGjRPM56KOOwsUZk35EI+E3xtYC48dxV0REZC" ..
	"PNBwInobAC6/XPzyf5+CGNK03X6rB4H8GoNjyBG/N9oiVpq8TgABxkA5F2gB8oOVVt8HjLbLn3pNRnF7rfvUOx5zdsBRKLfNtxIK" ..
	"8N/Dvp2H4aeLIT+imWQSltiUWrqwHGW5apJULNwb+GpKf3LdMg12XfodqHM1j1PgRZPTaodM4tHUGlnr0jeX9jCZ5aUuUsiodcUP" ..
	"1Nplm2Qle4iPR11gkG40iPoDR4tKpjo9pJK+lfNBQ8d7e2dhfljpSZe46W7Wb0zLwoC7nWcaucaZte5M0XVWB0tlMtWdQLUz+L4h" ..
	"LMaCsD/TPdAD856b08z5qjMfBpo+HrxVgRvCS/tWXkswUhi4u4FHOEGMM5EQDJBCCwAILnekR83mPZ2dI/3bGa+C7O9tZd4GipoZ" ..
	"sP68vG4faXRkiJOkAwZc5wMXLJV7F21LerLT1QJYg5spD755mFYEvvDOSqUwrDZP6mLDBup3GvzL56WPXpcvQacTCrd9TVq4T7jb" ..
	"AYLikwW+MylgSdHxNGBul5kb1mfbBO3O8y2ouz8UH56BmgJ98cPj3duUF4wZnIwdG5hUrGjjr0fxa639PL6gspneYtwMvsaO5kwE" ..
	"zjQ7HuQLtEl+1pQpAHgfbrdBXEWxFJjnUKWj2YGhSGNiQD9oz91xeq13SaPip05N4wLOo9WsdQiRyPbEsY94zl34MKTK6OgZHgxo" ..
	"g1gKBh3+cHfufvyOZySe2mITyvhFu6vU59RnJscP4ZErLEzmYgjJpQU5lvE8m9vU5DnSitYgSwX/nY6+xdH++wXkQzg7hKQBXnwC" ..
	"T/nBAuprbSourMOVdRQ6SfEaEwJAc5T/bIW8H0QDLbz/XuLLrZagIg2+CdLhJYAvMIns+GQMIrNeNOR6kZm+aYUgmEJbCWkvPrB7" ..
	"zSyeUCRE/XnlAmmwmFTG70LW9kuxAR9YGP8r3Lqngc7Xndtddipp6elfVeMi+Ctql3jNesJOtASrnSt4j3fhZL9eeXP209W8W328" ..
	"Ffy9phl/II0ANaBusvRIK8eWfCso2g4A0pw3Jgs8jGkOxCrf6n15XGBHn54T/ygHBdxiqYaGrAIAO913LJOAe008Crd22qkbXJxl" ..
	"IW5zlgRAy8GB9ImCAvP5XzvnfmkQEYDoVzKEx/+8Uy0Ah5qBWtcDcYcdRtNVBYYF8l4N9kHGu9A8RKMPaNRPzvD/eRMGsfxhS7Fa" ..
	"yRScLRzCWWZ7sJmCxoiu011RbmrF5sw3N2Z1tPwbWCAiw9D+YIiurU9+/6ZLMUzB8kpTcxZcTk6fGNq6z8+HWmOn1UcqSMBifseJ" ..
	"86+Dc1UOxWJ8gbRjGsyzuyxWrkecr1CNUoWkxJhIWoRKCT7HIacaKQGFpd3GMWu0e4NSpIvaZ21L0wXCQtYy0AOnyGgmhCbuTi5f" ..
	"GnafrI+oXxITkfGqDqghzC9lIGY2MqidGXdE26PvkHMl/nBr93zLSoK4mR4TOQLyH6w7rGbaEiz5WKZWP2u5nn+fcHOrz+eUv/eP" ..
	"DedBOQ/FSyaqTHHnTDn6RkGAr2itpyI6791YjLWygJOGc7CbGXv2+phO4oKDQnabrRi3WLwpU63/SX7DOlEZ6OUpQ2YMWaIavq+g" ..
	"SceJGsdUWuF5cGXBregatVbKOgMRkrYc/Sl6dQ93jPNDyv0EN++PPcWDEKIGAf811FZNy64+r2g3vXV8qiaHi4+u3Jrd04IX/NEz" ..
	"+MT3ThM2zie00ApoCv61uaXzQH9ZGvNbzkCVrVaCkqwW+Qw92V9tR206kbNsIkS5XUHgoYidPQ7xwMczJqSvY7a/K3zAZDsmwGgM" ..
	"qKloUG0NuMOHQCnby9x23PQAhB5HIWxrAh8dnkaWK00tl51NMZYcJfIJqCy8afASNhJpJmv9h8bmw6LRH+b22A4pr+ZBiagfG2Or" ..
	"l/i3HjTMq89HB1KEz7/Li8C1R3KsK+6hu7av/iFNtV4CsMowYlozD1/swOxeXAlnBPLBlTpNyAeEE/RzeA/B0HLP1OyocvOi9N9A" ..
	"KSclfk4E862i8qfnB1anGOL6xJyPORUNJP98mlfdAHJqvnVXbuoNJlNtW6thiBc0Un5eFa2pJPecywGthkiV1gSAYnjrWhcXF+hQ" ..
	"Gd9D7vGCwE8AAqhHpbdsSXz8zXdyrGQvZz2cgzDLQAt2dmTMi22dRRQG6+UwLm9ebrWxUhJ/gVlR5eau1IcIyLCPquX/bAPQzk/H" ..
	"Wz2QiMcxVkQ21apOtXNh6aID2bEg10WGf/E1XcY4Ci2CYbhWoueLcZXntqt4d0j6r1i5aeJUtW81nZ6KxfEpzwkSIzajAWhg5c24" ..
	"yfYQDrHDgt4WxL0rLTwnSddw4AQRb2Z1IFsK46Euji9Qrdoa27MjH1emvfuPH4vYjGhvbcaCpp4hyWaJx7PhR4cCNvOUOEKMFg61" ..
	"8xiBy+omNMg3iZqfvEz/LQjP99mf9MNLK2M8343RfcCq5a5Ae0+Yg3T3S5YaI0z7Ko47fFi2DbTqAQ51g8DmL3A9xY/c8tkyRpk7" ..
	"7vKf3FLxvsHfF26WspzoRWEYvyO0QwTd0qT2w6JUsqAgUaeVkorzaJ7l27C4W9u15NyJUrtwo9FxITAaq7Do0nsaEV38fcHWp51B" ..
	"99FRIUzhgTSMaVN94zb1GQpCafjKX49JRDJMcJEW8J+hbzyKK9iuARNLXepyEFDF85UazI027W/MfS85CRYiwmuk79/G8dG3PSEt" ..
	"FrODH0hX6Etv3RxpVgyugjxIR6FOswh29eUrTICI4b7fUEc7uqR1W0o1yR+QAyVCW+R2hwgYpqraqeuOGOMg/bLBFnM5uXapQ2nB" ..
	"C9mHZ81s5pvrskwdDfOsPPvIjM9VBWIS4jHI6N5wJ0uFtRbrQMMTQicFvMAHx8HXit9rAXyzkiH2H6KLL59Kff3XTsPnxOsADgkQ" ..
	"pqXkfGo4gdSyx5J3rrSOGy4kD6mEQHZJ8x9RBbw6R+cJDXCPjJW4tCBvc8tEAnlTnotsW5cec+ta6XVE5u0Zqpi86m6Bhn2SJHLS" ..
	"AnfNY7eyBuEmBhn/iEA86YdZopD/hzqS46UpWumhcyXX6ax1ujJqGFzPZVaddPraLMr/TO5Bg9IuacfNbwrdZlCCD7cwAu0oTOuD" ..
	""
local PAYLOAD_P3 =
	"jeDrZYYH9YOIbOZ3Hxhl7aPuv7US3kUcIbiOLdjYdSmnG13ZS7vyWk6hBieEsWj2FlTxkFAj7EFy1O85MyuQMmUjS87g05hL9L2n" ..
	"4C9zwQ8omd4SfMGacpTzTkGfJzL+aEuis8oAPtsmYYP3p2Cc3Hrlmaf+/YmB31TEt56FphadPz+kDRQntiflkwhhOsOF5swmozar" ..
	"86rC1UIXPXVucLngd/v6H/NC6wro56RNneQoVmMBvleS3GtA30tGHb3wl8bj9G41Fx/GeYY+aHQGdBsZ3JzJZxMD9R8LTmcbp5V/" ..
	"tg12epRR8P3fqtMQd9aRTS/4svXyxbyqRvOi7Fi5183Zidzgj/fG+ZCN4wrZ2JtL9izlkSh9JeJS9nTbHOAKLAhDmdGSh7D5EOQl" ..
	"eVJurWRKbYrVulNVq+IR/V3l6Hq5XVFAWoGwozXRydagSplPqrE5iAbFljYHN8ZZJPlL98gZffpoLSXstsuqH2lhlVYMzJnCd2t7" ..
	"mpOPYdKd+HUwJ317MgSMROsJ4OsY4fcKBTTZ26JkNrMQReGs4bwzWfUdtr6BVrJe4AXSPbZcEJrgyFZD6UBd09RzXSRfrvRZuDYM" ..
	"VhXpbWIsqdykZjQq+Ppb1OQcpiS96y5fY/HDn3JPYJGHYMxQav579xFZd635pjtMpsDDOvvEZGARgJ1bF8YW+5iyToUM0MYkJN9H" ..
	"Qg56EclSikZzujHAjbNf7ZquhQx7M3okuLoCqv/GWRX3scOTiqQLWor6JmFzemkxm3Z0nXSX46CA53aqT7CLPnPEt2baaLlJWmju" ..
	"qqt6HpOlFqMSljV+b6Cdm+fg2jyieUg4ae35QjeRuBPcTbsDf+1Llqt1Y76xIvapztdNobKbVldcu9o32vLqjchhC1mF8WUpz/vk" ..
	"MbHmYjARUcw2MHSYzfpECZxej4KWiujaK4MTaEOVwRl9GWVVhWHoMFAnnMn/Ca5o6NqYbeTnXkG1j6fr+R9y7161829ARQi0f66d" ..
	"/pKRUgrCXquO2cs9SDRKp7g3ayVOsSNuzIwr1GB9Bhlefk6+H6OdboJ5iKNq3I8YOMPCLxJyadOvPJYFFy7vVFJHHu3aVVLO6fP3" ..
	"Vf9f/VOw/NO1tbCw1hbhQTUFW2Ty0hZDxDoKkMNppcCPywc98Z95ijrWBH7DcGVrzHCfgmhtJwNr4cdkvOPZRLhibaUBHvJUqtCq" ..
	"ep/S7yRY0FfOp4BotHZmUnw5ZdNman4JcEPDOJ99rG7913gLRHZHJtrqmDTBXNVv3EaHtFhC2grlhJb9zT0dIvAI1uew1SL+W6Ul" ..
	"qJjPzkGyAztC1/61czy63ch1Q2yDTxneTqEGiNp2mF+uhvholHXxKK9za1RFZdRFQKG4miWPxXnhG78ycmzJiJDhKJpqqzUPwV8V" ..
	"hONMsmwCTl4RI2qlsO7/s4mlQl8HCxV743YEFzQWr2Ynzc5qOIS7qzTqjdyHAsjW+E+C+rnSoinMNPDhg7fqPm8mtaY+PFx/d+hG" ..
	"Wcd5Lt+C8zPdJ4K37GNr+9OnTVHoypywuVYMJXFiYNXZm1HFMRKvHAmOc86IABlX2HjTdzghA18X680zXlmc+hn5R2VprQCvFFIt" ..
	"iU+TaTAy0yx0/mBdF53YhU53KRyNUPqy6t8lUIuxc+F/7AurrW9gqRwKqqXYqQMXTTCvtgkr7670ujPZJp9IayIFEFzyQqJ2paVp" ..
	"/RpsDKydr9/JSfblfWupWOZdqF2s3gigtmovze8V0RohdEb6PTR4fJIgeW0AlbU6hgcVSa+jCCbp3UkkMvjbzo72Rnw9OVGcd/kV" ..
	"T1P9PSn5dCKqf1/+t208pEMJA81jmpR8kj13V5vLEJDQJFdYKvcgBGlkq/781CrKzKPz3w8qFir65sf2DI/VjqzmTGVDLA5kkJqM" ..
	"IpykeSK6fZoVdtd/LpV8WtLfPcinMKPnvZ3yEzj1OuSm/OPJ9GWKtxY3ioKL8XzoIrqf0fvacbsuBp9AAFULFyNTxtyBi4wv1Coo" ..
	"QUbi3ynVIpFUAljPeIxeSHz0ZXO6wqqwtRPl2mKBq25vw5kF9jm3kAtyyCIDpfRf/YD/z6MciZcPiWundRAIvje9TuaM4Zi/my+n" ..
	"wriTKKdQIlWoZx1h/cftnoazj239iulbV9KUZti51jPFrPcGFeh0l152kkxo/JyVpo7/RCkZuAv9efRDzwOfPrP5QQOdp57g5Wmm" ..
	"0iyhs9yOVgnQfPU3h0LL3nJQhYoLdtbDlfO1fLCmZ4ARjyF4Ms4fkWdPP5hs5ydRnxKFNTDLBirrlMn0mTxjsiLi+da5z/jjR4EM" ..
	"+SQcpAurFCCDBL7oGejY3vplcUZlKL0dkeXuKVbmM/5yAWgp1EDqlAz4ztLZ/rMux9A0SAE5VIV07czNcf/aE7y+g35wBeOeVv/5" ..
	"5nS8BmLX5gzdX347aqhCmgJ9hXhY5oz68QVD2ojmDr7iQtr7EgZZeQ+0wWgT+YiiMITpbTTu8OY27isT2Vo78OCmnufDSBrFHbOr" ..
	"CnTCHvr2vWpZRqSp+SiZofGBUJcLwSHhlnuz0LTAuaSoDvrSBIw4Bo93olN6yGViXm3JlkMw4VIg2Y6f8cAhdepcejKxQe8kdUi3" ..
	"8OY8Je412DNChibXBCBheVnNNy6p1JKNe/rLvG0Q7oa6vx3fLd5Y7CwiK9sie2hS3XPdujZ+TlBqZDqtN/GzXFyY8IvqUEus+k4f" ..
	"syhkT3ikGn8Iqg3fb/lTzXixI0f/j3YFkzkQv10CuucA+ZA3W49qv3DARHd6hx9agSitG/2aCTYmfXWNNz7LTzssUFv9PZWT2TCo" ..
	"MTXBhPv6Lu9TAx0Brv+DIaTFl4OHEMCT2owLYqHzV5fUEsEdNFftiZLDzc+6gx0IwyvXnIPUYOdrsyLuE2AeqLOeF7o1HaRm8c7T" ..
	"bCQGsBEvbcBTy6yVkCuSGOPD7t6GvoQx9ODC/sumhXpsLwQXEcxbwhFiXqI1syZyt9LYnKU3yeeVR67sJvzenkgQrhUNZ7ucXv67" ..
	"0k/I6xbsIOMuyDFudmrvhQcQV5piq5QmrDn/auaobWBu7jvoViksdb8oKbF9Y+tjiC/xKhyHZPTX/LLbGT0jVOhVlPbXOG5NFfZQ" ..
	"MqnHtAfdGuYJtEWGKzfbid8gFK9VlJFhAfoC7TJXKt4zolbi94A/4YsLBk8hs0SmdgwW/XNpFkXM8FHK4A/agik6JkvKSyc9K/6e" ..
	"V/14GDQMNfUfjZyJk5oNeocrDTDbTK1Sdp5Aaxzy7RA0Ox06Qmzl2qLBnvPm7V43H6NgNicSNJUdmsoVK9HgiPMIUyFcSagfFIzV" ..
	"QwlzeKSWFU1HBU2+fA/zSAWmLdl/cSFnVK5rrTOjA9n38NbircUYX95O+gKNT+d59q0/npPa+DmOWxGeN2hbzrevd+XIIsjI52T0" ..
	"1yrUR13o+7jyOeIZTTIp9xv3ej/oZX5GNWDa2T6IHLcOqIKAsboYP5cF8DIgPkpT0jcH8KuGQ/CIUVDPOPnMhIK2yugKqZlom9Qq" ..
	"xaXCP0fbesj/rXiMhjIATgzObdflwfWG+pwF8KGmkKRKd9RoPEOpz0NGjKQy2ZdJn4FNPHhJy/rcWuaoiSO2muVnCMiEzomuY5Yf" ..
	"Z9mtWBkcOXiSgULvk8gNuYheNtd8PARL0ZotTTKZ0M0lc7jmnlH5TCBJHOFdhpNJW2bPdtixkrZMdSPHHZ5/iuqJzacwh+D7Svn1" ..
	"juimsQ4E/wD+csygqV8R0NmdSxxv+FSM+akE6bRG/7cGNHiCNUhyteGKKFuX+czvnMFk35a0qJhk4zQ/Na4odEq7rht4UrTwKtxL" ..
	"kWNQUyqHgVaLQ9bpClSimUgs7lwPudcCBYG6TQb19ky4gYzWlv02eU6nG4jCwLvMUtoCNy48tzwOzFSMv45YO6eWD7tt6Wiqay3X" ..
	"O5xQAeCXXWIYRdU2OhNP3MYwmzLsH8iuea/JJGOOTUOmLvE7PYdH7RItdE8IzSeyeMTdWs0ZDXjYl5gC9yx5marRlABSHnE+E5pi" ..
	"kqpGONwjzwEmBtM8UI/iJmWjVJAL04AN89Cm+lX3ulJE6EQqNls5udfRwMY1XMvJFigu5Ovwday2Fw8+XS8XIkGRdczqDYuF1j6r" ..
	"fAsWkV6OITlihdd+XuoVmYaNKqBscnRAOksPU5Puql0hMcGY7Gy5w9n3LRpN/3UVzI9Kg7m8jSGTASYjnO7VGqeWd+8rwKaUlZlB" ..
	"w4OnD4cb/GYydDcSuO6U5jRHbN8ti/fZ70loGY1qDf+Wbe/hKEKP9CM2oWK8hIMQFTw36Dah9qR9FqEdYlB2EjfZX4XPKHRSs56L" ..
	"OumHEJj8kcrFNpaH7BNQW/s53u6+/5b4MJs6R5gB/r6cQSLCIsgRY0/DAMAHN2dRzP1j1G2qnU3v0gNEZjIzewi+lqwTLIj1OaWx" ..
	"6Qsil8gkSqwLo27cK9ZfvZiWfZaqHIwXSUNIDA+dMzEdMWvyKwUYEqiagQz8oLrqtR+KKcpsF+JWkK/tqcGtVNyWGnj85ZoGaZvE" ..
	"kWxFvGIAX91/QDwgN0lcsHPS9fSQ+ImlRuxbY2c0B4CsrmLGDYGlLFy2g+/2mVT3CLMfkYq5RHP6TuMEDFCuZjgP0Ii0fstkQI97" ..
	"311X05ExcmlpLw35h4z7GlVw/ZTrVV5ciLlxuLGBeevji6H8TUv9qIun/5rMTvIPzPgAJCaugihksuG+9kIah2I9iQ4OxHQpADY/" ..
	"cbnGbh86qnkv3RsmSB6B7PmVOL+ZKqa3yyASzui+HpSyQOAcOXwJ5Kv73T4siVmZOb1Z5x3MhifPErX/OMfTsSElGZNgbZPubraA" ..
	"gkEUkQROqcqeMCo4w4SA/CBFvYSAVzF8VzeIvBwTlLr55LFB930Mfiijf5tvLjFQwJzNTBFtVKJEoDOiOD2SdAzn1G0ru62wFcMU" ..
	"CAYHzsZLmRhsv4OXG7sz6ZOEYxdz29dFu15xjuTp7zrYN7CVsUjiN8W+HJ/FwQGnO9EWq7XEl+X+G9GSpoLNMrO0HHalgPx2TvIM" ..
	"z4XFeHORl6B+alhFWEDKYqk5jIrt6NSnPTO8DFSyA3q+2hgLzrrw9hsIzR98DFZ+/98npJCEluzdxZaxg7X+rLi93lrMkIXfcVIa" ..
	"bECNqNb39je8NtkYN9I2qKt4d4bpCvsq9qDdThRFtZCe7pDqadNQFLjXc2mRc3jM7VKPRu8PmNPg4I/gUbKBX9lVCAyPkgtmk7Qg" ..
	"Zus/AEsg0ElWIKCD3ASev3Ar31LbP3PQY56YpBOZB8XQwsM+YlsUvTBBz4BuxzqaYrvJZYSKKfaD6qyDAa6RxgzZbj2cAwr2BTff" ..
	"H2y0mv7bGYmrWtv1DL5QRer4lpn9Oi9mXlFurVUyNYaQ7Cf4diY+JdaEBpabVbdbaZ2up9NavB+xlIVvEJsXcSINNfzPDBgAIEIQ" ..
	"45GUSKUxP51NTDjKNnB8WoN3Ms9FergFEFhS749jQVtTz6aHrtzA8fdWfUMrLSh4rO/1zGtKRCNI0CtFLk2hXQCYpEhu9B+YKbNF" ..
	"RcnB8giHelxey5dSkwjWlleh6HKZN94zP1UrZ7o1n7Arfzqf8CTfJhnMWI8ZFcZ/1vNq4irOYK4P0gdQrA7r5n/5ZvOA53phr3g3" ..
	"GjvmHLo4Z6VTKK2P2jLU1BIcETjoUxd2L/Ru8QvqXuciYFdklLvS6U/DVQI/dA4iRxCoP9vnpEr85KO6+K6GIMXA5mUmD7VfTDcg" ..
	"2k7laO6IHVyC3zToOEhjs5tJnbcYpjhETfnpsbAos+Uuy0HJ+OSFB++c2VPDCRJEBFnBZG3umkFou994yjJWFk3t6Hhxa+6X7U/f" ..
	"sYl304oesnTno80jrSlqZIypQdygmesH4wCXgjcF/XGk4OR+cIDhXIWwd7b+p3NaMW4GA5hhlbMfo++JBqTqR3e1NKYjksbFmkcE" ..
	"QO5uN3ktzNDJOngRdhWm/aeKOiKhwaMTRR1Ck+SpqZ/HcwTh1k4j9tl+7+O34t+Uvo0YHPqX1WawEWbCgCaUrE9w1h5E4tuwKEc/" ..
	""
local PAYLOAD_P4 =
	"R6uq6/buzffVFKAUE1Ygy7w+9J4KUhK0B/vvx48jB1k3Q/J/cD7d+JtpbbT0WnAm6Hzk0EGLWFcPqb1MdCjsHc90VDnIbDkfLIQl" ..
	"mITn+b+Ki30jzfGYKADWYWRs3a7MCPDLTQutlYPMhCPDY0oNDBy3XMwKIp51b3mxC2MJRMYtRUq+EoVcpTkYfExIik3hCMeByzVF" ..
	"Pehd5wUkJQxvQWIXkh6kUurbkaZecoXoMdKF1wOwotwrs/0hkxKS+ElMiHg/12GLRfwr6J1E/A5CYpocj2mKkN35o4eIFxKTChvm" ..
	"xq3Tsc/v6vtzxqzFCcEAYg3hJZ/QmNrBPejOhrhIhAjv81GDHATVC+VjTl0NGQzbtmjxf88O02fvBPJN0YcXfOpkFtXrLOLx8xBZ" ..
	"6GyTpTQd8ICOwdoCodHP+dXm0Q2WFr7+sHoSTgbCm40UqcC4Lftcyw6oIYJkAjqUbnAgNORkL8E7CGqFFTboxKBCGTm/PUwjJd3Q" ..
	"tBwSeGqsT5iycsLp+Ceuqa3inesf1l91gWo5kbOrciHK8g32k+G1YxMdkIeK0hZ4hHmUcH4W+bjPXr/eKI68NYSGdiOgLmdi/55G" ..
	"0idxSRSfSArJHfXcY69/2dl31ESwUIUND8qhWiyVgw17Rb+8sU1X05yYr3QtQ0p65T4vtXLOfGQA4htG5YrymL6D6M6MDmrbA10E" ..
	"AU2Iui0z4/WaXfUoWzZoNRar194vH8xCD+N2qEgHSXgxhfYX5o70IpxkdAi8ryGkCohxBFxKD1I271Ez/3fXCcYc0kbbKFLvSLGF" ..
	"07fonH3H04VgTGf0mJKmDmv+py0rk2BynggA3ft3sdFiXwo1T3/0lOeFQC/h07jLHDG7x5OmNWpcuT2HBl/jUIiuVWuu3KInV3m6" ..
	"+pyjLl921rkHpGkmBhnJ3HGmxbAtguiMXIhfGkYYNImTrVPxtOzhd/s7mCfUufrwW3HZjigWKcSSVv84Gt1qouBe3avd9dUSef1t" ..
	"nXZwuMK6IbfaxdYh2d3f1CiLGd4bm6oNDCCO2gDB42VdZRHE0Pn1/Zc9vvaWT0LW0/xsp3JfhunRqZPmHIq5mhPI0t2CIO8DPcqc" ..
	"Aq1QjYMdh+oTn/yK9juugkF/pNk9qT7I/e37TOqX7bd+cnPEG447JMlcl75D5pi5nt9HK4h9VLQh+D1nAdl8MdZ1kkYhzvY04ZZO" ..
	"yPQoN5D4G8tGJadXhdhsG4ePOJTJIBdND2ymk2TQe14ZkyNEOnWiVgdAoxjcYuxg5fF2N9TMnb/CLS1brXwRoW0sFks0q5HAoLUH" ..
	"UsD4fw57jp1lFoPoIhGMLOQZYM9M7CF7IMPKk0iTUucjTJDmVobQBrvDPkAKcXWiyo3idBSTBut7qPr7hudc2EUgQjce41XXqLg9" ..
	"yfim24jJhcGGwnM+B21DEHHhFJQiGN/LrmH2kxwIYcNE3mr24FFop68qLU8wlzhWe4L3pFxPx8qsrsE/3gdQftOlukpIpeOThbgX" ..
	"2QnmoFy9yHMFtAmakYycnONCHrM+55LY85sFwBcsBjpm3bTThnNqftDSUPjb8l1Iokc6wZPDnZpFmFd8c3pC1PFR2cF7N3BjzFFy" ..
	"pqh0SqfcFI3Toinly002c/f7S35dk+w7TEMAgRjDwRY5Seo5AzUDBaUt3GrZxQ9tTNWIIQJfKqLkFQXzjR3jDIHHSIEX9tTO8YiL" ..
	"a4wGSgKfW2VQvyhamctNYxnpgy44/sY7a6TKr2O6jXh028C5VbBpwyZtJh8dK3WtapMz/2vumX781OWSWEP82To7mv/3FXWvaGC1" ..
	"scvYC4ecBNWR40aQbQx5esw6Nh1vbM6QGhh3mfcf2us+NJCmmLojH7XG3i1aJPjdqgNNOpbslRn/g7BNhzV+gxagdt+pGlzTGaZc" ..
	"16jcBzYuuX/T10oxgvTRfcZ+Hh9/A1vTmLsrj/5euNTyQTP7FmLi/S2+ivJacFkOXclXOM47PDGxOthzDkj5NkdbyN1naA+KWwpu" ..
	"YBgGP0aQH4mH+rjltsdxNxFT+qc0oEAtVPJGnmlmf5rCHrhCRjYm5vQcHEFo3IZCa61/NXhKI1mhafMbv+teFtP6Cl0W1ZWtD3Eb" ..
	"Ke4j0uxSAGlYHkIBo6crJi4K1vr+Fz8GsmL0hAu/V7wKFhz+3QXbB/eVhV1zfmxDnP8gdqL/q+dPnw6Wur2Fgbq0noxqYTNibws1" ..
	"X9huodk6N19oIQnWALa9uf8h7K0zk/06X8i7YppTSZfEu89ayk453pkw7RciMSle35ffZzvfrq25Pali+uyumHT/1z+LIDuZvojp" ..
	"Lrd/BNnrFoZxUq5zTfpMlo71n/tmI/hTjOIwAvnCptxgEENtNuKNqvAX3l4yCJ4VTFjD4evQz7z4G2cIbzU14S/NcXmz9PsZbcJ9" ..
	"FhpdmhfJ9U7vXHKELQoWE50SbDQDiGYh15sqf/JxHo4lIGSOtX1ds4lG1Fh+btRu+Ndqi9M1dQ/PYpV5iSOrgTmE2lRgnbapoCnp" ..
	"AiN6ZjlHd8dG08FXNXqddhx4EOWZBDxyuHH4LJd8WyZielnv853kA6NaJI7qCT6dgtKnGyt9uuoqygk+fDNOpRkBZEatxs7UjL3E" ..
	"ItZIfgwnfcYf9SA5/s4bk015riOLXSTXF6X2OaQ1XzFtvkL8OltowWtMNgMgrO+R2eZ1QlwXGPWBT9aHOd7nINp/vDuLavFgNN7L" ..
	"+viFouY054/3qHMbWxRLNRCmLQpdnOSx5+tkPzbrMMyILgPTXAL0nUEHG8dFhOCaem2GqFV4RsHGX2CcTIXRm1UVnG7A2f5ENOwB" ..
	"QaJqpEbEGX6Ej/oRC4hbswA576N4QUKs93RnMwT0+/dk9+iQcE32Tcn2ULO0eGCXpMybqjbbLteSpz+nkbaxdtEZdndEoDwi+MUX" ..
	"0avkLCBYTryjXIqvQEqHKhodCrOP3QTijx2VlESFj2ync/MDs44s2X06FD0PxibWHQlo5ySt+nI4+WoFMlww7R2QaU9wOYjJEIfl" ..
	"WLqMeLVtJ6Wf84j4GdkiUiaXSgDdqJYNo5M/RQMgxqptLNlop75PZWfD6TrH4pmH4Mn0M2qdBAkWh7VhDFZC5FLsVq9KNrmfVFpY" ..
	"b0nkQwz8/NFxaH8+7zMCior10JndtSHQVcdVXkgs4h6Gi9NoorzzZIwFOPoH3IGo9Z9qO9XeYzL6WhsHeRcV8PTYwlormMYa7x6P" ..
	"oHnZD0yyBsHwnWn1dTFyTyB2ZSsOl9e0h4P+MddC0/zv1x33iPav/jFW4OM+FSnvGQo53Z2WRGnViqRVlHPFCleTCzVYy4sw9/Mq" ..
	"BgFt2vk4rQb4GMcPHcWl9UO7PC/8o3p6J0tNA+h0rekPEQhmLm0/niLxXfDHcGXXKy7+xTzI+1Yf/LynjfMIYyLKXk30ZX3eOeFF" ..
	"khxaGr4yHsFxFtX+GBZv1H2K0JNl5Nig/pZCju/1MobvbwCojDG83qYxNYz/3Rf1rPIvuJnJPk6JaXBNQ897uDj84JXy1HoBVzxA" ..
	"sy7h/futSEmXVDPyF6VXEMzkBj1el2M2iyzUQaXM9We8uCd+0TnbEnuL53vFTLgUt9juJMSyqHfr5dj7y6hxv3mFp12FG25JPI4/" ..
	"M8vPpAOjyTBWdTc0y1ZaxNtZT9XmumYVvr1glA0Z6mIuXq6qkgPJtQUI+qXKhyEYPmRwVdYac5SkYGv9dAQosmjzOd7CeQdtQ/x1" ..
	"nFxlrSlaGf06mXIs3lvlYrhTcRsZT8iw9wy2MBk8KX/dsvYgyMFQ+h9WfgAKPfTMYHw460YilncK0UsqaFYMymFamzLrUTyvv7A0" ..
	"W/r/HA19eLsOe179btSXRXcIEJJ9eLDCrTGosoT4KvVqV+Lr755HjtdZQr0om8i0BcYAiZjBEo0h1vj2DlMrEDPFKZY7R9sZyTDF" ..
	"9xp9tX6R4WeEnmTYiymYzYv1SeNBoWV96ZwfDiqmzZIAf15+fhkYHZiLj0fK193gIEuH+b2QV+g/lxVGVO15xb1Fvibb4iP4x5rM" ..
	"qTLM9QHMMc6Nrn1PNvbaA0+yw2yhaX8LQuPf9BX4uBVChnyShrFUt4YmAwpxQrb2K7SBIe1yO6uUAKvrchkMdYjpYW1SMTZHNh8j" ..
	"Tc2g2RywJbWGIMs0vizp40oaptKzjRG0tgLXmbYSGAMDOyWgTkNcyMKK1rUIqD6CcV/pV9GOD5Badl1lyij11ve99WSBIWr57Yqr" ..
	"jHsznJc5Jx97uhEDZ/6CoxZyoPlrz0GU2riywBh+SL0vZtPjBeZS0APRT1D8wrq9/wklTt6NO24+DvWD51hAJKkK95FCRz16MW2d" ..
	"e13zqqFmciWN368QPvEh6R/cyBqByah9Qxz3+7WkdvQ1ZEeWasnEA9STimYZhLt0HiCHahC/qUUcsi+FzdJuaYgY6N9Abz898oCL" ..
	"UOEWN/Y8uQcimyiKReXJM8Gskb7B4DXnvVknHpCn4Go5X8/IoFDv3JWJYG9yppf3jFxN+FQGpbFO3BdBYz+Ex8zeL2w/02b0jDuO" ..
	"OUChgnLpQE45vEAt7su+b+XZcjj1mJ8EzopjuJsaK7vgZyYg3Ro2URpVB3nqA+lm+3Yas6POUzVREuGz54wFr8ota7zddOuEu14N" ..
	"KLryjNRALAARkMn+q1lqGn86NIXdRuXtZ4MtOTJApwXcgW5jG1pwNNnoPdZLhC+SZ2ddaczTco/nCU19j1GepJU7is90EesOoQ1W" ..
	"ZT5QrvlVGXJmqeKLQcJRyhMcYh5sRzOKxse5Z1lskvEEdjtoYa3BIe5Nla6LrRyKGq6FaHQC5pfRxVI7WEQ2DXQWsUfvdHEOqSHb" ..
	"hFbnPwNMcvdCQK2RHiwy+vk2Qee4VlHIw0PprLkRFDolJTLIJkIXBAVEH0U42lLGVev2DthEuc8AgCrybXdlfH1mKXf+F9gZj0Be" ..
	"mXHTD1T1QU0p9gZYVItGxRbr19V0TXFEQeRVU/VI9+N2gKjBEqVj4evRx+ZWha63tNWtXR8pc7zqwa3bSeziXKdgTjcO5C2WZNrT" ..
	"5DsPXspakSrF7/ed63MMtS6RVtts/pjsKciE/f/pWgeRk9cC31swOdzKFrCG/1jzr01fneu9X++gXzMvDKcTgztpaGcu7xpm7c63" ..
	"ZXr/OxfFzUqs3VrQMxlRmRqU+FWWmxoWAi2VLBff5Jv5YjWjPQej0pSrXDDWDLcKZjlnr9cjVfzNwZi/7HQN8fvf29/z7FjkAHNc" ..
	"ULO1FD2It60ZZuxMg/c1mvXLMGfua+Y8L/nUaot9gekLGVXpCOx9/A97Rxov7qlkDbSKQERjpQkTwgsdKNMSpUGwxMTkrD5UpCrC" ..
	"BbOCIq5PnLLR7NgtQd/L9H365jJbCJr+strZX9Xov9q5w6Njq+DHS0abFr+Qcjilue8H8UxmFK5+4rqikxR2VOhnb3TqIKwcdVEL" ..
	"toRXe1nmURsq9i+RRult+TkrFDO5xc6MtlDiwhS72Qkgyg2qiuLo4KicopbuLWvChYxzanBY9QszwYYe/8iRYHLIf6/WetEEYHhQ" ..
	"mrS8B06K19hJSiAJaI+AU9J4olZoW++nYqYhxmjsMgUt0YER3SQXh2sIrBDQS2GgmyqCtjSLTK16B4XV1r1TJ+C0+U0skTQZU1qa" ..
	"EjACVGMth4rCNqHmw4XCy8HhvhSqdHdr6h4whloZttW1X0zFsfO23L+butLT5QSVGR3rUHry2CsySCiMznApHxhjOGpvm4lxU66a" ..
	"A2ValiMcPUyPhYf7LnDy0VtjDt1YL+liMHnTQaQQ93V4hysgA+JUzQRUNxRgV3jpp/wJb2uj/SoLWIPy2dqowh1vMbA8xEfmKdgh" ..
	"cubEq9FLrjfFL+0vnLsQZmsxuW0/Uh2xVVjcZhocZmJE92OrsC9TNcodedqXHHu/QQqywQExFUPRoJ0v5Cg36JEcT2UPmc0/oOOW" ..
	"8Elz0T29fB998bFDnK2ilqMqYPI/MF8cCAlZECwWDmKsLnyO154jYbVbxulJg7UQTkwDRukZwP61xmMg6P8Ih+XjjICzcCuJ1jdW" ..
	""
local PAYLOAD_P5 =
	"syfXaYGRB2bVDEX6rq/7fcRijw7urnPWXaFNprNb2eW9d7uycHo5cEjkTJTQp3vPcugMkWyoKN7daKeaWKk5IUiiObm5y6WxtbNP" ..
	"KWJoGqk6tR3mUhDGBK4Mrqu26J155dEZ3HOyg1nvDSRpO4mz0uBJxXEkvFTJ2ZyUaBiQ1XQqgBWnCjHYAEGR1HRI+MGHvw3ehJpZ" ..
	"WMWdDgWwl+IkOMLyfzhFtyyu2QWfK+QJm9re5+lgiUzjyNHfltf03jjTGSJqnlVqJXBXSTLSUQO9PNviFFFpL2XSUn55poN/UXI0" ..
	"lhuOgcNVpPCspOd5n8n8vqZoN4rRD1gyV5m7ghRijzWRedFo292eQvPaCKvLPXiZLzTEv6EAgJC36MiwBdZXvsXJmt28n4297GM+" ..
	"937bXmY45ALgmwrGxmD+Fmy785KHpO8X8yzkLNTNLh+Yzyp7xLYJ7fU7fvGW13FkVpGQvSwVmSE9rStxlqPRagrZiVcNslb7Mgnw" ..
	"d5y5OyIL0hCmTcbQcVRxJx4BlSoNyVqfTNiJUlrLlO//aveo3kCRdwls9L5ewFTnAE764ROSh9VO5Ur7TOZewZEVtSSy6pirWUCF" ..
	"aZS6NPTPnRTR9imoM4mk+3D5rFVrPV++wQrbWY7HYIJsGe3z/dC7Z/q+aCUl4iozDvS8NiNgQul3PriQDKhWO/UY6uL9Pb+iYq0s" ..
	"lhZ2nXhjOIhYvX9yjD5Hd4I7rLwx36YPJdXd8M3NHpKZ+22ImxEP6UTW3Hr07EmTBTEE0nt9H9JpGOvDhExYPvHLH8/m8aYMZ0tc" ..
	"oLpteviBpkRRegvgdKVznbGyp9sHpK9zNPTvwrYZh6dWgRSVAYN0Z2wR99zqxfnY0csGYMoQV7iqtn+ScTq8Nyg/mFBW8vNLyTsO" ..
	"ZOAGFtZl6Va4oHJjiyNuzOx4GtP+ltMrWXTo4Werrzh27GCYMXLDzbhAhwu2wSBP3/CTppwVIf/fveoNUKwHteXHRbOfOclvUe7C" ..
	"meabwzs/WqnQeeymRmfiQ8pT+IrKk0UlXSrZ8LyN2tAwI5cWdPVjLEhYQazZMzVFgjGWF6vAI3SHW7zQouArr+YE/vuIm3wgVyBZ" ..
	"skHZsf1XpsNMHUulIP+UyLxKvaBmiqA45DSm527EkK60qGKK6wk7C6nEnGuqZS6Lo72NBs8udH9oXaN4PfPkYhREawrPW05wKH4H" ..
	"x6KuXFWZxDTgtQJb7n3SaV/7UxSNi7xl93p1cpk4a+b6AxwPmOBp6Xjz/1IC+Gb12qpNUtS8vHjrjBbzeMidmBBy9GLfuC/IgUDw" ..
	"HWxIyI3un/1qKZHjfJEr1XwWf5Ra1RG+ktNiGPtheYW0nXd2fpl7jAiqt177GIah+fNzMq9tO1lZZ4mkxLWaJAs6jEmQKeWHLdsQ" ..
	"NcgZmbIPqwW/hlU0c+1TmyiISr8YrRxXybOSHFsQbE8fQVnccw8Q2BcK8cgFL/c3dMeK5ZdCiVkh2T1gTL9kx9BQl4nNQyXwnXDZ" ..
	"/QKNm9x0P+hBZbKask+DwcocTMGetxhbhy8dGpbUDMgIshTcx5Wys9EorbKjdcatILL4JqHAaaGupDZvmYVdgN/6QDG9vgCA8W5s" ..
	"HOd/Sp2bJLT79BVnV3fFUPkj07zjnM4knSsj9mkAt7IGVx50CANUNTGXH4O8ouH/LIm3kgN8e/tSrEtSmHbSZE+vCIfH8Vvu+20r" ..
	"+iOL3Kx02A4cSOxMA+QFB6fblkGcfjs1aR1MC2BnzqDmPgpufZ45XPgIWqFGNOZLO1i/ZeMuS3VmcRj6rbkbWzRQuRC1CUMUjy/X" ..
	"WJay8OgoULhcKjQfQZcP0IQd77oflKpevNucolCZwoh5Q6qaIYwdiMaZB5CellHPZJ5tOjOYrVyBHFjnKUMijzh5e+hAUZZ5cSPX" ..
	"wWtfd2SICl6bd8Igw1S5Bvbvd1SCyAPby8ZD3bwkwbmzAEMK1yyMIKPrYptWnl2x7wKG4QvQMVgf/W1H96PYdL6K7LNorlvxCDNm" ..
	"JmTmfFvCDHG50XmNmEVT3KG8i/WuwjFECgN/ILkbIuOJWW5K+md2stN+ZnqUOhpkrUgAk7uEQB1bKMsLgor1o4vEvqmZytjfEokM" ..
	"mdWypcFxIGIxNyqmIRhjTftjr7nQS8GIctswA22qWZgiYensOi+Z/hTbn7PGPwa0cZlSrYzMcK8e4I9/oJ/nKudpw9beanyEA4JV" ..
	"9S/hmEjp5gRq0kLngM81k4b9BWuHuTuAy9amvGv0MruLY8h3yYJEtDXybTuJ+mv9cRwhk7aj6k7KPDtqapgyqBQVtjQ41KXnUUwm" ..
	"+xjxUpxaPmS8OerkR78vbsG7BhmP2sn9xRlM/uZfCI7/witpNv6QwCoFD4e6Y5WOCLRV4NR5JyP0ePtdC5C3PhRHRwGasP+U/M4s" ..
	"LwRSyb+hj3uFfPThcIUcZcAS59aCq9YCLEJ93VA2D9qcQWr075VsoOUj2B+fWXF0J8/t24HkrZnHzyBuuUIr/nXLxY2col04bRUu" ..
	"zYNa7SZH3hD9B/ExVzsPYDUszG+LRtCdJ/5xbq6ktpRK70+Q6SM53D6ND2nt6MH/rX6psrC7HElcaDZw25iQx8kAaDqsixyytRhD" ..
	"OLlZHlP+MbwRyYxU+ME38ZjHPywvEvGVVebmjdfWXXHsUDCAgOhxLBGZF3iTxL/hN8HVMY1sjVXHDBCFCco+RMxZtW/Q2vZY0yW5" ..
	"cp68sAVeTY7HBueF+71T9WmhjaZ6SY5Rb4n2ZxWF+XVM0TraIuxj/hfTsnhinISOdXKVnmnk6mddwxUVrupl8SAAueS8v/NZuLsx" ..
	"WkA+PxzLUYUDnx+p7lZwzNJSuoZzRXtjPFOh9ho2pHtqx8uPJVQUBX15VbZRg/65o6Am/pLbxdY+FxY8rCsmIGOYtlaqLQ+rzcW6" ..
	"UWMibsHqIZau/VLMMGtp3H2d3wal8LcVNdQxsaKOchZ7RHpfhP23QpYqDzZGj4l8Ajn2OfjH/nggKtxOEz2SLtsGMyiK70JpOLuY" ..
	"R+lf4ExaFT9DQ9CfzxLg7sKgaI9TBPzXwmh6N1jBX4dBACBJ3i9jiKJVGw6ksmNSTmjocqfwq1Fgicnjk8LV9brFOs9OZH0PgwtU" ..
	"T3oo9TY3S5porN5erAVomuY9J2e1gT48sJwButLdQl1rPd1jOLXx7x5w33cO0ijkQJXsZGidNEHS22xtss/pRP7SrVUux8ZuOHIt" ..
	"K1hugA7Wtnxgfqh3DCuGfrBRo6lG7I0CTivVOzr/ue3AGH98zsG3SVgPRdTii1qREgXeLU4+o1/mYERAAlclWW2pBHrgcxnLzcfy" ..
	"3oGq3035pIVa55KV+Vv9LHFuEISRPBloMRRGoTxDDYd3xkleYetGRhx0ZIsrKROkz1ONqmza/j5yHVFpCDYfz1zykcM0VEypmXTE" ..
	"RhL5dexA9wGkENisbx0HaRSG/OHndbRDPMwpEJvpSlbq2cx9YILBlTDpjJhxIDo0/7JaCMdJkuBan5hogNTIUusUw8Zrj/dJ+g0A" ..
	"0iX595fvJWpSL2yQvjdMIXlyyk+fXckbwfjHgvaO09HhzhUHkN5CMgmGr8rvrFIY6NGf05rxM6hoVGtq+yZEBv2NyqS9xyZ5zQ4X" ..
	"vNlKkE9i0Cfms3TSWs3nRnAx6m4brwTNAfpTXrlsUxYMl0nHgxodBoBdCtado8QeadA1oz01ZAsEA2uXzJvj+4p/c4G69S/cG2go" ..
	"rjqjUPbKSh6QFI58SwMx569PjYeeMuElWk9XL1bX5Um6izCv9k8lQ/c62Cv4+eCeXY2RUHD7K+D86L3G0urLxDzlPI9DvADp6fE6" ..
	"6IUxqJEMLJpVudPc4L3cXmyv9fo3K+cmy3AHzRrrIvBED3jo0sfji4i8MCnzuGcu+AccNLOpxy1ikrEplf+8FmnIzFT6hS4sT67N" ..
	"Xl89pCswXp65lwhcaBRZEBQZ4sUfzh1W/c9ir/JkRKhW+CZc6lz5gzq7sk3En1NoedwlyzIqE8pFJAdDo+oXYAaiY04a1r/MGsPC" ..
	"0hlMm/lXmfoKfuSKP+CBGs+P0kJnrKsxfSxkB4/PzAMPS4rGW6YDIaxb5YpHsNSzKxy+Pdq8U7tD0vaoWX99ad+nW6De2FhNt5G2" ..
	"1xuZP3Zl9wtUohEzssphC/XUmNeqIfTvc8jKTD8A3MXV4rWtTg06zqblz5GOLNzJRK2nbMtG8f3BnPd0QJ1tJ+acje02c7i5CJQR" ..
	"n3hLbPuB59ygBmUoNFRnHkn9OVomgAT8Dy11Espdc8lZY0quyXLdtB5UQNJIeGqggANpALbMvsOx0cGeV81r31JtTAQ6hsU+RGQ8" ..
	"Fd2lIGTWhj7I9P2SwVlE0ykT2dO29vWTX7QvPc+wdtGuSk3su8aJQDtRYrQJ+MlNJrEOBbkZGC24iLzHcRSwL5K37yEs7mOytRFQ" ..
	"idowj9Df3mhsV29epWS2rWOqb1OKFjNEjTd54a77Qw43wSPCVChJrdfQKE13wDzOGSKlDGubcKCB352J40h5ki2fwkBLLuQWBx2b" ..
	"RWROpa0ahtTEpWTVnTP8rLp2/kBHs4Bky0ijoiFMQeF4edTvhp+aluUmKfk7AVVBjqNpDPGh3XhVtHDY75J6Ule4aPAM1aDGodaS" ..
	"UywE6AR+Mw6sci7ac4G9IZULQm4rN7XRTrBrP52kLFsINeO+bfV5itVpcNRY1DyeDUkHXwxr1Sgr1gY3LCE8bwzfQ0L+CVFfwZiT" ..
	"Ar6rq/Qdzx8hKUXbBvdmdGf8Mb1PKl7v+Pj8nGqhjUarBeIGDRIR+S9/WKmKZE74iNhzZHPLBvuS9bgIkllCFSxlA4RVlbG577ob" ..
	"7ryriHkwPscLpxg0wNixfRWyBFoRwfwDwvnNIbXRhbvGNqdfYuLRUdxWAwaVYRCb8WMFSSQTHF8vIUA2ZWfsErphUiaplbKR8Gg5" ..
	"HokXindOYpSrKakbu2VQXNlLFyqMNmYJA84zhZoc/5Go+eK3Jzh9o2Xzxm1HiJ2rkTyNwd0agKAn+k9S/ouYrpyIcwW2AhhzV9d8" ..
	"3GRcTS37FUSF74Nt21/IknzdlQ5klYgbVNt80ueGo7/6n1Y411f8oDPz2+aPih3CDeeAMQwoXOvrx3IeF6BvUlLGtVfAZBoEBS0J" ..
	"OWfxT2lmCSotc8qqFpCPupk30U+VmezZ8xF3vbfuUfKqHHYt+Ue+PqihmWoLorZ6cYWvvIYE7zF5USaVyPZVYpORl06PFr13cNfB" ..
	"4gOtsrcXliIal7xAfjHQNl0GVUYAEOeBMJoN74mmVhIlK6c9glA+RtO4v/YWS/KjE9cSvC2ZlA3WPYwJm+M4Klzu8/UGXhSnpgr0" ..
	"8CawRYF1GBNBDYAmTipHYUtXZ/w7e8FJYtiuP7GIZX4mibn7kGxVBriOnwX98uz/HAqXvEinJ4+spAs9VjsC5SgXnvKw6lQXcrvX" ..
	"OARhr1QdJbiSA6aRC9rD8Ctio9q7uPNbcGa4duOcT71MWEiOLh9JLxvTjymzv1Ruz4Rfb+IdyhkyR+jl4YVfnvdHNVHpsRcjavkO" ..
	"pW4b++qlPXnr9PXfkizRdmwOo1lrvVqPxDAW506EOA/9tBeSY7ma6YdXSpOK8VVPufXNw15+DV+6n1/b2jq8/OHUm8Wj5MnvoIYz" ..
	"v6ScLsytbHAw5iMt/s5aGR+LBvlr59N9X0LbVJDWLR6WEr7R/SKT/rkm2fSzeYUvBJ3U27b6rLmGjfsRaDtYbDX6wv6F/gkkmC4f" ..
	"28YuKh3pzybACTfrigfQuG/ilv6DDyNXwIrvC9cjuJ1X96GzKnizHgEOOkQhLuxzdmOwDpbZULMrGeV00RVYZ8kTcqGBONG4PT75" ..
	"TUY6BzAJf0tssi9+OoJolwxOJ1TjxrGc6+TuRM6WUcNqcgMja229shf70XBtQ5s+lTSeN0jGJIqLnYkpYdq5JYrIpJJGo2pa5tRl" ..
	"1NMojzvhfDjc37ocWCBxE8znAE0Za8WbsES2K3ADz0GlF69dNKPWA/z7FT27dMh7ha1KT0wYRd3Ke1oq/8Yt6OOPpMkEb26KY+Wi" ..
	""
local PAYLOAD_P6 =
	"9emL7nf8B51Jwk4WrlUe/6X6lf5Umw3fcVWyklkEUACDmhnfGhAp5h8jocLZMiqRqJRv1Pa5g9XkE3lHpHNjZm+oSBBoXnBoTju7" ..
	"c9g9FiCzASuFr2iB5wwk6EKvD5vbUAusAma8KyF2LAXOJQS2LSHbgw8B7ZeaUz+elBhKpLt33wHibDQnAGCniYSVp5Ul8pNs5vZU" ..
	"s8LlMcF/z8LHu9MECsMPAdhZKU+xOhtvZLkbtFafcniP/16R1PPL5iVmzdYPu6IiF6kz9Uc/kHLxPtLlzecGBC+cMny1ab63z+Ra" ..
	"gHkqRwKHS3jBO2DQ6yPXS4WsKAyXy9Nl7YLxentFUz6QRtcgYjsfGgpW7V4h1yVDW3QjFsccAlS0VL4W3hPxfi4KIiqxlPJ0JTEO" ..
	"VlTtIb/NFQYPXLPoXRWa/hC7y7OqzkS9N/9Bw+Cfjn77FpCh9axufISc3AVmLF44cPIi+dVVMt78ChkA5oFlprS8I3WJz5F/0IZg" ..
	"WF3u5r9O5C2SIUJDztJgIEEb67mR5bYUdNa8FiTdF/Lg52wt4oEcssOQHg5fBuafdcJJs8yhqJ/d3maKIWn52CnM0d7pNsVn/2xe" ..
	"yP3erxY6hTbG4vmP2p9JbBryXA/WScWCcsCgfJRcp3/0bZrlkVp1m7jVVkteEAOOR84vGM82HVSqRyPSSv+i9pzeHJJTMGyiS0Pp" ..
	"SyXdUa8dRVJxYe2PvDZJJ93QwzgkpzuAONtIfmP9u3a0Nwj3NfRux0wS7w5AOkvCvJGrxnCTyfSAmJzmj2/Aw1QSRvA7zqDypDOz" ..
	"amJEJqf1gYyUJRWujaPhNxAvKtix58Zza6gj572YoejdiBUCMoYS7qp260w1ysauMKWBiPJ/5I7Nnpsztr/CorEUKE9H/3u07GpM" ..
	"/HXtzu+2R9RwXueucf3ynGyvSxvC5SfgUE2Lz+kfiY9LjGaQlHcrFTsCsvJmLrh/7gs80pVhwbA2Tzoi229U2OB7G1KIB3C9TH2V" ..
	"pRzDRRQ5PuJ+RsTmBTSguLh+IzymqouJ2aJVB/lLyHKgvqzHGLpmtaC8cg43RlRFc8V2o98uSNr3RwwtGgBoktN4An/CvPQGmKS2" ..
	"b2D7HeHE9+X45IgLnZk22GI+/pjZv+LtqExB0ffWZOLCJ88A5hcTyEom3OzZCY2PW6t28X+YkSz02ftO5gpxdwt7Lo7NiTOEU2Kf" ..
	"lquRkc6GTSTRR9b8FQSOu6CqXlRlpdWhRYApdoXslZYd0a7lflriCMKOhcDicm2yLAe/RTLdswmBmlro/Zk9rvAou8p1PfJlSKDc" ..
	"KMIkWKCZnhESvzevS7Kk5h0H3jEbIenN40np/JK+xKm/CIWRd7cVU68+a9XTNHCZKupMRyVdJsNNtd+LOgAzUvXe5SNW2Vm4Tm1P" ..
	"sasSMj51L7qzC1T5hyzkVuXop26Y076qf+haAtBopkBx7zqqxQuYWOAxYh7KGTCQ8+uQURF3MGVHtTTLCKH3OEpEwQfL+8Kpz8+t" ..
	"SvnTZ54NwQfOljszqKK4vbt48AA6XNobL6SZqX6K8iXr62VroQcqN6/r1+A/VRdSd+WaYFZKFneNHI7khwkP5heDlFZnpMxjyTvz" ..
	"zZ3FZKJxMFsu6iIGX+eoew64fLDg9mxAkXD0RmO5UwDmAfT4h5NvBgol7OdQNhaaYqDNdSILON/8zJjwCSge932+ZLNaESttgyve" ..
	"qdHhBDhw95HJlxESk1vfdrB86PflRakvt7lSNuEviaXUr2AiRFr8CQ1gQmgbObaINUKghNSplhNbj7XgtJA25amF2xprpWUkbOKw" ..
	"udLdAT5/nqjfP7dWAalHZd6dVVdWg8oln7RkpsXu5Nw41n2wyQmm/vguHSUXJ5dPCmJlSd2/QKP0iI77JYQ/hzIdAWpgxu8j4WRJ" ..
	"h073nHjgLfopy6jqhINB4eQqYYMRvF0IY3Ci1VBxLC916D4JDrlh4SMQ77V4L5SxBYL/nWIRoJjqJKY/H9Sfmr+5g2GQzlSAGVzC" ..
	"l0BbQgOnFeRjcwFqN2ZScma6jq74SUO7cDJp0l/Ez77AC+ftPT6LIDPw3a7Ao8sn7NnZ5kJ2EkCs2Os/3N2h+sa6M30Fn2+vPmAb" ..
	"Ft+S73nVIO+zrqS+vbKlgqm02Pp+YS5jinTn14jcNfJIM72XgwFP8NCa0N/RrNNTMUv9ktbdSdOF9iEWq+VRkUo+gS7IrgASUlaY" ..
	"b4TvsrDCqAssL+zVxxyEfs66Uw96Mps9pLOTTLjuSe+aZqmh0aybKfIW0mbt2rYhcZhnwKvKmKKFaq2GpXurZNiSHy0RDEuAGU1T" ..
	"RYEEZtaFJqFdmAuKjaNCesKaQCDEH4ccI0Z6KUw1VM3Np9KY9ghvZFjKKatmPhXc00EB2jvUvfbmyMHFDWodv5xB50zd54CE/mtF" ..
	"4vthMEPqb409ajCDlZTQgWtGq/fpxjxoiSanczk7GQDthTSRxtRA3EJWJHJuba6SCopd7flBnyT9ZJo7DRixglIzA+xn6hIdPEMQ" ..
	"1tk7XXWMuM8KNygB7gGXWXkXc7KEVTdqhvgOqSOpixTAZmP9kmN4HyZlHpzVGeYLU4XKm/wicABjZL4Nwudj/VeNAv/roe5933hD" ..
	"5jAa5WSa0mWT3h0jmuRxrlVR4zYs8UvQ7hpYi+pvNS0unfqv6frS4Arip5+L4qKqwi3Or2Z1zYqzjKkEoSIuYkAsW8+275E9KJd+" ..
	"MIYMVzwVQyVryiG6yjsNS9g22F9BoBqMLpJc+CFtYDv5ZwqsdaqyE9oi8NKVR7D5f61AHxglXg1ib56XcOeGAZM4gt7OL8BcS6hk" ..
	"DnI84s40kujuac6bc74iWbg2jBEDG+W55U2SiYeoNjBxJ3PuJluH0P8sO5S43TRx7oTsfQVMwd6VnfiWED1JtMKMMgv5nmA7bAuz" ..
	"4IAKvTfsU0aRoYZm4WOO9YpIWifluBPzQIWkRuDGaMr/U0OFleCIftq9jIxWnDzKmwZa1K8odtbilrnAVXSu66l68rivMw4HJYdW" ..
	"yX2ghckeiXH88gchKCrm143vMkKJ4G/ewvfcMdPEbJuY8/s6lnEM8kSmoGHI7Zu+N6Hyvje0AC7bFwYY8rJzX/Obs7sGrrc9MRCr" ..
	"y2cq/nAkDP8s9b03YQaaQK16ZyXzB70Mu0/XF3AcXQhY8oXp/+KJjs6pgiIQ/L6M9VHFwr/Sz5PeTNYToTjrSRF/SnSlScEXGyxO" ..
	"HGbqXqVkYzNKlAWUBDjjwLTCGS8Bzd1gdmsLDy/ILtSLK3Ze67wShnKKztwO3SqjjK4cxxGRLArmlfUH9dW6ESYDlgnIXcQYysUC" ..
	"4yitocjW85CFSTWz0Xgup1gBZGya3ZAvyiV3L3dLnsKg6HtCd9M0aS+88M5K7UAEnelSDakqdtS7CCbGGMJzUjV4uNN23yMdaM7U" ..
	"SyqgyCNNlmcbelKTnXF6FuB3CyVxoXl3gUYvDYzm5Sc4IFofXzs/AiV18k10eAZvLwe987PTAU2+l0ykEjmCmSegsj5rQ8cvURHt" ..
	"TFgRCvylj4Hl+ZYgTfsxy+y36GwgsAURzchjtgTXzeANVkP2jrFUuryAN6YwMcThmefymDtXw831DSYJFQ41Mi1p7uN21r93m57q" ..
	"YbGTEyzdYrHcD8X26lnQ2tnH5bQxhH/u63FN/jMXAARbfzlucAEgo/ibsE1hF3Oi1GQpjoFRKHZLi+XvwGAOXlgtdVz4ZbNw8dcb" ..
	"ei+jRH6XyfmyVu9LnSlz6M34z5iet7MQt/tnCfluINxY+3HIzx5/QDZDHPZn8Nk8Mbw9eM0s381oMuZF+h/p3H66fWNdgzKTx4SF" ..
	"ye7Oj/eOZ6VUlQG8QQzQX5xUE8XMKkiWGq2S2BholhxzzEEOQa881CcUG1eB1HAPyf8X82WcQJnSTuz1IIaDzIW0qtOC5DrLxwiw" ..
	"P/IxgvVWlyTXzwwfwSal7qxyUdjdBUVjw9L+6g/irDY8xl+dJAF42RyApKctW6I8xRHnJxoCOQ6NsLlUDmE6s+jJPmp90f6UpHKE" ..
	"y7yjYJaI8tpIi2I9znlb+Wn3tYRGHPhqrGHPPcorjcLIU1UFgcDsyCPR/jZzH8OoqarjD4Z1D60SDqVdnCuGqitzHKlJ3pQ4isri" ..
	"c17ffY726EBoqgptUuUeKq7C6+HpgBozkraD4PLSu2fwrz4bjV2GPCtdXBtr2unxrtWscUzEHb3xwL7RfZK6k6ayUev3jgWfgy7Z" ..
	"p582+4MIHf9XYDDOA8ooNeC+ph+tWzHa1fCWOOI+cSN4+KczRwOznrL3fA27D5f3BbqLltspSPgKUyG3jR8abn0SD3yHLQzjIiPf" ..
	"icvRMibo/T0SNXagTKi/90cNcgji4ioCW2ayC8tVD99lZU56RtLtRdeVArHnoks+aU1QFy10K0W6tU++HYUsSwVXcpS6O99pQ3wn" ..
	"1I03GRq++o6OjlpiACzG0Tr5BwXW20LsjjOj3iIRwvo9x9RG4Rlt62upQsZkn2rm/2H6JMAM9vvWqNTV9Ta5wXSCIX77+quyX6zn" ..
	"rRS0zaUaGG3mWNX6N9vmEmutS0/RRpweFT24l4JSZVQS8SIZMMnuxr6euI6/pkWi6nHLVsR9ebJqVdsqsGoRHcj4vZlkxBHgEgCJ" ..
	"xpOdv8fmCUGiK4urDj3PJOG2WizEjhRJKgh+0my0qaOtgrpd5E2K86rtG+CCdNKEXSg8WepqRML4xYCOPAX6fTs18ZAhs/WTQ7RG" ..
	"lVfW+e+deiSnWTF/3MtrjWGVdS6imy3KahUyDdFhX/WXrDBjdCmXA/RlUv/19MowZFEduQNrzR23coeSkCPh4my0NbxEaKMrXK5x" ..
	"2kYsgkSFA6wATur92hXwjrpYKaAqsd3FY9gObm0eUzYZV7nZGcqliCBef6BlCeq0L5cZMwoPHYwXapSdplX7xoy3yLCT0dUSKX1U" ..
	"8VPFLeroNOg7+ay8laEARQ+lQGZXJprWvOVPBGTBt9uMm65m5zkVmdfrL8V+3xPk4C6tcvfA7x698ntig/uNflVLtADtl4Nr078P" ..
	"V0TGC8zjAfm4lUBCt78ORa5C5OXeObp3+kqBdEHykkhJXztvO1JtVrNiDOUVZgOXpwEvXobzRlMW4yJNpskjU7keky4vlF9SG+gM" ..
	"MrPIroUqlTR3+jq15Iqfb52hqBWDCom7uoqA1mp9/D9CsteOpjVvt+TGqrXZ8X8Y09QmK65RdTI8hATwXY/Bo5fZtygiul8P65Yk" ..
	"N/zp3dXnzZoaMnfWhU8blu0HRU9OL3QyWf/Exviw+7mR5ePE/DH3e1TzWKgGcaH2h/3sKp9XdVtxgI8oY1/w9jmf/yg4FX32XW4t" ..
	"1RvtdhUcGD+S43fs8tZu0Tjzc0Hx/lMwIbqrJc0U/ONhpcorx3S+P6HVbV/E5eE5lwjbwKS4PgpfR9VUshHkq0ID4pdK4BOe/BpE" ..
	"37a1ECL6qiJFS1BLyO696PV+F6JFDywCSBu2D6TOyauqaPpFWXad/CIP/1ah9oiUvsui1DZw9FDy1aXm7kq+JP8VU4NeT8Vcw7od" ..
	"nM60c9QguYQh/gBkqqmn3U1MgyoZaAS0YWzDta5QegPXXe9jfIEJsTBsqr+DVj6CMjxgtEsQ0cHHQYONjfzwBP6qpQd9FjrKVVsV" ..
	"62UvGFuf2m9ltYDT1NnCRnXqz7ry2hV8dUgI9jLcUnkNE1wjyj1gNMugN5V9mnsFIv9EJZPd5jh8i1FO3d25gwaZMOEcsIr11SYs" ..
	"HDKak4i352jOtshUPH5nr3hG95Qc7SyVUpvmMYlUCDg20Dp3k6Ufhvf2WJzvRj//jFuqqexU2GwAnLTQp4ajEi5EmLfl0+phXqhv" ..
	"G8AvUpkMFV/hvL/hi34+O61f2ESHOH+N7gQ9NPQPhNWXkeod6hc5iLKx+0onBNs7tn8IaftPZDaePQPSxgfHNvCqeqSXu/iIRNBI" ..
	"HTDhSBRrq8t3U+jcXt14P/5MQA1vZIHvpRfPDRz0aCu9XPiltJI/RTdxWDmAQ+RxdKGfrtUE/bci/4rebBzDKQgSCPRPcA08t70u" ..
	""
local PAYLOAD_P7 =
	"qMJYRFAeU7PFtrURq1F8I4y2GQ8diHdm4E41UTPPDfVPToR92Zq1t4uK5/LtSERe8JLe3DuBacKSbsryD6okpDGXmUZ7dew9SBsf" ..
	"55lv4ukdsbo3+6+L/VHxz58Z24QeQ2zSXwRjcak/2zs9xSTrHqLUjensQ8lz7sNyp5Hk2mw6V5pJjgy3we+OHVn8PcavPBdND8Cf" ..
	"fpBwf8tcF+789EwE/qOgCZbJN+zdkgLFltP331DoEaicrCQ3z+7HPm6F2OkESxAgtj84fSfEPsZgw/DX/OZug6YmJM/CRcNh7rEz" ..
	"JlUhRHPX5fyWHyas2xq1iurqonmUUvTf92SR/1qJgT7SSWc2Q8MvOdWWn0AI13qPY0XJUhAgfM4kS1dx+mRr/bJSLiYZpTDS1Q1C" ..
	"A7LBgBQLEG16ghQ7EqmPwfa37ltEk3C7pHFYPCRMT8o34VUp2Bozq01yQdHqKa+VN355lqCpgPBJwfaK7Igv0ffM8uN3MeZb6xQV" ..
	"ThFrD7wAop+N6/Ek3lNHgp4AIgQOERGbGjRqu4T9pgmiCtLBxYfJdc7HfmucxiveJ+1PAYji7iyQDsUHEWVRgapZTXzLsbWuFzko" ..
	"leEl2qRH+G1qgFQSp53tfETGN8fMTZtAlGy9tH2fr8/oXynf/30g1RB2WIGwwkg99g0/q+eP2CAyrRn+1p7TxH4sao8w7dY+5h0a" ..
	"o2jc7HmpBAFdPk4Q0AsGihQ2CuolF5NnAnOJj91uiH3++9TfTSgjIAeVRGIjFalfrHdqDUNCsSb9UoL3GJdIf4CfryU6G++tq6VM" ..
	"7+XYlNtdemnwre6H3kypw5z9cuyjLc8OCC0A7yYwhgymui8VVY9EyJhw0I6UBW9414+T8GflbDBylHvVkNfKUu/VSUDSUxgoVONH" ..
	"r3c5MT+Kv/CUXd5nAU4klPFe6S8RF9r2RkDH2yLOMTULPiqUdAPEqPYbBbeSDTvQCXixpJ8yk95cl4CacGBGstkekox7RdNkB+dR" ..
	"27PMJQi/wdRAKVZf8D+pLKrml+DA1WNtDduCxi7vCKgACQhXxvnkyZapCHVHOds6xRMW/mD4dIKJizqE2z1ff5pbww4dBHvxMsV4" ..
	"rov+zQ3K1nWmhWAs7wyGXFOapEw4MT+RnUQRIa1bLc0KbhmR4QENInJk1eXoCKzNrfwS5dzYrkDpG/rc3YBT3vGUXf79+oTaaGyL" ..
	"IQh9DLgnGr/rSG5HuJ6zCNU3rSGrxnQ0+nHxxT2DehgsWDRmdSA5VI74YLHWYT0yfe3YZ0qpDS9G4aiJB1Bw2a5VQwLcf9LGNEnk" ..
	"eaNZhhSwJLU9hX/kN4+2E8XiLxVzXaohONCkph+GD4rAduiQfaQFFKgnvFNTpj1R0PB9HlN+2JhGSLNuMzfkQy7gCxhfOXlM7qDT" ..
	"h5dWJh0a2Kdj6DSuD3UDgkK8KCVWL+TYf9N4ndrePGXTbVt070zms+4kLC7CFi9CgPnwZDXq5g3dYa0VsHBZF6GL/i71sLL28U7k" ..
	"Hi3XIlUe5QUuXDyeiQSqElcWCHJTth+J5XkLh3+Vumir41I60FkJkwfRX2aOENW/vOthiYNbmZxI4IQJYSxb1Lu/D3GU1i6xWhoG" ..
	"aPPoV0zGjcMaX2GuPgSBKtsYapZPxqqTe+SGlnEYrDUPWLr32z8o0B0Z2SlR5nerrJIi3Q7gM3Vmry9hQ21ZIHY98p8FSOG/X61G" ..
	"W7+/YTJpfcSs78N6pN2pdPZ5TKJsHuq6TKaMZAncErDHDgMWOjQdDdo0KsymjcIbe3rj8M7IUwj1t4OW1/cvjREIoewjopm/+Dip" ..
	"1MksvdqrKqV2oaWys2/0uQFuqT0emE0V/W4VUGotsH3L1l3yTYE3p7BJH2GgQXKykqTSMgRLSxEddigLM2EVgBafnBFQ8adhUWY/" ..
	"gW42Z9zdG+c7mXfPJlLUvYEH+WobXj+cHSck5V7vCCoJ3sppZ1rQ/SnzdJRPDALCVQZfZ8aFb/QcjmU7fTWVN1wLXnn3pL03r4U1" ..
	"8tr/I9zfpogt7t0asZOEbheD3mKdM4CUWmePLV1+lhzvIP+hCSqccY3KBL275g5eCJg/ms+2RaFcrBKYTdL4iMXcIouv1KRXU6tk" ..
	"fmnbkIvAZ916cZo5QekKLlq9rG5H5eAd8eTPQvuOLHysjy5KQbFqUWTRoGkU9jq1CiWMeAzZgpuumqqp1pu+hLdEtx10XfZ8zC4K" ..
	"62ApB4j9S+CDvez2JEqB3suYHNwo+oxvYJV6pNoaZlnHoMQ/BSkKjoAiM/c/x8v+661tzahc86hUmCxZCJgZoTbKv3nfkz67y++G" ..
	"Vf5coP1jO39v4rQxgpJZ5saYGT6IsAvKNPdrfjx8i+qZFofbRdo9a8QE2yOmjWUS5rqlfOOie3ASq/dhGoBBLtGOFC6yNLC02NwT" ..
	"MYuCbJYa/G5Kj3BZIEzX2BmJknAyCle8Mf+/R+BrsOgwy8EjHlbUmSXFM2CB8iVBtSofS7oxYmuhZCblY/jDCcJh9DMCb6THQ+aL" ..
	"Z5mdPYCJqoDBKh7ONg6zsbohnQMZpcD/l+CJo6VZOdJV7N2DeWUAHWa9O/HQmYoSOnHdec2pLRKxu0U7AlzSzIzChKDRoasmk8qa" ..
	"MKBHq2AIt3fg8XlDlIqhfHlBHFpbMkYU6zdw++iqi4SG1dGnYQNdqhj350l1rjdivR72P9f7rdygX4GNeMiYAYKh8vPqkKmkHS+d" ..
	"SoN/Qt+sx531rzGLj5x+rOFtMJwTooLfafaJHRDgnnGSvc/a1v+3tG0ezhqz4nGenQiLSIvJtL+IcHSGCJ5x92vSCRhKnxzeG1Rx" ..
	"kriD4/fc+3aAC8rBynIn/s2A7/r78I3swN3UVmkY3rwRzjnd/vmeZ3lD8ZXNoNaloE/dUakWVR000osbwwmrlb45qmrgZku+JcZY" ..
	"SwZfO84d5h7L7EXuD41yE/8BIzMGQpbp2BZkTEzILfcWeoRU5HWxA217XvowFDVN7u/EzKESJy2BvY0NC+ES+ZM8VH7KMs4+gkFS" ..
	"Fcz4Y3rXIG+WXbtHT8YEwoSf/TCFCl+niPDoCuRJLe2FrzbtZFIK4C6yTIhW8F9ukzyvD2hk09aDj6eiFrn+20bv0wE1t1gmIO/j" ..
	"WOtgM02fRfQuQbdpV2yT/tkyM382QlRK49wyKAjVTxfdelHZgmfMK9DT8eAs41pSMjORDshR0vBM3mZDnJm0SpJ2knqOkQRMPnfC" ..
	"yHBfTLEC8DSlIKBFP4d5p+qjQajns13w2diY7dYNCf+6Sq6VAkSOOc1ND8Hr8qlVvhOuZjvXREDzOVq7cJ5PGerEqPE0/fLnPkQg" ..
	"5I6yaNzKjfrWPO/nBKqsUxPZ8RQcvw6HiZB1QkTfxhgY9k+6AmvjjWW3/IyIuohmQTpGP8r5L+5v4BgMdgA79eCZBWHLoUBD4yy6" ..
	"y/FvcXfTpgCYxTJP9itqONDZOsG1Hob4RXC2LaHqG6Mdi+tsxwe6KsCLxxeQMqANMP/1w478sP+cFPVysHq1/xO9UrM0lu6CkMEr" ..
	"DMt8s+NjuuT6drTjLNaUx/eowManSZfOUjP/CSeTi1fGrXJv0vv/ks422fMxeT1lC4r8j7tykX8iSVLLaZVfIFSMd1ra8dbU8MFr" ..
	"Tx4l4ZdtMcOolGQF71aGNx3f08RAk2ViBpRz29gMt/F9PzIaib1pvhvCPepJtoyz72KPEK4tpdqeH63anoedgcYppx13ajNc01pS" ..
	"4ANVWkKMhmjUgwlLyZm4L9deAOqJ/3uuW3ponlbkWGmtzm8soRySWtkVgycR5v596KG0j+izDCF3TDf8tyMgGnXmEhhTuQU6dHEv" ..
	"MSCzSOMeTjHjuWO9iXjRiuT2lxwMqCWSdURund6nGUP9W1QScedNJNsvLDclWkstYiib9MbfPg6p6E2uRX8iwMd/dzTNv8dc5YmP" ..
	"ed4e7gAimcxG++J/n/RIllQ8uTvocDGcaWIoz+4MASWEUkg0SiEPCKZC+ahIfSQbQVawGxP4QcYg1f9htHqTK6+eAoPbcff/ZTbc" ..
	"CRI+owih6ptfg+EKMpP+sDaanWgAFkArpmW3SaroiRq5GajuNN/X3kw/0y4TcEqRw1pRG4MRP5JFDKHOlaDUdDBXpAPk3um6+gSv" ..
	"eTDIpWSfAOm+rpa3UQGAL3VemlFMMDqUfRIphepqkMqYyD4nkx2Gk85W4tUR384lSPjCDYjdkgeeguZsWrBh3q6rL1d6znPRwyv4" ..
	"BLLMQvLQri7oJFE6EAXcWCl2h8vXHhQ5ZwvHrVcZtfa5GmIa08d+cxNpbYEpmmeXYueXiNi5KZmpophIzxanjbfCDHgaHqwk+d8/" ..
	"vpn8RU5EO9Qy94GGrUE66BHyAh3MZpI2ByUNQ96M8yPHIq4lWXcR3a8sC7eiMDfLDz1bxLpqed9VNP5h9cHpmuQwiC/murSHOwZv" ..
	"+puCMZATyNW0PgUvdXjLAD0UoRQ0hk0RoubN0fuWq/WOQLv+kzFgwc2Rm/9WNtw1ekyVIda9E1JNRbzxy79ttSPBgdZxBU6HUUGG" ..
	"U/+fYYlhCsxBGc09gbhR53LhnPuwswPbNyLtNy0yJjMJFlNezQo3N9NdX8kgKC+EnwBgz62Ex/KSJyaJ2JksWWZtYdJUVDgeSgpu" ..
	"e9VT5r+fKOEi7cZLpnhSS/oS+Ws16K5cebjjRc8Lq7z5iN8xDVoG3gaRPjgbp8rGxUdEiDgjvRqidi9gA8cptYAFEd11KXKrwiut" ..
	"5ui5mY9K/yz9aR0ZWAAGXrkP9Cor+ipst/CSnpPBw1hmNG1ru+QDuzTJhpknzg7H7NwKhsP916Sr2fruLJ9ROHAwD9LO+E6ltdPU" ..
	"HVtRdQt0PyoCZDjRdDQTT2QffBUurscjx4gsPnti267/X7XFcQT5Y21CJ/ZstA5tS58K2O1vgO+uvDbRDhw9jNn+iz8e/RKJpLaG" ..
	"AllmQ2QCdd5U1qnZUpkC8260X1n2ikDZddW47HNrAipWI2BuKDw6joUymRYJQ6uxINzzHVWtuQeyyYP4JeyZAye6cKiGmPV6TwBm" ..
	"Jw+MRZrKWkO3YYzMjr81ZQZTevM3AVaBosqE6v1bWCbOSv+PmM9cJFjTavo/famx24N0U+0f6J+KP4NpAQp+iTsn9fw5e+Yds6mt" ..
	"iUGhCB2hu9GSxYMFLxkjdBp7O+9xj1sFMb+Pwt9bsUWQKn5SRW6QB67nKK6XzSXJKZSczRUyPDceqiGTlEyy8PT7XkUHidEHmXlF" ..
	"r/dCL13A9QHz6lPscafRbE2C9+24laHTyErc3Lp0UWi1TFd77v6Z/E6SKWXVJuhWxJI7VVlRAH37qMNt/5ezG58ADkeq7qx4TLLE" ..
	"WgcBUZrB1XP0TeE+LH5wfboEmUH0WJJqyYSa+gA+CYeXhpBZ94IUoJhiAf4UMPMwApy7/K+joiIVLMvYSev+1pF8yEolA8lbdjYM" ..
	"NJlon8KVfoNp9LEKJBqJ5+0g0Am5YS/ZTD9yqU5YYCq1584nZsCir+AZZ5lkCSnnzDwSJ0JxNEgyvTbFsI1ZeG45zKmvXQjiV0aR" ..
	"vEPJMOz50T7AjjRn+XMtVVdYDOzNLxnsCqkS/NMLs6/EIJdQR41Xv6H2DACsqiC9iu4t7mvbNFCQ4VpOwWRTrC27RKvIdIiXRUQG" ..
	"SWvtVhc3gEuA//NVqP5GB6/WnJ3g+NWzUBZ4NVHLbta/yMYT4lONP/NurJvT/M8xT9KkQfqiD0UYJVtxU6zzufLJVub04V1VZPgu" ..
	"vS/9lJQrdh2R6uqLp59znRj4rcl9mEBVs6e5Vy04A5LPxC2hdNwTvhCJtCigjiRp6Anfha/l37GWQXwFViYn9FWWJq8EF7U/LjSm" ..
	"HaKOiiTBWc6NlR3BblXUJiMhF+TFq/Ip3l7wXCL/YDD1P746GGgyg6ta/ZIhdHQj5sSAMsuzlOhSSnTPZmIsKrKqUkA1NdLSChkd" ..
	"3jJ7dJ58YyeDdPy5XS4z0qJmqDZXOoE+IKIxc1AfxJE7w2qDSiS0INwNAHnHqTXuDcBnQVIO4JW9O1SCZbcVYdWTkwQ42EktEpPs" ..
	""
local PAYLOAD_P8 =
	"OrFhBdbHNNGqijmGFt2dRZfoqNi3GXPPIBEuNy6gQkxVfu3gvQVRichy0nctpmI8eu9lo3yJJyyu/MnnFefzRdRbvnqDef2IacfY" ..
	"ZG8u248DbllddRt2rDLp8kdOv4z8zHPTXSAYzr9i3BOTRb3NOltFTSyyhuV4x2nHTAj8iS2pQqHznYBw+YzG4l7GlAT1katngOkr" ..
	"zO3YQFzyuGmJEutGPi+ytLLmV9ReT1R/4bzXqGp1VouM+msA3bXtDhUABm/N8cEqF+EQOdo1kvnome8Exbd3opgdHTSXAiDPmQUX" ..
	"eKO6yVM1G0SV57dm9k+QBGKn4/kDnX35ZCW42sBzXvIW8hLtgjPJT/lnxkaC8TZ2Rb42MzXukbXghvlCfF5CV7oY76scoagSY6bi" ..
	"aiENGdv0TYctNO50L1nTnw3TpbPlLaT1RWvX4/xNg9985trcdJvYmLPUNl5RShCMxQmyN+yQ5cGCfLLQ8ZiqcSYiny3YESxJowcj" ..
	"jFKH6s3dMUAL8KL+Q2GkQFeN4eHBY+6/tPjHPRoMKFih6MIcX1nHbVySTk9D3koqJQq8lPweWG7PiHPaGCP8IBVo9AmBX7omeJyr" ..
	"lpLTIWJM27CgASQwrh5oDw3Y/ag44bjchSHCmUUhDf1GA/GRD5bDNmTJQOdE60h9/kl8DBj0yceRAJsrzW9bPrf0NF+fG6KSH7Wd" ..
	"UGeGZadXyxfGcHE6htmTtUrJzSKXfa28cbzjDmVYnoMbHisKMg2IWe/MgxfsUm1wfsJXhsrxnEyM3w7VG6I11ROxXf0b8vToLD2f" ..
	"tUKu4aRZzoBBBHlhquaagjutRv5Q0szV3BH3YU8F/pewy0P+5C+MLrjWPoHhljVeEFcKooTjVJQcyB+QSzuApUMjcWV0rJFNci3a" ..
	"v4fNgF03aZhBmf8OUAjySLHesEBQ7mbza/KiRaf6D8IgN+FTwn8afcJNxtMwG0MknEYHzzDlABloLRo5pjoy20i5VtgQyw47k6X+" ..
	"hCInDNRkaVdDNVxSjx7+ebJ86hrGTeqQDzFjX/2Bi5zia88tmcxraK+656nQGb6crDORVWd4lSFt0LjLl5l+ILby6Lx89qF2hNOL" ..
	"u/eIN3eYmEN0i99FGGQMWKts252Eetct0n/rOwti1YQebXTxBnu16elNAxwhw1BB8NqYy8YCnVmJGr3UXwe27nb6A8GvH+M/wURc" ..
	"4kHYwu2Qv2EnXMZkesOI5rc0rHUhyfHRmNHw3IV5GCWBkiWuGwjr7PTjs68rXuv7PS/2Tb2DofWog2qkyVCpw7xdRYRNmXmRBv5A" ..
	"0TJf+WpntfF4xm+vlJyi69fkuHwmdniHFa/7SZX8KKn0aidtRbFUaKK78jdqISb9Ti7ALfffFIszdt7nLO01zw+TBq0uZlL9lZZM" ..
	"edLJbJ/+MaC3tkJutfbZ8JjgB/6pr9Okhiw3KAVb7mb/bf93i6sNfrGiZEkIEb2pQndF742e/t+CpMhHTwRd/JznuxyI88zXIJ0Z" ..
	"zvwknoO9RIFD7Jy+ydWOsoA+7XQzaA3QFIm1cGDgVperefuUZ0TSnOQqq38cLL9pM4vHnuv4AHv/vyRRYlnnkdFlIdut6l+cZOLn" ..
	"EYyYkQOqNM+23D024Q5f3p9qbAjhSFpkscjrLdigISqduETsOPH1y8rZ8r7Z8oG8gFfuMFnOQ15D2leFHcBoKac71msnF0NLEZI7" ..
	"qf77+L33evVNckUMj/EPbKy8STeROzr5wU+VrNBWx7V2yZigbWAFI5sh8Ksc9E9MqliNqE9UcEsZ8/LVolPyFUHbmQ8gvagkFKfp" ..
	"xvYSv5g4md7g0AegYYa8E8kAm7jM2XfGF9fAx38bcg96p9TwOAdrIogh1GiA1xF92WRodDay9iMK6/lssPmhZME2yF6R2WvPflmb" ..
	"OzAqyhvBmvOmB1Y0Uz3WOCS21S6RJ3rW8miblgW9Nkh1lwTMSOstEpHZYHOtQKqpl3X56P/m04I/VExfGVp0Z/b4IE4WRscpsW9R" ..
	"QKKj+BhkNkrjmr6Y65lbMb27yBlLJRtFpfVYhGMNAUVKh4l+SYEULxbYDxTITYb+MekibeUr/CQnSvMGKXAxVUt+WLsmDW2X/ff3" ..
	"lQJw56KMRS0JdoJlmLF4cT5aWrFzobGQw9Ka18mv6OwlDJRbmRGlihAqFQ3r+S3yMx2Z+blbep73aFa8JoxV9fvNDPVDfdk9uTKS" ..
	"NIouuW6l6Lk1io70jaXz0QpEXB26uuGbpp2IH0epe12OF51bw/j2jTce1j/jdj7EzdkdvI/xPtJJyFqWBzjRdr86sCSoIOhB1zp5" ..
	"jyV8y1viTBJJbxLclYr6WU5iHsnL7h1P9bZJQGL49orW60u4w6uPHvbFJbmLPZEJ9WTx3oOlTSWdLZwcBxM0cVFJEr+wtxUkvjPv" ..
	"qFH/0AlyUYcTkMX1IXzzTnPVBI1LMJ/W+MQOr4/c6BiaXn4ZIJkVDn/TWY4DeJRxbwN8avyGnwYyok/8YYfGgPvlbV6JMHxavgfa" ..
	"x5wHbC4lthBTxVlLHo1jNsbyYjs167xiaJrUNLEI6XnsJCwgA/FqtLVnDQgbsCf6zVWWzngjpPrwLLXokPyfNnN/h9vwyWw9wLHZ" ..
	"RdOtQJePlp2Lf0aBNG9PZVnKyHPHPm1dd17lMrlI9F54s6N1iPxT7EP9XmCLZcLMqWx+ArzreUrOXww+8D1WBu80EXhJ64D8VEPy" ..
	"4YQvCgtJ6aEDMxeVYlFwmgb0rUWcHnXHK+NSpFCuYGogyAAVyWoMvY3crb0hO1xQkOHVjbduIVLK1409YLtNCfmwC+gXJhT+yeUL" ..
	"npCzz9gMUhqaqGdxYLKGPUs4SbesNaAzmiwBr2P3PaiOLhgYEJOQG/M9oB82vOZoNuQCg2ePeT73607uOyBcb0qGT+nt/VKY1DKK" ..
	"UVj69+vXIifQ5iYr1oXynsn/CLE+5QsiTYAn2XDMad+KfBuZ7yKri14CokHRs+A3hBo7zU8FPgMyK/WUmcF2sy36bCoSE+LDBjYl" ..
	"RPHNhNfAUTmSp5RNgDlnQXd9N22e7F/fY2szJHOvnCfvDsd1LcI6mPML5TaskJHe5iqYbBDCZ/K96nAb9GWfKbsI+vXM8t0t0k4c" ..
	"NwZAsVPj4Adu8CBrCh8wzWSlJ3+aG3ucK3J9jrat+I5nRmBqK/444wWmosJ2ouoMYtZ8E2b5n0L3moGIu0UQw0xKFNIs9ufqvYh/" ..
	"YmSbcpXxDAZ0uM/gV+WEaqSvWnNN3B7QXbfmwZPT5PYCiwVLFgyivRXsb2zqY2V99PMR17hmUNUSNdGXk7JOvsro6NJ1yIwLHClf" ..
	"n+vpmv31696eQDuIHB3XMYR04FqL+9LCuuU3vNtuLqsgM/hpl4pfgfaO2xaBCSh/7at7nzrarVr5pMJgKcxRCjoYgga2HoEM2xk/" ..
	"R3tcqh+PikgVuwOSaHGbQp9QcR03BY4KTcGB+rhMEKpbNlIaWyfE764IDpPdCJcAW+P+CdLRONJ/rvmMq3PPLz64tUiUvBRQIITx" ..
	"vBciNa5RfmEf325VLhvaxFt9aSogkTcP+Euul1jBFuBC9KSpPpVdGFmslOu4RinT8TffA5kuIjsUlWGbz3rJZnK8QfNVQ6/x9Avz" ..
	"+3QVx0sY7OENL3iTUYUsa9Zvsz8zKPpB2zJhlVxvHCSvaaAbbcWyCl7H3iqd/iCoFEwn7SMRHU4cbuILzdpfuampaAuHowyujI/d" ..
	"swNTj4VTkpPxNJGNgptD5BjIbji/Qhyv2XpN+Hbun/fMd6kXmB+LWOAoDK5aGnmkXPPmcoHlHFJgaDvdJSaJ4PsvfVy1TKF5nzXo" ..
	"KidVw0p4QYfr6pdqBIUJbmP4ZvpCcUDYcSUMtQ5Jzxzn76YtXcBhWQhr0vP9N4ib0VKoZe3OdC4En6w6TETL9czC9Rip8WMwovi+" ..
	"Zd41Kp1JYR3PgQP29i361mo3W+RRhefQq1imaQPGlKE3F5+pkbMQB5V+acUdu/v5VHaI8x+ONOQUz56oB0aJKpDAroS9tDVn5V4f" ..
	"NxOLr38+aTiCGxiZlgci/8MtsB86Tp/+7PCG/JDZ14qZnBo4Pd+6IWbZ2r4AJztZPMXHX785R5Dnqd2Qbj6rgzk8WihfQGVQgbs8" ..
	"ltzFykLbHdseJxIg8wCggxUunLZRjzAkbAnbJT5wPT5GBcJ8oQoLXItP5Z8oBX4AX87pKv9TB7Eb8GNqlwUBc4xOkGYxPiOQUGT9" ..
	"KQfCk9NK6+uoeGzwNO7jrnvHRCwAWVkoQkoBpTnWomneT/loo/ahkOQCrojgUc2BamQuN2yNEyFRzHxIPTLyzN48HnJfSriL3CUO" ..
	"44ismCO76fkZ+sEsh3ICEluLgP5c1e20EGZv1pAMmG/oghcSDWq275UE9DumvBZ3ry4jZduMsnGFpDQna9W8TkvqpoYNZwT8XoIt" ..
	"WrWpubjWVmMePPKv/85pSeDvKzPVV02t0okNBW3nYYkzJ2hZBiqBaWK9Yzz1GWQmv1wWCGkrKJhJ1Hq+rQN8NUale9JRK/0eaw9J" ..
	"X6X9GQV79EtaSIL14FaU5jzrSYIu6u10S8VPbWYJLscYVH1Dt4eo+06vckSk3RLK6d1yUVm1WHmxtggb9N7qyO5QwNLZi0n2dU6z" ..
	"/gR2a7QB8ixPpmrRyYZwc435rdUWJvEmOfwC/4N8lwkDDLXtBEcKN7byHqo09Lnxe9aVwGOQ4bpsTt++5V14HuXjb64SfZIsXMNJ" ..
	"O+KzGMK8Jwx+OnrXYmCv0zTlPJMjo3pUNJEk+iOZHx6lqS1PKO1lLc9xwsqvjMjmQoZdSrrK+gVwM4OGxjN4XRopYLUFQHYI854J" ..
	"ylQKdO8Ch3twSIfGtGnI8+bHgO/6nyYUDmfxexhWO/FMaU6LQfO4hUsqxLEWio/oydDdxCaIWOnVWhrLiwK7xxDI5z/OwUFp8ACy" ..
	"LGSe5NZXAMp19gkvbblainxNGOjec6uHjbfzRtmc8U1fy6txlqgB9gdCQx8BsE2AzI/7e3nouKLdBfHi/qZQp0TCawTC636htH0e" ..
	"6rk56DhFPr498JYub6UC1IY+vmVuTrN1vHQUIMuKv5JJ907mxyRPIaze5kHEaNuLloyXC3xFkIdA6Hgjfj+WUaUqv7QiJE+GY7oy" ..
	"IVBewWeZJ1bML3qfvd1azPBMO7iiKwv4NkV7IUeNoJ92IWowThtbNTTcKNrt8a5z2shrbh3SY8WqKl+WnYLf69AnqnUImV9rxJWJ" ..
	"Nc+VAwnD7RIIGGitprIdfKKAB/o3Pw1MTFDRI3YKqm4N6E8MXIJ/XX2gotYyovnyoAAlwXtGgRqFSvIQiO5Suogm22J/3mt77qFk" ..
	"/BqrenU/5kcfx41CN5soTAquS1juFlPgEnflGY6yzi3EbxsYivljA+3fLpddmnTCMmuu4AYrMycUya/ewUO+elQYyWNZrGxPqQEx" ..
	"LEKmvok8WwN4UFZg1KOkAklYdCLyMiplWwPOGgB9jFfTX3LauVQQRJ9vmiXy23CuAZb4DNf6mwB44ue5bEnrng/As1JP8xWmIYTZ" ..
	"ZR7HkCULo6rTAWFc1X3REBhx2EO/gaNbTRDPXN+YaoyRnNkn/XKv+B0wuy4ke115qnxFZVH5GFg0LVgjO8exZru1w8q4Ixyw9kxk" ..
	"5ORz1UVxNs/F2kw+qL0hEB/3TD7086svKbBpa9ZtTTyU3c6ZQ6A9DuVTVpoVYnCvOIcdb+H392MKT5FlaAcxS9Le56wLwV+AQlRw" ..
	"7Gd+q2KKXPl6ceNV/csJvs2nuKoQKZq4v/idILEHT1bl7OfkMAdopOwwUEsPcW/hmzgj4Qgc/M9739zGDyIaalV+vGWwMH/SfQH6" ..
	"Q9O/Y9yYVUu+BIiIZGGTEIQhsCnEeXGJ1HDAxOR+/9np8LM5jqZqdX/FQYw+ZHwrpHJ+H64KLMUc7kowOQSd1U1uO1peji0+/PlR" ..
	"wdTgRB/Ly1AlJzRgTqsoGyy8cU+atvMsUyPiUkOGkmnDDacz13opWBPpKFzAyQttQuQ2L/BtuWsB/aIe1tifkwQ/Z/NpNT7SY/Wz" ..
	""
local PAYLOAD_P9 =
	"AbT/yIK6LDaHWKAZAVeX9I00XaW7i07IY+sYY7Jf2vHsivs2Mi3ueJ4U/3XM9GZ8FfmdxHDpCgYVnHAShxciYCqXpB51D01wIjUD" ..
	"yzWq39SxFXnglsJFpri5IJrxRUuW0RPcYzG4n+DA6L9tdbPRjdUqWkeINSTtEHMXY+MfV8dtO0/u57zD17kSR47M5jiDQupvutSx" ..
	"AQ9HHZYqO4QuXtU288JN9LjCWoxeosPcYg9YIZgagFwhX64x7tRLI4kkSeEJ00gySvmv+LCpSOUaLC+z7q1eask1q9o+hf8jbX/6" ..
	"gJg966jAxanSRfANdwxdIPE7iL4Ga1Omjw9rThFjcW32g7EWQVTaDwRYHC3S3RSAvRY34LhrvDK7FzUcufPrTfEpGNrT4WSHrsja" ..
	"M8fV3CG5+tkWKh2H6bZNdkSF8Kx47KxfQ9XupkZJQpG/adL0RbRxmP0Wf6wb9Cz8OL63TRGLHAe9iJuQdAxq7Htlul3MPLpXn7oh" ..
	"oGLJq9rdWiYayIKykKdlNvz6qoCqeRUAFS4YIV8y06e7T9I9iD2C5URqv7NNvBbB8b8f5tLIrrqW1yy4TyfoyN2ne8BiqAV/zvtP" ..
	"CqaGGfwkfCSk0jq7exycxx/h1oBTicFW1gVCot5Kd8a+N783O8ABohh+y+D39OOpItsSsbspm+YXHiMew+Ve8QdTwr2EnGosW1z4" ..
	"YYMlbvoZqK6n1roYxzhpuWAmUBV8Km0/zB+KH0KUf3PEOudxbcL0qPlwAPZNTexoWx4E6FXxDdKoKw6sx2Oef46+2kdukfPYUWKj" ..
	"utpwCwUYMDCkRgbD1J+u5eKLY2NhcBsypXIsIZkFeBmyUZVTyfNciC5bdn/j8V6427lWPzHg+orMMXFtl0yOFj/bT1nV44TJnPIv" ..
	"Rr9vtne9arN/YJui0+Ma4Cj3e2GA67lZDiihfk7ImqJhHuS05XbJMNak5Xlmtb/iR530EEVcNoPvbccTTsocPBOcaiNPS+r1Joz/" ..
	"qTdqA3GlEdu50nctUqOCsm+M8EJgmvMPK4oC6H1PAaXntgmJgxl6d381nkgZGLcgSodIw8byf1UlXvf1wMLyxkKCBAZQXFgAdNnp" ..
	"pqg8cmuZ6CGWNry6t2tBKkH66dR+bTObFu8CgynmhxfHMfMJ7MmMeRy/Wxlw/B79i7NaRvnypD5Tty4DWI0j3am/K+KRS/iTdqB1" ..
	"Xe6iO5qxKRaHXCHb9G2DC6zuIvMwqU5X3lVUZoLYFjF4OLtQLL78M7L+wlDwiml7qmGoDWq60bkL2gyOCqZuoWeXQG72WQFlJfBM" ..
	"xbyIBUURj3DSWDqLzeiLRn7Jf5pit82oSrlVWM6gw65UamzYWg2k2kR+BMiQOicTp9XWqwaezerc9bJXIFWoyMVdoG+cm83FvKc+" ..
	"2udeWmkc+NQLtMc2JNiDd/saxyl64x8mlcLrsvLHmHFSBD0/cHBk3lJvD5xlKtQiMToCo03r/w4vKPe0PAN/qiuuFciQzuMX4ktJ" ..
	"kxXa32x+4jF+LtIi6ZBqjwSJtOBpS/UP8btLQrSpGSDN3jAbDRR8Cp2Y2tRTJ7JJA/orLJaroBR6F3GdZmyiCR2UcM2EGfibmdyq" ..
	"YmlvauHpKiihJzovIkyyPo6pMwLZETnaPlJDHbNvWYalTsawPmBZaOlYi+MULy/3Vk8oonGxopE+iJQixplLrAKg6xx3JcWC9aw3" ..
	"VrRCR5DZwecH5YEONYxf/76czEAJ151M1bCUFoZiEa0Be0YwIvsyrP9gdMk5W3nMw0V/pVv0vKS/6BcGvKYsyaNMrzMWuebcP7vo" ..
	"MhtSfyoPBbPpV4yJxtq0Kn90sdlNNmCuBlxeyMpEYE3RLUWkvmaicZEXJKd5jNGQSshl9f3PcuHwZbuWey6oc0wT0FgV5hKJJnxA" ..
	"5xCcPKOe/D4AnUygisgOE0TzbF+VoJys0UxXaxxOS3wwxPFcCHZHOorrvpL6T1xftqN32nVpqwBozAbkswsCGI6o8hRfPpCiMbhg" ..
	"/n/JfPeCfIHtany4OlG4uz1zugsPAtmqmvvNVjwY52NLZt8OeS2R+nAn5RGbhqZYGlthJwwpzX6l5mIfJOZwbHDFFejrFgj+PxEq" ..
	"HYL3DbXMZ6xUht6MLalSDynbQdhOCx4drS3ch4ofyg2cEj2+5brHNQdKbRlpduTXc4TT7BWTy9zdyMxm9mVppw6QvMkNa417oSqs" ..
	"otYQy0ZMyMfypPlUDSoOKywo+U/E3L8lnzhdKuoSD927JgN3JV5bEErOXG6WdE91L+hfZkE8nFlIE1XaXxjgX4P4pHpX+YYSz8L3" ..
	"/04c2rje6dDliPSV9D2HuJV2GSBpNbGKMp2wBJRf0AsSWzSr1vIvCO+HOzS9w3V3jc7K1NDHCeltYEnw5utiERm09QITTqyGdAyR" ..
	"JHYvGl29UZJOqI7SW1btZigANrSfI2fRArLgeOJPSKN5aXDrHyMsefpNxAtrhhvpsiq2dGjZOKRU06hYpDZXu+2HaFkA6ukb+8r1" ..
	"5XHEwRvpTeJYxeKJA3ullRcvA+o/2NF2oiSy4abhV1IEoRCyBI4bB/Mmtmn/usAhRhWn/4p+Ve/sLbwTJSLJXJwpMyYitWHhADo6" ..
	"RlYxYVpBhMyu9UsWCJUGtv1otdZLVozRXJfyov0oSw2bKRV6+Ywc9MjcziCfJfggWqoH3Svng4B1zkI1MIHGN407xTDgVcFQayaZ" ..
	"X+GPZ3JYhuNxGFpUTSovi7Fbqzy8y5X61mtFAQhakTIL0L/4+FKhpUt7Mz8KrfDZQIODWygG6Q/p1xKgmxCjubUSv8S8/TQSn2Xp" ..
	"u820nJO8gpYYCBdOvnVNi+7QKnsAxgYsKXtTyaLHSSufunEiQ+T0uF1AJnZya3Cb72hrvkJorErQz0xVEFQMimNCsSpLvCOnNjmM" ..
	"CcQ1FdwGoa3823vk7Ag0ALvpOEAy/6QtMdrT4m2+oSY3xAuNU3o4qrrZpm6yN97wKr4pfBQI6PUmVci/ax+Tu3G3WR/sVZ9r1VYh" ..
	"EXT6HgSqVDUZu75V6wiqk9gAEC2kkECJvf5WlG/52QLux5AxtU8k3ZvVk6WVutXaCXNmMDsXQyjTxUTBaPxCujRTraW8ct++oIoB" ..
	"LWRGymKJ+igI1OirSBMMFfVTbS4mfJGMYov0B56Ic08o6TgCZi1jvRLt+fbejTNdXANuZQa2EkqKDBoKx7XZxDFANyY3sOwSx6qr" ..
	"CM1oLlrTZi+qqIFVTP8MQL/7rF1cfBA8HZSKZvssZy8oZJa7Y/ZiIg9RHnNvqbsFutBeHjmNNgdpSPaXyDfe83uorIfYHBGTexkW" ..
	"lfhv+nrg7ecGly4Q+oq9a47FrAKiYsUdGWeEYGpo34JROsp7/cj1BMitU0vPRXeehAIKQvmhT5GimKwxxpkxVEdOyHzBKbvLx0bl" ..
	"2LjqEyI7OJqjojIvDbzFqItFKkPwIKGGUyGiz3ACSE6OMxVmjI2KaxfAHs6XCWa3fWXp4JgXxdkWfBXhwJnAYLSAyRWbbWvJ3y+K" ..
	"boBf08HmIBawpAZDaf5u2Fpxlv2s8sm37gDuoR114vll1xJ6femhPf4TtGuC8TXu0Ytx+ZgIjWCG8cfjNOawJPaCcOZP3znYpHY9" ..
	"8eZmKW/QuPsMm5veI5DSpaCNi0QYrT/+KANGM3KcuhtC7FZSCRtFHy0EC3Lo31q7p3hAla5gV5QFfb20phEtYODaEaOFDCcZwgkO" ..
	"LMZcLfElYORtv9J1ML/E7x7YVkGBrlwoAp1RAP8qi4vQEWRSR1l57SKAmpURXjPKjYJHgOf+EB3zgWkzLAJ4jZKHHL3Dkv/KFusD" ..
	"VC82g9qGlB/1DCTNTtokuQCtIXAB6VJf1iskDlim0yozKDZ5Y+9inoNnxlD9BMm8T2mQsVTgAdmQqDYpWJkXprFlYYnQH1JM/LhS" ..
	"cCLQG8lGi/JISfMryqhhO1a1wML0DNxp1BgME2yQSbrISeJenFUsM5+9pe6YOvKAO/p+XoJjsYuBmf0ANDUWjxldpMolXYJ25M0x" ..
	"ZIDaPirtocpoyS9v4pAjBgI8BvmMrMQoajD11ai7tEO+W9HcPqgOt/5S/i7HWWVM7eKsaGChN21YzeY2bx8nsX3sjoM0zCSnAOLY" ..
	"SxsKraVxtpf9zcGHuFM179Q0/sKlh9c+tR4u6fRM+SFWNEhlU5ydr2JS9l/y1mHX44ftbDY4CcYVmUKTXeLvENaBqhnt8/ddUkUY" ..
	"teZ/gazR0tELW13w3crX36Od1ILPQLZHRkxFO+PltCkuOA0MjAB8tKq+iyAUlxQ+SUqo0v4YiACAeKRHiTUW/kNOfbrUvPlnOYyv" ..
	"XufqaY+JVzDIXc2C7GV9Vqc4wiWCnmP3L7UjIelhhRnUAafTSP6NaHEkkjrpJXq9Pn2Fxs3JoGpFMmXp/OP7EpTkrX3xJAY6KE9O" ..
	"lypmMUHdrarThX8akItGTmqX9lyX3fvC9IGZqN909Xfr5SuoDnJf0iUr//wr15YUVS0RU6LyOZZhsxrQjwxyRX2eoOmgKvSt1eHZ" ..
	"OUD/urnNdx2S9+DN+E46V2UaBaGVGBQGMs104A7Vsncv/eSBMonXznyUWgol9Huq5aw83+6WrcPQdJk4p0hoSuFWjOGkUAVvfDzy" ..
	"M6fP1eI13uolnAsAm/FABlU2IJ91CHFWqL8ldg6s4ybiR3PSJmEkBB1JIthwDIZksLS+rmnorsyvdRpmY8XQur5dicooOPAgmo97" ..
	"Ykli6ZFrofJISDEcI2l4f+V9rQml9zWwDMvsyLe/p9dymjSyuHPo2TmDyNNNoZcm+Cr2ZdLD9mRrnRA4VesKGAF29CKel1YAZcg7" ..
	"F7zRXVs/0/JQnNpVLaQ29lwlTpuZzvsF5swh2BwupeEWUv3N+vngorPS3UQgmB2EUg2CbR0zFPiC5aRoxx47u1FM4/PLkShSx+ne" ..
	"feZRkolctPx0CcOQMz2utwa4V5o7GM6Y+iP6kKaJQjOeCcjpC+pIDDzoVjIZD5dDCM/9FBTrIuAvBrPcqM9GADswDHLxSE5Gu5Lj" ..
	"NY4qAvXXTabmIAOAP7v10bFdgQR8IhlP+OqDZEAYiMCXva9I4mgNMXObwTIXVtPen5TlBfJ6P8Pa+6b1CsV4QMZJ4AxwZ7XIzj4h" ..
	"aeCfVOuBa2m1qwCwyi4sTv4HszqIoR4rpK0/ygYKpFIG2kdrV13/pTAlkps9hIL8M8kN7U6sJkx86lgtERWVQ+NxzDkENet6rlpE" ..
	"9SL4OYGbWZlcG6BgxFMAwSrA+Ti4NfSXKtBCJ8+yO3KoLJmlkGy5GzzXZjATeJcBk7nms05eSPRKv0cS2f6//e7m9K6WOYLvW2zm" ..
	"lkqJppN5IssE7VtALr5UZFmhv17Lcmy4B+NHJUvm29/Rky8isrXg0nrRbe0X7U7/B43ODl74bKvS75Lu+VTJys6NZUKsSEtBDud2" ..
	"ElGQhsuABuSVm4w1negJAli6Qnf0jHnQOo6NYosvpp7fsYx1D8UFHvSQelvJ6uuwq/Vlo2JkStRgTKDXbBzFaNZuI2svBrm7HhPH" ..
	"pPT/9EsEjg0c/yoTvSgEbD7v85H6GkpgQE1OvsyvNc/uMeZRPv9AYqLA2iAjDch3jCE8Wsl0JTxMBP1KQWK9RKFKYaY/145uKIj5" ..
	"+uSA9P3d9EtfvhqBQ4aOOjzYFksMw/k3AHPiBkrqNr9m57SFK6DTJrX0N8Ox9zCqT+wfxnuSNO5kPF6Kd8WBRk4TkBIrUxub1QIu" ..
	"c/Khr+Re8RJ2ZvB0RgIgrJebsEV5KaNh1nRt//NAs+RFT+po5EgT0bPCiguU+yzaP1DG8mXQQqFlDsMM+aPuVyzjHz8AL7q6xmi/" ..
	"hdZN4NX1ypGj5z1irgH5r3eNYR+UwP81fOfxjZOipgt5E6WMAiREq/SOpKko4VlV3AefmzF8gN0t0FiXd5NO4KNw8Iqf1pBVerz9" ..
	"i7WtBskvFbNXGR2Fg2O76LABuL5VgQNCW5waioQhHsd+ltXozDDRPFUsYQBvYA067sZ/qOnco+pMmMBtO1hC/Jx/aVEoUDPJ72t7" ..
	""
local PAYLOAD_P10 =
	"YwpAYu/4ZSd1A1jWBMYvj3DryC3p9n5QdMGnLaNu7wEKn42N05jD1wCrEHhYgrianL2UFAnZsdsk2jG1X8s5QKevPqy5hh/cs0M+" ..
	"Fx2SQN2zWCd361LayWCBYAFdbYHAkiTGkMkI/DQVnSb5S1ZyhrVN3qNowrzw88YaPksMEG2jQ6mvEGghPnEkoAsGYhFLn0y7t7Xy" ..
	"rBH+WzrtlKy+/X2mAFKSq+XR3uR2aW7z2yKNATITsWQpzvi2KpqNrWBKTE02Ic9MSOcGeq24irSs9JitYmpSrDRe2z23RxdcDdtQ" ..
	"tVw2lzigD7byTi32+JLnGocAMi3PUjZ+0e6VLdT+kCqCrzhj0vrg+E2fTTRBhCtiGNzDwfTTpuuiwiNAASi6JgP5PD/h2ngBBctp" ..
	"GzvBzM9qddKw9HYMgcqxPDEk9TInKafO65WDoLIVIneE6wP9qA9tAmvUXhq34/umnpPPNY8aWIGpgsMKRNHpLBqUUMbO/yUh1dYn" ..
	"lIQm3sfnRy2KdbcsDpKtF5KdOFCTH150QmPbIEi6d1WrWxGDiDZCiaY11uOAZOlB9JlDwx+18XwFC86U9JNp6/R4/q3Y1EumJkWS" ..
	"qazK1BuAe05wfjZsONku0JciAYHkWLLvhimVQQmXUzUMSy7BnJLBnUTxJaw5iVLsug16gjXiL3RZhj7GlTNXUIaBafu3Ca/I322B" ..
	"OXJAAWHscN9leHzkQk0VxI+cW3y81hPxg0k/wxGUAPlikl6aj/Ui4EunkfLDpzzDX3eXAR6YkacnN2ljv3o6HTrALK+5b3aVvvUf" ..
	"Wkt/BrIi1PGOQxQVt75IU3LoJi5jx9kKSI7R8p9SGfgWX747+sDjq6TjNYl0WXwdV1pt3TCFuOmOAlQxnZuWKUgoBF2dS0a1hHmj" ..
	"9C3mT49Fpb/gE7d4aJ+vheT5WIheufnNQ9cTmr2OL7agzbGxs+lFMK+sF30j6csGzxkPD3Jh6lX4OmK8dVKxUNC5d059WVWcGgNe" ..
	"XVtvsRUZvJdLk4k0hlEXEZxlzXhkQ4EOx4rMB+7nTjWKl3g3qmbgnuYrXvxxEVr+gGrp2rkvW+usSpoZW2Vto13gFTi5JlgD8LVy" ..
	"QCnIcSYcfzd+astMojHMZTERhMTvY50uz810gRvRVWHiRgCwEr4AhtxybEPzPNbp81SS3gq1Xt6oSKKMZZNnUwO5rpxIsVm+gnFV" ..
	"DhNT8xfeosK8mqdC50ft7BnuVywJJGdn0ghR5rVa8SGx1tILjzqpRRlZxKBe386Xj6HUUDw70qidgefIFb+jNccWckt0ZVUaWqXz" ..
	"KQaZ/+8bvRDSQ/wfKQSGsZM+3r7Kb9VeTwfnMKokf9Lhon03rvYSlj9reSUVxqU1S+G5vJZ7NWqeO1RcpM5PRj3LpEXFhF52bBQc" ..
	"VNfgC5EZFNYlbsWZynfq5vbaRb7KrMkQj+b1vqxi2PVw8m9luCMt9KdF51OmlcJf8XjFyzvGqvfBOOdgjHVo90VDPB7ocLkUNq4J" ..
	"v762BOIEqUcl8xk1sFdUPoGq2690lWBSocLiK+q80XOWlPYQTlMNKe26lMFwF8XE3nU6f9eozhtlTJh99fqMKvYBel2PuhT9TlSl" ..
	"QoTCIruLey9SF8cULnfmYtWweajYKzfDbYBAiqKxOZZ7tnul61IJfMQISVcfkjAvX6YcVnRmL+kYU9M9mJa6Xs+YvMu7KCysY9va" ..
	"Wv097ZTg3PvsTUSlQWTw+FDRTdWR83CnbWmVIGM+NrCQcMb+TOZ8uKfNODZzMIiEbng8kXbZt7oTttWRb93Lhkeyf+j1t0haIYIp" ..
	"msdad7QzDOL8m2kMGPgpQgKyT2/6xfzHEw7QT2207WOK8gUgo0s/yT+5V0cX+qYIW/sDx7LDRhzp84Pi/J4MwLfVNfBZbxMzwEro" ..
	"ZZbjABNpnqO6lL9YufJDILhRn6CPEX9wKYEfa37YWvz89Ko90eMjTOXeb8wIfQipkPOdujbPLTSa96e3NAMiovx0yetdc1kcrEsT" ..
	"ekv1bjO2L6hwRQQPJmCX3o7bscueNiWfA6MytVYOAKo8AgYTZiPyAMM4oVzCnGCxrhGEPYdO768LHUtVVtavFXMqz8ry5vqcetIU" ..
	"3gJk/TXfCGnCLQFpUsARWEjYMcBzTetfkt3wG0pfMtncJDod/2yWvYJUQeiYmkm2FEOzZzcdf7846a9nnrsDQC/A0/v+VjbGUTW/" ..
	"94ooMQz5kN9BtzCE1Kd0d89I8Fc6oZ+NMjrxp5mKkdfUZKQkkOxpMCxxH5yNNj4CgKqKKHgzCVrcdEJGZEhwveozWRPx9zwAwzHD" ..
	"W14pU4F3iojEHeu8e2SQ1sdfzOg2GmKUPiVLaPifjI89bKpkb8/TB0fCvijsp0BGtDtG+uDx4wCWI21r50gtlUWLFvtP3zArpL7z" ..
	"97c7aNnw+SR6ZH94EEtd66pDW2oxzuy07WrHw1PpivR6TO0hUYJp2W9lOZyIeU7OzZyH9jR20c+A0iu1odvF+4Ytdg0ggLEas3rY" ..
	"ySVu5Y8/PSWJD5BfdQ4Yvjtbo1GeL5ua24L8EMG+8jA1+5cCimI1IjBKr4G83jDdiLwH59p97hlKkG/+EH8gS4LY7vDb2pBgEisD" ..
	"7BxVCgFBc0g+oIjeWqeEep2v+99HgNJ5CLdj9/HylV3E2njphHMWnOAbYwEmAfgA7tPwGfFEU5f22uvoAFTw6cdFkcKEyL/L0lPL" ..
	"qOkvGT6id3jxtz5YUueUiFCSZLkXLOyl8Twpd6AwtxnVfUB2at+T1tWXasQNJEBOR4qYtwIAvOlvqjLwVX2/5AYBDrfCY1sbTdGX" ..
	"7kek/Ilg5GuweF04HJNrdpYc6hmQsOexHfB2xqcTuwe2ktth+Ads1CPNk+5EGDUxoztrOFeygo4d2cMusDtF+uRLei1d22GLxFCv" ..
	"c00VJhPOicKdHjf67heHsRuZ+fHJCyg4CzxcvBopQXKl0ddMXPizOm3wNDavxdUcnIFh6cm5WeLsTYCgWY3hkjG6r8WbpTlsZ7eW" ..
	"CwiccVVbRR+2jqb0nXRdCUZAPzihB15vepGIs8cwK51ncCq1RwHoDs0KhHdb5x7i+EPoTqrPfYjGx9GI2Mp7P4Qr22mJ2PY81B7W" ..
	"OxKaEJLKnbLk0XSG8VSK+1VmUcV4leQdhmvHF6EcnJxr/gWd9r5tTJNW08x7Ffnxltv/R1ENVj/Z31wccP8nt0HoHF721ojBim5U" ..
	"gAUWSoACoYDM0xFSx4n9DR0wYQuLKUJl0BRb2SOgFdo6sQOSiYe886cbNpglDsjMcxT9iCa6O7AadqCjg7y2JMmerswuUP4PQ4xj" ..
	"36UrmJ7pe1dq2cnWO/KPZQ4I9JR7ircK0ToqEo6+06JvzmKcOo1taNfUoJLgp0nn0GOP/dZvF/hDUNimsN3lJr+LUg2kJg3+BYqj" ..
	"6ib1An8SaxGK5VpjaJU9vnsoB4/cDLq5w4mMiFj6T82jMmDjJ9afMa3BLFaLMTqOtqUMtFHtgyZYL8edFN3jQZnleh/VAimVbSHp" ..
	"kzU7pZ+pRscsxG7aI8xNkM7ufFk1kW9NSbBv6+64LI3pNxpQaepwwYu3FvvtxWxjeVtDr/K878+M7Q5aCep/OaudnJipFRsp82VS" ..
	"/pFS2XLTCLJ+m119eGJ1LytJuCeTyOrJrlXJJAnF7oJ5to/K9/tysS5NLFSyjcIf5wKbAmdF8w5YOvBTDnC4422RMx94niCo1GDX" ..
	"43xieVP/V/AROK9uiiy9hOsO1ym/5Jpm9KP/8jxigB9WMRIbNasmV6UqZG5c+g06yxkv4B0BqUfR+NSvn7V73YXHEBn1H2UmgsFm" ..
	"FW82iMAtUP8BLE8wUqhJJlKVFMRj9NWZvMAucHrzT8ycfrtDa+hVW+zl5ukDILz5ty6Pw7pMi0YE6CqerCsEc83R7QGpuwfFOPZX" ..
	"5UXgFb3nY+pk0Gq6HebKnNv5TWrn+Je/nnycbPXl6hCDTCvVeWxnAag7wCbEvK+DVvLRR7ncPzvt5FmwwXzmftffKK5HRRITo/z4" ..
	"+s9YTc7lMp3NTaJk78Y8P6Vv9vxGBzd7cogDt+4DjYlFmafl77xlbydiafWipZtgJVn+ISlfxX3vYPuLG60nOZgLKmDxyqXCoVP+" ..
	"0Oyi0x8AlY01QsF+S6aLh3dsAWf3wftdw+gZnR+HfKeR+HnQWT0U3jFcogtHJDYyBiQELSYIixJNmhVLKAmYu/jXKsvcadLAUUtn" ..
	"uXmHlmi4QvY0GHprrjlK+YpS9bb2Y8lc944uG4gYm6VlEIFT1CsCivXii6UE4a+7itnqV1ke+kSYA4Xf/CIb9MHcFR3yF8fh3Bj/" ..
	"hWPbVYzASPgz9oe+8mZVjEnqBSGULx9MKbkDnSYmMFX2SXJesTLVMjcky4EegL+aLzzcPHBGL+9Uj4ZQx9gIPxWtURl9iLU8H1Z3" ..
	"/0yijgHepK78dI5hyCXLLQKPYRnL9Rx+r1H3SZt8n6oatSVtbNxexcoanZCilQvrtLB5pepUbBQrCGNASBUaMKWBanj0bvBY2wdk" ..
	"oMNMr6p4xDmmrKoFSDZZ9UNz8ymIjLatYyo3T05FTMP4jSy1NymjP3yvSgsCcbjMgrxP3Q+nqTfPxBGKesMTAPUMx7IBkOwzits0" ..
	"cpxojctYARM36RVx+T+Ri+BSZB0NGh46g08dNLM4xE6wgZoSHRnCpQe3br12lqhFOpfCkihBZgo225wtedF+yfNSWptmha9HiUUS" ..
	"5s9ly55h95jvLOpS7ZgJSLrnz9f8V0Qmla4Lyj65Fv8ip8N2hTpMQ84CEtkxUJHrLmmoNmyvBb6MW2XERKqxDXgP6ArxKfy4jvdM" ..
	"4vHaZd/uVDnAPEHN7FslMfCfZWZ/PauHU9IZ6COJvEF/8LdbE9x2OqdI8fTBkBkCyTel5BhypL1wy0QJZrteNDIdxBrCeK0Yg5ST" ..
	"rfZStNaQDvxu+Mt6Fej3RcsWBIzJlnxPCXfsZ6RGfJ086xdKo6emDOn37R5GirW80JNBtQsEstyKwXtsSo0QLw1pX7181t6T58kD" ..
	"wf/TcHnsgvsp46BoVLlHSjyib13Ec55EG1MG1XmhbheN9lt+qe/PZXj//gwE6EwlX6dEQpnXs2D7VKFeBLCHAj/pJFYyrff8Scly" ..
	"z41XrdJydf123eOqDiJDfZFwpesa2Vbll9CT/O94OZ72ZeS+0rrjXLXE4Yzq5kudLhYE4rqyxPD3LLV6cuShPPDXRtvohlqZzsgR" ..
	"AKq/ucVDKwUlzVIITkOnTY3Xc65g4KX7e9IoJyqiGbXjdAx7ug9EcD7V4as4Vmla4dF5OE4A6di29XZC/WW1bkBPszLE/3n5CBsx" ..
	"WnwoBu9HPYxDMmYtzydYHUj+f/Spyn+mQEppM3JNe4Uf7BMHDZ8+RUu0TrAHkBhk4lcX9I4vTS1ppo1BXWqaPNcAcHPyDN4KSYxc" ..
	"UP0PJeJDN4wxbB0LZE5o8XWkJarKrR9k8Rn9Iwx5ZKyPKj8eHmLePFeoi8YydzD+qPrXZzgmCYNln0aFFWwzMDetIBH0EhQ63EZI" ..
	"tIWXvA5/4zsB/++AMFQgv39YZzyzZzQ0mwDQPAyL/L++Z5ZzByLSRQRd4caXVNNig+qSV52VvHFKXNYja0n6Yc83mWlr6/llMKW6" ..
	"T3B/O3+gI1veKrA/jVFGivprE6Ow/j4=" ..
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
