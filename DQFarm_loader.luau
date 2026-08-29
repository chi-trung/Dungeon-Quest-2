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
	{ seed = 882563319, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 887273697, exp = 0, plan = 0, hwid = {} },
	{ seed = 887872644, exp = 1788089514, plan = 1, hwid = {} }
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
	"50MduzRFYVctZbfQxc/Uf2KrzHWqN+sPZNWxiU51pZUHm201tFA4znKpKA4B3NGLbFtVlvar3ZT/h+7s3nBXmyP+kG8XImzz2fdd" ..
	"lrNYqMjPLkfhSp36knB86akXqseH8KBNiw0mQ0vElxI7uqaG4D2tDfahWV8Th610Ws91aeOTQBUASTzro2Hw61rg7jOzYMT6MPTG" ..
	"U8XXLjt3UYxDlVZ4cXJynOgMjHIQki/fSHcMgyf+vIquGebRQ/9Td+tTyl4iTe55u/+o6a3w2NVg3lhIVzf6S0GxmwAtRpaQPcVA" ..
	"YJsWMeUeXRRt+djumq2WeboACBJ00Px551WdGq/et1hUKXFaqcSj8upw/dE2yg5RvLC9RdN5/IzMtO97VNtQ7wdRQfwpbha/q1xl" ..
	"GU6AIv0IZC6CX//lM3tcS7LamP81O+jiEbW0l/+HzY4+tI/EsGfeyehrmtqC+ZLZrnqKEXcYPa4ObR3ZdsjoicH/B4rKSwCck++7" ..
	"ON3J8LJGOcFU+5y8p4CguDDCY/EUS91e8LKiF/gj2MFxHW6vIcOKH3Mwav1aaYPJAGDRpfqSIrRGA9Fpr/A3TwbrRR6tPGMVE1o/" ..
	"EWrQOX/PpwlPdsszCsNJHXSJWFGYYBbWeokAj5MV5CD45mhAvfidKqrq5h+Mu2Dx6OiVfB3zCwD+a9shaJLPSfHCEfWkH6dAqnA2" ..
	"E7ZnSOGcOZFV67EMB76NPt3TrXQ3kRGZb0jkJSVtpweBC+OexAcWlu9R0Crn8aGK7w42f8y4BT7a8TKnMbntPyM1h5qlafxDmrZL" ..
	"7/Geoe4HYVyX71E0tbwhKpqswDjBFX3+Z6BcpcD36qOS4rloDY76YdK3ZpbgdDe0rla6E5uIYSi/9l1sBGWfJ/9z3B+qZLQPRWKK" ..
	"VPSC/mM3n1Xq6HJwDYCS4K0oJ0/5kYa4DwRiAQoFV5iUK1eC8M8EnwLlP9vNFGOCURmA7K/bhjkDR3VJuY9/p+3kiYHUtnNr+Zdr" ..
	"DvGzAUDvaGqW+pHkEWaJfGfJA4iK4Gqld2DkfDUEpHsFiwugFbsxQLlirblwwfENMfW5QcWLGIms9wQJPuFPmO+CbbbilPlicVLz" ..
	"vn7Q4l0SeA7aoCluIronXxJd6dkiGr5CT6q8CoK185MkGhUCfTp8sgVlGzq7SaveaoZ0QSCiP4Ndk/VZsMbU/H7YYlpYXnAm/+7f" ..
	"29YQzqDrp8kurDVMy8RBKiyWKXB9dlJ+8Kr2JzggJTFF3W0xHWJnJfchUGM8adffJ9DPySQBoWPAPshFAy3Sedh8sd2CiXKnk3vo" ..
	"LL2CwFjH6hZ575TXEPzjaHcGEjq2v26cAypnXR3Ez56+pnP4AvFWWbd+eve+um1nVi+JvvFPZTjHrS+9JS6SFgVCBEUjmgqlylZ4" ..
	"b7R9vg7TouI7NtvM39Jke5IGfoa/AILP9VhPFv89R6oESxC0xuqXbBn57t5oLWU5ZUpdc73yaEjDZgOyTj7SOXyM3+rd2WGqQ0jS" ..
	"PMfkN5RVBwPTJypmNfJS/vjCAfYZo8lYO8FdmRbyGJL+qS5pg5C7R8/M+qF6fYZ73YmfY8hdMA5JL2TKcEhNfyBNl/dGKo+vugDM" ..
	"FEL3V4LNHcAA88Q/qes67YY5hrSun2USfyyWbPoZXRC4gsAdm6TzVYbmM2iHpAxOHW2YjsjSgn8umzXs+JHPNwZmL+OMK6lOqkOt" ..
	"GLZEg8i/TWp25lQQoVG/4dbMDDU/NG8oThGtRsvJ9s9pkRh639PSq9Jmqyk2C9aLcTP1kSJvmJz+hUPwiaEtS5SnJRcXnGs1XN3t" ..
	"Iq8efI0n/1aA2+PI5ZLmbjmkChhap/wRVqvT4e7l18mPX4m4VLVjz4IIxJZBZPcigI61fN/REDAsBWwHaOSvNlwOn5mBQh/nHfF3" ..
	"7UR6qmiNdkCUYBQnoWBnBzZkzt3q54+KgrZ/nBaGTbKZjHxt8ZeHtRCMM6IIKEFpKzC05EUo1KNiVs+Lz391aZrTWS2qL5fjvgaw" ..
	"0H4IwMXhvgCM3TcpaNqrJzMJc+V/DVnx/hayo40bicnkno6l6xXCV1RwMFWFVZMJudh7nOlYQP4FbukAPkq2PLdwHkammrr3T91z" ..
	"mmSKF7p5byYBOfblR9nYU9U++LiPi6R1OlWujcTaO6S6CYNJdBhJtAqBp3LAvUuVebNyNnILnln/K3GyjZSZzN3bz5hfYCxQub6x" ..
	"qa3MhV+mVvyq4xShZu9PvvajhQryGKOik71r0OcTUVdvVd/a/t8LZr5Pkq/UASMhiwoRjwqO6YzDV5fdMLCWzXzIC0qn5ldaYAx0" ..
	"kx0FWwzskfY3yRnfIVUSeGcM0NUMzbHKT8EruwrIoL8k2KGPRXnwi5oXZp2YpxBl799Q+Eyf9zCSYdr79Mf4aVAyOUPi0nyjkBii" ..
	"JFA/HPfbWuEC/s+iHSXnpIaYbyDWYQqcdV+YUz4s4SKDgdI5tSIbySPrtGkfAS5IomwOCt6NZ1Ktx4y8jt8UUypKeETZFAwX/yWU" ..
	"/RBZmir1Wr0XFOjHCO3RSJ7EucEmiJXNJJrwccrIHhc8iZ14UHAjATLTGkiTWxdV6klzhGV0vWSt0vVj46+wBRdYMxFN4wNGizWw" ..
	"8kYgQdiPNzPScdRO5RtTX70WXSI7+4J8NQwIdcGipRp9XkuvVVxcUQacvOBayZNvMKiukK3QsCGKLOx5NgSEJ64vJ1buwU7FUr87" ..
	"Rsm/toxQu21+n8OXOVUbz3DPN+nIh+ZcGEyww3ml/oPIrq8A6LUoUpszfk8qNQoTw7LnQHCv4ChBgtZVRDu9LiXvGFvwA5Xh++md" ..
	"F9K2jVwyBrcIhEZXsz74dJj6YUqNlbSdyiBjHeowj7PQVZHSH6DfNcrpywa5EQlC0zbv2oqN5WMHys9sxofHnKS2mP1ZC08zEDd7" ..
	"CpgTJdcIgVvm1vb29OEzx5c61tlqOQLKL6MsR4Az8PDxM4kCs3abaUBU9Hii1KG2Oik9GC5eT7eerrBZTiug7FYNFJ9jyrACLfX2" ..
	"Hk3VVkLuEyK3pfEhjQk3Ax5F7TUfmdXg5eAMIq4MrgKNTqKml4jMgu0SnHH/tKjSjdwjPythyrXPR6KY85kUb+a0e2IUa88Or7Ql" ..
	"nlEIW+Kt+L5drwKFqLRHWJX88wrMzyuRsUXnbba8aEjwww1negKN6ZvHAdzgKCLfT+YV15HpwAnVe5AOFG/+QHLQxYcJdK/NZKi9" ..
	"l/HgQ+TzibKAvcqH8i8ZwcqBR7YnIkqjh7QxNR5oOAx8RYmTcXcaMVZP26vUTLZee1ATqG0+Ri1iJzHXeXRxJA/dCEkchlmiG7vF" ..
	"gsAlis9JcJIkYXq7YaC5Or9e7FERP0uJIyVwn5ZXOG+P33bxMKOMiw9pEORBkeb/3enbz4wyk35N2rc2otKHCZNS/39+dRCxN+qK" ..
	"EY3bkVGaalQASR83TuLhdJG57AvKw++hx6SwPvC5uiAobiBiQW/UXGxRmejzrr5E/OJmGkzcQOz7Q8qNNAIZOzObciXlvFZlSzRv" ..
	"mi9U9p6APHGUAfZyslRSz/poyfq2f8flUVhIvWiiN1Le7XlkPIGch5G867QKo58ZECyAMahKpKyFfHE8+Nr7LVlYmVsO+1yyWru/" ..
	"otujVS0cwB8MaWHNgH1XNm/fTfHTGIiZoWloFXkUPWfeA5c+R0HoGogRdiFiFxz9CeOqYEULRB84L76L+UaohvQ+nDL/uQWulGRr" ..
	"ZGx/IKnDk1gtucQvlB13P00KmXhdlrjHUqnrZZwN9VE3KfBS7d19ytRkZC23C5p2F/8Gy4W9Pr9ERUVseEh0D69TNb5Ex+ifDTWN" ..
	"ve84PON2mu2+BrE1vicXJ4/HYDEeHhvyfgORm8YSP8wlboNw62/kQ81ZsGdz7NjAhpCNtY1nqJG8O+oVjsO2ma0BIwUgeNMeWB95" ..
	"JGi4u+ccS2rAGhHsJ1vbnI4GTDBL+9RYrWrhjbvHuv/aZkpaLq2n3ftJV2sM9dp2t0SvsO1CKScB2ZX3OXl0+R+H80GvxDdMpKVD" ..
	"ESQ9c86aU+1JQekNbKVZjsOITDF8VMwVRnYw34eFBjZaK/29AY4uorVVHTrZUBr9iWo41+NOKYklhzwa2aShKjRY43VJDX5rlg95" ..
	"lCR5ZAHyZQfJMEoMLgd51mgAeuZkpoImmh27Hbc7S0Vjj1HQs69mO5TYvwCha71PBWcIP1e4tLgIDVDqVaicBSalngBoDzbBQtnT" ..
	"pV+OMepbpgXtxcnBx+2H9KJ1UwV8NSQt8yhPUgAmBs7hzijOPf43hRK+fpEse7rvlEUT51CE5iDBaTeZ6PkW+gzA/YM4bnW+0zre" ..
	"YcX8ip1j34Y2vyU8HAQ1JZOQzxCJuwhupoEeRz1EiIERCvTcq7DMxkQdudQ9/i9GBI6hNlrQC3Or7LvVEs5V7idDbdnjgHG3wIxW" ..
	"HCrr6PKUUPTBw+VfIFBTzYebFaGIuJW4g7Ls4NDlkShnWK8eQi5yguSV05q7SPhJj0aJM46Fkcn0M2V+G2eOwuWkAyBGWbTQZ/GG" ..
	"7OuOauuaXx/tTC0OkTUNK4vKiJpH2XtejSL15apS2sydgD3CvH6MQqlNz2rEqJjdQNgJWHRs5aXFNS9tRzl3qNkxNiM9RcCa7Z2b" ..
	"4eIwZ+hZpWaZaYaNCoZsWhUVlPFL2iIrOvkRiCRr2b+nxmAKsPQ4XuuULZics9qebQxCbpsoRFBg/h1L/1WofrC93f7Ot0LUYCiB" ..
	"E20njJ2WqTe5sqLWhnO4KnYezIdsrYxhesDp/5JJHWsRrMlaiMYCcfyMsFMcQEJXJA+vCoxG9TbNHfj1SpcsVtH9Y9OG52pp439J" ..
	"allNvTykrmQuH2RuFQ4Y759+iYWqoEmnCZSIRPY5Gd9bcc+/zB2XnknakNdQdGTwdqG9/eSVgZPeJ+U6ck5u0wEca58f87a0UFtr" ..
	"1UTLQgtnymduMQjcD6wDHokwVvZmXmfjHeMGzJWs4oDBWcvTQm4zl6LQOKeadOmlcM98F3R1OYrUa1GlCanlT95/gFo4UJH3fcdF" ..
	"teUX5HZwtOrnt63Rzou27jl2+z77/FsIrZnnHguRB+wKpnndfhEDBPQBmT+pkCEuZZdvpNo71VerDtJFqGknca79h3HJ2VyytIUp" ..
	"8yOwm52yLFBJvi46iGw7Y/IvR+sPkbxe34LsaBpJ48ApWOciewP5dKQHFyG780AgZyRwwFxc0/j+bgpGbmJySnxDsRy4dmW7uQkP" ..
	"UeA+E5awo6bhyp8z9/o83SQ943pVM5NSniqtpsm/e0IFAFT+VFJ8gXsjka6rDY0zbkbxF0lpnnGbq+tOZSO9eR12YZ+II2vpPF9T" ..
	"Wzg7EmvzscmaiiT3R+58KC04VMfWFnroBK55OSdvqYZ+q6LlCwhriaKgYJbhSSpvJ23CD0GS9Yg06pzDA2sg28fKMb+KyzY+XdO+" ..
	"2TOfz9bG5b8SNEDYEcMmMcEUw3bkGXMMVAPM0uGWIUo6byrmiikCRh6IYdAOnUrskd40TdkmNNHIJjRfHHeFYg/PsRVfHxmfcKCN" ..
	"O1wSENxW7vTxCXTozjmJPF8j9hTEkLelpmQwyrWj+eqbnxDRc03/FP31U9iZlLScyeXkOA72eHl/N/B8ny+myhmvvXzA/srN+UQq" ..
	"V4FLm06jmgZ9LQxXSsFiBM5v9TlPx4IN0lf1IU/ggHWUk5S2twljba+MH3TGZMzUn6NyD0o5FrryVUHWlYhSDb/FlTKAiO0/5Mad" ..
	"eO/5qqz1uszwdHNmtoUF3DTOSyVzJwZAUuFXVpwGha3p1tmPyhYhB3LwHH+Ckxm2jAlTw/4IQbiukCu18kSTjJTx4GZzgdJjH54I" ..
	"cFap+GGxUUeBnSgopVbxYwUe8nvtLEurqgVkJqpXnfEhS2v22v9T9aU0Tw7fSqwytrNzeaStE6Fx59dN+yySC4x9FCokHmZ8oq8b" ..
	"NvfXJZJ157KJU/RDZvl3yxm2cGvbs1pEgiWh2hPEqj8pJLSKLAhtqfwij0egFQ6nLLwCJ+n1aHx8jspKjzr8cLS7xEzC1HMF2E5B" ..
	""
