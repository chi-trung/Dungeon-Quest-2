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
	{ seed = 1544009952, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1551882486, exp = 0, plan = 0, hwid = {} }
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
	"v7+xKmqiWIVM+zrHCE1fujTlIicDyyJ+8ahH005cFQARixAv9XZpuZbNH294wV+eu0ApcWd3RwK6PQqcmSH3mVYgAgvIiuEknAth" ..
	"4qaUaDfFPOzf0/V04XyVN/TJ/8RwvYrEv8dbwARPS93BKUMKPYQh36zoxWJ38TFZalFI+X8B7g7fDrpgeJEfsukt6VWW34EcvKB0" ..
	"gzsAWH4uBsQw2iqSlzM83S7nBAehXEjG5XNrILr103wAsfHB33ao4RVcACzSqGmiPdtAPGIoHqLFeUvV90PO+En00SDIgKpXLEUV" ..
	"FmtdTsFy03F5l1NtKZr5Rd79OgjZJXR3vjx8pLr2fzEcl/CwWqSbw+HtGl5iEgtP3kPujSObVBCT7iIHmiPCyotkOwatQF4Ev1rQ" ..
	"D+z+YYkwDUTc1dkGrgnKHx/7ap/4P+RH7HLVJft7cGpz9MDelXX7mUSJWJ+SSihIs3FiU1vVf1S9Y6i7JouuSiCorGv8eNXX/L9v" ..
	"lk/QsJKKxTRA+ddmzh1Td5A5jbABG4vqvT57UQ3KkkIM4gR7C4h/eoIjkjSwcXKukyKTCFi61RP+wO7mFR6ZAyzvsVGLVP1VJjm7" ..
	"WHifQHt7cI3OXqenFvyueKozpqbxXLNw5F3EPAkeLE0qXveBliz9cUdPbq7hr4Dq+04py0KljNfOW3e92harCLkkiY8ejl9PZ/eV" ..
	"nA5+G4oy3IkPUsE6q/F4/A4u92bQ8CMBy1qowI3PFGtWNob3pc+c9qZc51pOg6sbW7Ptha8eOTuLVbTQk2g94bGi1JzKCIrZe/fN" ..
	"jA6nMLbpPkCso/OlXiTB9DOYmRXt7xgxkPdkfoVYq01KE+a46yLK1ckMfu1i45bJrlb4Vyfikk2xaH/Kmk3i8qBw5/qpztw/xcL+" ..
	"bgZVZ66GTffnUik/QWOgEx+J3yU+zry1yYL9a3nnRcesURTdP0ZJz0npSg8+8guJMlqSWtpDYD8IGmj6BAloRf18znYC69WFsQ3g" ..
	"ct0x+6dhX3yUY50dc2l0m7a/NkMxZ4ZjFs4qIpCSHGx5pQiVbWomGReVtg1b7DE+vGgz5darQL5L05uVKKPdMAAVnPMOtTI1ngnw" ..
	"vvw4Nlk3uJOU04WlZ/ZfZDJFD6g9eZumk2j18khdrH8nfIx/slT1YLs/ke/0LGejPRBUg6vh9J/M8WgUxxDiwaMtjAr92Twa3yPU" ..
	"m9+Ln9x3gB+QyG51uPJkKNTO6uKadx6A1vXhu9B49B2OWBeel0vbauK2ySvtPOxiwkwHVgGAlhmDA3M/w8jRDNGzmcoh4cORtUdc" ..
	"AbFdDZtljnqWXvEr0IIUJ5YI1PlrBul+urFLEObmR9mR65I0IS14LOctRFbvenTu+3uxRYu6SOi9okNf1U9uRN8BZO9Am1huOv24" ..
	"ZvAunaUZOIoXSPt4Mfufqm7VGnoGKwUub0Rv5BVPjlAa5/zeN+oVwy3KEYnoCpAn6klV0fqsDmgtDUsSoBzaRIg0IYnDFSkWiI+c" ..
	"QeKOxd9V4kxfoxfCXeNDpoEbQ35Z/hYMdMmCT6FJkHql19I1v/5pGw3Ey3z64+K7n0jhyGZLmKCEOxGfAHktOakZ4u/JUvIYrtT/" ..
	"KUDBhPfbL97HBkkvdjZXZmv+cVBpimca943GF+EYUryitjeEm59NdXHRXCodhVgWka+OQVUbwZ6idNPAYTuUKNYHGnkTc8l5f/W5" ..
	"q2acmaXST2fe9M/hFqkt4rRfKmm3a/BzilDJrrsE53dlhCentSzhhc/ud/4JJ2leBm+zQ5Yq6muz1809X20BiXD1XV7Geej9LBil" ..
	"zEKw9unveFurWCkG88nv77x+1Vyjdm9hB5+N2LEdP3TYYll7fpZ/KQjZCLvHV0gqo+0dxgQrY5/J1qRM3SY9HSsXoLRjiM/CocC4" ..
	"0yj0QrX5i/cYJ0blnPnQ6dKt1nsKp0fbwd+g3YfXnqmor1kOwrGaqnLSWaBFrOM04HLQ416ruoNHTGyNHHG8v5+aR+fZfQAjBuKd" ..
	"D80fJ1u093CaSdSY8Ym5Z5LqdBom02YMRWKMPv4mxN9cQe+t7SsAt+Pswn2i0MDNGCK+v0kHhiAiB3m6H5EtZ+xEI44j6qUktPln" ..
	"OfrkJxfUQApVGsl4kxSKPOn5+opMYkUriSHeNiFJCXpJgWoaZM2c0sioPmtidiw5nRYEKklQWjK5eOGfRUMHuBviHk35r13Hyg1O" ..
	"T3eFW+7fQ0eKbDXhEFN0ZGQxFl5JNzVf62T+jyBGmlgZWeb3Wk6dxr979aLI1CMo6EOGXn2BR5V/m23l73JXY5uANp9IjnDd8l3q" ..
	"Ah+bkVjKNLIXDWL2yQ0kiVcyYBQptndwSbDTOv7azgMKzMPIOAblwWHZWh4gPMjz9k04f+Yt16qCYeyflh5C6b8K7lD3dezKFYOR" ..
	"xU4rtPOm4GCTPH8sUFF2AK9yNhnz8emPG7Ofjran7tlLGluTrEPPu0B756oo1XXN4Tjb0nE4grBVJuVRS/oSkzrMyCL/ix6CY6HO" ..
	"T68h6vyOWL0EQhWNMecIyW9HGwGUTb/bp4qfAMfYzjg2tH/0MUsvnUWi5tZjmT8Y7rM5PBG1fY03qLCDZq+Uufvnj9H2cZvXZF2K" ..
	"T2Tf9wlW//VaMTESrHT7hGvBZWmP7miPEl0SQ6cQHgdMZvMhZbx5vDa/94F2Hbf4bm00Sq17HpMW+BMYxup0x1NJFcHDRU/djIWI" ..
	"YU19rm96Zv6fT1fcrutJU2a4PU/qfdUvRbbVCAeux5hPsdTbidhhkBeYc0gedBou8/y+Yn3HGutCe+t/TuZ1qHW89jhqh8pJLpqo" ..
	"JjOm62T3qQZ0PyJSTrGQGxfFmpEfJuf6o0BB2d+9szULlrZ0MAJIqYH7VsAKK31qnoUPVccK9sPkHwVe4aFqB3lul1H8vWTY25q/" ..
	"XIm584v+22z/uZ14V0Q8TuHTj1mPQHBhSIjkaXUCZ6BMNBiN4TrQI6RcBYYVbbFkRKNabz7z2rw6Ghela4Jpduk8o64Feh+Ypw4R" ..
	"oWebC1qf491MsdKjldgJD0B1EismYDyFNiR13sN+rR0RwrKMFNrmW4rW0VxL/y/bXK70GKObAkLujU+7AHH7CPZYpdlCeL6Se12C" ..
	"r8bBa7lK38cD6seZ5mnVZbUuof4LoZTFVPndYk9MU5/TPbUPPPZCUKhi15s1rr7JPnHyuQmDMxqbX+NW+mps5lnCvbMkGVWICY3Y" ..
	"cuEvGh9iNeHpxvbb1WmKBwjgxRFawGpcRuCpxITOobOfxhzUBX/3QguP7akDF700sDxNeri+xQICui0przpsYHNhq4ZdjH/9IxoW" ..
	"Vvr1wYBbzqXroJg6MPx1qW/lWP/IQ/GuxWH1sBJOELSL57PbALfywE894ZA8SMWqFnuSPoS3wjDGGyp0OD0CmtZRVcdzkc7z/QjC" ..
	"taH36uDEBMpFQ2x0JHjqaRT0n77aUbWO/YTyuZPfuWpVSF5vQYATwek415SR6u33PHvQRkqq0b7vAdF2yz1ImzlX1gauzUXSJXVv" ..
	"M8vkncOGUAlX3lrzyCJiFr6f8jU1NwDBBJR0PTAK1h5Y4D/nwgmgDn0XRWrOJtz2bAa9qc7RbOu9GZQMU5NBMdICBC0w3uBncUBH" ..
	"QplbJfxF0vYmZfZfFiz8SUXutWF8x77FedN0sZ7mnCRpeo4dMHSz3lVa59NV2E01dUoG0uZW1P2P2XhWry52HhdK8H0gCNVv5JEt" ..
	"JRwEK3oeAfQL1eVOWoNpLF9tiT74kUtijnxSXKWL2SfixoSitwTKhqfvvJKbBdoROaS1LWnDzzw0SvIGRlIHMNQYCM7+Il4VvJrD" ..
	"CNgWpkeR3S1tcQ23vvZhhnZT0R9qfN3al5amaCmxgWG6V/k4e8rI2of2fFZ403gs5W9LQ2OIwcof8f+dFfE/Jk0nHkvazA90goBr" ..
	"oQOGMJiPba1+gvMmSJludnDwsoQ7mJ2lwbdVbYGWuYJ0ADbBBAgYx2i/KQqPcr7+qVcqbHXPjQTFq5uEMkn6/m2ZtVE3qdMTz11B" ..
	"cMl1NRoJuY0F251aOLGXv+6KcQIRly25PV36N0NxyCY+KGFQDJ+d9k6b14uTbW+d/KONqf991cOace2IGqAeFM8n0n8rIixYKxFf" ..
	"BEW9/byFsjY2PuPu3BGjg8wozQ9tn3JPc/WudpNhohjguSo88vND5C+Bl1bRUm46cR56LCE5Gb9PVkXV+q5Q3jqd1ezlUOftS/iB" ..
	"t6iZyeSMRjkRN6DNnFoYpmkaSUJt3MYZcmzRQmFwUWu+93ROW2kS+CRTv57+rBU/RCSNNmaJMAFn46B86OYVBazDWYiDrQ96VF8l" ..
	"b9ltrBTn3zmjQN+fGD3a0JHAeIbz2rPu/ZF3u5uEE6PAZ/yY4cksy/MS0F23goYRRjb6U5vTXaSy3mRgaJC+jNevlfkfTyOm1aIU" ..
	"FVIewmpBymvhnXgekMkZjve7TTEsA0gnd/YS4ev+Vy1OKNVED8+kiw66vAyYFdPKGBdmGxS+qWvdRH9vUfDnaK3Fiv0Faus4z6x9" ..
	"9i+dQKPqXrsUZAIOJs1at/3fy6pysHkzKr+FrQzDvioJEKP6P1b20okfFqFc7Is9nZKPDfKfo1rsqFllQhAWu009bKZHHJfY3TMS" ..
	"/4mkM+CqG6YXqvGPHAqRfVRSg1IW5+ZsffEYKTwl3YfQBXoPd9l2MIHUNI/BX5STyqfKsOsZEg4rBK/zL7PFrjH4R54YUpGvUaB/" ..
	"wBviVPiI1Rlkv2M3F6ZscDfLkXWoyqA29CPxDdKwx7WAA7yfcdixcbXhtVbSz/etEnhW1dnDyjLik8kHvR+JswMue+/qZzC1MjHQ" ..
	"SrZ+rjdpF2SZQhp8e99GLjD47LORUvXCyEXmafPVBtwDtQSHDiFq17sAoxP+QpVrc4TZhloCQanJcJ9STweqRzzrdlSczy/NydxK" ..
	"z9XDvBMX32sGmb4bAy90h2fcRCFS8he+/tXZRpDslacvHBlHnmzpl0ktm9Pbii54Vm1FmCxrZE4K3i5tXCFNxH/vJNS26v2XgV5w" ..
	"t4Mh8twfzA5pnZ9TvM30dqzsn7V7KMEwvOzA+UsqoGa8PTG5f0k1yDl989BgaqhbgANX9fKmEKbzoukmdE4bd78MD7c2OlZaWa2G" ..
	"tvxN8EzKWqYYMhv3Zr6ejI5KWeOMeRGiY/kHiACjDPisW9TCdrOtvspgQC88dhO+CPoohX3AFHAGmGI6dZUq7EAdoL7x2BPJZytb" ..
	"XoemRxZXHHBbtSoys9Nn1PSCnSlSpjCzyF2iYwmYSgSwv+TXju4/4BGRhgXLMTPIMxp5mfJ5uchQH1J5YlPrp7WdoEG/w1F8Hjs1" ..
	"E/XiInisK3e/kGBOOz5C4uIENwkp1X0LMehNAw03Z4qzPR8hSwKuv2oSqce9DhbYn8/J13kqKIaYEDg2roD5lz5129XsbY8jPJ0I" ..
	"DaS4P/nySc/Xq27aOgwH/ABz7h5KoRnzs/1hPdEhBvdvxqHsEoKFbRaOKizPN4r4CCZmv3P2g5L9/0SJJfW0IjFwN5J3L4gIcAQ+" ..
	"rhjlnPaytRO8OsYIMPyCJNzTXG0TN7KQXYY96bBoyQA1HHc1OHcjCQGvry5Gz4C1MATPVZ0sQ/98K3F1cQ3gT7QPEruel5wjfFPI" ..
	"OdPOGBhE2nD1UFSGy2W8ZKB3rbVGff8MhHrCY8bOy/rlnzIh8pPKynlHtagU10QqmnZUwZHRUms4lwTRemBKXYDTpSkVxtZbefyV" ..
	"TB93ZzqzAdQa5tG1pRPub5d8sUYIHpRCOEmRSPvviNGb59IhxfMJub0TM68RjLgkTSgZmyR5Tt37jWwhRNWBW+DU6Tpz2utS1Qq1" ..
	"xBwzLSaQ+5uJ3GwzYnXw5dRZOvbUFCWw+jFBnVOTfY3AhKUZlAtIH744S0C+eFqQ9LfWjEvv9KPacEFxdHf3Pza8K8OQWMVIJ/0e" ..
	"R6YqkPFSvSUL8kXRVkFSyD6TCIbIBUehNjxziOOxyJolAs2dqF3ML8PYMIUBd/NUyY4bd4SUUh1Y97+bJMJcHWyzwbHBuivGjich" ..
	""
