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
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/b7519fbfda6a4cff132c30c325148b5940c742b8/DQFarm_loader.luau")
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
	{ seed = 4215597915, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4215049037, exp = 0, plan = 0, hwid = {} }
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
	"vrGYEqqd2cQRET1lMgKqFQWm1LY0UfGeEH2B3XBuhUGoRLsNh3nMDV8rX85z8M9lZowIyhxd7AYoNIgFqWXrT8BdlUVPwmFNwNL7" ..
	"V9iqF5kboEXNk2U1K9D4zJukhCFKVF6xlIU632SUlOweY7uwEAA9/5hs/N3xkE6e3DG9LbUK1Fe4j+5M7U4aEJbVOr1MVNrRRx8I" ..
	"0cTF4GkWh9Ln+ZRpK5RWnU7XxUBVtYkIp+U0XxLL4ABxnB1HZejyRLf363JLoeXIJmO9/fWsNsLo0cIQ1N6HNbjh+Kfl3rmmqI9e" ..
	"jToSDLGlcJYaSBa3pw1MQ1lwWAPsgriYv6I3IWIcXro+0rb8itWc1vtlUVPAlLCZT2+QakzPqzcOa9EMZYPwXMVl00y9PNGyyFUF" ..
	"gteXtvmwbPyKdnpqj5st6KrnRyZ32fSvlKvJ90Bjzq7NexJT/w2iJKWzXcLlgaGDd/evwsiCPM/Onf+JpKCu2KFLDY8G1Icb+Ke7" ..
	"zRwoLYuR3fYjffo8wS/vLUNGXZZ4RCCIBr936C2EbEOCrKCWV9X5ArHRWPr0zDN1k3KTqUjm4+sEE+0Wv3uQcfETmyK604qKJSe9" ..
	"b6yfLCP27MvdQ/MMXqBwH+IgR4kyXPTGcQoQaxoNygE7/QntO996NrySYu3AOUdgZilKmME/5F/7PUFSqlhQVPGan9cwrGgLXWJy" ..
	"uhALDYz6ZOGnGQJYQM2WKLC+5ioM+trS9b7WNP3Xn5Gim6cC+5VOz1xW4QMEh1W79IJ1xIDd2GljRnJkAxx4Kcfr1jfEFYVweKwD" ..
	"AauXCZTKkKWTdFS9outdtPjyEhey0oWb1c3SojLebLvjCQdbXSYFNlZjs+VGu4m3WQAkIpKAKhLTn2byldd6ZeALdYozdnUStx6G" ..
	"sRNRSZGK45xXFFMZyQyVS268jl12o2AKSDHuL0bDH3zPrPyeACvIUWWOtW2G1VxJyWOW2jfnIkVUHXoXUWSKZBtUW/qmr7vQC60p" ..
	"zFr09WPNXlCajfbzQlETz5ruy1lEIxML8q/qnF9Lk7ecXobAIZjgxNu5ksE+7kMVrgx6TWgYqrNjC/m4XiYYjN4oJgAhmgVoxxs5" ..
	"RjMDEiwar6UmzeqinJtkPV7HJCBIMZi4fPRZlopsf0eoQkTYQHrYZQpKFbjP/iKTqAkW5u4jwxCpVuNEG3y0H7igdOLGNAtoRvMK" ..
	"n81h+MyxqYXxm6t3G/tLknWvTQH6uIZccUNghhX8OqbvfVaDlfc1Z8KwVkovxp3g/6Y+30H5G2js1QJK2wHNh8i/AmrKsJgK8S39" ..
	"MnzXOR8ZLJZ4IuWoCoLsBUSsmorrVs6TwsYMuLCP9tnv5GouGVv/0zjJ2DFt6E2XayByCfIOSKEM32x47xY1e5vGJz7ILGTZ2GsU" ..
	"MrNJ2UL67znOnTl5IRdTt1gTnYPEzKEw5Z7ocCiJI6oAAdULjZK3l3ZUdGfmkIGGLWrRb85LtTCbBQzCiZ1y/NTX1+0GAoZDNU1W" ..
	"Ezaxhe6S1V1AUWaIU1XebiL1H2I4BFs9UenNyJmDDy9Sng75iqX/XQcTvxkkEyZirJLT7cQpXHNPJe7HqpTIVQ+bSt7PEgLjU/Xe" ..
	"vSknpzTmPCfMuFf5XoqSKeUhl9gfXEWghidMfW4WrZsAFe1BAYYY/jOTrI4ydemLcAzqin8pF7+Y0Gkz5yTV0lvCQMN9TcBWrMQs" ..
	"N7qt6KiPuU4NYcrfpeRAgIRSONgkPosDUsiTJ7z98EH9OLr6TRHja8KZ5dvStstDTeGgaM1ARlOmWPirpFyqGqXGo4JhiBzNf5++" ..
	"vKryg33ePyigm05cLMXsaHsMxm8I3xiD3ZHAXouO0h2kuBB9WiPJQO48jSXm/ncn7jb5+0Ls8NuT1sL6MesOgr/PIy/NNGMnlHwF" ..
	"pvmoliU0kFzrmEXtLNifrR4yz+6LqAg6qG9U9rK/QmvUZU9A7KFq5/OWq6vBq5Y3V7HoB1jsPx3Q2LcoCG5jbk5fEjC+KG1B3Qnv" ..
	"oKzla/AglUPJzCTwf7UTKzg0EKOnnQHK9bwveyTXlw5KLqR21XRl9X0Aq0wvuI2VjytcMKQkUBAQeYxO9CGhQwX5okHlhN0B6HD3" ..
	"NIaw9PBPW6ouRIjLy5xMVj/tmClMzq1MLgbZ84PAVONoiKZKxsYF0lWP7s8BB0pzKr1uDl/cOF6urad3xRvG5Xq4Nkybt34iGpcw" ..
	"cYkuqcL+a1dWx2LUOxR7PhOqD4p3TYbDXdz3no9bjt7JNkxWWrQntqjjFntfeYDTzy1h02mg2CVC6u2aukVzzk0ZsOJZG+cila0K" ..
	"bAZgvUwD98MIVyHJz3aD6OcLwwuZgXOTc1y0unPQY3wxCPZzpf9X1cpTwW9qcoHQLaLYip5H9vZyhUnoR5dSrw+dzNGRx9QEbI4t" ..
	"3r5QK2Q+QpHo+KUImK2oT5CIOCvASqc7PNSvVfklKCmyRMe0e8AEleiJC0TozXmjIX0AOWZ/TfxgOwRozr4w/bxZ5EAeOobxd5jV" ..
	"MCmLSWFIrq4aqjG1daHF2ay5YDPGPNw4Z161aG57Pzo872VnKsdB7mX5hj0Gg61aFeHJn9Pxy/aqZV/X29mw6tBZcnMDyPTrzW9t" ..
	"4q1xm4gZPqF/VVL2IGoMbGfNwou2jxCG0yQAmYm4jWg4FTanFqeK7NmWY2PeDuDEjK3uYwJKlKRxBWRvAuawYGyz2PrvbUvFO1zK" ..
	"qcZfc5zwzZoyKqj5rhHXdnNVaE63ZTCYuv0HopQ18QhuNNwPzNns/omiOp3+R8sRjYZoYNOnobO/hPx061BLHiWUgCVn90RkD6ls" ..
	"fFwOHT8D59WhlGFBxvUbOhA4AeCe6gO3ZlnQjftRvmGDSYfYbSa1O/UzGMs9/CKugm5mvVB5kOhPGqNkeojoDBh/wuBp3BRApbMC" ..
	"ScDITqUq6TUE5mgwE1o94iO5uYLeCXVB3LewW/XXEkvyzWLZ+/RZXdaltsraZXfTsD2nncHQn3RPp1uwPqsTSr/EsuCCZhf5kahv" ..
	"uZY7A1P1U86J6Z9OKKgnSXHwOjHXfuvQ+bERXIA4Sc418OJFPn5SeVBxm6YQEjO85FJJPSTpvIAV3lFAD5AJVTdocPf8LwpQA/8A" ..
	"oVTfprHirHl2/Gs6PLcoSyQ34teQvPko651NnqOFhY+c+62ZFV8T89Ltc+wIHElUimexoLqAye9qYscLLu6mcFpWgozTMAKI2EUN" ..
	"uMEUjFga3n/f8SaRqhAafJAefyW0XEh4GiZJN/hBEMsv91ZGHSXrdmtd0yiX1x6G2D0Il25CuMiSLMsavByYVvn+/C9b2WVWaQxR" ..
	"XvXNXBotMNegMJqTwXDxl4+3VebEceFKKy9NV8q+FYHb7a58/pNuYQmKy+WvtdAtFw2/NAXsoAOhLJneIhUn+w6y7IpaejgE2g+H" ..
	"LfdjfWnqVwolVcDRDcWxEDM1d/akwqFtj0PgZYmhcSmEFGVjy0fJFZqXTlQtSbaiqazPRmJ1ziTCDWy1WTggw5Yw+yMyxdU9Orxo" ..
	"nZpyNr1e46TNZ6pmUz8XRJ8x83FLW2yNxKWZsxnxxYyf/L/PFgIvFReZMWcFLY6V2iRS77tLMUN/FCYgFMBytAXMfpKVyEjFauEZ" ..
	"746pMbQpJ+HeIwhz2hfWcRcpQ6yTH9DE0xSiYMQFqlAasmCCg5a4pEa5TFZKkiWzHXmXiMokEBPKO8fXVSD9wFBwTKPAgFyVWvvO" ..
	"FuyfvZ2NgNRJYtoqPL4qmd2Mvcj/Yzr6iHZ3LVwp/QAzTD8sv//bEzviqvYG5T1RJ+qgLhr8+OtA3860C93pI4NtQgw4ZJ+h7UqH" ..
	"htyKTSKPPaGNN6fjGgbJp6gNmo+idadmHyN3xeEfYeaPj3g6WxPdAHArfvXMctRT1ez/HaKNBcsXRQ9LXFJcOrAfQhXS2jdr5G/N" ..
	"aS+EUM7q8z/Gz0QgxWfHTLde+hLp28su9RjorAwdTcx4wRTbmUHbB+dmuy1L/ZaeBAoZTzr7qmdlqSFdx7D9HSPpWJnbacDjIFAH" ..
	"bISJWu5zbJ74HLKqa6ZJzzYi20NlmOOGItjXDoQuX5qOCBv+JirtOzLuh+4aONaTDSl3k9GSwbM/VK1j27JP/5yf6WRQTeUJY6e8" ..
	"9N6YFTzzKfXEemjwc9stlPQNj+dsqrUwctTGIrAgimnuvPSDiHJE1nZE7zEPT49AqZLuraPDvHaqmwsKC98j2SZ7apnaHnsGpe0j" ..
	"Eh3Hf/Uamc9TOG+79NwbCPHv4NGmDcZbyhX8KIvjtxjrKM4oenSesYR1CAYT4P7NVKK5Q7ZgHDm8x2D9NDB7IOlweEBIEjrzjVbZ" ..
	"Sazm7eG6TK2FzUycbpbsJu3RsZ2sdnStg4R2Qg2nnE5YOxj2jU9IzWteDjzR57LC9nn7Ki5Uab7N2dgta8FeQvFsAMhV/WgA8lx1" ..
	"JtI+k6MO3b2EllpvU1httogDpMyL5jMm3zTOi30BEqrZBZBTxBSnCrlL92NokAFAMkVAq90Ccm8j8jVy+LbuuiaHL+y5q4PwKpC3" ..
	"PQMWLPzTyzsPt/+XxEcjqGMDM1m+ZmE07/CaZu42dap50QoMDBW+QcLl7HNhjy+02obC6uZQ/Ep40exCWMw9cfB9XZBjzMqre4mf" ..
	"Q18RI1zuIgWNJY+QIyjjT+OvZLvjqHchG+kmJe8sfmeOx8vFBWr4IpOn92q9mO/B7/VOuk4HNihKjhVZE9MwKNuXowwttz7w3vLh" ..
	"enyl5fedDgugWUq0E/OJJoyoL6gN4seJrEpRKURcCEldNt5D9pfI1+YO82y/UsNkk2zAresaJ1u3UrGy0sR/1/cnphm3C11HLiBx" ..
	"aLoej+tUq8RICmT+nTFIj/G2dp1N3eEz6H8wu0Kyp7jM6XJgiFw5Qxjj9UpA23IQfXz6uAhMsnQUy6kHTV7CJR3TaNi4Lm1PrBou" ..
	"sCKaEXQYsxmShXg6GXNZyryKjcqDy7a3kdcEuAhQ107KlsY63UtiFBiRF7l3nY0eyukakofRSHoE9I+OJzsMH4jY5lnoaYtm0ts0" ..
	"bOUh+4a2LOffbFG9whyg1hcoFTukyVQ59yYiSDNp3iZhzzqr4OmCxFbtLpAEMWTx0k7eiXrR2Hf4C32eZiGBVz1Q7RpMkudvUCCP" ..
	"Glfwwa/vu5QklNbC+YxqwANtJHDVmIbFjYjI1XvLyXbmU2giWWs1Mgt0H9/juU4Z9Kn425G+GPiQXuYffSuaPwrbjrg8QQz1gaJP" ..
	"gl2iinP1gMfSuhhjK9ob/pIzcqhufVCoNSw7LhWccLO5O42zj4uclL9aUuLozHYVSh9+zsK5VVyBoiLnV433D7FfKZkiI+tDSQ53" ..
	"CVOCbgLksvbsJpEq0UhM+qKMe2vhLS638LiC/zTY9NpazCDLIHugPNSed6SrAmVceDqUE9MWbtueimpC+2OTVmGkPZAxv3zFHEVv" ..
	"0CLQ1yDemlvLadUNzBXjIHqK23cMB/k2cZUn0ypRg520wAubOyAkyVyHhfmsf/tvCApFzKxXFa/LtzpAr25nZbrEbDikuecLInmz" ..
	"1q16SWM8qz3h3PHs7SoXs0KZIEklKE6PSz/CFgeqxe6fmxx1DJb9uNQXf6nLefakRomtpwI8qUMEQd1f03P7qvtduBuETl1XfdUV" ..
	"0i+v7fDSYplSmrxr6HnpvgaJrHcHpJE2zGU5QmsyqVa1TwB3cQEQVa6NmsXUpUmGO1jvmwrZwC+0i9iLUF5SdWktmSMwIrfN0QyG" ..
	"iNSosh3OvtccmyPx/MjxThiBkHT6hFI4gtjgdIssmbh77MdwiuTT4ZhKzgauUX1ora+L1L28uK+zj4zwXdNRLGrB5HW0cdJkHDDx" ..
	"8M/HiV0EOSoho5w6Zp6xvu/CkqKPHlkKGHV/dbNXO3hfx7uXYMleCQtTb4HbDvwwoBIcRmKphyeQI4drCkHXL/k/vdeZaXrgwW3s" ..
	"wtUQ7oOOQ5pBqgX2E7vseTHYh0ShjsQlmaBzy9qQSsZYRN/3Cjt13OVackSAXe2mZfLrLjyTOaxkgPxbTSTBOloZieRAehi1GNBQ" ..
	""