local PAYLOAD_P2 =
	"PpWhmI9RKheA+20HNGA7wBRd4eKHP2JrN5Z831FbkBBvEY8GAweTcUe/Qs18ELEBnToROLfbXp1IFMXWcJ/WV3l273kZmuOXMDRk" ..
	"suTKkX8ck21qtdLaaElAwjlBRdS0mmp4z8sn0oFMcxX7fffEgJaH6saDJcLUp5zv02wOjRQewLn3UIwWbvfAbTbDngUmM0FwIt+Z" ..
	"cLY0o3D1jUfpCN/+xjwLbWvyvsV5pBu4NOx+sFsZ/xOY2SxwP/gViJtilP+Jv48PCV0ISsNytYiBWQRxmfx39ri0ubTDpiqoblu8" ..
	"cJTiX7TDxMQ3OUfFISMFq+BX2VlaJegIwKf6RwPvm2O1dlaytAHFZXcdvFyC1vPcbOsF1lOc09Bi+fdUk/WnNKj1h1s0a4ZmIjFG" ..
	"q8w4xuHUXPNKFIHIfuDHM6U+WqT7Ujbn18adx3EP1SsVdfY5++tO3Lmtp9Ss1XFgL7xpbXu/sdpIKDl9aRJhtHiiVMgSdhax6V+c" ..
	"SgeBXgSPUj65wv58NgmPCjUO4oFAAS12N0tj3XL1CeILJUHrGW+V9+H0Jf2Yp2TM9POCxacmAKtM3sl/XBlOfZFYtxK/wwNmRA8k" ..
	"qgzPHiQZqWFrQ/BJeCOSpfwTCNFNrzKf24pPu8Myei8QfJ7MY06gpgOWq+YzElJ2Jy1LxOOD2+ZuTomFv1P14Gd9LlI/mS3UelBR" ..
	"LzzH3XnezXQHWAXlbxoTuJ/0D9Ptp0esmkTcN+wUDghi6qmSyUeYOgtULu/cft6DW9p+w38h9tsPIXhzVXHIxON1tt2MdTG/37YV" ..
	"ZxM6QgA1Fe9w+/J3ge4+j8Sj3Rzx/4V+YKC0dsjvwJKC/VkpzBg/LlzSst/QvkPQx7hDJXu6nADDK+wj53CwCbQ67BgEH5uoPGqa" ..
	"UupovRV352dsO6UgXXXTdOy6SzIm767C84B0pNHLM2gm7ZYfEOcBuFbN1ggdzAyGeB6wC4/aA51u6KZuX9Evf/XHQ9gkglr1BhHf" ..
	"svNztBQSlofdrHluDcyZotDGCdmxJq4ho3nabcuagcnDqnBlKGuSAzwF6BlZNC/dR7EPPj3JXyvofn345P2oIeNIhqlMGeIYD/P9" ..
	"vbggY6TWKQlcfVhkw5b72apyzTDSBJAyuAHGOv/tyJ+VZomnu2LXfrWGHqH35ytWuphk5xYIo6frPxWHA+3LOu+cact6usjbD9Cg" ..
	"lTCimHDjwJDFqyCQsYVd+h8Wgw2OGMRvSlGu6c2ZqVGGzVHUYbxi8QUx3inFqShpmW2ENy7cv+FaY70BuLxACrvXU2sPEUmPrcFE" ..
	"DuWgpSCMgTMT+lyDBK37iTG30fM/i9DqUV9PxlJjAGQnTozmNUKMd8XfCyjusylj2pp7TO0UgfEAVMXWTtBnkEHtxOm+PGvApI8J" ..
	"tTxE65zZ56bVA1aJi6/ONet2RK37RT6ug5AbPc7iht0Yi/YlZ0CwjNIs1xWAMuEa0Kj45Sd4gy2C9y9MhfJkv9gErB7RI3hKdbdq" ..
	"NB9mXd5pxgo186nbK7oL7soLSqivhvSKtJZlB2EU9fGl8v8HT5n1v050Pc4rbzh2EFsk5oQkQ5HONJRgG6a9RnchkP/9F3fteE+X" ..
	"j+WZHRm3DJJmI8wSiqED+/rIwjvduu1e2DvexTp0SrxXeRAE2qF0REDKByIubOTqP+2ofC1V35pZbwFQyUqT5G6iWDez1V2eKLf2" ..
	"3qLNckyua3d5GjzlKF2ZIV3MjqugvNGzZSyndLb1S5YGTt94uGgL+siPM5nY+GS2vW8eDSVmV/URN36q/DkWlfnzq18Cba73QDYK" ..
	"C0scmIwaV35k5ayLH5o0oGEb/Dj/iPcxGOfj/wvcfKf9KBpO5+FIothAYhhNTEgWLBWGWuj/UFSUUbwz8jvW+jUwwgdIaXDUtvo9" ..
	"1PhlZagMAu1/LudxFmWVRi3CsyYZrol9rWt3EAZLMMdF5t4j4eIluOTcXI1AQ33UqU/xUXExeWUM8nFWLQ1Nzw7tOQs3gkn57F7d" ..
	"f0MYoeGBo19BkkneUqp9F5dB6B3F3akEBDgoTr56x7+ri7LTZ74xjD1writvAGqEPleO7ENpX0La/JeyElGakZMU3dFyu1EVBpXq" ..
	"em6Q7MxzfOInAKMZbhUkPgRkOEKWXAQojyaxT/yz35OX0OAQ43LsboGdVGxX4lDe4sF0uR+3CvdUDmvOwo1Qhsmh6ZZcRSeD6tb7" ..
	"ZiM1jUoCpAbeK9QDZ2pSjq6ftBltIKH4vyIjQIht7Ug7Lk2A2Z6fBMrpJs6ZlHr5oJfIzBPTuzuprN/inYXhNRWWUAd2p4pkwa6N" ..
	"m9TcfmRCi5hX90W5gS68EvWm7E4swbY27oEnRKJs5E0r22te5YOb56O3jGM5Q52SjSimSfUFR8HEoDWwcJE5MQvZWMB5Z7m3PpgM" ..
	"pycpL440+J88AK3W6mCtF2LltQJDJHbYoNowkYI1KLPtlayROfl3tgrJAn4VZ1ugcfN/G9JjihsGIg9y4OqJYa6GCZqCnnH9ccKv" ..
	"UB2pU5tswyvPMlGf/lH650srDrligTwewdEDatyY1FDCwa3juN4Va/DUdm9DDu0k0osZVy5sseoSJvbdLIpIxxSadtibw+BEcNp3" ..
	"aM1HRBykLig6dt7JAToqWQlEtub/kLoaiM4pV0CvlTFeLODAuO4chHrFLFIQkFLL8vGwsNy5aDqLZfrrJgcagnZFStvMRUTFn0bi" ..
	"zBva8zBwBdiu3qqZYscpmScylBETmpfqcXeNcah6lw94BvSEJn0HYvEZybsZMKDAuDJe3wPcr1VnxaaIYojiyNG1eJvRBYX2rZlr" ..
	"ZSX/S/AYPu1p9HPtYK6l1NZobFOl7cbvc5eVBAUdCEb39BgZ7Cx3/ichQOwblOH+5cy75Dz8HWML+qiZzHo0D7GH3s1e+94PfezP" ..
	"X2S0LXkl78nYBQELi9xYi5FZIE/BbH0HBUG6rTBxP5+eGVkXjkUS9oaxghOvRfnvxBd+soteEqtJeZMHCXtSEB4TmAwG6qzBGnD9" ..
	"Kk48ZWXdnYiPRuTbYrDR4BHLbPy6rbI87KgXsSCG8jiqucmc6gzbl7WM5P90bvAy3DYnZhEGltoIjzj9+DI5+hzCDhrfsR8wjlME" ..
	"PoL+pVniBSMqIMg0Urw5PdzhiQUrSqC/tiG3W1jeYpQf2dJREZmJrYXm/SHazYYSNpV1JByahgUnKQ1MBcUdApuphdVt+/kr0kZw" ..
	"iIWXCHj6baO8UXIB4/r+Riah6J0QV09OyxQPtd+QOtG9CgsHK3zBgHHIashZLKPmhThrKklLq9uDabHG6FCLsvlLD0jHLzSeDis9" ..
	"XIVjscy/2IPDfhmtyFU96AXcErB7KD/IvMnWapY/JlwDdsmUq9LK4h6gcKIW5SmB8yEfCYSkTeN/016JxqXNXdHiNMz1g6PV1tol" ..
	"xh0qiTbIBGlHCoTLBV/4I3LqFiInhoHVIAPJP4RTK/sa2IH+JUssBNtGOMJAvr2G/X7T9/5tKy2KUZklZY+lBpdXAjgoHxRtYRLW" ..
	"KY8RDJlqZbqciD3KcUQjcNEZK8rkzjnQKlPHM0McDaEHD7wZH8d1aLq5l0Kgs3UDIpKuH35p6l1QKJ1D5aBqCKXZDMwivxYdH/3C" ..
	"hXHf8w9e9aW/mIxkOY0kzMyXTE61O2m5ixfFgAPKKzMmnWEaGRyyXQOBnmpx3TI3LBgyTbl+Va9LXvmrDkaRRfaGWMG0/v/p2Yjq" ..
	"UL/bv+fakEVZe7lnWEEltEih7A8n1w01kg+sgToEzk+i4eKm/pd+GPBLRFLs9jewCqdK9ZRKmzT+Lrp8zDrKTejpdHf/GPa82IkT" ..
	"FM66N1MosFHVFHc40wtxOcLS3YAOh65RBzpfK01mQcnpd4nWRBvQh6LX3K6VnBYblFuFpDTbn8rWAvvK11ppACr/VVctbYfTY+Ah" ..
	"zgEyjsLo00L0EPWQNjTUtRkCWeEXy6RVYB0Tul/IelFUiP6ElpVg6frQH1o3m9/daVkcjK/7AmU3ilzNoH+XOT5S0Q6Hw8BEl7Ol" ..
	"P9Y5cuGCekg5GQNvCIiNHcBPH4WBwu2tuhqYKFHB/dcTJ1DM/QDLXsP1dqeEkzs5T3kHJarFNd3Tif9EEphRJFR+oc58agmn+rKv" ..
	"hkZvisTtMKJlFBzzV9Oa1epY6i0pWQOIjMp1pcWM9hoLPpZ5fS66yg9Nto0nzKryNYHmkgqPT4DE+miyUOCp2egaFbpyGolxNMNK" ..
	"yatSf7wNBB+HezPQ2HZrOzVUUVpktp8Ipd1SJJQCy9wSogpS6zlElGKz5u2Eu4KZYllrpkYYM17oa1cjGhvJIxmmBqGgIoOm50Fg" ..
	"UKInwW9zj3ZaSXKOjmoxICMe/fnhybcN4q7Oo2YJ4O6OXO6gQvwbESebHaBFvLdh+ksZCAXeh0uRIIGOf3jj8QfgxvV/Rh2Rbpzk" ..
	"dknpg1rqbJeM54uvN/Yjt/SgQy+8QMdql4JJ9fecdMgkaucGpxCyPqkgd9ShV6jgC9spKOwqIuBwxcvSUoxQ+bZwCQrgEAbQM74c" ..
	"C1P8UWSNBEy41fDEdRfe6I9FO8W0nroy9RPlscn8eFiCgFc/JRu6GUG+fvvXSEwbWUDHYtLtgpICOvU7SqdLbkGs4Zx9/WicK+3E" ..
	"Su9FCMGP1vp9Monr/oQspT/CXGbm+xB9dqbsToJOndmxst1jjbghaK3LTuSl0koIz43FALgXWpgu0qf1XSCJJeF+2WeJF0iWeDt0" ..
	"uRvnPh2YM4s9JkGJviDiKSccg2ChPy697nR3GoRFiiIt4CeroSRQtcD5sVpU7AHcC+9p8MS3d3jyLMg0wP7i+kPn7FpkGu0mzKu2" ..
	"injYZ/Ff4csx1Q4ZbSo9QduwWvul4TM2JZNqYJKpy0bpM1A2wRalwbmSGkeaJNo0cbMFwgLYdmgMgtMgoGSaVo7+HCFnxl3/B02c" ..
	"373nBzfMUDo+pXZqNKfdwZHdXBTC1xQPHMFgQ1olI3hfetptzAkmEp9ScofBU7kmJ4eyV57goaYdeAq2KfFrl7RvTee6p4fM7QHO" ..
	"XpMkmtKNHh6DlgyRFncWRd25pwiwDta6RzyW6KMGVZA9pYrXfX9JtrFrCyTxI+qTMHrQ5B9BxaQQrzG3Tj1fJyF8jTe/5NBVPItF" ..
	"zA0RpU8XI1PoqKoRK6AdyHxUJID+NfT1VBXrhbx6eGPn+P7n2t7Hi3hSSiZ9AORRN3MNA4DHomL1yTQXcsZtgZaGN4OTNdXldlk1" ..
	"5tUlqaAjx7WwkcDhhzQsQbdjq5pXzySWTAAuhT4EbAdMgSkxXPi0FOQqEHhcO1C7BwtlC74EhVVK84ahui+flMnRbZPJbMlp5hzA" ..
	"syPeN334WBsJbo4plqf1ThgO8bPzOmFDWZATsxiTNGUHBsrMmi/VkEzS88dbP/ZoDUQ+EJLL+cv9FjjVI5IXOojrdYMGYhil9td+" ..
	"cMVhpkDx503OPXkvJKYVRmeMNIDrpQsZWqdSTjMPd9Y2ZrK2I9bgAs0tFgqjVhbgsYCRhpNjIODb1A7PmPNwhoX+ucq/eSLzuYA7" ..
	"sL+T9B2S419NwmbF2KqDIkS3iUCDjZp1KD/iluIqqBdU/DYEEXJCJXI0hie5CHb88nfAqq7jvx8ZVOUfKGjRw7roGNyI4Vk8IFjm" ..
	"hYowXds5QqH6yf3yFM53Np9w5zUcYuhyGI8d1ZjyemgQIpI9jBuG0X2KLlKGEXBzF17pAYvtqWO2hrEnQDrdiIDDeSWTxK1vAFIP" ..
	"MTc6heJkvW3+k7qi6+FZ3plVZJLQdcTMUEMFpB7TmbAPPS6E9iwmk7Ie33Qc3aIJ/xutdkXh3k5bXwxI+QNMvPrQ2UsF0p/2eOnS" ..
	"ixyA3Sxq3YLD0blX+EiLu0IRRAnfcmuxn9iD0HdwDxZ8mjDwioUvOsXI0t19RnJ0L64MyiAyOWedNajmNrjmM76yAVBirYc7D9wJ" ..
	"QmaFss/gKmnuEbiDqUkDGR9NPTrWhuZPJF/XAM32TMJqeF/3YmL7YZNFOgUlcvgBIs8z9eKNJNWXgXdiMLtYaJ/yshf595YjPbzw" ..
	""
