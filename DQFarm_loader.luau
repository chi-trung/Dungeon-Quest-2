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
	{ seed = 4291987214, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4289390360, exp = 0, plan = 0, hwid = {} },
	{ seed = 4288906109, exp = 1788089514, plan = 1, hwid = {} }
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
	"BfWcbTQDxcJLGab77Wt9yKC7PJdBGNmd2oz7EeDTumrlOPWNe5Bgu457jscjp5e6qflYZhLRhbk0QDeHLMAAG/1BQaj72SpWg1g8" ..
	"TFJ1kjT8YbjkPIcsw2hYDGbj5W9B2FSOQfYQM97ZS2PkaRIz16IMGyFmQIzfM3iITWgmADcrNDwH0fLn+r0D7Tv1tk9pSE2HFwZC" ..
	"tH3y1d26KdqHfhJqSmvr/RDLBHoL0Mewz3Pf2To8AiM8G/zsPn1NfaRRbx0fbsJrYnm7RFvq2uC1+AozdtreNyWHpJm2ZqSDLOeN" ..
	"12H1mp6Qi/hFJEBQhwo5m8QvZ0AwI9523RcdZUxiNhMAk53Rdpi1co002wfQSXcRNv3nkiWzphSKWhnVim7h2cRs8np+IPKI5170" ..
	"Q6w0o6mgei5tDPf8EP1Qb87llHU+YSJ/jpAJbygJ3xzpGwKfWwv0i1oc/2HEZW3hQ1stFljQbHE3XE+HCWbd5eq0ITY2n2hNnQnq" ..
	"TW89uOZrCEzvN3/LP/ouuhmfU9H42gFkHiUl8eZzY3pFW5mr8sN+ikWOUVEgkq8NBNstOdtbAnucQSvyfS1Q66NrDERgjPe9ccBT" ..
	"9n9xZumE0oqpF8HD/2dMemJ/zSoqeXGsk0JM1g1PU/zaKfK3TfyczLiMVaE82DX7b065BkMjRc4wmQSZeGLAnJVDcp6+tweXvrjG" ..
	"JlLEVf1GJYD+kfz7qMOVQVqpkZHmDQvZN8v3eNaG6xZbxRNfLJRCnalqPHkEZARbKPL+tmXST6mtshbOxPDfWNyCjt62obe26rcd" ..
	"mKkA5E+9a+NDYa6SHxYrkZhzQlCQVM7pGEPr1Y4qeV31ClSfai69kcCv4XNxNIONpCo/saeAPZun48la3gIi8iWQyVvHfXOUes9L" ..
	"f3yUxZXaKatmode0LUOsAMeUCEVHxH5m7XBXA8B0AojsRBhsoOnmDtKGkNqD8CAXShOzrRIIXnnPahjfl0m3ONT/sUEXOn46xgVW" ..
	"fhc7Et36U/LbadNzKZRd1XM2ptpV9wbP7Aj1eEiPTPtgWS4XLYTf3lIHwIy7jsNWDu/0bdNsxsHEoZE9Asya4+KJ+PfWq6EWwmQ4" ..
	"9jtYNpffTn+WTDiObljCmPolRI2jkS3KiVrTRBJXfjYfcOR0G2VUVmxzlN1rOkaLHRGDckfGU2JtnFTuzeIJspNQQDTQTBaaIRlW" ..
	"RVEim/kyY/Jb46cLLi63BoXvNiaEUbsLhPuHPlrYCmhkCKme622MvDKB7UnzAfEeB6xt8yfj4RasuDgC7m0wY1BVKHsEnF5kpVm3" ..
	"0pz6ua1cAeTSjVeFAG6SiaxCCRjFph/1zrB8zTE2L8dOrj0TyUyTev734ISUyNzWBKZMtVW6HSg8SsT3urVmya/3mYNP1agJkRHC" ..
	"uKAAJPb4f2IW5JIKdiWoPNzPVngaxgLxPkOhWHFqMNkrqiKi/hCJ7e2/VHMSnHKBs/d1YlK08zWbgq9ralo9X4kzgULLkaB8KmED" ..
	"twG/KBNikQHD6WItjAPpwULIenBnJB4hbb/Y6Wqvjh2nc09xQaz2/2or7gQNKm5mimNS8pxFoYbQ25LT/xd9Y9zwj5T3HO6TzymW" ..
	"DT1DlfqS9HXgQnyZtQPJsM5jBFnVJGODTT/WEWfDbeiiTJrP0c4WfDFh/SlZAfZm7km/IjeOV8BdumUGesGT7qBpMdFCwU7S4DPT" ..
	"AtXCt4g6FhB9nn142Ps6lOfyIDEjCg/zpEFRwUAuPSuUj28uC169Xp6qyXENctwSOybAqJHlgT7vjR+Id+dP/XnRogf8NwCjIPDx" ..
	"CQYJZUwJ8zx/4jgp486l06WsJc+7r3kZ/f3JOE0u2pZ27bx1gmgLdUamShFuON6Ixqy23WczpuE6DEwuh8XBdjo1FdiqageFdIXc" ..
	"V9gezq6bPhF7ZB8prNgg+/7/F08dqxQ593pfZzmEwZryFvvdZ0pgR1Iz6Kll2+IG5KDdrs1NnHKma9hd+pE/KEcc0Rgez78DO5R4" ..
	"MqTppcRN5hiNtCU53s8uafaqJMp1qKewXBJg51P11rfyizPjU9bO+m3bIfQwQT5YvdfM5R+CE5t3iFQXEu4zB8EVOjb8zig2PU9s" ..
	"yUkgtCom6UFvcB4jdPK41CFAEmOK5+9BWYo6RnZw5Y4WZ2VMkgkvc7N34McVcxp0IYxJjfcpdALuid07823x26iGB+4FLo+tC5dR" ..
	"OlKgoF0C2LbIJMZIINMWL4YZlu08CchGAe4pHthFAK3Y+EEMNZFrWYBMbNUc0QvJbR/3TArN0yIkuGEWC8eoMSXJJfLJWlY6+M0J" ..
	"BERV65DIhqc3fG7GHmKdnY+XxxTipuFFj3E3smXosR1ycVZiizFxmwknB3TCzpm6NhXcE0Y4kiNi7zA1IT1/Ooganugx88jbUcZU" ..
	"Pb5pmbGdub5HO7tJhfdSyatwBhylOPbiI0f7XimQ9VuZzmLLjZAQghzBSKBu3h+o83Y+Rc7oehtek+Ytn8EJHotVfm4ly7y7d+U3" ..
	"gjCkBj+1bmXx3CWADqFM6NXYZTn2lP74FxaQ9xUPm2M57ZMBJCYhQltImLvvUx7fjj4tENxivHqiXGE9jnV2OEJrlCGHY2dHNukZ" ..
	"3NiGmWhmUyyNjh7tv+yW5eySnTRnKfxHTI2g2vFmqjQMlAlREJGvp1LVoDwYYajQeSl3YtgMXWAIKx5X5ZqgyoTDm1KU1ok+i+S9" ..
	"V+AKGtlPfOb/5zrpaE3j9AmW22Uz7IHi60x5CXw0WNpHU2HjTMoLB5e+LcrrbUhaIe4WPBRdans9QPpcoHYQUnUir1YKkXVdAe3u" ..
	"ZHlGZesjKNv5TkRAklpO1uHneOWRa3noxmheAKZkFA00iDSBMDPCQH5bCb8S6bUgwS8KIZwvXvHG9W5lhKF/AJm3A18JZMDL8QTc" ..
	"bMxvrgnCsokdmg5hr05SL+DOhbJ6Vjmn1vTG6kWGVCKzwm+xqxLgWlrPTcCtAZQWmNoJ9Pmw+Js/Mam3aRKo/yoYEnjDwcr7Lfe7" ..
	"Nw//K8Yz887JWSzonnEFDAO/AEE2C1YGhJxBmBlwjo95k1CauPTlBynog4ShDe/c1iXH5BOwXGkyEgevf0jMcoKWZInuTsnkOcPp" ..
	"3b3fBo2ONiLhLui+OrL1hZm4XzvKGwKYLB98XlnBE0LuydbyOteGGJ6B3sDqXTgDmd/+jVPMiiwKozztICCWVIfvBPp3rcGJsRoT" ..
	"ya4EkZvRxWT2mfCNPShR8UhuGPPjEyoYQKKoaum77y9EoSzJfAPDw4VbSq0qId6nZtwyi4uKQ2yhgRaS8cDDiMN7QdsgRpZJ5FZh" ..
	"kW5KxdtvguHl0nkxnwCNdsKuIOyICSV36TcxTrOmBzGPfotqoER5N+xBrfCbcXemoRXblALqszlP9tuUTB8VH7TG8jLwlFIm3jHU" ..
	"BbdlsQeW6hrAJsvVu+AO3cOt2uhQilMQK7ycEboqMCdfVqGUlZQjjw0ULu7la/4mEy8UKyRztrVZcWX/avaHb+v1DFbVTuym+/Xk" ..
	"/i4nxxMS/fggR9qxmSyQ5KIjlVPZxLYQ4GK3vxi7tU+RbD9z6kH0SQDPOrGd/+SzBTH1QBAdSyH/FCgkPS5nYAub12Sdf1JGLnbW" ..
	"DTpcRLEDEfTg038+IEj3p3jR0svbfomI0uUyR0CvVh0688Lz9YNyERw+/bwz5XF/g1ExF+bR/LqYtYWvNATVYzYDog12V81m5bUS" ..
	"1ifgvFXLaeQHFAxAj1cCYMaJuFyofXvH8dKQ6SB1FZ8cDbq3VHvJJqWEhf2CypfLz4yrAZt50LO4oM52TK5mZZ1LasulXXk/SKys" ..
	"iaDaJnnxKY9cvxPf2EbBlhlmAO9sU/G6kbR+y44u+Win3OmCtm1xenGqc9iFf9EQsKJjOciakq1DzibiNDa9NBvTAw/MP0fVUEc6" ..
	"np8jSgwu9sjOUr+NWxJnJzNvj/GIZoN6oXjgDeHJG2a/MK/CFFFC92PeAioSIyyiYFiHEj5fzVTSswuIneACjRBchmxy9j5KRAKS" ..
	"7SS8UqZm9+J3kjHJ4M9T0FPrhi0x3TxNd2/DoNIHix7+NniILUkSN2jphk2//a71GwcAkpN6hnKoTQX07XKvPnWAk3xzNHUa2TpT" ..
	"3cjbi2YMjxdWjImrYptrsu9C3GRl2pS1dU/CXMvF5fpMNQzJQeth60MNhJjEee9HSpx/7v8mwZEzrpSt6D9iP4ijjzaoD+P1zDRI" ..
	"56fIjL3LbbDAlY5TZH0X6ZVLJQVdwYTEBkLxzpgPjqvC1RT191RO6kejuFnTHCQPtpjJp9pOKRRHE3b2pPc//FTTy42DKOl7F/iQ" ..
	"VEDH/AD0RhaAK0gbRZ54wPeCOkl+JnT1jJ+O1A5RdS4Ks0UchmxJEDTcgybfynxzIiA6mHVLxUx9c3C4ddJNVysoYtieW2CU18s7" ..
	"/8JQQ76vdnl87EMAun0lY2q0eO3m9E+imGHpEsSS+k9sH/+d5hVrUqig9w6aeUGbZWbH98SH/1vAOEmdSKtdD3TAbTGrc1EIWjub" ..
	"NkJ26yuNjKPHKjGdM5dSojIumteDDgEZRjGiTj246KHW+EHX84hoyNfkIt6PezbmZXrlP1QW56dv/mKrhAYBNweUCwWq9d+iW23x" ..
	"zH9gkr7NK7nCovCty/adxNSmZ01ryRrKds1iwaLHwrhRrkRzeJgh0lOUGZ+vJBLqNHRPtEHrShQArHrfamKzsXy23OvkP55Nb2GU" ..
	"M11BUfabnPon0OPxIVMiVQnCcw6QLEcPTIEuT2Wz+W1BtYjS4yKYINOEZ3nUgLBEEfIzNuE25bYXFBMWG13hhqS9Xv1KUkJSuN1Z" ..
	"xdpTsASsofNHBnfBEPzgtphB0bheiEnGv0ob/Csqpxa6uK/pPwxhHqVcl68nhHgatgM8S7xv1NdyyJ7Y7YObSCnm1wyeAMbpagXt" ..
	"y5HZWoOyhKDCNSMwKROtiVBTcQ7OnpXV/EAdpcWDu9AcIljkmnaVJ5uRP9f9noyc5sHFDHdy6tLgVAYpvWgF8x5ZJykb4puUZz5r" ..
	"LP5OczkR7swF0CyYG1yRhcaRAj6kYGaB4pmRMG14NRthosvl+aT+gKe+2d4GXERUx1LxUYGY6Iu9Bqrbxo4f3eA+QVLauqZmzF3R" ..
	"udCdOe/chpX1M2ZE8XNhleFLXi0iMJYRKhbEHAisjmznsixPb+p+EFRPmBdCMvXgktv/F8cV0WOHZXexZRb0A2H2bPsKly96Te+7" ..
	"5DgSaoo72UE2HfPlaWhWS/yjXYVAXKZEkt3N90pTy04bBOj3FxSpReAil5mwnzsLX4xUy/sVfJqImV4c3v21j1qo1XNKSjkbRrZ/" ..
	"B5LR/96oLnH7Q2/sIgNf06ITj3aSRdNtlfkWcoGrgISpRTWElwkyw9wRhnGt8USB8TsHyNJzmZFyqhFB+LU7SwD5HNKR6p5dBX9n" ..
	"eKambPvnvdz7kscRnW+eQzgZJnuRgfcV98fupHvYmE6RS9QYaqVA79hnZkyz9oMLnFr/lMWwCOXW1Sf0yrr+OVo0qG/UqPkWxskk" ..
	"0i8vSHpz6Uhs6MI4vPxhr/yQfdYysTDYYlV4ta4Xzw6ll9vjwFU4j1l6JTZ2ZyAtfCZsNc1zy17cbHaka+my0Ew/yXnT5/BWinus" ..
	"IFSrR5kRyP/gJ2NK/vm8lO4todrNjQ70UTUvxazYCXrowua3FViDEkVbijb4kY6IBIs5yf+wFkexgR3Pl6ejuEhV4TUPywQrBDjp" ..
	"iyCPLX2KDMijO2OYdZ5OZlD4Rv4US76vnQnO9LgVRXGS9L4xj/EIldnBULdsLpS7k6n9NQu8RXXi1a/ZP3VRL7RAZ9H2XjPXK24b" ..
	"kY4g+2NP8IjnvNKA9ASBVRL8EV/utkS8AP3qiowI20z/016vYAEwC3wxoXCT8sfLS9xj6JD6U2n4t7j9OfckpLscCG8oKihgUNbB" ..
	"7aD0iMpXE6djRzInVk6yNfPkIRIMhZ/220CqJSduzBcWoxoKya9kAuh60tJYr/OwbfEdWJCxS4FIhFNn9WLIavTCzvZdEtCAypVJ" ..
	""