local PAYLOAD_P2 =
	"2zgUQfhbhOSdyJno1k53vRY3jci2DdpwFcXSVjLUFWsJOSqKCMnsEUfqdPDYUycKTmvOdQoeBSRhg5O2L7rEmhNhIjlsBXouznu3" ..
	"bevPRCqsdAwB+BL9KgxDWp2S3wjYxlJA5IEvpMOTpgawoSVMK9utU9Tp0QigsYhso0GjMFPdsEBwOAAMUVOrKRNFeZnasJha5YPh" ..
	"pRKhDlwwacQp9x2WdmUcploxDQfcHzBJi+rn2PzSrQYmguWZId8tHM5kX/upq3CCEHz1e8wwHa9mRtvOQXXigeoN6oL77E2bREmr" ..
	"e+tSIDYhSJonI1qnq32LEQupuKq4Oj7r+FNM0WKevDONoroyAVGLyuYQhD+8Lbwij++iHTdCuZ3bXnIBuOYq/rAXKG/JBDGAkPRi" ..
	"7fUOM3pW/LUxNEwizM/Jyu3Nv7kQJjVQY6CaHWcZ6n+wEtzXaBqCkzBwXIntq3HlqGQvJWN/L1Bjb8ZIpqZpr0c7ccOyDeowWlmZ" ..
	"OAtDJP6u0m3QDGWufnEHSFULrQd+q1aVUuefGI7GeM2l5dc0MgGYYcc2xXsPvfYP0WkCvQ5T+aMqAvqKyoeLfB/Va8moEPKpiesa" ..
	"svEsILyTtVA/hFAjsO+XSnt/WLm7jDSRPe6tIWIuDyO4kx36Bl26ope2OPzSNuyil9B++eclP4lgx/Q5BIq1sMgvekpPZon7DBMG" ..
	"5buEi12CuhJ89d7iApfIO/9jGBq6gXkIxtrWniKRRVASokMzGwu1BtA2b5SNopYVFTOKrAh/fzmUFTJ+ot9K1FmjdovCnPjZ5FMc" ..
	"jf/ELMuzBr/5ZkPlhpoYqoxQiiNyKhbKsbYvjDnTO5YoMEnZn+1KU50PeyiQ5RzifvkGT14QA8DU77CcA66bzzr3iLbM3ePWoeU7" ..
	"ANZXci51ymsegEgIqv1pv43v+salZ4W9zqjE4pqfTnmI/2wawvGHVl7ajrOhvAdAX4Zv0HaRpMhs6RiBGazfSSmTLnNgSRO0BNJq" ..
	"9rn1UBxIDxH9Ur5HAZxZziN+IZ2nivr1wsq2XA8Py6cirMq4JbSKhVtMDtXa+JIuxJMBmtqY8ct3IM7vTAPeaiPsavUfyLnjFbyB" ..
	"8mfsEJYOupV+Q+42LhSwvvMSMjomND3VzpwmHmNC7egKMYhg2RzCF5xjVeQk4TmRDNim86VnUgqtXSSOy+fXnR9jZn6UfaRIsD0d" ..
	"+cg7RNMRtHHi8xE3NoLXrrun3O4MzUxbMcFfTW86e59CdlWpyqQY8mGr+gVdpN1PSKPM9xgKHb42NmGczyge4ep23eMXPkor+PqD" ..
	"VHPux5iPRGIbZNfd1+cduuiuT+6Dsbs9Mj3cazGXO/vvhnMXSHbHuEXK29n3GqK1IZwXKh31JMiQA+Ydzrp/npepXGMKnOi2YJO0" ..
	"7K55zX2EpmidJcr8g8HQo0TM+aM2tkQ4obMxNsIc426ZhT/a2XLnJiIjxLtAv1zBRHFtgji1IiPJuQFUaXQ8Xp59bFRk/ttKXLdE" ..
	"qbGfz10w2XKrmX+Fr5c7Pi/nOTEbN31AfANUmY3wlFKuoRBqcqyDKX15nq28VQe98hjcYYxH5Z60GseFggDPMKTcywu4X9sdOf/b" ..
	"MtOP7duGuH7glGimImmQ0XgS7PEcipL1Na2H1dSiImGfxYPXD0oqcbwmDQfGvcxCI/CJSLNqp03xQM9qIHyeXT1ZKXq/f0a7SosC" ..
	"oYru4dAwBLn7iuGb1oEq1MKoiaVMqYZhjInpbexRAA9UuIlz8F5fdBQ0BvqxHnfh1yviJPXqAuv9xaYiHF64OM1fUsWVX8iCpa1u" ..
	"Zv6MlB6+7FJZtgI0xNAifjIoEs1EiC/76AM4SbmsbcYj6jROjH/+hJmnenwJbb4AKuVXMX4dUobZcv5Quxq1SWQQ8Gz8ZH0zS2/9" ..
	"Xi6UJM87bVvCDZj1QHkB3blxYAWaeQ1TzsDuIeixclGb1uzqoJ6dW8MErRV6L9MXMH0xdLJIzQehqKOdTiJ2TbB+VhNW3T6vjiRZ" ..
	"1WK2OtmVI9PcvQTVnlXE/WilmCPlPrwPEa6f3aP8hYGU5nL33Sz4TMom1R28tOtQnwsvIowWbZSVCJ5IDNaDouVau5ZIybHbVlwM" ..
	"5wVIx5UZM+8dpRNiUiL4ww6atFfDHAjOTQm7qKmZ2fazcWft4/KRR8757aGGH9py8xVxa+8twGxZd1RO+t3tubtawDlwuh3lBOef" ..
	"UYlKNL+M9if+Thf3PcqKHbvNXRM94HD8UAFSJ4QjxQ5RQu4XdQ5KV8JhfSzaT8C9TUGClN46diQtqlcdBafDbjygjLXxIpZIvFzd" ..
	"BgdPhrtHyDY0xKvbnfEZdHtY4dNcclSM7OL1B/hqIpGoEY/jEUcr421cFftfTWJhOziaiV1yM8j8pwBtr/LO5OycLkbT250AMS6f" ..
	"zAFnSl5wJOedmGVImF9ETOxrbBHXsZRPkYbaYuQE6k01/7oMWb9gGqv5ov+NpCH1upzWcnqwyhxum8Skv2rtDaqFzj0EvxtZ+cd9" ..
	"t20CUnCSpfVl04BX/nsr1AB+eCMAItB8ebiPKOI1D704B6/XuBL8umQsQCr/JkhwFjRpPsMAjFmQp/g2DfngcCmOuOp96DXvRihJ" ..
	"gM0Jj07mQpmsi6EWEBAco0mvzBYk2lH+89Ji5QrtZD0bqCKTF01wKtMnw1q2pw9MoQ1fN7UqyxzTm69nqE47QAllfvhjK6rO8o3X" ..
	"oe1DrPNrD7sEkW5C+ocvqDKqZeCDFMitjnwA28RKmNDhMmacA7suOq1aO/uU99W9dGbdIQxWVXRpCrcMv1dC1YaYzsosDKxcUzxR" ..
	"SCwUkhZiKriXA5PFrP65aLqn62VPoXPpbFh1haVOLExBOqW5JD0Cf+RCdqV4jY3L1+hXID0fhVhsqZRa6XUonaareoPloe8w08Nc" ..
	"700GErF1cxujCNRYSBIrs0UoIOFCf0dChYoMN0sCNBK73yf41JrHC29ucmRF5bsUtfzFUJ2HF+k+2l2s1zeMnPXBiHkfqVReSfMh" ..
	"5oR1Mee1Wp68Q0+JNrzl+RNmxC+0pxCHpZTd2OlqcF1bCIDI0nk4OLzOQMtqXWxjRs26sFYooS/BGMiBAnJ6IVimZhaJkf0Hg5Ts" ..
	"t1t6rv42lIQzjHTIE3wQN5hfOSYFuDqi/03+MWadRx95gDGrCX6U3r7fut0okkz7lWmyRarunIxTuag0p9Tuj2LwzvrIL41RsjGk" ..
	"P9b8BxLhqJji+spLBQbmyEcvxlhde/XtfZtQBqLBjO32BSYr4sJ7GO+gWnzOggCZIvF99GFjzYN77y6pnhCMLb2ahoIwr7C5hEvL" ..
	"+pHoHQWFvYnrA9vIPndjTxpCnkzJFTQ2Y0xBvv0bB4cl5ggEYKWWkYr6amp6Akjt5ZotTULMJUQ9k//Wjnto/p/RIcAQswrjf/ag" ..
	"THCY2IoPMX3OgGAhTOgQ/aclgVgbZmNVNlQDNFKGeKTnnY6c5CFSJoKCNrTe92A8EuF06Bu5LOq9X5c/8B6w06HlvP4705WCpD7P" ..
	"16M13qtZ9sNgwa2zfnlRcYR9FjyielmmlFGqYS2Ro4QNxz6OVYjvQJh2IhTd7ya2RkidWt0W4go3FhFKoWD6JGz/guSOmRPi1BU+" ..
	"6VZetRe6OE+TLsvC0Hj8Fkcdd9zquyErACXr3o79X93PePw8+QbIRV9xB8zyKsTy4xJu3JBFD5OI5lUROqKkzXNtH3XRvYDxYe2B" ..
	"KXr9mfN0rfsREA1wM68lXA0EYNVabhHLSPfp2O9f2udSDYdVnwzEQ5XmJuJVlxiflzex9dNnQeOaAFwiWdfl5A7FrvgM+pWL4awG" ..
	"o7hcxpuveZDkpwpGRi/htF1Mq41m6a9f0uirCyDmK8za0yU1yOvaLHkXlrG0rdCTIDCvGC1gb+LpioWiE7b1icJCJFGY8A/TezeB" ..
	"gAvS+inTWMxwNu4kJHHM0UAL3nMTX+rdYAKJnEIivlJH4boce9cmH/0SxkXdwBlIvGdAKTBUCPmfknVDnlp+bw2XZdKYbUKwWtmW" ..
	"JwSAZD7mz9/BnerE8FAYxgvhIY0hZ/3bGheBb8npd8bpuLT1SyDdBIUmncdvlmFL1g5YXx8QfrqcUhZNBo1gcnG1u+Rs7vWfh7Rc" ..
	"VVvVi8bs4i8sVocNPiPOP2iYuoZoSuPoXP/xOi8Ztf2fFKDBmY4n0gMipQyZLnfZJoE+N5LpD5NZGYgmuVIPW/vAtTtRFmZdelh6" ..
	"v4BlGLNNh2rwiuNrMZX1nsfLDiHEGY5X8gRDDRHzzE+ZQab7nFZtfc/7+MqozmkoMqRTu0l8Gc2zQqWb564waxo3QiA2qvfhzrMA" ..
	"pA5H4Wzb95NCpMgHtMACkEko8zOIvYm47lX9Vq8aTFaDkh/1nQJwhlbBy30H+F2uCqClY8F4XhdUkz81yEgCYEA8DM2wbbYJqk+T" ..
	"Oc8yjoHKDiHmUNMDNYv/pVOBC4E9+JBCEmrg+lWZx7WOP5QUFdQa1KjSLVrBPJlVnxMy39VlEUx8JiiJIB61kpAdt7ywNvac7///" ..
	"PIgBPfZUQDcbkiWdKZzm6UrlG822+SDO+ubLsfpxSz1i5j7EOhvuNnmIdNO/20XHTm7x/5QiUhPMBMhHTR/9fRrW5Dc+mzGepTbS" ..
	"SANh5d4i3opWN3xJDtq5BSDB37gvc8XYbuBykCndZgqUrYPSwoWDsV7T6mGfvo3K6XwCiD5wluTGg5CyCgrojSSa/3svWEYwUd40" ..
	"XDMRzabdOZ8ZrJ6cLXs6eFR2ZRufNqLvqY7U4JBl3ToBB2tjaSkZ/B/rWhXVZtYz50j01D01Eoq4bD7HyH8iZmkGs51rOUzpOD+5" ..
	"0vUg/cuf4aFV7nY8DJk9t0gLYnp5E4BmJerVglVluhNQ7Y244YtoKaoQxFXjHjyZPCiuddd9XzmL4dAlTLYHTsSzqeuGUofiSrri" ..
	"EpydO24JG2wBN2PWmyiXC0oyz5AwcPQfBo60HWorEuhmqzavGj2SuA4WrBuXc3l+732z/GcpPsCJhIJTCeiQI4Vf/JFghG79F0GI" ..
	"8jcKjilnWDiueFMCZtBQ+VuMTM6uhamOQNhwRHTvPXBOhbFacNbLOzT97VuZpr3Kl57lJA10LsOyu6YCWrS1nX7wZJwrGrekLeEK" ..
	"VE10Mee7nfWg9V1j72rcUUHLMX77ofTTGw8oyzEYwo8hN0qYQ4pLGzAy3GiIHMeQj6m+iI/jbj2CQSNKW9+sG5fp1M/w86ylpthZ" ..
	"iNHcsUjhvZJakVMoKKqqKcTcghhP4tpss9ZiL6PbHCSXSozeEo4JX0G64EaNCA+6tjUox8phTUpEPknj2NEHcs9J1oa0GOQhKVgu" ..
	"IUmSSTwN3P3qH1nTtdLGkvndZw2ZTbJICgJaS2w0R6tphtYzP5fIQmegLF/c5LTsbpbALdskQTX79rtcGEG5xfhctkMrV7JPCWsp" ..
	"2RzYgLk3dmP7EQgcgttkIOaOWzwhy0sm9ZcO1A0p8eRAMOkDi5hzmRrA80dwvHaBqj6wALHbgxPQMN6AVeifhw8ykR+40Ro/TXPb" ..
	"59leKYe+n/Kpjb95/Jm3EROX9EyYKK9EhBrHg+nqTiXYcGL5OGkfzli1hzNhnDhgdjt9/v991EKxwZA192MEalLbF9hI27CPIFOI" ..
	"LILGsr/9f+F4hmdqvegheJLZkjLiySlLoM6jH4HYQhhdVXD9jFe9RP4A9lTdsrokyxj2qigLD8ZDr+hxja7x01Ylad5lyqnbc7oE" ..
	"WklYkDO1nVJ8Mwslg/qVgjWxEH1tB7ZJx+gzUezWY1HEG9ZmrxmHFnBKCBBCUrfhwbH8lFZCc+oC3c1Tk0d0BJDcSLjGdJ2nejW3" ..
	"0chG7YXwxTJgDuH944du7D6u1Il7015vNWj/MjYKmhf5rVJv9PkkaMKUIYqV25j2isOisgH04yZBiN9a8Oe2AVjo/xiYuOoh+zMB" ..
	"jqzgmahDkcsl10SHPGzc9KSVtzP8Rj3x3jauw53Y25JYCBCoabZFP5fznWjr3M82U8OiwQm4Bqt2MNza4jsVQtJkX85nATIkrj/P" ..
	""
