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
	{ seed = 672635170, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 678426932, exp = 0, plan = 0, hwid = {} }
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
	"qcmKQ8BkqHeCcVjNUVIvLawyAQln4jkc78GhdQXIdYMNObpLCGhPgnBwJnmy4RVXLYeGfed+OG4TL7AOu1aA+r+an0MuVrJuix+q" ..
	"s9Ktfj5/G0DwjWajccLlLA2LmEW3ZZsnKEojn+eZktc5aFWNz09MI9x1jdvDH3LYNb9xmTAez813+3GeKur7CcQuVTY7tSJVahbW" ..
	"/pbO9IvhzcuzGslr2ZxBf58vPRmMWczCYrhUd+FsgjNuaIo9iP2HDsJ/i3b4Q4AtX33+29E/mPo5R+9hxGX0xxbffkutVA5BUcx9" ..
	"jK+O1mzzOJtp8OpGuqlBmWbLOGvzrQIjzJIyy7WoIoab0XUaak80roNfcLUv+sW05gSD98/DfcWul+pu2Pn0VsBsegzoaMNv6Jnn" ..
	"hwbGmrbcO68YKsTcnlLEnDVJsJ/SFXTPQbWJQ83EzUjXC2Y3bkmm31AEdfQTszuhJkQdM2OZpfj6X8lub0+ALfDxt4GNCPftvVjd" ..
	"uU3UpZMZWKNPW/eSHUnmt7mYIURynSY7SYeaKd11dC5lvg5vkQ0Bv6rYv8bQYU30eck2T4ZpEoNfYkZx4Zjp0KHDfWtJeRi2YjF+" ..
	"ydWixzBiAWySP+RT8Mv35lvrhvlFHoBt7OUg+qBwl0E9hMypCgmNHOnbhQ1T2mWpRq6Gbm3ivCahfVSeq2UyZ27U7gjZzA6lKYr4" ..
	"1vZ6igv6YvQaB5lvAeq4Gi4/+7FtwC3z4+CzUqpKKFeWdVXd4o0Ksg8u6mBXpMBhcN0lIT7pga11j4s9Ye5vwuBLPc02G3nahauD" ..
	"+LWjC+1vL23Bcgq43EiSwoBZqIsaCBQfwVgSfZs1hP3lSkxDsSnaWb2Mu1xHw3j2eMBbMvklbR/7usyN4G2nqwepGW8ip/FrGC0R" ..
	"F/FOE+cxYClLVlbxg1lSCGxOsPJQsueu+jTu4Vdd0pl4nlymMqKoTSsrw0Qeem7VcCSuegkeQg2oVa4qyXukg98WLZOw6w2GPliB" ..
	"iroHSESaXfRZA+vG7SnpuXCXxzAhyR6QWIB2z+JJsppIfGCa/4Nk4lItaTxAAJ+UMXZEnItAzwRqCsYqTv/a6Gn46ZSHd9e3Xyh5" ..
	"xJ7VC32HTLUn2DZOvgcpO2fXst7sFC8VHhYivdA09K9uQjOJhv3jyPzZxN7ziGwnwL2J9jsT+HG4w7wzVq35OPJR4JnG35AxMcKm" ..
	"7nZD7ZHo0ZUCQPIPlYJZF5kBAO+WFc1UBw0ms49h4nkJ1q5r3m9DRrjeIa1mbBQdZS3FGy7vMtUF9/Aw4mHJWePd0TCzJyo+kEGr" ..
	"YDKvxzPJswManaIND0MkzmHHwvlS4LxOgSPr6fAXOr+KNovGco9aLYHAH9QHo45GpLBq8SPU6tZfdGHReNoUZ1pUzinjM/KkiQlh" ..
	"65iJUnNch18A5EDWLZxUGQYX/7cg5ogI/ApjHCYhhZM59d/kPBy2BqI5e63LnBZTHC/xwW+0HFn4NbToq+vb2WUC5uW3IyZE8KiL" ..
	"GEzElajKrNeLT3gbJKd0rXZA7BIBQ7rRuwIUl26AIfquZDCPLknyxMcSVZX2oJubqO6fuOyguKg63WBpMw82hpNzzHfH1Np5T5NT" ..
	"NfASMq3HPKchgV+xT/BOYOUY/b6YWIslPXp0XCP4yHJF7ch0jdOoADJYUG5UAiyA1AKbMJecppr+zI4sHd6xRrCcLkOUjREV6fb9" ..
	"N+tP2z7n+ySXTWJiUQjvGofM3Wl0lWlmjQpNvRb+drv8NR264YkoJYN4jV5pmbgU9jjNvy8Q/pOQ2fpDwJ22XWmAxLL0YgOYWLwc" ..
	"/o+hy9hCwlqhEMgimQLbP+DU5XdnfpplbkmeewLNdon2wL7DJqf7+WP3BO7sroyyrHSch11BVsCb86PQv5edoMR1uH5MEGd39BPb" ..
	"GGxIzyXY2zvYK2FFjLcdZhxIPkcVScBKjzFKVV92LkDw5x8NhfeHmUXCoKWwNAcXQEeV9Q74luFrVQXKo2nNhjLm/Wmb/Obwdnxe" ..
	"KeVZzY2MHsEUXko9Mc6/ke9lRu6JUug9mSmmuGZ/bz8zs0Rnt97Z0kZMYgqS4Osz5R2lcZkQAcUzFlvie7xnQHy+wCkFasgaKmKR" ..
	"Uq8cU+Sct3i5B8fG1SfiMXitS8/k66yluURMa8T/CY8LeSCHshY3d89IJgE/BZP3FY/6eAZDuM6nvkfbR38TuCiWcxUslvlJ2Zkt" ..
	"hnwkcsuougrqDjwbIsVOBYTS+jdvnmSJjCJrVjHgMEHvsKajaf8RRVIt7dmLLAT41GV/yyS03L7fGZSsX3Mm5XLu2mRYu+Q/Erxd" ..
	"rWIEOI9oUO2vjEerh8iSYSUlN6D/O3tsSEM9Op7wFNjM5ALWk040mTrVXi7ONj34YC6fj4oyjVsb9cb7PawwO0e62iqllGmBpHlT" ..
	"SmPnF+xvSBodtw2guLG0RuQ8fTI8HYKmAjskQ1HfXNtscdFIfEQ2sBz12em+MZZ9CtexQG+gRGaD8jFpzmoadawrSSzvYU3OSigZ" ..
	"uyFz5DIQhd9C470MaeY5+xoIVxlTFCNi63PdFSTM/9E1pkuttQRACh5agxLLAzKTq1gnPbtp1KCCtidAhqDfhTMmAkor6BTn2n8w" ..
	"AiBM+lwT26fu5/sIF8rJX/saYMwEI+y0pP9ph/qUHfcH/cGA5xTEdh8svhN8FTZcakgUtFat8H99E9JonYVOYJ30LJargttKNtJJ" ..
	"W4G0olfsFABjfPXSEe6hnfm1Ylh4nSzMeRlc3tMD0Lk2jXhQE1NdzuzCRYDGE7hQE/bFDeprR/dCH6b+YZLgccFutQM15M2hnam4" ..
	"xKh4Njap5Wf7qexJS8NGV5gLEEt13BAWCDCRGtSJidwBXLIYiyaS/13SNNSu/1n+kuDx/VwxdL6iJn9VyzVFGWCjeDYVab6TiiRa" ..
	"r9Ygyf8Q+tV+gJMz5gOq/UKH26+c02R6DyE3VPhC2oUsYkjAm8bE8MuEqOmrZKGhuRRij6b3wfz0iuK9g//v6JFiXmNmYA3s8PI+" ..
	"+VT1sQz9aWLhGzWFTHjd4+amQ7ZtS17pGXE5smz+/x6bho2kGee/WVKUxMXWAeDYP/Bz6mgLG/+Z5Oe3nzbAc6VJ9lOyMnrKtgis" ..
	"9bEs+mEzc7yNZ20sS2kSA4GOP0UOJwxpSy/sTKNar2Bo4PErC/SzejqCw1OXbt3Uy/2orYp+MMo0RaqRG6a4viKoAExbRIDZDkKY" ..
	"QXqvCwQlqbRqyLXIGXs+aiS6bKnyrq8utNR3s8XWiHRgM6ZSW0If428IHLt0YCDYWS37vHdkXiQbZ1QoHiPYfYFlm5FYAbWiCocr" ..
	"2I9l85CjQN1AlryG82SR3LjeI3IGLtKtSs/hojrY6wydUPs38bg+DF/zCMcBm5Zlv41lYf9G3SV96TBGsr6ESOzXWk9DOlefD2GP" ..
	"VzgbdhrSdKd8r4RMkl3BpOmW6WHFYO0UAcdTZvofV5YX0icXDYxb8r4L4flfEOkJEfdDfH+FXQ1VrtfMaoN3sb9tbCiM/mXXyeai" ..
	"umu1Y3BGPMfCc7V49YSGeZxZ9+oMpcSzxMQG2UyD5On3nsEogmYFboQa17PPzqI4KJwuCd42JqbEwVavBdeXPELhX5cVHDh3w+Vb" ..
	"d4QqSZhxzE/SmdsHwKWg3JwamuAPON9WKcF7u9i6QxIbynYv1DvvZsgb3pOWDkdcykb98fOeHmG/y/57OjeZr4TuN6u0UZDYhEr6" ..
	"k03XuZDyWF7rKD5qkVBhU/Ecb4kDpQewMaFfdkNQK6z4h05osXQElbSpR8LAHSEb7j0XUer4LifDDaywMZwyPUS/oKUajNNFQYt8" ..
	"eTqPpJSwBNmhkScVSU1UmuDZaqRB4c3RQUD3iPiFLuiEvnKnFmX0XZxO5fR4oUZushecRF3on2zw/PNncMts/1C5COTGLmCCHO92" ..
	"ahwz5sjldmo+tCTp7dfca4pvHW2oYUvGRu7SX1xw28U+toc/QvlFfKqnpbrPUFq1fHV+d31vGUo5Q9/mkXwF8K8GvzqbJhFEuMyZ" ..
	"HJfSWFUMxB3cQBKw6d+LVjwEw+HwGTUtnJFJbfwLjmIhfbT7+ZSVPjE/KXTqqeP5uiRwNcGTY5oVApK4SyV4xbP+iACmH/8fertr" ..
	"XIPv7ot7I4Cr31ZDXoEgBeDZFRRjT/Tv7PUGNAebdEQ2TBYiUTiUWhQzR6iRQ3IDpJh8RSHVS4sUlytcz1rjQ+t93FWitphbdJB8" ..
	"blRwO+1bs0kaBfxxgLAp7Pevn2Q1SRhvxDluz7UEb2ZlImRBhvLFsq2opne0n9ThhgyPcJvdjFTTHTO4rQProZUuu7+QqewCj7T0" ..
	"mapE/jMFrHo6uer4HsvGlCuIA3EcuyD2FF99oUX8DymBLV7MLZ3MhOW6vTY9wbzOZC8BeeNXi3qfwYxWgLDJlAuj2sWm7Eq81aKh" ..
	"iN3/djnyaGxltaxH+Ou5hb4mABZisBGP9OSmGf6itM/nNabq+gODnIabWJuaug2/gVNfbXhJA/wb8vykMCyEdcy8K3ChlDdZU60e" ..
	"aLFTr7qPLSKyQBJVseQ7kCpFeb64ZDYig6g62rDYfcYRxmu1HOVri5yuor2sVXbCpJRMjfMbd6qElFCGvd4O7I/d34OKhcQx+tTd" ..
	"FhPtu2wgvjH2ONT9Uwe3Sb6Cp2it3rkWpIKvM3ETMug6FXqGFvRlXwD1zWxfMz7DcNpgabh9tYHih1naPZAXS3UOEp2+BR5YbHHC" ..
	"CDRYCtYPOigEiweCgWE3YTofuHmMeH3HVH6RwIv+4NiKWu2rylfPhs0Vm3VAYAo7gVbVT3hbKSFIngAmC+HCJJEyzXh7iWr6xtbF" ..
	"KFSv72K6nXeXZ6mmX6La+7KJfwXCVgvqHED0z22RJ+LaBdeVqU1kR44yKFOCfUruwzdQMJKVrFUbgBbJGJtQDIO2zFJtsdMd9eUX" ..
	"X1p2FtMB0L2pBj9SYlweWsqWJUNefa49+/IdmUhmQ0CL/cPA2D9kdIpTazvFHXPuL4rMht4x24GyMFHPDDDdzd2OX4a7lzb95ryW" ..
	"9foCAdK3PuE+ZM+Krf3QLlj3hfxH0FnRhi8+4NCQzEhfZszfh5lSuA/6UsALdl9ykx/oi49Os57fINRCaQ7g5E4BtL4iKFeFnF3g" ..
	"2hW39jUK7XENC9kJA1dkR9tJLkGknPOBnYRCeW9tlPgZykleTbQl5uvTfyENAVZ+lKQonZqDRGfaIXzurTz858A1L7KEKRUWPJC9" ..
	"Dug71Auolq7x+ej2T6BuoO2RE8yee4ctoYJMf8oAvU0TWOVRcKiNhdLhqXrbLItZUwQQF8Z3qy/mmQxs+pv2cSo8e4okQ731TKkp" ..
	"z/+oqBAoLHUCOv/dpWVeHCxQXGoNAMxBZSwqH0WTV1nZ9e3CDATXrgjNFPQtcNeHbHD2FwlUUMO+Wi51RZTifGtn6YHbGlYxmILe" ..
	"pNA8zb0BdQXuojSR9xlu8UOPNpR646XtSIz3ito2ZEBSzOj7IBKZXz9oF/i+UKuchTknA3BKpClpqQ5nUfvHesZzVM0cDTvsRLUT" ..
	"tRzYXtexGrIEIm4US7NzHB1eSTX0TmdVQqMVMiwHMo42FTeg4pRHvdQnFcrjMKt262cekocGLWH7oY5pacDOx/VB/SRPWfSS/SD2" ..
	"URihL/TSuzVSjdwJmX2Fxh1bjXFzW1ieKPEPyU67mdTQ21VGhR1ADCfM4DGD0zNgj+bh584ZrrizGHN5EHWYSEiQGShvinIwtN+X" ..
	"2l+foPPZi2hSKiRKGP+sB5NH7YkFDUMXl3+UdN1saeWrg8Snx6zDoqUGkkPY6dl4mXXM8bgp/QOtMvKqoBvp7xdufEaO7DgdCjI0" ..
	"8XXwA+4yfet9pLp9Wjvpcwaq78a3Dnb+weEeCgbm6erV4pZozidF7P8r96UgLHCCR1RewNXDEBc082xsacSgCrvQSGKcPCGipv6S" ..
	"ZI8mZosrWlAGyqeCcVeekBQW9eER/vUj3OlVAKG0sChUnUKbW1xn94ak4/LT/OXTpdfhRpjsqgvEJjFicLZ8nv+k6d9R85BnjuOt" ..
	""
