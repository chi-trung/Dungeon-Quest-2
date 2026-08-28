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
	{ seed = 471658510, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 476352536, exp = 0, plan = 0, hwid = {} }
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
	"cuQnzlZeQFPbJOe2zBicnvhbNG+J8PajrdRH2iADK7WtCOKcDdPUXjGn1VBzKTE6y4vh+sFtyhd9Pt4XzP1p9sMofDkX28EC05dn" ..
	"ipC2ggIALk+ztcTWR81+NDz3xJq3wWh1dJzfg/nZxnzVeu8GUtbLMbHt9rWshYF++ZiJ2kT/f6KAUNGCJuEjG2uhDiiepXasHCuv" ..
	"qr0GbCiDPP7tdsjvG2J6qVclniU8U4Bde0Xv3+a5nl5lAA/SdiCwu0I9kaZH9SLWdkvB0fjKIOZXBvJ+oX574O6bxka0TpBu3Mui" ..
	"MddcEYh5+NaES394UXIyz//VUXYHoWj3E84vaxA8GZHqWKhjhUFbXG1nX0xcWuwtqZ9o1VOmtuZjMbOTvH6Fqf0VV5Kn0lN3vQte" ..
	"1hLx58lPztOELgpOFkZL0WcBZGMK9/jMFNtLfuEPv4/vLAy6tZVrY/KlQTAzBrfB5B9FFPskispPawCBxQ2G00mJPQOJdsq5L45y" ..
	"6tWfXHIy8PGFE6d/txK2mbPq3juB/wJme+Ou8AkINmDLNY0jtgxalRsosPFexr54XYAcbsLE2aA0srCJOnNlWHDsNVAzfD4Xb50D" ..
	"MMN+Zup67ugqNicw+WakE46pl3V6JyQ+C1WtDfl5PlddyiFNur/mCS0BUKGQjTu1eSA1FAlkI2XoVDlxdMzOFljNnr8YR/n8PP0c" ..
	"GYkqHKRq/50OJ1IEl5tOTQxU/yUUREtWz1l4+gpF8BBD1pmAtfD4PDDAmo7ECuX5CgPYqsLK64ETincFWdcZYuM3ljHPA9RWx9mO" ..
	"Gazud65mmY0iFX77us+WeyDzWCMKTfB9sTAMZVTfX9vPN9DHgl+a7j1IHyHS6UI3iQei7sADD4N4AwEO+5+VQa+vc+ZYehIshVsQ" ..
	"eXFewnSBE/THIXwGf8Ofs4Ycmmzesn8u53iQtjmNO3EMGocP7A/qbvsuJJbA9XkWyleFW0KE7PjYqo/6dnrhBpBalkNCHAhlYTrc" ..
	"j+YQsrOTW09zL0DRncd9eW4p80ZT/BO0BR+lMrlNIA6I5vKF0TVdJpVvzDJH/UFTNEfwhG32f0LRH6JiSk0HUAaNOFaz07oLDqP0" ..
	"0HpicuW0ZmuaVGUtS4QLjulweTqZ6h9sjR9YHOXV/H5IhFW0zLc6oYvGyzcwFPznM2wdSRzkyxHzSlPyR2RE9mgKBvVSChYOK+lN" ..
	"poPXZ0ZClt56luIPthzeRr6uqm140ZisIBgN22uILijEQLAOt45SI1IBfzzEGoMz5sg2pcpdlExuRGRzA7BerMv3i91zjoA0HURM" ..
	"hCZlvwRXiXjH3ffvYntkkW8A8NdjoKfWNmGIqkWe39D63ahfV/RYQFoiOaASDHroxaR2Sk6gVm7cnkdqgVlIvVsXvEgqsbZ2gYEB" ..
	"q7q9hm/zyZqz+7cgGI2XjwBeGJL6VoGx5/Ouad6lXSpYVQTEdKGFisv34RpB97KfRt5pOIYkwpUXglTB59sB3kvGu1NU4dh0KWaO" ..
	"q4QoDS8qHIJHaBNid7L/+kvVVDdk+qIBBV+8tgunOoUzPgE0Hon1dMsRQwDA5Xjaz0QlZM7UJ+NYehDkWy8gd97GsN5wp6a9NEEj" ..
	"iOZNffzGI5nbkQoeYQubV/oQ4SrgTWmMcasGfBhDBYwvHkXT+3S0pfip+tLvbhkKSf0jFVGp8pHNT4QhY74Fp5phTb4dToX70/y/" ..
	"vIyQYcTZaVTT5Kla/wHv80aeXuBelYubNzQvf6uwIjq8SaMqU5Iul6WYThp1pF6G/6q3GFtTRyKPF5dh+NR0CtF0YHSkwIQciKp2" ..
	"8yrV7+3ALGPZQ3lP5d8sB12yI5JrQb/amdsZWRNbTPKIfHBfghBebKt7PWf47tnhSo6AZPBmQEKTJUWNUMsP10f+me42o/e9vcE2" ..
	"fnfEtgXMVxcxzSO+snILpT6M5pz5LMdpiL14WxL8PIIq+nss2dGbxhH9rSb7Lzv/SerM8R/orXn0v/AZGH+gsrQuTIxVIcR9OU0d" ..
	"D6SMvAHsW/W1rHIYz93MEHKfDCr7F2ceaG5pAo5/dAkzzHzH+7wWyyN55pwk7p63Zne0xnkoTJOw0bFOn9Zt7h0zpVxOfpsFK4b6" ..
	"XG3UZmilhdTymo97s47zyw0p95Pyljyh1x5+9iTGukxpumrBtVNP++BfK7bK1x1JFb3ir7jtYeWjgPCX1TV1GdoJ7T5MtjYqkyyJ" ..
	"1RIIoSKACcAMnQ2PQsIl+1W4I0Q6CMEJdV6TuK7QO2Icus9iKSz+WjsL9uchRi8IwgCHUCDGOAoRm3ZMu/okGvecQ0VsY4NJt+Dc" ..
	"+PCKJVHvc3DPHqjNd+R/ZSv8yVg2rR1c8VRgakNFVDI8MI1M9rln5U9AJRwxMbN36CLgIbHYrskC6rvmJMJdnyZqG9Mp/B/m/vrb" ..
	"vRCvbJBihrMCUrZK8uCJxv4Tdq012su52KIFnM1/Nop68lWcrjBMoGGVI/njx1I5kGR1ItBHugyeOdf4NmaNdWnGM2tav4+P2Idu" ..
	"B5L0PPGIjWzRyhHHrwNqB9rA8wShL9GNTQj0Ti3CXyey823eA27mthr0Cj0F7SocUXRprqMX1MGqU5S+oeKwteSnNjS/LROEZDmy" ..
	"s9OkmRGagnHDVaGWcTqAeHWbTS8C//pPPraxmtqxo/iGR1lmSXLEK5H4v87gIKQPZdONfsvnnDpnyd2HtIAWIU6+B/DgINEB1X+8" ..
	"iKtnRZfUv3ZQKvEuE5bDFKIeG+aUSuq5yOLngukDJ6m3A9gFYpv8JvKceW48bJLtRdCIqcdvKRmk30llCutWcpwbu+9FOqx0+603" ..
	"yY3ibDyAiJyptG3CrzVGr3/MZBP0496zd59V8olCiqR3SgLkYTVvQboI0gQY1bXcJlmXpNOfDoNFUmOlkL29tZvAcPx/UVcb8YFt" ..
	"kT4KtkcdZ9DOsBnBr2yTFpDTHdTWv1nDraUm+nWE6hB6AvJjIppRiUuCnQRqpdfqXaMYtJ29ods84+HDAiU0BBygF1SiU4rQlX4z" ..
	"m2UOMuZ3oD9Ou0dfRD36nLUiLvmiyR0iSHr/y7jlaAuWMwLQOUfS5YsQZROukpN2qC2zlQpqfImbBQ9tpgk1R4MWTPrFOjr3MEk7" ..
	"KMF81VCIZh9oTY3PgO3vRiiMCkkh9CUtXA3Hg+u9lDiSxJtX93ou1ljEn99/n3qETpr91I6XGrKW5wDp07wptkEQw/zUKOyyTCpt" ..
	"8+VtpdO0lJu+FXOm6aWu5WT0Hk4KbyvRquZpuaCxXsPFiWCUjRmtBUAdGNgTeka0icehjMlqJNsovlnLwWt5At57ROSVhXEN/auo" ..
	"ONUs9UimFWtj4T5ZgrDAGae+MIyx11JpVgb3jdlQYXfXjeg1PQTKvcBrUo/X/VvM+XlHlHuT76CvevqyF8GZI7r1v0ymky7s90oL" ..
	"e7ss2NBXxdvNRDVIk1U5G3i/ndVOm5+vBvaEegopfJyAGSgKJPdU1FqKn/oaHYV1awJLEml9tCA6Z+66RlPi9LHQCGIkvCEYCi99" ..
	"8Ft3cbjRSrXLvMzhkfxu5/Qlqcp02LWdbbC8dmnOaQCuXmr/HpIu64RLXKWNHEsjokS4FZvZT6BNUuOV5oZegBKcYqitULu9MCYA" ..
	"aNxEAPsjdtNPmYH7Uo3pDuAh1OpKe78IlHlzMXef+m7m7vuFPJKTa5fRxRAF2I/GxK32Rnlmgfg/SIM3U+s4Hy6VuWYrbkdJYUEc" ..
	"u3q4/z3EjfE4oTpXy7Oyd5ho/aBmaJp2uXABolHomaKMuux38rFpPrntrXOezzZN1+MkqsgCy9oZ3phDTCuWJpoNM2XsjbTQI1Oz" ..
	"Swf3o8ZQibZXhaiykLSKpvYO/9JoMcjo3ZMjqjhsIH9jr1+228fnwqJeaiYxonjet+jYe6YkhXzNLxohnwCS2qT3m3nkVxF4LqKN" ..
	"a7VQSvjUoOxc4zgfd0pfdscS3u7IU2xelPXZZUWDBV//RPYMrFO6j4T1kNcomEmjdsgA8QUgHP3hjs2rCYlBDhMXbhf9CpVThIQk" ..
	"/6nnLVBTtXX3l5tRgmeSbMO1oteTaN35Gw7BhtSICK5jwwC5qmI6koGVyy6IJ3A2AkYOZciifR6yl+N9TYWymM3uk1DwKzudBOcY" ..
	"yzebUxdgoYzsTt3bG6QQ5y5qJNSpRGx+eOX8sVyfwTD0+qi1D+lTjZ+BNslTtG2yef8fx5Fa4GJHbErqF9MsbgkyjZyklPEfpxyS" ..
	"IzG3M/OJTeZX9U6Ry7EeLBAhY7p0TnNWZ4GTvy+C218NQItUC5dHm0vi1/7m/Cz7J4vJ0jym5GqIsEBpzlZM/3zZS/VnV9G+ItBW" ..
	"rIZFbbjLfjRIPLUEIcPVvbB2Gk97Z/WbtvEmBKGnq1KUy/yF13lcHQUQls0tx3nCP+qpup5Wot5AmeuL+A71mzv8ugQlwzF3qInO" ..
	"Kgf6NkzrbharQtWy4J9qGk1V9z885XWg1ZGtiZAGdcJB/MGl/2SHqFAYRseNYXUeT6x3zOEFtUt7Uwo/TpuJf2LfQtWLdvMU9nLr" ..
	"03IJZdSnAgeGoGTwr4/YfKdwF+cKO5Gx9syz5Z+Uz78wjHqks6FIV5VZoNTqSIAp2Gd8ufooKtBx1CqFNziflZ6yZC/LuMyFjsKu" ..
	"UTtbFC6bGNNQeDKYkDm9/G+9y4nFV0NmeEulNjH47sYd7hYYenYMSGKBFcyeOK0ZrtAJGDgK9Ur7a7aRRHxJVrzoU4Q3+X6P73uf" ..
	"DMk+NU6K76Q5teGuztwyjooA55Yq9jX90jY6sJu1qU88E9FW+9qcrgzaPzwKYl6gh/Sk1EOV2dXmS07VawMghr7f5YfKkmpIHSCW" ..
	"glOLP0d5Chak2aAUx6voe4XSceXDNtl+ui23ASlb3GthqctSlSg31ZcqsWEfIlKDe0M4UJ3R9irpaKMjs5N4TeKT3mydUplK7Kt/" ..
	"96GZa3kcyehsmKEeysCYpLXiMcWYsU6ubYIsy5CSc0fpRORAW9gwj+kZgz66MOKyX8IHnnbM1Yv8zr6F+u+F/kR8vRSgISkSNgnz" ..
	"juuhAqZSZ7bouvx8oTTXpjpOwKO1zDE230tc+nFsfEA7W+ExAH4kaouPUakEh6BQzZv6gXo7jbg5ucmrSfeUtYx9I8AQ8l8ZyouI" ..
	"HrPaMRmIsd0gTyQrb5gEuXKfP27UG+ezXFO/pdUv3Ko5vt4mwahRXjx8bSLaK1Wjjf943hLX47OXoawRF2GArBgpxii27uI+rPFX" ..
	"6rH+5whDfBe1MXbIhNYyob6aIb5uWl4lpQYCOmOQ1+czCFU10JCE/4ohdL8HBSqA9pyjJsSAAr+zO6vnqbyhnEBbz2OwZXa7sYSx" ..
	"ZNCqG/6lLoigqxSIEZD9eVUOw4y9rR4MfkLn3w4lclFJQT4wn0hi0ml8Cbo38EYR/SsGmuMy0NXY14QD+mjsNRuXZmLQTd9o0sY+" ..
	"W+hfdWTsgwK/4UVWTTD7TeQ+NTuwVk3QsqX1PxyLoNpKnlR2v4lo2RHbdxJetvcM+vCmWtjEFHh9wpodWeruVU/s3r7RN4ThtXwT" ..
	"PuHYk3QgKVLz1cXDVl57zPxdyD5kztMszssEhyO4N7UAR2BpJsmKSL35Z1XvkGEix83cYPTNvEGxnTC376E4N2/sAMbqlMWyrpvp" ..
	"XD+NM/ShDpZ0alUn6njjlJEJvJ3reFiiScgGo6ySsyYuY5cSSL+ys1C1gPXq2VMt5g3b1sQKH0sag14M6EyZV7xDhyOM40jlfG5H" ..
	"Kms7NSZLPJ6gf/JBeUy3hI2a2qOQFzLubrNmLzeIVq0SslJ2hIoC6XMVLagmxQljE4SrMBFS4QscwwKcJWictjl+nsKHNSKKPtpm" ..
	"j19WsgXhhvIxcBJwFlo2QN/tZx+2FpY2TwIV1VEsEhdZGThX45OYe9ORUWPHK4jyKz5nYvmZqc+TjL8l/1vKanQktdkDF7kf0ZIb" ..
	"0Cw5MHCElb6V62TS5uJv2GWXG5x1YOS1UrCxooId6KJ7C2mImI+I63q3R/rMzXQf/y1m9mL/UH6FYiQd2Knd/AcHW+mCRVJObcvY" ..
	""
