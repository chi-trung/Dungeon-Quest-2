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
	{ seed = 1688577534, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1692255720, exp = 0, plan = 0, hwid = {} }
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
	"4ep8XojeVKR/PMIppE1jP4WYH0gP/LCon3/nXMT0Qv8pyNxhd+Y3kHpQhTWKJp3GNEKlRXfIKsn/C3jVf6pzGiJ9yOjlATkZdh4Q" ..
	"8Plhn7fEJ+UFgiJ7RdkD4nWVZrMIPUAbjPLzgi7lMA+QICQTsqiAfvYIiax7F3RHaYVCBu3Y5pMWWJ+68cecBchi7GmVOoRglKNq" ..
	"shcdLfHXJhDttdk6tVLnNJefgZUMNC7Idbmh0ut094fmXmc5jzvq0CENf7hy3l0ha0s4FrFXcOqB0g+BkUVKf2UQgQ91GdDOQRfO" ..
	"YRHGsfFdxTmAPGnMQULDZFuT2vHt2EylZ2E1KySrNhhz0wL4Avqdz/7A9H3Ho6yXpko3Et9mLvK5BTZE2mEkf/5fgqVItFCQKA0K" ..
	"AmUNO5O6N5J2y0cbH57ZKr8iJ6RVleBSxnTfmF0y97bU1dCDZ1DM62sPeOnnNHsK8WHxRDEmWzev+p0r3ns2DSriforr/AGY46zW" ..
	"65C41j1Auoy5dvTpECYapkNHLpyojTDrkblg90ILgDHXrx44tAsnXkLSrMTQ2aFmNdMvO7wXtUwGH38I6aTIdHJwiUCYqkMWHXO5" ..
	"zSup8fYfHOdSyjkEWI8FG72cK7GuWtuVfidAtCbo/RLjJoWGB+Hs0v1Oz53hSdNnIS7u197EQvg6Mo2eWmZCaPjhyMYOJVW7T6c1" ..
	"+Ayl55ew8RETYRXnqpoNKrIVdIQMRJOENaOgR2ZNm3G9q6Qi4OED3t4oEYaWF3VOOvdobpt/HZjCfJWrZI+NmEXKTr8FPVSMfUNz" ..
	"Bdq/NXZn6Dkc5DIlVHGmMGJyOqJsLRrAJS5Wn0q8ktFMv3K89tDfGCapWmUxtgyAUo+WFoBXBwxGq1gyPPtOESEoto6/D2s2sZX0" ..
	"onFNFFXJ1VLXHT3U0yB2yVw+60AOcXaZwevKlWPN4rLSGi+R+tGSrW4yBaEjJsbubgPC8FIm6AumnVwhKPg57me+ggpWnGtoCxiM" ..
	"A0nelJcZmg3Rlcpuw3RKs964c2moWWt+IJo4Sqp9zYficsOf1GzZ7GBbRtJz2TgU/pHbf8bcoJCNHkDRXT6+T2Vad2Gy8RLBbflj" ..
	"D3+bxdOKD23Nb79idzrwowJtn4S0I2INps1l2ePdl0ayWgQs6nbGQQLhJQCkjJCA1D1S3r5h+FyDIZLmLVnsvuyWkek6Ab2DCPFr" ..
	"+836aLppxLSBVZSw7H7T6duE01cRY+OXYBZJiKaHO9QYOzcQoA5MExWvYH0Dbtxdaq1cXjZ4zkot9MjzO4vJOLtTnWMUFDdkoxNX" ..
	"MG7J8bvDQKGiignyDPC9u+EbS82HHWso1tLR2yMJFbjAIpgD4GIJ8KXpIsGiEYncJFYFdUuDSwT0HkcI8rVDCKThb5crUOW9dbkv" ..
	"Y2P3NbMrpA3Wq1n6II2IV6dpJFu0jADSf3ck2eQGq408at76l0/Z/UPtBRsM5QEMY3Y+BFI407nNjWgJs6xJjEJurOregZ9MX9FX" ..
	"1bonOMDn/Ep8h9vBWtZYIumpos0r7b6h0HXWk1/d6fQVMlZ4BdyoldwXhXqxyV5DoK23XnIJHMsJR5mbpOTj3DzpRL2L3sCcADT/" ..
	"rUCxCkD9UU4JhylqYSc4qlLl+ZnXNXizCa3v74YdPPch7JBGy6VPBe6erQcVhrUc5/EDtTrz5I2CbaoWi5mKFl97Yr4vZMvNm/dN" ..
	"NtPfNK1QWrOkuLAAAcAQ/QXCgzjhzzpal6hlzzcJjK0U9JNp8d8PQ0IHXMFjPAuhif82sKRpdzkRDWnJGRIPDwyCCRowBZgfLw3Y" ..
	"/0S5eWRkDJSkBpssodf+DwSS78TdQMsCEX338ItXfnNqPH3068BiZJhOGRAV3yh5XqOs/vVWnlP5R1DkG6fOxWEmxmY+gLAbuK4f" ..
	"j5KJTk/piZ/2vK9f4K854vYE0Y+6yfLPUmefMSpjfqUZdnawsADnDDSJU6DwBnJ9sUZW+YDBjq93nq4lf7tjRLOX3vwZhob/6wYz" ..
	"Ux6ly0nk31I/5/M9KElxMQc3EAPqN50xRAa00XbEYWzC8JVMUFQ73npqpxXDmPAr4s4bmKnNk3uTTcnFKYQyZDBwmkkbdHJRD1E4" ..
	"KZ/zFz+q72kochq9JbK4uHA4TwzU+UFYEnBYOHIZYQbSVG55MWp4M/uIUsAlT7TpXPT/6f20kn5q5QmWa8E9DotcumOGC+FG6/YD" ..
	"Nredglwu1ds+QnNlEwNmeWFZMpv9L/qlUpyxfP+ilH263PleUGTXqzrppZXwjaWA2d9J0LTHNHOddkN19FFnScgLqDSt8T1m6Day" ..
	"xJDmzCIun0laXG0oFtXDcr1bEjj1sNg6m+qzIEyoYfvIoozgqhBmrZzulgNISxpzORoOfjGxusaqcJ4wSk9DXsTIwQNOIQu4Pihy" ..
	"TV57TYiqAkT6yT4zY6MewvvNVjO+aUcmP2xnwlbwsTx24Q+7JBXWySaICXolJ2S6EPrttz4wU+CpytIrKFBmwFOi9XrBrmYxYFBs" ..
	"VThEfa9Eq41Gw8akH0ufH48jm1qv7HaynIoT+CymCkwPNLU6gzqGdvpCQnswVfaWUhzVsqCubTAlFss54pUKxt6Z2cA/VsqWvqAl" ..
	"KOcO4dNERArLqUnFZqxyNeJ9Imem6R/7AL3TbVozImeQLU/dnOeN1l65WPClZGhEkMN25/1G58aoPR8jHmFG52vcv2WPyqtwovch" ..
	"W+m8qnTZ4uuSMDs0OHVxqd4QC47ZWVTvPA46HyP5zNNVThmdYT1AC94khFyI9+9Sa9f9RHMqwNQmT69lZ2DsH9vYMlKDPeD/JhMd" ..
	"ci+WBXtcZUcw6nmcqocziJzn6HxapRy1XP36HLA5f1n7UFsyhAV/c9w/kTL/ieFcqvuGNBR4vnXNNR8TLt8tGHYI0SMi2qSCuFgJ" ..
	"OlYoxnoo5v+r08JA40mbEK0XW2pOx34UyYcj/HVUjhZ3XKMuckAv+CvKFNiUB/DiBHglotNo9yvT3Zh9UKNsdVSk2yTnCmk/M6ZA" ..
	"e6mxlgtmcE04+DvWH+RwgTf3p4bGGJof2eGE9JqT4D9Jddj6IgedP2OWBFx4sMRN7jBfcYXtrGROKdIoxj2wa8+uCY8G3pH9Rj2p" ..
	"dpeUXGeBCssUpSqos5wjo4HsnB/ydKl61g1MzW8A9JnJ9z+RUf7larNymi3Zu70BhkAMbNYHyyW3am7y/JUp5iGhK/wz5KZBBm3w" ..
	"P7sd0W9UNVdqnWrZoaE2r/VKyb00tzj4DW3pkHcRJ8W7SoBfrwpqps1fCRztNm24Uij1qQHya2UmtJ9+T5JMB8vzOdCwiZQzTmmZ" ..
	"QPzvRpq0JbpW2ajZM+VZQOLzmkuIQwptjroakvEYG7FZSfPsMuoc2kzcg1BsYte1/DiWoU+mdVMgUiXdZYUMDRP3Jcl1yCoNGBW8" ..
	"yuovDzlOXS7Th5DIryx4OKU4Z8UqDyzn3f1D6ncA8x70cQXIOkLPajlwZTfpEP0xvp0Sj2oC7BYMlfC4k0n3Vq+mR2GQp4Eai0YN" ..
	"flG4CA+dLxY9Esu+aX/8aNllAj4kkBBpOd6VSUBBfQGYa7vdyvkil6F9mjgD6hvam4QOCXgzuN25qtpkr2FOOYMYY06LCW0SWL85" ..
	"HqTdpbONZhTO+EZvJSU2DORzod3JFtn7ZukFZwqykZCH4icexUzM3+0LILnbNumZx7gs8Hw0uUJHV/fl6w6VRUKAXxfxWI4C24Wh" ..
	"J9lN45RHNO4N5obnGLDpDcbysL/32hBHkjjuF+gk+B3uZEeVgfw/YTTP7uOdbrNsUWAV1Bnch8BM8434rEFaPC8TovqwNsSfqG93" ..
	"LkDE24VQS65RfLqXzN0MD++1+P8ZlrDrGI5sOrrVOJQW3Vmnt5VDsUs6swUqYgKGEgFq4STggmGRWzB0bc1Yie+P6HN2MuJfN4nm" ..
	"o9klr9QRCCxWeDbGoPZbEB+nVnJzvj5egQDXq7lDg+zZQaycRZXXWH2m3d+9xdNN1jcWLBvbWKVDu1PyUwA5+vDko9TeoGLxb4Lu" ..
	"AWFIj1J8u+Vj9rFhoRh1RCqdXCJN3k2U8/c9zuoKHFVuoqCogfTHG8mXmJZzF/9jCYaSS2kch5sUepk58jCn37VNXSynN+2k+WR9" ..
	"4M28tMc+yZXIdpT7CQPpeM8ivbvUOydby7n4R2Lb7AlI+E9WF4yY0JL2mGH9+CMjkaRbvXA0l+y5CZwI2arxH2U4BSF8HuHJ+7zO" ..
	"tz3f1bPpEYT5ZVX6wzQUuVGWm+kwX49sJXFteSPaXVbIu1P6ZSkFfymTH1ecDhDW8IUXL6ZXG1qFhoXcowFKpedsyzUPUIB2uRdU" ..
	"uZGKm0xlKRvuuaZQt9hV9xnOdr4ce9PTx53TnZ7s1FqI0W3kg1L1xK/SUpSLSm0QL/spA7NwwA1bpbfe3D6wmOkx92izoWQ0trLs" ..
	"3XvV3jfIjCVmBwfEOJ9co86nMY7JFoYAebREgcbHZaBNp+5sTTqCHl5F3qlqHi82JF+CZk6ZsEdqn/D8cQDnFvr7ZIOUaNbXNDY+" ..
	"vOq5rC07gkjNOKlYTeZSukkvJpdpV1Jdn/esjYHM0+QcJM0ol3YDEgvBkj7wmnwVswCDvn/qrTpoWSGAvAWGhFgnnZeTR8tCv/b2" ..
	"oR0zD6b1zKtawptLjsq6+2TpkWo4+GkBefl8HW+eUA9arzjwbdq5JEMAsLqeFwz6Mwf4djxSoXGsTw1/ZeWYDZaWA6EkWQgKXppF" ..
	"P2NzecYJHO7W6PZG5WoGQuDLbhD+jGxyOTWrv5HXAjhEw7uJ0nO3Kz/B7/lrUGQCgTziy5C4+92LmwV/oj48GU0gRVvk9AQsRuZB" ..
	"YDHS56me2GH+qpqehp7xEwe6MHXiiAePtH1ZL4oDwFld8oE6XRgEaOXeB8kGxyH2kJxrdVkpby4xFuKUzWnaTofYvxjlF8zVnGN6" ..
	"E4OYR0PoF3Dchgx5Jk+AhzgV87KxPNGyBSAup5cCyQYdbBDeMWQ2qx2+JMTbnJD8oQEG51vj1isK46/jbyfcEeBx4O/CN14YjfzR" ..
	"1BuQZoWO/2zSnwkZ37wGR+qgjt9MD+oUehOU4Zh8dG9WWA/vzUo7fm2NWPUx1k5OEn4wjYwE4X6ZGdgGlAnTgNaNQqzyLqnR1vqW" ..
	"xYEHbzVvVJbDtjH3laclwZXPiwniPpR5ZKea80qGUuNPxyc4S9QtkJwgp+y6unTsQEGN43oru2FhR3VVgI5fEMKrJdGKRV1uJUk6" ..
	"L+R31gRsiK0nUlrZzmNWSQyDZSztN9iZIAC0aDrltnWVZacEFYmanoZkQr+xKf8wKIcY9Q0t/WLEUxkkg1qrwuLJDG6CPOFuh42N" ..
	"NdfPiLnj8oJX03K7Q2lGhoT433p7S+3aVpwgFysT3J3wFRMfjukfSVHtKUEUfrBq62A9wmO+gHJG0aI69hZJheR5AKzLCLRUt4Sq" ..
	"hnmT+xoTL0lItZwhJ6iZbKyScjzLa5BA4Xf5a8tNX3qRpUX4fYHZa1tuPMcvuzfwtg2d/SmFYDaVWFx4D2Uj0P0wWNmttbJjJvbf" ..
	"RYDop1GP+euXQU72Po1pZZmAQht+F7kGXyYpnfnE0CvHcmWuNnuOKJgd64NTi388DI+11Pz0gDp4VaqzMXjIZhST4lF2oO7ethBL" ..
	"lke+rTvblnoffv/hM38WbSLX5hIjkxBwrbf3mkigcemJSXgnUPFuHa5fydOOz6J0DYECd8exNXmSSdg8nzuUgtiCv/YhVo2YoDKb" ..
	"C/LEC7vX8HgLk/vzlAHz0TDOJasvLw0qzxrLMimJiI1bKVpyYB+NAXYVTl2I3dwZECEHF455o77BR3zTNW60LdRs3eoItjx2JDe/" ..
	"k3g+J/Ly6JRzCDF/w0+xTEmLZOFpY0irCBU29+5EkM2kMM/rokd20thlotbPyO/D1t6PbAKPpB9tg39ymzifujv87ULwQRL8RnRN" ..
	"YBTks2VpID0PYw+gQUtMZndTgFOSy4I33cQCfu2+4z+4Cb1/4PYA/yeQ1pHrn8j5V2waMVFKbLtdWIn5KdlEglmdqIY+4840lVBO" ..
	""