local PAYLOAD_P2 =
	"B6ilDDKhRDG/YFcgVQ5qqIXBrRP96lR9J/T2YyAdzs4X3HhQa910VavHaPNWDUwR1DCMVQvYhG6wWL1zMYUEIVAeWUh2e67GyYIx" ..
	"SaIDdd9G0IN1+kBFwwg25L649PmOxl+lOmZEFED/nOhOowIvNjyiDyP14RflZwuDZeTDuuifjLjecB63/dVEbuSK6rB/xywculmU" ..
	"keerihQ4zb9d7fdQkYKk5M2DtxKeZMlcSYyy5jwhScvrfmE0ki4alm/1A9bA6K4MXvre+ycZi0ikVFnbZw0SuVP5Yq81++mOlyAd" ..
	"ATGmza0ivJ0dgu2yUeVO/RVmw7pdNVyz7RIp9lhlepgx+80VrwcYUPzF5CcQLUVv45GTEfISoQaz4xvOVTd9h+rzevBGr54inpDi" ..
	"JGpKwQeQExK+UDRzANuol2QlZioY/kGYmEhiPi9nk93mAr8oEQsCsZk12fRotqUd1iz3r+HFtodmCKQuYB0ibmYWkaGBiFp+mO6S" ..
	"sZIQjCd+EULOlUbM4n1OrqSFGcKKOwifLdtcqhjHJTYX4oA327gBwCzSTzjlNtudhlgLlEXNFX3xX02llEAQ7/SG2vkZqDPcXxVB" ..
	"jwL74MmRfG00Hwv/Fh/KFzl2tF/T8Zkco+8y2rpSOk8VXCX3Ntrc7nBhG8IzZTIU43ZdApfh6SjpdyIWEBcCtPbw4OOVgzflw9+E" ..
	"PBXrL9xLMcBonoEjrCArLmGqmuQESO/6dnjcFCgPh1Ul1rVkEXKNV8SuvZefy08+s/RHEz8fuyrWrd/Fy3mhtSdgpvWgf4Xx7fNx" ..
	"MEMKRtfr+DFHK7eXzcaSrMGqwEMtm+yc/Qu0N5iWWXcDJSWeKaKu8su9isGTg7XfLmYzhwWbL+J9r8tHjr6LtBOJqo8W94httPiD" ..
	"naiUaPyKyQNdIZj/kExKfPy2YTJo8m8ex4J/fm4LzjswcaE9z1vzRmYauTbVSL2wsD/MDESOgjL1pJ36cplr2+PbWYvVk3Qx4K+x" ..
	"ctpCTVwYy9YbR2JgC+3J+FHnxq7E9mJLcwvGcigNhryRQIQOpgYR8kMlx+6tL0bS+yXuubnCxYW6JczDcCye/tn/nCQb9GDEdgON" ..
	"tfGA5eoZQNCeo7oRHJV4QjYdzR5+GZI69gl6uvM3AE5Yn5ar718oMIic/iNF71iHQPWP03qzjrS55bonidwMzmVxR5Kpg3nahi2B" ..
	"btV2nnp+D+0h8Q1x6gnKZvuyhzIStjvmyo24sS+akJiy/HsMouqxnO9Tw5Vtukae1UL+xTMqyn9nqkHafhtTsYsQkVqlz3Y7OPIW" ..
	"B2mx/mqz9Ozqs6XU+RayaUJnbjGfRH5hvXzpMffbjgAZkF+DNxevVPVOm0LOxw70g74oYiTDxPemCDpVAs5wfjcefehT+km323Q3" ..
	"M419rIt0Y376+DRi0Ng6qYuM6Em6RW1clsqonpvrqG6t6xPclUaBgMnxuzRNH1RFFF+S4zK6RGWRUd+8CSG55WYgm7NproH42lMU" ..
	"43S53Mrdfd4euZKZCTvAjsX0lnsCCfzWzfeu2fhtXvA7cEzVl1A8fhtuw2c6I+hHTnfR8kJqnnxabt1+2oz5KZgSTM7PQef3j6/e" ..
	"hYfEh8MyonQTri9JdTDObKKqA8Opo0UgwWUgad8NizUOzV4kdRsmJ4wBzQOMM1ZOmK9dZgodi+Kghm8fcdFotLMc98DBYCdEXYtm" ..
	"53YxSHTrxiTzWaGzk8ApDvlBhzASzTJf5lKpFqbiiPMYPxgijHrpMARu922YQdL8QlhA5M6MV2T8JmFDyzvUE3malhD2bPzNscoI" ..
	"4Qui2BNmgweJ9haS3joJ3kiD804efIJ9saTtWMUxx+9i8PPYFL4bnjzenawjFN9fGRFxOxDpMHzBuOtiWJs338di3wZLBXScQQaH" ..
	"B5zb4tjLT5+ILs/1WKdHd3UaCe1yGi2ep4wAR2pRV6ncGdKvtya7QqcP90560pHOmKjbBDHGeJdR2HES07R24IqKOaaPq9m+6aJc" ..
	"DDX2D/j6bEMU5eXoprvlbxLu7JMLe/sEnId+tVUQi1O4KK0iKYlAlfamcuCwi9Ri5GouUer5Bh3oE6ktZW3cB9RjRb3GYZQbxV3b" ..
	"0IaTFTkb55bftax0S/nb11ZAbMIHuLFI3E9K8vt3J/enxcpESkyJouyJDuKhnUUMPyBYirAA3FkZp1bBJaBU7Lv6XGBD1f/i97Sl" ..
	"YC/Ko9+RWh7VlBeNjCKxcygwn9gTwjtWbjCS0fEtlwnyzY/6QfJpTM51K5sV0wpv4edaCY3Ady0ibjAg8XpoDCwfvShWkUIGhuEp" ..
	"VbeQoi7Cy40Yz6J9Bb677KnM6u42dQdqv4FWpC0HXf+HtwLtPN2BBRCw2RW6dtaJBDIt1EatZAh3rlPEdLmBQ4DDVE5ddkW0LpQZ" ..
	"PqvnOlrqs1Naxp9LPi4GCX7KAxt2nbpqylmOoN5BPwlSJSbXNmvTKejYV/uMpUuJGV4qgJ955ZAsOXHJPuJrPoAvaj1Sw2vCpcWw" ..
	"ZTm5RtABny9reMhwkzwazP/FwEBL7ylhXm3osyT8/hrAvQJxU9N/MQZ14fyeGeEnQAraWpZfxy/mMLvxY+OiZDbpuOYKi8t0jw39" ..
	"isOiGi9tj5GUND+46Xo7aoZ/7Fgmabm8O1LsRcMiDSeIrAZEtzB80aI1ZCquKUvUUVzK59iogAzDzpBGLrddC2Qj00Pwb59j/PRt" ..
	"BfuLrS8HIktw04Qv1rd3Gpm7KOcZnSDQY74bheK8SA9ClX10J9j1TxTKkx2gvEvQLUUMR37wF7kSYwLy8XmkchtNfBV4flI78Qw0" ..
	"XRJNGMiX+rsX91NEaqiLYO9UF8vUMwxPY8iylUpT6nzzSY0WE1aaKBZOMzVmhrU4Ujupf3ng870DOwXzQi3m8SHiFZ9O1afx7Hgr" ..
	"v61XtUT3AdCmnE/evE8x+o4Kq1Aw4eH/BRk/boex7QGsPoHpaF9v2oC9Oq3QtDGy65j5Cv5NXd/D6AnMzMVaQ1YZASjMtjGFFISk" ..
	"NGXCaco2JeIQXA+tRK9H+fBbd5a529X6eiJ/NTT+2bQG+iJHCtY/uKwmjp7gc87BBMf1pY+VxPIagZa0GrXiJ7brePSX/29m15U0" ..
	"NJQCt1S81osct6Co6CA06OlvkkmY5jCDi6UjWfw9enU5Z6NfdnddE7Uj8nn2Ly9d8WkMYHJ0ZPqqplr8f4z510jmfrrGEQYPPDsa" ..
	"5pxlXPTtp9WSJCkeD0YjQlpK1+6sIIYWVLTliJ8MHxYFmlzK8eC8PBkRSYuWyuafIz5/aDOzJ/tTKIzkKlsuUJFx2GsC/7oBC2ip" ..
	"lPFEYC9dOg2YLhyH3g4KZLhlniIUjcXS6Au1FyVy7CaMtl4ooPCs+gKu6nrXdtkiLzdLnuSDItIjeN5rlYuPGOBANd+jEAcF2X7D" ..
	"LX0gpRvDyad+1gsxje0GkGntg0KAvQPXwYS2GyC+ysmMJAL/p7ktxQj9H/KfNhIIDTJK10MJQZpzvBjzbE2Lq+1O9ShA0Vio4HD9" ..
	"kq5ebqyGhWghNJoAyocc9pPLk1e+DuSWv1f9xI7nqdt20piLvhN8ltr8Lr0jUHtQPcfQaQH7e6wA+4kCZufWcAJleE6mE3V9eHrB" ..
	"shMaI/U/9bnLDT1acNXdRdKZ0EyvQ7IcPq3Fp91P2x9nx8AA6KuOeGggtfKAZEpIf8e5WCgaAxMZvcHS1UnbImPh4qsrpWYG4In3" ..
	"KmfaXkYe661mVmWiPvv2rPF65HGLoncSfVXDcD+MOyVQY9KOqnmxtIBHBxkPKoVnZMe3uQkssa3U1O97r2z8RxEObez7bRauUjN/" ..
	"mTx6dDzvZIVBSmQjubvx0W6yIInNHd+TBentKzhYEWQ3ldH4hl58/G/UTQbV8VGib31WBTc5B7vImQ48p/qs4FjyYrXBp56aboRJ" ..
	"urjBW8v/WIAs2ZjU+7pFV8tPMaGKJQ3qk976j+T48MN7zBZTjGLL4IaNYIkW5WjjF4hVExW3Y6j6N1agC57kiRVHWlYnHobyzuWn" ..
	"jYz5VGussXOZ9AY3Hr3Z7imfTt6j1cAW/7oWVM/awUvUeMw2a5ZmFNRsZL1J80ar2kWrFtTwwbs7+4WpzrEh+fNBy2CASNVjBUFs" ..
	"rXFvJl9+cD9cHcGrQKE4cnxuB1Ggijdds7vDLKO9/w8yDNnxucunhZwZc+lt7ia2VRRYpYgo0NVPtUNWVqZNxvOKIwmnqv+3X0CE" ..
	"4ABUnYncHMk3BNjZzUekFnOXE1d/Ewh2foju654bjjD0ZcDYNeHzscHbm1Mglf7I4/pOGCkqGC4pBYXAxZXv/v3dWPTtdZOIChKM" ..
	"v9/ZmVU9A0xJs95xUYu1lTdPyTTrO4iP0bCSIEAXoNogaiemjf9m/czZnNcbbbqjwRAQgbOv7klJ1pQBfMoponhru7YpfOQkU3ET" ..
	"VCJeN+RcoAIcDsBfUpmYkKb173t/PQjMTPuesi4UTY31fPGbSHIf6QrhuoOXihRslglAH6+qdPr8uFcma07Pvc8GNPrHcX9RlkeG" ..
	"qYhNgYuekbLPLDtwKkx6xcDh9bpXFcnIoIjAPV/1nblr11gw46FrPp7LgQMHtW9WBAyNL+n1zk4uqnWeiBxaGAI0Gt+kBQEM1nAJ" ..
	"p7kD+J91CF4G6/70wA20FZoNwpbuc1w/VcNo+XbHx4YPIBPFzbN3rkSnVAAlf84v60UPh29AhKC6OcbBqjKVpUDjyDcFgDnXZLeW" ..
	"hZuPM7C/utr5lLHh3DV0ZVE12DZ8PbMv4hQVyMJojDkUlAHeuQgNrnpmkcD/zNrww13bbQ4RIoQNGmSqnL9nNodNv0Wv3lvMzjby" ..
	"O6WWK9VJs1wQ86o8nTxt/Q+icQzhvvlv2K4/Poi5V5k/a4vlD0qxnqGKDXIzRjtI17hDdCNWMiIpt7puA4uDKdA6C8aGTfoP9HhR" ..
	"OxQLkbPpCDsWxv4XNmHJSUGTEgVsKk5il5vi3kEmIcKWy7V6Xa55qAFiicdBcz1ZsFLhiHWogjlV2NTr8MXLao/gn37KgMZ9Awko" ..
	"hKIjrj5vV9A2s5RGjeIqOEV2Uh/NmzWR+y3gYEg3E/6EtZHvPKGE/b9w1CYuft3GgHGODxpZE3uFGjPEfkXRQ+HMqvdoRQhHHBrD" ..
	"a/jIjX0LEaiCGDE+CYfgNQWxpQMdICBbPuI5Kw8YGjX08kyfjTSb5TLBnHapNsv6aNuD/rdXPjzTZ5c8uv7QxXEgNNe+p0BQ2jfl" ..
	"4FNvpdYdPKYy0LCoiRIiIIR0DA9CzowDYmZutsNYbeCtBrBFqtrqafElTPWLbqbZPoe9QtmCe9YapKrG95JpU54xCs80GuODyjk6" ..
	"rooGM1UJSF5pb83LYZtc5F1yBzLrl9DCkuAbezR2F1gFsH5gjSdGvNuLv/Ax8IayCDpFoX0R4+bypCP+NE5+CzVxkKHcSLmIDFnP" ..
	"EFb5yKuCtCxFuS2yGITnKNE/RAqvX71wohnamoheZ+6e0I+vTeGS5Ds+GnPHBmwAecgZNrQYyn7bAVLAVnzkBAhcWwQrK85OwLzY" ..
	"v4av1XMVFIIQPRC+YTNvdQVg5RMKGcipbhmLTGQtqkN7bgFytGELTWOdkdusHKx03p7S8YO7e47lZPPkqElvrnqteaTep9jN7wiK" ..
	"Foyborp4J6BqxRjsdsK1/RNZBTCv/vOnfpP4qH/Zf2KsTmZXZprH4+pA6EvWYodDwO+T64ZT1X0RBJv0xs87So3TF780c6sBY+Ad" ..
	"etI3r1dGwChUc1nU5lAcEtPuKlw4g0SCfy24ROUZUgjL3rq2SKzIDG7bLPqobDrLojz+gTAyBdCE3o3DBLGlLAmbm1ijyAiV3cvN" ..
	"44e1Zeyr3Jlx47r/dv097qpKsY3lMeVqNfIEgGg4VPqf5wUT/Tq6XIh0E7r+kHRqVFlMfOlB5uOlY+ieUoTUIqi33tG1UM+2alAV" ..
	"aNZXG2dE6fkOTV36hnsKxSQ2dkU1GKNHm6q3b+WtufCIrs+jyxtPVOUZxqVK9IoK9W1JW9W1LITkDnXNFJLoIwcDSywa1wyDwnYy" ..
	""