local PAYLOAD_P3 =
	"JcKKLnec3Ap230xLN+uXRfNL3oXEwHU5qqtoTeMRjUzzS+abIWOoe5X5W6YFOwNt4xL0cXAoTqWlX+ZofrzkwkoMlayoMxP1Tb69" ..
	"9Ov8+F9LcqLgEVAnNWsthi+MFK2KPzyteNNBHTHv74zv0Bk/s3odDrhjzrHnlmgN9JmS29113PZA8o4r1k1bE86SVGYj//xdznqF" ..
	"kMQcnwvxa+6I86RLOahKF511MV3G6+UA/9RzFCSu4WAEvNhmB8py+hEgIwlTmQEYzGdmrOfK4AL+QtzDXh+PyLuuOBK7LP5nyBw5" ..
	"0Zs/aQVitUCGLkPcgFc780lJHaMcSrVvAijHYkDXlApCeyx3KiwaSVhHoE5mjaW4LaRs3B8gOG/ssXx34ynSM27ZAXbRPZolKy1U" ..
	"Wm+bw+VQ9UUWzesthLvCwq3yEPpFbEYZny8RkJS4mJcibTPQpvjckLvi3vCvdKk2KkDH8Of2w1hkxy5+jo1XlduCKKOV9aaBDRtH" ..
	"kKFEbmW7Bx8dQtuobNWoSSgpXxzu3619uMPYx2IWsiwJryVfMAp30qkr2/3Z2v4zL8FkJxcQvWgwBWEF0wKdYBsxJanN2fYm9zDk" ..
	"TnoowfuixmSkBD0tJI2fa4nMcGdgqTghl5O1vf0Ie7EzcANHpKVUTJNfF/Q9ecir2e5xyIQWTuBe5Zqxr9OVQNIm/oRvKyC49ID/" ..
	"97R5ZCnnHWxKaKVvd3q8t/nk5Rh+l2X5O5r3ubdR+FMhRggEhtgFbMHUTbr67rYL+6Z63m4sYRLuRYSfwbfK41xajncjRxw3wqFK" ..
	"0XqApFoZL1tP9DyJIPdzJTyrzTjKvkDpJeeXB2blZQRbvAnyo9WQEY7wWWbNY6bci89sIEcvOag6OaK92lHZns2TSd9COR9n4dH3" ..
	"eN5Wu/OgaUuQIhv7F8arem6t4oywoQoUr8PmS6ETWIofkz5/tWmoQDRKhsbRoccCceqYfPFPmRHs6ZkZX3j/fI7NUUXTuRLPviAd" ..
	"gwmvDMh7voxKzwtpYC+haC/JOJ0svLpHhQ5lwV5gE/SLR+7lm0pM/xn+YqlOefYI4yVXBG0WI9Js4ajzcVb96/shafWe8Hu/rfe2" ..
	"P/ge+2q5lB3JXjXY5pCqndSF7+/T3cQxydwdKWdZYkZgeTZXsEPkH/HXbHzKn2kFLKc9liudf0aWbhkjJdjD9Hv+GOHuKhUUE4QL" ..
	"dpMvmeez4ijgTm3ClqL/rhLd7tyxyNSyeYlz6bVsQJ5agOC0ShTHYwhwIVdWojwc0jUy7+ZYEeC76+ar3rUzWO5fXEgduB+e4N5h" ..
	"yBNz/hH+Vv2eREdTMC7d60BgDeszEqDFH4eSzMuPRhpoUSvNLs6AJr00nRC2RdKFbL4pQh+LwIPg0EyTbJLKAs5Qh8V+diuKTAMV" ..
	"6k/HAV/hq43dc83HOtPjWZWqasCsmnviWJi7PMTo6meIAKpSFTBcl2iFna74V9e+KOoizFPAyZwDiMTYljkflPR6mmJ/oJ/UZVY+" ..
	"sxHqc3ywE9OWxGUr+wRhbbgsNNGYnbFx/Vb/EBtDYtD5RL4RFB2qYqKIQjaugigQV/ChV3hXcdeeiE2W7nRz/aC3EC7LmxWnJzeJ" ..
	"lnoe4QOCcEckclrp8M5bvXU4s/ouDKJvj9bjwayvyt44UIqCPoIFsmJLD8rNDqtxy68TPXYBP0LTuLd519yDmXJVe0xnAQxGRKjP" ..
	"L8eTDKEN+bwju+ZIKhK1jZfE8lO+HZXMIqDsx1Uj9Q2CZjgoYWWGZIPE/V6zM1HrINpZoaZXb4HrMR2G+GCgDYYxtFc9JI/F1/p5" ..
	"8kE58Ptvi7BrWhGmI1DSBBZPJdELl0KcX5dBkObuczngllba7cT4zjUgnrbf0Lwq6gU5Hc75T3LqvkJCzKf0k8ouCO8nDia/fER1" ..
	"Yi2Z4wzh3WWaN0ftCHTleY6y9n8ZFQ8egxErVO3XnEI3FotiFQJhhd2W8/CEiksN8W6iKameexNb9cKhf6ItwS0dXPHHegm+mZxl" ..
	"bcvfu51BXvYaUxLQSuKIgZqExEcZYTXb4NMf2OjRWOGURqNyMWg2pPWkYYmZ0Iw3Zk8j0yvKmzeio2H8px8bj9rahY+0yMOlxt+q" ..
	"HN4CvLgFc8ztjTPl1YvKH1ZOHGyPDk86REMekmuV+oif7rocO6Ln/3YxEw6KksPip9kW33RktotzTre4qJEqrxB4BSJkQjnyMUYu" ..
	"nHaEEsFqLj+jPtj8E9v3aXFVk2+0s9XCJjXDdpFvLHBi8CfX2oY2033B2HkpAhhflMNCny4QpCcvZYea/vubY743Hgp/OUdEbXeY" ..
	"ffp/i5EEf/CPmrmnFEIQgEIRLuCiZmRHry9fwoXPQ1mRRyiKI8+vvFXT5ZvEIf3oZtWtvS2MudKaX0x8/NG5F0mEobpMMt5w3sOv" ..
	"hfLNvaeZFRlfa9A76zLJdRhiYdE3kogX6LdlWwwiXhJr2HflmGE+FKXISrmOic2epEx/iLGI0FckaAl1mBhyDlPCgyai/F6basgX" ..
	"NX8tmdMe5lG63ecyzRE1iPcYhUeuuP2TCejU4BYLbrmSV1BbieOLXloUqJnXbCp8RbRQWFv9TtZw9n5RYVyhtAp/PZtc2f9wAMqU" ..
	"iT9iFrFX328TN3GlAMgHpXGP56cxJmJiqsjdshgnbLO+WvZvmlP5/C55xaZ9LLQVBDkI87EBHjWt3S8O6CjW5Rcpc6pM7KcKUvBm" ..
	"PpTzlsVBhkXtoxa3lsHYZqEvIRKzo+W8rZedeKUb+XGRstL2BKen+a8PsEvxC0+/D7yxMhXDHbGbATZZTi9cNQ0u4MnkqVa10lRr" ..
	"/aS0v3NcXlSuhcXdqL3IMj2HVNc6Ws1LsG7TY5EpG/eUBzhvpgr2z2JYl1BPKWfhyBbKlNxfGrgEnvBuTQETyRzOThiuRzg+I/Eb" ..
	"kufKkO91tWr2r3KS39sUBdQ4emxqAVKR2pCk9nsHpj07ETF4cAcSRrBdJoaTp4kujEYLI0yGBFe6IQuGfHY1IjpMK67p4GaXwCXj" ..
	"vbdiYUEq71VfJJVf7prKTB8BTlXFQrTLXDC1zAEmKSJHbZRtXu0EELvIajPbPi/x2jwQojjrbdF3h5+qHsxLQ20YEAMzzJjCOyLq" ..
	"3ZheKZ2uBIJzShiv5uLybrXxNu0Rl5R0+Wb/r4NJJA4EBTIQ8nyCVpXDJNQi+EWpkwAfvGIvU1SugWJj3CiASna4bBbvCVmSnJgr" ..
	"RUOnAI29ggHa3eSGDlE4SCvA9g9GBCvEwfTDxyHDITE8ALWNCQtMSOCW5YoIeGFguu4TmF6TBw1I74lTzprsagU+1Rcud/3PUZWD" ..
	"jnVwmmJRPhJFI03RiRhxAdSrI3+Qv4Q72NsYnEisXER4ZxqEGtVJbemW87AvB40nr8E2njYuelIgQQjZYkgJz7Hes4qeC7UiDldx" ..
	"jy/sS6HfS6gJavJdVvsZyDfdcnwixUdTGdaW70+DY4CxpgaMyYoTwuwnEeEbt9HV9wcWOzFV4jqByYrGTgTNv6o1GvfpoO5/4PsM" ..
	"Z+MfIGBbG+d44k1Ncekf9k/h6tdoOvOlVeszVA/ZyCe/J3CbdFuYYeWhjHkq1IY4IftYeC0rgv7L2z847+r5e7p5LcYpCT0hhK/i" ..
	"k9mRPFyb1fS8zUQTpblxBvWldwpgy764d5VgD8g4wpI+9q9GJzoi3ZvoR7Wg7C2EPtnM76QE26cOPn/CV0df7RR05zTG7oODKS+K" ..
	"JGc9LIH/0VBW9ehDesxQ+IMd0ASu1GKBTYW/WkuOx9GC5bwyAdDXWaAADIM4xzG6i2j4pUoxcHyXUJHpQo5UjF+HUi1JkGUslNBH" ..
	"7Cs82od6bA61rU1SQ7Or0G5McDL2q8OUojEJxIpFXiL9aiTIMAOLRy0BrBblmJeWE+fZntpGy9eZne4RHvVDRk5vlkx9EyzLIpBv" ..
	"0jAO61ngZZunNae49F2bxGHh8xrvIOwlUrc9nCOHHpxm7lNuW+lh2Rrbx/pYWRp1UKxpWkahctpGMYxPU72P9q+BJV/6gjC0Wbkg" ..
	"3/I5zUnB4JNw2MdQhXeHCxT38f/v9Q1T4bEDqK8WcTLs71omAz72d+7sW8Zx9NJyZcI5YTnoY8ojkUTF1GV7dgtF9GsFDrS0mUPV" ..
	"OBx4ExlLDZsQT1JgG/f59Tz+JRVrDOxFcEu0EcYSdRGzjFtHIIVzxvmelWPA/hTIoDZXjtNypGxQ3tCdE4dXUCe6rHP42IHAeJIU" ..
	"7pgMDoTpn47NS0r/pjOqdWtL8++BE5MdhB4fVTN3QRTd0KGtIBSW24F+x0DS4GndP2ZdCHjHGLnXzTTNs2kgN/KG2q6rD89eJD0d" ..
	"HB6AUKYi9Z+W3ixW4uSwvHU5N6I4bDaoBBrvF1gNAx+BIIBcIn3pjMT1DU7aPnyg17WuMxGtOKIxeFhrgn998ygjtLME8shO3A10" ..
	"7V77vnSfqgDKnHPr7sVlifJYXHLg7hCeJOOqNUXICIx7aqkOdicu9eyrfwLfweJxfxaQVI9nYeoJBi1WkmlRV17aHOrlnKL8PiqT" ..
	"Kf6YY7ptkd0Q5oj9z3UdNF4AebDVR323MvxQL0LhGdpZ56pxqPjccOHXwv9XTCsVbw1ZJe7+wm24d48KWPj0HSeJY/7TN9UGA9JB" ..
	"go/hDb+lL96UYVdl0jD2yN02PAI/+vgY+jqi8JpYH0QYZLdVbsxyYzXDOQRoapk3XOmmvV79TWBnTvfb4vOSmCSsC3/bOYhSadlY" ..
	"GGoHq79Em7CLDWc5rXArVVkbXQnk6iuIRnyw1RyBV23J3A2F+72OMrd+Biy9iRBKE9yGxoAWg9sbgXXF+Gt59BrxLsrjNVCwpiuu" ..
	"h4P9Ed18/AuBP1xDjy53fL4Ws7iKmaKwIbGvEoSNiBF06lYyoX3kN8ULRCTAzrqrMCgcndLrKvviji8IF81h3kCrlriPLjMApySq" ..
	"OOHWPS1Ytg8f6eg2ydO8J7UHPHXSgJWEcA5Y/NBPGDqUwQ2MJ4cqg6BNv0yjP2Ig88N2phrc6klTrJRkUB6wHei9pkPQ02fO5UO+" ..
	"MLTxgAhhKvkv+QAonUNLKlaR5wEgZPI2DLpI5oABqZGv2jqhjRu2iyTLlV2j7p5IhMT1tvQ+9gGZKKQ7sjvBN9eroDJr2wjB+uQT" ..
	"+hwFomdJsUXuHb6CA9HqWf4p5rzCzgMAoLDzLeuVqS5cv9NUR4Ac+Mee0/hcXFojI7fbIwIStz7Bb1X0Rn5IN/eH2ZRuTBguc1br" ..
	"/jDVJMlLISgsFYv1lOVG3oK2hgD3sri5k2nTErAdqm4CoRtQCQ7+0ICi1Ag8xSzDQR+w0VDWeeQaZp/5dsV5Anmjd2wozC2dnMIM" ..
	"HRpl1RJBOXopcQO7I3rKOOZAFS4RnFdOCXEH43R1yX+4xiPFM31+sUeTP472Mk0SNdLBZCFdMYnYnd6FiBvGkvhLhhwEpM5sv/QW" ..
	"5AvS4tetYtSsDbobNl+hEcyqSX5VLsAc9dqf5EGl8JqNbNYK6SYqmzukFbYJc7UyilOtE8m4R7MsOdW95C4W1nqBa1Z0+9Y6Eb80" ..
	"VnvhzaiqVJsydQDxOFUuJvF1pucsu7iZCo/HjUZgGznWD8fv7r2Q5eA4XSKj0AG5u1ANLrPGkmVhVrg2lttu8aEsZc8uLSD5uTti" ..
	"FXvbRdA/eFtHuRajxaq0nVCjOG4keI55cKj1R3J0xRetb4gLHGRdKIQzw5l62IqiQyyeTgjlFHdt/ZUEHARCQJs6fHjUXhNgbd8f" ..
	"NR1ID0JflsZ1FsxZTLjX1RiMPd06qlRP/o3pDNgUAxBwl8+MOt5DnJNyoz7d4+catcmNGU3djU9nRWQhYTgFiiKKIRTJx2bLUKKv" ..
	"KMcLmKRfXcocv9TyFfCwQoE5DZztWV7TyIJC/yZYVmQjFoOKmtrIUzN2BZjwT4tpYGcPYcJNt+wzqDogDZ5Cx8Bj+r1OqaAt5i3S" ..
	"TcrjzwEonf4X+W3LENH9tiX2rnp0jcpMwe35T2G6TuphmYR/vb6KLRevjHmjEL/aWOrvfAQb6ieFfqgD0dR9nT1Q7+yBnE7IXB46" ..
	""
local PAYLOAD_P4 =
	"7LMkP0bQgwKwo/YLoian8QgcMww8t68IMCpf01WPIwV8TdCtsWs1CVle4ZtS1OIyIskaKiItUEG3LOBIDTC/0qkQxVKKY9QZapxd" ..
	"IqXpSESChvAwq+TxH5ERsEsIGvYIMZ2dI7wFTjPySQYCK+vmN2xdIQ1yJO+QYEQ8X/bF74D6RVInPZWEzS9SOsxUeHLNZ7JmI3Gg" ..
	"Ulgr7efBhfNUne+7kEt2EGh/QIK+HqUcDw0D5LU7PVN16EbmBf5efofeXLqrrWxgdTEFu/YXU9GYNBOcGYqAobPB8jdiecOwXj8T" ..
	"XcN/+xlAmh+rylh0lFOngH/J9avSKziMFYpeL1DFwQMwquSWHv5VxSMhNMCPYaxOC5GFXUD2h+PKbX71mIXjDhrUOQ/ZVv5nqpmF" ..
	"25KFgg0WIjGIFQCMcLQUSkfEruJMBkE1Sg781WSWvRgxuP/DkcQW+/LkFs58NiNzEkqI5jXzX92XVPRmgBe1UnuDKAJxVi6kA/ol" ..
	"dbYSnhRZdx4/mQ+NiEuMJVRMXe0PxS7R183FSv1+rGMd0mNlvZwAitwqj9awWVOeuQGyEWMGiFrzSbwMVtbwFECwPEH1gBvYfgy3" ..
	"fT2TLkVMm28BCGj+mBv5DhZndOODun3wtlcmNCJXZT6NmRPgBQhBHH99CYBImye0R4YGOm49089QTtq/MQOgGOm8LTjreFci+JMF" ..
	"5Pki5qdd+T65vczqAPslTd4grRqoRhyO3+cbGTUv1c7ww/gTt4nXEOiPWxGdGUk9Jqquwh3K2dtn3Bkb9GAxRMT857q3rIMYZl69" ..
	"Z/cRRoNkj/Or+GY2XDnbUCbqxFUZ39ha/8kbBkTApSdspjVnfAIEL9yZ5fVo9ruyED3COXGNaadU4VH12xoto1IuLYlwyehRLOhq" ..
	"hXuUqZCSSfUINsSsqY3vhWC9z/GqKBOelcjhEiUhBcbjfm5Xw7yIs4z8wJuJHGSN4Cyd//4RSa/PVYCrUIu+9GRTZgkwCpRXNRGs" ..
	"zNmtQRrm8AAOeLw6QVMjL3lkSeaJ9gimUSm6e4LPWxofiHMMtIHSGUl8A6TAcnHKtSB4mlRmUXffMKQQw+5l+PLn7ZKoy1XbprUe" ..
	"4APhYYQVeiRA9459lqS66bO7qYdyHDSlQgdSN9jOqs8bWpPLJe/djX5+M7Bi9h9aK5TcwmO73XwHiDBskkfybwfQsNAIPme0oKc2" ..
	"F7RGAGqs5ldCeEKd9HwfHf5jxlYTQQ5fLkKN2bX+VtJ4S2Tc2K/v0Cdl5t5l2UKhNWMxRsA74Up5QVH29JLvokyP7ku3XrT5P8DT" ..
	"aYk9/mprHCSPa4aEhP1fybEAB7LNwVz9afICylvIAyFuwrXcb57CrIh77d94pvPM9H31KjJV4sQEjBwNFUjSxRPKcHQ87N9uLouM" ..
	"u8uzuJESIb4vVZu2EZPxeEqcSRf+gN46KQtsRWkWLAg4si8HtGimUHSUqwcnm6OCGDROntUzSRJYKK/ej1onH1D3IEpNtj5VILNB" ..
	"386zTGQeewOIMgUKYI+sn+1b60A7oiyXFD6mp5xmpWU5k6nyQZai9SWsuRD5oJTqG2Qe226F1EUDufKnosbbWdWqdNCOQEXEd7r9" ..
	"SeEZIrbc7+rET4Tlt1QHARt/kAt/2x4SRt0sZk1njULDYjwkDzDqJ3g8cm2Q9oqjPdGwfWEElxWAoDTMrwUkRJA+X65ipOq1Jk9T" ..
	"K9e5uYmPoaPAylxZmG+EoDk7xTRww1PCQ/tiz5zYz6tKbR2bdItiactbc0PUWzQNQhMseFfdQvAHM452ccsc4c+2gxwRqgUP2FLO" ..
	"UYmA4+N+f8d1K126CvnG835jiKpPCRE6izdiCvQSZx5O12qntYRhy2U3q3K2CF5Vq8rm7dxJcFW960R7oIXG7KEdWqWHNzGlMpej" ..
	"YOUiAyOdKMjpo8u7lmJYS7zdx/Y3EDsQRRlMCD7BdhzXfbXA68hWioNKOSrksWj+NX1iM/CNRdm9Kp2kVRbQ1uH09jjt1htOZmG5" ..
	"DSnH7yMYu2+PPM470bzcT5JqdpdCNpFu25mcJFh19Wt9yVd7cie6CtMq3od1MXMwDSzCFWFC7jPB1g+n+Vv0qkxWdaXgSoLW8p4c" ..
	"S5ODqq4SzcaqLStTZPoRKofejpIbgLhWKPVO871xjsY2zazB1sA/Oh5UjPQ8+Yk2HCJaqogKm6Onm24hk/ksZJfnRNkk5k2PdHoa" ..
	"ablzU+PXPgtR3i99xiPnSVJ9rGjTxKSkZl1sysTFgTfAngTE+sv8MUOnB+ZTTBHaEwMuwi3LBcbH2ejeaLQ9OFxqCJ42xAWN29u1" ..
	"KQhz6ILpOdr+28nKXhOiaxORJtfQw/gIHxZpQj6dmdB1N6FYqkg/29ushCY/qeyC0HRb5XXv8QqFp7/HNlXwDcfJXRo+XxLbAlah" ..
	"QAK5tkmTM+ZETqWaOH+dY0dMjoNub6DN7Q/HVE1iveHd9KaDfwHwQiPZi5Rb3P5aEctSQZqrglpFLv3sQqqX7tTxNDhPiLOabebX" ..
	"Qx+OZ5mLaRhR2L9wVfcYtYewIbfKIbLnWW098F3N9aitJPHwANFeT5wb6X+HV65Q/blsH3+DwdiDHP3SeTl6GX5y8Z/KeStewEJm" ..
	"LgCJY5eaejLVcMa0MAmG98QFivIZ/IlS82Bqi/IIoiyg/PsN3SB8LuhQkH8XJdRQTpMeHzgtyJ1ZHdH55j65x/iao8F9WtZXVcDV" ..
	"ZnlBb69ePKlqkRT/mr69yNYlHpPRPQoErmIlKMjEOBr5vBRpSLUd8PyD+5pSmmbymVqVWRA1yueh9Wlti5r3rHrn7Kbib3PnGFQG" ..
	"K8CDy3rOuFQMaDejvUuwe0xEb7q9IRiXg/tf0OqAQDcqkNfjIWCXHHjsMaEfmEqwEW2ad0U7r+koJcX653GuWwcSD4MvZuOu6XT4" ..
	"PG7lh773L40Xqqv2EcChTicsBFpiY1bCCpiXY9oWxTIaGduUrSr+2NGxD5tLdfYmjC49krfISdSPPRRQuKv03SjkazHlFebuzCq1" ..
	"TKeR7QzOdt3+gf9aF37+LuC0AiQMPzH9SvIqRa2Z9hvzCdcS6lxHf82uYhaAXA2On/Mp5FRTaRPLI8v0j/OaRvS5y0L49Yf2TjHL" ..
	"Z9ri9FpkmXx1GBaAclFTsuypjA0zck6c0DB1TFnIRz5PDMu9ocAWNJa6s5gclSQTuxHwBl7jXp3swayncv5ttuZdew1vPQDcIrSG" ..
	"JZIrU3DuDcxNZPFJQuXUJscoSROQU5BFqe1WijkJb1VHLoPV3kgC/ho/7EH9MQEgb/W2bA3CQEczmWZSvjewHdkhysWTw/Aomcwf" ..
	"mMZOOHN7rgTNBd0Xt/e7Cvj4gJAmMgSLqSVw8LnshqdlvIWGcR/9haz8/OS0Dn1xCAfsHwbFmqB7ZC+aXIgOT+/GOSzaA/l3jchc" ..
	"007/j+WAeU9YFAVGLdObDtm8yMzbWECRl8+9q0CaMV6WwFLmoEjtUKewEHjWCr5w9LNpZ41LWzk9sx7F9BEh8vNPBURLKe7Y+Wh9" ..
	"FJM+WDmZdZPUjoGXwRkIPBZgMzd3N1ZLMwzOAdFRnoa9GEsfUt4qjThVPutqvBf5O0Pp/3PxJ/s+LbIO2Mh/2aalI/Ou2yf3bAFC" ..
	"6Uie8OjhhVq+Cl/jiqC/t/hJSvvmxW58TdVPoExnOL4V08M4SYghvDVtAS8s9wfZUZInM0eFmxlrQUMfrEXXuvD1esq3Cm/wtOHl" ..
	"jpCLz7pc4/7kWh7nNSUn7XHanJz72++7Oiq7ubiTlEMubJCZcGHcMwoGsfcfAR9CMHdYG3lMgGSgi/JGNXCsYOGL4FurbkwKu7m2" ..
	"ikk0ScLX7o/9Lo+YefjDK0kv35vczgVVBiTRBfuhUii0NZqKMUhYpIgBLm/IovSdTQIzkuRZng2aSCdNwezzmbfAo+sp7ijY6IVF" ..
	"eVr9+nfTyCHpetbysAZkd9a63WErcT0ZZtWG7cownYDm2I881gbS/T/280pa85m5rePhnqSVARLV21aPFzCoMkThNx0lg+qNeA2N" ..
	"W+2h1Kr0ys5UbnDcBEMCYAqOiDUeq/u5Eynb/dy1CwxjmTAs6I2nXs4XrtseMjJaNVVaKLYU0dAh2a8mEKummk0F7q6o8+WLSiSt" ..
	"qwh/J+RANtsMGyWISYlsXMhnrKv/hDpWzchoSGcH1Be8XsYS/3h/rRn7v+6Fvk6sdCztpLEcltUWLNu4z1bZpTJjPT/g7hDMk9Tb" ..
	"+QEbSdxDZiteEVdScwaqIuz4YbLVDUbhgENH2UnJ/gZl5LqWazbCPwep65p1ktAf1MDbge1clT3gEZiQG53fkdk3YuMEmojSMxwc" ..
	"WiffhrqXia+NECkXGRdutRfZJqakcpKoxHI9vLmhVFf6sKxP/iVrjpsanqJ53oeOXbMxnsDc328sgA2gWqUHTcVrQxXlI5Yum9Gi" ..
	"J1ekaruNagORscPTYH4Jze9CMv3Q4K8+YRwBI1dhmCuWvUZZp9atshSZej1d44o5P3h+foZyjzMWgXWZ4iATKdUMaoMLgV4M5b+b" ..
	"XD/m3k1Kh387xphr4trNKLJ/ljMWCOvD1S8fHM2D5ZA2CR+TWRVo8syJs1+O+2hL98k8vNdA6hDFX+Sp8oPHyl4feNz35+U3h//E" ..
	"pGeh9tHnhmpfLjzljepvC0PLHHypx3t7fmkiGfFg8fuFVKG885pS0U16lb/vWEkZarLw2IZ62+GRfD7Ca9nyOrtz9QyZkqQRlG1g" ..
	"JU4kxH7s/I16IoUKFtL3qA+3GLxuQeL6JYyFrA4JwLmZ7WJJRqY6DdDaB0QuF8xjSTML0SJ3+ZvcOrc8aM1gtTWCe3pDrvmBbd0B" ..
	"qVg9lsME9urfaP0wSTt+yxWe5soJdkE0DJKeQ3uQihFqsMCj+f4elpqMieKeQHibol84MHb714iaosK1fm9k2dHSpqrzz2szIWNR" ..
	"7a1+KHLZZ9f/NjSJ5hTn1ZhymOKr6IVc0WiF+oRtOpjOnLREtDHgL0gmG3dAD9rhQ2+FSyEOaCHA4juqGA/+o9TzpHRopISm+a3H" ..
	"ZiVBjUFqikX6Pv9Cbf6Cc/HB3zF5mcKNevbnhCyr6ObQuFVFg/APnbNf/fSP030CXrK9MNCAMUXuZhlfr+jM1bIqoC10KlzCE8Vi" ..
	"GvpIfRe0NmuT0xovA793i63rqdeQsvZrPgQFsZD+UZ3ENrZ3pT8wuOG5tCdoh3Q/BPRzeJEYahAxe1K1/fYm2MLf7Cxlzlf0QSjc" ..
	"FFvBOg0dMy64ixYxzzy2RqVwblUgqZuYhTp1IoJNtVyiGfH8F2pB0lz+RmEOp9TTSgIBxOgSfwMIAhkrCyA2o/9nMF7GHbwD2FIf" ..
	"+vQ/KIEa9aGvrw8wVEIA5pEav+c1+VlXbHzsnOhz4ZRGblGtof8RqI/q9fYCt7I5pN3/CSKgQCrqpQ4IFY0lwjy3sn8D3ZX+kgau" ..
	"Xm4OQGY/6h029TzeXIyhfTb/3Z8syvplnbCrBtzT8usTdTf5v974ObwWdGuSo3zxSFlKv8ZfjlwW+hoXqGdjcXeg/F5iYeM+zBWS" ..
	"vULPB6lRMvYQb5KFbjXfvxH46AHR4y/VZAnivo6VmEflSIBNjBp5XNRxLHZfQCR8dM1hVScfvJHhqG9uc20jscYygTOabteCCe8K" ..
	"cA86ewCyqqa+cTHqN9CYv7v3fM8r4o3KZTc6G+057F2LJv9OZZecNf0e9RFRnR4pk7SE7om3DxOunc+g31r60uE6zuW+KpFraH+h" ..
	"dJI+aLfKft4Dm7AsPWocJDriXkkQATMsv+68YA35+IxqOZJ/3DKPL+ovelbwaGPOKoUyGj/CAJ7XOOWa4Zaoz5FS2eZL/xig9q05" ..
	"7tJ3Jn+ZKQq3Z27DljWCSFKbH2+61GoQW7IYafOmHXSmugqzA/J9iCSRFOsOqla12gBf96f0cO6FOPis5VctukTN9XB9qZQkofMv" ..
	"cy3icBqvjTS4gWAHva+m0ktv+l4RlBLGdQ/ZIM5V7r8X7XDBXSIsYLGjhGfg+wKfZk/b/QkYtfYAvowiHRB1hRAzBmzR8ct5lK8t" ..
	""
