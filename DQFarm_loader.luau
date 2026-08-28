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
	{ seed = 2730594499, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2730094805, exp = 0, plan = 0, hwid = {} }
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
	"PeGOEio9LKUph8Y6BsJGA5RjfKzSHMhv6BfsndBRvG1uKedZmaH+Vl6Bd/kOESR9EsNIhbrJcC3EHISvu/4nIh+ODqBwUE371QSu" ..
	"WuEW5+N6hZ3SF0FWWLKoOzCV9BjruXHZsZIbDRcJ1Ych0NPY/Z55nqt+buPXi94cpSqIzjJnfOzJyKgWr6Lcbsr6J0e2Y0F/GQR6" ..
	"OIFbCLM98r2VdGdAF2IqOGrW55D6TcHlhILHEtnD9tkdKd/sUfteeAdY6QENnXEsGSs08VQdGdxcvpBEhGr1tHoLo7ExP2SKeHf3" ..
	"/y2JJye7kgWMejOjF395rk2bkGonKFm49oclZK9O0klvq5mf7fdZnp9fwOFAnmZKkNjXEXrqBA6swZKs4W9eV/ZJvELG6obKekVV" ..
	"poC4cuovAiqs1flJaYjhvy2nceFRxI9kk8Y3LWfUj4g1GLMoSrjDaWZI2RtHjnfMOOeIYtxabljM31eBA5ctnQH4QJHi97DbShLO" ..
	"DAPi7Q4vtOYadtY4eT52bfJjH59TRBfDQdUTo+0ses29KZ2S9eEKR2WFWjGrd6/tzZVDRpQpAOYf6hmSud2bYqbYEvxdezKSTfbQ" ..
	"fb6nGe55FikIK/5rZl8DG6vN6NjGMj2vsVH1kPOJrRRF4Ewwrz/KqX/sCEyyGCpGPn87u758TJiInwN0SVYVDTLKxgFAIMJQ4TNl" ..
	"4LWycL2X9I19NY9NaVr/mM3NtiLGCZjXIZn5sao9y1OPManzz90i9usIRKHfl/TeU9srhoQjpLqOTsUsP3ZtQ6OFJPzt5WRaOUvH" ..
	"DDBKcIfooo0qCbwLmt5QK9qiltUx7IaXVjK742w+FmuYF9eCmOR1PtRmknnDTwmmPeChcqxHkoiFplbIhRf87rPdtDt8u5eAlB8b" ..
	"dJYuw+1GYbPoNRlQENl/cpE/yl4ZnLsn/ulkfx6TQ/nuRqw7AzpjXE/H7Gq8kkfI4a/ufaPuBqSYD/dxLwEfKcwlPQx2B+LU0VWE" ..
	"GOEw+zGS1fe5tvjDANr8tnRrQWXaM0fTp4rvqIgR80HTtwTvrENH1IcgEZ69XJqVtbH5Va0PgJh8Im6BQVRpbgKqyscmusBrFAdI" ..
	"/TWE39UfWXhU7w1U/+YVcD+e83FtnAjtp9SLKmPCqtaszGNMNmBI5ZyAhsfY/sycbA3EPVLad8IIw3RrAk1GmU8Ogv+BHZj0WfXB" ..
	"8VXjZK0Lj/yAVQgStdNFclwl0zv3ePaswezwhieocrUL9mspxwpogaJR5f2s9Jk2/TkV6cvB12PWiVcbzKFQtB5BuLgE0bw9XKsZ" ..
	"f19ZmouCkBZVuwDiAtx6Wwyg9sU6eVO1QQuAGl2yeKLFAg7GmrabYVuuoG++EKh7MYBKfwCSmDYEelurYCLOJFqC9kIoxyf3ebuT" ..
	"DrDTkT+Wl1o/ZjDGaZokEhbbJCuc1qFmuAEldiQqrMUyUSF5edhobUhN1P2TaSeHF6oC0BKb6hSidOL78jPJdBT71JHFHDUPkDoI" ..
	"6GKZdn879oQ8b3meQ9xiu0mlQdIiGO2swsQ2f6zMisbUcxdIIH+paCti5VEbu+zLXpHGbxyqbYv6tXZ/IQGe++5/kce4Pk1dKb21" ..
	"tOT2a3Itmc+dlTmVWZ6KBNT34PlbGfIsVC0Sm1szyS/iA99GD3Vr6JBGVh9h76DoeLpcDO06/WTiuIwPvpeF67Eku0BtX+SrZVpT" ..
	"gPfwu0f4Wwa9U+yb5cVLN0IoTXfx7MaArEB1iBrHemPqsPuQDkpts9IoZ0NHfc3kZ2kPKnatyQSGIq14v39uSA2cfyeyH2oPh3Z0" ..
	"c+WtrqnbXp0NRMYjBmcgc8iVygeDAKHhoQ6/NrSEipiA+SPpKkZOZB7khUilRAEOdhiRGsFv8y8u0YRyPyTJ8GuxLSJIIWjDtgkf" ..
	"019C8EO5c5h6OMbmJQUFQaH5FTTYt2WD/f25IgWxmXRlhDQ/grJhDvfIHs76I10kL9BM2WKE5f4+cbY2xBOJaVBmp3yhZkhJE8CY" ..
	"+naZuz5w6fFz4KkTXbLCybnZOZXNGnyiB+JbCJ1p9sk4YVuZie2R94Dty2MkkW40vZqzUe4SFy0tVRirQIjMKdjqBMR0AvtuVoqZ" ..
	"ogHf9sg3VXpTlWCDNPw0u7vBPYHMIpvfuBgqShLl6HRi1QHmAz4/XwU3poXjrqV60ryxQq+PoorHn9QTeFAUEKrW6fQUE5v+Ikhm" ..
	"Fz6vqEN90KKHGlJsnvXY1eBOwISGKE0avRxhKk/k7IwMf5mjNS6iIb2hTGf0hkw4y09+fZnr06ts3P0sx7lVy1lhz/eLkoC5+5+s" ..
	"DJnjhusTG/AvFXL0XwrxHZbcp1N89/KqvAhI23muAdl1XYO0X/x5fAmq2CGUHUDYIQyuDZfGvBpsbQf7dYeNIOlqH5Aclditgj48" ..
	"SM4qT2E2Kb1ZwtRabXytRUn9uCw7vnC42uG20XFcnc3egZgkc5s5BBXiV1sbfkQvXcR7fyYYxh4Qzrugz5Np0JFiy7M5d9C1/4S3" ..
	"9u5pM367vIIYLadrazMNyattesvDaexhF4hzv5QNjNT+cEsjf9ukMldyUBk3unLLFSEG8qjnOtey5PvuVwJq1SZgTHwQh655YN3I" ..
	"bhVT1r2e2g1goachuzEzMxgg/L9c3Lexyt9m0TdV+WPIoip3oX6wunpAFsTLVoVO7WdDbwdIZKv33W4x5Pnifvz28rxrvsvroekX" ..
	"VsyXGK2JNIAJOEyDRn0e5Uxb4a6/oAhc7d2rMtMXAy35n4NOb/pzOqilUFe63+gCIzrynXvnN6bYJsaMw9QCXjM1jVs5KTBGq3T1" ..
	"zF/YpBPnmZJ+Qhg8xzU5noM8fHI6qpBB4yUR/TBeTuVzlBmzpr1cbAazNvPMXI4tnDNr5riEE2SeWv7/QIFyLLqQhQdQgSGfAMma" ..
	"pe/ID0ZVYz/ogfvmsV5FVFiYuxlEiKemL2gddPo2FC+y/MyT7IufpIcCNxTdjkFpPn9kEX88bALz64ZeBMoi5BtfWOsCJuXVMLtO" ..
	"Sis48a3mWkyRAxTylmZ+7C2mPUME1YBQMMf7Hqz5spHTkOnhao7m0/mJ7eIZoKQmcy5aeekOok5FvG3S1cTMcvPJk2N6LEwwgPQO" ..
	"vJQ2tPOQdNDF013Tct14j7I2s1ZHwLrdP1OdEfYCuKr9oWgEb+M/sf/AVhW45++Ca5bCvovN9VNmI2JcNfFCrr1PLLOBlW9S1HHU" ..
	"z0ytY2/zK6lP2dWYa5Wrkkr+2TH+JSt0bEHV7wM2rrv+wDopi/R5BAgoVMWiEIDvvSc7mK6wI3cnERvqzc9SYC1+98nkv6tsLQeD" ..
	"SAwReBb2z95DERtmXFY7qlpETiEgvrzAwN9hOgR9QwrLBfJc1csxnfyjKWhDlotB7ZC7KoDlMPgFGKf6AzooK4jgt2HE4Z0Mc9x4" ..
	"YjTMD9r7ccXUQ/G/sUMx7+SRRySlnPd9ruH1cr7Q348A4gtIS9/4Go11W+Dlm9ZE5/RwKlBACRjlyy7f/qe9w4tvYpjPn/F4uNN2" ..
	"L2c7LG2nncgBIfFCDDHNBR5/c99xGaEPg2hts9TI5onwMj8xUee2/Y2bFKON7tdpGAxHIU1DIX09rf2OlYkH82TcCndYoboJ26ql" ..
	"FEqF22gNAgl6XOcbWL5ehgOAnY7BaOUfpm5hRu/cD3+6dusfaUzzPm6/vr/kKrL+OjgrDt3Uorg6hVqyVixjS/nJUGGAJEdomCb+" ..
	"EZE2398l+XJMdqpZprjdpoBaRHiqqn5W4D+SH/Ta48j2YsTih2nMCnFP5NK6bmCvGtmZX209oHo03CpHNFV+pLdqcL9MOp1Engzt" ..
	"t0Cthi0xNcQOMpPhq+w3oMDsdVwQ1OEOKndPKPcMhjY32HESx83ikz9KhaiC25CZVvGJ41yuTlY1ERdRsXEcN8NG/TU6jfx+IC+I" ..
	"iAnp8MIB8g688GtyNO4JALZCBV7x2y5G0jGGtdwrxNJHcmATAcPlt4/+l3TkB+yBhPCbD81q2dnEtJLmmFQ6SQAfUB98uM+rZnmG" ..
	"VQnrKRXv5N46m69rHnGbJR3h9td8j+c6lVozEKY6VY0MBJ2gOHv5qUALYwXojcoYk17rZiXNw25s3UTEU1CpxgZATxttOzJvFG4+" ..
	"sEJCbvVyM1x6ZiZlQCpwuPLRoHiqyPqTdXhYxdkfyDgBFwYdzNqu05cuNjE6GfJG/pM+ftLhZ0Hd5U5pxT/XX4tTnX0Evaor14Kl" ..
	"P9ol1oWdnX56Z22vwWBrfxlfZYrkBks41dhFRgbOKlDTruUOAEiiRkF7RP5hAKvR15U3gnPZxiNqDVJeVoIkS+c5tL+xCtujVROl" ..
	"PYUx5LuxAez19lwIqTT9lnHUI6zvxqvv5jZh46PJB8/RgtO8ZdmGYju5aHGtUFo0bHu+d/H8pdf2jjcw7Jd5YFLrpp4VC4XR4wY9" ..
	"K/ZtphPkO2C8y5VlhfpzTk7DiHvruSTidjHaDQnUYT7oQG8OG2q0hRR1GtYmhwTqZct5qu2U0nl3E4exdX7gQ3dbmgjaSccznMSi" ..
	"TMSXAoaBWWV01D0Fu9F8iljbXr2amV8lAC0OyOsCgirtIWcNi4H3ZM/beo6IR9a7ifLZaLqpeJrEMNqL5TD9967d2R3Oj61nxf96" ..
	"W7CPdgeY5yenrM5XkouBQqQZAYUei/g3lI86dn3J6GWxRwmVqEbcKpcB2Xzpp3iqTya58zmhaytE9iqhjHPNMH6rlma8KlDqHrks" ..
	"n2PJny/Jc6jcjCvKNjNTZawOTft+o4Alf76uGL+9QBx8kN93FQby3C8ag8Qlyx8h5PXaysNptDsGYohYl1F/Gvpb4SKa//8ZM/9e" ..
	"MctTPZy1jfEjTtKzvIYRyLYCMwpV3Z4l5pb+UkBrTnbWmkz2tnjMabZ4w6ClhvFLNJsnVMyJ7rwfMDBAPUw5w46tSmpyz0lfnKQG" ..
	"kd4xj2dmNNAVmQUuxq9JQZ592VKVFj1eASxw2WylxbfUv7rf9xD1a27+5h10Hed1YzAGPDXmZpO1Fa0wLNnHCEd4O2EzKoLFbIUm" ..
	"1w8Njw38N+Egmx3+EcsAlbCA+y+XrPSkd/pbWsjfKamWvpGekex+VDMpdjkw1JH1oAMujzMxWj1EE/8iQE4McSxNjt/tG0SkKTkr" ..
	"6cvcrkBxOs0eV6yoVXd5FXR7zIDb9Xxc0/vNfniQo6fpmojWRCGEnZj50E9tdrUhJh/tkMh3/HvV/Rcs7ZYwWdKK9QMeckveLLwk" ..
	"tGV+65UZAu1C8AqmfI3ah2eyptHNNQ1Dwyz13lNXdB0x5g5Z7yKq6Gpp5jhZQOMsLFOtj2jzrSbS0h6nVqtbtOKj/3NJt+gDyjzB" ..
	"EZKGFA8J3KPaj9H4vSDtEqnm199CzsMyoWwUxnxhVfz2W0XXcI+gI8VkOxVD4Qoz5Tz5HSKZE1W0uznnrCiaOFz2kSnvpeWtIKRi" ..
	"it99ykjcIzgZ/IJk5S9MdY8L9L5gx+twm8q/ZUEUiniAmCTI3ybIW+XOUiCf6val9+fyKOLPZ+H1nvxN3V8ii7AHAfLHV96Z0b6y" ..
	"rgdv6AW8d/0x2G960TOg6vfUfBorXvfUwLJ8MEnNMuHAGUqVOT/whXzZgL9ogFSx2xOb78G2Sf3fFgTk9o9tHgh9ar+SovH1RlCa" ..
	"fFU2zltd0gdTUMHgjk/aWHbWpsiUB1VG2WrpYdB6u8gsaBtUdCPnjKu+jFIdXANSbIEmwrWZn6uY8/V9+L2ORB02wIT93dPHBNTD" ..
	"pyXYUqDsMUwo0DE/iC0zIlVhJUVwWOT8DB1BLbDjliIuqMwmt6pyeCbw941A+tq0dmH0jwZQghNf5dyQT/5Gvo8nFN/9gzvjOGMr" ..
	"AHJw1bAvcLLJ0T3T0ep0wVq0p8BlXiwmXA5Mi/APW86hQ0iLKH+KZWmfUIfKSzSoGtzEzr1mCIhAtUoHQOib6gtps/M+9wP6dWLh" ..
	"qOk8U6ZJGl7lPCeSDYS+cI2Q9L7/M6McMNAN6R2gAYYVJ6EFClvD8IrILh0idJRg3VZ1PIO4/XG3c4ICuSlGzpTpCNj0s7avjx4Y" ..
	""