local PAYLOAD_P2 =
	"efcqG23i0ouoAmE4ZC7pyNabsNrSWp+azyM92rm234KXYLcKw7cUbQ8qR8UpcH79hfRo4juKf8ySnIZ7/ZcKsvJWsAhInxxHJFbg" ..
	"UIr/UE3bkJSbaSpfYyFjKgHKzD6ic0whzi0JtJz3owoHSCx8NsYdGcl3iosZiJvsCBNi1z03o/Lr0bTE0msnlfVvvI3dz37jXyTo" ..
	"FyF0+Vi2RNGR9sG4VvpQbMNvHJOoa3JDB+x4cnuVG9fV+NmMa4Ewd80NaDhdB8TZo+xxKAw9nkm+nIsUGgD3DERN4maUfkDjBwYf" ..
	"fS6AZvBUU5EksdfYSU0+3vnsTjjURGhLVsqXpdof/9Rz6euU7AOUa45ssS30JhM7Ebzbh3f+tT/uCCiVHrFW5fs3XafYyclAti8H" ..
	"PLXIehSo9HPHmkH+SBRmgvRORl9vzAkizAjO9vmvK/MWTeWJCkoDX9WOJqWxOtEuaxOYmHTO1qQIKKgmNXOOpuAwkNCnBQGgqP+Q" ..
	"xutjHkEO1pXNcxoDuwCR4k0A4qWXqgUeBB6gC/8EVi4vkFh0/DoTKTd4JISglRkeIxu4WjM2804DmBhhxaAfF9feb9K+ryohAM6b" ..
	"2Nfd64ZqT1SgalyMziASKiPqRaYRlrNCvmpClfxkhV4gGpUDrVR5me1BhVFfd2y8BeJ0G8KMeDQFXmQZ6luT1nGsg9HEyP3XwqME" ..
	"nkHbefGDkQkqATdSZEQXvqb5Q4NdMCGXFcwGOwrX7dCj01sOZ5b9YtfhiBk2bnjOEhH0kP7Yn5tokWIy7DRVZW0+bmeYZh8g5rJG" ..
	"91fXSWjyPEHRrRAtCqacNjEPUpRIiT3mvuNhQw4Nv2mXXeiU8kdlMuU95VJq7rmB+Bko1y2FZ+uF1XxSD86mB7CNUk49l8eXru6F" ..
	"Mpbgtdj9ZVurKbqIifzgxkJFYOcH+FgDCWwoZ0V/Kzwtm6zx/RL0QmyAeI7eRRIrFTIno12dtQz/8g00aVr+9XMGrHVUnZ4vEd3M" ..
	"GEmmZQJDOazZHJjwPAe3dqp8SS2r0QL86RMsD+nglSUIW47fXc3LCHOO8RzQTnZXJCV1xoBXHeLoh2Grc3aaO/PuHingccswDusP" ..
	"L2ER0Zk/AI/njoYyX2GEcLUYfVvtGK1853yTz5LPXXOref80NY4SubA9aPZu4SR4fzmT1drTA4Q8yf0ymbEfBsmruDFalINlQ41j" ..
	"qhB91fxlE7HbzsJp+WQaJiQPVLiV5XANhEtu/eYNp4mvx0FL46GPkoWWv9Cx++l6uPlpHTm2izorT14IWG/0INmJIYGzyILHMgKz" ..
	"hkqh/n29ig1VilqqdX4X1Qz3BHfVJKTsDG0FhDqeBX0bwQkHNP/xaNXubneJvUXBoB44NGAlfr6UidbLXIRKQL+S0GgJ9xpsGd6r" ..
	"Oi3TyQy/gL8M8Ny2Tvrfq7GO8VHk9q9brvWhbLVzwAFZbaos7CuviGeSBJcSumN8HLvfR3pwLKGcvT7Ah2AztVlFacRtC+gP5DHw" ..
	"i8JJNmrIrCfLG3ctOA3VvujCnWBEny0Z2bEHkfqvMLNRvlum+YPuUhbsu4wByh0tSe3fWfgfW21Kk0O/bQpixwfuMfYRBiSyHJu/" ..
	"mmiLvHwauR5f4SqZ3HJESLSPQIr9Cb4GqYCAnMR/6NtEG4bjNJezs2ZlQVHui84PM/QsqKCb7eMWrYQ9drFW0CPZxeR4LthTo7pY" ..
	"CjkZCe9qvZ8QO5Q2/qFcxtLOU6p2LE7DohLU0Yo0r05jsH50Aymlirj72mjGQvh/Cp5M1MKnqDNzwabkUbsRBDptk1/0Iw8+/A+E" ..
	"PjVODixrZG7Xo+n6mOot67aYjjBRRz0u6KbxhVNzJouIJernQjzzyhCsaLsPwfcGk9Y+rv3DQj4wl6ivThs4x36UtIleHhhyswZL" ..
	"5qsgGFr8pJxgDfI3TDY7nXy+8firs14vw2076xTMwZdrRgmR1moRfNxpkLxEMGiuVk6Z7nyf6EF7AhZG5oO7KGg/uX0P6A3XeeGL" ..
	"JSXC8JgrW6C8//UFK/7nYumOREtNyIVqvOxpI/1abnRSv2UEjV2MYhQVFlYfYEHcJnqmoj+YbVRGCM3/pEUrX2zox/FhA5/5BcU1" ..
	"EHz/7ZZx/H6XjOc355MwNrjiHI3ncVgSzsHSlAS17gqXQQ8CGqOtSGUVYqcJ+e8RWpr9bZPuRoXmTfr8iggLRtiusWvSqK9nHVXr" ..
	"US84nkE2XilfvpEBn1HNlvnga8vI22ATqMcP8JkJ01bCPe2/iqCiG44NBULSbzIZ5vfcLh7QOOCU/5i0ShZK36T4THEmCFPsXLmK" ..
	"aGA+1qr4E1WdMg+bXVBPADejqQFHwfWrccDZpgE6PPy2rxN4NR6cgdElsFvO6C6RfR1X+UYbqjkxwm99jbnqZjxTzAXC3Bi3sEhL" ..
	"CKdlnbxd85Uv1kELW+JMcnRHDoc8kQxg/fhlBUXtNVgGeCc5LYU4tnm8eFs+f9XcQZeXWAv+ybO90qGwSewHMQv1KaQjwc+lCmcA" ..
	"AU/bpy7/XCfzebv1FZAlN5VM0WH+Smg9ZM+NCfg5r4jfbeGX6g4VsnV8tDaofVLxDfDyQo2KOlSqsWyaLEJvYlZkH/HyrPxj/xZ2" ..
	"uFyilG5cSkJBKQ1sr8Wi9ZOC8V5TXtUcCoylFq+37NsPLTqvGaZRzOkXEb542FQ7nfVcr2xT54lIwBD9W+xUtP44muRZ7C/wL4MI" ..
	"LPgQmTCshOr0A2PzAosLHXB72lYdtqucjWJgO+xhaCS041h3IsBHWh6vMkkXBuLVQ3ifhmC4wsu4zp2WWyCOAAd9w7chn3xSfAhf" ..
	"P0+Sj6akLugndudMnoXuVHxeptIK6NKwX+VQcawRu6hRRNPM6yk+5j6xDWbpBOJ8jb9sbWY9D7tjYBWIu5I6Ds0ZbdNRCd0J42uG" ..
	"aCzLTS6RXHEsZz/zYGeNvls4bh6p9bU0vWZE/vL/sxBDvlnNhzjcVojbXCctujx2ltNF3IO/BDoQTmHEhJ0BalXEWKkJHxiJqRCL" ..
	"DwjClWy3Iy+96xsV4QCrTh6sBHFQyk2gqrTm8emRdOZQoLuEPHmuQf7ZIlq52g5asqmAnyPOFRZ0YnQw7d7Vkq1nzVRut9iFLePG" ..
	"oCoYdVWuKPWv7YXvlS2at8I+5+lU2CglPNFXttRT86LU+ew8l7L7RtQfeFxJHTf4ElHE6BkV/2DJZ54bEuTMtaPfcYjXjQT2VlbZ" ..
	"rdwa4TDBcGG3zvfHNIcxaSr6Ui4L7FNpaRGeT3SMfqRZ6lFBwKZfhQWcxPqRzL03WbNRYs/kjXOVykOMZcPkX8NU1MHEpQP9dIRs" ..
	"sGVGByvsf+TWtMRg76cqeWBZt2jbOnO+ghduOnkmz7k/DqIFvBEImhzVGZllEDd0ZXoH5Fkj+u+TdjBod/8WFkS87DHzy2e7zRKF" ..
	"ajhaD67Jb8v3iil+kUTesqbcI9SJtGAu8CS6tmlm5wuDOYc80e6YW93DtB+Zfo7Gx2F5Q9Rzdlnar6uYuPNVngYOqUu/ZPHKYL+t" ..
	"JNaf80jkmS16tpknfNFslPy7a8fAVFZncOekpB8VEtGrOC6t/1tvCo0CaxhH1U4MUbVzRG2JWmak1gpILW4Y66nEiAcxc2tL6Ebk" ..
	"+z8ZPEmDqyNUR2JxkcCSgh5kKRhKEksGoXQ3z6qxww0dxDMUH+3zNB42ttfb8zf2tDmyUf8kYy47cQWC1uMsoSNr3Kfh94RpldZF" ..
	"9paydI81JwcTeQa1pM18un06d0QM4kmWevMXcEEyofvbpmeUpKKrwx/ZitFcspuJh6jFE8AKjrEI6OwEODBcIkkfJqqZGHQUXdGK" ..
	"uHszYqjwkq9yPSeZJoi0kJGDGIiFUJwhETWWtsQ2cVKWAjuabNCbzX8eAGb9X+HWZW1Mnl8gTCKQ9AM/UKto3fHbj8GN7Jrg0o6N" ..
	"G9DxoCnwokSvTuzoRF+ilQqhodchwdG1MPh91mVp6PPZ5Fl18uhYBPqJH3HFhKAKhHNyRJtmQyfYeEdGEv+L/yrbsXXUT96A9GeD" ..
	"RqWLfXVWI9tTNHHJvUykzuioNFEUZ+UrOdQHFpvBtlqB4ezBGQqN0Hdt09/NYvzDjZybIrjI9w3EuRFcHnWCuB+uvQUHEagaRnZD" ..
	"WH7272+kdjUUyrhLkb+Nf2V2/Z+FXD2CP8jTEsU8P2yxIkEEQ5e4e/O5RMB9YKPtBqFZBXTm1c/kWafqCZ0aRaW6EG4ggtm8ULPR" ..
	"7C1SiSSRGO1gE2M2Fb5o9CC6BORB+50Z/Nm5/LXrfOOGpG6eGHdGnbtV+fO1IFjEr6RgFOxM5U1H2NZZReun6mP5M43G7Lz4Dndm" ..
	"ISo4iXa5tw8t2dvW8xc+h1g+c5YOmVVUbk5fmNaFh1TqcZMPqODR/rAOaI85DyeNUfVGCR+EHTpXXkvvLIfDksPa62UoRyrACwNn" ..
	"W64mnLdLA32SxkY6kHTSTuMZ13IzhogszFIPz3v/DRgS3CGQB3qMPP/yp/YkOm1MdKS77Fjs83AqwYFLuMnV8sW/CkCkcTfqh5va" ..
	"GF7DVeJ9sCovYqB8kLfhsYsHs2rsMR3NnjbKUILdINQK6TeCWFfekSGYRDWi/E2MdBzscTvrXKb02qBnGYv9KwNEkXcgJDUWLvRy" ..
	"RhbFcEUL3do+mXXei1NvOte0ukj+ZAVL7LEmYIzUlkv+6y/5FJqLRtV4YXOivBf1IOiY0uKSisn2SLiUM2aAzSc6xsgVqKat5weS" ..
	"UEro3DCL3QUJ9CuOUns9zVQp5oir3khUTbovJ1uE6hBt/cehyYZ3xBQj2glhnTw8mph5FZzQLe+oE7u/U3OKKOzWtng/R2XlRuUI" ..
	"4SUZ2pzVyMeS6gN+9nXB4Ysm0/111PMHwsE/KwPEa/e96EToGn1Js4Mkn/ZNUfi7egCt4vXgkniQUwHCzfjiOsH4CS8g4h2LVeqC" ..
	"fcryGsBUQM7yxrHTyVUrgAUo6K6CENwQQT5+UFvx3i+/+JIEyOTAxENZdC/lTlfZ0GGkOFem9+exkLBWpVuw3fyaoymSJkx+q+x4" ..
	"HTi8I18jDsAKGw7oz92g5AWM0wRAthJRdkyfP1qYNS5dzQUzhweVdHvMc/Yuo2Z5hMK/WqW/evD+DCuuD6aesGOsTZgLb8j4Kyl1" ..
	"8sG7Kk3EuwWyFiRyRQjglXdO7KIxU9kJLa9PrkJkrBbn5yYoHr6wKp3RPmyqyJLqu0/Nh0nJTNx5CAbB/W2hSDCb2b7e+jK1ETCm" ..
	"RpOSs1uh2xZUR9MegZRPbQsgjaPdQVqAAAAsIckwPlZWzgKQ0gETNwDZ5hSBNcKGy4dXacJmXy4+ypcUUxTaNu2n1Zz4WIGHHUcQ" ..
	"G/JNDPyZy18iPvFZnOoxv6JiX5ZCvNvqfHvqSDUuXDUZwLFMoPoSreW01fUz9+DKRvkJqmZTJmktyOq+fQdmIM7QiX2cX2SDAgsh" ..
	"0zIpRcAGrptUmYbOPMtiKjsvTaS6aMx5W/sVa3dQGYiR+0XzN6WyT2T5d5iXetvDXZ/O+9vUmArlvaa7vXHV/hyYIqJV7Jf19Xid" ..
	"XwDMOxzWCB4wuGm2dacNJt++lAUBHB4YMEgWJuD7RGTVLg2ZV3E41KwdoN/a2RngAIAst0QcoVCoCKFlfRoCEXqvld/N6lmIGOX7" ..
	"qO7+0gxHZ08kZMjp31mayo5eCSG/wIvUF/WkGqZcRGac0asJocTXahoBdGiDv9I3/fzU/dShSpxkw4d1r0a6L111jjPcoeBKLIHJ" ..
	"FMHa00RK9gS0YTncVBdcxmvGTzH9kc9PTJzhoEn4+RvVpqLRvuKIr7GGPgOmFzCiAk4iSW63d+Mv08s4q8jmeokiToBkCN3UIaIC" ..
	"WCOp30/q+TRUHGKorOVPD0vaM6xMs481D3sLgFPaqVgxlzjNgaDxICQ8/AQkNq0mqGi7Ud9BvimejoEo+8IQO/wngW84ZxL26Xgq" ..
	"ipWVIbYuvCV04kzXXF2EE4Pbs0bcN5YniEbNe2vkn52no65qNQOMFOwefYqJ1qPdGHcaduO8ISSxdSGf/rKHG1KfJqLpAAGvZNaO" ..
	""
