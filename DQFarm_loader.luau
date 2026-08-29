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
	{ seed = 4095028953, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4100804303, exp = 0, plan = 0, hwid = {} },
	{ seed = 4100205226, exp = 1788089514, plan = 1, hwid = {} }
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
	"jGkShU3JGR05eX46dTmhaITsKC8Zagy2+BfMmg2PoeX7oiBjn39uhmno42L12lgptvoOathB17BR3xpDYvTxZ6rcbeoQ7O81ZC4u" ..
	"AM/Am5vc++p7uI38Tk03iq42VHEDdiwig3Ez8l9r095TXNgvEq6Mo5BNNLrPpG9Kl70gWMtQEeukhzrZOinJ4p446aJGL/ttde5r" ..
	"Rf6V8UJPscjVlWRZscMG3FqDnwAg1yCqjr+Z7RkuuaInQnLWbEtseBRCb9pCStyZApWJqozaiow1RKqsIAIIeoYt6SC6iuDqSpo4" ..
	"3UxqCmSJWOUHbDAl8LFGC1u4XUqxlmhpMAA82W1R4hCP1yYJuLQGUXw4aP0B3EJCURx3A4qOqPv3QLLFTSFA0hzyuLqjoeGBkiAj" ..
	"wpfrxy73i5LnmqL2tmbAHjOwfdW5FWrhfUOXLjVIcZTFmgL3nUKxbnbmS0lyyhCCUAwnkkZDAp+BNGZggW43gbFzetECayDTCan9" ..
	"lhgHdcW/rIW6+jG8NlYgpSheCy9n6lAnfSC2z1SsbNbtm7ISW9jNPRfi96X9goE+F3T8bkKb8TmvtaXgNEum9FGwKwKkjrfzllN4" ..
	"lFFC3KTMwxl4FkisHT1T9A19YcoXjztSen+PruuQ5JtsXHmXTyq6aYPE7Cge00rsjkn5F0o196jyhLuN4VaYt0fjWF0lpjH2JbEU" ..
	"gD4nXGEKvLsW+MPFV2nwLDgm+B3ns3WVy+igurGGJDVP8jutJCGQQ2IoGixbhaLwf4LmmEMMGs2unnhpv0XGIO+p5QjvFPX3JB5N" ..
	"v3Kz5twdxHyhkIwSHy6cPwKo5FOiwPTymcLITxvYqeQzvlaKk+3cW0Ul9M/WfvkEu8oOfvXCFm+dxfTU0c5KQGyk0xIy1tU+zq4B" ..
	"PT6AFTCcNrxfefIbG30yNefGaLvYK1zvJWIEVTXJbERlyftHMrj5TfMF3Ods+gMgZ77m78t2H6DxIT0AAdh4/RFfYLmYL9XboxGC" ..
	"NMioezzbRYdXHFZqNqRN29f7Q0ORY7sXKnoxJliCEwFzrfRm1E0iYUTQPhNT7+iJuGfG1ieCKlbfltHmIAvfSjkMmzu2YyVWrWI+" ..
	"nu52Wy0WUqBwzis4QpLLFJMpc4RE15+QXCbSymcI2s5W8VPBBQMjvf/Hvc1KvX1fzmrzUJHjkOLHui/PZ+jVPAuMYjkVQrJCguY4" ..
	"6ZEoQ4jXzdj1pfft99YQxdRLe+QbF1aCIf6EqSSGJrR1Z9wFlypDA/c702rD+hA3ENfCzRE1ebHr1aR9dR1BOigTpAUKIRj4OxlO" ..
	"a5Wt8frpKr13+kta9Q1L+1soJ2fBfyA2XM5zRUo/8D38BL+ohe8MKXA3xZAFv7F3Y3+ioju9L3Yp1P35AXKsYT3ZvXgLPaRQ6Z1w" ..
	"7EEYql8fjmEMvGLxfqfzvWBSSQhnvshMs8+P+2U0uC53vL2XzwC12fwDJGb+fnJs3c6q+mtNBchLnjq4gzJWxi26EofUtte0MSQ7" ..
	"cMeX8qnUoXAJO4qIVe4n4w6XwalLujR9H5mHRX0BebEJBaIZ87t3iVqIedMIWpDQRaAPiDjrHZKe9VWA7Vlja6rlUJw3QXNu8Waz" ..
	"nFW5J2XNOMh5dSRWjSg+4ghecEXTyUcmtmKOuN1d/KuEGQ8aIVeri/neSXHMFOifHf422sLU8Me0nePhGx4JxAua+2Vg2vBmVwNR" ..
	"Yy+Pa1bWsMPpoFQw4AX3YqYR9BfoOvfQrcJ1OrUXA+Pahpv+hjNr9/Rq1x3Huz/SyfHyZuFgFT5SOEKlHZ5UTGjvoZBkXKNLMyRu" ..
	"n6MWxhOua7LHRSgIXzkLNClCU1Met5AeaxvMHUFgGruCS/QzBWFVZJPOxIT1FAmUiL1e7rI4kN3AdOB3FlhcqLlQGLMFQzr5HpvO" ..
	"W48id7gq5sS/p1BtHYlIeUS0I9nymKzrHxKvIPCcwNZB6LnO3lVrZJ1CiVddoaiQXdE+r2dA2TKUgStjIZp9WBLir9QYcnbijew4" ..
	"y9igRiDVKeBVcJJXEa5EKNWaUWAQx0ihCr/4IQNtz1ofBAf2I1GhJsmmanSt6tIvekuwc+ugEci7iXxQMI325DEVV8yEMfu/LumO" ..
	"7u3eQxhoQNwszCrbRfC0nIEt1lFChbq831xl7C/t/31BZ0jqqV+nfaAfTH/uVxgR9w4Z+GqERWZOVp0Egbuo5N6uftaWfwhgZ0hh" ..
	"GgU5LKIL0l1zwy77dSqIcLniIzf5Hgv1AezYAEKL6BCwNtUguTnl2heuYglzlU2kv+Rdn87n9JalQfj0//gt51OCA4inTDTli3Kr" ..
	"TBnzoIwtNBE8RIrQY6A7cPW0DkpQrz6vVVSwSJ3bE38wqV1m39DX0YsVL+wv90F+E1vYoGOtCTfpKgbfKBy+/S3ND9waegf8NUvE" ..
	"4Rg0peJ7TDjlaXVzNBb0QbRgbFiE3Mhp7q1/gYuebrFhRaSbgca99PF7gp5n75Q/G0C1ahh73Chsu9Kxyn5gTI5oTKpFNGgvBTxz" ..
	"glPWLkvU8d0aEl+Tt++TLpyjh+5Be6h4X1qgAGl5yG9tQ9akWIFE2eW77Oct4a8xOYhfd+uYt02WHjrSNYvM+m8iLhkrBycek/Ks" ..
	"Wge8VJbdVmM+L08uKdIwSgpvN6rifZwiF0GLXUTiY43HhNz4O5B5eISjsGx9V9f0pgFj4E1MIo6FU1zFajKMfpBkAu9KpEZ8wuhL" ..
	"ZQCwXcAvH+uGB8bTGzEoIHdzIIl7KPoUQyKejRkbEykXALX7VI2mYyPNTSpy0JnK4N1Gch3Hj9wmMeff7EE+fdpYC+7gg/f/+ItN" ..
	"xA7kxeHoZsdQqX4InOON7JPpmXinho/xLGxwK3NUirEvupilLYrngnG61lxvOq0IU9RB0cHWDJgDofYT3g0vSYYtUhS80EihNBEE" ..
	"e5+0wOT6aytOEfh1Lb/pBzhpSx8nTGgmnswt2ypnJqf7EoF5yR7/QpsPuPHz/0EpGoDGpOyf2GV3R/SgvuFJ9p1uISi88CBkn7Fj" ..
	"GFec2Q8eadnGZ+mlmlFaDK8ism2cUkmyioHHsCxwkwM/qzg3phjENZ8bf/d9jMlbhHwBpDioiGB+2LdZXB+nlRbhEwRjPzhrmyDn" ..
	"ltZdnMA1JaBzZl2dLaDDLJV7/Rw564n3P47A/VwIqIptGJyQvkbKJVyw4No1f+qlXY3kOcVuM9v6ajc4U9rqpbBKx9vwv5buLpmV" ..
	"j9tcUEhFuXicMaegsngZt3OnGGAbYOXOgQBXj6vpQ9sRJ/LrfX4+Y9IWBo0+7njdJMbsvnzvp0LWzbvdKQWFVrPpqC+qMRaIMAHc" ..
	"N6wB+gNWtbwFnnEv2i9fKTJYaEsBusNNxhm9qMjUBOTFBxNTl91FzrYBvcT4wzLaQO5nyI5x85tz2cgwluGN49sKgKahJBlUd16C" ..
	"dE8rFMNwsVXPxj+aZy1cSTymq0ru6r6YcZjLEdrqVRjsmNDwWIf1Cj525xlB5DEdLHQvQdl8Zh4nLy3KzZTu+ejceFAdfKvHw1NJ" ..
	"Zzm4Q0CgkI7UivMjAfhax1FBm8kB2bIsh8VcvWNkgcERzq/RLdtv7WEj66wTTHWhSjG1FBNqRadSUNxy9j41lVOw+Kq7Pv7t9s/y" ..
	"XU0nEsnP/BSv28Wk0puellkjhWgbveaMDnXgYeyRHEEVhZ97mCRhlb+lhE5syz8BJhQ4Ryxg3bXz1E65Ib2VP6lZdHuFNAtyLFVj" ..
	"KDrH25Qc8hd64fhEx7mVdLVJDYF2L+B06WS5ntTLrU8ROVXDW4nlyFbOU2u3IjlCpxNA8swHrLdPM3Ud+9esagqRwVmY9yFLJ9Db" ..
	"BxVmPNzPJ9ggrHkz8yE9CSMKb5ZRdi12aHefvqiog89wE8dsILj5Cx0pfpFxcBS8KevsjInuBzy24cp9PHeWXoesB7DGlOkX59V2" ..
	"zxRWPzlM/1y9wLjrdFWhGYymWC3r8ZLeNOZLm55OgcXowlMc4QQFAjPkgTxftbKQ0YtaKyAhSAi6xfXV+UYlx4x2AO/7K5y1Mlna" ..
	"Ihy0vMiytPycXBCz8/hIP4qByjbCks3hdnzIi+v+1xGhA7tIQWKiQyGH3AMTv3L4biAL1Q8VSC7ou9QjUZNANv6Acg/bffWcXYCj" ..
	"nK9XcSfP8/J8M4tAoj1hgFuYULzzN3pLPwezSkBJBozkUuSAyEfTC/0wDc73NnHHvuOHR80AlSCK+wApN8XNe6vWRDMgJm9LR3ex" ..
	"v7fyNgQy0rRrOLVLJ2mTYiTc22LbDXSLX6nQhr08TvfWoXjD98kTB/y+BSGkM27tJeiBPFGt0e1sJth+uwCTs+fHcSSWNw7bZyF7" ..
	"sqhbjQFKU0cKndvLvClv+Gijoyv4MOqjxSkgxucLLsgFeoHv6MF5AYT75c8PiV/rYYM+u04Flkv0YBY+cH+9OldoZucJyXqpwBxw" ..
	"hbwNjWY+p1QxZgrDF4aToG04gFh5MFc5+efrA92zmcqnorGMEdzPnOrxbifu2SY13PELH5IxXuR+9I2yIxd7us1uSinK+t4mQzc5" ..
	"S8phVg2JdOUjVP+ot2Pbt282Wig3Mkcv4kmRXMk7+Tt6PbtSLKItVtuWK2vPq+JAsS/oPOZ+79Gm5D75oQ/bgfuIbntpvWuZcZjT" ..
	"qM2wEW/BPnjpmrRmXoySMY8h9fzrGXmdUbfCJhtajrgXj+wzO/kvhS9Ai/eyNOUU2AxkHcoUH3UQNmZWGW95HKX7JC+vVnof/Ul0" ..
	"7tRJD/+SL8CmflLvHcvy98Sl6AtfbDDVdAhxFYykmvPbyKxf+5H1yG1Vghz/wLavra8U7pUOuEOxm4RJP/dp0nRiZdptWFGy4QPf" ..
	"kw/xn7VNvDQg8YPhh/TVtBJ+W2+cocFiT4MlRppiXoO1P8Jz4y35ax8kdX8JZOOwc3TOUbG1EjSDsENV5zo1tgBB+Yy5WbsJbDK7" ..
	"H9SSZXILj/aelmgBUvW8iP0jWtE7VcwOAmPqCeNJKjvK9xnv8TqbF8sgecZTT18Dmc1iUB/nxDdfzhQH3e88j3x/UUqtEMDow2CF" ..
	"9maDRQ2XAbM/0ut81tyzvw38qds2BhRc3jUKqVIRqvCXwoWNmi0dQKAFf2i1LXRtAgOig5j73eFUNwhAqry7yaRVvqdSN2Xim8jF" ..
	"KoSHKRbF32a27b+G2jH3VPN/rsvKALeTJYvcIcLo3E9jxQ4seOwB/HCAn78NpA2AeZZ/S3ICmRngz+W8gTnd8KvplhHyJooQSd3z" ..
	"NkzwueLCjxJVAhpmVYgnIbFHjSv1cWOvsDgqblw0lAGi9B3BrlBFnOUOiPBYU48mgyqCRgxR/NlizNPYQeLZW9lmrlULADcKCH55" ..
	"K1murivSRZUQmCLojwAURHcBSQLeViSnfBk4WarqOAlybkXFpWHoO+QjI0wM74eUaAr6Nds/rk19v6UHLygX6NFD8E/IhbZsld0J" ..
	"hQC6olNYvaBrvUWUGwC82XVkqw9mx+Z4gebDSwb3dHish0lYoQ5kMJ8Ww88C5zyqbfzEaL0V7qG6zG6Gy7D50eNWTC0DTBgYKF8V" ..
	"olTEdZ17Rk8XQAxzcD5eXL1khZVaUtDJPaTsYn8gI+HRYv6bZpfTcSjHW3VEkrPo0XLnphmHRaGsrorffzvm2TGzgFfaq3eg4HO0" ..
	"I5mA9+kgbr4y5tVjkf2ZIQV6d/vKudbTdmwT8s4p3+Cp2lua1cTwO4XMOZ/vzj1u8IvP9AovG0GV6JffYt83UhYruxsjLS0mIx1J" ..
	"zpJwdKny/c7Dh6LxgOkfVGr131qCFZebawBaYYu4NCwfCHfvM6t0NXu0wbT+mY5g8F2DYu+bBvD9t01ZrL9dBqSVgCWnqhBZiX09" ..
	"AjX8fbRcpxHf+9Qt2q5+fyERm5oQZK640Cn5oOI6kgxuSLwGLPUhQxQVaPTAl47FQlxORuE/R0fCoWyV9QYQXsdC9pWBQwK/TwBm" ..
	"pYiwTHB2GEmBYDI22OhPlQQKncBEL2Z1Rd+aXC/46SYcZv92NJRtkBTIRS3HKmIPEYm7xV3unSJ/VN5OiEQ5bLOb61ICLdGra2of" ..
	""
