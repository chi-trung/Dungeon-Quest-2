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
	{ seed = 3416845025, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3419441911, exp = 0, plan = 0, hwid = {} }
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
	"iWnbiKp9DomTy+YtIbsE5pTn2m42yMal1U2/GPs5ZorDEq1DU2JVQyk2CVRO6yrPGWZth4iSvRl47gsfIv2jPvnkouH1ODhhp40l" ..
	"+feyCNW8FHsNOHW6URx3IMDKHmnnyTTSSKFA0PJhBFxAXahvPsnBuoKIS9JMtHDU/H8VvtUJfFG2SAnNJ5hnXLKDDB6u3xtePhZp" ..
	"2SHkD4DCfQNHiHW4aVtfRwXAZSILRDzCD4IGFxgbGBNbAKNUIVpA6rHGlaSvGKo8k1yyPH3vXYn8Cc6c8qN4qJCCNq4HXNdG/T4t" ..
	"KUZMyv4FdK0zntTUGk9BhZ2+jCVe/sLgzCx/mF5AWkVxE0L0NDhZXQw/rl4NjprE6ksVIRikleaJnd5qXqEEkrfnxyXdeHLwWAUg" ..
	"V3V7Q3M80MTPF473e2WY2Obfr3lYc2J3iambKgTK1eVKzcY1M9oXRkO2xSIUmsb54JUck03oRzE+cbjTaJCcTOScEVZYjqkpk7b5" ..
	"fi2nDmAhOLzqdluihHi+SQUvz0usOmuhdtPG11J6yspm+kK4BWwsgUHc706wMulrrBxvng1hyA5mBKHW8+fZSm5yV7lWgdvR5FoV" ..
	"lg+xFEgPN0RpZZRY9UHuzF38tYizHdoaP7xCC2oMWoqdx5cKbjQPMk3UScxs/pudp+QixUfRNqtJ1o67TwM+YdU8zoMt0a+v6AGQ" ..
	"NZ7Hr4KaIQe1xnUlRJiFIO1fQGCRz3VfazF8zA39HYoJOngoPdVhCJk+K894c2iJwqj7JG3xdt3QvL/ojR4z4aFCJ8UtN5lxh/nV" ..
	"VHqS5VVKuf92wMW2tKXb686tpLfsYyu0pgySPNL/2uFULUvh16bJhzXLtfTXtoBSNO0h322ZWapsGIFxz2n2Xyx9G3Og+M+v/F35" ..
	"TEhp9F5Zl/w+pF8g5uzsffZpYP0SJUS2929Apce7CUfAvQNCkqs+r7suPs6udgKHJleVj1BOBobnWsHBb/U4Fn6tfgPwSD9I3cBV" ..
	"yni3koIV7P4RXE9z9cMxss3HQeq91vpAld3MntbUrpa6na2rkDnuC7m80um0f0FM7RHKXm/uO2tNr52OocvkB+e9st/Xoik1F73w" ..
	"6JuWsa0LFcEANzHFPVGreGrv0SIOeQ04XgQ2Z7MA+REdSJXEqC9EV+XvXh5O1VrMU8GACtdHEaZLw0TPdDVU0PyCCl9D3vkI4iGj" ..
	"t5KnQ5yspVzigdH9EIMI4E3pHxbHkQBNDaPYYWlzWzz3HOPCoLqG7g8qcPMNgxaRt/SND59pQvrILZCQZbR/9Hw8jNN4RDBtlTKP" ..
	"E3YHhm/DYNwOrNA1587c1Q2yBu1DUehz79NC2Y5DDn+megg0ElPWlG7jNqRxUc79qi0Cgrp9tf7dQtTFXDV5xvVnWCfypxaSqgwg" ..
	"yLTJyXbcc3tPj4CrFjxsNKiE9HR7Z9eyJ5toyl4gVGvVcnbiLaL0WEt+3qSQRXH+sXKTGrlVVbUxqk+c3GUC0aabd6SQID92mrK+" ..
	"0Zo50OsNsKS0ir3rEb498FoqKmdpCD7fHeDgdDLSrGLh/mlJQQEtISoF9Hei1cWBjha0oQ+f0p0d0dXvh47y8qrVmVLSQZPbqcXf" ..
	"XAGDRbp877rZPQChz1le8NXt4QQTvSQvlJaD/12LQ1ApOCccDdoP3ZopvcrFQVBNX7Ix/s3Du35RxTmozXUv7elvt0qgy2gVyiGf" ..
	"NjzdB1pUluHKQs5PHjATggkiiSTbvCCs4Baxb7htlSbhAeWHyEChtgKPIrKHATwGeNP4o7qZ/06NGFTrAiKkT1ARk/cRmHrTqok4" ..
	"F5OB3aKdXR//j6HBSj0Ns6dM2OyIX4nQWhQrZ/BxJGbCYTcJXH3Dw2ScZnY/dQpSCqkGIm3nf33mnG6wT31ek+wHPVClMOeygLcm" ..
	"UFDnYn78gSquEKegQfyOVZTwg2p9Y48Ttt1F7LnoxPdeLgAIGFkrpxA8rtuRVXWshHY8+nQfLQ8YEa25iNQRu1fh++lVkxjzdMK5" ..
	"lgtuI60YuuBVwcXCz+Lw7rzzGxT9Wi+I5rN3NCThCDfq261VNgWv+4yFskBEZrUoX/q6G9/+D/lANzdvXdH8pBsGN3hl8nZij4Jj" ..
	"051bi+nGVDElrVXG/z2KU9+yfTBFG3dhnPDTS9ON3XxpZ9S812MF+xw6c49Q8oFHeaAmkskuR3ajXq3pC81JpTGD3WICWTSlgCmG" ..
	"TrVHSGjTQmu0UQpnCoB+1/3ZqRAb1OJ6Qv3vSS717qk1NeB+4AFGfWLY0wIvld1jrOMKpVPb2aQtTRQnPglcAtnjifeTGH1JGUD1" ..
	"AaVYTUZVaDMIDzLrCtbqlAsUR2p1ts93DLJRVgnhavanW+VyDBKVIQklnsl698KmanoGnY+rKoIasPQ6f6iBv8W+BOcKs6AbpoUN" ..
	"NfwCZaNR4bwCSGFdVdJfijSFkobnZuFfWHbJ9JrbP8oiyzp4k2+4Zm4fk1A0jOkzPd2sgwlEv/YTNaYuptCFIOWJahqZhaAfpyD+" ..
	"RBCaPOPvmBrDoYll8+667i7uzLeiu96FmgrefoCKkqqDlkq/rjMWIAyklQ60EouMO4IScPkNd0YBOOSciG+hTld3EvYp8peFnEk1" ..
	"ylWAP7+t4O6fxlbZY/k3InvOuzNZdd3aDZ4NYAWQ2IqN4UqyGu/3Vg2iTOdNSjuPwuxLPN8QuZqA44le0oMYr2vzHasRQcxFrsJb" ..
	"NFEnrNJgE3S71gOqjjdKUj+srlOkKJaAzJ6zQG5xiCZ0/HqZK84Ob3hizFaO/2pbJZP8l3XP8X0ZGWFVCWQHkgZOGBsHzE/WJI2q" ..
	"SQJ5tpP5/auOvjkNpuRt9/1lvQVq9OP8J6OwRtt1VucUB7fmjduwYGV0MLwIzfBdwhB6B5ux+EBUcTAGsnvGMf71/3QO/X7+ICxC" ..
	"JnTmT2I8rEYWdolN5GxIGa6QJxxYUTaJDtXJS+gzPxzFgrqIfbN5sCo5apb6gHIJ8AuDXwq/r7ew+uG//YukIjtLtdyqxsF7r+CM" ..
	"78SV/VsnmW1NedLRsUXIqxOh33WFdoeIwKMW5ZuD+9J6uxV6yoiN+VInquqayGmpDgZV2n1T5NUkdfwtmRnce+5LM6s4NuD1ENFo" ..
	"mWwUCRORtk5Dm4L9gIEF2kAcimrgN+LKPgpzHEettUVipRMN8qjJZbk9wR/KYTTO3jbI16en7rPM3IlqfWm1ayiducXjQ4du8Bp4" ..
	"Vy+Wwio4cEGIc3yco+m1u1v323V+oqX0Avvo9AtC143iPoKjGmS4PUxwdLE50F8naiPhnyvj+Qx7p8pO1zQYONcNtgJeqj1iQK/p" ..
	"xlsNwZ9cOqOBbqUl6MPnbmzdS858ZGXtrF5KDgFjhSb9nHDLmYaeDVinP8z2ttLcuUxChWzAvbDMDneWXNNy3PRrngo2BaGjFftJ" ..
	"4LOuRy7aMsl4rq5tRGHyvccD3Ejvq4y7q5fiQ65+u2ea3zJuUgXEWVJVHBBUwFEKpke/B7/oT+uuTPOanYNbQ6jzHsH3IYqyvqu8" ..
	"o62di/MaJyPgvkAw8fmOjgcaVUbjAZ/efS2c8f/lgO8aPB2TkbdtxJ58Hm6UCeADM7GvW3iOPacITHqcUagGMEG9L4xVD7lPFjW+" ..
	"EKEEfVzZMom1PiAo+6lYSoBm5zwHAfojmJHf97sbH8od2zrXC7eoCD/h+X+EK+n//IjZomqmFviqSVzqmYUUZrxxAl7baYHqunhE" ..
	"X1u3ohavLkoBABx5iSDGXAMTrZB61e7o+fiH/LJOStOPA2/pkwiMt3CnUdBXPlMobtL6tr/eoKhy5pvys8q6jm4f/E7U0MW4MzuS" ..
	"+/2Sd+OtZQM9yLpqyJ533Ld3W9q/QRMjyHUQ75ffRF2HGQ8I+RDAndAd3Tts9RuIIJNNI4EX4taRVWCskyb2b7PWybIzEFJuLm2l" ..
	"xngMlPun45DE3EwNb90e/mQ/gQ1T+b5ItBoeRsoMgONH9bhSUcdlG79Kcdqe7CBPGZYplJ2haEkveyKycKH+5UVxmyCjE3CdGpzo" ..
	"fQ1zIMgKbeB/vrT22D1aQ8ru/8zTlcTifFW2t7DWJnVXGU0ZwkZLrr/gNEVxfAGYx05K6W5xdBwvH13Mnc7B0JcotNM5n3AvVACq" ..
	"wrqkbT4AlX8NQ3qJdpsimwDukwFPKQkg/Cbdxp+pGiDn/evszYeytZPlZDZbEwwGi1BjL6XjB1ugq8zme17fJ/zn285AwLLqF/at" ..
	"qGGz06eAFgUhdm34I8yDPBEZIZ95yG0+a4koQVT+XawHM3FUkotGpqSTWGn/yaOBSee5W7LsTPYI2CE0iSLDMKKZsvEr6T+pfTf4" ..
	"fTNsb9xqHwgDpYoGNXEilfOGetRQZhrXvyHip92B0jBDKD0aviPZ/AfASpY2MLu+1s+f+uUR1PIMoLwVHTYuVWiLyGl5Q3/gOryY" ..
	"2q0Di7/sIL6lt86lwmaiOYEaGWC+hWgs49u8jGTU0Rz9RI4r0p3O1DAM66aZGo71A0DBW9mLkrXTzEMlC/15AeihVMYxHWnXt+0d" ..
	"lxHx9MR342xqXtiSQ0YVLNqyBFN/Eb2zlsnFi0EaRhzMwXbnECI1LRVHpPQyPjdphJy0MCKYmzxGuQQaZOjHyiQF05vs1EZsQOU+" ..
	"L/BkRUjjBiIBu8yAPL9UiGy1MEtT9BbfwEbbmGmgMrQnBHC0p4wj9+PAn62cxwM1XJUvNehwOW2y9IBOodeaYo6EDgDTOs1RVipq" ..
	"ymz+kUpe8ISsZ4eRfkBR5WjjU2CsmJy6OkTH0J2F2MF2ekopXavwNi6ifmoRgINtGzbnpTPc+qN0pWM2PGA3eDkWSeSdbS0hYd94" ..
	"/0iEr/Nvyo/zempP5rFWfM+4O3SaSslBbUGISEveycJSQnO9wrgG38aoCTKfTktnihInMVEZ2Lp+UNEMI1nmQrSLH+K5RqpZdEwc" ..
	"7r4berMNb5/06E6J+/ETLnUzW2OgPhr4wltOc0lhfvKNpmuxeF1gpwCNVg15I2A9kH7TYiH0+MdmWNqvoueHuhJJaU44t1TpCAwl" ..
	"5KfgYvTVHGONJEU/k6vFoNZn0tGqPCh5q7HB6/j78EMGB4gLPIDJrusgeBchbM3HgCI9PiSfQDNCuRYlJeU1fDJZY8kP3FtUFwqw" ..
	"MEQT7S48VwQyrpR134bpdh/7mQ2Dt/H/vdtC0T6rHlxoqpApAlWfRZN9lTAc4D6gITzqwPuCiZuTqdaCaWV3oh0rukvRqZjmcikB" ..
	"JqMuIdZJo/T/WrG2HgXQrRZYzJb4P32cq1y3L4/a2PlRj5pKdMNzOSYVxa8LHwpT9p4Jmuc827+HTW6xkzkdcJkoRP6OxxDpvG1H" ..
	"0CbI9x6jMN8NrMfv2WCJMM8pvMqVx2bwPurV5PyK2SSF46vNY22i7u8OVgf80siMegq0EhOe3HIUoDQ2zYtvIzEmEY7Xg4xYdiKh" ..
	"m1WCbv5miJS/NAidHHZdWncygmLIT4ZA3kFY5pU8OSZmOL4ECjEoPU6B+pONN2nnEMT11Dt2SlGOS8rNpMWcsbTwnPcKoH6F7GQU" ..
	"Dg2XHbTQxl7cCp/aXNFzsulc1axs0COhibU3Mlbsg3nu//QC5sU1+j+cb78aB6iMr9zPloKbjjUSwo56aTOuwejfFfq8P/qSimU6" ..
	"w7pUh2AjT4G7dyQuDI//qOpHw6756zODLDlsq03GmjhOYUXCW71/x6FRp9mDGLfpIajTfETw8OaqfDWZUQp736gmeFssZU6KcLhC" ..
	"NlN3fVoyZPWVYBEV/al5BTcauPn2Hc45AhzkBUpTdavSkVhsJD+PPYJ/RHR/HSUv+R86LElAiYh3Xfw9myH6pCLpdSsX1NkCpUsu" ..
	"aGv2LgFt4c7oBY/oTBnlrSAloP+Zldy5MVCcLrpAX6XRX2f8dPs1h3OHfDf2vPRufmzuLEhadp9+zLEnKjoWikAQqp4IhDpJKEgK" ..
	"lQbLoSyGDtLRCNKBrmRi1oQ86SjOJueF2lbPLg5OzslVrLytqf8EtWAb1J1V7T/ioLCv0xDw6RS/eI9oURD+yrPnujkQFlOuhs5B" ..
	""