local PAYLOAD_P3 =
	"6UezZomrJcYj/2PDoZvHVV4RoROskuOiOtKVKIHbmNJ91j6ZONMrh69UbmRt+6JJ+N10iYrzZjWQO25yJjowW4DNQH7/FkCthBvk" ..
	"Nw2nCX09W+uenm83yv3ZTp57sMv9dA8AZg+H6Ia0dwPDhacizF5dOHdE/bTCrfvbBDHZ6niaNrTob8wVhV5XCmBG7r8oFFTaEG4p" ..
	"52AbwPMEI0J8e/ypBPsmgiCtPGXlkRNTZv/CSzB/E/mEQWlurH2tbpgI6/sBxbsp2XKsfDffo9It5mycjpJBFOGBPAFK1f+Pc/92" ..
	"2y0IIiXGVpUE/thfhoaQ6Slfg+QELmL+W72/9i9qyqoqshNyKTdVvdqBEBuODXflIsAk4CGsPhqE75m8AZt9PaysB9F/O7BHJGC9" ..
	"qscIdLqj9R1WO9JSKkUVOlOSSg1WoahzOQ6HNKpAM5psaJSkSYreIxhFy3qBHAvTtp3GE7sC3WrfNh96x/rKCdE8hr4OdqU7BkIp" ..
	"d+K3HtCV8P7X2Ot1YZPX9jV0RDNAKVVP1FLPCA2UCBdrCD5ADWdvYGjk4wsakUiWEqznRpU4YesFbFB5eQMoDs1X/o5YE8PjBG3G" ..
	"hVPlvDsuSPDf1Cnb6skOruL2ug63M2xoUP80MfSEwp8PsRF5ga9DyuxSVi8kkvDtzC+t78MObNZtbyQJZLB5tdy+iJqT9LK1OEUJ" ..
	"BtoZsdWiVWyQtzASQEWO9UqWmGxwdTZp99N0U4GFYrG0g3aPNS/j+2p4jmmZMo94SOf2jUcZEIAybx4RTb2qzhriiZQt+YaZZWjj" ..
	"RDDzmfdSvjUoS+E49EpNC8DXBdnS5IQTJF2xkLzQkZXgD88h7ggMCRPyXAkwcChgdSbeQsy6oKZaXNPaWmbSx6RYhCPXafkVTHGc" ..
	"+LVpsco9JBKwTVeoPGvW0ZqosNHVtwBer1Ozq/TMzBI8Qu2JyoLtPA4UqNB146VYexjsqUgg2dLnGJGR1tXBd35DOXgsCUf0K3qF" ..
	"6AnZrBaUag90PvUBGoUooZ4q8OkIPU2iBst9AD51ppLTY3vvE6VG+rCZcWYAPY7PsgiQSHsSEjiu+SgeGifhRJpcpCJhEwteXGIW" ..
	"it4EYCteI8TpzG4hdbz9BQKNJiCGxjq9wYbhgVFU++T7prmm1FKIBT/hrwg9mN71EHy73jehE9ILHrXtfWdAF840AKBet9UChX0c" ..
	"1+7gCMPTFUGBZ2rYrHjimDY5SCl6JhtclL8TsfYJBRg2ukMO6CyQ4wfSTMW1Yng8uXOb0MoAe2qgmftg/5i/SMAUKRAWSwgHbHYT" ..
	"hT+87N/z44iIRJzio+KMMuvSpRicqaKNtF3UnUOBT91jV2/SD93dBthqxKe7027iSDXRtcg+Zmlk+ltr0Za8tO//XlT4mMbEJko8" ..
	"po60abGEZc9yDjbrzkgQyruKl8uWm8CeZi+Guk6PD5tx0T6/m36xrlLHFkM+jgbj15KT27LXq1Xuwaq0M/lkyzS9ITYQQieaU0Rr" ..
	"psInXd3Oqf16WSUQT2K/LtB6eCqlbNeytrK7IC8rP9oRK/yCeuTL3nI5wNxhuTusszXSuLQLfMs0k2di3YMANrm2fl13cDmptZzI" ..
	"6yeQqLC/P3GWMrRmezzteTCxoAUxSqvBP9bxMER7ON9yFYEHHdofXr2V1YfPZaBrz2RG6MVbvr5qoGL01pjS1rKCxlT9PxJNX3wx" ..
	"hmnDih4Zoyo4eHmOCzssbP4nC3gT7nAXDI+4i9dVk6K1FDs/WNWaLgdHEftt6e2Y++FqF/NEPxAyihDIciKBsUXHAiNr5vpOFO/4" ..
	"Z1fxG+1NAVdmV5cYeVpZ6ARiXpyvOyaWMqVqW5f/F63EJyJctHAmJhgnahKpLCd/4UZpED+e/gSc8mCfOdjeRlOT3lmO94IXOEod" ..
	"vXTMy8lqT34XIpQNUGv2eQEB+m/JO8nP+HNyFabxOatiM0Q2CpvyyvKCpSOegA5hnB+0rJChVkuUdDXPuLdVJAWAkSJPNR7cSH6q" ..
	"sCkxz768/6DYX2Usnp3Bpzwluh/gm6IUSVeq8rBfDqi6fhN45afpkXr35NylJ7ITBlm64hycqYM5US1+kp6x75gVlEifETUeonxh" ..
	"M7bQyknohaz47yKns5UjoIs1clz+brxJjo2vah/TvNxJJVhGca/FjswKObTPLepiHlw/7OxdbGp2zocKlORBNA7bIyJLi4sIIIEt" ..
	"ZTX95kq54bkWA3PMVnfAJL18Pj5ovH7cOD9KrdLCyIPP6Nq5BkMj4Mv8En6MqprxL5OJ8AjwxxkqwFzFY+pw43XoG4VTJIMP8bCX" ..
	"N/187oT9QMms+6HhYbdkPHVsAP3xGsIXh6dbcR4TBgOgRPKVJRp3aS/Uq0oLIvxdvFigdba7kiaYwriu8bsKt/LD8gMnIWHHI/xQ" ..
	"QfnK3HeTJukIac/d86dLvsKAXb+/4vbqyQdqd5VI5MPBCa3s1b+VjKOql/fdvfFNPgQMpS5NgiTx6L0YAn4VKTaFh6a1WcZuGJ9i" ..
	"+lga05uofv8/dETKV0zodRO/anISnc7RtUHesTB2V9KUMBL7NQVu6UhWy6IG05BZNcvavz29r2oMYhhLlqXU/Czd/FFPB/g48pIP" ..
	"iNLXLf4YjHwoIuxi8CB7GA/TRfeuEEpg+rBqva1lNQSGikGDYQXbY8pRHUbDdH7bHWudRCmkVni/plwTjaHneS29OcgvZG4mbFGT" ..
	"GnuMBuhUrC+UQEJiIcmNqgvjJdj21WVou5EvZodxyPn3WBlKc8Aa7qMbJf5GOtKEVmM2I0FfKRE+CLAS3sHYDpY6AiNgRUfxnfXJ" ..
	"Zz+meza1Bmerjd3ehspB8Uw8A8ncwcP2VrZ9/4Ay+nHOIl85xon9WzsmHmfl5hrW5JrSRbfaPtM4oWJPODBvMOKqxF5HT7UVutsV" ..
	"RP07w8YS3RDtxiFSeGq4SrdJ/H+oM3HlTDFaVnlke/maT0j8meuT4J3LTIrFRQGXge2DlbBUsBKy66yr32guXjqTiDECanND39gj" ..
	"Le2Ju7q6lCFjPiaAtmgBhUfYuLsDdGHaLCdYRAMaKv1um90mCYdQx1GK96L7oVoN+9KZ3U3OBy927DT73QeYLqcffOksQnfgAzFf" ..
	"Ineco3r2k0ifBAWJgyOrqPIteR/WXo7rxHzu22t//68IwDKQxRVl20Fcgb0JpWUFqKEs4EQ8QIjih39eoUHm8iiRqTLS1oZNSGFd" ..
	"FcykvcNV5IU1ked3MjEuH376UPmgg8UG+mj1jpLDFJs96EiNZ6MR9l8I9QAoJwWkttcXnXPTSO5C8MmVaq6T1Xio01jIgGxXakgs" ..
	"GqpplrI1xhY8HTnFKZO1GW7ktpsph86HeXKrCFQB7fU7jmZyik1YduQguK4PTDUyxabkchu2IFpEbsh2cFKej7aPxpYmER725ZIS" ..
	"dJ7V8GpvBLEDTD4ZH0XaD7uJFriuPK0ESaUez4/D8tB2N1IOuIy6BsksPKIbSJTX6qB32rGHj8j8yA/Ujd17P+kL8D7whj+a9iKN" ..
	"uTwumdYJLyMmIzBXoGbrouHoQvbJiMpaqXV47oiOcwrSPnOz44U1IHvIZ4TjgkfFqoBtUZ7/OT/B4uC//JRgu0FezNeIc09rJaDv" ..
	"Qgn8ItMidBhzCSyb+wfgwmDygZ83XeCbRAt3RYVR4LbcDjjyk+3bCNK8PgKLPmzCcyJCRdZJ1vZx+hwB6lxdJe7McGlvhzCh4S1A" ..
	"CuhYy/cv7mguaAmWsqTEokTEHys3HTlw8wrcSAtCxsRMXmlTu2KWl+MustR5zm1GyK0mDxB6WyPrcUgyhDc7g2yzFTImGhqn1Cen" ..
	"MzkYjG7Dd8tFd9ecOQPCTAIC44LPt49GrarWWsn3yFjh4phdw5NMBatryxJoGTNP2WI/REn/UjECcV194/KFKdFHAVSxfk+dLZIp" ..
	"3Bot/xkCuBHn59/xTRF34xJ0ZPQw6PV14gU99RZYiUhkuICuhF6oetvF1yAVLPtuRF9qW4TznTUsIUNWtNRWh5bpq5t69LvczLBv" ..
	"+Y1n0zdwVSaOpmsBB2iE8GGaE5ErNCz2YSSmww3qXAU95AAofR8bdYN79clYh32zwqci7Li4vdBzYeRaE4DMaON6ju4jQeiNVMB5" ..
	"M1AZNdNGLk9wPJwe4EOUrmeyXC9mTsfuQ+3jFT51c9gTAVnh62qErSJSZXxfFNzzkQCiGhCaf69Y2zQ181GZesyyjNhAywbA+7/w" ..
	"uIlBEMV89YSe53gOJ4bXt8PSxyJ60ep90tXv7QK8L99VprJP+Mvi1zPgNaiOddPWR9kd44hrgh24kR+dIMNBHuQgIB3zYZ3BSPjg" ..
	"MEALEOb6ZmnYvQ20sOCL+BSjVtzWZPPuwo2Mh7+khn58be+zi1UzxGiA4yPIi86bYhX6YvfCVbf48d11cBG8J1ZOMXgWFkJ8cfsX" ..
	"TYZUpzhgTjiUu+2WqwWDV6TrBrjRjFblOLdWSKhT0Qs0CQ63tmn3AwpgBjvj57g42KS7k5WUNLd8BHKSxoge6YrqNZJ4bGzoGOdi" ..
	"GgOg4JQh23cIhYkqUy4lX1Gjunrl+/uFgEtdpmUwRPM9vmrLtmxcZwnvcZiMBJX4kbA/Ha2EgTO/G1h33c2G1D0WcTYr3fKPnXdc" ..
	"oMsswrf5KArMU7utPlRUxWEfvhIFtW0gn9lmiKLmyp4b29x4agnNoabPVXabRMzf28Rf1j7VqKfu65aSKt7WeY2DS4EG9L0itgDe" ..
	"b2JvcXyrxI8NK5N++Pn6HRR7e0Wf1Y+VKTV+12562cVv7GCalv4ioA+ZPsk+O0vKlYsJJcb3sRPhiD1hrPMKn/fJT9GDb5jdr/5D" ..
	"E6eKszHnV6LVrrLMFOG81/wq+L1cHQtieDzoKuLE2dK9y4jsQqY93v7mvJunHhjbvisblnNHFzWB4js1phVpqRADrhNP0RrAxQOv" ..
	"CUQNrZnz4JSgd+k4m7O+x04t11hHTd3/wpfQQAHNfylP/ec2VrecHJ1+GqyVH4zW4viCADwZbPeCITrfgPTuWNETEYybwU4sqwgU" ..
	"AHtGKtfcYdAhEs56gz3cDyFoqpQXaUFTKI69Sb4VvwOWDrlgnLmccWYs6bvSwiY+9ivl/CJ60U8cQPiHysjp/Hje+Ygirz0UmRMx" ..
	"d0S6U+I2yvYNAQfd5p9kvUpB2K8pyXLrc72ZBT5Qv+2/xY9PjKux452gdnoWpfT2p1v8gfzjS2M29OOhQd4ezpRUBCBPROK7bUYU" ..
	"b7yF4D7YXp9OqjRuAT97s9OLXJEr2X0X23Wl9CcY/0eyMIStyEiMXpAVuBPznOU4jqBfq81Toox6UsKFMnPp5wHach9/e1u4tmd3" ..
	"rS66rF6oSIQ3YnGk4ocPw/goGc0FSPa2QMxUXfcxTm+vv2hQhiwtfBarVV/EMxkB39GFyoQACze9EfHg/AlsjyS+ViUKFN+tbih5" ..
	"nz2KWHv4fRWgKONiIwdhnBgH/VImn6xWrdPlxqAoOvJ51ykZeaVvlXlGV1Ar6sVhlu5ukbvK75dMr9a9JbrzNIid+cE9CRcoNYpk" ..
	"ycQhe93iD34fFefKCvsWii9neiKbS+DiLrgx1+ARCvPbzQytGzfkgMdS2wp3soFNg9UnJJ57YY+ohoEIQsgBtZLr8KjTJzFz3Qxm" ..
	"x+GH8PT+N9WoVoV1UvZU2M95aqOPQVRFwmvpMEsYABIErsvLkcF9uyvrbUFPLhoNDuAwdcN7Kgl4WPDZ8xzgvNa00h1TSzMJOd57" ..
	"Yb49N6PH2QdUUTnTs4brs9+gvntDAOJv7m7MeC5FLNXC70pAz/AxuZJP3AHGAkeeaxNtJnXzTfLl2y9jgJBoJCvSDucKu8kPXno+" ..
	"jWRYsHtnF8v5P7GBgWH0pCUQTn05qbKthEc/mCTzuEJu2J8Qg5wd5AVsKSXEtJpDCDUUyWM1Aq2DDJ5pKfyNMB1WB3Zs1ppiXo7B" ..
	"LLXjiNJDH+WB03/TpbgZKH7dRxIVqVJf+K/yLmlHV2zI75wAuS+WVXbfE7uBduQTDVqmjxhXp4I11jjx1tRSpyMt/+ApMI5y4whF" ..
	""