local PAYLOAD_P2 =
	"vcaLzTm8hCbogWpWMNjzPVqp3KzSW65Eu6KP0EwwKGFApB7Pa0NxMsKmLhopkFXbWcvKJuwJrCU1uFXJ7SJJ8cy/QhU15gCGJ5cF" ..
	"C6iPm/zyHzCqUcJmOtwTawJDeRErIGWsVlVFfZPeguMTDY8MHwi4U34siXyTj6LF4zev1s/V2bvaXhpPnPjCyvcHstdTH7oIsf5T" ..
	"cuITx2RwFOeopjmMs8nPba/SFRJZgiMQaDTmxYGCRZcDWfnGSLdRwsjzjiMP4EkphhRczged09hMUaHUTPhsCOhHkNA++mz6Ipn0" ..
	"79oRufmOfoUfp1QzE5h6dYSFf6TxGhJmQ5b4/M6z4NOK8A5mXr5hmB1JY+CjRRctU4S9NYvEifH1+RH0Ro6E+ep1GlYt0sd+JUIH" ..
	"RUTG0t7zYBOUAwLRy0RPQYmQw484oSJlc1bYXedgCiM5ZbKJZgv2Fi/kokRehbntwOyfHMDtoq1dHxt3GL/OeRDd5hJPUcYHjE52" ..
	"ZoykXDmcc5UwrRFNqc8ozEaD4bipmyWv8wsxR5iH+nnx6CcTHJ4LpE1YiDKDbiKHwnUQmWwDan1Xq6aitUx75fxnUOSaactwVz27" ..
	"8/z0SUnlf52jvOiLmeNBaU6TZQ9aWpSPWPlbG3/VOrSKS2jyz+v1dBjFaSNsZJZOCVKKR4Ie6Q1Whg3oEpxvwRvjY/BKqUjNqhoW" ..
	"E48iNpNMlxHRMWuXpBqt2ugCr5Tv8oHJavfrQIp0mu62WLBXhNSjWh262Dw6QB8MFj8cUQUL/IeBvfCpEd4aYvd51hFFdHezKGfS" ..
	"fBYQyvu3aETEEsjsWfBITqKBaIFpnR3qrrW5pOENszzPEOpGvpFaUAAArFxkyz94QzvlFlcomsfYuawvsAjDLWyP5RtcQmgYhifM" ..
	"MgIdCi/MtKmws7Nz+Q8pX8yEkvsBodt/yejrZRhfXMJG0UL3/HNqz7gGUWpMMOu0189DZXDe58m97JSRWqngglcrckUjWMZXtMWx" ..
	"JlNvJOHVz4T27cfSV94MCdccHGuiSNQRO6McC7M3hYQWYbpI6+QCx7XDz/UB+IKViNLcO2lIPKvr7+utOANZ0QrIPeGW2El3efYa" ..
	"1AnjZbPhkS5RdViuXSvVXjEUoUE8Q4ORm6GTmQYo44oFpvycdDQ/wGA+6/BsaBmzwPITJXqNlON4dFO4OtXdhfrj55k24iOdy8da" ..
	"Ybbf52sU7G7ov7MMiU7Puyn+oR9ripa538vUc0cczF2Qei3kmwpXrcSPPrBD7lOQwSVQP7vVTZhetfsVP1drjVElbtDMVzZhbGeW" ..
	"AnRwySHWBOylIJpQ4wj2oUh7hrR29jQ/Kc7Gb+TLF9AlPcQ8njSPsMU/406M+ICEe2fBriI8LMO31kZGdE6XJarhIUJ1kxYbDI60" ..
	"lOu9e6Z60/8GX+hOhFepXzl8njwxFYMHBhhMjetet4o17wWfQl7YIE8k2s8AH4P0p5u7tSHS5vOsBWgx3iZkQIoWsu2BFrf9yWgD" ..
	"tPG19HUMWSDWX26WoOA5mC0sdNsGqdfLETHGkQxOCysAB6A66H6V+Ezf4/bc5RdeVz3hudC+NlWvIpslbTgEXxxgny+7q1LlkAPV" ..
	"9GCIHgayfqxsZPAXXfQ+W3oE1r7FAYLq/hO9WdRwDTR8M4moy/x1HSidR/14mNFyzj6OiTWNKnBBM3+Eo5axUs1W/h3acVvuR2YM" ..
	"1R/xxDpS+O+ewsUEyt4b9qvc1cVPqY7V3M8CeFO6CXzhXVhcPCo5kiG/+tSM41VWZFt7ltliwv/pAIAj5NcHvVTq5EI48txT+A8u" ..
	"e4Kx3U3KJ3aj3D63P8QX94k2wTEkZehBE22APUQxGLbGgMIKxWgBZIlsCA3AQgDUYpB0abkFV61RYqtK4MUlCjiJiAkd/5wsRKd/" ..
	"qm+iXhrwXoWelSplN6/jd1In11tAkNyWdcJEJVINA8mjSMDOdN3N34KfVt1R+TRFH+gMV6N/rYKxjDJx1zrz8k7BqeIGLTQnY+gB" ..
	"gNvj99B5bLGRRIFxiUEIap6Z//6nOKSYA2pEwLn1TW7WImgzwEufJEVxVtosAOztJi8/N+HquQ+dQX5cznqeVrYOSl4fbMGogVLV" ..
	"67gmgaIYeRxpWjVzyJCGieSq0GwJhOWdAc6E6fLA80AugHEOwb7MEotBRQMGUd75dvJ7zk63zMOahr/5L7qd62+ry/PcKAw15BCZ" ..
	"odwYaHO1L84qqT7W+h//Sfkzy8Xc4QcljKIXCQJ3pUNeCN7jQ0wF+GtWYmzD7aQYMSN/O8qNMGsFsKp9o8+a8tXgtr+AToOiDoOF" ..
	"entaDq2ymkXaCB5m5C/K9z9bAq1bDSXyO4F1gjWjAGUFT70+zEjVeP04rxqKE3m21QKPGhIOk8tl6CMDJO/0kZtBPpEQq8RinFHt" ..
	"frZB14G2D9IkVTYza15lOTZVfOE5725P2DFLrcZdn/YWZWHsE5ig82A3NZx426x3a1Mj+gg8/8lfsSat4hwFy9XDOODH4CYQH+yE" ..
	"7lpWkmbKWjegRSF0QwKY+tBJdF6yx9cSaWBpsegNle46JCDM52QR51XBSFNdlu+fNelnnjyWENx8UO5b/HqpywAeIpHqF2jTmS0r" ..
	"gTLi64AzU6mMXhY62ApP3Aynv6h6PS9R+Zre1nAr1XaEAgPcxRlEjak4vphuRnEce4eVrSaStVXm1cD2/SNiCe1EL2wWAIdE+bY6" ..
	"TJGNLp8WTv7pKfVgtJJ6nqy0CZAKkBwETgULCVWa+/sZ1nq/rqekNYeHa2EJ8FDy2Fmeb2nm15PnmPJiFixIPc8UlsNQa9OdkCrd" ..
	"r1EOKz+LAHXrWmGlLJAGom55W/KMgaMk6hXqprj1zgHWqHAqy70OuGyrFq2fIGCcj3yX99m7zC/SvJFPpWp39IeGvfJguO9if9lt" ..
	"JCZOEacZdMq690VtlO6buAP/RCKY26r7cU2JCP/SgUlS28tlCLcHoWf0L0ncD9YVN57zMkVjOxuPKN1q/iycGcD3sTis9JmvvjuD" ..
	"lSTBsw9HNkRTVIkoHWI3g1TmhqHaaTgbipAlDef7+Z3PopizXpukQigx9EOOZ7BaBSltrUxhohQKDqCaMOfNNGMAkd6R60/6gmXx" ..
	"xuroJvIv6oIE67L2Bgevxy34jmExk8vR758tKIWGxh8SzCjfKnlzGOweXWvAMhWpxPFJBvtotA1K2iVHCVKNfbzu9+IsoXK5IDmG" ..
	"zWyY+S1ln43//BWDCBX60CHKiE2dYe07+TcytVDCO0ZNyUbknZu8Vw8RzVUa56cj0fx7QZCNN1iVwaGFSA0jdNyYE44JLf+U+/7j" ..
	"iuRh49ww8Pm83lfnwSn5zYr4YHRgy26bAyluN2mUj9rQlWFHx+fIss39YCLnI2fzM+cJNHWfImUAU7Sqjb98CG821HVBNgPcGAv/" ..
	"LPj6zRq42hy3YGDL8lEMOzuClC/Y8fVFJMJ1fPgBmVTi7OGyY7L0E52W79pxOxFtmgVjm87Uv5BU+oQIXm3M/R+Bxn9qeTnvmmMc" ..
	"PPdXjHGiEHQvwnU/thWbf3L6hEj/UE6DiVFoWx1T0OvWhdARwZFJ3c+j1J1w7cFiS4+0TiYfCcRZZlx9vxA+2Lki/jayf/XK9xOT" ..
	"hufAbYyT9MZeQ424rX4sbwl64gRAKN0lb+mmlYmSJtPv5pDFwrn6dDmtEaNwuZ5HcXsH45jrmkLjY4cnX6HTLJCsYkFmJaDvdvVj" ..
	"LBJkji7UwN4yOeqxcW1uTGrTfYp6gDcPvqwqbeQGEbM9OgcE4/B017BqTJMak1uIAjZBuJ53quM8UWS10mWAaobmPobZCWa25ZA2" ..
	"xzgcYHf5KB40rdLVg/CMueOhgAXmZ0CGxCPYsKsTk+3A1KDchImHdHqrg21sA8clKcQ2vMyWHG9+uGyL2AB/HQOf+fc2J0zQme1R" ..
	"MNQNcNQnXtnWjD8I+W2WaYW16dTDK4mUYr2TJ3Eouoa88YBtssOjSzgl3q38eQE7LQgOjnfanGYKq/3oRproZLbdpe0ps3awYhMy" ..
	"naBJ2/LqQ4Y1iFkLrvf4e6bp4kNDBL8z+XCs0zJaXXGzldp83TksGp8jesYrFLFILdBaJGGdvwczsh+Z5zfgz2J/6ySbjp4Pc/2n" ..
	"TMKBB6qHdkzn1Q/XQbZQzoA6sOo5sc/ohZBqlI2/Fst/KnNYiybJ/vuZAnY1Ko7CEad9twcNZ50UoKtFuj/tN9LxO/rY0hiTm/HS" ..
	"iIAwgwAkTkzTmUECLNVwyGvVQiBY3E+S9htvOSA/Ot/+hVhn8MIU6eAQrgCOVN6lzT+7rMVhdq2xukGoZraNrfpwLf9Rs/NaSScF" ..
	"yARIEUcdkStAY2wptzklnSlRNdjQhQ2uouv4bx/D6WhrUkOKviClAUlCMzIWA1eRijvkeaRcziUTTNipztGzQQcQf8/yXctmKCDB" ..
	"IVYPlddxmbJM04GW4v8jRy4LhYJdw2rBT4DNLqbSC1/WliFbDe8kCst9FPR+0/cGihZqcDx76HdmAXZYewfP+YlYScJA4Kj61g07" ..
	"75ZF/hiZNFKlKk7lwvxuNaggq+slKHBy2kyqGLQdG3tnB1xSCueQJ8uqNQZ9t5AN69A16ScYoQXMyLmh+n50C1yhrFvcwBXfQkIW" ..
	"3dtBQ9z+bZjsKNANDqRi2qshtNmUPnTabr4Wewl3BNythME6WtszvHq7taz1ynwaFsuBVLtMpO6zAKyXZE/xfpYRNz4+yHgFgqha" ..
	"XkW0h5euv5Mno0Y2nAaR0Sh87UgnkCCh2TtP1S7OV409KPWWli/aCRH4WgtL8za2c3pKpLFs7hdFyCbQtSFZLvoOeBjNVt2IaXQe" ..
	"QUkLzf2du+8LwUpfUgzU9cmYOESzg5y86ucMNlENkLGnUBoeCs/OFdL7oktmKuvPeUMXFd5TCoGjuN9CXaNdnlPmiz9t+pLtQFq5" ..
	"1TGs3NXSMtFT3t/BHpZUyVZgqZrSWJBM6XzsBZlYfWUex5ptpY4oT7B5DEq5QBnRyHXVjuh16va7uHSxw25jSBeD6lmuoMNFWmsI" ..
	"7Dp22Pa63ZwRRr74OGFB6lps5+WHCXhnPDaXaBKS620oQKe2JdxaY1iTE7lJ5CKvJGTPj+KAzhwSiRDchcL5t0R3cGUyBMd82urF" ..
	"nm3FWm5AR5bk+fnUQEQ4HyR9KRJ8OiBLtB4q/J0SURA2Wqg0EDcqAKhXIUiZwy0og8EUiAFjH1z7CZczuY+D92kbw+vXqK2C77nX" ..
	"Isc/nzf8IU08638cnOmWCCQ7JI8LLQzte4loYkBNFJvVRCJVbtmVVrN/ofXtAVKDz+Lnq4n8xnNzJ4FpKLUaRkNJN3A0tN8cwvnM" ..
	"ufMAJ+5ZzVj1aF2hMTT/+Q02oRDPbj+JgAzzFkWl1+vk/YYz8hpcOydpO64BIzC2/bShZ+MJRFL4dLbjj2zO7O6ZAQWQekGjfvnD" ..
	"78Db8/mA/1ogmTCjw6hzXGl+kKKgLXKrIR9nJJdkpytg6BUWmMNSFksR8zVZSrlvHnvjyFMDRQUN0GpCGmOsPiR2mCsgEm36V20n" ..
	"TeMr+pQmOIevAUuRgxES1oNk9kD84rBGEO2ijFRuZEj6BbMSM6Hn3lghetqVxWg6sBbUdUi5RuhA/ZcQUl3MPJeuA33g/Hgntn1u" ..
	"Jvfn33Gmj3/YW5yXLrFR54NwPCjovydu7vRQb5++u+xJr+Bzl84FYV/9MfvmfixMQgR2K40MF8Uh85IMJqX40wcGcGLbcolxFNgn" ..
	"sZZmWoov6HyalCJfV6ghmFfjMWV0CI46roLPfP2QpNqi/+NbvV+LY//RRUAyCx83p5XwkmKyH/DLZiwzDItDDNLWwzd95TyND79/" ..
	"rNY/6wMS2ReRi8UJoByb7H+4iFDh2LChRxxDTofvwLGBnSPjxHgEvP7EvrwHYdwTexx5hDp6qMVMDxjNHTgTWk6f6BTs7AiX/N7w" ..
	"uxf6M7i7VtHlgmkAfmpSzAizEqnhxmJxgcnYlMusOjaB5B2zxAnOwvfqRudjw5Tzt1IRH33m/Nezp6YFZovYb41nD7lNNYYYVYUL" ..
	""