local PAYLOAD_P3 =
	"z8g7XkQzPiR3MRBe+vP9qk090mNbHb+MM3UGkFkqYy2MZzrMyurdoAt1o9/9ldrhsMf89T9vIe+1ltZV6SOio3MX3xfEcNfJO9YT" ..
	"Wcyuz3B8hNtdpz7B4nwTopYVEgpo/mCSTXiOCC/a8sHvYGGidNNgKOkX2sPydfKFKHRpAFUg4f338MffLyZVb+siDOJ2A3yCCuIK" ..
	"M80WfkPXcu91FyfoKB/E7nK3UkM25G8Mr4eAgHlbOfsGCbawlxpsBZ8NV4UT5VMnxXwzLnCmGnPuD5F1D9yyVJIciLBLyraO4wxI" ..
	"rYgSF4XbIiuvGhMwnwL0nJL7oHR3EiUDor1l+j6LeVCSGNM2dzvnY3qd1SHj6RfOqw+J1HpVF1NSr+yR6yoUeTzq79u2z2tPdlde" ..
	"1og/GPeZjGuaKr4xuPol8z2IVkJkMdeUSrUCW/UEnzcOeDI4dGmrcTl8byk6Oi1s1ey90asxazIAgmiV12zut94ESsiT9XBXGWLf" ..
	"59UviE2uM2GQ06s30yS3PLF13oodHQG2nqvjMHiaSZkl7TnJ0myvE9keCfGAYAATUpE+nvFd3lMlcqJepl2bkiYkMt9lojgJvgx4" ..
	"SxhjKQ+y7UYoySImJ/K3vdWriUbWVNzmeZQbPsoV3aizphBjC7xHGvKmhbPXLAP89vVhwn4rPx9LBwpayvEXIrnLxfQt3187VSnC" ..
	"yheRBjydijvAMDwx3UxcaTlE4AavzGkh+WsctSKae5HBvFPYutEtz9B5dApJGD7ShLaU+AdL/kuhg0zlGw6brdzqrrw33E8H0/y6" ..
	"gzF90M/sY6h7xTflUDPQl+irQ1nPKfl0jS7toF7Ha2cY48NonqqNM2EQFbd2aMVNNQxYym+5LiAPvOJpHiEz726pEqJwX3y8n/XY" ..
	"Q0nRAfRlmqzY8zvPsKRDKrwOIw+bJ3JIGum3/dnva4m48ue8/lIf4nyaIGuTsRI8vkVmbdmTjVPSC1fAZ0C5QVwrxv/dttmkTSVh" ..
	"CE+QmErc/LLjW9YQXtl3rqNPeFf/K57l+ADv5vdKZszzST/8xRbPPWB5VvptQ2eW3Z5Ik0808w/aE8MzlhX6VshBlVlw0VShTsWv" ..
	"HuAa66bVylv9sGxVpW3CY1odkdJljg5WoHQUiryv7k5AcIox8j2gUbOkMOpcmBdxmNqeX5vQyss+YWCFeQs0Si/rpfYoeoW7zg0m" ..
	"9wfl2x2+sCasKAQOP5Inhq9vSrQzSnpjyuPKYzGJTvQu6i4CN5ypqA9JIzEdSJIXmV3QWtRVxthuCQqAmKfGDjBdWVGE3BnIAD6c" ..
	"RU1u+ejDjJE1deZWJNbTOGHFd/KX1hq7FwwADmlsx5QN4JitCpcWl/ZKa0UeYNziDQLJsJvMEKdGYsGrAOTcyTvLdFsoWbwaVUTd" ..
	"X7SYGCfL+Kiqi6ztH0ehs6ey11q4ZlFDV4Q7bLn7vkXs0n4u5NwUGVNIDSmIAkIcf1v14d5YwG2JWyKUbPyGM0qhlZT+rSmRs76s" ..
	"iSId94DAXk62VnI4EtxYAWCLJQvQQjWekjuqbW3mDnrkix++V6xl8/IGOcML4m7Xq3cWOZzkcijjPqBZ/4IJ+GA9o3qcq7qqGsD8" ..
	"Qjcc+z3gFshcKgxRPAOO7fThE3+vSKLzbySVcUpM5psrEZCHTUQTEGY7Qn5p5bekXbHA1Xb24YCHKnyB9zmZUF9KSz2FKMMQVYzc" ..
	"rFNk5gdlNhleyvG7QW8yPPv1kohVNIfBPiA8AR7eNV7FgXoAkmvyOXxuBXsoKWoVUquPKSkFYyhSMYJS/UmKS3YP1TdlqBcoixI2" ..
	"PvHLB0OJF0EAEEnY16ogSIDnSCdnYUOTKBNqSlugS3W1b97XefY5Ms03Pm3li8V2OyWmorsodHkBxReSGapg7qWuCR4MlUKFz8+O" ..
	"gLVfEcZgwX9fW6HjFm/CL1+YgVVnjxGP40YxLvVCXG4IfkDpTWFMonAGh6hR6G30qZZ9E1MlTIPXRFV+nZfD6lpKRyQE09bwDj3h" ..
	"GqgxSWIem38SEzOofhcqqi0KAGS6FqB41n/2/9bHjG/oLcu5RLBQgoTbju/+fyHWseBTs9j7DUr/KjU4F+imGYLEeLxM4aFGxbJB" ..
	"dy8y+mfcjm+Tly6ZF4QP6mdCVBOqobx2fIKmDzCx0zq+barbBw1JguuLvqOS8MrkhlfIAHWMAKfPw0+IwzeImydiHKOZsupWF0ca" ..
	"pVGT50eLToe04GCAGauYMZUDKHpVnaOU7ohFrExiuaxHPdd/VL6fekPxGRdPSg9euZcJWyLhUBxRgJ+nR63PGDNyRZE909Xsyqao" ..
	"nJA6Fzj21qG6C4daU45+BaK1O9pIbR5yic9N1D0bd5gY+XMxtxEGRh0UocWbhgH+1P1cSgjgOvUHczY9XqF2a8ywxhKtOHrnrLfC" ..
	"FctTltJVyTeQgBWvrdMwfcWkvTLf5JL6kAErTbEYipwLTSVy6vw0F+VE8zna71AHbO1xG4LNv/zijqRK5iqce4cqXv9+ztTgj/qW" ..
	"vJHk9vvq5ApyS2V/5dVic6SqcYMEa0CqCT3THkhDwyoiu9dfch082rDT/JQfo+mvN0kn2rTi9vLH1/QyJ+zluzMPZBgg6bTM7+73" ..
	"zr6M5eHGqT4MEaBJ5L2XF5oSdoX5KfJVfXgIHrAcKf7LZc5OtuavE92q3yvEsX+GbWlgwCPjH+SjAzZxcuPJgyZ32OuyIlKL6Qpy" ..
	"kPnS7kOL+g6NgzCc1z4DMLcP8ywQYIvvSMklcc/irRUuQgIyGY1FWWFbzutz9OhghkFm0hNykL9GjpY7qm0om0F9nB1vNbEeHuAQ" ..
	"ghVG5aK/v66kFF6BY62Sum77zaUIksRo5bShwS63XrsAaHQqXi/TED9pKBUz6rdMwgoj5b+gfH3je85NgByxQY5Paclo1II1h3vZ" ..
	"whHQwuBTubfDK2qwCBayNTkziE3Y3pj1LQB2s4Yy158+99ZCv6ma5UXVCMx3g4afzkLrl3PFIPWQZYs/KX1/5OD6R/Pb5CkS6XZW" ..
	"NQ36B802xPXCNUAOMYSoG1ZJVXe6gHLbEDdz7MWZ83l2+5q7PMuQwXe+NBWeaABZ6b0QJCbSaH906pbynQSW+z5nEeZs0HaXqscs" ..
	"dgha3d4zzFbvOo0Q8e3veiHJFpJCI1afCPA5qPo2QPhsSAxTTzCKXNCpNDqvsCYicTJT3NNOXKIhmDEtLWD9vxEGOjk5eLwvuoIP" ..
	"dNVHwrwPZRcEB2XET5MpoNPDCXdxYrMpLeEfKFhh5Q2qR8FDw7EhqQ0qnloihBBsxXWooCJ/9XChLkhFvxxiIu3YjPKyZGCBB1yJ" ..
	"9QH/OLkMuhrGds62ynHV0pi/EDXry8+L8wN4XRG8/RvpBInLEkCSZkOYtXOrE9RdyBVIfzJwWgyia5WkMzeAdB/7R67iMegS2IUe" ..
	"A+B3IkJ21K42mpU75YEXjqeIm/tIDDL0zONXMqfw4eJVyQEt/npodpNJrWNVboM8HlUiER4E/SIL2lwD2EdTi9ajXOMy1qfh8tRE" ..
	"Wa/zfcJUo3PsH+2hEx9Vzt+16wsJyivODWIBGd/iGQyNEpYL7igB0aO6B4xKg8QVkqxU6ZLQYHFmClPNss0On96vG0ASb7ocLype" ..
	"1i+a1lyMCAg+kZysWCRAFrGm8B78rvic9vUzbDez/PBJUja++M2sy/w8r7Lyx/NjevWvZMQUKVJA13KXHivaX6AHaKm05/U77/k3" ..
	"RfoERRr6XsKlR4MhbzKQ1fMPunmreFBnh/tlSayf1w4atZPeMJ0C47tzxeNrdNu6v7I7r/SMA+YX9pqT+pYdhlcy98u9HuSEylNT" ..
	"Mo6HX1JFO6UMEZGTijqD2jK464l55W3DIYxWNvP9VyUm10a7JpuqQDj8ye6+2S2bTvafCZ+YoCTdlwl1+jy6t8mYje/zf8B2dCM2" ..
	"d4dmqNI3tuEsd9NU6c2axLqozkcWgjNV2AHiYJ/oY+51ouEFXYOnyT+C6P/W52Sn6Ra3uTEsag25iw0X3Sj5MaSwXF53voVRXyqN" ..
	"xLgX5u6bkBNsJOoPE8XFzGZPssdcKK4eNwdlyP3v1DtUGFOZFFmaDYArT5hdFRgDy2lZH0+geg+zHpFS/OF6UjVjObBU5VTHVRB7" ..
	"b6CnoiuVhnK88/ydq2BBsk0xeC2GlWjnhqXRuGHxVj11f17/38VlnSaUHrRkUu0/PagTvOp2A1jH5A6gWYcvMUp1I8lw9T8V1Ebb" ..
	"yFRDKemkpUBO7BYZ764SNk9CGomL1VEF3qHnCyGgL7AP0pCWBiXgq4oR2dwsszVU14GkxR0Drry3CaZYXo5boRaGPRvPPw9aMZ9v" ..
	"x+3lfT7pnBLn5QzjvxgD+CppimEAc7XaB4Jpcm2PdP2LONy0RM/UH4vCkv6Aehf6aqzc8JaB11CvxcgECmzh1uuNE53sAmejgXU0" ..
	"VT1conuiE50BgFaUdgH5pk1NZqURIVphVBuTocuSR2UMrhnGTRa+PKo90wQQQtejrfObjWg2bddmhJHQcbHQW4bG51uGABR7VzYp" ..
	"c8ERB5YpJcqI/NDNLd/cCKx1chaiRKqkafvPwPvPFK/6ICNpG/G5B4ZH51HpDs102g0fmTM1BU+iGLPhurXIXWjek3PwjZjdMil3" ..
	"RwMUx0oayZEoPrcc5YylZ1zw76NA0kUA9Sjq0PUtEIo77NthIyNdy8+zYWSVu9Nl81L9b/Sx9NMN2keagAKHvuqS7No9wxYbnjEu" ..
	"UT3TgkWAOxpI7dajTesT2d9m6pCsHcci101d79IpwmPTgnI6dnlCO6K3wZeoL1agXabSPJybH03Ify1J+OGmD+UPxdE6jNXyFf2v" ..
	"0GtmZQxvUrrcDupqhtgXHnzMqweKUsLJf0zVf1vILUVY2aM5hB98KHYUOH+nEMx2K4jY/y3HZLwVjJBQ3ITSPLVB6rVLgcxo+A/f" ..
	"yO/8xl/BE92W7T+x7lgVXb0RDjYVGSo1EleNuEOAsTRMhFCgKuzwGG+cXx9iueFLoHiB1SuUelj5PfMBQTyUYjWKldGS4SX8Rp0E" ..
	"UKvPceWksMY0PUgQi5V8HOZqSLjPSf1qh5vr+6yc8OH3CshID8LRrSMk3CDtgXXN03BU24rUBjHF3M4CvKm7c3K7nmYiOi1CJkRq" ..
	"A30NxtK8FiLhbzO2lJiQnEWdEg7/29T1uLTKkV0fzDH1OIB8+Oq13Wl5fc85NOLBKECfLV4/3eKiy+d6/uSOlq8XVilhcxYn2Swj" ..
	"bFn8SJEUVKrjjhAuBLhmsDqJy4Bir2u/tD9lBRspgJ1BnXxM4sZEEMAGH7jjxMhwyryj/0tiuYVOApB6JzNrl0eB0d1ssoFeY5TZ" ..
	"FfE/Ab+bWNGcETqpD6kKj1byEsmMnfw0RO+8/t2j//+/hbQJSeocdGwrgXhOYtHeoQknCdlJsxeHmmQovz2N6ANAabM3DQenQFnK" ..
	"g3xIwhArTrn8izYtNOsvsCBYUhLLT8OcLxgx0NEPp00jCiCCxakPlPtD1OcO0WlT1zXx9tyLJ5KinzuqdUm2nyrGylfZsS+JNeMF" ..
	"62LWbMyGiKP1SbYiZYgO0zNuPKc8CrKDnhC31UvYd0POeDcS5iaNJJFhNMOQxqK845+fd2vNNt8KeuYdhXOYIZiMggzPBFiDYRnd" ..
	"f6ACHoCsTo3k2dlpZbpmTCbJW2h/HK+39Tfk6K6LGclvdHuXVbsdgEjgDrcVgeajPFKx/XxO+Jzw4q6/IzKWFuiVTG/EqnWxR1Kc" ..
	"pB/BWwlDnglf8o08iuvTVr+XW/d5DsrRnvkfJIDloFpaCGtW7hC0DZFwef+u5B0YoRj2N5RdqjAPrjZsK25C6+V/zyrlPDkIxuPJ" ..
	"zh+rKtovWJtKSXW0n2XpA4TnlxwWVQGMfLYMY8SBl7hsxZxAID7wQwSaSbd1saZOZoClxGOLCNB/eXYqLjGrX9caT8GNdZwF8D1R" ..
	"B2kLTICabe40hU8DEXmeL+dpyZRmmGSZhIQY+Ph155/iyQ/K0EaQ8LOkR8jTjMm7zBWneIDX7OTrWc+SEH1B/T5M+MO6votKFrxY" ..
	""