local PAYLOAD_P5 =
	"2Q9GbQmecTMIwQSgPpcVDq3pjiGG3fGWXPzdNoHfiz5P5rm5Qoir69n+uC1ceLpAFcE9GmlW3sISOeE9CLDqdhQDx+KQ/ay137+j" ..
	"OqC6hKxlfvBL8G+1Of3rEbAMkKJIcSw0r6FDvXYf3lkT0G52WaXmSJPcCYQYgXbX9TodFRuQE/baK5V2pkF8IUpO91o651BPU3P9" ..
	"wAmxl33wFTaUzUtEaVedETVsvPoD2kHnwBVzbOHMUnJHtPl/vOj3kpQJKE1fPTVrUvXA0yHxs8QcrZxUZQC8rcF6xJf6TYKWfVwZ" ..
	"amFf5DS5kRVE3wo67qmjc+0vpr2PuPfh/guaUJAjxde5bQXt9yLl2Nv7HQe60+AAZ7KlRNl7sG+mQH+4Mhr50akqMzL8FuT7+b4T" ..
	"7CgmHH5Fz/w9sLLf0VMcALtrBvyVvaum7PgLn3O5u803yoTB650OmrRHkyqomY8EQ3WtPtcf0FL4i9mCo91D1us1BHjs729DP0b+" ..
	"48lVFS+tzQRnBq7MdALeV50IsjkElEHJHoZ0H9+cX8iJy0atxfNFyR/dc0n93DJ8l3XS7Xod/7FiLNbv9k2c2IY7v/ZgyJu+XlGi" ..
	"RFGUtpY0ewlrUleKE68Pkl6y3mPlQ4XhwoeuzZNzQMY+ln269mTUpOA12aXliLm8+orehjxkHetntnH4+I7Db+gInKo+Ob9pMz86" ..
	"OPvVpqBoPduvfxP6JwS6KxtLPx3AvDry84/BwjhaEZWB0Aocqc4wsUmzXEctcB0QZ55eFyIKEUxh27z98tSpKHpm/qR719EHRReH" ..
	"fX5SvVxVG6KIQpxGFCxUEXQw1rWDSpS0fE3W/QIapANSM+snRwh/W+TJNcghXHVvI5z+PNWzC7UY6N3YYDkBm4ty7wHxvTH2b1TH" ..
	"ZGRM/qEHEn6gwa/XL3YfBNnUIGTRcMfXyYnKEe4UspS9MImSIOreQYxGwq8FAey2BJLMfPbjxpKL49nuBcAx73sOSXP4yrVm9qg6" ..
	"k3vn8MaghjeC5wTA2Oxk6on6rEGan8MbARiD45asNs09Zxpgr53N/f33pqzP+XkYiAp+dHYcDUuY6krTYMf2jkqFhOiWSPxaJddj" ..
	"pmA0n8Mb/T7i1AF0TVO6zH3lxq+oyhKiFNoS0cZAeyBNszeCMfmBXe5deTF9OEk1N4YcgK62/WQoKzE0pK8PuMKhYc2GR5ePzGN+" ..
	"AfwhoDO+Oy7xFBV9omb9nrcG0S2uQQVYUYdKQin6BBAVpOWqXDStl7+uuWway8cTBMQeFaIuz4IxNasJWekhPb9WbggClS+//nOv" ..
	"iUGcOxjHvOjzJZYUj6Vk6qXz9GgAi9FT63H9xfkNeQDp9yREB8fkcZiqeJ1BLsP662UcgsuYOmKou7gla/iSIw9kE2ItA6yY2n88" ..
	"AEB6iPuyXqqLBZZfoEocUMz4Z2TgMjWOy0mwwIWG85g5Mr1VP59FWqCdKdURgT4cyVmuMdF0EgTwk9UpTBl3xcj0mF5sIFj29nAN" ..
	"Na6HiWC3aYamxmywlOgBTZldcXMz3s/0Ei5F1hbWTi0x7c8eCFUlF5pU7zGG4V4tS1kE5otshrEZnIjPzxD5dET9anNEQTVf07A5" ..
	"0NXUKzoeVW22dEWW1Fe/WPagJGDgH9T7GcCcWOdJG9FhWhyj3cePqn3JVcm2w1x/1HGCPbHjEA0GI0qejHtFe9/TEy16mMceNGew" ..
	"dSeJfp35oV04hw3ZSC8B4yPMEi/Jy1xO3L4WaNNau3EihbiSM+lbDserDmHjT6KYE25nJETHLU/E0m/6vS743UenubT5NlX8zQwJ" ..
	"TAMfCGiAH2+WaZffiA6KRSrKA78IGH7MRk9Gry7g46/UP6z01oG+91w6bXJOfMg6YrrvEwcuFNXrZ8z4cAnN8fRzvIsLj4EmhWMe" ..
	"khnzXMHmp9F0G5laWZe/ih/UqneeJ3lArPbPEJszUgSdtJlETTtJIdHId0ocgF+lz2FsgJo1yPcoS0PwkhtY6fwYlQhAYwOvv7LE" ..
	"H80GEp8FTpO06aqaXDVU56s5jeSVtU8DcfFPfMfmkl8o1X9VTRoluHgY9D+RN32KbzCAq6qxJjf8bkzbecgcsHIGq+KRltgEQgsW" ..
	"zrEeNnuhFWq86HY4F0i+HEj8UZFPKjDZmZmOB/iqpDekagxCMrx3AxbDMpAKHelc+P7oNnxWSV1omMmtBmMm5rwh06Yn3bRN9ENh" ..
	"c7UbkPtKRDbPeEG3tCJ1lWgO1d/FzPCIULxfhR5G1B/juJqttwzaf438eaSbhzkE3zSfrFpa9qPTZZ2GGHDw/vvOnpnmUyJi6+MB" ..
	"vk+5fMAiv+26jn53jW9kt7XH1LVDQquvMnEKrR5bx/ZIbTYHZ9eOZao6xHaEZK/JZQaWLQSNnU7kaW4tWEoj02c8yvwrDDWiXvDG" ..
	"u0P9UpsY7NyvTyI8Zy70IUDEG14hmFlm6GQaASqgaGHG2Jfe+Fzxs2s4CJx1sR01Qm+wtdaa6Ek5Dw69pL/9Jz7qIulVOFFDZ/f3" ..
	"8y/V1uxZzkqmBWGXBGN/Zfnbbu17kbJ8eC1vJGSc0cvjJSBUE4hhtRRX3Wb85MUf2CLZxqds/vaFDEOOyZ+0K57C4l273fyzYI4O" ..
	"5974M/GrULkutR7ZF92YYXSBuXS+CdGSN2RAZrQ+ewADqHwxrjdPLKR25jUEJJYC2oqzRhSwqMVh5EL2yX0VuCcvIN3ZJgYDDwRP" ..
	"HG9iobMN8Uz593hXr3vz5WkGbVWL+vBPXStKnF+Fms0pQn45nYMQquGQJBYPD2iSlq5eU36XryD91fr6a302gTuJ8fjH02Q4OMmh" ..
	"bLP2Z6qSmm69zCN7eTV6NaGh9IXrpASbyDWbPxRdSzDwIhKkdWFRD03ogwgqWTcMH5Irs3JfWR3X2V9mDhRJU0cQEXJC+x9JES9h" ..
	"Hw3GTY4ta2yw+jD+62JxC1fe7891iT0/oH280pxEuEWklRtPvBighMClvAFnbrMA7+oijfOEX8m0X/aTtEpEQCG64V0yY+fwxUgm" ..
	"ZSH9Px/0/5m+DNnIgNVkgR6vS15h09A9WcWN8GwKnzo17wkClrag/HAobMgCtITLMsMhSEpMteYP4LYrCYE0KwdwEqqX29aIs3FN" ..
	"gmpHCkKdy9NG6Yh7f8MUTn8qn558kpoIVU5/QgP6C3xHQIQKKa8pLmmxuJLuAB/YgSZj332PnmhrQD2nCao4vkBtKxwNUVUGlgQt" ..
	"6fFwYcDI0IYiJehbSAQzWhZx2orgXQWhGByviAbQaFHDTJaxzvOtl0n3LE6yUzbfJE8uX4ZkXbJy2imqkMsSRPTc6bC0Xctk2kY/" ..
	"rKatTvmJZSqIPK0Y4+4B84MT+hA0i97w9RaDek/VFvUt90cQD4cQdekmrM/ma27A4k864nSHIrao2/XM/658zb0XRnI6vWOe8are" ..
	"i8nPl5hyioN4FUg04r2Tndd3tzOkRWkiVwHji1ISEH4kEJEJl/0gp5tgcDtY9bjjNk7JuhI2aX5bn8DYgcNoOG993rOPijULtAHq" ..
	"WDjux+j3urG6GrqBSxltBf/U7ogYF66qyO9qmXeKR4BMNQdndtPYRZSsfa1VObUtuZSZ8JE6Gp9TlyY4g8Vqj5J7y/IUySO3q7Eh" ..
	"SGzAlyB4/OuDXRh4RKf+SLlQiegGFf474e3sqfRJeHwO/Yl5TmzP26bDAIMe5iKfo4cjRwWdOBqtOiQ41+jwNZa3ZBe/fg4RcEKG" ..
	"S530bEZ/vy6Atwq8Mgzw+oAY93wYW4hyFWDcu5YS3fPsreX6e1Nz7HrE+0+6F78lga19Uq5PMhhBPmqwav7UkoK1dZzTGverIQ8/" ..
	"KI3knwxqUMNr2wusGBywpTBYJAryl6ZxmMq0h94NMC+iONdfVMSiBlo5CGtlla2BOPH7uaPfuIOcDJhx+Y/ts9RW/6jEC484gw9o" ..
	"GI4yhf8E6QWiR8jAewyVePdStbcFod7o2kBzV5XqRGHIanyNeZS/aVTNk6BNNpzSXfmHAEBqG7fGn/mcR0Gcc6M2NyNlNpwePrY8" ..
	"X1HgD9dqDDYUILwa5W+IrhMSLNSspEQ2t0elcHeik7rCu1RUi9crtob+UlhrzExWiPZMIrBZIYMJzhhjI5B0oWoh7izRZH2bCeh0" ..
	"lhh+ot9lGYfgeEPSDuKSitwZypwWop4qGg7DhANUaCk52zgwB+F9+OxdqBL70RfOFV7I91WJzkiA4LoGauR/k284K7tpKGv74M4G" ..
	"PGBntptl9m4SJPfJ5+j5E+f9g/QAmyDUhsvaW7LLIzZz9QSH662O2tA4tTdZIjAAT5hG5o6vPHj0J5uEWlQBlLQf+cOX6DTaUMf8" ..
	"rOyMwFqPEcvQsea/ZdM9YBCFG/UouFqKNXyMQIL9yHathL61qsS81mx2oOBm7PdfFrX/fLLNPsTLBjbnV+dcQPx+QqaFTEqD5txQ" ..
	"7u30ZF4ssPmZK9/ylHPnoYvYC6O+P7LkSVUJLmQTtXTkO+iKRxW+uN/LR8j5zQuIyXNnoYhOg4bZTxL5yCai6msjS7Wdffzklp3X" ..
	"zTWW7INPoV4Zc47XXCv659eOOz2fRpCkpWqsAHZt2s4h68Yfi/g7Ou+Q/2057DsPf8s86TP3jfokzjG725jIeHWb3r4F93JtGSae" ..
	"0pwkKyXNkVR4ENPRXPWWt+H1TFCFZrkgd51QcRBg0HvFA6r7TSQNYTibCMG+P9aPTxmuPQAVHOHVHklRVmfOp1VZ8GbOMHbPSwKd" ..
	"kwWhOKl8MWvwJRK2+n5yuD3IezmbAOnDNDLa8ZQrJxEUjNuy9+FAcLCAM/4cvzqzX9vLKs27xIorQtAnqqS/HTloFSYkYMv/gQH4" ..
	"/rUQUiZac+sHJGMi+VerUEODtnpnBa+X6zHqIpDlIyg+YDTgudNr08FkyGRRs+iQmfZejkvKF85DMYjMl6VviYY8qOHIuK7HCHbz" ..
	"SkaCe7UJZPnX8MkbUke6tOUXilYvlYoyDKDX2D4F7Iqc4sBvUxiZ4xJ8b5kXxpxEktpFyQWuYodI2Lu1QMlrUGfYlurZe1bIzyuF" ..
	"yr/iEGZ5d6PfY8vpIhAFc1BYqlpJ0a5z7/mGfmbmZvOpAuw2Y8hICPoAtil8Z0K3rsRfH7b0rPBbkRSSVjOsMdgvKpjUlFmDNSTx" ..
	"py1TMweeSUVyYYdEsklgxBt33xFyZG0anF4q60P1yO79Q6GezDjWqbESFAzBXOJNyVaWfWloGiJD0AR4iav+ztTV8DEACswKWjt4" ..
	"RwqosbQTZS+NyRVsyRTeQybSUH2vVCFlHSq78YE2wi1Xm0TiyOs1qjz75uaxD+4PyNovlWjQnfnR5Hh/oEuHnsON4QgvUrDzbYVv" ..
	"gih83E7cUIvlQ/t8hqUVVV7gxe6O2FgA5q7YW+pm3JIlev2zmj5ehfiFlb5tKOdNFDK9pPhSKBgaSTVa+R7IeN2v1FhuXa0RpxAs" ..
	"8C00OTmRrDJ5fvCOZgXzoHGoQL2eJwK73bwKaFo39f/kaLUntyp8LH9UZ/PFzD1IjjukWGorvl2TGyg2YFRuLW/9MWLchWY/9zRs" ..
	"nrfdqJvCao1OU3iNCuCuS8UyNE4il6FYbAQMqzeXDECrmOuySQcWGkUtuN3rGTdbwNkPYLsTo5o6fjqflkv4lPLT/nOVXz1Cujcv" ..
	"vgIs/vHuMQCSjSAxBu7aiH9HEcFlu70zf02t+kwPG84BJVYbn7JM16VO4CdH0xLNBCEj9ycti5yNrFyQRe7++0GFMaxQGK92UgVo" ..
	"HtvqzC8zJsVhuCJEAGGAEM9La0XaLdi4SaiBkrbPSbGm0rbcsG6w3xUHVvZm7gdbA2GonvzVaNDkZ/4GG8yi9x0QGWjZfGDqnyvK" ..
	"Xxg8E9XtTg99qF3EaTtwnU6oqpkdS1UCJOblnLnD4b6Uhc7TP6QmDXF21sp8dYjzq/9EatNPvqowfyQfsr56O+J7tfzOS93vLDoE" ..
	"c2grKk/W5Li6PGd8cnk4UhB2XzYpy1lavs/CylCkjjhURFE8mFpkCoaatE3Gb7Pj73nXpmnUFra7yFAbT3/9nWtI1l1QoUIkD3nf" ..
	""
