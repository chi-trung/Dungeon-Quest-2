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
	{ seed = 3626797799, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3629443825, exp = 0, plan = 0, hwid = {} }
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
	"zVXn1zds91W7SRXhL8EKh5Non94O3UEN2XLFX/n+/ITEOE9Uu19IfGhWaDxTuKfaOA+udMbH9GTBif5sdVbNpFnG/begQhM/K+sz" ..
	"jCdWWzdDwvxlxLfGL60DOc6nchwGku4JdOxWW7YIq4O8pvU4ncz9qw/5VdiGT8HCQmwVYpVNYgSnj9RZ3lAscG8Z6L/tvTU25QYB" ..
	"EQ50tAE8XQdnd+lRIdJHYEtrJYaw+ncJ/rHfRDhgao45dD7HrdGJtEDHxmERaRzJN9pFA4ZblMHEel9NQm8ImXjkTAUfO1kL8gFC" ..
	"pvgf3XyS0ipgfe5+8ZAhkI0Ed4pFmTTggBjbokebv7Rcy2ds7vubexvHvz7e75pWUO8ItAlEKlwnj2AhPQKrUe/m6nWmWPN4yfxF" ..
	"2jgAz/xgTGfEJ6W7VksvviLhffSFf6L3BrcfZMnTwDYK5BxWO3jKVYE2akWbD/vIBvJhmJr3qpIRWCxjDS9OdyyNYolLdoP8kto+" ..
	"72tC02q89kzaTL8U//IjQvX2JmX/s1cyJByp+JjzSApRclMzHfoGqVZEZuSfoxKNcfBDtznS9Bw5Q/QGIEoHYZjeSrPWODB0dmAr" ..
	"iziE0fzehMCA4XuLUjlMoweORMrI/l0caBuPQIqIe7YjAushbBGcZrBcfLu98jDNdTx/ZLX2KccqrPJ+STUyJnosNbGnbaS75g5x" ..
	"uk65m1CJ9VikFdw2uTetBwcvbgd0YnZnNqr3CPRGOdj/04pC8AmWzH2oOZubHgqLprEb/L1IP1QtDWAGbHLXER4DaXeShhLQ1aFA" ..
	"gXfFoSZxwGSHzs4Lk5V5i0XRx0zKLsRRDBglkqxccmW7Rz1Y/lze3MDlL67NnfK9HqPlOP1P3++X002uLxm1WkzwxAo+Yg1mviaX" ..
	"eYhojXpXVYfthq7sSTOVOL0HtGjxGPOx4wLnV/rsfNXY0cN2LQjj253EF9B5F+f21CZSdXEzjZwoU7rzcFL/GtX1Mr4Q543JBn/z" ..
	"LsP++sNIV/ZOqGsDY6/6hNj/cU6hZW68xeAzFKvaLTDvhoU+u52+OEZn9nyxl0zMXbsXmtyJXahhgXMbntoRr9MqX77poJIZkXRE" ..
	"47BlZZOJBcyCLQXUuSbZtZsLTz4CZA7zDFYuWhbjqjvU9iV/gg7iQggPhVuBm/+oNLMFurTAEJy4SSZ6RBD9nhEhaBAM7IQsq4KR" ..
	"FAQWhyxUAbpECcugZFX6N1GLPKPqvCC4ut+AdfviBI7GEshmOid0SZOr06n71EfIgCUQ7DIbVz8EEG0Xnf/79Sp75W6iJwve07b1" ..
	"vFsYKqvt8xF0nSd8zLxJB9eolWT/M5DY2wJdkvVhoYdpL6NOSPBOOsi3YcOi4smLQNUodqwW/kx+0fsKCcvPpL2RfbbrhJx06LBb" ..
	"ttd4rZFHO1tFHUmgaH0W3StOsw4kxpmmDxGeIHCOO9EvnkvatCQogGCTN3MNqpIKtvWZoNuc1dQOWvpWWDm7HtUMpyu5B18llvmt" ..
	"v/FP/6LKHrVt40cbncFHW+kOIxf/Hu4vBfatT8lcKor10IDGCth52hjWYjP0zLVrFAuwFZH6GkOV+cbezx1CXBmln/OiefUpyUcJ" ..
	"Q3abNSCa9P/gH1DTRnURabeg83F1Y+0oBOtPYfNoZ6icFnrWs2kVrKgcYh+pJju4a6aE+LRUf7lcjpfrlvahYCebtVC5uZ+GBXkK" ..
	"mJELUWFjy9nincqnNkmDoH2VIZqoFuSlPTvMZByDa+Bsh6iDFMWAvpOvRQ8wpEmmcXXJ6junXl6WgWNiHvSIGXoGYYQhZciWzie0" ..
	"6VvcFl+ABs3QqON2hPQxapA2eVxK1t7saNGaVBe6Zoby+xeLMIrOpAZQuJC5hHHm/v8NhWWebnfEtYFNtlenQgTluekWMKUaWNWi" ..
	"YIBFUJdQyXp9gmjqXssGzbDbyWc+9pV9wOgw2+JS9rBTUvE03k4tPb76jAPE3qgqyFVg/diSgX9rdow6IfEuwMI46c47sX2T+ZKe" ..
	"rmRB65wVaFjt/m1GtjvaB3g5pckccYFMMHrpIhWH4pW/lpzecUZWP5OSOYR25INUdelZYitp3O27Ukth8o/N8n4jChQznHgR+wSk" ..
	"bumRwbUnTFaam6VVcodUnbAfIo+/9IUrG4cl58h66DyVU8S00TyJj+Cw+pRoTqmC0dc1Gd0sAQYlkpKtVKkylv2KFVnGoxT2r9ZG" ..
	"djhyU60fHDk1oqJd1+5L1cIJXMok1uUm9Bqx5tRM4uFDFiTzxwkUHWbRA3ou1NQQdUhO/qgbncJir7zCzwk/qxXRaNJ9mb4N/O3/" ..
	"62rL4G9VWY6wo3lazUn/nmACgMENC5X35h4ZheAzRvIN8ZfirN659mHzzXf3wNtC9d6UWzHoQFEzwKDdQ4T9yz8PWnQgaFG5DRfR" ..
	"GBMg9dctw/Vnp6K1Qejl/TI57pLwS8s9LCVdEzZZHUXjzEKzNrXnsTbxXuPAyLVpOiP+9jsv7QmP46jNTA6+gxe/lQd2GWKCu2sV" ..
	"lrsSNCRI875cFF3vhyC1UJmGCdQ7GzJI0l9dLb7i1ifEcEvRNziTBxluayEaQ+XQ3mpD99CM8oPk+y+AaHRCXaMlMGhktxsRgkbz" ..
	"wroqBBlLhT0Hh3Wc2A3BA5JB5CRW/c5Ek3xJjInV8UYWhF5nPyzqUu2mYVO2yg+MHtXJUlcGM+TV28AfCVpJLs2A/CvbDts83k8R" ..
	"D+oQTWU/jxEfUrg4mx1FUY5Au4ESGHOXSMKCwiyMWbHlsfrt9A0cVuyoodIzacUZ25oDLgN2EsZMkpXEHhCRiHDrchVTi382kfZ7" ..
	"abFKchxsqZtIOX85sAZveF1nmQzP7hLCpRx8ZT0gdlhchPMhXP1FyYOw4NUrVicyrs/71VzkSH5SoNUxZV2KfuKi9BTCxY3Pd3fm" ..
	"QQHw+0vqvP4agWUdeFQBNmSxiqu6SV161G+lfHFaUTg6VUNU7aVEr25kZrpLs75wYxG/H2x4XikGPR3ZOYw5AyRY49LE5fLK4L1v" ..
	"bLz8ECQjzOkVUszRVtWOurIbein2rX6gcr3c1H5+sk+O6kat6xFJ2/zDuQV1yRmIMZVH0i/NusQmseWpB9yha1CoG1tP8DOHJbAY" ..
	"vnt75M+LUQ7cwLqr+ogQsRq7jd7QIhbRBtDqaq5vbofRjjyQr5pjMhkJnmF1GcffQURPFk/uhWU/G7Clj+1k02HuG4RWKTimO6z7" ..
	"Zj7ZH9gAgAbU/ncEsLU+/QmuQumTojgEEqmduoc7r3TYKQuVjwZ3U0lg6aV0GgwzWdNXGqk2DtKhnCzPHer+Y4YHfPy8kJK39pcs" ..
	"kHq3zHet8WMgPH8IK9AtlT9RxARTwHIeRr3a4PfmHqGenBG2c/ERBec3rXIACzYj3qtv29fjs6ArTDc9/THa+/nDJhf567hsw9hU" ..
	"don7LeHO1q7/k1TJjU9kS7NwVujYR9XOnjGFMkT5dPIIOyxxrnkC+bDbwKcN4yyjEASjVUa9Q3FcKTbsOyvMGn3Tj7XgjfYWLIrs" ..
	"Y+SPs5YRyaLI1XJckpSfFJih9mKwVW7mGD73RZuJZDo0tRKvExCo2dppqJWF3+Det87994yErN/YkhflViFsJmQ81KfJX+Rhg5ME" ..
	"IUjH30EvYlRveJdyBQuKhc7avn/aXrKbpXHJlQu37Na5P03mrl4D+c0r+Oa8qMqSNp6Jqkiqgsb1TKj/JVOakMGstyqjjK+1wYd1" ..
	"VqqWalag//o3p06z0ChOP4O10x00J23+hr9kn3TdIj5iXdRGWMUOn7xusBs7BKvbRQ/D/KFlUt+sX51ZyRAaLsQgjWxAACkBi0sW" ..
	"dfhfAaOjpDW2uzZ8ZZ9nZPUX1v8DqfHgau61msOlCRnsu1taxf9o7J5Q4Fhrr1WeezLtwAKPJLV+nmqPUEvdzbFHvZQCx2OV+UcZ" ..
	"hXTjO/5gKytvh5i3GpIukklwG0lgAr/WiSeM925tsf8iZO+/LoBd7uIHL8coqUPd/efOxQXKfcKN8uc03rH2cjeeclrKIDzPThME" ..
	"aTPcHO5LK1rC6bUEejsOn3cxgiiQNKT84utGIfsC5VGu76qC4AD7KuiXEjkaBZBiOveQI1/JWMBqwePYp918X/NR4shZkckHpEyQ" ..
	"JFH5mnvh5AfW46PNfMvm7Qad52RQvm9mbsgNSS4kVMefOfGswA8b+yTe0/sGLq4j/TSrCwsBZyE9vo/jlf5FMBcPm4sBSO93fkpr" ..
	"4SSG/YZkLV4ew9BNw9LKHkAudhL20sCdzroXzgXns6HlM5gSBH2xckl6izuUlKwBwpcWhWDluUk4s1AiQ3UNNh/sLhwNEjrSb25e" ..
	"G51XEXN5klkY5gZQt9S57Wmee/0wHr7T6vfOQfPm2TEPDS13IsiLckIWS1NgiRhJbOyZ9EE8jxwMcVL9Ix6q7lLUhuwoyC6Qv/9O" ..
	"r59dOl7/iylYSTjjlFEN8JhSBsbSCHvtfg2bAWQ67Cq0QR/OtihVS72D/sNvGzbOF+KuXvlde4AOOtOyCneHfv1xdH3lmGgLdge/" ..
	"vzc+rXh2sGSBaXn/iwVP8GyTw5PNyq4KSjucCtLM70r8n0lqh9ZzEi4uQARKO+yR++CtsUniWd9Uyw7oGVGzWdlD+WdtmeBVueWe" ..
	"FZK9esmhH/lxv4xvdBQMYe9I5k0+yCa94HxEGhXMjWmnAzCZBI+dQEUy96qHKFkVVIhWQVSvx00QsAZcSEfYDBSdBYs6Pwax7tyd" ..
	"U3yHW0/KesEnCo++ugD5YsPR1poz5/uhYZCoblf+3su+ojkVkz69fqvfjSr8I3RTn8jobtuDTTFN4akC9mVWOvJRjhm95FDpvzxB" ..
	"DI65ZyPfdIjvHFiqFv924j2p5MImyNrPydabyrdNjZ3fsFPPMXOr1nT9BLQdCDA8E5AJiE4hETlh3baQGSxd8gCII2UPIIv/EfVo" ..
	"+Cj/8XLXtQQxyrstrZyQoMtNZAbl/GxCSj2cIGBfYFoUtbWIe6Q3IRzgRN0lU9t0VH8kslvNqpy6n1jm8kBu68CJ9p2SMfxpQHVj" ..
	"w9H4Mf69E/iCvV+UNsTgtaQEG43wE+u/vrDskaeU6VVeikJQVdJhZuOF0p2/0TQNDucp6Np6Yndyu0Fo0O9iACxD1DdP+K60p728" ..
	"eEwXVBStQusgAO4sPBXUOr+VVfgdQPR7/H0hEHxPtR+ph3iWYoDFAJVfk7yGjXeWZ7Rz0VvoydMrwca4bFEP0nhZwVSfvnVV6lnD" ..
	"ysAdxSAY4c9nTJnlVJBlq/9IiHJYFG1MTHQV4Ybo8AZAHxFjwLH+04hmUygJfBoXc+FSdpZLzDiJZ+YFuep3DviRPznAozvZXWqm" ..
	"IiARu5Ex7FOInoseGEuxXK0nR7H4ueUErJnlqglt1kcEHBBNvsDl/Qv33j8dA2I8A3g9NSN2NlsGqwxJK470x1lEb4msPSgDQ5T1" ..
	"dbFjmnip7k8xmOl3SArYWRJEAZqpwmYzSzvnVLPLWsk8y/U5mo5Dpm103Oz6+rvZ6fhjnmBVyfddAFMENPJl4yzUg1ova5Jnj7KA" ..
	"OUIleCyQlwyZrmmINBtOAiEZY/gY8jacf6ygfRD2JURoNrXtRyr6jpNLjgmhVQYYo6HjH/s00TVvQCT7GfD4vkEuHg6LDzJ/4FFA" ..
	"2Akggez804Zms1XQm0UPMevQiieRtrP37WXqAGS8ogSnRJ8QQ+LGIAWUl0FDfLsx12XH630x12VIeAsopTaGIAqVaYdMdZG9hhf+" ..
	"QMrgQJfoZ75+FjK2RKCSnBqoYpAk3Nu0imdbY2i+eyHNOt+Rk5Zmg8Q9t3HZhzRJvLJKbE1kFsfcILbYc9Ep/1eP3O2LaYRXU+Rx" ..
	"LjKYfEZUXRJPKNeKf/6SdJ0/wkNt+Yuf1APuv29tLznK1QGi+gm5mvqYMecs5/Rrpieh+ztDCQ6q4RfkCTdcBV/sX2tt9jB4JkDq" ..
	"VtcbT0QrlJgUjSZhiFPIiRT0lIgTgVuG7U6A8o0FB/g3TnPI+8ogdzYClRp1B4vwTOVRB9uCxoMz/TrKCHu/lN770zArIngAS3yL" ..
	""