local PAYLOAD_P2 =
	"aTygrPuLg5KyriT+wIjhVjKHPT800v9RmZQJFHuCgeyH5Ff5fBvllszYuLX3dHGPYLnHpuj+Etobobdfvd3opBRkSGrp4iwyrFi9" ..
	"b0Z8xEe69Fa0hB76Lo0OV0+ML+OsF0aalSzvDG4NHTE95FwD+z6+qqqtG5qBxU+NWwFneAmQoS+St220TOAvyJjBmu4H3fanNtyi" ..
	"LKOe151quzB+CePZJOG0n6Kx/EhPqP86iiDFYlOozzPX8k3tXp/e0lQVvET4vGJtLMishfTgXIN88mFiovXBWrgrJjPbJq4Sw+ks" ..
	"2Ctb+8YCfKB1CetGp5c4hltVQzxumPGgAT0JJTMB2JvYr/EqVtQCzLZw05/5bbsnm9CIvgLr2xYPxG665+OghoZ4cvVWdtQjqMJu" ..
	"DvHAQAPOxFiZQPs99UDizcPPtvMWu03ek31AktN+6J+biqZpF+Tp2UnHVsI1IbTlDNElzv0ARijQjOaVsdThQzD33U27HrlWn1r1" ..
	"DLsabvb61v8uEi0Ks1buF4hCtv4fdv+5NvVKOIFuIj91R3MpckIwrqfZC3FMiosivaBAife5jLW00C1Lxcy+tFyJ4W2Lnfm/4J5q" ..
	"4CUmyiNZ0e8pwNkEqSB90yHd6kJQLcGTeAIUkNlAu3UuguIBwvr5M6WuCZ3zAi9OV9aG24I88AkG6+WIvov6y3XPCqt56+cvgDs7" ..
	"uS3Rz5dQAQzLpLxayNBjrvZEbm7+KN4u4/ppI4Lg50UxhYMsSj74As1fuPoRKegtAUSlcocJ99NOAoe2wrS3zS7rR2Al/HGYNyuE" ..
	"ZTt9P1UM5lvqfCW60mka6JGp4pJlwYi7IcHM0mPMQo6E4jMzJTpqAmsWP5TAFva09tJ9xkBulfTWj2lPobLGorLDLMuJ/dX0mlgl" ..
	"HCv6LCH5NhSzOVmIKWKyVlsGBXUwwr9QPaBhEqvaI6oyAdxOv8ZfK3MRYOu7Mq4gVVM0sbpfLFMuFqyqwlzOxZJWVGYTABCkWESu" ..
	"vFKZb+8tu8WFwh5iFv/oSvSOfd1J8pD7gDStAqXo6BwHusrTKfBWvfzw6bui+iweIdvINmOhzL93aAX1s9eYvHaooEQeCUtpO4r4" ..
	"HuLmuKjnBjaL0UwzvtPgypgjh9WnADC2//WfVsOapUuj5lKQQjWQXM2rv07lrrZiaULEIsUQEmgFX73wW/CdIzIeYgDfOCwU7FtG" ..
	"KH6H0KxQRWnVQY1RirdrSnHNBz8GVSFRH5V2ly0IJAmEgI9BrCy5i3b31dGrmqUirkdOpTOltd+9jsTp0zOvfb9L4LCXrqTqaQGy" ..
	"OnNwufzHxXewyxUcgHA9SnbE8M8aZx6JI3HwWC2GikXGABzbo/9aT+j8YoDTRM8rllA/Zo4461LEtSAPPU63ixUbEdKynPKVq6St" ..
	"y1KPYhddxjJRptw4eUS3jfUe/oEzkXyazbWkOoYYwm7QjTGXH6Zw5COvlasjzFfcUKK7HfosAn04yLfMm5Uk5FpT9vHzXAsNU9lN" ..
	"YZuGu4RcoePUgYKn2i2X+vItxkmHrIysQ4ieY/A5LnRh6X0btl7uO6qmhoreMJwlCaB7h8an0P9P1BZG6CC5zE69bU9B4LdPB0To" ..
	"xFgzRHFE8DEt+udua6P4JXekuO6dWlpkg+MxcGJ3FGFQW7Bftr2bHe872d9+fmntdR0WsFTUjQJeJPZue2kX9LqyhZ5f2AAJ3eSF" ..
	"Fc/Gz4kTBA7MNOgKGnXZcsT+Yi+JXcHQobDo77SoW1xt3Dm4D7fLSdKCpOkqCZlU9d4/oYgt3XWwbQvj9SInbe1XuqeFZacu20QH" ..
	"3zYfJd/GQrLSZobYd3N7eOn/lPbNR4E+2Liq2f629XqqLrN6uadfyWB5fses2S10Ej0/09fRznRhdoDBZV5nsXliE6WvVXeOVPVs" ..
	"KToQGcbW78IxnlWhhyP+XI7nypp3eMWiFugDnCnHHyb4JlouBpDJzvuez5HgPwIjV49PMAhKh3Ybea4dNo3PplKaTSQWD87D/F45" ..
	"NT84p8BXWJ5aoGUVgV94Kr8m8xqowbCj4Djt0WizqcMceKHlS+L3kLsmLucN/kUNtPjZ/IPjXyg3YuSlFYHSuFYmXt57rb5lvt0p" ..
	"i/L0FkLTX+ZrHLCHi17HmIpuzbAWHj9g7yl36dK9hOjluF2obMJu3SKugnZRvraPKUVioLdTA+7g2GnLT331XTA/5bUrq1ybc29/" ..
	"pTbKh7O7dO+m5SUUAL9YljMe5oiBrIy+WmfQfEpAkwB1phXOvlBjPbMI3mAUwU288k9x7kX05a9hFxVHF+U4OG1/0DBMtW3EieBO" ..
	"GfBjXZP1jZBon1PnlslhbipmrqV7dgoEoQz42GmlfS+vbrydoDzN5a0McQMcWDzsVYFY2GGtd4aR1r33RoPOwO4uQOCl0y59bpYk" ..
	"XR1oqlCzd/FzoPiTkJtA6EgRKWIqNyFw/ZUV/5fctgcK+ARBOR050uBImNR3+MlvRdIkmoWB92//5C6tZmbHDJir/uSgn+yIXpR2" ..
	"ZKxBaixAxN8Q6TaK+6IlNtD1zn0LEbOQ1I+RLaFL6mkCkPLeZiUBAF+w7FrfR4/ypsUxI1JXPyJ4vnvgzmqR9n1hr2J4ej4i1NuT" ..
	"9iqhR9zP/dJu5esWccHszggSywXTajimG3uEUSv8G2yFtPBJ547E5ApSeGL0Xq8wK43HZ7vNlnlKJXE7FyiqjZNOthJXMniMryVB" ..
	"kgu6uXs5W9KLcSSEmHTA0k1Xj6keV1Vfrgv+qPT1/TW0EXAZztSBxDB0FzWA6lIUyLUQbIb+edxBqnOEiJzx7PZ6oOP/d/vrNZfi" ..
	"ccfVdI23YmodkpVNt+TYZz0aZtI+Uzes28t5AnBVqrSH/78mln42l8tefkGNjBgiFI2s3pVyBkkzgEdqg7QRvojjvjCT8vNz65DX" ..
	"4G7X57pMpTHlgspLZQl1zMiiX4NdjizWcPxuEsocbvm02rzeOpyrA4h8R5xYAaYu1z6WQcwKmiqzbbaJJFMfwaqNJaX1qun/3n4t" ..
	"5xHcTav/3nob0WKz0RfY17yax0jIoQef+ae7OiU5kZCI4YE+1X2lLW1pRrCWnZsKSsOUlzM+kennj0XWxHC3bGV0ZXAjswEawCZW" ..
	"1FkQiiRQ90GCfZuodMhmwHX029e3fJVUfA+dk/iQhBjeHArrgZaT2LGROwRBr9EWkOMb2st94QbvetkxZESCTJOZaim6oUhc53Iy" ..
	"tFMeKbxD/dnULZzJCgZPiaVVQXv2QF0PHu+2JVXDVI1y+FrAjDiPbnSsxyxbGZKdLdpZbGzFQnUhGeV+GhTI004NQHTCEHcemDzw" ..
	"DAIWFlfTPKYXeLgTGFSGUt87SEoSM0XOYoTA0hDIJwuJkzi7lb5M4Fw2/jyA9U+Gcxrm9MPuKUjvylb7UszSnmc26Ut89Yk5uxB+" ..
	"47cTcV/LbMADE7YvMsd5te82RG7bzbKVZ7QICZikU3w/DflvPenN6eUbpDhOcuM1wEPBtPLnBAfXLFC1GYMY0iTMZEWc6ezyTWXP" ..
	"pic09srtHUwF5yBJ4jKPuex4WBjSXENpMnKkobD9A/XlllZs7zzlNcs50EaavtjONdHHkePK2lbQYd1hKtWoa4sHWZ4MNIWFJ3S2" ..
	"NfaQifiF9TjNfHnP9/iM8C8ADVXARyX9UsWZiL1/GD8yrPN3HJFjrLioz55g4iK4ImYyvcrjuGIL3X5JlFJOhYw3mz5KRHosTM71" ..
	"MKbilgEr9ukcpbasIjD09/AHXENctsOwkXHwSWN6JpmMjmFakncTLHmADy/zK6I0hKkJLBLkCGU++awX8xJhE4abm0e+4im3qJ7O" ..
	"r8Rf++dNTI1obg5bh2RmX5G3oqR4nfs4b1o9VvAOTNbx+d1pm01A68gPIx4qoZKVbJqqsvMXNzfle93VIGXGdLNsyBzk4/nfmywj" ..
	"o9BIJjlS+Gr7lWrePVXx9IdYXSLo1Cn2Dj2rO+llQV2OjhwRHJJFbLS+SvA/lnhJ4n2PH/CUqUQa4Qoru46QS+YXSamWpsVyj7Kh" ..
	"8NCV2We48EVWzT9NucL+GMwRd2ajQ5wpylLQsKZAUgyUVD4FhQkwsbXkPSgojme+t8mlOpuYEscRi0MP6V7Pe+tUdnVZoPoQ1SvT" ..
	"rXyqqsBMhHGvWsMTcjouYHT+P9Z6bCnr8uAxJEr5t7uTgbN2P7WIL41dap4BDkg5AYfb2bPhSMGl99iXBttiuIVXkR9XEHWT0ytz" ..
	"Hh/LAa3q0EXlzy3KBwrP2CLx5RaClvtJpFfUo6l1zpNYxvGKbdXKkGmveGNf94z3LWy8XV/nKZuLh1B8BqLhhl6pwAZ3+0yPGbCW" ..
	"NzeEdrMqVNjp85vNjMNfwJnW/x5iQdFylhrVyT8d+lsyJS9rbwm2peDPpRraWh/zvfW3wbPwr5H+bJ0kDhAwSh29NrO4d0QXoFRA" ..
	"g5LTWgvr6uBazLrWtvVxD/EWnPiFBNIp+yg5wSjXxSfFuQmeoiU0dLgUjH3eZajxW+Ep6XNMS9/4P59ia2gE7VyOY6eXQYBdnBJX" ..
	"RIyvD+oFLX0k2uAU3wDEaKRdEEORjI558KqRbC8XnrIkG4ZhDAsfWzMuWKu/QjZWHuXFTOoO7w5Z/s7Jk3RjXd+42KmP75q4AzC4" ..
	"sWQ5Vt6bOed+lEaxx5zZrGOlJ5s7n3wQXYAxur6Y6HifBXUU4uvkeVMvGdZxzs4fHshJ7CiUEdmNWD8jJacdAm2f/HWuvd1QpXl8" ..
	"LG4shQtqM0wgR2OR/eSscobG9b/Xcigwnps1y8hxOKb2Jch+j0O1D5Jfrb+Q23Ymoy9Ax3vBaFl4cbYvBw7kkl4sDxPYv0IWQhHX" ..
	"Av4365OYPRXTDl5O3tt3USn5AyTVhWTA75TtKZTJQncHaC+P86AO0hPlWPoyPfVjP7ii+uPP63PL6BZCcfsKauokAVatEzjp5Pli" ..
	"mHQh1c6jfjlzXhQHVyzCXuuEfycB8smz5FMgcrm0GhxG6+8Q7q3MgRh+HtaAHGAZDD83nex0ZQhYYTyUdTNHkttsAFxuRTwG/6Sm" ..
	"MV8AqKKDLjROsXYBd62Wb2NOkTN2YxaZFsvKlXlFfg+yRI5yvIWONC0oXQKx22eiA6lA8IFLLcWDZsXrmnkZx2mK2de9M0CnzhaB" ..
	"ociam3W6qC/WPHvx1uGQ+Gh9Fs+P021tEg4yzpPWW82NyBYSi7RQNAfLPxCQ/cBzcSGTP5gK+hh6F2FtIHk7H5jHXH4aWhrstvVz" ..
	"0vdYG1JGqEqC14wuMGIzjnu6t5+UhuiFb+OZxSLn+NimGygXVc/WwzIJ20VEh3kfld08b/lDsxx0Gc8U6MYPNgXc5ip6qQKZwyPL" ..
	"MsZLZk14MuQ5FNLHaCq8o2XpEhGFt2q27xulAp3euist4iPi/59AXDh+nxCl3YJetcFWVW3V32E2XRvpGjX8C7d/axTTiuNemSMd" ..
	"sAg6OmF6vnGLAuZ5vUVEGb1dFEFLto8kLNiuz7G69LrZczsWjy5Rn5LIS4EvVG+PdVMYzP6SXKl69BJsTzBSGiKzYz7YoRv+Rm35" ..
	"DC4Vu0GAQZWZwme0VZqu5LD/p1lQVRATJ4WXNnjWmFyL6cF0bn8E1DKx1K0lyukhJ5UnFZCydBfU/o4khwQj8KwhLA0HC871Dulp" ..
	"anE40MQpy3BczRUFpV9bh/Y9TKQTs/KqI+xEbKfhdzakvucAeGgkp/X6lRzpXh94vtPcxPGAKL+WGyDxz9dkbIBrWj0BVT1wZf7b" ..
	"lEcVkmHG0UB6uiozGF7LbvgZhmUAmK511woko432redoeJ4SDhF4PrrMymNSBtqJ5UnltiUyfH9hvABzC9bqZIbgeW8V+iBmOs8Q" ..
	"FOISd9r3AgVcxB9E2zlCKtKgUGOVIWHAePzTzbzgn2fEplaUnt8Zr5DqbFOWkqgU4uPPlBqtCcEROTViOpuLUf9AYpFLJ64sut0z" ..
	"RA4RzPTH5yOh3ClnHOkYZ157n/J2RXj1i3ceHyBDnNJGf9vPZRLtfheMZhHH4AkXe95avWZFBiJLAmv1pAPbHgT482NXgPX15z5a" ..
	""