local PAYLOAD_P2 =
	"HGZYZ0Lf4cdvJdmdNOcqLgVmZAPLsCnx2F9Il5RwbrfYSWQS+Y8tabJvlNEtuPdfheajHMDXgzJMZcoHWdH44TdJ9fViArznP3n9" ..
	"yRKqJeoPBzCbx0fZGDEC+vTfwJc+bj6EilWbs0rPGzhecPaemsL3RDBP8B0mkW1srGaM6guu/KQMisvXhfTmn0sHHpmVB2YfmNHv" ..
	"C6jlpr7SvGTOsxDpMfrAENTelTIeIGR/oYZcdK8YJh3s3PS14Kag0vJlYoSa7Sot+NjNgA+FCGD80yePnLRe62Mo+S3tmgFyBNA+" ..
	"HHQ/Z9UG7rllDmTNxD7GJCv1JChBa847p4842NWv8HznYoIkVJyoYtOCV/2zBK+H0+ffMQjvWgw5PKkJHOg7Gn4BR/A1a6Gi8OV1" ..
	"PIdc9HM1Hn7A53SV2yNoF+7v2q52qB+KYtOvux31R96c/pGgxvRbqu5OMbfGaOeWc/d6BsM3DvVzaionVcLoRuIlEqUXpUa+rmJf" ..
	"CiU4WI6BuQGgVzibhG14VAdAjFHmRoIUH7EsEtmV5mOixVZxUYgF17wvMPRR3d1uxgGXBujCGsDgXstBF8e9yahLE6/ynstSwCfd" ..
	"8ZF+iLASQb0slbMUuitIQp3eaZMOmMvCYa+I3dHWbx3eJpj1jJjB364QuRFQxiR11zCZp/V2jzKQrC/WGrF+iK/sWWc0jLjVZlup" ..
	"YkTJhpGu/PFuny8e7MhqGLDVIudpzA7BOo0DVUdzBeMRgXJYMamv1cwVqWEcwdQWY/6M9nT6Mm2wOBNGvqSPd2i7XEJKv2Clj7Ai" ..
	"Q7DrM/GrCfMn4bmFpEXlVlKgvprVZHM9HHlDim4AxtaxBEmLS/NLPnm/gRSUhkEiSdWbDS19PxVE+C8Q4lSsiIb4GLRWC2upnVbS" ..
	"BiBssRrGJ4PXifSHgklaHi0mYKLHSYq+CA35hmteqp+f1WMDeufLIaXTjTOatOWX10ac/WhBCC2nOyP4KjDfJIgaqwu9KsIG0UV0" ..
	"LLlQr3B+f0Ttr44cLyUxBRV3t0w6MPrEmaOWTeTI7xEOAvMEN5lVjMhuSdQQNxRh0nEtDlf5AM9pyMXukdGQ8pGccH7bu6z1yH6D" ..
	"VTJgIyeh1uJ6YhGFvbXE0dSa92hbBTCV1phzPnmN9d+JQ0bohCNEoaw+H/RQZXaPHSk5XBitsMFUp6UsOEcGJclSwCPO3trjtsmq" ..
	"W8v8jLXzpMjY3cbrR0MAfxxNlcvAeoAhh+v35KfX1z+u9ndDqD5pzOx9LxskSnJavYjU9P7Axnc5LjWBE8m5Iqr+L8dBUNlK4N4H" ..
	"sjFD1iRs41drtLyy/W+01+V0yqa884XYtcfQAlMiugzfJ08p5Q89ca5M/T0h8PAhS5Is8bz4s84jj59rKYymsrh3eQ+3MoozTV2w" ..
	"BETMUJ5Q4sbftTvK7zHJYrX5UDt6Z1bWUIf8r4oLgDl7rfgt9zkzcMjhwH9HeIJQPeeWyGcGEMDHWLZtQt0YAcHTeeodzFb0gWGf" ..
	"qRm5bdG6JGfvT4FSenZiMihORI4Sa9z9aN23dfEqpNg+eOPyYyL1BOl33uRtpQK8Atu5KMgjIAnomF71AmV18PVBLowlnG0CaE/B" ..
	"ztnpNp8oe3V3KTBeILKGDSBz7+RlWbVRHjCr+S2Wt5EFaKAl3gk0Wff2kxECsFZm43ykDuctVVdfiU48KMm9BqkLa56BLiKOpBCl" ..
	"xFPKBNmq29cWuVK54o9LPZw15EE3iqe2tqTmhyZ4HvqavVSVE+wT6ukF0vpgVNLL5iRZvrJdq0LL87diFPpqtf86TzCy4AfwzBrK" ..
	"uIWINrwSVLmi7Z1uOWSDsAu0dyAseAIBpz3QFxYGMDD1rSI2xcOin77e37y5XNje8Cv6M84MS/IqDh1kjvbhzZeKiAKMgtVqHQcD" ..
	"HUrhNiuYxlWTeHA5xRbOURMfDkhWbOaJAY4wpNKFgtga0neNndOyKgCeSu0rKJXyP0FFANI5oXjSM+MsyzCcOf9mmEMUwoAuDWMs" ..
	"mmf9LlqYLUSpI6Xp2TpVXJnLlZsqSOhnctQuPPlEDAt2cftpGGabKZwC+WknBjLrN8E0GenDMM81GD1anLc9mOFaXAeZbaZw3D5c" ..
	"ZS2lEaV2Oq0sJ3NEu3CLWtTsKy0zJENmDuRNjkrO4PENea0IQ2TUJZz8KPDiK02sxytEG47KCiHnLtumXR9kbdFMIqJIJm7dkeqz" ..
	"Zv1QuoJL+iLP7adWhPP9dtWSg6d4p59ZUAvhgviVBTJfUYV0VrawP6iw57nArwhpD9MoxHeNQnjOcygMdgm3bc3371flGYvvcbxq" ..
	"HZbj/18RGOWaVVrl0TSMBtXqzH18aGFPRT8/omr70bWAqGDdHoSaw9zjvzZOqkXf5zbpLUqI1Fbo5zHH1gIM+7NhzMVKI1foGh8R" ..
	"nT+97S0GTkVwzjabjpfde7cTOrb+MKkTAfSQBUsigJQicwC46/ht+6BMSRhgp3HpAlN9IB5d9G1Xxmn7Nc1Cmb5tiootBhi5Uqnf" ..
	"pJ/rKhb1SAQlj2TcQYLMD0TiDLeKwBg8I+gaDTKlTevvkVdwPi7do5P5mcN32fHD1cnH2KOY7SLEuibz/aQ+9JsDMDIL3lRG0Dem" ..
	"17MMdprG9Mr/TmCE4UUhFUiV5i7PVIlkpcmiv95a63iaLoseOSNmTLXuPqTZp7gAdxpvW8M666xd8l+w9rXafBcMMsV8HPvybLYx" ..
	"hiCZAf8q5gjrEfZKWf+jE/TGm6SFMiB5dpSz9b9gO1STDDlBnC71H4JhiNPHoN3ziox6E3ZiFB1DgqxEHsj5v9ycs8sEwmkkkN9P" ..
	"vOC6yl9hJWyPH1/kWAUqZfltmL3OAtHkr03xZ9EquQzcCXZWVowI4jGso86l3vkvSeVWp+55ZkcZhA3DKRqPYs2utchVth/CqzD5" ..
	"Nw+p+u1s6OeBqBVmU/qkJAOre7+lvHa0sY1CGyx44V/0H9/p0IxMdG0VXQwoDfT/icbxvnPA39mRMQAjTLRLVX4OGT9Q/lMfWCL6" ..
	"50vA1QOJ29gyGGgoOJjQ3WWMp9TsFr81xRYSHfPEeiG1RLO/F0f50AK59yAiDjnD3VwKZ8cIj2iGc923B7DxcEfJsPx1Splb+5MI" ..
	"sFV7XFN8nhrcP+GZKa71g+b74wCA/EPahFCmmsieRuNXaoQccMG5jAwq1IFYjvPNd8kTtZeCGi5J+pbPv13irdlsSZ/w7o6eX4zO" ..
	"5njoYBYIBsbj4LA2ZvlFWonYJVhaoG91Xqbg6mxviPxWFciIaF5eyOdnSPmixMR+U/DnBqoAZYv/h7se/mEenC6bINbgjD0dkaoy" ..
	"ubQokhwLynQ9Ul+rf8xdw+Pqg8GvvkpGWutPNN1Q3kxN5Fu4oQiv/qkc/goWqSJmTxw8MaRtyepXoacql0UQ40fdZiEHiNx5Zot/" ..
	"rrLkx877z8GoskggaUwdr3jVQ9rKyql07Y8qd209XPwKERdwYZFyEy7MfuOeKT9syGo6qREnuF3cdklsqLoJ9AvuQx79ENv0mZ98" ..
	"3+xiXi5LLohDX2cB21ZgUQeIs0S7umcY6v3R0LrWgsiBwfWdUqe+EufXD4UBzChpt2+tqCJMo4pGiU8xgXSw0vBLlYIRtNXVk1Mb" ..
	"PTftc7n2HOZccjR9dAwgdi1RzOQ45qApSD+x4k7DiCON2LeHsVf2EBewV+jDCklgG8u7xcU90G4R7kjDnPdkboDfb4CF0slbKtX5" ..
	"nwMgFKY2EWqEP1i9vfDA+Gqf44Y1ybpropVJBPseK+eLgHUREVOQSkdq+wxK5KqwdHqDztrcQKXvnX2agwd5Qn6pScIGaj1QyyJN" ..
	"5SGLE7icXeLBlhPn8Esem5yp1ItMV7WvsLQ03Fb5HiNLRRTdgqRAfODUWXdipaDRZb4fx+PowPbfCRRjnfjGtM74kwaH55Let5wF" ..
	"vCqzq8XKLMq8eqe8Nwm3voAp0XVfaDayIJKxC2HsbPgf+//+wUphQX/nvZqC1clBsShofcRE6i00PbBQRmh85Nij1tE0nv89nWWN" ..
	"w9tv/lqhiNnNxDo72ZLWwJzZIrO2kRZiul/uAk4BnuKTmU6MDkyuLmzFg2uqWSmflk34+btgof2W1wUgyAsyo9dk3jX9EYnoGhb6" ..
	"kCt1Ztd8L1WEKFCkiuxp2OjJ7ShdQun2hC05eGBF7VxVVEsHSiwUdwiB/bf62PmorEQoDPPLAfKjlSHKOKvtbY+y0nk8FzB/mf/r" ..
	"EZsT5C7bhRYgzji96xI+18+6s1qwBU4XR83XwdTQeBv6qbXlzKXlogRzlWQLAEdbZ7aeO1yRGxcoT9lmg54ts4m/hglVLpZGYAZf" ..
	"Nf3OVKGybHISG0EPRzFx8N6jimmHif0Sn8b87YNRjZvrjitpBX33ThuWwQw/mrcOEKIvVEF57gfakc95ztiqJP6WTVOKonJNggF3" ..
	"lt8N+CoH6NFVW/8NfODkBUCCA7TS++VH3KuPPliFdPaE/uwF8dsqx3ateIh2wcCvk4IZy50+5dZ/88OBNESZXLvOFsks73rzuXbk" ..
	"6J3jUJCjBEwQKzQEzrPdaOBPpCcZFJh8T4iaAAO04yLEf5/quvDq47VoT9N12fYDTpWb5QBGGBrYh93hGrOJozbtim08yPsz33TE" ..
	"h5SO2qwqbE66a9K9wWvH5YqJHYw0nxO8Z55mZopxODcKfEzoEb2+ECWLgnF/KjTNFpWcv37za6C3Yqu12b5TS+TaBYRAtPfHaPoB" ..
	"ntvpRJqPuPwW/SWARlNSYffWrYcz3Ma/oph97TrXifGW9UXtMO5g1CeZBIImsibkf2QTxZQKR36ipynCfBj0g9ab0Qk4BIaURuVu" ..
	"f/oulyPdQyEH3uKXHqlCR27UDwZXTUf9B4ZZ7DLti6d6dOAPFRb3rrK4AC88wzypAbyqunUMP9z8FywhAd36EFkCy+yQwV38Oqsr" ..
	"2ZVaH6WXLAPuS4u0dmNeo7HjeerpE18AmlD3ucloX1GvYW2KcwLBzquUdCqwP0dCNPgNqbBhL9rf0XHUYz04SnXB4r0Ric51oH4/" ..
	"idU+kSnFeWymSiqTXZo0vtyqIOHcl0BaY5/ariAxtZVnQL0aTnJrQP9GXqHzcqQfgE20ay1J4o2o/6gvOf0a3Cq1Y//FzdGTpP3v" ..
	"/UK6Wr1MnCXfIM2yXV6/4kwpdm9KarNG4I1Cszf29rsymUxP/uCeKnaJ3r3DtEYjrUVxlwRr+vLOHjFawPpWiYDOztbgShHBaqTE" ..
	"uu86RbSEXUEjuoUTqMxpM45iT4C88sJmovx87pRAMU2Fp9JfKhtlNWcVqTDiFfSvrnIfmXfbyrRl4RyAOTsX+YmeOyJp8CP599o9" ..
	"41VW9K+CeRuxzbXAYCJvUbB87hWS/tJRZcjYC/Ih4pALzYknlfOGBPr3nnAuV9d2KfKNXdjKfbifaRvaE0l59q7wPb4/nPBc//0J" ..
	"GDEvxvJ7YXsYWV+70TE3J83VlWZY7LQyZi87izCQZf4cPluixGW/YBYJNhmMRg33KzOuVoFpSXAHWqxI5zVohy6w5kFsQ8heUFRO" ..
	"Y8ZMvbzCK6p5Q5VcIrAmQ6ioOjo83PKZAognV+6WmzcGW5DH+lHS1kE5OdrLp+UfxFZjA8ghtMQVus3tOs1RF9QEAMHKzeiC4xA1" ..
	"dN0OPycZzsYfFiLklebGJgbLR+1LKJ3AMb2GceluJNXoSkmK5CcdMjd8RyV1RSXAbOwHJ3krWIqAFU9ls6q1smuhAE85jx4zYjQF" ..
	"3lUZ++7DjsUqZaz+svkSRJlCYDR6pQd5LGvvevDe7PDNFKSFSJ8KbOg3PvvxN2kycxCCDlMwn0DhmQKPAKnjVBNsMf9h13UG1rn9" ..
	"CMLMb3z1IqrxrCD0PiHz+VxS32GVYib3HHkcdczMW0KS/pYmNOWCRZcnLIk5LDeO5J0kpH95DnEXKWqU9cMJ7K12ClIVknGN5J29" ..
	"rfctt0AC/V3a+7xB0CpJU5A04hvqvIyTRFpG0r9MOqE8oCUgl+Vm9dTmx7AZ7rXNSkUHCbrSIwcJoDwzxpRVEuMBDOLX4gDqw3UM" ..
	""
local PAYLOAD_P3 =
	"F63BOUtbKII0EtKNwoWwzZ2hfbJWp314rQ8G29KBzfiT/joatr1naPSsIBXjxjVBgcUWKfQiuDYoTLx2I7axK+vDJiz9So428hyd" ..
	"fwKC2udWltKXhM3PRCLlkWVfCK71iODH84edWfY9H0ErzDPiA6QswNhGvt+cEnj1jCK94BHPzVcnejOENwQ4qgeVTurIXXz78crt" ..
	"az+YnMgswxOGBUWkwqMDWUP85uKW0likfDsP9O180AGYmVDz5VfwbZuOW5ThHPZivIYFbqx+84kB5mOS3KnxvRI4/4ttYm+Kh2Wv" ..
	"Cdg4C2raz9SPWHU8+SDnhgbrTro75axB5bUnD/JZ4WB9fYjNgTJ7HB4kvS79SZcYZGebuWK4EC3yBPoUpz2CH4lo+MAcQ7NkLPTy" ..
	"GZQnVlcKAt5OpVSvl3I/sntF/a5CQa8gTq2ji+fYnkqMX+4uQZXJrMSx4VKb+kv4lL85zq40vw+x6Kq+Ty+mJIYSOWhLtAG5fUqX" ..
	"kQusiDlsOA2SrCrYcTiLWPtinkhFg00BsQLxAW6fHCoHX/aJN9gCRDAYcgqu2b/DiMTyYOXZ/XvTMUZY7Wq5gCOeh0yIxr8hzpkw" ..
	"LQIN5VNIokfD2dsOQxI+hoi6akFM1Zc6eXdggOLYz2kPLo/didKkm+ZkOikfVPLybrEviZJLo/moS3x4cl9VKzrRgCuGkeOKjsQH" ..
	"aOwKj7SMVE50mNYWW3jKqdeOjLiNMWXMNJn3XY7V85WZ5q83QuuWM4sgPo+FyfMe8lbaFKXWvyZWB6a8iZSEZnJu6Zh1S0qJ4AvB" ..
	"HKQ8T7KqlhsSr83yeWvA7JwZaXlSVZHoW9GpJbp0WPaN/yeqcPkxGdsa/ISWlfhzAQvkBaPiob4/Ix/ACY0yE6u5UrrD9GBcAK6/" ..
	"hGMdxoS3av/piqNtxIJaLnjOoQLuhQXai6b+cGcv7K/30MLRmEjg3UFzl5QEKgMTByKDdslDLzs9F1/2T4Cl5Xj665qIb6twGz+d" ..
	"7WrVEjwT30VLmjtVaEqGvMLc+AQxqKc7ulBw9p4MUaEc/JpFFeuaJP8ogoycI9HNJsQIb0au4XRqhdExZB3ixZenYydXZVYLDIA0" ..
	"6u/7ZK+0KTYqI8J8bDPHlWc9Ja7ZERn8v4y41v9PIFGBoALGNTnW9nJBd/ksw7rmkvpinHkI1o/WeOM8531Cd4b78P58IqTmGhXR" ..
	"kAaQHf8MN76Q7RW6zEP2ZE5AGqrtQ+DqaxaMiNyncKUYp3Mrym+VbUitJvB3gxdNtjLB6hHV/3OBjFMCT5/81+J0rctnjTMCpg22" ..
	"l/h10aB/nWi12AW6J0+NWgnwkkYPqfW9pVHOIIuW97GqbAYqBl7Mzg8h6AbJ/FT23g2MjiS7kxOqx5Kr3GJ+zRAuKucq/mpO625u" ..
	"bEIQkwt1VLymVRjnHMUxNXPwlTU6tJX1Fj7stNTlOVDfT1sM0jQQyzs5teH2XQdCkTgkISOD+CbvhN0nGQ/lM3+blFmJQ8Ka7W9B" ..
	"XBUj1FhsYzkrtb219VI0jNo90CsRaJ8LTQPTVaLVVVzHjIispbb9BAlydYYinyjxvravUTTE1vIFu2PfRU5u6S819BGAzmtf8AFw" ..
	"PwC083nFBCDOlhT40vQRj97BWRVumg+9BRk01aqH0cBF67V62I6BghzNDUrk7z+U5NRw9HKVPyDfray8H7IsMFpP9vACBAOdq9wi" ..
	"Ofuxrm3d3clrkkMq/lyRDaJmPdDnviwfzTdKlIUeyoBzMbNHjrcPRuy39GjQeqOzMGBDJJ6o6IvsdtG8bthx1vSidMI0ylnSv/Ty" ..
	"uzbAW4vbObINfqZ6FqdiPe5ca8QEpcMp/OSZLQZVM5jUdfyWYTR1H5AhQAU8CCvKfb3QBU21jFmgCOfdj1OLatwRrEYZ5Z1jEIJd" ..
	"1jF+gxQyNC1u9eOb9O2WppLqpfLHGLFRcuO4GPBCR6BfVJ/wQYcy987lb7f4P3iN4zfQOxPZMvOhNTmDzpkeSZrPBt4df84wlsnP" ..
	"Zb9kDNMJ5ub5NzKsejRlngwiIlb7mzRFkuhaHj4Ppi2O4/vtDzwYojdG0JgAYdVKUMzAR1HU8upmpCgZSSoj4Owg8xlWAQGaLsIv" ..
	"+QkKYxvL96PdhN7eQN+fjF31r1YiwWm250X2t51jnm9UuJ5V0SqVkM3Z1iVz4uVFsYsgfmuvKDystpFNQtsxPNHkN0u6lnQw00mV" ..
	"x357/nUlHQVTEQ+Ytg49jZu/Wq31Iwa66M7SaqB4odYBBhdWYBy/9NCvaJ1ePDUwtlbyLhHHPtYl2CxY1Up6Eno+2EZpArWTYzaV" ..
	"+8byGgp2uUpyFbuyIynwDAO6M1Eld9O4EFX169dOhFcn2yoo5lUXZ07R8bc81dU8ubiAaAofZNlpgj+cyX3PcJ+qw9JzCK1pIN6w" ..
	"eAur7rp/MQktC4KRx/cdKLsdOy1if0I4Uc9DoKXCh9pkym9/Jje0jBgJc3sxIiC0SqqH+YklnhVN/psTywiVeCnQ9vHql4JeBzTx" ..
	"+b20Jc4mxYQw6Hg3ui+XvpSr9zeVgUJyghegMAQDHAc5UXPJQEwKrtgoHeVeqldgfLsOPN9L7B9nP/jiqsLHVgfF1T1FdoMbwbd1" ..
	"g8Oh1UoJU4632patY+sN4UeEAvgh5i2O3RqcAk6dBXB2doglPqK3itxZci7zrMXvLVAYSIwY+DDJbnsu3/gF6AYtTljO9ZKl/Ex0" ..
	"aNcr6npTFYgGQByY4HW3v7e1p0q2qLqbZehPYXPsFpVJPrRrs3wRw5fQDVuHNszNJJ2NAw7/YsHZqlokALnFBlhUe2IP7sNMeKfD" ..
	"ncrTQeJIZnBtxawmgOpg9trwZfYFvS06WMrm5zAYK/Y33IkOsJl4OPZs9WDylF4pd5WhQppX4ID5EgPZvF7Fzkmkqw8RdE4V47pW" ..
	"n4+mzD6kel58puWCh9X1Pg2Cyw5CaPUWvDyrpd8tFBzEcz24JBQas9X98CdOwkKD956Ik5oiOQKAZal9Q5qsgsKUrynwGzf0HPn1" ..
	"m6bwXENjeEuOHtIOZv3vVFsvgQmoSPwres0qQJgx5HVd/ACe019EDZ7ESnfOydsIPgIiwSfOzf/zrksE0aGYIlln4MAHRpM2ngQq" ..
	"TUVqJSnwctE2lOmcD6GLaZ/IgIgBZOwIcs5SKv5haILFbYUwMH2YFJKAMiWn6f4g+/jECyG25+tEvlLudWv8iPp1sJNELBc/v6DZ" ..
	"mdyDLKLPPCrdVPYskB89NpNs5Q+18NfuxIqylhAP5WwyqrjyafxA3XZ/L067kKQDQNK81C6O8ugIXNyl4ITNN6hxV7M0Q+WFe6bY" ..
	"Gh6mDf6oFkpRATudJgDvYEDEp8hdeY9x2iZhkyENh24/0Nh0qi0vlEotMegBELjYydkMuCZxRPu8eYAPTJmlWmH4ZJ05W3IIzzjZ" ..
	"8mSVmRkvFfGPVUeMgCu8cRGxKaFG4MmImQ+RHuR9uxclK4WKohYDVYBIGeqkiJXwA4rO95ZBQe7UUvIAjyyCnWF1Adsu/4yO282+" ..
	"qb6/PHtbhwxqRdIDZ5nOrxATloaLe7ol82axT/t6R3b7xFWHEgvRi36v73KuzZgqjD9hIp9JIj/LvqEaKLgJnz4Bd5WP1MEdWavf" ..
	"mTYEoKPZD0vjopEAH7k8bYHCSRkIo0BBpp6111BsE7Njjm1j1JO6wp9qcQj1Y1U8HSnMsq1anHr3toF7pcLTBUdTKNlb0nwRVykJ" ..
	"atNPGhDtmx4SkFHYvdly6HUY6B1LLqXi+44C0AHLIe9aZslGcn2DuO+/8mKN5lY2K3j9zThQXruAXUOZ6l/Z8D9jXf1/wv7UR8SE" ..
	"pyTlmKGMLB0yjPYuJWW99GSGWPNDDpwF5ItDhTHDD3Y6Jki2xcIBE2LEqL/Zl/E37IMcpzWO786WdZWXXozHbsYW57LmNp5wTY9c" ..
	"RcVtnjkPLsV5UZIB6NaHP8AiWzghfybnx281t1UZkerrKncDf5R++NZUO825h1u3HSQ6bYoD5OmB9HkgQYBXjOcBglZA/tryB6aA" ..
	"vs25I1P6kviPZLOd4Ta8zfy6WmOhrY5owVK0w8iXaOzWFzQmHp8uajhu7UbMnRuTOqUZGTK28/91RbLLHzxECGlNSK/6HgqK9Xko" ..
	"emIavaTe2RFr7aFjAUQR3g7Z9yqZf7UvYgYk/cCdLyq/vvReSmXrxYQRn5XWQ+8YimtPKkD/I41P5fUOeHTCtgqCALsJ2yfTsba8" ..
	"nwvRozDOgnfcOfK9dIwt90eyzHZ7q7qoI1iZiUnTrBVP67tzIakIjL6SAI6qNHxk5ITlhqQZZ8puxPfgnWW+94cEKiIe/EsS+tX0" ..
	"t6RW717gTCLsosPQW7WIgRtHOC7COCToDxPRKyDE8VjIRRA63mBzBcIwnkJI0Z3CImkdNh1N1NS+JnDDNe4vtv+CmptGB2Kr8xjz" ..
	"zIotg/2ujjuTfT1xUXVmn3UtxHb44A8eStJSJQTWMDy8XXMIjk6T/zmvN9lpX9CuhAGExo3mtQBFuLXY/5vTkNT209P/ftoO/k8z" ..
	"GYrIkBi9RyRY+V8OnKH76B21H9Tujl1SV8i/k9hkZRNvAnPuQXv3QFEcReQ3u2Ni93UeHrTMrHh5vDBrgzuBTpu6U8tUQFv93wuy" ..
	"mlSGQBaeOAhON0buVsYvt/O/GAII2/QQ68HL4nacdpERZx9Il3IyHFL1REjYcBHGzkfOB8wxFq2I9ngtNbzcPyV1zGewfXKitemQ" ..
	"eC0HBxiE+U2bcknbmMLbU2t2j2c7oaPIx6TSgfccb3kJwoklhl0La2QuBXxWKq7w2Uqr/Hepxvl0qqwxr2uhZpCPdwfnSs83UjXl" ..
	"uBwS1WQn4IkyMtbd8/ZqLyv6hh2LEKeTBZiPTCVP7/+0oMX+RH92scVgSUmT0vnmueSR4z1qLmiddWglLOWpAxgf699GkqpUJqmF" ..
	"gRAMJEyurYBCL9onZX379PB6wipDkUDPkkpKpaKL0ZxkKOMSyXNIfoNCY3BCuRzJ9gYIRfKSCLKRUcm3/d+hmolSeRypCcDDYh+8" ..
	"pYcXUuMJQRRtmfkAmuj6t+chwaF7hrALvhh1BReikmqKQ1NUZGQNvdUlXsQ++pEk/Yk8kb46Cz/Igauoj7c7hIhbd9lJxqNVWii8" ..
	"OQ9jkk/FqYU+0mOUgoJyD1ra3mfS1U7hfvAcK2KtF52hzSL7k4SeXgU5NFQvNXpdUobQLeGqH2UrU+8R1A/bdRKmjsvXiBvoOITe" ..
	"i+e+U4PMkVsl4u+2sMDLFvBTHkdbcCFPcnD4qGu374pY/ZtguErN/3dCNZhKIKga/bjVv1/un068Yhy5PFfrsIeQvgMSccNNNS6j" ..
	"nYCXs5owYI6UERp/AVOVlT0tbCB56BJf5zKu+qhGKXVpfcSE/ZPmFbPJtBX60gArDztRUqhuEXZepGIY3JLFZbJU/Vx7zDGHDB2G" ..
	"FQ/J3CRQkf2MvN1KCU5dnPLPKkHB6XOKF+HiJ2uHEOo4R78CLgfD81il0ScZL9AhDiFFGPGUXoEAVMml3e7V2v8sHgWvBnjaTJxo" ..
	"Mwh/qENLE4Pj2eL6v1tSUY4YDqT73CoDI/BZknIUsR41eWpe4nMHQmfHWA9+Sa1qqqqv7IACBA1jrkx8ItoYq0uBGbxKj8jpH3+a" ..
	"o/cZf8hO3Fw09h9geGgfhYS0JFkYDk0/DUGxDXFUTksQlB8TloblX37Gevqbm4W5X6lHU10QQh/u7rH6grn5Tt/4x/+cyA2lkKcD" ..
	"FvgHk4nfPYlujT9Yo9IsHM4ReC2GpmoL1S1oVMQxgJk8/q62BbNCqjDtXtDFtWmaaM6s+r7u7fUY2vD9v6JdOYgvyQa9SwriSpUG" ..
	"xUwgly7tbbSggVu6m3N3TV9rTWeUQs/TdZsS8W0Pi6HpzJB6RsQ7THSUhthxmyzA7wZZk7w9oJbcYSCaUeVhCIQDBGjS691U54MN" ..
	"/G3uUyP36Vnw7RNz1v4deELq3vOQcyOEREUzFUwuGSTZhKebI5FxlaqU6tGU6Imd2TVK6W5z0lcwV3v/4zgysyz68DgB/3JmxmiM" ..
	""
