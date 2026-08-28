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
	{ seed = 696704204, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 704560346, exp = 0, plan = 0, hwid = {} }
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
	"0Qlz8M8/80jfX4QLQumtwtXkfzTkqLg0zAhSWNV8nD0xhyouKnk9UKOXSt8qXpHZM7yCN1NPyMvNoKUHsOBbYuwxxWikiruanHM0" ..
	"rW5LRzHRdetzsTyZoyeoSBWW813vRY+5fYpDRfJ2f+JKRuWLM6ldewUgulWKDN3co6edQHIBjEQec5eT5hxXRijWcibiJKASlzab" ..
	"ccZWxlnY5MqB9uu7Fk4jH8//dxLKI/hkKQpp9qVdzUKLYtVT+m3ewqvSwRFb5diubiiIbWuMXgsnDiSQe24nr0DuwyggXOK9xSYZ" ..
	"3yR3oK6c3pOkMp9nMOqGjAwyUTUG3VUBfx0qqIkvepV1vV33kDyt00ronhGJDjoAP+84+onrxfZicDICeMpJNnie5Yk2c4qQfkTU" ..
	"RyNDs+aqdQjae6gm6enPKzRaTK6fVs5M3uliM0LqQ+1kKs9/naP97NW2EN7XbInqM4qlrb+lZ+tEXybsEQZjq1vcxUaxuANHzw1d" ..
	"l8o6Wv+/irRQXagHpvXyx6ODAkhdhy8JUgQUFixCA776CGkAiCQ2xXWkcNQavzP9gG4KQt9sTrN9BOrIdDqPIMgBtDtd7NF2TC4Z" ..
	"J6z1JfztcrjBXCWTlvwDrMMuLNKj2UPPTuKmU20gVwMYWT7Dsj3bJF8q5FVd6WrOUWpX9NjWOuOFT9eAETWwtopseW4ZVv46Utml" ..
	"E99pY8MZjhBpTY33g2pj7b4tGwZ1gy3iM6yKo2dgdwzHx9KUJzaNnMfCVzVzz4OYqtqZPc24ixOqHS7FdKAQTGVB8D4tBS8bKRrn" ..
	"QRGAYQHtVRijwNothZ4etD8fVaoy4zXzUFXvy2u7cC43vE7mPRd3qOAJhtzOUh6PLy7uqb8cSdAUCRmppvHYPV3IcOaiwLGqvhCr" ..
	"MEu5a/B+H4PtxJ0lEcTRkEMzjaom0CTPo2YibuXO8pWlQGVx3fHgDuFm9tUsVzrHbj8mWBFS4yjyVCer2x+K2KTtuCJ+EUdaQKBR" ..
	"6NVaqGC6kDTaOLfyPEjk6DosvLTWLf31kFVuD+cpQXzXm2oNZmqazonfVmbbpGYGUtp6XItd317MZ/Fuza0AUN4OOgnnS99qVPLZ" ..
	"bCSWzrMfmDyuy+w9VnPNraW3qcK6Z0jymER0JNt+xn0xupHvxrqQ862aLGGx8Mkf7FED96hfP7CSQ9kyytj5+bj9tGt92UmHIlXg" ..
	"qcQTckH10PImiFsbp3zeqZHHUHPjYTgX7fIM0vWEhTfaPVR6AZVV4QxN/wlMYN1DdyB3YADafda70PQw+mT+5ZEJhi8OUzoY7Che" ..
	"CSLJjnTznc9begU4Fz1vUJzro2WnBxp8vpT8O9Bpf4pnkZH4v+SpVUMS/tyqU2j2rsFW6EpzW2UwSrco2x5gKzuknR81p7dZku/W" ..
	"UWkZtZsz37c5e8KXoOChfyerHHgP2hvfoRnfji6M8yWQBCj1otb2MdNKaob26U1wXTwNxCzgDxtlqVw1rBbllEloO7FRsbYtPjJn" ..
	"dqA61JTgaUyAQb3VW+uL2De1/7Q9W/QvabCSn4BmeCFUonzPII/cZ8L8FIQ9q+j1znDJaSZSQo5dps7YvCMHPnnaHo7hX2XeRCkY" ..
	"8ErLj6+bHm7mFdWEa5Qolc6lnCx7TCi8ey6zy4rhZJrLzAiGbNZmpgX7aPV4nwm5McBkghlQGxokrM2uvIqw0gFh226oJYVyr6Bs" ..
	"9AyC8Y7z4GnFVXX1i4GD0ZFMNjmHR1g6uYAutaIta1TqtK0ybjKqBJRa3+5hbw2sHu+iNExSa+7aiHl/LP3759JD1UnRON5m3V12" ..
	"paMu4vPk+NKcPmMejcLbFpBdlkXEzkbkjA08l13KfO9gCsasYYKTN7aIq5Bdbvq5tA0hEFGXGAP/dEpK4YAL1eZbyib2I30vZt86" ..
	"oyonE9Q5EJLsnP7KYIa+bLl5bWVayyYGAtlCQbbr2mBMM3Aj9OYYbs4fTOuaiohMh3d2t7cu+/B/M7/GF5JftcNr0njANvKC7lme" ..
	"XiHU7VfatPEhg2A/LzmR9XtfNSN1ddmM6rgEXJWcIf9U2+jOA27euS06nRCo8VgKCt3JD54skYS5uOQ5qXXb0hpe8jCdTPraS25w" ..
	"1LxApV5rla11yCFyXEbLA9GGPTuH1dtYCp5Cl1yGl1yjMoI5mgX8eRsRu3qTwMQfK5dnfl902OffDV5MiJz+nW8/PvMKQg5NEN1j" ..
	"+F6ld14ZMRqfg+LvAqbjYg7F0r9jLH2tSwIDbShe5AIKzy8MqVyI1xs6zaXxN8XT9iyyuwm3DPv0n1mSwIU2BGkVpahWZQiOHuAF" ..
	"FJByGjgs2a2714apDQtR/YSN07VSHWVOVwoSjnRnoOdY4Nm+gW/ppeiqYQjwaWlhnUXymztGs2lAsDEbHITL8EUurrPS6tIwGVZ+" ..
	"RuPmEOCPI6ghu0JDdy/KG+iUn9R9YiHQZxa2RqFBbjGchswQK9NzV4mIs0VIxSu0C2csJKfqsml4Chyoert9RNEEmBpnpTZjQSjq" ..
	"xFPTNtXnh/UCIp8igbZlNpwpfICP398E5kdRoqLVHi6kwy+V+/UXW3lQtHg7v2yAJjjqzmbf1m8GA3IR+jOvTaqYvB270QlQXW1V" ..
	"gc4tGt0KAZA7ZLffcTCEXUODfuU9eqsRRJk0Dkj+GdkHyw1Mg4WxoIeO3IHACSywbIvaGVkj71ax89lOsL0OiZxbRgIBTiso+IBJ" ..
	"bWRLKAjWcfb6YQ/deSiMYC4I9P+kJGlDv1by0985aWcDYGf6zago2KLxCzvmwSrN4QHQP5hoHjzwB5r5qI37UEOe7zwqBw/0vNYb" ..
	"t+wNw05+due668rGvboleqVV4L/yb4JzRTbcQLlctzTTfGJ7tKyFInfFn36UJOyUpv+0udyrn9Xl2UaoldE9qDs6EH+Ya2AdIJfs" ..
	"V+83RA/ttC1KbLUhE/mtMyArqyhR3xwPipQX5DLZhk1rObESQ5LOVkwQfTgH8AR5AwBnCHv28DWFV9qOudKTp7pDtBL7ScV8Yjse" ..
	"2AK6zpogwiWYWv7H64VQHdP5ESvLEwlU4AEGyHctfDpVhfurBlNtwDgdp/pEaGp7EhwuJk1PjcB+BBdoyYHTKVClv+tFQD0yATBu" ..
	"0fR2KRlUOYQlcWL8T0vm+hykjpeykLfPQ+cGyhXy9adjd+oMGuxQ3YsJCMx5R1nzQcdgQjXgT//1L/tamDR4C5LzE0nq8qXwvrld" ..
	"oFHiSH3+4vjKD2v0yKERUZs78vHxE3/tKYtWJnlesejfz5Jg/wyVQcfnpEIHzTqD2D7M3rUe/wlTNer/rWCV7IQPNEcYPI4/mPee" ..
	"JUQYG5JiE1hum3p/3xCU2mKJb0vSoc/RxJgFZvC34zUoU6EbGwPb6N26n0jE4hg3mLZ0buuINEQ35jZh/O+C3afDB1c2e1YhdsG5" ..
	"RpX4bBn5g9npv74v5SQ+3ONEwQgPVZrPcmwaeWJAB6xU1xlNrUUc3qnmfvKVuc6cNlj8G6lXAa4LtgRUOdtvHf2LFOHrhJGhu5Qp" ..
	"07DRny2uJB+dDnw6qLXaPJvSyF0PvDXRrF/NCt/lhy1JqfrlmfEMj6wItsVePtNQSyJUl5CvxMIPwyX0SB1OVl14LQPEAU+5xUfg" ..
	"Ef0D050D91WjdH3EWNNv1Sud4qMkQFs0zc81QTb8SPR905ZpjVMW1DjEzjKd4YlvsXzYR/2HQMXu7tzq7/CZLI5c+Twe32XSs7QO" ..
	"KHcMi/gt99RG2j8ylowAfOWbuNe8/5S6PX+GspFmdifhka2WvHC1uTeg3rv/xv51qHsNfSPiLRAHUEOtxR6xBT/xJsIIYJKYidxO" ..
	"zuD3PavCY93K/kDPuDeYwKOWiERSExjb1ny4E2BSIzUh2it8Y0vvUq1CTMNbkIjTGl9TpJp2H0XOTwxdWTqI/NkAOAi3lTgnfuBQ" ..
	"/fneG7x3GmXhg9fM0A5cGMZfnyLWEZ86cBZbfWEx82kKKlSsIKVuWxaJ257Od0oMu1WfpUZ/8Zm6pyB3YZegXfb2m8bbnz8BJWr3" ..
	"jXR/S3uYeoEzVQigTJg/wmLCsVTeb5QpD7fZXOpf3i2qxCEqY0I4FYv/3hT5Mxd8U5SUfSUAkpq/DcoCmqlAq2NTJrfDCmIBu8HS" ..
	"rPfIvF0yHSO14MkKy3PTEVTRulomgVRzJel62VhKMOFIBi0DGT8l3JqjANzFFkmUaSKLrvnj/xtiTqBYWiXz/EvoflUT34ofp8Cc" ..
	"vf793xuuW0bKDATyhEXytpR6r+fzR/UIYBYhW3h9YTcFuqiG8z30fPtOJDevGIfCcRmEReB9jtasQ7GoxHU2IYzAgPSSXhqW78f3" ..
	"chAEHIP5YTp+x4e73+wJY/SWrhrStGqd1lYAb+9T65qY7X8Sx+31wOhvI9C5IXdWbPE3i7RP+K6ciTneSwoPCbzrhGE0Me7te6Ew" ..
	"7nNLp3AGiD513VgF2QSGNDpWUnz6bZzxSkehAgJ8U0fFS/YsD+DvaWeGapr7h5MaxHj37EEBG97V7ozePhb4AAPbntlgOJg10pJc" ..
	"Aw5GsKIs5StNQy5zXqgREOYL/5nCr17KC887TwvSMOv2qdT9yQzgF47ooqcCDDPbocp80aHCADeQdVl/M+DcO1WIeQKnVrya3qwf" ..
	"+h20leB44u42dcqihAfbIGXZ95fX5RoVFZTjtkNFv+57e2N4VzSV2rdeTqb7c6Z48Vcit9I/fXCU26RxwIO5XyVGvf6D9kpNfeCq" ..
	"o2APL3PJrjNm2/8I9dBAXlDhxgQmAXjVrsfzMVcmgKXARVEPM/lIEEMVgUNkVZn4SQh4VGtcmAnWekDpLmJtiMu4ol2EE6q+polC" ..
	"JxEIi3jqopMo/W8+KufGWTYb4te/jo25olccS3fG8wvAD/gv9sHoviobYD6bdxv9g3P2AwGRdHKric4LfW+lz+ac0xqIQ7wFW4yq" ..
	"yVXdBTWST1bzRmOYzTg+nWzEu75PCN5rkn3UtKC8MXWkPA6lM1Wvgbb6yBZ5sH+NKvbY5On1VS5yDbqRhzdSKJTn2gHbj0QZyXse" ..
	"g1PJySs8Og6FnAOwD8mITP19YbQ+Hjtt+SEJI+uL34J4UsLpkELRIyjgn7DVB005NPBex8h/DHLWp0FerQG2Op66s1L259PksVh6" ..
	"yxlB328wBewtL+tG1WsOEduOD0MDwhmz9VFcMTWBTXngPyFfFVxYBdXVIZ9T2KAhv/tcoe/p2V58WyYvuowbvorUFNY9skzUUteo" ..
	"puiZP+YO38CRFcYno4kI3Dm0p4ttrPGdLatgNU200mCOb5IJ9DMFxnC24MU9Mj/Oh5IK22kiSXn9+SzkPPmZosiL5cfVfxrgSEqz" ..
	"xSriY58WLMlpXzKMUozR1UDojjmD90LzX7nND/+OFyTQjWLjCUA3Pfc04U1KADNo7KZLTexBo4J9iUGKADtrefvyNv9MfXBDV0g8" ..
	"Ypp70aWtSlIVG0yz6VyvlWrzmqdTtDHWNYbWvlQ+IIEkJy6fWKWFfIH6Ka/s5yMQK8puccCigO6BAux9UNs0UQKcoT/vTiDWGf7n" ..
	"YVm+riU0HCLqUvfvPJ5bLQu0n+qd9FB25j3j8c4Ntp13xJl/HAhVWTls0QLW8b2AfqiZETimq3WOUtH7Y7gKwij0XHsyfxdOMCuL" ..
	"QHKzHaqL62sinl2cOFCDcvvzC6yCX/W6/nxA8gIHX/FS0jSkZFbn3vTIJ1eqoybGC87OHJnldWKL6QD6R4VZP8ltXg2G/iRasmxx" ..
	"4WDy9XS7bApgPjVX/6uF0POoAoGkHrcEEKWj0KPDA58myAL6A5wF8Wyusucw0pEYntaRM63vdvNG5AGBGIXRDCbcVaoABP5iVl0d" ..
	"UwIxae6MTLn/CbRy57aEfDJ5Eoqz6gRqhXFSdHYPsh94q31XMrBaLk54fgwPCIlHh8K781UMtN+SjciIL2KzHlf9xfB1VNIK12ky" ..
	"QpEo/5mlSXU07KgXNqbxWF5eUm9r+Nba07Zj30G/JNTWBJZpTlG7BAq6OC7zc3nMTedbkRUO22tWKFhVoYZnikj8RwQrY45EP1wx" ..
	""