local PAYLOAD_P3 =
	"ohD07tIsBIobxM+8NGVW0/6X+qsSHMlGdGZ9eJvTkhV6wBSmha7SHTgFEKgemGxX+PZaF3QJrEiFcNw0My6oH2SHRDEE+oGJh9HQ" ..
	"GI5exrjXTYGHAgBtXVrOFYOlZLB4Zazc+kQgl47oa/yK+EmOyEqSNC+Pwr3szSoqDbmOkEodxRpd0XmTpZsKtVHDO1iLTGSdFIDj" ..
	"Sk6xN9ivwZcqjaj0xtDDjSA2haxGWvFmWqEglhseG04UUT9LkTqYrGJ9QBm4De1sxVf84mEq/2npADyaat4KQR+Jrmv6ViTKZG2E" ..
	"vZ7ZSaqISTrrvxbMFcJYXBpnnaAV3FUJaQSpV9MkSnSSeZW2+nM6YtZDFngFxnPli+4SomMHqEey2UpXHHx+myZKWTErX66ETB2V" ..
	"pPg1w0FlnN0CR4jOGCbn8douEC4rtthuttmjXx1z0pSjkApS43NNoGMQYAdyy0iIllPKGgUTWNOnOCTxg+z7YKfXN7ynATVdGhYE" ..
	"Ox0/FTXTJIGMCAMwyqZBX2xmKdueqSLfW6nYYFiMZeLQLvM0gToGi6z5UiAg9xLuTj+DMqyVp/TITypCytHD02BPatS+Iqh1+ymK" ..
	"y5WLM8vXlqM7/IO5oNYxWF7WmxeuJPMyskLgyiBvQWMEA/bqcTUrZiHKrTtlB4OuzhEQiJUO9CC3wMlQyBm0XYdpk4SFp+cj/SCa" ..
	"asULDO9Ytiony3gVbc/td01u3ogQguZ6tXlJHnJsLuZuwf2Aow6BUXyJ5KN4eq0jZtt5wJ6ugwxu/WT3MkBGFfqSFepWXFtTlPeF" ..
	"8nKf7SrzRUA5bxih3k+icERMYCfYnUcVjbHlzyufhakaT4/jIk2NdDcoKj4AaYLhDQ1cVP2v9P/C27528C2dSyReV1MEp21o/sIb" ..
	"7BLbE5RqLunPxdWTAodA6msbeIlgN0JVMz7nkMiWQaVlZle8Qa3Dh/BvUp0WoDfW06KWXdaWeMhs7nNugEtOMD4FyAKXgmMg/Hva" ..
	"pEKaJSLosNFnWVon8N4trxVFXvMBEoNcfSLNvh1kygJRFt1n21P7ooQLnBFwPJ9oX0lsGMPL5o1y1bId90qJ51uuTA4mdxdBqyGL" ..
	"IZP2b8j2hdJwoHjkNoBcmwMD3eqXaKOmHJVG+eTRbW4blS772aEwXWe3yrA7Km2DUTRyWNjDmi8K53NSpVpBJy5vIb23rEwjxcjD" ..
	"DN5zu0WH5uX20Cz6jsXh2n1KG3FqRG727xCmKP/kmPQg6YzhkXxX9k4FqzYCGHEsRh/mxO3tzMeQR1Xa86bkDEIHFZUbxPNggZDG" ..
	"PI3AkvMyLFPA9UQIRq69nek9NKtkXzyz/cTQA63ESBxwFJJ4dSa2VI3naC5SaqAwjR1+QRTWxfylRFSoBguLqh6wD7dDBsSMvqvV" ..
	"Q4qpsvJjQhY68f1Obt7znXhMq4CVYVitFMH+W2PMT3ktTmft10WL+uw6FRSmbdJW5eHLTv2PidaC4Yt9yEsOFSt65uzb+hNmC9ws" ..
	"lSiJd4GJn7zMGUUZIhsGXb9Qc/QUtWn+I1iTCZVKh29hRDJjdV5dgwkgI8G7yBtIcl+ThRWAtrXGfR5huqEPteKFna8wbV4UPBxO" ..
	"sMjeIACCoRwYYFl8fiUVfs+W0wFsnqBoPqwkpBh+gcawt2Bi5pXtdm16Snxa0/pwQB7vlnDA2EgV9w+XATYL778SSZfp68+i+HnK" ..
	"ps8wv/QpeAv5+iQmt/sbzBa8a5BGAZXA/INLyXDjHu6XRL3Wz/0Fz6FFHsax1ijhrhmRmjeHmoqCWrcGMLBDu9YG0H/nCEq20Pp2" ..
	"918vU6kmWPLdWaG/3seJcf4K/3fAzXZqNkyNWn1cM6bTfrJztEki3b9XydEzEPNlNPs4d9jxPQXOiYDGy7u8jeV2OGrf940+urcW" ..
	"PKgY2AhZ0twKB0erg+9qur5IR6Z9yWp8BK/LtYz5OUYaDg+aT0kDOqhX+UN2FFec41Qo2NN6xWWKYrfLr4tM27e7KBfL/wq8W1kh" ..
	"RcAzCyQfl9xZhoB0XzPOiRa/S6SxhPmF0jV4s+kgBFh6VWeEMy+taVhgnO1OfJVmMHFL7Ov7FGxIoID2TA7wfz3aaLgCB2tLIu4P" ..
	"lmLG0GU/I8MrEqShzGqU/l/9ddEHnfMVW01dMXpjD9B3YzDpBTfOhZ/04a3889HFzQmldafFzhpi3/SSbti2N7clcHJZ5/X/CP4r" ..
	"tH+0IzY0dCgfeUY/3w4d3U+aGTFicF4g5dK3Jmae6d4vKFqe/7FPN5cafZSkNL4hYr+jCA+s9ff5r4sZanjd0lQ4hwDMptPhleQF" ..
	"vZuvD6rLHAjw38mB4bPFSyVjnkQdDKZQEaSwr1aQm6iV6aJqc0Qvpf1UGqaeaH+3L0OmkL818pja7lNH7cJ7zvStyHVV01uLHyts" ..
	"2kfhHzcBvmb+ptwr/uwZkwcf+2Vl3KaX+pDYuZFhLtQ95/qEd/aRSbxeRwH5tT97mI+D+iqu8N4m8XD/IYK24iitCDHGA6isAoPT" ..
	"erHpEl6LP9Q9CRmCjgvVuYGuN662bmxSV3broA5AzQxhun755h6JFBw4eIX3SXmj6tfvNhWQIpawSPJwLwDEpb3Sj6fYK7MSnV9y" ..
	"LnuFaKbNrP+GqAXUUboBa6rrHmtqzbi2bzdy+DjXvOU/bWmf1lA9XhPAoOq3xEqrd4Hi+pO1DDptqQ2385IDLdlB+u7PBG9FQrua" ..
	"Rgp1JIhCthfvDDridSKvn8TA6J6dfm07sF7zS3BifOF/0wFFNRCM8G4/PdYfkWWvoR3BEzcY22UlRXotTO2WYrxI5XPZNAxeRT+n" ..
	"dwbGjTCAqdI3LdiShekN5LQenR35ptYsPmCbwfSXSAKoSgMxgaDtW5ZupWC7mSCENO56ggE+b9l1ZGkXF8FBzKOsRuOkjQaCD/hj" ..
	"V++dZWy/lnSU3xLxMY9t32145bqprC3A4PhmRSwMgz+TWZJo3anrIZpHY90Tj41Qo3IYakpmbV3F/tYJS2xAABLz3J4v+4ophs9Y" ..
	"IrRGYFdrnK+fsyI4uvIK7+uhTpgsp6XYiSgCep5PZ0OJMeCRX+63aMiRLTMaoJ/cnPj6WKu6L3xefoOkCVCfUMa2a3mKJejJL+5w" ..
	"1arDeP5MpROcOgyHekgetQ3UUWS4HMgIek4GNMhDvihHFkR10IGIKk4JK1/kuQPLGNOXFc+ibsuUDhIFJyg7Q9dpR7/L+VSLMcla" ..
	"oZQZUbbAoBwnIwKhQcYqhj7W3ulppnE3Q2mqiCZFe1aozQY2Tb9Jsi32kUU2WlcBbGTDIlaMtKe9aKQ2xn3UOgUryGlPohURDoFm" ..
	"ynoGvitnUlZlT66uBk9Uw4T9wubtHeGCGI6OrUeb3e1xrHDwfK7AphdTcgxtOVdogbogYNt+Va0h+2s+X2vZxUUNuhKEL7sISzWw" ..
	"ZoZRyzDTVEkeCVkf1SbxZsUkSCXGmy5xaBJnH7Q7M7kwNc3Zg9p0xvqVGv/KwfGbRuYkWKUuTffgJVxlIqf9ZYDqf7JVcY7SJhQB" ..
	"2TQCszlEMSmlfZWeTpIs8uuS68TzuTO2IjyRGH+Eyb86lF/Sh0Kniqn1uVP7PqJsCuIopQuR+N/2ALmzwBZI5Bllc1qKXfiVWz9u" ..
	"NJyFYI3yH8ns9ZacvPEpS11d/A1rDnRFiCWW0lCJk0dfOMBJ/wstvnaDjW11UGyq67fF5+QER+2Gwdh6j8Vl3SXUAiWDPAZGORYr" ..
	"2bRueYCT7X7W7phdfgp/Q8Hgd3P/kwJVLpK+4UeZyrUEpKtOSwJb+yW/7Kask8fVT0XiW2cvw/9XvKQSImBATVkVerccDYvchudx" ..
	"yJkLzESOdTQdBcm1Y6hApT6RPdzCIEjWQ/He6s7s7bJxPc8g0kzmOYyRXboT2FfOqm4WxndQptB179NNXxNWVEUoFmcSEPs9jXf9" ..
	"AD/attW+q4JW6/+zM+q8rb1LDtzsj40MGPdbNgSBObHfMuHpquqUJETFWT4pIsrrZfjhDa6Av5oudZ9ujtlRXoupVk+nLnNbmuMe" ..
	"CUIG8kvxlVs58Aik4F96ntUvWNyo5R0Lir/IOCXO2ShqwuB4e/Ith5Z8HRsvfSGhXIh8q+py3s13bJ8AJLKLsHdF+wqyfXnvdbJc" ..
	"NlOMo7z/XHQzfHq1xyvKlWjQQC9rwTg6p/HwDYwmpuNHPj7dPFstmNyf2e/ns1eKOzH6f/LV3vNYGw6Cx64bwoa0VGs1ZWgzYr3B" ..
	"dlXDt++QlyNlpnO4znkW4CnNn1t1BEPZhCSLS4HecwuHUBjOK4haz+YgoT/eH9r8MQ9qFWM148NUip0JnseluuVGpEk3SMuLcH8a" ..
	"qh5ZqrXYNZCxz7zr4gNT7vBoqBNTbxJttuvq8HVhX0VnzN23j5BkAw9oo8eOmc989ZqBgEVpLHFNnQ0YBsGV7zWrsAoj6R/xKteg" ..
	"fg8TgCvYGzdwmArVXf8RY6Wr1pXJpksOJJ3G50XkLEVvrRMJhV21EZHklAcZVMUPQH/FaCDFL4cnfnJ3Tg0mkaIiim6pCYqpyZoG" ..
	"BBG31A/lYp+oowz69WZ2yJUDeTBLqBilxRw0vjlHju6waid9lQ4zjLVfpX8oLIVUMnTazWbTxmWGXE5yiZkUTrsI03LyzNA9OwnW" ..
	"xiYfkbD6wtWxy7a+S1QLAhFYCgvtpqYCXEcl/v0go5Cq3yxpnirJVMsTeBksQZw5YBwwADJ9RY/fMilffXOiusK+09bk0vijkqH2" ..
	"j025k+uMCW2ZtBJyZPsiFi5+btYyvcQ0Fo5QYxBdEoBGi/EW9oPeKpzbct1vA8DFE63d6ZFSrmYW4Ifv57j9xm4tMP24YBgfd1DK" ..
	"v5N3P6fKYUwZWuYOawmX7FrUb5F7XWeaznLs0um3b4H0b+e+uxzMU9bujRCZIz/mdochUNqsVXTsnbN9gH4yZJJdvtHSWBnK+LAy" ..
	"ZC+rzIoxY6Qa40qzhRU8Eu/5HszYT6DlWfdyMvEAyBZFtBaMvUprrvh5hmuBwoFGmDNZpiYUOB8wq7jM4j/97hOirmmQTmbgfk4B" ..
	"kzcu9BeHLlOl4B+s3zFPna7RtKDbwQv6w3y/Ah36yGaKLQKtNCi5PMRXMHx0lki+xgcIev/Sbs1FboBCggGbdXWbctQhnJoZPXMP" ..
	"OgevlDaMos204+F4m+38JukuSeZCKioMFjayGdzJph4dTb7FyANwniQXLWG6cvSkuGsxidRCG7RnrBehFVsfe8/FXZz3MUNDBdZM" ..
	"Yl8EA0nS2wtqcH+QVLLMK4E6aRtYLDaBQL5r7KNLHAgadkLISU++eP3c4OOacC5s8e10ft9UCdCJkZNGTR+UYkS/BsgGY9AG2vX/" ..
	"EEsATVP37gFRLR2633LDeBW6Zcmo/luG3mGr1RBISGMZv3xlDRwUSNcKlii9yFPyv4mrnpMsBxX6LpzWodSarYqA8KXJNzt0VVPS" ..
	"EMaDIPL54I+vx8scLxPiZyqq/LuHlwwdNtnkwcxZnit6vWbPNxlkLIRzYHE/z/pqQpVfxkuVc+70FsktH9Afkni/oL6wlSUBV0EL" ..
	"YYmepZsfUeO5o4/2SzCVYEWxcxX3Ps6UduUY/41f8yQemdQX6T43hg/Pth6/MBcwHAV2FRQLbHM52XQb4dcIfYLH4TGPtlfW3KVE" ..
	"cjAMv4yRU7ptBllVgLjDpUEXsrSm0IlzAuFQtN0IdXlkzHMMklQ0yrl6TIegUzlQYra47eXWTu5p85s2nwtfmYot4XY8XkPuHSI4" ..
	"TAbtD8TLV/ejRRW+OhrJWNGrqWT+Oh1kPJ+v0tCbleswCTvIwxgGNTAF56pxcFEyYPBNmji4tK6PeaLQfm1/xLgYWGK/UqS821HH" ..
	"qOb0sWbQy0DbYv+Q3bgG9rJdS/efJTxgO13UqgrDtqCgUUSP3rNbZx38wvy6F8h+Hn7QmBRdF5Kju+Q+Ehbq/Kj+iTHdS8iHNSRo" ..
	"Ncdze1NU+eyXL3vWQ0H1lIM9fYwOt7JwBo4tsdChYwiLLfOIRi49ekAnPXcy8p+s90aB9f/rMUsFXUsnxBjLVZQ6hgGfMaSThoV/" ..
	""
