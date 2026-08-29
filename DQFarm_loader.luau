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
	{ seed = 3622852402, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3616028452, exp = 0, plan = 0, hwid = {} },
	{ seed = 3615576897, exp = 1788089514, plan = 1, hwid = {} }
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
	"6xF14dklbIWXOD4bPAdXOYVUv3TkrqBb8DYgZzTAAVhuBJp6H8YzfHGxs0az+c5c/oEWrA5XItmcfvKef1EVPWGO5GIVw61VlICo" ..
	"ZX+BMHSqSWr1EwQN3x1ZP4qSySCl4oN224Re4hEswatRxWNOR0C4pshdDPKMgIl2/4k4AVoojcTY2e7BNVo6dtXlI3ZKlq27ECIk" ..
	"xNfh0XbZtqsOq1gEDYtLDoZog+qHwWjlPpNrCFkXb2BoQncGGECvRtFTqmO2iG6AuGW3JKVfGcerkYINsUZq2nXrNeuSgzso1ZU7" ..
	"vkPPENfWXeaxg+ltxOHneHEbKqX0Pqps8BT87ECmX1OCsL71C8cQEIiIMqpm2u5dmmEZzKXSmSp6WfCRAvBe8gbB2WSZrfWMeBA5" ..
	"6sxYo8IrillqAvNEAioxF38sKnHvJd1Mo4khnE+iy51PMcir1snyUrbAjxZi0RIFtyKY99usshey39lAbnWXU2BqKmHlpAwcb239" ..
	"vDwK9HeG9kKKMadPXo9R9DSXxyrbEBaFsI1Mq86XEJBIHQktHuaXqPzg63xQBrK9/9RQCPgR3p7xS1JsrmUkwileBQFcLZrGU4q2" ..
	"ZN3cnUqGd+DbBhhwiamjjcjD/lNOhMLKuwRqa4N4WR6T/XVIYGAJV+lwPZvdtwhxRaxFh6RsWIWgTLK9JKFwF/4MU/wnLCBoLOnr" ..
	"UCGWGTWcvRJ07BzLKPHnEU9qVOGqjYNoNeBSx9uNSLQcVebxeC9LXUmAcIjzOx4ZhvooeZstfbcnKZ14exgxUh25Vsujs7KGpRI4" ..
	"v6Fr/s5w5wtiCP5N/S40ln+G8C7mK/O78lnX3q5Cz8xTxe00DO1eru9f8gWMA1ZpmHMdOkRhRyPttyR87aJl0mOkL/4DpWmnQOs2" ..
	"aYFtgTGlXtVB8wLy4JQcDfsE9LpEEzt+OW5N8f0mHCBuASwjBwmHk/DNg4YlWZlQJspCka7sKtivHZalmUX2ZAl522Sv70jZGI3x" ..
	"K49pD99fqZd2ibU3wt7tCyHZFRVPh0TTGs+Y0Qd/EKeIlUh3rV5mwXuEzx/k6TLBBvT82iUZ4zaKBXTVoF0t7diXUIltD2wK2Q1g" ..
	"miLsN25zWQT9XtkWTZjksDkOlo55v+MNO3whp2yKOcTkHiNvnThovCqbUUIpSzej5sLhgTXFZZbKG5cFyrnzYpvT9scYFOeVIbxf" ..
	"UHZKMZUox3Lb81ucQC2K4BOgpKeGhcDjiOTYialagsCLHCaPXvtDkNshBsx/1x5/N3e4MjtIUbldd1RyPKMh/+6o3I661nuIl3Bi" ..
	"809xTztJQ+UK1Ya3COT2erAQq6OfZonMs3IsgP7LwUtfDlqyLcVI1MGO6cB9Qp35EnabviyIBGz7ODlwI2DDYnuNZp+hckst83v5" ..
	"McNVXnzmychOdVqbvLvWoIWX9FsZOOT+2p7sXbPr2+DAdohWWFbSH109rMHCi95rDPU6cQ/P3sj3SClN6itdVLajIFwFh+KBuoKv" ..
	"NS3t9E668UEz+wOO6YrfuTGLR3uzCmUKHG5dGzF9+UAhO3zCwUcP6FCU9juUz0N6o67YJbKUq3IMsfqQYKhyXScZHAB1nYrAPfDV" ..
	"FCjhtFArQ6pipx+FmbR3b2EgC3Ykrm4YUfvv8hyZP0Bo0dqe57JoNtELq1hcjCbP0JPd3qA/ZalQGiWhggtISOfuu2lt4Yq125X9" ..
	"y8pWIFzA976XhI877Y6i15RWTWsDFIcbhzidBJqUkUEEnxHDCkz7t8jsBfGJaU/N1QGRc3SpkaInitIBrvsNqa7hxR6XGASxnobF" ..
	"Sp0hj4SdPcyPbK+LibtcbcKvfKgq/ASq7kSu4TkljpydRGeBGpmnx/dWzsTrYhuCym1fzIkKLY5FiQ3rdrDISbDiIbKXqlMZbPcJ" ..
	"uUFwi+S2rajHaUMSvaF+cPWlssJNvIzgxGl0HslLY6tHGd6Qy1T4MLyiGn7uW4KTAw6mxSNknvXEHzOi3W8cWGE+Dr9L+FhAVCuS" ..
	"LVH1oM1Rp3eHgssuBj2CLDsX/S61ELTISXajdDtBUAVhc1vlseCV+wEBL1SRqY8FEmgYsp6AEZiUjufmhyv1g29PDBQoZIvccasG" ..
	"tzCnIRvAdYLF90hN12rQoyjFjykapNwp98lzUmn5ZGDErQP7IEzvVQAVXdMGAIaSmbNWkuJTVh8FiKBkPLwt1s+/vZMdVrPolfu+" ..
	"banWdGouoay1jTvuybIsgaxFNV6E9fmZvO5rowYpGbPOrGfxcHLJU6SBu6U1aVRPN8s3K/6ofNA2lr1ZpnSvIxMNVlZnsT8zcKRK" ..
	"6PkUiEO+N/X0Ub9l6A1Kh12Zmtn6uxX1nDpqXyfiuR7oJG98BZU3lCoMovAs3QJZC2LhyG9CIVkwAakmNqDODZtKOqBtHIXhBxAW" ..
	"pNBTuRZ6Kbes2VFZzIBzMW9ltqokWTgneSAH3R7Hgks7ci1suPIR5fX5Cm+2MI3Z1F/xvJ0Gg8RgMqbxQHlJrG7wfEuUr1reHXEz" ..
	"8GZPUIwCkieSQIJemQmN4DcMPQc8/8HgklRKBwqWm2D8aLhKZ/4CfQUbcGQkfT7eKeWmFKvRXUYBGXwLRYjbpJDyrv7rqRs/06ZQ" ..
	"d5Csa+Iu/6OOlKrRLohnuHBiQQEfDLjkKCiaMNcj0N/OujjJ/XrH4z/rKFPgc1jAPzbAO7YJ74BqmkXaUylOa6K+2ymdKJqvnSl6" ..
	"9dByPy2SlzoE98KbNawlQrU5Q9gl/nml0lCgIWg9er75eWwtDyt2tSA48KXHG6x45Qq+rKUokZ37eMrKLJUiyVY4P2sqyZxgOp08" ..
	"zYFdtpfcJdDqFtSKitJwbzjefaNv7UlT9EyzFbB2k8l+ru78L+1jDQsGdlB6raozLQ9R+H647Nt9EXmGpnjBuIkosxn+8ab/m1Pj" ..
	"HMz7XdpwyQYY9iBQ+hbF/FKnTJh3yFyiQ7fAsdlw9F3GNtfskqMVvI6XwUBxcEPdDl0aLr3n9yUN82Ld5H9L6bNoo/7lA+gLr0W5" ..
	"1EIUG2FuWO40tfqfsah+MOw5DDpLz9Ow6sDKTyJBFJ2Tn7su4gAODCQdz6EIS5J5vW1vYRf9vFE2Vja37qxB0YqntnVIzwjWxMBj" ..
	"n2imhYwSMNl7YPlTXoaho03HiwwSM49LVMcrlqJ+gDizkNMgVvyWEg7kn7r5e8KyerMIKmaYY8KqbWe+DRxF7+cB1G9VoezRDKUX" ..
	"Q8Nh1PTvi1hq/YVOQsih8l9gX59AA//PIbI8KTsgq03bxM9Y4gEtj1FNWsK867EvIlE6ZnasdjYXvI+5drmyaNil/24tfedDm1Rl" ..
	"JmVRhCMvRAi63PrJQawrBowUyF42QKEleEbZz0Ww4mwRE2xlNpUXgohgoEPcLYAJYgc9qeWp5/lf7zkSyOUh93NCVdAYn+CX6LRm" ..
	"vClU0Z/IombLWD6TMZY5TnO6adPZEgQ7Vnre4Kb/3Nm5JzAoaWSGsjayQyDVX4LCEaU+CFPgP9KCYyevTRvRk9Wv7FfNmMs9GkIb" ..
	"ScNoD2h7Q+aslqfNyIP2MiFTufeGKSZh3QOOyF8sqwjyKEfxrzj2iTxW891arBOq58cJGovABG2eeBsjKAXaCz5i297GxJD/o5F8" ..
	"bAD1r5FqUgsjOg6WJie5P7jTdMh4HZW05BBWVAcbw3iLm8jSrwVvzUahN3zAXBumzBVImGD+TCYmtLwV9znYZ/gIOXl+6Pt4mdn6" ..
	"zPEbSQouHYgW7wkPQXKVNoEUD71d4vnASt810Q6/UCnVL5U7xcgAFgtIqbtPgProN+NPprN5iCKCSt1SP6foPzvLdwEXSyYuh9WA" ..
	"agrUSfjlfXmXjwx9TijW6RMjvNeCbggedDsUECEDyNRyTHnV4CNhGGQ5iPWGkiQMI6fVQCJRd/W2wmwOP+JmO3521Df0d0vAIisU" ..
	"Waxnu1fDfHtO2TMq1Ir4NCfGD0DyFctdTw+No9YisvcEnf4cUqsM8w6yXjFKZA/lJ8428D4NMU5DpI0bqHKyYxlRwhQ+dNZrDfRy" ..
	"vnUsMdrubdOse/aCpT2ndbK0v87UCVq/8hHOKQJUKjprUNMSUHSUUtRQN3frEygjI9fWCIgasVWP35Wue1/7Nl7LtktEwOT2ItJt" ..
	"70Sf+cf1uu5TicnwKiF+Viing6dc3xIoGzgQoABQM9TQk0SWrE1sbyqTKaZLR01m1cJsnNDoe5YjfyKEQ0btuLDKaQzAqtZ3ZklB" ..
	"ogswCtSLLeX0AeGgOeP9z9qWE1uzzXWvdzVgJwfAjna1ufFms2Ej3PIHTQfW3hNfNt3ggS68rGpojnyP/WGCdgLfLSKcXlqJWVhL" ..
	"+PSjBQIcjs5FBqo7c2uWXHIRshNgKC6dHGspBGtk06rqptZcpnZvszy0yLHx4n7y+urRXYjtBw1t9TYt5CXmMepjJxpumNhWuPPi" ..
	"6Od+4UxVUwqA0lFQB0JNCk+GXur+Ua55yHa+1veLmuThYPpZ6eYjt6796glnH2xJS6AIkDDL0RejjlgxpjH3r53kcqqk2cMBziH/" ..
	"e73ch4cwoKJNdO/SUM/porj+vpKm/0tL8yAMblaRAhcOyvtYqfCJpLMj3X1DQaLK8PmlHukHitqpzsgM1p4hvANa2hT2i3vR/BgC" ..
	"TzZ3lcRmp6yLTx6En38SYaz5119flQ7kKKSsBiLaHnadEDSuwCMnS4+XOw3rZZLwp8AQ7IYeSxcbE3W24FmLfvtaRhgVGF2esmkT" ..
	"SHvmVG15BLy7cyurKazV7yxm9NNW3xjKxzjZj3fV86656yIsOyZNXh0NMxuy1zvJ8zuDEWXZqpsHIx7Ki+dXrMJHhcTok2dNz/pb" ..
	"+fuosrg3mPYjiRcYY8eGRtPCZm20+1SWdnOnz5HYiD1Bg+U8TgpdxnqXLrfIIpgRUN+9mBN/YYrZEWVk7K91BLZ1MFGFFZIW2h8m" ..
	"5mpTPpl93yBHOPclss9w0V7m5FdToxDtOsVfXSLP3qqVAXLWMLClUTM5FDWRjOrd38ZTthfN1YF3hiWlQW5tg0/U2Zc1E2VJThKw" ..
	"1RsIsww7jg4UJxUL2VuUniRqAoMo3VqUdfG/uX9RHdh8iroOU7QbW5lJMZIN8aJbi8XTBFadJVfDndu82bYyBn9GAVD8TaZLcQEp" ..
	"b6rV9l3TLId/yVMY2X0lNgNLBNzxIvPXH0SMGxoOgr+Qm9pbtiE24dRZ9+0Y0V+EQUciS4Hcp/lUl2+1wUPZKw7q7xHuliHJEurg" ..
	"nEG9iQCoANG5w9R7j82KeDtUOZrhAC3BFsZV0AvIqoDUCpCImx7TFCC/7BUBzUZpF9/+wFi8Gmq28jnTXpll8tAzKHcm9Pq6T7PP" ..
	"51Kr3k6toaL4xW4726LvwXGUgXu1XyJ3Nq68Gq2P5lYOJ21oj8Yki/ufa+S2qXdsFm4EapiwnAoATxNRGYK+Yrw14YRzLolQwMUw" ..
	"6rydoXJEPLfWxAh43xxDOVo/151GnM1/XiCUAoVxo4yfJdUAQuDctk/IBJCfqzBZ50HUYla77gz3PWw+bZQH09Wx7BflHU53Zxg0" ..
	"QeVJs9w0H8GqXQ2e9b9LEL2DutVwioZbtgXm60YGJG8MxNziwsWJKIw/POMuX6Y0yosez3IX70xteNSQZTUCASsO7aX9G61+Xl2l" ..
	"lj1Gn5DTR1gHEvB/5fJK20QvFJ8XQDj6KKPweVyEr2vawAiUQ77unVmyof9F651K+AkAZOZdohNISqZPQmIiy7MGOTn5E62rggef" ..
	"oKl+JQZmiG5394TaY7dZ8PqzOlhgiu04J8PWnrExQWBuP/chyB4TeByQrIarmDx4iygnea+6XyGdR+WIW5o1yPIjxJmhHTQMr6IR" ..
	"OqC7ItL4Fdrn+HEvxyu9csBoF7TZJ5FXfUJLSiNUdlRYLENio9My67qVXtWJABW2MS/v6pdPo/UBde5An3sChJArRifEjsQ/9zjT" ..
	"JrXH2e1h++p2hT7bk2pF013pTiE7icynG2pjKiPIxiDhwCfvA/esg1WUQ9ZPVfa/jzhMBmZwouZMzlPtwMhzrtKTWXjFMP5S4FoG" ..
	""