local PAYLOAD_P4 =
	"hqEK8aXjyRQE0hj3WLuwAJ/IwwQC2B7eNMswpyUvqmzwV9VVfqDU1e79CtvSkXQvsWgKF0WVuBPP9WD8jAbES3V3bqiQ91HdsPZi" ..
	"Xgi7EOXZ7T1ggW+C2pBX0HhURMsFc8RVm/9vjAf8bPkXsG0uNgxxkE/Lb0CrQ4BnCPIGULuba6u9pqW1fkLfHZFwBOliShRLU2ci" ..
	"X1P54fCh6nrh5goMNYnIfrjI0iw2BkESenr33QgGspPgBXM7s5LbfrDcPa5QrLKAqOYKcNdeeRz792HdxEY0F/PbmlBWfllKevSm" ..
	"eqxQfYwC/E52w6+9eq5VblPRqYkaET+G5GDN8l4rKq2gYxHv+bugeWRg9Nm4jBVGcJpRTgzU8aYIu2K+0s9hfkym+zGbjh0O5zaQ" ..
	"ztxsrJIgmT3EKsCm9VKiHzWvQ4+VlGdpsYsYvOIB8j7huwP9GB0meZLVRlx7QAiMuRzatkVl2/kBAsuvlhzAdt1PsPoWDTLiZXj0" ..
	"ALWtvdfly/peEtZHNKlz781+mjD1CkFUEOKYA9PmPzZb0+38m0TJXDzYyJkzHxFECvCvX6TKx6ToECV0igCwsCluioak89MLAyn1" ..
	"axqjYmHQOkjipn5nKOh0bBJmymaMGCErvK9FrtzRlmtq2mEvSEx7H9Ge7xoVGfzS7VAvn7Y4NnWxJz/E9ggV9pJICc2ZGUccNIKx" ..
	"DpO6H8VPC6TyxqvaabhUcsFADEaPiIRrL3RFdotw6P/q2/4AoKJcXpe3lUPcWRpESuBBGbN1PguX1GKYlgZN3F3SRNwELMdz1EUC" ..
	"uhIKiJcdYZjXcHEwzSCS/mcefqna21QWslkwrwKuvnFnr3S2RmJVdybN26klcLfspZc/dyFs8XBr+oWtJrJPjyfzWXfZoiOrz7Em" ..
	"f4tJBkbL0ZUqNLeN8jqOZVPuG8QXAjzDOP86PStOVTVUJmJyhwblFYw6YTBRgxVWTfwwnvUUNtYgTjg6Can/9zwO+IpLnazzb+sC" ..
	"+JifNnSiuCjDauu8rawykgZ0pv5EnK8fa3eBUI6nXpkt9BghR+SurO/D0LGoVxgFMgnGgck/n3LfOu9MGawhGeH8lTO76vFiB5sy" ..
	"ggjQvSWKUMgrtqrtCAdAHActYnpx1TJYkqOVmzMZMeS+nYFGEPyQXKt9/pFUzzS70QkpCtCs3CNsihkHy2iDPPCS7sqJ9PlvVY+E" ..
	"eSTrZwPqcXKTeMw5q0kQIiFBm8Egv8v7G1e+rv4Pc9m/uwXtc+rd2135ixB+hWVtiJ5DU0upgSB+VK17BmoKubMgRPYZqLMt4CyP" ..
	"Ohkcobv9sj/g4vH7gkZ2A0ICXBBbfuREHoBFlbrufZwneIc7aXgYeTlqM/EO4HYCZx3V+Xy5FTp6rw99b7+bbNygckrt6COeKcxV" ..
	"6lX6sDCxxE5kOJ/xwXmQ7BNdkViXjZRM3lPCFrOMMQOHJ6CnkOeFtf1HCEwmId8whMASr58sPe+EPNHmGgy67T9YnPNK2Tv6U5l1" ..
	"uhWuLF4y1pMjmO6BQ0Dw2fmMXpR/ofo9y6BJ2TgZPSdChPT2MlwwtoITJ9eZ4hliLe/wNw+4GJ1pyd1wCbfdbPFCOTeLB4XzZsbM" ..
	"wqaVp8fSJ4lN57PXZFCeIFU0UVXPBCaxJb64SFbb3hhXCl0cDsgd8qmZIw/B3Dw/gvglHNwUKwO92/5kKwoJOsD2IMXa2IsEPvu5" ..
	"9xGwH80ohffkP5H8GvUQr2Y6SQjcQ4iJgBB6w5LCiBgd3FIrCpg2Hjfabf8PY6zYcjU+6HXkuLjDcRrSjT2U+8fx6rrBjO7QyKJT" ..
	"yz2vW5YAbb/flc/gvic09nBw0/2NYTQ0lJflO6alxQFWbuSxTXNXouMzucekSZBxEvcFE/29/aspc0SIBnl0d3n1DvV8uqQKdy8S" ..
	"xAPEocJipb7NASzFOTuglvhr9dQMBN5nR5Lp6dPedv8eATOUnjWwqiE6s0KUrpBLJ7NINrJcGUDGgc9X0AKr82f73FFMyTF3K4QO" ..
	"sJtQ7tfiGLYkv2MNBBpGvHQaP62CTT/VFakPEvEjUZdRlM9h/P8+xpaebwC5D8mpkQ80jXrPWBIIkeq7DBQMZtVj8M9KtEwYzHBK" ..
	"3r0CU5mGm0GQmw7diy+LpBchIJcs6b+Fdx4EI3w3b3TZhkL8kU2yJXy02y4uOoBnF9bTE6A6fs82CUelp9bGVp9E7VQ5oTxhS6Cn" ..
	"SdDT6HCxxEL7uwhGx5Gi1rEcyT6rPnUYXh8o9DPIKCE7vzP9EPKRi3Kj7jyViPVFT/nJMdIyGg6OrpeT192ibEW7TKfoNt3xghfK" ..
	"s7GvD0ivhgSm0ywDO/nmPY4V6wBWaUFLzim7QDaSs7S8y/nFj0uBKx5C7qfid/NK2/3rc860S1zjKyA5FewLdb8yIpPwdK3fwrss" ..
	"m5zI+jTZzaE6k+GEt8M1DUmmjvmbTWshBP0wFtvPuXWvC6hKtspaGlPEd3SgS6Wzj+wqR5yfRZ3JUORUnC4Z1toWZ4J5b7v0yCUJ" ..
	"WLuKscWP0ZxhLLxIl/o9EoN4VuWtyafhsM/9vSroH/dQP4SEnWvFwHewVOEPQ2Efhvp3BiDkTrPYnlt0B3gH3gaDXQe2Ntaj34sz" ..
	"C5o56Anlzu1jOTyegTZpKlrpKXJ7v+rQU0LzkF0KPhOVYqUF9oomrc3u/jLwFOMhZfeIsQCvsfY0L0dBwF8oFfUF0Y6hqNd7Hl+K" ..
	"wGbKfcvOGQcOCrY5VxNW/L9ArCblaWgbSlvGl/rOML9aje4bjoMWHxIJZ85x6UDtZcKj9Kspwr60ICXSuZIvuqICrgnAq7W1QMx5" ..
	"lJ0zoAeyDgqJ/7s7AGBAjFVxKs9JhfR5aeln1FMR34SRBzEPtlwtER5dG0mRSBzqlNqD/TZkx1Iwg4nxn69JhuChQHyxVbts3z3v" ..
	"/Gul4/QlQjnFLqTVKYm28OsixF+aYVXppijmn/Ppkp6q0FDdSwlhaPKmQDVHy8jjwYJ8oU6WKYHbTxrkEWZIsor6n4xdW92ix76m" ..
	"rPlExRgDYKMMa0i0VBieHonx8yYrpNqiNMtGJNT5n/blYXYO2cC5VZXxKAoswCvgrZLQYosStKIQeKT7bm7XI+nQZATbr1q5J/jM" ..
	"ikF5A4dWfvQfqBOwSkqOnygQiOCj8/zRNOJaeW4XK5Z2820dt5fBSkVotVtELb9AYfv+HIYtxnCQa4R2XTjeCa2Yhu/NDF7kDDiS" ..
	"rrvsUu0OOso707PnaQ5owjKw+NbaxTeNJVpq4X5LY6cDI8VQQhPrq5+zOEZAZR+rDqI45UhlSyGUCr+mqJ0dEtaoL6Ng6PGMb5vp" ..
	"qKvQtmz9Snwxyx9reJgWFxiOuTPw9caRkJa0Tb74KBZiqC7M5YlH+7vjLTGial9UR23vx1V0oTjNaLlrMkLEKqmi4Xyl8MNb1d+T" ..
	"+mUinS0eOeToLWOE/tD6Q7C/N17wabpL4StjvLSwdfYYYUpL8cB+9+RDQ0xE8vnN5Vvksq0U/ZHbmXRmZM7NsYjCFtABHaIQJnjL" ..
	"JHOyWIXI0k075NlWCRAtLLKCT7PP8mZcIkciDfq0lfeHlMkmH34z4LVa1d1ovwA19PX0gfYymEheHfaf7S56XftDaVV81A46mbkh" ..
	"Trt/A3yOhHeUJwCwQCtckTh9P2pA3xiyHAmqzZtjg2tB/rDAxhaeCY8cngZg02lsHAe1f3qSwqriRdRUWBXT9ACzKNNGny4vvBkC" ..
	"6LQGMvQi/VMbAV8H2QkgPrzLHdR/X93Q8LDchtJgubteqS1qhaL/EfiDX73Qk2siCbBleW+e4rqeZ5n/7ZUASkDlZfgGhMsEDJLh" ..
	"bCSFG4XWEpd6nvupt9jSRw5kS4ENl1boADIfldVa8NTaj9RCJflvzn/cA9Ffub6h4vsqw0+9mQfuSfomGUueBVlFGWxOTK4/+Uvg" ..
	"B4R6mmzEy2WS2PDnswTcA5NWCRKvQhXkeHDCCGtqvINq/OJjzzTfJqxnA4kG7eobQUTs89AHThnDH48EEFKvtrN+sqLIWkWl4QI+" ..
	"XKtsGiXdcFq1crZJmXmJ8PhCsEgT3hc0ZZ9GOmgIes8bT5vGI4dvrL8sYigKBjVRL3Qb44E5AgfIyywXGbM0/QnJYI6Qlq+TqQbm" ..
	"VsCt4Y8e1MA+h2BgKd0bU+h5aNhvCnGKaeBtP0pFsVXMJULl0qbyLhmeb5pNMtVOEG63jmfRUg52ja+G745Ta6vZ8HOEL+KyAHji" ..
	"TdlGKB5HgsFZrTQOwonnpuFE3/ObxPBzW2OCGM1V/rBhuIIgiIp+5Dp3w5/NGVNyOq28rN+lNGU1ZeIEaxPwJZWWG87m72CzdpGG" ..
	"TPQxKy6EOrHOVuuf5R/2uRiPUIwm4DaDyHIIlZi/S3HzUD2nrkYEgMZBN9G3TU/XbJ0omX55wHkGMyI3FCZpzWNT5mG3ggh17oJ0" ..
	"hHUDb9TqhBDnHvvwWVNsSA0UFrRe+5FXXjRiVMmT9MJnSLlirFo602mlSIEVPQSN7Jpv7gaOiro5WKNQb9aLOfAKQqzEimja/nBO" ..
	"HsIwJuNL6e/6HTDuNdXSZfn2TCK9ooAJbSW9zy01txumGt1NMan4vlq1nQnHV0ETynPHSoG6y11PbDa6aiL8bVTlkzwbrRQXSDlC" ..
	"KXeCzRhx0y++j4yMoz+cGWyG/s92B2XvaWojWQlX6vuTu9GVMwwRLMbweHuJz9/zhUm3aZuSQ1WT0vnjeg4+FKV8b04QDgT9cJjO" ..
	"OnZ4llOgV+2GRDAaW01o0QFbiPTLEx4n37V5W7zk5wL5BLzIzVjZewZggbLIBQNkrVz7/fG3bmB4IF4x9iBgzx6VNgB9r8+EkO5N" ..
	"gync2GGE5WrWjQIOZyarZcpII64GNr9hKLsVwc8soZcP7KPkPtvoll0uqM8ie7RW3GQqu2TuyPWK5tvIQ7xLkFKYu6SPjkNliwjx" ..
	"oyxQszRGn2nOq36xxJtdhspW0pTDR5JMaRTzrQV1Kd/QWyU8CMRdlUb1Sr4OEcpqBw74zbz5BES2apu4yKXSSqWAIJlylZZk018x" ..
	"gjgRqJ1rtxlo8Wpvd5m3nX1NyLelLIxGVVORTuVO/OUI8ef8sdchUBx1Gaq4esx1I2L5EY/9AeQr/alCqYJypRw0zR7A3E55Hd5o" ..
	"jkOMuROaHsCkdNl6gZdk3/HCtNrphlZGyOrFvqdYx0X7er+t8Wt9u2ytGPXXmvsXfmaIGEzEqFWt4gRl1YBjvO41WKCsnGrqi7nu" ..
	"B2DBJyE3l+pzDv3BGb0m9F3lL4Jp36FM15c/9Nb7YyfqVzsSpLFOc1fKwVo7B6drTzyUp53ZapDIwvTNBuKg98zfCGJoKorxCmZM" ..
	"n4x1oXhA8sz0ke+BN/NqikiHkRZGd6YfwKyZAD8A8HYANEBEAc6VZtReUMyXlg7EPhkSKkveJokHiGT/VzMF4d46DMspI9I+SfPj" ..
	"Z4hMPH2Qpggj1TDvVRN+DPG5mLhGyBJoIQ5sWx6l9Txyr90p15pkGhY9G2bFdaNVY1RNtvSRH+6W7GIOhL58PBswh8nYD2xHx887" ..
	"yro0UtSJgG4/L3ly299fNNfmoO2owVub8HjWZACbFayD6qxwBshEgWXpO9Mnb+wdsTVNdy3rdY9hIg9NorbTpOhodfahxe5lj6xk" ..
	"G2tDs32GaLy7zoTG9JcTg2Gtf/kJb6YEbA3A9uyrJvhPoJKCa8hdcaJ6NjQEdgqRTHMreRyl6ca3iXvFWtLlsxBNpeTJmg6DfBRp" ..
	"d9jDlndZEzja6VeqKoDZQZEgTjVO5F5+gB7V7D0wQG2irdZNoh9qL1EcuLj+g1xWGHPywil5int/9KpldpKX8bviPpnusIxtE09o" ..
	"swmvhHM7mu4j+DPnnLbbZGme0fzrbTKKvuZg7qH2KnBWFFETNvLNVaC7aStzAro0SxmLA0poUibUmMzK7Du/b1WMoO2u+46qBOzZ" ..
	"MsHjhxnsOf4Rum9S1t/2VuKgWJMRwTwIkfpx6cHktoX96dZ9+KSLQxlArZEBu5JFUsi3Z3xTMSjtkwxWQiT4FuD9rfcS1IGmuOMi" ..
	""