local PAYLOAD_P3 =
	"zYcJGyjTmgsCbkc5VOBRLhy17LTwSXZ5UisxY+ZuQaMBPb22z/8UHhdogWxy1dbY3lASwUKQszwm0EBRXRamE2tsp670/O22pTLF" ..
	"XCWlrxRUopNoCWxMbLz6REoIxlocPcWOGBkRvECUkTGv/PtRRJi6XIitottL0l2/1K1jiQVWVv+n3gu8dlttYgzA0jA0BW679Is2" ..
	"jGnm/ApfzzAhLWt/RVbW5JaU5LFN6h9aKBhY3RZLbe5fsZNutDtw4ZzsDD6olQDy/yGoLkhCpreSM854XGyPoehj6h0BOss7WPUZ" ..
	"JwtrKYGzKg09O/WuCWRvMp2H9b1Ky3Z2zTqUG+EEI51E57hPW8f09+lCKrHFlW0UomlaAmpIKMSTqYU8dmAX8d+34cpubxg0Us14" ..
	"lrGrSO4PKlrMDCjvoBIVDcoFajGTJ0TykBJIN8qBD7cz6TRI5i1Smgx89LZfyA5ZS7AJfbbSZXVC5xVMi4N7T9S4PLOpq+DeRAFI" ..
	"nn8zVSf2FJupNoi+1E7D4JQ3dNZ18clN6bqEZ7mSp/Log3ktCUskNOYK4j4azlyuP4nMveAi1njh2OtQnGh3mwjTibauaf0BDvU6" ..
	"QnabGCSXl1nkAALoFNB/ZMqcUbClZUqSvpfTnwdR24cqvzk6zy3pQkGohuq9I1pCEV2glidJtwwJ9gI4MgWXszrdxFJOG7FKW6yP" ..
	"IJ9I/sIyrdSGuRY/CyYcLkjxJCl5FWRc8O3eIoOkapXOOhEN6Pp+gBjSzNxF8zBRSDGqy88JCnMfG4xczMHDBcSIl/+UnANS7gSV" ..
	"2yiRpMdfTW34ksBcZZQNYHgZ+5gJeD1PZ25fFNPAaJRPy/LJ4YNBHuxHlJp4fh7UBZKZmPRInunyl3R3jUGnssuedbR6dpwWdTe1" ..
	"Aaysxl5YKlnxz1lot9o+kpUjaFbljS6DgchzghcIcKgSr1OvrBs0cgelrrqrapNORQPRvJcR+IxyHdivrKVVsrBDqvpokoBT4bpX" ..
	"sZqvt3zkPXw5kcyEierzw3+BiqjsHD4jGCjSaFNQ1Zoye90OUXMsFpWlR3G2tw7/riLF45WD9LQSzHumABrmwWmkf4q9x8oz+XEz" ..
	"eOv09HzHUuWciNjc2/BX1rpcYKG8MbLbf3QOI/dzamwabmtMhHQ65BcyLZfoT6op7Exeaio74p6nN55zYVluqQYafWZfYgU/03h7" ..
	"4UuGYLq4ffaC5HdP6YsarUXKWe+2brw08HmgKyQprogshZr+kQdr9ENKyLPnctkDGEMEeh7g3Se0Igc1vTPwxGHe640p6yO9YFw1" ..
	"v4ThIbT6POlv5xoFJ9hlSsZCkhQZKLql+MKVQj7Z8Rudwi+Woi4HvMOzgOwL+buto7uTlT+mwIJZ/aAXq2jlzx/DEK6Gjcl1J9Tf" ..
	"/FfYB3CNQj2R47NRccfdiyVuC7kBrBrygsCpBCxIQ2ZMVogajcEPlJWncD9Uk+XpXLlCtVjViEVAKxmYV50sWnCnDFK6JY2POhLm" ..
	"GFWlx9Dg+tCQx3wWudxSpz9j/2fIoTHJmow+FJLEbFAfxuBTveFnc/GQU2mzVQXZzySmtBkMuSc1ZxIG9JFu4X1y7xNntE37apfJ" ..
	"7wiOZLS409nCrbQs6cIYRobwDaN78Xo2vK9hM/4lcYQCzXKtunuPnl+oymornRaBT/w/zH2jBYWT32YI6AMfKEsbbA0QFHldTczk" ..
	"lYrIDaaDdZvW/rd52g3g4w43zWLceZVKK68XobUIVBExonzZwqeP2g+oEs9kFfUDGyZZpTQe0h3Tf2iCTX7GjD8V1CNNZ/kgtmaX" ..
	"w8oN+eND98URmr7bhEWQ3rZzt9oKyUQzlRDXkNi279IPfQQmbK/Ss++hxhkJ13eLE2okccgSp1Gnyoizx7ED5BfM812RU7c2m8bt" ..
	"Wp+kESpEwrqEhEveW5mu2s/s+GXTbjJB8wl0+dlE8QawDU2Dt1r6Hvmf7xl2qs1CerX2HP1Xj7FzcSQwmZ3VOtZN+YcLMMuOnFIg" ..
	"SEREkUC8VrLJfnQkgCo55wJ0o+hTtRgNJneFTlsQyxnlbr2Lxza0lEZ13ZEfk5VZe7eu9FN4o83dGrt2ISSq9xdV+iOhFg9RAjQU" ..
	"XoemcxXHyqkyDqrPQRiKVk4oIK3En2/DsQI1pq7SFDCvHVdoncYLzoq4B4d+aVGaIFJDZwZB8JFdl8EmZIDFdZ6tItBOKgsPZAyE" ..
	"JWWaYegFOP4kRi4f01QWksj4Ckx5wTpaeFYoHInrlD8HfKK+CKSAHb+4iHwZqHpjxp3nhIGYzBSLbRoR7GIrGY26NwmWolM6XS3n" ..
	"bhxiENUpit8CgJ+t4nwJcIHHfQKVrxXYNPvwqiXC7jIdpVXzpiq1/kepruzKkeAFQKoinmkHdWnuUkcq4eB1l0kLe4sb33fapamu" ..
	"r1fAl3vsorP7AbRAuu/mKtZa2VigEH7e8l7Bt5rQVmDw8PBEgjbg9OyyaKWWHz8sTEVQ6wx6Ymvqn3bV1x8RFibDEswFU7/sNikU" ..
	"U20btZG6UxAz57NwB4sN+f1Fw0u8sIpGmMzZLGEesDo/DE61UDk+85MgvC8sgzKA6VlIkJ4hPHD+hYtjOuJyh+Z2GAxbfMhRucMu" ..
	"eHx+7CIDmQ3SCMDH3pcUXJx4Ui929njuPouEXQ3by7CBbtqjS6HikoHqZBwjmG3J4/9XzAhseOq9WOw+qJy5Ltc7OU+pFFMa2Ufq" ..
	"LclSaydBEfQ94nD0z5zZTL5r82Dg7owU5B52JBxCyNmF2hYTMS6C4CUxXhA8iaCRnL9v1tRVwTRzYk2V3K+KmK29j+TDGH5ZK4Tc" ..
	"tV532iNMUuLsoRmSuMLfqT7e/Eu1NwZs1SKF+ZSYt5v3Ej6kycJRQ7bZE8RRLru78/ysCs9a1nl7NVAvxmc2WNuQXKRmMzn5a9v2" ..
	"ajBq1XPRe202BC5IalGU6s7TOgAkyvQBQOuMASp1Gi2LZ6WhCiSt06oTlZVqv2+vhR5K7kho25TP9osPFP/bLCIt3FrkwSPhRxu+" ..
	"vPjn1UuFiHojgTJZcvs37EIQYZtiqQyWaBdeM4zWwjplQkBDbs1J2oAJPOOZcbpSLgZAkSMh5g1Kg2kSVmVZLH3FVH/dGU7NU0xm" ..
	"UhetAGl2vgQfPLkyCtjs3KVnDB7nZUZ/xOlxv4vTE6uwEJjvzcdF/iswxJwxYmWyiBS9Ikz45fsMFhDjw0CETRyWQf1tNAcCGlyN" ..
	"zvrlVI3WAV84mfFoEQAR3aEc/LP8zltOe7KbCdiDgDzWW5tkN//V5GTz4eMc4bos/JPKlRsxadi4mUDFtaLx/8qafIfGjdfSokEX" ..
	"ZJ4tVeMIBHOeRJgHyXrSou+N7Hkg8q8XasKPdy3uPffdv6vNBHSWgfI5ri582KPD69IYGo1ko8P4zB8EluIPceaV7WP/LyKteemC" ..
	"kty9BLHOUivLLskjXYSPSGG7nG/cwzGnUvN60Jwfd3qESLI1ip4wduU6n1qCwC4FqM8uTSWPf+hhO4RZx6DJHcZzfFuawRuu34St" ..
	"GyF/drlT7BBckxaloG/uKR6iLib/XQVI0Z+8uL+GNm3t9NSFyUjv85DQMLdRmJMjgaEgBCKgxHez9g/uIuX6/zr5/8NxGJTseGtE" ..
	"0D+pPjfJBQqjZ71FINkCf3ydZEr6LYjInos8Hhtt7RIa/hWT0Xq4c1xVuA5LAfE94SpclVZOmKkL7XDTntRR79NagiQZ1TUXG/pB" ..
	"0z6xyKkDweuJEHxgL/dPKZga0DSgufEVRr8uV/HsEj8amYQO7YkZKx46bHkhD2K2z2Mv5tIMboL4aFTk2zoZXVaOZ8QTyXr3TwjL" ..
	"wDiUz6ZSRJV3Bsh/9p95VcOFoj3qDs4iqfXjpGbamR+oJgrRtFnZXHJ+rRzR949PKKH3E7ex+bx/RvhmXo1HuojQ3lOnyT5d+MhS" ..
	"OEUgHxkiIcYYvd31yVDAjDv4di0lTCfm9sCgMDNI0rFecVW5aYbXhnbbkYg0VMyyRMQgS+WbzhMdzZB8bimshJm5vHIjNfXBhAAf" ..
	"SAlREDsmBk8CJPJ0qwXew5uKkz4RkakwBYWZb1X7oxy0JwqP5haC4QGl3HyF4kaJenBuNiUW0y+p6b5zv45urFEqvKcoHnawsRAR" ..
	"uxzmlfSFW/Kga5dkoUtglGTn2Rv0wlzRM7vPeVYRdqIACkuMH6ubBZ1z/vrdkUj1ROJEKGPqnujQ9tA9cWFir7nqQZn4M+1AJkR7" ..
	"60zU1LtpLp7FlabR64ryZUtJhkA+SZfDJd9vfPo+pFXC8+0NcDh4/BGGyVk4xkEazeqJ5Z8OsGZaRamwutj+ZI8G1ZBR9xggtwJB" ..
	"M8joZ3zO8dNN2dsH12xzsq7Z3+Mnd5S8h5vyl3rXi7Itl6pggfRZl25uPw1l4+zKgdHjZ8yJZAauTD+YZ1BuxtE9EBwmFc98EMfw" ..
	"UfJdRFdXCJnJ1o2u7pr20WjT4agYjzjSeA6TByd+CYGRtX8pJ/e7OKHKmtKH09g2g+qInK3Sc/7N9RKlrIARHYbDDkUXQlC9W59b" ..
	"7uVEjqvytwPkEngpAia3UJ9kigZyLJlXhSAgQlzOecdvGo1NWxcJ2y+vDz6GrzrBEQDlJypSKMWq23VV1yTn2qKEEOLgyN7iyZ2W" ..
	"3msVA87nmpgieSXhPQdVHQnCgaAoa+u9iFeLfl+pVdvyP8OnfZxmOZy9TSyZtxSevTWpPN6kluBExjH+myunnQsdwHBG+9WHANVT" ..
	"nFi52Ebs7f8/eFr+nVChVPkOeiTX22F70c8YMDsDQ1zYf+OtuXNRyH6190fDdbpNhifgUrZqMUzNbKJBWq7MPvHB93M8UUMnwkH5" ..
	"6NV8DGQirmLolaqDIXyI68UYJCd6oSk1/40uXbVCJFFFhFKqYB7u2V9m6YRzQU27QGebuYDXZqBGRIuDG9xS0XNnyuuKse4saiCX" ..
	"+RQpIXLLcmDLpj/6MosuohTf7NbPzmv4jlj5Br3TAJ0xduED4H9MO0Bndlms7LYnrv7eZLXlT4v2Pc9flWoGABN47CgNjwn1y8b9" ..
	"nKtkipPGpk7M+r+ruSD3/Q+CKD+sgRgtviL9xffgK35sMSN6BV8HwgH7v1SfUSbJJ+pshEfuN8cqMq94sKimK0oIToWjCkBmjQeo" ..
	"CPejhd6p21MIxfU+ZK7xzb3vkTpbbzpPVGHicIgJHRqcLmLHyZqbQOgZWmTswi83L+pss7lZSL2T4mz7NV2GENwXlgQ4DqEq4wuX" ..
	"ojtFehuHuECkWcujArLS2rGhamA1hPQrP3BQHB3SIP90gTupHUqrM6NdBR5/cJSDlSK3wCkyoYZkh1c33OVNf+t2vUqPox0Q7d6K" ..
	"N5K5KtAUVdlos8ow5bxnavw7Jn1Imnzh9IFKd2p3596HeNxQEcCiKWGJtTbQ90BeMPxUZZikrFI6UR+6STFCZrrny+psvTNBJZ8S" ..
	"HwumxxPv1yV63EPhb6XN+4+idN9yoTaaXSmAk278MGyoD7ziFkAxthRSYuqjnDxdghFO56MPLmyJsyF8rz1zONx8p40quxB/pLeC" ..
	"KXMFC7E+ugEekR4SqMaVXoo64KA9rpRAv3DVG+o/3jsqqW4Q0YqFzEU8l7omJo/ILGH5pBMXwkuuIRzsWd5nYY3Q0rRERFg5HuaE" ..
	"sOkcA8UlyKoi3yFWeOPTtzvPAbOj12saVSYwO64ewcQzU6tIEV4jf+0L9DP3X66j/4IBqQIzUuX2DlnV9Nx9A2w5YSx7d9oBhGKG" ..
	"v5TCffvm1J1QlGoU3xqQrDD5EBNG+rgV39Ld9qBdqjK+kSQM/CMtOZKJ3WX3STaX8wDD7OvXevR8A2MEU3P2vft8Cjl79ccyGJKn" ..
	"OSt0Mxsc4WDQQb8YIgx6XxyfdpETSrzam6EOGXJN6GaawupgTJ1g57DhlQHBVhunRoXLqKmiO4qgZt6T/T+xKnN+6ipEFh8/NbAM" ..
	"i5Zcx8J9LjsmDGKrbmf81r8jVaOlauN6s9SFpm4ZEFtByNWJVqr52+3iITtpf5LvNM9yE4vJLGd6zEphSrYVtLFq+wFDLhJ/41UD" ..
	""
local PAYLOAD_P4 =
	"YCP4Qtk6dML8+Cf5M9KkpKS3w1NzP5qXLMTKlVJ4r4rJaIcwdK1/CtqMhLAMzxQXutH3JxtK8lGSZ7FXndv1rPHyW39qwYvsy8yT" ..
	"JVrCm2vUV1jTYo4yhvsgSrY9qJ6IoxY4S5mip3u6hbQrUny2M+RbTK+8AUwB8XUrQBcRQac7P2PZRaLCVQ9koXaLExsLDhJRq0zh" ..
	"10UTjngDTqse5JIrnhfDHVDsnOT9GNejE6rFENpKiSGWaOEpcYzl0K1N6KCZfELNsJ+OC7TygxB7oToeNMTwZsl/CCnKg1zPuBDy" ..
	"uQno0gR/SJ2z2DGvAunniXOvTzvS5gC3MhDddawMFH/cUYQOifeKnGiluhTAC3HJkWbVY7J8bfG+W+0sCvdZdhYZFQ/0s4s0r7wW" ..
	"gTxfyny7seMYyVH+ywnV4iiLiF/mPy2secxa8pfuLtsKNjzQqm/sLdGFmN3EqPxkTXiguFS2mjFPB8WqvaDhInOK5QfLncV4wLND" ..
	"8QwO/w4EsmBOwLbAKfRYyoRqp/TEPni+KTyrFObCZZzLFaXXj9LrEgCpP667DR5WN+xEMGx2SWZkH0vAv1Cw2z5wnnW4Hoo4/Q5F" ..
	"2DyR2Mlf2Orcju/8hCsD7s3NXIkrN2vmaOGExA08kVM60PD1mev3/FIZev6vjEIMZX3CZwVRXPP8I8CCAJIg4jTtrYmU3mPDEhwv" ..
	"evadMwxe31qPeklHPNjoDqVnF2jEaJO6XKU7IdGvPafMEGu6Jq4hsNGSyyzD5gT/TtYJj77uRFWYvJuqbeB13I1FveALG0yjNznj" ..
	"67VgVxKf6s/SrE3+xcljyOMjPW+I4RwUBy2d6UphUe1UBuZWXTL0p3woU65YbMPimNrsU1Bnq4V2CjiWVi63v4UgVN2wCDKzzJE+" ..
	"hcJZbl3uyT1sn7JXR1CJnoYzbqxBWkon4nY52hYnk/lWAUkwmQ2hN9170/q/cKgus1dijHU1yrWe/oY4bifgLW6Pv0dlsTahLVBD" ..
	"K1xG3Uz9Hw5BV3fGQn1dxGELLa/j1RSNs96rSbQlAizMZkTHhACxX9bGbkLOmaSFwEx2us32kZe/nBoTbvVIKguL+oxlqL9K4Lnr" ..
	"w+3pDHQkqpHKvTlYcPRZyxW2HXuTUbMv1GN4aFstMchRkHGhvuMtGtARxEeHh54mVINVRyzrFDu/0cFNVr+zuSJSB02H9ffwg5gX" ..
	"GfJLeH6ErqhbMYOa8ZqL1UA0c52EV5eDBmGU0af1S+6egHA5/q/26NGDNlkL+/gWvO65lzMuFmhs0wvcW3TX4dGGBpWKWb+T2hVg" ..
	"nBzroeR+w7bZflgSEC3K4HpnOcZJLoF8pPaC/XGe/Qk/eTkE3EIrhpYurwQa+y0dBBgaxJhysw1IjZ7LJPVjulrxfb9eywX/8jFy" ..
	"ZwD1oLtSHo55E9DPvyTH5IVifsMcXPtHmgkfIm/QTf2D25W6xfUJ3w/ado6vYCWcZa+7bupkgAndlHbVBm40yD7tUb7IXyJjvk4F" ..
	"lssqB/gkBfiR7VM5kTz+2UhigPUJNPL8IbRmB0VR5eOo5bAgplKbhVlhrg8Xrl5NkLbhvdlS4br/HBJaFR37poHhQejLcKBWjF/T" ..
	"6u7piA68wRc9+wAcaidU4H615pG3/MoVN8kGYflZ9vStgJKBmcoFz/LPuvFnPY1Hruads+9GZDR9XlAvG3edtuzrgKFHrJdzoY3A" ..
	"SOFhgNbZynlE1m/ntVEC0eXt1/DGoHmhuaBlvqH0DOgL4Y3rseT/IBQlZ5zNLjd/eH4PcE2AplPXkstpJqQvM3+fHYqiAHqaH9qD" ..
	"dsV0lxuAu+NOnz3tTDT7j/59x1fj0O17/cuZqD6G+yjcCqHugHV4TRhtMejQ4mDgw5VCnL/fsXD3mbhedK5nhypCaMrd7saaljVF" ..
	"6bwuYh3e4E2ETRDmHIIqvIxlngdT1HNbnEJq2BxmLevp0krjPeaWiTdwBK1+tQR/s+npeE7pOiNkITl9sBqxabn+ZWS9RBGxYdnS" ..
	"1dO2v6YCjJBaamFiz0Vn5XGEAyYhO+OgkbUsQG+SElVWLWN/m3tweuFfiN4y4wsjscZT/EqcgJhwzMF4nlXQ86mnUh4YCV3i1Ha0" ..
	"Xj5klSAF7uYKl64HaggJP8U+52V4eEhXb8cD7svcv/HwKe/Mv82bv3IdD0AaOT4qYuQpgmgZ+mK2EzUAcjiAd3eUVzJaOX7TKy+6" ..
	"PxtGhpysmI/lx/HPgZzaHvSb9dYu9nzBjl+X1DdMKavZMpNvG4Xgn31/bejbI6gAZmqqgrRBRkjRcKr9Wa5wchVnFi3d1jJuW4Qs" ..
	"dPJaxOoQ+cCBtNW/Jv0bkFgqMmx6AB/yLWXkHCJGx37rAsfDZbodgLPHMh7eNXHfU04ud6H3R3hZR9axmaNh7tVzcqDZ0z7E+xk+" ..
	"dNAndmQLSQuSsy9j71s7h4Bkgm/Djt8hSfiwnJvsejzhkdF+I1CY+6/Ox0NWKGYR0wha/knfUGS2lGLFbZTuyp4Uovuh/vlKbP74" ..
	"ljRug3AT3chEKi4+4GRMkJ4k3RrWMwZWrSDyBUtGZE+r2gOHUIdcVp9kafnvL2rBBnIj7NsC+osG0/XthmnoehzEf60RHeekhgv0" ..
	"BdU8qHfAapyhO5OStCpH40xaTlzEvQE4cDmqlPWe6jLwETloW2YO1cgN6pmjGBn4glfF9oJn2jPe32mRnQjkst54ZswWZwP7tT+h" ..
	"ghL1nJh2zzy4VDOVZylE34aeoCM9gdWNuj7U2zMMxa0byy+gPJueG3yA2O7f30w8mZye0quWZ/GGvwfrHqLLSOGd6qklsDcAt8lS" ..
	"1UPr5HXdPqgyrQFNzh9wu1BCSRStyG8I9vMPm7JdLRC0Sa0ctEbQF/SmE35PLRsApnCxGbgJVCbd746cXH6x7n4zlTMB7GNvgr1i" ..
	"X8Oxqqxefchot6SVIpz4xwHkaik7HGtBWXvt+NXMvrMHLn2R1tk+LUXoRc6SzNdPJppWmeeU3yJSol8g+jM9MU+dPpdgyQFNi/JH" ..
	"pSamyzzn47OsM71FVXkKbRkX7HpLYboOyy06Iyyk97HWWGrabq8T9ogkwzjPdn/GjlME+MGIB3uMtLsuYqcQZZLBwpuGfrNhGyIA" ..
	"pXNGI9BnLXVydC4CKCzNmoPXzi17hCop7yNTEJD+6B9BC5BeM4PG7s6bxmgluqIyKNACmTMWgwbKNMKLPjDmG8xClSnVNkUUYJiy" ..
	"MTbdwbAyrXbqwsl2p5sTEbB2nlKTXuYfeJb7GzaqVFYG4swtSlfq8LEvbUvBITzpv7VfSp32vTlTnEpQNCDKZLyM+Y/kpHKXVBiK" ..
	"0saKyGaFQDVNlGJ8yak1fvPyrwHKp8rDpLwb31rG+vYMZOB8vmG6/GOn6AWsUdMpu3Q4+BxXYD7ck92zfcMQYg5+05q5g2oSioD6" ..
	"7AmqU4lkvY9slUYCPYAUvkTBTpk3uz//OuS9TSANqmHKXOtzTn1DxwOI6/dhq9n3rdgxeDKwSIkMv/d8apdDXZooTQKRQDq/boZV" ..
	"RP6Xe+KI69OvuXAjAwNqcox19lq5E182FXAXcgNsWE8++qIXArwYeZHNrnlBiGeZKMaReWhwiwxfuSWuyOqw906ckxLmOxPBa3aR" ..
	"Iv1X+8mHbXQ/G1WnIrQVImhv/RThP3QEACnhjt8lof/dOrG5lMo4McC/fxgAcBGX59aEzjAH7rKsJDnN49o+OPa3LHqTmlHKe2V+" ..
	"NUq9RzG08Ft/4uHsOl9teZqM5O6AYhnGLnyj1Pv8Bz44z6CYLQG4AHmMVUKvi5snMiXtkZUpae6/KxAHTFkdtTp3KtiMkpcSA07G" ..
	"GdK3r9UbfglRNVJpn6DAy0TmjxE3oyncb15IkaEnXJbAegMKlhz+aO+HwCQtot4fQV/nfJ20fAVGgrRsB8TwCZxrwCJUCM17lYBu" ..
	"GmQXipKIaZEEtZIGkqNfDmYoIHj1dsl4NVUEJrrtuINbFhjbKJ9XBqQxvvsOz/vCtMxEkocf9LQIRBrmivNrmqcrTZKZ/2PqDeWi" ..
	"nijEO68/pXWcODHP9emcTG3pnS3NiNCFC1PyCXxnEZOUF1HoYmwfRi3ftW5XA3TMwhLwMU5CCmJgd9hpxBuR7EMIovENhiO/ICGR" ..
	"ET8va3B3+VAklGfnca0XCOyMbMYXDjE7/uNguvYxJZx/bUigVhh0C3dNuadnk650Yqnu48bnYwc5KWwEV+ckzgiS/MqGOHNp/FoQ" ..
	"1K2snWbrpk3m/UUSGEfQdQAEpDoLBQC7UUCSv4LonT6wWOIrRTZDhdlUIuwwtX4LV1BVUZQBBMd5+ZBUMxSa41Bzpg+yj3RpGsK6" ..
	"LsIwRM4Xemlg2WCX81WwDrYfFFXCoTQtlryKIoZ7fHBjBlLdQW5lAVxTAubV3S6Nnm9HLKgaEAseCXhmqJVR61XV5+6/Ec+wJ7Jw" ..
	"oV2NuEcmyNA+gf9GW2Bons1Wm+MnzPK2YXYOjfOZM5u0HCcOHdOOWfPfjDtqa/EafePaiewmhATtXR92iOW4Z2LgwMVLkt+XZC0o" ..
	"ON7iLDB2ko71tgbn5Gr0/YpgV/aMlvd2J53dYU5olMiFpTb34s8GiDdq31lAOB/7X3+kUabZ7/V2/7fY4MSCikeogaqhHAVHT+u0" ..
	"N8E9R0vJ0CPJSNhlCuff8vmAVMDWX6elzf1Y8n/2LuzCehJIVTxo/9sKiX0SP2Mk3jYMYTLppnvlL0RY7VZEzsdyhINqBeksZrwB" ..
	"OkJGd2xJ3lhLyK/VBriJLuWum0N5PgmdoHLynuFULwavU81xeLaQd8DQh0htxFBMQrnnXx+dyV82pMyQf1g64/g6SlRRXhGuyyoO" ..
	"6KlFzt3yz7HcoVIBR0Jw7go+G0n7Rhkvt2kx/1d87cJ0wl00AysdjLYxaJiOLaVRvBFC5Zx0tVt4KSCYL6dRcBLHoonPtaWQtpgw" ..
	"IrWqy9yjBkZgKpzBIGmirxKrK+s0LEnYDHL8212KLA/sJlUymL5KVE/5WLrNPpd9SQ480Af+E/jLxkmzEqs4n+ZX5CCf3AXcmUqZ" ..
	"Q2Os/Lum2Fx0a5cBrziNU3p/OeTxWOTiKjjGJD0HiKwWdHlZutCpNyGsJRI5f10QigKzULUqllT+nQ6c4SXH2Hk12/rRsckpsmVx" ..
	"EGwegL0EbVsZWkRDZBeeNbcA4Oy3RBqPO/Fj7K1elLx5HQsrX7EkCIGauLoJcLvFOMAayBndqCh35uIFnNDGVHpGvxa9ovhXsSLs" ..
	"5UEP0Bh20V1aaAmCZe6HRzGXUrWbq67ZOW7Cj2s2BhdepltXhbDQvfzmH2Sdi1kK6kF4PJI45EI4giakkn9XdbSFCT9MErc8T/1X" ..
	"VyoMCTt9PQMswtiozY/DSZra51TCsUl/f836gxlmTQ4V6/RXh79YFPgUdIoPKQFRbJiXYJgrd5MfULOnUMqbpu/SLVPvixwYPggW" ..
	"bXW2H7jG+Q2sOOO0GqkXVz+OfvkwrC/SBA8pz0uCceYC2NjpAlZwirzerjTdDBeyRftB/yTVx16rHdQDa6b0ZpO0AuHgNITpqAby" ..
	"k+2NBuDnIr8cY18W6P4Wd6eBK0APQ1k9+DDZMm4aNflsgvOSvrDVyidv7OEVWw/5iALvFxTUVFoL6GmKUVSiR0O+F/qgifr3RwCz" ..
	"t9iWLkCRT25WPzGp1X50Ssabgyqds9koBPwaLyS9AGjROrw5DNUsZW8D11ywjn9VgD3+lzVt3NWIuuROqQjK6c/l6p8IuoOTp1sW" ..
	"LMOU52uxFEGus4QSWdNEq+FN5j9KBwwvxXEsy/WzOtvEyJssaj/RjDKH1WQBl3QnbXHx7I6X/K2J0fX8TsRP6/k5TIGL/ykmN5jU" ..
	"cZkybTUK4qZgTURqgDhV05+kjVY7SVcwUDD5JotxxxkB8Fma7JwQF5OHkF6YhoWbe5ryvJVDIt4k7mVrnl83WtghhqSrcdnjOdMG" ..
	"toHytN87jnb7Occuooa1e5oAvuUZXUmQOjbb17O+hoUGdIqDuVQKWojQk41kWjpnmCPHe8fgHl9w1kwg8s6hMRdKdjP4GUcri6ix" ..
	""
