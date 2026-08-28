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
	{ seed = 3613399478, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3608705440, exp = 0, plan = 0, hwid = {} }
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
	"T7MrOqO5cfvryRw80UnsJPaKo594mWFgKqk+lTFPjbKo0LeV8hjViuLumQeWaKj6PouL2d0YKjOnMJtytc08kfed1oHJtFx6OrY3" ..
	"xckxnkU/IvdFjJo2G/Lx//m7F42JN0Rn5InrhXWC/Sar6xaG/SA9kkqQT84yfDmK1QCvy0lxO083o815ZvcEg/4C+GglfSfzLEh9" ..
	"1/Nueu/R3I9HQu6zTrUXuaDvuG5vDK7lSwphHW4Qic0asX3jmzySIPvNE3jENZt3Z8uibyPuaiCXLP7YUnO0OPnrj1SEOun5rmQq" ..
	"bMQErwNwGwwCjavCm9JMOElJfGhP+HGfRgihzbvtYxmlP5hV8rZHwOxunq3BGm4k07iocL2rOM5fLXvBZu/4Q41Uuq6/Q6oy8nPu" ..
	"hu9Z4uUpMkUxUjfrnTfqTr5cuINWscF+2TsnCjnxoNh6I0GVCYEez+7EcuMWnXFwaeHk4+cNpcp0ubFQO/qj6CJpIRYk65dyn4gU" ..
	"xHp6NiyFi4K0/YSQun5QsIbAa+J4D8Y2jMTpCuAuJoDwd+1ff5ExDyefaqkETbvMcUUEwqHL00iE5QPZfwAeqTuk+iIVxTtu83BS" ..
	"3ZcAkXHr7YJsnAulDOJJQ9umvl4zQXGyy1W72LW/W6mGpQv19DvgzhmyBq4A60GI1c4OCcBUFzj/pnV9rBWN6UBJQHb8olOIRgCv" ..
	"KqtPh0suWzfG0OplYa/PV1nGatz/9u8xO5My3u5eO9ofOPFz9fHeVXNxarTTePQcBNbStl9pcamTdstRQxG22SEZzLd22oL0OrSM" ..
	"IcT2hIiIS63Fk3+o2x1tjseh1zoD86WMp06RoDsFUdPeGMMLk1iqT0Sw/mg49h1OpdmLJEZao017vFoT4+e24LIF1XHTolqphjtU" ..
	"c+CxkgH0zn07w+3o+NTBULBWopckefzP2JzPco+Ta7A8N64kri3DeKaqXnq9TUoSRRkv9D8uIQ5yjQzSE6vgiqaPjDPbBl9gQlIa" ..
	"+4/zu3dHZCWjafWKUbvbxDc7VMQbTgemOeGkyUk4hTBTf69zjxPDB3bHhQnImO8HVu7j6CgPxfBedu7N58bXkXszrgap6/TGTmTN" ..
	"aKWXyYNOJ2r7LJQSoIqoJxFh7KrNax+F1iGqdQTN/MkCKrt/XWv7yO1SEIUfv23chDJwxQHXIgPXXk5yFcUL1Ey8jEeqslJeAzyD" ..
	"5DG+gtar/WPwXnP3Hleo3CzcR3Q7FF9NYYyneZWfu+/JY/L1P+qxZo9qqX0n7e6wA42nIPka4vLXIzXY9cIlz4U3zH+fN+2AOT8T" ..
	"Vw3t0/fL01v8F/c+zPT0nGxVz3pt7+AuhyISanAHnP2iT89yu12weq4mZ2mrXx2tMQFIB4LREcgXQ1myzThQF6bZptQ+3mlBYGC3" ..
	"qmrruUgcoYvJSdB69agibyQZZeTpW+LUdCzwLX7vyuKEQX8VXdDNAmpJafwbzzF3ZwxCZ4VVaHR1SPemgwc6+d63EsQr6d02JN8T" ..
	"xGS3KZZPcu9T0bj4dOldYoHrboU2SyFeGJCqUBeN677kommMYCyehJZfeCQzvEHwNL9X7F0npHBox+fX32AFvV5ZWRL4bq5SCd7x" ..
	"Ku+xf80Xmp2HEzyvJ3xQKoRjnpySPHaNoiiHAZH2J9m58/LXfdSY40EZYr3i/wAMpHTBBmf+r8xgo3Jx4NjowJZ0OqB1CnmvVfan" ..
	"FWd44atfmcjPSwmmpkTz3hPunavK/0gDS3AgcJw0R9h9U2A2WEf0vXnr87xdzhtTsbXuCxGmEWxWmJ4taYC8n8PBPAuJ6EEzGZsD" ..
	"EUOYUy6/EtMbSiVHDxDtLsqLvuaGt+icIXoKItsCXM0Dolw+9Rr8xdOiIgwp3X3T7YmrkZkziijPRXUpxKleI6hjbWJaMyle+G2N" ..
	"wKSyRwUQdYa4tWLwNtCj7IYYbHLlKeyezMazYCr5MFvmVp6n5HFVsfM7MwSeYfb/WEvI5vRrSbGtVbgu4AxuvgXkh3GhaxtTxzBm" ..
	"et2ymq9s0S9uIS9ntn1VQ20mbcy3ykoz1PZ+uJFh23AbKQ+E8Wyx8f11DR12QLHWFM4IyKBoHRMFTV01eLRc+k8vWeV8xpbqB2mz" ..
	"cCFxxsi93AUwFA8BFa9HvCxRl3T3IFgU1RseFh4mWvlYyOI+e6J3YUOaGm/vNglCO4kt/kaBtptB3U21jzSmOwt7QjOqmpiTCNv1" ..
	"YlTvZdWooanuBFOP3zwo06Wxl/gqQ/PDw4Sr7ue04O7PPy0x6UgTKomP8st1zZFYWxP1yXswD7thmoh8zmS3Nt/5QNmiCc4NI1qQ" ..
	"Zp17V4LFZWFcs8TYz6HU0Rwhw4VMtI7IjIs65FrcAUh/qp+YJ3iyRWHyWokwF1GgqkgUp8q9wp+F1B/zZQLH10PHXcVeryw3U3/G" ..
	"rOQg82QidrlU06jC/URJDM1v9+yMRwWy7/Fv5/nQ2Nnv2I+eeGthMoQcUkNcNKmXv+Z2IJob02bK4vHYAVBDSrLUdrmmeUoTgQcH" ..
	"umAE0nwqkBZHUXhAjNoeTn2vLRDZ2ZVjMMRMbG3om+n/z3srTfGzSQZ+MIn9be7FW5VKUSCLW2Wslc5HifQyVSjKlnL6HpOsc/sn" ..
	"Lrb/osYU8ZHaCLgnCdoNb7E6mVaHJlgMGR+aX/APFKfoWnfcTGO6iradUu9PLfUZp4usVJu2N8Q0iJyMuuA2lxqIj8YIHJfCn6gu" ..
	"c/etrd48gjjjnuLEaRBnMb1rlkmpJa6hp0JxZqxGPC8wfaq8UatebmjPC5y8u4i84W8M45Nvk4e4+8UuAxDsTOqJwbx8SaJO0TLt" ..
	"WOmSJDKwMKpPe4OdLpgv4x99g2eyPP3lUa5qx4tlzrXzQpkp0sgSd8d5tIkAT4hm2W/uyBOkT6HvhHVcofHkQJcf6sz9IYAbGIvN" ..
	"bK9QiaHZhQSz+xm5LMrDNEtUV/xQ43RtJ43YIWXZqeNJhxGoLkiqJvlJjhUKS5pxgdqiUNZGAqxVmaw9LmjCDTioXLnlkvWZVsaz" ..
	"WG5j+rZJr/XopU+MvwGyRRc+hVaILiTYGMccl0qqY3sxV0oxf9cs8xirm0xz7CmQUigkpIoZLalpc/XTUDJDVWyd7YpfqLkgkvbU" ..
	"OsuyjHpdFMMiWxZW43053ePh4bnFVOjf4hAgmxKlCSKVDt5KtdZD6pUrszjF17kTohbXTV75cun26q7dMOlKOxXA6a98C65RwQ1T" ..
	"6ZMdGm2htBz2WcAOLK2+jlwFtTUERjuIjD+IYK7A1avtUWms1tClCRNCbTVw17f4nkvvGaFUPJcMuiC1Jq0m6QEquiB/O1Aranlf" ..
	"SXFYLEMYrES7f84uNzO+fUxRQIyNcugSM/OSeZhfoN8ud5RdI1eL4Z8jJaYpppbQJlMB57qxcNe6T7VHtM/gHjxnVi5K+MBJ2GcB" ..
	"XGFeHednb3ZJeCjhlfGn84/IwTVATku06yFWg2pA7/5f5Fnn4VLXc2htx0ZAt/1HGh61qEZSR2H92C9Gqko+DTe2jMc3rdZVMkcR" ..
	"U0j5zqrExZcTCAld6Q/IVXAmvG9VWwi1sIjPZAk+0T7koQanu3UmrCMYIqQh+hoBQYwaUygOjnvi/j/qAtLSBlUGwocwXwsD+xOv" ..
	"7DdQWmP3HAgjFeGEQFdSp3B/iy01izlbXdDIJ/LXMHIXiV751ufwOKQUQu9NR9Z86Aldu/M+NL+wPchE4YSI3AP0jBJQ/tFRtQP1" ..
	"XSr0wiJcyU7SmznF/rN7WfLuKbnPpUJq+H3X4j5MmOQnFWHdft+OAnPzGQh5hfY40UH20CN+lc/Ww73NQ9/53+FKKziZbgrz3x92" ..
	"er+8qeVV/SWTXYrx+ca0u3QAlU0nB/wDL1TW+ec29AAF0CIo4xXX+RlHKjw9F6EoXMl6xY+LdIhRUURu54DHRl/6lh4rTH/PqF0K" ..
	"/k+AyPS++wp2oVs1ArEMoKlXe1hBfpRt+2uroH/idowhiJhnfw3QNy98iKu1AF/irHQUnC/HT/tr9ygPqylQzFtHRtO8Kw1a7dwL" ..
	"fIWSB3m1AC3GsKvTDKqAi/b2i5x3SbEqvLApnLGrmRUjwoq6sY8+hg0Pt32sTw0ctv0zSKQmJiA0zThJH644e1W5bF6ojPjKqbJU" ..
	"XfflkL6VTpCq6ZGROms9RxL0jTwNRq5lEm3Sjw67xT+WgeCWGyVEOC8VYXfaKOM6z8v+flyLmPL2j5moBcqHC6/PUgpnNOSsFsAt" ..
	"edmxkTPlhbI38jHvGjmCVaUShMxc0xpaT3BimQY52KVfGoxI1mnEXh8g1s3225E9tRoRHVN8b0hj0FH+eIXfVVVAjNJ7+Ht3TuAc" ..
	"aikHEGVgq5m62xZiv2EYMVCCdiOpkpaxaP8vbYizIerxaEinDDcv+sJ5Qr+1JLBhXLm4Z6YhZCbCzBoVGp9fI6LZYxeAoCihgLe9" ..
	"S4BfzL4OceBnIfUR4FZFPrIbiIYbYke+05XVtu23jVgfI4fp6ttstlcf67AF+KpMoW3p4RNIIJFMpuFnTDb4aZv43czM/u2VM0Ka" ..
	"tNgoRmx7BWkKSDHcou8Mw01AczKNH0tKqex2kVL2m7z8ghfzziNvFcq4Von0SwMxcioSEf8Mkj10tFrW6Xe1h4jwV/6fTGQJonWt" ..
	"4nH+e8XYNdWrujX2BY1RFqoRuaHImGEUlP3CLaRSc3JNBdmbivLkBS6ot/frWRnVTABNtNtJJFVV7BSCfpE6pvt/PQ8OwRdrgQU+" ..
	"WcFPNKGZhpt1M0rRlqQeZmkOcsQCFx+DEyoTFZBt2MIuwNYUIyOmnADGRT9jxsCkc26uLE5ZcJcQuQjq3DLqHIt4MfdOwdPEhKM9" ..
	"dVThvV537PBXT8aeQO62Km7U8IBGmy9A+WbVD8HFVNtRpqr5RchFSZ3cZjYyfJlM0EepQKIf+yCEdc0px4g3zQWUykuETIzUFj+r" ..
	"kNHMorBX80AjZwyK1id0Huld+HQoRM/AZZEmtQdhN9LFBtiYnQeZTxD5ehb/qcMpg7RYHy6tFI9QTkSy9Ef91FoZ/RRSHt6X0tTW" ..
	"Z/Yy59sB9+/EywQ0HiHLsD1JIL+fMSyG8QKEPsGuxecm8nHeRDR7MAg+MivHrQARL26U5n8jRcjdoGy1GhXbRGiTY+g2Pe8Vjc+g" ..
	"V5bH8gIAnk6lWdTlJGA4Q4t/6s7/f97CBIf9eGhKPSJkg2SoFISCR/ibYCiGxToaF+2aCJk8HF2ANw9z6PB1JbGUzpPOhgntWLuq" ..
	"oqSAzKPfNEUcmZ3j/R7RUPeYsXGUVDnI4Yfr1Wb4UpMXpGQ0AhnT+qK/vZP+gTHVRYtEl48ZAQmZAOzeoTciXE0Pk/Em1dd1lUOo" ..
	"t76rfDvEUMFH99KVfyF2BvS2fDhhACCGDP0no2NuwgGzT4uvpnKoGkdClcLHFFLyBNLMAAjbxRXxS0IKn7Qccp/DtcWFifmJA7KD" ..
	"Q/MnIspmlb+h+s8JwiUY67h2SyTshXzds85xIABS8nIVzpckS8yN4edVPi5tQw9F2KYtaLP7wCIOPoBPEECG0No657ZcjzbjCMwy" ..
	"LX4bzO9G+EueScLr4DSvOpbDd9GixKljae879BraBRSE58xRIF5ICkMYd5MigbclrrU/7IW9bJuJHhhIkqVw9DoV0tiFK1KYaCa/" ..
	"+2FXnL6ZK1kYTDRScUZ2IOfMVT+gFlrNlVcyUXrYrvWPYgG6wEGyV/R19XJsrBJelrjj+KNOSGTfb2wUATqsB27w/IZBxpyxEp6D" ..
	"7Y2fCdBn36pRiy2qYlgFThyi3Z3xNoHlmnBuOG1eKcCgEs+VVwV0lZAjyP/g2kYHBT2qPqY3KS1AHlvhBUgWmoJ8FS/7FICXaBSn" ..
	"cp4373JgBGTxlYs3YkWesoge7Uk5Pfye4PfTwfjetpECAwYaVR0Hga8Eoxk4165419VlBG6PGQfqgy3SL0+aaOskXIL23AnpsahH" ..
	"RFxL+0hZvPWRqn+iShRP2HeVCFLn7YnUbX4rYBsjEMJ1/YWO0nmN1i2d9yTXADkxUefByELkX7NV7uL70oIaquP8pIvWUfFswfk3" ..
	""
