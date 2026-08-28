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
	{ seed = 3390428990, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3396187944, exp = 0, plan = 0, hwid = {} }
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
	"1Usc24tGf4gkzV5+JuXrSH/PZmWsCePU+KKWd9C0A4ZtBUmndMsjvAL7MxIv6z37yEzJl3DPVG9+N4ok4LkEEPQr+htB6a1cyzs1" ..
	"N9qhWY3cuBcwBJjjA4w4dXGJf7yXwjcDo36OiHByV/iI2VEwQjJi37nuyAdKakG3w82VMb4ysA6kK1I98PsUPgAu2sJZnQggabJ+" ..
	"+lqGyThRt3qIDW/NCnNKxejyz5ay3I9/HodCaZi0dR2t+z/SN/rZ00e/8KEFO430/Frqirq+ABFLnxYai2L8tBen1UEMk105n5oW" ..
	"BECiuDDU67j/sGuHV/a5ii/h5GTKPKdBPctd+lGjGnI6GA2xxWclvejKDdN+BsbgAjPZGpXeuYCPj+3PD6HtIHVP9+nULUr1B1br" ..
	"xhcRgV25FWwRMYc3hh7CnBt3rIxYqjYFcGI9FBfnYfehzO2BVIJqXCROUFTKCrcWhc3eq/kFSwJAInhT2L0z8+83SEY/j+L6bFwR" ..
	"8QHaMxCPQ87C6otmhUYsFPlF8P6+sPf8HsL1gCFgXAa5W6l8I7jTSUyMazxezsAv+ykQy6cmevi6Otn6uiq/aIH5XfzDLyO4X62d" ..
	"EmDl7IJvzUDbRhyTWCHl33nhgs8nKMzKscYfDDXF9GYU1KO/OyiUoJnvhfSIe7UcdkLzFDyHU0PdifYSkTHA4thpEKohT46eW9Wv" ..
	"azt60q483Rhf6Rm4jxoBDBkWlTh/LI/JR3Z4MkFZryHlTjZglt9wpYfyj6taLklJQYIxTkF3dSj1Mze8UCcxB1F1jPoF6kMs09Vm" ..
	"wdKnTHb3Q8706054eaUCVrDYuYrABrG4dUC9Gi2Jv7NoD9vKMzuQXkF6eoI0cQcLS04Fbnv6srdUIfBqQd6a+2VkZzZNtS+jMIsT" ..
	"f6mFjAO8zKLd9v+Oik9hAeh4ZSPya+JYE3VnK5Ftu7FvE5US78Jipb+U6sezpjCPvFjpYwYtfVrjDFmfZOg9PKeRDhGPzQuPxQPC" ..
	"tGsfkQ0p+Cb9QKUmfZyzc4/ca3+horK570MFFn82yvZDoKmuNMeH/ummzFoBGMhkG5EVU3Ef8kyXBiIe70uPnXFBL/G0V0l76CfJ" ..
	"ejTtjP+1RKjMGwTO+Nf2M8OZy6i+l908LKDSH0mOH35cR/aENRuLn5rqGy+qL8WDgjwwY2fSO3y4KSR6q61D1KZIt5XEFK5Hd3em" ..
	"T51KElpe0aUJr3UwgJ+EUx5KyoVjrbMbOlD507ZtjJ142kmuxirPzMMp9GBFLP35OJCx3uXb0pnQyrRVzFPjsBeZ9m7/SBuaE6i0" ..
	"iTHVlauUcJ+aySsxRAstEBR5vVipBHu3iKkDP5IRH9JcjQZirOhXcFi6OzXKkcjM/znqvotuoD7Y5opUGcfadWPQVgTpSDl6vcph" ..
	"y32jMhVDKSnwlnSXY2gp+BgoADNyvyqMkh69KvGWV/0Wf8w75GuqJKrlRbhlpdpR4XS9hgXadX+QBgLKYgDL+hANQnwZAnujpdJn" ..
	"3fbVU77j3gf98Wr2XJI2ZjG/5wvCuWbxTAfXSUrOsVf6Z95J+djFi4JcYoFGLoIrZlISFmhBzKx1lblDHkLhve1EuiQczHg6BO+l" ..
	"ejeSnJ4IXHfCeuvdizwTNrxQKxm5eeX8Tmn6HyEZaXijXsa/QfIupU4GcVi1tvCYwF8tiTx4vTegnKjqHp5ylFf8Y3ueymICUZXr" ..
	"NG5HYufxU5zBDRg8JGqu1qUGNrP4fk1pMIJiEDzydpsG7mPm5Ofmj1kJkR2T/X+Eyo9EtwPc5cQieVKoHe8dTK07DEWaWkEx8nbY" ..
	"/8TticGtdL+wapKv7EMhmWNyj6g9C+OW0kJroOd4QsJb8jFb2XLbrtFEQeP9GEwrLS/L5POPtYYK9pFPfVLRuqz69ByLxtDB118m" ..
	"7j3eM2RZDveM5Eq9M2TrvYFkrDCTzkBwmUy0ymI1DJ/5c1iSj6YHKxNVFv5YlalzynrlLk8SMYTKXnTjuYtmDNs/sgyv29bM2jDj" ..
	"RDzpL8VrXXP7bSIVoeS6Iv55+ZUQKDEbUbL2X9zOGfWj7FlRrwqYpmhXY0uyW3QJsos1vh7UZQInROcxl+9CTZmBXNbZcT7nLPUK" ..
	"nhVdhx1O4Mahjde/NRmiHEB4cerIKZttvxMXz31Z2H5TvtnBFgElLQoq4erBcvntpn5As5A+pYg4sbfzeRCcIxvinav/ZurBWoRv" ..
	"g6EuFRcaNUaxoszR37fIj4o5KsJs3DXsKJ1HlaCFeN1KYFh/f/Q5A/RJHu3P99v4D+kS6+vo3nmxo3elr3e7BRaMl0FmRuLphp8B" ..
	"boIylXS/0ddtVq+EE+MjN1jMCVaZZ1prtybBMDb1AWOgHO5PldcDS73H6yOI9CX9gxp5dRCS7IGn2NW+Hi2ecY5mNCuTvRydRtzP" ..
	"+gExP6grp+VCMBoN+0VT7DbxjHE1YzH5MdkLrc9XpfPbAAe2f6ROutWoBc3IH7XwSQRDOfjkU3GNHCdVUTbg3iiO7nsDaX/AJOE3" ..
	"h6RyUZ7gxLXnF8MvEtnzWKq9ecWdk4+DAAFKQkDbsVVqRBgsXNLLhKPWSEykATZXqv/e0PSMR9nASs1Pgw+yFX5eaJEr06BN7XH8" ..
	"MfJQmrP3/nW/RR90K9tOAu7hkHAqoHVgSZU+kx4D0+t9QwQOpzQUpBqMuxPDZP6G6O4v2yj2w7OiHDMUv9wx3kbZaeGasJxnK0aB" ..
	"W9bI0u3x5Dk3U9IlCmO190otAjgXpuKeNY8YI/l2WYJnliAtNdTeRbfgJN3Tc+2f4Bz0YAkRiKzKajRrLohpJv23+FktaZnW4H6Q" ..
	"4qBqchx+PXiRojaGR/EcP8L6Gv+GMkITahjcq5xRW9yQC3usfwHr5ONXNAhpGl7RT3L7/hg4K+8LUjpuxS1UX5Sf1M4uY0bnyRl/" ..
	"nPJOPdIHaNHKGfVeGdR7s8f8JCXUG7/K8nv431dyReCQUIdWW8crIITMLsB/flK2aYhooqubP2sLgl3XoNfiQZNlxzO+rpVadmJu" ..
	"dK436pKCb7inpMb/z6kuFERN491tVMSShJ3Nw5CYr1gAfpfzMr13t2yFkPZYhVUoq4gYafuLrr9tv7qlQgXAO3+FVbyziNx/uG8w" ..
	"gYoAujb524lfQL+hClLgmINxWRfavR0G2Y7EUy56QcTWvLVZLt+fnpZiA351IGoxWV+SAnGGL7DGYeXYjQxdzli4EPkrLToFl9sh" ..
	"7z2lMlNDKQ2/rEIUwKSbzziZ8jMTqOhhl4omBX08Yb3MNaV+b9a6Hll0kcXDq6a4zfhVpgUg284DGXhL912MumdEznVMnWDKQi9N" ..
	"98kHO/EDh2uexhprR16MoSQ4b3reVBvT1hdOg+/7NYQW9N9gknZ7/lrozykrtyIMOiK1xt2aZFJVw0lkEX7ogpe6UWyFkNE0hIqF" ..
	"qipNC8Ms/T6R7IDK7gaIq+njCv59f7VFXcBqZhh6xW/zozphorNf0J2omfMMvI+E7m2ToV17DwTlm+4Ahog5hyuXPKvCmyeyXP1/" ..
	"AaipE1nyoLq8HjVrLHek9RvgByyITLL2kMkrp3dIA+PUnC7FCO3hm4QQD4sp5qr6LPNPGEi/MGB80PyuKW4QKylHX/jvmhZBAsll" ..
	"OJ1WOUpFkg3tHu+stCRxeSdAnQr7NtC4u4gI4xkU2t6j8atpIgCgFsv8WGXq2y72NeZUz6nNDSSsWDUFcH0kDjCLRmYB60P9EKBW" ..
	"OtD4TUxTWAIKGs/ztkz2rGI6muIEejzQvbry5Qn1tbwzxARDC4TRXlYydW5nqdj8ju0XqwuaUjXHVG1CeDg+iDiFVK07SWteOR4G" ..
	"H/NMQMhytqh5223cxYpF/csftyY0VroVEBDD2SQG69xxII4ye6mYLcxrCAZRMwiKQN99LI8aaaU0xZkdL86yo2Mw7/llzmpDD+p2" ..
	"wA6fM60L2ivun/pmpFmSTf1PurNSRXf9CYUtC2jNRMQsPYtLBgFGd64hTtVSmcJ5U5DvY5jEtBR6xAh2lOLN6vAdys/mqerpuw2A" ..
	"2CTRG61wJYcST0f0rlY7S2bsbQCnWKjVelUG7hFuIc6dpUvxh3QCiQBtXpakrzICz2p2x+gNvnWV9cB+/UZ1+5Yy7KpzhvQUAPIg" ..
	"5HPHRCb+rJJB6otq48rgR4rZX1HfkTKDdDpUvpCiE3jJz2BYJ28qVT2f1axElIAKdJHWStFLKFu8P6YeVYems189ttAag+WXMxfk" ..
	"0oZFZ+mvpCw2BeDocZtYxRLLdB0vFlswKTzORII8QVt6m2W6h7vb6+D0CE57ws5ILil/7sF5BE/xGw3JM8tuBZMQ/xNB5UssWXB0" ..
	"0qLIpil76XekI94w7TnWwWtIhh/5nDMaXLzKmGF0uQOiQ1DQEVJSCvG6BsPztDqyouB9QuV5nKH+5/Mw0jYPlNtt6hT267XGzV6j" ..
	"HixMXqXeyX1Z8c9bC2VuUEadSugwbDIO+d4qXFv/gFcncBf0yXiaJOAebngbKEf5b0oRoRXvbZOCMc5v5ABzYDaXUizkARhWW7KZ" ..
	"FLe4xvNi1JlfKzARBjI7DEYZzDR3/gijPVKMKan1Vg7IDYtqJGZbKG70c1GMz7xX7ClhVygYMOqHHhP661vA1YDk2y6w4GTGfy1V" ..
	"HU1o4zP8Otts9VS1oRcUBevCprZkACjmR1O5y7xNUuQDFf4ImJIg4+Mf3Zrq33NJzP+z+bWOZFz+PYoYFM9KhpPuK1W1VIomLw1U" ..
	"oAGwy2N4fQ0yfoDtNpMx4EzsEQjWaq6DifTVUhU48KstOGEYeYpY7/DqutWYJuuyptH+dRKIS6r7futV5cSaqnF4CdmQVCha2+re" ..
	"5OfCGMXBdnDGn7L8lZt6cvpyfsMz+L0veVd+rhMLX3YwF9UVKiOXgcIeeZ7d2s4Rj1Kg9E74Cy/5sKGf/BEVa7PmBDk9StiXMsB2" ..
	"gY9EMmT81ocfbsAFhoFmy4RaFPuuN/2AoXDmIgMz2lp17K+zCJI8cbS9I+kb4JtsBCGHTKkAscg7lvBQExUHaH2aYo8TJyABw8I3" ..
	"zNiixcRJT/Xd3oHbLNJeJPzNZVd1vSW8tIOvOCOmrHsolr+bOKJlu0Oscd6qIPZBYCJ0J6i+kl2uZ+UvROkQDkjrvI6L5qfOWXd+" ..
	"BfGGa8ILqgmEcqp2P5q+ysJzI1HxfdpBe6XFyMAaD3cr9XV7qWVjZlYG0F2p89SBFN1j3sM3aidhJ0aOVm5bhPTe9Jsi334guGxp" ..
	"KIzvxbzQdbG35530F8x/tM5QETaFiwyWq3bxpqLI5rscguI+ODHgWiXEOMGMwLPCktw0Sw6CLmA0Ja1xRzcvpAZlyD4iiI4t7KkU" ..
	"Kwu95pwMFmlKPzhxP+DwPyeHlGzRRIIeC447YRyKyuQQpHXMjUtOtsW8aAvuvi6m9HfbrSIkZ3dUXCjjpBviThM2ggsIso3G61/F" ..
	"KHhDeZgRuKe1ohmqLVZtRLJcQgoJBpsnJR96MuJekcNt4H5iExbifcbCCV+e8cpzg2UjKJkhphEf0KUtVxkSE0cUAh+wlviZ/DMj" ..
	"xkkJEYOSM0cYMjRqZ4kmG+0iT22Rf9KdoQnmMzYf+GttgiAH09uHdboo3OvMT9kY8epKU2ZClfGpTmPEWOJZ3BNtzRy3j49ttMPj" ..
	"TGuA78XxSrMIwpEoQkRWbgilotWYcpcQpoiZtNvuh4ntGSQW9KlzAb/WYfQIgogxtU5ITT7b50EkwFDc7NbEMJzYnCiFphjy6Q89" ..
	"GIbDollkZ4odQ8CKVIgGlUkwuXR4AdIwOnBkiT6ZoRUmhHCoe4DeXYnYc6xgk7hKRTLcmGadv8u4N5oMYT9T9Y5FKBdGyJmGkeG0" ..
	"84DCkkNsH+lZiFzEhIYpCJ6PWkDmyUAVKmJtZJZGXanzGRKFTr00dCYeFpEOY2f3y9WrA9mfWBIeUEj+f5v0KQnU0avgDM3oF6XT" ..
	"igPEdUHlhVetZUUS4eb75DC0MjaO4HmH7PBqiKPmyfuonnUmvif7Y3DspzNBrBdN9g4HqAWrhTDrQeXWa8PwDpoEfxnULre3aWm6" ..
	""