local PAYLOAD_P3 =
	"7yC3v3HIZV/N79oNUMHtnNevedebvifirDGChd6spSnuE7qXCvXfvDKfxxlBvKwf3bH5y0kCdwTEQcKnvAnugeWH87ovNbIFX2Rk" ..
	"I6Yla/MsydzEEk5npMXLvCAvHDV/MSsRe57T6KFHirCPiJrfl6g9B1vM03KhLevKErUjF+chCJeMAKEHhdT5211uObRpPUeDV0Is" ..
	"m9zwnL6GyasDzOt0SS0Vn4Sozi60D2e3UaJyHZBWbr/vu917xRyaN0qV7BdJk7yKfc7taQFHy9zeTN+kkdSmz/epWii0o38NSy/n" ..
	"6EpYx+UlvKtBiV/eC4lYk3bWGpZoLh8O/7+uPXClBB1O4YUN2oqJ3lypdoH7efJe32kNcd8HowmwZYQdsSBwW2qX97aG/eNCRh7Y" ..
	"BbQlfsPhYTQzNiC5U/uWTD5aikFmEdLPYfYx8CSEz/pOzc/oFTe7GCH/x+wLsv3x5/3oQtkQ6RGU3i8IZq5ryqmEI61vSff5nNw0" ..
	"qMW1lgdOxJXt+tBL40FwPdArFjwrx2KVHKW0DQSNPj40+OPpMfBc2/EcaLviTuKxdKEaLdYEYQEy64FMbLpSoFMy/XyJOpO3Er65" ..
	"hV9JkwIQLPTS+/Fc8KmQWkRn7y2usg0DRQaKITBAugpf1tB0ZYFRI/FlWopFAl4wMZ/MEvi5s42GxYzGW5CW1g2ZFb8fONt6St4D" ..
	"RELpSSFrfH6REByeAhXRZiiny5rF0qhF3yCUMgByW0pH3Vch/a1neo2fUx1A/8NJIQuPqLtQzZo1t6eTzhVMranA2rPIHMBAOUWs" ..
	"OHGK/t+mFFwTf4a9E/6n+y2ccHET11gtqd+U4zbG9pa8JDds8n2Yx0D10ZlYl7vLlMqFlcogNGZolnSzfDSPPKLXvwIqm+fOE608" ..
	"Boeg2osS6Y3QB6L8yfBNJ5tDZAI4xe5uWudHoAXqUJlpciZbZIGGoL1nSyXwI2ExgIp18bLXjrncyT+ssIyM6rg6QrVq5FcZTF/C" ..
	"I+3ijlKCGYITIMDnWeJI5hwOYcY7eoKxSVOgdl2pJihEKKyD+ny/cRB35ELr0mjBf+ElIIEuNlwVYS6X+p22ZDJN2Eq448TTjsVp" ..
	"aogLjiAjQ6TFEjeCXyv6o9dIUoyr8bZ6zMDJ/qtHqYm1SZ3ZR97IBtyKI/jmJhEOQxUTGAMMIkouCIWzdiHaR+wGyul22U8Rp3UU" ..
	"V5pn7QwZ+yjWhyk0NWUFdaBhXg8f7W6+f+NemOR3ljju8QM1jEK+opKw6V2ZqD/x4W80/HDUEO9nVCOB/D9YZkeivj0hBTN5Gsjf" ..
	"s0AyL1SiUmEJan9kIw2kZJ+NT9zZ94jp3hB8AC6hMMdC5NtirvBtEbWtqhQbsZxTgC08W26uoxKWYnOGIPzTDZzAuhscY58w+9cj" ..
	"llLLjZ7pg9cxtz9JJrm6v6bWQBj6JZshi3ATlfeAkjjpm6UDY8KQkkymTU7IFeyuFsWKDuu97HGaH/QINeRrtbLkxkYbHMOLw3eH" ..
	"UhHsxM9TNmewh5jdtWP+RJ66CXECxi2rbbpfmL/RHMciwMtH7lX6lU+e5ydMjYbDXWHUj43UcuBOgWlYfrBwS1sivq9OriIXEfsq" ..
	"rd3eBqtmWOdkK9CeQmT9dz/iK32rHFQOGpM/fPTZXtA/Ngs7uhQts5Zf5K0gQZsYjKgPzzdGnyO7v8d7MrizcKvNdc5ns9UThFn2" ..
	"2M/orhWgXhwvSsbWFXfEKCUu7EfUMP6LMuj2RaGz6qZunYTRjHhjEfU1Og1pcoUUdDxPCVoJwK18glaE470QutMxLow4UMJLXzHM" ..
	"qRrijtMyszTaqEK9JVVlF8Pz8QtR8K7YKmKYW3tMCtkmagiq6TIYO4k3ODlEMJDL1nXbftYdTn1viqBjndhUW0Nu1PPjTBwzFMwu" ..
	"yrsdTrvbXplmdeRCXdlFXZ3xn9F3NU1WdUhMgJzIfUVoPspHzHvTzWcYUZb97aGh4D6GRnUOchT1GqrAr0WkFTFliKJJPBetH8b1" ..
	"bKGfVNFYpYS33xc6priGYDszmX+tYSKEeKOpJnYkazbLTR/vhtYQH8k9gnQ8fO/3ZDXibJxSBPzZMxJpFlS3koce1OaElRuk0OJu" ..
	"VRNhzNhUmvrqkxxf02H/GWWFo/E4d9JpT+dgEpijx84bR0037Cq5VrbfeiT96WOx1DeuXTj8QsLXs/ZJfUec2/tdZDeafzpcYKSj" ..
	"1+NC/Vyk8VgYWIj+UAU6WCDQm+MoyD+vik/XHkPWI41C0bUEVRvdpCnYp+8sPLiAzC7dkg6xyQyYHoMERarU4qnIaLx7YrVcH43z" ..
	"LG8pUxlW7VbNr0pB/AdhAIhZI7ZsVCNx16DwY9XvMEnOep7M+0ztptnKJsp9aqIgrFpgHFhJXHqIMt0WhB7Po0UrCaBmeq/Vf9u4" ..
	"t9yREc9iSknAq1Ufn4hbiPOdlzY90tg3G7YkLG62IDlfMQgtUxx+r8Ysz4F2E/3bvJ56sfMnsFS7HCRyXhmlZ/r9uz85LoVRReja" ..
	"p9oduWnhcGEiGTNncDGIp2en3uZzHIGtV0MRRS3KrmZfngn1BqtF5eyi3ZMIeO3N81+jyyla+8pbyzgWPMkxfYkLKIBXit1tAsL0" ..
	"Vojf93jXkroJ1Cw0MqnUEAY7NI3Runnu+uywrQXleg8l7bZrPuaqbFk21hU3T5v9oWSQs+Fg+KNtl9k47lKVz4Ic/o6GXjNjoTaK" ..
	"E+WPfvQ7Pq0eMulHNp88qIfMOMfYS7Qv5h064+cddTu7xn/Q2ifOKdid4NXb8bEx5ZnND6TQtIp5CwDUzUlKiyqIO4bbmTJntanZ" ..
	"xBBd9xSCViXosNtg5a27jOByLbDXt/DQslR8+EVLQPzc6ja6Gz4Mi4PMEySCQdkguz4sOLoowqKKlmZ6aiaP33CA87MkdrPc7xrH" ..
	"ETHVz5In/c4KNXa2A489tuU7XVp8n1gZubU3oXwSnI7rDxSYo70B6FAJVNX2hafu7aLrUodj8xAir8Tu7COICTAk5AS4sU9w8Sym" ..
	"suoxZ0Ol5Ch418y7/xptOb3NJb6XspfnPeib1IEpWR2r8X30HQghrIilAthdV20/7cbCDkgtF9sDCBwZaMUrdVg5oJVVO4shIQV7" ..
	"qkLfRvfrqNpgS06FO5nfEtEYYctud1/j6upDvV996o1cptAsT4WWMjgjhAYJtpYN0drFVa8O1W8VYlN17rv/dIVA2XJFWw8FjW7P" ..
	"ERJVQXNz5HSJAv04NA61Tf8kHsSyM/urbUgE7fp3Nz4ruhXUAMAkDAf2xX4+8jJwkYULFyw7nEBDULgubuj+ChQTyyWEq+t4b2cI" ..
	"ZacGCHYDe4Yjp7/PbrwvAhJHdVHOSEYMPKcElZyOFEgdSGp/gpyq4jZW8+NTxsp+8ceXL7riLeXrSPO7gEMZw1pcbi6jzndbg8ep" ..
	"H7JXxBRLHQ27dcI/mHybxq2r/JmoFMtOSjsrGbhLhVhbHxxhQyGvpdkinXS9J8IBrVDPhUjM9xPk0aZiVfUK++jupKOmW1frdEay" ..
	"7U1N8wgadLZN//cMas7GkFVdqsIWjngljB8so4tw1bHDGT2yMq9VQoy78kY/hf1SBVk9QQWAS6LJpirMwWEiLsnMk6E7ptJVGLhb" ..
	"l9eJKBmVcsTLn/GoIhIErcl7KOvGBjzV88k1al+Dt6P15M9Qhoj9cnUgfrewYe5SWf0HkK/eaoNVTzI78wvaZapaq8cZa6oiPcCy" ..
	"LiaKgLaHbOx2xk21xfkod3GzZK+c/Cu6jTqC1pVi2G/XfbkGYb6Osr+r/qs2gqO5o5NugQd1034T2hOjGwLpuNlRwMH/Y0xdQ1S3" ..
	"GC4++FASeX5OJ6RKLCqIgmOjDnRcr0RHVybL9ik5YaxAyTPSX0Eygmb5roKhwT4UiQ03dTZsqX3AYFXHEhrIXJ/T1hidFcMPL1FR" ..
	"vKuJvODofJVVtLlNxmieE+h3dZOEJqllv2NzfcFlM0T+1s0Vn1XfnNaXrM+CACqk2iNqRhd2evtWXz78Otr6FCXY28bfec6NSg+b" ..
	"u8Ymzppu/T3RxLt7GK8rtoscNq9QhucRNJNBUcxd2uw90flestorM1YCzwp1KiBzmlerj1gdQAm3PDYW8QuSnRaMyC74wqmLsy7U" ..
	"n2o9Y5K3iLHS/k43lLNx3bVnDn9nN3MqrkrV+OL5SJJc1TjD/r8F+Y/cSGlkkMoAZfCBe7oYpgTYlmkV/JXEP9SGB8U+D6NJ6kfo" ..
	"/cQm+Ai3LB221de70IA/UK/57HKmP/ZEg2qx+xmX/HnvTHlK2VvbAkWfBoqSqOiVEsA9GaGIW1jDYwCg8ZhEcH6vQEwET5P+yyxO" ..
	"wql9gOSfeuGl+ZQqpB/6kz77XDk0jBvE5sqHMUxJ90kDvmKvOA7M7gYJPWepUCt3aMPPYwqx+ZZ72NAb+cTrR1nrHdftSk4v7ANP" ..
	"FKUwrjk012/8JPAxcuYiqGKElf4BP8NIqg4fVwQPla/QPRXxVuCxhPJTog1yTIuIyAvKiO4LDZ2Y0uNFyB5AOsuv0scuJMkubVRN" ..
	"jRKqZRvYQz1r9wIPe8xh9MDNeUqnoaoH3UFhsQPsYLIw8lJ0eS3UHDqy5WaQs2LaUdAtEDyFWMKgbl2tEqNswZw9tVuoavYoNAr8" ..
	"Fnf3mfP9tamtvJO9+w/SDfD29KJ3shlwaqQUqtQSuxyZI6VHLbzVBnyHsGAnBmY968mdH2oxadVN3DAXVUtPe67qBHhlkMpc/+P8" ..
	"4pxytGQ52aHudmntplgAP8y2Mjdq688KQ8UifJS5h0sn3HOp5a1hAV+pgAuoSFd6IzlC0XsFNczriIHtgqsjJUisYdRhCAbYFsTc" ..
	"Gt8T2DaX8rTT0pUz01vyhb+1vlldhVggN1ZEtdgb/rD2qEhrnWn0nqtXB7YpSu0qoYG9CZHfFz+Pp1Cz5y4gt485EsHU+kb8antp" ..
	"5606UaBAAmKXbJgBEVrcn3ofOaGWWjOu1WGx2Q0juSH/3j8XaMFJ1fD1QifQ36xXHeC/iPjzOp7ip6CZQcGVGJ71+bnqZM3A0hHs" ..
	"1nnaKfLte7APEXK7nvVMHEb9fZQrS2KBA+olU1dgbZGbTfDjmPnL7+XQ/Zvju8YBIfwPIeCeKNncPkxW1Q3ywN8S9Vk+Cxas17fl" ..
	"4eEx1dWqiJZN0jiP/t0V5ydi/dPG1Ow6H9rnTfCMAQgfdMm58+zuhLdwPX+ynKYLUw1Gzv1mJ6kV10U0vITEXWnK/nuvXtpNOjKX" ..
	"21psh6uYTY3BGgQQ7fjV6j/Logl03Hn/2P2DGfkdq89XYQetpWDv/7zomitaC9004rsKeQ2Xg+QRec3C8ZSahJ3CNTysLcaY/9m3" ..
	"gV3C3mExxAx8P763ISXouOZenYfeOIenRi2H/Mk2oTborPTZ/e4l2iDQLAEmEEvuS6BIj/A9T3NMdpnwxqtSTWS0ak9jEkQC4U8m" ..
	"5wsaSdSkMFkkYgfJ+SY8ehdlWXsy3RD7aRzeX17dTYQdmp2U7BhZSs3EPA0grBNk8kKbKDDDcnv5GpmG33wU+50NHMyyAVWvMgyb" ..
	"HxGJW/ZG7drZmGSWUSJIlqyFPfsTSuAIxm4yKXy/YImU+O9RLBDTLChF95FSC4tfjcAkVKpsBv+Bt/0icw1tyaEBcBdJyhgkyrnE" ..
	"oJBQ8GRHH6rC2qsdZpi8/nY1FfOikt2hEzdTRApwvkHZGSRzTct8VglmoOqDxlAmo6ljd2e7Wz3uTQwdThGyAfH3FRdjhoov2S9I" ..
	"WItuZdV3QLIA6ixNkvBQUKw3PlE88gz1z9YonkTiyVwCGbbdNZkim083F/6ueQ9gMD+KO6b44dTDr6sJ0K9y5+P7KxBhR7GTV2Og" ..
	"BDzz3OcKkWX4+36EjjF4nvQfqvVTl46aX/kGF8W0C84eWXjBw4xQ7UQ4EL3YJoeEibbQKzw6mZebVJvzosLpNVvpmIr9s07YT6FS" ..
	"ecg77W13mEc46H8K1FlZ0AOyqq97RuoqCSP7NuAbN9oOuuanBwsKnQKhxXiwMzsldkGUzM0BXHm5gv+zGxfogU0FiclRXTaXsgj3" ..
	""
