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
	{ seed = 4291584037, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 4289986611, exp = 0, plan = 0, hwid = {} },
	{ seed = 4290602070, exp = 1788089514, plan = 1, hwid = {} }
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
	"kxlwTXBDl14gXiQBN17xu24zAExyf98vkQzp7h9XkagtFAxpusU2fHzpUlxfU7e0cPrgE2cgnooE99gp/CJt/Rc/L8Tf2cLddbgn" ..
	"iomAtSRIzLLWGXIzvPc9Thuow2FcEqTqFZaBmDzbMf0DM8m+arc7spXrF7EPZuA1pPzjLDnY50347PWaXRwkCHZ5rY7c0/LPwPDX" ..
	"ULgLeAz+boAdbHGWuvVZxRS7m1vGAv/YRO791rpfBmB1RYpmMsc6aVXPaigC7DNhv4HTL76qHOnNepFaR7CQ7Ves5Nvk4wmBTh5v" ..
	"2cSjcVJTRgl606vO5axyvzN34+DGQmvnjx31MF+U0G72ld8fw9D2XtEXekWk5ePvUP9aVd8rX4uQSGpsvNwGxrmRv0iVye68Ji2V" ..
	"/QiutZFRwy//5Ce/FMUXGQspaiQdBausdEQXVrWC0ChgFehtrj/T7B4JNSQFUrvWe0nzNAvdjUuJ3zC6hp70rDRKGsmJOGaXqGZr" ..
	"ySOW4/Bmjg3qW6TH14O1YqYGcuMNyOK5Hx3ibuHJr6OAuSv0hTmLBIH2s+BhPmrwk8vuTQ8KbS56LPc4fXAMqG+JZ0CT5zTg4A3G" ..
	"RkALGppOrxRJkmBWw9Wqpmnis780AVQperK1vg2Cp2HOngcHymAHY3n8p7Cl4SYnLwPFEPjhxBRmGvP4szSTFa5ahpaU/1CQCzQG" ..
	"lHFyvTtjP/GJTq+v7v/5DkRI/O88Fdjr7ZffCsbGidFpjge2jdEexZjhjLF7eKGiGIY0jooH00uDRQwSPUpzyJ/QlNdwHvYpWIbC" ..
	"Zjbyl21cPneudXgmDoFk/JBh0hjurT9Z/tRVz4ICpjUeMmh1fVH3KGCKJOQpte+cbf+f3I6hHrOYr+SqhrYqg6NpXxe69Y20FkFY" ..
	"5/VqwlAhJ0G7vmGHZQCWh6OOHQBvBNewE1gCCpEFqnQ5zB7oL43FbDiypKPl3OYrZ/Czw4vY7anAMJlz2XAGn/Cy8BqVEJNm+G8I" ..
	"lSAMKC2UMgZKxXK59MGK4lJQaO8sO6Ilcvt4kdxOCsF+xJgix2J7Px5cxyTeGm3dmHv5Oyz9kLPTX6ZS80qvX7f0dpJ9uS7ErRtE" ..
	"YK++pkjpPz9bUuOuGRk5ai5Y+BV8Cmqxf8a4Cqgfkkhr5BCx3524MHeXaEtZET6TR3FZn3jXZGr0ieF+Q+H79NNifuH+Liv6BCco" ..
	"SzDucBPop7MhF3NECFYvp8zBNuLFMEQHXKJNXErE1MvXxi8OtBZimMWJHs49BZwJRRaPr85AGz4IoBwscJ+fM5hmxOhe6W6qraNj" ..
	"XgfJ+mGwJMK0Kr053fVw/a//rD8PpiQiKC2wXaI8gl6yPuZ7nL9LrUr3Szsnd6dE254ua3lHdoF2OuHQlAqjRG0CENVUX5rQIRFJ" ..
	"PsyjHG25owGESohCivzhCnVp8MlveRieOQJTOGUDTkROc1W6sFT1g6hlCmAORop+SmCuiwidvcp8wqdl4kktS6yykde1JasG3j3I" ..
	"DdMGslxdzxVX9RmiIl9ZK9zNq78dwVKBeAgYL/nPBqu7GIqFWzEFaUXQzYZvdSjr1o80U0dqssioIWxBtmmJ9yk3Iyl80oa+Jiep" ..
	"ADHMGNEacJABvixMEoY2y7mLPL5jFKX9t5gFx9r20E/NpT90A1ZJBbEqiWbzDM6Dt1bABz4aLq9GcubOI6HNnh4BfqmWO7dL1bY3" ..
	"yKleRkZh+z6ZvjjJB1mLkAieZqBzraLIGbPtXHS2XciYAWBtlhtewYRfC73GZQosKZR/wl0gBMF/aoUBBQGVPbThKrDFT3Ph7IoA" ..
	"p4fzNY0gIgJl05OpFNNpIuV1vXvcQm1I8MQ2I3slIVum6QyTjP4pVzRjmg/WfhYR5fkEFGCzC+JiRy3ybB6BuWSPCiP1kiafNB3T" ..
	"9lxd0ImLwafoOsFLbNffbFUrS5Tg1aki5fFNPcp+EnLicg+cy2Xmhh9qMYVLxS7bVDp0RgM7OXItnkjY4Smq83hpyGE9X0Uaa42P" ..
	"E4RQc8v+bZtLaAqdYT8zcxb3tyx7+XO1lJU8HJ+VmvBBu0UFiWxPWNMKT5bGbOAwIiIlaA2RDk2ervL38ytb1HMNFDCbhaImkvvD" ..
	"zvHMQE5VkjMHz7v9+J8JKe/wGv0uM6JSOkJ9j8CTCLLQDxh/Kv6+4EfR8VX2wAFKOuuq8bSBrOZ5oGuxkKNc4E+IGUt7fc3EqEvY" ..
	"Kb3LYvBWdP7ChjICaDScXVxjrQoVxL7iyNLgxr3bygNs2ukctTxgAdbzceCMalCVIkSvYOR2di9s2WsaBI+bgCx0HXGFomWRlMoI" ..
	"E8gqgRHe0WLzV+8l9h5ves8e9cnziywh7BsPTgwA/RTE2ewOkA6Z+Y+ju6FIjiGVgTm30nFLUDO1N2eZRYY+p2bTh8Vp6gPulxOI" ..
	"0YEpnTVXQM0UAMhTTgIkxrnheqrZueseN8tEJZeHwJlF4EKPuUEPCch7JK/jdzH1e1SAN3fSYFBHy6ACuG7JgOVkoG1en4NSWq4C" ..
	"lfmVMcaBNgX46CWLWmRuwYXxpiMjDOhGOedPenbSTdjNKYhSAGAC780UbXupTENC0/1aC7NLcCqfESkHDhUA8MoGOzdWXEBXs+hY" ..
	"59fMrmb0tFqhHSEpk1x3Q4wOI25jLLug3UTLCjhlK5BXvx/iJPMmUngI9HpSH3HCrp5xB4MQGB5ezuRp0QAZjLEf47EF/Ve5x4aY" ..
	"yWMKmnDSI5RebndveTEptWNp4hnZ4U3qiyoIMAKfTSDEZhmILipbf0CgAa4Vrukt6XBDVFDC1wIuBU12Y2HtoZFcAhCuMZk+J1sV" ..
	"rjiYWJ3EX2DfAMtY/TL3wx05+/fzKhbWa5B9LKLwHGHpqb2OzeWBS2io8u/P4p2wJNvTMOS1Id/H8hcSjJgtdu0ZQ6ZW833cZef4" ..
	"rc+qmATA+BA9S5kqEaKNi142irbnjAEsbeYtnPurkuJ5zBo1fetdoe8yIxWIgx/GxSuDqraSj0vWaSss3aAXG6yHEHl+7/L6EOnf" ..
	"QF0MsStM1p1SL7oqU1a5gxGhgcx5yPpSBTAZQ8xXZsWpsCXwyqWOJ1H9Jjy2Mw17OuOsaiT4ButIe1Mu3rRqWyHgw+xCGw1SApgP" ..
	"koLsX5q5XriRY7HtiNFuf2BlgDg0s7bvJtKsjfncVG2Gf1/cahoiDi5z9Sb8gbERkENDSt8zuY3HsyQ3nKuMc85ncAoaY/kfLYWj" ..
	"bGDxegVRwa+APXRPXCnb17R4TrMNAalnyZrtMhoVpsY2+JIDRj2pPMkjahw/L1LfnB3IYmrigDQEBb/PrH0xUAUWxsm/bYVGwMzu" ..
	"Cg1bj7C+8KPIdlwWOLIPVo6Mx31Qi8uviNW7ey9rx/BfvXvALzIMTmWTxO0h1Vi/guIFE+HbgDLmmSh9A5G4y6bcItRt/5ZHHYDr" ..
	"JyY5BnR/dEZyV0XkKjG4r+M7k/k9t9WDnZsffk6c4KOAA3GauauYld8Ha/n94Rg6Bo4u3TkMqpY0aWm4XBUoL2t/6hhsH+NYn0yK" ..
	"rvvUM541OXlNvBZ6WIBVyaP9KrTu7spii8BUnvJpWxCamO5Mn84TNd2ESe4qYozkqosBKffFopRHoW28I6ZOBMcWjlCQ8GnsG5kV" ..
	"OGNwWClLLL+oRI+RzjL1etRKTmLWk4W3z+utQYRpIVKtYsUwYkTwBvB5lSF0XH0XBI+65booPY2/S4elJ5q4qRFzUNPCiyHXYo/a" ..
	"bCNrsMuoja8J8YlApagh3rU7jqrkzPjPB0B88k93kLf23HY4XNDGIPMbQnQ1PeTjQpwfr3TOd9eBpzB2MTUWabIHxw+7egWrkNGX" ..
	"4T+XCTjC2BJGX2saCTeH0bokpJ8P2p2keAzY508R0QmjHBFHnk89vIpwDIAzg6KMaTnVUegitSMusb/PKkwU2/GOYMbYfvp1Xkmo" ..
	"TFRVUoYBSLBaM+sZjfGsV6lhPu8py+EBv5b0gU+0R5T4UxBCS1xp2XhLL9SNVQkTW45Hh7mYb3kwpEE8eho5YJ1k5RzpFRyxW11z" ..
	"8+2dxzTjIJiEorWE5VOp0PPj1ZtgFb4sJwwQoKgDiLDQetMJZsiR9gBxgHIhCccyRFMJfkv7EEtCqiDlzUML7yjSEdOw6nPRNCrs" ..
	"gHsypmlldXxapmaBpBkfisSN5HJD1ENSJjuNS6iW0Bxmy5IqWN6LOM+9C6IpG/ZNMrkAq7WWVpd+bbeOhPV8J3DJO/i7GHx6BqZ5" ..
	"YsKLqX3NbAvskFNEzJkES9rppN5uO9DTurIFoz9xUHIuxiXvpHgjtXHFY+my89KKq/8QrYi6bXcOOoyiSrhV46x7TbViBQ5zOz30" ..
	"uXWuYSBUKwXdrlRDS7NpvwxLMT5x8wc5tWt1v1nhJuyF/O8LEwz2Mvql/rC1Pg1xSstNvv4/10KYbM+wEs230x6m9DZwUk5NYlKM" ..
	"jJn1uPuKcZKPZdAZe8SFTDP9wI1zv4Xzfa/K+FstDwp2v5hL1Kj+3TYlMNi8fGV/U7u0ONrt48SNy6J7B8ngL7dI3UvMTRoABTNv" ..
	"P6pJm+LYDASWGbJlR6UO7fxFxC2/t3w3olEDOqQJ83JV1la3StQHuBvThaJmenJ7hk9XV+Z/c0ny88oUvJrqi2f6+CX9eBBmE2gT" ..
	"B5P5FG+VC/a8eQ9kzL6Zb2PGYcbHLYsrdfu15+0h/dYNwNxaQC3Aa6tmTO/04trSZVq3x1MZwQabrTD6QIPj1vwLKXZnL+QfPQrP" ..
	"YlY2ywRupaY5mS91WyYsowML18ub8Zcx4c4m/9EPaF3i7FTbMPGC7RtR0wWfEbUp8BvAz8V/+8l41y0r40eTEHwf4XFI77PSLrPt" ..
	"tE7RvXadyzgYSYZTot/ZkxgshOjxoLweNuMLUN4Wuoqmg0VImt9GanOgm5EcD63fIfT6jvrtBKbtDLGDVjk3jHrk2eEAGA5Ht39v" ..
	"CsmDZlMcGc2H3ejRrr6/10oslKSOi4WS0ZlTuX7kBHNR0bxPNVwd17bflxE5Daf0O9jwmmL7GEkvF4CYlpdGi2+whoBlxcEDD4F1" ..
	"s7431KPIGgLMf+mz5bahPded87l3kqPJWG07IIyfk5s+5rKjWbU8k2hr51CFZui1ZR+tfL6XMeHtZ22dfzCY4+OTHanD+KYkqC/s" ..
	"fV6S1nk7y/K43BjIaiT20HjKhBzFyC28vcrkDcM3Dxgajsldj/hBNdHyk1Efq1hJ5nvWizecROvT9x88KXfmSApwA/jh0Xee/8EZ" ..
	"VauQOdlBKFNCm8fE3wHcZPSf9A4xW6GW2FvQoJ2bSGxIwyL0UnuvcEkoRuwYNk9cDcJngVLwlxNgzNof8YE5NWIN6jJzg1L/JKFm" ..
	"LZ1P+6MWZGczOPO+E+PzpwmICo8beXu8txJuTOy5VnFnNGBeTtmPqaL1m2T+jgi78U12Em78cF6diJ51W4izOBv6tUG9eqyTOicN" ..
	"X3hHsnASC5RzxdBLdP1RJIkFJhLnpu+0PSnMiBRMptqbBf4VylXQljirnNF0/7acWsDZQ2gg6gfOxqPn3DzNy4XcRpXbchZE7GOh" ..
	"UodZVf/7a+r5phVBDO62EMEX2ZEQsboajlN8V2cyHEaE9sDo8LJ4Zv6fpJM1GIyB/uOVXOoe4GngoI6+QOKzv77U99w5V31NOSg0" ..
	"y12iC08fAVjus8+W6pCn8qG/mthYHYyIbsBxxS6Svt/0ag8Z2yagoA7zMOft7+roWF1l9ww6Y5fJisWLFWT1ZkvPxHEAnSwu79SW" ..
	"JagNV5mHEngbreBzJkDVxcyP8SoGFEeTNpIZgi5RPATB9500iAUduZPPdpBvGdm8udp9TBu8x7gnNwi/Go2nQSAtAaU/ezu0vjAP" ..
	"Pl6Lcek+6KkgOi39w5jaOMDD2XEOynZIHy03iN0AsrGBUrkKB08AAyU/gyjZ3cRxLwKFEJkxhusdEh2EipsJs35KeMPcAEAgdtT6" ..
	"JrSp6oQMIBxgcMoRume6H0PnoBayEM9BgBLpxhT+mo8F22TK0q3WNUtoSxAv1GVBqtlQeSOZDazqbp7OP4emrM++atPfHi56+BRs" ..
	""
local PAYLOAD_P2 =
	"HUVNXmkR+B6PAwWqYu5KHo+Q5yt98ZYkND+ANVBQf9w8WUFsdNvPjCYSY2s1iYq8POAU9TvUbVCOWy2NyEG1OnUpwJtZT6MwHvXM" ..
	"sd5qKSryFg9HIvxU+cQ8Vo/Ltvvfw9+1Dib6XcEe9XJXIL3ekTGvV7Pv+YCtMuztBd92aMddlp4xDk4biLz7DB8AroEO/KMB/Bsy" ..
	"Ndstt+akGJnC2RUGd70Q9QEtT1HsUqyKlI1FQPfREWbchBAqPQzDKzZzLpCciWPw994mE/2/6QBYBJHKT7C/Lj5GKpXCStNgnOkj" ..
	"BXsVvFbtngfD/FZAA8Zf69aDN7VbVt2nzLuvrZBHTGWkZj5bBvvtN3XLCo2pPc2yJlWW6zX0lvWnKrvD12t/RzXQz78cGhtQQGcQ" ..
	"snMjGUomer8ypK6Ze6QmtzGP57YzmYf9NTyFBrZcdTz6gwUu4vp5N80szLWpKgiNGiuBHNFv3ONkICWsmUwCbTZ61NGbt/Kc2eP3" ..
	"vrc7/GTwGKCGMh3MYHCeN9GhiV5J2XZszRhRRXi9ho2Dqo711Dl6RkJr1Fa8g/uHm3ANz8afomsRXDpAExrXE1dmDPIudDEyMBYJ" ..
	"VIo1vA5cptq7SLTymUxGwT0j/MVh2B3eoIbmRvQCiNyx4KNehDpQcfb+8fIojlJodH/KiCROjFihsX3Lxgrr+GXyyw0ZzEW43zUN" ..
	"aFkoe0zig7keIGOPIzR67ek9FFy6XZHR+HeSRukJqETmhAknFmsmHWHo1c/mqO/orO8TDOydktj66xicn7Nga8Dve7ZTP8k/Ys9Z" ..
	"+kNXUgweoYBv6wM9+/0OdiYLYLh2XdWTivNbw9ligr3Lz7zseo51iqJEybovAsA1JFBEnQIfTSMEmWMbSjPRYWinVfFfZ6jGxO8g" ..
	"I08iZJlqqxGtImHtkOScxfeD/F4uVXqQFLHcNhzDZ1P51fIIjdE5Fviw1WMRIgl3QuDccFQFpKmuShx/BN/lGBtnmB57c1cYoyYL" ..
	"huHpvxKG4AxjxFux7J1Y829sT64M040KDQX17ZZ2P9Ec+cboP/dGJy7ZPV1YOqrqUdl8yetOuF9orp60WQuoEUbdre6j3YhHKosS" ..
	"3V4gsy9yo2jIqFjgRqNfxtWh2w/VGwZiB3VixbD6aTGXH9CLdno5X9QbDAoJ7zuzpR4Dr4uYGI6g0KpC/lVi6aHKu+c7BfD3oNJ8" ..
	"UqKzPqxC3z1aTWzUN9yTKIXMseprrVp6VnzAV+LE6E5l/B2tl0e41emVhQZf7Z8BosxMnJOOBJmu2mifEgrt1OvN3t56CtW4A5xm" ..
	"MAZpJ7SvX17pFbqKYmtVd6BjFzYi5ARxQrLulyVSIED4EUthkyDHkH9i+fkZOFGba8A1TF38zIyWmgP2EUGdgV05SzcN2PjrPkzo" ..
	"LzVQ2I35mSyOidVbFmzKKH/6l2TCiukn+o4nZ3MtYn75CsBQdl3uhZzXKCPXLZutRWXyED1ElXR7dplc/nu3ublDsTqasbLB9kgn" ..
	"tSa9LYBFMtuYUrNK8FMBGUS2+WevF04oQchwhuwmgDXKqsRC2Kb3Qup+pz/LZMEP1+34wALes4KPtHGAvUJrzdVVvmFPsFW83ZFF" ..
	"83R9SvkamdwyzITmmj5Iedq2NWYf28UKQdPS2Ck2gITGpo2wxKr9O7GVJBcTkTd/IjulDdS/9VrNEBomZ1R2iuw4AXQSbRpLTfom" ..
	"okpJjbFTFqwGXxMYst3Ilu2WMjKJt3gdKSZwaNZrSodWuCS0yVh81exPpB5IUALC8Qgz8yA3KyicYMq8E6fzfTl1q1wpxTaERgD7" ..
	"8AlFPN15tVYc0hxsOZQsu85TcX22iGtK7nfX6SSRQE+eyDhRQsMwhksOAegvybnQn38rXYhkksc1wBXVjzPfWBBvm4JRgmcyg5Kh" ..
	"lhP9wa6tXtH5fyO5XKkUowEba3nwqal7PoaQzMfsIegtbLPi/ufczCV7woLpx7zGku5puhyPahgh1etgKukm5RkROgQ1V2IE25kM" ..
	"H5/M2OOX0COINaixbs5T7D75cUL3d8FjHtLCtL6aTu1Z2lV/Zfn4VpFw0M356FwKeDHm5Cr2dLr9ielYOgArgRwbAlwcuR7ZTMkE" ..
	"uNbqcBGYbwtpLovDozYe1iQPilxWOQr5xTy5FV4ELznZWrNJO5LqLxfcavNFRO1iIgmH97dwnGsov5kZTmRx+OQzvz90bCC7b6nT" ..
	"eyDI0V95YeRRm4OhrB7T63MFPtf/BlGhDKYC/APxqwWJo8G7FCdNrrdpLj3ap+PBsV6SZTodwMTFDxtn9umDYPGzOw+pv+2QnUVe" ..
	"RqLCvh3mcLSWN50lgDY0R832qhLw3dpb+IwwvNGyg12YHuQWdOMH3t65cU5rhd5OK+lQO2yWEHhIfLODWk7af5scPx0/3jIsJsvx" ..
	"x7JXr/4NJpisy2gH3FrnIqYk9fePlJJF1gV1Z/4ECe3jWLcp0XWGSxVjt0G2QzjI3Q0Dg0gffaLg5QWuJOqwt5w7jicP0LsNNquk" ..
	"2me1CJ9aWoD99oJsFKUrNF0QNZivdotlaIajaWLG8QrciyPznkpqF1rhx37x+6GmsjDE8NO2aEGiZTUDYrYFwQK8WN7zMSQpUt1S" ..
	"ri70uTPYd44gxSywOGOTQ+TGL+y9OcC7VoV3yA872ijCZteaAp/nHzEbo+irTSZ5gIS98gh1IaTb2fuEz8Av1uMqYhgI0iFN2GQj" ..
	"uxXEAH+XhQ0tBnDJTN2C+4sbKptsc1udrHIJX7NhZ4el5JC+0Z5zD4Fiqlq+T0lhE0LQEq7PPpWpjAYcCSGgLamRI1HHpfrtUqHz" ..
	"Azq4aIJzXiHsPpHuny9YpMkz4G1gL5c3/vW6f6N3Eu/m4jSlfi7K4O4wcZEK8BT5ehqiCgQHz2XIxdqQaEfUJFrfIpoKSWb6ktQ1" ..
	"WdN2kuED/S3sZVavG7rQotMQx9DJhGRV+0eX5/y0hVjnNYR1JxdP84dvgb1tm6Pq5tO33WlOoh1cRZWdpK6CmWEuae1j+42KXaer" ..
	"vI9BhEWd+sgukjN2gOAp8pXmFMTsL81ulAJQpbiR4n/b8iVxqXjtMOzkk3VdObGNiL7F4Ijie43fHVE1o4IniaH5N5SuKE05mUTG" ..
	"9Rk9jswp6Bsg4PfGfvy+nqHtOUUZkqtUJmtBFWMyU99+0XO3qipuly2L8BE+hC8OrZO8l8dNbwELdJxUMZ1VKkTynaTHnR9YwDyI" ..
	"+RIw56ZpSMEs4niRjs+KE+N+Eb+6N2IAEsFdR0kmQ2/kPFxfMLreMgj4hysX06zFnNC/ez2x2KRoCe4LnQ3BKmBj1XofnoARWfJU" ..
	"Izb3cS/BbcZCg3QcIBEOn9rwzCDge8/3o17xGfI5AICYfRHqTDKpJs7mGG9+RQ9sXsyjsFZ87tPRKpvWeQD+4CPq3PyForZQB47V" ..
	"RH2NwEp7sjcOBKYDueT7yecZNgKltZV1YJhltj076Z+mWqD9kyXYBQbPR7pJimDyelj1VuUPFHOO8ZMoiqzlVPD9o7OV4PNx/wp5" ..
	"Ms9kw8M1L7o3xVqCVNYSlrHgSsRCwZU5scxE/Lo5iMEOLi3cmyp6M+1tiqgMRyOOlt3zGwefaZIQvwBI57sYJ1N/s/88iRB0q/ZI" ..
	"6DqZ2jTF3IWSBkHRhMfgrNZ0Jxr1RoVYtIisAaQ7GM/S7BRmSgKKtBnoCB06FFnKweeihntc7MQO7fPQ7fBz1jtbby43rGlILAer" ..
	"Jym7QxQ9fS+XuEsvSzbEvht9qA+yYIsIuWfg1vSRVa3uSTTI3ujVr9pVtHdil/h1huy8eGPMalrMJDk97tpFXnTOC+sUmdsoniq0" ..
	"lyWM9fEVWgfO1uP1QBjAHvWQG8NLeeZKdQ20HlAiKSDeJsgoJKCWqrsCiCtbcdgETnkhcU8U4qGZ5kBKWzHonLu5CYTlHCVLu+Ow" ..
	"MDLzBC3f3Z5Glj4ElgHBjDJhEi/D357AHiQrRXPSDABL5etQyOs78z8s6CIw0BZHgFhE2bMFpgkfdvGQxk+S6GLAyCTJxNztMxOd" ..
	"lrKVuEh+PQttJxZNhmgpp46dH9MNYu3DK0b50seGxF0l0QPxyCjo7bPufcwsZoZiLW0iq6Jq7Ug7Agf0jfMBb6jfgw2JlbEUDzxc" ..
	"zUTlgvPPnTSA9vfi924CyevIpHzxXKT7nHoSnJ87BTCAEFWKclOI3nTx5cIPCtl34pmmvMslZWAIAsmaQsvPb3AmiovPmV56ik1l" ..
	"aucNpO4GTY2nq/3ZCRYOeftHC14YF2AhCrOs54Fy2EOHfO005vqeP9CQPzY734dZK0i49DEi8ptImpkjbqvuWS3Lt1DYAwrlFcRw" ..
	"cYtUU7tXqMefcPHafNYn0jN/qyeKLsrmnmRsudoPU34q7Iad/JobFsA+Crn+IioxNMm4eKcjVOsGSmgTrsBC9M3fdlH5K/Lj9QXU" ..
	"mBZQ/R2EPCQ+9LjRj4JJM7vtkMz99LGPxDYOXbbDfE7ky0ZpG66ZfvlPYUYXXw3gUfUWcpLDYUb+yLoeHmAkJD8fHzjj8toaOKId" ..
	"ARBT9xj7wD1E2UeF59c4v2JUVLCXoY3SXEaPvljr7V4rrwKT9OotyO72ALaiDsLwQPJMGjVk+dRjlCP40c4GfXcAoxY8P9LvsSY8" ..
	"sb0d8czBNLtm6xmsRQyug8stL7PisUA/LNwSrUhxlNn5uLcHZiGToMBNZ2N/5ytmZlWumo18k6bsaKaVFE+1aeQRIZV2clgj5E5o" ..
	"Drh8cwaXBM8oKWxIT+9yi9b9CnbxLCBDV1cGBrYszNSbpsMWgxkTFDTrbwd8jmcsF4LnY4WEWgVttIt0J2Ws2n1GYr20/wNY2jC7" ..
	"c87i2k9ccUExpHKXGBXxCpA43DJ7UoeiG/L1GA1YIQWIdeC5XAzgU758Gm3Ct8ryiG8uMv/cUf+TezPHxzAKhy8eLXdrSSB46cfY" ..
	"3gww5JMkSXFjr7lpuFaiv6fB6+9sjWWKJDkJ27oSREp9GJDoa/yEW5ZcsS1GB6INVlqBTOFVTtZmC5LckTHRrGSVMkam39bTHnTZ" ..
	"8H/uM4XFR8Q6g33f2+jAJJaA74JzFm3eoyyqpQ9uTnMFJyISd6/UWsg/ZO8cjWiFNYurblKKwfRoseD58vcDofgEU9Qxb9rrl/Wp" ..
	"UJgDavNtngCQ4RfZPulqodJzdv+fm0rL8lXMpOWSUQx1WPCrGRdurQcjJbRl1yEb+CRnVU5MlI10FAq900KGcXTc5M/81F8aKz1t" ..
	"lYu03PpNmbzLt2yIT9r5S/QM6mysYzkGtIZCeMZH+jEFjMvC679qICzNmtK/wlpEKm82LLDDWclddON2ZYRMqJFvz0PHkOXV5AOZ" ..
	"SR8geJ0HOapvJEo6gaD2Tadxf00PXUftghg1cGZc5Gv1dQGOY8K4ZRMXCFkiU8k+dbLsQ4IPfZCWv+s9e539NVt2SLsqNdQtbIir" ..
	"xUKVhboBh0FjrRxZd/3evOc/ujU/Pdn72xtP1dQ3WOeMpXUVEWruTMKpnmWX8TV969UozpieOi1Zq4nVMTOguDXeDKPCvrP2OP7e" ..
	"cstLvZRzISlSAFe5r5Ju+fG3wef+QeZmObFtvU6PyrDH7xNPE/Xb1oaR4n0PDN6OpIfDgMP9w+ZwIJ2wPJGqmUttIfZe3aRJWj6R" ..
	"SsaqNaAixrrHM0pMBak2vo7e4YA0z0Z2jMwiR7WUN5Q/zTZ5pZz627Culomq7DdeVq/3DdwYOBOuMON3psW0wlH/c4NiA9RPca3c" ..
	"1f8WqaCizKjHflDmvnWsw/gEqZdglL9podgd4ddR/DwXHhZEZ+zoZBh8XI/eRwY4N9pAB4TR6M9ywltNTQpeTufscQ9/TUvhdo3u" ..
	"/gH+RfXr6PWlynXWl0DfsCB4kNFL2MXpEKWwg3dOyE9zcp4Hl3deZdjULwcnkMLy2QSgpwFpFabB1xPYsw3vedlrpiivp+QoY1r8" ..
	"XBrN6hM0GfeRtbFxfD3G1YeYWjYzjYjT8/4uPwZ2wNtaFqZAgAVRrNxH1K+TCkUQqmQLSNFo8NUVPftVbOv+X6Sq4Dxolm4bq040" ..
	""