local PAYLOAD_P4 =
	"9TYacE0w++dNx9XkCPHcNLtOmgUFbHWVWRw8zM5SSL2pYfvqb4MGdvueYIPy0gr85JbpULnJe3YaZBnNPYk2CaQpTzUQHtSH6soU" ..
	"ibytAR5WNXM8xA83ZZu883ewzijB0wWlQIwS1pVa1SRGy1onXNNNA3muN99/Tw9rMQ4FuyOWgUD90QKnmZUjDcWaxAb1Vgp54eY7" ..
	"tpTsRgiCnqavaM92YgapzjCoTDLkEWWmmCoItaKpSNEzj6qr+8XIqCyRogk1tRJG0OIrjXY8t+mM6jOZY8V/CY12kcj1YKvCidCr" ..
	"iyj2MPn8SUjq2DLtVCHRevJX1k7sIjPeWAysyFRHkGMOfu2dnCy5sdXbw3tvcuR5dNXWWvwRKiACg6+0tjX0/cezxHJOsr+YNW2k" ..
	"gRfhQkvUjPpm7rXO0WxDUZrH5HK8Mc0NBdaWUqKC0qH4k7STEUHu52w7w7H5/RIMHYUCKZn5BHh4FUgYFiGYQb+YzO8biryy7iuh" ..
	"ta/xzzhz7PzCCNLd6jIFMOz3eXR536GMl+EkZFqR7iB2wUUMduYhUNABHFVF2a9IKJ0qkb+s2eAcZ/9u3W4JcyQF1PTxqFnmThQn" ..
	"B7Jt5HHXep8wQJmbgCB9WvyCvbMLEoEOEYvCrsNuLkO4yBENp6M4ieoKCUDaRIeEqXHlAmrdw4/x2T9HSmdVifH/xzCILv7ZwgHc" ..
	"oGrGaCLMH9dCRATj0a5TEbRIrQsSIPztpHzdAb8MANIsWMzR3ovE9VhUXq2T7MXFfjF6fcmJIijOOwVskn5l+egFk9Ni5/Aqycv9" ..
	"a1Nsv+mBYxD02cWNfAGTY2vbYCObD1uizo6XZzHlt10rZvpmyVXixMZd3cqJItT0fFkeP70E8KmaJnP1i2bNlAyMJq6xEKqoBFdx" ..
	"p5Fcz1wgm937L04XEICvDvheldeBpHCW15bemEOqp8+liWFdoc9lRqO8ELXolcbX2B+xAhBhOHaryq6jDqzA9c0I9V6jcUtlXh3J" ..
	"z0QWpvIeuaK8kklIK2RL64dNXkVlncKPsgneLmZYaI7TvNIt1yltfgn/mJyB9b3iZD9m15hECivayHcJd0Gcjn2QbCZ6RP6cfQUW" ..
	"rmTJUnIEf33vvN7AXtukEQQcbzM5RxvPazR9o2cx///n20Jtj8cvUjlbQQqvU+tSquyUkpDGmSTL5tleaJqbZfqPHcW5KxAmSstw" ..
	"yR6/dXDduQkqicEbWXLHXPEgsp5csWPwuFO7VpldWP+Eyp3hJkHIgiJzW0UPbD9VtOvXStsr5McRp7RiXM9VltEZClMToMaCJgJw" ..
	"y5eK7V3s2vpETQK62pzbcX91UUbv4Ra3IR3r+g2vkQHTL5P0thfpx4/eqkKikamdcoYWkY94okXo3Y5UR55wQg5JIp3i7YR2zpjC" ..
	"jJmpEr2sMc1BZ2ftRq9KbpE0NwSxOq49NxMZq9T9u5dN1uYQqEdZJGE6WA+KCyTEtdqzOo62TxmF9TN/nBWYju5a7xL32USUk8p3" ..
	"qGfe0uXmBVSMURU61B5/728NAu/12DYmBkV033gPi0CFQs0Imb+YM1matsyKv6wHGoeqsZfEuZKFZh3eq3en0Nl6crL7WM9RXs++" ..
	"ocpwkVzK7YYrSBqixs7UM696O1DiG2H/O6wON5B+iwZIGjA5jm2jrkv3Y4A9/hwLaPHukiPb/T5wC8amDSCuJQSB46c+RjR9MObC" ..
	"fBf28oOAPFz8VGLmIOw8JUM8AvAPL08wadtrYDw6MIbpki3GARrtEB4IoVPao1H6KgtgWAT4MHTby9nKhG2Jf0hcrDTw8Ci8TFxW" ..
	"AI7IIjzldc0iMYhwENPy4uXIz8pWD3XgHnlnBKblo4u96/qfzFE6Q48CoWMzU12iPVTHLDXZ8wUhp1abFVwY4ynRWLJC+OFZ2odr" ..
	"NqagFo/p/ZEkuAsDjLiYs1IfkPcLEk2jnru7jSdEc1s/WFWrbP3MJcmQTjwFfxF02JnfJeoVVaX3IVf28wxjzhUosNomoatHFQ+1" ..
	"+eQBF5+Y7UUK3Uwy+K5FaPjhxj07x3tsXk3iCIG87bwE/Uu8uo4Qh/lPBvVeremXikuWZusmEPYVcRVmLY+e4NZC2h23Ul1Un05t" ..
	"fJwCbcCA79SMLufx2ltobnpRVGgsC2gVMhyGS+QRqiTih3HEZanyyZKxpLneHSc6d+tcbev/3QxJxYxFkuIxSUIeZboybkNXqjNk" ..
	"kiJoI9rHluPrrcc0vIqAtAS7xZ8KeGU+3FHVqmjMNqFY8rPEcKwguWTuFTWoDTolZLw073GI9prtQfpWT/asMZyB1nqmY9NG3bej" ..
	"CIRmjB38o42Q2eoIqjvB2T9pA3nTRiTel+SdDWObl4INiIiGeoHhLUZr6iIsQWeN05bYTRPJe0/CAlAvfwgorDN9tay+grBOs1E7" ..
	"jTlimuFlQO4Beit/90LzkXnUDmsXfcj8QfnkXTJiExs7MfCLTSfMa44uZhbw002ZNeq+vbDufQ6UikfUQissIqPmL/AkBirCl67p" ..
	"MEeXUIwsQPxguRJjF4CrwBL5o0MBOFOjUurEslJwr/+1URiOoFSUUT0xlvjzof6F4B11slqcq2R5zCDijqHtulporkKYglXpMrOe" ..
	"AQFdiCptcTm72ogvdipkEKSaXCStkIBCimRJx1Kt5bYwr0n5S44ZguCj3vInuelE1FootiXVQEZtgw6aCNoHvZbmLZfhp4rA8oU7" ..
	"QZTvk4m8Cx+0CPkPo0OdHpzLzKSApleez2aot4OxnyZklWhKwaHscAUXDzgCp0Aqt3TTGMmp6gzxok6uXnqEiQcbJaKT+RKi3jAV" ..
	"K9P82upKKcOk9rhiq7TYVzYJ6CZNRj2/r2GinKzerzHEGrIGcB3ETaGENPWKWBKfQJaMLRekLhJJf55mtb/EmPWEtftpX4zVtu8C" ..
	"V6lkx1PYlCN/YrmLXSB0sJDe9eqhfod+RmWF+LY0UF4LSz2qOAH5yt7nx4fjeqh1ilCo9que0l4yXdwaxt/IXPVDrtjQRfteB09b" ..
	"38hR7YtIecTcf8IZr3CgGDaRbKEoL13o3g4Er7dH13NMKqn4deNFK0xTEHhhfyZaWH0daqGp9pvQoLVQMIcaaE6oNnhuo/YlIno3" ..
	"NmW/pKxRWqhRrdMv/gTrRIkGyhkHUSMufbAe0G13hvc2KcWMmKThuSlmBrjzeDcD95yjRLq6XRih9gOK0p4RyrWRdZcp1yrWgUvv" ..
	"tzIS5rWuWI0qGKGqyAkBD5p2H2Am285gu6dx6UjNWbsawzWwRPC+0C/K1FJNKSS3qRPzx3KoOt9Cf7Zld0Hknzs5ZtKGC80dbD3J" ..
	"hIfno7OPdEGd+RRwp0IWq910zsYUuvqUO7Ry0ReleGs0muSH0f9q1UZulQd34vn5Hoejmd5q4lt+IyS0jUq3wH897uIUlr+3s7BN" ..
	"rElVTUZmAzjpePleq7mwKCsDlvwAC/Je7LQ6gDkkrehOMYBBobV4/4VG09igicFArXdAnRInMIPteo2JrAqLnntuNuNj+ZKAJBYt" ..
	"hYA01s2/Ng23pNTg0y+dRJdD5EFSXoTqOspzLF42R5QK44M1IEn1nZedQqs/MP4iWDAULM8uXvyTlEHEiOKYe2fj8W/IMUWdrb1f" ..
	"PArwgGPs1/+IWneQWQJHWc10/DDu434IHYbMp9tpM+AekktApJRbzOtMgXFkU16uKF5C8O5h6LmZsICiAvw/qY6wyR6EacoD4k31" ..
	"UmK/y6Ex51udd5iYGOiRTqF9m8B7lX4SbGKRCEbzvYW/yCbOIASXLgAGOydDWj0h9+3Shw9XjciG2dweMwrSp+bcyRUDV6ScjMRM" ..
	"Az6qo8CgoAWQBd25pMGc1m9BxrH/dKwcWozYiXA7yKlMGw2J4nC+2SS1MCwGY0lQTMpS01Pli3dQiL/WuYKxrbkxGMD5J+6GmXmH" ..
	"CM7Ju2hv1yLqfs3YViEE8CCBf5YtCJ+qqDo/JyttlUBI1erMjcdCVngyGLg2yH3OjUnPrObhJ4av8liQdvebQduzskIhkO1OSa/k" ..
	"L6v4dUdDvLIkUg7ASHT9OhlKV0gY9ku8zDoeWGO7ITKk8ijuTpy6TNT0iuFQ22CG1QSjQ9xWyqHHczBjUngpy60XR8+boJZ1mU0Q" ..
	"3qU+bQ8WrGjzA0Ij1+yUOpAi8TRX+iRoonTlna197B4Gd8UrOT5H0h4I2Ry6RKo037+2w0gB0FzEL1MM9ifre4vqIHDVAjKSDYFd" ..
	"NOoWnfhUzar68Oqxg19DHZ1d90YHnM+xn9RSldCI7cZVHcuTpyPYiQAIr0BpkmYeQX7ytD3KDL38N+SEjPxyVyhKIJqVMR91MRNz" ..
	"S3J4cqqm4iCXYwHUk9TMifClt7l+cerVoB+L/nyUI4H9ktMwcisD9TtOm/SU7EUindchodID4DzzbEJ6L/n32TxsD76xV6zY9PFh" ..
	"MQv3LGa3pMf+6huCl3D2tKmmqmtczQ070hOfCpPI+cY8iPxkC8teoFWr72+Dd6K9JCgrm6/6yRb4ltiHtpQVxBNHhFEa9d3rip8j" ..
	"RgwhA4v87ftVx/ZwOC+0I/7XpcroXDbPehT5F+a90CPk8TZ3/90XuqptCRzJtAX9OZ8TKGzuT36IT1EvUHq1IhgxiGAKcwdoXKJN" ..
	"H+f81ZtTd6HXMzoP3PEUvulLd2E2vGmzckX9TkZ1UbKaN9R8BMElpqd6uwWo6IiEw7U7+gysR5lGXoZBV2aPLlhVzUKCrnj4svxI" ..
	"DB8XmtuIDzYAtVtO94w0Pxjmi6cxwqb2rZelrdyp5SArPNfXuM0j01EzvMqiMsVq7EB+fVeNvcA1Q3KtsF7UY0YOV+znAnAGRaLC" ..
	"mPpxjJOavgTXDbaHd2tJWHvrotEDy8wZYdxfpyn2rEtWCmnN5cgwHk4wE56qaErJclDyMvvKO2jjhiV1mgH/0FxG+BuG8FcJbfXo" ..
	"L4U5O3ZWFR/OOIJEedawc2c6tHeE083zERMiR4J0pgJDOO7gCkyXGJ0xqKygtDVfJ3eiZ7p/wAkDJODq67pPGsxko7oGOuvUPqJe" ..
	"BGAMZgLY7xxmN7gRZtYJMd8FxN9bybYAqUPwN5m8lbBBJ3s2zPl49xd5drcIUuXnT1f1khUb9pssbyf+99kBuQf2Dbz+Y6lDe03I" ..
	"T+Elu62Qp26i0uS5+SRCMEAgRX5Pl262wn+oZqBQAsyopBhZ0uddOBO/SfFAXdfFenjiAcipHJtkxmTulAfsrJKDapKcFz03k//w" ..
	"tst7ZIQvvjiaNUWX2SMhu5+q/nFupJgVFdfWqFIY7ukmbzyO72jtFWvPv0yzdlKUtEa3hHUl71XvYYmhlhiSfLUPj1FLOlZeFFjT" ..
	"c3vK/vhq6Wa7K+2XIGJ6/4qm1N4oa5+A5NQgcRnIM13DeSghUivKU1+zOY7Wk5ls921inpwouaBnkimOB0ZHhVYJRv6HplL5/8Xk" ..
	"BPyMmBje7+98QYpWQ6INQ2p9Jr8txLQR51STtbbZJkafPVdr0BocXpIwo1KSc5/lhAypg38NWPI20P+bPsEIdgqJRXw0foa1YcVd" ..
	"Xb5bbAmDkKUdEyF6QWyQfeLeOCMaQ8Z4vOIt0KQo1UeOZhjM08vl9HdjvBqQfAtv5mnjN77HHZEcjJH8TjuSlfWVlYV6gddr0wdl" ..
	"UD+6kBYfXJlxNDaY04CGiUuYrfBc27qTUvYRxFhaa6ykBpBOHwDKC3hoXv+eTyipz8P+30+Ng4V4cCYpbkZ2sFUPLXofAbSn/pzJ" ..
	"GF8Md9yteZyeLponXpCt8k0Q1F70sf582PMUHKz2H4twRM/aI2bcmku/8zp5drb0UVgBmBiUPPhVk/T9BLQBnXBBFX5W9BbY0wg+" ..
	"f0ceRL+HOYThim4qeKoP4dnfRvehWSdJgMHrwkJyzYG6x7gz7m9X/tgutrUWJ93hoUZ3rPkSUV0OGR6pSipdQb/addPwFvjMg2ws" ..
	"08ls7cAnNrBOpCQUo4L3o0usiIp2Sat4fsrGYN+HHPOhEbdCVuJDB5ki359l+goUrFyRCoEyrwS8pLjDg0Xph9qyL0AlzrtrPm8+" ..
	""