local PAYLOAD_P2 =
	"K5wo78EC2P1C2SWAU57ZrD973oZAnr1uGLpbukrmbz/b+0bCrt/RD6nXKhR2bN7lGrlJ13iC+3aspw0wNDpqrRHkq1EUSsF7hIAb" ..
	"28DIBePREYVTCjSo2Je2Xj72O7eFf7ceRyjRLUr4q266sh0EUcKUJtWs8roGXsEnKPNrrsu3XyYKOCNaioijIFSELEOUs4pG2kSj" ..
	"fDNS9bFMbheL51TNxGOis+/iIh/O7mXYqAY/7/9BmnRVQtg9buuw+DSDqvR4afXaHvnZ4j6kUVj7zVm2E2VQwjRB3p0jIzXFMs8J" ..
	"cUlhUO1fNfFmPab5v4hbkvsfxJdnDoQyk/QFanqDqHL/ty05P5R8OaDH5pgvHr5mbFXih2kiO7Ag3qowJwiT8ZktXcHMz41j1OXi" ..
	"B/Jw8GU8c31nMuAGEJI0oOavc5cdzQQbgl0Ne7yLfcYZTT0G1C+r6tJijkbSFJW24whXeB1Za9OFankeqRqJSeVK0PxakKgqMu37" ..
	"j/FyU1e4ctRt+u2XMv9D71B6HkJRcBxQGoZbL6l0I6aiF8u83NVbTDLqCNE0jomeXXIQ6USuIiKZNqnHqWFq6zO9PHLuZfNgADLm" ..
	"auM8YK3Nd8PPL7gJncXMjfpJ61Y+nKQb+mKu+xm39Pg/FBfYjJRvA1S12zgI9ALX2dJCJLJQzXndww4ws5xfSHQgLRA8Q0BwEvZl" ..
	"PnMdI9Sxptxp9p6Gi18PAarklNy0SAwhUfRVIKJYdsd2mNWU5dD/tsKutqjgvtoSFAJBmNohu7gujsf/5MhHKoLxskozgj38zj3g" ..
	"PxrWy0mAL5t4lsctezMZdlexDnOondrN7DePZ/WCEHEke+Hd1DuxWLLbVe8kwYTRwK8URL4qrRbHidA55f32LfYsO4ew0iHlY29E" ..
	"dNhRijIXPTTOho8JbmgeuNPUdeE4rTqCQqSRqM4WSHmmZnKFhDMnG8F1Yew3BSGyRwAolOrSVGX9unGsruHZgIwdw3eYlim26nBN" ..
	"e0D3Gxx7+2kVLmNQazArnL+1Y/aCZOGy8lEfJrbhJ2L4jLfkfZGDVvrPta/nC1baVKUWqB7D6DeWptau9ZNOaadmpM1qoC3UTJyA" ..
	"qC8xoaGbcxMAlkjBCct0uUUJDs9hyz2gjNz9NY2ih1uVrVDMkrVTMs8SZtBsVVvQWVZDlo2LkSIsli34AzMIdOVbUCv3T+J2RQX+" ..
	"B7E4aFvd3xNOSdDjdOSFUa2JSnMxU2tRjTGsYKKD0Rvey8dZsduklcOEBMfDbD/bCb+nRndMkCU///GhE9f4J4cEDat33ziCvfcQ" ..
	"ZO7cSEctPygQdv1RdQJ66uJzT+SieFcQAoeiNc0DV1hljllrR7PMyTy0cgczIv+I0HamIgGg8misaIalnXbXYWJWHvicPH+wum1s" ..
	"e/hjqDruIHDt/15q6KjK3Eq1WIiO7Jaj9geTXr/2O1z4f1vr0YBKzxEiLDN/X4pcIOxWcmHKDHcS62UlzOWEn431S7SYk0Pt4p5N" ..
	"Mr1ECpMbNfx8PVQvF5Di5TF4y+vM1l/PhkgkZXI+Ig+Mi/NlLJ9NMeA2XyF2OSJFMMBkPiTfX+EkYXi/AdQB/BuyYtdLmQJz1Hi3" ..
	"EaKz+3rsxKg9L5D6Mf+r6Y5j1r2D35yyIZiTWAL1uChVJ/VZuFhzorlA4Lk71k3Om/pge29NW+LAvsKRivPWHT0+UthFujUsfA4M" ..
	"9ks3et3P7GDkR+njYJZOM4xKRdIMHYJgxTeUJY2Ne5SzW64USWfwKPhj6DBbgeFFap7zj+zAq9BnGYn+RuV/LHxEECiHVSOcEsZ8" ..
	"E69SN6gIQkCgwMhGW/tAh0oZkrA6eEAb1EPVGMDQ2UaXp7HLqaRvt4cxmxKlNoz9YRpaHv+Y7epva7hHoiZiXZe4Ox6gWyn+uCjp" ..
	"09tVe+0lM80YYKSGi2zcF27LkZenmWZnad8o1iDyijH3z7f0VvfQD85yFbszLYP1THmvtO905icr2Qw1wMJRU9UJIHRKiByQCWE6" ..
	"MOx9wbPFTjSlWOYLtaoJQGXh83m5SMamkJxlk3j9INRmVVkmr94IUrbo2H8SZtrSDyJcA8gY0nw2CPoJRJl37VYuyaLOk+QNt2rX" ..
	"OOXbTvQWmRzEdvlxTX9GMYsHQ1sTnz7oL98a3IWiNJQsa7h+tnCX4ykQ9UNEbo4a5t5CSAlRwjSAatuUaMcwTI0oO/g0fUUza16+" ..
	"FWqJHUewaQAyzYZ54YdDElze5Ru0u3UX3OjTjSR4L0G/OyTtpWeIft5Lz88luCM6b77EMh4TjHB2Zlm/3FHFsI8KU6/iJ3CfGeJL" ..
	"THGnRI8yVeBD7zfl0niUWoG06Hd1xkKlsgf2SfEnyhxzcwlyErIf+qyz9cJ40HT/82yeDIK8WfNgOeD9hNEYGYXjK+ptveUuwph/" ..
	"oPKKyjZQc7oGvm9FSu+FwFVqswWW2+rydQqqB0aaqTYSH7ohrV1Rb1UaSMUSJ8TWfpqeGNnY9+/L71+SUfgZM0DEmvyETb3e8IPM" ..
	"wyYlQnyeveUzLVpnQNruv0ZUxzTy1CZzD6p1GwjFfNDdbvOFHx4x10CHEQzAUFM0tXglkVfVyGmrw2Dp1pWQ+NKTbreXzUqWSNUw" ..
	"mU2q2DjdY5edeIoZIqwziRiq69Ypjr1ksHORtpJtrSxbsUX0AKa7GXAU5ohF8Y4Y6+bf7gHxz2dbpRjFNkvYJK876dLMQ1tqhsUK" ..
	"qYjPXjuardqAMov4iZIy/EzA27aLUaa81XAj9ROd3w5yvcNuf/NBCm+PCr+Wo2nz6KJfc9xWEe8v9fzgvUGDPMNJsFXrKmMOMEIi" ..
	"e0IeQce7U1l9taGnybzgMRP413r3Hnw5GXl3VB8U3AZWuIpFV7krDpr8cm3o3CGSHkYmgjDLiwAsHaSo6OOss5CLLLpG5iKhTL7B" ..
	"orgyrOHh/Kv4lgPBFZXfB+79U1o3pIuDQ2F2puuMa4BHr9Vo37v26MekYMeGT4b8E0d2y8Ot9RUHd1Vb4gC5qjNtU7DKIc8Za8u5" ..
	"g5lzoIDMoS1XwJc2M+dtHrd/5OITMC6jjxQwpwcBAU1hNT+1xD6PiOcI2MYBCjkFHf60v+fmw1Z5YC7fBf4nHeS+DYIl/XaN+w9z" ..
	"aComMw/PH6a5/FyOIu9ZXYDxI3LpoSM0FU8OFJwUkq+H4GFpKuh4EaabIpQOl0fm0s7hQxNvCp2E5LLM9MQGrYEeq4fBRCSQd8S4" ..
	"a3NE05NJbNvRUxFM6HFcaHf1h9VUSuKjLNvaK2Aa0Mz2EpMwK8weamwWBxQ6b2f7J4H6A+ODtuPChqLCVYgs8mn/KcYs02Vok9vz" ..
	"bPkFEWJOUzRW8DxGrde65fxK4N08W9iNMjt0tkNw2VyOQSP2tC8FPndlEizXDH/p2XPaLaAPfot+/jvmc6QlmBccuO0WpHqcYbbu" ..
	"BvynHFxM5OZO2vWSK+DDUMrk+KpArGzozqLOdhUW5aSq2PElh3VUvP+FOUfmrQwii/hrroz7Rl3sXymsDqpwNrqgtM01b5U31wb9" ..
	"Af410ExRhclFSXp/B585ZnoSNufmZ3LL4jvOkjwiV0llgwdKUR9JyqV9OsJFBQkmRJk4RWPdw1cYYIGWiBvAACo9tace2wxTiJBt" ..
	"x6gsELJ7j5d2KplaoSuto3YuqcwEzRRIR6p9964bEMQk1SZo8ZJIeU26swlm2hmQC04M9lf2nfYPDMEf5NsS6bnlqBTwBjvSNb1l" ..
	"0xc40uSwdAFcuXb+017MUCQ5hk8ugDB3O0duK2GsAuv5Gy6Uxtsp40DWDWgvAYjLaKMg8tWqhXgg5rlgCPqOUAIb5CTSg5G+I/Yp" ..
	"Z05ZZWAGeXfYCzb9QTuSXmJFQB5/s9jaN24AVsF7nUMVQImEgBMf38zvRYIDbrC7ykePp/S59DsbgXiBCyOmP/9HeTYAFNxbo//C" ..
	"8fuw3E1gfzsVIo7RldPf+zcPDZalxJildIPQ5gQ1nsRH+P1DvQV9YDXdWCKTYCdA/KS040jIMd0LZ8N7pQqwgdngPmnq5gRfHyn+" ..
	"V2F1z+hRx8nKKTi2a5aqON0nKX8oGFKOQuoXOUDwYY8iZR1/fgKEG9YeeiondzTrjfCuvZ0xEBiq+1R9/AyTxXPXyzsudqJmfeb2" ..
	"ORo2o7UXfEA3EkFxj3rr1N26gHsPbNBPDtkSWRqO09g0NfO6f5DB2bM2z4fgHq6WRSm4WLcI/upg5zBsARm5IuZHVy+agAPV2ym8" ..
	"vjv5FxL2d42yBIXrXNglE0abg8EUf8RDK36GKJtG7a9UpzSlpoOy8oSoAMSClhRFxfK+XQXDN4yuRLhrPiwor2hRobmZEzUccjlb" ..
	"1c6BFMCJ1Edg3/eNsFWMTYF+dUzZG/hhgSOIgBLT/mGUtaSWBKk6s6QDO1TrQsW51fCn0VGcUKCO59RlWgpN29KzoIxZp8dtB5aI" ..
	"iJ3G3rzSmPtQE/aVAWNv3Ffn5ifQCdIJ/5Tq9Go9Wal/2o5CBfe/Qc2j93XFhhwCKxVkPPC1Cia964I/F0dftUtQVJ/B+bCAr9lb" ..
	"NDFJuS2Xe2o7ZbFHKHvdyhCbEIqKMuz+g8s7cXjJQ7Co6JIWGWbQ0S9eZRV5WlZs/kC6PJ0egkM9H5xyVC/xcQZ6fadi9KsuFOhF" ..
	"jrphGkHIGwQ5UTchsL5bl+/mwdR7HMj6qBeofazJIgWNefcCABSeSRy285vESazXtxtSV539sF0rnPhAoo+lq5RxY8VyBqNnCzzj" ..
	"iKDk9Rc3gfvkoJWRfx/arWwgc3/oDzZU5vOyRvXYCho82B9QqQ8xg39+lWrVNqTG9wIZhRz+CPiNizGsksl/jCCgRyGznragJQyd" ..
	"Vlb9NAhstoYTdDcxpHab8oepEoSDylUCxUNWrz1xKgHvTlyJ/S7Cu8nZL78Ru2p8xJHVl2xNw8U5ER3WUje5IQr1gi1SOb2Pt/Qa" ..
	"9yeomPu+QoB5jRDR4oNfHokec3l8aNbTJsZRZkziVrQ9uImqj8D17zjdCypNwEWApPlsubXROr2I2wd1ZAHLx9LHtcHnNa0m3PFv" ..
	"DquwsrRFHWPjU7ZuDJPud6UAll21p2AY22pNtLm+8X81MfvJO4d+as1H3GWk3XQk74TcLRopM9nv7B/2vVRNS0HA3ltzMo01Zpkp" ..
	"i0b8PKEfLMvQjPnBYlJiOa7ARhg45aBDheE05sO0tbshzN3LZA5XS8AlmsUB1RWlGjN7jWdtBzZ1zN3gdFNWEE9BYPQuA1FVU5RY" ..
	"/1mJt2puMBMyscQqD6RRGjjihKe8BRDgxqRziRPdq89pY9DkhKWqPIqgbWasLE8+mRiGil7krrujlgSV4E8aAMfg6UJ0Z52FIyxV" ..
	"oFfj3YmMTuXZsVsLNHRixVP5M2N7l4OSxnvuiiIyR86uU27ZNxnBQg5ecsfiHuD6klpe0lOHfrfAkWWbP9D51DFb8D48kB2PnBt2" ..
	"smWn0R0xcmFJ6MOaiqcU4huk/uRmi2rvzLyr0qz6HbFN2rhRYBT/cOuaIn4Usnffw0Hgp4qbxXJs++FrkTeK2Cr7ewSMG2Lxk+aM" ..
	"2VicQKrey0L6g8XnQ9TGYKvqQBmPXMYRKHoAYY82zAB6UtRqVI94d4PPRIOknVxAzu2XVeuTJoXW0eFZ7KBAqJ50Wgll9Oe4i7Zc" ..
	"kd9rcHBezlJLc464ykJjIl94wOgUyr0zesEgAomqKTnhe6DpudBRJkXPqj1UUPO5GaUyylzh/QVXtmnBfRFK85C+sMeyuYkBw4Ot" ..
	"9He6fIdfPtmBu2Ic/a8hbd1lnG2Mn29cZU2QWjJK9JcKElp48OyOAAls3h4wTs1xj+wiwxT1VO3k0l0O6Ru5IbBw6yuDP/+k/Wf5" ..
	"55DF+w+cBvRIK8lX4WHTcCqterX26asuHu0OiA65JzQq8jkPhWqLnSxckhnxQXYJVoegBH5EDjqbV+a+P6/LGvEi72YvdinybivU" ..
	"ch72ta8vtvMMbjFFe1X8R9MyS5+yb5/Q3tmXiREgDOyYN8GqUAiT5RJ4K+EOVcltBY55jWxxGjp/AoZQOYakHvh+R3e2MlILBbP4" ..
	""
local PAYLOAD_P3 =
	"QUi643M6dUw1hQK6WTz956GuZqnxXdlgqqKZUFBTzQ82yu8HKl/0/P3U4kHxli/qdicS9fE+vaPQNtTXFA7iwCM6ayfxJAgcK+yJ" ..
	"Zu513fXJuFeKe2NAvt5fxw3zsMX/iQKKhgv8b/IKUM0or6Ll9pht1fFt1g9hnWOoZWqwpURJ5H//S/CkEuc9GonGc1Kk3WchykXW" ..
	"rAFx/Gt1Y6WjDCkxcT9ktb0hU/T0HmfInRbpbVxtDrNL6uQPgpAC8QElROP/9SnaZ7Sumw+R53akKWe/FaQHocAytBpOHCxyeKDf" ..
	"lP1980SKHDYypye8ceNllwHenQdnHwf/3/gqfaHFtKy7sagvioZ/dfwvTFJz5qxgo/VgwhPk2dJmekryqzxLfNhM6p4Ajst59uBL" ..
	"qT8GJFQ47rGxgAwQhdC+OCYCkv4yBH4ZqFIB00nte9lAqbY62Fq9dDB7OVfu4g6mm+aoHyCCCajkOcVmORJUJprJwFc458wvGhtc" ..
	"1GxaEUday4LMdt/hnwRezhhqIsTNh1hn+Rpd3R2TIrJnfSeQmoJ+djj2xkUZKEXjj3ugS1P/nyBc0iF7RQyd77ZqetGUY3hUf6LD" ..
	"1c499+q6H+13b4GAqPtyy7Fk09WFbaZxxf7x9j3UMGrWY+URiV8eDj1fEDM8tddCOZgOwJDKYHA9W/V+hOkpwFIIWqbZ8oM/hJOb" ..
	"rxoLEi5h425lEswGuyML+b2++WsIEVuliwJ6sSjwGnrlXM+rX2ltgXkC+ZDnneI0irohSUAhnxlpwzRg5uGYXeoF6Wo2QkNFQKBz" ..
	"8Xcc91eT7eHU6XtvPKtvN/JabZdavkMa/6OInpe+w9vDLw5l+MEfhlLM24zQMZrNL5u0k0vZAMYinlFKJ1YZk55X5hIeOXt00Cc/" ..
	"vjkIlF++vLeBVJHqES6g5gf3DRcc1GB7u4iS4QeNG1ALrbB1Xp3J8y9qrGmw4Qq2EMM5PsWi3JAgAl+14rOdZZb2jgJUhzJdsfhi" ..
	"qQMsmLEhKpPYVbxmvx0XQ4owgWLfuKtPYj6SPCrYOQRnyeB7lZdl10bFnrBa5TioWknR0p+os8sO+s1aI0x97RTdySn3RlFPG+Y9" ..
	"0fs4x+BXnr/qNffoYykzNhb5RwWfshAmD8ESzP89Qv/154Z2T9D854N8gujwCH4SzGdGWjlwi8B4H338GUHvQS6+QsP8OZSart5f" ..
	"z9G46jFWxGQ+eorJAPySqtJPq4xuewV5XsLxO/AsGodC3AhXsoOYnJwngW33Zua07JNDzU5fQS4hRcYE0adsbIiA6vMOh7M0irMr" ..
	"VcyB2mr8oq7ISixGvr24W3DnnXHKcvFu7nopT9KX+hQIFmx9TsMCDeFMDa0xTi/Lwn/w7Sl2lyGzM+oi5/CA87LntPh9dOPixpfu" ..
	"/cUMuXvbc5fUPq1NYvQURhMvW1sqzfc/L8UlAWMF428Gn6rirqcQqq+psS2G4v1JMS2S1DE6kNzgPFyN0xm/iuTb+MnPobfhvuJo" ..
	"J36zsQlrArEnv0i2TTLZDmP4rmKX6dj55BGYBl4Ey6evXxu9lfMaSiFCyIsiNjAYKwtbTyehOcxuyQN5hiBwFjgB74LGc92oyV2a" ..
	"n4kIfWsA/xeY/chbR9ziYMGxlIMUzeb3XT6T9jdQ+GI6u+BV6cHJVqFk37Vd6x6muKsvpPbDGXEAyu7jWYjo0Bb/b954dckEVt4b" ..
	"EYd+XPutDLdFXjcydrMwtpFiI4XjYNasnue+qbMBywskILWeQ5Y5GHjBtKmw1d2ip+9O3zKEOkuL+U1AXo70Gg7kUyMLI/utY6O5" ..
	"pu800hh/a2+vKixGW6hMaNyF0GAteDZb2atzQXQ/oU21k+MbdGMzEsa6CCZQsLbsiOssX4LrLqat9X4OGXzaCpisuhjR1wrb89xT" ..
	"kV/VNmamIlmsJnYgALM+t62aAGC3tEytDlTq/bAW3kCXKoAhvnYAXxlwUjacHP9qagSUkrDKh7tUjf35CJeNRLXWGy7g1Q1t4NnN" ..
	"EAT++Y2fGbukkppz3/ryX9oZOYEddBtqPj1N3Yt5NSaPaLdvBdaucZXSlhxSgfVjkGCOk0jCelQJ5LLy4td63/ybkKzD+ov2oWNn" ..
	"PS/ZXk6voOJDOabx/DuaNHL67Mqok1Z6kUUya4zTtV6yUBQ08boujA78w2V6Fe1ME0iPxaF1QtJt9vVPNK3jZnU3/biqCKdNwkTi" ..
	"cIMLAKsSqEH7oBk+Ua0OBLXeAGhnK9N4x58Zpw5gM9ZcsOBaUAGeQbnpdxQfiFAlhOgmvs4ObJ/cedLADmrWcc8nowTGZQCN2kyn" ..
	"9xkpd4BHENmVnXCJ3t9bUgIawAFOekVJpiJR9E22CO4TUkbm4fXiT/gHrdqTU535wMCj2qh+/ESk2RWmcWwaq9mdWF5YiYsmRt76" ..
	"pEz2aJwEUDFSufDGl6Ty3pWDG5kg/lusBJ8wvIRu7ybaSCfbw7MlvjMGMCyNn7ODM4lDNZq7imdUgjg8HYOsm3eIH21wRwrGmL1S" ..
	"e0H96FapzcPG4do1YmoNT3HgTy4SNyPuAnvE6bj7Qbqsz8P7uGg7pqA2a9jdLOtaS4fHPs0QnlZYwDWblXa+M8FtqU0HjUOmwnB0" ..
	"j9t7ltyofN4Qhi1aiiXLEJvkUBI28uENdvwqUedD6zzD8V5bEU6rT/3lEZjV10d9+PSDpcH011qXynzxiTDYhFLNQw26H/19JhIh" ..
	"xtxBWoqDd3tFSKKM32Ma8xg26eJngY7KX2kIBFldw7n5gsrBzto5BlIrMR6NyAElTahOzJ8CXD8pOks1hGgQMiZ/pQirjHHmHbR7" ..
	"tN0rEKif9Vu+kJGm8nr9k/Lr3EgAfYNlj5dDEZWInT570Xw/Z1QRSmfXknTkCPS539GEznMwZQn6ARvX76tUm63OM1n1S8aUAnIx" ..
	"YxLAb91mcVc1ZimgTT9TDV00bQIvHuU/+IH8NPEYZdd1y41o60U4qgO5C83To2urNdSjsWKBlukv7E3agDjFBOeHsICRF9KDTouc" ..
	"BqvIMAG3qzNEuc1RME9I0CUe9dA2Uw24FgY9p7juIyLvqs21NJJrXyz3lsjAUcd0SswAnLx30VyMpE4h1HSy0FHyIdOWBGxLhxix" ..
	"y0ttXYHCbRpxl4XG47rvd9jvYwBZ4OruRsU+s8dekHL5D3IRvDeF+eHhXmi4fChNwdeKczgrAEDTHjqWkeuce9Lxse74xgeX08MB" ..
	"7Pwrfwb4W77eqeyv3vfRZlDBQ4RJNEXl+C5AbvGXCSCAIpr1s0abEFmKn86ns/wA+Mid4eSltSHYOdvccc35/5ylatBB/NPxf4F4" ..
	"ckFYnOegwKG3cOWos36QATqOEc2gv2E/ujk4oGxhXBxblCUQ/wk/GwZ6NbhnrLV5ckg+66+aKZgR75S2oUDNG3pDtJZUwxUCLJX6" ..
	"bCFlN3K138eHMkx3PsLJzgxyH/7pNg09psLEnRuu4d3YCYVmH0pyjbdH+MGEB9ZImzygIeC6Lx4kZIb4iZ/NKClNdutCw8JC25uo" ..
	"keLfSLMLz1AKaQDcZ/fDxaIN+LRyN/QBeMpZxCiKgAI9S91lXZ1rpYr4bT7xvLYNlvPmcjrb8xDYuZt4Fk4IoT0Znmw/a1Smo6Oq" ..
	"ulworT8WPsb5JxDSXSELJf1pdTqwdMOkGtBVeT5M+GNeY/RPEWNUGBAP79blpGaudebSpR0iqLsvunNPLKvxPSCLZI6sonfg7tuY" ..
	"69TYDRuIuzjAEt5UUXi6IMwdAD1aXzZEnSp+fHJYJsXfxZ3MR61qUGOFK2aNGQS1WIv173UrjnobwKUKMo2zkVP0FSs26XLZ6yWy" ..
	"SLff2CQ7dRAF9gwVvQE53bIItAMBlrFbzSFHPt1nNBtBBq822/hPonS1A/U1CDs5K3NycnhdtaHIayZEY8i5qSUhWYwDWpw89IKX" ..
	"tHC8+vaEQzwws9FvJXY5aPHtxMcoYxxrYbO/D/a8BP5qEW1O4Hh0NdG13gYnluE6Vm4kxyNhIi+eFIekJH74ket1AzX3TxOyXYJI" ..
	"2y+8t36hXgrZ7bHvJp/E4Q2+SPjky1lSBbSZyr0Xdet1mz+11K3D69DrYsaaH1D3QOuNmT5/UhAgbZY5tcjNczueFoHXQX7wuclD" ..
	"Rg8pfSkDfa0AHmOLzAlmId+E8ERIWcUuEQs0IZu2r79AtLsNw+HZzHf0i69WT0IIMa186tc2zy6Ba59iQwJgiuIngXel5yYWupF6" ..
	"L9DpESqaoDS5SYoT+QrubbmVniiSnre2lSIpuie7t8A+jwxQe36yzuVgid5Jz3/H5HY0HLLNA2Z3YTh+2u3rtBKtwn/4Ly2ixXVW" ..
	"bvc6XNIaveNP2uzHkkisj0Em38j1qdKbi2WS1fn8WyNL8y97DH3Wk+HwJPDyhQTtL88LSNVyEdo9icwc03LvGKYi3tSVx66ZHT6g" ..
	"GlzcGR1G8SHri2ev4eqTNy2UBmPgzl/hGVaMtOl6clC0O/0dJE1vj07mfGwlN2Z7AJYPLg6bI520/NT+co1tJFLIaLHljTHNF1uX" ..
	"gLzmOWhjMDedsa5WGg6RhWF2Ucqb+gt5jEOiAupB0SH/AusS052QBpmQdA7q5jT6hC9I2UbzBdpdcs8Rdejd6FOfH9t/BtVh8Z8T" ..
	"V1Hz/44u4Vf7aq4PeeQ7ygx2AUvF3vCfY7Rb8pkxHnY3HFSRPQYteKQLXIM905/6629WoPw8bO0AxnGfTKcLEUQpasIFU8UnKSjo" ..
	"EWSTy5WAx92XZQS5QchWa2MmIGIhS2AhiQwTjnelx1u65b0z34TiAvAaDgK7Cz6BsMzfK+HotgK5xSZVr4n8G76d1tIYtusbfzwV" ..
	"pOckgb4BGfc6bmgtUzecVyhjFn6g4vlvo15eGfgoEHQD5uDKOgr0y+YQVWg3Zw2vWd/bZV7HHno12OcCDp0kqMOBQTblBc81rjHl" ..
	"NayEOHcmWrm4V6EvJowv7LBkEe7iooSQX5e5YIKLwzxzylUWoQN5MJIO3XeSTrJDJrtQT22i6b1r7UTkHyw10I8wmoF/cNNptFVg" ..
	"aNC+T0KjyxwKLMuvz/hBz3Vq/XOeILar7K9NNBdTaBcPJOZmoejpAsk17+cRvswrrrfTH/kXAQ602zbcVC+VXKEcJUJFT92fxnZO" ..
	"dgh+g9DCiUV0BeV0ySQ4c0F5cXu47kW0qHcjqEvvLdeLnu5H2/OUIKKxHjRUoI/Oj158yHPPTDGwspg7ePoDf2O2fJRe2TmwvkMl" ..
	"Txv18S1iIteWV8verlvJsNMTyKYpY4dFIyYPruMNUJIhKr/m+NXsplWZAsG7Gv+A+Fng030cZf+5Ftc91rXDV5Pf3Y837RicC8aG" ..
	"+6um/ny0mOW7aJFC7aN9qPe8TejYvwiXvIxC/eNN1gYoVx97flizOYq7lUbAQdgS0hQseCWxRGZMinBFYCm+gxvSp7W2PE2z8Xy2" ..
	"sOsDxwYkWB0fAPRNO1yK/IowXUj9IWlp7V1Gnr+nO1lIqxyKGuFJfkXQaqjg6DHrSnnSoITqQNFE9T199hyFr3pnn5JnQjcb4Snx" ..
	"RaZwPf2TUhCgR/IIffw9EQffHcHtbUKzyc7tzQ1y5rEt/GBgP9u85n/sy7ve3588jnhyTzpzLx2ABOyN9pHR5/3NYVhesTmSPBQ0" ..
	"b0NhEGgY8kTvXnlMf2b//e2eyWhgYV1A729Xvf7eWnDyiJgx62z8WX9NE7+TSJbSIaePPWffzOrGOZsTZwYMGAryJqRebMZWkHnU" ..
	"BmTYZc85RYHZTSMFsg0ZH5jwtlAkOhfypIXt3PBoyo/FdsDKNw64R3VwpC7LOL646U2x+ZHytVvlfROmyH/fhQOfNX7PZqE06F7y" ..
	"5swkDR0OS0SD09dUJKPPu0rxdd/NwxdwXNVej3y6tRYK1jO3dbsV7hbcksJ9vrjIaUHH1ErW9OdR1NCBjIGseXszhPlgrjWc+L0g" ..
	"/Zjhyy20rCiVR28+RYt9MsOEVaxh5dpdPxio8xhHdVpPsUD79hdWOIRULXrvD1Uel60mjvyJE7tjomu6bWrU1fG7cNJWIiyLNDLy" ..
	""