local PAYLOAD_P2 =
	"B8MjVd5Tvf+ruKqtb2v9dtA7lNhYF2SD7aFU+s/d2UIvlZV0QahrLV3PuVq54pu9oKuLTuntdmszTS9fRaseB1QfP7Qqegi+dVlT" ..
	"fNYCpjIvn1FXhjjwD7dWl1TlC4ltOoEzNncopYb9QMWWqgS1OiobrHxamozVJ7qfPonKTQUJEHsil4ZREM2T3m8FzQlkPWQmCoAs" ..
	"7E3PyiyP94Ir/1HmdYYV7N/nQdSUwwKrZkH+ww6AO0v+A+SuQcAdaMdJ1/sn6Yb755UUVtyZ3Oje/Zq4zzjtHFGrlT3woVbEG7mq" ..
	"FwNrs5qXUubyUPGJpQBTG8wdls2A7BBrpRL3sfG62NC9+5G7Rjzp+g55xXRIJx3yvPli6PJdSCOe1201Eb9sa8EUyo0WxVSr5Ri2" ..
	"R7hunTD/0v1iuVhFMAqvugZtwr7pi6PBw+f/PWYjFQd7SvAlkeJpWY1C5YXanUrLxqc5JIJkaBnT9RseS5BdMNIVKRv6oM4+fPzK" ..
	"Wdtb09k+lINLzBMy9sAcokWhvvvUZRuN06cWk94v9kHHX01Zjvp/J/9C89BaWlKRpUnmOoIkUMPvo0QtUrXfWjNnZY8v8g19oblT" ..
	"ypHRedE1M7XzejoBaPIUgERCbVLgIcLgRHwynLcjz6MwoDY7JbNXElOeDeizRrUlFlk9UMjgNQIQ3Ci2FIdiAVKS2k4k5IHuK/yG" ..
	"It3LrQU/2PlO3ShEfLGaS/QJOI1dPrvQLMqwWcp7nYECztp/2xodY4v3Fas/VoSYwKTQFND1zYnavfWIacNtTGHSTgzs685ug4fR" ..
	"4oIgxUiwHObKHweV5I14BgqPr81WxHlVZq3oTyF1otShspipktk9zw2bOMcgwqutUw7TlH43CWVEtHpkfdWQaCScp+qCzjqltOMB" ..
	"SkvYhLXdIQwJ2zXBZollUdlz8ggyQD/jwVKARi+pn3JfGyjo2c6pCq7Wf1tDNafn8mQHcc0b5uirZ1OZEzNrXWNdx5Srml9z2GdP" ..
	"Q3fKggWUaX3EAgyacs3UiEZQv54oN7EAEJVq7fhPUsbr818C0H4tLElFFoWuM5oUyHafFWW1aGzw4AyVKfqi0Hb5cGKEwcZg8Tu6" ..
	"5DrFEwUKpQvlultjdDwD75vceahKE7QLqu8rowO4IKBzRmSSugZbB9mRhGxpCxUmjSh3UhlITlmsO9U9qIm/6UWRqgBQLe7FTxo2" ..
	"oQMXjBLwAS13k7lZO50Ou7zk0oQM7Yb1iOt5TFuF/h5sV4eZ9eta185aQQmKt++27pS9PURg0DLqU+MhFozo6U8AXtnJKqV0O92i" ..
	"dzZaHwXEGOV1sl3crxD0ybVvPNAiqTGpyLB0rtRP65vzVWqgYv35XMSiiof7qT/o/PpXe7eygcVo5iabYZ28Holranu6zMxL3jVy" ..
	"xxyrBV+FXKtJP6Jk0O/8iY/SNtPrS5qIUNYFgnlAj4cunNn7QrUFjtxD/tYn1EflhycNxEN69OqX2iFzVXvhC0f7E6AonZOp9lJv" ..
	"cwWb2E6EyY/cmlyPRkyGeiFk1RDh9qeUGhV6hn6GWF6za+A+oYWvELuFUCOZq4p6WtN+OS95tz9Xq8Bpcb/VA9xnKgg86TY34vuf" ..
	"vR2RqUjTibYusn1d+DBl18cnertYmTw/j/E+sse8m1obS2A5PmwMOXPg1D0A2MHG+Fa1XZkbYq2LxR3UPJM/0YOJSQ/ne0XXBOOC" ..
	"QYFRtHifd7UQc6XFCTJdeDOV9rV6qKDQ6M11C7YdkZFxuD/CCeceKd2/1imCD4yRur7XI0Jt5F47W2msg40V6qwGHHH2ybFo2AZ+" ..
	"whOau2HKFyOGTH7eUpXH/bMW2RupaqmLQ0oFoNKnGZXniYbTME0L468J0nNnVWR2e+9NqFKAN+DC5KDtR47uGmSiT+te50w52BTy" ..
	"1ChdEF28w6Wouk42boMiIVrif6XEMBtq6nOFQIH6N/4ChCIMit9MspaE/B8QnIc9Q8rouICjFaZrQMMTFidSifKdf2v7JwxGxwz+" ..
	"+2nPGDS3LVcsrAeji2rjmbhyKoXEI8YggxkU7hETZQZBllytjaPKE8EJOgHKETfuTDaJDPmEOkcdNE7lHeYIYpOdxJfpNHtJnkoF" ..
	"86tJSVhvSCdVrM6D+sYq7BchEyNO4FCa0ew/JXpl89RkCuLmGAABNU643i8CeHx17ygJNpf3tv9WQXTduAAsi8S6CWk+106qdmqp" ..
	"JspLLMzNLJcTjXtevTU0g0/NPMOXZM2HLZpWzFjcMIDTeN9kyDx+Nx7vgi1yi6OF4gjCbXMDg0mD4WTbQPWcmlDihapTosSbZcdJ" ..
	"HuwYzNKN4Hgb4BagtKgXndAmQy4TOE5NI/nyVjguQf/j6Ub45AztT2W5t5DCKQvpTXzaVTS66D4ioJoZuhg6DxwbvRcSBWGVF5ek" ..
	"CQLFW+37O1ZabUKOXS7nfN0AM3Z2JcmEAxZLnUnNyjLfL6p1spl8l8ZiVxU0rv2ddJfIhL/PmP2GvqbmHL1xDnnHIdGXuD5cxZyI" ..
	"wzrAYu9BHKRcoK2zs1iVgKOI7U2r0Idq4Fj1npR6ak9+GaVOKS2tQ3ul2vj5SiBGwF4Qhf/ZyZxNMiTdgRTQ8Y9xbz3slD3hAfzW" ..
	"EnijswxjsfOQPMtXx4DpFRgIuNvgjvd3XuJ1Fv6ERJkvvXJZpKmGfyawC60oBnN+VQvR4qQ2u/BU5XSes0Tisb7F66JR2rMjoFgH" ..
	"zQCVFc5/rdQgHoQHSM4Rc1PsWIxPUAz31XviUX7ZwMI64CLvXyUpNmjzJ4uT5qipScHeOSK4m9Givg5ug1UcpRzkoa++anpoQkhX" ..
	"6uAxzvGnQt3FKbDAiEZ6mjwUp0WU/si+A09lzkquwmzrW3Cnd6RuBbUyEILfdIZ0EmuWUIbxMaHKHlGJ3hmUw6q85IBXLilrwyXr" ..
	"JleCmdLtiQcxeUUhRbs7Mo1blbkzdURn8e813ST/9T/3v8y7GAMusu/V4y830MudF4qAYl6eFuWB0dDBIn9E8d0o86vAgeXthcns" ..
	"3C7CfuUaU/brLKcHdsZWXHYFugJazGfggqEaQ1EGvQGHTV49cPl2yb5BUaMQhzYkpJzXGPcudoSSql0ouGtV0FMfH8XwBk0/jySL" ..
	"Z2OC/e3jik0s6Rm9/q4I/HPavP2mXalCNwkFhj8d/OaC1DK5n6WotJyJW2LNE4RwiNum3Kxdwg960mGGe+U/ulroYqWNELmSx3Zx" ..
	"tWPIJx3F6J2POgklA8FGRZE57LHfIpirJ6jDjLcYwuzEFc4GU8I8OsFzhoZTlW672GEsJMofzgkxh0vkHfA5PoLjVjNLjynb16fA" ..
	"ylGIGmmeQ8CFEsOMiSkDukfPFMZpj1yJlsFra23e2SNav6XsTzw4vUgQWMGtuDMXnalwtJOza+x7lRP5aov0rEjW70zHw8jaGRf3" ..
	"7beRR21MlyclF9BbwicBjwJZMM55217wJLFrv2cNzmaE37kT/Q7V3KviHeN8Y/Pspd+aysQk5tcNkK5PcPxA6AA6jKmnx75UoUum" ..
	"zLasM8hKqtzVFffqOftv7bnLe6XAYmbIxTl/9olN8exr/mVLII4NCchTVDUt34AlzV1QzrzNNppVKqbrwG1fGimldKgsH6MPLG9R" ..
	"phDIX5a2ARx/DyQs2hUUnsuQ/vFpZ4fJLVrYy+rXwbL44zuLuFBUfn1n4rrQCEpHOLmIV9Fr4dbFuGussN7157SBQwD9XCU/6SNm" ..
	"kxbnGJdWgFe5ym7ZdZSq3y4aoT439G0fP1bqnFGkT9iosJMi/lUX9UrVYoIkcyGdgnvjJoiXx205E5A3aZf7HQMVd88rFizI9QSL" ..
	"9tly3b1oLaMTfBH70foY4x4At4/94/JDTKcg7gRH9+ErQbEaqcgKBdkFy7wru73jnHlwaWwzlGhrZ9O7QWDCYDEar58T1+fB2NCT" ..
	"t5W9cO/y157D6TrdiErryC0j7e10d65bz1DRfoN+rTjoXoNUa3TA+5CqG+LXXUOJxj+5I1bPInuI1ZJ5ugJKplKEjK9geNTBG17J" ..
	"0SVavjEIpg4FipzY+zv7Mcot2Sows3fqLd43Uc6o5Go6SFxYiAHfJMJzDrS+KDMqI6mnp8Cafk81KaklDKf7reSN/zr+KP/ZWjY8" ..
	"q9/5Ho6Exa3v80vNFAaf3DQ4b3mjlV2Ox2asB6xSUL6qnrlpjAp5tiVChhmbEO+BiJ23gmFUNNCOLvLKpmk7dR2T3d1kuhYafbc0" ..
	"5sXVB6GROhftrIIkv09UhquQwd+K/DrdGicRwn+WNe88ak77EVVixq6rxuxqm9kHZ6UT6PvEzNZj42Y61XJo2xxOtYp1ekT+eS/A" ..
	"Cj9GsLc7ST2iTiLIemBV7+yIkMD5u63RLKcK8KtkbdACutnUx2EoLdHmbyLvwZUDKRbCotQUWCh5w2WHHhLY+Z4rAJ9ci5a+dWaP" ..
	"+EIe4z0boMhnmk98JM8kMLi7zg37EE2edG48BLhHgkMxczw9ttqR3R4i8h/rD57Vq1iZDPtGHRDmcrdDEREcSH/nmlYp5h5Pe1rc" ..
	"RVA7OQMg4FanY6hjFIFI/EJngHCDtiI/+Rlb/t62kuaZi6Yjw0MElzqGu2M8MPtvMGHFCn8lsS1s23kpvVq2JU241T0HEAAqgL4F" ..
	"DJBW4W+j+TnninliUXv1evpZ0PQckWJR9vjGBrtrjrAQmB6kEDUtnYk0b9vuuqrdO3qH4xlm58xMrLIdQzqxo1i6ySbOeXTJa36Q" ..
	"hTp1FlY/pgfLwjSSk2+84dRLOCEhcixfYbIM2kP8o38nXbxibb+vrcO3JY8O6RGzJFu/HLnnJoi2qkVY3ajL3L6ilcXKI4gU4IoD" ..
	"KkZ3INEGJd2RsEMpqYEZ3w2KpsfK+tmzLoTiIuKvug2Pr/hMZTSX10xO1lcgOr2Dwki2x2WMQ/bsq0H6BkBoEc0p+Qanv/5hLOx9" ..
	"cQheTlLqSaZCKtDuxdFzNyKJrK/fu338WWsddOkl12vHXoq3ovZk/wjUh9Ozoz6zBiadeUJNZeb/5OjANNeD0cfVxJuIioK+lVF1" ..
	"3WtnTU/C8gJd5z6DtiRxjRSrX+ssDqdHz484XqleINVwo1mbCy2YXntm4fKryCN8iU8YyG760n/DCyWr1cBTX9l4p90yGvSrD1Lw" ..
	"XO+L+VtmF0W/0FltqxBHi4uy72MRymN6VADcDNRRg7+a4Ihlbd55aAc0FQ0/HqNfRorUxwb2jE0s6+B/DMzkUdmrh3xMGsDmt8L+" ..
	"M/arVpuhDgApLBaOmiK/xMuhmxfcPwPgPZJO+SU3geDs+W2CID5q0IPatc6ojd+9fr4yXafuUP5gr4h0AVNBWdgMNbLZUfqXfWRK" ..
	"NxAIyPOlsJpl+/1s2E2Gi1tqmVfGW3KYWpDhz4ZXxDJAh2Y6g3tgklty1tYwGdghMfjW3KHJqKCd0ZmjnyAznBw0s4bm+OIfLQeH" ..
	"pNwRlfKUz9eTdHS2fvidLaL72ujBeQog00zePQ1nL4K7QEdAivMZtkoxh0qhKmlGwNuM0v9oN/AaXs5OGfOLzH5mvqKJt2wRt/PI" ..
	"r7LHNcNuxHfS9+oaEgPYp4N3C7aUu1I8fLlT08DPaxfPrWfsjR8nVkqM37Wx7fRFyscO2zzbIy1ppi/txL50hssWVUeBcnyUpJ05" ..
	"OUDsGPMgJChFF6Za/rCamK6JI561Xo+CPWwk+MI82cNcOZTtAVLjyYEnTnjv47AKNtGN9kNUwmfNi6IfpkrkShXPjEO22fef+ZA3" ..
	"xxPzBfDrb085pAsYkhf6LZTZ8JZqqVgG1ldarsEVsKkzTSgpoKUDKcXQG89ctvSVBLjaPEzIbB+J6sUqOf7jW+roI6j0+W9Ul1rW" ..
	"KZtMVvcQUr8JmAJ2znnSNOi8Xj6XTMzTmoVSOebr54UWo6OSoifGaoMCkPv6wAY1pqfgyIqnH6KgcE174f0plSC86zgsDApLbbcR" ..
	"fQzmxf4NpBOzUBXhCwSKjhvTQguszy4jk+51P891NQ67QiqsCulnIO/HpF1MO6GSty9dCuyLlv/zeDG6REMZ5z8BafidDwaG77P1" ..
	""