local PAYLOAD_P5 =
	"faUNtUC/3YyRNJoSIakFBN+1fjvJoq9LoXUu1JkqRCpvlBd1+jj9KKmz8JPe5cV9Er/hjW36njsCRU8tWDZcDoEAfFKvco39QxN4" ..
	"qTMINLZDQqoAPxcngZ6bPYxeW1PJ8wWKgSQ/eDXxq0uWIlN4NcSP/EsFn+gKJJcqj4+hMqef47OC7owOj8Z2D7ns9ZBHtprsKNc2" ..
	"9Q0v+NjII0fZvHTB3UV6799f56ZlqSZyvnXRpX6Ov9QdhnRABj2MYsugtafkWnOpEo3BNda94twargZecLzbg+6mx0tBj//QLHuH" ..
	"ZgAmzMSM6jxFVJTiIexHmKixTebNdd7hJ0uuETpFUrDgRZqgN7GzBz2nODK4SghWL/NYRryjEj3wj70d0G5MQmt1K/r5gdWteTjV" ..
	"nJ3bhGBQMwARL0kKhKSYF6d582HhPQltY3Efab23fjoVFJZdHA0gzo+Av9//+u5KL411dypCBHsaCgnC6LJODN0QKPhzelkNOVkm" ..
	"+lEn2JqCmN2yFS8qnuRLwkEETb7MQQHb/m4VL98gds3hBwn8/p9qLsopWT///FGGeHWmhDy/larYE2UzLU0sSurv/bIfoZlO9wwP" ..
	"zO9Cj4jjWcti2URP0tnAl4keKjh8bJR4I3B1/Mg2B2424nRu04utNyN0sNil5ZiPt5/E80hMb5YEluqdkHJ38xZ6zifsgd1ZlXH/" ..
	"AfF+jq9cYIEYkpt+bfrFgyd0mlt0Qdw5qmdqCxGgoGUFX961ctp1N8sbbFavI10v2a4kv7j8uAjx8fhVHYHlQzXGXoHX3iYKDy1i" ..
	"OE9sLb8/+IrmwhaRSdmJyN3Lomfl0QAEaym1fXjB/qVxLCfVGiD5n/gTBdZJjJrxM/A/xJ12bnzVAsndiN1s5z11vxelJxskoSxK" ..
	"qldRGuLb2s/rg967ng9lICVpRXTAOrkaEUT/W+hbpuBPbEMj9bYcfmRMKQU8SMUisEfVBwdQ5+xA7/WncAgy8ELNjhK9CazODplZ" ..
	"TWrevyar5IlGbshST77JHT9iVd0/JJUOtwQH1ef4CRbRe+jC1r6bZNZDFvnuuQB4xDH0oAKtYdCYsmrmQdxWM9Z581o9bPJX3Jsa" ..
	"Dz7rNd+RLLn93MkKbydmoLx5w/RfQiwHZTXFAc8hk6thKU5nKJcnYp1eHUE/C10LQqkCYexzXC/bBhRPoKQArGWavvPclFJ/Ur1b" ..
	"w/sopBcOKZvTa+LNEAvj7Lwq7jyr4VxmLBBu0NDG+gFgxLEGivsU41oG5z/ZUv8gVBpMfOn0cTknwcZozia1rvFsqAIVcMzuPfmP" ..
	"0nuDBNb31VKxmCbqBqNSiOz/4gEZET85q81LOhYYAXREvp4xvEJHCNYj36cQozGm4+Jdt0uJLtKxZiQEpC0U5Qw2eFLYX3n+HnQs" ..
	"T3BD3FOpOvJjxIRms1KOsczBohbxPPF3D631K5POWl1ch03KFTHBdZZ66TSe8hhpj2QC0TwKUsahjfOZRZBlWwgpIkxKt8NQUKqr" ..
	"yAeVdHGQXzg79xIKuGkuLI/WaUEhtvQh4dJYIjf4ABFQjbkeV3Jd3nSsMbd5oMuV3y6jOxjUZuJ0QYVWXSvAH4oCsmUKJwv33m0N" ..
	"eYUIYMy3JNOyLhBFeO5Km8XsU85cYft99fmW+Slm5wLWZdTyRUOPL0LxFIJr4bNabEmYccavgHJb27QPB4SbLr0khXH0UPaCtrTQ" ..
	"lCrs6h2u+L9EA3L5mME6vlzc+vAGHK7vdrFsf+UhCTocxR9wJh3v1dBT7DX0hJt4wbF9459RhvtIriZjb4NdiLHzq48lNbWttiIz" ..
	"c6izl8DQ5+qOq1pCfY9d3mpFqBPeSdhLaRe9aYOvyd6pTiSaTEQYif7CaJEQGmXMJxklyYr2/rtqQpMizh9nER4guTddA/eR6q0z" ..
	"RRF4ZdkdHwUC45TQcZrnID6hQHNX1M2+j1xme1BncJg80ZtZsP6zfDH6q86IydaUT/eNlmLZlesSlHkjVuXmxlqopquYsVg0FmQS" ..
	"MZaqgyLG7pcsKWZXCjw2EScZ6rish9SJSsRc2Fmtr3u7xmh8EjVGiq3l/ZLnBZTCNgOC7L/gFkCqgvmPcDN+vh8Qtj0ari4D42wc" ..
	"pXZucUwmYgm8m6ALzDS1yrLX17uX8cT7ljrhEbjQZfLpJmi5qKbXZVgqne2MlkjzeZeU6iHJjTFw/9j3k0bPIvQY7EghJJuaH1Ef" ..
	"kpVonahr/cp6Iet+eIoLQU176AWK4nEu/rzxnpCBdrX2VRWu6VXMUaYxra/w5yszDkDd+X37T81hrvWXMVuSkukzsM1D85W95fdi" ..
	"czTh4vt1TuurOVKKUOLsQr3Ln3/QjqJNmhhX18/41d+LSDncRuNfevg5+Fel0s9pKMQ38MIHEHHHSTbsVr2NLuCSYfgumy+N92sH" ..
	"kB5KEj1eKeCkbIVTgOKSQQVCLnNANe6LhQUXVD/EtK1kloha3yyjFL8hlMuiR35+Puop5wGJfcH1M71oRs3EGlZZ/7Y67HKGmpXZ" ..
	"mMTrYjxdZhb7Vo5cCXqN2iqXVaMIuwO5D6qgfQMHQq40hgKn4sPC0DPJQzY82u6APxke3xwP1iSEokceJ2yYgJr1f3kXA2+DvlDK" ..
	"FnP8bfHjQzbfdDDmmk5YW/UlEgXPpJ6qPra4q6pY8ZgrXRjymfj/78iHML4DjotFP+Vb9Gacm3pSxoixE4dtrm9HIcYCscTtTCHE" ..
	"BZG9Kt2rJu6sXhXW99so7DDs04ltP743D8NcDPKtUf8IczJSVIyeylBys0FjrpJeDjVOXFijLTZ7HguQ9fQqQI6lhOzyA7HHIepy" ..
	"xO5njajXelEJJJf0o+YE04uvFACuRuN7ikpCRJUBa3yFImbsEI81RnSAcVITZS7jGbmNHN4CL0KLzC9nTHoGvhksn2yra/SKVvCB" ..
	"0bNCTPd/RCBUaxjPktu1M7V2ZyfYoB8Y9zqioLRUt4pbezJbUK8E32ikCjc2ji7VLqYZnM/5Rs1760xzg3ZeXAA2jA09I4miGFkt" ..
	"SM6dh2CSjJw/SJemQ/od/ypIdCuomszqZ5ZLpMsv899mnHTuMhvb4vybJhiW/SmheTHfHXAIJoyyFhFV95kmHURbJQYbSegXAO6V" ..
	"KdE+hp4VReF/kK7qNrqbWOYQA+jtoW+j3xCaWcxPbBft0lpjvfnNmGXkrt9U0CK1FW7hpigBhbBtcQBlFj8zIzncB1vE+emaPzsw" ..
	"5UlmMqwgFwREz6/Lc2IuBeGOtNxFG0NL7pAhhPZVkSfkeQ07XxDXmRRKBgMI1jvJod1LqV0YKhSy3+5+oQ3ZJ/YZ5E4xNIKcRpp5" ..
	"ZYgykM1yyBRixlOwK0SdVGKrlMTE7ik/w2kq5Ts3oL1vwqPYs+PFn7rquOoaC1mBvcu/FxcaM0cLYoCa6sHnE/UE6CCPsyaoYWY9" ..
	"pVKNLRzRZzrDljPyCh5HahodtW2NpdcjACnnu18+kDO1GmX6ytUqPTrAEOdQLriepcctV/YlkVr+JNReViHG0H8Wuke/mGdRac5L" ..
	"VK5tW8P/ZuDi1tCM+w3MFMt7LbQFIYvizas2eETbLqLSMBLfjEHByvXbJ9dPaC5yIxHA5tjoIWe+7JaZDTNAvKG/0z9Lcp09QNvG" ..
	"BKJjjYJY6AKf9ZXgzBRddMufp3WV94qYm+DhizqbNBp87EAhR/uZ0ArpVVfm2Cp4yuvoz+m7CVK0DT1QWCH74MuFr9aQWs2gmAnx" ..
	"kvTSVSGqqz3jXGZHGbF9cx1RTiZpHqlRQ5HQhBB1pdjO94aVrn8lpK6E8Yz3+Rk3fxg3mGkn6/f/R7ocOKhWyD9bCBnITAqOutK7" ..
	"b04J5sb5TcRs4t7OsWzOynxpvL89aUE/YcpxQkj++I/fwSEb8ZuREPb/VmTC7ZIqEe05rLmMv4xvCy47IpRQXzPXgbVpIMSqKPxl" ..
	"i2HhsMYz82yGn6gF1AypcLB0y+bhZRu0EKJX1LBdJ1Lc42gUK/ZuJSrMSV6G+AoFG+HWkplZs+pBh2jUfdbIJRji8ZUYOZV9UU6X" ..
	"sWXbQqNlk97og+/JuCbcFb5cpkyAsxow8klk5eIFdrDGJjOOVcNWFzmGmuwOLXm6jxy9IMUjvnHR7+ISEyz84nT3GwWPSYjU1cGb" ..
	"WZYKhfT1KncQEojHi2WJJGMS3kRRoaGhhWU3daoRWhPHkkic/FcQT35MmOnoH0w3H2AwhcxU3pOPtxpimsvhS/WrlXqu3Zlz+uKx" ..
	"l8+wyqvgWlCh5UFEUucPDYexwdKdn348AIRxFprgiObtUtINE0K7p/mC9BdNplvfwdw/h/bmEEpG4uWz8qKqhCjG3HD2H6Zhst7+" ..
	"M9oodamgS1t/oj0TTFIutXH639oDOZcu6AU1t/JlGcK3qaHCuHKffnwV90bxEmHqVKhqZdPY1X2+am1woMI+2GAzseTErj1IH3Gn" ..
	"pGUrec5XC08ElR+zLusygaZMZRbzdyxlSEgkzmvYF0dX/7pxCzORvC0fnL2lVWYm90crZOEjufpt1wmGE+ufESlGUQMRs3H/6TsJ" ..
	"lyGm/X2Zau9253Xdtml4GQG88fOD/uh1UHEdVfkgk7uvQ6EqSJC9IYxqUqp2oJAV90EVM+s4B9Npe4jHli+ixmUTIB4aJK7mJPX+" ..
	"J3KymJn0Md7RsTLOU3qTtMJ57ej45X0OfxV3d6BFoVu305bELcq5OJWtFraHEu3QM/FH7+AD7KVkqEuqzZ//UE2wdvkCTOMQ6dgp" ..
	"kJsih6iPdVk2eDuJ1G/qi9jmEHfgXQum0q5Lm1gEbJnmGs1sfIewa7x3/QpUHg5p7uOGq4NvbiL1uXidlXoJZ0LMFknWpcaozw6i" ..
	"VNtvq4b/JWvPzx1kvmZ3Sxww8E4VlKnbpkXBpAATgQmjdTIuJqUxprzUh7T5fVl7ok0n7oCq3w+Tzi/sP4+88//UiDAp1FS30sSo" ..
	"/2x4SNYoAgH71rcD1durlLjA+F+oJ7yCpgVhafP9BQ2iEhwP58Ptrr6Jk5ZSVUSzU2eYGqJ//qpWYO8Xv711CDosz7b9Z+hcV4m1" ..
	"qJD1B94ZIwx84aRIym+/sX4pHi4u4n+6KTjRUGjZKC7XGrk6fOu1FS/EAaGvffPcM3WnzgSV+w8ZFJotmZ1JTh6d2uMYH/Z473qt" ..
	"PTikkceLA1V8hWZgCHDEucxAj7IjYJejX7kAi96ZmzUCZzpiZHPVjm1EdizFgVv8v241lYGO+V5QuHBOth7rT4BJNOqVD2DQguWp" ..
	"hHR+MRAk5y9d5wZp5ubE1/0q+xCuLK/jDtxaSIvMc0PgpEsI6sIXvnNcQN3gr9mRVT14YjFpDCXGdjs9Tr3E0o+mkw6FLt7DAD1w" ..
	"/l52XFyUrl2ObkdIK0ouE78V5FcwHEKmlyVHdbfFFjjSXv/899WQiQLAVI+BlUsplZkZUd21UV/1xibis6I6jTdWXr7H5sFOtKrg" ..
	"loAllpFCFylQhnFFGVme0Ooel9Cv7fOzQ6MI9JtEFU8kbm6/wENtD0ENvbCLH9RTofBdEmjOol2MsS9te09R3uoZ90VA5QS/bf6Y" ..
	"hw82EGAmjGcmeUuNpoAG9j+BJWSxwKWy9Xo7ycHx9mJFcQvN7I0mZWqJhFK1u/H+i+3H/u+AJlo1Ig6iSha0K1m0yoUSLsw8wOHd" ..
	"oEVUhiGXfrGhHzodoXu6vV72RW/7yvViIfpHUFJzgHVDhqpqmMPBHLcPAAgPPGkK5KI2hPGZQ9vms8SEZsb9aKftV9FG0wRWgVmf" ..
	"hOvbS5RtfhXPLA0+ENt7ZVfdrcFH1xDHhlRvtZjtplPobSbNtshCsAOZWJ1xXe2fJFB/n+zSWwabniGn7Lbgcc+gG/ivwgQ5m7Sp" ..
	"hxlg4JUpGuD5fhLLmyCi/5hmTJHDbQrVqqBMwXHGzHaO+1nr4KWCyTRnsyFb6od35TfE1wGXNQ62uVvKxGf4TAukq1h77OpGUOFY" ..
	"j7jeCq9LnxTZb7F9kCDvlimVsRgxSmMP9dUJ0LFUdSIKI7p6u/UNOkn98dP40eV5YkGX6ulmZYszuKnJ5nmha8FThqGOSzbuR4pc" ..
	""