local PAYLOAD_P5 =
	"xvqnmB/lsFUiihtsIL7eXuFT+hfXJ1+J5TTPd7VBPrXBMUJQz+ci84Od7csg1U8Q5W82Jc/3vcUcFzFvWxR6jfejw2CXgJRJh/cS" ..
	"wtk2FIoYsmpwKlohenmtetK8gKDeYdq/HotI5vsrLaA/Zi55kg7oSKsPRVGk7fmjrL/iaAkAR0imXGbB/pQVHVLZ3d+9nctFDEgB" ..
	"GIrgwxlsWMD/EHv7Wcx+TG4qnIktZMNa1/SvNW3Y5bWRRS/OKJSUfQn1SSwPiTpHRiEPnbdrcOjXzd4BJdv/uKFTlKnwsT09dUUg" ..
	"+oNM6cDpJc26BNYpKAUIpdZ6E50yDZWhDCTigBOV5V+V/ZOLv/U06UgSCVNSkS8Zf8D2RXakA3o3+09RISA5LwZ8/kuaIW1UJqOC" ..
	"Ijcam5WE7waLMT3beUUf7Xh4O9BwtemNw09tK6hZbzo5Zg+vHSHsdTQNuiDbp5EMVd/XlF4lxRjnPSc79ArGlKBamz5icdNibkR4" ..
	"zIF46GVXwQwte1cUc8jzewaaqYvANByEwjtDG6qMBAqjHH8AoJQhvd/WNInaemAZLd84f1VC2Fv1S7vmNANV8m7Ir9jXqhMJEvWl" ..
	"6I7MI7OH3Lo4hWUbH6tEdoPVLmJf+bzoZv+JuaMPAhUXms4VOyIe4d6SPLJFa7qHWixRAxHuGAAYKVr0GmpZEJRtYfSmv1arMGeY" ..
	"s02/NxuCQGTLXGRE5fPckn/zwq3my90Oq/fEf/+oboRdHfegnmbG8R0LZOlcO8mgN+Jx8cifHPJjEMrpPe36iJbw0Z4yeYNXBw60" ..
	"AwKXnleLadl1ZwwNgfuYrjScNw++TyasbEq2+juClyxK9VHHE/0zHSFIx8ouM0ejYP0RO5VI19BtDU4jhK3thP6I7+zW2udDnNfc" ..
	"M7Wn9zAJzkDWEax0idOT5+38GDrj7G1rwAWrWPQfIItUPDUQaVLYFtxRidQv2lXhVC5JhEAL9X3dlIzaotm4euIlKQpNTSPIy9pS" ..
	"vtTK15OXSQ3Gm8lPUNGC19IIDo9soy13sZ6IOBaHdjgWE7oam2SFQvznc9n4kusJDleAG1TrUisf0ZqtIXc+ONlkG1ikR37Go2Ns" ..
	"U1e9MY4e2b1mjZGWfUg1qRL6wResZ3SujOD1K0UYoP8kttdyUQHFQWuD64mgcsjXpChQXaUUURQS5CqHeRkcfLSRQPkcPRja+o5v" ..
	"WlTymRMBWcowuuP62Ru5VbUouorNYmvujgOSuHW3E9fYMybYiNAu4pzv4G3zDKnHnNRVoHL1j2vfChoNRKDGguW4BMx5hWuz+7yL" ..
	"nOcEa1G85TqWZ95uAQtpMcXBQzcXuR8C+tbioI8r/KsfeWHGQFM+nmy/KB69UuVG43Mz9AcLF1PNyMmWuQHYRcOsVDDoi4y7yFeW" ..
	"wkZhYulhqTi8q+PDFcO6uM5NVE79nGTVtiyejvtvAbt7LCC69HJXxFShlpthuQLjmvh+EOCnHknwAE02kEmjkDp/I5UufxcCIvUO" ..
	"TV/N4O8pmR/OzRnb2kT5jDCnXdxsOjqrbKWtlL+WR3deNXSNQi2VSeLzx3kxgJfyZ9fDxUNjWCd2p84rRp3+NMZh9HymHkKNSUTW" ..
	"A7LcNkx3jznyEXDQNZNbJSc8g4Cv2AxQQkqvTQel0lu3tmKYJEZtyuZ90GaJyPsGh4XIIzk3q+guN8ZlylUmiQ9Bs8ZmafdZJ4ZM" ..
	"NJ3yM4L3IPZ45NYmTBl3htZ43Uxshh8Kwf5ZpRU2VWl2cKZPuQb9HcflNrxRK7y5U6K0/Xou/eN9Lv0+kcA83jPQzR2PkRY432cb" ..
	"O5g+s5ndLCyxyiBxqWTVonE7jdu4X9U8/SqDYJggjmBFT2a21fj/btvuCxgkfxGJoK9nVf11dDQYsthiq9zFj8CfXBp5LfJSAh9d" ..
	"22P9PO7Hw8YNdBfxSdoumkEToC602NZrJkxQYpsOngdTCI1axWcAjwVvezDD1+yhOUvxILpyBfcC/k3D8hvOC3xGo06Pc2j94lso" ..
	"YGyx3F8/+XYKGYMpDrg8/XO8TNRIkgc47Cb70gyzDe66KQcaydQZyB2tf9cEsMxVnCAoJbPnb4ihpDt2nRIJafh7is4IwNLjEng4" ..
	"0kF/9K3sGnMgMggxxCWR25a9JarPeL1YQXVUJW0RBUoDpoGLhKbaGN2DHiJAeazCkmryzef490zkmdl483a8o2hGl5e7drG1BcnR" ..
	"d40gZJsaPyXEkwOtHsgGmoYzdRK3oWsHUfOZ5PjynJYIrobCSgJklXmwvnSux+6ahRp10MC95x2yO7maulrCNm3IEaEYDJPX/aPM" ..
	"NDTOhlK4+XUz5tFIMXeMJb9j+KUOB0GJ8GaPgzZJGRf7DGqi8XmlGgsUv1J82CZDinTGm5GQHGkBPFbX1DKpygttFWhjdBrvXEmT" ..
	"VsRty3+oyK+HMaYKHButG6TMmKllwxQsDb/3LwMDuRs2jZsU45JglPnbuQ+nc8O9r/LeWDubZPwfxHdTqTwMV1u3STsydoe7OPhM" ..
	"jlEGTd3gjTexwW4LMO6H2W7d5uRtcTiXKNJvDTyiyIU0lUFhS+1fORhEoeHCooUYslKvf0BmFQYflwQQJz+SNxlaViExUCicY3tb" ..
	"xfZEruOuKwA6xlMASEawBTZFps/TliLJVfcFFaWkhae0z2tuGFAZiZUMTvWSYxWgK58JWD5NwRSmAeS+ZKKywvtRLwBIQtC6fFaR" ..
	"yrPS1PrCyNdGKOiUNSC2gYyksUwr8u+r1zyTlPgMUnjmIdHE/qntapXa0/6Or0XaCKcYPLwzT43gbI2qSBXIoFyQEunJFwUrwo2W" ..
	"cwLPugaiUNOO6K72GyGKQVMpKhtCUxZZMV/uuoNNUBwrKoVRgxlmMKxumOg9gY51NIwrNcon8P3YeaGPoc+B+pjYsPZ9irRG8bC7" ..
	"/8/kLd6UzcceyvcXLNryuk3A3poyF5yBICVuLq0WKpxt0dnc3JW8L9vaa8Xt25W0kkFfFH7hL6RboHtuY5CEZ/QpVbfFul0iz6UH" ..
	"pounlZNVqBkIgTXFPKQyxWIFlm9vaPTWijH7wXEL8Dq5On0WWKkQszdeuxry4hRU4CMTEYl/RbBSCz6yekf7UmYj4rnXk3tXNItS" ..
	"U+NQIXkVjTeZ/L7ZT7gi71/SzvwT71cNEuB2wuv4BLysGNJ3KoiKhwUbweo9tIi1H3k8l5fuYUraBNCkZLd1Eaw5z/W5+qMABcSE" ..
	"9tOrMVJboJeXKa+DTKHE2FE+u0391YA/XqiIWgzPqAakU38KODIpYFCyPd1LPWnHjnAZmE7wo7pcqvi9kxTwsFTCnOXojOWHq+Ls" ..
	"9WZ70e/GghYf1NDwuYDzQBfxQnXD2NbPzmwGRK6NcLoYFEfY6FHS0agUoE916Cu6+jU2ZhRzdd0/F6paBHuYXiQz1xZEJA5c/iy+" ..
	"QwG6X/Klgg0M0Kpyu+JwPy0K7sfBKsSczMawjEnaDfDj5KzF/UU0RtG7FczySG7P9FHgfh4rpS9ug3ehAVZAyhqB1YkX8wgTOzkj" ..
	"nYXaKGFMRO9BpEMIjEFQQFovTPHfQvBTtfoZ74uW0mUrrVG4Yor0FctFiazCVIOMcq1H1wdfVbT0TWEUvRK1jIdp7dkNMcVW5MMN" ..
	"Vlws8jEGh1rSqpwM9FZs8HQ0S65CHryaDtOx0FfjfkxsQnmTo7e3W9kIu5plg6QEvBvdYmQ9HOxKGmxyHO8xK5jXUKeBBmFOM5bA" ..
	"+1SlJJMWRO9ynSVHLaeZJSRKz1yyjbdP7zo1Vo4Rwr5w5XguWDmgaYW5VTShPZpmFl8WB0Hj3CVWXhZVDuxrqBSanmF4PZJOf14x" ..
	"I+8dhXs2qH/d9m0phMcIP5HRxOvX77Lcv4u9JPkdV/SmmDxtQek2I9dHTtjIo01lQi7qZHVeLk+AcB7HEsv46gkqHtLVw+OTgNie" ..
	"Uh1G9cCPshvC6O+cTz6u4phJmuURWC+fZgbumewWbtZWs8069y6qWTylCD3HS0t/tnD8RRJ8cwVp2I1fzCdarvffStmBQkUJo0Ya" ..
	"tFnpHJBurZyvmO21tl6+fetJ/EHIhB0z0OzvoCcZXYbLfYvZyHhK1u+XU0uDCDxQRF3MpJmz1hA1KgRfnNbE4EhVU6i8wsotepfy" ..
	"5Cm/2dYJ7+mrdYIKInbMGnBMNoSTcJMrlriaBuWWIJzOs5dJXsy7UOZ+19KKymSmYXK1OsCPnlqvKrnXnTZkHmyvWWZYTSa2jksk" ..
	"RkLZrTFlDgbwfSUd1AIVDk4n52bY9peJzepL7DvZqw5OruAlMKlzF8g//Ai3ycsqWo2gkeCHRQpp9yJcTMVbMDAQSp0U2nGdiwNV" ..
	"eU1VNISj5S/sZAj0+a2n2k0wn8nc+59zjpCuklGwbLPCclQIRZyir64JELdfdpDgatP7KMTceVNzH3e9zd5l0SGEh3l0f6JLL7hp" ..
	"Nyzw6ur5fzQAkXXwsHlPQbxU07b3noeYTL5VrkyMU6f8JQ8/+psIocWjM3DAoPgGIJg5cgdxr54OkhVROjPxJnUCRLeT4ulFDJJI" ..
	"jATBwNWM81BXfGkqB5NYQSIL7E6C5ft9NiceJlRwmbDzHc2BAeSxRBV4ZUZobbC+sJC3r+Ivjpd6iCOaAbt8OjR+ji28pHxIhczX" ..
	"Y9pw21wM1m8IUMsmyfgCVEHia5BJNWrSUYFbEpuYym+kp5cbqsBY064JNhTppxY8Mwyg8Yc00BHaTmdPXeblKk123NEx97Y95UVT" ..
	"6gHDSL/TJvWJ9EYR8p9cufpo7gqsqP3wlqzOyPiN+hoKm/ZzFcbSDQ58jD81+CyDmucBS0XZaqldMPZFQKnVKjfG8sdy8JUHA6J9" ..
	"Zd4psLRelQxl26UqYseGT5TL5DgVzFxg2f7KYOQCNtERn+xPjRXL3NqjUuLXpP3ZExBpSFhumOUOuHHOO6yFLAgPjTfkk1WJwXVP" ..
	"RW6gB91iOFcV086zOtf2pGQRW7BxwKW7OCs3KbIlLNjz/BRG8srERDIkCxlP2HP83lS2Qma4+hCuCJGXqzWu4v85v1NjSwd3BcAo" ..
	"xs48dyDee1VN0leuDoxs2BwvtLaTkpXmtRufci3Qssj0kS3C1HAjgEVqtJ0S78LjQ2K/JYp7UI2tVqkIukh559hO76J1KpuAZBsg" ..
	"NHuyEY633zwWbqK8oVF645kixo4E/owVsD2mWZ5+fC2JyE2V8S0hA/zJvzwUrzn12mhh3k5IWWqCyur20dPSRmb4/Kl/N6W/SgKm" ..
	"4fXz9YcURVa4Tj1d0dwW8bWqkTzGUZZnE9AD4SQXpPS6I3oguOXC25xEwzBbLL0axQ+iUObT6tUef+HzfUW5tmL9F/4+FH1lQO/p" ..
	"PvaKQQsCXDLTb2Z2VzsdrygjYSHNPpr8+eR1fhSlDK1rFdx8d+/csrBbLGkptfR/xaV1btygusN+5oPWNcBWUNX7aZ2BzZNvz1tr" ..
	"RFysqGCPOoAgxFQHJ6MHMD9gFijUuj24AkEVge8HV/qfmCXU6JtRkL0vhn7xCovCrErFP7ervxcYYCMjIWMx02ihqhzPHl4N9l/v" ..
	"C7Bvx/xXm89vrX6zobRzGU/qxbZbs003vUTX8IC5t4kmkCLcfgcjjqlSla3OgYk6RnNItpwMkXJpGZnYQN2pPbe0JJeCYojITJqX" ..
	"R64leeu+gDdjVPD4RR+F5Ri1zRIBF5ewMpaVKXVn/VEnPJif1ZXQqI8OY7HT4hzA1S5ppapWTUYqiuObQ20xTniaI843atRjO41M" ..
	"MkQv0/AF+ioRqmH1UM47nObB1kGHW3OOBlbEesmuiKIrMflHNSufHu806S3k9UlLIlJgTUpsLXnnLxrYVK6FpfvLJBS6hgTymglF" ..
	"FKtOYXaGeOriV/SPlu5btq9gDK9iBLIQRrVQIsOaBKZYr85A6LWKMf2DzvpDsMiCaYAVvj/D14RfSBOwi3Ly3fhuAvGdKu7s5wZz" ..
	"Ao5uV2bX/l45HAM52QhWeTrD6QsP+iZ1LzPH6p/Z55Ur8g84U2bBLtso9H/AwXcfpnF3PVguIY1e0lJWD0slfJ2nmUk8AT6ewMyb" ..
	""