local PAYLOAD_P2 =
	"x29mup/bGTK71AP2PuffCDc+KvWJvpuZ3932E9looGfc1eSpIfygMQ49sJtxL+egyaJXXK2BlYiRNgtoh+uGMmJYqpOE9peiV2ce" ..
	"8i9gaSHIKEbkgS4pV3vlw/ycqAIbiCIvJpZvJcv/ZF/qalFStc6QR1D2M+gJa7cV68TCwBGxbAzhGU+JmiCnNJOy2h3GugEuKZy2" ..
	"sD864GHy5ZgR4FGEqaLE31SDZ8UmZrYIKr3ong3R70TmACDxW+1fDuYdz+l7NRDuus8GUJvgzVCSFg4OUH1Gq/lsm2ZDrzRCiyEd" ..
	"6aZ6EcqdhuK8O1+Kteuv7tgubmT9u6dmC24i72uaTXAhhiVSaMYZYOOVq4LqNBJ9WMiit+KaOr+3Py6JJsl4HCZ/9EUzA0iK/Hv4" ..
	"L+2GWCfhkTUauYKEsJ9Vksq+X6XZqXYntE6di6STU5+P54sc3DUj+82lHBt0O4946T4g3YkJTwQLhaVmO/RNNsGF6hee444v078B" ..
	"5VkeK9dIZ4xFNSD/1GAcQi0+6bzdmC3VNhoyzsR1Mc+wrs+PjxjKTNAXQIv3nUEkh4mZ36YBxwStWARbErWqIlJ9FY8y6Ac5AgHB" ..
	"q3WGFaCxyGIRdZEEMSXFssBd0zoPoqnRRHWfC3AUFk7ONlIHf5k32F52zib15QeoQvn5uH5yEmgDETF/cL9zQAKbNgGghdLwY4I0" ..
	"ym2H3Nio05Y2Ih3EIIUmwtKUIEh4vbiVQQapOETJp1ln7YFdg/kABO1YfDxhsVIawdVvVigEnWfnDTFkIPihtRTKJyQg8A9hHXMb" ..
	"EGN7OwEmqPZ6/LLirz9T+UVaJJUS6NVRwznAAnGDo4oh+tTv/LcqmS5FH3Ei2aci8Ok99R1OulLCy7nBaCF2QAHeLnLNoU03fkLL" ..
	"F/gSvmxuQRkqdtCQsppMuiSS3wnTzHPBfS/MOqFH4I/f/WtLqI9+mUZLsNdC5ESltzjuZFVpzkWXToCyWo0tY4Po/bsNpBKvGVK9" ..
	"QwVlof1Fugg2PlR6HApszJZM+IWJLC57LL+ts5qWu4SYj/ysZltG6MGKTlpeA3O5qtwQ/F85hw4fjFmm1aco99RQdzHlqYIpsJzE" ..
	"B1cRbm19PvftsgMg75hA5hbO3ootB2Ahp04igH8o6Xi2EzEF+EkTz4D3nH7qMJ8RHjENhhUfozO3STe7SGG1hQUdSqdJVNoQKr3t" ..
	"zH+Sgcsn5FJFlfH35X+ENw5l71gLZ7BV4eqFdXmns2a7GiGFi7P7f8rqIpcfgT1ab1TE6M0aQco1MYe9xMSdSnaNlqTSLu94Gky7" ..
	"Xifkug7tfFsKNCjXPcUyI9wQoyq3NnaplXZlj8AmgBHVQHL88XW4d9DePlb6MzMqHlRLK2u/VMcn8MLBu0l7Z0WRZMUbZFtcBoqt" ..
	"jtvvDueh/o2m24wb8xmLlxP6+M9akFC6Kdo2mjdeW9TCnWcjmsCMVkrwmVKWg7bxr5eSMs9VyPpTSx8InZ/vRVWni/wh5MUiL5HZ" ..
	"8NsBeBTzS6OAg4ESFfBvPagn2u/bOK0r0JC1REshFTf4S/GBxOQZg4CUQ0XHrRz0+s8B1HAY91+Gcyn32Bf1X/8D++9F88POWpeg" ..
	"i6uj6VGkQe0K6nsRRKJNrt/aWpG5hclNusZ4cG5LvYG8Qap6VvzoMgjTK3QMXFACZpkwdDsIYO4kQul6w3UQQyU+dhF6NFi/ayNr" ..
	"3areagZVDumLiWBmA4gIah/Ipfo2EbTDgeqO5D5vV9EHC49K/GimhK9l+n1Ssgjre7WjdljZjjZwZTmtcQKJUqn3xBJcMwaBBKlK" ..
	"Pm7B60gG2mmS07sSyM2vBydy6WJLfZuvgJI4Cg6DsUqtefw9dAj0QFDV+fhUvWR+VH8IDpfSFktvn0FoRBVeVpfjpYZ+uwqBpnXF" ..
	"+ZXArA9wOVD+jQp0raXGV1U0VO3NcQpk85cz9ZWEL6PBKKxBU9XjOXWl+CrKuI5Y/j6DFjdNLnb+2dHxpElYf9mLtzbTZfhXcCDs" ..
	"xIT9BhXfvbM39iE+1KZ8rZCrbQbi6/1qJy3BgXeva9xOEBwcikKUpv8HU0eAo2v/qhBx2Z0hoEUsKIHcZIBo5D0YA/bflo8g5WnF" ..
	"v3opO/uOXcxpryV9p4Ct7R66hhPmSt6kd8C9HjNrU3bFcEVcYVsSTS6LSeY8E3VWlDr5jU5inSpMjvh2BsB2LeDiS4ggJUQzFJCo" ..
	"6hfaLNQvzYR/m7E3GDQ6RB76pEzjl4St9rIoFPA2etCQCLg9prQqXCClA0osojjeLK3yADFRXKqAYrIHAVgEphoeq6DiBcGSJOo6" ..
	"3nE90CkAnnMAIaEGrKsmCJsJqQRyxIiItOj8Sj7qaxuoVLBLZqKY75PpvQYpxaAxvH0tmdDSyXTRoLicvPKLjt1t85Fg4eawSnlX" ..
	"qQA5HCLHtVDEpiKznwPqjveZkucP0XqXSV2RNG8Q14jdDlTGkfY6e3PZC5Aw/RMtaC70/of4iOAvNtlpH+kOTjWSZY/LmqvrF/pc" ..
	"O7MrrNeEGOFtIU/gCJjPa8VlKl0ulC1zS4PsPgRD/F0HcvBvc57cXvhWgFi22XjQk3hShtXjz7vOS7yAeyw8TazUXzXBqKvjg9rk" ..
	"xDQubWznMk+CmCl2INp0ind/sQ3JoxKljCAaXxrJLFZtfgAyrGGHv9UUSn6655eiroTiVpqz3q7w29AU1QkHse+PzGN0oJ7lMyfd" ..
	"9+LwZknNcLG/Cx6Prl0f4bz8kUsabYIjGCRD3vECe1IhQ0lnZ8/wwaYNovvR4rSghEFvsFH7NeiDgliQ3zESQINj27AVothP/Yzh" ..
	"f43kiClGhv6RP2KXXgIvl/lIMpQuQyS3Hpq436y/wZi3DNG2yKSY6bBEx71MRxEfM9VEsCVqQ9dOf6tPRiUO8kKWVNqb+00yoqzS" ..
	"jrfPBLbNhhBWjgQPCEa6qoAS1FXoGpNpqTXXhakS5fmVPV0zcdeBy3goZ5Qpj6F+aWGVHi00t9mtwb+gdLDUCMKM4KhUbAqSN+qL" ..
	"ZWxzOGIYu1Jfa9vDYQVsVRjIzu2XW74xpOLw3HNuF4SGx/6JTrhm0L4vL9Vu8D2k0JRThZE+e2H8t/Ph8to+W4JK4XRcsz83yDGZ" ..
	"DgMYhtohwQgAY9lS7DX30QLNcTVhxduU6nb7wDipJ7v8UmPpOOcrp6kL7KPjaTVuY8AP0CRyq2eHRzjZPcIv3Y4749V4xZpG2MQA" ..
	"rNZhqpvCshul6O5zUudjClmx988e3eJan8IIECPhT1aJO5+K/tcvkaJajk1T9wzEZReV1lV3Va9OepUE+QFXziX3K7QOHrY0ZahX" ..
	"6x/D9+u4jyVdJLNGfd5tzUfNiG/gOhpItKA80VedUowDcqvZdVEFYT+jMeBCYaSHVWd+Fo/l3KKzhZszT/HB1cZLGfSdMuzOKLrb" ..
	"ODcMmFI8xU0NqFATO32apjqYwD5wV5UPbucLdA5nZioNoCbg9MHoUHSQhkJZFaJiG44p/kPHyQwrqbmgJwHrCgr1Q/NTcqeEDlLh" ..
	"euOTmHfnQtnwPerA8LoNuMpbS5a3p3jwjWQbvyXYcIB/LkMLSHP2XmSGz3LgMQIPTsyKFD+sLY0CiF50e9r1ishx5uIoq7QZY9RW" ..
	"VaSHsNnLtngOQIVTRzh+6zvyakchousczQ3qoMYVcRB+61Czk0FbMtfvPIUxWPIlWn+dQVZ7b6Ae2g+tkBxSw65i+n5tLbGqDaRn" ..
	"jQakChbOn5XfWSKctoMHKD0AxzoBdfaBQn3e4ZlKrlK1mt1SOvGyLU8n2eOsCa155ho/3VZv5Yog/5YVjtw9YkWTN87bT4GJjwdW" ..
	"6wAqbCpD791bBcUUgCp5ZmWlWzLLdFPXy0AA7fZb6hAR39b4iv02N1655ClXni4OShA3qNFz+x4bhqF8tI94Z735EGR2Q577y22x" ..
	"WzsRvsKDlS+KVHHQz2rl8cRiTbqeaYp10ZpsT0hgnKLx9B3580FuAQWdVDegaleha1zeDM4eWe+1uenBwke4g8MrQNvU7BG57LZA" ..
	"taubBDdiwkR81Z5/trv5PfWeRTsDwpJtHkJ1wqho3BdywrvEMAspEs0UxPvSkYWSIs7MVa4ngxwgxo3IH+RgdNZaQDz/E2a8Z4Ez" ..
	"+gEFYTHnJqPSiQL2DZzGYylPd4p5y1iUnTJPyt89SJL0u7910yYON/qA6kGpFYghEPq+Q7UPE1j5IriE6GVgXnJZbFJqM64fFBpg" ..
	"QTlKlOAX5VhVrjCjoXfo9pIlPiDH8M0kDPcknHO0Bsh0upsUYbrCssp29dQ3qhXuj2+ev+58hRd1c2Ikjw8SDfHMgqH698DniahX" ..
	"Uo3RSzeBezzDUlPgQXKxL3CJZiHBctP2Xq8l00wvasq4iOtrtOssyKRR5ggMUbsW+NQl5LjP4K+fvvQpH7nbegZpzBBH+QPFVNWO" ..
	"BRs6vsIT6vG/t/6p1rmgFj8z7SB+bHDAZy8zGddLP+gi0c2pme2smTko6e533PEfUuSptOeitKdJsia8Fm0VU+Q+WeD5VBkxA/Mo" ..
	"wgrQ4jElyYHr0rAXHtgwc9J44+9MQCCqs3T+PBszCKCtttmmSDpphPHDz4qEfn/ikX8EzzbhLOOa0zFFm4KJbe3f6UY4kVlH3ukA" ..
	"CxEHLkZrCwPYkDkAV0aHkgq64xYbSLg+JxugjvqtfQvS44EpCA5GJ5YdNZFhSXTX4u+TvTUXOfCliPLbUHVpEL94T//P84l7bXqT" ..
	"W+OvhZFcs8n5PIKfMMP3oMth0b9JWQk5oa2ZTxhtoruG//3F22TJ6w3Wu3msf3HyEs9pdvHsmIyfPk434WZO0vZrGRShmIacEbuR" ..
	"4SviNU3HG4HB3i8vMQr9GL5LeQq6OS9G1nmPXI5l/3FX0TT5ycGm/HLFIDfi7NrmHqi9Wd1HxSQKOdumZvoBc7ZuvvJ0/3u/Zw0X" ..
	"z1q8X5NGMyvHm+AffYwoeNWzTXJt4IfrK1i9x0wFaQQOK77SGIcOLHoinBatBuQpDcBXN0o5kQ+S569fO0QVG9abwheFGJ6Jm+5T" ..
	"dtAADJWWigtnSIruuroLYjN5k0271Zva+PJZvTOu7j/zauD75rG1iOb/TWdR+qnjUwA6B0nyIoQYXmTYOcrOb3fcUU14juo0sQeh" ..
	"AaNtWZzFgDEtVQfp0em1qgjlf8FYoPD4jLhbigOpTkY/pxgnCWI9XLXpgynz5yCE1iSFItG3Ly8r5sw4GbiYsObBTsfcuHG+FCd/" ..
	"odbgcXJtbMoj8ZfNpOHVm3K7sqnVEWXVWN3l8/wX1LW+I4r/7CVc1tU90ojP5oqHCwhUun38tnFIOPaywt2C96VkfjoapInQ5F/t" ..
	"qC0Y971w7pp3E/hEhOMgbxqj8vQOs9Kh88PLwGoT8ccFYfdVLSEtL1YV+aiHmsdPvcysoSwIU19QNu4T1Cj9tVtj4edXIpuq41C8" ..
	"vRXBJOax9UkIPocX03LfckPohq0XuSZq2V/Mwjt4xyi+BiGI+rHffvA67Vs/k2ae96LKuuZ3KntgwZ72L1YaAlOBu2J1yBDEziTp" ..
	"cmiz0KjpCJKYUhgjvSaglKCIMxmySOS6NgsezsXdBKYDiv9Mmqut9UqmjvDHMWm5wcQaCSGF8HnxOvuoTMGFamAdliCHBYpQz5kR" ..
	"mu5ogTCzN+/VA6eUJnLA/tETjlKTDIqHt15xIGe5hjmqWVdyn68zDdM7o9ZvrMsw4ADWym90UbGZk8yyHPMGzSEygfUGI5og1yRn" ..
	"4p+f281oK/6YNRDsG+OZ9PnQ894eL8Sdtzj2o04lkI0q5pH5OIJaa4TWGetpDUnfXjHFOWzZm0HSnbudQqw96dZtsDusFV1Xym8q" ..
	"nwPoX6mC6dsPpLkwY8NgYdgaEkMKztFxZoLUiMcMLst1aIJr60h3j0CTjRBsPIFn4Ic+XRGlYfC78mJj+ERWV934QPhfmZSw8W54" ..
	"6FA8BSXOsDBY2fNSNGUtV0ALwv516uPcsoK3rNzQoZz9KFTM3zWVKcvsNAuE9Kr8KnjJhkfAOkYcW3AcfwA66sn4IPqUUGPXJQtr" ..
	""
local PAYLOAD_P3 =
	"Q1W2L/9Il+gLWSK4AUa0EEW6PWErRehOSvsAUsMU+wKzLAoZxXBcSNJr+3YNTviRHtVpPqAg158pCU4k5+FDANdIkhE3H+gF3XD9" ..
	"nEMv1EBR+GdppqvdkPaVUwUR74MGRiQ4E1T1QHCrTcQynQ0vRRaSJZkAUiwiYGMDIvfKB1wrZ9ZyHcIKeT9ynW6c1/0pzKUuomsi" ..
	"hIFOmKPW8s5usFYiVV2gioiQsoiJzaz6nCvUACVn6Qc8UxJV8MyD+/K3eLMw8V9q/yWIABJXMG5bCbwTukpSk7hZ5mSjayenHO76" ..
	"oFePPQBIPb6adPtV8RiRuU+5tmeSqeO6XBqpH2bwOQ26wPa/vsAEDPjXRY71DBIhLEgWyn3TBEB1DJNpsFnQhRvFkBL7P6WX7SA9" ..
	"gnI+N/jm2GVhiRcK4ur9Ay9u0hqYUo+uGxnOOQmJULQ+2Npn8wSou6DJJFtJi692gh+5YDa5J/HLVJBNLJfbZMiPlqUSWIQtypR/" ..
	"Iu7G/3LaVnPNEKlzuRQi3CEQUi3T/7i7OHOEegc95k1MeuF5yE6/F+KhbudA9j+ZMcYMwlmA3gIn6Nbf+NdIOSv8CrmPL+iH0XJj" ..
	"v39K0ZUEHNqHdAiSguf5VfN1nvzTcMXkqNnOZrfPgvreA4nOdPR5EDObL77WZMVpWvzmuPCpL6LyH/fYYYC1vFBaqYTlG9J+W2YB" ..
	"3Rv3jf3LEwELaWz5He39PhEJoOl2r4VajPCFCLsbCO6CUZGjEAsL+PErpzTovCnj8cPtDs27QyWQdfQ4AglkAosxoJ+a0LvfUtiu" ..
	"C3FO8oCTvFBBl6fgoQdXL2n1D7Pr1d/py52MrAJ1r8EP6o3BcaLVLB5dmpv0INgxW35l36fAz2nXASGj10vQVB3YrOZ57XLisQ43" ..
	"+v/ZV9EAqW6L8gMII254zPWQ+qSJs4wWexQ1foHm9QVN9P9M8KvvGEUXDAOJTkDAiNbtH4pi28bomO4L83+jSyuD8A3v005mT8mV" ..
	"NhqRdNhnO+mHdneaFxd4p++eP8VrofIX5F1MuGgkoFS168HdXxtDBqy1fSPF+iwWJ2K8WnU35nETAjbLRLJezpLOqZiipmKPUQWR" ..
	"/sTAEnLJQmmQr9WeDRGu1d8NjQIrXxzV+tr3YG2amXXmuYYA/K3fbw0uaD0IcWxy7/aJSf7JGPcjU1SNIZWnwJFDxP1vXjMaqmHo" ..
	"4txvQ8F1eDmOAyo3YCGd2x0/jOpp5y9OhKKJNKLJVzWgZi5nH4XWQ5fMiaeZ1gqaUBrSVhrxQoz4XQXaAwNpcyk1Y2VMQMpl93W4" ..
	"5Goq8u0UbToqCPja5kdeOmAfMYd6RA2wpgVkPQFUkWlfLcUHnCnLlpnPERE103Af6VxFaclmKUF4CbFerkbTDaLaIipmD5CrlkT+" ..
	"sDuFQR5yT+h+pP/TtN7uApzpro4flKyyXR+JGJBvmvc4E7XtG/LxZfBEcywj0GZirEQnHmT42xPRZFY/9obsjHTQuwsl1oFCP0o8" ..
	"I4GxtDa+cmO1GZFhPzO36c983elGflApWTTmEyO6KHViHyYUxgoaLywGfyPx2CmBBhllfV3S2hANK0R3FP5m+S6Ke7Ml3beaIUBC" ..
	"PMh8RtL/MPBqk3ZnUGuziSjGiMfUL0o8bzUVa75/HhSjY7pFxHNCOv51TksWSdxye1ChyPN8Reg1vIaWc8zqjdwCxM6TRIg8EBaU" ..
	"x6+jltrv2tYojop7yl57ZrRqQ4jGTnGgl3WOeB+Xf34ZYv3xZUohr35pgNSpmmje8D3VcuIz6QwlFiDizvH7VseS1qE9XRVHRFNP" ..
	"FbdnPtv0GF+AZNFAaYJA5V/kX0rSKpYFtGoPlNxMPKK3pwt9xUH6LTUaxXzy6YvOR1ESkDsluXQzfJco8lubAhuBvG4osfyFrSBB" ..
	"6bR2/x7N/Ikw3B0sPXnfU+cBWnOMwn/mhiYcSs4+az85WAXe/RsKI/8O1sE6cx6qFwlOiJYq7mik2rq2YeZ0SgelozzFMejcJP59" ..
	"zErkQWKRRw3wprCQA/7GqqQbR7NAxjNPBuFu3i68ALigN3AWEzyG+Yp8BX3bkoIBeUgnzqCX/XWnrFcAFdAqmhi0gE78/NtuMRwb" ..
	"OV8Ak7gx5zgxUl7oGwMXVTQuzVulQln+JkLYGZbbPcP5FFG82jBzfum9pHuCin9iSSmHhiL4gwIli4ug8xPpz5/dXTdN3gkFVDnd" ..
	"DoGecw6raFA092vAohkJCixy559HgSLFjOhTxivrfe1cHUSE09aHWJMoPoTfVWZ716k6+r+MFBFv4U72Zo5L5cpCJUwv9XdQokcL" ..
	"tj4AVe00Lt0RM600trJlJRuFCQ1pBfUzPnxtY8DogxET4iniXPuxfUe6TH1JgzAL6QYVcKgPKWukxMdFAFiSBJfYSirl5JuSSjgW" ..
	"rToMnMo83/xN5loqdVhKqWXPVieu88Ku0ROfI8slekrxjNhaypm+MY9QAM0hqkCa8X9llXBQDxjXcGjo8vc/pFhXVyUuRTvPgPfV" ..
	"P/OY6B3asing4OkwTPiDQVIC4SSUlE0B3ysf/T4oLNkGbr2xi03NpUq3RXlGFvVHJv+MPVHr6EpGhslXxHMn8WeJv94148z7ydsf" ..
	"i31e4zMNmdpJSuxTM0xRmUDinSRmTdxeXAwjtzJmfN8Q6SdI004gB5DbpHRufUuapbyPFtT0Xp6fD8X+x65NqvNkOI5x2xfVhp7h" ..
	"2LIQ5H5TvcM+P54nhUawVJRirAohQHLElMP5nhL36CB5p2X4gJO7dnG8zkTdp4YU4SJxkArcOsID6C/aiQQrzoXtBLOQ3Coihw3Q" ..
	"fAbxtvDPWAmptAMYusd/KRHRRehdwiLKUTQpHEhtzVcNQVsomb/yAonbcnPSy5uy8vy03W1bLX3bVQSKCK+SFPIUK6i3BJQAyoVE" ..
	"S3yUC49ol7VAhZqYncxsMt6cUX2vA+BZh6Ix+jY5xmYljSNEMMgYhB5rE+J9ije8ZGKpXMS6PyoWA+Y8DazGMRNyloe2EWFEC/t5" ..
	"ndrzftkHK6JxasWkAOgSrIsvBG0/ZwB3zU9FCQWXZDgp7siHJG5/G/2fMBAK1mAINnHU6tytdbR9vizKPbjvkM7BAwArNMV++Uww" ..
	"MliiVvwdO/n7ddlczSMpMiN8V7CDdK5l+OlPRSw4UZowk5MeGft3EueMk7uW+R2PRdyYQZSkyVTmJiAj9tfp3yud6EIWmaHk7Z0a" ..
	"qThOpmwW7hlKvYQ8sPniu0A2e4o98Z/hBvseg29r9XpAVHAjKUkJdZ6mHJU4X6Wbwoc97Vr5uKh7A+D9u67hyA/FavMXCMp/xEWU" ..
	"vf2ovVx5aTsuf8kdJVlkojHodAUogJX8gc8/I5LEtrEi/zaul/4jJf5A38APvHylwdq+TdAK6DMq2lATId+woYzXiVEahLQZnbVi" ..
	"qrN8LhETBFE57+vJqYzXN9WFIOvvMXysqfrRFCtjMHsUvnxMYy1InP1Rp5Czogtu5fukuSbAXOP9wZ2J3q2sCU+mmC52DNmTAQTt" ..
	"1TWQmQ/X0BCJ4xt6yUPUfn0hJSVz6XaukaIafR1FqCuq5yhPdvxlg3ofstHz5lzROcitQnUxXW8AT5vYxFdzPs1IiRbi6cO+EAsp" ..
	"fh+nn3TxYcuyNga3Fmqs6OYsJ2OEHrlRHkqra3fiwmSmTOMvgH9RmhE4RJKNKB1RsMmDXnfB1Y/JB8CTWdAl0mKIL4JW5YwIAzrf" ..
	"gw5jnLZd8Py7vLbQZ+c+7MR3D0/qGz0JimsG4YLW5ouB1I/5CtyfpvkyPfopPod4uzUZSM06riKsvyPO8GKexgd5dFxJQIKgIubH" ..
	"Frtx1DjeP20IG1kufaRAwUdyIUq30OHvywCtdxcz+xzXoCJ9lFJV79GmFDOo+g3GLjTnGPcV2qCZcagcRy9yz5YtAx2mUBLs1Ow+" ..
	"9gEf51lu6mao2qpBuoPGPFfL7Ap0Iq6vS25q3Yz9ODtO+k61hLsOZxAcL6f/yXNOo7wSQsfjpPhPpm57BD/ktrTssLEPDermM3tX" ..
	"hhLy+2RdtdXf09VQdmii9P/oGGmnCSIRzaR2eoIQJ/fS8cb9pyDK2ZA2ZA6Mmi+i9IayChmqgml4vAcNIfZeIi63Kw9yALF875Pw" ..
	"zInoRV0kBMs2acnIvulD+sW0wNvceMabxaHivpmB5sZlrTuuIyJavX/NEIdPYLkjgrMcr3STNLeXRcnL95wwg6rpDKX4z65w9aSJ" ..
	"UGfLHnhKyycHJGtXuyyb/opf+8AJwCBMguJtGQFrWP2xRUHf9nbazCpCw4pC3e4NtCMAmGyaxE8P1dlRwKPkcYe1Ctn6pr4PYAiq" ..
	"fyP1FB3QlagInbbVBZ92XXbwgrZcAMbDu2gpDxKus5ZouYprS8ILFrZYGVExhHoZP3u9bT1BHNcaW4SKju52Iw8nr4LviF0Mmj+o" ..
	"JyGm2PgJQ5bc9kKBwWKDaBHui/i30iYLtWuibn+Earq7n54ktXnBf820Sr4one+pMpEjF7vq+BArYi0BRDARHCbJ7NY9SnjZeUAm" ..
	"z2BlybQ17bHRCJ+al/A4cqjJYPtnJoGD5Rx91iUV2cBl5cAFxOfwLvBkjD3kNQLtDsFDxDYtSgkdlaNDwGl/lURpdHY7N/GIntq6" ..
	"wZX1VKMofgIZo+7QBqd60a/sQn5R70rWG6HAE1r+RW/E8Gt5TwPUo/TUBwW7hCuIpMgx+gaageF5gvwwBk/I8uG2q2pO54D6aZDA" ..
	"XbIn4QY7UuPKSSUDr8Sb8/liUKS/dKnLvkeizOae4a5R6ldh+bn5S2YFEFfPUfwu3QYMZ8ISoYSX9OhyCatb7shyca3oE93QamW+" ..
	"cLSfuLJR2GJ4XoK1DDCVrkXt9nQQQc2ulmVAcYqlBzn9ndcfYsBW8nQgZfx/sNxCG/sI+G7RpsnHZbNuJSZJvtaAPQrHattrmoex" ..
	"nU8oE6OdQOALU1OU74uM+a+aDPxgvv7UptCzSQjtQOBwt5GOShVr4fTMhj6boYow1eFKSZZEdxpYPELIQoEkJp1o+6ZCN7BfanXp" ..
	"5I5iEdEToRKPlCGsC0QLuR2IijDiYlSm4Gv29XPOEEccPYIs6Np3PUCrMauk7yZ9VWy6dTsrxFXSUBXUc6J+Dw2iAyWdns/Qxp5S" ..
	"kYY1TL7tbNKv33W30l3+JP5lqp8fM06TSz7/j/MFi3WZn/VLW2JeqA+Mq46J6nlMSUS0hly2yXAQURV697wGvOrG/f9Iyn+CgVWE" ..
	"+Y9IpksjgHO8PcsD5ZFWM2GNamRcucT6IKp+cy2HyloASZ8IMP6zNkGIAWpsMKMOy7QtSLw9reigggapmNC1k7aIWnRtuhVUQeNi" ..
	"AG6SQOndhbVLXqzo8qTVPw8PqXcbQlaq8TQ1fC5nw8kHh4m4Ck6HeETbZC+1iTGOMqshf6UBZAb2VNHPplGo3z0Dv3Q7tFe7+kil" ..
	"z/mZsyjg5/OJtEJ/v3Xe+X10F6fbQzbx7DDQZsdzBXqZ5RU8b/u5fnKB7MUTGnfCkZIeS4PZxe3j2Pjzt+zwVqSl7Grwyuo1DKky" ..
	"8/GzM9GX5l/5i7O4NR/LdOPREKKf2MPJIikDJrbE9l37vpjwEx7fJ95rcFJsFD7t9l0873Y19gx6vznhiJptlqJyepckg8ntqcNR" ..
	"ywzKudnol65m/x3Z6m/SN/iUgyP6kwM+U1p2rBTWCnBZN7AjdS0Fo6OvV51RXRYQacCl9YBAhzHFJ9lG3+zORJxjHbmOWIvi/+Zh" ..
	"PG1So7HBsLSsI0YyUrTBNTU1rRofiT+tinChckdqYYxWgixLZxH9D5uABHf1wgZgKtjGyDwJINWHZvW9mBlcdOXTeGSa8nlYuCt5" ..
	"Gbn9tKC2uofhDm8E28qVh/HjKTiwfbqrK7LHgQTGuPvmd4k4yMd/7aFmCH+N1bMDXX+Cde+2YyMxICDUKzMBSSe1Bu3Jc/nAsEcr" ..
	"wN61hmdb/eGoaZxMDx0lo4bsUXxP2xa1O46t/oFc+CkvzYouSk8drh5msXMTyaqv7An+ZjMBP2NeGgY8pJ6NBCVqZt/MOBKj04Ak" ..
	""