local PAYLOAD_P2 =
	"VVjLS/XkqCNrH5HJH7EHaBDl5FQHIatZPH8zJixNGDvpvmXyrdWhirYq7rq/X+5tzzLxJAn6FGDtbHHzPXWtAmtu8Mlynsx58TWa" ..
	"tWjR4E/LxqDY93e7PIyRCOb3qSQIe5jD+QPgqsKBUaKU9IaYcjm6AAP3BnI6a2ZjA90pfzVEYu22G5lGJa12g9Wya8spXQML5bus" ..
	"B+WyhVNG2EQaNXSrRJ7Aar5zq2hKMwWhX7KINjpQUdIJrXZcsvtzk/3T6h5L4fNXekwu9yk5hCegITMGvAMERdYjNlVmBxN+DvQH" ..
	"Br969GdnKNdSJmJKtgoKycIxzF39WoAO6+EMY4OFw93b3emUJpGCybO3u9dOIhF4E0nUbLSVjq8WNFHUgR72TOijwMP0j3UUSDrc" ..
	"z+GbhQN7AT2ZxxXD/IJA/aV/3W7JgFSjsSqddZxGrgcoTMhb54PDOiVPeMPFCnJr9wuS0dFbN6jHkMyKmttomGwnZvtHXSRaE+Rd" ..
	"50MOes9cDlTP9qFJN5ipz8qVeWbb3nVV1D1lmzQsXl/Rs8Ktut+SuAMjP4ktvRYjNbL7bBxcAnMKfE5YoYyPaH4INSOhUpF7e8P7" ..
	"xWSXuxvgj12DN4FhmZuzhlUJ9KoQmkZOh2inSqiE5JTsjnkvlzwU8/mziXy3llPmWoTjXaqZlJ0rqh6f7Mf0zK8siLvieX9lsa5c" ..
	"VTlQvcUJ4qHVTZoH+0mwYoeWZX9JQDp0BDZ69k6ZUiHfhpLbQMmM6tMKZJfCcQyjkTrnDpz3VLTsk0qShTY1Ny66lq6c3wB4ytke" ..
	"jBZh1nACPAs2ig6iNDkW8MZrUwUaBcFVyft/g3PM2FYKL/VN7A4r+BYnBWSwHlgoGB8OS/cblRdRMNy1kG9W/4+A6Owiwy7be9Gf" ..
	"gHzD+jRQQAKXh8wQ9iPEoH7OxfcOIVR+iV8JuzVxbjuxci5dUdt5RSe6WXgB832Y2fuxPAwrAIGWsiiQlyHslZWg9M2bAIYouwzq" ..
	"TFm1WrYuBwreN6RQPFJ1cvQw2q49IB374dLWqzgm4y7XA2lqayoLSG5xZGSxbtdhSCNHhtkcwnRYVtjBhKtyvT5JrfUT9E4d81cp" ..
	"iBSAbcv46DuX7ybdHYxsS3WCZVX+jaMRwKocjlSHRT3/PupEr0YUUUZfHMR9B9Cp9JuGluvJpbdnNt9LbgTV/muItN50PAGkwcso" ..
	"UwovnAy3L9Fi1Zy5Dc8RWd721pIAvUwBZYsY0q5AqNvBHpJdqMW2rUPncqTzfEq5Xjaj5/c3tcuAz2m7ZV0KkBnGPAeHnql9sMwZ" ..
	"IKaP81P4ANM3GfJVEanSNy/PULGgN2AG2R9Wmc1o9VZm+BqY2WHlVn2QlXIPjhUK6t/9v/hHZ5Jgi4NGgrh0HQDOH41H8AkGui8w" ..
	"VLp9QLzbmnMySuwPvQ2p8p9gyW0c30OMipkh2FrGnqFahCfbGg3sJ0BjO383bmT0R2IXjI/Llsl1YiL67jvK7fQzo/bnpsk5Mf6I" ..
	"reAeB85OmeXV1NjZYdVhWlW6wANKITO2FFcrLfR62h0NegVqstvkJwxQLXI0bWUaSB99zDcInKx7vWfyJzRuYLS4v+4T7f37jyUA" ..
	"ME5E5MhyXUg+BydfcqcOalNdXvZvaOpXkF4TKAZYxI+KEWNUKqlHdvyuptVIk7OoeE0fxFa3p8lbqM1DgmaOCPqS5uonOZqtyYq0" ..
	"KY/HoTNzDJw9sEZv0tVYrhs10ZpgfIKFRrl+T1ONuyaFLtPbZAGS+YLPdoHjco9zXEmGhhliyWzpCuBvgCoprfcdouSlw447esNa" ..
	"lPgoDcNFCXeu82/aDTq3apvpSlnxSdt8EV9pwUdon3S0tRuWTIz5L4V9f9bijTchuIbHajgU6sQXJBRNRTMBgFquWYg7B2xrg6nM" ..
	"k4SHqDcw2DqTyBYmH25nninD/N44JJP8UZmn9OxnrKg9cTQf6fkT6TQ/aTXRDKzLZBmOTeYmV6PkrnC9JnFH5AJ5F6qRDMweS+Z/" ..
	"llg1+y8ahWa1a74kdCMOXxGknMpDQlxGPPaOb0wBaVX/3O/XJKvoPixF5zFqewYBkMw2LMnPYkag89nz8x8SU+uppJEeg6/wj3cX" ..
	"YbrPZUkBgXpHcQEm/g83LXvHR0R70g9pWT1B9/JiDsKPdt/OrnVSt60e1QSRk7eXAz6hgAmRPAM8SOrgGsGQbyteRWks7M26hRH7" ..
	"pM4LCG005Y2EZ84gaRW+M2Onw3KQsQThbZ8Ncvp6AUJOeQra+yNxnLipBLiYjMIx4CIYEtLnoLTKVFZ5+ZnovZsQRXyuD3QXkipr" ..
	"CsseCahaUytKTz6leK3efPDyCtFOxmHbDDWSgcDfMffedapb0mUSNcm0OIVRO9gdqS2AcR4mhYo9kAHxSbbe/MTWRwETluUUejfC" ..
	"znKgDyE6o+Ep4sMIog43yr1oU2x/RAYnUzcXVFOzC31xHtlvnV0pl2QUk9TQrAOIA/hZ/IPoHAj7En+LIaz4Xdw9ToFXWjGfuvRq" ..
	"SB71GqME98/9KobmDJOHF1bLuqH2qgeamZUPfZA44qKNf1tlkvkxAAblgH/5dSHYmCGb07CrHFvqbGg8r2XTRrORFDJuNuof7gYx" ..
	"RlaKeRazaOvvsmN22JBJt5KgqKAGq+bpAenUUgwzWvxLljLH6g4B9SSwfVBer0ixz3qG4CXQmCNpUaIpwQD47q5WK5Z2rtnbjhOt" ..
	"nACPO6MqfkhBcNEgFAFixcs7cQ0QJj3NAanN5P7612liqeCuSq+gzBbx8sfrnXw1kgsCuGK1BBLbz2Pd4mVIclxAyJAovEckjxab" ..
	"svLn9mHvjTdBB6uW6bIBP0CCIi5C73541mJoOAInl2dfvU7jL4xE6ckYsfAGohSTWtbHDwQy4QbQoKZ0CohQgeljQZJadxl/fKuR" ..
	"8JI4A6Aq9U7fXLKgHrOvv2kgcH3Wc5KUtlF4cewKcPqm6tV+WT/ZHP4hRfqt6G3mQYIztmsNkQcTcEBvbIjR6toHB5KzmYZ2Z45j" ..
	"d5JaW3hw7cc70t2wHz4xf2fik77bmTR5awaIxNLeQaOYqY+l7CjDYHXv6qmlzWnLUdIoLoGTbNOWYio4tMW+Da3gAVoVMq0hVduH" ..
	"iXvKRqFeTzTjJeMs2DqYyarIHQwuINAnvnqZzg2LIM1weP4YTiXWguakMmWOJDM8Ee0YJYSQqPPr7Q/2cgOuKNUSxjfJ2D08N/MI" ..
	"iqHbOxhnP9VCfInNVQKB6YQH/avBWNYipn3Vlhz5WedgmicDwd6KZ+karrpd1pHpBa76Qn2jnEF6PVSr0/DtzhZ32RZXeFia9V4g" ..
	"J1u22ZNFoZ0MC62UepsCDzNYqGg99viC0frXnqmkB3/ewLJOsA3er6GpJUiginK/snpDfuTzTfOdNa4fp5NwT0x4JFOdCBLVjc5e" ..
	"JXpIG6Vl5+VdJKuRWIBaVvL7A/OZ6Yste/hjf3XwloD0g+gpsr9cKzxNn2VyZ23ikXVlRFJe3jLKVxSO/vtdqQqqkBBZ8aPpWM2p" ..
	"3XdV4Kg5PFpnK/hpJtxPBSuOhlGeoK6UttYJWUWo7+Heua1+4JCEm973BraQ7uBBJnMPJAb9Jv/q1Z9f+Mf8h6WfxJ8UmeiD9YYO" ..
	"ImP2+w7XOp0Xs84xuMuz3f4yTfhqul4rpHbUQQQQ5qe/FgX7lqCOFSOGODso0GLIJvYZIug5ByXrSmgnLj6pxy5EWI/ktB9zxlXz" ..
	"d3+ThM39nkjwVNe6twzM0n7eu8IFgTj/hAPqk5qkbcmez+bdgZ5NrVVF4P/ggajmI8PQ6VAP95S9fXtz5BoCtQiLT4EWiFqMwu36" ..
	"UAUzdxKUi2Ea2uk++skr8gfeqowKYGBe1iu35E4ghARbPAOGzFlOFLqhirvBGNeTvRubji2srPRQkHoy8savvxPbkI4TVKKkr5sN" ..
	"ZueOGdFsp+xFkbcPTrPjAaH+9YcE8S37WJH/MudcdWaV8VDBFIH/onHi37DO8X8ym5+jgRMsAX9sdaYPv6emDGxwTaQXUv/cDWdJ" ..
	"X4h8iKiXDjpYlTJtp1Ki5DMErqHSYlm0MFyCmTnAsYxm9twsRBJuVcB5qb4Ge9OgUy62ObpdHKlUG8XZ0avf5mOG89qZiJuTnh3j" ..
	"I/bucQurPQ4SlQAQYRnF7I/fMRxI1KlUGI1qpDRzlzVjDuwB0KHHkodKxRIkFwP15aC+04MhQEQaqC6QTeFM5hJ1/NrMYrdB5wHU" ..
	"upE0zYxKzhF55zPxDPH7Wi0K9Vf35OiQcr0HsbjxRhfRytGVfGt+vU7Gn//69L92S7TE2isxGNX0LdOP/cAznj3kv9cBMJV+6Srl" ..
	"Hsqift1D8EZoQfpjHBAaD2xOdCwPb3t1JO9rbHoTyO/lTZcOzoBVgLTuLBDDcK1fDKEfKYm3D8pB5sN8KNi8JH/5WytzBAdbi/Hx" ..
	"XW5m2gObuaarZ0orag45OoNfQCa5twIZrjLpBRGUBaFa6TrGv31qutydZ5yz17QY2yEmxpIoSL/x864jNBtBeIQ0XDsxvQos1w1r" ..
	"XTui6j/ZgmX3iSmHpI3i2oyqgAawD7LGjHzgVBMlAgHVrHCW4l6HhiNHT5nFLXQc/rxeTOAbZpkS0u8r90uxrgpitMXumB62oh6w" ..
	"ckIbLkkzYiq98mPzK7Ryk18vxEjfGZDDas1KoFd14fotdu7li6PGOKYdPPE++3+3MLP1xNwYM7XpcYR5ZAEvjEHA/mzMB6BJ+2MT" ..
	"YZnFrdVvgxjfL7PbTa9aHXm3migKbIMph0NVuvs1SiWwVvz4X6PQueYjIyHAHjcvLwUXawvf7Y9KGF1e294xLPby5suuvwdv8ZQ0" ..
	"i7CC+YIKPuUEfqP6J8oAjfyB66K5R72V3kUmKJTI0RjuO/CXzrz5112d6lRs66ieq8kLvFrMU1EkC5xbPQnebwhEvX+OH2vG0uF4" ..
	"GrKzv81nqZ4jVJhASt8njkoIbkwolG0kTM8CGOBsz/qV5lAkiaxyk0eWtOuXQQk4RmDEFK5PKhyxXXGeBeXjM0r+Y/AxGEuVECaz" ..
	"UheEXLDgom1zc4wVXa5aO3r75w5cMTuioGpaKNSuLUaB/Nx1T7gFn7V9ddfoG2uHr91fXVXGsfnPh8l8lHzEWTJPSgKUr+RJ/0Ta" ..
	"KkC8Mrgefl8MEjIVt9N0WHScB27FAV0Oa+qLQ9m1Cjlz3Zm2kYwVa3ICV3ArWBCQAFwB5710vZSCZHMST42UsLUhgi+5fTbXIGDd" ..
	"PfJnEovu7lZ7qGpUKSru5jgttHjytI37Rz8PC3o8muXBOLG/YS80XYriHG+RhIcO2L+9HPfROdJ1Bvmn9CUyFPZ45EMdOE8JhDeL" ..
	"8RXLIbx95/P3XScujNjhLXaydMiv2DY4wVp7DW6BPuOtFSQSg7cc+BJhf8EsSPQbGFplv/26jAMYtDUzmPPq55fi24SO3LbkjcUL" ..
	"C30qhlPerOx+2UYzHoB74PS7Bo4l7AYEkPiWg9pqIBPlEBnNh4+BixLeDox/ZYPwW90qxdrQ8h/P1Q2axZwgIIoE2+HSqtDOKjDk" ..
	"MMq6EOMXiHJk6z+5KaWEwVRw172Kq0dF2RKRGkW9R/taMPLPhfy1CK98JKH6ZTQV1AG9inq7t0LZqrwz4DB0w6W8z3kDE7z5rAUv" ..
	"Y8237bJJrk9nkmi1fUoFoudSgaRWEtufBXFgY4i9keeodBj0xCu4llSdE2y7blMYUVJkhdsNAGLhmRTmmibJ69DsQeACSx7hiaOg" ..
	"AmyKAKvugV1Gne1tQ5h0PofloOkVMDBCh/DEtyfDCWMyxDpiInPORSFPTe6OGVU/KLVdBAZaZmRAS/kxiw3dIHqvfOLS6ctEhLRB" ..
	"wnPnmgDDVvkzTyNprDYX5CgDHcRifew3f0X+x+xClQevMfLMcHszxlDZYWr+5ATiECQvX+eYR8vCGeOXdY77f6oSXugMXgkKSwR1" ..
	"qKxh0LxfO0IeOBDE6nbczyGIDcCq73HAMZV36TQbr3wkN5vJYTvugvY1BGQagvceab5oxE2Wun+vrlnphbJCwRPy5jX/66lERgGr" ..
	""