local PAYLOAD_P6 =
	"6a0zDsZoH4NiDqwlw7AVqN/yDyCu8RQKrqOAy8F6iuDLwkmPZ08MzoB/S1N7qxi6fdQc3NFZUFaokCN6XbQSJLujHFZiSDBuKdhz" ..
	"haUDMdYAQOqV04JJ5uKKwHQ3p3Cu8ATU6yi2KU4+0raN9AWX7LCx9T+9Fd8M6ro6Dxj2wq2jFiMbzJbkTLsk8CgkCvIZzhNR7vym" ..
	"LmE2ufsM0IPknVGoLaDZNd/mtImPd0Y3uHo9qNxMkLJe2QqQAz7JfMrs/L7OXiPDzz4aZemWMRqG6m0vTZia0D838DHMpiVOoa/9" ..
	"HcGFH5Pwbc7WUkt1H2f3z9gsimaMB4YBlEw0w+nfHpN58JtYHvsxdTY9F2ridLSyQ7ebG2HMIveyF4nsFitQ1eIjRXI3q7MQtiqk" ..
	"ReXZNF0T4mPIWOFH9JnLtFh48xwDrMTki8wq8Y9AYaWfTvpMarc+htIJUHgbsC+45O9rQD19SjjYRVVo7dL3TMnODF4rMFWZR/bi" ..
	"jkGIIFu+WXPa6F7SkmpzU6OdrKohcOZncPzHmWW/euPVCaK9biYC6MCgDZLgWoF7CgOhh+uuZQFCeXdb53MnE4TJcQySA87ispMm" ..
	"YMJxvAcDmiq7tRTmkOoeipn6MOnJ1qcFj+Hj7kxojX+nrikXNN7MWWNlVsK4ovFgDogU9nJWpo2o42uXjcePjpTLo/Y1EHIsECIH" ..
	"d+VPhpaWYYHb/aOrQ32ouVOJ70AosXNUSIdaDn0KmZxYfD3A+2yr3xUxKvx/ddSE8ZmcUKRMdhQggnQR2AzmCCWaXxDkdFJ6BCw5" ..
	"Ht2PcgTkVeph/GshyULfBrfcxChwbEXiFM+wo6TGpdIMbljxkY6nEHcK562UQVwbvh9wkKICXcCg8G/Jlw3Z0fhGr50DxLSnFffU" ..
	"35fo5On/mNions32DcT0fwc2k/TeM9c92XFZxer4fWD2zRkp+NkRA1FlXIPMmU6GF/HMuPVTm5vD64JnLSynSz1QNfo1vMzXt3Yp" ..
	"WlxPrlf1JSxoxs8GREtMHnStepidIEpIus74ixLtNF4R3Ny1V0fERonxD+shSPLOEPWCWCWh87mWi9bqlA/nZOq9u14LrG2Sr4fB" ..
	"l5rAMaktab7eWskeINJ0U7G+A8mrRPKdiVQ36TSc1t52qiyaqqU1VBHKGdbRrDgqBAR1Cvf3VHbuPpN8zi0TMtWP3z4UzaLHP18Z" ..
	"8r/s1+n0BtrDBoU5xOw/gH7wjjenA4p1h1Bqq7lHRNx0BQyUbid/iWnqqGtWw3npjMrNZmXoPwK9Hy9SC5Ef/NEUsg2jwJ/MCcn/" ..
	"RpsSb92Z1tDZSkRgxR+HFiJ8iDxDimGv9zxM/IsA3YhsDOf9ryB2/qEA1KVUiDZwlYY0zwEai0BAkhH92UKuFyug76I+HiaNesji" ..
	"x5FsHAHCzn1aNGciULI8dW8k1605BSld2QR6TOdSZKEq2+RhGNcp2fKtMhGjOCicAe+dgN3VICas+lkOoWgHyJ79GObutzfsFcLf" ..
	"GzPrNZJIa3Ga7X2icWzCz3TucaOAm5OHblN3dw4wmzOqusploz1MOM8tILBFHybGsanLi+wODzfMm0wLoI//W1slzR+58xFxhkXs" ..
	"jv5LSWFbS0GTrQ9zUfAKzdH861RXQZboontPgxXDs2K6tZ8u0OxCqXpKiQMQjZAw73E46Qvgz90M7YWGIYhiuzW7bKl1gJZ6k3a1" ..
	"eTkaMiWyLKFVZ0neS40jnCC/1QigGcfemcydXsi+jG4h4OFqjRkBmFuCMBvgyv4+fD/PWZ2ztHa4NvYhZ5lTTyEVgq6WFzs8qWLY" ..
	"mQBN4BVQG0BtYCtX1nM79z0dzE5VA7aU2wcYwqiN22+vfmrKnge7Ud6man0RNbZANiJy/L4ilXImDNOZPps9kgLXW+E/aL2YHc6Q" ..
	"Bg9LNVFwtjR3Kud1yX/BrY2qIio5Ue0G1jt5Vc4Ln2/tkngB0yyV3DdJCZ2rgzodGP3iSLR4OEW3X/XHUNS1JYBGtCbF7jA/Bvro" ..
	"2xlvp1Q2BXX7xOAXF5jvc/aDGtyWSc3NvI/QHDLyP/8mtXtoGkOkOka0i4zcdzVKA+T9fMO4te3jlXnOsRqldBSc9bPYv7LrBkLr" ..
	"pfNf5XeJViu10f8ajcZ0QMifeWC42KyyPDz0Oo/0KkqO5S7CjcplHeYv64OYDlRx6PVANmKyuKAERTA689gaO8r24lyZD+ZNNJ1E" ..
	"n7amZAKRWWjnEw/4/TtG3yCDnYm+fWtpUs6wZaDCcBU+qHhfj16vpSXgDLvZwm83nD/2/yRyiK7lkcsZAGCeEU98mmwYqwSWECKl" ..
	"REe1SoJHLACpNphjsq76ou7rg7Sxsp5Ghq0Rt2MyLsf2MSypyxy7xBAniqUYLMIuDQI49yjjACb3KUIpz3nttsh1pszvCrM/EMIh" ..
	"om4VXee7D/7/CgLyKqWE+TWAVUsaQrDoiywW32FcS7tyzqxio1oFhTZChsTsPbKD8JzdU0VzNmEouk4q5pzO4Tdxaagb/8FQ2oOf" ..
	"1pPXvQ0YrR+4WHutb54itLP548GU8KnEA9HM+Ap710BaQEON/NMlt75o+kyUh67KjhppXXwQROuPqoV2GuHA8FwYg35VCQgqHy2V" ..
	"p5Zki/6Qa+kw7zqBlpWF56AOrqL0PVR4YC8vciqMMXzI/hjDPJGnzi1Y1Wi7E1+YG1/4jQlJyxH/ujBU+E2do5O5Lu8vvZ3r1LKZ" ..
	"4i6RuiiFs3grV6PV965I5hp5Jf++UVe69mzD1edG2fOyYeD+h41+90rnh7sBAuzoFGmqBrHqZ28nVLgLwqe1ks17GosXjkkWa8rR" ..
	"G4RSxC8L4yg+SxZTMxJmfAn6upYl8qX4S+e30Tx9cGjkYzEw7mlkZh+n+dxA2GwFiWSMokNRzxeQVGS9/67AHRdFHL9fsuZo8Rpy" ..
	"0h0IOWG1DP9NB7OIJo7m+wqAOfG+gV8SyRzmVPDkT61NVyKNKk3dj/Bbn+pPfmQR8ZaqcjjoF/+EBJOOZ/1LirpNnFbLB3d9wj8M" ..
	"PBk3HRjkwTAXLuDJQnkiEDJEB4PwoipCEwZgQ49TWt6ew1i5vFqg6u3206jJ8iJ3XuRkXSMlBuZMrGFU3wj5c8yW9GZGh5nurXYD" ..
	"gWRiiGeoKMkbiNiSMCTaX8RamMmALOzu3x0BcJPPLFB/zhHjEkfe7flCKm7FQYIWXLtUfBpINpqkNnOBz1uKy9ZSl44Y0thaSuSN" ..
	"6eU4jK2BeCgzhiVFB/Vvv9Mq0HvHShJ+6hYw9RU3Vh6wmEewJJ0KZcfQsSlHQCbYabvA9vnee8VOF6LiTztcK3evGar1uR65ml/u" ..
	"54+nNbBjOv1dYbo+Gj45ja6irQpr+yOxV9POy0WhTBmjuu04CZRjJR0jsYyBZoZuoDfrexbJ99ZhSOUBPHqVIh9iFJ/3DxU/GSSJ" ..
	"y6E1j3+MVPqLAY9zJmoxrc9/RywHJcpEFdRjNQvSt29Oe+M6guROaSPLntJw6ELO/qFNE1wLX93gugVoAqA0VPr1/FA/vEJlWor9" ..
	"0Zte3Qii7mFMRkFfPRMIkwKRYZMREKdh9YNGe+9FPADuUa46MrpnLgLGJyvmuuA7HjK2g8j0LEcahfoNotBmNp9XTPSvQuWriME7" ..
	"El0mGtes9U68FeTVwPnDN25FAjlt8kGYtciOS0K/Y3SZaRUOuf2941dvM8LDK3v9mAV5toBdNf7bG5l3KzJgDaCT9FN/zrJebwfw" ..
	"BRwz5853VOtTPRc2/KEV4gdTo8IucIVj0/5iV6ez5j9XlXTw2i63hYJH7TlvVUDHm10ajhUSOhI+qmTwI/szxQljYhsHvcmiowWt" ..
	"rEFm/MlATRnvXXVkz1giGIfgq65/+xs9ZPR+eq2hdChEFdTTgqB/eUkmMKDZAnSpU8hidAaKc1gZI23iCgR4d9FjC2oMKQMVOybf" ..
	"zB4MrOJebRM5T5tugEWTS0NesJ7vS4P2MSVAYTFLQbzR3VdieNK/5O5s5JzOlC88H84DPP8tnE3I0JFP10RgRUnlzci9oUX5Telr" ..
	"c6PCnZ/2Sym65iVP+C5ukh6o7sIe+3iT+U8o8qzv064Hxhw0YAIdSWb0rNV9BrsojOIay1eR9rN/H9BbTK5/oYhhiL2hfM9HLzqM" ..
	"afj6pSIR8hkg2PJbFEBlUNz8TUyGff9XzFINq2kuYFAk3JcisYApTuGwAUkEBf4EMzy9j+YL78SIqvqq1ELxSrH+BD/xngAXECpk" ..
	"ZAirRYdElfh71bo71kkfVpTPijuOa+EogeOV5xbGTmS4PvPVF+z34TlESg4oeY7TAfRIyF165gf/buen9mEcc3FbQ0bAX8t2Qah1" ..
	"qz4ueahuHwMLtV6o4UnsAjGeuRuZCtN/L2zSg6WysB5bt0Eny/0vBeH8TvL00ug8sA72q3Hqz08kyJJXFzC/nKpuAuSCxBMnjT3/" ..
	"fPVeEpBEHfyHSCMtpLr2ZCH5MB3yWxa6kPXI88FxyGe6xV6g8RH3vVNq2ZNDE99el6hJfbzxp8qqx9Z8eketYgWn35uYRqabQWi+" ..
	"GEQLJ9Ua+UFhDrRH0XUKnmxIYMSZGZhBa2sfouS1e8Ii1IK/A4+XxC5DQVbF6brWYcAW9rpTlhOdTMEY75w41Esb0R0SwVF+GorO" ..
	"GEQcd0sDkhBuCFckU5vid3yiCtSJeqpssqCILpSadyqwuSsV5eK5EbBy7/QucDe1zT8ZPl1VooGDIM7PTZ6b0oOVo4+WSAHcDoO+" ..
	"FqPn+IJhgsscTL9FRkPONK1v9U/Ou17SEjzROUXfltyykvDI5J6e6a8d3nZd9WhGYBmlBC7B6K4PDT2F7z7E4CY5x56njypey/nR" ..
	"/KzPyeylV6atzy+S/CFZUP7AzmGicYFSm86iwO6TkPRr2gYxg+w6AW1GcBgVzDguRvAVspGc18+tFbKniC2HYNMAjGCR7TKZbTzA" ..
	"P+opqyPzgg4O/VYUzPLbPVSnfHGZC2WPmM8Ln+OC2VWZKtTiKWTp86yjKP7uRk8sUjsLfTjw7y+tVDvmtf6I0iO76DGjqptegUod" ..
	"vKyR3YGwuSKHxRbAZsSvKgTLYGbDYxMTm3oIATL0ENVNFvvemqnlcdDXPSSyow/a6V+2gecGWsc0VCo5ilheqE2MInTUCdTS1IN2" ..
	"vHXHnIVWXqqy27LIlRoiGBbfuzbaFRKcLfYTksNrWk3kc0zsxjf/I0r9Ts3WHO+pMcGFTxjbyjGNxX3rymnwhlV/6flKt9ykLi/I" ..
	"cy59RwujLGvYzdbBKhY7xised7PEH3VsTLy7V8Mr2jHWhGTVLUK1p/1KDV5Rd81Y/3xR3ZrMCgzxJ9MOMrCQeBIKn91kXVK8Urem" ..
	"J68kU1hGmR4YOzu9HRtDYsqJknd89X7W/h2LKdL2h4p/QSswZHpXTMHMfo/nKTNkTn0/HPyMAW6whTmsbjVpfgJo9P9M8rUWTlAn" ..
	"7Abbhl6HDqhyYcpJZA2e0wCrx2eG4KJlCVlJd3wINLTjsYHUTDlhXdGM0koB93RVDJxN3USeB+rZzXLS6mqUC9m6/ncVNq6HDWut" ..
	"bSBenEG4iot69FALtCOCSBrm/f5xs6z9N6e+jP8AZ+Acn0pIPu6SmIvKIpDbml8SmbLMuUChdQVpDEnUqRMGEWxNZoToeGfFdAWp" ..
	"fMpiXW1iO2utmBnmpaP75NBqrdJdocctaH70s+XBuDOTKvaSxl9FA3yYZ7G2ZYCGj1YU9Dl5C53YZmW3NZdaN9uLmribQ8i1+kBF" ..
	"yhJ6TRnYc4X7KYonaTBaD/scCcL2yp/zgVpCGn2t2ONJqgsMRltIWzPQ8EMbDRcYbVFz5IfmJ0QdTllLhIVchKj/Gt7tCebB6yx2" ..
	"VX64WfMr/yqvlYy/KHGYDndIl6Y9nE+Qyt6kE9i35tYtBXHTZtoG0JCT3LUmBjajZ36Cdp+sugLSM2dPw5+vFDHEnuPg01aACpSp" ..
	"+9y7RqjyC8EerIM/FMRJNUITukqaqjfOxFJSs56fnbnmVyB2ukXCFygB3H2BeCEfhaRPlMoYfyKYgiXxRZMgjJk7US3YfE5UJJlp" ..
	""
