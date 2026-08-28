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
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/33cb67d422c585e96ac7fb972e60b5001e420752/DQFarm_loader.luau")
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
	{ seed = 749745816, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 751326862, exp = 0, plan = 0, hwid = {} }
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
	"+69Jy8AgfHoWretiNL/b3PS2vte5PrfC8vPt5NELDpO1pRIOlEQhTjyQ0Tbl/i+KYwrGL3loGspb701paMLv4HkWqzpQMGgG6zyc" ..
	"JuJ9JD9/nLbDoLjY67saAzalIJ9OsAVAWK7cj0a4/dq2tNdTs3pOBkzY1AHLIJFv35xKpmRVL4WKcltTHWOA5Igo3B+yJFuqQqDL" ..
	"lFyBshtK7D0LxJFfn97Pl45k7sXL5e/PVsvZoei+6+MiIhqa2JPiIWJK7Z7nDn6X5EYac09yaGaN2eJTNKLGOOqyMRKRUZTAzrXq" ..
	"VL1KZWGpJBMwSqioOblbZ9kChqjMOemh7wkmfoTZuCwedXEGDdhl3hp/M9dHU7FIVc1HdoLYFYVS3/WBAPl7XWbPANenplTqhJqR" ..
	"zMBKlMlItzUvaiAxteRt4ez9gloM0yvfnZDRWVZnUcbfp89fxGzPk2ohRCybAY82dRmP3ZgQ2nHFTC8sDgIlM8SVmDCLaPJfA+Oo" ..
	"kdwQn5IBvXz3R+keQbP6lyHpeJvKrHUVwH9avA5I+Mr2CjxAzy4bl0EthK7DLPe59ls0mdEnbmQkOOXm1wPJlXUXhctBELdN+a5i" ..
	"gUB5faND0BeqMfmWW5XQGtUabUQuUpTzz2Nm4IOhwH/xYIUi73VLNaWGj8WTHJGzjOiB4dF51gxH2WTw25Sx4z4GR97hjQMd7Fod" ..
	"poBrENst4eMz5ESwMMok5GU93m9vhHpC951+/912YkBbloUG/4e4owjScNQodJaBs9f4dZROZf8W9AbSTdImtFtgeJrhLnHNYWBW" ..
	"jkHqQenXzwa1fm5/TIN9Ccb5NPz1qfHb1hvb1NdyvSJefEjRJZ3fg49W/gimEHN6/rqZtY1gGI7F4iUqpbHX5+oL1ZWi1BG5MLEx" ..
	"tHYyUUXB5gZW1BibAGNK+r7d682/u3GnrV/aabyorbwkTFADKmcwfuuDkBVSUozMox93rYjNntY3YMXf0mRrDi/u2vqjDX1ujyHP" ..
	"iTd370RxsEtz3mYUR9Do2ugBUWpiv7zRRjUgy1swhmx2Y2qCebzNqCv8i+TCVZlnyD2r/IExQ4SAm+Rf6sU7PGU95+Y/qdgkP6en" ..
	"SRNPeMOJaIQjG7T76J6m3+qNI6KzBdZ6QKjU6cXN5QiWT2siqWoWUksBWYQ9zp5N+p+bFA9eORsCEjwqjQxX1xRDfXxPdiByz/+q" ..
	"LmrMWAbJ+OZItFiWlnbmK8WNvkIoDopNS6JQuMOdBBfCmwsT4aTwgLF5i5/M9fP4IRaXZsTuAvI9+kaKILLWsK0+PwkqXdSPPMkd" ..
	"uN6KjTMPD22gA6q2BnGgg5AdeDEibUN4sFoN9XOKgL23hrsCY+Tt2G3pj0bZWkaW5m1l1xFj+Vt1hRfbGjM8pvGCD2CbwUw/0t+U" ..
	"pHoQnnDEdPSpywMQMN/RNQO8jJK5EiBSTLZVTcbCx7BXxCdc8fR/edKb40WfhZSXWyCtF8u96kcjQ5AAa1ZBGT2kPFncZAIl12QM" ..
	"shwE61a7Hyu4E3w6/gIYjFrhLKetiuHJSsayINShajqmFQ0Rfa023rTy25GOkm8xrjExxPdJfITWomblOuzLavIefiG/gCKHGIp5" ..
	"g5dtTibTK1+uUk5djcO1ptAdERGI+2klGqAXBSDz69QoIzguGYfeB+yniNcRLZwgcuzfkDk3TIV5mGLSZBtv5cis0rbg/69wmVlp" ..
	"KRc0cP61a5Vzp8PKsGpJIY4VU/YeKZXjX6I5RU4M0vVwmvhDVxDnYK2RWGs7Y3vl5zEmRT5hZEkdIZtEoaPSh5uFg91jztHxRxi2" ..
	"FA96v8ayw20fg+OBxr6d15xQ9NUtnyqe4Hk3gC0GttqXcrGqBXHksbzq+yCFjljZwSLX52SwqJZqtJL8jTsgNfpDneF0qA78vbkX" ..
	"ETnCsoB2ZC2KzDEOm48JY5J9sl8cBVnF0gRii1qSYFYLZhYW/Dc0SQVJTM59GFjXXUdGlrw7GK9N0mvjWqHfK4q0M2wxg8F0F8bz" ..
	"XKmF6spyWtXqjPu0DbixW2mkU0lXn1gmnwnW0Wwk75cGFZnvjRhFB7ny0JTbpBUP6Fc324keUs/OmPP9615EFdZIggTM+P3kCkSp" ..
	"B3l2hGWF7tI4QaaO51L7vaazw6SMaT8riPYdNhnoyyrv9PhDkpFSbHmgnsJakVsvoIZtNZkKyAvIhGsL2mjMznubC7krK+FSXUuY" ..
	"+LRe+C/5ZgJruVKJQqs7Pa6COIgBjqw6k4yH+ZdnM2C6vhAKCsPR6C67G2+kvPRDyPaJnKL3q96vtWrCDQLLJY1zz6kHTUg8QWB9" ..
	"xATQJ3E3gpWjpm5ewCd+ZkI8XbSKr9VQrnAcGY8p079CrCY9HFaKlJZ2xGarGkc7Lh0xIBZbXEvr7zbLBkP1DIS47HrFO4EKia7o" ..
	"2+PczD6VfSE0DfjVsoxs2fVqkPtIxNmRfd0R2LOIplvAIZN+AiwQxFSCDVGNO4Iox80U0RXECplmgkTOz8UDQio3SeMzJshJquMu" ..
	"UHDS8M2veYfA6TSk2ohPJCb3qLzr4QRj+ARS4I5TRJxR+NQxQauBeFuVxLNr1cxFbOhZLtTFCL+IKVNyXVBaMkJacmf4PZTWrfMG" ..
	"hbbT/cfnMSoeuSTJGt1f//qPHAvYjYzgjDAq+XkKOqgFOF9/KwcjJyalGVyAGsfCscJ6UCrBt5Pc/2sbV9heLY9ludKIjlm6D+Ra" ..
	"UT3dUUvz7DrHWdGhnU8nS2vrGHGpkduMGiENGx147mkjLV0wT4noFmlXDgvJTlMv9m9bFZm8VQSirelxKbCqm4TS227cvOy//mV1" ..
	"0EvPGV11l4pkIFQ5eILPpu2z4nxKNuo52Kn7wfqFNIpu9C8Vuc5y6SS4rn19MMbN4MyiY8mwspv9yBEo2WtltY64z9UN0rkgOYp7" ..
	"MhS1nGAJtvZBuD66P0kJ1BcgdvhUlKupR+yIHrYPZRXTthB29ac/orZBtxuCdPtpiWVYdmkSrv6Yz/+yxAiN95+BPoa2+QDdsTNw" ..
	"/TZ85gMDGtEBpjB4DpHxNGZ5NSR8zV4iGKgYXuvN3/IeAmmOwLi/Wfw1A5mUG8WKLz/rq/9EEd+lYRXz2KAr9m2+IzEqZ09EBrlI" ..
	"blMDpO6imbEQCxOHqbV3hgLOBgWZh40eSljSCI1UtGin6uAhMsAnHTk2Melnlr0g6vfkYV1yd5h7EJZ4R9vxO0SKk9rx13zBx872" ..
	"0O9DH3O/yjpfNZf5AYRFQQALa31vi0+avoReupPqSMba5827etEZc7SHwmoVh179XwpOVWN2PNHdeEUNaJJHLvT+rXMIh5Ywh4Xi" ..
	"WoIlqBaM/K+mfBBxjiDZ711mycfj0Zszvr5Kl9ClTNmjPfHadbYR9qt1mgtJLSyvshNyo85hljKTJCeekx3DaCehOMsC8rt29HCr" ..
	"v/3hYgo7h/1R2tplNTI3d0e0LBKZDbtumi6XLiBJT+6n6PJNSe98A7tVGKPlrN4FYfCRNOaOJdnI0Ga2bohfECgxqeERm9yxoNNJ" ..
	"jfWVbOVkVIQn0+zTLNnLs+7c19X3RHgJCSCHhLHqGFS9x4tujbaxyEYCCJyKeppmLSfYUop9jcjcJ0Y9rzkOv+V3wofFnk89rQdp" ..
	"AucUfBObP+r3cYYr+RxZnZH2hV48RLUUG/e4gUl1VBswF8RqiVqoKHy/WVPhqka8tvpsYMSyBiMY3Woq6/CLIQP+hFAFtS2mX9in" ..
	"5cyvrN+CiVgokrqcgOaAfu6et6bIB+Isa1twXiTov6Fvrt3fYJCtBznNy0x0fKnKhAvaRjN6a3S/tj8vDN4kIDjUYthzC/IHk2cp" ..
	"fYitTmaVB+dKOZefDZ0PP3hzXkNhv6VwHo9zaok6YGTyiBEPgwl8aIm/lj3duZ9LJCDN/nHZf//IVWCvC5qjmxT0XXkJJckVnuC+" ..
	"kgV95ZWR8opPI6PE28q2z/4jGrxTh+Wn6f2OR9c4cjtk0H9tofpJj3KuLVN3tyujD07B/hpUHdrOpmPkOTMIYz+rNXCY8p+buQ9i" ..
	"5s5ve0g8AA5KWLuZEhLMxRJqgJQUUiAOwCqCm+jz/f/shw17ZLwFJZU9F5Bv0A15PG0Np0qXrpPnYrSPbWvx2ocEEUc4o/kl2rnh" ..
	"vi3z8GsMCMEb+/z+NMoz65vzaISUi4qXHDGQE/ZcwUjYVP3gfkio84wk7/pOgR8siZk5IMCKQVAIVXzduPeJq+jw7nzdNwda23/0" ..
	"YLM7nsRBkWenYRbs4ARo6+oo0yuzsd10FImpp7JnxNrsyR92hu1S6TELC1397sEKYf+MRBnEe7eZfu8ConHgYKdttBwSmPszulae" ..
	"uhLvu8+BqcHq/sPv0T9e8PETyZOq3nk3aqFJoV4Q7Y0cKfZ3atzU6ZXHjaAvz7tXKFWT4MZW807k3oGOX2LbLXxCC8LL2RSvRnRC" ..
	"60GX5BZ8Udfp67v0LvXfySoIO0t03kiqHC72y+9e4uW2KYx9Jmz7SkvJhCpoyUiClmHT+UkIO+KrCLQxPX585UGuOwpVfvVvehuI" ..
	"NFkikNWpNz6BPWhe9km1y/VsXLh9bZvWnRXDHzGlv3qKX6D9zPPEKWcOmV+AgxZXyw5zmw/0ZrVNdo7PycECU1smhAxffTVSjfQH" ..
	"3/a2fNNPvLAXvzZ7Vmfr6sd5crXw9/Dr9a5+OwPXVzICIphtg7zSNOrvg8Ao+Y8gXMQK5dkB/j4vrveInZEuugcF6XFXOJkAx6aS" ..
	"ZA63U0Vi9TM15q5n+04mB3fbm0ntmINSwQgoXoulNFsmvatmn9qFAxSbYDrNYJ9B9KcDDk89nO2h95cjK0NwJhrWmxWm/DGiDHLj" ..
	"yZKZCQe/ZuhNZ8Re18K1R1B6ahZSKTucpDu1zitVhG9/kXP8EPvmjUGgX3TERXI5Ns/ubVkjsLXaI1EHc4jRhmEn9xF/K0yBNlNN" ..
	"AdViQEV/Je8g53Sd7z1F/vOk5Bu1I0IvgfZ5ooZhZi30WTRGwHQyEG0nnwtzvPVDw+GKtpHSuB3OaP0wRmtRiojRC01TU05ZT822" ..
	"8x1AgB4DJDkMxJDCDKMOoHi9LxLBqehYtDhMH7lKQyJEov2WsSdw4PIU6DJnub7fs3n0GdoNcReYMvKu9Z9YAH/2fH7bT7vRGaBt" ..
	"B9dC6aahj6HNVpxiSjTTwQaNfgfDZahWwot+QE2MyraDJU/53yuhGkN+bt51JFOQLh/v/mRATk5PjiVjHj27jdPnIjxgwbmV26cF" ..
	"gdOKxzePRRapztQ7lU9Ks0b+8Tth5EXF5RruQU476S8tlohgyktZ1WuJyPtOs8OCRYvaKAQx1mhjDTDAobXJZvwFAkWWo0TzJd+h" ..
	"FsB/Kd5fbEklbjP/aqKEKBsQpcrVv0qUN4g4L2+C02XkjuFqwUlHlAFRKHl6VLeIwwKOcQovfPr3OK7iXOA4g2vw7+cSbZzAl6mb" ..
	"9GYa5STIcN7+VrYXyqXmbVXcuQ1ZdofdT7QNzNX1d4sanc/GZKNGImCpa+6VyRfM9UA/dUtNaB2MBBz5p1+LLP/hz+UVUq73XGZB" ..
	"mywj2O7pyekAd9fL0NLoiL5FvoReU7yITsoux7VQIDuxjZbOHm/3/6nQVf6lwoLScnN5RJq+DfJ5PZafgSNIX0loJlKT0hIwUE0M" ..
	"KmOtTcFSVrsLYxHcF4anJa5qSMj8kypZxWzJ494Zx+EHF2VJaW/A8RY7KnaUSmHBVNfm/uxUQNftyZYVMGC/ox/pLD7SZnQPRW6A" ..
	"JHMOb+CCwQMdEevRY3Oocudnwf3+vDlGpbl7KeeOHuFmc5Ze6ZWk1AsiPho5SRjcE88mODQEnoe+OvR78ld9v9GhKjMQpL2R1LXs" ..
	"1R+z6jsDhR9AK6udVS+MwvqpN9BeDeqIf9gYl08R28UG4utNpnqNEwI+19dM7ci8IBseHkqmonswjCviGUgYzyaXUDZeBIbVJUl+" ..
	"qh+egIgtCzUTYDs0NfJ6YMcbaLTwqe2H0mzIdisFB04t6I9LlSeMUI2Z8jCNs1LK9pQyRhUhmTiy4wMKVcUFfGjg5rtVkpbZiXbE" ..
	""