local PAYLOAD_P2 =
	"k0NWkGDGjf3ZLStnZ/hIAzva2JUN/S1oGok/KkHGweOEEaqZRiwGlW4vnybwTj2mdRqLf1B0J6rxwkmhVUXZQhD8CH4lyaZG0qhW" ..
	"ZuD7XgLv6+IO5S8/kUQMvwwBIEXjEWSSqP8dE0/4ujlW8p5CI2VY/AByNqXCzzodGj08d4ryChooE/lEWowX58NaeeUWmo1hUcC/" ..
	"hfAb94nXk5xOCAWXXMYMj9W/6Wud+MV4nQXwUE4m2mrq3eFjAb99F86CkFufAQ83/BccV6LxXx4wZ8QLb63c/f4N7SigKEioRGJ6" ..
	"eKF7/Nu6QVDF5+HlfgTPytxqylNOjby5LgErg3aoaRaaQyKj339AjlWq+Q/aTFrFhsB1KFncuzwZp+iLZB8qc5syLyfV1EnFyVxp" ..
	"Vb+44XCu0LnwcovBHPlmcgD2pgAIOGN2D+398Jg9ZK+hcyqENHYUEA10nbjtxC0nuddVABiJWwJDO2zPBbtWKNOlYAqcju1Chw0e" ..
	"DRVY6q1mgEOHP8/PyQL9n3tUjRRaKjwEQc2ukJ+KY1QAV0JoXvL0ut+JZyZB9qNZaPLoHgg+Eeg9nIOQTQ1HXtRw/jNk0rJKmgyi" ..
	"O2pWPYaxeESt/kkipgMJg/oZ4GcYYSPXVrfFslwD3YeKsrgcGFsyBuqouuFDdMXjaOBDXjLr53e7hdgTTiW2LxGfSt6tGK6zVcJO" ..
	"rBuelrw9nXX837dqNEqh7Tii1y1vHPlgaEoEsaqWYvh6mkx0zBVlq8PKVeWgYsbm3lKCg6GHHFcSoCcb05L70/FuQLnNh6mg3h6G" ..
	"MrbB//DDC4FSszTcmhwvqIPOMmQvGKW8f2Eeo9q1dQ/Zt3IetEIInh86M9jew+T+FFH/PE+jqIKm2Avr+FZggrZAamo2F95KZHms" ..
	"g1MR2i2xJ6TCzirYtVWMwR25lN9jZAp9HGTycW23T/rPVVYQtcT37Spp5GJodp7Yfe4IWBP3OwUYD5fycDb4g+8C3gycoVeDt/Fy" ..
	"ETOSratrRUuTHy71IQeA1DPBfih9XEeMZC3sFQtOUgfJn3V7XfsxmdJ7HZtNgT68G0wyLb2lpAGmiWHZ/FWedSxUrq/V0ZzEFFgb" ..
	"7540MejowmAKEm2Xkz3cJ3LqCxwm8EkDqXiXv5vavBpTUld1V1CQK+8NB5Vz5TFMJD+6YVi/3d3arwHTIPaP/5Sis5cXlk1nwqB0" ..
	"hw6XsezXkCj++MbI299MW0QYathsiDDmK297D9RzQxJLTlLNF+O9erFySTINDtqPDi2IodBp92/oNw3hwTvz3ig10r+0tVSdJLjv" ..
	"QtAMSRlLAcHTHM23PwA1AnKDta322lB6FOCZciDI0Q6Iucv57YEKAAO+dieh8mghmJokfxPVmWdIpJEvYi6Ltvqd52W3KDslC752" ..
	"DfekeiNIZdcjrFfVWPy8+3js39o7TaPEemS4o6MJbbOiH9CK43DyvmGmpLhJL5UVnabylxE5sHmr+ogFoIh+Z37P+j0Wgb8RATuE" ..
	"3OvEBsjC+FwwfFO9n5pMxxglTF1RbuTJNoJtRdBHqbUT5IELkAH2FmV5KoJ9fKpRZSHVrd90IxV6zVCguhpJywhKcQT86Hehk/N0" ..
	"OwX5KM+TqkGumQEgqMx9baOgI+ZdgGixFXhK3QUdwmPPwG3ZvJIgyvqNapWjVnmJ2b6KIcxRNoRWf561qbtXTzdONLWkuy/mk3FI" ..
	"ReoR+CsLZ1aQ94C+9D8P8jrmEnecD99NAtbQkdxH+JM89N18vJJPg4IjEFVR4LPtFSDfOzHghwdciu00CpBMPnpMVbs1nkIsBRkr" ..
	"8XpzwjNCkuRbTBipzZiNeqMtfRcxjycECZfxUy4zYYYNgpT4oBuPVo2OlEuNR8Xq0ktFYgHomKWUvZ9RsEAnBOITC9HTIRGQhWW2" ..
	"CxHwoWnm1+mZP0krOXF8J8wjrITIg4s9qMFyhgbaPpve++EBHh9X7eM0hKS2vCAGSK9nNd3wWEGztY/DjlcNkQviWfub8JdrW1dO" ..
	"8xyn9LQS99pd2rL0rNmqQl+3uZrQsTkEDUs88BzLuAS5YRn7MAPYGTfFhxCAzbXCZA2RBaH1ThB2LdazYMWRQVuHPCEV9LpAXJBZ" ..
	"Byh1bsvRm8zbDsBySV8l0/xVcUPUl2UKIYy46y+rqnYndx96VEPkJ4n1ePeuFEddiiZQwR848GjeQsUpK4MCtNLY4ASvtRFVLXya" ..
	"1FUM3ln7I+rPeQI57XKdSleDMX4HM7/JaChz1v7OByqyBnj0gHfI+IzzCZHsST9OMcXv7TnF13rlE2loy503O76AfwFcKzzeuuIN" ..
	"pySrRs9ec8bhAkwDn20rajBHXq9ksfxG+gukfEF2wx7hVJJm0RUO9tqbotPk42ZkdxltxIOO5Vl4tcieHG5VZNckrfCnBgCwuY8I" ..
	"5uFeFK2JyalH4O4ArTh6Knm3uKOK9Xh4I3zmoh6r7YZF+j0quQZ4XgU8CR6I9jzqcVIJtL15AVowyV4pFt1jW6p8aRVPrUtDWjfK" ..
	"Dq6m1r82CBXYhoZIxtGMk5TSOGjGQLl848tFsZFiHbCWMXWqZ/lau7y9riUtPVI2QZ8g7wVRI5Ec+WfpQgn++2mzW2ZnScHe1R1J" ..
	"KUe410U0GklqzvqOupkU6UFLYpbVPdLbroUqc3r3Su0yimHezdh/QmrLBc0Ztk1J2JS319PSdsiOWSWQ3xpvbE9WgyK4JdJ4fFGK" ..
	"WMLdJmHJ84zF1/CfdrF/TFV28qxSSK/pixtymsCoFw5ESVL9oWBDejizLMqZux1yvvL777lC6dK3+LFJptXtT8z/kZs4IHDJ1BCE" ..
	"n9tqSKjQRWj8vbE397DIpY5GXmt92DZJR2S38dCg61LxsZzyLcbzF2jYef1kvIROPggboLB/A3wkPN/MaPTdq0Oka+RQewrkbr3u" ..
	"L3RyVh1MuXHAJA59nZKnk21U8TDSlFTeyIO2eW7tuFZLYBRWOnuY7kKNCZtaXRTaHowF7Ue1v/E+kyR3pPTWDHO7OOGzufeqEAuA" ..
	"ZUO28tTREgc65YNGq0/2N8+NA0T1meROEy+em7/tKkXkmB/AK/LCJ+7jjS6vtNmvqBUmrG6LY1sy8Nmuo66vZKVWcDGFxIqq/ZNB" ..
	"KaQCfTLZuQtJqhUbnb5M9p98zXOOjNL/Buvhm49vIMse+oClNjClDz31meCknpyW9FzslB0BSA+fYx7zJDQrKFdrIti3L5kvAtnN" ..
	"9t7OCl/bsm7z+hIprtVIkpOXCWPU+HokyTVGo3i0AtLq2F8qyNPPsAPWmZb3quPZslJ/tGDc/CTjgaZWz7yFWMsavbZxJaX4A4fw" ..
	"EWRdt/cv4LdE5pFYdKefZWLTDq52MnAFGQImgz2lBkJ1XELDbvHqqzT6m4T34LZKaH/bUgxE+7CQLQ0W3aB3CULHAe4afELmgFoK" ..
	"j5AkFluejTRfs7mN1AGNCYMZ/09qiIH08A7070U4O48mE8Klk/+/oirJHWvrDpGdW8aph46WDbb+vTZUzLfs1YF8F5jt72usT225" ..
	"RujiWBwO2Y4dg2sIUlBdJRDPg7dASmRE2RF1PY/4M1K8eetrugYP94aXUFTQR0O9CFqTHMozrvU7bsZE2yTE8Yz/wnAdN5sGiOnU" ..
	"fezPpcKCXVrl9kSyaf3yOWLpZshUtxAVgc77nAcvTJlUTA5nhuo3CCtl8GJ8uTXBO9n95TQXDmXtDxtQxvYbie6qX5dKGSS94LIY" ..
	"amR0olLG0OkQS6xA4JjPumUFY3Sor1erz/fF+hdjun25v4JnbqRn9IxZsa20TG6R2946G0ENhM6sylVYgO0eKekzz+HLE41swLcQ" ..
	"PbQqea1k6/IqGYqx8zxRHnIb2aqttwdEUO4Z8H/5T6W5pT1eVl9bTrLSBkRsG31+wky089Uk0E23g+9Zyssqq/DEmIQ2roy71Kgm" ..
	"TKCOJnB3iPd0mrfsjo/Vuh24UqWJ6j+wHNy4FArloaFEu+15PMFknhVyKlKoN45EeyvgFXbG2lQuRIfhon9HJ/bU+0apGlI/mC01" ..
	"iKlig/JcfcWqmC2fZrny+n+9t5GZBG8VrwZgSNDarZD9pmZqD0h7xlytJJl8scGRjnSTJBPDW4ReZuSQvN+v8DRifGYeLMGKU3xu" ..
	"s6QGQEKUy/F0okgaWZU6tZyQOmQQkylk9grjpEIF4hVVpbVznJJlo8JOUPyi3XneCfhOdOgFlkfADXI4UiWZ8K2aSMI6olxT+PDR" ..
	"Ab0k/0Y2+eHTuq5FKf1U3450r+Sm3kzQpdTksdRDmyySKA25OyA1sOUTWtDqhrB8ayZzr1iweclukS5/d1usUQHJgle1vDUxQSTT" ..
	"vQ7mMNJNF6pgJiU8X9/s7JYy2oKvOABbYkO0v/oc2IxZGH1JQH9FVMCY/8zFVnxKjW50X+6iVzOdiVsTaKXgB5mGpzRqIqurSr9/" ..
	"xfZwh6Ky58CMzvcxo5FbG8OV25WauQ3Xq1S6/FgATLPMZiMFsOqlmvOuGE4aEgI0FlvqcvpokqCYU76U9gRCJTkON1nBBHguTv+b" ..
	"g8va+zc4pzYe4Hcurln+HPd5JRE0Ry9l3pfakMz7/OR9SysfBTNBPUSWenc5Hw6sZWoQCK+Rq1uNc+qwOAcUNX8duM+ALWGj5qJH" ..
	"IvKdrm5nTKsE4ZQQMxRAj95Bi14C4qhoqK9TQ97VBYFlJYspngQejC7LFwXYD5hVi5H7QEXEvkXLxfai1aSaC5mgws9tsxqPfDih" ..
	"0en4o2Z6JAdIAXJzcnl/8xK1vyK8NPUBYgk+DTp+u2zewkThNAMx4EfhsEBZSVP7Zr7vHEzVD8avJX1KuhHpEk9X9prAUFIPqJo5" ..
	"+p/EAvRfmg8iW12A2DqNpsMp+CSjtnk/DI4E6w/anxK/H9Ivea30mCcIy1jftcZBd46PUHtjWcbi/cItysOV4dvRlstlbghDnKW0" ..
	"fxaOvcJCqIPNc8nUOWvcUhWCLxeJN/hReM888a5iFtA1fmJNc9Us4apOonxKFRF/K5+LhlFi/5lKmeE1P0FuXOqk0SZMb6UjE8LF" ..
	"SQO9Z55TYxGpNsC3qYMVkJsuMqxEOxmC3pmb1yQm8et7DHPziXOBKfNaUpGK9uDxWlbkjGRaG78B6AEfRMClaJznIQA/h4F19KIJ" ..
	"hfoM/c9e7wCTxERwemWp68+xWigk33j5p5wFc6otD+slFccLkkev+mkF51of5OPuDIk23zw/eaapQja6kNWDZsQRBwaHhJy/BUgn" ..
	"CEX8oUPBJAVb/ag65szH6hSoZ5vi00cOC46wD9chliz0xyNDpa3iMVRZcspMEArpWw3N7ysnQjICIEDNkvQg0sqMz5LY3fmAuyDY" ..
	"8AXMz1VA3s2G86Pw/L1wxMvAO9S9SBVWlj302722hzbLNwZ4pEMoL/t+OVXmnoQnT9zAz0QVpZtmgxlk/BTHOq11WUccdCPpI0gN" ..
	"CzxUJwcb94AOePNyBQxsUrKbRyQjUbYNrX5HVH7A8C8eCoTw9DUnapnhYxD2icgZJe1uCq0mKtSJ+P6D/eXIqi7GDvIrk/rfyTxk" ..
	"L9dkt0mm053EwUFFsuzIyIXmK9WjEOrmXrMIUJTdOi/I8sHZ3qJnTSaG8kBWidTfXKyz2kccIBAKrjesYTV0RezqyVA3G7jeaAcw" ..
	"9DtxY0XSKE0F2eg0qSALW/y4ngFO2FTViSaa85kXLRAFZJcAXBUxBcpCmOhWazJPtY7zvtbCsIyKDL7KAE8BWrDqbOHE4DFWU7Ok" ..
	"6yni1npEkihwuWoZf2xAgNQ6e8nK2unqNdfzm+wJAwe1WZJa2CEwz1p/gPo2LYb07/4rCyjgQG/JAuECDYfQhMySnJJ+TByCOdkR" ..
	"0omMtLwRSujKWcpk/DL8tSuLnoaC0VrSE10XZhsXOjUkG6fIbHPHVSeFbhW4ZaQSNeT4wcsHohvkzCC+wV1Mu91RnyvcGAGybJkf" ..
	"M6DtdCuUgUBmFDMgqKYRCDu7/QBy90UL7Xl4v+UK+CZ+/ebrMXCK0IWQPakqWAkAXQOlAyhznx6SYhReaQatRk/zmduI2TdEsnVY" ..
	""