local PAYLOAD_P5 =
	"zzKegShcTH/PnBnaeFmFsiy/ajwiQOUdI2MNBBoepqnzRc4T2YnrqjiYH7GWgz+IcOekm/64kzz2SBr1XAXOlMWr+hzzCeZq2iyO" ..
	"bSvI2wYpX6V8fNXRb15pcic0slq6zql9uC4QLNhdQcylTItimwen/DzBd+1OvPe7Itx9zrOFvQUcFkTExftvH5t4r/W0q9cuZ6Er" ..
	"WGvcgKXF2xw+xzDvhJWrMMUp9bF2gUdL+Q3w7ifDjwd9Z7xyCyVTfirIEiPxl+f3vCmYShgi6K3qCgf85BJaEHNfA2ugJORS1N4g" ..
	"ippf5qC6q/N3wOgURbB6IaVUAk5Re8wf+ntL6i9Kr/u0jWofh9eKRFcfVZz0xa+x8fjIJHcr9u7hgw465FUG3A7KmVO9nnF9G+SF" ..
	"9yZ0bud3N+dM28gk/7O9mfkEvtpljxiVLKraTcib+G+AmT+HL/A8mn0Ztnh9TsvxR5UfMeb4FJ1nTN5OGNMGVXInHp3XncGDqCxk" ..
	"INw6+tafn92adE3NxBQRSof5zx/Ya7wzoV9buoomUvZka/d/tyNsqrkPqlDjFUmt0R3qh3Ld7sUDP78Zx2z1tUN3kbeNFdMcqGZT" ..
	"SkQVl1+/4SMVnRzz3xEhaZZjH6shUfniuqZkFQMiDDdLqPsspk3HA19f/pSb/s1NB+ruw2bNX6z2gWZBPD9WhwfGWDfVW2dkSKef" ..
	"M5Y2DAtYUXF4xFsAPssFGLOsvlEpEv63WdAUQPzr95u2TDS5g55tnwo5f/3TBgarTMlukg96kghJ4P/p5g/QJGs4F1VKcd4RI9uj" ..
	"RwXgjh+U1FBRneMAnaHzsp0wUhT0GUTKdKIG8BvutTbcN4+Vbx5i+DCXnJzVziv1anEqqEsbffqsv+VStrRMcXwjEYh8exgKleY+" ..
	"9PruHkkX3EZL7PIgbvro/OwDse5TPFaX/EGa9pvQlOKda1UPBuNSVJR1JeLb5q8btbgaiBKHpgBEtrAJYTBOSFIqNfyySbXkygp5" ..
	"VtsEJiVG61lX5NBiYD210X8bE314HlVmVQnJRc9yysRh4XLX9sGwSKYx73ZA2/Mnr0GRFCr5hheu6o/mEekEKkdBznGn3/v6xhA8" ..
	"JOpEqAiFcXDlyZ52h5z3Za0CZL5so1JQaW6yQ1LqPiQQ/2pXHU+JZFTxIl2SnaP+RlFDjSKZrU+Y2EBO8osVzz+AvuYHtSoyoPUH" ..
	"KKjMj/27BGTUKQ5iv7Sw34DJWY6eFmmR/tPVwLyeDX2704gBBElekaDGr5th5TszcuTw1oDBeOCl/GyWfTqKEerwX9FRGxoY1hB+" ..
	"GBIauiUHdVNB2uCPnfrVK46TaffWCwmPd+BWHieW0wTlZXovoC8vvPgdIOldjHkQfDvpCK5YUaxKENomQS9LmiLcKdhpW97RVHIm" ..
	"xOb1b0EtuyjWzwMw7dlVDYynyXF0CFK2lGxF598vWM5R9UU7k/BTy4Ngtz6CDxBsJz1NEsd4SKE86JIZy1sAnoB1AolPNsJosB59" ..
	"O7Qdkyz+cq4A1zCYn3bhZKldamqZL+2MAzVFZXJUJvCVFOLTidnO6oxQh1RDUHNqaXrvHouUbNp4FrE5Je8scS3f44fflEUlpJEz" ..
	"6ta1gOEpeFBOsyWsARfK0q8Po/3PRolcii13H9HVKcNERqxiheQLI4dQSt4Sj9xBfS+ETbq6ti3bBRCtJn289/L28GYlN4fF7bbH" ..
	"rOcwQIxd6INQLdR2mFLjyCEx+TignsK3Rk9B9jdCm9QN3HDphp7CL1EboXA4xdiCHFVtH5oAkc7bUNtCGFYqceFkG+mLRNzgeWJV" ..
	"3DOCfgx7N2T4smc9F/OylwNH2hvRUqOdvJFt04WpyvgrGddrAlURCSb4v0W28JHXo7eVpB4NhqRE6olYTMAb3z4/LBTRHIqcl2kb" ..
	"+tcRE8HeKD541noEDWs9mwnKHccSxk4FMMz92liCXb52c+2OcVIErD3Itr0VshemHrUuPfaurvqgnOJVr15y4PnRnXj6XVwrt1vj" ..
	"slqGLsGVvFF9++CR0fWld41vClgUWLPIv5f4Nfdyh65vVNhGPfbEC0WaaSPL7LBTOAzgacEHDFTQ3daHhG2uKZkIOtg2OaKTB4Lb" ..
	"wU7IG8QZHcb1sC03UEH8f9ymS0SfY0u8SjrtUYIRsModB8wGygAG4Li20Ph+4KyYzVEfuBooXu93UO7qOxa5I071ZFbayWHW01Ka" ..
	"rmTqy3PsebR9bz9342YHjYMHG0IyVdZpRPL7quuED+gsPKi+ZE6ljWDQVYnX960EI9Rm+anTP6QhK82LaPb1ZPx5hI5sTLPsaBkQ" ..
	"rsAEpymo7IYa5VpdMJK/BhHQ9gKnJTXgH9PRq+vnQyyELPQcWxBKGVfWMPe3gcrBWM7DxehhvC53alIo3Zg7dlTLPAZr7/Pt/ozK" ..
	"pyvMj8SS6LmajuAc89d7NP3mYc+W7OYYmua+lq4rfhLHsiUVc+RIc+DX6WYY1nYj5jfvJ5v4Q/ilJoQ2t2eIeJIN9mRvk5NKUuD5" ..
	"2Zq//LY1MM1TD9eeWxkueyRKdu1rvM9gyf4DD50zAyf5a/tXnriYLOMp2lpFlsH1/Mn8Jm2pGOkfZKNLmBkElurPX2teZ6/pf+8e" ..
	"iETOFWb9Jpc8L2r7ghkc0ywwCk1mH4Vtf2Uon+6dfK5Z+78xq93THlYiBk/hTIuRG7Kal5Ho+5UWQK5oGJHLEO1ob2KskGKrFwJY" ..
	"xrzs+JhDoshKL07V9Q7ERkHWf+mOqB5D07jZDJAgUhvOs1Wr8Nndk4gnno6dxC7zhCjoVCWZT9oWU1YuWm5JSM353+EV29djfcNJ" ..
	"d8NPp1z9a3g+ixcPGAikhrM4zC4UkrXObNagTTvaBAfKQnNHtyS6jgAktB23Ui+8Mt/2X0ODVmgXDhdBjnYJDHDSY28YVRypJZg6" ..
	"O2M0c7Lbr430NvbMrazmS0EPPnh4ZT0xlfn7xAgQ0TE/VhtAjAobM9VdzUIIl5v19CuEh1Ks4Cg04+aq9geRPrv1p81PtMMLp3DH" ..
	"3N6+TIQza+hWPvFF17KMTivldLQO3banFuDVt4t1AJ3XEBaoEmIuDVh7ex04/1igR2Xk4jni0EzF/snEyu1cQ9b8r+u053khbvJZ" ..
	"uLQPTqizG2eQQuoweuQUnYZSSODuw+jk2XHASOVsQgH7MM/KAt0p+tzzr2nMfEJot2O9WRVYqZzi83kyyxFERpaTybJShFQ8iqXs" ..
	"oj/rdeW/mltpnX7f5AFJ7XDP6UVy/DAgGW4pLaWKDR6wk0zCqihBMs63J8hruI+7uyXMDA6SsJhLNQ7DWIPOuD48FUNhbnWWWvTm" ..
	"ExSOX3kxJr3awjfHTKh3Mh0qNYjASn/L81dwHGSyfIOq23M5B9e4p786brNVzS166+oeAxHFoa9o1nXL7tdMOziY/wHAi6NWPEPn" ..
	"vQUSsrL7HJevJ4ZxMzfRlsEx//bKP+myQOHWvPDHSQ09TPlQFzfsawvwV0DpyWk8amxJgbNvF7kB4oX0gz5xv3CWVSRzftxg5E6q" ..
	"x7fO8xHMD3w/NifnH7HbJcMYPbGblFkvxvclJQ2alDucAcvgEEQTwLmDAjCnSeTD5d5jsK06jaXwKrOcxOG1F4MUSlBmtr3j1srK" ..
	"ymEjE/wyOwZsILAvgI4pAlaQMaxowlEVAVFQg3GvEF8xr6vsneG5gqEfEx7FoycznwS7BP7eKKfp6QAdEmwMdxoCSpGAhaQa8ZP0" ..
	"D6//8BLl0Dj9H4Wc7Toae80vJFVAzc7ciMTjwbknnJdlzpBmwlwCja+w9pJDZfIvZ7bK4CU0y/t+pooPnfQE527/NUsAwITHselW" ..
	"0EbuYqesS2JiHyk8RmpE17b9fdOaSSk9GWrjMThHk0jUAhlvJYaymSzeRuWD2Qwurbm/92YnOu1t/yBwOnJqunVdB31XQW9/pF8l" ..
	"8um/mFb6SdUPMd8cjU8+ht+OzuhZu5mbheGMrhYVjGpUULPU+liJQxtftUvFfq75NI69HmP+MN7T/o6cFLNhtipvyOV9qaUwRyn8" ..
	"I41MpE4pu2WlP8SdDyAznxw4n1cD10656FfUyW8HAeBL+xXX/3XTUHB7b5FW4ysRaUyUqJydj8CZk0xwP3QN2O5gJMHW7EbAq4UD" ..
	"6Q6H+I4Adth1bGd9F7iXG+Cq96t94I07It/qRBUeYzp+ITH72u2EsusQn5nTg06JHDMzmEyzn1otupDPhfdiCxEtr1GIQ/pRlZoL" ..
	"grt1hqlyQuaNT3kgJCsXwX6Jr/JzerAlgrM0K0L6zUetVDL1QnqKNd3Y24kzA99FGkn0F4UOrI90onrLsQQ3KHcLnlKyP8pEsYIe" ..
	"YlQv4WhVJXdIx4DXdGxLm32+ac61ur7UDZkkM1L4L/VvS8uVQnrdh/h2/kiPRlrC0Fi0CMRrljk4qU8uMyMiZDyOo/lW7O5pcjJE" ..
	"i+kaiCzD/9SqY6RQcdDey6o/40H4+ssbimQpKJrz452DbQGWB/eEhcUgIZ9idJjiZb6l8ubO5iel/t2HX6JiasjGv3ncFGozmMoO" ..
	"IcrJHrFeCTNt+t70PP0ZFrFGEKcevgwIdo2B5l9/vdhTPqafIZaTR/u2IFlC8XIoG3YPPirp/g1g2YoNTh+T3DartPcEqkDtLcgu" ..
	"gFFVJ0PEDGCH7QwC1q2Rmti2sNxsbNlIoCJWZgW1IVf1wu526aurK4vQArKsSdDAC1yRr1sJKk80iY0wrKnS5KAxSoYCBveOAJlC" ..
	"JJTGAclowKKkSbA5j2WRgzRllUW4ZIsb9xg+i9vpSAiuo1rx7jQc0FIE3xYKxaPlCYAZSQiV576pVpfjNtazpOw3XmLh2Fe+vp9T" ..
	"SrJfuYU5Q85DHNHd2cj07u7eBKBda+hW3kfgOPKiWE/Ge5vgXtXMPS/AE18gWFcy8ezbwOjcP6ifvjlJxTRrVRKB+WoWJT61Pu4b" ..
	"zDp+4VlatlJBpfmzXnV28E9iILsP14c6pqMlnipQT9AjzJlzVUpjJT1oGKCRSZyta+9FaOAh1FgJaDrK8rqnciwbmnqNfQuXDr8z" ..
	"MVm7zP0SlbcJovGxKVJ4FFc/tMLInzapR7fA6UYjofVBZzg1tn6Iiw9gI0wHJajGXpy6jDNgmVW/WsogwqOC1nTQ1Fq9uS+UfMQG" ..
	"Qxf9EeOCAAOAAXfA4UE/NSkS0OWBpRP6ku5aYwfHwYovD5QD8etl5kmgfw4ZPu4hfoqAIQuQ8CNGz0vKYnawi/kwGreSQ4Lrs3gL" ..
	"8WLeKtd0D66BVVEYU8h9GEKr09Oo12KUgPXp8gHpJShK9v0pOweUsJhl985Kh4fWjJJ5gMk/UTiDPnjFB6IiiGK2maA02IHVzAOU" ..
	"8I+V4Sr29HMLq39icUHpYdQxAeF2PYp0yfhBEo0klLUR5ifhjbWwI3sUlhNvR4mb4PfEdTcI5IP85H+hF2rn9Bq+3vzEe1zdL6oi" ..
	"0t83JPrQf62GMhB+Tt5Nj99KXwxgMC0akGo8yKxxGAA/MGDk2zWASfBJWdaQsV9b7crmdc+pNAuWMfbv1shZItgJNI27LYi2HGXj" ..
	"y8kDzlbEYX8icJOmRBGXPx6UhgsFd/JkXvgkFRDoBPJnGPc6bNrNaoQtLdXf4RpXobXOicMPpkVE3zn4Q6c6gvqrAszrFIaje+Ad" ..
	"1oXSTYz+RwxkYy44PrFT7xpJxA6dRhJrRuiA+94Y3yRfAktSbQeZeL/nduM2Jz9YQeeMmH9+fOOxMoDuEQddbgf1C5h2JhurFg5G" ..
	"9W9gkEBjQRPLPKmWV1YLeL3sl/fRBw39NWIQEoYdUbNOZnZbMGqWVTk8TrDq+8qlM9RvHMi9toTW4zLadcwodRmsQMwKb3K5bT5D" ..
	"A/+VyU2xaeRBUqRoFN27275OhfqbxQOMtvIgOtSi0oVyn7sCpNfOck6AxhtJLo90NXSGNvJvjj6q31aidx3S0fHUo0iBYrYeJoFg" ..
	"9BrxTG7Q9IfgW9WYb8nxbCmKubFWwH7CPHvHItrgONCyr7YoCCY6wf2Dy47I3zb0/CwrZUeL3SWTVRb794WwR2K1ZMKwiq4TtrvU" ..
	""
local PAYLOAD_P6 =
	"OSgjDHq1c9owVYvhISFfoDVZhmUpJB8up/vF43cwDukdCtUVb42u6M/8lhsergH/e9o7QcxqTuFtl6/7S7B5C4oo0FJw+aXf7XNV" ..
	"ThJ7nFmSvvECISGua1btXfTrTRcK0lLkivsfjVyW8gEzr6+FIDh2Sk2FD8/7HEaXTVYXglXoBvtMF/yz1pZcoU1ms770GAJ95+T/" ..
	"xE7lXEcALZGoNa6yE05ZJIDnY3TmPc1ywIKiarBUWN2QocE3RCVA2XL+AFwOSU5AZe1d6eRFtENOZvZfmsa5e4ar31kxZ3pd1+po" ..
	"vPW4NOdVVXKXffP7Pi9Htj2PdvbXgeRfSkn8sBMLTfKVD8BD347J3whfdesKFPbN3fOsWDvjw4hDBVvbN5ptc0PG6BPTGeIyGC3O" ..
	"qZ5xj63xWvZB9nDU2zWpnXq6A0d9zwyHSIcHEC3/KXV3AWs4Q5RPAFcrdmG/P/erc/zzcH6lqx/+9YufIFgbfcJGzHC7bPYncIiP" ..
	"eWhXiTAZSWMVGF1SWh94QuWLcZCja/rP9He6cSfaYvGQIG95DiUtAKhLmTo+NqX7gNsVbQleTOZrJZFfnbGmuyOcWyAwk4/l3WMB" ..
	"AM5DKDWdXTxPK5sWlvwbz6rvWnJXP6s74yZyq6v3IGyvKeqX9mqtTeKsUvtbltzFnEJqHA6ck2+RAJMGAAAJaKBhY0WfxOXstS3Z" ..
	"xLhPvfsDr9LyhyYus+ekHSQliDbvVRiV5REf0hQfXB9bQ+bI0KpmWceaQljBx64FNkunHP6/q0FTkz0874bsUkx8og29/4IHzEoh" ..
	"MoqiBemrxExZRsmNUY4Srsv6iS92Hwx5sZetU7j/cZp/5w3ke9ewE4BQxK2WPvmlKhQMSDhgBOtZi52DAv9+W+aLy52cV4qki453" ..
	"lX1Hyf/F6cvYNJSAtf09adwEw/M1hVmuEudRGRefSOZRGDPJQ38e0kKjbplenF4dtl+u0whOGAEYssoZTuskzpOqLB3gnMdgAgyX" ..
	"G1yDjSKLqUijG1G1v09jdpP+SYS1cOiZitsBNJV5IOUFTsKAxR9z+SzHDUtBtW4nzxVvOIZtbQsz6JVGczZ6WGGBp5DW9Pj4H1B6" ..
	"1QmOXGvGQW723mFh9eO6YyqNX9be0d1CGk7X31mOb6mMc4BWfjnF1JlkCmaTlCRLyX9LsrKoJqAAXp8t3XfgAJGMwgVIKThFcy0O" ..
	"32D3E4gyZ868DUxV3K1gWYDqV7A15/8LV7CdEIS+fFT0jmuw6+XfP6TJy1hu4XKc06FkQofU9uWMSKLoriXkVYSFrBT0O3A6ixIU" ..
	"PDEPDX4+VPu8CoVxsLxV+RirATm3R2a0LzEH33DaOt/QXSdPLFufZHyknTIMLJ+WSUdfxycS33im7GWY5y8JN7qYk1ke9MiKyvW3" ..
	"8mCPWQ1W9/4AcB9lW6yzvZ0Z3o1aToSWxCTYj0dlhW1AYL5WSCYt+eSZgkocB3fjCbhPOHaI9matdIDJI3qh2bBb8/Bev/lW8sEy" ..
	"UkN15R3wTThXYAF5kxKhPhDHVONad9WloOVN1GfGvzz0NUDVidGaV34XvAejLDuZubhcHnPeuVMGDMeeYnAe5/6iIPjNbF1wzfR2" ..
	"0GT99N5rtiXFOU7YDioA7Xz6pf78BfW8vgDSOHyNDXWclzkg/tjCnV471pwjjxFUpU726W/MGCj5MYD+fXl9D/7khCSQaYMfu+yk" ..
	"SOIgMeBoMADVqBkbc3bTnuUsU+IO2NIjZfVbJIfTcAHDlXRPNs017nABrP0AlgIsfRJ3sj/tGsAAE2KGPOZHqRTKeR3/o4MxMQbK" ..
	"pcinRTWQIivB4kNREIU5wxWm66t854w+pCPzHujl9n5OPEtSOHzEpfqCT2Icu7/c9exzKvuk7HRtA1Ql4Qoil1g1l3wuaymc9QGM" ..
	"PweK+x91ZizN5EZOWiRjI+EqLcDxMXN3T87AMoLwIAgbEhV725oqjhK81/LUUaG55oGtnltBKpl6D/C+Uwb7YQo3oKl0L/c1INOy" ..
	"NsKHurpoQDPMlSKlnLgehF2dgkuFMiGqucF666UZWHUsFeKxxz2mFnO9B+heoaUvEPMfAxplDt0P+Mmo5nmTKki6HzwGd7dUDcW8" ..
	"us4SxlQVOXWYQ1w0kjkoQPMGWy5rZTYKzXRrx9HZXILtmynd8h0cYd20dTu8x6AoGkukwJ1FvobfjpNMLe0/QFgPL+rARUz3W79q" ..
	"M7kMqTdhB4GplHE6Iy9PvqJfiHXQlANTlW/e6MmJ5edg32VRB9m3T6nfDkOkQXCIYeQAQC1jWQ+YVQ45Nx7K4qzfGdkQgYO3CyDQ" ..
	"hgar1u3VibXSJt/94/lI8U43hsVVNvf2A0y81Tv/Cl0le9/MRCoMoE9Htm+G3eXQAPzJx5W4KGIEDTb+qtnzFtyYO1jqHR9GrdW2" ..
	"lASPek4kVPa4TLbTzGL9K3ZntXJbX7SS05lPJw1JFFxeiZvxqCu1r+oXiGUNdwaYDUuvO3GkxvlkUMDx31S6sDM94pfac6AQQ1pN" ..
	"M53N8NQeo9yIWviz+IhP2aiuSqU0xv7gDTho629/TTNK+6VItR0jrsM+bWGQg40lFoRlJuPkv25vB3X7tIBWuY6+GVkzplRgwmxE" ..
	"w3KlAGcqdS1pUr8+TsfizAk6gRtP+LTsBqMylJkAkQYXfLmbYgSl8cj9y/JRMGcwsNGnCvobm7+hbAv0uw/BIsNwVlYXmynzQzz7" ..
	"yu8t7A0bQA4N9XeyHLmdXmrWj6jSvuuDbAOnBFFiflnCU+FiL4Ba7ElQJWUYaANm60OXCREOkVsTazE5RF8YgrfEeRTE6aIn4ry7" ..
	"I/kHoDWUV2OaZBlK5t28ctZJhrKn3sGipnMag2sRxFhp2QbcXGbAnCTXwH6CSzMGDbFKAGEspnfkFR3TVjw2/D/0a2hLUTRcx1sC" ..
	"pfLIB4PdMxuNgtJqJGBjMLNhrhlm3QD3Q2F4lm7vHdgzedx32pZHXL6fMIMAQPuC6kI8e9/FrPuuNNR9wOZd/OyJCfQdK5vAhdkE" ..
	"QWJ8rYBZ2JrZnxjcwsF0ozky4jBF1qDCWtFeravachTqeThiVQs5/zkOc1TIe9B3mh1sqdjZT9yklCVAjf/VFr7PwqApnJbJCRYZ" ..
	"FTT0xS/EhiHylqEoem5sCLXhdlD0yemmioq951g41HMIt7uxbjdCLzYICk2brz9GHl6Nk7TON9olvK6LO5GI684Ppj7AnUFxOk9u" ..
	"y51ja4RQ4yX+n10KDqGTA+NUcw7DXEn+elLc0/zVCpb1uFRXcXXgj1xop5+OseaHAHBgR9IgzBuLObCMf2gkoj5/Aib57PocLG71" ..
	"yjQiybhuykYohSEHcyFeNfcLqqGn58X/MysMaqxtfvCqYWf8bUlQCIZdRW00h2+6KBDYwt3XN4md5ukzxMhNXSTv6z+GXo9qOVEQ" ..
	"F+fjcbZOnoapOPvnr1YkHavNtrUL7+CslBMCOvMyYjEATv27In0mj6YB4Yq3OGY21mS/eqWXUuXZ4RmHKwX68iDiBh11XDu0Dfig" ..
	"kv3TH58owACdMCgoBoZw2u2PRapJj4+NODYH0uEnVI9ehBISHfzclNyNuSv9JJtty1sQcfLILd60shWS1yYe6vlVSu/MtcI5vBv2" ..
	"RIXoumr0ldR03J4aXTdzfbLz8u/MYCnD6oNdNDGzQm/9ohZ1f6TiHzFK0f1tfmAOnTZ2EoNbLzudCbSl8ow+/9nkulY9YrleAML9" ..
	"kGqpeNnSYkhI6fOdMhh0uDT/LYNSp8HwoZprAwz/1PIpzH3PGsRv59bsMX6PiCJt0XAsix8BFOumKsjI08LQhnmx3IdZHp2/PNb3" ..
	"beRysJwCGR/42vDKMjSq0G6KFu/eQVTcHNd2MsiHFYkOykqU8C+5saNpcpxz0pfJ3ikblZ+0IRCcAdj9lhspSJ15VK9NTlIGd867" ..
	"VjHE11p1sBr17ZihulDUxmyjLaOvQYRgsBIS3Cv3sIj9+w1/X+Ou9MpZTZ1SVJpWKo0nu8Mrf1RBZOl0XTlt4fOTPMyzbok2uC5S" ..
	"z4KuaK8Dd/5+wnYYxa4jgOFycZFuSWwhAgloakV2LUjdc/EIoGx34U1ZCoMJ7YiHSlBO/QkaNOGwFEBGBQ1e9p3X+qEES9lq3x3f" ..
	"K9D5DjDJOSlOegtvRaFJp9BSemjumnnbuM6aIXa/zamNblYphg4tvnAQC6/gBeCfsZ2j7J0uXP3irox/ZItJFeCoxYhYO+liAgPA" ..
	"F8GFFRV7b8z7sy6smTGvWKoyfjWe4hwwthbuHg9AtA8MPSqcYKKFLKB3WZTNmKU0UwdrW9l77KBO7Jihderv2akksZwbPqOvD7ui" ..
	"bbH/XaNBq/APDMzf6eCz0GuYpONLr3Xq2wOaVnT6/hTgMMIiDC7r1xoNT2F173BFce1fm1fziE1PwsQ4tqJw+1Jpp3d02BV5WCxc" ..
	"PzXgDAxgSe7TXL2e/YRdDp3Q3hCUQ88mGQzYX7/I/W1OfCJTShcygxMa1t7ONYHnyU4wRkpb0pXBff8MMs5hKF6Ux8rLJUijwgJk" ..
	"WBCf0p6Z5jBegL3onWJjir0sFlMxr8vg/w/4SPqPJUFuuyXQegtjpcfQ9Rj/TxOVFTTVjzhS77WAkKqcoo5T7r6l8lHwtzfNs7q2" ..
	"DMxg9+l5eADKL74qYDAA2lnmC8h5fuoNbU0MkJGU/TVtofYdsDw39TEI/LCQ/wofxl8ExbMbHt2KYZbDvW2Ip1cNooGaZfN0p5jN" ..
	"FrWyJKJfNRWdwxsUYrZ8rrqTKHTHgGAagoMwnqwHXALfv2vovMh2pd+9lZhBs7GQF98l3k5iAx+R7nNmI6tDGCH5VTUkZZQXqXn4" ..
	"bSLdqU5+ZI7W74kGZaGniFn3XoohUAZIRplMe0OSxGroQm6XXsoDvZVF3J2PXwbzWiBc1KDIxLSwQCqgY9PkH6uv2dAl6+OZ/gF7" ..
	"7KqL8oscQxeWLv+fBnTMb35zzy+BDAJwE+81q6vLABtYM1KUawaQ3Wh6uMe/SK1acS2+E5agHZP5JEcJLMiPz/atRo7M9her0LbF" ..
	"SWU2ZzomOGXa+zmX3RIOd34ybjiNfzezqKDuXyyiA+VHwyaLyUlCx/6BC0eGREDSnonvgLGEgOOA6k4z5r017JvEIXIaF/2olZe0" ..
	"obAtlx/Yk0uQG0NUuTgKFDZJoL9zWu1peNxMxzPMVrETBIMLCQAqgIGQ+M/yoLEIIViFmqfT5yV/dxxyw6XMtn3fo3hKg+u9pY8W" ..
	"PZUXm/sXN8ljTBjScRkh7/exc+mzufDgd34YhtQ+nlHdTEwG5uq9A6TQglEqWlGZ/jPpFb9M+ZBsPFNt03rV6RUk7aXaLUPvBz7I" ..
	"OrbLCO+RoQ9ZW7FwvrZAcWWovTttj7boFzZS3V4H0s9v7bQZ5ebYCTIANY63o1+H2+lY1sue1+1fnVOzjlpruGjAuWHfxmzHR10C" ..
	"SZt0J7cSe54WQR9X2smpJKJ46ZuzUxsNd79NKxlNzTMeeIKnn1ShbF5mb721DztdAVp58j8Wf5MLZqR9LWgJ6Ub5Bpj3OlaCPkQA" ..
	"+TLsGutPyCUP7IoEA0ILSrKYWM9OPopXJ7Nx9y9ttYrIpnkErkyJTadMoTe8jOPnE9yjbHnajCFeI2tecttbtyNdFwTclxfCj/+x" ..
	"fh1SgC4lPR1Yw1gBxdfU7kL4Cl/WrJS5G+GPnN9XnOQZJdJ72QgJpzuCprMAzUqfYA6B67i+Sg0UpY5qFozpp2/01yOlrrTIhjZC" ..
	"vOk47r25cX2pdSorN1E8TQoB/e4GM9/Z5Ux3/GegxSDrEWjta4S7lbFRwraP7FyqBeht7GuJOPEkXM6jQ++S5lnPJK2HjdvrIxYV" ..
	"HAN7ypAAddI8ZJs6PEDqcYq0W4QO2qnk/D2P8uJZ3wx7JUkTyQykfO46zBJak7AgCpEz7LfL1BGaSCPfibHVGQ+mG/bZxrFBjoS7" ..
	"x/fsEpI2/v+x0/pFXeqB+nSLMxXoV7UUPE/6BEPxenj8LeNbbm8LaggLOdu6LdxQcCWv9lEfcWcAcJcFv5O49mka/3gyNW5mH+6d" ..
	""