local PAYLOAD_P7 =
	"Vf56MFtkACf4mfDhXorW72UED4bekTMqUiQa7lBVkINfh2sXGg8BZ6V1tzQvX7KhxkJEZuj2+aCs1lQCeJ9GnTcDlDPcU0u0JpOs" ..
	"GyQRNEU1/KYaFeP0ObPAgfZrfvN9zqoctXuKVcOwQvRT9YLM3qRrY9h8E+zVXapSVp1hiB5NyH6rTnQOeUomZ4/uXsJ1dyxSPIc4" ..
	"hLZ6RArE5kUhJwP+Fukf+0mdSXMi2eFVbXpmr+S7BioI9dohgOO7r4Sgh2YzH4BMRaq5Hd3MJ8iuTjynpXwvXxEkXPQ7Vefg5IeS" ..
	"buV1yQ2FVwEeeeWNqQmXqbN1MU94Zgt74Lzrieu7FfutP+k36KZzN+zoWB27HNAEe6OvUEuO6nAfpxAiLlwzxLl55YyL1twgnLuW" ..
	"zqSTW7mjURYWVby18BSsJ+QPr3TnnZ5iOiiSnNjdUiPS/fo68KmvztNfKquxqzcCXWKOUx0AJ4vKddXk5jl19paiwibG0KOobw1O" ..
	"pZqtN6HPQKnK+2ggd7ZWG8qlTRD+E/mKWKnPcX8Yy1QfgrnD+zpIUyhunJHXgMTtVHe7UgRxUkUsn7uSV3NU7MFRSoSdQPwSezxq" ..
	"xTtTcWEhYnnf9iflqmLTamyAnBzKOp3NPedZFezVgYc721KxGEI6kUMp5jdfmiw0fG4jQDcSn/qP2SCN12H+ElwsJkMPVj7w76l6" ..
	"zGrPCB/vnJ8kiIV4NBfVHFmAfng56e8bk1Cjjkddt+xID13YVsPObrqR5Bi5Ge59miOYtTkkGyBMkSl4MVu+obhtixt/evZqq/FS" ..
	"JuGmRIHmQquOQR66094qA6Uxn4dhSpgyImULUc2zZncXAULhhSH/rVeaXby0ApLVNuK0geGOKpGvBVXx3PLP7ok3LuMeQCSMHpni" ..
	"fwk7foj8oE6wr/bv95/GG9aA0nq4kDDiNdRfmRcFfc/F1PiZymKlhaBSssJbVJtpDH8BrYjsmdveojj+dtALKlGorvL072Wspgda" ..
	"2JMjxeOBupkK4WRvuB925Obfz4zWhg5+JwIGcneXr3/vzr9H1VuKTIx+DIkUGnjInP2yIqmZlqx3hlFPqtYjlqOEnUoPuGGvntLO" ..
	"JSV0BhmCA6zBlakgnRscgUf8r2+zaD+13O60btapFQif41/ilR2A2wSc++o1q/ibPptgttMlLuDOtkRTiNobXKdYF0hy9WuAnkGl" ..
	"xmHNHM/jJHwFPi3Yj7V61GDDfsXRE/jmQ0QHvbB0VfL6zKFYWgiT38IxOQoZxSWcjAeQUBbHDfYl/VX23KJa0woB5hC5xA9Q5F1y" ..
	"OOobf01A8JZ5VSpuhBFmdlI2vd06pj/JoiQh4YwmMLYMxiAZXRnxb5C8r8mUBn7XSZHV4+9rLrippugKwSLMCNUtG5RbkHshFCpF" ..
	"CpIu//IEQfxnMGxKBPyeGKYl0S7vLBhTWMU4lJ4IlcvJoXj0Zp+nRlRBNjN918l/vKefhgExh783KhC/exMgLHiqxpODgZo51OfB" ..
	"rOh2rEipvM/QabGcRgt1AmafPhG8qPBD3S/A8VHr+daXCwAdTz9nazGeNQ6DsGCKrQOFcSVNnGqtjmgRoOMCbGJIQb6zp0FVVjT5" ..
	"+vjtq5R9puYlg4gvhIluSlM6DVAlfoviHJNDL+u6I020Je/NPsMWn4wfGCbby2p1jo8PJ3aW/wztX5fBb5/tlfInRyljUp8KTdhb" ..
	"IhsCi6wTkV2AaMDlaDtpjVXB0GEiOBIJb6MiFCMl99djpfaTVV/n3c2uTvt6cjTreJKIe2tS7HVYYZP6IhytMeSE6fwUjwpEhwly" ..
	"vTRxEGIxNxQXrAtZb4ft3hODdjxatFs58WcxfXqL+smX4SbifrfZyqkpwhq1bQEqOCnR+WUETtUQKJDnKJhPykTJhhiHTyncn7jO" ..
	"UI4tDmUQBlJtN4J/qWUbtCWDAyvOKVl70csUs6F28PYwrHWwce1Ic1l9UNLdZWgq6u8aP4NfmZJbDHRlVaitIZrw1lg+ZizhtEX2" ..
	"1hbVXVFj24T70NYzL5EqctEeJTUjxZm2ho34INTDoFBDzFW22oJFk/eV68jVvrnNba8C0rBOvzKSI5xtcvF9oQ7Dc4duL66PKOWi" ..
	"OeLSd8AEwutf4v6D9CK6OxNtvknhhzDMmOlD7ceW2CpZK8Pllxc9LCoO51cZR5yCqm78M2Fl3bOnfP5hE0K6kPr4LPRLiRFFfhON" ..
	"AAX7b2vRW3xLqpxJLcPQdiobbuKfxc2IBbU0OsCPInuV5RPzj89Bi0N2rqlPE2tbP8sduuC7twFNTJS0g2NmL7CKctzcLD4O0oQZ" ..
	"ToAnsY9CkJHa+T+PYevyctt3JVEAXkf3dU9rWlJz0xrX/X238IFn8LnWNsWxatn4NPQahsdqeL4IuDpQ8z30XqaBMk1E4sDNIZJ/" ..
	"hRffI213o8iz9nv1cbJEd+uTNB1rhVqTCPwtQyQNgAeZt7g1TLog2UCn5MoD3zfmO+5NiyeqwGvQFLzunfkxFRiVbIYAX+NzTJwJ" ..
	"tYJ/Uj/QavItt88tpFk6ys+MnAYtgNXym2KhTuWj7NOQWuRK99l+dkvxl4r+7QJieIGgOxMrlnoKQtnuLnNF8xBZlLKrf7RlpoUK" ..
	"N7iMrO6dqYkxZmfhe2pCSV393Q1wzxGoammTBudEgHYiK5sZTnwy9NxdsH31Vf5PM2DOKCVpBLdX8r1Nzm9rVzYTDXRMU8ak7BJ9" ..
	"Y1EQKxssfhlP3vKijAyWVnjVlLcH3DHjNHBpzrZ8JGk8Hdxl5DVJuofjL89pIDHxZ3AYEmJVbHzudXAWLHLL7y1sk2N2DxZ/ixap" ..
	"+0+3QBGqXZdIAppLrYtA+rW+mAGEbSAjBAc4kYwyy/HkN3Id3HZD57TDbAoVMgRiKBGVGgQ2MsiJ2d/NsfJEotN7EWbqEuUl1kU3" ..
	"RDgJtxKqBFW4aHA5uCMZYQKPBZSFORVZv42zTBB5oOiRT2nvlkL1lGnLspScD3uJv8ka5kKmA0IIPIF66U6K4O9gkrRMo6niEqN2" ..
	"g38f2R7lfAl5SUGTdjRKFlfPDCUzFh7l2Jcr1ig6tXnfiNUixK57HhupKPef1J/sPSKzkx+WXcwOYg+HCCxnJS/1R4JTQxDdtGIc" ..
	"jsDtj76qs5F6QkleFtNImi5kedxom3eAYRWN8yMphvt5FNPXol59+JrMOf+JQWg+8Xw9kldLfs3EAmCbqx5ZZjy1QbErRU71Kp6o" ..
	"ApZdNfXaJexU/IVnDn/KKtYBg92IhiPrAkEHN+rEEbEIc6uFPq+hVWG2WDl8P0tFyCRisuhPC4tEPGAWc3gUtRq8ow4kB//BtDbY" ..
	"JUM+pzJnBJo87kUKIh8VP5GbjHj/avS6JhMS0KSwFJkywpng3JHyzEpO2tLRcHOBdTA2idFIf4pkSggQKnH6c1gltHQb1ozsgs3J" ..
	"7Ffx/urlKbJwjwsZkrPaCC4iCjmdPzIf8zThK9QM1MNFHWzqs/EsvbadMOUzc+M4hJm+7oFwYQCD8npXVDL6pj7+Ax/Lq8EKDQAj" ..
	"aTUpZi6KyDI/hfL0a2V8Q/2bxRClRsHcM8/LMqSpy8CjxVMQ79TDtd7BixaTCbibWB3YdjrqttPi1Nf6nDAw5dLfDJFWlepzAAsF" ..
	"2G5LuRIlqHuSQCqeixxNkdyu0kigv7HwearuChse9bH6S0t3rlNhu36DfRevPkPWbw56zRKxp0RIZMcduVgydcb3yyQdjAbopzmG" ..
	"f3sLMPwpBmaer+z+f7GcBkQXy2KWcOaMFTQ7pLZlpdgJqbM/oVNWdAdCalCEUjvlA8h+acZiti+h5VGIMYLky6VcSPc4IVDLLl3y" ..
	"LGKMhK0PXYvHr4nkz+UpR17N6e1m8tdKI8OibJv32apUc3yHZvvRuLnskeGC8MFXGm1drjAqPcKyvDebOFy/IBvoQJEkqUmZwq1J" ..
	"zRCkORqKtX4GmH2qi4z4m+zhMJJB6czB/ZN6ANNAqS8P6TvEy3uv2zYoDvIPQqjNtP0KjvQJ1LZrR1TeNsW2ziaOg/dwGG3NjAfQ" ..
	"UuzkDDm0W1LInCmH9gcP36BHmjv1kk61b6Lhk1OEYBsqNJFoF9ig5Lnvd/Ti9UUUwjEU/pzPjCnfOeORSbMf2ISy9Nk/EyIHhCy3" ..
	"vGL+tn0G3YIZh+VUklIg/tO6KgnXJo/mQou+GAh5IS5ZJRz/NfIa4IgZ8CIURUQPyfOCAWRt9z0nGKlZIH92qQf5OTTUj/9PDlWk" ..
	"vWn9UikGGIdw3fN1DJpr9jUkx4ylUqyrKSCb/As23fc9+ZmnMc++mRG0ugcVAmO/y5LSYmKxQtpuaiwzWUs402rr30k3V0nKbnDV" ..
	"XE/uO1AgWYeEPKifJFi0zuuCingI9NtSFTuETk09wC/voIeIKY1mrXKqobiRJxmxEf1G12Ttq2L2DdbcjQFUhv6JiH9XcWHcc2n2" ..
	"+WWTK/HUZNHjOlMFT0uS0i08DfWc8LskuqDkW4pnD0sVSxNbMXgy6k1Bcjtuy7vjLekMRssil1O7MUvIyJ9fSVJx/1ahZT1SD/YJ" ..
	"MCDK+sv26c3XAskmGLvRONfoX+dEtK/no7omptWm5LnoNlh6zLkLlfIGW7k6cG9x+zRvlX4VByAXy9X1UZX/j3atYVm21p2+6yXB" ..
	"Ywexrzj5tSkZQ7UtpEOnS7x57EXND8ic2D0P4h3X5G5o5dqynBcpV8VBNaYdxaH4yjZSII6ACHWm9G3eRRLklmHFUCTMkWVlLBpE" ..
	"472wAi7lz4AmTmI1ylHtuG/wloUDGMBkAaWqPd18PrOBbz1GGjL9riRBJQ25zRxVwutwtbYdVe9yihmvSRhHIYo/rSElTkqyWndM" ..
	"bICfBn6HS4ALylfHib+MjB3IjbtZ5LW7NAYDBlFi5F6967PnYh98Q3W3P0YEznbpmeRJ1cJDRYY8PsqfvnVAtSGsLoWxTLP6+mmC" ..
	"/WthKFCA+p0OkfSC8ueUWe6+8e0f34trcS45M0syTmfxSJ2H9ikQNP60sBOYlZJZJfr43AgYpzTsESKu/Rv3e/mT1OBzJwwRBr5i" ..
	"x8FOXu6QFydqXN1AD2LgJg/ODtXzb2cnDxRmBgw/L6+tMuNRuCiiRx8+4BsrU9vbvkveI72pxPIJc7X9+6Rt26epNZ1fl4A4tY98" ..
	"AxYu8ipAq9bVIwdV1uGnAGVFdOHrrIU0BZYTKAng0tTa0/+knqHux45HtTqOGTJtycHizi4W+NZqoGv414prvuS952+X7LMPcOs8" ..
	"F5IB7ONZUYMwuhdinlPphNnfZkjW+WqwskgULk8T8RRCbp8baAIZDuqqmKuTek6Utb2fQSLWKVcsi7C9JwZRUNe3GfoBkSmGqxnU" ..
	"OAYp8YXaWz3zNmWQGnftQ0DENxwIudcNcNZp+HdYOyqNIklcvjHy1FKFRVnbrCsp8r99WxbFfW3/3D/2OdIJTdZgRyc5r6lKtM8O" ..
	"byJq2jxoCHbehDf9AHMbW8cYwX2yxmDWrM+TM4RXFOU3PwYT5ZaEUPPhS7BjIhNCE6gbZj+RulN2tRC8HmPbnewTPLNa2xk6aNAx" ..
	"99PFizZ0lwJ4NwBLy7cb9LfNpErQBDmIO6woq7Sd765K4a4eOOuJkmfTsbn086eLvRoI/ttnoSvvtUq41tSclSRHM9QfWYInC/gQ" ..
	"qP+kebc51y1WgoCh3J6nIITznKFIIWtq2FwW/Im1FQPatomOERdEyM0fy6sS9eV4JVzqaaWx5NNFiRniWb6P6OjF6meQBuYT5vBc" ..
	"nUspFbKZYnRTSPYm2aWV+TwuqQyzl1RCdN308vaIV7ENgWMrBN2eXBhMTXR9pRASJVyq/Pu6yO2521Hdm7L4AcJunXILgIn+Ov/1" ..
	"E3EgE2Kt3ZuRq+Y1y0tsMloE3W8bHMroQOkxXsCdCnbgP7/ZnQxFNifMc1JhAeJkP8YDQuhcCFmJbn1t0J0sbKqsVc6Fj4ta+cNo" ..
	"BRKp6DXeXZZIagLQT6Tten66YbHuMoDdyh6ec8OKei6VJs6/ZxSbpOJs9M9k2NtxDeuFII2pSexWWCN8C5znOJTLXXDsIVq5liPh" ..
	""