local PAYLOAD_P2 =
	"q488UEXPjHiC8a4Mhq+ARVIZ1vgJ3+LbkkvI552+U7vlRZfFDbTjK6PE7ccfGhU6xH1OM7MCiRtl/n7GzHm5HsIcnWw4J2Ai4xNf" ..
	"/GpkKCmO39il/EfbTYjIb1QZbamQ0Qn+N0CFoF/1bo9kgWFQ4hRYiqAVdUmplPQRlsaxyJfZfQGcDTIhq63sTs7W4RdIqCMXaK1/" ..
	"+peuM0QrsJr+ON3KoSD2r7sUoslnSSuaz4MWerAf2uf6uW6+1GckW3slcRIZVz7Hyh+bAlx0wN61zXlcLaz2x/J4N2Vk1K7BaRc0" ..
	"4KW4R760M7E00gAi4VoDR3DH1tuGx6OJphbwubSszqHZpqVn0jy9WEEo4lSZfkAwmWMkGMtCmfFNkCBfaOZ5OVXpyBjgPCZ/x3zk" ..
	"mh7DtYCG667yoMAgXKiHYue8MFVgO5r8cd12eJdkurqvIiHBUIWKbuMeblG3ek2Uic1t+05IuXy3GP2l8k0PWKxdn93y0F4THpaR" ..
	"DEh5VXIesGOA0OlGEe8oYji3CrhhLGy+Mtw3toQWJ69JZEGPktB8KQlacjYJ1VIf5yl25WyxbH76j15YNl1yjAsaPUQlL+RXaF2x" ..
	"WJ/5KJoye4DHQOzzmQFCE0JmuFSvYXAivsWLtkEy41YPh1nPZi4Zw1vA/8ZJ3sbbOaS+srESR1gomETjWG5IiZjMmi4zzfOFufwP" ..
	"b7DQ/uRwQchPoPCTIkgekdnVt/O3HNHeS0/RjuiuIINJtm6RfyToKN4T07sHQ9Up2Uya6BfRJHwyzqGn9tZisNZ7hvigehO4wDvy" ..
	"UF96J/ap2rhv0venwyKFpI686t0n1k/UKVnYnbzCSQP3MRR8dzz6cd4aNXa9RNB43+5qOCxwdlwumt9rGhTzeBD0jh/SvVHF5GXD" ..
	"XRHy6iCThTCmhcnEn4XDYVfusvFOsGXXSNhUmmE+igztUbz52A5WNknl3IIRKfZi3AH9NtC6M58ms/1/r817LTmyZ0AGO5uVZjLF" ..
	"E9OD3yuchyy3tDFrXTV2npPMf0UubtD9VbIPObx1WXiLb+t2G57C9s8vAG7/Z+5AWJlbdeL6Nt867es648clsGUIX7+BDo/e9mnd" ..
	"gUSgYGVsjYRk8HkuLEluiNBiNjCD4xBvefrIYc7/LmeIfjSz58s8GxOlVoo0uXf4LzjkVVMb8oGeqWvGk0jDBFDewam8kDKs5lPM" ..
	"SweBkYt4moKYvwrGnYp8L1dwaLNrR5TYN/GA0H+a19mV/wdQsOMfc7ggEPavTrH3T6i8qyuMUkOioh0vPwhPhjwXyzoH1VIpw1qh" ..
	"UEyIeyrgq9d9L9dMngPU0sCkH0nKeHiOGHFGy3eG7UmRs4f56NtkF7JLCbCXCvrmSDK3wf5aWuqrRMyUieqXYWwE4J0GEQbTOcZg" ..
	"V4OlvT+REOxE73EJFW78N6pAn1GrcBLTqrywO2BPGjO0bLBrqQU7Xalv7BGNPtkhZLsiL0ef8sjLP+Q4MKbU13ruE1uXVgs5w/SZ" ..
	"oNVSREwwbBAokKY9kAVi8uc+tRW6YdWgecpCWhHDe/lN6zBAvc0AHVlRaU/DfvZGU6IulJR1dWtkkCZu4rPvSbYs7DMh80R3aO1D" ..
	"l/PSYNozVsq36PEx4Z95wR57+bEDtL5DTdZRPWrdF6xjGs4A/43SZ1LpI8tgfm2aGmqzGk3ELlrDkewBuBFZvhDOErAggiwxk6FC" ..
	"1bsmFFWOYZCEs1AxnhiPtCTozUBFFdH5qAIkzXkuRY+N/I5tDKoUmvT3jBAsThDqJr28Ei74nHxuVy4ag1WWbbDj6gSglIKzuLfi" ..
	"EZUtGJNMUjDGuFAdmFloHf3aYS6CM9BvsRkUvKVgdGvv74L0mBq8GLXY1C/bYYdBhGNierQCrqlW1DmJH3DQhftfc8ST8d/cz8Tz" ..
	"siAP0wylUlzkn+vrTlQKMh+M/AktKjLlNKFM7vT+9ZmDuQvrKQDKmJGR2yb4Y8CxmQDieRBOPT7xx5kexGEvwAJZJ9A3KnMrvQZl" ..
	"VEMZQJxCuezmlEfztfvkJ6nIdghi9rBlw2IhTb3KLau9JQtxjiY9mxUHrVKyu9PudiBL+EhQUT7hBahOslENLl8ykSj0YFDl8UII" ..
	"MU9smGBe144XAdExkQwGyEBhw3YYKvvzWVWA95YCRKimoGH7HJomuqkaQHL8U2VmhCLL9tZIdcWTYc8ctCm+pFc17WUHIrqRdlZG" ..
	"wtP8/bQcmxb897et8NXocss5ytpBpY8P4+Z7zhs+i38rgDafvE3BLHv0JAK5JdaGpJzTDbh5aoB4WQ9pICGE1C5g74hromQxIMnb" ..
	"4Y7B0Lmaei23UDqbsxecjJSJ38czgYjSJW0SedQQmCMztmULaKM6XhakYS7sDlDuIS3Fx/kPhs9XlatCYKGmEFdiSls2oX63SeHT" ..
	"FB4Eh6vR7SoTBZJRjUXIXHmzX4QIkX+cvcX7VopKlYX2hYl24r01VIRstv5Lh71oZ8H8VA+ljz0IalG6b0fa7JSbRnNLCTYXuZcP" ..
	"/+TvHTwLnnQOJbz/hjr4LKzorEYrCrgVL8FutxpNlRi39tgpHRlSNJndvaVlOTUEba82R6a4iMT6iRoYXmdRj6iQM+dEFvBHoOcE" ..
	"MHFlNouFO/VP6/FkryuQyGVNnd6Dv0adSjJMpAqN2ummz05wRdRB62nKLan5Z7J/MX0mAP6T3qcZjPWmzXrRPJLvoHEtdJmPj3RM" ..
	"gpiX07/g6eDWQhv0Te0kRZ4oK9W5mfTmv9nj/grT9RKY29EuYYQppa9H5Ymbbiet5KQU/rlhfW65pDYJvHe6YaqEmwdvRt2zYQ/M" ..
	"7QAhox7XDYL7XyR3HM46vX8pt/A56ARbIGer91SwkFH9hbz2RaITy3JIE1VRuv1nsP3Vwny+cdJ0Wc6jQ2G6tVF+Ea3A0S8Yp5jg" ..
	"UXbIGC85i9hZ1W4u10ZRmehGuoyAYc5HUcoBHPAGnJ8xwPClJXG3xPCYYaiQ0CDqaB6RRfkcn5NOQ9SkoQh0zJUoIbdnyf9cA+f2" ..
	"DSBcGKpP5mGMWZgZPYhU07EVhKYigz+Hy00pmHOGSrqwZbgZxoVNAOqOPSfZVITLFcny0bePn6XCqWd4/TVgHpMjKMFSYpGoxihA" ..
	"5gxPDs+J2z5Fma/Ts29h+lmwPW9gP0dzDqf/HHExclGXDFj9yxHGA63PWfiJ0Fod4D4MXtC1OQ+CrG2f9KhnT8zT8wzcEKWpzNcr" ..
	"KUFpZtT6R/Ih9dOq9JhzFmA65d1SgwDciUlYI9Ut5XYk7F4cS4052Xw8+L7M9tZU5zmBhzwMlL9Xbn47zemidPrumWcyThObqJ9N" ..
	"kj0V2NvynUYZqHIuLvbrHciJQYuoV/omHyqbvmUSXoHgd+XcWWtG/+zUAclIk2KIwVEYa9CMN1xcFSmdmWJAsZ6AbHtMbVUwxEt+" ..
	"z6Yu63auW+m5DdF8LN7glK4Q8wFr3fifLoBuajtTkSzcAMXNn8IXGcVDNYp5zrSqd3ez/jSVn4SLW/5EebAnHzWfrz5qNt30bTzY" ..
	"j8yziHOOcLT+nUgXAT70hj580g9unpTxzbVYqfprgPp4NITLGlp+gO86HVbgUR5mP16f4i8VlLhrZNcBDab4bVcJ+p8xL+W30bze" ..
	"t5YiT1oYoByzHK5geb8WLfdrdeit7wwKW1P5y2u3NHKpE4VeAsjr/EKC3iWQlwpFg9yS7AEKZ51M3ZdhfB6+FwmZ5JJPmqTwYZS9" ..
	"UNvvRBORm3iAsxNRNilikGt8+dIupBKTpf8XLFi1Qd5Jvu7yUup2/wJSq6PIdgTPKotLJ+0nqg53/zhhfjRNc/5ekdqLs3bW0bIR" ..
	"80urKIM9JYoEjovH5S4561i4PLGFRgb57kEwjWuA0rBt2RAyxr1UnhDY1hcRyqgcoIxF3oUUHMjA8PJ+eBDwRL9Uw9bdb/9XmdhY" ..
	"ScSufRl0cM5OjATHQmfziA0la8hNv5sfK7AQx21tKwvkBt7XJKgGwmOAoN2MmArH5Surjtx5Syt0iZj1oxS7RC/E/bKZZ1+IV8Kj" ..
	"MkKk0GGjZn6mT/nkJCdlngsPhVtJdoyKCylkWDgF92dRet5SU0on9Y9SRmpO9Vmm2VsE0KvFk2OaH5CHTARKqx2UsAKjrB58VioR" ..
	"VoQyqKzl5OyPVNbG0SQYRaKXz73F1/HR8raRN2Uy+0PjReymzD+10xGn10uRwNzo3zfkdMU8zGkgxHAxcaxShv5gwygCMrLpeiyj" ..
	"41btXB+o8OgKMseJjHBc7/Nw9vSRt4Ad9X1SDJCOsbWeltR/y2Rip3rn7kP7aPrUY7C6QpQXgKKvcfDbRUGcq9O+8EpzKrSmYRrU" ..
	"K0uzmTjV4I8Y1bh6AuMfQBUysGP17c2g87f5IcLg+LqRNL4Xf8HpHxJXtB/fzqQKR8eGo19Es/Fwx9JtoHVryQIT3vuTmfzmwXy2" ..
	"sBhfNMy1tmOWRIlf/CyMwhJcmPWuip8lb+Lkz/HaV+z0TIAMF+vLWk9YjD5dP7LT8x9L1jcTuaUM7vgpgsT9EF5rpAHXZ7bMvwDv" ..
	"SFG+FfBoACDjhMWAQyX/WkGw4GfmZkBlv+ocs1f6nBX27qek9cpAx3ckXIoEiZcU+W+8O1WMMWN9FKhga25VyQKdCIRIfW2tGFML" ..
	"tKuAVtRnrnFCopiNCeq5O3hx2sJoCXeTsd3fNEIjUyV5ZBdkS5a9MimAG5lum/HOElXnq4YrvKQBM3lgobSn5PY/vMsxKMQ2VHBa" ..
	"LRFz3RqoBd3sUKXtJAOpgX5SE2TsCuvMYqGWXfQ3LQbKu+waA0Ll9YUH1wazvYxsROUtkAFNzCF7Xk6bJhaf1dz31YIO2JUE4xuA" ..
	"Ww2If/Hpn3Ne1mOK2vWg8gbxtI2fgCOZSEWI+8x6/FYJWgaO8SzcbtI1M7Ij/e95jde94KSx1eqspPR4sgAZQ7Vr+B/z/rJXWyGy" ..
	"Cw3voNsVlaVoDtf6UA/eianjDKxLYKJJMZJyqozyZcniEyC69OxLLtEjAehcC1OTiDjMbypSr7+VBbgawntGp/IJ1NuHbRnC7gYj" ..
	"zGS6P3xqsWfvkmaHXL6ow2f40cTw2kLoSX8myEuRwGxfSExeoYeC9cIgMzo6+iSQx/EdcvlkR7lX4uze8o6gECE9k+hZ35LiK+M9" ..
	"rUvVHpw0lcw/hDjJCCXQGmmTv0uaHI2JXDKGNOWJnkW/Hz0mcRFTdx8wFQ2RUiqKdmZACn+9LOIEoJDRE422LrDneybRzs/REqdl" ..
	"ep8IbaecCLwnwJHQd4376gktAQCNU2vCB76b8dDTqUNn6FFwX1bdD6FCJqeaM56FjdPXEk58wSVHa0ZgOiLow+nwRs2afEDaSz9C" ..
	"WgckS78spVvUyWWReoAyrG3cWZgjdUT2eZhqKBJfo2YdpEnia4ge0mjDzPN4PbUV67GE/8XeY1kfnavg6lTfKLOWEdjqluB54h3L" ..
	"bjmidCgi8aP4sIVZgx1uVHpLlyrdt9ZQ5QHCo/vrQ5r0X/AyKdCe0DKldDVURXKkPijDqwm4Pq0k1VLPrJjBE4GMUEnfP8Hcb5Hn" ..
	"J+l0z/rw0zl4Kj5nOf9Z59DIz128cfcvPsRxvAdtQpa9+9LRIqY59SFl7+DmnlKgwJrUtJXPIzAsDtxVwog4oGwyILNzqsUjw2Hv" ..
	"zQs6sUJWTW+SndYgeqPU1g7oqcs00y+SY4dlDeUns/IToe485Ro4KCtmD7KdklILNarwNqevZZqOLeAZwgtV/1dzMrV95nzRKMiN" ..
	"R6mGwZujZ/ShOOVw1EFBjaWjYLKTBb9JWAm3XMe5M99jfYb/Kcsz7hYPXzFu2jl1ASz2/7FlmgIKJ7fjBtxEWubHDzgdkMLlMHvf" ..
	"bGBdItCaUv7beTl5z3Q3/ukrjMAt/7fMTT9r/1oLmA1i2Qy2cnWfsHfmduBVkK+K4KgwD1HgSC2hXQmPV4sNFWOFFdPvrJpXdMY2" ..
	"jCWlOcn9ivovn3ZD8Bxdz6EMXAl1GKuJbBK1Kj57YmBcMEc3ujf6Idl54P8Kk5Ytr19UksQBj9B2kezs6AlVfR/OqIzNCzG8B2Y7" ..
	""