local PAYLOAD_P4 =
	"YjLLYzD2Q+8ThHnZf2vPCJt+bA06Sn5o/JgTYsDD74FlHax2L9oF11/00CyIRaYtfNbwwssjLPoxxYs/Ys9bjSK9+RqN/ZT4E+rF" ..
	"HHsMxwp/FHpMBO8YcPJziNkm8k/5LzgUznt0w44Q5KO7rBJYVkM6tCFc8sAGpqCuFHIO6AVa6u+SZbZfJ5PvYxgYDLw6+i+Z9F+9" ..
	"Wa8LbaYIVm1YQafga+kJwvDwMAQeLpnu6mo9IqSnikpUxOU1Jx+++OwCXO74MMUuji5QdqQ3nja+AT5ShHUvaLrsRVM/mVzAVwH0" ..
	"Mcoyv8NcLOMg+mrwT+slV6HNWFUBh7cZ/1eJoYo1ryWYuYAB5BIy1cktkSFGJh3SAtweVh7EGMqiS3i3yzfhOxKQ5liPYsWpoSSP" ..
	"9j2TYMAg6XbWPUlwxQheH02POLV2DJ0dV/+dr4xIfXx+Hr3cIDC6iOb7EzbU17huG5hBookcmmf2zL+k4u21MAVtPpG1755hjrG2" ..
	"39l2NEu6eGTwSkNeduA4f7cgtLYnp4uVEVXa1DFabm4rQ2Dp8DhFGut+3MkwVE3ZDAtE3dYj1mE12a8U55TrwMyQnJCQVS8zEbbo" ..
	"mzlZRnpFUlNZNYyf9qSh6A0onyrcklqVKPMy/PK5npR/sHn1aeHoslHyorBaQGpyE5W9KZJ0suPfpvAC73w3jrM06wxbHRsiVyCQ" ..
	"WRzZCP9LLd3K7Y9s8M3meMO9BXbxJSPvngz5jCM3b5hmayNj7KIhZzqeskAH+T1KQkttBh0252V+75a6pV9XxPx18gWwA+In9Gjc" ..
	"gF7pOI3bYikEeNTq5FmSZDb8BDBlbNGyltwowBaFj3yfXf+YG/fJGcqecCmbhlwWPug927BEaRwtulU6SrzrKh5jjP/7U10fVJpj" ..
	"240TMtvzE15n+mqmXnIwtaojQoQB9li8on5QqHCN7MSikKJ74rHjZLXRlL7RtTvN2pf8m28763jpzMT0Lk/XTJ/Q6E9XgIz2e/P6" ..
	"St5IyWWbKWG6HCW9b2wA5faNR48s6BFewvWTMi7rtncY0wUKDHj8jw5L9fV/oG515XInB3UXyKpl1psydQqFKRsPTLhTY7W2s5Ji" ..
	"YBhk9xI22MY81S66/ULkdAU7Zi1oETyaB+jP2G8HyFtWTkfxe67nKzqEbii4SwD9a3KGjkwuemMey1M7ApvYWoC9MQPbv4pwaH+7" ..
	"XxEwqoEP670pAAIXWMZ2cAC0BZAuAJWtYLeIDWNpKLCFwiPORbOJFBykdATQGDNFaiLHOVmmLXz9NbvuQ6Cqrf/cu/wW4G5ot9+d" ..
	"tXIsDR4lHLNEy9o1rwyxeRJiAlLMkY8NOtXSSwaAya6/gdHpJ7r81L54/qNqFRKGUOwZTn/n7PQNhhLeG3rUfs2KGKxcnebNHuso" ..
	"WzdI/n0tN6ATt1FTlSYoAhjUWsUFwmBB6cfJIKBQ3GMs/S1OKraQbBoXPyOrmTOilaNwF1qZbXeQAaN9hdDFSJSnoQfTPTwSa5tP" ..
	"3N4K7prRjwURPWAwkwAGr/2ImVQDUGuNZnZUjUmXpC8a6UhvxTpJpnUC+WbNAs0XChM6Ew3pjeLpWCcZJzYRX26dEiHR7GlPVxU+" ..
	"VdIxjOBSlB2WEey2mtUgSvMiS7NtnqJxTp0GBRbZtYQQ67jdg3exNkJjNIAIk8QX95iJ/o19zULAe2gB2uz7Wl1lrjJCUqbdnKdd" ..
	"GNlslmNCvT4tsbT38BOBFflthWNxXiP7jhew9LgEHsdsS6J5JtYlpYKiYlmZS4Y6cur8/H45KpIlSKNJ6k+muqGG6rex9PGtFxBY" ..
	"UqzBelzjP05pQrq5j3bYnuqISHJJ85Xdy03H55VnAG9zEtgs29a7n+wsxDwEHWWV7JBxvDb04/MRO8rviEBk6YGOEEN8yxOtoela" ..
	"u3zOxDDwAL5L0JQOSZMuki0SaxArEWGpuCQXFivSLRafvD9wPdHUuFWA1lrSoXvEelQDYbZheSx7MptOWVtgkc6DmNto+tvw4sxR" ..
	"HYGnHsWOyiZcseCcUW8LVC0MbDf0gIeLz9zXqbStGBAarXUegA0m1bPzFhi2Z6zkH/eGBxVkU6Xk7D3gE1ApVqk+i3mfOGwnFBLM" ..
	"qBPUf//4+o+m4d21EGXlSirfwoRM5TJJxk3YYAes1+UU5HKtCkthaqZSHRWscqFFTUE/32xHWIhtGNijnCryZGQipIJuQhCDBPR5" ..
	"41n6jcrqSvlDsY0on9OR307xBCbaPktKxEmN6Smm2uc4ZuBVVpoLvrPlZV1Oje3RaI1dRzLK9EHHagvQfAHzWLUGqsU4STgaj7Lg" ..
	"gnNUP6xYemJ+FuLFiOoBQDlulkydcDwQT8ZBOsdEnFfXqkDpqPLhwleWB22Op/OjBqBftAQklaTDqsrTGGBg6qS/VuPjJHq4xDGQ" ..
	"t1+yKi81h7oIIEzMkAGrE840Mo3XpsfL8r8UgOUpVfcuCWRNESwEfAdRnZ4ppZlYLQQBnrXh2YgwbJdDklx0mQrPPDJktD/I14Iw" ..
	"wkNwOGp6bMcHTzIw7DUmNS6/MjsLUt/3iG7X4FfqTqcOV/i/+QncnF2IHlGbJ+LwllMTbd8B4NnpkRmGHaPTQ9nL2K3KRloOY6/I" ..
	"czZ+DCyvFkgboOZd8OKL0K9hxBgAM1Rc6NV/Gv5DpE1SGZYuKp/v0IJMNqDKOtBGuLvXgcx5rJ1fqg7ss8itQDQBoAufKG99unbF" ..
	"hdhMCmdsNcM8I5NPZ0trz014BXMAArVxukQxwjgPOb1U9r1d2huBCw2LOqem+bTjwBSSV599rG76cCncQvVJUiY+9xLqnQzGWwNI" ..
	"wm09PeCP/yx+46rr5Z7wR3dP+qARSSl8UB+DBS3q154nyBizl5DneLG3zpWU5+LdDTROaYr28F4Mn5obJq7uZzYNvh1nyI+4GsRC" ..
	"dsYWYKfQTLGBEJsR6r8FdjR9Z/42UT+DNJthEw7waEHVJ6FUbSykkWkPGe6QRTzsFF3w7xZONjJVhCQt/FWIB5xJokbJgzSXZ0km" ..
	"zjCvrte0R4HWg6aQi107jp4Y1lHZ2xgzwaA0YdN6F5UG+A/LNPhwc7aqVa/7sYu8btGO2O8wIIopnlF43NAsiczLQPO38rSRrHqQ" ..
	"ailznkMsciuU0kyplQAPBAgXIeFmjBZX0XQbv2ae4jfUU7ySOgOioGyNGVWEmeUsRRGn3Y8WrM6P9XrRz7PpCZm9uziU08O2r2Hw" ..
	"M/Hcb6+TP+tB9Kn6MHqKuSHENmMdQtN8qKSHjn/pT39b01IXwNTYX85h/bBZ3fKMua0iOpH4OEI0PWB2Ebyz9HQ9YOAOR2ndEM3R" ..
	"Y3b6tp4W5GmClQQ1kIuekLKSgUJfPJwFCEG1h5MOYplIK8csPYGkX7t2OQ7nf3pB02BosOXyoSJ9L+HnYIr5JE2z5UqQ7Fv+ugCS" ..
	"JbxEMTvNXoHth91Eu+PumH1VBfIIRDuSNRX1pRpTkwYax9L7KuClN+dDZGf/QYyBs1mkM1GvLtkOKFh1+Ibl8ejS8f6UormPm0WM" ..
	"mXp9rIcvYGto+iVATlHBcoacPSixuOEne5Lsx1/nlLV+GuUHJrG4WIKeWdgTjZA3gHbxi0JrQTLH4jzYGR3MX5S7s+K8IgrPRckb" ..
	"CJrmxPT3RHRtWTb4r4Qwi6qI28Tva71Net2HGnmH3rWB6OpLU6/69bDLb4AZFWZOQKZ4VLvn6N04S4UEW3D7kg7lAnXlE/FWjV95" ..
	"Ydd9udpjeYpYONk1LVSSkCbIZaAQ6xiK9nFc3OEocBPND3lO25+MqauFzezYGTWT790Mopd/f/qSnTY+2bZSkugTlyudoLNkjJ69" ..
	"2aaHlzrG4HB475B9C5vgmqDRrYMiin67CxyVZCx60yvckH10fMGZCHt0PjU+7gzKB0nrL5KewDxx+kXf8dZDHC995E/YAQVp0YNb" ..
	"GHz6GtwtFpuHo4S+9kgTKb0uvvzoJCLeaKZ10DyCq8QfX8b0PIOkbtA+QHFr4FJstjjQeqb280AUUqTxJ5FL9jvck9/Tpg878E1w" ..
	"gsJMgEgoFu8U1vlBJm3qoZ74rhVqBhPyTk4S0yArEIavT4fgWOdvoApkwBgqWitysd4k/FaPEMH7Yh5+PWh5QNeoHLlL5gMih5Ah" ..
	"ZtZMTCbSq3Llvdwu0FtgHj1f/jxSBOBI/2L53Ix7cs/5+QZYUf9R3L6ssjGfI1zsdlhViunan/0P988UneYs41WctZECv4UsBX53" ..
	"/stoYsg/DP0dDOw5UY+qm7hkTUMrMjtQVWI06uyp1mSczr3dAHVG9GiyYBazpbbQ+8CUYru66QAGzapb4ANKFkhDFQPA2AU8AIWv" ..
	"hw35vObPb6lNZTCadW2SW4N65IrxWZjf9DmTrtDpH7Wnf9Ard6Xy3L/Mgf00+iUp/o+r/addgLP4sQ2nYk8G5vm2wq0/EzCbKY21" ..
	"JPhIvJvZObLzyOyVzBK9J0b0Bh0GBAbYLLB7cBnBloH2zyf8RPiAbhxM9fRKPo7oZFtYZVJ0R08W2KMVvanQgUROWHWw3zXmwOgq" ..
	"9LMekItQRHcrj/ayHtdMZSR9OxqM2Jw+wzha7siJMIxRUtsK0BSOU9ENuOQCUNEGauVlaHDdXOZTmXUUqoX0owGiun/bI86j9vMi" ..
	"y65NkU/f1P5OboGL6PGghBMmS+d+ow+kj0Bhh7GevhhUIe8KMcDGw3FC3xLJNQo0dX4pNClsr2J142pxrnGi3C3fybVa0+xg07hZ" ..
	"jam8z3hLWeBU7bErxz7RoA6uvEf7fsSH1JcnMqz79FPW09Ge1+yQuoGIw/LRUYja/gleBNI5GVfij2oPGxsmjk9ggPKTk66L94li" ..
	"dq7QAOKWWX54s7QufyB1tUBq+csoIAa5MsQkzsIpl8pYhiEErPs7P7IR/GjN7Jfgh25JDv6CuKUaGvkR/lWIR5aoIVK2wf59wDTi" ..
	"ZDcbRkIxT2CCM2x2RhMy/Zf55/GVn4MhAdHPsaTi+7pmxu6/lPAD3hjfRx9VBas4ScfETFGKjpASti+cjZvg367UgO9BjCtqVcZh" ..
	"6XRmq4wVvgGWy8cZSHblfoewVEE7I7B6698okl+dS0vBqWKr5Xd/jKRp1Z24TZE7mpWwzEtU5lXZCToRmFAmh2Aef/A6QCeWo0/p" ..
	"dl47TaOjtdQmCwtsd3fg+tGs+NEQsPBipF94TvwLTi2M/kCiFhcIrNbwlTRFETVI5QYgEa0QEqSSZ97iAcEFY6+2jbz4IZL/nSDg" ..
	"sDQ6sA3gpMyj4O+9bpeH5oUmf9/iTFehV9cI8hw8E/jf6CvCSCCq8nAltG+yXW+RTFLl4g/p2O++g2+fHaKK+wh8B7FW9AIgj4IJ" ..
	"bbeMTCAQT5RAzjmqJfenoFQ3CA5R6oXUyZE6v/c0HD16sq7WLEQuCx1xPazxRlNRm7tdVUnb7qgxVcJ2usvhRhY14WybJ07MVOpg" ..
	"dJVXOuuFuBk7i7f2aUStDKrQ0KyoxQAmLH3sBKJvEt1hq2OO6iUMKUpdoi2sIWltn98EWZ5JLF28wuqqfTh8DmhD5pB0J1mrI56I" ..
	"Uao55udrXR2/donlxrBXEUsjbQ461lzJ7QOBjDfzEvjy31bTayxzxtSB0bIWlQh0n/xRl2OMasy0KP0I+urPeaxkj1hcrSCiYJGh" ..
	"xqYnlSkGC0L4WPFDXvdnNWUsZiPa8T8gYH3MzvPyCkKzMZac1SIGgItiKffUqSBq/rj0m48W1e9AVefETKgYnYIo6LpCdMMhzqrF" ..
	"hPr8/H6lVeIvTQo42wIFgPJnES5U1oG7l1Y5sHPTq5msLZl6fSYJIxxEKD/6OpjxrkLRlg+LBKYAF0plgSINiivXfLaPafg4b1r7" ..
	"Wc9nkBfnVr5rUFF4Bopjro3ZA+WLTpVhfwTK+qjL3bR8kkhdivcyCVJupR5n8UOt8SB8SCGng2/chm7xZkfPv7/hNWP3ZImBryjZ" ..
	"GDOAwqisY/dQ2DYJTdnMi024v4j3JMim1m/+WuRoiR3rAQVnoDWYYEgUWCJnE6/QxTbYM5aVkcOR8khrUMeAf6Em12+lf+7ZgRWE" ..
	""
