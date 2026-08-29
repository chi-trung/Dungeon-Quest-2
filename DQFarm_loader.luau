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
	{ seed = 2454325270, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2452776960, exp = 0, plan = 0, hwid = {} },
	{ seed = 2453343333, exp = 1788089514, plan = 1, hwid = {} }
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
	"gM6rXAzlO6Bdg7RPgekQ9Lfezldr72zOwMFSRh/uQQqCf8m0b7uk+tSI0+WgKmRqNzfDszwD/Y8Giciv05IsD8reECsEmKWn3oDG" ..
	"+/MDs004N0h2sp7Jxw4W/wAw/k9OeIHugLg+3xomeks2jLaytNQFvzEdRdq7uEStELNcdUzNipyVQ9GZHbFgsJ6vpkY/8JYs1dZs" ..
	"LVzvfWyoG/mkWXcPGuypNx8G1BEDDgQdzDZNIbcZJKOXtGp+fr8vcOKrloDkujtPZjFRFOmG0+1gN22G1dFUuIZfaz2K2zos4kM+" ..
	"YngN3R8sWeafLWn1inTqQFTL3oxTQ9hVsVzUXzGeJCULYbQjHfSUfczEyQugY0UB/6CsqfeBJHM1H7mBzXRt41eKHCXbmWdLRvgt" ..
	"a3O+jdKqNnBm5+qAcGEMa2WZ6nHUycjAfLp0pkb3OPKazS02QgYDl+l7+uJKV894pfkVB3xB19oFhQ8L2BQGXcvRbvTJ/UAdJLCa" ..
	"OoV8Xz8cuiGc819ONVmpPYN72yVoxD2Txisebkl05KuyJnT8UfIjmJ+oRcansZqL7fcZ5YgHVteeobVsweEHqqri7/TBo8ehTqLt" ..
	"sENRgKxBVD+91kt6PhLZN4RbVVnbkL5+sM6EXgdtL/W+RgKMGyzfSOPtaZEz1Ydo4odBJ8J76t7vdAtS9CVWiNV5QNUXMCZzfivX" ..
	"0IcyVH143OwL9JKRoTkccWhdPiIEmQ/8gCrvQyNfACvmiVbfSWwcFkoezFQYx/mzkjTCgt8a8CFyBLrwx3oU9XLBvCdKxlh1Hpa5" ..
	"8EjlSGoCRLVCORe+MGz54yyQFmA8m/nIwPX7Hjp++4Ci9QN5S4ZaSA1PkXDIXnW1eqYbSmoE3XhiTpIJUp7ulBXcGOzxPY7SQpZN" ..
	"eE+6KGttzAxDXjbFv2CfNjyr/jJvJgK4aBk1n03nwjaGx04tqKFHnXoY4Yi0hW5YRrjbqngCqrj6oNKjPZ6N9MyKF2+t+FjobLIY" ..
	"HWOOv2dz9vUHNed3p33xqcI7Rc5ntutcHikcPwnqpFvP+RGcAiN9/yft5Sy/xsR5Iwskx9gs2W4fYmZ7SVCGjq7hJgpbdSReD03o" ..
	"1UoHyjvn5OZk9zsEcKWWUfJB4XSyyXTjrowpkZ9M9k3o/3+gBm7IcDW18/zoKKm5rF/XuxRTKnZ9xe3/vS85DHhtKAHJuq9r+G5e" ..
	"o0tAF/rHZ8DWMKjMfRWNdifzACG6zTiNyzNOP/3LAuhqUpGKtPZsPC19SDIDzzBOuZgkNDpEfck1vYA2c41BOC4N9spLy40xTT1L" ..
	"bB4yCmYJLKJfBIdIyexANPh6AuYNMAc7FzzOxlyzDJyXWr9hE+lgjij/aYeesDpRBLcXwA8IoTWxqejUD61nj9dWXXlXbb3+Y4xL" ..
	"kjQK+Nmc5qRanmfg0q3ZVqKPPtVLTjsE6cT+iN/ZTHFhsk3/yoVSPbNZ+xK3sY6QAvsC9YyVjsSZJ8pxnx1n6yjUoiViRcQ3xLmC" ..
	"+M6A2cgTKPIqCtCv8z4oS4yWOlGsUiwrHQZsQqBeVxoSPDpcID1R3L5gP6+/dtq38Kj0G0fCxb1CbB+ZPuoNfa9qFV9CPLvHy83w" ..
	"bzFpQKMaZD90mi0lp+Eo0UxhuUFbeSocP/yfT3gmEobxnBVtgHJmNPlHe6jxyCUaO26QNA4aWa5ZnZqbCr5O7sPr05Zh/7OnJRDq" ..
	"aTTAq1vKTkOp9Ff/ti1XBhGlR2lrBkjFPgZJmFVDH+If81gamWeye58aiE1uTpybTzIaMQm8noPAgBlavJArXvP/EBzX0WK/nHcB" ..
	"LRJHjlcIQBOBDbJX5vkCQnes9aQXQZvIewAR5kU/ql3IG5MxX9JhoGcjElpqTEHVyFNiPfQunDOR7f7k6G3DP7IxpKq2ap80Hf0J" ..
	"hdzasoJKmWzjZyyCSGQlkFPRGvgLhvYMW/mMshR3WB6a7d4S5TALKNSNF7Nt/7BNU6GsizHRCmkAdqRZnaFelB+es1RFNNUGwooQ" ..
	"1PQmfI0AQdS9DR9XTnmXB74NTd67wPXpx5RBWoamVptGxmWj1aHCL22l0XDhNh69Qz9olNIUh/DPR3+bNwLp5MLtngoFWAPF+RuO" ..
	"4MdOqVoZ7dT6G+T24J5/ZKaB/Kg8DWFsSGIFOX+uEGim+/UVx9Uaiu+ycRa6uBOdfiIBpkx4+UjXt15gd4dDPWj1dBBI13fwKBhr" ..
	"I7ANPCdGvSb/88rTnAvLjHtO6U1fHXARYa+VA8oelZiXS3eF7iqww5VTsq1XFMnX8WYDU7bg4a++1f/jUnmhlVvqjnLpOYEcmUKI" ..
	"TSoxRu0bdNQ5k+HROoOAseHmswRjgpDm6r+JdpSlwVZy6Q6/4KFpxEbT/OpgomMgFjLpPhKBLwBd7rePxW3Brp/TWUNHbBWhDEVZ" ..
	"iQ+oHX8ynJ5FAUwLB+36GeZ/t8Am5LJ+21eihpg0s4o1adY7Hrfuz+EX3SQmOHIdHIIK313L6XWYnXFJ6DsE+xAm4C4CsCZuiToF" ..
	"XeKQgJySn71HES+7tir/cLSEEAtyD9nPjyPSGt+KuNN1Y8kIRHG5MLKaAOnfF1Cp/u6E+oO1306HB+/YxYN/oCj2PGFVUvXuiM+H" ..
	"3WL65b6mWFQI+NY+yLBHkQK5Is0DY1wbhZn52hlIoPHsRvc7EznCJDEOS3MW182waYQBnzQ40PIksPPFdMa2oD0MRzabGccqGEsl" ..
	"fv9mJDqT/ZgdtkAouORXahFp1qbMviNLEjpK/nbVumbUCrQCse7OhMp6vH3rFXbIQelIGFGYjYfWSNe/n0/f+W6IGLzwIxCchf4Z" ..
	"lKNHxMQtEmfu/04YptEtLM0KyhOIw8rOZT1gQM63EMbaZwE6KYoohOHuH+1+ywmDNll4DSZcNclXk1/lq9qcKMB61jq4dFrEVpal" ..
	"J3RLmFIHPgrPVwa3qxLB5+FmWiJiKSVI2zk5Ze8LAVJqLNzSupvvi9alzwCoaVvi2P8f54iUwX8AweVFqk2OFfUpXJwafqPICM4H" ..
	"rJL4T7GG01GmVX+0iZOJAqhkoiVMHLQVpzcHpLtwEQUpLIJB1L0qE8xvcDiQqamI0Orq47expd3thsHpGWwhjMrf/ViQh5wKFzdg" ..
	"Tk1vvNoSwTPD/QxIUYU2DcOWTmoO2Ao6+7fz5qkBMHpqRjPb3ddEdxnI7AScx2kb98/HMBhtknv+Iq2tX5UPt/pZq8AmPBUL0As/" ..
	"3PAvypa+bK13/vR9ssIZH9DGamoWD7GZxk203reVESn5qSnDarzLPIf+FqE5HQDInInjwMW4J1SBHpKxel3hwbST6pxvXNTHfPVd" ..
	"tzD3Y0Nt1ATp5q8TDyCpZz1Wd7qxiuoO00EaFEgrXhrUySn/w58GmIVSzHS/beNhx2nuK8Nef4bS9M5QF7qJZXtDGisS8nz2YRLK" ..
	"UDHNYNcg+U3ZnzWtnCjmhZrXpLLKe8lR6opH7tlYr/3gyzDXdKWnQrX+XDGLMstwD0ghuhtEdj4mzR3KpXipxdkkGZE+Oman8yRA" ..
	"9/kFhIsqllzBrY+cCnahrXi1aykLh12pXCLbBjWK3PSFT7bbDC7Zf3IZCckZRIraRRfKPpsWIb/OYA84btHeRUjwHN2J8ODNnnCf" ..
	"IlI3EqyAq1Mj29mRNDDP65buWSiu4iMkrcSJtz+PLz6qwPOo9uxCUgFOUuUeOoSGjeL6sCgA/Q3XSgptuyljEEVQW927eSsfRw9Q" ..
	"kNK8kWcj4Vj6jW11OG1f2SrUlafBJXwTQpiXj+jKcdYvpv3y8V4WDoSFQeQALb8BZne6ubblKnj8ST/cSrbzEQT3C2j80jPUf1q/" ..
	"XBxSNwcKG8WYfGtMgK44GCZ2S4jka7YwunIVUUmCYao9CCY7Syz7SaoUA6mlRKwhZzhLhHR1apBFiC0pYfsSW8r/Wy6LyUGt8WvT" ..
	"SlzN3lUGVd6acz/8LC4vXskswKQpHH6tdA0bjBjCa+QJXw70ufgA1Skct/gO0G+N1PZ3Y0eHYK5hhH448Sd0wome/Gonfk54SLLr" ..
	"DngRWNCSxhllc+xeXrJ/tJQ2/+HI78NzMuk1s+1y5sVOcJ8DPfUHkx6+b7vGT3B4+eILZ/+WojWMHZSuyEufrwystIzmYWLUeRV9" ..
	"BXS12+Ea8rjBbFQ1NZ4gzAzGLMpm3dE7eC4yLjJcZE4F2RUjJ3GNDS+IPv7MZUiGy7qQQ5qhOJ6vZ4nHhmVQX2gUmp23ad0IDOkM" ..
	"/0UxohqlQe48XcfA3bClqJBMAQ3A4VBr66EtpFID7O9OYx8FYxLEdM4yWCZo65CNK9y6yOjU2o7eoEhfznpXKIFBRbdtlFP8z12Z" ..
	"GFKjeqjvy741ZGPNW5V0v1OS3WNlNiQ3rfAZtckFIrYO3sPgnn61YnihvtwJcfFUHyKdeB9XTEF3AnEP3cpavxmMBObfD7Hez3o8" ..
	"V2DaLEUNGEIYlcChwElauv526YUD6PyvqOwtVidwoYmylrLgPEJAltgkp+uCljc+fOodAH5uFztVsCB7ryD+VTnBNv/OHlFSdlE4" ..
	"vI1w0TWrw4cJxJezIl9qdaHvzG7SlyxYin5+QKVCaZ2Qh5ardiVWyFQ7q12FgfZ4plCbAQGzmRd6i5pzv7/x0PARNS8ZZRMCys6V" ..
	"E073RjGKptCXsLV8EG+5UXrcI6LmUM8UfI1euzfvY45kSuJ9bmRC/hoN6Yq67RPrN0QkdV06Z6WAQhpDzmIbtSbevK0LjwReGSpx" ..
	"1ru3ccn4+GN245BvMezA7IUFGOUYQaEPWl8BDvR9g+FUeSzPKaK32/kEJ3mJToSLYYvPOsxStM0P06XnRMqKZdCLr6uz5LOxYLco" ..
	"VFWhfYWhH0DmZx5FkS+6avyOgZbPmx3eZdM0V2hlgIRMKh4Ylqs9RIMLuOzNkMqJmVewR53LCh3Iz8AMPGIZ+xtHlnnm2Rdr7U0F" ..
	"hu75ANKkuWPVS0fr91MRFgcHMXbjQt8WClzaB8tS76CsA25xP6FI+zDQX9RjwOHpWVNp8qp54hUiPy7OqJp5B3HPHNN1gr/5HphJ" ..
	"xDUJjYVj4wwdJT8n6eWkn/V0so3PkOCNz6jd58zefgAt9BpFjURL120Vssf5UTEdqLgdDVv5EYkkiNpd+JWPRybfuSKsQKY/B48/" ..
	"0yFDuH0nGq5T5dAa0MRzOF5HiNz4c0XCS+6l8ULtD1X3hNMtY+IQz8MC3e3iJXw1AtAEof059gjC4sAnuhNRhAtdt6jxOtUHMYFd" ..
	"7JuZv2cw8SoTak4eCkz83qBTe3oQbSP9G+4D8RnEs0MAv/VSb/P7o6uyrvQnOIbqMwLZipvyNmuu/uw2W0LXDjchFPY1TJOyRk7S" ..
	"kl1/3ajtlIgppzXL826L1GEwUBbeAeNKPsCGWY5oPn9Be8DitPlKz5gke9xUpaEALqR/7/At9cCn4US6zjjFij0VRCnU6bTkROO1" ..
	"gomT2blfUWTHvJvg2fENaza174Bp3ao04C86hmrSvHlKd7ABHR094Od5NDNQUjCEnSlFFUOGrCrptQaq9L1NJVWMzepxp7UNT4Ub" ..
	"oHHw4JL1QDsxc7nHknyocegbo4Jq2/BT5elKTWJVFNjKVmZdCfUlupFrcBjUbM/IgLbvxO681ALOZLtP6ULEsU4hxf2r5lfxV1ox" ..
	"XEVpWrgh3E4hFO0F4bj67RK4mM2+qI8i8pqRGBYCoilH8OnR69pwE/KO/5JSFNxiD0RJi62HpagAdwLQ2tT+p+5UZCsNz2oVm0mF" ..
	"1iu49RxMJ907K4bFvk8FuFc8QcVHc0v6W1Mv8XrNRyrsKQaFvco4cN8pRagPy3ub4s3jTWBOJmowvCnAC+1wIA2pBP4Zmq018Qkl" ..
	"OUCFhFyDKjTD8BVBbPgVQ5Qbh+qea04h5OnHSDsYJLdjXYKYvWAckf0IhhmESwp/a97jBl2U5Oo8wH6FzRaBO6yhPpr1wOY15eKy" ..
	"sqQT2yW6/xSAvJE+zqR48TTw6QKXRGlLE0ZFh7TRQeuX4dR6rVe1hcZy1xaKqexlKHHV7DlUSikWBf+w9IQ/X9+Gw1ST0xzyIdPS" ..
	""