local PAYLOAD_P2 =
	"r7rDZXuqkt3XtSdV/N6j876STD2Dw4dgEhnrNOqGApTledxbcjGI8GFXRW4n2BXguG3/O7NWfZExaZJFT+8NRRB8xT2yHLJ6Perh" ..
	"FhLa0E2nLxNdtayqzsz0YylCodXsIdblfRvdkivOrIHiChFs4dQ37MIaCSsopI0nmfhYkuLKAQ9DKXaYuJq5EuARia6bIbve7xPI" ..
	"BfLaJcx1nkCTEZzz3sp2DtWTZlpcP1xVl2nBDHKFWN34mDgyDEzeG2mHBM/KcuHidPJ9FDIbXTA4tGMnFVgAZQTcUF+q3RyveQi2" ..
	"YbUFpLWu87H0DtdfcV4KkAra6S8J8vleEkg8hLDAjOErkodioxumkNXAQbXjisIryCVeUmXdXh7Lh0rFJ6tGbeq56M/y2JFqs/MH" ..
	"n8YhKgDVZV2a2ayPQG+jJ3lYTXX5cmImSIJb2UKb6BN97sN8RbmTUdN92thvSvF9tdxfGiylHVfMWrOWtwD4s1ABe57UroZKOqvK" ..
	"HslRJutSt306rnk6qFr6hBPEwO5Cm6q+Cky1ocdk1+5nG/K4aejc4KdwBh80mlanyLvn7740NZSRV5+KsbENDDrXGaGBoXt3UtxQ" ..
	"jqukTBpSy3uPcjb3/P8OH03d4I1zi5euaG+OCkvhbfv18KKOM+zGzrZQuryHUKD+m1AuRT0MmXmM7nd+nFhxlxBMoEkAPKRY984d" ..
	"d0dHFqf2hUr2cNqc3ZlN5ansNCfKe68pY4a7tvr1hx1PhhtRrgSDI/oOxDM+XfU3j3jij2WZn/Ojr1npiRvdSjnJn7zF3fsSkKVQ" ..
	"ez1HZ5FsA2ks8dpri/SwSYVP44P0tT6JAPaCMXTOwjFfCa4oOhMk/NlWDP8db+R0K68LxUN2ugeCCEiOOmRyHMzHWInQhntUzUfs" ..
	"6KPgOcXhi4LU3M04Ln34ilKv/iwwhmHCcKYOET5r3WomZ/zAcQTp7rPes/aFdiuaa6gGwwQ1Q0pszkAzmld7cjscpJh4cDaYfzK+" ..
	"22X40UApXL9oScbQ5sVnk1GVaDWGn7cn+0TScW79qZ0amdVQmJyo12P1QrjoLZwOsHEi5x/QAdp1BvTzwzqYEflnoDkQ1EvmV5Gw" ..
	"5BD2qAuSJZV5YaAgOa98Y2Nndo1xrFHX0lms/7WUIRDONlPOvsxXC08tGwgf+QHiQmwDaAJHvnVm+6mtscgzPYbTFqSuHI70IcjG" ..
	"5XrDurnCtbiace2StQPWaLAL5D95e5n7yx7lX2Xyv2z0Qd+rKD9nXjaXfdPhRZO/Tl3aRuX20IL4/tZErD4Y7bAhsXZfuJJsM3Rj" ..
	"XmTJ4MJY3K/0yCg37Hx03WqzRzs58L0Z2Y6bZ6Y4ZyP+rQWuZgaRCzi5HEYKtz3fwzrPd3bq392RHjbGBO7QFw8JFOG9bq8SBVf4" ..
	"GpIgwdFaOXaAWF9EnBJnrs9HwsQdbdR1lTM9Nj3LHr3rKBrTmpuKbg4dpOlkmbh5bhpITiAwO1ItYCorY9nBB+upPQkV5gEN7DC2" ..
	"t2oBHeSntA/M4m39EziNUhSxVjhlYapEWZIYr5dDUgQ8HR4NawjjLUio7Rb/bZe3SadrMuMmJVQcc4UPEvQ8SRtQFDCmpJnBUsxE" ..
	"4Qqmh1/PIMip5QrH6mwGr+ULH0Xtj253tL4eSr5zZgW2ZQOZ4YyIqIBK5+hX6/Y+t5gaAawIBwteYRegXRti3tQCNANqqOEi/qcc" ..
	"LRK9W7PnxmSKiW8p2KnmoLipFaYn8WRlxa6AZb6zGtf9U3SBBUzCqO9Qz9V2xFB7H3upM2cHcHIegHt/E5zICcGPHkBqIy/W0OlA" ..
	"xflO20PSuSgIdE4vQiwsL8B3dcsXF+ZXgjpfHfMHyr+RCb/HuFkuZy7nNXnu2Z04/8BCLOEm6dD3k09nNo9aQ9/LKXY8dKybAx9A" ..
	"/FMpan4fO+lNHQnZprf8RpeKHg+OiESGQPSskHT5psSdOBL7NxrRwf79fL5zwNeD/uCxEh1vvt1lmONXEqzo6+/YOnqjAtQFNras" ..
	"X/AXTy3N0utNO/7tvw1OVXzzIiQyXgzAgV9ILgQcCZ9Pqu5zsF9+dmZSzcPfvVFdYIW/x+FsETJJcZDIlShUEBmK6XjVLg4FQlxB" ..
	"4+4+KabwOQWqjzOmf5CmIXDNQPD95QgUFrk+wJqRLJK9VHc4jBN27aJjbVXfK1MJjm8JXxGp6Rsjm+ImMY8ChxR8JuBp/GYK+Bli" ..
	"JZ9H290XN3K66pBtZcKFDfijht8v0lgq7ABki+cJablVJ7oPtpG+INWW1Oy/0YNZuFtIoeqNcTLq26OjD/ioaZHZsVszppVTkzMn" ..
	"rKpCgI9CzRWm6bCczmNY16sshME/HwKLAhk0fEBMJxJZOoKqkP4QrAFK/4c0NaYq0sy1yVE2nBHu9rA09ho+fGxRC+GMX/LcKmZh" ..
	"/l+r+4z/mgoDLFy2aoahGeaYxldNDQhUXNna6mSLiwi0aCWTGOk66hLwpKspZERnzuo+ujcT4iDsTtYzzYrFZGSozqotNCkZwUKI" ..
	"LTMJ5HxiDoCj/1k14ksJd4s5Ub+zc+vdFVweuahzYdPyhh5emj8oko8BgBb24wLugiyIarirkdLOBMFGs0vwAJiVMswKpK8Ilpaz" ..
	"sZ5rW5MAZtz42/bIvj4NEbSaLbaCXGH+WW85rH6BmwmGP7GAB2dp+tnkDWCB3ljnWP0MO5o8tT2K0O2ZZIcMIthuz4QKpODV/j9Q" ..
	"a5PehTq4jrtKmtFWVr6Cie9bNAJCkbA7pcASDxJ1QT/LnWvyFuiL4YOyaWbSLx9eIzT8TjVj7GcxEZ2p3he23SJzC/sD83yFzhgy" ..
	"KjWz6EyKCJk+v70icaGyswWhGo0TY4FEu5Nq/W2FpY7M8Qb3HzRMNGwlMi8ZeHb3TxKWjU7/NWL+C/Opy3wapanEHk0ksui3szrQ" ..
	"FusLOL/p7VfsrxIBZUWB+H8GjC2qDJ7h1LC9ECOM4SI1iz8xDj75dedWGKO+poj1D4M2WuPCxk2fZMOa0NiJzgbvNBNaNnnZF/Jg" ..
	"PkzcIVwAyySD7MLELFPw/UeTD5z50WeBgNyzWPLfD+M5nQ0GEQwHzDKM1RW3WcyWlBPOt4xx1dIAXrfKpgdBHQT9t0GxEjVYDei/" ..
	"x4poDDLGIl/rfRAlzI4aBsKl1EsqcDK1O9JxHgAiBZ72iTI4If+lhW1hm1PBET17wEMq+pXLIwD593Qhj4U2keTjFRaFgAd++rpo" ..
	"HTC+ZhM8HfnzgTAv70o7bnOuXWPBzgFddf5GPk/lPo5y2vT5C245iVw4ovvPwiDLlWW5cqVeBQ4/e9kWCvQfka2gcWbchXt9Q1Vl" ..
	"B5hlnv3B7/mhAaPKOgiNzV2TyY/M0v+myjkyZsH1sSXhjVFhezZ3HRlhK40GwUbmxzYp7/iO46IO9kb8P53sUYJACDgWRYP/FP4w" ..
	"D4c1ZsRKqx8NoBjIbOrAfnReQTUXaHmoAupxNzcQ3xaN6I7ZatfcdL5lgX3AwvrQSllewLr8l2c0J1O7MZjoJVzzNERUT6bdYTnl" ..
	"/IuL3OrhxkdyDA0k3Sli9DrkdrRvKv0pi516s9KRpWPuWAuo7s0w4VRizwPoD2XSDKHOLHxaHJm1Rlmq5C2O/mVHEUPn98pdNt91" ..
	"IrlL2WxLbX5Qh7a998e9vpz3nrUutdIqpS5yyq5CImzHKVEEvnYUDSRdcga5LFhdfPMIyToSMt8MIevKttckiz+pFJeiqzs2Qnuo" ..
	"rnen6Nml0vPTe0LBdjmIEsUQxrlphnSTTPFSmnzfn19fqn7H4rxBO9IJ8SdNPOUDZ56UKSiFPcnUXKfhY745uAsZRAx9+tgNn3jC" ..
	"In5Eb5UZSKOH+exaYJjQ1t3wVOdfcGYmO100AHbH/f2owyk4enLIpnZGGsaHNufQdnYhNNfp4508xbg0uwtD7Dgpubg9tz9Dd6cT" ..
	"JQpOcp6MZB5YgeXa8vyC2CnwSgt4vTvsT2tgTkwUYRiMmDlUYaZSY4yq5J1lkwxnJF7eg/8ahKz0Q/lFcXLCJN80e2rSYwxwIhgT" ..
	"pzWluTP7NxFGB0b80RPU8XE+qnLbP3IqQcZamuI9/m/gr5ZWbpbR33/kLmF6UnKayHPE31/QB0KNsqD8MoDYDEJdtcdEkq5NWi3u" ..
	"lDHbtLNo+uFtkbBJa7Lw8fl9PZhPhsnIajluWPek5w6D/9lJfuLCMDAzViqB+j+psiRYVEj0UIeq8WaVB7makQ9idF79EnEZV2mY" ..
	"KC189Sy/yrZi0/qhm6I+h/5a09g48WtntctSMB/5hV129CFxucpAETjcUPlZCzfiwZ7AxgsrzaVAXbkRwNaBjtExh+Im8LWNs5Jl" ..
	"dW770WhiNGf74GSO59xiz/jYQx25Ei8YAPkZRdPpHvQOpkCLfP4cWKl+hZdkMSw1SGKiwfLUaP/HsIRyVTA+QyAqI3gUlvc4KVpq" ..
	"BrzDA4L1FgnwIVEVlnXMak8PrLeI6eSu4t/AzDEFCWWWBPWHMj5mmwJzKD3JU3sOjUUe/V3kiEHqFXmVFJy9xC8WZ8lQ8zYyrDvJ" ..
	"gE6h7OAmmAzWEm0I3b11PNyIc+emfqrJEaI9CSERarXOVVMpWOqsEpXrILvazGg9JX+1QiIHo027JoOja9srcUdqGQi5RVn6Cvz9" ..
	"BMRxbUtQaJtyQX7x2qvFpI4LCQWiQic84lFvIjP1wX67w62yjRbZtWRV45gNsMTdYmbqVEaJMePX9e7MtaA9B36gbxHb+LMytaul" ..
	"4liLbYzeiYMZfKYgfUV3/TZZvJ15sgssEBVceIqJOAi0UKJidRG963VGzUNRX7poDzSUiWf9LJ058pREAkPGiquB+3vguNUaLOXx" ..
	"pGOexLVm8Q/g797KfqzvxKkB41GO6ICsB2TJT/Tgfo1ppirX/zdJXvmiwEsC2m8UQp8NBwEuz+x7P9X5Od3GXTaZRfiH190Nqzpr" ..
	"ZZDbBeoqjjulcwlmOd6oDV8RCZWWe73HSNsOmJr7l70iE80HyV+JPbUqb/c1sLPy5X0w2vR+j6trbpCmAi8IjS1xIxOcXmBjA8G8" ..
	"FQwTiO+dZ2RoU4wZvyLcL7J0q4OuMyeU0P/62weJPrpqt387glHioyFof5WEVEE0yf2qZNA4NuUVvff6nO8uuk2B4Ih7vewGqHJN" ..
	"Oen1Q2PpeBOuFCQ5bHdDgILf2h1TdZckU0CKNa3uSZKAjf7UVoZRSjz0QFsyVeAS1VRwycOUlTMD7/heUFbbNfZ7H5XtyGMpjXqh" ..
	"0Dq2ghGmXKMSJpMt0lsL9PQdzNBeEHqrTEqMGagwAt9SWDMRcjItZfKmt8Ee2sXXbt7U7d6ecPFRJPSYhN+ICRIf83ptaE2aS/ou" ..
	"jGwgKv4XDYcPV6JuFAnJXeMHUAaHbjGLqYVUU0R1WYnyeIbLjpdvCJ913CxgmsLf9sW49dxd2qO9+GEwPCapVtG+JsvJIMvmWOcM" ..
	"9wx7AZT9CCd9skXu2pqR2977l8guoUzY8D+NFXp2eB5Jx05R5LxomnjdP4JExuUO/FbSNoaLOZ4hU6UqwYTUP3gv4qi8HH3hSaP5" ..
	"8HHC61d8YEx3IHORtDcCvWTPPFYWwgexLXzSbp7OlHW3SNC+VvPhZPM2qvpkOGQqF33ZiMDrdh9WlzeDtv7u68Ibi4Mnn4bBJUxn" ..
	"1bcOB/Eye4rju6Hsh8F0+f7ItKmskYC+NyUBizk7cB77I6UeamNbZFhIltVW2iUU1tNiziii3wj7OsNBeJQgjaYJ/FLoF6JmS6zt" ..
	"YyRpR36Ts5BW/dCFzGAmpa01TsJEUeTq+UqkhGrFQ96WT0eX8nrVsXggSilj5JDNRh67zUFX40ozdNriHyabAfG0SuxUueoZhS0E" ..
	"IjCCpODwt4dPkraUiuRumhlEP6LSZdr4WnSOhFUyPGGJXA0mRJDe4kb8kEMRKCDsO4DpQ8wRBAiRG8VAXpd+s/PmSMf9i5NNFTPC" ..
	"MHlBKZnBx6+kTFFREW+6wmlV7jomGkn/21Xlk7UMPr6xVAvAQsYegnGbRHjNViUongzZ7/Qk+YAIw/IPrDvFfNt/u7LG77p+m2/7" ..
	""