local PAYLOAD_P4 =
	"/jbHKQ7vVJGWKR++hVwx8gzBYSE5HnGjbCaHbniBExKLZujjgVN5VvxM7dgmTfUOu9v+lZdpGD1m5UU8JqaBsBL3in+N1QJq04mi" ..
	"s6miYZYksxCAN/Xy7pIkZNPjoPRFphhIoVo7RWiiBMgCa52H/rM7S6TtLVTpbwxjBhPw2jSIhuHBIheJdxVO6UViNTLD1clQCJ0r" ..
	"1vVvduJKoD56yrY2Ob6DKowJ8242RNsFBx6ffVUNv2CJhGLpvcx7R8cViL7u0EX1zOpnF2b4XhcItFO70yO84WGClXjy4I8s6Wqx" ..
	"SE/8eFomcfdKV/QCE9YZQJzBKjzgr3uHpH5eMPOjZdXDsgHQ4f5eMjNKSk6PuyivIIoxVQnobeV9oa3Y57DFaRm6z8TWPfE8yJGo" ..
	"DJxGbzVO9eiJ/sX2sVGclwkAcB6V7Zou2UtprHlKcX03js9oKc3/xDFE/mQ7V1qlEJwmo7oFwXYMgOdUtaByePIekqIvxEUDWFBW" ..
	"OTrqtfac1XLEeuHK8P8O7mdz+JTrXk5K1CQ9P9Utt+qA09+NJDOjG58BnNcT0+F8T4eRanYwY/RxlVpbwUu6NmcVImyXfw1NM2Lb" ..
	"/9DVEqgimJnRQcdAdk732yru6lwPdRjN+LoFERK9J30/SDmDyg4sDdpknbIF7/KxxDluUhpyVik71VwHC6SZ0FPqbXHO2SZ4rn1T" ..
	"xWDdoiUTf9xR9125iMQoD3sMbAy0C7JZ0P+oZExPSLcgjjxdMDojZy+U8XC/LKuDIMg677/xytN0VwCPrz5aKQpgF4+b2XU96zuI" ..
	"hkevwHAm3GmiYnOWn07KmoTjZcvbmOaXx1EIoPUgPqiJh8ObYjmmpzoUrLczMZW9TaeFL4pAZq3n2WXrPqCbUgtmlZrtASnu6WjY" ..
	"5n0COgdJsTrT+Yf7nQOkOfddD5MgAR6GTpwAxe0C1+OzsdH4H5WPNSWYAX5bCmuHQY8u+4/EIKNw11wnrXoKjAGzHxUI8Cq/AGQ/" ..
	"nc9Ss71He7oQwxPxLG9/H1HcmQqYFjLABiC/noJ/NcGfBjwK5CBFObFi84OWc5klVVoS69R9PnzMVmjjdavWoVzbJN5+nxtUXUfj" ..
	"3QS+Vaai2KL1JHMZaVF3Wx+81OCrUScY9xLZ97eY7sY5CeppO8DknxKQ5cxMO+VsLF9KSDdplGyPZWIvO0tGxoa7ho6Kq2mmISaJ" ..
	"5aGYJEO3JKHyVzKWsYKA2UsIqpEO0PsvRpICyeLrFvsVpTsAQzybtsaBB9uopsozMWTbwMdXkDfbOzAEDCTP5w505m/ZeUEBxXxf" ..
	"RG85MyWo5PEf1sgCm0jBn0fD54sdAS+lhIVQleyDEfWbt8RSfgGOyuFjFjuhrR8jZA/lW9UJQwkitxYw8TUygzMyp9DuDEYw3kqy" ..
	"Z6BmkeKje7OgBxH6whCJvl1VdSJKP3h4pe8KgnEIMW9bqViXy7uHYEP69EKnFszh1kbL2gtMBsdwPfCZqt1B1lcE9bSu/jRhFBPj" ..
	"Siyi8f9V6K3liQegIx+y1jAxWQwwdG7K6/f/ei6nu6BTfGj3/dV6Wkns0Dt1DfWLdZnxhLtsFUZX8Tbh9RngKFWNCAHr1n08g/zK" ..
	"ma9p9cJ8EP+QmkBl32wuAlv86vrOwJCJMo922MpkxNxP36pl/usPDpQCT3ZEDEOlhtKEF9eb5FwpW0d+xaND5+PYdb0eNFUR5p77" ..
	"gqFrPyIcZvbG7893MyIVDiRJftAUmEvDXu/9w5YfXRhb6UqunSORMz6J9sQtInUgAbbIFEfwh8Cf8lC/aobcItD+yzY2wVyhEv8i" ..
	"BeUK6rtywfihq7EvHB3R9Sy1eJ5D5/XmIAhxfIXNRgGIuFQhZWkVIq2eeFcu3lesK4kycLmVf43aTPgIBYD/VmprmydkRSA53pyS" ..
	"8XLoU31UWqMoCvZMLAeLicUJl+nj0IIUyZH0KIyoLhj4oBeTjcI8bAMJk7Xkxu8i0T0WGMcgBNnoHpdre9Wd2tJlFLidiF+H8SzY" ..
	"vORvQHfmjkC4OcUGuflSG28LqcoyQiqw9LG1nvB8nTfOODGYLUn/Y102jGk62d+GON15jCWtnVNsyRo4rDPlD1rDVIh1CBtA2aVo" ..
	"nhkVHPONXnpvg4/tizLsA0XFmx4cJQvRsDeL9ySA9uX79nGm2GWn2qRJqcc28gHGM3GkM4Ov0zkeAxpd28+IpmUbmULNM9tubYX1" ..
	"tGqwOwdTv1PV9a9ATTKAhpy2TLJAsQYR8kTrNk//WZO7r2fxzjFnb7aq2L7CrAUHSQKYqMtzf43mcgRG7uF8l38MldwO1qAxon9L" ..
	"6icES8dx15ykC8EYC1pCzXp7UGqC/XXDPJBKBbgtAoeCJLVmzJllwMgfxOsi68aSUUPAccEvJ3ulZcnzSrckSGmeiDcD3Me8mGwx" ..
	"a2HCJcaOLcZrKyXoJrF8ffHxyPG/x0sunVz4Abus7cOuKLeEI3IO9xEJ4q/h797ZtCraZmnit7LUJ397KyXjmqq2U+S0+/pQ0Ibi" ..
	"V880JRpq8CW43D2pC8sClseBAep8CuPBkoprAqwqUhroxteeh/1jEGG6REoa3gGdys/fTlYZmHu8Bj/lhBsEftafQdoOxxYUc9bm" ..
	"o8dpp+3pP0w5yAcIO2H/wEZRKzw3hl5W/cwk/X2K1HejXXranNOdgpAXAIvfCvkk3Bl4hcGcEU0doHW9m+0LKAr7dRgm7sAONX1E" ..
	"t0HZJZUWqJKByWzHX8D0mKkegzUkUn0uDcJiLlrS23uXYrFl+RdBVpM78jO/bTFhkd6SSrl34cXPmJxZUctD0Trjx8/FfFiU2oQx" ..
	"GgoKtkFXzSdsSek7C24JuAPwH/JNa8s6aAsBAHihBgtCBsD0iRpuxYgE9wHm17/5UB/bw8X1xhQUo11U1TfoA3M2UA525/IZo2qI" ..
	"GSqSyfoZUbUhWfXDGk7Oe3tYTyvWn93bvBArMxgKccXymkVZVDlEZ9ZJknVWSC9txMLsbTT4AWSUgD+J0rKwmhKQTWeJPh9nUkzi" ..
	"S/vkCRdE6M4mtpJm5HvQZnNWYzvkZ9BzMa7B5fGeaokRx9oLrMBzZt6sUAo+acQi2slToYh41AoKrhcdLzg3W5jEuUAvfje0+vTG" ..
	"BFviirnP4Zd9myiME/jAB6adnwnChjtULTWAyW181xSE3lMmCraTa1Se2UL1z1AOZ8ofuOIztDaa5Z9eU63J3FCIdndMiVn9q53e" ..
	"9i4CUi1hBGhL8cFlBfZMS8/+RTEq4roDYIdpIIunPCcwWEk6zwEgUouS43tSqHOdVOZDKpZt7nXkDjfvNUyEtfjl0cJMikoGlAP2" ..
	"D6LCMxuLFt10lXx+vNeWH61uQIWT2JEO6j3fcmx21v3GJnoJ8m7abn8avlY7ozFXGi2NlCm5e2WLMj5UoMmnBplGNNjXLOlQFYMZ" ..
	"AdLqTIKkVW59Tl2TxzJYZDhkM3knUKfE5ExbQp5Xy5EqMXBLbKf385VCKDGgEMdZO00nvCsXP8aEiJUTgeBRqaprn+1n9TXVz+YP" ..
	"HeL0doHnj6uEUExwu+/zMKu6i3VmX7o9sQyWI/O6I9tM/v3DlIsSveiE5esFdqx5Vo3orGoGEWhjj37rujHsy6aNpBvZ9yAFUp/0" ..
	"/h9aBMecAyC9movIk4vvMYHIqImpP3RjMXE0kpQ7a0f0zFG6tYHqHsV4m9P1Dydrsm9M9NsPCLyrSNdiyNMG1QmrWLaF9Epyr9jG" ..
	"X/sBn8NafcoE8u3giovQwrqcMiESL8iLgjsR+IpXPe0VE+avbrPPrwZxMDXBP2hwJ90kyORbhkBFEWxXaiVMq0RFzoYKUttQdkBv" ..
	"7TcHDT0zjA/UJF7cfhzpZXWKBHLIng+T2bcIP4tWzTYCfXDCVl8LJBRbJRgXFdIh6/E2HDyIu49pfDUjC3qT0JaIitGGvTq1PGr3" ..
	"baUklqqbFAzDYyYMqZF42NtWu9vbYV8WTfYMWqrswC0MP1kw7XFUfCKfScoJPoUALqRRGYuedbyg4eCNbQ611ps5jlKk+eHzVALa" ..
	"Qh+NL1B70YFvGqzPh271ONXi6yDsv7Y+Wbp2MBVQps2Nc4AbGbLKTzaBbQp/zAOkWiC/8oII6SZnSdPqkPweQbqe6l30jpoMj7cU" ..
	"3UyNqUyXS3EHDybShf7WJE2ygKoFYQHTvIpVQC7kRwe1hHqKJ9R56OtTOfuQH2CVBN3FTYDpcfmW/yn6eMjAykIwb2bLRkbpdv5E" ..
	"1u6/IksTKumAZQXKnoIoEtBTS98N3EwNErbuSYy0QHzd0mFoaDpEmfm2iw8rnkkZ0gaBUsDOm5SE8NaIFM8/y7lQRrMuX6L7zIur" ..
	"LsPLb777Mc01ztwaVaj2Pc1BxXSIje0givZeTXRSgX1ZmVgScgktqKSz6LtjtXgNmuKOSJ+ygaDchUGZuRbvRqLcDlH+IHAMrDXs" ..
	"8r3uhdhSydZQKpBt3hkKuFW7aCoXDN1k3AuqqNZDmaoG++GkiZhkkw09L8iQVnqUNDika1OnxDjnQgLKi5DwwEgwVcXuOjBQ5yQy" ..
	"Yw9+nI1LGZ1XsWqDfqEVsBzBAUkzabG0OIwB+yGAW07hH8isl/cSd8Cetict+pJWhUmw+S8wDC75uwKhoVVUGRlv6eyfZBwCJbLI" ..
	"AhiCc8qrIUgDTuw8FABQP2icHgdKohf8igglSD3Rl4gZV3V6zvjYA/1890x1ebLPSQc+HmMiw0huT+RHQFCvAqHFLZm3KvBGHd5A" ..
	"tH5rU1vb4fqjFroWFZKL5ifcW2Fw+YfGMxn0v0cOkMhrrvcXueNJEK3jf2gp27YkgZ8B/KxLZBgszKGcDs0E95IPCpFWagiMl3Vf" ..
	"ueGKPKdk7zZhHhZI0hT0QSlVC7Io7SMveoKFM8FTklGfouZCMnWWM0KIU79GBZiMT2fZXWEzy3TlQ3Q1m+TTSQZXkyOsF9DsFNMG" ..
	"CaRKFkc197GB+Pb7eDy3KKaNzJ0ctBJT2wtDDyIFO0Xbv2Gw+Ff3A42Ze6g553syHbpnS8N4NYt+kjo4iKXHwAJFJQVgYKXSFWs8" ..
	"nPKBpoxmQu2SpC8f9IZcba9sPKUcTlSdXYUkix6GPus9BfxI1L0t2sx8kLpE21Rpvqu+7rPkmUyi6E7KV2hpcgU7O11YPF4J+y0x" ..
	"hG9sFYv3LgcIkvgklxjK3nMaEATXfJtONNZqvGIZQwZm2eOBdWmZwz005LyUfd1eTCevfmBevNfEx5GvAkCJqX4AYxm/Hj1ECND2" ..
	"10cV6GL04X7G8zU5X62EYmdrp8Z0w2vSQYYwvNIyb9yz1gPqYvPV4Uua2FNTyaUXxhl51LGrGC4FCK2JZUoakeaCRxNe+alM6tKX" ..
	"MlMnuYgy8v/6XGKLKk96JnP812POHUZjMiQuS2EJpZdT32UtI082kAI2HZBt4Nd9pifdYgEjqNCx5foRYE2P9U3mPWhRGZt2xMfH" ..
	"pLzQNc+VXYyOht1wguBrrNUB1CYSaojwm8qqWoiuAgkU0P8OSBVrbOAGbEWty8/ei5Tj7RKH8DpmQjt52MyVZaoa9rnpgMP7YQmI" ..
	"afE39CE3ORQ6/rcBSsdM7VKMvofzsD8uQXsIA3yRtHHHC1oRkIs12x25eZyTMex9tzbvfamDpyvwVYGAb1lCnil4j7HfnCOiMfco" ..
	"JVEi5I7aUKsasQ5GN6ICrm7dqNxe/MKc9tWJE6BmT75uXYsXwpZ9ODbJwJ8yVlbxVIkYVhlFa5Nd8Sx9npmIk5cKBsZHeYgQ5V9Y" ..
	"eT50JNAdMeQwSXbWjX3dWtlHxsORCsDYBBPB3cRuTo8SaV6xuOnbXnHwvaG37A1qAsh6sxFFKugY7g0QadKjoyc7EN1BnDA5Ejpm" ..
	"DTZZKrCBu0z8mCBlvbxqZD86g8BuVBSgjsGya13s3LAFMsrYxiM0EZ2OJcgWqsUwO1MNiSb78IXLzo4BaUAjsw5GMCpfo1jo/7oW" ..
	"ZAMs7lsWFK6D6wFmGx2Y47YZzlXuJqXXNTqLKOE2kqu8jIoJhdpGaM5pntUtypzqwAc5/1PDyKsx08vl5QOpTVqxZKcPdS0SXAzk" ..
	""