local PAYLOAD_P3 =
	"RclLtbX/79btAn6dxJ/CAIcO1MCc4HakQRJ6asf3UzaJ5rZ0oGAHoU+T/9btNBeWrb6ENnyBSz8BXsHY5Xii3KEtxXSKQrr4BeeQ" ..
	"0w+YdLIDX96QFsmng5pbJBR37hhA1eyc7NDaTGQ7ZCRDbno4xWTbtCgK3yZor6NJ1qMxyH6/Xg/oKW9Ik+n+B6n7Q3lH+s35pfSm" ..
	"4O4dw14jaEPeSpLEnJtoQerzjGEXa057U1CCDhehJwz9QQ1EizVG2Xj0gr2nPzG/XDEQbUMgw2HXOQGXnUZtJaNSLUphxHOu7p1K" ..
	"n69dGdVFAcQkeWfiX8tQOXNmSkypKyyy8NFx7NsjWkJompiTrfftDEEhM0Rs1BDhJT/xy/0lrbgZ3u+s1VWu344fot/Qqegsdu5N" ..
	"0y/qzws957j5uFnMdsRfyZitWRwRQBgJ7lxirgIXLwe1iKMdGno4s7BKgNHC3Z/F3Pe+RYY/WPykeptOb9ai3Evc93r5Di6+W+Rm" ..
	"lYnR3t5NIKtaZHTXo1fEyYTVNqFFT+REqGZLT/XEG0GLAjbaApPnxopLloTqHt/+Zd4rWCOThXMXSZxS4xNqVzPgj8X9jM2eJLZr" ..
	"N2QXijZi0wri4UBc7hnxdxXWKGW1Zl6fwkkmeaizp2fynQmXTl6Ldm80LVesEAVNrabbxWCK6+vK57v7wsUAUkNzLUuFWQ05DOTj" ..
	"6EMiwBlYDQ0X+9M20Ht3IIB03/lYXKlYeTtyDWZqvjoJt8+bMEPGX/GDVoR23NRaJ4FG87DxXgR9hlwfidpYBYpziPtQuXYWI4lj" ..
	"yNLWqKQm4arRa/sYDgl1Ov9kQwBaKjqOXFZBSrv4NgMqYVoRg5Yi3xyoKmfr8uEQiensC3+p1oN6CyleU0HOPs6okKV9X6nqUGxZ" ..
	"lgx0FVQCQj1sQYGKQJaXn8Z2jx8wq3AsAxuaRuX/AwSi2IcBauvs60/DBJVxslcARZ8Easlc2DxMINP0dA0VzH9nt0kB9eE++kRj" ..
	"3q7vjdlAs2upgOOtR2HvaqMBUVfs5EJllve7vlEZHP5RRP5z1kB69+wHKl0KUzsRCPE4xicvmKxO07LFg2HNAUc61HNDxLvCsfWu" ..
	"Mwm9lwmXD8BasU/Ic+MrFQrUJlVd7LATp6m2PJ3ly4OWHWmDFoYtWQdHOQ4rZJFthBLYzuTTok92uHDe32MsiRTWpDRO9K23c2/0" ..
	"s9W/j25qxYUle3js3N9e3SHreolLpBwxHcgkodv07etU1u31AJiza455MgnEv4LazjNc1KgNlrsPVQNZ6zm2VqCTcQsGc9vLZrPM" ..
	"eds7DyxBWw5ggp4t6QRoMPZtbiq5bF45q48yzl9oltXHuxjgKLrC9hUk352b7Izb3DaC+bc/14xc06i6GOxa2faM2idz+J5N977+" ..
	"0tu0Ak7tKDbs1f8012eOTkkrn4wdLa9bfacvhH+Gv8hVw044mavZOodji3XAEAlqznEytB1FLfUQRgQD5/1STBQswGn1DAgRflYq" ..
	"BveY5mgJiTl97FeW8ZC98PSv3rheQCkHwie8x6JQCS/E+vg5d7dkXI6Qq9pcz6/FLJ55IqheKYv0kAX9qD65bg0TL3eBIZjUscla" ..
	"22jL20zxADv21rLyMHx6a6RbgO/j+P527UH7KzW0IY48hQmGePA0+NjADn05zPuQLAs4g+6j6BdtCJq/l80f125bMhVt9aGSN6Wg" ..
	"lAzvjYeMEQc6MUP1NZJ9xZ3FOIxWkO3C359pWIlrmlW0X1b9cN7AHsm6+ZyOO8t92pW2bVldyYEZyk3NzVq2Qjkp+1+EJNrscVdh" ..
	"s128ZPEOh8Jqv5nKmMi4iFkckrZVEHLP+Tr5RPAKiyyH4j/82XdHiWYMi9twFCHlabyz4eTOgUlz4s8LutCFKZP0SnvAP6hMLSF/" ..
	"g9xo9IXw4s96UAtInPksQSd7up1CZB0vpnYA/kA7dTQDBbsfkbhcOo708k6/Uvy+n9G7vT+766kbjtJylkW339vQfIVrgThkeoPW" ..
	"9SzWplQcq/u6XImTa3AX84GjgLO7y3rOI3wCkiPzsMZrL9EygW8GEbcb+185iJ0g1NKaKw5FX1jLY79dDfE82rPNZ7LF0SRJ2C3L" ..
	"zClwdDVsz8lgxEp3QkJS6tpDnN0fTFZaToN94GSW3QAT6UxLhBsLIaY1OITjMgSglfYJxQMNtHUtPWx3L2GpRYzsf7LxyFNQqFfj" ..
	"WGuG9F3o6MyEtJuWHx9FhSJw78jnmUjoGot40aIOF1j7jIJiXgqTuqBNxNDlZxftjGdScbJGyu4i6fUzUrA+2CG1nA5WHpXVFnLE" ..
	"UrxLXTc4oYSjDoBLxOVWVbf444wux0LdEgXEUf3Tw9K6wiqYZLTBcUgF+8eD0Y9UX3Bwp43igFSnBJCNdi9vbyF9pGozbYs4LsNP" ..
	"7nODu+U3SglR5W4+dpc9Os+K3JRIAOspFkn8afpGTDLKgyDKyHfybKusQK9LtKGjiJAKFtFamr7Kt2GVYdVGHXx18A8lbSiuuFi+" ..
	"YC1P1q9znsv4zHJrjWAjakUG+NzZNORCcXMLBpnM1HAMalXRpEi/94iNwN5UV8XdUOWNTKcO1Fc49YZcjy6lBuBCHihMkx9jiggw" ..
	"ulHSMvaJkPHqRULsOofu3Rd8FidPDskrLkVItyvt8KUM8MnwqGE6d+8JAULRE0tkzt4WGgc1enCb6mEolellkDlQ/jzItgA07EWs" ..
	"iKET6JtBvex+ffbmuek+HbrhDone8SJSs2ep/S5GVgvu5WrPJOUbqnbjQZsRk8RIRrOZFlvRe19lPemVjNhIjWluvs/NcvgkHW1t" ..
	"JVWVU91vhZ0nmJDHAHf3AGqHebH5Epr0aF/NutYZX0oHw5qstYOH35CHHvuBZtMiDw3l6tPwH4tdTZVu2nnXLbZ0qbSDuAUN4ECP" ..
	"dX6T6H3rt+hTYzLNhOqiNNhj2zCPYRkYR3JWFnU0guYVQRlbZ3XIm70XnxFO2N/uuhKEzFKLT7bzFB6ngd3omHOCxlG0ayL0Cj/f" ..
	"QNRb5DZrZQUV5k3NfHQmAwVDrnjNBbf1pdmRUiKy6oP2Cmv6ob6sCuKZm1FyahET7inNwQai5VnmWuTDc1DTaDt1aNtt1k5QVXYe" ..
	"P/nr0gxUWmwmj4Fo/+p/cnRChVhUCz3jvXdHcr8TWXik4XYZ+j9trHtAlrJ1jmfcWdVZU4KTh5fYGi4VKZ8ajggoae4Vxll8vo36" ..
	"useLzl1rf2/1lRkfZjCAXn4DwdebUvEBPz86tCsMlh0uiuXI4D5qLnUytTozC8WSfLrSLubsvNW5h9YQwavoNTz5ZUdVpsJaGEZ5" ..
	"ilJwXlX3pdzt5IM+25MGOG77eqE2QS/ebM0Yng+18ubqmiJvmz6ZemWr3Gzhwo/H1DHh7ZQHTu2Id3Z2iKsIuROnCATrzVJPA+6r" ..
	"FJa/4+nyMLLQWNsDCzrOiq6Zf5/8XP7xdbPcaLzGi33sT0DyUWaXN/EP+TEE3rqN8y2Mz3TAE2B+pOe9Jdo6F44HRbxKOQ1fIdUc" ..
	"EWIebvOr4wpeTE3R6ba90l/fudEqF5ABIV3qm0r7bWd7ASd1rhTEWg7UnD7pURnbWVlN4WG2Kqpoeg1jfxIF4fhz2EmNFbzy/bO8" ..
	"UQEATs2WVTtnvNxGNl7dTIRk3xItGTfb1hBqNc5MWc/w/0kK1kgj6NLM5q8YUhsgSxAEwqu/XSoonCdRp+amVPpB5JyFfcM3cht+" ..
	"n32mdK/p5AZ5uYKaRE5gsimrl01Ya7W31i5f4STYRvkdI+YBCaztne7K+1ZYahJKXwpTmZ1s1YKa9Sj7izwA7TvhCfFG0zI8Q4fF" ..
	"EMdgbplfEfTtWi9QxuYOcFBUHXwhWbF5f8sbVavQ3+NzvTgLXEAi5Y+Mx7SCJm6mt+95uUf0Rxnwx45iDE3N5NH2ZNfcnDh/Y/+n" ..
	"h+2HXElbvRLtcV88LS8K817CSA9T2i6WFRjxmFKdlyzSgIyoEboXj8sKyXTXS54z1kM4PQi5/NF95lWq5S+/ixssQJbouKR1YdaB" ..
	"b7q1k0wOd4zrIVz2QCwE8Jaxrjt3l0oqlT+5Y6ZuE5pqZFmui7VbRTWkUMYWdeHwiGO6wl8RRZrg3zboYjrTKupdeLkwgdhZBMQt" ..
	"LCZFXfvOsPMkJ4Qe72OrSCBwGuJJ+xkvf0r19a+d/OoMVTchVk/j4Ma2s/GDokOoH97XnG9Cu8vdJQITP+3Nuz4lMGov8OeOguXM" ..
	"hQeoHSQWsfrIBNk3ot+49WUk2/mXcoDvvhk0OPR7n0htxw70ofQHW+xvz+I8AkN4GeahVIDsMekvDuoFZGXumuG+kN8zzwRmB1rg" ..
	"VXWooElMVKuzikqACD2u6yazo2aE8DNqch3xy8kPFWeT7DRxIiesl3lxMg5vJKkB3gxCPlk6JXDPYZRi6uA6NrOgwICy3o/mN05r" ..
	"fTECm5Rc8j/YmDkQSGuH8Xl3AcSS/Kssrc0x3dde4z3f8PYaTUygLURscoe0MDqWi4aMHflVqAhcKD+CN4k3ERVgQrMnp63TXV6J" ..
	"DQx6qMUFTHLqWIUxN5f/kE0zqL7c+5kJgsQmPuVtmegYnNlxpkaqT5C92Nn2WEKM0kmMRt+xMDUMkuvFbC1krGzPfPqMViWuZK30" ..
	"/+WoRqYeLzhVjNkecKP2jmwwCsSAKRfYYWLiwgxx/tp54yjLqZTztQsh9gPcVRXELbHbU0PDsd5XXkY8PHi8C6iWZvxtvazR7l5U" ..
	"wDhjHTijdLOS4x7wfrGMaBD2seYVm7tG3KP4Z0+ohe7dnmEIqDl12o57SioK5d3ib8pUdjaDyMDWYirYZWlakP/V4f5IOM9CUwmr" ..
	"3o2blJruqWXBu98sZM7y1xdaSkzFHbXKawiPanFjmTcSzp2dsDqa7YSTPsrf7DB/ATb3GSqRPngQI8LI+8k01lpcQ9YWFsU1/l1D" ..
	"26wMJ6sHcDneq80PqtxwQu+mOpkirARMfR/5eydpJKeVk/FBtj3KR+gCakQEJ2a/iclZRm8s+cJW/Q45PHtORm5zeeRG7AKAvFsA" ..
	"BWH7cH/SdO4CCNtgyF4R5nGZnl3PUkYYCwG/tF+I7Et784wNDrvewgUxAeu3YSrLNfNmuO9eks9XdzF02gI0HZAijYGcc7jVYNsD" ..
	"pzjkPuBopZQqTs1Mx+QKem0qeHvnzD2l1WHGnVw45FQgIlfUSyh/WIaAB7rzpNVlOaCWnuof5IFAkWT/Igsy4zBZkmok4OERslga" ..
	"4Dkl/MvIeTYD9a2BkixVfRth9jhgvd4oQIEYvcWogBAkBtYtETF13fRzA95s77gcL7ToxXqj8qwr9lbMEeMOXID4XKO6Xykrf2J0" ..
	"xF8nYQWzr1YMXye0S0petUeP8fpZc9h9uUfzhDSRMgwgO082BHriRrEnZmsHpIzImqkJ8Wv7WsSV3M+4x0u7PWd+Y0Z2BkMEKPGX" ..
	"7CyEwQ3s5j6eZtJWcjvpjw+bCLmgoAvHz+fUigXKMNYa/LFxFRehhgECjyAhgr4fMGzKY3SiiSlJ8oOXEm3nDhVB3sYBaazBy0oV" ..
	"1eiXsmrNedjXUvdASVR6gY3A3MJ/qeVqO0Aq2v5ZNV9k99aM6t3wcKwL7BFucUJCwVbCGPCiHVGi0CP4+mzdp38jiboLHFJ2SZUm" ..
	"+e+J2cBWkybFAeEcqFja4QrNNTWsIP4LAfZ7A6tr6HxGoZmBITexnTmFHrKQnz6pcUlyMyHYlzFAB2z25/Xi3SHtK8nMJKAIcEzH" ..
	"uIKnvL8DJaV/yud7joE/fSIkACOfZUxggt/s+JotE7G3JCqzzilx0RXNHyTuj4J4OuChriKt5/Cllj7rFAtEOVo40H+CUqmfJVtW" ..
	"qI9t9tjWWAhtLnduPwF6ZnwOSX7g/RzX2ULtLEu/jTB5QaQO5vyH2gVp4bArtYsp3sbvIHP3OplAJC+IGemNFPGNS3oMNVbNgebv" ..
	"/439mcurhb62GLeVKBXmSPG9G/iMAc3nm1lBqBjiIzQZ7dilK7gqNLdJa1tb7a8wxGdOV4nT/S8jp9yMmh9lL6XYFWgcNc1Q8qYS" ..
	""