local PAYLOAD_P7 =
	"RCnA6OazotiiYfJn+D2H+Q0UU+KH2wsSxaThuf/3f395FaisePexgKgtkJbVcUQMWY8BO7HIZb42zr7kbQjIL3lspk5ULwLeJ0pF" ..
	"UcL54obdew2tdRXxKmJml8k5eOsijcd7FjyURHNQGJKeFKAtiFSFPa9mW0LHzAY22M2RT8GdIp/lkZv3BqGf/jwy0VHN43LQer9E" ..
	"jsAqRdq1J38+qC7paVqEYeRv5jPiWwW/vh93TShtC+mlL2fkGlHtG0dEyECMUwulz9HrnNi1JIQ9lhhRJJZ6chXdcegOG9OlCTKg" ..
	"af96/t8EObCS2LlBt4+KAOmnwL5bt2J72ZwdnxF3BQR5gZnlGjPFpa84P1v95CHL7Gz1mKAeGJloG74STmHpMp7HbawIKXdSlOeD" ..
	"Gx6CsfteOhPU2fCzoKcCZEh10iyV/ttXh9BH4kDms8UquydOTd5beKtS9n0LGhXTf1a7DBvw23Q1PmdT3LG1VKtUmLEpCRXdIZcm" ..
	"eebt38JO02XUzZ51VOSU+uF4LuneNomh5vpvbebGXms9271zJ/8qBew16XYHGP39X9fi6aZI5/L/meMCr4p6oxLZ3wv7mGyr586s" ..
	"9pdNKGGJ2B2OCvpWR+gixRXxyy0IWGDo69jOJEml8AiiJ7gCDIUEDEiYqz7WSDoWCWsxoeul9ruIGlq51DuqltafAccaFSvxIByS" ..
	"ic0XogqtIGxA60ptq6Is9Ej7lQQ7i8w3pb8Zz8uomMcAy759ESlH+QMzn3ZTTIO/INKU3Y3m7nO6SXrxXvExEejBUFNamuHq18br" ..
	"bU2vvA7EKjU7nMcd/MeCkYqlB7QgVWvCr2OUKKPG/JORbNkDoELM+3YNQuE95vmm7mjvCuNF4tAmQyHG3L+FYn43BGWF/YgaUdHN" ..
	"i0Kz0UL5XYdI4WefxgseLYSuC9clq5fUv30pScz6bt2U7B0ai3BUHdi0dS9cPn4htP0Cs4wJReK0K6hsp6lCWY90YoBd1R9yFx7T" ..
	"Msm0ISiEShXasmPtWHj+9kSRQ3af6s1IYfsABjNJbWFb4dT3uyEh4Jo931dc9sItPwssFvkv9ykosFapRFbpYASHaMKvfve0iCIs" ..
	"rZ+EdkcpqF8iluKJEK1n4rXa3nhLNttUtdKjx3r96h0oKJqNOqBbvk9B0h3y3uoZl/wRfCu4dA12iq4/9Sl+67F3cR40Ij6b6Vbh" ..
	"VP9Qf3WhS2lZiDy9C58wEuGlT/FHddJyQvrWDQBMGR7iI6bgfkEorjgjn5dtqdiB8YWVE3v2VLlzqO/fEP1B4X5JX71c4iPTgU1l" ..
	"HzakjUr4TLhyC4NcWSc+qxo/oB3Hvynd5sD9YuJz7PN4GxVaZFG/dCCMRQHJ7Tow0krNylgR6ghQCyJa1SwblU5upmdgKlV8AcwK" ..
	"OtVDjO56OtftR7QWMHp5THEPTwJAQnDzBMYgnOnJoOBT/XVRX1u9PjeytKfQqraXScCxfKTFtphL90pj11lQbT6QRxXCVsrPNeX7" ..
	"tm5Qky0sZtNiKQTblEG0ja4jNqd+FJejbxUms5gWHllcmddZ6Nwf5uk/IHOQIe0aDX77FSgpUhr7wOjuI6xLO1GxRvoI0K3LX8oU" ..
	"niN/an87PHm0ltNv7ibOPpoYel/ZqOmWokJtbizk8VP8pjG8/LuEEZOIplE3FJRI/U6+ts5+QRcr1597I2zApsNoa1OVLH39CT5A" ..
	"O50NC7/uDRhDlcurA69WKgIO4nfQBhNttW+00/8h9iaRV0MCtucQopOV71jznJQ3mVjx5Q291XikB6d4ajd3xUXxlWB5YmDAMwXS" ..
	"WToNBEeQk0sBzZUGgjoA8MEoVZ4n/X51WL/F2rA7SjrNoc/tXyaeLXDQXBlcDZgK7PKHNb/zKfv1wvLOs0bovzTlAw7cHHmjn3Sr" ..
	"ndORRaAM9XNGD6WT0TtzGOFkG6Q9ggtV5xjQrfqtOdcjp9+xzDFrPmW2e+mRak6bDNntpqT/txHvL10Lw4Ubuf+I8f1o8q1ebhef" ..
	"x4PpFjBJ6bcOPngXlcoD7gbjhXjjKdldQvz8gm76SrI4RjaYMRvUf1zfJhQgZg+dE5QNeTkz5fIFGUjEbrA6DnsBt6kYURwBrpE4" ..
	"Ny6+G2CDTSR1xkuNB069GiG+/iRkM4Tfef/sUfLeoDFwV+aTM7vtZCGkO4olNFFQXI8H6qoDzEAo2gTfpv2cWOuBUu2QbjkCc8Jt" ..
	"VuOBdqbCUKyvE0OTFqHQ23g92oQQrA00WctBvaQf596KclZrNuzPZcWwNokjnZNkTUu3i4+O8shWh5o5mRLQgYTT43W3kkBp7mzw" ..
	"YKr7YVQm9pFR69fuGNu2zIRSyjzmrXh5n2NF7tTV3yW+M9DDzysEtHY+5kdgAaCxkyWcaaTTbvh9FEFFE1knQmS40obl/RrLY8hZ" ..
	"lrITQ0g7hV2fX7Sr8t0gBzJBJKzAP9+XWV9bbHuSaVUnwlxjscJfNUgJ0vembmy0U82GcJtFhn1Vsqr/zS22GkdkMsGbZGaUeTGT" ..
	"tN5U4V/VZPoSIUUMlaEoyXuxUnuIUQKc4ry0Grwx+twnB8soOlyYPthvmqFGYmKvdX1wr6RAlOsnUNTJI7b4IwtC1uultYNSzMvd" ..
	"o3lPdsEFua9c22ziTuU8Z6IfhfvaYf0Poejp0q7umzoLbejhiHSkOLWcVoLcl+1hVgxKGMrhXSB4mh7/1qgTpmr2YE8rX5R5Hl4V" ..
	"msREUdvO8kCX7ue/M05Lrs7V3o+HNpbn+sTK2EpfeaAEVUezMOlydcuPpXUHcWTjbBuZRXTbGqjbVNh0lYN3DE48tnSwDu8A810x" ..
	"8wI2DzIr8STi4Hs619q52YFUB61MDWKafKy76W5UxbVUg3/kTuWdjgwzaXUXIY1U81x+c9GI/9khcdp8qSHqxgQWsr7WVZ0R4yJU" ..
	"ryqT2bzX1sXjGw8HHHUIw9tI2vfVRDATgM/9d3jlJauu5KRiAQXqq9sKn45uUpkzR1/kQI2TfjSWOzqwoKVCOMD0iXmUFQy8VdC3" ..
	"QkSslQeMupdebVmIRamVA9b5Je99AYU80Ie40Hl4vGB6EgpR2E2/b3MdY+rJhaOHiBJpY2sl46lrtErFyiwSlMGLYMzr5CwTJTKS" ..
	"3YiI3eYwdnfGcAb2DPq2iTWGrL2mCY2WS/o7wDZnVQz+E1M898TfGcY7lez8/j7PHkgbFyy9Zm6iFRAGqwMv+lGUj8PNnuwHWpNc" ..
	"sja29aoJUVth/OlgaSbKd07z/LiuKDwlYDGI9ntSnpjqUFSYITL3clL5rAsTuNiioXWkHbhrmirzOZOTjA3vMY1XnG3ut2jHuxlP" ..
	"w6zg4wVIyMd1Xtu1q2jDiqTG1rtjikqrNemQM14GjbgCdKocIzX1z5nPNTwfPBFmjnKXD2p6Ci4ZuZlYDs5nANfA53c4MLUBBwqI" ..
	"fa7/Jm4GUiMWdR3E6pfXe0/Py3fRXofAeH4Ah7CubUUqYEQ/e8JRXsKiprg8asP2NeKeuaIu2vXoOonT5Vo3qPYZzd8PlGvxIAl3" ..
	"2ZOzN8ugbIieb9g6kpRW8833asxE1B11D3Fswy81WXCFqCubrBsg2NJXN1a8xcpYNS4yveU957UE8Rx0OYLjuUGQvrpcAzgQGuux" ..
	"37TFApvADE1U5kHsN6m5L4xLH/JqxjuzAqW1eESw9hTABBabJvAepZydlRm3FeKw5eE6pbPKlxONC0JiAqPhknEA1VGeUr7W8f2f" ..
	"teSIhLNqqGcl8z16psel1+HDzpw0NXhAPE3Y1sq7rd4ZmUDpX+WlojArz0g/+2mLeWmmPiF9iktKQ0ug0fKCYsYg+MZcP8OqY06v" ..
	"Jc280xRRNHQy6SUN0HgU++DR9kLaeYiULZo1A5BvkrTKCXppZELGNK9z5pTd5vHXqZXWBJ9MHNl7POsZPi2gZLWDKI0w2wKIyZW/" ..
	"cxM7AuanJFYWuXGfaoqiQtdshTcTZPgf/le+jS6qqmii8dM54UT3RrGKnonlpviLaduCwCrqc26t0aXTwkpaGZIwIX1/Gza1qOVQ" ..
	"Xj2s0Xzm8N7CJZAn/hnAT7rHUA/Dz68iomApdOmQ0AyKCu+DeOuJLSsnD2rQzYiLTj+1Eyo3vJfRKW8xIpuCLNm7kSOfqfSPYzCF" ..
	"9i4RVlIdZAZzg+g52J0VeJIblKRLNqjVXeLDTEej9Jg/407lo7FFg+pKxY7oL9j7zRcq1WYhaaIvF4ycD9+hZaovgcxxL+UOfyUv" ..
	"vwL/IykMUXeIunSx0RGK0xuTLLSeGtRWEPHig6zIHtKSE52byLFIrfBeSPRz5D0v5kMcGTDPQfCt5DsAP3Bkwiq/Cjwu9wo0gi1W" ..
	"urG7h82zgsBvCE9YsY6Sbk+jijQ2JkWI0e0AwZOgDYrE1LQDdYwvHfo9Xki2pEe86GpNHwpEdklWWbUVVmgs4jqKrLTWCLj5aQF8" ..
	"MzNGQstBTKmLgHC31ZXhr/EfN5gk8fL9X5XTWSCviuv9KcvW9LcHk5xrKv/Tl5VWsifK2PN+98fXqWXiPfoo/YRuGNhwj2TQqKig" ..
	"TiVimHdSk4zGMox77FU+6yBrqlRtrjtKpeSnmIXb8IOVBLZ4ZiUEiA/m0EbiV5DqRQulJOkVoP1iySMjzY7ZF00ofTWn0MYCabrE" ..
	"91K0rAPfRz38o52KxU6tf0Kx16MtDxD9uWgy+F5miKZjy2fbv2wASZkiclMEjNbBprAgLCqC4wNMJ/qwt/QUbCSOngdC1BXBHfob" ..
	"WdhtpsPjFneDS17JXBp+xNpGsbl9DxhAnmThKvbtNaqR2BiuQseTNTQiVlR380UFhgkOF1Z0rkVicCijIAilmIMRERFiJ2zL7e40" ..
	"mn1SWgPrm37XCl2Cxd+ntQMrRrUYkmHceiRBchpvNQza1dtkdt6YuY1S46zdgYl8R7jnIjsxgILZ35mNSeaYWCahDpKpig3CdBhU" ..
	"d2idReQvJMLUbeNB7B3nUIU7pJRmPCb+WRVm3uw93wKCpWwV5jB/Fa+0UPS+WzaljAl3hq+9OVYu7Zzu4TEbJdfIpILdhRlZhpki" ..
	"yFxfLVsQwQs9/CY3/ZExbCaTkTZfMy1CRMWAvy/e0fHH2a45qh3OIuZpx9WEhKAIDNQGDpo+z+O86K6OSVeKFfhRxxzocz1XEaC6" ..
	"wbBYvsj3XhKpR/GkBzkq+ysRixaNZEoMXo37Bz4WOvocze2iB9pXIOW6zZRHvNhXKbR2lO9hYt6zTc6DmBygN8Ih1VSdCf7QtOwn" ..
	"/SG5WZyc/GKkiLBsJPOcjUqVxjZAGT0r6ycon31TD2PB495viM1V83+eniIUqwJzLrkZ01vuzQFGbvcVlb3IGJ8m9FpKTCdXiPvX" ..
	"SNuFWvjbNNMQ6f7DGprJ4Rww9HbxKN5R19XVtengBnei/HnwrjVeMclSFeU6Ha7L5j/ixphW7AGnHPZyh7KAVg+SgXJEqHDUW7s4" ..
	"danX2VCSNsGHdkf34tXnNICvHQjOhcXEjTgykR3LZmykiILmkgxaD97EkDaBW29QAKV+rCT8YIGZDSjtPPbpuejBnxco0b5avm7v" ..
	"VEXug5MOrZaqjStHS9rCZRjvFA7tn/JmdjopnlmGdktSMGo7dIx2g0WWFP7LpZoJeFGWKNBG8ajG2IGMPqhP53FdEJks/LienoTr" ..
	"Hmx0I7aND+vxm5HTp72isM1xaLzRj8qFa2lu3DtNPVEgEwYUkpAGd/crYQzca+j5cI+VAtkqYSze0TzZN6CqGdzKmp5KxxaWayOl" ..
	"bIHe7BMFlnK4LPiP4OGo7npW02Lty3xbkls+YqHqE1l1c91p8W0xe2T4Kisa58VzQnTl6wbrjBCCmpxoK/d6GaZ3WKBSFlB93oUw" ..
	"TYAOLpCqjHXbjgCq0ebL2X6aUvCHK++dX/KghwTiopf5sbgIEbQ34segeNt/jShqiNWZgwbz2YtR/2r6Df/DXB+50T7nV23W5gN3" ..
	"6GrhG2mjc7L7OzH2OPFl0IowNICwXk1UpiDG7Md6zAAe5g4Cgk+j2AFPLPNkDq6BTrsaAlfyaxRE0iD5+r7IbY05o1LuQBXPc8Sj" ..
	""