local PAYLOAD_P6 =
	"ZfgHFpdmrueNFipdOPUa9dJRQBhBQnwJ22+F4msgKFAvOEuN1ljuQdEH/ahmE6Z7s16E4GRAcxVJJ7S1OT93smonOgIUUqfWUc2b" ..
	"niXgSEZv2GjAS4SlZVmJFGlZwlwIqrPQEXhVm5gIUWqacVlhr3xFT1Uj0ewWWkO8SZkhCicPxjRyfuVNmqvvi9m73Hf2pF/cksjc" ..
	"Skb2J/Th09uKvyLfO10YfqNH376c3IX/nCt1sbTOGr8u9LGZutt7uyHy7N09vlqYeU0N75DrgBerM+nvzG/swvIWcgrQ5BNND7aZ" ..
	"ujsRew/UsegfeFNP8rCzAK8XLqPee+hKvTHzFXgoCJ6Qrj1hYJLAVJlQZ2CXQfOAp8XZ2/5sJ686HRm+8sEgjzpuavSxnwno/W1y" ..
	"j91zn0TwfHkyJf3bMrJn0v3tLjTMcCuQuxNJs2ALRPJA+eOjK7WUS7YpqFbVxzKHK/5vqwK1HCYkB5I1BZDsU7KJkCRqhvrtGm9U" ..
	"wcJ2e+EsY/91VUqjEmxV9s9FAcVaf/WFiR9hgBnMnQ3yJKngr69Muk8dNhwFZ60MjVPMvLklxs/1gPp/MbFPdlpnq7Ze+M5lPkSB" ..
	"aDdLvIiix+OOwVc2Q8xRYRn0e+Hq+1GS62W6S83G/vRuOgDUc3U1AQ3gZJG85GKg7eQEevALfeorcZjLYYlb3kuR3SglPF4M1HhN" ..
	"cmT0Z34ymESrvktM9w4FlOeXOsp46Oc9tZZQb2FO/V4LxoU1y2hK9lAet/p/ky2jl68mDnav2EahLuV5o0HnutuxOR4eQGI3FL0K" ..
	"vUHnVWTRKPoOBY/v4la8qVY3425DZ9jc0HPIGGzz26AvvX/kjqWXA9na5rLufyeywOOYvteCIrh57vvSFMotFSxuYgz58fP6/MAu" ..
	"PCMd92ZYI071JKuVUe0SEAoq3/0wyhlHC+i14V47Wi3lTT/PDkdZ9U7QV3P5X1SaFJzbklzFaqPiiwdWD9RJm524PQd3HhZaLkP/" ..
	"ufEcjQjqXi6Prwr4OJUhc50vvZS6KgegY3YMYDVfcH7ytzDKSqdYJjW/MtyKBb3Nb22P221RzjEp2rCtFkslQk2tytpZ7NTvEENB" ..
	"4daAfgU61ZgKLXgn2P3rhnVYj2paIad2mXQQUuDCvcOHB0twvPn82/SDYbHmkh1lW36KQBBvt6pGrNHiqXdAcxYmgMruELlPAGhs" ..
	"MzqxRadcaj5HtF6vIPw8fCHYkFQlLQ0DHs/ldTGNFTyCXSUCRed9ItGEw0wl7uta9+nMHc025TMxU8Aat55E/9GktpVHDPSd3Hfv" ..
	"cxXDxUfVFy9Q+n/ltM8Q6VlFnsTJhNCjSerKpes6R74qb8809G0SFvlnjPklWyEiDyEHdxPUwm7XTE+pJhAlDt8C8QbvKom6HXd7" ..
	"2FPNxuvy5LKP7Ls0ytKBYPxQo7V9z/9WRDW5WcZUoQeWjEklwHDHkZlDOe/uBJQkXgeIM8ay7X3VaonxIVydBlIu3WmTPPRO4dVp" ..
	"i9tBRafo33NjCiHwmae+luUiq1tsUyRWY5VXriAa71dd+S9/fiD8ObcBFKeReR3nCMtGCFl3eiPAO1dE8twTO78xkf3oUnlpc3r5" ..
	"zKCjw7O8vkP2neJ1i/MqmvGAPd5yr19t9svbTfp93eLpNiIt55rktsQOHvdyY8hKCpRAEa0a28b9Vb0d3lIeHN7IIsJcYZC67QFM" ..
	"eYVenmSbWTGDIEIBzccge1+w7hpaWlxxLP1EHmLeeO5jRRJX+28/PHNihFhfTXFQpY58R8YttUqZiArr+PDjBzoCHlSNXwYrH4Fa" ..
	"KZgjzmaAJ9yLtRJI4STs6STb8B2/21Zy6cYYmXtGHXi/S1EGetT+6NnYz1itS5AEIzL9wGrX3po5N7L2sRlf661c5wxCZXcExEOY" ..
	"NdPbBqSx5IwU2Um94Z1nJgL/xnHw4jvco3ZEo/96CCRS3y55etHnNwU6x3fhThSAXWtJEd54zouSd0XKUbtWLsitq8EliIvZQuww" ..
	"vP/xhe+bK16zIdKkSHlVCnWeV1jpk/9syRqLG3y75CR0i+MSkTEcDNBaWUfQTX3ekzbYJLgflYkglT+EjsJgT6BXGoCkQlvumhrr" ..
	"recJB9ydWRTlyATMtUEeOAWpZ1EOHOCD+fiTOUEVohOYBooUrefNYh+RpwVwaarcPljutqj74xrc/HvrhViT/daiz0Tm0eFywkAL" ..
	"2rW4xWWjrkAuYhZ5YiwzoVXlB6mt3OC8YrZlatjVBu1cO71fpMYQ3OPsbXsNHRJvK3ElaYtconiDpRS4NUhUZ6/oYrkA/5S90BA6" ..
	"1sSX1M6Mg6HSvZwjMBUGQMDm4Z4P9/BU9/HxWXTd8/cuWrzy95545j44djGI8nyteqqtEefMSluHiP41Ms7clB0uAkFgD76wp7BT" ..
	"lhJDoAkmaq4nuVtB9GSxrsEz8k6j3rOCHtt4M3yOnBecUu8UKsupXjEU6RZwXnrRa5UQdaRKghSZOAhpLq6rgu16kP3PAW3R/Q15" ..
	"kbiwY04QK5gyDecNyyToOa+O4GpNk5aimiqhh2dfjXjAtiqIcKpHuGstpTM0p9ImeCVq9h9BIEUlLdbjKXQeHp02w4SDXxIz4SKq" ..
	"eMf7CTzw1jIzbfP2G/yaAG+Ub9Q45Et8IcHKBuqe3i3ecYpa8lVM6VxYWQ7DLYBFEpukWwk3mYGj43fKWYZln2qlVxIf66b3iKuw" ..
	"fVtCzJnDoplJbTnm7mQdacEA7dv3b/qgyjhVHwe9sgdMHk7pWdPfUL7QnCwC9jhK03DdWL8Ev7hmxxYQKZl5I3jFqG1E8TlQ71cj" ..
	"l41Lso4K0rTx+NYZI98090g/7eCSuiT3AiuhGLTSIMAda/BJ3xE+kZuyxt7k1UbUtP7iO8wAYdIlDe3sNrQ149BJ6l69HUrDFNPD" ..
	"+9vzbI58iJukSbtlwF7D3O84FAu+/w5CNTCJ/Vm9TJ1b3Nv08qDV1IZc3geHRt+859W925cuP33q/xJG46cImsk7FEUHWiS9YqcR" ..
	"w5dWUA2gzxdQTG/Cqc2xDp5KmFWe5f32dBrg0gwB2lxDaSsymPXwTMKTr0cqYpX7m6qVHlc6NqKz0/bPv5/ka4yygQ6aydo6MK2a" ..
	"IjdE3oK1Eye6OrosHi+ukJfd9sHSCd2NijPRBQP7NN8anvfUJ3dssNnqgCpTYW5oqvEQM14EFSZQXDX1a4P3sVFOKC1GENZ5a9N3" ..
	"LrPkGLeF1U7eVcVn3nYX4srwMsf0c2Tl4S/erHTG4jreUq79jntJf2bwrV04hEA5tJfhvhEyp5W4l61r+eP6u+G3D5a1fy2ouy+s" ..
	"WPM8pONr1bLciUPaR2H/7ieC4l37vjn6Pmodn8MYmTEgSXHdLAgTaD/a0LFO+5xmTcXX2rgOalfrFOOxHeq9QhtqEBvBH2RJ8JF9" ..
	"R8Yr8SsnyBLUlc/qZxn2gP9ab9efbxgrOolGZZuML9ACE83xqrJljPgJwE4FLciDus1EWuDbniNlxEP2D1KHk/Kg/774/9A4SJgX" ..
	"ZnrtuVdUc7ECKciENLumpGwxSETnNkGhNM1N0E8CFv/ANRWDEuuKXBylH5u9cE34D0fE45kpBpouDlx36A4fmbNgTzmE357VFpaB" ..
	"8FMomYHPTBw+rolA3o6ohS/+rkWwmiWyumVNYsBWhLZqyyyjy4oDSE2BzLxat5yeGD4YLGAHu8HCww6zrx43V6NCuu7NldNAFzDZ" ..
	"MEMTURFLnZBXbeCFqfnSRYmaN7Kc0HrP7GG5HEApE7wOXKEbW6SELgnkhcgfDKn1K9KGf0sW3BeOkP1+z3LdymoIbq24kMyUXOFY" ..
	"/gsTM6er1cstEnp2SkM+2EZw8O6Nn1/9JUTCzL6GC0iwMQxCrpDkptXTCI83AZ/3YFWRxEzutHIKYNXEkDD44Vpd8BHzeeZLM/rI" ..
	"mBv2Z/uw0jP+FsHZVkvEwLMKucWhAn+FB5G0GZEBEiO4c8vVe3NJHzi5vl6WXcgVNPC4Yv6fieb/53Ixg8K6U+T6eUnPMH7ozYxn" ..
	"35STlcSwIF4zvwahsxy9J2xwApaM0Egw6OAbpZa8H3BpHIlCgPpF3uyNHOIedLH1B8OxMOAeka8cR8KUky/IBUbA30J09ZT7GMUt" ..
	"7eZTeE+NX1g0UeTKjH83ac+Oq20ZYVnNZ27EvBj+G61DdQRtgEFEtaXg97p3YO4Lu8VNgPMoxCgwYvtL+63cqYMw+ENRJFqVo7iW" ..
	"xJiVpIE6ASLxi5hu8qWyOmQOSu5tuHLMo/3uDjv+DmgxcpYwyNWA8x6vvfBOq0KMPlnNhMwhRvOjJeXVRNVrjkxNrMnyqrfQJDlj" ..
	"mNSFICHDGg8KT/n3S1UH0d/TA5BHLC7sAU0z4hYPNkhMnF09qjzoB8K2DAFPvlnD8Cop1dTUn0hLMSmWzaKa3weURUSfjdRsrHOo" ..
	"3+SEeQyJcLmzjodifpavr24+If4/QtpcXoVuPqBuWGiOt+/9s99tnKP+ALR2nh8qw+BGlR6QdN2iKguorXIOBPfaIGl2hRHW/7Hf" ..
	"Wj5YGgy3IQoFA1oobaT0TyrqvRRQoMEeM7gpKnW6yMYrqphYkmjA18zjdEYHvnwiyLoO1yqHnJgxHnByjvXHjxfF14BcU4IMifVa" ..
	"7NnaJccPVAyJZ5gQGTW0AccxE3+/lfbnr0dc4umNuIP4iEA0Yp2BvSOXyk6HejR7sCxx2gKiTPmbKsQgOmfqO46cS2lJNCrxI7fc" ..
	"fyrKaYi1bpbf8XRtM+y5ztDOjJVCXlzCsYJAcnInWWMNGA1jZTjt0llJwD8+uapRkFg4PNvELqYrH1jDa/oUe5NVjOPAtNpYcRxw" ..
	"yMgF7Hnig5AUGxpv/mr0/CZ9acVPyzfnUDLsKHiCpn3956aJ/D3a78qCjbnv15kMNYtRor+Ysy/yUStXA+/wjNq8dsNfj97Ie8Pe" ..
	"bcAYGhcplrz6wKpHLuubQ0I1nlcB22S9KorljMURLkZ5iEw5fj1h/RXlDwLDGIbtvhwAn3vwKWvoRD0wM1B2QZ39DFoLxnsCfvTd" ..
	"DKFqF1Rg1x3g0nYGViMOIqz39GOmIt8f2ggCo9VKNlfUxbvMw9oRgQFkOgDLB4YAANNXUpB0Kcxvq0OlPyor9u/6KDrNIzSGxzdM" ..
	"yXB4C7dyVSvctRJDK2vbL7OGsoTcUeaPlWBPWP+kIGTE/I7p5DsKfdNSXhOn3SZy3XidpbXVVvm47YeLCkHzbNIrM/BHn97BAqP1" ..
	"05ewiYyyQzyRsxz6DSYggjz408SNCoSC2TtpR5L/Vyy6fcuO6tgr1mrwelyU6cG83/TmU8xOTzGI17aoEitYi7yrFazvArPXi3G7" ..
	"Uam6al0iy9hKWLnYicLRIU7SqU6J7ny7Z/dHSJqxkQIYT1Y2V7c+5B/g9cHg4Mjq+Iigbt6mG+v1plOkzxsP7v+dUAGLo0NJCfZF" ..
	"cSCL6H2Rol+t4GBPRxEFZStbQyxPzQuQD942cXSBeSvio/BWlTLP0t2xNudRKBwhkSq3mjHCp/FZ5pwafaTLMp82lgdraNmp/90M" ..
	"EmedZjP6t1jde7BIKDw98uCrK2Trr7te2pc+vSTEDfy8G6fq44v3b0hsp1Xf+RJrXDfWiU4m7D3FATnKEqWHiznJE5XEMl09zdiO" ..
	"ujGP5u2TO4g7QQHXoSRwz6EPVg6Rernt1//42ouD0OpmTlEsR00xSoG77zqXWBiW5ZtpQ6DTbhHuFbLnqtH5XeZtMI6KYSXfZgG9" ..
	"/aoIFvpNG5DrSJa+AdYf11+vpPgfY/sPQhdB2ceozKU2WaBL5m1ZLzvZlNiOibtAhKBJdsvc+usFn03nedhnfgw7h/CKYsYbQhqc" ..
	"YIaHa9FT/oESMhJFAOBV2MZFSQqkfWJEp765RozgFX6zHEXBAWjAt3CrIcgxx+HGml23PK4ueqQ6gimpHnTHxafZKe8pnyjqSnnC" ..
	"NhhFz6mI9Zcme/lmDTX+NAtoI05Fed66AGf2xDavRK5n0TeKSIVGEV5fSLXzCHC7ra8jCDAMPaiGjbTl5voaKX/3VKmPNPtg6K5T" ..
	""