local PAYLOAD_P2 =
	"fwM5ICQLRj4aGqUVNfUMQIrXIOFg7sv9fWidXNAlSMGh3XZPWxufOvKY97KR8++hSQ/jgGL7kxSpmbaic3GBjLpjuzYucexKY5RG" ..
	"XN/y4htHyAEJrO5mlPV97FeBpKWZ3huYmHZKYyJurbkWFJ9X8FHJmWtX8mSNPWGmiCml0UGyVP3Y3S3m8khfNixkf4jB/rQG+VCS" ..
	"TLYCP/SLxaf5beywRVgCUk0V3s82FOk6NAmBWsA6d42rWF1en6AvUHPBKs0ArqZALrpUY6s0jhKKVFVemQ+VCN9tXzLP5wC3g75Q" ..
	"VJEPye7SnHmZDwinKJUCpLuT7uJ/okJF6izmuqKL4FUAM3/dS7hjhh53+FBApcouTGxMK79bVYWJCBNo8u/uOlLhZgUVx5g/TajG" ..
	"a+0GJheKwDVUwGwY24tAZ+rVyBJBGVRIUIknPk/QcgsvtS9cpB6Ur83cvo11OBjVP4mNcuk1Q24R2z3kTEb9HEpGBhMh543IPIN4" ..
	"MyZ6o0dqcRVUuZ40i37FJ4aku7y5CbIDaKLI2WmKavm6+5zPawep+C/sO3x2vbpe4pH4YQ1UjdGOnGfPd0z1fqQN43W3F+oGp8z/" ..
	"IbtKVr4bt/AafjXdI5HGrCRWnaWCtzjcwgPLZDgRsSflhyvyfTFU+zi1FQr1vib+xsN9471HVEmiCao/Wj5hM4uSuF2x7sk+Jmo0" ..
	"gjW82nhbAOcD6kxa+yOhSx3Pt9DIp5i4k/0u1Cd1YLRJ1KdHMEkAJjGI4RVTWgACzlABRM43Z4x7QaqilLPlz1FnUsg9/hxhvLm/" ..
	"RK8/duiDzu2+hCFws0kLRXcvgKsLVn13okpnWJo0KdBCRxEXZ+vxvURIITLL+V6uUIH8r/tXeM+uJpXrk6uxvjW7AmfXWBpFdY7d" ..
	"onS1UzI2xNoRWuJE/cRrfk/zT41iWz4mOcudqz7ASUZO855VYPLcuaeqyxr38tK1Evrza0drjNv8cK97iuA8PQhzrpkRa0hWDjIs" ..
	"I2NZc+qQs9QPMaY4NIyP5XKEPCDrMk4BxC2ggzsYuKL6Aw23fZtA3VK6mkyTzq3wIEohaAVsy4zkK1qrnCj+GWYsKHT/xap+uMW3" ..
	"RdH3in54AKyHRo7Gjoqlh8WlMAlhZLWT4HtpACoSg3Kef9o23+Jb7v4EY2fpqiowWhu9+Q5nkNWVpSCe8nf1x4NFx4tKcLzre2SV" ..
	"7T3KPcxTWbV2WBFZvtykvlV1ycW6Hh+GNj+He7cd4kdksAcX24CIakNq+0rtncp9beH3AQIVJ9EfZwkSWLJQqWC3FWTy15yOJOvb" ..
	"srKTxsP92O30v7G2NBjyXxFWf3R7zh+0upnLJ7W7OKZI8M+OCVSqqPB8VUWPenM+wh/zncPwRPidPmiqpBOuZ8Wkg5SwZaRvby9B" ..
	"C/KclW0kNjABalhjLWAr2QQADWclltvkYjULgDJwtXIrFws2oUQ0regpRZLxntU0zn7f/Qs1swWcBZNbW649BfO2xUtPDpVBxkML" ..
	"G3I3qplVDfLesjBYCpPfs5XtxJfLvNV45gIbtvLhIDIjNMQo3emaGtOxJ2svI7ZWmPpRk+FMJ4/8pIn8SNtA+Uyd1dPgapaDY2/i" ..
	"N/6TETqXZpWIqQIG6s6xRapvEYouQ4WRTm+2oiPr6uGq+klEfX1JGas2XOMBRkMnlBSwhrvbJKfZlBjWSHpYNNw9gqsNPBjuJX2o" ..
	"Dn8gn88cPGVhfOJnnJb8Xzsy42CWKk3NGPJD018zbfmKo2+6PBHQzDakJA1KlJzXUs3tZpuArCWl6ExdBX+9WM/5IyJComhWZ/DV" ..
	"77vGEWyKx6zmmiK4NlKeiSQq9+K+JtMwTzr4UYb46Y4vxxpJ+P90ZR/pnIY5DX/EbkkWo6tef+uFqWW85Ls/C0rsXhks41dSxNun" ..
	"sOlTmx/9DGM9kxxWeWNzu5lY+G/askIC8pD2CMa6Hc1aA6t/W9ZdfXGZYzv/+6a+7RmiWg4HdWIkG3AwmlS3Ak7IYtkNfFy4HIyn" ..
	"Ejx0exQz8AP+sY5MSrt8VKyxIG3J3Th2AEO3DfmwRzHgbYFIrzRD/vxJAj4rIICHmYaB/CwPQcWCJbgDHyO7PU6MRxXZkAU/+GB6" ..
	"8lfY8ffViIHS2NpoC4MuDGe4PA/N5bq27kdxPaVebO5bo+VMgNjZV5VGciSXHDzJZ8+g4sc7FMNVA89w4OhWzHbFCcYE1DQYCSBn" ..
	"VlNSzHQwfH192oaKvc8lqUG90nEipG9jZzf/7ao0iqDyaLhiNA+igTrJ4f1cwTT8tm7pUM2PeaO2ZXt25oov5KqxKSQSJ0Yc+/IB" ..
	"dyfP6Q/e8X+0Xs8GvW4skZfqUE+0DGZKakEBVhGl08dRS9tM+QFt4YbFnrRy3hfx/3FnLRFKy44qjOpEeiZkqYiQwzjZ72ogyApP" ..
	"UaTJ8btWJLlsebO0pwokmLArmIruNjSwy1d2+o3H5L6lqlQjX7Iv50EmtfRPovhd/ATPvX8rmJPQezFj1J9m4TJfpwzT/cznrXfs" ..
	"RvuTkU49ep4REJ+XYUgZBUAdf0TjdOcVANiyn/VyOKQBHkHF0nerrZyj2ATUIiNSgci0JMQIcKCEKOcDKG0XfsG5hXvhBiQ7JN6S" ..
	"RZOoluNReLyMG9q7sna+xCjTTAw+7vPXEftwbEwJGX0CJaU/EJGGWwJ9Rrd/G7XOZsB2KN4q2i0UWKI5YIwnLb+cvIrJZHNj4Qsp" ..
	"2KEmnNzWLJX6vtqAwqVGiPnSgfZtTe+Qr3xI3swmqufwZhoFb3SySM8Yb2QTDijO3LP+M9bvmhj/OxLGb6n/KEakb/Qo1vEgHKpt" ..
	"sK7Z+tkyJtmq7en6Kh1j8IycezhwR4ng+ty17E7+YNV4GqY2eVBt4269jkxnN1RpiKvJrJ11o1kEvF5/PkXcVpCCGrDDZl4T843x" ..
	"i26jHrnLIIDaM3cC3GvbrearlKXdkWXfBKbhvjSs6odZ3aulBe8Yo48tivfAnA2wSbR4IvHPs4DDPQGSQeDQ3IxOCQspLY6U49Yf" ..
	"x6YUqQy05N3EBtFwcNQSc4kKSf3lApR5EApg2OsZqWVdv/rBUw6oZFPcMqTjHfY5BrQ0odKQQUtAY+HfticDYYo8NjwA5G5V5x/V" ..
	"fdhEGzuJBJZxMj0t3U+hZUA10+0AqX0qjM14B4mNQ7mjgRASJ87g8gEiB0k4A6tvi5JbGFKyPnFgXlS/3JwpolMnZ8fPcQEaPF0Y" ..
	"XNSQiCwPo2smkPLNRWZorksIlnPwaoEcUAE7K0HXImG0QR3HuPKNwB5AQAvOfzDpM/eoWBUUZKHTYTLh5bc79IfrNxJyhExNuePB" ..
	"wshbl3Lgxix4+o3QzcYTgh8/A+ErNPI9MK9VspzbAxtoUlRbiqGRgoFr7hOvhQuGc5KEULUomga6TlIiASvcKbgAf0NaQMgZvlDS" ..
	"H1UsV3tR8m4V7DbTFE4gcr1SbFGKd79YzzIrji2GO0Kwx2g/XldBdVO7OVGbc0jHa+xFssNk7iGzjA3b5I+dsZFpPQ0DmX2zGBEx" ..
	"jKsQkLcLtKxzwBVeYk7kQ49x20pGcSwuy7gTWMGqbraUfJZsapKVmXqnfd9JcyFax5wvAH6/JXLsr4RSGvrOHf6832mp/oRjW6nb" ..
	"1h9QB0Oo7xyR7jGJVWqb5LQowR3BgaAK1YX9RADDgVVvjvEEVUEHncjCwCwBbTry9kFhqOfvXEUS9mK60EU4R8p2qgAzhKEG5GHH" ..
	"nci3omurFSWhrh27NpXXOV2sR6Z2CqfssVKI0otEG3+hzTrmsGefzL+8Ca64kmM2ADO+ATLN3TZhdhO4v0ArqW9/GnU/cWpajR6o" ..
	"0eWZwDwsk8uJP6fBM2FnXC6mCkGPrfw6n5pFmucIdArga1Ajq2yBDfIqJmbuZQLxcFba3/vUYxSw221zBgCmBumlSK4IcP3xPzYa" ..
	"Hz8larx+qYbIatuHL7Z9gCVdk3GZhbVsWrRZha9j/035+r5SknY8lLDX6UpkBquxX704lJE9l17BJqecbrEvoYmYE6u9NF5aV1UU" ..
	"4YvJX23BkT8ftGWBN7nxrxgzkIAQK3vjWiu44fn1x5VJH6Vhc8dRt+Q/IDFqTKfeOtEMcAIuyRsstBS9AhQZk7eoPXZ+IZVrDz7B" ..
	"I2KIU8gjU1+poM7B2UUFycDAfI0vBvWRWlTOgWD4DcML8gSrv6SXUu8UeNct1vDO1EkKE0T2aDVS+eS+I+xHVxdtFwkg4UswExQe" ..
	"QAw1OLmRVA1449hqjPtJcZ/9gke/axjnPWlnKtaITGHb0o6ZivlOc7qmwXdmRtYgI9heB8HKSdbZO4+rKyButy0+aaOrFg8dT/Ff" ..
	"HVx7/nGjHWe3U9LXLD9xcIBH+ZhUM1JPb0bxXnBJT/YrfX4HrwvrWRQcMefYb/m1/x6Ny3ZV5pLwdKmAWMw5vbef2L0a8OyAO6Zz" ..
	"oB6MfLKbI5Y9KpQKiPC67zp07r2SKHfXUT8xxM8+JT1MXVtMDJXGJQfgFzXEFSiSlN12PHa78fW+zLqHY2E8gs70GHnsPrd9D0KX" ..
	"o4FHrFX+yxWXwgUTy6vgF3qEUPdGP30Z3viPKR/yK5vI49RIo6pJaCbmB2UA/+PPHPWZ9BirOn4eV5uwA2l7qWC6rk5ZMEIGaIOu" ..
	"URdXGRHScvsU/08scbBJidCFwftlw67LN08S1xr7a/PRBdB6t1Hwn1ZugxoBv0FBMaBt2DcPhykQpEQZIuurfZFlkMSgo3A/cqWd" ..
	"gmOm3vAFlSSchXS2uKcF6UExVnZPnPL8PXFA4iArYMP0/HjGjitgQBBnNisPKq9kiNgGVE1verR+lSWL2wt74UgKtwIe6GQRHh+j" ..
	"rO3SYHuliFCHhfSDK6dOV6YJUB73zBaJkLw4xhF/zMwadFtgsXS0rDCDoNfUJrhPfJYoUGAT75Xixjh+N9Gc/RaDTSAWY5VxAMdD" ..
	"GJRRoxXevQwD1tyuk9+CF79HXK+oUEAi+9QWERsuOgpSD1B47vRrYjl7VzlqKTxk7jNhuI08eN+z7GNEcW5dyRK9TJxChkC2Vlqg" ..
	"pFOFpYdwAvjFXLz4PW3d2sRzv9V31GMAcZv1iooNXSg0sDidBsf6tjDcUTG7FWAZina5ohYbHTegvnfteVZuV03oYb5VSq8zB7U3" ..
	"e0qtBInwIUzzM6A0wScYY2NTv8mfyox3K3gtbfojx/g8Sk6SNH7d6tbNrlfLrhisAONOv0Jpz+ahAnuBl7Tvm4yavLcLEAMB8nNJ" ..
	"ee07EyBfFbWGeVEF+C1tM7szcysW8/hPF8YRnJibg2zq8yidzhtK4z0fS+nedp/40ro+zYFQjyCRvgiDW2la80CRV0bv3TILj/Nn" ..
	"mAW5NBeJEqU3CGPpHd+AYhpf2DNKOnRpMBzvSdUjIDGwNXGeNwCGIubr13f3qDxJxm5+mNS2Ii7jSOaYHD967j+LgB3AN9ITjTBO" ..
	"tFtAK+ae4JRkgZ0s4lcLAf/JMepmfVDXBi3gJ8tZzweueyCE3T0yTHeMgzN596RfYmA90Alp++8f38r/LWhyXc5HgUcg7k4WFnZW" ..
	"arGeaNL1OuiUt6uRy8N+hm2cf5Bn08WNrAmwl0HCmj8hxEQOJs5cieeKHh1T5XZS4r3WsUwR5I9MH4Kid11RYWRFgClQpc/Nm93v" ..
	"RK10ZSY7UydgJQCGrzgbwZCLYvsRonnaOVfjLbcgEs1t2n2PQKCZNDA5ZPXuer9Vvv9e3Ce9btk0E9knYc4MfMgyZ826JP/vj7nt" ..
	"nM8YlJbzi9uckFB7uX5C/cUNTAba37T9xqoM4msfaIw8mSpkSG+muvu67+ehSSE0v/Gm0fHUhIRjxWIbYXBSnZDg+TG1JQWm8rOO" ..
	"SE4mcNXfAe2r1m3n9WNWchoSjUR0ONCWwysZv5wBjWF78kANlPoYtdipPKiDw4Maq9yOJxpBLgx1UXQp1GNe929oJnKM59sJBeXl" ..
	"EMT59eNZpAkzi1Z5k9ndxej6wb43VJ/rWSq/njYRq87BLVeXcY8Az2y+67XU/bEyKPJ1opl0y5TVuHouG44t8n78H2KJiYaYaWRK" ..
	""