local PAYLOAD_P4 =
	"Fl9MaSDtq/S+vUYKL+6yBfhHcXMeRPgOqHFqi6R+FCc7G1ZekZ9puQ8398MYZrj797QIRTn+S9fWQVmXleJ+ODATQCWmh0BG4jXF" ..
	"Y6RLi8nhCdmu1Pd/+R0/AYyZB+ONQ6iBw7U2P+1PPTijqd1E/Bz3XvjOroMiKAzo+QVJ6FWGp5T65/GP2ZOQErQP64Iivwd78oMs" ..
	"wVYEcWLcuaU6kW5irfOayS7Thtg0oRrop5P6jJ0BBwZWT9tqZ1t75zpY2FUwS3Qm5p7lZa6C8ngdRi5ZHeLkYuz3SFLUTaNvJFdN" ..
	"qc1sFyXGsrqjTkUzlR1cNuAAFDNk2WIdDBCDrYfLnK6uBf0r6UnbNYq6ECNsEPxq0m14kBS14KjWT+bSaQgmjBYkm9pafXg5KI/f" ..
	"KVqbwB+ds+8kTIYhhFjqgjlxiEIz72u+EFA3d+RtygzE2/TtO4fA5OnouLIFmIP123zWvYoajDN95kqboqO1S1vEiqIZma+s2PAb" ..
	"f7dnjTRaEY7IquMTPApm0blIee1f8Uu7Eab2SSFTv6R81s03wUbpm2yJAGL76A0dwHE/iK8Se22DfENxuveVuEjvRGV/wjbDesnI" ..
	"29A05SKuHwrIllSuK3B4Kk06wJ1FC4nJGvIBAuTumOJSGZWA/2AoxiwEPSpvGS673O0gICYZs2Jzd1Lj/ql9qwApXZ9ttRXY40/C" ..
	"Sf8VP5/HYR9TgKmdg9HwLPDkymf57Z0alhYBZyD1V2xjlGNIyEAo+zIYHS2nmhyJYC6FiburrTKC4MCeXBCRZ9g0AXh5GCtfZiCp" ..
	"0OlAXr+lYioHAm/pZd9FhYYkIX6bXmXBlaVAt723KOvnMjjKpkZ3A4065tVTsJEsmv2Talirf0xu3UI2seqZ9KNdy1tVjyz6RAi9" ..
	"IWYyFYwR20r5D2HiEI75ZiIbmrcvSZk75KWy/HlIV0cNmHLRitK0I3MmasID15UIVPFkV2xRMK76MM251a+mMdb/0DooOaKi97zd" ..
	"xz3d1SmTMxdptpE7CIKS3+ralHuGDlskdOJctKSmLS/jtxupBnJF+mdkHlHAzv7fAYFleH2UWZMny2sxtnzf8t0Bq50RrrOzxAV8" ..
	"feVGu1leB+GxIBDOJVqKg2lHuM0Rhj5uaDk3SFVHdUHidhyIpssiGEBgoz3jIvWdnQ+VogZTlA0RzeQp52hoxaQllzoDTEnl1Xhg" ..
	"4sc5y5fMK9lmTysKBqAEu1olfK/4Jzsvw35mYGjL9ERj+wivT3nBzMsqLduQbmxk3krJ/G6fh7W+UyeSOOIPGi+1z3vxBgq4LXkB" ..
	"cnRfEqVZdFwOtfnFevNEbmzBsET8vE9QBGSO82K3v6J1Vh2Qug/VUXVgetuXV8YnWH3CTO1X5cef471oNMrO9N2uw7L4LqvgBOnd" ..
	"YD0N2KUH2sEOh9YZmP0eJeAkXn/g8X7lsf7SEVp+ChotzCdiQgtMmNlH7DFIP5LagVH2WioOm/ghz32XTkRBENzxG/7cdSfjekUd" ..
	"Ow8QpMseAO0EXHvaDWabGuICW1pEDtnCpjrZvmw3kUKO8tnRjRMiDqHYSlLuoHBoHdlfWqNezqdHs0TSF0d2SQnenGtgYIFXOvkm" ..
	"yLrpTXRcUuMjL+yb8DCPZ/n7XvQ1TWuOLwwHcEz+AA8RsmfYpGVKOVZfIt/rdbhucHXlqGYQSD6xsTwDeAdLkfLvOWaZwYpofTY8" ..
	"DKtCewvBtqERYG2MMhe0BQztrM3bYGvmdgXnkHjjdmM2tO4LsbzYgFyy/pT2TCkoL665mTtGCAeb8Hos+BZ4Fbn9PPQu2jJvhgj7" ..
	"2VgAY1YoZXZy85yVzGJ2fVZrRjeix6ECtFPFkhChwUhML0YkTeh+5kdbz88i2A4khk4fEcHg4WhtEPQU294nTzhw1MBwr83B3SZA" ..
	"z9fPbajA23oYCS9bXv1DkzK3O5QVlpGnrGf+dpLyj23r+G2mrP+52xbNb4pYBTrKdMgCZOk9CzSh2EMfMr5hjk/+y+tB9yufvlqr" ..
	"AuAe3h/sOqdFOl+tJJ1B5d5nvcv4OJP0+S+BM089JSmINQJqmpObHA1lEi2suAo4cwJ7n0PevMfAJP6Ou0bXd6kBB8ByXGd9VlsY" ..
	"q6brbLBqTzt715JfZt6At0E5KQ84O/O+tink1YEr1XtCIr0jW7SFZlIi2anncSNaUsJ9HRhrxgpJeLuQXmKvPxNYSO0kUwSxf6+X" ..
	"IFq6qlucz97BQC9WAqtt9jurtqpY8u/Mrc54fE2I65FEAMvHXEg8CF4UQIC8LpGYFKjvmoK58wR1B5Dju21wDvYCy8hbcmHKO+7N" ..
	"T0xYCcat2MY6eBrhnc/NjMZzuojov2aOnSuZbsK8rlajzko7thZD6/FxA5QyRIQDKikPWvH23Z3SK+P2ype1uhrXOfaXlVS3XoYW" ..
	"4o5nadbWbum168h3W5AVTeLl3D0Fe33q3/z2W2eO1X0b2XmTjskoajGhUbaV4CYknVMAG6ZZL1GsNHwZdJzhKUPmjIiuVOf+8zFD" ..
	"H31w3rFMMnBMizHw37cWDDbA3T+5N5q+6Eieqi8r8Chgn6ffJTB/3uXP/8BSLqu+8vomaPuFd8mEW+fogV7WmFiTQuczc+6hkAjK" ..
	"z0GL+lL/UA/3fxIyq3rcB1o7s9ZWnvTiNO6OsB7A4EDfUTcJEPNumgYFu4lG+UcZOzOdCyXHiSyvxVrqFoJfkpmj9Cug6W+0dTwj" ..
	"qv+5t5W7uE8JdQMXhVg0cj0wkIY1HGCKl8cdmcw0OLwsz7b+A7RhPDGtHsy3SkpHTasRJwjpw6a1pHtbrDp66rj7AAiFYpXksi5D" ..
	"JNrNkcylEhTTqpQXznL7adC4vv/rg5hTZU2FacnvWhrkYg8TVx4an7OHmWEUPq+KWonua06fKZvqQjoptbt2DZyzUFDW12wkbqou" ..
	"120lYOCksz/GDQMxJ03oNNhP3Fm/CMY0SiQUgGt/+wwctSE7mhbmz3wozgz0cC8UPiYltmhXao3pwBW7j/9V5hmap10DFBlaM23a" ..
	"8vxJ8eLmIeU3wcVZ0CU3yMvFhnMu5IrQ7kpNInNNzb+x2toJLye3hlncBpdRfQYK6bvwSFvFlNJfda6qViOJgnO5hvqdK8IVBsfm" ..
	"q5g9D1fN3cDtV8H18RnaxU02DTxUZXCVfV48jAWk5TZfYEP58U96yb44o1bCXgvyR+5pDi/DiVXODclcz+E83johMf++LRlYudsG" ..
	"Qa765/P2q6XfZm6w5HUJufsTNKhP3mRvdaZ7e1AK4nrLduFVh0r9X4/TZD0TlfkZMMfhXYFc7gwlEMhpXhMEqrD4373LsnmzTxwp" ..
	"3x9thBzAg4pN9cHamL9jVFrHCmuYGi4n/45YoZ8oBWBsIOinJSXTNrxddxvCt1KyxXc2mSiAxrtfrvzO757iAkmkz9STEo5KQdNE" ..
	"A0A8TYNS1SMwPvvy73iCUU6cI1kjw8Mm7f4WPxJcI9Pw6IL90U6uRmGmkEmtmEvuyvRnoiMt0p+yL04DYhyQqglJZuoZ3FMg1oI2" ..
	"lpXxnG/IzWAkLg5GQ7BRRFEcaPBsD9ISVdD5CTovPj1XIBf2kSUkRpaXR3YpzbBNO6U5E0nsASz0TJZnouKoCzswhx43FBOWRoqo" ..
	"33MFhjLZ0/eM73xxcwAszUmJZgwi/ocwo8w3da0ighCV/fEIRBBAIx0k5phnV+Cuf4vhHxfRKGlA0B7a6W6u2EsszrgRGOjOhMRs" ..
	"btGH8GlC08RQdnWDfUouMNSmQzA5j9ANOawWr5kDE1/vlUUhg+15xadBUMlQrucjS00zhMnzkX1kS5yqvmMuQZUmZM6LxGW5e9rA" ..
	"5VtIt3VYuzKXPd121SQjfvlMCTh5XQyquPKQjuJG1b9lOKUpIEvUKm0oScvDy13N5tjPCe+f8UV5B6PZq8iBFw5xxD8SXIWTbLmP" ..
	"0cwNUsYkJ3tZgMAfR9Dz6s/WzgjInNtRuxqd1c6G3tl4XuK/uromXpWxBtSBtrovbf9XyS75TW9w/WsHqx01/LszUpWUmfdgjD4m" ..
	"bXfdp2qA7e6KepOzCQS93m1uRX6Q8blN2O0YNwxEPAimXFOip743phNAg1wIWBwTzj9WPh+Jr9WLzViC4hv1WFanDfPXnu9Ds9j9" ..
	"5CjJJ18ji5CGsLUC/QPNhU04iwji0zeahEKqfhQG5rslDJuSl85VRiOcSXscrzrXX5vX7yWUeaVar7YPzkKsBFB2oAaCi+WIieAe" ..
	"wgqYidH7t8ysr4bRZy2EmR7Vr6LBrQPnQYNaWmMM7rY8/Wf5wqJH4aGHjEHAcXg2tU01+HZKtiARWhI4xq4lrx0bYEACte0LSN41" ..
	"it1hyfA3iFceQl1wBCwQoDFehD3GV+5OVv9BeM8/E5VGHMLsxD8BBBBXudP5UACqR1ccYg0Ak1wmeqTaXBMugoaLFW/9hbs27Qmm" ..
	"xBp+F05WFJxM+liqDMpicS8X0XK9wIY/b29ksu68CCryQkQ3Ieq+LJj+74FdDKfVnD8LUlevwa6ZO2LFXxd6TzeQK3eUSWEYKW0d" ..
	"ciz3jC8YlcDA2/xb3mQlveXFQTszg8+AoDDwU2D/JCVxujkFtin4wPJ9IkcADLr2WJeYDvDbdAkdhYp/c15T8JMhlRqlNdC5E/Vp" ..
	"wgE3mw1LiHJTbe0WxEYjOB+kdvGjGhvNXgN9xkFniBrxYA0eLt0aZBls+t866YBT9XfKtRRpgW4FDAZQgXiMM37VazrIrEQv4aCF" ..
	"rsA22o00OhEj5MUXCjD3AsEIKn4Vyp9qY1/KPad358Jb1sglX4NL6Hk3+BHxR7Iyt0ejw2oxdNqUfMCka1w9f64IKWThe9mzL+OS" ..
	"caCTyfs+t5pIAzY/Vp//kzHyD+BS1mWBgFRZWimF/MMupf3faEXFDzv1znL7ZP8N0XFKVdRQmGDhtihLIHLiDVnKGR965Zt8yLfT" ..
	"o4+szPRVJlrb46VT7475yKwM+58tpzhwNbmlPHu2A47Csb71oD25xJqzI5FPY+YrgbmwHE3gNCiC7pSs+AmtXsXTImTlsUwXMgfj" ..
	"isqjIva5U+gjOIDUwvzzv1DXdDrxWapbP1lVK8i1xHRwTHhvWjvjwgc4jYCW+DflaRdQIQtAIewYgpcMUN7wyH+8GhOy5Tp+zt60" ..
	"9GextuOHA4ZqOQ1QNhmorE9ydPl2iWsOh8zxk/XFQVLxJaHCpWFQkUZZWPGS9zAjSPk/bJffFjKNfxJAm5f5qWTRpW0JxFLE0Hnd" ..
	"6iNHAS+ZD19ZS7Cv7S8fV/9Rw+lu+RHTg1UszKSKO85Y3KLcY8GU3motBWmkJPo2K2QStWfMXdrhzcI8P6CpBFAaWMfWvtiP/r6Q" ..
	"EfddUAqyPj6oLuBtL82k2auCkgJbX6gJiEPz7kUUFHs5SD4o9YEaJD2TQFHe4ZG3e27IAMasGu8Pq0CNGn6KhGxAo0kZ5Nt8Fm9R" ..
	"CVv6gizO81RZG0F+1JKTf3N2NgV0gMVunSf6BQ8+WPvRRejHBvW45ZdSI8bTp5Ty/ph8lIuZeTxzF92qfwDuyhRUSIm4MZRH/ULc" ..
	"AzzAcLaCHQ8M9RZXsSp892oIdcC2+gpU8XyttOroO3aqAi+BDayFxRntvsgrMPNmJ8DC+TXeGt02BTZwceNWgXiM6RX7xaNlYTM2" ..
	"Bc8EVOK87pFVDMOwyZjCQfuQumO/4HEMy9T7L9vA5pQtyvl3ze6AOFtDIeArXYq1GNJaogQgzzq74G5armDg2f8w/PGn7lUg2Bg1" ..
	"hd+mPvZ98ZbGRj+Jh6KynDeTDQybmDyc3zExRXPfbdjivL9O34CPQexqq3pq60c04m1tTlLMifGPgKqq1KyuttCufRBUDbXgAIGp" ..
	"7l4RdVkw7TWKj6ix/jibPXYgPVU81KbfV0pUxA9wStPRVQ0gMyzkZmJ6l516fBBmYn9YuK2sY/gq+bqZUWoClSvSiEPSilRM8MMF" ..
	"AjIHni9XNS+ptAF2DRXLVPii7WBlUv0Wa6jezJt5CdtAy3Lj8WrafjG0hpyTl8yb6F5rwmAEorr8wARs4oolxqId2z4i9R9/ERZG" ..
	""
local PAYLOAD_P5 =
	"QSrFxd5LvpXQr0UrEy6vIcG1s+5C60A37wO8N09cH1f23hUh7xINjjpVxpL4473r+BF1cUBQTVD2WMM5XPAdqdi4Lz9Fob4RsAT9" ..
	"HN91kaXiUNo5JacsXsslTpOdr1YMCH46IpFiynQc827phlG3MM4uDOAW+R12DahZ+2+8GDjWjAaCSEb2M21JRmmeOE+HtCXK7FEh" ..
	"uzg8KqFO3vH506QNv9QB/F9YfUR9DdK9JWKGATxBzGcTAb4Pht2/WzKQKCqPJ08Ns12beOhIa4pEO48VvGuFbXOWN83qQO3XrlLd" ..
	"GdXhhEOVwCRmVsf6oalDTfQnd+ThJ1hrwYYtZ4RXBlm3h4oPxH3wg1QMWrPkcbmUrRYjUES/DU9FBf8TeB3LcPXjKDYB7JR1as1Z" ..
	"Cm/T6NolfADCVGEhR8FDRIYQiGcafNqFEe52Q4/Alzej84FcKv01zF+auNfkrTvW8wLnNI4ojE80xCDLNgaLx581g7GIxKArrJpV" ..
	"OybNmw3eoaYF1b5gpjJfRjxMcBOFMTfKzfY9L9VJ9H74hLhMddArM6XKr45oqA/P7hkXZPFjd7mDKBUwXsUMgWPkchhthDDW/fvQ" ..
	"Ka/G1gBDrjscDlQD4ZTBxRDJYQxAvau6psI79jnb0A6nCKzEXcARC+VK9K5IYAFcOnSyDvoD2ZxvvERzHiM8aaN0Ud/AA8x5ZAxa" ..
	"NC9HY/xBtfD6t4pkqOHX7zFt66l1VIfqpcB8ZXT3+dFzBiMChWU63zmM3kGl3xyMk55JEOSsTbGGNTz5p74d/twd/odhsIPAovLa" ..
	"cWltQp+WZLBU5EbcPP6IzNAtDREHXM65ZudYk76IVd3KBjb80XZZ1eguDwgzUpTGWsbOywOJFiOAld0rBEB2O83uG6NlwZbS1Aaw" ..
	"GemqDl17WkH1bXkxE4UeYkfmpSZ77z1zz3nmmwa7q9zZzhJhMn1rsZFx5l3PQztn9BBzgVtcIKtehF+tPovCbhLaSQdAnSd8/Qu5" ..
	"16klh5eRI9vSwWs/k4Ms4Mc1/CC23L4e5MtWtmUixJYzOKkC8KfnAEcTB1FwILQ0c6Jn7nqifxyCUJDlXKoK9NsvKMxu6dJ4s2bL" ..
	"/HMooaTF3xZNdVygqyrh/IvgApA7pF0jeUr5N1eKOFXKZ8hmuPih4RCR2+DlnX0wMvXdQMETaWmqEjikNzkMohg2XhyyDJUeBh9j" ..
	"LRy/ABtMPbYgLaMPtr0w5I6/dfG4viQndm/DGBximqKKvwR9KPC0xUSjlhyANCHd6CnSuQ018nu5WpEnGZjVlnwZzbSyivKil5Td" ..
	"Jh2tWYgw/uzVgEoZY8FcFfsGSwJ6sADEfgdc6Cnk8xXr7NvCI8tN/EnKEu9NAiLtM9gsAHY9HB7lg6xD1MoCM02eqGRD23asiGJq" ..
	"AejdFaZaPxDIVCA/LoAS8SaeqbsafGLyGfsCeM0uf4goBo6Kf6Dw+owxCXwk0qqQzoXwKm1p/XD1oKQnK5R9d9bU39LQf4PHtIFJ" ..
	"kaXgLkmU637RBClZ8yq4djn8sK/N/TXa8I9XF78g69R2jsy+XqjdcXWHYis5RH4mx/AMkS2NaBvalC3AjXpErdkL2tBEU/d/AUz1" ..
	"4UIk8r69TIv66LpwACY599Ly8kBlG/FuaB+6M7+IC3zWUFbNYd9QmygxWcYX40oBBdnYz+wluWfXqtmexfiOuW9FhX8VLRyvP7XV" ..
	"YQadYmc1NQQDYKr4nuvnJ0jpWgwvUdTi0fCpH7gP2CzDy5wHV5xE4x/u0fzTa7+koovqdofhapOxzVMt4QtJa/PJLNXwVq0X4guN" ..
	"CfLGmMDJYMxMSGd2ellClGZYwj3djNYh23sIC+5EOmEopWl9gvTrXgYhXTOz7p+zwfmcL3K3dvrwBn6FZm8WoaBXXkZ7pmF2NeN+" ..
	"uykucETJ9b+UMYsk5aol6+NQQGJnX0ouOuhA+cRhAFDyKXyxz1emATjcrOy7DYRXKl29Ko4nqyGn/AhJXSTSlREBhqFDc53a2GHq" ..
	"pTY0r0tbGI/OPiNEXCs2JwcbrH6YSBJ+MJr8lJKzMGyGgw7yLugu4VrbBm5iYSphGUGAwNddDhjVbyLnesuBNujFEcnYOI2dKjWC" ..
	"JxP829dgLcjCpJTtIO8TksRKBYD7M9EAHnJC/OcvdQl8t7ZNwy//X0ZP6bNKozMRocVFCb5Mw/ORYnEbjEs3CIbl+b9i7wbTIr8T" ..
	"tnVQrYEoKkL1PJVhvOgfdnkzOPybJce88jppHPs72kfJYudNxrpBLgc9sWjTwNKE5vwtjPLN++v6qKGkzMgCmN6NUpXWrrT87fXc" ..
	"EQ9l9iE43I+X4PGgTx41f0XEdMQ/zkZg20a58SKkQS7QMsHgbVH4gaXm7bmFWnVJJyk4th5+tRGeP/xDxvbxXgg5sulgmU3o0DYc" ..
	"piP3IamqEnEeoove+aO9KYHI6fbCCXzf1tPL4oTnF1aRekx8/wVn5GAZwJO9wG4Q2/de3Fcuv00VIMx9ZbKjRMCM6cK5VVeiYOeS" ..
	"AkjUre7hDs7mRAfnKmGv9188SQX9dGRicdLjy1FMLf3Gkw9+fzn7Ue+okmzeCOLDvx9yPdLyOlycftkNLuLStb53O8nha5xsBREM" ..
	"K5yMYW3GB7JWh/BuGaAuZtwNKQPO71W7Mm4L7BBvpzXceBlEM1q+R4XJmeUJLWg+gt/6S1G3KK27txZaXMRPaAUIblE9Mecw3La9" ..
	"LJA+RMFLpN7aHZeA7IsOCjHMSvxNrz1BKKcmbB2gtK9Sw5enXNlFejIWeT9SA6MTssKs9xibNCVhCz2zum2J5ML61UzR8gYiMEw2" ..
	"5c1QXkuOdkAnKmOwLQQXndDwyS+5/b8ZLnQo0s7sJ9ZW2nv53ygLw7mI4Gl4qjNYASNbskkffRntyEAWujZcXD9ZAqBlz3uwpvif" ..
	"O1eRYDmiSD0TnKlxcH9aDmqP6UUW56cGVTACENrIIf126D9L3KJmJHB0ymgYdXilbwsfFqX+XaS2stcCFzsC8IPWmCF1Z9Yn9DAg" ..
	"y9knQ3ctWQXehprXfo9kwyE0okgAqa3RjSE8QElLjtubafggvltEYd9qdneGPmLumYU1720CY1fhdQAiKAmzowHvrP6PGehKBr7K" ..
	"9F6bQ/v5Mdqmc03dH1bIqdtrX6iy//3xXdX9l10xbvAY68YHBvOO4IU27+KBZVJs0wWnBOoSrOh1GDbQrJAfELeNodAF7raRWdzq" ..
	"vllWLY8QdzoWVknMZlcF9KoT+VaWbaP87VNWbGFSjVIjntCn+LAjrDikg9aoBoPjWMS45xpFqWhIfCz38+Yr0Ang8giHkNoTXmFI" ..
	"j2GfbZFgTjjqT6o3QChH+u0ML1AyCS56yS5cpGYs+2hDirDuorOujS1U9ZT4aN+ix84fe9vb+e5oNPwOEz/GzwllaLXDmJXM3A9C" ..
	"Y9bopuaKL/7W4fhk6cFKmWbNyvXU1PJzqu+PQpBxDILjgee2uoTIVhBEBqTFFJc/KNJEJC13Gr7/SD8xUn+WKgmdHd6g21Xq17sv" ..
	"8JJZO866ummn6i9aQ9RCHELhMRJ9tXFsXLT9QHeDFlzldMTAIOghaeHBaqgM+0+8fGCTBZtnHx/tpjCz/eWR1qmrRqJ2xKXM6VWc" ..
	"bMmyvo9/uIOqttJhukwTh/PCQVrJsAAY9gAmBlHqJtMr4RK8bF4LS9927C2uHbgjE/iDXmppnSs31SEz+3Cm47hqoIYJnnXOVMHv" ..
	"RadUCDbBJuXutqfU+LtQLGuFPChtM37wj80pqjXI+4wFr3KhquTPuUJFynxFuaRF+M4abJqOm/W9C4z1cBwMqLDEGN3wheYWKFyy" ..
	"71Fs1WipuC9x0wM1TupBpHZ6cbBoiRUHEqxULbXDzBsK7QOQXvlKctmixXQB30opgxrkQpV9oLKeC03Mk1w2Yu1FrMw13hdRsiPn" ..
	"/pM5Ryuy/X4viihhvju1o2LqtqLksJX1uMBX9j/2qY5a0WKih2SZ8LgCmFtIIqkinSZHwT2VIIArFtFN7jBKKjkn7RFpECrwjXj4" ..
	"9sGSjgBQH97mMJWYe7o23f6Fus3zjVmtyStxYWWFl+ae3OzbP8juK9KiHDdwplW0IqwTNG09KugDL0dukc4NuKQtMildM+BK85CO" ..
	"xtdc0Pqbqy/lJS5AhZgs+i+WCtIa9EsZ4FxPWR579RtPdha+1NHkq0bWyEXKyNU2e9A2lpFW5/IviYJUvNSfNhGXrfOddHwNQWhG" ..
	"+8mbUWWxeal1io5ZRZD/j8zFd3MGnMGENAHTukxN6foVph6l3e/ChEg35UFYQas4KCGLi5VSfQuoOPusq2C+S9g7QjHZK7WYJFB3" ..
	"xIefTHoxF5mofLFVbd8M+gyGUPnxvjqISD0ojQU2/5I47LYJ6sf9WQss11jAyZF0ZJHFeEFOF+ReIeqeJtUXGgak9x2HTZWnJJzW" ..
	"oFs+xjb4DHHDHnjuOnCoCpT65nyFY0WSNd+/txJES23V8COFgNTdFtBNzF21qFNXCzIjPi4vSqv+0nArhv3L2GVlDCosca0Szd/R" ..
	"0QxSWeigmxMaaOsX7Hr4e2YAWCVZi1pIbmC7zMZS4PYTN4Jzh/LbSRwkmUgii2dP+TlzyRQGhN09RRCrTgfiiE5g9klnQu857Ixl" ..
	"bqfQ9hCgAStEM98xu68LiTRmD1/xX0CxtGhgSvQQEOwPdaGeH2i6+XZcSL0WTic4xo0rI8+2H48PAzy+haDjYFMwj6JQ5tb2q8ax" ..
	"bncHU9TKZNQ4lr5Tkf8gHJoIL4GDZP56lcdU8PDq6kKkXxPC3kysCYJf1U6T2q07EGAjPY6N6WVPaRhpYK1gTYg8Ct2a2R+mCtJa" ..
	"106Zxq5GFvqENus/lT4dto7sfSGZgfIb4nYrzHXehhuN+K/U4f0Jbs7McPjhSFd2PyrTq8i+DdRpJhLf6q+q+nWK3p/jlfKGs6YB" ..
	"DQffY5uW1EfkvvXQGT3qpYPNa2V3kQQsMhV8896ThclTYA3KwZogNz5X1RW1bt0nU6E62LkKtifZFrzp43F6nUg6KlnQqruJ5W2r" ..
	"K73QZTkktFyX/LaCbqe9HKz4b8s1nHhoEEU62H9hGKASsbPDZMr4IjQI19hJV6FxPHi8uiSKLElYtawW1Lx5+p+uFO/jRSg/vAQf" ..
	"7qXA+1XXkN9Ud2bUzSOeWE41aFHJfSVlPBqrvCIFV6NqvNaFcc23gKwgVmn5NTOW4wEhPAfaSlVE2umyTq9VXLXcUr0Toe1JtUIq" ..
	"JPH+ImXzvHi0AZwHNw9VAbQJEr9V6AmfGYhpUy7kBk7lpUEfmyUKlzJlga9l6HrOXLMqtSsPC66qkyiH0Xdwo3LrSqzB4uAjj+mH" ..
	"mpVe7p5b6sdcm5daWqnBg2OTCofPRBHaDjTrftZggXoTOxqUiLjRQvw0QZBJA49gPLh+TSS09+zkkv0hqvnQRgIsKU80MDsXvh7X" ..
	"sEO0NBnh5Or0nk222JzVPNxtwhjNATE5B0vqw0en+nkOHppWScbAybhfL8xqPGCTGyHm8znLYNUtIRF3IJW9YInaTeMQJVkik7bd" ..
	"KBcbjHRWDeGYOxeXBVCPpZAqWcGqFAu1eSk7LmXbikb0FkSFBrnrKDTRQZxsqJ6+nhbwvPrxB78UNouwT0EQHtrZl8csVfBzWrZ4" ..
	"GOlFUoCaeplBJLHlrJkP/sNcaR9V793rBHws3UbNQi1sea5hWFyJrRn/+7cad8yJIGA96LasPB8gN08TwEV5qgisV30TZDwToK5B" ..
	"SJm4Qt5wI6PXk8hlRb+sy8sJUQgyQN6htzK6AMus8qAgCHArmt3NOf1t5NA18vFXuroWdaQ+5Z2/zQm2IHuBKLs2S4y31OdU8sQR" ..
	"qaIYuWR9h24V5Q3ceBU9IHIcelWZCktEr7ymUA4suds9I1VLFpGgNgAoFFft4uVsdIwWWGLimW5Zn8Zk3M+yJev/OaCYZOo/iDRy" ..
	"0L9FZYNrbyOOM2ZkGzKeIi6bychcklsi+iMBObYbgiQpDU+suugqVoL/R62ZgeT+IAH9t0NlWuIXmjYIOmyoeaHqSd1IWgMKY9nA" ..
	""