local PAYLOAD_P6 =
	"7EmWlN6sJWVtGQKeNrhwLZuNqzTUY3EIaUh00J/QaWJN5YxkyMZwciJceJQXlfUo8BbNp3ZwNYz4b5Zl04SYAMQf3pZ4zOyF3qQa" ..
	"AtUgUbI7vuvd4nbOXBmxzjcuLfQaZGa1mD+/peg8OnaLDHQj85Qx7E2oSjaRHU8ief0t/GhouudybD4N3AGS7HzgbOpXEgifOmw6" ..
	"QzIatOzGAtVWOLIzxfn/tgRatbx6UVfmpI6fEir+o6hRgG/2bIJxxK2VgqibuUkXKMFhSdw26GHWWI3bqo33asHmwvxWOfuY6qVV" ..
	"OpIrzpTSAPIksI6aJdPODc24P2OQLxc9BuOrTU0uNFlpwFoHLFLx7BR5841WLqmWi/2lBUjRgpWgg2WxLpGpeUMdM1DtKLfxvPbo" ..
	"iIKNskbSYkP0+q/zLYgSWlKNPKVEOuPjE7FMubUELnkAIuaBCjzt9PpQ7XDkd2sqBMgTxYho8Pk7a5XBHxkuAGTXkCchqzclFbv5" ..
	"7k/2CG08yvlmq9CX++weKeBCn4Cs30m8A+1ThqjximXQnYZ+lNHOrvyeBo49Fbqr3z0xBm0jugU7OBq7h1ziW7ThijtydZz1q48o" ..
	"BxPem7aeypw6j3uyMRHjXPjdJ8yV1mT8NAgizIezOWKveEs7UeIYXHDmDOHGf+m5dtkr3HnAXK+1hdObXKd/kpR9dvP9saxtplid" ..
	"yaJAZo8ro1TZuGyg7VUnL3fhVbTUhhuUwZQRjjSt3rlqxgDeT0j7qEF1UfMRwsTpJN6ohJ9Wqx4dSgcuSGO2/mMjSHRn0nYMlmZ6" ..
	"6E6BGdN9XblyIqeg/jv6dy4k6MJt0GxvdKTbCBsyfUajt6Erz5JPzBCY1k9+r7BGQXB6GMpMr8BpeO4HytfgOMo6xwdUTXR5AoG1" ..
	"9SgcyxPB3+XA/q8EjVhWFnwwBVIt+YBPtCJ5XNOsxwLBgfkKe543tuZ+CQfm8beD3q+EerZQ77aBdB8RZ/KP+WG9AVBZEQ9nxMSY" ..
	"GKt/gwUrHQnd6dJUURfANrxn7+bs4sMCl5iW51bj9RClIhsJ6MLeNgQRpLitZDiB7+28/UoW3I2big8rQl5CyXNzeiM7tQoADFML" ..
	"HuqmcDnsIrWVwBefhuFSC8CR0Y6egIjqdidG2Xi4h3stBGdLCjjYfnV+uNhu1o+Dv/OBA7ij3b2db3pYjVoHSbvKndTmXCd87boI" ..
	"vwoLRUpqVhy2icAAy2702LTTCzCc7mzLsNFbEaNaxbeElhr1sYX+oDp2wdFzoHYZHj5Pr+aA0gcULzQ1uLvz0qHy2UAdo92F6Zs0" ..
	"1wXFpxJTo+IcQnkl+eq3agzgFMvRW+/6uIc9ftp6R44fAmvIOYEEWRPSq+guhRVIzNz0HwrTy67WhjoVpd5+FBa2bXxXV2yFMHxv" ..
	"silZQ1BMDgoGFU9E+yW2hNc6Eul/O3I8vQ9RH15fNdwJi3cnNqHHLKlSeYehkM/XSIRpzpwtNNssYFnNGknvRCYZE2n6WUkLny7n" ..
	"eMpDwPJQ5w2ZC4XOEpQzCz85BVZj/uy9pyIFM/YdZJtPa5eQ2SdByg2yBYlXot2kueVRZAel3ov1O21cWm9ugLqG7KoDrkxPEUrD" ..
	"XD0brYac0arxntAcRrZBfZWXT9doZWZxU/Cx3akQe7phAlnh/x0I6SoLu4TO4sIGoOMttO6eJeOYDnT+n2WbuogSlu6JCwvtqPBv" ..
	"hgFHLsAgs6rtLD/Bu+vRD1egL4jxEIJU2FQvP7QFZ9gs4oH0DRzg+AL557FFpRmNn9VkQvdl6PvNutpDM15VihpASWpLXVTHEf/Q" ..
	"52PCMszo/zc9+kX/Tx+T46nmAvMSE8dS6y2wF8SvVsMTy49amqrNUCFHEFmN/2HZJ2Ni8cxhR5tBq1jCrOgVRDNURufJarc3hC+U" ..
	"sO/bivwfIOkMwvc4eHkfO/OPOjO0gx2LIocG02XhoV5lfDoTa4eUZKkdVZDMPa/6omLEM4OillpbgViw3+HuvseSVWDBbskYTRuk" ..
	"AqC0qJKhMbvX1/wOrCtcqXi1sQX1xTjLHFZbqr2DVCpAvklgqbFJfjGxXjoitPmOnF7dWWUzER2LDQUrE7qAsBxw0dwFtzCOcCOA" ..
	"wAdUxXMONpC3uHq9B/lgkjerznIgSwbD6OU+laripMqMsTRZ0FuxQMLAmlTF9WS2rWzHMVrQIhtod2uR+Qa9oh4BgFy5EMKOzHgZ" ..
	"my9P4MenfpEPdKJDtWsqKtMzSifMnqsWoF6IrQIwEpyxBmJ56pVXlJaC5zMqSolQvJh4Bj39FbIFu8da1e48Qd1Kkw7OtH5GGNHD" ..
	"KmGaff/789jJnU2tUJZfgX0q18iE0shMQcgseb5Pt+rqkJ6+oVetTHWI8Msw2/91fCl5iPfu3tnE0xUSQxR/yIxVuYP+dDz2Xrni" ..
	"9P8I+XYzdcamtkfJKhkqEPhenMXwL1b3Z5COtr5f+m+LfEGyRTjlQ3PYa5+x6LahGdHSdJmv0hBfjYlTARtlvsebkz/sVu/3mgcO" ..
	"lOFBCEM4wgODJs5w2P+NxaK9fswotULR0UNgTYCvKkzfOFbqBwQVymvbZ38TNRUZdmlW+jp7ix+/k+2MvQMDw9nbXEtZmlKn25FY" ..
	"l5LCZ5Ih/B/pi7nv+YYGj7quorHqsi+8uYS0Yk3JwfHBHZWzICfJkHDtdZtVlX+frcmrmSA2wZybT+JvBLUT8H1wYXqv4xwd3CQC" ..
	"ReA0NEB8r71Vyxovgqf7tmfK9EoOEy/qTqelLmpdZDg1NM4dGtvjn38betHBQp9ruhFC9p9LyPkdARukgu06vxqZiwGLjbTULSUz" ..
	"meeiUQnnDSZyMXLKYiFm7UxC0JFZqz5ANtAutoO/oanQ3yhUFSRLcyxR8ZF/0fJ0G3ZjNq05Uhe6fy/aur1PEfXPRFXvfeEVAAaw" ..
	"yX+JfKhguCsG4htn9Vm6Azhfn2ed6Qtm8f45sEpT4Wb/jY1lijuUS5KBCV+h46uF/jbSY6mj7OXkD6TEkWiZVk3tkV/UYPJj4svk" ..
	"df/kW69uwWJsSV09WSWneHxnEBW8JqjKtFi0LQecWu+/mB17YiSq5vBnsIuvF6cUhYPGeiBFa3bLigXY/A+ibP2ZUTdNf8ZGVtir" ..
	"VmL6VBd/8FkocLDmMZevvIE6FKAV2xSI4QYFf6fXgIr+ynq3bOeumm08N2094UFeCgrtNdPker5PrPBIgxhx1+zIjdv1oFsPYWyw" ..
	"X3ojSkaRRywq/zCkeAdAox3XfkJeUYBT8KZ8PTj8KaPdWJFliY6Di0wqPAW9KVwbaNIaY5S7pbxWqGR5/HtwHbthMFPig2je7CQX" ..
	"g4DzHI0L+1dmdQSXFgdifD5IJTpc2LI179WXM8q7wkDC/y2Z/LuhH+b35MdzxaQo4VHO0b0KcmhAY2bUurcBTZhxzGO4s/sGrLgU" ..
	"wFN+YS4S4Bvd65AsxtLHPfLPWYD79PVgQyOK3KJsa8d1R+te8K5MuYV1d5bzjsLTPjVRmWHtakE9WOIEjUgtEi8UtgFygzfOT7hE" ..
	"8pwW6Kp2hwDL9PO9QzeTOlyhxseG+XTxYhSVnvpklmXhEYaEcy8LHs39vbQlA47u02QEQxT+wkUTjikP68Pkxfb+IkoGFsL2V6rD" ..
	"tFttAkZM9DfWXC/ZJtWUrMwECRaI+5++mUZdviCXHn0H6WixDOw7EmicAXlDEpjiVBJa9vxJj+IdViPQlC9FX92WTbeCNX6nz/7Z" ..
	"yKJ/k7tuEARSi8gVhAshIFLiwymZfniIRnB9x7cVGKXjUNObewoGLP/UrQEK5vHBmKdeqFddfEkx7P6iSloVNwU9le4PZhuhTBDH" ..
	"4y1VldsSI+lZblnwJ8kLvQzAgMpvx/X/c2T4u9rQ/Lp5Ll4Jzqee7tEWSMWXqW2d7stElwG5LMMcHSI1s5Lsjarnlz+cDquNr5J5" ..
	"h6dHyjhm2aInb+iRL8GoTNLBy3PJ3PV4zg0N031bFBeJZjOdAiDFUuYGOChZd4089qSP9+spubBgHZoPJHAVjIvZqU4kK27RLbqf" ..
	"+Pkw7f62TxgBl+8hTHjl2/Ikmmd4F8O/S57rzHDq2KmBS5DlPGG2uoEO8muuCfAuq8l6TzxV6NFwhUWs6oEci+Gjt3BoZ5nQF+AS" ..
	"dqIzzGuqUHVMMYaqNzXPhLmj4L/g2aRNRsGIEO0u5UZUXvGO8aPxYclpvbBZaC3pVif1yDXPYA1mO43GfaKpRufCZJ7f6ywWj0ak" ..
	"+udI56sHXSmyouYBBgvARP7S7vwFc4pgIioKa0ApRNwb2OyOe8laEzUodKwsIHJJ2DHWiOI8QQ1WCq1BO7+B1SzygrK24xYK4y7o" ..
	"PO21LBeol/wldmbz18o//gVaQPlMBblg0wAAa0fz/kEHBScZ6vw5NNpl5ae4C4zeX0Soo+jevEJTbXnFMwpvecBfRrFfGmdokp5N" ..
	"zKnKcauru0nNhQeKFeh1uWuVnn/B+XpQJWcxgWQRGUM//VXN5ncd9NyEFGwP0sENsQ+r31bVrfxlGN5YXhPo+YtRs21DU76jymq6" ..
	"9T3pY3IgXpoYPsz8X3ZmsHFSo6n1M6l0dnWQY3753fJvaiiNbwDCM/3Uj5CLLUdc4hZYGP4wVN2Xh3zFANx68HDMt2CWLSYHnaHA" ..
	"35cYTqMCMwPcyZ1TcItusaAJYE126jWQId2QF23/2TKHlyPm/qn60Xg14+tB6wWGGzR1z7K3pvdCSrOu3ZN2BkciELrosrbGczn6" ..
	"yXP898ReMGAKvPCQLs7CRSGj6sSU5WwpTw0mB4haXOAGdRLmMKkXLc3c3clWQQmbKow8sGq+sIqjWaL9oeGcXMqfwD1MquJLjYc6" ..
	"UJPFxd5DazoecuBzYHAvUcfXgPm7uIX6wRgIk1KckSyGU+B1zyZQHOtzcClip70nnFeNXYZ8PcHCuJmLtxy2stxo/EZKiZUl5kd7" ..
	"divGp3T8116HJaHlfoClrQhKGdzoXZ6aEmxBwbvvygPdie9CMPiNpakD0impQ6wJBcCxvUURwHizOjvn4ZgX3DnBwoIiu5AHiEt/" ..
	"Y9Xr1/52daRVktfTVH6lWEO6Dv+ggU/i7t9yTHGf4emJrvxAs5bQM7lqCvvm3by6l4jyvrcsGSWz8hseiVIQetr61tmt8qTXbX7q" ..
	"HEJuC3hJ0/M+RPN4DT/Xu8tohUXBqAj091tM9GOXfJWAbhqSos0oO4oS9T/lOUe9c590EBudW1zbEft7+mUpQ5q46LI6sgIh5Rdn" ..
	"FlE6UGp7ZH8LF5hgvk+/hur6kMZmDFfEY3BB0eORJZf2kihTH9soglQZqZSSYJdSSZN0ocGCAb6ZcVqPZchODVVhP2/L0C0ajXjp" ..
	"f0AzM1RvY3cxC+om/D0ypMoznNJbuH+sWH2kCcDriwYiFD8xh7yQfhOOaisK86fsYolzzLeLYXuPEM/xcbddSlM434YhvUh4bmRm" ..
	"5woYU3G5v2gTHA0rcyoWTMPO/4sFG227s9bxoJwICtVLkn8H9N1dkk4T4giOS6MtY80NFetfHyP0Aw/Z8BHWziNgPshkZpHLjqZi" ..
	"xrNVictAoMH19+egBloAez99dCStRullLphWUZ2nNlMDhGhWbGxVk8gaeo2/HohRiGKBlf09rtfXk0sUTPcfK9/jBMefi10/meaq" ..
	"gPnb9gLrWJO4IX7FyEgHtjp2UHD/9pKb0Pr0rgaCGyUaeY+DtkOC42yDpCPPvYDu+nAjMieYqjYxH3fjTUcdTzCvWQZY6NR7J0w0" ..
	"+XwlR+JqAqwS9rWr4fH3vkTupnwiy04rTHGKQvC5AnoLf6EVb8wmu5pmsccORXYkA6WMypH5Gr84Fq7XhUbfokCy00MeIfcj7ysf" ..
	"MxzRjSth+Zx5g8TOieEidj3ivp/DcHqVrKXekJIbrZH/As2AuDk/PTE6tqpQnTjIaHZnrf3SDtdO55q2cYKqaa+bJ3uXFa+2jVwr" ..
	"nJRrsLN5sGmib/gXvCdxjAlzslTnIZZ5QcQr1tVhgtriY7NY19Hxf0jBqxCjZHCtE5/MyPBnF4M85o3RyaeOhAaGTPSzdU8CZK+T" ..
	""