local PAYLOAD_P4 =
	"QG4epXb4qIeBUxlRgEn3Dq9Nn81YqCP49etNh0EL0PSK8IdrY3TAL8i7yCgEjUYAF8kpLirKDAu4QrAG8yInvAp8zjpJzTu2MLAm" ..
	"kNkD3n/wpKJysEfUkXyTm8w0RgHfIsl08p6x675D22f3k2Lj9ZmN2ylQCOlzS71um5G8Xi9dnjTqlI9yWL4ImR0n4vfaM2Owvdww" ..
	"AeFm24CiaqCxiz2eBGit9h5t6JOIDa69kskL7aRqD1UY5qVdelkelArbfQCoaBnH62TRdCSMRyGzNCfDwbo2yVEVBEAhJ5gekAkD" ..
	"fRngbTrmXhP0eDoFHSPTA55+wO5GhOtPhkrCMEganXd2SV+fmV0UgRJTgjp/qXaU9DRERmm4vDePspquVnw0L1uZ3CRK9tU11r4L" ..
	"3tCKcunp1N9NizZq44bc1dhFraFhvLpWn0WDoogzqrN472Ux7riz3ahsQVU9mC6dhCcnmUJWRX5eKji+tbDwpTr3oHWbdpuoOtKe" ..
	"NJpO42E5T6a98MJanDGhf5JoQ9bNtfffAkhsep+tnVSULJEH9/3SBvugFR+TU9W1LWml8aauLrgqUBD5KUtI0hLpFIv18C2pdt7o" ..
	"61owQVBcDJwgHjzI8K9G3fFvIZzStzI2NDvnxPkkJqXGWLXWCiYyk53ayv041MI9iOFKBoXpLRmMwSdx/4Rgy/qOnx0qIHaQRchO" ..
	"6vwCbdEkiEKVtuP3lyoOFYzov24Rt4trNRvcH19LDVydO0sCw3iqrYQ2q7oLgzCDH15NV0tWQomydrABD2du+1KF1KMganBCL7A3" ..
	"AF+zOg487054DgjEW3+fkC8DZEJELPXqtF+Sin02nyKxCiGWOXT0l7d5ZmEhJ91DN8cx/Yg5qGEr/JpiTzMBpDAKpHfdGi81PNDT" ..
	"1j8Bdh39zMQUZ8ZyoJb3rWn0aTkXIj9mUdzUiEi0EvXLtuxkgxd3sBI8gXyGbC5ZjnzxmS9dFl5rJuBg0WghFvAQmxQrQh4DPZNj" ..
	"gAAX0Wl62CTNpNGOulru/yvpqWoLrGA3LpdxpJ1N0hNnRUQNIMBcMisSm7S2oDXJ9WDSutBlIAeE6VQaxua8YCAoWlwvJ7mwlkAN" ..
	"fV1PujfZ4jhqrUnCrz1qdzBl9m2TBwMqIRgP14IbO+USGErRsvl/LVUz+m5ApFhPYyXn6dB21Xh7vBhuVmdFOs6E1i3DlkjJbPu+" ..
	"7OAbSU4ycBbluG2zLh1TZrJACj3tWV2pPxi2m64bSgzS2Zq82H5tFd7Xyrtmr6eF1w2npG5EFn27G+7+amU5PmIznUwypWCjXAak" ..
	"YNk2ctn29/YzCqLeyH41vcQbmQthQ993eLFHAAF1ITzTuorFkWVyFWpcyuUgOn9P2yLAHmHsHtvzd6RFWAmyRabpuN9tNzVAHpwP" ..
	"HgBPr5jmrIROQ2eDmF12NuyjF8k+HvqRTdqJoE0QwAiXV2zwmfhXXkMww2Xz2LwnrYPgNIaiD5ANxSiBV1rRjiGf2sLZvFeKzkUk" ..
	"8u0uzWDgpqTtTeQ4gNsZkn9I2R4Zy2dzg3LJmfgs51mFF0yL3pi6hgmDrQqe+sHyVUD6+jHpPiAey1UUeQQ/0TtjU93HYIkrarFL" ..
	"Z0qR311WTUJjzbuTMdpUbXQQ8VoW1dildcp3FX/UuDWPeMoLvBacck7tJsnG0gdXx74ySGyHLcUykc6UnHhz5MJJGaWJBIbZVKv1" ..
	"rk3yyHrHPUCyuFWNFCq1ibVz6c5/LmvlMgf7nO8nst8lOgtp2R8NREIwINKigH3EE1jTsO/rSJ8PYfHhMA3z17Xq8a5hub4yvGM/" ..
	"B5JM7dcncqoAhgGvfXj7uJ8eXxYTXZZT1+5orVABTgH4itcEcuIlIGsxPqnM3k+/QNbBTmmn8SXxhoWYEYGmLJDCNe326ujQDMf/" ..
	"NUCZVwuk+0cJrD0Qw0eva7UX7Tfn3nTbEiL8YwqIM8ARR8nMKnINZkTyUEWnImHe671yGj9TvFaB+09IBSAZ694xgtiQ9dvKBnK/" ..
	"GI83cUYFmBS7FXdVgGf/ka+TUfv+A7QibtH1QfRosz3DaYNdmcVD6wjPhdkYx8UAFBCZYREj7JCvS2ulMtsaxQkaDWGzFTOUG3En" ..
	"YPhAluY0w/ugkKoV4nS/aV4owZZm/a1k+GyIXdbKlGInpU2Jtp6baizkcl/KnpS8cqi+fFQPqZPYybWOOhH3oC0wjmu1hyhep0LR" ..
	"3xkVSJCNg7n4Mau/2FRaFcCn0tSLl5Wkl7+TJeblvhbvJscWqalNVQaJGsDFUgKC1+D8fkQ3aKfAOzKq0s2/R52Uolj6yREXPXaQ" ..
	"qa0P/FXzxyK0Thc9+F33A30VueRfEXpOt9FiqatyitV9H0n/1CIC54w3QLyOnYyf/lX9H2RBZEMcT36tESapTpErlYiaRIDycaUC" ..
	"U9LXu3XpeQouRKstaNpE8RoiOVZfcZuOUggvLpX0HqJk1eP07/8FLfcEy0RooVK7RQWZGIKomamiXVWGgpWNzo9QfcU2MpnJcx72" ..
	"cK6mlYchwIyv7M37FeMSSiCjg5XnzEaNw2x0YsH91IWAbyS+dMbpmK8hsrKnaFB7Rj6dZPpdS0fJG8WAWZCgJc4Q1tv8ni9ivq0c" ..
	"efR80D81JKBiTyl0PFprv7j02C9FPvZPMi23ia0QMtmfGucpKxXfVtzLWeWJDGqWLkw3YpYuJEZmjptqA0o4jKRDAM6SXiaYJBlm" ..
	"NV9RWjRa1IH60W4p4on+pTbdiWZmL+utowdH31GBp6INby7Xk1kn+9BoulR5sNEp8uMbw0SxXyWkNRRG9IC9mlmE83RvwUQ91m0i" ..
	"9da6KRk/UapZeZzj7h8vIu2aBGaWJyVmretMVNj2WbCrkoIZulBejkWouAvE4+lAT+boIKknb+nYB8OGIahJX3u3XOEgy0z6JItb" ..
	"ZHH9fzCk+aqr1W+3c9IdY9dEvS7a0Prp6IrR2jRz/CaYZF+myDJbxCbV4GMhnC9lXeLjt68LiSNNMveh242Q0XwLFGYtM7IYVLr0" ..
	"/UbEI2mxNqiB1oI99zsaYPfTifhzUyAQ9CQrktxVspWEtBI9DujsfrCNBcCRwNTK7c3sTBO3gPiy1z8VXOW3gJHsIA+1PMIynNf/" ..
	"IfdsVKNEX8XwC9nzdzy1KZ+0utYxjUzvC8HMubJGDoRI1eBJH17WZri1UbQnGIaB2/U3rSrcfDeu1jb0JBBOB/T4nF7jETi6jppG" ..
	"MiMmiUO3PP0MAkI87PGSiEDPOzuxIdwEiicJ6xx52fXv/2txdQYSqC57/+4DqR1Uw86FHiUD0saZ6ffS62tx2ZNxi72VB/3ms0mo" ..
	"qKTyXt75q2zWUvUC4uawP75MtgRzazlmTS6iDb0vocxnMvhPJI39WhBItG+Z/AsRuNO6EmmFeX/ossZQ7JQNSEBLb+dUZRWXhLoM" ..
	"2pt/8WyshlkrLLfVg6JVhXq+iBhpBQKFej4YiaRgX2elfL/QFaqO8R33/yofp6R2wbWp/SJVoUWOzIg0BTwozKp69iCLzjzTnThY" ..
	"nCk3Oz3YxV+U0ba1cZcqDBapxuaTiA6j+owuzjnFU8ds0NjxV+mTlE5LiSkqJ7sbBKNejJR8aJTrKi8h5cTUT4iR+J4ELyqG6qRc" ..
	"Y14m1ZhwmIsn5I9X/shJExujbdGKG1s6KWwFhgTQoy7mMr/9aWM98vhvxZeJS9ODwyBLDCIMHTP45PVsC7qL5dJGFfj5vsDt44yj" ..
	"sy7x7Neb5OAoaDdmWQINgbcxlW8/hYAOZTlHIL52cGHYD3M8Rk7XwUbwU1j4zTHZd3QWlcURKR6f191m/YvSqERmck1Dp8Zda7yz" ..
	"97LOMWFZVum+cwMeq241hFLGpYPZYNi7WqbyT5Qeqwtwp+BPpC8chaVTfwCuGIKcKMcZb8dr6qwOI++9gj9/XHCkKOLagz2QJ5kO" ..
	"ezQQdW6hbxi/V+802rjt8dyBaBe3v89DwTwGdQ2dJ6DbPkBe84XdyMLRsLi3GbZClDZt++GB8ej1kURUySCBj8nZWb9U0+S6Fcct" ..
	"xEqmczAte/ilQTbnQjPiyMkGf/PExsOZQvMhAWAc0/FFr5ZA5jUPN4KJvosrope+yXBMXDBDvqaop5Lr0Css0vh2Ut/2FMV/tf7P" ..
	"PDwS4+Y1djAFLkOwJIYe31p57Qgbm7/HxG1JiU8zvp6T/svaQa+4qB+F26305ezVyIFZTcZ4iGpLh3KTA2+YQ1x8cQVOn9BLTv/3" ..
	"q/vnyroaK902xXQ+4ekPB5c8gN/JHG5FUXELBebhu0y3CMVp0DdpPpeiVBVO6BtjpiU8/a//nNoCDga9lzPh+R0DMlo1cHjGPDc9" ..
	"kt2C/sGM6xGQLdez22AS6aMfw1nkBUCS+Wvp4YZAmll3Mf96Ft1781mC8MG4DJmz8qqLnpDieWEvIosEkxntTYSaDBca/Nkpren+" ..
	"2rRzMKZrn3z7PNL9UdaLhJ5VzRc61mpf14C3IBWzq+febZA9U8rcGJzthWnwdFfmzirdRBscMAWtG140ksJmN0/5dUjYoKOvAmYD" ..
	"4gSowCX+XXxteoCYZmfXWWsp0UM1yckgRoe57zRbYnrxCQE4cJu85M040IZrUD1cId9GGsuxt6spLEOZ8xcp2lCXcoOAZrNNFymW" ..
	"gx7iMKJrJpcZkBUrCMJTIiOJxHlhHMMfZYCnWPBDG4zy5/sC+bEtJ6AcE2NELdZE7PRC68fof+KFcf5WXRP5lRQB5ApQb1vqDfBO" ..
	"A3kl2hp2RQ+AogGbQlN4FUUTW7q2O0s5vEJ7Sz6dKTxlIDiZ5SlcqcJbe4ExmZqww3ArnhsiO4p5g84U7KsEM9v9qoCSmv6Isuzt" ..
	"4Dz9zwKiFpG6rVpa94KwD/bLdC9wG4gM0AN13gFueWaFN8B+nCvMBKIhHkm/qNAwQ8b3AYkdnGVM6oafZYyYcS3it4zjugmMOsYw" ..
	"N5NzEE8Kf/obUwyVcLZbO44RPNMED0o+RyCg8D5Bj62/IvRxbvh00UuT/qHM5rOZndosbcmBB2utJlwBgXGo8tErYxIb98Z4zMlV" ..
	"rc+0h6MRuB977Zta2Z47CsWDJaGzALw/uywOKcF12eUTWmypTQpT6Ko+r+PXDwq6tc/COQGmzkIHaNRbRNaMygb7RBlMv374wY/H" ..
	"AwthkJdlPmIkUkz+xJOn2oVt4JBp2M7abcr5IBcXOS2Ybj9EIrVdW7AApymZRe20Kmq0edyEPnQY/Bd8BUPTt1TSkGQSZtVbvMNJ" ..
	"ORw9qaXgr/Wz25LZ7zCae9qKDEo/8imgvBEwk34mV7yxUx62ic06hZ9kvSC1wuDS2Y/admbQBRPg1PtPguQ3JVBLcQ6R/DR+sz8U" ..
	"3Zx9ropiK1GIboP84Y7LDmrAmTB2Xjo0quR8Atqy8J8/wPjuCUXIdUSlkctwLcB3F7u/yq+sneHuIDNTeO8BGiyLGqiP5dvLn6pO" ..
	"K0GjL1i0bE26PcIYch6BWJjXCpzrUphHs/LYX8MXNYJ6zOZku1sUSJTP0yjneSIZ0f2wo4x6xCMXhY5qzYKLpozy3TOoRdVLXNDg" ..
	"3rDhBwr5WPVirtq6QRBn0FCnvQAZ7x1e8WMUiseH2W7pgVU7HA5eYaAeuGs+RN57Sy9zuErldnwOuAd4w1DGREKZ6RNq8JultGny" ..
	"ofVyZmX2EdFfqbHtp7Tpdg7BVpTTjooyqNPJqYlW2PfcaOxdyTdDto26UzcxPfQ9O2ICv9nOoV6LXiQOhNkEnPVs6y42Rg4VmgSh" ..
	"y5HSjJJAQAdy0KIFHGZt/qeztcs9weGjU5FOL09b6r9okijSHeCmwzJcHU0kXiSDkoFRaoZOr8pfrxm1dv1mGVuY4AwvvqOetcRT" ..
	"rz+BHN/9gxShEEEw5eVLERNwPG5qIy7EMh+JVUqiKpV2PP0p7exoEUuhAIRh+V/WcUM6o+Q3hZGyMYcYwpk61iQRGZsyPZSizODB" ..
	"AYLtIgOVjWvlaRPc671cFdzwSgUKVpUSlh0kqIJ5vk0TvAQynxglLcx8/TFlPQ47818BMeSajEJoVMnFneuqmRdoyaU+13ICI4/j" ..
	""