local PAYLOAD_P3 =
	"I6dsWMpzLUBc7BVDqXjDRlPyHDrwScQTgIPgJS0b1BQpl8/8HIgFtcls68GUXa9KW1QKnSatF5xAsbwv6lZIX4+iOXbq74TfZORV" ..
	"tL1+2UUiFkAy67tNhlK5dfYmRrm/M0VU7XUj7xYXQhP93tiJxFdE/SnD2SY2klEp5xmptrAXVaUqSwaTQK52mcPDguMh4tdRlqBx" ..
	"XzqtXZYEvq5peZlT9HtNMcD9FWtTkW+0fhFv4gjLFUuaW9MzEIHrJnK2KbbY+xZsqwxTqZMM12mHMsKjkPQr7KNJALg+vS79gET7" ..
	"pXjjZQuL4lqL/twwB99UHgGl6MhnpXvRm7C92zVUaZHLCS8gLHrmfWJadfsFuNHkOArY8Q20WHti+i03MI3cd8Qr+4kb7iPbgGyr" ..
	"Av64isvrFm8y7ohrU6+q5+YriMMEk5aO1ulygoyUFvWZ0UBIDdJG4c2QljNUteCdcGw6TRYocw5rjMuEqrKAucZvlz5BTduEpMdA" ..
	"pFUyQ9mn9Nj1Ft4VvmMGOhIu58sdkdphoSAF/Ikn15U3RiEGKhasWEQLhSUuYPeWCW+kungM274MrZZt38KEcCVcHL8eTk1HoPaz" ..
	"bfBP8XkzqCF10tvTNS/rHW0gvtVpqTbdu1kiTK8/4FMhmx1sTKcls4pyuIE8MHgxuGjcZ7frDaQtIXKC2pMmu7zcbQNHfUa9td4v" ..
	"JcWBz1rTyZBisuOOZM5KN67RKlF1kocBYYAz1EgA+DQwXGrmjSEW7XuevVTNCONXI8ls+/kLw7y43gVS+1N+KJry6yOMq+iTDkyn" ..
	"y4NGnYQW7ICUxxnF7MqMlBBAjqpmYECg9jMjL4/usXqThX9+LYC9Fv4RkOVOXlEEhnI6agsV42MV1/2nqiIb7W4CYYGArA0KQM9o" ..
	"l8AJiBGk6ll0Yz3vPZ+WfSRDZlKMwhc7IW8s6CwEUBGz4eWvR3132AL3rotYxQ623/6vxJ1/fHhWpl7H4C/eV8l8SsmjGXB3DSWC" ..
	"sRotIP7NNK4pKfFkvKupeNX1w5dpTvFJz6ppWWLKTXrqSRfqcl73GNKYJChrQSsdZDDqbJUezMv6PXqbHhzTz4e2PaEFJv6YdmVS" ..
	"M29RJsfqxVyVYaGZk5AT6lKLpjsIR7MBeKK5Hvc8XfoGXFJqRbbYqEs/Zzd/ZR+ZGqMiiQpq9QJ0m2a2U7ViIH5Er3WEH1cruccl" ..
	"8g0gEhoum2KZRW3jeFxagoblyrPVwUwX8MdBKhWobjhvc6zP0cZdfhRah6fsYmjaSM3mjuN6T8E0mE1ReMht5J2MXzZGUojlPXHh" ..
	"h1ZxDw23uuvgM6E+cc6/TYtHDaGQIe7lYWQmohzLamujRlqeq1J7qiHMhp2OnjBtaTTA/MVVIaYN2wAjiJphQaMDpPO9vAczbARN" ..
	"wZq8xuj/Xb4Yc+Wop+EJQRst/WZeqybWjgVT851Bs3ml0et/QIFjVrG1Owiw0m4ltzE9IojiGJW9x4FW8fvEf7H8Cmp3oxIBYQiD" ..
	"EtSPm6wIU3pGdhfWWZ/NG83KnXLZ4fc6/lkel1YxNl9NkEfbthOsx9qOo5thA6HKygdWBmc4yEa3FZYT02LSWrM5BiSTtITpR9sn" ..
	"QnCHTZHWbeNfBjtbwKl2x7NJ3dSw8T1A+zKNDJ604YlXJzL1TbywhdoU+FkPR0ZRIyRWGEgKilP4/O4+Wrrxi3NKfofYeoCWxRHC" ..
	"Z7xZ2Q7o6a7Lr8P1cXwbQ32Z6fdMx+3GV/71N/dpuKpGkuZDE6dj7JwE5LIFhb671TZbRC9YNfU5vtX5SHJgj+WGPeRP2LfKHds4" ..
	"xnuyX8eOmkKyz76w914yHM/I3Y2MdtrBm1dPvT4RINZa0mm6jJ1BILXb+qBt/Pl+pFmN5b0DDHxmaKLP67S+nAnFP0eWt9JFxzks" ..
	"+BNqAq9tWYUjBE8vAdoaJML5kJMsf2FE/OE+9MRc59PcrIfZSLn9pVLWDzQrnSF6Prf+bXFz9l6nkJ6VcTKFzJ4B9gTW9gmfHuLc" ..
	"OgTlAr5+F4KLoMljG2C+P9qQ1W7SAVHGnAzuIO84Yd2Gu8sri7NmkH0W8rmuhOKu+HCEVJaK48qywojEDwKzE/3n0tB0cwrjq5BR" ..
	"0oPZ2vA0w6KFj7xwjH+5QyhGPSpO012mvGhOPsWDia1wEBh3CLMsd9kApWT3MSBMll5+FgJTpvCvCkQIoBD8HwaZQQN0wj9HSFLC" ..
	"UOVGnvOILp/szwlVF8TA6C89jz8r4N6TfaHgblt6imvyRzlO2VDrcD1HXViLWrGBWbEPxGBKLgaj6e5HhIdq+VYlMMJcj0szd+BF" ..
	"GmqD1FYl8e8Mn1Aw/KUfsaPB6/696D6U81Y5l4KbvQME+PG0Nksi8YjspOKulOV83CEpH8VceKjBE49g4FnZiKaoNBc7KZpw1SJd" ..
	"sjZC/WJWsUgQKpgV44kJgztzGzImxR2lUcW0o+Ls+f0g7B07ib1zfBji6ionGfQpepB7wAsWB8kIfMo5iv4T6Cuyvp4050NvAIfL" ..
	"+RiRKROY0oqrJYZCDfOHxL43TaSUsFZMGeIX76BMcBfKy3th6asH99uoXWIDJNL+6vITCe9GUXvQf9D8Q0eiKRaYMkkW0JmBrg8p" ..
	"HFe6yBQEYm/vA6C64zE+MBSMPXq8JIG/4KDLuJ2MMLJuw7TJnqHDSfZMpSNZYnQVB5uPaRRwp1dNv9kAst/+h6ByIF/2dJRD6J96" ..
	"UV2UHhvxcXqV0qhRmBgrskPYw4IqGypnXq4K4YKeQuTacgVXEKhmnw1onwMx4XqN7Buoi4KsgWr+1qHQc0AWgFDY2MokiK+qT5XI" ..
	"FSC1gzs9WHjJjRvtUM4tLGKY+fscCLaZFHOKBIODSsgAGF8WJU9oAVBOhf3DQN+IxtgKUvSM6L8+E5bReEgNd9bsorWyUlP3j7lx" ..
	"OSXWNaV9s/Lz0uJFJnBlVaJN/d+rNsTgGTt7QRdj0/SysVFp2QkncFN48Nr8lno+JOXk4/+J79oEXhKEcvp6lBs9TuBwBt/kWthe" ..
	"3lGVfLhPkaFbsjEwoPsHwyXkHQVM+OOrAEvFZ8yhEUEsrUw38AVebDeqbg7cFznJeFDik1uZC0IBqePNu7w6Jr9WvbC4UDKcTiSH" ..
	"qEUYzeTKLI9k+nO0ON4B2Z6yCsmeX+Ig8yO/vV80Gk7A62OLtOkejXl2Hgcikw4/a7On77soahlKBHkOzat+ddG9qSR0hKPaspnu" ..
	"4xM7JHfAlSgDYOvwLBOvNgbLpow8kjPsAHsG03ocAHi2d8sY27sXRHDylpx1dX4k7xXGBOaN6BOTivraiZWhA5IFVi79pBs+bW9l" ..
	"HOf6HEwuZUpbbhxeZnK9TACaBHQQiR9468YZR9Q1uh2hVqnbhIqZdU78fbGXMIiUBfldSc5IjGdYwoOBk/aSEIvfjSqp8fXGP4Tb" ..
	"2arm48qI8dYuO/cjZbwRdlE9y7gWW+DFckU7p5zmOagyD3ocgmGH9KDaNPUYdR4YsCqLTJxNAE5DJshR786rIsojZ9g8FzT8T7Il" ..
	"orDNxX8gzgOu3PdDxu2Q7M9AwXV4hIwpnARG5J1Wmf0jYL0YJLlL0ZVNtuX2+cS/pdNnrh56APvSk88JMmHQD3EE1a6IVY3+fhu6" ..
	"eXaAMkh7kTRJEOokEsktza0cKRrY9+uOF5cgkULs/hQAdTUkf2LvH9nnAXY3XJ9PCilBhYFim8qVsK6XpMwHLpmy/+q8EZ5E8c4X" ..
	"SP+LmttHzJYfBBjysiUXnQZIO2H62Eia+fwj6tAzucRY2dEe8f7yLWoDEywmGhDf3l9UwRzxPdxplIeo6e2zFmi173jZn6EnOMnl" ..
	"mhRl1bWbPaE9Qf943Tju6Bp07LNmBVDiMg1AfQfp/O26hgc/jz71/+S/lmauujVKHZI4S4LbaWdiN+tZwCQNhh7mZqZMB5XbDdSQ" ..
	"7vJ47KDAwEJ7SjNK+aE80LLBBqUr7aoxA4iR9BtUBygVCoXmAPKl15CuQvJt91BFBBmngW6TGZysF0vsE1AIj8lPGjxZs9rHlttr" ..
	"nprrn9s/lOKwt0ATCN3zJRF40sfrroqsPtW+c3DvNkI3w4STL8INO6DMlRq83LTCAdkPAjHwspr7mRON4wEIv8XmczuFLMnmDDBt" ..
	"nyiiUCmqOvk3QOU0FkLkhL5CUaZ3CO7aF8C7gp/CAXBsfIkGj66wsw4AxAjmuOtPTWD7EyDScRP88U0Of5vdSVpXDX/5YbGUniPz" ..
	"raYJZ9nsbbulRZqSdYFyHesHzBgLojl9yMAhTxsz0jGNNR+i0V/If2nL+zdK0m0uzkE2iqry+Gp09hP/jei/OwN80bLqTam2t7RM" ..
	"glSrhESnMOsTWLT7/V64QR9khl27m9FxiF6Df1ns1t2vZnWn9Y/xk7f2zwBAZZfzv3ll7Cq4vnIDW4XnDmeuPQBaLd69iOEK++d6" ..
	"/qBWNKpm4Pm3RlxzH+Dki7cux/zzYIVTWtdtpUUrIMORP6H4QaWnNKyjyi5zvEVQt0sUZPZocEFSDLSSt7oseBS2fLFn7S7/7KO6" ..
	"U2BGnMVlxsmqUVsmnz5yaWo3IdBFD3UJnzkyB6Ef1+d/Y3WDuzLFn0iP5tnqdcw/Ejfp5U+5+OhZPNQVzsRPYDaxHrOhHF06IEy4" ..
	"FSO2U18EwhYDpGZ/mXZENez8FxhqY0uwcwXje822tAHviPn3mki9nFlS52MZ9fPpWDQoUcenKgMoDhSbzftFRWG2tmF92iNnXUg0" ..
	"qx+K5QCvVZQ/CT7Sz6MV6eGohfeRQU37VKurcpfCB9QGcYBj0J1idHMRWwT28BhxfJSGGs7AGXk6p5Hzu1S5OnGmHoTWYDVe45cZ" ..
	"VteCUdKhWprG0ph03tF59EYP6F0pILRzAJOss/hiolbBcI0WFT/luGa/wYEtp8NpbWeOjYQzHL/thyOXAV+62JGfsoXN9Vy6VRim" ..
	"RV99KKBfqeaUtEOAFfKAt8D2GIomGWbOZNeLVcswr+ZfbhD4k2yPR6cKY5Pdx6gNXrbMHzvmp6ynpNJcmLhBWKrXA2QE88HA2jFy" ..
	"/Ie2ce07Ta/uLnZeabdz9j7ES26rmcHy0hjbypCEskP1QrFgHMSFa390kIpbqhaRILLvcTGw8sN9JNMWWS2/GFbiTrQGxYkscNB8" ..
	"NZQhtPGxIoe87b6l/fw1KT8+lHlpIEwJ7lCV3jMFbz5uFV6tlEwjn7CauH4LZubQJNt07+yt2ZNTXnlIAEu6p7Liy4Uyo2THw18a" ..
	"1JPMEtj/iesySttQUnK59MfR2mG973NiiT4sKyn/Wx8FU5u00Q2lZ7QRfdT35IaGQefMVTfg9JLkHKCYS8RLgS9RyUH7QHojStQU" ..
	"87GlvTJSAEACfGzR0fBhPQpPeP2YCZA8l/mckuW7DvGsG6qhr+NhjwS85BVVDadTjrOooBgNZYJcUtVC6S1s1jKNkYL0j3QKssjk" ..
	"OFqPtlLsJsejFLyWnEU5ZLmKRdoPoP3AN3ajgwQuJ3j0TPFmwCqiMjDvIUvyy+MKMMNCPGenhNAOJF1zBBtkvmlOhRmch2rlQy2B" ..
	"MalWOZCUO6NQpTVsA9LzUqT4ETuxhGj5UfNmfV2Vq/Tu6PGdq45IvJow5YMmKIUp41Bnvfzr+9etbL20YZCg6ckrzijb92Sh9Gox" ..
	"iPKyn+vQrSB4qU66ukEZfrJW7WwjvukpjHUG152tOuyJ98n07Ru/Ljk2Rq8Q45J//Wknwk/2sxDPkb82Qj4av66ZAQ+zkM+qZ0D5" ..
	"l+BZY8OaE+GAHLicWYo+txmYROH0epTj5+QzGPeaAPav3JW1RAezDNvAy09LHeeqNvzz3L/OItfOfGqudtxuki+Q4Xwx2+mvPoRP" ..
	"Ziv4rnF7De1ou4JmmhvquL1hcPBpUt9YpskRw1vhAbxDNAK+1IvFJKjvMKULBFvc9P5USUNZwFRwQ4PjifB+9VbCsRBuXAKerEfM" ..
	"Xfg66kW0d7Sswlpve1+xaj78vb2SGcW87h1w4H+GAFp+DiZnwr9pdaVYIejUjCDqh13bKgvLgi58RPFy1jco2Irm8EOfQHlgNVWN" ..
	""
