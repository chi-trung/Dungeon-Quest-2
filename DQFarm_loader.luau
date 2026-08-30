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
	-- UU TIEN doc file local (dqfarm_source.luau) - la ban dang test hien tai, khong
	-- phu thuoc vao GitHub (ban chua push thi GitHub van la ban cu). Chi fetch GitHub
	-- khi KHONG co file local (thiet bi moi / executor khong ho tro writefile).
	_teleportFn([[
local e = (type(getgenv) == "function" and getgenv()) or _G
local rf = type(e.readfile) == "function" and e.readfile
	or type(readfile) == "function" and readfile
	or type(syn) == "table" and type(syn.readfile) == "function" and syn.readfile
	or type(fluxus) == "table" and type(fluxus.readfile) == "function" and fluxus.readfile
	or nil
local isf = type(e.isfile) == "function" and e.isfile
	or type(isfile) == "function" and isfile or nil
local s = ""
if rf and isf and isf("dqfarm_source.luau") then
	local ok0, d0 = pcall(rf, "dqfarm_source.luau")
	if ok0 and d0 and #d0 > 50 then s = d0 end
end
if not s or s == "" then
	local ok, d = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/main/DQFarm_loader.luau")
	if ok and d and #d > 50 then s = d end
end
if s and s ~= "" then
	loadstring(s)()
end
]])
end

