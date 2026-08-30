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

-- teleport-persist: MENU tu arm queue_on_teleport (armSelfTeleport trong
-- dq_menu.luau). Loader KHONG arm nua de tranh double queue khi re-paste;
-- loader chi can luu source da giai ma ra file dqfarm_source.luau (xem tryRun)
-- de BOOT doc lai sau khi doi place (Lobby <-> Level) va chay lai menu.
local KEYS = {
	{ seed = 2023856993, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2027551607, exp = 0, plan = 0, hwid = {} },
	{ seed = 2026938130, exp = 1788089514, plan = 1, hwid = {} }
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
	"FXNEAyBLct0pCULb9YDQP8GDCu3AkLYIw0YRtUIkbwppjU1s73/YDy5I1DrzXibUDoGCrsA81JCdc+77WZY5KndocDnnvUo1XfmK" ..
	"Y9YnMmIcZ/ccptTUIVfc5zryncNC2lkb0XbKX/nfX5k9N7UeQ3IWh/3uI1XMcWzVdcjM9HL2XLQ2e1vYEs8qOT5o4DIN7/mioSW7" ..
	"eUUJmOsfFl26eycfO6ARtHEHORCctfDbS1hIBWCyUMXlZf1fvzP6Gzrwv7Rvh8I4mDHBwcHb9vA6rjOz2niO7BPYhz/k+GtoPlP7" ..
	"11WqvJ5efk8LR6axYT7KYk/TG0UcGcsXM5F4scIbXp6gblesnDzlKaL8mDbi+t0IxEsQck6HJ5VbUeAAcp16KzomqO5iZL9uaSoB" ..
	"8P1CDbLAAMharRNF9UDXlluM1cZQRwdJWGCHCxuOAetTHh2ev0sAt0kqmjYvHflIWD3TWkpvGCRZaNDURhSUJeznWetB12jAkDJi" ..
	"3RGe+aWE3iJS9bX/gT25QQjuQyr6PpQIFKjI5KSa1SgStbcVR9U+hSYtHUMjYEEnAXR6Uy2ZYA3lv94v7fgz1p2EGhDsaS4BFjbr" ..
	"fUNk1EBOdzTX+1cEpZZ+hRL0VYEll9Bxz4ksY2tCw3hcrGcg83zjrorhv8gyj64Q+4m2uUQtzdXoZjtna0Qc6STD5SfQa0EiXzbM" ..
	"7aSriXiiM6GrN7uPNFcp/yoO5jcYdLI7mVi6u32hIO5MAAHhA17AQAcijSzzj501GbgdaLQOaThmoxoeDYvWdIjhZZwvQii7lm72" ..
	"cpMUyPa7BYSj2lXpnW+V49J+1D5MplWCDgzYDOYfTwajBjpEkqKxAu7rtHy6DTyDVI92JXDfKZBCXjESZ+Xl/OPpDsS6cHMoII75" ..
	"Ec7rQrCs+VfJwV4Mqp8oB0CcLBMqUzErV/abS/SIVwEq4GdWJw+cUBlHeeI5hgGcQf9jlw1aQeUiEMZ07uFEx5Ed/Vl8I5tseZk/" ..
	"LEYwqSFD25blwiBJ8cvX03FxmoJMf16wYH+Cz2uXA4rq1pM32c4AZt1eNPVnYHELpnGkD9sDBRMCL/tDh85PgscPRW4KnmIihekI" ..
	"xdZ2p2wPkGAwO9CDd5NeoeCt1DkAFPWIYneciZyZYtn29hHQ6bMgPbjrj0jdJiEUtb3KjUxHeXmSCVAb2ue1KofByKLEi3mAA8TC" ..
	"HtYCMhfHOFuhccqZxEEYoBi1uylNQBVqJGmQgWiBXhovPJNRtY2H6kev/3H7mf8AvhHcz3E9bOmMccocK32yV1JZKf2arobvJCmT" ..
	"luK6eXUDe7V0q0yHPIeccXAQ0ycT3NUj4ZoZ5fc9ZntqjMgo1B8gKy++XTPW43PZ2CAYWYg0aWpXncoGsZZ7gtIgnQD/GWGjKMtN" ..
	"bSm0X7RxAkIe5ap2ttpJY50VlAjl/vFLJ4jkSShGqsP7pM7YfP9+7iETmHNJ2nIuiBlnwHvUg9bHcwZYxQKAwNWHFanW4YbJ2CGE" ..
	"POYGU+ML+BUW/iYNv4Pqu/HC/kGTsKMsPsAdkD4X5dgc5NL1akOHTc6B1N/fly1KM7OJ5AIeZGUvZQE9jF0RPpcXzJ8qPzBN8Iy2" ..
	"F6Wv3mDBPM9qEkeocquu4cHrHhiRKtHi9NL3d6lb++9IDm8U6CxvAd0AJRiBtqoroc/bGOpEOfeJragRKWHCWE/z67MBvBLV0p+K" ..
	"g+E9YXLsk605FLvk2ChCzEyhT3CCgMxlDOkEC+C5ZwEmvCcW4uUDUF+OunuMcSevKstuTDgF98WSFkCcUs1wokEbD71xpsYwyBcR" ..
	"um5jdNOUwYMOhescv1JWaQj+3ZVuL4rqY2bM6wpwL3gO3/rAQ/KsFuba7Vp3ZFOizmOT6LFb8FDUtuZSlQDqF90WUxDXKLOvBvKh" ..
	"33Nt+5mnY1ZuQ0M+4sUiqIWR6Q7tAV/EZ2VrpoiPTHawvrpI/HPJGq7pfXTrOyb/pk9P+duTXssNr0gEActicGxBvaHc/XARNYkR" ..
	"FRiPVw5R9ZkkM886c/CjI0JjApIstOrvPtyyrV5YSpmKDHpNbdMHfShsypfHUoKURvlTZ/nRZ0b1jyVZOe9VhTumsvuXnTaGyhp6" ..
	"Lg6OERQ4LQG/l2wqEjLeTCX6zV5GeBbzaDgA5g5ZviayHohVgt7M4KZFOYdAjdTWdy+jm2JX0Ev1wYzRAVWEUhgzm59VW51vaJjv" ..
	"2K3bmxWNe1aU3kZMQkjgx8xtdEMn9E38a25Qb6Zb1MqKZfBOEKaXv2aEVG9zwgm/9gEv4K6K2dTpeU07bO94aJn7ugsSQnJPvdVr" ..
	"nTsgXvxRyec4vIQ/VTXx9clWgaA31M9nq7F9XX0U7QhaI03RG9rnc4efOEvqpHvzAcGS/LUePrVFY1hyJhj2ouBFrcgMJabXicfc" ..
	"7qdCfupC/OmmseMmVOrHnEbfq4V0+oGHWBp7LwYdGfudY2ldLDBeHa4rhcIDxFytXw8eCtzL9urpu9CDWRcQXk22fcW17nCOW9dy" ..
	"Ty1RMTJuiPytRxSnlA8e4z4EytlPbLUiEdHBLOeiV+dqs3f792/toGKPmBEszfIGW5kXw8ensaMkb875uRfr4eGpMcRtnTpcrLCk" ..
	"FZoDr8HWlKMBOrzOS4DWXJbIES46FgVwr8k70WJnlMsJ5f/QohE1lFEmxv7NFpFOlPVOL74dqvyROppOgS9jpYmI1+Rk1Ltl0CNu" ..
	"MJo0mz6jUAb/RiidC+PtMH7q0KekUoppixrJbOM5+qcT0nQEHMVakA4+BeKZxIuA53DclsozKvPQ6sI2OWRPOjdQy2CVrvBZhN0w" ..
	"eJkUrmaxsw6q3eH28pyGqaDBabjFQhMHqv7PqZ58/zUwpHPQ71vBe0+OHPGvBvJlC9VAPq4PMBSVcEcOJBgjgKR0tR1LVz3XJUEk" ..
	"0MqStqMDZtRNzZ6Hjf3yKj2Lh522fg9a4NLV0o4U002LR5WHytAGinjW23F/kWsnH70ahPTZClownMT5BT9hglPE14Fz1tAgJ9Gp" ..
	"9qQx62YxprJgqTPzWESBPCA+m/FVG9Ga/CtmMHmWLSYMjicxoimW8U34jX+xjGVNge4K4xmO6y8DN+itAcKNIM6rpbg42MKU/68K" ..
	"yxZ685bWuuzL9HtW7xjlaWO/wvkBi/NoHm6PhWywzmspvK/4zNXRz58HQ2JaHYf2nLNQUWUgkGV4cOAgGNs28RqEg5Fwf9NQMrnT" ..
	"aC45fr0sHYXQVyxWLF2qdX7ptb/u2v8AqWEK0ELFMtw0VyYYU61HrGZVrAmOM0q3kfnI9zZZuU9NLRu/wEybQ1eRES9l4reyOoZj" ..
	"5aAecZqz6nBvKOhX1db7S2puXW2X/NL2BS2JjNT0bWOdnFGnDXnWTOTudrnaNFH14MfuJ4YzrxKR7CME7uuyz9xKMVAN0GjfIIeO" ..
	"7kn0noh7N4QMpm1+QK7MIOqXib1xd99Yc4cduSr/dIcH4dD2FTh0ORhTLDrJ8gMYyQ1OLqgLSB7/8sX+xTj2e4CJlEzEfAjTRac9" ..
	"Lzv8zhYpNABZuOBDJHOblhFHkHjLvS+vhA9XHt1m5fs21nqf70Tft7X79X3Sf6n0nICWHAmmkTc/DAARIzIvLfBZi+D+DRE2frsh" ..
	"EESmJW35ggkx5Rj9dhUlJAIlmWpLcOCs1a5TgNOFcSy0KiLduwOP3Hmt8eR+X4KndZUZ66KklcUEm1YYYZSrecKJwrWaiSUSB4Ck" ..
	"vKBtDJQHu5pCDhlnelb/V3UtjQ3I7wHzuBLcsuWDCnhpuo2WmvTPWln4FhlgDnSn5s4EUTEAPJcn6jYZA3dVqAPBYVHemjETgNmE" ..
	"oXFgkq9C6Mqp7kK6AlgioDZBt8ZR9aYd0vG9nCMiFivPI55ixVbBxKxHIXTGixw5M6PVkI1dFz5gpik6h0GkdQINrbTHaMuYOqx4" ..
	"y3uBFOIJWwluwlHsze5EPX7QBss7Ex2pHvKN6PPnG8ps8owp0Jn47q9gK5pgmhB/RAUTXND002WIr0F2yKParsDcSxUSCb/znjsJ" ..
	"LHTRZVHmh58Pjo6XKhjRtcUr0R+XNvwdia9PUQTGcYQgo72zqL6vugnVDtsyFpfGhw5opVibjog0dsJSYICQwW219cCCqZ/Cuxqb" ..
	"5UUSg1DfZhtTfjJKwHHfoPVIVSezHEGxJA4O1KsH18Ia/rV7yHqJnQeNpRmLavbbA4GCSLHDT9zvSTUsaxvs4wGhhRQyQ9m8yVlk" ..
	"FW9lZAIr5PmP5oD48Yd9l7QxiPx3YLEe+TBdnw/Fzvus0vXiNDWhHGv3AYAMpntUkofJU9fxErKJcbrQ04jReqLHq1r2pZirPY4X" ..
	"Q169jUtZcbGxT6TBV4kLyFv3NRi8gH9Mjopzccl0mDIdkWj63Qj7DBU+j3PUaEml1kjanep7iOJCzId7TmLDJf5CpX+hFqE2Sfu8" ..
	"pquPefZ6IQT2iKGGtf5wmhrVTg7nrGqR2071GFt9NqAZ2a+bTq/Jch/GpsP9XlQ/vFuQMtvkqpugwdiuuGSKu73Pl/WTXIwQOSFr" ..
	"SM5KayClWw1CtEQIcOcqeu7hf0rbn+L8ZWBIqkwlhKRQwishIExgolE7cijJNQrzjpCMRjFwvnsghVW05fjiG/Re2jSHCg0waG8+" ..
	"AkIMTWJKJ3c6aOiYB6F4kmRolmZFNQ6SlCPj+SeHkFEaghePoXWHYkss9kMgTUiMJoiBt3UuY1vht/Cl+zlM9M6dTSIQAkvf2S7Z" ..
	"OytaDGHbQBN/vQ63jDeNwTzEjBFrJjbb8QTFAAqIK+GpAvFdx2OyHP3QtV5292kcrWnOICu80pqK9NDUHWRWvJbsfDbJhcwMelch" ..
	"dIh+BtDMoFHF9TcnsH6raWFFig1ST9qlFHO+D39kp1kzvd+XSrkWDYiXxw7CC8AZN/05amzc/XTC/HaTgAuGcU9G5uLy89h2qPgQ" ..
	"L3r6SWb5Shn6EHQmNusTMsHv58i4/x5olSHZyexDZUDyofHG78TC2qit7PAcvQCzI307pbLoKL8yIxaVhTKp9P7A3Ypm5WayDypO" ..
	"Z1Xne/dHcx0o7LN1pgV1dxyHTTYcMp1GTvGoEXZYn6tdFd9fO+/PujGUfrt1ekswN2ngxmk9EX/gicG9qdN1NX/l/bJzd7tevKov" ..
	"iL3X69p/ZGagoNICVZqI0/45yRfgzcFURMK4syl7JnyRcTQVm78V1UPzVSDWD9I930dYRpTUmgyTeoQEna92Ou7yKlMxItfIu7oZ" ..
	"8QVnNtqZ17TB1uMxSV/lSV+B6GxzhUiLmR9Uk7b4z6GEdmAMFET01JYMuG7g13PEUuVWeU7irvHzLK2fsrlDarG8klomCQ5ReZ7D" ..
	"4b2NZvTItFuNRxf48eH0gQlTbg0+x2f3AurLL0Le5bXyhbyOswbTPQbNDftcMligmGOk/mRfSFbMMUzhQ54XTRDVHBwN2V2pCWjw" ..
	"ah3tRzODwRAVvfyF4Y3/8KnG4yvO1MFHRLWsvmVJH3lKxtmzO4MXzRfZAPQEsLz3gfst5Muyt+WBX+36GnZAzfMGow4D7/F1X1P+" ..
	"VrXrDaPDSbYugXhHWvSY3glDsvJUp4/IYuH0sqWtfyt/+KSzCMURQDcO0D8jvJsyd++RdpM9GHL6sCCczuLjbG8wtP7ovHLYP3fK" ..
	"LSffTnNSsZJhZgfql42zKFhRT3khcXoVNHHer55L5LVdsRbB5OV/xm4eII8MJtt0QJsm+Gf3RVhzFzgElEeL4QAnP5GlTd+Yjl1m" ..
	"kpoLPSMymTg6KugvTJKtOEz277TClnpLg1Pj3/v/eWdsYBPGOcISIHkjM+SiYK9yKn+q5rCtgEOn5PD8K3zd5v2x0uoioP8bq7Rt" ..
	"hL1x0c9XtVi7X+oJvP2i8yck5LplcDP40NZvaSTw2O49kqPAdPkSnJxCt2dMX5mcxr5qyFjCnOOlvzrnyQUCv6lCEgXj+nUcQ4wD" ..
	"5z0umtRVT7aaQya6oIkDkuCEbki4R2pUoHsJ6dkYF5dEVOrg/ODXdD8V/LGw7uq6XMwSs/vtIIoOyAj2ocMgpYC+7Cjjx3a406GA" ..
	""
local PAYLOAD_P2 =
	"DuhU8dlUt1DYhY5ZPYwaOD/ot361IeJ/XNjJwhXktmHJxWNuKXj3+oMdsMyhRiwfIQhj8AJj0o34DqtfaRhQU7iGg1fsAc4nId3Q" ..
	"wxfeHeURL86tdGngLtgtLWiPFfeQJUEKEK0c+TUNJkgjkWF5UnvWLlT3t3IiEzmkHhT4WawuecQfYCmpM5k1Zrb0T12pXMOS1Uap" ..
	"2uT9oMhGYvXLkS6nasHO+3HknatSzlOox0E5k/mjwdkTRrSCw5vcffzT2wBv8+4RPWiAs9HJ/s4ZCc1HCL3sJrRSyJlP0P9gDyoK" ..
	"gxcyugugqodY5nzifoL1u3gtFUcxBwkrLlQywpH+moW5bK8PgYSBfVcp4DXHkA40z1XK7EiEzCKc1tV4a8qsD9hcy532EmyEEbrL" ..
	"k9p2PTfvxBrgPblZE/5lJMvRIu+MisouM6/hE2ut+WV6q6Iceg+IVRyUKjK8WXfSJk9+rUdaB0b3qgMWT0dlumWHLpa3tYAEz4sN" ..
	"CouQ0olF31bL5L+VrHsY1t7lOSJSBSXiMGf4bk0REvIyLV2B5/z+b31+rgTY4N2H2FlXglMYaO9Y2w/kaAYARXVvzOEv+B0WFZL+" ..
	"kwBnNcWoC7UxNTgrzYgiEdMM38PR+zkMgmN/O9iUP7aMAXXZFldzFx00YpJGoWz2161iU4QR6Yu9kcOHEgNblzUVFRSPwJjzC8j5" ..
	"M/oukqcv3kOdMX3oDnAj2dyhjS/ie5yYPULk04vMVhS0O+JEc8kCth3fCbu5mDJJIQCyKIXkZpbO5gog7hBcEq5K79sTcWA664Sx" ..
	"vl5/H7PwHiATws2JTzClfWkiT1SgxmTwh3AEdXncTzDlm0DF7mxcZ7oB6xg5aZuK/Qfg4Cz3hsfx/KkEW3Hf2D5/YwqS+FhaThaX" ..
	"eMEdi9qoyG1VYW+7HzHFJxE+7h+n4QGdpj4t8/DpPdCqJVRqgXBUZogmpWBEC+WrYVqQvNKivcciBFKFZ1JdVM2cX5vWxo3mt0iK" ..
	"SryaeD2oM+KcIGwk/UjR/qgM/r4kKwkBG/eCCD8hRdBBThAxrIdKWBDedaxofSxPrRLrT7MSxPEv1KCv5tydxrNkuKGhupYT6lng" ..
	"nuf2fwmqn5jYPYU6tlZPkmp/RSIESelUHdPVkCIZwd3O3sxK22BfuL8Ql+bL3lgmwtTkVTgd0aX+zwajF8h6bfob9Wkt96PRi7cP" ..
	"l6Wpc0b/FNkQxfhYjKKIRov6K8xTbYS9qw8wUxCJ4EbmJ1J2KiGlo+H/WSB2+zxP3CQWeI6jLGAAi0nrSKFPYYoUE6/OX7ggYe13" ..
	"TBaVJ+AaigKMwDMXC5pL76DRHxp070YD1IlzVwuWJv/TB58TUgnuJ/GuhfAf6n/9NB5ZZeHQDZkXouA25ibzNJJaykgP2Wxyc8Gi" ..
	"88A8srvx9PqAQwZs2D2gWZSt9QuXpNjeDO1AKfdI7Gs6BX6oGwRo95y9a/Vnq5aRMo9vVxd40lKMzF9be1WBLo5F4zBMLKYj/nPW" ..
	"/vUdDsMfE0j7zQ3Xb5sqhr/poGBhPmDqPxI4PLqlEpE7kXrQjBRO+PpkW/5/a0uEm6C/zQ0xHR6lBm4n4cGXZG0n4xYBlWx/Impv" ..
	"ve4j6Y5r88QB6erAGxAJDvfCzPW6VPpaVPzs8xB2bqyoSz4jHgzfR5JcR+C/6a7La6BPH2yxA8og8hntm1tO6hJWyHIjbJqD9VJy" ..
	"kRPNvNTIgd9QEp37HFMAgNEIiRnEag6JFnImz/yfm33lT+4SNjq5WF+3F1ey0nXd5U8DrtwIT2/5t5gurbVEQCFedVp++93RsCkm" ..
	"XE5Mh5WK0N6dhtPu6t+rJZVY1rE8O5F6anlCFZiX+S2OdF32WzU4+9Jv2QolKz2uugGowkzMvZcBtW6wM3GruFpbRvwuufOtyKGu" ..
	"dG1R90y4ZFd1EVg4JoUdWLVuJYej5cZ2/keDxz7xEhCCkMLxyR/T1x8G0hEryAotYUB3Zq+QJ2VOq7dNIFfPDik6KqcAuPkctwqz" ..
	"s0DIeYtQSlYCipjInOiQvKlZPW4HKm0NhteVQUnz5sy8FT7cNP7ehkZ/Uo+e7lZqV5gSn1+CPfGQcNS7z+0jA83blEEjETc9QJGc" ..
	"Y+T3ZtTccP4p35YEFzDZP22y7DhG4+Ag7K9Rb5nhtlM2HsgZZ/ojhZK8R3fbKCQQxk1gXbO5EgoqXYPDILkjOQkIYRNvLs+KwXXH" ..
	"TLjiwaoegHqhrT+prqpzjbO1S/VJM9S6eOcsaMhhkOYwvBlOGMC/2TKENVdcynvI+/U/mwF/LwRVQ+GSVTPoB475zRNC3D3kj+0w" ..
	"aOrgg76VrKkrdIpO0AwDXhzxGFiqzxJHXhjOfKjy771iv0mIr+20KUEz2sLaal0PBa/12GdSDhkYWXlt3KVn7C5RwzB0206uptmW" ..
	"zyMLEnLJfcd1ezYPaWVUt41bee2SA1tzfGi7SmLPvcgTrZyFnVG5pTcb+9iW2XmI2hzeNItI7b9MpiqdO2FmrmYMUmi0n6xJKhep" ..
	"OEdo/wJnt7hrgkycJlsIkxMPQLwT6RKJVUuBp2pujhCBDHkboWwsWaI1x2jLImqQdRus8x4a0oG9tqDTK8dkzRunQ+pmarPW8ZL+" ..
	"eqLy6tnr960216NTjRAOW7NUyt8MWypmQePfqL8grYBvNOxsvDD7CWBfYuhRCdmLMqhHaKMMCCuKwCwIBaxTO5xDN6awouZwUsGW" ..
	"WEmL7m0+TV56e7FaRIoImuBmXwzU63yiWo8V0MHEdijc3IIAiPs5e+nveLmrSaLiG/S61kqfPycJNeuat7YfC0vZAsFnjMtHtI9N" ..
	"zO0D3saJlUBetxqZn4oeGMv+50Y1XYLrZ7GkpYE7xdTxeMzafF4Tg57eYjrKMSZ9t/bf0RdReYAURHIxYOWxb+xqVjaBUAIjerkY" ..
	"PIHV6HiEPfAGOpZvjyKx02zYuxFfr+jIvDhw/wIDGmvI4Mh2SbZzr8LjtWl87cBHBJi/5ZRWamFmerFEIsWwWPBTqXwkv2yDsZ9U" ..
	"HNDz8wT35njfIRpPO9kBsbwUspTTkMnmQM/VE0czIIxDB3Y1t47xMLptOXR2HoG/XxMretN0822IVAPk77RN10/7ofbbrYU8Fu3H" ..
	"GX4HIoKMKJce61ns46mov5k/cieC7/aQsZDtGCPY1T70WTqb5P1dZSWL9JUuMmlqsUvL1ClxcJj/uql5JvrTV3A6Mt3zlmkTC+TM" ..
	"yUFqquBMzvx38ND3G4IdA5YLgLSuqF77W3FgwR70qRbH93dRyVbZ5tZjJcPmUe4Of1nBU+/6Yf8wm868MjiYWBnwhZGbBXvrZI2o" ..
	"u6s4MhI1yAOufS6OtuBZ/XltUw4uuNN5qxpLGRVdaf9uGDR0CuaUDk8Ien/MxN2SkuG1Y2FZguwEcXKYMJlB8bkuOOYnAb4rf/tP" ..
	"FybWajUpJeXxeAfn8exuOr+JRuki9pv4HStWZY1euuD64rau50euec+kolov+++MAnCY3PBV4gYLe/jzWuldn2fk36lIjq5VQlPs" ..
	"eVr6opJNV3vql2MbW3a9vAoUosJ3iKPsBk9w0KgHKvVDhVAtPxtIWWhsJVX6FYfRzwOWjRJNiAMuucB3YpuTlk9n36Y6mnMHyZUa" ..
	"8EWxv4Ew4sqm4mEe1nD6Vk+C4hyb00qaX7qKGLiLIOtCbUoTpcrwlHsSDplwLWC0TMLuPR4xZPG9adwjrQOzOH+w2X5e6K1/S5vc" ..
	"3SFVcogON/LDrVOxT9mPQhgDTE4IU52ykkfaqsdramK1P2sjrHdq1aNnrGSyrBWYMTDMQtSCcv64xFRvZagiVZEGPnMJFdTyUYUa" ..
	"GvIoFNuOu/mW+yNXRZv0GxHTibmnfGouGSdjIIwIhXfX3nFlbThjgzINutEqP7ypct34IT6wpBkxYl0PORyO2CUQZDWfxSMFc2Ai" ..
	"Q1y2eiyFcLrU0FFA1f1wdjzqC3Jtafm+UzrNWEyNYwYKJBsnqA0FuaJOWPD/mtT58NQzinpTybIWCVX0LGwIBa2TXjOp7eIeRTV6" ..
	"gRXiSFWMpV2fCybKmwlv4u6yIajmRxZ4kZs/DnCHTbZ9S9QzDaci8em89bg1u3T5Ak1VTLVWAyWwoP4Rsa4TIqYQA64D/fa1cflh" ..
	"RSqg545gZobmGWcn24wo8TDHGOPr3U9MsewFq41vdI3frURsJWu+pfVmSi5JtsO4uHMFhi3YaYPzX/oNr0u9bxlMgYTX3WDCmj68" ..
	"/oON0dJscLy5JZXAadp9ZjVfcG4pzZcUBHZ8W/rkvbgmntbIogzSyjWdo82H8kizv6GhbzB8WH6wgkIEAPze/YpmBEN37rb90kbj" ..
	"+Ex9rsfT5zvf3r4t7SbRxCKy4mxTW8lnI/8VshRPvxuXZdcE7Ajo/D+fX3PdgML9xOVxrhA9ZGMPNitRRgvClckneMmodZz6L4la" ..
	"bT6qC96wXMEwTklOgsOC1vWW7MYJ2H01/TF2oFoaFcF0G/X8RXfLJvV16UrKkk7tF6TEeAdHwHfAO+HZAb98i0dbfDmp2DkfCJQO" ..
	"r7uneUXaJ04NtFg9L++rOmTRbUSF+8b/f+6zixaW1QfF8ZWXNO3iQRnYSHFUA89pug+wFI+sdCZyFBXdHIlM8iBUCwR2xaRI2HEQ" ..
	"qsHhBthAaoQrN+kX/0/nTS5vrHP6h6AQ1HbXp/4A0a91UoGwAU9WzhP+fmf/e1R7p7hVrh7Llnpe/gZ2yo1ZXDLYMtUUuHDoQj5E" ..
	"ILVM0vM7HeNga9vLcQRou9ysHV3vNCXMy8z0DtumHFZhQCiYZXMmNy+Cdbf6UhCyyNExmrIFjMehtoMHQQM9f9V0KxWrmrkI/f8e" ..
	"cmDVTdidjlBj85OVR1rmQWwex6eYlmVZqAKpqHCPmoxWWjfyt6mx1ISlZfVol0gSygVNB83ZkUKP4lGwZ+W3DRn7F003D0ADrqMa" ..
	"2JHPnMTYOdK7TeNE395XvWGxjcNVIxQhAWBOBwgF7ku+Dx1zvHpDEBSxittabOYLcLWpOcdeGltu91QHTD5wZAPxzklvOhuD7kNe" ..
	"OAswTjTsJcTuaSrQIJt24XeJwoU9CaiVL7CWXu+zrxS9kY6O0um7yK4wDyRgGpBMDhX3xCo/YmTBOE3IaJOx1aJroNyKI29OHr9a" ..
	"WohX53e2+FgauZLk/bzgjKHZ4iEyfDrNS+IlZj60l0t4/yc9i+ah78B9jKHCinCaaLF7hbY2FS0VxJkdZAA/YPkm34KyWxECPHLF" ..
	"caAsDtA1L5qF29xWqlI7RcxPK0dCiParlvY9tq3EjKjs77K/8zuG/mjgHUX+2Y/hjmhl5c/nlzNN1JTHWNooTCwVXRgcbTsFFenN" ..
	"U+lg0LaZsOklKUzLVah6kvLq670DuOmEWzsdyTyLzNRADd059YCLItZSBNFLhU5r/auWHtQZUHYr9okrfH9XIwzuPNtw1Sd+LndN" ..
	"g69g/TumXCjHb9Bm8uwm7nxgnNISlWFCNfWN10ZO1PAhqssoxt+a+lPa1pGwc8tqUPAR1Zqy/NW+gk9vyG9R6+WZEZ+rby8ogH1Q" ..
	"EWue16BxTUPyvBAGmKikCbAcEmLQ1t+Gt11hcKv3ZWL+fyWJS+lvZslEggZ1TVuCUZDyUyWRMjZh+RwCp+7ZRA5LPNmFyxl8q9fq" ..
	"mg4Jy8YHHdw4YOreE8SwqG3/Z191mswqT/aCk6PhBJjGde6syhaHpaHTdYgREHnM6Ahqh4Zhai6frFWD9Uj+zgFSLE88TKFwukvv" ..
	"TV4yYhk3o1IGtGjT/4JLTapi3J2Y47O/EFHbfdy4bkMwQChviU3Uv5dBzulJGVvr+u47dxZm10G3maJ6s3gVNaYoVm1HXx5Idrpq" ..
	"HwF5x48Q1Fzpcf03rOmQpg+CSa2s/U5S5LgEBepbktYM154HxF0pa8w2i2jHhmOpb5fWxhQYcVY0durTlLbSEx/eJuqXWTVRb48Q" ..
	"8u4AfmwfEZBjY/w6dr2/KEJevm6is7I468ZO4kO80oVWmTxixsuT3l29OWTMhQw5t6YjnrR3Ke4csQssqbr4Bvbfav2lKguiAJ7I" ..
	""
local PAYLOAD_P3 =
	"3LdQRygStzKR/Oep7gllgW1+LRtBGjLPMOd07vZ1tKF7S9VWK6FeiWKRHfJYYqYPfja/0+VyNn6w2rhIVZ78sLrctIFIKNiaDaed" ..
	"bhotnvO39wOQfI9uO2/aKWPl+tz1JfhfBNj/Ocv5hmsqpwS7qNSvEx8WVd0xeiExvwZs4Xntra7tUtgkiEfk9CbNT+VNdg193XpK" ..
	"ydvWWP/uUwPXFPmSdKt+KidVED/46nQM6P5eUAmyh1+mGzsfrHtnk6deteTOJpN2BFsNuJ5zGhGv7XuwTl0X2yvLO0qUrKTDR7Os" ..
	"/6gsCu0LtQjTGk5qJ6V1Q0xfJ4OBhw1Z4CXKmKBgDI6wZnN7yXVuLeDDFWXIq1sxYFVPIwhuIkhkWiC5duWvgUxNp0lEHSIVqQlY" ..
	"ndPBvauVKN5h0NSPTnPsFVEsv0Onlk/9tK+6jsLcl0wLZ9v+yn+eoJqHq4wbMpDsiwKArrAW98Xfzsf7lS3NSuBLY6U/5XIUapF7" ..
	"wdg3FqYiyQE8lzLkAuresw3HwU7k28MBqe24TJQeR+CCcqn74ovwsU02VV/pGNTlhpU3oM7PWjgiTTzrwtGZhEciU+/hZXmB1sCg" ..
	"MTzVegezDh76ULLFIPXwJRMkkwmMsVrlqVFP5NxJ4r/h/03nJ4R0afpcGpiT1mF6lGBIuFgE590jzFgzC9bbsq7bHG1zOoRbQMei" ..
	"23iCQqYWbpcN9esNI/4Ck2qiUj5QDd/5JymJOzu5o5tstG1y8Y5Qjwcn0cN+emrcEBAkumbzqAR9XAwWCJj8vIrBinp3grPq1AMn" ..
	"LpbGlLs9GefXISCLDFsuGJLA0+YuzcOl2HyVd093UFfe1IhUi73mwu5ujpFlE8KlO0WEBQlwi1YtawY7nAuGBID5Jz/V7oGFXGWE" ..
	"cSLKJeSsXp8cpLMfAyHs9U02EOjAEVj2/291LCkRRfv1qhtUwEMlL34jT5DFcR6mplJznKrwjXsir0Dl2m/6cPfvdRHi9nt/dCEZ" ..
	"EUfxIhm1svkRSDVwdOsWNICky3uZ8dl/lX1wfogU/BrufmF+i2lnjv01BIs8p9X8TKbDA96PTuGg/wZoWMeiB83QbkmQb2a6GkcF" ..
	"2zsweypdCk0N/1zqLPjjAj/Fe9LoTXzl8ATrp7jV3vc+Jar8TqnRnb4rqk7F90vQvEVDh6DTcffG3BQt4CjR0t228gytclPNL4ZQ" ..
	"IF0smXnx8OHoJamRvo+GztbDBNkgzOSgoSzuBrIUVPpNoxnZvi2GVYH1B7a3JlNWJbKmQf0j3Bl2bm522GRGg5YgxcDDgpZ1GtwH" ..
	"NmXfASE4IEDYAHcUCdvGd7ZcedpnXdBT5/5nfA9rMphM6cx3pZcMjgyCsX5bJDNNMkCX0Vsb0vD2zIVi2LgQYrUIRZYti3FBAogf" ..
	"hFM2j0Blk7cd/Rn/FprjWyb9XXHxD4JS4gX4tRDlOy176gky1fw4rxW1ifsDEz8c4D3vquvLibNVJc0x2pAXMlUtuVelX++vzjb4" ..
	"q21NllB3sWbg7CK+Uh4qbsFSrWLI5+fu8Hv2wM57XvN/ht56gw6M1TnHkJo7KFe/OR3HVECiDsuewCtiuC4uWudoMOLxbkudqHYP" ..
	"bYVjQ1OKYlmAheYkM6g5M78h/4sBVKGY5im33rr+Jg3UROHr2DBA1vhpkQGa+hFr5kSGNygAOm+reWds55I5C3h+sCPE6kfy0XP/" ..
	"YqWPvWJw4rFOhAwH9eKEdZ6Y0nfONwP4CZRLCj9PbYo9prj5CEOKQ0/h32RLSuKVNRg4HbYUzzMmgD74MEKvg4Hdn1SQcOyPJ2DJ" ..
	"v46rOAOIg2RDIBJ6sx0FEKRwtbpAjzzS/V9ffwkTZKL1nIi8zW/AstvqGn0tkgHsEM58nEjZyaBexTXrHHcTqec9iF/KSVE/GgJr" ..
	"MECpdOzWOsZn1ZGeSpIa4YQW45O+1COlgmVVWZ0Ay0Roao1WAyrIIheSdC6D3Gv2uJKlBRwxK3V3thGtRgjmBp3V/WnkmeB3t5tO" ..
	"agtgshCuTvyp7QhN3CUWYiZwO/3jl5sZPC3wydejXCNJ9JdZ7+3+RA/GNjVDC4qO1eysl5XE9wS5JB2Ngukmo88vxMl2BSRZRN27" ..
	"YBvjFbCA7MPUoJTSMV0uhViSdwmORTfb7m1nIyAJqOb6FCDXK9uGHo/XIkGXt5z5dMfksBn7RKs51QzwyfXEeNwb8M081bKBeER4" ..
	"S63mwLud1JSIDkDKGKZbCAIY76O29lGKb5nWIcQzzBv3Q7Lzt5hgWaHrMMLCMgVGB9Py4us2JcpX07nVycDQ82iwUCJDJ+xwG+Ly" ..
	"y2jtr9Vb/gzKwN5sDJdktXezPoorjE89GHXlp9olMciLCooqlzHs//PtloTQtiSPz7nvxxAtYIeOEDkUQ/j8yfUz5TWWW5cWIsO3" ..
	"Uhl9+oWJnOcmM91aOOMfcRRg8QyyW6wWscx2IY7B+vu13yLLwdwhaUeMyYMlupbYcr+WzLqQXWSBF+aCS7baCovkt4uMljGmrTUm" ..
	"sB6I5SUE9/C9HqiEwFVVye0Kbt7ZACctWveZWiaF9EmwUV+SrL5pChRqLaq2tWAUL1nut8SFoZ9+XhnPOei8YGWcbfSKyIZvhTyk" ..
	"ow6s5yMSBxbLPlQFnXaNzCeu4Uj/qvwgFAehFFLWYgfzlxySsQfcgToRp6fc7VmpRkSRNk9XrimejIU9Nu8hNnFzDrONh15lBK8k" ..
	"C1knP7rhB46eiKMDVJjr7PJz1f3XGDBR/fTB5U9wgLhJhZdwo22k2AEU37q/M0xcscxKA51u5OiLbJAi7O8lXaoy4zTdXmQFaLmX" ..
	"6HEXCLssGusSe+Y/fFfl2DCBdQLpnQ6/bnGJ6iC9q9rfnTMWyGlvMMu38qFYL6EJ39EDn8SGiZeIW74vEBhViILwbz1qSOeCegz6" ..
	"ctubDy19SIFbRm9iqqGuSnEe0BKq3WTFTlSvry/BL7Vf/0jAM1VI9py0vA40BelkymaggdHZ/994sa0+2+9t9Rvylq+Fw/2BbCT4" ..
	"dQhloBHcSOCVSmDR4H1Qp7IIUogVcoONBxM8sQt4M+o7+EUnZHCaMuyJMpXFNff+wNBRxb35KCZeh3j0hSyuSWdkuN9zG9DWX6M1" ..
	"Oeds8LDE7Lf7OKipVvfJ9nkIn830l8Q997/FeDiiNG5ggkEBvNxNTsm3hPz7IC85/Ki4JTujzqMQk/0awmvo32lZuYGcZZhFsCIS" ..
	"xlrq0sp9IgVqyzRxFxzb9WNij0HKUQlgTqD6+sn0lZ8t4hhEglafFVw1c/u0vzyMxnyluztuCx1Ru6qZzK42R5mWgSlRuedLiDSR" ..
	"Zt2dm/tsKzbkfH/fSiUCHmBFR5aRkbd9W/CZQzm7EFbR5eg3o25lU+I/ijmf8odS8VT+HP5mDrke7j+3kIGwODfw8n8jaJu7w0r+" ..
	"2iN+8nWVuISzJlSkdX+Ip+K9vWZD1uTV/rZkEeDRwNqgVumKQrYcrR+qggtdVXBxHZj1Y6IcI61hOR501u54idXxY6DBwSkRq32D" ..
	"twPqzXQexwCIsHeYlz9iTkW+dE60ebLUHOAhgCRKo3OTBbJtHMD7dBFU8COEJUiwxyUNGnFLpCQNZruwsgY4Gp887iAT0rGOQEFK" ..
	"z1GczsY6s5b4lJPPTFe4VWYBPyzOrsTR4WHDm41pVlWLO7TyFc9TIc4hkoyUfRLJEaSz3TXEQIaeynfQhcgwYz665LuXSTRQhNLM" ..
	"5zzZV3vO+hOjroIkJnV85Kre6/UD4wQYiOE1PW58J7NjXwbVRiDCMKdzErSNOisaJUYLPLIYjxtnpu5iZHrS5UNdaxdBZULTS+eX" ..
	"EY92O/MDN5D0QNup16MRxu4ZNeqchstPkYrgciWJgo9FnEUMbQMV87RU2nBy2HcYExSojDo1CSLnDbCiHW764VfPYmSHk9aIkb5P" ..
	"hnAlAAqq4wTTLLW4lpxrZ7VEExUf3iUGfhEdyEDjWUSH8jEzo2tffcVXGK4rNc2VplIemCp7mWhFgaU1NLsbHm6/+zaElc0RRORv" ..
	"OIpb+I1bDK6lH7ASPF8GQcSTnjHGzb7y4YEa06Y+JvtDQd1IWv2//jWl1alBhtT+NZ0gsaHPAqEMQEhepzmX5D4pct3hEkhVTo/k" ..
	"irN0voCNnqNzZgWT4KTTfjXUEchgAW07RU7s7R4OWvZIVOC3HwG4aXm+FoZgU0TN7A4ndEl7xO3p2yQVoQJavNw2W3vyxLmaIfqh" ..
	"SdH+NkUNGAFqcZzWUIjIw6p1JFVsE0MOXixcWjzoJMS6hcdRVCcdl9/f1Xi9PvaC/3yX9HQYzownMnOSDuWRCXukpxdQHrpA6hOO" ..
	"TXadjDCxnk5Nc8lB5ft9ITFBoh2y4ivSq9wdgIT8X5Yq8YtAkUIiTy9pZItNEmhy8PQ/ozpfgCtY4vdn4B26K9cmfGxpJOONEBqi" ..
	"lZuooLZLZ5Ds1Xn+u4+S48YocObEnIrCQGf4sZBkvavVI5uSWeLjCq6vH+vcjldF+jyMalvX32NmAyaZHgeeSqdbCFclmR6DtBPF" ..
	"tmCQ3q9Fe4O59CRelvVAXs8zVzrzHV+efU7jmh9PwryFoLmp1tminFLnG4bHkcJqfHfNqEWs1iOH93v0AnsBwmnyyQDn/H/Emw57" ..
	"XruNGMY0S9lYX/7hW/94SlrkUqTJ4rUOWcFOIb3fcFZn0VlLzkxvV+u1jP5YTBGMImkZlX+V44zycRClqbrEiKwsD9zaq1WMp4+A" ..
	"cbV+9LibSKVy4jsHeyc3j344o4vIYhP1pOFrIYM6FvaKJtENHCPFWO8qmra5mlA0kKhZIxa9g4gbepZC4eBYsE4gMr6PJI8sjQy6" ..
	"P7k35yzctdgusiYkcanN58+3fMjqvgh5d9zB/ESkMRdG3oLqbwfVl13nnM7cokIbyaWEMCahbnpc/ki/Ixcbba41hir3X+Yn6svf" ..
	"qk1zVun3Ttq1MEbFmIoyYywGSf0SJ4F0wT3alCYzswCc9Wm6yZB5Wls6lQKGgEjDnhRMJSzDI0yRUtuWLqoxFMtyk4TxY87/clEr" ..
	"ko+Fi813S4IdPzbT6kQTKVTvKSz0hfpaZXChFmBKIvB/vKOTb62jz4zn1FMaz8QLI7jJIdjDproP20LiX4MCXJL37Dq6ZEpAZsNP" ..
	"lyUPn0aTo8xtaGMVraRiTFKFQ0Q1tufuryd0I9Yjqopf5BrBlkCGGGx/XTyyRPtDFijdGDicIJT/8Ndkf40MnjzKU4/iMaQpZDjq" ..
	"uwNYgwQD247JGYu2B9fdvFbLNHb4dp12VaThDFiOKPf4rR763sIbs7zv6J9/s4cUy9FaJjgl1bNmKGSZkjSmy2LkJoqKzC8ItYtz" ..
	"rxHUY28BbYr0dWAAipddquJ/j9lNg5k8v1E4S1T/JtOGzkajRp5kRtle34HvIOqSLlkGLW9yXaXxZ96vqWVRdp7T3R/nD3MnK1ps" ..
	"PYDPSWKupKc9bhNbwCWTWCfyk9m62ZwjnDJgmwefMMwyOfe4EWfEnVfpxfE2V3GX5SQossWR3Y1g1eTzbUa/qYGarLV7IJ/9e4wY" ..
	"GisRk7Eati8V+qd7IfejcZEt0nleEqhdTYJ/6e3+rAIcH2p/U/eGTzhnlipA94UZwwUASekUbCR+Ih6VOTqPs/ikRfAJPBuhTh2a" ..
	"iz1LTQk85dbOfkkItqnoaWS15A8CqoetepFSy4XQ9jhSdWUAJXL2PbuRjPkEhMqvBSHm/ACwb9wxd0JWmxYSBei36CqTZ6ERQq4o" ..
	"AWGVsvBcRIl2/qQ8Z1Xgp6XKvgLOM+GESjxbuwzoyaC9r3gsyhxhgX6UNjlXv1SEZ79W9F30nzv23gQwjNa8RCRuaPLsNF731jsa" ..
	"h8fdhPCvoXQqSBUlORz9+3/HGTDKutdxq7B+RTpC+WaZwvgkuCIFEg28/o0KzvVkblUIAsmu818q0tojs60PR+yK2pFyETNkZKrD" ..
	"i3hKFuIS4BeD2qFNM1YnWg0Pc7/cXhAhiNqH9jZcrcsPHDTJ5jvUQTBLJjRjEOCoaQKfH30y+mC8dhoNGKvpw9zp+ns4ru349Ypv" ..
	""
local PAYLOAD_P4 =
	"fGN4CozCmzCOAogbNnChZgdsAszhYYw/55dmlJ6utvBLXwvbLtrJ2XNAMhgetcxoaQV1pFMBs+yx3qF/Rx9Yke6cYSviMFT4HUab" ..
	"YhR/FJYRnYBD9N1Rt1GY14RocQD7GIx+R/ip+FtSLte6YorMEw3biyes5q/tEp/L7f4M4ThSd4sCZDjfTCcDpRprm8r2SRQ1hiGF" ..
	"xeEXoHCMJLZztpDf38qN8h8B/mMNASx9y9Hjjc+gCSo1ABMv/0qaCIgmL8RJccsk2KZMZG1p0DKlueAxU3Wbprzb9M1Z2okD0Opi" ..
	"3UUz5SkUsKhiRHP/urfFIoWtV2h7hWkZQ+jZqI8fd/LCdAhIBdw9OBWkANFuYiw50ZYV1VbhlS6sWmfRlqDUoNQlFcEo7NzDCetL" ..
	"3nfSx3Z0SWuT7DpLds4Wq+KMwtjSvXVE4F0Yd0LjZa6yseCwZy24ox7OJttZuGjN69bOZxcjb09RNhHbP5dKqtifFQjwTapvlLkU" ..
	"5mjhL+Acjjo7buLlZvIheyMRogMLOxv6w6OsLyZ6ThyTecqJ3teRHYlqqWDSjE/g9gvPOx/tWoSeVbI9BjtOgbG/uUXUEq/9suIH" ..
	"y62K8MCv8qRUHyNUomlkwALqEU6InpJAsD842Y9EMqIKeY3wGRCGXy1SCH5MqO7lY7MDogVfz+feaEUmCKVPRkyA7Kw4CBm13yMv" ..
	"IHPhb0sh6YaOOzVMrFOxCiNsjNaUkP48Gd0SJ2DEDh70BRIBLA/oOrjQL8qQwWnjbdbwDtw6MrJE7Pb4b8+kZ9JB7sDjE7yya8j7" ..
	"znzB9CErcky/4zvoTMp5HtVpUDf38IyQFb6Rd9Wm5bKCyPZZvAScRTruBdSNUx/QUJ7NB5RnqYVuuDJN553vrXRRwi6pq1g7/D6N" ..
	"VrSBUp+7erxegTz0Lym1M0TM0u/N1mbQWU0JfvGE9LjNKIMrhFjvl5xorgRbSxpjKrO60RP3EXd35y9IHV1zyXHBif8fAvnd95wC" ..
	"nBlQXAjs6bP7Ri6bJocoabdwQM5lulmUCA5MkcMEx55SdSl1LA5GCDgEUnovDK5vnzCMYGC4BZOvX7Sc8rigIa+o5nZRFv8wHFQU" ..
	"0A0OicN/kwkRURVvqbWy3QxQTY46jw9Pq+AIP9in5ZFxsXhuMyod7yLFrZ8KI9ReT7PO9uyMbX6CZ+1Wyu/6TLPYg3qkBSPiiv8M" ..
	"Dv0kpUYD5XD+nRXFlyOoYuBOZSCMUJKcZ6dmpgTTxCBfanIPznp1I4S9p/l4t3OvrCU59QsQfRjC4b/3+HgHXvMVAAth/L2AtXGu" ..
	"uPj9X4XNADmPkq83kaLCyTesi1o5Ar+RzNwRojEON8If/LH0aWoYop4N5KOVAFzOTupDhwv6IMU1QJvesq3fUAIowdw1IByQ6o4X" ..
	"LyaZ81nQ8vyVkN9DaU6VNLZ/f5B/rGKMIIU6Jz2SE5LNr1Nuuc8gd7W/EnqEX0GzXO8HPwFgaFhe4fLfre3m7WLPNyu0csK2h+7y" ..
	"fs+x/dDUb6TW8MEVS26+VJ73m9PKw7Z4Yu0D8wIGhucrPOfd3AY+WGkHv+KZV/7KdpYfTeUls6pO/+kKLu96Hjz9kuLd8RT6RS2x" ..
	"PlX14pmKET2WKyOdnrCMcSx0Hzy4UkfHY4h9n1pCcBP3wvis52XAwtaD21/zX6XU8w2DeNzzQWEVmJGufPFBbdrDJsAOOC5ojcY5" ..
	"iyDkQXgD97XIc8PLwEdtwFSd/QOxPqO8rieV4uGPZXt3ZcTc9jNwEgYOqF2AVzF9FzfNj58MBC6S65Bd739J0YZ17pF1pdYfxBVA" ..
	"bb+tQkaBuhTWkvk/l2ZRD/1ggoFQYmEZPFpHQlrUZutYskPu7l+efrqVUckOHFkDRkn6P1cNBO55rRQtzBCy8TbZeIXLmcl4YQiW" ..
	"2nlf4aT32CMRLavBXjbIEqTNYodMJ93Pk8WROx+ckjFT0sH4D/G1TUeEhiKL3HN3r1n0ZuSweJA5tNZM31a636knhL0j58YZJ3A6" ..
	"rOVU+P+VBsmbQDBQ1KVtljsx3rQLXk+MEH+CZdLRbo3523jddpS8dfvdEnPmFVdOE6lasJhG2Oid9G2X9teZbxZbJGbJzKrYUdff" ..
	"CjuuElf+xzDlWNaLRIRLNmxPfdrF03jFvdMJmgMC3DNfGvIj0KG3FJ6QKjOIW0krpfsFUi59/Gg9VmqLhGDLqxxCFU0F7pcC1HIZ" ..
	"22budRjtdYvpKVYcFhAVwabhZaqLndtYqdxH7/dwr0QK9G71pTcvQGXosehPfAvWwsLtxZCRUrl8uXK/QmOK3cADpfbRtAM9EGew" ..
	"3Qoac4EcRlKyBima5dK+YWPbtyHajEKkS7vMdmr8uvMe4SE0GwUwE9+qMgl9ZlkreGkg9aRonFjrloACVaJSeoFhYDReDl9toj0q" ..
	"nY7Qv6BvGC7TSaPG8koRJxlxmndfykRFG+jHH4S2gGzH28W6/LQdynb32vYJAuzPrd2Iw8ZxSskh15iP4Nal5ferr7uYu9rEPzwZ" ..
	"Ge3QMFZzIxDWU7pjDe1VzXSqHO8QAZOR/uUOUcgbj7bMmVVgrh8x5llugfihZpCg5pzSOfe3g8/FTkB/JzwWqdp4wIjA+/s/+lYo" ..
	"prpJEsf8gQ2Ws3oqejMQms8FOXCM6ebmy6qQvwzw+llQ3jlBiBSTZlqCxJEE6QvzgDA4FLBZtc0ujZRq8odmFz1WiGJPDxkMDUm/" ..
	"Gn0otp0ymXqRCqze1+Fqh557bO+7rdVQ9H5qeowKV2qvy94q1c1FatfIzHtZ5N2EMxeD5KrIltC1tXv55tPUkC1amJE1bqrCXp3M" ..
	"DzoHJOo0ixRrmTBT52yikmiy7W6crR0Vs9p+RXxscpsrZ6y60ETuvboS5BB/G91t0VcYTFPV3qUN2/c6fAeTF5bAJTtdqoZkC/U+" ..
	"UI9sPnsOnlxWGyefcqViX+dIpoR3GGs2z07UObYNtEXgR5kGIEnE8Qa6zdgBJqh5iyCJnZCkqNrvkZ0BUrW6s2ZYO+o5ouH9RfQ1" ..
	"zBUKGdmZXwqoAz00czBjq7s+P5ENI2GNNvcvCxoEnA2TwBm8NQHgBoaiTrSGBnO72jAuiy6g0cBESNqvn2Pj/jt1uDdv5PsFCcAg" ..
	"5AaYTDseTIPZ0rUElsAdH/D4oXQ9ZydPV0Z6Wcldt55VRVQk5zqLXY9+twB5TxMAYBObYG7cxcW/s5pKJCCB87YVALBu7EOo8urc" ..
	"mTcyZdEpBQY5YrZmjxc5+Jc6jqWKFBFrS/p0zBKo1dLbBrCWlcfin/2eSnWWRHS0aeEOJ+xBWRV+jNLPFVhvr6h96oz0fook93AH" ..
	"Ej0hdBPtzpqOCa4mfXqdmQMa36ioCwEUmRRgENuxNogEo60JmE9siO7o+q8eQsOwTZfbty+Sk0+A/rKzdbq8ytddgVAq/qJgyLGT" ..
	"TkpvMu4PC39KNNkXv/2L4Ad7un9oN9j6Gatx21tE9jvve7EvYt6CzS/I5l6ZzbYQsF4EYW9Aub98srVOcrSz9bCAOvDDzbMV+xQ5" ..
	"SbeXdbpB5PIRZ5oYZTzDstpVg59dBAu21++S3P8dOWuGhgmD/x30mjSxxEzTrQpI2n6X95jemW0i1gYRRtCm94j3vvB4HdhsyTaK" ..
	"Pll5oYMZwNMtfnA5u1FCiySboxv0BDU6KdrfLmDHR12hQhTwn8wtrnsCJkKuzzi+d31aAWH52VjK4czrtoomuAgeXx4lYkFcWMJ4" ..
	"TyDAtk5uGa/2cLpcEOo5fyxYDrNscW8yPqLSgMt84vdOw3kCdRX9sKy6C3rOGsPKUFEuW16l9IIzMpiMpzVRwqGv8+NbS45EWPmJ" ..
	"2Me5SaVnhjba3lBLmVilNqLhGOHv88JgsA5nl1K2fa1JdxxZ+VjePltjtab/EDiIxJmrHyhxiCrGCuD2xiM7jc7X7xnyutgI6Kpx" ..
	"zCF7HFUWLGtEIFcfu2691yHQHJmickz1qn3AgKZgStNQ8t7MYLW65vdy71SmyW/JL7HgPwHEO7xkZOOjflTrU9exQPADgScMXJlC" ..
	"wfuAMrAFhHJjpw0DGxCAdwXREkiD7Tw0dOBPfKR0ww7KIZZ3VQ2s3qa4HXdsPYDHebhZaH+mhJhqPUSl7NTIytAz1WLbDcgAuUbh" ..
	"C0TfphG+AIGsFfakPbYsWq3PrPT3bBxNLhXHdjaZ984x1x+NtM3lNpjrxuI5MgyfEMAnBfXRoYKNbALCB8gymww50FZYNOQPBRuh" ..
	"6QtcuJaJ9bk8BSR85me6v9j0I086NeTYPY83k3KJFS3TDBlTY2oqycj1bzFKtScpVyclEgrQnJBrS8uZGrnhkWBBriw+dvpxohfQ" ..
	"s68/6xM0+gk3H5Zo4jmKl9yjw0Qv73YpHj9NSROwvmOZ6VlkLKnYzfR/YSqkxAC80S8EnvesrgQnZ/SNmBLRGBx0KiNmxIThbVcw" ..
	"PT7jRhw7lVeJNC9tDwp4KUfBMdD2JPefAeQA0jic0ZA8jMHJUH7AwAl6vBmTgyCXCoIOKBBaiv7oe9D6LszVaGb3HjTqJyoopZDH" ..
	"/jvC4+EXdAuIQjfzrWcdc4hWCLSXA8RLnRzIdZnmVTMdoml7meeLovcKM0oka6KTY6EG2d8e9iuJNYsyMOFWMVW7IGTXh2OyGTIj" ..
	"SMSgehpvQXLRU0eY1mcvC7uXYZPeMAyK0FmZ9eBhNczlbDfmr39lrhKMI579oiw5cpTH+V+sZivhxPK8CqYGAYnMgK6otTeRMHuw" ..
	"xL6Clk+D8oze6TTi+NZ0KTrSRlBRAesiRfTgbm96E4zsU+PwmB1vw4Ca7alwDZKpZbQc9R9KwEhUdtwx59TjJt6vMK5YqQAH5MbO" ..
	"7Ko/3Tka8xAMk2G2H8veXyn/RxiWjf3bmgsOKhQlDzaZa1XzEPqsEGBhDtNvm5kvnBacdqxB55bqtbG7lq+5a8iOzUojOMEVclcj" ..
	"zkSlnq6lJL5IgmNERGevJWnUuE0vAuPTGAD2awOsgVpd8+X1mTTlasqHegwGYTodzaTN+gXUl+g6rAqyqIrs//NiClh3DP40QE0r" ..
	"aHHe2LXGhwLuy7bgNPAfYtR7CkTLUFZc8ejoen4P8+Wxs4oi7TrfsPhUB9nLbc9rmhpe5GKlg8vgHDffJ74v3thvDttYVHIRfXxz" ..
	"Di+aWYx3VCj4X45001gfMZMemtTMJfWR8x4UerX41ODFf+gF7o5YDO5qIhQqscVQxgbibOnHcZed12d6PmLDJ7gzQebhFqzsARMk" ..
	"dkXiwmGv57EObwt9orVSBz4UOcOg1aqItou0lSHscAA7lGfbvVCDXxuX/FZ9ypV98MpZ9y/cSIwGU9Z05xqYyg/11sw5W3TJ6oMc" ..
	"jJfYj7ssUP4za1MK/Yo9u1UFZ3bZI056MTTx3jtOdj6IFhvlSCepBVKM+4FZltnPswREo9e/35iyXG/aWgVY7iyO7ZTXzdwZKMQv" ..
	"5grPu/RB7vUVAUcs7wXeRIGMtKledoEx6qXUzTOMeMYjj40MaUh1l4O5sr73DOcKAmnRVhTn5Vfgxh9DKsGwNy0EuBUZtXfEy/bb" ..
	"cLidk+auOT7gdiApSfMSe4nXqaJ0YZhF/FUgcCigxQeEqUuDTHz+BCM27yvTKmEc3koDh6A7BfJgE/lZCosSpySIMgGZF+E0+4/B" ..
	"YaXNsPtizfPoAIvLmBIO5h2p28/iXfoZ/2++a6R2MUVHTYWjPUsemobxPqjPawVtvXIBrPoDfBX0wFqrHytLfKMWDNXA/bCxwprB" ..
	"FObW2Hzz6lv9nnlL4ZHa5lQ7S+gp7s0ix+95y1Friwcw58Q/BTemUeGnwnv0xfpXqkIWJX3WebRGmpluyHAECjlF6kz3Q2VDDig8" ..
	"w4e3RLdlSstJUlffqdSs5zHNTLIxdc9R26obcjiyjRmhh/ZEGBol+a8U1Amcxpj708Q3HQIYI7mGJSzL7Ev3nBrCkEYhpuM/PmD4" ..
	"LvuZf6VJVoL7yzk3k5awoWlxBgRnnmdKtff3a179qDASRrUtjj4FcYEzBRnc19PWbNNHGSJ+Y9RrfwuazucrWbj1eavZLB2Ou7/5" ..
	""
local PAYLOAD_P5 =
	"NZim3H7KoT/09ZENuksl3sJkO/G9h/ngzl/xCHh1yhFbCSFSdLlWzkUw3vwNgkMOBOTXqyNLlElqVeUn+6AwibuJRtjwoe6onQn2" ..
	"wDi1B+AjJmEUg03QomZCvcBy2XWHLE64SLZQMo1LzhDoZZaWCFLli8Add1AjYj3AOzVjpkLJ2QLMirEunWIYSeL6/tGdQ2guEQil" ..
	"CElH5ezxdSq9BqI5eyYHoFjN/YC/EQMHwjIz6PS3OpOFFXp2b1jCmn4J4jXBpcXAbp89YajlxA70K9AXUmiTPSmIqYj//ir1A2Fq" ..
	"H81k8n6oSHX/ZdoZMkGbcRAGTpdH7F3zhkQ7UnTqHARIhQCSAbEHy3uUkd0+orOcwiSSanb4I183NOP+Y6BAqr1hXUVcDJjX0pRv" ..
	"YIZaU4mezqjCfGQ2P0NgYarDwIFWq/1xUGC1O3uQ0jCkjSR97ybf85ATM8vOpoA0v78TIoQiowHuVvo0+8CMapfYaad4AYnopqOm" ..
	"P0MAhR6as3S2CM8rLPQ0X9jAGr6OkgToty/3WmuDkG3Mz501aksS2cSUG1kpQ1uZHoexGC6uQhsKD6imUWUyVPb80yf/g29WaQLr" ..
	"ddKiulYlYS8t8/AMW9NMa8xB2GuAnxJQuQ9ro+ZVjkT5XNkpm/pjL48aM/c7UGYJjE0nghgoB+0fVZWAMV8P9u9bv/9qyxQOujFa" ..
	"2GAuRsqwd1vAM3HQO13+g8qzpqWeK75Z8zbdzsoInS9FIYUYmAOkn/DI6a+ZxYAAuIYSdjaNWy7rCeZRI1GTqI8JRa7CVaEfHVpg" ..
	"3fcXO33WYlKRuzvP4baaavC6t8hpNm26QbdZncJxJ/dDMnQFdesQwfEFSjPZE8BDfzB4epOfbu+hJIzM+fWO07X2I4yAb4ICioVV" ..
	"s+B/kijdt5b8pBISKfiWNr6q5v8SM6wumvRmEcihnSzdI+gEYVC52rlUhlQ2jo/3rRXYwuYuFmF18OHN4EXgyW7hRcoXvxbPEc5P" ..
	"dJQrrssYgF9SXytlUpaVNVaxuahERq7dsD8qfG7YLNvkSgIW/Ye9o44GAg4hhPZzEMvdPpM0G1NKuVPSEPKxJnj6pa86F0RwKA8X" ..
	"0s+/WpGRmD+XF7y55si/gUF8maEAMRBmjoGBgZpwbQEZjzmsjYj1ahxLL2TmmR6YsqxB4E8w27fG5bPcEE2m6T/a1D3CjnX9Jway" ..
	"6UJxPz/Boi7vGt6sKTsmTZh0lF+O98O43JIZIOZQKFCvSfMt/K85GqRI0evuGPzQfejAMnpdzf4twiSVI0f+0c0XCdkZDfabwueA" ..
	"F2j34VW7SXtsllULZRDLF8qANm1vKeE7veHkA6Ff/uPzSV3YbU82iRrBDxMLDh7wy78DAxxPxjDIA1SKO+kY7oN/7PGfUwyWzA0I" ..
	"LYqQqWaZvxxoAen18TcIC06jlyEgot3pwljNwfPqny0dp6xFy5cZjsC8ihEZOOfWJU9gdaEyGNb7+pBI30YVSPIHdCDav8qs4Hgi" ..
	"Q23g0JafhaFW1mSDZE4QtRrprnyNjEHUwxbyCYwCM3T4+Dl22kjg6mGLcW/li9N/LirAhJfAI//5ex5S7T0ulXIIB7SW32fZwcZr" ..
	"gTNdTTQKykp1eXBk9w1nVBNqo+skG6BMPFCs5M98d3hEyF+H29FZUzsCzhqd9Y/0jS85tfF8taESKi7Q5pslf07stul6KdzSX4x/" ..
	"6EO3OI3QTZBUlIywphxy+y1Yh4F5PEHl8tW7eGFXsJW46iXvtdNmVrXNDGyDiufCvviHAtOhoVIMGqpLFdwi+i+BLBXY3rbzRK+A" ..
	"3o0qi90dOVTQuyMzjd5Za/CoMv3fJnkiveyqsG8hyqqoDuB81J48dN/gjL1D8XHwtYuJIyNHhxQ016zSMfXczLTRc1M1mi0twI7r" ..
	"cjX9eo/uz6c9pKc5cMObPaVA0CoUi936TyE/JUWqM1DLOP6Zqk7q6kN0kEMhSjku7n8+bJkzG9mLtkae0xLhSIVMMlqITEd+J4uK" ..
	"jfp7DBsspnjAQZuRBQYWVYVY14c+1RqXgb69nIgJWYjICktU/BvH6VRUGkdWsB0CCx3QcIDQbI8LV4jGKlMqC+FW1yTF7WWA3Xbc" ..
	"7fwMBhWQRmTwZAURkGBggqrVuLQjXX9AIE62XtYXG/ig1Tz7DMyj6FsVReAb4+dPxoaOaLT24AWOkEco+Pz0Gp7NAP03vdlYJdQ3" ..
	"YF0R7Y/q4OqaT9Ue7fN6saksJXtAtwWfgLFE0byylSK3z0n83Rk2EDnYdMfUNiDKJBc0d/gxIlwph05h8sx9tHjoRjF+lyMFrS0h" ..
	"M1v92udEIizoPvx9g1DBz9BW985pCDD0vBKwINS4XLYZtR5yhnjReuXW64VRwA4Nw4YNNujMsbsflf3NbGONo61AzoLsTuB43gEL" ..
	"TaMLbAelQAKIF4TTXj4RPBZpt0Ga6kO68qUPsF0pQgSUyNoDYgbLeDGi5uLfcLcOcyqpjwLgyl8znyDjJmNZGCvEyoxRj+PuHt8/" ..
	"MCC1lyeJTXstCDgkNXIPWSCK0oCMb23y1mmia86kEEDtaxj7XcKX3c4f25cuJhM7YmkFow9W4kgHu1x4cFUUSL1343EXbrQRl51f" ..
	"7/FbzN9n2pi+nRBTuSL/KE/AC0aLjxGXu7u3wTvGfUHCdg9DQuvW/u+89ODCO7X0cv7/JGebNpZTjzhF/rr2ZcW3gIzijigvaZfu" ..
	"oukZqP+coWjqYZpt9MinpbeKagGuDWB7d83zCp5WOBCW7edFTRJ7Jrlo2Y7tiQ/zlW3cp7jTayXBHBGkA4lPM1tj2DvpoiLN39N0" ..
	"z+VQ2y4mxTmtPYAObZDxP3qznHCuCQ3flNncl++lMNWdkTbsXtgtwv8WQmJFdE1ysHsg6SVhwa24tYqNnKG1rVqbyiDAx78GKpXX" ..
	"GnBaIz/g6jT9qpf6dX4uRxt0BeKVIzE7/558k0dz5m51t38A9FzrGkiUF7MYndiXu453cE5yh+DjVoSEKB9tXblw5JlOSVPLG43H" ..
	"KuGHrYa5UmlhQRZl08jiEjAfPWMBFJeY8Ru38fMLtVXpDOWQJPWLvEn2Ke3GBw9VRA2bi+CpQzswjDbPPGOr5/eU5qRfrLH5dFVT" ..
	"aOEqIj03xkachZYJaYmD5tyCd0Z5KLvbc3Nsdfe6e/K43u0Abu/PWvePvNMPiGjAK+RucxVpB8xkbAafNIby/eba5u+FpAZz6AG9" ..
	"aXSVrk/vACDasX79fVof19FmPaFLdl1Rt75w7NeKmcDJvJG8z9802/2Tn/9/Y4qQ+ERZy7lwrfONYNNAGRobyCx3N2sAnsiK4saB" ..
	"DU2AAwIVvi/v2smVWBPOA613KQfgfiE/3H6y5S65foBC2YmSS47bcOWnFp6Napn+TlsgkZODqq85Lltz1IuDSJwSJ6km6wPxM3h3" ..
	"dc+Plh0jZEUE8RRYj2cmocgJSzATwB9yM0f3swpf8Ir+LupX4oiRX2bdM1ao3MB5FeH4KvxLC4iAskBZoeVW1fpsBdESGCMxdku8" ..
	"/sQHWBjPyWlInwgQADfiJP6OXfFuwrgvBRDnKTZmm3ypx4xdmYShUg68lC3uGAkA9sn/OfJ+zFlFtFJJv5YNijYm/2X2LmZhzlFz" ..
	"U29wlZ9gfzaMS2GuLB39su5lsZtixf9A8GOpLQmawpagCDGbfh5ihaEyaSDOlonsvHHT0IKVTkbHYUqxa6p/CuaR9UDdC3VcRty6" ..
	"wMV/FGdbylBgAO4wAxA1OGM+LrDlF/lHY92rf97ZdctAtCWgjooI9C6XSyhko4/fUH5AVgZfbjSejfiqyYq4Vb9bBxaJOR5QHNOK" ..
	"2udmVUiDQ/qR7ENFcLxILg3xZHbZ7iCEa30L3l6ETBwbN4TyMsVkTTLxf2nZbZEJLM5qLWlqJkUSgWztpk52WTGbFlMliT4b8N19" ..
	"ebe/8uruSDyToPbXgeT9wvp3QW2ehTRqeN7Y6oqc3BKgturpAAbxiMvsJKyAFNCwmjIE9uktEx/59CtwbgXY8vRWqOznBHAPqdAT" ..
	"9H9tSLm4WXky8Qphl1TBraGRQ5lefEPeRvgw6pE+KyvnvU9TcdewGPF51bd1ZBLi4eMnY7yWRHq7wq/HMbmbYSF/g1ypQ/44Dzgg" ..
	"W9Sh0ZrZuC1KqJXrhLLooI1Eg5fgV4XlnMK7Xndhyujubdsu7nUqEr7GoLgIjXoF/g81+cXkwnVqzGGMria9WJMLHme05jqvgCy+" ..
	"eBmOszAxjunfUN2qTVFgf5tDp4/GBjGOa5ZSVZZqQ2USDs8l8PNjMXeewi2m0X4j+DivWzzZgKdKqNZjTYCSAuebgDtWk7B/8kTm" ..
	"1nUcrWzURqMFEKLpEsZrzHMqFb3gyQkBdoxtQYB5A/bLc2u7kPw2mkZ8vRKU4qCGv5bUV1/cUWl+8RihGJAPvXIYzoV90oQxyVgw" ..
	"XgUSqZ9LSqmCJN7c6xw1U8c0Ck/DkMvym9mX/7/k9I88+EEd0Kffw/4iCt8ds3LsMN6uVSe64+26xEbBzHaMZbhLsVMI6Kn541jS" ..
	"ze+LPSSfP84PdZnqmkwdErVMM1Rb/h1OBtjBcWU82PX7h62eedqgPHFT3qsfJJcDeYn59b/BOrb6DMjtWx5On0cb66NRJ7oo5IOx" ..
	"2K8TPkDgqbYLqL22iU8QccaLvXsRTRKRn8NvJoX3DI/K3kEnjKGzgulpl9NjcBb0FckUQ6i5WD0VRSMGJ7td52kawYzF6Hxa+U2x" ..
	"qKcz9lCZatpcUPVgUPCS/rpckmhfjjjGrkk7DUJyqGLY/OafbV4U8iaCBgLm+35nmG0b/UmUYX2obIyv5MB1uy2CDpk+oeM/SR2N" ..
	"IsdZxd7JmnOLyahize9y1r/ieIzw3b9s7J+hadz4xVi9OMLv4f6yAXcaCq6EvZgrNV3In92BgzEXFxkTybgccdBfqhDiBoIIjyx/" ..
	"RM+/71l4FB2R8BHKgBpQ4Hm0vsKlFHalP/qIpDgrnB6ZOaAyaI9eRNC5czUf1ryzqv6pcSA+16hmoDP0s8FGrK/u3xgFMdh23PtI" ..
	"fRqJ6KlI8YNgIC2GxlolR1raR7H3LYWZpgdm5P9MZDgtmxW+dDeQuTiKMWPmPq/rFpzvzlvIUKj7/psPEslJ1+y8cBBnU3u1HbLD" ..
	"UXZEQGOF7pUmdiIXkNF83BHedzpuavf6+VSOv89bZxb+4ZCMcO3q+0lXwSy88jgAkiNgGkzntlnozs0NFyltjJoTW4w8sE9vgU2i" ..
	"ca92hTYBzkucWQn8z7pGbqQUL5ULCq3lF7NJI+c5fNExBwRqjapYho0GjSxCnobkaXGg5v46Szz55TKhS7ohSuIX8oesbuy6wf5/" ..
	"L3uMMI1R3z/3OcdvwYehCv55gjgkvXdoMtRd+15dCclgFgHvbBqi0m5FxWub7NJdG8SpjLMk+8HB8B6EKw8mwwZhpW0c6rcaA2tt" ..
	"KAEr8wuHKPWwO0Hc7k1mi5MAANhnZQ3DrHB7axyisEdnS58e5IAZr9mOm8fH+P1U7DkEK2Uw/1J/UFm9nMIA5nsZfFjlDSlTt8au" ..
	"ckhlWBcITG5o07t7WA0RbqmbjsRwzWIu91jDURsZe5VQRupOgrGtMlhSZz6Zn2w5n/3+gyia5+oxZuBI/rSa6YTZ7kT7z9kIGXRg" ..
	"8OSemedHiwSmg1MXsBRY5Q5whtX2zDwoNFDGUAWHkSdtA8J9aPczDoYpvms284aD/LoGbXpLvz/pkcm6EdXbA/JAxemSS9WXawrG" ..
	"Mesh9BzBuN/xfpwCphYj/1/BYX+hlCc1OHoHLgkxM8D8gMinBVl9rh7v52fwnSTHHlN+lMLKAn2YfMCzyntA/2F7ZVPJ6ELzP0XN" ..
	"MqZ7Cn/YoZdsLBMt5jh8L+LbMQBj3WcANrVBIoons9fuwNtleMCSIop1yDAuVVQdhzY8tUnonYh9+wSAxwnbiTlMhddBhIJvTlUM" ..
	"EnOnqgsZA1RGNKcTirDEms+2uCpOpbz9Wqxvu+2DWNDfbn6skCt/xjVVzzL8RMxiOkkdCr4qXq/XdDzPozD8qq2mYNZsJodDWbQD" ..
	""
local PAYLOAD_P6 =
	"xEomO80DxQPLLoU38EoythJA2SurinGd36MV9UQjiYZL8CV/rWiIQChPG2ecM2sD+1p9BSWIRK73u8SO34dQWQPd5ULERQP+Mi8N" ..
	"XltD9AT5V64IVQOBJsxwPLsVKBmDEKuw2BPqa73M2kbKH/OqNPJG3/cd2s44eNQcJzzMxnzj3MPEVnZMfaF8hvtdtwHuycpX0WaX" ..
	"T9KaK22u4wdkjtJQFJFXGtMvpuO6lXNT9ve1AtgtPPlS0OequQI/h4aD8KuRYQ9pj9UcdMiZIKrfHwghadap/UQrGTmMYJYlbbEC" ..
	"HJZNIYIQ9JptBo7/vKxkjDUlTCC1YC1TXT0RjRVHThPIiARKu1vM9YEpA9ogcrQmIsgshyHWZSQUbUYGng8zLkYw7Uae4R/OJL9G" ..
	"taePrMmeA5wzfDlhJq1jPa0iaPGaamKJYgFcQ+QWRuTo/MiocmA2cidsTR25qXRRsY2OYf/BF9nAXnpZvuOMNZ7wU13k/YjaHSzC" ..
	"FdTldvScWkZZhi7C6yEeeMJBlPgAcZ5yPJFqcPsev5Dq3d0Q+clgGMAKHxUHcdbeyIT+Ca7zBu4XhUOE0NMsTIYa6OSukzW9FlCn" ..
	"BZ8Oe9NjlZFsbzHyBPKqRPEgQBXPFonMCwwsnL5hK6X5npyeAPJTC9LpL54cE8Edg3CyjW8Tk1iqr0v/Q/frqfe9F83uyq3lUB96" ..
	"Y6D2ZYfkOW2Hwl6krsXmuLtiFnxX3PyRZq47hl2ax+8r64X/bn1rdLkQf8fBn5/gTxe4ZHXtW5SSEaBLqfXfsmM86VOQyU27XV3G" ..
	"bur1Z8+vFt2h15R26WFiQ13E38fZln1RoYkTt6TtG61r/A3GpctPaC1TXyLMyAZQEoyQV3A6Y7N/e7CdSter3g05K/FEoRCwuGYa" ..
	"/akIOd0UeL2hf9bHUHD/J9uaJROYYE/87Z2I5lniSddq1AUI69Z+Gib0iZq/138je3LQJJdhUZaIV8flTgRf5bIznxN9O1gzrVI4" ..
	"tgLJ5uci0gZ8fE2pevhdihxTOrzhFU7T+rSSphv1OYqv7vUEf81y0e5lO+4Xw6QD4Wprqeq55yrxbFvYRh9mM7bbVkmRqgfpXFAK" ..
	"2WMvFcDA5tPOj3/GpVUb6pip1bA7aE30wL///0+RCzG9pEtXf9wKMcN1aW3XBRDSG/9r0wE7NAL+z5Y/hGZZTiCW94KThNdayn0B" ..
	"CqQvK2hBwX7uWWRfBSEdDIEQFCs8vHYcnwppkIOo6n59k5gzae9B71HHesWPiihlgnmV6ub6keFItRJtJ+jTMYpwSsrPk4gsOtrA" ..
	"L33n9HeSXljPP+jZwqksiVv39/Wu+XQkN1zw5wbEMwHmuuHyAdCJB4ZjeSPlIfRSosJ+ivHQcIlbPCov36YNTKZnhlRSqd9a5zk4" ..
	"2nMuNa7x3DMMS8jeblhuQbwaLFTMmcgPCZUjiitOZLVEzNv09eTk2a+F6VcvkrO8r0yPCTO1ROs6HGyK/BNUwhAMSmZHxOE/pwfW" ..
	"g0jR86FjbHFt6xj5DzlOeuKb5CvL/HXwHV228WrH8IGaK4na3CzWJ+boI1rDcQHY+x+wb9yzext1pJSPHhqPMgUPBWQhrr4h7YFe" ..
	"EDumRbhJoQfRBq8E3q069nAia1FTePWfrt3fLgrLm7yfWlg+s/GPc8uDOgEwuSYFIUIJ8XL1CG+RoQiGJyLlSN5MioKl0oWv0Ggq" ..
	"MbD+/yRBUtx4S3iQzfiTekAFiE5sIj9V0cLZxoei76ni4c8l587T8VPCI1Ot3tCLEbuHWCEO9CBj0t3eKdsBXlAZUZ9TpIGEKMvm" ..
	"NRfd8s/1W5kmGPCIA7tLf9MKGOhfxkT/u6wBuIHTgI+A/S7evIUTcbrqP4JY8f6f2oY1Dgq2z3Bu0VWerm5EFs0flgCM1Ta0nVmZ" ..
	"L93nsrJHpvzbARbZYAeJ0Sp9zUOVxQbM1CuNlVxqAIhjid7y/QwZsO3xLLYRAZOYnkTI1DjoCwOdedmt9OlfHsf+0/O2dnp4NdAD" ..
	"JYuFABqHeOM4HdhL3xtWY+biISUMsI/ojxNzhV3/oohZO6E3aMRa2EItNA14v45DaKWfUb8dy3LtIiu8ngqopUW/LwojzMY396tp" ..
	"4S4J7YI0JiJmRnWYVPmqR3XBOxqX19LpRjZFc27fBJ5PptnaIWPyrQs31/9DUzNwjT5M76ntojhQIyneyTS2qeJQgGLzHwNuAH6F" ..
	"xSw2fRj/lW2dE/Q92/0/9LOQ2LpGT1eaZSGY/h0l6VAJmd1Q+QFfZ/wGwP5lTLbuouoshMWse3Ef+/z62ONcXAL+EaikRw4Re/jk" ..
	"xc9ZVgDrA0mt0BuA28gnnM91g1bv1z0X4RvjNKvKdP4yMb0uIrAgKy+04BNwYOGkcV73k3OQgSmvWEYYXBe7kWJLXZU6tOr1Tf/9" ..
	"AnITh9ztQw4hnoRbUms0Dr6T3kGgAiihGlLqvtMhkBwhOyd+BCIFR5WGuYMGpIbiLZ4fKV221Iaj0NQQo24SEvMTXy30ujuQDQp6" ..
	"Tb8CHexvU6Cyi5mgQsTgaKvEoXZdEYIiHadksL/VQGMMOYNjIkNV3mz0Z/nY+3VgZD6Meinu0nLhf0ViRRJxGdQNfCDcrLrYgLL9" ..
	"bDTy0D2naumP5Y6dC2PC8mzDAUZZf3AzzEeFuS9BIdFRh2AlOPt8MrukYmdn4N6bhCEp/X31d/MUN3vajJBRiqWe6NhCdSinNAI4" ..
	"ERNxpN/fp6qqKVLP6md/Ac04m1N7bZNPknwK/kMDtzUsUgnzeFhZ0ugLEQRr5sO2X/qAferhrbB4K50mMvQAK2lyKoas9Ze7/ebx" ..
	"XBhmiutlnyuonSOR3UBiYo/HZ9B0rk49DI994EXKLOGs1UrEd4qICs7lLmne1NXvYD83akF5OY/VKgePcHmHr7NxI435XhjKOXZm" ..
	"j7/JpUkp8A8MX7tobUYMVs4ytA8NdhmAJbx67ShWKVSnH6yRSktw/rO9ACK6xSrrSg6dRdSe+pw1dt+lnyK0WxIBZkr+LPqVNSOl" ..
	"fnubjUDOIOVHbP6mvaMTQKJeLzJPMwAduBPGqSGq9lo21hqOasj//hdQbXyczsyUKrAY1cYHakUotQwU6WKxWJ49gSctDR36yu8y" ..
	"iMNZmL5DDXS8QGUaCULDiI3WH4YO+BtFvaZgJuM14tZJWbfnjqCC3dou1jdZ9IakSqkR81AA0jBfKq28G82H0day3dr4/DW62ulz" ..
	"OeGthmU6YpTcLaH/JU2mSZQ6uKmFFGbJGdGQa3xZlEst8tpc8fMcXuR1qOQZKc5HzOMasbsj3d95dD7FnCb20kQs5W3lg99euTXk" ..
	"BM2vTMfsqE/zzxaNFKzduichoR0SmHL23rcK5vj1fE8C4PhPbu+NBMeIdQsiJQkznGUiu//NgI12oSgsDxHlS0Z7dj3YSc8bQ5VW" ..
	"Mteke+jAemtBtJW9+2iF80BENUpe+NyhAX8aP5oI4jZYwm054O0IimrWpaYTARvu9Ks2mNB9F75W5406hUbP2YKtdDDb1KnXmSPJ" ..
	"z/hcAMToAj+wGRcITYiGcC8VpfLtJipnPJm6p1fzGxXAAYcd3mx0S08dP4jYveFTghMlDVB3ZlXOQgx+mckL9UrZyAfWoDM+ybuy" ..
	"YCuSUs51QDtHpkDTtqCORFg9Evef/Jrg7fkY8GV+mctl2SOafCGFb7jqACtLK8ZRZAnMjViNGuxT3tPNHmvi/6e13qPjsVBfUGGc" ..
	"5V2TuqcKPJMGP22T+fDQ/ZKdtbmGXaJO1XNqR4ZEwVTtmcr/by52EX7JkWyravnPK0r4fhBsAwUDWhkcz/VFLOVBiiEa+XaJ093M" ..
	"tGCZmDN7mhjbZlbG46vBNHo8KUEj23GkxZ5L38oAoDoMoObmqsTqPkSq0yOVKHLW5E3dhPsMnRnNAxkKIEWlywYBjeF5v+amz+ol" ..
	"0EaRTJCMpH1zbDHMlNZ5G0LpMx1XYg6zcwz1W2v3gcO9PHudmFlrRWcdk/IPJbLWIYGBpIgJZpKaYX0N4KwBT8/liw1RBTkO9kaU" ..
	"ExHsc0wsRXSfDVbMmRA/9Idn6h6/cmD5LeQSsx0ES8ufB0w5shQSjidYL6+/mmbFFiiBmSiWUhslFdu+tUCDRcugzdiDoaYehAQH" ..
	"vAcw5gpVqUE7KO6zxAk2REMZl6IcrM2EuG2co3kCrEPWt5Oo0XbT6C1bhSdjgMkDfY7nAc5+Tgr+uq9y1fBBxRmqmM4c5exea61j" ..
	"+Y/XXvyZCuB0T6DiYbdry8/+xkQP8iibyh+ZxtdHhiAIARD90l2g3+t6PK+jGPlyVjPfnKJMluEMpkJoogpJ3urQGXAJh9NEX9wB" ..
	"BtED/EqqsKBSUWL4DU1bT4DPHEdBaXW11CW3vXGPF+Z73R89CITesb+80NzB1hCVXCcNwtQViOOlg+TzpLXNAbufGVj3x8MkZPF+" ..
	"dKZ1eJoHA/jDbJLnn9mRVze15jK4uUMrSQHYJ3WIxiX/iuqBNOTOxjuQ+ropBkN4ppTmjIzylor1Qf4UeNFBG3eIn+ibLm4sxHff" ..
	"75FYCLYYYvy8UqHSV9j5f8pVK/edPbhMXQL+RJ0ijt840SgR/W0XFYL6IghgjaDKM5N5ogB8GW0uP9r3f5dLTUhKIHPZlRvo1hvv" ..
	"3mCsWg/8y0PPF1EJH6nUE0EzkOAs/8omNtcJLXIMisbGq8T8fHZSnLx6/RJhkU5qrxW+jan/kIAGpjVePBf5EnQeqla9UGMI8x2h" ..
	"Si6Ifua2G9d0wQ2WAaWorC3Vinjlw4Kus0qXj4nJn245LU+jmmq88zS+6AproCXCJWpCzqwPVKCQ3UhCNZQPi+Vx5RPqn8GTbm6F" ..
	"sJ0bY/NXCjV9lJNNtLV+GQiqJ1ipX+PS8ikxhRMuPFQtDQrAIW3LD2Rhowg3vfc5T3wW4uh1Vvg0xe5Xp6VkTGHZn6KlHpBcECOj" ..
	"lsbQTp7IJmKORg1jTHhVcItbcOa6qJQj7N3PMASr6FRyLc6Pbt4Tk0tB3MRq5miGfhOghz50ClM4QoaNrUTNFUrE7qWRMkolnzf7" ..
	"e3xFcgnbacQ/dHFlIOG8yb1SnjSxsE/j2rezNp263/ngS0yqJqTfBitX2RCC1zSnaN4kLUONGpJ00QpeTXqjJMmgqqq6wlnVvJ6k" ..
	"VurEnDnAnWG0fVBB24p87/Mzh0mJKGaUThMW8uHAd+5mW0KMH7iBsmGtHAeJp1cscubY+7GHibz6LwTz60Ao/8pJUgz1KYq82kiz" ..
	"iCKA5nj7aY42CYtgOlnswUocneYZ/KFSZiw/dV7jYutbkmx7t1Bw0Y/8e2uTJ2rQLmUiljXGADNyV3KKtrKb3j3znum/whZ0bWJe" ..
	"Hr/VIXG0/p0lQLpL3k9q5HgjDNAU5UH8FInxRxiNaxspPnLWiv/iVwdfJ5ccqJvCKFhSq+4Cn8qIeF5SgRYz84REvtl6I+0mLmsP" ..
	"2S+tZZ4GckZ7S18eDQJ7n2f6LkMDtdQW+uUk08AaqtRv9g5z282xIO7UU9D2Z9EPru4QizaBfQz3Jor+OApY8RwJa5cWcl+dkUTT" ..
	"cf7Z8c/+CBvbD2IqvaeFqKuS+zsUg40xXW80kl95iFrLYWhkw+gmprE8iIxWtA/yy2IrZJ7zyryA/oMGd5MSyzjTu7skHvFkQosT" ..
	"FdKe743dey4C6mu+00Ap6tn+426EjY7ZAsqh5AbGmJAmkGL4WvwrdYdJCUKPmz0vMg2fHDDYNvxvzNUrBQZrhDeurseBfbxmBcZF" ..
	"8DZ1wrk50cSvye9RAD2rCraquqsHkRR2fv7JTxhzhm1kM82AbUA2ovIvzSoLp7pJgGuM8b1e0Tpd+bdDtRROmSTVIUMCSrCSSolC" ..
	"+lxeyZOenBdprIR32t2NvLVVKFLX/kIZaD701IpkPKLH86alLHmmBxKC0a+3tjx5g1vXPWdJ3UrXYozdSglEXGTHDyGVXvN8hswo" ..
	"c/4k+6Rz3nsbHJNBfoOGHf6b8QftVIq+uFyDlJDaaw/OTKGl/wdI0DKSAUzpAT0dmLKvEcb4y7Fsktv7XVAVX0hO5ZlhioLwY8KO" ..
	""
local PAYLOAD_P7 =
	"DpWzWuI9sXGeKeLkCE57N2hEy1MfTm/1b4eUSFnygeAy5QJhnWwsIM+AnHZn5W5xrTSUGmnm4fSyiGdEj43T/pp7xDb4bD3ULepf" ..
	"HW/8Kbr/177yOM9WP66xfo1Fl9w+szew4cOSzeRNiPm3eUR4hsbXg7//vROnh4qWJIMDEg+9Gh0hKCdBhpCGMjqtG08xdZ203/Ak" ..
	"RnCCiWd+sLuBS3UoTet91WhhFZLnlDKJngiCjrVKKlTQ5KON4s0qTbIz5N02MS7dmouBUYn3bloxZyQqbmbZTlqPtbV/s7NlK6yq" ..
	"Gm+ReFxS65wCCACXHhCopBb3IFMYNQyP8KlLwIrdL8IPJTyW2I8voeRtXkvmi3TAyTlmIqGFRJ4SBPREjONkK6TdgpZPXF8Eq92v" ..
	"hyLBRrxU5bM75vefmYXLCajvLCL+68dioV43mJmpiWyEAazdJb0wNVUl851M5PHAF66+mM6UsPD2rmP7jY9zqTD6PwXOmp67U6gx" ..
	"7DSmgEc8PSJPPSNvKop6FBvzXsVv8WSYCa50LAY9StopfLRQtvbN8b+ln5t2RdT1y6syGmDMdoqkC64OOV7lLhWwr8eoXWn/7FJk" ..
	"NjPdoV0oE8abtze0Z/DipjqxgmkYKWnQlN7lPsCPzeTpybEdrgrdZyr5I76cxwQ+AQgMGs9b08c6OgWZSBQBsGqb9sxWMejKzrh/" ..
	"rlsuFNejr4WwmF8XrcCW0JKZ50P3wus7hKieB9ZXjSfMi3kj+aoxibmxpsfhXK2izdbanQ69rb4xjDpXN5es3W3CM/VKpa+A43LA" ..
	"VcbdOj43bFH8ON0j9+GxN3PZUfWym6ofut37ZH12bsuNEfsSyp0AKnlhokXfF63waeR8oFLT6CmyKpbsGE/swUiD3Z9NLFP+ro1A" ..
	"Pu6YksgHnbKWT9bsoa6naK6iBFGt84G7qSM5oVgLrFu/pLpS1Tbk3TR4go1osVnnTi293XvpjaB03BZEvF7EoXNsVC2KwPNydqhM" ..
	"+Sk6yToo6hdrkLG1nkAJh5KVPZu5JYI4AhWBBZ6kHXG4AVkyzKX3VZH/rYtxFEVeMWZuJZD4cghVlpOqLquiobzWS8tZohtEwsAS" ..
	"NUyFUA8OqfYJpW0BsXJgKx33aQXs+L8iZsKKJRAlaWXJGLFrojZaxwx64KAJgrFlV/ubCl5Txp92x8xYJVqUA8CyBTzBU5CbSBX6" ..
	"wY519o29eHWNHfuIxTmV+HV7Ufm8opKaU9LA4R/mJhgnnPZk7/xrhzHLifJv8idDWtjs6qR+iTRof2hRPxMiPrjUDoZl273KVVcc" ..
	"QtzfRos35uzu5MWYK9zN/nleX8R2NA3+I6SxYNgpljjqi/IHV12IvQ98uSku9lGEArRsxGt8oWBqpGQBK48Bgq5BEB2KvLlTKyaT" ..
	"65OiuxONZivljvIp/9nhlE5AQMXrBd03zh/3KXALSLRZVp0xn4L5NBRHNoCboCNe8loQwapsjCKqigluxGeUdOoqOyFAgJ46tYxL" ..
	"EdJ4t7a6wB0t6DTATuxVXLYJT/hE7RGaLhbsbR7kmg90ItB0jrk0DL2yI0IaXpvmyJJHtHrvA/4w5+TNA/ATemtAzlHZfVKfGgH2" ..
	"K0reNuop3tXNCoGVos7Q5uS9KtM11/J5QR86/bWvFKNS8TF3Y2TQ6NZnybkRyNYhCpocM2BKl71/4RTIEvb1/aBE0NWe1RiKRHhn" ..
	"14uD3kVeEIdZP1YVcvoUbu62Etix9wSol7VjmhAsGecqKaeGtfAE/G6oLBlE/eto/wUlqISwkgPegAm9cPOSluVP+lRQFEuiH/nS" ..
	"Lp/XcsB/F+CUjrXisbuiwrFohVhs+GkQgGOZzoRiwwEHVmmG5UtSbPFSxgTx7QQ2DfUdflYUbK97xaEv0oMY1RQ1wc8defWcvwJK" ..
	"k2MPWYzeI9BWB0M884hOPMsru0e9P+bfFFA2JX9LcwIpFIUP9qC7smOTb78+5b5jnvQ7HupG7dpfOWg7MWu2GcVz2ndc7asK1HNU" ..
	"1c3TPL8JZTuv1hKKfHwPD881nTPFgyl4grYAJzYiN5j2nnrg3jwBVDr309Kx96V0h6Zt83QxJaw4BRLNRNL/wXnqMAxQhlVzdo2j" ..
	"/hxfWHwPKcO21TqdSLi9aFSH09HdRjszm1/a3wR3DCbpFcGySl4OoJ+B0YIa8/ZxHOBAE9I1jcdwknSeZUmytpxE8XXrCym0o3eA" ..
	"hE3GW0l1JgrafGe91J4JHFY9994XHA4Hs93nGWBCW8/vOWyvlPpHfb6pMfn5GfNEvGIUycoeJEVUV3XiG4YM0qPUq14s28RcQp3e" ..
	"rDJe8wWditu9EB7cvNH2Xziev2C6l1P5P7pOKfucKHTKQFHpz1VfjL5i+N3Qwvzb4Mju9PcTNbeYYWbbDJ/ZYq/k/eTUTHnqH8GO" ..
	"VdalUsRTDFysXcA7L2mvSkJrPY4TiEnwAUEkFhLyv125Etcx55lk6Vm3LPRnJPg4Lq9Jjd/RijwbCA2l1E6e172OhaYEQLru0ETP" ..
	"4WfESlkhRACNHB2fvuytiSP3510f7tItD/GNvuDOu0EJTGfhjPUHzaPXlOWkvSwXRIFjW5Hoitih6LAJdM9G0AWx7sQNdsjDiIn6" ..
	"xh/5qi9n1K9F4byulk6ctOsWhjen1JtwUqDdhcfZSddEQS+6oxN0A6Cy8fLGFm6LCgABeFrPdSxVX8E9Lem7P5WejF/raWEnyqyW" ..
	"2+90OiVaa79nxHKLxzDOW8OoXRWVRJdGIySX7CEv/q/hlaXLnr4ZqrZoXYny3I9T42zVJ9IKkcQ3PB6HYSK6GF82si+McE3S3FjC" ..
	"2ED6f/eKvUdZWXZ0VrEUCkCRKLZeXguva0ZRHpSRGaxJ6WVUMfcGbyL4ZRb55JZ0/xNAFNXBM5JDQ39g41WYeX10Q7HDFHUV4TqT" ..
	"q4Gmq21Z4C2VjWSe9NJ2C85o2XBdXHLe4/Lfx27RQOUo2MUzhL+gFEnLHPnc7/76voqGLDNq6oPrr7DdOPuZrCzEQoOGETiidZqx" ..
	"hDc4N+YDVME8v/qhtL6kh0OtjfehhnDPUwf2yvU51/j9lgH/2ADfZwcYEU7mCU/Etgngk04Qv1URU5gIm0fdD9Nv431d/G5O29x2" ..
	"Cal2qmK1ba2yy6r/7NMbHybWKPr92XQMYTKAsYuLd3v9GDJZMtz0EXLn8eEGlF+p6P9PAgrG9JLBrxUqdVE2FTrGSg6/ND1NfwcP" ..
	"nm+Va5iTtOGOVmntEHzH8er0mZLUVTD6sAjmB6Op0CM7TheT3W1UzLxvfZk8r09aG+PG3EG5rjiqhQIFDf/v8iOZXVDquKMgkYAj" ..
	"vR4Qg0gZFV86OXVYToHcpbYbT68nSCQ6IR0pH4HIIvCen2fHN9jKVXJnC3aG24wy9Y97rEW9Vx++aZtH5izB2LVhfAEqlVFquJDU" ..
	"L13q3qEuE0SlrpHS4FUt/dF8Kt120fChXJ37Y93Y192PUCVrSeTYKv27dkYlXvapxyBtb8f/9kqbpHQKGlEGiDZA2B5iwTBP5yLu" ..
	"t+VjcKXqi+oUZM60qGR/CNrif0hGSzXGYMFoga15XT/DtHfVq2lABUGdeE0xdfvLmfS4JxY2tsFbmNWnLMupCRy+zdCwhfZFXRk2" ..
	"Xc/lU9yASohQYOPZ9uk+9JH24bEYYTyK+4iiOWwh7WVzqVnqTftxH3MIAcPFQpWYBI7lQ+cRWw7jV3Na7Lfx6Kdji2c/j3IbCU3O" ..
	"V1m761IZ50PMAjlEQ1WcrrzKkRx+LnvNoWPq/pvFWTmxr6nP31Al3SYl+8giqhZyv4kTyq+0yuMH1JFykPhnyex/oxtt75R/vxT9" ..
	"7YKoo3U3F/rqmVeh3PeXw2nFNHMZKsfbVCJ4gXPJ8K3sNARTjnoAd9AbTXgaHp/Uf8byeW07EiDegnVRxf2AqJkxMZ4srO+vCzUR" ..
	"t/AOGVbHTJWEqxPPEW7JXUZf02AM/kjF8XI1DWj0QTv6WQiXNML3sSKqOu8V2ZKTE/SY2QORXolOJIlYflFdZa6TvVKGSqAiGOjg" ..
	"WrnvjALhqNC2bJf5DifpAHktV98WXNwbKWF9f5du6oaj/qYcj8bM3gxqwb18HzyNolZsLzTnKOAqsM7gqAX3olMP6Urw6pCikVuR" ..
	"ONf2E9mC/ck2blfuK1kvlOt5GevPZCLPC4GK5EP2gLV2RXkQLYuuy6YMx9eXWRiLnYFYK+8fCFdqmMOrcJVaRw+H2pp2gpCgNjaE" ..
	"NbOfxcs4CABlIvK7ugH9be5nWnbFCQN98kbl1jyI7Q9LdFZU45L9F3j9f4juZcVwOk3DzyaOJQxbwf2uoV7uQjyq9iyjA2eC+XXG" ..
	"5qNDJP/+0fcKGMI/TCG+x/iSJydLV5A8L9WOJr14rfPTKM9+BLBraghRHI1YOqZazFQ7Q9i5n+kCn1AOKcVKy2gUmAoHiAMAwCl9" ..
	"pL3LaaloNrd7o3Tbb7mP+t6y3V1ExTCJ7O//pem1jPHJV3lnoV/5gAkceJMhDRSmz5uT9CB1jY/BYlk+vKA32yZUcfwGpWfxiFhj" ..
	"z4gD8Fu1gbmdk/3+BEcruY80E1GiYLFC1jT7/SszxyHPy9a/lkFdX1RH5aPWCawzrbFXlBvGDWhljVPlbDtvWrK3amekQ0Bwa+/I" ..
	"RI81rnhg0Bw2h4a6XFRNbuTGp42lH4V6IWu9JSl572YCnhUwd6mht4l7GZM+bH5puBHTfGQN12bagyuoyH9/juMTGDvAZtMhRVsP" ..
	"eKEOCAjFI54HlY8HuB8jlAmhQpttvju6Zp0jzoHL/ehk/Avsh2t0fVUP4hFGtctwgdRPFfDilPjB8DNPkaI2Kcw4mMJ7F3173UGQ" ..
	"fDagSvy4/D5e5BhlBTqxQ6h2XpYoQEHojKkcRn8wkLRkV17JjkoO7qBmfLA18FVCEx521Kin0bK1MBEndEDviuf4zj+AMgvevIIq" ..
	"4uQGHLsHlpA3jx71H6EdQbAgpPCdMzUI7j9AsjiS6o9kYWI4zhsi5zo4/PLTvcR7I2O1juPZymTxwnlbLPvuAMXf7haRkuVQfWtD" ..
	"L8zoGVKz6OHO+Q2x53BD26/raDT/b0rfZUFNTW4izdv1ttGYih+BUflwoQjusLqd/mqs3PZgU3s0iPMCQOgLUdbcs3Viz3tH/mOy" ..
	"7xS3O8WMGiBSbAgDe0kOPNOfMcwPLCJQLjkiXVmnFPPNPSLvUlMdkCK1YTqCpUuhj2XNAkWX/Q8xfDzyshEPTchmixhEo0282I3B" ..
	"QpRM/jgpwYWK3mz5DV0w2JlZAYv42yMMKicSN2sk29VipDkQTpgZ8KnVbhUwFYUS8CW6/4rZttA1BrMN6pyvR0lljTK4oAxu/baq" ..
	"75/oWshBlZ4T9FwWTDRI4UMXYK4vpGrnxF9uOhfs8X571xp9xsjV3BEhHGVZhqHMdkgWC0LyhQhv6sDVA1vg6WKiWmDFyRbP4mM+" ..
	"bBlA/ruSM9UmFmtmdNynUVZ5Dz5e/9k0Nw894DPKkcR18yjMdc8fmhzMUvMxRaWfIq6u0qF8CA34SM6/s/d38O5zUw7I+vPGY3gd" ..
	"MRmFaYHAx1MrLX6Xd2i+Wshq4l+HOlGUXxqcHnbUwZJSkMbPpyFoHVnhNVQnGU8ksmAC/3Z8y4aBRbRDArAD7C4q5pS1jKskXPHc" ..
	"moFos/ilDO/okbO7JTxx0pTwwH+KaHO/1SWOw24nivdnhDiYxmwjg8RJOVUwY+RnUUCyLehZcx4pFQkfkt97tq1aC4svVM44Rszb" ..
	"/0CsjvUPOnQ34F/ib/2kv8FNKl1Qf3zajIChunLVxR0lNig41XIdK0sXV8khvLzqWZidC0LgAJNzM/yKzVtuNJ7BEkubd8GpF2QB" ..
	"yRSAwdhbZtmjzvk/bptZKAiuyDqRKed6akyFiorvz4eStakBguelXtDtfTIflts9phGi3Bsw+XbX50X5D50HEkPf92v0DjcRd+wU" ..
	"LWZmcucaNdmdp8iRd+wGVKBD8wzsBbLWYhsLrmzBCqnZfkS1WjnYrvuioMCAgXXDdPhUw7r7ueD0mQYE14E7GG+UO70YmmmpnWJu" ..
	""
local PAYLOAD_P8 =
	"Vy+BV2ndUKWXfAeEcgoo/IJ1Q7dlcxlGxWw3dn4NH2VtFoDVMR8q+YU27P4cb3gmuTPSOm1RT50GiLp2XRPj7N1bz+4wNao7WA6Z" ..
	"Ttwamx5+lHmWUGJCh2ACoN9D9n4XtWVGB+NtxiMsI1tR/oVAi49EYOOv25Hq9larYKCCO2MzB1FUz0h26MlujkEWCzzv+7iupIHg" ..
	"HE+7lt1g/ZPFGCU0AP3kiE2DPoFH9f3bZrxa0kJP/SgN3rflpYBIRI0OaeA/xr+xI2iWy2Qcrm0GLj08GoRlBUD0pZ/Iwex0X7ke" ..
	"aaz08whw118/TQ4E6ppmzBicV2VwXdQ7jcCS3GrcqVGR22rf++dQeQ857YGucPKoU7Rx8hOw0sCWKc/4cKYVHTsMZaugPJ3ooG67" ..
	"E/XPUG/1Dni5aWiDVXerAZxpzgQoTtcYtztSYOEn9y0mV7sc2IF/5be8gRlmRseuvUfoc/pRSGedmUNcgXcdAeUtD3jf3gbuKe3b" ..
	"EEIUZR94qlOZBgMtFwCOIcc642ifVYhMNRPFXclelCwuSx75a1ClP4FXkCPcpwV0Frq9nMehOyu9RvH+csAmfXz9//s+QtfbioaK" ..
	"JYaqvDfZ85J71nElutc0nVpPTFaMUBC/elBH69O31AnEGvEdmwWJ3YG+S45LkLxdqLfCWa/EOdRBDjw6y+rQgw7YCXfeD2j6Kk3G" ..
	"/jWDlIHHfTQ9s/h7I1E0dsqb+2inDoKE1qmjB+ukaQWUxs9NXwxutdWJCnl5IyzZBCsJbjnJAqnV0Z//BNyvEqlFWwdPHvR3QPn5" ..
	"Bd1mK4TSDov212tgNIsJvXtLsLQtSzkjWgGL/Znx+khT+kBDZbAtvojSVIjdXKFRep4PuMROzFwck9cWdofCOd8WXzC7peMDLFo9" ..
	"HrXSancdOk141oDU/xj2mh+GS5Pa5jKr9pETxih56BeI7Y4v4IZ+H28VSTvfaAQnmzY4c3TZZDPGHnvQ5VE+DXX3k0eoZnjwjlFg" ..
	"fyRW1xj/FmDDnPk2cYSIGvNIJWvDaiCUxWUc49mcrRlntFzu5Wpz2SbaHYmsuGI80xdklhPMzUPc7nYooZRHxdHbi/xlQpvaZlTJ" ..
	"STxXlKqSthBbcxDNKDGIgYiyxYpXLfPybMbfMaxyO2nCm/MxW9Q2p3hQIJYN37iYK3hWnf+lNpf838pc124Ny0hW05gb7xQNcad4" ..
	"lCUbS15IuY7MmPFTWJlxmsm8TIruSbXyySAGpTFCle4IGy6Nndg9dQTJfxGOUHaa/UjepE3dtk8GbgXkGgCqqPpHJ3TMhYCbQdtn" ..
	"3vkyEwxxo8d2e7LFxAlbb05EIajohdJWUsd2Qwln/G3nmPNercuHATv0Ef6uS2F48qrBo93W/S1CBQqe+Q7DNABkxRbc6bFqjWmV" ..
	"wQ/sn3K+6DCbCJwf2ebYGqmjL9wYXt/u6ErDHrWXzn4Gp7KNd67SmHZxBL5KuxbSoU/+ElSdlz9e4jdVQD0TB4uOAYZ8UDJeWXYw" ..
	"gCXhQ92Wj37AH+OBboJDHHglpAJAaDIBewaMCalmUlhoUukHoi9is6E6+19rWdWRcej96NF92cICYMbbxMArWJ63v3Ubu8yqowzd" ..
	"A93hMJZw6PCmJK/LOhLZGC1IvPmhqr3CAIHylTGZU0WdrQZDbZ3cS6nqFfOeW+sltOtmbJzZ4gp7Vfi5Y2evGj5zPX+9UhgMQozN" ..
	"M8dAqmfkk+ql7n9Sv9UV/iv1Yx1NoUIgBOSp0DQEgCRl/FneIFbpIV7SPwDNDlW7QzrlFYBFzxa5YEzeLG6DfgsOW+nWJjJOiYWZ" ..
	"ynTmCm2gJL0n9QqXrFeE+aLG94xdDxSQ3SKGHfJXbH4iVU0VmPDto53ekxtDdQiPEziHYGs4CJ5h8PBANVfCgC4d2/eAPFdzzDhU" ..
	"W03UULAHaaBPEhDqIUzNkKj1v5Z8P4XQ/s2kPCex8YjVZfXtzlywR/yJy1oqLvZeOLdaQZCyee2bTjJAN9Hs8b36C8TYBcsX5vCQ" ..
	"XyQyRieP/TEqbzTduTzITdX58AxmaSSbvdvFokZGgihiYTvATbhFspatWzkJRvhH4sOoPypFcIkk6IvyeIBIhG6CjQskEOkBpvnO" ..
	"90c1FFHzYTSkleUS/88wvuH82tKDYcTmktVZskBYqzbUD2g3vsO8vdn3f1AXpt66s2cS3oJoQZi+pNUydEtuDDyJfFuUKC52ITXX" ..
	"wv17BGAhxvoINtdGfAUq6ccC6HlAgaH9lkATmn+CBPis3Mzm1MDfgcvQzgQnr9rsYvMD5iB+PsC3AYodXt+N8d4Io6QspnSqCLdA" ..
	"eK0Lm4f+euU5hwEmsQ9aTK6dikwGDJ7PULwQjcZkGGKbFmR1ZeQx6eAhHkifgwIYZiClmqn5HlF/hh/nyn94iek5IM6xRGkMOU3u" ..
	"PbH1moSwG37mBKoh+O1lStmk5D/EVINTVBFWWbIBVho9Q7b+Cxiuh+tl1CvbOU2myDmFk2oqazZL5j5zats+aCSC76c7mz7hCLCg" ..
	"AuAWTmWcHGgE62SQk+5urhiWh0fcPFKVZx7Jdptrh2/7fT8bm9emlQb8WbiBYm1/gdIkyTrhRt1bi8lL5JHYdHFwyit1YhRXg6D1" ..
	"hIiqbBYzS9jdvQ/mGyBvHrl946wN2R66n6ODAx1/XwIVPM8QMgt8haznOKkpO8K1dd68+QMdh1er/8W4sxwSNgr6oCheNlslNQv8" ..
	"/naJpBDOE3nYUhTFrLhiHSWEp7ARGLA2kjIAVM/XzcMhvXNutYpkKNeleVo/pQfRbF6CJisUsGXaoVzwOvG7wsRoNBgxGA/0vr9s" ..
	"gw8my65RRtKgcb5gp+tLNVux2dOLs4C6kunVbhv1Py4dl/LefoLUu7PJkNgR8h5tX8Dpe0m72CF+pRwPEm1QiNIxal9eFuTTbzb9" ..
	"phdDGALzPiG6RwOeAkLnIwqG9IGBsqgtphUlY8dA63PDt4ZEs6fIWvMLeH67un6RCHqIbIbb0v1rM4HXxEhb43QUKzxPqmFOCWT2" ..
	"dx3xbke9FLgUl5PKlS2bSFyOS7lIqVj6zrqINSZzVsL1UBBXN1E4vuZXwVT5pHPtdcWzLK8JBcDsqSpsUkd3EcnDFX4hZ0YkIUrE" ..
	"UHWpDy4OuSkyheW8uU6VRp6xoRXXO8CRjChR80WXbEEag65DpTAVAVZk3h/eC1SE41Tbiffj40dVwleZZOhEeJKTOOzvXRWhM2kh" ..
	"A4u2pcRF7MXVesjgpGrPKLIzszvevrTjsyLUIxyS4azde3xT2PuuV1Yqc5g6PC4nEZFkkslklSc3bezq6A0UgbettvKCcQRT9fxV" ..
	"9vViwfVdlPU3WJuu1hFC/+0MhL6a466NMJOpACoJUVCvOM2ZWJtkR0gfbpDaXNqYcRktAq10+8pAsMCVgrtlxDmo/ZXYFrDALQ2X" ..
	"sz5DlGHYsym12y6JkLqjcQG9i9VmmaAvVJ4C1EXAwl8MTjOWOzyqsIqOuo4Hq8xzdom1g3KwP2b18EfB3Id+aL7giH7Z8OOl/iK9" ..
	"MHX2WMeqfcVDMfheLlsSDLyTrG6n0c9OcIGAX21F+HQzknCaP74YeAa1U7Hug/YXoGoh6cp3IBt7juo9pP6OIERCTiua4SDZjPZa" ..
	"kzo+RLaq96+umdPNmxlSjyMOChieiHilgzfpzsbL5IM60fIH2HmtV2atwY5OQokb+mfJuQqYJA7Vzn2UczyRu1F843ah+vzPvtp6" ..
	"QJqN6qPet7cSQWRlm9Frf1SVm6cRE1y2KYgCmOnkzyYzdmwCnIPX567TH8JrpEWyl+fYUztuihy208ngfxyd0ttWY+3xJgR5ToYS" ..
	"VLnwUeZWYoScNL5+6E1WfWuRO9YHrZoM5SdKPIyPMsy6hFaDAaHQJKCkf+uXxI6dqkjqjOms4aSeAcwJFQ+NnzKDshRroc+kOilS" ..
	"6iNhsdxWdDAjbwHDFTKsFOzIb5vkmTaxjiHPGpS4edBLUf1u1qiFmCb1boREANq+pkWS8SHfmBzRvZX88YIVAqHQcLn4YoiAtSH2" ..
	"asJFeSwNtb9MX29iElCMv6rBKemiOSF1Ejg5/5YW0zRaB2oY/bgKcjg5yXJEcv7/M9TjWAJkBnJ9U17BNiCyQTbZkQPSShXKyzWk" ..
	"EhdK0v0cmbvRwzVjNB3xn2KFOeFITrfpzuPBXEUa5ZBCAtlhc9IVrfkjsqrMvUMEbQmmYI18tTTP7N6dx8WmDlLqqZtvvBAZxo/n" ..
	"mp+oe3bYAFJjD2inx1zS3azxk2E29hpKr8sprrRbCD8OwsXqTpVzXt79mmjnBKlYLxxdV/guvsTZPuNkv/iLSKN9wKNy5bwn5/De" ..
	"Lf7HETG52ZX3wEVbk7uluLP3yLV41dHNZKSZOuoXt7l7c0Cx3NyQM33TFWVIKv+MZ1+kHspqJQyVwI8hW4Y3xG6t3PE6NzyQFx1M" ..
	"nc6VuUSFAowrImznwWAXV8H9x4naAobetFcv+lwgSFf7u3Fro6/ejGkCax/inFVkgiGiAAN4QcVz0vJAjntCeb05M/vlIdR1NH/a" ..
	"KQj0ENEKCLdpvE+HEoOOlxtvbxDN56B/5YHGXZncbAXurKC8NPE4DVMdYpz/DGZkU+62hickEYgtH/cM8UQDOXLy6erXp48iUD03" ..
	"guuC1gLPLEaP0Y79/2BekEq6XomB0imf8/T7g7nweMkgm9ocCHvZYn0cbXTic+sRdAhcHtPXdRgYhaZZ/Q7VqkPxofBkaQMOSv8b" ..
	"MSvnvth6Ikgw8yLaxXWuL8qAj85sQW51yl3Yi7KH57XEl6lcLJtPzSRwY1DAAfdhaAbHMMKkNkDT/nBJcQchva3/ttcLhatpFSza" ..
	"TkFK4ltmdpWA3i/oXXGyxqcKejtET1NWHrHB0Det6GuTk+p3iGgi5htym0xfnf/LAlXr6XSHxfigeY+BpA39Iz9glaOvWhlbdfK3" ..
	"XsD3xrzgnqoC8t9yzv7igsFPZyhVS9mhLKjl4pVQRFHbSCHqMgj7QpthsAEQ3ZjPFvMNY3uKEoPsqvW+fMvddCeAEPxRkkUjKJpi" ..
	"t2Mhg5/PmauG9fiUvc+DegQdfla6Vj4Ny6L6abqgvJHu9deByKtXeh8A8J7sra0GLeoiVXx+LgXHBc9zTETWgol9+i4b94rp3a46" ..
	"KuqbL3Nh6damxejLJsJASd4aKtVjS0nJBQ7nB3Vmg3+30GRdSxqEVsM0AWAg4Mv4tS7XPMDwrWoz3yTIdp+BeNvankeWBA4lTcPh" ..
	"oZDrXyGb0a9tXE/SYrE0hjhibPdaQa34B09nhJXp2RxWvtY/Bu5fRx2XmHdDQJLYvYFo0cSSboQ1+a8faYg5lEkIEFwZa/Rk/WVS" ..
	"WgoJnEZht+kFR3+hIanTlbe+Y0ovPCjLn8c8ZHjB1Z++5Stkcngtx+Hja9Pd2RVr/ksdJU8NsOVFlSGj4Qa4PTBX7mMpeTT+Bf/J" ..
	"McF+2FSLHFlTpKK3UbkSlgbT603+cjWjfD7jpM/d/T/D3i9deavYdTr/uGO0QwbF2ksCHTzXQCMqcZCf7fMaEKztZdIUZmv0DGGA" ..
	"Z9JEm3HbrIeCXJCxEV9Z2i/k+GGyDR3SFsQm+XoiJkbGGZ7VAMwRx+Uruq/U/4R1UiolsGWtv4Ck2bLtc3ddmCa+8mZTg/A9kFAB" ..
	"B0rc01xKLZPg02MOM249L19emvh+3kcsPodkHsGL5d8QagosJUN3OErzHK+bffmAhPWzqgL2XyZ9p6ywDyHLbYvZh6ka3wCT2jqv" ..
	"UkI8q/azAebrDMt7X3ACEQQI/hNaV1Ha91mKWrL5vFHAiEsT3BjEC4b7hPl+VdAPx60VwrhnMR/eU2N7SWX3XN6LH1819LMpmv+G" ..
	"770RcjAJHsnM3dGuOCFU9wfUFmfg7dU3dI0UhGQ7UXg+9xPGTRbR0K/wpQn0gtgtVca1hEc1yLSWyAqPWDoiQjJqnRlLQDAs9eKf" ..
	"F+rr2iv97qcAoztavZaol8Yds5r0iG8FjT8p2RgkR1I7HKyFqK76ThD2JfANBRRr0orDjX90QRZBGI0QkGCliaakwDWMVXyOsvyl" ..
	""
local PAYLOAD_P9 =
	"8zasv8YBIrXnjgM48/d6KcjeFaie96w2nvhzs46DGc8pQU9rmqo6toj8EXTMA1h/W1/zuCs4QPhXvZ83cK6Viqjw0jHEnn2EyVXb" ..
	"fn9sQnGshD1gKswYAlF3GutMkenksOzHVwHDl4+FCQm62gR+y+ukVA2Lp41u8XUZJ3EEo99+ihjVUzV1504agx3cgtdtRs9KYpLz" ..
	"zvHODwHxXADLmxZdsAINvjdE6BTCNMxu7z74mvLOSqyc3VwBibxFngFm9RNkcVM6+7cJ8dly1U4G1nP+h/TSH2b0mKGy0bJsBkFB" ..
	"OmOtRhrnOFoWCfofrWOdW8CsHjnNAKkNvOrv7lZ/sYy5FMymVuA/I2MkkoMWBXq7VJqfwsIKtSx04J6sN+2yDW4pW6KHr+wcI2o0" ..
	"icMoxpkTHHiTF7MrqTBIWsA95bC5n/N8ElfYenhr36KPczRaLjwOVtDr0Pqk8sbPJ9TGpAncLBRtjb55DvbO9UkPkFxahiGNTM+5" ..
	"oLldVbYNPFyzFY5DIIO2r9+Xo/n4D8Ih5iXKUUbavM5nkniEKN21TXpsenbfjAJCWe2AY+xVS3PyG0J1fon/AsiGk+Nw/WLJ0W87" ..
	"J2iH8OFgc3zyHIF2wz4DXcHsdV/hFG1OEec1DsCeOEtXhMYfwmXlyxqrW7iE0dsJ/HgAQiKQcVDwkvD8rnCJKt20S3b9BwTJLsB7" ..
	"71GfOrnUH0yQoFDwa8pq/H6K3avCAzPrrm5kGtobZIzdjJCLUTpTtHKz1yOTQBf23xvbHE906wHeZn42Pe/m5JODdTLJzqZ/Rlz6" ..
	"vODAerzyvGXzfPZKFt6ULnCLUm2iHbw6d/t9GDfuGzc8jtQaaL+D0i6WycIJPo0aDgeevlgNjVcKWvaAbI2WZTlI2eqRZM1pO1bK" ..
	"BG6S+Ej0mxGmjhECBUHjdk47gRdhRoHVlbhaY3rSs8D8I2Ta1bycz3TDvK5mBQveSXH8R/Ca0WdSDZFTDZfnRpUr/PiA9uwVlRud" ..
	"bklmglljhg7xLJn4a74El8qzvzy7V1XtSMovyD0ytKTyxpboJ6uuEPXIcC95mgjyt8JPkIQEXNhFPgO8tF9QLN9AaQ3LCFL26+D+" ..
	"d8sMQTy2dUwzsAi4F6XsfEFODcSQCvZrDW7SokyevLCX1u/qnHZGo51wBQlA23dxaYRlA7wGc9tSHVscuQhLg216lJxClS5zlkFP" ..
	"Jm+UBp7jGEyMQiMFzwv3QejyATTSu+vYb4Isb1hH4hrz365YHxVpQN7jvp5YkakYL1ZXC6WkV8CU7GQf5XOJNPcu0TAnZJ2b4KFo" ..
	"+Hzg4Caf+oFmAS3VmxdbmC7et+EF3AzpSjvrYkb3XMPCXtpDUOlc5osDz480LV8lfCqjSbjV6cb5jbs6k3fJ7vrO7T1nX9A7H5NY" ..
	"Wo7SeGZ8Agwp9RlB6RFP3QCSb4rQZhH9QDug7bzHuKnIGtPwIR4Wii8VKkLYvA8XOvMBa2EN3DJZ6bWrfnP+vhlIoADu1gpThsoO" ..
	"tLoveMK0csCVmtvqyxFVdijCoJrqEKqqjQ9HjiejzQ0Ju7FX+cikF1iiF/cUY/0HMgj2N2r991M1itHgcYap8+8kKQbleOutcmLB" ..
	"mzazCcqotzp+Gb8E4UNdzgZ3DLoE9NfY5JOhr7bTMebumcGmMcTfzN+vKS4jBgJz+yMbtenJ3pbt97sHIG2UDQTWxBjvBsb+3N23" ..
	"H3EGWi7xA7Y4rfoIR6V87xMaOxt6M3Azl7/cK2NMD+UZ+wEnNFWq4rc70snadZZ9as5mw4PcLf70bJNSU+s8M2FF2D3DydIzDz9R" ..
	"q3dmvtztgn6UDrzg69m5YTyw+ZOSDLMxm7BGdC/uVXGEjRGaPhaWUXzQlXvavTi6eTYiVK9xjDFvqLsq1cfvJPyPQGRSlLbgVRek" ..
	"1Kxz3U0+k6SojjkKDcyp934s+qbA67fo6rYTIulbjPKkKRl9UrTq7gzefX5ZeMjR5YhWfZz2Z2icoZt916GoOUEJ4m1KKl6ue0ZP" ..
	"6EmBOOe2lEytszxzkKUP/mN9IxqS9cLI80qBDzUDqmVEZxzIDHsw2lcoFINo9vy8uvPu4wBciXCoQE4jTK0iX4RJ7tz+ywDrXTRr" ..
	"d+X68N1xTJeZ4vA0PUnnAbTqeKkbqiAzgRzgMG1mudjBN1HUvz/LoTB3M4/2A3BMgKRddQ8DK0J1IvaMzFcRxMp8gO+pdyX+Ythq" ..
	"EviC/zam0/sprKfiim9Q/JsaNcCroWiL8RKTQaM6dwNcQdK8qLscAqQNhBqzzZgwggNYMCKHy7NMPyg6i1xRo0QAUYxBLcuLnw5i" ..
	"ALIc5lM2KLcXX/eAY6/DJjl1k7xeQiTyE9Ifr//wR1a8/46iG+r+4jGuaNv1ogvl5C8VDMGthFS5HoHy0r+SEhT6Hqp2OB24lFpT" ..
	"MpotzvvKYuVweEAq6ZdoNU5R4gUQiZv82vSvOJgAwcxBhMveelUedoNd5MCMvFx08MUFwT+NNeDDGi3S/agRfb/hcXZzVZUNc+mg" ..
	"0DU9juh2NOIvyYYDp2qQlkyZSH67FCYdn983/JAKuGoYZ2ZjIkRiFuDxiUL/Uy4+06D6svT9fIL1H2AeUQGpqCddkgjSSX0K7/De" ..
	"pfXqBp542wuBsJSvPIGoCWQpALQSBChljTAheJwPN4C2wz8zglR52fGS8CuBIZg7rbDRcsm17uUbSKmZrMdDoNY6gBstmGz39NJc" ..
	"mTVvXRbA8snIKaoA1LCikqxq4ceSVMQHH3n6D86LWljJZ7EwnCGQZEjSPFQBUR/R5VyG8kFB6nRxLn64H7ANtucwo6GK75W2ggra" ..
	"wTnnQbDWr8/MvAsID2ubqsf6aAqDktniPS6F8zJhjPhKPyx9Uk6xNNk9Z5rEeQq/JZEPPxfDMMpIbPfK3ukAlDwx1k1zz/JSsyZG" ..
	"KC1AkRGfwYHPZHcax91zwOlpI3EsyNBWY2Jd8wRP8Srr8HBkjDHwMMKBrjR0HDdr1qOcPptUsLfICd58owW0xIDw9vkjmaaRf/9h" ..
	"Y2g7z8Ehz2F10OAYbMSfjVpsHnHIvcth4PdEYSFIIp+KKsjp8XYEtBnIeyQiL4LRfZoiyxFuH4OjIxEznLgOodqWJqN5Lqqwrnm7" ..
	"+2fPQ0HdCgBjuflW//9rPacYoN+APFxli1Asn86oVt09XNEjWmjgMQyGj3nwEF6ahx/yCGco+t5iRhxBN77QHgx8Euh2WH0cAoYl" ..
	"Q0uuT0yDhSMQyZClG9S8mMXWVnhVV2y5qdXPLqAHzvfH+vNpq7lwEUDH2XW//r24FT2WXW9BDUKn+q4LjW13m/oinSpis+PADW36" ..
	"/oj7425FFyY8uuIEO9fRXwHdSMKRsRcIOOgZfLo3Q3nN8aGj8z+ht1y28xhY1WmqHjUy0q0DY1LNc9pGhoiIsDz8sctI2IxGThq4" ..
	"HkUZEw4Xe6APuVp+NtWYYzoWLx03pW4HBDlYVAbeerPxBswDErfN0yEMYocxQ7/9emRNAKCePffX094XB368TKPtcZheU4RMjEUT" ..
	"M88nityiVONSHeawI2eQXTxD5Y4Vz4SwlwOmlTvyHAJh27UNThiCAm8R5pNs89zqnEzxK1tf3uFg0uWKpo4oNEJ9sYt4dWXHRrAw" ..
	"oQjCS0PXSmN6HGSdJiLg7HC9B5YgptAF24cYLsE0exohdkUyostj5NfaUE7BiQcVLeEEzAmylk3c22sgVg1rziQPsSHKxDVjCndW" ..
	"8a3Zb2hfspTpdwazmC1infTXc1xV088+/2MhWaUc6Mb1YN2Pyom5IghCjjCiSIYfYgpUgHNOYeDx1lpvyVxNCngE8DEHNNihJsnI" ..
	"cvqeUwlq2MZJLD8Zi7Rq2GmGKrWSJJKnB5ymyohutcHLD2jq81Fu6PYrBD1WbmLRfZyecKNGaft3aOum8kE3i7F1Mtuyv7wGS2jO" ..
	"Jv1UGjdMyeVPoNmEEMzAden8UmTWea8SEpP/eV0P8PO/XscE/TMkUYedRNfKdYNrPMkxAGfbuu2HOjOnN6lXgiSDQ7aNAmxQzQdV" ..
	"EZF1fAL+W2qjMIR2pduxSeCR12Il7BNReP4wn+9E/6JUEf0WlRiwdUQTesW0RIxuN2DJZkcAW016j9nwqnMhsjQJogQKTA6Vj6+7" ..
	"hQEUji1M83n8g0B4uExs07jqxD6gMpgdVmLOeNck1RW8YGCBe5HvIRDIt9MVwWbUzbTJphMWxoa1ytB8X4qhy5Eve0Eqf5XNo8RI" ..
	"UfMbX2OejnprE2ZBzCEffIFCNyuS3A3HUqrDhDdyd0qNHjQAIc49E8gHuBUKi1ZIIDXwwqYYowqewSmdLqirIk0LKweprl7bwx7B" ..
	"mYlyhP+xWQ0Xvk5U2Z38pt1uZBmHuY31MJlKdwIOt3ERA/P8ZG9SgxZ44/SYOYzrWrY27VTqX2+R7oV+dCQKla3yx8eTC3n3D97X" ..
	"AlrDUX03hWlX/1XI41RgpsIqADZJarbHMsAsAKX2OSTTq/AnrXasLM7eCdh+5l9Gc5M8854VMMvokYE+uAgdw1HHubsI0z7YV8GB" ..
	"8oYKjU0akeqD0kG6X51VHt/2FKGVG5JSasj1GqXUSZVfFbL/UwATwdoZFlTrJ1eCRMdGStuP37pUVKQnevdsIlrejprsM1gGGTfR" ..
	"JtXtBcDJLPfTmASeYCdn1bf1A4OQTzvP5FFHtjseOt7/xt0mO03mUlrao7z9YP1jtRe5UUvkP9DsI5YkDomBXFUhJEDaJt2CYvjB" ..
	"Y4vPvHIA2VZKUbIWH4lPXHh5pXb/2fIgxIMDRh6/0FtuIGQOoXiG7Ocbyid3mA3sbBuvmaW4wThm6/4jsQfV71wF4QEur0qa0fxO" ..
	"LdSAMUZARfH1grupUIyqjJUgdCD2vTBsxrjp9QSGs5Pi60FGl1DlVXHgE3ooTS0yY4x6OoEkmFyOMK1z3KifqMa/3riIdw1Gr16d" ..
	"e1vFFzTT0574bPoNLrLz7Jkb8Kqk0z4i2zEG5pk+X4WhcwUdXuk+xTyq/E2tR/IZmqRSOTWfaIaLxk5HXX5N+ek5IA6wnM7bXYj7" ..
	"F1kFX3brv2v0Kj98E8sqE20n3NazpBDq8huBJIAbJ56Gc6vgClFJsyedZc2kMPf0z0yLBhl2+t3oJhqleav0I4Tu3IB6ocKLxRHS" ..
	"Yr9O5QXKXZQn7obUTpElvmzQt5geYgB4v8EfP7IGR1XADbC2HM2out/l87lE/ynzHUmKDbsJs8T48dUwxpZj5BkZEPDfJfLg1DVW" ..
	"0jcuUI+EdxsByoI0daPajtm8+/8PRheeJGLtC64ZeyLZOKJozBPiSkbyHspVpseYMoNZGqL5ZWudH43Zf00g1SwYbjjhjRZguNzl" ..
	"QKgHPm/b/hq/uwtniVxCIRg795yLaWc91SNE+PwMZTDxDeGauCyq1Z7ZGZ8ok4jtn7YjtN2cI/U6LAj0AY6cxboO3xCymRK4Sw1h" ..
	"0DGQiZw8jc7onN2+qWRcoOnPYQt3bLNvYZxGVfWOV6Wn3ATEb7p3rXALetDO5STjkfKS9w9/K7z7cXqnrXsn2dpT6Fn3mNlhWldr" ..
	"7c79vaLGX7x+4Pb/M+9LTa4IlFTC6CgXJwdaw19Xx/vHmLf7p8L0ttlGgPjRqxPwP5nvi9bwsdcYU6GNporzIzvwhGkSxj2dBkIy" ..
	"pEFUXi6igeIzV1TcFm2fEaYgmYR2eenIrYNpfa3/COK+mJZ5eDAlH3WPiBLgxTKAC1Md4JlRoyhcDrAzhItOAeU1OmN/cSoRJ8oq" ..
	"uQ7qadCpXfVsFc5zNLUiG0/OihuY9nvDBx4W750eF4bamY2+UJdXiGNCZb8K7jzYsfaMid8T4htB2cLPcUqRHS0Cyrbi1q60mpSv" ..
	"TAsan+M+qsl+j8qsyZw4ZFNZGztJE6GW7Ip6RVKgg0h80IEB/tu51l6imGpynHhmlqlCw3EtCzx2tTpeVhiV+k23XTiXkWcjBF1c" ..
	"Q/ezLNS+RquX9yasCh8LjD8Qd0HUHIZKE92tfxQXgK/W97qC5iJGfhM2w4WxdSmSEgA8fBIRyiLwQ2LCS3ggh28+sBQW5XnyEbJ9" ..
	""
local PAYLOAD_P10 =
	"OtNZWNIMjVaUdpqttAEAiVsyz7Qi7+IkOy+VhVbhX/avmqZdBDoyQvHV96GFq7U3cg4ia9XFXsodORiZoFNDk7lfauJrfcsYvRMa" ..
	"5bSqvvI46mauLOluNXgZYdR1rIJSzJPLRdKX45utYFncipPvEoM8qBtg2fWP9PNR70jP3zOxSLxBFPitXatAVcbRWbN/af8tmcen" ..
	"PATDXsTp6A4ZPO6d4bb/6oXvKnM2JF8OlPngfesR7zYE+3qu/VUrK8TBQ0U7IgFwIgBFrizaaDs/Q1277fPrBpvX2aPf7XX3bdOk" ..
	"VlSfCX9csaP2bkAzpn8rdXoRJ7mYyOoG4zuGxgdfBHxu/TvKOdmsYC6C4A6PMchWZQ1GVWMYD8E8pKYT/FztDKhlrWjw0Oqcmpta" ..
	"tmR9hS+O1+Y96CGyoI5dcTHWblSZralf+4ntR41f+X0ZHZUd5rGTEJL3d7YWuveHOSZt/fQW2IQwY/m/9ge2LAwtgzjOVQ2Ble0O" ..
	"rpKGhXl4MPFgM2TmukbSm1XqbyFyuISd5wgSZwqEmC34v2zVWpW/ZJ7ZtYoORjhgpy5IQRTTFNS7rIZ5I+4NhARc1PDUWAWytpFV" ..
	"qSBq8W0EbDzqsjhg1FnBRZD4NJCUQckl4MGNMHAmhgQLc1UaaApxcRoYnKM8lynMy8Zk3ZpD23V2zflnUks1pFIVbLvuRynfWU7e" ..
	"TQ0E64AGyLdqdwyb033zJHIn+K5ZV8uH0ltvhutjiGIEOy8zSz6snfBmkdFY6JQqEGLuz85CUoGEGF9lkn6LXePZhw9dUUEPOMyP" ..
	"uhShs+LnwBl2sMc60taWGNr8of6t1RP/UR1V8uKRaLqtCeALivZvwBEzvlHO/0n3xvQ9TPWvWiYUAkiGF7H3KJQFyA9OU7TXrDOn" ..
	"h0jUZlP/BmYlRs9xABYNJAmiGz6ToQXbguHII9QUpglXh9uG0hFUz/D0pD9IIHrDRjip471eURI/64GkZ8QgcI6WZXnqRI419H+9" ..
	"0gY5Q8axBUoUgZhNdmkbyVJui5Smu2qACp6sr6bfJ9OxTTm4twvNj318hLSG9YYldMHgMhWNZug6DYdRZxdHlxFXcHkPJf4QGqsw" ..
	"Npg79rmJ0mjNyPgyVPmKio5lbKgWAqbpCxh6tUW5DyTAQ/QxN9Z5AleQk23gG81Kd16upyHFXMvWdm+pTVu4SD4sbwRQr86fkBKm" ..
	"iI+AeJZQsyqtFPnMkkwnn/080eWktmLvmiIL5WyGUi/yKH12uoErSVNPB2N/lCpf0Qs738vgF1gixHlb+GlI8DgOHTLBB5+mRcvt" ..
	"ABQ4qH9O08keFlwYw1S5GhFRKmpixMNEc73A9RZyzQGZmBphmH1WfLz10huR2OSH6NxPJaLNwPRnPFUvMZnxBqizw9FbD4tkP+AJ" ..
	"lHxeCX18eUSAF5zlZPR2HidoD1qQuFqQ6mNP1MvEJ+71i/984Q64te60bFZkz3TaEgOPgp/hQX0Npss4SCFue0rM6QBOASSrpw8m" ..
	"vXI+hGDoLNRQ2NvrZPcAAupXWMCADrmzpzyPLGI1JJEyCigxeEg2Z6gLoXkfGpnRk8O/VKRED5VcBBlihL8vodW6x1TKypIKMqa5" ..
	"cfWMsjArcypGFGIienU2zeBHD71/QTXxBsj8CLbGSKl3Uxh1hE8BaZ6oLJaprESVQyL/623HQxgLLaOhE+ty7ftBHTbF+YUPAzAC" ..
	"sj34mvrhA2RuDCYpiZwSJHZrRhidfhHoXz7KM5J6tek6pKgT2x5p0oRU8KnFLiYYvuqSXJeO1rkXnnDIBMT7Q20/tOy16XQe8sCV" ..
	"0rFYzCJS/3RjqIoyErnMagHZIWc1IbXbArWUoMOxdkgQ2u3haggj450YnVNsBL+uGUPDrrD51BpNHki5fPKsDnN+XxAPmFNNvjoD" ..
	"eoii2XVf1C7ddp7JONtx45lcNtTAP51opJ1Pnksh0aX47lm+7ADnbntreUws+tf/83M0xoCbvWMPrwbcAN3Sb1Pif8Ljmh3/nLiZ" ..
	"g4gQorPpze1ivf0tRXYttSvCtntRzw3GFwCCRgde9riJZrCEkr5YqZLoT5nKMrfLycx/AvX2HkkC2hyMrKkeqkYBkWuEJxgRGMb2" ..
	"09Vu8JHzzNyNXyEhqzxdY9Sp35Trb0kmULGJa/jPzvxw3M7e/xtD4YecuoVCnlsGcDEs3anmKiF13Jcpo4dK8VCy8y4BPQFPml5A" ..
	"p5T+gzci1RzFyGebIQoFtfJ9RylFX+cKLpQZpbA7uHyVzFRnIVjCUga7RSZj9cDCspNznj61P2duP8ls1dqY+Za4HaFxnD9h/gR+" ..
	"I3CLJomxjT1Fm3ofOod/aXTAY3crd1ty3/kww9D1n9J7EDZPYlhs/6IECCiP8so715EOjhYKr2vskUn8tRIUrM39srgorFTTSnu/" ..
	"hYzHCTOFTDPBEFsglu8cRPiUalMQlBGKbURBEIi9zMj1PmSePZlDIZL/9mdPFv6ojW7bRZqoUH19/2xDl4siJJ3ThKzUY2hmGYYd" ..
	"4B1FRGATSxxt7D2YAwru03YTZVNpBBPNIEiKBcMDzGFcmQs31lQb+L+QzC6l5393x+NsYQgeei9aa5XjzcAzMRgstG1s2zslzEQa" ..
	"m/txsEU+KIDTO497vHUrMP85S9LLa6HuNxQq0sWoa3ZjeLC05d/tR8pjUde5pUF6IXGroeehSN9b9ZhaymCxf8Rmhk+z05Deubdl" ..
	"pCgo09yRgS3oVJXWrch6ue13UblEKHbnRGtI/f/Ui6Upa4L92wfzVb5GdOTPijscDAIyc95Yhh3lWaRNL5UMRm0e+JpXnsM1erEy" ..
	"DLi/SEQo3GDQEvyyodrNjZ8s9yYZq792ANeIOJXaDOrQ0FMkI9powsfPOaU3eBz0B0vRTEpkJDtCpnbQDy+lZQQ3Gk0Ijo20g4eO" ..
	"u4FiSwLgQtfF9c94g/86TstUmjIiNa2ZhjFmuYwBYyfgJRIeAWBy7sdNgy1V8tJ1GCOvl2swtgwjr39jMk1vonCn110mHpQzc954" ..
	"bJwJRjjL5fKmhxPRj0dbLHGVj8claEKvkDIjKL7/U/GCZZcnOtVy2r8bvGay0woD5iO+B6D9FMTLjms3I1LK8XcnTiDC+0Y2iD0U" ..
	"ffjrijkbTV4z/joedE9SaFSyaSNURrkuIHqhSAX5ot80OphC7wThHk9jl4gVLpINgh1Pw1NNgF4rneVi0r9WSNxQs77Seu61U9YW" ..
	"f8vYHOxRUaC478Tyg4Pvh+giPugXA9hayMe9HnuHFuFYuGAKiuefiG2m1/fI4znCjYJM/E78JvLztCgx4KUkayb+FxxAF77tjSav" ..
	"rnZIGumAhWrobbHnUnzPlGUiPvMX52uIq5mzhBnyn8MQefKm4StqmNi6P3lNjBo+GzjXc+t/wADmELQRJPSKxpVDeEeOQ8mXbwRO" ..
	"RgbSfp845Xnnh1N4rY3XC+7hTLP1WDpfThPK6xuTfZEWiioqyn2BOEtdg8Nl/5LrX7ouNw91QSjDlbzLWmxUSnmqN3m582P4gUdf" ..
	"QbDvHQlkdmZ6K25Ljt7JHusrgTv4Ww1Aw+oN4djsVNGkEY1lIyLLD8XihyFFPPBvJTaf/xDwuyNSZGoCJyR/9JnGjlOf0SBgniq5" ..
	"TIZjzMQe8/Jrlkoo0qUt+ydNm6fiMP2ie/knNH1LoY1wmGrbjrhvRvnYLEiCb8i+IKyWLfTLQPAO200VcQAeo4PXj2ThzyNQkR56" ..
	"lC9u0Tsl86ouZp/PnS4AOuLvdZAAxTTSgaTi0XCLrdjopzNxRhgCrFwWrzWFV9ghx/G2Tryr54NqAnUjHwVYbR9RUKjhbxxGVFVD" ..
	"Jc/pOvc/C6PHKfNEMj0PG2Y9YDbuMh9OcJjtppz58xCGWvaet5VrzoG9yAvp++iZ/g3IbcsNnk/e3ZNdkYNmk6z5VU7ICKbsBVsv" ..
	"1avekKmX7fp1uz0JC2lrM8QovFdIrd0NhRmooKoWZNayCCN51v2THh+zCwFReqCJOnn2I5Ilm23tJpJ0e1E/CsQIyFOmvXkz4gSu" ..
	"SKbgJVXUSAY36SFFpORrvZjukjTPZEQrq7bvZQcBJ9fVmXUIS7I1uoaaSjVZXElk2vpk6FHb0SkmACy9w0BhPoVZYgCEzGlHlOp8" ..
	"6bTsIv4fbUelo8jAHwgvl3ukqqy6KaVKo75S4NTeIZPpn8NJtHaI+dbSSiI2aIDYKjMZsYMz66m0F6BpbzxOgoJuGN7VrgEf2r3i" ..
	"ecpoctWXvoAnU4P3kFd+0lifcgQheUsHJy8v4/x/Nq31DXBrUUQG5Ir9erJgiAAA14KIFA8+MDE+F24DhddBmZHWP9ZSlGIHsK2o" ..
	"sgXLtCsPyzFvpKB3aD2LJYef7NMgcWfTIRwlhtBCCQFYEGnb1UgCup/k5fBFTHLSIKVuxFJ9NoqBbBVSzO42K30RcOmEiqTU+dm9" ..
	"NzbSw+mBDS+ninfd5gWGJO0CQ4U9pTY6jbg3NzMbMoUrZ3gcWtMzb91mVcRaMuU+5Vu5JFKJ+lbmD/wauyKAsxMd8VBQq1SyfCbO" ..
	"1bVG6+HzAKbN+fvsnoR13apEyw7vLFrD3/QpQJxXvr5jBSes+Yy7OqvulHCCK085ih7xc1BPur0JyESFceePnlWlgpMeYTNCg8Vw" ..
	"cL8FfjKIjVPl9m3Y+abk4p0sRrH0HGPfdBaNwj+LrjO/OmniY1HBD1cDYaPTuoNHVIKCNyuQ2PeGDWnvq0HTkudAMSX2WPaCZXbm" ..
	"PpeQLlOeI7wFHOF+9MjvvAx/S8AKfKLNvyh9iIvfg68Tifl9I3023xXoKFDo3Bf0gh3UY/Zv9q9S1URGUPhmTWDFBb2mwUvWXW9i" ..
	"qTQg5vDEwb5MnmqKhTZiL9N4RX4C4DCeaNSaOXK+h9v81kLfGV6YGLsCtWFga/jFMe3hWCQGODo2O7WJlctjmaNiUzgwFDcmCKeQ" ..
	"C8SSv1lTLtxnhczUiz0/l3Dlo7Lde/HXuOEgcHXl2mARANuNaPh7tL7zGRQa/Im9YDo59+D1KRA8xJgwlB3OA3tYMyqWeg6E+fq2" ..
	"pHFuTi3DWfWYHuVYDCLR7MJfGn+IL5HjD1I+zuE0ExXcHimUW7+CED7nUFw3566EHVwP+v5G//SSM8+5RN/9Kq9iDWJRbjK9acDf" ..
	"NYNduldxUevcc6ti/harsrgzJaiTHsR3A+d3LWI2b8kWUI9A1FXX+mGqx8VmewHiPRrDJqqNxxmzJucqQzlckBTrsWonqGbXI7Sp" ..
	"CKAFWZOSB/wwSk5iQmGEAg7WSoQd+lppspYpkk45itc0FKihjs0VyhvndQoNv3cc8n45RIS/rgHJztrQe0/5rrPfzgwvcnqFDr0g" ..
	"ZI454Tn4W/UN05Qyvh8mgm+BRMupCViUEslt/c4HARaYXxcbZ/FkHO7O+J7vA0M6AF2pg1xIEAZ7k+5rEbTEcSSoo8goytxcL9uY" ..
	"jiZ6CYwKwcALxtwNXyUSliYf330a8yXZVM1SrA6I1WFB2y17WhMjPyjggbNe9Iii66KPRkLV2MsFwpJew8MGqjSiR1PcBpfGKKNo" ..
	"iybud7AGBvct5MO5+BulzoRCpoVbQsWhIfBVU5ssGTlWozaerC9hl7jRr7WcHrJkC6j83wBrDXIf2ngtiW0l4unnQPHWCDLWlu23" ..
	"VoyTXGuZ+iiQeya4+AvWSa6qRJI0KnZ6cdsNCZnMq4xK3yB1bNi54lfK76XQi/fABk8pgM2Cq8GtdA/Gskw5OLAyaIqaGAr6l0uu" ..
	"bgBQahKAZz+PIbp0SO6D8g2Lcja9u4cchxwlP/Y5vYbIhqiB7q533LpCihy1DyarBYTq9ybkD/onGuqKP6l9KETiH1k7LU59HBIE" ..
	"yeCp5AqymJB9PCzscCMj7H7Fx7Ppr2A5aul+BaAusa90gWjUB+KHGucIx/+HyJb3RazxrqlICkOgUs5/fC+xhLgqkA656XCrC7ni" ..
	"uDswgWKL8TSvPeD1801Mw6GDKjUGKQ8MnR2FOufq8N4Mq3ZAcXT1TPMYpYJmVS+uWFKjMgUjh5AuFH7AI8ajvJq6HM4IiEpo7RyC" ..
	""
local PAYLOAD_P11 =
	"qdVGGxomjGGvW7UzP8KFxVkf3hOEYXOK5btQ3FuF1HMBr5JmMZnvekKjOn/YqURP3x9LpG5GTxjNK5JAfDLfIoavptusIUwRhkoQ" ..
	"+eQDGIBv/7nlAUjlGrdyjkkUR+dawbRcRczbb7x3gIzla+V2W7zb/rVhqpWTdxPSeSszIU0pAa1kXm2FVEJj8fmOBFZi1qpIqb2i" ..
	"xo9rPeDk0tIFVfNiqTzHELsG5fZfjxpFUZ1U3jElyGog3ZGrIXCBzf6zTC5wqGz9HvIijhRIj5wti/zVNVhfJ+yjeoGYiyRg0tag" ..
	"VQB3LJgm82It0VQ0EfnUG1BF4+0n/07XyzwYCktNvpd/vqi/43gf+Di0AUuYS1+CSp9V40lRVa1qLn2Q7gL2kHg0cuWECg6fBmeP" ..
	"MiywdWBXsW44Ny/wI1Vwc014D9/JyftOihnEPKMbv9ZAJjpOE2LC780BgVc599y63sCJtIMCZqUPRZKSwxsOkJ7SOxrEsBc/qxpc" ..
	"eFrd92eutXE9bonAdD5I1gY48meXShLTi18ReIYoR9NPfkarb4OneznLRUZjXZSBhdmj+/b1Og3iAlMRMbHxTZgVzch7mtaLkBKY" ..
	"ktgAM0PcQptCVpS5O7ZG6e2dvKRAODkMJI+vaBRisvj2gWV5nYLqmul3DdA3dLy+o+mvZdCnA4b3dUXJNob1Y1Hk6RewecofpGi+" ..
	"v3ufwUav+HYA+Xq5ckp+bnAYk1Zzo+wI4n41yByyBY7fOLBtgXLlaKXgv/AgkkhYBlJcaHC9LYAQvURS1YlLPDBcUeyKJtu9PiOh" ..
	"3SD/8ysC6VfgwT9bNgyH8DzGC5ZjpHM8iddqKJVQMfUZfuimvZZaVbj3R9m9pdkJsj9nEPt9CprzRlDPJ5D3jQCLu6IhgbuAfdoJ" ..
	"a4zWwanDZ57YJAgbKFcYIgMSKXG+OAqSCu6ws4Wfp8GbtXWa/4v/nsJBEWqsCixyzVpTZEGjLKi5vPuhw73WAJlbffeI2WQR++2B" ..
	"OMkR6LN6TEbdY200dvjwHfP05IZKq555R+GXqmZu9wKcXnnq3Jt51dQs9rYwDJvI303KBq0b4q48Hu1vTTZzTZzOEZSf7A5W+GQu" ..
	"AQG5LrBnaBp0s7V9DiwmSmXALuRBRnKC+rBeoKpgoxzhLAhfCgM5TMBDvt/38+HoJ4vibtU9SiE6kLpL5AtBEiJEbQRJvcABX1/3" ..
	"DZtcy7J1H4kXCgzMUZwZfAejxoybDyLRKnMpJ/8lNylEmuetgXEF+5bBICZFkzE5Zbr+wk2/z/o+OydKXf0lqp9PpuzGoWxO1Eus" ..
	"aLdzAAkQFpf876lqrinSE53kUUkbiKRkLbzhXkGEGPxxPMTGUip/fL+nt/jv2vt0Gd7n+X+oZl2uoTyWLJnEg0FSKZPTz97QJxkj" ..
	"Bau8fAETCXJ0n8MhGzf34kNcdoMy08koDRswSI0sX0Cpbj+aX9xErO3wxExKORB2j4Jc6OMpgvGRjXujsLI/JJMPx64Iip/UahcN" ..
	"c9cy5/1zupqWyG4+S3ah5XQSdU8DBpkT2YwJPYId/zBOdgpNPUJLqsa2B7fTiW7jlH4ZF5ceR3GYZWa0pCZEA/gDSwUKkNI32PNS" ..
	"VqdGgpxKpfNH2jQQI37wT4jFb08SUvGYi0Q5WJ9nleU6WAEBUk2zorK+hU9KXxQEa2T4BD0PhrJJYGEvbnb55sZA4H1aeytx71f5" ..
	"xU6kfqxaDDYzNsnXmDMksbTQHs/ujTd4+PV0lB0iZ/APG+GAPY7vgdvs7OEmGDL+DmQRo3pa51MIzr9k+X/OfDWe5NIyNjWwsIjc" ..
	"6eFgYsND98rqOFq3pYDR9sIjP/4f1ZT4ZMe/4FX0GGpZu60ElNtCUyXvzF4LXpNT0s5ueoCd0OiTQtDGZBHO0s9CrZsP4R0pF01l" ..
	"azd17mH3JZs4tgzpzETdUYUSRMIlczqxpT0OLTrZdDCo9xnYyAuY6eBzYYowiixIGJmHRqKUVWYAVcfmwHyDpSa1zK5jzuZ+jrRe" ..
	"xIfJcJFiibDkcKYJvjaFAP4AqQRRqpDULMXByW5wR80VOebqTVCdRC4R9FPVSuGDr5Zop2zatUpaw4B2JXPQacYQThfr9Cu9hhp5" ..
	"ftDucx4et9QHTio4xvCXzsj8WOHaPRVc+Crg926S5OLUvXT3t9UQPyuGC/BUuY1+b2kUtfqZ1j/3W60HfZVcc9NYqCSuvi9OOLk0" ..
	"iIPQHgF8PEHEsuHRhBNi66Vn3dEVwQRBKlFjU7tSsbfw08580uxaeVeRwrynqwZPq4zbGjL1mDGk4dHR5nERmVhnH4qcLcNDifEN" ..
	"j9qfzEfmx1hUuOeF8VoGkitgC11CLCL4pPe3Mv/fE7xzxf9T1OF+I3ih7BnhSRVYglVdKei0a89y5n6ks9ijSzYVT7PM+IUcHB93" ..
	"2JF/2mNqvwWJ6p5iMrZFSL1Fpz5neVqfM37ZpNM53BOEpUrPYeOM4qeQhd16zr+pNU2/r5HURBBCCrMialRw2PRMp4vhpWao63WI" ..
	"xTIKtk8Y3QZ2j0/1MclJLYiuT09ug0EYfTDKbPu8idkIKtxgBQNVG19aIt+sTMCJA5D8gJxuY0oL7wNQyyLSPmJNrC7Z/HdeWNGn" ..
	"mnmRB3TK5H8ciEgXw66ltIOVeDYgDk1D4rNVztDepIYp8MFUF4rrzkezJUE3wRW/YY42w7Z+91iMFZ47PVuMqrTuoybVt2ESsxl3" ..
	"IyAmh53mgdh9hTBWrecC4afu0H3Vp4wpvtIJkIM8B0PJvD2a57SX1pc0ufxEVcmy9s+E4gMnAK7vMNSnZSAvUV4oyaR8d91SLoP6" ..
	"Rrhle0v75gpIJ2IxoEo4svaZqZNt0rC+Fc0Ej96L3GE+gzjymkcouU0FoWeiGYRxWWW9XD/wYHbDWeYfbl6ZkGk/dhn+qUlzAKqm" ..
	"wQNa6E0PXWDH8aRg45uM53QFm/pAzoENXAGO6jKz0WY02cb40QqLhT+opIEM09dXLYv7LtaSV6ZXCzW0RsxvyJ0zaM96CZhCnLhG" ..
	"OXoQqnkAG/JVGWPKVjXL0YKdzdta+0B5a6lvT908oe4NTJxtWVnpykNzQBt4g1t6ixGnap8VocIjqOV5AIOLrrOa81yEx9BMjvzb" ..
	"1Z6L1QaEDHmpWj0nLzG/C2/ELUyfzErSC9ub2mpKPACR3GXb00QYdcHiLt2Mo1zMH27NJtsEIUDq8NH8j92oU9sV/BjNxqQSCZEB" ..
	"eYJS0OHpHd15zJ8DJdE7HpRDt23vMuVNbgMf0l6IWqXBorXhsIIp1op+qFZJt5RfMQB9Aqw+9exJz9hp2bmmAurp4ylR9iAcXaCw" ..
	"i9WMLclx4LHIf4hBH4AcyEoAHreL+zrFPRqSv2glTMEI+23oLgvywlx8MeOOuqJWgtPMTpuX/nt9O1gjwCBylEKMbKcKTzAyRmer" ..
	"s8D1KJHS+9AtdbqJ1uXyhGK3gCqQE8sAUwdG/A/ulqPX2tetie78Zsz2ju1La1xfSlA0HRcXcFQX857HbGRuwclL6iHKEHGAJf1i" ..
	"/VxevoMBm39tA13LoYw5QsPtFwHSyPHhx2OCBKouKDjJY9x2AiC2vss62wsMoJNftB0j+XbalNP/edQIUqMBqr8UtjCYF7CRNnt7" ..
	"HftKKFCUxrfn5mgb7nl4h5fqfrAUdKA6JqfWbM2OU/60rxqm8zpVo40IkytqRdh+i6DJV3Ba6zx60kiZa+60begnBjoEy++kamse" ..
	"ykseZ4SP/hIGTXtpMfiThsQoAZVUPpGPdolFNUQ4Dtdrwdz4sCccGWFKZ670s3GfcLaNuQB6Gt4ULP+RjRe0kxM4tPGsT4w8uY6u" ..
	"AQb0gpzvfbVPeHVyjsFI4EvXFU4b8kVWjXUuyPfskDeD1fDVP3mPDU4glMHK31O9V8p9KQEi9yYJvWEy/sH1RlhIZzBPtkc/8jL9" ..
	"H/JNf7YsP+c5i4iAxd1cwoFoF+L7EAb67TxbHtyNLZkb4JA5vOQr6F2Dd2jJBPJ8IOqVLxuPMXJFvJQwV8pyVAu0ajkbOVJYUmwT" ..
	"+VGhY/1x8A+BC5xnNvVsNyDA4UsLBK31Zxy9yz1roXgGK7EOhoPYZzgij+1u2NbeuE8dA13EVzwgn9ccTbF2JgzX0AUF+86ggP/B" ..
	"P1g5TIUtT6oTAp1vtjGli5IX35W8h166+Wtq/gpN9jSNH1/RSSaBumhCLyXOWY37/v5emlCnP2mBo3Jec9GYdf9/EQ8MLvghi7vX" ..
	"0mljoJRp3QVKcgZ3knV6G7B1vg6BQnMZ/mVejFFWz2sc8BPe3nOa4v41el2a1pX/u/t7gcmp2vSW7mNC0ZqKkNZ/C2hp4zNjYnos" ..
	"JzPR5mwappYbwy9MZKg71UDuGRW/qVQyf93e1ENBM8l/JWHF+taCBzIh3vxEhOFe67mHe8N8ghAASYBBuODMfubp1beUYaL3IO7o" ..
	"VmKJGM2CvoNLKowq+McFYYXh3jRLzu/v2ultMrz2Jg8Deh2Qv6MBf2eVFDBTgCeoD4aVPDYugFerAyUGpt+cSQWTHRHdsSIMa+0H" ..
	"REfbij3n65ZM6LOss/QC7GpkkW+taiplV4nphG8xHS7s5KrebbyRn9eTt70hnseRjC5ckse1AfjSMdZ86b1SnAE0OgIcR6RmaFN/" ..
	"J6zqPwyiWgYPxc4ZpSRlAqEUnCKq86mAq1iwxruLoCzSbpM1ZQvOtTgpFUkKWX4aNLF4Uf2+rnNO7PWqfdHWPZsAUoJ2esKr38LH" ..
	"/fpLxjPK3a6SUiTWHxMfUvtHS35mb9FuXyC6E+rV16PhNrgrfOVoww2LaQdUj46mba2C+VkJcFYF9JK78SAyNmHfSM78wGNfdbec" ..
	"ni2f6o0yjFPtvbYWY74ujOU4ein32Su0FVHw7SFK3u9A6nzK3e6cmh1qpAAhurFT5q7m2wALn0xFjyXZDgwcbJuaaBuClfc5qW7+" ..
	"/jZJ8fJd/pHEu45HLhGa/jUlN6b4juMwCz3tPMneBu0Iv6Th35vC+yuB49vtVEaytcRZfe7QtbuwXEaGByEBpTxLAeZXPVkASqHN" ..
	"DyXAP5HOgKBs7Y4MqTDnzB1OJzIyVna9eihC5QjoEEnan37tCmcsZw/8iD+oihzoSu5WnbALeU+LrASNGqTZFme3m3WGUWBjSvZJ" ..
	"K8YvFJjMkyU0K8fpUwbGJiz+O4cHRPD/d5tQZMW5PENUxwPmvvcLEd+h2S8QTxT+pHlluJKH4hT4+zk7hH17lLFAazjTduMGNUiW" ..
	"pZ3aYu25dDfrPxNkulcK5iIksjAPK1lPRJ5V8vOAPCes2ydpzHYxm/jnTD0OfjK+4gguTizmrVSu3wd0q603CS8pe0mP+02/qsis" ..
	"pStDPcbFEW4riH+wXNrWCZVvIEYC93+eF+BksGMRDLRtcB+E2b918yHSbOb53WnISt+YalYFese5bAMG22aAwybiwPaECEcHx4NN" ..
	"tvFAZKYmZ/XbPrI730XnPskAw110x8hICRA6W9a9AWE3rXNdliVL55/cCQe8umMkG6dlrhTidDiYTC3ii/40dH4GErDnCQFOqavx" ..
	"fNR0jXWxdZ+3HfFQlCNY5v8SLOuS8vZ4X/aFsNhwPZjumO0AZGseVxQn58PfJxuGOcYDSS4huza6j34fndsVhDXC/1thcE4QNuqE" ..
	"Rx/YyOGwljRSnXmMrpBpD8JCyWd7nQs7edD6v8ZZYeEMjWme6VBc31PP+6+602x7KVES3z/0zhCX3jGKSe6CwoFKdAAqxeLUILBL" ..
	"Jdb/6ZCjXiTd6SziHqhOBq/mZJLZ7DkZhFQjV/IreMvumGZ/y8HWor/VqxR+UYC5uGvQGAv5SipFu5HqdNDZeqr2gMOUWXVAGvIt" ..
	"50/KGYPTwmEZ6j6KLOd23+YoUj8Qsb9ZJgGs8CkU4ozRYMThEQcy0SG/ZtIamUMQsfD8uhsDXTEGDdzJmY2R3yjJ5wZKb0SEuFXr" ..
	"mURMOCrWIEmEjRRoKXweuMmjff8Dss7wBVcg7HwU09/PXnKHG5YafBtbpuzc8qilszTWnWjrUbXcrUamC9kL7IgIkx/kc0PXH1Hp" ..
	""
local PAYLOAD_P12 =
	"7XzdE2dHq9SjJJ8IsuUuR/0ZY/rfG2NOnB4n6LQryyEob6BrDyggpv8woLVmqdHbjBrVNil7jC5OgpfXAc5svYQUTJuGzQ2bsKZn" ..
	"fDCyvOatJP7khkStqshkHK7PA+DiktgEzKOk8rIEB4K4dKN17Eq/J8SHsiJCYJuQH/b+1zrq4M4CJj5cQY7CCMNXhBPpQE42cnR/" ..
	"OOiMycEBtuHdfsp4c95b0LrldjfouAN72mNHZS+eV5qYqUCwj3612ILv7s65PHhQrzDIpIUgswtIOkNY4Pc+aVkiCinCY7g/VXf3" ..
	"cvvV6ArULdVIjox4M3Im4CCMD4+OoK+wb9ra8KyyFaYhfebJUtrZ52OXpZL1P7PXDH/oh8LiDhN3NLpElQD1b0Pi1mo/ED9P6Dg1" ..
	"qEf56bOuKQXGFPmGRgG8BayOO+zVZ3DmWJmhFOcrMtqyTj5GryIGWcjMdhiBOQsRVjhaynL5vbtnW+nmtJu90BaH8ZHHTdeXzssT" ..
	"1xNAhcTqqkEFIu45WeOxH5T2NXbKMatO/u6ei4jfH+x9mRyATOfa0OW8/A3v/MYLL+TxhpRH0RTz54AaO7kjWArKJVQSFYJWZYqG" ..
	"s6B+t4VHmFgIPHyE4rUyBYaNXKhYN/H6kqYm+9TklOMyXGcq0aaMXJce0c6Um2F5z0ju3kVoZGnfmlFoID+p8/cfBdHf/QNZYsCQ" ..
	"lYT8ncSBglQo65VIUKbLfhtPrbX0lpHsj2ZzRxnttCvtKti958DmTvopODbbFNl5FtzywbV3Mi/BCoSmq66LPFsfgexpIhJSwGEI" ..
	"w7suD8nVQN++09EZEIK/AwwHzKEQ8JSO6Tlf+SoiVXSIFAFr0VvDaUArOcdGbN4TEZk7wuDggZ7ZwwDAcmlwbClbtA09B7d1M5PK" ..
	"rqI/vpwSQveXh7DGpHzUvDZMoN4Qh+NPjzRcboF8gO7yB//3soHD8Bppu38o56pLSr8nXYZkWPw7gE8XlNw0VKk1bgFLhY3YZINf" ..
	"3VpAYv/vv+NL1CFREphGV27LSzJHuWfAXkLLdZH8upuFFGUJCNCEKFou/5LKicRo5SJk3BuboF6EcOt2JKrdzBH001RXAjZVLTDE" ..
	"t4nWnGd8qmfI0uUvNOq5uIdHydd/8qIXz2Xr0Sx1/qQ4cXNs6Z8DzK3JrYkjZQTMM28g6KNwudFIxO68fDSdzw1BQ25XMU3mAHAh" ..
	"I3a5iGdOr0KPotGIkYeolYfkEIMPxbNuJJBg6IFeRAuSL3pBb8VQoadaP+0UdeTtYogMWa0fOmc6ieewFD2YidWTFmOyTuYQBlM2" ..
	"QDj69IugHrktsQc/Am5D8eh7iBNMNaNbT+Gwm3pu3JDb7+x3Jw46XhVSvLGzyRrAi2go9VDUBkIKnin6WQwQVklG2ljOqfb4SXeW" ..
	"aKhapRb0Cb7oQ0pKcFQNITbt0mTjQoeuWBite/yggBuwztoQwY7UP50bo8IoNoR7Xy4e8vjEnC7QuZoRdQ+AxnY6/3TggD6XwOVv" ..
	"C1rBTszZ7Q7iqybcyKF5pYZ25HNhlyhuCC+iFYiyhaP9OJE1Ac3m4HPxwt05bP8ZyhX9p/Jz8P8CcscAsHKJ2qSGharxBCXupTdK" ..
	"1QlY2Chy323DH/SMV1UPYenLX8v0/tGHS3Y+FqF+3adjFsIy9aJGM+6pbkHdE7lmr2RJbOzE8f7SoQXw0/V5aQlb1bd40NyMXxcP" ..
	"DQcv9NUNsVdxjsVaCsRAsu0XAtluUDoWkR/9gq1t/4MndluIt+nKM5rIAGgJcJLwZWwELBDKciIZmUzSA1O0SuR+Lsmfy7KrUkKE" ..
	"4gfS/F6AkqKJSgL0kX9csxLp7TjQRG5jysaj6B6Rr3FgOPsF7QQHwjny9aoMhep6GhbNV3pgqkuL/t1B7xbS9IdIoiWNbYPQ9Tte" ..
	"1q75sfBtZDfM+K+1u5GJAf87lvsP1ntuChAH9f6JT3VuK1bufbuPvuGfKpLUOWKQi6tBa56IX8qiHDrVKH+0rWWH7XrFtlLZXnGL" ..
	"31/qxOTNSSW4fERmIqnddwZecp0dznt6sxB6zfNh+ydYRgjRnFmfkGwatDuQmr+UoYxT2ZRVCa3r9dZKmqzMP1Uu5Df7kUjXpdhg" ..
	"ox2LH29eXWRnXI7hMDpZl+n0X0m9bI/1riMZ4/TaXeAGp6KcKNC/qCIeuUACaht6tcGIPZb+T/TAKIVcfSQ1UOHBZ/aOy1KLzlCK" ..
	"VLEjtw2TqBWOOWzyeL66BlKIoXENKBLLxzB64yqI68QnG0ibZek+zEZMttP2W4g7WYMuTgH/yjd2WTQE4lxja79KHM+xaxoEccZz" ..
	"MsqbPHvmF70oaSRHsq88v8XQCL6zwFlcVLfHhgQZNBXk10VqVM6tihjJPvNqy9hMNOlnbB+ybutC0HzyxULcIA6rKE1itINnPson" ..
	"zVbvKtUlcjfHhZpYnzL/JryE5ys+NMbzVrBW5f/8PoWpJm9jOTMdzdxx3mElm2FMXx4udMZOerfXOPCH/O0ofVOb76khLbgcBy7u" ..
	"XFP8zuHS36BhbTo8Du0shoMvAdrluZC3TVXqouRqa1iPh+nwdXv2SbbsdmSIFYwCoACNT9slZm9YXvcsHnWouSEcFIuRjgst1gy9" ..
	"A59YFIMS0guxrLy3NLYumklIQUornBsU6E0RBzYf9/RMM/2V0TQBtttZRpKZY5mEwlQwFh0f0I3W3H3g+XshG1JHcbCnCzj46OyK" ..
	"qGXhfWONnsClPeEV308rrxNywrkd2kzhQJgpgeTKF/MmPp40PHCK/TYU8m4W9LN97RxeBxeKVjZxmxvifHaDCMkigqk8U3FtvzeL" ..
	"3kD7f9bEk7680RjlRUJpAJKgKr+hYZQ6+dhiqM2Q/aYR5SebiKW6uZpLklKjlFlQozgk98JDeyxR3CbPhqOE1Ot7TNeKG71z+2Ct" ..
	"sy3HWL4IsI1ov/EgWrlBXfhYpiI3nIfUADTpLy4alVmySoX50+0DAarCkPOAm2VOocCfYi3L7T96aUde/kPaF9Onl+9hjT6Vdkcv" ..
	"vWvJ61nl1wmJHTTHnJPNjxRxrihSHsb94wGLVfSdIOrcpsFm8fpr4NzaXT2D/ASzL/XoipdxUc1tBLQ3M8gDOs0TJxrEt7iemnQ1" ..
	"jc39FCd7vxFPulnBTcToD785752YaJuDhb1WeEkDYCfBXvB2lXmDlEIOFHk02dIQp7gbfijewLoft4Zn+BeyTaxDLC9Lx9sHynF2" ..
	"V07pKPO0aODTVXxZsLXd/c2rbXRUjw5b2D1/hKYjhy1OAYYmM/Xehee30tgxypyeNwCCSmlP/2pBq2BTeNPIqea/K4Ho1KIq4d2f" ..
	"aEErbJUYb/pmDIHho5o5pKSzsHg2F2kSo9fplEHkgLrEpOA3LmtHt7K2FTqps5fwHO0Z8hPlCo2dKkW5zraxecD3VCi4UQ4yiFon" ..
	"lcKQeT2lNqiBG80lDgtf9mAH2pCsNMOJ7+7KgEzDebegGj+5pwq0VZSNyn4xuQd9yqfEgNKnPJOMg0ouWHV4Gy1O7Si72gDKIWqD" ..
	"1UTH6kb2w8JXHBbNFK6wrL8btD5H2Z+RHMCEdCTCgxBgGULqXbQtwQcrNNLrx1u6BH57ntQ7Mov9j2iQbv4PB6MLfZb9/qHLQpf1" ..
	"r2En0Dkadh9sjrcsESPQ+twy/DT4ZE66ExM7JqDeMJZ0iujNpqjxcUUqpXh9EMwM6oEPdDc74enuCjvHzC/siqVC59/Poy6eDon2" ..
	"pwuqykUbKbCdueDlMNOjfzzzVSuMsPJunrJwCucbODFKp/GjbxYOyBekZ7oevy+v2dMSsvcim3gFquT5+J5++tX9/OdYfsANwVD+" ..
	"jiebbzn8nMmxwepUScXXb6CQgaduqtg3FM65D7ZsF8Q/7uvFqVobEuFFWqfGtlnYP0kDjSANUeRC7IfKiU2UTi2xmduD6jWFO03b" ..
	"9NLs7kDDRTpswycZx6InMyMf9mWKW+7CjZBVKmTVj9F2Rwp+D1W1HUcgwcKxcTOvXIzWXYH6L1ZTt6KgG9r4CTr9Q/ZeYxtvixqI" ..
	"1wLybkkWtxeb2ULOVYT41y0oEQzSpaUxslKdKcfCG/+OWjrBAjtSGBk0Op2Eyv4bl022jSJdUVgW7I4sws+/awbU9OMi5/qgrZV8" ..
	"XRwueeiS2DX1vWzvzJRruCpAOh5xOP8B6i/GfsWEgP6fc741YcXG5LLtuZYKyYc09gmvdWQdmzRXILCoeyDq07OM5q8O0fkFgp2b" ..
	"+89sWK81xr73yJrsJaJ7IGAiiyKn2xoWqV8RBos/q8MFeT7jKuA+skGIies6MQoaCLa5598bll9jHKodmVCyd/RJhF8gIgpCXIov" ..
	"xhg8TZzYEH+zYkMpqqlukPbzn30VWOjtg6qL5Ybldx19b49LlFn7TP15FcGJvjekjhX7dIoRkia7OzVQGdkKqQ38HaWfWett/Xk4" ..
	"WI9dsGZiPQ0D4EluTGYfRh/oqx022W1x4Jg40dJ/VzB6v35dK3k4lnGzAvdK+zmYCJKGNldSdAchcVbizDTljQ8gK6w5YsIlqRCR" ..
	"McXbNTKyxtOF/iTGrX8zmlI/U1lkxeEcTKp4Cb3W6zyHCbz6+FZjD6xJRTHmgqoVw2IbNYVeWEtzQ5CtzDKX3yzMnq76GKRJS3Ie" ..
	"V0vKf7E8xCCq2FoKhkiq8sxl5m3bJYm7Z2UB7/2C/GGeixEENPjLJuh4zJOoP6ao/kgY4Pegd44QwQ/up7WaWpKjyV7G/DOD4loV" ..
	"6tGECAKxtVW9PC9N71OHyE/swUJD6hWX5usYb2iOX8/JbshE3fPIyHveC5Ub2jG/ok/rAz2PfcoUYtfrW0JWriPYswm2FAZMr035" ..
	"hDqDYoiEiBwh59iXX3NoivmVQL0We/4Cevkdw7Ui5uAg31DUsP14zKPjJg9ChXGovsVnRY65tE48vP7pYnHJ8NwAmnyyNW11YulR" ..
	"n2EsLxX1Q9NNtZm3P+VFIu4mc2c/d4ucjROs6fYRmHnp8N3i0dqhBWgA6b5U2qAqIWRNtq8xWvVnUjhBP6NPrAfok/61sTPHKPpr" ..
	"kS+Nmipx2XjlVGIFEi8AlxQKmmXaEN+zwgIeyLe++JwADAlXphYWIvPhcT1tWTCTcwR/lxuwwv7eLtBtudinXNe+17XG48JKxHeC" ..
	"fnic6U4TBuk3Gy3OntvDQPBbRKuWNAMn/VEU5dpbhlnneYQZm8FBDJBdaP8Q/IGGn0zPBQYJjyVix1cqA8QtaiRlkHfv1VAJgKWU" ..
	"jHeQsmdomPSK0BPAdii4u/art8wLN4PdiI9PCQ2a6aNVCEudSfvw+IS3nyMpIbmtuWNnWsuczsYcN8jL5yApBx7FcXsNHIrD5SlL" ..
	"rTYK9YiMrVjv05bbRF5DtIJ1Gsha1mZcePhVekJqBGZN94WA8hkQ3V17VAFk7IEYf7tHQeRbVVbG3qYeOIoEcejA6k8V8jjpq+6x" ..
	"UAQCELRmuN1oBnX3RY+f/EaqK04A91tO88qPKzMkPxSFhKvwutZaDVznO/1HfokIRaBo0vFtEBQLaXol4VPu6HG1yStP69qo5oxi" ..
	"EdRYb9zwxXZj2IwBmnSCd94F9RIcFCfhZLZNQNExgwZOA2d2yRNP3FSrzIuyNPRMFin7GmSAFuIyOgT0b2GBHztzxNyPnlmY8bzf" ..
	"QITCe8rxknmuI/QRZ0VRH3Tr1L4aiX4Ggqc2gvwC2nmkorFkq0bJxMGslroSxwSogJgP84To6GTBlzApJtlKKgLJzG9UH1vlyAgM" ..
	"lPraPC/sL9MM65IwWyLHTQI1o8OyvnMOQTWJOOjM4Onxsm5/FOewb0wTT+RMO7SwHdrDivXWI+9JzLC3X6y66pILZZS8BlNM7Zs5" ..
	"yzftofyRjp0QOd+IF1Ud9otyX8ONuttKYdRqVVUBHxUeXf12VG/6lmfLHc+aziqsZS4J859DEiUIVuIAOwbvlJxgN49DIdH921zG" ..
	"VrWUPGK2qVNSQTQo5nAUDjQHqS+55sEZCOKMnuxMLlcbkCyPJcmLZ6A5lRoOBXCVk1NgC2d8iW3emhD8ngYT6HH7hLcmQLwp3SCH" ..
	""
local PAYLOAD_P13 =
	"6+413PrlQt8Nfbps1TUCDfTGJgXwlHcI7VbOK267t4l4dXISbiDny+ZLSkgoXKICyh/hzGjOg6QTLrw9FvaCQOhwLiCLgkD4F/1n" ..
	"Bx8tFOTxqY0a7uvq5t3VAX1Pxff4lr4JN/5ALUmbxAfk4pcLMevRxUIO3TPs8gZyPTkV1nCWQQOHEacrD5ba8Sif6s+KffTYaUtr" ..
	"X5Jzr21uckV2WXLz3niAVngksgEVSozPGUE5Qry9cGdrwr23jTgfDpk1aJkmU9OphVBfuHjr1Ew/QcOkOGomGAE5mrN9sQq2/s2H" ..
	"QMMXugX2CC/0lagfgiU/bDLhal84jnnrVTiQPywS6UvtuXtq1YklMkoZPm1WpqmhUgw3ynqeP6CeNcD0cS/xF81p1bJUd3r/NVBJ" ..
	"z8p207v6rcSCVdEic4O88YIpQDuO1ilVWp04npKJziE603jjyEVt/BqI8q7+qAPyLRrc+ohXT8NyKiFPrDESS4KgcX9uIHa5Z+Gf" ..
	"LTnuxLOHCWRJi/oxH8tsj6VlkyZDQq6PDR9ceIp0LeCK81KIIbYjWcPoY7JxbmdxTMmDPQODnFqK3N1cM0Bd99gco6SgCTr7wj6l" ..
	"DfdhBiMnmG/vynIiYDWCru7am9n2SHO0e2dVlaiWtHBUQXaS5Fesu/h+acJjM0TVbKs8Y36S3o9M80eBSwnVaBA2PrjEPhzhRVDY" ..
	"PPOrMcW/bSH6Dfs/8rz/EI4+GWuf1H4YyERzpc/6A4226/MkvUCeatQFjMPOpQ3s+qVLA4NrdIywtmdQUv4Yb/DWh+F1g7JUvFe/" ..
	"LR86ktlWklVX5xyYtlnUohEdTUnCbfUd/g3uUK6qnt7Di6gD8UUBZ92063vGz2RVJsEqvG+f7VPkCD0ZtuwwjeDkd0Ow7se4mVNf" ..
	"xD+em1/ITdoQpcYJYhkD5vp+V54bVj3++G6c1Bc/T8oc0RkzaZjq9vsBDlc3CPrFI7gxMNNZcXQFBVotEgTYQ5wsw1RS/t+ttnuA" ..
	"Qiq+ARXavC7nKLg4vNeywoo2z0lgi6Tyf7g7iwfjrLvVMWbnl9qrSsRqsM8tcRuOJcmlhI97jDoHyfEq8YN3gP9mO4xEmuZBhaA4" ..
	"5airTiitssQxJSOKA4wmVE8AUvn4obOmgmpOtg6wPgyWRtbMBtY5eCB3ZnUnERkYGJD1qYzGGBSv4g+xpxS3jHVxxUfciPeHKa3V" ..
	"NM1jHsQhPP9lDTm5zLNYyRWuIHvfAtr1OgTcFMkioxnwoYrRbJmck/jqC+u1mf4uckV4i/hy+xh55MuCe5DDSwmFTdcZUDUvi9Tm" ..
	"dhU/jWHMT/R+QXkNDC0RxUeKr9wC2DxRvQ82ydG4WNqNmYq2JI9GxzJYFLzDwtcOtwUwbrEOmcoGsQMvumQ1J6+IP59Osx8Z1xL/" ..
	"2f3IhZM6bFKCYOUSntfwGDai9AOf9ITRr6ihG99r/KZWK/C6ue+N2AE1ZKdgQvQ2P5fKhoMWjDLrPzpEIjFOqkLlTEC6hZaTiDXs" ..
	"RbQDHqHGrsbOm4LXkQm483j+Ij0h2AwfhQ/rWru6gZYUsziYCe0nmU/OIMS0JgCQ2r+Sem25LNmAAw/KMh/xz9ox2FssGUaltreN" ..
	"msDTQBAB8Z+gfflAj30oG7ODcfRQVY7Za2SJEIeBE7UXd9dAcT9NqdxPAJsrjKQZctL3/ewCJFrysuFYHoj8TIBnSXanvnbXGvag" ..
	"Wa0HRd8x1ETifb3HEERRrOJfYcCzWC5riLplg9w929wjE4452L5tvEH61ResZ1PG8zXgmLFTvj40WYLXURheT/QVhrLCg9/N070i" ..
	"k92VbY1R8nOq2MCQ6TZZjzR9fMovZAvKGhbAy7yjl1TzN/C/Alc7l2Z7cCoNNAFkv58/MoQFDYVjKJcEBTcS7q6j6w2ajvvlrQ1p" ..
	"4ExRJSk+2T/mwAFCbA6lTkA1k0dTmVVVJfTNuSo4laUHWVGdvPT9UMn9URNh4eN4RApB6Bdrxlgg6wyP9Os+Rjpmv+Dj5fGf8Ran" ..
	"hx5r4wdS63OD8ZIaPzKLe36dcRtPIp+eIYBxAUfC9VznVRSgFgKFN+wRI96Yq6cGnygO1wdpxQp/g6XXaa+cu2TaZjnYs1nVCz4V" ..
	"kouLfHrLJ86FxsU/mk56+CJJaO6eCLBrt+tQmzGTz4jvHJ8saALPXeMGPqZ8vXb8mNdJ5XJ+zrWE2NW3vhABhcckqdnpNesEuIu5" ..
	"sjccTj2dhjiBDbpvupsOKuMcpy6oCxsic0cU2TqT0PAgMtj3/RI6lKpcNAdyoYaxHzKvYSJNYhDTZIHMBbpr1rTBRfkqrBmP9yIx" ..
	"cb+JA0EEh2VJOBwqoYHdOkz4YG7BNWe1w1xPVcDQq2piUgf1iEW82dD5EdK4nWrF3JSC29fPHSG8fcY/co0MpVeOwZRtCRsFElmq" ..
	"qZMFhOkGTc4VkZCMXVJTj7KW7+ArUf1Bli6stgjZBnh4GC8YTUgsTaZLwyjD4eceuieiclTwqmaM3AKrh1pN5Xnjc+o2rAomHseQ" ..
	"J3R7xDW6rt9g5EF44dAo5D98nF4q+U9eGJhee5jAxcYwHk29H9tF7SH3f2cuqEbscbOKwp8IpuRJv/crdKGtMIbk98J8zetQtWlz" ..
	"tRrdwfO9RgbmP04o1ZZ+Kam924RkzGETxzMQ7qFR6O7BV3R8FNQPOxz27r2l5KcmHBO//C+lKBD9OxNxK3PJFCxun8Qcxovr4CVy" ..
	"O6Cjm4EuQJ3POWGjMbz3DUYo6ksZm6p8om9EuHZ2om4F1eYh3Ohil/GnSSe2GOJX0KRau79FH+r04CsbmJ8HXd6xfz2lygRaJKoU" ..
	"FFA6zvzJq4QzV2RovJ8dcQF5SsPGb1HZ62B7yCKKKhHl78vej5MCZqFvJrHra8n7mHv/Yj0eNtYv7971ekX6wQ460AcUflQAFwjU" ..
	"rSF7WPqEURg3Psvv/cDF3i70oaJhNJNoSVZTSbtczNddgzpPB9Zr+iUinM+tkn+nguQ5u/dfGmTcE7mJ9+l5eGdRd/Mh8SlztLDI" ..
	"vISqR64xysrJpooblF2l/JRAvCTem2OsL7PyGYaq52AfEl4fYt4sTvJwch8gR+crVoZWFZK1wl7649vYExi4QhOCg+oTunBLMzXW" ..
	"Ai/Ox2KQOplFE2gm1Q04TScRmMVHWzG4pACc4SuJX1lVCXkojS87QQ1Me2c4dd6vZA7bg1ulowTlc31CQinlQFZXWLuC/j3WfwTt" ..
	"zOq3LT74yB0Tin56/ktlVfZ9t9ibSlx785nC6hpmfS7v9mh6wfwdHnCbiSuir3AQpSiU4lonX6ViQ9cqQ9xp8Qet9jdAPobe3v7v" ..
	"4C+Sp8E61BI1uc8Lqt4FtFOWY0llvTG3FZQxnQFsHowOsRBrZmCSLSAVMtiLfb6k+Dq/6v/ATAc8wgpyWrC5aJu4wBhTo3y0+SCX" ..
	"LP6IbrNJh8zSDZ9gJS7u0Ln/Tqlfa7D1H1cBSyxDxKdAqsL93Lud+BVRGnU6yq+JVpzyJ4Srrf2HaT1Ktvfu06OavjTTjMDi5yko" ..
	"1vNfUAguQychsm97UfYkNNoqZ3ZChO0rqiQtqNodT1f2YI4DHRPSkOw5Q3n/VJlC8MGwy2yCSk1ivBNfiyhYZ8/nAxFy/iHs0lEk" ..
	"VZMVAesA3tict95OEbA+ZJ0cFkVg3OuYA08NWFTMc/WlQY53J0GymR/5ZPQ5uZgaU+zNnq5WoV/ZDseI1H+23g2wFFbRpZ3wUI9D" ..
	"+W9OsDxyRTaYfHVhIYwHDdRVvWB8GdsZI9KQ0faiViYn0aOKWOuR28j+zSKfbNEY4bauB7rkqasQ5HeCh06NuuVgRdwOa+CoSFm2" ..
	"4LZsjTg7Ry5BdYkuVGiT1m8jwLNVVp47tJ8Y2xtvgEvjOWEJO91aBFuXe8ZBp1Z6FhPl/HaXGir6xXyA/TVfXJ2j2AZ0iklq+IT5" ..
	"evmWSYFhpxOhU9BU4tROftosFuK2a8fzRfGlHdCBiY3pHJXUsiCymAK+CUZJ+8+9PQaOxh0e0yMUvZJJclrwBSIoB/Utf+Ap63Ry" ..
	"3SkgXw+bM3vJ10jpml4wg5ZHLKhakE/lN4d7szjHA2+NFUkOCchWJMaZwEi+7vIaxYTlJQf7L0pHExPILDPXmkpkJsonS/srFgit" ..
	"yC89+8AUPSWCCz2smxpKP11vvJ+lJXxhoAOT899gP7MStjOgMvupcRn5oaAdr+n2C+C8rxibW7bHxbaYPba0zlBU8Zw6dUezdi0N" ..
	"mU6oNqSYZzPzyLBYda0XkPYFR37WWGJFDRxEgDJfRKbnbCgNZpTY/jvRfbA6NR2FXaYvNwH85Vg2VLSRXQBx9Vny1aWZ7L+RV/Rs" ..
	"fR7MpOxHYg+YMfglmiUW8VrzWQPBMw2klOf2FYC7L8N2Ek1Sj65y2vF6oFooYSIPrPGnEbJXTYzkATn1VGuhTSEWZBUx6+65549f" ..
	"WxiBr5Jx11YSMSqhzQJn7/OWgEDMBgGL1mqC3HguXcPCLV+/WtgsH3cXNiVvrsJJP5ZB9yEPY7Zc5+LBLuPjaR3AxplILhI1reLc" ..
	"wJcYN/eF1/HzPh0xwjcR2sURFL7hhRHZagcLzNKh8mcwuBd3BUyxtvMSTFB9yZHFphUZSdBI9UWWK3Zoy7r1jgdaSKqqJHAth5k3" ..
	"xcu4PSlym7XXxdLZtXuvNX0jK/r3C98UzltKnC/iPwVxF2qRPBGqWapSpwM7BR7fI3AS57bEd3ManTX8MBpgeaXV73XmPYJ79FNX" ..
	"KbAiSw5SUICiFtUEYtw+v0zQ2yylqGxNdLurzw1pruOEu254k+AAC+/gp5hybXc0aX82nN6HsFHWte7OndWEj5xCG4jVVRvD/o6O" ..
	"zbLDXLoVyj4HzcyqxycpkIoHGIOxG1b9GXWDgjVlXQldX18tZd3+jqTYLaPrQRHSHS44lJeI14/iWT5PzydZXEoNqIGK7o+IcpzA" ..
	"sRVOnRi8RCjYq4J2FHPeMcjY3zvgF05YHOx08Ue/Ey96GDqPyiaxwzFl6TOh0CKbZGwYFZwKhTW2j3NujZWxaJnzYv8zKXcsE593" ..
	"J+kVDOKIbUymBJaKau98qtqe/a5kgRhadC8ERpvVCueI20SoB/MHfXsGAwFWDUA6yNusC6dd+tDdyGByDvjWFSz49PfOUVsbu8/i" ..
	"+BVGdao23I30JHRfOhqA56PjJS4sw8n/GKlEJHYhIONI7C12nF3L5i1oxIu3xVpme/oI6XCUNaD3gJeOSAAkYTevz84iQ3byvUmF" ..
	"bK6pP5An9rtO0hmKLSm4RDDCvliADcbracyybJ4dXuNAjn5xh+fxt9GhhL0sWG8oO8ZNJqFBTOJnQw8ZoZnvmjVD2y7aE4IC6qKK" ..
	"pZ0CeSpqfhzXcHbBMiwoShx9anf61cWap0D6S6Vi+KjdHRm4eVnvsvSve6Xm3AaRJ22kWdu+2O1YSLZoNnZN8PQrZH+wUUAsKaBU" ..
	"e9o+FR5pZM1Yb0IYyJYmJdYhly5ukW/cEu6zvcYpLQKydgkOBckBrJouVbIamtO1NP6ho9XUFor2MX2PUml9JLkTfv+9Shxmc0JJ" ..
	"fCy8SHqz6qO9xrrzoa0S9vVIRo1ggmaEfysTe18MLzYUpqLNlGCSo6i/n8Rs54lgxc2qqrlkFfiDACrx/6ue5bzx9GLMbrclA4XY" ..
	"TZSiDKtwtJqRPhE6XEPIlnrfknmBJTO84MggTBm5ZmzAUayjNW1U2dH76gXXbhS+pvcm8VGzyDLJKhB86UluNXgYaUYztn7AlhC/" ..
	"SRVA4ba3y16I1xoLQgVhcNPJ16p2Ja8ZVUiVFSB143tYCheH6BiHPYta2Cq/X2RXuwde8HmYALBkwvGzr0QVGscbxuetqj1ligfi" ..
	"vnmmblWzMt5/C6I/68kbd98UdSNTHtAXxe10MI7zfgOXGNzS6CW3gyPbBT2Km9xtUuQwY2iQ/8FxLk/9xh7EhSCmlMn1uuF8eIcH" ..
	"OFdY4RwxTA8E+sotUQC9wclGrnAphcWcMNeLRCbGLYOuV0NCUsqnshNh6Ycf1dB27VG9f50xGe2a+M15cS8Pjej0WgBREz17UCO+" ..
	""
local PAYLOAD_P14 =
	"F7JeMckpOQ4WEppkNXxNWAppdjLDpVraLjU3pZJ2pXFba9/dREBltsZHDdbIMrRe1oOvJ8BjQjlPVqgQVuhGNB5pAKydQO6AwucO" ..
	"1kNlQd+yn7hSLQHFgkOVPkV2G3lv3I4FMch0CnK/ClxIo/WkIcJjC164NYhYkvrhGMbNCbPobQYTyhPw2L9bEcCDzCRSju6jbn97" ..
	"rFoCjQ8Tzu+5QVVtq2Geqo5yHij9byfptCq+3VUYK3KPYQKaFMcxqvzvnL4NWZgukKVOpL8bPqbRnataluwUjwzyjDXumRnYro8g" ..
	"h+BZG32l7u4grEtu6Kuec42Jva4ziBTA0x7rGHBuKpglqlW9m41e8vxPl2S6rFF4gniOfif7gerT5g4Ut3jkhcD5N+fiif7Uz1q4" ..
	"n5QnFEDlMrbMApX1CtmXvj4v/btLowx2DgjqAJqK5MYg+kA/yZmLw7hzX1SYPtJUjuFvAHReA86/0TCu+CAfAdP8YkED4WNA7Crk" ..
	"bBJAztYlY9T0XaJ2pIo4XY/RzdPzUg4Hewy6oxVzNhFfdpKnkuca8hO+B7p0e7fGyj5Hppeos8q2EFtwFdSpxC/fdL0kFYv+dU4+" ..
	"i7P5/vcYO5lQzv0pqWR1LOIlIwW7H2s6QFtqsiGfKkPAg50/ddiZ2FfCHZ25Y4AyGKvi3ak8aoVj5KT5T7mfdGMYmSq5AvsRB6I4" ..
	"pdCJBe1Y69HWcVfB+Fn9dSt7HFSZ/pJ1f6KVvYWqGt8D+hDqW2t4rRgvOPf07zWD3yTniepjIH1qpmkcvuiUTF02meQfZ2HH6ZxK" ..
	"NhaMyqXmANhxqYkJq2YwIOcZalFdJVsPE26S3ugK2wvuujmNHD/00un+7E580CpYdTd/5AUq7M6kLgzo+HtVjSehJ400SXs5p/Y+" ..
	"MaD2p7NB9loL6EW6CcCt1Oy6lyAlp1wloXhOxLeLlKmR3qcDvJirKZFdhcQta+/L0al+k6WzjekLMvWRiJUfBCkla68PIJsnjVlA" ..
	"KkRxGC7myOMnAqTIH8eQgnn7A8EwNxuYd8gOlpu4Hhv+AxIBr3jnQYYr4qgr+bsIRwDywB60jSXFX3N7zhaVXBjKSkDiGOZekx9h" ..
	"to/fsSyYCm8BeZbWnmk8vK0oHwTHKVgrmcNIZK0qiRoHG6mpC7VH910QyZ7fZYXybUtmM156dI0ag9Ap+/DPMKZyNJz8V5u0am15" ..
	"QUfsbRkf1BDrGMsZogvwm6Z/vUkHpCzh4k/sPsS/X2Xh3AtIM1jpiFHFbxIU8Tawlzi6+RqGXjEWFMbzbO+KweiDTwkhiNx5phKD" ..
	"kmMvRWrJ5aNGiyaHpa+jv0zSfZ8zW3vMbyWx/AGNdSHOl8xNXcfE3r04cziYbnoupfI1S5vbfixKqTCP0na1ozrr0vTwiLD+LD+A" ..
	"ORkDc1rF9fnu4ahvg2IRE/losjRbHC8XykA+pEA6edhVkQkyh2JwMQ0p3qDuuHiArBRdrnSVemA4kJI3sWWv3+G6pWXlIn404Ji0" ..
	"qNfILttcsP6DSz7u0FrL8wZ4RjwmP/sghGDYx1gWNfBQsxi/TMcPiBaaeC9VSEtiNIi78MJ1s+v8dcxn6vz0jvncx73Mbc27YsqH" ..
	"PaIdYHKKBy33iTrXap+PUBmg68vtiAnNU3d7KSd+Ndp1Q8dzP8K/9XsYbV+8iR5FsAMFz+zDj0F/pDuyE/LtHwkDUVDoi3uOJ5kp" ..
	"SPXBbgx/Mn2g3ijOEPN0sM9KZHJe1i+83r9Dvw/MWObGG3sLy0sVS8EQGJa+SgEKD1FMzTBPYRGxoiz+xPChlT2P7xU+YghZ5NEa" ..
	"DxOqkduuE8AMVQ8f/ONYx6I7/q5nRTZ3HRpFjKFYj5/tp4m2Hki7/BmuGx+mgkFzOL7XC+FsABKP1+2CXOFznzB+teJICeNV8j/k" ..
	"VQ4SjnoubMsjsLuzYdlxA7Gbm47y88rYOagHz9hfYKtUZlc8JDXdIgGu7icbd0KbBDmCOtbh60Hg8CsprLhHj1wBnEZpcBe4fjwa" ..
	"4EMlpe8QCvtbSUqqJpNsji6Mmb2jsmzel7mJ5fLp4Y+HCi7DQ7AVJaLWMhNjpZn8rYlk0fsJ60luwRUN730PgMmTMaBKR6WFbJjf" ..
	"JrmmlWodhOsIp+kC0JCNVFHiG8NJPwpju8XEqiCcG+fRHsaTtesBSAfv72gzIAVyDTJ15nrnxNmHKCw3mgdY3iNrfqMJ7v+BAV+m" ..
	"ICHeZSOUSFyDKdbN3FeuXHUBNT91yPslRLbwR+EoxBphwS7+3ufsyyf8VB+CAtY6xJZrYw07vheavtzk5K2cv6JKc59AVXmX57aP" ..
	"7+nWiq7wMihuGpRsxTjzzFGThmVmsIlHdcx3+K9GMb60q5xw45bcXzfTHbtENwHvMHg9d3YSNRTanck+wxF7L5qKjPXCIYxkwNk6" ..
	"ufjwWmGDA3q7cpKABs4uWkrW5rQuhtPaPgFUTlNUy0+2UXTuvuY+kGjutzdbruvK6BVMDSSXO/3WVFfzLAtoTseynIVSJLhMj+RD" ..
	"tC31MogfjX8thFbUDlognseWvM1CDHZAhVFb5J/73U3mbt4tRfh8SCBhm0LcISAoJnjvLsyUsJUv1EWdNpG312rx33sYzFsLieZh" ..
	"hxNqP6S3FXeVMO5jC3ezI5KBQBn/ALU5NY9KePZ8chkEN2Vp+7AxCm+1MX5ygbF4HiJTV61lJAg/PlD0pG6LQo3vE76rmHrk/jL3" ..
	"TSZiaISWLMUC2Y85LG/XNVC3dkn1tnN6e7r2Avvgla2vOv4vA7VZvRPKC5YM8ZON0hCBmJBSDaH+ofWbYjXrdesmD8d9i8iixjRv" ..
	"DPiT4cfzZUtx3Fi8Zwt+GFXjFx4Nr+9DcVRnP8NZUgHpupH74tThgaAKlUX6q5RIJPLbKQOH5UxbpRkOk2tkG/SLPH7yDhwyFnmp" ..
	"q5BimsNDjAY42bjPwPQ8J5mD2G7uloHe5w420Pq8e1rRr5pgc6D5pTCVVTSr1OdJ3VUfUaGVt+L75JG5YpJqyDcfHI5hQMa++Cpi" ..
	"XqLKTzDNhs1YpA7e6H3PeF2i13FYK93yHCaWX7bexoJ0iO3FTD1xYvstLLaT3oOc1g2JCugtiu5MrunoZJlMDUYrFbN58OhbFBt9" ..
	"jKPc8uinpbf3WPTdUyXq22CRRYLL7d+2S3Kl5kvKkjk2lrd4P14e6ElGTiftOsxGP4OVoPMBCSgHVsq7eDk05v/Fv776kb46VdvM" ..
	"k6HlEK7eP+uMeBQbbAWL2GZ1P2fX8tmZK3X8pht/y7u+oBz8nVHvlL+kFcxtOwdSt2A+8tVz03XogwjoMj8Lre4z+y2oeaatolIV" ..
	"NjKBwyO6cUn0eYju7nBWaH71yHkyTQYzYps87T53ni0NqgNbNRt8ZDyLFVKuiRoAKGnN57iGZOCCaXbsj2Nmyo1O9U+xf1LXZXTH" ..
	"KDXH3uloSk30/ilcU5AIhstJr+bYnomiatWYOGFhtLUsGX0F5D2qSwrVbFZqMObXEePgimOlRyBI32gsBxsbNDLYXsj+ZEedf0a0" ..
	"BidPLfl6hCPSR99LiBz260CJzs6xt63mqqtvYNALk0VelXY8IZ/ZYpdmHorLitvd9kh5Kc8gczijPtBWCgffYmfMfhLCdw+H2KNa" ..
	"ifgt3mW0cNf2e5Sy0HPg3CTH5j/sxRbphULv5gSni+2qrwF6Z/WXWHAuOwZwsAtQehvOgNmpcFMCrQVI01buHDiUA3gsHjpGGatA" ..
	"eCuxopfCnuuqLK4j3B+qaDvn6BvrLHGuqlzv/xiV2P8XnRrurH+HwQf06S13NXRY5ZGN6zew/DQx9k01OFZEAV5LrDGSNpIEKPZT" ..
	"SROJCjKUuxqr27yC+OhEiPnW34Y3tlyUmdVuiQ1/CfMqZ/TY5w0/EmolhEhF/jkTX7ewiKzpFpL1+IcOzBDkaXFKDalVnCCLxdax" ..
	"FrVFzBcxyYReO+Qn0kvpOIiLKPMPujR5l6rJWzedeHOrEgBvD2kaZfFSKHZP+Kj18YSCQqZ9vkK0jGuo7Wdov2U73sOxsnhRKJD4" ..
	"MGjUyy7tg3nQmDZoIwhl5XorSbobUtJ9V1sbQqzw5eo1w0+yKNT9zEy24p+GYkI78XORv4U+LMkAGKmPV5neNGVGrykc0wxXN0gU" ..
	"fFHpauKvuCgV/36FPJnc8IcWSJWhQb4zJv0KVVscupCWy/yJIoWFvz3HoNRgAlqIHFuH5FvwvBrObxFVvkpV1iDslWiUNyWSecWD" ..
	"bQtd1Nu87fuenAQxRM9gEMRHtEAlmWQhIrrnJkg1n34KIRnXJPLUGQ/4GDsRjVUti917tpusE8CH/8lmlf2w/BLBbLjpJDbZZDuB" ..
	"Ei6f68rsXIDMhMa7RtxxiqL/NnfBwORgeBA1YcxJzE6i3DI32y3sE/hXHh9ZP3ztOxZYm/BjCtyehFuC9UTJy48lRyQSfajaABt0" ..
	"H+bKMQSUxqpLTWZlzGOZq/Ed035tXdtlkhcZvBvAM48qnglDbhSd78Dglfzp/opFdY4pHEHiTRAvsArjFFu1SnMunbQ5zAJB3b55" ..
	"HGSxgeimPCyrXVMwW6RRWXRAO2e4thz/+pIua7oMWW3WjF4QgtGmUgPqx+cdWV3yKkyWXwv3KZRCcbhKrFatYC2nzByaLefRoLDD" ..
	"Rd0aJV8lzuuEMDIXD5GeCO04L9hNosI1niyU52ojnGp8cOzYouTwEdB7+V56JusltDN1cT4O2xEbEne69BPOVAyUXBvanCYOx6/d" ..
	"Nq/px48SAxaOsBPE6jCxOdN/hj1jyU7/m5LhbgiFgOpVDwnacmxy6EWdKRn5QtiAlBBVdMWqqhHSxGXwgWThCvkUQ8l4wKg3s38k" ..
	"iry/rkAUZQKQ6Ff7CxYnxFu1jDUMve78EJ2q+Pech7AisN+l+KaNYB4apytGoNzZhNlGQtcf/g7QXaOAX39hnaJ9n6rWbHJD4EG2" ..
	"42pyXTdWmP79re87X5bHyqRgRGdfU6O4FssAHoDrBIqvmCW46S4SKNCqevtKf0MB5YBQhBJ21HbgGs1eZcZdz3cYV6Nl8EgDgVje" ..
	"7p6PlfGwt6eo8rBhM8a0Xg12vcAPgKezhMXRTLv4kbjk8zGvU1R1UlB7NKgnZhvCA+2kbrrAciJd84BmeSkrIHuyGfuvH4Cb6L/F" ..
	"6QWZgJU9p25KthI7ofW2A4kqLdrsHNqwJyUR/d9CYmNHS1Ut6tSBuMFxXAV+rnnjVgavw5u0O2S5+YhWH4pacmxAUBPrXaVoOIcM" ..
	"cSE+B6R/wilFumVumc6ahYQuPLxZiA2NsT3iYGHR7QUUQkueU9ytqBuKz7mysQ0wOZvKQZbtji3F1ChdgIMttQ4m076qUiin/rNS" ..
	"3Je8VzB59s1SwTwViDRhHzqhSkpHWNVwpBvhnPcCGNpI9qD8LoCNLvX4b1eZT7M/ceh7QcOOLMyZgx3yu8lVMmXvXzQGQUSaKmyK" ..
	"lK2pZ2MDYh48h2dGi4Ffjt9P9eIr0CimPSXuOv04T+gLNrSHnvmP5O9UVNIKbWKBLFQxRuJRzC/CDXrZlV6URyhG9dQyZx0YxN8a" ..
	"F9BzvtJoM+2Y1LsX5UMRL+l7t7jpqLNG/EsrYSGJ/oajrm9SjGVBl5+q5qIrHIH7Iph+n5frdEDqBHFygZVwdFfZAJ+dzjFgjLr5" ..
	"/bf2IqFyGZFhIkfgh5/w2ve+7VEniJpAh22mxAQIapP6ywxrAmM+EiYzohGSkxP5FbtwHsOqtLb8D444QNd4M9cmpJR6kuCHsveF" ..
	"xZ02LLhVREj7GoysP9B/ARaoPkbNH09uP7CVpubSQbmLw1c5AkcI8dVVWYJgBgajjTAx5dOOy3T99t4DUnF0l4hNjBPjil6uN6bO" ..
	"QRrHGyqJDKMuRZOtc5FCF4yGHvGWIk887ciA523MQufowUzowfuB3bw0RT5cXhpiz1DIcjJSqecgBTdFEo44lMbwIBhWzifXWffe" ..
	"zo9zheTlPOTEBtGBREdzPsl/mnEn0urdwYvxNJQw/sW4gxdPRvPEPyIDpuvPT7SqlzQiurNXJ+OeRyAcjgLcOG9w6B0W6kHepcwK" ..
	""
local PAYLOAD_P15 =
	"VwVCtwk958VeL2ukSmN0oVjUzi/ofbJHMRxqmR/Tt8/VpkWiRaxljVSDb6/wHCcyW6aHrlyXIVwbMORf+n03pA2HKWb2DMgz7kib" ..
	"r1EBlLX4tl8dgutffm7s10ugBxx4TGFGjwy8EvRL6wAiY5t98BE+sR8UVkpQrauQsxHyZNmLukUkRHKpbA6Ky6WPnT61nD04xQoQ" ..
	"FOcnJbB8jTnEP9GgF4B+R9FZnwib4OpJipg8gAOJP6dLqyShI/Vxvp5V7vZNiMLNot2z+FBpltEvB1vIYUXI4e9YkLJXGp6GFIxq" ..
	"t+U0c7kRzi1ymULvfUC7CF16dMDVC1zpCQE65L21ytt43Q+d2/p9Z+16SCbqEASuCIeKHcza78/Blg+pRAhWYOIsepfVMUa+A/bZ" ..
	"Ubu/dzduj+LcO4DA9wqQ6GzrD/gSJjTmEJrC5voKLrOWkEzKORrQ+1SiKOZLcNkBV6EQJN6wuMi+yh97ZqhJFabTT0rwkhTcSUm9" ..
	"GienXge4y33ZRB++7eobQLa37Q6WwlbIKrDG8MsMviHvRQFeqU4ojJti7SKG9xokBryBnjvYx/CPGpPNUPUR/uxPaeyo0nLFgSQe" ..
	"6hhx0yD+Nn6XanmoMPayaUUi4it27H6236ngKOO7X8F6N0X0E/a/F90423y6qyIjdhnMxWrDl5e3b/2qPdhsERe6v5seSfZOQBuq" ..
	"Q6gd63BEqlI9xvs17/dJGukvWGyCgnOw3EoApZ8n8ANz1GDysf3hLI0Bc/qIitEmXe/Qeq7Hhy7qoH4zV8088z3LRQDVlW6AR9V8" ..
	"V25A/6IoHnGu5ytphxw48PnjuS/jvPiI3LhW9RUB+cYsNtsJ0KA5TlaWTP4nsl9FbWaxfVqVEk3A0c0PXDMoEZx8hQVazXLXF3Mt" ..
	"enK8JwnvRso9BTgOa6d8m0d+IFUURsYcHc6pPab5wFaj3wC8jkbVIf/+XSKXceOvVPSNBVgVsh+lVRREMlN7Z8xgo5BDrlMrEHK6" ..
	"W9b8c5QFteoQtBH9J01/n1p74P+4hZxaMBw9ZfR5siXlCR3SsXMLF3L8pd1k5jpIeq8xxbpqSkCl/c8mnrrHQt/LN5BSCG26rk+B" ..
	"9YVmUl4gftIsWKS6LtsaGKHIswBfvnhcdcaJAzWC47YFRXSfhseDLSgFdd9E+K/4u8vvR4nfOFgi1hrx3vf/abibod7QiQY/MCEZ" ..
	"PpLSUfYGBY0yoPfeA2wIimnT9BUMtkl6KZ51s7k7yn28K10VlQUBzVh4qACSBCSM6oK7MbEYWrIfIu5Y57NuR5QxM71J/JdD5xQ9" ..
	"PtlAaB2roe886d69tQMOwk8AxC8/LPLNZxLyNStOVUwlav+UQ5nAzZzHuGHBHfjEIySXmh5EF7rUUfT48Aa2qiLLYyPPaPmCYv70" ..
	"FK4L4YZM+bgkHe62R76xtRToboNdqQ+NbyUJiMQ6zzsbNWDL+I5XE6ywwZk0dxnjbbMkzwVJ+B4rsd/KWjTId1NT1BanOjpFGK+v" ..
	"jLeu4DHqJXN32cetKje5LFYHMqAsQbFi0F6lBNHidzcrEGlTC9xIAtWS91cu8+1rKUUpU4zocIB5Nqlh/CHLkw==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13 .. PAYLOAD_P14 .. PAYLOAD_P15

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
				-- caller destroy key GUI khong bi block boi task.wait trong menu.
				-- Khong nuot loi im lang: neu menu source loi thi IN RA de debug
				-- (truoc day pcall nuot -> nhap key khong vao duoc menu, khong biet vi sao).
				task.spawn(function()
					local okm, errm = pcall(fn)
					if not okm then
						warn("[DQFarmLoader] MENU LOI: " .. tostring(errm))
					end
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
		return
	else
		print("[DQFarmLoader] " .. msg4)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok5, msg5 = tryRun(input)
	if ok5 then
		saveKey(input)
		-- dung FindFirstChild de destroy, khong phu thuoc vao upvalue sg
		local _pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		local _g = _pg and _pg:FindFirstChild("DQFarmKey")
		if _g then _g:Destroy() end
		if sg then sg:Destroy() end
	else
		pcall(function()
			if msg5 == "key het han" then
				errLbl.Text = "Key da het han! Lien he nguoi ban."
			elseif msg5 == "thiet bi khong duoc phep" then
				errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
			else
				errLbl.Text = "Sai key! Hay thu lai."
			end
			tb.Text = ""
		end)
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