local PAYLOAD_P3 =
	"y8PvnRac6f764T3y+/XnDr3y/zKfg69+T0FVDB9jQjNc41MoYp9HhxxDkuVUs7ZlMAlCtPS0iaWq/PoB+kXa0QDlC44nMgwRc7yx" ..
	"+qP669RzRcRGe4smzReIW5chWrRS3sLBLH0BaANEFnM+hBHEf3D5QZnPmiex+i+1X86IIS1pZSd8UTodAGjScYdbVdGsQI+QVgY9" ..
	"nw2AU7eV/TTHk9jctai7+QrGLAvP9udBxAxBEusg+ho0oqKRVh13wbDNcd9zSzWmtd0kxjcvVcYteZxEeegALleZrwoLBfXuw/XC" ..
	"dv3gGlSc+JZEhtsul6ZI1hiaF317Ntj6HlBqkfTuRDtlrTmkTbjSzlYYTcVK3cEcB7EgzO5EoNiyQhVhORRJNOSGLAPPK1MjCQFU" ..
	"GFG4yAn5RC/kzd5fKcIW3OL9V2bpxv88g4aUrr81aBz/EpSEeS3F168PC2UYYdMQ6jV6RIwjPP2DmOvTW1UANl6esB7scLEZTVwn" ..
	"7L7PiyWQl9/Jfv1NGx0a3Lsy4ocdMLFJYpgcuszKnLDDZ/u010l9MR5djBUKNA72dK6V3IHwkOgmMrMqosp04YnHw9DQmtduEESN" ..
	"ucLck1bRXeS4pLbqLXvy5YF9aUFpgAb/Hj1ck6vJu5j3dggxn2VIv0WOtxh6oj8KdDtOwae8D43pOPzU+e3gPvatJfiB1gWK1U2j" ..
	"H/Gd9nytS1nDjVVp68lVtGMj59+fFFTsiSyS5feY7fLhg/rPrnH/4k0NhLqf+uz1AAS6jHFarcuEZiMxGJa8V1MJPcJYBzgGNMw8" ..
	"6n8zCPJWx9a05+LdaclDqawCZMOculiWuOcz6ukJXl39g2+5vvwR5ni34VT1F5Vq2A4aZCylE6RbeXiV9u7oWfLfE9jWyxGkW8dP" ..
	"RH3jwXBteQc1olROb/SkGOyXAxVyC5fgTjK5DglgTmWuD5GgnVIhBPmx379nbvs40tXy6P/AdFTYspKKTSDoijIvCfn3lhAWIQJV" ..
	"01U/XJ/BMQlENbtCJ5DSHBJsaV+RJ5eDwHEoOA+mSROQptJoQhzpjVqx/Pjnsp/66071f2JU5Xbr+Z9Xg1N6BWe0Zu19dxdurAu7" ..
	"L0s/VQL0GCkM/tQWI9qFq/HFZa7HZulzJHgETdnzwTtbMNgNXZQgVJ/JV91QHZ5q6dH9z0KldqDwByra21CQpBsHF1GeKmaaDdHF" ..
	"tIjwLUV8PJVVB5KSq2c4cBMO/heXtJAWYOfmpxORdYUsxZu4mItYH89J71k06jMGITliG7dAXnabE06zD3Ed++/1pssu/IvySmgp" ..
	"6GYIVdaPYlPabyQGLqQrUyyo6xocPsVqaFZPsCY3B47KGparEnK1o3I7bd8yfR6yFAEn21QtNozadTt5h1nnPCPcItrDZR6MPKJl" ..
	"pA8BaFsNk+Tq/reVkQhbkMywEnUCSv/rYWso0A81PZq9nSSqu9LQCOsITky9n5ql4VrauEqxnhgnvLV2hfigM7yO493mIyrLsAIA" ..
	"Q3EyyZ5rjCEQPw+z7rbINS7QiofDWmaxvPy1TJt0SVIWjuWpkyHFlCzaNgpyy+Dm9eDRcuiNBZw87g7/rODZWliSATuLy5/Ijday" ..
	"bhUZEtAepgNQBKmuT/GSHa8morbJCco/BjuRnV1cFA6tGFXz0Wn+RlMdwb7MfDYqQOVUv2Cs1EkjLwJ1BhST/1W+I/Dnzmxb7prJ" ..
	"HY37HAv/8DSuQvei93HE17WFSb+DfG2hqG8TERdme2tUHzHjOOM3Awf2I8vTwBXl8j2FWGNTgMbhrEztogjDV9+4mx76iFfp9czt" ..
	"yI4ILaLzhGd0taiu2LyOTU2sPH0JnxppcLNejZ0hBigTgsYwgEzh476tMWVaySY6VQbZJ4vIh6O6mqWA2WxBdbATQ6Q5zrAtOno+" ..
	"hZgxQFObVgA0SabrT2h5KoYls0hnZqBly1MrvITL51MozoWwJyyt7hSmBasDBTq6S+S1Q+mLkpugdMXgHm5yT+xHF9wsWaejiPQH" ..
	"5mhGMbYVfN+GtaKjR5zdw9IuiRARUb4qhQySH98j5pTKFmYMCZnmjaeyF3PZZgoP4pcqyR/b+SJbSJrTAGRY+5QwbpaVI4Ai9tin" ..
	"S44UPAG1zMij+njJ9cTk6qXZDTtDOemSgHCzb+snmayf3ksuXp49o4bfqqFSpiLOCW3ty7uZmLDQlQiNZxr7F63avBKy61JQGOtb" ..
	"ymxbxP41kKcu9r4DHuER8/N4NFeC2kLcjf6snXAhroj7wyo6ZbkWr41MGPHTUrpEUieVhhos7wq7Mrmgq9f88VtM3BtVXqQgjJrU" ..
	"mQcHlSErMXLDPlNLPa2jCxuAQwaIBFGlzPkKbmoO1AW6HvOxaecNx82W/ZJIVSS7nXyd3JUnbqoFfmdAF6ZRRhyyyvcRrNVu2LQB" ..
	"i7qmPYu50qBSEHt/KHSF4DWps1Y4rBrou7U79ItJCQu50ByXWKzAOUBWAjbaWCpffC8zj8YYCqPiyDj8bTmlDvsKyQBI0G9jSQnx" ..
	"q++OCapZ/7NF/Ot44zOU1QeZbzxGx+Lzvb79NNiDlnYMhs6Jtg4QnGJ+HD9a75fVt1m5GcmbLlu/h+hkaiCQj7eLEf05hyXt5sSr" ..
	"AojiT9b9yp+7r6UQaiu4LrcPTM7bAblMkkJ9AWBF1qbgjS1J33XcWcGBKj1gApyDaVOXzn3K81DxlKCdY3DT6lo1R5GAY6ysyXTU" ..
	"21Kf9gsXzl42Zq8cFZ459OLPRmRZt/kFtAS3qyWns7Bb17if9qM20epRxNfH8YuDwLSaNNNvCHlf/FGGgcCb2sjlasuEjI5UkC0l" ..
	"iDPXLYJBq1T+DyFhdfClDYhZF10zxudb5KrMiwdT30IRhP+4L7EmVxY/mtrYFEAoIHHmMSqNCj4LlUdlRkWSf2Q7oj8p/a5Dilqz" ..
	"9Esxx78N2fzlWM8evQVWF7zuFvpi/Ia3Tv/75P9AQKK1MuBNz6yZTz5C5hJf/RLhq4eHSL9bGpCuNzZJBLgwZO3IaIFSgQI6AAma" ..
	"tP4KVwZe+1yueFRk8N3jWbwMFkGUaAi0Cr9FOVRyq4C3RFTnzJ0nWxhkemy6gh/NqTEcjl7OdX24d+WFQ/+sq3RooEmceOEhRpon" ..
	"RtRphWCM+8TfXOcWlcZLaLCbAOlM938XtH9oBMTcEf3oQPRmS8VFP0NQ1mzzAqHCcybVSaEvUOBAgqAwnzo/KE92/XfI4ZCa3w04" ..
	"ajEfggYAkj7KeOjFGhJRRbHyHdFHEXc5oLtPULilMcj0iItwtqp46AZJj+oJtj4Vg33hMFz1Iyvn086wFtM+0/AFTab1+f17Z6af" ..
	"L4RkV3Mi8t+9XPvZzvTpFSDZjawaISFPZRJ9GXigC/2m8rESH4PeVYT8XtLlDW7bjBRuJjtcyfnYoXkPY507Lc1k2cS+OojANMGF" ..
	"9lw6MCLhdSyf3QGeLU94aQxajmH3dHOaSFPatqQQG9vxFT3+Gv/i1FREdn2PU833kpCVCwtpXZGkT32babmlzCsXzR3Pbk9rVOie" ..
	"x+Fz8MF+WyYXGChfmdLwWDRvtA6Nm45ET8IkEuXCSP1p8qb/6bgyM+gYlxZelo3Bc5ywbSjVdzXb9BSEHxXp7vn4Q/bKN6uqnMdo" ..
	"4qpksUpwKdwj3f08VXPJggpLV626/KwVQRj+Ji0jUfWAHgSGVKwgQbHZtid6bpppCP6b3DTwT4FDBHOFQSnO2JBfmi3YA9sClqW7" ..
	"XTlausBs+tGnU362LGii9wjCgwgWWYydIFO4OiUtdpnNP/DfQ9ZTyycz6s5rJFk91BOm5r0Ej7+burqU/m0qAPGs0QPcwBDa23gS" ..
	"wEayF11sH6N3HG7rAA5sgbTZqScFl5cbeIm5q2Eij1pTxEoTcWm8PdWyCflqOEUetjMFNk2AZFEpE+2YEauXlyfZ7ZVGi5MPSeiQ" ..
	"5rqx6kuRIYZEl8bq4nePs1DKfarHQaSbP55j1YU4ejvcjqvp2UUelNzm9RANoyMTMzArcQ2wka7Wd/0KBtvaD8bFnWSvPm4nzmxS" ..
	"X1YOjkX2o0VwdW7eN5aLJEwtD1UrjprWwjYGNXrVp9mdWBiB8ywCChUzIuqj1EOLjoZYlW94K5qiIQynt85N1RfYy/T+OrbR10+5" ..
	"5JrmjIpt35VdRcHAyi/zyWR7iNVYHsK8nFxavgI7GTtPhNsRkW0pHzKRROs6/ijyYLzoIWrNH82L+R1d+BrGwfQbjmjsCMu6RoTL" ..
	"5dRXjsr9/FwjfpuTkyYgJo9m+OZIwXuBfYoBIc5wDrDOde/ckcW9TPKESMjFvVrm8HFzHAYa4WKJ+wte8lfQnTb21Myu6OAsbd1z" ..
	"1RHR/YZLfD/M2J7TcLlKQlnO+PFuqDcwRFrhs9YaRLEARXfMfIvGjIfN8MzN7MFq90JFV/1aSoLsej6tpwIC8RskwhkBWy0TwsVb" ..
	"Wq7VG0WoyGPQU9t4f2f7SdTp3cpue/4gFxA9BkF1ic2XO1rpJ1atbSVokQwK3yO9oIsOcWABsZQ+6nJpmJm1AwRiOQaSiybCeN5O" ..
	"6UJgngQgONqFfhmdwBB+7apyJ58XO1l/eer7jCasUpbqEUUKXRz2yrlceF96V4Pw+oaVN4jgIKT2oLbjRrxiGKrvB0uqUEq56zmn" ..
	"hEMVzgVN2fOyG97RH4loNMWy0pt0dhvfbtbNV9UfSjgaA3exLtayBaC9qEuTTsE4VnfpriK1sFdk8Xy427SL0z//W3BDgNzog1E9" ..
	"y3/8gU8u2FVR0Daj1mr4HkJmoRf9HD6ZozSrCNwrwIZ2egQDlTQkiatuV4azFj5Qf49gQuU6pTbrao4NrOIhGGXLEijrw0XOJXaW" ..
	"EEnlL3AwBvOQgdwy/Pv6OSUIcIPgK5txtMdsj7ZHaTYFhO+6fjjqtzdoUZOJi3FQ6/PyNhEKLqwQi9WzEi3SMxbuhWw+ogy2kd/o" ..
	"HjMvo+vo5IRMAYUEm5xgcJu39f3BLLkobsMj1Rec7wfY84wC/6acZexRp0jBWKdEbjbWEgYVpKnSe0pOZd5ySlhUZN1+8no+6ni7" ..
	"qYX8UcqBjRkcGO2joZ6GBJPtyenH79yY3pd9yTgNotEINsw4Yeo/tVPGJGpj4cRc/tvHl7Xm9KOWcpLZACX6hdL2W0HrNFgyaugm" ..
	"awAgMTMHcmb9zJRCpFWL2H98F/rQpzcSIt7u84OOGBlZhFR8HOqZmaISab+B63JC3KwH5fXQjGTFvA6O7z0I2mdo4Src1f2MmUD/" ..
	"64KykIlp2orTkFXLmTduMlqHTy+nQ2QOxaiMXsc2iVKEWc/X0c3xZdh5thRhPvRbojAnnX0RZ3tSwFKLAk0Z4IK1NNCly3A24YTv" ..
	"seXMLigGcc+eHByjsVt47rp3t9bx/LFUMWet1zWPgCPJdQoT2Pen32NW31ic2OmWU8pzb+Zy4jDC+h4BTLnG+NCrBOqTcn6Iwp3f" ..
	"+lcWtRu7uXaxephuA8q+WCjMAD5JOzQq+SPbgBis+UhgvSWa61RbA1TJ8VOaMXJiSR7YFFxdgkBrQhYAhyNPtHpU/pdE1JNLYOPq" ..
	"JOwFFhqp7gdU2y98tUlK5j1frdSLWbejWUQvlCRnpcJtEUh+RMcvd8dmaIyq15wDYYCKycDE+4R+XIY+tNZ4n0aBLsddcafhXOBs" ..
	"oeR1XDYEefuE0NFwfh974606KVBecQ9tTtAZXB5gWie/+iDZc4Bu/2d3qFJ4U8sRiM+ZMLvtyJXZHZ1e2eAqLDZPQVJn7r+qyjqV" ..
	"7gEzoLCm5N6n0qnLr5novzN9JT1iZ62wlgFHR+Sw5rvlCiVDaQ6ryzHDbBHEcR764GBvyS8Y+1V/3FlS85kf8LiG2IWgijGIIRBx" ..
	"/6DohKXfNmIX3aykgYw3zJcPq0xHhJnH809sNXkSbn+5hllbV/aamFexxhSAQ8PdHWCPGmTRs/66ANg+TMA7t9/QmuhlBoWa294G" ..
	"ShPYUCeKzPjmWSqwLEO6eiJOaXnbNxQr3cDvK/V3LkqPDj1+NLSJ0Ijg+xglNkpJWk/lXfyUWznfDS0n3UkRMV/c1u4xxkBVZQWt" ..
	""
local PAYLOAD_P4 =
	"Iaqu96wng8w5XdaHnJLj/hQzQ6yEo2v7JAmHvj4iR8gQ9FHYRFNowXAELRwtuVmlG8N4TOijsIP1fQSGIC8ChHb/2ZqYEIVdr8MO" ..
	"+2lRY9YMyONcSFnQBaNksYLeN6mbgnlC6M53CJn7FN6JlWKvdd5iUVVIyGveokM7wi+MJq7ZgptMs63HfluYudPVtU0BSyKETGO6" ..
	"W1RLPBkyhr5m4e7A14uBfsZvcnp7V34NplQm2W6RVbK8Ijr3mXYcACl03ofpl3mtXSywOABFjm9GxMtBf3VbxFTZwloBM5dMogkF" ..
	"+kEtcAZCWdidex782Uy34SoHsz6hhBMh6dgMijWZveH1LD3DoMb9ZdwVLlcDVKnLzOmVT8RUtuG+SERspAGZxEchblOybloy+LIj" ..
	"kRZcT0no5DWjRiVwuEmuVetp/+ZJv0fHyo54SsryJIvRlarIMocyjSwgEpL+Tb7731Tw7M32yhqetEHkohBF1/bL4ZZAHMEOrPyf" ..
	"BcUtLdnayY23ad5GBFx4N4kR/BszZvF1PBuHgb4Z/vgGV5YjcqmPRL65T2S/IZgyNflp02rBHtxvn+cEinNzYyFBYrAJVEFBlFTC" ..
	"FPMEQD16FNhazni6bhIZRTY3sGTGaS/n9/w0br6levK9cP6lY/8hcGwE0Kp6STrk6R+yY8JnjBrBvBH9rTq9z1tF4PCJHuA/YioE" ..
	"GW0Ai0x8oTKbVKNs29JFCOMNQ2kC5GO1gK4W064QseVzuTGeRMKOq9SgLEwVIbeGyang/2JdDKF6zJVRIb+Qdacnm4ZKJZIWkdbD" ..
	"LJZ5O3mIi1yEsmrFavqSPCwKELvyJr6d49nPoi5YhbKIQRb+c2/iHf87I7bIwFJTkSvtddfnJU9UZ55J0wSFEIl27tejhfOYznPR" ..
	"KXiI5xoapvm8FGAWjqwKbQ78u//rUWzfkp/K0jECWPKpJVLvaTFnIw2n60YHtOfOvDK4SXdpxD8toOWkpKgvpIareC7zBjyK3ayb" ..
	"aNzUP8w9bQZ98RJdbFC0r0UPhupXOK9I+yinn1UVpl26rp0Jz8AwEm3CQYdl8wHTHda89XdowzlB6TshHAuFkXfMpiAf5Q7g2Vto" ..
	"nx2e3xrRQnq5eP9hzOMSWTlq4+fb07jAzIRJtPN8cACaDJsO4v7XixvEPxW+x9Su2Ch3XHVNGEpHY15L9OI0NM+ALghBd9c71UeZ" ..
	"z35F63tucI5Rw9dcXRRbbOVJ4adRGMV9lcTMWWJgU1olJ+/RVvXDbd4Kyyk14QfsVr+0IRgtPWhbnJqqKrxkml7YkqEjmM9MBOWa" ..
	"igLsz8pTuF+rq+ryCFSUjs5hjFKWULrCL0hDmhac8FzaRbcO9Mv4nwS5lLzRykNXFWT+gf2uhuxKLLFuiujCuN3gz4IK+CVZmaA1" ..
	"JLKA2bXmVmO9d0b5Cyl4xwm7tMhJkEL22Yz247n6Wj5HTZkjs+GvACWMgmUv6JNTOeJ4b6Aj9Cw9yUwwIrLdtdXEDRr7FAMXkJOe" ..
	"/RXuiaLRdG1YUDfb+FiLxCYEFJJu4NY9jyP8N4oAPOMrXcaMJId9ZdSCMEhM5rLitH0lXUIgOIxpDozs32S1IvVSesdOP1WCCtM8" ..
	"Lz3ZlC+SYQRVB9jQ1nX5eoIuhzeMNC0Eh+QPdcBgU4KCOxLrWzcBYM6CLW51vTLgyDv59UaFTaakSBeJOswU9SSy226NqqMOsy+3" ..
	"w68Rtpyws2emrnxtRijW+mYHV115YSr6xTKXK6+nV22yTE1X8PqI3XzyqjLOJrGaRXBiz1/mBGgkXyBkldW9lqrZJoFMsVGX5t85" ..
	"yu0s6oPMJKpgcX/GtgtcGiFrWnx7mlv2F63f5NN9Fs0zzZgSd+IgMfp8PPNf0ayU9aD+Yybr2B3fqjYx5QiGYYhTpIotXFzsEtmQ" ..
	"FnVP+ZMcJK9vYheW0qi8gVaHL0UXl46jSDIXjSU4unQZN717zkzj3tgoKuFehf75Ot4XiAKQhkq/YsuSWe2wvQP9v3M4LBay4Ugx" ..
	"G8t1l5udJjf2qPvhV5YOr93+DAE4omNDaSxu0noe+V0JSgBWKwEcUBij8F7dz+TbRe7WxiBLaIFQ4tkNkP/CdXvQ1EzHdfv/rkCK" ..
	"x6MyNryLMUCYxHsO8Avm54zUGnn1X7l32bG8NxXPx3O/IhAL1glc5OFA772MELQK92W9+b388cLJ6gULq3P8HyigRlmKJJSYweZT" ..
	"qhYxDRkzjOtofUcswXDQW96tWCWjKcuNwaPtMhQa9H2NTJ9xSebxEyI4SmdpJfg2eZs+LqxARn6JlanKQ70SVpWblLoUfWwTeTJP" ..
	"dvgC/HwO5v62gFA0nIIt+AGPV1nKK06v0hYtqvOVtFOeaQDu3v67zUYY5C7wlQnYTKNN4Ey44tqQANEdGCs0Pz1pu81ESqAMERTT" ..
	"bbELxPKAK9u/ZGp1BUt19/3w/+BX/7elvc+Lxz2dv4bmOJniJLzSWxYVZo0q+R8BLLPehB7TGHmXw7hfkECROwPhxqR0RekFKMu8" ..
	"XK1IZDfnzfFnnkGlcf1cE4+mMpFY7jv7OWHKuPUvXFiY3DFNXejxrsaMcM68BRvpyyp+w3ZhImISDfBa5LyBC5uBZl65CmpRGxeH" ..
	"YHG1GkpCmM90Evu0mihk6Aw/zpz5d9QyrrGd73vCkjSo2eLcD+p3CP2O88M0ph1Oxar7DEQfFrGnDsd5yE3tBClKdwqIgd7ynaiz" ..
	"3fCtIOZqZgRyMaNrNb5680V9Qk+RfQO5IvlzLqscSsn9XuEi7OQ45aTLQ64MwD5/uTUH8zcDABIwmPA2T1rfcICktZ1JwVW0n+J8" ..
	"3xJWRoCC9b2sorCe1d6963hlL7T1E5Jb6c2e0/UerWirOOfB1twrQM+T2N+GACetrylbxeHnc6cWPxKl6+Brp1BBTxSc9zUPggPo" ..
	"vadhrglQCcW8dpqarO1NV+XbuRwHa9MrNArToPXeNQ7TH6aANc/yiJLAox90QtUM9va9bZv/290riACy8d5K2X+jWHUmSUWzsG7I" ..
	"CQeTieGBtDLEENMmO3021S3ZpDWOmTVX3rbu2VI6NxtYNmjisNpBc5iBxHaLlKw3LG9SSh7whUaALQ2E+SFXDZ4Eb054f9twJVdL" ..
	"mKG14DB8wgNYn2kYxiWC6Bo1eCjstVKskaxtnxt3DheRX9avQUeYWdxCQrQ4qajzzUESTMiMtDSV+Gu19NY3Fqq2j43dcmZ82Kdy" ..
	"v7IrRnrr285YLGeXyELdM2IitG64xb1Uay+Cbf914omOov3mA4ns8Q++CtK2lFI/XUwDRtXXzK68g2VHuX7KLuRJNCycHQC080d3" ..
	"ATYwzlUrUUUPd8YkuQOEzmyEeyoA+kM+z4urYRL+yVlyDQdc3ku01wcxLknQ48IOWbj1CTbmplY+ljfIDjp+6vNdPr1mk9Gv+hXA" ..
	"XNY9QsrPcxF8ceuLjp4NTM8LcwSkWs4hKyQc/dzPPkPRFUzYywUBf4AtMyEw/F7geAhNGoQQw9EIolmF74y0mOSzr8FXZMbY2UIF" ..
	"gmiw8t2lQK4AI1MLIM30B0PQ8lS1KURhkcqoE6TBLoU2pmzhLqmGE+drhE6EuRBVOBCN89g9hB7+kvoJSdRs2REoNXOxlgX9yjhk" ..
	"3JtqhqrBJhev043duieiMrSAfuG0amV6rSVHPZlraPMgsMLwagtoQLqfh19lcR/ZFtBVBkZ62cN8FZk02NkEtvRwlULQv3CbdilM" ..
	"GFTkdmjVtiBySQBd1tUO8rq1ciDA8Ho+Ka0BImoT3dmgFPagJJ7Kd4A2ii0NyBqTP+As1/1ul3nRPMDS62hDoVvuvdPS3tQAUiYK" ..
	"Vr00INssS4tu39XZvgqZJZdcBaFPuRrEnDeaGW8Qnu9+YriZDXj+36LEHWKAb+a6xVQwgKuFBPU4PaeYVEAIBb1hgDbto2SFptOm" ..
	"84wThZpzEKQU/KCENMGMaM0sq9P6yI9Wot+IigsBhPHx7FnIohlOtsw3Gvh/Z1W7LZ85RuaXGoig42kX9VGqeuaGRgfA+z7GxL0R" ..
	"gy0grdDM8QmZiyitCy2dBiDvvbre1q7AIVuNlMP+vsPPpRZHOWsyz/AQZ8zocBX2aMiXysqiASre8ikBHAC8NeXjRUz/tw0ko0Mj" ..
	"YmFIpLXvYDUusl28svLzUvog1gKHZ5SdcuCQF6/n7VJrd5vnKmS4Ar3Mouqt0ZgBK47t7xhGKDbXBHLXwh5oCHi8mEXxKWd/3Myk" ..
	"+AsAMlzsz9o0lMoeDJ5doEo9IE756hKsEM98HSn3QRYe98lYrhEHUu9Osa6SuIB2Lp8zmhl/B2PGOfZfF7Kf2abLodOZx4rukAN9" ..
	"uO352mmUvFglPC5imx1eLw7tWcPlRbE4AKIoiwncyHOAWuK+//71ydTIgHqfP+xfwq21KtT2sS8lzlONUCeBuGHF6AxWiRNaeRwq" ..
	"r+Jci3M3HUQZwNNu/WpK2BU80V8XmcngTCckuVFgioHd2nIutRstOc5NPbhwz5aVdqUVLuEzXu4wOqRqK/nsBQzVfR4AZd4HszPQ" ..
	"GMG47B6MvAmpeep0pA1dlrZ9XsFod1na5o0wjeVMCEWk9KWjpN3IY2iUfJKeXVcr9nozJNv1AtMgFF7EIrU+Fx5rV+fugsGlivZM" ..
	"/SqHc2ZuOiCDHsKhM92caWau6xP8mpRonfNUm7xWM2LsedW1mGXK/r6uFbDkpK+RBRwj79KwbU71i1nmS4sLmEd2An1Df11AXLTd" ..
	"uEM6JEfL7MhWZNejF0nF0aIVdPBI1Rzso1CRKkBIFAkuTbPrkMxNYTU10Ge/kwys4MmbXNWFWsqu3PKy4UhrJo6CPKF1pqENa1/F" ..
	"WtvWUk7i7lCkt7SrZgZAwWky/bs5ZfEyfqjXxZAzweugLvmDlxb99gGsqIsFW6pemOCx4BBKW/M9uksmw8j9OO67WPpNoehYIkjm" ..
	"3LKF+KIGKk9wFhNmG6l/m3SbinL2P5/nm/CAuFwpqaews8TunWOeZBrms626UIsOKP9z13WefeNdz6bA8h+Df9E8P0sPDvLN5XY0" ..
	"8mumSbYL+y4ZYhtruJjrbIPhKeuXUSZ9wxtYNh0pfyU5zbwOTXw4uh3a5EteISHQzVbtIzq37G68qUCGANE0aBsVDNhdpNOfCWcw" ..
	"MBgdbqPuoo1hudtARCxiFMRqUCA8RdwPr1QxjGXBwVv9kKyPLG+9cQZE0O9PWAzR7l1OCChQBru5MxoD40/v5JnPE7sjj6anstKa" ..
	"gHKzAm0nKE+YN8LDDsC8Kdpch4g7ibtNdD6pjInxvRaskmFMpGx8zJM9RdmIfowc9/sNaS10H5ikumEvzxZmfve5mRAvmEPaBo15" ..
	"3NdJNA/Pta9PMHG3fxuuBXYv5KR7OOKVku9wVVkcRU2bnTZ8KkkzGwLvrpm3YFaExjkGp4I+cFIPOI4oHmUc+J9Wdv8fOXEqovF8" ..
	"qhDqUMK8dT4prLw+MepUSxVvL4aSvCucj77pP07veUenKL7OJ7sd+hTkj6w2QxAZUk/StUGTiriZvYt4FUvMrIIsM/xqX9c7LQAp" ..
	"BBvETIeoZcCElF4eok6XuLyKqhFdVMYWT6K2mE5uxhatovGeJqCGX+Y9dayDH+dIKfboW3eaLBezeoZuxYpShz62kGXpsPtvMb0V" ..
	"XZNrGXXkhn9LFlCgiM7JgZqv0iVS2cSEWOlnnqMYuGVXGDJqchjzoJdQy+CLoe2MRJQT5qu8fFiOcDckrQqST9lfMKbh/minDA7l" ..
	"Z2Kx2almxiDUGxL77IMa8KjUG+fH+PBwxr22/ou5oJcXL+rDjNrVggnb2MH1GEZQsB32ecD/ybUS7bNaHIti2a3R9WWMk/wRw4eT" ..
	"8FvFsWl2EDWRaGcRr25qpUs9D80XmvSaMIsC6XtiEK50ZGut3wAGIbf2AiAUeOkrqjPwU7d6/rbGfyy5OHvsTWAorcHakhsPtTpH" ..
	"Rt1AtuT1jAkJgd4Ebds+1FQhc2BY32V3F6rhHmlRjkNUQMPjg8qXSn9Io/3U0gWPyqE7pJiLqko3W4AcYK48TePFU8kYJPOW2Ctg" ..
	""