local PAYLOAD_P2 =
	"LqTLVvMJ4LLvF6Y/bhbsdQT3vQ/+kd1DldWTU6kmpmsU7hscs15T3N2cmjW5SBumo5rGQI/nzlfY9NqEn60xs1mBUEby9SOpUAcu" ..
	"0AGWuyLX3OEkxQ3yz+4+RiPoHgo5SnZfNRH14D6na8tJu5MzyJF5Q3Iax6QBhnYV9kdHIw//rGNquON3R/PzDJPY8Ah30PhKCM/8" ..
	"FhtmUHj57QGoddEIU72C4m/iHB8AHfWEarC0tgISb3ttlBPQrmJunTssgpCKeAdvi9bqW7T5436PvlV7YSRQAj8uV3m9ntwpnXQW" ..
	"dJSAy/a8SsXNEnVAUnid22/MWJvwvHbEP4u1+4iAllgDRff+46TOHIbAPqWOw4ClbiqWS4N2TH1xpqLbhyoPc1+ZQOwza7C5OkHf" ..
	"lpVds9Lc7QTi2t8CJHoZELCOK3fs5ycr5s0aAcJbjhoSoY998Q6x6iUXQYL6dwoYVyze80Opd4/0riu4qGpVbyjW5fjAs6cCX5rj" ..
	"qriToEgUcEUFluZe4yv9Y2WJg8oHnBn2US9QRh/htfLeo+/l6PK9yCiz4/dnaE9k6+1o6vlO0gbzok+zLgwTUgqAgwJT7Y0xXLEV" ..
	"EjXo8LUaf5A1qojupfchbxzyaMqpmWzj0A87ONgByiOqYTkRoNkNR1y+60JmAV3ApSAiejqlt1bJcD7rmz4vcB/kpqnhPSY7X7VL" ..
	"NKi5KyzMGkw06c62F37jerJKbs/Rig1L36BrqTJoPUc5yDI5uFP4sN7gpHGfaOU9yAqY3LFIDADUgPUZgEs7B0VtT/Vk4uAV2684" ..
	"BPwbVCZDfNNZrxggjI1cKhRQYBi2oiS8B76OHXlmWKIBXSXMZSHIkHR8NAObdN2X+/m2tv+NNXApRxjgrHTyl8cDBh7ksQDmWfJj" ..
	"Ce505fDH0A+QBkdFR2lTxegihABYeVHhqEAlB3/J0VnXCLZ2HKViB/g5C41phVxjYGIS+GYmjDo+XUSWfmbKYwhC8a7sb+Tn70WB" ..
	"aXYKbU/KIZM102rwzBNyVFvBKKYHokZA28zbij8QDk0XhxilKA01cTtyXTaNgWcQtuoc21OVVPoTsBT2iHvSE+E9qYeN3bYwsFUs" ..
	"4eP9wg/7MnYh16uUt4+P62DNOKwcqVhxi+P+J3i2gK+qutEUIYctzLIc1R9Jo2UeLEeRlx7G2PRdpX3tMG7JAEPKBhs5wXFgshmb" ..
	"Q9luRLvMNUKDN6E4ikwHnypPx4ExgBSd+h9/zeEVjb87WDCijUdKf0ubyozDUqEdZXLEjku5SBJLV3STtx+FSjKxJ5hqA6sy3WV/" ..
	"7LmSTyl3kN3EHmtQ36AORIaAkdAVHWbJUgJnL6XQQqbvi4fF4/QRFOa+ZpYQd+QPKa95LHxBHnGtl2lrPhRyL6A1u60YGR/QX0jE" ..
	"YuT9E15oYhdtIV6f28m/XRMf0ynjbrz6foQEiKExpgGnyyrT2br2xeEjFH24Av7si3WFsgiRzI5IAsDncNbRt9mTtE0kFU/dS8Ge" ..
	"JLI3jbw/s15qtJAlqknptFf1cbGMhn2tGNXo3UPM9z0Q2uZFTiyYDAbvvS1OIcgBUVgpo0HeIAyZUPaqMoTS+LUJJ5O1h6FeJQ/i" ..
	"UyYnt2bJTMcTeQQCH3NQI2yPo0ckaHQ9/dvCHb8KMz5kLZhFqUyLgXxMgTZeUnCJgZ7+dxgvR2QrC0dXWeJk/zjF2gjwMnQjcLlL" ..
	"nmGXNbv8d82h2W0q2mUSKGWp1B5d6X8wE+xLue+DAia6+ECiG1tj7yzeaqjGf8+xloNqPnHwKIr+yavoDzHoimmWvv5zA5QChLFq" ..
	"U2dHytPXAIJVpxWxltNXQpw70Y6cH4eHSsR4YjAONWF2w6c/7awziRtddfS7ryTi6gLgzJwxLMe7f2BVoMXB3WWTERWXO4xNH3ew" ..
	"/cvXxdaRMM9tX+/EcVQE4lOFeYWEk74COCox9kkfsKZfaqvHtr0rQIuv2vVvWxJvpCBYqyoeAa0c7GL6+dgJ4gDrLGQphYxfR9Hf" ..
	"LprpZI9W2ROb460UEo06Pwb87SE9z6zb8I3oP7RaSaGfOVqNFHL1xsE0sH6G7us+T/wRmp1JUWoaNs9fm/nk3TkgS3nddxEVMRU/" ..
	"6qSE3s2QTfKKiGh2hkH0SE4dw32o/c6fcEFNl/Z6MdQ8SxUEz6v1+3Tux8C0LcpHROF4jN+xpsAYKBBDavm+XfQK+4RJ5+6xgBRv" ..
	"Hq3v8EzxsG3LrBsa/MluQoTS0IqXhOfULgP+1e1VY3l5XXdTwI3Jax+e/pNHd5jPd23fPR2DN3y13eznsT0iQF53qv4Wa0ld6/WH" ..
	"UVh1ICHnd8mk8j47fppEnuYVBQTcbznJNNbIcTD1Lyq8yto0Wwxfy5Js76A6KW2J+EA1ccRSi9x2dM167An3bhmZGmJe4yKPPIXt" ..
	"aTtQRvjmoYlLqEtsoGMGVferrvpVCOThLY2K1VIA1xdZrrl3vSN8cM/oUgt4UJsghBFrEHEx5tcobNNVVssMPjRYEHmgvKCf5iiF" ..
	"jLk/Ad9JwSZuJGdcFBliwSXQujUr2WU5OmFtPVfjQLU7yFn4qgClrdFfqYpSOI3ZdkeRbwkCglvk7gKZa2O7PahjiedXnmBTPR6B" ..
	"5MxvfhsCmW2Dzl5tt4D9tUGtCw0y+xLXKJIjLTPNKPycZhXi3HPZOze3U2lAMvgfZvpS5wmjoINmqmH5TqboRZrJmSh+jqp/rjd7" ..
	"KjriOG8wJK5XvS44lOmYamOrVSrAarQTufdPVFeQlGojTxuWiBgF7bA1zS9TpelQ797eZZjWWboeIavA/nNnv4Vrrscity7SVTCm" ..
	"xGzNU6nBi1F3sqlXGAVU8Z5iwDX2rEIa+0spzDfx8UMEaFHaF7Y7Qp1heXYFESGBDbgszbbRhBA3M0ECEHPu/SBdsGWVvpGOXez7" ..
	"MnnzVLsQMstvnZqLXXO204ecMExhWXRTkCC16fsEPJtVIgLltKYg7EApaVt0COdEGXdDQCKzaouiGe3hg5jlvPhvpKbGLpwv1BTd" ..
	"t3WeDC/AF1zCORoALLreUJ13R2EOd6NOUe8H3iwBCSemM2c4VWDvl1WlCYG1XIV49PxqNJv4fHfBbnRIqDxDDmb5CDfuYBzHNMvG" ..
	"l1W8nJiFkLDSkUzoSgSTvBEUUOrhosViCBUqsF1/yDYARc/ATN8DWSJgqM+ynwKcgp/viBnvfTiI4uBuX4FNRKoLbhqlInRLVPh4" ..
	"F1qXanuYa33b+uUs87FdbnJxdDllm0Ct0zMeGi+joe9hDVWL/INYgY3l2pyK+RY854rhWENABURsj3lDab0rqIY/JJb3pzNuINHG" ..
	"Z5ToUTsKV7GsfWPHIQKu+YfAUp/lXWQB9q/yE3bbLJ7ka7admb7KhXZ7N1ZtcMC8qJT1rQApRgrIq+hpfDfj/enndEnEDYGFI+Zv" ..
	"QUPtCGNyOc9fXY43q9Fqe6xCCcW7EJy4gFV8d70+Dx824/BwVg4Uip/Kp8Hn1+xB/pGETwUIw2KVL885NgnLlTFfYxLOXi6s40C+" ..
	"eUzCTYAck31ZFCpht3otXyfrXUYTQzwe92MYDhTg5yFMEWI1VmCic5+NKaDKz5j28geLG9LbPEYCCwPlfTxff85r9YWnfGhYzvsv" ..
	"hsHWn53VwwfC7Ng6N10RSNWFplrK13S7CHF0GgLgMcC7JkLNhcM2wjZDPgFX4uP2wkJZ4Tqai3sLE4ryta1HE64QMMr4tVJ5G/6W" ..
	"PMRPrn3XiKt2iRZcMfDSLoU01MI2ZCi5yera3HjWd721vueIDsFwhzPYn9rZ/XMgyJI+DvD8PxRBcprKtlPEPcQaKUW2dZOkecnn" ..
	"4AfjoRGJwNpP9EB/zrv7SM63IasYqfvpOJAQZp5N4MrmuKTyBzjurFtCBWM6vg10Ma7Amnf3A6a3ucB0ZhJNnkqyjViTlAF9QBEv" ..
	"fPSrd+whoq1eqQ76pzGXObbdH0YGdo6wUFamLIM0v6VrWE/WlLQ56D3WNmJzSpq55YtUY7ba79TpsbWqWqkQbgNFJWtkDxV2ffrc" ..
	"g20lBWj05CXWdFdMmRaern4MSdSSoMD512X6sZU7Xi7l/WAM8muSeNsAYlgzNE8XheRuMyCnTQjWrrwm8eXCiR/AQdM2q4tUauDw" ..
	"lAQohhiMIsCKH34eRsz1kNBUi3RR3vyBbM7cg7S5eoeID6n9RCZvsrCmIyPktnNvaSqb3NUwDx4kgtVlxgnODpNAWN9oc2jRN+MD" ..
	"LprWWYKpyAMJshHV4b1uwZWW6ugeaCUtPDzv2BOF82S2m2eyuxDmKEI5oW3L8JUJJu/HUir/sXMkAE+1dpcRQ32ivA41RH1Klarj" ..
	"DmPETBDwH/f+G6V4H0QGyh8T10SibVnw4rBObB2BA6/vn2E+/Mj9mX2dt9qSnHUC+SldPR76tu7l4fDhpfDUIXlc0Qll9AQtiDhu" ..
	"ZDpjQagIPrzUphM6JyS+lmJEn3mUIxEGWMGPSms9GwydEDbviWlxyUsK/1LHwysIrkf3yS4n26lmj4+BhHyAZ5FLOuwAtct8UyOT" ..
	"9CLMYpwELXnVPsucI6YaJmJ9Ln/k18xyFlTXG0+DW3qzfmGlkj+DSS57b/km/ya38/RObbIqlyOXYxtM87bzar1j+fE+HFLIII2I" ..
	"iKYuTqz4IGS5de96fKrYO8ouMCpLljX7zsBOIx4nJWfMHH7r+dA6mg46ZFE2YxaHt/tzIbc72osaG5TmOk7YQWH89sjw/eKHk5zN" ..
	"SAvugWIHHq6Qxc3mE61hNvqBQymLtX4qsSEwwruso1x87KoTcO9I7ckst2iZb406vdScG0Ahqe4dG9ZnkGg4QMpUF/wRzPnCtyT0" ..
	"PReQxxxf7lq5Z/8JUHaHH8gQYTMQTAZto5kWT/ug/mVoXb4x2JjNcqsepUMw0DP6RG5jkofUnN2SiN9jCfak3ZIs14WBVlNFUTTg" ..
	"gmTinbSg91s5wL+Jm4yZh3U3uCcKMSh4nnE5zeq4s61epiyxvQX1VAgj+93yWlj+whDWJIobuJ62NBLjpjFTGlrY97pG7diMX3WC" ..
	"92OrTZJC/gQkcvpsyYWuO9Av+laMR9zPqjTNxW2yhxzRtuJ17Av2JHL9SfRpxMzgHQPBPG/VcSeJbb6a4nLMzJ89h0zyAE0YU2am" ..
	"B+a59Psz+qe3GoRE57kfK6Sa+xcEz6/hUFhLYqo6k0JQ1aK/mCh6PuoMfsX3J5cA7Jcdx7Cl+SJd+p6QUWNqfeURrhPjxFpJr3wI" ..
	"SvezE3MdAkUyzWlReAqv0RX/47J4RMvtM9FCSEaQRlUIy8z+0fDVJRjbm9juDDlovdB06RjFYl5Op0hBZs7zZLjGQJCTWjvy3KIT" ..
	"NlxiKxbHSAKTIKhZXRj2W5svZsvHMwHW4Am67N0jGQEM/Gy6gE9e/C/JkgyNEW6WmttF5eJU2mZb3cgkkNqAIesVjkaHvUy2SjW+" ..
	"a/Q2t3HCuR67YhqCOG/RaYaKAjXvT7cr3tKmW+R3YoyrDZF/ZCXFbJUzuFkKd5dxL6CewNQhd/K+cwkQzQjD+e0GT5uxk0BWpaJY" ..
	"aFiun4bM1FmLrrwthgNmkxHt2vK6Q9rcHq83gY3nt3z7b7Fhu2b4BihF+dcJznEe0Cuqf3CMygrxvKDYF8qamzfr9SxomGBrpzcn" ..
	"WW/DbxUyGKmAiy55jCAEFn0rSi3bsWwrI7wcvthM57FY5c6yQZBG/9egmFc3c0ufQl90m/NWssxtbVbIhQRnAea/b5/+Mshmp5GJ" ..
	"gPF/XrbFT0yVudYMqu6TAf0ogR9f9/y57nbzWZC+FrKdJObhARzBv6WIT6/dKQlylZNUtUUNiANZbZ7v3435uNIJy5oPSQpo33bw" ..
	"bY9pdtIMQ4QW1LbgmrjvPVMLyGx74kRAc9WQ7WuUoXYb1iB5GW2Nb6dF0rIpPPFijwG6jFNg5xcoHnPUZKNZ23xn0vj+fYDsnize" ..
	"T/5ST+O3f0JzaMwhWoKFNWAAQZXdobxEauVhEsJrmmRWZxS1qhSDlGBUpx4lvA8r/6M6T1rlzn3WJH5c6GMJssjVcr1YL+TuzBGO" ..
	""
local PAYLOAD_P3 =
	"d0IEvr/M+g3fIA8hK56uqYEtB5plJmttlT7RXwQOhvIFzbE5XV7F+7XsXG7J3lO+aBVvJuTo71csfQ9UIjAAonryTSTNG+ZsFBiv" ..
	"aBQSABLS5nZHQ07s2jPz510KkIbGGtuA1VjaQQRZbs6vmchXw8z0sCG2pO4cLpx9HUJ/sob6ceLqK62i3OOsmpU9deseLp9gYCgm" ..
	"WIkiZh3DVtyxqdV2rzxdN/5I/GAqP4zzb4o+N8ceJf7fvlanaxoww85d18uBUMbZ2L1WrrQbykOCmj9k9ud/8hg14gnZyJYvmFcr" ..
	"+qyKWtu2XzVUFquBCv+TqrWvAZSq/kpJUTZzZJopFf+npOH6kqW+DL9m0Th9XKBR2iVuPChCDMQTGF3O3F4lUijmGib0lWbCdMBw" ..
	"78AtvALqDZTV5kAF89eyKXAkFXIcN5yBse7M1Mw/sZtd6tkvyZE8qp4M8wgsaXb4Hl9r3V69U3H2QLHg29QI3vrtnH33Uu796hiW" ..
	"Lw54nS3jPiGBhJU+/rnUgepWgG2R7SLpplzp8QrPv6Ok7+o7hsmhPE13XvfQo9ycPIfR1Q8CZG+2SZhm5EDp95Sv5VayWOUhpWg6" ..
	"bO+v0gzXbV3B4YScMrkLCf6ejnMrEYGkhd9AGVGkqoNSHPa07ENF0KNGrG1raGRG/5n28OUk5vcRciH5XNn70Rbmaw9NSog0c+aE" ..
	"xzsB5uHdTVX+KvDaa184bLrDUjNYdKLfqEQ+bbBtOLgipg2Xk4ZBZsiy7xRyE5VZnT7N4z2bGeA2QjI9zgZGpvAR1vdHZQ71SG37" ..
	"83GxzxcX5lsruVKoC2Wjycz/Qry7UBrFGPen8s3f2pSmCfCKbJxrQuLreO6Fn8sPZFPe8bTDOxkPFu67Wm1h8MTrFCGG4ksPY+TX" ..
	"CYya9f8RTQMnFk2L8gxEr7BmpufjpBefQpDFUmxwmrA4uJNV6G3/uRXetCic5WxRarti7dJjfir0+BBVuVhcvvDqRuEoMI771NJB" ..
	"dz0STFhbx3zqE8q5YP9TEgIz4OoiKsCucwbpnmYtKz7kDbLHLJNOG+gZlpcyS2fpKH+QS/JcthM7M1vujGB1Vln6oD6LfZutUGyj" ..
	"nZSDTlcc8QU9efFiRswS3js0EexSuXYueLbl5pAquvu29vr4n44OXlmMrQ/D5zEwJuKTYy3SA0WH/zHFPudlGGHoF8s1WPz1Uitk" ..
	"k8/lAnBQBl71ZOU5UFm3PRY6Ogy7n/koBK4bKbXEWoDNajVF+ZrIgknmW6BVv93tY14tY5Za5OrDQBHKV4Joq0ooAITzonmMwMo8" ..
	"5zK6asaQ7coAqOKr/zk89nMd0CO2obVyHX5NmC86Rq+846EQxlYaIHVKmF76IoEzviedwg4ZdrK61YnaewLel1SqZWL9QAuWlW18" ..
	"RPLEWmE/GFk6tO8JsRUHfc3tyesjEnojDAQjpIbcoUoEyQZUorcvpDss+8yYfNc/CDTU7w+OtbaCakvh79r73DCKQxf7F4wocWfP" ..
	"tKzJszsJOKh9f7KHrvGeMMv+/zyIPIRsd71I+8X3AZue6HI9/qZavoRSgES7rahY3ZDu2t/lBlquE916oSxWZf4EPUeMOYa5lm/5" ..
	"xdQBRXM/4ClnyngmfCHYmYZ/BRKSAO8fkYkAKl2mbEdbybJs7OrWRA1NKYBg1NQJlXOsYe5LRnWU0AJJ/uDeEUkRB7yk/Dc6TxlB" ..
	"aOod7pPGZGfkBaF5JGKwjxEM5eMiD1SKgAuvzmAoC59aurAsalHBh5UPsGmWz9QU+OhIMsiHLevqL5WeDpecn5dihQ7ppFbdjCKe" ..
	"kXoS4uRlPkGTld6J1ILeUZ1YHd5EMLxE2TrV1mw46RZ/a+mWQzoodsryAtgmLZMj3NnV4orcRK0GZjpE0DXrzYDojtojh+X8ufL2" ..
	"uQfyjRXtHJF1a0BxCzs7uHlFOtzn8dJxwpROG1SwSGHikwKV6WMgakDGVXbCKsAdoZQg0QnpswahYXyzNN5grq3Mga+Qd4iQ68kd" ..
	"H9r6wwV3EAAnSvnAAfwQePzwOpj1iw8y/3AIjaD1Nxj2TmnRpXAu/T/rg1o5svNrQghAN9nP72iIkbSMmnCqyq/MARfTiewD7qt6" ..
	"t/QMv8pPWIDsY9oc8akXTO9noNBEVS9AFwh3qF7Eq77zLY/wYohsReE4xPi2T85G3ERq49z0ulaWTkKq2vh8J7Jx/GEAATuClHO/" ..
	"xx3Nv9QtkJ5noMRBcNReX36CgbZSja7iMir11Q1ed8Z4Y3alcPvRXb1QkSmJ/Lz42XaTJZdPqlAuWvGtff3vYpdcOMs5E+2AAE+O" ..
	"oQ16HtGkK9241MT3JuWUbei1yAJ3FRYVGFw4OonhVeK8L8JMLQNhM2MTc2UY4+lhH54W4i2dPPvm0UPnrkFSD06SAbA0x/7LYrsA" ..
	"7AuaukUgnJlS1aX4l1xSzq87a4Y2iLdhABzWsxeLWTNUIt6NdwpRFwzKttrmKOupiFOtbNbQdIkuiLF2dufFogVGgHtdQ8H1PHLL" ..
	"ViVf4wv7oBM+zyqaAsL9kAFxyuyLIhxGqSiI34C42t4RsniLAcWj68s92pPQdnN49aRag3jv1aFzQ6Saa5QyN1jkFj+/Bk0boQKX" ..
	"MSVroQQ7FY5z3b47CSy7kZcigiVZVe/83qkU8H8DCEZzTMBicZ2YF94HgcxK+9DD8m/TpTxBnT3u1tgMBkfe17sgaqqtNNJL4+OK" ..
	"IZZ/fUnMMgiw5c1QKCfQG4R2PrS/O4GT+PPSTS7po+l/fzn/QpP/4ESBKnhP4+BIuGiVdyb4w7U1hXDmLvU/ks7q4ZRxbhCFAoMB" ..
	"/P/jgwAYjnyiI533tdqWpkvPzCcEAO//WJaeBkENYroFE2MyzR1JXlYCWPinNW/OnXeGlT03e3mH3gGB6XJ8aScBAxYg+xt+HQlL" ..
	"hT47Bxmt8A1BYiJ0HRFD3KYFPAvr65OL1TrwxK1xsTCboZPl5T4KTTBpMFrC3LzNf6SifnKm2ObLK97xFFKfHDj0r16swJNQEvHr" ..
	"xYAOQoh54cyT49pDr3UT++pLM8jnPdWUxBMOX5MI6PEZKxZwaKhlv1og9xXZsAqJk6iTD8nzagNQ9Lm9ysQKq46YEe2YcrljFSjR" ..
	"ccMa5aoz1avo3W43uQ2GT+eGBWUOOzwnV0WXgoUI35RKoPRO/m4TjQSolb0sOZohZpw/8zJNn7BFXX5pH4O8RjyJBRvExexLwEFy" ..
	"c6A/S3bviAN8RngyVE1IU3GA5rM4Pwq9WOb9PSRku11/1sX8b7dQdhchlG9iHyNEPnBBpjuDabqf/Vh56+h8Yl4oFSN7sk8saAkG" ..
	"3Egegsw9B348YOXrRyWaqz3lbJ5hwJanG89ZZcq+YOUO2zuaoA4hVcMqLlc50sMCB4bCa/5j+5QDkQ11NbMllnBR6XhmvZux/t/p" ..
	"oalBGkuCTU4xIqMzo3BkRS8wCniJ5Dsj5U5FUXd7uD0FdKQR1XqKTHHy1BJrU1MLWVax+Ibzdjf/FwdjBMv20UG67PENx7LgYY9/" ..
	"WRqOO4FY+bV4EBdPEr9dMHfNCAbwn1REd1cqh72rLc9zixN0y41d2Vuw9P03WU3FQkwGeHnakDoyS8O5KeCKoiTcvs/MbYb4ANsY" ..
	"6btqpupaErNY33cPtZjTuiS72EsdBKK6+7oA2XT+kYhD/JKsXmJRHYJ4GNWrzLvp/qXcP2Vmfsw5P8PfwLPSqUAqVailBP+YB3VU" ..
	"huXgQMuV70kFtxzvoxGBJDdFa2X/KbZ7SJ2Mf80/D7bPnxhx+qmOPNbKxfvZ7GOWXUnsrgGb4izovnG4VZ8wd/bD0XrTcvp83nod" ..
	"P34lmUV85RsId8w4c83+SOEYA2XSrPIKYdO8esltx4kP6XsIYCPD0erMwlUVPvIYbiw9oRnqALX5TcKrXFgodNVcQfUAgLAseM/6" ..
	"c18ZvnhUO4u+riUfs1A08GL7KwXUt1PGihUSCQ4r+ibiIfUK6e5N2qXjVGVUixC7e2pPdk47y1Qs/JQbRtcjjPGQhv3UYjrZbYoo" ..
	"Sx9KaVX53fSnpN6NqOXHQyiLbedG/QBj8CUA4a2GDHZsdKzghuPKCkqrPnNCvOUWMFVCZmEeVxhLlSza2G4szqZpqg+xtphrAMlK" ..
	"VoeRDW+Lar6grs/Pr9VhU+IMbM/4E2kWNU32Qmg2DhE4VCzylUM+fiplQoo+U+bijLFqJ74XNpvza8Ig01txFjvZrd3qHssD3Jnh" ..
	"u2GIx0D26dZ1ryFuBIE91rwWwe6Da7pQIdq8jZtxxPauhJ+aom9TaIjrz7yRVryN8SxzySDgRWUJN9fbpn5lpmE6CCAJOp/u4ftk" ..
	"NqIpjQZh+cuV5kKROVnlsnX4lZuz/rv7c1hY2oEJGgn2Rggrjjt82bp61Odz2JsJIy7J0pt7sYZuW76fuvzHO444ej/JyUCcjyhV" ..
	"kn04ziptjlj39GvUz8hq7jE4w9fSwU2fEzWZ4of3EVGuRZ/RSBlEN84HE5O674delVJAjm9acdCfu2SY/Ayhlp/1wnZQguhUH643" ..
	"mxuamzj7jazYfbdAScYavbooIzSsk0zbUMyG3dltLfMJk/LVtJIfcU5IB47ivOzU2pBiMQfJEinQgp6RNNPy+HiYGRjKBvQpcBUF" ..
	"T0ATnFGVmZaM1/qOIripVw3C4gsIs5kAO3Gq0HtFK2cFubdClOpMOSEVIu/VnM1xoe7WdoaRbMlAsrmhiA5e9+7J8w1i9vmiq8qt" ..
	"N1rTEAcvcd5cI9TCvU2w6pfyXPyD2heynY72KinY40RCwW1GBj1ZZT0sj7dp4u9vbtMekc+bZRtJ+RkPjC89pZ7RiYPg77ARLbLd" ..
	"gmT4QAG5RBALBVzgA0dYsA+gKM1ArzxbgilaW6KxSijg4aL4vkX16s03Hd4puBKUJQKkMwFI4pVi325fvGWQxByIljchWiuu1O5c" ..
	"iiyA3zsHyJ9kBiOODnJ6nHFBQ7wVU2qzZvRZs3H3X79ysg4ngT2Jm10u0w0yA295CnjwNcuTTiQ+bj9au+Py0z8nLfQituTqPzCd" ..
	"gPC9wmZrDLwhFnsiHJrlgFAY8cOuiuHtMLdCtYIQjwH3RBUk2S1ovgd4yb691L3PB9CqyHgoMdsnvg74shuy3Ej4aV2e7buyeO5I" ..
	"xuPvrFIuV0j5txQ/OhWbtuRjBrxLDrvxdU+AEf7Tk6ZtKLnV56IhGozm9W3aJ18mGxyXi6T59QV6u0dUkubBoY3pTN/xyghcLg5t" ..
	"0xw/Lim0KQ91SVlpe3h7XDDoENtIAH1aSsoyvnb/S+Ojw1jaNdPcvFat0/xjmJ7FRTLMHrJhrAWwNUXVmjtFiDuFsfrVjGN6eBE3" ..
	"cFlHjpyjEAo+JxjUFTzCJIkIMbznmoAy6BopmG3TDi4smAv//aFwrQnj98NtB7tBHvqmrxzfkv1Adg50pV2otlS9fr+Schh8oOSB" ..
	"5qBFUsVwnBGZ8uduMijRHwyx3SiYMA4FTrUMmMvPJHXnIJlbK64l36DEjQIGdzqcxkvTWouVfCmfuQ2dJkBEqjXD9LCDZGEw+tlA" ..
	"URaqzwlTp5+59PtOr42fneZ17ZgqoZNbI8E6RCoycmTRDCXHFUwf+IaVNXZL86qOmGT4COx4SiK+bfRJu3mykW0eoXHcgavlInGg" ..
	"j+g099gTF2Bnpsc8hcXDY3uuKLId8RJ6oqcufPtY2AmaNNNvuHktvH9o3BiJS0chDAg5QwB4DBJ0IA3GBydkIZPDfAzV8aOy5H5n" ..
	"32cOSpb9mBwIlzybdLW3K0/zORMaFDbhOhHi/pCjSMVVTMd21oQwkEOqyeAcaGwL4kYfqNjG9OshPEf8WU4KfGed+hM1Egkx6TyP" ..
	"vRst3ubPEnbRGev5cH11qb3HhhcZYhWXrTDTpMRR3A8qI6LMRnZF1v2LjB1uJBZ9XArT4+rRDMUoEOChMBv0C+2e8OkLOpadsv1z" ..
	"snNBcbXvKuMmiN5njX+kMCBeb+ZInFeBupsCN01DqwbnIE8644mgZaE+roTlyXAItOnlnTupHQkSAB0G/3MfZY2JnQ1B6Hw55mHx" ..
	""