local PAYLOAD_P3 =
	"CQ2VbZYpte49BXPWmZjhu9TuFqa7XR6dsz1DXf1wPmggnbmAmn8j1WJsBno3mPYG6NfmWnmem+ZhNNX2eIBQuklZfhkFcXWWp+Wb" ..
	"2JMGxJl0jghMqpCH18o8n4mdDUmVzfVH9AxZlkbd/Mzb+hEgCE/1FrZXUoCFb8WtPvJ0IquYkANIsxcn+LieEoqiJ8EgSjhb110T" ..
	"Xj7bjrWh0qAhSVCb67FvepYmi0dE+/u/ZIhMY477Ji7f0HoWjNrikPMIUvovjsqSIMn0Fuids1cdl1zyhqmSGXSBqsKK9au9dJGk" ..
	"NHrEiHKvU9nEDScybYB+MmXeRDbXyguvMRZMTuh+a0TGt3KLhNTnXgwG2AbIRnP2JqsG623bPUpqFyPFnNLKsBP4wj9ZTby4CKax" ..
	"/53czhFga+bGZNgnIY4Z36UA7rvqAIJUzpMrYAsb6bhLppDt7u3YohMCUo8pkOvGMnMo5VMWwD21+2ocNUWDYV5+xknaTADvu69p" ..
	"9F9dhzUfRZ0hFfoG8XnC09Lt6nfhaIWSkBiHcIg7xbQ/Ws089aGz1abs9EcrQM+Juj0Pd413LvwU7nq166wlbkxz28mcIq/j+5me" ..
	"tC3sZUwoWblff8dXUAjKJJJKwmvGjF8dlhUavVQYWpC+WPRkyS8pf9YUqC6SdW8dh3wo8INkHKzUTfsJzV7JQL/9rLkqJh1bZr8x" ..
	"TLGbw33ujL6Xvx74RzBT/sSRVqmCgyFV41CYcBUAakXQom46+g1jzdxfk+coi8IRz3WkjVWN1wZcOVE45Q19IIQEEOPKTYkJWhVE" ..
	"2be7TUNcfq1JSQIGVVTxrrj2hyU0z42Z4EPau7eWqC9H8CczxJt4CnDVAu2I9dv/acQvcBLAGCSTDtleon2ryj6jj2nuPZiPY5N2" ..
	"t+zoGvQgl6ASuKsAlW/JJmkopF2H6C5tULgCP1ZjeRZBSIUMtABhZ07aYcmmsLVXzXKdZcu9WcWdmhF/LsqvpXAce6zWuT7iDIR3" ..
	"F9hDTGfd1BK3drgECoa/afVJTqXaTeKmkbssxB2AZsc4UCRsuXYBJ/F6Oj2BptSRyev1RrzLDA3DRbajtPqLY1n1wVehY6zm73ou" ..
	"OQBIQHKjrM61ztoouq6ndAAfkdddf/MDErzgdefBr2T9+aByHmFHR71cOxzSdDSVh5P0WmNqoiGzf9pu/1FRCjis9oDdqEONm8Oe" ..
	"61gxXyu7H7r8wnnPM+JvtML2olkSRkc4JcdetBlZBCCDDAh6BctW8LiQfvFmbLMP3K8CbDYwmnKQRr+KQ+06XkB11y55zHaDEznL" ..
	"LAXYe0GWbYRHEyTzEFWY5b4mlRgyzrPZxBv78PuybtJRSxGq15VHFYZ4dKZEeHYGYH4Sc/DMrfp1uhp5sbHIeWnAR8zVOQhKTQNN" ..
	"JV1oNg5P9rUkxHL0XyixszxEViX50kyrrwYr49J7EVZTQCTExK6Y9XgohrwwL+6Qovmd9tHAbJqrGwhNMg6/MupkSGs1bp5CsaBf" ..
	"ZbhqQISSrKb/IRdAyEI/8lRaH/rT4hXw+2nfiAtJXBYPrfvlgRvXtVu87RTCDfChGtxBb65QOgYDKjZKoJRo2C5Ihy7a4Ya+kVxH" ..
	"6V2UP4ZGfkUipk78ppc1Ivu5Iu+UgWMDgDElYQOl/kVJnWxMbrfdRkkPNuYPHW0LcfbWClf9Z9DY9zlFTklYYsQFRiEuKg1USdRJ" ..
	"F5rROOd7hBwQqEiO+PCHRDub+oUnJtDvjAYwqdhX1aixJyAVDLATSMOWfybMr1KTCKbJFetvBUekQGjs/DA+kib7lW/k2cI0UHQn" ..
	"KIJmqp/UVJc/I69psHgHvsJ9eZqd15Nyag81wU4hLQQq0K2IgCDWwUMpRo5Vj2cFSwFwdoVKOle7OZ9f56TDIDuBgbNzxaaP7i75" ..
	"hb4JVvrDYrs2XUFRKYw1bUHMvKVUglHp2s5Sfdb3+FwbEThRqAD916ReB3zPltm16CKjnl9bZdpUaP1U0Lb0QueNdvKqZIiQVbfL" ..
	"ychwxJSeNuoccPZZb0fhdAdtsPas4brtocHHt2nItkpYPNL4mNb5mPWhg6JY2Dih+aV9REkrSAwporGqR7KxyS0Jk/FXE4p8C0iT" ..
	"hb7KcalmMrUeUA0gbTnTAMy3jwCSMKzc6TBfQiEeDIsJ7EgwRlcWCtQ9AG9Vi+IlR56iWEXk7G2ONY62vdj9RGICGrD1FlmXYMas" ..
	"43KLRiw6WSqjmWe9XrJykeAEgYTzvrs6/XByNyQbZNfMkGwySupxrlJvAi2jAiPp9LwIVd0sNqhXv75pKE+BxSDxaXM7qygxPhVW" ..
	"LI/cXcM6zUCwgsUGty9FCjoIszF51PPnkHIU42v8mXUCpb+U/aFAYLzH/B6NhJgsr7Hi001iL4CSDfwzyZZK/VNGNa+2yhSRxviU" ..
	"Tyo91iibbrfbGc20zuR55tmln7gEh/LsgTn/tU5JP6qlw4n8ucLZh7ApWEO72wpUP7Pgi8LLOvKTq3gcOJjSLQlKdQkBJJufrif4" ..
	"0LGZhgVxu/euJOK/1BAp0bPUtGbAh5cx/bVyFA1J5iLzgiMtPoLQTV0mPZWeLIST0l5oZb4fyTJdGImRwMJqcoeJVr1HHbigmnvk" ..
	"4cC9meS1yo3c5uPxqBmf76BSyczwV67DSxPSN4HxCP6fXGCrY9R5O68qoDof7jumCZX2l5ME6n48rXajKKt2VU1nB3Cwg1lR57F4" ..
	"RoExGOIsgVmCpmWSijbtB6mqGAMljgFrQtyCodvMLA0bO22SWIxzfdF1MEzqftcfP04DbHv2z14nKb8tJXRSrFa0oYdHBI40tgR2" ..
	"SSJEHFFZlmzXSS1Tr/kxRQ+X6FZFQFkF1oNC2krRUxTqMzfvGgc454V8QS9Y0aSCe5Wts6Q0qYzyhK6OQHB5hb9PDte0Bouiaq56" ..
	"8rdjbveuFkbpoF+ItIfp6oZz8HNitL2MZczRSRWz+w+VVu6lgort8GUqrQdqnzK/opPu2upgMvSSbn0svPmrCqH+2Tmgui97KOOh" ..
	"aviL+gccTAk34nOildqau6UFuVIbX3lmcItgnzD9e5weLvgB6+ZxTiWs1RaMfBMtHCRZMEgw5fLAjTWd4Tl4X7xm18sx9pyWxo2Q" ..
	"wO7kwE+ER8SM+OJ0wS3vEYsywX1XVOxdidur8Gs4+1cEbUF77k/PlB1yee6YvZWXw6kBfa3SJ+yrWU7qTto661obwDqPzeTz3cW7" ..
	"zXc+cBnLl3KigGCbtNwgiwD73xgcuFrMuu49vZn1ugvpKlmkdk3ZhIPHKUxsYJmAwZORXz5mbjL/D425q81f56DBxQNmXVbxXfOO" ..
	"6j/6BF+tSe0JQWq0iZKC0ent4NHJLKNTovDuBFDg8aKLtTSS6PpTqVrYRVAGxq5Vza89D26gj+irz3AfvTc2P1FPFhU24DkEUN2p" ..
	"MKirlgdc4W6jQruXuZ+jUcViwGTr6lyTqRGQDxjo39XPJJ6DeD37lvI9Fd1vjiLlzL5zRTRnajwAabCrEftH3gSI+hzxNkXu9wp/" ..
	"mrSyQp/1qkCP9kKqbvGqOaZUWyacS9h2xUc8brvd7QC1LjoAHjrIzeP4mQLF08lwhWJ0AhhiBKVsPlgOmJ3Qbxut7bPvV5kd/4+1" ..
	"+hniyh9L8nl1YPFQ2bF5DgKEYXcI7KcJYh0YRXfROIhx7wjVSoav3JqMk6aHJE8wvu651bWqZkX5Cafb7FNcbZZJgUfPf7aJglR+" ..
	"InjLWcOLHMuQfUIR9VlA+/7RdJvLr6OrMoCm+lb4lW6Er/8Vd9M7glAxI4oNv3f07k+HATFeD8KNnbbLc48AF+zEPua/dTnmwb6k" ..
	"nRBCsM64hF2VR50wtkcMIC9+7zbQ2ee/8c1VgrvxTMTTxq0NSxcKRLkiwhFO0QoalSPk7wB+gNJDQeyV14IXR9UCY6A6Otsb6hpC" ..
	"Xfpnp/wDFRynlSKe+NYghuvNlm2qKMOUJr40Q8/R3HhyBaj//CmUm3EpZA8v3//V2sUDPWjJ4cMOzKJcJ/7Wa/+PVuJ6pDqRvo13" ..
	"X0ucPKH+DdKK1hnqtkB1h1yFMdauDiLda5JVGCT0cNMauU4TaWVF5wfwysyAruVve/gymMEzuy8FY3B3pkxhfp9GsiKB4MCCPCuq" ..
	"vXXS6zXV4/XUuBtv1pKk2DcH8y8L/hkyd6f6dGx0kGz3YOTEQAcxowGmdUl7ImhNPhlA36qEI0HIpWKw6oGDFadhB+okMaA2QCPV" ..
	"RamZo1GghOVBAF87jD/G7nRkBhH3+63X1YFbzyrhpwaLUo/OrviNOWQwqeg/nteApo/lhw3u8eMFZ0a4rdMSrZtfqB2W+2GJqmgw" ..
	"VzGKMpikpmrdtyzreYuIrQZzgQVSsWnqrv7Vh/ZDnMS91sAC4GHjPMLBhCi/fCPdkL4suMevaQx+N5mfjuZUVFpTHKNM5S6gURC3" ..
	"F5TANDDUJSUzc6chJj05NvvuWgr222ROvtGnvH8ZFK6JosMePuac3gGfQ8HTeYb0AMZRQp+0kchS11E+2rT7Ua8LkSY4DPf3eoIZ" ..
	"bMYL4zN8EDWuTedLaIHGW6G1RnAVMICHZnVPKgkRXpB1QaZxXYuU5P3lliSLcgCdhyrs2CmVjbe5aFrytI5ofhe1D1Ojtql4s4nx" ..
	"LYsmGZZONy2Eb5BmKG8o0uCAeykn67PiwuQrPywBThqOfIRyrhCo7bTzML4XyIx/oXuWQ+B5IFMWoWOJ2sr9Vg8C9ZMjRTskAGQi" ..
	"B0btcCC1MY29UJC7sRHcXMkfZ+sDxJADwYFedy1HfenVB+NVaaIpRnP6XAQ2+U09Ml60bvgSX4vPEasi65J73lJj0YEO+EcgQ4Zh" ..
	"mkNj8AUYCyq+uACn5Pla9RLHPOL6E4o0b02QSl+eWMV/Yj5X25FBi8842SEJWMHZddvtngh6+UAn4RP0bSE9xu/y7YsJo7e8/G2v" ..
	"95GCDQRhKm+xGBvlISmU0wLW6flmVSfWPDpgrJwtc/8n3B2cQtCdvXuesq1yRkSm0C9hSb32TBrz/jAOB9qNjpz7e1AzSrLyGhY2" ..
	"1VddxEy/v7jKoItRqx0H6TN7KmpQpjomqGd9iWH1oGKAgnU/Q3zdJzCJbsApW+UhkWJ6974ik3wTaWoEubsuj1wjUnHM6H0af8BP" ..
	"3akY68CfWC6iNXKRymrXzkgqE4b/XTObFqFK2QXcgcDdLbksNdZrECPCHel3SbW3zKGXbuf7EQDntKrXmMydwGKuRwl7jpWHm/Mu" ..
	"4COjPEhe27XCL9nKWj1t+WbD+HrhKB8auMfd10B96Ex6istRau/psMA5nAb8CsvYndGBsbVVLaqHlOrGtdRJB94try8KQ5Lhozw4" ..
	"v1/FtdTfbVz30BAeSObjtI/cUac/V9FcL0CVhnVTCbNpUQx9fPKRpWAyMeK99kPgKYo8anidsBLGpOoq57q2bi1TcaGpc8ISekCS" ..
	"pdkelcrw0QVJGQ2J8xqWIDuT5D+wZU+jlOeblj+vTwpXwBO13mYlDN8AWW1kb0TUSNwdZqsFI9wSRD8pWW2v9fXPChM1Pvl6sYAO" ..
	"rngCwzfz2a/gVXcFF7kp0XASObWNmB/yeab0498yhtpR9MIa0R1bvFtPLgkGE1lVe5t+2ULrObnyPP7ewQwEPDNAw0yZXFyHVKTQ" ..
	"y+kQoCH/1MfT4PdtDXMmnO0GkDyhHAM4ZqBI6eTLbY+IqSNe11G8IMWyf4Yk5r/NSKkVw+YidVanboCU140r8Bb8V5mQ3Hjgsfx+" ..
	"5VaZH9URGNsG4wQpMhunJXi26IJwYaLrRnqNM0r/JE7iE90+ed9jgdKf5J4K4Hy0YOcKFRB+5q2orno5sgeZfA/VXR10r/ztBsqZ" ..
	"ahjhJ5eNNcW/hVvZU5kQwGv40T0hFpI/4AhG+oMGwwUMCc/V92jXG6igIlOzS9wI9M149vaTsT7fa94ygAYLGu2xfxKwTD5cGThh" ..
	"iIDvk/hefm8pQiJCtpBFpGCtXyJa7lM7q1bv8UZ45WcltrXaC1g77f2WrfdlqY3dZCW0TgM24yYSx1SZcKCLTm92cRmjUZX4GUX+" ..
	""