local PAYLOAD_P4 =
	"9S01oV9Aicdv0hwRLiBhCVBbb+bnpaUGwmefii4eq14m8nsreph4szxv0LU2FCzKEhGEL4FohZISkdJo9IsVTWVTm/FZ0roL5PfQ" ..
	"J+X9rgoXKwWfrRkmI4lU8Fu5JL1conBwjr2pK6HkZDBiObSDjHEkM8FcmUP6cH0wcMfOcamdvt03WJA477sy0kTJaX0oZBxPjnKf" ..
	"0GXNuTscmgqSLyebjCr+VpnZFFs6mvVrObTJhSYqRem8DRLTRqb69LIL3zhQZ1x4X6bghNbwvYZLUOLJSmF2+C+CptSl8TDWRyNq" ..
	"YBRRV/bke5AGY57xdD3FiK8lqD6g7q2BgP90mbiSFGUBheoaAi3/LwO2mCA6W9dOfaeWxGr/QQjGHJT6bJ+hLtEgNfxP0p4lfM4R" ..
	"Mjd/b2RKD5ilgOmQt/v641mkObgE1C51eda6aKP4pgil4Yei/sHnEJ2xbGCbnluBOH9GG+8Vy+vUsWLBe/srHZ2ooZRiwx2oXaO5" ..
	"J+x1fxT3ldXkehZcr1PZSUmIWUZQOUXWt+1w9zWFBKedtPt9nRASPJZLbxeAOEmqVuZeB74tWymX2y2Ig2mkx1SJpiV4XQovNGJI" ..
	"15zWaRdcBgS/t12wqng/wekfUgXR/ZV2GMUibRukecdVI/E/WQmyQxR9c2z450mM0u/wNd+bDdrh6/MAh6RUS1roap5FwPG4QvCB" ..
	"ZCq/dhbFFZQmDUv0RIFPB8bm5gdwrVk5oJi78Oo7Bx7PNblvvJfU/ZiAy3KTv/+v44NrN9c6tbeBHmfOgEiB7oo9qtMiYcjQj+e9" ..
	"Jf0rXWc30BKkm0y8j+1rvShIPs3Ge9LSVLADCFj3ronCjxTE0wsCgc/X6fYG+OqCoqreZRK8E7++USNU5gcP1o34AYOmSAo2tWC/" ..
	"gs/Zn4u1KzdacYs1cSSAUzjKeLaEaboXqLXKBqISsim927SaYh9doxJWXIg8haxfPISVOcqdQnMEWVvmfNfa/HD4g4Hx9eBaeRp9" ..
	"bpdbqZms05ijNBjLcVUfLYsJ7CbobmyJ8nINGIvfafXi2+rhFt5dAjX9/D2Qn6pEO2R5aFm8sM5AOQksQAY5U3kYY2Hyeqbrzhf+" ..
	"bDsEWF1t2qQW9w6YQNbb/E5NoWxKd/90lU3wsbw7YSXpGyduVsaXnoXIsiMQhJOudz/vj2AEmyVHi/FcGXX+Nbkbm54DAFyY4qsv" ..
	"AzEMTaXaYWfuWu5TrMMrf8aM85zx2up3iyH2zjyYNiPkvd/bIXUW31+HCPYVyU3f39+WTajCVRkWDaUWPNFHnojLMxCL4Cf79qLz" ..
	"lIMetRPRVFKHi0lMO2apubGFlf22vzCg1Abfh1zwLYL6xtEH8qjQhJZiIVFZZW09VYKqQi924VUDQvnc3BNE4UN1P/nb2cKuTGGn" ..
	"XRhhzi/IvvPB6XiV48gJ+ppMdVdNLdMp15RhMlBI+ZasXgzvNb+cNKMWzYwMqO+qzdT/CFnTbg000NmFbWd8acf49EbAkExfRScL" ..
	"jECcTAMnADzumYWZ/P46aQ16x7F8WMzUuuC+bhjdWmcZCB1nSoKs2Dl45Gsh1HkviTPc4bKpC7z0cgmLeHCMOYj0p5uw0E0ZPuwi" ..
	"lGfjDFSzSB+4yXVI6BTV22PRjpDDSAZAD9vTUMWVKtNXO5GVsG3inP0eq9+nIrPHzre6f2AAqjrKx9IaK37HDq1RJhUkSgTW2yZ+" ..
	"E930CmXMC6PhI6K6nuOscazClFQvKKA1dHuSyGUYuBxHjXcos+q3HszYnjPSxn1mQ2oZbxYBKxt1AGNjzqM7bw0I+QCGzbeKD/zE" ..
	"8MoqTgvkRh0reoBhLs0GL+9ZZocciN9hYd2fgtimLZDeJiod4XlL5woypmVBEJcpzT+pgzVSeHXPiRJOCM4KjTtsaqW+PQR2P7Pu" ..
	"boPBIfY8JXdLgpUZLR9B9XmDyYlgrY7mohVAO94ZOhMns1flEzRAKmYFIgvqYCjfwLsPnMgjWgSqhdgWSKOfUQ74eO6mhggtaMgG" ..
	"Kf3sNuLOhIDUdk6+NjTRNYbB8vcF83Q+QBMzHDE3kogQT56UIQlE88w6eHNoeXZUrVjYLT6T/poGAAi3fvRBcVLsDMFgY8+DkU6u" ..
	"4NeiKh1cjQp13+XXhJdAk/FnQwpsYQ7zNH9pC8hvTJVwWDWzyTg5cpvuH36RHf2THPATP1qt2eMisEvIX4aPS2RbPYrfWS4TLk/Q" ..
	"wslo8dLivCKztrsGbrA63puOtNda0nq4AZm4mm/Xjy+XUVwAY+v+MOEFL9R5X3vkGNKquCV5kQyRIqnklaFFxq0+Yu1sc2PnTRHn" ..
	"BIaEYA/k/oCTF6VHAxsnbCo0kmhAThlhC7XecPEtNoTq6oQCbNuXUuQn2KaUkLj1jBHm27XHVtoZyVKQze5KO6KqC7X015r7XCEc" ..
	"BAhMY1x11vMMFXkhAo+Z75w9tFt2Tq2E2frC67z+agq6JgD4fHCvnS9/WC4bQBTpFpIT85Mvvw/ETk4I4ZRq9DaKCsjTXWJVDxbN" ..
	"oLWQVkuTaRouleUzfGqHIgOIsQASPeZ/I5j+W4DxXseGQOthTe0bK9XREiso71a1r3Xd3QfTF26JWhFwLlBY+S47AN4cTQ04jjKg" ..
	"OmK+bjHZGekJMHyPYIFjp+zVg8CVthz+ILPfh7M8ohhMm12kS8qpIlyfLIdxdJznN1xwfSA1UdmOlyCA4a4jTyZtYVXXVCQTArim" ..
	"Ylw4KDImObSrCW0mUJUPwh0nD9di7YvUkM/UaUzI8ErRpLA2yn9Yg0AihLQ32YTzBKbkGjXZ1vfni1NGtCaJY33NUCqJA/L1WE64" ..
	"v0yKDiaUaSUFEABub3jOIoPagY8J4zMuEgMruXp1Z6lDTNT9tZ0V5OV2CDA8JRQwDiN+I/IdpwHcFQ57LrAoTZuTHFnoPB6ekDwH" ..
	"k8fTGPJ99MBtDQhqIz+qStCE+9gSdWnBuMwVySNlOKao1l2dz0zyzAABIFzmfO8TPe8NgvFMwEO9c3wdYR08fxcWY12DcoLJt3V6" ..
	"PQNTpGt5jpr2bozJeXJbFSP1E6goNYRhQxpuz73cd2WEMo+v9/cy/5jOw7k+l7DRW+aIoOU/RqWfvzcU52+ZKO0gdKfWfGwKrysY" ..
	"2l7f6KjLhHQmYXNoNeHJsMRd87PdWRQwiD3LrnS1Xb+C4BgVk18x8lVud6mnBD1QQUbmJE7XDhDREXgw1XFMDIJHSFAVMrwrk6E6" ..
	"7AsoSb4Jci7j8TxJpnMXvnPPmAmYQvnflTyLrE7OB3N2A48/rrnzHOsC4j25ymC6E5VNjJqYjeS8vZRdIe5tEEocApOZdtJEub2n" ..
	"ukC4QUs1Oirip5E/nhihAGn9atdM8CEY2NbRk0VzBMxCz76AhbJV4j5qBwkG864Xr+2l8vWQPIdzBxoRPNjngQz/4EB6ubw9WXO1" ..
	"vwkHut1Paw7jgCE7OYK8sisk7vm927JMOi86JJl4su82W+NuSCXNMgvccXh0oOkvC9keH18tJXAPZ9OqyO/yKUVJKSbgXNFRM0h9" ..
	"ojMs5uUYUZio7h3i0qYcfl9CddgaKLyeykeHzRPHxaTu4v1IAybmRn2FZyssimsdlGSiSM5tzfse5A/TvCwV/viBw/+QX/A/u6CJ" ..
	"1OwMb4I1geCSPo1zEkHArNgUwj6kNmsyDAhml20bC2g2uawi8k0NyuLr/cv9jhVQXjq9w8RfJamA/Lz4EsJhuRxKXFsB+adoHdbk" ..
	"Rns/ChKpl457ZkFtR2CPPhUg4LLOE+xSloE+MTOyaT+dutRSpqcTQGf3TjsFoVUVfhlzD8lCajNTy8YGmu8zwd1DJkunGPR+JX8o" ..
	"2w5imuSp3L0BGSQbE0I+9S1aTMHoHMDJWzfZ2yOtO6j8syEKOFo5J6y1UIBsYw1H3DLw+MjbjSOPsfYuM2XyAXSCtB0VsdYoH6iX" ..
	"0tm496mKGpLp/hD3VdGH4a2cHlSF6hBVBZPfnNaPcEjtktHw4WSDX+rH+sMPTCd0a1wQ49MqpwRWyzhEv3Ij8gaWtwvyFQSXMqE3" ..
	"LVchyWmkUCBPK8XHJwsaRVDClqOxYg6OlvMjylV9PRBjGTS02/2CvYOsjNbSG7iL4smsbVpVU5cjQxZS8KG7Vo/ihSkWrkYfWCPd" ..
	"kZbO/x5JV8cK11uktqnfd3ZmQb0bk82z6QKjcdU2kM7lgTALv79Gh6kbQuJWSKGVSJu5PdraQccPq2mNdsC6A0dv9RX0O0OHV4sc" ..
	"rIljfV3TebLC+3CjZ2TT6fBAImKFAtz/pMx5J1PUordLkaxut7GKj44okfL3jKfbHe4lSMqvjQQ8nFPWkcyT9BkXrag/dQg7GbaR" ..
	"Ltc1ABLT5Y+wXDW04SNC8n8BCMG+MmTXoxE9VOZIFYriWHKNceR2xEC3MwOb7PtwO/pqjSdLxLuZjjZMSMQtWf3CbqtelwmSfSdY" ..
	"RJo7tYuDmbgF03HBN1bkGTSZJqvDJkIP9SkjGzXL0Ev+TqMO0MaH6xc2vjxx77lnAlnilTL9VPFsrYok7AkplEaSZ50JAcRx3waH" ..
	"EFhn2oh/5Upnf+toKgnTX6iayBwYZF4/WtRMlJNZVoukWN6ttv5Uq1kuyES0adAClqCSG67yf2LKuyN75rE92uYGD6M1iqkTiM2K" ..
	"MkU2Tu+1z56F0WeYJsslLU4gHjFZI0vtqdGzLqQcxnWgvlKdWnlve3r16x1xkWGSt5T11M1zawSZ7Qkkq4+111eSeOVfrrDYQ2ZI" ..
	"7+jJmcSNrqC8CFacPtbtQgl0cPcPDpOLWRm59ytBM6IgbWbq15Aquln73PHygRAEmWWDFrRYTgUCQyiwr4ETALi+0tM3ofun1IyE" ..
	"/FQUuaCUy0bQ+8CRDCIgn7DuU8DKyJv/b3CjEbbCW6IV2tuKToRL1s4oMPf9SENTmMpg3ygo1Q99Z5nkGEnucWPi3AIhhO6Lv+1z" ..
	"EbxydYoC7MGTkST38TMXhvchvrg6/ZeVzFUL502mG0Z4bbfYhvnESKapxSutTS+sbHSRSvl0cEH2VPorfQdzatNOtz1sIGFHRIhW" ..
	"j0x8tjqA1veOLJEgsuG5oonM70DnnkWoJFy9HcUpRkck5CWMm4uibA3hjzPa3w/6+M459WNC3DZnnBYxlSOV/9xpB/AuEFujYiWm" ..
	"AwyvTS5lCvI5bBCWFHKBljvPLF7pKnygjcTsJgk6zHJpvcBctewUXq6CoC/N3N5APFVScjb5pTfMzgLwgQpMW+FmNru70ZKNQ1Ol" ..
	"kniNJtOMtR4xTaGE5Guo0E5HNBw4zR979t50B+arsbHs5aOflMhSBRXz8vvyMGVBXh5BKpIJooe9ZIOIjS6CuZkTjN6ij3XPlKwC" ..
	"rEnvk1adPNIYCrPkJ1qub3HG206E8o4BvBT7tU7LMvPzrhDos9jRiOBmeyC1NppmwY0azb+MhM/v3MdUvSKCwj+f8esz4s5hdJNr" ..
	"a0+2l+Sj8Ms+2UxQI+qS/qfuOURtSqdER4BD3fG34t7PoOo8siHo2/u9nR4N+tmGqi14LKOr+WB9lJmLxAhFiVt5Mo/2pPH3tf1p" ..
	"H0eTxOQP91FeknAB0UL1Dau+iOfV2pPd11opxISavT9ZRVr2TJBi3SikWItN2mFFRFxPqOMuFwwqwnF1FbJKHMK0GZcds+WSbn9W" ..
	"ki9MXMC/Q1yVg2LPeATwgUArAtbOh4dlGVGvwYTNurLLSaAgxv40K40dZpFKPV5F6t2JtRA/tuiISQ9MVFtoIWAdcWGMYU3OCpv3" ..
	"ZNUMnkH/1h+ARFbyXLwQ7QN0AgEKSI8E2ra6h/BK4QUgtcz4UzYO2QMGtoRgxwcXEoL2rxmNuTe+O1QpPmAPInr+cxCkKlu2ZUab" ..
	"e7lo7gGMarELtSs2IclTY36DfshRoRwsRkvxxzBlZ/cYPet4x6HHid3DyN0r1F+BELu+zeFiKmc/yl9L97rIeq0DEj9JlDxTuERw" ..
	"KB2qFX6zz9HlLX/AVib6iyGCOFnWUzu+59WQc30Vur7HlWFVtWOPXzGFTU/lbHUOrcnoT00e/o9Q2S/wX8gvB95vSRfx5LdcFcFr" ..
	""