local KEYS = {
	{ seed = 4232962398, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4231364936, exp = 0, plan = 0, hwid = {} },
	{ seed = 4231849261, exp = 1788089514, plan = 1, hwid = {} }
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
	"vx95Fa35WJL4If8yzxwlrGMxG7XU6CRCvpAJPiRagTiCMP8goEbiLyiY/Mk0aHlCyaW1FAVHRWHp0Iht97EkbmH+bHnikttvm5Rb" ..
	"fH4TiD+ZIOT33en7VmhBaME2THALHaF3DWQdzcZx13jnHWz4sHpNQZb74hW7n4pQxLO/qOMPZZCdLjLDLoTCTez9dfWlYUBMWFzT" ..
	"x9VwzfYDC58iuno8qzwGGOJJKey0FvBLbOWX4HonclPZDoNgAqua024qrvpIlmuDoIVTfd4Ut/rkJlPl6z9YF0sly7qiEJXwo8L3" ..
	"i9qEaXTpeyMMV/74DP/sT4CW24dIDjliWyxVIeXJgkvL898jZSRYmfpmqx14A1voT6RUtHVq4t0kBj0PLTLXncgqK2bsOvdH0A4u" ..
	"K1+BRfboBwiRJqi+VZJI6j8WwjMXbFckCThtZsbXXahD7gqQ1OPV8eIansYAya2CC/oE5+/hlNwKtcfquOnL0CAiTqaEAnE4OVF8" ..
	"S/hVvXFeJHdfGA2mdr+GyVkHFDanaObmW2CvDRZPFLXxMyxgpXU5/RrUvLmZFNmG1K7lSEdMugepIcmNOZ+ql1FLd1TfpvpjACOJ" ..
	"S50rl+pQf07nWMCKxvh7SNzPMaEs198Ygu52JpcLifGJJMRxpu8rPHJTt0t4AUQa1N/bYi5Cc/OBe57qBrzxvot3s86+DQov9+Ge" ..
	"Uz3d8grVYBbxSC/ZJVPQBi9Kkck2Y9l1VEsg4HrY/FM0YrPcOVsazS4EQwhMFPTy+jxZu3A8N/ygRx35oehXlR5uvxKUnT87Pq/6" ..
	"D1YyFF5Go5r4F1zu0xwyS7fEFBajjrE7IDU/6ZhRa11Tz9If9rHqTagHNX2jqBuAEEYNjsvt2ve59vPCR1TtI+SZq8vf2OCE2lC1" ..
	"sC0y8XI3BAoxMg+SCZxwVEmZXMlvHHocjzroQFFbtMQGJjsWHiLEFtCo5TFryysEalD/tFHQx/x6IRUs2rZR9bJaUR+HkLkIRTo/" ..
	"QhtWKea8AaJQ+MxV/Pzg2Xc63tuBgoDJgxdqVJJARTmEpvueXl6YSLntXkIFaiyW4W4niQh8n5Q0mlhbeZwChLbH1kagucVZh0hI" ..
	"SiK/YJe8a4V000DZI0R4sGbHTUNxclKphDXGsFnq7/HkbvUzEGMp3wbBBlnQXOhO9y4PdsZAOId0/U2Ei/IXSBVwdt5e6e6fEnlb" ..
	"GcFB3AnPWk31j+PYiIOzm6EpmfSu72EGN1vEqBfMJTYF5RMK/5B6hR0j9dAQOc/i5/4uK53s9RbaWfrFywb804s2lmO+9WZVmvye" ..
	"kwESzxdL74d2EcwRvXZqMPLbq/7/WrM0Qyfi0ZrCXFRNhNfiaKQ6fi3TpkD+IFVQ7B9Hb2AxfclWOKu69eg2ZLt7svQGy1KeIu09" ..
	"kQ5u0KamgFDaqTe5JpY/4ZNu2PRBsVjNRe1hnE1kqEDa50Oh3YojqQoXmgtReGC/o+cuddGTE3law654+FZ4J56VCQhuA+51Fpxr" ..
	"FnzSAm7EDI0pU7d1piwJXgT0xI+n2RXCanCPq3L+LIH3Oi44kfBbAfKdkHsiSxLbDNfodCQl+WzhTcMvx+wV4sHcTVgWdA+2wD39" ..
	"c2oxuKVkHOgVXOQ6bU6u88FikaM1P6JYtvfCdSqwUNV/ybnnro01LAGPXB72xUYO8PmiIFoGHh/VbijTX0VHHFOm2Akv0NnuuYbB" ..
	"2Xjw0yRGf0+Nf5EjjsDPk4toS3SDjXkK4CKyUDzd2O5q1hoNv8MAL2Sqs43t0ZkgqPA8atQTgO+FwQnL1KP4MyLbaNEXqkc2rMNl" ..
	"x6q3SZGDdtS3Y8V+Dx+e587EfRoTlQXwUcaHQ80S64UoSQetJCEd8CL+RsNwNa80/d8wkKvtd9JDGxcrKI4ryM3Yj7bZRX4lzNf6" ..
	"bEhC7lbWwym4wBQW+K9nW4OYm+Nuf/CXLY8jh3mWfxM2VXK1W00gQap8n1+2qyw0fJCDFbHKRshi1e3PjeyL3sPnzNz8bfI3K+yJ" ..
	"A4HCRqws8ykVM2otpOiYbFALkaEp9wGPALebmLF+p8f7pfZQDAjUBO7Xr1kU6mXrIinxxJsVQaxH7vKL8B2hPOYyITVwz3+/IoIm" ..
	"gnK1BiM2vYPFCGvd/Va0f8Je4/QW8EnQybr7gLumXv1QF+XgsKDRhwwuTf87ep+GlFLSvqIkYRQqcNLx0SauUEg0vp7NQrTfP2rg" ..
	"tTDKi+3n60csYuKOmFIOUZPHxMo59UzguVN67+OZNCs61+v3rLROvqcEymVRhWKbTTV+VTeGTYaPiDp3OYcfnkDHcRufBISYDgza" ..
	"iC+6T2kiEqmTxbC2/I8nJkXXGMKPt2pLJbJq90nTsTcl+ebf21H79r8IbG9FCfKIEtQ3ON99wqday0PAYwHHMtvKesNDhhQf2ySt" ..
	"ulzxEN0FxIJ2cpLrCLSvD45JgLbFwxbtad3Fw2V8L8qNocl0CLDm17UIUnbyyc0jY/joKoWxfQfpTSWMw+S6I4zplQweJUFSRwas" ..
	"cjTDxTE5qLKMhxkZmP10Wv0BL8DHs/4hvSi8pLPps6HZJ4emJifweA1E72R9MH2fy2uUyWN0cfc73gj0qYiOxA12rj99Vwr7LmAi" ..
	"P2RQxyQAihiOb/79pzmPpYJpmPdpJR80cPvyRc0Ot+DBFGTpnuLhUj+kT2UZx9hpvklCy1UcxlmkRUTMtCTt751GfraQXL4iQV1Z" ..
	"9BERziXTBhNj3ky0sg6zawlp2ayHYeeISNOTa3rWkMiGsfFMVeelj7oSjX8mcOWs+Am4BV4SnmIXtcm9Xd6KBjsb0PlNxqynLjMR" ..
	"/hQGlZ6OCv9E9aYxOWjUjmEicaPsDg/dDLlAVPnzOEEPq75f5RoMuavAjyx0fNGzMK6sIjfJcZ55cRAoJanqK2B6/+GbTtsa/HXC" ..
	"iFZ929Z/G0ZN1PowHVmF9gm7EIDn70yTn2/jXVGQcrxdkvW0bTVNyf4FtK6jHFXDAwlX57/9gwFhj0QGRaBlK1Iu0oSriPs/Z08p" ..
	"eJu0eEUuujoabRjKQtBey5perWeAcJTY8QNenbmhYglKRhSdhbRLYcKs60z2S6nQ6CpoDwJhxKIgbAoSP1wnCqVMOsc3Aag9Hah7" ..
	"xwovFqvGO+G5vtHIh5aN+NHhPCdrBZP3YtUJ6HJyRF7A/1yFH3PNapp6ExZOxu5SyffJIpFHHGqIXKekYTRZ/VstVczLIYHg7CYO" ..
	"Pz/AcaxiS6s2FSgfPmJPryJlTPx8lK7JbJKo8roQLrCZzoObAt1kjgWMuMc9NsFDyJBNpAlhAUGJiRRnUMhGYsGFvx9oAyVIXtMg" ..
	"2LZG8JQU9Ycl7dR+vcLfINKSrn9YceBbQ750dKSNXNstLMYCHorIDCsoctNrkNQMXYv02zvF/jrAIplTkCcWlTETSuNc7HNQ4wZh" ..
	"vELeNLAr7gFDAdJz6Hy1xDVzG6Od5xjJxH49TLP9MbKYA+PE+GRfDqxOI5DNUmScN00q5sMpvXfZujSVUbsLMlQpR8njUHpK7GWz" ..
	"IO2NzLJjJToFbrkUEkJ4JrZhji/zqokf+A+weptC5FbN0986LFstMKXk6vUQR6provl7QOPefM0vm1LR0h78jWaZAspEtdDCjZbe" ..
	"k6Du9VrnYw2jv/hDGZz6zhzYfWVHBsdJdX1OwzzsCynRJHZMu9Uxs3Vpw6HQLpEn+gyRpeY/cEBohRA1yFkxfZpMH+TbELdHmROd" ..
	"0qqB/cB5U7Q3Zf2sasbeHmUf1MYyGoQuKS+oKJuwrIELHVusV576lbj4bhfxY5qkou+XW01Q1HmXoJzUMYa8/2uZFflpJd3dFEeD" ..
	"KWbN+Hfu1J9I2H8SyMItECe793HPq3p9YNo0eaa5yD4LFhatHNrEpjekfRv1hH1bBnmlwf8aY9gHNTDLt/gSy8wJqDw1JbICckCK" ..
	"nDzkha50g3w0F4YhdERvqvYYbZ1UV+lZa5aY9hlXPOANiXZDnB7D9mTlcJtB1DGvBESjKm2pL78NrqtMohXTv4inwXsdSj0jLr0d" ..
	"1teTGyndl9w/4dwElyJdItJ2ixxPGu7d0Dao1n9k2J0YWBdkmeQ6CVWcO95wZj/pAZCSPaB0AgIsSC03JE+YrPek4EU55SRQyk57" ..
	"Dri5h4Wn610RRQ3BW0QnMWeWoEu+ZlfTjkekYBtdi0wMtP42MUTIQdqYSMdR225ApI9fCC8rxqfDJtVWhU8xUsTu2tx9pDdUAeGf" ..
	"ncxmH8cClY9Eha1Eqh4zlr27PgN7giEgbQ6akhjY09cdTqxWis57h3oUB8KeDNUGSBRxEaGj8z0wdSR2SCUPScl5vXLm7LLwGkdo" ..
	"oauwdFpJytTZ3Xan8Yy8V/zP8PsAKuL9yX4ZvaTmuLP1DxPSVUaD6mpzM9nQVOflzHC2Jzjov2xooVPK9eR/cHV0bdNKJjeDB9K6" ..
	"DcCBSBkGt3qyEkbeX9avAMokOou74j+WNQYdSUdBba7N8CPXDa0miL/ijRlk8tEHlO6b8G5kS12Ubzc2RYY8z0BAAY2jIe16WE5U" ..
	"96CuY3UvoOeTvLPnPP8/ZpON0wcsYYNxZq6lcSDWm+LpSkh8kjLCS3yHMxAx5P4OCmk4qgMKPTNlV40ZUMBeaImOirTMgidYk/Bu" ..
	"n0v3V2HAF4s28RDPBRYyhLyb9Wk3RaZai2rRmSF6GA6AoaPo2o87OzpehB2Y1jj7kJdMcTUEGWGBTQtNi74CGtdC5H9DUt556Q/A" ..
	"SZB2Aeg9Y9VYC4nTXVVVTuZ0xOlh9KoXKEWCzqxW2Un7CtuIGBSX7GvKPLZBuVaah/p11R7qhzZ4bOW25QK3Nq8clehbe80w5Rfq" ..
	"YMU+B1ugcTuWq78SxWsZgXFXM3JHrdbWxTAOdavlB8qXz0Uo6mXmdupI6FIo+SuNTfeC8/GQbFbiaVrH/chQqADf+8/lixz/3H2k" ..
	"xj+10E5adgZwuLQXjXoM2gGBYOkejI4TLOFAKqqndZw49cUJ9Il+XZ86YZTjGP43vY/AKirK2/+5rWHxh6D8vCWhXpLP7zCSx6Jd" ..
	"zCVn66bjDWvVLjvLflVWRKdJAnkNJ2z6oKThTjobpoaVyhnQfFR5ZUslmSHyCoWBGNcjRgGzKF7GxDWhcIVo//NPGZ93zlsAv2Ib" ..
	"7Wisln1f7anJRGwfhMgMO7OMTxNc5RKqnqlqm3ZomlB9sjMk9YGjuZhBldraJVyCC+KB5C9uNepyWjtsuHMyq/YKuBqeXGAMT0VZ" ..
	"3DLqgm3fcsQwhuFRlnuLGkB4RUVfohZlcTC1QSPfVUt2z1ARbMKDkq/WWhGojIWWEPtZr6ueeBly2MsJoQJd8jdTk+YoaM0SJF47" ..
	"OQ2ZE0UvHyji0fgdhloSpb6NbQpTWvKJGxhbddpYBd6hayWQ1D/q7PBfV0H4Ppw+q4Ly+GeUHrblx4ZVXvTYh9HkWcKaZc8SnzqA" ..
	"sdqS73WvEJRp6PyTbmxKS7K6e0/MKYFKcCxrxQ7WhbwpHAHTJ0Z2PWhSZ3cLPBylifthbcvueO/RsGnVwfcMGV8h+DFpb4o8KQ1G" ..
	"8eGj1debPM5AOpNXxosl1SPwa9gSlwHB0Pmeqg162yKKSupBT2dn19ZwJpkWKckGicxA9yGPq2Fha5i/7CiA5PPRLv/WyL7B4TZR" ..
	"2/1LTRBPCRMzRCxFKSadHWr8KSGZSjUCdiabveiM2eBMbBoLEKmgmBO+7bmZe8JqvKZiR6IDq+u1Ab0vgOLQC7WYHpgkGkJ+mZck" ..
	"WDzlYBzO4WXmSFt12egYUEckHrPlDaaN/yDne9SGDcXR1h/o5I8SyWmi1jQ8yjYMdKGoDMbGYhlTdIKz9iv1DRIBpRy0/ns0GG9m" ..
	"rPbJnx0RzCsmUCZM1y7UhsGwAochERdR9RcKx8W0+FtRV24aLLDyFJBZ2Bg2QM0XvZIk/wvdcali+l02R5J3Oc11GpqTjxPrEyK7" ..
	"X+0a3dzOE8Ajxb98ZL3pnh334DY/sZXKzOxEPvXHio1yE3bB4lIeoae7LY2s6i54DgzvSGquIz9e1HMlRN4eIFD4XoUEKRJKKkyj" ..
	""
local PAYLOAD_P2 =
	"GAEDG5TCxW8swQNuDOELpJvUJ7uMeBO+aIxstYyi8gQYXAv1clU8zV02hqyYxd5xNclFK9uF1Mu38K13/AqKxB3F0ttz48qZyAAN" ..
	"A1z6nfXGAy8f4+AEYrW+i/yltG9/lalu079WXMVjJIZMmTsU7U6IkfiwBixZinO4OWs2uDJ53bIzlQi4j1zgFznofO4LAtglaGzi" ..
	"hem6WgK/yiiNLZV6z7f5NkJFMRR/AOIJHf+JIrmzBaj1ntcaXvsDyr732Qpwj/9vd84PyZ1RDQntbC7Cg/4nECr6qkpemN3fdowI" ..
	"YcFnKwKdbiuh8EtA2HClR9ccL0N9NtGVX+nJcGau+1tijlAf8GMVE8rICSn2vAovbfV3dDR1IPeyXr3JSqTzjiaQnddriqQibhBK" ..
	"gum32tocfm0as3qnIirXj51TvS7BhkR/hJZbHsQMU8yxgqQrROTaRqC95LUPfB0A3kGh+dwFo640lZBEVX/2dYgl+Nc9F2inp2Gq" ..
	"ZXQCI9UbjyEGeNNxn3eMgS4f0jJdVTi0ZwaUw1QELM9CyL7XXYINWxyDuyspUnECsWyA/LVFZwyp960Lj1A8qWIzBElkdteIjQtv" ..
	"v6ZDUS6G8ARAYfwlqR8AEWGWl+JqGPMfsx7iSJJBrZz0K2koDpSlP0yFLESuJBV2vG3Iv0A0ukC1hjX/SrFAf/aZpdeusTiUx0Ie" ..
	"cSYh0tg3RlPohvtI6z6fwmcff4Gmv1OATpuACFwnTDEKAW0KyiEKsFCLP2rHcU7NFks6ryNJDf3va7PNiUGphZ6s0WWkNuFlaCyN" ..
	"w7nJA71Zdu/Gdox1aip9S96lS+U0zlJUY/EmILtq2vEA/8YB+yw2zTkCzpkzMlCX1jzks0uoLHzpLFTHbg+WWjYsld0ckxjj0uxK" ..
	"P10pIA3Eyy2mfO0hjTaryfwJ7Z3AJyWQpzeN7wqZepROIc/D7ZMBBzf1s34bTo0aG9MMPsqz/92fbm6UhWJ/vYMKBTcbGO2pbv7g" ..
	"2jjpYLpbj+ORfxOweK3xmIJtvBnG12sI7dQCb8AJx9ayDisyQ/813wOIV+fx8PX/iZuPRTA9MNyN0K5iAewk8lEAalrg+Gp5WoD+" ..
	"er0EVDiBZUPkCI7DQi1E4dj77VJEmsIucd1+M1D0yVsF/35g2RXza+Z7kfjj8Sp6e8Vj4vBMlGvJcFCFGrxhuX/ZRo0Ike5ezJES" ..
	"sPl/vRjnunz/+/Zkqy7IITyYV3gNlJIQ5BfrI2hx+ABJCVXFUrz0X9VMyN58YHA7T4ANlqQP6b7Vn1rJXkarpCce1nxeSlI8Sxyo" ..
	"IrBiKa71akKOB6uIyRnkapk0k6W2g28zMg0nDLSdoGPzvy8LiJ223ypUIiabh0ls1XaJ1OD/ffwDub2yCPAWU2mc05qIOwHa9uvQ" ..
	"b5KICBp/8QTNNCLjMh7gaOYeJ2MV7Y7wnHqO6fq5A2ywfq14bDJ1nkBZvNWMr1X5rw9e0nVP7VkmX30pkZxymrJR5hZFkEaR0vJ7" ..
	"qSOK2w7nW7UucMBZOh6oJiPknyue9EbShWhAIhn2X4E9ts7ayol6rTdoQCbP6ET+Q9Wnm3w5YCaV9Sju2mZKZG+Lo8V5LZZZcpzz" ..
	"wQkGZdIMSnN6DOUrD2crYOabONhxH0nU0RrpDK8M9UOnikj5jEOlYF2EDPEgpIkIiutrsge3Xt7D4eBvdWximp8iHw7Wh15pmSKm" ..
	"LkRAfyrb5AaWkXzT3kZQmd1JXnm7DbOgd8oofn9z6cpdYUXejyJf8kpZDrGbg31rjQS4uIk/08OLc0ls3vMUU/J2RJnzIxk1dMyr" ..
	"u06PZqsUCuHzIhFjJ/v0UfyokOqD4jtjOcJPAeRiKYy9Puw5AxGoeZ4w2yIyLRr9S9XPD2ljF3pXlrJ5uW3rGvCLwALQC07B06A7" ..
	"FuHHcFrhtbWPk+7gJVgpAl6hOMrSy0QplHyGt35jLpNSSvGoQlF5kR4+8YAoNGdGiIJxxIOBbWk8uane6gEp7zU0uWRI0qCjiu7l" ..
	"tm6Ha3eiLSsiD/YyeH8rx4u+5Jr5pjibV7rgYdjYK46m0ZjCJmB56wd/4UWbX/XnecnKCk8ORNxf7ET5dsTGANq08rRYn8bsbmuQ" ..
	"sNnhx8ID6xoddC9BYCYdm7w6VRxv+gO67l9OhF8t+nA0b2I/GhQ7IRThdYqvYs5wcsgoMJ8ISWOYqHVE0T2hl3KF/ZZ5yifndHK+" ..
	"2j2iuZqhiodI1TwuzoBCrjxIgq0Y/YogTaaHjuL0pJXRMF0D5erwCXtJ5ZaxYHEjLgpsHX4aj/mo8A4uKlWXKDZ85Q1QeJHs7LgY" ..
	"zjyDb/htz4mQqv3I+4oY0Jv2i482Uq+NM4bDCAlJdy+/lmYlQFE1JjSSIfDUnbrvdh3MlGD+5cicimYYZcbMD+cUxaI3rgjapbem" ..
	"/TdFUUxZiT5ltLnsESEnnzqkK7tK5PGuMYLa97/yVers92ueVhWMXgHX8led/oRCkP2gnawp5e0T3x1dMCWbtdTkIk6YhZgu+doe" ..
	"e5/rbOWZaN/++49ttW3eIlRvbURYvbnUuq7Z3ZBJwF/O2tSKrCy6WCmazgy1xg6oHa4kUfCxfeC+NtQ9T3cLnO+cLsM4uBxkdpRz" ..
	"9hdX4LhEZBF36Btv2wtGzSI3xRIyj6+McJhkZ5d3/9WjToy/D2x97hsXNtn/lg86uZLtx1Jllo5foWbiPX/cZ/ho7EmAjfiDhlbt" ..
	"pp544vAiKgr8EqT8TdixggMS0mdhBUwWV/wVoQZqQ4ZMXTwt19inqBe9Z5Go61ddajEL42+gTvpXbEqfydKrPTe+DBDzc8+MBzKL" ..
	"DghPc5mF48Y0wvphK4IExXOXVdlDAQdzv4/wfhvhB9qFRWuWD7nOvxvneHEQWCHDSvRa87YPMsRqkIwN5/AEl6MfOIbcIAYqBQWD" ..
	"QzkKx6Y2r65HG4RWDoZB63zrTHRqEQcc48S1RjBvzfLFu8flxsXt6Oknj0+aevQfNNlKLqvZZnaxUhv4+JajHyfy3BRCel/0CtUa" ..
	"v1LgHAOPIEwWh4wK5bM5l4DR0B6Epu9DoXKjfGWN6Aqd2n1rYo9iRSX1qjwDtXDy4HWAfc84eck7AbRe0jvyu6cM5UPKic1P5M35" ..
	"GahDCAYluS/wWo3+bC8jZFtFJ/1DH9uH9Q+BgiYcho1vy8Y8Hfq/wxJH1tlYv/ZRU9UrglJFoSVl4u55KZQCeGdSL2PABFehjNkY" ..
	"UU+A7YSq6zXbwaT1cVBv/MlIUOIwwr0IlLt7/tj71AsX4SVm1xipubEcAQKBlvvHhbE6mlSDqNm1kUU4QAXtAqp2q22eqeTidQbn" ..
	"3R969iBMNJC7yFmCvROKCqjpLhAY8DqwkhQZm8QgDD77xqhGW3YT2/Ow+ksdgjD3mIao6aezJVlfRqMcgEXR/YOeEeteWclGet6D" ..
	"rdZLJcicVbwUA3wZl6QHQUFfO42p3qS4t74G6MOq9JY33w0W1MQIXefaqSN6Zt/LMgYJclg73iLTjT7qnd2WGKc4Pa/i4lTAgezN" ..
	"1Q+voa5wI8MFA2iCyf/pVc6GcGST/8Z0CQnfiJGz107Jm4Z8P6OJfdWmjDAVNK06PQOyH1KLa+LtLOqMrl9yNg02YODf2mDEV8hu" ..
	"ZElyYFiz4cxqqwPwjbKJjQNKGgFRgNyVdfQ+FHCYWZZNspmZAgHx23J+Qa8ujWW98zPFybc1KhX3zJz0pdUlDmV3BDflTLxCtOKH" ..
	"d+QgbZCmqYU5sl9uz7Vg7U9d4hh32H62cG7SbQCjgR1nR8vpwZlCEOXBKvdm9VycwQk7UsZJ4SIuOvHRaNi2lqtXSCrmgxi2oW+R" ..
	"ry5EEPBL8Yo9RQNfchuh1cAs2yfGOy1g9eMxzN/VBdaYZcoP583Gahf8+YPggC/WhxxHUfIQZ1iTATUp8q4x/+xqN1FAK80uUp5L" ..
	"UjwNtSRzqKEeSinreow43lvy+HBdQgdy6oZtqxpQa4Z652ogTYKQuc42QmtiVnufA3bjcz54Rfg9LTPYFNqGFMl2YX0ieB9eKGrj" ..
	"rouSjGmlSvRHkM96N5e07A+nMPOrrvI++yYoP5ZgxyfIrgP/PRdyOq9op4OhLe/TFcyc03dlnaHWPl458EMPf7SfunTm90hUY74f" ..
	"rIy0nkRCDmyJY6vUqlmVrucxp+FbqzxU+I+MD8WBrynXg1u0l0pExdT5yTQwnYSbqZttrhZtovLprsDPO6PTCmsMbHlr82UYJXTz" ..
	"L48+BfL+GpSNj9iwCLLCEFXVly+AK09vwG4VMl1j4Aqj/XbhLgRTJdzNLyOb95wSS6bfpyLItxHOD7fjI/prIismfBk3yuFT5ope" ..
	"2w6X6+ztamFGpxgBnc++Negn/gsNUNBeuaQXFz8ZUbXbu2X0Uy0Loee23h47rGmYC4P0To71My1EwCvNOE3vUQECxnRkbzI6ISyc" ..
	"vKeE8L61hZ8oK6/GnAHIhTEI3yQNZcSx0E+6fxn/AlCAMjU4N5VutEYUun36/dSQVi76f0JHJgPrfBemJGoD7FO81VXqLMsxVygK" ..
	"yq+hC4UEZXFcfoLF2iLnBCxpA04G6KJPo39WLzD6IKR3dc2xTMwxJS0E0SMb7srVPHQm1BgXio/9TgnYpvfg1oxK3NXBDvMqO53R" ..
	"kIMg3xX3mrKM+89CTvV/3AXBNGbkTrXl2V6eYWI4Z0Nf37SzQhlMQYJ3J0C8Tr+doiXK/+/MwAQfPmCm4CL1cJmBmsiMZFZxjHUP" ..
	"8uNBDtu0y+RpjiNGLYb4zJlCFp15Wj8AWabBIPTBFHtsOjaDX6gbRbG4WCK7hfO2LF1MqrkaSwqgxiOg9TwK0zO4pWaR7c3vaL5O" ..
	"aRZkycP4Q/qqVwXboznGUgG2Qg944Bpqk8LRNeONgVfWRCaK2dZcMvbLWIiGFr9ZgNXsZZTNGo4quWoZvk+r5WpUKawed2+0YTXK" ..
	"Fc8jBCPD2ndwbslY/74OyYTOZGnjuBMFkY406R6XBMNOQOE2CPVcJlcvuEndIwzTTp4oRElO+k/box526fR4+mrVtyooQ0Y9wido" ..
	"nX+B867L0jSQipj0ynik7+9UZPMYLuFE4VAwla89iawc1EO0zE7TjtRiXgrwgPcP1j+Ow2SSMfmxFrDCbxoJrv0FxTKxuKSXwZrh" ..
	"1qw569W3Vi2ogS5u8/ZvTiawakjkkFH9rsSeR1kFgmrig7lYd2m+xp2l5hwSxsZrHljddvuFXyAX5km+MbIlzutmEG6znoLX326R" ..
	"u3Isp29IprZ9V4PX8z7+RkTbSA5fWvAV0PYNPeOvy/Myhfn3VoFz4e+PvZ/650ayIoLGD7AE8r2bRg/dTQ6KMtScrCX22nEIAzRy" ..
	"463854LsOESXqo/CRiPfX0rXAh/jfAbk3rQBpySpjK1mLsUkcnQplczN2cNVTcfahWlMWIqNGHFvReSHW0REV0ZB2qQyKf6cDjkF" ..
	"6mrn5hQ8pcU7nrlAVw5fkYHkrULrF97O/dWBybisWZL8w+ZsqS0W/fGOZ5uMS6J5m66TaBph0HgWBF29KtNGiMOkG09WJqFjRNkD" ..
	"qk1HcY0oOP5bx/Mfs2MPZBh+5T/x4aoL2OuftcI3wUjmSbj9kaPiVMfmEA7tYMGl9p49tEZhbnCX2nDw/v7kYsaawZ4T2GmWh+At" ..
	"MG2ZolHFo5cmjgSBiDt0LHD4N3JfYyTu92zVGLsobRP/rBNxAqCBIQn/CNlXlhCUPWjeTig0BCh0Jzdd6nXwwJ7v/wd0Ollm4Ke0" ..
	"veSmhttCmbMkihp7PLVseqYvAwqKx6PWXgFzo/A90XTMFksDqpSwuTb1Sy4jOhYR6LMcu6a7dOFf/GwkfOV/lfvodNjbkZYgW+bP" ..
	"COVR0nGwD21VaF2HGp/sguARd98qHUx22NAUVCyi9z3EH6BBfCzjdY5xUu260BZGEtmFl0XBHwBnKMtBOTN4/G/jRgQmhBC40Gpx" ..
	"UQorXUfXJVLZMcVgKDGEQgFNg6nyKq51xNq/RniHIk5ziAlBCH1mNTlW8F4kqziR4JSc38qOOh0q8Y3FxPxeYQNmjiAJaRaEfDfs" ..
	""
local PAYLOAD_P3 =
	"A4Dde0Co/8ODsSikskNaib4EiLgnDaHzXiD+p1VeBgScxdPzJzde1ftzp/Zp6hhPs4I21vuN4eMYBcNwmy+LetTfWWW4voF8uYzZ" ..
	"lpo0LhYzgN7YJsgfoftCP7Lf72Om/ahZoezlOVsCjPpSaXmH5vatNKIAWGllVabRV6MAu0h9/pm6ILHIO7KINpTH6JuYj2t7R9jL" ..
	"t17vlc6VS5GLf3pymty+Ou4+o6YSfCD4t2jYn4jAMgFCJ5HiJjn9neDmVp2H5kJCg5lOTwhjhITSXMbASpiiWYqwt8dE61bDkZm9" ..
	"GrTkZ/vh9d3bRNVUaB9XG17qpK6xxHgiMcB5sIVSf51FuQtheDnl3e6DXLL9zS101cj7jrU2D7nlkuIAySuSWTIS/N00jdazEM07" ..
	"+3To0hNTlAHjddqx3LlJf9bj0OfOKHzspAD6m9LHhNFY4hSpSn7+DuFOwXBg4deq8hUv+FcSKORX/2bdLlDDXwnPLhT/c+NAvzNA" ..
	"cKj/nTnXtARVBvl7HbWhE9pMhD2kW+l7Rdf0cHp3kUEbMkAhvmoQ/zSWEVDhswduvQTcvx5DcD/haw2gG8IzaecAI3y0ffWgSryv" ..
	"Ve04ViEpl99kUDhDBUOY36UQ7/w3r7vMTjFD3FWaOpB1VoloiiTOlcPgsReAmKvv86OKImUk79B9W3Ta0BgUnSBdRU8shfVb01DI" ..
	"61CBWa8FylcaqjXBXBSGfwbZWON/RmzGr3yxGC6D+W1ovM5GTkYaPPdYebtyJIKBuBlaVwEqU3hmWq4ryfC2yQ6aDHpppCqs0tKq" ..
	"HI8M3w/e147qZsj7Iyw92jAVEc9RUB93Nv3sn4mqYWWd5s/R8+207wjzHh3oYybEZM0usjVZugXmZV9O505v0CKGOEssT3Fh+Uhg" ..
	"y4a8lYy/KTcplPO45us8QloB7XMwMxmsCvsKcIXlPujezMzSbzrRhhKY5Vx2fAqyrC9uf23Nmim65Saytse6JsbHD8mlrHBhkuos" ..
	"vUlvs4svFegIjrOlCIdlo2nIS0CI9BLNjMzuv//bfo0lhI7i+xNrCvlm/BgEfzNOL7fPIjte7SCP4vYeDDuIOzsWR48QGpBY9AQG" ..
	"PZtz/7k9eWr2c2J4/nFaCNlDzUK1Ch7gqxuTkUAGNdH37xxPciYJVLQqozyTYmRPgCBWMewUJtrhrsu5ip3nQ1M9iIFrrZqxM1hf" ..
	"XZV6LbdpckZvBt//4+BgNYMc7OQLnjZNFiVgtKtPsBn/c28Plkhk3QBznPYrGHG+p2vZkiNqo8L4lHIddXum6htJ1CmD/axtDgOy" ..
	"I7xwGXUfS+dChGTH89XQ4/Soky0o+1MWFpz+STa5mw03Oz/4YzaqCbQ0BmcvMNLwTArlrZ/m3aJ/5KNSVAsLou1vNhoH8ecPRAbh" ..
	"1MISxd4MEVFXeb3CrwxNCleCzVq1yFF9GUy3q7v1Hi2Fg0FeS+xa03gqMPgtXOa41OR3+67kzuY400s3uNBLIjyqbXTJfq9uZCUG" ..
	"UbdvShN6EPx9pMKMtCtL7qsz3B0FcMP2Pvoy/wVaewQ0+QRkCoVIPZdT4u094CsBzsqn4AahyKEv0JuCfgfV0RO1ZMBwvsqf18uV" ..
	"TJi7H3tq2uudyNLDrWzTCEcpxM5m5VnxnEZ9N4MuzNwNb201ZqPWAhwLUxzZCxS3zXU5fw+b+2p4HCm2M2FYm9IZl4J8F4UaXBVs" ..
	"iZXpQVxwVR0ekM7PMxKN/gYeZsuMEGZzAccykQc0qqxRi0UnXH2AIqcsbKRnh1y2SXfGwsg6w9+QiQQioRvvSMcpAMTEkg2VxUjv" ..
	"C/Qb4D091vv6w0q2Y4krtF3C4P3nPzKEslPaGIHJLo/MC1i22wcXzzhXyAeb/NdEk/FkGpM7h6HsHARGef+zkW0SUx6Daz7mbnA9" ..
	"xssYIWaYC7DZPTI5ria780ws6pxkYn8h7+yFoRfW4QItlW4x3oSOMV5jLCGwECCJyY10KxQtbONcfKtjeyxZnNi9yO8n5ZYy9fBO" ..
	"du4LXIUG8oKv9hoqqFt+o1N6Oa+OQ6E53JDIYbc1fZSdGhjv8CrCHuqiKIzL1OHLiv1TIT9L6JWtQETIDk22HmPVbTrlEbfywdL7" ..
	"5TnltYfp++S9bU+UTsR0Wevus+C4wCx06/vMKdWyLPjqCC9vjfsWEVb2vMQayM6B1geZj6UhwnzXDde5PToIHJbQ2Pf140WHNF6z" ..
	"QqmUTYwLsdB2lZ+aiuTbf7sg6hXZ3i8P3SGvybnlh0Z6gYptU+RMLxPzcCJ588kzLHU/WIeLI205tz70my96i+Q1G0W7IlPWWs12" ..
	"FtoikJqDzSQh+ucbBrUdYsGfjk0CxNkR+ghR4FwkEGMuizjyrc+u/hHL2LPkrZ+X+knRXG8W99V7jO51YKE0t/ocsKNV+JF+9qQa" ..
	"O3sjqQnQO8hwSh488Ek8+4ZaXHYrE0nQsgTt+krBEw29X7q9CLxp2ola8O8Owi9dL/HfXhcjIBAth2epc+OBlRmVYrteMuAWOaAi" ..
	"ChyeltaPUtjaQptFrv59gZU9rS9dgzZ2fUq0mhr2e4ziESFduXbkPji3pXMaddrB6sfKXUANIoubg7DmgaevmM0+tNJHyuZwFzuG" ..
	"bp8Re8mmtvfRM5Q88Jq+yYK0NLAAwgZsitdgoZBARTV83fU5nJmWFUlut/0gX2xPVBPBqYmWT/FAadpXX4cI/TnFFezqF/YOPBGT" ..
	"dcWoYbHMbJ9z7pxNQsKJkZm5CfTlsz3M7nfPv+18NBjbbQIc918reHxZG1H9Nr9jT+d9En73M+DdIzA2Ucaml/f619hO3powyf7q" ..
	"gSkQ/cHiPGatej7ok9YRnU/kxlsiAn37kbhiiuqSjl9BDlgSSKwB8pAFSQSMTI9iwpjrqHpIbapdi8NR0k3Q13c7yippD2Lb+PNl" ..
	"Pe2RwUTE4F4m8XXzArYoK6UvewjTEAIHMMAXEk3atS6zoyrHDS21qg+dGk11DaOruPSad23ZDEHG/rqUc2EPUCs68mteKtTNrlXR" ..
	"S45VY88rtbqZveXJ4UfqmBuqOgLrhP710DNBzewHMwVSkK8RT+QGC88Tw3v3ttV+p4mr9fBRot8Kr4YNyyEPFZdskMrG1gD3obw4" ..
	"B7viOfTcRC1fNZOEWQFQFWtyAw4FPHiyXJmlzM43OVdNQ3M0vX+NgZ48Cdjo/1C5QwUKGVy6/Iz9GXWXbjbTPcgV0albfp0+Nbq7" ..
	"vpIsSuxspvF4Wbtt+fxNWr3olOYI+WODV7H13j/gqSkRzO+oCnTNqxtN1soNEf9EXDVUPFzqxYxxbCUzI/g3sarNu56Uqur956V3" ..
	"8Raqlas3zyk2HO/Q9VL3wxpYf99Wpxd9D7qY90daiJ34X/1nZgEwXyxm16J5KiWgLnRjs1hrppm9/C3yYAKVRfFlyqggep96Sash" ..
	"INtxHT2t1O0IDLJgyK6pQj+WMIGlJZbDGa7xdY5VYhqeP6GeDTc+UK2XVHeSB637KHMZ5UDTAukEygR5CEeahxitmsR4He9+LzEE" ..
	"hfbVP0AJ+X0VcoyFWX4cNuwQVTB2hRa35KKBCz9OaDIFSKQqE0MtQxgzgggNiWi0w7zXKyhvnSncfugDHl3IYfGQaUz4rtSNkadz" ..
	"Sbfkdnh4BwxyMDloOQ1uFeJ0Yuj6og/BbVPV0qEG3ryO/RGWghG02mqiP1j267Z2UaCRcEBBm9Xdy/aZD3a+4lJM7BehFP2uurLW" ..
	"931aMh5/3WdlWXBpYeXIakkv0gXw6jpqi1eP9Z5mnqlw0RFCSEdsZHVUrMzGG4djlE5pcyZpS+I/YshJ6FEnLHqV137Hb7acdswK" ..
	"GtofgcPdMoyaCYOLq09Z7/mZCx1L4toLUx6lif73QmVLJNAkFmJxQOa5KholQoYTYxxEqv0Nygwd5t6W6jPwmnEjqaDOQGH/APFa" ..
	"YDHBEmblMCvvrLsYrQap+/Q4vYkhmD3C4znihHonXSNdVRJBDQ2Lhex7MUf9bbkb8vb7QIH2pkdaUEklVlX5T2pscsKVO2OexLCB" ..
	"E1U+uq4TeHXTf+E3LwMoLOJsThN2etDUz+PubMZpSh2ciikVl4LHA6KnGUzHE9XFl+eQfk2uM9MJYa70EUw6VxUGePV0Osiwv8EQ" ..
	"F7b4k5x0gpG7TPjTm/eNFDwGCB1hBDpWwsPIIBjIpmGvMCkJYPGFA1qszR+zKAcZwPJeW2U/2jMxnMvwU1RAmPrySm/fH1hOYwyL" ..
	"PUFH2V5hLMNKoyKwnfvxXFQtInOFJmtTzmMHUcASxCM4UcnVAc0FMlJmlflNbmsJfAqVai0ybKRAXfKCtttmMdd0yrGCHPPKUaKT" ..
	"ttEcQbzwh8whwQTo2D3DJXQtkPSLfykxgpAr8NPDZ/7XfEqJiUvsHDDeqy1OrzkpoLJK+kvVBJZr+qtlxOAwqQ2azPiZgikJeNr6" ..
	"f7oUzTpaXG6YB94IXyZ53XKKU7pRMRKwOQRviYeYPXbncR+iigX/bifbgyGTLsenTAXRCXF6er0J50bNSaUkKWOlrYuu13EezRxF" ..
	"EcaXCnEmhiRjwSjRsN7iGZkiGzzrPLoa5gFkQoJ+/UMTK5+26e4PiKUoHkZXppid83zKBmnyTDsM/YjYzonOV/EZBa23sDBSsLAz" ..
	"2+ruudcc6qV9cWmAetZIjkbDmnNSRd7DC4gg0bMLifJGQaOEnIY9ARkIGoTS9r3Wc9xD1s4KME4JJlpKhWSlmWrECC87YT/RNCDw" ..
	"2djy2S9pvQKURG2y/QOtty/q1pkVFXSOTMpfxzNZqj/dp5YaUpU/BOMd0947X/6c2ZKMw/HUoNIvfZNKr39r5JgTvZaTINuUdERC" ..
	"6I92OgJU6zQPYZEE7BLnnW5o8ngCWXCHyWRtQTncyguVdIQqNb3s+L4BOLzW7I1Tj4Nl0hpxL1mAxg8LpfHN2fDiQPodUk11eyEL" ..
	"ZnfP0SFDICoQYwcsezx4XomTmXDYaM0RwPrF/e5pjSm8GZxHGNiEmWR7P4WfQSkVB3OVI0Z0+rh/mF1ofHQgMKLbdRYW1iqE4GzJ" ..
	"xxOs3kZr29GnqO5iHK6MlCt1Yb9BrNwY7JJemiibDv7NCMqFnNoU7FTrxWXq2kIfqBbjZwSu3lBiu+fO7thw8CVqDRD6VoigWGnC" ..
	"lZ2s+4e9CvHlGWTkuUdzEFzPT0cq++m+ZsScL70VczmAGcBu5yaHf+zvZmwlPggSQaSZd9fJ4rA47Dgl69LNXpBYtrweZ61x6F1O" ..
	"+Kun4yWYewGRGP4t6ZD/zWYD9pqI0/iP1Vqr+zNSofvUdaR2HlkrSREvzyGgVycv9267Yn0Ed5yQHRxYjgy+tEwFrjGALOBAgGcB" ..
	"hq/Sh+u9laBa9qFj+Bj0+UJRPKzCd45/Oj8LfbsB3EGggl6USdhS1dg3fSc1d3fbDQOzJAmUOuLOA3Cf8e9gji/xD9j7RwMd+M1G" ..
	"FK/zzl/wMFjs8Q3tCCEXH26Ux0LTADkhhj5pCsUx9Bbg2KFOZyv0DVczEWYljrIDjxRm5HiFMNGDiKX7CW9Yb75B+KNWCOf5hVie" ..
	"7lPugKR1QjQWbpVqeix0V+BqlMKCxzQFPpM3YTZNGozjLJVBMpWes9q2wlofIRnnrtrLq+0rfCocDn09Bso7JQ/BME7DxMMfkC1K" ..
	"6IYP5Sk5EtUpm/tUFyUOJiX5HoKV8nEhHB3+xxU9BWvtQlIGjoj50lcm3x523Pve65RmCUr14dgpMoH/LE4gzB51Qyb/iT96FqTN" ..
	"FCxGWARmKgX9UuLVRlKFCcaCBZptYhJj4VPCVMl5JrOFtKbxUIFEWoqDRW5hG7qZCPnIB0/voyjJIa8ie4HlZZ3o5okZsVhpTpVE" ..
	"ONzsQgPCon/mBml9uhzzFxIy8LnRilc6BMB93EgazHIdPgBpBdXRnzz482zTjxsft2v7p9a/efzj0qlIfHmFDkPCjfZR8lbN5SZ3" ..
	"WSqVj0KWgSD6it2Nzd5k+AR8KWAQkqW5yGLPYRE2x9nF4Y38L5135YmiMg+ZTxODi4DqL6ztXl7pkPPNv/oP2rvXtXYc3aHi+ErL" ..
	""
local PAYLOAD_P4 =
	"Yvci2IZZ4wR5PDlomk1MWg25BwTUmDZE1VyaETOJkeUjj4FexvRvudxsfk3URYSuLy7RZuPx9Qy6fuvcDNF9Wrykjh/hfJkBSCeN" ..
	"UHHaQnYn1sMgx6DLXbqNv/1KBRUzXgXbCx6JqKvKSXoYPhpu5VmRSASgvz2y1Sv7TjeH4leNe0DTru//HqF1wVGbS64oAgtuVPXk" ..
	"MnPJcDN9rqWgRsGpwPgRXZrxC1hkS67QJGrt5FrqFrnO2DJhjQukSgOCRgw7RvZuHyaMMeAR9VhM97GCLpd8pZ1UA/1na/Q4xUpb" ..
	"rCxloDAbGuLAnHT/h15n9mGw4gxncXx/H1j9MlOlZHik6Fojp2OCM7LCzun3nyM7u/YcPAzXVy1qZ20z9XWLFOHbxFQfM5DSCPaj" ..
	"kC/3kLu8JG9PwTMMYXbq4F1D5fq9SXvT8JZ2FlKg0yw8fDOgW3aSP5/XbC16dtmFzSqtH0KxDJwCuZ8FlfFABiQJLOwAMV+QgfwI" ..
	"Nlne32nL5+9WY/hyXpaELEfceI541FJyGvn+6eaElp7SDSHM3O6z0unDDVmjpw5JXDb7Q1nzm4UFIZXuo4hc8eQWU7h1AlrqqNdp" ..
	"vF5UeRCUr9vPcD+VVNYiAepwAvAF6uoUcTB/KOQD7IEZgQA9DCQlYdkbuEZhgcvtt+SnZKg1rQA8nEJL6LEAJ9namjSwHKyZigK2" ..
	"bD8dzHdI7WEAd9o+yk0V32+YQIuQpF645nHkGjw7aFFb3dywrfQ1zZlrpcZmpf38gpcLvoxFDLxI6Y7vynTJf6yqK35dKXm5V3zw" ..
	"XYiRP3s8Qwr1oUq6Jjqlcb7QhaCl9kjep5RdHySCARajVt/nKcHad0aSxDwQ7c0tjv4qg6qY0KXM8OS40gwXk2slHg54xxrffFV8" ..
	"BwkFwGXM9SHhd5rqFyZpZvKKpWV4QApFXwZ9FBYRxHRWSAYeUCS9liW35jYaS8n64xnFH4h4CwI0Dlc3Fr1sHGhKg2K2OylkBtTX" ..
	"qAtMjPO8OroOkSAqjbDgKiZ0FWd0GBk6+Be1QxtaUQOQ+xAQkPE+sZZtpVGncLw7O2xPfwhw8YDPp9iQ/243OzigiHCvtAUUhPKQ" ..
	"3de+NKlJNVuHaUIddB6Qn5rlUzYRv1rrTLcr1ATqT3wjBvOr7Z+Ej2BSDdhpnS2h6nhlLkr0sCYI1WWvLCn8hq6A8dSsTb/wpLjp" ..
	"9Cw0t33vYNu/cnI6A6c8fZHsSxgZFCLLbKE79Kw1p0QXO1i55Ii5X0FTsxIUXPa/HlLXldoOE0vhiomckMyzgwf4JlhgvPHWOWiY" ..
	"mPlFRKz4HPrFIvomdhA4GD1+r5HZvHVMLZ5LLm4jqJekkp7rnN9du4c+L4p3Ryl6Sqc3vA4ADDIAf2Sz541lQQzC6kERHsMOePiN" ..
	"EGRfPTQRGegGj8ihkSbe94DsKDq9nq+FGZoDqW4dZd9FJvNv8litnJx1NtsARm3IP/vFAc1fUaVpd6f5a9mY0N4Izt1Takn7P/FL" ..
	"fKt04I22S6hFDXD0j3IRTb2ucaGp0QAwBL9JMI3ebU9inOz0wEEEsJE0OojY/x2Cfw+lUpXwJN8uyGZTiXYQnLbOi4hxrUkl0s2u" ..
	"ecVo2qRGxwQ+UBxoRwu0frDe34tc8ldwlaZEq7hbQU2NYM0JVNYxgkLVt9kxp6wwkDd2hasLZO1H/LcJizHtFF9773eIS2jjwmdp" ..
	"zZLeKwdofrz2eAkzArYkYj+aqNbr2T1NMBaFQ4ULjExY9aVjpqlja+Uu48SgNKLvP2RGgJs2SUC8FL38mcHR21zN+P+nkI/I7dkP" ..
	"UF9/1xFLwZUnsTSsGs6TLZmPTxTkZ+pP9co1AYSL0PH/H7RGagt80RW1k7kP5JCyOCHoVfFwiMfTc23ynsYed718ceSskwYFALzF" ..
	"gTNdvNg7l4ZK3YXThBgSkMFjTxFa5GPhGqGt5GTc07AuGDSjM65QkuxLTbmXTES8NfuB5rX7tbRCTrzU/y/tMXG+RXdGLSkWowF8" ..
	"2yTx31tuTdZB3UlwrlyXWhxy3aj7s4M6rznoV5mnTgj6f5Zulz94njSQR1KSqvJwrg+cLMRh2WnysDPRiPm4b1cPkqhiymis3D3z" ..
	"i9HkAlmEkeBWDWqVWUxMfQ65g8Ya9PNWQI02HRs7jHBIIVN5yTzNkfgNSS+upZ+1aY4RB8TjrBZv9CgiD4ll5DJ2yNSemgG+391c" ..
	"PruB7ugcWxJUi6edzcT2VdaKCdF8GcCw8Sz6xE415pnqA9N5gz0wGQCnnHoPfE+pAVM1K/0e2MPac75uudufhElVZHpyoOIGzRYY" ..
	"FCFszSVQ9JgcUdLh7eGl7++mIyFavTlHWzqOgvhUqsh1LVVK8tt/dtyhtJDa5MPppt3m80nR8CkgQgdJwKOcr3bjkdt8sps+Jnpg" ..
	"jNpm6hVBLPS9CoDEHXBHI/Ps9D+cV07mhYhu8UjxjhdAM8kqz86j1thA/DNveQ0dOTJIPyedz6fjwCUfhIqZQqxi7y0BsagPmRg8" ..
	"xTxVK8KXtzXJMLW+yW5JPTyDcxBBJddICjSQa6rHoOMaJj3wMwPNkE3CYisHhOEcrCJQy5EFOK+QMN9CMw9JE8bZQCzFGrFgAGIy" ..
	"yiTHb79POES/vgqBI4pffHiO1ap7Y5MdEuN2T4NPnkymjuLSTl6dUEgA2YdZdjXibo0m5FZTYle4dSSkMpB0BY9WU6Og0h8a3F6v" ..
	"ErSJqROejERHYvcuGzjfNZtoKe4vNaN6fZubAdGKKKvHmXNbbB/9qRvRiXnqEQXw/QkjJd5TMipsldktL+VA5OpMfKIh7AUQ0W68" ..
	"YKNQ8SS06/Ctf68ZbUkwEG3Dpd5QPZHN0h+jBMvkLyUkMbcfEkEUhdZWzW2NTx3TUS30+OuJ2YtQ/3PHGHXxNtIP5l2gqYSZ4ZCt" ..
	"KGNVElAtIOFnjKWyjKHdiwfODk4YXABQqj69ocYoa1VCqUw92xKTM5UDEwp/f/NnHyPcsoZow0vTW+8nPtyZwOP4ORy7Km27gYH9" ..
	"JI8NC0+HJWuMAX2ZadK+oV1rzQs5ryNIdDjyOBSIIk9uCKFPrg/trAc87JIeO/PcDGJsSOejUHt/xlJYvsr8Z5SFVl5gWf50BiKv" ..
	"vtwKLmjKA8Ab3iusK2sOpFoEbEf7MksfVqE9VYYfMqcYFHdC/2vKlDGos5HGNeom5J3Z0i2zz6gerlRaJunydNSs4PoMObCeMYA9" ..
	"PZ4v0ZXcNlIKW1XKLHfDChM8r/lLl8nlbiWTJicTay09zeuAavn0h3r2+jgZIcxQ32kbEKU42+uIJGT5nyAzWhlcgh0nYMsQk5+3" ..
	"Qed42AKDluxm87C/HIGxNFwpZ0gyokrzOlLFBrSfgE8wcuoxJcYumZVzIJRfQKc4nS8WnzMUw/+D5SN0UFFlm11S3rquPpXb/nT8" ..
	"1KEQgXTXc//0jRvTLy3MoOml0UHZ2c/70AG7BotgwWBPcVGvx2xAyMI+GCFy/ZpHvY/9dtsrmVAjNf9C4qqsxjOWirgeExhLqdP5" ..
	"3xjuEJvSuo5n1aqPpzMXhE9i2GmjTC2EYhfHlo1lViAUiHGiFNjHQHuRunf91bXt18hhWl6LRlpFbY3OZ7Wen3f/44TU63GBzxMy" ..
	"rSgAOW00sSMkkopxe1CKfqRGDmL4kmlydutkTnVT0oYnWYHenrIz4SA4nh+Fxb3PEoBt68l2yd6rX+NGsZY20bxoYcjNK6uBOLQq" ..
	"1b81G6jqqDJBh5LJtx6L5hr+9IFaV3aQcsHXtFNycXv6nRxdEMX+HpGeNnYNQPDtS3HejXUKnZ3rYsblQ1ARtrCyMKqAOdbiIaPA" ..
	"IKKj3jexuPfUo0+9zLH/7bdbdlRbgD8FT6ZJWFriJmmQ1+D+RD5JkgpO9Epx/WPv4D5K/vRE+iIfGpSNavf9Dft0EBg5ey3EOuDv" ..
	"4zhUAqdNRWUcX9TWI3qVlhgGCxLMpj36o1H38ynr5M7SWxkgpUicbaacWvy1KCykrjz/7Dj7znNZFcFAkdrsxchoDNuiD4fh3a9R" ..
	"6DdW0LRMUD5KwBR+P/ypRhd4ERo4LdfhbIG8stnA8kO5kRlf0ak1bXXryxBsnUexNfbi4g/7RiHAp96dCUjN2vY8k8Bb/E83nAgc" ..
	"GQk9/nMM/tz7CHBEqfvASlN8EC4DmvVpfrFJonyexvcVep6KoC/wl7YaII0lnEOunf1zmwy5s1FK6JVgcrj3c7rO3C9V8pLBeTPf" ..
	"N/porW6QczibCh+uZ+5wk9k7bAX0J/RlJ7AHjckQN86kbygDCylOGRjF55FGa5PVspfZnMm6wnGDffNL5+rAlkSOOlmYb/ZgMpXH" ..
	"wZFFVJdsxrGe4lv6FAVTlzzEkKyuCVUADcLf0gcZRHT/c293fBMAwO7TkXkZTmneN4b/IsRYcUKhgR759YlKzh0aaUD4lYaAAP/I" ..
	"Tbcz4WEApImBz1GDGyR3wD61ehnd1Elyd4w+ezm4ay5X4PPiQtSW3zibX5qMGPYnyrPYPzj4Pm5Of5L8bO7KnW391BsJa8iao0Oz" ..
	"uGFJ7KWr+921eZQ9xM5rZTHmZ9B5s0KlepkfaEX4cDoTmir24k6PRO5vZaxc7E/NCflgGzf/0O9tacV0KgB08V4yL5v5fIhw4cqI" ..
	"YsaSuScb6N70xOsSb4oMrgFBDl42AIKYFfmvaQZvBuyxkwcj0n/MnZVa+FM3pVspvQ+FA1WaM7zBU1mR4smTsmgmEn2hUOreiZEk" ..
	"SmWkQKgJNFL1okdWiwZPEKzF/S3Gr3x8sDT9wV6CWIuPTAXvYYUYutxTtAB2stiJFFuD6LxZn/5Va6iTj6yVaCiZqdc49PEmXgg4" ..
	"v1ArKTZUMDoGwnpB3nxEhTdzLcgdVS4VhOzbTs4JmPQ5KKPKsjJtuKgPHFabEGN3H5zHZ6KEuyJZVM8TWclSixQ7aCmtGaZhomdV" ..
	"6zIKMzpf/vgxfTZCF3zzbL6DsnrPCsdfFJGlYEosDTtwvPkRavcyhjpYfNYWrtbkVDebuvEmf2yAdzPdsPSFvRU7O9IaOyzY1Rv3" ..
	"HImT5d7vwgC+mUgc/2uhTItemu0kwbZDJZEha24XKV5LHv4nrByoJ8fabtnc86SS/vc5ooeZzLDI6eiNuOu10BsvNEZB0A3XfdCl" ..
	"zrWlVpJX5WiVLTNQ5Bi+bm2fk4yqDwRsFOeyQAfTC57PEfJkbavIQRGqGfNkShDORN8gkZR1E3e7beAA3NrpsI60+i9XHLnReOp6" ..
	"sX6gj404JPJr9Sy41Td4+LxJf8Dd/RP21AJINZPJsIoCMaOuoJZ9hqDr4QLby6ZhnFXGvmQtCcTVcWvksgQZc1erj0GE1wV1t2ZI" ..
	"6RFFwSDGeWLEyoiIP5E92o4W96o3NAs8TvUzz31c4kP9x3PNjG7FMciEXXGjLM8WUmGYeXOV3tWWFH8y+YEJpG4PSjoFPfQ+Iiso" ..
	"vOvoo8Ns5up+cloH5dbwtDgxMt6OpgPJucA2/SjjBAG/QZFGm1iUHoD30xfNpk7BoJ3BATGtISIqFBpqQcivt+vc89vBYULr2tnY" ..
	"xzwyesXgEGe5I1+5Eyw2HwrotgZ9Sf8+9kncp2E6XpLRV04qK7bDRsZHuOutL0dCuHhviW0oNoaGzsh5fUuYx9iNltz65XwsdgfY" ..
	"WV8VYobiDk4pdwZZIjs7AqfIrFW0ZAR8nFKocuS5dj3wuJsI2hHVBwaieASQGHw7Tj03lHa36pfLaRUmZfa0tdAOhF49PL6SnOTY" ..
	"KEcDh2Vr0hSwc6NR0hcGb5x9H1Hp1mVra3O8bIDWuVzicBpuLUbmbksW9Rwo+2M6Ns5jHw5cYWFWPs13IP+hAO2ivetBw1Y82ceN" ..
	"jprd72aBYlIqsvugK8Hlw5ToEiV5uQKqlwMLi7KkjEoxr0Bx98jiSWikcRnK7Jn61kDsYPBeGRfsg+3c0FBiiGKE18fYrnZ4xU7i" ..
	"t/hnhWt+C02cdCqnPE/+LCfttaTPeImafP8wnltBlmfRM7tp3QKkORqWRDbZl1CGhswuNR6tHTh9cua+plKG7Jq1KNByTXcIDvdo" ..
	""
local PAYLOAD_P5 =
	"ZMEI+HiqCaODRgGmCNwc+eSG5ZTS3zC1EDPp5He6KvJkgIsB4TfOudAfuX54GpfKdwCVGh5+XL0Cw/fGzm8PkNbA+ns+pEwa2Dfs" ..
	"SYbLrdtyTkv3lATlIl69ofRNtWxQBoLEIH2bfvhBoSZAFBUb+c1vQd99yhhVSke9ykkfhAOodrzdCas7M0dI/ql2bAG5VxNb5PuR" ..
	"NaRAgeq7JBvVh5d28H17U/ZslKZt0y+6oLMcd2RSby9HOn56rNYbhiZHMKyOLo8wD0JFwqKXUevk7kfKcfE4r0TRbRy37X6Xzt6d" ..
	"2dUtgminzDQZhxikFo5+mzZrhAFOESZMTGDFaLklYja4jyw60dWbzPYGNmNhwNbLQWLV3A3riccXovQ14sQluHFl9KeD+N6Hzcem" ..
	"YuWhMyvBXQMMZxXcSRFWIytk6bz8FjksZiVVbwG45YDlA4WGxXHRTZmlK2nEu59/TJqA/Y5z0Xc4v5+sKTpLYVuXpRtNyclUGq5v" ..
	"pV3DvJDwsdMoXSI4FMbDNa9f+nE8e+8jvzyM6uHCeRxZo6bKWKUEgvp158Qk4vPRxQbyv2Xdoyrc+MTO8pnpQsB1qngP6jneVoAH" ..
	"NbMwpyQT5pPmAK3DJ90x8iaSKDfLWhX+wT1SvObD06vanPY2nNluuAnjnHlm++xIIJuvb2BtlD//UwDUs01sFrC92cJQBn8t0dsr" ..
	"3SeoGM0YHQ8TPln3RvYxzOTG4yIFgKMKXZMuCw08wFOajBEhdezJj6LKuu7Y+x/9QwdFDo+rr2PG+cxs/QKgNHTe0ilXj0cSmird" ..
	"T6MLEipe9/5OkQyrO8nruc3s0xyWrJOSBN9GJDlAMtFWFMu2OF1Kcvc2vOWSAx5UYpA66U0rnYzNpHh2Y1jjIy+hpghceQjZ5pyW" ..
	"VsyX4zXrktIBdKz2xiIBwfEA+ZM/36rOsX81+/dLsoilldDzgjTihBjJFfA28rqrV8P5zNxl6bA7Eq/c95BUiZrN9otyxDFtC1vH" ..
	"LdPRFVIIAUeOaM/LEX2B856Fg+wLr/V3UVi1obYQ7JBKHzM4t7A6APxvrQlPEad3dMBoutMntaVjepoxjS9GnD1HH0Lv0LG0wcF/" ..
	"iHdYwY0+9CSgz5jOUCzzBi0kgc7mMBjm8KuKolcJF5PeDq9ywFWsM21VeGev0DA0Vvgs2xzpMwlbs2Jyo8yoX6pyYdegUUcyAoev" ..
	"A5KZaGsFMrdH8ysfnugCh/rVE/nDSqgF4zoIcYIwfE68hVRrXStVaalxakuDJ1YGyi70fjHEuoGkeq2N5A4ayL8CFyq1fUPU/7Yp" ..
	"qixQnyWHFeYauc9GYfXGHBoqyaOn7n+ePzsNJQV6v11x3QoC5CO9PCTT+fymOKRORWnt2aJ65Rq1DN1I+OJkIXlPzJooeLX1jTZR" ..
	"ko4sIQyLttQbQPZZRtRbNZXVSj0HxqNKOkaZzAZwF0Z5wFaFDi/1MD/zPkEp8BY08P61H3/e9nCs3V00aMDJerfyaLqSXpKThXx4" ..
	"XUr8NEcaA30lUwE7PIskHMxehnEwH3qRqoAcjsyIiaM9YlCddQXJUpZdjlPyT49/Gsz3MbmHCWNYy9cbSvpvQiZ0paUQ5iUYmapM" ..
	"2wRi8oueSkHliUmHr0lO0T6uIQZSZoEtn0fQSF9Kv9s/KQszxcYu00PZ8+dY1MIvnul0rFTTIQy7Ycp7mlmL7szY1zMFcsTkSZHT" ..
	"zBxueGfBcvYwiQ1tvAKUQEi/ZUQitGvRcGohb3OcXUSkMbq/Ada/IU3bnYhbAEDhiKB8/R3+TggyxN51n8FOesiBVj8qnq7T49kE" ..
	"15BBMc0c1rxv79VhXSuvlR6/pO/GPyv1YIru595H/q79g370Czvz94Mr40PrsUnFmMWLg3jM0BSp4J3ZBc7Dq4C8Q7d2zTK96eO4" ..
	"x0dRnER+CzUB6gdAro/v6tw8AkHSJ09b/lM9TOZcgsyr7Wm3UY/x1cG8juTw5Fi3aCnKJuKVJVP/7guS+94rFB2ohBfkPUUPrhYU" ..
	"BRDQUszb3P7FqAc2Hc0cvXrj1qA3ltMvpLfCMOiujSvYIbyoBVagR5TFQVu0jRP43/hksj/iDjg54JfawSJjSDfmQOlvKwhle67U" ..
	"YMfoiWRuwLR/+oi7nfPVHsnemiLfGGW1G3wLi9c8zMgydVf9YVmM5/xXEUGsuE0tHaqJVMcVaBOf4Tn14LBzCBamoicZkk1OFMLs" ..
	"yLjsoxts+auvj/z/Ysin7spkMY+urvX8IRP2ipM1M68CqcBkefrma4VyD8XaR7oofW5GwmQqQQ8+SPx27UlW/rZUVKKW1qk3AwaT" ..
	"6Xs2pagm17+oOB1Xobg6aGja7vAFwEM/mCI1UC+h+i4uW0pbUUoYXNQVRfz2jJlIrYVkUhXMG2LOzMxDtCSJzd52yjQz3LzTHG4q" ..
	"DBFPqb0G/JAz5nEq0QOAJiEItu0q00craI3d+hDu7pxOHW2o/kgnw4NRN+k7dl+TzjOym5fw49OM+skxq1nae/0iS8kTELc2PMQ/" ..
	"1I26wnDRwYRp+YZRUa+lM5V5KGhBJHfHF8aDlFsFbh4DMbqldJmaY9ojbh1ZrVNvm2xpxyEmTxYlNxefeYzgkHNdKvUzaBfb6tQg" ..
	"tGmYlbwBJ8Wg63TDSLgf4tMFOTSEAzLhePfHsGTYRCQNXS0qGIUnLA0TXMuySrIKnrUHPyS6J9UeGQgluk6rUZJj5y0FDL/8QMiO" ..
	"ijRC8xX1leEPb2GuKwLtbRvvG7EaFMqlFXFMEbacUsXIm5RGx2wHsw+9XEtt5WXYyjp6MFffbx8ROy0TysKlykTbtSn2TVuQTNkD" ..
	"pjsEg/TgdWawLnsY6Z+HO4N+h6NTYVGrCXFGgkm5UzFsLTSwchEF8FjeqHIW9gJ/NX/IxbvF4B9VkNFfddRQK6+0Sj+R1Dd5KRgk" ..
	"zh3uMdLjcNDcSyw6FpPf0cO51yC4UdL1cQgAmKaFi1BQcNfw0q4gdR/3vqBRGes9sWfxKgwirzh1JSNUzyoeZ4hXNiYPIzrP05PN" ..
	"thbgxOZeiceH3z2xkakE5bHojC6mOb+enst9YJKvsYDTFncTKfuBoZyjR6Iredc9IE+qN8A5fOlRs8ViRr/LW/KC+cMlHBcaIZLD" ..
	"6U3w/AVpque7bcIoT3vF8UYDpJ6QmpK8+UWj7PdupslV0O1NOJi2V5bKvV6e5Dj4czppsPKWRS0oAFmpcYvhQxB043xtpi3ekfzz" ..
	"rYqnrZW2AaT4pJ0Os7At/3wSrm5ztWMY7KpPrmz6jI+IS7ou75gtJwqEh9F/XFBTSIpaDUsmble6480nuYqe9IContdanMRH72Pg" ..
	"0jlU55yEVSjqyZp+zSz6h8NS/CLthP46BadtOvC68/vBnv6XGojmhk9Z6plI+IFbrmC/huVf6wTJYZnwPKkaa0IEF4t5McuitIkS" ..
	"O0gaVb7tzhE2BFMuW0M9pV3QfVv+er296yrY0DlaOYwxyi+0ZnLWIve/lFVOd5MbWE/fvQsDm/OTEYaLTBZBlPyWF0JwBvdSDjjX" ..
	"zypexq7TsGiAWZ1DmYAog0Vgdlrl2AxLa5t6bToCL4vSI/Ix6a0txUOL2gIRQB+M3cg9i7iiXm22jPTjY9ptVdbMeeE8Cur+pVHy" ..
	"EX525+Rnm7JEovH2+aqXXLNFtAnlZiNoeawWYkN0cDvSw9O2smpzYWBPwAx4YhDTKX24AsPfeGc9les3hfyuUOJKjQrFi9E9Twaa" ..
	"6nh9jfadFaFfJLeYMAvI4tdp6b5MOSPc3zRWS3ECZ2e2E29DLx6UrWxAfXcOJe65nL7Lwh1f6figAKmaeiRSsrBWwrqCGFIsFUCr" ..
	"YIdqdUkMKTX57nYlcIZablVoJcqv5pTwZFecxY8UHch4uCnxl6qYNiO2FGC19FN0Wqc6fnsPDLPm/89nOkErIqGjUDGa4E53ZC8s" ..
	"fiWHy2I1Zsd2e4Yy6evXUAKlEegRe7lWO5j4EK1I7hmsdSEBoY2nFDqlmSEcdbHhvxRNJ1a6ZchwoeQuSQVgxnd5gbv/sHAOTh4a" ..
	"wrx5+4mGzMBPRdw9D04XbO3nT1JdkCHy0oiUcS1BArkUgW7LDbN9cQOrjFo7T3Y/ZnxHrlBhKUdY4PmxCKql4R613C6cLMeAcu/S" ..
	"gHNTGKQZw7eCVaMtq4oPV3rtf65jhqoMBYlLw3772aakivxajq7MLzTL0Hll56q6SPw/n8OofykBb+AuyI9GibBbpzTc/IFN//e1" ..
	"oMhv5UZ7HFLacxAfoPivh7xAz4WEj2yUd0sN4BuQ7RC+hSw1ojNKJ/w48VJeOm3mcrGOeZwsjYCFae7O3VeoFKIt1FoG1l/fkCjU" ..
	"J/1eybEnFGTvVJ46TORLVogy84xjmIZskk867wpalyy7oqnwXKnadfcQMFBnB3WEm+ZeTspHuHsBUQ5lmc4y8uDgB1Pwt5vqmPVY" ..
	"BSavM4ZGM2/196UnfoNqiettwpFu+FATXZSkhRcx4+XDX6Cv5JKvREF0tMmQmTyzaA7uEcXK9nRa+OU3MQRHpmBMmnCnK8fgs7Kl" ..
	"uqtJoGf5py8Djs5EWXu7EVAsB6chee/eiXRE2wZhdUDQOa2+6k4MiHgrG8498uDxcKAsDodIBrIl4BKsZOmBMda1kApI0Z1qebAK" ..
	"iYNzzEDfXs3NGx21Jl/W0gesmbOUZoy0eHiSUd/ygzCFh4ZRuIClerZ1KLeu/q2KY6JHXSsOo7iCLe2AnaIqKXnLT3qb0uS+xgz1" ..
	"pCiChFG36of+CCPke97tLfxN4HDJln9hyYqon2+Eg8GXTf18nqefAwdunTVXAUzx9/jennx1Q8lmUYTUYFS4Skr+7c6iU+aPYhun" ..
	"2I6bpo2B9Nh9ptQXmS1B1zbqPed+7Qki4GhCNqRzyszjVkaxWALafDaCD//d+RlUh/8+3IXILt6hSB928RwpKotaux6wlm245jNJ" ..
	"2O+Enex2OJvp5WJqEq+nr+HA7YrSG5euV3RbodmyOSczchDRApVMYji322ysm2CIIlYErfVMkFtgw+pPknY+cmuej93HJemYH3I5" ..
	"S4p84q1bocl+NlpiUS2s5cnrpVKB21ltMo+HZcXNAdT8y16aMhprAm6+/GSuYz08g7drkcRVO7YwC5imdLN2n5rcljm7R+/0vrRv" ..
	"QuhGy7S+KATgAQP40rEa8h0wd2mEGUICo6sRC42rtQQl5e9kc/zoMF+/qE9F9MxArZp1PjEGMore3bB/Xcl55kqtaijaFMTGXLU+" ..
	"mBSg8UmlbrnBky3r7qxjrCR2HWruRbwcEuh2qyh/0SljWvbNgdzBtHlJpQDg1Mjxvow6AhvhsH8VtYoQI8l42t9xjs5i71yTT9Kf" ..
	"PmGxd2iPgCR+gfky8xgZ2C9HRj490qh7FA0JVJ2jgBA9Vdh5/2NG4IDvPNg+aotkYjUaCCLI2mwQ2RmLNa5MXwVJBrJPZtZILKc/" ..
	"LhaRbHTMYOfJvhgi24ga1Ssz11HxlTYTUKeEyRz5cZrD7l/RCC+ObOcLfyPGqS1febkWFQPNDr92q0l5I5HETS4rMPVJbrvIn+KX" ..
	"XQY+gHD3DuQnDn0gcvHRLxekTClqKBondXT5vssLdtVM7OFwvdpnv8T2xXkWf+3x63r7/SNDHaT/g+4Uul8/+eSUC1NcKgkEZL7a" ..
	"Ot/19r6R4v+vKwIeWaqW2jb3bZj6+DzgtQeWhDGtknvdLfYWENgrAJ+JmRh4IzHRoz90UJ9xAKRXy+KB+7zkNWZElOrF2XTO2kSp" ..
	"DXMFXFfLOq2qCY0DiKyE5HWAKk223j9//TwAy8W7hbOLwHC8Di5rKw476dMj6ylGITnaW+6PfQkONXU6IRWPLH/9siMlFBhUAWNh" ..
	"/VhRhlvs3QxbbHnPt8qpfvymDOKyH9dKSDFwcz6jnoh1NQrIkT3wtxUfi1hFtoElbbAPH9kUZRWwqraf4nryowedwBPDsWRZ5swA" ..
	"32IGgVMuVZtUakClHVPghs/Ba9iMqyrnhgZikNGTEu28SNd8Nmw5MkVxk769BllsnOmAofLqXgJD8/YnPzvzC3hd7NTX1o9Dk6Xm" ..
	""
local PAYLOAD_P6 =
	"erWf2s/6qvm8bkKAI2qdTGMCGooc/1l0A/nRUEzhb4pKM4c3FQRVaJYic8UfwVaPvPZtTn5x6NVPXfncf7ZJlwPdhJ/NEyGStOFP" ..
	"gpAqGhHF9aXQ+xfTLfJkM0sj/9/p1oJlAdi/ix5bhkyJzFeVcptRwoW9cAv+pwnrIln4dIieqNJ01hx2gVwltjqSzQgWjQIPopCh" ..
	"c4wwS0ZDeqZA6h3wEEpZziwlZx/D2b4z78N/1DncnEAaABTae/lYQmV99LpV8sM3wTcHDhTSa1eYrFmrFtn0Yjzp18n9qDgnVXP5" ..
	"JeHKyGIcUFbtbmmBXGQoAODfcv5ZNyKQ7oRcGCdNq8EKp7MSLefBtn7hR8fJjyw4vCuw38IM5Felo0yhlt6v4ffVbwNQ81kum/7m" ..
	"Uh7KFJKes04a6MfEMRrf+OKnNcOiPt8rsoTKEwOWZM2NRvbMf+pvy2zQwht45aYvlMzu1CwEGof2pD6D93QWSkiMtDaufHi9BFno" ..
	"8sgFr2LaWhevfFfrEU6Sq6VoRvTaX3bEEf4PZWuf8o2cijLk1LA+eK93FaHJxDXnXxXvXtV+zNnHe9iqajxiagGJsfZz1JbR41oz" ..
	"/IyfwoXJLkldWO69KsvkVZL0s4mlZ3p/kYRItsm0LS53dSO1xpA2Gx6GPlzYBf0jwEBD4t1sSTXz1yofI+wSqDzA2p9jSGi1wqtr" ..
	"f2llysp/iSN0iWZFsHpl2j8tiP+/2UnS8IY7IEYURfmI/k1Ako1Kyg/NK2NPYskK8frsc24L+j09K7beJF6mJd/w9HaLDkzova7v" ..
	"KABybNt74gXWvet5V+c0vRgGJHt76fNnkdgpzh3IBPAWEJM3h+c/S7vRBMkIq68nElY59MXmkqko5Ii0rPTOicAXStb+xmO/+4uF" ..
	"4o4MUmeE+VHuWJYOoFmru3weO7wegJjSPAkhSGVEYclKtDxRgJi86aLpK4TsVyXl15yCH56/Irm7dkWLiNdq6iuGHjZz235evFdf" ..
	"fYemXdz391fluBUs4Fb9zYsvkwMLOIQEcg0+wLGu39SdqlcRv4kvA3e4ZKdStxkZ5kQ9bPsmmuyB0Dcj+ssMzsd4pIlHukNnjaln" ..
	"8+UbLMH+YQy7zqvLWQFgsHdzcEgyTgRmVv87+R3LiALsjzXz97fZBHGG1rbmUWiMBqrtn93giUGGaUzPuUWStoQvVKnCFZX1cfvj" ..
	"tMCkxpr7AWW72K1SOP3icOmcrkYrZb7IOJ5oRmn1YVyjwVI5i6hzHqwxZGoeCNtaZsq29+BkAa6qm+rWy10Lij5Jg6UcDk30Xnls" ..
	"Qmy4kOVCc+Ct6Jv9xeIux3H1apsAAr416oyuUomXwElV4nJdvm6m95GjzJCrD/dk5Bj0Z32cF8i00BmH95piOM1soHyc6O6+q52e" ..
	"1UMueyLobTNypSQL81YhDdAVBeRxUjcKlbl0QJDpCmOjJF+wvQHNAMhKbC2dthblbQOnURMrr/Q+dDMs8HLdqBu8sqzeHzfIMp/q" ..
	"yPbgBAyI8MqmTRpF9Tqkj5TrYKMDRi5qGJ7T5sFQvvhRlbFdPtVWGqv5kic81IRvqqXbuaO/N1za/6mEanNmZoik2CG3pxO2ENAc" ..
	"sEgdwB17TA+HRvOWFpTF06I4LIPj3a/eRhdDhZvL/wNhzTHVEg69CoITlPWFz9sCyp1+gfzKu9/eUxWbpg0Hzw7KrAzw1uW5twnZ" ..
	"sPk/jaaCmsi/Y8WAx8sbu3nLAANo5pjm4m5z+NmjVY24czOHlcWVuYMWXyl5Mk7mrGxIGDu32jSIqWBRKYFdWkzfEEiwAbhQeLkd" ..
	"a5E2DzK/FxEs/i6kEJ4iWuWGSOgYiSnRjoHcisfvtc8bUDboEKYzBO87sltwd/bwT2IQhJRx3Jfsr6RT6mybFm7U5fUGv0HxtBR9" ..
	"wOlGmBzhw5depxIYgxfibgeEwnnvbZTLYcMShKFTO8uRuTs9NSS0j2ZPwVQZK9L4O6PzYi/dUMQT09xfVSMpKK138BGuAwMxwmpT" ..
	"XUYJDOHbPvAT9JFbhnvPccmgxF4qi9BkXdmzFI8KedXMTmAecut8zm0k0TslOi9Hh81oX/uGVZoQBwxD/naKp0OY/jzjqb8ridHm" ..
	"qFXGfYWRsVvxb6tz+rNpg+Thzou4ZSsaja4Igq6Nqe24NmHD16bybiiQZSDkliHsrbY8b0AnrzxSaBjMNdGeqp+WnIuWLkt2SLGd" ..
	"zOUhDVdXd6KjBk8zJRqcqifUorH1A02sNZ92o+pwdYD3LNtCBMKWUf68+D1kFv/0ZtXi7HXzU7OSY63o8qcpy++aaQhNA9T7Z53V" ..
	"fmxdmV5iOtSz3wzTIG9aJPinL8aqk4PXNGgN7FNeyjGPNN3ZWqse3usFKdVNdMSiMTrA5gFx+smMpxq+3qzas8zGJYtIZfpFA3hN" ..
	"hd9QVpUxkdOnrjNIXnEFhFg4ajSE2OYCuV109uJ0hjgsKn7YfJVeSj5ESPmKtR0Im2tVeqldepfsGAYW/MOKg60j9iw998kgkAuS" ..
	"let5gpH1ONXzLPRgZTBCnQB2vdpYmZGWkBffvavm82ly3mTvT8cvBHHZMBA5ykSsMmIOEpuM6lx+VCepHvY9O0avPctv6KTvd0np" ..
	"cSpwS5zHiqymolZiLb3ckFqap+DzOIv6n2cileKIBkTFoKS66TORLwsk1UssWPn7vF1WDrVtijdD9csP+WO8FU6uOfcsXWIsRYLi" ..
	"XaSKxIT/OG+wFGMZg9A+fzydhbPFTzJSIvpNfzAqDAOQa7d5dEjji61QAfDt6FEMwtKr9zmf0ixvR9WD8xntRKHyrbQTrLsaea6b" ..
	"SFa52xw/gK9GX/haLSkD2pc4n7cnMdqHdbJnyZ8A0dmkMhO6D1e3Xs9XCceEo851oRFytBaaU4Ye0qV1sBhy0Uct0tHh3naQmI/B" ..
	"0ZPEAmJlKJNEieX4rz/w7fRBTLBCcyu5ElLOkfB7YDrAePCU3Miz//MfwRpA4SuAiyPSGKiNByR7iw5d2KtNVTKF+n8jtsYqRSGd" ..
	"HSkHwqbisHhK6tLQUIZXE/QUCMihFbg9mgn/fpsLXnlvoI7wN4xFBYIJjDsaB4JDdU9jDzea0I/VWCmKlC1N/wIvjvO1rHbLek+S" ..
	"CvH6Ts8YenmqEUnpDKwTeTl021R2KJrjGWxOyAITxVKu8fv1j506wBBaWJ3F9JlWn24ThUbZ8fk4OBPSfeSy3E9QqIgRERdE90Fx" ..
	"MHmBT9cEczKPe6Oisx0yfM2m3gQSyjEdEtrHYKMh/n7qciEzg6IEnNd93Mh0pGsAt97yK0lasLmoGKUpon6zAsHVK53IDNOgZHu0" ..
	"EYd+nSZQ4T6ZbCCD3KpOo8tYiljX7cIEB1gUdMSU5D2YjF4mWKvZ5BKiR0HIY/M4iakDhwaL9yBJrCSy/GRDjbh0u5QPi5SIGLVJ" ..
	"6tiQe1fe0TXHRBClFTHsG+aqCA4MjCY3yEvUSfPy7aGFi1TvbYgqrxO0FBfVg73gRRRZJx7KkIKGtGVE9cbnMMeEz7wSNBjXNMGJ" ..
	"p3fmV4ksRoXW6Ah5IHBoI9MKrUcuLvUqJk/gjdshiYciC3rehkFcSZYFcwGxo/tzU5ch2Y7LNIXZHLaSiV7V7mQnvom0EQCwg1Pd" ..
	"eP9D/7gyXqYlFw31Twtq+pnIP8FtNdTAyhr0qSPppgGkz/Vw8gxmZGc0eS3+uxyegUObgxtuNPgTRz7ZyNudrEfrZ+pIxi/TmCxn" ..
	"Su//qXz9ozFU+j1hcscL3U9Iqjkgnt8EO3IFLWwp3x3v3UERnN9IG5m51dzgf/TPLtUKpoiqC+LnqJif5Itkgwvw/bdJ54o8HH8c" ..
	"I+pyim4DfY7ZiezeUdccUIioQ+wa51Dr794ZF/sHvUcvY32usNAsjlE44soV0KXSw294NJ0GcmgmR6YHUalJo5GJgEq7t4Av5KUK" ..
	"BPaa5VBaqY1oMj2xqtEXs2TPLMHqIq3AtC1/rqbhpQP8LNqvqFDUeEeuD52DOIE51Jwvhzof28taS3FcaXcLKFKo4U10oYlEcjpG" ..
	"X1MjU3fs2LL2oPtiyUahTDQFQDgjT06P4+O6+4D6HNjDT0kaQSbAazCOuy0bYSavKeUH/Q1jd05VlEp0CS/84wHfbDudNtDhMPKu" ..
	"EL9EIlOyC0ACuXyRP7bVOQ9yndH7+zGgu9N+mJyCe5NSmc5RjUUkLiyk9HAUrzhYpCnICznImhfbknPDlIU8HYhKPM1Bu15+mX2k" ..
	"Y7m3F7zX9D8HSs6rEjHMTmyQFq6wMePchcWLRmu7jw66k4HjmD9AN+3eaDuYNT8Lh4XoLOHBWX6Qa3jpyGANnTisWkYxG/aiYp7o" ..
	"RjpiKY7S/nldUyLZkCqGNWP9bXTFXXB/NjPjOp6Ua5VvlJSMg64SCZXpjIGnYAO0CcgwX3uWDOCEebQxzC4FRGNMTpCE8y0vmDfQ" ..
	"E86iq+yefxIbMLHYmBeH/pfVm5jQ3eiTsJJn0FUsAlGpj3VwLq2c75dK7A5dh1wMB134jNmzlUlx0tiCYM93zxjRoHCy1rcZ3bOy" ..
	"yICoAz35Bnp9DBE4oQ13qcznCf2ECkkZA6M7CfQm8M+GAJtpWe1I0NM+/Ow+0umzZr8ugr7p1o2Zz9yKpca+1ys6EgsQUkKPC1S5" ..
	"lmi0Qu47DPxMNq41FiUOFmueUefYid0YdXCXbTLeQ0eTSj0Dil2uSmk1wOkNwvEWdYGKo0RlCoBEfrt7lx+CiRaPe4Uy7IWDhoK1" ..
	"WtceSsrwzTDVn+fI2uWLZBl6Efq9oYYP3ZHSIELK2+pyT0BKcf2odnC51v5N9HYRin6uVgjkYR+5pH8Do4E2zhwYkhkhY2lznKq7" ..
	"2Uc8djFVEHZ2DH5umjp20FtKOE1SiLQLSyj9TaGq3Kis5WnFGBZnJEnqX14yBk3n3US+CDAvc8WLl6lN8qpzggIeLdUlFNOy2XJr" ..
	"8C1koUkKoIOBTlXaykFUt7ZbxBQQyRtk0k4bSnMaurWnpTDUuiKUaN0qDH3xcEU5cOqdPdEeqEyQ2RjBzrfitKBIWOCFHT+a8DG9" ..
	"XvlFHFdV37qkovWv3otyARS47sYOf8vQhnKZrNlTbAekWmTowElE6sinq7GyCh56237RqP/mBqomvL8QNfIM8jzb06CQTw3vosAt" ..
	"A58Lh2GwDo2OOFmqq2XjN32PNgYDfg9vJCbTvs9aKmgYI6ikLHjBHUKhGVXYyQ4KLti7uNE4dokPraxVYPLq/mOJ+ZCimj/gm3yU" ..
	"gcM4mXt3HTpVeGvTr1jALPTv9WJN2mHFCKp4bbwaX9LVWZ0LWWtsMPSdWlXnKx2GPMUVF4bgQJpRjI6cSOuJEWCHJXzxGS4p0fhb" ..
	"VfaAASIQCuVwkhWd59tnwCvT658L4HU55BX5nIcDElpEAqM5yXRRqACdZW3s1xD5KC378QK3HmC1dYBxda24m8PaocNNosOGTKv1" ..
	"9q3HGNEG0FRKKM1aDRjqdhXF2hYePt5Aw0H9loAxJADkcNMGuVw90gzEKWdl4lH7Vg9yZ1gNoi0+7RvG+lnLs+XMHdpYJxKjvGY0" ..
	"Xpkk6Tj6C9m697ObtzUukMLwmCyZMg2c/NA2SbhEYXHv7zFm2F8an4xLyRBFyrTIUH8YK8eVboC0WP4ox30sSypc5Znt+kJXiybE" ..
	"mJckxOm3wWT3GxHt50c09g6H4z09S59g/c7FREE7orzPS3Bp/0EVK+G9RqQyKSL27uZA3d8YQlEtBlJuckMqI2taA4pY3halGD9D" ..
	"wSyQcjueyOvNbE/wSuSMmAiVnXIP2rTkmlTuvH4J7gyr9Y4cLpPu2PbD0ILXtPu7l+zv5nQM0a91f/eLh/y9iovFJWUzuse50jDy" ..
	"p0AxeehxiBk012wyNAn6hiJYlC73xLg5bmy04df7+id30tCUOygF/0suS5PqdILZ0sSrEDLeWYD91kZP2LuYU4oqQf6K7SY8ftxc" ..
	"GpR+HCbw8m1PYqLxWran6ul338ljywqiwQwvqJSnL74nO0Aiw+CKyj88MWH1vLXSSvggccZWQgN9WzeozLsnWlVSxrtmMDjg2vCL" ..
	""
local PAYLOAD_P7 =
	"k0JG1uUJJP0o5ycYwzNvldpDnzSyEb29wXk1OyDmBr/6OCijCv6MTpZ/6Xk1wtg8wdVW5WIaFqIJLbQC6j0UF66R+B+8PQ7SdQ/4" ..
	"yfWoM0dTgpRZ4zesTvwnm7n4AjYs+zH7Id3x0eEhDGhJIpBCPVSMeXwpQ9QpIM37n2HIFkvrVNv8szbJvTWMgllpM3ak0cNZ6u+a" ..
	"Wtnx/tLNPMo47F6w2DQsLrr9K0aCszMQZEsYUVDwt8zYRrm2rnnDOge4o+SGu88Jg8R9t2DShNfj3Z3KP98KAKAmoMeHYgneXNZv" ..
	"5cRrzEwYgB9Pugh5mfK8X93qxV0Cx6olO2d43olLb20vM/0bPm/5NpsQlJq14vGMOSPJllt4Q1tTV8NX0IDILulJGNUXUl3UAmQm" ..
	"sknm+dXAsX4p4yprWY4L8SQHKd6SiX89ODqobOeRc0POKzlk8b4TX9G3lYA+AG4U0wmxFiGWrrl1gMljAC31LqfIBfSP9pAaG0yZ" ..
	"MotkZHb3YAKHajwmDs2JFoTzFYeFqFAXxsw/08PBT8HSxFJC8wXEovxXmC7myIAWZyEvfuRv00Tc2JRFPKRGQzGARxDNQ+2dlUX1" ..
	"85PPGH4Q+9AnkzkS6jTVgj5uH+vK4J9FRUwKhZtSszK3KGZWzu2vqxZ7XOlo9z33Hzt3RDQ5vJSXwedGWmYYnJOaS2hEMi/mMIn1" ..
	"+KIN5b1Lh/TFWPxTvml85GTP5IZPZStXzI/f9VaYYPPsTWYl9MYezz782Fw8OSPmQWoS2LRbRsgmXyynInQBsfmaE9kSh8R9oV30" ..
	"d42Hywj1ViylcW4gGYfId/5964IBCdEsl1vM2rqIIDVFLUs4HIY9goCtn1YLCeAZOipthrfiKHPZgCqfVnM7jOkW//4y1CIaelOI" ..
	"2OoQifWFF0GYjbjUtYU+JBgHfoUr78gkmnZxkf4LJpj2/8GFjQGI+i7u/W4qo+2J4K3yq04C6Gtj8QCiCSqBSKw3ZdZ0t54cFgie" ..
	"1c+PKPJe6RunV3EGIvOaEdUSNLI0LfgBOhWP/prJNeuDrdIJcjYXzKhqEioX2cHnRqlJMJux7deJXFOtLnRtAzkUgGL5uEEFGUkn" ..
	"bhY8D/wfxXfXxZbEQMz7v91XFDhEn7QMvSmW8kKyfVjxzNg6OMctpXtB9WxPK5PSqUFYB+9KVRsFbC4MQmuNdWwM2fv79zJGhmCD" ..
	"c+5oOCbaV85dzdVQdcgabTrp3lYqXcrctqzTlH32FYMTmlB+ejT8AHitDXPuYYEJ33FmxSKGyu1oAg59Xjyozfz3mg44oKAruyXe" ..
	"Rg/USbalIMmafkYIGROwNCbnQtkDa9FwyWaV8Rl39ykTUJxPwvqjQcLKfRjKZjv0ipRWwkWcWougpdNTm6cRNwWnrErMltpzvPnk" ..
	"9kRWhUOJLdGFooNQP7pZFMEEyuViDQib5X/wznxnyN+Kvvi9HBG1uzLsb0jQdKnhjsQPzXYA0vv/oajns8jkz2Op9CuW+TUP9fu8" ..
	"cNbu4OJbC2lhXdlYTBz1pnYCk7vSjvEdZf40o2eJrTq/odXbsNndhkPzgqsm944WBGtocZtWBPKrP2VDwutmFrILavwXiBteCBcC" ..
	"p4V4uxaCnAd3jr0tyx4iTXr/uNFaY6pZuK2wreuVhdgwqdvMS/qXDu8qTGBRLds4cx+ZNK8uHkHlIcFuRTkd91iwLn6xF7GS/qMs" ..
	"hvQY2jlEjKbwFpU8+bhRB5OJDQAC479fokLEK6NSUUYcC/ZB9LrYDtWIZFoK6woJu7Tk9yyx9h12qRbzIE/p2v/IRuEk+/ocPffg" ..
	"Q5FK2xTIaBEk9ePg/zu8dXadx6nY9Sc5xTZIKPDg9jbKzga5wFyKXtpLUDd4HC3zpMEGGucMZphaUf87flfvqSl1w3Mi8u13U3ze" ..
	"jsHjdrLa7hLOw9IQTXR/760dDNi5Yg6wYh326dn+Z1YEKlKZM41oKHSaNXndmdKojDfkiH7zi9u3p+/xP7cZVlsZ6hx8Y1Y75mxF" ..
	"6COKG+wm/esPAPHOPc/t1vTS52ghdyAw40yxXmVQmt4jq26Oi21ui4mj6o7bVyE8DfRHNLmC5ppjcinRjHTVOjQG6GK2LKSMaL0D" ..
	"mhK5EipT1HPkp+lQdxZanwSuzEFpDWZnHV9Jfd1HOcgSk4CTM3gd/vBBi7SWF4V9Yid32VkDXTzmKKIWwwbgGAt/R5eX/+Yhb025" ..
	"P42pgHB54daJeJB8chIJ1M4rMvJAd3/PpnNnkXg3L3KvZO6UPpb3buJQsvYeazKdPzUgpoChJqhDP+eGvHt+NGntgz5fW6Ql/cNY" ..
	"aj3YligVYtEdCaWNJR9gl6EOqWo3znwaNyLgL4xNojSRawDC/CS9syuNDuHT27wVbbcZedytyaX6m2TOiz9wToxcEdHv20NQ0c9b" ..
	"EhSyZqLDem295UBN4auqfHK0uOFh1n+onzRg1ovJzKhyhljMl5XIppkDgpEMz4qmIdjXEE2qE/AsmnGIJUncygwW9u6d6E6JSOr1" ..
	"5M3Px3r7tXvIh0GAWaaUTXsdEmoHiDL8ybEfFT1iWu+IWdnC6l2iIUCiijyaQ3w0utzNZRtnHgq2uFHOIWSSJoylxDPYBcRS9J1i" ..
	"EWiu/CJK9doaOkvZCnOPulw/FMWUA4w9KYgfmGY9Iuq29IGu6QvOGxIqEpge5p4RsQckAH4/d8QLPO9wrNncb/kVQDvvHJJ54eVp" ..
	"KB8G9kiM09wfttBWVaxE9yplb/QFTCS2dF90u0t7j51zAyP9X+8G1F24pWD8yeuPfQ9Zg1pLvfFGJRix8hNphx+a3OG71wmV9Kyl" ..
	"AwYF5K+8fgMhb++e1ncUmwqHLTKXGshw/4mrPWYCvTXMVkNPp8p1KnplbOk2pE+a6cVBkpwJF4Z4oeJnaG3ETrAfIbvAoPZtRB4r" ..
	"x6ZxEcVA5Hgc0k2S4PNhfIaz+O6mOYp+6qpRGFZ/CSE0vUCUEZlLTgiJ1cqr+JyaFdPYCuZvFlNhhetoGh6dX14g3/Aw9+PnBFB7" ..
	"yL3qEn6D74Wy3r3AIGwA12JUhUf46ja5Z9RWW6nSxgVBjAXXOlm5kL5mYdYGJTbFkjB70lGRw0N7uUThJ3z9xl6aCO8LZJNDEcoV" ..
	"HpQmv7Gq1iotonPnpMMqyo4qjOW4cLmSP64qEOq0DDsPoDXL3vdNt+sHmtBU3A2i1BMuN16zZzbnKfRaoK7jbQAeVuDbPmDPcgtq" ..
	"rgvz5roC4RCYKfdxaesidw1TJok5rHcJQLtrii98gfldrCoZEFJuY7lVW6HJAlq1eP1vYcZjir0ig08r7SBxD49yDs3l6dTcP7pl" ..
	"PnOZoA6p6U0qMfYZ7GE3iusFkdS4O9ZznB4/gC1XHLrUrY4puvwKcAJDC9p0lPRqw5Xzts4bxOVi0mk9pbYz3GU4Nc3UcZ+goEle" ..
	"oOGlnu9DJeyCGbqqKpltvffAZ8kbSArGNNwluU4Tk5J6d9vWEjh5665x59XhYR9RbZ3X2g4E1tSjIQztN8hBz+mjit9Ls10AN/sv" ..
	"7qzH82FV8uMByNWwoyoZgF4D/Rr2pJSpvZmY6xEAjU6MMmCywK0P4pwuoDHINiOHHBAcpiwfdRv8/Bfeuq1R66tDQY+YP4j684ZR" ..
	"rO28/QROrJWuDcLs8KoTOHuQXoqNSMG2sAkZ+jN6GOnrRzS6OBdumtqM09pdD7qZ58rR3pIfmh/iYLdwdsNIGTYyh+bmvBP3GBa7" ..
	"2/Hc+lxxAmesgVMdyC30JvB/36OehyfYZWCoxEXRfofTfKnQN4Myeh4liK0g5SbkgufngKyigkWWxTDBed9/2dLz3ycQhXjYaqFw" ..
	"VFTqkxgGtKpp+v82GNEtRvOxNTyh4exHaxgWfStBikzmNj5qIUeCz1c8oRvHaH/1k8rFL7GkxBfptO1WH2vDLalY/qUamEroJe3X" ..
	"A1ZwPPHrLRJ/1wKWauAH2k3M1XPgSBYux9+ZEWUINSHjoKisiGu3Cqy2JEMZQ6LQ7e61XKrZyxI3JbNv3PnJH5Hv9MwsO+OJ/4g1" ..
	"nIpdYAsINy4Av6cYgKTmlZWvge9YmHQb/z1YtJz8cQFdv2FYBIy5Zu/eyJ8ypGjTsZ+FwCpWFo2XXqSuFg1nH87xA9tOWYqagBpD" ..
	"j0ce2erbaoxxH/Wi/skI26o653x9M644S4xf3YXQ12LHXLY2VGBY0o0Nt1xD5lj1lgsV7UCclVQzdl/7QJ5uHRH+WEfnT75VS5XE" ..
	"9HvhT+97IB0I8RmvgjP3C8BiDIokO5EuGn/yZXwIjyAF+8jZsoBk5dWq+q0exia+KMPNg4y8GqCveMwBubk38fQUFRMCoUYFfSIi" ..
	"Tm+XTc13Pm6GN6jsWlQXShh9RKUCIyHTfGqSdqvgTGn9ONv7MAkxLp5vffHqOkdkWvZTYqhdyxZuRzC5CLIYvqpQU4nvoOxnjSLD" ..
	"YPxGwkOxozNyXiA4q4jfxd4uc1dAUkBWjdJHapNj3UPLtPf2DFLQaXLAf5vyuvhIDolh+QcMje6t+aHPHPFzjRCpqN1c+EML3wdE" ..
	"WaQeAWawcqnynKxD+dMnxkimrEflASyE0/MNaIn3NBqcUyOdJ5M+6QaB+kIawlrb8IIxQGInoTCIQOfylMb9ARifsfVFL19AaHzv" ..
	"7pnKx6BlfU6vFBc8PO1M7fTre5WR+jKIplyt74JaV9gPZTh3O5Db8j1VYfhvnFH8ol72htIqxnLAWl03FOZr5sLrhCu9Ki/KfTrB" ..
	"i/T4fb9HSwbRXpFX0+6joESQZQPlNCnTKVEW850xpAPeV987BPnhvgTQSaloNxZrwRam6T/93Vq/35PG/U/1CRR+acpyigK1htOX" ..
	"1aCwQHBgylsvTyZ5EBiU5M9jYYNmfxHgaOlleunYai6MOQrgtjwnqLt4xTdj8D/QGHN7cUPlvbTc2/IZYrV/SbC4HY4QiwXwD4gT" ..
	"EM8kwbmJjR9jCj8HGIBt6mOBkL8/hUQXxqQXLPTKvqpayO+npHDnlW5B+ggk4XTw+SL1du2B4omAVPNrZiTL+t+AY+NegMvGo3bW" ..
	"0IdtD5Tb1Wrb+5mOZVYm6LU4tY29g4AsCgwk9Glxm9dIwPm3eLykIpGOHA4G/NIQapZbOu6/ggubhqvR/RTTlwIJTffKkpdSbF0o" ..
	"4v8vserwgxf8m11TaJT3AxjTJOmzUC6clEH6YAotYe2Vpr0L0u760YtJ3LMLC/nloaPCb8zigtp480UHPLhKNj6b+k/S6j/MoBVl" ..
	"mU+UIWKesYyeB0lEgHYFu3dMzKyGmur8p4vLF2SOkPGIm9rNnFqONiTqCLvMhiZdHWi1bc0Lt7kiMZC6gimdCrg1vgI2SA2BnLnQ" ..
	"LTMfzxB/99Y4TgQ5Z/wdeF7jVNJpfE+T+A1vXz/skxzshH6qMMBnRjLqOaGrpZxsLu/a6qFZxNysJYH0w5lNmPixXNwGkVoeCi5N" ..
	"ej0tmZyypZ4foGIyajoL0pVH6h7JbIXAGoEOH6f/31PeYgsapqvX4Z+AvGIYXJmeZp8C25HfGgHg2NfnGpINcssj1Kpu2W9+lgYE" ..
	"fo9tL9htV4+awHsFqEFNK6LvpDXF51XPr+pa3DyCI+OrQ0Bjewb0bFw2SGDRtfROgKnRNO3du7wXlCzGe6/dvd3UB6AB2KoiiZoR" ..
	"wpqHfnp9l8ev24wGp/ZixdFBl1l3fu+X4HfynXVTzC6k8eZoQnY4nd0yQ+EeyRz/NyjjsFpH7XQfOcu4RdICGST1xjTsDFq1qaCj" ..
	"7gbJeTmbjClPlobQtMPPOyh1I3LX8Tubw4aVNr95fwNABx1Q+7jnMehNPCpN7ASgD3YrwXYzTqWrHfVBK/zE+TPGW1sn7KQMNs8S" ..
	"+Tk2KMg4/GEGsLYoZ11nDJbDGxpFBhR3G5mauxTDr67eTDMf+vp+LV4MAd9WeEDZdPr8mAQEoQfX3JKrZNsDkBVYHNmn7aGky9bl" ..
	"BymMpbId8NWzW+htyQe8udAKDj0qqvXK0LdtdokeDVfz0OjA5DLU6TrfixRHTyhl4A3BWgvPdb4PBaMZ+dCLGVibOCULPqTMksA7" ..
	""
local PAYLOAD_P8 =
	"iVqXsUHo/NAqkO2OixyfU8E9ym0D8ph2SLQz1RHRj6V7KLJ9eC2IX/Vrs3+OTx0qNDzjVFTaXBnDSUhQ5zqOfSjqMjkVoabCetTb" ..
	"crCBANNAzTbwtHz0Tuva9Xp115HrqZlgkcdbSdsFcxEqXnAwQrXKeJ6b2IG1M4qV4nB+YISNyKFPGxBXgmfz9yNIkEAkaHpf+O3G" ..
	"ZPtPUFH5lmTgAsTxhp07B2zQ/cxGasCJGfrRww1AWtzqWNy4ejz+q41BL6nvld8pSVgy2H19bm1DBwBFlT5Uak3Ct1d0CBce/mZh" ..
	"KsozlLrK5b1gkn6EXTjwxUEO6xjBNXhfXhFt+RHcFK9JxaG+JzLw6rJiWhsboQHi+ptgy9INebmpNAvmOcoiwcyGMfNls8Kce1R0" ..
	"kdGa8AgbWsW5hJvGwFBt2cTHL4HbZtCxTSIh5c6kAjS6tL/1v7q4QqMWOuQBrX7Zi3m+hCAFZHGOfsCz05ZlTF5qe0PG/Hi5zz1s" ..
	"cOsXQIOuZ+ex0rIyHs/8De/bMerYMLxvQ8I2X1PTs4CPgrWrwpGwU1coVJfgry8Mu1a+hGZU2/lnNe8CRKbsL0coz8lBV2VNTO00" ..
	"XdbJPg7OOFA9wZEIR0ud7zmAdi/hi9NEjd7p6HD10y8nH5kXxrL0Zbr5QD6eEkCcc2qWe3/h4BXILseolLvilewENCLxP58FUZlp" ..
	"fZw1L48Q4RGoDG2dyck/xYz37k6VBJpBBMj+qc2nRyKdSmP1vuylnS9czlJ+58/MK6EzBuorbI5D2lVxpkTxlwZmtR6Y0clCul2U" ..
	"LjvtDGtl1LX9lKY3hVMyI80/9y9HHKP9pLkCyqCbIhf/2Y8sMHJ5mY+O7/Sh7XrOhNw1VIn8FkAHQytiAjPpiNTXPpsIyPiuZCGo" ..
	"q1uQ38alUTAfp3ybobsu/F5HTH8JlydWXyx9JWyJ1WtPb90S1lz/FMNAHtwei0t29NQ1eADD8HNFMpnSqIbpB674je4hvUnbvIHq" ..
	"wu81LuKZWmloUVANWv1PGKyqINWgxZweUwakUdGNQKDW3IDKnL6oIYzvsOHBZ7ZmaRckUZcTzbqaD+8V/Lw9vBxTk7OEMVCqSwR3" ..
	"wAArNaZbllINCJ8i6Mg3WnLXwyIXWR1lrWLPKD07+Z/ifEGfpJ9Plw9A6THmqfxtsqN3oSvj9pH/rTR7tLaVGH50lzYRYCGK5GU6" ..
	"i4x7JT9par5LG2W7t5skyaDgbi5GjuPP9CmRykdOSL9LCAp24YjPEYCnPDmyNVcm4aDqBIURFiBU6RmSl9zQ+rfYB+SggMUMYWj6" ..
	"cl5Kvn8XnHNMl22Fm08akNvo1LrRul4o41IGx141KBwxfghyd0q2LlORP9wpcqShzzYRD+4rUpw+EFzyWJIY+cP+LeyKCOJfd6oj" ..
	"5OkFPjuvaTza8fEHhuauqh8BQA0VLaQil1mlOoS5A31xOFcfS8gQsilgJ4y+1f3DD3Oajy+q8mzT1nYpVnRehbMzKqyeo/hYxvNS" ..
	"RKaTKjVXZPUJ9S1YMqSbPnNdRj18sj5yL8MkxfYamyy//Hsm9yzUGWgKbnulf3LUcJu6mv2JBohLbKGyraHZZA4SrW2XPlcodEGc" ..
	"CN7l2TSkvdJ0Uuu3J2ChVeHtcbrbBojJrZCjD45/eciIsFgaS3J2q/0Q8hAXFrPO18ZIEly3Sl4LA/rdaBNygqtbRzEDUBWu1uoc" ..
	"Gr6Y3Or6h1RqJ+IvfixqCGLZAZn/duuax/ykCYRSLRyez3ShMC9aGft4uUirTBKzmbtWbomz1rw653xsUAH42pny0Y7dUB1Z9+HK" ..
	"I3Ai0Rj4tTOh+6IuoGd0xWjYSLyW/0ETUefoJng68D+0u5Y2XpuViH8PHCsVohYF6W2SmGYYZJTVE6/eSZIIxCbXW9C5zJVgO3xj" ..
	"6n6lkqoBzHmZn10gyJZeYTFFtV4Xq0PusU8FczEfsSjnU5K4q2+AbH13rbPl+bbYUl+9toXUIK95S8vBENoR/YepKZtx8ig0qBXD" ..
	"T4oz8JmcNkdOVYlZmafp2MjzHbG/F/pJ75xCGJy3vWXLlIQV76urHBHAe+/IeY80OUVwNSY9c8u9vri7k5XBQzPyviBdhai9uQp3" ..
	"eSa3S4zIyRVMvI8NxiTTHMHBtkdIjDybMXg+8L2Kx6cecdRbioDgVwIKGXjg5GbUXpu41KK/ki+EJu+9DtcTyieHyyKsYdgh29Sb" ..
	"+7v2x3AiMzY/djfTZWun6C8amalaejDxz6/i/6CZ48IFPJnk3iGfXis9YN9Ca5q+NsUgWJ2bBCch+sZrX+95K1K/makASWzwkN90" ..
	"QC7fBu2J52iS5kB8et3ysUNBZqZC03ntjQNtSS3y/go4fv/MC24ILqFthU/ySpmCw1S77DnwhQA6TFqR+vdWSXfxAovYol/Lb7J2" ..
	"SgWO5x1QjL5p4EQyk3+bEHiyrOAW2AeNb9SGnDd/YCX7Y5HYuKDv6Rbbo30JCfDR3+RSyLYwjTtIvhbdnSVvF0SqTYWeW9RgJyo9" ..
	"bGWdoxmUqF5hyEO9v+aDu8ayJbpF0sU5lsDD/6mUts7pSUOvdkhPyR0QA9frpfzm3mxKNQAKePD9yCcRCtBeAIbwh0gk+9HDQCYP" ..
	"eFB8MlC4tAV613wRlGzF/no3XtEIElSjfMoGvgIx4vbeRiln73KgglgHa+pxgBH7qhYJACn058HeYYe3XZQ3v6lpINeyf4E6kME6" ..
	"aV2/gruGmWqEfISfO1xgf6frz3OGX/w+9cmdN133uk4iub1kNr+3/jupMeKEQES139BmdTVioxJMvbipMu0Rmy2l3gAcuBt+W+mk" ..
	"DV7YBS2do5UioZejRUKxjmZSbWXpp5xJWlavfVBO7z4Db/JmqSWMC8VOOiD/zv27FzYdDojep8E8iSKRcGacXY53G/xf7xHPQCCt" ..
	"RoSc/YTcD5yFOjMo+8IMRbteTChCnBmmhDzqkI2Q86GPfcvDy0BKK3+J+mMssqocb6C/hPqKoJTnoSsZGqpe9B1WlLIQ6dO8NNZN" ..
	"zU7Rr+5f3ApJaakWAy2edn+E6metZ+QuQIEkedfaRy8nITLswnTd7wWXNK8pUuPPSXT00kDkcW9daKIlV+714JnlykCrtKDSsn4t" ..
	"DmhwHcZHBB3arHnfi9ZOSKHs029YECVqTT3od9G5uCyjy7SiNVO9em3R5CvjM53OoUt1TDkprDUjXgFHY24Nfkqs1q1peBtXCsEv" ..
	"ndcTQ+FyGWR96adLliwMYGXaUPespSAqSgYfMtB5YaGN6rLUidkxQRj1336n4YWt4YpGnqdhNyVZ+9Qq/n9u5hoQue4b59g3c8LB" ..
	"mrpF+Kidy2NkloyFdI2U3kNwi0rKU7PljNiBegt8DvJxwyjs8pi20X9OTN71AkkcBR3UKCzoZKac9Z1mxLSTY89sGpo9CjLrRG6R" ..
	"Bdyy9qpmFR1BTovIpNlp4AxBSN4Q9S50aeuYOjbZ0IBMW6PhZYfjBac7pxtjpq87fxBFDlv+kHa35raLqF49dDRYNhlqGx9AoQ7f" ..
	"jYozWVQywVWfb2iuDDWEJoJZs76zX6CxnWVb/pgZkfZgWMDO2+i+/1lBrqVHgaiMF/BwvVPTVLaWuapZ9WbCCi+qPZNxdqr3A2Jb" ..
	"CHSHmnBw4s8PKcdJRW95MKYPoIEbiWMgUM3tj28LGpB6ZUnIs7zMKKbrFNWbo2T5U1oXY2H0b1amD19AIaYIRjgKv6Is1pebU3sf" ..
	"f7tDhiz5UfgRH1lmQ0V2kqEFgxYaloBvycD0E2FRZoHTl5yJ/Knt89NcfgMw9oMY3A25CZUwcme/mGGG6rLBY/Hebhq27tWNRnDt" ..
	"Q2MdZiwyQ9+Kx74hBg6A4EuI6N08kt8yBcPv9asPMEuD9e22sFB2xhsufEknvMpyz3v40WsRf64rEUG+YddfvRBa3xC3zCojI3a5" ..
	"MVWM847BoVFOuN5SF3fvmYVFpr6ZwsiD0OP9f0FGjL0JbK030o4fU5Oj9uC24ftOLw8PDTtTTYyv0fFLUs5fwCmuWChno4VHBOCR" ..
	"n5HAmchllwsj4PypFg7CssCw2AgQvACzAeTabbMDFf5lJHJoEIcrjlV92SlDX2g5W8W+N839mcYIPs+HchicjjRA+0L79KnVt8w8" ..
	"+RqGTXYJcncKHE53AGAH7Gw4HBoIQZ2O3GiEbIFpNB1tB8jd+UMBVTLYeBCygyCGNdn22TDRIcI881aCgPbDQjVvgauesjeZSSBM" ..
	"xCRYgOxBbQLnyCPgI9+PMkgisZN7EIfQDqw5KF5rVoezpM3XjxEP646c/isAgb2L0UFy7JNx08CsDecta2oi+S8+8yLo8K1Un7Pi" ..
	"p1L9tjF6pRRq46JJzFX5FqWoSseECqH65XpDWcj++xWO/qkV8Tz5GytF61Dvqg22N1r/fUYvcSf+WiJwlIBf1oOO25zhQ6Vmca49" ..
	"WXl400E+K2IQ78evJMhdMVUMoeYysQ1nmOVZEzcKJ6HI9oDjuuU1BzS2Bu97iM1nHMPBadGgcbHUZnq/WLoLpeN2QR9sSb9Lym0Z" ..
	"bi5tHW/B8oYDN0kO3GFdXk0qpM+jIxJD1hiQBZBCDnAYJ287l7Heel0vwsO4fDkvPXjyu3nh9qbA7Y+7NC9Q8mqWuT/mKgNu+IkU" ..
	"WMlnC9I4p9cyW6rKRWarylKvZK11nfWtac2LyJE9ZaVLsmd4nYv9ozyYVC3/fMIsDOgZJJw0w4yQpCUJFG0f3dYtMKz9rzNFjdzK" ..
	"kZX+Twdw2Zta9eB6WhrxvYeGjpeKaETOqhbvXTKtmPqtTSUdxUduYL9r2LwcWmAgf0sTshph7lBfRjphD3H4mhK7S9dBiRuncL4R" ..
	"0cHfkpV/mTVUTEUIbbJfhXFVEV3Oc/ImzgbwHzfRFzFgJ7hML3DrB+8aa955xPgLHvRYzDkB5TlQo65TvZy6vSINEF4rWZ6WAElA" ..
	"BVwfCB5NcH2nXrs/fI3Min/IfdVupcFMLzEKxSuPK9LCwK6xsZzyEjnMzx48I51v22zvMmbjKg50AQfX1Qy82iKW6SNvF7NW1f4i" ..
	"uXI+pjGh13OmH327XMvLKo94+xUWg3zZNwUSALfMFnXyg5AXWkSKfb9c3SLj3ZP5liVO9WME/cjaUxe/jg3s9IlVTzUw7WgwYAwc" ..
	"aMcq3U36fS3z6CtoHpK101xf3Ul5RZi9k6u+03cIw8cGbIppD94gdcc+sjTRR3QNJKIHGjI0xa9jBYrkVmnOJZVHgnXUVVquESnw" ..
	"aZzI9TZEPAeTtohEbZhR4Sc4WhlhnNReJlGN2P1pIZfPkX9KUk5dAr3xXBNfoCJcruibmpNAgrXX8Km7dOj/VEZq1qyhwH/oJ0bI" ..
	"aKQq2DJGst462mLb2po8E/mxGSP+b6SrXlwcsZ57jtok9ib7mGC8DMqCtSPnnFk7qybK9O5y8Rmj4YBOV7y1psSCxJNnfkoFihUg" ..
	"2z0Y+vtq1eTlW/UzGDE+y+Sjq6tzwoRZdbp5e3+MpPW6UyW02/QKxoobumk6802jU05HFOOD34QzA6obLvHji0QPgdNYzcjXtOEM" ..
	"sovSEloezUXiS9KiLfy2yPCKGQE1iFeEw0f9ioeH3ppTpvRTy9uozXk9ZYzW98BLzkeR2Uw6TQ0a+uO4obVFpnOtO1rTDcb/O6jf" ..
	"D4QJv9WnYWP951wZ/lkx1t+KHgGrBOICATTC0cqBSXcygppXaQ7v2OMCYdGu9L0yeisENIYjvK9GshjXprqPBMh7FA1PHCV9EZHf" ..
	"jasVV9D/RGEdhhua6Pp0o2z8rkVpf7joHhkZLaXampeifXcB1jysq53ddIorV5nzciDd2bd/avfNoAoScyNMDnuN2Mg7pC6uFqC1" ..
	"2AmMavGoCFgMTGmOxal432nOGjeadHPc8Y1bYpxRFaccT9L38GRiOjYJUiQCSjqP2nzuIO0NhL+fuTriO0cUJ+mF2EkjklGtRNFq" ..
	"uy+38IkrbPL36LempBYKBCBIf4QkK1qiM3+3Xkr7zzC8mt93YQTrLgKtKNoFq6ya8q+uTuPEFDgvaI9+6wBDNeIgK6uGAuCsF6FJ" ..
	""
local PAYLOAD_P9 =
	"XCXl6fytPlsCECwQuTi8xhDl6vec0v575GApjR0eggD0OnAHeHIbQX2rNTtki+vXR2oVowc9ayc1P7WCmhxj64gP+pQrt/RSKqMK" ..
	"CRbdYAhc+8nCBWY0T6HWg8nuVyMGQFjhn5Sz1RrXApoM9MTibMGaqRETFpeNpsV5kX/fXsNibQ+TTDozcA3Ipwr4TtiimHYLqJFn" ..
	"dKwe2aTENE1nisfyC4JhI/8qt50OmR/j5SSsKeDjBLx6S6IQFFxUFzf/tdPc7ulRoS1woTbu3VshsDJyvat9mGaFe2418+sp1rGZ" ..
	"kZkMh85z0PmJ+eZTbmOKfiXQIsIr8NdyMdwOfcSUw9WoUO+iZlGe2ZpBp8DnyOceES9YmR3IyMbdOMcrBlvc5uvA+j3c8UgtxjSc" ..
	"oKk5F4rg5YdeeZnzv0V5L2yuLdRcmJltA2YKME7xpkyYPY8Oxiuf1PRRE/zaiv8aSYw8P8Qq4gcE6gcRmw0yw/DMZUhM7CfmL9fk" ..
	"g2FjLAmdC1WLTY5rkYXIjXvPYpJyEFygcUjAyf4NL/rj6A6eHuOKEaCMmeVbj8ZdMDoXPQk+w1Mpf2MMPGTrvgv4htLqBfRlkRmA" ..
	"oZJk+77lvV+FUnxDyz32G4PtMeY5poqBetuQRQGkkKMYju5CELh75yoqYxfLHiytWFelf9XcPHk4ycydkRv3cXIzu3SlQdAqQn8K" ..
	"z3ppq+QBdne5Wqa0V+pRV0qnbFsH/0KC7Yq/Jj7H8u76UozBp9bdxGCCGGxsqQJxm0PIHEnZxkIUsP5xEcsnivyPZMMeO13wU0sE" ..
	"5s73ga89M7nsMqhsU6SFAoFY20/AaGSjpBDRIBJ+tEg3NzBV0pdh5FxH03jx0jPocD+2ld8fabaxHat2XXZMeRmt43yFb2jZ30wJ" ..
	"X2BN0938Pm6NED4MmosJTVlvfY299j97HZUoOFYcJsGRa5eK0MRPx+gJelgxKeu2RW0EdyLdpRKtaHPOfqb0dmmbWc1z17AYpAIa" ..
	"Z+1xPg4noz7wA7in3NBNhiCndhh2ZLhAOsuPuVZHegviqJpGZRtEu53qSiGDKLCPubZ0HOkhCbkXPSFij8NHTWd0yfHq7LiQOhnu" ..
	"CqOk8TGvtYrY79R9VK2EgdFAh5dRpBgfesXYFGSXGC8ZCmJHGPIQffNTVncdn1DijrW/7qLtHj6ANltN9UtDIr7KlIQ+WikTRL0a" ..
	"mRUCnzfFrcQvN3wXYRSaOI77wXsmrXZ+QZ5jGxOvs69RMP8P4xYcYFCVPwi8lPPmVQGdav/s80xzsC4WONmcOB15RfPYjwxgsgEo" ..
	"xcYPmXbHvJomctJ+jAZDdJVmBqD6Dikhy2xBd3flAvxuIbyWQHrb+Uj9KxTUs7QWKuRhOEjLIpcOM9LW86Zm3ZBsC9LrofU5JW0k" ..
	"eeo8wFwlg/EjVR6X5h8HQQFEllDqVJCEIJNYYTb8yIIhZkcLQJcbbbNZuz6h4uAX0smHJzjMDqTeARCMlaljnlPwLWDKUSPsAdus" ..
	"LA+vMu+O8Sp/mW/8Y8M1foX2AvswifCBhXkSDjUYZA9DGpQWc003xv7OB+OVVbW6ao2EzpP3NBJYu5QLQkOFZqWuPjARKWsB8mYC" ..
	"Y3bkaeSW+N5nshspeb72c6XiD0wt6Stdfh21Ttu4YIFjO740UqnKQCgY+EaXh9DlWcSeFTE9Zq4vYQrwCzpfg2qS1/rGBYe+sKp+" ..
	"mtSOW/L8q5ZAQMldIL/Wt1M8XS8KJRpb3Wps9NkTsO44cJnBcNZz5t/7JsDULun+j1PBt1QXw+gu5aIBmZ+blI1UuFKkFNJGP0u7" ..
	"O6TO+kLJ2TEmcT+/TN7rtG7DXwqbU9tNJTqw/6Eqy0D+SJZ0dFapwmLZl+Uk3fZX3/0cX3k3XJGlFx0CCLD/F/zJo1MPYdcrMMX2" ..
	"0F+QcAYIvx/ACQDq6SRqeG6/ZTeUrwRTJIMnTtY8m2OODBgpVriP0AEC98gOxaKRhT9xoSndycICba76M/xj5yrmaeUm01WhVsF8" ..
	"RwA3fJEOgoNkF7Twaut/fGi9qQFZ/iLDv2eLmIl5UrVQZBj3vC1ImdFOgo/END5ghCBZFwTq7oHiDbezH3ZP9OXaBQws0ivg2km8" ..
	"ZJiQZyCk5xhKItwWCGYjmz6K9tMi1d899uQ28DKlEK4sh8+S9rwwxJiT31hqe/gBdQlLf+wSTayNnm1nX4Qk2dxoFZH9DiyxjzKV" ..
	"0NFklN4Z24lBtJ4XrZYtzJiqCyRshl55XCUCeC3b6S4LN47TVxMNTG0bdbs11ZgfU+nch7Tk03+DRVcBjAOQGAyN4KZAeKCYSEUu" ..
	"/XrsGin8B2ZZjbxePtpYhNHGBwK849iNT5FVCFrOTchQAIEIB7qOubg6jIHWVbYjNn7cVNzt6yDw5iCE7xn6P8F4dF4V6v+/Cuk0" ..
	"bDuQNm1h9afTgH6rP0PagsETyAAw3cozjv5D+WMO0GVHAEyJ5NAsusRxtc0JqDBKlb+mwlM8pzUudRuMPMxW5/k4D2ZDfaz4lftT" ..
	"suBd7TfIHocK1dVcz8RpArT4oz4Ep+sUoCaVgFsVjMaL8CQfPSa+O0YbZtPumcGqna4XSwNRyAO9xcyybvkq1bAUVSo0RffRoNAF" ..
	"jS2IE1slxO4CXa1BDWQ6QKLghUu9FoFKGMSl0vWPnAnhNfoKaX65ruAJmnwXdLVqlKjfSaFOue83HDkzHWn0RmhY18FLEZbx1bqO" ..
	"jxS1lITgzSQfj+s9aPnluHFpjwUVnzKFVJYRgfcVk8S3B+ChtyIwpPGsI/kd4+D/eiJqWNluoNnDRkktfSufhbtjSUmmDT5Afdm4" ..
	"7Z343rI7PfKabAxwfcYAhqrT7oaXMUgkbVKE8saTpU4s4CZPDY0RdVvfPWVJT3M0Q7EAXO+YoYDRQHeEz3hkLPq+ms0mk+a+0eLs" ..
	"mlrMfVCqEvgna6/5PUMaxM08zKMH/cVXP9TBzdQAl0klyOWRPbqS/WI6zY9UXFP/jyEvA7zhBMJeJwUlBe1eRhXHaHuebIK2ytrq" ..
	"gUJOJ/Eq0u1zfbstD4ecfadASmeHcJKs23lU0gmuPGBtPUWAZq/SiSfZV2sjWGKJ8bAh0LhnWegDO3e/DQ24+k6x/I8CUcyImZnD" ..
	"Qmprb+ojUbB4x2CF8TCmG62mPktm2aPLULkkO/MSEhNOaUJEl54pLm//tjFdE9Atz30VXUE1S0sN3wqbjHVOnTNPlrDl/iMURbx9" ..
	"0Ao7pZOgthGRHXpPsgLi12syf518pKh1ewe4LO2x9hI2KEJ4D5G1dg29dxfrSeh69bcmCpYhFv0wHGRU3RQng5dRCq/QTnYnSJP8" ..
	"1P3ivMCt4pNk4gHB/PQVEWnLtrPZMtHXKutr6YEEPtlkgQr3M/6fbo7SJ0brfsLzjYipuyP5r9xj+RgEJKygbpA4rf9HhxPNPpug" ..
	"py6x4skFUEQ4ga1S1I164wiVYsxtuD9NOulNWnH+oRsFsRHW5pOunbQcvBuJpMHmA6ZaB9s8WPd4D07OZjT0LJVU3ervLc1UHmK2" ..
	"WmRAeMEuf/UZepUpUTayRu82AGIFq4HYbLur+KHaTXaSaD+sAzAVzsCy1whx6B2O8eE+GH8d4C5ICzBDJXH7dDyZKPFMBbwDQgL/" ..
	"0nsfUsL6FX1GNYP+zkYhxSpz39D0zFqyttnlWDMkN9uziCBzBxNzvCVK9ojRsjWeAU0CBCdVUjPCKP797ugYUzOKCPcj/U2g4nej" ..
	"YTCknDDZScUzQ1aRpgbnP2FwGbaXBk7cyoNARBooQQyA84nFZUNqaCcC/BCfCNWXeDdFd+J06AgClo3aZH0WfjHyywz/mBM56Km2" ..
	"iFFpe08Ge15LD6DfxTWtGLV/k7toWT8mflesNE88gJctUbkItgVSKiObrl+NGpXxygROpO5JEYYhhPKdxjJ9j5adwVWhXvukENUF" ..
	"myPRBmiCxg9PdRseCNxjRR0VuB2M9K3jwmJ/LVq0TFlgat+KjIULTRFPZ1kvSKUyppzhI57jab52HD0wD9eyPb2tdXLXex3xhow0" ..
	"xsw6EuegbiuX7Q9ioeKG0NVdnSNbq8VZvNvleW8N1ZXDXw+drEzAIGcCw3V/Q+gHviSs3MC+FmvoKzMYd20iXQE28iTlsxRjr4HC" ..
	"GDjxMNGbThvX1aHmN0c6CVcHFtJZtZ3eOUtzv1My2UvBAqgPafbphi5dZfp7ebJOK5XO6jelJrw9MZZy8uTg7s5bTWBXNWMGABWR" ..
	"R77cH2U9wwJbMd7JmXYeR40hjEeeuLQp/sVSKQTf6hs58g8QHoEgjsE3ErgsttCQfPWd79UgpGd9McEkcgLPVTvFFxQDvqdptD5S" ..
	"6xulgvBfdh/2gecMPIlxRW6IVVwwHo/vgVYN30rFwZbtZfE/MNveWEBWI6GquIyR6Kec9AW0fJlMOHskA/t/eW7ooJvd0pioZQeB" ..
	"gvsPUPFar9S/czS7nGTOO8Z6I7N51/8hG4kBBXSwh6/jazCOhb1d+bl6VVZhwf0tcKqqA+RLbTbrIt/OedhzOtyZkdlKxBeQUuXD" ..
	"sA6QxWI/QXYOO7baaa508EJrY1WveY0/wrgKr0e65/P9LBItv+X0lk727pmNKQ4rCoL01SrmCHVifQPIczu24N/9WZSlilGUVCPA" ..
	"iwQQelYMLHzN2JUcGKwdpQGqFj8EHwlZB894K8sZtw5ObnlCi5Mz+HdQMnjlpf/lTd/CxXi+AD9z2T/4esvwLAbrzGw1e/+s36y0" ..
	"Gqw9bVl7p9nyeFNeQdVCie3kmSZMt5AEpg216P5ylFilxveC3p9d+jTB1duFLv3dQbikTVBiYlNOH0IVE77mRwvvkPi86wCm2+uc" ..
	"K7Xko+Fz/n46/rRMYJC25RSCGMEhWQvWhFEzn/ZoBtNEIUyBZ3TmUoBZGvsYoIr1XPJ3CtR7Lzw7+mg8LyqHMuYwfsFkA3whP2Z/" ..
	"A0qAWiSIyCzuH1Fk3yoo8izBk5MBtk5Sn6KLTXHX0ZpCeq6MqdXeDrYqQEr8LHoRk2V+4ttuOtsjsV+x0eOwSdW6EQp6yEwhEeTB" ..
	"cj5sOljtkQHWJyoxX0ceUue131ZWHXzmO08BtdMccQWAFWncJhiT1OEBmsakuyw1HedVBXdgw5F3TgBzk/kj2paTzpZkluB7CZ8r" ..
	"PZfnfI06QsWCdN68reANe42vV5e0kynBK8Ci9yVitNxdxk1c8Gvjq3OOMC4j0tD/WZnmQJdH+JD90CeZpefn979P8XXHpChro2+O" ..
	"PlNQPHB3ujMvRIW/S+kZcMuG6bmfNZrF3It2hADlfzCe4ZBxqMaT+MFuU2PPswd/rri7/tnZqrcFWUk31nk9cLgL6aD+z8cY3uXD" ..
	"SUYpUcxAKSe6l/a3g7mklH/3xI81+Xe1rl1WXWidaf+7wz+3QfuSmPtinqfd5KXCXbobRjBwTKEIdmkH30G2cfNLOherJlnl1Hzd" ..
	"3oYeYDgPLbEuM6pFY57qHOmJzP8/9zvbcCD6hjWJf9Q5/upuJXNMVX6+L32AKlAiPrOmmw7pTBL629wlck01UexfYCfmFdR72ULc" ..
	"d6A1z25dzbaXwNG99UDx4HuU5uhEEXSbmGHYrZmGHkntO9qQzxGTixOxAGUAyOfD4xoJZ8kHFurvScrJIny2AgNAWp5pvZ5GFPB5" ..
	"4J64ETt8oeUGOtOdKvuzNDkvAcwc5cp6a322vLrqEv/tMo4Sw8YZ1nVAbGI1ATrZqyO8KMhaHueu84dzo16Q+2mSI16oJBhrArx5" ..
	"Qs4BvMleSU0SiPZ4oeJl8RDzuWmR2i/lVS/cvy/h22N0PXY/IdS1GINrG97nyvc1cocTzEuY+8Dtzy1SiiL0XMLbx0u9DjVX22H6" ..
	"Va53AOQms0jCDvHZgtaUcMqDqF3u6SKMGm39miV1NRpYa89IB5OhwmssyWe+nRl8x035Nke+gvH2+OuvnGabD6NSjmIJBTt2SN3p" ..
	"9vu/WPvAORLYkjUj/fJO8Yu9SP2ffKvMfxpOBrvTRXCdeWf1iAn+jln5tGUon4UMNkNi+HI2hD5tUxPAWxSMomZUGCXC02tF0GVV" ..
	""
local PAYLOAD_P10 =
	"EcZO/TmCJIofMEUJHgkv02z/tEexoOo1fGu1HYF8s67450Vt4SB25VrX6KjZXq8ix4TNOwhSVv6iCgy1IHHX2Lb5LTrHKSUXClJt" ..
	"0+mm/qr43AQKV8bIemLPZwggaofPwtPFJbckVM1rHhM5Ze2az12DSpBqB3nVGyJj14+h0MeqeWkQd66vHHtJTTfllSN/xyR4F6XV" ..
	"kxBj8IGVlR1zkXVNG2klg1oNy/SJVQyrU8VbLJj8LL7qQ7vv7nH9TSnHYFctQIBjQ3Yv36jNephmXriR6pUxZA2llz1oUk9Wznl1" ..
	"1bYrOf5/EigUIUzg17UxEfRNPMuQ/imI+dFYMMUexjzq0wNTTlVrMw7hzmiLs6CE2TTs4Nara5684JgEtcj4/C4aEfH4T0EP4mlo" ..
	"mhVPoExiu3KsDjocL5g+g9ZPB1hifH7vr8hUguQBDPzd19QJqsol5R2vMQTTclgvzwKDNmrAQORTDQvaqPt73WAund+WJUClFBLH" ..
	"RxeliwAl+uEpIBPbQAifk8cFh9zaunOnPCge+F3tiUeVx9SlaspRKSlI68ileA0mNKgCWL+3vIa9Xyl9qIOE3wLm2jvucNFbu4Bg" ..
	"mycc/qw/H3IDKkieCyPky8v98oOhcbMlPJbqrL5BgUa/JAet+J7BT+UPETOne++7853D5CR4xaL7PaFGAFVZoaK2DqEx/xN2Y/on" ..
	"ZFT9Fctt1AG7M0NOZSZZVFABmgzFset/hwky5NobotNaXfvGu6Ty7ADa9GuwUc0SnSYTbJyKWsjeAQLwDcjSqoTtjtLNz5K0KQfb" ..
	"jDYBjvdYX99LnkU6oeQC7RpNi+u2XUpo87CAIvhpvvpl5zJ9HYFBJ8/sVEdnW4qzb4N0G5X1+utJypmBBdsAwH+5uzlAc2pP6IIj" ..
	"vp2NVxEmbTsZ3Phf5lR4KdjOY4C8g68V1vOSRoEny1F7yJb+V3DS75LEifwRW0dn2qq1AIDII7nC0j214T5T8vYu0XY8Rphd2Coj" ..
	"FLkordKlZUVzcUrVfyKv17oJIoWtFh27P2vD50mTkxAsJIq0sjq2XrxQsZbniwr1QdPrBki3mu1cfMPDxtnYAUAGBoSaj3g5cwK+" ..
	"4MU6cI9o79CwVWIdFN9Sv+MWoPFYZSWNoYCf6P4/oDqJJCHXvqTGJ2oC1dr/WS58LJM/SWFX1ewHAo4nxspRUtwcTdMH1k6UGjiQ" ..
	"eCnvnMDRIxb7off/ldJpE5SMq4IuVwVXVL7SUBpjohNAJlHqUeOLWlY4qIYh2b9rzIkdIBF/jXGCzetwwHMxpsIJhoO8yga+IcNK" ..
	"kwhwk3XzcnpBAd9aT6SMorLH3MYFXDumymh7uGAUyctB6S3WF+VldUgKm+7ZE6WxAoI1zEdXf7AZq4SVl8WovDAXCmpIcTXlvjqp" ..
	"I54dSwwIAkqXe2FR7Gpbev9tBrthyTWKwnsMjidc8jlgthL6HvuHQdgmxKnfDfe7iA5RhwTFSNrfnS7MGciasatEbMAMqgzBZkTy" ..
	"auOaHOUdqDxvaw1wEwdGqI6k0XQA6cq4/j0zd/XZyES6DHMMNtq+u8XkotHFVj9fcrZwkWWYAUdr8b2NrNinMGY0jVw0zmMgoHiE" ..
	"+Tza+yJ0byQoisa4gHPG50XutlqNqgO5LTcQ9kQoP/B711MCF2waCTmVvhYvxuiobpCYqD4+sthFGkOdh0HfbARmIft4XfMhRKbY" ..
	"9qsEN6jKYgy4gCXSKUTv1iW2A5SunDmIzFobcZAd/MU4p7AxyZrY9v9vglofE9vAG8du+Fy48v8FJ4fm+PqjKThUQISw1WMhXoRt" ..
	"5JfuvFT+Ii1VTE3Gwc7/DoOShtGO59x8zWSgq4IiuXDV522Cnprv3BUKhirys6I0LiubNKQdU90j9c9RF+Aa9sHiD4wwWEU+vmBN" ..
	"Mq8cPgQI1GSU8iFs8X1D227uGt6yaJn/mhZaKizoTicx73XCJth4crGs6bu4zNrdXHkcQis8FGHtCy6GXwKcCaLZcSjLPzvM++Zp" ..
	"2o+R7UDxDgNH+k/R5nMZ9SofBGuYX9g8pWcOBM/I7SMGTDg7evEy4fg4Eb+wifUb2ryjAauOOv9BTtExnPHcEaDEuTR9UMsm1lJR" ..
	"DBJyOhtaMSvqYXxm7sJVytVZImw/0B4duRHYncArBLdizibqTZTmlPAvYTOxJAfNlQlismYeL/migKk7TJJf8FqNEVlK8M8tqYXj" ..
	"C5FWQatTB8C7t5uAJ10l5ARCLbDu5WlRKN5i97ca1IY4x2GQZJHnu8Uv3Ktsah6x2mzDECseFXO+4sH9wHsaUoH3BsHB++qxAF0e" ..
	"Pyj3rTvwNMQTytQn12NScnX8tkELvELkcAELf6hp/z0BRX80X+SXT44H95cKyFNMLie3KGEmvHvXEdZ99YPAQS6QsdG82uzVsX7q" ..
	"1qoFlabyNjYNVPxNxQyNne4wQVhkY2EESeNATkc7Hw29S+oyp4r2SB660AcpB7omvMJW8FY6I86bcqD4bW0stge/hyT/KLdzrrxx" ..
	"gz7amwm4vM1HpvG97kw/Xts2D9Fw6g7oj13GnZQi857QqHBGqEHN2HnHJG9F55toinmVfWiH2SXMDsHUcX84yW8J/qhDMqc+CeFH" ..
	"d+WPbzmOvc1opr/Ch8NFqbpcXp4zP5WmZQ7+eOWuwApwo1J2uTLPRYaaLciXFXzpszyfROvvaaE70T4bfIh+Gz8BaFDdVru8Ueqw" ..
	"Ahseu0n8jSMAk0Yds35ZfJ13r0gV01BIRurDWorCLQ559z+xtKDVgEO5CC47eS71R5qa5aMU6HZWMA57LUxV6tW2GXcGQoMwcZDL" ..
	"ouH1Bsm0Dgzm0MExzCy0kyo2QFPAofgoQofIDlleRgQvMH8h9ygsiD9s6QqBB133ovTVqF1W/RZsBSvSMqsCVd2MzS+3KBndpf6M" ..
	"WT2aSfXnL8GdcLLXBVAUaAnmSJ+9U+fKzRVLWQ2g8hGkqmziXrfBqPd3sDp+9HEspF2qN8Q15LrRRw1pNObkVn7Nw2E2hju1V+SU" ..
	"i337rrIzhoVrZUpmACmgdGv79+lWE8Dsgna7S/r8MdVrNOtCZqVe4bmsBbx+peXVvoqrkPZxUXmkjt9klHYtxsM1kN5nzHg45lDE" ..
	"kHUqT+zjfJWVB3qABB48x2jWcunJNicZfVUrvhVogsjXL8zEA0eZpMFNfq34HXyJ5g4QlxNt4L3z1jorsJDeK6PaeYugkM0u29ny" ..
	"5KFg9ojqcFRCzo+XS0yRKDfWd/e63KgHzotlUQ1CNXEcZ5PRmfp8lPr2MuydmXcd6+H+TNt0VcqIZHmLNNXQT13Een9pWh4sPjhg" ..
	"Ujvw76M/lHtUppkHrTLvceIULyznmTZR1ui5S4CnI7GZak/cI56kg9HpT92KCSB1+aqPCPBbk9fnEsON0wjepTrHiZZ+le+/kWpe" ..
	"0oa9ofZ5RxnGdjzkRhU0V2Oxd0dHVarz9teqqWc4EwJtYnDIqRv8+/hosj1zdAPxP34ZpPr/s08dOic5ObM2gNXi8WuPlxG/p3EO" ..
	"DtIBTqpLntyPES4O367eWDVUxMtbnrHCqXTOsLr5NKzmXKs1YgnTGhiEC78MIOKA4FfbONQuzVxqeBf8UKm29tSekhUXTF7kAXPK" ..
	"Pbng0jEdpOXcemFNOGvCNUOBxpx2kc7O67HKR0aaaC5NSfjg0M4jag30DjNZ7qhNBKPI3wR0UznDCo1hyLXpT5gHpvmoxnYO67Pb" ..
	"V4tESo7AxXUZ9lkF26EGslrnFnLm9g4JtDfRHznhAqN0IKYPRV3HYLX+3dbTy2u6VYdR8Lmp65aVkfPRJAjQKc0jvh4CM0+6/vIA" ..
	"jRyLYFpvwxWgPVWL9XhIAckQMJx2ZtG3Jkl2GVf5IIXnja6nilr+QlQtd3e7fO9ChLfI/SPz4NOGQTq3ZjQxAOVyoxvx9xLkjGUw" ..
	"NJHPSvT8KdB4de75jhbV/ESEacvhAABQ367iWg0ROMi/bdg48w8FJRbOpf17C8uuG3WNbTKlmCcqJUnA/WuGv3+hO2G97OMgaWba" ..
	"aVJAIsF4c1jrLX4H0lw84/0sDxm6migW5lcnhxHlAD2LS0UKzGoyOuxMFsioPPBbZU89LItAhcPKNoI3fSBmvqtG/JENh9el5MY5" ..
	"/XBmnzClbhzJrqX8rfxrlv62qK6avTjnxvrD0BRmUnR3gyG8HlfP2wftbZNXS3CfMNyy9RRk2nhvz91CxUnY2ANGRqJ3wWqivXW1" ..
	"6H3isq1k7EMEoepgcYtO91wLwbfXkPnLln5R5oP+sedW50x/jYOwEaeRR9S3NinFepyr0mGHHmiXP8p4idTPF+Lr6Q+p+HV1gh3f" ..
	"iFwGraH1NnOY0fQTK5emalVcms4vIbLeuQvtz39OErrTZCRgIPVDymMVicfLfw0F0/ke6OjEKiLl7H0m5gPqPJV+BJe+P7Uqmf6v" ..
	"9Ch1EDbTsexnlkwrQBoZ8wy3c5LeRVqG0aTkpONx2fHsTlmWH/5mWE5A+CHBDzyWx4LWN3FTG7lCDO3vWGVRlFxfsuaHi63ecttP" ..
	"tqr7fEM3u5/W62kJUCc2FajHM5zqMzSaM1xKYzzRx4dWmpVdEPauLEdl8M94/hV4RX3H26/+Fh1e1VXVknp4ToYA1fc3w/Kb7em+" ..
	"kBAmqW1ypvlBbRP+he7JJ1DxVpL0SH49jhrpRK6mNGp4h2WtiV+D3MVBAA0HNl3w5pYJ6JONAascVC4iVFkVsRjmiqlnvuevwE3/" ..
	"prcJeullw9/5wXwh5nCsvGI3j3OJU8mGDNvm9rQ+l/nMJwt5uixEBXcX7e2ASRg2ouoKvhknBJEBpWDd6kAbUajNv/OHEEBj+OIt" ..
	"jBMPY+ApA4/dXvnh0c1jTfA/TnXqV0XzxIjKhC0ZAzNiGrhdSnedgJB0uni4vd9dsy8shTjYv59pHrQDiQTyljNWuXZK7ciuRm1v" ..
	"SOGB47hZSdITu0jAdvE/82AJgFEA7q/54nsyZ6VUyEF9UfTgxkQ8YanrudXZ4AvTxXRqOkaAqAPLYou48ekZu9C4JiJRB3hJV+fe" ..
	"HCq/nmIJlD4C8kvdepdv8jXupDP24zCwnSCI8Lt0hJTWLhgS/r0pPPf8/gKYAq8CetYhaI3K+pKmxhYK08cyCElCF2vg53zzC5ju" ..
	"tpo4+BpnDAmbi+0LpEsNRKHRLn0AleOY7PUJ0GNcAzZt0l8XQQpnZ0Uk+khpuTiuRAazSRvveidWwjzIsHn0FLLsiWC2tX6oqbDt" ..
	"ED7gW7wnDOxJr1j80nJd8fs4TVKanMHV4U6k+IK1NdUxO8qinFdBEUsaJ39R58PJVQkkg7gKe3onJKC46AwCsmvtkjTZFmNHRTIU" ..
	"fEOFCWQob8rghwu+KgmvLyq+wXnAqdF6pnkES0we4/ZlxuXWA+yMQwATvP2vuzlAjiM5JvnW274Nf3XxWqQs6+k/0WGhn1zuGPHq" ..
	"0BICOq44U5hCNBsNy1mWKaDzWkCxQWD1n/hSOhw/eqRXw2DGWv6WKmUGKVr6a3jwL078Sl5lSC4Ev57cULbMjt/BMoV42QjXJmeI" ..
	"H7rTmnhuncYX9tYb0BOFSkiRJxDtW11pyhXO3NuY4yrmaJliWgonrA3qKMo10h2fHjMB6kE2SGoGcxBYtdfvCFfW4axUA63NaJNm" ..
	"Z9Eswz1kyUNjUdOYMU8aXFJBOVkM5jlYAQMa55OWhlxboUZPSquw6fU6pmarX99ovh3XLoCF/BlSm/EM3R/xRvRB4pDbW2/9DVeE" ..
	"TU+6JlPwi+ztxTybFz+udUtkPAxC9cgA86o6JMjBxQIozrhdPEJIcUuU3LN/u9Umi+ZbTsA49m3SISEHeqwb/g/lL4s2uU8oZtqc" ..
	"2/QZcVV5NUZTvrUnclYteG+IOva2sRr8tDu/v3KC1RVzvohy56Y4GdLiZNVZ27WNo0jVaOdmoFMq961z8Tln19k8eyv8gh16T4g7" ..
	"mlqr1olOjWdxFSb5deSJxYSUPUXCuWXELr+Nr/mWWqTTNbKFxHMn/hd0I9c6JeyFZQ6kuHvZw1oeflRq4AedNkcdwSDjNEce6hG1" ..
	""
local PAYLOAD_P11 =
	"5pyqr4hSZy3/cvxJDMrtSgbXX2YzCEHz76iq6P40lqK+VWVCJ4jiPjwGyOSkDdKAd/mTa9RJrOl6NRyOkOLCLuOexxIoDXCG8I+s" ..
	"nLeCcEcJVqjwAwPrXVmQcFfseXpOHF2OOHMSaIEV7DjAaMwOjsC1dbSSd4BxGdE0KPRARrDRa8VMcty+SGiZ4JoXqb6DTAOTGNGX" ..
	"lDnByiboadWYc1gWvwWjva1z4PZjhMPaBeQ3RE4WjsA18a5MZHjgxOMqlchccd6f+R9rtjIIFONDQCrtfcbdvTk9fsX4Gi6O6rKl" ..
	"Kx160eC2EWIy4HUi4V+c9LYz7NHUIuZoLnKyGOzCmqoYJQcKY1ZiJ7uYLlJ5uKWMMiD78s7noKeKblAwbw/K89IrA9TzU8VzP1A+" ..
	"Ne0BW6DrTgOVg4TmZ2kESioh/mhJRSbgtiPt14MFIskGr44PqahACvOskmeq/Jkk6Vtqa8GslhB96VCB8LQ1jmMQRrZmyPTv3V61" ..
	"+JWpPsx8dfJbodMcpVhFavZ68tMorR+hY/0NxUp9Z2fc+KCikIz8jPIj70BDvvtP2MjMjnQqlCCp0P2nmW6WUlTARsYrnOuxHQgp" ..
	"qKiNF1ak1neT9OfrJxjJhcNqE+5HlvX5XqrhvXTZ9Z/fsix8BDaPGgygQq8l9ghwRM0vIBeCMmcoFdJRtjn8qpk1sLEwabU53TCI" ..
	"3vs6hKwn4vtI9C2zWoaeI0rmfbxGz4JN7dIVGQF/o+voxoRuuQQ/VUS6rVadBrHL3PZz/l2yuGY+ScMWdN20vq6uO/DrWh8dl7Mj" ..
	"Qx1LaHO7azsq3jfuG/ZH20Wg6uohly9pvdRLx8+xQZVrNnudEaezU/a+nVG8sGabaZk+A3jHCvlyJHFkEFoNn9HfBCMMeKEI0pEK" ..
	"u9sZGjdpx5yTqwUDxoVOsOAY7gdymgMM1ms36rIk7idKCbOvH61PlZb4xlH4z/MMz71X1no9QMXZki+PSvWIqHB/Jz8oEPEImz6W" ..
	"wKyfZ5Y4TOBi69JpwvCJgKowZeWswv79NdBVdyvA1GL5gewTfQQ9Ici0LoJFlKqXKOl/s+NdRCbPSbijQ7qRF4QOcyOSeo9KHb+h" ..
	"t7+SUydd+LK9hkJzrm5UFD11d/WR5SbxFAdefYQGB3Rl6DqV5MutuOGgcyaCidQ4G5gwT8LdS3NRtg94mrWcUxg1TEFlPO+Xa1YL" ..
	"OiroXsVNETcESiFZUECyKTD8ki+0eSF+FlLdhwH7tzlDBr+VDoayWKXMlaqe8uIkeB+9KrCNnjO00Sx6J4JDMEb3AXaR41zw/kE+" ..
	"bfzNWOOGU19T7kTRD/WZS3Qbfxy/ZGEVXJmlokjcESSWQaFlyAsqb+FygHVHHLZkpA6ENoIriEu2h2C7Th+g6WChqxxJ63fezkf0" ..
	"Uf5A8XoOs2ISpfwKC25sr4q69n4gYcunQHE34PmLSni0GGBHJjY8SAX1zC0yCW+gPtWoo1Sxe/s3osw0dxgYwu3iTKMzf+7COJYi" ..
	"9mI5sv4xgXfKx/UrqIrFyV4BIkqP/Wgt1NFiQeG50ir4Va0rb0fdvotibDvovG6hteR2KDzqlNE6X6EAYg+NUpv/ndAl8V55nnRL" ..
	"RUkAl4y9/Bdm7AbRXhC/SiMM3Uxdw7QfGBGwu8E7e+2j7e+fLf5q79HQkMfp85HZQH6DX4Dvy7W5sSQ9WQiNiNtB4M8YGM5RkA77" ..
	"OgEf6eAtb6ER0GlMyHYyw8hj6cfUUzgUGswWMBIgq6n2C8m+Lu4cuuQxuM3JwaeRu+eaXB3tWUI8W0YR1UwVIwBvNo0k0v6zQaby" ..
	"7JQVqZi+ZfsuwxYRRnvbEg+kGLiIDTa70se8ykjNun1BD1pq2RNp3LHgA2NU63Y0iGEqu1Z4QzG/djj9b0UiKmmgq1ZNTRv2QPpV" ..
	"fFG/XJa3tQ1wjO0hgr3xoUa9tfFI0jcrdZGunSNyXRMCuxf7qY2p2OK0H64RVsjPjXl3Sst1ftbclN//mFco4qrtnsZ0EUK4oO0d" ..
	"j/l/pHIGXgJS1tUyH0YjdtQOLWdvyXSb8PbSaurhO4noD4vIpx+GJrke7miIIfjbZnPSc2VUj/gPi8Pm47JwM7YJH8sGg47MhdrS" ..
	"+gZZbVthCPw+M6gJ5e6SV/Eu1Wrj6FovSBG+SMDvZBn2O8dTYuBrPHItM8FzN1Eej0WYwe2f9gWybYDJ6BaQ9PRS/oWGlefrIDOc" ..
	"4ugeZYNCIKXKrTkZELojR+0FNY3mexoY0amjL4rvjnpcmDObhoUZlcYgggdY3K9g0HJfEYowSFEMNdwFDEOcJg+wwk+ZeD9h4WyM" ..
	"6v4NKwqCgWF4TW4rf+yMTubEEO/r6qT8kTyMeMOEewv/eP0nG2dpldHM7lMjPO77xoSYkLW3Sj4VsSH3oGkwna5D79bzO/seb4rX" ..
	"A6RXtXFcsSES3uDozzk65RqT95U951MBNbKfaWSdFXfvWAgKilVcgDbQYXlgfWONXTw2ESV8ivYGWXz9/gKyN+zpDIH6MawGdRWl" ..
	"/Dhg5j/xugxmHRiDo4nEJRNWWD/vI0/9x1F+FRf5SPIV67qCsTWAaMO3tiETI2UsgA3aoM0ynFmvPZOh58oxAbHXNRpZhtcdcPiJ" ..
	"yitN635ULYmXDwNLpz3Plrqo0UROEFqgzPqpm2yhyASpLn9GX82ACyYhelXr8QWBLg8m0i6m4mfepecI1UjnrZ95mV80dobBC4Z2" ..
	"BnUncgPMwEVRlojWmt9r1Cs77D0hBMmXkxyHNG+Z4/UjN8gvDGYGCjpu6PdHkQi1AnNZ1/YvTxHy7n6jysxUS/ZACSu0r8G5K46c" ..
	"Oof0cfynKP7BUwhjvsaHoyIrZwCpFm/xgy5V01W9cXSsNVo9Js87KZWb8O9ajI1ZuqM0fNB//XLk5Qw2z5Kp5uB9ML/U8fIw8qYw" ..
	"ij5OqmJuoWMoqgR/h/D3FZXANLVRNWUFinW3STeFev4XKlP/fvFWGzYmJm/mekEW7hYRfgmTDjEo8os0NnAXIrah4MJocdCFhhYZ" ..
	"rDizFGWXtruRxIpeasOKtt2AXOa2utLnOM/2DU0XXMvbU+WCfeeZkCMZKGNQZ9DTgXmBSgptN9V9i5Cq19friXp+ThGQx30JZe0h" ..
	"YsYJzL7v7IH11pSeJadNHJLvbQqjEpsNsbCDpFzFoaq8OTFrRrTb0j4uQ/twP3ZqHEAuQnhR1YbaQKTYLbo0DAE7vKGCTqq4pejg" ..
	"mubPHoNfEB/aC3nvNFKXGcfrISaAPbPqWyYEgTbWMkRpXBxOgJi4u+ibycjxeX5vUEgTy5vwDx+5yyQCZ8g4Ifv+3PV6Q/z/WJAi" ..
	"8rie+R+yw8beSvv3QhPiaQi7MPWtLTFujEB+b1Rd/XA3HyZEpaE4+a5wQQ/5YRin6eBRtzMJf7cM9NoUNkhy2ItqsOxyxdFGgbUf" ..
	"81xy6gVlvGEOy0bCkplNzl3Rk/03KTDV0OFt/SQn9QTY4QGvfcGmJnHMuchDI0d2ijEX73kZS5LOpmuaaC7VpRxWXG+vOZkc054+" ..
	"I+d1E4DFWAaYj3Ea2fE0ImkiPNsJKgKR4NqliB8OHGalsTNPt07S9xj0qCElnTqbbmtdcjh6Qv/OxXhYvRkF7AZ2lJd949WH/7ih" ..
	"hP52jTf7CoXuyhYwXMrlYrXCi7FkNmF4G4uhR+LDHMwe/RE1K+cC7rBM58+KwJ4jQichCHoBDuio2xehhZgcxsWk7LmPa8NM8Prj" ..
	"kY0kQie8w6yTXpYdjVGfshzkgF2A82tJODnRAfcSwwrBJ9BREdN8faqAk2INC6P/6MSLBQLiBGxcXG26fp+Af7138dw2lKKlkQtI" ..
	"CArmFlgh2k/Host9GqdxICRvcLd7PCJ3zEdTfER9IKLjBZ9CPEFZH/BSOQhN3NeDJ4YrimaqWUMJqvnE2fYgX1vAphRhJ58nH7/1" ..
	"140xjfCFQcJ44KIuIzwQUCzLUgIOu8Wts8Oft5UCesV0xX/jkk8+J4k5Otun+YbhBgnZgbCsdGr56S86QvBx4WQkyknBZvtnt9FB" ..
	"74EKk7EnQMmB6ntl+zIHu3TyKv451xQmK3Td8dmCrdZrXH6yW5cUKOQ3T1i9ZboGScjic5H8TGk5F+mZLHg89fvbWXJvVr6Cu5pj" ..
	"lk8IudAAyXYgGXCh0pWF4edyts4EGyiKolayxAfGU+cOC0HxYHXkgJbDYWV+B+lY1c9CcNY3CfoOYfsqv1WobsjVmpqmNjE+H8+d" ..
	"Kxa8TgEa3y54+fQJV4HChezNFniKnyBabi84C8CWolSRqtofgiwVaUCwoAqzKc9vgmzoc37+NvjRHCjm+6+0isH9WRFKsImm4htf" ..
	"keFmgiDnngEv0xENCZYB8v0Ev+bR6mDaLqtVF6NdyVEl2+1QHYgMs+83tAweSKp4+EI6Jb0yJmE6agLVNeVQv8UbjGmJzwgfBVN4" ..
	"lPhFPxf9U59aKxcW8hw1SZT0DTf/9gweOlMsBR/+4KftDIiD+8+yydXWneXnymuM+IiruI+0JqxXNgLSGO4W+/lf0FnuhK/gsiNe" ..
	"PO8CTAjaCcai1CjUl769o3/u4A6j+mmiOuY44KnRIcn1FwnqhjW6OhvKvjX+1lsdE+NVJIPctLXE9NpLMOATEB970J4nKwIjer8z" ..
	"4R7auoxeolEKccXqCzq4nzx1bILmqZacmk7zX/HgQrh29Upl+ddEvGF6Z6o31MSYfLD1aSJBOEbzpLqPu12OkNtrReVac6PUlGYW" ..
	"Tg0xnbi+Wn4BH4Dze9JyGZ0DO8giyfCpWcZKLLOZ9Xx/2c97HKSe0TOs+1DUAITVk/inktR7IGONOdY4rFhwdlKNPEy64sTXIm45" ..
	"t33nruMhnxjmSwp3orU8bc7EI3qbSTwTMhykeQEEP0S0jZzuxZLAY2YDLRUdIdNZR3JokTmcjjFU5dR+CRdooIa/wlfJeANpOdyY" ..
	"Gtk7zrda8Y+y7kWydH9xVrTUtBlSCfD5absnMOluP/lhpQoQ/w/o1RJ+AaCVQC9TBI6RRyf4QEGOimm7vIXflnJ77MCYj208gV/k" ..
	"sZD7romSUW9vlrbQf0v2q02eojGZZkbZyD6WXvbCLXr4gdiY6Iad+DIYKZKnPrId8+eKyxowwJcq2RCYjrXlPSJVlCZUwq4dYmiD" ..
	"NfVv8F+FK0tJVwAGRWW+tOrHaV6bYjlNZjgFfTB+JJaDXfjblzC1oDOlEksgrVrD+J7YcXLPP7cxY7iWuAfpnJbZu3TUe1bVqATz" ..
	"WR1JB9N0gmdmN4cOVDPGVcvFFOqaOqoVSnDFJ4rdBmjBst3SVt3xcwm5kwIUWHCsWZqKPzNTtyw5FJBBTgbLkk+J4JHV58dYhuXR" ..
	"eYfVAHl0clVKuoeWMphnBgY+4Q/zA6jCoX1p2QWs7CfwkqcRVvw+Ryeh5sUL5jInixQH8717xdmZNzNxUZVn5Bk+7tlrx/F+mlsM" ..
	"DWywOxdGbXbs1rg7x8tKzdXToFU4a/1ol/Fb2xFfZZc5t7xxSZPdCfqkf6fddK8Bs/d7TO4ORwpg/MV3OWmDmYXLRxeSG/Xqpo8t" ..
	"V3lfw3hpe7c3NA/BWe7K3HK04C4awHdDRIrkHlm0M1ijUcssXgVSlvpLUVrJxQr4SwaeZa2OJUn/fzfAhVegLcXBf5xDM2ki0mBc" ..
	"Cb0W1O/HNzbAuoFp0AGoTghEl5WwfWFP2TnlG+bUGn7/n6tlj0UD5ehL2PQXsKZ81UcS9jxaTaRrrnAh1WyhnruSSNVS10C+rP7C" ..
	"dXDlvRW4t9eCszHIbHeoYDuT3oks1yNxFA1Sdn7+uI7hMhK2oSoLZTwXdWYEcZVAJOtJFCgse0+rdsghC3uG8pI6ts02jm9TvuDB" ..
	"my0u8Ya+9w39XLQZGoQMDvQoEenAmvmjiRfAOC0Lvo2zPNFuD+QhQOCB+cuOLXV3a1Ht5rzwNdjdYtwWHtFDabN2vfOZzOwrsMe9" ..
	"DAxTmiOZLCpR2imDoWiTGSjoObICt3DCFXJdAD/FvUJMdNWdgxooUv87EK/AJukbs3AF3mIZU0UY/nbT2QlH3inr/bmFWao99hqK" ..
	""
local PAYLOAD_P12 =
	"xRPfh4iUFfgoDp+rAIJryvaku7NPkJCyt9wDXt7WR/UXaoSgQkosTlg8J7/1H3YXeFnrc4MX8/bOHgmFh4MFWv/P9hjatUefP6Vf" ..
	"23wVSpLWjprLZnkcLaJWbAhm+Jn7+rkjPrf8NacJsQkHR+ZFXrhka9IljmM9aJnkbNo2CWrD5qgT6u50tBgiE/gksPEqp934itjz" ..
	"7uyUgsA4O2bGpEj7wfMKUeTt+papno7LKny8umAy1prpJOaRzTTus96LpzEs1uCj8EZtyt4yF7yD2P5JALmIHopruDtEmdldDuWt" ..
	"CTC8NHvEZVXPwymG92p6IRir/EuK+O8RHKuCskEhYi2SF8vibXd+10BEIio3NFFRANjiyaoGVda14r2UTshdb485xHihezr9EVy7" ..
	"Ds5GpqbiKnGT8R3mvABHupeJsFMtnKdjRPFhaHunQSLAejr6oTtQQIosxYn8BtB7o2d10q7V1GjyJ3yVYm80xosVkA8GE9XcfFVh" ..
	"EMEu5Wd5fY5vFRbWjzDbgox/RIncfpWfAh/VAPkNqXMZxR3LvYbAh7DgJJAM+Xr/hS9oYXuyKi/IOOodCrJ4cHzqLWgpbOQq5Nyn" ..
	"vSlMFcgALLjLjdUCX1f6ogvC/9V3t8+cUeqGKgTa2SJzghopKjzSxR3l+qRKKErda2FV7t1ljlODDFsUjz1ab5zYa2Q7uUkZYBgV" ..
	"cWeiHArVJxZwXQOKO9CfYvYk+kPGwZ0kDWF3t2dwFaxN4RAXH4a6vdiadnxNpJW/c5qtwxcO07SCrpjZ7xp4inOPALhnB8uKCCoH" ..
	"VKqgId8sNheTJ/zBM8ESFnkijD16dWgXHkC5bCqrtGirO1h8Zum9BPAvPdQTmgDRpXKj0W2MNNP7rzQttnL6hqvmaCCoZBJTPiuF" ..
	"GhS43uxGQ8mNLElVtsX0emeh9UPHo9145UrxLGeHaK/chVoded6iORNbr05u50OAKmoXxPf6TIau3jtBVJPNnmlGDlCuG99V/qux" ..
	"3TstHCQzS+avjeIr/BLFj6hQJWOwCb5437cPylmZjMLoeiL9CPQNQwRSO3kejRJDrQuiWBmI576B2cze6E0J38xBVWyFY0CzAwor" ..
	"0zp0O0zx4GFpQjZP4v9izr5c7wtgzlBtw9dTHsqF4IGMe1YzMhdo9MAM1o7/MzfFgaSYdxEeKUu1lSYDFMnladW3hsKSmEgHJO0A" ..
	"sjNeH7lCjf/LXTwo7wCT0SZYy27jwduNmR2Y86z+Kw+GLpyv8f5bjydia96LgCh+lMcnxZylcCCU3Q2evzuGc4PmpThnGSxIVwjR" ..
	"qCM5oE+H3Av+LCSJ3Ln07oO2eAgTbZ/YZlYStKBTq+ePnTzz6Ja9+K/eimAVIuVgbXwjkzqK4stQ25o3H48X9Gd78b2WtJ2ogXGS" ..
	"BRYBaNTPf8huZpbeK+hYeSz8KYazeOCZsD+oWSP49DnYn0XKsCJzl6u1o73MElKH3SgrwJTBoW9bkhn6SDeqQWrp5TAXq3BMKmkJ" ..
	"1Qrx8+TOY5K5sUz9npsx4UXErUdeTBlo6yYFSXLDPpkmW4A8GVGTCAqCGP1BUMuE/Rxx72jm3kdYNKvhNm8Q/YJRlQOSzlv37X+r" ..
	"cM3zmkPc0itRFuWk4fMG0XJGPBExGwdSJS2+zbgX6dJgIVP28yvxYZGBCcWbEzegPOgfJFo6AAneqS/JC/ppddfCPdAyQMG4Rtuq" ..
	"E4/4Nxs/4xxY/zCOAICWOEWHW4vULUYNGFWhum9NCkNrZkn6Tn2Or9Kxdh2iLsALcDo/bYSPXxVgBAg4YeVS2upgFDKLPRxRYMgp" ..
	"H6I91Qevot4tDyhEYZZb/MnPr4Hz1bYERQM3X10hx0M2bRmarJS1NUA8QXtZpjKfPsntR2LcHuIGl6Yr3W9Hf49aOrREmOC9kNZG" ..
	"uWeS96/Wgx9G8y1midQOyZdniTybNpImJpIhoTxUx84/fPBPVdRmIINwsA1CDsb5cBuHjSFQ8etvVQftJz6Sktb49JAxfWYdCp+3" ..
	"/JpK7dg5jwWNsZoH+K6uHqRQKXtG2FKsXRl65HuWEQTgrLaBWihsewaeXE2PTqIMEI46ZfNnmypNrDVdhVM4LLMV7EaPFeW5Qf1I" ..
	"k8dycT0/kqyflu1tEJGBVnCE0So/W99RiiTSTZ85+KoV+8qkhhvPSAwK74L6gR5M0axPwWTbbwJ8d752gTj9uU3OJl/GvXH9rNgU" ..
	"fylj8Gd510CX8ESCkhRjNVo0eZeThqg9oHYfGXzApfTSSVKlQZ+bhpU41zIB+6JRqto1r+3QHic8dIcNLHFYmschRSVQwFD4CPwB" ..
	"i284Wxi3soXI78yjB7baJCVHc5+BoYKQ2THtHW3nVhPNerV58e8cdV74WLg522dYKS0nYBC/vE51waC9P1MzI45eev7N1HgtadZc" ..
	"SEUYAh/lwtS+Co0CmardG1LLJtzmHSCs1oXaKcoyA7nQJ+DJUHK+TPdrZqpVN3t7bg1TdmW7BczYyYhlsLs1EIv+7kB+8j2RNKBo" ..
	"S88rbTId5YRmCIhqHI1sL7Z/HTrTzELYfLloN2JBDYm1AxrE8M6O5mXMQzKVpuJMFfpw0Qp7vReXCmT/R4cVYAKepEbjg27hgmRf" ..
	"WRYtYKvOK3vr5WXln8qhaYEGv4j3zLj/VQWNRBUNZy46J3bdj+EsfbVgwHVLqBXxVpyj4Q4SqkUAJQSmC3j7iPn5u1+Qa3yRYhQU" ..
	"mR7fJRvast5/ny2lUd0a8I1U/OMRE9Z6WjiW6z/V15rI9ncgQwSTHXbjisce7qn0ed3afuhsg1aTkKiQMhTgRh105BsYNSAJxC29" ..
	"nFq5C66d12p2HtxGPlt9cw/j7XPZE+wGskcKwsHXYIpzQEQuHP+jCDixA8UWkTw5P5FPsPnmMv/VqK725X+0Q1GZEFxKQjeqN8MK" ..
	"k9AjWiThuUKULN1aaaJNHZUQchv8TbyXz5HoLoNa5+Cr0/gUHqMlhz2CqOCVLLv5CD2/HlByEeFgRoYuOn1+SZea2BvFoinspExU" ..
	"SN35/reXJgzWCCfHR51Q4+P6+xwTcH+J6L5y63y2YUeRJwPyQ+3mq10MvsIU0jL2MSEvUe7AEYoXqodU3P+6u4v+SDreJqdPjCQn" ..
	"8dtvh9WbBxRfmenpkeN8izW33Y+oLyfCB572ETiqp3XFA5fiy4o=" ..
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