local PAYLOAD_P3 =
	"dt7ZstmUUqXN2yDvnC7A48OnOnZ7PWJyOO5wpCsmlx1SOPbnYIWwho5oJ0RBwYLXtmQtnOp19tyWtXOhYN9rmvdRq8hLO7692a3M" ..
	"mzL5GXpmdydMNeS2FPtLUEkBVlK2PlXn0r6vt/U9LoFiHA6qrCMFUvfVSRzkDuq4VqRSTbjT5San6qAyEdMOglBiuDCeXbHd94Fp" ..
	"C/zhgS+PIXJyVlopiiI6LCJY4sD6lDlcuNRbuI43cF9B2wA414w++dQs8eHses1vOX2odBEUtfkOqCAD/XUlTiKBdHZ/YJd3Sp+f" ..
	"uImBEaSjXaB4WqPjapLG9/c2RK/+8NtzEuDWSgpZgMYixaHl9F2Q1QqxX3z9iXOD+Cyt8sPz6bqfdWK/GRp7oqyMhgjrbDfo6nd0" ..
	"Cdlaf+VOmXRy0BjCeX8wJUY6TD1hVQrVAiZ7M/gqi2vzGmDMQwp6B3zIO4vYQBUledXyHouWiRUHM0l4O7Vf+IQcn7FApkbm76+Q" ..
	"T3mkUdxrJyutvsGvorVKEEX5znxk/nSfje/xBCTEtyye3SQ0pKVOqVpQ9jRwFM73d0p3wcRiiiLbQN+k0W4jZjJxKbamrGQ3oNEl" ..
	"RbRoWhQLFtz2K4IpBNEj4B0g40wQFoyuB4o5Ztj50YV5TqXhW/C87FtVG8RyYmWX5mKRYEFGGdlu9agXGej7TPoIING4p8lMOQZF" ..
	"RudjG0YJ4BA8imsnDutERnBV9nP3DMl9tkmhO6BLJtdbdSnBcEInzYqgplWsenUhlOBi7Hu77Qa++eYIJR6fuBwkd9wEnN6u2X2F" ..
	"wYk0A1PTYMlTUqrpWJGD0/NvQ5aojB/REhpZpkX6i/00XRrL7A2voDOM27/+ghcL6vi4LQKBSs9XXLqo6lYWmt21qstL+BDws0CA" ..
	"fyTBrf85TKAPF1lohyOhsEqkQBV8HNSGztTBfa8c64zbt0865CAZQY9in5hiWXNLeBNRwxVn/Iayx2OC4NG3wF4x3eq3Y0qwiUbT" ..
	"DGTALBLi+puCtrnRHor42KcY0y0B5xVt67NRJtXl4YJxF8ADCYKk/sPEKm6JsK0zeGif8vAAIzOeIYA097RwR3NNC9MbVM+mpklj" ..
	"MD+Fv839+vyAkx2L6jlwfgV7BasA+bP8ZfGDS13SC59KVv19ZMFgw0hncI/veVbJyesdw5F+8/adAHHBEGFMEXlNF0lP30bMJTQm" ..
	"mhPtGAz5mAzbwE1/lC+BZtuw44wCsnUY6hYYaxBTgM9ZERpYDBouotkPqOD0qBfqplz50lz0qUTi3PemhadcNCFXEuZCHrhX5rZq" ..
	"33vA8sUUnaiCFijAufi9duVoBdcb9RRXk/CxcoWM3KHOL1dMWEljJyu1AwviGMSpS7ZBlLyljTE1AhdtAvzO2H1IT72OGRF0R433" ..
	"ZhtymS7mPVVviMB5BbfDFdHa7tHGUdwSuBQ53AyWLjA2PFX3st8x0tdl+czDY79NNXq7WqVyoto51vmNR7eydBFE70D4pZ8cINJy" ..
	"/jsRDrKiT4icrXXDGPOXZFohumfbEJPzjpF9zT3THKRpoiE2cJc1sWQu+bDqjt+n28kN9xo5Z7DngRxDasNWYKUi/gK0/m8KRq2v" ..
	"dGn2SXzqq/YEuxgw8M4QvZyemKW9hSfrw9sz6fuNjqacCjIexC9kWW9trWjKbfi1YyfRb34HtCB4Zjim+9Zzk4e/uKKEpmnmmfl1" ..
	"jEpeFTcAKQzxMTdqsVcSH/+kKyEx9WOQEAOLR8JO1zvAObr+sW6S2qtmYoTPPNO0+0+SNrF+pxXcIeJb1BkLRugtj25HmTSssXNv" ..
	"56Rj7J3VAkzalWUqHk7Xbo0qZXk1xjynEuJaFrRquxKJS5fgXV2vIqBwrrxcNBjqxoT6oVwOQVsboBA9FesXyehutdY6QqemrWNE" ..
	"HvGbgECfkmnVQOrNRPSbTolTl6ry7EXLmmN/pkfVYBGHcVx3zsEs77+IIXWjZ8qewBCA20Ib+/5DWqVvkiXJKHE8mLenGaC47Rsy" ..
	"rTapZfORypOkCb+jRIVKkcDfdEukqCaRjRlX0zdAAUUrdue6XKaMNjZ8FBlTrNKqynG4mOR91y27LW1yh2ewfJAdvLRfmM6hU5GY" ..
	"53iiYNqBzJQE4wcksnQrcyLmKueShIeDrQ4EYaW74WV116VNlxPhz75aCZ3GzZ6w/ymVisNyO9ym4HofKKDr+jbVsZa/FDmUrDyl" ..
	"MQlaCVJQ4EuCbE7nC9tpXqip1c14HrPUJfSjWqo/n+RwYZ93UVYfJNLBeJc/hwxyS8mK02XIZENtEJdLxtXBAoXMQ3IEqHhgzlUe" ..
	"u5RUO7GBEj2cOaoZJC+4J3W1+JVDSKuFHuYsVGhfI2WD3Yx1oDhLKwdVq7WN7vt1q4Ahr6B8MK2c8vOf54g1fbqT/7CxS6b3HHsZ" ..
	"b1HN6+ouODEsx+nJG5D/f2ak/Qe4chAPmXv7Wqb4FdW+1UNP3Nq9f/p96ERPuMOKccKAdTMnRjnixyFn92DU/GUkOOZdX1sv28tI" ..
	"05pqB30D9uya4XPFMYzLnXLZgrUaqBc/GNmPsLre0n+zRqEzw/RenA5lUh2Dqv/Y5kJj/Jb+FA1/GwHPleZQKARa+ct4ePhqJCqj" ..
	"iX+JBYGXiJ1nzpq1dwU4CPQ0EYCvTab2L57v7bHwZIz2cLYSJWk2jbFmGz/EsbTqjbeLNRKa6pWSEr4yvJGa3UA34KdvoApQdCIs" ..
	"M64xnf+VqQ6zvY8DWLRyvxOI1TCffeIZMtYcSN2JqhR8MAM0H3R1TRsRtyzVO9H74NDuXiFhj+a5DtGKMbA/PHfpGRKay3ma+6bb" ..
	"+hbuBq+nxvbZlbGr09UYt3HqRT8LacBgtVrb50qaeXG7+g6eHiNbY8N4yUflQe1CbL0jUOo2iM74wDTkTGhu+HqvohJRDNtSCjtN" ..
	"3SS3u/vRtPBAnVxZ04Evr5Xlbt5FB7CB0dgb5AM6/o9L+MtkVUJ/C3xS7eHR367iy8ZDDdKKawbjntRQHIOdvtzClP+d2LHlH1Br" ..
	"8EYjmQ4g3U4nmWQUs1kszMNTs6k1KzgMyF02pbKhLcRemontwuHsXvI8qrR/R22JFD+PNvlL4k9Z0bbT3bd+7yrqNZHAzHWkCqhU" ..
	"h71QEplLTTc0hMYavMHXzYg2Sghu4cSSgX4K+/r0z2Z59VzC5y/P3STfjRQx7QZwBpMpvvv5cKI2pvF4ZXcYYjkW9DW7vyTaTtrs" ..
	"V0+/u+93Ro0hO86oSghKkz1UwoZPkxT/I1AK6MsSbKhJDt0kLvhZab+8svN15TiYgWjV4RzU/zZTGLEDX3zclr/lh2Nz+q+1lLuW" ..
	"1/NjfiKBNi/d5sNEbHHOAL6SXvBOL+imFH7MViY+SIGg209HIC0pjR+MWQZMp+gqbq6y9vp4XM0/Fs8UxrCi1ZffcLwXj+QdPZLr" ..
	"b9jKvJy5I0vlzqTqGu+jRTqruVCca1W0jLX28u/RnG6Ufj+ttE5EMaeYmJw+rPZiYU4rC3TlXOQXRVMRzUMqR7xrCCvxTK0LJSEj" ..
	"ghLYB5poG4IdcjHmKBw3u0ffnzP6UGcB2DOoNULZKdtZ/3qKimkVhYVZ2jhRHw9Z06OvPHaRjbpXOnyLhrth8MVnBP39Ok317wu8" ..
	"MoAHFIucAK40tlg/qHkqx1xP1PZPFEk7rCDlhp85BBtHl/loVzzRhoqYSGHE9Jg/D4oor1PKdgzrDHdVzDeCtHIhqs93l0aEGR39" ..
	"LEp8iMCi5EuaIdDVOkqSngtO9SNbrJ1JYv81HQ8Nz4Lo+x4hK9IulWnVKthppyLDEbDJI/hpJyYrqONbqxgWSxDciXL+iUHEGqMz" ..
	"CtUebnm+1KS+BYGhkyNv6/PAHO7B1YDUyXK0lNkh+VBr3LegOS+JT8DLn1gmmCq9MXylErtbqsrjU31PgA5VDLxggOAeSucDOFSn" ..
	"7zuGA/Kg8J/mPcEHqdU3nC0P4AKv9Xm2DcP2ZIBTcAkHMZXAnIEgA7zmlwFMk/rst1huT/o2CZuUXMmzWB4uXmJJz+WyJU+U1TId" ..
	"KB7K081XzoNVGbTdB4+FNqv561yap8fAePxvrFwcf3VL7HfZemc+u2v6UQFTdd2bx9T1yDD6tiLHz2RqFH5w3Lot5tRRkQUKUUG7" ..
	"RXfvpVv9O8oWgpEBoIIeACMNasLK6KuKEVD3QER/TtpGOi69dSCWu/eMnroxbkBVzv2JfqX/pDa43+eVHAN6bUG4ymwnLowJRcvO" ..
	"4PAvk2u9OMBH+uhPtMUN9/P4WKNLKxwb3slHU2izVAymW9Dfr2184sh1YVmSVg3U0eL1LrpOqRK1+ZQOVfKnutBqTI22pVM9RyYJ" ..
	"X8MyqPp/0ifejNQ2M+RqCTdgdxl45ReBkdSg3jKWk7/S8w/2/0nJD4Okx+g2IsYqjm79+p+zp4vt4b0L0Nw9pria5ZTJ2LGsYsGA" ..
	"41qULTCa44OG66X1R1L0WHQxh6tjMeZbjVUKKw8pFA0o4/U26FFa+9rXzslONbRldHbJal3Q5Cd8CzGqDbbSyh0DqBnz9Dp4qIKY" ..
	"U3nzZMA9Rggi4M33r2emeXnybAXHIIcP0YmWlsedBVR66cNlzJYFZEQoXNvhpBS2K6X6Po9u5BWxxLHWKYAh0UgJIGZT7UOzeg9P" ..
	"2hejiRxW8amP0UKepIUjlTsBJD2YiB97I0oWndgHWXJTCwh9cz7NoSh18rH/1D4DbazK/2cqK7R8QrPwM+ywnFSifJ/PtBHoplQM" ..
	"WkBWGnYH6/dnGQOJd/2Lmap4DOfDe327pNjQByFnmoyWisyFlTqxM3vIHZP4rx53AixxBgqyYnZhCYuIrmxcfQ4C1WOSFcOww0I8" ..
	"+XxmAZMRJFgHgB/9wcMAcsMV2NEQxXV7dG/ODT6qXHPHPCdA2emCWyMLrGZiuxYypLX2BkgUvPzCXtpkuOOLgwB3IqWxuntOIt3j" ..
	"YuqD5cvur/uQo97Vdjv1h3sdPb3PWSMBWh6HcmSKxAF8LvuSg1JgXkCsO7ul8OtgChoh2mx/rGLd45/gc+zRlaQCEeAygfcPHn3Y" ..
	"yaiMlNx5RWY59arvgbePTQR04HeAKKrSqtlrcIeSbZPMuq8EALvX5mUzYuZ7pYuNXjCf/jtscwILkKEtw0zBNlCvw6VGPnucM4At" ..
	"uisX4M/A7hlnwnZWIPzSM5rtb7hKgP7nizOSz3SAFE2VSCiZopZV4bRwySiwm5kjq7GNwTPyBN2TXMPsWPEOZWRGN6BRSkjNv3k4" ..
	"zS7Gd3IufI3O2Yz2aS4ahglGQB+oV3x6odrGrN2cGUd1JVbm94MNcXXiXAP8a376PzW7VzZELXDHMI3jrd4YOYIbIvOW+7sGHBQq" ..
	"TCmLXFP3RggP2nOycdm7EDs1HZcCn5qqIO7PXKJQB0p9wVt+XWANORNL0B3JhUNqlVXLDa1/iIE9Yqm1SKI/E0oTBvu5O6PL3PF4" ..
	"76P2B+E1wkIXSYM77g2OG2MF8DqJg6raGvDHVCLibfAtDcwHlA3sby5ccPwzom5tlwKUfozDGDzGl9m2O9Qa8n1EyioLvNuLY8RJ" ..
	"TXh4bR/0qyaIVJA8EhMSYJkCX2HAinLXmxsP+F1qeQaxZ4EcTAtkH5aYX1mUrBc0EP/aEURFFoZLbc0Bo8RQcTW5Mu3mBYLWK3Z4" ..
	"NsT6vXDDVzv4rEaBVcF/jSl1WUGLbWAE2+gs8C/nG1mc0XAj2pTIATDaedF4TGEJFkzntttBDlatU456Y0noPhcYrQNMGB43queQ" ..
	"N761DYIrfwDMwA3IdQuUZMlKA/IeMoGiD9VluywRL/XiNoagoGrvFi+ru3WdehQ4i6SC5zpSqWI1uxF1egcztj/nxSEWuMHo72jw" ..
	"g3XCgDu5uq0x1g+hlnerVqdbNI/qrOZP+RmFyk2pci2vLKqDGwbo0bfQ4s9+jyAGKsAVxfwFUarlfdNRyLc+lBlGjAGtZ9T7Qyxy" ..
	"sN+IUHW0y0NCSq+UkBAlEgFsNlsCuTW82vXJK6q3soOGwQhRqTPY2cEzlTULuTbB+xtUjpXpU2PABoNp+guNRUQg2ZQeLVrNprcs" ..
	""
local PAYLOAD_P4 =
	"Y4b3cylouv6u4kZr6nqCQoNFC8QC4Apsr64s+mW35EKGlZRJTU46JeLrnQzfauKQhCUsuG1o80wzXDAVuq6bQMAyj8iu+A+0978a" ..
	"MDAvJ8GGtKbD2E3Tp9a3lyNMQFP59JtjG/h0RR9QZdRb+PjliF0D0QkYSG5I53122VFHyR+O9/38rU4/NuVpGqqiCw+LquLaazTV" ..
	"0PrHhKPs2DIuvvIQ1pXaFKgTZLSlyFTQK0+S+TAOTI+UdBzGoVUJfmQ60bLi6Yt1uv0+9BPArG+lhTwmI0MJFqz9LiEBEWAZZ8WN" ..
	"L0GhthADOtT456Te5Y8WSp+ocYzOlOKpjDcnbZNwnr2ayzv20UsBmC5AMMgGBKBwszK1QH09uRqmKAvB9gD8dozJmhYgZTQ0JtTd" ..
	"eaayo9OFCemDQDQzGtroU+3OxeSvAVL7bGlVz2a1NgqySNDcuo3NRkcICSN/oaqC/0enlBceA8s1/+0EZfhqbEgCfMJidqYh86AB" ..
	"26ABR5TIc+IfYASzqQx+/SjUCz+CL1mnT/cx5Q3hQLcZZ2U6j6Uy9/JuDwQdcAj/bvke4fUF8l+KRDCVm9zUMkKPgDwlt0bTZnUP" ..
	"rDzBt1HVhPZnr8/S1wGskch2CHrzx6ArEUc5XSKwUU6XrXUY3cH1GO+8rgv1ne4an2ba9WZwLRJkjFp5mWBd/zeZ/6tfTOw7B/lX" ..
	"wlBwJ8ZeJXQgBvQK6mlRKIZWNKjAK4gBeFwXpTUhhvOR50qWLdTQmFpjRGZU/vVYvuSHopO/a43ZaAfCoXzD6Q2BfPBvPCz+106e" ..
	"0S38rvnobw7/SJ8LTNrjMK6mhT9rCe/suRjcwS8lwFBDMU8I2UIDIJd6goFPdynFSHh3JROg+Dg5g2AYnEyb+lJ7CH/7y/N2PazL" ..
	"e1rTfjdGe+2+sg5fT3qZ4gALYtGhpAjCZdQd+SVQKOaNCecpD6RACs5+WmFSwzkzfYHbjRDTvH/3r94QRQoI4YATFIWlLgJk9PQl" ..
	"y8SBv/PtBco/Fd47qLvtGNyBkFJ0dWa/qtnH6raOIhMGwXp5nXt3AwCb5cFETrAYKCbCfoEa487kW30sSzsLpxvrJyVNMMVL6knv" ..
	"mrCOlYhDEznt3M2rabHHuygxFPRzTtN7JON4yNNHigouxdi8tThLmAnAQwDpRuAh6umkwmAm5W/2hHjckWRErqlMqtAajTbJHdL3" ..
	"mv+0AnzlF9l0gfdyePk4AiThj7xt/xmf2upCJHomBF0QBOR+Gv1CqtUaXzYjkUX54zJ4ODvwvOSpgJeMtgJOeiSSYy5HXasmmE7w" ..
	"vUT/n38R11Gb+dTv4VJL5NJ0Ru04NBVcghT6MJjqSWjIDI9Wx0maKGV0ef4AMQ0oj64XkD0GyAC8C9gqgLhg4mKNO+hm6Iu/9RIa" ..
	"VTzsEMg1OkIEQoFiDbxzEMcmaPedNS2JklPnF2u7YHqoOG7QDQqbHNxDRDywmDDsFv8TzRPZo0kx4dSL+SbHNwwY4+3mDOmxobfP" ..
	"45CmoSIrI7IEkzFqGnK9JZlEfCax+k5cpeIM8Vg9nzigtQnusGqEat118w6Cc4KIazGKuzl0w8hM0h6Xr3IrJVteR9nFkFEQ6+m/" ..
	"PeMWHPGGarpgTDnvTNsi3bf6/cV4xdjccdVwlWh7wtqnc6DUOSq60sLiCkNxJfNs6YwmFg8Dtak5WrpJOqVJx4y+bLdAA/0liQLp" ..
	"tMlc9AGdyH+hjRmuVKJ2qcaNYXnUaADWEAWiUCD6TewPMVugTvPEpLzUxCLeeOGsb9Q/XfABUgexArnqiromSExjnGc95LuqvaTy" ..
	"rQnegGl1wfNAmACbhcbEBsB9D13vOa/6lLd/LCe80PG3Ynbu1+tiGpuhBqL1u6ARMnHDUlCApnwRokmEdieNYIm8FgEMtz6b8lbb" ..
	"CKBr3HTcSH679iP+rIg7Xnww6e8LRtUnrI/bSDzFb0GtdFBHZNtTsLW3FMbGQRDUuICKljq/UarYoLpJ4qGBEKYwzr9+/7zpo6CV" ..
	"b7zABCVONOBm/GgkpzfGnhK16LOJuABtU7yURtZ3klAjruRpOull0thQHxYbjbzS+HANcD45U0Y5bMWzpvLR2Fo/0mrx1c4zeigh" ..
	"/KAIuehLQliHoCiY/X7jhek8AL+U3jxYCs3yCjQX09uYcUONCmx/TRx07pAjALLy9Rt6YYh8va7z8Ahp4PaBUHb/sdr+35KwO3vM" ..
	"X93UUxvyWtdmwFxyYTt57iUiP/SWkFatT1uhIUG7i1nxLeo5qeCPk9cZwLnhCvGKKqPq5XD9UYIKoIfdzQkmdFo1g7ODjApjOV7z" ..
	"7qQcv//dzY0KDIP2hpgDEN6GdHPj9EjGCrEbCT0rX3GYPG9vX6Vhv/a858Sxdr1Q/iLQUPyHEDLM2mXhqJQYUVAUog6yV1uRKGGs" ..
	"5vm/9qpGCJCSGu2VbW9rjbGwVZJUycq/ZbO9oZmIEv/oP8jAhHp/Hp4aSn8x6JiSkicf1xdihnXBy2c9GZzwve+mRPX5rrUdlTff" ..
	"bIAvORUoxGsUw2mTr8DD2lxU623hiz/2h0I1z0dc2nliW/Sd87jRmEPfyoCEJ/2s+Dg3w8mcSP5qDggRgNTJoIiihVXRaX5PRhOZ" ..
	"ge3Thk8p5bKMiwyyVwDesBfZLoeVVGhoppy4OsZ2CmxFqm6FkcZl6m2JUzpKyaHEm9JoqDd1ynC9GEylw8qfU8wgbvHAtbi9VaKa" ..
	"4RCkjvUUSGdTNkcSr1yyyKjnZ/3dvIdN8LxqIwJA9U+wIo7naxYeuGvr5Y8y2MumMyhzHYhFqDuMraH9QjcriZD1Fcym+xLghLmz" ..
	"U80AHA+TR3xHgIhdaWVuKqfLuB2iIVUEgK5If4E5FVQIztCGNxjmIJZtzxYftL99yiLqCc4dhIXhX06bMrelP1E5fXde2JqkNlh7" ..
	"3B5fDJ1Inx2b63cmkpk1fAh8moYcrkz2Eexm3jHj0H1C613u0udRaJZD0d7H/RBiLnt5YFnhjbkgT74VESgRrL8NrPhXpw8bOXRQ" ..
	"aI2qlw2QgcEkMS+SV0L4NXR2NZj4ea84hkATWyU4WEM+7ZoW3OnU+hGGVRGYb3My7l98jF9OzlVKsmSS2PK63a+CJaozKDxrkr5r" ..
	"SOBGGoDi9G+UX+OijVgZHUJgA3exPkzL8gqfYpAix4kOgGw2L38+uSWGwAe5B+Ds3YyrszsRgR+p3Nq8JEcJCwwgJhI1KXXgF2RF" ..
	"gFe93lqvHRzMfw7k6RLUN2kAqjspRHDAQZ9vDa7deXCdhE5k+67VDkF5o5jQwEpVErV9Pr25wkgi30vCJ9cxL9GFtqR2oDux/gU8" ..
	"KEstOhsbh0IeyJVbNwRHmTrV+1FNTyv6JbLoljC023Ce6FxGX6EPz08/l339WhedFsN/RAtU+D/yHXqSbhnoZuPkISf8tGc0ngE/" ..
	"6orcQV2yDiEpHk6y6kcS4SpssKtFlbTXzwDGw36hbpe9FSx4apS5w8uK54ta9WHq3A/kOTwcK7qDAPFSAEtrClFgvhSDj7AU6TkS" ..
	"hauPsbVzdb9cMCEVDYs7pJZCGKuyPGKinn7qYFQ/OUMNBLtKnKHghHVhmy3bpNkhVV7iTU1sE4sRXRCc9yGIePr1coHbi3IgL9In" ..
	"kAE6ZvukhIsjo+DMhVikz2EtUyWGoZfaR2rEGb+Js7nGS8cb9OL2oHfi6WbFY1HvNk/hJWCuERd//LXmyeVH6E7lJVbpot0LgY1B" ..
	"u2VlH/PStFSEYmjeJnYvgwg0eeQVoLsT//btteULbP2LM4SRDseCiHn3BW2319xwQYnfx+xUQP0Yq+fPIDphYV9+3cT1+PmaHYur" ..
	"IVde6oXyAOukT5W4hAiv5aEHIWz+9zpYaC22vONlSR9cBJhZtIB7P9QofF8S62UXfSTjitJMEkuO8Y/ADetvRNvcWvoON/uajM2d" ..
	"6UyI3922Ci1aH6rvkHOsqB0i5hR4c8su5C5SGvmKxSlpWpSaroX26wQ4sRI1KbDORuCqEiclaTnMXsBul55hAop2SWNB1JqgXk8g" ..
	"zWUKXQj8UBceuPHnNBINEwHDa9C5GGkdrWJqzoYBKebp/fASJqwoDQBRh5G568TYDJ+ryuLlrEm1R/s4zPon0vxmKaoTyP0b/2Y2" ..
	"c5R3L1jOCu2Jk0U4j5HrCDB6XcVBDBwdDLhsLp4KLANxTnM3rNG0zK4OwsEPq75o2xc4gNXVa3Z5DrPP5pcsspIvMZVEWNc/NbuO" ..
	"w3qqJJ292NZfwh2VgVWHxy3CwU/0NeA5eW/zSNY3nXZL59Vf2/QQ+bbxScM0x2M1kvbj0MPvhUrjl6oBCk07qxmAqAx643xqN4sM" ..
	"rl8CU4ZLbz/1oVeSrs2Q3YGLilMaOs5trLKlhyFvDDdiNfzsvnJEN0SPKfXi6kfjwEFjJ/TOoRJRA1xM/cqTz16IKh8hkjvHQAp3" ..
	"W8YDJXDvP+eWfsFXErYoCHvuj0dNPHPibcCJgc/SqmhBV4jHhX9/IEXNAT+vrrjtiHpsdLr5knYcoMJPNnpHBJXys2SFmnR9Voxo" ..
	"LrqAtiqbrULUtdcTBWnWNNk4NBilnu9U8OTXoO8Eec25Zjh72c3gbOLFnT//nIldTHksXifDdKJr37CDw/uYvLF0hD0+opJDYuHv" ..
	"oWK8/O3A2FTSY0wwG0mLr9MzkC6NigfhTk0l9Yglh9OiwzmlE2IPDNpKrK+Kcj1PpRWjkuA1lWu4jOvbbtTVKju5AjxkzH0HIEdq" ..
	"DsvR/FEtL4M+JllFsr4JD4HPLFsJOVqOPFkeAAks/PGanEwSIPBs40Q9/3DJrELhqs1E7Dj+XpM88084TGhmFdSL5HNqLYnD9gNV" ..
	"0X/yT4w48APSKnfAurxbz8DxR+IbpuP+OPpdD9SIkKRT1/68o+gsaLP26PwVHZ1NM+Y+Q1jo8peIrd6snP7w4EEmpMrJfGuiFmxl" ..
	"TzcNtMeVgdSEmg/lY9vtYvdKkUGYVJt/biY/ll8bvrrS6bHxG9qkuWVdb5RrCJbPJlVE6gmfigrA1P907oQxRUsJpEOwZnyLRMGM" ..
	"i6w2FSF4vbAd17Gv9GxZeGmQt5v5jg7jOjocAkmTavgtwQC3kDmTQu0XJ8FA13qNNh/U/4avTFqmeK8qmn+XbmYgOpdV9hF62ogE" ..
	"ynwdNDPYF+M4wM0zEOCoGhXoW0EhHi5sG5dRRnwJt3kEYdb3v2YmMxAACni1StU2RxMpeOsnWZ4+yWxvALZvYTYwoRd6Ev18qGI1" ..
	"cbVTmNqgMicnYxgOaj2YclTiqtBNfelh1IAUyEhGl8JcCD5ArSyrb8Ez8FpjtZDiDHhr0Izal2yPYNSKxj8xp2m60evK1EBT1fqj" ..
	"iI7HE+RRDGDQFdKEqPpmIEBaWI3x0gbz80Yg8M6f9yhBxlj1Y2X27Wya/KQP/TZEsbsn1FQe3sCnGsS8CRxPa/asUEdzjJ6yZ35K" ..
	"In0QoJN1YN3nBva9WXZjbwWDHQdO9KyYxXNZmkvdkDpvAyV3C2Y+mmiXkj8pj3cJABWNhL46K1hD1w9vbmiWTwHgVaOj3WvL/7IA" ..
	"uoA351ABxxepAAJUr1dbQYxH3FSEVLns3rzVlHhze1cIrZmw4x0ZG2aYVqXkC+HdxO4+ZeJ2F3OWhb8ob9r/Pu9I7DfKPRVppXm9" ..
	"VImKwoPfvdJrlTrEg7qW86eZjXyAHzmxyQWyQC4PCXOVIRwk08Gl6GdaSKYYZi9AsaT+WfWgVqBEC60wW6q51GD1YrpJ4LVBEuJt" ..
	"ge/iXK0WwNWxi4Bky94OroOoCorFc3F3gibX9Di7807L2zOT1U6lb5jyign5Ds5xwjat4bgIQo+qNdIZrv5PObg0+cE0HUwFGawu" ..
	"/et3C8a4jQjCAHzSeTL8lms73Mqj7nw87MCHY2y/4TtCQMB7LzPuEf5/qHL5knQUq9uAmB3Gd6I3Q0ksjEq6M/fh2LQlIyhxEhOc" ..
	"IxfkZkToqF8jekE44WCPqHFNgTynNYMN6Vzt82vZ4MOqLZmsn1KSFqOYugYYbp8NOqLQakiQjCSli4pGmzm+IQuoNC6KgAqbY4oa" ..
	""