local PAYLOAD_P5 =
	"C6TsiPBKrY9WLggFdMLtAluQul3P3n4577GAHKX8Qx1+XI6AvPak6/SLg2BcBlW5ecIJqUWNtxXNjvTCR+pKHMJtvGp3N8HX/xoV" ..
	"rwZbwUpe6MSsFgrOmpacwb3T4bMVT2mOp/g75XDMlFY0mCcYs7wvRKXatOEw3m8uSzlrD0xJG+iQnGovWheMueIcoKpZ2r3++Tip" ..
	"u9KPotk28A9sEmMaPwgjUMVqixYHyIZZ8xKmQKSzhtdg/WSRsbUtJksAVtrxg4asKKlZfnpwUhcYoLB7zKMY8e0gTcf9nm8gMBdq" ..
	"W8AmT+fb0DV1IQZjZeat6yK2KaIJ121UBetbwKoHko9IB5lHvTK97tk5MNAiskqY8r0qKiHxA5303AnGs7zlwytr/x5bMLcgmt9U" ..
	"gZQF3znJvJOq5wa0mivXroQMNSB0p42Rxv0Q4NVBlGRMEn+4guVBdpnedwFMLmRe3yGciDDOcA7oTdVzqpPIi09cMY71Hv31W/XY" ..
	"shEbdA2VoHnpaAPsncsrQlqHPF8MNP4vaHyL6IJ1bYL0qySIOk1kxEfh5lcomdzLH/XIqxSnRfqU4pq9Tv4KG32qe9VkdpvXm28d" ..
	"WDFlyGbix+0lbhgwPhtKaD2pyAafJ23w+o3KlIW/uH5/s5NhYxH0Me0CDucVnSGkEryfYBpizpsE3d5qGF6kMid0BD3qzMl+Kq0Y" ..
	"uaeMhMvIFVZbczvFW0Pxse91AyhJMenP+hkFYivGGsHiWpgCehzF9QU7FmLIHhnxIO5qizoy851sQ/wP/enKqIYe5SK+WPF7TGaY" ..
	"ziP6WVuLa7TfTwsLb4LTeE5h2COIPEQjR6pS/gIvybJ//OcTgErIIno4lszSaeD/lvPy03PKaUNHptsRyIoZGm2lnug93LSp4VAn" ..
	"6W+TkzjvcNYSvxLLm/26bxVAO+OvPWHVBWov6jKwYdbhoP6gyVc4tjUhGIkj3M0Ji0gF67A+fyBTHb4sqaagEU/PiH7BqEO3J1Go" ..
	"bFY5crtiZSisHByMrD/aa0+McoQLATBDVlig1E5aevbukQ1XFiHmPdh6+up1uS1YS8sYZvcDD4nl/YF9Fu5mgwefswWqSCwUZFCo" ..
	"nGmosiOiHfqbticlXXYTD2KjqdBuf/falqwY45OoNeCXwrsYtPDhaeHTiyin8MGuvelK9P7HDKlKUUoIBuLzmdqFVQ1cvbUb9wgj" ..
	"3c6PWkpRxEMM479M2YErs/ZL+U8MAVw6BWVKJqwa262vo0S/xlXxrvzDqh1mLt5FF8yicq0Q37QC4Mu+HKL3etVLrdJhA3C7vdzm" ..
	"r0bm/eDqI5ACZ+BEhxge6f/vjjOQNGJa041e+qr2TCfmPyNMmWd/Tfo4iiH0hWWXr5HfIadPetAT1JPnAEC9IdLunOtPDNSlSTvv" ..
	"RtB3NH4Y/73GR0wh+i+HKiWl11r/l5U59dSfCb3KNm54fMCalkjy12LNTXDZ2WUUwRglPmAPz3Vy3cziR/T+dV6a/zAYveOh7Pbt" ..
	"WBlB6EC+GcutdM5YbS1VcivIpbxSCur2iSbeTVQisifDvssvazCQTtqrYgb7HQTyRX+K5vd27Gw+hl10SU7mapFEt9Bra9AMywKo" ..
	"aFP0WayWY2HKpImsND3o4F+AWr+HIYeldT2TRM30aMk3vVawwhM/1yBusbV/siO0w0N6+6Ep3myPztpCbpwj/Yg66gz4nPXNZXPs" ..
	"62R3/QmymgeV8zD8LrvKZCvOb8CVSCa0OgFwDSLe+HGcLwTzrA6+8PBm2y6cc138sR+TjRueFvTVD/nYr9B9BTHcsQP0a0juB1Lu" ..
	"o6q0iNItDn4baLyBx/j3KyCttM81qCHs0xNhB9UsRmRAoQ2vEJVSCRUdXPwSBpVEwg3UW0V1+8eGbpKA145Hdx1gMtQF8hBK//fh" ..
	"SSeQ0pdqdM+6Wq8Yaw5NrAVo/VZxfuesDdcGuIxApoJh3z4/Z+4TlQtuVx6LRQ3MLbbflQu+8bRpTk0bQ3DlzfztuVP0LzPrtiW2" ..
	"Lt2r15FpYqho7GNVj1ZRfcmbDaAl9jkALaGislfYfHFVk+X7DuqCaOxczw93bl6DdTKmlKlGorj6VwcLa6+SutHsAmd8TIJpahh3" ..
	"qAIxeytDALiRoijmybAUC+KfTJ9ylbS7yc0cly9zJezf+wXunHN5dGMcRPMUqMpX1h0SUJtxK9lH7dotDjuCgIzDL7dnJStnfMhB" ..
	"p4z6lFEV3fhGLfHHx3MXI7gkPtfAQS/yX7YSHACxrPdHWVMySoTfl//00HVPkiQRrnXaZoxLMdNladkABQ7CzFHmV1tjSCEzkPhJ" ..
	"cbwmChsG/HZ5F4W1M2KdWL3LIeC7w9MpjO4hNYAEH9YNkfCfVp2wMdR+iQ/wZqjXACjKYCO4Vc3ZkZLnDh7xkOj1VSZNMLe8adpA" ..
	"55Dw72cV1/hNJyNzP8agj1sVawH1dNwFoRipsfUSQrT73Pov3pQcy43FMfWecu0hEEXU2MKxgXZetakB/F70kfnrgiMiOpVxM7qd" ..
	"FGURvL0VyiVVxIvbaJmf/KtYQrwrDDuDErdtIkcDS/TGNkP8HfY40IOC8UtDD66spbNo9MXLGDKCcRTyQOPmDw/ZA0BZp4/l4HfW" ..
	"OMtvTWpG2UsCfdgNKZNrdyvTO0vG4AOSD9Y8YUrVM1lwfxQZooKG+FxmjCkd3f6R4ZBorOqeecsFhKZslymlsqq/YheC9b9D5DS8" ..
	"J1W0fdU8QSeJh5nUOz6u7nu5GBdZpmE/kmqX3CbHbJuDhTQGGgNMK/bq2O2ZXEWx/HdqeUA2WpSnf8+qWExvxWxf9eeA+7cg9LoC" ..
	"GJBPCPcsD06wtAa5eQcXe8y0H3CRtEaVqJUz8tJ2RCgQU/AYlcYKNxm6jdISeILR7s1LiXKaV8SbnM5aIqXyzAcqrLMtguNnqx1S" ..
	"9NXG9TWsXD9U06hBnzJdxkBx9iizWPrfouZeI1GtvrSJJil/ZTkljTPNPiclcqD+M6wrB2vyIkRWGROf+g8Exh+8PNCF9P1oEBq9" ..
	"0VJetqyceR/R1WM+d3YvC+bJKFlS1yZTTbSDCIuw1qgbcWBA9eyq30unBsiW49YARGA0ZGxUr2DwoymigufRPOFGWXCcdLi1JCFw" ..
	"LfAWQNI0ulLnz/ZYW6KRinCNj5/JzcxJ24i8CmbMVNrcDQmD8vXKJ74iFopY/kDGMlj7Ns2Cejlt6L3EQXhaLHkGHmTek9DAXngJ" ..
	"WAFlnsSKMlaXnJLUe1XB6a1DUt3ZN8qK5ajp29DLeGqPObMg2Sexl51rLdUrD9gto3cKDJW1e35+fLov7M7cLtlTXXVwK2K3o1Ac" ..
	"yvitvH8LJkWB/FhF59IDs6BNFYbQH76/fEHfP+iAyaq2EPBpQsva2zWmdv4uDcHOUcIJVl5/wcWLsGDFvCwkNFvRt6Zu3wouimwc" ..
	"SASbc8B88uNfKY873M5ADwwRg7cvbmfNF+uLHJebUQRc/Merl1UaoNsWIfkGMvuNtpQCv7Ego2T+BWfmzehlfITkLZ5MbnIwj58k" ..
	"Kxl8iWxRoal8nCoyGMFkqUeJ5hWZC936EWlM6rFKTGYAyRPzXKjf4q0yCOCQjPurf8uEA12wfStNCcpSr2gqa2XKDLDDX9Xm5wCI" ..
	"IIeDAp6303MTktLDTmeza/Q8PIuFkI+avTaYje7TxDtEdnS4AwSqna5M2TCQEbM055dd07tmS7+nkM3O2INXDt/+Pn21rTLQxl90" ..
	"tGa65a3Ia5Y7FgoeNOU2lOn3OhYfCbjHXy+MRauwL3XuZqU+VSmYOSOV7djHqvJPozkt5L3XshsOK8wQvnYU88Qn98nsNOohF5Xq" ..
	"Yt+/8t08pGPrWkxelKU1I66sDQDmnuISCSQHayWqPFZWo/90NWEqVXLUENFKKlYSDXLiTXJliYTYQVIQDJ6owgPLUqkcNBxJ1zsq" ..
	"N/RFr8XOq0UwpcfAbD5uwoxmkZMHNKwCYkPhyjf54z+mXWJvyoWr+y8lHROAB7xTh4hF4jOgIzGMmAOo0DiP06jbBk3v9huNsVcf" ..
	"KcXbnmOsn5t8rHluYxPo868n8jOMjeF6ZxOtkkO6U5jFCuIqvss+X6IGb9nSl3AeUw/IeD5wJmifclx2cEJpvx+9zKJIqWFx8WZv" ..
	"BXcCLS2ffJ0lWhyhCG/eDgXY8jyglgh2u7qomyKVo+rRa1yxG6Jed31bPuRTMVVTnkB1WtUyhW3Y2zNjlEdYB0aHESGmQO2WrzJ4" ..
	"WIzKhq/DHe+oGWPBtUcz4Lv/Tm9dgOutXQfYOLrPMCGbO3QkGo21FLr/plqvmiJohyiRRCPvDa29BxqKnNkN4MwzaVBbmEULy43U" ..
	"IZ/vpWL7V93zUoxAb95OVucfxow9XsVI0WpLVIAOA8wHja8tcWzeMuzNZQzXh3WD0aJtLEvrixY7taIxBqD8wfeuIPchl2wnQai4" ..
	"xw4k4NEAVUir6fhVXrWhy+y4i5OU5jdVlLtdplhTfZyBlHeDNPgNG/SGhsAlJnpzLpfwiJBjOk+bpfVaH1WHvW6FmAGB43TMCsha" ..
	"95HRGqy4ATO7DTs2el2WNIhbBw2H66BLEzgwd5k9keEU7zaiyWIFXVdwMikRjkW2tYbKrS1PM0HIYIvPhM5+VH7NoiP3gGJU3ZwD" ..
	"OvpOGivtsTTlDEDlzFzzHSmxHKjRsRG/mKShwx4YBVAMWJ8xqovFh7QkDMUirgg5OexoBo9D1riOfkKW/6sonNDto4bxTo8Wk7T1" ..
	"sYspxOpje7wEpbQSioStFAhSBxDBdDE6avdeIN9tuUIMGIJhG/X1eaiqUmxuNgMHZJkWQ04vZjzuyjH4CUg22+UvpM9wljHDWItx" ..
	"Zvh6TS33AXZ/3mE+RQq3HV/dp+kP276Jdd+soXvoQZRAho4vHcy55VIw/qv0HmhPP5clmiXyL6Qj+YVFvtYPSkmbKC2pSnXbTyHK" ..
	"ZI/rJxy9PtBZ0z1sPfLptX1Gaw01f0cATn59iUkAp1W+woKttANd6B1ZRBhQf5LQ7ARvcp7UHbLLvUN+Tmmf2IJqhuqZZo9E+DWs" ..
	"Jco/lWG8Dx5XMY34U4VikZJwEiLVNRtSZkn0FTkg/HMUe4ShehOQC52nrQCpm7Pc0Jv1TgxY6q6Bp4z0nGLkeiOLDxf/SQRDnM6S" ..
	"8QQHUqplT+KK9DK961Ye1QVM9/9ksqVmoyZ2XEvC7RVPObI7OD5YZu9VWPWSaBIUrK0IkOiTmRs9QPlqHLre8lCqyLaUo3pnn8uu" ..
	"mfoKEKaanGk/caollXVgndjFr2/SB+jHBxMXZ7zg7Cdn4ZZk0Hj477wX9aSu3EkJeIPbumFa6/oxjDnPBC9V9A48yYMHmfPVe9Cp" ..
	"P3ExaVFiyB8QDhsE0mvBQ6USq1bl4wuCJ4+QK8rMIo+YBAXkavjpnXm1mujyqzg8y94MhHEU0buXgJGdqvNLQfi1ao++a4ycCcRv" ..
	"8174fjZv2gOmXjlxB6RABY9/2o+rwJ7kdw28tATwligjOA6xZ5IBKVF9rgI6vwBCx2ofNYv6uhmECL8rEKemQFaBUaruqXFZuX3v" ..
	"C+ptBszBT+UULQzeqKuF7GwUYnt0GxJGLupPJPHJ8wB/s62VvFG/KHVAbvdY40+DbkI6PTMds9ubBykYmvBPpm2ZQjqVNmwuV7BY" ..
	"RszDsq4xqKr+CVnzXqZ/ltHNbpw8N+jIX3fc1CltStoPTQ9usJe7MR5FahDt41Ye3cMWN+urDUr4hLrrDhbyCHeaMuffzFn9WCCR" ..
	"pWtB5WuxnrChvOaWkTLEShVnLPSiP5w54xw1GZ30uDMI1eg9de9QG7uODNdbFSOD6w6HMXO+W+3ZnmtMR5UwFUSBTZ798olxfxs9" ..
	"vEKuRpxK77PCBg3xg7WmMxzKo1OqhZPbZwDXyd9dUUXTrBHKUQbxrQPORTC3bvh50y/pbTUJPbmToDFf6SAcmIVZGV95Qvb4b+mM" ..
	"Kivp83iZYfN97h2GwTpTTqzwKnVZf10IpaQ2FCCl6DMRYy7uIzbdHtZ3jKa49ixlOprC+GvN0maPI+z7D+4ElaHoEK+6QZ6TZ+Bt" ..
	""
local PAYLOAD_P6 =
	"WIqbpMcRmgAMlKW62ak7ekDzUs1Ll7/Z2BNUdKjxf6jXjLZDCszi5e2YSRZwbb5Gy8sKPOmimqSMv0kEDoTJn8EPaaWpqk8/o9Er" ..
	"5Yp8vN0rg8Q8Li/kKNFMb9zkMyIOb9lvtxCxFyMSEL7pFE0eahHmVLgztojQBV4IvvrfcMeb3i/s0dfJEyp5DxQ0xaYbBTj6NzCe" ..
	"r7GHu3Dad8eN/r5oqVwyXV5efWQkj8aHUBXYJAFwQJDUyvwaFxhmCAnYYYg26YFtSs06XLNdFwo+wnJgzJ4+uIhzL6VDUH7wnr9y" ..
	"G59k/t+4d4McbWajqbJ8qpoejKHM745KggCSCAnxrRmRgkiGqY05+/dF7lIWWdqM5s1OZOemfuDdaGchWTAcenGEEVTe2vdROZXq" ..
	"Bg/Xa5wglMRPeOZmvyJk3xmONZEiQ9XU7DS+2ygk4oAgk7ebXMv4qK8cAkZHzNEEzDWn19BYsTJ9cY7FreA9jfGVVgkYd2uGkuYA" ..
	"fept5fI0pPn1IghZGLRiTCpIDTopx+2QY8no5YQBllV9lfu9I7FSbC9hOh+im63EuWV5hYNzfMSrAMzKKzqEfbRIhuUUhqcaLeZz" ..
	"13W5feTYVadtFfoHhJ+cJ+RcddAIoTgS26i22VVmOZNGBE9LlYWeqDh/vpSWWBlC9TyP+14zKkPU4STKLHC8vDwHwiIiIACx3/LV" ..
	"7gXwV2IDQxuQKuSZRpu4FcAw1yPUHmE4QhAisOvUg1SdJ9F7W0Wp6GGzsGd0IKPR6qPkA1N0VzBMxRex0XeRPw46RIGQTBeTHXno" ..
	"TcMwKn3gFPjGBc5/pZg1tRxKn16BvtjR1OsCq+7rjYKdgokm6gwHMLxMMfCFuR92uNk1VE88r3J0IzuLW3TAV+rCsRZznOyijudV" ..
	"thIWlCoR2zkvVARTOCyQN9E7FjoxXYyICurH67wnjMNgkU62CdxVkpCjGj6YcQk8gkeOP3kJ6ZnSjpGQhAC2xDafeoqNEw4ij3e8" ..
	"veseyc4ozU/Fvyz6lhm3zr95Vh55pi7PPCMm2BhDbTF4Ff+Gyc0qrjIVHeHDVljPjrObIQ3jJl3MIwexSpifVCOqviA7oriwoTf5" ..
	"Sd1pn6LACsh8CMECddNPIKgzqSf47scMbBCEKdc3olqufW3kPQfYtP1mMuiu6R1MNRubIHpUr99y+s1d47v+2JbQbvHPttMsnlOM" ..
	"bVbh7yYLHdreUAuKgqtRXoW/6tDS+8JHi3ARTZSDl1iLsMM6aaRzhvviJvfPRFHdL3IGmub55PPa00M1hiO4aCfGN6pvD6kJ9nPi" ..
	"uUKl63XhkH14LV3wu+tW25TjIgfW2T9d3+Qwl9UsnW9qdQkHFcpl6hOVNnxiDykxWEwHIWqzRCpwY/B1RxEo/Swa5Bq9Q268uzDz" ..
	"Max9WIr2RjFcOfO/r9wDefI75qCGLBVMyH3nOnrMNb/3V2VmJgRrESN9cDsqPgX8EJ/V+YcW1iqE/5fNUFsJySPjZoDuZy3NpMjF" ..
	"iJ3UT68pgOFzLbZDkj0KLkDQdtLRpTaWnV0zGSopNnIqbU1jL3I29UAM8gN54XMEfmBuc2S9WDFI7fBMQkUNroP/9cgoau+2aFgy" ..
	"I/7xy5Pfd+DUEGIYx8JGo7TPkJFWr4hifESTUJ7LoywpobyJcLjt8xuXtwMn7CQSSTgNrBBGUhB7lZ42Zzp8BdJ30QYRqAjs3wLF" ..
	"XJjoTTd2GMenyr3ikoEeBOxb+Xvt8gwLYql5iC0CcE4tu1tbcr4MnA1DW/3aaL/U4d68SWxTXus28yMZ+fJ3gt+yxDkb8N7NWRue" ..
	"4LVPpHmCbXUtnBpoz56+gKVLk+0GoNI8VjQX/jFP2vI7mk3ur0FIC5+xiVHp4/EziATjZ1td6pTxdMcyYN5134evE97030+LUOWL" ..
	"H3wTnVGMipKZa4KLnJ0aeOoCBGjEuBhdCFovJlrjtjy8icFV8dFDP0cvGdBd04zEYyISCDnctDMcRsW2L1Uo9xVsMWo9mD6QcqYW" ..
	"zUVBBmr414EBUT83vtLu/I1tY2rf8MsLwkpKky2na5hafAGXFqOh2XBVi8XMWs3+1Fg+2RNndHIPDrJQeW3f6VSSiBQBj37qcsjt" ..
	"M7CNdhYnItK1+HPKRatVKaZNb3NLCa9RRE2xM754bUmjMYJ2db32OnHPTWEQxasmSZSDBdVRQgWajr73RliwQNdV0rBMQV2HyzYu" ..
	"eIWjn7dIhTh3Z4JvqIy+PYfruQ5p9djqCdQe79EJfLCEIh39JyYu+fUQd8x3LS/O/d7tHJ/maE434fqw00qaVQJ8D+SZGGP4SHDq" ..
	"4buViqaVVbsITO3XuBWy3SuRw3hLVbz+IEsuewejcNPyJs190NXzFaoMo+PyIxSi9GLqk9Mfrbo4Gc+Cb8IYpiqWG4NJ+MlbOCI/" ..
	"74W+GUkzLRBgRNMLV65Ajmy8mQ6VeWoMYuAWuvruF1rh5K7EYEhbIf73/GbxCOwlTVnMo0aXGTI4alArMqnfIRqbGZk8MUZxES5Z" ..
	"Ub82wNtYQwSijDIsG3fPn6+B0jlmGAgkyXdGjaZFT8wHCIjQJJAhryiosO/W3xVTqedWfkT7bEuhXnK9xB/nqG28UthdWg0haWy2" ..
	"JEuMRB6m1UXQSP+ABoUVQoAVhelenGO99aQ+3Y3U2TK7H9pcTGgtr3jT4SEQ7vIEFsT7kDBsQr5tBDbZcjhoi1lhTRakyTyJcAsg" ..
	"IP1Ozqfw9a8eAIcezhpK7B7+J+s1julet10rsOP/R/fUgxMkYGc/feKDoqOUpp845OYjDenW4dfv0d01m0cx7mhaK2boY8QBOIRb" ..
	"iGxE2v7hCdVgIwdiHyRSl9rvSh4RwL1MUTLIRTJiTa4UpxE/j4vO6qEGGoAbxQgIRxKbF53m813T8wOsgeBHfyV1wuWXeVJYDdi1" ..
	"uTXf7R/88JoSmTtdIvFvnv5W+5ZwwSXQJfHSHvai9BTLZvrNcpgum/d8YgpdOgfRYxqp/oSiKNcFSJbrHUj513g0aLVO8wx9dmoq" ..
	"BFEKWkJA6ChuUnRgQfm6ReZhBDDwjTWgojmJ0LiRbkRulng2Jq3p6khUvHebZ1Fv+Q1jgmDdAy1U8E7nUU8c7vwnxDwC9d3WHbJ9" ..
	"38CPnuv0zbtO/ceec3Zthq4lUp894YWbqlxanPzFZKY3duhX6RB7uZ/FUhIACosjj1hxM6t62xT78tniEcidk+U0whNRRYTerjvp" ..
	"mEk8I5N3+/rHsSgCUHz4pOXnXlUbjSt2kCedWpQ7nOLiclIYiqPwF6EznRqcUH0Aldn+lVMgVQyHG1Jh29WEwKJWLXnWg7ioT8IY" ..
	"Q33TFt7fSuM53ecM1kmMUtrMqaRukR0wtXwi/p2mPjAeVbYjKkM9bsoqgbmjbD9UKXiPSZcIf44O7cW3KwI4h37u7ERLnXjxl0hB" ..
	"k3UzvFWu98FPVtORP8rxEkxYsD+rbX3DvNcIkUMz35ulXZ3MHeQRtRa+F0eUKdKqXA/SRUPOOoTXCUOJD9LwYmZcwZcaBDZbHjtJ" ..
	"fUTgleT2sD6OrhBlEKh3hwBMViNl6Q3qPD/uyvwQo68uWOsIEW/4WyggvAWSEvqKNcJqwNKS8Gwxl2GEY5Gn0YZae4Dxmdscfizz" ..
	"vaR1Hee/tQbyyKFZj/3hwxUbGuTSD4ChwI195aRnwHaohlb1Nx0EBjaE7FhN2hyQKZm/Yk4KlmMWso1yyBSCyN7NbIWHt9Dt316H" ..
	"njngxkEySS8cQpCOTOpv1IhhAB6LdKYZawJm+pfkyzTSqvb39rC02C+LQl/GOrIDQm0ks2arUF9XXIZXM9a24TNHhQLeJj630i8o" ..
	"bCREac54dCCi4aZJWQ92pmOmkWEyIcbySMXkT/hUrlzYBjGBTq0iQENbyvfYpH5m9JGnZ4vWgmKErjpK3FZBcb4YZCW8boaOWJOh" ..
	"Dxg7wAcBInnUMnZOapcO/SrPWqB659mNP2Iy70OejJYNBCTisP49LyyyRLN5dhfc0AkEllmCVF5+jJK6bZYIpozfEBXTS9d4UTY2" ..
	"82vhUp1sQgFNryrLKV8JlM84KzpL8Y97w4e5QfSbuXaZ9cACW2k//ReDhSAizRIv+eA5ic7LpTPcQUf7hDX7PihnzZL+5MXrhkX8" ..
	"DoM2iZOsYtR0Nu80jeTLvnDZ1/vmXj+zwrZG3ozlTzVM36Bu0zNdV2lXOZ8lCLpb4pLmSUogWwaZKBJ5A1F189uXQDSv5cfngSHI" ..
	"9rTwJwCVCBk7apII8Cyz/9tdDVfE9oQgXDIwJ9mHg33SO8oo7xFBTSN+CcZmAClXLCE6M/b/YGG0B0v+gcnPAsTkJc9FvbSneOcv" ..
	"7OE4+m0+oxucC5x6f/2X2dmNkrlujX5vdW2aaGQ8no/AOzVStN6/K8OIag5+XBrHyL0qQ8bRZboghorc7QYRVBvX18l0BCi88eWR" ..
	"Wdy/D8FynDkYjksR2AMjF0wZlROrjwA3/20pE+FuuK6WBApdYQGqcPgxl/cadxvfHKirWG8pKV3bDlnXdCZqSfCKobvHTywtozqf" ..
	"llA17Hzq99FrsItmYCsXUzdl/n1BFnIa6g/n1kYpbhx0yVxKfjWshsB0bWJRKNysJMxgdTFQcjNmt3kf8miAowv5Z+7mFsHmnZ1y" ..
	"77N8n8IioraqakFIoanQMpRUfFaCV4jFfiO14+5g+fZodr1ZMgjvfyQWRBWN0wdq1LIdLcS7ZoU7FTwAqZvRJVcglaZumiHayX+e" ..
	"dNjUb0hhjKJi85cmp5tvbMYU3x5R3AleIttBykEUahR/lVVdFflrTb/SRGN3NDd5oWMOvYw2YwS2dVwIjWfltnC69/g1Lk9nHVf+" ..
	"aGOWwgCd4e6d2eR7x22q79lC+me2dsKJOdUaoAv+D/QORQS3TPXRacOxgZTaDTE9cdmarzcLZ7cTRdqccizcPjtG/ctaz+1B/EOf" ..
	"uQMmNiGvkIgZl6l1k3xRgdLWNvgcNwrcuwsDFJs7VIPOZLsnls0JXH9bku4KPdeTYz+fYa+GdA9A4ijr+KTOJjTeH6OHYEqcoDD7" ..
	"E1nZCl966EyfVxb75iKwJgeExKM+Ardb7a5HdlZKzra+AykrYOZLc1ESDL1tWS27xHuGNVyjLDrggegNYrd4mzvWjlA7dEPF9S1J" ..
	"VX0HSRRGO1aGrzT/HqARuzCiv1hxbuzDlJfw7cm4fCdJn+smVy1TiPvj7BifQuL4CEuKH1X4MG0ys234hZw6ucYijRcZM9SkGhpj" ..
	"nqXXBdKqCuyxSAc1k5jUmqAVs8LoxejMSh0TDZSXABOf0hUUpHbcImeWYSssIUj6YTXe5xt4cNfjiJ3cxrixvCw9gW8MPvTGHCy4" ..
	"Qr4vIZwwTD9py12CbtiUb/6yY0IL3vRBWSFBjfwF9osDZGUq6QjzfDXFAfxtV+b2s8tSip/8LhU5k6Doea7vnvboOIlSTqdi5g9H" ..
	"K0HxVSlHyQ8JaO9G9AeIr3Wap6mZxQVoNFmt39sQIJfHEqY4xYS/YIE4q+3eVNsh5gACj4vS3lkAcc+OC1C7SLkGZ1g5tEG7br9v" ..
	"/PTZ107tWD+OJLW7ufo9bjvaDlmpkOpQR1v0NvsZRVytARZ+DeQGt4VPtl6NQu24psK2alwJ9TJb66EzSnEq0Hyv3Bdh5BHwWHCE" ..
	"pYU/Ns3SM8CzvQTzf6Q9KuW825aewZ/UHd+LSXYIuvL+ccVl8W3kwbD4h9Sw3JxVdi+UXcDKkdLgtMvU45LMkMBmauj0srmWbQxE" ..
	"8v6wWVtIXP9UJiLos0NvYNpiMGXNVYh4QEnXPIDsd1EKIM01VK1RoSWlmh/FD9LM52EfFYbGeJRU+Jso9qBeHe51l/sPeKNgWy/K" ..
	"a+6gcg1RVvYwUajxqG3MkArOVY0O+0o/Apn6PAFdv5Kw/Npb7WDm4t40ZPPN6TYEdFwllOcCYOHJiLyZ4MM8DlSyJoAEkDsNi+dO" ..
	"8yFSJ2jB4TY3k8E3nrUUJQMP3D6Zxu+JIgjVLZZs76Rx4CipN4wUykJDPYbVZSt/MLjaNMIBHEPfITFBWJ60vYBxpERpJbEQEDJs" ..
	""