local PAYLOAD_P2 =
	"bVahqghU3tHOVgKC8E0Jvarf+80k3+O0Mgaj3/QGmWUlou6o9a7n39yzzpiJuNe7F3JnuwpaqjSPc5iPF3+kjfQZ5stm2whY8iU3" ..
	"3i8r0XJSIplp0TTWfI2FFXY6UCsmR63W+D3rgbtGYGaTbremNmM5zGov3CnVRAdQ487BvwRzdmJlKGES5f9wa1b+QAv64rPDoYqW" ..
	"1AaD2YI5PHlDZGZj25w4JdbOgkRNZnzE3cfnqKxumOLdIyU3TGhXzB3/vIGYLEOMd4aV5t3fSDmREQD88tPH6Xi3kt6AOTW6SXJ1" ..
	"q07QkJFv9bM0oT2PAnxLmn3VzrshgGTIqWTs5OgRSJopv3zBT8nkbfV1ifw6iayQM7KjPesWIRcXNZpXD8VgeGT0PmK+gTQS6Bdv" ..
	"oRgOc3DDFygu518JABE+l66ihGhsydk//Y5x+xGdNwRHyXdh/3+jY6t83uSAkRV7suEH9aUv0EvsbmiC0lxNfUI4oqtZgtwo46MK" ..
	"UF1gFOC3n7dcwcHTLp9OZH4GMkd4sQ28TRQbyDX1AjTbpJOY2dMkRZxg2435rE2tgzZZu7Bkziv/RoZziFFcLBeG48Z1ne1YZG7R" ..
	"O6AL3uJoxJAlVrAqddFbt7q+71preomIDjUnlvMQyco0uzeZcUUBZcdhQ1Tdg/cUdRQL1w4hIbxJz8W01IAU7ypk9Jw46pe0LP5V" ..
	"ketz07Gpop7PFepcY0+zXfGXfrLVPgQ9wMA1bk3qvVwoKBk4pcq5emcYGeP1jQxdoU/NIUWj1X74xJhCN3EJTKpuVfOxLmHNktyL" ..
	"a/u97Bi1I2kDx75SvFBwCs8RaBhaqjuyJOpHS9kAo283NCAwjuooXWp3Ym41VmrMxyMeWDIKcNNefd7EJeS/65pAHJcUu3eKexGi" ..
	"/nwg3avXIbZYguqABmCLQPNTneNhJxu1jJwO+jy2gQ21+Hif5J94qezCXpNhzmnMwb+k6kaBOKyZ+KrLPJXmsfnb36R3wtlrguci" ..
	"cvU7jp5P5E+NONV5UDgTHyW6g4kXUrJ/M8eVEEPuzZPBTi+mY3AHaqAKzAFvQ/sLbzHyVhcQJx/H6kEOZmY4vHBOqcA7/g67bkQu" ..
	"X423ybmsAlJieVTbCbYx9wRrqQoFtoBV33dc4TAuTomsQuRQDAB88V457e2XCKrh8veYciFU/SaAhacVjecb761nkvGIJd6pwj60" ..
	"WQuR65zyfLuxwQDTiOE1sEfu260J80fBCmGAOJeiBI10xpuaF5vOoQWUE3GgT51dpWEatCW/u2ff1G99pkVNHUXSjiSOoZaxONTh" ..
	"xQzoiobEr5xRTeicY8tw8UeBUnrPJYZSXZx0leDMj1J42up9uFCdB4sclWXkN4YfRKKHVu1U3drALZQtz3jmz4eLJ/NYW3xLplv0" ..
	"p/5xPLjsIoynTgNXPX6p3ZaIGEKWB0AEhglLq+O9vtDdwSH3JV4UvAFx78N6FBzjjD4CoWWerm9GbwHsxqjTp3NAkoBt6LZpIXCS" ..
	"Zbv4IPNcSeupKj0XTiF7Ecb11GHvmUGkfQpSdW9U0Ndl4rtAeIRz+2NSDNNvM7c72Gu8BWvzPoI63Tf572l0g5acwtwLylliyifA" ..
	"mjgzBfLlcWALH7USZt0ekoDNMh0K0d+8m9RLwQw+vqMe1NSvbb0Nm5Kz0x/287aK0GcMLDMpu18z9uCDopFfVLpRBQ8JgPcGJh99" ..
	"q7DLE7c8BxwEGGRPcOLnpdEphfAWvKqwoq543hlyMYrJhAQ9ArvFn8wb4UxYQS1s3gE9viYVMgnWplZT4CrOnNqzi/45HY/6yIhf" ..
	"qQPvcA6qnAA7eXExk2q3RwZ6w/m5bshPCsa522fsEaUKezFBOt5TVllEsOBKH1HSdpfc2FZ1kXFwGICsyoo6lliqYesvwZddCms5" ..
	"eH9tjWf/Xj2N081+909L/1EgqgFSk6uFaaY14dsSgeomzSyINkRKtB2CY3TkNIKnWt3YIYJl3r6/gYczXggQX6lXAZdIBRfQcV6z" ..
	"l1p35hUhAp/9Z8O26+hEP5lDwQDi0w6rbEIwE2rHk1UhWUPfG4m71kj9fS1nv0dA44QSoLBHTQklBZW//3nkMwJ2bEVJ0Q28AKCe" ..
	"0Kvd28Tc9I5nyKwvGJjWUYD+yw+2KKvBa/nIb6y5vW69AYoyramRx0mFRxugJbFpNupRj5oPQIW71G85VJEb7IWmVRistC74ic/4" ..
	"zLXiUDU+9wq/Mme5FBozqpyRxClxw5c+iwl7Z2Wc1HyRhvEAv27qJz7CssbmveA1vftVAf+OQgdWyp213rDU3/aUIGTYjeh7Xpxj" ..
	"MsNVJqP3qlF8BgPnJfKzrvaBehwL7QX87XvDudTgmk7wN6kzKaBi+AN6zrshrUNxGx2gGM1NiPvxvJigax8lC8h7EWavVWtdnynX" ..
	"V7sHlr7fZIX6DJ7rzJGhQQ7i20+LBqcYJ6dWLVqfGURUTMV5XBvsGwZciOKRlDtI7O9t3X4d8valTZEURk3vYJo0/ZoGWNywZyKS" ..
	"6noSFf/Mttu2PhILpAcjsPsymThx/MSHKBxTguLKXU5Q2kV+Q4IJM73FnR1eRixHcnpQcxO1SG6LXmZs8aIUVyjwPpGhJVOgr1Ru" ..
	"KaVGJniIEKmXCLZbpkGXnR8ArgU+zDjZ9gcJy7uwKEwOee6qlihdoFXeuE2XumX8py9HaqqO1dRrjNUORall+0HNKYODm6+03rbM" ..
	"mhFAOzpo40Wxt2WzJyR4xD0fyioy5HY2zyw75oHk2eQ66aha0ErJFHJkAIytXsZUrAUV75/1VEhYssUKzQC61+DeSbQ+cUjnddpQ" ..
	"NeMywMhYMi7/8YgbxZ/00J6xFcNL5glkrMbmrM1oQTZCX6UJvafUN5Vb8QcfxV8+0xvsgj+3g2Jh7HF3EfnzKSdMneb3pYuYc3UG" ..
	"YakOIWR3GVDZdSO1ksARNfPoBz1cMJnIpRT3G1v+avSbled+uaMdeSVR5nLiRy5hJziMl9U2eegdBlcA4kFwvoORg4cekaN4rIkT" ..
	"RdNEVidMbWO4hooxiBeeOnz18+4kKT4NJKil4fqFHM4RYjV3/JeBmV59PwSUr7ZDosPQjO1BKSdtPYr5mspLozz4WEVg4MZSXZEd" ..
	"Gr88VwNx8NyJHvsJi3p13wCwolm1REgcIhk+psvLBHLsf85iKai02qWDaJ+EMP4xeboBPXqpETTpMGBZNhjVZRMZvfp/RQKNkZhX" ..
	"xqh3zZzFisvukFxITg0Cl+VeEwqF/VfHZym+sF6r+FJMY6ap+x3Z7MTuMjHHlc6sgSWjqazpY113BnhVpkKksxCVNAvC37n/vp6w" ..
	"OEI3trUlI0MGLHEMkR20BnaOuAwnGhhYcgM6dLQ4uTKF2LdMI9GZ9rX+dXzDl/IjD+U3n0+vxyzHNU6/NHYBHrC8FwSsrasyoorS" ..
	"EspRqoMizuQAPfQxhCwGDRirAJC/a8N+MomQogLmZWVWR0Kl8rUAhWmetKQHmsD2gKHDnYYvm6SNYt04cDVjH6xX9GgNl48bjA0R" ..
	"58PQ9RgzkoSmelYEq/wtgqJaYcTJS0Bb4p+RRDVGN46YBeIYY72dapOMrvYszzRK7EQPJ/s9EYF2jlkRC+UkeTfVXLEi5kHYCPd2" ..
	"YnwrvIqkyG9ub5a0P4+KO5PDLngDs04OWjyLgHADybY4+niKXW4rnyu4+5hd4jEw1EgdJyqN4NKtyqBFXewBgmITz2/9Os1GsYte" ..
	"2Xp9LLtmcsvIAMk7NU2xvZuFzGFhEUS+1e5hXOYnh9/rx2ofVUcboBoGtFL0pDzfsjiDMPDKPmyoSAwCilOt0fR+xo/BAL5lle40" ..
	"nTxcKBEqMAb3YOM2y7ghlBH1xNHxongLqN2uhFf6iDvZXNUK6YZ1B1yi6oRSRgEMmZeOUkYAsH7yjYcel66dXhdy79CzjGPkPZUK" ..
	"ikyeR+ZdkJMoHuCPc2e72S+Elr65Wj2Wa7FDWPgBBIroTCa4gmD0R2/CqfulpmLO0ATz5c8ToyUbklpnU6R+/y/LlWu6Bb99HDtS" ..
	"Xlnqyt2Z880L+66nObMxMvOHH0hnAwX8rhR6Tov4RjiIo40b9pDWPEc3NODwzfz+cJ1ZFbgO9X3rEYbn+h1gmHn4GWDNdqX16K5g" ..
	"Pw/5o4F7t17p+L7/ePqSiX1T+3ndDApMTUu+2DcKAtiNuhI6SuEAFHNXiiaywnHxYJOXGSOmeWkCI1rMH5WPWRSUDHzpvvMdxhGa" ..
	"fzvc32VN0CRs4yYGiqnNXRm2b+/tfC74Hl2bkQ0Wa8ZRQM9faTk0kZRZPoPytmRc2Jm+FJxsF8hRSUFNJo1UNDA5FuEdh5EPSFD1" ..
	"tm0u01vOPvl3Ub5E5IhjkExUFZJzLkZ/sM+xVNqatSKkeseMrNTJZm0sSdEUONBX2ivhtyC/WCuwwomU2AfuaDeJTew8Y0tIIdGB" ..
	"DdWoyaw1rv3mqfl1o4+F0rKORPZUdaavtkCyyqr5xoIL7b+c5ne0fZy1bs5O2zMuWzhD7tjKLgh+HmKbKkvGiyzzNw5hVtqiB2Cs" ..
	"19CMckFk8d/MBNncxSFYlrwyR5GH39QzL5WZlzjES6HwiwlMsTd1LFPGsC2Vc5rOpDgjAu4KaY3lhTla9+chxEXBnY3tt5eX2uCm" ..
	"DTaCzUdveH8CmMtTRJ7BRLlYMs3EpRp2gGNyezqwzSPFLsRWGGbC4sEIWcj1SIMWvYoX6jt7JyEoN9H6/P5ouJGyQlbtTUHixXUU" ..
	"wL5wYXUG/7cvMzQQ6Eu8/DXsoPxV+YhdDg41MzG9LAUB/2nRbYZa3TWoGiPs30HmXtGcU5hESzbZjdeLem1x/rq1HMwO0vlseR59" ..
	"ZPWGqvXkg1Y+2996X97BkcRSir/K2fc+HDxuipVufq5xqHEqkqLNdXPUBuThpMxjZwljVXm+qtoN8/yJxXSOIxa2S4IYxabFmyxM" ..
	"m2sqnSMu+z7dfqYwkLa3mqy4jmq4mV4E2N4doPHBGr4tEJzhCR4Y2oQWBCREzZxOg3qXyA6gA3Tm9WUpiMSSmVnD7A8tEbn4qp9E" ..
	"uF2vV2dXxrYSOVgY7hi/E/S5kNrhfOWfHl7Je5jLwR2Req9mOQeC++MMtOxQd7o1ABldXOTDIMiHWt595hZfssEmYzZkdSS0tUJm" ..
	"PGnNNpLMJLumOPd1lag7/pkKuVpCp2uDUhlsTrq+4r7YEeFtKUsDmGUFH5mhSEghcQTY25ePcMtahfeylC2DOLCHcPL9EJQBmHak" ..
	"1RYdVBSGBNW+r1C8HNYu/M4Mr7PjvuhItWB527ruQRX0FPkSHxiVGeeLRNHU1J1Aj+LSpGG/yM0uYpJAkDUk1QuvyImkwhIRriTC" ..
	"/gW5vbX5lmhUEh+X8qorI6/Nrs11Bb7Kakfmv+ylbZ90gz8dr0mRaTXAaXA6eLlzvKm8HKx0cxMM11T/C2fkfh8AFwn+iaiMXGbX" ..
	"5L6SG4jzTJCKrXaSvp6ZW9QQmC/WkvHAvZp+q/1nmRojb7hsUni2jvccdaXN8QWvi1dLMZ7200JgaDjNDpfHKrdFsMh356ozL3QI" ..
	"2tyTU2+4KCI1O661dwyx1xVx93j/DcSacpmmjUZfcWQlTEpHWDkhao6WPF0U0SHDCbH0zFkp66XvI9peWnftlTbgbVdB3nh5kfG9" ..
	"j4io6rZt56Ztvs6XZOlO4XRQYs4U0zNlI/q1nIEeUpV8lqTVUjlvpGzHbNe04e2J1jwhDofi6+wVSwg5zUjH5Mick8YZhJplGvt8" ..
	"TGJAm5ce++ioctHUxmnit31jCMc+i081lHDmBQEpQPuU+nNpjOF4OqflD2wGSmxcU/qu1mIj3wOdRCyZejZQeN8UWsCLByyYO2n3" ..
	"bJIXdVbbVpz/XYNg/2zPk9FYUDqAIm9C8PsqdUlBZCf6M4/cg4LRAM13BfNhGroqX2ATIhw1Ws7C0rhxDTj8qtV8VvZCta+W/Vgp" ..
	"Ry+gvCXn5kKDIMFGio8JHorF/g8nISEAo7XohrqxzxP7nybB1XR0n7yeOptySnlVhKU1NHoh5SgUpg6VV5iU1Ep+yvwhHSqO+X2M" ..
	""