local PAYLOAD_P7 =
	"f49y6yCEEj7BW5N9yttdTu1F6H3PuxSksnfd6EsyYHG6iQe5J8jfqpi0BP73d+P1YHvNujXv9Xv674pUf62N5jGOmb1GI60cUOs+" ..
	"NSgWYByauP+cd5vSofim/NKxE4DVekfVAphmwj//Y0hnIas3s+z/8uQoIb/CGOc+0kiiF7CGyagYgiPw6YPGG99gaEkt3ZiLGC07" ..
	"5e/8G0msMkeJg+STq2LqDXmz1Hbv6lGKv0KMNNjh0V64i4RPnNQrP7NsnwxstnVQ17J4LQvchlTnATPi9ZiSuuuWSnxxtpzNDsZT" ..
	"IZJPuSBy7ZTktmgyANhwVrZqKnCOHdffANfR6Y+LbxaymrjOe+cbKHNpyUHvy2HHunzmnz3qcVpS+mnTvE932ffLDBV+xpsyhyTl" ..
	"C6rDGFPIDhqA8+j1Rs5uNn7nvxWS6cth/3fI0XwHg9rOVc6RInyQAupzgs6hi7x7wNZTtgPFogSDCSZUlJEP2kWeAmVutmgbJJia" ..
	"/plAhnqC5dFr+NKAX1aBWROkvFXUIctxhpVKSLo9Ek7jSTfJ+7RMocZXcRMNlZ4P8bDXAZ0na/n3lo1Lapo6EfsGoRFu2Ok5x/wH" ..
	"JXjvPkAnpJOIKZjb5X9+vTsOWysC8U2mPhqSZ0uFL9WiAPGBg+0CqVNDtMMYg2eb51zmYDPgJ0ErRkvugyALtWg0KN3SAPxeE3WS" ..
	"o3Ze3VgHTdC3NE+W5axQ5G5LlrBpHURN5fKyTaWUb5lFONwi3Ze9ON1cBnCgynD6wFOobxzi0dYaCPrqUmwbegjuQIRCTosFk+4V" ..
	"iylJq3IPeLqu0l9VjDj2GFZxv3XHfCvP9QdHKrnRW0u24oCaoFBwrYlL0xbaNe2MbZ3IKAev3EWoXH0wfr8IOAGIp8BXgQEMunC5" ..
	"LtGSwOvLCJx+33JQ8swNedSR7PbzGB3EZaHCdNwOFBvJKAugJQyhV4z3U1BmN+9KoTJA4CwlpuR2j02/yQgfUfaCgRkr0FLdmA6r" ..
	"g7fZYocsGPsNT3bUyhBlPB/EQad+uz/uacZt1Txo+JcrUxMTnWXRGG2MxIrKDS67JsiqSiOv4Q5+J6XhSE0XbKkzOGIaCmpWqITn" ..
	"X96jMOSOYKBIXNlqMaCjG3R590caXp+4/Hpw6HpyRASpe6yMYAy+qHnkkQLwSttd4l08Uj8bGicXf+9Hf3vuc2K9Fn6keq+XwRRg" ..
	"9DUi4gC+nwQ1DpQOHiSZ9xTiBRuOzkcThimf1Xqq8NA6vrrOiuK8T8MZRDaekfnplg3wflrhR9w0KcdoCQ//oMuxzJeIFjYeVeHW" ..
	"PkIghlOUs8LOclg6WmQG/mLPiDQGSJsUZgfUkp6blq5xN40UA/4YtcHV1HJPIgBlyr556MV1GZcv9egzC7iBii+WjA1WH0N0QMuZ" ..
	"/8XfDB9Py6c1wLUpROWgzMDhjqzuicWbjmjZ7bheAT0aAX4fdKMbrMBOQj1Zvm+e2luX9+NOt7/0zWY669Y+42uWKPC09PTxbVCo" ..
	"yh9d/UFlLwgLU6YrOCYPvh+h5WbFoSBAUocNoxNZpxAGmO/bIQ2K/cVKIx2cNSUh+AhbGH3YaL3btaVSWRhFAhBjr7J6d5t8XKLN" ..
	"TJft1w0Zx4KFzuRKrSw+BM37ApZjAsErPkQIZl2tJrRTUEj8tCk3rz9QydepgKzRhQXBsN8Kcln40gG8KnNfuY+nD+S5Hgtr/zmH" ..
	"7k9KIX00a8SvqauEVAnPGDB71uqSlrkD5/Li+81/oEjq8BYnsxcdCMPcvruF+6YF5ut+DTPDuSFOq0+L8bgDs/yCfII1PViAfD31" ..
	"lqrOkPlqNsRJ8Iknjlss1bB7tJLyfKdyL+yB8qSzhv1UmKBpCaM62Bd0vockGC2MXm3D4RgU0kKWMb0dRDfdZ/KCYZ71C+gnLJE2" ..
	"btvrg7/ijcIpOfWNTouhQn2oQSPOLzUEYpxHKikVa75uTGPJMoqYOoaWfxq0Dwb1v82QsJa1rw1UHYtshDTJaQ26lVBZ9gXftm0T" ..
	"lykpK+xDHX+qPBVylh1QJGXBClGrVEHa8DomJ23Amcf9y0LJ9uQP0HhQAx5TK+jXfYK0M+p6CjsvkH8rdA5+LSfMUhG3J/UpgzKW" ..
	"uGnw9dPipkSD+yEWY/874bPqdQzNMCl2woFFD2NB9bECuYaTdyO4I5FL8pjq8I9Tvd1x4Mz7OpszwVw/ocVJN39atQtQLHKPrIVL" ..
	"fbc1HM6k26B5dRc5gNSmC3f6CCRkegHKXgwjD0mLYnfQbHO7w2ygv+XD1YqbUykNKI0Q2bcTo4R/pNv+TCbRLSDx9tFF+9jprrnV" ..
	"Lbw49SKg0iIW2BQ6ibWVI9Z5V9A+gbRwrQQql6sO3z7qlDVWxrypwiOjOvJxGmRaUkxPmjmI4eq5DJomxVxVELLeyLYar70DVa3i" ..
	"Byd+BgK8nlI8L/WuPLg2EycbcUyU4vuCcR6YmwY1QyimcuMU6XMF81zPdQw1yhA39OlU34qUBrK1m3POan4szRqO00yR/TnFWR1Y" ..
	"ZysvvLjROBjgf34+ZZmBUQCj1Nyn9/u2lFWu2o49+QpBi8QkZGg8vgXs+NQ2BhOvMQnwzahsFxyQMXqJpu7YxsP5DevCgkJctR0f" ..
	"hI6yVQLTM+YR2OVNlAjK6uBEkZIO+BC3dtfwliJ4VIBisoO/UbUft7JZjvjRGLOEXHsWv6/1wNaSZuLcvL5EIdfp69g13CrlHcMy" ..
	"N6X8vj7uXJA/Usrmaw/g5/NPPZ7QjDYDeOOq0W+ejZSEfRnYXqpoLsCVNUCK2GYyV742WaE1aBhFgecL+wQsSV6R5PAIdhMYw+pl" ..
	"lqALvKxtJw6nCZcZaC0/GoL/0M+OwSLtZ0PQTK+lcytwwcFbSRE5VUWhr5umP0sGgUZzF5fsZXmSVifm7hFgRsvRvsvfjundTh/1" ..
	"DY/rUa4tUP2PcbPU9qy277AT0b5STl/Frl7ysUElKPFA8xQgwVJkc9QPIcc4rX5RAW/HVTCsc8tkQF8saj2oRn+GEf76HwI/RIOb" ..
	"GQHQ9PdQ+gJAfWa9xea175/hU533TAy9M85TdqQQctYhN7fygiwnSqmZ0Qkv0aFFM0RxctL0flHVh+rNwUIL6RS1Of4moUXzROc2" ..
	"sL6XOBm+KEuTdtJNQaAbHiqkdtLF6Jkz9hJ5/gSXBC/yDu2EKOAjueroyHxEcJUsW5s7gz/2DWx1q+cirUHOj2AZw18i/OqdewMh" ..
	"IW+iRvzyKprLmRonfmqy4YIPWfjMzDJ1ZnzEBynQ6y1FMiWLvdF8THPcd2BRAx5V3yCdgwS758YnRbvtaz62A3j70QYTojXUR3lp" ..
	"HksB6iQGTZ32Iw3YHrLxEIrKLjoRwpfkyIYr+Qz2I9O6P7lgbxKKTzRPZHfoXWfe7BdBj/6nfp3cYeFWhNgsC1ifD7gF/g7cDWqT" ..
	"TsWdV3g0B6f3cE8qkwxyAC5OdMAbFp9THebOeju7u8eZeXs282aYPYy89+yIV4R+wvHItYiv7fuGYB5fxBW72X4jBY5TMLfG44Wy" ..
	"nyXasrt82OirsPXUcl41GlQ4lE3qpkr2vgPrKPpLC1JrnVuOIIlPlSUL6yM1SMsw/E9LYodlS91C/t8oiOpeUnfvxJCkT2+EXxzx" ..
	"nf/pV4xl70QOMVnPlFm7P2eDZ38nbKOgt0ZMdJ3hnOZ8NtjMa9EJgHrPlxt7s4HeFBw8IgzGkblDRqu2ziAjRi3CF4uYo/rzMRXc" ..
	"QxTnneWNVJoEwsMScoQqrA+hfjM9bS3l4QGxGMOpsR7Vi56JpWt5v/d1k1KrFevb++VELHZR3kAPR4zanav4PXdB7G2TkTJmfwtN" ..
	"noGtxhRX88x5fZCQBEod4/Ch2BAPB6wLPJFIukfiWquvDWWxPLY9mqvNBDwXJN5Ga4YVD9ED6AWO1SCUMMMOSG9Qp9eaFfrdGYAs" ..
	"B4c9Frd0DuzuGKRosQ/GfcPOcI3FzfwWt5rgXSpx4OytlyOk/RavDNQwX7B+eVNcaxqx926d8hzvSdgChUQcM+Waoo/uYY/jAlzh" ..
	"YaJhriGMjuZj4nX1ELOq4/u0OA6nAQAy1pSp9/QKDPrgotH6qLiTC8UhI9gg8DeF0zetAVA3S4O6WWMd5qebwgM9yWzA4u5KkW9E" ..
	"XeyDGI7XXbq+YuF8WH2FF97jYMOQIC7M1BDR1sFW7Jl3IqSNbWI9SQX3SurXADMxQRljNPJIoF23BFpQDH0jrZ83C0F1Fca76EMw" ..
	"gC+/L+qHgffMT+a21ybPybIrUHPBZfsY9CdgnnRl9FV5aQKwiS98HYF0R6T7nn/31fChb9mXTjI9+XgNe79a3e0jzRnGWtx22cUi" ..
	"DPf/I/9xRZmTkFtyZViZOJmWHMKoiGo7PuToAlQZPwAVDu4pWswWoq43x1gFc7AMOzVOxo3SWuN9Op8HUfjTl913hstjOzY7kgMs" ..
	"5NFomcAJM25wtYmbwFjXdL8DnRLGgnw2mF4vZmQbqga5sknrHJkNV9qU0i5OerSEuicXr325iyAMnD3kN+bQlnsSWsrTHv1BhfNi" ..
	"yXUFNGO/HvyQ1c72gwqGvW+52o/DzPJ5bFTzJ2ExCrp/tL2PVHnTfO/PXc1JI/Kba6Ij/uwm6C+VYDYGIasAEEaKRVlZuAUfX38q" ..
	"5H6nemNvandBCjTxVRJE7XKdNBTDRylWvXNPBIcibOj/FeM7rYKiIfE1fJUVfGEqeCaGChreD3uMjhASNRPVaB8+DrcH6jJ80bUa" ..
	"ZkRHNvjNhdqgMV1udkSn1L3cZgladGLm/6CBMdsnd3du7DIosGRaWZ5ouG4XdkVZJzz7o0z7SfXYtTG6HM7OwsjULCk2IfU4xgd7" ..
	"z0VRt3ZcdkmspenkE6KqNvogP1O9RJQ7E67WfrCbSe4mA/VYYWbyD6cML6aj/wpHlEji7VMYof97pc3msGmEMcBjoAs+cGGom3M3" ..
	"Vh4DdKqgURsWRUUH9jYMev1pdFALH9Ft9b6Iv4rW8S1GDQaIA6qn4y5JmK6BcfI+YWMLlmlldAnYeLsR1mB866uedd6zfVcJ4Z3v" ..
	"g+LrOvle3a6eedjGM6cpg7FfFHTjKtMHf0jfeya5kKUahcMFamvpse8NHggP5Hh3fZQyDLkJZ1pl0qAP0qUv+NbP6FTgtYWSEnra" ..
	"pBBevLTn4phRmnjsbp3ennSUGyfAikhNjDJpU4Rj6CwiRyVITejh7ciKsqQfwsJBca9dnXOx9icobMYD/1PKbi+QMVf5eedJRBkB" ..
	"vjJOxTZaCOq3uMCdIWVT44vFBRGDNvcTNBAJzJsFKRke48m9+jaG3DUmvn9Uw8N2o+iVj/oHih1jDa6n8C/32lpmAJso+A3zjh5J" ..
	"Lb7h8B82qsodXTeyjbUJTCH/MtsbQ5qS++p5l5Fs+n4J5z0IiFDkR6XixT7hHHmL7OOl/g/VhMkIz6USv1g9ppIMkrclpvNAoiFz" ..
	"QCEpApq8p/i2HCCP2OZ66x0oOLaEXZf7BOpWtymDeucO/ntaX9Xf6hZXtp2OOoWqoX/zEdR9IqRF3nisE1e+ObOBZAQhUaBvHJnt" ..
	"lW0thhlOzPe1rvLoGHxcA4pl+zPi9KdBDq3zALzzS7cprwVTx+aknUaYDJ8ITNI7qM8Tkq+xeu/ixWr/dhu7kq4fqyB4YOMP362r" ..
	"sJchJvHwMU7D07reaJG5bC7+1JbxpqU6S3kU1mOJadERkp9J4mHNFiVrhLNp5Dqy2d77ghaWziOV/JDRqabjZHIp7b3CNfftyyC9" ..
	"vCefWQ3XfoIS8L+O2qG+qLled0H5NMslz9W0LaVL+jqKD/+izn8OdLgnEJh/bVTcjL1F1Zpv7OyFSTf/Ytl36YKcsgvWHdxUOsUD" ..
	"H6aVjsovqDDJ2hoAdnLhQGKhdBhsWlRoYEpn8L8ozcl2pcf91ugSW7B7J1NtSHLezADIARHN6mKBcB6r/wL25tkc4w23M5KYGvbP" ..
	"0bqh7opmu65rYXDe4IoyBPR0lDDEPf5wKaSxiHdaSdwmorlVW1LQDy6WA54fGgtdFTl0KJDkP4ZBMajHMx5sF26twH51ICrL+3Py" ..
	""
local PAYLOAD_P8 =
	"7jnJTpNI05Yl+tNXPeEz+bAHOuSvk7d95aNSPiZjUt61XCTkXolurFPePSqD5h7oFT34GKc9vW7/2XY1lU33kvO+Urbv+0eOUw2E" ..
	"O81vlIM2TYdFWQDsmWByACsKBNVW9/8Qu/HB8iNNxuSU9SYfODq5lYKmGqy7I7WI8SlCf8WQ+qn90Q/Db16M4K2+hNmX3PCPRmRZ" ..
	"T5ezfpQQI5CodqS29u0ktBJx9TP7CKC76AUtzhA1BwXn9AUq750UrBaEr8K/6leJfXAcTw3cp84VsXRk1t2wfXFmAOb+1KoNi0bL" ..
	"8GczPjQP+wth5beSswQwrVp8DU4DeSfPD+1gl0Wqhj7tSWjJojs1PbvKVU6RsuZPbYx+uYp65MOImvBkZXpVkXtAHhFDAUzqeqrv" ..
	"ma5r1kU5xot4GX6DnuVtPq7IoWwaGwcD3snuCKKT1IhKd57zXzuTi60XtIL+DcX2YmPtdLmHLqJiVjwt9pdTZ4VM7+vg+oWFw+kW" ..
	"xdQQ8tHe9FCEZKEgkHmPr6sQfZB/ToUtWCwUIHuv7ia3puWPPB3g1ISz9p2pbQfhK1+nDqmbfR5/B+m3Ad6qq7XAh2byippDfvjY" ..
	"9UMOMH0+vsP2278+tkxEUMG1z9FZAzuWAxPh3qXL/ExS3rbPeMGVlrpgy+3UCT+oGZSJYGTOVjEe6oK7gGVAUrsNjlt9hnaIjkTh" ..
	"/I4MxddHRAllZWExawJNp8nW8r1KRhHFfha8KFmS8Bc67Q4BcLaPP1BiclTV1qxfbOFDGWo/78f8oUFOD45ab5oTpPXgXaJRe9Tk" ..
	"oCaxSgKyiZtp38lmksEQJYa2JEYIufhO+XTU4W5J70T1M1kWucN+JecwFf3MBYSg1jN/QqjbiPAeapti/Out9/W0it5gsniyrGP6" ..
	"Ym3WXhwY5rhhcGjfVt1v4/EicscroNwTktUTii24s0gpXB6dNOgbZ06B2wJB6EQUNhUQ5HhRYCb5kMxO6TzinDI58Mbsmp7u7J6I" ..
	"48hJE6XyhG+ZJzzt2nY6kQNd8ElG+jwEPLdo0jpbzQy3O5rFW5Yv3dAPnDJgXI5b5DsVoMTzdyahf1kcjqwQFeNyM3FVq+zVad0K" ..
	"eJ7ny0Q21NfvXgoJNxNk9WDiUDYy0r5WFZYpiRobIRYF4I0GzCe4jbpaLD2MEECkqQXoyld4Z7wk0asUqbKpNG9Bm9f0KG2bMOR0" ..
	"uON3lREi7xcGbpCilsAUEE7zVegybNQLUNHUDJyVmYMTECAY0KJVsBBSrxMdwn6dY4i7eB9piW9/PnKpSFCoumaHEpa+Q+/YZ3xS" ..
	"8Q6On6fmJn0tKdoLjF0iy3BC+7NHCT+MoXftgemH3eBHRSgGFH8uHT/4FinVo95jOBTliF0ChIIvKersiI9Fi18xdbGx2NbjAuxr" ..
	"BguuxWqwNLDLiselc6Snvmpkg5l4JfYXU1PMgWM5cId4zITqkUFhdUKVVNpHdpNIuC4rkljaKwJSdBh5Z4pJTWElyZcXUqeo+5uk" ..
	"nDmYKRfidnIISZv6tiQXtfSQq+xi3I9HNyeWt0BOzAr5klgkSe8MdXmzSRY9crxlAa7EKpMnhkBqz+WFnqzyo5xQ9UhExRXkhj2V" ..
	"x3H/zBTrUpKBSDcVHhboG7Y/TWB3NT+Gu81FFAucw2KPcyyVucjjti69vm36W7IALEbD9Q2Ny2jly8XcpxofX85Z+P0p4LtWbSoK" ..
	"HzJghoWxWuQol2CA7mzD2CcAZ8nAbuXd/Hj7CCqF3QnGhbDM+eJ/ZN6pQFFQX3LktaxuGQSRunJJP3KB69zlUsaRNJejJL3Jezvy" ..
	"hx1HnzwO9KSsRnZoxAhNSdqumSdqPYQuT7Ein+57tNUJORCI2HR2dT8cXZ/Pja3L5iJF8fl1vFo0H1SxD2KnDhHuvWpo+VZU18Ey" ..
	"/jjEU3V3T6js0j7dTdAsayAYcyRqL59z1eQLIKwew1xQNV6GQVlSR1lRTHmuS3SMGNV1eeFFeoDjf9tLlbv6oYAQv1oDIAndIP1z" ..
	"3LnC2iaQzbrcVdH1+RIB4cieLu6UqZntXjEh5jYamz8cUt5hZabA87bdWNddjoJf6oxCX/XmNkhJTfqL7qSOvSlK83ccurGvmxhY" ..
	"DgFgVEOoPX43KR7xTewNVRlt+IwI85JtUHeydzmXgW+RaFrjvNY4UvhymYxPv6tO/P+2SbUbHS4Xm5r46JwyPL1TwEu1NWMFEN8g" ..
	"aYmmGDZCnk9u6Pm7RrRZ3fZX10ad3pWMqdoeFCaMrGgSWpqpCkyWVim6c8E1LYHMXhpNsA/67dSeZ6GIKinrBDwyOi3V6drcsKNv" ..
	"ymknWJsXgV0ZGjy7bAKCy0V8LPLHZ/8S5YfnVSTIavscVwzEuC5rCOMnnQzJ+vnBlUyERuFl/UNwpsX2i8pkrVc2Aa4RqE+KATnZ" ..
	"JArUTLBNd78lATswruaVBkW2FGEDPS6HVGVQQdmfwVZAz/CopmRStpksqCZUhLYN9Ox3HJp2jgaVdXVg7eJSX6tIcOffeXI9ApmC" ..
	"/zQRC7IkSiB8PEIf4jNB2Eltfk8prjlruIXZ0Kh5GcaMF/bqPa76i+QTgcIIRi7I9YJQ9q3SzCQZmMHTd/kbvDee39l8bOs3fmPL" ..
	"W4VJSbASeC0buaTvc8B9FX+lANLprGKXsamBDqjOiF6GhV0wB6phFif2+ZhlcnNb9xrgW2phs7hkdvo2t2pCrcjGY/H0vPyJOScO" ..
	"memchONptv9ruVMwwLa1lcEIuXfDzlvarkgT61Is7DKiEMdrh75nUxAN/yhSO8bV0t2JVLSv2FyPn4O0KbFHHZHIVAbH2KvkgRQg" ..
	"btZBhv07DcbJpCmHZ/WfG0/KSEldQSmcv3/F0GVWZggabPdd3MUJLR9uC5vXPXShB3731JtnljTzKzeabi4uVxWWAG+dw0uBma8j" ..
	"ncYJtZFPJLuP3AjV80/UYo81joVPC85L8KUi+TuL9AjU/4Op1ofygG4aSTmCbDvgivcSu31WHSh+weERA02m+iXvoHvqIvgMfZtj" ..
	"bKn8wZPW5BseMImcAqpP/I+SWU+0XWQ+9KsJzK6yXgUUgJ3NjzszbVAfox+z0EfCq9aBTYUmtTOwjqBDhfYrJXi36g0I8KA47vrN" ..
	"/+Al4YbyNYBYqXYoy3AmV50B1deeQyWD1MIHVM8xZUoiRK1uFOu4IaXeatOrmsfmqljLDEdS2b522h3aC+6VCqNRKiQeZCTLv4Sd" ..
	"sm7lGjtcFUjNbhcwkhE1xEv5H4d97rx7IoPYJVJmCTT5YWjSotDhFIQTwg36BCyarsZr/CpJQeafFIzMjOK3MMLI4jToSKEcFzAq" ..
	"7dGNtqArgC5yVxrORZX3n/LOnwzX/+JJV7Jnt4EkYFVp565aSOxcsy5JRtB8DN8vQNv3ODPOs3+P01LVdxmzQmWdcwAyen42Y6Ec" ..
	"UGEFQqnCDB+bh2SuK/P0xf4/HM6qxU5GqQlJ0Vg5vOsOSasQpm/JGpqRhM7j61/0j+KHUSOCv7T3Ngyg37tp1IFkQ7MOTGAfALGF" ..
	"S7bHm7AX06zJV5XaS+c2uJwkOQyyRe4g+97cGqwZS9eYTfHa1F21cdmGJ2Z9VBVmDGgTUaas3rT2ZfTAVPCL+IXwyBZZh3YbkeEq" ..
	"WvUzSdKOBgOcYvrWGINI+6j/PeCt9WQyw0vDUqDl3KfppoczIl+jJO91dfW9VM0PqAUOYGhJfkAOPRkUpyS6BegPb6ZuIHpS3Qro" ..
	"KJyyWKrCXhBUZi7dTyhQTN+URu7aIS63177Y7tovWTCmM4hAtxtYCgzwY6uCw6hDWHt0hjWHT8jgcMMK8/wbnqNZr5gKd4XW012H" ..
	"WQgjTDXK/r1LuiDdTEqeBAbqAnhe7EdSplLcwPi2JSOiHtxmS87YbmVYMyi0DKv15sD3ESJLTvO5kIC6ZelZ1q9nWGEQAXyLzvEA" ..
	"IpE2oTtKUrZBNlppTAGUPVsy2DOLFowLOF+IfXhUvFAXtyvSrlYbnS95EOIYw2BomdbGyGwFBrzZtzI7Ktn1ACeQiAcFPq/jAlVA" ..
	"M9mcHa0gxrRoPgYsGKkrUHIgGkX/tIhPyXaZ/xu4AYiF95YqFI3WaRJ5XmQORzhKreiZ4vAoJOibk80q8AcFGrgjGl/May2cGUIi" ..
	"AN6WH97yYywkc4eM8svmmtkWq7JjEq5ryfzAT0jtXjSwTuEraRycxD/PY7aFMpmsyA48FrN/NCUkgKwixmHOKFdEMXGi5v8Tgkja" ..
	"FsFtptMgysRxP6TC95F8jyNN0gLHruHlwE/Py2YdfV5OCaYFwJ9EWUU0SmHTpjPF3hC4rBCpCkTZy2YuyT3C1zmobVrOC78MYsWi" ..
	"E0IjyzRPkt8/EVaJqyIfaIleegxh3QiJwLHF1W79Enh5twSUP4kC2cG6vhVSVySftW9r3ZTg4H3cdddBU2hCu+D4LE/xCdlR2SPp" ..
	"b8WkIH2Y0rycEOem5n3N9mZHpM2zJNuyApWBcQzjmKRvMeCwcsDGS8h8A4Z7nuG759ZGfxMxwkhui7BIZkHT4WfoYo/Qc2m7HZMT" ..
	"CXHfdqQ4/g5BBLfvso5PsbfhmB6GXpJNpRgJEEf3Wr6dSh1JOEGPDvQi+DWfdmslgToER2fPJSByAfGmTUYGx9j/hWgAh95P3yIm" ..
	"wvj4W3uKH9OCrk0oMPYZFqKcyKoAw/dADUj1/ttCIqNHqqPy7BboO2WZiEM0F6HujK12Z7zAf+UfAe0p7z9IvWXgihdrFQ5ZvsBn" ..
	"2po/LtwAjH29I7dyCG31csRCsH2WVQMAJkXQWkfhpGZWWlfc47YzH+CyLSE/8JI9DvnjbuNEJm9T+5ARwznIt00z26BZud8UYxBL" ..
	"n3VvweJZAFAgweUL+l8mAR17zAqh4Oks/wTQJzkSWY8AihcqjVuGI+u0Kl9V2wDoebUcEvXjbbzds3BqJqxh+lc653InWIQux/4n" ..
	"6ouOiO/Q2UcCKmoelTZggXfoCdEtu25wUVIXi006erxbO1hMz1iiEVEqn3Zg0eWYPFaU9ZKAvCHwXK4MCTm6ZIzJRKoWSyLB5u8D" ..
	"GGV+uZd6+gMHZVYjxLP78gDxARf57Z381dSW6OSCEDwELa4uqLk/eKfp2jT2wwowx1QQYJp7oNONYdOTJ/JEjHleJixZGngoZVJ+" ..
	"TaApYRLyDINfv6U+XZsaYpGR7n4isto1ByVZ+a+GyKBkPuA1LOhVI9aeg2IGrIOnwvUgvKUcyX2OebvkesuRDRTfO4MaxwxeJ3Fb" ..
	"oIRopMVF+e4wRRcDWNgunuExAA+fPF6dDg6aapU/CaYe9D3a8RkCRdZ7xEvLbsMaqOfKWC+QiqQfGEptrC8nKyJ55UAVLcb++yy6" ..
	"QazpyWtoWELilv4i//h579QZcEKuH4DKCe9FUQOghGFO69U4vhAGj31uxpe0Pg09BCtn3jMRUyIdUaHH+PpCwOhsrpt2PV8PI7Gt" ..
	"DcAlBAw1xzdn1z6GyJXKjEdbCDicG47GDReDp8WvBIHq2qBUzkiMvj1475NgFl3NrgBHuRNIH0clsbaYJjjv33956/PM7oIUFryX" ..
	"3GR8fwvfq36b9aPYvlMxPHwUvlav60yiS7fK/v+wYHy6ZNVU9mBRe0kh3vj3a0+dv/xqGld+YBf92IsKzRziMunSVYxNH9P0H5t+" ..
	"koMWLmiw2Wqj96NnySxVCX4lQTkpsF2G/7dpstssdCxag4fUv0Wrz/+BnTlraql07+2EGGf4MYlqK3vOSi6NjzgnU0TFGk0D8+Qz" ..
	"RlmEuZeY9NVsI1uTtTXt0ibChm1WYYDzaWJjCCWfH4S/2cM6o1pNi/GbJJIDWXon7HP/h0h2gPhWC0F5FJB1MXpWUW/M8fUWh5QU" ..
	"ghyugFmTjQpoHz4SEwGxHXbP9gfeII3UVZM+Hn499/njAvRA+wAhxXlztgb5VdaZkUkij/sCQFL3Xj0bxs1nJ4GoHBerm5ZbDkTp" ..
	"wK5p3JqX/PclAdvWxQRc8aJA1jfI9P9LB3pF+cGdXbd4raxEw3AGT1+2eNCxJ219Ft4nSnxtXX4vUtiVARqiC2G03MrlSMMGgBkl" ..
	""