local PAYLOAD_P7 =
	"y3p/kJ323F9SOQIgcBsCSNoMxFVX2nsmxxEIuwUKj8AUiSU6WEZlSfU1rHs8elgzO/dVfsjjxU19w4GKeqxQd46j0XRZb6a4sPYq" ..
	"MArS6q903uwscHofufoS7Hf7fZeb0XBkqVUx/sFYORxo3KdO28nKCJtEBZJHfm1AeY8aK4rBhFlaglWsp/dfBSFh7VIPyIWhi5VQ" ..
	"ZItmMYBoBQ2yFklJFR2FZQttT0nmcKKTUB2CQRMpbfpFt0vd5fmzUcIH4+SBk2nRC+fMyDy3t7VoYPhBKI2snnvI8r87YyNtZzL2" ..
	"dm3QO8BYTsz6NHuf3nUPTyZPLfA+xVtXRk7eOh8yCfhTtMZv6Jim/SyDVoeybcl89xncmG3dHp5cTuBnoVFMUxIedLTLD9iNHJrw" ..
	"8mQ9RfX2wtyrzfte96a2roYn2O3ATB/6IwLw1KlprMtRqOnMeyCZG0ZOo7XTFwvJUzas7O3YD/hfj+zMxRKZZHaHcVk2PKK9kZBZ" ..
	"ccTdWQemna/5E6xcgJy/mHVq8xF4DEx0+/yZ+ok4GcEkuzCb+f7zhDc+IWY3kae9A3P7z67h/WLW39YTobckidcZeRM3acBLbTkh" ..
	"gy9XYfyjHx0pTmZjWuqSIihBgxIejH4hsRnkUKpQjHEzKa3lt2KL+cC73ct2GkNLMO4CW4+Dv/yd8aSf+hE2zqmHfS7HwnYTOXdy" ..
	"ZGd2WYFQ0D2n6sL25l0s2AYnVGnULmhGjMUA5JZWvHoQ5sATbi6GFGB/I9VKgTGDa1Io2OOIXDNnVrcRkYwKpITk4xjpYO4DpW85" ..
	"iQLlxtU1IxP9fVDFyUNjz6VUm3zE/UIhcZEr+Bj1gnGd2R+gAtU1DVLmlFU4T7WxbNYunrtsibMIzeMau6QcirYDpxefNapHNVN0" ..
	"XncPdsv8CtJC7nhIJoDcouwOuzUsr2LBxUUt66oDYezqt63TWR+qmwPw5dl80SWgfr+qjteQy8DvI17xAGQ1nNY2HxBruZxgnGoH" ..
	"AMtO1I0PhZIU+KEJrYgFyF9+Ap1EkIQfCyighiqRX01B/UCpjeZuevIfrtM54vVKEDj66k9uH+4Uy5sM/K4o6WWqjPrdMU3iwpf/" ..
	"WOt11x2BxuH+bqlugYHOsQGMU5sVrn0K6Rt2E5jh8vVqSBfNjlGm0+X2xtD++5L4T5OxS2uVb/HKCEr724s/HJjX9gWAW+pyrm+G" ..
	"sPdthHLwNq5yMUzsR0AGx/YnhlhtS7vBiRdcVEFTZy3fczjwGfejYDZCHjh0IIMXK/p8LZB0ElY5taqazyKSc7aoFo7AzLlCRwEF" ..
	"gJ3CbfFGlZ8Og5Yd+ANjiwQ51JThn7fasYzt/90tauFz2AEO1etpfiUh692XXp2IINt0L9lWl+CNLfDn98VuqCKCulfAT7KXVeIb" ..
	"wDlQCXr02ydtwJa5pAIu4uvH7jFR5SJhdiinUanoLW+ov0376ub5fzgQQya42pnj4c/bp95g3vcH06XD0NZXHDGpb4SqZz+QupRU" ..
	"QFd7xbMCuDGoznQSPpp1OVAlvIqaW9sznup6rgVpjoedX29NtbqM+GaxDLaR3Z0Be50OPeVH2mpvljhs7qRfX1PIdq4GEHGcGbDi" ..
	"Lo1TQKtDf4J52VG4YeFXdtb79xULZ+IHpxrIwdU1u5GI6VXftQucQZiSaMioL+MtyJwm8LPVzDOAuVvopZ9Ysx9uLGZ+oLnKeqgc" ..
	"pfSe14yPS9cqJ6jae66zJ8qZRXR4B1AdMxd4q/XeW+rQMAdD4pWxw7ePXy0mhoPkWDwMQ2Boo1ElwDpt4Rspj4Kwa3A5Wrnj9MLT" ..
	"eJRV+v8j12ESSP2LEB/NP1HFn4jCWgFTiHKSurvUQSuvAbeh/XLf/QFd9F4AHgHG6O8p9FHBAyNWjnS7LEEm3xE+9qCgGZPMvgZw" ..
	"uK5Bn+Y6c73U/7LCMCY6Bc8NvREHnZyIc4bpPBSuRKVt/R4v5MIxDg3M965B+loj1J4MPXwxuk64nWUSRV4N005TXCdv8Dz1gDbp" ..
	"VsXWk8um7tBr29V2E9UvnRuXea/cSo6RHrWGfLnBdC0Lzmga3IwbKLVo+Fbhw+8Kr5ObkpvCZ3czIuuK0nuNnlS/YMtC2rxHCorf" ..
	"HwSPIzcbbRm4crCdOkyKZ4HnhG42D6O4OxgBVpS2yel0IIV2KI251F1Q2sW0R1PHJP+PRakSz78fV/+x9vg/toUxHDwtbs+B2vvE" ..
	"Ue3rEqpDQKdD4WvsBw45y3A26oCHdnSMxXSSpw43EVm6J4Tmx3MqCcePimdMMv9S7BwZHBl0BvXzGQBiefkqsP4rLhUK3UwHWlnP" ..
	"2PNj3cegKL+7PLNu6gfOy+BG+cE7ejDxUizMkLxd1KL02gR1ioGQzm2nwcJz1hL1XdltwsO/Lt4plQf7oQaIGB2Tbtj/XZIRlWR0" ..
	"QnBdr37u1I2lPeTQsYjbgOMXRTgRXTDUkX/mjO4Gr+zcelhIKTDu6lma+EdLQN1+gvK+5UtBpPkqM+00MqxoU+kEq7WnDZG64iZD" ..
	"Wk9viZi1hpHbe17feI69KcdbF48/2lblFwGXheyBQERG5RqxDqOiea3M++FtP9tvzK09kNLUfXlk7lo/l9CTm64Ciqp2VS8ZBjo+" ..
	"lPw4fAYArUB9ZuDgTp6oWO4awq4Qqy/qaEJaubO4G/EDIp3PaEt37rW8jy3yHLIaelxP2BCGJQI5ouqpBHnvOSQMIXEKRMa66D/z" ..
	"rcXsqS0VJv29afRK989oXqM/wwLOpJCIrf2edLjF1FdNRbUbDzDZnrzEygQTsb3IkAwIYybWEXvE+jQhm4aMdMz0TMyxjrWEnXGn" ..
	"h8PJJeGO/hN1WGWZaZf+hZQNFC+mdFjLiHoBgCMHKyyaddGZU01tUfMazO8QO2TbwyFyZFUG/LbyQJEyqCwvMQ8WCiBX6EXqq61F" ..
	"+sdJFAmc1c5Vor7SVJVn4+SwkcUK0DCsBXlTDReERScCIBfyNzpQfNqxcOPPIaN2S5sHAwYU5Xm0E0OFnwInk9q6RBhxEZd6GT1t" ..
	"otcH14vjRtC+vglGMJk8sVnnp9YM1zoRMdAuQFND3zy5NhaELPaAX8pGyBwZZBuBE47Uo11AgNaFjm5jFY74tAO5zRXCOs7ubFeB" ..
	"lKs57+PweHmlX6cpLVg4HLcnr5wmncXOYTyemV6BNzUHpk/c/Ysn7x2pg2x/Y2qoWuCcolynGJdcKEdQHI1SH1fIbjx4+91Fjp3l" ..
	"PEJS6UQcBTWE2ooI02SLyCeL2Yr8VZXsEoy3RwLtQ7WkGUE7MK8Xxjtq0r5jWCvyAyNwBqt5SV30wmpTE+lfj7sVVxebq1qCW+ex" ..
	"RM04R+IpVd5BjVoUF8fZTseSH4dX+5eE+ZBTf/CKzQTUSN78xElKT+MHqS3f3h31JfZyfWEYIPRg11mz6yUhLCgQqsyzxHegGylb" ..
	"QImOPwISwjPTHYvG17uq6AnHmqHcoUhrlSKBAx/aduxYpOQxCzSvG5jijhyDvwNcjYZtp92ZRT7/OP9viLOP43pVvRatKBpaols1" ..
	"nTBamAjC/kDMrhWK2sHVCJEz0JDvJAjylTwmr8VUg2/BKh+m3O5HrbqnTo+6YXq86es7DDKfwqgHXbxmEEL1bISB4Ilp25Km+Pck" ..
	"r2jdgsC7E3xcBtk416sPpiD/ZeD5LYRJt0hDH7War7auz+NcE8BTbSH7+MZP4tvcTO1irNqOnHHWRSp5r5r05ECkoDklWMOM+CDc" ..
	"5+59we5uVDXBtWAeDQy+B9Kh+dDIREKi835ISxY4+FwKvk0xm0yScW66CRY3eO+nMaPm3FkTR1RyRyjCoyhujWVRYVph1qfbmHE5" ..
	"fzUsKQewfK3aCJlgO1fAWZrjPboaDyRmvaw3faqot4Rh5lGmd5i8g/+1Br7z31CnoJ41VqAG+v3cv+OCUJL+srEz5gjHKFoZgfIe" ..
	"jbmKLhPl+r3f8+FT0dIdpIc8FrLCANI6XW4m1w+lqIg3bM64dEPDJIlR6+MonqX9ApP8DoxODM/w0WSScYG1bKUz+bcz5S2pibie" ..
	"LkBV2kDPBdYXJXu5DFBB4Nq5Q+HIK+8fRq/NjovyD+HRP9vi+FLGaZhIbsSrQrMG+bJiTXyjoa35/9DJaGb7h/yF7XkIQ+tWPBNe" ..
	"uB+Qib+ws6WNvvXp4E5mOoidsqD5yrQ4P1CVr16GIzcA9YhLVp8ica8Ms5C3+/bNa0J+FANbEFAlOuLYW8X1qWbmPEjC5+4rnnK2" ..
	"G2HeIOBw8JiScoIp/rNwCU/D2brVeECJqXobnzeQ3Y3z3khYz2xWcJMCFKjIgjZ/LYpPDurmOYLeLLqf9hVmwSMn/PgOe3RVbaD1" ..
	"jGW+/8R0PcwadjQCSNCfI03IN9aFvYj27MhNcuucvGmQJ9jwhu5tihvHIljFWLHBw4O1Nmi4CypcBOxFBo61LZqT7OxDryxORIDy" ..
	"5ozWKgTWm4QTvqC1Zkibav71yXmC2/p481PCQlN8qcbIo6CkcT6G2ZvkpfJCXqxUeFecZuenxOcZcI73+4GdXrcGDsaxJE6cT+UJ" ..
	"V/e0S0EIBB/ZThBMuMvTO7oADrn16LiClMKJuZSPpLPQrt009PGS+jmUsYfUOXNxUv65m5Xl3aPaqpj1830Fk1LWj2M+fSCkWjS2" ..
	"xU5RtcdhKI+2hXo8M6JSubWdLn+M0i9NiRzOCNp/dUnYVIVjaIiclm7u8oXaP0aKjQb32sf3TojfoTO2uSo6xgoqioiQn6ySPNdA" ..
	"jafbegqh7VBQk8ieevOrhXfJa24J9/CLIkyR7IPCUVit5k3s9RxpGSyOEFgwTLbaC37Hyxv6WhIpngJihsdSh528AXjw7fKsTZCg" ..
	"4EKEB1jB4/ckwmhox6JuXXHrRHaYAxWEMnTdc8eUpI2wSRX/Fg/BGL0vGkNuqZZDl7XvnQxQovblVw7gyN9JG0ADMmwJyFEfGjc7" ..
	"mYHFVE/UoCHgWjWvOmuQlwE+rYat8NS+k5oa4rY3zu0cRFG2eW+kCEUbHSnQNNds/lCZCNnT0Nl4yIW1rLYW5CklHS+BcSsz57ws" ..
	"fKJmZp3jHsptpP171yAwrnug96Gaqt6/U2P8Tl3xYZz/rx1Yjmx9DtlzBwId9lkaSCc+WkWNU1o/qhjbueU1/RobeZ075OnincK9" ..
	"7qX8NsUyYb5AzQLKOCmUj61G7N3lg1Lg9Go1asQvnvZlnJkCY0NZSvAuma7SPc3/a6jR3bsKiNVMh9/ftQY9HbEOfmg2eYHyywUB" ..
	"7GQm/oF7+LBpEfYOL8ZpWaxWJn4S/ruto5aKUCa6iLOWL7QcjXiaZRnIvOdPkT8DMzhUH4MPJ6u9BbEneOmU8EYrSBCl/uiT2UTO" ..
	"BmnWXCoHR8vCpQh2fjmR1N3e8m/+KLSrHEGKizkYrfxiD/xCmaWj35TUVIqr4fYnun1rRAvuRszDHJrMdbxzASuKe9zyBZ7VQx8t" ..
	"xAjwxllazMYogh/2TnoQh5dixOuV9rBdqVX7T/UjykdFaoruky0e3NW2z6s4lHGXSw2ZerBTNTXiIYSzLE5iY1WRId6EC+j/6n2Q" ..
	"/WyegY6hOWvafZm0H8FL+DViLQHv3zJGEK50x+BVsppETa77uCjBy3lqN2Ifb6wbca7WJ6/4Eo3frVbyacab3Ek91Pl64/m1F1Mu" ..
	"fUhbhj8N4YaEhjXwIx/eRj5mS/foXaC9zlNajJlBQ2yCZFwZANzvgFyJfVl+oo0MRC938fUU7rPZtmlTb2HaijsEBrERDrnQKi/K" ..
	"RH3zgp3cPExQGPFSvAJFZ+K4pK9vYoSekyYumgXJAXCsyUXjgaoLW+7aZ/439bf2ibFhprPQdb+iFNMWcjnLUu/Jq2UYhhXVuB+0" ..
	"UbaV+p7GqRwZA8Nhhep9MKMRKmtjPBIiIubwza9o7lHa/CAuN8L1RBpLUsEtAbDlrVns8pnt2QEpxo6NQEeCZic8KQfodbUelYGh" ..
	"ppt3ECaemymFw25ZGWOs8AgT42Oj1zYqHUm5tdTo3E9B7eMyORdVWVgKDMj8mBAw5WWbu0H1TezDImiEplPp2/GuN0HOvZlbCe2D" ..
	""