local PAYLOAD_P4 =
	"Fc8hiYxCaXJKiKtd6Irp9Y1WvkYbw423iOGskr6+Bqyuqng6lUbEa6Tb2pUoLBGEL4S+aYgjdtRc2hXR41Z04eBOEQ19hSV+vBcT" ..
	"4Z1yJX9zRJv0WGrn87yu2yUKaBX3VtHmhQ/KR9Zra75r4Wz0sDZ9gza/vKORRmKC1kSarBJmrI0dTGXu3mPaTU7RWj5+fmLea8p8" ..
	"yLQ2QBMi2ARRLxLHLXQCJZVB7bwnQwKwXpotpG0waLFbRx3LNRDvZTMOJXnEpy055tts7WEc3nrDdE0DZJLosTTE6zqC2JNQQIhO" ..
	"8yku4N3n40Z37URqpP1CiyaSeeM6dZ4Nv5vdDFtfLIrNDGz6SSeFh1WaOoguANsehZxYyGW+QpVZzCP1q6pb70La92JqO/8uHstU" ..
	"23RXDgNYpcmMtUuV896DTp3dgK7RAwHcpJis1PsTJY3yDjA7bS8nlXvonPDsSDEh4KXXRWJOB1plC/ug3YOIHXQOwgShgCv/p03x" ..
	"bGBHuA8cCFDA+DkSVeXKbBjM1vhy9AjwIZBGH2HIy+IQS4jjZ36kuPmWtlo1rXkqwjKv3eZe89VerxXpk1Y/dykNgiCQg7fh0j5i" ..
	"ldfXq0stJa2bPXXXQZc75y0MqjoM+U9ETBwj0jfcBmAPo/JS/XLqW0E5RgkfCIkvdiXbQMuwHZhTdsuF6MQgxOYTClQEa6KyYlD4" ..
	"aap4zk7WzuhymNRst2CCGs0wAU+6IqVXlEPm9jpFSIIIHsFgqvSrYB3tnwakOkRXiGQzfNY2pk44gw7VaYxUMLQfkERaCwCjubPN" ..
	"lGzAVRvpfmpyNhyhUIGu31vBIkvuFITrz7IGcaKLV0v57Ubu+Avy47eefP26g1OAiRTC5th0xgUAZVyvhgNgU6MmMlK2Lug8e7p9" ..
	"eXE+w+CxrtdCknoGqnaIDE3dbsDDG0QczQJO0+SvaKJExcl3vJ3Kdu3eQ4DHC8mI7mhMXKSN84AYPQ1futouQz1+XGVFKSF1P+vQ" ..
	"B40ii5gWm2nb1J5p5u/TZraA3kwzqcO/qUYwFN6zgchMPwaOOUzdAsLx5eR0kz3Hy7k/8tCawo//tC60keEEnZW6/X4Y2BFkAszI" ..
	"GBvBYP2JJ899+WAlYI3wMqH/azxDtyvwGcdI/SbKDQtZn/E0nTU1eDFXNrIJaqT4hF/PAAiSHdtjb8155h8w0QGTpsEiaidXdPKp" ..
	"KPl6usuY/KK6Px4xdgjbB6Ld3X0QJ1FomlPKFQ5qXft6Nd93qmSrI2vc9PDcUYbRVhsloQRqsf9QRC1jpLYcrqlcvgma624qsfKF" ..
	"o1oI2bOgT+0QsEq/N/NtUG5uaxXaeF8s9tlFwNTWWGOaAWdYTuEAIFSJgkHNP0yFPTwK3kHsHjlrvHa0EdrZLrdKLrZ5psb04Zc/" ..
	"DF0xplkPbzMJmRdkV2hzqLRtDUcg+CQ9pk1wS9AZu+vh31lgBarFMvTA/UnXh3pyvinnylUJZ/Ffh5ZWtUIY3/+1LxwAypuf65IH" ..
	"ryVloCajDjNAUX7So6kTOnvEWUzjNAzvPf1Ph92uR1H79SWt4oDiZBxNaN+ckI6X76CXfNYDe4jL4/c9W1HM1emVjdxVI23rnFXI" ..
	"M7gNdei96WqMb6NG3W3cEsm0/qzYkrDll6/2Ol/nQaCUISI+9KxuSkHr2I2NKzbUJcT4E5Nsun3Lq26Q/1Wv6FmgDJcVJleGmNPT" ..
	"6l1+wqxThViag+00GJ+YNlU7icRtuJBfWrky1BTc2Dnrw3HjG1FZrSrQcETx/6NzrxtCRw44vgExgFC1z+qQs7oUaAvAmNaKEJPa" ..
	"JFma7nCb+m99/fYsakI6FNqkqRDwjKZmEWv9OWLXcDYRY1KQGBUgYWJVgklz0H1uEhgQRVrOWLDQhdCOOEnv5q7WW6ZS+/oGzNMC" ..
	"1tKoRsC+H2EHVpUHDFxQZ1kZRBrLhMM0qC+5rkihHJ6mfNU+TfI4zgIbl9EUI2kDfJkHbYj9wNBn0bZk0AfIveZikPd6cNUZ7T6C" ..
	"ZNxwl9hLB6auYDJHgS0jjScWJuRT0j17P4c7bF5pdmD+YDai1twaouCt/LuaVyIgXgMbQmqQAR01Z999c6nw8m7shQ0IJh9BQJpO" ..
	"m/69/08F6vhSJPS9NCFyIMLCFIzA1l2XfBzfhZHEiF9YjBWpA9I9Y0VskpAHgTDOvLk4PJacRJnM6odgAXvCxHAEJXIOqq5HP7kz" ..
	"9h2c+z6ueMLM7DN3uGnHyUTQuO46TEXdf99VtKBExAvKDb4rVe7jVPzD+6nGUcsfqMo/+3Lv+UsArNdkl9o7Sib/y/yXqO6UGuu/" ..
	"g53+f3ghtA4A//eADpq6z8g02TAwNIzCdql46AeJB9OFRM60Wvhl6n+at4O3Q/Sa4UJqhIEKTJuoUHuluEZMI7QT9kqiYqQTVPdN" ..
	"9j6SBSXuLgYiwILtVTeyTXbzmFNkpYjG1gWh3O9nFAQr4XD7MmDiE1Fo0rkF2rJHhlvgRfvEPT8jVolmaVeqvIwQNXtwdmhWgEOA" ..
	"FwdkVClYSAdmjZaSs4GJZeDYV5K6XDUWYyt2dWGe6orypRLy4ghy7YI960rfar9ZGYf8lH7QVZKHGNJhETyhTjdBjJOt/4YR+d0v" ..
	"/PiMWheUHjt1kdDjzpDjwdq+vOr9HzdpfOwG6aBDEylq5U2p1w/0keSPE6IG29Is/3uzq9dVISErYiO42TrZgIukHkJ1LpMCNZuX" ..
	"wf2NiDRNoqzpWmqoNXtLD4YQRCxunL8fv557yNh78efX6wQLDHWzTPl+xwwi1Un4WOSipzEw1DY1kEell28qUmY9JOpBrBCZU3TZ" ..
	"hD7+GAI0/Mz0/iJY9QnI1Pp0e5JyU42R33GItdSR+tdVkGu4cxarjSajG6K2wb4cephEgi5QEGKzZuZ+5ZknrafMpOHi7GKv0vzj" ..
	"pCP5cIFoKKUIXiX36/PldnvKscCoWRvpRnd3N3p9JaJ7Klvi9ZSjLI0DS3ra4uFacYGesqkBBsCu+ZstXDpA7WOn3+GWF/xCLTch" ..
	"wobOzLZCDR0WjK7bbFVlcmayX/LBIqaExzPYXWnW1NPelG2T3zsapavuRe+slQqfDl4h5PlKFyb9WZPGRtgYrv22nraiuMMH9jUV" ..
	"W/EbSf10E4zyfQhfwRIYZQn4Y3984bW0Vwx9UN9NBXzqcW004eaS6lxmrc6AiLLsJpSHsp82Mo4ulO64FP3fLQMboa9BTMizmC0w" ..
	"WUBOQkzOh2RLPKY8zjyXjuBwMUOowFouJ/BX/d567DmGqI7NiArElkA1Q7c7UuBOvOnVkP2YKK68gzSbe5axJiuzM9iG64hlBWDX" ..
	"TToIPsOtLipRlZKs6oYPcXdg3BblSNWuXyjwU0H1EcvdVGNPPlZmowj73AZkZOULCWeEuLq8mP2PYSanIvLRiLXnnvSLCuTxmcer" ..
	"mjx6uqTY++W7HHULQBTb0h3srjKLZ+ZwJpnTRdLPdoCL3GL5JUST4WjzNltDqRXa0zZn950h8kT0X0+GY4Th4yuaY/5QQb868Ca5" ..
	"KbKamnMGsZle5H59sasW7Sw7nMOi8VMFp+TbGKFPK5aej3+hbrcmnoEIvkT5QH5ywJLJmSusV4XudONF/MIN18m/bbwNvqE3fkP/" ..
	"FFue2AH9Tfu+nzQEMbEBhp9EJy5UQ3uoNvUW5pGkCI8f00TKrtQPBWEhRBQ16y/D1uHuxPyEDNdx2KYLQiqaDnrlIS6ENzTCXdtH" ..
	"tIB1jsuSO0biBeV5ayXxZN1Fyvvdlx0+uTp0+bEY5s5LsebdUJwDjTilcR0BlN5C4gzmTUB68l4ZjnMWVl6/JNjZviYFHYq8nsLG" ..
	"jkMeVFF+4+xKpTBfUvA0QplRbQxpOdTu1OOPC9r8FdjDtY9Mn/eCXBszNDqJsP8GEgBS+5VL/FLcVrHno1Eie+YhNXDV4CsgoGUa" ..
	"EQlJI6K7DOiKeYaPm5LlOG0okKe/4RsetyIeubuvBZOoN8OMvxDrJ5XEpxzBqFD7cWPeDuoIdJlgLenkrVCPjABTD17KjakXiQDE" ..
	"vSSZYJZdPdT0hiL3IKGCm925iPiBzWS7Zf/UHWKGfbeDsKNIdm20zdYfHnHS4nCkhHIVuggYxCyrlIv7AVw9KP7ombUHT4cnzZO/" ..
	"Y4O+uKtxmsz7ygAkbUIpSKryoRFuBsUwKod/ZNYCy2vrrvn5Oqc8nFZzUCDW9t2zCDrebOV9bZ6Xj9ckjWtNIgUPO6Xa2u5c87m/" ..
	"QuZqThCdHMJLV/Rl2YGmOQcug3ixfJO8Ljeoy5emVnL7mQIMJqraqFg1f4AI25kDsbz3EMZH/69UF0AIAjvP7E72cKHIFaW99FC8" ..
	"H6joJwQt4+u/QOC+eZ2OEyslxRyrNT/0w5S0Uu50sL+VsJpY+9u51E+1n8jcRdQOz/1c4B2JdiCYjZKMUAdF0Pv6+JYjVIfN9zkw" ..
	"JIYdaPvx6fHsIstpmOqY6zpRK4scQdM/ot5YHt7yVXLHXH33Vgjl7m3Biq1fPHbo5GQZ/WTCy4Jf/PHDWKewB1OIcMhe/yhaZrTS" ..
	"u225dHHeSTZq8oBring2nb1YoO1jWst5fcGxoCfeeX+UhKfMmRupdFumKbkULmvBWPbI3mpB/sEqxFgUg+XqnqLCFHpzoFWLUbJH" ..
	"Qkn/Pdw00KsAWjTSI6RDVSfsNlPL9jQta8buSpKBV+3WIfKJeKkyefcPrie8J0o7W1wUI0CVSMYeBY1xOWXJj2EiFG2469YQlA6l" ..
	"aIwgP8JdDSld0H5Et3xRirfBihuRGxDtBM9zBlE7IUUb/VcMTOE6/dn2bkeFPsunTmW4Mr68B3kfImduhiYiRx23wcc9Vn+mHJHp" ..
	"arTb5067dMOYpa2yS68197Ax2Acg6ww6RKVraCq/byhgk55X1N7ukow5bMNxjt0ac1wiR0er2c7YrVIc9RPHAo1kcS2+xvSAODkN" ..
	"2PreVaHn2Xwl2+oXfZv4rK3bHESqG7WSqpsI05fA+CaQXFZkgfuK1FE+RZoDRjwZAzf7NJONYR7Ws3ZJ83Av+dMzuzOeqqjyffd0" ..
	"FFxkuYiHCJ/bMMFJZ2qxNpIqhlldMiBptoNP88gB1dwYBBCfnFmpHZWaHyAgVgoRaXh0hCmu2NBa/avQhzK/vkS2gOpgnCIm92N5" ..
	"tA5wZ4tJOm2Y4fQMaZyfsLaD2tr8DKo0dWy5hFwvzyYQ+V3DHrItgXIb6UqaHGgtZywHY5PnMP+uneVIPAjpGW+Mg1ChJ7iuin0P" ..
	"MtDRLwbc5JDlfC/SAbcnYv1q4Z0kOTEJlg3JZlTvghOKgIBqEY318Z2Tq40aBhItn4il9jxCOjlDo5U9cHUBaSQZBKcBrvJbHPdh" ..
	"d0vt/8Rl1EoH/I17oeSLDXLB/Ivy1sZTwOEykqIlmxNTTHjw0z/Qvm1GttidUl3npBubcBwxc1WP8S41iu6wWp7CH1Dy/dPvujHr" ..
	"BWgtJ7weJFES5C1JJy4/vHpNmmGMe88QqT2HMxjCnbpxWB2z38Hmo8oFmb2w9F1d4oddPvII4L3kGIDBxFb4ZRuMl2EnKh7RB5ly" ..
	"nChcycn7OWuYK2ncBpRBAVH/B287Ya3IZRIUz5ajpXwiojoJAGLLBbaezytEj0ZP3OUSO4AMiis2fYYKnZSMDWNWJebph3jmkjj3" ..
	"WUyUO3NAmjXaOyu5b6z+j4wfT1aXwGjWtAreRoo3D1EJQ5WSmSl0ALW2nCqKM63sjFZWwHBO3oerSPaf7TbTDoaTWiHnPCgD0U7i" ..
	"tGIk4cflJrgDZQdcGQLTY7bsTAcDkarob/yEsfRccKjN6EiErm2TflR+Z9ZMxrJyTi7hj3JE16y2OrI8892a6vqiGqQt2cmSsZpb" ..
	"mCnuKz9W/DblUkUvISqFkdeD6uF88fp8/uS0LS/iLA4pXJDOZBYQMYrNoksNoBBhhA3EaH7uCRUXvbFUOHX8MYJrMFzPHfiYnDNl" ..
	"K83g9CJgKYTXBmnfd7kNdRoOM9/QjSvrSg4f+yLlsR7m575xC10dUlI6ItUfijwr15juu8GL7E19kY9uubMIaSHcWph8NX6bbgiT" ..
	""