local PAYLOAD_P3 =
	"2NBBbdrJ0anYlQGo60fMqjP5fpqsomKjmq2vHeLa89I3OCzMBImTUjcKYFJ9X3US2VopTqYQFZqLsb0nXvQwbHImQD1hjezehMNR" ..
	"WF/1M8zqJQHpCgcVfbBamlUVKrK7dU7/HMMUT9pNu7C84tYm0Lga2hpttRcIQs1f5lDYfFExfz0ublzLbJWA9IifUIK2X622/2Ur" ..
	"FZy9WgUuiU69q/BLuXvi8J4b7bgODa8dQBmAVAOlwqlgtfRxTGpG1rJyQj3rU4+CfLzfys2vA5lRBMR7UQPqir+c2AFg8mvO5Kft" ..
	"eVUa+RO2p88ggyNpN+ZDysxcWusoWkKmrKWdHbSWGdwPUZ1dygcx2Ke4j7/+546nm5W8og6jTc69e2wvhEzDBeycHe4N4twoib0j" ..
	"0nILLPiVc64k9xSC2HwPQCGXBSu+CEQJFr/fQdtz+pM2BORUD9NICyxuXUlTQT1t25OybxfNp7T6n8uqlL9FkuVOJ3pyCx8tMMun" ..
	"0b2B019NmzFy1191mEb20XMA3KimrxNgv29Q0rNWk+vFLgvZOlvWJ9q7cuiEc1oUuk1tB+3F61wpYT1706aJNNlESCB/kWdWGH4N" ..
	"Uatab1lTf0dM/R3rOk2rboQCf2BPP0ZxvjQHcZSi8CUFc1cflp/2wqGfgX83CYw6SdbIEGiB+wh5a844qtSKyTWSYYueTcSE60W7" ..
	"CsTjV0ZJfmkHaBD+2/0vqajyIrPD4DWlxjE/OLZ7W0PjZh5y+eAOtcImQob8QGilzILWdBh+FTMBRNInanuJ8Bt0A/1/3duJ3Rqt" ..
	"74tmWaStVGm1+EhOK/aa1AWNxH9/Z32ovSbVOgaRe+DJYcW5CNbjAmwKkUZgZGl3qBH2JlHGj2WhhDzz8NBtUFuRL7QmPrXG/NWO" ..
	"3Pc2DYvAMY03fiP5rzEdXLjZE+/LBtq9Zlv41Z6M118JRdGVGsDqZPxNTZaYNEREW7BFLSOTwvcYLtlIjhK2gs0UrSCMuZwGVSL2" ..
	"vWRZncRPnDOhXq2XLQOlrQNeyuqKqbw06lz/nSFgahYy8m8bo/n6t6qCOjJEq83RfuGtg7SJseguMsO2o2qJpvig0pqRk7ywk3oP" ..
	"COn+O7Bl6YPULqgCGfY6JRxT4Cei5p2X9wgewi+ndWUb8VpcrphJl5cHR48oIuklDhqKdO8lijU1ENFj9XQoAaK1DbD3EBZMho7g" ..
	"o3x6dVA1WJI449CW/TuDJ1666F2Lr286i5SRWnxAjoPgy3bL10Vb7XH68QoIHQLeJ3iIG5Pyx8c6F9SAL6rV2H1vc9RLem2P31mM" ..
	"6+xs8qE/cSIGTPlidtCDlrwvTDiK5WL7RBT02RKeC8nOEFBOkxV1p5GbmtV8QSjP8/BeqnTD9so9ozdc9bVVoS/scYj4uycc+OiX" ..
	"EFjuDChsAWCYiGV7YA6veaI3KdYP31XQvpdK0pKr2bVI2AB2iO+gC5npwP8MAQweqIZpHqJrM3WtkNIbXbE8cxMOrmsvfJFU6Qej" ..
	"TVr+nKbXcx82T+BGXXYQw+sD/8IzfwRykLY5uaXGjqKtncP1F0E3sSjbcyueFIAU8BeaHKjKVxADdoY7c0Kl4R12exEWhhcHVzzZ" ..
	"LEw36Tk5436P5MmPeUDWZT4AQpwwypv/CJ9qu6RS9GjUPmnKa36Pys/rDb5MT8lOfDfBIb0CbQH8gxCu9brKYiPvwu+egNicO64B" ..
	"E+iev/6L/4NYesvA0HMRfqtXwZB/zKdbF3cMdRg283pjBG2aWyWmaM5kHVhjyf3mSFOehaexF3/30e6L/uHqMLf3NulLNAeo0xa9" ..
	"0EDazRhW95d7JeWql4nilqEKJernkmo7hgOVLzUrBC6I8g+k5HbsekD+dXORO6PfMI8TGvL+PDXweb4ZpylsjWYR1bGxea48cpnS" ..
	"s2T1FVEJl3YJRicCL1vh6Dc4ffLp/8n+21mmvNqeyh6mwzWg/4lIa54LZEj4klOJF2LeNWp5jUmuk/1DAZ1UV7JoQsYcqZKjwfHR" ..
	"aLu38IgI2aWxFmQuY7Dh8mwbTrTqTIXVDxB/NeWuGA/REQ1Tp50BeRk46SNAhlYP9Wy2BMBL7PJJHic/k4UJ2+i3Qh1KahsDHFy0" ..
	"06FvkaMCgsNPbNfDAB/b1vxT7DM8MB8lnL/EMOqOm3uJUjXO4qy/feG69bLj3uOTLSHLKq2iwIQ16hbokjUTYGdsSisfkndw4HER" ..
	"Tmx5FyXZccZPtOcSqXIv0wiCXjz3lTKkM5IOHjkIdMjjmRRRESQb8p/i7Z2xuYU/4QP2XgH8Yqi02srPnqHRfv4AjCm9f931IPwy" ..
	"7xs5Z+HvJIoXAdSTSTAZruzVAjYuKSaUMgfoh5BVAK+uHTF01CdbqrPY0yADB3SjiEgBIgZA1YGeYMk/FDwlyM6TCzSxbzH5fqMJ" ..
	"72dCHunwncD3i6YTbYfD469MuZJFLCgzMCdzro3BZsXeO7tWs9/d95xh0k3HqzL32inVXEx34rGy17jGllbtWWwH+vEbVVv3tC3L" ..
	"U+k9dtpEHvCnzS7tC8FSzBUnYFUjXo2fWIKwmiqWVtI/K0uI5+yrD+lDB940NFBELO/H7hyZeyIbSWk9vkgVYdXv9ioI1iBtmTsG" ..
	"KmjBREShUVlzhnjFql3M2JqRpxjZMUt38hdGqtoSyCU3WagLd0ohgxjFz+mP5MhiQ4lLaOy4YhcCU8wVDhIC8hxscgcgG230LFUm" ..
	"SmJg4ka7aXm6DS9v2yBSW3UGXBzGGGw4i1rGTOtfVvsveH3fGD2kTk1xJ6vZJX94AFObY2dx3/kH3TGYHOxGCC0J6/8hHdf/41KI" ..
	"qDTKUf4DaL2HGjgv4VbY/QOuN89VYiLoS69VlLH5HQPYx3wwsa9vv0GS5gc1TlDRBZBsgTnSXiNkyb5E9MHsnx8/lbTbAzn212bg" ..
	"rc7KzL0tRKO5eeqL1RouMgathk5MnfzAR13rHJVC3xxeP6v9Iwp2yyum/KecHylaTozw0NZSNoh+lqSN+tU4BrC0YPCacXjurbt2" ..
	"OfCyr55HGKPWwkqLbJoX4UVMAc1hzfA0g2Mi/pMdfaM0f1ecbx1q81ewrI65WvkXyGJ47Lo21isHEpsEjec6szA7uM7oVJHtuDoB" ..
	"TwKs+GdRXkz6QLVAjctc+JEEU0jYHvjSfwuuSgPYMF1f6GrdTEO8SqltzJUclr1hHW2+mVF9RwXmxXJ3CQTLyig2o5JGmszgpOED" ..
	"MsLlWVYukCHEuRed15mN+cszMGLG0jCocyxVRoX1o5JBg5XugzERL85ZqSIBN8VHw/udvrBAgwaDz7mUeXwUI4LH5Rnsw5Nb0T06" ..
	"k9t337zUl08da03tZoo0q7uFwPuXxHV7IY4RQCZNrpNx9leXb+SxRQXv+xLSiFrV3Yv5j646PqzBte1UkzYjN+Hbx2CT8OVgXHW9" ..
	"RvMNQOkpMnOjF2He0qYNe1MMB2UqfrpeFmfos1Edx6YsXpNEy+jmZBvelVvTNhuKaA8YCYpdCNWXfgsdBJE0xS/fuoUYYmDPQYpl" ..
	"ryXp60sBMSmxH4JTBTQZ8DIfb9RFWktLi9EmZ1p3xgGN+9N/be/xcWacjveHrvYl4hnSJmI3NdnRujDmgzKWXGDXM5ENRyYVgfFe" ..
	"eSAHfjKKO/izpL9KesrXFJk2sWk9F4XjH88njY1R1je/wCE4VKiWo+91GkjcwoyfE1Xb3kfi4l5HTlIxmtjKEp+CDXHkVhC+6YsW" ..
	"GJmg55YrUZUcCT1yy0nQ788vnekC7ixzTatSLMqecUbc2RhHs7ob9Gcs/gcqWMk7mZdG0d0rwT7gXVS8QWTWYdDlrRL3Sq/BRJFs" ..
	"eSHV7i1w1opD9mcevrZoMzNKZHKzrxdYXZ5Cet/DR15kwJ2t7wn5qJ/J3R1fJSw/xkaQehtSCeTCs/LdN6/paIn8P23EvTtZSHos" ..
	"oug4G5+DvjlSXQ90wHCXr5OwzTKCDXQ7tMUeNtPpzOeNofGHUupfPIJo5E3lWewsLVtWHmp1pWP+oOs9+Vw1VQX93xl0YgTfSeoh" ..
	"/Yd1N4V5CJq/VAberH7XyHhrAb8YfmPg8JlZ/BVyP+l8FDDCpW8uaI9I5NXwtkc9NX8RZQrAhsSq8o+XkvO7isbB7nYNFs5wQ8pN" ..
	"OOvq9Ns8K++zz4d1adp61/LpR1Ay3htVQNq2fW8Dink8PIEa8Q0KHX1sTD2Fr57TxzulvQ3N46/ImPw5+8Zrw8c7Oz7NqfAAivm9" ..
	"WsNwcXgi9x/XARg15YXy/Bt3Amu6m0QwvUVTIYyrYcHnY50C5718Gx9PI9/rr9e3Rbs+TR0M/9ovYh6qIFXZiwgCzScA/iy/+ib1" ..
	"QzNhW8f1/P97BJZRCIuaVDgkVGhZDkHjOYirUeiEv183FcG/to84z32uosPPaVLKP30tfb0T2LxRaDuqUOD7Sa3ciG4KxZ6KPDwh" ..
	"hSBmJjCfxnGUZVlqQo3YIqul6boDKljNTvTQAV3JvEFv+NW4sGMPaKOqlqfJinQJjmMADBUAntHYp9u42qT/pJtYbAGVXwE4bDj6" ..
	"IJGsxLAW4TXePjKxmukdFetgjaf8uWNq3cCN2m1eFeOcENND415eoyAtARfCXF2Gq9QXt0x66Aq1jQDhaSi+OlCA8X3VU9JRbx0m" ..
	"uCIkBnLmEYQpUGKIBM3BwDL2CmVYQxwtkpOiZn9aC1xGR0RLwEh1wR3UVDeuy/K6e+me3vfs2EOij2ciNtFkGDOJxQUlN2wXxf1x" ..
	"IIXu82I7O/GN9NObRMYNqo/BWUceZhMcuRpzWr91CW+Ix41bvm5JpMMnRxIJl0M5Rj6mOcLRFz8nAK+OoNQAQnCwLJpvLFsa0OGo" ..
	"OhxqmxgpAyCzYUkLavz5yfbxh5nqwsFKs1CxetSdx/WetqfYBxfSjsH26RBYkt6qrenYiopUsBFaowmhPVg4lM2Ez2NNiLVUMTtc" ..
	"ussXWAn9Gy1BFVdvnxL/i28rblf8PUZRGT2nt8rJTf5t4PrBmqHQ+rJdlsl7/1e7tWgUeEGiOptLxmpzDr2g/BHHrQsrXxaRlHSg" ..
	"zxiX4jXbkCeBamrNn8048WAUVh6L57DN5RDvy30M4ufPF5Lk8K/CfIZccn+s/AVG1+P3hKCwjzmagFKFilF986ZxdRVSPqxtX2Ot" ..
	"PE/eUJMPDI9ADgUV0wwAz0AQ38PLcYqVM0sAWCW4eQZPTdXQukgncpZOSCvB+OKzFDiPTNLbv0JP8Tu2GnCV4N7OhhgONiGbkTNn" ..
	"xAoRQFhbzqjwS9/JwxlO7DOb0KW1uCw/0JPYlbO2N/Qs61IPJSSQ/YuvTWtI1pvvy3wWoIIbhjptUi2vk9+780Ks+LTjVXdfHX7V" ..
	"4v7mY5t8VnnsFegTRUFn6eI0wmm6vcYY9bzhskHUB9nXaHuz3bjWiXgc30DgIITzgaOtvZfdalS1B1uLDqlyKuVygrU91/2XdfZT" ..
	"fXNmPvkyADSiE2yPm0dfKvDva/QzxzoDUO13fjNGNzLZ3wq4dpb4vP8S7GY0/vNW6OVfmIVXPriDE8PwLb6/Pw5fcZW2p29k3SK7" ..
	"+RVgzLKyKNkRF2CCXFVwH0hxn8yVm70Hljp992wYf9m/CfhHCWBftQyHAj+PWgYRiteEpUZJauA/Q4hX3TBNvIghtq2FyJtGYIc+" ..
	"m6ndHRUfD10KdSJTgIyrn1vHMM/Hkxv405EqAMcDU4ukqTc7QBONyZ56gwjlWJmD97P8r26Qmm84yr0bNeKZ03KuVMd91y4NtpnB" ..
	"bT725gAbkj6aPjItlfUbJcWQXRa3O/tn6vjdxRkouwzOs3pLeIn3vUsJwhAjQqYwD7HJw5HfYQl+G58uGU6HDBjmCQgKv27FpuCq" ..
	"Ht+EgI6rkFipIAmB7+p6gCz+3QyNxMJqCEmRkMkuz4QgearXgMGkN3xvPoaHga1ZyXpfhCcQPV+8WX8h+Co9MOwVN617+d0tdBsI" ..
	"qHYqYMT3HfsC2k/CLq6Zf0C2BI0i/dxg1F1PkaOc8Z9tPP4LgZPC6ykU1wOtSjh60v+pxqvD820i8lkvjunIRiIgzsoZJ90VviGw" ..
	""