local PAYLOAD_P8 =
	"3fU7Y1QstDaUMmnVqrJXUw8IOPfaOYV4Vn3cKDQ/BzCwT2Bvctom5LTQqT7Os/RXRsWob08WNGzJTsywv2jSNZPGJsckGwt5P+Gm" ..
	"q+dAoqnXehU2roEaofQsTwNKLT+7aQKUqhP2VadoaUy300hX1pP0VYXL/yUyAZUq3zJpeyKycKDTkMch0sQjaqAuA2lCA289yTJP" ..
	"hApysUNY9hVGH47TvxtdtMFxSXTyu5+AL9q8LrmCn+NQ2+FHw8hMAYds84H/B2Rh9x6ifsHdgctQvBItbauEpm89PUT05XbwYJ6h" ..
	"GppoPNswq72bygG2BJHB0ehwliNweMNlyfmx1WFdlW3pG4O9xmsCajPEoPkjLOt3DSIMLZGyNomkatdSgCBUD5Vn8HcmhJymeinN" ..
	"O/5FW7y6qguLwAxBHq1AJ+hg9RCDt7K34XMfZB25wQT5cWeIvvOns05zeE+OUJCXL31oaQ8hVVS3xOAq41LGYj9iadqRuBfVFswU" ..
	"QoxMzfLgAMPv+8Xy4MdXYSOkfAdmszY5vYDcM2kqLUOZJEoPVKn9RyKBra5zYrJjjF08gjsBVVG3A2lQa/D4glsbbvC2rp/Iuq/B" ..
	"mRrLMsEaxlQ0AF7ybZknkjWmLhcTlIT8uI/KH3Dr+du0hjOs0ySqGykIwzrZG3e6um0mUjcwQnwlXqYQy1WzT4ArLZjCkg2ULg5+" ..
	"UDREgBVdS4/gyf+gfBjZ5O5IOa6jgoAcW+Pv/vecS2i1hE1wAtoUVJHQA4cCWiWVq/xSXnMoMCvfn2nLLKztdEuqX58yEFs3rBBb" ..
	"5zOf4GDOP0nughBgn86Gmull6RZr8AkreNA1Pn/7/V8ZUmfaItIlfWLiKJSWauvJgwqvNjBT6Y1rVjS4/DbjPH1TYGT0uzNQ/MQq" ..
	"pUAZrarGhVFDxuTQrp7l80Kjr9hKe6dh/QD+27WbYHJytkjfh+xCOMQQTtwrDade8sWzBqouVlO3h7aec/4EnUE8t8Ez+4/Ft+BR" ..
	"3NLrBDp5yehAT0sip5V85wvr5vR5LwGvyDasj+pZaQYMlA2Bzm+jOYzJYNTSvR34zEiVVrZGsnHaTQBKiq0d1Z8k8O+dYbGaYWO8" ..
	"cbUdxaswXsvoFIEK58oqt52CjU1T9hAgA7SRCRIoEiYrp01JxvryL02Di4rEBztEYzRkjTLB+IxgdhaxtSg5u3jCggC91rOog+HG" ..
	"dDIhVBTzLO9ziYGUGhsAHC4a0WavyXBL4y5cvpC7rMUVxGDNC5FK4U7rV9FEx8TCycOAONKBNwxcU2j+Q7beoOFLlgUm0P/0pVEk" ..
	"5G0c0YZhJEsETefVwCTmBO82Q77X4rTTGA6hEZuirp+QGtHGs7ciGYUGTDoqC7NfUtsPLg9XA4juQtClYjIQZwJUzidlskeQ0+7K" ..
	"uS5AdwkKp8ghMMKfTI8p3TgE9teOX7+YU31NP+Bf2eJZK31iBDzE8FG7dfGWCfTn120CczIdOGlzmXEZOkWGPaNMU9P98SYtWJhP" ..
	"gUREpBYOQWHNRSpWdXyW7/FDvxZq4hO1RexHwe+9sN0FKFQPeOH/r/rtnPpoWdw/mSPuQhERBVdEkB7oexU+Pxl2+gPXLY5qCNlN" ..
	"OkBnNE8t5nsR4TIzTQ5e4fooZFcIL8WwjYsiWBy6s+Gf+r1dBnuRPBhEXJnCN2OIqfRpHfASwCok9k8WqubfR8GEARc2EfZt01C0" ..
	"bqqa/LekhOKVTmo1CxI0Na/Fa1zUo0hsiyBlNRGgY2lX8wL3wosVO59ujIvTtS8kjjStDODUjS5s89pptTqBCpTQEz7jM67zhHbm" ..
	"wZVLJPM2exbF7OK3NY8PR5kFXyXpe2Ys7mPn0sfFkYqUexzhUHAzS/qNMlAKRnWQAlQyMa8jt3e3NCKHbZ1sKmZUXTxnn0/Q14yE" ..
	"dVE0hCeZ/WKJkn8xqY7zPcjdWC92m5i8SGIdB+TYjKYXFdOvOwlU84ai3/+2U6GTRcMUZimsD+svHtXompe1LYtUbF/9Y3GyKjbh" ..
	"4bAr+HNsjVTTjSLdbuuG9rOQhQVRsqy4r0weCd5Too1DTvgaMcjobV+inbgHMfuXFEIREw3Ik3p52g5z3QEfi6hrH8xg1BN+SMwz" ..
	"j6om21WQd5mm0vIY2YD4XjT0UhT1hMB0LFV/U4c0ziQ+b4HvRlOXt5KXxHizvdlkRAqow4wna+2yzm6YnJhkXhu6+8brVKIg3c7P" ..
	"SuZte3WvzeupDVm0vMlHOrhFQiamW3TtChc+uSWoCpWuPBVOrlgdK9pbRNXt0h+NEFjM8CUnuxs08H1kzSTRUZ9FpDgIzd2d65Vc" ..
	"yqmOqZjJf4xDflTx6brpTR+sN+et55qEPTVu/G/TH8HG6fQ/4Mm1u4gIsxH9Q+MNKTGGkkukWFPutoGTMD5+Xdmd7LpRvDeYJCeU" ..
	"P/8L+2i/la02wPMrY0Bnr8of7X+BFJ2o/wiOdSuX6M9oTCcn5y9upoK/HEyqZ+1xMGY+//ZoQ3cc4PIqEIDlX5KhLdaVdRepgG18" ..
	"XC9zNVC9cJJfmdaC4c5+l5kGT54VNuhncZ6WYOuHyYNuCCDl6+XCcr+1AMtEu4//STD6wO3w4heOmW2Zxy2iM48HoN9jEcsxpd7N" ..
	"oiKvWsIeSPXrDsO8bv7ZrKeMNSSSCUqfiA/uTqF/wstm1Hcyz/mHQNeZbxRE1uI5PN4ZBgtoDeu+0G2DqltyxFPNaoABZmLYieVG" ..
	"4ti4qnG+TRhssjiSDgRTES++kd+psQFL/NKYf8IzxW8dVQr+tI8gmeKfUVe0KXY5rD9nZ7NJnrVr6OOjcsL/+IypOMxoRSA3TYen" ..
	"MZjRsd8K9TmLZIC1x3rtK8FblhGaxZpPtfYSzE5tr+uz1R4NrQlUADv94QJQLgxcevFpab+7eh+mT+r/Ocy4j73bqLZI013QA269" ..
	"SRbeMNaEB+5s/eJubhPXDL1C9kI8hfSynrXGrkZkc+hGlTjfO3reemZkJ1VpKYZUR8RuilH18iqOhYzTQFqueKWmY7UcAdDcXRfb" ..
	"gnbyQWwn8XBFkc0TiY+/4KC9tNvPrFZqlHhg+VxCFl69AIE6paOpfBGwmqHD3Vf0Dw4rIcNLevl9AwUE+K2es4xBJt6x7P2gvStC" ..
	"u6FljLTPFX9PKF8Kq9qM5Hvy8AOMFqIfkR9r2yDgNV5yy7pVkgXE8DrNhea3TuCVvm7mJVQW853Bum1I/Ka7iZDMILwZk3q/srTs" ..
	"U/RX4/9WV61/HI5OaMYeq4v75D9TVczoLlPvMKNdhYPHIVdPZYt9EZDNI2yNCZWsrxvwldvGtO2pBFA7z2GCbFeY78SYsKuM8gg7" ..
	"V9NjGP76giZxgLNd1awWM5P7va89+YHD/RwwCLW16+QU0DeXv7+jhr2083ez667C32XUH1pN5Ajr6TnkmiYpW5YHe3zW54EUR3o6" ..
	"Cq9y+arjOSGf1lOGSk+t3VrwEKxuLN6YyM15Iao6siY6sanh+7PkqEZJMYwu3CzheW7Q02daDFUYb15k26/bhze7Smo/U60qi0J1" ..
	"qhL3XQmPdvmw8qPDwELqYw2DFrcp/QI9EEoLgTkmaYSM//4f4xaB5+LWAJOoD0YkFSnAa+mfP1CGM97634nyxirfIhHHBCvq7CNI" ..
	"aOPX3LKMNhWKlGAuFBMuJhvypLRjPPwdc0ZXL9gjVrtxGW3yRiksKtjuFmZmnkMblq8fHCTQmGCwjJuCk/5as4jKVzCGclDdHBad" ..
	"wwg9w+ueNmTah1GlyAHgCxXZ01ZzM4a6SYsTAupTwmScAfDJJ8uhXGxGXe6uEJWVsjRjIHrPIF6nDUpmhPtqMnPOmyzXGJAoaO3a" ..
	"xFtQqCoKfzKWNL/GLGcmrBghBP/Tht64fBYGbmkMx+SUXublBDdFXKe2W+0RfTEi9YowjfW8vLKcatZuRzZ7ZhvAMiuax7aMmFXD" ..
	"YNe0vQi8bU2VRGJBNP9137n8bUwDyObgRfSH3c7vaheRsK5IRgIeJIFDtywMb0ziSFKhVtQ3FlGbGUwhPcv89qWa6jOcL98+6mi1" ..
	"C+5XjLOAoP8uGFAceJe5TvfekSrKUHp3v2CiJvUKpOVcgOqOittFOQJKPBhJIv8kWzex7P8JIppaLbECnsVSaMea08d+KFQEtu8p" ..
	"AJ5NxNGBjv4Tyk24ZcaTmshyCqOpuBQZc9Srs7Q8U7hugzL5CWIsd1OuWhwiz/v7NhfmwCmfG2NtDD7KOsrGmo/6osYZJd5rut91" ..
	"/vWsrDrVqmLe4ROO9//3HopzJ1EKs6GOHBJ2v2G4ae6MQ4YuMfb0tn5SLm2hs2FWmij4kjqnB/xOu9DndNTroEHQxMv/pNt1/uXP" ..
	"gI5HSuS1llA7ntfS6B94Jfo5HcnMst4fsGefECKkk7WlZu7CZeRKztaM1K/OLGDluXxXfrDnIgvPVrwIAMZZWYxX1/x9/FEqF8yb" ..
	"SfF4mO5hjFEP3WVaIxe4M7voUNgF3jpa/lJzGsxWzAy8M08QYS6xVonwoyQzvvP/kALJUew4bJq04SFlLajqeqStNnS3MVomwMlR" ..
	"srfeDGe5uxphIHiY/xC1PvzjoTOZA4CVlcQhktSDt9UNIrWmOdiYN+V8UAkHmo3nt2K+vnhMr8ppubiAT/kkn0Xoi1xTIPsHBbEi" ..
	"gchYsiXdFhioXLmI4RKU8YJuR+ugVEhT3FgZtY6AYrVUMJ4TReOfgMVNm3mGdFxx5D0G9NfbYAOceDXj1kG4ds5/Ic6w9pNmHKbL" ..
	"H2imqPA8S8GpET4loE0xFnLAKhD5m/xfi8ZqWk6cqHZF8vNFfnk0swAen0kqxcLXWGgwPl+BC3I9FTIXrAU9svlLFasNthiBNfQD" ..
	"XtrNfz/xSVHkXjYW1Qtyc8JW4fiJl29zPNYqH/l7tKtrUUQkbEFti5swY0sRhyPfJsoccyF5A4UBzUl/+YJbOGTeLUpOl5qANZqs" ..
	"1Al6m/VpFNATUL5gXJKd16hytFyoRQ5cPJ+7VruoiX6HXgrU1SVyf5ILJc3fVQ4T7Ao/c8NIb8L0fHfGtOF4/CMEhNKfQ8ht2oM+" ..
	"wCUj7qu0F5Tyonc1HAG4BAwzaPm04Z4NPSWxfQ++G5xxq/WMQXqpJpSMkWXAqojahOmHlXw7vQYsiA5vkLPgWpuHLzslMGr7kj/J" ..
	"Uhy0hcuZTiBsuxCEVb58w3ZODNvbHN43jXKXHCNASLlCWcPN59odcyk8Fp//iximiIbELcHa5YFWgAoK6WcP7DLmDYpQEHzrABH3" ..
	"1+OomKtvG5Pk1H+L7UM7GvLhOJYwAMslx3/2eE2GSXTpalwneYHY0pciWJ1+n0y9vtKtJ9U+BbDLVnmQvxElvHxGAMohxPi4guVa" ..
	"5VN8zOcYxV4HOZLTbLtds7KV/mcklO+oOkuOGPUF5ivMa+bgbF/g2DcrEd955SFuNrnpM6xy+waqWfuavpxnjIsUizpTpMvMNw+T" ..
	"FBXJaxcR6L79hDErpsTeo4cpT52KSuO1pNXg3WyPvgdAG9pOZgy1hM9/jtqWwPx/9w4V3BYrvMoeRSup9txzDwt8M0BHuEfS31O9" ..
	"cBmG7/zlj1LkWxoeXE7ccNqsa50xmNK1xK0cqBlfTiIUlmGTNUZGgRBFbG4oaU2Cj25huDknh33yIW8/DbjorfXP+wQ+ShwOUOSp" ..
	"0R/BbT3Gz39ubA7nSGxhtdk09fzUenaAG43iL9R+gfAi1N7zr1GIgg8JXFTuFSo4WwEd2VBM5u9kPIabxXs3NAfAWLEM8B3M5tgP" ..
	"EedGNHeFY7dQkKeG6Xeziz2iwXH73Vi3DN2fNmbDZS3BYmLQTF88bn9qb3H+wu+NtFO5HdvcRGxgAwrZk94/I+EDEWa2R+hoinIY" ..
	"bUpK0rhe4P4uZomWZaZueEBSYEtUoDQolNHSD8N9kZcrpRzONE2M3eEWey/4wnLSlTKLQd1QP62FGza1OSTPLlpZJE1EpeLHwRN6" ..
	"dVS3QY7YrHla7KWReffN2BuyXmwupmBY8Pgair0na0lkwXgHW/d2UZbe5G+CEptdwyci4f2ThKWJlmjDg9OMI+iQ3MP7IvSSAuCO" ..
	""
local PAYLOAD_P9 =
	"Nqhw7toNQQQGj9QrjDVmLSPgGtIt+lFQRU3jEo6hxI5LVen4d2nr93bjKSQB++aEYm/wu4oXJqaC8lB6nzoWU5mSDk8mBy2lZgFD" ..
	"8zmKK3wRGPgGkwH1O6kyw/hWYeG7aLOFSbo2NFzxighL/H2heLK+K4JiHClYfs/r1guoQpbDThlX6YXlJ2F52KR09ff/Chq4AiMb" ..
	"zywJn70DB0FgOKUIedMYt3InGvFlZ/YwyF/oHSMVJ34c0DbGmPsdyP55mRJ99DakensGKitLSLzk4v1Tkypd1YQKijMBqIji2DSd" ..
	"Y6K96D+UX1QISEMWDdt5PqqHNRxM0pvUaOvDbHJxk6ZieRLm65t7ddTWG6YZV/p6fs36atMSk9iuqmfXJegp0NydOVEaOu4/XALc" ..
	"136m/FEo5EK01r02a3JDR5fDzaJT/deSqFQTJWXkHDr0SAQ6uCFYIvOZyewk4/K0rl4NoNawEIWU0+T4aaKfX4lKkcllRWKqwyg/" ..
	"4gMtmjepzb+X21DPulBSNMq2vBODA3LyeWpS6Lh6gh0BRz6ldiS3NIYHQaYSzV079zdjvweaznwD2BrxHDs8WKknGpTRZCEsd/k4" ..
	"ssSFZA3PiWSjIsFrLE5JP1dIvHZn5eLY6Dd5c/McH/pO0LWjSCtqBzYGRkovnWrSQ4n3zgx2+T86zuFLh26mZEuilEsbwEXmQ0bA" ..
	"3x0OgP+Av8bY0M1k6re3sXMlS9BvkbpcoZFRn8E9QJGiqpPz6UbRZhrTbrSsa0kajqpsOxPhucr8BUnu0jQQ4GYKLCGkKZ3vANfC" ..
	"N9CVtlyvrqFci9XdfpwzNPWK/Z5lWf9WLeciTpPbSzkILc981eiRAsbumOwgde3cZDbVi1Pbz7M2zb8r+PZL+vDTn2UyAxA5cbZh" ..
	"i0qeY3kA/GSEQKYnjBj/eqruYgSbdYQ/Ne06FN7GAIbeOichhm8AaLFOB4UkNBypv1o5ZLQZSRSHIxvieRKjGOKdTAdk2UCTSHVh" ..
	"I3tBjs8PJmWC76xYY0YSty/CQ2AceUr9Kzb4T0v/+AnSCOA8mhbFtYp8z5945U9czKc8gSpMzvdVCZgXP6vgiSC3H/UgvObwNw1J" ..
	"KaRtrQSPp7aSTzp/9JAoLyF0B//+5sVFU3j8VI3TevkoB8vbFMrnFMXsZe2XExgLliaZYOyGtsk9yQjl8KfuHuHQcizLE7x0rolt" ..
	"9hoZbDsuMBQWoLZ0g+6EWzZI3QhSjPqS7+OIXB7FQeeEcEApTwVaaYfXi45FFDVOQAG8nJFxKHQTpKG3TDozAky40yO91i1mlc8L" ..
	"xHWLR8qFadEqOsllLFObcf6+wAiOevxBoEnqjrLtRkbJjFD2KGSwOAV/0mcq8c/us91IN3aLppCc9XBVBXXWXQkU+w6vWJ8jvDGx" ..
	"0igSojNa6vKb4GfG4803pcWUvIYGIpBEKIBDKZH/X6SEZwhW/jcFQkaOOa/jJ01XziLYHBZtDOeBaF8rzcZf9oRXsY1c+ZfNp1uu" ..
	"1eReqvvzkfJp59GE5hcj7ZGKAgVYYHq7DK+UGYBQQlbrh2PBLqhh8IT0STwWztJf0UrhVTkYkYc9hZXP+GhbY3e5Ut++QAZtFzpL" ..
	"sDCqlpIsGZdRTOIOLNU5Wz2diA/aACMSD6uH/3OlhU5/WZ0Ow/J+3YWd7nKEE7l4+cuKQgyMK0Kw3sewaw7DXbnn91Z1wHiTTzQM" ..
	"6HmELn8L4ICvAhWAsxHvAMqE8ArDZZRzDFocjSL443ZSjcySH0otfjEqRKlnrVjAJMwofGOneQ9NsFBc0dY2L7fBHLqCNooPJc2R" ..
	"C2Bzo/9+tKneVHRU5EuspyyCie8YWdGboTjXuu6uWgNUpLe5WljsLKpejhBwW7NmPT12Rx+Gfv0bdEQjYWdfEfPifpCpJYm0qNXP" ..
	"4dAb5Mj59kv8ulESRo46ZAMxTosDBNZ1BE/K4vn2Kbt6y43dBnP8zhu6xEbhF296jv21LPlvAtVY/VUlvv6G8IhnjswlvNolonqB" ..
	"LDrAM92/T5dukJay4ght3y6YFsjGS+C9ICr+RlGrDK/pQLg+6sai2/qeIKqc7xn50diC6JmpDvlw1RMgvyPU3sWbur69Xp8vxgBu" ..
	"XNEtRTB8RC0qkGlAtm/XOZ1k19/620ZMG8/qRViRAv4pUTDdQ4faDyAkn6YRFufcnv53Y0RCZProx7U8lDOI3FT9fh549nKKN1+b" ..
	"t30SxVAf6kiP+Z4oLnoEl7Mowwhyl16aqKg9cTam6Q599lt4faM7MCKKL+6XFPQZ7AkNqd6mh1E8eHz3GJgQ8P9GdpSwIjw+HY7X" ..
	"qneVUOuob3p3DCkkuBwQGKnT6l7HsPTIzFY8i0kqZ3WvvdheYp9IxVEqooqjcKvwpB9EemX3AqcTeKTn4jVMWry3SyeD8p4DnQ3R" ..
	"T2gI6RBD6jz/9lMPZ+FdasMm0X0c9RQpheod+7Bc7Gdahrnkb5nZFDBtXtH6ZxIWyAV3NKuuKv2LfWVNtNjZO0Acdn6o63MhzaOk" ..
	"uEkGYZpm1ss8p3rJ8ZqDZ3tr35mrc2Z73QolYZ8sD7QUHKa1ZK2mcQK/bp/8Y9D62vrZxVRewxqr/AMEzKWws3Dg0SbuJUlxpoh5" ..
	"NCWb4W+XE2PGmwjGiNmbT84Tn+SprFIzTafp3leY5NuU1udtw+YaBT0ClxhHXNvdeVM2QNbwFmSgyEtd9Y7PKYGv/J2F0PRefody" ..
	"fabfR2yQfuCZ9RQALPUpzE+wUPpGUK4uIO2zuvUHXONZ5tmnKJ1IjIaQg49ZG9N7kCKFEv4B5o7UNwxu8vLvtmLjmaPR38SdDO/J" ..
	"Jswy1dj90XK3f81Jvz5higFVLX9NpPtGIZOkWzpMYMH08+NEnCIzWkIOljVS/RFmE/GuGiu0LAfwsKV2KWg2PS8KqT6D1HrToc6O" ..
	"t+By6F4PqvF+cU2pRBlPS/ohpLj2dSS5nUNRP+JE6+W0DsjCLuQwSif3XhRESdSnCxGFGPzqV3aN9sXY1HvB3KU+6mtVZcFslAoB" ..
	"mpVaTy8fq8qEuK0vgYJ6/hBczqQk4g41qMgJw8m8fRW1p+LcsO3yhKWq7Siv9HnPRjF2T02GhBRVmegaMa3byIY5WL0GcVdHseDA" ..
	"QM2zSXm5VDIlrgWaJr8qhbfbLyuG3x8SdGtt6vHuiXLWoQ1vQ7wL5AJ1tZgTdoFESamncX7n+aPTOLM3MJEAeblezAot9lXRQZSG" ..
	"m/bgpsevF871UT9vV6mNG6NGmcRwMFE6SkkE9hpej2pVmHJsC6aMCun5hi8PhkwtcJNELlK6nVVu81D9bH9IoVzvSVhQVosF/PvS" ..
	"XXa+aVA/theh8CR/KhO95Hh/EIg4l2avMJ72ZBWzB+CSBRaPRW4+0gQRwRwpkXc6LBcEMn3p2hDFNY4yF2YQpqKbd3IrvbGov76U" ..
	"4vLmtGQL8lvMFyNkK7d2MAxOpof2KHV8WXmnr4IgdyicLX7OmIAsRSg5/xl5/Ebuhao5WVUqMNN0BrwWjgfYL9+Er4pYnoo1fJES" ..
	"gFIjAFUOVfuBNVdZAv5B335yDd3j9OD9XryW1Rvg8xXZWgcSPRb+kZg1sCwFfSm93yduzknBLghOU3IElk6kn5FzQoyG9axlfI53" ..
	"ITPYfAYHEYOABhW/MEwZAvHd8/GUp6gvVbbAMywPJjTG2JzJ4VYxQrJOiWKM15Yj3meBKfDeFikdjLLR44yoZZg37u5DHWW/i32C" ..
	"l2s8xzjWXpH7s/nSmRb0GzB4dY1kSQTddrSHRI7S6/YD9U0/I9ZqNd86z9gilFuwhA0kDDqTLDSCU+yYxRBxzSDAXXtTdsquX7t9" ..
	"Pd7P1Dqsz4hEEbYimP+hw9KIKEklNtwUvUHKQfn62dBGdTnULpT/nwB1pnS3z+L1HkDWIzqOHeKeOhW+SKx9s7WvbBNIUoykGxeL" ..
	"hk2XB0MiA6bx6I8wG4abmUyrM0mwDbRtD6J2TujwJFwI7qIYO7Y5s7cUMJtP6WItSc+sxkmxsm9nxudSqcTqeGwJj0ipUesZHWkp" ..
	"SIpNVZgsyzCDjMpMgTtDwSLBvQ5UPF5wQyIJoiu7Q9dW971OOpfp/z5juFn4WRNqfr0g38w8SrbaxJErfnt8sEmFt4DKm5xr4jhd" ..
	"10FXux6XgmLX+KVcOXCutkGZUyjnLrS16zaeueZC4q3kM5nuGZW8UKwgWWyD7FCz+JHjVc1CgG4u6hyiFrv1kDLEnMV0wOEs7XTd" ..
	"elBWmAUnQAZKJUvQZPSVJ37mHCslesoodDnyvR3PSwNrkP32BRd9YW29R08Uof0LCV/WFJ+gFLMc1HJuMcgLCrG8Fd6/qjVbaHYd" ..
	"wsgcH60dYWjlRKcwy9OKkbkbaFDzsLXxRJxBr3leC4hDUUkHs2XP7y8WdYEvYcQ5HnLFcJunpg0AuqSVWF447sgFwvQAGR7Ttzof" ..
	"u6GRiCChw7tayEoN81z5BWeoSxgcpnWt6QknfWM7aCS+3LSa+rbGtRDYsd2rilOMYKhx4ZS/WhM2s/nFh+ThHgD5DrTKyCQKpDNn" ..
	"vkcxqNa7mAytmlQq/6Vm9mC31wzLoQzDYCa+aksXv5xpwoAnwI2IKFyxJ76zjg86yXhwsgmXOP0/1ku24oFZu6JWXCjRnOEhwgJH" ..
	"QwborVgsYKrWsJraKgY1SBEXes2YCRbuzIC1demZyx+lBW4v8s/AOuVvxGA1ZeSBu6njrSi6ruFxV53nrfTq5lL5ksfCWygrt1gN" ..
	"VkxcXzNql5Bpozmfm3j0uqPWCCPZthtJb8zR5K865z3uzMC9OrUgvxVq8g22LovSwg1je35cTGDYMWeV6LD/6svVN+EmtFHEXndW" ..
	"37VF7uRieIEzDwPbuQTBaYnOsPFQb8rEj0Uvi6CEo/jJUnP1QBx9QKKXQYmXvpv82Pj8h1SkXvRwXLq01pRMdyTj9OTo+wUHTgOk" ..
	"mqxFzr4ikkAnPx4RfCM+2ewY0Hs8VKUpiUiL6DoD1FIansx9BBnBtAuCR4V/zeeFgmEKjLNsxQVqkGqcvq5pjamwaBPNaAX5xwyf" ..
	"VIgQA/9TzyU11HusXGxIOUayV9sIIjoJROjR5LqiY8oWNnaZAQzxSBPalFWZZONimtsint2c8c8NMqWVH9j0FyxQ4MV7n8PiZan1" ..
	"U6EwGTI1MySZdG1tcRj1r62SQtcpVw2roMaBkcqGNqSw1oNLygcAlD9rDE7rf9dtC5dDvPqQUgeRS3b9qzE6xwDTC4F9GzezQoDi" ..
	"HMdXM/McWRucDXxr76+kCANG+KKK3l0xQDrZ4rHNQMHD9ePHdXaKg3invmyrQrF/JhffbxTLukZBEjMtK0DhrQMdrAdSBYXuCLXp" ..
	"XOxt0KlPzLDhWRWwaC1tQoPIVIfb21xln3PRMXifbn75I+D+WODhtW7EOjNqpY0SNNRSz+T5we+JWzz+iOYgBkrujH8C5yPkgwTA" ..
	"aVmQlrlTLMP1KcwV5PslN3bqOc4+9a2iWcX3Yr59U4Hjl6cTFcHw+bD550hUWGd6Sku1mop6ff69TVqNLDOaMkoMvez7gvr6t1GV" ..
	"EOs7EJLqd1+KsXDzBUffUn2YwtbWG7RVtScojqOegduqlgi6qSVvl9DjN3IcDC4t5GZ/x3k9ny6jz3Tk0bsfd4Q0Fxb57me591Di" ..
	"uD4uBqeGK4LvQe/vVbqAcrwkrR6n0dRzZSZVJVLid1/mkvdSks+DMPv5OCrpB+Nj8pL0DDX+NfJWb2gLOyLtpC/To8l5BaUDUnnJ" ..
	"YCq/x682Og2Acwc+/QOX4HLRo575cbmBCFNiYE00eBW5rHjx1/vF0R/emjGmN0uTnaEnp71T1g410XCPrpKxldrWE3Df+qXtfIw2" ..
	"+QnUpkbOHaPI7BzXzvipDgbI7KYcJFmzbj4ct5ShzxrFfgryFGQ7KgqIGxcIhTigJebelJ/C/ysV0r8yHByFrXYF6JoIkQdFWdFG" ..
	"R9YuQP/ycqt6Agda7IZ/gHFw+a9GtD5OVOkitE0vLHM0gmnCOcAtP9Wvt6bO+mngvRn7kDC2Dfw58CQVZNMseT4k9EJv4Hgh7bVJ" ..
	""