local PAYLOAD_P5 =
	"SYGQZPVsZKhEO9ZwxBbeC+hwKsvr8Yh0aV9tg6g4ojAUbVIXtCwFBROUYr5zi5m9UakL+xbPlGQ2vZhCCl0IfFd9rWt8LHyD0OYv" ..
	"H009ZLPr29qutxpdRCsVQv1GT309QF1+ayJqnuTeVrUlNynh76hZUxhzkNXnyWqktntzpvAAKoo0qPSd1VpdBPa1924CmNR5/7hL" ..
	"AsPFZCvcDKiMAZwjhbtyvHjgJgjeFMqRfm8TUbId3eeEXE+mXMBK0Eel7qWuas8B5zOObcpjDnxYX7UEMgUnIyOAed4lgPiJC7sA" ..
	"/MRKBbBMrQrPKlmYKxE3Ps0NyjVWk9cxoUwEoDMGO5ZW9PV7pfE429zndym7/Zbs/0zuKNx7/Rp1hTj9aoGGZr6Ho9/HvZUMPVDM" ..
	"uY+tixWgOzVET0KGyIHTRHullMhe9A6d74yvwSJ0i/1PAwbUtS6BfikhHX2+pGGO8PVvI/I5JoriJNMsa3j+0XWaHxcQRs8l4M4d" ..
	"k+x9MSUOgcXH33kQfM47wu8d6tlRHH+oW9qka/yG1/ZuWQPN11r/Fxc24lbugqiWCCImxk35f+W4d3AHlTE/XPAovvWkJWokvBM4" ..
	"bovEYoCrnAS91nn8A4YRH+ZHwJxxg+uAJNJfj6Hq1kL2S1TmOmCM262ezW5XqdOR0lRdDE/OL+MRPozJLhXDMyqRAxIR7k9l23hj" ..
	"C+p9n2hipJOwuUp1PZbXJTuBbbXykVI/1ARFLuy2EQXU3NU9NCoI155oAN0UWtY1H8tbSJ+8VEMvnjhdsjUuFMN6eYpBXq5dgIdk" ..
	"Oxx44M8zKdZBg5zvbGbSRrOOn2YORLl/ShdkNoGAAAtj7xfyLY01F+87SHOj87Pl/5wTWgs3JXuwclUBtPyvNMLu3loO2vIz34G1" ..
	"k4RQEc6Br55pfIQ23HTyezJjb3qrnBufKdYUNc5vdBm4zqEplotsShs4khAdAZWx2rxXIbPYTm83AdcJaghVl0ReheG0WV3T4EiX" ..
	"e4V0qf6ldrQMBxe1of7MQkD0IEuBnDLZWcucki07+hsVDM1vn7TmZ38H/hS3LVhy/Jcw06UusYxAUAqG+gMQuUDC4YLOkdBQxJUA" ..
	"DxqSuCU0bQET7zWs1ESy10fC/ExtL+byjIOp8KBijL+I1NIV66K0SwSzdEUOWILkMqR/sYfGPdH4Eq4UCF2RfbKJHmyu2vbTEVOg" ..
	"q4U12ohttbZiqUv070O0aE0Zu/OTxeugBCKICZRarKpcmjFEEpkCpaAxcHjiKDyH8VgJAfN1GS1OEGRSAYW9yljc7UZwLbpza9ID" ..
	"KqEZlpSWkTm2muZyaNNDQUXht3tbMjFKb41aWzYzy8FP4HVd6XAQednTay8ICU/w84GMbzEaSmG255r2rXUwwVIelWEQs5lOecEL" ..
	"2Vtt2dC+Ppmr+/meRXbShbS4JVGSFJ/j9sR4+60zKUFcb42ARRQKnWovE/OfRj08/y05URS8Zowq6q7wRyOa7viPgRuke15IdSOr" ..
	"bS9xk2O6e0Mtf5+DrNO+q1lWUenb79vZErxN3jPgDGT4LlRmgU+RhxhdxtOBtKTA1Q6Q2kRIr/5hlUYHJ2o1llHli0FjfbqRc7fK" ..
	"7BUq5fc0WylyVTV14Vf0VNv+T0AMSRenEqdF223DxV7RwtYgv7AZ9VN1qMEatV962ncwVmD+zhJfXfl8T9vghlBq7kXuXyIvpYOc" ..
	"mKe1zr1iV8HbsDi8HxwOZdExadiMRxUY112xDM8ou5Fl4ghyyM+8iJ7CIR44kXJoVfN2Uc1MgBKbJFl8NHCATxskQaQWApAj0Pp1" ..
	"vuYF6DfS2PJ0VF+n9fGdAOSbHH7ysGpLIxUt6bPXa/izJqjk0Mi9Fk++iojnCpfWZe51gRU4CVfWf6x9jE5IWtvPSSO1ciHnlFdH" ..
	"G78ew1PwuA3Pg4wJ5Sx9+p9ceBopAQXJqFXUevFSytHGWtiD9HI0KDKPYPusiQGOY493IpG92Mcuk2v0WbOSebnQfX8ZoMxdAx3o" ..
	"EF2bTs304afJ3HfXGd7cgx1RIfuF4mP675KJX3J9iOmz4OHHlcFgEbsX8Ohusjn3cAlB6GsHQAFdnbnqRMuwka01H5aw2T4w7fi3" ..
	"sRRfdRoJQNOgF+CovAm3J3CiLSzA2uB/alpBplzGStzA9S27rBkWe1o3QHjC6eA95LGGbekp/biDTYHtf7VG59Cp6FpgERoSqAWV" ..
	"bGi3DNKwbJLCltpE3UGu80CGOOfCDw2SbtanfCy4OdJot1m91ZF4pa/YuVK0s9fPFYu18HhahuIUezJyEK9Ae1SH2YXXzP3WYLSI" ..
	"FFL4FR8G6p3QsFkFbjhfyLO+nGwFUBVK3f9PaobuPbOnNmw8l1UnwdQARxd8tUOyI0bK7o2AjeeBiSWyosMaCxClPWuSS7Rkn8F/" ..
	"Ndpm/2x/lmH42XnwdrZzIkq38mnIUxniQnazCPkPXvyj6PFk/2IzpcCeNY6PV789Zof6MRtJrEyH5u/RkajpqLMTq2fLKeLzlV7i" ..
	"rAH1KEdD0tfNdeI8SJVt8GoJpNpYL+Ea2hbUEelpuYnpY0dIfMDqg3heJeEJ36yP0We2OfizbXTccYc4wDIiwrBgdSsrbluslbsj" ..
	"Rt0Wwwh7izaXiX7geFG/Wb2+3j5YKUnPopeSTqodSpfLod0lBg3O+KN3kJKA3LUK37Qqz4gXKtU8HfEqZhFOA0VoDQ46U41wsgSP" ..
	"VzxRyGTLR7aZQ9kvDw6UwMzeRfvpuapUbrItmbX1OxdhH/qbglSHWA/oVkGtyVgG4IMnt9v0nvnlPyNoeJjL9BGUYZ+Cx1X1eeg5" ..
	"h31RZdAzemD6DRmFhmSNVDffQ9nZr6sWOthRyXYyqbgqGpDX+zn6WEpBtDbaGJKepldcrwyqcP9Me2SQqiUgK7GGuleQ2CQ9FBfy" ..
	"abNIdkDf5f0ZIi08ze2bO2hFS8YT93hLyRBxAPSPJfJJPXWxGiQR4pGXueQ+VM1hQXqedchOiuOlV6eqRfBC2lChxp6f1fGKhsW1" ..
	"8FzrPTW8WYjwRlmqPHmLCNsCDg+maJV3FY67XNUL9wtH88EjJaLMhh/tJ0FrSsZPlo+hCj67+dcGVjohPTkk0RR+zhUHMyLNBa4F" ..
	"cbLuKEwybD5DspF2kX60sMpq8/+f99RHxFoj5xeCWN2c6VHLY9cbtA8o2WoiGJT2WC86f/Pm+AJFNQKeC21ELfrD2mPnVkkf8Bly" ..
	"Bi2LpitjgV06hgaRMxJ3ZegyIfnISfWQxNeBGPz7QKc4A/ZD135OCyBfnuyz3h8dTe4DlxQrXqq+iQ4oDge6KzMkvhC8sXjX3LqH" ..
	"PlY3TRHigiGohQVzp7GbZiGpXyd3OOLnswkOZaLec1dN9l42b5Utb+b1qPXdHvnhnfz2ZE7O8TUXuxj8FBjebn6cUEH51IrODrrg" ..
	"LDc3GrfufsIxEVVCGT6jCbMcESbLKg7PUw8ZSjtAT+Y8voBSOGlCQQGhZzglpVITCtj+UY6veHan0T7X3lqkpIAxOxbfnOo0NF0S" ..
	"0Ts3ccn4abyKzcHCMwL25ii6pUcGgIcODyyAXgjt+ODAAtiJ4uSLNCIvNfTBwQdurPxMaAD7kk6h8TtqJ4MHsTz0CXwh6OF2bUuc" ..
	"69gJx1dfJ2E5ruCnARp3ylM/w69TWq1qJt125YNv8sK+DYdqqxSXOCdh/ALmfy+6SJG/YW/p1g9zs8T+/OxMjXuwWYkA2NdOvQpK" ..
	"fmO/nPJ6PkwVftmoNNy/X9iBlDHTPUH9f+38HaqInmBnEF7DZlQ1ypZ6aWpZ6kToVAe3a0Qhu5Dtf9FCwCOOrAwGot+vXDJlzb8N" ..
	"F1Z6+w56QR0NmcEY2+psqI/9PElFZ2bODnuhK+0QK9nA/JzB5gsLf3GaYoWoYcFEJjEWVm+IiKNV9KbHD0YNcnK3tRG9TXzaEStJ" ..
	"g7Y9JVKycw/z/X9f90SktY7d6J+3DvIi8T4UZQIbJHFkgXyKAHkAijEq21LR/XsRfUPbmJ+gwhVjVsgVWq6sAVlBEj8jeVrrkBgP" ..
	"PnIpCZ1Rjky4rxb9Emxo/fUt9olHTdrqyw4gEj4lgwrT4AeVTdd3iI0lJvFhrBoxS0DvvVFhg7N4EdI4tIKc7pTIwhLDTg7IVHvD" ..
	"akgB11Ygs3A7JntUl4NgUAIOs2kIlszlVx9saDCGPy4co6PRoKwfPawB58q/qPhgIbYwq8UqywV6TdNw+3caFPLg+LnQiaVlTVya" ..
	"EijUv9NCNSS4DwTCGERUWUG4Ejp+8JyZCoAoB6bPatcSadfjhjKaCLaALDnqdjPHMdj7fVZIFlnn2rVSKJCmIvRfhG966XCMn9Bb" ..
	"FCvx3isJoOmn4ykjzfcAFJLGIWtKjDgabepNR9Y1SSxChv+S3tUWA04Gw/rkdwCqye0NUORskE9S0GQBGULMStBRCKxh22e4vlNt" ..
	"CIPA0ggmbQI2kwV9P1Z0Q8uXvjKw6kdkpviHy33g2Uf+7pHWTAY3OpHkHoVu9yxEU8B8VoRG05hPosdjU123RGmHnBMJLAVsXnBs" ..
	"at7WMryfE+2yxoTfWGpvYZBiT5b9r1UelYyjqdo9V7htxpBJEtElUtqMY17vJ+JUaUpf6T0d2jN7MrThQC0/rNaVY6Jjtevd17fS" ..
	"kH1GpYTVE/NcybVwkW4UKoF/z2mURl4SJSi5OgPnCM4Z7g/K17X73QYBDSp/A5doJge9h69tY7fOss6eetENLdrvnrAdcP+7MUmP" ..
	"o2uaCQwZNS5Vh+32aMBsgwYDJglpFyb60Kj3hWZeKiynEJunw/ZlkW40DQT8HCldwYv/8sQrkw2xJHxdAaWZKeEXSMjpoP5i7j21" ..
	"ptxYQgB8M5PrSBETRgFH2LCQf5kma5Hr3yU0eZcv+ZFmLgBLHW+flrayHDdypuXXdFn2vTqIM04snZhsbHUQGL6/iIXQCsTdYVFx" ..
	"z8X/qKqtaoOu08/SY0LzUrsJGzRYHoGABPdKkMBRpnX+ogJQojeyP4eTTphBLbg6RA6hS/NcNCv+bt+8sBf6DUy36zaR/MFPluIE" ..
	"mtXR1OS4k6ecrAc2IiVcOYXacbusHGCRjTG4zmLrLmU+25ZJYVhDs0MXgQFCMOkpoVlVePbcO7d+bR2cOM0DntE08IXe0XJnYp6z" ..
	"/Rq1NSAgpdHqbASgxIVje6Rai4iW6xTnS9SyUc3Y1PPynfLiWw6M2117sOniWK7Qy80v8dtPlMngQuUfZMWcE/M6bvDpY5nqF1wH" ..
	"2vFaJLvCthMhZrlGGUGXLQRqZcsksD0kBrBYwTFyU76OfV+1lTMLqouWid4UD24oHTCg4TlOzec1G+x+buQGWUKI3pp53Gyw3e3K" ..
	"2U8YwQ+g6oUDPfeYtqlRI+Kbh1MoxrgqbFEzTJsv7FiVJ5YemoSIHNGXINjRObT2K3Ouc+Mg8/TihPKiLV2V66tyMt4t6OWuzwe0" ..
	"pryQSZ40+FjjlpDPfFNaVd8Fc7HfztWPA8CAWvxZ48UpkpyvnrIAYgjrwqzjsM09FJVg7xpmAXP9FJGVTM57Ck+/Vai/UFBs3MXR" ..
	"Cqg0Ib3Af5c82EJ1+/KJOFarXP0PEClw4z8SFzRalSB3mjtyZwswjzzRw220Mkr6S8P6hwdn46Pg482BpGKX9tjEGMPiD9+0saIH" ..
	"1Vc7NID1R+8GKQIEVc2v5Q900eb2N+ThT3Zg0MdUGAN4VpK0vSxnbHxfwPIZfeyLTGMZPOgo+XUIUrr4qz+ktUQKrWlbqaK5p6ad" ..
	"DADEvyc2d8OVfgxhMsexNcvpF3nseBCNgUip8EBvYi7Xny0TE83DrBmSrcCgk+ww4xGrb0Qw0eYIz78scct3DyIPeQygtXCJIlpC" ..
	"8IkGW5UsyMgPGfYh8857JB6lVh4vCr89LOKaHOHbqIxe9jiDZ3D2U2UYnSr12lEKgNcvGvGbQ1wIummmso4AeCMcLVapFdr3LOxx" ..
	"3GSRIuhbqhVkF026mIGkYGnFIRcc/mqVM/rF0K0peMmc47s8tEoM4K+Cl7jOptP38Y/A3rEdQbu8Ov+xc5/6Jdy5GiMnQXRifiV6" ..
	""