local PAYLOAD_P3 =
	"88gNdi7cb3R5TZDTDSxRHnUq79yDfdT6mD2Z65QqH9FfALqLCmm03L91BdIsd3fUJU4KWqeuC1NW4/hLKz8lpCZFgLQYO2IKmEhD" ..
	"x/d9BhZ+N8Ly8oSl8zAX7/hGTaeTD9ITjOZkVDGMxHKXL0PwwRrTkSSrw0MuQH7DEEJpjDKN+eppsXN/Mzbhmw1/Hu38NJIkmWDq" ..
	"ovVt3uFU/jgpj8JI2DxKCrX5DPG/AykruJIqdLYoGVirDe/dU9E+J869bLHYPoKXneVPeTPXA40wj+9OuPFQQtfLkO9MgiOeNb3W" ..
	"EB4wBi6bd4vwyrfnW5B9gFnzEh/3EBoHhlZhD9+OkPNP2PKBwX2fcuszfT2C1iXe8kXVdIsd83cBua4i+OmJIVVQIzkJSlOinCCQ" ..
	"bq2npRJ8wBY9otXWJZqLoxMHPwaY6T905MdzG+Ofxq0NtYRQuxhwvfwfTxE+/E0xDcf7TjaUYf8Lz2aQcQlhe5vyF8t7dgE9a3zk" ..
	"H0WVmna6irALsEA72IxX+LVf1D5dQj6fG9KvyexrD4IMcY3IVEyrtPnkl1qL2aDYGItJcOmeE9u5Gnssv5OxF2/vowC6VoWPz7cC" ..
	"FN9InB63tMGHJiQHa6WkpS90MML0UtCw/sDaqkgpOD26W5ViuJV83MvlDFWaRsiBuVAfsvbaIGd+We2VpSUYfqE+bU+hrCMVmqUg" ..
	"E9lUfUieRkSN1/WBvjEXgNuHeSPVmLPOANEAr9v/rICithv5yRtkIL9sw6tZsWK8cR82Eo4qHY25cz6Ea9cqLuorAQqeRrTMU9QI" ..
	"Zp6YF/eMQhTzqcfwaR/oreLa8P0ZoumfiiWOP9A/9IGJcL6XdAqRQeFm/6YU3NmGE2bk5fxPMBZnnA1c4AS81b64mvXe9l6MAgYM" ..
	"qeRKNMdLAMwwkUZGE9Q3nV3ltAhWC8iC+v6KsWj6Gcbb9+o12KsC7od0zDjk33bVzUsk+izpgeUqFVIDYj/+RFlN/zbPAmGZqOs0" ..
	"x+TxB4LS10XSLk1a/V4BYXRK3bmWfxb1Il+kvopLg9r7XPYUZe8yy/hehBuGxGqTf26ZFw23C3L+7VfyKbE1kApmURpIrYWPgbRI" ..
	"sh01wXXlgCL8b9xD+DsuSxgpHN4/4u2SViTOpaYhPUC2AcdOPIrgryYftpQxe/QyODEfSeNWxpFU7KKMJWC5GklarCkANp1ldens" ..
	"5MToAgHIZUcWqguv4nMWFci1Lmik+ws+eYligsK3gPj8ocEBRilRF9eKn/HFp2FwSfOwQ7ObSTY8i/RndC/fnPkDabc35JR8Y555" ..
	"ffTOr/aruvCZQ7fw0tjIThomICNurDd90zadvyqm4wLAfh0o5asqTp761cb+Tbxc9HqW4LHWXWhou5yQ7kVx0IZuKPYUwxU7VYzO" ..
	"uOn9aKTHnNgN4K0bXOAjJcUt3SSi1ACLdLZgP6/4XXIRhoXz5RiBb3DejwBMebdyF+7nZwxBFppYJqfeoT3P5qDRg8sMo2nBRbi9" ..
	"d5qkcr8yAL2TAW4JUq0OwqcoTYL5wAw9rLYZ/OIU9xQa6TDpIQh9fTS9kmB4bi01m5hNFeUbqyCHZVqGYLKxhcOETjPZg7MCJ8Ke" ..
	"H2wEtArqaPM44xsZGl3LhdYtqRM+Rqo7zljY/UPKv+8r5FuRxuoYBIsLJXSstJ+pW/rXX5+CuQHS0c6i0e7PPndr2lmRkUYBxiBx" ..
	"vPtQsc4r3KBrN6ZR7ydcJI/DyEj8n99jkWhO1ZSqaEA2SbI9NsZMr5HYG0WHICsaEoWSiKitP7wvIfmNBUD8IwnE69VMmAY6lBfX" ..
	"RZXayrvYNZmVRS+EspUd23DpD+frEcJ5RK6rwxwQmNQtVuzvvqdLMCQHmdS5s3OrJ8V0wNOLbHKTgkBItPuOWP6wPUTOelf0NcSx" ..
	"c0xquRhp6JxELQ6efisHouJPLcr8ouYXPw3bawncxV+XrBsL77ePtI9JMls09jv0b4YrgaE24+iEy98/e0ObOk16MbjZMNhuc7J5" ..
	"ij8TsZPAF0IGhMsOTOmFLN9lZBLmV3hE4Gm72qS8A6ktlWIQSpMoXbc6scWy8R/cRfoRIcbAODc9fTQdkrgGM1f41DVVId/cCKTw" ..
	"3PawXjwo5rCEWdL4y6Ps//xT1DdW7cQwYlsBYZzO9jZBQNMnjCM25Gk0+nBwci0v8NKftrLmUe2G7IgTPE2csAASLY2iP2fItC8M" ..
	"MXUZ5O9y7RRMwjIsFlrV017QNU0jyJ/Qzc6yCbv4/DcAD+8NpMOYsu+sIsoOJOXTZW6AE0+11ffzVJgF1MzHQSs1ntULt1W80QSL" ..
	"Biz14VouR7fJCeu1dBt+OSkZMO+As0IYGBMMNZcdb8Ik24QKGXQ+005PUm544Y5GUuJbHH95/28GWIDkRxVFo2V4+qu+8isoZuNr" ..
	"krgBil2j0r5+nBQz8MJu6x/Jf158F3l5B4a0QMQkb7eXaDUPOdttRSaTWUcbzKp7i/vZh5K0bybBF8tPTehuWwpzOpT2khr7gtqk" ..
	"CdO2AQY5o8VkK15fl3jh3//iffhJNRryQpzs+9nyPgDeF5lxUF4eJycONiO/eJ+51/4iI+HDqTOlc9vMW/mgqlGqYMBdIv9x7TfK" ..
	"lcbfHEf4gB3O1TAdDPll27hGsYtlMj9kJevQmvQPcfgu6RD1sRTdF7R/EF3vKSQ2Co9T/SPqDOHeZANgfamDog/ghle/vpEFZtSZ" ..
	"xtal/ORUb9zNKT1iQB9+TH0MIAEXuzY3cDyIPXImdcxmt94WOT0OmSaIlBxehUji60Q6M1hEKWD7gtJALzzkdzuahesS1BXU6Cig" ..
	"BZpRTI+oZXfBHcxqaWS9NNl1W+dfDLBvtOsfIv/6rLMKEYH2Jk5pO06C+KKp+H+yDV93fMgCmVi9n8QoU5y8PzMVIxLSPSXohd3k" ..
	"Xjb5e/cRCvIdHzMeQAjVwZGti1bvzFfwBslcPWBo5Ut5I1St4zq3GEofk3newkKVheUu5ZFJUhrjdj0koz0psKzDJby11+0KSpYG" ..
	"zCc5QwIgsLE1iW5ThK9/L9pqyui6aa512WXejWhoyPUcKRBgrsp34/kPFwhQKGLyRjtEvITXR2bL9vKIP62E4zGrZYLQcsYwrR6d" ..
	"e5Sc6m4kl15rOXARofOWLLIAfI6u/Sjq1BINSUUJFBmU1Gpxg/FMN14svWNkOO3pEyiRUwe4mhnlENKbMMuCu74aBCgw54vrhfU9" ..
	"uzCaYXhhrJB896y1sLSiJOFL0czDt8q4Ds+HpIHhjXk7XlzJR10r7FsNBfawBAdntv9XEuD+VxNvVFPlSU3cjPJ9pfeNEE1seR1E" ..
	"YFbc9FgZFWN82fUjjitgN2fBMYkfHFQxWSG8zfawo3T7BtYiHnKBnvxFN10HMUoFTeAaMA3k7V7ktPW2hMfGKAKEqh1fbmlHdSUg" ..
	"VAxLbDz54IVcsugN38sFqPVSWXpiWdxAQ1ZULNpGt+rwrFn3ugS71RljiXGnnscBp+kB39J4GzbEPOjFVDIfzQZrK/2Z6BgIX61H" ..
	"cGYyPoile/2/nXY/+uZOWbx3oc15m4Z/3XUsBDIA4UnQ1lwGC+nDgYcUMNwZj4BcCCjd/+d8rHPNhNgbmhySV4IIESiK0Ak6RCHQ" ..
	"ZabVh3Xp94X02w2ebdU2rgmCW7Ag60kANeE5d+iowS1YE353OM3ddbtWFsn6NeEPfABuNYrtGikY5CtR+qBEJpG3/t/qSauZYzg0" ..
	"xifaFpeqKzxBNN6lwN92lclgf4TZ06bvT7FCdVApI/A1XzKszFsOpxNJnzN4PTRwZwD1o+NgwIorG63YrYM88n+JZv7SM4ONhXVj" ..
	"INYJrL0reI4vC4tGxC+kKTuuR1MEWPU5F8xHb5oSApXR+f/bt4PPLekJOo+hVHTL5BwJAk/s03EqCWa5GGM6GH35f22fsc5W+h0G" ..
	"hxWkklj55q/Xqu7HMQNOMBk4IXCz6o4Ggk1HxQR2p6G00wY1aYCZ0KIc9YYyGjKp1yLB85iPqVuwhEm9h9csqKQmpIrXz+8UZwu5" ..
	"uju9ik89gnfTQm37QLTUo+thZ3YXgpSJVt8ThhV9n96eGNlkzLIlIil/qtrG4poleXkYfHzzWUm9Qo9BO98/XfN8nqbykTpUhbXe" ..
	"KarY08R9NLAOph7//dwNzuxffcx1TvS4FvCthYkVPVzgSVCOLhwHRAh047EPIS3cUEj5ikGuES4Cmcv4CAuALv8jSgnHJcZ0VR1k" ..
	"s/cDnfq5R+D/N879iplBMOlVVy3XRDS2aTIRcdsyTs2rdum9iQlgTO4IFb5std3HwPXFxzISrk9MMLSsASwhSxMXyDUQ6TQKKoo5" ..
	"qAMUz+20J7v0A+BhB4tGXgv3wWPxxCVhUgK/0iT5HgqLsk3GvpNr9qQw49TQUtYaMV9l5srITbCIGadwfs5499oabiQIBwRk6lSm" ..
	"NAW8MXKyEjw1IPfGiLt+FOKoAkICbTOfcDWcHv+xYL/AANPi+VfxQYUQibqa+pahpbQGyGyXBAXTTZejvfaRz7Xci9pa47PDj8b1" ..
	"W5KJbM3TWjMEsbjIK7vJcGmdSBh4NAIkzGuvjVsoRoWQA+yXebfhI2cIf+YIto8URA8K6PHg6y5M2Bya5RJtcBk0WiP++scxmDUh" ..
	"DgGTtjdPiC60f6qGzDoC9V6a41k/rrlgamMLEcBnHZzg1RFnRzFz4mCWp6Jl1xsx05N5mQJtqm536xitV83uk0RrlqKxSnw4kSxd" ..
	"WhDlL5cr0JHHWtEWfAGZEhQR9vlGzHv7LEcLlpVnQjfL8N28evp9T6U/IXuIY5adB78bEyh7ipxKXwPAcpTtLRGI/vB+Um0qyrqb" ..
	"i8KuCVz/KpTZ7GrjkP5Ca+GTbUUhd4JCIfxb4XKDSATCcG8fnkXtdiLZboZweySZTxpHyO1aecqhJBBGL0jkMRrLfRZdyMLCh77Y" ..
	"wnXAnAHEuopvNC9S/Okk/Vr4NjLxqfmVyYMMZnohVYk+kBJ6TGNNGkC4pBYkQFo0SalZSCX5Ro5luraWQKDTYPee4gxmvKhfanSD" ..
	"LZHPrx//8a/S1Z8T11U7kfvR9M43QuyVDTn5CsmmqJfQ5z6q+Qr8zJwaxHozrCr4t/fYUoSjv559R8J1if38bOQ1g3kqzo2Io5/7" ..
	"shDciteYtqZbwpkfo+jVG246JLIJm8FRpazJtgSgD4hv3UFyGarYXz6LpnPQJQZ38Eafv9jQjn85aqQnl7oQNk1vzQHG1uO0IZaB" ..
	"PfJbYRnArdSNQRSIU+06xsNETczK5UDIHzT8s0p3c6+wxYXuey/VTkM5KPY2nMMAgMTqZv1lOxlagSPyCYn5Hd45ihJbh1xGhs9q" ..
	"o8JPil8QXfFByUN0li93fb9tS0sMKMFvqbybbtTfnfbjI5DH773uiNzet040kjPOwhmCY9J0mFtbjiEuGVlBaFMoXt6OR5PTezg7" ..
	"TcoDH6avI35lbynVB8uK6Cp96/azPC1xSV4wFysAhmaOha18DfFdou3CIVBMErCOOdbNMgFHaH0wVq9j23eQ1iJ5zOGLi0jb8WT+" ..
	"4GYH4+Zm85gCDX1zOhfFRhsZNHQ1fAlFmkpfODo0PkOBpFBHMzVWI66U3L9cbImojIDFFEeYW9X2AwxtZQ4Zq6B1Nh6LbC22S+I9" ..
	"V0s8CO/f3+9dezE+l+Yf4AblC0Ahs0mv6kbJMrdByqxY5vP/ok6uBwUKM6J8fwt9Rj3F+2mYQPOfi9hWznko6khwjMGIDHe8aK3z" ..
	"+jIcvvScJvxdoSWlRvPLDQHzW7nos9eaGw1CfWccUc+Qv+3AKpiPUVQvTYxMiGfzemnexMPAC8JZCv6O+6AkP7MuSf+oSbnW1I4k" ..
	"Lm7cZwYDRZIzKUmiB2axYSdZbimFFboXS7kvazWrYAoukyQaYt5T7gagW117H3QzaaepfdtEHfjsWrphU8TrMH4t2wvC+F/2bPuG" ..
	"02BkLYNgZ8QBpdwrAT99Hy3kKeqNzy9wMiK894CCqF0yqmMMeqNvv+E6NwlXjUU/xs5pRkCSMKI+5alAyPugr00ayI9ReSj4hKFu" ..
	""