local PAYLOAD_P3 =
	"YV7KDnQXRn622cr0VZUMgPphUXC8VnQyYgZGLNGphm7nJKI6UF9EiYzIo0+XlZ/pmTZoOVPDknJb2ZSxhLQJHNAUpBOHMCDOGGgp" ..
	"0lEn1V7nCCLaLwvNoBSyX1/IfxLD3VsDSbgtabLnPZLsNvjeOO162wgDaUe2Vj2Y0EJk4xDce2ZJhGSR+KSuOWXZGc29x9YsRuOa" ..
	"E07PQY6kXxuT9SmR9SKlAGpc6i/f3u7f+9t69HNfLjKLKIUQxCzRnQyqnCLCBYjaS6PGxLDqvysIY/Kcgk/9/QAtJLhZq9RxXdFK" ..
	"b5phuxTCJZonBwn7OGX41O0PYxn8TuAO7uP/lMzvF13qLjk+0FIvf5dfeqEGPOCpTKU7ITPr0SBpCkpA0uSEoeTigeXwtjPMX0EP" ..
	"1h7+epoKhC83vOqyTJrJnmz6hXLkpSoPcCxC+Pot9riSkWV4JmSOewxatf//c/4+F1jFW2nit/q89pkHNXzt4PTuD/Lay1idIRIg" ..
	"OClY7vpH0+ifjYWHQOEei+GxJ+/2LPhtR6UDTeLtKt/E3CQN6NI/wvLzwBQHreeTnSOxM+ByJiughKe5t2PHKBC9DaXto/AYg4hZ" ..
	"Xhqb4FfDqvCrpZCJpR3VSX8L7g6oV6Gr/b+0yYsiDHg6ZujNlV+jXkv5ZTPGwt0Mcssy+wBNi3ATmEAANSFTPFrycRUI9Dz7aLmP" ..
	"Z0HIarWqhnO1AWKB0OzgVKxuK38hn+ZdogmgxJg7O4CpzCz4SeP7MrCrleLVKVd6lkdrBYd7/amP6TAAW2CM1Celvxfh02XF73ad" ..
	"ShObA/rS0YkLv6e1bMVHsR+YLNGxTcsz2AbrMW+E7U6zOPJeOCKBiuHi0T43phB1RpqAG5uLGf6awxkHIJy4aBW4gZlk3dgtt2GL" ..
	"w68Nul75GEFT+HFvPMrL/f1C0isBNinVURJtCLMUxEYjgOlfl2KXsWpGCclGskLSG49YQFSMMgd/lF0ZvDnWkBR4QH+I3EyI8fsi" ..
	"OcFkA3T/MIsxVjG1YVTdvFf0v4p2xkicOgxExGUYXEAe9ykJUoBQOyHulmMt+A0SAuCIBasAPcDl7eU2pv8PCpME0Bg2eHmOd5Ht" ..
	"pkFsPvlD/fJXsMbJW7KTzDglRAdSAecZOZw/DW6qaVLUmGM2A//+Bc4ovkKdFTH+suv8uIqc85W2apZFI+JChZiq/O4Sowfu2hKU" ..
	"LD9l2W7Hzx5IBQdMpJhzroTI586sO+CAC+CoDAVyA9lmHSuyG6bPraYrEb8BTmojBqHCSbpiTarB7xE0vvCUPknvzkVJDvk+KHaQ" ..
	"xBcmEeh+fxWOFrTEqXkYCZDvQNG2SHZYr7Qet15kojx/F15mm4TrVn61kPL2m6OosUHtg3A22ABeGFrbhfIYa10aRFYJoxn1zXRv" ..
	"n3uqphSG20+0VcBgPYaHfXDjrqT0WUkZtNAo1vd/QlefG8mqUynvrTM2CayXPENm14a/SaQh5QHvgmm9nJ3LNdbCVp0CrljKf2Tf" ..
	"c7xJSxLCGT3K39DDsFJikdtcH557dCduSIFrWyRsAff4+30wv1CAAAAti3AcavYfyj4ApKqwuP3/RWrq2r3WxgfcNvDIc051GDG1" ..
	"znaOQ9mnLNMUzg9CaG4nUe1JbnDH1A2DmEYZ35y+rgBxPvqMd1PTWyzOPydLIg8RJzcj3VoTIC1DjG57NvNR7+2BAQYLcSiXQ0Fs" ..
	"NhgOOby6NY5yPdt3MCLdYfg9GGL1DUBlfc+CHJpSmxIcHGjmisTUwWeJhM9+DEyCc7OgAYudxpRZN6oQHHR/CMzIESYbDU4Xc/fn" ..
	"r4HiXQEWH5qDp+l1PDFsR7WywGYRQHgS75/PeS6StfdG01YNKJfa9q4UhCtOUmK3DcbQmhW1sck2EhxKojDjsRPojFwSpMx7LTyV" ..
	"JBrrUDGHmuRnM7EhdWZi7ikIhOkfg1gHOVHM4KFmLf/+yii2zua5Xq2Aq5yRd76w08RFVfxSiUWXAt9uZIPL4PBAyqsh4+/Zs2eY" ..
	"6PaWjhX83Lzox70eTFzNKs8AB180FUjjwSPLuS+yreSTwLqY36KXejFblst0ySPmY4gh/m+GXwcBPcOHPFpAriledczguRkRvApi" ..
	"XheMI1waDkJxztbmSRjeK7GlycSd8TqpS/bJp4cu3zSfm8EAAxnTXMdpaILYj+S1zS3qPiPfEi3QUCsJ0TPIkY0EHKyGA4Bs0q9J" ..
	"swpIyALhGigPJ1ex+NR+EwpI57tUXkXzyzSA0J2R0FTkb/iW5w2HpY1pfX+FwjvrSdc3ye2PcRIE0aOHsXkun5bJdK3pWFv8d1ei" ..
	"1I6LVBbkXl0gLBkdUBneXvXXcvnwkjkXcwkq1U2IpeQtikPXdAnztWTeDLA/+FD1tlLWcnjIUGy3baYoWOoleYZC7LE+/vcrHk+Q" ..
	"RfGSL79PTgTfSwwlAKEUKUa45W6eBKoJ0UO3J7YxPkidY7rH3gKsvfQXHdz4mLOlc479KIGNAJNcp9Pm213ILTCByekuAo2Dd6d+" ..
	"t5AkygSHLmgIrLVkkJgrb3eYRiWdw6uJDHmhOrnUjoNHyBsps9+l5HDw4tYb19jXWymExTUPC5CWb7aGKx6hiWmXADBNNjQNPD1e" ..
	"OEubJyJtns0ufWI6xDoNKK8qWfjRC1CLjJEvac1oKEgTSRGj5grr1Mjwp1TFhZF96PJ1qlfS5opYimTmIlKaQl1s2YJvojWDilVI" ..
	"yhdWHV+fvTktuQ7HZqaowD/vIgf1CBva0IuuLMxdgsjdMnmJECrikBmFip1zgI+iIJyCWAZHVllQ0XfrmPQhw8NMcyhrnF7sZk5z" ..
	"+J2ytqrUQdVb0CeGrBTJakfokmyhinDf4t3S9h58qZjOpETLUjk9JHHXoQyUt441u3wSSX5jg/azLrZ6LTgiMaxywhKGgA25K2XM" ..
	"EPMgUXPCS/1oHvaRoic5kQxDiNmblF3gjg0WNOtx8qDmR7opbFpaMxRGBGZRYhsEj0rA+w0CIDoFBKz7uyc/KKSwisERQisx/AJU" ..
	"ks9dvmtqYM+fS9fGD5vkyXljj9YRxKkYWimWysg0waYde+cXMu4k9iAfUMUsB0gFjypb+BFkKn/oWztsv3Y2PcWvJ4IwQuIvzTxB" ..
	"/mk6bRvn6LaEhcCXF2hKaTIDBDUB2qoHN0stxcOKrRwECH/4/pKZso3kvhFGJ8KNynM2OaUPaDKXB9iXYlmUkJ7FqSKO2yzKCEcm" ..
	"mDlIbrSJIuyMo27/+apEOMKQZ74BmjXh3F7nrXZUwkD3GZpKFhRn+MJjhv03NI760pR0Pi5tNZ2KMB692Ka6IHp8dNSMe1WctLD2" ..
	"v8zM2yUxLdo4uVS13TiOgd7DWyLOR46Y+LXwOvIvJLorfK4vdWi064xrwbatAGf/mmGzJFY9vxcsGsvNlYCmbIGdBwyjhzo6RtFd" ..
	"DrwdZpQ1Y/Am7Pf+2bStAOm6pIR2kzKENVKSu9957CsimxKIPCb5m2WpU5OcCLJ1DrV7x6vCa+GMP3CHEzyQDZPPOSEACc8AWO9K" ..
	"nFnu5vV8TZDfvdUQ/7G2BQc16ufajVX+TefymVxQlAanSVj8JRGeF0YZ5YbX9a0ki92rrTEuFCo2ZLJZM3iHPhVuXmRdJOW389Mf" ..
	"EWrmqqgy2bFNj73l4qJNWX5P9jbgguYaADBo44gdEmlXcfccdtwSQh1qGvYc8qIAw5KiawXFo8z/DGVhZ6Wvj13X/fMZUDx2vPlG" ..
	"rI8rFODU3zioj7yPIu5FHh2II26hptw3kwgQ6zoTpEzawxc8X5uASvF1f/+tFrrLNyhNRE64IyAUDg7UZIic2qbU0gyZ4M8Lbxx0" ..
	"il53NiltOjz2NtQI+m/reNjR9cXGZ62fZZns8X7yhMxufNAOKKoUuNk+dJubPnjXv1pfHdt0Q2Jz6r5fquXoiCB6ngbNloq+0f5c" ..
	"FIkUyJHMe0ZFrDvmAr3KakMHRAN57vuFvF1gEvNhlPOMr1s2Dy2Rok2UNZvGngHlXkaFJ5zeECTthTudMPVdO6gbwUfvQ0g+ygwC" ..
	"vgQhTNbDh99KOCDoaw82GnXbZtFKKWc2ma4EudloOINoRdA/BsZDlBLnJsZSns9VamcbZknrFPT8kwMnHBAjY9NiGxybbnvClJ9i" ..
	"uW9N+DQOtiwo/N3RsFfk0oil3rpccWvwAMf8AaoYnfpj6f9YuRYpCw3pgsAdJ0Gi1kTTPO8aTQ/T3UkTGwnyVmtxJly3Byqjzu2j" ..
	"U1b5wgd/6V8bEDiir1d2V/cqerwspM8UTu/BPVpnS6O9MBNKLvaC6pmRLIHUcxJBsPZyZDX9wc2HWTizN4w196o8o9svh0YISqDm" ..
	"zBixRi58x70h9fkps/+KqAJX4u0QbFolPcX7YPCQzq+GjQfT7Xyog4/BvfpslZmbbj3PYoc2RtpNE/TlG+98JakxGpC4+SJwDqHn" ..
	"iofkJaKQcw0KXLrqVORdZ2kwTNS1T+hTMxg4R6yXQq3T8KY/9vvF6skbhQFgNZ6ZFDMtr/b7TX4DXy+JQUYwDdr9s2tJAIX0gSCj" ..
	"ZS22qq01mbtZ+2rMTtUIrhJXmd138p2+nM+N755bf0A4Dhzb39BZyyYhrFpFj9W4gpamU0hBMvU/zN2YKyn4L0vKqSl7+7Y2aBCU" ..
	"auikQycGTcHuHTMWzi3R6vofi5k811Oqtx2JZkCKZmCIowTmqNQBuoouSZjq2gxk/XoxLl/Dotpuu+/WY6KpTF7tIIhiIUlhyIb3" ..
	"jI/nAccq88eSxMbm0ugIQOPS5vNjjR4HVUMFgFuEoYmQqriwOVo3w2OfkTeCem2keKFGDYfpM9YZzIEuJL+YoU02kalNT5oUrHO2" ..
	"/FfwTiGqpylviWFHc8bV6ZN6dQA2z8ZAARe+bHzUgaF8NkrhqSYh9lGnb0f4ODlMRE/LT/5xjJgu9FjwNVu5gc1e/6vebpQKB/Us" ..
	"xXdhI7/0005pngKvkxZu0u7gWsFXHzqYY7PkZIhOwQYOgeF+fERhVNVz9BkO0CpI00mcNpaAsdcIntxuuR8qzZewy564+ZCSS0bz" ..
	"Mjb9OmaIpC1g/wLE1awmI5CODNMUbAMUMwG01qiN5T9/ad+UfkEbqOkFPjyxCAoQPAjZ4XSvsKOaTDlMA3zwlfbUSPgPU0F0rk0S" ..
	"o856tmSXPOy4SiBo77LhcRuXGLUTB1G8ipZ4AUqfpSV/gFfhujhoOT1JtVNTUtNvyCgrfi84TJZh8h+JtD//Z43qTTsMrd453WIx" ..
	"B1mbusr7C6wJlF6W9ETON8FA/cjQ65tMUhrWQWZ8EL51g3aaiGYHPmtGp6P23fAa44I+l01O3cE6Q4B5O7A+MDV6gqoyEaq3qcX3" ..
	"zZMA/xXcDQnbpYc5ioObNwA6fNt/JG8Uviqd7IlzP3JO8C5jZOJvxLWdwkJUwbY4Zgv/DvWZKCAZyugs10X2jRKnq3XvtE4U79Yq" ..
	"LcD3hrWTxRhwF/WCxmEbfowBm4UpThrEepFd8uq7bFTPkZkjaeO3Ivbzoe1MNDo9s6lcMiuGaMz4jC/4mqx3fMZ66ta8ghY3p1HW" ..
	"BTFnBrRslhB/pwv5Oh1EAVxeE8c7I07VeZmDJOn/GwaB78oaR+5Bpu/WZWMungVDK7oLU/Dy93AB97nL7DHxuJGhB45414IJwdvH" ..
	"RJsLA5TJ4HJmujqIvBb8pN0lJJksZnxvyUJKGoreL7mpT8ThyLIB45f9J+M37IqJDiBuruTaBwag+weji/PcxfKeB5te2wKvMbsE" ..
	"GMkIcEpwZKNoAxy4rSdkFH54ElHO+3c1X5GJUSlt/+0vFIzFNnbtCGsQkh29t25ko7A0rIOpYP3OE0wgopRMcMTC2PtKQFjjDWYh" ..
	"vOw7DfU2qr64s7aSissr1IGbjxIRigstwHfoQ8XtJfzgttkfW6ss3c2CNvl5WTjO/xtDB/sEmG3K7UVNMgqLpUhlaUW+JTejsnuQ" ..
	"wB7WRGQjYIEljNbmxhnZlOSIZZKerA468ncAVlmtQ2BD4rsg0B9UXIx840sJlqVoIiJjKzYR5tnMmoUooqy+K3b0fu9s7PAvLU0L" ..
	""