local PAYLOAD_P6 =
	"Tanho+kQnzvgDQplznqP5+/onzYnPzSd/7PYPKMTuHqwHLQ4w6e8xsHGk1/xPI85LlDNYNrKzAHyy2ji/FXuttUz5bX1btD0Fifh" ..
	"Qq+lyIuYTUMnh3AgLY0iYDrCR5m/lurXZXmd9vQFRUCUs+aVMmLPF2Xy26L4FYXPaqSI72sEvJ501EjipiLrUWgXTbFhPA1j5/V9" ..
	"5n72QfsD8cl+5pGyfGZUFm3dgMnTI8xQ1Q3Zv3HySWCiPjkdVXGdrtBW637pYOXagEV2OCnFE0ubkB9EKUUx5oiY5qYQnUfinWW4" ..
	"3p8sEMahh2dLv4gSDXgpZayKZ4xL0pPNxiO1tZQtQsJUWEdC8Ckt2m0+5AB0wOXXYoNWa0OdVUZYxXZFdKnqGwZXNB/3Pupedcoq" ..
	"adNLFqzZk36nhLZeUC0oj8GZdqd0yNjJ7rmH8vMUFokl4YIGHOV9TlrTUsfdq5v61UsLaHT2Se8DjP1ebrI/zA8Q7EQsTxiWg4RF" ..
	"xLb5zi9HMbcVBA69Y+KolxRCuWeBursj7YdoXXowgG5Uv4tebWukLpATyEkckTMHgmQaykDR+40HkDdHIBQqI/aXGdGmUkGTUoFI" ..
	"cCSTOYosjZBN+r12/5Q8un1wf6ovXFKkjIZPncckDFEppcicBhJVr6I5JUD66bZG4gRP6YHo1Gjovn5G9rdg8IT4m6PUvsU987aW" ..
	"jQZJaRdMOWmkU0hohjXAN5AtftRayhbc/LWjjaJu9xmYH5UMkYITAzV71LSB0QRYED/BB3nP1hqNVFKV+4xzOKGNCaFYh/34uVj5" ..
	"0N7K+5fC20566VmCtsecuT3Y8N3+DFPydgblsiz4+qHK2EiTw4IInS71zmgmqsQBtn7THNy2RaMf1kVr9M0R9FIDGE9zOiYVyrGx" ..
	"Pl6IL52xGSxXknm89ueQGfrkmsuyw8rX4QqzZOXjEKaRaYTfT51H6JnDc0G18IJ7Uys4VqeXmsLTgxYeogqEEMpPNzRrkQywb5Ql" ..
	"6kjguH01hTVsXBh4mH/O2Pt00HwvE6i3y6VpKsPOgYHqFBVTnos2vlbTphxhkW9InsVx1hWqBj1NjYWdS4Dtf5zNTusFbjjnps+R" ..
	"aOhXKRjSX6C7aE8gMX6/USAwoWpMEDz0XhkpCdTlktg9kBE7Asb9JdCoS2nOOROrSQoh+bJbsaav3yop1lUz9PC4znawiv4EhpfV" ..
	"sT2uimm1/zb3OpW+RfAEb7/crrNeomIx7MR2PP+HCFk6iMK/ydFGP/Mmm5Zy3PKg44EdK8LTRcifwQf6DuP70/Z+PlfOmcNe5EZj" ..
	"JzHNVJYFgHf5zhQPPlZeQ25cXUf3KOcjO+e+iL1iuQiUXF/7o3bruincPwJW6gJjx7EVgG7uxNeU6LrlHUfsGmywWoBtGuH4FlYR" ..
	"XO0NsqJDkyCTGmdZmQhXz9LkdyuUr3PkU2sCC3B3gVSSxlpX3Ts/IZLHYVHEmGQBdT7opf3b27DYs5j2vnMleqFHbXoKNYptPUhH" ..
	"etnfAsq+0zL5A+NB7ATBz7yeb6qkH/uHnv5lbF2iuTbzHW837v9FPsz3rGexAVeYPRztP3YzUBkY0zd49KXfTds10Slex8L4QAzz" ..
	"aWELAzUS79AiQyoTdglWjIwHlU8wukfukKUc+ddQOtIg+5RunYzs4xooQpmcpIIip1M6LXCGSLeMLE2xkcjc9ZVPmQHDl1/WqRO/" ..
	"QoWNkd8aVhUx447n0zoFaI3MOEtNjR0mmWqvJ3slFvfANIxPLYBFZzKNFrOlw/ZbLwLjaRdHDNmHW5g37VOvhA3G1MdzTHdAL7QY" ..
	"3RoxyY+jzyuFSI0JvNcSf57XA+myYv/NM2XGsvG0m4q47bN5CDVXH1pHIx1ZcjySATfCSElq5atDWef/gPmvdb1EzYaZ31oEGEwD" ..
	"6lVgX7sKmzAhiGiA1iBX1t0w1CTGSqJdwskkqeBx4YB0wTR528jeVn6KlUR1ZViLPA6aMB4R3iV9jGtlaqQAlVuj8NbKgegPpnMM" ..
	"kHJhlm1qYkW7N24hxsYNMOMS8QWe9gGLj180IB/4dJJXTLuy1OrTJug2Ko2k5gN5Tr0KxcCB1czRcNy+z2vcqZsUpXXENxGp3SEf" ..
	"eeneUw3kopYw8B1MctRN4+6VPHvASA+liW/4prT899z76bWNx4eHvzHykyCjKcjIOhf97qAG/XRrNLoUL+7YdRFDcxLQfZK8EjZ+" ..
	"ZbfE7nWa7wJW4mqZkLhwEvpwN5v6AmSLUYumUGDSMpBFbTTwMaFNJGUtvVd52OwF6J0b/JJy7FI+v3N4RNAVG2PP4zCXXFMancP5" ..
	"cCq9tVlZ8TBsxWvUJlt9KEvIwOawEh3oNXv80e4tc+VY2y1elO3u7IwkMzn5xeM2NP6lYnj2b6iwCd0trrY+wK16GyQjuEItjUJr" ..
	"KqA1a2M1OTGLZzBATzuPOudbS2Yqd7hTyBy3xQnx84mat+tGbWztvCnvBOfNsiwiPKl1Pl3v9CavLhPxRM6lpbNVsWJQ3aYNJ/6Q" ..
	"KvuxKyv47zEvmX7SiLfxMBGy8jqFSXQku0yiEAjuHh2mB+8Lt1IuCOrgPi6jsNTMYPxk4WTij/dPy3Zq3eYznv0QtD2yxvXeBIHt" ..
	"VoKa9WwhKq55REg+2cnEuj15sabwsMeJ6kCW1vGK7g2hHFChHjPct3n0RDnEP2mJrNqLGL2BSAl7Kw7rRgmlXhQMY6AVmAg4a6qQ" ..
	"rLYRSjJmnF3JZy4+yNiJS2QUIGbxq21MZr4PBkSf3ozy0NDN0cSp2mVMa3CzVC4iZrC6qLkMTNHzs9/JrXTTL0nH5oBk1h8vQ7kK" ..
	"ZhcsZZBddUtD9YpbwSwAdAc6RyqgF6mdbTK8casjxf21SFJPxf0ulAli1oTUi86j1WJnblJ6NAI+2sWHR/mp7Jc9Oq44gp4a1/68" ..
	"+KSUqsQxQJgOvfYrw+RQRYkRN4OJQ7J37JMjR/35O4Y5wxUZeiTwICI2a+RQB39r+GOBOP50ovcv1S4FsumhgaSeC7XfTB3EQRvm" ..
	"TQycVzb8gjGxckGtrnnyS2Dj8KZqOo9vNQIy6Kdkku550LTCe6aELL6rVgsHLVOJSc6MwDHURAz9Oc8klYYPsj369ws3ePAfokek" ..
	"D95eryL+2liQyNmNkfr6n75P8vKdKtLkHRhSkCujSawK8EjQeD+mzRDIEcuoVWRRNJGmO51HA26vxjBKxNhrXVKnnza7WxhCqliT" ..
	"YoilxGBuPi9P7fNDbN/43nj2ckdSHelQv3FHG6io+kuVdxZwmMfNmyVoumWEF6sjlOhSNTPNK/eEPLb7tAqB/pFb0nPTz6oFwH+d" ..
	"0ES6dGvkcIeXnnwqXWbm8en6Mi6LMmYlW7mrpC0uzXFegr1uaznTGMHKiOdfeAFEJvXGBm1Kox6Z/DrCgtZDUttIDmWSR7xH28np" ..
	"X5xZ+XoHPX4S3KDQajEXxEo6tLZT1y2yLzO2LUFPtjkZJfSJRDcydBNfp2YL5tqIHo86RDoJQGQ4qj0PQGO/5qDSNVMnCgOYI1MI" ..
	"LSFssRYapxeZf1Azvd7DvAITI9ZujLWKctrAjuXyaYG83uzn/iPPGNFcYS716mNqmnGZ/o7IGLn2YbWoRSMztJW2uIPNQ/pEQv1p" ..
	"DwkBX/3t+I7HMj8EOiVk5Q5MKEezdxJjCpBM1d/RBMS/k48U46u9vsplZpxkbec5USupuJ+2hwclli4N5aAv9oexnzZ24zKpFf/B" ..
	"q1uFEalOYN/8TkBiPyKOlLzMfK7w6iaoMvntbnAwzerpcl5trFtFhXImnPWJHcqSsFLNHIXQxtn3j3kH6DPh+UYJS9t5kq3c+m/C" ..
	"M4xpK6Kw9deAgBSYE8SdwUoUts4CLnQgRD0rIAbZYSHm8aHUAObYYbMyivZ/WOji+LAYWBbx1q+bDGSUC4X2yZkpuzs5B1HvKsxA" ..
	"wIoCexFxAqhMGaDKvEnec2v1hRgb4NrIcm0fLIoLF+z6H/z1IlGLL6fGu/Lr0sImUOFuNfAApAw3KXm7zHyxfjDeCn+lWRk8EID2" ..
	"rQ8KF/pxeOPh2LfQMTSvQQ94f5SGzFeRx7J6X1t92MswSVUypHdSt+T5HvhhriNQQC0bk8Di+9ZiPmZ/FOeo7RI5+TVPk/veVYaz" ..
	"dw/hFabJ5Na3xCW7lTV2XJUMZgm5DSpXlJIQjdCspLnxd31BND9e3hzeLsmWK83nBP4cZjrZSWgk6JPMoSf9qArdQbkWuwk89oIP" ..
	"qbC9A6+fsz1oTbxsqBewhP08HuPWueqF2ZsEgzYzvY78bkNBl2oXBd9bth85SmUIV0rfjMF16jiDNlPtn6EcgyexVGBbUrl0mtXl" ..
	"TYgAgMioEb/37/5fY1ewgBfgv97HSBCLs7nuiYVg21G9gczSyx+aDSumnN0fhDNVOV8MvDexnF5Wn04I0c9eJZOcjxiHCun+MLKW" ..
	"vmHgwmX7GqAyhRC1Cc37wuaKNIvGX5nZuc3MddZwlRCleEDVEgEvY7vnKRq3dQid4OjkardGYada1vVVZTon/ioLz+XyTWThjoT3" ..
	"32gOuiNKkG7ElCX/2zo3NWnWfhE1q9w2LrxJccAinJbNR5xKioFmU46CLqK7fkLiokWSA339G1QveTicedBE4ft86xewGW7q8OQi" ..
	"H4ogcEcESoVptQ+9srjMeHS4qS5mTwTW5zD+iMVmRlpn88A7SKz2Qii2tgrIwuzW3i9z8453Q3GolCnxfIfuFgBDFBCTUJy/UHJq" ..
	"VX0FucIvYZ+t8S82MgvNbzUujRajUpHTvnfnRq+chh2Yx/4z642Azbeaq6QyIM0EgkPFo5rS5mvegzowgwtw9nymdN6amlKB4VvN" ..
	"rEe1/7arJc2FD5mieqxh+Ve0dWvHEe5IP+pPlW3b9Hob808c/Y8N3Qce/1MskPfrAf3N2g/r6Nam0sPuLq9aQEx10n1Ja79rP95t" ..
	"b56jK9j8lmRzlD1myp1PgH3ceKKRCMu8KrVi8/98/lAjy05X7sv1WVB+lUztwM0xqNWrlhv9B+NdEdzoYAZPrbepIrSO+U2y/A96" ..
	"y3YcWVyGA6NLVEf64FlZX+/VFLiOI9LImS2giGCB4H+0SWLeDiApJDjL07Dh/L4zbx5AbhKCGfOvIfOnfpJXQRs5PXc/Gzk48M2M" ..
	"KH20NWu6dtlGcNsX9xcy6VA9IkgJ4D6qlXIY8ma+U2ELPvcoddQkOvjwWeZ4LIm0Bfz/uugbdyG5TfZZenU37MYCOfzLr1VecISX" ..
	"B3rOxLlpy0PjxgejWx4I7SINZtbB3Mp5u4IY2cQSTzN22rxfEm/Obr3j+xiNZVbWWy8o/YIrmJM//wc8LOeU76d4G5S4lUgxiYtG" ..
	"JsS3CWKMR3uPRpJflQDcTd6GCTAoT/uyw3AvwVOZQYhdMkWiZIdNZMkoMet7gLP+v5h7b3Cqk4f9hhL+rvQ8kyAvvjFczk54sEy8" ..
	"JypTXLoE+JGPF2U57VHeP4gjKWctawyxzN4lMDmHGE1TeM/YSxrNYvndYB1Uy7ouQHj3AicsA/ABytn9y6JrK3uC3hQwMeucKusy" ..
	"Ff7QGp7bQuZVTj/S3T//r7u4N0DzRT1q64xB5mBd7M8dl/4i0E4i6wlQcxe1lNpvgB2lxK5NhMVRmeTFWmAShFeyI56piWaBAHJ1" ..
	"id1cPfUAPsNZQyQC6+HGJgo3q+/j6oPaORnKxQ+0dP0LIngTJ7myRBCB3BHZqvokF9qRtULz0CSvOik/7sR11vBhOhtk4p6Vbq2N" ..
	"CkAU+rAii4QImQrE2jsGoewWHkg9ypSsWte/n6WWhVIQDXtVAqPqMygytb65swAipodw1Ntx0DDp8mo5cM4erjg85IjWuY/a6kP5" ..
	"AwmoyI2VLGw+CS6RhMJg9CWxE9kqpfavDBEr8rUaeNo7EbRqOcac/osrECcR0B7PE3dPwtS+elKwnrroyldkQMW5i5atZVtY4MXp" ..
	"rqKoeEbt3w+xWrQhA7O4A3+L0AiL8K6CMrpWDmueIh7pH6sI8A3EFZTSgtsENwCBdX56vgAyHnwWwKI0O2ScVOm9cccVSV5N1ChC" ..
	""