local PAYLOAD_P4 =
	"iZNejot1qm3M5rjTHN7KKWyIHRjM8SuNubKnj4d7GoDTG0eEhtk6sF5gXA6ClpXW9Er/09PevGQlDaD6GyE9YNwXsVQsCBjvXW6o" ..
	"tXdabFzBlW3oUABdsPE61b6K/lOrtEFp5FzSdVpzZiDQzNVYAmrxyIcyUWQZTjIX99EWwXwPEegq+6tLqrRhBAZMAkbQbEyBqwaB" ..
	"9QYYuDj7HxF8QDxd3uUKUgHFHcuYsJlfZw5IZBsTQxnONd9teHC212dMwMvbxcqpbwePKWIdQJdsnWLaLR6G5oJE7I/OdxEdGNzY" ..
	"wRkNJ1kpNu+e9kKBunu7b0/JvT9JkulTNs00lb31puhgSMkDMh4ROTM/NLakcdB3rs0Ipg/jFayrQMZFLlb8nkf+xoZPT5cUeR76" ..
	"3laVekwY8jFZL871dO/MTM7PWpiUgj3Uh3RZ1PWzU97BtjfuGE9zUlanSqskyphXTurThWp6IuG+GArFnQQuOnGMNQq+7M5NOLrS" ..
	"zbbBNZ3+zPj2nEXjGDR8+6ncrQQZGt3oschcDz2cOJcFDqFDUgG8wzJ8gaPp2UkmwJtXHVahpmS7eYUcf2eDXqGcSZ2NStiYtvAP" ..
	"s0DLiLELRqHdd0kRi2zKgnsGcLK8h9QSLAgOuADNSlQtaj7xZnTQUrrW3ip0iy1+ZEWLviS+Loc9nGJjRRPTVqcyKMbCqG/brQdU" ..
	"jqLudZGzvgJKGXmfxJ2sHhBVb2vWDUoO0cTsL71OjmMZwg1nLP0l6ktPXg0aSwjKRjlJ+EUQ0Pl8ZFMN3utBa17cxwjQZQSSBTjX" ..
	"Lnb6kptO4tUrwPTO/GG6rmbhzx25L2oGbn8hNI99W76Yowhg6uxJPfFTh0fCb2YcdbWPrMDBMKrCTvMrD42Ql3Ywf7zACRHcnRZN" ..
	"TLfWqERdCrwDOB8yPaZHPFoH+XbJXkfGZiV/DMTI0uM+U9Zn8g5qyrCmGIB+82p9PGLF40yw1uOzeVnMP8RhnWHbyiVS12ZYqUu/" ..
	"LsSS7KI43xT3FV2+uIj1ho4deYQ5ShevGWrrogTyL6RbK8FbbLQlmEHtne5os5ywGb+WRwoTLjypwSI+LF3yavtrvnfV6phz+bZZ" ..
	"k58Nn3nKYBw0xOmCoj8LEs3y8mKOCCAIcVxHaOfMttHIpxATV6UdKqCDNByhmx9H8jpZA4fm/R+zULLDePsKf37vmy8omXL0uqZ6" ..
	"xzbGN82AtbGxdvUcgEiXUFuYJ8D5GbMXkHW3AWC7QkFbuiDL/5nWQCX+ICB0x5ORrRNS7ettZAbvHzOL20DHbSih12R/k+SX8kdT" ..
	"/YLZy+aVzhNkS9Gl9y+HbeiptrRkkkdlhexd/UGwEX3UMUNF02w81dMkk/YL0KW2rcFu575Mit2HpRSf/3yv91bXbvwABxc7T0Cr" ..
	"jwcPl6qHV01eBAeY1dagaERv1s3kV+saF484ci2PicDFRxfWcI/XsmmLidwWfnYWROxFq/UApaF96WwWLrV13xyOLATf2zTbqrTN" ..
	"LtRLq8x7ky6WDsc0ntvfp6bAiR1ze17/K+T+fdKqc8ec1BfDdHxp8BoYIrzZsCuDpy3NRW8VUZWzONjMxbhbar/up7YTO0m19Fjv" ..
	"3eI82JMTwJzHebWNkH2HFwDOeSnUtiU90fwAjOjVT6Vs6oIkzL68J70D2L8Sn6J2Ul1JVFVOqTAoFn9gtFoSzkLDBIsET/mVNqC/" ..
	"gjjJiFtFyEoNbf+mKtYriuVxoJ4+tJ4WUYKel/ZGaY4yvkwlyJslCcje9tJQrMEnx1v4/HErlcq4syMl5xeTT18HU7GiaOMtXSGn" ..
	"eBv+Zk9zCcqYce5TpbCIMYnSj/2Cei6WkNtVSVblgvuFQuZao0G/9lL+Rd06Q59vV5MlX3aczA8dGza9CZFHyVj+lA3HiJUr+s7s" ..
	"CMCG+MpNOJckRdmsxEvYePoqbtAxQg/4FwW19Nx+CnQJs7nsHcofp5pRzYoi8CPjkZnSzk3QPtnWeCYpyB6ghJRbY3iujjgmABSI" ..
	"Zr0PXymSGqRzhwWPoRywdR9f3YOCipVR1HigSbkjWFIetOacjHjPS0fv+S3uwnAKW0L1XABABpOdGLQk7tf/5o40cVuajtZA+UaN" ..
	"bvZ6XD7P3zB+zSpa0pT+LjDbW+kBNpkbkJ0x99w69ZShoJwlKJejDG+R3RF8MGnltiR7p3imXtYSaPwGMJggUSwL/YJsC/Xi0/VB" ..
	"brZgc9XL3YvKGxvvZQMEYD0PKIveLhZMUfcSzZT8YgPfK0WnsdN3eaiB8le6H8BOElC2emkVXPGUgVc9NuvrDg9xdxIIsURLwASt" ..
	"zhyF+6bMMJSxgokPO/F10dOtRngOAL5FTg/qY9vqY2huqKYKTYBoexyiQwLUyBBY4isZLdnPDBZE91DloPX4L55tfxX1hNBHHcxY" ..
	"bwCBRsrGZLXN2H1ZqHJNHH/kudoa7c0YZo0oe8+IhOeg3EZTBwDmuh31XI1F6ODxyAnFbWjNb6b3KyUHS+IX7d4ySZf5a5zA5Gox" ..
	"T6mPVt89N9YYrDQ7QvPwW1E/c1DW0zNrtrCyLkY7zckCAMg+xOTJPPFLfNEZcHKfF0pCQEe870YHhVIhX7GjxuLU9Q9EFDWXJrce" ..
	"dlBv0p0AscNTUFlVyQD3bXN1ze4TWVTGaaOdviL5JIYl0GhClqN0e364/xvLI7KD5baFiCpDnEtVo/PDKMTPtkvCH+FjINf3v7d8" ..
	"P2YyvorX0xQUld/IOrK3IkButcgR0PRq7GWhJD5c1LlZpldids0agMKhz0k3TNZ91Oe22IlmmwEA2EXdu3wixg5lSuibHeFdtU39" ..
	"/eGJmAItjPwbSx/m+P4pI3k8z40BCPil9fDmTPBfgk5d7cp+vrcmguQIpbS95zXR3LZD15P8YAQKRhXMls6llNc/T2z5I8JE1/tP" ..
	"YM/XlQ1E9R3lpIr5A7TMTWAI/D3mamFCp90JEPsC7ICuLyX5z6B9HWqVK4dR2U3FfrJUTChCYluVKmJHHyDkZHubeXKTqiRhvhAw" ..
	"40jTqqtBiiAtHLMc25E0tIA4bb7MZcqoLoYpIIsfSmvaQy2s790sthX03X113/xRh3IUBvbu/rQ4koLCOH2+GLIi8yIY+0nH8TcD" ..
	"NHw73hqncsSKFc57ITKIB8sY7IJav7/ZPAgw7JuaHD8DojfbI+GJWOnuZwLzoE5yjGBhAwh42brHkdFUI9bPMU/HOhHWACl3ejnH" ..
	"ReZYicluqanUXsa9QrAxUTVpar5gG9kyHN4QAO+VOwUcm2ovMhQ5loZ7pFVWyuEyml43Xa+WyItgVcD3lse62vPiWHmOidxRPxSs" ..
	"1ihsZEvrnwHJ0Czy5o+My6d6+ucUmlvLvLTO/hrmTidS3ioU+j6WiKomDGrdYlELOC/JidQXwd/1TshmUnPOREpA5UNNICwNK9fW" ..
	"knFJ092Ou19lYt5Za6Atv4Gdu0ux93uSBZUFyjN/2pavMutSwWeykyOJMiYqP/BqHphbkILQWhcqvNJg66GujxgKm2dcsoGTaqph" ..
	"B6SQWQi/R5jiM8Tf90taNRqZgYkSqVUtHXpAbTJ7LtgyNQU4Ut4EEGrQz85VEeORaoZ7LknMtX2qViVkbTAtQ+Jc6jfiJqWR66xX" ..
	"jQSeTkSp1z5qGkpqafJc4IrqY2aBGSScnpDuLVPF1xqYdrqCw8W8CwSZ/UawC39q55LQubuJ+MqoJEzoWzTd+1JkwYou/9ybKGLG" ..
	"oW7KSzemv/VLx5AFF4Dz7olimRdZhUJ4DRSF6o92PxKXfQ8U92G3kb7lGQlEbytj959qCHQRLsrRXsXQxPIUi/3OI2lJvW4ok5DB" ..
	"zsvYFPGAn5EUNZAIhqkzzcn8Z5DJ5COOoN0b9tdlw8nmTT3H8mlVE0mnyz3FPiiqdVHsoJ4Go4A41IM8QknxVpB1w0/7rqNJ2JRY" ..
	"8RUkiJohhq+8vna7XGRbSjFsCRfBy4WN13fSr7hJ+Ts+2gHzWLoSkY4P4CC+KQRuHsq7eaE4rkilQB8ZBl+A3bwZQf1izwIZyDEB" ..
	"MwuHbEhH4sbP7T6PMjTeopsVKN4fuaXg9fWwtUYNbXxndST0Z3M1OeZRqu64+8hQaOTs6KTCI6m7hOqhqnCAlnGJkg9SEkr8fL1e" ..
	"R2kfooa6/osakq5bFO6GYmYCxlULoYCtQixS6f9rg2z1ob5V1DNraNQ9f7YnM2Z24XeY7RzTtGa8/8AWJcyuGQ4ayBCjMQkm1cNX" ..
	"uuxgKTECw6GkrNjm9Z64vMvE0zm0X8yIxjo/eNDiGs45BcFYbjARHsGpKxVcrKwoAFIcoN5H/wSGhkieCncdSA6l6gr/bkONpOdT" ..
	"FxIySBj/fLegrcaueENUOOZQJ7bX7Gyw2ZaJwL6ocvwRErfvPXT8G7eh3P+c6pmuvTJ8GyOZUT6Ao9x8RQMUm78HyOnL6sgOXQC8" ..
	"uO5xuZDSDBK6k9nTWveIql2+1q4B78rOV/LHb+JTNlxgto/fnmLdail9Dv9FLUoWD8eL9nZDEK+m49NJKMc55QPZnehMeN3qwKqK" ..
	"I/IlCfGmgjuWCXDUtMSIWxbo4TjwuIahjHSnZCm4eygjw8MoyyPJjd/3Tud3R3lXRCUuWSFHSFMgLibTYvwhtkQjiIGfoSpJ4JLR" ..
	"rPbTE3yk6QBSR1TPtrSOHYDFFYwCc6+Jl/4erc+GBb+6W/TaGRAY03/QdOHNfBTUVD20qzGIITjpLAJZAFCtAAyCYmCh/dPOV8Wm" ..
	"wDjjK8cFcou/Ryn4PNvkNJQfLOP5nCxHV5DmA2rbKZ9W1xjJOJZZ3hBnH0Hp7kEUj4GWFRvDCn+2giDREFeMGL0f6bUAPMGDS6VN" ..
	"SMp4I+OqZ7ToANcpaVe5OekZx1AW1n9AAaD+idzGlQoU2KkyyVoZAtICzSv1RI2vA1/qRY94UMKOjHZYHe0KSuDkgnq4EG/ZVKeM" ..
	"hZ5w4ME+3lHDNVQLu5oRVbtM/jzANYybzkKQu0mtHIUtJls3K2F4DyYiKwQAEkpA0o7GKlyYH6si5eYMNN0zPJP442MKI7iywEyC" ..
	"kQ74t9oeWZM+L68hkDMS7O1iWyQ+IGfS1clhIL2xiS1HQbhw4oLPnEkakmqWuxIQMseagPWklQKhYUwyEr5hFFrSCZt3o+66kK5w" ..
	"3v82b40ncLYkA3wl35wDZnDUqQbSVBn7Vu9swZttr3wNHtDTrJKmxdHtGopT0rFbLaGXWRQY3gpTigb9lks3A4KFrYaI4LBN5Wed" ..
	"nXKMKoHli1Y0vErJPdE/EcGyd6pd0nzylqaQkjLhoD1e6u+Bupf7lkL16FZuOvNBJEo/IivLkGKe41YaHXPLKTSWtYwwjVDR5Ph/" ..
	"dPtpfyrH8ppuIGWCQEn0chJDwEvy0J34F/TeIDyD4lbVJ9CKgV98wA2gjchoXpr+OEH9Q8jJInuse9P51GSr/IZCOgC9wR5DbT1R" ..
	"p6XloSw+hkiV5TPCYYqpJogURSWVr/X1nWd8tbSHbYAK7Bbm1i8OpIFIDsqGBwd3cWAW1M5hw93s3Rk7eQgpQRqhUkAmuOoKU3rG" ..
	"gQamk20q6gCX4BBvpDbg6y0tL8NN1Sigv8hthZnb03axxc09o4Vhge5s/4XRv7GHRJMaSenX9b/KWqTifdFs9NGNKSQB3/5WeEYU" ..
	"zkM8lkj1ApKIUIrNFRXV28iNjVanMg3nEEH494TX3Xc6wYDjLJwCWOtvf0iJWddanGMDDXFxGNAqQ1mIyqtKlvMHre08voRoKHsR" ..
	"M/u7G9cWr2iFFAkx2fRu/B5EOLWX1gcIj03FE5WMiRu+zfxa7w6slVEAxEbb8V3vPaZRticLGeYVi5tEXIk20cumd8NbahB8/3+U" ..
	"ZAO0Ae0VaeIXV+mHl4uuaXfpbOdOTAJZCGdGoSCHf5OXmwp7J7Zy9j5xnI0deobzjAnjaqKBy4EJ8GQYZjsWTjv8fIck3tTOeJPa" ..
	"2PZA9DI0X3WqBnUn+II5z8IX/q6bBSSAkhTGUW642uGpEIhFy+IjSFPeUSHHWCmmQPioeGadDR577PNqZoghSSb2r7t0qpDpToxG" ..
	""