local PAYLOAD_P4 =
	"JGESQj4cTdwakUcc1i3nWJmwzQYa6GxTxOzci2IXaGXx1D343iF3V/IXs9+GMBSj8rvkUVdczA9mldOyzIFgCYiHrF4MtblDZFqA" ..
	"3kOUlF9kgN5iVPJRCBiad4y2GBiojAjVVxx1saGCMRAWnGC30csKtPBihW/VEow01p5/1aLj/+cW+yjPi9ZCqqg/QrPXyTM0TYAU" ..
	"xjwbabqPpzvOChE0PTNNO+1uTFViIELuYe7v3EAn+HEW1NY5fA8GqP6bzMZH64xYHh52tQ4cryHL1niFdfVmBmaDhfXk81m5wyra" ..
	"gDupRRLj5puxnXUMDCaqzFwTC6j7zO61KqJVZgn8DtnjV1+uvx3B7u5Yhh+bqAHFcFWf22lRN4BgUZvo/wSGuPkbKMA7YtxfYepy" ..
	"xUnNFn1d7scu5wchKb1yXQsm6IAogMumWAoCE1v9FcQHa0zWCZgprdjhgrXPzE26eBBrskax7ngA3G6rM+zNJ8FTZJQuu4hv/RhS" ..
	"AuPegzNamTBe2OPVvY5RWnj93Qb4WZV9uPsMAkn5XF15e74OEbGIanZfTaLckbyHLHMNAemyuOf9RfINUljXPOBIIoIt5jcjmn6j" ..
	"MNZJEjpjs9lYHNMzecfC2BHSFtnF1yIScjiT2g/Jdg0Eg9Ui5IPriYO+vUgYxT7KyVnZevsYFp3ePnkAkNhBn7dtBeObCLLBH3vk" ..
	"QFQ/ZwSEz03FhEkF8S+rWpZP+QJf5ZzPd/Jkhx7irU5Cl/tL2vZLlKwd4kRSdHw76LYiMsSzFou4ds7wsvjSlS9nomRdeJUVSap3" ..
	"Mqw5k8orFRz+1LWheJiI5sYHUSezSX3vNKYx4F96JSmmNlWnYduMJK8G7CuezNUgWZe8jJG8huJofcNgHt0t/4hpgcvjpYUS9zKB" ..
	"feH+1Ymn6eC4ycguKhgF070Kf6XCbtZ7Sy124iJjO3Qxa4IQYcbGLlTf6ke0DdMmfv61jOcc67XnMRrGXFOE+WTpaweJ106wKuoI" ..
	"TgZgj3I/uemxV54f0onefue1ggZqSGW9tN4PDti1oHBdOOza0uJ7LMwqg7XoQm2TMJzoJx7vR9pZKrPWmL2SQ+NqTVK9+QM5eqH5" ..
	"86grNdtWcf3shl0pWUA9/XlmI+F0KdODUCt1q/G3a1fo3lp98uut/31rC/lSsJzXXOk6h/JtN8lazOdMWT8Xmz/ScNWdlB4GlCXX" ..
	"Yabm9jIq8rjTDWrOl+VYwS/kzkRoTeXJN/DmPTlIGOEbGXBxqjUftDqDcKAWuKLCg2stNEs6zyweqMPwqXy3MaoiXu5L3ZkLpraz" ..
	"c6vCIu17AWUH3TKnPubbLv3NIUO9zFnKkSYNxk1gz96n2kkFGvDCC72y1lBJ7B1WMVc8scLQnXYLxj/VnKmiWjBz1n8w/uZpDvDT" ..
	"50GqDxrF1YsSBQhTDzDYyKI6YZCpU5Yj7hsmSPcFxBxoEdr84XUe/bZEuPyCmqI+W8cvf/106EWXIVeQqZhYtcJyLzWPk15RuEgq" ..
	"5s0zYG8N0JRXU8aMbcMFQ61Z4yv4MMvROeF6WQLzT2NF9JV7LMor6luBfGavM8W4DdNA0gZkCKYk4VfAqbC/RJdXVAazuOkdrIJB" ..
	"TMacuN1mCYWYyRX3I4mwvZ/Ea8+VWoAMJK0aTdiHNeBtkXD/5T6MEJRddN6Nd4z93ccoz/QQLNwMOyljIOUKnWaSoPecv/PZjNd6" ..
	"yEQpTWbcXCxK8gzaveqsSg0DhtSNqb3xfZSzxI7iqTzl0jj/wq/+tiUASTfzCGmlxZCVQ/O9vyvq0O0PmiwThc9qp1YDBDgQ4bqC" ..
	"2zf2/pPmlb9Bk3rBttQ7S0nIDb1AknoauEAxG88t+MxdwtM9tX8GmWAqmryAmwpb6w02ERXCKc0g/MJjBeIUkvm2jrNgXb0fTOLr" ..
	"EMH9h0Z1/3NkMt2h9DOE0XmELbpfHWrVmn74LXGVzzfLPOiLOQRyLL8EoQi9XyD7i2S/nppaED4vWj99JW0B/exTl0jmCdOAoGMo" ..
	"+hAnAWVk2/xcgn6WJrTO6bjtcFWzjyV2qqplEd2M4qdf3vT/E+t+rPhKsxS6UAU1LNyJ8O0fR/Ur8uyJs84ZkGcFeXSVThuEfwXV" ..
	"nUUj+R/79H7tQ2ouC/FlqoBy1Lzaq1gBeBrhiuHK4APZaOcHJzAOS+XNFEeF97kTj6bfQASHzZol97lQDh54ATEFnNRUnZUJkHx5" ..
	"lV+CN6M5xQb9XSZKs6SmdVwogRDLCRdibvwC0/38D7CfQM61KeDsK3RN1mcMTQsnmSl6538iNbE7H3242SIGIbPqSjirgtXCnImk" ..
	"fs/jKqotuawJjMeGfdeiLmcu5oNGEAS8YmqOqB/Od5zDp07Ld+9DHOFLvNvjEvQAUixKBfJw/zYhBp7fBMPS/Jc0e29oHBG/NVnj" ..
	"AT4qU6CSv9Wdz/XevX+x8Th6iWcXVcgOrLHJVyVvqmAkcjJ77nRMhhAoVCWGzEcv9gMwPmV++1EW6KUkv1DqjlF5fuZn1sD6J8IA" ..
	"VNzD+8IjbIc5Y91RKWAgaBFogLyuXIFyjv6oK7P+9ZqapzPNi3APGH6wUY+k61vn3Aj0vbt+pu4gQCYtBI2vvwEAp4x+djhgfRnL" ..
	"tjpEXS9yswHT1nowjqqTaOTqgv15zEq2DSb1FhodbvmA3GgnzyqMPckrlGrby5RrFYGr24rkDlu1a2tIS9RMPHdmngvXG+TwaJlQ" ..
	"jmHrBtZRE5z9D4tEIRYsTVhD6lWFBp0og9gq8PKgXbTV9mcCAWVBFyGm4RUFPzVXAVjN/uXy+XVrpCJCDFNFbFGMK8lDSOLJH07c" ..
	"B9+59LEheqC0WbyCkFpg+E8WICJUTxhFOeuaN+FvS3nmefgCp+hqXm/f/HseTNzSiQB2rF1I6KmFgvSU9wVpPfa6OmNF747h38j8" ..
	"WjV8WbfmKSLTW8MNL42FprxeB1dlrFAxJAmgSL99ABXGnvnwl2WUzRuf4sp7vJU9d/7GfkxybJ8ekbujzvCe+KHLkcW9nFz4DnAx" ..
	"uOilNgqCW41nd83OB0U/qk2P2x9eGN5I/xwxqyxSQKfWbjmxp5RVuxZ6NyiIhV+yxyQ7nsAC0fkKHZARQyvtJQpzgwFmuLfrx3Ye" ..
	"EB/XUYwE98DkjLteGxElE8nlhFvmFlVrnGyI0XZXYfHpkxy0wClHSXOtm8lSI6ZZeoqzRwebMbzdYF9tDLbSA3xZN7xIHJMkeH9d" ..
	"T2H2E88eB1jE5WtTyXbOqiQhWXDAfdeFtnmyfY2rv9Q4juxsck8HX853ohF1EbO7AUxratbuxQo2VSK8YjICA3IJK+qiRLkxsOvE" ..
	"1GIaOpJ/+gOgvkla71rC5eMApx48KzFZ7fYI76WGJbl65RY7TuUf1DutnilkCtIh9iZMyAp6Xje/kEYx5a2JzOPbaVEBvSmRZJfd" ..
	"c5t3Eepjkp0kTmJnMcrBVIaYhWAUq7O3gCKm7+qn8iyQCtozlJMs52pPEBvf6VvuEr2Pk/GehLrKU4fHX87FX4PEtyhdzHDhRDfI" ..
	"YoppdnG6RZ6vE7RacBw92JBMDEQYdZYLpyHoReZH4TmKJLxqqCG0DmSOrCfipKNbk8BkLi7t0KHoolvAvMxGOghBd9cy3eRPYGDC" ..
	"TRN+5Aaj9fccyWZl/tIamuk3mqoBcbNgUSpGbUCnnZF8HcfNufcbvYRbudxJKiNbNwYqzic18icK5fFtRAYTrsn/dJSs2kMW0QXp" ..
	"2R11EFNuUgkCBmBNltV8INEcmuazWlCBLzMxfjiKHI+pOqntScW6LS29QKhsv4Vza2ieMGg0/Y4rGaH1vzkgGNG9O7uNQO/Z2TSv" ..
	"22njPCigecrVaoMG0NuyZHpX/ELtMRvI3JWu9zs1LYJbf0eYOJLKRQCd8Degj6tEOVdG1EaEXHgzIg0fE1u/9bLZampLwp9BngRq" ..
	"oVRYf3V8XWOC+Xov5nGXnr1pVRLgDvbsLJWHTP68s2abNbf2oHcRxHmzpfHc1AXqhV1p8YdCvYfYpELr5W5eeMaiv8wM94pCs2vn" ..
	"2wcQ1QKwAoYlNulHnZ5qupr/QBWyhp5WtYQfek5aZzau+InoZ6EOsrBdcRt4uNDY+LdZGlk/HIsVVXzsteu+XBQN9bsS4ZT92Ezm" ..
	"GOm+X9+fQ8h/vZaprC9M7FeioaoNnFL7vFXO090ioeUL2QykiHTPUp6M5kNmeNX4t+WTFunUDMlOAWNcJclGtRKkf6PD14Yf0bMf" ..
	"OfZX4BUQjDSjw2/mhiRKssGPQS6hI1J8txjXVnh7jjK8GJQJ3zMmiaXdtmN2lZc/Hft0HVdPwVY6CiO47TumJ1HTEqxTRs+aLG0w" ..
	"vbkrO4VCoYJXsp5Buwy5RDNbzCjSKWbBpH93zPgXd5Nj5icO7QJ8GhIW/t7hOWqt84f60PX17RmtR973IFuRIWTH0Oa9WYNUTxcG" ..
	"uLscQTCQO5yy0wTLywTIcKbldH5db0zONWJTE/yQIKcw/bUCtHByui4nGfZISrMZ/NbI+PVRnJaDyhgqfxRX56TFB0bPYn7Fw/2y" ..
	"cw+lcgBK+SIySpjo4GByLaS0/2JbCq2G6SMuiALG5kGwazRGhGOdBdAwL71yXbHlL8AsjLWte2FTzbRRCRPn5k0LQKYYLRrt1ONK" ..
	"1F+Pb2lmdRVyD3yXHhGyXHA8Q/saSsdj4d3x1yCQcYg5o9QAansmwuk2l6UWkcXf0PklV6TiEG7m7Mg9zzreXDPrwGoiR/kyBTmw" ..
	"pD58VOenIsga85UxcGwDLLOgWSQGZkm48DfvVQMbSjdkxeqEfTgkphN2lD2U0U2NnOpBsJ4C41y/zSTJjmQ/+0QyaXrwsQt1q9kM" ..
	"Q9Ssq0zOOEgS0OogJTg6dckZOLZE6TnAjmm2R6hvRjp9/UJ0qb0Yej6+XEnB5wDm1i3XXuEwnq15S7T9Kyd5NGt8vNV+zd5NEwwb" ..
	"/amLB3Thpw2W0uw5RmwmCuKpOakBaYoFIoOyD6qmvg6sOf2++xJCO1MOhqLBCliMPRWJyt2ltuIPbLkKCbkO36Xr9c3Mqm/EW4KT" ..
	"yGsMZz8J+gkW3bff/RrHwoDp4tPxeRZkwzAJxMDehQXtHzxl2iLUpyaOTfHRIo2l3JZI1xp0HZJZ+FnNFzoXE1avOz1UjWkCx3kt" ..
	"iIWHuimYEVe9b3AYScE/nJy4lPHvGt7JgobCfvOynFHU9okUCGqyOBD31dfrM0Srno2PeDY5Ldtw1TNTnG4/5V+ay8VF16ixDt7p" ..
	"oCc3ZkNCZNicItb6DxIfn4s4DlCp8NuTtB/UkiCncm2XbKvoWslWkK66fRAkg+1pftmEBogEnkm6z617kcMJt3yR+ZQftt3oMzO7" ..
	"tuqyPDS7QTO/HdsPPUUDKR4VQgrxh58ax1d4JkFrSnuNRwtGgV4NkMThuxue95B7dEuBssuTt4VpJd8HKJ1DFTmXEW6GYMpeU3kK" ..
	"1HbheVak2ceZCOCXFyQX7u/UJTaq02MFYV4HG5yAE/07bJz8P8tjAiDBkwSd11aqpbIRxCtLr6sO17UhUE9jWlSAXE55AYP65mc7" ..
	"6LcuTk5/XpQkAKodj/uWPny0K4cA7CUFt/FMXOox/23p5dlCIHQmFjDgQf71urEVPOv01gmT0FSgB0XbZZ53muSRLqE5/VjfzP2i" ..
	"o2PyQ1v/mXbROIR/qqgSTmhdn5aeu0qbS0zAw9oU7bo+riLGdp/NwrUQX4gNzXESh0bnheLxSfl7qIwLuOA+KfGv0Ylzpg+SG4HR" ..
	"kkJZQgQFBy6jLu834MaT+OD8sAZMK8zSkyHFBpV2sbKNqLZgTPS9PKarMDvjCfAomQBiTGVjFLtRkxvi4yWY/jUedsU4PeQfL5p3" ..
	"fDo5vBCmHN2ujIiz+dyu0li+5k1Hx1EQeONPpd3w7W5yzQ08lxeje++qcQPGxQM6UOb/fjrUYPZEcHscmdJYEsudImPumSWu+7N1" ..
	"AAdtpLbX8E1+xbE2A4bg2CIMytpxr3mXrElEZykmNZ6a6LBLUZu71D2BaSn1Wn0bXkLaa/RkNVRAJpWdErzWAfhgKC+ujurhiTqE" ..
	""
local PAYLOAD_P5 =
	"/aOjoFm62LrAvp5IWtTy85ydOYS7Pvn2CWFmVbPPGXS3tw5Festa08LEnmoMsFL9hrV6vcuv4VRWFmLAhlH7/3YsDEQnF6EfHYJm" ..
	"zmzfUxkc4uZWqD3faJVCBL+DQswRDlt6frhVZJb/eXeGDcUbgyLn/bXFdFltKjCfB6MwD97tk/4HoPXp/6Gd2ftbsKcqs2RQBWgp" ..
	"gYDMMA3IT3CD5Yufvo4DGq54VzHCycobzqyh0TWNfykWwfxPEcPMpaF5shiGG57NGThmEb5Yjr7diJfvk6mOlTcU6Nn9UHSoFH2D" ..
	"hlA2raYZK04PuFKVyH1OwyRelbF0yf118h0Oy1kTu+sJ3EmaXe1iTJw+fS6Qk7LEtcGBi15GlHSYQRel36Q1ZJjm+oyRmQ+3Cg4m" ..
	"ODEtikqsQIXS/Uyq1Zyv8/6wnu5dpvA9BLfRIGI5T1q9oJ7hLLzvikkx/81wQ/sTk4S0iEPU7vCNJqscus3iIuVeEZbACuqYl7+d" ..
	"nWTtbpuey+x90N4rXmqceUXwMVdKdMURKBv+qhYmSA2w1+KIk3TverSQKIhVga2Lt6BL31ws85CAp41j1JpRcpTzQnbiL0nV5s09" ..
	"511tKjWSwJCw5VeEWppvwQhVi18QS9jHGqotlO3t0C3KD3dF0ufaE5FZrjyBWAW995QuQBVGIXszcQ50KnlcKgm+y2FB3Km4Jp9T" ..
	"xVN3DeZhEnONcFS0UOzKi0eUX+GybdFPrVHGChpYk52nK1iskEaYjzQE3dSYW1gakDE/iRJa0QzyPuRF9aNhEJ6Mo1c+4u0Gy0RC" ..
	"37db2qNREfaMlHOtL54fAj3cAi30AfqOK2yWv5OBK7yCscaHsNJXLqy01wQbNM0g1sAobRw2SpK52Xjeqr2lHyr+3paiwVqwQ71X" ..
	"kB2M1cpzNe3sHh5ampI5aNGbBIWzjKt7uztfQJIfdB2BKCegaSsomF9nTXqAnU5M0ZlXpfPjk2py6mHWG2RAoqpkdxPHH7mQYNKb" ..
	"nN5sj73GyKL0N+X+fyzYL2FtKwM9okEPX6uq4MEntgxodJgZA8vOQjl50+FuXrWZexHc4CveZgtB/kxxxsknbVasMSvmwQH0H0/Z" ..
	"Uh72bPRAI6uP83nsjGNRX47t6U/aPkIgF6CAa4GuKmxyT1zAhk9rzTawTZ4IpiPdayE4e24xx6FeFRYvBis02hOcggVfiBLzfKKn" ..
	"Z1mIR/XxaMVLX98hF73nvQJFipLiSKnIOBxt/d662/2U5LpHuRJFwg21rzKSAN2zOJcGK70fshM7Atc8Ubg5emISaIKCRgXlyk8X" ..
	"bdTRX0SePP+bRnsXl74DlV5wndXcFwMrnh8GefgSfgEiQA4uBBV0Sk8gmQky4G8TY15nV5aofaPFd98UgXTzchqi8WeZBs+l4sx9" ..
	"HlvK9EIjgKaW3aehJ+zd6qfNaqDkf4Ps8GOC/+Ba6IWe//GtGxGyY1svElh2coqi4HISopYirMNv8JjH/Ytv/UNqTkJs8+gfS0ao" ..
	"I12pAnWEnb2exuzB+vsyeENVsLhdYb2VwDtNueUgqQNd1018yFGvdMSpWOyENDLcMrsNl2nzTFJYn95DGPGl5SCxjR2CA49L2qlQ" ..
	"wksYQVQPoHrp5SI0LHtoU4ffW2nvRBj97XbrjyY5tSK5H+HGHRpSTJZCAeQbT4rWfFMGEYhTRjS5N/vXUlgo/RJUYfOwtuGJIV7J" ..
	"XOFdGWdTS/RgcgC9LLII3F8mch6ASE6C4+8nC1hoksJMNpa/C4T7I3V0UZ8RfcS6SQZwXKfam1tN5Wc27almEsIKj034dJdbm/uU" ..
	"a9o2Yzxv7nqbRiUREtn8GUf2jwGuYUox8sAeJ2mTEZW1v5jKEf6QTD4UrAFTsH1MtD7iFQ0vheITf6w8LdlhqF26dUqgAKgnVRT0" ..
	"KpXjah3TW/nRbiNOA/qy9Zs+PXC2+fp5oBiqXWOsB51a418WdkvGtP0sHBz2ZvXXP5APB3QQWwa1qa4EgAtFOxb7bfcnMkTiJyv1" ..
	"dMgyBnKRpwhOyozxVogBtUB2dS6mjN2ioWJw+EKNEVTsKvt/EUG75w0TZWltvOlPbX7l0qZ5T1lvcaywnkha6nhulCCIUyToMkhR" ..
	"Ng48n3nCIBeuTOJmN8EOKzItX3N9gzNrbE+rRyH+8ZmYagJZ5VYo6rW8S5V8E46Qxz3N2etybvBq2JWGRAXw05wNWSvz1BPjCb5E" ..
	"mG7jzkp1LRn/jMU7zI5nCqRIRPsPAQbzlUWjzaKvw3rYwMzlwgvMVmsEN/3cUecdHsqPSeK+2DhtZA6gnFjdLOmISLY4PbMh9VnJ" ..
	"O8lvZMtKQRt0X9tql/6PqaXIWsK+Jy7r4dQb5H5ZttWmOvbW8kXnr47IPRHAp9jRqXif55ph5Vq0BEMN/o+bbTz2Pf9N/MEEyKZ1" ..
	"JPAuRlkbyC9ixPauPHUfAvX+1OsKiUq2ySzphxx19B5hAkM2edw4/DSYSBCA7IG9pwnR6xmGgmtWcwCWr5QkAl/mLtn9a22bwwG2" ..
	"MUxUiCeoPA4/Kd9Qyox9lmYpFor/P/I5CPwLaPJyG9yMza8n+sE/Xuc4j+9hSz33kcsvdgXcItKUbT+jZ3JM+iijqiLDAIlfZDWI" ..
	"3Cp7IzTFKNRzO5o/dthfoKcFH7vZsfFxifaQyvstzgrwRcBSt9qxNcZfRkekAi2s2To+MVoH2YZOd+O88kDLj77E89n1QWjdA0DK" ..
	"kNRs4qJByg6Ra36QjQKsvsOZf/89piEEqXavQhs3Vy3BkU3uPpw/f3KE1CHt7B4sforEiWxWzukH7yWqQkny4rKbGfK6/Wh8uo54" ..
	"kO8ao+9bzPNCZC/n0vpuGfGk6wtoaTHyRMo7gTRUJhoiaFHtn8eJrDnk7rukK29Mq1ucjf/BS7R9szFjRX9tzAbVQtqla05+Vd6B" ..
	"ZLO0qlILZAt+57RqXtsY6MHL6psPHXgBSPIIHBj+uU3aLHUl+iZQl9GXKLEfMUr5EppO5iy/tOdzIIOX0x8LoASro9fymZMW2Cce" ..
	"9YbhbhGV3jEbGHqyD48IR0C8SeETfdgHqFwG4fk+yVh0otCGOqHi5DwBmBvaA0iaXpnL6Ztuo3v6JN+pKUHc+185vrimNrH6ORhc" ..
	"x1gPLCxU3dqcFFLgDfNc5HaxjVtvSCaP1LyWqvOOuz2tkDRI7//ryQezGBCKR+ze87moglhAt4z5OzlyVAenIASw/4IOG6tLVBZ9" ..
	"dEPEy0Q/2YVLpNK1VZGA3+Nvz27IDdCZ+XQV8vHtxuQ2uz3mUTVpyj+pNiYnl24DB58OwbTW+PIOwbgf+uL+l7pGH/98OPvmjlEg" ..
	"pk/jhoKkpWgy8yg/Foa4FDXEdhHRPg//X9/+sR7Uk6g08zHscEMIa798/ehawZcGwePmsuKyQsqg1CkCMPcs4hvFBv4jtIm6Y0Ww" ..
	"ulahhZ9sOA7j7/0+5YxaSrf0di+QSeQ1+fFsByaISqAVVpRqTGixiM+qhY1mq1N4pVh/Bmvi4WGwi4BhDsOiBtI3+lLtuw3BzkKZ" ..
	"LGg+TEtHMOpPEhNWyw+egDPMAwjMZYj2RJkfq0K9JHZDRlLpu8cFOOc0uFDaFaMNqWT324m4+EEe4CQH3wc5BjS9NVDWhDmjA+ZB" ..
	"EObuBdowmkcKGT1k+NpLQnH5h1S56pUTwingVlIrbSXOl6SgRFIQsfWCuRgQxo9WYY99E7sU6yJ+UeWxs+vzxtqSmqqeHcZIOhYl" ..
	"YpK2oNGDEBj5Td5UcMHB0UZQ77ilL+IkNiKnlAoo8cWj+dJVGx5vd/vkvcnIkBTT+EV+FbLnK0m29lYiKzG2qM4oU92xfVGeRFUy" ..
	"OLcRGtZxIp+m7sTnSiYkSp7TD+0HQuQ1JNGPzNL8onT1Aw+8toin6kNBf0XMLHvbl/ekuQh3s/AppeuXmVrQinMz8B5RFbyj26Td" ..
	"cDDrcdRqRiXST57XgUyrzu6KOv8+93FiBP6m007zknaw1JuDroslw7nf9bkDNhDSBMHXI1KArcAIJdFzaDwnIRH+85BxwTII6ebC" ..
	"pHzOGI7oMnhZVbFaNeH76g6bVZMM5pjoWOn5zrYSQm0Otgo3OOpV/TS43SAGcVK8b1ZmFHmlBRgnxoG7L8gmp4O0p2GdxJyVftrQ" ..
	"mLy3kZ1JverHoumwJxL4B9t4bHEWJWIQI0vLzzutXjlYiXnRoDKrcPYhyYN+mYSy6MZUJNcv5nNjzecFvyfoO9xvTgOON6Mg/ymJ" ..
	"D/2SUGymz5WfFb6GnIrzn7uO2UkkZUfZ/gdfO6P3ukCQRnPB+YeGjTfOWT6wWE3i4bw28TAuo+FgVJi+uK8Yazf11hge8WdL39iM" ..
	"ZOplgH+MscF4BCtj0kSv69eFLxIoQymswXA5MzhzItAcB8TqOZWQYHcFmDAXGzVWgGaXKrMsPBfd6mL45D0Htud/vRgJcKr/8wb/" ..
	"mFLooYFxV3tikat+i12jeOvqQbfJMosGz47hgAFhlRYmwwilN5wiVxS27vfFxj4sw2Hxbantvcp70jSJjvHKnDiFMTSwE0XkQPw7" ..
	"+xe8XLuVxsjfR339cBz1YZRKJodV3JXFSwkGgC84lq6o0hSHsBIgiueDkU9Bk2RUx90o81ecodUgkp7ZCo/POpHDvHYWxvgNNyyY" ..
	"KIcyyiifmLx13Z2U2p3dCihQ1b1v7c/VEyBQhIEvA7qK8K6X4IXLTPeiPe/FMgzfbsydtlmPrXYe+eSHl9JUBOhTjtSk8sFmDfLu" ..
	"gO5J7IspM7mF2o3UNewObb+TQqWWwONdPYiUhYtuhsMGPE9u5Q/Otc77Bnfot6bTKfs33X4hjh1K9bD6n6QqFAFTWUzO8zPq6WHA" ..
	"uHSE+YcWLTfDoetv0jm7ZiHBCL54+EZo5KbP+pGWSu0P/Nc0dcF1YGEyOh7LPi7Dp9onaBoCpd2sZdbIbIUGYlMXio6RwTCfO1IT" ..
	"jSLcTDRR2DhmR3/PNg52c537eguH0F5lqO7BjbZ4FdqdpUEGjq/C4JBeFGxVy+iOa6InZAdSTVvSEEcFOB38eY/pRw7ymu2r5u8A" ..
	"55U47jtu1dw7k0N49T/0GsFPHm8MuVraCxJnE685OBGpccvoG2FRUJPJZzHWiHJA/GxJrg9putWSZ0Q9BaJSJ8CvA0+2EfV3UF9i" ..
	"W1DSD4cYc8JkJGgCM0vCi3d1FAcLTZhe3zNGP6BAg+QY0hFlkug8faQ7csGRlE/CLekM+Uyl8log7ce/BCmIdn/xbGswEQV5V1UF" ..
	"6j9D5SEXFxGBh8IHjt6K7OZIYGGLZRSGMckG2KCCTeamC3qkQxAI2cYN7SHAyzRMYCA3Td6J3AFC3bwK/ITFLsqEHIS7EJ+GbGHJ" ..
	"wbx8ReZA+xhFYOcOJqGWAOOcmQ3Gu7OHuYeblnqDgL3f1yv/haU7CwKJQXXCgi5C8SVoXjN4yTwzMx/3kkvYbC+2ZhW/MxiqtBh1" ..
	"RQ9kPtSCtjXRCKLcmLo3IPBJrLhFJrirvUJ1gj8dNyOQuhTzOBmH3R9A3XGlFB9lCWRjOpKZ58UT0ZJq+IACk0s/HjzOgNRMHFyy" ..
	"I7D8gZr0SIO8in44AwI/upm9noRsRjPS2pTZSdHbq9WhZRwpAWLqd4LyCg4b/MuUSHon6/YZZU+lu+oWeBsSSfzfiPlOVRYudQiH" ..
	"cYK3KVhVElYMCnDL17HA6G/SbAPjxvajjznp8T2jW/HZlNO90rdiIf12CsVOvMepltLFj7jQKhFDFF7bfxjha1ycHZe7wlBXI9KT" ..
	"p/fFNomXPyR9Dh8nA2RHwsp/aBS9OYF3Cq+s7ZmdihSLV2+AuEuUtClGMizsjZIPzdx2Es/tkq9U91YyYRA3tH7MAZgLvz5qiqPL" ..
	"YX5jD7/mla1Fkcg2q70PIKqE5lqgV/BULO4pAbhiPKu0SnUtGyx2NHyygAhIuhS2XLAAAncs04jbWTN96zrxpiLt9YGMwJ8hLT2N" ..
	"PLDfcPdYKzsfRMwC+tTgNThpUprCvyO8n7sxyFMiOPoL0KO+HQj2wm+GK4fjGN+29MVyczJuUcPg7F2gDDOKaepOoDvA1eHxoGv6" ..
	""