local PAYLOAD_P9 =
	"eL4xg8fncZro3xAHoBNmeOF5uPkcIwJtxHxOExecfM2yyOy4PvxYyQ1ByeZ71FQCHujTxN/er71Zf1ikPr/qxkVKQsLiXWSW09R4" ..
	"T0RNg4WZgvxRX1NjYrIKwjA15/QY2U3EvZaAoReQmwn37MPDHjAC4qkaPZwf4hrVguugcGYohZQJeKTYPd/sxTcXmoQiXyBh7/T8" ..
	"IW88yadeRrhpZFHp0YmRVYYxqLAPKnoqKUHHvFqoLjn/HoL9dknL4hQYOiQfzOkOqpRQOEBk8brgSfM+tEBRDCX6j6Ai2lKzC1SS" ..
	"zwOhbSI/A7vJlIkbH12UJp4erXeSUbXbNGaTO5+L1Vz4TX3xCeiFr4C07wmKB90W9mID5fPWzv810NKKn3b0QMyR4MYbMB5+L1ba" ..
	"J8ZOYQu96EetArTN0YVFRMSWbpb6bHxkpZGl0bPgGY+APaW/l/TskKwdLOG9vfWo+SuNjkT037icmHWu6nYk0/eb5c7CT87u2IHk" ..
	"nhB6ifwHzcvZNzRejSUOzqqHaIIRZgiZGJzhUq+YMepOvj8bDTM6mNCeGAOoQ+SmVxaXli5Bd5E5ESdaCQUNsXmhoGvnxdIoTnXb" ..
	"T2/6/VymiaDJPQmgKXcAFC80XHiYC0D6RXVBT9a7RyVKlR8mdYRxkecwBDmrDaWHidjhJscBVlv5MQL6BLSVDeggkqBxDHwy6MXn" ..
	"GVBRU3Kua2XM6z1O0mf2WNM/rto7ck/Y7YzGrn6zxZgXmKEPQUmZIitR1v4efd8qVRy4AAnF74DRZ/bqwbCaZIBVENdKJlxhC9tD" ..
	"YcM+Xi39WliZQJE5q7Eey2D/GshBhXebqxHpnfUUfVykciMOAJP2T1oc4RrahNt+5zPeFZAYuGvdW5sgIOhPNOGL6OriC7SMZhUe" ..
	"eEfM6LUVHGT/iHrajJZDLcxyspxjMXmu314NHtLnFv/rzmcjETOSTSU5I/x8OmNsjFWlMhrF4Ps9LCxLrot9wWWzuRcWwr0oLU16" ..
	"dM/qAGgX0U7xRFBN0UwoO9u/VUbjoRRn/uyWc7Af401aRwzi3WGsXppRxUo4DuexzPMvkdOrDZEMC573FAgbGvFt9bafh4pZWUcY" ..
	"FF8gfS/qxX2rXIdYIs/dzJYIGE9F/rGtM9f1MzY1n84Op6XZIhhkfBE5tTGMW218H+Qj2/8s67pBvZu5z6F5Qv3fQhCJTmTgDIx1" ..
	"vxFGbXRH/vQQ/Tga4WioYk6VNWOKzytkoldB96UePtyIsegkUM5Z0yM8HK9IaYLzeL81sSzOjOdRmH1vjGtVhBxy0iyNhmn+HPw0" ..
	"hVPXtxM8VLqCTRkiCRmkaWBKhtJ6Fdi8eNKZ1uTzUShEVelrqRN7RNI06h17n6jEZTCmbERcry1QH5AkJglDGcYsp1fg/S6NFt+w" ..
	"MtFZ9n1s8OtwxD99ykibw96nUN/+XF5DUuw8Y8/XkQy8ISPfHkehQPaFKZBVVwnUQBzm0AHteyBWr14UtF18koc/KApcthHZkkVK" ..
	"nEBLLEoLqD4z5dZdid5h5rrpuSo7/GtdgXl/LtTQyv9P5KmpEzzERjeq3UTBaUejRFHTnsVcMmSzwHuW81PrYSZEL4yRW/e+wZ4B" ..
	"ClRX8HXMrPnvxyxRc2PB/qEBOYOWuVdjKGGutOMW6Qi0aP4jbZ8fBaF01ZH+Re6GPEnv3f+kvl54aKLv3oPKOMnk1PaCt1KT3418" ..
	"/L1qKeerfnUHh3Zm0Vyif/ZxZEkoTbk7/NDGYnlrDcT7xDpSXCsOo0LWXi6vJXOL/P87o5tWKZPwc7uYg3ZniCYZ2hb/rvUUoBeN" ..
	"qAyiq2H0COqa6oytIIs4Zw/Q4EsapkzTryeJOxPGv1iRWvsqYLb/DYgDoJi2jsE2g8yRozGol72UHerR0FVAdamF3+/qDDbN9Aua" ..
	"zViPDoYEvQp8N+GLfStBXlM0BogYRhJXeAwSRaQGF2C02WWRolZlptgVgejUnZKQ/bf9keNSCLj/6irtD745Ik/KVFoabB1cEgny" ..
	"g5XOGNSDZNGsqkLSgbsn6ybXc//IOpycK5c1AefisoamgxY7RmJsoPUzWPLzASrA/+d27PgJLYdzfRbtvMD6GMV64TyQWXrsztIt" ..
	"8aETTAzoDu54THFq8faGytUwlSnz/sTep5jPXRd71yofZOKV/Xt5dqwzOB7mAaDQxJ0fXZKz8pSetEyF1nsZ7vCCPxM5VSn8S6E/" ..
	"OEJYuaj9BLxi62+QuEAKBl0SAAaFHbsAn+8Sm6KeLSESqf1rXUn6W6/YtKdk8LsoZ1YwDVO7Bn6AmoYNbQPmwg3GZq2A+bK+MHS4" ..
	"mJpdVT75Jo9j+qQhth84eP0baibMf8D5Y6ojEl8wgSejYj+wdpx5c8WMXj/RwTvjY0X1iPAVQmZuKJoys3deHjdzhb6ELCKWiPUU" ..
	"9q9YKUKeZRskw7dWC2+0FmkEMjXWkwkDicf5IyFz6fm8XT9FTD+awibz72+q3hR4+27o3B/hOh7RB6ZKhiJwe9AwKI6HbZx59iUD" ..
	"rreCFTBrI6bIF/nUM0FvgZfusNz5Pi30+W9VsAYVFck1fg3+YiKJrHKLDxL+Zo0rpFjKOyUs162hkag5WlDfD5DFmmA5W/XvRv5J" ..
	"ioTSlbjDe8/zgafRPgno805Wlq3gOBNkv3Y1opyZklBv+9fUkazKLlGjdkEbvci6Zes8knTTtmshYxgW+gLiYvDBm41sfFog9PwR" ..
	"H2JlNKCK6W/mHuAQxtBr6F69KL1ncd/wQFhsiuuGh7N2B4Y3ByGNU7FaxoboUq1xUJYPz3K5SpTHyCkFGW8C1c6hy8M0US2n6FWv" ..
	"/ZOM5QDdJMYhEam+bIsI1gAMOOgCIPBFCxTCNKJjHGbCdxsLR5dQzoXngEJquDtJJdKjrv820JoGNi8WJVuN/gYZYWdzFUcOhMlQ" ..
	"bv3lCYe5fCiJD2i8WSQmBFMkvGWCm0Vm0OM7Z+md9iqkb59xy4QkYX/e3MnEY8uVyiS58DRF6I4yUErgKshk0YGr1k4tzsQ3f+Zn" ..
	"QujAJAZqIEBf4PRdfw1CqKA2dwpalGKVa2908d05uKaTwQXOtp1ifJZRZ1dTHj6tzmZYroZmvWolWnz9QOq+AXJp0a3cTs3fMVve" ..
	"zOulUUxETuqYe8flu5EHVt1wdabmdDY6wM/QQwnd+HfGVV2Lr3yzEWUF4YqWBE9SlM3FR4S58nhxa+lCZCsyLT8xZ+fTP/Y+pDMH" ..
	"Kz/vXIQC/1Hg2cGgGxo6uLSjQNPAOZ9Eq7MxFyYP2vFMaCbcBGexOis2xzwQR/FWLQT78rJRmVYfODI2MRfqrojwnyFSXFOhLjxm" ..
	"SOyDaTL16BwItyi5H/6P8lpXpHTduZyUrFqtjp3xt+nbSkK3LkEtkb0wWS4s2UqYVex9nRw/DuIIDJlp25b+/xV2Rb2s9uNELjP+" ..
	"fXU77AIMNr0woFFb9U92INuZ/eGQd2ZALyA/S4FD44B4vV/B1sbwYKeXSmhFCuFDrwQXX+LMeiQN7jPkazD3S7FXXDDYFoZoGvQu" ..
	"NCGhnj5svDXX2jIksXPOA4ew09v9+05VXOKtihe8IrUFrqOkcrz2pMHfc0FHt/6hy5HmLBTYx5me3Y2VnDJnG/OwqXHF+FMLoB2V" ..
	"kW2yVOn6vKeUHZDeMr85dKaYsvnbVWdZkFiKfpZ1zM8bHcVhYQgvA0aMl5tHHU7BWkQ3pkmjht2fdnDX4jjgc1uOLPJQx63Davhl" ..
	"6lg8Fn3uPOVFoeYNq6dY+B+DZPgDux6Y8U9VqBBjSd47LIb94/H857W0QMHWoD6Rf3V6+wQApg3mFuNBqdL47+kL4RSMbRENWCzQ" ..
	"LYGda4a7/XhPJXZIiQyIs/aatn3p/j9wYlOlxHtR1vTy7hfcS5WSyTZXQMDMs16qxEmf/FCCTToTum7F4xFw8ipBZX0F94Mjjv1K" ..
	"xTPJcnsBZAuFV5MWZitmQyDilTT1VBGfx/qUIg3VF0X/+FTGytty3i/PfQeG1tM7hcJu1qokeTcbvJnprkXzjSDqHq8NJf6cbbjM" ..
	"5EO4RcEx+b0mEIdRMH4BHA8pPB9KATntokyX/OrzmNQsYXtdTobDk9jp1de0NVfv0/2JndG6Z/x9HiZ+vQYMXnkMYJ+n+Ao6P+UN" ..
	"JNMrdg5fgCM4fF0FQ1CX3OeQssouXS6/HRzWWSUdILZz0gDfsk1FFmE/u+Yx35R0snpK/QuHPoFQwq0EnUsM/9vHkP+dBjYqo69B" ..
	"YI2fTT6UrATdpIfUnwobqGTYfAbFCUzALyfe1BchXgHmP2mZIIKeILOpcscAZBzcd6eEyob/Msn7ff6wQj8bMOuctmCmnEgQ5Mut" ..
	"pguY8tY5j6A6cVI7rxpRSBsl/Y5sRCfeX5INQY+SP+hDmPN894pCoDMF3zPDtFApBK+5HC/bJIfVmGKkR2dq3s+DNIyM50JYfUPA" ..
	"Ss/s4bDXDTTfhFj4TKZCJd//YvKlahIBPXNNEJx07w6F2UeKAUNM+Z6hhoz+uubGcw4Ycog2VFU7b5ZhO4KJ3msuTV3ze9/qw81W" ..
	"+QphtudOxS2Tohd2gvLDDO2WyElM7SwT56mX2pwAjmGkwkXqHSfzQte8fV9iX4AIpuvzyvnRz2qbhyfURV7c0sOu6xISSnc7Kf+F" ..
	"aYHaxgJFnFKnLKsIa4o82AT3rcu2BE1creowCC1P2p0ZfzjRcT6HKohTeZxtGmDMZW64+0kbf6B7idFYR7AQfIC/4Ad10OBum5w6" ..
	"2aBEEu2dv48XVgXygqK/tKIbnL0ZHWYoXv9uN4rYOSPAOEGUT//nUXeH3B1Pgf8ivV+H3ZcwEWRtTwyUCRYbjklYoTTbACVbZPKQ" ..
	"bPp0413jzHHbmL/zmbtsFVOborYOthrIbI+EsleVxBK/fdjnpoeuYZcOqpJ2WApSXm6Tl58oTzY3gkM1qtLs9EIzuvCxFkFrICo/" ..
	"KmP/mE7+yog13gmss0Xz04hqJYI9lx0ple2wCwFErhOeoDdGgmj+dqn1qnrbjNOIu57aG3dfSW240FbRRan1zIMGgedXpcnTB3ab" ..
	"2F7C41BNY3cMK+iHacP21NeOVKkp2yuqDoOgVCRMZlCzo9d5TjCCYQDsCcyKL02GN3Gr7mzCNmftehMswPobGu32Ea5J6buodVxR" ..
	"Pnc/99GDWmktjx2ZYxp2eD/HUcER2QjD7Msj9jfkj49hSdcufQ+ZX+h01VzVxUuXCPvZpQ82tRFGzTLc7UemOfDPhQF47KX3Eadb" ..
	"10bNW/V1gKUqoZxngNqpwtvnoWXUFHU45Ef101zs1z0PO2wY0m7QeoZ1GOhO+eGsmhuy+qSZyGylGVBN2bH0v7Cj763TR9oOjxiD" ..
	"u67F6GFQE9zHKP6shyldyEB2ym1LPS67TkE1tyARceSquXR5vi8vcbk/hodeZDRQkh6HrfpR+OGRG+j984xSQHu745i9+qN9yvSg" ..
	"vfFQ3j6CvQwgiq5Ln8RXyzMDd2cKdalVLpa2XdFs/IQVdc0oEmt+tJzstFatq6SsVsB3Zj7E+2g6j8cAgbaaw8p7ee1M5V1Qg/lm" ..
	"sUNXTSlmUfDNQiz4HxjpbwB0npErNRGEGrW7diiAV2RyALzU+Ml+A5UD2/QjGh1Q8szrhCQUkzZ4vBy2QmSzffS0wCh04DhJuKYE" ..
	"s7bWgFmWPtUvKBmIUlvk7cAk1axQEwfzQhQ5By25cOnqY9mnwco+dcdeU0ttL/pre6i8seHPJLUfHlRsBsQ4INMP+GParee0tK1e" ..
	"KnawGZvF+lH2Mnb2xRz0PHAF0sbo/iLyOXM/I758uZUnR3AVD8fwDRIjsUg4FXs46+Zae33Xy6Re25G3Ai2xQxAvkfhZbOjf77gG" ..
	"HAbAmhqJMp7RpZPlrSDbT6ruwb2n5aDvVa8S9LcuUPsscbuo4araaadZHVsfs/6sjykWAagC+fFiSQWrolQdLPBrwPj78kBfE3Fo" ..
	"Hir2OsKlMFWEzZ6q3m9HSSFpQybazHjcca/c0KxCc0/z6A68u82g6+7IkmZCFS+48WhzhElsZJRS9iXPrRevXpJx6MsFhOSsDvS2" ..
	""