local PAYLOAD_P5 =
	"RnJTWQf+ODYtOYC3UWiCv+CzPQdasZh1W+QHqhfMCVlyr/2WBbF35juWwhhxC68AhC26uxp3vltAj9k8/KIbjgWtfnH5ES4FUJqL" ..
	"tJL2i9dVpcaAvvLT4D+qtWTsrsPhFCPcA/Zp6WwnGbuZsJ7wWFv46UCQrHFYKUzKlrOvRWM0eL61yyl4nXqzXH9iVk20k8GMEMRq" ..
	"MV1oH1i56kYJYvSaTeJ0+8xLut6QO3gstm00tMm4WwGlMVGGmavbmcMGp5l3+7ZRHOK6lNvQgKMaPhXktrZXfxGSTNYwmoJNbeK7" ..
	"iptY7zNPgH3Vd1MGJzcI6Vh1q9ZFmP+5QEnktLJoOXlYeJLc8XU6xmIRg2Y63X3gCv2g6EAGkgOKI1HIESurchUiY8yn3M3IzrHW" ..
	"dNaunZDJlTQlJNy1bF1P1Iba92RqAlvzeuFlahUQIJUd3MUcyEwyGubqEhH98yccWZmBnvTIT3x/awLQrNQ1pQiVMyTgOwMOs5LR" ..
	"w/126gaQkxGcXSTFBvoGzXITYKhha4YG29gQz0LleIMwGCSNvAHgjb95GRKRhozdi0Z1FN4ArxLqjjzZdI4SIyqsdMoGCH+/TADA" ..
	"lAIYmBOIBBQAElZZmj6SoG3dTLePLBfUUic2H/K0Lk4p+Cr/Rq9L5c8gnj2WvrpKuXtKSjdnt2fgBcQsPfkbwp7k3l0IxNxTyPYD" ..
	"n6BxLLsORrmSsEEH6rVx8UBBN4Av3jn/kY8MIVOKjUpQeA2T7l8cvgt40N5cq7zheO44OZhuNDQGIe6sThsrcSMRooGQFgNrWokS" ..
	"QCbNMD7H1cF1nTUbiVc/S9IPB8ywNZfkI0VXt9eTlHhY4E+ij67H7IUyTh6gKmbo7JCGO6KccUjLsnwV7T9LflyJ8sHsNPyn+7F3" ..
	"TCi6i/szqEloXVlY/ldIRIMv8RT5HmH26rZIPgzAae3x+ixw/0FlmMB508Ix7RnxnnVRu3xzfHsusPlZrz0d3MUfA2bvQfwdAM4F" ..
	"VdrSyfBwgZv7nC+h3yqdo1zUI+G+uGadLFfU7itqVendxkm+EdHpjFd9Lk+CnxnKgP/XeZAlEkcWVHbL0gsz1l5Q0CkhxRoPUWHh" ..
	"cBEAF85tgE7HiPc4R9fUyZAfAlWDjYcE16cFH+z/kWEpekpWbvx1z3+Cq60p/wqDYEYrhhtSlDLIKx8BAVcAflK35Q8Hoomx1pKN" ..
	"U6KIGKqSWLWHToo4eSsyucUbhuBfJRzfNcn9OkFOgwXDkJxZEo5aA3P4zXv80AC5Qf0WmwDNsUteuAJPIKUOc2cQ5LhbeS0qKZJY" ..
	"lP1agZ5tmJXHQoyKfK+BMl7HcdEG+ZZvXR4B5KTvbtYZD2VLAHrcabrlGNFFCA9sQPFjfUKzEYuOtPAci1rXxE6L9Jt01QCjYkL6" ..
	"hozBUBi2nrc/z7oX4ERYrfdzB+HsRvbS7ICe29la9YRHorYuagOf74RssenJx6ywpbaZDmt2DINAzBI4ExyU1CJ8Q/5j2VavCmza" ..
	"1bZvXZkAA3hXLE1/BJOvTxg6zNCt+NyR5jAzzcDigJr6WYHW8SddbPId56IxFJwpkm4Lf+yEkrFPQnpu69b58RTCeXWgk+E/NBCW" ..
	"UUghIDne9HBMOPx+aZ0qtgo/g58SzWiPMGo6NZe0iaw47pIYgkzTZMhi5WmdN8+P+ooNOcbeHK+nQxUJTVuZDc/6Evb7pVkrY2RI" ..
	"7E6iQrKkX3NG5jC1GeG7HWbdEkW5pEFbAKDjLdo32Y3/FartBlE8k/FeTJKcIwJmV5aT+uqqQpyCllPQTASXsgUVLtSWFQbhRoG6" ..
	"l06qNxo+zqRJUWEf23HSo5r02fB9toMdXcPFYaA401yGhK4CiXJa0e1rJQj5NgpVX/5a3LEqg6cj+Si7I+CSbwS+vbewnIMs1APM" ..
	"oIoIAV8o5BFvsOR8W3ZubPzYZ3QHbmln7vaP6/EWaYpi8AiKhL3WR52siJs/BlxH0tP+nDO0TBB928J1GWaojEwmBZB55Ht4dR8s" ..
	"AczTeMEg8Ob0rL4kAYMF4YRRxZ9omn9v/JYHX5wvkZKZYFykMT3Ng3Say2+Y3C7skBcje+elEo5FyaEzKaXsBwsE95qKOzw0f4Hp" ..
	"lC70bPUnUa120Q4XJdKA8Y4sS2AYoU5VG0cQyrhG73jCstKpV3Jrj506M51ir0iou4vX1DSV7pr8ByTeRLrzG1yfRgZHVoOE3KhH" ..
	"hXG+NgM/nv1qZa9XRZiezN/tK6nyXJ9XUUf5uv9Y6iGSmCW5ZYvX/Tb9DD72MzjcaXeOGdpI9aVGHRiGv8KDwFFkqKvPcA0EtXj9" ..
	"kEwhvHRGoT1Jtwv16L1fLx194ZLn1vy3IPUqqkA1O/j2ojER2BjnhzR2Xf+ipssbv6z5CrWM+soYraLW3JvGvO+m9aq02m/Y0de2" ..
	"JEnjaz8rqyAN/MOfshGCX1NWtaUq6wOWwYmLXNcTblIEHNZaken91oZL0CpR4DppLQ5Q1j5udfbCPt6ql5FwSR+GSVZLiaNSMEk6" ..
	"0iLyEuQYMs+pHXnCy+sNIRXvx2UQI4AYfg9PNG8KWWjhyu1GWwSnpOD4HcxG7ov87nmX+athuZMrP8xkFVMu13sVUtWvvf2y5NiN" ..
	"DpQfqqdHzFJNJplBhJ4C4TiSbKuNNgwnlYmXwrYJl9fyv96HS+4MKuw9ekrzoZXehbgHvGo3a3j5+XKwNz3RdthPyjA0lL6J838+" ..
	"Qm5nmJa70yj937iCWBPLVUBJxXiRE+otXVUXl4Z0bZ7+xoS6Ny0cn/0PPI4rGIS9DpKElC1QLtFF0wPcRt+m9hX1vQAALdGJBYbn" ..
	"4MF0TuTRyA6HqQKZHnWJSqWesu3KjkV8PjbikjWBZ1g+4FXdrGTYgRRouB7wE4mZFPHGi1+WwmOUa5znREH1KOxQIND9y/R5mjqd" ..
	"Rurx1YzO5U3WjEqDfBq2DjThs38xxSt3oHMS8fOajlg9zotzFTpFD1HP+8N/t8t64ghD4eWgTVjT617hu1tJzPFPB3M2EMGlYE5z" ..
	"VGsF1oexjrWf6k/ldageuxv9Kka9ft/qoj8iy3/wivqreRm3jBNe8Un+/d/TbDqshn4/VKKb9dbHxCvGE1B4nvP6dTqcLQHlOb16" ..
	"vUaL0g59CG0btp5wZRdB3Qjme9FazTLwufR6uP/ETAxJX8E5J0pixBHlv3WDeiaYP93/62qQFdqa2ZO08Y4WlwsIoYCM3UzMtMMS" ..
	"b6KaYLxNOrcraMDsZpv2mz2f+Bm7R4ke3Nq8LXle7P275f60ueatb+2qgVtPs8o2ycBlsiLigErNzuTDoY1ARqgFoSgHuxmekQRJ" ..
	"fIDHrNDkhdHDGmPD4HSksCY7i0VhJTqF3GrVrmgq6wxHdhfKOG3tf7Ox2YukK9cKFg6VCe21EaPZ75i83xGxeFg94FYy9MM4nRMI" ..
	"Sz8zmwlIu6RoHsbYP+kD7x/gM//xg+GT7jSGH5h51HAfkpei162V6tpozmso8ywz61HknBRjleObkROjLCz+N5aFaqWwdtDE/5Pd" ..
	"sb/bUhTNgXYLYbbTBAScxapb87e+X5878oH3Pjk0o+Q6VYrhzoQkUt1SnMbr2oiGlXedq3lJ5WU5v0VaXkUrcoAiTx2XYTTGG1sO" ..
	"JqURxJJcBVPpJTXzU8EAjcrme0MsKS41v0QaB7y8yEUXmHWK6U4iaWSJ7J2WWR7O0YcMpJDG2PvPzYytad+7VlUQOrlNZf2PnXQA" ..
	"s0sfS1+L08SU/sA4j9pzMADH/y8wSHFU2bTCmZbAj6yPzEzuj1dupONzZjqxkQ6nPjhDVOxejXo7fJ0uqxIuHuO/jVrW3R/5e5DN" ..
	"VxCPObXX/eN2XQubMlFG0/gw2AOXSLyGmQIXbh2maMEtQ9eknit+tub78rafR9m94gg/SPYkGk9nGHGRQzm8xuGmQwcGWjX7fU9p" ..
	"UJjBLTiEzrR2N4czyh0Vgyn3aTeV7O1qEl19GSe+Q+c0AuK70BBWCaQwI39qPqQPBE63TMpCIeZ3o8496T8DQ+C0pSaEHKEgMILz" ..
	"/YRPh09gnV/BoldZ3+M781nxbJuSiRyyAPNAm9rh4iL3R0OgVrxq99cngqB/Ix52xI1CMm018jTDfUsRy8rChQGqzzKQFrSGHDg7" ..
	"7tLEjmKWh6I32qKXIQ6ETnXRLR6sVpK0IhKz1NnaMAIl4nE63KLJ4iM0LmQMe1fuAzkyLjVHnymbzVNOz6+upWAQj20ZFBfOC9ZA" ..
	"xtyVd8OaYSw8caENcO3wn8Ik0GjJrWVnMjdykzJbThlGtmPR2PVUMl/Zgtoktzfwj9sfww4G3intmPg8vc112zku8+uYsy/SFSVa" ..
	"u/goj1Vou4uwD+yxFAnggOQd8nwSqr1MTzqgugDYV0A9WNo5UxreL3SuV9C0+5MVktXTBu1NuaeogiwDZC/3dHoA8wI3zFKfrcAm" ..
	"uYB8POllWxeARE5rSzFBsY0rn/H3z8h7D9JVOJEiQLsbbBYzURhQ2VOdr5MvxLw7NNhpYuJ7f7drTUPnv/37Chuis+VpKSUPibCF" ..
	"9u3LtsVyu0qJ6vN7joyP2dmv72AA82wRljBNlLqJCcpPUeEhGXZZM/l10Kxk0e3qnHpaEfSxU4aJDYyfeW4yq0LXaVwSt8DZF+Zk" ..
	"7m/MiarE7QN30ApWq+V+qJ4oP09HTfsnSU15admQkeJJmj5xER/qLdNxEjF247ftU8MSptKFTI3DkKJc0yAANsOrjxwl3zxHL/Wc" ..
	"Ea/QamdQdiYswGLxXHyczISoq1+B5QbqTWGrj3kNxn6rBMpUi4gSe4HHhHxRNsJCkPG3DDOwlDDkdJpPbSDGT2qtYToo9JHc9aZG" ..
	"wcPZAlXlXBqMLCcqWrKUANs1RBrbhj1j2Fikgij5jWkJaeq27L/lfePXkRz1LPmneBF16MWDv9IA5u7N5D4yIVtTxtfTSoEhNOON" ..
	"xdYdfPHlQ5AwSUaR0jJumsIG6gPoveKDJZ1JXH2Z+fCfZgh+d2EXswf8m7/lC+Cd3rXUZ12DF9O2Notmfwmj6s9zC5EOPfl9aip9" ..
	"qjIYgH1BoEpcwU8Es1/mzjxy24w0UGRAbgLpnSYjgAM6+et/XP6DRcw0xy5r7vVMKUmYRvaRqy+Xh0LQ6OT1P9QUvtGfOEqfxnWL" ..
	"UEeq/lFaLfN6NHlwZ8GiyuSxLbdYopoeyTcbXZAHCmyIPTv99GnMhxqWXKx00SZQN8lVpUM3Wgdx/+6xKX+ToY4MkIxNJzbFbEPg" ..
	"/MDoNiyeQQFAeMMkahUBf8XAHLz4I19+/9Dot21RqAIb+s6NfSfumCFP2tIlhHe2V7FdS1JJg4d6V8zjOK/oNKP7oFlfE7qsamVx" ..
	"aRCVrR5oaa0Mv2ETa6VlSgTACyc/lwMxvqXIzgMw8FiBOZiVGvWpw1bMAd+h1aAP4vq+gIjQPnFjtKD/hWKouFenXPSWTtlXelzz" ..
	"XnriENewiQGUirSFuIz01eSwH1tRqh7aovUNuIK2BPfQr2ilNRdKT+g97ClKx8oUFxSmMoLeHGGPoaiJNBtwS/eq9I5pj24rk3U0" ..
	"EQqjHlGllPPgeSZQmagf7BnpLKPLIVghxZuo7M6yQgGuL/AyckEwnJczI469Md6XPl0DZEqyQaoZ/LYOyNrCfTLer/as5XvD1S9y" ..
	"RwZ94RnzFPYA2nOsMK/pXUS9jetMzXT8sask0CQPvVYwGdmfx5Cgfudu6AdLmkUUbqaowPZ+AJS885EqqTRl6dBsd3Mrzyqsfo5P" ..
	"+lTDknzPDv2e/kkJwtpGEiBjNP0/wAww2N/NmxFTpON6NfQOlh7oQoxc/XRXeu5XT8Io2tyryau6UorUFhAcMnqmlyQHz894nVKN" ..
	"iKp3C8+Pgx4NPtA55d0uR/c8QGu7KcleP0/vnda9Dm7sG3OMXYcrDSLuyFjoKIZALGoj2vzOMPSbKBYUoF2u2h6tfFjsqqS8X1ON" ..
	"1KZSEA8+6yzVNpHjkjqVBIKW1BaT+vsp/6JI9JnYcukKgiri3SsL9xTz8MH/7Kgr69do7ZzIPtk5cGPkgIeywVjO+bdcvq8fZURw" ..
	""