local PAYLOAD_P5 =
	"ICM8bJGo66v20RVwe8WsSPKBDjKjPmLMF4vJ3YVeVBOm/so6SRACxnzgHmNQY7X4AcB/me3/zaeJb9+Dnbxkd1vxt7PsltbWRCjA" ..
	"wMQ2dlFCEVsqLK2kjPLoFNqCp560EoSLF994gP9fEClcrhusfcmVUZbl6GNeomoLTN9Ci9ImB7EkgybqUJQ/x27M63nzQqNtbF7y" ..
	"v52OUoYcX6sgcDdsa+CKKwSjhbpThesWxhWS+X7usOx3MUfAlBs4E/BN+Bz1ibGTDx/ZmxXVQUcht0ZJ7/fHBsBFc5Ce1XMDmMkk" ..
	"7zrPubefOuNjpGFaOk/XNiL7s1b0ZwdZeALn1h2zu9N0xe7+cFPG6cBgQ06bzMygpRBohClYzXgVztLjgp2OBC9Spo8skgp8dnGY" ..
	"gtuRheTqZOzAnxqAus+uqcTTTITB+KKdrHgtV23YLpohMWXRw1FJU2yxkd5LfmRDkOKjHjvyV4YqgJknK2QCMVkyo0RifzUPDnnU" ..
	"MoDdBAHucasnOBbiz+fRnQ9nziv2rGUImcLm6XCmkyKrck+0ps1Vufujuo1NUMosoaky1lGSkPBKXIUdPX4jMB9IaGgyk4yTd6Ta" ..
	"3BBzKvWzmcQyvrVOZNLWf2hFCpzP/dvSL5OTTapvjV6DfrmcTA0Z40fZjDc1rreR3MTjnk4P4DvYLpsNQQ4wd67t124i0O5bM7ow" ..
	"/EEXH9TmGRigzAldm+oTnlniIe4VZLgYeePBZQeuhLLQ5jMw9p41Ukuxw5rYyXEd2UBNnEoliuaREmfo/yJdiYGC1ML7dG8sc7aB" ..
	"E4HxxhuaBnaFtv0ph2R0baI6OokeejR7BiJhu3GqHrdtVVP1eG8hGfi+PBEJ0/kw0VwIc2oL6tEEX4fk93EX8AF3X0H/Fs9oj8Ju" ..
	"/4bVF9MD+4obU734Wb3c7AOkRQWoEXiwwvjuuaInJyk+6aNVG6d1ys0W6mu77iZcC4HUlg8S/NpKiXOSSuNqWr4iSL7Lvowccg7Q" ..
	"SD43sg/2U6fFQ6VhoAL4G5Utjgl9kpA/3+RufwVzLpdbEOUih2iJk3s4y14SpXSJkX20rKWAim7jaxmbwCmqIBjHMLJRem8rqnT1" ..
	"yYH/FkW/561immv3X9rWr3trQSAnmid/rTke70iUjD89BtWA8kXYp7RtKdkxdzUpN3MEzxB5PFuUPLNHTEIiOQEMekaxY97dPCB9" ..
	"WZv/TwiSlyMb36w0b4W55UvdOEAsfVUJmuUWp2BhgtcNVz6vOsJXXz+T3IaBRn1fpJV44/Bn7sYIqBTkUYJRy5MaP0OJPfIcefd8" ..
	"zmimX4jl7PcoLID7s2as0AjUwmmXyssX0SWWlp5Ni3Lm2aYHcTUwUl4vDXhtoEKUCSc6cN6+b8MLOV80XpCmUyFdfvvRKWcHXQFB" ..
	"0plHVzip7EXG8GdNCows1aLfWlx2ormqqry7/o1hAvolxTMXGSJr6D+NPemYNwRAgBYnM/EoIB8kmwbCv5X6myNT6seTzwumf+y1" ..
	"h9vYU8xnquVvoawKENhdKaM+tAV/AmPwMwNuD5nZKBkG+5SL270EJvqdb2mLMi/+OMHVSHQXhUXF2uyxqSLUHSETVNS763ksz1fi" ..
	"6qVNQbhFry6kEyqX/tHvCKdv+WFZzh8IYYuhXE25yUiELkHBhT7Xk78RTTDEyh5/hYx8zi2elv6htn5G5BdF79D10ppaxy4lJKNS" ..
	"7edb6Bkt6rh8cs9DB8oye0s8KvyzWtF0irxJ6QVRf9kmKbUse87ESvkwTacgfc8m7gwjbIDvtADNd4not0XlUUUGvhHFvlCidbaY" ..
	"ow2+A58NB5z5f/8CdN2D0gGSk4Bf/CsHJnpRwrlabqfgLt7NcFWKr8dLuHz1tTjP920NX8fqlITKwREROviRx8OKm6Wz8HvhkJih" ..
	"LtGfGiVa+5yuP0VwcgY5TUDQiyOhmMUT6ccj7P9Vf/zAMhFHmS9/9Gda5nLYliEKMQ1gUEu3AJePdID1pKJfdR2PWytXnkTd10Sp" ..
	"lE0AEF5s1t+ct4JCPIISyaetTmks1Jwj+/V9lweF2tYsSoaDBe1ZLl8ARvfnZTaScMVt3h5LLCRD2EfO7hiVXPIfebVtQl+BRHXo" ..
	"ElmBi0LMhHsTQ73KIEDYPp4XK9xferMDJcivp+qMRNyWTpd6K74NGtsnb4KntDu8Pa7+FdMDLUyf59sYlQjU9rDo7NlaSj/qpjzy" ..
	"wLzX9cxOPSNBaqZ95RUa8B+9k4NhNbGWBBhc/+Z8Qj+WLusSD8pG9oGOFftaJk62s8iaJ8Emx3v2T8sAvfG3Ujg3rlG9Oz1aEA7y" ..
	"jzNEcUXCOsGyXryIvmecDNrRMuOglX2JW239dSea/2swOEnWbsGYS0YBjjr1YMUZUnrqyVmbZ1Rhwz2Yu21dJLs1VVCEXJ9oJeST" ..
	"y79twNETh7PFCySeT/2+Q5Yf5l0PMrlUXYgvZn04STMu8g3opR0MtQjYCFxVrY7EdEnTJIFeb98jW6ET8FH+QISIfrMffG0scroL" ..
	"8/e11NPJVEQvVamksR8Bv/NFGMW5mLCvU13Ebz2OUkKyBzhhcMgCBlxDUNnexmkVmU5TH2CTvk+o3rCjMi/GoSH+GBXsew9yZ09/" ..
	"3p1sGMP49hGJ3H4haIRyAWRxn/6Kas3UP/EIVBJ9GzQSk9CQhmI+6A/yRUt1q+xVPWT5E6Y5Q0ZapXzF7MoFBw09BGIc46i/vL4N" ..
	"H6C7IKYwRYsnwu6CPaGfw/Axl4+WWC8u8XAbkFlJBGkOSZg5eMYHy1u7hCkaR7aunXz/etpWXMVcc/pmaTcOy487P2P41nK4573t" ..
	"FyYHu/gsCalJd+PoELGVGJNSrV/sMD68xHEUM1wZOVRWRuyg8EW9gOjGEheF+ct5mtu8FGAmgAL6D3+JbLLP6/8+uBH5E/Y17H0x" ..
	"GlAA7QtXBKmpVUqwXdhMDD0zrFBvGeT2N9md7J2qQWjbuUp9kakN+ip2QywxEbQU1ZzOFwDhkFZP7YXxycG+low/TUvx7j9gZS9E" ..
	"wooNn7rMZc4XrNM0MTE8UnQ/rOMVH36bmwCz6Q5mOSSnJ0TmdpozQeMEHlIOv/HwU8QL3kD5f3sj49psmF8gPBTlLJA1sBWqI5eI" ..
	"ALViMlVfc1p+o9T6d6cGSgTXR0YyuD+7204Qd9EknNmF9gqY5JeoIKjesxbnKXT9HA/PT5hY2B7yCy94V8+Y5z16i57BP+sC1Wab" ..
	"XpgkhowVvPxuYlXEoI4V8rG/Cj378Q+v+Sq9repi07SoEgGV5LCwUZreGm2aPiayScbVvO9LZvvvuuGNZ3jtzFZ2yB0P1cwndFc8" ..
	"DXrPdWTa/7ywuddyzFtJGP3ZRws0Ho7Y9uUDrqxWQF2fCDNIvYssk/2pQi/tEbfEjocIXWbEkQdS6SLFQPEZvxqa2e85bo4VuBep" ..
	"FkiNAB3N4hmv2hg/Wgcm9/yZzXf8O4J1987hHqJ0Kfo65EJgIk4DHjV4lG0gfD3tl/Ka7nScc92hrkR03XKxmdv85LL7U7r5YDsU" ..
	"DUHO6oFEfGh6Nz4LvwdAxanQL9v/dIwKLMvyta6wbUp6jy3sRMQQN6HCFDHR4uKhufQAA9QTwfwYuOBLPUZHzJirHjVLsvMke94g" ..
	"vP3BSgHeXRJGqzeVyg+pSNkVAe/xcESz+RBFM5YyT+D8T2qdlIpf1OI/2b+MFIoApAE1es7WTtm7rnbjRep8fXWDV1c20IkKXERx" ..
	"O4xd4FFQ4bFqEuCdhzyMCQ/ES4BqmXNpMMKqmWQ0K/+Byh8hb9Fu+NZr1Szmuka4Otbv7Nsb/5eNtX0Owi9VVLTIhv1amG6lZ5Rx" ..
	"Vqt2A+IcY+w71RXb+PcV5R9rDTr9hntcMyR3ahCFBmlSxIwRhQ4l0dyr/c9Qom4EpnWFzTo1F4VUJkB/t1pcjYYnX+hHo/5hgx7f" ..
	"PaGZxlR5LbnOQRCz9BkrUSvMr12Eg01DviCakfwvFtVS0nfW1XxHNY26VzXyKZqQK+w9XZYhrskXPfWLY4xT2fY9j5qCl2veZR+m" ..
	"JCaPEwJGnnQKrsw7tfiPVyXm5wGZAGvbe+C3pgiUEWY5iyxaiPXZfKl6eeMomqjWU37M52RwM93hdXkZ1id/WaRISTTjIa/o0Q4p" ..
	"VvglVZrOyTYmONxR0h9CQWhKP4fCsEaAO+fAmt/WqIgHywZSAHdH3VY8fv8ERT0JdsTU8nQpALcAMRMmhUn5O6R4GZGu+YcYhRmC" ..
	"z8xhfFRnxHVOBH1FcaYb7eW53zy3kLuBbIlskn5EvGvOwGsXbi/fCb7cc+BVGkiKknqjDx9pNB+Su9mDpLI8gLguht7OUg10UGKS" ..
	"olf1Z8NvRRh6OX7KQh4XDq1JHoo+ac/vDQosF9cSipwDwFFIJRSjler69WzXAGIE4eeYORgzngDTw/yYFa052Ch9F0ugQzKv9xri" ..
	"mEG0edHKNqhLXJeYP63+sT7Ml0yY+sapMyD5yec8fNCin4Yk781L8JdRU+DPDlhKKjHXnCqcQRQ0VrQmF6+mzzWDwLQ7eJjC3hRe" ..
	"+Ui552qV1Mg81yFbA0/aFGB7YD1Y67JgWPwzwQpZoAuA+IRpuDIE8Azmi+msBRkmPtjVteS5Q9CwIFZkQT+xMdv+5267qcKwBsJA" ..
	"6lmXwbONjyGBN3zaelP9XPZiAAUxlkRk4bZAZgSjuAsJTpf4Su0mBmaw80XwGWAvK46PoPChjK7daJKgFt20sCdvwha8jOWMMFiP" ..
	"HA0IsBk8CpE7j5gppKScHTJuXnzD8K0m6ZppPF7JziN4+Ji5J/iSPEdS4w7OyWGPiRvv2yelwriit3cVb7HcmutfWq/VDvFiVnAh" ..
	"uOUlrljPanpuiepacZDCtzm12QhNmOxq8x5i3RGCLda0Z/euUWNXkcAfh0k/SzG9C4sdrqAQ/ie6pyuMeTYD1fMOCbfKmcH27aIr" ..
	"1r2IdudMqWGf19QMhfGODjP/Idv0ZYKMBvD7AyO5YV67mON0wtoEBhk+fVPNYJusVeo6AYCZ4v8AAtLaz/EvX2uJdkkdb/7pc3W7" ..
	"9SpQKhkBfRVY0dD91LPsF8yDm7jo6TrS+3tgx7FHSD04CYc9+X1gJLobYD0Dh/EezQVr4YtJ4k5Td5mHvmlOIus9ThNXpctKXfdf" ..
	"DPhJW++xdCB0ss8/v6m61p8rPe6VNWbK/boKay2sRU2uDhoNdljYL5+mIsKB7rGechvcYkh8FYlSfPiG8/zQN5UAtDYRaw9FxmId" ..
	"HiOCqTKIpcjhPj3qqm9X0C1InUyIqxCmc5Hnfwb7FRnPr3YLYlRyWMmqYUOmF6DaCM6k9MCVKHqZbaj4qCOURN1jmsVT/I3OTSKF" ..
	"Y7ILSKZQ8x1817Ahhjo+mHJTsLurQpGva5J/2e4smy9x7jsE8sO6f7jgAgbcAkg3YU4sQcICOEC+gvmvdgrdkLAFZUbFhe82DLyu" ..
	"Q2oUxEb+KXxlkCzit6F6ORhDvN+78Aszq6QNZM1YhUDODlCRXCye7lXbw0zUu1XVqNwG24ubYbwYtyFlIDdDu1qGdrZtN7GW0pLd" ..
	"UlwmgWaT4j49PaCLwPwfd6lunavWhCk24IgSmDjGfKvTdssJ/QTNZPxWWGnUVIBK9IQ5OLHBlpD6FwXHTGwoCCJKNJ7zyZnjdP+v" ..
	"G58aRnWGd9Z9TTxGVj+/sCDFgci4pQ6heQGOAZVmHsbwjNGKCmnaPN+UuHYSLoVnHSOefadqpHU/7itBEA36kyS9PKBIdoc0ab5a" ..
	"U1kFlvlt5WDfPgeDEyTSfjWH7Q8sAwj0H9tRrYB5URE7vXd5P0Vjg6Bl5WbksBGQa1EMy2s5JjnrVHNvfGPwqSS/UzsOCPrOyoXC" ..
	"eTjXNF6VQ33WYDHkSje6zJ/NTt+IgzFfRtVFPS5Pvx9BqU7zv39EgzxVJpXh0wVIVKhDlcvLjE5hkXRzgl29SwY9eW0Esic5XUM4" ..
	"EtrgekkzDrUxZlOxCd77WHPpI0GHsy6GXcB85vjbuhdMWTt9LZjcd5Gmx+QMWv+60W/ylynUZATswJR3tp3kJ+RR4BhKnHUKWhBF" ..
	""