local PAYLOAD_P6 =
	"lzsnITZ+mrTu/ctFpwlfsuXTYzRr8hMsmBwQCo456kUNkCSk4Pfq6ZiCq5km1a3BbJK23By3OwLLMouQVJ5Buw+w802INSYMefYs" ..
	"hM4zoOUglrQwXQFAcq2CKbXZwtw4mbSA1C965jpSFgfUqAKxUcXEid1UKHDJc4nBygKTMrVoNBbUcUBcd/+kKgZllI4+Jvjd9uNX" ..
	"tjZitDlRhIQ9aR8fzGbZuGkgzGsf6gnHhdWCS+XSxCEkG3BCjqtpYWR+5tw2K0QaSHhmUasX2KkB1lh8QWsSKZP7X+6PLJltu7oV" ..
	"EUCO/iP7y5+DsJxHkmQDLjhdeWtd7UG7kxADNK9qomq0oHBnaNeiKOnBTdfOXB+R9CD4jF6p02iTuxKYjz9Ln4rjTFVbb93cu2LX" ..
	"mc6BEsLt58C8nja0bWc9Le+B3i4vlfzy0K4FqSUixk8VTH2WpX4ds3wXzEs95xXcH3QzuTeBcmTqAbO14wFQG8j8QNU/66XrhvPc" ..
	"jcMlCSjo4z3N3AqcanqE8hVFbd0LGKLmaSiHoNyircZiC+jG85eGMhYiFQ3huqkLjzuXXX+3mK5Dk5UNIIEYPhpnjRe4UFBBISCM" ..
	"uruiVmDdJgaYxsF4+mRMJe7Lfr1+ndTUIxEH8IvkRXGQNwV3iX9ttZ6DNUrH/y4yrkd5iFdYHFN4So9w9eVOZ9mEkFjCPg3TEdiN" ..
	"le4hzP99Z1FWOwLW0uoBhvVIWkeEjQfUWwibTPfZko7ntv+bdxc13lkgqDtjgJRTZQ9EemieBx2IVq1r24DQ4eR5Ve0ZhptXDbBi" ..
	"HS6XABNYStzWWblpj/UbwTHjBW6ELruBMHz0zqfEEze8q2Ooei19Txd4DnR0B97/pvlzdjYrQIHar6m033fhoDy+lEeegyMN0ZWg" ..
	"CKlEbRA/xZPKhkakChwcdgyr/kHP9ndOY+4sUV+oJttPr7rdxuQuwjeLrXv7nxMOrTY2LKxgL4BBvn+TqmbH8FXnEIyVS/5tJajy" ..
	"veZKYDSR6MrkN9QgM/7LBZ67g+WxPBC985VJYBe+5Sr8qjjr2eTwlQrJ80yt1LShgK3pxPmOwi2tN4yjnIlqCyp8LoJEtH+klkH8" ..
	"mlvomdAgYA2pmxLFu6l7vYDh4RU1dBRF62yxb6Jy2Bnz+r4QB7EUvzqCenocLmRgxcwxyYSPVNO+HKL47Ufj8AMQn2wsSGW31IC4" ..
	"G5IUpBQ0kZP4ceBk8hexnDoIgodDbsd6GxWVp//FQrIEemMYAt9lA6vWRWOrDS5Uk9vrUpk0BO7X0Z4B0jylpuxOdubRrRyCHthk" ..
	"shOZ33MDqP9YAzwXg9UtDPKK2vA2yku3TGb8JBO4GecrJeMAlg7pbl+1qutI3k5WWJvakMk9NaPjqVnPJQtxRRm47w2s5mv6R0VC" ..
	"EF8yyqBqmOkl1ImVPL2j3sutg/g9FM7L/s0b9F2gpprM/PQ/dOMsslaxNyJ11XTghEUDu8gegfwz3GOWBEsZjYxP2xQ63hAUWlqJ" ..
	"K1/jD6dFGhNe4J1W4npWjNRjpp7F4f3qkXDe5eQUXZwmM5+dms5eBE9qmRsVFCECrp4Zcu+pT5MPBIVZGX5MRMKWznycCaRZVc+G" ..
	"+s5KdHa5B05W8O9U9Vdq6hlAakiCZ6Tuo6TA54MrJqAlKWu0Q1SvYYOy2Q4zUfdNIMA+gNufO8AdrfxODEYkULchOVeyUTemYcPy" ..
	"t65tL4VAredhI8HXNqzGdvNGiElGSSoz+dtcf3rnDqJ9pGUie2zo67+wWSoY00Krcz/G6tIJMBVes1ROBh+FY2Rt4M0In3mCI3no" ..
	"q3lS10LLhXj0p2VP+GReh72i1tYwcY38Dt6DKprzCISZu3yssmAlkz2qXdTANbxA9oVeEK0O2naVZdZR46vHg5DmsuSfV0FhPHQW" ..
	"l6m0jDMJ3u4JwvKFejtluI5WoA1PSLRGk+/UuNUbImTnpVeNmcx9F9WWRrCUqkh5zqZjY+ym4TQ33yv5cLuJVuDu8b+u7uNlNzO1" ..
	"+tCJdSzZyMQhTLm2ie9ix5DBM5PK/Qb5JSN6rlgQnsupWSuC9Jqjw7FTVBcgAtQwOj63fFAevNDdSVrIMkdWpR6387KStisL4HL1" ..
	"1RWjNc/jY++TToiFg65Ht7XhvkzBYhcadbL3S3O1cEjWGjhMp9r0x/VBdu2qAMgSTzcoCdxO5sVVKGTz3vCYXHWLoBL5QvEGg/le" ..
	"lt4yzv+yeS1AaRc/8gf4W39D9IWjd4+og9dLy2jyzeuluwKtsURHbXt4zGAG+XvS2Lb2bNeAHX2IBlXflG/iDWaEUjcwLJtp2Xlo" ..
	"QpxtIP6jCJ9cwetepEE3sJy/DIDRuVDsmGMOIB0Bz2t3vkwHmWg1xgZLCrUtEr3i34zqz6FvhS/Qf40ja7/kXtPaUjG26qbu6Zso" ..
	"WPCZuFDAnHaTuCJ5IByPB6twivl6xVBckVUKFATqaIdkOELlb1egHAB3DZa35xgA/jKCgEChJXlbqqvA4a3D2dF5YH1JcIbfd0nj" ..
	"saIaTjbmxikD0/zdhGbVH9IAixFmINmLhFjUZRoO9ju/hJ93H6zxzHl+JNxsodW1ezhTwvZtQp4K1YK4lAA9P0rIxvFkdMtOIKFT" ..
	"1ZOU7Q+DAyBMSgYbFhBm1xw6IRx2AhLvzYPl0PdaLKMOGB2Lp71buIpy7Waq1i8uvnZzF4UBk7f/ivds/K6wP8aYz2n4705TqSKb" ..
	"gm+NpftXEPKZJ2Cnx1KYjH8M2hkQ+l8zyGc6L1PrgiCoZACge4MrzouQ3RRcbH6jk70ZhWibuELrvd0iqaNm5kHkRWdjBNcTu0s9" ..
	"Xs6zJ4XtPMxBO7lrR/HCpModC72QSZqQc4ORKKh/Hwc2CXGZ7VyLoiB9+XvPTfbU5PRjEpqegl1du8JKAJk6KB2XyR/ZnvwuYupp" ..
	"w6Di/mDtAy4e1BTSGHBhXaYARl71SFP0eOPxHRSkT4W+3ss3NWwS2FR5dOvsUJNUprfbYK6xzsVsjrIu7NHvAWzub8/9gkXmV0Xy" ..
	"Yf9MqktPJiVtZmBqxpjOQ9pcfjcGwtmPKr7foEY59QJ4OgTZq+Ma/F4aLOHwIK8tuM3BbGQvmEs0p7rKjqvLv+I1C5IjF2XVVHSA" ..
	"zmwkH2lk/rXQGdl6YXqgVQlX0pVVzpcYHtiVMvnu/9ETLg3iZPMHBJ6O6St7yNUocgOh22Ei4OlJUlhjxlgzqDwedqJ2kLyWnw4+" ..
	"+tmcysXPUyRuEKtS3Utritt4bjWphlGR3bD3+k2a02z6blFXiByvAQwRc+Y+AT3wfANQpXOySPCSfJllefHcW0wgB/Q+dPcTn9tD" ..
	"q+TE9eEox+dff2yyHgHVy0u3SV6U9uxx9ijrm+wVKvlxm6KmwMzJ2laEZyaVKJejuEA6pmTTtF1vuD9AFmwnpyTRw8Dn6ZHooHx1" ..
	"X3nj23Keckf4bCIDnk75UbDDFYfqyXn1XozcE2F7V5KKMBN+NbEsM1Jqdwysz59wKS4y1fvXSxkvgZag8QjzDMi/rJURTCJWgyvq" ..
	"RI8F3m+IRUACuleNHh93Dz/cFqJC/ZSXEUTLb/t6ew4zeVhvIWPRDp90ODt2rxz/p220De+MrMxiQnziS20YmeFHWKff8yybV0zR" ..
	"6r+S89goI+KyYQ7GKbaE8rRNDttf90Cz91k/HLu3PBKtR74wf+d+NtSJ6jnA6V1PtDH90bkFnyWi2oCuO1nIqJ03fSrL6Q+qtwA0" ..
	"bIbo/gKDwesQ9dQxTYWiDk3+qjmYBvukEGCf+KxGMHAdBKKD7kWMNaAomAC4s2rjUfeqi35J+oNSg3cLIUWy4YuzWV5FK6iElkLy" ..
	"4WniOB6LmoZovIJnD5CPNGPYhVuoKfM+tEsim6uxOdPlwgIvzvY5Gm0aGhlCge+7prOYVb405aWI1U+qkiJEG0ZA6Ru+9AqL707a" ..
	"R02FkEtfhjGq29yPT0bPkoneBvOOwwDlUtfj1AlVaoIoHOMLkf92vsPuLEFfPZ8cIaJm+dloNzJ/Sm4iI1wrkOflwcx4Kfjjndcj" ..
	"Rs23pnk3SeU9ibEqpyHUheSD2WZC0pyN29aWGpxTzQIoRTf2sizHT8wdDZnUmGBuCSatygZcqZMGulK19Nh9RMrhqb+nwrD9kazg" ..
	"mVVbwg6/nK47Eie56GnCKZIVY598dU2kUWIhMJC3+95M2V7Pdozx6jcDF46Y9p5YSsqwDdMkmHL2cZshdS1ki5/yI7JiwaHqGrlF" ..
	"IWzfT0jw/QMpwh6ENiOa5k4z54i77oJ25IqTNUR6HCa71WI3ZpUi4FMSGVg6jNKBfPyKfN9imlxkRNkY4QiPSVgL9yipw8+Xm8Za" ..
	"s/zwYXnKc+KiRU5RfoZ1IPYo311NIFCGm32jRIaXroFMaHd7UZ1Z97PCLY4zWmc+7JWL6b8fzRlz3LURgLMYSqx7t+Na+9Eg3oyC" ..
	"Fz38W0ZSupTR1K8uoU6DPpNAhwu0H+iVwYfTUzpflDKtQHOac5/uN3wOl8XCt6pdHgYmpJlrC5XzZaNuh90R+JeKDvXqWhBG1Llh" ..
	"vS4Cl2YRW6CMJAIwFXUK8Xyd1ta0A1g8iuhXqUXLRO+V4fBkoFy1I6ZlKCPtpvE6DPfZ1YaDCmDyqqBHaAdNfyyLamiYVub/qIfM" ..
	"ZYL9gE7YUD/2IbLjwEXuRwMaOSaP4bIQjRrkv0PwB9aYxGUdO9dsvBBzxWQx3P0R1FscZlBejHeaKDewfhsvliOLjubKpzWzPuq5" ..
	"H8jAwDyQ8dpGaeF49Ijx2/6MX9HLLkZg6uOULFrVxuCfgok9U3LOZyop/yRc3mNpe62tnxLFbAAttc/XIO3+yq8N+FAUr5VsdV9N" ..
	"Xu59Z9bYbh5DslZLjyQgjRaWWwn7Z+hbyBgXdXmVLEVpIcwt3DepzBGWgtOh42TVEWYoR90bHzrjZAax64moygtXyu9AvwkTqcGw" ..
	"+R4NFLEiUmRIkTD+VO/9VTcjKjKNNlo4s2cdkmGhO641xwAuyfnF5etHCzsoQwR4rJqR6vJho4tUqufbKu5LCoZ4bDM7b3N46L1H" ..
	"wx0744JE3kgx2ygRSNdmGcbhS+tTGCZ8AsB/dNrUZoV3/+2w0oeFMD7dgu881LhfDigiUVGEYK8eYiUeYjReurT/uAUy/wo5WZp+" ..
	"fUs4+P7nfJb3V2WCdDhzgva8yY3pfZ6TOSJZdCftIYJjs6kD3m5SzrQFWmZGWqCxSMQ7wKyIb2HURjyJZWPHy8fnKxsVUr1eFiPA" ..
	"oEFRjzzEN0cnrYKzdil1kbcq3Ih43Kjg4OnEJqGnPxtghQwADnYL34fDQTMS6ptzLQUb83nXtwvEju8VgELaaGHYT2sDGFsjG7bF" ..
	"NCpz52pMhHg/XVRfU1INSC1ORJXmIAXV4z3IQ6IQ7rslBjMLlUj0Ft1zUw5mztQPg9nh/U41NTqyJOVBiMkgLrxeNFnupyCNk0h0" ..
	"b5Noi68xYzeOC/LNG72t1fItXbQ6lbMpBqUT1YKK3THBNcnnimKd7B3Oqx1zZk6PI07wifd1JQfATPtmrowJ/RnTEZ53jilAvYo+" ..
	"LIM28ImdnnYPCNS1KHNkKC333VYnUNjn/Cu+rnlhGUq2WL0zGe7KfwkimtcOpw9RyTtNcg3gAeknI90+x5kOat0yZyGesTN7aRhh" ..
	"ogj0wO1pjVEofFhYasg8MNj25vh0tY/jC2a3HoDJgZhR3OUxRM3BjPXkgHFGr+E7YA3YR4s293ZMOL0Bzw8SQ82MIcYz/uXiw/je" ..
	"2zqZr+53eIml/sFqH2Ve5n8+P2JEDxgxx7Q7FcbmQEF+IfwKGcnC8pc97UssnAz3Jky1kxkaQClNU5k3N1fGuilolXteX6tlSufy" ..
	"oxJ3p2ung0Wkjr8ceaZeCDwQAaTh+7q1nQ60OukmzRlJgDHSyJcvDdhTmh4sSIJXGMbMZp51CnYOyCdA3H56awIWslUpT0ERvBDl" ..
	"J6NtK+h6E/R9o3Chvhu7vOZz15mIqsfpyeXMoCve/BWTusBcIa2iIMn66PqCosELmSMhejyuKyjKRHR00tBXQVfaD9w3NLDPC+GF" ..
	""