local PAYLOAD_P5 =
	"r8XequJdqqBhJ9gidk1ts6OvwUdAjMj73Bm6ya4eXF83DHSIxm6dP3LO3M4i6Y37PX0z7RqAXtRqAY+BL5JZrEleIVE8xWRrgwCw" ..
	"MY1ZA/0TY2PybQxpIEY7Cmj66+NPPuMs2g5jHLnge+/aIH9v6bX91cQ0np0zuBQ5Ng/pufSX4IgBaBf/5WjWiDej4axwY9xxw4Qz" ..
	"rmbtsYMq0J99EsJdhhV63xjGw4E79nQ6NB8urccsqIiFSFOr3NcCDiUd+pRbnOSwNN53DAX54fcznrmaRCfWN4ldeLcZxRg+r1ET" ..
	"pqmvlNzA1C9k8BnWzuC40W7aWjApEdU7bfj3K9dubIk9XzBRsylIzsqxvzF3ipTjo3OSmv223Yhx5MVn6s40eAD7XKOsIdQB/pTq" ..
	"5zz74/S/fTeuCJE2WVQjbDp8himobwoDwkzIGQZr17TusSfAKhy2yke/S0gXpPOgMwyVzBvrotchxsDCltlp3mndaS+6SbVIIjwF" ..
	"tvHHC4uu89Y+iArnyf2DnfhAAaIBmXo144PLpPctx8C+J7EFXqpOpMC7dvDXS5AQfvvMohRDp0hJS/kYX+sksHENErPBdw7CTQrN" ..
	"ubWkc5ZwrDy1Xyl4AKMTMJz5c883iXSTGNXNQrKNgwSbAd7HWWHjUcGMd/aEYkRxuOKkWOhjLXfj3uCJon6rvSzdUNuMhbtsL76z" ..
	"V8iavYRN3XR2MuVE2i9yjum8IgOgI06Zc8BK4boGMQk0trTUSIi7HeNiwjHLMjgnCUKaxHeoKmYyrdgaWQKqYCKpB3fxH8Dfq9t7" ..
	"qCfq40N5ktudjYj/QPcOFaxTsMT2Uv6B4twU2GREIAgRiHmJTfZQ0Mq1IvfVsj6PZ5nNO3HtBAr7KaYsgV8VzNefSoVTVJ4OThXN" ..
	"DI3ccod1ajvz0H6CaCse5WKvWe6qDIgdSXYxssAim/c8d9KM8xlDNLSVxvN2SHYXWkq7/axu6RXG2bMa8tS7jmH/JwwsntqrJdW5" ..
	"9MiQyI5SoxZ95N2+LMucRQ7bVdh909nglhLaK0JJ146Z2PSpeun+kNOgm1gVIsP6tc/T3DZTvIPhNJt/p8LoZmNloZl1lsV9Gc6i" ..
	"3BifYFUSj733jPEWwv9e3qPTCNR0xd7basbT2H/gZhOS1jcw3eYKDGEuHtfARFQkIAzYypG+Pm7LxSVhIy8mfrmld49taNvKrSc2" ..
	"wgbpf6Ltg55NwcV8MaYUbBzihvMzbnNN8L0yblN2BPOMOiUYpTu0bv+ObrXFLIAWeCYyi7rN8GtaYng50vCbO+lKxX5ylUNVyAo5" ..
	"v+iq8QbGwhFBx9v07cD0M12+bQKK9nSHtD/fd9pF7ZRxDQRh8aZWeviHwmtECrwobtsXkfGch8CSsFebb5TX3O7FtGYOqfv6s1pA" ..
	"8w/F1zDQigLoLTkw/YsKfCJIYBF9mh/mwSs8sRg1SK+5wH64W5pHRfWv7k17gIycMJETumMb+R/1msXGZz9h/z3BdPtLnYoU+LRf" ..
	"Ti1dPActf30Nbor2YCiZYLD/d1AmGpSvKfZZzcifh5+rGK+xuC1s/izgZCzl7Q6k+A72RMY7qhobi4cXSr1+n70yLKPWsCAoo5yo" ..
	"8Cg9NcZD+kJCzTdeqKd4U9PXioqTvZ2CJDnS6LNeSeZWa+U519DygR5b+Z4HtJ7nKUV83HsNbuCow/QQQDWMz2MIE3mNXBWWV+IC" ..
	"38M+gFoTb4cwxBj7IVkmj14+XZo/XiKplr/t3LKgAcsVXqYvdXAHeHA99mwssJAw6zMEQ/1Sl7WBbd+YRcUuzzpclFCGaoKk904C" ..
	"Tht9qvPwMkP7dwNECGKeqYjyrlEp9g6lkGPyRWuh5Qv3NzOOPpfaLkv/CstmEpznBd1SQBDwr+b2B7/Wis/D25Ccgr1Kh6EfV+9P" ..
	"S0koibcvMB+JqRWkXdjOVAeuOBoWh4cA9pna++6zmNWjtI9SGdo2gL6K4Z5Tu7fjkUVGxjd+JUXjOVcn6cwkXqKk38z4Rej+5aYF" ..
	"Dzuz4zbRSxqOBeIWOa0AQ3XN4oy7ZMyvTLGk7Ac3M1nMtrYlg/6A/7zMdHNhSuNxZESNulmKxevAImbuxpOnTh4kAmOrTqESlzw3" ..
	"pYPhPNLnkYGUtgmuHhEKtCxMQ+CyezrUk7+evTd+e0JOixgni0YY5OVkGHSNsIRf9d3oSDgVrZSwI7HUQtfsH/WVrRgF09PmUp+0" ..
	"9Q72EwBXrU/MtFwWO6XDye1iGL7/PaeHHO3WbnRk5KmK/Yr+JCYF2jWZpniScvFvgPbKtQrcjyxRuOm/Bvgm6yHr6FjkOYGXo/Or" ..
	"QUuiEieUMRI6WiCNcd8xkwGUmQJPom/d4J/sjKfsgvZNgN+xfyLQt6LbzkYH3PYnDfyP8hDldEsfJUY1Vylhi7wj6tb8PhDC5Ben" ..
	"1FXXs/JSDKGEVzNwRRYp+sl5rXkZ8KYRKL1t2CPajDU2fPo59VB5Ud6R3vG9NTJbd2iTGxjHNi/ifm2RjQx1dKaaJdKKCX9a/IMl" ..
	"ujNuZgTmrYVgiSXTHGUIxPlQrjCr8Lx4Gts3rhtKlyeMvIXlL7hzSc2AeL82JsbYLBstv15AtYxivoTP6j69OYUBHwojY9aiYfvI" ..
	"H1p9ZM/lEhrMWwrVo5+ANd9Iq5xj8V/5vrrrfG5wdQRuPykOVaLAekqPizRsK33mjArQrO8E3/MngQqhdlJYmV/0Ckeq1G/N9c9m" ..
	"ENNS4jq2r5I2KCNyip8yGn74CfUC/h01TcXDE1fdBnM+c91xQX2olHxi3WFGzU3yLmJAvY0jFbkymPWoEf9z1TmRNlXc6Ljkjo02" ..
	"89G9lSTJFH8mR2iEI6xVty2faJAomgsxCnlScc70ylq2FsK3hfJpiacMAGhjRulstmWBlT0Inz9ACmzuz9kOOwyCzOJJKd74ZS7Q" ..
	"QHceNze7uBmKCQBLoq93vVamtIILufRDwwQ9Wk9g1cpr2vxKOSdUviB7BeLijNIsQxxmcD6aNm52gMmH0lXuKKUw1de04j/Kt0LC" ..
	"WzrcQOTb1UzXBLptH50ixIrSBNX9GXYSA8/gTNzNZ/PvlLmeRsmPGx2NZXZoDb5Wli8IaSCv/mCXUShUPzIRPmg6mrqU6ro77hFc" ..
	"gSzVVSjIVid/eIEZ7LTzh2hk4eZKPWjiNGIvdlbSVG2/jkgdW5//4IjxAYvYBN5bVEIuYmd/g/hzwF4O6pgYjAi/a3GpMG17w0IA" ..
	"iQMAfP3ixQKxTjwQMys16R3T4Ij+pV/z/wWLRPTqoh10+0o5Ni2SaVEs8RJuNcxOOSBkIDwsN2mcWzT6r9uvyW1cLZ0IYqnZcujh" ..
	"I3lLiwOK4bPs7/nxNWJvvv/NzQ36UCYP0Mrq7s/BTttKIYJZI0zYudtHKgztFbAPK9nVLMEqUt6BQSm+XjxqQ6m7RjFEpsOU3SZl" ..
	"UpjGBVD1RP9v42SJqK+cOoW9ZsY9PGbyRTRIq3lsRAQFU2c/qe3MJw6csU0rlzrY/ZIoZ+yILat5K/z1dBfnwkXgtPrgCdmceH7v" ..
	"/CIjB5e6SEGdJivJbgazBlm42D3TrdyNE5oGpeRx5JYlVuByOIuH4j74tcDQJTGIaRvgFRzFTqahjEbOYYiYl7enMUEolX6XVn/E" ..
	"KIWlhZiKN5hshv0qWZ6EwndGLc7VGH3Xn11Hq7jerxTnUHuRKEWjmJZS7atSSrkWDXpj+3S9+4NO363GIYunp5DheWdekQovXqOi" ..
	"1mSFTahX1WxUU9FtrnrPdQ4UGX07rmtmGpVoIp2q0UArM2sCCihFpCHHqmxIB6S7TiX00OGFT5M+ZY9qYCLSP9n8TdDcgub9+kDZ" ..
	"EG8fEeG06g3Wry28I7+5y/23nJkEW1Fe+HXNnjAPkM+bdb9gzEzE9Z27SVYZojVpvpX5EA+HwFc6oZWEV3/oTwbgW6pA1fdxQsUu" ..
	"ax+UOUKd/2oavQDMh/dHG715TB7ZanKCnFysyK1NBk38Iv7/sSqNJR8gFJY9xhCgaqxRBoAtgWdy5UVMPrFIorr/mEVETFr9PHWN" ..
	"uzFje6mMGbpOe36zDT0GgX2b9nKO/PEMPrXIGuBly6QZQ6Xz0XLvesT8H3mOnvY7x/0xJajNYGSz3ZFTaC8RiF2wTq21w8FyjN1x" ..
	"/+rah9676jUu2C0wO6CBs4U0iD5d3YlcMVT3nsGVjURaFtQTqSvlvJOjym/8W87mPL4m49EgAc2wc8bZM5fnDtBFbI27oO7f1WO0" ..
	"uoAPV5+Kl/ifQjr/9Go8Ko8nIkmrvKnZ2/CIEl8hnRj+NGzwwlr4KrS3NtGc21pPbjwQ0C0+eQPXcwAjZ+xS7nPaJMXI8+UBIfzX" ..
	"pWmxcnWJomjfj2gZSkXpO1gLNid26v2QXSC+hf1IZfOk2x89476TNzL4muH2C6OWbE4o+Gcx4chrp2HrTf/0dQQIG0TFfgCQlomW" ..
	"Xt3+pjkogoC0Mv5a2MxLI843QZ1DDu7KQC4PgDgwRJVpG/GkkDGB2cpnJQtSinrLufumDqagQ4tXiL++Bpt0ghWuguKmqzZXwdCU" ..
	"iJk3uYjUrdh0v2ipW+P8rCuroc8wlBk2GOPvy/RlkGxKRMm7KjR/IRLtW/tAV3+CDl6KJGeVkjOQz4GufFqwvGQ3SDCfqRoAQMLx" ..
	"8VlOjpA9ce6MvQfDNp3LjlrkFp8ZAyFg0fSumqGJuX41tBlEsyuG8nJpyff7Oh5+LxhTy18F2dUG1/O0o3mlqRe8DdtDO0wdY9vL" ..
	"FnvimqUMU8d30Z/KxsfBbcauWgysEKo2S0tV/K1w8TV7qkIvGmOtNpwkyLY/fyJ3YwebA9Pmgm3VlgvLuPsh5Cwe+404qDQ7K8X0" ..
	"VZ34ZcoUbahUdPQfrIF9tE1C8BBsVAOJ0y4GUEOGvMFfpkM6dhQttXNZq/JbQyq70x5wdhe3BTw8L0IYIwYILmJIgeUr2UT5B6wM" ..
	"/bLQaCg1wqPksmNIOPbN++m+uQlrxRu71IeiT7Yy5w5cFQIofbnICPRPu7l07tMaHdEx+g2TmE9tRaGBnGF2Nq4/K93UdB9jvMl7" ..
	"ijB5ED+mHbN2Ynh1NEhkUQRriyhj6uxLJi4OdrF3TbyECFtimsXU4Zfr/V2mAsA3+/xs/r6xr34+ER7tE07c/qsmceJlEAsOtYWu" ..
	"K7A7O94yfDMYmyAF5IMtNeEcTsVOcN2C+Z9+Y+rY76fhVHZ956y7yGRsb2HG+9j51iQpl0Z3MgMIZMthaQgMEsdUQqDsFzMfZ0Nm" ..
	"J7fBpkSpDMNoe0bhPE6eAtjL6f46/O4bTdjZkR1z3lfYt9G49bRNuw1TyUL4n5KkldwA8ci6jRUYyarlW0ef1cO85zuxx74FADD1" ..
	"uFH3TLf9W0LjlltI+QAA28fHClF2rnIsJNBjS8tm1YKPr7As7E0TeWU+tAIsFLyviZOy6ZkLTimu2doi552t75LPkAlkKYsC1Yzw" ..
	"mez0Dq4WUGfewrdy7GIw4CQGmlm2Kj9sNUFZ8zDUvQZrmlp3luxyOj9xswie44+7VCS6W7R8XGnnr35NY6tMvMuD63jxGLxkOqS+" ..
	"6/UnJnLW5zyN2Um5UROvMSCkNsGxO3a226C+AyknkpCS92bfHvNqjSP/40+C06vFUoYT/0ur5EoVpz7MQNqIP6HFNVs04p12a8pn" ..
	"0dGFBXqhYJzLBNse2Ik0kk0+IErTG4rUa0VDC85g0RDJWKhHYHEKF05Fj0DVQvsDndmzBQ8L3iePNdMuUvf6OwV1fb5vAcJjns3Q" ..
	"IZlsxkIsIGVGHTwgFmg+NXlPgRsJhYDdscb4aUrFUwJfZf0vA/6K5oWPhpkWatdqH+DNuu7O9BVM4fHddOwSQKFmvRVPdG33m2Nh" ..
	"oCcNIUxLtVcDh8g0b9nOuBbdE+/FmP2I8Z5pYScJQOijfKkNrYgFDiueQiDcI9w0rufn1jcLUXV4d4awOk0DoebJ25AJcvA+Pbrj" ..
	"Gg7EcFX7twxDDYRK4WNdlhn/gtkXUv133QxheU13Qn7sbPCOt/Du0aafSVlGiXQzPuC4Aq0mXptnjzGudC+iEpLmWE+GrmASGDl4" ..
	""