local PAYLOAD_P6 =
	"tnOWkaadPjbVZVKeBEuXEx846JXRXVaFhAZmZXN97Hrs+EerrqTn7oscyBENPTEv4yLHvXmj8Epkzv0WwxVo/bVK9WXI8wvihY0+" ..
	"pdA4OCHtSJBEEd6edDjoPFu3d/LvMtOLGBRb3XNBObrANJ5kgjhVjstTFBG0WeFV2tzPbVcbtLSSiUTRFthMXSkfQHsKiOFqLsnm" ..
	"6VNvh2IMTISmOwe5mLlygQoB+1UngEQjh3htF4j9KUk9Rb3iNEc6m6rZp78+qj9+OQsIDGQPbqUXRMGTi8k1R+gZKJyj66urUHtn" ..
	"31hC5xrNhqHqMe+5HvrQ835rGWRJ6RQRTc9ax+P++C6FVpF5e3GiV2P9cxjlC91nmvfjTWTWPeE3Xyzcvp3rXeS5oFzzNPcuO7iF" ..
	"gGZmgPS+MXLvHvW8tVhwnlOxErjC85SkMmo+pKacOk42YCWuTE8KJL/SzshlFPFIacw1jNVCWH2JHPljpuo/w/77muf9ScufAaJH" ..
	"ZvhI/uj0DICHY7CIiny5ivOOWpbNWQRDmuV4IjTqE+P5xAzp/MqjVLiBxtHsK7a8jJ/R0/hiuoX1gG9ChW+5ytZ+PZ5v9Yn3ofwI" ..
	"Rrcd0tOUtbDU7CDgxAlKurUTNDDVkqPqHHSphMytZ1GS5ZzFRH4OlNR7jv0ALzjyoomQwuSvY3I3b5tZrdPPgGqflLFTg7DJmniX" ..
	"N6Jhe/6UCwDtk1+A/S7edihCp5w+aQCm9UcvtfNMlshNAlZTQFyqh39Xxn0H2QUmH7V3NeM29YA6Dg85UQuaS2dRmpTO90iS3m1u" ..
	"vw831JrQH1ad5lfe54z9WoprVfF0ignUBBkN8/CCXwW4f5+2j7QXKMWQk5X1voRo/ds0hgajOANvtS6eSAQYtGnZSEaud0lvtZRS" ..
	"1k6dmvfBuJbajkMu+/k89dpLiSFTllv0cBJUPn6dVxyNkaaYstLQjdEdmCzk4OPin84WGAFWiFIu9f9s+a4pfE2g0mHBsdy+LSvR" ..
	"67Tc1L+9DlSlXC9Sg2QOy5QoXvEZktt1nBWSo1ObGiMxM3uWguNIYvb/hS5LDKpYBWch1eKFFX+BsHFFHxTneIGRP0HWNynLIP75" ..
	"Drfgwjs/XtW9ohleO09x05Smm4+GPlEQWZ9GQq2wv+ljignW0vC8YrszgJjB5Ex2KB15U1FfremVq7HKntUWfKSdEdGPs6DXVE9f" ..
	"bHIEB0t5x4SlfJ7vylJn7cPn2NNgAn+cTmu4tivP0MbVORVqXiwNGHLT/pBZg2Fxrv/Jk6ITEn6TLdX00MhIyCKjjtSQgB1Kl9pz" ..
	"yXfViSyDoZG5BdSz7641sqFV8H7KaUHtakkuiaZbklWcUiHMYVFx6AFnlvup+8J3r53eAL32Tq99ZDxM7uXvXUJ/Wu2kZDSVgv/G" ..
	"YNeRA8shRR8lBz09Xh6mBlYWeE5HH+SMgy/BrOMnDWHkLKXOGsYUpTakrbyH+ydiVS1jUzid/ozqFs7AerKpBKAL5sUocCq/kuiI" ..
	"x5pNpItI96e1yARESaH9pBdLKq5qAhxiuo2IYwe0XblUTh6H0sSaxOLr0VbGgXrprBtL+kjQ4Yqf2PyGz0KoS8rTd+PqgptIr3dw" ..
	"44Io/nROgjJ95vo+uw+M5paJNgXVb4cgOkKrU7E+OgfubzAxVjWuMYNXj6/P7iBcRnEZx3P791XwgAOsDrjm2jAAhBn64lIMq3Ad" ..
	"sn37z3igZiwDFuJjTmmxNtRWIXR+MAnCu0ZNJjoVkNANAN+1hXL7IVTGkdkwV5flRC7bT3uFTZTspGXxLc7yy6MJ7+PkggdJQdW7" ..
	"pmAX5ZTA22EiXhP/SsXl6uGin4hAsC9wAQI4t5CTq8sq7DZ9wKtPnHdrU6Ya0rD005p16VMqzZh+tfVcOho+0aPpfB2285EBcaP5" ..
	"84Wo9SeOqiDeIwDPWMUR/W3v9DZkESbKN4n0pwx9VNVLYgvVKR0glDAPUz376Gm4s2jMFAegNX5n6pFN4w8ucX3kQHWhB/L5mkbO" ..
	"HP/ViWkuYNtmtsm+upnhsV6/H6L2jfurqv706RPouOrESxyIpjy4eC/bTY/vOVULHQQwbha/+bJyTnZq6v2DvQIacU8/9gyOF4B9" ..
	"pa4FWKVK5GmJH3H0K+FGae+D310cGmFpp9/fMsvdV8tZ2WO4/FIdBAHqXu31EYfRT7TtLym/uQ+SjpYBiGi4DUXQTg0kKUFuHs41" ..
	"LSIUrq5HI/yGY8r20DNgYQfKsQXmOwZLivQyiOa/PROydAMXkFrJmliHH+64j1BMfzu+jIXtxC2Fy6Tx7fRkaeYFh4kOxS6GTYpM" ..
	"wOCWfCz+uvl8N6RXIi8W6N6EyEum6WnfKICNeLTDR7ihMFL74ODtAFA1BlA0yrZZN/FRvjpae9dqF7q6kpR9DbCfz5hS8Q9p0foA" ..
	"zO/OEpVLz+wI91yTCoL/1x7UwJEtZ/c4QdC7Ew+UMZk+H7Necnlqw3zWaBoCsQPpEBJgGMs4Slecgn/lp2GEhtzFMJeotqA50BFr" ..
	"JteSJYajSR+su2C2627DAYa2t8f0hCVln1pZ9wn2QyrrcT2NpSqvH92exv8FyL0FxqXVNEcz1YIEgs+UPk7iQlF1MiCcWeE4MU2S" ..
	"xTR1ISrCtzWraIlRBnKtEwQdTKufMjCRHGQe1dV2c74Q/7+GJD2ngtvEdmtX6s2EBhv6sYQC/eBT/0TGgBiW2KNimPXw7N94h4DL" ..
	"2t7pRyJdjYvCbGN+Y0TTUQ+N3ThdrItllunaXpIwRg1WHrPf8EZIyozH9sqcto6Fr1iLBGSKoC77Nx7Z1GhKhcSeO73YVu1v4Vof" ..
	"Jeu2ddoqj27RqWvCPutSeBMDizduVdTEWeQgy9VhmdC94715CBICkhFjtydpvyw1WWX+nRRjmv2rcXsyAKGFUfJhUS+ecyY43uP3" ..
	"7g7RmZ/7jkL37t9hgELGvrb5KYnlTVM69fO2q8F14hMx3jZytsk+C+i+EhLutXLeTxb0oM7P3xcKOwj4DN27alOI8z8TVKxgHyJA" ..
	"zsG7IBBHF255dh9UCmcq+2yMU4zuzPZB09h4jqsugZtDSVC46LYeJ/zDwTV0QTgFyJGdVIU/KjA4cu7M+FCFrRYRd4DKlJRkmjp8" ..
	"OZ5BGrtb3CrxbmSTf9GixwgCs1P7Ioh8is9zFT8heK7I9G5tJyOpPWLW+L8GkNkWZ4vun9LP1NXdQoz2xpY7ys+mrANwO8+kAn6R" ..
	"Jjm1wUxfiNJPMZnNvDoiX6kFjUuaIjGRoBn0eOQNeVvItOwfYuNChbrGPLOOAzBQWth1VfXqEaV+vVWghP2XB5NenhuSxlagiWPU" ..
	"LRyqRkzfBcjZDpJyXTYkm61altk8aVjBBzLh33BbwXSEB81LfCAMUGwU2dGy4YMAvyC+Vwb6QJfaZkhJRcvWHRJFhO0KawJ1nLOh" ..
	"8e7x+SUjiJAcph1/uov45ZoF48JUhMA2WQa/+f47BWNsc/5qjDlrKvt0eyaqUds8Cfzpru5YUxb4ZAILWWedR6WXm4N6WpivqJej" ..
	"K9O4OQlUst4wwsIOVaFIfpMTsS2hv3bEY+grSfp62KXwmL34DIbPervABEtYt3Y4XoEC3OsCy0/gt7SZmKgokDIaQFLjm3DBCQCS" ..
	"kXx6U6WPqO9CjjY0QA6eqtmcWFYHQUIhrwCu+xa6mdoE3yXRciu5/LzVF3eW1IQvjulXIKuCpJ3xyTi3faArQhpaflO35+HsJcux" ..
	"vqoDLmTL5kPyFuSaPr6DyRHRCmFxoD0sK+uxB3KVHg4yfFhTDpSHcniT4ZmJ4CO9XNz4YooiX/Vv3gTgzsVcL8RyZFS6ENRJ+U86" ..
	"Hzba8yYnABxEH1TeySZqEFrH+A24oc2jPhrkYZ9kkYRIM8ZyJf+1Yb6muLRctbal45Cr0Pxnf8ke2qwOG/ymAU1CBPZjYDMJsJ11" ..
	"0g7f/ggzbR6sImPd3By1ncezC8Vj70P4TbWyUm4WJcVRVHGRFhNCcwHaeKVsJ+tH/q+hKu7Aos94iOQB2+TSMmegCXyqJwP092Ek" ..
	"ZlhooT6iRHA7s5zc6KI/9B2RpzZrkhQIt9R1grm0jUjoXrKvNSkENP9dwomRadpTPjPnKyVqBjSswiRHmi2cwJECwX5yA6lV4McW" ..
	"aQlAx0MtLvCN2OGQ1TzgQ4VxaG43j0IOPrEUsguk+8C6hLv+ZEBThP4Jg1p7Rwa1RKoPC28PVse7hgsEqfOyntWjtN5dUA26jzly" ..
	"LYOtTA9uHepQoxH91Wwxej8BMZHzEGIbhbV0N5fo0ZNjl2N1qN3ldnurDUrIQrOkA0UT58vBqbiIKF8vIJaRDSXdKzh1IixLSc5/" ..
	"mcXcJE7zJBuSHLD9unn0ZaEVU6fEXqJbzN0y4DP82g0DN+g0yCaLotoOc8tNIc6/nZqG8LzWzuU1fRGmjgrenX4hGTIoNFmJzODr" ..
	"bl6qZKvUxIZa9CiNCcWW6pDFfmyvlFbW+ZQFQ09PfwIKDbGoQp9FDsHRC4k0BpbX3OXDd3V5Ef9zCt1S5CuwwMa9HCZ8W0UB/4OB" ..
	"cE3kaonX8SU6w9J79A/oXuUpZ23BDiGp3hb/jkpjzCYco+aSHnLa6OBK4Gp1rDQaJHyrdnEdXTjaEXfwg7svMQs9Puv8x1V0fIG0" ..
	"bB36nfEudPNe+cPcDuVNBJc0lXCZd1Sv/r+h+Y9IE9spW1R8wQVLULv91Lb9TnOYQEVVEMWi2TlUHSNist/oqStGM06of9Ed/ZeM" ..
	"RynAltVcpWIAmue9lMmxrV89ma9Y//QU3zuPQlUMiazLFpeQUmL0UCNwk84YITmM070VjXFTZeL2+rJ6GnYrXz4g/8Zu7MyyilKm" ..
	"fqpwhyxQJsYUh+k+jMGcXubF5V8j/UctAqiXMq4y5fbG3EcJ2Vl8HAgedP5CKOr8Gr/87PuLwmpD0n2HnpuU+DgSUQBz6umBFoQP" ..
	"sHCycXcwe+7QwuXfqywfcAV/gzKsN2x1HaJUP9T6pyzXw6A8wSe38s2xb80/++Q/09lZAOsSOmds2Enapg+5YhKh2/0tIoPqmzp6" ..
	"U1gFH0v3xKUUNriqT/xPmWl+MSMwrzoEKVfZJ4GORnAo59XO4Ge1W66PiyTHfG7F3Ordxk4ogr71Wk/yLMVUOJ0sMsXM8oKt+BWz" ..
	"3sbNvIYqXhx+s3jrqwWTx/nyzIm8oMM+R4t9cxXuh3ydt9nPL588eM7BS/s58F8Ss9eKAUtJnDelDZu92icpQp7xghDefF5V9MrZ" ..
	"FNapRSIjOWGEi5A6726hxZyDyrV6WtHGa4OoWI5HxANh2wHUTxS1EG/yJB0ndbkSQZN/owBi5ZgwMj3BtWLK1ceVbc3ES4ucEa7Z" ..
	"gthXgcMEz9B5TkUi9B83wkR9cZ1cg8aOUmdpowAuZyi5Hw+ojrNiEbK5PLIWFJGZN+zCREpQR2lo4qf7/hUsgzVp0wLSriRD1mY7" ..
	"xK4UK5jZEnp7fu+TQuf1NWCxf0jfSza3ZZCkop9dI6zi/DUiOJiSfVySH9dTmyUWHLPQxHmbzya5mMrBvV4q29JvNaz8DuCoc2QC" ..
	"7S26yl7xNedP7AI/fx01lCYlxvpoQkv23zW/qvpIHwd5gdknqgfXdAS7G5s4IeJC9X3NBlV6OX72icvZxFznvuVLMIwAyQwcOJmw" ..
	"YPdxklotOcGY+uQIPQYbxyb1gXgBnHX0BgpuIl8dc0GjzbX3c6d6YKF5WJT0nKUwN3TEOliJ3h0IDM1nQygrWkpuxu4R06XBEbZJ" ..
	"evp6F+xJFJOuHjFS7+A8i88fUDoGsjmfMHiTMKoKiqBA/g8atVFnWbDaRrUcncTBY7HwER0ocKtS/t4iSZVnV2J+XCi4Lw+rWY0a" ..
	"/04xidGfYAEir0Pt4Uk24yTmoiZswOkRCI6zgLBSN/U5oKuYmZWrplgAtTjllr9rf+77IuxzZN9tv4121SCkwW0SuP0BelfchZAA" ..
	"EggqJY+VLMHr1prkiJyO574vZzArYhQNBJvVfUp00tK+Vc8Ue5F/ef6J2TaKdtrKa6eCbr5f7akJ9GSm2553/Ttcm4FA6vCv1KCN" ..
	""
local PAYLOAD_P7 =
	"g0mOl5jkrXgMmuJUh5KIw47vF3Z0M00Y8IhSacjKb89M6TwjEDOSZ35DRCC5SUogD8NtmDN3j8dAytO0hlqz+s6YanF64QrF9J4w" ..
	"85tcxZ1gWZOMxYoJ1S/CcAjO3Gj9UYEpA/bWSQR0CslbDVz2w4IBPjHg1fp6YXkFfWd2j9Mk4B3CGGmz83NRKZNsG/qbSsYZ3X6w" ..
	"Mj+eZTz1dyP7Y1+RXhK+Jdts7BYX2lB1EQi/7YSJaHD49eMIUln4s16wLefa+V+BtScL3SnIOCGj8s7aOlBkv2J3iEnq2iFR7vYV" ..
	"XqCTMvo6gDQ/xZazADcKZ27Xn9BW40JSBxKhYkerncZ+sIdC4vmlEeys+WXkqk4NDNTMgtm7A/mTFbYc+rWfJvZNwFQ9DpeQLVkC" ..
	"9t8aNV4GQo+KcDLfFTkDD8GEpccpeAhM4d+d8BlBrpxhvbOyBuJeBd2JqDQcDDSkK0gGG09qgU6a0sumdwYdtzscjCBd56yO1rrr" ..
	"/rsec7eUgasx3Xgkuvp1Oxq6iTPmFFLlwUb1UR+P1UoOQYmbue45YES3tJqpzbd7neTsiKri3P6VCZvrDG1rKYLt6wPgu9WPJVK8" ..
	"t/3BSgIgd42DbHZ6xF8f7SGUEhQpIdRhsRvfCgnTRZjpPQlFPpVCecVmh4yUvP8ombXKXCAxdLDd8dnWuP3zG1eekdIlpn7/8ARB" ..
	"m4JD9RjNcuvc6vCiTSXAONYZ3UfukEcbRcbRulwv4VI3opWDM0jXEdKA8ZVgO7PkbW+1qOhTXqE8bY4Fz31psdAeE4J7PJUhmzwm" ..
	"fAs0mINXZGY06cmPEcXNZV3qSvUjTHI6qzXAHvqNDCBSd+1t94FvIvTb3qBVB3wqtsWwdHRCkgR/YQMhjLUZlupzYDAv1VXWomzK" ..
	"P35JJn5lUBM0MoPOmQsSNJzi+aHdai9i4mmUkt4ZjTRzy/rHU7O8vn03xkRHHM2CIzEfwrI5Ze8nMEW0Jk8YQ+Z8RIScxtgGmuTM" ..
	"MmL02TrbO0f/Sauy3UVDJ4+aSgZVLNpH+NXAekBbDJDQ9RWBD3V0yZ4ViVX+eyIII5D6AVg9lWivTuPTJEtEbaj9lBcjvlPH1WDl" ..
	"rE5HD6YI5dUjAvZxnBVbsF7uQ508LHegC07JMqMdS69xvSRf3fpuW1eUaABHLyPLxfhILWCRqHTuLbKSyTJr1h8iar91in9jJiKm" ..
	"VgOV62+wbgE5pwzq0sAhLcrGH5W6SA2PdQRfQ4vehOKsUxuS53woaYljRPwy1UdOs/lb4ej0noDOP+XgqKgGtb7jytu57UtTTRiR" ..
	"DbWkiXJEnYYoaKULe5gEGtbse64EoH+4fiziX69HgYIHCXRIiLBlEGQPAtFa79qD7BRmLni4w5WcTInI+1CLtd4p4QFM8H9sCMEF" ..
	"QQd3CXFbOifvAj7AS8tDgXXsBT3kgVTO0ffzCimZOx06vhT8phn2plr67GERQIy1cSBViqmsXfEKFOoV0dQb36KJRsX3/VkCxTug" ..
	"BTeHueHDmYp6D9J4Ks6gwZV38TETGSYch9iAW+3Rbzw12C7nJYP80K0nC3Z8ppms8W6O0ukNOFPr3j2xUvdYJDP9aCHwVHNa65Be" ..
	"8Coyb+Yst7OpUEtlCCzDGPOC2bk1vG8oo0fm0+dQ32e70NIQrlG58g1cWcXGx/m01RxKlCgRbiRRQJJ39AEpQr6KHZ+CPEOCgdD5" ..
	"SWmdvp5TftNQ8ihkT5nFINWBQL+AB15x6yZ5wl/M/ovdfZiCdDa9xAmr/T6r+K1Kn2piZpCSBS5DmD+t40Ld9kXhPMsHxwHSXi7L" ..
	"jk93DjqS7e2yYltN2vGWdg8tlB1A9TLRihVD2l4SFhH2+MLts3g45FVWV+p6qXODdMJbbbf67o3uX4n/4hDZrcQe5qt2dYFUb/OC" ..
	"OycY+cixRcaDVZjMrNIhfGUcVfmZP8cHosTtsBzvJE902cfB6REriU9hG+LPArJZ6JvGOnw9ONjZLd2a84a2/+h65XTFsv+zAZZh" ..
	"gNVvtm2HX+5Xj0+va/FOa1E67CAmAMfyXXgRLGupXZCCarizH3Ogg6YSLgBg/FxqXHK+LCtIa+elk3D3JCG3Zrct7QLC8cScKupd" ..
	"iBzEmv7NHQk9026ILpokD56Di037f4mKX1BW2NrfLlD5GpqppdrbhXtqcQMsXNfEfHNqcofxjuNyxWk73fnr436JtrKhBm2Nc67Z" ..
	"Zv41iztUunEXAZbUozaqK1uxm4ytbPi27VIEAsij+S9sf3FGaZKPoVQ+NjwnG3NVGXKDz43pXwhMETjvnhJkLsbtbq2nU+XzrgNh" ..
	"0Y29b0VQTiL9267gqXaeBaK5EsZP5FiQArAjgqc8PuRinzq31KOks41ngrimzzkErajp8rkjKrWuIPrc8vV4lLfxxMPoiZr0lchU" ..
	"fSFyzNDJeWWyT/S/g+SljPM0Ad9mtIaDPcNCPim0iSBKYL7wOtfX/GF6TFwMiLM54ek2HVzD5W9+5p3wQHWWhyNdizlG+IQsXems" ..
	"n8RT4LXXOsIqz0A/BhLxb9iR2shULtl+Lu/aV0iRi/AqFAXG+CN98mX5Ik+mKgothpZNOKbJ7rBuOS1FBrNEQQWKJgpO9RxOPLUh" ..
	"r3cNS4VjmWtnJDJ5LBAL3ZhJYygz/AjLEJd8CijpeILR+s2KvMEQMxFEyJzKv0dJBuD62crW572XF0EJRmSukWI3z74hz74icvU/" ..
	"AuzQhRu3h8hcBkOwwCqvnJUu2D70ray86K5uSHcPZJR9HaYuWlUfEQB1ZwUcrvRo/edLCjm2MbMeoWS5woue5fc5tqx52wQ4mbT7" ..
	"sjutBHCg9SfPMK/BUbvZJcNTtY/o2sAGUNdNOcsqvMvl8WRwjOcTau656s01eUaaB16sgBB19zbc8aSAq5W22otmJ3iTkLBxs+6M" ..
	"EPuKQUhHY5STRa8jZZhSFXxVcXlwCHa9uf2GYaKGpv9Al59A9GpqFnEss2rnI0VwE5nBn7GoGAT+ywcOD3tE5LBg2T2GfMLmGCmR" ..
	"svZdP5F5NwgKWtf0lErtAy5pEQ2sRp+sbVhVZDbtHc+7LE4ABezDuVRswfZo8Xh7stVkj4XiSoff45PFZYXh+TwqwabbehoyMzzx" ..
	"A0IXW+eLmzk0p1masok05v6TjP9x/NAVUZ/tGgWXOta5IQ9NoBYTLPL9jZ7s6tLq4tH/UFuB+ubcd59ZhGyGvJdcl2ogUyuqsWJn" ..
	"srLGFkeeLRIjXkxO2wfhOdnN390q2w2FHpq9aH1jlzMVgyPx5SrxB+Z4cgQOxEqRGSagSE4HOpM5hrc8JhLMrtj8TpmPi4XjJtW/" ..
	"sUfxmQX+IzBqdfWt6T7wnrYwsLmljyuewLeQVwSIaLSR37Srl8w+rfwW5Od9x5+9dD4BGTE/yNpUwF0u9Jtj1vj69pUJEs7P1DGF" ..
	"eji6vHJkeYfgfN8fCOQInzSm6itjMHFlbkZRUhmi7Zvddq/y3DHZUp46MYCOsrGRhoSsc/bjAw2Uqlss/3A4wrppj8ob0qomr4Gu" ..
	"G2t8FyBX6WnLerHjTUg2nEkeWRYLh2iwSpAX9IfEj5X0q42C1Rl6+dRXkb/szjGMZdIrv9AOzb74wfmpt0pUGq6aYeQDK1EJTR4b" ..
	"hqeDU/F4qO094USzW4gqsYOSefUD878wmjWOBGmd2nye2LPzI+2ivWtZ9kQjrOeUw7jFPftaevqC0AYObA+JyfrQgiV9EjnlcNw9" ..
	"Fo1gr34DiaEzN6S0XD8nYiinYN9IZMJUTqhRUhtDQBXpxQO6YiRpxMAoz3ohIIvRCq9jurhxec31zMQnJEQb4nZH//iN5VsvdFTk" ..
	"qUTNdc4/ZyTDut/JRRJ4s2ti+yneFiT3tkg0ExDP8VraBVff/Sn+kmGKSQXjOyY3y8hb8yO3QJUHNWN1BPDtp8RHPQ9zXXqSWtdu" ..
	"Q6Rj9U5i3RMGXJZ3HFFxtNq7qRmDWLvUJn3Bq8XlQGAVdmFVC4piPl5w7bjOGE7eNGPHk1edIImpcrKeACbs5eKUbA982Du6TgME" ..
	"m7VZK3BOnM0cw3p39YbKr+PYDd3+S2Njvg99G/lGzQwj4R/hVoIT1IWMQp6eMEHGSiM2cPe9sLSjZWdN2DwWSf1sNn3O1d3G83MJ" ..
	"QZ2p+7XaDh3+tqZ7MMYE/VC6PPt/CCgR/Fdx3l6JHyFyzxEIs2rzTAATLlmnKVk4jtPWCC+R7xqjYz6i+OCTJv6XzigeVDbvsC2l" ..
	"wRmnYQh9Kgd001wG4IoTIOfaS+NM2Ah4P71NkdJL8ptiKt4rXY1p70bhtYuEVYDvKtf41I4JjWe6DeSf+jkyrMr62KOigtJAWtMH" ..
	"JF7zIMZn/r8c1UWDSMoVCgzs8dTmWR7MZVsKolj3N8Igc+/Y6ma1Ee+Te/pUy0ZgB8Xd9JdTqFtzj+gRXxO1xSsk0GFjfGWkV/gP" ..
	"1VcT/WujLOdkeDJMaGw/QAcoYerlA3tJy81sAb0mA+c4LZfT46tg5uIMy4xTHbLmH0R7JZhqTGnqqYjGiMQu94y5E2B5bgg+OvgU" ..
	"tK65mmdWc4fwDZfCI1mtb8zH6Q0vmnBQrjqu/jwlEAvrbOUIIJOjEy6roGcfJLsu6vjklEpAppXsFGirNXPYeLYTzmXmqkIV5otL" ..
	"stPrj/qbr7+Ak9HGtoD3DUn/w2klrbsd9kTxBSvc7SYTHwCO5Tf11rlYGfBH7KG+/zQh55jPTq4Dn+6vRmoDqDATHdxTa16el1jf" ..
	"cnT+GRc88C55618J5yL3K20YKFcWrxj3j6JbCtJAQebuOlFfQaqAFmOjAObUsT2+5/BT5a3JjjfTt3CLx6OvmgoqtvsonggZBIaW" ..
	"dGNQJ7AMylzZZTpBYSoRlkl9PRASBNXk/gefPuV5oFoePtOHFjaSbaoppu0EfBr0R7bFDPn63OjjPogjKx1PbE1zNRBMQMgmr+pH" ..
	"IJbrM7SoOKJ5+1DjvNmOfNOy7pLEs82VjmD7Tq3O5FCOYa6IJZpKKbQPS0Hfpx2mJd6s1b4Mb2QDSbujQH6www9G4N/4U6zgKPAG" ..
	"uDkwRMXbhkGCvvjX6oJDw4/mQeqCtIS/Y1bSZnNAbYZS7pOhxb3Vf0LOTeTiUUFrddpIS9jppF7bVAlngM9GSD6EzLRmdTORfQyp" ..
	"Q/EGbGUsgGQw/WbRnmd8qexWwXaqp8G3fnGkMy4gEHl2iECrWLbbc6+3/M7tPFNavoKQF59YbwcLLAeQ2rdcbcmv91A80wGjsq60" ..
	"BBTVd1IUTXBJrb4QUKXrXsfS2SAoaPVKdrcSibsDL7IObC05iqkyQLcjz52NIZi4Q/g9kaaR+tMRQKsvbJNEqRdqPZWFRohsuz9M" ..
	"DhEVJNR9jIQdTpl7bukxeW+dkPUI3bfQwgO8KBwH8q7zga5Xo9Fq3eo6zQDeFgS2k2PoZiS7kRKfSAi6RQ97VpaNbwEqQowIPjDg" ..
	"Ia+88Je1bBFIiDB/QH8K2mXk4lB4mqwhLH+K2FRza0K+u29FdoYKQWXz8+tUfCFc7yy6TOsF2IcmHT+qWNFOGTIPw4xn16ixM8xu" ..
	"3v39kpT5qH0VVcOjyHJbv4JupCqLXarL9hhz74DgXUDI5CiHGleq0vbhEq9pqMEJTQhf+bU4Bt6DkvmFWq/p6g0qneP7EN965vvj" ..
	"8Yc141Adl+B8N0AhbcMUzSnlb53hzQs2aygoBJjcNLT8LTZis20xarTQUj4OjLaNYC5KBW5CtjFmBDC2ObDTdGh6enHRDWvR+Kn4" ..
	"MaoHKUawiqDhaeFilpMz4SGA3RHsnnAih+99zyJF7vUcmBlgeRcIBVavM+OOyPe8S1xFHUVVnNfuUX/DbjZp9ZX5x8Vz8MJFWPe3" ..
	"lJyIkHd58p1Wp/gxL2/Di6fP3iDbQ87OzLs3gFKnFGJlAwM0YxbwIL6ySEjmTE3Cvtd8rvcR7WBHgGj2ogeK0RbneZn7b36ccL6F" ..
	"FFJ0XMIoQZtNRI6XlrKiTJrODCTUpf8tphVzfl+NgJvYL1PFxqIMaARbZzuLuUZ2DCQ3UBeRXtrpB7p6brgv4V7sAoDtC8V6lWL+" ..
	""