local PAYLOAD_P5 =
	"ldX944BXRBrGmwCNp3v/tJ1i7GhBW4NFom20eJPSHTfY/xpE5yRUHb5W2wgcWCG2jkvC55F8HMDP6GVEAq+26+NNJz33Ub9HVSrP" ..
	"AJKSvw3myzuk8bJJluyolymZTOTw/NMQTGXAK+Zx7nUwmaeik2slpiKfNsqfvx/QTK8ucXAEPPilx7xkVZSDMdf+DzDdxy+OnKVU" ..
	"4WxkO/PRR2xLBdNF4xFDef1UcfH9AJe+lZWuShrx1QmF0p3TnlIUsr7KrHdBUatlDCg87AXoJUMtLmrUg8gOj7adEJMtKzlC/Gk2" ..
	"MAQx1bKY+nxr8nOwl+3w1K2He5wHjYcGfzWIia+yuDWfplc/jARwq63EMqQGQZSYsXv7dMWk5OyFLtrWoQc6tJ01779IgeBi52fj" ..
	"Hxs7ER08dqqG0x1JUdddIC8ZmghWhn4UUR4O279cwEPKxGWRmzstvPL3uuQ1FhlKbcWd8zChxpdGX5TOTw1xAyP/o/XA40jFfayw" ..
	"8f3hds93yZVTCN30X/Rrgxz4cK9gu/TnJOXBqeJ/jxN3x7EYLE7uSPUWXXqXdTv3+/PYtyGRiyQMbzPu2ge9wx/lq6c4bum3v8Eb" ..
	"XL9J01njuAfWR3gefntqoxeYCxBxmSfcd+zihmehp8o5ljMK5nigSpga6Vb+WVJ23R81mTC1XmOV7ehrcUWaJo/oTqB/fX6j8YA2" ..
	"bXNtohXU6LPqqgidvNImbADHnD/F47HtYM1Gvq/FUxsLrOrkXVvAxQRfXnJ/Men7p/AdCknMhI2VBLXRHOopg9dgDjgYk4KM8UKD" ..
	"zFxU8u4N0BBVSnnuFqlrekFnM9O8txEgnquA4ORhiir06zg8fWCclAHCNtpihX7R9uUrCsB2JF5cXBcKZaBdeQvXU46LM530auly" ..
	"RwNHa84ONNgoZezEkReX5wHd1gGfxFyzOhwAfCcrnlsRZKg9xELub+lbGFQwfg3925HfSFSAQqJHcwijFvpECOoJRUAHnN8cGQHZ" ..
	"tbUbtF96oUYvTvIbdBdFC67mJttAWaoscTW5OVGsC0V/jE285shjxRYWfvaDoLsgeorloJ7Lr17xoiSYyqbMziHkRBRnM2FixBFQ" ..
	"FBbE4CvLQ2+M+DFdQKuKORbs7Gba5YgrIfgGF1Vef5E2O51bSoPTMvc+H1L8CVBKi4KkrJq8O0piv2xiBenYBgK1vdkZVMqsSsfC" ..
	"nEwqsnIOVuc70eEu3vIUN1B1JLujUAqDituw78IUj24xKs15BE+a6/L62McPRXvh6BhxoYLpVGKELK6EZViyHGvg9lADhtR62zyz" ..
	"n17ngmzNGbtFJPAWPAHE/m/s3dBEa3NDnTsJ/Fh9leC5G5ZAC3r4/LrQGTGLcHmGsIhrp41yRJg2066PYKyJYZyAmL29+gqA1eQo" ..
	"2IZ3uSw7DZIjs6lPMOtEp1BYJ5HHGbzQ6rlwccPWhGB8chSmC3zUA2hXbqbNXr2AHxaL5c/xBREv8QFNFBoXDAQoYoQZ4ZItroGU" ..
	"G9Exu7wQo9+ggqBwcaesaMjS7bz6z+PdKz3ekMDZr5qeeD5dWJ7DrdcSNFedUOyAHtcarECmizmrmZU1O1h0XS9KdkeW7ivgOn0Q" ..
	"iZ9JEkM9d/lwB4qZ40xo6TRhtDVlMHd74PPCKTR5Nu6Hz/qQWm3Mb0sNP6FNVI50zw5oBj1vZMQ1gd3hUJrXkPJET3Nj0IwvFd5h" ..
	"nAsnkLKHYQbvlTgysQ0yLuGWSE9+8Hn62FkIyaJG0gIZJfrDPIDT38QaitR0CTq+2mtVakR1MxZj00YF+5UYnDZ3HfdHzsorUOgY" ..
	"hwBNHbC6EfcVuoOziIPxItmA9d+laDIXGVrHFPMzaYbvKeDxV5e28CkEVjnYGBhqEu5GFpj1CjDHw9YpkquJ470eHqORxyrxCxjB" ..
	"Rq1TJk2YtjKf1BS4QKVT4QoAkU0Zm8pCZslAZ0hbD5wLH4HchGz0xZtCSDIoSkUhjpeetJF1Aj8y06NC4zLNU+6RDj0gIcjp2mmv" ..
	"mfB4TR+YuwKI6s4nYs5XQ/6WdRQ1k2bsjw0ukk/akfvkm6NA2PwzACv6L4yCMiiiPRRnLz/5EmyShmUAcEX959Ag5cHOhFLzTbvz" ..
	"r8lxr426OINvppBAFv9OhP05VWESxREwjU8vlVt0TvvLJCWTmAmtWr1e9xIEVadDMArNLk+lD7inhLzbCQs3HgVWP7dttx4uGxYP" ..
	"4RIRQ5IgCgTPpWR/zVkVwdUEFgF9c0MenQnvY/ZfUdICnioeVYmUSmaFXCuLfayAvIu590iknaMFjZ88WKAXZ8Mvc/pyrOS5/lZ8" ..
	"8SipsbanoWRr/NPdom5rT1HwXpD07RNqBRcwzHV0UhvuF2cSTwqHHA5a0mddkEQsNcfiS2Yf5/OHRy+RpI6FpCDo9qNKsgDEQ6Lt" ..
	"rX50tk7TOaSmR14YE70xPQPWerwGUnX2tsD/lV7kET6YGH/2ir1SCGTzvkPhhIbk5ZmnJviDpCyBVTfUU8eVCUpJ56K2X6Rru6gO" ..
	"e5PohqclCy1MS9DCPU/OQqNA4+QoJiaeT8k9u/GgDG1QGdSzu8ELg4lkNQEiFyjEPcAJLRuc7W8okNKrBWtyVXaK5RfVk0aJ3pNe" ..
	"UgJvp4iFGqfLf4DdTo90xVQHxMsNjH3pBZUkuoYdNUB6WoM6G5GpVL3O9banxuT4nHlKhLBgEl4OJ7dksjKwwC7ycY2rZeZ1Nc00" ..
	"U5Q5A8kA2jKmjJZ5ysN7l87PiRIR0N2ZBcG2tetjKdENjWy8AxMsPyn+brndVvUEXu1m2YYu4kJt2hCeGLXQsOsuzk/3GA23BkMg" ..
	"Em+Ad9M/tQWGJypIVfGYzGFuxYZ3SKSCY9htUPhJ5pmEerD59r0eXQTW/P5aQ8VUNIadQCz1MWk7HLEQhbpA8CGqDPJlMX+QpNt9" ..
	"Gh/oMnjMc3l8RNSCyRcekFe5hb8/aZD74DGut+k3bH506zcQKYQwpEa/xQGk2cbRyV9sv3MIVN/B6RToxXAd2V5LxWYkJT3Pqk1l" ..
	"8q5Dl69c7e8SqqOWbGRYuDc0JooWVlDJGb2lnAmyYP3m/buY5spZA7R2GxVIR/6HilQLgT8iYbO82y4r3pAEBwQz8YTReSsKTsI/" ..
	"0sP3XXyxMpWfC5wV+N6clNn3H2hFd3UW4y8n3WrZ4yIVsXGsaTV9px86Xar5Qk6wtZQhlBW+DQRk33gsv4M/4688ViKvWjuJoiJ6" ..
	"RzqTuhBHGvds2O4u3XdIjayLx0WkixhQ6a/EAl2qh2Cp+W+EEp7+vSiZipySTiKpv0NIm0Kq5jmGpKVLiu181yVo5jIQ2IY5lVlg" ..
	"N+SIRYxrtp/haIPyyBxe8JhcC0OKVZj5bX7kzL1wraWdm/sSdrWfHwsuA5PtJNmlks3m6Zyyhiz//0ZtSmCcB+8wf5kBI4a8HjiK" ..
	"dpNgJgT8S0p4TQbLa2VZhd17Z2OpZiwe7VkTB86WfxYtes1guwGpgFUsZxb3Vmnv/olowKXbjZpHunoO03OBQWXYCTYRx+B16gKn" ..
	"gimHMnExQ+X5MJwKIgXLl7/kzVfPGOBSMl2d52Vy2Mg/rEVTh2MvnyyFwrt1gAkVEhX8hU9Jk5ilpTgwgXgIVqc0XaqOEIs4Ndmf" ..
	"bDLHBwZfmmWXuaHZ5e6qQX542Q9j79lOZYt2ML7xWrqLS4ftCzxevG5G/099aaDXhyVdC3tNreEZQDx7cLOK8u/7QPL10iasElmG" ..
	"QMSxwKBSFlNqfPg5cX4ZMuDtkg4tXN//mlhoCLccPm0ylrB4ZqhyRjt4YgAvMy6xg2RwfwUx91Zund2E3iorf5tQuZR/RwUR3W5a" ..
	"Wp6EG1TXfMcAItLgxRLLfgZFfgYO8jEpLimnBq4heF5zJrVOYViRDo8ve5DBI9la4dGYYwXrqHeUiNrPGLEUwOpo8XmbBfKjF9YB" ..
	"jlqcikd10JbVK43rRB6RSf6mCtbf7orIQ0vOvQHq8VdyszO10wiWzFyOlNj1mov9JDKy08bIz7c3fdSIsCmQpqnlNLwPjxe1H6W+" ..
	"geHC10t4iLK+FNO4FmLsLnqd7XBrDFK69t86zQGfvXakJdubpcO3VeVgBHPQPHSmBmxwDUwHntp+cM5N/rxgA7FwNQaZMMDbObpX" ..
	"ZB3mJykNiEFU03bYynhpHO7Jgy+Z6eUymiTuY9xOryZW8/h0YcdHLhpMUlAC0Sa0SQpDZxMe641vT66D/KC2PNmsmTKeIg/lRcV3" ..
	"iE9lNOJ/Wai54sRc0JaLqwg6WhSnJl8a48V7GVUOklfTHVw6k5ibHbKYji7TIzLs7cArcn2BmsBVI2k4+HIBSra0BumLL69DGXuU" ..
	"MyubMtWYg6Pq2m9lAXoQkaZSSQhXuygr7IjwVAKZBhbsAWYqlFQNJrkV/mgYRkcBLK3tFRPpOjtq5Qhd3cyMLzK/KdJ2Lgl7f7sZ" ..
	"hBYJOgE1ZLXnVvpNmFuJ78II7drN5oHp+K9cp1tdd3GFCZVK35cPMvaVZ58VZ6xYQZ4LzeJIbkt4cALmQopn7kTVxN6MuhfGxeE6" ..
	"LGUadyTxXRGHAUt+tFid49Wr4n3oYmSxk3XqRDadAtiKRpYDqS00hSQdQUhegdVjOcGh7JsGpfSsjiPuTBFU3FuyOxZz/rQWUm+F" ..
	"cRsAxFei7kjl+sE3bF5muOfIaeiDFwXa45bAkMfeL+wE9itc991WRA1J3v7Z30j7LmrzMB+PS39aJ5/OfeKnVvCbZpGu76YN7jIR" ..
	"0JroTizXBxaBQtB58QsonklGEG7UPi48GfSzgWLSX57Gd8czYE8luuJe2ysKPK1Z31yQDgB7BVEq4TBxc0nnppZk4b+WGue6u1+H" ..
	"LG5jgc+ZaSo219uhZUnUx4HX3/amPKw3eOfA7gA0IDnku2JyWyXnyzm4pDjH6fd0+V8d+4uXBOeD9CLNxGkiQ5+jRjOpltjZ9xjP" ..
	"tCgKxQowLAzWeFoaOcz3TLyoP1vbfXn5gaZslRHF2pEGIeHZN9Zzs4Ss5s3mvzX8k1TlrY5fHxq1RSxbRJK8UDF+nRHCbnC9vETi" ..
	"0ACAZainWaJKw4bXwZiOC/TpF/9xebaSLMmXBSTZWUyHc/yHrdp14/Vqq0SVcxxzfcBhWiLL+c/UVLRvsvZFiVHvz7ksCwBQ1oOG" ..
	"S1gB8fUljpgWIqlu3oZDNrlQY63+RYvF9eGYmoSEioTzXu9aOqVq2Ki9CgCMoO3XkTSBrhfXvcNgYjuU/TViINWX1108quL9WSsk" ..
	"Kl5IJu39mvKXYGNGXe1HZFsStQOiEjYB+Or8kuJENrT7/F/ZkOYG1IjNpAArMm/bdAf4wIS6Cpj922FpBNWIR7qLOGVdYXIfKL1U" ..
	"0LU9HiMSYHrZ6QE5MOZNqWIuPvIFSXwTlQP6NmGPOMAY1XF/2NWYj/SFe7dabtDFMvoytqyPvQNE42BId57T7Sz5w6/bfJOEtNFa" ..
	"yHj0crDkVKMxCJwkrJnOxyGH5XRhiq0F/RPouSTzWv4D0IeSg5xk2QFsixopYn4YqM9WiD1LGYR6ClKWsGXk/jWYxc8KgEd0TQ3P" ..
	"YWSCXVycW1vSkw8KzB5BS5wqWTdHXvyh7X1OyMAVLUvrEqyglCMJ8qWjDh2Oyqyvyp0So8AOWIGNbGJpsxpNz+y98/+ExNrdnIH1" ..
	"u2y+9+Tz9hqtZL2wG0wQaGkGlqpnHWEkuSjKnYuvAZRyjiyFhoFtBJsa68Ifus2EuKGWCsvIps2OWat3yTJWoGImbzUTdwSgj2Pj" ..
	"U3FHpY6PMvzlPFYUvvLxEHLgZ/BWTgR+lW7YG834CbfVeOwCXv7BkQQ6+hfHIlxXgb61AFn57z+B+oCKaogYt5fjKIWIBYMR0OmH" ..
	"ZfGR8Ya3zD+LtjuHAolVQyiU2MLt9Ctschy6u76ZPWOcyaSGA3IiN3VFjzU9BUXdCwhat0oDLOwwVN/moos8lpUvgkeyyXqHjHp/" ..
	"nawGZ/AtiMbkHnvZ551ZZy8UX4V1jN/zQ21ERbgk7dhPkiNuejhylDnmYCztw1WWR1wQBQpDv7wIfCmOllzhSmglaX/BQjG+QDaP" ..
	""