local PAYLOAD_P6 =
	"cXVRI1jg6U5hjlRuq+c2x4yjLFi4F//31ffjlZB3Xqz8AY+hXEyvTYwq1nfwl5Dm+6jQmW3d7xt4eoQU2LMNerZNLCYs9e80jh/z" ..
	"E/17XuWaMp0yXSlBkg8oD2J72oiq1xbt0+pnQeTJ15tiNUJ/0HYur0Z9vBVGU//+b6AXorHTutxarX4gk2UB3HTLOc+sFtblRP2K" ..
	"z6Xo0oEFJtrv39FTdRdD+AJSpIoMCyE8RwDsfSuGUUz6WuiSWAgNEsDN29QJ1makBBmazAYufXR2uysey/poduAEBae9rXb6baiV" ..
	"/4AsCIIQEwdLi87tja2pbMW97D0J4zH0ffG7BNFv7V92z/QOk9WRYDhpmywuwZvY1+6v1lrgZw/C7QK1/VUkzd+35UZ9jGrgtaEY" ..
	"yFFlXXUpg/EJ0NyC05EzKeiklIEuMjAqVIRs5mWPHtpxqnh0rr5moW8Bybox2bjsM0hBMKZBVmPF01CDH2pcsM/5eDfZXYWHmdi5" ..
	"7GiMpKk9HohfsfbCMwlyzV+0kKg5DUqBuWT3/ywd2GUL4b9zAdPHZzBSrUHN66ytMHZGwGktB4LJg4fqGzGsWy8phpZezQeurjV2" ..
	"iA/NPorp0sllU+1ld9hUL0CcIIgdJ7oqrEna/xpZLqoWI9oicsNmRNOHCgQKjx0HLww+2WntUVkmCPT2Vt9qo8c+m5GW4f4t3132" ..
	"nM0u6XuW0GA+c3kcR2h/pupgN5r8afzKV4jVyaESD+T6TFiYPHlscIFrB9u40hqvhLL3DFBy17jQUvCNLEb7LL7FVlic2vSP9Or4" ..
	"YursnL/Bn1qQINwDlEzUc6BuqHUJkhQ0JfmaG/9Hfx7x1hcLjMfRi3IBkB5k3EUTscWctkXa5walfIaDMkrzMQJlp+h/3d4efLtY" ..
	"nqsyZvIOXgMxJyNP9h+MFWJdlImagd75Ml4drePgwlR0RZMqOYuzTx9xwzRYezNWcB4rpzYH2fCLK1t9JnEOxDYT+0fp485ugCcd" ..
	"NyPoJTtFNjEY4xVhDOhxGlf3pi76M/HODf6fx+2jum4Ftd491vq+VAR/soc/jkuutJIgznr2KXFWmy/12F6Gg9IkUzUfcYsWJjpU" ..
	"2IWggxIxHbEQ7zWIDbN8hB8mvU2A4t2/9Vw6/V1o" ..
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