local PAYLOAD_P8 =
	"wXufkyFBFJZdnUOFImp9UcwNE84INdAzGdoEhMhg3KflHNH/ixxdIwox4D1QXtKsbLQJp0aA1wJ7tHqdIgSrVVatx2p3dUwL842y" ..
	"tEVA8rXCBynsnmmnKPZVHVnmRn2VSABxV2nOFzV14wO8qFr8U9Pcx6kWTVc1V653dfmzRkzhjpcx/XhyWBoLQeIriT+wjT0TRlEP" ..
	"RyXRYW3MBgcedg7L7paIa64klp2+9n45+0yUKhXFmM+Q3wjT4/Lot+atN6HjN6c67pz4yPszzxgGM0dekopO5F/ixdxjXvFoTmP7" ..
	"MaZPU2B0yRO575MgFWVjIcZ7iost7sra+d4jpVON++7SgBhfNA27lWDpgcByrvct1whMILWGQcTNBpHOJ0PMSBoJP+SL8ZDMhyPl" ..
	"roH3Y8ou+5hBzmZ7vMQAqA60OPhzoKouLsaKeiCTJdqNp1Vfh/tcfKx/ZzKLWn55ex0bAzPE14ozBGnrihxyN5VQXHEsmk46qDhw" ..
	"lZ+cHSjeTnt7qY0KkhvJGSzy8Seah0zRb6XjYsA+nGzpIWY/VC2OQV59RNxFdVGRZ9crWNFkgH6CAk0f7TPPaIPyFGwAVmqTsSWR" ..
	"TPqNDMOIVFBFn0zZZLWi+nmrhztDs/F+BtiXbloo2R8DwIW7Pho27Ma+RsmH9lxMN24To11qqRXTm9FUp62rnBRhmOX+SXDrKkmk" ..
	"2zM+CT7+xmszsfidVMqlazn2AgbcKECZ7LEGkOKuhQBJNlO61MCP6wEDf4FCyYuPu5I/wKN9jcc8jMs1WAxjs04NxPR7vVJRQaFY" ..
	"bwn2K97x6SoAWn9h1BxckxhsTh5LHI0fYS+Q57PpZWgL3fH4SxNMxAzB6yQMLjBnbLmwgj5MXtEuBfgsyuO0TPomS7wlAskTz/rp" ..
	"OZIf+ksdekB0KExsGeIM6nuaijdSXqDIV3SuLuv8gQvuTq7vcunaV3TqqlTLJz9g1RHQHvbEyiHt6NhImkMEJwYptTctTsXTMNKi" ..
	"fwmW5Ldsz3DETILy0Sd0jPioNsg59AwNj2yqQPGnoLe44MmrsW9Loph/ZGQM/81F7uV+0TNv5ePucSiVUbWy6Q77/eV3meJgy5vy" ..
	"PL8TumlsjS9z5bgfMNslokKfQOodTSupvbLMH2jCtXH3JtvbLOwHJc3oamlk9qfm5KtQhvpzwT47/ETcqC8dCv2y+e97cXQL82jB" ..
	"+7pCk6gwSB0pdmTAyDHM0Rx6zC0n9VnJJyw5kOPxUoLYIq6BP4+wqtZiCIvx9S47HfiXJ98yMhu2s36/areq/1xeF1kEq3aG14V+" ..
	"QweERC1WnKE//ezTWIfOOVlWrda/bDy69JBskQ8uf3jk21OgIyKlcxzFa5VF/6lj1bWbMTcL4kwX9SNKYdk3RBIMjOlnjBr1XyfQ" ..
	"qpzFNqwIsPA05i1tkrjtWnYltcLNGl8ja0bVH9wC83tpfDpKPqqW/uVL+5vWDz5eMDtZ//xqM7I4pOWSp6BVfXqM+xjpRTEhjAHQ" ..
	"Im/svjM41irgoTlhX0nHKNKxdWW3Z4WnfKnSNbzDbwwA1J0yPg+InxWxc+timCXyxhXKPCSEazWh1TMDHElGNJMG74ZeCra7winc" ..
	"c2vCTf4DbEukLGXd7F+D1K/+U8Dmi7Wuk7nKbDInjaFCu1/F393iOY7P7bN9zLCMGbuGSCddV6sF7GUcdk0xxFBlFf8KvT4GwyOd" ..
	"VCZ8a0N3/vSN3bNWVppHcYmxybaE3trJV7QpFiWbNAe8KTWhcK+MQxkdm8IRAJZrqyzpTslUOb/cXAmTtddk4ZAoCZ8nLrxDyVPv" ..
	"Qp1NcWmuwleZxKhGtFwGAkROCnIpeqLjaHe/vVDThMk4+O5rlmrR5m1QvjOiMpe1VWXnhd8CrLEjNWXNOnrAu3lFibcU5A+bWfa1" ..
	"sbsub3RU4qFCL3S/QTkVB0fG1t0Z1x0mX/nu2JpIr2NEqBrNMQyBVcSk7mIT7cZPKgvfLa5bfgUl4gVPVWXjuZQHLDkOub1F6JJ8" ..
	"+yViCDg838f0tla2FgFDD4wVWfskQH9d7JdIzRgLSN6taJco3V+5P8KBlNd/v/1wnk73XJmswNK633mDKhzPT9x8Ma6G/8W7a1t0" ..
	"sI6d5DeBObOYpcyLLtUhFmT9/QbTl419irvV78phA2AO4fxb2ZRalssM8y+JUkirS4b9YW5Z51z9WTk4TjRvFtpmeob3gsWbi9c4" ..
	"BY4gH7pyIDbqMksJTJq0AytedZv1ndx1ZX0Ul+IKSpFonLn4/VPXn5AqW/s/H+mqNut4cwfl0NoFcIOdA3ZHfaST5KQkj1GOrxS+" ..
	"B9bQSCaY+3G/BF/5DOMEE2R6PQ9k618inPxdeeyrtBhpZnFGIhxU/Q5B7ejbwSZYOQNLq1kZLSuSAp6yMZyvY+/IelFRP2Lm5r4q" ..
	"/Jwzr9VQEKBEpuk+Ebe0XyGWK/kdgVUxAQPjBr0UAFghq4RYpcB86HOZ4p3bw2Aoercw+/SBnNzbZakZxLltvcCMCT4INl/HdxoJ" ..
	"eKadxobfyAshVVZfK9L7XzFmTmLJXHlCo+KcX4a7IjLqZw+EFQTck4JGUz702jpxNCLr4K033Neisz+z3ATAo4ZmaRD9ClykZlip" ..
	"UuMCQaLDpubNzG0sUSU93u0ay6b/p+xakOnKzeSkPZjiPYY6LqX+XVDQEXB+XkpUupaDqO1n/8/ijObum8JrtsvtvqWjskFxzDMr" ..
	"V4TRAZvNpOxC9AMG/vU+IRvSD/0slLvIXW/tKRtOc6l6RrGD3VsUVSLfrzh9zC5m9QMwYoUagqE2mmXMnZQ/mWrTu+EiPpWfZd20" ..
	"zS/Ab7IsmZVk80GrbPnEgm33gaS6ArKRoW0Wf9p7HI/uTNmk1YmcsJKP7/Tk1xfI7VltDZz7kH+yZHQOQq8/ap5TQ7Xg88IxrwBo" ..
	"GUlKKG3CuuF5ApjERxZiJi0cx+BlWRt4fR4JGQMCG/nYKw37q4jHXhb23cgOeMcBVnkP+RRJR6+R93TfSRDrnI7t4oApbsNrdb/Q" ..
	"SZQCfiffxJM3qUpBlOPsEgmJYgAlbLrOYu/h+EkMBKWgb/c5y894jL48UyMuWMn9wZLshM0ULru2if/uhQzN5/5yrp/CjLQkkWw0" ..
	"tGmJqpBYa/7zknl2yzP8omEQk+3tsdpzRb2xMSuwK2nBHMILQhvkBMeR2UR8en6BK95joGbvxtz92ZpVDGQZswKAavZ0cldnJj6E" ..
	"az8z71T2ja6uEpSS/y1Lu2sS93Qyw+kuchPtn0EzLj8/IjHeOjwIK9IJBhP9oh3LHhhvifQAZYGRfltFI4vfaEU5UqE9ZwSAGo+B" ..
	"Ec73iqFRtyvW7GiiHqsyR+FYJfUgDQiFYhKt+71l2rnBvXiiJ1snu44WBFFlJXd2rcy8zSOfKo7fiBTMhx0AJuZqLwh7f56lbPUg" ..
	"PjYy/PklIDe10MMc2MD+dDRELpC/iuRsH2fOrt3c8SdIfu/TSvu9lvqWPeTPiHsf8sRFy0utf9eUVMQD+OtaqwuFc1PuxPVtmMH1" ..
	"098pzHCDv5NdqH0+T5tjmnsS48puOG0LpnIzzuRYBLFwrnVqGunx//lzFQzeKuyDbjm94UjZD/QRnpWrEiepvbU0cSAHqfHJfgAy" ..
	"fBfRAaZ2xzyqOZ8kw9U/og7p/PSV4bmQP1rNlZxdpB9X6XlnkDltNNqIx5HPhhOuRQp5+zfz5ArDwf8286oJvW5Br5h3Sy2HaUT+" ..
	"NJFRlhP6cuj4xjTWmSj6YSH2W/xGBZkqfn85dd/wCRIbL5rSSYfa2y3bizAPWMuYAcdYBNrheIgMbiQhzGypD6aSgzucPrn1f7jS" ..
	"xDuJuqFAP7gQ4oAtXxh+LIm3oi5uerMCBsD2sqBrBjwVnmLIpaOaoVSdoyVwK8rB9G4M4g/0nU+GIPE3Epb9dGQGEI2R5oUyqfE2" ..
	"zVq07vLMXUa0YA03lnNPEyV9zHU2wzHt78NT0bX+GbaVX9g8FszFe4wKpzIVireYZE9Sqzfo9UjE1sLgc4pZHGuz1fzOgrjagKBF" ..
	"jKZDxCn5bH06ZNPHs5zJb2E9xfqjB6aelnlbQVSIC2UHlIF24IpwP3uzTe8JbJIRIgHAtnoevem+HivGhumoZTjn2QERP567zzGA" ..
	"NA4Zu6UdhqY7V0lo0zpG4hhPXkIukbxgMSriAkp5NOoROjkbrFqRj36uy8mdjag9vSvbpC6aMbz3Sc08yC+KRWeRartjOi9JQQo7" ..
	"lY0kgJrX6sNprOJ3ob96QnmkQBLmz6yjPpCjTkDEqhj82/gRW/rC18WDYeR6Fk6ma4NeNPqeIy13GlPtNq41ggA/H9xvlvpqDINy" ..
	"ggoirASvVhTKD8R5c5aH+sjnULDOjpC4xfo67sUvNsTbKFAdGwkx/Y64sF1AFY3rL+FZ887wGVMPbqg1H1kEN8fGS4l5VCk9UKSa" ..
	"4R3DG4x6Fr4udzcZmImNqVWNW+nTR0R5MYiRG4HzA9HsFky3givMYROgfrc7x0M5tzMSBK1KS9fSYNQI8vdus9zX8Ym1UMFHWrTl" ..
	"nN3kvrrUZRzNaHgL/ChKf6KiZU7MbOQXTMbsL9Dk8zuC8p0x70lc3Mz95GCrIqgyqOgQIZa6mnPdyohshWQ7Zuah08hGLrOWxm1v" ..
	"GEw66COmp6jn4ao8c/Rh7DSSZNA5DYKdq83f9Lw2Jj/D20S91A2GyeKFhbebDgHE6eqGRA4fzJlTfzAd23sRaOoSgJsgaP1ZRtEj" ..
	"g4DRwg98lVwgYnUHKdLAs5/RLaNq6dyaZSFDxbvcsjcUVCm1Tjdn4ms+YhYLOosE/V8gB7H04kUdGDB/M1KckmVRwj8f9gaHLM/d" ..
	"8gGNA3lfZdNWDSTAdjnrgC8M+YISRiB4XckwguIfxBlpHeBHW+s0KyQqZPzkdlgUiNK+rRMa1OiUXXjmIaoLqq0si3iUVE0pn80T" ..
	"lCVTjZbtcslpeGt9ErS6IgWgcnG/hZJI6EkEkX8BvuSEXygvo8xLCFjjd9j6T3yzl6fUM4XISvOk2dBw+jT3AJqrHmwG4E5moASn" ..
	"UINElVuJ37PNaS12Iue1zYAN4E7K2NUeCucqyKKvnAEJX+qpztx+VfEVCefcLRSOByyiDiIkQbCEqYpFxh2/vRVlV6fqDRtjv6KV" ..
	"L9/QSojH1TNyEVsp1Uhtr5ckw/3ilPM34UJe3Dwp+09oJypoDsW3+k6GsgO1X6g1K0UYC7qAm/r3csWg76ue5ZqxAqitmWTp6z+Q" ..
	"/K60/gPY5nRD4gHfY1QyDzceuYhEUz4DkEesRzf3PGTm7Jg7npeuGgy6/kelTRAEUSTRVwBqbMds626dpQDnd2vMZHq5wPWIRC3e" ..
	"9P8I3L2vWpT+1XKJtwGWt1bZIucdfGUoIKKQF7SvzFntU80FYUGEsLCOVwfJcVuJ5FQGAscCDA6HFVJfqAn71ermlYuG2RLxSKGD" ..
	"9+JMBraL4/ilDSjC+1k3iwNr4IPFvtCglgIsJQ6k01y8PIKZgZmkKAB4e9F5o0bKA/Hau1yLSyrfo9CpKdD1t+Jro+HhMKkUvpap" ..
	"OE750+dGWdcUt+7STiqlX8C4Hp5vCy/xRNESSANlTc1LJ0oYw6Ui0xcFzRzOZ8yokOWCszXyyxGoe9oBdHAM6SFupQ72YsRsRzbo" ..
	"sZoDrYeFGD8G/EKaAIMA9Tslflt9VcWdTGUTNSKE95W7mYVvVFBNReSPw8374VUk2XsHhkMMZwX7qA1aiQjQvZ1gx67dR8P+3VxP" ..
	"R0umkwGHfyN4tyn9gZKQjjT4CskiGBQ/yArHQBLo/bLKUHG6qiM0xU1Q44Q5rp+ZdhSlxRWnjV1aO5ack2qPonjxFjvZ3Qy27mx5" ..
	"qNqS7RdPAkKmPkQwb08wQf9F3gr/tyS6HEc0B4Xd+KsOJLbKi1JVs8Ec0GVoxGGOg4NwSzBi9RADJ2wS4hpvEMfRbek7VooCZNk7" ..
	"xQtoXwlABDu83OLYY3aq0Pg4w0cOqTHD/T/56HWgcRsiYsvSJ1Jk1POvBEpX+ciQjv7rjv2mAsu22tvG9PZ5uFGaFPacxl5uAhZN" ..
	""