local PAYLOAD_P4 =
	"aL34+pAgbblMZSEH7uf5cqU8+eUsR/nyx3sP0yox1C7NSrFMsJt1LEDy7AOYnTumH4Y6GPChpThaYfWPcIt7MTv312LsUgn8uOCB" ..
	"T2eoXhVkXhSSlbQ1cLulZnOrvAUESVyHYbQ8dHA1WlU5RX41sqczbaO5bgTz71WP6DTMYd3IecSCQ7UMdzJCGZ76gOVzwL6iynNB" ..
	"iywkFbeZm3BveNt1QKdRUdILYFQ4j5o3bkiZzv3LpPyadq8PsvA/5vzU5FvaApM06A//AaABys/DkE6NB9hh97R9Iq6XgR0GjTjS" ..
	"hisYwqHjZdI8+bjh6fhFZwUaileBXqHGoOjf6UDpk59MgFJKSwaM8m5x+so3HJMfmwBiXeKB1KGqKdXefImOEgCRE/C0llov81p+" ..
	"ilG8tznbJF6xgOj292FXSrFdNFR4sVLTr+8QLamOk4iLlvyISKvwwa1BDPfoSD5nCvrPFLU8GSYPQ1JntL6LCccG0LBTF16Gflxc" ..
	"A65E9yNR8yp7hHPfeft7C+lhpmb4BgIb/HRH9/ZzDjV2zeb/n8Rg3NrYNy17hGHie0tnabV4mr1r1HnHrtVEUwl1SPP62+k94DAb" ..
	"QypVsXSx6+UCXbjLuruT5F7x1WUN1S4AoLr2OJXAWsJN+8M/FyPd8nEZU+CbxCoicdnDFKuBWzWy03CusgLNn9e+piPWYsbLftQi" ..
	"VjcvOKIOCkDEt+eP3GJcr57afr375pU5pt6/wiLpqaN83Geruc1a+q3N3T4cM4J4x3vl+kSjA/4ucvq8Kb91tKT4hKo/iX6XWS8y" ..
	"BwBBOwxdx8rBQEu4cie3gU+FNHejcpt1BFDNIozVqVW4WOGgp6wTStTrrnYc/c28FqRp3x5ImwIHhSUOD811NnZAgxQNlHHCM+9H" ..
	"sdQYkIFGrnrE+Vu75CVV3HBLadi2cNnnLYcA0bTIxPU0mHFsgD+XBICBo/I47RO7MxVB4eewTuuSQM/esEO+w0p5JfnlM2REn0my" ..
	"Irl8jmR+5zdzL8iqfXK5i7M5OGtX0YpohbhGmfHRW9F5VwBO08lR1WmFQeopJnXzOJ7ovQKNbw8ld8sz0sNSjGP5DS0HUdJ0VGIn" ..
	"XgMmSVV9CfNs3mw9YHC6zvGe6YiKvJ/Se1brzCaLQmh+G4S18mVPMNbaHknCeWx47DZKYv0MZvUl2anXAnawo3hqmfDDb34Q24v9" ..
	"zYBG+EaZQrATVIJJCv4d9+OkL/GkLxHsYaIWmQPNjOqp1KNCor3F4ZGaaO0fYo3DSkCCiDO2p14DhGpmhEMcUjXEZFwhfUHxwi3E" ..
	"7/9QiPb+GN1jFW4iE6HvHcaXe7gIhgHVzWIqJh0Y0onWXWsZI2kb1rauUbP/qrmSvCWcI8tse1oPF9jUebXbwpqk0oVMSujdavMd" ..
	"axcvSDksehlDzhg1veDKmtOlzAgHCbW5T6Tbmuqtw7BYJPPumeoVNEsC25/Rj2hfmvM57LFATqNuL1c13WMekbNpNWsNHNDjduzW" ..
	"9yeF24+/muoKgrmSA3dvNH98mRGW+1ZaI/11cqouaVpOqiSgg2gyEAzZp1WEBDVlW2BwI4+Ne5Mgrc7ldzV16NIZ8x/xVPEibw0D" ..
	"x3ZGpV9B4HpofzDFNRzKSsB7ESPKFJ5dR8Jiy4u+/qYRtFK/YZV/5FE3suuvUb95feyY1fXxn+wlnCfmANJ9olMugnzBSwLyh2Fh" ..
	"DXKNTyLl9Ddi5dzkw3AOZR81+IBb09n5V4rByclhRNbW6xTwKuyuhLCG3SIotnAIV/LWyV6qu6zaLMuxEy3RIAJWga7nWGG59Wfq" ..
	"s/jBnehFCeha/flqHZaY7hwCBePiDWUYVj2tLMNj1krzVWft65SmqAURPspp6NpVRnJBghTeY8AqfAOn/lTW5Mz3E9Sp5ajfls1k" ..
	"CWYgqI4K7AGKxP90a3HallG45CNhzrbHJkSTWG+x890LTTdHKhM1yzov7KYuj3W2CIufB8hdj+0tLJnJbkTdR0KkD3376oVzFia1" ..
	"DlGdluasUjgsMBmJpNncuK85zZQBvD+nMxyLhWKo8Gb54lDWPEYeyP3AQhl/5Ri9lTX7hteaq8fDHBWPjH28yHGGOHBv2OGUkuPX" ..
	"vY4vS4UMFNkJ9eRvYn3FRHz1+wRyxk5YdJOBEaBkC/R/R2Y1N09vjrTvg2+1Ins90G53RRr7LDf37ooKsDGg33wPvCwdrZ2OYsf6" ..
	"jOwatmNlmX5fEX7yByBNxUieoQVQA/9Rb3vWszVLbtnHBO5bH5c7iSwwct/moLHHcH/dwlxFjhg+36aGQZMkPZzJDIXIsbhmf/hn" ..
	"1e4psn0iU01uVoTq3r46z4Iirm9xrgyG6pLU5TEX8URuzkUgYzG5YTJna+eHRTAvktsNihe3D1PNzE0d0O1CeBI7+FxZhqKAx7yq" ..
	"58xjaPa5DXjAnScmTWcxHl5xPGpO+J+HqJzOeiVpWF16QepcC7zDwSokHG4tdDGOKEL/3uhOpdQxHPyqplGrr3Ki1S+lCUFlr2Yo" ..
	"6gQ8pGrLwtYf8afXQ9F7F2aeNaINE82VsJSdltjna2rzQYRloF4nfhyV/Nx15dyMH0I9+11dSFzzPP/FtXRys9Tz9HmbiBW4Bxti" ..
	"yuF/XijHFo+DD/xkYovnPKDqdQ/wIwWFFG2lob35fb5ql9zO67FzTXzTMTvdOvChg1iOj481suqMHH5aVOxYxxWuLlUwqOuMTifi" ..
	"86RhB3G7UG6S8YIpr+6WIE1upE7cSKJIoXGumavGw6+u/7pY1XXtXPYrz4+vrRqYQGzuMxUuyaVQ6K6iAWg0Jh2iwxTdsYjraZz0" ..
	"27qmhhUYDdD3fGiItnR6cnNskWSo2HeV4PJHx5ghQygO8W6Q9rO7dsrcey2x2fy4naxdnxyZm1Yxj+u60Nf9k/BbahJxSsYoxvB1" ..
	"SmA2nfikwZ+221z15pI1ZobwkWVVp1zTiZgOVL90W2PYdWsugp16g4mDSLBQ8YYrbKNBZzn3/GfSMmNzLJVEofz/17aB7jjtzt2C" ..
	"6Jsv9FKZo55Uz6qMTOJZ9sSpZUBM5FQZ53PiSgUGqcFkqtqqYFS2WKtnAnklfOCd2HxvGxAWbYYp0Nyca5BFLfxz5E7qzPWIOYUz" ..
	"HnzUAwbhmmfp9Pg0HeoOYuhIAOroxOe0inktS67ZrzZNGTiO1YwLz1bLoBz2+Ls4Jk//4SaLxH6B/48qs+GNoI0xhv6e1rcDAcBN" ..
	"5W9O+icpR/P7z1f/INbtDY2wYT9BkFP/fzcQpbTVoYr9hVSH+ZzeUcADQ4Wj11eruxPlacHLeldIzoOEIVy3ywku7JDS6z13NefU" ..
	"cuD4Zw48Rrg2D5KIcN9Vqys70rwj03yi/KEEEvToG3Q2gId+JNjCb2RrSixamstWFQ6Wlz8bRlxbXEyUvnan6DbROdGP1S6T2iTl" ..
	"vbvnhA8MTLSocYJIyLt7WOtfqLmZX0qNBmkUsJfbFL11t3u208Ipw5C12CMLIMd7TtWRqOaxPntwmhtwnarkKZb18WkC6NAqGuRe" ..
	"5AB7ylPLiLewVQ4HXu8DBhmehsl5nEiXYYTOIcd9B25VE5HEWJDLCk5R4XqAfXqWfMR4cLdBvJDyQEfORf3j+TcQkNQ6ipD52yk+" ..
	"lqyRCg15wWH1LBYZ1/Cs8oPAXT1RlR9547Hp8uj6/PFmJPdUYS1LainZKM/pa/ZziH8IpzljFiibDvCJ0PpVK9QZC8hYi2ONpEpf" ..
	"7LcZiUjhVUvEGnGzPliEvlDvRB7VmRDDi+3elBFcPvhdASNKBnpjuMuKVzZPX2KAHxzTma/ZdYnvJhqsjTobxGhar0Lw+cQtVvqY" ..
	"0hXKdW71f9mWfVl2pqq3qMHoX34T06Bnen0ZuQrVF2uVwcl2lJDrfs2VNa1LOQe58k8f7nRAXbF8MHNwkICsC+qQTxC5ZQKqcSPJ" ..
	"TE0pMpXjETqrFEEcBJO9xY8a+2p8tlkY/5A7xkZ9uuNJTNKLKGfqEBLsbKaByi1/D2PpxTQwikqvBoIt6oGARDr6fB6N+iXDIfn6" ..
	"vx5wkd+8sBgi/c8Wxfo+yswJfHTfWtY3SP31jlCWf8C0lraest3rTemAEGGOsIzNvA+rnIZXD+Ljt9bWanTFu9TeO6DXG54eNxzI" ..
	"tWWI+vZ+CgNJAtSpQhb4/aHK31LxV9P6+NUQN/V4BiOT/yxQFz+4klquRBbFyDgE9HgReUVaCaEhHgpt9D3+785VZGTMH/A6GGvi" ..
	"qB31l+E1Tpx98Esu3uDWnS5p7EApRjSRzl5y+1gAWTNA0VuaJyQwf59bnnP8v0uEEnhvO/CZDPNw6C1pbQjlcdjaasVOVPHD0yHU" ..
	"8vzHt7bKkG2BiB9v8qngUrkJYbMp8NcU7CDrHb+OtJJv9jqvFenjs5DpOF4L0ryjqhOvquns8rHQ97T7OzgLdredjSxMh+lNDBnF" ..
	"QgyWK0QnbtpI+Wm0uLxD1R44ZksyN40/nS8IrGKhZnIjl94Nv+Axk8j+rSRLiOsX7PwKLB4f1bNXVQNE7iSTfeHLEkHYeMrcV3kd" ..
	"XZMq/GXGmc+2RTsME/zPy7cDHWrkeqXVJrziFD+hM01dDN8dO4cJQcNqgFtI/f/Iw2n5N15nSbBJAt71ysFjRN5DezQSSSipycCa" ..
	"FK9W/6TCjxn0gPG0rQuX1KlwJ1xlQXo0xy22Lqw+q79WLNM87fqaC2ZeZZUhWW6mWG1D0zqrjLFh5Y1b5ZZ72GNgF+UA/WetXOG0" ..
	"GQAXrAjYkOf7UqXr+NLDSQQkMa3TZ5kNLxr+OknYIR6ilYFEZJRQb4GDzX9pE+jdGgofpMMWDqfchjUNZu7fWZFo2SpROx+gcuFe" ..
	"69eKsPXcwv89rrxi3LWBxnj0DTdNeKbLPlnJjpsgSAt41yd5TguxN1HHCFrax45P5Mwjxa8r1ZYXkXNF0Q4s6L3+kIOtOYEn/D+T" ..
	"IrLx0m9YmAdsmlSdsm6ig127yT90f06yRC5xCH4JV4DbEuPo/63AIY5RhfeUKxD6FUutyIt/gFJ+BVKl5ery5v30GLjYrMf0RZK0" ..
	"7gMulM+8SpH6w0amjcyEdSHOY8Xaa+sykH7OWwWfuFR3cmfd/Tckr3CTaFlgIWaSSkoUx0a0cFVh4mbfr/rV7yVhT/BBI3qBI1CE" ..
	"0IXCba9nXMpTw3v8eQi3mNWQHUVT0hnD2aSXXL+g2XdU6GucmHxg2bMFLM7BlHc2AjAVx40JtKm7dSZeUluM5YS7aVM1tE5mKQX+" ..
	"Vy14+HOA1KxXTSkLAxuRJX6tfkh6SCAHdIT69KsBZCDSqa1oiXdm2Tqn7wDIStkZbcq+BhVZxeI6qALicZgAZWmOCg9A3rwcgI6/" ..
	"+o60pqgE/ZdsTepzikbf1E4FyFQN3aTFOVhx5wzlRdBBtxEbW+gVQfaLe3HyK9wyFpdBp0ofqSi8BV3x/WPFTTD9XpWqgvB3Zcex" ..
	"8xMeMu1CjPw5PeHJ9/YfcVUSOIuUSj+CSuag+ZXQMk1LMjqFHEjcJSPIa397YcwLZhDeGVIOPilqKRb9H5eKLm2JR52F8Svoid34" ..
	"PPPRFabT1K2mdRpTJ4nASPVrgnSNmatCZu9W8CLGIxSx3ABhM8axgQ7tCCkqsIJ63r28ykXsHKCSFDkgggBPm1E/uVkg0zR/T6ai" ..
	"2Ynr+ZEPztRj0sNOa0inZTibGsCdqJfrArKouUcrmLViru+59bLMOuuvO2lMDXRElg79rqGOMqiKIW+kzmHelwx9gYnLj9E9RAxw" ..
	"ZQGzVtt2HorM2G440e28tyX8K8y/GeD84PVVJxHTStLFEhR5XoNTr7GoNbLj02slUKE47EPOjylruXGvB2HPWu1fEOnR0xR4rb07" ..
	"x6YDJ+oW6rOEAMEpBlAF9JQ9DM/ztmDIWWVK8ZkpcngVR3vdyfJXryxgv2gU2VZ8MWnj9El4kMmMx3cKPwPhFBSp38ajHfSkqwfX" ..
	"VscOTwXvsaYnx86aiuF2iM9GUKLrhz553vj7KsxcGRpDRpz3KqtbGtCpdsPjFUz43yjXZc192OpLhrI/LzlsxnKu99knr1kKgpTE" ..
	""