local PAYLOAD_P6 =
	"WvCjM8HMSozuo+34qpQJls3BUf33ifhR768sNJSTATNMwNHFZOEdUwiOjHsMYCacvEEnAmEi8h9M4sTfQUhSDTuvsvq1AgP4ExsQ" ..
	"K6YKjvf+Kf6xCm3B6N/rtaAnP+YhfvHIgX1U2KM0jCiufKni+l9/loj29bO7nGj9PR+TlZ1s9xJETy1zJoaImMC2RTlvlusa5vVY" ..
	"dt55vXwf3w5JoqTXtpL0k55MPmrBzgS9QrTNA3aWye/tNCAaIIBq/BXTbvRANMW/Xo59nBtGA7eTc+XTUY4sG0g3mFBtmF9FxKAt" ..
	"1WtkqSmMw2+LP+IyWg0pG0NH+FU/LM4cNoUPn2EX5hy+tigraWT+T3UhTr23NHamJWnT8VNrIFjm7wtCDvK8CJ1la45PE6MlCNDO" ..
	"r97RoQ3kjMDCLtLjnFhg/XRi6LlSeT7ed7lfkOQXAf+/Jt9JxfYmM/+9XOmtJucT8iW+5Cw4zJa97wMhBanuitk1zzrCJjcjCQyX" ..
	"QkRTdiGVp3MgJOpVaJYY3fhFo0rsmp9g014RDb1FbTSEnUjZQDWvT1kpMpJq44oQAfJiiKyj5YLg+ayokqmI5LeQld3fth8X+58g" ..
	"LwJqWuzMt9cAXsSyRhQnX3oiSHZ6OlR1fB11M53u0fuCYKdVI1CnPguh5z0U/KovrF8il3hmK8CNs12dKSQwu5mcc5p0w9yeNC/z" ..
	"tzB7LBFdYCZ+bsLiVyPo54m8tqx996jTtW2bsL8qtTSMm88x+4xW48xZnSeDLGJv8c0AI6iX7BQgrH5KOrsr3BbQpvraGmOLvrtd" ..
	"cBsWYmQC6CZiiXWLeG/sS3r4QQBBxVG9ciE2c+QCCfa7wraOMfrD1NVk6W9UbAKuwKr3lps41CSBqtFJoB8QTUKEOn8xm8N+vQcl" ..
	"QuyF7D+Tdh41dLKx91s2BpnfIfbqqk4rqO85uU1cILM5XZtisRxG8dgM+utocuYC03w2UUtRfc8/As7+2qmSQpb4/djMBuXxkjUz" ..
	"WTd6LO5Jt8PCoPkV6VmSwDMtB4+eK/mcNXDpmUjyp2A6XLiEgSGEDbezjjXihztKw2VdoGFA+/p2kX37dMkwQd1cIvCaS29izQt/" ..
	"v3akZEbWYdMoRI5+wX4/Ww1OFy+jLWZcMKA2LAcLkngKkkEpt+IWr6KzQVFc/ISq7swvKU7Oh9sqAJdmZTo3pYlIJCq/2EeteI6m" ..
	"hr8cSP/V1x4wunBPglGK/lw/7yD5vF6erKMWLrz0m58n6DcEaucbpkxiNk7o/RnrglvQjdYEVu74alb/KOwAMjBCiek+xyvTCZsm" ..
	"mwtCMhXbek5MiFXdb9znkL9ZOGuPPT/al+6Co8p5UPiH0iNgQ0rAkTHjYNnJau5WTdlN/bcK+nq0AC2/YIZk6o2cvl/waupV8g+r" ..
	"bH22zUXpcyVy466vx6R8FkweQ8I06+lltNf1xX7C2CoSv2NFg40Yqo8zswFj3FDtXN7gJTlckemmekpHsCuYY7S8vYgCGCo11l6+" ..
	"VapTv4/mIIxQy5PtPP+OAlUUAsmwMGUKomHCSo9SbWJTsPEQtuX/zP9zSWd50MMjApB7lMlr7c+41ShHYcfeqr2O8e+qDInm3hgZ" ..
	"geEF5x8GGKQ9qV8UkJcUQDLz5JbNpyP8NSHX7fyDFIraB9hnhnd3Xn+N2IYZtL+Ho/44FoadQ2MCb5pJsnmtKb2aeaC4k2aeDTGZ" ..
	"JsH05O/Cq8OyOEc6WZX2EZ7WhsA51W0bm4KX0PZrYF7TYhmEqC0IzrKJQZ+EwgHbNZuIdYLlL4J7RpcjvDDIqb+mQUCcGUH+xMy8" ..
	"JuGSk0doE4ehz+258aM5Mjo+g464KXITnASnEQoQSgd9zCCc4d0RExYpqohu98FqgNOM5cF8J/acTLmNv+A6jxbGrDgNVqsUYnIw" ..
	"3gNom7T9mh83CaPNIWBsA6Pu++gv4b8P5jPmE7d72QilRyAotu6gb3jqCZd1ljpRX7uG4B7EGMVMZmhmTSAGRDUxrYdQ7l6CSKw9" ..
	"d05WrTIq6T3qlL2WnM/QShsHj5g0Pca2KaaKJAEBCHFdpd+AdPcn2LuqX0XJSiauKJ6Mw8X8LaisSS4xhVF/8wi6TyjEgWy+HU6F" ..
	"Xx4Zr+bv9LdIE05elmU+WoOs7xGc2DhN/Um9yPOzx/OkQM4iyEk+80C7nbS54qXUEnQ9x8+KWk3J0f0gZBzeODQmNFgGnhNeneU8" ..
	"QWcCt5JK4zEoOcOgM6FndxgobFefVmTy38IipXhliMim98MlhQkYI4KAoY2TGezedyyUuTBR4uK1hHMxyttmgXyK261AuGesBxQm" ..
	"yTs5OWftxnrSlfCs5lvxb66m8SENA345vTJEfRsnXbpgdgnONf1ZHeW9Ka84SJw9rI5Frs0EbSVYTkHeuY6NQwPdrK9HMkPqJ0nW" ..
	"6DapTMh1H1+RGbxuwQ+rGRm/7gC8Bu9jQZ3CJNeQAzs/wczYIfo72t/RY+PMTLHgQ9m3p6rJmUe8a2H9wjWaGqtlFv3+4gCoDVJk" ..
	"Ebl/oTg3rd+yRPxEmBDyjXGJ/H4A955MjxFfjpxIAU63scKvDwCnNqkUBtIN0vjtksMmnXfI7yRZDBWr+EREkPq3WO+J3Zhf6Qc/" ..
	"LEUQa6mc5QZTU409omIUhu/9ZTzIn+sQJBAmS8fQ1OTOt7hG+REqEwkDfr5mULfRSL9UrQ06nY2Y07QHS18EGPVrP0LA/4c5eBiY" ..
	"9dgk6LrCxaa/lhQ+GvstZrVAdMPCywtabdp3gNUiICPElCdYaYiGYx0rJ+iHIaVLwSRqLSROFW9RR0nyZUHaSGd8+uCSrKs6Geru" ..
	"htv/E48Et4k0Jqhgpyl6oPApjlI2iliP8QBbPpW96WRsNsNmIhncJcLNK4cnNX82/O+Rqpn0jtRkhifNby+RbkjCtdYzJFpd08kI" ..
	"bfBx/BTHiaVKtGpZxD1sjTfs2vUpTQf+NFi2FNFOBZ5ht35CCIdq5amhDktzGRbECNnvffsp1av6/IkDOUiKOSJrspZlvZZ5UAV8" ..
	"H04JoWU/9O+oWtcdfColqzr2KSS1WM53s/Hw+tHYDfnFcb2qWt2VGtRq2l8/wI6LePk4aIHCHmsC63uykoneE4lPtR52OmucaPTw" ..
	"W0MDqbKWCh9nyoKN2FagK4D4vK4Q1dNqM2FLDpLthn2HcIbGXmX0YWUDAgjbnWwRS+p/GxPlEqeUgJ212g3usZiKcxMCABUnVfNR" ..
	"qi/Doukqxtn7RVY3FLFWnMvVoWNYsFfQqNSbi2sltlTXu0HalroXK5Zs49F0OxHz+GXnYC1gM4FrSU7AnhO3CzIarcVyrXZYO2uH" ..
	"a+1b+9ZEY6ZYBH+smdlS1RuQ+MJtFcNY3Slu5336GA62t1TTB8ooDeIZ4PIjIGZ1E74jaAjav0k66tPg86hI8ndeo92Ur8hQsvSq" ..
	"FjfcMU/e0PYeqKbWG2lCc7X217paV5U0eYLu8Lni8IQsN6ZbwTdQLF8KNmY8AEKDbb6RszQqDygIkyhvviDIW2I4M/p9oxKlNksX" ..
	"eU7SdkvWyxMEk5NVOGHm3bj6LkYaO22hE0G0nvJTXP3FRhrnd6qz99qsSgFEd9F4UlkCwdvakc8Az8IZ5oOLXt3c35luGWj4t3la" ..
	"8OKxrph18bUWP9cP/jEwf0AaKxIAbjZkmbfDVEgD4/wGVRJXSkxxl95zAKeHac0FK7qUtv8gPBNiJ8oH+Ju6pCJB1Itfm/KoFaC7" ..
	"ot97aCCEBRlVsjIVJbEIGgd4WVaeRh1Pz84KVWDYmoTq+BpQhT2MooxPCkC249czD6pmh/9HyofslfxpfryxjHqsR8l1+f0zH8d6" ..
	"izpHyryi5Pad7A7eIBg/achCgVYNQPoJSrkrMMbWpzp4YjtRJXlyw87E/pWo+gQ6NzArehPH3haLxhD9rM8pMh9NFYh71/SP6TEu" ..
	"VBIcMH0sftbt/eVNGfCGymG1Weyu1FSmCPV6bFdkykvLmwUcynvMF6cC3vIPTnXA5kmchztX49VwXAiHdvyBHzp1oXZu5mknb1Pf" ..
	"zUXc9zmOLveH3Llyo/KABmGhMsC8tTnAOp7y0b3RX5ZXj2sPh9GrqLrQSfrOFdW6S8t3b/iDr8CgW2fb04BOQm2O2DqVy3ARxCuT" ..
	"5/TaoAHhaD8rUMgqdJg0G9v69AAZMY6n2rWH5Qqi2fSdI2gHPseVD3nOnnnV5IyqL9iZ+6zVKBEDEMO9dJ8d62z708uedW8x07NJ" ..
	"HN5MU5uuzcRGe5Rj0pc+Mhg6ndcT8/e23LCjDN4skNGDwfH/o6SfNXJA7CBl2FrbA77nlJ5ondBdgAZiA8iSt2jOBRKiALaigcfP" ..
	"2xJytojeP+6LXM9aaTGxNF+J2ehxvRAbISmWFIc8n2910WyRaLo5Xixc8L4ozLpWhpmPOx6jXhX+usyB9CioL7eTAoe2saobOkmk" ..
	"GB8zHdj+F7EjeBXKRYU3LYfDmXFCPYSIQDfS3fv7hoQ039WwHUhS2oHiyiUEHWujr4ckUj2m7fKIc0Z+/mhiKMLDftt3rR8lmuKj" ..
	"ULzqs1puIPMRdReCjnrBAq0ip8GTTvbPe2vKOm+l/9W/V2/5g/Jq9n7vXEz9GSlo8FEMigQ7o0HxAXgogw+ny8i3xRzFLCMfeasp" ..
	"bd9onr8vqvjmVugucwBvnwbdKlz7K7bFZ3upOr3XnrlobfQZCtvTWbYdKRiSA+XdZMHNcA3IyjBigKey9AdjTf70AR0XMTJpxPOH" ..
	"Png06iZ8wAnvKkHed+digEUM0Cgf8QBdoGzjkmbOTFwH4s4DswbRhUUlpJxHYrja9xOQ5LsQCxpTkGirIdUbiUEy4ke9y5lEBVny" ..
	"/y1C+3wHl6kB6TrihpoiXjQit08pxhBdNqNdrllLY0MRp4IPw70lvzo2VnEXYE+suEpvNiigR/WCyAtVH3vqCsIJ2vmeE7YS0HYb" ..
	"56sZx8k72Q5VvJ+fPQIlCmQhxUjFowEwpYXxyCGAQmjo6dR1L/xs4qI9DBw0OR/5HwmnkVzak+uIUPHzO+0f86YDDGyVm9P9Ucdi" ..
	"zj3aWVN/uRFQ2I3l9yZzplRYfT+KHxnuy5FWt6pSL2lKqvY8z/Y1oJ/0I+lw9YBxuPoM4JBZ5qVcWvsZB+Y663sPZoeZL4IuIgjY" ..
	"zAP1HByKoc3ZrlXKCsm/YgPGY8EQ7ERWWFSQNCSWIa+8P7rg2WMb+c8kZ+Nb9Sxj0K7BiGl+pZcPF9Fi3vhHqUFuWau0tvIA8u5r" ..
	"MhLexzlgA5IWTgX6I4K/z6dI9N6ywltMUdmJB73tl4YPvq99XWblk+cn1mgEVe0elG9ZPHdYShz9AczKUtQbcooyjD5CsUkrk0p9" ..
	"yIpZ9pfaZXSELU1QvcUmhhOIoM0X6trlJHEMA9AvYgmxWiMsA6TNVusJuaNiZ+zJE/5D6ZLqRcY/41v9BS8Y8bw1899+NhhGR6Jb" ..
	"LpocFMnY8N/LVqR3t0CuanIaNTo8nIeUV32e0/8OXVHR08B7wpZOSEUec7OBwqlhExKeu6XZAxCVrGbte2cIDW00N2/LqvjwhND3" ..
	"3F9aTSIJCaczRuKUnTlzimpkjhkabl+mgo0IxACirFfOvDcxXW+7rxTS+rtH1AfIs9kJfm1iZTBbuyTpAcATYpZ9dBTAKKeHw8+d" ..
	"nnmfoFvRMj5n/N+rNEN/RHnYcYx4qTUMxV2+VNQ/1SCt4+YPAEPJ41XTmhJHSp7SB/zSWW5bGTIpU0aDUa0SznPv/x7aiEJmIKll" ..
	"eaOHuRNLXw3qYjKOp2cud+zkJxGKzoNY9CQ+LyeHvNnH+CWEdghsKE2LP1fQQ4if9xND0an1QI3xHkSabdWjbVCLZxjsPteAzYOG" ..
	"D41x6Agz4vq9lr/CuA/7HrP9KJ43GjjlEBdR3H5STWbtmUOj2GEtjqetMtFvfMcuY7FUz01S1NEmWmSjoDdRNvVoQfVH2EQbpQbm" ..
	"ZH/6jCiNrBNH+SmJ2lg445nDUKazFElIjg8nSRBWmFpUBnYEXaKsJ8J2EWZFHYeuu+DuSQ/iRc2HTvSJwX7ARA929opP0qJytGqK" ..
	""