local PAYLOAD_P4 =
	"7ADqCrML06/G3qsu9HXqnvNxvDhIkHcjKSfkHeVJQh7ULVcpTyH9mTqC3/2LOMLGmf9hsSmfnUNI6sQX2N49Tn6kVMfxThyL8M0V" ..
	"W5cCjFRJaXKBGmRyP3uVLJAaNWjZo4J6zIq1lqsRfmjes5nbFg5eOQS5YOm2SpFRc17F+o/nxaznsOHnooGXjBfCSh4xwETZt1Pa" ..
	"R6D21b88EVy8XEbvK918B/BmD24q5Az9ldqMSrhHwWzBrHlMRoK6gZzhumyxziS66v1G2UubCxqwX6q4voEgI9fXgLeuR71TNM2W" ..
	"oNL0f9yS4P40E+ePhQbHf/ow5NNumvWMP0NFmDBl2EwuNaLepFPyzF5U3zunuX+cbPBK6SojEyVQn053srUZ0QEU/sacKhlJONxp" ..
	"4rul7NrkhX3zUdutXWK4ur0UF6BzH9C1QFwVH4sKuI7ZK7TxgUTUNjURaJN3AUwwjOMIAphntkE4DZ//rnSQ8aZrUDGwVobO7bw7" ..
	"APo6+6SbDU56aeyV27KVpbIPuDQMXPnfWktH3xpqkeKoUx72OKRQQV770GF8EukVYpCeq9Pr3J2sghBMUxQblmozc4t1bo0l2xmE" ..
	"dd2c3pQN9GJAWqh5nPf8RaHEU0SV2tEPMERafz++zGiTcnBo08ZVXQB8CqOLQ2eU4A+KRqi7eebNCVtkAD1Xfc79qSyKyEzAixB6" ..
	"v/y/pJPX+O57yzmcNxeKnvtt42YIdKad4YnSMOsHhT8rD/BXFllDoTJy0+jMdBhKvOP7E+aIy1ZPIubDF9g9d2iGqCcpH+Vu23cr" ..
	"1PtGLSY0B2UvFTj9vjZxbvEIYY3l+1qHymuGaDp/4ZwDkTPlQWsVTEt4g9FFE+P6tHDKWKJsmPSgTfW80gVill/601TWoiR/Apph" ..
	"6bZ5+MvBaV6PuZvM2vPyFDnNtr4AaaA28O+Az2M/srhVw9bZHmywLapr7W+SYsSe4hhrMvoBfEo752e/+1QGywKQFaomt2sk+rIP" ..
	"SDlaJdBumXjvqmez8Xbufzco4Nt61+p9SWt+UxkFoRFzf/KJ5UPsIsvHCC1pRo7BqFVni8iEbeSV4NSqffrvpdeBoiw898k3oW8w" ..
	"2n3MREetqXjZy6Ud8T5I3D4niso7C9GcEHZi6kP6R1AA1o2ztifLI4lBErKwq4gJ0ORsc7WBEmi3FEz8NkPTS/1HmGZhSi2fOMtr" ..
	"wLqxWabS7yBlc5rJDvvRQwN8i4zOjNYnOdgTqsxC40S8yXFCSbz3ddtfbkJBBPZlqfRymF+tQkvb7J5d7UkjODlxkuMWRLpKOqnv" ..
	"VHe0FwpUruLPuZqs1LUcL6qnWWiQkGziiEy3KXj3fGCnhiufod3hcNaWVl4itlyA1w+/xVVpY4HzHugmUHwgcnz9QsRvqOBT5iqz" ..
	"rNe0knNAzQOXoQNO49UTirReKTiml3NxNbV010cBa/8su4/Gx3eo4u+uZIH97aNQydFh6IFPNNORnNJLV5icMk7DOIxyE4dXsQ0d" ..
	"sO0rOtW36yKqfhxw9JnSTltX5KQdejRnZu06/s8c+CMdhlZ+GkDsLc/AbjNrFPT1jn5e6OBDjaMadzsZXRv/hS3Ul5R+e6c4NjyD" ..
	"U2ZGrservLFyLh6AsCdG3uNK3Kaz5xbU4RtDiEiMrAoc+WrxGE9Lv4uOXlemPaD+P0leCHj+urlqWUhLSb8URHOLKV2W7hfP2A/B" ..
	"r1pmRqgRqSCtEo/Ra1oK9BSHPOB2HZVMvomC7Zm9KTnvPu63MXRuZiQR/ooSK/R2ctt6KVebAmHnueiQe8+FNWUDRClYr/PQOLx3" ..
	"IYJIKCqHEolHOTLQhUT0hBl/4KKN4yrlw02t39TIUb1IuYgaiwVkEUYyUgJfIVOLO+vm0DDvjCJlLy55ejL2Eq5tjT3wdzldTsFa" ..
	"qBC1PXNAZey1YHpHx2LcWKfPB/2jAnobtgBK2GMubgOHayFpPX4kNipVYOzKoNhxtFHt2dO4xYU2KbfJT5vVPCY351pfoVUVNALH" ..
	"mfo2vm37d52/029SSXy/ccV7badaBIyxy3x8QNXxkFAFiZerZEM25gRVW7HHTfw3Ts8rtxu0NlcFmG6HsiOmxmVgtVzXfECVj/RJ" ..
	"d84tBl6ZYcSiV+tzqm84+7Kq4qikZ98yrYy+0EwAddvnpG1LVqjAlByHokqnTlBhTUQIMzHufTeW2VK3QTRQY1FznBYY4wWIKo95" ..
	"iIsNmN7OXQc7C10vK/YcoUBzwFzDkPKHoevXGGCajTL7FE/PHdGeXJLRWAhhHdH1vnR0fn5rVO5lxLUNUn/SdtU0ofRCtbyR2r66" ..
	"YJv++OJk9pR2e6zAWe5J2wT9gIRjJFqtcHurBe/FOsKECfMFbxYzVskIwKuqdlR9HW5nDCd13dO6McxqcvyAd41K2koY3xGRksd+" ..
	"5Yg+SdRyzgI4n2d5eAuTqP6lsId0hvyna/ymRd3txNudwmwH5yVRVhA5x0VezNfLtnIjvTkwzWJ9kIC5AQ90wSZZ5JQTtU5poY9S" ..
	"mZRDTqyxgti5fmorWwHF1oENwDuP9WfV1Bt2IyFqF2UToqlRA1Hu/T5Deelo0g2r+bHmEAvtBbUuVJl+JVZ3MPE4P05Uoa/K3lna" ..
	"HVMkXuVnbYNtm/BxUOeVDRmX8ZwGDA2CfLlNKpxEfEWeHJdY5hg8ac9DaQNb5IuE3rbAOSVHg9/ymqmKso4aTJEnDaOHWARmKwYz" ..
	"M4CTXG+mB2f0mrDTX+65idC7KPI9ZtWyJrgu9/b3hbL8NyBNAolDfq+J10WLTWBHLca4xwv4x0gE8yxMaWHDJlKPrk4xRt26YsgP" ..
	"5fyncmjWnzhmV6EDYR9TetjSgVOvN2zZQ2yldwskCOa39NM3iR0lNuzx86m0SEs+5M4QMIhAQtLHTjds/QhvvCwi+mNwfhzqKG3g" ..
	"gHHawjCvTELnjwOl0Nyk5FnP2jxV3xLcN5SpmSTx+5Xw62Sfk3r9mxYC8GwfQI1XFmJF8tEzY/CE8m29SUMmGbKGl2IIJm12RvmJ" ..
	"rNHkI2HIzzIGpcLcLPtS9NFRaxIF1XLG0cOKN7k/tIJbfOh2NA3Zhw6FcAUK+N4kQ4SCSQdmQxA+e+0uxx2K5dszaggMfMRLsJws" ..
	"61Ldksi1sndlFi27i9YISQdq/HvcJnYFeaXejXy6KN9cvvYXIeVIuEOAnd3ojYQwBRzzRvjNY9R1chFPTIhvIMXejvwuIF7ohYaC" ..
	"7I1SdvRwLnOEkevO8vosYk/EWaH/VIGjbCgoKDj7YlVaxnAtL9IjjBrO2N9HuDVncyJHGLDJ6d7aqmQGm3SHsG3NrQjBoLu0ZzzG" ..
	"zwhcY/6EC8WpaGVj4t02gq9Q2dc5n9S6DDTPO39U/hyZWaQBKi6BJ8RCXYUOdLWvO3d4/zeXQsWWKn9LLEu+sF1HIuIV+46HBEEu" ..
	"CV1ACmLpDCRNmzgTTOO3bFvzQDqYfeBDm00WdfFZKoAjnDh/ulVB2rtR5B28nZNt9Q+feShzKaSWKC+j1qNEGA5ZDapJmCVuMXww" ..
	"NSW6jcqH/95o/V1r2m0PAb7iv9a5wHxGvulPDTYJ3XzcIVxjF/0oqAFDv7yF1Q0zKo/YSsdSF5WcCD6Kilkf2SZXEUTptbi5Po+k" ..
	"kk4fERLldLLS639SR0khabSZUfd5lHJSoCYLujJPsRibFYdTsu79pJkO3fUUoh9iuFiyk9JARViBLQHVfSyfo7hca5ILjnGTQWe0" ..
	"kqAsaBSHdK66CpKzuG2xSF8d5wTyJMgZHp0aabNtjgsrXAliM3XVVb3AOISQlt6Gse9LOVYi8rdNa4EH9aEz4pe+NeW9vLe2GXov" ..
	"iywvQTnBl412TxiKTUf1WePh77nhB/oFNzQTrAgEv7/cGXAvoDaMPxnQmB/OJRzawvyRndxw2dLF6h2ySxNnPWmGM01gZQv31ywi" ..
	"tQQS/qByIqDGzstItEicLFLPHX25A554OeYS4mGNcWnJUzY1NEYVBK3HEuhL3y9rK1EeGnm2ddfWdLSqaEa0LaOmCEAUQZjGFTrq" ..
	"JE6Qh4hIdzXk83V5d7pWwjtu2qtNLT82Tny40SqZmrwzjpfBHSeZ3WKfzVjuj68FuaVs15uyTOZ3iRkPfu+hoI636oUk+SmF72Xq" ..
	"yNvPm7gG9JmQ+1kaZ8tmY9PRBiX9u5RHKaQDbeaFwGqNBjpu0/1eWbwwbHc9Hip2YesxdCHpx/l+JBplsL4As0upGyIPvABbfVsI" ..
	"h6oRdnBH+HqrwbH0CjNnlQJb+EscDKXj86XFW4qdAbh8NQ2bh+Wi/xuj/KZLTMQC2vLCWPDFLfvIsmIeuSDWRFa6wjz65rnLJSxJ" ..
	"XChaq3nKLGgPQtyXnGrFv/qp0705QSNYbbz+fZkE58ZILBrk3jCQhcRA7YrZ72gP9HQ//pBC9OvZlQeezcH+LWMl04o2giBML+Mt" ..
	"CNtxBaC0qW3DLhUW5z3OXic+XL/XHqeZrXjXR3b4zOgUuDcX7ml5zGiqgcEtjzqGrjcNG7+SjJJzoKDhnDVtUFxjU8+taJ+gRxqt" ..
	"07lPOwfEr8WF8LAbqsuGJMfsqOzwZbr8HWJpJIQi02NGc4/ZTDsBiErp/naNKACeogHLWe+OqTGxITP/nJRXp5c5xAv+1FfdO469" ..
	"hL4nTYl+zILzd1Co2HN9qiH8cf29bTlSOkAkE0if/oR/jd3rBtBPxJT2PxaK7X53Hqo5Ml3c9ZdaD4FsDzPsuuIkHqRPInCThg44" ..
	"9nzUMB97ZrU8R7PNJVjRJek5uzcZ8kVUTsv611+tsNx8+w9KMkELCs+/uBNnA0M9wSvAvlF8V1oQS62Hd7dE6fKq3nPiDkL6fK4w" ..
	"SrxK+bHlvSfdyVF0EzufUnnLZM9SpEeqXqE/eCE3Fu1z4fbuxcZ2MLASt9bGOBOL8uQqiXmfMkp/9slszGV+SC4FiVG/zou49tOD" ..
	"s+KEAQidIkfDlJ0j0MIGRWjCTSMNm344a8pKIx/NdJMJ5UlhYCOv/T51f2mpkvKR6eT3JLeoT92ROAR4s1DR44za+u/TRfpvVFH1" ..
	"dYLPuufbP921QVRKhpDt/Butu/Ox21HdH53DHPdsGjopLw038LcPXKzX4aWrcLLOLaZAL86cYxT4xxOcyZ9Cf/ZLm3L/HnvsG7t0" ..
	"LSSQ5xDob0g2N3I8ZV1Fh5TyGnI348VDxXuL/GdF5uERTeEkwCpwNHuv3YI9rdW2mVAb9uB/QaY7AXMevWZnKML0WOr3jtb40Bwz" ..
	"RUbjo/O4Tqw2B7Ga1ygtREYGZCQSKvfi4FIpZ48HmtkXwgX2jLnIJsJ2jQg4vbu89H01HXY8xuFc8tPFo8rYaoTQe4AUVCTkqOu6" ..
	"JlqrjmdUXqjlPPoIU3sI2j1AGrauQSDxQKz3H0SFRB3L8NyiZMuJm6gmZJIhG+l15rp4C6kpYaswG0b8MuTqftU9hzrJi2eKRzIS" ..
	"MksANdiqFtUZwA6TFXVabW5lfj5ONSMgwJ+4ZdqfBK/yov4CzpjjxgvK4d3syjEOUI2aNPnKEWSILA1y5xoxauZClZ8GPpjREWeB" ..
	"+1Q94Zc6+XYI1JhaXqn55Zi2PPXquY3FslJqL/dzSbGPlZs7Rkk/IsiJVMowOEMgpfeVwGX6Z9B2WB+05HJLcAehSf1P/pEe0pZo" ..
	"hC1PWIw913JW73i9F1Zb8xfbkBBY4Re66+OgbJ0Nnlf5rwEwcqnvmYMicbUVLgcrLGvbmNuvjX9FJU6fgZwh5mWiZGRrslWeqgnu" ..
	"1iUav+0tUL8PjtUolChLas1hrqUojeSjMTvuxrivL2vq4dS5zXD2kQyTN0dl4rHuIKYiwZyKrtyheoPrF3x4zbL/1SSti2GdaWZO" ..
	"32VD/dQSBeYHmEQ1WVXL3L+4GESWmdm9Uq90lZnA9B7jXRr43YAg3nnVL6CRqOuL2xZq9XDS8rQoZHNSlvZ1ll5tZCsNGlQ4iqGT" ..
	"U1eP9LGMSCmd4gkA4qvy2G0sQBWHqePUEEHyTovXigqSSHm1nyhjvOWx4nUP3YKJL/oaGqZO+B/IpzYaK9UAwBG+bSQOukfEeCbp" ..
	""