local PAYLOAD_P5 =
	"ie/3kHHcuEXz4UG5f1zHd0iw8F8rL8AF9skC6VZieysawpxJSFJuVAcrt4PHf7mFUVAt3u9l+smfCQtvkzzlnBYwPdqHpse/Y65W" ..
	"ofnhBbkGYWJxe2gfATpS7h2XwXPsDKl3stjhY3qjxPtK0QBmOjXSF09xRwCI+0ll0edqTXQb5a6CrcTXKtFtGlbYT5cnzZJz4QLp" ..
	"/pOaKRlPSgWLfQE7HdfuY+Sk1laZRko4xSZTNxYsNiWPJmwUAFTIWlm+A6sC/BTi7bpsx99ddlvQI65Rka3w1osegU28ipjEJ7L6" ..
	"mr7tHf8UHQSlEGdtTfvj8lHcwt1/zEyL2nsYCExeqZSzjmK10AhB7h6obwURJEgK03T7bsBqKbGOTo1XjsjSXmCllhFtIy6/aSbZ" ..
	"0NtWXapkhHgE1sAZ9OioXVdlp5YMajcJQJ+R2FZo68loPuaGcBmBegm+H3JdZGyukIdSNISLWx+c5m5OJ+wKDlAp2UjdmjxAmnhL" ..
	"Ilrl9nD+dJLfifeMkGroz2f5DohPxk5ApRB656nf0bFrjj11Qc2Y9X2yLi61WaEObSg4dMUTrOSWMKOjzjyuWRdV9UWqx4lofcdj" ..
	"YmaD8RzrXt6PeaPwbNigFht1awJrGPjwwxdvemad8ROt/qNDzQhlHN8TcHMVQWKk3i83Se/DliX1CbMSrdwbmCJXTw10M61Ms6WZ" ..
	"21u0KhL4lHDFTLSgYif7lXJFphtH4ZjpBmKBMgp35LIDwzRm3DugypbJmT0wOzirtNajrcgOk7NmFURyf9dxpbqHl2UQDDnRlOv6" ..
	"ytR9sriWyUawPnXHSnl9opnJqmA6K/+gRZ/LGFZxcwD44wnv6E6jHzAPbqp933zSUdZGNPjJxSIP4Q4yI70a+ULovq+VTcM7XHvG" ..
	"bWeWSdnnP0Sv/5EBvBKU0h+UiPe3u/YXFsu/vSCBBQZXp4qtmb/8+lUS5rW46C7X5sul8a+yd15OSsYbYzz0kbqygtxTv+H5d5Ch" ..
	"N+ebTWaKpyAuv4IttTD3aLjcbOlUM2EVh+nAdn3+3Ei9YiQ/enSJBMTYhgKm/MgRnyTCMKj2tdPrEeIMHF/DetAhLgK+IIFJ2wZ5" ..
	"ZHgCGNBzxLKzQ6KJAs7CChx8ZRNJ0dbo9rEX5XAAwNuyO7gYdXND10tKf+mSsKbGnWYF53cEbRcQQCBtWrrxpFIRRdMqjhmJDZPS" ..
	"Z2tCdxjjqbiX19VInP77PI/HPTLpAyPNZrHPDfAGUo2gob7lR1lULAJsHxFZpSu0e3KuITkI5hTkAW+XZQ4E06CBXdQttcxsdm+2" ..
	"M+tvTENwy5mrcBzRAow/O08U4qvuFkMIbLYbu0ess4c86QwEYG9CCEgIdXcYdgSHB7D1mGJOzsAacJWiR3u3XXWHIQl0bwOhoW74" ..
	"lIWWFY2P7n1XuOW0m/t/a6h0kfHvQEdrrnjnqd9fT9gHIoC4dQF9VdQKsJyWZ/LLUlJSSYAEnlcw9If/M5wsTJs8mV6VIAx2ggkd" ..
	"UJcn8flSJqpxldCWIeKGH9umlDhFRd+EBTXviAuROMgrEpkQbKOiaccxw6CfyuQR/dVYNzsUPlaLHVkybctS7Ncy7ODRctq7YT6n" ..
	"2gwwTWiVnUgQzqP5mcXd6Kn0RHwS5H0IrdudFMuX4wu+Mwyx0DSGjkup8Dc8GqAxhj4NzmcIrrdcbqSjBa3bp6e0LjWq1g63Eged" ..
	"qpnAWoSxBlrGKLTVx4Rgb2lkz1ucEGYj8kNw5EqLHnzMcSkv3Cs02sRBDVGKldlrjjF0mz5H511Dn+k0yiB9oL9SKk61zrCMCDmG" ..
	"yFVvEzJNBp6zXF5P3hXxl2hC92QpdDXTHDtiTpBlCScEhwXYGQvgBxAvh9K+UoGVbYxi6zGhwvLHeLiKNad55AcuUdB/u0mZ+mQj" ..
	"iGhp3eYhL5s7E8904u3VDrBNALv4AXAinfE+XoP2OI0zguZnYPUaYmWdM8xjQZ9rR/T0NsiTggkyq/SnXM4uNRekM1YhnPHr6qej" ..
	"fxb0ecQtaRQ+KdwySkyXn016qNPXEPVPH02t2Lptl7n7fyi5u8AIa8FQQw5AnxWjbkJai/PrUOF7mhURZ2L0FP1x2AINr/vBhK6s" ..
	"RIKRI+kmtCO9iJXQCoHEQ9QgcrcYKKT/7aURXrfi6jA9veIlff9HcaZnGYW5hxTprIjekRQq53AeVtmIPuNExENRvGpf6grXVp7o" ..
	"qkF51+OboCE5Vg3r6T9Qrwk6VTbCbpV0UYB91ErWWNxaiJ4r3rElrDaFL+X3qPnP1Sa2LTQT2oodT1i8kNXAWU49+/mh8HoTWxTv" ..
	"S4geDHvT3+pkM4TShpaFNJ8xFltEyOMqRwOiRwX5FseySVm0b9F4QzcbbqY7GrZfmbmmrms2Ky/VlJdI4o490LnXUC8N3ay5BpDc" ..
	"WUSUH3KBDN7ESjJrM9/ea/71XLtYvCMCzzADQJLObFZUcl+YEnh4evLj/8kX5j5Jdlw/5XyS966JNLXXKfZ2jsw/GFysE+4zIDRO" ..
	"tiovAYK8QZXq2EFT6MkGYEWGQPKkNcSyEuTh/K9NDGf1UBlcdYUE+RyWAStcWRrNub1FsIL/o2sNcAsfkabQ34WsT5/kcLOKGKZQ" ..
	"226z+yTaLhBOTIP0tfDZYhrfA9NHg5aCcJYC8meEjs+ZY5hZ7/iO99B8tM+BXktns0RldilOcdloVgnjtIOdLzWAs2Wtr1JPnN9k" ..
	"A8SOiOBraAMZodOBX9y7RW1DTfmavbCOZQpuA/04ZVWxbKM+0CmDYAD68AhHfiRhycPpoj/e3+37XgB1rGKTdp4a8M4oIliCeTlt" ..
	"B0hTh2Y/PkkqjnaAx1Ff9HkjXO3inCRAbZ340yxNQdNrXPxhO5+ConNrWBWRWd8zLG7AFNxVo3xQ7MLN7kcqbk3mSC7OY8aiPZen" ..
	"uTNHxdQoDrffMt42PVCTg4n34uG/wtWTzV3SIFEEDkRxqnpeA+pyHyeFKddSqCkxQhV4rlgP3MY/Azy+soxeoh8kdivzaQRk7MQE" ..
	"Ponm+NM4cJAH4U+HGxnfWdV3gs4n4Ez0gL5njGJzHxn4MFglgkX5an6G3MwCzpxPoU9bPwMCHgkr4t+izBW78h9UH+MeORgpjpbK" ..
	"VFjHFnzWngGSNkmZuVXIof3Q5Mkmlx8iohn1UsLgkgy89cuMIhoM1CabSNRSaYnBt8kYhA/lATppBIaN5JALc7YbNFpERgxAOEz6" ..
	"J7NwQ1XRi1gSA59wATVw22YLfsxh5NGzwDapvJU+YL9yJVUkBlr8I+0NcMA3o6SIc1nAA7gx4UQYmgY0mK23dLs8LdsX8QYXQbh2" ..
	"g0LJRNOJ0W6z2Mi10VDCXAakW2Et+EZesz+u7QbxATtDf7OpdqIaexT0ECvFRgO9n7FXZRcyXlS5SdyKnGELr7Y06+b6oPTFIHvK" ..
	"rIKZuDV23BxHX0D8SehQnnoxXsqVNuUHl8J9HKVYwx7G/o0o0yTIl9lXnT3ZEY/vVDsTruU4FdLglbEfllErPgoYnVVtqHDnaPmT" ..
	"cyjx57DhLKsBQu67HoNa0nJUKaiS87MsmWHmsjE8AoYJ2WPe7c2nrRuzcgO7NhXaFCSF3wNuxYxt6vfoy0cWOvM+8VMBSNRSC5Jb" ..
	"afJ2L4ri9AzYa6up0MrMq/CoyaSk+uuI108IjREX1bdpistZjwJmcH0zj6DFLxDD16CpbkXJ/34DkLawDGirFA/3V+4XGBl7r5Tk" ..
	"6dQscLcPpm/8FavLygaVuEg0+Yef5GOJ9X1RcHWRdfitBmRQ5iDLbjb7F+yaNMt5PbmmCEFR2BUVzya21IQI+q/m7ptvNi82/tLr" ..
	"rp+GRYhorPrHvfCTtDcCcr6ahAunNHKun8bqYYPd01VsAriyS37RWJw0xm24wSfDsVJSuOfzsmp1HA2QYwVWrbbWuqmJ9lXY7BfD" ..
	"9mZ1PJ5tfvvvTuwLklEF366QPZTlqK1RenPeiebfyUhXfYntyx1Js4klp0NMaoSMG8xBAZ4rbbmovZuvauCoRQYi6OSseIyZT8pj" ..
	"cCqvb+Xc5HyZD9DeexhGgij3cRx3TEIuxOHTIO1yxmXVIgLosj+PWZ3YJbaSkueExE1kyjT6dq1cEQMdMUHRlgqkGJjl7JrA9aXv" ..
	"1P3NvgfTD1WfFrI/JaFaiwdjM+b21yzrvGpBszD9cCT4OVm+OdgpKl2V/+oIMJRzNmWCPevoT8IZq9sOZd3GJiJvaxvfnenlnGkC" ..
	"H8OCbAlkq71xwR42KPrTJdiI3sYuAI36lN8KfxhUbh5aTylenU4vO4YBblCl+D4iH6muWdpFpt7JV++gN9zx/KWIx45I0R+O6NPV" ..
	"h4czTcWFeU340LxPyUqsPYMtWnw4BGphUNhJqclGfey7wVZThL/ufruDCwmjraOeM4g8/TzuLhGzNclsXLt25wpYX4SG+DVLz9EY" ..
	"R+CPDX0SJHZ1BJuwphNmWi9dhq8pAFM9ffr5k+EsVHhjHcdRST8fcXJm8Cxna3rBPkVbKCYhK/nCqHCgG6K/b+pAMRF+gZPSWEcJ" ..
	"GRyTrYbKYlMIUg4KkdVTUcKtt/s3DLAxNfUVhBPO5ynmYr2ANXbgmo1ZMP9c5QPzArdYFD0OAqTUAB70gnLw2kt33jmo18uppRm8" ..
	"lt8IbNrN6RvpwfVT8tPUVxB/fQ+0Z7mSJre4Ne80gxm1MCy4Vu4H+aX6A1BJriHnncNxrOjrL4pVTvIVNFXLl/pIySV2i7rAGJF5" ..
	"ZPtbtODfKEjmlpELZO/bd8DMrHp5WWy3nRsKS/bqM+JqbjIzJz1GRGUJDCf/qdRsNdk619Fvac32ZKP1KzkaYTEtOvw9K04/jXiq" ..
	"jLvePDD2KuElORvN4//DSvlqmyBpp1GFHajEnhNctAknz/hxyVYa4ZD7Dz6HmjjMVGrcUr/Bbj1/eDed97yZA51CXtlcjuPAH85v" ..
	"j/nc5E6KOpVboNSivsirtUA5Sn8f1SAMsJ3JZ3P8yf+T4s+082N8F0ofF8chWKcGvTbUaT4uquFp3NYpfRFfXPkcpxiSP71F29EB" ..
	"YtjGPNmgM2fe7gwOAVuUvA0DNW7JbnS18iNKR16n3EsO5BhwxMdLxFcJlKqHNNF4QPaWP1sHzXbVv8uwgzMhe/zLi7AGzZuGqoep" ..
	"GzgVolOg3I0h3mPRGH8Q0d0Zsm4pse7HBujTnvVY9D9/gDXh3y0DBd00LL7B5RcfbUjl09baxwIEM8AwO5dVtkflyt5vkx8be9qF" ..
	"2J9DKp8EwFhkrQI4So3HTKQbao8XGBo1Zuj8G5OVjsH7yAfTDw/1y5vrs7NN4Zb3IbjBpuX2vPFhIKYd3H+gLFvYQ3uq2iR9/a8o" ..
	"FJoesoSczCNCn7Us/j/lMJYlpQ5oRd91b3Wm8Xu1oENqmDDwD3QbbvIXi/vqEHEo4EljWD2+SYmDSvXwoa6qLqBcnPcpByZjM+mG" ..
	"N/ndMYkelSZN3TfNKHo4hltxg9ai7HEwOrvDPNFlySzdJdZ9zpFlOeRaMaSAjzxG2ONq8utXib0ICl8kxBuGjG9iparoLO5rkeqV" ..
	"I7yyYQDt7tNIfNC/Rhx6hlEwb+tVjNozuygOcLxVINRW4dW64LRt/TD64viYLq3YpJporPBE2tbp8h5/q4TNjVkJRQOowBoGr4y7" ..
	"Dj6+KPqruJwni+4CNrvhY1fb8I1dKQeYUqB2vRTo4ecFM1Jhwu8EWhQZ1Z+JvyHkhtAQYRREomSTaTmEgxK4iB1dCA2lLHx6UMT2" ..
	"jRBJASm+89hjhNvGkZugJb3DS6DG7Wy1Oxl1RfQLuSx9Z8Be3jzd50kn79LfhdojfLqMLSx3887L7nuZi3f5bD4i/TcMJmDA3gZI" ..
	"mzNqPv1BhBungnetwxmW5iq0q8kEXsplBhvigJ1XSrREb9eMP8nhXtVtU7SzcsyOpsqwZGMkYZzzduSrK/fGy/G/SwbkfI9Wry5l" ..
	"yYGXFs6A5oE0SeQV7/G/9vj3P3JgFZxtBIX+0UzU176rfjyx2fZQpdCP/M3iLdZGU/p9zKgX/XR4MitT9wdhpQT2fE8GJlidzC58" ..
	""