local PAYLOAD_P7 =
	"1lDlU4w7FypJr/1tohjqHz9uUjazIDk0r+8sv0hnpv2XJfUTG3ERyVGI4ZcWJXo+drYzjkF9RlLRpKwgZGfqC1dbtVfdv5DP+hv1" ..
	"bpfDFMylwHvBFKM8JsFQ2/WkL8G2M4lP59YhyiqoQT+XNFlgJlZCzIPwlquzcNi94VaK7Bj6U5bBAeEFlyW9CG4P86yOJwYdNUBo" ..
	"Mg4mKJtYxXzuKap03sr/rSWtPksxK4CprVHIfveDiVB8+VxauhqOoWvY1baP8XB3tq3uOE+/tcTYrlZkvp7e7n6bObF2N4sAQcI+" ..
	"9dCR5Nmyg4oEQWVSN4l5c4KW2KNs6WAxtnnnAh7i/vsjHIa6VV04w0PxeYSRkW3/bthSIZfSSZTekhbtWY2w+rQzobmKpbae3F8i" ..
	"a12EmoCckkoJ/3Lpf3tnPWdWkez/UqJr8UZ9TegPSxkKFX9N+v7lSvexaryMuViL6lwz0FPHyBEHdVpDOvUom6KeSUaDH1Nvy7Et" ..
	"PCc8Ti3QvaN2sXGwYHnWIPheTnrpJSKL1cbygT6cBklcQWG17dyosqjNkxwsFQsOxrpRjoCJ7AmyD/WMa3lvhm+w/mJp5Eddjxdl" ..
	"3PK4VsOUPT+gGTV3GfT2kt+hqgpU/TTXeMH6NyDiUs1C4eeldqnNwpmDeYFfaewK1htSvvc3ctW561x8sCCkv7XC5NMvPJeg2sG1" ..
	"oF+rhAfQXEdTg7yDjdqb9gTp2xxOPc5Xk+h6hIZ6Fj52cnvAGVn9VU5twAKaD/PfuoyG5GtY+tBNPW88RwF1hQFloGDgEBMdGsJ7" ..
	"Wf5GKbP1rBOQXRUQ1gywqJ4OUiVVNaSfcG8wVWqDjS2bCG2unzpUHNEs8fwt689xz0//SoP8sCwfvAep21WXLeIeYvbsj17kCykx" ..
	"MJc50tuTSb+ABi7yptkthQHMG2qZozd4KEC9oSSsEYB3/eGW9gECmcFB2DH4l3DpvmXf7vCt136hmGg46k97qu1njrHviWtnBzey" ..
	"8JvsTLY8IAkyNgnX5vvtB+GdHgPbJO0OmsdnOVv3uSYxFw3FtX0u7660hTzRx0naB4tjD32BOqWURWFyO6WPryQSJsNoNeEuKGCb" ..
	"acrLIAzg6vLtuvN1u1hI9SMLoKS3c0MP2CVgcwAonXkapCP4S3qFUZK5R0J20aXNjCH4G9jwG+4VyQhvLneZAKdg5TuWCGN9Uri/" ..
	"HVVZoGm6HtOGqM2zZe4Eyo42uIra6ZdLDbZWtUO/yVNJ4+lg9iebqd4+s/9V3mSN2qZ5dkYsLp+w6zbrrSXALpzCBuJ+b0eLLgeR" ..
	"FFV0zG3VU3JxOZ2wt4BkoLx7tP4grQAu0dqRpslKaT8lQRG7oWHdOAMg5DLTNGauO0UO9sBkw8ILzWra10F9KkzRWeEztaEJiGWT" ..
	"zLSd2crhUryLpOZeiXbI7zw9fzg25jCxA7kSAKeyTiKo7Siiml+GQkWxWCCak5KgL4KK/wC0nRK1epKyxWjg0vtXaQXG2obaLikE" ..
	"AVYvBRTRkGFdezMfrRJgXrMTyL8kt1v2YCkcmtJpDWZjKTQkfaPcB8odB8JIiC7zS5QN6rZLE8nAzF7VQHobc6ihczjF66Ivsnlj" ..
	"g4udHulLbdGZL10BjmTcNiIPgn2cmmYkuEjq0VBwQxjvj1L0KmRjzTM/eKD8mpHea4ftG9HFv64ty4mfK/5OOCiHTd8zaGBkSZjc" ..
	"UwNf3F8oZIGgUl41DwIfPlhhUA3oWDAqBluNu7qH0XcPcS06hXBEcgruNvrdMD9aGSlidtlwTSaTM1MGXtw8wCz5cMPPdUa+32lW" ..
	"l20lD6oa7yLAao7Ve+el6Dn5f1T63ecQPPmjAFE5N86QhxkeHQAF/gEgweOEhZNUYC6b7t+txXhwWF+hbxGNAwVm38lL3SqC2ZQA" ..
	"p41nMhruraLau75w2oDnoSD/AYL9eSbwthASz8Z10YRRQ9lE2HDHlnyC95hftDzPdnKlELaUnd4JU2AmFHNfFADGBwrwNcsCCR62" ..
	"f/KJ6zLxunrOVASjKIcOnvrU1geWdvpHDWHRuL6y10GiVZiVzYfEZ5P/s1VAmzzG3l+YdM0iwOHhMpDQ4G1ocXkFK//aEbCGVDGS" ..
	"nvtICGYX860u7jQRmShaNW0CCIykLmQHDm6PA5thyuG3LFjxwI8d6y45fkeC4dNh2gzehsoD4LhDnkyfgvIqW4VezCiGqqPsrOsH" ..
	"35qHvj10Oo6oGAY20ThJgFoWfRUcEsn7JJxbQs52EeVtYDpLxttHDuGjnvwMypIYyQxD5/ETpyVM8ZY72+dFKWqfYfN5WIRfwm1u" ..
	"QMjYQ6zhzcw3TP7rXTJyI7WBKAnj0zueMS6Ci13fW2ddd7dkfNF97bcRQ9Y9T1/Qu5fDe5t3GNNoAQmIXzezEEbLmR9mJFPhFb3W" ..
	"BUMfKEgX+kfkPsesvouzviuz1i1eYEkseooEnImUZk6PwYG4UKL8OrmNq1B3WrlCiWnC18BT/oFlgpN+QjGV2JvQj2kPE/p5OI1z" ..
	"K1+TvV+ceHCb19eyFp6ait9CzgJGh3GFCsTzwSkQlxb6vr6Vl9DxCX3ngyPEFozg1L/K1gQbHB+BUI22o3d/NxpDJE2OpGL5od5U" ..
	"/RW5K+vOPn9boNidZc5MA0QVqM3kc14h99LUHjfYwd/DF28C7IQVMswn3jd1ign0n/qJtMdMtpUGleyuRIcvkV2urZM883ReX1SL" ..
	"GnTAwY4OqfHnfNZycbRp8VvDYPz2IFoS5GTzccpAGmKq9/dglWLmlFY7X5KYVcBC7GoinJXyDQVQo//9g8accn0IVrwiDqOKf9mY" ..
	"4y4Fw2E8gxSgqT3/jBe522PPbmZApHC/XZx3hIuWY08leUvYRD64alWTMMOtyym6o8mg2lAoHYWlfQgbI9TSoCsVoumvVM3VzMEI" ..
	"muLm34Nb8lECotosw0NiEFZtMpZG1VaQx1cESvNQFof4RDlyKMXz6CwVrcYcNRGMJOPVoZt3CFWYCvhKNJbyffpUKBhEQILKhEm1" ..
	"yM24uZrPTu0ODoxUgkW3LFFbCIDLFxSCLCpoP8dMQqAdvW8aXti6f4YSBrDKZyrAgBXoMGRn8CwSBgAi9AlD2L+uQIh7zaalgt6A" ..
	"OunExH8Iy9NPKH1s5NPj9Ds5V52WewS2tSRvNIoQBeGPyC+UScFeBNNcF3IJckrlb/ym0VhVHH89CERbCxmB1Dxa+OMZB8Vsa3H5" ..
	"ZHKkgkcp+iqxgcDenvgXIWAnixrm9pyvrsxpHaaj2f0EEAHdGoTYXq50lVpZsHkyqj50m5Mezs76qr6yCvhhuo3JIuaqUYOO9sNw" ..
	"BU3ojzqKqTSwLvN+aw1lyKF7LW3sn8iKWkSnSUToxXBvH9f7JtsfLtKUJVwPht5nE9gQgmOeGM6+BjfUxBRkTrtwDAT+6nTJa8o3" ..
	"2p/daQFxwymSkqhKGCc39prpjC+YdBrf8EOX9gDrtebMUXBnIhWOJ3Tl7qKADLLrxjvxgNfTSC6Kx6OqlmMMNID/7VI37a/+jImV" ..
	"K4ccLmS29GP8V95x75t+nnV9c/OLBymIJJmEccls8AJwszaMnjnKf/n71oAK4ODZ7pUjtwaeVF6wfQdWOMjMPrN6E7RcdxsUQfQB" ..
	"2CUXLOToq4m/3WpUfjf8zIV04BXr5snpuI+F4Hi+LUkTlzjdiAKhTEpB6WYz63+6H4CXEZ041TS6rldbSHjBP4dru0KgbZY3+gkS" ..
	"qNXZkkves42EGAUC93OxQqs2u0+3eruCCTTe/SeESBXXHxdnlA8m8dXz3T4usJbUlR2ntl4LKgoMwqIby+v0bQgD9QUPY4wTDe2J" ..
	"uT/iMlco83/Gww8ftH+qfuRdAFVl57RWWvvg+fZTwTrM04cm6TsT4Y3U+Yu19646tTTYkLIlaGlf/nra5JB8kgbzQQ8Ty19pO5wf" ..
	"Rlt0TgzmAUKQbmBM72JC4AKIA2YdZ7X/G0ISDbOwa6QcU1tLavakTjUIvkXx1201j5lK+LlZghlEB0xtLNS3pBG1y34MD4jHiDBQ" ..
	"592qqR0TAfQ3eAmZ7tM4hQkVF+e8xzKyiuUxlcC76ZKVCEEVZhy2OgKwNjn7yQBtXASh+4tGnhcPEoTs9efq7oCe0kzIfTZWk2+x" ..
	"LL1Fjf6nLs5wWxLBdFbDzHVwW1jnSQXOZ+4Yeg/7q1zSS9PFtjpTF0d6vijxgYvu6ZLMoGt2Qbwqaz2Yr1qRFkOEz9kXrUdu4DUb" ..
	"xqO1AI9Ls9d7bkJlsO2sB4nvECCE/f6pZYWoU+t4RNkwYKInM2zPTbXgJGldyT86m1iSuGtjgjX1tDHOC5YPViA171FzayhpsZca" ..
	"deWQeboV3IRjcLDLbkCcs7pfzbQKz2jDObWFNkjcqilcA2PQyA9ElaJdHMCkQTN8/UB4hdtGB95Egt3fHPoDMmkuRi4HCAuBfINM" ..
	"iDVgxrNwWRLWQuuLCXhoFlnnjllLBXZYyytfUubgyO+iGeVAjSedxE41FNTw76u0mdmeUTrjvCZPrzCYmlA7XtPgEVv8Ty2378dv" ..
	"H6zkGAcUjsq6Ulp6stgpEqadhDodr8TKA2wtRVDPB77Koz76d74CAP6xQG5OIJBAtSWA+rcAuy5ro+wcsKmItdzxjcpF1JKY/HoU" ..
	"ACz5TkvzybRbk6HVPXcK8cHpthCavLAFv90FN1kF2N3TX5AtAGqd7pW9CicjJHSl4ezJhyKh5iQbnLj3F+vPGK91jDZ/MrdbjHbW" ..
	"vMBAFc8sGxAEjVFUHYOda8XRsYFzBjeK9OBsvjLR0m2gzRFmBJTlLSdSmlZp2C6s+TrCqbGTjKuTxyehyYUoMpqp4XaZs8SKQ2uE" ..
	"AFPa1y+zEF5TYCR6yQve4RWQGHKJjHm7caBsiVz/GQKDuXrCoA7E7lCDtvOBcq3MCi0UXrlcieiLPmpZpUt9IP9gFxWlXKzZ4Cwm" ..
	"gChl0KOrZYaLpSd1rcjqdiewOWE3lnUbY37Wfojz76fKcd7d76rOlA2FE++IeXo6rc5QMgy0r8NQASrd/ERuJ+BebsFkrTDHIsM9" ..
	"Yzsy0DTlix8dy+GvUqPu/DO1k3/XWAvgI+CtdZHpgLlMFdZ0EAw6Mk0EtJNgzpqljHwgHgAYt9XyR5vtgQHPP968BjebEQEYhfxA" ..
	"htROi3555IwkJx9n44UnBefosTvHsx5FktUHlXbxjiTLLECwJ1KfoqQCLMVXOjFC4X/ixaBT7z1KxRS2SqPUemYeWu4QAYTXmksf" ..
	"AU7JZhXaU3CpfJKLyDOMaMJfeqE1gxuN7RORB60bCp6JV62xC3V46ILrxv4Wsp93NyT59+jjUgbs7VRfZ1UXPzl+15vtlcs1MkGb" ..
	"S+RgJI0uOpXHFmjdw+AcmKRfQVaqia1VOMbmjTR1uFnh5lQhVDC3MpN9NzP5Ps/5xdhgBHKGIWNDTXkaQD/zOjQrI5mEwQ5EwGl3" ..
	"YvaLfO+6FLTEtNux0tX65Z9lliHnhMCLbd9g7ASLnuoygWavaY74+u/X3R8VSoI0cMGCERauld8UMljOFSN8bwhq9L+HFSFNJEQk" ..
	"jKPbCjdrkV0ePA2Z7/ETWSJtHl49i5XoLZtR2baqaZfVlI14yxx8cnBvszHjfMN4YNEj2SoioPDfYcEjgUMjWUxfy8ZiIi1UG3Nk" ..
	"wVQSoKa5zRq07ovKLzgOLTT2DHGKFmg2lCGO2z6JFi+njFhtpQbQAwFPlRB5b9KgXfPybAR1AzQiOlUsUNcrbGft0xhhe6iW+dMw" ..
	"8VOtYntfkDugMhkN2Xj7PZkZDzhhdYVNoiYPCS3Y9IunAzrYdeTpnTy6qEWeHeCHTOdUlTkCCfXXuFiNg4Ix3cQylGqzNs+ymuYp" ..
	"MYNbiui8Nl4JQX4oj6697fxx2taNvJUkmk2G0rUlWQijEcJOwzDPWO5bWNl1FS40f/UpwAGK3HSuthZYHJzVxOrKye3ZQGxhhPFs" ..
	"5AKnsq+Hrdzl/wkY0ME9iBvt9TTw2zVGvmQ8UDDDYpN5IW7clQSlmwQmFBVxAVuz4ynnLV4DkVbLBiWgc0nK58Pma1sCGzKKfd2X" ..
	""
local PAYLOAD_P8 =
	"vxhTr7KdBEx/W4dGX9+YsJWPAnC84gybg3v8YlmiRrQRsMxTQ09z65TOnuO3aoZNGdy5Fr63QPDDCVvgghV1JyFuzA2NvHTHEQxv" ..
	"Ml/r2XSD92PEMWAwGJReEsmYjDl2jM5AOVAWPUHfYlkUciCUKAQxGg4EDCXkSTn69w0ODSpNxQGXs4X0a4WojaX/Jm+QWxY57SCW" ..
	"GBtiH/b7C/M+xLGzW0t1TgLGNtOdyW7NXLI82hX1J6Czr3i0XTLDA80qV+Z6+svcYHGK7vWJpT4KYerIZ557xXmQVKf0TD+DKN4N" ..
	"4scrARDpECB9eWIAOP9YsQ9q9GcHuspYJyXw2WQAeuRGtkzQW/8jnsFOAwwR8Yw65REifP2VwkjS6aW7RfK2pqBsz93FtnTf+Iqe" ..
	"3Z37ll+H9Mct6671Ujx+xTp9YVj7kegNcxhnXT3qp6d038SAu0gDiRdbU7re9l5chmJh4kAmnJBIMhbiYNR9BCRv3kwL/DAdNVwS" ..
	"A4vsaR4oUqb2hiS+Aii/OXvhSuCqqonAUHuy4uKOQ3CE2khiE7mpa68ORI4SIpUPkgeefiRC1PGxsZcQqEgSxgZv/TjXZ9wdhr6d" ..
	"18Ad5/Y1TnMd58Eu8VMcvEI699AaP3tH+QDU0W3lOYHW59zevdfFyofrakpXEDwXBEBuHo78F0yPWZclcJRWBeuSw1j4MbWMWfFh" ..
	"enc2jvFsv8zAiTzR+XxFvwKKLAbTOIhFqUiFSC5E5N2I1oQrRJSP7PDm7aYDKJIvNCjBoDILDux77Qop0wh+CBn8mKCyM+KA/yER" ..
	"4XZlY3jVtxbtk4/hTkqetZiEjbClsrCKx6Rybkcuj3NMa51uSrq4jUIzA66kGTuJRcvGKJV/SZhR2J0fqCMqSp1Hw+e+B9FL67sF" ..
	"wF2sIPdoGqhd6fG2sNcWBju21xFnkYE3CVRb9PnPg8gU+P3avNoLSP/SEDWwBycFSTqH0Rn/9he0Zc/VPUHOfwG45yv2PJ/TZJjh" ..
	"kwnwoSMrmOvzWtPAsMt8qfV8toOR552ei7XWPPvGLufctbgVmxRuTkTxFkZzIiZYeSNw/gJrqZAHCVMfGEWJxTYlVfF7FNm27jG6" ..
	"uE6ysZYU+PiL5oichMfDcWRGt5e8zC1BAwKo9I17StVJIarGJoEgIqzRueBjcAK0Y9Ro3e0ZlYPu7xUu5ifOGcOBfoMTS6FDLDRU" ..
	"wZAFbXfA5eilkd6mxyLFVeUwgxfS+LRGOi1nvpYhRhP6MnY4HpCUXb9wJUjEIBwekfvyt6eGe5ggfJfsf9Q++wMTRanRFxWsNbFJ" ..
	"QRgi6P7NItXcBTtph+ezB8ZCHJ9uFdLvAMZbR/ERshQSL8VBCU2pJB3Vr+09BVE0u8S8/uASqt+RaymtRMjO6StWaqY5DUKqVqhk" ..
	"UdDQ5hO8pPTnH0c0ru82UjdHNYpPDtkHhxyjmIE57jWRJgjF62FCCBatyQAeczugEnjUnuwFisRJz9zCpOCN5UsYKzT3HATWmPRn" ..
	"pEgtwXHuVUk3dldmhGgQo65MJy0tVWI8N3Q1oAy+CAM9Rek9Upa1CH/ugvS8I2up76qM9sZjf7fiA3xw539TOpod2LSyYRbR5iTt" ..
	"v8UIdFw5ER518KF7TMAwm90wgf9Z/TuH7hlxILdH3N94tAb1kv1PyBG2tfXlJ9Tr7a74Hg60I0hlGXANFTs4bH/CTwEpnOXkE6A6" ..
	"KDD8cujsk9kHZCXm6N0gjvHJ6C39kF9eWb28FHKy3GIqfxjmwu/iVH2IedEyI/NuMBCbcYdiffR72+6A1HDFHaha2qFeoCUDWY4A" ..
	"1qSXxHOxGKI5P1YFF/EQLDH1I5j9Fx2nvMpeTmJr6PUPMfP43lR9iiI4hepQtum+G3Sc34s/OO8WP+gabsLVdaDtE5ccEUYstD5x" ..
	"sNd2hqo8hOLGY/HZyLLtGVSUk0W4MTXk15vuZ6b82mqk1JwRgI1UHCtGQ/MkPdNxubi1yqwYFKfW5TRhC85NjwgP43ZikUfpNsyQ" ..
	"TjC6+Lk/polNmryVCl9EAknDYhbje1i5y4+OSAM2i6IkZXGU8XwkmM+scX46o9hjWPtv8yLSttFgzlpYks90vwdjxbRc9CQd2mCj" ..
	"nTetCMNre91VtQ5XHOadD//qGEiLOjkmmNKIbZaxRorqfalTYxrOwBoFkr774T1dMWylbFlGK1PNSclYk8SmB0TOQ3jGLQgF7kCy" ..
	"JylIf2NYTwL94hdYueVvR+CzzZLL+UbBFXD20p7cCwE/5zswTikCa8zKrKPb+PP1bM6AFrzq4sMKHBoJrJmgJLjm1mkznLgMu9Er" ..
	"lrb1JfS6XcZ5l8tVhc3b4V33lSJKmnT01RqahqkWaaWoAxz5sbDhlHY9voq6vVhmK/SnzYWBoozOChOrVC7sq+S82oGxurx0OZpk" ..
	"B0DZzwZZ2MVaJK21/j4/iUOK9ZI0kXH1lCyvOaXSrrFhZFucKKWM67A62uTaG8ocYf0BF8rq+2ms7xLtYuUyWeTZdIjWs5tI076U" ..
	"FRE0bL0nRmoMrDdI+NPbgXPAZz6mzQfzutlf0EPZdIQQnHuqPa4P3ydwn/tTY+c5nMJNc/uMuI5A+kW6eTLBeGvZpOSNDxnvWoq5" ..
	"5PmeZGF69jVFdmdQ7aZh38seyfR2GpJG56EIdTwTEi0XES8skf15wxKZJ5YolCqsjw7b/6TCLc6mIQSJ8jyJU17kI0DMORiy9jcv" ..
	"MeQsVUl4DwYS9ABOyOnZazL6/g8rxrWCDD0n0WOuGTXyew73sOgIRk6PbsNVObnBdE8wLwHhyBYtaRS2XI0wQqDlvUPLMOXtAQNu" ..
	"naDrt4wYPk6tCZ1l6HVVN8LILinCJbmn6YgAbPIXCmCj+raKSI+k6kGtw8ftvrXnh/T5xt/j4HGHYRBrartecDQUPJvMrk4XOMze" ..
	"Yh/3axzWRpDpnNP00IPMoryzwM1VQ0AjPN1ClaRT8JUdENHwBbHt0/gPmCNKT8FAq+/cJNjHe+DyEU1wPhmF20rddioWlGKpCY2Z" ..
	"g2pg/y1UL9xdBdNcsJFnlDtxT9IGmAGFbzxl3Hj85WWVHgCLIsMyjnnGi/miaYxGhisb/pin+e+A2eBL+BhbTi8Df0xLhBv4+GiQ" ..
	"ZkvgMOEnCN1b2S30X3zszK1xOR1skaEvXNj/0/hvgy+9xzzi3anavlMJ92fUxPAYSvzKDHlpLNpBnlwjyiSL3mJqM3jmNLsVzpKZ" ..
	"vmQ4cxBc0vreomalDie9kcMGpjd1r6g3jn1U5ZlHnLjPUWRCxUnB/swG51FYq1kMSP1tsNNgHhFMVDtFRpIOHV6N8QzSAPQkgoze" ..
	"Dq58zfQfnrgG7o2qpt0pf4uwNby9qFxGHCuu8Sejzdb63nVvWRWyIg9gzW41BI8kHfWbWTDqlEhQTs4+NAJNCH9lyuEo02AMqc1K" ..
	"GqIyQUJHunBwpX+U88wYO9kvp9yfnUqrkJEkXI3txOIR/5I2XYjyL02kidd5GHfWBnZecy4cKXTjVhalusE8tknIRMqxTr9Dyjsc" ..
	"OpeFRbDo7wiak/4L3X4XXmnpMq1aqoL4Z9hMnypyl7c4Z/bgltb4nBEoomJD4Urvdx3Y5ghnJ+Zr8gwyuboohHevtMvW83YdVePV" ..
	"0QMsH9/n9EJ+TYGICgYDSHQMJNvbaSJupGIi9V8RiCIVEZgkJQPdnIZoCqAJFWRIJSQT1euU4OxW2I6xUje0v1+P9kLlOqMEo0tC" ..
	"0zzo+Kqm6BWDP25L20P6JRo0DO5aBb00YOVnulXBud4Uu7/43RmZWPA+G7CTklk+YbmPdNl5aQp1pl3Bygh/xvQCIMhhFO36ZHIK" ..
	"HJ/hZB/GdVX9AeXU35m6x7Xyhfz8l0rvNslIe+zQQ/axcYcJ0KQSaqNNhOeCcHFUcFw6Z3gc0Mba/vJGGGySSUWXaQkmxmnYJvRD" ..
	"3dhr6VjMuPVxanuY2fgF9+maxncWBQZqQE1WIb8it5QbsDRfQsDJ6SB70sObVxys7hFCvNgPLbVZ+0MeC73GVVpfUZh2RkJLJXzY" ..
	"jdSOqoNOIjz8aQZEK5ZCXv5ubIXgOmUxf1CCHoIoZlUovaay8rU23fRKzCIovXf9cu1AZBAFkqyvJqTyt5xaWhzhsCpVAF2gEsAZ" ..
	"IA8w/Gl1tRaf7/PS+fRvQXbTpAdgCcW+KaZe0MTPIgEiaUBckc4bNeW5OAq6clhUOZQ5sET7QxD9GL5SMgB+Uf5EYzQiWdrT4h24" ..
	"ePb1V+LWsnZgPM3v4kmnhgYpSa7iHYEkMEj0/iD7SaqowLTjnFXX6eA/tk8XBx9/w5JKMViDtRsZjWrHiphdFN6ihf6IKKWuNKvd" ..
	"HpE5RjGzHch744A2Az7M2jNKasHNQujkjrUPO5+5v01NpkXZX3xdyillgfAVrCyXsZn9I3Mb+uoYvSGfBJNNIWH6Vpc5aetvR4Bi" ..
	"HQFNYhwcop0yhtwaAsxGXzAYT6Zkr3pdZnzbsIov6jNcVNddbgVMNS1R4UHnrPtFpb4bGsLq/8d3yBMcapzTwRjTl+KFzDXFhPl+" ..
	"IdnsidsEZr5aAkeMNHlc/hyWQoq73oNtEnN0jBpCuiFqAqYAYlIuOiogqi2ql3x90U+kOw8uHCY0AyLdbb6BgcymdyfyHh3jTTwM" ..
	"AiJwKanWggzEVCiYMvVgC97ZXrUyZkI96kfzpQwi1R+gfr8ZT6ojaLCO96d+ATZrWBNTlRYx8ecIL+ER28Fa0r2F3+j+eSAFQa/s" ..
	"jS0FQ5XcUZtojkJP9MqvWW6mivlXWuYO1jwLrMuJRdJlvEWu0bipAJdLIxsZI6LK/n4eubFvtBjZSxkFfbNiWQM1uXD0x98tD5fS" ..
	"Rcuo1UyLiWHLSB8KwWslA5+24Yijz9zNzYtzJlaQ33LtVAxXIPsoRrkl6UHWChaBZrKf6+TXWVBho/tM0IJKtPTYC9tPgZngd8st" ..
	"2QxdZoEdHZS8A95COUmyi6cCCiBBqUv6VwbgZaXt+44/qQhHGbEto3VPF/AYaB+PKs+NEQ6Qrv+dQ4XN366noxATL/ZmfFp4Hpkx" ..
	"bvo69glac2OSeQLGPLPyzlGYwytmfU+oWvJv/iCmv0cSh3cGgcf+f8NZeKTbDE7g494kchXquRHgQDkXyB3L4lMPggcpUCBj3knj" ..
	"IIPye0bml56iYUbBsvw9FQZd1WmZebz5VSOAUkvGRPDwDGVYnk7fxZzZXSlVyKiwIovu+VN5aXAU0rCbxbSuwH9N2uyhLrjt5uC8" ..
	"xW+KKGsDT1jvQaz0YJ1fr9ERZeGw7IscCR2rAIB91r4DECRS9WxOYZ6dEgGjuMRH9z0RHu0kglLLJ1hTV3jMM2P7DfosnxQ7oB9f" ..
	"HfnKsdAtFAvOUMn3dmgZR/5jJaXcc2KNkEMGTFkEd6zhQcmoQ3GDDCKGTK2D/X7n7eloMQMymSP8ChaXKT9VVkoZg++BPBFxF1fP" ..
	"3925/+4+g1NLgEXuZTqIOyy+KN/JzORAqAQ1deBvRyDv8P6DDpxi02QbJFw9waVdDsWsaaubPRBhTjtwTzCCKPjDOG4DP4C4sdfX" ..
	"PDsuu6qmFpgkc8n4nm7E44uwT9Upmt70WPe8MQJwG1JYUD+UOmOHAK066vkJwmpJxKzdGzsx4O46mwNFmptTep3aGvC9OrQuxp0a" ..
	"mwo87vdXSHgr1NHWBWQLWh8wSiGV5W1f5ImY9KJIYxgPpZi6hYAJ5Qsq4HSGq2ODXOuoNL9DmfrtRBPNaBBEgBQsA2FBKmMEQw9h" ..
	"U0+jBnrillwpIF5Maq44P7n4omdQ77s6fFE9oEsbS9VKR+RSXD/kz6lSvTwrsmFVDWt4DzgFqalqaRO6l6ltvuTZR1o5AqLgJEjw" ..
	"IcavaZSgOqNYrWHiKjuYLM2wdjPplni6RbHgF6tfaj3HmPesTOLQCCZ1n4oQJQHHY1XsLjdoT30GFKbgD5B7F01UAV4VqSwSm+HI" ..
	"wiOfg2n3Hogm0XuifSjgLxtGkfOdRez7aOVQZUGZHgA6vCgY2CuW5ZtdZ4sGha/luj9en5j54tnuRKSIhejnVb/AXHk4JD9Z6G5K" ..
	""