local PAYLOAD_P6 =
	"eYbn2flfgx6wpTlzQcL9KwoH6UH5ibQTAPmsVx770+m04ZDS4HgNY5a4nZXndkESbMyR+6UVWABRo8u/MWR1cBXnL3Xerd2ToSJs" ..
	"0s/5Qy999OsxCZ6K4zUtwIMH6T+La6FzZS2TKHWn7InER7dd916XRLX419zVkbkSPh8pKbIk/nfoSHJn3JFYupKhqdX05RBnkV3c" ..
	"H/mVgLCqRyx9dTTMXIKSgjUuMboeytMtSwNf6xCuBLADnIX+nde9EC2DSM/aliC4zWA6GAYRfCYgm18VTI2kYZa7jYLa+0bzYVkJ" ..
	"1N6KpSF6vUg7o2Md1AWIMPJJJ0HVKdmWsUMIhDHVTOKmYqiG+udFPa7CvD+SklI3gcdCIc15ljW1VQnHJbaizV5ZePfacQ+Jp9PY" ..
	"5+LXRbVoW/vQYBgFQw7x6slKBUmDKoKpPWBg4L51jLF9dW6kjG0FulLVoHL3h2VKF21u+nqvwhgpuH5phVoU7oy92en/+u4l8Hrp" ..
	"EI1mJE5G5TW/h1i8SxBcVm+6TC09xIYLuxZZoQpBh8pEhIf9uP9LHBBXFVWCP1nsaXgPata/bDIa5POfiYZw0fAexlqoUvXQ6J3i" ..
	"gZ3lXg8ZIJTWPktUYoPj7yWa/3vtiVRSE9WK0BKgbfvsaqdHD00sTquWTfb84068spnlvxMlOA1irns3WtnW8ntLQ3RZwJerDpFk" ..
	"Nug8IltlQSP34G1YtvFvjz2T8DzJQHbJwspwwZkwqWGM0xctqN0+Qx6A++qORLzGlxBZ/x9y1YT4sRQgkDmclkwHRVWO5Zq2cwco" ..
	"FjlVuVTuMWIO3Fjc4mOR1rOqn9FLIBBrO7h8WVKTloF17nM1WaDcVjAh803LibP/fm84LWk9IsEqZPS5YtZ4M6zRLn3jTbywAakk" ..
	"8pSW8CAQ2tn7dCSMTrhV0A4MHAA6Ab77/QDS8d/QDj3njpBilezdvsdDGtaBbzfll5M7VTqJ55xFq7NkPh+DVlfjMKeo9q5LRje1" ..
	"+qWavuFq6zBQRDTdOyzn4u+sOzN4hZkoJK8VVjvobFhh5HsDI1EdY+xlrm3IWqhyXdjr5HDP3UriybsSo7h5v9YQxWHqZ4B4PJzu" ..
	"gOZmB0eb3J8yx5XeyiBarYdvhpv9njF4FhqtwZsm3h99lv/Da+yId5bQGM/zRYELcYhL3krSoBFg7++BZEg85loo9R43qhrFmJ4O" ..
	"+uy34Gqi0d55CPi3xuGHjzCvVn1o3fEZX8hnNsQ1QSZ0Tr38q+vXf4UR20ZUCXHkEkVu5KFeASBSW5n5vuaJXUp7bRy/DYfQqA9k" ..
	"rUYarlwG/ilqCAfpIV4JO58NpTL+7QcTN3yyDsImIomACg1WJ+ZOYzSQkzK2kUBWhQqtbWKxkpQbYtaL94Ye/V7TUR1VS8KEffMY" ..
	"dkA9o4NbWINO0NnaBCGAA/XugvVdyfrngGMSdHwcg6Z8uMtfVwz4uUGeQjDJTNXTNIiq9lWHd1Or0W3/DHXusVZuNUPteM2dQ3Fq" ..
	"QhREX9sLLU+hakuqnS6/rpPAO55G+li1WdjYMFEKENjNH5di0XgQOXezOivFMLSEtP4uDOD41Fc22CdurIKm9aahdzdCVcD3Y7VW" ..
	"Lo+JZG5KJ94WUuhNTzQkyI11CE1lPIVcNushq71zc/0G50n+R1ovGESAxXEkfM8wZwSlbckPrgrcJCzlMFuwm58v4ol6BBMJGC+P" ..
	"y+qI+XH7nb88iuJCDn0LtEXFBV9xZLehe2utVMo60ioh2JQoAPKUluAV40TcsSxxvmF8hhKSZgakDmbYRrJMwYsFzsvhnrJopcel" ..
	"3FwG5ep6tJZK9QT5NcV2r3eSfhTyfI8koev74U51K3pMQHBIjHn685Xt48R5//D16TT28Xm1r/m6ubsjQVqTYfAemSw6S4gPQstO" ..
	"m40CIXPP6BRcXk3bIBdXr+kiyi8kLgy0O4WjFyGPZOs+YvRwy5/Kj1LHV+sQRTg3EbvqKqdSSE4/qMliF4Um76ulHRy663aDIzzh" ..
	"G2ejhgbnZHXTp964AmRrWC2EmNz/83j3tVq7UHYc95YskX1mSqihrngEsUZZQ3kASQctroqvTX5jqL1+XbiwCCMBwTwQzfdTipSd" ..
	"mFXAvGY9dQdyGDC04Si3IGx2EWJ/90nn4s8n3dvxZ1zQ1ELuWccLtSHLgeQpZ9AJYVituPZFAO9co/SxwO6O5gF6AL3HVY2i6FUZ" ..
	"AiSdp0nqbRHGx/SUOQBllft0iAb5/H8ROpe35I1Fk8CKSzOgT5EsbNShrC/9w/Pec6fpQx2lfHiGpOqayAcg0ZYTw7Uc2pLSwroE" ..
	"OJl5RgnCMC2LOb8bJY09dg9cFBiXojf4qOaSUDKEWFV4dFFfW1U0moAfLHC7ptiTnkIS6ZT9FFtYXX6VeNhWQcQA6przzf+rdMRj" ..
	"4LD0d8K8IYJcMY6c4GqEwoRpevB3eRMQ2cdSUSbS2D4GKXdv3xIqdrJThRPSWhvQUI5RYHg28hAGUJIAihGYM2LH6Y79SY/5wyyD" ..
	"JAqyRAwvBLCjQIl03GDhIAY0vVcOWWa0BAbrDUhzxn4M2NXW+eiaFVxDMk/9/rnlbfpIhOQuPT2ORlRIFkaJdn0keIhLlaAiPdD0" ..
	"wWOzmiG8A3+wr7RmivgVgP8f8HS12UMZXVJgrEiGIUIA1hePISa3KFTWBJTCe/YuYlqzUCQMurCjwvaWSLcoHnyZqvjD8+qO+ZBE" ..
	"Ky0URmvLqt8llO4GLJonOcBVPul1YQQ9xXY7EgHU0EXqcz0sbzF+i3rVN/zWQ74ReihHzVYMefNrfhwSlkldbUpxge8bG3Fd/q9o" ..
	"W6Tu9A0ymbVGEoTcfdLLd23e7BSV0seJGHQoOxmSkd1J4tScLcpeTsJkHANTNQ07hBsODmoLb0p25B499qxrIEw2m96sFfTgMRtA" ..
	"+e8wLRv7SAVyoy0qZEHatIJJdgwYY7DPXs0UUuz5aMF/eS2AKDdNaB3Dn4UP9LUFb14k+MLmHSynzpUS/3Unv+tNNdB/x6oAWmsh" ..
	"7X67bX4WNvTn0Ll6bUxFnfoRLow5CRdTECiJgF49Moh1ymHMdtcTjOwxWMmseZDmCSESfiXZ+wYUErrF+wTDAOA1UvCXy98srImp" ..
	"+tQjJBhMhOJHXmmJmvVQz2eZBhp+w4+VhP3NI3Pq5aVZnQ+U38gDNnrmO+cYykAJ5W0dcpIn3QaQjOiRNcGTIP0XZiKaszpkJVlr" ..
	"v2E+eKVhfoDcUqklla3m4AaTQur6+61KtjHfTDbD3lMAMX4QiQquh0iJWNSxWCWNQhFT+IyF0EbgKgRFzLnGr+MtM6slx9krl3T2" ..
	"wDsntk6jFdrenxItRyO9K5IpKW/sP+cpzG5vI5LJUFLVkF9UxprLqDMn0WioNbHfXoxjZ2CljgF+/UG++Vgh6gXBz3j4j8AkBclO" ..
	"DxWYsP4I0KTpVWb27HsxkVDG+uUpTAWyZPWvJJ2YYWrvAYhoZPt3lx0BKgk31OPMqObW2IdXeWnv8bIMTFVSgK6kgx16aFEwceEp" ..
	"4wiyy+EAYApRt0HOEEpwAcLgoOELwuaQYIr5RbW8AY2SJ+Ykg+fVBEmb8rzdoNCoEZlYxHidN4B0jUH78MypkkhR3aABOzdpMqoE" ..
	"3f+1pv7w5ukXMBG9+vkfnTjQnrMvORXJG8s8hcsEtdBzMr4uZ8qrciapvWjEFgUcvBuTS/xCrzXXypzpeSQGoNxqmLkfrXgI211t" ..
	"pxGmRfvfEUHN4aO6EFln5oaRDpV9QT5cXpFN5ZnhypKtXjvQr339IyhXEObgRqgc6+NtqdgCHpmCAR7e/TttYGO3JBsWdSwBznvp" ..
	"R4ACiRo/OrpPQ6KZYk4PyYzUgkj+2fWZEFrReL+2zJig4ajwlOCiUWH2cdpc7pKHtTHGDTEss7kt4ETTPRIxQirE2cceFebw7dvY" ..
	"KJ6hxUlibD5MNePUVpQOBoZiWvb5t26jtvL3esWfbKyukOu+hrGdh3oxfrwcCHUMEDkydKWgOT9r/Ayozu3D81cePgh4OBsrbDca" ..
	"F4V3yLZczHRBGq/zzZaRdUwBFYph/Z0uNt9FGXWb+Wq2zyXDHKNQvWtF4lrvPNpmHH941mDaG7/i0z8D5g8yzQa83eBPE47ZS7sp" ..
	"kmXij4eJnMvwpu+Z806zIXEQWL5CnIV2IAob7O47zDrS5AYC8N0t+hNfEy6inVACxBET8/E5Ui6vlhV/egmKXkqRAD9BRDmq5or+" ..
	"xv0rOyo++fGFQHzLe6jPCvkigg5ybjDCS+dnclbs4s53F7CwaKYPt3Et/Ql6NjCaEs2G/7D7poTuAtGv3Xc5nS/x/88Vf9Vq19dy" ..
	"gR3261MOEWqO2BXcV8Yo+qRiauJDkvS/S2rhvloAgu2MfqM+DDpS/zcp45XHMT2cWPgylhG+rxtQnawKGGhmlALd8lXQ28zxYk97" ..
	"gK7d/OrJiqVToVsBYGAmPpxBXVsILRCjRs8VtwW7rVSdnY3ylvkjIGbkjWersCiLbisgtaAdSosnqR1olBwdRd7MZdkhr5qykjYi" ..
	"f+6KfXUAvFwgUAMsKPrBk5sGf2MPllN4J81SHEn60+dxVMfEhjBuIbnbhAlTJdWZySQiNcqH72+5P/JzpY9Ixb0yKzmQutVtBGYD" ..
	"VOAYRzflLfIc3rXH2LlF167L2wbTraHf00pQN+d4rjkCzPjx4CYL4XPtg665aBtNovYm1rqhzIEykDt0IIusDeJjvH38eqySmjY6" ..
	"s4r14EkLGzu8VFiStWgMZVALySt5WLBHnfv+376HPn400FSdSui2CPhfmtp/Ln0rzWSbZBDJP0KAMikflWw+EIPeEn9by7MCTvAp" ..
	"twuHvS3yuFEg5Kc2iwyTlfiP4acr3H/7MH/at9FEj2fXTLa15zEGoZU57LmTZ5JmVyp2l3o5GcVMFovhIcZhJ2NDjcN+W64dTn5O" ..
	"yXfD2e0IPTAbMcfEErQfbS9/C4NCVir5uAlDhi+ZbaZH9sEnRwcsQDKxP79vYZoPsraN+6x71xJSDNH49wsXtRxt6M6Eer6PY4TR" ..
	"DVpIbLxLpTo14oqtwBsXHv2dfHbLZzVen7PlPpbgg3Fh2OUJQ8wDiZ4p9Ayb1M7qJxTEUtG2+6zm96EECaC7ILZA4uvtTmkAkVYk" ..
	"SNvPKFjDHawfIOTJpatDFGeHMeUKDBKkhWKz2TaZMG0CsPYF9l4ntVt9OnDkepQ7W1+Nq1WkOWK/AS6Ve/HPIjoaB2+f+Um6EWe5" ..
	"AablI7UoRKuW5YJpt4jwddyNxuHdfRE6IW4wLD9O2DPPWSCDwFfuC8fle0sBDCAPb8yHHZJn9gT44ilPszhDZ1C4T5vAcyk/nBqb" ..
	"QwTICDi229GQgDu2XBMp+NakZkraeZQE4CUt3yJ7G2O5oNnZA475tVFG0WGt7u1XV1sMjHbWN4/gVK1T0XE8E8W4SrRtRj8KTRYr" ..
	"0pLRC5xfemmvYCA/LKqHsyh9WnYfyPxJ2jXg2SVR1MNxRBz/zWiXZZ+ids6euoMWkK3cs7A1XrO6FFWfxBYJ8OFt7ToXSyCALglA" ..
	"W5Wx+p6a4etCpGr8l2UHiheGMcW9WX8Oejb8qkcLDw0huPSqDZUJr/I3QUYgYGNyP9SjDfUKg0g437JOjMmrg6T7vNG1mcq7rYyK" ..
	"4e35AM7GsTehYi806eWfk1GEB8WuMHvpZpK5t8Z4oVicDR1Y1OBJ6Q59yaqGa8dENgbHYRfhckOxOYOFmGjfpx0ibAfWyq1ocXZJ" ..
	"hv5egnVotCkrzuX8EnOt/TbuvU764sNhzWFD8oUlB5T71M3YM1mlPL84OCoAlF0DUQpGPXP/XbrzTW+7k0VmpFFGPxNlmfMUlkgR" ..
	"ryFPhN9r+JIYEl5O3nzpcp0m3AUoDa5sOZF9EH4yfe12XXW75yjN5Bt9DNIbLvGwsBEpAyJJYhpLIbvA9nUsDUxejD2EeNegRsEB" ..
	"BkFcvyF3afrx+Yj/RIesUCiC+7/XrUy2QLMnlVbmWqeWNZL223WO/rnVG/cuJWAl/THWpD8fN/tNZ/pAiyWssZRhTVsbZaRpACLE" ..
	""