local PAYLOAD_P6 =
	"pMDLzJnVdyj8710Iv5PSKBoK7Wv4VFo9KKj9XYupfxCD04rGas4lOAHi3AcOyQ3K5sqoqoT6MuBKGCIvcjVjrTckvItuSm2SK1Zs" ..
	"yfJhPYPfiqWsfaH46NRcYwsaL7aZ+qiCLVR/fz5ZK37CsNwDIY3yEd6iTf8qFNB/Bv9gcXhvy8oiKre7wwf+VesiJS8GAz5UCEGj" ..
	"DHqPbwRVcFOG2ICm39xg0+iME8j5GK2+iIJ6f6WMUqO4F5njiotGH+9GYm8QgmbvU3Punl+NFKE0iKXo2ADiLMlVq2qGqm4fPdK0" ..
	"kFP7XznZPdANSAZ9TKiqnC2h8qAWv/jIvBDSwwkauPTyLXJlv7Vp0C6ZzrX2zF86hfiYXlDxE894Qh+KE6sJaKGcumE16hn1OeMU" ..
	"Qpb4y4seuH9u4jv2cZnkfMAa2cW2J7R8AWwnTV1LIUYlF0773f1tuSwxJxSwxapW3fWhADeTMgD3Myn+23eydxMx1FStpjXpdZTF" ..
	"2sWG9P7EBhWyfcrs2UnXf8vsiTng0rvZxTr3YjL0IX8hgLPenEwD+NDfVbsc7abpfXRH+H5sAO4uGTB9nuPvZAp3vtxzY13N6ENB" ..
	"SUKTHebHxhjzugap9ZEPJJ8PpqwZurTO0a7L82wFSS+fHgP40Ojv/UgGarvkuHbSPFo4OqVJ5CAp+VqeM3OdVWTlEZx2GqRz/gYs" ..
	"Vw+ZtiwwMe+9ikenYaA2ppJOlEKNB1VKE+xEleMvFbeMNk5EvoWO/2jTSFnC3stJKo8yVKXYa/MMf2vlQx2hKFYNk9heNaqPK8Pm" ..
	"8YpMDtDAG89V3bt9OmVnnmu0os9ufIw2LVvZW9YsTBIPvViSenwl1/53webQuBYmbzIPEAvpKb6Sfi5CE8K3DX7tga88oLLZv+CS" ..
	"A8depoqxDwbYU0VGm1gvuemF0KKRcsfpshM4/h/bYI07COdscA4bFLr2gFVhbetxf0f1qY5g3alvtvEkhYyDqdPUrmvUi7bvhHW6" ..
	"xE/9e5nM3GWOj49ESoRVfhuOBQxj+W9099pY7/boOkF+IDChWfNKnd5hq6zNdfSdOaHwuSdJG18TZa2YuBtoUeriZjSxpXR4Aq1P" ..
	"8nfbJxSg8EHbp/6AI2JQoQRWnL9xBW/wk/xV0+9vUywNG+4md2dSH4GMU8RxK7TsHQa41cXuSGu/0Yg9xVP6tp3YDsnwojDZ/MEt" ..
	"Ask90RKVLxFcp+Od6gdr/00SMbJh+y4puVolmZigBAxHt6nULFv/JZJYKP3pkfz0pMvwYNGLldo5Zc6wMkBTrJPjyBTeJFJV4Lnl" ..
	"FFKfricqs5kBwmU7ixRdL+Dhjk/9Elel/M3QwJfeEfCZWNluUKBE0fJ6rjuM8tNT/ItuFds5H4/9rGUNYM3wPVk1TvjCE8n3DkA4" ..
	"rMRl4enQku17vqCUwXDgxuT2L3KDtP/saG3U4g1jI8wtR6we9rNPM2aCHc2DSMAvbpHo+aFcBpqwwpmjsumh5kK4dpUMiYaRPbIm" ..
	"+D8URaMUxTSxdHQ1As0Im2mAaPBpoGfRFSueYmjabXofhOmv6ciqxtp0X7IuMMbY9G9nKwkAiX0K5z+PBqhyYPiL/GOl8F2QMMkM" ..
	"SCK9o0uKbQA07napHHf/aM2RmAPqc6wC6GbFoOFOTAaDASiC1LY4amdZXChoE9QPvh6NslPBTEXqkXpISz4f/65PzntvjYU2aWyF" ..
	"kwFZX2v5phVRh8MgymjZPjFd00v4vylvP6Lw4JRuiHHaxKyPyLg5l2bnfXaaCkcz833c73QS49hmsKUHTBMPQIKrcrdQuKHyqDzM" ..
	"ROYooTfmtPCy8kxP6danB8s/qx741wmuImrtQA4a3baQohDCncaSeEPJzsLtA6TkN947GT6j3KtKUA3feW0M6KX8/uXETA3H1v+6" ..
	"uVKv9R3j6fvptNik37fDJh48Cj3ThkTaOiHxKf+Rlnz9CQ1M5hNnIGrfIu7bCwi1oU8KLil5IptcOt7NH1yDDQmO6ArM25WBTHWv" ..
	"q+gnr9kAFcpsjvElco8P2keFYyNwz+lBAAbTxLup8rL/bLfKolRv4yizetG7IihVdNfvSVPU+Yyarm1XPDcn5vczBO+y7bLrXVnB" ..
	"54vlCY0Ucl6aZzOVlcqfXZGw+3keW9hDuH7ExLtFA80LHUbW78xmpNOP8qn1qkLQFw/M5D6DbQC1sBXhXqbPOctbcXpy3XsgAuea" ..
	"44/KfW73Xo/Oktsypcikn2+S9xMFORQe2nl+tvS5qP5ykKetXdsEy3o295/Jx5/4Pt3QqYDcfOo5TAKW4H5oZ5lL0/E4bWCpzfku" ..
	"36Vf94IEx+TuHxzyOj9nAYpnlymzq94mFfgLgc5ThmKzt0q35Cbsith2/nVnHt0T2lBRxIPIIXLd1FkIeBqCtGGz6214p/35mCW2" ..
	"VXSH+u3jUpM/ey6EVLg4OAbxrRXjSIU72ugD2ADU72LAW/BKSiMKZea+qv2FX2bnLst5vOS/0IxfCjOQusHSaYcmw9f/6X0GxL91" ..
	"7VCJyi5D77ELua+nplWbnqHaXeHnmXAvUq09Z/e9qN3T3achIqAaoqLRGcn91hWL5IQYdYDLvbHzeZ0fWS7t2GTVsBmu88CZp2Ey" ..
	"bQpFrMW0213Em5uauPkd5Vz2QQNli59Pn4PrpIZBnyfCPrNBINw4sYAlL6l3a3nIeDZROb/X5pxs28tA/6+XOs2pVsn0foNPgdXO" ..
	"teKJaynP3k4iHxU9uLJBSc3uN1d01f82aoFMwfUOj7VjLTXff0AzXnYqha6COLTdXswoVtT4jZBSC4W5I14JSd+bS517XsYaZUwH" ..
	"9k9DJ6j0GdpsRSpPDpi4+nOaZpEyeD97/8EXwvXkBs3A9Dcf0twyOH+x1HGYjFott8oVO4kRQ3dS2lVgUkTsZEYZiEY/osfzQjME" ..
	"GkzlTgGoLrbR8uoSBQkIuQlq6xAv7zDW2yoddNBI/Zog1Q/j8qBSDvy45eO/ROXvf5Upjm+7ENXZKa/p42xfRCLDHIk+/pOr2/jw" ..
	"TLUVndLgasOS5iU6kPy/+TxE703rgyaF0X8KZewD4NltER1RP4dAqlGkIkuCbJRcvYs9nhszuiD8QcwA1g04BCc9Lv3rQr8puWob" ..
	"p121geslgnSUQxOd2AsXkFpdR8a/kLN/Z9sJb7F2M9tp/5m72rVITSgZN8gxGQ9Wd71T3jjnbAIKThAx9cjAU/T07fDg9NMAqohr" ..
	"L5NYHhMbsmcEk7aKvZXvvGs7oTQcXhbY+yaHctaIqJCMZ1bw+NxVbJKpVoe04a+49ItoTzWYnyp4PxWcMiCeo2oKbGdZSS2XoiFU" ..
	"C/2wIf8Ydh0XG6dleFDYWi9JYc/TfbYRYoegAFkRQaKvwwJmkVKx+mPsF+ti3O/jr4jrAv0VJyJLAPmYPv2osA4iTiGhRp/B2rjE" ..
	"hXA6Fg5Bz7EBnjTIAXLvdUfG0rrJ2YGD9dcH2E42wy+tTZknnWHbeCQB7B7TaLxG6Fw3lsNgv57e/b5zfWaseNCUeOXKB4j6o3cC" ..
	"gsb3ChOtUd6EIjrvORwlzqGaEVTNdTjWB+ZbM8DHGeNrmoPvHPpHGGw/sLDMbSTfxiKBx6Bw5FF0fH2ArufmFRRHXaYirjYoYBf2" ..
	"tc+dcVTpO1uiE3GWks4DePZJx+pp9zwDDpYPC5Ud47FX3dvePIdk5dDGZUYNsBhSn/ROozh8QEYGgU9IHe1Pyu41m7+nu7JyEgqj" ..
	"ifSP44b0IblDgQiq18lQ9LMeiU/SbwpehOxSfw2XGJ22Sgg4g6b1ovT7DO9gniqLmRCrCzxXPRbmkG70l97bgJ01weLHEput1lkZ" ..
	"hRP5XAa7EDGtYo4AxTfhiiKnhjnpRlzw1CPq7J4wJxdoXe1JCDXVL6i5J0JDuZbgjOFOAEgBxw4aK3I34O5cvJ+i0vUWeBdcakx/" ..
	"nh7OVEJupYeBhdIx3K5PNRun1CVBQOaw1moSt+kBllmjPoq0XArrzshthDa2qkilO7txW2tvfwTrarMZ0qx+3jOn6j2BUYfoyfe7" ..
	"jLLbkk5iIcH60V9cvYvRi+0lTxj+fm1XAC08UTI8Glf9zTUbsmzMuGRy7yG5l2Fny9eG/AzvtT2lxZJpb9Sjk5iLS+m0wVzJTm37" ..
	"i0IJfU9HzvcRSOLJtOhU1U60kJdZIRTGjtOxb9PieViKV0cQLf/rI4Va0/iNj5f7IPCj5yrfa19FIFjcYSlS0hn+DhOCwVo1tONJ" ..
	"spxKNoKigSvV5eHtPcMwtemoLjUIXz3w8BWH6otkrKKb38dNcvMcf0p+0RWr5oiFDTUY//4VKZ5K1ISf3GDppgLBB7h14YjmiFLQ" ..
	"Z6PWgAitpFQFdG1WE81yIfS/MzIlyGCrHzAjDeKThdMGA6ifYn7HYvA3YrAJvDqdqydS/JlX5s2OHEH/3iy9AaY4Eb2yVrLtADyW" ..
	"h+RT0P9DXqhdnTzBrjbZsWuSfjk7quaQzwCVr510wskl8aM3c7El+sqTB86vsFuNSJsGjpA4r60K8uHKM2x7DOfstQ5g0/Sc1EJi" ..
	"yLiWPQsssa69HvspgXUfVlznvdftc9ULfCZhrdREexmPY5rXWG1U2ez3JvAtXqTdFgIXE2GSIllxidL8TabxzCr8UM2H41GMJwXH" ..
	"TuxYnaaciXfa5NSIniP0imhJrDTWGd8vZLcLVSv8TAKGLkk5Jk6PbAcclsBXo/hIxZ4uwUZ/sMbKReZiRxs3zuo8TzgwjAi3+PaP" ..
	"0N2fezU1Hmdy/RFrPLiN0kpv1ip9tciQuo3zkeLZ4yMPDh+YvMyKnwFvz97mgj0Y+OGpyJN3nIt4K6wrbbu/aurkzH6x5wywCZV+" ..
	"DLMKvd9eDh+OXqVgFgOXYEqML/8SpJLKjzBCNAGQ7PhdpO5/DDR8FCVwiYfDuj/epYAY4pZj7iPK5aYcJzmB8aFY/Zo8Q/GoDOgH" ..
	"wbSIsW5u5pB7lGRae9PRHEU7zUrzkC5XnEJLijq1KFPKxeNg7vvyaJnsTqZHGfDo2722m054faZpTl2aOOcxMD0d9QC/7en2M92k" ..
	"4COreQUJXx3NxoQUXa4A9a4aRoxvM9zphhDTA75jNxmaJzjWfalhEK6zOju7FdbhKnPy9BQzWSyqMpXm8mPpr50wPNxekAkKXilq" ..
	"6+ZkNnzs7ns9wY/JCusic+9HZivkY/0OL0I9yj7HOjG+RCbYhthArgea0z0j36Y2NI7jbYSe0lIebbPocHjJW0kSa+4J0Nd3L+Q+" ..
	"EkQzCU8Vo0mx2mQYuPHcHEQQ9l9u/3zV2cAw6lVgXHTvVv82RH7ZiuD3jgv9cSY9bl4snv2Ja55PPjJlPDH47hD4a7UZ49AHYsNQ" ..
	"ho4ZjynO0hQ7r7gedDsg2+22x0svVDmyZaOndfUtvxR8r9yCO2LMP4SVzLRPQ4u5cjNADhkXlo/3Cb6rI6RveEoVbauEr4jqH81o" ..
	"XOwT/e9CQ4WR1/X01O6at5C1hpVS+zoNT9F0bEJ1B/IbTklty6NOMzf36aAiRJpVi/xRskkPb0eP9GcTUtW8WP3/QRpsfO4h2Nf6" ..
	"JsgnatLzFTg2/OdDOUEwK8tMg4DR6Hy+drcg9+spRXqNtseDqpshb0NuWVZhrQgK5WZYx4MBrlanWPTKm7aC0UfxA9ZEjrUsK4si" ..
	"PA/ZeY7wIFp0lmfOYOHfFCT1CzvuOywwT2XJ91DYHZdckVWdQvnj3BmXCebVLjbcE3oe5xByiEnr9bv75+dgK7gZhXv9Ytu4h1Ge" ..
	"vOIISAdq1vOu9zn5/22VJqHuzgZ4AUi7ZI7dJkP5SD/jy/tDA8qQBu2l7XOSezhowh/DBGnEYfdsOOeVxfhQ5CFVCR3l620WhI1D" ..
	"9AjNycZuSoMRoK/hDEcZqzcgHfCUCAbVqDU2dHigA2RvKiIUhFoj+FHQwvJaKnOD2UGOmbJvUW9uEhnUCoxQd9GIV+Q6r4zYF+L8" ..
	"JaxX5b5tB2q7kVEen3chL/Rred33YGHtwRsT6nXuRbfqS8GxHAFYnI6vkHsLLl33xGcj8/4mLbnFnAIZiRwibd1ayHof2qWDsaex" ..
	""
local PAYLOAD_P7 =
	"cjd37XSDjgElcgCen6OKq5fNdFU2LbqLW61IMQCXjaBjdzHQCA3Mm9pt/ShaNqVwGefnQd9Lruc4JM0qjwUjaeKArF1q7nQqpQxL" ..
	"s2awj91oTlqcl6vA/Yng2ijGxbxqOl4J94t98+NmjCD1KpQKuvGclWyRwj2lgHRJuHcESKf6RzYqJD/oX7ZjVt7uLHpeAY7KDcsK" ..
	"nwQ4N2tQDY/hsvCwmK5Zi5bfUI/Rr9c/jx+26+zFWkSTVTnxABvnq5+krrA7N7Fm/PxT+VtigNNJ3OCJKJlrzGnnufnupJNdkKfW" ..
	"XJUlheSH9x4+MLuFGZWPlbfTRpAbFjABxTgBGS1146/E80DateyRqkWrSPplAcOFxqd5WJ06BMnCODQbWsZKatrCjwvHWv2CFv+k" ..
	"mNm87OU8WxSLGrfYYLmXzyZQQz/q3e/32C+tza0vcavMaKw4k6bG5MVctmmi4dcO+hfZvpeDOKQOGjiS4Y3PsrH0887hhnxCORQF" ..
	"NKTMHFMW99dx2PUlylQxQbX820E992T8vbCK1i2ps4mnCPP/bjQhrW5CAcOAgnmtHaxS/o7BkNliyY1XuziwlxEBPJ0RkqjUf57N" ..
	"MMlN4zpAkWdCtaeqMmV+oCSAkTb5N5wLv7Dngbs1VRVnQyWTmj/VBxKNvifcq/FSd9VtQ+9NwjkmgzG19bhSNbu2jya5cMaf2hqP" ..
	"SaWyjJar6EcrezAOHiYjWqJn97CgmtsPSYaOKmSGFwWLwUe1BSDSsz/SPbwnMfzmmV8p0ciGbIzWFdOsdok6ejTQSQw3zCtvpeS+" ..
	"d+L56/Sf7QYVP/w6jQfS+Nf6OrRs8OSSiri68s4X+zUe+5ryIE6bfiTVR9xe3jO6t2eVKfAsOmr5Fj4mcCHeS+b0Rvml7E3LdejO" ..
	"Mn5ZZvYjATB9nFGvFit0cJTpQiJCVhRvUubZ2UuTdeoSzY0dGs7XStdSo3vnH3L8HGBhSndADBl5FmeiLREnszKeW5XjvnHfCDzg" ..
	"8V7QyDyUaBsLnLpH1fElf+Z9VSA89gOL3Etgv3L5/1LcjB47tKfIgP5nOYiQlF6yvfwLJeOKogtFJbdKecIKsMpzx/bDeEAbPOMD" ..
	"pdSRr/AVFurzjHfPZ+DiRO2PGv5BAtPy9NihM6RgD6FOTFeHPuwsVRdJTLwxP8JxAq4I5Bvzzot23i7kip0PgTL8LAuA1hKU7fyI" ..
	"ra5bzNi+2aC2lP0j++Cimsb5/YZQr8yineUHfR9BhDYoBrziFsKblSh2AYQBsEV9v3p8XoTQWn84wcFx6jgVPI11vO23mq346BjF" ..
	"L7xCh5BDmW0iIvVLJ1zGz+OPIeYmOnEoV1Mx/BmYzeSCuOVk7zz+UiBEtLQMznbHXU6swKi/IepT+kMj385GjtXJbhQ3tVYGdPJE" ..
	"mzJjkoVDNg7jS2fMSa1jokmNOydTgGC/9KbZrU0c+9dDRaqRdorhaQFNwTnntC9+HSufApIPpqg/SmNveUUdkNZvTUbJUmsnTBVR" ..
	"oT8FPnGVFP7E7I4g7tFANAkC2lTnoJMh8S+cSckSN/ShZwW/G+Hf8nb4K+xotYo+JhWdcryuxIVyjcPdj9LkOObtjcEXDdJZBAzo" ..
	"ThMzjuIARxKOEh3pzxVH/9+jy8gim6QlqjGEqhTsil+YfpmtH/NZAEPAHhA4dBwEH2BU4STzlwTKizwoFlR8cHydcczf97xIBReV" ..
	"0R//ep4bOg0+t/nBKlBrSLaODqyeAS8gB/925r3rPviefmz/Cl++C9Z6FiB9sSHJCJ0ohsYNnXE5fKa4GbEcI1ZH1BypKt5fAALF" ..
	"dPm4ml+A+PU+3kO+LmedILYArS85r/rKww5mu7ESns/VIgWexRuh6LfgFrRQLABaUUdsy+CaQyI8IpCqPcwPDF4b3yHmGuRpcXyO" ..
	"JmOY60NMIrpT9fgCnP4n2+RoFJg9mkRItuX3ggvBi2UyWHyFfUXD/RAAmP45Vglt0v6h0QEwY9OpKYzA5WbjJHr1x/im+OVmosPJ" ..
	"x7Yd0Un1Jic/6XjqLFMN4k+QVXOnfJNO3ro1AA2I/ifQBkAezUJi7DvdQMqFt9A2B7wZsVEioI6qaB/dJs7eXMGD/XdGVhK4JWfl" ..
	"1GQ3QB4ddKMb3U5ih2NKLJDr55lt+PR/jKnjhtMcGs1IYKaFNPhrl0dYuvcmPWNMjzhePdjq5aMZHf63JPVqVhR6xMBkDpNT1whl" ..
	"AVaP+Txb44b8oLdsZUQhz/sUeSKyhF07sgirMpTNn/ezQPiYzVw9p45tzO4wwHWJO/JncXdZPO4swVKlcNI1SoKBydOX0W58bCNR" ..
	"812VQ5J/+FaxCc6Ryt1fxqRUr6ld+8niAbyxDSUwkd1VqUT9xHi7MIWueJagPFRDaTqOGaqGSHNakwQpmssKG5IHGDh8/Y75QwT3" ..
	"O5JfWP9WnfWdzyALUAB9l/aEPwmry0zMA6VXH354pf80SiKKa/I0WRVBfeujJj00fN9AcbWXny2ZbcSqwWmfKKmAlv6STDczlOsi" ..
	"kYWVInkrOwHfZaIa+J7qYVRsmJDfAIZxHLm36AdY5jq1docDVy6VuA8dqYV47nbEN2TyitqnWxACYbJ7p30Ra/COwHdEj4PKD3rJ" ..
	"l4BPZPkAH4DbJ1Oo4iLReriIERB0bg88OcLYZPzT9JILVT98bIYydIF9jTj8A88KKjOGfuM1CnilpHNh+UrNd9AhsxUQ3l/dIXSg" ..
	"yRBcnUU1veK/KoLHE/pyhBD+KqyLMhdKuHDQxRONqhZjk/UQOOoDlJk2IU+KFiZQTzDDKNwpym/rCqvUSvppMzjsDfrcybrN1p6S" ..
	"uwC1O+uWr4x6hyV1inekqFLPMf7FUc4gW3xrf3IZ+EBJ1OWnhP58d8TvTbDNvqgWje0IMUS/OfY6RaS05HsECHyZ4jkXt7Id9sie" ..
	"M6LBkdJTCht2KHPH0TZdwxubf5IVFStvLU3883h5VYqslRn5cP9fbqqp14l2lThrZSfBfKKoJGmyzviHI9U2AYO7SjQDCy0w4l6r" ..
	"ILE3NMB1X7+jfg90ijAQnJh+HUv4JOH2tiLY/FFVz1wINfXrNfj6PotlDZkeHQrkOF3IFeuuadwL7+guOsPlB7IfRa0pPrGhvSWp" ..
	"tgBDkH/fvaZ+4dsvnK0RcPTLP5lSvQWIjefkJlBwQB89uKnetAG30UYqxYYqb1c0Tdpztr9meX1EqtCiOTk9hQ/dxuQU8o4Laxmq" ..
	"VkS/5u0qyrlwHgeVz05Q+D74CCxCjpINkpz9EUFigUMQa7pbnva7RhAA3vlmuv1CNSE7sxutwAFPYFtkLYwREVxEhhsNnTjenoGf" ..
	"OTkZ5pePO3qyPeZw/4b1GvBtfgyzjBBKRkcWYTOf68HWPGMvTfi/+sgQmMZuENFtVDVvKlQLR4HAESM6FE0aT/RqhB34l9ZbmzUF" ..
	"HtEQYVL4cc6RXOHbHIy118rRF4qC2uE+kJhl5UkbLXdgmxaU8gRJNzm0b8MBXgELTpy4cdE3Mv+bzgxPFgGGPrYAzbeHH+5tD2jd" ..
	"7GPzUaxy304dwjFzhzFjEKTFjm5vj7X6Bi7xoCta8w1ZKRLq6qwQrLR3hp5RyiAjD1QKWIp00dGasN0id0gzTuIS+eTrCckms97l" ..
	"w3ga3feOlcakuSp5rOkuKWfeLEnZxR1hux5B3ozmGUgkwnTELPc4R47jET6GG5ug6I/iZlSnTbYSwzrIVRP4JTyKq6QNMEV9XVtY" ..
	"uGtv0RxNASrxKyrjUbFWmOTCyS1cKOJ8/a8mlOh5taY0MPa1iCov2QV+9j5X2CJBTr9ZyowhePOvXDF55yAI3LMBjN4zep5x/4uD" ..
	"0BAMAdKWthWuMtVxrtFnVg30zysmr9e32L+tSGjbxT/cnidzrRaHBLvmogTHi9Po6mYj4RssIpyIT6u0Dp72vfMj9Ig64HWB5Zw3" ..
	"9loZPdaCQ8r+zoRqRF5il3JpBpxtBZ3iEhHhw48yhD0pcect+UXYd6A2POA+cLPXeXBMxeQ/igq4QtQrngdyEfZiTsbfBHQ75H7D" ..
	"0Xxb5g2oxbDEAC1uQAVvQb+F+t8Ir9oxuaxrgVX0duG9XKtEWfDLmZxe8USUIn30l6QY56PkaO/MqaXQBc4RJ6LmKCZ4ZrLQL8Wa" ..
	"00lOc9Bj6341w4u7xQ4G/e3PxxAFcBgFATTaDoq+s3Yad9O+ANHSwooo+sUO+tz4HwB4n0dFqFtv73WEh8WHKfXOhhjSak/SvPyB" ..
	"vhCHgwrv2hIfzd9krnQ0SxWao/t9ow0P0QRchpvxiidXWD4bWIGT8IWUOD0Uaq4lcjGmXxLUtTNIUaTVcXuAurGxSHzPvF6jVZS8" ..
	"xO/kvyKl7yAiz2JVCzZDioONaWwLgvMaQKT7UVf2YjYp1d2Fh32WgYoBoC83xUrdu2WSKE1xuxCEFtYsjVnHWn0JqWc5p3IHPTl/" ..
	"YlgOvfmmtawub13RI7OU0ITrLQMVVSPgj3gwSNA7ta3JSHQ01FoeeSUhEzblRqV/Xyf9Isf+fU44oqIUl1zHFN11jbBU7kjCuG++" ..
	"4/KRBa26pChPgNiBZAGHmdYclvXITj4Kuxws6CBibpeFH9EEE4TfmmEwgyI7ZAIs6S39lOqGVDac9XT0zXb+RpWCLASqTV/gH4br" ..
	"H2wyHUJWU3fQTuuNfAyLorsEQdEHQnHb4h44iLnMLHQRdxqWH5l4XKXyHUwJ5HP7xxAPXTxdCgCtgSkQg4xYQGJQf4RBIu4Dwu8z" ..
	"aED+KY5/tH1v0edqkeUYMIKnUZ0E5ah/HFlu56/RuYT9iAwDpgEdbIRU2nVT364DFHAk+y95HTBL0QcvLRpsl7u8RAqI39wkyAwC" ..
	"yMfUGqXLzd3aoYjzX7w1KyUuokn6V00+trU3bIUWHObBvFIDO6cE6Mw2wgAap8PKDNxBIAXgIwS1/sL7uL1iNvuB3P2rpnF6QXo6" ..
	"YAJFmOUr1MVNhTnz0FappOEbH2/hIuXGQ47WYWjJy+W/xvZlIOKgrHBmkFquFgxCNqT0Pa5Dw6lMK76dBaPar4o74mldhgx6Wzqi" ..
	"8jg+UxiftEcAlvWhKow6+9opWX5qo7rRoiJz61ZGL1y3pkfDS/m8A3LQvDLZAI72gWguchRNXhe0tlhbv07S0/MzKDVgAToxv3FL" ..
	"JtYLf075j5Gfi1+xldocrHKBKSTBvs6Pk7VSrLIXvMs9GYIoDozufZSUBr+gnOC9e1QWMkNk+7fyC+R+1IhF6AUQ94RBuTyclNop" ..
	"+DSBjpbeWwm0ubntINqdT4N1Sa2nJEaeJNZqHWkq86serHsQlB2nvd3vwYuxx5sToX//F8fD9foFcGk/vF/BrRMkwuCInvYnLwxS" ..
	"/ZBei4xKp8d8lAGcmMCVo1f6qIa7lUX1DWYhS+saTYXaBS0Ii/n8xOHwPvI3IPSn3VMV0vVdkg3/P/+8V7zR5rRzByQgF1RLAYic" ..
	"6ioJopsK+sPTSTXBjOk5LrPLOMu2l+uzBj1OKSsMR5VMSYzWEtjwlzu7+U2j5c3WZ+gExpQJTXAe+XlrzhRMzYXFZ/1vlYR3KtuQ" ..
	"GjInuD3yGKFf2jG6gEg7eYv1kTJwYUcEIXL7WDsDV6fnkoX2v6FwrAatHK0wOdO5vQKC7Dc9VGhTlYAcOloWXjRBQthOUPZYrhS+" ..
	"m1/nLEGzxfUjSynXLxjQs/6eLQjEjhObQfoMGKS3HWX6sZQFmW9C8nclJ6YfTwXx7eVcPDvnMAqGIoc/BeyAI1qBm83DjwyBi8x1" ..
	"nJDkRYLyUgRsB8EIIyZFNKA3Pf0lxZqyP+IkZ/8Ze4+kT1uIvtbgi3cyeh7v6bkC0PE552iuQuZIStiBfgbt/1UY6s6tmhpfoX34" ..
	"UxpogOi3Z1iS7JTHHSLEv1VTS/XHm9b/QlPpxtf+7DhTDfE+F3Q3/DYfEBHLQlyMsLJyWutOnI4VeAYL8N5g/OvkZ3MvfPKX+f+8" ..
	"pgfrLy09mCwQb9WLnuV6XITgAOB2cYHjrVVpKAIQjLpC1ftypze12dPBTzw7/U3Iw33anqlDWFu+pCsxKX9f+yni3RtNfaLpJQDm" ..
	""