local PAYLOAD_P7 =
	"wkF63Ptgm5U8juZB1PA92o0eGj7ByM87zAVvnQULSrcXzG/TVNiqvl1u5gPMtTHMAyjLX+0Ht0L1nH9lL5H5oXK7MVgGxXqbv5QE" ..
	"lm2iGJ9PCJS1AmKC54hx90QlWkMMazzJun6QVJF5FGYtXk+MDHrXt2P1N6ZOQ5Tn9yd6kMUqckr13DRvpCE0EEvEH2DLVb/v5Xnd" ..
	"FaWuFQYyda4uYZmTFf1sl5fd1af5gXmYouPTQUwgsKoO23FrP8WAm0thvsF3xye7YGcqF473wooTCntU1rEAFBav2FeFuYmDDyvj" ..
	"QvOkZwu/vNnhTvwICwO5UV2ZCX4J9Ju+M9mAbkSZSdAFkTo7u1LqvFTXPKWhstkZlWA5p+KgZU7FnTesVSl1GVMzp7N9YofKjuXH" ..
	"z4cldUE8tMRAmDy5D6nSzE8QdXkVrsQscpgmStGNJrVW2OKEBS0tWNcUZ61AC+s/OZ8/0Wiy6f8gURww4/Ngqm5uVtRA5Xzwrokc" ..
	"9pcDHIYLjpayKMgw7FSFeZ+2pGheQ/Viw86TPpSbxuWXTEmYR+H/rFgRBKVJGd4p5sndT9xmXhor6gAYVgs1L9MvjRpvEn4xA0f8" ..
	"aDh1rOfAH1dMND2jIB83Zx5MIlAhrdumh0q5f7t4mTjkLHDtygchjw7mlP0kBRwpK7bwoAa9rqI258HBLEMKoUd7cKB2D5cdKrnl" ..
	"ucxS6hZQBA+xKyuvY9FfZaXt03raSPW2ojSMYQOdt/dN0+2Qlz95qTMUMB7l9STGXYZhcQeDc7KCmp2dShUqOIbFW++Hz38auaPL" ..
	"A8BODWbL7t+udlegRsQmDBal9inYCsYOgZRlO+5OXMWexlZixfLg1EMZ5cE2y0+6c9IKcl4YTtgXfsvDT/LQco9gWEU3P99otHDb" ..
	"y17onVvEod0qdgLq8d7Td62dFpd4nGkAqMRuzOcfB5pgcWeV8A56IdzA+PYG4lB23FAZmeL1g3OpYO55ks4tTQhTikLjOSjWprti" ..
	"0ci+aPkpvupWu+/UkQpo7e0SZ671bnFAZyfKuFBNrLUvz8vquhELWnaZH94vJ7wA4JB+MsmwaFVgJOAGnoox94JwU+cFRsezeoQ8" ..
	"JqrMpAjddvnODkwKWkL09UCiMH/PymqbUuzNJwjcfuQHcwu1XCetxg1ImXLf77L6G8sqJ4Aou+YP7noI9Te5hnrm2SFQ5QPTF6cf" ..
	"d3aN0j2mlIgkg7FPjtMllKrnYFYjQxRB/KJPWBk1izlXZ4uTB6XTpyVv5IU84mn6OvT8qK2NdgDzUG/6jU/wGJ++dD0puRl2lg0j" ..
	"b1P+TgCJ3yD+5Qix6Q5As0XBRKbvOZr6bFAU4ZdcZ8h1XGk0qTAEiTShONXxuktM4W/2AJlKyByjyB9nBFsFssqGQQcNpzpEOO88" ..
	"z/+7I/8Wi4yix5LnhyTtd9bCjWrOI8X2H/eI4j32oAa3nTujJO+kXJW4el8qwZiribqDul8TFo3AF3Hcazn2UjLnyEeWoLpP3p3y" ..
	"OWFGFzVdHtb4raD4XRn/Eu+IOmnEQ+B53qa66POpPT0lpVaaBtuxPfUivYsBcxdDNNlNbL+8BVnGaVG7h6fjd3BTu8zQathElY1B" ..
	"EGke5epB/pnD3j4UGGDEvKLelFwHTFb4j0HsJ2k0zIADYEsZYVWoL5ykSnNuWoWhws+3FAoJbsrctYpCX2qSRzoTT/1GASxNIq6/" ..
	"D4hk55mAxglvf4+qZGQS2vicwktyw0rxD9mZKeGQ+336h1CY/EV6vbC0vK/G6Dqy07lM6EkfmyfmNs8Bjoi17+thzDwwp3CeZ/MK" ..
	"KjUBm1IiDSvlIIs1TiUqUXNXSIQmj7fOYCj74zq2NWUvFrckuiEDSBEuDVImJO5LvDJCl5uFRBRJEj4UoI6DYiAWsl6Y1Dv60bvj" ..
	"U+4F0qmbp5uUkNT3LdwCmJ15r6odEIECWY7Tkf3RPKDODJgK/Qr0fveEHMgSZ/X0Gj3Gki2Y8DLwGu/N+i45iE2gFfhnbQQtEfDu" ..
	"UDNgs+FYseDN3tjhTDqWjT/by3wWFj+z2VEez4+yfLMmUzUIzTKeRuseEIIjCHfJuWa/NpCBS+tE2VQPu2tM1L2yK9oMaGQdmafH" ..
	"pnRmHPGmsVWO5u/yICjRXbBt1LZvIIcg5FuruufMlRP0HfSRCG/d+EqpvPL6eLJBXURK8C3Np3sE9ZzBQOgqHSmYIuwVtet++B99" ..
	"rtzQymSmPR0AwWZjKAHtHEDl8mfeMXk+7m/aESZxdiUFeWan9YJx2KyY++3TJokuhvpsQph4yhiHh0RSAyiNEhbjY9Hqz2XB4+2d" ..
	"uMvhDNxQXUJReMIZEu3PhuraCF/pw8KZ/nGCyiKMfQ4kiLNS+z6Rh6wZpGPc9Fn8rmEsL+Tk+GfEH8ZP4rRNORhGf8QXALlhg9bm" ..
	"eQKEF9CokISG8lzN/oiJfJFe/SzWw+LDEWot8kTIzjNLZz7jcz9WaD9NIQg2Z6cdH0WKKfUL+gSRjTVe53RBhN3jdtVK0corcKF8" ..
	"1WLTzxwuzLq09dJ67ya7KBheKHZG9+wNw02ZqPl6h3H6bm8kej97mgMm1Rws4tMcWAspFX2EIBGEWU4bRev/C+Ps1QJaKCVLSuIJ" ..
	"7471reC4E7ER1791857Av/IgFccfjW9lEdrS7f02SxbIMS23KbadJRTk6z1eZuXZyZ2H4nVpertXLSFN0aC2cg7CX+gkelfxPmJA" ..
	"EFpv5UY+QXGS9PmxjyG3gjTMRsfYb2A0QIS9ItkO+e1yUKGvRWeNOw+sBtFwtnI5O8utyCb7zUJJCzGQRmbNMksPZDNsPqCT0bxP" ..
	"JZjy4xiJD9RUIiSWU7/lR1nuUtOo0Dz7EKprIxZWYkS55Es0Plk8aMvSgk/0X45ftgpJbrEei310rmqtsfc5DMBL2y65bJHQrh6O" ..
	"xs1U4eoOGFz7kLhAGGtjeLV1q7wPEOo3pFDfYpAmjTZaHGznLTpI/kseNommDza+SgNb1LGvVVvNuqJtuFf4bTPPVrRdaNdH1drz" ..
	"P6JNBg5nniZubuhxy/AU7SPCfu1iUYQY+UjLJCDUBA1J8c1j1XCWf0EWUal1oucxGrM55kFuyuGfUFgmzOcITHjvAldCbKo/ZmlB" ..
	"HFuchrVIqqExXLA1qmdhrxSnMgJ6GH/XAUupwQ2Vn4z037dxuHdL1scOt1ggYVS44tDvyu5m15YPvBMo88k7rhqlFeva8ynW7t6y" ..
	"UTyN+OgAAEd4ojCtJvDUHNACODgtUGGciWNr9074R3FrmUUIHkiUWQq5FGy52mKtLCwjNOnY6N1MREgvLH7JNvWVQick136kEDqI" ..
	"2P61MMMbvBHszmSeAaa0h5ANZKmyyc6WjwBFsb71hpVbiKYIo5jiuK1bBUYS2zcgcCOOzcbt7vg0gTBhS/IdnPbtqZxnBrvw3/QO" ..
	"2AHZV1lKJEzdMjsg3lm7csKye6wKSZ+xkiAgebn+oIwWo9qsW9aJXrX8zYvd+jR5WY7Fo6dHffq11Ta8h5tvAjuK93LTpuCno6in" ..
	"OpkWRoW9E3tpApfaRpcdCGld5oCgboi6v7PwnLCBo0nPc5z0rNBL9+4rXA5zWMjftrZXFDAdTx1vYynN2IzB5BSo1gmEHj5Z3ZQG" ..
	"zUqNYhid0f3NoVndF3kdR8Mc9E6asLHF20lAgRQPPAp+kEbezat4G27zxvbM873gJjISVBTf+QubzdMj6I5ry0SknhzpqXKkJDwM" ..
	"KVZFBou5s/Gdz6BsA84+DzRuktSicwAci8cGQgpQtg/RoaVUxbooZ2JAp35eJyE2Wx57br7J1qJfxZSKnnd4MYbc7hkjEk9vECl8" ..
	"m/xANEB2HK146TDaQOheTeyy6lcBkxxUrr9fTG8GjDzDjA2WmMbNciYwfoToc+2ntSo9ja/69ZAwdV9/irT6ew9upSKzzCVA8hCa" ..
	"ZHSFqqQOnLSPi2NYuaAhoT3bvJdjird53UQjf6Oc8relWIGZUTjzud7BXHMz6ERGfhgiCRPen3v+WkeH3LjTObD499leDI0I4/P+" ..
	"pak8VElWVxfwFA4rj8NLZe3jwAyERzgPy1qLKQFLn2r1wY/quI5SoggH+VDcTLIZ6KWtWWY/8iP6kTPDwuLxzgu/pb1LfX9hQtEV" ..
	"edjwR+GZnuOuk6U1eFAVsDtqRHuspuy5lXlOQ8HC6FladXp1PIhPrM35VVEOjn3cr/BKqJsj3Foce7EJCWd6dqgy/bRaKhef7R1a" ..
	"JRlZH44u9+i72e7NxwKSxckG6wTu2bBKviQ7vgx1I7m0URzxcL7RDEyXkkBteeTbr8e1J5pHgaBr3I9fRdVHpCQokt7Dv2Jy2gKR" ..
	"ThiNqPB5NDS63xon6Ay4YPIBexTzdlT0jWgc47vK8pOabp5TtDT1DRuE9zJiOSUfyEa/MIwJs1XYl3effFkacdb4IaM9eaXVz3G/" ..
	"z0JqJBy6oCjHgV+1ySagZkIGz2ia1f1Ep50cSBAlHAjhYMm4wOwEDFX4MFBJ+ZQOUOx9ApYJZoLnOqxPjJXCk+38cc+FWwVwL7jn" ..
	"aU8WXPbq7FKCPfDBUBQIJsCszPNPSlG1/lE4lrqfiuFb0PCvA03ECNSH93DAUlG9beCtnieCroyZrx3GsnVvLNb2RBRcTV2tc3DG" ..
	"0smqFwW8jQO4lNoQFnwaLj7jZIseWSiPNTA/YtTw1YaiLqrCH1HJKj7I5Yd0+yVZWZXnSBKGORWJ9dXXcrhuZpY2/7OLzlYjxfBm" ..
	"4V8HedST3YbRtySNCpBf3pgV9Xrb+XRb8YDi9ew2jShrsHvzf3qCf9lWH9T0oYu7wfzT8iMUKfUvIYR4ObCHGmgmR7eeCILDIVLt" ..
	"uZwOlbqFcOD+9KZApuwJLfcXuuvFP4w/yZilx0uUJ3m0q9C17Knl28eZnFikCER1P/0jDPYD6NXdtXadMzVPMPFomX6j1vpFWXKp" ..
	"Yl3k733q+UrZnfWZWp4lUUAI5dnAtJAcJ2kMBS68wjtQWSUN8WI6ZcQMo9WXCBdu3sYIJFRkssk5Uvk6TbH0tt/3YkYNbJ3kUQLi" ..
	"robP4QXuRQqUGTeOigrWUV7YGlCWM2uxixMvAcsVwUVjDEgxKDYa2MVQr8U0Lyp5T2UhZveIsV6SDHbdH7KgNroyScvknwf6PJ51" ..
	"XO01Ms/pTb71R+SUm7A3sCrrURpOVYy/DvULOLgSyBod2ZJdXo042HUYJJvgPjVCKH/MO9wE/ijJqQIcMdhTghWnM/osHAJn8JN2" ..
	"iZfHwjXEAxC1qpqYnivXmSwtEE3A6yRZ1CkDLn8B2xlWpqBSibCbJV556Kc7tmyn30Tpn3usfwj6au550sCxvKPcnqPyrqEA7vh8" ..
	"6VVPgk0pEDwEYcXsyTaumWSL9FMu9ttx87a+qcINnZM0kmOOGy33ler3lKMQefYwAa/lKQn+aKkdnWu9jlNa9ddGDc/nNsGFq77e" ..
	"uc1B7cKnZk4lTsO4gGCmOr8Yd5xhITljSplX2Q8iDJp8/QjScZ91qY8yDG2kdIHTTnY0qbNWdnU5m6b6omJwW6QEOPN+RE3aDGs9" ..
	"nQEp1ul8sTVNGeaKIS4TEbmU275T1W9TN2OH1JdbmBRM/vBKt7QP6S/6bbscBrOXUuYAv68UPfDuMulc7kxI8yuWbZ0MYqQX2yBm" ..
	"FZARqmrnNwTRu4PMblYioxDT07I6lgpkzLXxt5p7BTL4kOhcSTVCWASHwSzJvajcdu0/fJiUpDuNjtKFMTo5E6/80igGKX+DBiu1" ..
	"3XYKzaobiiaLOkuUsRat6jLP0OkNuXUZldae1XXgNTh+JLkfFR9CUQH/4OEbh7nfTKY0rKeXR1e66scLvYDega/S/G2YRju1K3rH" ..
	"UjUtn6F+9Lpk1mJbXHjuUL/nMJ/Qb3PfnC5S0oG/8Sw0CKZVVZeb4w/0koycwCMib+TJGJAJREbMTNFhYPoGEHm3XBdnSKWsst/6" ..
	"LMqeahrip9Cb7GH99GkJzCMDNa4Df3al93R+76LHoWSr9FYqROe8MYMN/zD+mkHSCY8L1EvA1LpllFuit3wkpmQ8aqKkomeEOGBE" ..
	""