local PAYLOAD_P9 =
	"dvpWfXUX3cbMXHY8UkBTIFiPb14FsA8iS0N/OVKEYJwgYXcG8SFhPZOwHtHv5ivQBIiqlgHJbWhDxyDesru4bFvOoa5+2kgIKmCq" ..
	"Im3cuvca3RXq6FCNswp6u6TMTif5Td4DlTcCwqqS4cBAB2RAb3wFBtzfqF0CLpFB70d3Tk9IpC8qQumUCJHm802MlVoW1A1UWMVe" ..
	"AXsm9WuhGfuvjZdt4ZCUxIBleWrEKxxsLhw4n3nes/Ii55RnLbRLwKqnZVEr42kdVr4VaQmLyQb5feensIopKgKTMV23HgiazEr8" ..
	"xgm2ZdzQFRGAak/ry9XFniyMj/eitJfflL7dvk77jnvv/Oy7FcvkBVWgmmsMGTNg1O3xv2GlthBs/hDjnWN1JRsSb+aQgS1gg/XA" ..
	"H3d5oG6oGkaGsHWg54ulhC7BR0iHiaAVxJPkyEAYh2tDSJw2F9/WOpgJLaPnwTuH1HJ/fhsjoLWcnjfVnUhqAQQCGaz9gy77OW5B" ..
	"zYaN912aIDnXGxTjWZp20uQkWj+0wILDC+5bbn0R+RZI46bOar8YoHOZSc0pkzF0vu9HHq0O0zV/z7tY9jJ/Rn1XumvVHPw+XznJ" ..
	"VoAtoS3gxyHUbPkbvePbtpk1xLod/R4hivRaATHIKFBgvHSFhOMdpg4ZL1PG5HaSGfTSDS4fjZPuMX6ZDV66JqS46fMRSar6YA+w" ..
	"kwDYotyaaApJeloKonZKAZ3TJP6XcPRuGdHpL/Ei2mJoVSeWKxN/vfeauSmkIacprPdszVgtMW/qdDipq5cd+khiU6nHm8W6RPBf" ..
	"MxoNvy3vI+dHLVlAGif2jc1xd02nMqmPzI0yE4ILaXmfjzuNS9q7TacBYW0cBdv3HKsLVLarIsuWo/fk+e4Dl+En+AcomII9/Ywi" ..
	"r5KNQhtxKqqg3DBxSjaqvPM/qw/8hPbLU+X4KwyL5alrinTvN+fzgHpYdtY8lMQpInOD2FMQHCaTXV8gEe2DzeUAlgtPM7fV9VT/" ..
	"9/lhawScdevRTaHBlk/VmI9fICShqY6XhQuBwY8fdUtc5KNyXt6utWKysdvKM17DOslAFxHIgcZbDoGhVOIqRcNHj7owt/VIQO2B" ..
	"HXtT2Wz54yU3w3cvYAVW5tllbAuQHpYyGfdaE+4P3BpgHYcAVjQPf9UASDfscKSG6vtBYZ1Ps3lM2iwQZtvt50tLB2ktRz+mOOjG" ..
	"EWCiTZWFBacCXTDjjuawhIMiEwlckGvCwvSwfVz75dOeQrM+W4ucnsYRX4jmxkKmRvG0K7nIxkPoAbX6f4e5podjvOrBMFqeS/eK" ..
	"J46UYK9s5aGJ4GU0sLRWjLy+W+QSrnKeJeaU7xj042xPA7uNPgJspJvdHP4H5lxymrLYndngI/rQF1NmkRCDlxZa31F72UYiMkN3" ..
	"XlcMlhGaw+JAtSWBKzWM60NmPRHGNWvWLYkpkX+mS8DX/55dATtF8oPfEACplW/XrfmaqTRHGtsVtn4gujpRWlclt9ZnD6e5YVaD" ..
	"hjWlKx62eedy3U1Aa9ydDU//ih3K9dR2oOqTebxmLECxABhLteqfOX3mGN7zt5Eic9eqV/PemluAW3sjKAruNOYaK1lXGSeqFTQk" ..
	"wg2M4PupIgKqIb2z48VvyO028WquahT8LCDnMJLvyL3HNKcVD6FTRNgSlgrc9bao3P4OwUfOfp9BcYuP7/e9B3ZvqfS0yyyvW87v" ..
	"othRdoPrgiMh9oBRtA3bkJsVSDKfVDXkvJFIAi3n1KUzmoit7QnD+WsI4MroVngbOisSV2g0gF5o+qNjq/Z9scRcw8YKdknc0t7G" ..
	"x/yVSkKjrIHp+aEWuEvsJ7vIh+gvqpjPK8/8e8KKrntiHAf7kawficCWy31xaLqz0hL4l7RzLC95hDdSMV2TlHz7dhfUrejHmFk3" ..
	"CDRIYBKyRDVR0Jn4rQRuiqV9KnK0pBBdYzj0SnzP/sw3628BakSOhz+s/SLp1lm3VPK55AIiKaYz3PY1UnIyhxA4y4gDbAdMfbFK" ..
	"K0dQRuhhDGOTbz1OQIGeK3sVamJKjR1ut7C2poQ0zKpZz86/tDb/j6JZfeqnupeaFnvWoIV0D+lqiyEdDU5BO/H1pxuhZ05n4nYV" ..
	"oh0a3MQ8CG/5i4IgdE+VsHeeEiV/fsvIbfMKc+/JnIeaZJjwQ2NeF5gn1Zg9P3QG5kq67Y7Gc63bbnWrMDKTYbUhFDhcCCEd98UQ" ..
	"a8wHwnB3ASVd7MogiGeD/lf2HGuPrAJ1tOjILWkNGMQd6ISrLvCTMhgWNvXqs0wcaPP6zXCi8nZjC/uWghPqeNLuWTbFmONppu9L" ..
	"CBgr9NjhcvPsp7RqkCxsOLuNtFKoyfxGm6uKakR1gGyw3iWt80p79brzqH3NL2OmzcD9wxx2Sr6z7bawB2Oe7DL7wt6DxvZlMAIH" ..
	"7oNb1u6hmT/msaEbk0xxA7qmBtOqkGBVIAx2z2TK+XfFL0pyK/P35lsbc/0CbOAD6w7wCqKz3pRKwPzMMhIL1kgIXN21Dej1MlVV" ..
	"3ryV/+tzDxJijGa/Y+Cg+kgXROx+bTXbva/epzREHNrEl2Q3HpZZjJ5OxOCAUIVAa6t1PzwTT8AoEmSB8j2Wuf6lK9FqaJPASl/5" ..
	"W3cpwXwdBGpA/X1rHNsYsEiYpiigNzC5y1V4OGMmYZya1eDAAqRtMxyUACB3rpYPivBNyrAc9CEjEa7FOi10d3TVO4mtD97z2J+c" ..
	"583sKYqpyTlz6WKjWE85SfpHw9nEs8tpCUy3gvv38WLn8eja0XaPP/2eMKd/OKgm4m2llmUEMGq1Nrs+gYPD6BQH0GZD/PAi4rKB" ..
	"Z/a8hVHF8ixVjspF2d7qTgtzKpdNcESa0HFqsPXIIpkvqKq5nKTrYdBxhOuXtHgjerj2fyQptnvv7qlDpcCUD6B6mFHJEsU6zDxZ" ..
	"TAEXemvRB7kijB8PZe/yoUOHXz0GCcpkuWU8zuNzbWJ87Rhu+iSBdeTJ/HU9+qFyqPC3+7wVNiglUVciKNYqFaZlzkCamXE0CMQh" ..
	"Jt4nvUV9j18anmqzqxavF28/NPBE5D+bXWoQSTyN3XaYwXbS20U9rZ1unTM2YGTzL26U50+nfesP5zdkHCRT16LKA2bq8S+f6rML" ..
	"1J8CIsDonluXRvS9o7Ikbmus6MIbPaFwgEMn+SohsGyYh6vwnZ0NAwM2rC+Wtlq08oil9btN87R1DK9nrJ4KnbTjQTmnmrBIdA6D" ..
	"pNKvdvSLMuS3fPVgHUWEQbuc9zGMh9TXtUiu/Kkm1rON3zpB1CvuRK3xlPRIjKeLCkqx7fWQncLl84sTm9sUz7tg+JMbBlu3ondG" ..
	"uVt4oiZC7h0g6FuVSTJ82H5bZ4BUwCGiA5+gJp3ZukanZiYfkdoF9SfQyN4WQl4GfOP6gGcjVQbnkYdQRWvmAMQNenmXywt34Pb5" ..
	"ho1DbC6NbTzK+XNTp6gtylDnJBdZVN342bUsfnlOvcxhJgG848JBANRuz1eb2amVkvN7fp1saDIGU8SBdD7cNXJp2+xM3CuxpAXQ" ..
	"OKA+IKRQJFtxg3j6kGsz+Wipjqfn+kvFTAvqboia5A9DPb6jEeYm/DHY/mEgOU905lBmdxwxCWRGZunFaXOpbyyr2L6yTmhEQ0lq" ..
	"lxcKrWZ/2NN/5RDwjUR2BW1WNnkQxmMdLeABDRpP3iwRXFARc1efWqolcoIlTzJ+P223QoofXWNQ8z9bHHakpTNp90VI/3kfSBnI" ..
	"uvoUYqeFvBGbvVZcaFpGr1HC70AdJa8EuBbuG/MkdbA2n3OhDoHS1IZXRvTWQlo5DngaBGCLnFVeFjENVTRmkyufihxqmqsCEGyo" ..
	"zKh+3IFJRc8Lc6ruG21U/qmHXA7lMY3aZg8UNDzijpDcyDCb/F7VhY2WoaWr+9WCmJxLhs5LYu+HHZTBzaOfFCest880vjyNMPdZ" ..
	"mTCeXLYXHz9tOI+V/po1YsRXRiZFpPnxSovvpmTtrzI2Xh45nLoIzES8YbYEXx9XHiMvK6liWd1q8bLIdFjxc29Hj/DSKrMFTIPv" ..
	"m83bcRXeeAJ3cNwqLck3Jf7M950/qaBrjd15qiW8Oc3vl1acAsNMuq98p2ipgbdvmcYiBv47zbslLpgR9lUeqjuYdBvvalW2KwEs" ..
	"led5DVGipo0ifMUZBLvdvJyVpQuEjH/xzIC8OiGSu1UcLaMjs+JzvBeAZQC/qITWQ2bn7LDsYNkmByAyx+xIS8oBsiYZ4f5CUhen" ..
	"asn7jrAkuWXvqOyu0FjzloNYPM8cKjeXb/IRvCCW+/7I4ElW/6sY9gdBX1rtORxlqeoXCJV/S8gTIz3X6X8nwbYDOmMP2wwPHOgU" ..
	"nxs947z49okRzBij/Ryiz/CWB3vZ5N0ZRiANGBYqipwgfU/Iw86HUvuvmow0jGDOyzNjPxs0YzFmzXVWSeaPpPqz2xYxo4WcxBRh" ..
	"Opkjq32fyaOfLD9QZoLNWmPmkKQcKIeDagaAApky1OOAtdvhlzDLzqG4AEMa6xsN8YTIBLvS78Enh3H5up6Qn+XAPHGjcS5LWpum" ..
	"Mh4Q4FipvdcvwyMdsBsbjfSksr5QSqROqTAIDkvMAFkbWTr/U1hCR+aQbDSvIjhcix6FEWingV+/VFvMw6a7v6Y6YJRVT0hKUCC4" ..
	"kzaYJHeyn6Oo9s/Ba5M67E4Y3BQY2GruK/SBIBx8SQswhkTFywK7AY4e6RClJr/7b2jkTQEPuOoJNr+5oSnS6HVZBii++B4bw5YF" ..
	"UhKlPWitZMxQVaHodIBUGkM9KGLk1pv5yNiZShiLeB5Jttsx+5CkL/ldVlCFPlx4vcWL+WWCkQtOlyqEfPwZk4fUbzxa2lYR/QJt" ..
	"OdK9L1QWULoiqB5jRKUAqIhYNvpk98aA4J1jldUVFqYfuwTo8Qug9qBO0p8+iqoGj6XjaB8Dd8SzBe7EzuJqiDXJobIomtGSWsL3" ..
	"H1xAKYdfaFoEEQEmbWQyE+q5KT8NlWDNAuOz2p1aFLwnAV25EM6rIQwSn51p5zUG97kSJWqK0tIt0HEUqtrSrc1uVsM373cMdQHM" ..
	"WvAfWZuBLJP55mL1D8Z9DQyIdW0KvYUERMaqLzQnbefkOfgin9alCaNGZKq+Zy7CWQlQD/F+dYJxPPHEPhar087jshCT+wk4b+L5" ..
	"FxSXzgiI7vV25NPvl7AV5737w1jIGnaZibI0LTC0DmVZw4gn5v8Yr7nbf52gW/Xk1CTFLREoXiElL2iDzdWrNeVrvZubmS7QtgMb" ..
	"cU6sOr7lqThAsqglmQyfhJ6QZEjlyfK3xZLOoQHOhq/FKNQe+2wVuXhYURdXTK968Km3O7ieBf72va8QGbNcNhejcjQ6IUExd8JL" ..
	"te/LyVboy7lOf1Na1U/PdG7Ira+5AIgB3FAw205fK1y4Lb+SDUC8GQeDiIwX4Npc/I93ncDWFZF9rBgnuC98SjjbGz8/EIKXn7Tb" ..
	"9F5I3XPM/OXX+ShCIxNKXYI9EsfHwa5QJKQyxsV0Fx12UEK9MabhusPXmo1XT/kauoaV5eI/Pk/GGu6ev7r4WoocAhtb37cgZPyi" ..
	"d0HAw0koKjIJ4NqfpTymsBZW//rJ+odvj7Ewk+l9WwHGJ8+14GIVHhazislfrnHgV0UyX2+UVK/LwnAE9RnCrpVkl1xVTwZvw7Ks" ..
	"IB5ctq1eYkg6mij+uH1nyCw7ZFyoLSUqrfVOjla10p7By5cFz1xitgqnRrzpHq+0f6QZNzGXuMAj5mgqHzCWcGSrcZpTZJ7RA/9J" ..
	"9P2BJN6l4bOfoqLGwOnkSxpzB+7xc2WwqadLHlOqM5APChXpbfumTHZAumQ1naMqlQexQ2YCjx/1ISXC0UCfUsFDZxG2cLcnA/Jw" ..
	"o0w3rHsHo2e+S5iRDr8NdgxtZgXF2+qzq8aWurzqJ5gVOistm5AjbnwQ4OKMrZ40/M4PZCR67iSx5JL5SSXzDnTlc63Dv67pDCJu" ..
	"897/bMAvCzvQCgMFVVvcrZZqTm3WoX0j/o/LWPvmlX3Mgqn+SsMQX14HGbJBn2CksbeN/XiV9D6Xc0YmZd/vInzS91Z5z6O11N74" ..
	""