local PAYLOAD_P8 =
	"xNfZC0Th95NfA/8Sbnsus5NsaBaeM1+gZV0451GHmEdPKxUWdJrS4rSIp5urJ6vI/sRHCYuPVrCkUWjqrUYsG78NnYxkKaGZt2iJ" ..
	"5I/RYxvz+9HUN3qrJemWpfJfBEJ6Mp/pIOL3dzbe5uf5+SWEEMA9GB0ahn+gjPgRPhN9pQT1v6cEZl/tQgQ0tVfxC/YJ9mxfWzgq" ..
	"4KpXy/ibYBrNOphyTvY030nQFVejN/AneKgo8M3DC7V+/HUR7gp50rNTOFk4e8JsstF9AxsdDD5fiFy6bx5zrnn84Is9Fwd79OAY" ..
	"r/dA+4ZVedpzVBRwIwWZ8ma2v3JwXsOlZjQfUVpS9QZn9vvmJSRPBMO4LJWrXwDbvL+izJRwLixpOl7lKXqQkAWNiEmXgg0NMTh6" ..
	"lxoV8VYSEy0Am1b2O2mAn+S+bmMoI4EsJbGua7FFh+Hj6n0SOt/H5nmaxt1Xla9C8m3XApsZSp//a902F3hfPNV+imJEZxeh47Jg" ..
	"Y/kwXK+naojW9L5Im+r7l6/O7QLqnI+Xns//vnTaa9HIP0DFiwHgHCB9zMF0xtiDaRygi/M34GOzFcp6xtvHSY5iSKHE156kmKN7" ..
	"98huebC9HROlrL8WO715X4yF9Oj9tE8cRAy16DcWtiiXogTdVzgXkSiJsL79NB72Gy872+69VqI/q0IliibYeyGhlcudD9f3Q3wl" ..
	"ffyCIF37XBVYRYu0y0jQishOpEnp2V7kBYWT4Bj4oh01lAeD4ewI9ln9PiofiW/C0LXXw4W9TTDalcDKxnf+46RP0PzpSf+FsQJA" ..
	"9kzlMnCMJFI4tFqmb4x27S8g5XgWyzihoJAK6187OnrOMd61CjcM4hqmDhz22HNK0YCFIxSjVnuu562pMMAuedsGVbme01UF10eb" ..
	"85L900zUQsdSzWXExMbWW/Y+t62AAsNE1wtzN2q8PWsa1y3irPSNuNBDc814WpWtHnAn/PKae87eIpBBcTV7tjYhdYXsMOclRUao" ..
	"C/hFwbq0bjeHV8GcZU5j4ltPItIrsywxXo9K/G+2pXuQ+Cl7/lNOvyxVcaZe3KnKJWKyuQuvmJz2/dgqer22FT2sr8T/CmnTbqif" ..
	"5FtpVerAzyxNeL1k2Iinik9xDm0WHw4NeBOrESVFsxJnZSnzhYFzcl2CaHXFEi9IHlyKNlNMz8z1xAGj99xaaGoiarFN55rKAc2X" ..
	"iEbwE80FI8PCSGLk2/+7ibZ2WvZM5XwLQnVN6q2hPwGcvBkyR4tzeogsyj2aohiqshIbrPxyS/FZuTAIWHu8U/Yspv2+ql0oAOH0" ..
	"NTw7snYSnaG9LQGxWP6nN85rkAK/Ys71ELvNv3Sdi7EliooT+Sg0uN5sAUyv6xb+fkC84bUkobNs2spSnZvWJkxM8t6xJ/pwB8Ji" ..
	"INTW/pN09FX71T5QTRBbii+YDhbiRarqMY32KoXwRxMN2lT4Wr6BlrNl/FQMTBLqPOIpJQ5V9TC1KpiB2R14x4fsrCIhloTbpH7s" ..
	"IoR8kLK2ZVcO9vzd4yGcJ0/G1wD1CFAoQwWCpjJBFnR3SG/aLJ6nxEhb55E64FF65AV5RGTOAINQdbjvrXfriMUkDy7i38zJ0UiA" ..
	"eNE5Zw1U7Hz3aa6StAyeMAUzaxTE7HJ21/h2krk3N4zGSQckTJaqOwZVPBnYDpnd9laiUObkynnqNDuk/0I3XIYscmpGsegSF85U" ..
	"8tAtdAHonnGGH3aNItFlU3+Wikd5hv+s3vPCpz8Gf6/uHyQZn9zjzKC2FHs67t8R+3kFFS3G/H/dWH5UWP5bffkTViioDOcWGdXC" ..
	"BZyUyP2MlCpQvcdwGSttDx5Cp07geIo93VxYk6Sb0m0Ck7Rr+zVYFCOkRgmAVOAZkB+KAARqaquGxf3oII2y9/KQ7PvniW7kdgKz" ..
	"FMlsdiKgN/cRMxibAHBYEzYIrA0jWHP3PRkPjqk8bZr39zR+bKUaj9hYoXfO4ts99i8g0OgCJz7E4tHXRhgh/TBHSu6Ijky3bLQI" ..
	"8Z5FSKIKTg3fML87yyl3cZbIzl33P7CUfC13ujS1I6jB7YqVH2xZqH6MOznxaBbUATY4o14idag4UqeeVxABJnAH4ANszabhhONO" ..
	"8++GbkUmj15yxu/WwR4SCGa9HGqRs1NQ5CWz1dai0mt4b7If4QT61KWHONVIdjQm26edazJGbohwV0ZKhGpqEB+cfl6qJnfqZwRz" ..
	"s3lH1hPGgT4dqkBOZvzJOmKOC0MhvktZn8HCpZIZODw+ymLhQe4HsU/4JlstPwE7Bnp9i7q7NnhdFNrQVpgdgCubvi9UY28E3FEO" ..
	"JV65sBCxnSwKmsJbfiaKHsrHWqeLVD4w57vyRhc9llhVKJztJLHVK1wYDeIEk3U/fS5i0naBcs+JYwiXWJWFpI5irnjdpK0AtqoM" ..
	"ilPeqtXq3zJDPdxwTHkFno07iRSFjpchi9d7+YsU8mYiyMZ1krntygUV/UzmbWH7MQMfDuyUWgPgklQ4ibDUNm9vzQaMH/PU34cT" ..
	"1yuzT+tzxDr3qPZg85UGlx0Npd/B16Y/JE8M3OXnw/0M+F5W2fFgR0MLmZhyiEa5Ve0l7KzUrywINGDZl8KMeCt/M2DxbWMGaYFW" ..
	"9rJWn18WNzJiOtrQJ+QRWHP1/RNcN2BlP51v/pqrxyOEgkfMXy1PLu+/Zf8bepGSwT5TgKLqY4BwulEn0k6ox4lhtBLrNnzT6Cl3" ..
	"9Vdab7bFCwP3RaPq41bJ6XVMf4RSbpDIqR1n+1hkMbPPpawy3CmQrB6lFHW/FhAq7xod7BKFu/Y2cdHdl6DXju1oa7XCFgSQLcDc" ..
	"PnCAMEVvNf0CoBOis7h4x5aK6utDvgY3/9alJHSF7UbsAIb8geIOPggiUNhGNuCNW+C0qo4PzEiOrzo2QLCiXM7YwugaiqiBNxA4" ..
	"MFF0I+2PcxZUpKnDUPD9j44mnvnRnp6qdrA98ViXFX7mv+fbb6eFsUNx5nJKFQA+lqZTZ9ZOUtohtOdsET5wuJGSPeuXlIlM6A6u" ..
	"7225RBbfANsqZCtGejV63CJNoblY68A42gDxVSJ7Nc+5W0qVqBg35aP0ouz6CO4G+B9o62CIMdUqibpjIMdvfpryKGToLyMTtqoP" ..
	"VF0giO/srooUs1cnfsJz3SxQl0r3lIz68t+bUVxc5GvnIfjzDSx5Z0e1B/5/3zUAfN/OlN7mk3SJNPj2Smbw7O/V1NaXCeh5RlzJ" ..
	"jAGqUDbBMz7jpJrAGeOI5xzychcjyKHr+fAyfH8nUWM7GcCRLgGcyj1bGpB9EjWAVumDpbcrEWpbMhmbX7tQ+1dKw5hHchLtKm1A" ..
	"QnwMZZcTQzmXk4NHhMLNNE9d06eEDNLxnbiOeTGy6RWEpe6x7T4K2uGQKHjVmGwDkD6zrE9zvUGTN6E5rd0CoWw7BNfIYLWVL4Ju" ..
	"Mxe3QaRMRVskcdykAWa9LlviXNNk1gUI3YxtlzqFp58tRhH+PKFBx41RguQH9UQ9hIo2CG08kDzUejCWSq+NuUhFqdQSUNi2BM2A" ..
	"9iKHz21anpaXye5k7gBosv42aDApDczTGjpBeg5qhf4ObB8VZB6P/tKzUYgf0U1evEP9qTrIrR8H5WdFve8oVbk9gJrBLCI4URsY" ..
	"1OvmSG75J6AMUNN39+a4GrF3Iuro0/qnGfV/PUzU1iabIpDKjuXNGLzyEr/0TKmdZsHvvHK+XvLzYhfaL5zUPJF8yDZHTPKFEy+W" ..
	"8+bqoPAlnEJfJQqQ7DX3G3etknreqzqiHJjcx6eATM37Ghzx8m41zkEEhZ5hAmD7FoseINozRb67j/VBs/1nz3A5fNjIWEe6GRYK" ..
	"BdcILf1CcHdo8YMXis0BIfwDZ3kEkE3WVWiX/HBTfzAqP6Rd+ESpmZ5kuowZrH65PnZwv14R+6arOI/tZT9B+koWeS6jfX0JkNfw" ..
	"7M9bXbhr1+MFerj7T9IcYnXnXh/tkQBlM0hbJjlIkqlZ6EQ6zwrZ6xZyPcNIA9J+HnFgMpjVR3CAc2DGZIC/PcKxlITucRm9WEXr" ..
	"ES/cq7uSicMlS0itEcmYXi8E5ObnWp99xV+tV8m5gOle+tPqluGmgDmiCNtNrW9xflBfk3lqndfHdRBS9XwuhxhNPJoR350s9UjR" ..
	"56f3e9yr5gb1/QbTYQUPWPsd1bYLdzArNLfbQhLmRRiEpGBMOXIrQksXeu39WyAgvUi0ZDPfu7QsTDuC/eU8hWqGir1AL0kGUIH2" ..
	"bQa1MJ2aIQyc997R2esmLhe2Ys0n5CeZNfzROGvL7rBSa4u10/6XVuDJUETCDP/6PqBxLiNdWe9KO0Ov0mzEKMqNVQRq3luEu2RH" ..
	"V9mIaLwc9j2UUmqf4AlmV8b0QwN0LiWOK6+M/ufvO/KHyv8LhndvFKsUGjwSp14W/Np4rx2Vm5Ikv8fCuImXcw+W17C6vvy1Y3TC" ..
	"6lJZbRxDJnmZXBF82Cej8qBeJbgz65ju6e3oZPLzVWUI9bnC4Pwun5ZLgcxAD34di6BrG9+YVhLy9V1YYtYWvj/55Cj0H5XFkUhj" ..
	"H2vHCFMQDU5yzIFDsCyBuKKvU6I5FQfqG8m6rtBe/JWT5cJbxdOQOB9cK2cJXOBxdYivqxA7pnw4w+x7bMwXfElTem9WhZcqNKue" ..
	"mOoqLU0PTaqIPWt5muPI3I0klFkScWLLAsYBLTP+A0p0smlGfN1aUz5EaAD0l+2Eh9Q+n4Q+GIyg/jxsXOgiXatE65HQpmiVPl+J" ..
	"OsDwthiQUbD145zY3Ocho6M5h3Q4N3qeCrdqEuW0oq/wSdC7nnZVJmKUitSOhnr70Twii3ySBvepRswP5ORf0nwiPjCzVRiIuX1x" ..
	"iZNs5CSV0ULYCVI3NnUuafZsvS0qOUdaS/g02iUoPzWKqzgEKyHQ/axmlzgB3woG/3MRrImskmaU7+fNnh1Y8fNnQ1CiUuEpaWNA" ..
	"VMT9UlWY6fPfsUde+nk5NppH9s7aezvVzM+frNpakg/RHxB80vMH3k0Rkk459lpA17Pzciiy0ROtKufiKMDU1mMtSODDDmNIgyvV" ..
	"i9K6whQxlNMwLqoF3wSEsHLn90QMOKiJRKXfxe9r5wZYTzEOne3VTWmQnaT8AdLPyi3krDFxmJcFtB5eqZGyzhkyyOL/q6hXV5JP" ..
	"estQpUX4hs+0QqgpClXkc5VRQ63klXLfCYkkr29WWTHKxSsYtGd9sbZP3btUdLBqGquef40ByYBNBHj0FDBHzbgOBv21y73dOaLp" ..
	"hRY+LZn0XSJsG7wRhJV55iy+0BLizeca8/zjAyMSjUUmUwy7Pnr3PHOoN6uT4GO9CzVCN6S5tzuEY8MPi51nL4tayXCFKhcNfvNZ" ..
	"P5kdw0mnJRtIIWlMqNghyApP3SgnTTj1c1GmCr3gFRFkEqkKxRwtopjbWcpMVvDIWP0MXF52T52g2ZH5r1dIBXNEeJQcGbWgYb9K" ..
	"FL/STsZHq704otCRQHtRJolPdUEC9Q5wJCV9f9zAL/GB5F4/8advDCjRqJ/wQsXW4H4Hb6gns6ncrGIkykg/mLkn9hZYf0bfoIJE" ..
	"DMavumDmM4b696Vd9voPOuiXax4hjQ/7oiXCDuONK5SK6G35vme7hi4YHxu25Ob0jQTmmpGIILg3opCJgxopsSk51lerfacCDUti" ..
	"02A6ByzjP3NSfWEK9VoJU7Nfx3QGsphjuzE3lgvm9rfjDYTHLelizMDHPVJIK/nVxsy2CN+kcqtR2SGGa9VkJQB39ZYt8gmL2Ql3" ..
	"YiwEAvXVvbPllcmANrIi7oruLDqiVCE49fAhZwhOKAeU7t9tvsfBx77CY7gFe1o+GXzKS/KqN2p3Z8N+y7bYNUnQnxbkgWn9izfT" ..
	"zdO1vsJtea/MMcsmPlqp0OgP8y3SA9h6ZSmF68EkvYXP2BslQAF5k3fxwsMutstWumrFAyNfW1j+50vFd1L2tHel8O6wLG3s/MR4" ..
	"Mi7NnyU2txaO7OjQPsuQ4KT3hCoXpKIkQUWO+NtQdW3+oDGzKX2+blBb2U1eHZM4Db1IHSZokbrhQzBLDxTYbGXDyrQpQIIYXfTs" ..
	""