local PAYLOAD_P6 =
	"gIAhynC629AYZctdd6XJdOS43c0G1C71aF6VGGxVKb+Vo/fjSsdWrDbTVho6GZubGDxY9GB+FkmaADdDMd7gX5VpV+hXLxl8CtQN" ..
	"oN6ZIyIyNuvtqf4joyj9ZcJRqs5uLiiqkmejJwlkYY6NfOC4svkiNEn0uo29Bk6NNUppMaBQNL6QzreA/SOX9CWvfWKhsySKtg/d" ..
	"yFfm6aty3iTulVJ32J0NZsM/cewsuQdZPVPU7AmovKy/0JQHIyv/vyyDRffFLKtRi82csk0tV0ejG2I85y7WesWjqKOLHZlpiuHv" ..
	"ypdQfb8IT+2E1vthki6v1V7PFWFBOMK/lOo0FROjJgaBgHNfWZ+aLYiIYkxb95TfO4Wp5sWacKWCTSKjgmSLHHYbN+JPYI1l5oSw" ..
	"HxuFzIdHUNPGN+IkK5qx3OzJ3bi0Ihsr52Ybm3nQ0k2RhguyiLmZOylob8AlXMChLr7gL+YovRm/APvFo5XlYfDmPLq+LePkPAlF" ..
	"AUEd8udZwx1/9oGzKsRlyPA2ep0vVpNqbDbNvBuEr8NP0AXj80x0hw888MNW6ixJsXKycno/cqIj42cZD5JSPJbkoe5c/x4L/eha" ..
	"HhVjfKhE8/KWP5b/MmPmtIlUuCH+7VEIOKyE2bK+deNw24vp7963tc0jibyjsEmxB9t7qcJ+OdjEncLEd7iu++JP7KlHtbYvmaQF" ..
	"6erW/BwMGs8XlyutOKqyT4JOe9BCatbb3lSugois8khBKDAoEt9rwgKYPERIJYe/e34oF5uPW2TdX2yhiLS71yZpJn/hIXMu7GYZ" ..
	"iHlK0A4G/jnq8CbkaLIx8MhMLv4qPlloV+m6dAUoYJpCy+wEJ+h6BrWssZsRilTRf5H1ZTxIw1b/IzrJegr/2RoZ+PfGtQ6p52+S" ..
	"lLLOslqcZdZ6DAMeuZ/CEZrGLaftPDORnootgL4UMTinqXN06st4+3MPXJcGUghZj/LvnJG5uXhN4j4tzQ9wZCAN25AVCeJPaFU+" ..
	"zDpCKqmAc7qWA5vCctMT0mXMI7Y5nVA70kdF/UoOrSaWhJ36Xy1h3WPrOwxVzV6Syen7iaiesFJjwvAXVZXt62UeuQC1rqVrhNmJ" ..
	"JitLwmhs65IL+OXoECs9KkCr5neF2PV7QqZ47LdxNH9GDZDW/jevDusqDJnzPEcEt+ORIJhE/njQx1E827vQuyhhu7S33dWgLq2H" ..
	"VKPicz+U3cf7Sa49cWG8cCHw6/zmYF22Z4H+EGxvpwNDGFJdg+L85VF5Pr2iVfcOCmbDZ9h1bJyKiVPwyum5KvwOcr3P0xZW5u8k" ..
	"N1rWK7fladE2fsDovqxyQ4YAf5l5g/6sposvTrXH10ddBZ3Y18GSTaGhFLAnZdOPflLOE6/rlYm0njRJIpJhq5KesVSeI78TTIXM" ..
	"oFWISWBOdE63fYzANk9eMvcYCZa7UQhSQb5FtgwjMT9IGmuPumT6gvfX6rK5kaOtziphbjJHDxw1KdmIrinNj3fBnOj2b0w+3wW9" ..
	"Eb4UvIFLSqvrU2WUwVZ/f6b4viPDN1LwcYmPSKawBADtljaMCg50I+GyHC/Svoiq83e17t23xUn8GHDqqblTsiwkKWkBr3zmLezT" ..
	"HTc7228ob9tmjcO0GhJ8fGog71jT+1qxmDtqQL6aitZx3TSrhnITIP3EdiIYTbHbx2rtHJFmjzorztg5dnXHZvZVHO1KgUY629f6" ..
	"lF3jWRwSa3nNeosMGPKV8agkReYoLos6KCkT1yO2Eac2osLuM/kRBEW80brXhmu/p+0zQFXBybiyjfuq8jwMEHkU8DDFDl0NCiwZ" ..
	"+1aMe6D/XEjl5FyyDPpwyWTUtthujLt/1clVSmEWdl+O1q4dHRd/oG9r00VyYq9RAdqrkTHsxCUclTbaEdBnN079qQkfNtbvC9q4" ..
	"9rePVTQsj7hTmxX6Dj7MSF7NYv4Ui3+kEtY9IsRqBVq6CkNRR5UQPbjgpPJN3GhNcEJo9OFyaI0OoubLvfNT/VKc27GCu5jF6zSR" ..
	"+cTgR5b+cboGgM1KVoak+lpYVe3UqSRoQskMONiliAm2rVCxEfRQ8w2QfGLuc7Gb/pL9GHDTZN32LDBgEFmA6cYMOA4rFqU4rkAS" ..
	"REqIZ4fEyDFRfR8ISVqjF7+IhCOXMVk0dk/Wd8i8Cd1w59UT1cPOgIbKRXQJ/BUyV7lH61YtvfiBpidXagJ0mQ2d9uSgqtk7CRNu" ..
	"VJimVgeZY4OgSBvq31E2NvIHnIbvWNKtrEJdAT05pS/TsGBDj84sPqQ+EFm8uH2WHBshv9yECKWwvKLSi2xKv7OZiqiu69+4WB11" ..
	"GOpQQFLgs+eZ+iqtx9mOCZKfA9ifLaveBvrFt6t7J1saBmdco6TKM7WI6jqS5xyquEQ7wiZ6y4G1mFlyBz8R5nWysLA+YVTYfQJh" ..
	"CuusSUySF8ooj1q4fUfCzE5S5rqbWpaXcDV7cwUQbOHxDtrZb5BZVZ5TiM/v/o5iyQCSRF4p3jas0R1H6/McAmF60Yi3dd6ckdu1" ..
	"ssIY+BVoB5fZB2D8vlynroLspFDjWh5GOnuSUpl/arsN2c5QG3qN4FoFmxRHlg+uoAFM6Qq5sf1/t1jevd3G3m1k64r4lbTuo8YG" ..
	"ZgOe2IRXJ+Vaw3mU0POkCXnrNRKBFOqpHjXYjeqCmIouoFNtxrfXW1aB3hDAhqIuXJqd8nF/z/qJ2rwqOwbI/h3HVO6EC2mGRAxf" ..
	"wEZz2OiSbkv4mSiZWOfnxfhR8kapWIflXvo8TeBJj8ARvBBjSo0/vQU9y0hBIGeGr5k/9dyMF+wqJ+9JWoRoD5pvRTY3r/IecVJT" ..
	"rUUnBGM3Fo6n3VheH3milFEJXk9ztdroCfFjT3dJHFSHa0EsYmUZa5LVv0svY6jpP7tr2mNxB8MjbcFzq55C4ImvR4iJuOgmQfE6" ..
	"9x5sfiHaFI23HHwwnh1o3H4nc3/+giBvRS/X1gBhHNJnXuj48pluHI7xS52e8lq4oWskXsMuTeJXI2/pB6vqLpSRNIDhbIKSKV1i" ..
	"8W7fbdeRl9N0lVy/q12Bs0bXSQ22SKcuUVNLdqVM20PSSqqnYOh43xJjYViChiS9585jK9/4K91lVekBkerJwIqcdE75Owp+2HOq" ..
	"UhZ9wNWJKbNPTMj/xrx6oXSv8diw8q2/t86kzgGhfL0TZNulDJmgNZz1hIOyUAk2BApDMOqBrM1z5Sd7J/fxezY+nf2ZIjGB9hNJ" ..
	"oCLyu31bB9TLLVaNd36EouQZz3Tutz/LiXpZ1X6ZFvoqGts7XcgH8YMFvCLKhjLjfViSImLczA6ysnvw6SHdqbYPReC6BUxw2COt" ..
	"y/70frMeV0dpONu+522DvSvTOcnE6Xz53pi6eh0pi9eNC+kkrE1PeseHfxA4plvvlpzi4JaSXF1MuiPGxRchQn0vof5LvoV9qNvp" ..
	"PfmfcG+kpIGC9r2cO89NgF7wTjAintIMzL0zXe7gndjrH277RqaQ/kJtvj2PWNDMDmplh4seIxAJLvdP4UeU6wmxTsYD2q6MwiTE" ..
	"1ba8Rg64qeiJ5H7oRCjGGv7y53/ojj/ldRpWj8aUFW4VMRpk7rPJtakcEYdDcq+k4IlmVwFkDBniDjn8wcvVuCCxZS5OEXqnJyGs" ..
	"HNKE04FBRSe0Z/e2HtAz6Eo3CioK3SOiw5IJi58a3ehyQTOfsW/+TXG9A03SOgLoW3NhHQ37HOCOIAlWbZMcRtPgAker+a0bJrGL" ..
	"hWiBJe51vYKB8EXrxDIrDAIx1pBpk6LR51bOS+L701isc5Uehp9oagZ5skUg+L5aXf/ATDMmlgauQEJtZ+JUm2aa72n3dcFvFlg7" ..
	"mAfvii2mhRKMqk4+rlAWoc5FdRqEuXDnd89OKdfbjA8d+Ko/nO11V1uAXzzFBRPFJ7HwEzWJQPXe4atAxN2EdvsWvkyqoiJwYYCQ" ..
	"Et57xjbnJTxsX+v1IgHz3A1aoRPscrHQD6H1VWc7k3OvJ9bObJBCRfv3O4QKczt7xXzHeRMBBq0NF1v4JLA5r/fLhtImOC/uHcP0" ..
	"/NeJUBL64G4saU1MkxL3wD6WUCqdJ6GZS/fKf/bCK/l8/KHxHloEXQeAd/nMwNS6IS5QHjBskduH5BhibQLj5Ly9TG/5W8BfUok6" ..
	"3psC3iFKp6MgN16/KKv9oOiYboEMAJbdO5sXRxLG4MdMElMTizAt6TcGNSKO8VlcQ3UYJDn4VNguulatn2noGLxrSOHGW8ZwIGte" ..
	"CaTvKIIbuZA7Uw5GVkiVqpIYWprdv2T9GA5ybGhzujkQil62THCt6Qmf2kqtipLfHKA+RYeG4sJz8EPog2pnML+srV8QiifJs8II" ..
	"yZ2Hh464ufi1Jp6Uk1csP1r4xzsmBQL8xDpUREeoG2kgLc0IqUUjXmxGq+KsuJx2NG6mdX03jM+LUCrc780pjASLTOHMiy/9dVxe" ..
	"NFsL6NA90wKlDW9F/7Tr4antoc7dCFOpSdC8XjUMSVXV9WNuRm+FW3UEkOvyOMDlqf9TRoYUMyj9+0psEtRjfGnBYWTBy37NZ5uD" ..
	"YA7EXbCwktaag24xhL/QgxuQBlNsYw3Qu+qzPskP6Oz2oLxoO+IXZuVxKfgCH9UpeV6SS4edvHPT2SapRX6isBIHaNZnDwmpSvME" ..
	"vWgdwstWFyoHYALzm6sHxjavrpWhmiWzciCJROnyHoB1MOrQE5d5HN0qG91G3oOrBMiK17nymuYJAs3XPNy4+pMEp/M0LijbK/3M" ..
	"TUpeBr296p/Lzqr61BN2qp2yC445fdUSBg2PXc8UKlO5YHZNeqkX1d4RINeRGhpSskugymN4P6yXA8xBZx/frZt9hT9vHlQ8g4n3" ..
	"m3nOfyEPv+2VKmmFQ2N+P5v6jvospyosEtjEv2lLEF8Iu4LcCBedMOPxORK2CeRKnOrUNj1YcDtKk3hFR+8hj4hYvsZZONgj855Y" ..
	"sl/KERnb241TpRJeFfJ+98Aqe+ozQVP5KPu0hVlbQj2Mp5Rj8QmmIj7ua6ZD6R/mXzDox0JGCc3KFuRQJmFKYRekq/E9mC8r68Fr" ..
	"OI0bKtBMfVEaJICa5hyEBlDe0gQnxUiTLWlWkwxspZweVl6d/9tOQRYtXw1k71VLwhLcXVCt7VUABDQ8oPPLiVdliQOlQNWnthKT" ..
	"EMpPX7VRR1RXhu6Fl/A7wVAREIivDl5JZSeANs5qxXhZ8JDncQ5DqFfiI4FoLKjeJIL08FgzXAiFLignaXIYDhnZSZOBaH1HK101" ..
	"FXIs8YmSwNatomq3DSi/zqksZkoLb5TNru9xzPN+YDNcTvOAiPJtj+Av4f6W2jZF9L5FnIMCe7okx1K61oSo8KQZ5hKyGemtbtk8" ..
	"ViCfLiRXhGiHqZO5U1SCRDPiN31PMZmpgnUME5Pdw46+srVgpEvirBEZtMROlH16hX7W4IWyY6Ndfh/Pi0ByP1DTs41QQ3mo6xOT" ..
	"rF1sk0WQNB5MmkyTzUFv23D8KnQwV+YdKHBneT99mmum9zTqQZC6UfvOZRGb2cC0wPgR6GDISjBIfaDiv5P9eJOjeHsjhKPA4cJV" ..
	"EniPINYxmpYjsCaFHzMKw5VnYxY/jkedU64m6tTDFBt0WbAR62k1TpBUGOfNmE/Af9bj1Vfn5zhCWFJtmhHoJaW8mwYyITrgYpSe" ..
	"es32uHSvko8dILhLiH7XScii9JSGSzTimtVt96gvEf19oQUv6v69kKX6SMX86T/2ifMCnV1oYu1nkjdXgnwVtn64667R07lTsGJC" ..
	"nfMDuVU2n16caE3mORdQ5xs5sosu5toWbZ9J1ZTIY0XhtHQd6SdRfZfwaMh+Vrg6S/2dRyPEIb0i0GQN1u/1VfFHT+/mAewDZw9u" ..
	"d1C80a97rabL0T28LqJdTlCkxi02RQp+UbtqOJRa1Oggn1/Iz3/XFlxSqJk5vod3mXuApoFksyQk/Vx2abOJj9/zyhKOC4lrNYXw" ..
	"jQwamAkZwKRGwKB3RBFvap2LRWDBd8nHhlHRXs1TKFGfqbe9P+7aRJqESuaOn+q5fCdhdwlaXGLsIWcz4HmpVPVaywAAIXbAncfB" ..
	""