local PAYLOAD_P5 =
	"v4UMszaHzT1VfjYy+A/F7IJUGHyHXyWqQisU9Z8byf6GQBBjeKmXmRjGpg/a6OBwqyo3+dR9SHB38ezNEHI55gbHstBlDkhBBtRC" ..
	"AaJkI6MhZf8VobVkLP8WyrR5b9HVj5mE/8yi2V3MTpDa0it3p4BE+7epha0/3y+fgOPB9yNccuk8VOEjs/eGz3K9UUcYscyKQlij" ..
	"kCkdqTr6LZgxqCpFCDjN2E9ObjcDUCrnN5gGAgj2QdsHOcfEVizGSHkJrMYVPXcVAqMejyPSpYLi/F+QFuw3pWJUuCKKDDbTXzj7" ..
	"sjrlCd+E1hLA5+0yN7arkAOV5IJA0uauGqaF2OipATbpCeMj/SijMNyOOkYql/ZDXRA9TsjMVTe9m4ci/u5lM3gjJn3ngS5AQaFy" ..
	"4rU7fCGXuNhFh+zQgFWPYji/eY/Zkd36G0Zd+IKh350nnuX+3fccrCmnOprpMM+aFuhyp2SdybkwEZp1R819BlhzmAUAf9Op3vkf" ..
	"LZebiLkSPeUpPU6GH+mhw0/qJKIdpuGaemFa0MGSo25OTSrdnyJJKEckzMwEH+A4JPq2+VaGLy+XCaHbIQysZnzM/6sA1DD1FogU" ..
	"s1zp4oZIITVgGK5sE8Kfh5mnufGxUNQdXvSDLHg/9oaHuO5KSDt+vq0mKrcsZgjgzb9+RbieuPEdM/b1kRfp/rnDyZia81enyEGS" ..
	"aJsCDC362Zi5yWcpEeUSnkFp2zkVkp0LG5DxW1FbVaaVIZAdwjWBI0IhRAK3quTClEEVcfO61d+uJlNOi+bMkhD9XHAz9ehVsi8t" ..
	"ljdCtw1KbhTqh2VeeMQf6V44YE9GM/liOyCodCjfNA38KHe5GzUrsEkptPqS4s0g6l2Al1TEr1fsNMuwNw1r8gMtOOuxLNk8a1hx" ..
	"Pb5jFNTKSCBM6FSneg6x21qjLFr/iLEdK+5GyIGlPnedEogjNsLcI1IlXd5w0ufgu/KrHUUtfJNXb9Zzh4APKcQxabzqBmB/9zm+" ..
	"MdnBNGd1llvJQwElSTZ4V3UnI5XV4P1RfqqV07Cf1Ct2HPq41quVvEbOCyzghc3G/fVhwLPmNdrOuF2ypCzBcXOjfN2hgKYW2FoH" ..
	"B0x5fvUk2WzdjnyFrukmOqCiEuXtTEMdYFqhWHqOEWeH4ELUebAYr8x9w6yXVfaiFjcNoMr2jvduayew8Uk9lVZTw7lSWtmkQ8iN" ..
	"upCKiScKusA2jqh/BXqIEMH+fdi1V6FW7ji9Meug+TiEPu/7ngmYk7so1pTX5BhsZnf6XyVd8HzhsktO//zwIeMArE5asnTaFDet" ..
	"c8VPfvCpRmtISdi7qcOj5SNGOucG1hDs0EBBhOIavMZ5mylM0A9P4DkA8Bd8w9csEpTx7Igi2UlW23Mey8Hw5Mm1WRaB3HrNdGf9" ..
	"dh4PyPaduVWRIXvbLFvS71HLorwouY1hfrUskXeV+6/Io0C/ZBDCYKRngRct7l02zJdMqhQxUmFN4ZGmRhdM6phiznmmgBqmPtkV" ..
	"LVkYdmZQd8y96ED5YOwTgfhkgtCV6iQ+XaQ27mHyIidECiQZeRVZ5o9eMh7NFRoJ3EAb3hQDidOPk4JiScrh04CGrhvIWMhFCKJg" ..
	"qfL07Z05IjCr+hJrPYoU1rnI7AvIBSXd21IYvRMgUlCUm9FHLx+klSi6eHEHey4HIDG2NK0mQxWyZHzSuX93Ga0FTAFUamBTKsy1" ..
	"ruuo9jRn6jrmWMk7mwOnNB4HTAJsDZCLtEbgcLxtObDDwnmXYcq0Lwo8XAOak6gP3Z5fGnR8JYyKdRqSAnghKTBUseahaZc6OO75" ..
	"3SbwfzQIa5+IAzRE8WUPNOYLaUiAVo1EDxuFmSwLbRlVQbfDq/A0kVIHFQWwv63OPc+UahQCX3iXnilDQRztuBXcZ4+3AV0FjGdK" ..
	"HskpFzIEJZZITkvRTnQWuowTxn/C/KdjVbFVhf7OF+IlKPUWUzTGv6yiDFbP4vcL7/ERPbQeTKG5cO8wNlbN7M63J2ajrATr75hS" ..
	"D12uVYMemyLBFIMx+xJyRNB6GqBuTJ7bNL+bbAsN36VxOiLFHbTTHOKPYStFLqMCjSDBpCX/6/7Eac+S7sEmwhTgEqQt8Q/ASRup" ..
	"P6Min6M89KOmivhpz7CDvRRjsSfgm2qyIf1LA+ASF26Ap1eT5CiGlu+l+lifPvkpdpe//xQArlEWLNX9ISxj+dn00uUrkt7Tbo9a" ..
	"db9oqWeZBaFvIdiyWbTRvckFqr11qYhp0+kkndqd0XPUTfbxTu5fhE60Ym7T7TIlIBg4Tr/gbyBZee1F1daWHqsqbfNHnFHRrNLj" ..
	"BEphpojfdBU/FZ11OiVi5KhM6FMH5Ynf6WjAN++Y80/vQnRTs973KIYMHbEGaWj3skVr0qr6QIxEGaX0qf2TlVSyr64OCq2oFITV" ..
	"r/WvRug+KMFNQmV92Ly5wchPjjiNC+e1Tl3gbSnqHSSXu+rj796ByZqIQXVjin/h6D8q5CwADOKINKwst6QL5u6dpiTk7swU2bg1" ..
	"3b+yxpMhYWMpugSOx8+F1uXTJHxSFVkDIC/Z96Q+11ulpUgjd7oev9kzChJnTTVfVDeGlk0pUKzyA/N4cfp4C89lrZ5EmMuCTYiX" ..
	"ryiG9YmY0typc6f5Dd1xJhSLzJLFlyKEzcYiUqLEgS7iXlnvnq0FAz9KsGSY1QGn7V8qpR/PR0vRSIJHBe/QKVnS6W14HLa6Vuxb" ..
	"kRqIwepZwVGBJZGcUCLTZJ1UdCZX/A5pXNrtrE//3cZg1sI1HArUrEIfsmPK5KmweFVdzZ4o1SGiQYTS/5Ueu5KddDeDWJf3RjDl" ..
	"D4Irv18Z68d0wr9i/BDsdmckcIeevQIFSjhPBLAfgCAlC7y6ko5IkVjsRvWoc8SB+iczJERBcBzy/Gsgggof2r6YmmDJ9gielQzG" ..
	"y02NeVrTgn4yKQQZzXQdZup7sAGR8QkBFBy1AN42D4NohP1y4kF3Gj8soTqjQA/yf1DwglIaVbQwY+Q5ebOrJ7YclgqrzksG8P4H" ..
	"f7IuFXtGGcB6FgwsJuvgEq4K/hIACZdOD/Hc2D3+GoRaj01JJUEpHe56kgsngjcAx3vKzu6Qe8jc+fD3nZUZsjLPSrdrL/58p/jm" ..
	"Fvl1mrbGtWR0nb6unk1QhFw7fltS3sfNTiSPg25kKwxEqHkRxbaTPBzAbzig5AdyMbuKI0vzaZrDUw1mg1WEBbmdye0TkoVd+W3A" ..
	"HAcnCvPlm+R5xgFaHOJuhW/vWaQ3UA+KgSpjlGtk8Q2kC8+BYLlRjY8tC6KuAqsmaWq+XKW506eqjo5jsHXQjZyY9cUYjlOAs53l" ..
	"VuizNKwDXJjzgPe6drxhnh2s8CTs4e4H0kJTcnmj2d4n7a/ZR31mqhbhpXDz1kM1H45cOTthKk5Wiybg7ZYXNXmqUpPKKYfANhWU" ..
	"uUuuv133g9WLOII4V7IUHOuK0UbWW8EhnwBlmr4IVbVuRDHsrA3sYeQWnFwAewWsfC9kMHWdvLGhitRcP/KadMK11h4GTIIVwkwW" ..
	"HGwr2RnJhHKHdgmKeL61BtdC33C4Ca2VpFLjLN273+s2KEEG2WW9Y+vSGIy0qT8Crp8VbjSV2+LItgD32xVxkwT/9uKIzIMLivhi" ..
	"oJn9MmelFNNEQ75crvzsbvUFZdUvHlRGpdS/gktlTIz6o4x2sBmK7EOWqHwToqvoABWfxq959l/rhzMin0EBU3ZrTuUMFZBiefqW" ..
	"5tBzHZHXYnplb0Kx/S8G0bDsDpjckh1B5Yd5YuLv4jUnbD6uwChssx3X9sxwoEf0qrsxtNfaQkvBrqYM2C8RqkmhMWXQIiAsArLT" ..
	"4FyLSIyeVaDi8ylpvXjimOw5Kh475fmgXa1kYb02B/2ghkfHv8vCbhY0RkStz/Q4OPwtVaous0LTBOCXrL51NIKnDknNkT6APaI8" ..
	"oAMi4k6//iqU3uv6KGFtYT9RGDGSHRUVzik4wugBkNpMQM5tqIVYhLrId4n98jaPgzqsQ9SeWk6AhwCxixbnFJqRuvreRqXEEQKM" ..
	"n8Ld1KBFP9YnEwg1Ygj4jchv6PPVMDf19Y7MrrlUapXT2bs+gjQZAaLSCiNn3tNw1WAUhK66ay6T3PYvBIBjRha/dEz37B0I9IFr" ..
	"ynf98zK91HkAuH5f7z5N5ElDh2q7XQznds0Pp+kaAPBW5tdFugyviF5VBBejsAwpmYZAh1h8YbqfCDhS+Xyf8MEwqhyjulXDkXk6" ..
	"90rhwLAunIn/YVTSuJfcfGYx90puVpKWoDA2ZrPawGxT1+A7BK5T5hI5dxahIByj5NPqyFZYCxHtyQx8cA5jhnVLWzQwBkAmD948" ..
	"SEICixbGfEYrxzcmXJoQee1wDDpU5/7LZTclCt9qsFv2ORnhZ/saqaI9yonI1hEV7U0FI2ZWhsQjM0BTYBCBeqNkwRfH+cQgvkn5" ..
	"67q5BRyyyoksW3zhpeuGpr+/QnDQAl/86B20spu/chQiYMKQhqm3tfmYELDgYKMd+E+F5hCYxGUETd8OBlpgF0sJ7377BjvhcbN5" ..
	"QFOIPMdShbBQMVQX97/eBn478B6fbfiAtB6pCAMzTy4MJDtuEmxwikg4uWrJBKW3qQSekacspqkNakSyQqF90bl7+7fjyM5125EK" ..
	"FSUFeHD1N7hDBXBL5ljXAGnllIHZGm8GcjqlnIeZX07pRLAmJvh9GFL+IHtvx2LDK+olCXAu+RA0MtgxZ5qurzxY8cJrgx7aApaL" ..
	"qhbZKOZoGfPMtK+Eo1tUFFQrvUpmOmqzgaMVNS3ixsmShR6UcRwdwkgALHerSXFkoj5d4M3vPz7UJ867hzK/OnwKcOOsRaoetrXK" ..
	"uS3AKqdhrIWRZfpKhZY+xQxezu9tR9PxDigsqloOuV3X3vpQ3qkUcmb4WgPKvaPzt4JPPDz42ToRxtVkI1iJ4Dy4u0NwBsoivnZw" ..
	"2ys4D4eZxSu3GBxjnmLTVpnb2ayeS37xV7VMrgjJBg2CV12WxxQKsJhZmOTUrU0DMrcKmeRFl5P991+kIvc31gq96Kwl83N6vlfY" ..
	"KtWimLOLJPlOZzSZK5dDY0Ds273bxz1hoMkTi/CPeu2JZCYQkkbap8fw41cNIKOknvXuuDJW7lCoHc71fomA6nP/9s59yN0d1ncc" ..
	"7NiUMv0mw7l039r+OKoZxNFcYxemDQraNNJFMEv5ufTE+xJF5gaSX8ixHnzZcZbfQ3yYSz9R4f2s2JOphjqniIwxBF3CfUqDShwx" ..
	"H8gaXf1H90bReEpapNGFsK9zMDHnVKNSYX5jbz0P8MziviAOTJ3pnlaTuPaW7iledb0OEXYi9HfBvfM7nFKV/56LRE3xqr04QLLw" ..
	"tQ9zGmGeAyI7gVfep+rCTggTvfAuPWW+TCnlq/0rRToSvl4eayBzqwQBsPE+66WGQDmsSRKHgLPOvIRkZImdqG3zX/cIkgrGYJkc" ..
	"IfiyE4n2swpcCY6LxrjvLyf3VJXkelPDbCGgJyi8E1DIGFAJ6IjjPNzqpk0s9o7ISoxrp67/nyVfAoMKTd2Ixvx5KOJSXq91Y8Dd" ..
	"tyx9AX1jdthqQgWaBKTExgVo2kdjZ4p259uyCS0W5kV1MQ2DtGI6ekHzjwWsu03y5Z8sEd3gboN6YGb3js/oE5+enNTbDzjFrtRN" ..
	"YZuiZYdhKUwH4nW0Zx746/dFWkKgfoQmqA8LOmbbZusb2sFbh6+vsaNXE06FUkNHyoJhgctHMtDtqgBCDMF0sUPh1OyuXnEo1ttz" ..
	"lThW3QzURhpnZB7OyitEirAotDIUI8sGZYju1U7GjKaZMNo6r4iK4IAQH+9JVQNMUvzR1cQI2R4IVT8TX9Yr4m+CpwV+sU9BGVzN" ..
	"yHXGr8q0TsSA9Xy4FylZdEQiNcCKEcJnDkeh7ChD1pJA15eEzp10OfUdXTpQ356Dk89Y26vwaBGe/IEo9UqFcFnmi3o093yyXUAW" ..
	"qR93rpbfhY71cr3dFDGKTKye7mPRi5gcsY9DcY736ohvDBy3zMj9v4fdfSXLEHECOWvR6BwxLlYdoGWaMuEDhTWVUD4c8CLbS2qh" ..
	""