local PAYLOAD_P8 =
	"w0c08qtpjeF++Yxh2fzZ49+NRkex6qRRVIGVLf1jqwRlsIXoe4evYlX7/1nCMXhvPg1CFeFr08UaW0EkV9srNdZeFweCYnG8g4oB" ..
	"zp18aLx33dHqjFhKyn0pKEDY5QqduWWqCwNbDRYDlKo3fwgAtm3Sssnky9O/qCZ9d+yyPfuAybM6NHJ47SLKWy9B/11xtzbgvtyO" ..
	"7Vq8DORJefHqna/KcBVrY7XRvTHZk04bUGeGjP7Q362ODxDE3HyV5nmqcEU9p6T1/MgEKYmhgOHlBIj/kRiohxiTP1e8OqREScnw" ..
	"UxSXdgF3PtcsFrtNGoa4wCKCLgPgSnPEOcS+z0O64L4jUzX9euJioMYYYcHIG2UUp2xaf/vZ9iQZD4ylwow5kmHPA8Y41aH5XDqu" ..
	"BMLLMXdAvSbg6QFSqHWIMNzR/6ZwSbRSuZCMGad2ipR3m3dMgDnwTapvwmZGWxk2q/Sj4NnICKWGbl03WAVr+Vvssx3IEL7h6Yri" ..
	"gWM0ocjGLRrkV8CAbpP15PU/8a3vI1mqGr2c1hG3zaxiYnAdnx1ywLffY9Ft3Z4E2UM92XsCLMnFhwUwGlIOUsqTg+FpO6qHPc4r" ..
	"k2jSb4qj7SAU3AaLu4C2AZQyZP0ENwXXrKBkpq6IHeW0R4URX80+EAhqcxWQg7kn6OYVv5D6pOvpK2WRsua4Y0PYE9FSlGzB9SCq" ..
	"7H+06l1+OjUfS7CQesdVrcUKL6wKV51gE8Ara8rqCSGrmfNao2FF7BOUEM/F4uorer9Q/RWnBvUMxR8sXt5BCmIgCYw6zQkSwqWC" ..
	"J+VcI8Xcc3ZX3Z58gsYHgYRl7r1vBp3Y8lDcTfHgZgcQkDk0Tk6UFLpDNfKkvxo7l+p41BFdNQ9SYJxyzzi/+7bl5y9a7Z4FVqPC" ..
	"3D5RlzVt2xdH/A1DGyi35y39NDXkSZFdmkA4EeOs7Bm/1bZ2NGx815Vj4JSFu9qRCORXh5y1P6YOAz3cfZcD//UtE47gDaGb5TLK" ..
	"GsS37gFFQMJgKKRP5JlZi/AhbGaDhVCFgH1D3cSGpyo3nSDPbSIiEgn5xLHpte/YY2byyjD9Hqbm5tJkt/hrEgdzYkfPQrg5mCqM" ..
	"KpsihLs6zJ67oRzn/YQytdPH8ZrJ+ym9eynsxc30K4NolcUH1JmzEyLOF9Z3JC33VuZREgsH/g022cJLomXtHapHD1fQagWDwHfj" ..
	"jpAisVwT8S8gCzleMwuCZAyWQvP8raah/+z5QNxJpnAPTeN27JRodL2NNdL3/j9Mrdkaj+dQ1SRcr3B3lHP7Je1oPywcU9jSUwtV" ..
	"rettiGxn14+o/5NxTJr3SBxHXB3pDailSN4jEV7GNR23uFShmZJ3F3bWiDevTvWtH+PfIKNu+NZAaBnevf3/6rteZDyY1M/jjy9Q" ..
	"48EbmOuInZoHVBsJVf83akiv8nmwIkgQHudDJGOAh6/2KlkYLMLQxoGvKNPdJg20IuKuv8OqVzNoDDLFX5Ga67xBLQDcU3WPJVrw" ..
	"qE24EkrUN42LxG/xddrUuN9UWYVnH+rfJjmz1hs4na7K4++rCvEZCUdJg4gS9fSIoIilD2EG96KpVzalhNSBxTZAOuSseo70xGbe" ..
	"K4XeUEaEK9qf4MutPWq9wRf3nAAzlyhw4L1LtzmBv60RQsaaip4uYHUr4+peemCixYd4xqz9Kdy+FeQBtmMLF4vs8v2Fp0Dah8t6" ..
	"3e5CEUY9Kvc6yLmK2++oZTSHkdqMPLlGxvcXflt+sntSGrhlxXpCRwd0DA2jsTWiNqQjiO2P84luh5An+LqxLuiW+z0m2ZYIGGeT" ..
	"StmimcJUW1O9E/02rET+SUXIgmq02SW1JeoRLn3tvzOUyGBiv+oCho/hk0nqujcO6Pke4qjO9Qf2uuCJGTB3K0z5pbQqqIywKA7K" ..
	"Jb4ovIm5UmZuJoAqZdQ5MaMaQM9BnMVUqiVMJOwl7yDXdEyaAqxDdH5zt+m4FFEXozuU7HSwjg7zR7QJ2SdtkC/Jb0TuGSKVOlxs" ..
	"fllx4w0jJaE/b4lSOT32u0zgLhs3wsbt4fOQ7Z79ftiReQtV+yCPteN+DwON5+NmvbX1D/sRjJy9oZ0bZ5h0KJ3vZo4IdbUtx6zr" ..
	"DU7as1Vv4TtvnuQvF6RmQH2YeUZtDSZmDZJfzK0trDV6s7eUimWrxbOUKTrKreh4Du9mMyQUbvhDhROOyqZIDU5FHrxpwuaCA4cR" ..
	"Up6w32TChaHLE4E0Ct745y0YDPnK9IhwkXRRTvNJ2Yj35h6kG0WpDClDtrntGdvl9V3n0pqWd+kpimVOfHJCt2KceZbc6hQHTqLW" ..
	"WzJ38NDg6Z3sBeytYpozcN19QXKO/BTb4O3VIN5KzHaBjWmBg6CFB7GQFcqIllHFxIKL2fmlBwd53auqoUOZerS2xrpqOR3eMMwb" ..
	"NUVhfs0lwRZBUXakPCTllVxz7Eq1aR26cQb5okKMev+1luTl3OI5T9YxrHWXrevFXDvhs56TtJMhxVFrVjVTMtoGvqvOoG8JhdOE" ..
	"nF62NxhvdKlGEg2LswogVivX89s1jcGimWNPtOG9QQWz7LufRPbQP3wm7eGsroLo0NovYMDMv1uxebFFYo7FAq+I4QgfPjgO5cjd" ..
	"+Kx61nLorU9JyF2SAozZVC3oAvSbO4C0ITktViDeRc3YuSmB6DhCRfUczi/AE6k9pZfEUevQG4OYty/q4538s1sdAfYIOccsdZj7" ..
	"0Zs9+t/0s463xvnR9vwIYPzNB9uxyChecsn+cmkedGXLhIBxC0NTfmVeEBK/hlUARVlEU72XGgDkYRH1a6QJW5KA5Q2SEOhQD97v" ..
	"wGCLiNHKWTIAszlJO/PRCqnqSmYVK9o08Oztd0RN6F0Hcrl+HWnJTfgDAlQL/XVbIsj4u49vrEiwJO8zd7Fnq+IWBbYKhY8WrW5z" ..
	"OlVKzh884uwEJRfQhklS9l1FUJ6FLOXc3ce1z0VZp5eVnOcjn1OMWeN1z1d4GFSUmPtUxfuMzzl3egsBG/MhBs6xOHOVXbcjr36P" ..
	"Ga2WHv8RswuDyP+0Om30DKjIu2JyZXka7dEN7msFhI+yWZcL53NPVtuwok331RXIF7HkLt9C6/Be6AnNjGDfQlDMEK7VJ+Ztu+yJ" ..
	"3g+LcOQOxo2ml1HPth/lkgHolZqpbcD7ecu9Tqcr+6caJ5NE+0M0O6eNxaG+6BTj/tTX1y6IJCq++2u6JW6H+FMKlhU0S21APDxD" ..
	"xnZzOPy7wsuJ3O1cg41fENXZ4HE4ZiEgebKNGsuijQSsNalZ2dNsJRZsdqF0kk7gNCIQ32N/GiKMZZG9OuqaiYYL7O8xEdD8kxN4" ..
	"FhORzbmLDs8xfZwtmQu1r/leMdzdA1pOHbNo1JUJTH9e7/FwOElFA12rgSdpKt+mWJ4qi5HStBv9UaBUS47JDIaPfkmEb+/MaR+/" ..
	"fWttCbovuKCi6EBi1kneeg+gRD7+quMFqG2GWn8Jk//9OGNwF/T3REcaQwNlVjALFh9LkLJV1UCmuBM2EO/bRCEzToPT+32ljABF" ..
	"C7kZiJMj13RrCsi2lNMucHoZAJ5JWENqRyGTDWxM5J/QdUh4vdRNH9iS3PQWkjnDPQmE0JQ9MFbc18XDJy6vamYqc34kggRxJv2g" ..
	"89JqOv53p76Zo/Uqz+J96zI8XCvNqBY/Uzjc4PmlNQhnEL0sWQWtVfdcPivaGClstPkHLzJcAHlf6v+EaoaP9SOofED3SK4VXj1w" ..
	"YvBBw2czrT1VqWxHxT8nxtYPpnVcIymuCw9tQGNFLDE5CSfqVMxt4oAZpit5G38ZtaxxjEQZIWUfhF48TqoMiG14bTfe28CWI4At" ..
	"IEshAqx9VFYbrU2BdcTYyvSYYDTCvYmZQQ5JEWI/5gMu9jRIt2dWzREtwnM3zbpRMW1hkPLs2EVBJlITWMSFYLLYLriMyykPi54h" ..
	"sxfPcsQZDhYVm2b93FU5XedPGzSBF/FP5jbDWz0EHLp2clp/feR3N7heL0PHe6c8/2GpEnaAQd8Z5GRdjm1+wr9vtLpxIzjnS/Z9" ..
	"jF0mTw0ECokMmw+Jok0P2NSWJ1NAnSKVH5ggOWzhkjYCi7bMVwXwp2eT9QdefKud+DZiQV5cUUtTVbfYSplPQjqrLmMao4B0c7pv" ..
	"DnY/ifre4Tqu5bRpGJznYXOuRHNSWhG1y2sKAtUEC/sOhoSPnmOKa0febsJ0z4+T6eFpj2474iNuW/2ptHmGBUVt9Qyr+IX2nITW" ..
	"mInWrdkzgsGTLnfMSx/PoB3txcYB1yQV+nu1AIrhxfu8AYOjbwmT9T2sZAlvgla4eYcx1oAsJTcuJWnmwb9X0tJyQHZjAUpofqvE" ..
	"V3ZdjsivxBc5oqQ+BQiNZSUpm5fjhpRIcK/scr86MnXtGQhu9Jrwjuo4ItJTbCSrIMAwPybm6oHVXq9Py1lf7OoTK6HTclUJcO2B" ..
	"DV8n+h0i4FgrjKNxNtC7wBoG83Z9d43YFfHbjDu7QA7FAWaoW+Nq4PSaF1exJclHFudXK66oio+r8MUCwfXgyy0ySKnWDKWK4/g1" ..
	"QEg9tFxJwr9xGhLt5MqC8PDAaqKb8fwhqicjF/PCHnnlu6O7vQVi1bYEp2HZ3TDjGehMo1h0Z4xNTWF8A4+jJkCu/gHGWesoAxoF" ..
	"0i7iSBpMmbu2/qFcIcH0WpdHtwX7ZfRr2cLxUow0EktrKMfcOVvDNBqo7FEYPZeE21dUMFY5dNFRLca8PoFDLmnb+fYsyLDk3ly7" ..
	"jt7vJYCcD397RomwqAw6qWJxFwJHPITa2tBONkKlFSx+hsseD3+BbQHN8MiHCJu/vvng7XsB4HA/57WW7qR5vPzbC5ixJyF0M2S0" ..
	"LU+Un0K3fliKGGja+9seEIEtuJsMDXcCRvHkirZXkFD1Q+zG9oKlJBcfsi6PecuwYBX4Jo8Z4TIW9Xs7nACf/qeCUqekT4NQZPAb" ..
	"rjqELkB2+qZbAIgqXnBxOszXd9RCZfaQpXmJ6ifQyOwJ/ExjodHVZngJLtQoVGrY++Bp0i9T9rmfLoLt+3s49kv/cXPAzjgHWWlq" ..
	"rhMhVHFZa+O3WVJ8psQXJY2QXcxkCeHz6ub0r9+3CeG8axu4NixCvJ1FJ9xXkHpz9j3ztZJvN6kAZjbJG7PUpzDLZDpdSakBCNxU" ..
	"62UrnmXCNBG7VwOfldWmQ8JTcjh4QWOUnrzfkMGVyB/ChnF1yxd3iNZFdYAQxreG4dB118MWRaQIww3c84U08Zg1zq2I71MF+L7P" ..
	"wlzWMBCe0vLoLGbBx8GKpLBGGFRBfyVWtzKG0Iyz12L/8P5MYgDoc3soSP+KdFZw3K+dXacrgKuHv/OYqlckYHKQCwZz3LjPv8Qm" ..
	"n6d6AaMXsDQKRmcUvBYERfZ9OzRUrLbfsBgeFfhpMnqaRxCyipGyEugck2TtMvAjDm0EG1NwBhw3POjFbVXBUiQr9TWeglOCMwhr" ..
	"o11f75cnxZ9UccOzwQRw1kcAzZrSoVyXzPdSLJgBNj4JV63+4KvHxQGy2wsawtLIC5nmYQbMF7hIg919Y99oioB8Z7FuY7wuIE1k" ..
	"TxKE0nVBmgApMoatHkJj+SKP6VUrwUXDKc+g6Oh2p3vnG+mc11OYpgjonJBgzLfHlEOMW0rSP17B/i5cZsOzFY4rdv/ZAsgZlEIy" ..
	"xpWQI2mUKy8BAwnGA0HvYGqLOJbUY0MprWSQ4o90fYzciO7PJLxtZpkM15uuswPuqaFsAFB1RmBmhgzJ2VaMIawu46S3+1G+wTgx" ..
	"ZxYxYh/OdHis5VqisUIuu851TO3q06GYHLG367DZfbORKwRrxfUiZKPahIsWyXd7kVAOCLeeVVX4sksoUy2Ai5JtVdGyBoZANvXl" ..
	"QbyzZVlXhjSInAOYNIpXqb8sf5Cfue9Q78yKOY4ksws9msrSHdUi3vwCnEasZvTAO9Ah46N5Emii3kJCEqQM7grlJ0rfWzuaB/ky" ..
	"+tYDHEkj/vlIEh8dZgSBazA2lFUYBqYLOZ4vTFrv82JmeZgz77ZVujHG1ua8qpIZY50ckrb3oQWUdo9OrpSABS1Rj8ypZJvrFSki" ..
	""
local PAYLOAD_P9 =
	"toc3S/qpSqw0zy3LQS5z0i2VG5yKdQKvvtlwzLXbhRJ51I68+6xupjVClMcAUoBfnhb+XnBsEJlyGOczqiW+dD+yNuVrsW1kKO4s" ..
	"ByOq9PzAGgP6AdXgpHx7URBucf2U0xHLw9a8/lXbQWiXdbpxpCFj+TmP6NUjOY4MBn+H8xRgcJ/BNWs1hfMI2KJleD8JfKRI1Yw7" ..
	"Cz+7eGnXcJqP6W2UsiP/YxRgUQG3+dfcVUQ4hm6Yhrhk0nSa/VXfctSNnfB3CjrnNe0AlXoOvHioRUSIkxzBmq3MP6v3GbtxyoB/" ..
	"iv1divcERyAiYoCkVbtON3/Zkt/UJmH1BAVzeOHezb1bUHv/D2EOnw11FSomJ0ZD7E44VLlib042zNVd2hf2ut+RxpclLQTy/+NM" ..
	"FQzIhmwbLu4CHwpF8sanaJU4gvw1S9tvht8iLLGlKCj58ognYmfzoK6NZNZxik11of/KPFRRQA/dHoxDJexWWx4Cq+j6dX5tW/TN" ..
	"AAKAJ6W5yd6f46yLNklCAWLyB2z0jv6dkbiyOTddsupTU4LC5TsUubsWwiO0reO95neE5qngOafcD+Om24Vop1auQnrIZxtNuVBw" ..
	"bPLe0mt8eprmeFMFTw3J0z6AXqEf0osrc5MS+SvzLQLqdVoOIkp18IiNGDMqTcVzTDz+cQ3FQjYbKTbIlYZUo7mLfv4FsmsywrkF" ..
	"EsCH0LFJNw1LpNaGVHPmSrP02Kp3S4JZTSvNf2rUb8upJGoWa0yVp7rBFW+LSEe0hzuffaEIi863gpwY629vp2I/dmGj8gnNqWD0" ..
	"LBAWV+hncQog0BMxQHCvzC1AWosOqYWvOq0247GTKuF3q9zVlaETZdrr0j1MXhu/xEYny6kx9VQP5WxATy0PX3SzPBUQAdO1XiEr" ..
	"kApWWVvBG09SY1Gk5G/7ckybUCXgjufm3Zea1Uz1152wX14fCH9b4YeQhWtQ0gDaBPw75B3fd2pkSyfVT4AdwmK2NtwYps9ISkH3" ..
	"gYWHQKVNyt9SV6oVeynrnTFVWv7o+N+Gt/g3SGvBAVTyfEPGP+q/hP4thhrN0GwZO4k3Y6x023YLaK2scKI4nFV8KbH6KaTDQpMh" ..
	"q59NGYlRa5e1yj9R5IcdbslkjA1fLO0iwuKC+tnryA/v/YLlInDh5JNEg0JAXEbZoaMd1/X7j7EciqmdBWtn66jAhHwuPWCQih4z" ..
	"aGPYIqp4ZjIIr0xgzrhFuh3M8eEx3QMn0oJR9NXEsHEQBTw19/pxUe9p6N9V8WJkJ+6lCPFLGb6fhYsAVmO6Gezat4qBhJlW/KJe" ..
	"+IOxZoyTkkS2bzCaWjU7tKScxQp8LJb7jFSc2U32cYz7t7K/1kppyb27q1zaEuYf9CgrupuQ6Ic3lrQRSumpYi05d7e1w3AkxIJg" ..
	"3oWelJe47/31xSBEndcyir3m0tjr9a2dZjB+uRtOfwTjwrStnOqUbOSnp6ct6DbUDrE+hH37+EJu2ZpUNwcVTAaH6UfmDPx5Bawq" ..
	"IXCn36TVW+JUt6PD5c3BIkTK/qml/kKbzkA+D8RVGfhgOZbiuOJ1SjP5f832jQAyLDiqC/w8z/g5fUCvdHlosIj21Y6lkhSeqiZo" ..
	"aUiM8aGeuS9JJNVECL9iAqmAm2Wo2cPmbDDtbrdfwEiNELCuk+K0YLXRBFeSYVZLp7gDHUSfW7I0jGBYgICRLPNCDRp1wKokKJCH" ..
	"JOnZBDpq+IcNEJNTCk8BQDTjkLJ8KKAArR7//pDv/xcFeHYZrwAYBBO075D4yiEE4uZpxJCICYvuQvDOILSKk6rg5Mb7b4lFuchy" ..
	"NdRRDI3k16ESAh8w7FUy2+wGDrCyChXzVcg5SIjZxQZBYWfdAKwVVBqfO8GYzeYPtcNKSfifJVeJ2FiEtYnObYaU46ETAg3uVXXb" ..
	"Cu3sSFVcQVSS8A6uW9oFW4gRqqTylAoc6d1bHPqARtrCbb39KK5SGBXelvWcHbhOaqnL43gTQsKNlVUa/+97EVHd9eltlVbAN3s3" ..
	"k0wkpoaIlEyI4HgQYju1F28Nv8dcvWw/pkgFnfJU44q+8tONv3p4R3QoVHW6EOgXKZO0z1zyrRMwJQW9CKoxmBz37Eu37/ri1phh" ..
	"/M917uEkMPg60NxH7E3vXrfXrMcYkmJjc9Mdb6/bV6+hh1o4Ho640uxV+FSmzHsq6/lxZv/7NPMhzRjlZf+t2OZHQO6wEMMUIyPj" ..
	"85q3AyhfiuWgCql7vBhYp91ywv2iGZRpz7c1EA3OZ/OsZARV3TBGdZXK1/BEFlZQzQGXyHtZQ7Hrs8G7kUjt7GF1L2RxJC11HAZy" ..
	"REX6xtoe6JzH5ZuC+sVk702Jv0zsqweRTdvQXsa9dh9fmxpE49t0HbBTgTBs+OD8CpV5T/oAxcu6l/BC9BlxA1vexNSGMEkdF+1E" ..
	"vAP7un1mKC+drIKh6IuNcKvmheQs+q2ikTkaW8eVyvaFe+LpdVMobbuoCIiIbG/5P2JTQa+xZ43k+ObKZ86nk6PwEZkZPN/bPFRr" ..
	"IdqNyELJROV1dAAx1JxpenkpHHv0HkA0gmaeC/kdrsfefOs6oR3BJeCZ7GegeMf8D60ziCWI4mVm/idqr2LlMfsVN4xuCFE4asj1" ..
	"+9PeES5OSELK47CERwxnq6gBHlhRPEiVas/IcXTIkVK8AE5XTjAxFvxUv2iTfImUQpWuAFIc/RubWRYJ3G774gOlf4ZsvFyLCJCD" ..
	"98DnPpG22R2zrBPKhWzNaS41E3HrSphTuxI7sjUgUvMFFUUU0BRy6lIYStSFFrebFF4whs2s0SDbIi6Bvw6W2fLuu8BCw5De2fiQ" ..
	"ibYF8CdMDyECQpmuufq7D8uRz9JfhIIYXfB5udh087YIjFp+t5F2vFgCRVC9bm8CIklw+UfqSGBjY4BHHqGlyEh4WzvWr5vCSux4" ..
	"UEOfdl8nwkTme06jMKDKy8O78Q7HXIy0XhJG8kaPDOcb1X+Bf9qhEeq/ZInh59ICO2AASongDggXadFaUBcIG+iwDY4zut7Vv3Mk" ..
	"AbfVujio4wjerdP8sIbrqbOXC0hTw+pcR6HblDHukHhpdZN1nWCrim5AL0MaoPdNVo4pz4Zlp3hQrKwNTRFkjZ5Zm7GubRnRu97i" ..
	"ea4peF9vyzg4t3PHtFOwclrfhBpcInh64cJVBjeRLwKAcCfy1iFxNlQ5k40MhyDMiHzhVCyUq0JIAFAST0Hi5RRyNlsE+iHIfr+U" ..
	"Ixl2Kbyfl377sUpefuia/utuGh4zQ7So/fWiEk0FatfzwTA0IpIGwM/6XXoqtuZWd7Iu6verOgUcGLx2SGhSCG9SfmdMdweHrh4A" ..
	"loaik+Ex8/AixddLdyrKRYAZUtrtE7SPVOPcQutpow2D469/QtBXj9p25P5Ocrgkky0av3Zi1yAMFJ3NQlegcxc/qtbbAzBQFz6a" ..
	"3H41ZlkHk3O1iOtslvhQ2DC0d1nFKjyaarS8i3kmAPJn63GJCnsfFQbdV/LgJvGkGa2MUA3WmmVk5OEXKcFCbxjGK/hm6JpjWbs3" ..
	"824FNqP5hdNwXlcaiRNG0RK4WUFatxIm5jJcE7dlJ1qP9xVy5Q/1Ux3JRbtUyKYiRw2CXSZYV3dFt87kKBDn0fIE03dQIQUEPfQ0" ..
	"Gku5vD4tPt5P7ecpUHCCf/5ODO6rOVuZW+QdvvACtR8a8i7R6pRotNP+jQaNy3tJ+GEWKC4ShASYEe9FoPNEDbyOqdzfC60MbHSK" ..
	"Q8plWvIPmms6A9W9pyNvY3MXCVm/6BsyAc1Bfy+MGJ4uDF240CjGfgV8NOIzbu+RWSan0Tpw5bFlXlTVqrNnPu4/XlHl6VTSI2Uc" ..
	"X2HowHufNkncgI7nHlLg1oKBnaQpqSbt2i/rnYqx26eRAz/UBuVxcBkX4VcWaPLI2M8FmR3DYeaVwNP8uzfrKU7T2bxSn9aksZJM" ..
	"1NtAUI+TjKXGTVsQhHIDszKbCnBiIkG9YaisniiOXONr/s7/shGpBdP4RchZckgvbjjgFtkAoi0v0+x4FPR8NkM7sJBH1nqAp1Ni" ..
	"6PtqU/PzaAOcVOb41bYIOdKPOP9XhD4kB+hkDv+1T3cK/mL+WwXP8q9HGbp8YnQmLNRb6tjJFDsJZMrl4qaUafXGKDodf7XZYRUI" ..
	"A7ChA2j+vozDNfAbWBvLT897c0nw7mG9vpLXOkFwgvHFgpcTOuTHIPfXIR1ulJy3ZxMv5rL0wdHItk8KFWOUTpNDr2q4Gmg+A45G" ..
	"bMMJiYOfEuMwqm3sQE1N0wJh3jQhfvw/7pQnQtg8lRDAlFXU1LDuhORBX4AlrAHGpoGjd4g53ZmG1Abp3PUn6x+90fGKrsoEULeE" ..
	"oLv9W7fjdmu+vk8/E1TODp9QwjxMrXvSa7jwCkLiAiuPGPIRnepiCzypzjmpN+2W6TMnNZxRHLOT7ALmfol7ZccacOTODPJah0Qu" ..
	"fggxWBgy3mZzhZ4Jo0Bo62WSWl+pvy2k8cHxur/MkyYMZSqyRQC/MfyFqvRE6hU/WVLtElGULnggFQoEJw4LPCuwLpxGbwiFwSBY" ..
	"9wsedKsGfQ4eqTgaKqh8CYTKBfCSvIScsakYDswpeHaPoJc5BgQNSbT7zlcbuqnnFIPwKsX0rgJPRvhaXTjLXjTXyv9+gopiMKaQ" ..
	"0adKf1eTTxsZeFq+9FHOAqh1+iHOPkrRiOGcQVvkLJFVzEV78okkAJ2IHKtxOT2GeGreHhEgQ1F37OJU33nfVS9LKgXeGbXLXEyu" ..
	"p/FAs82amknXkoOLWk9QhUy9kTPhkWvDmLwNJTdxSUlgAkIs3mzuulbU2XpWAjoKAWO7NRMSLEm7o9WtlnPYlIeeQ8OfweRPLNr9" ..
	"TsMp8wWVy99BpswcQbmDISkizFDoEDcIS1TxAVNmWX7unopzzDHdhkfv/a8GNLFf67oZ2SWw0JR6qO0SKfqlAf22IpHAxrlM9KcS" ..
	"n32qL61NXgK4mvMRGS5GVud3pZz5icO3Qk0czNeT1MFk9icZnUR5gUq4BMORtBGLNtea7wEenL2CmPWo6GKKuIokuos36YNE8Y6q" ..
	"OdqHcyiBouyDqaGwVaHg0EH3H77sBfkShxDnn39GDFvQg72bvG15cxDVKZ9jpkm7zjU4WIdcCuqm8q3imDdx0jYP3qr5H8PD/+hc" ..
	"GayRTohYlUO2XfCVSfnmv2+O2Z6/WZ7QOzWSa/swSAnNrWfMWSlMR1gLgY4RACOJh8hpOAq02O2pjLYAWwdMYY0l8i/YZox0xFML" ..
	"4GLPFTy/m89D0sNOVEYfxwv97lbehbU74OpMqo+aPw89kNYLj2Lkuz2GJvXfkJ+G/GPduUw7UK81v0zpjy0j6XQc5CdJxSdsvkxK" ..
	"FxMmn2fGOZhSsUBS1HrUA4/woj2t+aKR1I3CZXW0/EEybiooNkLakN2D6xVLWGIgSUtfaZqRuClmROlXhXhgJyuqK17N+gDkLPZr" ..
	"yZ2bwb1T+5tTNUjzFizAno7oTjz8LFaomsQXNeEnrlC/TLcWI30YsRvROtNwFzvF7zpGxwSInL5K7/71nlazdk1WpgAgj32QNfbc" ..
	"M38uw4YNXIfWy8zGgpDdO3xtoc8PGsFwnaVFpfqXi09qsdgOD/Q6il6cPtVcSR8vSJ1bMFdpey9Lu8wo4GXMS76KishLzqgPuHux" ..
	"ZBR5XeeutNK6rmLIMltSPZgkLnOF7iRUOYsHcc4QtbErLJuqxm1x4drully2GPCrqFeFTDA4zxm8WxquXS2NwjBSdDSB93bwCAIz" ..
	"C/piaCQgomXBPDj8Xj/42fd9Pm43PPC4432bIHM8d7iBQGph10O6KGyejnQRMoFGIxkIaPAz9B+gZ3nWJC8xL0cFjtPt5w7SrfO9" ..
	"aLgUvyEveNho3fQj+mL9E3l8vGyZ7G1nG2i00dSrWiPaUhsX9qich9JLPuer8KNkB++Mdc4SHsWAf9GjP/8HuFKf7Bb38sy0/j5R" ..
	"MJWj+ej3VUrYHO23T27zQQUuMJ+3s+l92mvitwcXH6g3MNj9KAqole/HlWJrlLUESLe/4mZWFSo3wCHdvPWdjT8lUhKZwcf7yWF0" ..
	""