local PAYLOAD_P8 =
	"e1F0iu7+8vWL8shH95YV+Oa3qth7K2xYPnWlUYZzb86DicbjMRYYoXlupWQtDJaW19XDDLSQihjs7TzKKBdsdKMrzGMiP1M4W6nZ" ..
	"YN4vGTPoMRQc/Gi8XCp18vaucWFAz34RD1KrQ+4VfWccHV360OTBJON3AU4hhxN0Sh4PrIaYauc1eE47uHzQv0idsVaabn23ieUK" ..
	"TwW6YMyfEM6s82x9/pf/YQCq4x65s79Nxo6vsjK62uc9sRItosGrTkP4NvzrEPNkkGy1xmshEyyZz+nwZO97bpYEkF/skFONmzV+" ..
	"iXYxFrXQgammOjLhjt7RpXhsYq0LpD40uOoa7HhlRu4zNA3iCzmQcieh4oYpAp0rs7wkxfZ+ABHM7n6Y9V2hS2V8ikzudbPu5zeC" ..
	"/W/lPLMMrgav9foxsV5qxqjmvkKEkRzyDv+ZdcjU0mcBq5wOjZnSbIMvK9r+X3Txq8r8EY/n4ODSq6imxwfDJGDV+3r0fCt9U3Rg" ..
	"nvhag8LBnrvp5Xstw5y/8vGHgRYsAkjKCA0ZAFMRftvM2EJpKMJf73l0OZn4NeHqc76rp3jod9B9rIdfsEkOcdgZ8L6jlGCpT9Xu" ..
	"B/ZaVFXUOgnoFTVhUHnNw46d4veuxRb9zz04ak2KdZG8oecysQbRydqxufdD4xkZyIe9sN3Bu18/1PAQHzKfSHLLyGJRF5n2wQCD" ..
	"W9cC8VweVB7qUwcjBAvKCiXr5lb5gl2YpP/Ok6jseF62d43OzGjkcfOx2dESNROSAgO+EhA2AgSS6uCUoFOAGcyyujyTP13C9hwt" ..
	"BSRHAa2RWceGFs04XQRvDdkkr9VYvqHdCxy30H+MrZrQ5T4Kz6QBTg97kPHZkbxFkz91VMnvBsc6eEsjIrC2FDvf1m/VhEuq7/ga" ..
	"KKI3Hw1QaltpnXbsIqRZ80ZSJTCPS1woicjDLzLZvQPGsxqRoLDGU615TJuTIO4NBGfNTOWic4wllLY70ZF24h5y1jaFoIVB56k1" ..
	"8RO2oWXD6gWHQcLh3KIS5Ng1L3vj5z6Yvj41Dx/xD4N1tBloygR1a6fz70LR7kBC8KxZjgnVtw41Ro8H/o4pPah3gLuBeTf7HW0C" ..
	"G5cikPTheUrlVWtuwj1M3UxMsCf6rt2PyruzJoMV5tGxPrdRwI8CWXDq6MroZGWJoq/OqZbWCL5BKr6jyyw6iiA+3Twu3YDbgsZ+" ..
	"WJ9ZcmPjCbcqD5JTCQAbWzDNYkzo9DowT1Git3FxJ3R4ewbHkPci2aYW2YxBGICzqTSgZUDGPwkIeq8jtoUNV40ZRPiP4l3E9Mx1" ..
	"krBwmXpj6WiIyTvhlXGaZSntZJYYUVaj761yaWbTbXBYcZIjayiwFx0cS1xAB1LMdig8OY+kWo02So7zcM3qi0zhVpNlwbTgKl9v" ..
	"3f91fkjBPzdrs0IxPEtWIEKMelM/DBmIwgCWlYS89yfFyiwgfUphJwpX1w9cmdGpczQlGSnKGgiN7qd8lpGlMwsnkhOFRr0KkGAH" ..
	"n1o+Edc4HYhsjf4dYmJ+DQdL2TuFzQPihrxoSJ8exlqhk7xQ4w/aye4skc2H7XqXm5feUKCLOMCpGV+3ZLDdEIcIKIHmOjpZ8a9Z" ..
	"AKQZwmUYrD50nZLdcAvSK74d5VktSr+Ku3R5uQCAwZZf2AJLqPYdC9Kg6SBd2/vvpjwFflsp70l5sdyuag+uPbvq6QvNyQEWF7vk" ..
	"YJrnXVchhuKKJ/TB7gLx58WnttiQBT5bnb5sdY9eKl+pIPbx6mc2uqQgKk2AO3YIrt5qyZ8yR9u0gjDpCGRPnThHhBjlgmiJrN82" ..
	"DvFzdaJ4NOa9Gv1/vTolPpLuZuNH+9q5o47Uk1fQOxC6eN07UwQDW1bLKZVl0O7PbamRQv4+OYQcGOdttliwXiDAA6rRPzvcuGyM" ..
	"VEFPf2M0xM5/E5tTD4H+e0BcsbHFuqf4ywEmlTxDLipxtbFSEBA3f3BMDY5efoEVlwt5kRQQZSHHuVZOF6R/9zLcG9O1uy753iNk" ..
	"EcLisb7dHEeq7nS/O+SeQ9a6VoEqQ/nZtkatKFMY584DLWptA3P5gxfX7KfLtaZBdYj722mQCG7t8VbEyB2Ec5zLAm6MiBb2klvH" ..
	"L+mXf0eJGiV1u5DARWivQ9Odf44ed16Y6WAXI54QHjgZ5Xi+qR6gsYk6ZZh9Kiv8fsFMbZgjsP2gWYICRaHNG6T2D97oOzXBzLmT" ..
	"5mqmfbsjtyldwvWI9hhONXRmRLwL0abR9NRca2o7ZCCcZhZl074QRXy0HG4ng0AjQJRhjqwwsTFbgkrYcD9hv3l9nTOBCVcsF1A4" ..
	"3I+DYkWD38yUQftrHMthESiH0IZgORAGhVuT/dDw1SbU1ECVmUnyioXr5QaIob6i+kF/QxrVzw2feAWbixr0QGeKt6Ed/ouh7hOG" ..
	"q3VgkLzDvj7L1/PF5dHFuxzvzpK5LYs8UrifCG6YSzqIILsdTKJPgIOU0Qj/xq0ndotI/aWcAOP7CaO6GxrXsqi5oYF59aI4TjQT" ..
	"MSh9ZfIxiObjeuhUbV0vd9QA9aSFuaN5L5BeXC7glYDbUg8zhmZz3zqt1Ft2gxLee8BtbhoLZV7G6zGyG7gL8XvS7b6oSS+7Ap1f" ..
	"Z3jtjOwSvHXTvesvNKMdrbncpSZI73bqOMqCYZIP4qYs+m422YoIUgaOUAYH8y+h3zBog88U46Eu/2tC7VYofDUcvzAYD2bnSHwC" ..
	"yBbOdSZaPeOzx6spCO+aG503FwZqSL+bQlugvAgYukG0DrP1bGbtDx+eEfEvOr851AgDB4PynZoAhmcXLY0TiX43knxVPaAkx/96" ..
	"8PqyLOzNY5gPKmm+lLTaFbLAxdOsLQUdETvc7d6Pl3UebWImSmsYGCp1ZtESkwJ8EF1yDUPp9QyLIvG3G3MkzHhvexi82RM+JYlD" ..
	"7PkBGpmXo3OiPVefmCGR0z6XY/iABeFfn6cw1A6SP03xyt7EuJ4483+/LxPSMg7FJSZgtKj7uaPcY8UA7RKu9wDjMm0Fk8wce+PY" ..
	"swUX8/Dnj3qLlJqwNatdnRsoL+X9UxW9UOQWBrMb5UMvV7UtT3XgjgDpsM3plm2jwMJiOseogwPjLkgcWTQI4YnD51qyP06FbL7k" ..
	"nwYRzBUrfa+XuW4u/082/Rup4r/d6scprtG/mmLTDhLUVoLtPdp28y9V4/XT7sPT+WqXQDzDwRreiKCEXH5o0Lv26heo5pe3oaUY" ..
	"piHazehZx6IluMcIOLowBcr3GXkR3WlCGOaZUwWBL/qoFA4M0VhoSkzk9TSu0+cecqssZb5mLMVPR3RGfWBijdElz/l+tPzlgxgD" ..
	"fa9r0KZ1fYTV1E1CL9gnBMIVMa+nuLoaharGDvePkJBb6QAyrDnOp1ledOoUh9VlygaKq+CpELOCT36t+mPmiGDMA9rzGGL/PRW5" ..
	"nTPRzj8NbfPJjfpK3ptJXzqKQiEdto32J0o0TZOyCDMTSTSx0luby3wioYnCjCtvzqxdBQd2eyEl+nDFBoZ0o3GKs5NIIx+0Nk1I" ..
	"xICSgzwrHCEbcJTT39cL9eQ6sMCzIfJpJeRXGkuygr2YTaoQyWjnGPEaM2feTeRZWANg3/W5IDf834K/ri45WAwcOZAKpG5gJA3i" ..
	"Oh2ecMKC4HUgFwSFTcHiEISIPAgOHTu3QtUIZLvBJz2lp6pCSr+OUh/mW2bNruAnqAZEev5EmuCZzI4qROX0iIADu3etPM5oVGdQ" ..
	"4nYy6zDIzVYpmc0MoT2eGISyc2O2QJDbBH/hW59/wINvLdORwBSPc0Kiy19GivlxmgaTNzg4Tz2W8dF0PPe37kOOUDgAY06bWTq0" ..
	"/gBBXk6ofGDWyqF07E6HH+CaqDpy+7hJo/2/vQ3PPfxYqcGNGQ8j5xN0isRurBlN57l2B/z+8cs7wQSyMORkg7WIVz8j1530UeMk" ..
	"zWE+ZC92J3+oUvgFm4RbhOIoxiGty0kXNl0yLfNrFd/wPhM0VJ1vMEamUgHqVSuG0YeiF502Ow41VwxkwKDeXgkdyLKxRpl77QxN" ..
	"qxC2oED0oHX8HvZuXRObyQqUv0xKtvrAlY+GOACV3Ize6FOjgc2iuyWEdK93hpGnE9GMRsnsltUJCGVmeyjQzOWfB19ke60te/BE" ..
	"YCcXEtgE1yhl/3DtIVvTl/M73cnhTxiDCEUPK09nXoOr+OZJGp1N3UhNgzhI4LIh783mnQZAch4Jc6SnxUQJLakJbkJVMV1CpAfo" ..
	"SDuO8JTI25mBGvut7BVVZjis7Huau9q8g/E/gNamnxLUa2+cNq8fuWGggDrexnUi29+abAnZAPjVy+JaExz1pMu5cifEkX2DSWZE" ..
	"SiPgNXiTseDP0StTkfp5tGU08yV9zlfwpCUsB/0Yg3P5PBcKjd1Ev5uXms+ZXKEehhdz5C+zFiizAn8qPzVf3NqYxxaA67x6DUnB" ..
	"ko7unW51Ig0JrTrtQaTwmzwoGNrGNnM0AD1YEa1grN1YVU6QIEsodBV8Nul0vuLm1ErqczRbguqKHqJaF2r/z7RjO9GYKwW6YhZh" ..
	"uNbMmR4MJApqohz8Mioq6BOCeZBOyr+sCtb0zIELllJ+qcZY8lpdG6fcvk7p/VB8WauV2W6YBKxAYOigo8/qief9QkPpocSjsWG8" ..
	"6DJUMiqKHTcJPE0tODuvOuHMHTYFGCvCbdvk2JVYT4bHpRD7tf9V+Z1ImDf7bYuzAYKx6oh+JC4eaj8t5YQ7S4iW0FyVSfw86RRP" ..
	"/cTbzU695aX75JkWwz/qxdB0EeczMANLLkOPh9tdMPL3KUj317GMpO1ljbNkclCdHgmFrjygUQI7hEhprfPPzTJSJsA2TEpOX53d" ..
	"FcFIWIxPSzr4/8Y/AEphTSKHVz/xkK+MmOFiJhjL6i8w30T9lLGHNQ7fs+RVzuLz6kR010vAHN04lBh7/fJMyAVzx22Nb9Lm9OPy" ..
	"j96lfZ6mgfZZRL0qIdX5UsYlYWoARk44Iszev8cIqYHiHHErMh8qrtYmnlQB7Zk/EtjuR5OE5Bw3a0iblarbtbxlgg5qPQbbebkr" ..
	"/QDHZe9RR3jEvrYDetGnpzeKlsVqV7GIBa5aULkk4WHNrFGRFJvPFZ0b6a4YkEzNL3w97CL3Pp96ri0pb1Q7Jrbvx7wYoZrOyAz1" ..
	"l9T9gn3fQV8uR2+iQI3l/SWTHn+Xn+GWHd6llE4f9ywqhI47nx+HC4iasUXQBOgUBfKZg08N0yYzKKHt1ISvYJWp5vqMt1wBsnjE" ..
	"1MWpZw4mThpuaj+l/zGAs+uXrTT52JoHGV6VccXtVbrcjs/KT0/9jBHlUiVJBZygSaF/6GKg0VFMAFodqFk+YTAytOGy2Z4xeft1" ..
	"aI4rN8LTRgV216OGMqEnJuDbnQXIvN+NmFZTq34pKHyy8MNtCTDLQja8clvRfYv1FK0V7D1QSfeg1LZUSIR8gLLVat13a8f6BEDy" ..
	"FHBy8345qiSUzQq1uLjrD4SuiIKbdTKOPjqZfmcjYuSMUZn/fx/Z8vwMvTnD2pnNJkLJ8MKxQhzHZhekp0RwzyLD8yJ+DJY4NPEO" ..
	"+nD5CpX38vulc1RlsG5oFSrdLn40FcYvVCiqtA9RpmYC4GajauEfaykxk/D1rRKlpxCg1y691Q1W5CAGdDIGTWa2nVMqOB/3xlkE" ..
	"OZ8WbWAKyH8xthH2jTHBrOZGKnbQuw5h+wB9Uh+QohjnTvzW9Qky30sR4byGSbhCj/BOeGf0O7J/c+vkD8opw3M/EIk0HuScJ0HB" ..
	"pTNR5uPZRERM+k4wyDr1mYSkiOJcSv08peY/9iKVlKfj6E/FJWjghwKqHBM8/VDrHleLvOcifC6ZJc92V1KyS/ISPb3XDq3oU9dg" ..
	"sqoxxFhcaBZaA31csZs+xj9GsySbUYBDzvH9u50G5M1snk17DA5fkvrgIDTcti+E5I4ePJ6zGrwuJ2QpDcJ7/2J4Ky8wzzdtagvN" ..
	"Iyg1LO26K7WM4SKXRqMK5JcaWXg1N/0YaMBvwJeqg5QcTCZREDevj2IWwDdNXMjgn0jRCODO9IgE8B/GtyKt0ls9ns9n3IXoMHSv" ..
	""