local PAYLOAD_P4 =
	"6OO7CqsnBgWW6xoUJR0kBWrW13moWS60RhDn8eazLDmAluvMorQP7Jfkx3B9lx4e43MZ3tjcmZyCkXXKfLHfbKxmBKWn+idTRk1D" ..
	"qaEH3fe6tF40Ar51cEdmVHRgM21sm/kPfWnYnQM4p6bJWjKZVKILdbC8JVo3pKwj2uZOO44szwTFEMeykhItG9DkqFKDbGDLqewa" ..
	"kTHqeM7o7HAPbKD8S3ubx725NGBF8Um9SLJ4+4bmnwRDcmrd6IQOsNJB5gJH6MsOVYbobul7GqAlUWTqI60t31YjHtazc43UGiRQ" ..
	"cUaLabSrY3au5ZPdzpK4yYSQomqtjfMeSXapty7VzGb7jiDccB5pHuC6u8+Hc2PAu1/mXB+ww5EiOAOXDvOgt/iYdPGRqNgwpodx" ..
	"xN9HBXFfsjilLR7Prz1XLO/RYKfzyuZ/YHC9Et5ZmtMLAGX7ou6ZuY/H1c3cnEZq/4aDmTLUDrd3icVpnfDANDM0gNEJPivKhITZ" ..
	"hiCoyaC/hedj5oxYFkMbdESnSZvirt//Dhms9IMn9IjNRqOuNXohWwYWbNBycPv+mp/M4nsFZ9tbezEX78MuaC1pMUGTFhBXqI1A" ..
	"Vj9dCpsvyiJd4ZVfR/mmiOfK2aqlwvFF3Ggm5ijPWoqKODuKRK06QsoP3YpHfXFz9uZIu/HOczLzEw3PwvfElt+buoIatx/Ki73i" ..
	"XMZOTWa/NLroAwvv5Zki8AShoi8IZZ8ksUslDDVLvUiso07aEBHsK45fJ0jZt/NTc21BuvUbPigveiZHKQJcroGjqvZK1qHvWyUx" ..
	"1A0pwgShKAs8GMZrLV6TOYSj5hc+WQE5HUttUkee6ow0zX6FSH1UiePUzhTYkeJr4qAwu+8Q6M4cNovWkSfniVgVsHMEFmoTfcLp" ..
	"LXZVa7nxUQM0HdEtA66HT3q/flQD70s9wq/BaVl7Xio+yV6uA9WWck+mf4rUAxadb0jl2AEqMH8XIsjaKLHR1455VBNOZeV6spT5" ..
	"cUTXj3QbRm2UskxHZJKzP9PBie5mE63Iyf72soEXh/JgQ77z5tXVE7rGX9Z1my2zmtVWZcBXvqrQsDw4XCH0LzEReJBXpi7jwolz" ..
	"9YeK8FNqRx8zOIQ/VdeQoG0tUTIlzzqqzSJJ9nxfqEtTK8Aug/bnd8HdMKSGH/EIVJOqxc7bm6RDyoHX7GxUsU6mtk/vunoQnm34" ..
	"g6330m2Mq583w/YEHZa1Pm+LEET0tlOcWYkyjmSwhwW11rBcxPhNxU2081U+YKaBLyEhO0Gxr0mgsROiyeJAbvIdvGZ3ra6xXnVs" ..
	"DiWX7RgFWBIz+RsdDVzJjv2DwBNtODd592e96BpmOHWG5q6rfbY1SX4y7Pb8XIkboV6VnGqvoL6zqzErDSIEzpX4woR+Q6CNX7kp" ..
	"IS165DTFEKRT3+pYQq7MVC2IuL6y4W8fTgFUhU9cY9LyCicMzjzxFKeIEmn/pTLoT+OTNlQiZctSCxt3zp0xojhg2O430U939kGi" ..
	"PAkeZzNwR8lCrP+Oi5hNXrMjp9XI+pM0nh2UlHaRET+NbDvX3A9OChkraImNvj4+fmJAC3oirH1r2xQ5IB/Ikp7MZax+i0KmUKqe" ..
	"tYNanvseceQwatnjQqUQ/65RrPAfH4IR06yyg/RsmyQmADryxJz66NXNHd9ndSfLvoBPDoRPVOxnJQL6Gmw86dpzXq51O+a1a3na" ..
	"6uyM5b+fQIkJPMQ4QSTb75R1LzOGW0zxI85zu50nFoB9LFbrOML/gK1oTGE5yWQu+suibE/tqWya9vWn4I/hwl3monYP4i1mJpsv" ..
	"3DtimE0YlhVVdR4YAL2gJ1cJnzacEgK9iSDm7RwPBvMOjcEoX5Io0fxc3N69hkPGUZ1j0ApeH3PkNW0yqnNpSN7n8e8Jc8hxiss/" ..
	"da8V1RPkkIg1tC7N+6wGKLyN1yoOkffYk3euR/Jam+fEDieFfVUsE9Cuq6nVdILY/n4zVTAzi+QHPLRuHip0Ah9elrHt5T6MpxIh" ..
	"f2sqN01/Ej+dX1CTlraT4bgL0KmlufWmfAPKrDiCKLlVvk8xDp/iIoUEpa5hLC5D16OIkVyrZsFoJ5pB2Egg/OBc0DTezV5Pm0qD" ..
	"ev6ptGSYi/NQfR3Q22uUQkEybgF7I2CMUaEtv9nYjQO+Y5JcSGn7Fu4++n6tREEf5OlunlP80f8bh8Nst42UDO+/B5l9gxkVQIj9" ..
	"9OE7MCXQdhnXs4l5GUlccK2R4mFM/TOZkNYFaALbShTp3/JcMlIePorjiVGZ4sFKfF0iIyMcuL1u7kg3Ctgipo+kGEDvNcHUL5pa" ..
	"WMq1JzHhzpn8F3/tNwuSDAmrDW5kYxNY8Ef5hiVHvyzaAVMhnZllcdh96Oo+tW4Ey/O0yfr7zMqQAY3LASDFR3nq7u7IGjD0YFo0" ..
	"qxmioqbFeJaIyi4eE1LsAYNmFCAtuefOlNf+U+Dh5X5yWSYoaP7FUCqwF4lw7FNx/mGSO4EKsW5ZrUqs/s9XyHdQLk8r5ABfm/8E" ..
	"V2mhAZaXbp94jL0/EAgreuulUQrWxLZCV+A0QPXhrw8mYXCgijiBXfgBMUKxuF3nGE+DlccefUoGetU0wlWgje1dnkhGqcvfrZVo" ..
	"blyT+Q5OAcKvY8JHm84yPueazqDBkjr+pl2P5Ax8a8uWgT5h9IiS9amIb5ofLdPFonaBkPjkp8dsxpye3kURE+ebRSPNwh4gVLbX" ..
	"XUktA9QXnjJlB4gWnZ0fWCDQDKF1/GGl7PDLb6WPeDoHyyvnNPerLnnlVojNLrmNBUiaT2cHDvEkZ4HfvRi6w++aBI59wXnxtmYn" ..
	"RzEIvOm0d5uvjOf+VNUvPKiGsz5rh4p8B6wakaZhAjcIFQZliGfeGzZe0mmpDponQ889B6DMYdffZTOZWGKzz9i+PDTWGo7eQGu4" ..
	"1KaUY2opFbhKgaDCePUIF0WZM2Qmxro5CowPvjYXqdlEpd4VgI/wFHHKoduhvJnVdRm1WBWxwWgKYjOg7hRvkSZIWrI4R9zTHN8B" ..
	"9aW8Zpf77cL0ITNOE1jldg5IABcETvkEj1HgTlYk4t+QqpIWhr2NeBqgqS6TeKtNiokSzb3cIDCYgaTPBthi8UlOAXZoz3tNaoB+" ..
	"OnmuH6lJDsKYy8WSrZHRRzfSpkM5V1La4TeBMx6Sm9ck1/UaBqQdGgDLlDfe6GGMkQNKk6a90oIHgLfpwJNAR5saNPg/Lm6Z0vx4" ..
	"OVkdtJnxWnIzSbkrxkzjiQRce6xKv1l7/8A3hvtk9KbMzNCclW9G5zUmxmHiZqz35pGa5s+C6OkQp8cVp6eXhTFmXCNrqIe6AKZX" ..
	"SY3jZFpJcjYW9owiJjuwKPX3skg8DLNwLY3KYhFgSCpQ9xJaJg17S9XW7aX/fTvyAHV098vsp6iD4mKUzd+gqI2AiomT7SZGthLA" ..
	"BX7EjzuXgOYhN7zQcf/Mgfo2LipYlAA/Skg23WX5JuY9vFQh24BB3rWk+LGpGBzImZTasvGKHO1zOLl8cZYSX73wMKh3SkNf+Qsv" ..
	"WZj4WnKl4HeVmIKqoJ3jQ2PiwcExsVh3XLUaF6GHubuhpXuHE6lCCxXfiFc9mvUdX5qHjRyEvPy7z52FFY7Ih/swghmgLRLcKWpF" ..
	"nx9wIPIFoxr5OpLTbgTueuY0HSP54JJa7fB5XNU2bzHUqXcQZguoM9pi2YawHKpsYSptsoY42DRhDKxmP29oC6CY2PH6PmU8cvor" ..
	"NC2dDIe+hRhGxuTlTvEOU1H2Hs4ACDRYnr+qAE2gmG8sUHnnS3Z3exuSMAnduVBv6NkxBXXD7OiH36dozLTVzqCyiUlarE1WicnI" ..
	"RFIPxMYKtQdIEf6Jye9Ea5LiONidH5ckGo7Q+/aCxEwbr2WfCzRpmoz8DEUNhJh7U4EdN4ls8eLJsG/ybXsHowZs8sX0bN1mtQV1" ..
	"P0uiQFBtscfHw8MkvZHR2sL0ctDiCFOYlHxnLKXFhcfeI8dtmLodz1zOeLKEtRmxYMChJ00EtbmDOQ3P/1gDzJwjiI0P9q1PttFn" ..
	"k72NL5P0acesXtvqIhR2IkLfg3jm9HLyEYYZGelIgJGXMr7WEKFFH7YK0THCo8q7T9Eh1JmlqkYac+PpA4weUfUc80T0N1C11Th4" ..
	"nAActxjfhjPdWpfZWXWKrEXpoYrLn9hNq8hXyZNNQ+Pd6IGF/Fn6NqHDluJIa0070cMSdGlYt8WyQfEIIfKeJ0Clg4gPEhJgISpL" ..
	"51K1TO35GFJfdnyRZW/I7VGZqkgeoi8wTPYNiUn3CDYy/kOuRxJuuvIFkFDlbw+u6lTJVA5n11EV8z4akle+wwvgn3clJ7qwJ3t3" ..
	"NpY/ahWfiHt87NhHE5jQmaIqRqN5KMeomLNwJYdVb5r8REg5lfeNV/Temx0oHtUuG32b9hWfLalniwY6epXbNMojFCev1QsygqX4" ..
	"X7LKHrAESxWKZFzjQ5+CMzNG1U5sMR3kVdLoSjpJAeBxFDsN1a/C9e2Hcx6RQberRh6HU2KKcm5+X1a4x/Xu50l6IiyVG+9pl+vv" ..
	"DNhJc7SFg3k+bhgSC/VXQ+TDEic1Hr3SX/jFjgVPo81Lk3HnraSDE1oUyq3jLnAsvyIJl1MKVj0m1wddV7mRKEw73VpTfZQMfG9J" ..
	"D9+SAPJVZ8x9iyggtXB77KvZw92zCtbTU9nL4h62K+V7c+6BJ0jzcuPtO2V48hxFNIE4p0v8TaCepqSq1SC27LgDKmB1gc/OCnNW" ..
	"GVP/eUVPjmUlmPRzB0jsQhgKgZQv0Fy++XQhZzDjELh3G8mCTOFSl8IRfOocNJRzRhQf9DUJ98pFH+QosYuQ09244UmOLm72Y1+A" ..
	"ZwEXU1IV72G61JRdQhSMgYBPi/r50L41dprm5e2uAYnVKPwClzC8mLlD1FDiglWVbcD1dELhbuGGh+LG97Cx0foImhwgE0SsPe/9" ..
	"RjvhFPeI+j96+ulWB0tibawMbE+xuZ8g+HXbycORm5jqh8iZ7qZ92EIj5r6NVbh+6nmtgL6YCReOWXsQ+9JPExM6sFnLc4D5M7BH" ..
	"naZXQHa3rAy8/czRsksAhpFt6W+JsFiQpMQGrA98tLkNxUnjBm1lB27iLVMgE0fjiHXxoBVIpcWkwhFThcRDFgsVRlB4k37nwcUu" ..
	"aqYBuSEsoK3YxNyYDGI4hiWECz/AewKcJ317Pg0GeKRMPxLQGrRwy5moWhCU3mYP64S0jl1ctrYJ1fsAW761AAmJa8YMVhd+hkqk" ..
	"6iCKbCNlGuIPCEp8y46Do9KyIuTnjNHMGWHHsQgMuqWvjTYSlD3atWbkzSATaWtaY/BDjdlVZoAimY+lLRzZfnvFLwjmyH4F64yn" ..
	"gCV35szYhR4/sFkRcpacD2PM2MMttMzgDkwvW0siY5V0PL+dubKaxGihax61mtVsYwhlPFZqSpewYv7hQEVYaoTIEOo1pVn3f8Am" ..
	"RfN4gGa12ubG4xTck+vASAtvEgiRpthAzk5/1tfjHYn65K7/I0Ae706Mr0OqL+Xlgk86MDQyCNgjfXYNLwpcoCjVwUZlBoE/YYrl" ..
	"ktO5nYJqU3Hd5ZJSAqfwK+AqlkKax1uq+gYdZpY8k/IFaGG1gW1HgxEwdxUUO2uluQib4oHtCdOfMkrJ6ybxxZXa7xgeG3dqpJKE" ..
	"jqpgxKncKaamFWNq2ZX+41D5GHJwRz4m2knYYZYiqUAWyVVD7hAJhvDA3lBdBb2SoakcsCF4HeJgDvCvVCuRnvcW4fkdZg9LAwIG" ..
	"9q4NW/GetOVtn4ETXpRgBQiFzwjsGPMC+ZvooXS+1oFFCPsKgA407kXT//scdT3OW6D3IyEutxghHqFE5uoviWnXVjYRBA4c6nKt" ..
	"Wh8PYMm6cPy6bueTFX5+0eOQsg9PPPYHgeoiNNnCcb5y7MtcfK57ZJgEcv09EmH/Gz9k8nDZjZwoWLQTEUGteq4039fvXQE8bo+3" ..
	"sizd7yxpJ3smq5PKWtsYDLa535JVZEJvhIdhOVTq35w5oeTeZKmBtoTyBULw8spaaKax6SnwuqKpAIu+rDhPszuEKukzpgYB/x1E" ..
	""