local PAYLOAD_P4 =
	"sJGZzXJroWt6XtJJD8L/FwPMbzZUeNMmVDcTSIoDXzgL16rlxXj6yR66MUDxlP9868LwLpXwoKp8vO7eOrG6KeDKyrq8NTE4Ltz8" ..
	"qsCKPTkC9Dk8E7H8u7gdjLS7wOVUfA1aT8LhEN6xXnYfYtGBnRP2xt7+F0k6U1Lt9w/FWRaVB+GzTZ8AmIZv0Rc1zJI/57FT4r2k" ..
	"LHuiyM0rzVQKyFJ4BnET300vIpVlDG76R5hjQOz7jE5WRNkug4jayBMmn+r+RZ/eURgtxin3vx3mJds77Gtp0NdKlBBV7WIaPS2l" ..
	"1cEujJRp1s1b1hAP2i90HnpEMQwWaH796+bxoo9t6Y+DL6PlA2JZFwI53Hc5Swtxyl+fcU7WeQLfeOcO+UKombA1tH1QR5ijKt1p" ..
	"7kKZBKM8+LdahNXwMNWpYrJa8ifpHCUThkfM2PWKOulbpS0YlvHe+9jm5C8liDdmktJTm23CeVDs4i62PjNjoe0Rok2ICIOQefSs" ..
	"FxoYgbrQNkQRd+HFAs1PTcniDxWGDExDI8nBrLlnvwE50y/IK4dEGL8xQdVz5HHxZwVG7ZYDAaoOOFxZzrs1xPFfzLz3wJhZRn5V" ..
	"ZL8LMyb9E/QPA5MUZTCfl8UMNChlX6PcOUW2PKOJs9lLGM4W74nr+G5BK70ouk+ZnP5MLzlQ7cTRqxU8Rg3Dr4E6W1cnXZ1YNlSg" ..
	"EYeooBbmgoBPvPL36HV8OqKIbHbRlg108lhbahRSf4+UW3j5okGzQONELs5/WXacZV7tz1CbLQ/EjtxjZMxDOFE2cH0xyER8etc8" ..
	"RTiiogBeQv7nSzVzqf6GJNWdz6LBPQ5udSRjJ4JPEiD6uVGi3vJqXhAlvTd06VYTx90smKf9XNrLe66SC7CPJN5AHxKqOTI58VXn" ..
	"x6IjLzq9uDmhB2b7s0jiEJp9xi2mmRQHqetLzfqXgNTaW1/MFwfjGUBGEQgN3fIf6kRs/n7CceEqL0MsCL9Q09XURoQzoc+T/hV5" ..
	"09H6j6nQIyw9XrHILgjqJjVfc6A8gF63fSLWqSYKUqo4Hrjj4wUinFbkI60qDuM3TGsEZpkd7rqtxd9B2OFsyv/qiArCfaJxwwOs" ..
	"OOVl6779JI7gTx0i3tap5YqLB51PAVOmjpkezaoira2rgujLjN+I74gxEQpGxlFk7JDHNDuTOvEOWU3ZbPit7+jJN7S1LXq6mdu8" ..
	"0kYUa5M6f9cOmJzj4EG9SAmz9bwbEwN4q4XejoRgg/1URbeoUz+tEWSsMqt/Fskm0x7V1YOQP4fXsYtN4V5jRt7x1dVraO4MjmzU" ..
	"edy+Kze1U1elIvDgGBZBLNvdIk8RFlwvDPkqLFo8Ntf188yyUur4ZfdZXaWnAZMVjNXeKoaCRz5YswFiNgZmcoTm/V79u7+xEo4N" ..
	"1+LKbktEXO4I/DDjPP5nZYBcTqjoT4OOUQ5pJByOkXefEQEYSX2SNbVk/ui34qAZ46sAhGM5TRU+HSelRtYoRe6G+2+ZtPCI0FjG" ..
	"LKgTxr6SDJkefFrvlYhPkX9FpjmQj/X4gHlfHdh1JJl5tZBcrGhhEse54WiWG25xgm9xv2GhnayL9/85CkY5CJIIpmZRfR1qgkii" ..
	"/gJusWlaPkd1jJgsg4gy7RdIWFikCednGSJZ3bVwgLtKSRWdvFZEDLGRtChJABgfndvkhFGXxJuy99mCZTNNSrkI+SL/NT6eyRwc" ..
	"bZORtMODPBpTNrtNGEbD+OT4L1FkeEl0AknrfF5cPCXOULN1Cd8UG5QMfqAXX8ryx8Q+4iH7sD/SBQ2x4p4ZXnWGKCAdBWRh0OQF" ..
	"AQXWN7rGn4R58jd75HQvLTqa7f0DtuWH2MklmO+Gk2YplE5PSUC09Ptsy9WRG07vcsId53uff6tjbSLM1EQcwfBRRSw4ww9v7G3n" ..
	"y+G6RMtpkKZGPyBKvxcbMOjRhtkIJaFUCWi2G79o/aXpWexJOOeZi3kr/AZV71HENsflCNYGYS26vGH9/2xhPwbEyxblIjZ3ffm4" ..
	"fMD3KaA9wPaE5AlH33noOy1WUOvUGl+iEdNTzheE9+2rf7lSb6ge63XAVgFEUbBrjKdL8Q8uPvTApq0k71mGDLrf7g8NuwtdBEZY" ..
	"LnlZWeYwdSwe3qQvzdYSzGh/1l0+UxZoRqbeS5mV4EXroSHHpAhsUASY5Xip4OPuqliMKzqWZIU3uibJGejXERBH3y2RqGTY4K0M" ..
	"tBJZekkQTOoUP4tFWjDvjp/rtg6b3KZRpXBoHihfYpn+EOYz1VBI/aaLDQMWSu8JlZ3reKyWPoHPhjhpM3D06ojTg/0K6eXgrtaA" ..
	"NjOcHYojTge+TkkihzGxNMCcw4qso7cdpvEYrOVt7lZbeE6zmEBOuLaTi82hlFjFUvQ/Hqn0P7wFqZ2qOd3VWrKqeZoyplAc4tXN" ..
	"GxWnCJLwdMJmuJU+vI8ZspWDzPJMUsHNx3zO/NN5LLjPkwK/UgpfEQhlhKbPTEKztEYES44714Hsh90s5rKsO0rafzlfprStK43Q" ..
	"FbqQ97rskEbdhK3XkTUBkAKgl3mTx7SqvjkDxdtcofwiQZFy3D/tO7AQbi0SGtgXkH36iyNm5PrAQjUYeUKGC3VVY3lWt6nEahB5" ..
	"hADySTohi/9JrYhUFmSeAPMAOpPqg0UBJlV85q+FmSeJX6mM3spq5T7z8PnCB9H7O6NTPpQhwOQHV66zUdFJJhG2F5NwtmIRq1nG" ..
	"qvDjZQlslRzMBy7y1pv4a/ftpi2JNjl6KY7QtWNs0Gk7XWQBwJg3yW4SMHz3m3EMtQKSc2xA3xMOPe+Dnr/bGp8bdeFctb/YujXV" ..
	"iNYaAQyGw4z0hpXmMVyqMC0RD/+SzRBbj2hx5KdEFFzcZLZhekrIhx5uuj60hrhK/vLG2Wu2gXILG04Mm3j4Zbq1c9JfjOg7LvGy" ..
	"TwroqbRIhTaEIifxmB/+P130uOH/pcUy+mcBWU3uLJ2vtj1sTjWu7p2pOQ6loj/+lA4y8Xj/iQv84wllxN1D0WT5wJl+SzQAlZKc" ..
	"I4ipVP+RpI0d2f0t1H+wDsWyjV28JI+oVkjU0WrwjY5ruAa7iTFVndayPitj9pT9hmlYa+jKJFj7n9hlbYVtW6FmKb+oumDxx4N3" ..
	"/zwn8LLotz2ZBnsrKDeNAIQQlTg0VAGMlfzOlCBbIoNsNpVEwmhb417/kJgF7irSiJbPSzeaG0BBqKfM59XjkYd2znEvu9tFUUZ1" ..
	"qjbA2jMxmd346jl0jGkznaipCPRk/YM9CGOxmxFpQj7bEsoosaBqfYoox/b3j0DSswQU4wqZZ0E5OY75yi148makYWbSNLlHLQhh" ..
	"VyMZxzNpNxupa1b08XANAS96GBKRnNr9FgUlQfDIlxAgyXBYwRZ3i/o5wfXeFPfmUxvs3WxFqXslRNoZoz3/WhzEV+P6rtBTnaly" ..
	"GdCeOrha6Dm9Ljd8l3m4pAyhxqLryLgxw9uSCD7+qQg2zc/g19Y6mokk6mXHrSvzKWO795ZTUdvC0CI8kOmcJbwOWDM/VB9pyYkx" ..
	"qWIgbwk8YN7Psw1VAVjIBfJ3ju885LxihPwe/HUNqZFUH5rqU+U+hcfkwqjDcWbsPgBEdihmX0nLMRDc/RF++yaui383kyIl5KiX" ..
	"0TfZR0wy5G+2DRq4lSR5Xom0Pt89hAn6PZvTVAA3gfaVjW4qQr54BbKDu/mRyFQWeAHe+jmuWTWJvPilGeyAKfmSOuaacz1r8u6o" ..
	"Vs8TFi7oDozykVZRNQtzPPcM6x/UmU41yDdfnSHhdRZlWxzO5YMmts2VPVoLpOOYeOy+SLqc0lpmbB0fz0o40rUjvpT/G6PItFU5" ..
	"h0UxjHzz4SJ1PGOOUe1slolMWRGFevRjX/GBICkDgmZgTw2eyFux8qOQtpA6uxYqSxkg6Lkvz9n7dXUZmeH6c0/vWWGUHWzJw0QX" ..
	"pugsw8xgQwojNAxxhijZ2bVsvph4bqvOYsSuVFmidBDHDyC2ZyT7PBbXEXqPt/cXSdhfle2lGnx3V5FG3Rl23ljJSxDAwjCUuNGU" ..
	"2/KmmOcbPmaIJe571ZhUnMswZsgP36cPva2F6R/T4WpN69rojcxcu6wHvcN+1ZxTjtbQHeGemGx+/chmUVDnkDQViFELJYTfs7TD" ..
	"n63xxfCcCQuvnZVl4iB2h40nVV9RMOeFpt88a0BlkcxhNrsOZTc55+isfjU2MkzzLg4H3K8fKW/6GRMZQjvHQw4/EHnO8bO2qrLL" ..
	"bfroDcP5nxLQq7JVmOBWmtwze3N5eWu6Nbvb5Q8peZfxbC3IxahMeocW3Pt0fcTSn4aDPkL/jFavGPv8Xb2sSDfhTuQDyGV/QCeX" ..
	"RAgobGKJ2hdtc/DCo9tL3TfmsvalCpLRHP2BLj33McJLFQ+GWRq9vcxdh3kzgn6xm4fddi9gaSfG6j/XxtRaImvXmRHCJYel/oI3" ..
	"dK+v7fgHIrvNOngmN0shzPmnjLB7muXHl9Gittro1WbXbxH9Q13B0c/dT8PWVo77g1ydB8lwIjLNWIJy3703sNOgDD8j70/7k82g" ..
	"k9EA3YV5cX7w6R9aFPiTf1QUgyowNntFPFbLyLQ2RKYeE/6y+WNAIYWYw/kz2peARbVHMupesUZN5nf9KMddSbNUO5WijDFUoWNS" ..
	"fc9r3NuAxus2mRZuwacXMwK3ISmdWl7fokyDiLe4x0to6aHbfdufDDl2ynJPILNa7/pavdvh2Iq+zPf+p3gKfBDebejWxEwwEvPm" ..
	"nHOnbKCFcH0enh2CzWI1V06fJxcSizrS3dOMjESZZNY1h5tq6zGU5FgVmAyvQf0XjoYbQqFHdqUZvYDNxz7RunjbrEoWoqZGqcHj" ..
	"l3dLoPaw7BCn40jXs1eGasH1W5UJ/vWmx/hKP95bEqWdYFNwjWtUD61dNnxW+soo3tbqisaUzoEM12gL7mE6kqFjS0ZrHS4Sw9KT" ..
	"GE84MmtjZjwMsVhgnHcF424ZOwm3nluNgU6T2PHcvnF08dxi0T9PpYfLgq2k1EEmFQ+6K9UsvPiR9AaNl2RLCKRcEddyPF31VgC1" ..
	"rEOlo+mG1g+w5WKGUO45DANgfm5sZ/A3uvxTvayWKEP34i54sM02USyei8cxKhjvi4V2h7IGyZNevTeC1eL1tk2hXbEmw/5HiHCQ" ..
	"fLuNSmcZxwnq/RfS+qS27p98r0dkB63AkFPmE5v+Rw2PxR7G/sy1x1EY0iQMWpDAuOKR/IMNixOzbH76rANH8Qod416SKEGcOYKK" ..
	"ngXHq+RklVHasLzzeX3ZoracrQLqS2BaxYPjreyn9atslcf4NHblIGWoXfSUMI3jcF/PpxhZY1mKdFTPAJJ+tHOI2G/7jg6AMBVm" ..
	"LEI/chVFP95d7Lx2maVqNJzhXvEpbpFF0odPvk2SMOKSm4GFpIXzuRmOH8sr3jfn5UvGbZdPnoTSY6NuGshDKaw7GPV1F3Mq7GcT" ..
	"swvAlP2mIQyI8HPzyZpZHymTaHEijMSayc+GBoH+BVoEAuAyrd56olFVfRlLcUD3kgklG5HA/b4wrXa+qeFG8dtue2TghCHVQYUa" ..
	"VquCVIAsmcDbsrqAXXHKvW2k2EG/YbW9htx+d9ttcI2Z586v7JVm4a4lrZ97Ke7FHQxHZFywq3HLKX+73FTndEl+tQrtsDUD/IyT" ..
	"l7au8kW8nyijaqUAeoDcKnCAr4eG6nimgchvfj8GzZcrHqTET98lPJw+eOt90FGsL3cd1KooVhlpZb0m+NcpYcLlwihP9ZfTS1Xg" ..
	"Zw1bL4/yro67wMl2/UT9jFe3QyxmKPnOzEF5vSyIl8PRQjZMiPhQc+iBH7pjiNQVuG292gCDgeO5lmtq9oEYXBnhuTPFJ2KPyW4s" ..
	"AxkkQSU8kJEoQGSDw5g3mHCG2k6fPDySs4EnyrG2Yy71Cgov3sUQYRCZ27f9KI+O9a1QZ2ZvNgDAsBgqKLGaA7LQ32J82Wv6acID" ..
	"Q6IhjqdXabet4ryQpBDc25Vbp0W7K1Fpigo0cm2S0f/4lUV+MyluzZ12LjmRCSExNkLc6UQjEyzDI1DJmIhJ7hnArjmwdm+f2yrK" ..
	""