local PAYLOAD_P9 =
	"SUlQw4bOh2STZOWUUwDyJFFJZJEmps0L2bdnFHp2jJ5QeaAsmpcGXi4MXiqCv/ap+U3ukWDHVFRNQWYVfLZvgJbyFvD1wZ2YLIZQ" ..
	"qZehP/FtGgoLSHs3norclEQhFPC4dJp89fgPt9nYfz2Zg3w7aA1IQTiZb/7z7UKrvIwyYIh4cNkIWRKbSzGqUotzp99Z07bd46Nn" ..
	"LXb53sMvbiDACp6fiNjRcytkz8zovbVUX9QW546J2WQ2Mk9P5yr5pyt5J7DJZTFwsJyORA+DisQaNqjYDH+MTDkamq3nVxcbPscu" ..
	"VOvtaXpJOdW1b7+xO6KRDzSLjwN6OWP9q20CvA5BdVtNeOgd42+rgdFw9zIVggji/0rhCUEYS7yzgqXhGAuXXWxypqWdHOoVrAYL" ..
	"Sh7wgpAxGasjafWV6HUIJDy3KuYrnHA8GtZ5/WWV5c9VvkcgYEjVuWQiE9ya4q3sp7VsIBez/aTi15C/b7wwH5R2rOQYarisTIuE" ..
	"3/H7UBiGislElNj5e3zu/G5o1Y0GCavK/n846UbFu/zZVAluTkfajXg9HPjZXkUFnr0sdD0q8UM7Dd56D545m1VPiMjwwm+ipMzL" ..
	"CNg8Y/Cqatr2kz9vtYSaXUM/skIEilycfF0oIHBicVfN1HH834qNjaygC4+Ypeb/X0dfQi2kdhnnUbbNkAi4aAYK+/Zr9cnY95sf" ..
	"eY25ClA9+FYoe1mUk/mmGhXQJZQAzESfoMyVgAxdtB+52FyMQ5wWRVKCnUXQNKQZx0dvCWhrsUsCezO1QxCb1IwAEb2fZGXN+nNa" ..
	"jYLtK51TokH+FG5nswHxFcKRzZC8V6EjwtK/4bB1ms8RH2ZtYJwQGRRGCt0gsXAF73y6MuX1arbcO4V2m5CER3mkcmJGDiO6Ygp0" ..
	"DLzRoaodLZFE8iL74a5O3kdhw0wLHnbVPHHyRLBSQQE1vCD2Xz2M2XipmqTk9QQhMpZFEY+SSOa4uLW5TQu+ObtkmduF7eUoY6wQ" ..
	"MBmE+NkQ07uOnbW97MkDoFZDVv3vPwy5yX9Tto6j623w3ls0TaTlro0VtwIJpzZ7rU7huFs03rK5XIqGoBFSYkyy3GbqHpY4HjNb" ..
	"fH6WVCS3pChP0ub/B11PZsaJlVgsK5kEYTE+Tiqqh1kSfPY2isr5ILhdOzT/2hA6DvhJp6A7TbdweuO7LgdOehEZfXAfqEuDmdhp" ..
	"q6yrPw/GZYwrbjK6PYWUaKAvIrqVNhIuvJTtVcoHkjhdjbR3JEU4jjBoeg6hcbFIq3aSNwsKKJ6r0dBGRSrjwVhWoxdciP/nFeG7" ..
	"NquAfYg9ftXKIe21a2Ofh/eZP6+nBfJ8zYOBu1OC4vyWZjccPDclmRx/ircKPPrvlg5zrzEH/U7aCtn1zrTtFk9CDk87eWeNbJFl" ..
	"xnuBiQeS+MLOH2mv9w5ykeJARp1J+p8Ihos6wSoKVyi8I9a+1U2u5gDY/dpK0qy2ONT+KtJBSoby78nZ+5xukVn77b+ShTSTMICL" ..
	"EDZ6/JgktAiIUBLW1KAtyWn1UU/HbiwsgMpt4A9GC8wna5QfIaHVHrKp9mC66x2cTTAOblZqZ02cp9nuh/SXgpJ7vcZGziK2vUoB" ..
	"98+nviUW0kBzjYm5zXnEU4ROKbwjGiMW9WND4CqolMj3Vyxe7T9T8Oi3dB/jQc92RbW3YLqkVFaaMMbVLZg6QRiXWU6IVviYeEU6" ..
	"D1/exjAXIR0U91KYGngawNXejoxArX2QdvHDmfmwaoD4IQsnmy0iLW2KNzBh/pTA7GgQP7Y3J9eSLnlW4CoaO4aYcAHKMlZxAE3/" ..
	"QIWdYmDLsnSLXLmiA+TwoW3JVQLQix6S203u4TG1XxR3UVamoHXJi4ABeS4BXXg4VWpJnC2SbXB9sbrkAt/mi1GiEjvtaxPSTYgr" ..
	"TPN8U939GPZ602cz0xQ9hRioQ36UqZnK886owImbgnmEBLoHPUUrj4Y0rJSoxkzfWWfQ+8QNnfg2IJAFasxNX/xaBXTfz69ts5yD" ..
	"SSZtSkpxbYKv6AgQaOnjZTP9s7EdYJ2a658Ag4PILYIRVw/2CJ+t3Z73ltBMHBPFkW6FgKS/4X9tU5rTPty5uYb1yjStU35Gl4+V" ..
	"mLMxTUvKlpmJOu+Oh0k1L5DqHpo4Kf3Iy/BlOvl0UA0QZ9+MPZHWCFrLT03eUjK7djVIJcDfbYFJ1GfSVX8pU+2heGm4NX2lmist" ..
	"/fH3bMu8kseQpawFq8kqFJzkFdib/zQcrrjwvrXPzI/k1q83kVdfzrurDMb6mIgptzhQFL7gyBB/jzRmDbQ1J/4l2MKOzGlhu0uL" ..
	"mx5Tfmem9XCNE8QOEU2BPa0nklX/fRGXz7FpwWzDCOSaDAJ0qRJEUmuQw7aashhOEm7zH4ouuqIQY8Rjw2BfXGMjTz9j4zpNeoNw" ..
	"Auev5BQb5EwhRu4INJ6IrWm0pu4gEdF85Xzn9HNxd/YWfRCFcZDn1fT0hIlojrPwZArz4NGMI2f33D4RRlzJYG6sy1fmg2+Sx86g" ..
	"aR/LV4BqxkRELd41HrNqEG19TGEBJYFMb6BUygpGnF/Kczm3qG7WULplE6iOg20qiwj/YNpXRY7qozCSgG9iyjeGkkR5gbVG1N95" ..
	"w95yHNl9y3yqSyEG811Vg951tn7N0KRmQDuhamsrKlQ0wK+QTutNNIuhvyLq7HyMdF8EI7Df3b/QrYoT7dytaGkpGVm45QHiig1t" ..
	"UappShWckqLhIYMDkxUzZXnbn8jTkfG+Ni/hlOKLwNwF+SUjPAQ90N6/PCPQ46JdR06twPYAl9VNSdJcIUoWZuQkgzDylqlKvRYu" ..
	"xDwzkoEqoxroOIzU/Wj9uyS/V2yQ/j59dJTWxqJ2BA78UdGYd6Vq7bw8XK+sGhbsKDH/PtLV3bvLLaGklpcMUZMOmTKU2E+78zoi" ..
	"TriKbtIaTf4Z1eY/ajXXRqPOXE/Gr7EXOJGdUDI3TEaZxCmusPFYf7Jshd8C1biu1UaJpL6nWvJrGzyd1QwgLckksYKZM7Cp5av/" ..
	"bMK/yEI4G/KQwIlmIyS1hMNfXBWbZcF0nAQbrH2Pc/NGE+287Yru/5Yjuaw98K3gXvqoLwfWpj4P/g05ywlQFiv6BeJnrBOyaSMU" ..
	"9ZHrMJFkZKiNucUIGP+nViaICmxKo4mUSFkXJ6gsAvwX+0Gnxx/yxXlexIQImTv8f+sbr+8/RW7zmkwXU8680zaNeurfNTQHY7mF" ..
	"URTUxb/aq4geaBtFaHAx58zQDQhv6V8LFof1tqwHDZaGYjtSV6MOnW7+7TGCNu80SH9YH4hgq0vTZiF5b86SDI10HIiGwYgSxMeW" ..
	"lZX0wHuC0CCsYFDCuG4EWa2uPfXeHhbmeHIpKPzz8YOOfBGiWYRtDcVXbASZjp82nS6eS8C1G1i6il5iyjr7I7FkJXuFles2Lhr7" ..
	"y5M1JMnhHXXjsKDCMh4BVOQS5kZKWYpnTvfpB1+J/f2R4F2nnK53XqbPbfep/fNBz0sNpyPkv68/h+aVnAZqzODy6UL2XzAddpMn" ..
	"V8iK8avuczsHuGGyLQIhnfMtOeanwO4SXu4ltf12/jKdldj28j+nCUeWMGHXbSFLZMFByYa/RknEyz7ZjwuUvN0GlaH+Ie/5NOKq" ..
	"8WODRPt/8ufUIpOLvzDIKTH0EHnGFNCWtoKJzAj/w6OYOcQXPXoFXYN6REo/c5Wg7wT6iv4r9s3/40TTF7hT2SmGbXBFfxZdTHcy" ..
	"2lV7DFlk1ZNynmj4ws5yYMJLMls8jUpLx2uuGLASfykF3jhasKLhBfhzC8AXliZq4Z4tCP6HbtlD1r86qIPwNVfT7KEVbIeGlVwi" ..
	"4SbFQNlfEw4I/8NklcLZGWS+W5e1O2GhJh15ZiKI/NN6SaEWjn+6zpftp3viU/2pjVV4G6W+eFOZGbCiS7il4Ev3UPsOZkbb1AOg" ..
	"EfDMPaGnxrKylRQvfp0ee6Llop1rzXq+HMbpn3C410FqUI3MxOVAoqTVOcdLum4o+vZ6vGV0TlelfjXTBoeHJrCcK11kBFXsItBo" ..
	"odNmsPHVK5WcunKLktNkJs8An/HWkw4T6tqSfuSOefsrmn+f39kuE8dF8uCyqzxijO832iHNw0R053BI+cOwKZ0uhrjq/eglifxL" ..
	"VAvf1MMrYJhPLVis/ZVX9cM0920Ca8gRISRaLe7iZpwcgXIpI14+o8EXThKSmBWyE5XwWKIt9AnXHwc6RpFiHCSzNvGzZ/ATi4Xu" ..
	"IY7DcnUelJtFVmtvDrl7Ue3i1YnKlqZkLiuINjVaKXZATfvT7mQuItsvN9CyCv1uztzBIKpnL4tL+Rpt+Z6ddzqJ/0A46zy58eid" ..
	"q4F5+jx3Hw+kiLLBd8khtZZiaRyqg9eKceYbDXjVYvWyk/tUFOC+7K5S+HLwcKwU9iO5jdWgDzL7f0CsuHjrNNdEYP+u40Qnc4SV" ..
	"NU/3tjrBJ/Z+Lt3AXc+jpM0nGKTc3aKACXB3zU3pXdfHE1TaLJm0N6g2VeC4L+XmtAaXLw/kqFf8xfGmu7tcTT/3oieh0i9TStVr" ..
	"1tjDn4zCOW48vHsS9ggmofB8PMXSRT+PMLQxWz51R0nqpoDQZYHdYTv1kObDQGasNmXgTTIAPS8jVozVifgKmRutX06L6sO6d9ju" ..
	"+uhYW073hgSBYaDXsS1TQwGf1jgPg9/yYIPzZsPrJDoAGLykIhSOSd4wiMlMEUDmhFqLkVbsLJZZsbWNGbdrYZN6pD4v9ZWiMyEY" ..
	"kiILDdEufUwnbxuIKdZnPGQHJFysnLjJIX9T7LfJFzqs/oUsm00D15x7nO3qhuNGXF3QYbcP8JEYGET6XOTKnRwEU+Y83g5sDuW/" ..
	"k3Ooae/BWUn+ks5dftg7jmw5jtcpwVzBkKh05d1TJRF16ODs88I5W53HN1wfLPLdbZfTdMFYgRWVIbtXFMd/NXTRxbtWfyq0RXRa" ..
	"Cw3Jc3dfa7u3Ciwb2w2VtEojjXwHgsbK/PIU9wlzlsTBCxUyjRRvnLr6h1z7d4LzxhWSqqvM38Ih05AdnNBnlRd8lCor+XCIBi/S" ..
	"ythHCv+0BoVdGBr5hYUc76GmX0ghf6FY+2EJx3/PY6Z3dBFIrJYzqKB0eiiaQ94y2DAXteDAj3ALgDxGudo694pe7UQ3LWC2yJTH" ..
	"W2tcNeKW51EgwIR1gsMdySv+BooCkBPlWm+mlxOSk1sHpmJ/W8TFYqYV0zqxuoHyTXFby5sV14FHhBjj9tyJGq8FvRBikeaAc335" ..
	"YIcOt57689WbVJLu0KA1bi8kfAAyGGr1gswuB88CFCSqtvohQ/7l7iL0AXHP0ZtGaKVssZ3WChHJI82wGBuKNEL22A9mU8dbNswr" ..
	"cx1yNOCLSQYwg+TQA5i2oN66z8lw1wWJtGu+LiZAY/OoDS4lf/DA/w9crvXmej4JifB8Gzpsuc4G1lTsr+VtM7s5zUd8+KJI3X5a" ..
	"PHuM3ePqRwk/rLsgRGzl4L+i8fdWY1PFfa6Zh6G0dysYxsHrE1f64gty9Iiqj8SdvkVG4i2hfwHsdZplCkUSMe7HyUTVmiw9O5Rc" ..
	"1N28TKuOotGsO79y7U9bhNqSPRhGn0KuFBeLBAz55Su5YStoQJY2c+b6Lf8BfqHPg5R6K/pARozj7fExLQF6AzSMNKL6C6LrqaSU" ..
	"gDOAjvT1COjJFM7M7/ZzniFc36LhSiuJFQaPoMpsnHKPAGRrh7W4QKIp9RZctNMYVVX7GD5qEUN3cLTnHcbRkTBVADinH6VU5UTj" ..
	"h2ZoNlVZmf5rwbocwiYIxtTJhpIuCXwG9ZkPNTeay6bTcKCR3YWxGuEnSyhSjaMlB0XTiDicZ/xGVNiIOKjszjXXjVF2w/RtFwTY" ..
	"AXzyfLv7C8vL/ypHwHDXBv2DhlaCuD30DQCdMqHMYQ0vPaSzaAUx87lhZZg6/jCcqhCHU4lWJb3zEbMXSR65/CE4ySzElRsQ4k3C" ..
	"+LSLbhF7pf6pSQib+G1THod6JsYmu8YthIHzFNuFUYVuZYmP/L81/KQoB00N1GphU1AdPMln0vs/0flb2TNO//UxCid8/2aVB/Ii" ..
	""