local PAYLOAD_P7 =
	"JodTsmaRtXXKUdctVfjKitS6D+Yt0DoGg/UerszXj2I5TbQUMp9X+IpciIUbbkRjuuN0wZ9ZbIncIhWTjTu1LIzCFwEjay77xefc" ..
	"UzgSnQ3488y+BB/r6hAWJ0WcL1ZldslZtKxN8lMqWx8CMUWhyZ7Vn5Ix46s+GMKCmIaeROPr28u/Ldtn8w1vwY9yC1aSaam6/Bnb" ..
	"4eldXOJ/8FaexzkIlFpZByfBlDnnBpELWDdRznz1U9tqNWsJpGN+Johx60DZyJAs9cDINOZJ5wmHLxW4jCI9ai7VnUldaitvBCDu" ..
	"lHYPsaoJem/6egdWTzQE2tdEmGJP7HfdUCtgq0YhBFIaIEw3d5gkzMFGUz2dpN0scAdbnZUrtj/PwTNi2W0bV/M8CUzh0mlwg2Uw" ..
	"bxz5cJsq3TMT2wfY4wTfZv7DLi+lYIDIEJGhj57pe3ONtP4AU7/KG8AL+AUvDgklOprA+rFl7MP5G+fcgwr3LUVirEFQslzKwppe" ..
	"kTM5RaNytrk30/Pc75FJvOVkRu+tTWp1CpPykWtBCmtKPxia0LyDYNhRygq2xhDGxLL5Jkl1H4EiqCv/XLfxfGUEPscughRaXkxm" ..
	"NJzmqmP+cFlWh9eNF4Rvc8cQunTo3wwhGWbH8jgDg7sUOuKUahcFoGOTiO8V4Fw5u0o6DUvBpu48MuuujskS/3SUdtSZGTErYRVK" ..
	"kVpGOoxwyA+a/GfE+VEtA2AYij0PDcMYyRi0+Mc8vCNsILfPPnPz/cm8cXC+iv5HciFO+OPSrBLtYODUYg2wrz3rS4GoYYWp6vzW" ..
	"Md2hvgcu9O8ckyTRiuqA5AgNasf9MDCR8zHCvHGSCfNn07VtRoZ8wsWSk7t5LfjBZuWUKRXE7s9QwWJbinYWZVqclVAzMzHG/teN" ..
	"GuBupDZdttoSOpZpyo25IMLaHB9ClcHM7CdLQnKUe5gRAaejdVrjR8ONoddWWwTmkHLOpVAAPe7Ojf1bvt8v5dO0JfdaLgi+YC0S" ..
	"mk6Doz6D8wCsEDIGT4B0XVJSFucCES1+8aZQjUwmMGWu4K5dR3QXbpN+TVmVDZEPyjRM5xQR+KP76Xia2dwm1PB+aioWv6VSagYu" ..
	"3cMQNkwetwuQOhxFrxMl8BMM4ClJHHt7Hpbs6XyXAZlEK2kCxsHAxFIfjTIpGtkt2/BViPPAhYdYP2nztZqQrnK1k8Unffx7t9Qm" ..
	"fAU72lqAB3069eSj2GRqdaRcunz9mdWxJIMey3YdUA5MV1QVLw0+tAwQI/N+BQGs/vT9LGH9mS9z12OUAYOLhW9Ls1gekn1VkYlS" ..
	"VjiRg7SqK+gpn4nLBvZ35hZKs+cNYWk0dvUqgiXp40FxvJ7NeCehGo0IHQ7tIW4ausmieZXy2jpcaJM7gOP0vpR8nNf85eDmIqm8" ..
	"KDg+gM0F3bAljQx2T/myJvbm9jUsQtq3EN2WcKkU8F2ZPF40dOkG5Zlxa3ZxuklxmqNR8huFwwOuKl1A7QRubzrpX2XydX/ZThZc" ..
	"Yw6kTGMReUCFzP9gXX40keMnLxWunoGKMwP+P5AwSog2Cr3ELBmy+5vPR0jlEh8SgT+Pm00nWaofppyrnI2DjCcEofxGIgMNwSdT" ..
	"VtthGh9HmZqv2h7UEifiTgKgopsqeklQDy81lsu0pyUWGH6JQbNBgki+ZRrYKhA+LQng1efCz+IIsfmec4UnJLlS4IQcMfrpYlf2" ..
	"KCoV0sYY471Y50+ym9EPVtXO10U59FKjvNzrXZCirvnucKgdwePDXWQa49ImeAGSgIZfIPP5E6b8wRpcDwP1wWODh7prJuJHrGRq" ..
	"B0wADt7cCnja4PMXzwpq+9CGSUyuwymyPrUy2tT/0cLHtxdR9HeF47CSAmUxFKz7KShLwmgxOS2VtdMytiKSACBNOUAgtIeWnFu2" ..
	"M3vpTKb2iD+3weG9IyrnN1madL//DxXOWj/LlOvhtM4r7LxBNNbCiirfsEo8nnoP7ayd7lMebVbP/Icz0oHotedPMAxf+wTah7/V" ..
	"CG0eRRKWt/NFWLmZcM+sBZTNc6NV0kr0CDggCDxpK76W/BOWh/XKEt3Ff3No4HaId1Fqd9h4rUcjrGLY7NHtlcU3oTFtGYzmMjIL" ..
	"kZZgCMLpDCSGzBLqsfgvJHytJANbtwmbvixdceq+SHlAUNlLiSBhLKXkzkGq9znUEBIXVWPwpV6AuIAFzfRBRbsrZc2jH0idBDyv" ..
	"sKNZWJBJbroeQoxF18/OMm4AKqGtIZCwCuR5dgxlQUMHTAwi7WIp+erVvlWaI6ne+NGRaX/QU637dGCfe5PGLHK9LUQcdSyzA+xM" ..
	"91aiJxSv69AsPbVzR3GdIDKHFBKqMQ1abKF5cPROWoze4we7nyodEoVH0EnTQpglg7YVqJkVwWvvY9xh/bvf95Nddy64eH/Mhcwp" ..
	"QVBCMOGTjU68OZu/NRPhmGQvO5ThWF94ZrMZShmoYLfiGnjIDwEKgSxQ6xTSgHhHzpDErQ3ZjAsGfQceE0DiGI2dyU84IjKndHhb" ..
	"2BCt7KTj5UR4C/jaM/fuo9u0oRN0yBAZD7VbACtBWzuRkZUVV2dXIrQF8Qw8FQaNC/rEbCb3CdRmHOOzBaPY+aiD/ghXcJi9aJvD" ..
	"YJlcMqdl71sJAN4+/pKtvSMhoeAiQ7I1eolAHPWY0/bfXR7joFpRJ8iB2nAFtz1rJm5wp2IIq4gAs/0Bx3EnGK+aFjb6g5S8M3Bk" ..
	"Gp16bpSgGj4OAYPlthegY/MOFYdDfzU9QbVCswpMOkcgVaatcoe+77iV6i9D0Yd2mTjh/4L7yarX4p5UTIS0MpZaGjvt3Igh7PeQ" ..
	"Pn2XyUJxahI+vKVwEkr4VYUdw8XfCtnCrbMFxn6jET7EJC2109bdo11RoQBJIz6aAX+OJTZX90wM6roG0powNwLdks3GFE6pwopD" ..
	"SDRq6xIJO/qn2Ndf+92KzVyrCR39DV0/3ZfBfkBzM+CuCPlyAJIijrIyQUxxUYwVQy5tyzYxFeEABhPBy/cUjexNF+gNYC/BNVbT" ..
	"VAzw7p9EYxDS609YP9aEjsCvPiGBr+9SivF+UMf6ua9o1qS5arm8tuAU2Na+5AoDmQ1pDkX0UKHgjLXMqBu29jjHeY0GEh2UYkZr" ..
	"YacHu61GRaUH+NjAF7Cf19TynuIMw/Kn15FLf1blEQGH9ZBhLYDBy2ZPM+ajEnqCVVvTgJzfe6wHhTX7ZHnWbIP2deOLCwZa2Mgt" ..
	"/bbIp9WxWSTLA58LeX9+4sfod/efTqCdaglHyVylJB/JiWeXy4BcpUYpt0hzvRVoQzeQjcn7iZg2udLczayvlK485AKg1n0qpfkC" ..
	"Fk61+zj7gabLjw7oU+RNTgHV299Tqf6YCkFHDo0MbRhCnkXuALGBo7J6M5yCxEWTHMIk75vpTnRBlnJ7HDUuDn1EHbNShhIMt9lw" ..
	"K04zPJ7PhiN4zBD83rIsLrEtNJ3SHgg8r46dnku+LMBr+x9wzIWcI0mzy2BX3EZFRuJWAwDNmtRdQpVKPrWJfltoRYAaJxM1k+r9" ..
	"PSmb4V/HcNWzyD0FgRUcE7sVwL/Bw9WP5Ilgwq3KWpfpww/F/77RNZWQHUI38SmSQIGYNOCQtqOMFzIjzwKu5UpwXqrlwiLYv6da" ..
	"qxSA4zhkOj3VOaehgCZ7D3OVk+AAXxovzX4EeI9Upj5K54CoCsBWTt0TqgJ4zjLjxVWRNCFUWL3ADEej5E+QqhrYRjDFoniEB4Le" ..
	"8oERSJJMMLX44BgPPWSPF6HjJ7eckbXYL93mizbQVOGP9lclJapOmYvPIqqhQpoHdhO0eoS1kUaj0+Pcs6uZE0B26b/PHKg+RUtO" ..
	"q77VU+gYpF2CSgJxWBDWK6o9z9nDCn0l1VPvyvM5EHhD94KaP4uhwee2nJpywxJGvZMdDbzns2sqchVADsRvP+KQPXBhIqi2RyzV" ..
	"qVpZYSTxpGjmKC8JzrafS48cxSLLf/uw89KTl7H7PxOwRdxGVH8AWPbrJxc5bO4pCDdoOFLdHZ1eJJTSxQlJG2uHYaMQ+ihYVoNn" ..
	"NGbiirnsZmeKGWerg9o4NZwOFSvQZbks+oxFCPFYusrq+UqgygR/Oh23AuCC4FF5cC3VEuhoNhzS+g7Wu07WBlT/UQ7hDIWYqXjC" ..
	"64LY8SAUZeL8LPl3lvEhscmDz+/0vz7qqm5N7t6uKEDH7kV/wFmU+TLLjMasanXH3ZV0CNbJTFImKf1ODIQyyICvn6XqkmBGunYy" ..
	"sv8z6zy0QZLZ2FKtDPZh9Oqck+4ftDujaf1fo0fry4TEx8YleIjEDSSvxOUyWn6suaopf+gq3zUplwlJgUZXyGxeDnXMmBIaYIWA" ..
	"Vb6GmVlmAQNnuP/rIWlHR32wCrGqT2DAg/M8vhTSsnEaSzAG1wnRkN0FqnLspuaiAk7hM/k4nEKY1QjoBNpcorgZVNqhUOTjG6a6" ..
	"y2JBLSHAMWdwINNRWxVjcvyyvQuM7+RfJRRntf6qoMVcfbK4R4m00+7aox8yHXSC/3p6f9LcEALczVDXI9E+4485+spwJ89mdu7D" ..
	"3PsjL6qWr9/RNR0Y3lgfGEpdrU6u/8AaWSKvEaXa4eX4DjXYRj3KvPbUTqtjjRWcd8CsOG/Oo21Xh1L57796lbSFqynjiN+xjzj5" ..
	"oM9mZ/nbnjKLXeDGI1xtquEJx7N2A3gSX+n0dXxp9UanJ3Wh1/19n5Q94aNwm0/CbMQ9F5llRfazJLNrXjlYom8Pj+ebZ70zGhCR" ..
	"7XWe1t9GcBHX6g8QMDyt2c5pxzSK8CUz9IyZw4/tBUezRP5hcU9lfR3JA28zksC6wI4Sr6GxW+KDYV05kbatOC7kiT2C9JTp6t97" ..
	"qzcOkguVg8R4qbDGrKa5JBYok6tmmYbu99E8o3BgIgx59DAHJIjuQ6XQb1Huy0Gn0mvqY+5vs3rpMgUbvYS+v7Yq3upXlyOIUkFT" ..
	"efrCxSBzIkGhonMcwMhctuLtXxywifM4jzCAL3vfg6ehMcxIWmUvJIcH7aL7VdrZ0PVCAdwSwxGO38XYi/vMdof7ic5QjfCVlb1k" ..
	"yqDNS18KnyxBIP+yIcmVGYQCNakdgycu9MaVGMCseHLc1u8RHX36hcM9oQKXJyV+eWfOQmivQS0wKBqYwmDgEWXZypabElJnzSkP" ..
	"ACLIaRT+3ZT9zl/glp3wt5WZLpbJJD1w4E6uKwsYlXre9P3Vr/UptDTYZ0rxdXh/gaCeYIOdJFF7n+20a+2azAUWxLQ9aiJp8ToT" ..
	"6C51yvMwpo2YM+CBsVMMAYy+wYVbFocycKCNIQUzt7DHYyu+MLlXs6OGMudUrN2cpEu8+ni8meOU+a6zaW6neI7igoQm/8+y8B4N" ..
	"2dY7CnQmxbdh6tC9zpF4/Cm1fqKZV8/j94RRz5bZrn/Je1VU6FWee05E9v66WFXUqoAReoci3UIPrCVZ2ize29oTmLhbrKo+gqQe" ..
	"POixiAqGckAJnyUPc+Lartd4MZDKueaI8iXknQMjFWIl7WhEzDnh1dYdW3s71ybHEn18fZkRHaOVmjzVd0pV6Yc/wvWgS57PanpS" ..
	"May8cBnnvrPdw7X6TLtWS/o0Im3//PSPavV2cvXCupIE/VToSAXO+Dz90/zAcf/0+m12kBrnxJZ1tFWqPQddRgseEldFaqUszn6U" ..
	"A+28RzyjaDJ/d4WQ/i2ok9CxuPG4IwqpAAd/skIEEw9W+8SlazrwSn9EJ7wVRTQVR9n2eC/KoquxX0dgpKIeDBFKOYffR0wH2/3c" ..
	"UY5aJcfYUgCVc20mByro1kZp9PHd6DmOqA6xF4gRs5YOAcyfee0yAJ3nsKym6sxS3BJghaFGxf6/JXIEM7ajBznTXs8pZlxIp9U/" ..
	"AAWaW4ztcIL/sTyUFf1bgPioqjA/1K3rWIXl2oVWN2LONDpIuBxm5imVAx/E28RRQqTAGvrl0k52q3gzWDUCsIjiE/wQXW6rSgoH" ..
	"9Gm9BnOEZc3Xi+cUZCbCJLHbBOkq1ozpAqVhQtmjRQ5UCAH2GjDsUxFtByYfsd2LdSZGVOjIL+F73xuNLKQX9LmKvGMef6Acrw4J" ..
	""