local PAYLOAD_P5 =
	"rEXS0+J9jz8J/k/n/hXYp/d4EHex1d1pHHeIrJ0aTSj8v/McH0bLrgowGAM8b9YghM7eR7jrYMf0K4rxlnkf+Nifm0RTKo0UM0sT" ..
	"SOa3G8AhpoflOV6t0mmQTai4knHgSbnt8DQZJpjiDmnwYiD7s1a3hoXLP0Yw9t61MieMv4htfyCHKMHTDx96XQCJkZDuqjnuHS7T" ..
	"HHzm+QKBp3NwJJx+fKiVJfOGPayI09cdIgNxcTPsBzJWN9vDmdr3ZSTtd6xnfsT1AVRhjOWXkt637uYKxQjZSoD8s4zsa2YxS4eQ" ..
	"mde3b/qsBoBV1wggZllyJgiRR+4mmENy1jplg/LdqHPzGzpWRoqOi203VunR/uK2dGBG3gGBRSbt3XzJD15PeElw8babDO4wnJ4i" ..
	"QpwI1AceXvpTrJeYDAK479dem91qIjGK8ozC5+fSXxLhrXHaTuhQs+DCCCM/pcRbto5+95ff21qYhK1nSsfrLfnC//5YZa9Rrb0K" ..
	"mWPokAaqLIBVPwtbbqolet7rokzrr65CcYWP4uOGNAnHVUMMgp7Jvsy8jYofqX1nqB6Nw2ld8QR/GjgybYgFfbxNhIQrY6Me7aoI" ..
	"6vvSfFUDOyhIUClG7eqg25Tz8BNhzHZnyweX8Xe1hfx/uyqiOtFjNqCtCL2qm9vXGc0Mp2kQpTGyeKnBJ4I+grw9+XI5i7+I1ASk" ..
	"e3HHlpB+qmkKre4qCsa2Ypyn3wn5vZ6BWOr+uaO2rfKxOPxbXTiUSrB/YtQhGDiZeolImTunrE/R2/5HwcgvVQwPzmLRXHcv+vfT" ..
	"AacplGAERCkw7KlLz3x3rfMgxHbSeoXU+HZFY60t9BZ2+RYwsgWsJ8HrjotZV3Pi1ZWM7gpX3Ar87TMxMXCV5XaOHKDxvRQ1UfP3" ..
	"lAHZpVv8yVK43Ya2Gr4LpbPUrm5LRJyg+cE1/l7HV/ET9Yf1yB00bsDixefoXB2hMng1nKoZ/fwqh2KHH8kYJncXogErWG8uqBXM" ..
	"WpJpNZH6MU0krEwGiAHV7SMbeBIa45wzM6d7LSK1MeAeNFkLVG0QrHeXtYgSfNvVwKmOSONrZCtSEXaubfOPdFokXTtP4arVfQ3k" ..
	"pT/xTW78gYOWv45mi/Ig36OtNODXbQzdRBtwI4UYFFzUTQxxyyyLKkNrEWJRFXXCHKH9JBJvS52ABh9x0AB2BOkwaG90YQByuoQL" ..
	"tiAf++xCydszMjpfyNanDuOSz4YcdjcIy1XE5DVg50lFWcen7E6IHGqVhayX34uY6XwFCPrVZqNgJGes2YsGCBbqdDrSG6+pokFN" ..
	"m2snL+T4w/pNn7ntfoFS8Pq/pb3EVKkQ73svBxLsPma9zTh721Jt6LiRl409pyZoKdQKw8W6zySqoZj0PYypzSS1nmcg8lhnoRo/" ..
	"ffVuklqr1GMPBlV/BfH86820vEMEHTsuw6yEKf5LppIj1Aztk8TdW3DMyXd/RcBsFSeiyFwpwNuX7IslTiWPlCYd4QJLawNkb7K8" ..
	"uFhkcNcqJLe9AV6fTQ6+a5pCmkD8YAEy//HJSI0jQGGa9gO+VaHq6fFJB1LS0Q+0FIVXG1rz4jrQ6gQVTOCKZWlRovHkaYzdyqe/" ..
	"aVoOIFJn+WuTYdoSnl/F4/O6XbKc4XlIhgBQYmeRec21TVv4H1Vi6XLwJozlqwhSr38hbqNiEeMoqgse4MkaZfDYQqqIBwfhaHFi" ..
	"ejsh87v1dZOJGqHHnHjiS+sTBg1eTUOipKCrijvgXxPF3V1Kj/EvTrPIPqFUwbaIm8gmz/ZAtv383zJ45ThdSYwJFiqW2NYH0PSF" ..
	"ApaZvAeNT4igvbOSbFF0fOkwijE3Z6E3T6qLw6StxE1UAeAEiSHSm7irZpK8wkvmkru5gaqqoyaRdCB2OJ4eCULNtLPMhJXUoiW6" ..
	"1qS5sqEMDXxB0rsVFhi0Z5IVixLeHKtyWJv4hkDQNfhXjds4ha/adW42cCah6sLelWAt0Afr0BFLeGc2asmri7hiye3eadRFyqKC" ..
	"GQRPatYWlc/sdyrINzcWd8JEtSMxAmy8uaYOLzMi35kSJglErQi57zSiSGCE+j4XHoeHI5uvpIYvRnEEAioOSNorrvuPFx4IRh+D" ..
	"61tjNX4bH4T/gyKZTx20oi9ackqZaRo1VNFpmvcIPpQZ183B0iTZaL1PO+bd4vfNRj5uDT71u7r8qS92c0MdCPm21XZMP1YL6FVD" ..
	"HG4sc2ORj0iGccIqxhbSoodl7674t6irySyCZnQp7Q58xYgi8MKUr24K5zjmFsina+ADBWGZDBdy8WFhD9E+KkYXtbNcm6azJSv2" ..
	"5cm0EZ9XnFHGDJl9Tl+PumiRoB1NwfD1H+WCCQDJMIuhQEvC1qw2BBf5OypDuTpNeyadtZkn2Ikx5d22Zs4eDcUYXWT7hbK/dR83" ..
	"+5X1H7IoRNcaEzS2pfKTD8ZWUjKbYXwhQHoYogHjCzD/HFeTVCxOCBYOqIbsexb+gV4bQMqj70epCuDOsOTAwEmmj1YsT2zC7Ogr" ..
	"nJzbNikwZFCtd4JVdAKAkL5uLdb/DrttG1aoGVmXpqdVaAFTW9gPT1Hh3p+ZPlZW/4+UZdfCDyANnR9KXGGsnRYpjAH5prJP6NKz" ..
	"qonofSV77QAAe3MTQ73rihPuhjv6QvO4jyLdN0j5Et7DiLku6SI9QTZlkgJkISyH5uSwrmYka0WsleTskYscqMBsScQ/d4woerfF" ..
	"/T+q9dAcFGpF0dj6P3kaLww3cz91p8EU1G9XKq17CI3VkgqzoKswM0y8DBJ52NEuPpMRC/0eHeEz4I7Z19blW/MEveYVIMroKuGh" ..
	"cto0JMtuwrKWVbR5qGr6R9bSx5acQmOrpgO67pRtH1JH7jFRA2OgEN4ZHy2HOZhGO3DD8CXgEj840CMESm6jBthcpIpI8A0Y8XP0" ..
	"n8FoArnzAFHSHe0NLgEzVCkulax+LvBpq/m63H5Z8vag+5im8i4IqO7zlr/XPZTvcUJroStUXx8GisMUl5NBAZKUCP1inQMVf/n9" ..
	"RNlGcbZ/ZUHgrZ98PSybYtBsW9awAHq+rzZSEM1pPgdP3ugWnK2b/G8tlm+8TF4Vi91oGbJi4JAZdcnkaFDBFLlGfIU/n0Kr7nVP" ..
	"+OIPcqS4PJWHFJbVRTcB3G14TPzH4M1m+1KCbfeYbEmmDCM4r3+TOGkQmjQ+El6317K9hNKuVeDbrLjoYC6x+7K/0zUS+e57WzAj" ..
	"ctAd7yqXRKAWj4vakvjwksZxwXnJfzFkCQG5ONjSjWNr3kdRX31UXhmzORr8ryWFL8hDVWYXKr6STva2IDmlGpszfuXCtiAgWc7k" ..
	"c7dV+Hxhz0xjDn9nJezHFjYjVA3BJfr6xklgn0TxIkvs5/T1Fs+eMpZ5yekVMXsThlmdsaa1viaBZh1S92qmIFYvQE9PbX2RzT9+" ..
	"c8ITa/qiAtYhg2phEzy48Y+RLDQxvofJkVOcF3z162GMCp56vl6SPz+sWtjSMPlVjcVauKnLH9drYQPM7f0jjE8nehg941kvU8J7" ..
	"W6E+Fn/OMCm6KKhFomNdUVaX778ZsYRtbpDmq667qt4bIqbGcsr8fCldTKVOwL60kumdbxnd2EYGJ1y8utlBuiv0ZLUefBc2Hofp" ..
	"jVxBJIKp+hZ4h+5VaneEbTM2Nr5Zi3K2soyRbpt0lAV4090E4IdSmKxDE3Vf0YswbNfB4MS4+ev5I2oCD4KYdhbOBKYVpwOpVb5I" ..
	"I8uuSE2oZXseQZwL4cPNf+r9etHkdAGZO5o5KD9pUaBAmnVdlihJtX3Ez1WnPvsBq1f63boc7QalSpSBmGhBIII6Di98RZTmqFFV" ..
	"NfmDBVZgjCz8tAs/EIBozJGKrqr58ZF6Adc3fDQpf/gsfmIkdXqa4mrYAXWDLFBlWqShEABkY5UmVXM0nz4dpkopOPt50tEFoCRA" ..
	"qP0QIIuIdTVzVBFw+N8U7KXqOCHdumCql56KECdwZtlxrLyoWtP2hTsSrTpZR9LShnWDW4HZtnt0dJCzVyLFC4iRsEc1m1s5SW7I" ..
	"G7Qbbnh31ruQKkZYjGvPsbsETFqs8oxcHKjSosMRkx/J3r9V2q8pbPWJgzTN2W/Oa9i4qXXQ+Ak3ALAuu1otZO7UIFKzbzK6/ZrK" ..
	"djUjqOTMb+pWGxvjTgkjMNDoNoZozYbP4RZOfOeRM7HlpfkTX1jWQIRcEXWZoZA5vAROUBXSA2G8IKGCj/rdqy63IcDdqBzrLyae" ..
	"51EQcKRpRL2P5a6YGSYGLiSBjDfOcHn6NGNeYrl5vKjfOZbzGx86JxcQq/1KMnkSuOAkxHRQQT/lGkoqfugnCGeehVLyAfYJ50ax" ..
	"elhvEkwO2grwrL3IHgOXbFeX1H8b+djchg1qrmJ/TtPREW9Y5qHAWoUwtGX+i25eycyJlAX7ypegqZQSOejfsBEyTPSuLoB8CIPy" ..
	"ARMZG8S2m4oHeiA4noIVTXlvQSWbRvpnf7+gQlvJR2UvLjAOiMqiOoUDOy070wRCeXOjfCAyCC6vdm+ph6RExitDfwuCMaBoP52R" ..
	"VWe6LAffo5G++rKK+i93ESGE/RbY+7XYiRdUBa+kuWYcN1rWKTgx0F2cu0yyuobuhpgSfYhilciEyCuT8ZuksZs7hhcWVIA1KXbo" ..
	"GwszF3wMaT4YCFRe8SVfoneHC/SPacIx8gVwrQKbNj17RBGCnC3AqjQtMMCVuO6Q7zlNKNerYAkH1QuHmnxPc6niYGY8Mf/fKeR0" ..
	"/uL52wvGLqzzNc9U5bhbQJKpRnjr01vIMTz0PqhfGRNmSPgHJw/4IvqE2nWE8ktaQfy4QDmaNQb74tpWjA5lOsrRVzksyidD9N8F" ..
	"+FRK9FrFLsibVdf4mlN7HwTKKeUvRjOE06ZVGCz2lwuJu+vlgUZO9sY2SSf9xM2hgDVh3s3pgohgE9sDITD69jE4yDR5p/qe3eBl" ..
	"5iZ5Y6+2getKkfhAlnRl4pNR0JwZl0YGPKmtUwkUJzfV1K16OC69u3J1SiPnEDzvOjDFA6JnDL3zu+gP0ja4MREcCsh0Ozcmz+ny" ..
	"OwrguN9J9TQ1lpNu31giw+fOsmB1HNZHTzjd1g2JDauNGiUkd9ewgaVQuaVSv+Z6iP3EjYaPe9bvqyQqS3gRG/gawz9BoeMlh8GG" ..
	"RL+yheLTr8g+PZIpUpMpoucHhA3gU/GHXchelCpbzHUkLaqV679QSBXEhvD1mXWbGbrKY+51e2gSdkXRmw/prsYnIhN3mUCD7GCX" ..
	"jWkKJpPRPcd8d5uEk1KCFToRM+OqAOplBACTMqEKMrYnthTbc+S5azVzYJtgiRYyx8ZX1OUqlcRerCjJCLsAkHw1AW39qv+WErl+" ..
	"LmG/pvbycslkbwF1vPFd1SkZ0yxj8ZDnvcL3gMEi8pnEhGb5YC0CxgEyLySLVBrqR/rZKZKwJLC/NuiPVRYtdk0Dc3RC8CRnkfHC" ..
	"lkRj9EQ8XHV3gBExMn8ddzxqF++Kk4DWjCZ8xWWyCb/IrCRg1tzPLVq/qnFQCTJhhwCmqcUsF43wZjs55kpMSjInD7pCtlrbQcPM" ..
	"WsdRKgCzm4981CHNn7fP8n2vlsG/ckjgtQLXb4CmdUsISqXwiACvr0ceHAlQLIp3huMNHcwnl5KtvcWv9UYnURB1eXTJ7dwaUNnM" ..
	"uXnjf3v4Pfmv7pKrPSQlcR9SZLxiJ5w6p6+YoEjhtDqSHoDF+p9OC34sliu7AFyisVo5z9/EHKMlLcpN07gwUqkjNNTFqlc0a7Sz" ..
	"j/2jWEFoHSE4UJVmLM5F7qHuKLsgszBHrqcDk0D2RfqBfLf9aMaRRnd5Wdnrbp3vALFvqtEdn0U7TRdIUuaTSrrGjBzCgAn/04Dg" ..
	"AaYnXPpQhqeHcSx6CnIZXlxEcklz5aUr2UZiHOXX20NaWIpzm9E7ahxV4hEuuGnGHFghlAduj7pf//C78BW1v0VZUCD+EqtaeQTT" ..
	"nEPgpqHGq9X0C8JtPNtE7Ohc0g6L73nOAOXlSjrITqM9pmPh4f7EJK/o58ME+xdg0KVDPS6B/XZtEmdVGAZLOmKIaLbP+Coxytl5" ..
	""