local PAYLOAD_P10 =
	"qES5GcmKvwxVgcz+hyuMOW/Ie/uCO22MmEAD/WL9fPu2UmnfDFtwtOWwOalaTYP9bMkSztAPjRYyUracC9PeQCxmk1nqjrjsmeSa" ..
	"jOIiPG5f551vhffccslw9VLiHhFkldecl0/uX0isyQSfZIXRWb+Vf0nxA0+uW8ywNUGPZVAmZCb56ZlRSRd6H0R5UEl7e3vFGpfv" ..
	"EUIvKWy2upP+5/163EU7j7V93UuKxscwwIWTn4iluwy1/JXSAn0SdKNhrDYMmSdUqjA6JkAtTY8S9InBbEJL2UNAiq2N6HywPv2d" ..
	"FYtPMOu5sUjBVH4BPBKQbSDPz4zwKHFE+bJEcoTjTa+kOE1kKbtSijZ3nvN+9u1NQG1NR1r92Y0SSdyj+9d/Md7rm4SbpGK9mOeN" ..
	"6X1y8pFaBbD92FRRs3El4dxxS7BloOIS64Zk8JGWl13D8gGJv+Irf3yvQ6hwEbL08J+9bU951yzIT4RivUDcH51S/XzJnEPGzUG2" ..
	"UuQg7NTzaseLlQAahqQrInaQ8xBsuzA42nFP7UbHUXQ3TvfosAMjkR6auSWrlotVy3Eb2/S2NQUFf95bhsBiibND2pzFcl5GGn10" ..
	"ZAEbeXO8Bcp4y5fwFE01l13BRq90OOOjrhKMwNuFeogJ7eO4zL66Xcp5gGbu1vSK6IjVfusKqI1P5I7s3Y6v/zGLx4LU0niKWBl/" ..
	"Kkdf8qtYVvviut80+4iVCf7CowpmJKe2T5mkqBNK5VVS9qTc08HKoRl1hFtxUfqkkl1V6VnriFDXzn3TQ7B5SNU2+RfSIRPqzFb4" ..
	"4Cq9XbD12IZbBzJfmZ28x2jVWKHECfgbD6/vvfUJt+7rk9Jgz/iB28jXIW+6eIgAQgLWcxajDEAnn08FThDx5Wo67j9hvBzMv83d" ..
	"sdiss7rCxpX/tCjdKo9Cgp+k9+UhqEJywhMSYU493AtL/aNBSUNnpVX8K4B30CxTZWZpRfg17U6UBrTzvp+yNw9+ez2owUK+gcGn" ..
	"aDSpkSEmp5r5lYYv2WeFpwtqLKw4omZaBQPG59kPgR4r3kwxj70sm7ld6/9pyMm1V4io1iDbrzodAhuiduNtpiBILgvzr6LiPmfd" ..
	"fJOD/R8StRetThAGlrZotVLqsSglQd/VeD04st1R3rMbHY0MXwf5WzJdQyrC2gCNaJL0kxKfyI92aelhl9Wq+zGNFUFmNHCKNraO" ..
	"UB3T0JpUMaRCTuNSXmf35BjULsVY1mDlnfD5KCYJAxnKrKb18jJB6rgGASoTTzBumrNFs+727/qMGly9zuX9jMKE+fd3lIPM6BRA" ..
	"5P6p0XkJSVJ+O/faJ3wHtaB7RTLQXAfeW4j3nHfNG0Cbna6wwJxqS43jvk7Id4aBpcgHKUIj8gB2eyOJ3/XIr8Wcwu7D46IRlEWN" ..
	"DpQvThXXbc7iA6XQnIHGDDWKRAoXyfzAnrltfDqPGXfCqEg/lZ+ud9q2bPb1E74vr1pdJofrBeRhhQATPAzGnXdaO+EnFhahT455" ..
	"uF0I+Y3Asl0DZJ0/tFr9mTq7TbJWyGvxzqDf7HR5MwSbZT5QrMrKwkKTz17Ek/2LuIjeWLXUxtieTvyvwtdIm8JYKtkVzJjGU6Ln" ..
	"7CwuDQuDRmdsb78+JUZktBOA1l2PAyGWtwOAjqSAE7nWfqKhI5pnYAkgTdYAtQw7XnNG+0McUtmgap4+hfgvCRLsL60dQPsjJaoR" ..
	"V9sskCwiXWM2rIAn4Il+xFlT0IkE0vW7oJ+Muuw2VZC1sS4mlyA4OAxAv4FcCsBWksxD0sx+XQRgtQFnDE1hGur0n3IOqBkwzREL" ..
	"gCYguoXAZ5d5JOSbImzb2iJ4h/vsimVdpnkfNoht4sjF+1qmGWoxHBHeAhgaSKTzaOD4x+AAxk45E/k5JoS9PTAcT16z3cR07mGf" ..
	"r0SD52x07XycJ8hxfvelhSNjgdI8qP3c14mfrIQpXg+leSNW59IGTRvSATa6E0HYEbs70N4ihdr2G7TuV6zUPARcnMf8nMtGZwLb" ..
	"gdj1gNA6LC2L7l/j4Ys0oe38ozSF+rdOUpOSbmPsxuGYjX4HCYtden4I9Nq2GqMX/4Zo2Xr5ngO3Tt/zAH22FqBPZZGnhqkC/hta" ..
	"tOQmxTggnDx7ocJtDTLF/1m8QRJpAf0kjPFfamo7CzaI80ZpaTUfVYK9AJ1OQri60lLGxYKagSAlFMCRU0UwSXOmTYrymCUlghFV" ..
	"h/59DBpQXlkZMhFt/YH6qPAcHmrQMlDqyqb3X2eJyjDdDMz1IQ+RCvqU5C6eqKj57KpOClYfWifGXoJaZdOS+TSKfSj4Zv14AAwf" ..
	"4OnwsWnnFyEPvQTSk9b4TYR8udDwEs16QJ4b59XH3nXM16C1nZgsCxtSzunLvGaPx83/k/CzUhcGQhczsBeK6IY4tmpkHSwrfjRe" ..
	"y37dx8xZAkTiSSPgMfGt18wP/B1bHdxyNPqxkkQWwZFKP8ehguQzVyK6wIrGZVmXynKCJdpjssvFUwDCOzdp8DskTl9vHVUtsUqi" ..
	"9QDh0heWN4GjMZqgNGljb8mDPU6LaDo46Hc9Lxj5sifqPEFcXAsjvKbyhxj4Y4wOKwa4PoKTTzotzuRuOFojTCr458wwcZ9mUIF/" ..
	"6tR1oQZbTCc6TnVfdtKrIjHS6faBiq9cDU0jEt4hqkGJANt3imE0W3fCi/0jkv2nPVjSKa6RbTKBm2UxtWKwRI7lduisrL739RyN" ..
	"JraGakgX3f50XXZ8dnw17/SHjJilTOS/szAnPI9IQ29XT3lJAUePsgG5zJdzMJCe0ybPb1JdfEZvjjuVHjVtMIMaiUeIKtzlVelA" ..
	"ww+c9NkgPV8CnePXF/jwsXLjTPPx7JVZ5fJaLt/6c3lsEuEA2USoDJ3r2gpi0O5JCb2xocgCHEaPAg3FJgp0+hgeL0AGRFOWzpVk" ..
	"u2pvzl9sPNtohevyRzW2kZy2UCNb/sTyDtr/Y4auXCPJbGw3x3hhE8F6zJBHz5OCSpAhGooFGmnBBvuM+e93gLagLdwChNDGg2Ym" ..
	"MzdaK3Jyl0Byea2LnzCKDW3wOnNvbHmfqmYsF5ouMGjXgqBS1lBEFFOKv/QYTEG3vl7eZjXwlBFApgOu39dfQpeaiQgOrY63HiiM" ..
	"8wTQApL4swtxXtM0TjYRpGwVnImf0+kaHocFYyIH+8XeK9JX8hcTB2y+t5rkAA43EzCZTKiWFJ+oRzhDrMYo7OZghddKJvnv1FTS" ..
	"ayRyBiv2Alzs5C+UCyDC7D0nPJKEaCxrwVvsKKN7U2u4oRztC98Q533os5LVTw738nYB8wlKblbAQIgdJ6uKuEgo9gLvslN8eBa3" ..
	"l70q1CtOt78zXNfYycRRBjMmQXwJ2BBMm3qD+OU9AxtAsMF0s/ertiJY8y9Z4xszkQFxw/Mt6Ito55OuOyr9jtSRNN7Mvgml2hLp" ..
	"H3hsGMj0lpeLHI7skmjY8A6J213DXfnMDgpe1Gzy6ZpbME5WgQVCYN3fM9gJf+0V+gCakv0htTQnPF7TEH956reADBlAth6YAJs0" ..
	"wVaiIuVnoAdUcoHPCS0qFxdXIGifq9Ab+0PtHW+/uzqvh2DnJSmyQ+1VYkl6S5boAkGyuxLPr/aPByXpe2I6f9X08KugLzgh7+B0" ..
	"j961zP1ZJFnoQVlUzoQ3nTXB3IJr7KWqw41c+zcyFJp1J9o4/uOeUhPy/fyaRNPTCswraGJ8y4ZFyLbx1hQBO4S09JqypZzAEHBN" ..
	"N/pftl3ktCtrM6H5tU/W4ScgQc0P4d8Ge8tDJ00GmYepfxBHuFyQop5Y0JL2vtij9lZDTuy8nSGXtb9Lsc+TGCyzdZiT8ZKMcoIA" ..
	"9kCSXrNFtwVL9C5mNvn/qyaz421K0AefHVGnrK6BbzYce3HMIy3HKkvuwxfoeT2/m719JvdJvS1ofdRrqMoZkNTxIl12pOJ6wKzX" ..
	"xAj4HlKcbC/+v3kJSQiEUap1J4Gn9tCjASrSCFTmnLp5iV3BS8J+PDzemONyyZW7vIHDnj+qF21mi7CfTmyZPfKdnuFDPNsr0kh+" ..
	"O9HS2vc9XmscoiX2XbJpHnxr6GE4gBs+3dp/w4dD5Q+Hg/LDd6oFJZ4D+MshvLD0bjOhKB0u2q996eoWSft3oW76jl5SkB92hpYX" ..
	"+syRNHhd5o35MUJa9MzzZlm51PeFI6ENdAcKIB9JwOroPxj+H23J6wxuiZamJ7oS23jBrDtzQuo5U7PuMiDVkGECuMw/y+OZUt6G" ..
	"9qLY4+UTEJtI+7Io6zhBqHRBOQypOizyeULCe5XlHfmpQwEC1Xa9rdqA/bElIGkpWrXULa8GTAaHhavWRKpZrgYBWoyx1DGGRC9s" ..
	"krJ+d2W1U+4NFGu4czbHA1zrV4ZlnwnhT0lIWIeFvRaCXpiyg4tWgPUFDQspzPaXh+Ok9mEEiPy9rHC9FavAfXUAmBkkyL2rJtrB" ..
	"dVgaYeJE1m4dUECpJlkqRgyGKXRIVCyv3E0vWY6wkWjvujGY81Q7d2iUS979LGQjtpXm41bh0DUZBLjtaNZjkKAXaa9sCSCcG2zn" ..
	"B3XcA3iH3C+gsGzxREWKLbwy+EFEUH0jX6KPEYosqEZXMeB5ESj8gUxRC2dbH8t2eFouTdPNOlCmf/B6Sxlc90xwVaT8rAExHU/Z" ..
	"UKa/kJRP+9gY2aH8h8nxjlIY8DarmVLBb2ijwuNyzGooU+Fpv1TFimn1jdRuxP5whIrIt1FM4SHJ/mJm684KWiuTq1dZU9zTEtng" ..
	"6LQdshCL9fXd4ExgLQ3VASzWWX08s6h/gTTpYmQyiJQ1cWU2qdVL0cdeygAB5BYigJtLZBpO7rzZtPh8kmsTPIpJnBLUeWIRgySA" ..
	"yHznVR/KbaWE26oJ5VYrjS4+x78oy1pPdLThZX8Zg/RcFS1bhS7tDrqMp3Fy5pI0QQ/Y7AOymQLeFvv2vOrbXW2VIL1vi5LWyTD+" ..
	"f/vw8fpi8xLJmAtwf2ZiB4g7F0KuKGYvoaBoGgzP9ppQklEocFus5LFXDIFX3RY/mn04/IcXPBaXB/jg0zCPXL2R2SiIzrzHKeFM" ..
	"cJYN3gFIVnleomyvz/8T6wtIyhGomVhLOjmwFkCTrpD79IsbsLyyh0wKn87UHFYiLKWQIoULMtLnIAA21TY21/ug/UW1xtfW2VM7" ..
	"P/fd1IipSnBMM3xHTG7aBOT9xlNbXUn4hcOz7xwJXq/2sCjfziLApmrxiZtbE0y1KUCBsfeaPhz2yCspx5KpDGY2Uz/ih3OU7ar8" ..
	"Yk3en2dcY/ekdr6EgCsJPoyJzBpQ0lXPkHKQ4GWlEd7g4bfdzhJlIFkxYwj3hcxtC0ifnTZoeBgpvDZ4je7cikrIBYWPiFKSe1kh" ..
	"nCo5VuK/ABrfD25jqAAZiFXSxVNnFfFbYrfAlXo3gDM5y+0gQwOINguDghg8hl1YpEZ7Khji+MllLr95DAi9FYnJjhaexEXs3w2u" ..
	"2M5nZxnYdvZr1m6iqCBh9qOCF1rpnJ+n3bhUsl8EgqtD2bYuiuxPlKoaWwhxGs7A8AcfidVpbs9uD8EkvJ0qnCY0Y3PTIXcpA9er" ..
	"vN/me9LKf5DAR+RGI9rSCIY/JMD5uWQk9iBjRW1nOXeilSzWHtzHxR/PWjzYUKa5O0LD/GqXsahTpEzV+D7IWj2le6ZZOMIVPtyX" ..
	"gyMx786/6OLUmLDl8CU8rdy5Iw9D68UXV3S54waEoIxUSD5ZcgAuX4Wm7mOGxZzcNqX3P6dLWBoBIz0Lgjcemany4NZReEOqoJR5" ..
	"JozgxnrFuhjOZ5bSqc1vmIQPAqtjbUqrud88CCxLwBRO9xLsaqCN8nFwpQBk1uHBxYs85SBbAMRKqoi/Aj5yie6Af2W9F2RFcyqW" ..
	"MKe8BYrE508wln8mGTarOOIbSh6nDJcW8jSo1dXfasotQKN/2rdoRFZJSAyqpC9oJjUwFfkwCCCPi006JTKugV66SGv1A4chVKAA" ..
	"bTE0bqe3nv/dglk+V8PSX6tkBPgeKOy7jQikRizk8B1aIMlIpGK1530pIC/AhQr4FYJAxjyEwTclLJbea0CBwgeLO7wlC0F9xeFE" ..
	""
local PAYLOAD_P11 =
	"GIhNGM8YUyvB15zDmhU6M2hQcQ+p1OlyPTbfiXUEUf+zCDyWK2VBobNLyQZEpoRg9du5nRdTUQsDd+WkiJM7ga6QrgSAwBtMkOLd" ..
	"dMJd5fJLmUKCAdfPs2gcjnmrmJ4J21zrDjM+2SNTwqgJYHMqSf5uDH3CvGpYKEelxU29cm7sElaQGjjgbaAxJD+3A18TRDNdKgKe" ..
	"vpQvKvVcJUKly5MUeJaCkfbAQfkJGgIqT+EgASAedYsbi1t1wIpozwZwjeNpe/f1JVIkSErPLq0dEZK/rNXwlJ3k/wNlmdCbW4gk" ..
	"hxDJQYXeqFof9HA2kJHwa3tVUWtXAOA62mlhOsauP8pQz3BTb0mTEXUEcOk5y+zhvF+csDmaXsWHdVj5SaPfSTU+kB4M8Uj8ENQx" ..
	"jITCFnQ5q85LvP05Kp2WfiWJ31bTjQqN7uGsr2kRvskye4PwjT9o3mzoZDp14SZ3GuUrHwaADjL4hTsdgnmn8plOxtGyEaJJsQbZ" ..
	"dR1AlYVi6KZ1ZpbsJTV+5xt4UL2/49L3kJqVdaHgr0qKlhkXbCkg6HEMXuuHEddl1Jn7xEr/tU9LxPLhuSe0Nd5jpUkXc+f9LvcM" ..
	"KJqNBKlIyl+YrdOxvMR86SE0o0bOYHwh6e5+4JFbOMnTKrgRAOC0uQ84gnFZY+IymacoajZxGtWbSRnw72okSI+SDqDrSWTXiV23" ..
	"j4B2WKFeqbOwunVgJXbyNkDjWfj4S5L/qJ07ZKB5N0D9s10iFunfr84DVLNijwSIc7YlMJ3AZhtbj7yBByZEnWjwv8e9nIhS/4nv" ..
	"LfCE2F2fagWbBzhPQ2YoksICuL+IZmcKnBxdLlnzm9wHMMN8siT1VlOiOAIjVQRw/Ho7VONmgIMfROyofITSx/6Z+hjGUcpn/yOe" ..
	"Msajnm/rhqHIM3yA4Wq6MXgs/1Ko5UX1plyLB1L3vPWHi26PzzCm7uQYNmOngF7YX3u93zQ1LSZa4wuiWCwkbSz5uUBqa7UGjKfC" ..
	"a37hmbbTpFZ34NGXJD8Yx1NNXQaVajLjh6DjABPmu7xgjnKYXRo3uhCQT6aI+TBmp288xyhOcaI3AWD+tINvRBU7QTKYuvSkMY+2" ..
	"hvBZrxTYUPoc1QGscGeEN5lUmdq3sycQzr91+fyP5vzWqLsIlLydnOyYvQJKOnIyb3miFzKlf4OQDLrCYfZVA7ryJuktBR3YgPxz" ..
	"8qq9mD4yMYbmeXwq0Ig4sWDnKJDSzyh5T/pOBZO2zowMCjrFYsi4uvECBLW78cmQztcZzcxhOwFhStn6QZA/t3avJQQIUW+AVlSf" ..
	"s7F1qOqr1sKpElYApFP7RLgGKaDCa2oMCrQROiBCVrgjWZ315QhyfyNZgkdwftgh2xqazYgR3vyh6JKiuDCgmNPjtZh6W92uHbNX" ..
	"nPMkPreHIqDhXY1HVeJrS7lB3J2ZuEQBUpYpO8w/xbGgiYwmbZHaCd2FD3YCt/kTw4ihO/MA5UfizBO06V8DHRefpUdn/wWubMwt" ..
	"tek+o6b6eNEXkLcBKs8qQezS12PI5hdFqhIjRAR46TkaeJWOeBFQ/AgQfKhwZ8ssuoIzZh3n0r0nQ/Y4Ek8duIaxChK0ppDpTMUW" ..
	"qtAP11bJVJhhcjpvwbw8yWBC68Lx+Jm7ZO/Z7tRAQTr/0JQSskzU6S2f0gMl3ggu1Qe+R0Gw/hXt6zBtPB7ApN0O380ON7PYIkwj" ..
	"WN8SyL/Qj00LGsiQtfwYqiHt/KkenTURzTNjga0jtIcKz9wPGboEWeekwP4JNSd4B7TG6jh/5up4nmPx9Crb7Iqz0Jb10V1nQmvn" ..
	"uvPKmM2kFnf8q48F5fGHU4f5OXc0vrXjYnKqqbrTGyrgI3/Jg8w3/C2634+XFBKAqHF+T6KHZ8kMPx4nCeCLX9CJD2bMHvvPx24O" ..
	"26bUA28/ICxz6pxLTM3JhOfaZ+e3RmZVQfTPYBfg2S65eYr9OYtJBPqdBudvxzg4PnONhQpuVB0WoNN2cW4+4yAUfox8sAK2m4TU" ..
	"Q97cZ98FAgPOcMh4qLfp1r1UgeboKNFSIcxqPs9jdk3uUHtS3MFEjMjcq1rTom6L4OevrKzwCSnZWnXhxLujGhMxVd6DWD3rr3RK" ..
	"zmzeVcoP6hyftMmlwKU1qkjzzL2jhDZK5LmBJ4jQiy3EKJC0VgkzBTAsrPS9HC8wYJ4XKIIG4OW3/514vKSQCrymE/6T2j+xuRxu" ..
	"6gekjaWFgqKB9P+ydkwOZ2IWFZC1Etl7XQQujOwD4iCd9wBAKr69Zy8hqMMD4lbdUfvE6+x368sky0vZiupjL73zR+TOug3JyGJE" ..
	"qL7wrCVfG1wLAMDQhOX432fa+DBD1SHdR91JZClVm30HxocBCCC5mxZU4XeCN2fLKkQTg7iZBnZM7RgQitO3H8LmVoAd11cJ/QoH" ..
	"DyLgXJGWkCkd32qxLIOXq3lLwbgvd9fju10lsDstooR5Noylw15zjkGDJGZ8o5MflqKy59jzoQ2+Z8ecCty623D6KhZ67YBHc+NH" ..
	"3Rzrmff2lc7/vIu3vd3AN7A64N/l85dOqqeosAvzhDjPzd+w0wy1r9/7+gqAmQfC8JrN3xHRcv/T5AzwOpY2HQkxWwHozrPx5mW2" ..
	"LPSV0DX373YTnjfGFpLVwTEq9p8HtjnfYMsEyjBI/DEkzOEqpdP7OtRnJc7lwTw8xw+uG2scHX4lamRlg8Yp1jHxWTSpChvor5sJ" ..
	"K9hLKsUeP2XnCg8UJkoiVthM8Iuq7mUBSxnw0ReClr0sFpbtN+AvABGlNNOq5tDAAMIa8pSVSPqgZ38pQ1rToPpG0wG3ywJx3yHQ" ..
	"74wGXfF1nmhjyia9MHpblwqCwD39FHZ/O4b9Eo4OQR3bF/YBiSq8w2C4VePy400bqGGIfU0UlrZPClzUrMVQpAFCmOjSqB4PhEW+" ..
	"fewWBlzsDPS8x4C/YS6Bq8yBo5HoSt6YNI5+OJbiHaey2AwwYwA=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11

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