local PAYLOAD_P5 =
	"1cpfjkMRgxwkfEFXGHHWumw25A0ya6S/L7PuyiRVa6y9YZFvHEwDuvNLiLd8lIbEwdo/czwjf9xM7UZROhYITUoDLeaEPIZgRn+8" ..
	"Nq8x9eIag9DycFQLApp3AeMszlIwXXJMqfLzvFBmu/FnNiObu/LotkOnLHDYGBM7jkwp/VbxqCwwCSLxGih7JDPmLbNT5CzoUW6v" ..
	"KDszHJ/EeJdL9eVxY6Q2YbcQFyR2ZnLg713ljryKFwWbujyQv11r+N7pD2DGkmo/M6zH90060lE3erFHnYC/4c7rdWyPm0K5IXW1" ..
	"yAxm6rAdaTxsJnJEt4Gi7rpjJiOyl3EDEIWAWfCd9oTMY/oCdWFgJ6jHKR6MI68alnKtb0l7ZcakWAEPf7UH9EJzWZC4+JELWr4b" ..
	"aBTsylHYVWPxqxNSnkysO/sK6WicursHLvpSiC+HKwK3wXaXVv3Ag2tPB1W0fA68YW9Fwhe7nJdCqgoAFb4SVasXQvL1qQQ9R9q2" ..
	"0Hapf2iFywhUJIdK7xhMuoo5m2Z2H9XUw7k8OP/VjQsJkE6Fa+RS4pCE82mWDqk2tYMLEH9aodbAL9ZNOlDQwYbvldFcd16jaM36" ..
	"5wA1o0XU1+a0jNFq4qMCTMR7aiGWdRsZb2ULoaFD801nTMlMUHJLp6Ig7e7ipNI2+9ZgbkuRzGTZiOt+GVmsYPBdPGqP80AVNiFn" ..
	"3CCZaLukiSXMZryocPDRWFDXeIW5Iwv8hWqvH7B8qw1uw5AcNbHziL63WsQOuLgiaMkG+NuLjViSj+RHMRop8D47eFDyWi3gqZKK" ..
	"SNvxgZqrK7H5j4Q1T4nKHslVPyUbpUvgVBS19bN5w0uF0cViiHcI0gFizHBL/zA/q4fansV5MJbyEsNMVqc1T6qHfei8iz/MHtvS" ..
	"1pRLTizl4Dv1yZFtR6Jif1amVCebH8BLj7XbV6lTzC/mbUqHrUfLCXfyz5CNlzPW6kOCPKhadkwfqHGnY4PVMivbkdi8izZJ4AxQ" ..
	"8nj47o0yewsTdfMxfGcgUD8QqiBmw90uEJfeXTj8EJGAYaRyGs/fcAToCtJOGCwi5DFnUVaMmB6DUQBScgWUlwGW13LPBNlVlqU0" ..
	"uF/z8i6CSD2HJiJXP8tvqQyoCewFffHDXhyT3dVJjcMwm0MIdKUD0towvOWEDE6mlc5pFjz1b0RgCKlDmKk7+8kmo8MuhVa7mGSM" ..
	"y0BRSw2Rj3Sm2vqYRLhm4yX33126npeuR/jDMa1BC+8gU770yLmyfJJ0NfB1nQy5ypy/ro/Mo8+oBmRpevSbzOK8aCEQ91eT40BA" ..
	"+JvGDYox5WX79UBX6fBuZS/PoeT0y69j80wP+za/G2QOK41H8Vpp/avJPt7Jgcby/M658W9LYoFWoLpt5lfnmg3Gpb9ZI58bg59o" ..
	"5w+KxMeZpWKrZLeL82/WOjdM3CXdkG2SGm9e+qHcPsN8HQBHwJpzlAGLptsSuE7asW7RfasHIDr5lTe3x9INLCBz2B0e28n4BuD7" ..
	"27xTTRJjjTMr9NFt5MoTkGwsqNDRxEFFgyoCmR9WS7suu910B6v5LevNnwgwSFy/JD8kTwxYhNySZLeqSzHgn7cTXXBHwFlVg9iU" ..
	"VO23+RMquQEwIsA9o38VsBi9iTon0GZprRE4XSG04tyircY/Gf7KAz7T7I9yz/IglUcSWcCBobNSb+FzoNKlKydDrabisu4QUVAP" ..
	"5dXGoi394WXMjGWOjjNHXPEIHTj7goW+jx5/DkeeFrkob2kREEwIPQIOGRZIcVbv0FzjWmj3WVPZ490qdR+50MNZW44wzqn5cum8" ..
	"vDbUp37L7wNMQ8gXFDn3wBC7vBmlYEchGtu4AXmpu+h9gpM9jAAZ4ovjksgIVQ5sD/YFYbFqlKMryEYuGKA4DYrbhY3m892If/rx" ..
	"Rc4AxSynX4GTaTBpTRMs2Py33G2yIU3fLEEBa9ujX8N6SLu3AdXkrMKIe8HgzZYC4LS+B6+y8SBpE/f9YeZv2O5xdHMIdCfuybRN" ..
	"pz1mZl7aHFc8NJgG6D1AeRSnxTz033PM+4TJ4vbw/T6wDZNY0zNXFqNz0mEb12KrMVuBjIxIeO8KwcGL46Ymu7CA1frwlB36tsnZ" ..
	"ooBbxf+kaAb47o+f73bBnRDzLGOSX24zroK2ZtQZZZzLMxUzAPEi3MfGuUX7nGhAvtFQRQhQter+/FF/zwpQVjXfdL8t7KCHI5nR" ..
	"mEN+piKcMyaKPZ9HbRpgp3cmLYKNGUelk3mcBe7pn/+3s6WpwCjo3lYjKmYhlX6obaUfI7yOIIGS+45s081dHnykAiWbf5KLLBgn" ..
	"SveOCLCs6F79zQJ06F5ycwZLvTLcZAL/e6klIsrBSaLXuqqZkdGC3pVIkYcPTxj1n5qoqyyQZ32AcTbHqUvse6jFG04ctKMe4lBJ" ..
	"vinOyx5mPtXJvfnzTRbdQnoUDp3JDkwXB4WU7qPdSNU/1fuoJXGJPssmsvx7Mmk1ejcPmqo8qwbPaA8Kt03lekILRz2yfG7EnTE7" ..
	"gQZAkE97hy7blU4DY+iLNipCQlzRKUZca1nwnT/oJSEOZmYlueUr17DmuMQ6E4ec0jFABUy1VOm7YAcmhftJ2qKsWdT8bS/9lucY" ..
	"qlG9mcp/duWLwO4bqYKYY59PBchrtVrtLbmcZx8cupD2+hG1P4WHPeLKzsmvjwBVsXAz6UKYfjYohPQUgwyiZCNpzDtrlALOcVEY" ..
	"bCFTXKiL1JXMZrXtREgUT2bLkkRlAv84pQsQWfu8cvoWQk8e0fs94fVNo0gDYnA8haH+IbAJP0HCsx3VmmM6ct7aZbi3d7/StI35" ..
	"QXJJmT7aiMbyPmYJk3cjRv2RWAx/BZGv5IeSKsiZmvyPhfbM6ekn5TBFtGeuv0NQH++/7z2+y1KT9OyHde1+KK3gxZLSQUsLZ7x3" ..
	"njDTomxHEs/T0cddPtyI7Bw+lwL89P+gDejUlIR/qYiq0j6ynS2GO05XK/9pAgOfxrPLvCM6lUp41d+wk82IsjZF/ATp4bxBpqtG" ..
	"06oUq+ZhPzj/lCgyAYvp6huZWVOxYU7sqLlc5tbQBAIu2G74isa1MbsCtIeydSji5PUB3nhU7mIVC+E67MZvrzCMhdGCWhFu8/OG" ..
	"jq1bdgl0A/IV3nKCTIzlrNVLbIgJ40gfjnJbUipZO6RmH1HRf3b+kfHcSREs4a9JyuUQLuUKAK/i9Nc5OpFy5rPyBoQLeDYOvcuP" ..
	"97CrT0dcmNJAN11vNY0WB4tNXuae8PphJCvbiBHwPTktOsOiUMOb+xzg8QULcZ6bI4v/jV3h1P4wW0ru/dXWp9nUq3CchF13ZTDu" ..
	"dXrAS68MkIbn321Qq+eat/MRr3bOLZ7R+mMAYZy+OYb4rumq0mrAb6fiGaavjNDaVOI00dLRrgHSvvEsJDyMqLvX7N+2NBHAF3Go" ..
	"YVaeWe87rvns5vvitZH2EDt2qoo40dsDT294lBpMC+oCIIlLQD4uEgTYJKly2pUE6W1ffyOSW3i9/UP43MlqAP4/M41Vc2nM/rJl" ..
	"5A96gpHbGMp5xXTsyxmJqJPttlWyRB1eMAqXf5W4MHmirmYVAo1qB+0G9cxX/XpkwT12b9Atgn1AC/l+apYrxTTtlWam93MJfEVs" ..
	"ilOdrzzKzLc89MeZ7JyEBKnKTL4T6xoovWdBbzq7KnPH9FEw8pcRr46F1jKSHxhCIFYsS5kmErUpUAK2KgSV/v4f92exrHFL6yI4" ..
	"b8+j62WUHlkwU0xR09hak1f3/qgkc9sFjzzNIp0BZtZu40Ac15x04TaaAnyIJIxHpcAFf1rW+oiYBQQ85imD5nWsysaBqnAn0vSR" ..
	"IdZYnaOt0IBu25kJMQNqGClxscxIysMJgUu/AypJsn7ywJN98fFR+Sr5cdMiRfPZVbraU/adSU5+CAudAN0im2VRz+vgWzrdUbjh" ..
	"2N2rKExf/9HqFds6ohz9jzq3T777leVqzEqx5B2UOmM3OOFWjQZUaYDry1zdHHFX5hatO0QC7s0qIysFyXx90G4q/K+xVFvXQl84" ..
	"QJgv3ZgwwCIz8Pmgcke/bDTCkvwdy5C0FXk7vNkWPx34BVH3hKYUXjzedyU3nNlSJnt3GuKQxFlAU/L+cHdlF/zetNdE7Wy7QZSW" ..
	"zoApDanM5HhT4BkjKUGwlaivG50C72iwphfwDViLYQhn/IDy3DxxY/wwGaEq3joVyhAMo5EE4GsLTOgZOn8HpGrSnvhR/BMe9ZTX" ..
	"BcJv9uaKl7/yumF3iU4U67nGxwuIntGKjU4KGmRcCvf8VZRVDq/xz2v5g0CkBvW6kqgKJ274XpE3a5IVh2X9xNDEm8roaF6mmxCK" ..
	"S8cISAHxfZUgzM5RrbovqLYpRVSQGuVOLM/HxAcFrPu58lI7SmGkuPp0z17t7oiQ4p4D9MSWvaDkW3TDXI6E9G+jXV6FORbKu5tL" ..
	"cpOzIoWncWAA4OnhOOThPWsytdd2fyTJo8FzYJ2sHufk0gWzYUgwWmn0z0mPFd8W5DE/yGhF4p20yxiBLmC3qjRBHs3ErSAB1cjr" ..
	"P6xn6GLQYezz8htUJi4HbwAXNU8tpAEkg1jXYfM90kpapmsSDuasgoaYiq1UqEI54beiREGe+VLEmZOVi4YVFczsTluDAVEGd8j0" ..
	"78RwbDP6AyEBooUwFCl4uKAFQf5ZGZsKCKXz7SlgF1ZNIvY1JucD0Epv3zpFGIIo94qZ2jPGUXc+9BRhBVqiXoQ4lu++ZXUd43y2" ..
	"AB5bAWFvlALv1Af8qGgv7BfbVQRRCgrYitHDwvwp+o9DzlHzgaxO/bgWFqpPg/l3nqzCmPc62Eh5135p4mc8SMHM1fRZxS9xWHl+" ..
	"eLnv+TSZ2OZOGtiJybvAoJK3GeE7l7tvZ6T89ZEKiipFFPPydcyvpIy4qGWkjkz+p1abCi6Q6nW4krbRiHTHh7Ch0eKz5kwsECQw" ..
	"ErXYDotrhGMOT8K485KsV1YHFlF8WwqwqtLzQ7Z9higqSaTGdU1t66+QmszDEZB5UzexgEV3aUvMLe0LrOvDHzJQBa5Fsf4/yfEN" ..
	"lKmOUw+fcoWiwq3N8LVqqgT76nKyMXlP8tA098VW7ChoKct3mLhtOrPsHT4k38vUpFrIGszXmaY55/TiyXwpnHF0sBObo6FBKI+P" ..
	"t+UDNHfv+sh8RjtDifhfNBC8B47dLZr6KfRCQ/uEVSiwtrqTi2W52lyoKH4JsT9bYooHe5jzn8bcPWALbSNB2B/gRFMTd7eDwaUJ" ..
	"3II6P92LY1cHme4LLqTPnPDz1kAc1Gb6voWXyXtEpQqcAUJOem6Hu0NCLO0PaYXywu4q5PiIcn/pS/8Mv1ZrasfJPHflOGxaVD64" ..
	"AABQGSvVelexTpQSbmNIqsMHTFmihlGrJ8RCfpvrYQpki6WJgordlkgpUZrIBkjktIsnqyGRGgMsMPfqaCX5StnhgnjjQ36bwHCp" ..
	"O+Jz2rWa3uEVJNMoXsx6bBplM0mGOcngkttKHjS6mXEi48z/tW6Fg0srwgjtt2WFjL1EGXs4S7szRVTTW4YnjujMFkRA7+Y3QWG7" ..
	"Uhim8Dcgdfynjv7sKF4ql7dqKNCuqORoYCAA6/0HN5jHLX3FYyUcRBkBZ5EBbONjaMCscD6eaCHf72YTPu0SU7odqpsldJ6oZpj8" ..
	"8nUH9z/I20gsCyYzGQFm3F1Ci/rh4uMB4tG0UpByGaeyXQF5K/n3BSK0rwuYyF8cUMOj6q8sWyM85bMm83ikxrp6jsr62q5iW9Nq" ..
	"YyO7KM35lD+Vg46tMTo/J5r03pi9JmiKT7BKtUu2B8By7DyhVjnPpgiWr0WgCWr16uZJhl0wOUAq3H6IJqgEJMhM4gmRdOEFH2R7" ..
	"b3wr4Y1rgz6v8qjpscSeimg29GkFOsyjHqcmHqTc2i7FLS9L1eyOA8y5jBCFiO/azdmMeqs7g8N6X5kBSldYGhW/9HpGGn6k25Ju" ..
	"7OkMUwrtESMPEmLzBuArzs12GEKnsD7U/yU+UNDUHnVVircNAvOd+/baJgKoQRUxXHfM8QaWk+YuZpm4+AVtQd8rLHGr+gF2XROY" ..
	""