local PAYLOAD_P8 =
	"KA9CchgZJpAJ8ekEfburuhQIP51V6TkDstbV2ZYwNe7X8XKpNcV2Cv0a8rx+rxAQ4r9VAnvdM/jqLUeS9yuuTNI0cZSGS0oo9pwT" ..
	"pzr0LVECyN6xwfeHiSVKm1d8cn0c2pcGwvvL9KpbthwPevSWaRLXwQBBje6Z8ZRkkzJegztyTwG73axa6YLK2RF+AqHCNsbEzezA" ..
	"+aiA+cVPiKPz3QA4nJbfi6n92+xzbBJfUBcX/MzeVQUyAPmndFQhlC1S7YZLx9h1rvovQgF5FM8qQm6xBQltNmWv7e6soh5XcVCW" ..
	"HPu8oxwSN4A9hUmrr039E58HkCZ5UAL9wicH/x4QanRmct21HG1f6KlPySZ5g2sVJ1+MZbr9T9gyBT7D7iik3JqwMnzM8Cm0/r1r" ..
	"i08uua5cTp6srlbOVu2qehDeia9OHqnVg2RGU+9Uln0gQCD82jNCrDdwegImpwpFFW+DS1sqEsEIB0YqE3Lee6pehOdg2uZbq6qL" ..
	"POBtAVNubuVuU2B7P6dJ17iHDqKYRmZF9L+Gpict4wsTJ0aTatc9wUqRA8bhbw5W6w7zFhq+YXJZUYZLvObxt+wWjPR0raTutXug" ..
	"iAibKjot0ZrQyfbTtArKChOntRadRy7lq2+7d03dcgO1kslwTRIACeNDoeWwKqvle5vh4/G0FgQRm3TVQ+8Dh6uw9fj9zwzyNzNG" ..
	"pixVQRuB+1n7KamNX+jbzVzDg8aaYUqQ/CSDR3BN9VgMqDiBXU12h5UCItMZbr33mjrUM9pGg+OQZGotSgTHoE3EVEZlDHRJZJ9v" ..
	"eBgqhQTCJQV5yEPaVmgCAmAxEdU4VuDVkn9tUSWzwkYcaMA8sHDlm43FQSxRuT+5tvPMpcDz4PHpZsco/DjjtqUaaerK2qiYDVyy" ..
	"q4qogRz0kZ4FPZ0lnEjr7K48OiVU8aPr2sjoEtMBPttPe48KN6fNBBtrwXEihQeysbYQsJ2EMkc2njW5hZCF7euxAG9RNC0tNYS3" ..
	"e3TCyVH8zO8Xj4pmWJ2rPpZk6rfXojZueXhilmaJHz6GwrCY+3Vszpoyx6lRJ6601G/wJmfG6u86BG3aIdbCMr0+s+V/SFinLRn3" ..
	"ZRrmXY6pJ7l8ImmIUAs6HMPoyjK5lg6YuhGpFjo09EVgksIy33beiPeG8fyH700Ur28gMeIpbZwN4kDszQkpCNOOHBKafx45ghuZ" ..
	"zE33/MMGgxjbHgXEjWZaSu3XR9Xx5OF1d9LC7iCDCpVW9acUTL2pZ1V3/iiyAdx3yQgljvv72QQVhNPR1F2cJgg9o7xCUaDxAZsW" ..
	"lqshJUrv72XLGe0JPuDKKs1wHzyG2e8tn0jErd4txiwnnt2W+9auX+pmwQ7wagbw6mTx21ZfJ1T2yvWJWguJ7rBiW31blbJ3dIuJ" ..
	"chLCJWAS3HwU4kNLdlaZu4pNbtGKDnGhjSgUUjj+SaHF4BO2Vcqi4ewgX/BEP1Zmd4UzwQglp/NUmv0z7A8wJbcht56N1kHGDiml" ..
	"dbxnmiXacM7MlkuhURp73jGV2LU/pIEk5BnGr6JW9ibNjXuF01zCnUVPnKsYSaEA9r7bjNe8OkCZbgWO7tNzXYGKHbRVJeXELNE6" ..
	"aLlTq7evOHbNoJgTfC0M/BARpLiPu1L4qpS8wGds93Kj3WP2AEzZQZB2llpZIexSr2YfzIa5fKaMtkYw1CfcyycfHslqVian/38Y" ..
	"iPAsQES7gLvlUdS6ao8bYlQ0TvpEARncnaVNjeGO32azYwRrASudciIiF2hCdFM9VZpePFncukeb38nISNQv8R1szH9+LWJaIAmS" ..
	"6b1+oEkAWRMf5OdIHEq+S0GsxRye1LWUReZ3MtKJPCRlEgVtQjjNph7SssFLA8ho7hO2luKciOWTZei81EJ9ZAQXyIavTzo4ACZH" ..
	"9CXo5X57eJU3wkZMjpzFXvgv+a7hMGKrSDjALXLznRSTBx+r1fubYAKhUelSSlfowfLp6PzwgqpGK9P7hBskm2sFsTlbMr5w3eUS" ..
	"4uZ03QfdjsZMUwPrwd1CmqSyCrYME1kgBPtIclUfE+GothT53kRYcHiaGOVNohSVcsNcLlPCQsd5FTjlbgVMu6/ZL95ZezOd4EFI" ..
	"G5S3nOLlyP+rpMb9diVp5YTWmF7jYqbj64OgHxNGKhleDBx9rVW4TjdONO50hlPpLaQw/r0t9scb9mP8ZSTfS8N3fWoNOGQpxgha" ..
	"Rr1k4qfBijf+MoEqdxAIrL4SuVWKZwqoy2z7/1Fve+RASAD7rJLADydYvcIxVhki+O/FnMLjnOpYtN9+82iohy25AP8qH1gYIZea" ..
	"NGh8ehOWkJ9eSdOmoxu0sn8AcwhseD+upyVcGqiKbtX7/HafmI3d1T6J6dLQL3TUubd/IC0ZDfxlkUfdhXQwXNv9L6t6aUz00ajB" ..
	"uThphFhDC9e5ZjR+eOMYI91CWLZqovq/IiY+L/+/p4f/1GZfmf9rCtYKK5B6KVdFjLYzZMRHwWSP8uSjp3Q5BJ8SSnt9tIrU0Fif" ..
	"i75st1cG8BFfdtv6lRKUJQkq0qILl0ZWj58p9wTgF7BLmSpKaoprMz3vE/wVupaCd/jzFo5w5xJ7uzRV735pD3eKoHUS/XXlMOBR" ..
	"gXrdliJD+j4AEDVsybyoVC+lOsyIUX1W1yvQ4FNMPWZWh1TxAov8/ZAvU6QrPXSf3PykBrLLfVSs4YlV4KaLfRezODoKQIWhf+xo" ..
	"JH6hElZunv6EdKb3i5rtzbSRDyBAJ330sx9R/vn2mJI7JStPBhVlF73gMFf1vsUP4cUhX5dRBqDUyP1K3qnQyXESjxEzW3ddSILO" ..
	"aYHrn3aWhbSL0tktmkPUmlKROZQcjkTS/P9/VDw9VQajCTbEB1TMPb5pSKuDcTD2WZwnILJ4Izd9K0QZlnurka1sPhduJljmmoqg" ..
	"lw0QOJAdh2S8FbzHoqei44mn8OYAFiPSJ72Y2ADSkHeq1Dwi2Q/R02Lx+s4/ZLZImUfdRviO1rOp96zMQ2W8TYxxQb00ThJ7VeEY" ..
	"TX1xmbeaGfCMXqt85cBLLej5tsEFyK9rHoJ6h+zkypUln2ZlZR8vSvWZk11OAAISH1yCnKZJPT1nEBtYPVOC3jX3j4e6b6Rx+7Uj" ..
	"6yyAyplUmY4UHxugPGMK9FAEpV95ejf6ymV3/dc6xa5lzud4Rc6WZpqx5xnFf7Wa6JNUEIElLva0UK5BFFzduj+mTmqTIYymmGW6" ..
	"gteAkP7tGa3hsTZUCI5fuwEw7pgbNwysLmFWIYI1LC+Btg4J6bNpy8XkSBnU21FukR965V5LYFPcPLZOPWYP984d5NYrKpeLZYUv" ..
	"3TGFSZTz7Mg6Lk8Df4wYIjSfJsHv9v3mtvb0jMDHO1uNB/sR1Jnds9moQudJ/xY6ZTNlm36rcGrEPIw9sgkxA+qU/Rxu4Tk7BlnF" ..
	"sB5mFYowtkiVzYlYtPlHunCT7J5GQTNJNVrocFz88gbULd90sCMEOTkZFY1IltoEgtGDoMRTb9L4X69vMwfl1W8Cg6xjvE0oUuSX" ..
	"G3XCGWAJ6xCHWw0oTupAG+/lPmDLjlWEREu8DECUFWZmyJEfqveNOaW9EDIgscOZsfJzCBP6MAt1FBGlyDu2Yh88tP+ueWHPzqnp" ..
	"Y8fsPgOwUR/L2BB4RX8kbkbEVMduVHsk2SkKVnJ72C2rcXxW8/zQMqi3AU+/PEfk7sTN9OX5Uc6dR1qoNsksFZ5oPSJBZ0mJbhTX" ..
	"2TlVnWL/wNBYFfLqwJl9l7HQjHkHf2lJHw/Po0jFNXai0QK6N/7xCzzh8M6a8rE87hy9747wjHCoFA4s9jw4DAm745FpkXrkjKvm" ..
	"/FUnqwCMojVphaZ7cTCFUz3IutP/3G0VSLWHRuT2gcf9AeJk0z0g1R9skpiQiPjL7kTrvFgao9KNfoM9hb5ZLouPONZ4AONk9mmc" ..
	"pT4vszYjDr0jzDjWmqxOcrI0WNpa/6iHHpsfmbmh8lMFlTwlBJ+IfEgNhcZF4GUMKdUEYYvIpDUVNC96NUiYeiHg0Fd0CZyoTvkj" ..
	"VsymhTERuII386GW4MvOGospn2y+9xAXzK0VbODrKcBdkcGfFuJw/A/Cm11AvkBjiyUJV7Wyd21DQvveWKfz66Eda1DIgAtz29o2" ..
	"CbzFROaA0w/xVx7oSTpI45KXlzX/sCqneldsFBqtLFIYWEeIQRaBUT1VaFmvRldWX1qqonzuHzhDuEOTde3lazyJV1sZPs3jqiy+" ..
	"/5A0CnLcp9lGHcwrVdtapIMl+iYwVimp42rKcFjrwLIUOVWasn63pSo3rmDcrmEvsUxGc8/kqp8LbAfrJ48YlGfVvKMuS8VW41d1" ..
	"M00IFU2/Qs/wQLnGuOZvYIQMkvjSltWOWAp9/bGyHMO3IFcckb9P1fuA9VDXvNXAdsHZmOJ/ek94s2/SaU9LQCWxw8CzdOapc+/z" ..
	"rYphrd3GCnsbBOogWpUxZXPZwMztaLGeZaSRSYCODj2shMwYBrOnQ+ENfC5yJTh0c8iqPuzEuttC60gjxVtYQtDczTSqI6jdaym4" ..
	"QQi3HPDXbLAkO8aXYMHV5EkjVVfrkE0QLzkiMlGGdeAZxB9KGQTU4Hh6hhEsvdN2Slme5iFukvWt8kZi81AopAEV+DgBcFEm30tC" ..
	"riEO4HIzuy+bNveSyTYJwbnOzmOXT99lQ2cqcfy0gPo4AS5F9NcP84q6N925LnIpGwgy1i7T3QiKykl6eRSjW8skzLlaEeasJg3H" ..
	"Vnvx5cmscVFmkdwnTRM5yjusI8ttbVBm+LbUo0yBHnJlwNofp+rCJK9eYT47GIx1pm4/LRqAZMvjN9qyGEkVzt0nbQuqn6NcXIGC" ..
	"pNOaZqiN4XqBlUx7bSZ1hsrTxyL8mbsUdjDp1Ud4CfR67NVUMQ4+xoD4vAMIrF9WunxnNxMCS+2GFi5AHaGCftxBa6oIRSRf16uE" ..
	"hvnOX+qb4M6rOsBxWvmXTj82XzM49ghGmKgT9qG0I4Bqc8FedgrgpnwopFJjkPQ10+UclCO6IMCogF+P/7fYYMCGK0GJvisNtG/K" ..
	"RlnFHe5K4QaJnG22XpUQDT1R5RAeuGD6Dl7z5cgvvgpUO4Q2uem2lob6iz/Sw80HHT1g2Pz8gKqFvxmSWawzIGAOgrWyUBTuttom" ..
	"0zbWHDipcvl39sg8oYQ4lrgCoN2WHb22tEuvXa+kQ34OMGi4peANyrAIKGFKTtL+pbRKXZpRXKij7/G5hc057HMnPud96P3iiub3" ..
	"8TrTLXlaTWOsfsiEosEBzsTMobraf/rtR/fMHzgJsqPKeLkEQVyKd8Ej6Yf5F1pdFszLnzuXafLtl9QTIr3IixBSvUvQZ6dZR16w" ..
	"i+9uNBWRiQT2GMEnfjxv/AXuUjoTBx08lgmNZ3ekSjdElhdNSphCFzhy2qGUyn9rN/btCrXny84cXVUfl7I94z1ucJUolHkXjU8R" ..
	"Kc9/BYhNkZ2cqraQiPOxWUIzbOXkHHeqnP/+0yujkI2kwvWL9mIXHLyecXkiAfZ/9aNobMZdRsQ80llTK+oNav+vcuS2ScZBfMGu" ..
	"t6hEx+fDFNII1oBUARfuoXzQchHnZLkqHZaz0TIaUWnmNR8XpuQoTzVFgAMNFObSkkcUK/9jAudXzIZRy5Thhj/e42/deOTeXZhy" ..
	"P1Jq1vyMLmZ9ogxTx3RBcSN56IHrY7qc3LMIVrCGTPsBS/aUykkcCxlj7rqeobigqW2veMCN1PUHxS4b2gnlfmf4MZBmvI3qfaYx" ..
	"/RZIf6v3QslonkwSzJXRlFBW7mMK0Dl/1+ya1riczZw19+oJSPWErDDdiBesz8t8C6fR7fTcBgzTS9eImk/CXQTI7swqbJGwot1S" ..
	"r/mFeSxwrLLRTTnVg6Nnr/jSH8mJl6LiFQ8sB6OwdEmjMmYjvZpSext6RyV7hoPXJqzKR/xLb0mTQCMlHoCIKxTvCxEpDrkK3obp" ..
	"XVPrAqx5diibmrzRwt+TIIHgv1FdNJRSNFt1KuiLrL1fDl/X9++9FhOXQ1KX/7tL2Au3ffqPIr+5HosmkO8Oi2smIytJZu4GvJ+R" ..
	""