local PAYLOAD_P10 =
	"Yxy5eHUTE9QGmd/68BYpkHr5KgXhPgATXe+PDdC7rgAcMzMdOib0I894iVJJHJrLboPtXrZEqHTbRymAgCl1wgj2Urd53jipHayj" ..
	"oLPFO9nYGB2jNbbcznj10N/BZQCZK+Jmu9Opct0I5tfDh4KPLt5yOryPdOtDVcxpD6RdVRy/IhtUlU83pzOJt6MIV51ALbC6klec" ..
	"Us4XrwaPBZe3RpiFYreptieLEClO+cgTUkAYzxlaMJzEaa4R6r0yZ7Wk5lK0G6BT3S8r06LW3y/rtkyu7Lz/0Zs5hheDDOsSnZTW" ..
	"atCLrmgPSspnGsMsDsJG4/C6WGwjDujklz6DAj+7fCoQPbTw7ktJdrOeAscxl2gXvkyo9ilamYFfMHUGJpW4zKERj9BmGcbhJLPA" ..
	"9uXdEKEuJvUcLQE5C3qi/vrc5BGQ8nchKFvlIiCi9R2d1PR/h4ByBmKYtkS/LCp5DWvOcnjFBj6vhHrk7q9FIhA7dapgnfLASBsF" ..
	"oqZB3V7xiPrq8qVGkcbCJCd5iiiB9zP/X0MOooL2SGGheRivvlgxjloKbUAgBePlcXo8Wbv0knUEGgI52VKSsD5i4/NIyFo95ey3" ..
	"VfHnDtyMOSSrkTAfHMB4XwV7TwdH5gsz9v/ivYQ32SQcb3Rk5Q1/DbJNyaWv98pQhETtBDgQzBIljQfKcMgj2R13bNI7DfD4PIEX" ..
	"L5ZsRmjq8dPt+v0FGBZMlGow1gJA2Ub6kcmchm7OarD4FI2pZqlZRWEYfqKnLlTl06EeneHh4h/lsWYMO9Czf2wwFofC9CvxIQZW" ..
	"H0+y7OHzCOyulP9eGAp6CfaRUC3oXpBHVvl9UFGAUOXxqjXgY0Z8U7FI+ApkBl8sV2Wr5jjwQ0USL5st2qpue2WcjrUxNWfQR0MM" ..
	"j+w14LvYyx/31pKn9m76Tpn2Pw7uJxq5+vz36P6VIAlMAW/Z2k14KuWB2I1XSkdbcMk/fSICUAwbZ8NlXUV/RFrDtp1HU6KRvTPn" ..
	"lCMhga7E7jfkDNxeCf0Ya8iT+KPJFLb5Hn1403IYB5kAf4kAoPsvcuyV6OuYQSJzCFcinsKJGuUWKkG5cDmy+FNd4cSs0/xulXH1" ..
	"MeTj+5MJos0UX0awRpW4bu/G1qvomB8ICqqcRwJM5F6YyZGQayPYS1fJcrxFY2hhbQid3ESTSTOM4NE3RnbjWyJAVaafm8crNtZq" ..
	"hsG2srAmCBywyWvxlxY5hZ3aQwthsZLK5TmGfmEQwY86VGQTSabquCjqmr9MOMLTqsQjQ+lEbBNzsvQ4sLvg8qqE50cpWFMDJX7+" ..
	"s7OVbTptkiF7aUZziG7ypBJvIG7sDzIOyGNsed8Vbuqevgatj+6NJnbFwhhdbrkJw3OAgrvJFeG1/Ese7aV82VTw6IREwUH4kE0v" ..
	"0r3PoDyQtnQ5izx9Fk67XYhqtfEPwHtsKVXLYvpnitg7R7fBCP8iN8CehgdSaObuEH4AUkw9KVQimTcb/mFk35WfjGKy6ynhVLO4" ..
	"f5HjptnNsH+I39fM6zOPI7DIlQXjfUbZmPLL39yYdfW7iAXJAQ4tSHZ8fXRPOMfNwVFyii+m4OIO0T28+1O2eK5j86QAQ+g01jcu" ..
	"uT+QY5Z7aTvfXdndCU1CWFw7pMw6Jsfo2jSV7rSTNlUt3cfoUuFAzLX+tbCqFLJLKIeortNZEXlbHsx/6PG9p1VLGn3vV/+2Ejh9" ..
	"TyYBooyvulWzygIQfffhpDyzVIgVO/lqlDQIUHCusRoG1FKrqf/0xKDXeO/LlDeJJ5uJ7MrE2ujs060lj3jf+Hw3UD6WgswYlyZW" ..
	"exxxArMJq5LP/ahYC5yWvEQ5dXPq1ZPW3kMA+SZYR3t4fK05sem7aNL8/MMJSlDMNeXg7yGBltqrPBe6PejZwuBcAJwKcX0bMAai" ..
	"KbA32e0kr6HoddTO3WUFw9p1qxaF/DKnhRLDDGjCI5mwX2WDZu9TpghRjVGACE44e3pOLkh6dFsQfwhoHaESDMB/KS+l1r6ir/84" ..
	"ds3rK4g6RenmbIiwiJNFPtCWv9fAjn+/lyHO8bFC7aSCRvXWRWOQAEqJUhkfesF62BoTPWBmnAB7pP1DFlkC11ssg48zcZY/KR6X" ..
	"8yuwSwJs/F3ydfsTkD45FiOIHu5vI68tao3u+434nlNDx+eYEwWeohMiAyVR38uZQvvE5PK+yzWwP0FcDgbgElM1WDbLzlvB6Zzm" ..
	"W75ffT2oCF4XpZLroEzFXE5hmKyDbI9VPzOZvtSe5vVwADTplnQrBMoMFDbDuYa2+uCWVgtyoZf5wJgBBQABSQwKAWwYavMuVzBe" ..
	"S44vYDkrLdshFtZZx+f3BgGnFpx8QkpIIX8kSMBl1+7XKuUdW2x6E2oABmnjHIElmlVcIT9g++ICVm0Akdg5uDEbaRc8AyHK9m+N" ..
	"JzcRJJWT5cfb9HQ5ZVB3IFUliwnlUH1yUoQjovckjrAz2r8fGVkL3Olu5vm3wrZMUs66bE+tSoa76AuqEaZLy9Al6Nh7+zmH4H1U" ..
	"BG0KS+7IabRyxS1azbzurdyUwhG0WE7PyhhIEHz5QrJWsx6kBI/UbqO4lM5D0DZmi4Kgy0MgeD3g+7/yKs+lPpqLg/Z3SdlHdIN0" ..
	"2pLBvf5+QaeMApgwb0khi7jgUWAhcfw7gXt/V9hpUPLJPOJTHDYp9Vrq2E8FvhIcfg6N8b+nEPmv3bOkCd536z0/m1l3Y/7P9ZvR" ..
	"wAOJmzDLqasPffs79ra3N2yUKTFTzaes0EtmmK18bDeFIahwd4HEnqYRVtuj85rx9M2ztF+3pgzuxuLD5tQ+6lutCSH51eC8gFZX" ..
	"Xtb8z1j7m8q/9OQ3V6mOCmuWsbAC3uTb82QUcGTHB6uJI9zHyktDfnyfHuh921FkzjChwUAGaHVInhK6sZT31LGKaLNhTTDIHUZ3" ..
	"LW7FD/02t2iFtUrvNgJnAypJdliltWAzWr7WBMks7AVqO925tXiVOBwDz2i4nXT/3YL+4NBno4TL3bJ+k7v8E2qL3kjju2jx6E1U" ..
	"ngPjBuExUUmcjmvF42Yjkl96rGe91Xy3/fS/MQutd807FVaOWDsZUNj5f3k9nu787n+nDWodlFu+l67cbmdNRBNtgbuT0ZzTfD8Q" ..
	"f9dY/5HkCRBtIKIr00XF/jG+KZeeMld1JA/E1VXansfyl9pVsL+9KLDAebo+46yqc2QW9ytuDcgRQwK5FsrrKj/D5gh48gtp8jRJ" ..
	"oARf9Mka8dvUL+2ppschHl9pFsNpCBlyLGWmP9rNu63a/ZlbWv21dRMdS4WAEEjhtkhbVNwCdzKPKZ5kLWQ5FjsrTY2HlSPuwsZJ" ..
	"+QQzCSQoKtQPrJIOHTu5smBrs+Aufh0q/mOuKjQjkNMO7s3IDRygzXI745iu4oRlseRwwvjEFhjeShw7yrDj8V+z6CKVWmvXXT58" ..
	"2xmAjvq6R8j33CjEIDLScjPXeSRJAcIXqD78WyRARZaaWJ7IzNcIEgEjgQVcpoe7UvEvVFitx7TynUSFy19wnZ5t/yY7bXT5u+oM" ..
	"7nD5FakslRW3VtT2zYHHJH1m0MG9WZIXXrtHsiIPf0RH1kdUvkibddk+NYUD06dPRkrjEdBfGcltvD+HpSO/2we4JoHVo6JhSYX0" ..
	"D8pW5TLOGfJa8qVKCS+fMjf7XqR6UlKzaOQ91xyoevhuE6oAdqGt7F1qcxm6TclfeiAbTbmln/mQOjW44U9jMBFe9QwvB+UcjQbS" ..
	"VJtQ0f0luKJbcrsAqS/3K/pVDhxPPo9OYPuOmvIvGusMm5uNvLyOp4xjnGt/3BRv7HwJZbAr/R/O+bBJtVIHxujBQc+jbr7V0k2w" ..
	"Xj5mWm22ynhbw0pkKqRDGNZasYnCMFdJV+MMJ1cXWz+mWOQ8thmBHdCSU+MHIXNqgC0rKJjBavRr8GzoWzrebR5JrbgfnTRPCPy0" ..
	"/xCjY8HwW25N6WEkO6P3zPtB51RrrSx2CAsrQRo6ZRExAdn0DUVJp8bZhShvbOpBqXuQ5vwsV9WP019JICh5BaI/GngjHihlCEmT" ..
	"nw4IUQg5KNwH1s55Hf/bE4ZeFoNqDUXwY/wV4kkVdp4eBO5fmwzbllrvLTtqwBQ3q7Y0PF2ef4oagxHeNtXKXWDu6BPqfpoYgZ3X" ..
	"btC9VTQo+yJlt30Ggow+Na4TIu8LbuLoP8roNNM720fzP4NWz/XD6inv+t4jdt8Vrqq92+UJHB2P13rvPwSninVx10bEBj+Uy53w" ..
	"DJmMFOn3tX7aA5VuND702j9/qpfKHxiMkmFX7dDgA0SbDtNmN8NaW00nv7malcoIh0IqEPHtDhMUnfcZ8JjpCX5i939iORjOVgNQ" ..
	"xL5MvZg5V60C0NJpw8baRyrECfp+p8+4lTwGJpuH8qtbdP9+0cuBOIoUc9N5+hai2Vy1G6L9Bj1vcfItuVUtGVZ+n3ktMt9fNqLN" ..
	"fwcgcTELCO5u0W/BIG09f9EQaPXIB2fbO+XoT85vL/AcB1CxoAKZ45Ll0V7YgofB5Esh9em8i1UtQ+a++aTfhH1HrM/1gfIN8328" ..
	"3pvz+WXRuUfpmEKRXGTQo1NFMCnSgPM8VfGMdvjyZB7P3AIvGCLa53dzOMxkDI1c/CAov3lL/mRjus9t9I8rANB1D4WYNbh7mSc7" ..
	"ZqsP8Hi5k2gru3cK8hddb3hW7iC8/CXN5xG8VMncR6qPcp4wFPejMxHrJxPyDeT+vIGUINDyS9EMJiDnp3vE3viHO/3VY5xPge+v" ..
	"VjRdE9Fjs8viu+w+esWsvTom42tSp+6Sp5H/iHC1aauk/Lc0gGLSlQgIQYy/0y7BbUF3RQcPZIuXRWy2EsiVwSjVG7Bue7sgJEU7" ..
	"U3a8fa8yIMIN8N6a20gMHAE5YbeqV1Mx6ayIJrXe+bQ+1G3ccnMlK3THlDYjaTRDZHITw7zbRfcz4tqcRi06414h7IbgZAoHwoJe" ..
	"QCCxR8tAvNTA/XQVWhI8qZNaW7RI0RlRs6Qxnyog0/0ACD3YYS713xTv4sEHCmTq85muUAdgk0Od2UPXu6MnfetTO0bGUfLGeZbx" ..
	"aGM0wPQbOrvkcm4Q1NM3ekM1+aGQwsNTdn8SRSn8wQQJFbsrdeCTRvvms92i640+C9rvx9I1Xgvp7jfhv/MLeI05IAJzjzTl/3v7" ..
	"7qSB6dRCl39wwmQR5AMM+D5CeptVhU/gAakEq/uGIDl4ViqAraqyI7gR6dko8ir6YP6bj7+FOYBAz4Cm14pt9NRbsxpLzX1cdNjP" ..
	"8qrrj+wGtQfhEVApXfs2G4izXol3cs46Pj+ZQhoMIgpLYjK8L/dqJDO9TnPprICOIG1/CnktlL73pNufdmfxxJQnRz+o1t9lSeSp" ..
	"xHFzRKky31pScVm10lgll6qvRh6Y5tMfbCi0ilU2DlFVsxrz6HPcwDLrM1vYoMO24sJCZDzWbL1Kfdy7msKbbyChZGVQwaev9ju4" ..
	"85LuiNINybYHN71BCRb8j9EaYukSO3wRFuG+1mh4mzzbfMHiejjE4nh6FWEYBP+OnRlm0onw3Elf1hDB9A0xJ33we2CNChx2kxSc" ..
	"IPe/t0nXQ0Z07FgHPpptGD37oOtCXRGCLQWy2kvFCgRCBT0JwEjGZp3YsnDeGcBfQaY18ePL1GCd35gTwOZdnbb2I6vLjcomPafY" ..
	"T8oOSe/NX5HHrDqehT8pM+z7unAh+ieQpiD9PyaRyBEcjl+kwIersvy/dbKub3qTT54qRB5rBmhpCZ3HL+sTsS7b1F2XqJeOzNmY" ..
	"wBEBQPrPgBGpFsRTlQFe18+SOlwxFPp/JfW9XjI5bcsjNUCiSnvzENIVbhC9AxRx1rBks1Gk3doCOkoWMtdg3lpp8UIx7yC+tBVx" ..
	"2Tk3aO3az2C60vhtr0XYpncLvPa8uAvEVQulKoInzRbDPatuBCPcjeCFCpErrmPXO/kfRo4CvQ9v+NnmMkXseGxkI0WexVRrEc3L" ..
	"SJhOu7HVCM7jQrToYiVPhAuJk7rPOIgwj3u3c7WssdOiKkRbdJlIryGL+KcifZ7HK/upb0tZIUBuoRJahRn/tkUJLpWWQTPTDK6S" ..
	""