local PAYLOAD_P6 =
	"6HGghMTert0lOSQmqr1kaerMUhc1t1RbbwmBc7mWVrh8wzUV+0clFCaTN7A8FXVlJ0MI1Ky6mLb3JYbZDH5UlhemazcO10aHEfxK" ..
	"JIK/aah0Vcoq73+ZHAMf2xTy04/QHFsXpZ8rSPY26AUYZcXYja07DepLx6fjIRh+OuXB3d78k0xymSQICzrUCr9f8LmnOnMvOzRg" ..
	"MKy/9rd1o9pLR118WhH5tRgYiyIzttInB/CcyPBfWHcqpbDM/e7ktled3N1+haScHjmpsapRmX6g26mH6VX8v7zWbCiRfIAdrFzM" ..
	"NOkeurIAxmYNMUdSHQTSaH+WhoVXWEM9jaMK/wlkJHvXDT+HSV7fitbApgjTbXHvIgPQI/OYNfB+XxR6QROjEwNP/cbMvBjB71mJ" ..
	"zSQjTjeZgtuxG6ILg27a67RWndRWDSVey7Mu1TrqfLpyYayTksoesNzYCpXJVNFL4/bI7dAxySLtI39SEBQENs0lNmfJnJcnPBrI" ..
	"HYbe74BMuZts0yQtH4Yk7kM4fqZTCDTWbEF3hFvThOn6qAvHZShLodoTzFli+W0EMyyiBUkZQozc0HEhEoh/NyZ3e1IZzL4ufQUG" ..
	"N1PeNUsqpHXwvIORQfRZ9rism7Li3AKv95ciFusKWel7+72BRU6wbNARiT9/Ks44ZA2RtKuRcyYVBaGGMxwsHSNQg1VHX+fxdv3H" ..
	"X3qLlFn6zXsFJCjF0KKfaUIpem9rSnW4zhawFmqj8BBUYeofx3Du42qpkEwL2S7O55R5DXNsO4qaESBrXOes8TZXcwOmLGV8zBRz" ..
	"dsWA5aMtCjZbHv2WSEeHkt+ZNf54tcic365tQs7XlQqvpSVoQY/WApkRctW3WRnsAcPq6DMc0SlrfYqR/op1ijmIil7ujJ5I4Wqm" ..
	"fbDziIBgw3FBU7uyPKKwH3pNX4cV0pOcleCyT+HJviB7r2WP7iJgt8ZGxQDsdlPhUE29sf+i4ju5j8Pj6JeuV7Un6GjVyNOZOqyM" ..
	"/dLhodTyMZG9VV97cyAWxf3cb69VNJAFlIXwYTinJ/J/PKYuRq83g/iBiEL7ML5md5B/uQZE7BukdYI7nHGMgJ0w7pUZGb7ARgcu" ..
	"32BWcftgDODS1/DMhJ3oNkKnpRhPG2L0D7c//jF1FDSqQvhFqfcXFdWhCW5nJXGEZ6xJbRdxf7K2j2VdHWiw5EnTBTpkHHQsO/F1" ..
	"HZXihz0yLZi2c0D9Q+yQXKuA/H76IBe7jthNxApIRQ5nFHueiZOaTBMWLYMLXDaP8Nj7fjsW0dAXsuqe80bnMz2sXRdl4aXDdP5a" ..
	"DfIxF32vaue8LbTk9g3QkfDpjeyO2b3odVML+njtNReYHen+a50V5euZqfpe0YgPrXcNzHe3oUXm3aF94qMtUa0Ry/ulGj21oJqS" ..
	"NhI8CdgDkNKQmOmZ1C8A19ihlmjQKHR3Rzn78rKX9c+lkST53TO0d6sTH1aXWu/QeaGdRGX/rlJajCvwKwejIipjR0Cr+lQXQWfT" ..
	"q+fx6B3BpmKw0o/dB55fF/W1zZa9p0eqOb7/vp55kPhD8a7ToYu+47nyJgnPLJxek557f++wxGFtzSO8flcshGUAmpYW/RhoEHVU" ..
	"a36jM8Hu0e6KM8u37EYL3XlJDoHiKbpP6u02X6B/hVl4v0Dgpw1hkY02go9jLZswyZIwovf9x0ZENctxSvgDFSFpAHVZWSSBVvVT" ..
	"O+Xtethh8XdTEZQbVBeHnjP3CxS0hztUcthN1VMFDa8ejFjMQ7lZ2j84eFB7+8NnlT6DTGptzKjom7q8XDIdV2v5gLt++PQoWMlM" ..
	"JFzj7gajFcygKzGeDoIH8nTN1T4Z+/R2sJsmmHfILaJOowNdcu63nCW6m/9egdHngyn9qbVCukUIptFJ7P8JE6WdvG8rbqmBAkVd" ..
	"udmajrjkM/NL3pZ0yn2d+ifuLsK4QFmqmKlTd33PU4XdFx0rsoZdgFJbBGHfXPnkazz7LnkluhRzMvLjpaPcp5Tg4IeyQRPufIjx" ..
	"Bfl5UE6wEpmYeazX81rdoY0mwYYZ13Qp8TfXfNAfo4+qDpk8mEiNOEB3+1/lMaC2xgHQ+/vJXT+YzeJ/XS/HLjDHtvLZIyPup+V0" ..
	"NXEjohHeOHF9GgVcLdPRqZyS5n1IYn44luiPjwP4/P0Z7QONyATiob/b3htHlX1jkvjwoCMxgcRijZtx3TE+wOMWJ+b+VpDJd8Zc" ..
	"8XftgTSNZX2hkui39KJtjIBC25R/HLy0iU8RSIZa0hhrt2/B+CkLbFnOw0lCYsTwvR9073s3njWFf3woUIAItmCkUnp0xk7u2JsN" ..
	"O7Ovy4v8Zlzc16pbkkwtMaWpyW9gGd9orDeCJk0GA/fMtuDnojD0KRp+GGFAoPpfylDkEyHUgDkjZvmnQ4VYjNH3Vgva0xFZ6SgJ" ..
	"bU4c5b8jtHA4TVGrA6KagddDGtPMbtSIvRwF456w5vWbn2jBKpUpcCaiP/B05N2cvJZzH+gFXWFjMdmhffzl9hsrM16vhVJgon+E" ..
	"/4xwe0G1tNml3aF8B0zVfLbvAIsa7xHboPhywLeDWAYaFiDwR8b5hHPOjcc73PxXPc0gDqwk414GOUHiQl5D8vq4wjAWcS0nQk92" ..
	"VRC3Dk0Bkmlv/ztFQhNyIzRRJ2RvyBIpVTacQyNyrCjwCMkuT6pQko4uOko/r/Z64Pz+NqrHgrVFLiGCb0UmDjvzAW/txnk+3p3t" ..
	"0PeZArrGme9he8sBmLG+22dUF81F5rQFUUmixve5FtRpf6MtqB4wlbyLwYDLqYHwI9ApzZ9owRQTcs2GtxsOBqOwlVcvwdY0rG6K" ..
	"MO+2pC47gK7DVQGpiQTEMilCYK5iKeBHK/mf+/19bx3WptnD9kbJF5SmKe5NDZcTHUH8ctHCjMtZ3qcn2gxM06NlL8XVzuj8fxX2" ..
	"W/XDUG6BNK0YC8B78VJvIVIt5DfRhSxJA2CFgsRMEXgZ2sWYrMF+SxYT+UyjsUDNUjaET8mVLaw+MWgGiS6JYmxSES40+sHZLISW" ..
	"ySbpia9b8V0a8hAdVrXcjtpN1JPdJXHKAgTLgEQn/b9Op4uYovRpGw+SkCNP8/RNI7Mxqjto9Fya4fTNTY7HVjp8Oa+yjg5fmWHb" ..
	"9H3EudYFscHMryIF0rV8hWDgDAfiBrNprEUE1TA4xvTr3MMMDYfqUv02CE04x5k4Z9m+rUMaXckehNJxURz5Zpdd7NySGjowUn8Y" ..
	"jLT2nTQQaddirUw6VvEYfJKlejpy4tLBMPp6pLvgKRp+LJPndnY5/5+0NG+Z4otahECtAsQe+yov1oCWYBzs+7I1O7kh3RCPEQ6M" ..
	"uAYJrIEuI+OqQtuSw+XsX4X4cFVhKXYol7/ca9cGMiOkoV4lqeAE4yywljAsbGYg9/p9NQV6VyKr9eL8iQki7dsHMbJIK3fIzLHv" ..
	"VV9HL4Ympph04DwyExf2azEXLAOAF73H0Oseq2jv9oEFkOjvhhsUpCZ7MZytAA/kbe5Xjpn8jDB7SQHjA0r5OsyX60wfPfQOmc7L" ..
	"nATeB1FUdUS/wreoR8imxsQcHegNUgzS65DOvaTPkgauWiLvX8AhzVqd/5jSEw1ereksx0AcBjL6p1ebAUUWFgpzds5loR/03bEf" ..
	"6jtK8HMI6af0pIjnGnqlmZl/0SeU7EP53eUBvBt/wsMqph//RylMV63X1etrI3glPcv8jE7SouUs2BwyvndWvdZ6zt2lsKxuLlHI" ..
	"WzoiTs68kx+RHu8nwi9c2Qn+0+PXZIB6XMo2o0mbaM9ybeTGRrI7zhUaOcqCp+omKsTN6Hi4/SxyW/gfRLom4MP/FybFLK2PyLSX" ..
	"Ql43s5M7KF5zCNrfOoeSN2CYXc25U0adJkEMjlqtw+ONgPS9VKHVPLQG0y6vjwaF6xfkc7JTx9JxiGVOY1pbxnz/L7uesJq56FDW" ..
	"/3NPmQX6hP25FZJrXZOfzdN7//M3+yEbvSuC69J99pYTqO9PWz1zkmkDwo+aM8xPnYfloqeN74/pjxF2ikWDhXP2hDkNB0CkH9E1" ..
	"wlKXrsWVOzB3ek8rtpH87xeFCcU0j0VIxRhy0NbGwdpP62WP6VCb+M4RsuHq1kV+rY2nws3YwkLU36aIWkvPGEa4fUqg+C7DUfWw" ..
	"IJ8wZ7H7Mt5d87gxVqZASnAAfKhF/SqIHrr18EdD6Cm3+MiSw8nmGEKJuBtllPChoB7TqQFVZFl/9+bukSzlAfUvvoNUtNIb5ort" ..
	"sP6q2+gQIV+W+Pg/Q+hkY6p+UuYoJOABFu1F+SS5mJ/jgZTPSOMps9diLOZBsg0CsOpPhgDzfI+R4K92UOJJ90+4H4If/q6JOAF0" ..
	"eLMg6rBihA90ODufsKa5tGQBinAoXHmEYEG+3KCH6sg1qj4+SCBnMk01wSRpeSMxp6r4GDzYgPz+TrchU0FjSINQqidnFHjwK3Sf" ..
	"3ybmsiXovFlZop8KN7cwq0XwckehqM8yAwObK+tEourl9q5EWRSojBy4POZ3XGYNwAI37DW/F34hMEnjYpgc0PnszEFMb919Mpr2" ..
	"SHMdu94zQ29IU6P2zRlpIBEJLPxOTvZ/YH/TDy78VBvcjdj3MFp9SbhQrWH1h7f5E0/0Q9OynolWNDAAyD14gE2jVbIaD8Rxon3E" ..
	"p8qw9hPe5dVzA4hldUZA/pnj9ABWgRswajfkFlL9NMi1AYQu2vbWxqHMn7Y7Zk0j3oA8vAR7XRvovpKbKLQ7J5khLo55h/dOM1iL" ..
	"MqzTvW5Iz+NqtR70PwR/0DxD0ywVT2+Ai8cmKrKO+UgOc9XtSBOTDG8U0fnf/ucIEykrXS8PzRjnp8lDeziYeigzjweCGa+1d+98" ..
	"dKhXYye3b1K079gt6gRLoHl7vnSdl414kkdWYl/WIQ/u3l3Mnm3pxoP+t6U9pOczYhcf7cVG44sqaqVxZLER4EQfX+1K9FQ3UVFc" ..
	"eyZcPkBXlBY21KRByBP2C/eehSMdf4HPEC4UplNdYyIHSw4Gh01qy2f6gno5tcRkN5NPYA1U7vfva/HUXQbMvjPZw009+KU34+tU" ..
	"HGuvH779me/iFlM+9zWn9FbblAtOfGNxa5fYCreHRUzHot1fPJPgISjMrK15YaFI4+6/ZSg7sCSwqUfJDkb7DfD7VABGpk4Me4+H" ..
	"soXAvoWKdVr9ux17EroPWk8WVV0r63cMuM4yG3blE67lGnf9lsLPsG+MQ0RtwpwkXVazEPG8DSfSMlRPJ1tg9LgrejSdG68HfDbv" ..
	"Cz7mVA8KcGzNk2idhD2eNatfj6tiMR4upd/N5kK4TWkYgOtlPTb8iQAFNARTFURLCqpqIsjeyyUslY92CqpKDHPSvgrxTNeW/AVZ" ..
	"wziiL6LL8S3nzeqNVtcW96kHHfxjf0yKpUtcwSvetJvLFwWXFJS/TDLTft3fBL5jgEMI0qTtIW1LLF+IOYx3Z9dl04JN+eqbzrgT" ..
	"cvhWVN9yhmw9+bUR43QlC2Z1UlVBoUpTtg3saRTP+nCOpYZPcC3T+gTnTTrIG2qWqn3IAzOpYpLI28L17A84bBgsYhGIIMZ86ELm" ..
	"l6AcRlyRTPXE6V7tMfHZKOcWkvTwRApZ6edVWs6bpOtaLN9+jv2/f9Xt9AZhVkGi/v+CDmUmYqKGdSjJrtpNZmG5Tbl41VKRRcig" ..
	"TvWNiXS7khiETPmEFhFyPmeVcXJZzFUdUMw9fWFNAUGfJdS8r/kZh9OZGgkIFa1pKPvy5I+HbIZAZpxpvofK14Teej6+zYAmaUMs" ..
	"+0LhjGfsAsbwQWbyqGB+fIfYxweAcQxkJtfijnwI13qvL5OfdLLkLW84z3XJ6su5cmY2V2TjjU8Jb4C1miUKiHKD6XBNdtsqVHTK" ..
	"UMO3lGNtabzpTVNcieMXLDPSQxeNVlLmWDo2Q4DCPLMuirj2dWuirsee5tQOoTUBQQM1IloQ4KDyi4EOuSpBrGRC7/tqR77vY5qi" ..
	"5xjh9OTWXHz2QpbAy5NVlBhnO5TSKqvAcNG0C59OBDRq6oWd1UAaiVAvZ+bKUH6gQ/NXjsixxYRjr5FEQSz/xquOIt9gl9lJ5e+l" ..
	""