local PAYLOAD_P8 =
	"q2gXRn0n1nnGhW+Ufe6vlTb/GDLEzxDwU1r0wKcV4rgV/xWguY/0s+TeC5ZBGtA8NCS0s1etew49iw76afPKL2G7KQrU7WJygbv+" ..
	"cCkKiILYAu4BIK/U9TVcExze2dfM7LLf3zom2CV0hG+uq7uXDdZLjlevwPKp5jKhHnJMs2CHPeq+UP+vKhwGrqFQxSowOrx0+Ezh" ..
	"TwcwdcMCcEMLWPDDpr5AH9S5DoAkTzCzLezpG8mVabkU7p2YApEn5xtG6qvKMLVH55tBkCD4MlbqYuKMa6y7JS1rNcg3QOsC6NLx" ..
	"kku+lNTtdjiVZRc+SsOfd9Z30ZP9mC5Pt46Ps/HtTq8zxSrLgPYDCbBWLnqqAe5moL37z2+BtX2cqKVl77pFJZMEfaT7gI/9PLMD" ..
	"VCVAuF82olfRsEpDu26hu8tLliu60Is7kmyhUUav+q/HeNwmed6vvcmYrHgOt1nBN3Ee/Nnl56P+Xj1P3/m1DZjJwSSTXV9F3O8I" ..
	"zsBx6cCFGxNWmeUo4QmAyNd5aKdPQLOc33szH8sCXj3/HRc1TGFMY0H3rmoKTXHqRkJoWtpPP2aF5Jay6fetnCjF8uDCUAny3ilE" ..
	"wD4yqjiF7Ruc9G4By9uU5aJ9ZGvYWMUO07lCPBH2Vwl/VCgMViR565FLGN4NHaat4140q0dhdcaes0eUJMtzZZ5Yxxp5fcqyQ5Nd" ..
	"KINPvd74JKWqvzZzLJ/htBEDun/SFxJ74Ws1w+0iKhrqowWpWXArkWcv2McbhxnVOC+UsN5HTMRBJZO86WycAoy9fUz81eyZZaXz" ..
	"aS7w4c11OXWdZr1wLrgqHTEn30Q43lp7+EAnK0hSKWV1sepZKMRmk/UKeB+p7A9tyWOTqWX0z+jTu8wMDIAQdrmFEOuw7gISfb31" ..
	"GLM00SJhvLmlsM8P54Xw3qDt/UoWNSVxLv99JGp+ILpXaZi3Rn8lQlfEcLP7xx7K1hsEHNEP9L9LUHDewfotfoUmUHrTYLbAlUB2" ..
	"sTfxlVSVIcKe+M93TH/6rrWzL1DG2kNFrBMBBhAqJCOzFyUS8z9WGPjc4KEOqZXoT6S3UdXG7bXo1O0uMb31DVEgnGX9Nfw9eRCc" ..
	"/dFGqr/zLWdP9qNuJEZOmj4oxP+zqr2xiNhmFYmHRktt295eGCTT6Y2AtE7KZPV50Jl2NoZCBow2ZnuipptbkfPHP6m1P9qckoa3" ..
	"BOGoiF6EW3FrIFfQJRp74WMw3/5cQ+DpgqiqUgdlqC8Fgo1bsRG8FTnoDgazMRhlD+ZtPUd4I2PSXcYZS/+LKLrPUuRY7t4vfspG" ..
	"t7KZY2RGqiL32iwTSHHvBKtDi+LE9t+PtMogJ1YQl1+OeiAUBlG/KtzBlCeIvPOsIC/Gw6UAOI4SclIPCuPWPPW8mhCIFoiBA3BU" ..
	"RO6qVEAj5EUsIYyT/xk15ybNov7JW4kL3xGYul0C10U14QD0l83xa1h/OnuSpfWhUj2Kc/QgbscxB5jcsslDB8jsR/AdiGGsn2Bq" ..
	"2LLGtYn3nfleLtaXtneNsuEab5OBLIcQsF9XxBm1FlAcx7AZK6aiypn4i1Nc1PmoztFpb0FmSuE7U1YTOWNBk/VKZqnx7thRpKiw" ..
	"/TLtuBqnBNZMpH39H7YRsylMGzgbTO+vLx+xCYJtDu6jmRMc+pS7gEzrcLgcQrgF8MloMtxSeGeQAqzMXvJgQ1w0KWB0ZazFyLtV" ..
	"8ZDfxXSv1H6gxr83efZH8AmYm0vAt4LQORsiKMVKw1dn+J13dw3oL/U3whMUTt7qdy6Ex3WIGk9aSJEzr0MLXDxSMzA34VXQB0TF" ..
	"H/5mOxLtAY8+ksJz+ob+dZVxmQ9q5E0ScynG1wBKoS0VcxJDdYsDfKbOJD4ToPWrEtqfPwKa3ykgf+HeLVPqundW96t7cxYkZp6I" ..
	"2vo4ySMTjY+QY2wf/Ob3CrxEGve9/ckC0DFprt/5GQodM+Fnu/LH0Xogc9qpBxihxmlbuopRRy+nefGFf1BvBiKnEwtIE6WzXGxX" ..
	"xRSMHZMYQuU5GugXQDmdBxrpARw1F4xIRlEjMtUsknuFg9lo2WN772Fqkj+sduy9ohFKi1gBgKOjhATZd0bAkyPPkAvvTBcUmI9l" ..
	"5cetn3lAVUAYkpQ/t+MpG/gTxSi+B9w2B6aOUmrsrD5URnQy+nsT6nD5qLT/jGPIk1CnuYPAZveJfU7kpmzo3B0MJ+hBh5qZ5k8S" ..
	"3UxEuhxoXBJ7URD8H/JBJ/hv336wOsoQRPjazej0OjCgBYX9zEP9G/duWrswiDF0y8p61i4hgAUIR5wMQCsNvVeqBxZXYHGhlW2e" ..
	"edT3JMc75gEC1M79nbNRk+1nlPi4YKQC1W+AYLeo3wI9AXYWtl5TDRs3hHz9/I/VOG+v1OidUt6zG+ZK4L3h+GkoCr6/lfzNgXOZ" ..
	"DLfYNg6se3rGi9hj7EAl0REfZwQ2u9uzi5tsi/XLnLh+UxoP6LhBagYdjX7HR3UWeAeqIJLCYSlARIIBXJzu39AE3QHDKA0AY4TK" ..
	"M5fLwXepCzjlzAYgA9DTQaa2l01Urq3lcKi6nCHR/Tq7o/3btogh3bja3z83palbmC1gy3z1goRLmNxoM2ASEP3H4IlHxxHhEfR7" ..
	"qkVJT/e7d9EiPzOuxAJwWDO/9FijDlPsmMcCZihUZBJrywEjlAK0oZ22SG78l6i3wThLcqLpM5rBRwAMco4yvwxA5nDEU/vVXYZL" ..
	"1HONfS4op1tuN/aU5km7qchMKU3DZdcP8y/wLO5xYPL+n/k6o0B1hmA0h3H4SK5AdcPK3FiXJcbUGTLTwkBa7ypDvCT/coOem/Zo" ..
	"wNeB7Eq7AiDD3d/baP81E/ULwWa3PjxpUWwcE6yea1RRysgZirDck8RBFitXxbd4sRPuhL4Jv6EehaZ2WYd87NBW50J6riBBPv1w" ..
	"h58SJZiu38/+W7UKY/WitaIBc8jwa7/4OrWN0nWvOuehaWtraHpM/vUKRfKnVknIfXtd6yP+tVX1XxmfKRN+sDTmi243I6+kgL57" ..
	"RrwZx41IpbVc8ByycU5KyFMhReNy31K1CSoQ95elwauUm0tVZriTI36oZUTtuTJJTr2Ptx/KHJAsn1itfNdkC4p+aj9QJSVu1Z1E" ..
	"EDlJkvGd7/P9uV9snrfmwKxVV7aQUPkjJOiewYL1NpUmIpqbnp2TNFQW8AGIgOu8EYPGspmBddoNwxagSl6lDzwmPpsaPSxtoOKM" ..
	"CNlmRgrcoL7pfbTr31oRGsyApx2Q+lrjMD6NRcO4Hs6EuOVXRbQ26zygtn4gthKsrpWIxPxMCGTescd1UvPueK570LQUdPptfY6k" ..
	"zI+a7aSSVMsdx9aPjyWYhZTM13j6Q+iaOffu0zRDERZ2sQgCr8AOqGNOuZQlvIl1zpVAQdkA7bf6mFdTVgSqxbO1TV1vLTvEcwHp" ..
	"c60lnBgunDaIp0Bcc5y68h4fDXtM402VDbS2JQAah4tt4Nkp5utNN1+1jRSAhrapWNdWb+uTQVmErfEBGTdZjMRovGpYdmxryD5I" ..
	"FqwjpdWy2jKSa1kdtmdHTlzCy8N6x989sV7E7BsT+quSoPzBD9R1+uy8k9m9RpHE0vcsfv4xT+NLAdgCAJoi4nxeiVFucMq3bLxX" ..
	"OEUXb7eaAUWdzM2TAoL3w/XhP1ghQvtamuRSOfzJfhkyXv4QCmLqG8WxAKjsMiR2P/4MsJKfzxL0oRM9DeyuEno5eM2fZFJ9mViT" ..
	"TgCyokCNx6pcLDQI71C0IYGwFE4/l/RjRw6z1eGKE915ZNXaJVzOuphZzpk0uhR1hDwag+LvoM2pz4ljHcUV+Z7+mTl4J6o9DCM5" ..
	"8boeR977YtxpBBE4SODQiJp5ODGWXSGFNTAWhSeY49+EB82jfW66ZXcCv4HA6WGvNbxxYEH29rBpyC5B+u7OjG3GHvFneDmwfboX" ..
	"/F4i7M7Re/VPKPIYO7yVufDN2aVQ4knE9hzKFwpwjuOd/v0bC2LcfFUTSLKVvnrrm7qmMaSrLLySmFmNaNiUDOMwjaIuq/osnOov" ..
	"voXhSDE54Ny7AK5TtqkEs1eR11AP24WBaD5yD5Bmo2pLy1dKQ2+VteDK/8Ca8rV51Lljn2+Y2/X2zhfX9HrgLkeeFYoIwOSMCxsj" ..
	"5JvXmq29jceGP33+9AJncJQFrsGGctBpXOdPkeBuOEXW4In7tlSjS6/Bs6yqnAGxg/j/Nz327pLAkXqxTSKqsobQKKu0tifdF9zD" ..
	"NACKgkTm/4KlUnTEiO5w7wIIsRsYRc7Xh3mnlBYDStq1QahvrRHxfttoxnQgDi6LX+tdEzrG0eqAahsDX6zJy7NIMa8m34zNlayC" ..
	"uKwf6aDBpzwI4F4/GFiCb2StpGPKsZeArCrsjG9HPV8C1YTzJ+6fgHVDPrbGTj/Zvutf48ufOFvX/PDf1ltM+EHdZX7PzquAhO+F" ..
	"8T5wpqvCO5fNsgyoK6BRhICd/SKiqt9Q4qXC+VJuevpBjt16DCkFFZhGxXknUxlUZGKfAC+8KqxnGBibYHEZWHMBOfxf0B+0DJR7" ..
	"AN+tIEoT6ogfSsCmRkblOgyPQI8IaEDRxsX9vR04UL0Wb6a3dmzAnkkVl3x4ZYQj9ameIuY0yyB2hpQzHa8ONCd2veFaK0UUFFsF" ..
	"n4Q9gtgl6uynQthjaW5lNQUEkUwjN6s3wbeZRciD8H4J9kwvNVLEm/b/ZdUxgD4OZuyTVTIrkzth6ISDXf7bZUMyC0IVCT0+1B8a" ..
	"W791gQDRwObFp9xamqrk5zVaeC+HLMejJYx1RSXfB1SxwjVv+NIeIdsK0giLRXe0iW0+00ZxVRhj9TqMNGpHNLxOiU7WLHmhcjbx" ..
	"e/4oN5KDZzxQs54yLtzQwLqlWeFbCiReYMBPSGhFdq6vm9ZZpzMX3rYv2AqGF+iYZZl/zsFGyB4bHvdIv25UTBPSbkBT1HAdH8eJ" ..
	"aOMJLm3d9T9ael7XPT4Fj7vyrtmHcVjXBTGc1PtFJ4lEKH409Tt/bIEVkB4iTgQEoZPeSbAztd7P8U0LCeY6fZHrRB+g7A59Oxu2" ..
	"2Wf80ttazlAQ2kfxCIC8/RSb/krV2bkYAE5t12+vyXK9o3bx2EykG+46mFnIVGBXkbmSVqxHAAOurxRohv5C7/T1IQ/n/5pO6ECV" ..
	"twgkJrl4V7iXuiKr4dHXClCLnxdvE+42xzI/c142Z3eEomMuoxN5MD36hvA3AstNvcKrOLv4vjnTuWRYtfwar9C3ZY/8dD1hbv/e" ..
	"LAP2M9PmzgZeX547RKVhuqobgKdd3dro9Os0i11InkHlsnScVW7ItnRLhaxV2CuCFXYk+pnmIoICg+P1aEbe52qkjms+BBJ0NsZa" ..
	"C2GZl7jXXx0VHwFCUWmFttafoGBP0KsV0wWOCRcAVKXl2c5+qo1lghT7eeVAhKqfkt+5uwrIjX3HJvOdLKRhUTjE1XG4Afs1Y98c" ..
	"8pv7jWYAQDO9mHmIeIqgRIlP5Rw3701KYV985ybnItPrPS0fleQTFDjf5kF+IjmABR2x2m0aITXtOU9sZossdLN9uY/6ohfSy9J/" ..
	"FamjN5QYoMQopc+jCPqKk9SpOO9L2W0bm9AQY+SINvyu3UcShvWb6cCWHu+ETQv7XADz1QZfDSONeRuREmAR2jTs7ixkTNTNbMN9" ..
	"P9/Shk+8sEDQLynPotpCdbDgh3Ml6OJseJPhqJ7LZHZJxMxJ2YcYdwjHkQa2cWPOnaqIZ/nJ22PHxwUXomqRLbGkdZmZwYPV25ht" ..
	"LMmRfoQdl//Uxp3G/6h4XEGVBw9EDjNfWfqta1iSyl8lqDxWwN9vnXyaaFBnHl63VoZvlsh4HItlraxcMjO/Qz24BTbIAuWZAZy7" ..
	"79/gvqO9u1nPp0B9gsGKwe5Xj1q5SkdO1D7AsT5op14Ma5QaFSJ7zmKDemROiXkUyc7/qeq5M9u4iFiZCtn5MA8C0pnOwQ2HhdOT" ..
	"657M2vaA9CMPToHqYVLya1Cjqbvn0ZcSVyl7ui84gZJL4VPgETKNbwXSKXrTsogAyaAPqv2jscwElYPuf12p6FZpsKkRMQiDsQng" ..
	""