local PAYLOAD_P6 =
	"TDrIVAF8Ki8wEJ763sw1bhoI0RqlDeN0LiBg2jMyIOQ1X3cFHObuqzYkn6hvOzxZj6XaviBdSiFqOJG71J+YdV/qKnTBHpv3/Cjk" ..
	"RjKv5jUmXBGPiPm2MHrxIHEN79iZqeX4Lg10I+PNbygQQsvOy7ccirAv8OIlqY31wm8dWcQl08VvY2ni7xMoDAsQ7mSR7wu6HX+Q" ..
	"xZ4OhUYL8s1RlIaD7DnItjRgHXtMj39lipWtz/fK2oWOn+PmqkppwO6Rdoc5yuwhA28RwdkwPTJy+eAJR0Ad2LnAPfSWQj4wwUKu" ..
	"0e1k2yNA0a8oHlDtvd3GVsYPF9vNxCZuXytr8QrKGJEYGZfR1d3jfPn7m3H6Qm65ekHjDZz4V/cI9pVTfAlSqkOLm5Eg/GfRc4yb" ..
	"GDjDLcoYQpCAk4z1Hsw+ja6GsN9nS63lr4NadDLyrOuIzm4xjl4lWUe0Mqwnooac+vX3BUDGjsRl5l3pU4eTd+AmOAL0uLZo99rx" ..
	"LWu3SQgiWVrmiyt+PP5TGM/IAg6jnZWYvJgvYROQHRAUDwXkeYyLYUQsajxJHFtTzNl17NP2JW9InsextYvloOZj7lWF4iEEIZEr" ..
	"pLj/CRaBzHhVNsVYXK5KNASg3UvSGnGltwWI/P2DFcO+ZDHVzNQU0WPXSNUgo6THajo8H5DPixuAoGcrBv1C4zSBdBQxnrtcJXFm" ..
	"inwIhoqO5wB8WxsIaS1KgnF3tI31HYiWvkt74xQ0E0RO1EFVNhYzzOLlgOmjDq/5K8mufXbkLhPlaT258WHVBw9+IAVuhaqW+KID" ..
	"zx6EchoG8Qmjo5XRUUFJ9ykqS00YX7inMK+pRmOsPHl4ikM3Y7XwFJ0Wff/YkIXEV9NWyTkU1p1LJQOKZoW9DCQXkx8nEnVpci1P" ..
	"gn+RUa6gox3omqjzUQkZXAdN93SSg2qm5do95g6wbmogMmZmxG2QU9AU41NnhsVkWYzwTzdl1K5lwMGOf9k062T5VCfo0ZTy6bqM" ..
	"iDm5y7EDpqLppPnaOPpskmm4pI2qwND1giE2Oc2hWLm5bM2okRU5S0/OYKbCyn0SitypFMpYFBKYhGjSbqIcRMrJzJaNXDYKlb3m" ..
	"cUbEH7JR5jWB0aRfkqmNwNEV1JcoLaBAqzwkf/qw1d1UH8fGGAqIP6O5/9QHTPhDKdJRs+gh/j+vgsQaMRxwvmURsaWPPO6gWWgQ" ..
	"qJUbsIIi7tPh9M7/lD3nj0bObdhET2pNISdtXNTHVyKn2uvzoh3YsjAfO+d2WGVKcuUN7iStNIy+BBQR9JJ60oi/9oNhE2oB18pG" ..
	"0ux0zFDeYwzZmyF8HyccrK2WJsN1hyENXZWKeR+V2pk6xd1v/TdhKMmuF1FilzuZ9IY9MYiLYMEf2eYDyGsqQ5urha2qIS8eSpHF" ..
	"Inv0mLEb/g7k0LNoCQL1tHp6JO+IGalm+SeEqYC1S6upXwKuii8U/dOM/78brb/MCd/mKxNHQ+GHdfGjlOEh9ErYj2nRgDfaAOej" ..
	"Su64Qn28fo1MRmdFrOVNdlh4ZQjrX5eouky8qEGuHnzWGGqHBlV6IJ+K+XHBDvQ+GTI1jFzyHKYrBoejb1pl95bXKdJjZ8eiuCt7" ..
	"gsyUdXDHA3q331BkcwIv7peZ3f1mOq/7rH1C3lic0zsvGKoX8uZzZm4oIsZ7v8ppWKHoILyCCXcJf4xHe9/jHu7bs+iBaNzJD4yt" ..
	"QLnld1QbaGP7mQ/2bPrmhPlfXsEnauH2Crli+OlzPqyj9KKDmQlQPeKdRtFZ5k1Ndnm2kwbypastazzfKqFCuvDQkzSZLsRN5NUH" ..
	"WXPC+RH3Plp870nK2yAqGnZXXZQUbzIszYeZCjzuuCNzLXSPvwccxqCOj5M+bgWv+1+4FflyC5FW71gYVol8kc23L9MHWH/1gDu6" ..
	"MIYgXFJM7QSsQYs8ZEg/e9NBOihcEeMJUZyl8qqopn5yJ8Ti40/VJ4a5r0bOhD0Ob1+lIeIDSXJUNLuG/ImksqFYrqc42zq2yqWM" ..
	"5yIv0Q9aETYt3xpDgXGJYmYRXAp/XZLMBULYUuoGlvFzDkhGl2ZXIzEaW6ffo/Zkc12/EarkR9CXAqkF5aW1R6mDn+ZRegwm+qmm" ..
	"loIqziKizUspEij8VvdKcZjvzVSOmGujGrMhgURLXjd8EMzrf7mY6su54+vjT+XNIXMI7rQsjCeM6QhvwNYvOdcsnt8ZF4bKAcH0" ..
	"0scITYjWt/c2YDIyL8v3h3jWaY0ywFanAkIBVI0it5RCJl3gd/lBMXX7l9rfVwSBThwE55XPhBzVqB8iwDUjHsiKETxOtNsIB+AW" ..
	"wYbyHowdqqZ6CXs1g9xFYD3JC7sGPAskufeTSlYt73YYIcndJM9X85zYZAEjy0lcVmFzkQYNq5JHvmNRx7slRYC/IrcGMwCOA53b" ..
	"1sXj3xSjdWePhRE3sqOKmEzEhnJAIKBOm7fKU/mBWbvs/CXVUkDb05NJiymrWfSvuRmxaSxpTmMgeNE2uFJ1SCQ1WIBkUz63QrJc" ..
	"EQbu5bX8AiZOGSkY8+T/h4QIM9ZFTX5qsDzPZ9dnE+5bpRaVqjPbtC+ao80PUkTsdLyVfaZFQj4o1XsBSqc4oinBhw/IDc1FV7mB" ..
	"5rXx5RCY9PURr4bviY1vN1D32BejxxDiidnQEXHKdsCM720/B2eobfoO9VqCymtlP3EJ81KUk6Yvq3UcejJWGmz5ziJom5ouQrTi" ..
	"rCNuhBpcOvo3DN1t8rh17KEgN4qXVx7JUv8e+GnVL3+JssQVSfRKVlSByZduIel/YpHt1Cc8+21slS36uUh1Bo73XXxTfkpvLtqJ" ..
	"JCEYnMrZCmJ/EvSYTmx0w+8I4/EBDUnvzefi1kiXSBl1aMuFnbWxVZas0wXEZAB2b+aCP1K2E+oTh15DmFwREmRVTvA0h6JGIEF2" ..
	"AYHt6PPaFpXxk+GZ5snp99y8K2qjWujt/i4YFLBhI2jp8NxZqSQxQa0S058pQcS9Vqr96aI3tQMWp358jj15EFvT9mamXT4tLCC7" ..
	"LP4yHN6vt4CPcBQ5jSv5MsH/Pes3SEu0x00C/n8svP+aw2xxZoTRinBnDAySqqjo0LPbwysr6p/u0HXJ/FjNpJuPmWOAzvQfUbiS" ..
	"1DZ5WmPG09pSc4O5adurnZ5yG28jpw9x2336Eqr1pj14ki5+JHop+If1dJd3/CJyYt2od9ZPt8goZQB47qcmQ4K8cQjtaQ7EL2RS" ..
	"ARKGHyTQbzZ20ht0wUy3TrlEUSPnR02R7tim0xT9qtAYZnoRvTGf9v4AsX2RCs+diRslKF0wVcv/u7tFIbxidn2bGaOq0wlaTcC3" ..
	"OSOsbsL8mwbFIlETQ5TTPlyxs50hwlZ4powu8ODDCen+QZaF2HTT8TwmTd9Dp+LvkV6Kg/HJrFz5q7g3aaQnr61a97K0RQgNZWuf" ..
	"drFWd6PJ+K3+MqKIaZqfI12YXMzodXm6PaAKINv3cqFw15CmAYcWkg9Ayq7d9oaVtz5Hi+55RNa/q3o2EPmBwgd6w3EwlVAF0714" ..
	"Qw+nJDjtWR5kfoi0CajBXVk6wGFewtJhX17ZpqnORIuTuyrJynXrya4oVOhvsHfA/DAZHzgYWG9QYTynu2hGA8Q6I3Ka3ZxHPZVS" ..
	"/NQRSIjtUS/QN1wryH9+efAVsXY55hRxTS43hdmwutKqqQ1Ik20toPB4liESGfM8U3LXhO4+W8SGXcz0gIwQG2hEXtohCbH9ndJw" ..
	"sa8F1LTGnamYF30uLEjwyFJMfer7GvyRlQS+l88pF117sEkMzH7OSlA99M/N9MUEaPv/OZe7YJy27u0ItC3Xthy76iuecC1mYRca" ..
	"Nuhv9A9yHiCx6bfANEHhmEL+PBcDF+PXadR01YzCZOUMGMjCVPAeNs5XZT3qteV3N1Ks9LXF/68lrTK6LodFB/eYnr2IQCo0Nrwq" ..
	"CpzWssgwXrEKLzkMzxGrSuawRoX19ljuAc/fmmm+1tfAqr+0YevrZqGlTR3XAhsuzziDCmr42v5NsVTiiln3rCw0yx7ltUSw6QXB" ..
	"OSNFXEgteu3TU4x4GcN/MbJ7dovGqZh9catmco4mYl60B/1mZywK9/heRuqXMvRziQmBlnBpt6bZQm0nhIwQlBmbEltNt9TEBq+f" ..
	"of1NR9bD8ukIZONeJmTrgPiVaZBb1M4l2Ud175SJbIrbJjV6DjxOinCoeCnBm2RIUdO0GUpqEaffbJrXLjie9MJKAWV5Pnl9+5Vd" ..
	"bxFTmylEh0FDj0qce72m79NZH9nhJ5dzA0NFdO9csedUgRSbzhe5A2Wl5CJXCxOa8gg1SExAPj3e77+FDdIxJ4Na3cnnr7+g/ltj" ..
	"RzDWmikSMCSKiZpmxB/zjxQyK//I6MosFBA1TOSQpRYpYI7Ukoq2PwXTyrLwuItGUkyqibhDpxMqksAAVky3D42aZ/XXhv6ZkjQJ" ..
	"gFrDi4P/OG7Cd8yUsRNF56PlLcUwQrTFCCfDuboMr5hY3ERlLK42vQ8zyM2+aYinN3hBRRdcfufpQF5mEFp0c294DyBNMX8oDYJJ" ..
	"2vgpeyUI8ZAlh8GN/nQMvXwieSk78/RbGnXydEgVZWPDYnIzNlXyK2r/Uen4hV+40YZ+TSve4o6DDDdlqbZ0V7+revMTJ9N7YFL3" ..
	"K4W/xHxSHai83UyKlxdFxexwqhEyH9o+9yiF7xVlwuEpsKjykCscDrSoloDX9QQRrwa1uLTEYCLZh+Qz65fvSygTyM02OSmUlrJP" ..
	"znP6N+jCsxRON6ZL5BXxe7ieadOu8PR8cIyleISRJbgvsp22WWAM3JESnG7DSV3tyguJp7DPYzcpT6SjHYiDJjxMiw6fH2xu8tu+" ..
	"ho0hZkyyVy17+Em5P7pm5+cCquN5V38/cRTuID5RP1WPBZi6rD60i8oRc9VtluKN7dfOt7iApt3OEdZ9Izd0DZpWJ42BzhFGmpD2" ..
	"mTgUiISiEgCrkCmGu61Bi/mnzhorhh7NcZbbvl0yZzk9zgQn+jCntWZS6DO2psE3o32WJABvHqXkdKtXb27cH93QcWHuz2k6743o" ..
	"bl8VJ60opAUGCKpbpKjlSOW6aF7jB5riaH2iUVC2hTrir1dRBEdfd7ycYfriPVVu+kpZyAUZZ+ChvRBWCXIdvu210HkJ1Ebbwaas" ..
	"eHi56RFUkuSGl2AZU0JekuRKkMaXozK+b1Tmu1daEjOwnqZTPHKPvw19yb0a77eu/OFD5NKbgtkkXATcRWErD1b5iY1jc3Iapesd" ..
	"idwzJIONL9gHvvNTjn0vKBEwdRg792HNr6vgpWk9GJqZDGLNboCrey+dmU5CjSwITcZ9jt5mXxWCOJlma9XPACLwo6s9mgr+psyh" ..
	"j3v3ykSyu7M6zE9qVkiu/3IA9HAi5kZwimFDrItLFxHrBW7LxrrHkPsasCo2u2lPkd6ABN5pItjGJwqLWdlP8ujT4kVkGcO03sJy" ..
	"lGAwj9hsYr/ShNiCzjZgce9TOAx7n0QZOP1FemifomvPcEUaQje6AsHT16K5H2hgoVA18wpSZGV516RInu4auFLfXFvRQlhzhAnN" ..
	"RZxjQZSAgG0TltLLOYvGBWLSva67abFaFUZVNFRrnBOuUNzTKVxeOae9zIKJVOtzFRGJ3Pn/vxGzU/AWENpOp/5vt1lfgul9i6X5" ..
	"TfbjBr1lLKioU7kyMiJapeiZjb9p2P9lV8acQ++lZGbW041rw0c3xtGNLhwjCt6lLK7vAFasbTHb1Urj1Ku6E4qfDdfetf9PnBcy" ..
	"H4ShSepwcv7XrJd3ASUifUQ6Ubo4pl1Wo6KdnQqCgGXcrXiPIlenPdhqk/C1zAiODGVNvoKzl71NfChiNGCaVyXko0RJkkyF3ayL" ..
	"0gsgSdGBn/xlADHyekDPbouS1m+3aaleRlJVm2fYf6Ncl4ce4p6lTryDdrKBwwAr3Hd5WOum259Oe/DBjKpYSkjrCDLIf9GljCM+" ..
	"tlbd52cRROkYIEhKju7WuttkiHRDtJmw4FZQfGrgO17QYIW9Xl77NgGzhSrTcC/aYc3LaNiq9fy+utJEcadJqVRhEQTNCsz5bqe0" ..
	""
local PAYLOAD_P7 =
	"ChwbZ79JZrQYXDVipd41tmd7JnNpUB2jDeiq5r0RT3fgPNAoS88SQem060Ik0Eu3nOzd3qJzsX6k5hcACXx2P/ij0xjDKA3LLHLm" ..
	"EcsOOgtwDRFC69kRqvzjJCcZpYi51ZV5nywfYgCLEFFDt1DcjvFAB8lpMR++VfQfqOB9lscwHSCmvDLMVB6cy0Re4rFzYItynOP4" ..
	"2E6ztDZIsTCCKePa3th+RvxDl1lTHjlV+8EtidGRkLLamg8f9bOQfKJu16tnj/cv4+4a3WV/0oXnyr6PQBwbd4r1m14S3UCCJC87" ..
	"sXKbpkxHVk9WTXgGFbp2+GaKIVmLBhM33F2SZbeyvwTQDvlpFDC2ORo7v5cg99J6olm0KcJejC5Az75sjA0sScviS7Ig6D3wD1jp" ..
	"wghO6bOP/I2QaUC0Nmnm9geZ9ktWHnPkpCxbnFv7sndJsSqqG4r/60C4NF2nwfsBbpAsPmRj0zAOAJtCXh3TGzzVAd02b7MDILP3" ..
	"2i59sIFMMo48K5w0SH2TSZdJXvZ8f60cBGHVzt/Y1C/P/eJmEEkDZgaQwJkEBECcz4afR1F34pmPnNMChGOKnr4lCQpiEZdsI1qC" ..
	"WKHlDh6oJBLMJJBOggjbIWYdiY00PD1O3E31vBzkonWUGOuXE9YQztZGOSD9xOVbUYfMt6ia/f7+Hu8AgjqnDJlKG8yWSFKBjQFL" ..
	"AThwFkU3X2C6vlPjsbMyY+DdlyeVzEGalMH8eqI4vXC1Uv8+BBPOsn3GnAd2uP7uYVHYly1Vd4SXWHXkK30PPrjeoAABXf9HwhMV" ..
	"0ygi74AMB2Xk1exN1Cd0yGkyVGF+1Iur7YNFPkkG+e98ND2cwGdjIDzLiOAY2eMmRiG2bk9iJUUKLrbNZxVdY8o4y4pGxAnOutzg" ..
	"eggUX+yVzktth9M4FntbbhvY/DUZLTTWaQH5mVIlo7UVSwBgqNiLLNYgBswSI6igYJ86to2Hz56yFE2hA5W5vt+yNjU6Q9lLxBhR" ..
	"6LaCyMcazs8OD8ZBtv1E3Cv9cHhA4h3mWdXr+uMDGBCqywP8YIQq2hSEXfB/tsfIMjJas8fdmMa+yzIXWkxtrLWQM8yLg3UsITEX" ..
	"rSAdkKzCS0zt5+DkYaxP8vj86lFWXp161d1INIILETCu945P44eZUKbI+5aMLAY9tg2kB+/IaDz5Y/A2L7pVlQgCTAeIu313ztLz" ..
	"uXbVnFokFgX/Eun2VfgWbeqk9ZAmZkaUZfJg2H4kWrZFSLhIK3f6D4qYDn2Uw5KOOJWggwVCoIUJpyoj3w8zqcICQz1ZloF+p6Y0" ..
	"72hSx2p5byQrNL200Yes03k39hJo1U7L3KY4BfqviufTAuAAxqkdiJTtivj5dckjU1ZEqlG+3cepvwuMSTTEypjauCUbckFcC/ed" ..
	"x4BZTncgdEMnB4nod+UxFOP+I17L7DBijyTSCr78VoBhh4l+ViUTc3dkOfqSjSyCOEctslndyuWT8OdxhhsT/deEHd7zueTr3dhK" ..
	"pTKwDcS7GXh7TcD04NukMA8bcR0d2HgLbQpLp5qj6rUUHBSevIFgLnFZhbA5BOvMhwrb37eJAYDU2nPvUG/pt8royxNbjIzInfmK" ..
	"ubyAP2MHN9b1Kfw6s3qHVRrpGxcXfTU+j4C54IdRe1nlp+C++zybbZg+8b3Y3FkWxo63uJse3kbTprPMmZn5hEfLUu4G1Ok5D58S" ..
	"wTFmSJUFbaUzsccSnHrWj20qQZxmevJOaW0L2LKWFVrvpWnuM5jvT6W6j6Pofm+uBD4daU8mpfQDPKJvvxZBOhIaJ7ya8avcyI0Z" ..
	"xytth7s5JL9buHV9eSYVoBzPMjm8bhrwM0+GI+h1gCeF/a7ya9gVkUxGfmNK0KkDtuml3S6S6JELQp82j6HrqySV+SJXfLjZoUgi" ..
	"NMUZiN4EekfxTaCh+ewNrWts4PVeo2xy3NhwzPc5O08sRTmZOBElRgWVQ6ksDXIjKcMx9GZir2zIP+l9uJJXcrtCWLqdgxxJ1blW" ..
	"eOdpQtBBd/mHVxMRFLsIxkG8mO84/qNG+RMof65tddm6q4WQqr/eYlY/eUj6PlAG3mBsnFkJsTBnt8NWYisEa8VOLLsQ8C4Fn6K+" ..
	"9IrbYCT5UZxx8ENEz4I+IYm7rykIcQ3D4pyy5IeojkJyVB995ZYlc9/T0SEZatllroyT2r4iZTo8M08pLJA4DEvWpk58FKGRU71S" ..
	"6Prmi42z2BiuDv7rp84IbKC4FrSJg+gd9F8k8F1u5+0n1JjCq29VZDWkj8ctYrHKXNK1TG75Mdk3gdrveGHKAli4gnZG2FkCBa1g" ..
	"4D03CvbsgXktTEKJGFXhJuRNQBjFkVTw9G0umQ80wFjztrJhWRQ3NYJQUxKZukN1YtIw87VglwncSXlllw3k/3ICBYMHPpZDZPja" ..
	"yagZMoAbarjmR+M854kXghVHO/mZS5grsma9jMVT3bRZpElZRacRs6ZJyvY3ZRpDiJS6bI2aDzwj3Zo7Tm6g1l62eDENpQqqNu2h" ..
	"nxKxyLlOA1YbuPd/C9yHA3plxTfTtC6/bcd7gejoZsFuOxRrgnyA/3lUNqPYMzKzoG274lWYmcFU5P6zav3gQJO+fY2WQk2oArwu" ..
	"CK4ypXPhm9nMyKxgy8dqeIL3h2w/FNELjyebRwIJ2DpYS2Px6Gg0YjaxPK10yMdW0x9wm/QddU6Juw6oc3jr6UG1IDifFgmnwXSq" ..
	"9UprDGc7MekCtUE0ySZZXFgJGA5aB8dWtVOgfKoCRdpGMPAFWrzAzIo8rbX0f79eVdh0LBoQEEoRW6fU6pXRiNUbd1HqDmwU2apl" ..
	"E8i/ry3N2L/DBtyR4WXA/dXBWCMo3vm+lHoDX2rJfLzfyg2QzUoUtCt7qJUIXe1QL2Uxh4q7A4LY0HN0pznfA7w00oOfz6XALi9u" ..
	"IevDivNYwKgcPl8KwjMOcoW23QKUPZ3Z4C3alQl6dCUwSydW2r/mGKLHjNV6eGcxbkkwIERwq6TF7zgY72/2cBFaWHIPUAA28ar0" ..
	"RbyQBUDXpPeTTCfs4wnSe5PUGpB5Q7pUIrcEKwPfd5kA6rn+hni8eXnLp5kMtFulcj4dWJegHshUQ5AT0r6pkqiIs5awTmlELobO" ..
	"IJ+RrcR15QBobA76LQ4OCDnRPVY4yDX10QAMPM9hix2LVM7TNtJ7soAsmqyIaYpdUWaA8+8qW7ZZxF6XK4PDI8+GBuD1gvbxetda" ..
	"BNCk7T1cVO2M8Zo6xOTedviza7leWQQROWnzKei20xQ9ldID25AxnkXdVdzKQ/rKLaJXshQoZY1EoHBcilO7FutzhHwBME6Kz8B+" ..
	"Kv2H/SWeAWZdBx4Z7MTXa7G8o40zhWMAYxwF/Jifs+XnyqOALq+tm8aC7AaDsjygpYlPAhfm6VxXz+pQWNWsWCyKVETtQiOYBPuE" ..
	"gSE2FW544alkPRNUXENMtUqBBfU79l9A3btZnbjeoYJXW/HuG64SY/gIQ1rTGMzGQrQWZL+2YxiDIaEDQnFbEcfC4Xt+rlfoBcuq" ..
	"BNL+i1f1rKo+R1NehtEHVLOxi3UI5P4KOJ1oEkN47VRjQohez4pWUaM8ietsJs5B6h/K06qwRki9C8MRfV+Z0OBIxhM/9wgg1GFq" ..
	"BoN089bnqqTI99eE3tfe+YccYsEJV/h3BxPMjC9C6dK+oKDGwhCfBA65ZGGNlxjSsi+0Sn7/l7QxOPfVl+SQER47q4lR5rfHHZzo" ..
	"bfgorlkkAhL1dHERwiSX+O/cthyGeMnlXkkALNreAqHgIAa9yQhY6Y29HXaJUAmNtUiUCib+4V+uChGd6n8CNbFfLrDQDMSXLzcR" ..
	"L414yWpFNDMYlxNywXa/XBczZoRJaAlgEfVdgxS6RxmZRfHlJereWlPYRbRsTMg9HM/SnF8P83LmKNn4oKaw/I2v6EECr2OP3Hj6" ..
	"U3OL3XIfYtSXX/6TxgS18tFVteKFt5sWO0DS59s2G+IivXw1nyhOiHK/lCtGT/0IsObamWSQj8DV+7r41AmMIyzRrAkQdJ+9WF2h" ..
	"L4OLgtJijh2YD1ETcG/wyLOY+sAt+4COGilYNRSVfu6SvO+vgKLb6XVfEkVjh8d3oVQHxiElk5+VsZ+rKQ907nwRORA4Cj6ZOldG" ..
	"CLxMZGYaUDI0FvC/53jAYzKamzMkVM5e5VLG2obSaciR/UN5cROHIDiLJPNzbzUqflrf2D2ni8iRP2HVG20J9WXEoyYp2+Vsm8Ut" ..
	"PPRTVSSdqCRDkdCoZq0Y6Ltjc9ko5dL217mu60Tlv1qQoE2pbnNzJANnGB2LzIYNBlbs+KdM9keSUWPNbrvh9rfH62WvnUZoDu9t" ..
	"zlerup7c15Tqxn9BmD7DbCVByxnoMQaY5WGNALaEu5pEtnTzbD9YdRx+kgSqI2iXYhdkclTwzTr+vSQ6gSaPrn/QLv7inLDfoFkQ" ..
	"LOXhAp86gMhtmfmrdeY7hJSufRy+Qoq+O1CpSGtkQS3W0YKv/JCd8xQzMdSsu3Q88JeieJw4nz4L4Au+U/+oBrhRJyn//eAH8Vv+" ..
	"rX3k/gd7xW7bsUd0/91G/YsZ8P3uGPJ5DvvRrSGlcusRqEgiZp8ciZxEaGeAkmQKiVM/cK1L5tLMkP+pNgU9l+JHrRyOqB/C/kP7" ..
	"Bb+Pw5nnzrgFH7Md5zooT7wkGGPJJSFHgDTy4CwrN0+lZPb0HAVyfYSibcGnfY1EtUA0UBoriZkQsxLnXZonufh8Tej0kjNixCze" ..
	"hu58EFHgOI8XIZ6Ea8tRkt5HXyOAl/qMR3jTq29zNI86cAtf1DNb+SwSXjNYasrWAGfDA6IOEeXM6swWYNpJQUEba2/ubXVWu3jd" ..
	"Cu08SR1Ev86NHMOhwN88gc4DSpYvMKYA0DLmB9AbAP/9pqO9v8r31ysyLabEYU3sMUY5dixYse0NxRxBh+dTGJtVAXoBifxglEGl" ..
	"iKr8cJmKfansRuZgxbc+BIiRrTIEDzQajK6KqnO4tMeQrk1GJUDskgE7aNOmeGm70YLaKgkCu9Wdj7mnIFPnNP0X03CsLUPWNL+b" ..
	"dmirrSYweCctMRr3KGV1xS9q014inYYNQkWg1H95gXaxfWoStJBYX5DlYD5DPb3ZRDaDj0Rl4SRLaybIs4Ge3mF+7IBrNRqSasQ8" ..
	"GcjgPKjInhFu+86N9L3+wzdPVtz972SJsVknXQP6C5CnczpaxLuM8vbjvoCzfjZ1mD8PafeNT1WSUdOjX9826ZXst9Mmm9JPHdxV" ..
	"b2yo1d981P9uV4+KoeMK4XBbgBBUAaD5S0d6KcV7sw+IqRHFY4lDOcneywe6ZYDZgXa8XEjJFMqUWLbkVw/q9CE3Jemr88+Ro2ES" ..
	"3qKlD293kQjDdyRoSNYNNQkn1tNeqn1NRjQHgfyWryS4HQtObrD0NSnCzkJaeqE3ZaiZckw8Tgh0PuV307rpAhEy1tVAz1Y/4gUL" ..
	"nEbixAdbnb9JGr4wNOe1MRmEATUSD1D3t9fC8emivdhkDuEC+YQa4xTnI4iMbk6bM/CTJTe2uUNAVrjsLhLeWLfZlhN+Cpf4XlVR" ..
	"yQIgkWB37yQ4EtbZj6kdYI8FEp0g3gI5vS6f5/30NI0+ZxIM5l4mrUbOAMhC1sZh0P1GTCmCQpO4qbFWPr/XoWS+0IFDPqXuPxw5" ..
	"8ziuyrvF45CBctDeRP32WoPDzVD87nmEf/s/M+7/VWDNQnIkxH2ydJUxtcYA2yx1mP1ouRzoy/FY4ks5K4mIpNueSEF2rHumWcCy" ..
	"zn75n/fFvDLCf/bEjMunCfhVa/mq7kTnPC4nDnw/ahMW8yXlFXXMxMLT1WCD+8383ZMOlQXxekKSQqdSGZesaezc12rWHV85/wYf" ..
	"tb8lhpOayFjtbx7ipaXKuzVr3ePP1MYxwhcna5QkB6cAxDzT+J5etmZ5AwX4CgUcKGTsJFNhOwsZjjSke+BKkfbJSdLUcdL4oeFK" ..
	"Qscz3ca08A5nF6/TINtZ3lF6HgzP7WXNnkhCWRWYG/l/igStFKAPkg52CUkkqxNZNFuyyqb+66Vgm148Fd9CbU/XjmqJGASLAI/N" ..
	""