local PAYLOAD_P7 =
	"jrkzTQRaGp2KSW1OUGBJslMaEOrjkyueEphj0/0/WWzxbe6JOFR+upMqZkuLzw33wVBBYfOpZqhVVgXU+zDHL9igzw4j1XOQygyj" ..
	"xEbvJl5amd5TqNYfWjXi6AcujUSouhBUrvvGFFxpc14jYObLvfq5ooiYiNaOtSQro0a/t8dZp+BfJtlxWkuBj6+nAtnL0piHF53S" ..
	"PcOwB58GSBMRldmo3Uv5hdEDNmIBVeJD09MkptuG/NSYxBMzvfCULmL1t6iEqjC2E660eAQgAUTmUlpqp4bh+lZGXcDBjnCpj4R+" ..
	"GJBNYlXM5DOkc3io89UwWhB9uMcC+WxbnrGQgUmYl4UdCS1LCTHhCsF49wVRrhtAweJEThgxnjjwtcl7Mztm3TH/AdbRRHBio0PQ" ..
	"J9Vgjh/eji1f4EeylFZtuR0n1hMp8b5tagiYENvnoJDMu/147lehYHfYR/2OiUQocWCcjuS2IWU3bULZ4zSCczuY0AflmMQOebd1" ..
	"BBfxCmqPk++MW+R6MjZOpOSGfgcZa9fcmdWaDi9HKvwANbw5gIr79qmwM8TTZAT61F6AvtUL4DkEsCH//j33r0aejLfHIChTyVnt" ..
	"Zk8GZRy9cpbGBElfNaH/SN4i0fO7Ma4j4FyjhiNd/JUOX7MM1rRk2KOnVFKAjBtT7cUkS4Yvr0A/RLIlv6j+7dQacNG0IM45G9qT" ..
	"ZGx7Sb8z8EDFNhEV9gdHm2JjnIWWd52aLhmSBo9CALv2vfKJvcAKqJj5s641uxsZnSC5Ind/J5hPpIYkoB2da+7xv0U498QI2gL+" ..
	"I9wElSpCSZuosRdryLsImhHTJuezq7XluLTuPfIHKMqeW+FDGA753kESq/8FabqGIUf3ICZw45fFFOUsE57/uVaP/k6VwPYqaeJe" ..
	"S4MZ/jIliXzT1DVIm8mqo7ZEdJ8+pnvP2Yeh3UuLcVO9zbmzrSA4FtB5QbOsp7GaZOWX03MxipXAIC+V4t7O5ysexD2RCAE2oNqt" ..
	"i1zD8UespX8NOP44LCMBwAlLEXPVX5sej6A1R0cXopSDNwYe2rbPx8blvrnqUrUlkLpwZxDA3EU9DmAWcykwSiCMA+94UMkJLeF2" ..
	"G+pCvtVm/YwP5zog/icfzpm7uURK1A+0n3EPjcSxHPYDWFNFph3lXqNYJ08UgA/Cr6PfIty/dQHM1riYvC9I/VP6w6F6EzRRIGcl" ..
	"LwVbWgcrioR3NIkhWD+FCGej7Xj78J/XTfnOXJo9hXUJXIkXYXUkLc2hTQhyeIiHRXGgPehmEZEaSNH1AeqyBYymOHpsXu5fMz7g" ..
	"1OFjC8J0EoZGDWdxpCO6pJ+zQ0H3XXwuyRoawTG+F8n+9JJkXbb6YlhUwM4p0J4w0nMcbdjjZRpUb2YV4qdOK6T75jmoe9ZG4Soo" ..
	"yDqN71oHdyI//DkZv3n0l3XUJGw3CBrdDRNetU55gAaxguLniDAihUqvfZnq9B7j1wtARgUlY42ehcYQ9vSRGb5BKYXwZctq8iEB" ..
	"6KAx6dHS9wtcwQWcWnQBBad9tr8U5n+HL06Fw5XhvUkLvx9RVCcSmlEWFrFJIXu0l60+m6DcutUmBuSC3Qh+Xb+9tBX9Z8e6voLb" ..
	"DO5FmJ4xA43qAfqfzWI+gWPJP9bBAxp8Vs2xPodSguZcJ6tPfJDnOeVjDXcauS6l1wUnnQ+0Itu4iVn0WeqqLxtTbs0i4dgb4wKK" ..
	"ohdUjzyaDe6Zm5x87emofSens2u3AEXECJ54NO9C32seE2fGlpd5VAiMcfOW/9ymqI8+FnRsx6jolvXvEsWW5RA2X31lfO7oSmTw" ..
	"jj13NNNc9wbeJlfzINCxOT+MSfWvTJTy60zVOrNDYg1hFFDuNucPDgXyrdciC+aw2cL8OzbbhbYdPIqjSafm40tWm6NO4khZ01jq" ..
	"OsbHq89nnl0OTq2lQh/BiHMmAb20c0Agw9HQyL2OewgJqv8+0P+gi8+rBQ6H/h31E89y2mSAXPq6IKzW9l2mJznmMe+GRo6eMOxo" ..
	"tiU0Tpojg2vK60XlN4dg/etb812rMnPkFg0feLDbWv5+LNR4BONqjDJAT6WRb27rUgXAItXvlv381Mszg856eUhMMsFDTxTjdrcl" ..
	"W4RWn86Zw0DSFAyt0nB5SNZPB0Am+uUZ+8lWx/ExG9Yye5iCwcjFClST1C9TeaJujrSS8AfunQkf1lEcT4TUHaGy50WcMcvlBNFp" ..
	"gbNypssCd/WV3g3ZF6FIbUBJ/rZWG5rcHLY2jbCxdgI22fGh8LSBdYULkVtT2BOw+VqUrR9RJw9g2Smw3RN0M0VnWn0TyC64VmA0" ..
	"XDA1jsSD9En7Uw6+xY/FTVgfW6HWNPCqbtybSKrVeSJCjSeUe8c0oRdZDxJ36b2wjGB8MEYvcIT9adeZFqWB7P0DZqJJNhsjnjIF" ..
	"CPA3XuY7VkoQZv/WB8BD7TFA9dcdpL/clyJKMXYat4pv/5vJlco4NQ+vx93G6u0uc0I9jx57yzF70gSZNVv96vQ2UAQ9cpPp11cM" ..
	"rd2z52Zki/vASgMP/g8zaZpvKVkqzRtL2VhPfjMcNw6TNxUCOJg+VOXychUYGWFPhBXVKZvLIm/Ivn2l1Y80WJZFMG3ZULV3RoCX" ..
	"UhVj1Fwnw29WCxVMmy39zfwzVWUX5EPQRjp/tLgYQ9osHfuf5PB2YgRU7wZCuLdS55yYV9bvSyvn9JkRG9q6Y9zFoR7NB8I034xo" ..
	"yIriY3wcC3gSpXcTvAd8vteCQEWpVz6iRcYVQGXE7MXRWq2kS4CaBV6Z+NX2N7cDhGtrHa3AqMtVxleGMOev5BLn6vWd/u+9CMmw" ..
	"YKFAUqZF3s/hb/uD1uZUesLlhV+DnHoPwViqRri/QaLiuVs/e2zn4HdhqRxCuh0b5cKX8xXIjunkxRriXAVGHTsFA5Hka/n5wyMR" ..
	"dwsrFvFIXH+BiNgrkWVlLsTi+napyqaUMjCVEjLC8dXeEKFlQl/aQUh9ksADiSaerciUX7J4ISKyv/EtxvpfWlOM1wnz2zYTw3wk" ..
	"pxg/iWMz2+KxZzOXQtu+PqJZjQJ6VX5tICvjmD/GPLcu44wjcJfDrOpWQgkj3JeF89MDAtwMU0JcUYQZ30zLKcnmlhXoPTrR1lX7" ..
	"BmQxOiqvvGUT65q930taywXDCu54dOwg7tYfaHRDGlPJD23/uErw3JmVEG49+1OhJ6RNQdgeti+JBzhjwgHYFll7Z2Iiqly7eqG2" ..
	"Ff8RStyQYr/lWiVAPUb8MWBANuNZ7a0kxVjOLZ9QwaYaCZ85wSCLgox7FYjMAkCconmwNaVrxFVUZDCrFe2+A+5aBbxhVDOKQU2o" ..
	"EfaM+8znQ7ARlV0U7V6CNJhrEjvvtzqR4vRHBdZIarxcgaPF4kRXWWVvjj8rI0NEoqt32qIafB2SHOE4+M19uIfPwXdPF9ZNFnuA" ..
	"78t5zNYiKCKCnVo8L1h4MoVpLuJ1G8N8YHRdh8Ag0C3KGWXk/Tv5DA9poYixJdNhpnCRAGhI7cuWKKkgioXp0VkFRnRFPaS6RYKy" ..
	"yOu+o+uGrTSdk6c6FK7PVV13TXZp6mRZQicW71/8AUwjyoeEjzCl6u1SrJNaRKFuhzmBzcy/FQUE0XT2xDgxN1UDLWU9d0qsRnsF" ..
	"aMg77PW5f3+MvMCCQKBqxYGe1G69qqkBrG3cVZlOZnEbtX44CMJptO4Mxk9aSCj2Y9Z+kUj5lJyZixfto806QPTNNC1asuo6vawk" ..
	"ZF8Tc5OGUKFWOAa7vWpq7aJUhdESmCrVDWnMeqmOXlNU8z+sw52FzH8QOwNOlupj92WW5Q6IPx8ztD7+sg4ZHJYt/sNTTxjBRefx" ..
	"rHJawhdUq6KXej+bekswjU0w5gJGJv3T+jaB+qeqZ/AKQiDUTttTEKsxtZPPAYklZ+/owupUibgUF2cHVJ0bQc+2+4ur+vKcfamA" ..
	"m6nfEUFRbU/mZ3rovE9DbHr6odykLuvXvmCt+ngtzFLP1nWiu8wmYzkBKS20f/Xx30VrP2NQqzcnSrCH4xt74pkFFn0COdMCWunB" ..
	"wOy6MMEVx+lM7glyBUCWw2JhTpiQ/krvzFwlEYuZ6Uhzec2b1dJSREHLp0OKa9Rc4bwcgVU4zSXPCxcKsmB3qjdXsyun4SUVJq0Q" ..
	"q0uWFpMi98qaw3OogVIrCy3OT076QI3UGlQ68vkZsIqfrtsQ/FqreynsL79WP5fuEP6tpCjjKpuiHKYTNRQs6Nr9dVVmDViPPXHB" ..
	"7CsCl50OxJy+RrpqJNqe6wjWvNzd8JNJb2FvyWJi4EzFZj41uUPXsN0KDz3LBbO82FtV11vPS1x6RLYauaLHUzfPTTiu/puSn9jQ" ..
	"CmVVCA/IDKxLwVymJlSaw7Q1Z+GLE/9bSNXTzjjVsDD+K+eXk0KaYjJsO5KRc226/Tue2RKfpbUGTyvjCw+ByWpKtnADDAop9abk" ..
	"9GJdnXuRxGCi7E58kABnI+JPVR/7sVU3D7rK+V3T8PKEwWrGCQab3v2RT5qe4xxrZKFe7D8Ew9EI6n+gsBpQvKFHVA20851FrCqx" ..
	"YHasaXCwp7yJxsuGJvGaiMNJQme0xtuwB/7ThnF/bewekEPBG20ZJp7QxN6DsmA/OGzN7vNAUm8z/5Ys0G43MW7IfPCYzjZrFk0w" ..
	"mQobfZ7PIcYWLCplMTcTSybNhWL+Ew9lH3QL/kEhCQsD0HPhfWUSH2QB5V6gN/AKH2RspxuS6Drw0Jf3DIlwXtP9of8FEjcfaltA" ..
	"F7sLEf7fZ5Df3VWYzSgtIr7iCWH6hEi9ummuAVwWkb7iIcCJojviaZcauAJ+h7JKo8tCEm9qFCi20lNWYwIguk554HlxscFn9iBF" ..
	"ePjYP2N0LXAYauAht9VJnfAiINhVn2G06WiWPlh2KAav0PzJZ2x08EV0/Je/fwtHWXDIdCyxI7Zy/hxYfk/02+D6lJLxG0QfcYEk" ..
	"zJ1rG9QV4fFOnYPmWc2eG+znDG1m97XYis8F9ReOS87uAQ/e3lHouScq01Kjg4CdHuc50kf3ChksUiX1HA2o9XIZfmE1gu8DryKT" ..
	"s+OyMT0D0k5sj8BCb0RmHObjaRug3P7DU9Mcfgjkj2v2GXz9c+L+QQDrw2wcLhecpxLKrMa2icVy2RmVr4i9IzrROQuzisZZqLLt" ..
	"jpff8FDe84mujSGl6ZgTgZ7ip70bpS/lzXl2r63flfxs/+uKtaCpxEykDwctKOKack7VENlND9UgQk1w/mKUiRK/mcWOExQ0wjrr" ..
	"BBLaLy0ZsXGuBKPfuD79unT5Gvuu2eTf6QXuACi5EhThJMqcfCo/Uf3FcCeXdPK0jyfz+rA3/TC3SBLRRvSfR6U5XaQ74pcg79o+" ..
	"FiDM+xXtQpkmqyQ8Mrr/FvlYCibOPMm9uXuGiNYXM723X68NUu7IU39ylNAM54PIwKPoPoHwMyKyGG8pW+auMioTb+qvr6ko84HF" ..
	"pnkKNomEn0489wB75yjXpegL1aD0h2B8wDRvr27t+I6eAHZbvP7Qd/j73NNU7cGF0JnqoXBdpkSyD+YPJxpR0id3cPC60hCxrdvW" ..
	"VYlx215tfnTPWg1W5s50Hcb+zAXjzIvXxtHwAC8fV74tGO/QnEO9yHIPdrvLN4rv0W5jyADj3iL60km/+LVkIdkqfeQ3NatKTHcO" ..
	"vprKrhFIhsgGPoolKb0+3sOTr2kQEIFrR1gE7xnvbJxqT9qbhLStdaZK5XFWgGdHU7zVRFS11SAyJFmTcQyRhBFpWSf/QCfkjrSM" ..
	"6157ZcXWi0DrvfBksqOWWtaig7+xLzOkovsoCZ7349izxCKsb64z5NKwlhz20+w6yFS5gIRu/Dc2Qe7NCjSRqgBY6yPBUE9oh6EG" ..
	"MlaecpAJcrZQ97GKErY4x6jxQKf32+u1dnghOebmJaRJc4JO9+A6IcqxXQvhOS7ZZzYpZjRHxkpoU1IfXY669X5NsY4CCiSu433S" ..
	"/BN5P/Gc7z2/kpYUeQNxLtwkBEc1kadPPajuWzLrHDpXKx24g2gG2++CLPnis3FcurX4MDcgHPKoQqjWa/ShRDf+hPzzRpolNy4p" ..
	""