local PAYLOAD_P6 =
	"9BBE7w98a/HKouyZACcpG0x2A+Mdg3qiH4AvKMUcMvc0ObJuzSmYZwjdjiF9ZV6zeY1cVLya0RebPQs+4IeclWm5vWuBm5IsQ2h4" ..
	"H5sTP9dsvM4omwn7TI37LrSIz4PJyKkowKZFIvr9CAvOJpWAXzq6/nz2Qfgvv47EJ503hih2I0dHfRJonyXcOpUWt8LFjyh/OVuf" ..
	"qq00/hhREJRAVvXexuHrp0rkaLKRe/WLRHlXNUd7W/0FzMxQ9vJp3ERe0Iguf5JH6OshLmXyad3NOuWrmZmtmXUL8eCF76ndTYP0" ..
	"Gh5djJK0VX6g/+2EvvNv0LiLfC6+Tb3l9Y0WM1t2rOdmkKVVg7xTxdHGZQB1PalCsD/8lTHm3BykTLy8VNQCze+pGM4kGWn5NQcI" ..
	"fzo6HTb4P+i8J2DhOqAI8OXuBENY9zD7I8Cq86konWIRMTikcWGGaKyKDJlxJ68PH46uChUp5IeeeQ5a0uI5gQ/AVekzs/mASiG2" ..
	"GC+wycJ1D5QIs5TwMBqmgNc2CYK32ST24SJq5vai0/h6vfYhCC5tZpEY50QhtCzxzdrtvAjhGyySn4Qrnv6zybWjBmirOrfndZmQ" ..
	"PDaCrl9yCriSt/FGnyIKhShwLh5jE6cDqdnt5S2IKmM9T5LLdipMEG1k6qY3tbHHXJfDYUHu/K8cbg+c9OxBHYqsfj0CXXXGqHc0" ..
	"97PopbYnrWPyDyCk7Mj/dPohyQhlwTYKKrFedZzPeUAUB5RBq/FIJDpuOQZ6yGcG2ujuiMcLtUPQkda0Fg0G83TsTtbYqKi90Vxg" ..
	"kPZLUXQ3hb5Xl7tMHkArvyfrecU2MtdDqgRStmMp3ylFqGb1jD25OvDnXO5jzx5O+nRxg0mF3C78TFW+OtUTajaOW8yqdcJ8ruIX" ..
	"oiQrjWWlSaCnlIdwXioyXaNDBYYDgglK6j5nKvvvdDZY+lUBdog13H31MA6Nl1nX/OhjvMAJRiP3N83eEbb9JcsBDycSeG4MwGqr" ..
	"CRaTFnOHrdK0cm3kHZcMJhuPQ5IzYlnU0WOsgcrSUE3dOfsn+MCCiUCjMEfH9MRRC/8hOVF9W2h+zyZ0UosHi/JRs9rJTXrukvHX" ..
	"AKRaOJoFRjR5WeokIEMtaDj4lF4WfmC2Hy8ht6hLs5WG3hTSdAbv/+ekMknu6lLVS7SL3xGzY7WmYtAuvexetAOvL9Yn3W04zLfc" ..
	"Gyhieo0gZ54x75zt0IcdFCpamo7fLPcW5sbEb2OXMlfVGycITAi+IMoLfV+t7XPIdfSSz3V+wCjHWbSB7EUYFQZluQmBeDMrESqE" ..
	"BahoWrwmk+PpSi0bJenLzMnXeZQWvBb4AID4X+6j3xmxxYEb6RD9/q0ugrZxC3KcffHZliIPg88LpyoWkrwEhQZ4vIvJsQ165jM9" ..
	"oy57/dqlq+pCYY4kPcirI08RmYyljWVpgH90x8NUYeE8qjdDrqwJSPb/zbqy5pdInkT3WYQWJjswvQTEyaFyL2Xswnq07AIM9BQi" ..
	"9bGicUDwt3gfzE7JoqmJONaS13uTIERQ+x9+XT7jGD+4rbdO6oXnUcainAOqkqj1o+wVId3BO4/I/+8OOcUvEzDNSShDWkTRFBtF" ..
	"iwqIH2bzLWlbl5E6uU5ejjVk0G/9yoydZfcnvrCc1VHrBHYVE+d2ntNkunQBCHYCK6fE7fSI5gxp4QWRjlk+Lmup4hIFv+eSSr/Z" ..
	"Imej7ev5WwsLBNfVP7rWAlAIas3ILc37R9ssiZrpimwVt2IIXhzYQ35bUo5NKfux4RJveAww8JzNBwJZ47tGp0YCYsquQ6aGA3j/" ..
	"mkxEPbqaqSNFtOTDRm9K9XNcSLm4KUerbWPimgXFV0sgVCuP4KQcDL7IwtI7ERzYWb0PAZOkjqTo5l+9M5OTv39suJ4bYMPCu0dN" ..
	"C6nvaJyA74UkLr0D8YeKZiNkDWzgVO6F1j4wOwFArgklZmdrSzg/hEKFueVWAGLwUkKwAoSlqmyzAcM94YPTjXW9BPkmwGL7B5Y0" ..
	"hs5fQBvFI9/jEmsyF0kt7BrbcRzCUiQiF6n/m20vXzVV5tqqln9n8/Uv2L2z6DnoaHzhOmucD3bML1yw/C8wlNE8VhYqjgAlJM+u" ..
	"I1C29mJkcK+Rq42rmPQP1CXAJk4KdC+a7Iu3Rpdc1U7/flGijNByNKp4ljcLG6iO4DkOuxIFTeCWmn/tKDJO4cnWKgj02Dz0b6Xa" ..
	"5F9Rqe7BwDpU8YSuOkkXkY7V8/0GjfXGgYaI0rnqtCx4d0EIe5458Z2i2Jz57UTz1rkOAht9nlP9zSAS10Q+ajVs3+x++sLmr71y" ..
	"iOAt25vbwbmLdpD9krkK32/tLv6mrJGfNd/kvHUuyNhJ/pupJ0gzsnwJ0N4iFOtYLa30ZyFBu9S4iOjPmO36B+vE0K0jEA8086Wp" ..
	"Vzh5WglywOF42duDtV5EQRy99GfMbkT3tBfIA+kZgdcnwZ2f2UbQmq9wxUtgm5UK3awRBL/O6DlQD+ESvwOvk1xpwr0XmE5yN7UZ" ..
	"n88v1XI8/QqdRRl4BZUzE5fkw0oCiGgdTM2Kak0bVd5JC5u5WMz/JctLOz1swX3E5Wn5NKMFpTijsc7kw4PLY95jAy99YJCO/3mq" ..
	"Nb7NfvuYSXo/KbjtJZtzBZYLPUg/t2sYux+LVh0hhdOijocmo6Wkq23sdUuFEZ0xZzEJjIv+iZjIWTIryONU6kXurK8OvyY2mUvd" ..
	"Iglas1NEumh+1vjPMaDfEjRCAKuu34pwzYtxLFYNmdlTyRt/mlAnGS2kzROvBkiPepKz5mryu8tPjS5zbVx9nTyh4Iz+yqLwUEli" ..
	"4ydTVzs3Tahmh8hFD3mTQGDEOslAAZdBBQV7SlpmoJiRKsfhocF3audhTneAa+HN16l9wUJ95FpckWuIdWOukvI7J+jdTGRCcdZz" ..
	"qswouIxvUeGqG6Hh/l32DPJ+uqTdmNiIOAL1UEVRmNXCRh6Ft7anxtweTidFL9ab1XKekqW3zS5hkrSE2/LgzLfObqQJ87X9LBnu" ..
	"52N2v5WhjTg6kM6WE1ch40loCecdtMM+AwYhEr58nLVHftHauYIefsWevdov8TlRkZ9y7/nWueUgoIv9muJXymmHyzwGvQXajqeG" ..
	"E085316BoO7yDCsEeKmp9P6BIfLuXNMExD+7e75t3HM6BGAzn/OrXeydaTpvUG4/TSkW44WO683VyP+/DpbduNT2CQHLBiuNbeZn" ..
	"f7Pg1U4p2+BsfKuOb4FAyugHITvfw/bTqIUMhggdsoaCkMr/LUR1cLZ0yrDjgeUjBGm9UjFxloh2J/KfFOIDCup/0WMob1sG+gK7" ..
	"HEs9xcI1KLPKgm/Sz6uKZQFKbYeg5+RyYV2R+KqYgC0wHBe0iA9vUHl+1m2RnUv6U3ulZaCCpntnXFPJVBbN0dt3Q2VpjapXBfMn" ..
	"EvbKYGsPZMUy/nsdWp7/2W9O7PANmyTDzvfrOZZmOfDqAOn0VwzaERDQANhD1BfRYIL6eSfLZ16+wXAp4p0UfOylvPO6IUgKK81Y" ..
	"xrUVDdHklT985GLthrC6qiBQ6wd1tsT8tkAIH/VfG6aSsB/MrGosYpupVrmnrKCHWU1q42b1QtjmHmCfFGlfSRenRoZobCS18fwo" ..
	"/o7KBbjLC1tbejZQqDdUKS1vo/wEhtANPUA7ZWjF9OvUVBsSgqTgb261ZlYY/Uan0br7rOQzSSTX+zpIDpc7KBAjQvYqTjKThRMX" ..
	"4s9mZe7VtE1PamUV6RUMp8zcHx+FSMvkeEWbQPsFtBKxUJLQZkvHO7P0kmJcBKEL34Twb8h44XMuEH5IaVthGsXSXjTirl8WdysV" ..
	"g5nnQ5zPcuOjKJpEBleGhXagq5mQyDJFyw2BHOR8SKpzXYB6+0QsxDIcoSnSsSwj4uCg1lC05yUTXQ+UbM3kwmgAWWB2a8v4Oc8N" ..
	"yZQFFsvDICXxdGctVf4PyQI/9vnIc+imbAiPt52tfyA7lLDDTwy+jbh5d1SQwb1aCVwwXBdPHVYHLCP7zjI7o+s8baeCBoJuhR1X" ..
	"gIJURkFDtNjzBFu516ps5LkC5gSdq9o/5181U3mjTr3CxkV2qwIFji6TE29uK8/HIjGoetldi9G5jf/A5J1ajfxoMCO2nVibUrP+" ..
	"d0SjYBITFJ7iP9n+Zb0XUwBG55zAK+wBxnr7ClKdJE2NCU2p2egM5XN+Y2JFzEocf2KMWVf48sfsr0lsk2ae5DHaZtvI5CyWX6H9" ..
	"8Rib6EtsxtAjI8Wh32mW0wPftxh90lXN+WzKAsVIOETz17uLvbjp04E24J1cKb9x1/69U6eks5ZFBD/3KsvRj5sijOA0PsG5qYhq" ..
	"gNJ9Gh9Xgj5xEmA/SApkbubPMFrOP+NOQnLDxZ0x68wVSj7x4MlohY83vy4guhblr0TH6B7LItYgtuggUCANmD3W+lVR9udWZUn6" ..
	"n4HZYk5oMC04Z+9KSj26aB+u1TSsBZSUWDHfFRGfbI3Z76WsK+XTHx8ZtnMOusjNAZFmUaHOVUMamGuY92OPCIvKSUglVRSx2CKe" ..
	"NYgi8NLiQSTQyzhtBsEu36PDFXv9xKFzlobySCvOv5HyDWzSCBlDzAQ3DDUO7/uhAsYaU9575GwU4zGSaa7I5Nwm6lXcd2qYCA+8" ..
	"q9arZXt37GlLedQozkdeROrfeCu4oImjZa5rVtcyvmHLaZousyItgebX9kZB7LDxedjwNpekiqX7yUs+6COqH1HEwXvlJG6V15na" ..
	"wGdsD8AFHeSW171TysciItnDp2dUajfEMISAB5DubndeIlT2eZ9THroUlfRFcSUaMfC1HumvyloGACifo8QggnvlEBIGD9EKYE3r" ..
	"KjiD0qrX80Tt9RJRmgAAmMnXC4DCUwaZwgHuTIdNT7prP5LBXgK0Du9ri9LqQndmeKf/uQk+xCnoZp5N+H8MtW1CQ0XArlBCogTm" ..
	"hkAAYH5wlSPOppQsSMFJ/zmYW9QMZHV/Bv05N1x0APEbxfdGMWKmDcZcA74pvoS2ZBcAcKpzo7UeleRegEMKxnwDVP47+2LRry7Q" ..
	"DgQ6XlWEl7zt8uVBLkHTwzSsdo8JRn3GT+ihwdRMZ/ZccORQGr9XmhOAr87ont/hIPCokI8wK/zYeyLvzfQC3c1UFJ9eJdcLLGfF" ..
	"s1Vrcfh1Jxv3LVlXVVuZFet6zysJArxz/5ecDTbpvNCVm62HzrmF3grIPUW2AchWVV/a5gcIOR/ZcmrYhlZO71YEQqgrGwcO6In/" ..
	"XT4SDhM8KiXjo/Seq4eP7olys5gYINFC9cjeqFO7j/qqUIS4vrUcovwY74glHnR+zNJkqdKSGQrchLQxbtZ+w7hLZrpm99gtqeW/" ..
	"QPfk18iQkMqkYke4LxyWxvm0jI3zaUSkO2kvbrDjVevd03iWS24aix7Mn4vu66yvUvecUKc3H+nj9XOfnzQaFY9ldm1MTqUQYLKI" ..
	"fkF3ir3iT8CPpDqkngy+SACy+imCcN7SvlAu3lx8O/yEKyi3r5v4MA3crP++cAUGvCQKuMQjnlAqZNV5Y6Mu+pak5YNXTwrSxqyd" ..
	"KgghgP9ehmGnBIh3iSAIoYLx/wWvvlINqRVI97sB8DJ+Bb36rXbXsFh4WSafFnnz/IG7hOXIyy2+mtGbkdnJyccun0f+KautwHXh" ..
	"tbRaBUWGpKg60un6hIJznK1QgT+FRvz7KFNXTv9YsL9sHbIUAal+tXzvwywEqE0PK7PSOtHHrAgmzkC1XpePAS9FC1rEH9/aHkbr" ..
	"WLjJMG3KtYDRvAKvez9jzJ0ixC6dIAf02XkckHrPV1DUDCCYs7QABlSjBwwuKYgVbLmOU68hgexIu00I2r2+4BzTRImEHt3aqUHa" ..
	"hZyGD9X9GwiQcPYK8gxebZo3qXH4CZYrZUD9K/pNHDDYWv1ZCjycUQjOpntAPAV4uBPX09vOP0rtUo+aK/CkXYkr+eTNTBbw2/KH" ..
	"j4rgtRnU5abxbOhSkk9Z7C7UWtSOh2FKyPyFY0ofMlqL8xhyr1wpkVb3c7rF7MJDrWnhxCwqYGbJNYv0ZqXs2Ki09QGyinFWOIWN" ..
	""
local PAYLOAD_P7 =
	"a+I4JfuGYOXguLDsaEIew0Wlh6xe35M/V03kqYoG4x5hKnG6UMx+Cg72rqXo+Ht4YxRm90VSZv9gXXO10uYqz18bvW8KEr63T5B8" ..
	"IDsGy2JqQbSjtU9BENcEMtW9b4TEZxWaZ8l5aGDLSgkoPmeePQbVXsXjeGmkN3g1oS53BkwNHTbZ/i+n6qJubCbrSgVrDL6MuNU3" ..
	"vgyg8JGDwoxNpeeGp6peffyQPTqddikRZiBCwlPG2/n1HIvso4EoGIEQZtc6NVMauKq5TSWs8I1lIwvKxEnKXnkcA0aXTZSsP4Bn" ..
	"Og0IEf59N/MHlMS6hmq3DBg976RSYkl6PlciHURaLoAock6jduvahoBM61XeDPOM0kmvrIX4nMkiWsfK5YBuMd2zx78L92qhb5Ji" ..
	"qnuw7/sbY8opBctpZ7CNJlz4ZQ0uQqL/46XnJl68zd2B4SDi/l5dOYLMccFieenu25WqZLLkMifNuXpX8Fhi+BBjAKr6zurRqJ6E" ..
	"WeFgmfBzI/Pf5zQnHXrffgjFHxqXlDeJ7oyfh8MkBJKbIN/olyfk+WFMq/yZvXNkv7mTAkOeciO+IEULm5zT++7xkj4xElRArOiI" ..
	"llDNDqyvRyBOK6gWfcltDxHVJwwoS47ghg8QsaMxehUubT4iZyv6trtuCRXiZR+c7/A3b8NkN2ELraoAF+SlcktRH8SVlQEa2ztY" ..
	"R2j+jvJ4r/BsZR2xqXYcAQfYH29nHN5W8dVYArEZM/saK1nPFGRZ9A8VVtAdyOV+E/qtw0lI99I9RElX4Y2tLmAA9KWhzOxbTY0H" ..
	"ns1dU+g93dEaZpNoqtbLnxARYwyvHfrMFiZyT2hHY8KgG88q0ieEgpIkIbea93MAHUg+1JYqTx/btOyCrNjikxyGvqraS4apPA8i" ..
	"d+dEjZLjOvVgpWkp3G57po+Yb6i75jMpuq1Tltq0nbJDvIDD9NeQhanoncTqgP2cgbIDDo1a5HltYHICHss9Hm6kkAI4yhwJuPik" ..
	"WoFC1TbzsRpoM4OtejbWZWR00rrRT6IkwGMI70kpzlivYxOGrJ13hrBuokIzlFnWp1lAy/+xfCXYLt4n5qO1Brvr5zoJ/q2TJgjo" ..
	"SkiyKGeu0EG7jok+/dYusRq4UGByBNHniAwfDJRxLtc5z8Y7t13yJaq3I7mQKdaahTc3ITlu5S4rDVuTCncrfk54iJwal1CBA/hC" ..
	"iiXUqfOhgUDrtU6rxjb9IzpwT0zHN1FuYO8wP9rZ/02r4GUYaaYLLaprScv0KhAVI3+emwYzbwZ3SC0ZtlkJGJCbhUQPyqjfMkI1" ..
	"0CydJ620b1OvRyI2AtkcSzPTUIFoa+dqyPEko9Dnc4eRdrO8KJaSN9UMkGcDQgabQ4F/uz+1MTjfy22LcIrItl8Cyhv3J3I4v8Jz" ..
	"peSpytXSerHuAjr7miFU9TYe9DPrg+fw6AReJ1twGwGZwOwOJD1xH6VOhveFCblE0L9BvtLxfFr1EobLWqgGAg4Ma5ZebnSEKz1C" ..
	"tbYjG1lliioV8jg7323JGQw3wtUSJyMwpFhLTxBsmOxBuslu7bXEo+sWYxPS7g3JHuqIEPKv+y6YQTPNjP1YpEWdALdsHKbcelXC" ..
	"0u9SGDBrWLZ9jXQBvaGcyniRWIqBlpKtVqB8rY1bF0sa9Tb7Onbkkp7fEUlzQihKYGyAw1D3p3U6yoPN6tqdzTKTC+qjPihjwo2x" ..
	"4gikGPySXq3Ez1j+ytcR5r9LRQfE+Dw0k0e0OpKXqpTwuSbe5BnsOflrw8ZbQYRhi7ZH012leBlqyFiJX6D/OxSSd4uCDW1YYOX/" ..
	"s409LS5k/EEkvsY52AVRG12Z8HIZT2zC7l3nHAs4CYfixk0JHo++J5v421pi0AnljeQwMcl49oRdTVxyU3sn1FhXfrM/Kne6SZ3/" ..
	"1qmgV1ElMX+0AmUz81N93TzmqTabQPKQEF8ik2sP2eOit1NIoo3+YsfT9dzzNu24HNTMiJ6karr9J7EaMYurIVvmq160AX6fKRKC" ..
	"RrQ1XXM/jPeThPrAaWwuFiKBFdIJtkcmOSSC6EiWMM1opsvR6PN1VaLyvDWCNaNZE6R0Et9rqJKl5NTbm4oKnfV/CggORJ4oS9aY" ..
	"exu9z93SNCbi/DquXs64Svw0hGNO/bD6v/jJGWma/651jTbAy/K9qsQbBkNXg56yQg7SCFeQaRK5MyUj8JKYeeziipIn6ze+aUNI" ..
	"Jg0V096/f+mi5nLW9S78Z2N1GDNeXyJ3oMK+ek1qjrtJywgAgkkUbEMAI7/Vl8UB+sGs7/tfjl5cXptHviYdfZokH9W2LPPbsPjW" ..
	"TTWk3ItGIH9U7vjDmuKHMmbqOXdwiSWkmBRPvYd+7zIEC9X8D2ft7qgszlZqm9i0hbT67opCTBdfQ/92N4YJHYOVPn1LEBlj3F8O" ..
	"48VOQMDAvaTMBm2zoYhpAO+0DXrQOSZtBn4jTxJLsfJikGZehrNlKDxV6jBl1sv33sME0BFZf/I+6qv6SjyF9LfpDHvy1J/qTTyz" ..
	"Lu3SQ2cs3zK4YXFaNJ0H1fg8gMnBfyNm4You38olydTzC8KAzwdgORl5JTe7A2+Q2tJqxutViXSECTW6+LadwcmHPDtFKurJwWVO" ..
	"1pRSCSDIRQ0DiM98a52YcVSi6SUyPOOqFvFRMG8R0O/RGKvoOYI5jZxKAtdZczAq28nAtYEyStXwIni+++8IBqXQVHRzVzWWPHZ2" ..
	"K/HwKzwk0Rc0vjxMNM304zjOkn/W4YJMA959l1TzI8xBMol9/Udayj7DSebzxqDti2oIYdiCIl/AGXN4IhwcsdStjopmXJ71+cWZ" ..
	"S4DuxbK/7EjwqbCDYn8mU0S0i+Na+pBGybtF6lcxyHc8X5iPIzLOs8f1eV9NhEHpvlYMTDc2Voha75+mFg3X7MXRFsHx8klCzQS1" ..
	"gB4X4RoShBLuSXcMHUVTMKedFEs0CdBQarMo2yD8HWHzVyiCd0j5Elwda0rKkObkbEhkEeG3nkXEGgbFkyqm+hphyCxGPN8JaY+J" ..
	"f93A6PYi2+z4ABnqcpVY0OaNDt1RzfdHYxbhBBohWS3DtFo7kBY8AUYwHxt78xP7XkaU//V4UopJ5UNfXkTqVJXJpa15YG4zeXKx" ..
	"MWspGiuxTjQ5v+DE+YO3Yo+VQkEJ9SA2MSuTMtGfFTYNx1g95w60hc0XMsS83wt52VR+K86+iOUq87iDRc2tN8BV571cO0ZT9rmE" ..
	"kMtDEXQqkZOP7qqRBswvtVgFGunRq3wkySB1n0EY+IPMvohbik4p8CTKZ+hHNocJhDsQ9DVXjJYsnxgwJ9Ldf0DSELvuZQN/+SXv" ..
	"ePAqqNqG4r3s0KcGq26NhaPiWEyymzKsvYQ3PHsxD7GsghITfwManMdX8pWUzS+tD3slWcRo4Tr3d1LNbpMoCuBYBDYcZfqMLHFD" ..
	"QnN52j2ORoQaScAInI5mUoxdqKSQuTGsAGqI+rwPV3EKkM5EOKJwqBTui7pPJIn0cQXEHx+uBfTGspFTx26f2Kc/Lrgo7Fc6qz9W" ..
	"4B99SjPXYLY0PzLT36op/KEadryfC6ueoxtXTpq1GOhTIT/Di6voB2v0WqHDwR26RCa07GBYv5ZWXlai8PgriMcKTH5egr57hZ+E" ..
	"8Fn875GHrJvJtLclt5A5yrj2c3trJflT7Zsjec6UdRbAm4AiAEWq6SujXKYhN9121wv1MOWJ+8UPuAA11HbaLNua4hGPPp0F6LQr" ..
	"VIFChn3V/MmJ+DffaIv5nD73JubVH2HP0EOCTzzfHJenzkxWMQdLTSBPSvyMgaPVbeiNaspwDc2owJbikqXbbnknAh245UgYPOcs" ..
	"ZR0ywJlbpd9mm3AQT6N6FOOs0LeBaJVgm59YZYuqWxRNTM7gsPw9z6e2Bc052a++r/NSfn6fS5OD7LhL2KYQBbYVw0gj/25cKMiF" ..
	"+m9qbxVTN41F/cWR9Cp2ZFDGk87q7OE0H47R/rlSTu7wm2zRU2ccwUPuaEsvkE9exsZT5PLdnxlOAp+2L7moeU2XHWgUhboShNLM" ..
	"3BQHwQANRK9kSeER3FHppvDRaPuda6pqbuiN6BfGwDkyg4yhbS45EoWNgCtRFXYD+VyQr9IITRsveRqzokE96AlplSicfGaDlSsZ" ..
	"sJKnbHpNrhYTMj9Ghma/aRL1jLEf3J60oA/mli0ZInq8tim3UQjw2THR6JK4x/HS/zApDNGpmZGcbKjoD6OIC44WNG9699ZtS1YK" ..
	"ZbSe5CwQ2thckHs4TLiWvnYsROdPEw4N+ih5MFxSS5bhem06ZViMgsSCv0hjIboXKhigS2XRq8saN6WAf6wFA0hUgX0Tk0MzV9YF" ..
	"2hVNp8oJrbB8ICXLiDiJLJenAam0obzaQkkSc9osp85VwEfTELtHxAqGfvWarTct+jgEvl2KNWzLK2m6j90iWWccAT4d1nPu+FcC" ..
	"ri3w46EflmWmUdalT2TfYNGVyCvqtxai86hhAfjhL4k3ao9gmYAvP9Bskm8nbPjCW9bVqhmObjUzOaqdA87DiNMYTO6CXRnoHhg0" ..
	"YQa7+48ySX6gPWCmVbgfM8PEK0VDUFBIwPpM0UlbUC6/3qmnU5GH32QVZWa/sB6fdFJse8wmATs+reHyACRWlgYhcb9uQaiN94WU" ..
	"CUq+82ORdVJ14+2IZcGOZX4XJtp6jD3CakTbg6ps/O9Kg4hasA9Pl90fWdFFO0zW/O1K90JwcvFp1k/XdXiWxbijlVY8H1JnzFko" ..
	"LKjWhLxMkta7ZqYULSPRNk+ui7X80IDgM7icY30r9SXINk2QIuxo5twuS1CNYYAn5Gay3Sb0I4j6uWfM9Zc6GvnOlGhvUXmXhEKw" ..
	"YY5vpAll+EfLTedrRdGfBNHKbBhEpPPYV6gxxH1J1hVb8hW4Dzz5CvTdpJ0tj1trLhtP9sS5mh3a1aPb1qhJouKYjW12VgF2Yj10" ..
	"nlhEWdEjrfe5utnZoKLKDEwWewwvolJ/Op1OxP29U/S4m0bKa+P7wF4GBP0dz1NR29YzmR/Z4+MbgDMN1VyS9s3ZiFaCeQD0eUij" ..
	"Ks3uZSdkmK5bE+QOAEPi1qD70p9yFtSfR3Vj06BSMy11AGcJ9RZ7/iyvzRkcA7E2j4AOaAyXOb/PnSpQ+fVW1Qo+KJIEDytXYeHk" ..
	"9+JROjAnGFoUpyXEZJeBWpHqDrZuALDCRFvih7Vx/3TBQSJbKjH+JsgwiGdt+DAXz8iWFJKMTccEvBttsmrzPzDTWa0Mq4v2yUXv" ..
	"qkRPnRxtlmnVXdN9P0IbCYcUtiLKtOSZzJEi1bevCbjzcCft4tHYk9ZvNAgEr7Apn/6ym+eurlQFSZTNIfmVHj/5lx5RTLCc2oOM" ..
	"xem4/8PucfYoKiYPhbkgLtOYLIaUom6xiYJNeAvYd9b6TIWnuz9NQx64DHPMhJTIKKoAXucDrvsbPPo6k3r6hXCDs8ATp7pUGTXZ" ..
	"cfmFbsqETmLmdHj07wf8zB+lxmqlwyrOWVI/Tlg8jJV9kqBlD76q1CE5C5tIcH6boTSmzv9LxPbTE2zQLF2rDeelEBOZEz5vPIdh" ..
	"lbAYrqWnVgVd1vjpNTFxH825H2rA0vW17szmvwJqqa7cDygmJpX8WW0Wk6IBXgjyd7ErV4b/NRoSz6OK3NXac9+p1oOF1ceWHTZW" ..
	"wYBzwrLDdwhwatygUFJvqZv4Rk/fqwv9WMPQHbWeFGDHFC6E8Gti1BTz/BQBI34lOAc1EExM7Yv72kOHEzxeTz7PWataMVfiKBxh" ..
	"xz/iydRtUoG8VMWRLKqjh5pPpNgc96YvocapHlkI5Cg8Jqmc3LvwTO/jGHF12NyTTkVVjte26h6i2daV4gntZdPBFzeYbnQMxL8F" ..
	"Gll6jNLP6IMPcHO/ywzXb/3+qUSxQNiT+oA6cLSb0SmKoVkHBWkBZJlhdz8GuP6f8sMvbVGg1CAaVQQBoo/UxxwiG3Y1NRPns8cd" ..
	"ZzDPk8lVtawEYTpdVeK2E3iHCGjvPGSJ7WiXzeWI+EM5YkrMX5kdIqi10EktLBAcnOhAuuQWphw3aFINvkMqbH+kV6GdYKSeEmwl" ..
	""