local PAYLOAD_P7 =
	"Ove6rAjKM1wEOmg9N1ex1W88IQd28gZPgYi8eFtqSU2jo2yU59rFAJTXD/MHGi3H10vsRC1diDndq7fFQ2lbVPLTGerfakAZ6hRx" ..
	"M4cZ7HdtLvZjmX+f67dpRLKidMdWARx1t+LS2A0DNCfIA3SvHsCihhxX14sCeTqafVS48uL2KYbyOt6wCpFZMdXm6GxjsibZWu/K" ..
	"372UF5vt2bHDhvnFYnRT6ARz50zjNhIO32N6l1Fyz9g0BWMOL1vf5Dwy5C8HsEXZMCPwR4jIwRcrT3Uay7TWK6+vjRXjbF3bibpp" ..
	"wp04aEvjxf9BESr/vCrtQ27o842GD7DJ4QmPAZg81Rr50v1wjZvQHriBvE10xPbOuru0YawSk/qytsSJbIV8fRS7m/VgD6rrSC4z" ..
	"EkkNngSbKzcgYXXDCaltu/0yfKlxFDrhgFpSYHklJlF7tRSCTdabiZ6M9PeGwqN8Eg04CRleI1ScueB216nqHLqTExlzEJMUM0Jn" ..
	"swaL5fulqjQezyB4g4dpMPj855jYXjMcTvmnZhSawH7qeO7rGft4SuConfqJyiLQd8Yff+O+hHmlLjylsmzI3iD5a6Hl7jjvAmvs" ..
	"duTTHKs6j2wTarBvrq6vOCAMmDjN+8Fygm3/xqFOdLmf278dT4v1V4NL5irsMu6k2/kJ+gCeohy2P7m41d+8DOQcY3tt1Bg4sp6t" ..
	"rYN9oCk88unZQc0/RUXFXhCsON013D2njv+v2MLkW7VAzeyDbUPqw+9HeRYLeEQ99PMtDLsrFzYE/e77M9GpuJAop/iduvCLXQV7" ..
	"ZFiIaD1m1dVNIh8MHiiAcMUGhHX7eSwpmx920zlttgprTLr7bIV9KSl1EnCLk2Fc95G1N2W82XwV6sZ5rflP0N0AmTS7QnX+bA/Q" ..
	"ocNy9rU9cgeMDjayojliQ+gw1uvtcc3nr8b7c+2S2klsC/W+zGk2bdDhtNqt2n1O+NVTacN3tZHe99lNg1MZoKVOBl/a0Ry03Ptb" ..
	"YxaK97Y41a9EYVZomUVm95kHChLmLoLrGnFYHD0zWBfSwajQhtGAkwYlxAG4FwgK9ovOfSnqrBv1UuLS2CNuRuuO1J9SNXss8Mmf" ..
	"fZ1w4xLA7UQxjhC/tr6094tqu6Kw6v3mZoPrhGOUln0uetRt+MuC1pNwJGDgfttn82VHS1js1kJmOjGRV5uKRrAHOTI43WXPy7gf" ..
	"7sMOgN3CUsMGbGlq+GcyJ8Fo6jQvigdxTbjERhsf1POan+YlbPMv8M2DmIZN6npOk3FXewHDDEy6/l5fr1CosDGTZhzuLc0BPHkO" ..
	"UQ8420umlLcmgTPG7YsCHkGudFDOdmTfQ2Nicbjj2jSmWIng8dr21UZAXXyOb9uPYyNMtG8nNoU5u10RTWUErm2zrsy1zK8STLTh" ..
	"WedIcteo99Lqjq/yHN2VQJ54vZXSL+Kf1RVNYzKX2qACG4NRdz5dvad2p9FBC2NL+bK9LopRH6u2dAtJ8OWUFIDDqMJwZPsJsxVX" ..
	"vfSaSbn6Y3DicnjzoZjDxLBQqBp2AYSCoSn1JaCMQQMTrQ6ET/ukfMHMVR/Sch6JvIlA37k3jvysRDeO3bTgCyEQuHg5PpXW5FfD" ..
	"0SoRlYENHBtJDwZAO0sfRXBitKlo09e1L9tuDeeDwdsTEm6SgQ7TNM/6SJWs9K6KXt4NIb6n6/lul1guBCwBLcNzylUqDKM2SquY" ..
	"s6crmUbTl0z5I10J3bw56c5YHjdjRuEx+BQuZVrg98Kmbdd40JoOdMVphXm/PAjHip9LFD8dXEsbumvab6xLvuO0NQf3bWTs56U5" ..
	"6wEEFJqXTdHMd+1CylCJjBDppnapYI8zOASr1j9nzBhqVn2fZeGWQkXYu2Si+bqCG66EfxR6afwKLeGCaNphxBHYjupTWGGs1jvH" ..
	"Jfi0OQRPPOPmefTZxdfVjzR7N88tIeYQSV7AKWjLF5Yq78pWUk0zWZi+eHMf2Bd/F8C3bpcBQLXdHkPlosv6ML9xK66gqSYkQvAm" ..
	"scvU3zppfwDJla4/FPfjN8M28CbhcXYkNoqdlr7VxbFLBTjWKq/s+drvnmvPmf9VoAy1G2i1JCIwGMbST/pSkLTAj6oStMtI1+/+" ..
	"DYVupSldtsyZHP6xGbc6lzHswB/8RhRqLFZG+anJU0rnK1Q+y1QIWfHOW0UsECR+rrVGhTZQVXKAvK5T8cZQMCYTPdwDHo7TNo8g" ..
	"oD8f1NuiKwa4L2FGFel0Rl7VmyS51Hfo9VJGuE7z/lujrvuyfXGSbexTdar6OtZ4FWTbPg9xEY9hnQlIrPKKo38HbVPaXwl8PdPn" ..
	"VN+Jg+8FhGSpGkarxrh/jJZHzaDtriQIPO43IsC7DZUvVi0ZT3FxtXVSQ1ECdSepl6gFYmFuMaUvt17g4YwobOEzWVRMrL3TEuC4" ..
	"q20MUilnzcPmlY+IMVU/jRWxea+sVmpPkntzy08MNRTgBybxZQJ/sO2JzBIhaaxF1BFDMmfGch2TxxKXr88lKgF4tD7oKas0238p" ..
	"OpCoRAfEXSooeovkLHur89R5UGf5KqSB9sKrMcmUGDKBWwk+ls05ZbotIuXz9nTalYIZ0rQ8UqdpoZyvlkGSm5xnzT3G2f0Ygn34" ..
	"nnU0A/PkpedVWy7t2yZl+oZyFFhP4PWeE8zEggJXn/pPi7BYuzgFreys2P3kGwlqIYoIVe87WU3RUqh0B77uW/9qnMisShnyXIEk" ..
	"3baumZAiWJz21uQgvpNJmD6GzCvEAFkZWtbJww2jKt1uQ0t8/v0w5koi7ER23f64VOySDd4I+IjaMW5fFvU74/lGIB6eAwxp94N5" ..
	"uElxfdXW8RNEEasKQoLnySYd9BgY6b/deiQypNjG+iEL6ppQ7CfBnnug4Y4s0FO5xlEXQcZgi0I7pGBM2IMkmy/cgO7+dy1mFDQC" ..
	"IbFr0zMUNLSTHmgdJle75zCy8VdE+vRD8kcnx4q7HkCwJ3IcYatMQ5dRKxj0CyGTVP672p+OP4teFi+fCObDCIq1JgFeNg1ggSw2" ..
	"7wXS0R1B8h/utnBhqHpdhXIYBzwu99N3uqdW8QeXYqaTyjVHM/DOjabwiTrd2NeSUjW9PzPM+h8mwyVQ6dbQsFi5FVXU2x0oNB94" ..
	"y/kEfRZO0N8l2VZlNnvC2eV+HGikBerJrW5l/55I7OZoQk7rt6g9TZHiSpYRcrIS5P2I+Q1wPwDiRRf8ZTbTr1ryTNZSaZdouxLs" ..
	"59/t3Lz8jUE05JUcieioAzdHwTaaN4Ho5EeP3n8OHBh9xl5aq4rout48q0fDUw7Mb8AFCx8cRi8oJy8MXSbj7ao0cGo6zZT/DD6X" ..
	"Hj78XOSS9y6t8RpiIYYoskRQfp+8QAF+/Afh3dogNQn41XmiEvgFp18VzPuhjXLo5U2fsM/hmPkO0rujqrJ9x2jZ/iu/8FRh/71b" ..
	"iv098/0CFPJvaThpLBqg+mDjcTcT0jZFvDf+dBdoH2dOQ6u9ix+UylFJDVNFBEP1s8O8lc+dYLcQRHDAgbqw/Wz3Rkz2/WmZ/u9D" ..
	"0nWmBRx8qla+UyYjPhK/UP0sNEkgnL9tXk4dD2tIbcsJ8KhhZCFgoM96DabfdVDd6l0yPLj7vsB+DRwzXEUCWL3cQv6hf6UJpjeL" ..
	"gwf9nyOKr4xBdE3eL5THaQ01uYke+qemqJnwprUtBgwp8DoVcKDssMYugwy1aBXoMUbBRs0zOlAbumKDfENKYQ8eY/fmzDIWUE2j" ..
	"ccz8cooKgHKLWO7LKSsLXMt303mm45D0v+hYBUiPtq3WQTJIpUjwYle6793gQzbSj3N3W9XIC3dZqvvOFomaioSe0TaBOjipDt4n" ..
	"fKRpWnaA5JvZCGs3OuOLYleRrRu284RtjsnBiuAG09osQrV0M6at5UFPNPF//9AWTCgjAyfMaboag0a0D/KybIwzNT164OTeuVdT" ..
	"rfxyUzfDQZm4w0Y9MbatN7ybLiBxrqn4Ok93HEkEGDDZrzKJaxga3PNavEzKF/1VTBJ0iYXTQ8ZC2/FAZv+5ed8VybDXeGJaeQf4" ..
	"bkMo5+X9frpDntYSGw5swo7BLe5cZ0IVYSv9268gGI5/y9HN9tWjp0bZDS5mB76CgASAC55TLLVBK+T7UQDBFx4UBbu4l240GunW" ..
	"w0h2YBP7mOYD2Rmx1EBEVavXud+qHoNcnczqllA45uaIYwz6x2joitozk1aCE1/A95RkPEkbFuR3QgcWGz3ZGTt3MhS1iAwZx/2Z" ..
	"Ej6+sIQcfxXV/MDX7Rt/lXe0PIFIX0EB7M6y36IBM1Zzh+6I7r4aiGI6f+MNwwMeEUbzQIRDYolzyQZphahKXwLSAXijNrFIX0At" ..
	"iLkjng47JP8lSM81wMdaZ6ja73fMT2QarsVAx4eDyUw44B9PbQrS9m8ptblBOF6vk9BhZEuhKiAk7HnjdwifcBG15X3JDLX/9Jz5" ..
	"DW5FWiZST7/Sj+75Lhm+Lfo7I8w6QVAwmaRW/vdsXKOQX24fFpy0SOxfecjQ510LSzCmVZTn2xGNFMfYIlbgSONIzDefLKVGbqO/" ..
	"66d/kXkKxl6Q1K7AX8jHdH2A16A8WLb0qoDoB8NB0PKY2mqlRUXEXgO+91RTKsa6AZcTn2uIxYVoKA6Oj+VmMEhT5x+ZD9ID0D2j" ..
	"r8/AlK7Zr5sjMXQVw9XISUTbvupvqEM2vbGraNalucGWn1xg4T4fpB44ixOpUZRUBDReCvYyBxe1D9blRf47sY5jkDkbWZRVuIRp" ..
	"HaEQ0WE8RTBPRCFceVLLSHVJamfJodw1gWkNirdz+656oLQx24mWabDHPfhVSJphSn7dq9quqkISbR3wKKtYsuhXRJZi5rzwJwD5" ..
	"R6daumUOviQgotauQfABj3oFbS5WgBISzAZ5MqPDVrB8puz+3mXWvhlu0nm1yhbiy8EACrcT5SdaisnOn9/02za9osaLCdIflVom" ..
	"Q4JlieGg+8ivlSmbQ0Rqc8BriUtej8SoR28DjYNAfg4bFwguzVs4BMSg/ynpsXBilGL2sUcGT5wTGVi+R4ZohoYXTDcEOL/Tc9o0" ..
	"mAfaQXADOtu2TRA2Xft/P/pqdj14l797xguzrC39a5ReZPrecesoOdVsod2rv1OgZrRa5Dn/cDX+0JHV0lvaaApaS5lwCICNTB2c" ..
	"fsLWL6vcS6Omdsyn3tWjzkzjMR1XkB2xj4B7AI/DKhASjhyl+VwqD7GC3qlU4jK8DiJ5wHQ9Gx4jhl8QoyFmqaNqjwWinnGO7bHl" ..
	"4zJRX26kgVNZi+KVPByPdUCcLNGCjxl8JX+m8DRs0t+DjMmXqwR0sp8FXaU/EkZWsdMPBLTz79HwANNjCE/j5FdBfXo02YMIkxuO" ..
	"zUZh8lraAHRaSnuNBHIXdy4om/AeSMgROm0r5kWpmdVPtR+XyAJXCfAx+WB0blFCfLIr1gixjK1rGaOwZeNLJp2bWcJ5Yxo/iDxU" ..
	"dmmE/OvGiQC0NEsCeELAgBCgH8kw9WUmdqYJ/bApQe4jxqzQckuSSQDxkTICBBqloexWH3xmFrE/buF7edaXsnfroltM/7EQQSvw" ..
	"hw6PJy7wLzSs9JupEOwJMHXVkKXUZSnmSfwnVnk+xKDapNWFHgzWP6rmYaeG8dXIIo+1dkPadcoA82s3DGXW51FVZnQ1Q4F+3bJH" ..
	"DZViCxrxu30RFD4asyrbfv8G9YVLyChaMrNbcawnotkGDN8gcNBDKxf74pY1NIDhC6gDycFnPVZHSl0tcHlQSgcVmp5NzGRlURMG" ..
	"s0ohBJbLcmrGGegxFrsa3AHjPa+R9hLQm+7AbPMpv3RfshSINLajKmUlaBRXpMU3s12YP8k7HK+JoW4OzuQaUzxy7rSZA9DnqK79" ..
	"VmH2jdizmTyVHcx1SSikRY4G1fVJnFZxMiO/rh9mvbf+xYKzjGg6WkRsc20chiPb5RA8QYLAU5KW8MUnE+OBQm6T+cIC1q4OQW/o" ..
	"ncl9NAz6UqjS4565zoa8UwrIqraJ2xAYBz8A1Rrae/lM8240os4icY0C+8nF699POieu+zWkfBi10PGh19SRtE65bnE9kF7WluD0" ..
	""