local PAYLOAD_P5 =
	"ov0Layc7iwpfWr0XPIDBSq0ywZt7GJn/Mu7zJPnUTzvIWHbXhmZaSfnJB4IYgTBw7/ZMmaIgK0rTQtEq94v8WvzGJ952kpyMo10Z" ..
	"dasZTjK7Q/nyA+ITTgHUqf/3CQnfr2xqEC54Q7yMMH3fxoeRFN2Jds2FL7ZTRRP6oFmcG26jypkW82lwWobDSlwr2knekqgDtAMQ" ..
	"PA3S5gi2rnlhwZtBn7ekvi0Cnset0ZG0q1KCrED8zGRO9FKgam71ZVi6PWUMJC+lTnQpoGNgV1OxEBQOmR/+khbIn90XAM5R2+rY" ..
	"5MdW8UbjXGxO6FUmBzKCAmZDHtufViy7SHItfQaZeL3ntZwhLokgCp24xgERtAlPWajDolaWw/s6wgsXgYVtgmtexRRU2PnMrvFa" ..
	"qjgI4o+VQEsEqNwz4Abn8xnyLc12WZfQKrfm1GVsEVEVdEdWN5s5Zs2ZC9qbyAmulRIJTnySl31B7+IA8zNsdrxTwBF0hvO0gTHE" ..
	"4h3i8QPvqniFW6fYCJMSDlKnhrBPz513Dx1/9ab4yntibHdFbtVwV3KX2f3g6UwkT+uE+iQwxlnCw3Lrtoo/l/Y37H5AJF02tzP6" ..
	"lh6+gFcFbCddNc08mIhOqu5/9J0KcMqerrpW8VCwoV67XsJ1DI0roQQsWFgW4Tk0DTFEyxiKySxgeSsS9+kagudHF3BPtIO9x21Z" ..
	"TiBpYpTjEhIep2lg5Ubri2paeL6sVjZFEkXdPGJVJEeojC31CpgdkRfai+AFx+QC1GCbKQYk+5Y8lr8ZDv8nqFFaVdQyr79Cad2O" ..
	"nAOWp3UDRCrsXxRGrNQR9uvz/yrfeRKzMc124fZGuTt3Op9jwHnWAclqz5kK0G+rr6psyuklijcjZ4zmpUVX2ZRNBrd0o7uiKUu7" ..
	"zwQCoUL31fLPQwqtM4kYn8/xESgDSVPAgVRQBfqd01fDq3FNhpM0vYcVJi8uS3a61+CJrv5+5l0OP306kTWVV7MCDCfaLvF2aLwd" ..
	"1Snzef8X6dTOXl0D1q3SzUXquhrod64eIrqQKWZh+5tzTdDKZf4OSusIld/4OA1Rj40wNS9ZgSl32LzAbhB6QfPS0fd4L4Sg14FY" ..
	"PUKfw3QWBVp7hv4vth3iZ9TiqQdOY/V5TVlBVFCj1B5gFAZfo1T3DnAWbvxdF0XDRZylWk//+YKBvFhUtkPiQMphw3DEr22f5B8Q" ..
	"SVjKB6kgUh+jSaQGAx/kRonus1NDRXph7eq7LCq2WNCIu1+P5C3KaShYI00a02ooNPriCE+gSp1V3TjsFqtuA8jr2ekJeZI7mjjK" ..
	"PwfGSH90a1SNkn5VRkavO0XMhmtVQyNWcSSG/tJCbNFLpL+L/RAwnBXT4U6lth4+xixFuO4cfZB8KdxThIkataUGtYjQDTGYccVd" ..
	"arsMLfHqxVOM2iq+vME+Ec2JBLfjb367B9zwPVjnhPX+ELCD0Mp/OV7QebVVcuZKF5dlk5EyrzAeBMLjm+o3VwbvMin6VxtubAUX" ..
	"ZseNyQlqVLOo9uMGQXRQ2fySBXBiaSdyno9tngGzwLG13Ax7t7iG/vxvFHY7xUi0KnNmje7zWtiznwfypuSLqZJkHPU63e36pfLh" ..
	"YuDcxATy1Wza0kGGBoefdbtJLcawuobhGgrBlSkDtD3F4JAEKpvmwa9qWyxFWSMFcONPkbE2wDMnDk+6dKG+6RbfQvproDAJ84sf" ..
	"Wkxx8+KrRRFNayma1IkaKqFvuIu/pHn7XoSwVR9QrzAKv0ZE099Jprl0GOJwOad3FnqhwZe3miJvhHDUroCqHLOXQD9/tQVWqbZ4" ..
	"3/WXU73hGctq7LISqU2fysJsezEbORwVTrhXGCOBd+czvRZptub8nuyRgbcwSVduDAOnpHAoI4YgFfoex0Yt+Ra0duWSn6OcHrlo" ..
	"zJvjhdfIurT/TdFwHHSS2ntaz6ikcYgdge6nraepPnFk/EC38BH2xmuPis7n11tl3GodgMSpsmXuQVEI6jgXGuZmP/77d0c+RrLP" ..
	"fK2rdxoyNYY3C6B151FPLuWHkUCehq0jZcWIMgbi7Y2RA9TJnRvjprcxcJKtNn/5fzYaQlftXS69z5C5xh27RkWwNREebAXGvg2f" ..
	"1Dt7UrKi6TDlryTX+WXEJsk+NG/DVyU6YqEohbBT73iBLVXCQob7TYlOpShsDLnR3yKg7Zl4Z5fVEpScDGXvma1vpfzSx44xmrGf" ..
	"tmlgj9Co92J1UxzoCFpscMwi7pMzOEQnLo4Bntck3fVns5FEBB7ReKgixansshmbIoJDnNbv/M+CJPBcl8ESCAHC4dTvxnYIr0jd" ..
	"JpVFhBMJ1LCtmrgyBGTghadmU/3IAH1Bdi5GICI3FXsK8VySPJmETAtz58/Jeh6zA60TXxuR5fX2u2ZxtQTWGUiO9PRpL5VMU/fg" ..
	"Tsl5d2tmks2YawNqj9lI0wU+2G3Qa/YCQ0hFO7JBzFrNIA8tnDQUyNwvPF5hHAyOMtdWfR+2b5Hh0iedbN1ULTfnJl42GKSlHs5P" ..
	"nBQix4MH57t7Gf7MnjwkFcw2slXU8Hz7bBM/oGlEAqPtTcMOvsR9bRKneVR1M9A/p1L22XBlLTShquaWNIMhFvXG86X+Eg+TsBxq" ..
	"PhqGaZB1wUXcV6/b8AX2Es1uBBwoumKh7Nl330dl/dGdkXcbffvataYv6YDh4/zSPf/+YVu+bEeO+ZHqgsGs7skkBd1AV3IjA3ZQ" ..
	"gPUVAaBm4I1DpSqmRx91bPZa45ktzmY0BiySViVvksFJXfQAuc/3SN44eRRSUdrd3ErEhntT6wNsVwqYOjc2yCcPpewZhOTt+M3p" ..
	"xcKnfkIhWS1geohUWbDa0Rs5+Uz9lP8adrFzgOPJxecNCAV5lt7IwnHiBkXgdzZFUTz25HFdAJomPs0P5TZXQchhievJXoKNDRE1" ..
	"OfwfYEIbhLES/4NOyVLClXcOJ++bdQoDnAwsvl+7fGcC5Ivvvy8QqUhcln4qjxRxKm4EZfCTu9WxbASqoCJtmTFe8S3MfPaCK3aH" ..
	"pNwe/QdX89naCALosVSLv59VCG2UtJYMpOOLCcmNKKc/z1F5SaoCEtnDQpI2LWyQXv6F4QqD3N9TRd6y1Ks9DA8Kqk2qSvCYEmh1" ..
	"o7jjP4OmTqsdptO86/3wpiwi3+kTp7bmiznxmACh4f3fe1Gyt1GDyyq720LzjAIS++oVN2PdTKle9DidXg3jOphRZ25BQwIVTz6S" ..
	"dIYcGJOaox/gBy7nbPe51qxUQh36bvQ7QdfrXS60SboM04MjUpn4tCe0XW5eonwZ3/IiEWft/xf29PRRlXJcv0rw3tKciZasigOo" ..
	"k2xwqGW+AZ3I3enUnCBlh/uFe+MeX8CsZ5YmFJbFS1fyBJAovFoK56K9TVvlkdjxx4KT1etBC3p26cuY4KGgHHZoYK7Bz2O0KzDs" ..
	"wD3OlIR7tigB7rbLGf0tIw8oUwm7EP4KB9mAzmocTN1N0vOxQdxyb34td4Sl7Z6vgx755yizcgVR6tZZa4WM0AdrahUiA/bFY6jZ" ..
	"OExemX68Sye+5bds9/4J2SIimJFDv/VLYE8iZ9ZTegLwmdDfcNKzZ5kTsDbYlNg2ueRAw+rh11SgJ2IfbyOLGYboM5lfA8DGEgmM" ..
	"Wtg8uwjUIXE0NF7pZMpuSbqvzVJb9LhXcuy7aWOGXFnev4GBib3LLpjllxI54fPKZjDyuimLZNjnNhTVaReDCitypQBe4xxZAe+g" ..
	"2Hi9w64uXO7jhftD0Gq18ENbWFO3n0BwtntAqos3WvDEW0pROe69+IOHlnmUMgRs8Odv8MNoO3z8xQZW9BoryiCJG3pYJdrUzx60" ..
	"wNDxXDBdVgU/5dqT9nfKD2gzLRSZzw6Z34uQBvJm+eh2ePuhysIDza0ofJ5p8OrpiilHlet1iPoclbcBP8V1wW2Ph4H+5jIQ6Ont" ..
	"1/x8yHqGr7tc3hJ3O2CbM+mAPYZeFEe8SlXLJGBGun87emABcq3k0iYdhNwVFS2Sj8WgKjJSMKv427qoORUBOladCA7bHqUMhz34" ..
	"WDFuWH5Vi1mfjtaYXR2KTgwRbNk61zVfHjSC8+tkr1VCGWQcnnmYh7WZa5aZOl+qIpR2NpWrmwQQgHuq9HvWTto8n9N8B6ETQ2Ac" ..
	"O3owdlxLWnNKwKLt/78OMzJIba4X0yPiSwgz5dFdpWaBpUJD2qdmT+Tp6TtVoDbbIx+eCObLOC7mroGRlTTm0x99kvOb4cWf+kbQ" ..
	"XG13wculvxRVC8/MQPSs4x04Qlx2gApH9gdfVbdYjDFHqVbrvAEGbC0nLZuVa1+YA1kt8ZYi0WrbEB8/xi6wGIW5N4hli1DycA4F" ..
	"1yi9fIPLtVVC0EbLqpvjcOVwmYvgxAW4Fid6jevOoAKOE5kBWSwspDcG7mCGhfCy2eltG2vJr4ucWeXrFFGgUZ8sVnkDkOxxGF+A" ..
	"ZVuxp9M0IeEl9IFebHLhyP/TTX/eogJwXwV2pAGp+hoAQDtfHcP31TWHmcmI0ewCj/As9xuJn+gKeihteFxfik1gvHN6pVc/Dvvy" ..
	"ZgSk9kTewDIW0JDAyGsSPUlzSThbnLLcNveh93oqcVjbmuAHRaIL7f0cwCh9w27vmxZ+2eXrzYnjWZi8vdY0lWP1XYtRDCydy4Mp" ..
	"2k6c4Un9e/2fpUSzxBwqtRiAG6pDsejuZ67UuBozMmIsnj3hsvrnV7z9pVTiAq7NOLxl7GpLI4PBwuEW70/t/RQUOBNmvtJ2y+rt" ..
	"CzJXNdwec4JRsLxxTq1gNNEGvoWoL933/XHuB5bxmBU/qtEbNVx2+JfAHneJ1y/Okv9HDQh5EDFCzzMPdi/OX03ym1fZTzawVSQ2" ..
	"c7ZTQYIpBZQkynJDjBNVgw1EPfmuXzVZAOPAWaOy2TZ8yFrdgHv/SzBGkW6yKo0boQU6d6mVoim4EXo+NHdquUQvGVOaVfEiPYZM" ..
	"cIF/jcxm6o81mxR8nDfYErauBqmHn6DDFCUbo8cune3F6643iKMYbBquJEPf0GN9SrPORR6pGO7gMk0HiJJdnbKpYqVj9lVzbAZ6" ..
	"iMvuqltBNjOZ4UFFYM7COAWjqOJaC/LEDFe4GGtyQmBway4y595L+n4v3jRV5QCx1rc6EonuyJau0bn+JcUpt3uHKj0amRWzpjiA" ..
	"RS/Fyq4i3/qjT6Ij7pHQjUAT0l4jbsef9EHAfAYm5CVihGvTYLgH6Jf4/7VTTewaNvYKOk6A2Th8Pa4S+UiGts97hq6brT3W7LeM" ..
	"LJn361qoyluPRaTvi+eo+XPrtscVcM6bkHftiP/QjZG56+biviK9ZMifKR6wOvnRtL5V1NCuJqQm4D96MgjkgsA2dpOuocbilxD8" ..
	"SdIlfB76Kh+jHA5D0rIMIxGEcCnl80YcHv1XAy+T0nPPq3tw349HmhNEhRNpN0RDhgOhiT+nfD4kpoo5xYoQbySr5C5kReR9Xlt9" ..
	"Y9w7UFEXythHfQjw37gQ69/+6G/556gYJcHsOMgabvskVaCCdue6J4opfd1YNwseubruB/tmprkhuAbnVVQGzJDp/eiCgRH+RFNQ" ..
	"pQEXoKlWaDmTP/mshqt0lS6tDawITOiFkrHFCBr3PemYisslGlcwuWQ9jOEsYy3lD36AE54i1qEOxV2Fgeve8t6VO6Y4pVuzvvu0" ..
	"04SRgEfTPkPxV30TT986lwFCoORSmB78tyQw+sPohTL4ydi21o35ckLfzZGLVYfs43vR3ncwF4VX3rvga6OhqP527oxAg6RSVjtU" ..
	"rgFGsVSYQTbZe1yPIujx+pmZI7ebSdzR6X1Xiek2jx0l7gAl7AyaL5oXZY7p3On1xgz1AeCk08OduwYBaYbnJUy6+vIpinEhbzaj" ..
	"nmapjnRbR4NJxTNGu1N3TncgmOf08wUSFnW5b+iLcU4pwFh94e0DE6GI611SiAw8n/0XXniOG59J4wkvPSaIC9dsy3Mp3YBNoOjw" ..
	"o2hOrwS5t5qOWYVFln7dgWDv8zMpQphR1iXzksAIKDdIppkhL59CJNVXK5HErBpqdRDu0Wct5nTdy6gP/pFn2UcP0AJXyih/NIY7" ..
	""