local PAYLOAD_P9 =
	"rZdhzMMNdltiUcHtQh4QHxZ7RW224gIcQJVC/7+mVk5Zi3FxT84A3g6POlrZ2SKwjRCqD9lpFCPUIJMBGw1/JKsmHz5bjUQzzV/0" ..
	"fM3c+9i9kRamu4AYBOWU3B9ba596swNDkEbKhUbDGl9P2yFDYpMKo7sWuDLjTafsNDrDquLeB4mJkrlRI6e6Wy1cjBXtO1+PXNY5" ..
	"2jX+uLhXFHr2QOVYSwRRE9+Lbze7/RoRCw7NlsfTfgJIHgN9py1V+gsJ5N0EAfiwat2g2xKp0qzvQ3juUgkgEjHiCB4/b52vv55i" ..
	"xpijqTb/KFOiCEsbt3l81wJbo8cq2uzVh8KAFXanfdECSzHGIpuy2LKO5xxRjmbHJ1aR+7sLWgPAsCK4XwNTzVtYOMFvb4cpIQYL" ..
	"/omF5MMPghZrXfLhZQ9pdMJbTdeqisfcmtkHR9432TPxJP8aklChcz9mXbjwYkXVPd6dHXjj5/UIa4aVqfhCD79LeYVv/HByJVBs" ..
	"mSoDH2tkoGfKsX9v2vvk985+SgE2e8gwyIuwk/0kKQe2dTHOD42YEMlw7Xh9wQdGjs1uoJeapvdvQsM+G3JToV9SUwRqM+eG2UxT" ..
	"BqtU6q/lsko++3QrQu76pDR2AbBVuVULWU6Zqd20QlxEGUa7eQKf+akPULVGbVwg+6BOhjYZD1P0vXFKPSoxYp+N0qadedk2p5Bt" ..
	"FUUeYS1iNjad/8S7dEitW+zvf0GdD78E3rR295DD2OcVUx22Pw4rdDoHgiBFwmHa1wDPLM5MUE0gKV7dSEZh6LTiHkje1x88KEWp" ..
	"Y5bMeJ198i/KD/gxQiM0ULfYvC3Ewtz5q+oRKyc9Q3Cjy0+xMd8S7eyWRyVZz860dc77sy2j+a/16MrKp+g8x0zSc30uYPPyPoT0" ..
	"Oan5ZvhcjEY6+VhMCkURzsSdpaQCmcdFGRNENpLKnd/BrFqR7QnQD35ER1ejgnVCzHAQ+97bFyXhhhberYEwoLuCC7QiF66jb1ln" ..
	"bvm8+QafWtQ0sPCrDkBqunhK3JI2WtM1bzAxrzkCOLZ5uBQGG3FmylFqVSEzxmomzJtZsIIk6i2ql+9W6D/ZbZRPr134NRAg0Ehc" ..
	"y/isDMQV69scWL73N55YzXIY8Jlb4mpzfFBdp/eIV+pNuBYKZx0T9eXzFDRlKEFObplF8W7T9Zj/qhK5USacUnaVYkpd1eFPJM/D" ..
	"uQ7mNGGOTfXfgzfuDn4qlwCVGY983qP8X4lV6oeMh8oNyjaBgHTHEyqgg+ENolDF7SHyQQgVtnGnztYpA/xoYmRooem/j/9ROiPH" ..
	"GvbctAj8I17pUAdwu8AokxQzCIGGoIBLSUlP5WOecRIrYH71CR6dZG6RilkWT5lFMRXkQNMnvDmGFv8DRZCJuooeAmELrCX3Uw6L" ..
	"ZghSm1MrGLYG2JXCYAgwwASdobfhsjqFR3HWuKvEtN3i3iLi9csno0HYopr39QkaEnUaOZt+ekQQRsCu63GFLbVpCWuHT17O1Z5v" ..
	"J+b2xcYO4ywe5X77dNCDEZnZfou5dSx/N5fFGaijbjAmPiRJZU5jpXdZtbMbkAPQEQHnfkt4NeEJyW2XxVxmD0tSOWTBxlbtI7Er" ..
	"rmT4ZHbj2bmGtDB/dk9F/NoEL8eayWgI8FKUWxA/p77mqsc6fgnCnd93w/JiDEMP49oxXefGS34Pt1sNMOqSwSA8wzTvJXDrUPIo" ..
	"W5dhGJu7wcRo5sXYT8h5x+uCV4YMlTpi6Um5LEG1lg5nVOvvxFZbOmaiyY/IlY7tyiK/m9NCUqd49Xz7Za10qWwdYNs7PXpjQ5g8" ..
	"j+o3A8X/qYicbT7CnMFq4VlQd95kjOk/NmLO/FAy/57fUvGAb0sd4q9GQr6Bqf1Z4jSRIQO9L8CLZF+6BK03AL/4MAlVQofW07v5" ..
	"Cr5CFn7E2mLAjcQewupAek3OHCM9Jfu+B0Y1N4ovmZqn6eYBKMvO+AbbeQwFRtoRoQZv7OJV0R6kdIHzA5O+UPkaduhe3a/ss/Tv" ..
	"ca52zQDhFekDnWOn31PzNfpAjKfvjNki9C8uz2o2NRzIguUcXWplfD4FWMUDmYX049FS80JMSW9VNdV00eax99YO2IN3T3FYoI9R" ..
	"NNKz/3PvaxUad2Ne6F0RPpu9vEKB9YUVLRoyzTwhjaNUSQeG9rAuNbybJH9oFt94/825trmgA9Br/xmfO8hNx/zN6ZphG5IvzM9c" ..
	"K9JGkWEY524qvlHt+gVzM+3uTFvQR7ZHjSt8ntaGOdh/TrfUKDe9h4a9U0cziRkG27Hg5FIoMRW5jXlNh2kA2b4Vosb56sY6cwdl" ..
	"8d4Izt+OC4W8Xp/4xhgbK9LiDxMh8lTAchdGDayV9QT8vBCuKuKbLukb9DEWMRYDvX3kld95XopNV8GhX8sRaLNhnhc2vbiblMik" ..
	"R9c1zcmkXRsIskDyo6B90shGB3WpMQVMCFHya1wBLp+jKPNzaHF/q8HeZctVTHz51RIe/kf6vwbFuXSyMOl2Bu40vH/9jOquq5ly" ..
	"GlSe/pkWyI9zzsdDmgZ7RExPbzXm3c3Elm/dvmDXsf3Fibh4xkR2T70ecf6CQUbuielJYrE4ExL2NUdQtonZk8rWH9LLU9MCyRGh" ..
	"g9hY6G2NjLHgbo/DqwhOwsmNh2S6pt5GTYCxPXnrs7wY73GOWY9ieyx+FzrE2jYXStllgsmI4JpIRgKS5UGKIwbgMrDL6o/NnxJF" ..
	"IPSi54A8e4pXFDpYuyaFK53zBobeTWZgKrZPSI4SOM5S3dwHpXKNb03VravjmQb6IK3VvUIBbZ3R6oLLyAXili7r8S9HL1RGU9Zp" ..
	"wpxM2Je08HHUysVDRVEteJy/Zx4M5USighRnok8mHQvNI+UThpuwCyMkUyeezLObLtpUduk9TLcVVelaFcel5jV2NkyG91xyxMDo" ..
	"bKxEQ2lAOEjgM/5t0I1bRn4NudoPB7JV3MxE6QIWCGLLzgqO/iuns5LF/nu6i32fVKUwt+pMHjMt8rYp3pKXT/sa19C4FM2qFlSo" ..
	"gMPqjkjuo0M1I4ibT78gxTMoxh+Z1a1leXf1se+f6tMCkoHpzetKf8yQE6U5W/FEMw5HF1izJ5w9vCKR201dYrlCq0h5nDBJS33P" ..
	"Hq173eepG9RpB6Ovp3XYeiv8ikF4wWutkE6Z/4QyvaJ9ylG5BAwsJULaCHhKqzSEIsikZa7p8D2MCZvkEFu/xE8SGgP9CHIYKbEi" ..
	"on+dCo5pS0KHtYiSaO7zjYeBKNFS5aiHsp3N6GqA6Bb9BOdjqg2FeYNOLfQ5zpBic8aIMf8mJS3Sif/u4kHpOkkBz9W/6ZHaPgP/" ..
	"r3MpFGe59lMffrj67QBLEqyAhkHZNmbgFUgWr1jfrE06lsYO9HnZJbteT8Gj6Cp/S0Ohu1rjPnnQ4hhnQ0fmycswLcmMRFRq8gsV" ..
	"iGBU5MYXcBq/PsRaxbOR/MsdoKYjjb/SwGCrcnREjhAqlc4o/44q2xpqgsOBz/qRK5+hxdbz/+SnUhvHSnxOZgWkYWLVX0sgGdQA" ..
	"GGafnjcjYzoiACnKRk13Lo1e5o+ORdesdfmlV+i1zzj9kKs3Kapx/ycrpMwe39ceLwP93VugrZs0msAozUo200xG5L2TCb9V5ifh" ..
	"OGEsX6A1TolI8p95p+MxyOLBBjKBbe5IrPXEj+qUhZZFfyoxhzoHv7bMP9QeGnFW2RQ/YOE/fi+Dgz0yMmAsTgO1P/SRX/8MWjH8" ..
	"0nGZDeHh67KC6k1kqAIhiqkQHG4VjdS4xhxnM2JkJbDARE1umRZSwUrTKJbsNj2pGzS/pthbh+e3ZX1oKu8Fe/JBpcO7qGAhRTTo" ..
	"Ksy2h4TyCnrRHfQ78Nnu41zJrXcEsmZK8WEBAJ8HTHKX8u0nS1uALbbP5ke2Oa/dgjcMvHrMptscr+6rimlUPztrgjw9306KGu/4" ..
	"wFP3Wv+MS9NboqKiyvYKxhkcftil00Wtyc+USrPYmv0gHwl+Cxkqvq8KLx42z46MgvEn3MB7SudxIPpYXofqAp2ZL5LbjBFkacVy" ..
	"Vo2/1+0ni7t0eVHoO8ymJNGIyu7tQ3ZphzrPnjPKNNJ5VmqDjDuWTbjSIHXsD5oQLxIABYdxLuU6dgj6kKk2BC+wjO0a075MRurM" ..
	"gFMUUE5bucqttezWmPudzS4PKpaO6qwP3Bv5zbSgDScctydfAoRCbfjhTJkjDdWS3lZDzU8oDJla5x1dUozxjzB1nFjeZ8pKn9AH" ..
	"hOJIw6ZCqC0IjeLW+M3sUdiPk/+f/nkZKyGxzQDPFMi73yXyasQI4vmjRLLCSKiSqlKurh9lDIeuLNORkkUY91wqoXsXznoBQQoe" ..
	"J+/J7Zl1xn0O/oqP2obMtZ6MHg4Po1w+1XMKy2g2eQ4H0fhhq4A2huBEFR0mDalO1j4paHH5KQTeR179JRuaCEQBNFm8xJOu5+Rc" ..
	"4eh7zmEluwqup0NjGM/A3OUnzxYjY/ODoggb1seblZoUxlp/jAKaG7LfwEtQz3c/G461TQKwNKCMI70dxxg9X2qsBwqCBCE4OQxt" ..
	"R+D/Swqkx0OCxxDtrnBdlaeliKI1Lo4R4cUg70M/jnEnI2kBLcR/V14M4Qfcz/492/elh7joUTzmCUJimWSUyODh1Dhz+BTfyo/8" ..
	"Q41QC154ZejNmfyN6KRK/qzle0b6S5fQ9RfaGGcwfrD2f27bV7nfy2hqmGHyS8n8Ycv2gKkU9gLaKEM2JWP8pzzINbX8Ed7G5mWP" ..
	"Qu2ykikssdB7httxNXaW0gs2SamCGA9vQ3tRH+iKkXFsQuvKP8zPNveWpGFbcnaeGyetdn0+oi8zuQbbmaGXyi4m+hNB7kQZhmAp" ..
	"q4ZOMy1nrIFmICqxCp9DlBBVoE8juqIRGCTKk9Y3ss7rZfarONrJqHYMFi22GfZnSe3MvnhKhnRRiNH9oHhMNisaCrdmE6w710oK" ..
	"RGp3uN6GFG3Xdgy/WfH6oVQQ4t0xZEgWyF4Bx6gSxAgYlaCaiqvzZFQlyd51g/mEFdY=" ..
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