local PAYLOAD_P8 =
	"1uva2feLqhu7cZFG/bfod5yjqi0hOsTVSsGqjGlr11GMk0VR7U5cDyTy8cffBRZQabaUuyGzyXM1Noskhi5Qr1EBlTA4e753YR8N" ..
	"+uvyiH/G43gHlHMVpRsFl1DjVDo5JksyKzCl3FX1h1OyaGxvRB/BTCpUtf9UwB9E/DukgPolSv3+tD8KOebTtvPQsCDybf0Z069S" ..
	"3EXI0KuHcDWkRoLI1Yim0voTKnMS+jdupg4WY0C/W8dRVv0AqUJlXau9qaEL0V8VYcw/qVviB/b+C3tFqNZd4UOi0ou7OJcOkYco" ..
	"+zl1jsSvycCLEjULQoEy66MkzDbAgo8vzpycCxozDdBJYznE+Z63I2H6p7aA0JGcZQFKYtP1TePsYOK7B9DLMcl/q9MTwZA4PHTQ" ..
	"3vPf1Pl/HvFhR5gce+4R9db0npt/T5svlij4HIiFeBUhHJXUgAyVUF+qYRkklJbl57BF0Xz1hh66IN6+FwYH6t2kktET475BbdtC" ..
	"Cjr7u7Qh2dITQkaKnWICo3epku9oDHT+h8A9QUXNsBI8qOvi4BglVmmBo3/Jp7AbeIFcvCVPPDJ7yU1CJtZXQCnDklajEm+kTyAZ" ..
	"72T5x8jJDSG9dYb3Axu/nw8pXPOT5lB3pJE5GM/jryplxVWJgbiJoWz3kjnorN4mEgr4bsRuT0X3auOh7x8Ngqv3g3Kb91oZdD76" ..
	"sL/KmfTEDY/vCJkW9ACNyrTiIpfoX9xeCgqM0OQEmkFiB8ySIS/Ie+SKH6JBaOUQ+/G9pJRfvWopRXZIWbP0jprFfH7uiHMmkAXF" ..
	"uhVMRqXB9saJRBi8YgB1W5NISOzI0rci15RnD5gUAE/TCqgGC6GIwBRH7aMI5XBRj1C3j5ByEYIuR7vAoHPcTJlcKID9OpsFBl4U" ..
	"HpImrz8fJitfd/94D55e2nZPHikAZIyhBp2Rrdwi9vH8AKr2Lgye8uskyo6uUO3rX2irV8jMt5kdL0yR7ysVh3Esq0SC44dBrl/a" ..
	"bV4FvXbndPl64+9ZvqzCu5l8/kTeCNCDCDku1M55UD23zCb00CZk5mhTXKgYcUVEPfJyZ90p7qZF7oefafoMa1PLTDzfrTq72vzs" ..
	"FSLcGzU6vwciMGoXM85M2TIn+6K2AGa7M6MuJwz07cETRj3k83+Kdi97+d7KVMag8hIyPUQDOU6M9Old7b2g+uPtjFudcP9VUrNO" ..
	"SrO1nRqhOif6GqnWGGOmC+/u7jrdG41huju+obrOYvudbsq6E0h0QT4Fn3M3VvXIsVFQObPUuQv285vmuJmZM5kVVRFLmg+sQANc" ..
	"6SxDMK/463bSVWaOYpRlac8vWaRbg1HX9Hm+JvNl4xcQLqpoIaF+FNq+yfclq75CO95cqkwtVpM2TqQ+z9yzkaFK3AIF5XtGD2BX" ..
	"QX4bG86M4nHjf/1HewnJKOxxkpdm9sWoQJwEmGd2pVFtL/J/pS25r9vVGuL5jXplfNeTFXXTUyWLuaBHvS5J01E6qZaDBRrrLG//" ..
	"mLsulWTp3berm5LZOXPflqRyKSHTe20XhpcsklRN9iM/MnkDjD02lzrFND8VVzJ5IfwA5oXXuq9tbKqSxJmosc6mPVLX2YETp4oC" ..
	"SBp5T934PXjSi6Ce9nSRxGsRN/pqvfcAyBh9km3IoCf0k5Vqe6P44gGHiaRrt7BpS+tSPUerfOHlHYUMrLhwKHtJ2sydcfI6LD4e" ..
	"0bneFh/35BY/8m3glbASnD9H091ppPWN4M9RG9OH5yTgQQ+HB5bfcfoEBwohK7PR3pwGULCcd0XRz42XO8wwO4oMzszDPCFeq83Y" ..
	"Y8iKc06BR+kRhu4wPpsXp+x/it/ay7XmtiPFVCtx0I4GWtXeTqEq9tODXGmlJ+JikziQthZ+EYm5f1QeXdB+1VwDyVxzxv+zRqzh" ..
	"IR/mjMpPj6KGbSyuY1FlL++5fgDRs3Mrf7IX15eB8M8gQPIk9qXC99HYNwj00dadrQAbXXGNFYbDpRaXtetHViBZc9rQ9Hdn8a5y" ..
	"Evr5tQlwMRoIa6TZDteyaroL7GBfYLfPl+4Dc0Fm6dCuneOi5ySeK7+uQM20+pL328CoCpI6AJRsJLgG9dd4H1LduLFFmQRt1cPK" ..
	"FfxpWqLpTkXWJWPc6nVKEFlxj1YFhiBVyDoNnXsySlED0dEoCa5tgmvAHqS+/y1N2zdmU2VwfAGtzkcK8Zoz/cPU/4KER9FWpQ5E" ..
	"V5V1ldm/ru5V+QpLsX96DkWK2/JlbW32xD4joeRIE/hTXh4S4wbSDJpFV9UZFvkU1hbMyXUPBjkHgzlybF5Ypv7qzkfVq6MV9tx8" ..
	"KUc2KLyrdTQjzFyVwc3m6jtes6OjtqNw0lOzcyz+rkYOhca4pqc2vjJIkhkUcYqzdWL6x+yT/qlPRPCdVCbiWZyjDvc4Mi3E6x1E" ..
	"Bxjn4ns3YA4bjmC4+ndCRBtTPIUEuh1sf+hBIv8tNM/5Nypfr+nnoUI56zgYBJSx6lc2tc680/SomugDlTFVqne5cxri406zluyE" ..
	"ry0VNEXhTVugerns4F1iitFQA4ozTUUM/w0yBo03b/7UBkZ2qxPF43mFIT/aEJ9DiE6Bg9xviXPzc1rQ4/RQV90HTEecjMQ4qHoy" ..
	"dY+9oxsnH/JkvjfmXD0ggvp+8gNJs9jgNV7TijFMf3114U4UdVv2aRWRg7PWwjXLu/RpAjfc599aztm2ouivvw/DvcsMSOIfBHd8" ..
	"RlkMBvDjX9rvPw8IgqRTKMe+ZMorRJoTKwur1hq5iWR3UYLIKxGAfjl738wXV9US1jAYO9q/Wml/BB/D5obgu0zWakgK/GiDDbVJ" ..
	"2wEedPza4NIizG/VpsIV3I9jVmgVk6SEFprJ3mWQv6U5jTqVefqBWtgPTSxZnAdbj/DJ8wQ5xetyFX+Z0Mi6LBi0upH3WwgJTGW6" ..
	"Rz2qgNxMlrpljxMFs+3seFSLCSbpTvn53BEtpjnd64BqNlrj6SV5168o61jlwujySL9Nl0VVq9buP07CAm9P4ZNSwFjGmpa2JT3z" ..
	"s06mw96wCoFMA67Rbjfeye8wbi0HZt+JxJ9qQnrOAQGR5oNqIL9etccVrSKKPQk4Qn6OX/DS/ZSreuSGm764Nl7Rdoc8PYujs0c9" ..
	"72KIaRhXPZ2Q4o2i+Mdt4qHA+YXY7JHJ16Hv9DLFVLoY3DvAphzavyRVPqAvBXvl4cZ+js+5hiqyIQmZKf7cnoLeHjIsB54hZ+lP" ..
	"SDhiCcbn2OuRgdBYL6oak3pr+qWsO2jpplCiAfORv+eZPRa7IQ946iN2proLoJzoAwWBu8AgZzPmeWKMn/3GYzJ6vIOiIr6mZ9ec" ..
	"d1E95AKazWi4yxbmmIWK8iYTzf8E2J6E0e9ST2Z6eRLrwuLVCLEtLdWZkA89MlpW+5qoLjcmLg7IVVHRE4FT70q3ACkCVx+dIwYO" ..
	"NYVQvUsgbczqunD+Xz29yvwaSSk23X5jXoy+Yo58EUPnfQLRDmoRU1WFJt7ZcTME6rZiX6/iwDnj/EzKScrz2/lmdDZt9HY528HD" ..
	"f9PQB58BMkLQ1hHcS/VQZF8U6es0yHR406CiHK8UBYe0gjJen0qzbYDODMTCrXbTG8AzRRNeCbJNUGTksABZEJ45ZszeKNjYT4r4" ..
	"5k5j1ZUcx1n5y8EnUYdLduHt/n8zuQ3PZv/6da3cM1UPbsIiw9DSAKRWtc4W2Qs4+c06i3CIF4Y/bFMaKNPFeXZHE7lLRNawTO6J" ..
	"LvnHpT29FMKnx9CkUtmd/DY/+KdwnQvNAzaX3AiYQKsEuy23Sj+L507epFKJ72fWndVCexvSCz6/iTRw9pEHfN852UeXWV7OG/or" ..
	"sFMKKJRwXCXXYjL7T1ZtZP8ijQLpDAJbX+rbGcTiNFmq9QBUlF/qA/owBMbj/PInECK/JP/RXUrHQ7CqJg1Fq1xqYY3Y3OXeK1DZ" ..
	"CzSTQhZiBRAOW7S0xeJggmnef+ThPS3CuuO5xKsWx/pBU2Wza4VnTQ2lKiSZTK0dx1BzaKs/DBxOWMXhbTKK+r1/cW1iI1yHxABW" ..
	"mCMWeXPI1IodSH4rnJtlfjv/fIfDjv22Z9K+dz0/6tdn8XB/O4myGpWWaGB6UvJu6nqGWSzHhrAk0BKdW7mqzgN8PvID2crGnbp2" ..
	"EcjT9hs9EiisjwC7sYcKU/02aKYZ7TsZ5Xoq+GYZ3XeSHQvpZvIZr2dYgNiUA7nSMY988qZoG8TAoQ7CJNjc0oEBTKsIlv0+IQlr" ..
	"B6SfDa4F+RWtqr86s3Smh7q6kX2jAmEQE6XzEAPGGRotfJVRgl24oS1KBjQAfJWQSka+zY7CmtNiF5aN35UC7iYneMglQ/pms9Tt" ..
	"+iye/Ha20DV23PWsi4dWnD7XoOG6ea58VCzTJoE+paYvQ26bnTeeQ04HzuPTTm8yzHw6CEafCiWUNHcDap5AKFr1myQ9dXaUpHwW" ..
	"OSJAnrTkgsdhA4oVXbVz2nuKW7ai232JV4aJGE3uLYpVY5DJnAiWn9VpiGJOGVpF4wkDILZksdzvD+n8nA4ACbFSlZTy+WZqLa7G" ..
	"BeMvq19s8Tj4gOIFl+rNZJ+OvZrxZHG4hCQ0gt07d4WG9nlZg4kCh2i+COiNkp+v9yK0dAmF8Ag6NVVMHWhk4Uf+DYkD5PjJ5ikl" ..
	"a57lXPtRrBePGh5WU2qKG0XZiuzLnSrIR10GQ7+Sr5TrLif6BG/dld6sJqRSFt4PkE+7alXchR98EqjVnzMisZoEsGxiBtUIwmfN" ..
	"VEgESKZp5HcSRe98YdYWVagZaZnbKjKilXhABt7YX4Saz2ubE84vErTHJOdzCn2v8ouXiE7QbKAn8iwxOJem9voQkRyVzkrz6Sdn" ..
	"412I/vH0k/Dhs8JFSSIBHcAC5YsVd5x+Q+iyCNPZkZL8QoooBM28GQQrLK57opwCiml7e4hLy4xFXNujyr7hD0zvGLyMmIgxxzGV" ..
	"M7Er+uSISTsvmoJTyuN2eh5c5erWlDKsQpbOu7AHyBz7aCCZdSufBdeGDu5K8+hDkd3NxCu2UIyrauipUwnOeSTOJfo4KZGcmsgg" ..
	"hwPUQHcjG0um+pXqXoLNHh7MkZ+MrW4KX/lKUSFjb73VjKx1IEbOSfEOD7r1HmIPKJovVrGLkN+0+0wPB2P//dM0IxgKnIB00MPd" ..
	"hvWxqR6H3uLDIZZF9uwrLDGgiSgelnDRyB2OzjvQGXr9KIetO8kDrn8dNT2SLYB2u8Lb6kJed6+JT+M7vKNHNpku41o1RCHvdgnf" ..
	"y9Nof1BN1jpNB1YNA4SQAi/FXubABCqQ196qwHK4mU8v82JomoDWxaQZNkiWuYL7lhzyIcYsMRXaUQ9E/uM54IkZpSFcU/T1ecKc" ..
	"zsbq093+Zcx8Th5FhyBTsYBBRE3IDOVAYzIVZOAXOCqwIUcNO5byFWVEHeo9spttqISRzcTcIAj2mgzdMuHzN1XS2hMXwi5hYUXa" ..
	"JsnKSbwX1pDtdgc60ItwUZBpeMcDQkI53uTrK1pZ18ULcaHGrSSLqNJc4grTX+kplISPdbsC8wwgRy2AAvFeP2OlQgjbdSyjCkfv" ..
	"7y4aoLAflYqCCByhoP47y9VGkU4Qw5Kf9RDDkOL92OoCUNAOUX5tzrpUwl0lI0RgbEDPkXwwN0U1VEPz+8A6/GmwiegQbDxR9wol" ..
	"B+HpnJxDjyrd9DUPQXoyYhHemzlKuYI3kIKsCPNbnMuijG39QaoLcTXsoqbaHenWd6ZrMbgq5/DUITanpdrc5jxK81X0lF9YlA/l" ..
	"vdoCzZydovGsiRgCJUVr4KOGHYxor3t6Yr3enb1a9k4/iZrocquyvZxOCbur98q2R0+zehvHhuYdxe7q/xKXPO22JMmg8YBvZC2v" ..
	"qTCWhi10c23HpTi5aiDbO3BAuasVqa49kDzXjfx8fvFEImsMsDE9a3QT6hi94Ljj9bY1m8wWpjdYjsErlvC3n9pRmBYTYt8Tv65D" ..
	"qgA1sdMbPABk7iNLWnVV4uXLhH50cFI3YBF/teolTLuY/A1pEGNjof/0Z0GNtzybiM/TMMruB+L3xEZfLO/7h6swQ83gAy8D3jH3" ..
	""
local PAYLOAD_P9 =
	"OWscn2+Pb/7gyZFiZu2H2d3UWIxWegqgJXl6EY5eVpT8/X5XiWQ0gg/4DXaf5kwWvanOHM4QKBdmvRbrvRNa5Mzkcverzb/+lGdY" ..
	"Snu2ZieHm9ZsRieX4xj/y9iVbIUfeagHDskGLwYp95ORcHYhVlR3Eb33c2q2xEclQUe4HHwxoIwoAVMXTIUwOqpAwY0vHklIMzek" ..
	"fygc3hOLc/LqumoFXer1rIcZxNjupoZfMcZF5p+hLeLAIHJddzidP98x1Vt23zoofYo6qgGFuOO9lLDLeuPy5fwMIOwuEcPaZ3k4" ..
	"lrnkoS7Z2jNeohYPPtOvtaXLLiRHmvFDjO9P3FpadITotdJCmMsR5tk8nH3Jm9PkWVrF+Swiz7Q8myBjWh7BgvSikTJUFmQEowOI" ..
	"SlFNVoJpHcbjVaF5def91rHdICAMvktssVoBchDOInU+oAbKnwHk0RjrUib3CzuDPnJiP7x+9ls4axjysPYAkym5X9FkPLA7aOcF" ..
	"YvDeW0pXliGSg3JqHOiiMYqvuAyW193oA0ovSPG61b72FzOhrnxquKB4jtYBbUsbFnjBasfFcRR81iFwxwoaaknvbyaYj/E7pzXM" ..
	"O48E74Qt+t/0VLyAq17hTyE1XD0spPxlWSIberJRsfCHsypdT5f3e08mLOpnebFHpBIfO1Wp1xRXjP3s00QKIXFQxdG+LBskNtMX" ..
	"M+f/tOWM1kD6F1ArKfFMOSVndwTmRuJFB0z6D1RnIs/xB+HbmXeK8HpB+Ce2CtAJlZtONHSHDyzsvfymADFFVkrsylGvkbDoHadU" ..
	"AhMqD4gCH5qeBBNi8OPt6KazwbKPu6yRfwQNoiklal6SCmm29+lOKHUp/q61r7rw+zlctIKm5ztVtetukRlkexOPNs/YU2Oo0/eF" ..
	"qCOfwMJQ0Q/+Wpt0YD2UK4Ohn0mpSmygaG1JdzP66/o/HXn7d7CPsdZ+34QXIhCr6Xe9e94+cKT8pRODhqraMgILwqCCSZY4IQ9y" ..
	"G3xGTYo3inv8h98KvLMIfukMvP7jUGtVM99Gjp0SVVGo0kVxIbCiumtKTFjrNy9fOeLL5hqSsSl8ynjl33WABy9ba96CJeRZ+l7k" ..
	"ZqzCLhP8FuFC6zjre5qHOHZQ2iu4ztpsOuAX+sZMsmeDdMO23mA/5pCuDjPktiUqWU5iJjE7MW3+cReljHKsZwH5BQvAzJWtxMFX" ..
	"ZjaoS1AAg/3MyMEiZdXIgsQUhfOYwHbAQY5Ntco4gYkEecL2y5KejibVB+Wzla9kJpLcZNAi8SaJDCU6qq25wlwIlgGaBhHqnmCd" ..
	"yp9EeLf1bBb1l/EowxC+AK8P2byXNMQHLTXGoOW1l30F3seYu3tR397prZuRy5wB1xlj4wdddGxuIwqn4HnlppOXjaJw0Qm2VTfS" ..
	"jXa/3pGplQN9Qo1FDhP5cr9fJFl+/wrhiSdTc2BMWBV2gQIUqkVg7NXAXD9cr9VqvYqI89d27XfUxOS3AnlfRlUdaO8XQewgNQZ8" ..
	"RS+r1EryJe3/6fcUuS/kDjBrsYsWOFLKtWXI4bXZWqwumx1oEXLD5N7nOkvhl/zWrfDcj+Lpu3b0boL+iuId3o+ak39VAxvPCU/S" ..
	"sPymHqqjyFjPhW1bhtOffoVxDcEZyOqPi1dWpTMgt/Qds/IysSdYRv/cQABfBt8Z1AAmh+AYo51RNa1r6gp8cju/8kp8ctt/Liq/" ..
	"pV6pOmRieibSBVcJM9RXyevJRDVILJPb0QMdCtnSOvW5uTjfrdCxpkX1rPJxTFWBz05SzIAeHENX6GaD+hin61maK0pL/sVeGY4l" ..
	"oO9k93fLQNz/Nk+D5KDsUMGwIDsFtwS56F1P5jsuxgqs0KUqzptD21ACVEtE9j2ZZI+/9CXKKM64BYG198Cg2wP1YZyv7pM8huar" ..
	"+0/phnBLlYQ9YpY+ArA2L5H3aK2qqQ7yiX667iIAE+/DNh12fO/jYcHEWPNIqNjSZM5Izch16700zU9e2p5Stn2KMrGhrztbbLFc" ..
	"LswkHsWrvTKyrOShcExY7DgSx07n/Py9iCDyshw5jVCtf68b6swkjOMkuxjnr33E0ieVzQHRI0l8ORzBB3jwP5Kxht8VNzakOQPf" ..
	"C9Hzf8ijgVAMvXhyigLd8s13+YphERyFigEMrUVbaFhc4jiPqYIZ4oM+fS122H6QuQsTOzXCPO102CU5UOLlezSwOqKcwhOgfmUy" ..
	"10SiQfrKOOuub/MKAfxWZsDnBxPGdvsFRgp/IOUQoR/wlgmOHu/r4y4OVaLGfMgxRJxQjsc15L8OUoug6z/m7RLkUhKfA0/8vff5" ..
	"zky6Hsnr0Bgjx6vjkKoMDFTLDdwkt2ZNpqiKrv/eOclUztLE2i79sUMZZe/urAGFXp2bSUwC8SHEkl9nbG+FKQKcfTJ1FP2w8lrx" ..
	"buKnaCYIQ/nN+6sUj3C9cSmwY16AS4P2MQXOQEhrcmNSZMbxMp4LL4QaQAHRMPs/v87VhCJ3mwbI7wa+2QmmpAN5a2F1ei8i3Qf9" ..
	"jQAgmH6kZ0DyPTGwEKeGDRd1tzIUnyDo8P+Nzip3wWOLxOAYP2iNDRJHhgMxPqyDpNjKQ0lgqhd29Yew+pjLyTl8EWJbxe8uVcui" ..
	"JzxE8zWlacFNfJYVlUfZJVqk5AcjbniX41d9ejPEAdJ1x4mcjlmbcCZ7XFYPsIcBq60yL2n8VaReQIvk9AUerhH4hXEIidU1FHYy" ..
	"W/t7MKPUzzPcduLYT87Jx4QZw+T1sHYm0aExQZshFWzSQj1tZdQSEF1rZOHMAEdPnBpgdh3x3mHeu5VUUJBvE0jbUF9UfOcsPqp9" ..
	"fPslCQYkMay9He9hGIMbtaMxFvTAKN5c4h/qJntAEzOr7SYxr+wVLTOmCBEAU01XVxzOOcO/kfWmeZqSiZsioaTMDrxjFBw+OQbR" ..
	"DW8ZEzAywxoVJjFFTNz2KHmFw6ZrVGLEY42vlWmcXOxvnRtB8PylDFYurYxgeoLcy3jLQ9N3N+AR8g9XZcI+8BmoKffmJ6JBEFrH" ..
	"5QIuwPlj/PcPGj1MyEGqJvbPJBRPpjf3NPFv9q102UC84DDBWI4ZQFQP+cA+6QfZQsyCLSnsIdHUE42O9Yr7AuHxFlhHqEEHQccQ" ..
	"+FBvxMOi7Te2dzkAN7NVAwaPBsXoRi98sAanV+O3zHyjOC4+FJ0JQJ6Msqpxlh11TCHrSRM0Cp1qOECeyeKmS59n6NIT/wWO0ISj" ..
	"1/xKHNIRr1vJ2N6N0V9c2srhImOEivTudN6qgi2nVfq6+XeQJR+/FCAOB05xssAHR47ijvM/JHrOeIJK8TUDq7h74LQo1BMQAQ0m" ..
	"EH5YoGpj7b8PuISveuCKMF8JUFDcledwXuFysHNlEYnww0j0/f/8mF/BhJ0x7TFRTVqJ+6NKnQTgZN+5RHCeTHVm5uwEbtEkablp" ..
	"g4eZJ8ycokHzW6uFCXqmDh1Uy7oiTe7Mev1SnNwHBqrWyjW48OFNF+gSfozL1+ly2DachvA7zHcA9+O2BWI2roY5cZhreaZIOtSK" ..
	"FSJlgzXnrqLQpNIab78OlcFcNyzl4yP9jP7dL9Vl/DyIM/0kCW8uOOnMEB9K6Yt2QUwTIu1opjMm30LsI41XKS1pJNjZIcRgdKT9" ..
	"4A2+L40E7w3AgUvA//xgowSAEI9ORoMXwNj8K9fZpMcn9l/AFn0xdtubjnlRp/tJbXTt+9j8ua6vM2O4THotwa3Q8dKyf05aVD46" ..
	"AjwdAxK8ydMUZa66giu2WlEVRd5KfeJNyz018iGGhr4KbHNe4aXyuppaxh0LrQOpfomABPx+7JihP+5poyE3sk4YTsSAPZSFU4Tt" ..
	"kiEuc3zwox133MjqHYg/omMeOSyrcDisq1eEAkH3OP49cJbuH9yg5JAfEgmoGgHZZjKVKoiGjc0ZmpxzY4UfsryqcF69519Lat6p" ..
	"xHdSRzYfUQ/6jmf0gAVtIi3DfR50d6aTVaRQUAKD1Puo46DyvWOcKVJHJ+5jGqyTLUTfi3IAFIY0qaErJtOgFGUNWpLkC9Up7ghp" ..
	"wTEyZZVJwCj5x+TV8rjQ+hGYKcEmAb0W4phhLC+AO5qFcPGLk2zjRQM4ZzNvWDr0d4TpuC7xzc49vpdlx0DWforNSni2n3mpPnFD" ..
	"DXBOTlAwc1fj0lPW/eZSf1UlVmib3/sKfJl+wPheCr7ekfjXFkuYBu2rQ18RQovFdMWgDytumk7t+B2i9Djymrx1PkQMNOqf2Ihr" ..
	"R+MkXxExXyfBQXJl1HnFaMWrRlPiaW7Gz7qjsRTmXLSzj8fruSCU8xD3YPzBkbzHtqF8byhPk+gKSfXmg8mTnD7gCiQAlgPQYA5b" ..
	"75WUdHZsohl4Ze9Sp1mjDF+qENIbIvMccARfWLGrJCjEQyOiwchoQ5TO063/nkW/rVhV7NXNgvkD25pQ2qMEGcJcFKlsoRZ1RYEX" ..
	"Ms7ELj1ZqBU56Jbtdg73OuwNfW0hJatJu6nNfxkT3TVFBO+Gar20OI+5f/jsQOYiuMJ3hvAQVoccY6NtD9qLgVDgbUR3m7NVWeWz" ..
	"jAtzLbi4QLocNVq4rF6ZUtb6XzcJGXRrOYnIo+mzf4LzV/0FdpwccYgiD1Qswka0kVqisvhNEkzk0a9ucVLPV5SV/8uLC5zok/zI" ..
	"x+IBzUHWP2JMGSlg+dV2eZuBFtHwZxfuyoaSOJ65JOoaZ4JP22gi55L+hYY8BneAE24MLi8lXD7kul5taIjxLhz3EwbWM7DdNzJw" ..
	"01pkNqFUQBKN0l4kdWw7GtOfqaxQG2G45CJyTEZ1TX2LnHPex8HB+h9ptNC+UQOPvbzLfeqLnASOWUMyORCq41YmMf4MVemObkzP" ..
	"FnlP6XLHIE2cMIr/gyIPmKua6RLyoTgYErKEfU4QIrPZ6r7EKdBpYwlatEaqX3U/l/+qf9G9lwm8l3ZbqZE+H8yvOX5qosViv3Mz" ..
	"CUIuvfK6M3YDvOJ05vffHmnXrxGCDOH+dQ5YksFr61iFYihMOrYQQ0MnG7/+E0OX6RQvasanOfvIa5q70FWUJ51PqZ7iVSl1YmYX" ..
	"4wNVcmZBx2RvtR8FINxCTW1jTfCVSradPe5bO4cxMSEddiE5Jcg2NO4RfdNpHM0jqFDWq4D3nBa7JYsysWXNr/YhsPb6GVRVrOUl" ..
	"tmuV75z1CM7MIWzuKdU7jzyuL6CEbb9flk4W1he79AzfoP2Hth91zsP8tWOuEA+cIer8cfhMUECD2G/SKHW9JQAhDNKe10s1NWOZ" ..
	"H2JYdLXhGWWP1q2Caq9/YaUsmOVmSWZuCWm5/UwgPMGE+HvzR6oz++6IqO5q1Y8ptWF4GZq093gp4kat0o1en8DffqLpXAg2603R" ..
	"pSTvbhHkKsD4DSDe8QtXhWfarZtCoW07csasYLgMS6zzMSRVAc7J5ak1jKDP9xne+SiUYuniTxOAuD9/sCRASs0t/Jln1cGwhUah" ..
	"2nRYdYhvNEMZmgcZMveZxoNXuc0GjEnyw5cKKWOVYzMkO91rlE8CGuwJsDuVwx9cPqrF+9Eyvs18uwHiUn5hNy/k8QKcvFqm2vhe" ..
	"8RvIHrq2VZmXzz6Cmq3GOlESDsDC6g5nNBRvvVsVdnZOEjIPaftlBY9vUQTIxhei2+Ivk4vibpRt+h3MxXQ7hs21oZe+vI8dD1k5" ..
	"V1gAFvwSvb89vpQMemr9jkubyVaJ6o18pgQhTAGzr1ZpyH3YUG7DOA4faiffgNjDOevhOgQYotEPmdS2EQ209GBTqU+39fm0zdk1" ..
	"WK+RPWnReK2mwW8B/IBpDPPvhff+Q/I1HV+y/QU1qb7Mi8hXvLMSqmIZPbeL1eDz9UwMQf5lC1R0ovRx+ejcAyjrLw7qB+c2hMWk" ..
	"jpIYtdPzvct0d3sV9L1yulHH5rWnb+jZJOCmT0elo7bpnv7z1/uXqmR30S8SCQ9atCBYUVFPMFTMich0Zys4xx8+cBQAYivPWHPl" ..
	"tT3l7c3cW3ULbW1fB+rV4tZDfAM/M1QcpGvD2Zsac5qyaE411Q9eXCmG4VZSqC5t5WplckdYzZAPtnEUYoKY5Wfl0YFpzSQdfDcS" ..
	""