local PAYLOAD_P8 =
	"zU6njOPg5h9vmqRf1WrI8WAdKzz9Mdqw0H1CTTDKQGVcEETTh11uLGmOlVZIg+aogPWT/RpiaXNbUn1JJ7CoAT+dtC16CjekAvqL" ..
	"y28dZsyf9ymoh6hECV3+WFgKwSoEQRnLOl1GOCaRhqvcdwLZec43Aj6EJHer3ktNU45syRLD9B9wzUcDY4uG0/XyrNQzqcC1H7ko" ..
	"1jaLQ+X096oR4rRTvKC9uifuChfZx3bp4oEKu5oXyqTGN+6O25hKwY971EWxov2ANAc/duiQmWxbauASD/5GgCLLJrWSIIP/2MfC" ..
	"PWThKi+FkDKGt/2DINOhqObuBPubJSXsD9Jz6N9cV5M/SOqc3PxJMArWf4smJvb53L1gSGBGwHk3U/nPTSxQaeyxoJWNNBIbD3kQ" ..
	"qrv11wVDaaDxVwE+hSjTxRtq+vBzTdB4TmJyXrmO1zStVB9B2OU43tXBXl+R+y2UB5yUR5T+mlSrJVyTrIx1Pul/syceaU2VSJc4" ..
	"hEophzUI47nWm0fYFTtTXObcmxPh6sAavJbhN00bh9uwPMFe325CwI6gtTAL1wch2m3azmPU1RgypqKBbjqTRebhXT8IVgZ7+JI5" ..
	"e6zABX7ERGcf66fXF/pJEgBdWUMZGfTVHibDIIFZXF+SqzCzStENZiYIQGy4sZj/HqIvleG4kwaSsYr3JZ3NTdti4LR9VyS4wG5e" ..
	"7eLsKg2ytZKWsjwSzQL5sSzPkUSBqsU2ZedpiEXTnXjVtzD0TpPy5bZmPGI6gUm+Ts4lbue4eP/kc+gXGrG9qwSOpmVZiOOj/xgN" ..
	"+7EtR+G6nVn4a8yuarr9aBkqeZ7Dh0g+a5ZcDhptCGD5pE2Tr0ZLpDOwz938TTTxDcgpV9qtciMu1DPMUJCTdy5pBLTX20/R5MBy" ..
	"56cqUKXxH6opN4B/bvLTKXEgkqNka8xvDNkT4rjtUIcrfmQfyIsHAwI5qhoeShkbqKBG93jrLtrWs34J/rh41PUy0wSZ8hiB9FAU" ..
	"ME7qbWJzwuJPvjso96oumRSk55DcW/Tc64TMELo6/P6OEhFKk+BWwAoNcyc+z6GSMOsnVAiZHZQkp98xZNJEzdn23rzugZrQekTF" ..
	"PzKRSyXLdqGI4xXvKJU1AIqxmVj11gjH09PGRrJPgymZrUirD85vLDbs8F19ugAiaUl8SOWXWppcmbUNDrktnF4ItunB+8xgC1IV" ..
	"h33nFNYOXyPh/R126tz3upzplFKYTP2KXlRHbzBCpdysyPiniVwzxajutYBwqUWEZ8tb8weJYXLkj+w4Xl+V3mNdJbC498dYQvUq" ..
	"a21DRVgE5Lqx/y0YwHRu8TgLXvVKYfkAO1irVdCG2CV0WZyFNKcyIYUVO0Q7012KtGVro2epVYJ77tj4OxnnkJgwGPKc8h1OoZhT" ..
	"zD1pRSzT0s65hI5cTOQXRHJcu3By1Jit1aidm534czDQs3clAg/ru3QfG/+ME4DI5DCOh3s1S2NsrTtAt2sDBD89mHS0LFoo8/9/" ..
	"1CPP760FIHMbzaeLr/Z6EJl/oYZG3W7gW18SZoQn4GfWpmY8z/yoBGfDtSRbAxGI7eMlUO973wiZ4aFDXgL2aQJ9IoatXkqcVrjy" ..
	"2nM8HfBTThyisDpt1UtP/z6pjYobZZYLbBXCV5tRrM0/HgWKLZmgyMpXS77XoOPF9VaBVymV254Hhk7k2Qyrsd04dUFCe4hJwUQt" ..
	"G/2R6AbpCzQZYrN7ny8eoPh2EmCxAFkFu7eFX4uAkKhw3fIk3+5U5EAuJM0lr3uqebeSuSfmQM8bVENzj7InTpBceR9BCM04IMev" ..
	"u1xyPSAyaJbL2yZZ8GZQ0x64UjuKTwFTGiTlCFHXvX3l3YFLTSYEDCTPeghaQaY6vBwQLLYbwd6mSFxugoAWwhcvxpS1ouJ2q/7D" ..
	"dhoeXZmywJAhQitf4jAbHOeBic01kwe52mkOX9UwOAeb3bpRFhG4j8E5FfLNsbbRz4tvtkBDFEyBs8YqIIKbSjD4OuQubRUTWMtf" ..
	"afoqVlOmloCzEOXNgKhIV1UxLTU1qTIo/kQrOmvGRK4GfY2EYrgbQyE4SchvzyfbbQeaHyQliJ+3STBo7+SnWSbeLOT7/4Q+Otl+" ..
	"FUSN++F9h/fJiaP12396m3hW1sjVkIMreNiIEid/xiu2SLSJ0EWYmSuZNzEC5VidDH84C+KBRr6gISx/6cyraSUBM2TF9RqTmMIx" ..
	"de7WfCHmyQO8MhwiCF48cajGIXxelpcF9809UMo9kW6OKAAzeWlHG8OqsZ6fSEILe0EU5CCbNGMR8ojUOKpgWz+1W+w3Yr33xeYq" ..
	"gDuDqRgK1azjUnOUM+Yc7vGtXlAYSou8aO1dcbCHEzFiZJdTVTljPL9FZbCbZWbvMv52I/6SHsxY+iFDtOynjhFAFiKuZHJWjEv3" ..
	"LFqum7T0OLyo0giYf3tQwFqEDADtbom4FO5o80XvjSWnpZqwHtmZ9pOJgyyYWwejwC5/wRJDUeDkelarfLQKWZH1bRYMOWURVhUl" ..
	"btgdDdZxZQlEjJgyYeDSuQrX0FnzcEUTBeRz7coy+LpUiEosv/kHd6s0LUPuJ9cuOgOiWIpw6umg3eXLlspPStkpMT9WBMx2+43E" ..
	"eBB3R8c9Ru1ifrqC01WHlC7HHlAhGatGtT4bKotNDP2qVNRaCRb9BzK9MIjw+6pXkaD70Z91scgNGT//xKcdMFGFBbTXXY2EvSCQ" ..
	"t6hN8hyd9pGeDfjvqkgiyrlVpNowFi0glp9pOAMeIg6W1XxA8OrsE3jwpf4npCTaln6oZKs9vX/6M9ahK5iHxyjmXMIReHgJC2nf" ..
	"SYs9uwk/i5G0YmPxufEsRKrOE8azGdBMyccqOk9GH2K+pJwnn8sU7/EQUbvX98l2MvRP52m2+YC+HsXo7KVPz+TF8HFy27PIdQZB" ..
	"sSynfjOPe8TsLXRcYl7nFGIFja8/EvQ+6EoVHEA/iPZvBiujPuXxi6OHPBShcb+Q2XcovQEycpNox2vjRGEoW9IkYRyfkGcBt18o" ..
	"MbT49fdoLi/Ue7nE7UHbH044pLWx+QOSeKMktl0wMNnKA95kzVdY3NPwyYEisFZyLZ6de7XdunGcDKij16CZVXdloKuZ8vEq0U5/" ..
	"3SBQzohx0bVtYNYlvXhnbXPiL7uNZ81PuREKVX2eu/3O9EZx8xVoitnCBxZpOuoYxEPopvqVVTH0CinpI2JF9pDxp9LzWFjRxRuv" ..
	"0hcH6N4Dykt+xYElQsDOVz978U+faFoykofdtkn3+dJz4qKmFYoFz73jtxnBD74w1cf/PYaKFgHUGy31Bus+QVaRdU0nKbK7rN3d" ..
	"lGgidzMVT2RNNr6jTfYBvjIk+JXykogzPW4ZMcxml8M615oJJG+3AFFF2oW4eon0msiB680d0FdebmwGJj6Bxtgih9pCnWtB9veM" ..
	"KuYndcL8UVdgCJ8hAgXEJ5OvYlUyVHsqbo0kjKMoc4tIyRqxkt4VUtoVcjvST8m8xPncNrdpy5Uk6O/xL/BKMe5gYZbexuv89Qwk" ..
	"cG6lKv5YSXh4WD3oRfUKZiS5AHLrm5APjTfC67iTvZHUpwKqtL2utiVAVPYKKcoSr3aPX/ju7KYhUtCbn8eXRlzMbAq0yy2T+9Wz" ..
	"Atm/O+QmfBNNgV5OqoKoRhqatSUPo/P2532+CcC6Ut2saYJP1J7oPvOpfWvNWKZjyLw1a/Cy4BNwrVybDD4o+u032nVfvkbPPSsM" ..
	"h8TnhNxOwiMTbMCTaAQHVYmQoNXusmOVTuJyJQdRz6qp/zwN9eDcw8yaatQf742wvLy8Cjzex962waurm9h9LnHJ+PscVQVKG7NK" ..
	"KmNI2eJ1z8lt6j661q/M0tKDRJFFKaC+NbLRgVIb49tDxG0fL7HlhoQGTBFxnAKpnXzcsqbXwT+A3w+bbVfRZEehDJSFSLlbLaUY" ..
	"r+kN3Zqum73sdtdhc4QYWqplfmCyTHPKqr0TymZdI3jjvDRw4OAM9dxpRi8EEn1QOKpGP0tPKmau1im0LtbfkgUdDV2FBCrfRomC" ..
	"8zHpZ1XB/OilXOGz3/W7lXqtWPsumapNacYYSHP1VU6FGek4TG+XiVR0N9hgxhuKn37fkwCQmFs2q0nw5GwiL0HbdIcRLLEKSk+O" ..
	"jnNd4GCwboTWT5JM4hk5gdbtAL5k/0T8f9iB6orxR1H6QS7Ivom8gCdz4nUuWo4+kVv14WTgjnPGEyeDzBrRsRXfQ4z42wHVRowe" ..
	"lUSN5UtOACgYFIp972oWNCGnq24a7OWfyhvtp8VJaTNOt7JHxbX+ov7gN9gkN5JXms9LANW2EFsJhdljp/p5O1/6xAvSGa4Vpx1w" ..
	"81PtPf65ir6+VWsgSn2k7aqAuZY4qudFK6tZ4wG59Y9lzZhuLs6OBYPN8Mn8tsocL76buCufsFZSsyzRlNQrDtZ0xQ7zL59EU54M" ..
	"cA+J2eUg6qREOKBaYvh6mVkIjkLSL6H1oufGpzmUYUTtryBoKxi7uh80GF7+eG82Tcsmw3CkbZ6l1G/7XLSmL+VFWUO8aBFaTwvc" ..
	"QUUVpYQi4X7vscMKFLyDmvQFRJU98IIsXSd4n9PypwgQNPhyWf4gGAUcnYp0z17K61xSO+9IwzEaNZOgXmdxag7Al1DZ6HSKw+bi" ..
	"8pKm2hlBWO8m+GsrGZJ5wxgDLPthT/t0yLZDfBCox8Vj/8M/nym/pPS7KQ1Mujb6xlWOZnVOBH6FLFt7TdXDtjaJ5O5WoNhGZnrh" ..
	"0uKSlvealA5N2xppfHGCILi8/nGyopbSBeqfYsQBZ+oIQKk0aZdxGZX2FG5VPicMPisQ+2GxTkW8K6f8rUO7YaxOKovnBzfu4PHb" ..
	"n3x/0VibHCSqU20c0TV8+iW4SzCs5phq+R5pRoeCD3VtSkHoEcVXX7bl9jPUuIm+wDT6PhHw0Qg2McoOEpDh3tveCDWBqKb1Sle0" ..
	"cAy1C6MTOo3youjk60aMhFoHwnqPQzS6xNTryAuX+pDV79oHe9Vy7trLlGDELVSqZGrLfmQxHw2Tj1FceHXyTmbFfk5gly+MR+os" ..
	"TRVEmjNagehDr6GbGo+lNaVbRbiKEgsKr+oCsNakJkZ/51kGiviUjhYB/ydWNt80sXo/9/LM+H+tc5tu2TEioo4CnWJmyc64ecEe" ..
	"2jtkRWxgont3l3aY57VqODTvUJ/49uBBfA9BLYuIf50agEEsGfKenX7geGSwHY6kXBRzcDVdKO/UIyukDYfU+g6n0xVZLSuxBfHe" ..
	"uDPmUV5LwmqVVfrH11gQx6HLjOduTSXs6E/aV+7SrmkSwZH2vtVcM30XiT4xgUQI9+hdWLlYbSDD3do5auC5ny+VyzPYoiscQ9UR" ..
	"mHBBX8okZ2gFUKlK/FhicVADDQT9rdFAuLjVPxItBJ1W8u2r/kmtPCFnot0c7lLs84+uzRoDDzaq0+xPog9zkck8lDvr1cQMfdvj" ..
	"+j0/CaZuQyO/83uaa4+yyT0k97NhSvqQUF9ecEMGVHc5XudhWPciXys41bHpQuB716t77EGoAvOg0cN13sA88CNgm8BRQxpKprYC" ..
	"wNJv2aq0J3/Zdyy0HxqgA/189ln3b1ABd7mfcDpbP3ZpaDnx+nOH7U4kN0TNw3YvZ6k7e9cdHeDfOX0CwSnr+3yAElw6pIITnBeV" ..
	"BtH+nMHn80bi+4T2EcYU+aTxWGB5EOFRvfVRS/LSD4E+tkp/Zdm0j8QPZXCT9MgAC47DS3YDQU/PWj1oqf1MJtvMCeyArw/LMjzx" ..
	"marJ9H6YMbmcO0TxgaZXxGWFrUQI1RJYCfQg/Jp1w1veDMKO3DUT7EBJkPrT6EptOnKwNUEeDypvrvIp+gpLdS+h4UOrFC5feFPh" ..
	"Y0ngGylynf37RXiz8PBsSkSVCq4esIq6piFPJjhM0Y08DD5lVYSUyyCIUFpiykDgOO4NbxKdzTIpnLmCRuDWefsuxT0wTn+iN3Qp" ..
	"Fy0H1QtjHea1MWs6ERdjsh0BmwyAS+dFySjOmj2Jhuu2xP/p1SbD5r3NkzUiv4PFnpSFMMrq2h1gg3y2j3oGa6GWp8mTLVgKyb/5" ..
	""