local PAYLOAD_P9 =
	"F01hupp0Gh6PSkZ505exrUdUvvLBWn9CobV9kjUSPYyuQpvbbsNCQTNXhm3jSTmMrbF9ehmztAja+WqnWMwGXB2M40WrW2sjpFwo" ..
	"qP4Dqv9WtlXYqBBfRgEssw3FSb6P3QsR8VDcBkiQaSUp8sZmGEZu+2PpyDoP2UYba5DGPwUA5ucqO/x5PeUKvpXKDbzYqh5ihJSw" ..
	"kxilZZcjDF9IHqVGD5OweEzMM8R8WDi8ejEfSYOw37JHdGsxz6W0BZonA76zoM3uJW6xdyB1M6Lzeli3Yv99Vz82iinn6AX/pWLW" ..
	"WR7VBM2iKkTxy/Wf5E7EyGZL3EYvZ2siTyDTKf0HAPhvmrO3yBK/eSmwgkqlYD6VuAuxqp6c5TuHQoaY+CFl+aKXZQ2qhiigEsfj" ..
	"w03a308D/Fko/mLU77x+CPPEgwbUJyvNGnHZ4emIFnT44PMoe6Fa7fmSuJ87UjYL+6Vf9uSsKJ6VyNCDmqjPKDVV1XsXxbrw9GeH" ..
	"brFPs8Mc5mPym27RpHIlVWrABR0QV3rQxAs+ydEe3oTgjUh339LRkuEr9W8JP76clZRS8DujilkjsBf0vpSzpZk5U/Viq4HyJJPO" ..
	"yXyje1SCeH8ADhFhx4JImflY5RMk8ZSfotAr8Vx8mUSBuOao39zVI2VrfqZ3lf4DyVO2hYCvzlVap1CcgXrB2lVndGimH5oFh4+y" ..
	"sCtgf+rcqxGd0HibkpjybFQHrO2xK1cvnB4WJBI/AliXhX+Tm14mfGOgGslZUY2r/6ZRhdbtsrsAbEN7tk3P0jCbYLT6WQ8j5ffJ" ..
	"X3wn5m3N7KfjEJ2OGAp3RUSivUe9A4Zacy7swBgDU0JB2r2mxdInBvGsVFQBOlcPcQd64ZnSxOgnZG02G/8kUwvC6ii/4+Z3X50A" ..
	"Y8FdnaOS2GwgeQlTPjOwIrA1x8A7oY2mqhqX/pe/ma+NB+d17sMYxcRxEnREN56LoZ/Kyi4avvPwn/WpxlY4aSpCxaGkOB4/h98s" ..
	"fvT3peggAsIxm6GbFRU7AJ+iibyCJKmZvMDSyLkPg7T3aHQXHQ1dRqwA2JVzkaiUqONKU9QaNuGXk6BzUcmXw921oDqMuQ0jb/Wc" ..
	"lnytroSmuPngf/7yKAzXjr0FrZIL0WBmkb1uyhG74UnMZZOcPY1BJMAlHvoywsh1TR1g8rihwZABbEDY6U2SbOULSvL3o0auazYm" ..
	"+XWQf9S2gh37Aj1BPk3ck67qwA/QCT1cHAn7WKJMi5TCf6XIUVsdifa9W9m/1In5iV8NFuePY8NMZ1dig2dQImq5gSHNVPfkVSQa" ..
	"puRMItM1Wkk8VEt3VNQqwE1DYDhZHaxCYzaQjf+C6ao2wNz0ujiJp+RUi60oZBrFrlByuKxCcphfLKV4IloygT2HmPEKibDXq884" ..
	"J6J/GBciu8Hyrtm/M6G1pILNp+veisb6jF+NQwguKyTSJt5vFUWHkHpCPIoKiZ6mgUyrNIy4uDGO3VhqDFG99NmOe5BXGDnWpzLe" ..
	"PBJVT4m5xwQOCXHi8bWtBVpEeeNA6TLSkNtreOrRD+8pCk4Xo7UliplzH6ZSTNkfTzcp50NHuImlO7MbZM7yyU/X5p7XKdxaR5bF" ..
	"hrRKqLfK39b+dlYutQNDlwvnPEUbnX5LEoCUhdWzK0H2XLws0uqea53bTiwLKSxMJsyRjKZuzDJypz/eVEwtK+IXN4Lmmyydmf3i" ..
	"BOtqlfPChKodD5TKdAUZ9lljksoAwv2j84gDHKBxATX4M7x23PJbE3Hl5F+jxCUCjIzuaMsbaESh/BUL2UNiV7UFCgUwBUyErwOT" ..
	"n478xmJHV3tRrIexmwoaf3vRvZZgOMJZqYDFN+ZyWESt8+WKM315huGxlXrlev+anJpN5Fn/BIgKn2PIzWNmo6Kp4nyTFg576qLJ" ..
	"w2a4vnZGXAay9CjmRso+LtklJ4pS4dx/AHxO6kILEvcTedl5Z7QP09hValfWMRly0O7P7CIVx/JUqh/3VFQM/YOEj+yVmxDiQYSK" ..
	"aEz9NsS4YAae6FDOi8Q96iRj6U4uxlZaPbCZ8il0L7gb/yNivkEDv2bp/BGuRSNIWr/ZCKQJ5+jolYAoUvG4HkkCZGb8PQOrW9ed" ..
	"PopTrGMqL2WJo8WCgzfAedgHxITr1iX6Ksc9balWwOZUufmJMTqRJvjXzRp0LAvmvolv3DCo07DklFCISKKe2E35KNvwlYEkyarV" ..
	"5xC2e6Sv9JTsIO58A6VH7PUoeTcWpRxYUWkfmZqChugI+8Rq9v8RKV6Cj0ZO2vyS9iBguREHaLg+Pa8RsFtyXQ++8WsrvVHd6XVZ" ..
	"i2Cz1V6weuyFXOAd4aumGfw1fbnjJROQavX15+fsos56r1hBkZBmozoQ0OfOpf9DibuTiIiitS3aX6k6I+/amSv7l+YSAabGgLmz" ..
	"tTuW/ovvGEsutH3tfc0WZe6O8Kku0Lltl2/26Mcs94xTn+ys9HgfOZ2nmnGEuqz7a05JNNNq+yKo2QnQHB6Hs3D+eWJIyB7lhq8a" ..
	"EcRkHGxeCq3MieZfxO11zUjDUOdNkjdCkyL/6s8c6BgTayIXJDKsNnq5RxAiAFB8+eWt3JOdCThrXAuBlSXk053Emr2kHVRetch+" ..
	"Bv4Yy5vIE2U5n6PEXnv/rk3xge+BAx8eHBjMIWbsc2WQT1uEDRqM0hygvBgGJMNLi9WX3tDNxZ5oyIlVFar7TO0c7W6wskFQvCwU" ..
	"4FydXTfStBhEYXGSWLGH1s3JujWPaF5isvdqK+hQViUxFccaNuiX6Nm7thx2WPhmmPRBCqHHT/7s3umRbYGPFjWNPW3IAPAo4DRp" ..
	"DjykErdL0pGeg1pZQqH3JP2V0LB5XoQJZAwQTJUU5ppi4hwPxuq8lcN1t3wj51C1zOp+HAw+FCs+toE3xH25aKnEn9AlgHJnzR/x" ..
	"ETk/wwfRT1dfuiEyA6ng6mVk3hjnpmlAvf0cHG72zmc9B2EDlK/DbMc8WWMHH84hNOCMwPO9hibtgERf0627rt/JBnjHpevGmdOn" ..
	"UdHgkLyyQzaCkS+3bq9c6fH3PSJ3vA6WtxrNkzhffh4yNLQyu51WYekh+ZnqxRWsOxVyNFXW82OcKyFEMZhAn2hAjXNIMEu1ctnc" ..
	"ZfMTxrWUSR2vk6XgGmYfLEP1VVldyI0lnbQs5aatB8vprYfW7Up1JSrH6qaTM/sFUEC+3XHgnqKe/Z0piSnRQ6BlR3sEyCWJK43k" ..
	"2cs/IbhPTN7ygnX5oGBvvkYvgsbdzMv0Z/ncsdlq3eCkGrP0qt10k75cRE4GM7TZGw2Ic9GqjXVIAlQP/TSSRg0rlsgNGdhOQ2Ne" ..
	"mPQsqPhWoMG2ch/vzWE9mVetm2VXZQk1U1kdeakYuwPKO+VAw8Lp3Avcv2fLeMrEiZKHAOEpKmgoku22UthdBjMAephcydC+dCyQ" ..
	"3/WKIUWTNVwC69AlbD5uLfdauu8SxuwRrb6LWDKqFTIC77OfQvOUAAyEYojrGgkZlNUkENkCXVJwAKQwq9rMTUGtx+4YPmaeFs8J" ..
	"s7B8bYeVfexQum92ZRx4As7EmX2eeRZsqYg4Y2fef7GgqNDRRnDnSO5HySfhUpcKPx4k9Sd3kBisyW23Xo4AC5r/LFnz4ABIiGt5" ..
	"IHlJ+e6Yl+JK0BPRwkqjKgg52CG+Y1sn3JrDzQRpPYQZoEyH7zEVbTdBkXiAeBwMS00qBVWHO/OwFr22d4u/hNfJWvKoukxdUGoD" ..
	"7PXpWh819uO6Q9daG0lKSbF2e/9g4EJRp7/7wNR4iu9yaZBathNKErejuOCpfqqAKxyjQDL5lZd1F9OeLcv+N+G7YXIB7yNn9g14" ..
	"1ZqX+yQaQO+Rdz8Gwom2y65944NYSexkUS0FRoiwjzbjmL0hMoRS9+W3td6yqQAq9mjgqgOt2aZDx7m/5pfz5U2YXUwd5ULmJr5J" ..
	"Ycthk52de7m8fIE/6Nv17laInk/H0Eemu/L4Y5yen/N7hkFqAkrkUcef5mt0FOJal8S/TPVxNsHw4Dy1bJirOCz/dx3Ac4aFtops" ..
	"4WkF0nUBv7xDQ1xhQugf5q7j/I/0cSOzhd77GMxib3wtQYaX2Pd/XwbOeArHDnYygxkSwKNjFkeK3fRDC6guOoBNwf7q9n3sE0GP" ..
	"+8AbCi5sRgkUoizUftd74Jw6b7otCwEi6UFgioXOTjsDHK444fbwoctCDr4GvZLnFW0pZnaKGPGkcreSw/8ZEFui2MP2GOzs98lq" ..
	"cJv9rzYicrTmGwm0Zb0f1e1oAh/FzN4aeGLP3HeWtVDf2t4zkAT2iPqiPk7K99I6cr0DdhQ2u3vacsaTCqdCe7rFaMxtPPlvqYml" ..
	"AQvDi/uzghP1V08iVllMsNqmzfcHw9kI4q5vEGxHA9UnYffak+91Vv5BQFG6Sqr/rOrVe2c8t+J1eJqSCdgiqXAOBi975vZ8EXwR" ..
	"AlD3aCBpf2AhSUjxTR5dERB8Yt++xvLb9G1w2xnI3S7YA+DMii+CNB3G8fGHPgI7pzVnUEsLkXalS7ZSEGcEn4qaVfx2HGM/bqAV" ..
	"Qa9SUiHdfjbvgAnZ0xsp0UWCrYZiI5mOQPzwYTG/Oe3o5ntM/8iO4vRLX4fY9uKZSFHbQ2tL705FVnhsuqVXEaza+MFhT/4F7mVo" ..
	"I59ZtEt5I8eAy8KUwdEw34O+ALP4kwa7UBT6T23z9W07P1iNxr1w3sJMgn3XzAtW+BNGpNyEqHuF4N3IagiYEt+BIFR/+IGa7iq6" ..
	"0PyUq69FFPaIEZJh/eRCYspkX40U0eyrj70qqI9Hbb3C269U9qhXrxw/SlEiqQctcVPqUZB3WaYV9jluS5VqyY9CwrudaLCJyJDp" ..
	"yRUuhPCikiBAcZyudK5o+yb1HtPSvgTeGaWtqoYrFnL5032uwdUeFGDl6+qvYgZJhPBuKN98dvziGUrUCrg4Tz9o4uV9kqWuRYqt" ..
	"CdxQvV4lKglZAgI24kWZIN942BM/6mRSPfAYxpb1PwPKWjY2kk42x8g2n3BB+nRtqAv/07dxmje5/LWDc9d7BQyo/Q5ecI9tCrvV" ..
	"P7oSVBbew8HqE1OTiWVmhTsEbZNiuio4aeF6E8hF/xgmmHgG7ifDe/vSJnA1XnO9c3K5t6x6dfUjKNZydIr9TRrYcHBwPJSbe73F" ..
	"cb37SV829FRbJ8zgX3JGBdHyKYgNPsyyihD0UjppBkSujfZK7nEFeFzyGgzQ8W7HjmR7Z/IZkArY1jb2ctjir3Zs1z3YcfyzkD66" ..
	"yE/uF4BxmfnEyZKO7cH9sLtl8z9+X4IEUL4nRcTkKwv1Yru5Uf0D3D5j1CiBOwuVnYc1nZvZDiNmSz5Zfk6QIJw0SSFvVp3rqILQ" ..
	"MsDKwLWKNsq3IVNo/BIdYq1fAVUQ5Vpu4FDzfs6Zt8eiFwa9fOs2QI0thQCQV68BA+93ANdT8AJmqkATz7F+vSHHRfo5d8ujyFpK" ..
	"QG1qvWlGc5nkDx3P0Q5Fxj7gL9gl8XrAWCHnrse0yOTZ2F+rYyJ2NpKJwNP0rD0lqF649sWsSfWBQHj8lIfxcbiu16go0BhV09Z8" ..
	"cm+91ll2zOTRahaZ+PvlPEShIlf+GfGA1+nHQi3PRfaMoXgEF3uq81q2rt5qUojQUrGxom4wuko2e5t8jojUetYb9C/M+y6n3J4I" ..
	"YB+d9bpT75496b+FnJPZ2SllBv7HMiafDjUKyv/rgC1/vPTGnvl4f5bCXPv7l13cJbyL4KpmBJMpm7n0/5Vm+X6e3shklvf+Slk4" ..
	"IPapL+UZOOcXJS1XwI8Y8bikU+pxpx0njxoihiYWeFB+AJBkuxq+BCTVN5+GDfXylycUDuDApAXEH9r1p2ICzlX/cD8FJRn0hjuN" ..
	"4jLrtmxhEh8rX+3GmBf01qPdXRkFX/WdqngZ3icabwdfQ1dDALCvQsZcSV05bzZJ8wo4sM+792Z48IMKGHQm00q2Ro0UWfvkbIFM" ..
	"fVRNN5Y7SyzLDLomMDDdcPGm0csxz7c3ldR7ieRQcwOlIDOFF70R+cMsomMl43Zk1EvxPzpxGVlysEkg1Otmyw5yawpCR7K8Krsm" ..
	""
local PAYLOAD_P10 =
	"f6edy6eiD65NNoBNRNIDqzDNqxqvCo9jrGflYYc/n4IRlUtwCtlRUi9Q/hendE88i3k0ycZz0gcxh2gcCXBGzUgInC6MbcU/hprM" ..
	"NR4/nt+aAAwGK9K1ch7witRW5vR/GlrVtWlZEzdsuDvBBH7ApKdY65AzOF0NazEpNiosuMVy7RQZExtMbe35Jqw+IkWgtd47162E" ..
	"zofe06DunxX0jWHCWCCZWysgDGlGFSmxvgDbgWarM2JU5D4U8zPhlRYDi/ISSDoyZ0QjL3fxbv1aki1VWLBULklS80urnzmUzQm/" ..
	"9jOa0BshSIVXofQqYyQdEhMpLBg+NIPV0c4AOuZ0uZ9ZltGe9j+vgHiMfmeKHTpKUgtekYgBLjXl2pByYOLfuBtSz4QTgSENouw9" ..
	"H8BdrusOkLCRMjsTgiBZpwi3u3iQNpXdIJPWKVeE5CL5FoyNxbT7LMlWrP1y3aj959R1RGxjIkFkyUZjztqHejLvgHHzIzEV7a/L" ..
	"xo4zbg8EYiiDdYs1eteePmKyCyoKnSKgLpMNbdua4ABBiJPx2p1WLs9rZWwOAhFroXzCN2UdRXZ9jHajBfibpPiUsgKvcWPnfTgH" ..
	"7/tyn2OmLUXFmQ82JY+IPktInG6WB5T97k5lIgvXNQ2nZC3N+jj/3eOxDeOPvxWwleGuRow3S1Cm7kZ2rKYcD/Pem6T8ZilMkDid" ..
	"n+bIg1IywTF5hRzEXGN7oiWqD12EbQJCwQvTsxMjdqUp0HrXol0u5tT8wqktpxqfSvsrSVzrrQnEYKWq9Hr0bA5UmF47a6AYMpGz" ..
	"wwdnBseWEtbAeViiXGafM8gV6M7nzQCApQezojZkOQ82e7ZdCvGVhVb+b5tYWp4eatZzJyis/RyHyKM64hCx2DkkunjgnWn1u12h" ..
	"QISYrKqJZXxWbeool51D82qIHaSDuVjXhSjY/nZTlLQwNckFrGW7qMf5pqwO4XDVuZV0p9DA53QC7bTEA3/DuJVXkkz1RTGA9uLo" ..
	"FgeBhUpAQbu2WGRu0jGvasYZwsCor9UJCg9UmU9QrCQMyKQDdWqmwcTkKd/yFfKSRNA3km3A0MGiDfS20gX+xtKSDvimNPzv3sA+" ..
	"hQl1a7owChuPCRvBVJ5OShUyE43k9jy5K3E06LtppDXGLJ4TUVvRu99xIQ8Q9Nz6L+/mvPPYnvmMTDB20q5fdnrQjHtYhKwLnG0f" ..
	"YVERm6fgPfrx7FCW/7TENfp/RpYNHt2Mr0lP6i+8SmrCEHJsOPxlF2KJ++2YzKMtk/FI+N/lV35Qi8BuhOQijAv9mMXSTbIkRoI5" ..
	"D/BYWlnGjSEGHw3JmIaZeZACpaAHlWur6oHDT6reNwRhiqmPJf1mePc5IqnRUmZCfK+aUrjXTKafw2C5saT1dE3keAnb2QCN6uK4" ..
	"xszdg25X15tNo3uQKFYOxLjU/qvR975NQrjKMuCtvVt/ME478/ps1ClauwvvOti0TzhpAv2ZD2kqo1SYoyvIlD2hGrgsFz6sREgb" ..
	"2U+SF829ZSkk8tQT2IqfUvC6DcoTzCe1/+7zrzsCGUkPPEZZV4fmxVf4As4K9XllzpDF6tqAZu5aXgRA+cZnxrR/4yyI2h7ALvn1" ..
	"qZ8G0quJorUcM40rQPXXRo6XNpVbmSjHHTvKNIvTptwmT751arIAfC6T3SjpIQYRvQjkUYU8mgRyAqFnlRQTia61ZqGLANli4RRV" ..
	"pDfHT2ZXKQib9FVlOmkJM7K6hbSrdPA7PafGzctoCi5gv/zvXatvcuSqm5wOAMjtmvHjq9Hh4O5cBZDbt568elqAR3NACDwf2NjH" ..
	"ucpmOMdC6I0NuQRI9hpjR0XCc5U6uvXKZo3OFcEKPK82z+ZUTKc8Vn48B978Ou2MAShveZCA8WeoGugKbU8sY0Pp9aqW5WMci4CG" ..
	"61mnj+0ZotK15SOwxSJMW4VlOkZT4oQf5sbWY9t5nZEyBDoKyp58YbHtMkiaVDlqsAKTrhf10khGIiZbtYNLaynnucSa3zkIGhB/" ..
	"LdiZ/DnPbvsbZaBh66srP2XyuFWFwcv5Shd5fnYsJXbeUA1vA7CUqAAeTmbN3UI3hlTWwGXTBnJo57GRD3D/fiyDpvPE7UfhUe3i" ..
	"76vQxcXFnDceHc41QYTa0Q0LCWL+8KgeRu3+XDfMJlD58lUFMW88q+lqtqauNmPk48dkWnrHio72YtJgf2cfGSxfgMtCg43S9qZ8" ..
	"DQKLklUdRGQ/sK+Pd9/Hv1P+HGRk+xqBZ2qXX9a80sbSnMeMLDhgfTaXm0/6s+5omdCRpIWpdjxJX9We76PxLgnoNP+qKusvIayr" ..
	"GxwnMkHppA62QQlFQ8PjwW531uPVCCThSLIjY2Ax0TMPMTWiw1rVQbWUeq5X6xgjfxZBFfmMyBCqHLLTo4O4G60dJd9M1TeVmWBF" ..
	"+XM/9UIQQGEZpztL0BdQBDUHJiIopgdWmoGNYva4xgD+vN/wxOi/ugtesDLGty2To7sscInwgi4weGXwNr855iRlDVGVjGIIJ5Wf" ..
	"cOc9xGfrGfcXLdFv3s9syY0d" ..
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