local PAYLOAD_P10 =
	"QcVnk+1kVFDHz8to4lxgqBn6ueCuh85dpGsBzgNj13OLTXin/zAiexU21FlUm7bFaB0nVmxl7AAGidxDYLY7V6f3oleoTuoyyqSk" ..
	"M2zA3giQ2w9EdMTfVq4EetJ2tmeGeLEK81u5VmcLK80RAezooyt9sX+JuTxPniHq2cKrXhwVYo49gEorhWzFaxoGybE5etQLOfAw" ..
	"TMKx7Q28jrYzbeqpK/DU5fhLwi3eJCzbQkrjzGCUKkH6xMk2AHdE+dplaqheup7g9XnQJXCB8rpYFsg6Wkm2n4/qylbsuCZ7vrHf" ..
	"soqdTqd1mteetgZFZPWAN7Wn3hIZvAY2fqQxQLpGg/rD0u03gUn6SZ559xN9yl8ZuXmJit9wr2m3EpGQpsZM0ujRWVSVgdTwFj9K" ..
	"fKVzUfNwY/LNBV5Zr4q6Qtr1400FlsRIA3/Ry7CfjnldXlQsgrpTGiJt3LGYY+V2pXXLb+lPH9ypIzCUWPnStnX6F7GQ1+12RTyT" ..
	"4p72/3wpyEVn+aJuR4bDtL2LPcmzoRKJuiu0bQDUd3I8uOgQMoq2SAL1kHVTV1K1msHsyQKNAn7hWbDmK32Q+N3p4ofjKBruqb6e" ..
	"7DWE2OyH1GMtIKTqnRVYuoVlHuYKdLAaHFLQs8eEGjgA0qXnOv/4kJO4GxjVdpTeXch1FIY8HzeD1vULcoR5kQIwawoDPf5tPL4d" ..
	"ICnfNrQRSQ5Rrltd0UvdIbJM3A7NYWAJkYTpb65i22oI1unndq34zkx6rumADimP3eiU+IPWlYs7RILLOhkFFp4492FZlBdt/Zla" ..
	"wyPAVWE/KxVdD13DVrJFD8532OD9M6FC8rYwGCp5mdEnn3ICHnzGn2D5EeMOfdCbHFym40AfiJ625xpH+/aMD2tkWclJtfqqeXlj" ..
	"/rMO6a/LLE1vlXOhLWYHBlBBM3/82cRbIGZTjTF62cmGfM/HqAVDkWpz8psZp1EtBlky+KxjrZgfITpgOI7GHOmtw1gylMj8hkva" ..
	"RU0X6Ob6uJwx55a3JDnOPy9y/X9ieDvzByq2gS7E7HwC0mrNQ7+GaQ7HPqrt7KZ2347cnq/r6c6pScGEFXEDrajIGYzucgZgG9+U" ..
	"EmoMdLAOwhmNDLYowcl2SK+Cc0mpDBfia7Nzm2N5at1+ttllnaQdD7ARoVlTveC9rntxAF05wgLv2BVZn8URbHmZOmoDk4NDEABX" ..
	"92swAyyYQwD3j5ItHVhU+0oCEVZddNjuNHD5eaTyjDuv8on5vHukowmANI7VJcBXatZMFOdSE9jqiqv9toDv0GL8gPwq8yx5Uwq/" ..
	"0fQPtE69lf3TH1KyEBbs70t8eEiNb2p+u+jwnV/VHYDOOtDtW5K8qjCW2/a7GvJlzrm+zKw2Pl4CsEVO78JgQHQEeaUSorqZENqJ" ..
	"WTi+Vi+Y9RPBtMUDLU0P8ZdTDJGFVvuXuadM4+w+8GKC/mIr1yNQ3MyU0BOlqkkU+72HUN85Uh8NZwtlX7J+26M4x2iKjM0KiWlJ" ..
	"zOtQa4nT7oCTe5XhQnSuvyh7JoXzkVwqh0JAC5vzc9remobvph/DflMzWnqOX7KIiBQSV88juAdrLa5u+N9DccmyRyEyWOs1vQuf" ..
	"2PlNXCmL2YIVhuzk6bND3TnvxS60Isc3Jg1nzR2vYH+hzjgJDB2YSUCeoe8InR5oDLebYUoARQFJuxGqbJSW6aeOI9AfULDtHdEh" ..
	"gqw+svfJxMxsqVRqDdpzkvG+UswUEnB52nKBmyyjEvgomrs1JjORHGQtRivgbgbnY4l7TSV9xu4Rq6M2zvLOTrPMB0LVAx1a3ihZ" ..
	"zBGJpiur1efCtvqzzHiqbPRrZehyj4fiaRXC/UeOeuY5ByIpmN5yHbaVHEBwCHS4maTxCvi0A8inSQ2KEb6LhQP9GPHZZF8BtX1X" ..
	"5LsMB2ZanTnbHgA8wMs8LhYx+K5sfwGozi9zy6hoGgUpk+VZppvtTXi+HvsmPFo9M4XntyNrrNaxMDkt+jRtGdAyRhMLRKDSCJPB" ..
	"B3YhgBX2TZNkkFG2z/KAxFQxFug1X3NfI0LEKEvZBtYihC6lWbfm48ZAvG2uMoEEGKy/AOC2oQj1NeE6IfBvymOOkTPGcyPtcCQM" ..
	"9vFaWGXUwfgzsPURGHiJklSMzNmfFp/fotrxy+L1J0tiVJaRpleMytZRNpK+hu/Ecnm3BP5ZrZwy13RQXE1RvGsfWHZFc6wvRfMp" ..
	"2UYFvfQUGoF/bnZlcfifvNCv2bl/ZSqsoOyvJmb+1EF7vwTrlzrBWnWIQOKzK9arYRVUzPe4p1b0TupM58C2tvUXgOKB4eX9/YBA" ..
	"PP/ICtaddZ5kOT9x/ZZATjdOqhxx038Cd5/R0ybLaI46Nh3L+sTAY2MSBxmy2NVAt2UDV9CrmwahmOFFbx0uRmATd05py63JRF21" ..
	"6uE9fB121SUn/XK4sFqU7RxHVqL93nHOzGHISFvdkDh/kIVmGekg7hGaFad0Sl7NOAF7+Y8pVPA2pWzYIP0OhH+zl/n/JMeic8yy" ..
	"rSavsw4zeTaNmMEieIB4waWNoW6eMzrulS0Yf5aRPN9WiVCzwMISLdXhGKFIS9ccOWpg1XASwxQFG+x2CVdHpJ70P5/Yd91pUT9k" ..
	"THjcojrTbqsP78fpN4eq8rqK6RY+PwchGfY9h7XUBVmGhmsGe3v7GnESFzXA68UBs+ubIFkC6Ftse2gEx9fnye5OjxHsPGxgvVKy" ..
	"Rz+nMIJFvccunk5UYbL3ACZQajcI+m8LLXmLAay/meogPwgijBGJnDizGZBsyxM69hjsM9tRaKl1HmJdwGLGhgIdVs2Y05QhVzAc" ..
	"kDgJ9uQJTOsMB/roqITK3CwroRTrNztWRAav59m9ggbpqY+DwmzTyMiw/plGwx9nzDdanuaA595zUsXvIbolzXQch3OuRQzQAPxw" ..
	"4tQmpU+gncVRQpB1sDg3mCzilGyZ9SYWTXh8cucGCVfMs4IhnlHnlxbEdj6+J5Jx4ugiTKi+CxbyHDhOiL7mYY2duECl9IeOWJ2u" ..
	"ORWo20hqOKyMj5cATin4GEAVGwdqUaUoctzFXhVoA9MokPOhxzN7Notg37GCOIkv7P6XhiAxAnwKMkJxSNEy1YFdOcygUDnmAn1f" ..
	"+mSJA0WJkoW/FJOoAC/Gjuj+EpOoO1Ys9FpV95v6dB4XtlhCMYPNEzk4Cpgdazo1N6FCASIDuL7SLKWpJG6rFIflENv+VrrjBZpY" ..
	"Tgk2NgsL+KPzZyJ48lWOJX/g48p9kDGDulgaGoWYRON5+cCEwajisI9yp6N/17KIWuQMl1x5SIWo059Wbh1W7c1HvDCMTJTj9Fuj" ..
	"bj9VQ9z/7HIZT0LAkm39DoCNzpjb+rsfYuC4/VcBYOWGx8WNwkhPuNfCANNp8QkezoV+y+a7/53SZd+3hFcMaPMvTdBhgufi6rm+" ..
	"KErC9Jt2oQ2BFWEl3RAkD22yLJtr0F31Am5prRQnDqB64+qZ6Rvyr55CkTQljpvGb16Yxs1S8zSzEXeF4ssu9S9Uhq7f/qk5cCan" ..
	"ByL2jD0hQ8ZtG+BPYFDC0Nhn/IKvVcN13ERKv7u28HaeFrKHr7JjFfrGeZ3SjbArh5vhC79lw544NnSVZx+0P1UrAwCbeWgxWIav" ..
	"CGUAi3dH6Mi9WIIs2KlzKIXD+c50UmtPbLtgRDx3X+QEx30H0UHzcZHjm+01OHAW5EAudLjlT7DhxNzi/YoFF0PSead6PhuAyNXo" ..
	"evboTZ0azNSqjLSmMoUA4OmkiXHpzveqWO6k5RBkrK9zyOpp+w7blgWfN3G9kTVoH0/ESKUQ25vjUNo6moCfk8XSHYxLURNFpIS5" ..
	"mJ83eKHYPCvh7Ymvr+HAZL0siSLsoioTF6RPaDU9ECQgIagddIK1mtgH8lEB8YHdGahQsIQfY/Nvyy6lUE3HLQPWyZxSxhLNWfHj" ..
	"HCOKhL1lPWrNnNbefMl3LiRxdIUn1B1o/pZ0aU0YtPJw7Zb+3Fdzk/Mrv379t3/PBIJ4j/1BMiYGSph2mIMibDGLukQIGkWhzwhn" ..
	"UW2Oreg++nhMRHYxSiZGfoa5IAOSyxFqvcZaGoB7kFZcbmteL5q2xoiJonu+9lbbPqICC3vAeQYoY/H1bUsSEN0FsF/RYgbVRhVU" ..
	"7495Y4NhjxnR+iKI064SoDFBIz3PuITZEvvqQCtdfPRrzD4qSQ9yj8IWXau1eR+/AKpfZ3argAYKVNCCnT9EjsTJ5w4Igb1PEhOr" ..
	"cvj89dHXhsWMDQ3OzvNrGxOB9dh0lbM/Y5Zk6odM1uiePNtn0fb0kVVnPeP2uCvX99XbRQhHm6kBq/gVYMSsSLSJVMk9DGxYIg9n" ..
	"k/jpk2kblUgczw51oZCn4jBfURJ5X0x3bHH0JCyIykrZ/lkvs1RY5ktpIX6NSK6SKMZwbbYOPMD8AwSES+v9yNhVrNu8zyAnxFEi" ..
	"STzxyp863aMQmzOVDVyQ1mkrFT2yNI3LnqsxOiQ6q6qxKtplS2EwgTGUabb6VFc7IZ4SYzj4eRg4s2aU0RwOnmZwFdFm85bwkz63" ..
	"G8+0WpI21a5pK5T1AY3E3sUk5L52oZYJRSOt6dd3wpJ95L45RrLZB0j4glDMv5VlxgymLEzefJLpFdVEWCKG7ki/bNE5yNuY2EJF" ..
	"YuRKuCuSOTA9oPaWKngG50VtNFTHwWpxDMYNf5cxFYvGuLyh73TBk7wfgXKSkDYULPJb1HD/66PAfnZ5RyfeOO2r2pY0IDQdU+sf" ..
	"svLyykQImB7DxnzV+sKJvvSz0pK5Jy6wBXCCvs2SPZpHDyGRDedOsSFputl9q6xi14Wzb0EKnYiz1uDdEb4FNF3gH8+4amcOKuG3" ..
	"RYb4wEwxLnor44JJZnSO2p0UNfrXXhllnZI/csAcHoKtTVRCJ8UbNuA+5vZuO7ixdoLlzd1XIYGOO5iE584gDpbjMpePKFdBMXtI" ..
	"+lW8oiQCBpRY5WXiGMjUMGLEL6GuCgoHWqcyH4Yvc3ZoKfNyErkn+wYtTckd1pH97pAUyE7ZkuEeq1yP1iSgziCVvv3hH+qf2o3j" ..
	"uhWw3kDIkoAhmpqCLTAaoZ4g1tdvW2pGyGBIoeX4oeScJag5sAYLu175/UNyV0pxXlWYxT6LS91CRzpoQbshztTl9YB+FT7Qbp8S" ..
	"/ivMCsKv20eLanq2nglx95mHDuRHPkXDRHLPpDe1nNeR09y/xN8C3S1NWuBn9sZOMajiYzOwmqmfdnuuUlNmYen4BdWvMXkfth0M" ..
	"ufqO3X0rntvQQMd4/6zblCtWYEI+Gl9lyU6fds1AV9UOGSW8yNzG9Dlccc/UxSJATnREhYsPG1oJlfnSPhfh4qLnsMsZSjvjwLby" ..
	"4phWFudzjKUXx907RowsfhW3ShDn148ZVhyuqkHs+kpVEm+Zjo7dE6ndQajDZt7jsWjAcygMG4jnNnTmGSUxwH5JbE49q3nN9Pyt" ..
	"AuKtvYXNjPbTF7dqEDpbSRQXsWJOR8XBwrFpwUuHl86ahpt8fqo2sjNL1CMwn1iYX9++59jHUc0zeuryGRrigPpeDNNBnUSfJ0az" ..
	"EqNnl4EE4x+I8x1ehH6Wfpmy2UZiRfxWmmlvYFfOu2GJeFygUqKYrs3MSzatiGeO+8ivGKpCx4DIG7CzlQNomoIrQ4mFJTV6xh7k" ..
	"Uy1WOpjbxzbOANsvTHqgpsn+Et+gqv6WxfbYxEBK6RO8zWlCLPbZ5HRDmE9fEYQKWRH/GdlKGMAWJsgrmJDIaerGY/ijkD6Kg3BK" ..
	"MH9nE0+YL+I2odza6fwBa9yfcs/aO4IShEToo77IBw8ZZz1EkK2ZAU9wh1UVyc3uKZv79L48z3xe/U02m1wZ2/o/bWeDGXVD2rrj" ..
	"NvFatKUiPZ2+xUqJ9KlcVx4id69ggBaDj89D4TlYcTrwccolqP9SVStLVOVQhM34LbLGghKBpgj90dOFvcteeou2Bal3KkoyP+Yu" ..
	"hI3XdaVLS0pKWVk3sghaeior3suHnj85TEUF3tQYkd2MsytDT3ou7UhH2uRN1+ho8CCbHzz6ovVAVzZJN0S54QblwGtXFCqJlogj" ..
	""
local PAYLOAD_P11 =
	"j6JOyGUoi5NWoWiyziIMIC8O+/uk7yR6DV/y6AOHFQy5q5HWBppervkFa8ZHdS/NdCU08k9EpCFaO+K01lbPTfxU4BKauTTXdRYQ" ..
	"YKnTtR9Qs4Nz5PQJnhzVtP04T7UpAwmXIhgBigxYu/aRBTcVhOGqr4aMVt6hgwQkxDRZEYuk4zSqLh5BVWIHGfeyBTv/groSUjFq" ..
	"u0sqr9y4MC1MjN9eeiprUr7M0qIoFs5uJlpH3XR4iIK52Gj2sMqV34WJ8+/lRat0DfGIm3BhIHS832cccpfN071ZKXdP9q+FDKl8" ..
	"XCW+OQOBn0oh8nkQW2vQjEB8tzh1xvZl8yJLAsulrQaJGwueaOq6caQUfeJgeveyHvRyQkrqGmoHhnppUOxtnnE9YTwT+8x/sxXF" ..
	"+0ACX66fvrA9+GSuOwGkFLaA8oNgAkydArYuYy48yQt3UPtS9GLVIcTi4bz2QmmCx/GDrs9n+WOjhqtDB0leVLUK4YWY/4m5nO+7" ..
	"ZVFrLEmrHB542qT6aNPYiDonysgjhDZqKhcbHo3UhztfgP+2519e3bs+pgLkJmIvxv2I5uq63WPpt/euuRwmH7vDQW8yd4fo3N6q" ..
	"U5l1JAl0JKezIq5oa66h9Pkxj1DmWiaCzz5C6x+7B5NToXAo72HK28RhJZ/vBzeyJB7uvqPbnF4OihCsfWtgti1gKoZk5N3taa4j" ..
	"OoQdgqq0ZTG9TBvAPgCLyE05UNXPxoy5Vb0qsd5IJqeKXZ6fBmQFm4onuB1oh0iBhZMoHeURGSnRnNeq1TmbXQS743BkP1pUcVCD" ..
	"KSh6EZjeuZRtiIFRrSKwG4MLeYl0x+4ViJGaRT0Wst3xYTGZsO5WnzAnzscMtRxjZ1pH8khfqBNVIqqyKSipMhxO1DWBkGOlm7wq" ..
	"m8o87t7YL2YJUj+OgflotpA33FRB02gjuBH3LjahgXMOhdiFyQKmzitOdUiLHnGVGZEBNwwQCJZ6pndMsNBFnselUpQKRnbHgEFf" ..
	"HijdsiJUy6/B+7IcelGZaHXu+8oNrwMEEGXtMqjW6zjW9azOR+iyl8iT0y21pQWivGsyk34f5cmsYegQ6b87va/RYnLvBC3LqcG/" ..
	"BK0uU/eLH2CfPOZo0y9aFYxrITSg5Nh3BQaHWqh6js1+h1XCf9OUhvK+xnkLGY3DeSiKw7yo4MChuEBibl5AYofnMpuG4dQ1nYtX" ..
	"p7Nr04JGdN93+8HcpB/EsmAoyMrqJ3drF+SqBzu3cp8CdKT9AL55wQfun7wmAutTHlOYkzgavYnUD04g+MDjxcmdXcn9WBZEaEtS" ..
	"2Id5Pdzp/IN5c3EAbSDfEqMO+CItLtvQwMT/MK3bEo0i2pQ+2jD+sf80atveFMbJ49/jnNCmjoixXaaAHhyGXzW8HTqmOe+g/v/9" ..
	"1bz3Omy7uZxnT9aqqHk1F2z7DC2f9Jnc2+C0GxCOfQHQUpO8JG84Lmlkapir5R53eyzuDp4nQ68800llhYrT689YScRFYUX3Lc2a" ..
	"VFPjvyADRXPpxaOugIxnylAH9wKPbCT3x+CdUO5zT9JMxTYqHQDWGHrUjl4peZcugMFdLxhm0gEXUSkRaf81pL/GvNfuDFVm8mh5" ..
	"VAyxMPIGIO4Cjg0/oxJvHaLexZNN54Ba1522WFPaqDQJ9vP303JxBfJjuJ1KMjkGq5yvtg+OH8s7+ZEIgzNMN6AMxlMnTATNT5iJ" ..
	"SQLCpPXGpZrn5LnWfx9+LwJ5wYqvnPXeIUV0pK8+rTURu2yI6SKNsINP+CPtGb+k7Djh2bf2DPQ57ZAcufoDK5WkER2hfWhY1D0B" ..
	"d/gtxV1VRhwJE9aFg1EF8VdL0Tlfx4RtLnpUHfdLt9XNJojvfS7Q2AMgCaFzb5l03IThSjXNvbcR/FwPB7zG8kWF8XfjwRv0S0X+" ..
	"KGvuRkTHccs6Sr1dDphA/4+/iE31JByd+g2fNz5ITIMKNNfB58mm/Ob7fmTXpYSQG7+oWuRBdEAX+yh4cvqNY7FpQQwNcMPVure4" ..
	"beK8TG9unWVoJhgn3Y4wrXmze9bVAQu6wAT9sa6eLf+1DYrWGo4hv2SdA6tg6jUeTFg/2DdoYCLTpj+Q743lBZ1dnIlu7bYJABzp" ..
	"MXn5wjGY818o3Mz/9NK6Z5sDK2gZJqac9LPc8bZ0qoXAlZ14bWvLIL6vBNTru4Hw20avJIHsJroDIuIbn91T/0plhC8+xtawSeAQ" ..
	"HQhPZbyneEGEIgD71px8ymlZsRxXAcI/K1Ie1p3h84ww0/NXrqKxyw2y7vryVQpo8AZDTNsEPclNCX1stcyvRtuD1D/SE17F6Lbs" ..
	"DOKC+FeULGENKy0Xkr/laH9ASBpDuHYCSHNXYawU+FhlPEznL3IFhQMtUwnqwbitdfJwd3IDUrtwMs1FgoBJm808QXs6ryBCTMLF" ..
	"FMFgFbxfcgojMFKR+cuj42NptUU0p+Zpws0oR0HJHClW6uzDlPCT3yg4io/eAPgmoLds5wV/Klq/yzE68kYa3wLF2GLmTQqAZnbQ" ..
	"wo+Hyk5rXGz9KNBRpKTcTlt7gdpAtbi+OVhyjuVUCfI1lEcJwxV/tSRc0KxuE2e3UBFLYKshPYohBKFmnAgholG7yp6nhsyiK4Bc" ..
	"RD7a0+3LQ7cQa+ZEcx/XkQEipAXBWjFRUEYHePlV2epWzgWp2eJ/c+NvFHvTk1CnpCRcVC8V3B3C7+Uc316WmsbjUjDwbxNKPmDd" ..
	"Ca+/82WZY9rDZyL87vLj/H0+TbAJ8QgQ/0YFOzyfqAF0hpkfbPptfPN/F5ffxgfhbwWp/BGRopNBquF1jp9Xyilu7836oj5HpkKT" ..
	"JjoVOWb4wErmGIjvsr7FvqdLcCFwwc9dWxHtSZzZHTw55eOXYPPIeDo3U2S/i3gqAOt4nEvw8D8+qTzy6e4CDU9e1YS3KZ96D7vb" ..
	"Zm5RB/yj2V19iKreErno/0UFFBGUZwVFqzDahgg8FdHEqlbofQ5BF5yRcvH8iRqcT5btH/wS9TRitNgTrti5X9IWZgN+z8L+5/IE" ..
	"JJsrtaRrDpfBLF5tihsscs+Vt0XNi9JIXJ5PDOj4OLOxYDxr7yFt18sO6LMUPk8dSwfqO8s/Futq+rmv3TwzPymehLylXbeu4YJl" ..
	"/IliNdUGoatmA8x9B8A19RqJ0m13NxMXP6LiU/x2//3xLkp0YAHDHvijwNjeUd5P2w3AqH4ME9zaDDZGXXCKrkOfNwirg1lMI3zn" ..
	"GGI9Tg2vy1jYkW70NJwC1I35MMQJQ/vICG3DdEUij8nse6P22PtRWjFQDf8Ci+2LNn7vWARq9T9E1vYcfPHm9WrJ/ENBmlwvql8u" ..
	"sKPUoqvbJSVvXHlm6EznucuSj4ip/uhqCxbTH7FbsZJ+xAdUQDJBe1vR+wQ4tRujsWK4Xfjm4Oh91os1lEJ9XcYRFt5/eTw3bKjy" ..
	"jhNjgxAu0iHdST36tqExbczcM3TUl6/uDoI5lw0zk0aZMxnNzcOqQXbfDy2OpirZ55FpEKLoLAzG6F/ygCSVwZoyQOe7Pl7rLguq" ..
	"wQ9J7d9Zt04L/JBo3vAzu6Qb6fBAF5KyO/9EorB+iqYIPUxhZwkrB/41u6qsyK6cQhRlN7K8cWcbQKwQYYrtaqY5u4ZSA4mcocjm" ..
	"jC4g8DDbH0HJwAXsfuV5zRfsG7yFeuqETk/q7/BQIcp+rYJfis18Z2jn0EPW+3nplJfEobg8cPZvfFdS6466H0EgHVh7a0rsa7n7" ..
	"BVhNupkm+rBEV36ayYM9FUPwe/W/ePVNvOV0vaB2WMf8VwDLyq1tRKg3uAQaB2ue5skhHBrtiWVSVTHNQnEws2aOuFQSUaJBOz9N" ..
	"O1uLymjgUOrHBINA6PIJY7MgfRJjyrb5JzcPnrmwOBWH3Qad1t5zpF4/2/Y8PyhJStStpTN1rjcw+dULqdLANz8eczV/OSXDTe4H" ..
	"lz0iSACyaR0oXojM10KZ0mXvyumZKQXuL2isF7lRWTCw7c+sCLTOIbnJhB3jhjDkBG4Sv0L1kCxImWp5dzFBByB/m79bQ4oapUDd" ..
	"iDp/dgcnrDW8Pqcpa++hlZsyNE2sL6k/Qda6ObWOwRaO30QKI8qEJqPJI+umfXz0Z11eP5lbHDVYK+xFb4OSubH0rtYVNuDlopO+" ..
	"kqvwu+HBe7OA4Kp4eteBd0ys0mJHvcbp2LwK2avEEIg8UU4e7S6gFqLcx8nUzJ5LHpu+kROTCWeRaz7dQvBLvqYP4A2Tao5w1fw9" ..
	"neJK6jfPFiao9n+Dw65JRkIIPmNgPFx8SoG82bR8/qUKk33GaidApNP2ukBkak3WgrwfxOaUg37w/G6eyAYiV1tpXBGKd7v/BBCs" ..
	"cXLeyEXczWIZYXG3lNGPuYIN1RD7BvFTOudlR9XwkpL5L7/heTY5zNrm0E/VLU1oanfqnHSrCre4KYKUDy8E4m9QFJkKL2ToF2bk" ..
	"N0K09+RZA9Et67bKJX2N+ZtxfSOu6Zu4oR33NbXMXina2aLTDa5Iy33DjyiEuNkRLlwIqS6dfPjxLY4WXTxLAaTlTgdFT6nhxyu6" ..
	"PZAlSWH3SLjQEITnOHZ/NFZHQ8kV4RvoN4B0sTdENyFCn9MxnrM3AE0UKHycaNNoq28CfzziFcthGkUrSYatpyWLC8+l+rZB37AT" ..
	"xFyVIVvqCJXUAMdfjCJGkd4PF2+g0NI7jx7FyLdPhUcDojjJeYKKb49+HRg4jAAmR1IdtBUpcvjLeAyfjmC0GRNW5qkhdXMwJ9Hb" ..
	"OCUVMGT7rfbs9qzkhToVRgy0Q/KkGuMAOw8ohnNXp1WD2ROW8dYUuwvZJ/CXbHroE+a3xulvXvcVxkg1NDZDi7UBqeT3B7d05Aqz" ..
	"LlB2baKvMbolxatwvz7SQV9MiXTuagNX6gKTT8xuTaNaKJm0Gs1HTeuMaSFDxVSDWsQEJJ7Du/bMGXynGrG6ULB+3lKbn2nuBKhK" ..
	"2vV73UWUPhMcVCID/Bjrw0uRxL3fpVMQ1KU7NZACNypXDCHIs3YuX2JVKWrWaRSwl/oBE0/wZ6sSbfwmJf/QG5X5GbXRQ+i6OMK4" ..
	"0bT60VnhiEx+MkeTJuQmSiNbZe0musE5QfBVLzqW9RkXSiEomx7WolWoHZgj22M19nBr/zL5ciXEvxsS3/1hP0W0x2creLVcgrZl" ..
	"mdsg9rVCPms2iZwTnjUZp5ko+93jGbkdXttEEsLCoAGtaVom/AtRDCe6JXS40euQ5Z3uZri2YgpUKGLRnsHR06PcJTBWxojXTz/I" ..
	"ST4t3mOsk5zZqlS1ioQFJY2kfO3+VxkeEQ4g6neHt+9myob9ZDj5XxRqPART5uIf5uL9HhTZ0dYMQ4mmmUh0QAviB/AvlluOkYGi" ..
	"jZive8rv91/SXs4mZTm/k6jDeZDZKJJNz2cdjzU6GbTV1xOE1ZJDCVCvSQ1fSc8wGnW5aKWOv69x3LDnyEO+He/3PZ/3OtIJ5IdI" ..
	"bdVu2l8zDdo8eEKnH4JXkGJu9GvVraNaQTlKJ4LV2aQGyTCxr30aqK/pR2USkIZ8DDEXPn1fKBrLrjK51hVLg/zRxrOQSAlLOsbx" ..
	"PpLYwm6k0KCbF7PhDMvYsfqnyLKU9rlepH91ZKjvYlvmBoSnsCNGh0jL/kfEn23VT/AirgsgRnXpcQ8SKe/n9YB69qS6IYm8LKh4" ..
	"pORu7iCjsiClKl7xas8aBemDPev3MWMUUwO2TQnV9YyochOEfbzkiU3wu1Gh/PVjgYvsDWoAkdymMbRREQi+v0KiLSsiTq8OyjXf" ..
	"bWaCXfTAqkDT5QMNQS4oN6rlQXv33WiyTdsaYx1S3etF1tP8LG6Smgmd1vULEw01A2fc9uYKRwdkZtf88jkgobVuEsB8D3b5BfJd" ..
	"02dscpA3KdTHfDX+FKfxspvOk3IlsJ1Fx92Gmweh+xKNAJ8/PkQz30Y+k8/V2QLNd1w1wwM6Tobq47jo3L3PZMV/qk/9J+ZRBTm7" ..
	"mxZ5bwrrBNhMrdybHYXmsHpz77hTmOnsFSxYgrlFXgvGt9h6aeZYRQAQ6YxmVahbq4uVtpLBuCoOHPkuASuIk/StqYfC/nOCdYDM" ..
	""