local PAYLOAD_P9 =
	"ndvR3cKStg4Fk9GCKAlI5utNRn9sh/t4lIKbzTOB9Ufrd5zs/V+bDWYESNLZi2PsV6ymXtQEoaRI7+bC7RqlQn0pMMsqCHVg249P" ..
	"jeD+EPJORvK9v8i8sbvvTucf/kutenXAlQ6GJhVbtnrzfWMte2Tev10hL+GpsnHFDA6PQ1GtGdeHFxD1yIo5X9dgiq34rohpTt5f" ..
	"CWDCSwht2m7zQCcuAhcvEHCRUXUxl9CewKh+pHYJHXbJXHLp2R8YmiKjpZfpnYT5CdErrfvSMBuI3X9mDHyzsk8ft/ibDXb0qG14" ..
	"O2HapNoj5Gk/yyBgj1vSrkqPfGgjAIGBLivbxr/feEK7AyxTu0NXMnb99qDPOtsBBZyGPesrL5kNYAV78RZ7bj67dgMlF/PIOHxN" ..
	"X/Jk0sKe6WE7kHQU83SV6IDEMOJS54BlATDlNRWwfdT8LK1nBsfLBL8mDrowv6SykeiGjnz3+XbvFrlpVQZz2wt/fr94vO9FxntC" ..
	"Ai1QlQTFDIFvgUJKiXK5FVbc/ij0H6RLTMLHWvEbPeKxINH891pY9mtP177707ZvX6ii290s1FfhhuzmigrGqF4KQLEWImACwxR+" ..
	"ESqtweiIeUcPFB4b/KrYOK+BZRT9LyyTiDpu/GYVvyDjX+Z2GpDXTW0HJjlu28tzMSvR21nyjlgtz7PZWKJozDdnEd1Ce7IcF1bR" ..
	"cx2kFu5QZy7YNfTQnboAOTzvH4C1BZsctJkkptjOtyGBfsq4kivdTOD8IBrwYmv0Yioc2uyqwjG4Z3GJg664z5KPaey/KNfT+YOO" ..
	"Eg9kr8VTzmX/wBoZEqKHbrjYS3ZYfRYWvYf8JLwD+Rhih5MmYFEXXDv4poiz+wZ7o7R3Gcu0LBJ1as8H6H+VXwiNwhclrzBiA7lz" ..
	"Uaseq1FpiuhiIyDKzEafwN6aAbROrWTqu7jJqVWYQvw/5wlQSfsd4TZER0ov9EH2kXpHQX/Nt2mYiBj9IxQive7fAf4+uFqJ+98R" ..
	"aZXvB8Z5/GScRpz7mqWPqpZBs1YSUAs8YmR9Z/fhBZ6D+wZLpLiI33TOPHhg1CW/8iucBiAnsqHKvUJzXpkwaEFQ1djnaC0BZjBl" ..
	"/DTPZl2FpDcECV+V/96NfYj5FZjOEZWNfWW2Xs+TJNdBy+CwcaGz7Fpzoyxg8ITyYOvkBrBBf+RRNKzXRLotKMaFEouzVQB+TDFc" ..
	"nmtUW8yyTHsfhWs3itX4JehDYlD+pAH74CzjaOkJHDr8bQCcUIZVM8+eBvmSz6x/Ko7Anb4Hv3JlRtDviiXzOme06ShCd1N4DIAb" ..
	"kaqDVaiwT04nvbJDyUKAHrKVy0PaZOsi3URcw3CdImMsVq36g6ZFBIaIhOh62aiiRcgCQs8j8nO+es2+AxA6daZOOnSK+qr1LKmS" ..
	"sPsOpBfld4suHijxm8/WFLqVZrNd1MRQc8+LJJF29d/3D1ff48JoGwfJYgRh3oDySfIHryDmIoHbfZfnRHNHYarbElhqf3HYsUL1" ..
	"g/f+ROKuEKkw8uZyKaUSndrBnUbYjyPfg5h03giOv4C/QVfvOPTB4toTLMb2ihu2fLI+5v3ljlDN99Jd8Ojhsfdk6qtDHBsNomLo" ..
	"Tsx89SZCeZ/BEdvxjWiOTM0joVv3hsQ5RvLG9Qf/GxtiNkVQsgFKmJMy4qUuSOayIkN9Uf83ZhOWF937aTe9naEU2wqy7Is2Sc+M" ..
	"E+jyu3j60Qs6PWmlKapyF2OSng4Htdcyh7Yl1Kfrb65TLdkLALbt/2fIZiapBg4IrsIEXgLzB9gDRnx0g+xqIlKkmDXmxcASrdI/" ..
	"gcy/0JVkzESbH2Al9h6HCkTSTo4iKkKJSaC31qUbGqqvqG1ByxPA3baZJr63mNT4TTa95Mv+cHuQ/L2HMPCYY73t/DFfzny8ezTn" ..
	"rxLP9FwouwZYAxRR61VgBoyqcRNBvfFnK78eAw6Y/cEoueH5ixMQbwUaxJJKtYiW9JDlGPSs2628s/f5Gx/vwUo3PX60VnJwi6mM" ..
	"oRKgJvlKjE2xbtmu3i8xFhWumFa0m9TK04ZgwHtT/t107gsKFWgS2nikAj3u8mc88Pm2rYLFTeq2gK4J6Dk+k2W3QAKUTrIG53AH" ..
	"WTP30V3WJdKxASB8piPOBeIMc+39OR5uVgBWWwPffCr1Co+Rjj9CFd6j5cz3gYEFCE/OUHKd88uZeTYfpnH5upCsIilAZT8eq/40" ..
	"WVTz51c0srCsmWPPNdmZH3noCjtX7quCBxD1nff5BRFq9sfHHs/8R4g61TJXXR5HHPbwgiOoEVj91/Kgs5hLblLYgrAx6zAOlFKN" ..
	"+jCk3VC3s3OhEsXojva/Q1W/S0XwSjL9Q20cRMj6jIild2C66o07VEoYvgSY4TXamI9qpVtRxB4lObYc8EcZCkDTGw7zCqyEHd9g" ..
	"352vTthuR1lRCF53D88EMzJXUuvjtOb37vA0DYUkQcYsqWSQCxSsRDzOwzGnVm0Q0w5j10yC6qN/Mrr74XW98DUj6RjzGE9t+0vJ" ..
	"fTmeIQYhzDGD8zhZhaW07Q/o3eYs+5YtV/O1XRWbSMEQgyxTyJbwXkRPLJnnhL0r9YirfOZGhn8FF1y/5QcMlbI8RbveFnkPu1/8" ..
	"GBWILT7256HEWC2/0LCU0SsjtUTBktKnCTF1KfB5WW+v0PzAezMsMt3gU93RJ7Nt4tpU6l11tSQir5B6f5DAWOEJs9wGF7iFRLzY" ..
	"j861NmIfoHJuLXX+c5MTFm1xUF2wpsXDducu4Bc5TWO8thgWvrhBPn22XQqWXCasaKoB3mcBV9OlOmH8aP+oBCXbLdFuYwqNFX46" ..
	"tYUNM6EipZ7ki2ah3A77R5dFYPFogJzMUd8TXWuG5N4ishkwvvW8WKqgHeaGibi8qPWWRDkcDktCWAL98jUkk76+cKV7ctm/u/52" ..
	"8FAfJ0fWW3O44urRDK0Sw6FuXLptsuekXx8DF7KLXLKDSqVtZ8CWgrnxOOIkAydMORZZsQ/NPa0h9UV73biVy6lCUGh/wJEsmbyI" ..
	"C8Eb6T4Ukrd9SYLGVVroB3yDGM6MMR6JRrFmzAVZ3culc/hcLLINMjphNY1OiINEyXSBUgqo/Qt1kEaCnFGpaeYqFSy4llgi1kvH" ..
	"C/wlGm5vSzbrwcVaP9bP/YxpvtIPLiGu5SFnBbJ3ffXesqAk+hAqSU5T01lm5PpIxJTAtuIqC9he46ci8AJlXiA+TwGwbVbBGkP3" ..
	"qieWeMKBaof72r6xkDKxLMNESO3Ni/HT3NpcW6sJ39lgzcGoJZVdiFiECkH5mjNQnqKsrEatVlnpYW6AIs9FwOtgkIzF73JQxbNR" ..
	"IIpk2a5DxuPTLxO7Bs63k1nm1TbHmz3enneQlIA2oSvLS1PMRG42xvQ6N/FKsFcxCc0ytKFQRjCnAgZxM4Ofz3C7wH7Rclmi2uzu" ..
	"YVAO9GLSET8Pen8uDytDvhZx1wYhJXmH4D4i76EBmuUWY/5Qmoko1u+LzbNVs1exlLNiS4DyykaquZTkrl7GsJqfCTbo1dF47Z5z" ..
	"sb0N8dEXn4yYGt51xupFHO1F5qLF59lv0zs4ksYocx5L/2OhUzsxLmsbWUvfB3EHEeXXnDWRAff8zEO8CD9GzXBKdJxGeCFnMDKY" ..
	"9Lnp+aaCYiM9vXG4cK/EHbFNWGr5w9h7yo9lAkgh3HmttlhmWe1vN6r8O7hRwH+ZYnkUXFMT5f5UIyV+Ry3F14moMbeDbGQOo0x+" ..
	"H1h2wGZ2gWyMJilF/D+URc47CrsqAy2pRWdvtSu0kbNolLeZD42zqT7rQX2M99ku+9TMRrt6Ps5QJ+OXDe26ot4ljpqp2outFzJM" ..
	"+nxl3H5AtV1OtTBgeKtvJQm3u9jzohyi7AQoXeKYjuiR4XNsEiK8F1DAwOibsPipuvY61yBpUjUgMvSE6ev1lhSTwKh13ttDwbbb" ..
	"FCPTEVhraG8dqUmQBcig4EQGbNKmaQEW/Ku50vH7/RjTm1LCFsoEcQEwpzE2g9zY0Edyl+J0ugH4GRWUxLWdM5XvQyWJcwYc3TUL" ..
	"xMFhXMS1SrvJvjL00v/roH0pYLeL2+KTL7ENpL+nKTTLvNd0iT7z/W6rbPBpaw6Ds/UVKO9K4pBjOyRePqaI3IOIUjg9oQe1TgPo" ..
	"CY3UG606iSOacJXUQFDHT+qEC7/j3oV6YEk9gvLoR5Zgq6B7wtx5oZD40AH05Yis5eC6MOXBwSgUfjNd8+Ag+tnnjaJ0LipULf20" ..
	"S/qakOAoykemjAaCsfAW4t2yJQ==" ..
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