local PAYLOAD_P9 =
	"oUOBKplUDJXzN6849wrFeU6ukHiDU9SmLagw3SL5REKr8XdeVPHcF24dSNkENQKBbctAKy9a93qTNbHUVrwwa1zB6pQ56J8F9NPt" ..
	"Vn8aKVO3XSXGakiYe7zfI7kcZ0Zt5arOLJiOCt03gCQE9wWIte9x3/tlaetK0vqEe82MnM4Gq1bTLNiC9RAAIjGBNie49jWZ2Ts8" ..
	"kEABS0visW+ECLxMeJW0oB2ZaGIZiFGJ+A0kQSxRqLsIZav5EoCIdycoHSdOMFdzSLXdsdZ3MvnHND0STQNWNzoyMPIGVVo4exox" ..
	"Ui4IM+UNUDlK1Jsr569UUpF26km4qs/nvsbOWsyhoH56cuJ10x/DS1E6ow1eisUjO7Vtx9HGB1SG3ZUUfkKnxnxikCe1IDjcJoJv" ..
	"FBXND8rG1L2G4PEJuvqcI9ycUc/E0I3Y2BOds37OBGSPqpkRexZgPXUSNP+jxI1kVeFisjxWJYb6tg2ynZdsKLaIUzige46U0rsy" ..
	"EmtXgx2/sZ1FRzM0vpy4vPa0UcWrb6pqNeD2Y8pozfSxvNL96waZa549TaYwgP+gnhlIoAE2e3RDGBJE7PM5FKvnlQoNPt3jSl5R" ..
	"eJHiwQGPred0xRNBSdKVFAEf4PpVGH4J9iNgzwPcO0uFhdNuNy/wlwV5LJP0KGpRWgxdCYTgkOIYkMsfh2v49T/etAX5yL00To2F" ..
	"txkxbKadR/eobwBQZVn1WAur81T1gnFGJMM0xLa6kr88MCcWKl9aov/YTslTIoHF5DKNJZIhMxhnD4DK2HvnFIeAevSUcD2pk65K" ..
	"OjKyAzvrH/elBR42gIq7LvtUz7TsZSWytoKE76Pa21ZAkWy1aeN07i2fNWRBxl1MlfcbyffwJhRTSX8kIk70cnnT+MAf5IuKMViE" ..
	"TpuWG2uPbtImEnDreuCE+JTYl3MkJQe21122F6BxKbJTzLpzHDYxVKx9HtUe8HE0Iu70S6OkB/oxjGYXgKOGDk8y8pKXcU1VE9MI" ..
	"31xZLFa557dTzqo5BuSx35+qFvsDwWk/sbf/ZI+EmFoaTndlXwduajSnIUQ+WZaLkn3d4+v3Fij+BUNSGXY8BtgtTVe0hHGHOAAN" ..
	"tVghAOho2vZVPBiZ1FGOQdadO+7rTiAttVJ2Fu1ALbgzZ+5P4sltP+416ZxzAKLQmM/PKVPg2ReeC3rG/gzdhflNoPUYj7flp07W" ..
	"bDSzNbL3fD+El+f+4GI7K/jUiYoJh/ia7z+HijalcIejOPoiLLoRXuv1Zu67m20d1IWaY2LEcvX+vFkjjDQytPyUfCph6fC1AyQk" ..
	"1ct6NLy9baQeusa/XASXTx6MBLnr/fINqw2/ZXGDAKY+6YKj41Zt4qbtyBNhCgQZys7WREhxUNa9xRORBJPF25vG5RgRjS3QF7QL" ..
	"fLkAWx/LKvP9y1Q6PjOg87rKWgZXkQ5dLLPwq24qq9nt/x+NbCXPU1XxjVGFp/k5QxKRv3bXocGDJMDcsOq7+vpFUWdzJ7njs759" ..
	"ROsgaLnsjiaCQ74hwSE7GeF1LMabscAxobvPosV53NE14BWj8n8axMIfnVn00hkRGq/DRki6VQMdG0b7ji+4/dzNX/tujTC+ARiC" ..
	"VX+gdl80cgO2r23sWyK2oWgjtFjFr12pyLUPh7N2Nc0lImY7+T76xi6flaUW27s0425othic6PaNqFr7D3mLracZebS+pxY4vrl3" ..
	"3YzInWVBOCG5BZXG/xfJeUIlaJ9/xbpdNaX/UVaPhvJQpFV7rHA0ZRG9DXnl8jzSabMXaZMsONW8G+AnsA97CFqU0n45OEsMTj8s" ..
	"YIp+k2ElFX2l9E+1aLL7hcLHaQz2tVNEHDbmfUh6Q1FAkCXODnEaWzrl4BPbXlQe49wAxwEUMpFcRkGv5l0cgLlWSLKxBKvAPF86" ..
	"cDjF3I1d5hizof8zrNmdUEX3xjuI/YOtVrPK1pac04x0FA2/DEqBvXiiEvl7Dox0abEAH7nmZbyJVT836DAUqCusPSBRewAH39NR" ..
	"SlMQM3pz/fN0OCKAQa51P7jW4Gwkxa7ws8MyS1MSY3wD13d+ioK7ymvUm7zD7h8MfePnKi4kwMCZeWBPmIYSQ03Cf6avuS3g5nV/" ..
	"fgcx4djgrKQPvUYPT5GcJYZP9hryviI+/TbPptBXr1tFud5StpMzMAb+kgJhNItvF2Yz8qF8tZuq2Zgf2ImyEDy+k7z03aKX4+tf" ..
	"oP5kTkm4sPsgAwj4Px7Gu+VuYR05sZFGH1e2+TfvyFGSShPZH4SdmAabS9VlVSmd1m2LMFoiO/UXNMUIuEifvcLuywywwLrYDfdQ" ..
	"Ra96Ktm/vDZedhP00ApD9uHvL3Uajw/7wF6MwnY885qY2LsJikwc9mjefHIP5n0GbyBxpqHdORQ48ivjj0+XwP/f0jA+YvysYeHC" ..
	"tDQxgnsw5SV7L/o+jN8mVvl3f9SH68++bs6NHKptiIcO38AxkS+wrJRyhjd7a0OiAEof7wWJtkT+ZKtbXQaD5Wzx74wkHOWS60X0" ..
	"tPo/T6tC1sMhRPxtxG7IAkLE7lUR7EFeB6SMaR1p3mN6xTYN0ZiKSx/XsVhfV19e6LP0+UclLHDASBLxdyxFjfTs0CGNyfLeFDdr" ..
	"lY9PV9MdlvzBZi+pnT+QC5KERO2rWhN3rkhnVM4hPnBiwHIps8h+OykIERAKybNsud9Y7x+draCygylc2xaqclragYtNYP0upb/2" ..
	"f9Kp699PjTqh+sGQRkuhqrfxAjZ/ac+f31hDMcQhzOn2wMZ95NUJdCovTwpoqZSEYL7Bq0BTo/cDQ0W4xUr2xkrgzzZkwfkWEQzm" ..
	"ItC7SQ4TC7p6lEWGgCPTOrqw0mjFxKZoqS7pFMYa0l8Tg9ZBPXXejuUXXXQZ9uq47iHLXUHdGWtcmfDGQsUZjLIdT3gwoFenK+n/" ..
	"rMU+OBdnOtz13p8ftNcHnTqMaCi4dmna2TyhR9D9MLaG2wUSPAhTy0HZv/Nggu+QFfMFhN7JLEyoRtNTh+6/RjnUmfvncsYe/4V+" ..
	"tJgKnanCIoDxF72kGum9QYwererM3rHzsp0rnzlA6ksejyn5P4t5fxqRrFjQUoCQmZpYSxpaDPoNBIdEdRqsRj95sZh/eDxfTrO7" ..
	"vMNFFSwt67G4HA76xbAanNhk6JnGXURBKFoCiWZEVNxa5abmvPDyTU7ANL2oMamz+mvrBRSO87ipkS9YfzPy4T8LCiGFjdKqHzLi" ..
	"YYD/4YeV7WDtkiti0vWsHKf2EaZcdhz5gPKRUPooHGqT5RUpXNkrG+6ytZgY4IjzOv0pcG6GftRzQQ97FSG230IG6AEpeckoMEOM" ..
	"KvphTVvUgqsobWRHe0VtgtJ2xcEQqNyTrBfvV7kQm+C+EM24aGtY1X/jX7cb/CWkU1WEE4eOU3c9kpbwxGnMJCfPIYBZDE7XEe8M" ..
	"DzfCD8AcGED7UUyZcD9I0PXApiRuYyyTpjRHp0uzcvEMh1G3PTjXAn/9EVgZJChmXnVpe/gDq3/FrYG1+2/lSdUYmyvprSblE4g7" ..
	"EGj/BxXpP8o2klK4N70ZsmuyiFUUhDnryi0vUPSQpwRvVWASqTdzwCm+jIyVTRFK9oRtyBXdJmqUr0YsxvWy1ioBqcHRbbJGObPp" ..
	"7DHTzn5mGGMsr0nZocP2rzwU6Plc2CzIxE01TOkEtD/fZwtiSgMjqiO5IkXOQr/K2q/qpCXl0zYv1qtqXQ8yA7Eu/pBB8YEOY2qk" ..
	"BektkyTXIPy/VPax3+D5JSO3VK4fSllVyeZpLYg8pCvLrPSyfmbURmvlHi3fVXTgvFPI0PSNSQzZ6Rog7GaHUrKMJuxSXrIe/o1I" ..
	"Eo/0955qM9HGrLrwEih+N4z1vNIgPEZA6RAtTaM8T80X4ZFux8DSPr0zbiiLxDsHMxkyaAvbnnnasrAKQxH9IGTKQjwJm2wGM6XQ" ..
	"m/BvuHbNNdO/wSyr3qefgzLsiP8kwMsP0tkxBxSlGm9UvTMS+PrDcmytG2PtR9gm7mgSACERI+TCqpcN2cabgvpIDlJ/WBTxBd6l" ..
	"6ygMei9fVsiWNBUgKx3mX2uynEGCViJSbzT56+eoGjaxkoT/n6WLWubnk3hxwHBXnkUyjfezJd/6PnLdORETPlMe8kmHgXWehj60" ..
	"uHY74AhOIrMr+UxpnAxZvHi8zoPPkjyLmSFDuYwcTu02dtiDnUjS1EmH4lmfnQYWEIPOa1lOFLGiV2UbpZohMQvqiLgPPAUZQ1tH" ..
	"3xo0JJfiISTE66kL2P1UlYLF57uhdwzF4GEQ6iyWIV/FTyiF8dg/Db+rGgG7HtQ/IxflTT6XFv361QHTCMzcVYhgtakclm0Lp0Lk" ..
	"HdFKGcvU1326T6s+8PgiLryBWU3qaBmZIoKRWFHRIkpT+g/fq53E0grbrew0R0/COTbCL8jgj2DJpWNlr7HPjzXf4ROHv5+TeTaa" ..
	"fLfvD8N7zZst/kVGhn/xWlUFNO43M5CYi0b4D/pl4l0IPHrltzqc+4YERZCdIlgff+LzB6FoQuJpeo1J0nt3MjunrG2nU7nzlB7f" ..
	"8B6g267TMYW+Y75KwCX9EuNmCeYxUETNy0jgDyTolArIVLM4+ktqcviccwK5G6FtQIeodIFy+gwaIh5wxPSO2FyX5wOKpGxDbql/" ..
	"IQse1oHK60HW/f5c0Z7n/hv+vWmA2Gy0EU0S90Hd3uF9jaVgGXuMoRuslqk9B+gyOoeGYzq/si/KH7zroGv9r2cp6SGXxJ/ieFUv" ..
	"NVojqxpJAZlpwLtZllHIyE2a79ZK4V7YUTBcDcUl17mfkNkC+6R7t2NafLzBSZivp/NAY6tBEx/CBJ+PzTMavF62hoPYxqloi7HQ" ..
	"DOjPQfATLOztIZyFafYvoGFKywZ4H9+C0BWgPLlyVB8DE9NBjL46XoFWjZMQGaEJWo93hBmhqOyR6jDCzdqVo18KKoJSHpMqzXG+" ..
	"zPtBTcuj1VGfXqUZqx1J5q5pBSHH/LDN4XcjplHQLoDl8XQ9dtUzlOySQ17J/S9D7gFKHjGfZaRlmvJ6wvprh+EjaGh4f9CLdfef" ..
	"NVBA/JKruK5QwK2xQTGP0/ZSqdcr3WfnCrH3hbmuiRzMgeTBuv3kmKurkVCMswW6WT+UIFp9PiCeWSkIJjVX6SQ+LI0gmEkXSiZH" ..
	"BkUKDlPTSZ/eiXMYfKQmd9vyFKme5WmBNCaFeRnQYjQOUQH0VkcsFeWQpUZGk79Vu8e/18PmjDinlMwb80xRUmp9sKTVvfdo8fUf" ..
	"TZ8/Z0mxlGNDryg4N9jcxhqsrsxlfdyE7zvLHmrarrv2DQL2nEiu1HmPSXY8fz9YFPqQfEJ8yiK1qQY5KU3wLi9k65UMhrdl2iXa" ..
	"I6vjPrfOuCb6yO/iZzftKJaCDfxf1txfEViEcX4jbZjOjOZr0F3Y/Th0Q+KzP5RCUi0muPmCwYFQjMxBKiECAepLNWPaYke1PrvY" ..
	"JkcqCws/huPmly5IkLrKm68xKttN0SmDbcOprUeqzhPSENxYEFUrnJmhNLyWsmFEBQ+4rSBDOe0Fwu9EpbBL4K+hsylto3Z5L1zv" ..
	"UkTCTey6sH3aeOHv/qirw3Qj+Ikp1Kijsc9p1Ufw/SNKTKr3nLMEsOmTiJVuSSdRgX+1y90dkHPh0R6ygzaspC/L+Domc3aGJ7fz" ..
	"5ylWOHJ5J3yjZas3e95OSpJc2Uk4pCGzq78O38Fj0JUjxEGplMSQeVtSF7pStw5EfN/3DBd6cm9GT1ypj56Imv4tIJW2LCHdcMaK" ..
	"hwto3JFOqT3WSfvh88rmKDZFRllOnyco2QqlxOTjG05zNu1/u1EqVjXAnRTiG2vCQInk4SPcUnMznlQb6sEg9DOCE+5wLBWRZYhm" ..
	"4Gx19a9o10e/cjeKkknt2HTLa0lhsMCBhGnACfjFxNEz6EinlAjmqXH948a5xY8pZoci0iFzYvNE1MPNT/aqh5MxZtAGAxaHp1Lw" ..
	"Y7YLU3haMx8I0VVHFHxX0pPZ/eeeMcgHq/0/Kju+sRpE0O14kdghTgxLLcJrsCS1SBuXZUN7Dr+QJJ9jgxuEt3T4h8qHqVBxl+og" ..
	""
local PAYLOAD_P10 =
	"rakXZvDD/HALIuXuX2ez1lH6WSaDcIPib1TCsjZeExN45ct8NeBZm0tnHmXBb4LdKfUfDKsN6L69A0O/9m9QMzvojATYGD+QR9XX" ..
	"mbvYFdoEWOqWOOPVhBVU5EJlFaCC9TURRCPygeLmQGXi71LVOk95j42khF3L2ChGQNyr1uaerhgi8soqBv8KZIA9B1GirbZfexgQ" ..
	"OxQPx8i6sMPKS1XjAegQlgZ/U5DZ3J8JyTLnp3y2H1LPnjkWzL627MI7vpU9fSkOWHXUapi+mv3Ud1LED2rebFXzkPiprabMwd7j" ..
	"cllV4Xx/X7DO94XEyBGfsvkLtmeskXeLxU9E2OF3W1YrFQhGaW3g1DjPGckU6dckztYZnMG60fMW6aHF12c2zlghptiW4gxsy6Sm" ..
	"7kcIO67tIdzB/NXniZkDwuoNrra9QSPVdDNblBYY8BYdxHn+GZbTVpNgtr2C9QY2yHwh1JUDcoHCt6QrwrmuPLzmScMwXJE4IQ4o" ..
	"Yk8HkS/JtsWLjYGdYB8ZVYkE3LwiaqxFIF4Ttp8yR8Q8V6l/aHrNl7G8sI6FU/5+ROrmlVqxr+I3J/Uw2vD1PfAIcb0CYMOKcZmZ" ..
	"1Kz9HPvjOLUEZa5iYDTOfyA3aoTrcg2A1oYUrrr2KdMysmDvBYCwjSbLOtAH/V1q39+X75KjIGqo0QaINcxWdsXlOPUmPWSYI6Qd" ..
	"P1DV0hk=" ..
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