local PAYLOAD_P5 =
	"mcJqc2UGbRdMb7Hc2/T7FAcWXM1wnLZZcsOzJ93JER04D6xALE201UY5v0tj4Zb/ZokKfM2+LXwPTNlai2hk9+kd/Rw0Naf2QRWI" ..
	"47Q27asmcGE+s8oIuiOKn5ocPLNd3tqGg8A/KzWjcVHdjB2bZyyZOTEs3vQdM4IatbJJXTIEDXZCUnyzYgO75//FXe+QF1YQTlhw" ..
	"3L/uFN2n/EjDU1vc6cC6uq2AZsiIsNCkYEag939ewFEKkkVz/KQ0LN2fdJNHaX/cCe4slNpCQ/w8JtLvcvqIgapFRHySZ+lkP5ys" ..
	"PWjDgOCkiy/m/V0ibvRga1BrEb/FVr0ebqNibqdsPxZqpPQX3sfcbFFsjfvWJEfvW1IaGHXTb9ui6OWrCw+PtoBYKng4bp2reAko" ..
	"DPUvw4WsodaBtrEoDs/e3IBqnka8i7CIfKc2rbRSL/6ErG/EaxeVVfQ8J61T3xveBY0agRXky75+mydrm6oe8QOi3boZi8qI7SX/" ..
	"ZD7iqD6s9eXlojfgVYYjQIwFmlR9KimbECZ0Bz1+MBOYsqdy56pN3i2su1jyKhdf5pJ41lBClmDJft1vz90wej9G6rbHsrpW4Kho" ..
	"VY5mI7Yf+vH+b+pmT0W/SVqly3+t+hGUPPTJy+2Pi9JeKvuELIKBNbfMvzu/uGT9VH+MIYkwAEpan2/0qyKVWOln1pp2hoyXrGcY" ..
	"RVCRCf6A2Y9lL5tbgunQbhy2o0YCJaTvsuzRt9LnH6B99LNB0/x6awKFOjWXsbLDWPHJTau41BVZpRLnkIxPTo53PV2hDaCQNq+B" ..
	"JW2e9ov3O/EXPaRh4cPs1WdwdlIyt2mvkD7Voe4qPxm6a/T+VY+ryZkvEeCxm1VLra3TP9AL27dxIdhE/qAaw5itWdoYYfcd5O4h" ..
	"QplyZWSZvakEkFnGmgb2I3uUjjcEbshBPwM3vFG04QSDVbbELUugwt6qmrQ495mfDPwlF+Fomnot/TtCtar31pnM/MnpQFissMKv" ..
	"qnDLlKL8zm2G6bvk6NJyXnf842f3J3nFIyJUAXVxpr9pE1D5JzlcmGfl+hBKq7v20yHZNw+Len3cUlvTeNJ+LtkRehQJuAtzaSIX" ..
	"MPWFnpwduLL+jX2a/ZigzZzwj4yIAY4zHOWgH6saFNdjnnOotQEiNW0FHdQCOXb9jRD4n3sl5oHOJOOzDdJft2ow8vB3HCxgNrUZ" ..
	"EanwxZzBrksM8ansbiqlo7ge4bFcSpJAozG7mZjLcuEDqe/oDJqBXywyM78p8JEs9UTwMkby5H3BoY2/5e21TAiF2rEwjTWKr5Ph" ..
	"+UmESIJ4gTjKMBJBpJWe08O5GV3QbtYwyFuAmSZ5lQANB/ZNxQ503u9NG1RdwexU4pqER0fP6T0tgp2cMI8HJGRZJl9B44X0X1Bx" ..
	"Dcn1QxtMdq8C0EzfSRdT4bNiJAFr2UU9bN5RmOvg5dyymjBXJB1yAlcz7aP6bKNPinb4pvpZIM3ETzclk0i7cOok5e/wSByIncYe" ..
	"5xDbg2y8iBdwXmdc2Ww9/+STlhm/P2duaPkSqz0sAuIrXHbFQ9B9ofXqQAccTeNUiDKA4Y0Jm4VyG52v6DacWn2zoS2CybsMLo1F" ..
	"+j6mpPsrmMz4FpkghyPvsEcaM6ZHFfMAz7uQYjTOXN729Bc5TAI/mXhoeYALh6DiL+0pMbzLXd/jWU8JK0aSmxal3b8c7Oin6fFj" ..
	"KS7zqYzNjnDBw0JfAW1Adjlk0GrAySIyVTJGlu1Esz5IcNIyNa0foqjYvmNc1rZ+U6v01ufGdw00syXphTTzy0XO4ku4UzF5SY7C" ..
	"a0BbQvgoOQYfz9oGgkNPAzRZvP5atYvP2YBWUepSD7I2YdhPHX5XqQT6uFKYkgzwcI7SlOpcICN+hljEG33UKTQNfJf70ONl1IbW" ..
	"ah5LUROTvwRKSU7e/Qa+3L0lJk8QlpW7nOi2us34ETFaLoac5FKODyrIdYChES/yW2+JlHEn9xbwGxvqPaTJQ5FhYVvPRcGM+K2Y" ..
	"VXH0JlrS2N3UkVohJPdWzs205yyDsHXD0TDphyaQcQOuHI4S9+KsQvKso3S74hQikpzW9BaM0wcWK7obLyv8hTISo9pUnPp/uyCK" ..
	"eZXfExjYunr0Qgb6opZhyz0z2Gf7jDb6XQVv1I03MBTdtlLNPQfeUReNFVBqjyLJNRlVgnXEFklu9/PE7KjWHhFQDYYNvhl5tu5e" ..
	"parGzoxZmqnzWT6LcOI8jXqXAqGSa0T1ttqBUus2qt9YwqiqYZeEU1UOamI93fMt+WWH216hnOj4wikQddy4wJ4xdjRpwac7zLbR" ..
	"+AV/ksJ82sbst3yc0WMcRnlO/4E5ugKYWdy/bp9wQFhbM8FAOLYkh8LeuVQ24aRu5mODtheoXewZ9f39uYTWoqVldmmeCPRIVGfY" ..
	"/0rAm2lPMNyhbtG1D7l5fuUJQZISx3GcRjyshtnFji5E+I+snJv0XCxKv/ACjuoneX8OM+f726npeUuWpWwqm/dytUIH8VKkE/5H" ..
	"SqvHgkGQFmsl50oXo7BvrwBxtWckEKV4zfNv5rEu4KKOYSx4+UbTRGfRQJZPlbDsywhlZAzgHwNeuyP+DZ+ZOyHAyT4wqqS3c5jT" ..
	"a47ACT4hr8BvccxPT3EF9lPmozdq65vh3ghEEo8unfTK+aQgZ7+qi0Be4uw7x36rcP//RXTU1wJKGyREZv8PROV41Gk6ZfQ398jj" ..
	"oz52NklMAsUzZnDcuhEhAQi0qUfIIunr3W39dqQJ+H0fBNHJ9AZ/G2PKZsucmOkMwYmR06d2GSpKPFK2Z1wvwBPWUSWGWhVIC/my" ..
	"wXzBEBD8XPFgDxNds4zieglDl+5SrJXYlwLT82jY06XU21uhiu7UqcJHlN2lTgFVgaEasGmeL0zX96vMFDg/7BknwTOboV8XfV35" ..
	"4edI0jZxBwuekspCPJ45m05Uk96OhZJgVvLU9JCqdE24Zq4o2b83iJ+EIxRt988unasMDCME4eyzLV4ky1y/ITSiKvK72h8Pe+Ep" ..
	"9UyC7f3Kz/IQ6D0rARP3KqYx/7meNug6gwLVbVrebgGrHoB4pfILtEvPPyMlBMi3mfBf3dTi7jajz9HhGakFalD/+XAvdbwIox9f" ..
	"rp2F8G38Fn4eawPbxwSGPRDgVu1UMKRPlAmyYd5Io3Itwd5oUQKOPf44B94PfIlRj/dcWTjCBHrNdappzVUT9wH4J2/MpQLHxrMv" ..
	"t2yoVh3278FWs+wQQiSC8/N2CwxB+jp89//Q3JCWHpNpwqGEepiSaHCfJa5E397RwkVlM7a78rJpUNjNVvOBOFAytCtF07pQaNAi" ..
	"1eGQwtmxr7T27s8p92DExYEomSM2oVMihmJdyCzXpeyS1SEa5YwElxLqrxPg/sJ5CxoLByfmIT9CEIs/LcS/dGFwlPdInMtU8wj0" ..
	"mKy6dIFC+Z5Y4E5EpjZZxRroJ1MNkCJiTgCQCciuzjF0Yoc1Cpv2DyU6gNTNncfFm4d2XpEhSmhcfylCTXERDfMv371+CG5CJL1c" ..
	"NV22sSD6JFXkADHfBXrQjDN7ragCPbdBhVKkSNmIerhSdvtfG6n8dl1JsOod0pJXKcU6z/l1L7mGNV+KKN+L4cP8CVuRnIKD6+aM" ..
	"hWr1xU76uTmwjhpVhIevJQCmAdyxkXzLhfcp2HoV8A4uzd9PU9xEojmfrCinGMzVokOPEfEbXvetZUQnfJRmp6awTwNLy76VmRvF" ..
	"NwSHofgJ7/WzWWj71Vh0mN1VK3c5lIn2YXZTp77rjKfN4PKTU6oSMk9SHBx+FmF2XUKUQ20hDXVwMEoLupRB9zNG7RTZjGuQKLTI" ..
	"vI7eX70sCzeHs3dReVHJ3UO9dkb+L79kpPJp6NjNed1OfuipE7/imB5SCQLun8Kyb2RDCo1Tpg/w+b2uHTES53Eq6a9duGA3WpJe" ..
	"UrNGdlgaoOkpFEiRR5nfjfWXNZrvDDaqPx9pLeXAOMsE598+dKDvHNqLhbyE+G7klJAsb5dVTl9TqhOER2MKHf/gvgVcgIbwIDeQ" ..
	"fqDeELAQsNdCHp1GQG7c9tBrJ5EMznhYHJHU6xdgDuHdGNMj9v0oAHkSnwfk++0F8glMv6QYmXW2BppgGOjVxCxixXCNYmDOKTVu" ..
	"YYh7g9bqOvsf7n6dUMdyBsh2ZWlhPkGDbGC4DGoiRvDxwHoBwTCtyTPp/WoslxC+pvKLZPFXIsuB8NPCtUm7NsXPI+wiXc07OQxF" ..
	"1ElRbK3KTb366gA/c6zudXbekLXKW/uhiqCMlIl3MyzJNrmDjsX7W39zHH9JcKIc83dkATSvLZAcbhgRT8mA5PDvI8eKEzz8EefW" ..
	"ZLmgSpeJVRAWF3k+msZCBg8dljWJnwe0TcUeaglzhtbwWnnadx7m7R6Ry+wtX5VucZi11cmsr3lyM8qsHzicVKmDIdn9D7+j0u50" ..
	"HYAEkgy+BzEXwvumtxAquLsp8Zw6JgQhmgbg+UKdFBBqSOrmLejReJLYL7i1huuYf8lslxG4Y8RcLt5upz/YaIv49mgEJAkIdTrX" ..
	"KC/TB1PApC9MTOElxSaQzypkMDKBvCfM4sy/KNYqTF+zOSmJq6D3yvCQJ7NMDHpcB4/FsCGXybr9VypEN9bBjdbdsn/eTkAjiATL" ..
	"fNacWUgIHOH8kfrxGT46fNGK5Vk59eUh6oegQeymK4Jpr7shGYRoTtVRotJBwNe9nJNOTKrupr2WVXkAMms6fKWSsTBHjp33rNaH" ..
	"XNm9IXzsUy0RkCYTX01z5Bez7nP8NKIluUTDJ5dNPqTwvWljmMM6c1RMuynDwYjP3GQsNe8YADDZpAkT3t5HFW/vXtHPt4zTgq6P" ..
	"2p5NjegalKFJJUeNWGb9O81ck996+6bFhIO6Et3SDActyQn0nXuYksGPqEIj+pSj7GIaq6BnR7EuMQfskyTVOtoxF145dY3718oG" ..
	"38lYyzhqO3RstPcoJnW60Hio5lJUOfkjDiu6VfAMbKY5xw7BrtYV++Ob3x5VdPJqG0lXJQwVrwow0aSBLRE1bQ4oEZtgsMTeBdbY" ..
	"Dm5kPd88ScsjTyX6BF3QASG2Df9oWP+0ZBiP/y/7qlGAuKijT2aaW/qZI1p1oJEWt52zjJJm00SsBa4s5clebXEWiJPwej59kRru" ..
	"3pC6MNz9izWmTThT9q0dv1oRx/fu9S36kmqguTyZfIKKAH9wiTCqxdHMtIJJ9ep8PT/vEjkIjSnE7rxrdeHG/fUP4sBpf6N/Lkau" ..
	"7tpTiMS94oUFJGF/+lxX+77BIKIHGLxeUc8WK3ht9VmQFulUFaQ1dW8/e2ki2ClgrOZIpboBJAOoGoPshGmFBxbj4BEPRR0oPKV7" ..
	"omC1Nmwsi8M+UNmOBD+pQjz2jmGBZjWHg6WgF/2yG1R+IcDu2dZdqLdXkPa7cp+RouQLoHqEx7ukOeEgzSaLOqbO15vnBmP9h21N" ..
	"O3Dl45jqv1uw3k3a9Mj5nmTxulSvb7cgWcA5aSfgXoSVcVG8/zfG5AwKqqW/TVuRoUtCHu6nBiLsHrPKYL7mjMsMWbo1LlZP9Qns" ..
	"5xkBo/JNI0bi/FMC0HrK3DIu64f06gH682GSihk0q9biLK15fwJqc6PQlHu/xP08/5xuEnOHpCtOCwGi2YGH70e0fuHtWjK4gl8n" ..
	"ghvJmf3J6FO7kt/B3enRnXK0CIfKroBr6GAz6Ut5ib7r/eLcNAg2mmETHVglsCqIjsc+plddV/07gUWmlx/Cibi2L0XaziFE9BSb" ..
	"NFXRQ46nJZJgpbDnyZMyWPyvEqoXzuNKv+tYdXDbCdk0aPBbzbuEtQCToq320y+o0ckE4YKTtVKPsODQHrhfhU7bFpSwlbI8LD81" ..
	"Qh1Aen1FhsI1wjE0mZFia1Cz4YPm5C4vUw8eNfWocIe79VRQ+gzUgQSK+AdOze2t0kBVEsy+Fy7aPuecUBcOUmKPDAp+hFCkYHSi" ..
	"/7vAkFXoXuD5QnMEENVPwLk0lDA24n7ypsZSLT8xvQRsZJCKci+JDs75OFmqudIK/0QQDO5ER7INeTK5HKQxiykW6v5rhZuB1EYc" ..
	""