local PAYLOAD_P7 =
	"dqDtcOYWQtk+G+HiiNUJSOmY3SnV8i2zl9m2NaR4aG9e/ejzbwndKPSS/nHxKTDY6FbYE+A1STgv8kYUn19ATtlbMa32OIez8AhP" ..
	"SJMraxxBTh47pOs/ebQTCj79moxhQNj+tsV8tVmsEGpp0zpMUM1ZnUdvL9Q+qLX7QbpUrr8ba3uO3wWlNOHdU/XLR9MF4rXG2f0W" ..
	"8MxXDovX9HGNTanBayPcxjqSY73H0cCTYg9SBaBijzN8ozPmYfrf8Ul1a+/Dxgf324zOVrXIu97xZrujhCNeR2MajplP8b7+baJw" ..
	"ndj1wdmKqYm2a1M5OaBJCNzfzGCa09joT3mSgHK3q4obqRG6X4kGvedHuTIfKhDcyUtjddCfZJgRAFjpAw1XkP7OtGDcusJH9It6" ..
	"mdD9URZB8qa3pHcFtso/ax21dUCGYtRWnxA+EXbWC1ULu2hKJOvQ2hTRD6RWGcWktbFSWfpQdaoNpVpdYO6aK3GX7Yt1/FH+WF4y" ..
	"4tFtHZ47z4J/C7aPeHvPrRbeQ4691sMnCkKh7mnnzfJROlFNTUZwI7mhpDQyf09Cb0Muci/guKOPD0v4Xmur48Qv+W+NMprrlwME" ..
	"SNbWAG8PmPVkexOywk41mGbutQlqYqGJsI7qYM+I2lhz0OV0nxuadqpg4rxWiYy5MwK0p4u1Mz22kh9vtilMBIXBXU9VKQeyRV7w" ..
	"kmKgh81J3IDFMINX8So716SO+xnwouqGExfjtxaRJv54LFgbSG8kRPXklGJzTkmi/XmW8ZZ1aRKMbI2B0jbxwx12OjhuT47DN340" ..
	"9oHcqeCg7JQZAVlexfowK1XiK29+iHNE+xUw6Ok02bo938fUdkrvOoUG2EI52eR77rmD0VLHJIwCAnkN7QB5UCdU8sN2hI17k4VY" ..
	"WiJbrNIUYBE=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7

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