local PAYLOAD_P7 =
	"NKz8UAHO1afnIY+z0phwPSK514ZJQWB3gkZO10mwT8oo++JKqVd0XTs6W3sKU1ekFFfxdFJ6TINSENd8MOfjeivHCGrhXOjRomNZ" ..
	"xZ5xus65Ps+KtYJiBiGjak0zU2QKiQZpF7Wfa0nSYZAtLh24eCKPDKejeVVNnHnS5mglvHHS7j+RBDQey51Ezui8pKa8vmoxf61v" ..
	"eYAk84tRDw8z5gsqzXlGekT87qpC9Y2ikUJuV4RZEILl1b76v2FNJQekRhx/hOGoPKZunvpTrKVhSFhuSCDbY52PbmiBs4ViFAEC" ..
	"L7UTtInZPKzT053g5zJfZlEYM+cDRlh9ZWgKWPTBc+ESU7jg7IHTJrj05Cr0RKltykZ0u7Ufyus3TJgAKVJTpIS2ykLxiIzq5o1Z" ..
	"DdVGsnrZFEwgb8rdwR2PJE59Pu5TOoMEtXZhvbPwOsgqt7Q4XD9816oOQJzJzLu9myyLbJ/2q4V/OQVNPtNrnpdJtIk6yZyKiVOI" ..
	"sjfvRVN++Cr7IQJtmyonAVk1zS7Z5i0sio1dAnihHUCMU7ForwSbFNlyjylXU3b4i++2CSR0E2CQ37GsYbP/TQuHsbMnRNNmzoIu" ..
	"MuTfvJ13jG+b3DxD+5IeZ9nz2lZ2tW1nkE7Mw0KvsPyRRPaKwQ9/DaivaS+9QNxvLbYw6XGSNZ4W3IfAsP3luw8HWz3G9kff0LKh" ..
	"07aGwgHmHWz2ahKMYZ6B/CrQt6vDrvWrVvxBSh7oEuFRv4+TnxLYIuhbBFHeaUzszc/2rQ/Gcav/4wvtKxDWaUZ0j+b4S1LQzlJq" ..
	"ouc/lpdrtlMUYIVIAeLrUuORIVTnKdHrvEF6d2gAIejn+6EYYO84PBd5aTG5GchYXV0iuLpMq+9bjIm1xGhXvycpZSlLDSShlmgM" ..
	"qZv2dxphKYNROC3PvZba4Cgx7Uhot+WEZR+SZSJ1or/chONo9PgNq6wJIu7rmr44xyXEQ1tUiqLBxUBg4aTxCkr9ahCkvBFKYs+2" ..
	"fJ2sJnhL+t7A8/ZrK/Y4AI1jhj+8hKdIrvO9AJja2ECUT1scha971CiO76YYskALJnMa1k5nNyiqsrkOzg7RvtSVOzBRbfxGrOrl" ..
	"lZHifTM/IVpKGfRt4Z7x/YVj0fbcdJgUi3KqRn9DouN7fJidU0HM1N6NVWLiD+WdRPbI8XNHh3pOVrBTffTEdvz01UqsLR2gNn2b" ..
	"099PjNmXutCcdyXXkWV8fryuWPDgHgS2hV+VZsdvFdTXr9kYTccujt8vxIPddLFR+ee87gHA7dx6RVKDAUAjKUk98lhiUTTMLr0g" ..
	"QRpexBSL8oTEvkKuCnKpWDxCYNh7HQ9+9DXnBUYOzHFPL7CLPmSGqr8j9dRLqPJ1sEQs6RxECH3PryYEN6z0hP958kCSnJTCcr9g" ..
	"H3dShR7oMwbMC//LrqeWtloaOPm3Ee8Qopg2A7LyvQpj05XrD3XUrQf6jxVgmrbDUoauzeMJqlZkNOpY4va9Jw4PwyLJ/yP2aPnd" ..
	"HGU615a5mike/ZTkNWoBWS8D+GqpMLFUpi0JnHMmwzcgNv8j/4Bj9HPkAb6WLl5tv9MyL5DVTGlka/n0xyBVCRBeOaf8u11/NXOa" ..
	"hG0/qDjI7UwEdkgauox+tlo9qs1oQzFAPqMcIZxPFVBbgdHHv35Nz+Ekyqz1x69iHMHfHlWFSgAjwwsasXcg1F43CTX+aIy9ud6K" ..
	"7wRucWorHxdS9326uXN/3UNsyLV/CJKPRYA4DmX8yr83cBBL8UBL260YmssuRIpqZVQS15Oog6dVpdDJqcUf0RkF0z2UWwPZ68iJ" ..
	"wa9q9RvZ3J6F2eWK7KmlILibsphO6WtSuJMeuAPXKfcgjR6o8CdvmxaDe5+U8OBGHw+vmlZ8lT2p6BGGvBVx/JcTLM5GewOwgPhk" ..
	"UbaeBuMkpz09vnJDz+m9M14t3eP3/d+A1xqqOFWte25gXuAsHvIBEaM0ICF00JGXhFUH0O0WCAPlhcq8krWNLbASzonyWGd7x28q" ..
	"uJq2aDOX9339Osettzgb16JXQ8zF45QGr3mogmYuWZyURVXyhM1t5K1bYK9LwnQ9GzaMoE462khC6jjU4O7DJ4AzcP5wxF9WP4Md" ..
	"F/LHYDublrAWAlJ6vDKdxsHXP2H6NHuVERxI5VFjbubx1q9awC4kxQecwXqs8e2QjiTjODSX+aA+jFJkbdX02idmy0Ffcpguo2gC" ..
	"Pnfxtah+DRwpfy2cf/5uWIUa/SbjwVKuTuakF1FvabcGL+stUNshRiLUL2VXMwHqV5QBbO9jdS//gAN9jrnpN1AScmCPuc8PmpYW" ..
	"wUBqObYAhhqCeIqQHgCMuKankIv+xBocL8VbOztz08+rzKMcHriSxWOsN9BWVAF/u2s+sWKLksRt6antCLoladck/1q4gR/hDc3d" ..
	"486QbfxSBbRjDl+yX1DO7LME6QGmMbuUDDaH+AjCEef93VJVDHKcuy4bFnCW9L1NXv9n9/ze5P+0htChj8T9Q60qKdzgAYDa/cmS" ..
	"NcaruuX67YbXTyzXaXrlt8i8phrOZYGWD4+DY2W1g3RL1jUXwy0J/DBaNdXb8rj/UzFQPXOBbg9ZPXwgDKsYMsJTDx/fV+3GV1rf" ..
	"wzFqvIim02KaoaJq4UMyb7BHx0WBL9TCK83INxDGBEWL8LijLGtdBAz0aPwDMp6sdM9xqX8msK3XDJx32Fifpw8pQFcwlx8WLaCF" ..
	"O9P8MKRHhAvMp9sktBQJv+su4WdlH8fWZ8/W+gj7STt/OtnBOCbI152Ny6qv/mMS15rF+TvFWgfxLsNaEAyoKGF6h/QkGvd/0OWR" ..
	"OGqc0soz9VUwC77BykSO5VZFtXRhpiAhy3gn+37jCiBR/qtEnnq/sQx9qQntP3Kq01Ih8r2f2rPqcekmTaL942AS7uik0/XAJ/C4" ..
	"+gys35g8IVZqnGBKIcmJ5HbVSZbcw3/lNJuhbjJ6SA1jZWBRUSt7cu43HlE/Cotl9PN0jKBCv3ZL5fQo88SIDi4LF4v3KNnhFRln" ..
	"t61x72xkqAJ2RvDeIfTu5eEM+8wVQvI6C6Uht67R1Ih21CvKGbttfDVu6TEhAlncY5iEwMg/yMixiUxs5sGKANL9ruWFysp+bpfg" ..
	"7NzvLIlmW2hS/Q3Ew6o8/bGgWszWg9eb2ynEKDO5XWnl+qVN9pnHNuxYP2NLTEcMCX4Dw7oWUljjT5xrJ3h7Zh39U9h3PpmSAAF4" ..
	"97obOouw5jl37twdum4/U1gV9z0oLOfeXJrnSEfEdNYzjQbSPJaEgq5UDJ+O1wwsE1V9xsnb/khQXn5LJUP8rMLAj3Onye/ntqlD" ..
	"9urakcSDJ5Hi+YMQj/MgwNZHhgerPND+SmZ9mYCSYtsvWyM3v86jFHxXn6Z37tCSlouusBewxcqMU6f3BobRzoWpUVH7yuiMzy09" ..
	"zrFY25swDNeBJfvIXu9QsElN9eofwKX9pmHndNHBDmzjDAZ712z//V6nxfT1whZDWr8X88MWwWED0Vit1MV1Wyue0fdblPJ+X2dT" ..
	"K3mUQmB6haynDKXMlOroR6Sd82GQzrsNhC9MSOHTGOVetguIUvX8/klke3xR4smMJprQxg4i84TedQI9NZdXpxtgLwpWYRAArJc3" ..
	"35A7OtoDgmkf1XOqUiE7ianzkKEeUaqtyq5czDv63UeiVX4Rw2ExgFAw7jut9KESnGIXPR75depdfgrkO1VNwYUom964NjmtjD4C" ..
	"R67BfLnJOZwWMXceAJMRTTkp8Pbtvw6kcnWRujx9pJImB/AGP4CU+nQtgFAqS/EKI1vMEWrYkJsSW1TmlcluQYGKnPRSgYH4Z8+U" ..
	"/wNu44GVDgQj9ZqGddd+n2w88MQRXvdL5iwIa3LajEFpQrZuU4WxGZrWa7OZp53ecJhSNrrGIpFgDrvDbKiqVoDW/2rijEF/C305" ..
	"Izhqds51SIpOgFM0CEGX11LkimTIdWhXFPkVZ6V+lFFjIW0pt/n0vzGau5INGqvlNRqhAbRf9Mov8R+QR+O9NQpQMr4rrzJUceWc" ..
	"wkLM00qBgGNv0/irgkKQmOw0KkAvnIgkIfzbmHUCmE9JNtJxgOeZ7WhOcid/Omlz8YjfkUzlpfCBqdDMBm0rBwFEvxs5x/ghOLnG" ..
	"rn8MzwJdGMD2KFbhX9ZRtQJ3iWVgM6Iq62VswUZPIYsh6u8v5zbivEKDtDuVLJxGqf7bxDN9uMvw6c639h52O5M7/xGap5MGfJ2P" ..
	"rcIYzElnQdyU/oSRGC4yfwVJqiGWfnB1IBJjIT7c7UYR1rZxTzeYzV4MlVxru1wZm2AKLo8hcadxV7owBoJ5xwzAMHrViWYv0fte" ..
	"ayfnjcv53bNqIe/DsZRlbZgJeHh7QRFuuJrkt2pmBuCugcP96tRt853mJOEsGaRrbrhArY0n1rGs+u21s3dl1R2EU6FXADu2+SZz" ..
	"4WgdtpHD6shclFYN6GRaXPNmkcjd1kIPlFM/erwsTOfzc2zj6zGVmeIKzwvAIuWbP+zVAeGXf5PdchG64IBJfCpchQAoS3fe3M+f" ..
	"esXCD4TM8TdrFC75Oxsvoaj1hVk/oo7/U4UvOb20X6LmbLa+APLwqCLMpIXss6s+pAxfDLY7Jc3wg80ESfRNFc9htjq2PYoO3JWA" ..
	"QTr7LOpNe36f7OVK0rKtM8Ao9Wcg2/surnCNJdiHW24PiIEIhnxO3gcf64BlqaRHg7rRkTwtJfc2aUR+YgqqGUlubK0fDdzMlJd/" ..
	"jBnPxRnIfhggwjE/xHbiGg8k3AznCtjvPNuTVV7GpB+3uTfgWdXd8WUmgSW6cMyIIRGypIqWbsE3qHaQVegPpRlGDwNfeDU24Plt" ..
	"YHrBzoY7OASqfAP4T1vU/NzN7uXmT7W0Rz2BUDJC84U7R70wZV3EDAa0Wmxwyp8vichq2FRLnnCcwl2PoCKCsTRgYAze5ImUc9W7" ..
	"DgAx0zlT8BRrhFT9OvnhdN7CMJGOt6vLqP3H8PPdBFdYEhYmrjj1ulHhzbCXEdzCF2xhXyCFbdLhNG6HlLK/ONNZdo0Q59UDVHR1" ..
	"D/TurhNgM+87L7JyPxM2vRn47P9geGfJhQuxi6c2Spao385PvSncYhUlKxIFMaPtiSv/RTMnFRHQXsLSxzY73MuWc/yTle+g01ua" ..
	"w8RA2pvGXazHJ/RoyPq7L7ifkcjQsl/WzslJmHNUhc0dTqVqE3WX7Ydc6TjCA02VhfHVyr5nQalSLUue09O4lFXNIwDp4mN6C6Qx" ..
	"fpAPfOEIr7n2P2vpmB8GhlNFyqPD7IdtQYKoBDnVqVUsF3efFBT9layGV3gf+sqnRbsuiQLJC2nQkeUaUhZjnqMxU4+w4Ex+miEh" ..
	"lBwrJhmFxu+cWimLQFdCqwsa6ZXCBj0kAVrW1sWoLd0tg0B9S9PdFKEpz1cDuoz+lC/ebjNFurwH4YSb6Qh7oEcyCcZwVm2YAQxN" ..
	"Byfgpzb6U0aEkvIkxiyKFyIcg0duVfaiFpa+LLVZZ3qGulBbwg1vNNZgCXuffcHxficOtZsILXGSMOmqgUy3YBO94JtGh0OIiHVY" ..
	"VaIGTKTdbrkAFYnUV6GZn66YRquJa+I/imPtl6k/uZgzrnGYQaW8NNeDGl6j8tJMG9XZnr3PN4Ontba5EJjTnSP8q7Z+tXfB/UTr" ..
	"tKG2pkns8j/zqaKXdoyrKzj1jshD4H+Zmb7MfwNzBPEHWMTo+IRCoqpqcqrvyFoL5E4hCj+Un7e4Xkk84zgaDtBqYQgB6hNYeu+v" ..
	"XKIT/lqbuOHhCpiaZYM9jRHVJUWG9WL9f0YDLXZEMa8Mk9RLzirW1/kFBUumwzmeulgNmcC3nHWwtFClJCSVGO154qol4ikJskUi" ..
	"Y2xZtS//YyaXQNrPxpOPtzyqL0lvcGT2foeHiJ01jBOAMXXR7VUt1OHWykh3xaQKY9WMEFmacjlz87zPZm+UoFLTWK0FgB2sOcRq" ..
	"AeVyciP25pM7CfjP6w3xWXWUfYb3HQg7iViI6CWsXZScKzTBOWKiWx4b7MuyDRoBmo2xCgAXLxI/AWJYJSTRgyImbCyFmgdf9I2Q" ..
	""