local PAYLOAD_P8 =
	"obo0QNWtNKVwEEumyKGed7Zv5i5Yh3owTj/C4VvfRJB+g+PPHRJnWVxmMSsrtVG4+yEvSHvQx4tz33evGwmF5jrAghnF5oxVFQzn" ..
	"gLWAVjboZ4NzsXp2OeuaiKMOizke5+chIjcT6VpKvhVXgW88JYKzVNmG3NSSxThwzQGLJnG0YZJZ38uGpNjKvxf0jbMq2JqApk9r" ..
	"puStnyFHls5zVMMK4NWXlqP0EgS08DkJ2CGrWCUlJsinhKYwMz/0aODmU+pprj9mDHBkdFcTBoFi+F6q5V27qev9ewTD80h73pzp" ..
	"F7DmjhgDtt9WgjqivSbeLDYWaAQIKtS1hK5VVfg/0j6brxASG2zYkbmGSOUI8ZNYNq6SYyrMXiJlTzY3nKb1vKR5eFP4Vz1xqoxt" ..
	"mz+Eo8Xeefa3oOU07xuoxgcwX9hfGlL7iKn/aIqMGV7YPULIKbgfwOPoA6l1rWHjqJO+RLB5Qvbj4BUKzotnsAzHAYufb4tjfBKg" ..
	"RRB/lOnbx3GAjNNOIYIETjHn/A1722kV5cCRli1jDdWJWr6lxT4KNt3FNhDOCc9iyyt31dyw38NDP7DYNi9eEJqiA7CFmwnJMSS2" ..
	"XtoU2uwZpgN0qWMirW9EqUdDn8dz4ra5t+i9gwm49a1cAwtzUUTrPlOnwy/qT9Ltdi3yP9JagGtd5odbyYPDzv1f7s6xq8YjLOOA" ..
	"Ob2hFMgWhBVCJAGinA51NuND9sFYXbxu/pf+afh985X8jhRSWBvcRGJvaiu6N7Wm1+aerVerTSKlXJKr+I7rJ11Of7J3J64zCWuF" ..
	"hYInKGTKSuj5QzezpnLPd3QIgprotPvx9U+0aIskP6ki26PUQ8kEFGPQP7B/QDPLPx+qwVegD1ZooaTfhBLfHLHROQhisuThJ/jP" ..
	"fMcrpKEnSsK+9q7WLJShMLKLzjymjM4rwIrlep8joiJwNpdiGeG32dMcKOME2CRIA8bE2YCXYlQIWSzmDWVIzF6o20ZYJhhixWDv" ..
	"Ha5td6r0gNIF+W7H1+60yE3675V8Z6Xt3GJEvwFnVpO3f6mXt70Xsq1XPD3g3HdNGlsuGsr5Ec9TIucdkQNyreyi86QCE72VMe1g" ..
	"/kwBM5Bc3+HBlNrc8dM1GcqfSIH/9j8V8Toa1izTZi7UEPo1VGRZMllWB47G4yqwfbS6VtAvykBgAb1EjErycNF3icewL0weGtt8" ..
	"84E54lezRhjm+DH3IkdWt+X+oKh05CUiiZUhA4tXehOtcwg1haEOs2eT99mTuXjEVn1AIK+24nGeLQpLFMjnpYlDACwq+PPmK4Cz" ..
	"PXmcyfiZDI/9X0QrJs4ZDR4Mpf2GqC2zh+QRPEt7e0o1sycf+6YdVpvDSE4ESNyJ+2DTrQd/20SIuoH+A3nEEyYTL2m2RV2zvSQJ" ..
	"HbajyiaVVO7EmP4Ad993tVGnZ0bG7Rjipyjg0/ltF9H7cwDbn8TJxEyP6VXxmmY2do0G5/xeneb9slxw1llHJBfEkVky1VQbnmGj" ..
	"BigzmaL4Z7qYcQOGb+Wt0aqZalMTR6nN2RO5hf3TF/W6QXjngbySBK/SbbuhYNBvb5Xt4a8pV/y3iSqUunKVTA+kYVwUcurvQh/6" ..
	"e9jgwx5wTotZLPz0v8nMTDFV4JEEtBlUKbzVkUdOKEmxK2YsmSsxSJ2r8IzWCGIAlU5KM02/8gbRWYl9rScYNU/pGO7lXFI9CCfO" ..
	"4xAcPyurbSmcP/+SK2sxglE6hvJZzZqohVJidN5L0MnuFeCpW7TglADfvC32X8CXOlRdz1HHEETDd1nn1zMNqq7xKWLhfZ3p9Iop" ..
	"StUe4F+5Wpr+e5I4pBGD5qPM30wWmh8wddrJzboXgny7Iw4QooI0QnxucpN+6imGrfzsqst9Pk8h65RFCkbUjh6zczbbm4oE6xJB" ..
	"xPCEyIDSqZDScEZLsi37RybDEVEU7RNAyTkvAJgUdQmprXHzZWyQXTAAT9ZT+rTneWH+kymmZ/+IsXFh3DNES96aXMn2N2/7KMRM" ..
	"FBmaCrA8Tv4Tm6kk7eqn0LOQt7a9EmzjjJCvQypvR4vx6AvqLMjuTPUoAzwfoODmcC2UIDzLsrNu09w9M4flUUG9TfJJVxTXry+h" ..
	"NzpB4WSf7XUQiHJJCFPtHA4LtHTf8s59sH2PepWls68kY/qNb2uEx87jt2A++I8H8JS6qOcO1Z2qwSvuuMucudmDSR1Awy1XoVlS" ..
	"dI+/L6KPjW9+dtH3Tb37mhonukcFcZSC7ePMQ4FiFFlauH5LQgd6IlM+GmvFDRvbhyKCz+llQFjvKdEBzhDmHnZ0/z6OctYsfRH5" ..
	"OB9cwcYNU3GoQ0GkbU+PxDG4pB9xTEb6/cbZT1wBQ6VtbA2wh9p7fiePqMB0NAAiwzXPas230q89unGEC9/JdUmH0/Ec8cFwWwo4" ..
	"qyiV5ZQspcyeO6cX60J9+/SfXd9k12eCMT2XhsVEroilw5jKrobUICMOqHxMBLNFKRWx/a3At+0XbgWl7zAQBaraDALwULMm4x98" ..
	"wPgebBWaQC5ToaSvWCDReOy5cdvsTLUkTEcPDg7AyCxXIDI60xujWUBDYQYd4ux2qx4xuhKdcGMzYEXqsbrKS7PtBYDSxR8E+kQU" ..
	"87JkfU0glaCP3zZoK9HYdULwm+NzpJvRJX3KfWiZ0UQsESIWsR9ThfGBK5CFK8IG2FTjCdYjDBDYymTPgWtZmVlmd88Unedn/Y4R" ..
	"ulCQiVi5eHz8FPoU385XMNJfn6nl25YA45Bf2NjCeNf518KsZms4ETarl3xoriyxtkNd0o/VgnXgobnlEHUc405bOUODF9oHb5zj" ..
	"cCCgQ2z0WGclHhPKt9pKiDu2KqGPBsqlQXh6AkordQwveeidax0BJ9Bw+dnCbza/rT3Tv3ayGMbewawr3hCsPjANylOxUts5ppzE" ..
	"roFXhzbpiHvf5JxQg4DNJBORTyYo3ejps5vJl4McLTgwaNs+ktYMStpu0TpKtDgqkQ5VawH0LxmXnb3AFvC8buTeayEsbefwnsyr" ..
	"sO6fjzJNs9FxV2PSb7KU19DBg5oe6FnlRFBt36NLlLkHLiOPQi9AJQhYwQ2H8u8n31Ievg4VRLY+9mRjzy35l0SSl73RR+Y1KrW0" ..
	"J2+msNg1b0vkKwKZIRB8vd0tBPMz6a7ZxqBvFWFsnCuMp0/P4iWA+B5ZmCRU+nU0sfOwB6+tADKZW8q0LeW/tmvjPkpqjyStZhvZ" ..
	"bDP0WZD9N0elsqdp9WRQlw3VuitSPS7F7YOHqxQh0cdXkDRcWuXYew4GKavbVZIDuSNgTe7LqdZ0kji7d5X1kEeJYr5Et/bfUlZY" ..
	"daDuufFQvlOEBURlwBJRykvOyfIC+VD7aJPI9Q0Lc1UH1iAtURJKCGbts44BhHSpM4/N3XMqzwDxP+Vy6EDBRuojWfsQiNH3I+n3" ..
	"DCFOy+x7PPL8c2NMlWufahbSo78rydhWc/CCbPuTyxOm181QWd9SHGDv4tg/v1dIcP5mRf1yP1F80t8//7PcXDLbObDE54Jv69em" ..
	"WiBrxe4GPdiSCJNLWoh5VFGkfsC/4Qyln3gYWofKAmhF6j97qgg9o60K5QWbL7HLPfomRyXHhe63wUlL0vTv8lUR63n32UsEDwzZ" ..
	"ZfHQCaeAJZuq+HN/qKwD42Shg0PPR3i65tNdTMpktMKf4v7CF/JHwNGmkpdm/1uE9OTamM4JKLgTN7dekxMlo6guWjCXNkGm6w7k" ..
	"gHq3yJzFZBbpPhPU7m7B2jute35/cWZwOPy5HbbFNKNYtzmHLYt+x5syI97OtlszqfcdOFu8VpL+4hBGYz68QxU2X0erlpcISvEc" ..
	"ZqY75EL5pidsipKrx+7HgeZdx9/WOlcNBUUugNBtk86rx1LHBPn8BZoQ3Rmlev6OO9zpEu0knArC4FYxGeKMptBCGcTnc3i+GsMG" ..
	"8jVfOYwXnCvxifdfQ9dFmL3Shl8XuIeJTSeYMVDZ4/DqCnYCqdPBxSjW8imQr2lGKRZUYW/Hz0uU7cv8+4HugkBOBITd/7v8IO5r" ..
	"XoNfNyj8XeQHvD+DwBZZQLa5eXP8AYtzvisMlY8u0S+aqpR7X+5+HRyqjxP1w6rDR3ahPwQ/n7btkGFQ8RyFQa3mljjUO7foypLl" ..
	"JLXYZspEq9R348ygpeTZRb5nvt0khjbVlorS7Jbwj1SBfJdIpLVAX6DIEyzvIoxpcn4We97jxLYwplHBTMy/COf7OgHSKgFRSWvU" ..
	"GWk7OR6zoXI1VW3qv2r5Xd46yVN0qMhitNx/bOnCUByox8y4+kmsO7QWz+8Rgp4Jx6fVu49VH0FV7U8hCDpAX5Ae6S9AsdTabPYB" ..
	"pSlnZTAFlJYgIJxgxXIE38RkNJDXT8zZ5Jou+EVAeNXHyLOhTRtCXFNp7QCQtP5+gZfJdcyAsCrzoaj8RDCKo3G9Ai+RP7d2I67h" ..
	"XDRCYefAtSdrKMaUqkjdu+ceCtvo6H2atFQd0D3k3K1WMF3KY9Q0WM9b8mScPl4T1uQn2Ebl18CryMxlTx8p8eHIt7aoqzJaDvlf" ..
	"hjRwfMb25TBojVozkGsWOYZ+nT+z8EhxxC88DmAS+wEWLJ5nfICG0CUbtXkINRNHD/HHI+3luZO98mWSWf1NOaoEeuSWcqFTOJvx" ..
	"1/Gg0SBBF9is6LLkHKY6wYsp0ZKZEnPae3y3uSPEz5I1HxwTKdvog6gUsHoGRglOrgK+mY1mQ0QIu5kYLKwxXuPaoqSgrWhyIsVF" ..
	"vRn2pErMbn7N2uycbYRqJLRR4g7vn7zvQzSOXSknaWv4OVWTE10S21MlYRQEn0yZjgUmpjWkW2oyQ52K35Xj1wLGgg+EXDnXaXH5" ..
	"kYQN/40VFloqNBFME2CE4O9osMcQCil/gb01v2uJw+zByl3pn0dMZy1hMImAdQkHgx+2Gi5Fwm2YUzqrEBi+yh4uo6MpysQsWSqJ" ..
	"usic8Emwq3e/cuGK/bLt9AElikWnzeNH4jWmiLDbTen2lkqUO6FItu/RHtulinPetfBOgRZoBOGMLaHhsL2Ek9fKQgcAL0WA+N05" ..
	"V1kEd1Qzn57G4quFmgUsKC2QV+ck9+71u0DRckfyKbKW6ahrg8HfUTbWYTRdRzwcwsfbUvKVNT1y/5IJQSm8CbhhjxdddXR+B8O1" ..
	"kmL4kbpOqnILXv15DjRD0kcXy93CkoYkh6ZIH8p3B99M/UTLjW6+v68PFR9Z47ZhaCLXQ65WBwyFP29g3mI2Y0xNBBga0dJ9tNkD" ..
	"SrRBs5bhCmYIhPBS3Qqyn/aBs8C6Ynu3irc+jUo5Hrj7BivymYiQLvcIk9lCVOQ94FYOSZGgXO742HpObWx6ZMXl6ihfs3REehsQ" ..
	"EerfS9yyJhw336zPfVsxOpS/rxlmy8ZTbPjB+FY+Y1+wAJEzxeIPcZOOdqp3h/awmtPAmecn62OePFm3HFizp147HDNmmg2SrTYR" ..
	"pgFLtsiOt8MlHAhMskLfQCgDGwC4eT/ajPi72PPa8c4OeX+OWYsmKt7Z2+sLBP4P484qbaIjppPqbhfHg0PftT468dE73y72ni3w" ..
	"7lqNpn2JsxzQAi9dE1iJFe0EBJux5hgDiBLltVhZN6JvX53fEQlSnDOG+lTNoxZGx8112c3TwGDRNkyKIfz5+8REmji34WUn+j9F" ..
	"M5SACwmddZa+wIW0ohb8VoNxB6VFinAGFT0UC02vFb9uLAWBwBsQ654p+YplPV4xVKfscEw4L3GJjchk0rVIOWyYwCadJaL4D8r8" ..
	"V2HQe6EP01+CTMedE52rQUtbIkGZDsXTvH4g1EyO2JD69X48VFzcfk2wKGMJxIrGFiT5a09g3ckoztBmKGinQ1CB6xbnstmaA1hy" ..
	"Ie3DT9YEssXM0hUlfTap+WVO5+F10EIjHQVlH2tyvyb34lNsyYw+uuCfrDE6GDbNXtUR2xzu1zZYL+G6RQyKaEp13NVf4x9+UiB2" ..
	"6StjyGlhrYZhbGQH2tSVG93HbSREcmjSzFh8tdsJrZDjEK1G9R1805geUyWruYuyrLmzsyVzK+gne9JhQdRZlt9PgcxgqI5/ettG" ..
	""