local PAYLOAD_P10 =
	"YfxRC8suarx7kbczdLx7riSqpNJVY+9ZJ4zh2svH8dJL+5rKyZWF9KDSdrF5gNzs1KooF2dwBJOYyPbwi5eqgWlUiA/Vbqn4F/3n" ..
	"GH8TOCUgemzQ7aG6hqCOag3LQcP4jxkSeF/trgUNoOEkOBH5KYyoKp5VjwAqgAbuanspI3blIAMWIsFlFenfENOJXkasAjfYvly4" ..
	"AXlBz+zin3cOIwwhVDJI+DL+92shAKmIwQxnB18fbgZ3k9Rt8E14LqRyzsZnitycWgRcGUn6sTiSPst+Ft+QgpvO5d0kpQ+Lwt3L" ..
	"MN3ZrZH8EySCTZzWyh4am3elZZHTV27SfXcm+JFWf24y3NSiF9nIAoVhOA6fqn16YyKQ/mVS0fQALncSPDEG7fVByPmDZsgcgg1G" ..
	"S34H3n3IzKT+NHM+BYRNZ4tjDvbBdtiZbG/SwqgNRnPIlAAseUfO0jYLY1FzosJEjjmq1Emq1oNK03rEMGS0+ReQ51GribTI9jAY" ..
	"jmVS0tL8NbWysYL7nLLLEiFXcbgt6vuwACLqmSwIb06V4lQRw3JwcIU1TbYptWEkLYLZp/Ua3NIajDE9AvnYE5Eu+akvwwW5kvZ7" ..
	"fcxrSp2OmSVHpECjck35hPetSQwnzKxCfQmv0nywpTgIp6YZodWm8z9lMKQkpkG+jmdYdFxwvwJRSFdPIYs97nfqOMf6il9mfR6u" ..
	"mMNxfbrkRw/pv6UsiC1AFXv3A+24VMZSoqqzxLctJTn0ouRBfqJ2JeracGezjfZnrNrgghT019f+KYSYmb93GsMALwW5sn4vsCkF" ..
	"9eRtlZsWTlLcWiMzsP0n1tqIyU9mP28C0gzREhKR+bV0fcSGNxIiZQgCub03IFsm28X4/DehvfoeSb9+ogLciXYdJl9BuM/u/aRS" ..
	"IsCiyD2ALXEMUGPuYlFUH4mXCPRPop/tiH+3zVyeemXJhgAAr4ioOA24u6hg+FF/4aGkwccMEhXW/LP5H0pc3eJd4JPE3iMTcMa1" ..
	"lMYWg67QGr25IJQ5K+aHZ3P+6RV/tTygPvFeoMRoIIbX4W+39EIhJs582akbX/aDsR8c61dmcaL/JjedRMRR7xeMxpKBhi/tjsug" ..
	"217I+fXHDer1zLwq9bMJmvUvgey23YMh/CRj1+kLvUaikuE2OKYrG2/h1Sqmu6KiA8pOphjdv8Wa/GcHSgnfQmF6KBPCFqmCtSX/" ..
	"taB4kqwY9ELyAHONQV3QHw7ieyQLSRcQqhYlnVwznfz9/ZPMNHDFAOHRtZNf/9VfwoSV4ln96H3E3vbusu47i4eiNI9IkySXkq7B" ..
	"VE8+3jGoC0rk7bQkL+laaHboJta3c8q0rEOc59uTW4EzYBTpQPHhHaFWAS1ZJwi0YtXLpRFuJF1qSy4kvE23+MMzamzYEm/q2uwx" ..
	"YmTnhA+ogDMrHLx2GO95DnLhuIgGz3M1E32V9igRq6ECkmw0ym1sXvWajZgmuoBQd71jFvFZ6rsfDvuXMqpjZzFvXCzgAZoNezvQ" ..
	"+dLoVIPkqBhI2rwqV7U6DiXJxdohyEMHjSdXoR6FVXutWFl/McivEYHoRRN2sx0DH/2oDcmg2DTRjtWL7lCyXLwsnqQyDewb07Hw" ..
	"lkbCmyKaOF+xwjAGW8n7UXLSn1x5VixjVsdEUe7gUN3PtKwqsdDNsF8nXUuJT7eIVYLiJYaOlo8STz/MGF7GahfOOXUmupYNlkrL" ..
	"0xigo/QoQMxHHhOxTZElaQKqzho++3xzTTlLeQXDylsGeGCJyLBHresKEifpU8ILxQ2myOx9Cs9zuF8D0gf31XrcnLS/JA0A1yYl" ..
	"18xmE7w5jiWDPzW9SScs6RXexn9/sT96dJVKmfUMPPQ0HTi4HGDmKcgVWpU+/+qVlUV3CP6NTbCtQ0TFU2vmf4lWN7JbxLfRbeUa" ..
	"Qj0I7S9gpb3qd63n95IHXq3R76uwFLTcP0Ven1W5GqXA33DpentjVnUXedlLSNAeBqgs+QZoAk+vieKrZEz3MeDvOVQTLhkk+kqG" ..
	"vCBxjWSk9FF6cHbYTISUqL2KddIhyHLXyVgMdL8xmcnAVEzbqUj43hXkHSYyRNIHSqg3sSCqtFrhXk9OIJqGG+A9kBONnwzV06Sg" ..
	"Vy3R9lNx7sAXNYv2MxJBqpFoyIucy2cDtwE2h3JUY1xQoI5+WHmBxN1nKfpSB4gfQKy4lAYSOQa75vbYQt5r1Mgy8YNsBZWyZCut" ..
	"l3OoSNN9ypoaeRC6AnjIe0SapJn3bAfo0mCYp/QyMsKGeyTM3sdt6WN6w7LnsesjdB9QgcKYhFRv7cp8WRjnaccA1I7DKtg0MU5T" ..
	"CKwEk34RZQOmz7VH5MBCrcs3F3maIN78AfBSdHRyUiLGJr84mCD2UVXKkaccLHZ6g+zJWgVVx1RSX5Yuy51kpZNlrGRkhHgqp8OW" ..
	"hOcpfTzBMqg5H6B/U+5a76Ge9dzLKvP68ZPlL9YBwvHpA9G+kEFoYkaM8jcimk2KayD+WPXEpbNkaZFNpaS2nqmO7uXmCtC4/hiP" ..
	"6G1U65TKDKqRbiwzqzmurj/3CLUROp5n9kYDv4IaJHjnakT5Qq5i3Q9UWKSe8jAXpGJfCNH+khDKOqs1+ihRHJ322kQkeOgJrN2A" ..
	"l+Fh7v9nCH6ddK1+vJBzAz1g282pmYUsk/rTJl5nf1X5nZPJ/G1ibw66D2NQIOblYLcyobJmlDn/gEDIEns4KvP4p1iZb/JBjAdJ" ..
	"RbAc2n7qszH7OzC7ZBDuZC54/obrsVsm+zFd4585BhBcxYG6AnbSZ3sCC9xIszOj5vJo8Tk3Xz/slB2IwkCNTjWgCHE0bNPtq7nN" ..
	"j+byfsnTKlUziAxkLxsGTzLzZftBPXw3JpvcLU4AN1Zt7DjzdxH91dwUiivb/5s8M4fo9mp07opJmeUtycm45rdUsOlosYho4TOV" ..
	"O5dXQr3IuojnjekCPUhKc1mXCbo0ZIvHDSPAt8ywZrJwscgo0+h5uUhiWsLbwwo0dsDyi9a93vuAITH5dJWfh9DVfSxemyEWwXEn" ..
	"5qNIW0DqkEE5QmXa6rZYBiBoqwHeabw5766TjoTBqThmEtuR4Jq/qlC8Zp4VbtFXqA/3NlvD1yinuLTyDkFlF7ZsdSFmsNjCY8Fa" ..
	"YtqsKpv5lBVQjpek5TR/rMTHgkyPjWWzoLQTyqx5M0saoTdWZefcJMpIWpBMdbv4pzN7NPE2ZhJs/acZKlHlF09QGkwVtneETGOs" ..
	"m9FzmHd8zyE3vpKA8RENUJYj2R458TQcRvE4CsmbpRybFu+njy9Q8/Xeh/OHySApl8N13xL4ZQcQmQjaU38Ot/IDkMRbp2xrjeV5" ..
	"JwOyq6whWiRAalZLKhhw196OjkCwebN5ftOPwkxOB3Qx+5OaWxDJyp8QgQguISJcP65LMv5vAdZLgfXwwrcK6YUvk1KVYkv2fehq" ..
	"Yav5unpV+jzucGS4+2nsFhfHbkevt6nMrDK5gNwg41PMOTVCMsBlV1loW8Y4haJBy8oUOJy3L3QMofZq+3lvAJyx3bfVUix42G2T" ..
	"qVTHlwh/JUdFhJnaNQ3P9Y9Wz3txdHGHzTAmwWjr4n+4miFGidYf5QUPg1cN3gNDJ5TLctuX0Cm6o2/8H4MQ1p7+fyEHp7znr2Yj" ..
	"OMs8zp/pmyE9RYTMDfN0okulls8CaAm76snnK/r8d46gx2f7eJhR9BC47C0WLfsLveyrLBdkcACi6+SVWXlRV9uVNOA46FZ864am" ..
	"Iv2gEzzPlZ1iwKUjai2pkZiN8NP3KRX0n/RKYKKl/C0aXWgRUdpzsG8TR0Twx5JVWJcR5gdwtTf8hrP603Ip+ZTTggmQ45sZgXZY" ..
	"Uj3wdourB+3ExiUIaiWDjXcTCAtUFCuhCLSciwWpvaC4ZYkep4jHQ/6o5Bcoo2AmRTKeVeLUBxPjOJPGI7g6VnFbWIBWEmTNJwU6" ..
	"4eE370asTLevixE6ghNEiX3AvZe1KI+a3alcc3XnAEan4wqTfNQfFDo2DJDVBxc439RqZiDDoxlM9ROUQB7i+KM81tveYkbnSzON" ..
	"Yik7eSgHLLh26P7HS+qQIPJmIEm+UVMxeJo57DnH1I+pY/ts+Ais3AEH9OeWa2XeFvGEjodNjTVghkS8h7I99Zu3fLUQ1Xapcuba" ..
	"V9Ta++4Shch6MqWtJC7EuHOgoUUgrsORo2zoq+qbWEILvyS/4HXyhG044q46Whr7dxYmpqvnWushnFi7Av0YA+Owx0FGj6laLhf7" ..
	"nY2yRkIIl5wF2COcS2s4Qpd5FH34/vzYwB5tAMfcWMzFXKgLKojLCWDXhCUd9OyX3WwtWTkfVevEognim4iQAR18t43PQu0IkPGh" ..
	"KXZpVsUn/TvOflhIDH7OozVDB8lKGlWahPb4C9gal2TQUBsSW5bTVGqUfiDHAmfwGQe6iG932Nk6sQStQa8xH19KHS+HJBMgE8zV" ..
	"ZLIwhqFL1NMqNqVp/akfZ8fKvusW2Im4axrlDZSj83TWsOZqYTyYszH/Fy2HfvVejUO5EcGjdbKXFvy/Hap6INcItnRLkCIUUFkg" ..
	"3hyQXNSvLxtFrNqKjE9jV/4gILZP6jvfcfAW4+8zfdeZDnP/wefhH5ut4SZhvos3y6cK8oEcVEqAvGDUHgj17fh0A9FxYW9k0XN3" ..
	"ALPy5uoTV5eTTPffDU1SLwu5hkDL+4ftqHidEq17RSn/tqHsPE9xCd2wUxcmm6npvvLn0pgDBzWDlpvf/4Vh6NjHXIoa//O19s7n" ..
	"YnLbWC86O8UhW1ZgzYUURtZ5fJftM3cQn9mcQH35KYdXfCqRIJ+XIZfECOBI4zORv6MYswMj+wDSk7sDD+i6498dHr2duud9JzzC" ..
	"a9obApwzDnPuk7Dcf50j4Cud4d8gQhU5HhVU6+tRA36NoBiBqRZtnBjmICUVH3DA4TfFz5S0TGa30g4b5wo7VfZ/FzlEEoZFReD0" ..
	"TcWtoBxgTGt4snmOzyyHw70MuQangYOFgYwBioyT5c8TneaOVMgrmvrvcJ0y97tZ54a3wmnFZknKOXw6P7XE+wVk0Hb6/yiDcIBp" ..
	"wrCMJ3UCqNGytYl4wOAVIFr11xn5KKOLdchA75QVeNQ7Tx/ScwYET9Xgv5QLyvjuVhrKtAnO0rpLwfpec+V4VQ8eEBJcnqSlvht1" ..
	"eFy63YPUBjIrZ0d0z/uS+Byw7DHVn/LoeDlBYY+XVX8HsyJaKKz1Uza9YCqHR3t2QZYYJp2UfwZE6mwfY7aZ0hs/APK6zMRWBzot" ..
	"QunBQn06rKi+Nms9d07TT/ibzbEAEdj9FnhrPqJ9f61+7xmqlqaEPiZBkB+IZ/Frvkoi8mKoUHUgUoomccqcoVO/ce/JJqjQXmOS" ..
	"cbzB1nSeOxLhy69FYpRvjJkODKhWsao/o0aD986oGAgaqVqnb/qMOnLnybT4b311uyM7gSdVLa3q8pkLilnHpMtFD8vtzliTcXZe" ..
	"wPel+Oza+0xHa0EmvQvGdSgQkgAiLcgcGFSRDA+E+eoo2SF/+Ee3FQFdqU+Bak0apT8DnL9NACCTlyObFiCuHpf9oPaCWk4sI5Ps" ..
	"YLZhmeKzQmf4Xg+IeR/5F7ybsVHR/VlgXOAHBf5KlS7JoT+1Cu8Vg/KubOCjUwTQYqgBLE0/i7ASIZwJnm25TVXrYKn4y4eXVTn2" ..
	"6Jl4E48tAaUNY7J4G81F4dqxmXQT72ZELLM5ERh4glGEkqhm0MIlW82GcOpGYGSo983BMS7zdQjQC8WbYJg6xBj2Zr4/ZN63zKDw" ..
	"tNjbCWYVoZ5Z9UU2ntP/0m1r3rYg5KGlO3N05N4c3Zwp6/NtUyhhZ7SS98CMjhW52d+mp6gGvlbP4i9qCGgiThVCJ+e7QMG1dnmE" ..
	"Wm2UG0bKcU6qDf4pII06VF3qp7vR3vGNiTVp8yhRczn2URm9ZmDK2eJdVMQ60DEHfN+vH5FFK5XtO4gZ25cH8eaqiEdvptGwChxT" ..
	"GmdYK98IOc94iBcchxOz1SIx1y6d/I+e0tSMLAEbRQXRh3I15KCZtzHBJwSpQcS2ExXtn6O8m+RAyOofAQpXMqajMehXvw5NqLNp" ..
	""
local PAYLOAD_P11 =
	"bvjZ6PxiAwJqhqRfbYCaanK8XZl12d1R/sDym0VBmtjwDSToPWZK2dVahNrC3WKyk8OnqX8u3knxB1QR2q3OX2dWF18RNl2H3rrZ" ..
	"Ms6rUo43WDda5aTQH3ScPPfgD5WQB0urb1eeWaq919iyFb0f26S3Cfa1HRoHBy+GUIskINTpFVZWwX/N1WqaEvtKXR3b/UjAfOdj" ..
	"NioUDz4GIatTm/eUxPMTiQ8wyDmipqKjrOn/Cl+2ZFIPcclS8c4W8xLgpG9X5IlYUn18TfdIQDlCxgEMSbFHyaKDAC4UenqXUcLV" ..
	"uhinsku9V/57h7nRZaq4nXOm919T3IChMcOP248FdWHCEGDmgVBRgfLBeHdn3Zg0EzFmbXudgtDqTJsaoTA4hw27spsEEQLJK5mh" ..
	"pP+UYg8RTcVrlo1vX6SC9f6WUJYHI94ciI2KxVi3V4CAU/x/BdMentURJXkbIMSHwazp4rfLUCCXRlGVZFTBCmO40G5jzgLXSU9N" ..
	"5S1RA6izfWxL3gZFeZ25oJz5stSs+3A0LeaoYhneRgCdejlhGSKKmLjFOWCS1QBcGXMc4rGXqUbHzlf+964yK1jjoH9z18BEIfwb" ..
	"XMzO7fXwppPIFVMStl2bkkAsEI+8tcOZheJYM2L3D4RXxOi7rCo/10kv/0KPqB4skr7zXLm18icAnokK1xKcRiMJVdeiLtMJykjw" ..
	"ZNEuqxdYkmquvZD2Vy+BpzZpmoWmDfp3IF0xWC6svTS33o2uGqW960WdZPjTOPOGdoOiGhqj1Mva+8SoNrVlDy5LK7pKEaDjU1p7" ..
	"gT4zUt2qqUrQscunXlf1ZYhxiO8jMpfLoFG8exGNd2ZEz0zFqSVbGBhpsNYzuIXfwDaOqPrEMy/WJBb7V5w5Y3FH8b/J2efC3ZVd" ..
	"s3so8Ojh52ed22ZKM+aSOzPrGAGcxN2G21KHvL2/Yl3Y5hhPG93SprbfFXQAMZ6Xv2qrN3hgJu2h5nov5hZEhnXY1ERNlIOh3njE" ..
	"vpxuJ24ThkYSmF/5zLZX7PRhK4jOk67ECG6fh4VR5tzVy6llsRIK9uTNLexYFJXt9S7vyS2JLWY1pLSToUTKWvr1nf4PQ3xPKP8U" ..
	"gwt7t4vCxm7DzLR4ZxVy7UVLvpXBMkUArZNr1Zx0x/wTpop54IYDSKfIpBbNQyx8J2L4kWmuvDmUbOIWk97KIYVmHIT9f7IQy/Ji" ..
	"ipCMT1wNtDjEgPFsWSxUwsQdqzOwBXuTX5aLaNG8hrhT5ytVvIW3+voRdhnPzKdsWk+WXqhL8uPG+xT9artiEgGdycsuxIov8cwP" ..
	"3Zu10pp5wvEjPKrNcNLIXcqTuskZtPw4TmRsg5YrAhLgIberijiu+rfQtidxhoDDtVXOjFit0s3ZcoIu+E/EYg8vlM++Y28AF3VR" ..
	"+wIISlLO+gMdpEIHD6Xhj98T22L2O0l+Jb5YLSYMmu2lCjZRTvsf23YbbppYZk+a1sJm6+xrDMLhKIpuj3pVFI6rIVHXsYyHcZYC" ..
	"Aqh/4c1jprWQEUT4YTy5SDi7KYfyIGCvuvDVMy2inbWANzHW8RVBOemtH/6/E5s638diQGroleo=" ..
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