local PAYLOAD_P9 =
	"6NJ5MOe/6Lgno3Hl5A1FixFRYGx4IRQ+tn506NpeO7J26Mn6LqiaRmHicfQFnNP27PIAxIZ0gk1FqlOKkf35J8JnpaBrn/cIpjv2" ..
	"NVIY5COdSLnV1g+mDaz6KEsjZBC3RhtxmlWkfmwPCCOtD8cWAgy6Of/flC9ngn/lmFy690EUpqGMcTLYqRHjmCMmTbrOMvI1/UwH" ..
	"81LFWslf8UGd1TEPJcA1unbMr6j6sMbbQP0C1gDHO9wrYUoUzCEm55FX3/LE7IrHyZi9gqgcJUw/gXvXK4kZIfaiHBKzA+7VO8od" ..
	"pJ6If3Qx8reyiQDmkLP/lA0OIWHCZK613AFhY5irBADNYUKjgZJ5m8wqmyLqQvKWCZfYFerQgd8J0mcZNdYXZuaJiSkqpbKf0VLD" ..
	"Zkk7lKgEV4SvGytb/AJSJbb1MwM/H4JxsRgigVB+K5CIkrmDBtd+0BNoHyAth0Fw7XnDy9QXkBj79iqONRpsLwmEnx7iQX8NC5Hp" ..
	"4tN4vjcVlTIz5jQpzUrGZszT0vhKws3bHEbEOqT3DwoIBnBQmeVfIVqaZR9Ox8F4xt3sRDc/LpZB8DFO2Lp+AqkaKJD8xmqc5+XD" ..
	"87SIIMQiuLRw7/uT4jCmjt1eYfr/L0K7cTh6s9kN0dF6Tv1DVw7tvI0DPSa+phCvJSKre11ungKwbHgJV39aOaoZsGQFJWFEfu2g" ..
	"kYIpMQBiDJzgMVAjmNtiUICilJhsR/MirK4iJZURO48kPrnffSjno8Wlc1fBaVnled7kzmfARHG9DrffDUl2o6G8stotnMXmOnBN" ..
	"BS8wgtDdFuFwOrCVXYjew/7dhPHoSNF/Yan7fe9qcyGFvOIZ+MgVSh0Ph0TUvIm834tL4e4fDF5fR/6gmra8qgOovPHf9la+J7Lv" ..
	"eUcRdGAficfxzw8YsAoqBjqwj7E2ItHuMQxs8ri2mQy2nMRsrdBuCY/9haS6xLEsPOBYpgze0NX3YibmnQlVKYGAan1mBRx4ppRf" ..
	"iyK8BgKsdIvhNvb6OEVGolCTXbROpkQLDMNna1dthFv7n2JbYDHdtMFeatpmJWG3urAjXK+m4zysVVfrDIXTUQqNm+OGEQw58/fO" ..
	"+9/4sd2BRJcUXE9xG3GYPyyEKMuQOKQnL6uLyCF+8UyfrcVRYIYV0BbrcRLuwINiUNOJWj1GPHUuYHorzkNe39fOKg0BdLqknbs/" ..
	"EO+3gEwgAJfFb0rCjT0JC6ncfspOL8NGtIJtLqtdaXUk8eKnTp/SVYIuskME0Hh/y/LOC5pm4B6G5MdMtKZt61l2az0bC4uYl8/D" ..
	"31pjFBwmLy7tk6kHLnQISALWxi0IwYuZgP/jkNbXjhD1HK7mhM4WwNfj3ciweSU5sl5q6BTHw56UxsRZHJtRSB4rc7wiEXz2e99+" ..
	"YGx+vyxonqDayVjIpL7kAG4Qz0X1MOiVaX+3SXkPzYz1BL7bZxfDZJ/wbgEjOII8lNUA7KHZJOONNi/0Q9g8nCkVUssa5iklZ/U0" ..
	"EErmE0If/mIprSrsNfl/zLqZz3/EhCOxQg5kE1MbE4qikJsjpf5RCkngBhFsYdjso8OrQ3qK359RT1oP+Okz/O3MyTabu9LMWemy" ..
	"zcZuKS7TSq92BxUGhe/z//fuRMVlfu/4ehL5tsLIHRI8SLlarbTqopr4rnlug0Gfjqj0QgOvCrex0bLTBXWdr6j4ifluwAV5zegQ" ..
	"/zJffTU2Tq2149Wzl0mx06ayumg8vfHtUSN3tCgZA3/kQxjYqK76v4S0y3vQqdYsRn3KbYNyQT5tvfqM9DdcavplXYdUnVl0NOIR" ..
	"TDIR/qbsbeVAtp0F2ClNdvQLBscqA0MbkMsAuLEohOgkWjw02Xjwd0hUoyornEaK/+HxKaQtyir4ktQDSvrG7vcujJ/Nl372Gkda" ..
	"DcuNaqGNLYITdV4jbjH138MQpCgPpI2070geIKyQtXFMLeVllF+M8CkvI8x4DtvqNnY2fzf7rQjU3X19CGr9fDS3L9aLbyi5E9Z0" ..
	"m1i64GMiRGbqk4JqoQlH4aSQw46lLt/ljnIGyXIOaw6/973u2wIMBQYNS8MbivJwWpujFie/JCG961Hm84kva9+lM5l1WTZQQqCR" ..
	"SWqndwiskH/7482LMtHSRxi3AWrUL/k746zeN/xyoZChvi3JkjPjd9iwaYDw+dIci4okJRIC7y5LpcyPJoIqBsiD0/YA87JFZw19" ..
	"Fl42ZdbAggyOOeJdTUAcLSHKHj9zW42e9VNImLRkIPE/FVoR92IeIThu8tthE4lhmETKRkLHIuH5eiOew2rACqF8H3txDUPmDE9G" ..
	"SfVgMnFSJ/Ro6U4q6DJOLBmEBENsiYMlWgJkq2ojrpnTZ7egb7SGI7/xonBSCkT1TY3nAFpoHV9Ifp5AsMprwDj4khIOcIQWuFIM" ..
	"gKJWywLRqIuB2zss7XFUmzggAvgJQeNomYEH61+6YPmO3MnzesVvmozAeXAvtUP4kLul6qzXHOT7YToSVgqFlXYtGlpkvuzbyS+J" ..
	"aAFpv3xRgNGt31/ola+DHUdPQ6pCGjdMUftarmsrK/0vXK//n1MjBW0LE+S2/HGZlinMejav4nv5YI10nUcgIbLbjWtWYdbEn66q" ..
	"Yzw8bEU+HlsCSw9JvnwQAI2j05PnzNeHLh2nseCWJnWQMIfd2IoTQotItWKiXulkCWssDZUWPcZAige4+AN2GZp6JFMk9cWGTMk3" ..
	"IpKwvp9ld46Pg1EBabOidDv61mUYSPoNp+ON7yEqDvl1Sw/trksCFzE0ZKWpwZXsDdHR7nkU3dJFC222a40m2+oqeEVa0Pf+je+q" ..
	"6Dt1ZbRTaBRhVn0f75kDZ01/IOC1IBHx49dx3ag9zi5cO33bxHfg9iynCyHbXvzDWSEAF7q1dwN8IopElJq1NiQBXL1/gR46bjPR" ..
	"54hwyd7bt2oIhx9nnyASfPVTKq6oP2qmgh+ajUF1RM2mYQY+Gne6HYT+7BnOe0I+NPkr5L+pceO8V4tGQrSzyIgwEYrMxrGfnEo5" ..
	"4uslVYf97aMtJdQQGWWW3wfLxgUokA68s2wCT1p34idbJoP7cLQq7Fi8Kt17ooE8D5KAt5slLiUgCgj4AEWR/KGdazM2SnfNiAG5" ..
	"JSMBl5Aita6FtiJmntKaGXEU5vRaonD+FMXNgfVIHdraHj/ZhaM2kG9r/Gyady8lJYWP0fFNZP8CZMVYD6U5LF2rWqVSP+sBej9r" ..
	"GHkEsBImxPCSO8obf8cMATPg3ZilBTDHjNhZCN4gJEQKiCZUKTEDHopBNjlolY0NGLnvX9imGv0kC/3a2GzXIYou+Gps5cmTHect" ..
	"xJdAxaCXUqnibj6y6Sb478+JMw4aVhUhh88dx3R4b7h7ICY2gKqR0uOmykzUfgS64uNefZP3r28xcDzs8JQ0JCbOP39V8HtSAYvU" ..
	"a8Y1Y1ZZM4HXChuCjgg7Sve105HZvemOqtlSqtaL8KK4RJdcgpLmfFuN5IoXUN+oaGWMmxa+TiNmAPVX43v83Ey2au3qsHnaq3uW" ..
	"q2KUkgUMvT3MgYoNfyOhQvagPkx11z8PPCwZFAE6WPlSp/YvCZoeM8fvmiO+s3exng88MDgdso/cfpWqdd5FjWKJgZ2D/CgMdJ98" ..
	"gX8HAYYWpSoNNy0e6kihs83yj+3znxtZEbzJvnzCK3X9OvCNibQBwl2q9m3gLHSyT9ajdBKRsVdUh30SzQ+gb+09Y9thxgLodUph" ..
	"OH5FfGKWZyRYkZfVpDjFdgslVQQ4Fxee0pco1wZZLWFXx7qqz2eqnGkhaIxN9NCgj6O6clXeQ7h0HK4nWiY5gQ9IYP8srCKh2dj0" ..
	"koEa0PnT5dmUIt+LWBvr1Kvvgiz2VQYxd1eVd/ASVT3XLFwmEq7bjLlgS70DucLzOUKbt2B63xwvsKXqlx6a6bVWgLlfmT6nq0k7" ..
	"RN0DRYY4l+HZH1+zNpALf2CmPKjbaQPuJSRh1C/NF+FQHFCRBWY/8dbPCOeMSJ1MS0Oa8DbdzXMEdnwQNhkArYugmwh8JRfn635a" ..
	"yz5dmTEnuCGUqJqRx4tBZwttoNwLD0DFCPzaekkoF2CjqXbrX7LFvk15rWyVSjCaBTiud+tWp3P1TIQX74ZP3JS3KUkz7QfJSirc" ..
	"PsahLY9Lmsbkp38N2DT116bk6zlw6eF2zBqwvHVnBLUdIZHdriFfaoMMR+cbfwc+BTrxwRCYjzkUcxlyd/vzbPR+MkeOqphRyvif" ..
	"3jrnMJkofqWw0hmp0MLsr+h0HJvbGSIlA5UKnk4RPS5q/Rp6pcIY3/gGIdTqlsm71aY7ZzBU+xvPpFhpyziUENGYsn+PMzj+FxiX" ..
	"BjzTi4LYdoxff3Woahg+VOTpS+M3cpSgOOlhPQJqyYFAOZcspnAgHm4g3/FZi+TTkNrAWKOkxLxFhxY5dFfCjyqqHgt6QIOT8165" ..
	"Wvn6yQpXaBmhWUWPlZwjMavz7ISXhssqA2+8hm/FLymM6YrT3/iccBYIOEguyzPq/UFhIdvoxE2KY6Fz3YYILd5twLHt8W7jQNI5" ..
	"90m4YD5vH2qHT8agleIrE77YkX+zYS8eeLBzIpOIAW1ZC0lhGIPLJ/Hfo3PkKsuP87PVzQ0xkM9N8tlp32lj249SJiEJry/IJWwN" ..
	"f/JgWH3Do9RwUnL9TuMlthIiNM6XgR6QpyMYXirwlr/UrnoHC9vOW9u5iyMI7UO1B93sLt6Sf8S8BWtVYh0sH9b5fWfOfGrb3v/Y" ..
	"IqeVMkdFeRVCL0fwC9/Q0zAvh2M6FUNdHWAFLGGEbC3StUbDExvM41We8Zs88cD8J/5GzvmzGmWe2sZoVr2i5/Kx9AtAoIww3UjI" ..
	"076EuDN8qq+SzYHrITrT/qiT6Du7NZkcReJA1oycxLkkfOd0JNTjeivCHT6EOmRtwvJ820AJ8OYMXmBr1Mr7zVWkafn9Svbm2Z5f" ..
	"6MIUPO2gOfXbHs8vpN2lYW8rL2Kpd/kovPqn2f/h07r21ZoLefRkZJ6aylUs/3Bvlbs7SlMcIlPGtA68HA1hP7Uugnl9+X0PeD3e" ..
	"XG9zqO6WByGKHfUpAhUFTJVlPbOATiSTcykyn+YdeWjK6Scu6xnmXFa9E2atFtAUDWldmVG6gPLttim9uoFgLOtQhH3SIRePA+71" ..
	"dCtw5Yh5p1x5sFfw+MX9Sum9xqbrhccp2HQ2Zxykf8ojD+xSnKyQN/Ow1rPwtTpGMi315sCWYIq+W5TWozXG4njQ9N+DTysl4Ueo" ..
	"QBBLsOdFDl42yb7qgxK5jjqBjMpnNDMt2lgaMp1pEtthAuln0HSTffSM1yPGKVMch5JhNjzpH/XpuffymHYGY12rZSgrFCKC9mMx" ..
	"K9aUoOD/4UC7xgeL9NBkWIJVofy9g9TUf9kSTlWoGcxmtqY1ZvA/7+J+0LQuOzsQs2YjmzQz9nhuvRy5gP2i481eff978xFXd0+/" ..
	"x8ypkhjVVlNjowBQVf2dQwCZQg5i0L7tXl1JJNuvRNK7p/geOCxdVFYQu+7hpFDcQIUX/FpS/ymzMKn997aFEkjq31fD1LJ3Oo6q" ..
	"XGACJ5QBVA2ZIgZY+VwwhXzk9mJjA0iOZCgRIwFTIVKENOplvse7YI+PHFCQFvNsu/mG0vcvYoWhTb/yqUtvWXQvzZzy58+fwuP3" ..
	"ATM+aW+APg1olAiFOpUx3jBCjcAIka6j/gKlnS/9gisHCzfftfUmLngDDE2JeuhVpsnWX0rMybgDkNosbTEasV24WZDuCh6F5/0l" ..
	"Pj7guhlbd2qV5Cu7Br/NVEMhuUWkQdvEPsjbFA0vNwtioBc1i5pchszlsTvru1l+/mOgTiORhERTcLLgNIVJubLmW9hf7Brl/4fu" ..
	"OpF1w9osy9AHsJri4pdXT53DgcnDWWkvIBohwlsSBhRodUrOACcADHy54OwCvU7zXRCWjvj2xbJwKjyCWhDJfLNIlBXfcZlK2Tob" ..
	"37oP0r88hILi/dfCg6bZ1hugnTdECtqe6W5CdZVemzA4QEfFdaqtxsWmovnrMVHLbN1tKkj7I9JDO0HEznoanVV0Rly0x7QS1xJY" ..
	""