local PAYLOAD_P8 =
	"lC1iwBmuiX11Z10ME1oUt+oiaJPYOvlBQNjTb13DVgb1HfkDQ0DtmNsUPKCEPzMOsa4FIID6EF5NS91JMTR0CqxG3E6ztIIL8Yy3" ..
	"4j0fmEU0+zXi/jcOhDDfQngeYvwXvNmpKiIKs4mgzlUkwplJuxqHdeFEze9ETVMEGHmd016eAmC7lFabTPPUHJ8YV/D3Y3mZv9ed" ..
	"wmYVnMQssKqJhOEpK2ouwWWCntkZxu0obuP+QzpwsfAs78Fp017Dz8WThMAaCM0RgSqTYyQfWvfndNsGievM/GqI9j6StgrBc2jg" ..
	"ShSukGLcCTZi1AZOVi13mFKJnqgFUa6a87FpdZw7bryIGaSrCkEICLAuiaCtdEHdmWBxivmqVVUqtBwcRrh74L45rD5yUengknYj" ..
	"O68Si44ZP+93CDjJ5fnhu+XteAtY1TtyyrRpYY1PrHwf+AGxmDPUrVt8vLxUXEK/GHEVKaL558jDUbBeMvLMa5usllQmBKmU10Jf" ..
	"sphRjagvaok1a56bqj8jSko96vnbfYXdz2t0cuM3chOc7Ip96UnkGG+wNoKbR5hilStqZd8hICYoMJ5ApVpDIcL5buadGR3NjKZq" ..
	"5l/RW2BScPGdLd4oTuJWnxGFrqdz/dp10zM23Dk+kcgW7SW9hqQaWiHDfuNz0bTex6WrHvU4INcpUzENkf72fjfilxIt7ef8yYp7" ..
	"Wz2w/fHUw6+mLdiKGTefumkV+gR4d3jh4CxPzio5MQxZBiAf4f+FYWhPUCiAW5Jh3HqT+gE18gwE8USfxolw+rFdxLz4++4QTVGp" ..
	"5dHsJnzApIwf10gz9CRUEdqXLmj48nAtvUW4iAQ4dJUDr9pg46Y2QtE/FC5If3gfPd0vZ5dM+8dmiDQc9qRuGb0WyCKA2Bd56Fmw" ..
	"xgJAukFXESeWQkQHpAaq6gxh7l5hlQg5AEq7r0YuwwHo+3wnfU3Z+UWdFKAFeuvWLKpv9H4oqAYivWjMHc6Ton8nDImJ6JrCppx6" ..
	"CvBgW/q+34/KK8Etwsw0Fyt2t3PM8gla3zOZEL/q08P5kkfaXa1C/1alwB0koGKn18cvj2MHV4z8ZmBgq8bDTcQ+GPy/db2uYt2S" ..
	"9bitoe9ncEPRwo1nFv03WNIHnLlhHwxvbCb8veTFShprzT71glVwt8lfVKn3xwsAD+NXZ+23j3iKlBO9TZr+qhUhMIkNwEWJLhjn" ..
	"1cNGtRej7Rl70AW/av0naD/j2McAjoefBVAgM3UJaK8qfg/Q3jJNdLKnRM+RYrXnRJD0/OWsDqXJn5Lfc+ZtpiZqAo+0HIBN0KMv" ..
	"607aXVRTGE5YFd74/mZGQwF3mFMrMbvNOd54xhrBiJDue4lUME8Kze7/XRa9pmmGqd5hOpiUBT5T0xiKK8EQzAWcGHB3fpSF507j" ..
	"zpA3PicmI+JqEiPuPOHboR+XaEnmp889pDtxHAO64r6PDfNnzovm7iVYYQ3SiO+v/5AelHnva1njwpSsjMkBnJND9CbEIZGONBe2" ..
	"Z1v76V23+YWWiYMlmbiPVBbqd5VzVp32L/9HJfbNiZDCbjF0URVnjSrwn8213AnoUidRfPYMlOqUoiHioD+8tSiRJmMJEKLbi5bP" ..
	"CIqUjSKj8f9Nl/WhRLdX+WtaEOVk411UPHmuY7CCljnTS1z0LGlr9I9IxFaem3t2crexAYd9H/ioulrqKcpExwx/apA+WSDtMkzh" ..
	"U63kwM/tSqR2jlV8oTuraho151BXrfp8fV9D4qAoa4ZicbwttqNBP9vtR/cWwfbxB23A4GU80jOMLZMulCxdSbkgiZAjFHc/9jK5" ..
	"CmCqQKkw+a+UlqF+j8iOA2y3aKxytqvrmeAqyC1Qsxc2qkEMBWHo1WB3vjt2N/tAE6qveSLwramDl5GNTLEN1+XkmQL6wybt/Uq7" ..
	"vtwJa5fIgbYkl25Eqn3h48X0i9IhtjXWKLHDUyY/9gbGI7cO++wTLNNuyzUO9Fa05gxy3LQYjhrX3+G3EB6M1cRjJcLN/T2V4Mlp" ..
	"B76RJTAPAaJVou/SyVIG/qV74jkpsJK+bEWKejxtHldi8PK8ul3OiMaiWEwijWlYHCl73nXlF8NjZrON6VX289zxYbvyyfUOwM+M" ..
	"cpS+yQEUlL9zy5fAM/zxJX9Rc884gJQAxsrOKi65s7ehDdjq0oozG3540McljXxEXabzyIHlYbzTU6fdRIJugjrLv7kVvmGfwx1H" ..
	"B64YxmOh7dIne+JH6A548dC69emXIqlsI8V/6x5t1Esz55Q8yfYD+mJVUiKuN4TIJUAU5mUuaw05h/86fclB1qcXQ7Dx93HQQq4L" ..
	"jeitqIK5Krz4MRZmFoSYmKtUbgiVKKCy5GC5eOF2dTAECnqBtomL6kP90p3PspcHpBsYhKdKML5wO/nHlCtFNKT2w+acxWVhps23" ..
	"nqmyL54H6SLJjWWEPUp/iTVn51xDVUT7ccRYDvzcNo+ArCLTftE6ZNpGYFHhY4/M9u+l4D1iPkJsrDz0GDNPdUSCKTOLNDSsnpZn" ..
	"N1TQRvseAaxfo9hJKz1bAAQidPxu2SWLCQumoKjRabS/QlyIlJx0y6RmVKMTizeFd8ZqEHlz/gOB5PwSFPagrv7iRAV0i+8XWZjr" ..
	"RTIhGvBcuC7D6KRR+7GDojUWTiIxOCJH02jwsPdRlg4bnP5RlMNMQGeCFKHiuijtYPxAcyEn12LONgeF1RZa1rD8Klm1FBHFPIMg" ..
	"lLzqhdtnaF7bgUNN/Xj4eOHhIBONKoWaCxaoqNXcI+JiGnJ/J/JDSDQkdrWb72DxxWYteBrQU76agDvJ2p5RjXN2WPYGR+VYAy9/" ..
	"+xrOr7NgCyLKbMowwE+98RfbIakV0vtkgbYDUvSh4S8H1wcNn7v5l4n9tZbZ8WSdOxRX/RYUgi8c7THhJ4/UO0A3QPlG096Bqfhj" ..
	"dlPGTETavdJh2uHo3s49MDQpTnTHeE7txyrZpxV7PpfT2VCzcFHktevpau0u/BscjzToRIh6hx+j/4fl8IYvf7FNvlKwC2/ywnyp" ..
	"XKJQvvLXC2k5uLr2ZeCXDZ9wD69ZvYNvJ6UO3bXGhoAUJB/JZjZGN8EY1a/vHTr/1zRsv0gDFXYYcGyp5leE1PpzyWFdh9WrAWqQ" ..
	"QanVuylMcjYK+wPP+XfqmxpKxLdzfFkczOdlM0YoU6ttzcpWKV4LmRu4zhM/RdW4xCLF6X8iarAAOXFJOe0+pD67dS65c2Ekyjdf" ..
	"OZhiLIHbulqnKiJEqSBFXd8nW5AKH96brlAGf2EkMVY35cnOvqU9TAfHge2KoDYWSjHw0HF5JufCh/OQnW2l3jhcAAN33EEulnU4" ..
	"K2kmi3E2eyCX9NtA73dsyxyMrx98N8++9+IKW+E0fqxodFMCHzf0F2I65ivknoN971nx+PIoBTD8VNKf6JaS1d2SxRypoXZYxbDs" ..
	"zYWpfOTBM+TQwCYvZUu/DJwNEUwlCtMyHF6O1FznAeSTXgALcAUp6jUOJiChW190iNT30oJaz41x0v21WrB0TMKrxcj2STJhk/TV" ..
	"MYGunqpdrmLNdqigPTepqJHNke++Ee09NJAVYlB6it4Npr5e43kQVIcRk1tvMfJjeZZa6B8CcALnkWXKE+XPudhCbl6jCZqrJHrN" ..
	"RJam1TJTzZD9H6l+581H57F/AXxVQ/Ujqv/q7P4havDn4m+C9+fB6zhIdhq6nMTiuaMqKe6WFogqJvmScQ2LsrlpxWgQnHo5g9UT" ..
	"B/kNZvzTvoa4dKxBa89BcPWtzOL+/OYfOw3LnrLVXTcImf7UwcnbYYL/JrsipSsix7aBRend9CWYN0g589GVkh84AWg0hGxCrHAn" ..
	"usTuJUmj4auwHdcT+pLkBtlbErlHSTqpMsVtO0zs7CVOgZtD7OIYGoyPTLgO3MWB0STC18g7iySNHmTIqSKzGEG+xo8opFQu/+ol" ..
	"LkwTW26Ch52Ee97jv4eqvB3CKzOe9V6lrhxT78q5IWg18JnhIpOyKStISaxeySBosvnsYJUS2YJmYbZGsXRom8fXIbEY2llL6dEI" ..
	"fq44qqi/iwcc9FyMweIfubIQhHlw7P3w4WGs315PxevoTeaitg/UGIgRl6R3r+SHzCusIfEhiTm1CZdbxqhKRCULdVWnYRVLt8VC" ..
	"zoOtLo+yraJeyhdcePBbCfuBRAAIrafg57I4wrp/a6UaT/TUkMUQccE55xEvkGUoDHEDsychk6M0OMORCPjvaOOW44ExfyrzVfQu" ..
	"kk+gb2fYP6O6k8x7JFsr7f85jW2oWqI/iWD/geZ618FC30QF4Nbo/oKqFkE/uX9Ndbi25ySpwK21gTZ4kf9bm3VHZjowxXi1UJ2V" ..
	"/GnIwgK0sAl78bcmvmYKs86e5TpgOwVik4rkKw6zvSH8pr4nYkQlEcpM9G3VXmOrvAgyKRiPN4rVvJbZJxwcGP67pk2zazw4+Pj7" ..
	"vQBPAsycw9C+VxmHT4vtT+0f5nOfY5yjxdDzdbchJGXP4DaQn8AiU+HALxB62+b4pjeUFlNFPr8Iayn7RaDWW7MTiDkQqIq60/BF" ..
	"XQ8gqN97Sq/H01ISY3y5fhmt2vyb5ljK5CGP/8T1KdE3mfQRGsfJf8hD/GKGGdFieJVCrIcX65pDK67PcVBmSnfu0w5O0calOSwy" ..
	"MIzQR+dd/V9JrQP+KEYQ4WNM/y8RrKkJ5C0r6QoZsemACbmxsBzDEMT4tgJ3hdayh9qtIi3QVn4L5QRA7LRYc93cELywopYhSF+t" ..
	"Ag2SWDWo7S/wRtQ16Uzc3NVK+tfLrqCXMPTNEGZmt1vUYhNOmDktv23lj7EjTHCEsmMTDnweV82VVoW3R+rsvvRXjNpsceHoVBLo" ..
	"LVT2Eq+bk0f0CjfEqwaJ69MJCPva8TlUQy+GW+JP4tFQgLi0jD8bTzRT6yAdbLiPpJCQ8D/MWsHeRlFC7yymSGiAJyiVBlRWEVd/" ..
	"mSkYIxhy5gosTeH2cxLJzV2ZNurLS7YJ3EVIldm9mBv88rlUABCbCio8mYfFTYLFX2Ds2wkBHgaFtpdfR5jc9TG4iJ6WAFWEDx3z" ..
	"WcjqZTSanEoD0dhLxN7tfzPYgcTJ1m9Zx+4uE7uag1lOF6iL+gNapL5ry0PYn2L/k2aF8HvkxXZBrcY9OROJgjUNWeJxfLTVByd4" ..
	"JWvjZ0QgPj0IQ9b3lR9Ky7jze9FsQsKdOQHI4NnCi66XoJ8lP8fRjoqYdHNazv46hx5vNUYJtrUkNUV3CwYBOD4r94+Nd24mPnai" ..
	"TEHlK9nDKDc2TtnkK4Irl/t3IS55ReVp57MAAW9atR1vbDxjrniyWQd+pS6B0I9n2o4k6RLPKDj/2OYT25ZrCMYBQrjhkkOe/gmP" ..
	"cyFvS5CUKtn27wWmam+fwqush4JxYJQT6MpBlK6BzztsFVWtY7N7vnJ8LCpT2RG4Q9RRqnNjHVgWvIbAkVxjDuXZfFi9Gz5y03Ym" ..
	"oiwRrny0EEYQbu4uuiVV3+AH5V6QlNreTINTAB4KFFGkjd36FbcVK6/G6bLmSRV6tLr9jl30GV3xElCjagPJcVx5+LWLUE9x0Zki" ..
	"t9JoKQTUG/psVO5TfvENrP/1x4nlscOZMDrxs2/XKYzeNo5j7kAY9UhRMxKSpgwEh7KtAud2dmXllXy+M6WtKH48fuHAzt9WbK57" ..
	"/+Hsv7V+uO1qHw0rBeqEkKZfnvvlIRJ4LcM/tJ41dA3c3kLV0lSrP1FU9mM3YBLIpymzJK3O2NvgSuEobvYr6jBPsqytoPCWLAWO" ..
	"Gdqgbf7Ne7mgRgxlQAhbrgxQ6mUWRyqGwL29BnVfbBYNVIHEtZXPM3f3IEsV8LOooKsOvyEx6B00fQFJvz0ZPFVwyl9UEnhxQqzg" ..
	"QF3vsGfSUX7CTnQSDYhpy4tqGZBBmqTjQUpugpitw2OWj+diogJTTGRHbyEi3DVhOll34nlUnc3HTFU5/MIeT3q1A4MQBjUZfBEU" ..
	"ZAeaviyjYeidKtVMH9wijyNd8xDjXJmiAq4t3+7BCL/MDrqyV6SHEtdDMBzD2lLta6ZIA61FlbWxFx9ZE0nxhzmkKOFe7A4d3tf3" ..
	""