local PAYLOAD_P9 =
	"bynLu6Pdkg6E5gIv9HD7reOIOVHkBRdogSW0qyzwHXRw0KN/N6W/Mn9vAiDX18qdGO+kJxMFlHmiCpd2HpHry4BFi5EG5JkT9A8Z" ..
	"e5F8XuVjagRp0DlzHkE9QHCj0dU5Tj3r23QxP/CpMewnh4Tc4PgQDTJGo1wrlII+IpJCQ1Wr+QN23qqbyljyn6BWHWpHj0nMnUJ9" ..
	"lg7+DN3fwXOVFNf0XBZsAXv+H+Ko4DW5xB9LH2J1qJH8luKiBTDnZLeUyY75yg9M6aTBl4qDw5QaDh7L+sKLPuXlosfp53dvrIfy" ..
	"m2GNbxMdwKnzrQQIeiXgZ3zspmzVGrYWolrZbrj5Wm3MeMowkKwAwrc/8nJYHHHQQl1dUPIB3u/8Hk762SWJyYGrnUe3s9PSsCY+" ..
	"yO8V8obm1BUoRi0cxeetJtUHia5Ymg9zZmxv9KadMRUj0+566s0g2QkOkgV0W6mDhPlehnnMiNTnEm7CHs4Igtgg1uekM+AdBZ/D" ..
	"OutZoUYsTAk47Lf9wabhn3mZwAnDZgDGQPXjfCHiCydKxhKymxlt4idglBaqXSG6L+fobrgjixlVH0vr2mU/yX3T6C4xDlFyEEcP" ..
	"DfJewv51hZSfM7Sg2jVAtYXEndfeYwR5KaWcTc5+NwgxVEqWv+A769EJklXbKL2pyOSVjy3zYSvSVkEPvq1i2hitwgoCRCajpIiI" ..
	"bh3BT1kD5BEkou9YNgU84xqIFJLSVe3MR+5qmO9FJRtW9UWe3vVbVV2v3RogippeUdzRUESfKW5gJy6jADtSr/ByZ7mfTS/w3dfz" ..
	"4MM0S0bdhz7SQxDaepUBNU0/gEqAGbZwddkIDC9ukwNlA0H3D7nq3MgZTE1f31Zy7P/g6BuEK+0UU4MYQqCri4jofLS+dz+//9LD" ..
	"Tm5IN7drkm6zQ083VL0GAr+ZUmlNsLX5RFoytBwy6eOSlW8+z2Aw58+0DjlLu1qPaOXhF9KuUwPBB5o1lem9HtMJUU/T85F39Aw6" ..
	"7w5TFO2vVziMfYf8Kw4kr8LF+IZ90Ig5TFSJ0XtJHj8Gku8kKfMMsOdXD47XomsI636RBe5l43mkZLGZ+mnDEjddG/8vatcQ1Arz" ..
	"svDs6aAc8BYGQkmUNCv9ag2gAlBj3FabDtXGKCkCAxdHSaOqGEM8WBn8GlfrM8dE1WudOYenMoyDahZ4W3kPFsraZtgpd+5lxey2" ..
	"Mu7LXjpf2cmoQpVZROJunT+IJK83LQSp5LRVBrnx1JLFjUqlKXyaihzyzfQ5c1KfbQUUSSH9Aa1VHSSwYeuuld5XoVtlWXyE2w67" ..
	"49mFtMxzV/OIEsZanBq2hc4WR/E23shfgWFglidYsniBZ51vFfhm24dIN1qW6hJjngwZ7EcZNBpTqRO7v0wfINllKU0s4u0AtXTA" ..
	"27nj2yc6REA8foiVhaLG65YnVsvjFNmq6mOIGmlukeL/AADmoTEJQtiPbno5tArTdNVDa0wqkwfwuF/8a4QjJtVaDd4iz08oySVa" ..
	"vV9lg73X7QZLb2EsAuz5AefQDWvtxbTJuu2QVYUjtycNrulB3zqcYIjJ+m0uSilmvwNA+ha+AvouXur/XRh/8jumKbeJ5KoKRQHw" ..
	"d4cMIl4Soi2bCA0W2wvyldazU19d6vPCH5i6QFR9F8zq93Srdd6Z1prwg7pXaTCFwGFZDYSIH2E+YLa5+bnp8Xv1yTcUS01zq6rC" ..
	"qpd9ABHhijEGfyJJWWkmiy43/iEHd4bv97hxGFQNuYxQcBF+zNKHy8vxafuEvzN4OJIAMZpMf+pbkcQzc2AocA9Y+ZJBMFJvnPn6" ..
	"ighiRD+J5K6EOT4QzZqn1uz7gCyke0ycLHAhojlFPPqyis7vxS0nevwm3TJUcX1Re5BcGVmKFWAQFItKnyxd+dCOXpmB9CeBPgP5" ..
	"6YUdgqqqjTf8E86LvIt0v7o/l5VkVQ//tIYQ1Yy9857uDIu/K1GMXTcBf+riArCxZUQc/AEc2wi9J3ZT79oSj//vXQHx5Ari1OWm" ..
	"jfdJJATpEwIbeTO+USCyFVEmQkoemT9F5wGLR6eAIX4k0p/zdeUA+kd1FkFDr4eidMo64rxLEKTsplvjVjNBXpY8aUPpXs9Lnaol" ..
	"5bC9RddBuNeS+Zf4i1Cue0zwdStAUaL7MCeQ3JveTQj5PkTuM7DS0cJ1YnS6f1qx9s1I0OuPlt7TpRgVk/dodreaBltfukPTzucJ" ..
	"IcqjCxu6CJTxPHsOn062/Y5VaE1ER9NyEsXM837bhjtA6QQpQKO6O9OAkmNlS+tEXboD4gtvqlvlDRKEUlPXp+xMPCt2oKG00w8m" ..
	"c3N8l9BehGCGCuL6MG52Kak1H/oY5uCH9cFTHTWUhs2ttsKjfEWDx7Q3YAg9jowEODIwyW0+ONdhq6DrthyyAw72OXV9s4sRvS/s" ..
	"NVMZn+ZQmBzRV1B7ZgfyrSOaHPJw9jdbkkvrB7tdrjQ0b/SmKF7cD8vZnTGwq00RcOa8DhmHXyTk5XnkQ+F2tUrQIhnv7cSrpNAe" ..
	"DOtaBGtItgewUt4RUU2SzucPGeShxGcIfyckLsnsW/tO255Hqtx1kFzLIWVHuYtqei1euTIqFNVI5feRo05wz5/r1jm0IjN/fM35" ..
	"yKYJhQvFGEdApXpmSd+sTnpvZsA/CHdJGzLlBtcFnPESUOA8IQrl+ONbJjuaPlcWxwgWNOw2d55vsdwUwZ9xFi/nwPBfbS/ULjtb" ..
	"olL/rgbxAJHwQzyf+2cl0FIjJeHg01VHC4toH5Z7bnrHx2EB9Oi+eIceSBGoHVDCLFjvDah6/zQjCwIkkFuo+yku211yV0a0DBkw" ..
	"k4TVTWhyu4mHA4fYkZnLCzpqzJ4PY8b8kJrOUiU6SmwSuMzxB+xdshH5EsL6aQ2l4m40nNvLtHsIKYML0tMJNXDg+LdNVfEVObI5" ..
	"Ef13i7jkYciCIBS+iN5HZAyiDGDDF+GzCz/brpexviQls3+k2fD9hRX1hoZiOn4I2B6meRx6EDGjF3sBUoakJEtptraXyEz3kZ2i" ..
	"IHxQn+SeDMidit+GMbZjdD40MvttTKeJxows0Ra8xczPmkqFPtQTuOEDdHQ8TQjfml5+iRcHqwuc/E9tDmCz1ycS1xnB4WySUjSE" ..
	"EQgaTDjTzCHAT+Tn+QmWcIeXXFyf5ESTXIbYMqVo2LqPY9bsAvjMiaoDStV2li2HsNuzqHZ+DjPP2u+ENc5ha2SNGHXYOg+zPXRR" ..
	"4/JUX9kI3Dmw3r6A4KEEE//wthDj1Iue7XU1vwsRUg+e3mGnW/6oCLWlBnhv/r/hpV1ZckV/SjrKloa4uOn6m/62Bcee7k7FjngP" ..
	"xY3S+zhyfiTZdGnUNcV5InvepwIt/goGTJ14Mcm0rGVU8vJoDjw1Cah8CQ7wxmWTaigy1Zq2a9hg9hlcTcOsRE3cFmzNN2ncFApW" ..
	"YOVbKhwnCM6ymSVE/Xmk6Z5s9gWF8brDBLWjMXuV2IpXYVjH+DePPeGF+wXV7Hx25l44Z/pXDasFe05woIjZtf6WdZd0WBGSMtoB" ..
	"W0tfItqCFg+BmyQwITADfFjlO8Nch2aq5PUwXaHTW1RDUIXXTYo/MVL2kjl557HQJ7GE3OJsSesVt+i7EjfA9Ja6s0A61wFMDY17" ..
	"ja8BurdU1POE598iSrUugnsIL3TTrAcAvg3yWIj9/8FEEuz+6rgKRnzGPlaO/X4aSlLxwTW9x75ASJI5Z50HaaTyBf6+9fiGiz8n" ..
	"LwUx+7uMFt6T2Gvx026jfvF7IxpATZIb7gaR8tpXoa55pVofwIz6reHyAxphmO+UUb8sJH3CHc9Jyqp0fcHzb6aWt0mg4xiyuHkp" ..
	"Uz22e+oylzZTBXOe9sWD7tAOCx35KBgKKuHHfEM8x778DdTjh1fhzVkMt1iLPB8kIyBVCy6aeSXjSJK5MjjuZ9GpcStnTDO0NBcc" ..
	"8a0BXatPDuNPLjwlsHG17FR/Rs+v8R0xi8tS8LTT65Q2EfU+35r6ZrULFTpOf0SMXt7SbkVt7j6iAyS3ksy+pluGJS520CMRJUve" ..
	"Tw9dFJWo7eTAsvgKOMIJj507YFCAwf8QAz4nG9Defr5vt9cn+fRsQhwrxlgRUytH6TWUoAGfOLZOmQZN0LVnt8421p+IO6AUYX3Q" ..
	"5eDttV0oz9IGDNn3rZZ4At2CNq6tZ2p4UEfJV05tfjWeE3wF1FIWX2zG9Mu4ziYnNWRf" ..
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