local PAYLOAD_P8 =
	"m+D0lXfo9WAh0KbTxEOn1CDzoX1dCv5ObDgonoxoZbY+xO6+VkRF/tfvVNrQWawMueSK8HPclF8E6DND23FeVcp3Fd5XGy6OHtM+" ..
	"hERDdRj+Fk0GrwWXlZnjTFjN028vtS/CI3ENUUPQ+JoPfGBmESTYOH7wjfh8okm0ZXUAvYekJRJeDGswfGRMNDX/JZNShihmQC4D" ..
	"TTiXvhi7JKCavCTHghZ3r0VbYDLHTnuajMWP5DBpu77/jZdM0O8wmtixi8SuHyz2+umZtaKFTAtPO51j7X7zTCDlejyR+/bFT1iJ" ..
	"WE544Zj7u0vnrErx5fyLwxOWwLgBMS9zxZqiyOwAkiXu/ycXX7WzdYF/PUpIcyP+f+rMvhSqyristtGwZw+1GUSE8yrGZ8J/Y0vq" ..
	"nubf5q2gEMSL3vi/h9LOnA7OTJkLDMsPpFZtdYkTK3Do/IqEJmgLxhUYsTiDV6XhybNNww93bconuFrgXx5n4MWAcjHJ56IJz+Er" ..
	"J175fMrg2W+4Unima4vwEJHMIC89ndtNMoQ98K/SM+vM8ADRLw/HsZnSzV8J/dSa/HyDVwhWyUWqhUsfQR8LB8UeYy/n8X9XVFla" ..
	"FpcVExxaYtg4z+G7AbtvhruKAs6D0oHSF8bqaN+YetZTLZ+/tPlEQj/v1HB+YIc47CcN22ZxKsj7E9GeWszY4e4SeP8CniKtqh3E" ..
	"Vva2tcVwjtwdqPZ8UbKTcAdYwtktqtDbFwfc7CQ296IXDzdmPwcABIcH3d9yRU+nss9EQ0CB6iCXZysivlLyZCJETV5YO5eyrjSY" ..
	"CuFawbxxf18ZQjKT/0qVG4mhHoBxqnj6yDDYrgwbO2v9NCYnKs3F2RZbHkdKh4pyfkTkAHEw+e7AUO7Kh9NamZTmWjjY00+4g3RK" ..
	"wVVBqUXeggf1dksPy9nqve+xhcAwTHn6SJXmOrwAhqGg2RWdL1JO1RCuB40c6TASIV5VfnXu4+RjoX9XdXL9V+p3ToTjSdrW4/AC" ..
	"cdFRwOPx3fHT5XGeJKfD3GN3e9LD8aI3bkK82DlGDzbohnGCyf8eBNIsGTarSpErwbkjs//xAh0xhwp0D+bl9gadGpZhr13K7xM5" ..
	"EjFPIcPXUjgGXblpibVx4vbhWTdHS+clJb54QrOrNCg1WqXIteXyyrfErB0tcFP+sFuLcV/GOVQh9jGCbjyRAMMQfU3+OPugiJj1" ..
	"sL7C/I0g1R7DNMxnih0oLX4vN1Pla8ceuxhMo6hjnJ3MPiPSKJ3jCh4bE6HDdaZduMIKnRlox/OXWscbPKu4HOT5TAtPJ8UlJo6f" ..
	"bDyLifQg7S+9cwW5QtO3MlnzzsttxqKwOCi+DL5pLOdSaQYi2iZnq/Vq25IV+jpN79+smtGbH14oX1NEFjzVcom64UQZylhsL15W" ..
	"g74TXevPAn8Pt1ZXF3vtcATnG0HykXYYAK9xJdNPUAkEoOgR12O8/AgGUx8GvY5wbF4pqRxYuN5BkjYoBhR4tO5nMgQkhZYUbuvL" ..
	"pkvTAvn0QVtPxQ3Vo+Olzh1UjCpdHubVkeacYZDC3E1R/Y84BuAEYYH5D5J+NU1Ntin5qrCtRF6QyRb2Q9x7FNa/xQBdEgY8Ujt3" ..
	"Lb1LE0yqyPU57r61tS8ISOoMwqq+UUnR/A695Htls/LFoVUOr2MQnXFmlOUuAF58LY004YQXqqzAD2aByYc/2/WSKSj1/+Ujujnt" ..
	"RYbbHCcTT8NJ5bTBeazWAv+mqnQgwkNyQlP9jNxkomHldcgRbp66tZdOuXMgXClIHiY1bEvwqZQMXOp2frE6JrxZ0/1qfiMHsLpe" ..
	"8kGq6Iq7jX8VDw4eA7WBi6bsqHS16EfNF+yp5wKLMINw3kxILnkN7J+ZaKrxHm0f8gpB0eJ0Y5kEGYT5xovZpIKdSXk9+IGYMOLt" ..
	"V3rD71atBGMMoQFpnJCCpLZRXUAeusjIAbSpy/vC6JZ5MYUHvCHufzME/H2V0n8r/hjz1ms8p9SVUYxszM2WnuSf4/ZxqY814YEE" ..
	"AW2yU9N7" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8

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