local PAYLOAD_P10 =
	"D1wAOLy+uKVNCXqNklK7e6igFMju8bDsoF1TFbpUTTYPHWOYP2sFKcGAUD8kxeHe68DXTY0LV+VKfV2yaWMu782mvI5PeN64puYC" ..
	"fPS5wCnwnPuqfN6DPQiasJP3dRCkj4UMBSKh3RLCaNZt/7IeJZ/Qc055spfgL8YUujQ+femTRwCYQy8SAXVxrwTorh+J+Jbb6qM2" ..
	"li6xoa1PwCXMn2aGvL+FY3n052UBlzURUZfNEUlkWN3Fb5Ehl3fBCfuKBiMfQmhkJPYN2peDTwM4VzIxHRzJp/6WYT7YHa2HQAPs" ..
	"25aOO5oOlMr/80TV+k4EsjmaIbBvk0QWU4RSFLDwNieckwXD/CnEWCPMAmTheSBND7Eg7nCTizO1oE09f9U1KgGPtRERb7vIYsce" ..
	"dP8+gvgF3jHGgq80j/wL+3XqXA0T351V5GmuUZdzsksjZ2DdJicQFWAghaTlSclTNuxK9JjEyVO+MXTRrSeKlbqu3+oHwvIENLy0" ..
	"t9ZhuLirVhUWWGqCf82H/sAvPxgwQeAXHVm8bq1NfzgDon/dPO6mCp58uE+41TThmAS0q9dkzZjZuvdkpNDWXUZQaMOsu9fR+FEf" ..
	"eOH8yjfJHPFBKHFsOzQ8UtXMs91pofdM6qYBu9v0068V/H5eGMEYZhh1mQ+/33jI+o/n73Bgu0h5z/DTtnp7mx6Cdhhn29a2P/S6" ..
	"rwWNvD4p217UoeIMi5CQqArYYxScjDcFSLG0upsQrH5tALZmeFxRE/8OnxGCszct9qzaLwD8yNYkEC2fE0Yv7vuf/yY3HGmJjIxU" ..
	"1/mYtWz11XHNkO5HRR8R/6p/BSiYDsVXw96tUHPgIoFym2gUexcyTmZPOOgPigoa70M4eN5j7xQ1KPL3wokeCfpxN0oqXv49iWoN" ..
	"LADlDT5Cmtj2iciFZHwCHxSCWHc1mKVHp/alixdnAg4BSC73q5ZGlW1tIwqLSIAyobdcYzjmfQLUYhTXbMuFPrWP3tqcq2rmQQrg" ..
	"KYXrFe7McRTbgogRz8jLtxRY/H2v/wRyaxysEM9tnbprMCSxoGqdXGZ1TYILOdjTT6snyjfCfmqcmvWezgDRKW7gFXu/N4U1PRMx" ..
	"H4i0uWtfTbN3AaI0TTlcN1DDGMrkDd7lkG+IsfBwqImOdgcRvRuEf2Qt1/6D9OJTG7KNJdC7GGHQL3d5IiVycJYwIgkjAPHYXQkQ" ..
	"AGAYtp9r5PAEp+P3DLEwlkOVgx8CSFJPPlaKNicPBcOkMmhvMSrT2DNTaOxEgXktyMEOVcFD9s0lCmUGOgEo0kdRDHjNKaNCl/9+" ..
	"F/nC1IAv7XOjLBuxpwXWQRF92i9BOYLOtC2406y2Uq/QvNVu+mV91FDYtjBg+icGzD732Z3Xiqhh/h6d0fQqCmmB4gWkgbhSYBLM" ..
	"FaKUK8GfgVoB0J2PcN/w1ChWNA3t7MZCGZUhS6k8jKRMZ5YSLhyk8Qcfiw+eTNhO0dZLujWkg+v8oRApN+Eb3d487gPXdDsTZaaP" ..
	"tIjdFDY3Ca0K4QkDu1zqub0sfBcrb9tjmk3neGx+5ctxv89xBEMPxtboJU4kSEf2gmVPNO52Gr2SjZH2+LmOAqSGjo5Bg9ILugM0" ..
	"TvLNty0qWWUKcT3Ime47GOdhzR5FRKTUgk9rYNwhKodky2Pq0HV0njLfw040SFaT5xcOmwSfONAETnjlPHtGPjEayzt1IJB/MC4F" ..
	"aEAhsKOORJrStYAZbEr1UGU7fYBPpHDy02nq8vmB6edANmKObbu/PD+YccwA2cAiC0WBGPkHgFwuuZ4ISbyPBJ+/CxJM1aLbphIK" ..
	"bdfdoFiX96tIkbzMeinaD7BW98yrd4hoxiEHUTFfXjgA4AQY46740pRogXxpQwuKqPu2G9v9BY494Urx3SKGbPKBa0tYu2CilSdv" ..
	"maKLwq5q+Rr4BTSWyoJMzTFZ5z35GLDnlBZOMpB7jl4VVaTkiU0/OFasUdJF9l4BFvrz3/OaA3XnBuIIhpAy2RcFm7RbEo5RGAaN" ..
	"3rbLCYKqOFIXD3JQukBqMMLFxiG1MY88rdd2liMy6AYOmYgt5/G1hGhYoyuD2N+8VtB2vLZDxw9IrjBHjfMZNT2IhV1jSqixdePH" ..
	"qpFScise1tvvTQobKrdLrHuVTMnYyfUYsnEEFx3SSUPkxwKx9ESQ8meA8zUj1LMzM+CN9HiHg/CnPeUUeGIc6B+1tXP+OuZ9ibMy" ..
	"utlO2ojr398jvoAFPhNmkNEmA2L+LVTaZ6dLg1zM1c/nN61tcUlVaHdYlRP4mRXFwF1NAL+lJIQnRUY5r0LsGF/+gG9LY+cFTTtT" ..
	"xwPE8sg22CpmjeNsja0rB0/zkRkBX0QJrl3XCzvR5sOvLA8ypRA70pAkyFG7LJ37jJeriWi4p9yQUjpUnMrT5Yl2lYc89+sS2vQA" ..
	"VcfgUgWLYQMQ03VgRwCpfSmlkSwLG19mUhDzLUIV1Hd05OeoiYqx290d8bGBfdpLEjZ/dqpQAy//CafWx77QcxR51o1LoJomc2LQ" ..
	"7/cyhOZe30y0j2njCJprnimT2Vo9pym1bCWfzMwde0BVDRBVJ0f1xr7VYnAgcC3ial5G+87fWbjewa44SVlS+zIFRDSea1u+CdFG" ..
	"LZF0rkPeeNxNcjhrvnitAZkHSZENs5MEVjbsAw0p9hCQBxMHnOHbmcsWqPDDcC5uh4SHMtG5tc0dzLtc9EWdMVvINeeMhIms+fbE" ..
	"+V8A5fJlze5WDKOO+/1u/2uB9walkPhXC7Phb0xQYaGcgJjj+b/YV2zymfLFWiqFcr/vX+lDysByBoZaMurIyaorAxyWFWckgZNe" ..
	"fuc0npR2IekoyzymXeM/sPxh/ebCIwxE7CHIFg4nNazRmqGWivgxcDLSlPKLE5v5FOAqEaD+H/OHfFxHtvNQovzp1ru8yug2syD9" ..
	"oQ+P6a87AqP1G2rp5w6yz6gMgv4eyEmmi60uVFuzCdYbJ91QwyJ6QVtIdgGklr0zokyjMWACVNOLPMCQSIWE2V0ynUvuANiv0Ngx" ..
	"GfTJrP6FACfthZzzPqub3A3AUX7nv63dO+GGUr1NqgEWbRjgni5bcBEDMam9QevVtYxwmqdiA8HtMWOibMLDqYM6cjoDNTna3C7q" ..
	"7yKeDd7dC1nrWPv4LSBi+P3yN23TDJphVJs8PGDoMQwSxr2wYeGXhpNpc9RjgPj0o6HojmpY8POo3RTcapXpKBn+fF3dUzzhD6jf" ..
	"ytoC0fOj1lCs7GNqcotBJSCwO3SXJ6ZcKPkHa1F3sig9GxJrktfRpucK0972CVJJNjbgj76iIgj9I6LSvYGMHNiVIXzcxwpEtnSw" ..
	"LYyvhNeai3r7R6Pmk5aFw2kUkM9FUcIlTT/Et1HbYZTQUtoo+C1Qi930q8e1Dvquvg1o+Qs6F28PAox1pZNY7mUAT6nPuJ3jKTZC" ..
	"FRJEHTi1RtHa+ojs3xhrN5HnYotkFCUU571HbZ3L++ftLZB/6W3+mgQsy46fHrH06HsGexGwH2MvgNAB7IpJIACFa1WAz9Y/1x28" ..
	"CUACaPSEOS10oEgWV1hl/hcCmr1FB764osW1/J4lX8Nx4nIFF4XUcbf1+itbhP0GNPUE5o6KhxlbvEOGStJn7kweENuQ652wa1xL" ..
	"jR2s2Gtk89tyaU4jSBQ0QTfz/eo1PZMpOXC4iPPZePZvAn0yFXCxXIm9JoRuyqw5IU+Bu2BX7rcK+nwhABFehWt3SOsqUb4DbFuy" ..
	"ZEcFBktpLFLpB1ix2hwGBCc+7vQ+CkJTT0rpNrkTKncxv3JvhnAuxLpDEDWqxQK6n3Nbb3/+Z5B7Tx7gB1aX0sKY0OmIRe9l/UxM" ..
	"dgz6RonaCsf8OT88dfBEQS1Hsiq0odF0vdtXnvsyO8GeiKi8p9aWea4n3OtwZc2LcbWpGl2sKhKdsX4GKthXN+yw9vFE0ZyIkiEc" ..
	"y8rYUFryfmvsyt1d6+uzHAuPFpQi9URPBETLltEvEg8QE88jCHdWq2MpfYBi0YFXu5osI7KYhv32rRJNuBor1wzxRUFovt5lKMyi" ..
	"OqbMZ8190ByjalBNWcj6Vn0XKJSIsSZgVPdGptZTf0/zTq0urlzQj7IfPHfbPuUG5GLbG7cPYQbBDj+UL4WEg4keRBDn5bNxL80K" ..
	"iJkT4IfjlL3t1Zv/9mVCadxF5mskCuAbQAGAnDUBMnN9HGqpF1131k8Ss0oJUNDexl0Ngqsxm75gmV+6RRtaLm+aikWOPL6K173o" ..
	"bG7x4g5TQeBZatNL8j/8V44s9FlrvcIrCuWNxv9a1WWndmGA1xabBmDWF5noj3v8YbQyVwfHvaowAVMk2CsTN2bdj67H3b4XKEzQ" ..
	"zYSGyhMN2IRCYtIGfWNN/3RM/Mec6Q59ptgkQNF2MjyJRkOqDhIf2KXnQ2D0UJPrPnb2dKUL5K2elJI8MFjanWQ0lOnnNMIgkOE2" ..
	"u6Gv5XvKuNNHyNTAw9JWIgjIFOnWQdGpEmQrkesMjBkGi9UQYqA81FNz1qEounmgcq9F8OhwxrLawZfcbcETjZrd55KfMc22YLrE" ..
	"hZUg+2TOYZwkBhJfW58vDJ6hzERhPm8NYOLp01PDjYcP3EwJ1+BFgGZENqKyyblNfKFOSaToiyobqLhF589RbAK0+qLT2Z6SsYz4" ..
	"pfW4mWqIrCmRe2u6VmKVTg7tCb75pji2yGZ36wxD86C2X398IqZT8f00mkT9k4V42N7IGm5O6BALg8A5XJP2pqtaZhfCp79rr3Lu" ..
	"xShR8HCBnPkmzfoaAfH/c+1zluSnR28j7QJqO95KmSXiGcmix5Ws1BH7albDJgc6NFptnqQI0Z4eiFja5eiSjf1KsRXjXw+HIVj6" ..
	"lEJ91t5ptVd5KJrHlQPDIZHPpdrwxMleR2/D/jwFP+4Z1pXaKhoc9KA=" ..
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