local PAYLOAD_P12 =
	"+oZj5lCPMnrOf0j4BUcqi0OtpIT1WB3nG3/wd3BoCwUtwCPnpjzeY4ln5nDzKCMmiyW4zafPn5F/hUD7U4W4tOQL789XoPywUtwL" ..
	"TzfNjHJfqqYBeJTyE5F58TSHNadE4A8mmKOiNN6gNvLPgphfFdctqf3Oui9etjH8qx3UFK79xC5g6mlyvAvrqGjUF+JrcBeBets7" ..
	"2OchmaeTKggndrJMmnZ3A3zwdKuHStAlpzfJYUCgvRMpgUch/GAxpwsKjIuBHsj7YMIRVEtW9S7dwNAQoUNNPf/fngiKGuAlPjQG" ..
	"TD/U6XLyTb1guD++XA8pd+HSUHKMlvwwtjKz8uQInXpckti8n2i+XJx80R/iddHS2xVHbDET0UdwjTlgFU3po7HGJ7Y8r1KxssEW" ..
	"B7T/+4owMaAoix30n68YckOEynYCk/x1zYODXZuNE3GGh7vBSQdypsIkPp4I3Pu5+fRvWDLmaS3Qih3yWuW+2y7RJB4S/EK76Zqu" ..
	"bwDfv47Nx2pgbBP31wqeM8Us1Qh4IKQvP2UCHK+hNQfKOKI1gQC8Hvzd++34dWYZ+uJbgAF1S/dmDoJ1Jh+21pJruTpbZtGIS/lZ" ..
	"12oesOTJ9ch74+TMJKDJ2/27gmXKQYmP4acXCzI15W64tywYGHcpigED1XxCwIOQvZaPvlTzttcV6xwYH+lOKeXGAuFnpSAFZR+Z" ..
	"M8DbXTkOvc9fsb+RXW01PkE7ngXh4EwphZOAs6eZKOrICDjBiYzHmeLK6RSeU21j4Ma/tYOkQB0oamoOnpjId0i8eMW5iVg2BL80" ..
	"8W9BojltV5uLx9jfVxURJ/y6VReNYC3zPJ1wZhbLr80yZnvPZ3T+WmT52A0lUI+yEAbGZaGK0KsrS14yhiGAUeJhMc+BJY7fcFqI" ..
	"VXFebzw+uTB/ZBtGsTJLEXfXvgE019+SIRDK0KylSh8N6EVk1Wc+1fLmunXxg9dtahceDO3S7upud2m18jpRdV89zE1XA414bhDV" ..
	"FImTkGZruk2rxmyHMzKWwoYVHS2YlmepK8YTXbs8Aq9Zj4jm8rIafrV1fJmdNEFlK2pw465qZaGdLW3xBqm0plSuaZl2L+JgJNVQ" ..
	"viG6Q4EJcPSq/eSS3K7S+u2rZczhweNobCV/0BBzgf8ESedlYoO1SNtVPv/lr2cpQruUiouKp5uVFQi12IFJAn7msz3znMADsX78" ..
	"0ifbM1LPGvoYJQ/ckCTg2zLXowz6RJoWn6Z1TgyC1nkdkr1UFYaGcdv5RU7CZOkGTnmDCY5YQjw54h842tKD8auirGEGQSxqvKWK" ..
	"gJQpN5nH4eyM2EkZTaq+RrsEb2ROoNoLTYyRN3ZRrWDunEdfsDnmnGgBjeY7x0AG/G5WirA8zdGTxxeuaRTF48RNAzOgcusd+9qK" ..
	"s69A9z9p5JG//G9+UN/2D11/VnrPJCH0GWEKqW8PntGe1OVSCdph03wp9z+n898WqbHFXVA1LMcJh3ypyZ2+qAy6IS+2dT0woRYU" ..
	"fuEaXy0mTmSXIhoBT9NQb3n8ekzSzkgVOao/QDM1JBT+zwW92x2J8KhjuQyhtWSpL50oCtzRcK8bchFYFqwyL3dk/EmCS0jDKpVP" ..
	"8JxlMKIiX0rX4Sx2/1kWcinVXbFAUB2pddoyZ2IHz/h6KH8pHpmB9g6ra2qW0E2gdvZETYhSV7FLk1xn7AuVLnSsQHkJ2eOqUJCU" ..
	"QFreA/PKqBuz/GzluW1+PxGZSPOVA7MA7AXwemJOYuEocH7Cz92ns+rnUnQgWwqY/y82aLzM5O8vVBx0Nz7MIOFG5Iwp5zJ5UBjX" ..
	"6zA41CndDkS28SyzqgHjczPiYXi04ZFKe7mVHt4AXr0EV6uY0JqaWYYBwrV27z/m6YP/B8QWNte7JSeLoSJ10L8R58x2xHFqzBpw" ..
	"BgcPDDihk2RyyPRHLZe853CL0xlTNYF71P3LxR9/EIwYNkrVYQ0fUCIcyC1KKrzwEXh6+BDc47FGSg5c+eEexV6fEEuTSpnGvAnO" ..
	"mQK+W8tgLRedelxaNXZJecTsaex2go+jEgMZrU7AadMBfUg7uMyYaQGynKV7aufi6h4EQjtJjLwpH3vdeBflMj5DecoMjn3cRIl/" ..
	"X2fq09DFmkcWF9UNhWDSq04c3B+1mhgawlrElWA87zZdgu0Lr9pSXvNWPNm8Zz/36EkAnKjZS2vVFZ1XjAlU4i4KrCl1EUnO5T64" ..
	"j0wSMm7PkSb68Qhw8SZYoEVl8Rcm0eJFgf6k8ueKnjNhCqJr4ocB2L+iHNK+66qQUQJy0Mj/Zi7kRBiDzv3VQUOAfZemfQ9T37A3" ..
	"/lU9IT4iH4SdwZGmcqUlYyxCUwJI/1tE79JJOOQ17Xe46vWLlWI6xtqwJG2QoMlPXmHQC1DfFYOyNvsUgK5RRbbZojPYnOvsUKff" ..
	"uTndBYzarpyjYE7NHnmAx9lh2UFxApncs5vJ4g0uohWwCMG+84I8U14T5qHLsY6qC10fkimholdl13TixdUxC474mFGUJ5kCB3V0" ..
	"+2BzFomSbs3O4loYAPzpru7mK44fOWzVl+w5glE38K1BBL4tIQ/zEQ45wW6EF39wo5v9cVd+RA/duKYGO+fbELzt4FlB/eABTtsZ" ..
	"aOcIdxVELS+KKYN4LCDfK4xqvuQHPlZUkZ+y+qGHcMLid8HPBbt6fNjl6eyKEF8LyIAzZtPDcQ55mIy9uW47RVncw1ZDF/GsxkXS" ..
	"6qcH8p0nAY03IaHv442RZyxauX61nioS6TzoZfVsIdXfHSG6xYP41vmfCkk5Kx25kv4N9AP/HuBA+RlDZRYE+Lst0b3yZ7m061po" ..
	"katNBdoL5SgYX0EAKgwlThbUT0zteEXRACFbv2www/IrSprDbPWVV86M3EPXZaeujZFgLpvHjYPsEijMxpObk81RLZuMXi98VBcD" ..
	"zr9fGi8rWc8ygMzEs3jNY6hB1hyXfArMzzuKRhrjMyzSVGtqJjvnHzgLvV75gNfDXIoYrAYsB5XQM/YXIAWbR224h2KJZcEeYHwL" ..
	"26YzicmDr6JP4eMvOmn4pZ2nDULuMZQL6rTvn+7DgPRw0wZ7TzV7HQIVx1tsFTrIT5C4svKrIRRUpx1pAWK0vA+HMDrnw1QQZ76V" ..
	"1+sz06gwVVf00tlF8zlg2ouDX7ubIGrguur5gDi5zAF/NHWRDjoRyrZYP2mt202QEiYqJ170RU+i2m4wBRCYSm2oB3JaGt+NS/rB" ..
	"QEy5v4XXuW5/vRCZo3bPIahcJ+xFPpbuJT9aXDLovwvqeQAvD8T71UOh3cYMzLdPwZgtX42+UUUZLX7A9yqoc9P5qhXAFmkADF+x" ..
	"CcnlTi+yZkEDJdD+0epYmfjHCcIrL6Sdi9VQjMFTGRrNZu+HoqDit+knNbaNy/rOglXZTv6GcRFsGD4L9dfxgetESOt0SObSavAZ" ..
	"MH48KJ4qXuTdKNQ9oT2kn6bq/mOMwbNLBPFy18Hw9YC8mov45EgU8GUPaT79XqblmGKzV5DuHG1IA663hqG9rd+w6Sdn9DlOlG1T" ..
	"mosQpw+KJrKNB9xoySB0GYAve7OzvImRIh+CT68gavkTH9Mljxy1Vb7TrEtRvNP5inIjSR9+/4QmY1224moXtVVdtsCgqCGyWYnR" ..
	"CUZkRRiFQeblwT9gMORkKdDX7bNnaA4MvfJd2Yuli2M2GQIxxwnWygzMPMYChCAeHuFnVkFm7hKEfALG3XaqcM58pUxIDuPYtxI2" ..
	"wb21dR/T4m9+4xxeXifVM5rlrVjoZbPl0IhMPiowzVE1mHZGHwUDpWPdKn1CS8CD52YCiIeKwmrS9Yyw4ab4C1YX1bLS//qA4ltp" ..
	"CrVmdGNdDpCSvFMUr6CVAtKHkmCyXzSdIXJrsadXX7+8o8l3uJZopTCYPpRXpRQ7ap3LXrkgo/PDk3ufW4qTP5qWSt2Y3IkAPs6R" ..
	"/WRkDealupLRRZhYYMmLwt5AUeTPDZisZL5dqilp1y4ovESX7ct8Ew5UCaDjPpLpMFPT868pLAErcdMwBXcBidDvxwfbOhztKZtM" ..
	"83bFfYd5w8iS3erRiOLNJobgL4p2QWxRGf+n2RdSe1FTPXzCjqqkZm6W3xjpvqqsARKdnTW4buj+knwYCfEIfAkfFZXRLTYmdI5O" ..
	"uWg2BUpJFfeOhhH6Fsa1IuMfV35fcE+B1OP8nn1y4Mo6y5y4sy+hAtHIzCUjQH01nz+2R1pn1u12/TAzkDVdNZWkp6QCus9q6gBp" ..
	"t5qqNh+iBFe6xuGO1fUyVxIM7xIuq2z7vAiQZoku7ChwDcNzeum52w7PR1e1Sax53fGZ7A6iTLAXAR8jSlzpbIfdZnN1FWasmlmG" ..
	"3WEEUHTc+jhla6df//dBv7UQtUvX3eU3bx9u0UFX5bK9G2vFN0sVk1EJStnpUM4W8O3OAjgsDNMbtPRxAx7DXyqMUTKv7WeyGAas" ..
	"r8EcqTQOBTRre9NxAONf6ZDqUB54aOppkpslQ6HRAj2VA6BjVfRpmwgTigqzxWikNsbaOXU+IfzR2ejlsZOeJs+MjHznKvTOuUx2" ..
	"xxZOqxrdIB/DsqejgFzP4Kx2x7sfeu8xo9eNMUqgKIvjc3W48ZBba+XD83RmWCdn/HZZsCpRBQ5B1WqhWJqfnW90XWgjpByMNF5v" ..
	"RGdXTlqPNo1B95ubT3fPXmAZ/xHY2BU6RGlEqpbEYDexrtV2owiaJSC+QOQNh+EL8xYQ2ZPuCKD7G5qNJs4tuMnIjOAInsk0g0Uj" ..
	"L6mIpM0CKqI5F6TOwqBCYmrR6U9dINCzhjSZNtA4MJs8st7R+9QgPf32MKjlUXiIsAhmVgInQyTcjchVLaNybUefHEy64a1heJsR" ..
	"SyrrrFYrb7+78orgF5B4eC0BuRxW43OTKOHGgL0Ph3+ND6lexOuA2SGC61MIBkbypeO4s1AHMSPlEyV26Lto/qIeA2/6qr8kwQDB" ..
	"iHAIHPUcNRk+GX6fnD9cY6LwOG6PzOgiX0EqJqDKPi5bLC73q9+XBFx27uaPDGMRyexmZ735CHclldoTeYxkDi1i0YIcqz9DOFJ0" ..
	"SAX/Xji15Du+Mi7mcu7QuxeSC1udSq+yA8ww0oWssQmRl84laoErtYxG9nvIA3N1L53JjCzDEfrtB6A9pVc96psoMRYbmKOvmrWc" ..
	"u2YOcqdm9SNRYihyYXvWFOFuB8p6utSwSE2pQeUpBkPbD7W0g90d+q/tlqKRykanHsvRyJWQsUEv76FTNiturzV0DjBQxSdciHgQ" ..
	"BfQHLhstKTAGBEB/pus6namF1by5FHA4ijF7uisY2xuTYHeAc+SaXVKD2Q7qy/v1KNGhw+pttXCEFuaXfKnkv6kaSU9MnvLrcV+T" ..
	"rzbVi6FDQ40eH+hWcrwlaYIUPJDyW+tA0ONLxMQJnInTeKtN17czZE1tyRA6weeXTp61bcczRcxOCH8DBzRaiRlxayWtJPSqp4NW" ..
	"wwstAzQ/hmB9nt5EhlYz1ggs3ZME/dQ3+NVPxff8wXjVPZ0xj1n2ObY1Bs/S9kQ/5wA33RxzwgNeNprJmdBVPLaIIRoFf0ccGlOr" ..
	"6zKdco3kOoewZz18cB+Y9ll2xL8nYij0jrIw4wW69wCZHzHfNBX3y9RXBy4Pr3whtTVfA52xtjfpo4nxf2Zg57y7t0L4TnNlQXNW" ..
	"5YgFI5eLSIBrBpGNt6PSTUyWPAXSHZOE8da4aoOBWxxQ3FsZGnr2JTJIcAKvPn9sQF0dQtkYxqIIn6PXwh4X2rj1ThHf6J+pE6ez" ..
	"K5igz9jaz+XDjppK/6IYNttfnYuhUHpTBslTjlquXDiZU4Kk6L+c6hl3lr2a77qggB1EgICyCuD3iclrHHg83t+lf8VpUiEmywMI" ..
	"LD88flqOMMtOJ1IO0a7uFbYq9QrmuS2lzMnda2440AUvwELTxBtC+TdSu1BPp8niRV0Q+4cWkGMcZmAD2wt2vE1wECRzFWHWBRI6" ..
	"kFgIMW4GLuBb7y6qypPiNqfgbPi/2yjAiEINms8rgg8TffPL08/JJ2dj8fyi/PVJ1iPR3LcqQ7SQv7CVOocOqeJtyZ9HwQBfeER4" ..
	""
local PAYLOAD_P13 =
	"peJeRbxCzURzEzKvUMKTIPjie920uVYFgKDb767MpxjJ+z4SZZaAcMJOHInv6lA+h9Zwp0vxPNqQlleYFFNGQ4oklvooMoUbhqPS" ..
	"ZS2ofZhfAK/2kNmifISqEZlWJ33lLc0Ih1WtmVRHlxaKvVp+s2cR19nnwOqxSHXqya0pWPzMiRE96NYi/de7WzU5/0bT6izxkgcT" ..
	"Db5sO1XtuYX5zKwwIdj2q8qIu3j4wh28eTpn4XWzCXg8SiFfp2sft3pUE/FdYBZ0Of90ep8qrZZcOtAnds32Z02ilAio0sD9pR5c" ..
	"OB0szZdVxZ+TWJ7ZpkVoa3+uKZ0cj9i50075YGAVjNFl58mAgyhss8VVgLAIc9D/rty9Oum9tWIJlX9tpcOvriKqR3lQiBg3/dGn" ..
	"NDu0A526lcOVqpGsr72yJxHyv6S6qe8UNpqGbIBSvORA3yL+NSBG8zghj9q5B6mfAoMVyWh4tZBKnb/R/zXfvpOnDg6E/ObfVjkO" ..
	"OvYivHD+m0J7oEjxBx4/0v5aGbsGzTONwUYiDXiPVdwcNkuNuau3tEVAu0CMKRLpy9FAAqC/euz0ZVu00QnpU6sok4mzFXQVOyJs" ..
	"tKm5Iw6XCrWOzojePIs0m8DDr+fulFGYktA9FjDsmTst0peaHIEfe6f4uAeuiGN+0qztEI1wQoe8HexDbTEZwxa1DQW/4vIdfO8I" ..
	"avGGLPvo625ewpAb3EOgoPbLsUJHU/DLZs3VuPbKvcJMIdY8Q0rSAsmsGM6kKx89XiXcklztOKfVb8PC2IlMVuujK36GxvvoazP1" ..
	"sTGijXGweqzvnx43rMGKnZaFOYJhYMP2clGU4kcof28Aj5TwuVIwNb6obwu3KjVo9+ANWlG/fJDUW4gHrBOmBv8uiCJD1/b/s03r" ..
	"waS+eYSe/d3cUmlJtyKA6WJm0Ddak2zRgZyP7MgRpss6nBAd273KgYI5QZ83lfp+bDJ/BZzW5t/YuNjYstwkVSKnRtamgRWfsziA" ..
	"fq6VtXVagdbJpP64LA+tFYFmWKIjVxARxkME4zw95Ppm+ubgvy2yFoIinLQBFbY/xppvcGiwsBpbFnYKTzpTr1nnnVFIrjHDRkCS" ..
	"ga4HXOpjIeB18qwwTaAglzfNGydfRvN+slymUpVMgOALhDMo/7zYQBBAzN9uZe6lTm7asu0ZjWEJIgaLC4LiVS3qNpjMSzZpKKEP" ..
	"+2+u8juaRdq91seiUH8fysQXW66Z9AEoMvfLN6ee+zr4dYl+nUNB5pGnLnsloDABwrIq5Bpl4zFaTGeuuUEJKoHXhN0Mt47qqEc7" ..
	"onneF8i34O/pr/ANG6Z3sRIPwzU9lp5Ry2RuOCt1riD4Cc0NCNtdpQo/4V64Z/INAJLsU3kh2A5Nea2QYJdw01zcqpNE4eHtQ8+a" ..
	"TcW6HpCTGefvHRJ2wvrdO3+CErvuVXnY/y+jWCeFsR/ogzuqV0iM/mzvZrSF6R2BvS8qOnJ3lsbvO3y2vJAzKY9Q4RFpIBBbDarj" ..
	"cCkd8ADaYHWbGlxDHBYk6IthmAzom5RRJ778966JveLyTgWEjH+Ah3tNNNa9SATBjA+QtEghtyzF3v47zBRmBVCgRsje/HS4LMDK" ..
	"WgK6HqbGb4LXwIK10Cs5mfEzt5SejwczqLAbVVude/ipyLiHY22Cvz3ElbWKw+7J7rtIEJFq1I7mLrH3wGmpuce1od18ZS+Kh1+7" ..
	"i83TJsqmOQmPYJ9ym9LgfvKVVBk5XqKTgx0rkFVhZr1+xmdPfn1SRNLysq6R3GJJvpWg/lIrg/qe9gC/b+f1wZWsxChVMbL+KaLS" ..
	"KgtEpUeSoRVSIRJOTZR2dbnPqm4LrjTJs2BW94G9jAcc634AqqioVOraFW1oxwp62ZaQSoOdliZaCpNzpbA+zB1XFF2YAyEtGuwO" ..
	"a9cTAJByLyoFca3Fw3kLVmdJkoyE7PXO82smSzS74KwPv3iUSiLj4PP2F+m6sDQb1m0a9bimW7CnFSSsvmo1LdJEt/uGjNmAPIDD" ..
	"R1hHRX2340TKsnltR5PH1qd6F5yiLfna570tCnZH43BqwBiyYFJv/dqvs+Rj5cGKL0kHgp0vapgw2NZc7y///7Nm5kH06fHAGgc0" ..
	"Jxyt/aEIWfJQPxzhdnc4oHRDWw2f2yl1NQwP4jmI2IHbayrRVSBdswldHnZVOL0PgdRztWSpIC9LusKxtcaMoq4yUc7wRRHn8YVa" ..
	"OYw1JRIFcfVRNRcl3QioXFvINrHhmBov6B4q95ZHuUycxgnk2jSi1jU/7/RoI0uACL4XeBBt3xiP2BDU9MjlnWq2oTSROo8sfS0a" ..
	"wajgr5LTpowy8w6sLJCPrAEWpAKZGFomBgWtxFc76qP13MFeQxVeCJjdbWyDxhtXF66zYn0P3xYMYZ1PhmYSTwdQMEdZcHd1/uMh" ..
	"tNjs8M+H1k3JvG+lSpiGGIN5Eyyp8NUmn+xjsTP8VcLyNGszvCUspSShvCsAGP9NbKF8avZZagtjndXGBabDDO52DsN/l02X7agl" ..
	"p+RoJ89aMEoV/gc9IOEixgt1Osld8vZdNVlUflyq9ubMvGogCYpXHVcoSiLDrRHWbE/ZzhIdnS53vysPjy5l5SWxQvuMS5c62P4K" ..
	"mBUVbzgZTObcYoDONnlTCbNCPZUJspuK/OHL5bDtX4DNUPUG+Ilp1y9ZhsA7pTJWqfpuzdS7Xgvz81gws/Qs8qpolmPSQpCj9gip" ..
	"HEILO+L4TV/JoKiJJnkhk+Rg2e3tdxrdg69lGCWRu6enDUCjq5+L4WbxYKb6dxXi2PQAK7E8ChbLlnC54FO1zzI6am/P7vgPUTPG" ..
	"hmdZq1UWlJGRqJViOv26Nh1O2oPhg9Px69artONYfdIqgVgT0Q==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13

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