local PAYLOAD_P6 =
	"I7UXPOyDLouOk4uqK8gqKxykq/goJIVe1IjM0cHN0kQ/GPXleaQceCY7ary7onbGY6DNodrUHVnX1hxelZ2+aje9MqIQdxaDUTpe" ..
	"gljPyv0+LfGUUgr1IiLdsQqaTWtLclGDvt4Ohm2RLIIqE4ArNKG8KauTn9mo/rwwGw9n42OiSoidyVxmMdPePYeRdcO8hgEOycdJ" ..
	"qyztRTEi1wUjvH3Q9kJdXhw1Ui7SBddtGSLiaysFdKM7bHIKnyFTG1wqp0TQKAurl+mzpWJsOD50u+enMtSihAfOsr21/J12zXZg" ..
	"D215t6bJTO838CRnJeP3sWKC3sPX2sY0JHgDB/lg96ACxIXQLNno1Bybc6rNUu1+nEUyo5R98orKFL23RnKvW+sDhr8WuaZY7Sfg" ..
	"hfBqPYFC6B7ny07WITKo/S9SQOH2fM25t1q+LOHZ8tjm2k/arxdpTrw2XwU7nr1NcXKCv8BN2E4qZFxQnlb+94OdJBTWSZO1IcRi" ..
	"n6d8OAW9ViwDSfPB/vdaJ9OAKslRY9iUUJ9Pf4YHaYDZkjkZfE78h5t6BHh/sP0z6L0V47KF0R9lYhV29DLXXsL4xU8GMupg+mZn" ..
	"xTtOZ+j7Y8wMRwJsURDaN6GTqBb9MqibNlZOsPVUkn3NCBr0sWBo4bUXCpwc7v/yvfOsCJf32r3TPN2hEl7KkCCQK5/3OKbUygmO" ..
	"/n6EP5AcbMKmcp1ieP3GDimV8jxOPR0wj4WyYkguYcNvOoogythfom5OpQdwR7ZAmYOH/1mGqVR5syP50pJ8LKqQUZ5c/czoSc4n" ..
	"9go4cMLCgiclUqgZPqPng1oZ79JoSqoC8wd2KGMkfTxK927OEEbNVoCwqm0X7Ccy4bxweMBJ2dcTlVTL4bv177oQVwBDX5nQNwON" ..
	"s5Gbhzhg3531ZKx+e8NxuYszAirhH6hIEp7eZRlR55cM9ht1amjVZtYm30uYzhyC6DOS+Cl7r9RcIJ+ujowPPtiVJZ3tJnqBoTWo" ..
	"7s1mftC8AJrw4UsUbUf9I1CGl6N/G5YSBHh76bHslAz4UaU04ZM3Zl9n76LGKbHJHi1ZhIc0QQhY2IBp2+eDQ+J5OiRHjandyMAc" ..
	"a+hM0D6xSkXYG5Sqr9C/Jzpn6qDOHNRVK22nJVpuw9E5L+C//Oy7mzjkHISVdvBQqsBeLW4khr5fRkKTGpU20V7qCket4jVOE3U6" ..
	"W64e1qgwxxrBC3Z4OiP0qFQdlffdW+8vI5WDXQXkfO4RfldCqHKT1htEcMFFh1SgdRAm0uqc2K05uQ/ZvmG1M7FKPWX1edr5tMCQ" ..
	"TT/kNJBePuTA6I/XXi7g9U8i1NPHHTashHX9DyKJKjA0HzWQLeGgyunGVlCfjLFwd7JF5ITSeJ0ykNBSWEq/y6Y7b63cysTYbmV9" ..
	"+nWYB68OiGFKLVedutLwJfbd9lw4PNY5nmlRdM28fr3xucX5tiq/wJtkijkAzWTZ2tYBrWRIzK9KdfFUo1XgGOeg8QUqUUc5d+DD" ..
	"6GYS99OHpy5KoYbGIjVbGE0+2HF1mpdzSXLfsxHrd+cde4WGZYpTfWd2K88P2/yaT2SCJbQWpP4eITkhQJwqf7vutRetjTvwh90L" ..
	"3fxJknkYMc07KbJSRzwbj06s/61l/XMIktuG2CnZlfGw2CK+yZjiRIsLDJgfmCGmgwCwuwrGg2lsrOJIvNnXtEWJUBv+DO/5d3Kx" ..
	"2va7dUjFH6e5XEWUkRfBEDf+R1faxMaySkHPGwBzqmvroW4k37PjOlP7tXhBRIr1vKrBRfwD82H+eYfIO1RYdAOHM2LILG2Hky5Q" ..
	"6WbcmB8S+zFWbEWrL9CnrLlqtmc0LvIAo/l2X/9QSn2bBXFdtNd0Ai15WW8lCrkc8/zUXb60WhfqaAvJjz5jGSRqXNUuE2nWfxEf" ..
	"waLo3PEsOO18kx/GdxCLTraEgX9pjdqU76bnISifCpLmXTDR/awXuVxtsooBT4J9HsIsC5jA+QFfq5K9AJKMMureaL7hiXMAojcV" ..
	"sOszlhKtFdIR+sLrPRnByhQ3KByVyzEeTPD385W/TJdTKsJr3WEaZWxaNarQElHeDnZlYh3dRuYfrwwwdwTZskx8R6EVjfw6UbmA" ..
	"VVFYuV70ppWpUENmmk0h3wy3Ld3SanJzxhqgv6iSdkzxNk3LMKutnlY5uBj3M8WdbHq+3JnyJHPBBAa829uYmHTpgXyD97D0Z/tN" ..
	"3D3bsTwb6l15rqip9w41IwCj7OBrJPGeBIk+cYR5jrp+BEi0Dps8v7CLXW151zZ7OdJ6K6uS1T4IfdHKJBwbbhUcjbjj7abpOYfo" ..
	"zcWdVI07ly8z9XsFjMKqRHCIYIdCCtDeQ5l8RMDiv7iKJJwzDN0QUwM6ueVAl1vwn6gmhzZ3wUqybWXiSQ/sxoDl3EnzuS/DKYYk" ..
	"1bsNaG2QGTSpb5Wxkr/w5HrncoVYRg3h4c8J6ocmfxyNazOaPHY7dhK5O28zYFgl8DqmNr3+6ofuA9DYbszydkGmpUqXlJUJcWKu" ..
	"nFDDGiN3gXt0Hmq/Brt3KWQldYdaUS0M4N7irpyIlL+i69QK7/i4N4A42Lyi0QtealiOsFAkQMYtSA9oFL6ReJ/wACHGJRwiBkYf" ..
	"9zi2Tmb0Xfcxw55Yu6zYEgt+IGeJj8AlJ1k/CswI8CnX00awbjjxsIfozwH6M1bJXsCDyRIbcXX6YiSjBibRAew37WFnHJK/kTn3" ..
	"/5/tealaXkj7Jmo1GDzvQ4XDCCT5Y28ulEKL/+gTxk4D+MecNEsfsSff8Zss3jKt9G+sLgkQ3946pxqOr7U9pcPL0PVWTC/GW6zu" ..
	"M1MUE0Gath70zOdZtTnB547seDiHecm2asb4f6cg1M4UoUY9UKPVsHRYFsLyxiWZm2AEFqOYCOb4ML+fD9UtnHxAyaxhV7SyLVLN" ..
	"vjZ4HXBYH5CEvxtr3ICJ4Uqw2px1KteN007wUaWc74KpzKS1SVOREGzlLsJqh7E6HXlN9TsFgg6KnrFVo/HFdPj3ECSGsVJ6TAgQ" ..
	"sPap3xQ7dpxx9xypom/Rce+hitDKOFRJ1Wi8xZfMPxnTMnOQoGqVAES6UpYlCi2q7DiVTkz9KbVnvFjhLP5kXyV4Df3A/3gmFRpe" ..
	"2C3P8eujONa4qlzKHF1OzExskkrciRuzGK3fiXxCPQEP5k3SCsaHhR6IUyT6M6lLgXhBC9ZJvFc+1iEjXFoqFpr2HBheklE9FmNl" ..
	"hJ64xgd7nXH/Px35yGiRPrmmYx1mM39YEBMrR36UNbLitqRd/BFN7Z1/61hyIetZsHiCAwEp2muFDetATldihxopEgEXF5s5I1F9" ..
	"AhntyKp9F5dENFa99Vh5YThI3QScKDTyVttqf59QljhuQbVe1jX+19ob6RyfpZxmt0EF4KEQj8BLbyR/bHGcWgF59jh6owwRAS1J" ..
	"YSO6YgTQp9alqbkbI3sVlHas0Wawr5ZJDgd1joIyNq3GI6PtXIpDJCXwWYZNKNAfS6uCb30fc0ihr/5Zts3nDXnek3r4XvEeXG2B" ..
	"5qAF3z5gnoaaLluCE00sdbJKb+C+ZZvMvGkre2dZZ5k4p33D4fPGyNRmr07+95W5rdXvNtYaDvEtF6zr+igpnnif6aNDVzshk3qo" ..
	"QqE2VwuNTYU9aXP06P66fnp+TvscY4PopvIgvE3gCJtiQ7TzdR3uS31HbQlPo1MndUvd7r4KPEHRBhbEQKn37Ex97kUloWvh3kV+" ..
	"uokMtsIB/4OmEWoHIkHv6TlhjOWuoHvB1K5JAJcIs8RP2aoqnXPLloVsfbCGPK+vItV8+ts3X7e5Ff7iAGirNEyBsY02pmgFLE4f" ..
	"3rqtA3rEbNMNu59iMXKdRnrOjIbZrefV7uFx9h4RNnJWB3dMRNjdpd8aefG36SHZKwx1fZLbmXtmQOIKfVZVexuImBSm+wChzlou" ..
	"4UQSyK6QHUsfcm8W1YOp2J0EAjkfDw/eaCyNawNK63+eaR72xENnsLYRJ+wVnzOKPqEZqj/QZVsVLOuWXSLaFM5miQ==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6

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