local PAYLOAD_P9 =
	"081mmyPzRRzWUJ3vC9Dlx8e0ro+UsUaazRpIoGkgtrtGzzAgh50WMeWRka/rLacVNb3mayCjxwDBL0jEob7AvR29v+/4uNhAJDh7" ..
	"HX7VknovJLWKphamgN4Z/NCCk/Hdu9vxRKc0P1/2Q47xJ0uu/lVDHH7Xg+8O8BBmVgRt1UDFFV177r0b4MXflmrfst9yM4r2XrK3" ..
	"wgTpY3N/pQL+/5lw60fTsys1hsD3MHCOBnAtW96lxyU9q/beN1Oppt+92i+/8EUdeUCj+UaQ//YThhnYVJw5aITZOenDFCdmJFsZ" ..
	"0EtCXIY5gcZZDHH6WwGSbimTtMNxWeRQRo546llXRQ0wdyQn3v5uJdHE+6f8/xXpCzB492CSI4JcYdDORwhPc0APzfna1BLyb9QY" ..
	"Uq04wS0HEObq+yd7iz4t4KFy6EDGgbUmCYUKpxMK9oH3AOMUQTgTYaix8Cjh2YDTizl1KF2jGc0fN/5dIbIbBak6BV6Pyy5lFylw" ..
	"Vd962/PCf1xBtdFiF00MnXCP23IMKoGP2EhX17FLxcxibSU20LR0pTBG9cpdC7t18IIHOKjJ0q0oODyd4xvBY4n/UcHbYicmOCvQ" ..
	"AKARomwYrYWVVXMnXQ2kVURamzVrn14uLdrARooNNjEsQhua7YVMhbfwLLnt+tHlRyGJImxl6sKOu8AqFktj2W03EJLgFHcKT3jB" ..
	"DlmRbEbH8xdVWf5WIdtz4yQUzV5aKu/naOEd/u60l22KZtXVCD7Z6Ae3aaC95Gh3rfpa7jFgyMn6By/EcvjVQrZXuqn707Ye0icg" ..
	"x8L3ns/SMe57TBiSSw1AIprQ1I0gwwS8WxQ4e4B1QfnnLv2+yEBAIujMYqkKmCj9s6dGhE+fPIaQ/vq66vwzcDxKEja7Ddd9DSHG" ..
	"Y25c3c7c6z6M56bTS+L7rllCCNiV3PPuYEvcuHykWOj5LWtvO4DpEWwp2IU7WNrqDgTlmQmz2wA74CFsmfYUEhGTxLIFcOrHIxKF" ..
	"Bj39K85yp9fk8/Een9X6Oz5lWkh1VxrpwFKLv8wUvrem5SaDX7lT0y4FmCuq1lXqeL7A9vijYAJAeGe1l9hurDDl+kmBKwXBgdv0" ..
	"S52I5Oixm3c4ACT6ojXcHecNLpg1goYRJbuOKOsW9D5UlDYRRUMFM78cKy7fyy8Uw974iIiMcWmwhtUQXRexgKHhnHEf/Fh1Ag80" ..
	"4DSK9xTHd4rPPxHE8plM0WwwQbONWI4QSy4nm+d2yqQP03ZCl6tb7FcDwKXONBB8V6ziDq/haVlXslDMykVK9SFLR7rwQpLtB/PI" ..
	"GIzKc6o/yU29klImXz5t0Mal4IaiHq2y8AetM8iT1peNn0P/cRt71KfMaOwLk2aoc1Vs4rImzb8VSH5PY2klhsvr5hWeFTOShZa9" ..
	"xn/CWvDh1Aoa+uRoMkrkBpi2BB0DdaaoMODlp9f4V4P+kPlycoVYT5k72M9dxqtAe1SZp/QqeSvG7yD6kyV0wL+K9FRpsmUnX2Mp" ..
	"OhmzmGqWnQAT/mgOyMurn+PIrISzbLzibGfyQI8x/igOQJxWxt5KwECON9sDIJpGTR0uLwt3xH5AIw73xDeDGyNr4ktfWbsZIj+q" ..
	"r0vvhxT7PFjNaHwvo7DAmMWuP2YjwL2dfRf6BaMXuILYZZlYDJCfbZ2QLx1UgFutTU6w7FLFJxdiP3W5qdL8A+kAO9koFAVAX5LT" ..
	"DFBseVc5BTAw6EmWZMyD5vEZH+u76qRMhE6OrN9K7kFXeGf3qfwcBayQTfgdOzANA3n6klDy0Q4tRPya9PJJGyhozefR7IPsakx8" ..
	"QN32IIfdcvnR12ivKRRI2hAFnxpG3ZfkoNCf2qD3KIkrCGFEuLQpxHr14ubb6fD6+Sgc2OhwsrLGD+/TXIT4UQfJ7prJGCbV3/B5" ..
	"ufXRlTSXI3weMdJNtuBg1O/scNC9UsWY8Hpw9fCkx3jejukW1Z5GJXKxeXgIh4svu2BTKt8Qr7SB3FzHfK8WzEUu+/VFqfBNSOcw" ..
	"cZT2ikrwMId41GQjUPhkzw3VyHrh+bfnF4XLzv5pDepR/jceUEeqAY/MTnNRQ8uND7RyzbmBhhaXYeWdDAHOEkBVCF92dsfdHHsD" ..
	"PQpaKnZhv1qvcqVe4hPtsJCjPHgedt4WsXhAf3ZzGlAyHgl+1MBxvUMAsOe7qrH2UuRF/y6xOEdJdYdp4cr26dWzQIvDymXF8qsq" ..
	"VJIxV3h08GP/wp4PMwe8tCslgvqt2G+xKnp0Tayyekel2TrKbnTZq8+oGHvpcKwI9Xx2pa9iwI5rjPNvdPSrlW4sjy3+HM1ICct7" ..
	"gZ3jl9G1jwVQx1t6VZlR0fpFtdCgyap/53frXJrfnrKHydBN08Mxe64DGxFzc7VIXuwHiq+J07LI4E5vDuh03hQPFoGyAPDXkGT7" ..
	"QDwHFNLKEEr8EfFMYj8MwrSZZI5vTKczRnsJxGzLcyC4/8FACLMlgZaErfJ3D3XSgGTNeTCOw9n3ufdeA4kWGqwXkniBvkKgcsmG" ..
	"+cOzSdUiRRjTdMfKa5ausjRCeC6amUG3l12HdeDMPOup9WRwSTEYtlYehuE0lBEQI0s35E3llfQC4DSkAk+r/pUyuteOlQUTeax9" ..
	"u9tZuAVO6KjaV2hiKXkaHcPIBy50BiAqiYATOkNJDMWTndLpSQTNPcH5FBjQYtPxMmf/o48D4pOBCt/H8Eg7AyhZfiiq/XTxvz9l" ..
	"rBN/I4XUESwr1mPOQKePIiOh4W9tJuuinyYpRjjFQ/foOSptc10J9ouVv983WL+YYApmMiZp8PbZFidwZ35C8xgDdVBr3fLhDXz5" ..
	"C/cn8VKZOjDg8+LwoZCdSgtUGz8fzLwcRvV8/FIyDJ2hbUaR1tpO481dMzii9ip5KaF6feHEFVnkfZlf35mI2ukdYp/QsXTQnba3" ..
	"M2Mr6chdGwAyEkutntv6qSYJx6O6E9yRySNUKsltrrfXQ6oemMTaDh/KsJqaZ+nGkiOOLTXL7HB4CgpEyUGuRHHiG1GnQTAY14Y6" ..
	"ISaF2Y7bmoMoDc/aIxr0w9EE341rXC+Rnxphn6oS3p+WaKdXHnGIyBiHD6Lw2WvNCMl17jqbzBpUPwa6bZHmIsyWAo5M99uIUpcp" ..
	"r8qKTMLtm/6JdtynzGp45vZ5t8t7TALqB0MLioI8S++47VnvvWvPBC2mGHEwSmV9G++1zKKxenPV+7ezfcejrDf3M25iIwb2RzMf" ..
	"FDykUO3A5l8YJAkI8G9zHiYuEJTB94JLUBMQV6WOpvMIwndZj1VRUXy5oNO4aKzdM0uOkGcv06viuqOKcPnTC5C7FeFycYyCx6gc" ..
	"VhLZX49vhVRs1NeehaXIrF9nruIk5NzFy1/rT5V+TXRpp9cxunPDHnqS6VCcjc4WJgB4srODwVgEcuvFu+839Y+q6pJMrjdtDdIc" ..
	"ICjn6GgiR7DGxQXJfs9HM6ybW4KtHbsSN+hE8sJEYjdS2SXlSI3v6RWfhvMcCkZoI0Iamn9SuJc5FLlpQMJlV5K8dD6Fr4rXaxZZ" ..
	"yRQaFlqI3jw/BTh0DXxYsJ1DjU01A36bUOv/e+L+fmfrTI0E4wz4AQtbtxJfNpVPiHYyF09fYioYa24LuXDStGBEQWRAyconRw6t" ..
	"ymGThexMhX7CJ9eXdfqZUgALg8NyRe6fIMqA8e+0JiHaAxgyJZ78ZbQaaTyOQYowrM7IVei8OeVtTMZI0Ow++54XFiSbujsKq+Iw" ..
	"9K65lR5I9xMmZ2miGwtwWssrlhdKMP5qFshNEtQg5RvtM1W9wa4PcN/3OolO/RMHshY2PemigXEtm7fclQA0Fh7uFQBItt7d8cGB" ..
	"fUmusEOWjmQnM9+a0kc9sq6BeWwI/hg4ismzvwxU6zxIIOCaC5NfKFzDfsrZ4CEaUvxOlM1ZH7UGunhNiRyr4YpDpdmcMmmRbveS" ..
	"bMgmHWzacWwgqKj/N8RRLMBlgO73NyqnrFwIEocAB6s0cu/8pH0IU9Zq5e48NSZQ0geAtDtUnZRHExZoRfmKol7su2RXb9BvDipn" ..
	"W/0o0fzwuMIC03kBHVklaN5795cWL91rtP8vQNyza8rOJuCEyzUXYgnnktUzBiwxzJvJ3W1v04M0zVsRL2io34PDyUmgowqCJ0wu" ..
	"cu+D86aJwib9lqmeKIqxwpy/hMU0wSaeW5VoUEM61CULqk8UYTP5Cs/H32VpLrlZTfLEk5EFg7G0EslJrk82e6IVb8dm+Zstux98" ..
	"yr8VJKKFlWeysiIUxViVxZsS/dSPUNNoeOmoJFV5Dv+4SBAPMQzJzF6B+Cegamx4Z/gA6j3j4OjAt7epaH6RTOYWUfDBAekXszII" ..
	"qBiejFPGoiX9Ec5UjaOfzvqsMQ0KA/TUxKvvryBB3EywUjwqFeFMiHweBPrbsMMpiPC11L3VQetYQGfVeUFlD8M1lU2KZNCGb4jq" ..
	"FpbS9iHmeCjUrN0wQhQx4y2oBGC46iXUJO0KqQ7m8bLepxgMR0obnigZBcOjgQgPAhZj7uMKy7cncFtTLd2QBo6ZtVsN+ZqPkdvz" ..
	"mJjRKoTZudGxQDOWQ5335csDJKDun3TgBNXHvgRsxwGj/X+AVQRVgVKZ/EY7fVhjn3exT63UwgqvsDOmd5AehpNRVbBAJ5PE8ydz" ..
	"yzkYIQOfKp89tAdYVHo3/aqoG8PDhBtwdToVB7NHrCYEkYpSX/eRJqWN9ZqxM/GAz/5JVvnxJWVrs5xAb/Z3bPv4LxkjqBB2Gj//" ..
	"f+ZGl5lHRP3GFyVhlZYc96MNmDhwt9lQAvJ6Eca+wuuf+F2jLGppyrrpWyBl8Gyd0+Pyr8wcWgas5UWw+BlFfoOXkFXEZb68kTFF" ..
	"ohu8jAq8pgfwodHPIXX7zHemhUHmjv3JJy3JmwxBhhXEMQZ7nLmsW7mU1AUlL3ScKboYOCFXB6k0xFdDVcb2BaUFyPi9FEm/WWo3" ..
	"pLdRF0G7Rkc2UwuFItINS9GGbM3e31OYTZK560PZgzotAT7nRUGKvBQeJiRYMlZ/sdFfwOCzFn+1BFiNFNRtCR4fTJ53HnDT1ehG" ..
	"MC2x9CaVTmdOrofHqvV1GRX5rXQWIvNMfkfUUHLS0iR65vf46UWUmZe+9UVHouRqZMOWpZTjs2hX4qd8eosFEt7gSxVPUrx2WSgP" ..
	"TD70yOEBT7L0n9Rgh86AAoVA7kG6TQQf5qpqJ7msfwN+034yZDYJAOqUHiQGhJyI9giKBx8E9ft3eLhguthD9y33EQpeCLe7p5FI" ..
	"bZqrbbd9IUmEVUYHKCyFO8HfULJRUUUnEOkf5c1/+fDehpf076hHVU7ImTqWNPom4JdB2kBbcJGzT/NdhYpOdOMU8x3pJHMOClww" ..
	"0zcmeveLI+olg7+BJAo4VJWJsSmtvBwyNkqSL+uueVsYZanpdha5kqLL8Nz+b9M52T9tnWtE0Ub0L+eDZ2/E00mQArtCQN5+2f3G" ..
	"CxEJbGh2K/IQ5POrfWv2ABnQ+wwCpE0YQq6hTDbYUy68P+Ukc3miWLRGqWmbEHcRVomVQfsIFnrPkGpT8fC4a76uGqQ7yIHt9ucz" ..
	"1kxtXy3coSSZCyAdu9U0qKyYfMCS4Xlui7c+4B5qvYDqlwzT8okuHEZdrFipqNlUZFyfp6k0K1ApTbmfDydcsaOjAST9zle8uqAl" ..
	"Aatmj+1xtoMldbpx427Y3IcV2F8ovoh+I72A2sUEk/6GQOyyMU+nKDo0l1YtjERQ+y/dYF0yZJtQ5A8IkjdzEPzH79+2VoAH6JsF" ..
	"k6yjKqIeIw2ZypCVskAMY3311/B0+HUX92DqSUeHY2Zf8zICTmdX9WmUW18JVBFK9FsV/BPvcx8V7U6tylbEee6fpwCte4shsTgn" ..
	"Hu2nG30ANqdnikyoE/GYAt/CyfxkaFha9FkOWjZcIzj3stlmYwLCKVPT7KPyvH4q8F+ZDsTFsH4uq9tw1519YUWULwk2hlz6iNSc" ..
	"NxsxTvbuBWtyzp3c6yBLOPLq/MxSUnYwt1oj7D8QqUhdY3iOknLJ3UunQNxblpxBAU2EaiTADu3lVqDeivyG+uDErXYj0kTaVP5c" ..
	""
local PAYLOAD_P10 =
	"3NIwNLz3Xs/EZ5B2wpHRdBM1Jcnie6QOZTYbSLt1elAvGQ6wp+1pUgmI4w+QJTQiKd7+KxkZR06NV6U+GzZYw8acUO8yxxXb61Pl" ..
	"aakRHJuvyK6xKxCAptVo/4yjqahkaMyGPpAngz7xJlgbh7gIqrl/rdNcwYshnAPZfA/PZ72lQ6ZjEFMJ/0I1OqcPBerMnrEP5p7i" ..
	"AGj4ew0Vtw0NsxpjUMebBk11qvb0yj2GcDMK4jjJC6WIEahtAzvKmrR3mA1/cLMb7rGlLnGrBSDoIuOSxUj65FemyxSpTJqQPTE9" ..
	"xrlZ+J+hGXSbVBWerXqPseGj6PGApd6xhPzf5CyltWKP+tO1hz7kGOQ6dNb397m0vXzHdb74IjrkooUvJ0FE8isqF7Woa1EQHs9J" ..
	"4Y6P2sC+YxC9lFTOA8+1TjEPxJI0xCcFTXzLV0oSdDH2EyubWusIPK1RCkJQau5AMZg/M1TC9kifHgpClvyg6+GqkeVyKY/2jHsl" ..
	"peFYf+aOkVfJDhsgDTkQKOCSnpzil7FPta0iQBvl/quW+vsp90O3gssR6Mes/kJlbiCDC0+52YD9g73lPqk/P2hneBfuByY7qk2T" ..
	"DS/way6T0BWV8KQhEv0H6uBgiqUcP5FUDVJf5SW/5PnNDuSysJPNH34bn1kqIOjSEKStwI4u4cCdOSzOI4RcmRJXUujt3hHYSwFD" ..
	"NQQ2L7HCXMs3/ESB11QtPyDt+JCm4kRWqnBoiFsuJtBX4Y/H1KS9CS5eYi5J0u5CadF8RtLR1FVdGfmH3wPFc58D1aZSq+09OX65" ..
	"fanfCdiRtvAbM0NQ5+kvQTBAnc3+tHYRI4rj5rfPTAW8N3UcR82Hy4X67haasHa5W2V3p2nrNglLD4Usp0u1RHOxkd1wvJnSkZ94" ..
	"9oYeBwvGgPgXBaRxcO+lGRFggnz7jJMFhTMT7LN+Oe4A1Oy+ceTqsF4f0t6ct/uERq04RxYg6Vf0IkLxlK+i0XTI/GHCUomB3JWU" ..
	"8WZdJ1evnBjJuXYJA4Tyaf7yCgA9JZC2ZDfwuTNdtdUrqsHXExXEMjgnscw6eSVDaHGo7/w6tREHRDlnFQ4DO0kO2pwD2iuGqCQa" ..
	"0aRaidKFAyy/haL5lROVI2AVGd0YgaGoZsEDL/X7qGL17VsozNV0NIGJWEJLLEMDdwQ53zepc0HwJ7DxV6LnuA3nqO0vI0YtUykP" ..
	"Etc30vHMQTiTV1HFRHNdllo0VqhO5P1Py1Qz5ZLDpP/xs/d0kOpTlbA2w1qs+XKJ2PTcXv65EE3W0ecqfSSIJwIrLjSnkZn6ZP+2" ..
	"3Z1Enbf1q2L9LplgTGwjRdWklwqR0ESXeCIu6YmNiZkubEp3vb+QVwkUiQM8kWQsuT31Rjkdx6Kgq/CH4NgP6pEI4Ae+W/k9Em3E" ..
	"xzJu+vEBBm9gJ3BAB7Gg6m/cRh1DN2EdwoPVsspZTeFrixGYa3c+AUeJGUI1OSrkAGTgFBtMuqPIMR1FGACf4do7CTgrmsBkKXuz" ..
	"9woZo3xFocxJKYHGKMQW+yuO0YLhUTsq67Z7LMh+ZHOeGCmbUrWgqM1wuThKFChhhoH0yFaxiYBkC4FIvd2IOVDr2UAsqzAKh2dl" ..
	"t0l22Mgqgachn+vit8EhkpHDAUIBKg4fgZEq5TdbkKyLRevJsNFffIfQoRGALXWcA/1vys/nLHrMOGw2vx82RMOrQ+apS5aC2TgS" ..
	"dgo73qTCrJKB628+yhPYko+8rtn9Os8BmWK0HXKtSixckG3xmmORbudwM2HfBhqoScF2fcknJbY/9k7mEw+/iskAXG9Q0yt0CqNs" ..
	"3SsF+qs72uONTVUzblDNTsZGoOGMxkO2U5K6JuAF58ZHOLklTnyHcuZnhRiiNwgsE8qAj/usEZU/O3Efya0iXgWd+piuqguDN0pm" ..
	"SqKtL2wPfqpsZ2O4uu3E2+BW6m1i7d7QpzMQUJEh2q7I6hpuDPgNofZirmMW3JqHs9/QU6zRi/8AKUGCV4h3Ur8YsghFJE95Qygo" ..
	"Hu3Ry1CQe6uS/OIWNT8khhypiadwWgp1DQlGNpI9OONs+orCWy4L4mB1TECJnPzHTtbVRsm46GS04yGQlVHNibmLe7SCM3VqMR9N" ..
	"hWZW+9U7OJU30GQ9bkkJcQRF38qEwBYYgBHIZf2aDJ0+n8glsDsJw6hp0JOig/DwfAO8JlGKXd7O8105osSn08x+HoU3JlQ/MzxO" ..
	"8yWq/LdKdGuFt1Rvx/FcO4uNfa4Gg3haDTrQ11TGBY0FxxGbm7CzcgpC9xBBdLngZqUsPQpNO8l5u/etnY+uzwFIy5xTPr1nJtt1" ..
	"g9ho+45HJpKdztyIEwAJA1Xo3OvZRc6vvUQY8Vf4dLyCCIrco/4rAV/1vTjrB9YUTx6TRR7bQogV3eENVJuGSry79xpV0vzdr0pZ" ..
	"smghVkP3eU/5xI566O20HVdmbnvKiXRmUJKtPPiRQqC40pcSIOrUqBx3yJqCGH+omwf/5pZrbaNpteP63qYiMSUEXjnR7kh9dLag" ..
	"G+SiLJdJCXTQ/QyzYAs6oObiocB/M563Nrzi787nnyfAAmjAfCnPepPBxHEKccPznwuLnW+D8rcfeZlp+pi75zqKDyl82rzHymrw" ..
	"2MMZQss616G2NidKIKNxjXwe0pktiz8VFkOfgZQNReNvR8E7zR36X0v7ReXkeu5dudMk8WaJrjE4+eBXX2Dc8QNwqsa4RMThjNDl" ..
	"PMWHdZ9ouVzHjZCp57lZ9TvyxQBPtP97kBJoTpSv8sEXa2XKpO7a8e+EEw1850aZSkG1bJoVeLVlfLRTFNx8LK47gfN/R9WccRSA" ..
	"KjjRUcVZXpfF130xnX5f16sn9/NBbnZEYc4JUGMl/9hx00PQLweJnlg02IqHRcEUKPD76ImPC3iGrSpZauDd7Undm3L0aB15HMDF" ..
	"dWYdwfN9HMlEwUoyWiAdwZQC6/9cmp59IhiAaG8HVWI2et6W08+EUmIGpzW13y8hYINt5iU6MPgenLiCSX88ldsuS+W2n5nX8y0K" ..
	"s18nu9msq7zrMGn9D68ZyiJlFxu1zeiXpyrTNBlNnlgvBCrocSFxLJ9IDOgLInFsjDePefK3XnC0yHfP67ktwrqKz6Q3BiwfzBBa" ..
	"Etx7fKZ9Ig7m2RDfPtTB3F2YGaAfR+/Y2B4IOeeZnK+iDyuhbFXZJI3aZOBA4fgwDjQVLun6c4Qp26WSMrJr0G1714J3CviFi7ty" ..
	"Spkqzw0tMgWV+DjK7BDxRA8ImezuFnDi86ILxuYvuJj54htxXzK0D3z4AkAJtMVXbUl27aBSsSxnUkK4sBqN+WI3zoDVd9N4MQKe" ..
	"dfk2KEY3wVvJAwCKvHxlDXAwb+iv6bimmri6/unBcScJ9J5OPlLoilR/SC8GEQfwUmz7hWcCqvUDl3CQ+GlL" ..
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