local PAYLOAD_P6 =
	"4k5R/IXPWsvoPt7ZD5EsslcdAf3gTNPoudm6ohd764BVNzvFGb2wk0k48hpXDF13D0JIq1RMkG7FNy0vaGvJ2FQVAJQRHAq9j1Lq" ..
	"DycMZ/YmN9jw2IqdChdghgZay76T11zhq/9XDD4h9I5l1GIYfWQBF80dQsOYRnDHAkLqf1+H6iiM323ZcDQuyK3zSYb1ETuyFU08" ..
	"A7TeVu5aBB5CfudUFe6nh10Atfs3zjyeDbmfNQu1zXOeLUCdCfS+bNMUg60vfuE2H3bz2WccQ1RuphVIBA2E0riFznAfrjyK2FGJ" ..
	"yOdGzEYFJbmcWwxJE0vWgFDnOvRPb/x1PQU+oiWzdIeOikaPYKJLrTDCDgKaLz/6pvdLCLhgmeVauKFEdmHiqc19897IGGWtvp1R" ..
	"14DbOXk/aXSJKMYrewL83y7301yvGg1Z1Tx8bS5kqVvCw+mzPOoM/FyRvG9xQ6Ac75KbEayt3vDGTTy5FgnyMnGNk49c3PXDSypk" ..
	"Q+wwCu8AkrbDxeGJT05yP2Tv3NwMPF2MM9ckmis172+iBaFgTAGtj9lhCcCeI8YL9og37bCrb6KuQ7PbSGnQ/p1RZMyYTjjRlSWb" ..
	"VVlZPtSzzuTeM/6VpBYFluWpuROO/pnKOvhN5IVe4OorYUGrvWRIksZtgeVRpLD1q5i4oAwEXU/+KjK/eNywbvgg/UJKVN/+2hKJ" ..
	"8KAdPnvzHGDezzUCoPgyEmUc68JoRcagYHTygMzXZkLq6+Xpz+xB/NG9FL3I6DymXaRJb71vG82L6UAETykouXvCqMbWBGMuMgi6" ..
	"qLAGNnhqTxl3+d9cWs9Byle01AtAFiBV/nor0iTfDQ+cMosEFayBkuZmRfgRE7O8c6e2yGA4OkUQwpDjaN2cEId5vErhX6wDxG+O" ..
	"xjXPSgNfIIJnqQ==" ..
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