local PAYLOAD_P10 =
	"Ye8TT2IcS3BBw6qla0+/ttzyCOM4dFKfBrjRYDKLW60LO1IUQR4XqmjUqqEWVw1zizbqnDWtvZhoiNbb4Up6NGSAQ7qXbvAyTlFj" ..
	"B4q1RmdPgkZ73ICW+q4yodGGaUP8Qjrm7CAOhCg2pQeHSioBneVCmFG/yaAsnwcHRaICqkc8X2XTdjaIO67KgpkxvZfWFhaB9gKd" ..
	"zx0ueJRaSCC6EEdJpPCBJdi42DxhGKX9iEjZiNEpJpQ3tOxDT7b3A7XhnUIB7WmtYejWDbM8FV9IgurUylaVUI4xqoEKP1M97Bab" ..
	"uuZctOc8k3JEotRx+yKrYZrze0t9ZlDGYwGYgFS0T0SQgbP/3PfHvh/+RHlYH+IvB9VXXUlcHE8n09i8Sov85uBKDu9wAw4ud/vl" ..
	"hUsvhk5B3K6UMZUK6l/JfS0xKw/3kGX9cF2u2hgHuiPQEWPRpziwIvRRwRycW26iyjG3qvwa/7YiXojJ/wDYn7GyI/bGO0wu00AP" ..
	"l4GiGG7jZwqL7aP7UFTUuit12kw6ro8iJcPYnEe09cHKTpFx/Gqnxq/vC6BePvzEZW5+buwYkW+f9trLFdwnYANF0iYCgJQipgUg" ..
	"m+nAaR9dASKFvvIsHeQCvPYvH+Tybr1CQmJj4s+HGL+S/xrMAYuliPri3sOaZIqnV5bRoTmLxLDa2kSU4shvuop7k78tAnXf9UVn" ..
	"teSeP9GxRksbj4h8Xst4vuhLVbDheYQ/2poa1sibnvjf3rFk8zr0zuPLGOIvN/VCDYORh4uLHnPdoO/FoUktkYdxhgR52tK26io/" ..
	"MTZjIjM2k/482/GeQZCA54pI9dRAI7V+J7Eui9DvVcqQBuayNfmDYy0/d0svLi0S/IKggUStQnEs60GZabYcGzloBtr39UBxa7OU" ..
	"dorgrXNU5Ngag4DEI+urfjVM+DyEYSFYq6HbcQoOyrCv3m46EzWe+Mvr5MtMjflAaAtUvVhfUUH8RcSIIcEtztg2xhtJ606v24Ay" ..
	"x9VWhzGV84CDsHhEmqzCl9Uswmy5g4RRhIH7n0dvgvNgM6p8S6OQtm3fCeXBWj2J1KpE7aBhDOKeJIHYZFbqEC6C/2GSqjeUOvHj" ..
	"vrbSGxAzFn4FElZGdrAm/Zonszhm2T3213dCLkAe9RCxZkEkk+j1n7TI7mxe9i6bsVnO8cepZeusgUMViyZ23zqrF5Ut8CJT++Yo" ..
	"NoX1vyd1IZPUilp5WTS8p/pPO6RW2pG3E9Xw4rhdJ0Tk92piEbcXONUG8/UXpNoJFz2wjcmH06FndAQ7upmHNpWKy3ekZWOJek7T" ..
	"/0gy1q6Z+folmDXMERtArOjbLqZrw+XZnrobnFA3c4lzfM6Dpv/FQli+rd8pD7wJMmfO62eu7RKQHxaO2dWJjQqMpmOvAG/Y5sx1" ..
	"4792YpUcr1qVq+w7z59qwy66ycS3dDpqjakwn+8MDnIvYgUOlwLAifhOfEXjYiH5W51QhgnyN+whZKMz9FFvv4J6nSt9pQFO/iGJ" ..
	"stiqsEzN8Ai+RfxIiRMwoti93Pd7oR4qOJ5b1A9sT5//hyef6a4xVyybDW/ktis4wB62hbDuSlgQfq63zUgB0azErROgLJl9icip" ..
	"Qn3Rn2KwaXnDrf09MD3kldCb6leIUfLc/zLIA4imy2pLUvFmrp/m0SiVEzwkESENBvhJeQyIWYjKTjkAc5xHFAxqGPZr+jWw/ElS" ..
	"dSYT5gUMAkr7lgfGU3zZodZtjhT8wTZ/h7q2F8+M76crnaZoEWhDYmJt4h+uzL2Te4nUUXKU1ZFa6pR65Bxv29Fe11O3/GBy1ftr" ..
	"fldPE+kXbmBSyl2yvKMb++QWlBNSEPTohXAuXWxO6I+oWWQCLAYWLkkhEUXLx85ICOj7dDDKLPkiXFiQwCHLy99m17IESQUox6kX" ..
	"pbq8/M9bHQ26HQq+TO+ppllYp5GQvbLLu4Pu1MIPRDjp0w/b5uQFHVf7lGsY0pieMDQbQqsIMreABI1+GeXLaK5VIKXyeYu9Dod4" ..
	"5E/gNa36CRbqpHRoVun7zPZaQO0dLM48EtRmk7ewKV/UB+Bp4ruYS6aMTHGkyPfKE5DoNhq4Vt9RMq/IjY9bGCT69HfiCpqmFFTc" ..
	"CKCBCV6nXV4e1Uk29DvxsPudRPTTbd5k26EQ5P/i6rkrVhBAfeQcSJ6M9In0PagiWb3dq47LcLBjyP72PHTiWszplLZgAJ4Y3g/2" ..
	"1GAJ0WWKo0JRD8/6PNkYXKt5R5lNoI/nrjpjfvjlzrQFvHyC5kBSEF65PdXCw1WFtE4WNIHnMIfFJwK50xwUN23Ov5qqcspO1R5x" ..
	"libDYLWLuWdXm0VuOJ4p+WrWdYzDJC1MfybYeJQTFx1Mjh2/OY9eYxOzYo69J1moxO0ZD+rZf+adh/E012u3jGFbWNoSlqpXMdnK" ..
	"AQaEDGuQiQji48OYrkrirp7CbskMPsR0IlmmEOJMqpVbbxkiLFah57QbaOanJoy53mrwhL0JMDafCHLBFMdBYaEXWi/0k8arGuLu" ..
	"3zBMd8f6aAcqKSj21+bpKCeZgd45dx2vfmlqlddAr62nKqIdmrzDYQPuZ4oKGk9sDMAiOcMYOorDbVTu3Mbumnfk/hZqv9FBxpGf" ..
	"266BZKXt4G+dpvYn1svupyacsvggK14bM8dUNHzYd0lAeXtuUp7FeddhWD5HWofwQ0nsWZnf0U3+LhgHhNCAAFBIRntRGjSlsHuX" ..
	"bJQJyYiEWEKbu6UMbZxB5gjCPsbtltBLj50iB8kvFHC8zr1zrvvnhESRxUWm6Ly+41PVGYG2izNo6SiRdgWDFR766FSZpKS8d6uB" ..
	"4jp7FTEfcoSdQwC8ucnzKLdjqOi6TkrinR7/grut2kbJ6CiBmqYlrJY3tqULkCG6Szn69Yaw6Jrk9YkdbczEVDrq/b9n2IeKZo9M" ..
	"Vk8DGUXCb6r7/lZgjyTMkv6Ttu3r7CTOgx9jUE5hbR1yhvEAvXVcQ1zhtBA+u9M/RBN8OM0F/f7RIOh5EaMfu9s/BbscXSECwJAn" ..
	"5R8Umxuz0/7DFoP/baNQoNhXtRTHyYDB0r8RUh23AiI6RKHaZcrfktm7vyzvjbQsObtvf/OxdnHXQT6OFSBzSVItwrhXABvNKMjV" ..
	"J/K2Uxcw8Dlnqz701FL+L64IoTSg6yWX5v1I141cJ9gJllGS/VlkEPR6NuAqbqaaGigT7uT3zarw3sfkFmOw2MtPlFv64yom13dG" ..
	"+GicAJ//r+kM2J4wkEFmlwqtgNUdbr1Kv8BrBB3myoU1pn6WwpDXlfBh7uLn4azN/Yjj0IhIEOdFWoRG7UQ8SjSJlI3phO8N6zyJ" ..
	"ELwIbBb7flj1DzPRiIy2bDXl7u7vE2lH1a12eNivlqDDo+tgzxM3luls4otxTlhmlnUJU8aw1YBQvqMAg6QqFJC4dy5KMtCh/wbl" ..
	"+KshGXBKQmVtEZMnIHl34N/PDkXZ4S3TYQV2/r1gwhe0RIsd8GaAMGXU+7kHzs4rWnI3O1LGqAdB5MRGB5ThZJ67IK9t/hyexRIp" ..
	"GkaMv0hyCq2tPvFaJAnNP9L/eodvn/jCuMkW7nHlGt1kGTMdoly7gEQSYhkGP2xU2rOoqL6Td/rN5BnuGa9CARgFGhfK+LF9hqMu" ..
	"RXY77xL7ZHh7LCZjb/ec1C6OXEhQLg8F9uKVUDzXsiViVVwr0hLcGpQiemKeA277VrmDrOHJVhUXhl+DrW2QD/jDfOXyJ9s6uk7H" ..
	"FKXYaLlHXBCJKZKCJdrLa/1OTVv1AKD0iwUFwEQArFsksP4XaTpA4NddpNS8ee5PhUwbT2q/qq28yRpM7l4q7XdboK56dMThKZYD" ..
	"e8w0NTpPoR7riISmP5OD2RTiER4QIoEBQOItwr/uRE2fYEfQem5k7zy9jwuGibZZ64lY3jPFu/GXflXIYHUXv2AUQiu5vIjd71Vh" ..
	"IF7mkreVcDoeGUkCTXmZRS+EVK14p/wbUvGXqZ5U0ip1/K5swCgWaqp2jNTp4F2DN1zZtrFnYjExgiOftO9Lkgs+h+lBbxg5f3EW" ..
	"yeshYkTbEhCxH0UqIntARMiACUW3naxvuk0ivBIpyNHBdzNpYVur6H7Rlw59Lv7alOAEoo/U+94ng0iXzcz05lP9J7tOkwSYQgC+" ..
	"FL1iMACmuViG8urB3/b1PfrcLDPt1ez+A5/bZB5U34LKAGbwU9U3WGZSSqQn9Zq6SHXU+AZ4woyLXM99c/2UZq6bgEVNejtXqQpc" ..
	"U2rGyAFCk76e5tPZEwNJzYQ8y07ozr090BjfYdIJ7k+M2eaf4dOyT3Hlyz0Pr/nfVvLd8QLzbcXskj21ai7ZR6GYnxVGlxht6jOh" ..
	"zzmHVq2Z4JoNVW69E/5WL9vtf1HAJ+TdqsONOOgWHTxGBMDXcFIgtci0Ji8v8yior5InK9x+eXZUwBdjYHvRQ7MW0D92e6Ns/+nQ" ..
	"igc97sAGkeNnp8/Jd7ivYzRbzbWzKqWZHRv5eTC6Ii3QlD5SCLQcKKaQ2U1HTNUYQqogHV9QZ0+FJLIcEQ7sDMBXdSQ6C0HDwOs4" ..
	"wpRFESBdVPw4KBeSJx4I4vjmdLAXcv0hONYCoJNnj/IiOj0PqJnbfDiKkIhzN/LGT4e/k8bQWsKQO9EIr5d5SAkWEXBtCEZIhQfs" ..
	"Y7jWwElB8T+1Ov6KqE6a4lyYZz+1OVELhtAx/ho3qJiQQuz046Lc/eUWV7u3xink+n0I0p3gNwzVcYIzeCEkgjhe4Z3ETIo3DMEc" ..
	"IENWOQ+RdlAIV/GbeYsjgKx9jC8fkNF1/GHG4SI/swv5LEg5AJ+mgOwRoXtAk/G/XEy/Nr2Hu65SySm1xy70TKWC45zZMauu7xaz" ..
	"tFIKT1mUSzZHYd2+YDd6P5+/EwUNrAlnxQ1lhQJKYFjs9R7B6uywfDE0YsIri4pI4T1tCrzI/l6Xs8V3m8uCo/DNppQJAFYQP8Dh" ..
	"yLhFhFhel3FLIv8Oduqw4qEYTruYmqR/chfLWbOK9AnUKbdJmeiUKM/BZl2A2FWbChIE0lsKYKvHK7eetCxMSdtXXTyxw72EjpoF" ..
	"xj/o5UZRMMSjBgTW2UvYvYTUcaUveXnfBOxHp6ZknYjEAv9p8P3usfGtvu663Sim3wQjvXl88oNtwOt/PrxKDJIY3haNzCokbJqb" ..
	"6AeiFPRxZerS08Fhwm/Wa6dmAriy6ueBbz0Plcb3GHQ1JEPCnEA2e/mVtyaB5wf5oWuKmc9CxH1aPWPWIVfgX5J8hsvFc05VtYhh" ..
	"xZ0RlzpcEFMMG+GiSrCgX8BflTOAJuJDSbeBMW1Uq1kL46ACEMEftgzBLKJ0o8H49qZEd1HHRUVV8dIUg6NiLjBg4lM1spzdmnM6" ..
	"xDaPu+bMKkfnCYBIae0+lXGGCuHkJirdC/F/85xsFGH6rq7ueof7DH008OzjpZCBx71EnoJ2YP8wgMETYy4JsZw0qLTuavx4oMbk" ..
	"ryio5KwiwkZs4hV5zJ90kGHff2gj5a0/G5IADAE2Rfs0w1J60TOrd58dL98xvdDHjSnez3gs9Mu4ORCofA4xw62hPTswylkARCTN" ..
	"rvs2DeXXIRWE6SykDtI7PFD6GDXHNJ6LCA80PksQmwUboyCWBaVPBhjGm3tEPlftxkejIxtnbXlB+vrxUxZHhfvgv/66/xdB46ew" ..
	"WXvG4Gho4MgZYXoe0lagvJADfBHl/Ow=" ..
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