local PAYLOAD_P11 =
	"AbmhEGz3dBA7gR5+ixRTRU1ywWJzFW/XlS9Bu60ak45aFxPT2Olv5siqg+HuLjAS67j90ulF/7D9KZwCE25Tf9WZbfPiXN6wtNsh" ..
	"vpI7jYb9/QRrmDku4JarrvKpfRv6pfQ+qkbEyMgTujMnCMofkUEEDg2xxvrCdWlG0lipgWBSOUdGY0Yf9y16tLAqYYZZDrw538aG" ..
	"eixhNknhKk4Fcej147LJQ57WaSHwFzDafLfuH0kicGE8gnHt/GG48IbjoSWp4IJ/Y5MPMyFwmQ+8Gq6zBUnU8lOTzVE6h3/ehbvS" ..
	"fyanSkoU2RZht/H0Mh/ww1I0xo+jylA6SBH8vxVlDhhprWhapTlxql6EuLYgl9DhBfxGOU+YmyEkh8Ge5uDucz786t+/nQQBE2dt" ..
	"uUZqAcfCGe5RLMkPe5rW6Z8UTuR5FykslZLS2A/b0ATcKxbbeJ2urQ0zIu0P3Y9kxhKGJeNnAa4mDttYmCKWI0h0aVrK8es7rctl" ..
	"ci2qcdHK8e0PmaQSNEQQDSRhTP7EUv2GFyh4lB7akqQ/WbPznMYQzPQDTZwumossuvWghcDXQ0G5DhGt2yQsC28T0e1sOwc+WXYv" ..
	"nDt/iIZxiZnhgkzKrLkuf7Lttum3nnxoSf125mOrxSJsQa6VcOpFh34+cArzPyek7sJijQR2LI5PyHnRiZD7ariwNn4We/rOkees" ..
	"//ohiOc5DcfOQujYsmhvV42BMoPH6zsxTOOFFXtCUnnGr4kjD84b4aakK1x8/hY3qvdW7s9aRAdSxucP82u2x5zISNeqlLc6+xlo" ..
	"F4GBCOwWHWIpCpyC4drS+7woBMchTkhOKuAhyMF0BRXMth+Y6GcKpRG3agJsFKSl3NQAH/CEHxDktN+rn6bYRvhie3BJx94qgTDc" ..
	"SBJV3kIJyozxem0VPxN8Tu+TvVlGfPKJJqTmK39HRPX5aNbhSVJk8xeFpqwYWvj+IIMbt/tOH4xux8ZgIJR6oMqcd5Mp9d2dG9rT" ..
	"UvUBCJisUmEMVpKabHXJeElCbFbs3NHtzifM49oef1WE35SjCQ98RECxPeCcBy19A9qV0fsVOK6XsBsARv1vZnNSSrNip7QXBjyS" ..
	"Bvqm4yWdIHx5tmgLZl+FUdOXn11mwRkL/z3CzmOXTLm2Hs9aqDqbucHVg6t9YM568IJ7Rt09fVDh46FDxBBusrK2WeFmGxBgbKfP" ..
	"0dNwlN4HEnRofuKkvfjVk+Jhv2ObV14nqgCC0uCRLPO+MovBE1EQAaXE58TASTtuB9bUw9n/KpWsIIp9ln09GcPocMUKdU5T5Vs1" ..
	"UG0Nb/oN+JUFB5NP8iDe1lbJSMquuRwHsmDSjBAwHF36aiOtpuxK+nEHPQH6mRQh+DydNPXqkIImssb4+HlauBE3ydW4b7rALMr6" ..
	"9mgYYUWuuGtqyBxQpPYxVocSwzVKaRoxJxBYjhwJhOpVOdGEeZnZraBWfQHXy/abQKdI3VFdVHPG+iDTER3AmO3tBQNWoDqr3w0o" ..
	"lG6mfZrCBBBNzHCkbiwKuu+PsdRA5E6jGFXeWI0GAcPUsLzH5952JgpKUhJ5YPXZvYdtR0iWF/GwpobP+uQvzt1ch9fRXuyVVrCS" ..
	"uB/xBns17bYT5Grqrqa6fI5PNtW6ccUOXHFGbmHqFXQL2jMqmpbsTf403M/sQXT/u8NASa9oQdq2KFYlXI2DnzjlFclym3x3Mrpn" ..
	"Ye7vdykf0F5H6pXUlHjcYH70YyC4WUzqOejKwabUv8u5mcCogxLmV2zPxSIQ/k7sofBwB5D5gzUj62o1qCUvsdOYXidx0/pzTrPL" ..
	"PwhvsipdwGa1ExF84H1spTeRvmSRaPXj+O7QmTpUjZKqfed5qRDb66G/2eXgZ7pICXzpHKduJAA3wIk7HMC58CqV7MZU/vLvy6Bo" ..
	"Kw5xADJpYop2zgGHVLiopGmPqxyiHzSdj0P8HnBHsoY1ZvQ3hwtSXFKrPibKGoZlSmf6Cxx7Q59XQ8QodjNtz+7ozPra0pZ+gulq" ..
	"c/iYiMJt8uJaNTZvkPNKpdEz5zLpvest8cHFxhXfAAaPFJWXkP2O7PkGn7LB/ct/soLOz6B3kQS38G6gRed5vJHhGqkpdR3W1Vst" ..
	"6fC8jvZ0MoyrsR6DqSVuODQmkEf8DbARUegoKNSVd+5iu7lQUmTfKfZycmfUy3ihkZzTGJULejdxMw3noCNi18OhvyI91LGCEhVO" ..
	"3Z8RCs618yzrJGfSjITiB/dQOl+sDbfc9h9TnJ8kyJCG8EGpsIfyJkB3LCijBBi+aQV8mazkkAb2zPIX67CIzv+/bUcv3N+K+kka" ..
	"VykFag8xt9B3l7tKZeh1PGWAfCeU2VQlgE+IGbyHqUkanhzGF4Y6cexZ6uedNRkmjtp7g7V3Rx693Iz5DFz3H0QZpLA2LCoHo8KB" ..
	"8crOQEyMopcm+ZsAmiiSAIAKOp/Si/ln9/dHYdu2jpD2kR5Pk1PLEjOuWCOfAUmXYAjFTB37+H4/Ut8ThObLDxSkNCeYhqU5bN6d" ..
	"Jv1Y0xise+OSxRcFYTLYUv66DRA9RGOcV4fDq1MlEz744wM0SqdNqpEeqhIMkwRHLN3vlA5sdtAmknUqRHTaJDPlcbxALE2oedI2" ..
	"9/A23uEdzFgMxWODDgK6WIwvM9WfkNkDV2OmrBLPBSSkK3XCBXeg4LM9H8unUYlSpBKmVuQQKz8wyZtcsTFjiLtiRW4B0Nz3m8lQ" ..
	"n++Yh/N6l4EjmCv2/C0Z+ffVrx1iNpoGj12y/QbfKdtuB7SLI2l+E5qz1fIIamTS260pLHv0XMEOnhXjA2ina2E/nJ8k5Nlv5KXl" ..
	"EfzmzKoiYWm2Lxd7vRb39/ERv8iY//VkO/iAGs77hscfJMwlN9MRmEUeC1LkTayrzosC8zhlnXlAfOS9NsHxDYV6P3WzbmvBSi9b" ..
	"fyGAlddsE70QnnbTb9+bgJq+qiN2/bvGkxPIPyuxyZyvxAV1Jqcsc854d7isi735HOSTa4mFLCNLzv48rdnUkovH5DL55HP4P72J" ..
	"n+5R7xCzVrxtVZaz3TkWBI4MRP/Mw5pbj7mmuQqiBV6DBv8nF1qD8EbM2j2NP5DOeskAq7FWc5de2lzmHee0by353I/QY6fbJDdV" ..
	"kpHGtf4JWQSPN0yQmI6UB4mEt+63LdeC2MTgwuDn33hqDJsTaa7pfS00LjQWwBUQVk72DUiP+1J561gWaIn/s/S0yIqc4fRg47wF" ..
	"pZ3EEkOMsLLwlJfPRN/zznEqeE3SZ6v1gG9DyLSFK61/Wi/3hYlJJ6ycSNzJbUUL0KqMOkOHKO/MfVoqTeb5IyF6XjsjiYYqp7YK" ..
	"Uv84xqfdOmao6Nj+mublu9Q7csYy03zi93XnBL+C7HnRdWdYtMtju47y5U4KhPjAeRjhqvFgNJWjBVqM4RHQtoKoi7fWJBrptzVs" ..
	"BHRM64v/ODnlcB3ixesqKWfkWDmtJmwDaZ6qhoetdsdf8EEzpI32vaEfp14b++nUlwodY9s3sv3k0e15zN6CiHPGrjKlSawYb+de" ..
	"rqqOe9htXDAsfF9wclkcdW3AnbFl6DtCIlWe3FFZq8CINUWRRB+atOdmQLeG3J4HgS5td9nZAtRlxVOPaAW2UtdcQcxG181Zkcgq" ..
	"56VdgDH46ZUeAJ8zToXepKDPA/Bt8enopG1X4u3/rDLdZAFUpgAyfuiOGe3B9/aMAXF1Hdcna80AzjLfw8f0bflPfDQi4C8GvouA" ..
	"p7fJLgrHhpYQyMd9nwpKYgi/PDHJE7WEh4U1WDZCWVf4g7rR7QACcwY3OG7z86yQ2ufpD2EpbZ1uqDi3Z6rjq1wwqkPVIGc3++1z" ..
	"N7keulMvws0S/91+xZwl610YfGBbbXmInXcLrWILZF4HEobcHFXEwIipygMM49V1GViISkHDaYYKWvnyHwGQddV+QtD6896VjnGR" ..
	"yUJqOrQv0iTRT/MG15lPQSfMjE9Tb90f9TKG7ivLmLs6+6L5IYmao0gVJdUF/8kn2u8gwcru3SnjTtLxh4Y3UwCRHhfKCB7PiNwS" ..
	"YelLttF1gbFLIBB3BLlhYsQpOXQ3pEVEo+xYboQV7HUgDnaj5n8D93zDxd10p0y4z3VzJvrQeOWKnpAeIVgR2kAi/z+Rb9zJ+NKu" ..
	"hY3GOBgTmHVS7aKJmzUGWnQqgf1YNmbGOa1a7Cd64BrLPPbxuvOZwIbBYkp391vPT2km7t9AcFDxBRFQ9nLWWqXmDToWuB/ru1ek" ..
	"jaII+MzXvjVJ0ymc0fOwRKWqCiKoJaVQoYO8xHEBGPVwGRYES9BP4a53FvZXnEq5GhrBVRSHOFKy02zup/fGbMdHta8RTFvY0Jzw" ..
	"W68YTo+wmxX6CcsVYUg1yl3wWD1KoHIWoFJ0BtsUMFK/zJ/HP2dnkszVxeGxP6nVt3yL+Ll0WyjwnTOa6eFlYJ8KOmaDTRNdNtV3" ..
	"bd8Bov+SDaMc+daCGeeBq+RMeMc7i084jlQ5EIP9jJPx8ilVLJq6Kt1PUhRA1muHz0LLdRRpcd+TnHVNxY7fYwkTypj0fNK5//RP" ..
	"fOdUxYAF4ybg2vz+cyUmOv6f4PrqIDXg4kMRQ6r0DwA2ftftNMZiwLtoId5q8gUaSJ/uIvn0/JZxjQ6hcu8EFBj5FJJVINZjz1mF" ..
	"v4A2pWB/XoVR+S4Y25I4voae7kJjCj9kVn5fkkSlh5HN9TPZQw3Wb+112o0VAu4uyuhczgBNDlGigu3P7Y5ccIU4gOdbKJAAbZw3" ..
	"rQ3yD94zb5upJiX2krY1l1+SYzTODSO4UTMZ3uU7p3123nhUrIj8Ed7mr6M7yz5EE56TH6HRGA5uKVEQLRX3STvAEwcD5lz+kR3P" ..
	"MzWlXXNc8A/RmLzd76WO0pdU8hrh3CYyCudJlljHTo0MR+bVUjJovZzUd/zLOq7php6L1E7B92wTmrKFeZNxA0F63z9pkL+eemGA" ..
	"jwgSAOQ2xKs7T+TYjBa42IcyRFnJ6Q4e73xn0zRS3kMpA3kcOyPkvjcBo8hwFwYlWvQdRPUgqfN6htxpvZayRosU5XFaYe+3p56L" ..
	"hkWJVW0AWa45Z2PxJ731Q4rrAjvgGE07NlIaf7jX4S9Qnq0S3LHwIEemB3KXjCG9XqnTnZ1WQY1n3SdPZxusUnVF8EJJp8wyaFSM" ..
	"50m+e/RP2/ZUOmOfmoepphKbYysjEZNbbUIYGl6ZVWcaq0ibDi7vbwh5CR2ywVKDotC5m87jIUiXBTsDQQ2PqREC5PYf4b8BvU2+" ..
	"eJB0QUOgKpBlYwNSoYQFP6OJ6JUGTs5EuO1MTGEslbo9omh5vQgJYSnKY5PToLw9RfsTbEwCVjacMn2P4hnFSpyKuq88nrtac8xm" ..
	"q4+QNyn5W8r53uU8Sh8kT0Z2KigV6nJWKQQmTr01K1CHIpJ7O5Lqq1chLHdMqdLtHj8vy0r9qO6GcxPRZqV+eymUgwBAWB6JR6Jb" ..
	"niPUeH28HFXoyCoh48/EpftSpWhV04LIhkWSoqbU4ZStGpZK9uOwBUIso+L97z5ASX49VrR1AGcX72/wDcoUYbKsEtgVSazfnWMM" ..
	"iO9vtDmIljT7Gqa0UccWfaFZXs3LPRS3KXCXoiCn7GMB/BiBDBGcTaOUB72NzPRsfHQmC9lMtLHg1kcVsXWQYGnyuaXhx1yacu4f" ..
	"pa81vDlwgwDlPYuq6t5tg9cA91dplvzvf0p7V12McQKm8gN8D6XyYUJ986NiEjsfmY2Hz4xLmEBGR8uMKNjIWNyK8nnXWPz2e+PB" ..
	"LGY8DCI5J7U/vVwHDjWs/tdB0BNsvfhDniau7FkR1yy9XK+/AybQ6VOjf9YcznKCpIKa6BOTVn8AugeXFrYNlQt8J2bsOkjmfaRr" ..
	"lgQ9HdyUPtPsPrCYvh6aPZH93wUgl70c8vi/03/eEaAz/1xsgrcK73oBpq/GgZOlOpyf+8gFgrWa6rzvJiXSuMfARervKFrI5vPs" ..
	"IkxVu4Ko86SOp2r2nj5h8lPE/lfV+FuG7X8kq60vVdxyau00mqAFfzY0cdm2L8SlV3OJWfKM6E+A32ycD5BVitL9izhNr6Xuu8D2" ..
	""
local PAYLOAD_P12 =
	"cGIDhNJYlUeBdr74kB/ji1Q5sHJfcIy1gEiOOI4ZnwVhP2EoNhUeEnGKDWR8y4KKFBYlhAZsr0xpOuhFPmwF1y+lN0uzKWn+iqtB" ..
	"d7vKooFJ/Y+jCyRABSWp3th2sUuQWvVHRhjWB+iea7w2/+K0BduLAKBf7GYKdaGRwEzkDqd5tmp22qauyBvSzWdlC/Pe+DACyZg4" ..
	"lOPV72VL+q7zXgFo+qLEZ0xCJZBlxTiS96C8YvXLgGn3WPmyHyqWmtRGM2tULo3yMEHIhNgwscR/6CE4Zx2eid1ZJ/meEu/B5n00" ..
	"y23dL7gnN1U3s2M4yoB1YMy7F+sJZLdZendkSas7J0FW9dtTOWe2WJpT0gtyfq4AHJN7KZCCOdqCYl+X/Km2BPIWOM5BDg43vndW" ..
	"c+oTykplLi0kJeEL6rDt3aIVSCscz+GEkRn87YpTD+OoNkRZcqG4IxgReT13Tu5gJzn5+peZXlBbBLBxmbYtbI1GypPm1iXjECeo" ..
	"QE/bwHUl7I80j4zV88ZJRCkRDW7WPFxJwSMqpkLPpKbW6jAydMbvdW2TGPIvsz+ovrc5v2P81ppJhg/yyfbT0MPQx+Hh7rxlchkL" ..
	"Vra/qDEKnrIDmQz/JLtlhkA4iVvJS0Vqt/MQuQvvLpmEuKyMWB1WydRriD85Zd273zb7i0r4Cmdi55tvtFOxeDBRgq2yCTtT1slP" ..
	"KHlUdWxwSYcW8gohBCfuPzY9T8SwriWeDLN9APcl7u2demgEdvsfbgNP7zxSwQDRKSB2GXudR17Lev/bGRUsqqZfYSZd880jpB48" ..
	"DWFiUQHoRFqeA1amOyQxObykUkTDFIw9y5EaFyYmBsksBxfOCYUXnOoklpFGCCjqQWwgytB9f9CQ1KNcUKEYwPxjlOF7tkPuVi0V" ..
	"sWbrMNIM/7B5ozXBUaccDIwA920TNC0yfF/+tkJ4h269+5Cj67F1awVPkpRtAM576t/JLIhbv/i50GWyLOimzVOmLj16xEy43n1N" ..
	"cCSpcj7Bbt5M9eEq4SB1QUnkQHk3rV60R2P3hIesyDGkywyN9Z/xvh29qyx8kmvGk2YzDsq8UufxolpkOLl5V2WzWW+M7f0sn5/7" ..
	"p/4tFVvRAudZaTZ2ir3EehUeHHttp3pDigWI8sGmFWaKwsTJ6DqXvJKfGkWme44iBQES9G9ApxhrurkukqVC/eZIc2Ep+kqHgGLv" ..
	"YOnx2ylwA4sgpbuZNEEJX2iYTUvr9FQ8vfpyxZFka+aIZVpSXTy+IQEXDzgW9/Y6JTgPnYzJcotujH1uLzJlpdAWop+ck9TFsNrx" ..
	"M4/Ir649dCBJXGO2cxiPVvdKi+z1vWqtaNha6eB4tgbzNMapUlH8kvySDyqqWtHF9sFEkvIhHVqGUdQWDu+lAT3TPih2rR4HlQ+V" ..
	"nLjqOuZRzfZL0Nw5ca/mN7VrB3AklByaMxqbr/EgKkns1g2vtJuL1ITlCNDfvD3N/Y5vvOxTvDDizKVcgJZH5vuwg+sYS8419jay" ..
	"1nt9DNOZ4N62l2QYX/pRQSqyMLOep/3IgQFmAOSNzu7i9PCPzF3MD2ZsQfoFi+TcgV9VIqXb+ONx6SBZ4tS4z2x3kvgMLC99Ep1N" ..
	"5HJnTGHcTIW97lWGMYxamjdkhRbCBMl1JH12wRXt46fG+hA4yEzRHnYGazmYsv1xlT8/2qZby3v5JXewguFFR4n1Y3XZj/FO4kwQ" ..
	"duaMC6O8ebLZ6QSXPdWFiOC6M8bwc9C75cLOYEUTslgSl+tvsERoubwMhnSOZ70Y/e0r/ZbO7X5Qs0kO3A2iGOFjM44mtxVkWTIT" ..
	"BmOBzXwlS41l06GHPCz4ZA0A9+yygQbQlJicokIG5TNZMz6sszfAS7SWIZ6tiEfHGOp3y1o2QnG29XBSaSyET4xadaqeHPm+5lF0" ..
	"2uVCGm8AnlRnHx1h6kKNtFUPodQO9eVmFOVRybcpKa+6POUC4EVT+fFBx149ufjilSOfztIriIvuPfj7kCGfBiY3lcOeX8199rUd" ..
	"hAnYd/L1Xr2dVpGyYiof2W6BrO6PiUcTIvHElLLhMcR2c/C2JyOYf1ROOkHSzIY31gxrb6D0Z9f6nxhIV1i/OEVLRalG6go0Hn5U" ..
	"jA/nS+a2VwKiZOCtNf+Rk1DfsIqa7c2sRE7edMqfrsDwzmghP1pVWhrGBnWB+UQaZrbPN0n94ckLuL865ztFIMHr1KJKZfeFu7gj" ..
	"hXTHapqZ0tlb15nEayo1EzRAoTzRmlysJ951efNKUQ/uy+AOt4+J24I8FYVo6Kzi7tgeXgQ4sXaru5BHlCNhSy5tvTOGp0K/wHo8" ..
	"iANMxmKLZjjDkPoSJNicyuiw1tyUnFuF9QyCAxrFyg3jO5KF1kH/LTMW+nOCTXvIRXDWGeUR3RmgI2CZ/phub6XqJ8VqdU3UfMAh" ..
	"smpI3LAfQAlqTnRPJsvfKD4MpvRiwMCLv2JzhJXQ7THJaTA5UtMqA2XoNS8q3s6H0rqRzIx/G8JdPo0Ymz6wCwX63YZ6IDIf2ekf" ..
	"pxwB7rLH5s2mY0skRiE3/KHa2Wt9BJVITiYenhWisLSCoRJD3Aq/bN2wvbGIIjBcI9MYZmf5mDSglPR0jONJgcZhyHhrggsQ8sRC" ..
	"IESHuZjXTvvGaNphtcsqyIO8jbUBlooOhkJ1EJL2M42QT6XRehkhq8u2k4929U/G44Tr/xhpRV1xhNrkAZKMqzcXVQnDL3JDVqFF" ..
	"3C6lC2Wafee5pQ1zsWIZaMXhaUxsBm7dULpOzFL6w1CmPfBuQLZpDV+gova4CEke06zbrmFgamH90VTwfwo6gvVJyrz95mICkEmr" ..
	"9LCSfNXi1r8MUYkmO5ww2a0u7Pz8hct0TjVZSg6/pcj7DHh6jREbxXhhZqRuVjoQq7ADutZKnaLdt4SL4wIAuVXN7aIHhouIfJw2" ..
	"PLT9CWQpaQSkf9Fsar/FlT+LR6KbyTOiT2PZfF2owSfryIrYLLMHRrFXw/mRnbfES4ZWWkM9BJ7pLdKrCzQeBF19jNQlE+Vdmra6" ..
	"2jX+rkTFeM0s5hwli3cdXb7/R6Ero0cb6nFNYXDWPJL6SK4Z1YLBYz3AxGv7OVltnoGhtOmpm+TKXdH3tRdRhx2UL85l5CTPCcSj" ..
	"0uVXSh92b9+aAkEcctGlhcwvNEBFzfFI6uJEh7eYkO89Shyk73eX9uEBVJbeVN7cjAd1Yc9qnZhj4BlF1Twv5iLPeJZdVUm/JuYP" ..
	"755MyqMd/L9/AvgCRP4Je6+WhKENaonm8r7/+bOTWcvE7LQMyxxZzyLv/e/I+vldQhXt3qaoO7AqpJHRR4Mof0odS6Utxc22B+qp" ..
	"c6whOtUUYwDE4OTc2/plgjQhz/kT1+vUHmXtEA0s8zaL7dA+Axe+cybSrFnVUaIuuS6tbEMRCNXxfZgcDOM6nRT+c8sqKdS+Fl6y" ..
	"xQF/TjtrnXDkiythk0k61mSrprYZYauhAdyMUYWg3rPeZfhJqP0tNy8/Hk/I730wyiYXaDULmYaE/gdJ6pizZ7Z8Xicf1Edm3u86" ..
	"/VuZO2Cy3voAUdoY68kRmaJ76OcbpK1hSM+s1mEGbNUBMP4TttTPPiRoV6MiflQPrUT1BwUeuN8xQQqzDhq8KWuqmftpSLD5ikS1" ..
	"AV/bABEIF3vSqc42Pzq+/ieJfRdvbCvpztYz66eXrHI6OkhGPBtwfPu4Vjm8iVl6vN+BPN0vIQXMjo3Rny/tQHFLd+T7TptPUH99" ..
	"s3lXNPfdKCIEYrx6xa8SvOD/I6hSyKHmXMcFd01hBkBoto8NHkoy823DTekaX9xgRO/2ULlAvds+g/rFJs3M61hYf3gVjzbALAIm" ..
	"9Hp1jQZUXxEjuFwbDNRDUfAS0IpNypePPxfwfFrtHRzIN2uBQjKoiEg2tBjgOv+f0y8KI3RbOUk3Txm8bX3bRgHaTD4KmHiH1Ahd" ..
	"KKbMHsUyMqhJunevgCDKRf7NZOx82iZqjXoDFWtoVX2/NiYQsedi2QvUcCX4QMVOsSseRleAwxKpxpBKSnpXETy5VAK7ymRtzEGt" ..
	"JBUcUzYA3f9cNUHoT0QFT4u5gio4Yts98HF5t7kfGsEQF0BhpLTFfTIJpwrrXz+OqgugOBJt5mQ4eEwZ4RdXHwEEBj0JyeyNtdz9" ..
	"goXg3HuSNWavho+YYhRAreYRsKTCwyw7xRTJUrD50ZURI+DDsn3HTYuyv1lxlHXT3qLWTCcFn25uvYW0i1RnIl6+PJbFForTKYek" ..
	"EWEkiQG3hMbpSd65cJbAO07Bl+bvSF+9luM+MY6SJ0HDrBGVSjIh5nDEQrP/OBzDiHtpotmSXEpxGzujBjTJoEWwwb8QoKEvyneH" ..
	"IzQWnzGc+fQAVZwMTHv03O9MU3jB5MOyEF959olEi6+QmtXzNLRfQsufUJFSW4n6SgCh4g50qlI698zNWOtaX0f0ti0xv29Yn2kF" ..
	"X8TeGWOKlV9shjGuFoqKFLSIcw18LBFJwC+LwJ4ura8uURDAVutLe/VEEkhWv1/qo7h5mQpVOyekv+xgQH9RtbfdScEboQzdC/HG" ..
	"+lX9M4lbBRDqiEtVrpR+kLbQxQKZzQp547+jSSfhRIWu00idUjSZWexXp9VCamXhhwQzOVrUWTvZgQdfGBV5lTThLr0m9NJpQGSM" ..
	"zN42vuVNF9wNrQEUvEY0oM3NreGpitey+MV4qrgMTyRBkKAOUT94OGWWMVvCBLyTtdhsxrbL7vB9ED3WHO7/kfyNU985xTABYiwi" ..
	"f0DNZur5A7CNUFr2eKUdEdYd9GsXQ2nkEoN8mLnH/OzyyuM69QrIOw8l0ZnCLpcVi0F4D6eQ27hExTbOES1QHfurSEFlNwA/jAFX" ..
	"VCNlAiKfmdSyQjz9T35Tx2aH2duGtlDcuteAXKlEu1ahntHFs/RuL2vaJkgNiDGm/Qwe7Koteroi1bNZ03/hTpEITxOxXwIlfotb" ..
	"fyxZRue121R6j4TUhxIQAlB0nQ68ZmKyFNUbNnYKO3fbcop8b4lk1axGVtcGJsvoXaq6kguw1lPEg280mcXk8kTnYuPmmhY23Kv7" ..
	"jZ+1mEhOj2fV8aXBp3Mv59r3UkAXLRhrZoAuMztthCnPPp1rdi9pOsXoCu/h2Woib5qquujWu7ShZkDmPQYmQab5n9r6ERTn4c2S" ..
	"EDDJCYvOenMdb0QQm8pnr2upqJfsmNhK3Otr5JbRGsl7kViP9+NqZoyE9h68MadZ4YuiwhyKAziTSasQWoouGW98jsUBgXdZ3rnK" ..
	"vcxfYqgS+yRF/N2OrYav73kbBOVzub4qjyEkEps6OwqiUnvaw6CFiZgAbtPinENYWLPxvcI+7Cg8txmhrjzR6irA" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12

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