local PAYLOAD_P10 =
	"DNkvIeRMAsfbnzZSvukKlP+Wb1i0Vg/w5hIa8CbWbaVUhN5gX9sotHgk72kGQguDW9MoUrkPGe7VjLWZ06Pv9DK3Y5UzGyRHV8kS" ..
	"Bkdr4ubhD7anUZZCTKV9TrUzvBUtio3TB6FlL63gq3dyOorb/1GgzfMLhGrjrngbjrTrVdVZLY5T/YHfiqhSUEAJWMTbItU00vSc" ..
	"7o30w5gUgrwNm4yYjPJil1RYwb1r3HYKQwH3dn3XV/AJxuNqeHaW4RUeH3wjz4H+r2aziSJ7emQAgr4ius/AjmdcBApbf1KX5Qn/" ..
	"zFDCZsWJ44CevLi7y17yuD4jAAmpbdKmOiawhPRYHp7Rh4Z7xW2D19A912HCAKpwJRCTYpUF0HAFMt1BOF+Kwsq/5PGzW8FABXp+" ..
	"236/SDdSxkkqmLLS842y8d8WS/YA4d1w1rIBXcr5uJYbjk55zpMPsNwP3UUYiWzDY7bqYEyI0KmUg5naTGLgLp103EJTmbFWpNoQ" ..
	"Mkv6CJ3C6IMBzIOVZF+muftdUNLHvJBO026XRDhWr12JZv6+azkyW1kFOaIT8/G9gXyrIn2zVD82FPkYUj+LWJU5GLrp3+EFHXsT" ..
	"O+OAhCjlP0H5VO4mXjbnf/o5gx/Tx7ml7OEh1rNsEB5B/r2ln48NlsWQQuJE+KwGdJgtAaKKKIBdzUdwmQ9WerFNiB7JaXTPErkP" ..
	"RD1AKHGznMSYQl8WhROXIIobzQIviFvUMfbAzwWr6PduelE+AMCUHN8EDI5zo2PpsNcSM5ngZH0Yld8xKS+zuqRwW5KE5nmaYM9V" ..
	"FvdxOFe5u+UBPziwCHA+4BDy3JW3DDSJBbHbQaCEY/h6OYZaLewvBAkW2RFKXkyqSwg7waLaJybddSR94XYvOyenVusRfSmQzPZX" ..
	"ZR39SMIU3VCF/qtYDs2j/Sp8karnJiTnfMy6F3SkaVfoidANpB4gxSo3WLGw1McLf9X5ELUNxpXMxwukjkZJsJriC8b98xCx99ru" ..
	"rWnPd8Gx1NnpbY4Mr8u+kDN0V15b0gG3ksiFb/q0BMXxTD8f8FZe7vlmAEV6FmU5lIsdrRBf9FNyMJNG5P6Cg5t5tzPblbG6DTdx" ..
	"sei02P3DRPDDVh3eXVm0/FptNqLZdEHXlUy6hmNeWdm2w3V0B108Bv6RQOrVqyQEJGtBrmKBOSoB6bLNCWW9K0iCUL0IC8ysTT5p" ..
	"IBCGGgEKqOGaO3Gt4r+fyqNWdwxLPIwcb8VMLsodo2yOA6NDyEkvG9zyfL+waCfCZYk8pO5TOu0rvjAu0ExRLguFm/lik6BdqwHq" ..
	"lxgidn3nEUkieDzlNgzy5KdsVq3q8mX+aa6dMbDR6QssiW7TVEs6mEtxBtu4J7QWhtyj0vccoWCLueVxmGfyfo6aMfnlfvedVc8p" ..
	"eUoGGSWsBGDyZDfz32I7RhVLsK8OVrxCTxb5DITNNVBD2HOLgqJj/e1BkByWLiVdiB06qyDGl+dxATr7T2bdRg3uWvYPMWWyY7G1" ..
	"/ujov0HFVDbQldKK3zddDmrekFarpRzq2lwfYiP/OBgMtvXO9eWSDHPkynLJSgOhl9i2ptdWKc0w8X7ML1LeHeeBRroF/rS7SjZx" ..
	"5DeqpZsMFB17k9uthSeMP9z8mGlyTnKR3PLq0cG59EqLkOCeJlMyD1CuYhc4OxviMmlKNot5I00HePwNgecT+XWFEZBqWMc52Kud" ..
	"3nSQJy+YFI0G4ecwaUWWE6nwb9okiVfM0dCJ9z4doVY8wgahb8MilyR1zRHFVDfRT49B+EVWgQV3YgaTf3cVptdr2yfixbyo8R5u" ..
	"2TMdima9qVn4qPjU+9UPLBk1wd59yGd6TEMTncUnDq4lRkrv0rQ4EJQPtYOe5Ya0CDSBiY5JsNpr7eumoBAuLL5qZFwn2O1MVln/" ..
	"HOBx9T/p5tb3SZBYONhPGb0JUsYOkJkgpcVtyCvcaFGA2MUj2fSmLpfp4Y7IkxDa4tvRAh/Im59wsJrrYgfCE6D9O7BaXnjvjZHr" ..
	"bioDJwVfyyQ/nFnTgZdAzSxUc9+dQ4jlv0/NWQay8AGxQaJehJzpIUD0LnbgOff15sOf0qRWGpzrhgZZWmZkrv6rSdgE/+DvNe7T" ..
	"mIxD/4gegSQkE7hraC2s20IruQgqcGOYjJv62+CqWFeu4SFELDvvjhYAwC8ZJDPzCk/xzO+lhGjRqaH9eCa+lfI6NFH+dmawzYh9" ..
	"ceNVAEzM9Siz+lXwHmFQWjIOfCUhxesYTaKVP0NlOI8u0gjcTMzECb5jwVG5VmSIZtu38jen+AlN2r6FT8+qFy4Vl2VUJJSrqnSn" ..
	"9+InfknalNBoa9Xo9QdkC2lHsC1ak/uDCOI4C/+sMp6mTRhQnq5GnPyGZJabtm9kHi7hvkw0TojAs1tSYXwIcRzzP+buHl4T40fe" ..
	"E8fzumdlkJusek6vcp0xjzAcrRJ0XdkUdLq3j2YefDvqoj+WbSWqaMhCOmyzmqJYNxxKQAFhVjFVpPCaJkhF84jC+kx/moUR6Uem" ..
	"U34M1tLne6Q89WxQvOU+rjx73MOBYDP9I3U8C8vw3VXfjL0VplYElJi/RIABzrPDcS63vALdbF5oEvdOZvjp1N8d+or+QIQzEhl0" ..
	"P/d+LU3Y7Z80g8R8Z/vSd+6T7ROzSTTIt6Wn1Av8o4YhbTMbH7Pns9QyR5MaFqPVtw5R9pSYlQPkJYlI5AOahC3N7ilxHCWHrcFU" ..
	"SObwfycG5MxuPe47rJYn4SJVx3eKABXo7sHA1O6jZfhudLTqaLuW10g5vWUQtIocF3+3AE+Ii9rxtRHHcSBmoCOec+4pvdurcr5G" ..
	"o6broUXGqaXf7isnJdHTry5NbU5mcLsV3rWQInj4bx7PhyZg1G7Zo+f4glayallrzVyppMX0NYB0k8k3yDz36aDqM4GztIJh8EtN" ..
	"rlGNm3OLTbBgY1y4rvaLlQvVTsvXHdU9ReWNlKQ02AHlLJ1Oa4titQrZa/y+ubpktmiWgpApGwjtYPkN3OWaTdBnt+gu/j5UTqZ1" ..
	"4BlMjym3lpVSjrxZjTGeT/+RlFp0iyGNkwRUgu7hTe//mUERgg1JaVKa8p9plPUba850jWe1Rgkiw/WBCkYlwFZLd9yXHyO6zqFP" ..
	"dywoqNGKORaCUkciSAHPSQzwPoEetJLgtsyljqfu9FLbRrFF9CQqt9irS3skYnUtJXGyBzx6wUZQeqLvAUmOhzGu5PjcUUonBM2/" ..
	"tXpZSpjr/fHzAFhWn/suxo5NKcfZghJrESK38CYqB95dPIqJZwaNePWGPcHHhFs+JLHnKupHQNyXYb4nVwtlbP03CVl0nA2fXrCH" ..
	"7kwCqWPToP1TuoedXo99mQ0OoUUDiY1qr63VQRneoAQDMpYxpSs5zGzapqAFsNu7l8Lj3RhtVrLEVogMY3bXj0CKdyg3zCks6CPW" ..
	"J8HQI0P42ZngRt4gyjaLP9u2VfRpP0AxxcFak15+5pIo4MjBGPe2mP7hInzABPr+EAjUMqF0Fgjo6l5MEDiWUJe9fMws3RijnV+k" ..
	"GApDNM0gUPOH/TKq9udkAsS+urSgrSneFZ/kMgKR4j5ZMUquRgbEQf7WHxFeEWUSSxMYIdcLlFV52ulxs38bb+grqiEGEV9x5rRT" ..
	"8BVDJ7xJHfcoi2nrHCIsjHe8Z4mLzHSsz2cDERLw/mJC/ysXAE1wn+sSN+0X9lddWx+cTDI42DolG4RWO5Jk7sJ+4HHY/MsPKJIe" ..
	"yqqSXC+1p4peP5hDqKSOf747qXcUS9k/2r7bywWrBYJMJ8BOFjgoG13w7mJLo2jH6fzfYCi8Y60H2iVqMo7y4qqK0NJ7BV5kUFRC" ..
	"VvtBqROAdAOzXGZbb8XmJGbjiGS3xA8KNbRA5kXwj9ohhaQdpvuXqo3mHrC4DQsttKfk5bnbyu6Qp7ouk26srnygsuZo7IrmBe7B" ..
	"V7WwuTP3XPosaMKOfoNJDJDbQ0oQ9oo8/jh92TFuhqFxIDrTpizJytOFcwRgzHiuS9V4c9vCQqNYIPy2jEACrR4uuUZkncgCeXrL" ..
	"vA2z1Nio2cBM9nKYw3cewQdW+/FzIgHvsPn+4xh8aHgROhB8S7If+1iaBK4wArtUWqr1DVT+PSkpfHaqKFe6UqSjjDRozF3g0XRD" ..
	"BFnsLaY5CTfgdOnNjVRuJ0tuyLkmEVF/4ZULqEhUcYA+1EDlACRPtqPhT+r2bo3/S2An5U/d/lFBnLVEoqp3DeVf0oMlFc5yAAKT" ..
	"Q6+35YJUo/KoUQ5lBGzHHFEIO3u9UiDahmpxDQn+AcNhcldpvWFmPMwwXWMOBVPSZnW0yhPIqkhe0vKOK+q6Sx1vrRLxiwD1YQBK" ..
	"vLrwdTwFJeNz8qTNH8leXk1MemM2l/y+CDK6TIfGLOSthqsqzxr0dqPpIGFlloNYq8AwVgWmPWxLyio/Eoc3OG284qR+IdcB8l24" ..
	"5+yitILuPLPchfvwViJXr/Ok/QXV2eU/cnUo6Pb5L+Sq/0O14Q0vFl1xWsavEIW6OfEvtrso3HjViLaaoMEeEm25kCsQwMcZi4xe" ..
	"3sHEt0SNnr5mbE5EN1kqueYyiI+C0QF4CldSEB8V0OAlqBuaFlSVayBDdjJTA37xL71VLXfKfHXhiSWDWzkbaZdC2glii6RdmcgG" ..
	"EAkSVt4m6a48C3KArReJ6104gEmkSYfAcaG4qztxTZBe+fQ6bL/t0rulph4iqIK/NLX7Stf9MbqW1Z3ZXVVK+4I/+36ppZO1ZLHv" ..
	"LEyEd8RXga6kXAXaWWgtU67SeNhBrW9MZC7v4tRXQKNpaec1565GMe+ot+gn05zPkjGUNNt0Je4h4ulc/oKPKa6/XhB38578twhK" ..
	"GDvx4veOr1DC0xAmaYXaO8CwRokVrFWGvAdIS8wpkrYH7fdhc/4rs8mQYyoM5haRZsIywvPFPipvqDQzAlQY1kZaF2hmLDZ51gGs" ..
	"DSiwH38IXgCeA8zZdWqceBwlZykHM0hrDCD7Pm8YqGLs4dE16fft5jxJka+gLluM2OBiT2cVPLg0a+tJypBXUwnY1eXmH4AZ0/x7" ..
	"4jPcRQX36mN8/46oQOsCQ7FwWnuNpatYt6hAmUQajlvApAj3YUMUs6hTNca/BFByOyFVXQcIDhY33faf8p3W7q10FV68xwWBYpUi" ..
	"arefPw6oloPq8uAskqfPzWDEj/hwnVVYO1aTjHlMLqYP25D4nwttoumnUYr0RY87xEMgdF2kbUPeztT8Mt8QJtEtvc5doyveQemi" ..
	"ugjbxlva1W1Sg2S8Ri6CwU5Pdyh61IJ9rhLx8DbGMaZV7T7hgAw+pYE2NFVQPtmEs2YeadM8ozerBcJRqso92v5VZmmjsBIPXMbl" ..
	"OGEjNYqqnSOP3rn5+qYLItBUe/RVufqEvsE+RpJQc0Bxkrx5tL0guL1+CNzZFDqE9RfRrRpnjOa9Fgf0c7Ll6+DE5eYMTdmgsuXA" ..
	"imMN/gbeN2UqsRHHR3qDUyKXAPLnn0ZAVMzF85irpjD1ooegz9//jfp0CpKS4Sd48gVlNKkFBMjP1t0QI2gE6udJJOC5/LJ7PZZP" ..
	"GVv13BkYPxo4V2xp0zRpVV7npyIuSAbD5rPgCjI1IHlBwelfDHmu7kkuPb4kYNar++/GkCpYcKDU8m4jDMghkD5oWyWwbcsjqIU2" ..
	"2c9wMig/zTrgeAnZoJTYescc6UcYBz81eAZTfAPntp9M7ZAVHDJ6eMvpF0Q4s7UE/mR02Efq+/5z3F+ZA7QJTB4ofewf+b3PUkak" ..
	"LhXoJAwY+r1eDWoGzCSX37t9QmvyMCuP9GFtL19zzRivRCKjE70deweckAJAwob9uYiXsHZZIlISWwUVZVpndy9z9eymcyU1Jj0a" ..
	"zRSNDIbosuNu4PE+Z6nchRS2ewOwuZ0y/vGt/QyeqRAHAa/BApIMUF41+EmN7+al0Z5ydGMMyl3Tbg0HH+/dV6BqL8y4l9REVX0z" ..
	"A0hXCyuzWb5HVnnJC0jvKUGWMhw7L0HpxjTXTYA4KenDDNi5nQjY0vJsUKWQFD1CgMmazRfDa8m/YQjT+F8X+r3HYROJFHRA8HkW" ..
	""
local PAYLOAD_P11 =
	"zMDoZpExnRxHLDV0RrJRQqNQqk9J/Y4dupQN9nEK1YHd8OnpM/KbDPGBqO3k4oQq0NFuk3FtFdxos4rGW+dXgLvIVeFC3YJw+9ZS" ..
	"WxC64fDb9AaX1dV0g+fnSSK8aueSmi+jyDqhuxQ9Ru2cW4tK66U+wQbZp/ouFACwE00JxF4IwCSB9JCmuCkwvjyeOrgV25mk6mWu" ..
	"yltoWwI9lKVXNXgV52lKY+rs75b0zxdhRrritLJtaEmNXZS7YjKXn49p8WVbmOcGEQBh94jvYjw69HUR8frBljmAxZXGMTmdiYeQ" ..
	"Ku7Ob93mf1c08WvW24xhVUxYkYWp1adhpQ9zmp1CSxqxGQO5oD6OStymW0zHHRaJ2kv28rjQx55Vc2AZgV4Cm06/5wVVVl4rH8dX" ..
	"4bQHR3ujn31sy2v0HjFWgViNKpxCgS141ZV/ywN4efDqEzFkHIgvdNlt+NVVDWItsXQYaFsvk72L8c3nATTZaN2xmaTLtJVAfbEn" ..
	"l/BCv+z1IWZJJQaDm+etUFZpzKalvDrXCPDsFhnTHlhSw50SrWMeGbtCz4N1OVa+ax/ucaVFVhhu4FZdDjDS6pz1uqGgHNcrqTwo" ..
	"3YW0G0wjUjVxYfndhJQ0iLl8jH7nETpXGZ+qv1nhbWCu8VZkxevqNaFWb4Bc9UGjF1Y5B9uqlQXZTJ9S1EghB/79q9OMh2VGWtgp" ..
	"HUzBH+3TvwGyoVbHeuL4ZWrfFDZoYQYBXH8mWSgUOMA2QUYWeuSPr/qEv56oeisaXnzOeonW+qAVIAaa62D106IdT/6PgVi89H/q" ..
	"EY9RUaMeQoq6tX8fO3+7geVNcK1thn6dAo2CAHhQk835PrHs4NLv26Pk3sbQunW6I/5xCirPDbw7mJAN7huFpgF7DAZOjc0AI16n" ..
	"gooH0YdjFD8d9kfIdskikkVRjuQIXkrwL8z4RcYBn1HVUbQcX/FxMyOdIRl/0cMJE5KTyQcul09hK47+amZVc8vCFB6Sm9gcPuKG" ..
	"H86lXpNz2dQbV7T3KsJJXb5YNHJErhvlkSLVaFntun9FlzDYSkM1QI+dBbfGbNaoC9c242sTrDhhFUy3Kid7w+Yl+PE9ce4usZX/" ..
	"WxB4mQlhLTNG7knh4YaSsWPAv2x0kaqpBp2sb6IYR8Esc88lOUorNKlGzxeXroWpQtzQDZD3w3XeHyWN0aSLuQZNF+k9YBRHzIXv" ..
	"c51XRAAowhYM6Jk0se5aBSjQQf0WNOrnFkHwpJQZ4B9ybjH1n1eg3nQV8RIQcIerKTbj8EvgtrUGvE7EaqVm/jvAZNQhuxyBfaxr" ..
	"4QK/NLoaL3bzq7Bu653updN7eF3wokHSMJf17LZddYMJgRwKHhSuZkgQPb4kEqcrliiDw3D4JW3R+WDiHOIdkDlmaEBg1Rqs7eq8" ..
	"2RO+UOsYMJpZbaSy3Y0ufEc3NQwiMrOfoJnYgCwkQ/kL6cmIjz2jo1u3MBWT6/4dfvoFzBIbllDJsLiLyibRxdJrOItITJTwUDv0" ..
	"6z6pFnIhQJMYAS7x4yiQ3hZx3tB+q9aLoML4XYnlTbOUKkZ18Cd97mrHBQIK85O3kh51GwJHGXwzuryW8CZdiRtqktT3OeHSdWKm" ..
	"IqKQF9lgRokgmdMyjqexGKdYnE4ltsTrmEdgmUQh0sG3CBdY4H5mRes5WXG/JmRDo+do8vwofdUXDiBS0MDmssKbtfplIDNXzURJ" ..
	"41T/49Tay+OGOmzalwgxBg0db3TeaR0Tn/PuDDg9sLWrWysqojo+KLbBDdFv/W6FMwPrSQ1cajXxnU3kwCdTL58z19HlVSb6Tdq2" ..
	"SVHsK20lboIK2fp4M1YbMYcp57Yb9QyOvJ0m2UPpo0LLb7SSCsoGy6G/BHCBDAr/P9CB1EKiADYc/OTZPpHvOr00A3YEw8rNEpVp" ..
	"P1epVfEiCXNn8wA/kSWtH6KEFjfmxFOLqb2YfzSRkgxQZEZ45r/jrinMdSutqgWBihC6tskzM0zlYuYzQW/ldTJ07Jy9imrg1kBr" ..
	"8z8jlG1CvnQW/b+szzaPmXrfORCLbCUhVb41tWVgjcGZ7+GXAj9rdDZt3eNFKaA/XJopycspt8V9PSgarxfRv5KcrZ1MBGkJw4ec" ..
	"639W/vEZAf/4tIvfGrN91YVemSg4RXmr2yTXbqBJ+9QehSWCDUYkFFcka8LqqrrwgklfFncoxYJWq+MIVD34BT4JUAAUD7Ld9XeZ" ..
	"N8TIDlUr+VoLZLAyzHMnE5eArpmT47tJcVCKzMwFlhcAd65CrCUAB/2rd6M0LLc/nSqvqK8RFYq8NP6wlBDdQodU4Ji+pNaTFRUN" ..
	"FJ1H4iJeMszp4mJinuVJ91cEjlO+ZSI8O46Kf/1bvw4H2jPn0+6p0G9Nx7CbGGj1WLLNiB0tdaLYh8XxHvduSJYvSmPbmhD6P4MR" ..
	"Bj3+3cb9cJab9iop4GY4Xr6spN/hjAMqR8aYe6mPZ40KVMGny/TrWyPFHvZqVlSG6CqeyDmmA4utHbgfZbZXWaDfRu/JECUO7hlZ" ..
	"z5BnUSk8x7386fe+rb97cC8k8D/2WjkkTjBx7ceUvRI/WVkcikUa/QMWA0bMP9Y5MTTdgSqglfDWOrDg3EWSKUioZ/ElPP9nEj4p" ..
	"+FvZe7liXUESsr9r9RgspvFxdTDLLZXoIFgCpfAKvz6KPss9Lj9FdNnzr/usgib1WA+ceaFf+C1Iw/E+z5pqp84I1/qchUDZZbcO" ..
	"tgBk91TK0jp4Tkso+dNgYHv2ela+FyvowpmHTHdNXAh2huZobgX0UhHGJCegxnKJ0+2EHpxPoy59FoQZqAMExgMRzxHlkNXFcp+f" ..
	"8TuZKJZ9trkcvDVVB08rk4hdmzpq9Z/YvKcmpVcc3qtp/QiTPsdV0ma2oGGkyW5mLyydMVb9QttwSCJBpPCmFcy5QEX6S5RGnDpv" ..
	"KoTg+0qNbtHc5IqXMopYuC8kZf+6uqAkN/0VChlKVPHZIMCbchcLoZcNHoH2RY/W9TK4r+E2/zO5Zs916J4b" ..
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
