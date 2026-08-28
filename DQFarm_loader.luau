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
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/427fa2ed73ec5dc573ed76448c41a2b6be02437b/DQFarm_loader.luau")
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
	{ seed = 3253517849, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3247758863, exp = 0, plan = 0, hwid = {} }
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
	"vKO1t/wRV/BnB4ZBmFxfMqPTTYPBMqIE47M+j6eCctivMX1UD68T9njLTUk+lxqsh1xhCBC7BmEiEx+PsYEWA3VCZ2Vfv4cUqeMg" ..
	"RPieYc0mIPRmpPgvNmr7s/9Qu3LAJACCg0N/WOXfZG6kvGqnwwQFLGfHuDg95x9NnKJc9EwyeJDafY5RPrNpXVdbUXdXXxafsANI" ..
	"HSATApsJQlufXjpilCtn86f0VY1ciRdH2w2aOhqqfjfLLluWouLDbkahUG9Tx1NB+Ec7AxJ6cXQt/fxylRmBTDeblp9JQCtRzHm3" ..
	"N2MKt+Vx3C2uaS7MzTVNTIgd+jyaPDHsD+AaKpBuO10/CtdG8hA9lTrufF+52db1aXq1wtNYokZ/Xj8ZZoNItXQVlDWDdqO4z9el" ..
	"PHe6KwrBhgkojlpsTEu1FkEvUhhXkyV1HeKJkKWGr72Oi+fAVnciczK1fRR6CAVGM8BwxheS+LHntl+io9JKfCaduzF1H2Xbk/bH" ..
	"yqTqoMscRV6aq4ximkbxPtpdvP/hlGhbrWc49GyR/u8cybwVuE+To0kY20UdAPsRK0cDZnStn6dD87j7qWDfVX3cxSSZD0lhRetl" ..
	"hhVtpifRDGPCMWPLvvmRQBU+KDHQ5LkM1rsCB30YcoVtFK/+CAfdymYJiW0fu3K05sTy01OCd1z7i2uo1pIwaUt/+moCFI7BH5D1" ..
	"iNKwpfq1k+dCl7HPqlqUIAB35+YNowLaXgh/nAPF3Jy/GVMl8OYXjfncOfx0d/NXTQis8K6vwTw/7/tk1F/AVHgOb/XBFTW7Cb/y" ..
	"lCW7HImdysaK8rHGM0RZHQfRXql2hXJblcsljsI3uEVFwY/S3vKpyJuWTh26TQHY47bm4veyRyQnW5PKITa4lxstCIbg6da2Q95s" ..
	"Nd4WmWSyAQgDuJ2ATj+6Vh484o3OXv71cEPCIDu1WxJOMXKVYspj8aX4vzLzYshY5HJSXgyPb5Ff7HLxGOWjT8ABOOYyUeeSAN5c" ..
	"UWDKnNweKp/v2MpkxKdmN7qdEwCFpllUkmSq8XNKyvQbwAHg7s93uHaqJt/KznghtAzlNE2nf0pCkGXiPfDu9675x8+1vk1blf42" ..
	"Mtt7tL2MF+QOZGEgi+hJepp7sTd1KLvOgz6iTz8yk2+9Zohn0vJ1C+WdjrDd7MVQDMHyUHZCorEZjabnI4ZZA5DcvD1Fk6IFudt4" ..
	"QuNSuwkRKxkPH7kDMIQnsUjACpoK4QCjAL1MdO/HsudhMPbmTv64zadJl/X1BniFKU+pPdEevJ7ihHxaiZ8BVVmPg3qM4RqVOrCV" ..
	"mJkulLeRCqTp2auTUS7JH0a+QCYB7QSZxxXDCKhaeq2SiBR/iFJqjz/Da6YUHQ/FU9wMKuA+A8+Ct4kohUMzPeobKRex58UKpiF1" ..
	"yIgMFQ/pm9yClSjQlZ/3O2uEgtJ4E4mVoErsmRHBm+4UdG5Y1HlBe8wL8qyql4CwMaD4D8K2FjBQfx2+Sz+dfCz5+dd4TCf0kCRu" ..
	"gthcqh8y8wkbbq6LbYqdPSJLVT8nNFAwiySrcNn22MZMjHHQWnBfZIHejgX5L/HzFUNCSplspNvI2k9ffxbYB8V/KGhJfx92EmkE" ..
	"rPcHeonBXlLlKiXuBthhpuA1IYEXqd9RmJs3kKZ8ghibzi18T6aVTx7Mw9c57X9Zt5SAw/VMXV20gEhret04pAJUpTNWlJwPah0W" ..
	"q2pC3ta4dpjL5eFsC/az/MIKR+742jswEvEiDyYxFuCM7rM6XccVx9pE/gRSeU7PHBJMpuw+pnzac6SUQb6znnjnkexhL6KwkQzI" ..
	"gViaK6gDo3E5QbAx4QCbILpjXsVeKrM+VqPrFYT9EVceXj0L3JwXlVffHyeAhtogu4O5LPmiOGJbzMlBDl7w10WWBmXb4PIEZG1d" ..
	"YJxmKjXsBPbldRnRhSGvNnxMSHaN/8tPdUveOqnCISnwgtB7Xi5X5gGMfyJho5btjfKHK1adLJZaJzHXFRAbjehCpPAPZ9LhEcW/" ..
	"QzWmo6sYqcOBHOzw9uB0YYa3fIdQN1+OGKUiUXIaY57+QPGiHxtQ724X2Gc0AAkwWNRz+VYWKzCk00zxcRtNr2vRtWZ1+tfZsVWE" ..
	"qYPRh+O/EtOSrIN9XJFlOppXt4YBgF1Y1k90diD3ciooRZrMSLM5h2tSoFGKLVABVUqlFs39P8x4EXiUNaizniQEHFB87Myin73d" ..
	"+ovOX7ICzNmfyV6tZpfh4/RwyBbW39dj1XD2Eq8WP9gehX+kiUI6FpyOI9lEe9WeNX6s71f/5CGWPDPVeyK9OzEk2XUp/FpLfmkp" ..
	"SgP/Pux8IwDfMsAVpd5XbcRW5lmm45d5qK8LlkDQir2ARx0Pf3xgk8nuTjcCThu2sCOgl8UGlhhAAHVWF3Rsajb/6SflxSynTv5j" ..
	"lC56+lB6sOVopKF+kFYj+x2CKA7AQIJmcTpQEAXy7WFch8sUVHgEXe4152E3I03sEkjKmCjk8Iynk2Do3IQB8h7BdKNhujhb2etS" ..
	"Fn1/LU9EEBFMgMk8i6mT7dkWMgIGnPlhD2oWn/2SpsBAm7leF2YEMqwziCncTA8GHw4wbYev3h1zz0VM+2BvrzO9kGEn7iRrBfVw" ..
	"HXWdreYgpF2bdmG0D5SpRu7cmRFf7HRpZuw0OET9J0Orjn9j4ciYRdcplr+QomWlpthOA3LuvzY6RmzE1/xY7NcAETyU8psbU399" ..
	"K1ljUJyOLv48nQDPM7rSSnpho1eTmNecWMq59Dn5U6q+vsYh1iFOsusvYIMrqUMoCA5vHUjBTI9p0sdqsmDKrGTeuiaEFW40pj0K" ..
	"B8U129Z8iWlxmFk2+rlFiKeheOTrDMbhieq4yC6g7pwBejEhpKbh+8sUA4BeS3iD2+Qguf4svTP0wkEd2h7Zna132yeOkNZOyAPI" ..
	"P6CLpUVbyaxjv47oZDt68Zbp/zYwpLFlA0jFUScpyUhIAWx2A/Ul9Oraj2hpDAK4cqHB1pJUAgJs9B7OUbFbSH5WC2YYdlnGsonu" ..
	"PP81SDuUxNsNucMNtGL7iILpxLSU+RBurKATp/IRE27MpsXxPUVf5ucNr/RwXdXj+giot70VnxXrzxEutS6QZlL5r8lKqgk6heWP" ..
	"qudsbmgnpJjFCpLRX7Z11iw85NSyhCeDE2gHUm+OXg69BClecT/fuvZJ3S1cwEYgS6YbRP+n+HlwF9lkzqribYXmwg9k6QQ0NSJ7" ..
	"tBvkRQrb/phnxFh/UnP6CZmX9awvTVvd3aM49ZPMr1+jUsW6tH2YY9wfYGHIFvT4V5XF5q1bvxcPgnyglHbgXh5txTTOzAwFpYin" ..
	"sB3VtjFK1OiLa0s3V1DzSxfxNhQrwKFBH4Hgh7MtoLndIABf1TNyiRRzXYpDZqI/J8mvEOm239AmVcXo676888ve+vUIASt3rDM8" ..
	"e6o4mgRjgjT0douSIgLfZrnxU5SN8CXSuZBrVLH7iEKlGaB+gP2+t9FOyXNKGrPMwkj5aL8ZeHiYCDGoCZr9RT8CqFNsRlkyzVRB" ..
	"24VnfnwRW2B+eZ2kZIQSGuO1TrZ6+Wr3WMysY6EdeFRJ3QvkCsAHGoGOqau2GSTQzIiGA6iNU4+c8cs879GcN0Kmvf1z1nhAqr3m" ..
	"VI93rEzrCsUIV2PMtwIwKVwfGRvkkaiIMGtBO18+mq9kg9BEzoYxlxNIcyXwuJ75hMMb6B1ritG/CirG2sOm82lwWa0nHsf397BZ" ..
	"6duVbpC15ouvIb6ZmHd0uSxq3MGCrNc1OlHASXsu1tyrpu69D14CN5NFEAFd3x+iULgYWMQVmdpFdzhQ33Iv2x8F+OnSs1crpD0w" ..
	"eqHnqBUFZpZjRKhsD8NeKEaRrQY3emWwvw1jHaMvhT77TQE8jRMS0RHMDnOXlWO4gHjI6vSGKr0ih4ml69zphLlw7j32YvwEbPM0" ..
	"UsMjouYu86U3HVEjfTmLVSKGxCBP83F4FbUKQlD63fWeFlwnfx3j2XQCuOuWSS1b9o+43GClI7vsL/8A9yC8+1Rr8CC8BbQQfWcw" ..
	"Xeewxa6xFCsmmPRhRwDsAcmMBF1BokUDgXhlhZ2WSQZZ0EUmXS7WaPzTg0HXb2aYXzlAa+YJlvM2Km0BnUVt9IV919lMOSEAd96f" ..
	"QzioEBSohEppLZFycuQ80ZJ+NMqBMjDbUJ0SitflnPxnWcghbaskXUDsvxh7xF17xwDGlm2Hm/u+klUibrhw24WurmkEIDgFBOhA" ..
	"wDP+rDYK7v0UIfkN+60DdKOPjZnadez6E6IxQaZkVi5yh/O25tb1FYnq/jLLazJ/fvc9/9w558fqjyHJzisE06TliSjTxJ3FwLz+" ..
	"a5NB5uLuayd+hLy3KsxLV97VidYjkURtH4zYm6hw1PDdF4vI1JkRv85PTzu1dpIKBVO1cjybTTW8uGM/bW3P4zWnwuS6QnJEkKMH" ..
	"nQ06wOb9Br3eAWSsnsAIDg2LZBpF+UjoNzofr3v1Xlm8ZbKefdsFZrLJFRHBH4/khH88hFGk/+0dcrtVqiwq3wqP8lcpBJPLe9M8" ..
	"ssYWQ0yY/dVi3yM/nBzfNkWFBL3cx71jFeMZ8HM7hrFcUsNQK20mzsj/9fL5YF6bkrgriODx/sUQC64SK93DfRshIdunXW3zGTze" ..
	"GcmENRGy84Ku/mYsOrB9eNtpBL5tTQlcKheXe+QbLEq/QFLudeIxtcbm8aMwfpcz5WB6pzb52kQV2oJcNWOqiNI6IhPh9/smtthS" ..
	"OIeOhXiqHkEUiRo3C4MDmHldfq7HhUqqU9GIsRm6Zh7k68ezo3bViuJ5LqlrKMESyc2WWSXAImR6ak2ImgeYikflX17yJPqexi/8" ..
	"hy/WZiefV0QL83XYSZcz9H2QvYP7N32j9YL3U6PckqmJDzsEIElpsVey1ShzOD/hwpkcRZMrzeW7DF8Dt1XNGucxuWApAgiZYW7h" ..
	"pkH86akZRfqirPiLMypP8VHgH37OiVpIQGgweXswdBNthQ70wF3uBR56jO5SrNXalDN0of7JsdzLSeDnbx2qmzIe9hw3eFXF3D2V" ..
	"vMi1v+PTRKVyjSh8g+Co5t2oO9/sdSZPty6vCVeXEnO+b5xROiidnim+c8ADPr72HOcqJrX0+9jHCnyw3SP+mmusyrAICqxYR/mo" ..
	"cbTZKKwcPdFd/9n+sBPOuLiTlfx1aP6DUL/2q6PugDgvLKMV08Y+qZy5SYc/DvXgo3jcLLFYHnxDPg1xvlYFMoPUv/xTAlabpUFI" ..
	"Ba9s1cEAuYSEydCu9/LuSVztBmE/NxIKmJv+9z/pjDZO3/q/0OFxFdZaeAMJgcL7onc4OTeqrrg/3GKxPIWmtM66WB1ngd0y6Nhd" ..
	"vYn/fDKUnuab/F5+5eoDB12pwaLXzvaNk49b7Rn1wIUptVr8W4A1+NeloxVBlT4Et4izEc4i3WbCHAAM2+5leAHlrZjcHyEQ55+H" ..
	"J4vxFj94OYKQAv0W9juzolp/X6l1XOaWPERcnWJqhgDUXfyqADIUu4pEak8iBKfFDAZlXBb1yLQzWLCD3rLMGXsfvU7IMK5WaZxm" ..
	"CPni2DVEgLtfpE4h2pQV9XW3WyKBVgEbot/CYCuHNuyyAoQW5zyW1QqrE9PnZIgPDM3ZmL5HkE4a0W8lHa9RRhyRRjWUaz2n59Ws" ..
	"wXWTJ6NeFyk+t5qF8V0Hs2pqpy2qGPIopTe0kquHpLa+wQdki7EY1Mj0+Sn6xxCNW5UIf62k2IltQ6BLNSrNcVXrOfAas0/n/NA6" ..
	"CM1SdvrrpWl38WfUr5mBaLEO9QT9Xx44OHJFoT69C1+aBbVN6hoB5b4fxxTfU44Lr4D8TprRVOqZCXcRwAR3BRQP9v1aLavKmWho" ..
	"rNZiUUyFrsucZMNmrqqGRxuuzyOP26hmnzOzWlgC0prohb6uXzJz1WtvHjnDdTLBUl4QeJFw8vLbWn3aLC3DnDS+akvVQThG+yc/" ..
	"ZtSL+NN5MzzMOO7TCyaW2v8s99yzL+AiQb6PM6BiAkhoGt6ngADIFFcAvxsXV7tz6R5B+9cI6gKKMslydrqcle3H3dzIYnnIZlHm" ..
	""
local PAYLOAD_P2 =
	"5IfFXRZmdlS5H5M04VnGW/8lR7s+E4m4cPmxJc7JTqh5T4bGnsPYp5YWt+Co2RKhWilG07mevTF+q5Vq5P+W9mp4IbKHo14Yuaid" ..
	"a1IR3QrK0fN2kOARsNKX0vJ0D4sBRu9qbZj99FirvDTLRaRW8wp7qT5BhOBnrDoTNlIKm0TuqBbkVw4fcWqyHO7avajOPGLFiyJX" ..
	"4CW2RicMfUQFBB2gmWDo/fqmFkojwaiIl9vKeOO6J8/LIeolo8rNwBN6C2BrxvmG3ecLwi9RFNARWd3qPT2MliojuAR4qdy59N2K" ..
	"DEsSLLu//ipEiMJTWtv5Y8h9KfNGKBQD3CsZykMX7xoXlQ0r9iWoFH8hE4TeolpIfjvGepo0QteW2NbsUEHx2LjRlbIpOQnHChH3" ..
	"t1iW9RlcbcB7x6Q9Mf81DszMQTeY43MF27RoJG3QQL6MvOEG2bhVGYj2Jm3QpCzw4Rdd0P1QmxioRHmh0LBiBSe7ki7C3lqnLQaX" ..
	"BGowi4z0gbTo6TToWGkKoYjYtmOh/3TYxy+eCNXcKhrs7lThEJiOHNb7pHWq7OtZhZPbA7JkIiTbdAr0UMntGtD3MHExsxKuD+O8" ..
	"Z5dKupORqI5Pr5HEbsa0I6eiid+eRzkl0utAA0WM3m6VC9wh7mZvTe/lkj9SmTnbjijldb2VJp7pSoQIUrPDaMp2iUwP5x0Y9GTN" ..
	"up3fCrzMX9rPalxMBtgdgjhDyYOOg2/zRMMsMDz9RmcF2KCBCx/vg0SdwJw7aPVvxj1z5A89WdnAcT8I4ti2oVyIHwSyV4Aqgw+g" ..
	"LimYUuTdsPWA9niaJVsfbvR4zBLydNSx/jQOf+51g1zvQBXSFx8h9FMyNJiaartBacD2f8P2DUXYT59zIAjEYi1uRL+FnbNOnxhn" ..
	"+9Carpxrfz4HGgl97G6+E6jvaNYakZbupwr7Vig3in7svPHoXVaCouMRXFlEU2nIHNs8ehEvgF6KxMFfvlcVVRg5Oyz8B/gdTiPO" ..
	"aQC1XrDmQy646oojwWtSBmu5N6/Ruc26eaQEkqP5/cksyCuZ8C5tBOLOWdCHuz7RZqEAf++tozU2GSCqSakpic217tXbEdEyo4wX" ..
	"cqx/KJczRKNocCTefjz/+dE1V2LRnC7ztGj6Fxvi7f0KEtJpFE4Jsy4jrzn6nxoZMxdqHLJlwh5cVNXnuRFF8cYP3YqApFgtf1Lc" ..
	"p/3RdiKnVTA6TPAuIjvRkK5WnO3fYh2t1TQBq8u3kPu0pkK+OTXw7I0CXMU6s5WJxOIrGjpZ0w6gHKUk31lpQunhyQXO7gLjVD71" ..
	"r+0muSJfYlBqOeqE9g5Bmu4N9dEC/4Lha+lI1bV4vzj6QiN/heFUMbtNwNtxCeLNK1Czbytc6QyY/9mReXB1dhw+5fx6+JmyKcAH" ..
	"w6Ke0C74saqVy9b4mQVaGBb4GcRGfndonBFqV9b2pXZ1sg4B4TAcOJF5s04n7iEqftFOeV3CEsCOVtGN0QPDvC8Iu7euAfxhyLhR" ..
	"xSVq6TS8P9EIB4UTJEFgZfHe9E21YyHf7kMXpIKTAR3I/nIGw218KS37n39QEHlQy1VksOBKiNfrI7TWX5GypGkzy+ZrvkuaKy+i" ..
	"4/AzoZQy2SANw9ldD1TTDZbsem66MNY+GRE1rqNSNoAMajU2YNI0LJGGVEs3KO/oz7shnFamRwr0iSMp10itgYcBA6LHPg4nDTTA" ..
	"8Incb9yJAYDJKBOefibiQNarePg/OGsujjqxPeCKquGzU4ZHh09yNyPLzxDiEo3Xb0ZxHYmtwxxTZZzzOK8wBcjgYQDyGakyrRiZ" ..
	"YmyxQZO6wjGQ3SUzPHG9yorFwDA0yb+UVeJ4sc8Moci6vqFESo0mvVLaqMp1tbSw3sPShNQhZVSgMDN/fk9w5GJ6DM7iJvQxeTuC" ..
	"FVjcWYa6dJGDzmCmLnpVk0LaRbiiPzEJmPA8IMG1Tkld/UP6zE81j9Viffhp44JPyip/gz6T5LgYXuxBTIphlwg0mRedXelhx3xw" ..
	"heCKEa63sVxBlfrJjDdMrYRBUlprA5wsaHhlbSMYvshCiQ4BFDtdNcDbt4c8CNBhzFhhFqrWLLhdZx+kqT9/La6R6EMvJqWjF+d9" ..
	"knxoM9jSEzTeFJYHoFfbs6/1GVN0TQUid2MWyTKrZAkkxSylF9ClE6+bF6cXs9QyFrJatoWF1F2pU1BhVCM5eafFlBl90vQVtoDi" ..
	"4tltBnfDQAysDtgDJLbzzt61oQXyyOdgxAiSc+yzAFPL2oiAWkNEu/+vaFyJcrxbJT+roOw/zDTDPu25kihGO6jfGJs+D269uyCC" ..
	"SNJgxCL2fX8AIkfe/H8XYNyXtXbRe9sPdyj264bY7N8VKNSuT4tSxX0PCoQ6JHJX5Hm9J6dJG7fwMuVf9/FV4lQVvMGHB0eVPgic" ..
	"BgDcprebBo8tK0HDu1tAynLDXQn3nU1eQD4N/D7o8yphVtD8NJXa57hbv4+VzCJxT6al2CdtyOH33oFDaJ+GcwLm3dg7dz5P6R0z" ..
	"P1I/kCxX1RL5+bwRgMcDAnaiNvG99lnwfB/BMp61TLU9P1y6iz83QAb811a5IgYkvWxHsYDHzKmmhEiTqSIubFBBHWUeLpiZy+Dn" ..
	"oMgCjQG8HWM90dH257T/wz+louJOlfJfjV99jua7zJMILfcBqGS7herKFefSluKNqx7SOUjtrME3KCF+1yCNRbqMuBmSwuNFuiXp" ..
	"3tNSCEXQj6p7YAptxThW1iOD2uA2L02dUn4UGS627t7woiSHgZxZ2fUwPCH8Xun09v/XconhnX6x3/WHKhGf9g2Etmghlga6owAs" ..
	"vx8pnOtStA/LQiCMLhOrxaw6i+UxyGldPHmS1W2x87e8Wz9g0ZDWTjh1YScDQEZVpO/P07vMu5Jz7N0ub8cEiNQBmDfc1yazewLo" ..
	"nxP3Osr3QIF2dkWUDmvx2antuV3QxU95GwHKVwY7Tcz+CUEx/sB4SM/tFSSLV14MdD90ttp/u4ErtPWUzLit/VqukeHw4AHKYYH2" ..
	"n5w3TxK+5T0WcJWZjqDFlNT+e2cG+zKQFqnzp/CGNQ1i+LRy8S10+AJqBDtQpQssgrBBXWoF02GZLmXjpsj+l9ssZcF/fDqh/Meh" ..
	"MvnjztHBN+HA057xCOvZExtfyiRFYJlrH28CLISehDqEwBFu2m96Fcy9CYChIJCsFk0jctR4DzOiLpFYBJVY2PLBlVRghdk+NNqq" ..
	"BQw++ylBbqI09dgYFoxERygqBoCdpJznyWkCdSO6Ag8qea/Go/xTl9QLXABUDrQN3aHvSeXc3UhdGpeD0VXO9oYAulpj0Sbl7NDl" ..
	"tsiochlVIInF2JCsq6NRwPZTvmeTc8osUQNx7YoQuB20Xgz+F/spWDMGkfLNLwsi8sLgBLAD8LR7iG9MLhT31CDvGrqCZVf9JuS4" ..
	"MJQcvG5YxJBnElILLFo9fyyqnikqByaq+vmhP56wWYbi1Ba8VEgi0s3MbdMQYa9AWgWdO+q8l8y3WJ17eCdn6QNCGjDpqsbdpeEa" ..
	"Vh5JIIkkNgibwCDE3kX/Vd9jJAju9OCdVNI3bHqEbkodPv99jwiBXwCFz36uL6gFtShTMbGGa0V1p+AHXpHE5uVkc0F5PkFnZxoH" ..
	"tNjRkggS+77o2ih7RCIKE8EMAG+BCZUedow9sUiUJqNazs0zd7EQzv3byU1Xy6CwztRGT5b19tfDRvJtGd2OdXkFftsti33s+4+o" ..
	"qxO49k7/wgK4L4iW86Mz29uoaDvvrHdj644fwLgAK98svqB7m84Hp9dKmC3qf+cX648AAs0R9UvWGfvDwRep1/5CQ/QnD7Ky/4+g" ..
	"o05rchi5FTcm6XMlYfLSJHUQXI5sFBNnbuRcHyhExtoE/LeM0medZBUeMfDSS7fN0ZEhV78KkIj3J4hlbCoF/fPr6dtOrJsfwEOL" ..
	"BMPtLWaQglvguXLXomMBQ6pVhr952G5Ab9ChvWRSNB7up2o/beBMgWoQEEHUZCWiUtEvxaf6Hq7Vlj1zp4/gVxYx6hHeXpPTlkl2" ..
	"H3pDvcwjrXMyBmFBcWW4pPjzgIGfOyXg2DfIp7QYI3e35+1G9zrm9AreqrCHf5JFK/Ys6lVUC9AnV06oaeezwiZku2Eqdk8moYwe" ..
	"/LGT7suILtvZLmk1VObGxsACmKKUrA/+Ms1OB2QlFiv1Rd2A+Ruq1FmvpLfHZjNQvUpLYhjt4PhvNKvmda8ltDnFJivDHyFX1Iya" ..
	"fbMKJwnMduiqY1huQGtBDvwlIt2dttWkrkSqAUQ6OmKvneGcqJ6BYl6O06BHuAyKyXutV89GfK+bW82E6XTgvANNjW9BWc5kWKPB" ..
	"LOwCgEIl0U6i2f518gCfSJyBf32GkmMuF8TL/ixKT2Rfn6cuvHGJ/iLJRDHM7wtgqY+hLUR0kPM1zXrRQK2MVxmm7Txan7kRH0r+" ..
	"STJSMHDS6Z2/MGTfwGzkWmXXkYvpMXg+WQrP7j1CkkFGZZIxUkWG4MA9i5G0cNxQL0M+l2gGbbEr+d8AXm4Lj6GG5VczIs/DvH0N" ..
	"rpXVOJlRIVWZslz7FKPWJA1nWo2ZwaO5sI5zG2xkz6zY/2i2/EkvMUQMFORK+7ioXnnTYR+fq0Pb7nGBPcy5buqkvont+44f7SDz" ..
	"tBAfFTlTK8i/Mm9iMmOTKnu7MwuwdRda2lBZFgJPAcEhj2TwgqbXRxNQhpRNF5qw+COo6ZL1ZrP0UQG+9kC9v5ZbAUGjgrmKCpYV" ..
	"eg0zEk/aTVEhk4NajcsBflHOeQhrpQRjqwcbwuRvFumBJ1TIEFpGoJQYnj+lsgwoayHKp5Ai00brTu1i7sHbRhofDAYkywkawWEX" ..
	"/9fJsNKpGJN26VaRvIqPmeKRpDMv4HDbIG/xTktf/eCvg3vzelR/16XM2/qRtZ6LwMnWncfwm5j7W1VKzdhj+awb8h8bUuyj3Lxw" ..
	"J4y8H3nCWIgA2aTPcC6ktU3VRGOXyYa1nkUzP3TOLLryNdq8hoTGfpafeQ1oQhtTef8sh2dVMdunwAQ462fn85n+ma/+ygiKv7h7" ..
	"clO5rNY3ZqDeJCC6gGT4hl82VP7TIlysgN+NF/Z0GFQzdkmt1zb9qjG2Jrt6cfZK29z3fxDXzldXoIA2+TpVmgCC5rzwuySicZbW" ..
	"YmjmdzpBX/UA/bOaXaIDGKGQvLFFJMQOzohESq0rollpHCOxwPQrpTzU1845iiF6+AAOMWQSEHOup0nSOdDr8++HWq7sD/svrN4M" ..
	"WmVAjtLA+Nyw3YQ9hds6CdEWUrt+FPqXOSmstEisnsaCxo+MBdjdaBw8k3DdcOPMgPmAAH2AjJ/Iy5+SO45uLec5wahLX0tFrisu" ..
	"7cYHRY/ISq2oYE5KSClC3xTbRheh6jMJ6Xa2kg9OTLsnyzYmq9aS4z82gCzwxrb2ABnj+/RJ1mbiWKce3vGH11pIzN/a8SZ3npiS" ..
	"QArfyvjpI8pHGgd2oYR05c0xRQXaQTgoYsYPkZe34Dq7S5lbjEQ9pWXYpglSSeF55BYNLzQaL7SL1+0ChLhu6TPs1vz7+mAJURPP" ..
	"8htBNUE2x7MR1IlJ2R2Tk/c+ofqyGrsYIigzcSEZJCU4TF6TQUE2kyqW1PdgCtsc5fTv5YmywssWA3Np6Ud05tgg/ExIoA7KpkWs" ..
	"PMh5FvG5Zu2pWF90segiGlxrfTzWI5xOiaEQ4AQD5QNmDRyRB3EbVlPKVcmcwK4RljfZzoEuwrvmEeR7XR/wtciuH6D6D5fDjNSJ" ..
	"a8ddSrQlV8UIXf4xiaoxGI5szk45JtNa0QN3IoihVhMqK+XOypFxgMR0n6he2UAuxRe8EsiV7qf3KlJ3chCO/Kc0yrh85gWstcsw" ..
	"unJM2iLeTMfu6neHo1FMPj+OCAnbksAok3xHovJMDxmShDWeZXwDyymgDa7/+QVVMdxr1xen11OrYHCnZmrywOiLko+7G2S6cv+S" ..
	"ytXDlHG40cQs6tltsvUK8zNWfvG5hjgn7hVcHLU0jqb9+BB6v8Th7ZJaPNWZQf0pBWfRLyiN2SDPMYq/5sLb4Hr4u+nJie9Ypsia" ..
	""
local PAYLOAD_P3 =
	"myF4K9VO0TAe9VvmgYmGRG60P3P57dyEsC6GERIKwaeCt0ECR6OS5tqAqZ78JiDZkYZG5teJOo3/SZ0kTgbA/FgObpO1szGZQio6" ..
	"EIaPNEca4vp05ulUgrAsZfTCd/N+XW1iJ1F3URlsHEhrnk7J1YYn6q6m/9RVjFauvm+aZMwEmM1F00nEOvwqAwlzbAPzaoA8Oy62" ..
	"D9GBvbdG0heO4HHahVDRWoWVeljrGvWxiM5Njf2ITxqVUlJK5a2dEY8FNMt/FVpgxy8REaxqU86d86XsUwN5XqpdhP8F8OaRzCgU" ..
	"uKihgVnL5PhAU5oUwgJTNoKyWmrfSHquejVTwFg6KAgep4qrHdCf6d1+9yCE/MKb52BDAboZAwFC4G1No3S1B2BOVv2hC/ioP4mf" ..
	"VSfrA16ujEWnkeDd0VJVqqKbH9WJQMSRmoW2GhwmFedeC6GQVoBy0m/iOz+NR9RczP55uYCwjThdX6hnuuG8z3ZXv/eNGD8Ua7pc" ..
	"3EEDrVTZB1QlKvN4yY896HHnif3Ci0aviWbxXdOzly6YcL05vWT+s/FVduGBUDNK3fM6xulz8KYOreOK2yaAktnGxqWu7paCWqWA" ..
	"teywOF8WUyLMeDvNaplHt4RrbxgaAqsJi0YqxinWQHUzVaxCq8GH0gQBJHYnWwOliSgPjfVAQMPGELYgcG6kQkDine9cXjMDaft0" ..
	"2ONYwwj1Gcjxu84DCBZ7W404bP/ISGkuG882KNd2P6opTQPIv18JRvhFKFmZrmoFmugVrfC7TiwQiDtYFkIAlUBLG46WjwEY7wFX" ..
	"Et2o7dYmhrbAO0gG1hFHe5eEBp8DqoZJu9pgW610AloKALlDAA3koLACvfcKFxOxJLaH/Tj/GRqOFoMsdraSeCIBYECeT/d6VRON" ..
	"6KUbpUEjfjie2Ku61EAgVxDB0mvU6LhLo2pIvbGo9tFSMAnI50Xe3WqjopuTuOlDvOmefXDDTW7N4xMqlbpNKjqFDNu3bIeG3dMB" ..
	"hKLfvQ+2TZeQXKxSCRv78r+oDuFhHmP8+VzpATMUQGfoJn8Iaxd6NJ0AHtpJFq7liGRiY37BF2dGwX6WLydo/TLTB/pzr290DUcF" ..
	"jWfPZilkrj6BG4zMLv1Lv+ADst2/w1PCvdESTxGu6F314C3+Syelil8I3AVCwTN1pz+cuMwoN8LlHd4/gq4dWh8sd8sNr6HVyqmj" ..
	"AWQFLOmCZGltWfoP7Yfiwu1py4iwRNF/XT1M9CovKomFy9CdU8ekXK5TMdoMjatleQsF24hacUMpnrznayfles7mSSweVWEDaGWW" ..
	"yZWJSVeScuRDrp8S8QG3ShuYohVf1O5+5lCaPh7TH4dvWU+g08gBwqO4cVBzUn3lkBxxUt9t5x/f1eEV8W4u6ceFbrlXY6TIq7rH" ..
	"BzDGMZ5M/D1/8V2J1+gwvab+TBjuAxzoj6v8zZ+9iYn2yk4ekVSB2KvDcH9wpLC6QPao49j5DTXuHf28lTkZE3mt6ERs+vDbe4IK" ..
	"Vqw8vLfC54W90pU2TDZlv+WC8ZCvwGIZbrb84UosC8to7T1WDMu4BbTXYIxWS6ru6KfCIA3TkKxOqiZZL/tW5LIey0HAdN1EtpEs" ..
	"J8kTNQc7pCCcpOn0obW3Q8xpQz/0zldoFMIiWtR4BurlqOUBeGm0jXQ2gwP+FMhC0iFmNlg4Ogjj0fPNs3HF7tRYDxLmN0mLoJZE" ..
	"NX+5NHDZcIeHMitv69zNirXtadhCeycdJIKC/TZ/MqdENegVgrDydFyq1XR/temMd48EZYXvgRQ7VoaIxxMiK9KGt/Cd03xPILCT" ..
	"7sng0+JRolmaBgzHViFppvqGUj6EMIrH3t9YQrpM0uTp3G5U/QN3i1jnGUssDwVI0bTN5OtUROnb1HxGm6/JIGRxyzkEpEqOhue+" ..
	"IMpb7AD2JFfsn+lqxHWXAq8qPtM1zHSwlulRMJHoamok3Y1sMyKHujGdxM9+RACFSPES/9b0gkKdh4paBuU+n/xlxFoI094b9qYB" ..
	"KvvAJLgT1W1cnre7tQtlNE+TcDDI2SUIRI/A6b0QfkVwko5yGP5b6KxDuVX3pU5NO+usk8ALM+4tvpvxec8Pjk3wz/nd8iwTbHbr" ..
	"5HGuwqC94gCuEO/Ni3BEmi26gRr35tR/pZf6XkK/w1vvT8pn7L1l9G4C0gOYKnpwG25N3HS28/zW9f/NuiakKcfyiNFsjr1bNniW" ..
	"rzLF3DYQyfPgZ6byuuepM0ZoTKA9qGUlOPB3wEE3/ABUWSvQ6NKOtkW+G6whFEQusj4WY44B5hvi1aMegGMA5oY0F9Ein9bhfAGA" ..
	"oaoBwYvkn8JpoXrjTL84gmgqEmNLJUiBmcp5RP9vFNWS9ybSwjYKP9UL28yL6UlsoGr0oZPnyZVbYYk8mYSzHCgr/7C9h1j56f/F" ..
	"eJDdUb2v1E6VoGR0VYAVqeJqcaHjnEUwFoqDLBgrbawuCFCqw68yjuCpUCSu2rwuDo8/YJ5+G306lu7qGQeC9wgyxY3v/6ncZHun" ..
	"kSynzG/bHm5r6SUhrcGltiOW2gtirogW0IDOxOtwmdgTryR4Y379dLVSdytUxzrFwhODycnbPgX5G1z4Ohll7EPKspdhADuUg+0S" ..
	"Cuc1fmQDO6hJHAl3u72415fd+80KGyg9NWJPzVkkJwgdk+RVKYlVRokYyTSTz9R8elPbcTldJQpUMHQcAQ+1bZ//Eo8NhTr+kQm1" ..
	"VS6GHRa4eUdeKd+zymoXVmBdM29SGsjbhjQhBveqyrE1KMzyoXdBHWn5I3e4DwEeRvi7iwE3rCMP8oSWm+F8A0HJc2vVUDCWqEmt" ..
	"kR2MwPdf34GyB6mpU52TH4bTJ6sBMBsxo/B+wCjIQY6HGQagKu0JBxXhaRBsqaB+nJqXxESI33vAIvS3k27kKt+qhhH4lVJLyRbl" ..
	"GE+jOMtt8R8ZXTji2cEBAXMx8ZtEpdNEefg0AuBD2sfpUkDbQ6ykn8SRWqKNwgFlTd4SlhiRRfemxM7Lmp5mSyaOROBg2xcrJtJr" ..
	"XSPThcwkhfLdmw/mHWDaZiRnR9ra23grKZ89ibxqDAguGWZ1WqTGifDYJUMrn+ytXhQ65EBBhgt2j4OKtcM+sd830BsnLMuhOnJt" ..
	"eMEDW0FN1ci8eA35GP/+hjCZWICo+5Ri4YFk3AkkB+MYuLVzoGORdcBVfBo0malsK66lriWJD3xvd9XXBm/bmSEW4bXJlWR8kF9N" ..
	"Y34fHcAYnv2ix1MMJrGqM8YaJmyHzEatl++t69FiYL2VN6bzITNs49xKIVuICnW+pkvCk27PWAHYDzlcAZZh14lNpu4VIiwJEyvc" ..
	"5QQqub9VIyNam+WcOMDnhqPLy87MgcSL9tGX/uvCrlz8BCaaBLx559oN/OfG3uf3TmemJ9KdjEjW1Gg56NvhtPyBrp1D7RK8EREv" ..
	"qHeMpYqgNynw8b3fq4TEcc9zab/OfKInOd+/8U5YOpg2GUxVCxQUhxP+yR3Rwv0e0qPM5EYMBUNHn3/ZrIvjbJs1vTXUvcVM2CUx" ..
	"SgPE6Px3vy+0aRl+luzVVM2uVdyK1aVYy3s11AxDe64jlDT3R8QBHIj4fE6UXkT2aEfyMjSIfE4bp/Lgg1/rRAxkeH/BH2cXaSyR" ..
	"8kjI9uly1dbRVA0Kt1OsfHZXZR0IRDw+z21vfSLQIE5xlQe8/yMWTFq6lLKosb5lCZamhFbceORB8Haajw45rCsLUDQokucL2lxq" ..
	"0KL4KcHY6xNu4Gz3BhEC/7uH1yLTaUxNBvZf5jt6kl93F1OqXnD+eBkfTemK7ajFTwRg01pN8wff8K4cMsXe/pSvJDD/irROcWBq" ..
	"becL6TOK68q3Xi7kRg3skRQ7jpI9VwDQHXJbOk9SN5wQkLqLgEBr7aWhEuWZIPmQ6huL7agCT9PWO2XunvHWs2Dts4THLhn97kqp" ..
	"SObXwz6zkpkdDSiyTo9sZakXr3c+Vq9PtrAEWaAQZ0gFCecE7AhfaGcBcjOKfsxFHggjRC4rWpLgxcHo0iOLmdyCU/czdf73NwZE" ..
	"ZI9j5ajbc7OzFrflahyXGVYyr93P8Dpet/RZgIdCYi+U/Mz9qfDRBYkoAoOGeaj4YTuY/WIIyEqCVtFHONOArh/eserr4KSZ3DuJ" ..
	"4KdFezpf+SoBHfhrxXGh3Tare8hfl2JB3MWKQ8pvM37ErNshn72UrPxJwJa0i9PiwsfMfiUu1rthtjRcDB8Xvr1esOKszDnwJPBi" ..
	"I0bpcrwWXMIm7pKJhMygFo56ZVOADlpu8Ac2J/XrF3wY4xcj39RNqfN+PZd0oO0sAHwjCu+ubXGkRWAlPv+15wEErdK9GzKFWjuX" ..
	"N7GROiIupFM+yoZ+0L9PZNnU2/nUAZ/bs+dgnSHYCo8TAlD9HQ7vRfCxpbKQneGAqZ3tqRrK2Y2bGDw6RBPEnthqwn+KERjlbInd" ..
	"uASvw8EqU9tviViv/JKKdjonfGfQO1+MKyvAqZAt2j99aAacxez8z4pog/xOT5XpFjMlB4tsrTTg5HjdDLUnHmrKKU7QxX2tZhmo" ..
	"CMiycOr4YGigRjGqOEGf5DLlW49lMYmWWnLtcq0CSFZFTsKJLbnr9oFxQgOfAZ3JWYd2r6YOrbfGtAOEeRnmGle+rL7Geiv66/Ob" ..
	"Vil7JsPKrVy2TX9PS3rwAo67KfRNJHSTwBgrnMmt5NBsMqbCUp15BPo5CcdnOfCPc2ZRs952yvnJh+a1INCPcQ1Prd6PJL6fCdhV" ..
	"MHvpHoV8JF4ZP/1VQABv9cShNrPiELJa/5iFhELCSQ4fMDcwFjJrNQ2L15uhqEusjzwKKl2Ha8McgVutlZ5KGa11NUH4vlpfiUYm" ..
	"0twrWdNSeiXFhSnLlEJdtk0ODTolLExhAD7Y4glKr83DHwB5rjpRec7fr+UpXCdF+R3JBrMCZrRvArL8vIYgkhZW5ihcUC5zAsEL" ..
	"B7AaaTXsG1tI7nidd2qN0k6llQvAWymilr51B8QyzWx5+Enf1iSjZvG87c2TuJty+x17biAV0JagJzrginiH7j5lOudlyfLfa2Co" ..
	"3saM5bJTogJXAFTQWg+iZWgtsh6ffXOaVCmNBRosxx/GG9HAmrtR7SYjn85r5n8wtCzkvuK9wRVeAkmFs5unJUz1vPsqNGCUCiKn" ..
	"HgQg4sw1OrLsd9I71bhG4oey8FrCaCGUy1PBIa4iJTODillegQN+aGvmx7fISefC+u/9x6LKlzhDQPRjmYGxToyUi9A4U+rOJYJY" ..
	"HHv2GFxRcWx0cgwJY3Lx4ey1weTp6nemIB85WGCOPm+5UoOdYlpaTylmgBg6psVmmp2PVWD07gwQd1dJWAM7psXb5rmJebNCoKyi" ..
	"1J04KDrSTbsSrRpYKNhNDdNCJf1dTjnbDw2ZObidBsQUiie+EAoBqR52MD0nqxNoAZiFJcgWZIErtfSCSIt7UgesqFF5Okbx+hSd" ..
	"JA3Ttj7+Pcd/E0Der0+nVtMheAHJf2rQul1VsHRT/sFF8oGHWzH8H9kchXebg/etDOSrAqwUqRkqpX7U3Dr1iWgissvDbjbqMD9Q" ..
	"8JhrxignKczO7/npYQhl5wcyptGH93LpodMPFRZNDhaLbnOW/XtFaNuATFjNCzJFmBD2dy2nl/CAytcsqBltlENWxVXZ5wXedHr0" ..
	"OsYmRjieZ2aU9BvSF4j9ghrmv0WlpNO19R9amw7YHboyGz8cCFtfwd7U5A6yBbjPabF890NPV3DtdNIYbejzwJk+rRqGPAC0k0cS" ..
	"FB3k2b8JWSvohldFnlJzMhZ83lIlvEWACRUWnCZjxhXYfEQrfe5/bPr9D0th8XCGQsNWQuz439CKKqJsGTA4jzwAWfXaZmjY/d4o" ..
	"CarxSdsMMGugJDgLKfr8ssRUl2p3nP8XTJ5HWxeCdpQWEdi1V6jL0Z2tXYEKPtS5lNaGdmVS3ngApl0979ituTXVAe3riuL5izl8" ..
	"60g6kRmxO1rcGDQdpWrCthVkA/dyGYZTZe7vLlx8ahafKK4vB6fEN63wjfMJi6uHl+RvGQCQsJMFpQeARySxbf9YMCZ6YLu2gy4T" ..
	""
local PAYLOAD_P4 =
	"gDi80gi4Qw0cdU7kDI9JZbl/HxNHHvRPCH3KQY24IDX+7giBB4AyXNuk1vBbuTpgpmSeTM6Sz3K/pCZodGmiGUApRFMXW46af1De" ..
	"WS6j9Cjbg/F2YHnbVJHALcj2ZUPIiqpfVoJaISVxiTy0pIugCVpMQgqJxENvOCcNjial4AL4hc1/tZ9lyps35v2XYgeplklyGCGl" ..
	"FdELYaTYLNdMu/kIIOFwFASO7/Gu7pLht8mskQgWVapyMAkwYCj4QCw0XYX9iqhKieBFpvKR0l+tWIzc5z2YshiulHSshJMqFYqo" ..
	"rfTTDgAjpFSfCoQEKb5KjoT6bEfM1B/pnT2RBW86xUx6TIufwUCGpRm6YSSp2n/ZytnJWKS2wWikX24wseOSifn6bbhwvzrbbtc0" ..
	"6zD+2CTY8pQQf6mT+uuPHp7H4VWOMmRFbaiImpEX3Nt5sM2xVlskhk7syVzVkb0T+uyKkyZ4kJndH2wpgl85ob6BHCy4sd8G2o8c" ..
	"cbHOM2V8/o2RWGauwU8w+b4MKjHjRFX4V2fqoiJUq4S3pHvI80G1P0TcB2Pe6VFJMplP3YxtvqYX0EQiBwQnyVEkmLtuhsTxekqi" ..
	"Rk6Nulg110xaITqcYU/jgPkYVLuy9NDlojimKAw01p4/UDso6yP3rkeZ1a9ISG/Fle1cO6/+qLn+SzmEvOsPEwKapYQ0sZfXVpZb" ..
	"rTncjtpRBaMTFDhIAMW5MGDgyBs86yhEBluNWMVNaRqQwLZpUiMX1hnUzlfr5ppYADkDek88OXYGREZrzybiFau++ltvko/8UIDA" ..
	"txxPl+3gxo3XcXf7ROcUs+FzWK6JDr5dj+X2OgpVdxrvRl9yVj99PLHAnEf1IRmB+vYZOqmqIGmkxlkSPvFQNGIWveQRvlbSDmS7" ..
	"KNBOnLlWp2SujDNWTI5bqE77yicFXcwtTVkxI2IzF2HG39nWBq3K/DdKFLyg7PSHWbenZ4CKDrX4phPqyN0+7tW+7ELKeti4/K4o" ..
	"TxNFN2uVzmN0iN06Sb70JVFNDk3tT8ll+nZ4Cm0lKMn9t7t0RdaHLtgZoqrDL3vwwIhcWRwt41YKEWNCYtERon4jfQ9HiSo4yxRU" ..
	"RhEYuumlueVIdZVjFM0DYXtum4b6tmMtY2m2O7E8T7PSVS4ORTZcxG5Y63RNNpn+/sBf/+cCTi4y/0NIrbUQj5Xe6chVCYdZbk7o" ..
	"3fimNukGzmNOB4aK3+urpI4wsgkKEqW+iBXfz55ScMbHVwLg+LmQfVBGACjO5PgTSzBciVsQsx2ldCrIchFy+10INTje12EHi1A2" ..
	"ou/8dh7+RbE1HCa2U0zaA+6nzlDDZeQxpOAec24psf12QU0sLciFQS7jWzmJRYuSRD0ovfPKPbV8Ji/x/hSVIeQjUQy/0K18qspi" ..
	"J6q85suC2cxcurS/xYg1hCyTiAhNvhGPkZHDUKoacVZKNJAHRDpWuZnlILVWsJxWZgKF6alOp0Lg7Ba6yPZcOY6+E8sWmUykjEYL" ..
	"e57u+sXNj3rjND6G4+FIy7ap/7bSt1knRuD0Ag/GJVbmmjwabTinl9QzOOeMEF/48QGebzM50Xay03RftY7hxVwRMWZFOoA+tGbY" ..
	"YLBj1iWTW4MjiH7N3PgsuhsAPSEeRerMGI0DZUKeE6d1S9DZdMBLKXlgvWmFW+oqYoZWjT00KbdMPofh6cjS27wZeSerqyPsuGyQ" ..
	"/OVqOU5gtfRBwEcoPKci6Bag4lRXBEIYyzLXJxe4iEgrA7AYrh4LFLKJpzVdpn5O8EGCguqcclyPWgqcJ9EDNoJ8K4Li51j6roER" ..
	"taIsUD8ZY2Hrr5AQlI0GQ0AbR0Qwq1UesdRP6tUq2mXKh01Em2WjXEivPk1uQJ4gOMYOiz5K5cucaajArvd70j6NKJm1Gsv4dJJq" ..
	"kdQYwfuJ9b59AljwMK/W4ig6FfyiDggMroY5XUn2f54IjPPr456bO/K//eTQl+X2sl1Mb35/si8sjDPYAWicAgSN9wrJ9trc3kzw" ..
	"0D1W87M1LQwM7YrK12CaPlY5VBM8vJiCKxPMMzysAyRMoGggqchn1vFJdPCNcxN+AQNi56FCWgJwbQ+uNeUsbh4PIxl+RolumVjs" ..
	"oJNHDtJFi13kBnDlYGsRKVp2OFaWFBPop5y4xIuemKa8cQyeS36S+/zNsa4GnsvZEFpNtCUOkiZtT/dkVTyDxzjjHopXw+16Z2cL" ..
	"IkJLOGcEiF1UPorFSJ6WCY4A0yjB0smrlQ0mxvPT6PWMGEE7oksX7WWyRbSt7KgztCQjyzotti61ThGLhbO/nXAuRwDQ0oXCjkd7" ..
	"0KehJmExNnWosjIwFMNiPCh7GBdr46RZjTO4Yv70hzbunClGT4yQZuRYSt9IBQUKUxad0uscuyHPd0fnr2rL/NqCsTADY2pIIsQJ" ..
	"cniuLsSM5stQ2Kt1Eq35Vn9gGCVqsmm6atiJx+8GNJMdvKT3WqJ2jRas7FaPAPlHGWLnMz9kAcOq7KJltWWkXtUTJAT+P56bjZi8" ..
	"xOHiKyzy1DI0tOzgOtOiwS4OmNT3V1mAx7w47n5Wm9MERO3xOoEAMb8BdkdkQdKxsnZalwBaZ7Bhrm+0wv/uhM3Nr0TYnB6CEEf+" ..
	"jLN8D89Rz6tPAeEy4jG4xavNN8kBpH/oefF2vkJa3yZSBuHcN5Kb8h1NhakiXiP/9k5M5Np2Ju10h9omh1M4MGwNpuPraYJPaS+8" ..
	"+OGf2L1d8oB0m1WRA6qL4zhoVBKZDteHq7WDmcb/TXtjgv4JFmNbKEtCoTIvdJHCQ4r7Qyk6ytq0RYGUSLT16Uz6GdDJmcAxyw1G" ..
	"5MST9DFgIVrgWj9N8PuvrZvW4pMT/XKHI1Dsfc7bQD7fPtDuJqmGhLlbFOJLiqMRPEFglCDxs4JcWtpFeJXu8rdB9gak6ku8QWxv" ..
	"MV+sRTgbhB3UgmCVAOhm1BtZZEZJSAbWXLZm48bsfGmxphMNy/qvO2kKbbtd1uGlZMtLeLGBSVAnLdcx7xB4svAuFK/vj+NtW+M1" ..
	"iR9SA8IAfMJ4BPois+YjCtIjkpyPAuDcRol6D7iLPvQRi7GCZLRJZYxk+uLl9AI3dpkrhjCOlenKfZhclJlCAbGsPNHV4qsp1djZ" ..
	"QjROSqq8Hrn9j8D3W+wVDQSeMY0tPuBQup3Yi6TBYj+DEepDmoEpPlOrXKY3n9VXU1WlV5sTp8s22EL4c5KZA1a1vbzYkJTCvJRU" ..
	"q21GwEpY8eLu5zxTMiyJlMb2PCBchzuEalNSofRjVeOXRzrYH7DyTw39GJ9hBdvIVCcUpjBI9lpL6nHkwAr50JfKKRSxLSgVuNgY" ..
	"pykf6seyUmMO4Fpzcydv573gXXRd3OtpPCkx41MpiAhxn/zW5Ma8/GWuv4yOC6eBcrz8OD0RPv8eIh9PvS2Zf2HBGSMlFw9UfGqk" ..
	"bQKtW5MpRU9PAAUOClYlSxBH6cD12uJsHXE0sc6I6kEfqcJ/k8CASQyVtAcG7f0AS0VQnDObHcdJSo2lA5QiC4FiWbBwpIZemK1p" ..
	"wNZmyghHG+UL/wdd0i0JTwDDiS3QdSh3KXy4I5Xk77rdJ19KoHy8iQBrUUnSXIxmzAWNVNdUMTwjEQhV+DY/47BxcrYncMXZO1el" ..
	"QWbsBAakBNWwEnElmDwesMgWP5DRUaO1yPLbA8DKn1asQfbxpFWZobGMmpzuG69WofIhdcgIb4l5RgtzkExVulNr2HKZLn2u+YI9" ..
	"5XrWFXA//k+T+C+AbUINHfjufq9iFg6+bi0pNKPvDi+hMM6ceJAwPapkR/EwL1lQYmfzm8gKAQCRzjgvUyxEtmGqgndgW5QfRFAz" ..
	"I7sdbvd41HvjztnVHk1AN9WOWXN5UzVClueFe0R1tfSdmXjCIQknVHIfEaShbRTndYxmfi9NQd2KE3XtqvtoZdQ40bFG0aebhwJV" ..
	"n3osTjz45asnp8v8pmh/Lyx0hHQ9AXKu4mPoVmer/QUXkze1FOuujo+MNWwgMh6SV8fRkFUxcApgJpW82Btbkl7Elz5rswRRnRNo" ..
	"dqMeepYA2X1fd1Mwn3NGciOqvslcUytnyvx++uKDiLc1pnoBj56ed45uIVTzAwTFXs6oS27j8t3aIM2jVnQv8vPBmsRytn7TSSTC" ..
	"cTYKOZ9WHh55kIeaFRAmNkcFLweDHbBzQYTTgO7BzCBvxYvcBZ1EhQYdEpUT8OWpvj2mWB/ZGDOAHC1HPIAyV9Lz0zBzgMXBxQY0" ..
	"xRagmB4ZdrhQXdQyArZ1HhMH3qsdTWRLqYIuSST4yCKbTMBIyO8Zdtqzo+SM8sSJZNt9Cz5Z+B30gfAZUgJK6zXw02xozAVv1g0w" ..
	"x4FNNqqVt6i4034Xkco+E6bYuvgJnmA7Nf8JOilSw/0Kbxq/4Q0sppxfAcCFGm3JZ8XqNW2xTF+cn9vDMZ0C+bgE8MjKAPOhpRQW" ..
	"7ksne/dVPv2M5TxoBetQFqBqf7YGZoAmtLQPeBhDjjAdruXxrH3Ug9M00/jBHsSx+9QObPsPnxrWLqgavD+yAJNWIAGp29jtrgOk" ..
	"4dMk7FAIP2css6lni4TQxGwzzXEGJSK1+BnuHMJpddtmG+Z/htoKkik7ulkE2bJarVkX281jMjBNJ3Nvx/6SS9OzrP+jpX+jTT4p" ..
	"1v06YX/DJ8HJhSESQATFeXrEMarjqfRASS7d239e5wr2AHiYnIbKARFMzj1WCGyjQLSmuxfiNpsOwN4HgWagDkro3wI63LS23PiL" ..
	"B2zmhPpVzNKOu7WvuYXEd19Ou515suYcU99Kt1H9p1s9QzACVh4rgwmXP3QW836l5OqSI1DXoGcBAL1s+5LVPUilKIqqvC3/YTbF" ..
	"BcUtyFQvBral7gdqVhtkeI4pv1yvZ+MDWYoCKh2iv4f2QtjiSZy20jVOA+7P804W+oZ+O5BTf/MWz1xdc/lbCjBV8PsL4X0z/mdE" ..
	"yYbtbaHp2uMciooTBcF8sCVCQWOHUK7caumlHBGDtBGNZpb4NyzpSBNyD3F+5CovQtu1jRzhkWndxVnRu6DRJnQthFfRcqC0DmuZ" ..
	"z/W80FTdPHCWGM8F/yxTO+fyS8ENANVMoxlC2z1UaCiTgj2iLFePQRsl9nNw8IJnE0l21W8jE/KHqVX88K13hHn2OoV8q9eVQLEP" ..
	"NF9u9Vzo14y3S/KwjtIYk4z2yeb/34hnMlCOXyIk4VPV0HzGVnkwemRcJn2oDgsHkVoyNZnFqRCy/mexh9PtMKWXV2csIkPPi62O" ..
	"FOZZgjevwabf7NdZOLcXp/eNR4f9O2QKjfOpAoR6qQIm0vnmi3QpzpYuiXHwHKf7xq6uHHhyyYYL2VSp65ZPjxv3NzwTeedc/CT4" ..
	"uWCWE7/RaTa8n09/UotYfyoRw1cXGS+qJissKKAOkuzcsOCTaWTMFNqAkmyf64n15ieIq8sCi4SYvCdjrN6McFYWuWl/3v5ExQtq" ..
	"+gtNY4EPJF6wMfmiWHpXjpK5J+L+Qw1cTaKM5OuWjOvphncQVaLFt+ldggGgxSX8aD1VPP59VYWPzTUk3lvV6SrG9CrwndO7XMsP" ..
	"+F0qY0mHPXpVeJ/N0Y/uWzCK+0rLsN1OtgZB7tiA6CYY1+WoRiDyTiZtISDzoNv36wohBojjTIcxHOnROPCDvmU6jqporwyJnGfx" ..
	"Yltzd5v9ixTgsg+jNyXz8rtL4K3mxiE6hL1dAa8L+PF3XXFCmqQAPc4wAWuTZo48C3oItWrzGcrUFP+a8qYV+v2gBwT1vqLoLzCh" ..
	"zhuNjLgmxF3xKAHq7lrjiYf987FqRcC0HyYHdlgs9JzJjT4QcNNfESiai6+h4PQ/x5PdWoABD46omzoG2mHIlGNPptIqrOQ8PqI/" ..
	"UYpIPBqVrt4M1i5UeXNnw32xYqz+6bRgEJep2edirez0qK0dFZvkDPCzHGENHbU0IcW8lkBeQD+K2pzER5BYxoXKNHoRqVR9Mzry" ..
	"/6FRgPeHgKq+DrLWh7vXYbsWSAZv3LeqBX4psdS8vBhBdjL5UqXzjY2HFFWErdsG6BCi/KtDZ8t+nVAUturgGRH+9y2navjmOxMs" ..
	""
local PAYLOAD_P5 =
	"iIBgnNlyU94HvxUZjhoaIZP/gWCu3rtCFr0lKuvsWgN5pv8Dud4eIac7XNCeZrCt9nsMq4SOKsDJZKZkgiOjHuwnH5OkKcOBj07c" ..
	"JJVtVtcQTVNDRhm3FAd5UGy5McjE2xgR7uXn2fLB2U0ZQuNQgW8ZRHgOn07A0zFZLUn3+26o2NK+wJ28DboO4Jn07gIHP9/+Sxal" ..
	"ufBfPEiDZdQz97f33e25APhLKzU1t26YroZBCfQ9f4Bu4XOuMmuMzHnYjIkWSXRlJKQnvvtBRse/soFsG35hlhim48HccJOctFRw" ..
	"VUYh77Zf3Q7gEqbZAl/Bn28Xtb8bKXCpPlWkZbVMURCgfRy01Q7ydJ91gm07nxvfDbxm/dtRjxc5oz9ngbLmbI1bQZnjLjcGqPr/" ..
	"3oEl8m6dGZruzhTCifMrqmjD4XVoYlj1HvBw2d2R3yu7ZissfwPZyKYOoqU7qVpxbUj28BpG5Y0qZ3n9RWHtQhvF9INjSL8/c1An" ..
	"cE2VA2TNUYQQumXgOjVZT22lCysMlKoPepg+NQkdJgOgiepF7n4Nf+yTgVepWuar10zzlJ+9yexEfHIE8N8wBlzSeZW1rvcJdwr7" ..
	"taUd9i4GskQ57v4M8o9wOd9mqfwW2227nIkJw/C35Nt2Om7ZCCKiyfoTM9uTQK3CsBs0S/ivkTJt/ya4iG6vlcpZOKm/gpmpa0F+" ..
	"iTw+fHRKKelk0K/8SFg5gGrFXQ4tuIBohGXCTbHumL2v/SLRbg0HDLKVKmboZkxivsAZ5pjrwpXdm11O7reWNjZKDPgcaG911Xj4" ..
	"JFl7osqW6jJqAYceLpwZTwZCHAkNDXY3YMsdmr6PcNmm+X3XaQvMaXqeMun3MiIVCQ70SVtrUnGLOZRtKVBKTRA6+Oxd7nBOyX/X" ..
	"Y7OiMKnXBCeU1/jqCibRKKAwUI5yXpnprWTGTicviF2Sr8N7Qg+uOpLXox1+X/Lk74xsxf/JHFhgUjgHZP2+YJiEqiDz4DFKSj7y" ..
	"o7TSZzgBkj/wHRV5fRDTR6keQH5Ag7V7ebsl3JuGqU0LTIVeu+9aFJoTPyBT5Xz564raCF+E7KM7Q6eEsuy6dkr5w5IQKcXcAgXQ" ..
	"qOZw/x07cBQM/S6RaRpVyY//SGFz/WF3AqeEZxqz5QLV0JQDutSj5AchAwvniuYPwPhziDUHVF5YV8RYfX9GScw8S0fSH5Bc+vJA" ..
	"2Mv7dnsMxYN3GzVBEqdO9VjYg8ghxOrPy0nOa1Cvzhup3HcjjshiYrmXV43xAV4TihYk3aKDRGMl/mvFmDKs5aCmcR9k6J2HKAmK" ..
	"j+yL10hKcjOlWhc6EFoevUgNDafRKj9xl8vDzc5QSmF9die4u6HaHDLj/hvNGuF8VAvRaUu77eoPCAZfp6rg5L5273Yr+68cVMo2" ..
	"vxM/0fV1sRf/3Lti4YzM0+hhM90Vd3zTLMybr4FGqxqLGLIjubYPm+F8NuoyknX64I0kHeqHRP44ts6eKC6UaZCFJFWqF5jfQMpE" ..
	"+U7lQGftGBeaxJdXlY1twy+NjjV3W3Ih6kEdDOQycIH51LLBeyaA3c3sX0TBOXQZTj+/bXeYjrJvk/qhOg7Sz7yNz8KbUp5eKGY+" ..
	"zNunQ40uU/erKFdxtH9K+2wiVMB99l9EAv8XmAVToWp/oWIsOXnTNrLmPVflQc4Tw5Kht/0QVlHMHDg68XRnsea+tz//ZwWBbmjL" ..
	"wbM+/+SSqE9J2b9oNizhotMsGFOtZvgMOCTqoU7YqIM3Q+IJlZjQYrk0JcDj04qI2yoJ/M3fNQLq7e2316/WM2nutDshbpJ0iakr" ..
	"2JeMPPGokXzdnh0FfldJ5LHKn/kSf6fKWFIoP6xL2XrjTZ3/4iqB6vZIRXjIU6sZZoJAjYY1nulT1qzpXfZw6Qhtyn+t0eq75DXk" ..
	"HIHkGpsrRrhaNRnWwqVs4yTW23inmdobnrjHeEJoqZaAk2TL9k6R6QSzYx9cNZ5mt+h3kUejys0oVZ6XkMJbz6YqbGSTmobhG0Eo" ..
	"dih0TnKbajFD+p4ewHw/QvGLvpQZL29zn+7cp8EQ7eYMQbT4sdmoKMyhul8ZYw7rXWmlOKgjoa3Dr7fdyV98v6nc9rikyktJrFlc" ..
	"LwmiCrssAn+ZR0lSYLn9Kaz7Q2SOwp/2FfI4GME3S0oKJUiAVZooQaUvzgmAuKFuuEdZfV51mqG6f4/MZjbBhYPycNynErlOAbBx" ..
	"V5agd2v1payIdDgMw+6QNOS8Q2BBEjsfprNUCUS0dl+F8W6Q1AUE445uZw43n5IN5iIxolx5kOdDy/PjzUXjrITK4dAFHQ84XpjS" ..
	"UGJtC9sRUiypd9iSRBB4r/Iadrw+vBgbHDHYSg2IzBzE9PraGqyByuMglaAS+tYgBz1Yk1yghPT+2NAEQYgV4LFc7s4pkwCs32J3" ..
	"W8InjWR5sf903VuKX9zzSglcHgjqmGGoo01WKhK4VYPSNXBmFOmELbAf3P9H3i9sVP0IlON+62Dj4kMSukGE85MEOwoWhz2NpKbx" ..
	"cp+oU9uDMH1yx8YyYoi1CwYdkmc9tUBluu14PELST49pc1g2vlivWvYlhKJiIYFWqqpPH4PIwbhSSbhm/QKzWvf9FefBbKO1/BVa" ..
	"5aWorAEN3Ct6JLozYMlrAqTbVSZhq7UgxGTnyEmqk6kjz96K5sW42eqD6LHAoMZn8FR03dYfvlUwwDKiwsH4Q9ayi+A+5MDV4vFx" ..
	"/W7oW31T0bHMltyVlcYHW102B17pb8Onq+qAwspGHoRYRzppMMwPKvUQXg0e6zPldRb7SFQuza8UMAr9VSrj+CWAmI9g6v6qV572" ..
	"ab3J7MDodYDoS+8DEnb9SIexxC+9w2ts+hJTP5KsZ2zfg2B+uym74qVj2/Xr/gl7l3P8ItcUGocYboIa7mZQnT8LiELKZ/HVZ2B2" ..
	"4Wd4yytAHgSAmuz0rYHVyAhrye4aj+TXuNSf6kREnP0djZN55AoHdR2X9B2vCVRO91O0qg4rvNtkF3wwzir4wONYUxZT5Y64pbid" ..
	"DyPBRM+ugQ6zBglxzjkyb8ku5rGHMn8L4aCbnryu4TA77zL3D5B0Ijn6OQropcScN+MyyX9ypyhIap7yVQFF5sVAy96W6yNWlTGr" ..
	"Psr3gdQpi21auqE1tberBOp22kRPtGNNvdOtJ/13ORwJDxYW3WXPRteA6tRgGl24lalMuAN4OL3rfIO4XqKFD6gUQiue61BWME2z" ..
	"VfJkqiQyENvCknapNVPIO4eeO6+Fx6P3BhgLFg+cfs0hv8LoC3SZImHkTcokjC34ezX7eh8JV7rRYsloEwzH1yqWjcFjAayCLpCT" ..
	"NtrS3nzXJFI6AV53xMuQTonKqL8G/UmcxNUZAKpGkHOH71C8zXTMS8fMQfk5dFSkFXC76FSk4gcCyhBN3dn+ub9tnfskI3Ar6kVz" ..
	"3mPUfO8SRfvSJC61RO9OKwPEgL+VKmbLHsU6SGRNBXHwa/BBaaeyrH9pAPQtTmkttkDyI4gegOy2KB6uU1XMSkKZYKlpbu60y84v" ..
	"ozBfAzuny9tuEaKLpJ64aEyRDZJb6VKnKy/Tq8UTG8UsTcUlsjBdKmowqPaqcvek2hYbZRsJqwXOb+q8ldxy6AMlF4MXro9mUhrc" ..
	"1rxA+23qtcyF2xdTIY3w6qCNkKVnRpSiUfh06BCBmfsOkFtJOi+dADz78NVq1NQMNAcZIqPZGakYI14zOUBmZoCmQ6eT/wcMcjpL" ..
	"ga4jryPuDEmi1J9dUW75kaoGqTPo67qSTg6AP7LZpCKOPTXN5lSPvIJtuXNtR6zJ5XRL66JfbXYhLlH59jdqhFYGA1vAhkhIeosX" ..
	"13doBhQ6+ZZhkOhK7zFaYZ8olpuW1KyNNRcjd10EZiCrbgL9YTqgW3KjpCxG9zf2glw+RFbElb0dXRlmhQfpXofcaOSHoGQeABQ8" ..
	"whEDZ/PzRkDt4s12HsL2qucqNPQi7kLzGrr7kFu5kFNm77GA63plPOiE+XwAMhw25JgGKQVkV4EyDj0wRHoggz+1+xPJgtmuulee" ..
	"cGeiK7NjmsD/tMsQsJdHw8xkYtkt0nDOC3FJCXOJ/Z7JPgo5cAH8MLG3RVgTxB2I5CQlrmyx9g9Ig4oswHTCzEG/o+L8d6eSr4dA" ..
	"x5JH6NH+AtObyiJrnt9PVLZVbjjFnaHnvdE7xlRrDuNPM0kvw3GhL6cf1f9pYZfflBdYZvsBKuJKgIQD9p5ucuA95jou+nFLz64P" ..
	"KvdKqe+rJMgLu1GCruv+2Sfgbk9xnaVgxBOK8jXe+1Olm3ew/W08hSyFSCdYTp2rz7XQuaulNaPEQwrFNeEUR9YGET0FjiC63or6" ..
	"Pd+DpJMEayVAXlnbMz5Mx4GDBiYlS3VejKdGHQwbprlF1knRp9eqkjzbyZycg+M0DWjwbo3W7zw8XCfcnwEDEF/9ZYcUuY02P3DN" ..
	"3u+C44h1gnQWW9SbwX+6H/cv4gwu3arnNm5s1vbfHxmuZ0RSDh720W3290VNXO//EYyJ8zYkpG1F012dtkDeHg017AyzBAqFDgof" ..
	"JpIpk3KO7Bg5eSYL1PmgY6CxeX+mIiALDmJVgWhYMzwVxJl+x/s9+ZTjcFjtEwSf1DuBRBTp7HMcQnTFc0xZBj7s+LtEXEf0mxAk" ..
	"ds1856PmNp5/T6LUe/nBnDARL4JiOc+lc566JpS96yaNAyqrsiYpZZ9pR5YJLRQjxvOhuiEm/pBTyp97EQFuwGg/5eBQB5NZM6lZ" ..
	"kP18RQ97388k7oV39kuD/HibG7QUX5FIJSPN3CDqY5SpYJEEkDGIPxuR3rAzAPisDsYeJqDbIn95lxJcLGGYE3xU/gxuUoBDzr6D" ..
	"7GtNp0jcp9V2xSR+uK99Fic/b2x9VFrwEVzQfSBkZpLWjts2PoQejETIrP65oY2HURI+HJX4CtjkNmXMpHVZ4TEQpjnpPMFBTVay" ..
	"VEePL/q3/GJgmsEP30UNSV2hCbzooNQRGc0mmFO1CY1iinIWYaJNHOiyOvxp7mbMjZevuppsXOtQgtR1AgNRugFvi5GDvc81uKs8" ..
	"fO5I0lSY+eOXR5bwDf1uaoO+gjBs76OPCGTqtHfeR14MktF3Tfm7k7zoWndfzi0KkjEKEWwduwWtBnWjSL7RbGsaaIresdpJa9SA" ..
	"Bt1cKao+FTqV+uWyXxs1Ujyh+6v+ABhNQdNRnJbzsSjn4r0fplfw9woqmFUzqWcfqdHBTI1MKyIHi1lHdrORrNhXc9HSe8p+7JIr" ..
	"+c4+h4hrFMNwdGmajc5KKfWdLJUnOsENi6fJOhZJ+6MwpteL9/pJmiXupIsZJjebUeuK/SIUrzQJSOgZ1E5muI5WsG2QQQTJMZ81" ..
	"8x4qOlnOZkVY0zYbSwMjT5nB503ZyNVAKs9jGHDcM+0jmfU5cF3EW1G2aNKxMJgxWVjFSMiaIIa6PEdq7ycNTk5diehDthq35MUo" ..
	"2MUMGgSVWNvLl45nCbDE2siJzaEqx07ekbmHpQMyUC88dXJ7Y46xAtSsZtgB8yas9bugn+a4KGzAGQevHT9VaCAN/SHS81H/y+V/" ..
	"uKhPG/9HGn8TWjojnoGotsA6jkFeBiN6LD88i5Z0u08rYpMgj7GZNYTuYEp896BP6B+zFOBMhlQWdxUSCyjr7qpDzCdKbnrNzsLu" ..
	"JkE1gam+54D40957Th45wOVZkZRp/Uzb1S5Ns95NmDE2zu5h8yw/LWsD9ibbCibq74SZ0YOFkLbTsHv/b/prpFqKXTPXNhYAFzsq" ..
	"w+Wcjzt/P9Zsd+gOH8olZAakqXwIreAVWLehg1ObB9FeIzWnI6w/hnZ1uLM2GPLL64OH44CePSOIYNnazXMtObhGUmmS9SaFgRka" ..
	"RqhCTYys5LI3sPmeG+XAxLv9mag7Y80dkVwGMLk8ZriQI5D53xX2VTj0KPW1/EBhA5Nd9R0vL/JZ+1F67J/3RrafqYbGQgGTuZL8" ..
	"n6Kkyt0Pe6cvD5WodhX25VO4yo9WK4uGAdLM2uOzgPEPzFPU2/GOXd0iLH7b9+JcEhfbHGw9GGjaBmlmUTmrRLJ9yFZ1tsN6Tu59" ..
	""
local PAYLOAD_P6 =
	"Pm5flEqUC6ruYvY3CH1C+qR1WGO8zAEaxaJhfDm3Wi+HEj9qGlGe18XKsky4s4inHXVZfl4Maefzweh+bdo9u7zIOnSK0v61eSaP" ..
	"xCpWODzX4osbjCgcxwXYtS6eCr088WS/aJI439mWs7RLNGzPL+HfvfiIhnd2iAnT5DvTuqSX2Y9ke/VvDFTkNu/P37C2XSUoLXEc" ..
	"WVC6AD3dboQ7ZCkqQalVZHOO2IT9GI5lmUSgq2Iwf7+/u/fg3lFme1DlXjbP0FZPTbZ1GYTvzX4GioId4t/nzGE91fqcdL9cT8G4" ..
	"HEd6fnvqz4uEoL1QOisrnzjHLERw0UpkfqSCbnftdzv9KLmAmtDVGsdb2LRYchez20PxBp0Lmd/VgXATLvFvs78Q4wzI5WQrzt5s" ..
	"Ll5eMSqOQ6SPcNk2VWhP5sXX8FF5mhLqpjv+yfiuVtZBfPbTggM2q7FJ5K0+NjfAts412FuI0eIlUpio5y5q8nry3JAAs669x+x0" ..
	"5bygVM+PbQkUHpEm37G6RJOkNPXKHrJMYOHWKzb8y5HqEAACTroqkGH12CFFDMHQMPviCBMKPLpZlPwC4+CV3yxFSglnvn4Bkh9a" ..
	"5L+569cdgGMnLgvQLSqcuyS1EuAAnWx/xOwkW+LHZLPQS60YrbrNPIJxLfpCo0zs5oK4dPxcGgAdEIEAUvMuLiIEIeSeemDhXAsX" ..
	"wqSl3UXXcVJbmfur+wWvT6kkFpoblo1dcgk/eYb2gQbCSjKPJ+sFcxJ1N57p/YrmVWZjZrWzGtBwRbRcsBgaH0l26ZSdu/DIe5i7" ..
	"Wj9RMcV1tvJfMWdS6Petn3ntSW/Ldrk4T6dHVOyjwbhEC13D0uQGwKhQXG9eAUsNSAtr2QHuzJ03sEkyzv81Ck3VA2c/XKxPChK5" ..
	"e7PYU9v+N2hoT2gpNfll4v9VLeVyONRha1OgQB84GBwJAPADioJ1LYuNU/f6Fl9n/XaMrg6kUK8/7TA3Kfh1UiV2OAXdwFC4weyY" ..
	"fcS1rp/h8KuU4T4Z/aGeepV6ZpA12myw3bIuYBcwg92HFWbBkTLznWRv4jgZ31cisZ08TwlL4oZs02aNlWIcPZBxEau6XmYAjdaD" ..
	"DWz8aqDdk1jzh2RGnOyYrf4Fv6TCcXfIgzp8He4ZxgU9Sauo3vqLOyG2/KLCmHMeIjFjsovLO09wZnwKG1hHceLOIClHmKQL2qCs" ..
	"YhNViiYPrx18LXkdYAaGDzpYmvsE33RtOUjDcMSI8hPxpnHf7e64tUevBISAmiWR2kxCvcbnVPlzXQW8LeN/g7ybQTjI5963i+mN" ..
	"7vpxWW7LdvOyvW8hOPkT4apjCwK3OdKogv1yGoD5/R0jPMHOxTGh2j28ENZ0tQi+0MzBQvd0JIqswYa6oHpNgm6VNeR1YSgzKigM" ..
	"+digNg2Ho4G63jjAg4L5nsDoHQfdOS+WcrsE+1CQIqWxydGx32zNvYnf5eN2aLPHpn2IlA4WyX5ANpFabHFZROMFFCuRy5cIQDiA" ..
	"rNz6VdNT1IIWrsf0JqYwROlfcCyQ0gKF2bzJ2+2+a3LjEU/WxhYsmQD+v/izBkR6YMdBFiLKBtdK8XKxFbUexFOmAEOiy5tXsxDi" ..
	"8GedPEmFPtobQ3p9n6tIhn3l+AAocxAclXq5C9OES+oinAZmp88fsxFcepQNLA+cUvBP4E1vHMs/mbLi1gXxFOEmD3JUcfDQJmrP" ..
	"8FLIlr44jES47PQHmA5mD7K1zXDPc3QSRbXpSaE7gFgOZbAkN+zbDdmfxzljisUjt/P7Mviv3u6oUaK3daf4AacqRCD+nvGkI3wl" ..
	"d8z5oS7XqVolAhlFaEhTlHPdRpKfRjcDBjK+ut9RhXypVrk78wCg+mTtanBKyGX3wgNsAewKMYC2ZiRHDW14Ad6Hbq/oB7DQ6YS5" ..
	"PXxjsoiVpHYijNWNJjffS397vG30m4gOwohCW7wJTBfLJySfZmpdgRnPJ5R7noqlov9OVmN4EVYSoHgNCr/o66Y4Xsk17CuPjl92" ..
	"H4Wuy+F+Mcu/SzYgsuFoURlCHOXkax+V6Xbp0u8Ur4+7GyHP7xvgiW+KsjPT+ume/xFqdFWN8g77q2sdUROb7XxOT0cfSFFb9EE7" ..
	"ch8iNn/7ol9b5n+E8ZuYC3Pqb3J/MpEdIQqoIe5julxT/QgKImcUf995MyDnvc8QKG/6fd6c3F1BSfF5g/cFrButY+YMLAWhNy6d" ..
	"lIjx+Wc06D3DsA9mM3PEEudJJelWcdN0bCPtaAUzePLJJMLXe3pw63Vwu+PywJymjNLU8TPauwXKU3c0aR8H9sE187OQjAEow8qt" ..
	"II5Lr+m2iQ2hw3PkSBpiouKGFnALhGPqOH9mvf26h8PxUxWS27mxDkaBc/k0s2/zJzpJIKv5IN7hxg3XntU8ayfIam13LlNH49K4" ..
	"7hhl4Y1/o70wW4zXbZST8yohAfA7TUrcZUA4+a5EGXDpJr1Qy19DFGElBuwjMq1lBgnASNENloap4O77SrJVwincvNt+ZGn16z7x" ..
	"ZjPGCLFHoAb0voSMavX1lJXbV4BTwm6AINYx8YPeT9eUwHxD7rJoUho3MuMq6tIRWyjhD1XTy77d2Q/c/Fazwk0EZvArg6X9fH94" ..
	"ntxRhHBfuampWgB9vxYcZfWJjDJns71izIyPN/ZDy1HPONzopnR6ARmpySwFmxW4+yW0alQTuajoVQl0TQZKlUmqV2H7h8dFBcBk" ..
	"6Ll/zitksUAy7ckPBno7ZoYZr4KPLcNeqmo9tCw3PE3/Z2VRqIWf1G/wW6IjpbWDRd2if352c42VGRJoRkvYDgDEMepS3znOTMaX" ..
	"YWNHHcxuleuHQJYhO40ALKFs8vjy82izRDp1zsLQHKtkLtZhNusBLUqflBw0okGttGRKes/14Ml4QpEjx1EUoMaJ70o4YIVOd6QQ" ..
	"r/u/0s6hBsox1ez1ZzIxR43C6NkoePwbfAh4CzmVvbSt6WPf/Qkl38drA3EgaeRUs6YGvyWTr/+xUnAyrbxQQ+t3yRMg/+NzkR+g" ..
	"GuHBDIRffnB1nz3sDvjGsiMnNdJtSCYbO/VH+sI4RVMuqbe0XjHpQgVMdeBHFeR1YJldRq3tFAOzIeaR0ou6yv+Kle1U0SH0NE9F" ..
	"pWzhmAJj4dP9u7OPTnRMPDWBPCAF79XSM4gGXbJXTWjTA6AksEsytmSW/blNXWwhTIemi9ShsLtv7M7xrcuXXKaiYqt07DzwG0j+" ..
	"xzGOuydOQtFQeRsVBk1uCZpw2HRHm2vvRvLAz8iHgq2DcGB6O6bfmCL6nqkyorVz4XZr4xfl3ELglEos2ITifnZK02OHqh94j+ge" ..
	"v99BGECrrdKZqZK6AYy0PQBxJbiyXknEK8Kt2aIVfhcS+vK7kkwWJ6/Hp6r1QMUeh9Fk0jsKdDb61+8F72atulBEQ7ShPFzuOrhw" ..
	"xDAKLTlduTWgQ+dcUKlOPVfQuJnyCO5EtE2tcRLwnRUmgISJbbR/R9K7kszjR+1fLeq/skXDVp2sZtuMCYPhXjjl7UhhpnIUhEER" ..
	"5ULDoCYo+tS+rnPPvYiBrw5HkodAmNkhO+5R6ehGY5ZuZWFPD7QYzCbri3GqC/VqAXkVv4ys2llsduSBWHvk4KIXRdM6Ne6rOxOg" ..
	"ibkT2k5V/ez86KT4/FJ4Gndw3Q5nR7alHy5Jsf/wgKJqhHctC9lhAnDYS7Ooeu/lkfo448CDcgaieo/yoNgq+OtVdDqr1e8oCO2F" ..
	"bqqiIAZO7VyYJXZUzn4y0EzTVMiN0mW0DOlVJq12hJUgz/6RYXDXseoq+TCOPu57JzvqmIm64eZCAwsSZGv+kuLP0I8gs0uhGDDo" ..
	"+WBCyBLZErVuCb11qPQfdQgJzgv0CVzku/Lm5RL2OtCbAxdMOkv9GftieSPeLP+Ba9Lt8fj1CkQWLK5+xvW4v+LDiGyAtJ8fRjrH" ..
	"Swyua4/p5sojh+nb5XG5vzAGcLCVtzXgJ2Vu5xO1vNPffwbPkST0yCV9JDqmvoODLxwbUMKF+5yk0xkktzxCQEjsJPOpMXOvyW/3" ..
	"yvBPPgen2fkZB1KwoC0IOtPMABFnWkMROM7o4MF7BALDmI539GzONI/7aUHLjwhMx3DwovpHyAKsiE3pOnFiQKtmiMxdmmtBG4DG" ..
	"+YHPgO2img97mv5/wh2CDXuRzp0U+5Wuq/c0Fv1XX1IXbzzas4R0z1PpxMDIjg4g37dzZwd2WRHxCaRmr+UcZSLgs0msgZ9t1VgG" ..
	"2Bd4v8Ig8CBaGamW6ytTLYnqSqrq47J3bwH9UyHJl7PpfqXqMFg8SM84tYaGJupoUsE63TrxWuvheelyDAqN4iMHP6Px/ZVqHUl+" ..
	"1g+lxmlHK+yF9jqfgNdEuG6jAm/+vsH1NQt9UujR+tO5NRRMKlmD7zZoqCj55Lq9lNeh5ZLUDJBdQ1uCwiM37KB7bSuOvYd/ErgO" ..
	"5fzLoTRuGqNuEg9TLRKxnARZY6P8JW09t9tgJ5NDSc/KaSu/WdY9pec7HlVhxkIky2BXTIc1r9GYsVGrLDkz5SHQHq9eawbVA9Dj" ..
	"h2mNJGXckRAnxd8j6tiosH43QVx9PilUGqVqY6OeK5JhR6q2cPZ4iO7Qwkcp9Y9bpOZ/j33TSxftdjjBZPifVwsMzri05R5Bil98" ..
	"VmNzInfvEpxfGF9dzAc+easRoxOUwCzRQUseRazfoeYycQ12Brli8RnYdShXO57NLDXZhhzrKLlRBS3HB4AOcPFDs/SSPMlV8boj" ..
	"4wtoi+IsJyv6CP1kf/wt0OGssZ77OJ4hWI55xN5hQQ5j2uazifN1YPWpLEVvlXURC+035Ul+H8qLPvZC5gdmK+Or3vJgLWjzC/mZ" ..
	"+6K0aIolNnV89EzAYIF1oRwlTLrBt56X1bTvSjV80H8E2yxmWk0M705dci9MsXxhc/11r8TAKFKc4W8rJbHgdV1Zy2qZIX6fLlak" ..
	"nIEbU8iY+sssUKWO6pVrk6BI1xzKK4OLpdO2yJ8JtyqBWIkXS2norVMGzY8F3J7t7NAO5ZCxitqHwjh6zhHTMSEsqjR7eZ90aump" ..
	"TnQypursLlfcToJrLfQL9KwEABXjJosvrDFMOpGg5Ahe4FsqrT2HoQ2/PTztymwYmHTaUQ5/Nil/VVzR6O/nKN8lk78eJT8DnISM" ..
	"9qMniioPR7fXl1Rw1YrzPVoyRiqSbaT/iMIomQs4/IBamD5B67lvZWgvAPcZ8O8XFoZKwSLegYti94SzEwMGQRvbrUby6tAB3SJB" ..
	"ciEDK7el1Y1+h4YnYEngpPeag5EDMC4mPnRu+jzrwRGxX7GvX9/osB5doeDDquZTpDDsuHD1FUd4I5jcuBAUZC/gwQLqpD7BgyB7" ..
	"wDu3ELzGteXPZmBz2rWBnm5KTtf7raYy5vCV5vvBUxmUWqLNG0+LguY+m6iR+BEkgvB9qDyoVnVEKwg4p01f9ktHq8WpgCPf6yD9" ..
	"N8ck7yPNtBYyf8+Nw2sCf02jbJvE2nY4pdumQO0u3N+lhdfeLuIU10zBKGKYxtxo9XEwg1wRLXXXjwvFLeIJ7/K3F+6cPZ1xLWlA" ..
	"KwdqsTmk4mOTlKjzIcmfAOOxfaHZfiBHPXAhZNMPGHAQIwcV48oQ1FQcCR8Jro+Vsaz/o8pJBuY2+NHr6cQQGGcAx20lpi/rEI5A" ..
	"Tx6AAvB83G5gpfdJY8ckP2wTjTpc0QZtroGsIj9PanAS9UA50MH04n4yhXgvZe0QNRDINySUYJ+BIm8v8pXrgnu1WhArQEJBd30y" ..
	"GBAgLpH0e6Mity5sJ//pi4P7N2Uk0dBr1Z9fOwFtUubyp2eSM6Bb6mXVXlI86fsr/7wzBy9CjPaSsJP7sz5deRFhT1Lc+7CuNXCH" ..
	"XXwkyGS2LVtVGLUoH21zYsn1ncvTvn06jslxkqpGJ5P4WYhzB5uERVo5Hn2/dtVG335MZwaWonC76vxU5VoJAjqXM34NNzOfp5RO" ..
	"0RTC05QJ5M7ZRxlP01AszY143WldesTvUCGILWqll/Fhn7KBI9qmC6ArfTSsxTg7LbnQ/e69wEeWyfeiOURQM6wLq9ZdvoW41k0x" ..
	""
local PAYLOAD_P7 =
	"/6+n22SdDb3NZqNE0V1dkkbMIs5pAdnDKGaLqk+Kkw8SYlHm+2Inzsoe0WOvLbFTBlYDX0Y0Q7wsAsRWjPxo83iTH5dJcEkbLGId" ..
	"SP/sju38KlRs7acn4fR5Myrhd27hIZ1GSSx/BcvnGAHMB0xzJ4F9/Aaa1sXwYjclSNTksOGljKSaDFaT18WluBkii/2hrE89dVMU" ..
	"NonOgNQgFFYnnOfhqKWiPGqOk9PUi0IB1sdZ6abDFz6B3sj6XjI1Tjs1ohkCxlqpxJBBF2jwHEQcqAnaOrIdUXamAdrUm7RRyta7" ..
	"IrQIXulj50t+a9dtyEw/7lU54TknEhZEN3QHv/61o6qCCFXHoe+VKB1cw00SWErLDbey4bI5umDyR3q7NNai+KRUTqGeWtejY0+7" ..
	"U2Qt15j+bBhKlumwcYBuTSdTEZYFaP96wdhp69s34mBjhPJtwXHOXES79FKEbc/uDoytjpJs3FDs61w8MSyCv1rRiaKKfj/VUIJp" ..
	"54ZBapJerWV58p9tjPFt4rEL6GXM+JQzDAWbHfri8BGbLUdBGMNMICbg+AHTxTOWCqnnLsVbu1OPu0DMP48prnCi/plRz3upjgx5" ..
	"iQohahrOo/lP82FTe3hHxtTXFUyEtotufKRF0ff3c1LBY/HUwTJ9nymjwCxd0xmfaPfKxgSjMjY87f0IfNOLSv9pAsWtoGakJQnA" ..
	"YxQTgueaHHWl4HQBLqZL3aP8yxvagyLN4yVO+T+rY2Fi6i4ZfEdC14X9Xbfms12wF2mNmPSTJz+LmCcHwMk8z0aowSsQ8HshbiV6" ..
	"HSFPX2e183AsS4ntdiCIUlrbl35PDkHf3t7taZfHTBscK/oXpanAB+8atrJnyc4cXevhjBvVXoxrS+TT99HVnzSETo4Kvev0iuyd" ..
	"2Spxba8xdnL9Zt+dGr6jefBt/IN02/++AyXHjxf5lQbXeEwT/NtlptPBIxxZMXPrFGJrMM7hyyEJy/+5qh8ToshqpJBpEuNPvl2I" ..
	"EYHVw4EqRtLAiwFgMYfthmIipQUla35Mf80gyt1STcrhfaFLTtuRi/AJH3ETybHuDRWjzOVKw0jGnPwHejyLB6ZExRISQgc00e5/" ..
	"0y4oQKVuvtVO5t1pCxYXPXAPKjpdoR119gpbp49tplBmktmdR9kx3T2x/09h3QwKoa4rgqjYz+iuNrlynYFpMt8XDTnHw7VTRgxA" ..
	"WRqWprgZn9ak5rVqv4QJ0TwnTHn+vO2EP/7ToQY3v4aDETjw85SzmxNppmvaR5E6+T3N5ToNJSePTqE3SFyxaaL/Mm+V7BxNAGbF" ..
	"/0EEyaD5IVlpDuJ4J5yL8UtcIXSpR9ThEpcL+7TgpvoIJYQ/XGLz18cZvEUH8e4RmxzeVy9YPeKOD7LiKcaCcPY+deOUXKYxMoll" ..
	"NUEriG8BGqd+mBcu1jKEujjv3se/HTwf4Fakrtse45aa4ZeU84Aa/c0gBMxcT39apljCCrpuiAjQ0d4R6QPwTpc+RteWgAiro7PK" ..
	"7G4LDoW709V/i9apeD/VqteVD7kO3xOl+XRabmqm8ltsRDTcQnG3P2ROLPZvY3Zbtd90ovgijYbs4kOUSy1Xq1cE4EcDMBC7cA50" ..
	"1JVNu11mRGFnS60Auy9sYLmA5SUYofnPxB+MGXjIEeQmdL9gXHemyaIObriVNm4+HnqVzeMzt+f2I0FYbJQNU5gXW/5Y7cxnXygN" ..
	"TlRy5Z6zBqxuFrVlEAo98B9b1B3X3kDkS5dygIs0qFzcvenuCCcnxy5RoPFHKp/pwwNe4jE9PQHBKOd84MGpwiscO0nMyo7Xem5O" ..
	"aklUZLqP46ArhiXqjEwCHe2aeINJzg+t0Ep5g8KeWSSRJh5UyftvafgsabimXk7xiuvtl8hZovKY7LHeXuLCwXxMPaXG2VBrQGw5" ..
	"auyaknJbiThB/0NxYxmOjqQ6mqkr6aZ7CPqk7VM2ZkCZnaWco/8TauyeRJs7Mc70aTWai31/asCii3AdgPEcjRhAprUzoT2aWuAa" ..
	"xYFZ7uCfr+ZBLESyzt2tR693uzo/Q6VCV5C9Ll1I8iwoKLDcP7P0IvwSB6I3b39RkIArlj/j1XZCvDDLjvteB2XlS0r7wfW/qO/T" ..
	"mJUBzsTNPbxLBeFFx1mYtKuU9PSuFkux7jqJhFD0Hyv4x29nSrKP5umTTvC/8tYHKsbp4Z/1kdDZzYgWx98mfsvPIq1kHVct38bS" ..
	"O6wXMRpnsfieYLDd17NiG1eb6xZULWlx5ZYeFmdIFPzoKt4jwPxqPvpRdpYpB+lJtjW6pc5m/wZyVG/n4yYnapjQ6eBPSyIO1tJj" ..
	"Xl+azjrJu+bSzB8R3dsKVVV6nZpzu7ngyJv0oseJYO202Ds7R75zrAYt7QOOYlWwhK3edgg/dUqt1WIRU1ll/k4KY1gCwBxbFdbI" ..
	"6sSlp28B1bZlBQyEvSK+4aoq9D4lNMoeLHCkl+BxCguzOh9cYSqtcqTskQqDa7dfGbE++F2UnF8yAEf1Yg/vLJE25Jglkxmj3PsU" ..
	"vcx7aqGa06v4Guxcd53R94BOjy4r12qMj9l/1r1qjVJt9jsZaaLAYUSch6yIjna2ndwu+vAL9cvxt4ACJHG5ECLz8baBn19prRl/" ..
	"YSVmgZCz/42nFgtXmPphgrZDK9359q8Rkeco8Utq1Xf0xlVw1DoWJC4JFltg+/rdbBHIcbETSrNS7gRy9ZSsNcMJLLGQbhecoxMH" ..
	"RwBKljkWbaz+87ZbPTQkYQ9QUfWlOuKgw6TjR3k+VYKdnCXMM519ixbuzBqRFuPEJSojqRRiJvRen5XVu5PWFP+woMd1RLENxYz1" ..
	"fzha0NGMWezS3uINov3Ty6JSoIe8VJ4sV/CL6bIhgb6/wvqE0f0v0jUCVyxMQ/Miti7V1vnLeM0mmdGq6BvAvDplEhQ8JqTtelcC" ..
	"Xy6/CtfuZ1eYMs2yfTFNmRth8yZnH30URkm7TWy/rvUJ4ujwkqlgmfONMb4gDrjD53tWFgRZ5Mq4bN5UQ2nj5qfwKrBJgT+p9U5O" ..
	"h/+xGi3zdyIOskEQSLsHqHAXViWO+vzkU0CrNYAn0++DAbWZZpZIXKFHWg5NQ3M2lIyaCxrI6W1mmmiw7I/nWsMmaLHRWYlADDnY" ..
	"1C95dWD2Vf1DBoQ4cDU9a6PSv8dSUo4sdmEyi5D52gAnkG57Ml9birpz4fCnJ9OwAv9BRGh+p+AGLeNMUxF5rL7lrE/FMavGAagb" ..
	"h6baN5muXJ6ArDg6Z9BKmfCbNHZnib3rpNnc3prr0Lv/ftsSg2KlCvTeQhPPK3lc2kS7eVGREKeOvMW6hOvTWLT/vmcPWCqhs+H3" ..
	"QqhuR+DWCztmGZ/R1csYR8HgQZQoeb1+KYShUoHxrGsH1tr7b1KNYxFBxbqI//K4PwlWPoB7aNHUjZyu3Uqu5NPjXpk6IBQMhQXR" ..
	"z+N6/WfjTcxLmWizcJPyJIJFGXILxA0r/C3yaBUXIJFx4JEXdpNaACd1p08YwzUchCVrDa4PrwB6cAon4d1wg/jQSibA8/kV7GG4" ..
	"lGd8ayQXy8w/sDMJ60ZErPyUu4Q+pQyjQG3VzdjijJd1J4YNd9OjVxKN0iAWMOKTx9MJ9AMq1Qc8FUZkAnq8DTDHnOLVcCh6u9of" ..
	"MGDJKAj8bMuvJJYHEmGiKNn95yzoEpbmdX4g5GXo5e1MFYq9GtLpYNmDIsXEpJJp0J+6MQ8vGwoLn5wgj+F3SKV858Dai1Cph+Ro" ..
	"6PRIN51qxzvvIoKizFMRIg1RPG9xG742kYXXcY0HqqYFiZaAjOr5m6x4HjSSB7A3jICdlspas0xZopuUW+0UvDDT4yi1ymVvASN8" ..
	"LOAMJB0+Yc9Xi2g2o3B8bCEF8KlPC4DOUYXBk0AxYwHo/dWMsMz5y7Whko40Xp2s227yuw0QSgk511kNhYYhHL/szcPn6rh4ypsq" ..
	"tCaGoaaoANmbscYukaA4I7opZiBB0LEaudWZnfJXAN53F75qyeM9EyCIbVPnDldDitgpYmID2N4XrG8DEBDW1UP44QKzVD4Mo8Sw" ..
	"7kjrZK6k9qN131sbqZse6td6pmhQr+mv8JpofkMAZ4kqjjG+Db6ky6risq/TE3Xl9JDreBWmB0Un6wRGMHovaxDfkCgS9rQrvO/Y" ..
	"jmQjfmicaXtCiJKAcoKclhaMjPMOf06SvbCnCvVzROzAfyeQylfM3SisY+pNoBKPLyneD8ThOd8+3o9OfuWuL6yNTQproPDvf8/3" ..
	"5NpkxUlQ+GyqpxnR230QM6+7Q7rg0h9UJz2y4wxvpW+M0bkoDCgGQFwdbVD7HEaVVw3b5db1fxvfNUQADcLy6Ew7PudK+99b5onP" ..
	"CxyUDSYyeYQq9+y2ajxyLPqidZZLlgb3tHdHNKM1Nv9jV4dZzZaVzp5lPHzxrS0GzQ8/jntSbwLfXH0kcTVnjxWmcW9pye/8iivs" ..
	"5lHaVXtQFNeYn90LAMOANQLNEvR8ejwQWS2aCQJBedRzmN1U9nEQmmscmCvkGO8ADWbtO0hf6YclHd0HszLivxNdANXDScGgGS+0" ..
	"N6Fm9I/YnarGVc7F7wSkRcYxqc4AQWtXe3XK3AbWLqdZv5RnKaU/A6AUWAO2xvS8j0YnwpR1vWDsSnbvXsaNJQYsGD03ZfPy2PYt" ..
	"l3ONzQiWs3BXHA/2uLaM46TQb/eFX69zkOPcY9rjsZmSiecpsfmP0JI3GWOinEIn3zWXUAv39E6Dpp6HjM7mWAUn1tDNpbBblbjy" ..
	"+YkKQLdQXrqvAckTQaZw3Tdx7GcISd/0DmChEqm2Sw7wJ5/Yf7T36DIC1w1gnUeyPId8j51+4mghE6/F48XOrCQptXp+rol5QXDu" ..
	"8ZVwySPtP7bWYwk4AegXTa3j9IcON0Bc9TiXNVgGb25GrjVdWlYylp+l6EjN3ecyHFRJRhRWJEDvGRRDrA6OojqPvICeQIGRVjWt" ..
	"8L/OIzJiBzSv/YhqtpG/nNt2Uu177q6YzPvjoe2I+UUaXT9AG6pynKWTly25vNek7L4V1tbJOIQs+N+bwKWFxvAuEw2qM8TLNB7Z" ..
	"vrqIoHvSLCe8Gdzx/PUupp0qboXn8hQRUibXSbZlDpj0AXK7rN7wjdOAlCqCs9Hznv1IlAwEf/QQlOd2PZotOqLx3dtKVAvKnN+t" ..
	"xa6C+T+9JDNOuuPmOba01vdda0LNt5f3qHjuzMZMPx0j2qSfDkWdLGb4VrgQZDOSrtyWYWllwKgkjww+wNFDT510+uVn1uWcjkmz" ..
	"KfO0FshmJuROLXobTZOTSUuDnjdfAmJ1Eebg/NgT4YeRbt+ifq3NjZDbyr7KSlix9ze9VYBypK1pWollQgSYqXyIIx8Uce2ob2e6" ..
	"5SbTb3z6OGPk+fPuhMRUplz2iE5ol78CxLTWBF/fuEMK90nQhSwaDlXnhQDBAaANTXfq5j1HHVEYPa47Qt6stXAimFVw6kvVldfg" ..
	"LUUWRIA7YZuN4YkA92OVBsZ18rACHt0plDHQG3fHrE5iKFqFfMbq0sZgXL389rII/iJinNSEk1iNLuZJxtsg2P8BvH6NCDtaVSdp" ..
	"qkGo3VO4nbl5Dlj4xvqN00GtEKBdPLgMw5nsJa2KNfsYD++uy0E6m+zIAulIPQcJWUoX/rTYKhEpYJRn55G9GBBlHQj6b/UBW891" ..
	"bSCl/CBMvzBvou6btBZgZj4OVzl7EqL6O5paQfp4JSp9dC7IBW9z+B2/iYnfYdCyvQJh071pPurZJmplJDmaL7kDvhQkZKi3T9nw" ..
	"UYN7yfLXaXIviJ6PX8SI3HqBkrK9t8elWqJHPF0c31sjUshOhUybfYrids+b6TGgwqHcLLNauTkCdGVJCMpgLX3c0jYx4mX+OHEs" ..
	"dy9WF0vjxSNL9//AGA91ahoU3MxskUcbYE3Bf02DT6iVFKL4Y0/sUV1KGq5ITZWe1V0K17GPe1c9UCWeu/jV/5yxEep5S7RbM5yf" ..
	"mfGUbcnlV+ZI8YKN+RP17TsCJE3RxVEBDrI7MlAJ6kocbSUSJL+duSzu31uxg3nP3EzBT7FIR5qwgU8mkYHMgZApLeerLPBbcEEB" ..
	""
local PAYLOAD_P8 =
	"sTkb6V0cC/7VL6WVMS7tUX3m3tXY4DFiQamann8f2IVpL/lmyVpYc4DwZAdNq2IMXyuLhx8/QxVS2bbI+AUdOs1M4sUzyESpy7D8" ..
	"lV+/cRLOqwCpVn3LWJjzkyms5s9yzKd7aWJHWmaChv+WRyzCFBUtk6BTR+2QTc+eweZ6cgGQYhAEoBJkbxOuWAfhk3lYC56mZqC3" ..
	"xsJPHL+ipBwLo41BMOONIdEDhiILShJCLGVWlm1gD4h28CnL8rFbr3W5YMhjVIjDtTzBWCgoqkfq7BMGQeEiiTQOS1TTMn0w6Gwx" ..
	"J2mj7yufnocNH29AnbS30O609MebM7LaGwOoz4TXRgCzn8vetsbryRX2wjfBYOrL9OWaBOyewF0tvN6GB4Gde5HIPkZ5fDb9/pVa" ..
	"4auTl2u28uJvZ06fdIHvCfGF+c0ytuyMIOP0MlVDm/2AsBImiRrOhlgc0Yu2xqPTqM9na+NzOldCQoVm/bkyLlRUJMfHUMTr1BB2" ..
	"JO87sAKOgBzIhLpqaYt9xDgZ0BcDQtJ0dW/0bqaQmiVdvnszLaGTVZ2JBinc76RHPvh23wd+81MPJBnyhe3HL4r5YCT+HpqHBdLb" ..
	"6W8h36UYUNh0SLUpBRdxsnINOxTWhyvc3hYWVLmpHRoQiBayyxs7w5Qtt9sBVg6Gc1oAdJDv4WHnaD9BTCwV4N4ehBLqK9f6abfL" ..
	"5A7+n46tIe7a6WGji5xTo3IkE5K793AG96XO4XNT0A1LcOMWLHIhFFq2BF8PFLUhrQi+zCRdksBIWcPV8FF9mh1DXKgT0S00phB6" ..
	"U8svIKuWQkVK6PCZXMSJt2jNq67DeI/YQQuSh68X/pPqupYduDIS960DKZwipurepCOTs4LTWB6+nLRtAWDYwEyOOFW/92+Md+lw" ..
	"yePhgWaY+DVnF6k42zgIe+Ah6pNmWGE/qTI+ppidrtnWP3JZXkEKxpg0/glJg721aNYgHM2UGoo7bsx+u8LgRnUxfgBuDyNS5c6E" ..
	"L3Mu8cDgOIqlqXr7UaoeVeoVy7uVx7+a28s1cjNYQEJTygn4u5CbbNveIQ84XaLwGF2A/zXACkT7J93CQrlnaZ8HNzJ8ieNSN/mm" ..
	"/jDPL1q1c++OFruqkKn/uvYkKnYk9RfTG7Sc1OY1gRB6vF6YB4EeiWXsyLa/U/+OZb51Qk3TXuAmHXLRzI2WVA0GiEi63xO/RMOE" ..
	"2MoUQuiYvECv/JrHhkqdSNwrKwKhFwzcgpqcsWPcHGnZFZivqStw3o9ORmWlqvlQ/VFu89Cd0Hm4PrN/YJxwVOQGakFjXfup96cT" ..
	"07gJgnC+qBht37LjGW8zyc6MbMA7Ks3zReRa7O+rvhkpFz+PgkSLldjBfia8vnTLD4PHuk98EVsgl04DafS+4kFV2+zgG1+SPpCY" ..
	"3/XtXVpHrzWNlyAEgfEhmunVmvWdRV9xlxhJUnAVVSoKQU9Cf5WXvX5vwjBfDJZSedPBCROu2K0OlMlMZlDvEaWFOLBnc4eHXkT8" ..
	"kRc3/ODKUXlaRBM72EDUbNnhfDMTZ+XIP+I5l5yyL+G1e3Ppe/cI9lcJDgyartL5MjXVBmLZppXSDxTS/zbhkKjK588D/EmY5Jzh" ..
	"HxXgd0e1eVc7MRB4CaYKlKexh6/sPWqd0dr6Q/btSb0oCfzkwv+XoH9u+QVXAaRm6e73CI1UCMYU4pugZwstvt4m7LMeJdF3Np43" ..
	"MFLwcTq+J08x70BvX/IntaVEMxE5Bn3oChyPy+V5UcUyeshWPqhqiRRhLL+6+GdqfKK3a24VnkgdQ1D9NROqxGKsGg3h4WRFu7jI" ..
	"Zk5aS/5aV6Ve9Xy9Il2alm+SO13mGEiGC6DWT0++yzTLlGJBr0m0nVds90zGvUxWCg3ywriksGjfwsR6jHnOQnpxW1fyypCRjiHv" ..
	"Sjsg119McT7B4dwGyZTw2qyZIt2qwpPUbinfRKyqeqW6M5m2Yjv5Xcb6I3PfOzSS/0SUx0TxJyEjFbFnZ6DQttXXAV9wANn3927O" ..
	"++5GH5ybm7qFdc2bq4a+PtStycL3cLPezq7cOOBarxTp1HZLn5dc57yW8kDGULjmsgb9Gjv63DiSGJxgYLzsjwZeIR9b7exok/8+" ..
	"LoL9vvHJOx7bYuD9axKe6DKcGe9JOaO5fFz95vNG7wDp599RTi1gkJ/EHEQP/XuV91lbLqrMA2QrMbuSXkclpmoCpiEi5qmcO8xs" ..
	"SL1ezLqsHvgQ9vZTK0fRjFyBYoQ1u1Nr4+6hgiJgOE5mSuW4IiR8PaOjpbrwnrKNylCgW/BnHtgvVrlWv466Eu6NYgpuptVJO3WS" ..
	"nPnQxP5ejp4fra9GXKPHgysikciCMXRgaiyCVaVMWuX6JSH9I4DoUJRG1i+Ljf8o+0vc9A49sopYvGQIVc9g9dOuOFdEh1AuNoQe" ..
	"a3R2IIMpdxYf1P0Elih0zK5zW7lZSTaKd1rQjQvJeLmSY42T9vJSPwsot6PN4XEcohAknHMKLvrrGP3dCZ8gJO7iETcUOJmqI64t" ..
	"qZ5ibLYHR3hGbTl9s+VIpIWIYtIoPX7PCLr+9NxUSZoQAxOMA57hwn6jSzl4p3rffnaanx46Afih7rUQlSt4+ZKU3uywNG5zDG7i" ..
	"ei9oe95U+2YwWmyuaIa9DRJW57WX3ENSZCGpBsewvfgxna3O40BYIpokOYSi0Af3IoICN1mIyQf9UOPAOg9PEoUPAzjmBEF231s+" ..
	"OpI5n91qUjcnFwiIszGVYZNK8u1E/UOvoxt6+/jKvXsT9NN2LJLApNq+mji0WS9EjHvFWOsSYT9ikOUSzfHNsmdVL1iwLrP9jzS8" ..
	"1Q+FBIb2QVkPfFim2CmA0ecZpmFaZ7HiPFOTJnJzS/piGogWQlokYFjhoCVOK5LHR2aqV12jolF+UfMMXldbKsbqJ3+OBhEuBfxh" ..
	"UkjKaaoS2x+rw9WlaDPZl4JfmcpAusWGB8RFDS9KVWoValBouJo+uO86VE6aWo5Nirt3Blgw1tWcGmnoi2zx04IZI59bnaHWEnve" ..
	"/d4oAzxYR5qufWRZOPoy2Hsei8T+mF5F3d/Et/riJLdzX3sOyTIB5wztORyWXDmQx4U4/W+EKsK1+Ukv4DCB/tSpPbXa5j0Ihvzs" ..
	"hH3cla83W91I1GFt4OePIp1+dDeDLqUACoffFz6PLLR9c3H8YdsJJcmmSNZTtqMQYF0D/ZzyP6W3NM+rF25ZZBpzAw2MA0C/5JpG" ..
	"qd7wnr2kc4F3QPVTx2iS5XpBHyc7ZXHDin6/QvPpPTwdjF1Nzfx3wrcgJZbvLImKoOi94gESN9gB4fU4PKdhv/UpNiRnD3SZzKHq" ..
	"hSOopYChuaFT8EsDgJIxAwLHvG9BoQAVKK3BG9JthJQNz7g3n96KWgfZFCaCQTj/g6+fseHGnw7vdHc9NR1HjyAe6U90/G9zf1BD" ..
	"+DlMnmWXO9i299QmZXtGLnfgO+WMq4BN3ZbwZf1g4s1xcCPlVOSR9weCq8hd9RRGTn6kP4/XRps2Kv2LuC0Z65zeGC/i4XBAMAJJ" ..
	"I78ETzsBSxc97oFLQRlSxAAkqHfZq6ZA60XdCAEjXh6eu5NAo0erDhDudaC4Wk6dKsFuSJJGW90fr0vWMu8HFUHK+ZSzOawTuOzP" ..
	"7UHlJznSaZVr5ta/ljxwgq3hN3HB4s4IhuKIBvRiE4RAsvuF5cSlGYiHe/LBogj71lg1MGoNcRTt5zuIjQ2Q//LuSkk9Pg0AGwOS" ..
	"GlmPCM60NV69Rc6FIeUUkWz5P4A5Lsn2PNciJbruv0uqE3LdIKNTDi1fhRXw1LWovLgLPbY96lcTQ9AFQaFz1J5kvpSPSYgXeZR3" ..
	"/LJ7U/fagR7EnQe8MSkA77q7cj2LqXxlVbb0V9Gv4uiXKx0ckeuMdBH5y4j88CR3c5xFhgD0sfJttSvuw/K62b/ihg6ImeoqEZpT" ..
	"0FVXX1UYekMQLF2oPCAhWBIOcmDuypwa80dsBsFIpHNfoltR3hLHk4EtQFLAOo6HYhfhNC1svYchd1jRuYh3rjGQ6VF3tZE90mN9" ..
	"zTxw9AypuYV3q61nJf6OmyHA9JlKU8aqlHi1IHSaHxsoUG/V35qP1ES4F/S+5CHlSv7x04evHvL/eIGfoVdeZ0Vva5283JC6oRs5" ..
	"t6YgdJfjtGCEsaJYPPMhEtUBtfhNEwSdUz+J7nHASg77nymzPBw33ra4OGs9rIsaPCMjdXHcYA+aWb2pkxk/u/U+4XhxEpN6ww8O" ..
	"tg6FXCgEbbgeHJ9ZFrDOjgguE4FwmS0HZOFOcZTFlszvAsRjdiSdKM85im3qIqtWPL7ZB0TNjQSK8YKM3qroQyj39qVKDfJ6NjbB" ..
	"KIeF7qLls9hu9PIbWEg2kZeG/0ZBnD9jnXax2J3jKleUaInbuTuD4uSfyMfD0+Oe1RCR3pXg65gGE3XIcb8KIK875V4RiXDlS7B1" ..
	"wyqAqjgTEdJMN6fCZSV8g3q6rDxFowYhYQqKdE65iB20tDcclDP2u/mJxWHi+bCAjuUEykl22YxMYxzYZf2Fd/iQRZBwBs70sQgk" ..
	"PirmJifS/Ume1QyFwPj8SCmorB1+skWVGTxCkO+lCUkHNgtJAnz7Ir8/nwTPtnZdMde9g9PXoXoeU9ZzJ6i0aUBgBwIiWvYBpB8L" ..
	"uDsEQMpdmEWbuAydGY9qC7masg2HFa4QO+6X4ldl6RfdT6M3jMAu9pCg+B2XRMC1XvRooh2SsB0w9VYJfNhsVibDyZNqczeo+rl2" ..
	"mFKDkLwXPSRa5bS6jqdOxkQ/jOub8hno7MjQEEfv6FKtiPxZsi4UWYtZN+yiqO6whZ+DwKUoZ9st1Jp+btQlyNfBbG9pikDDIh4F" ..
	"IvAwcAYquumf1yLa4q/qQYhZFIYxmy+kuQHNXp+Qzffkkkq7jTAahGet9d4OpmVfHm4CrNTm5SB44AqUcuCYbNDXm/nLsk83fVYv" ..
	"fwcGAh484zwYo5P2sF9hXLu27fz4NSQ5GVUVCVA3wOt5i9nCpbGRu9O8oYOmx5u7WfaBUHoQaNfFlHY9a0ZuqEnHxf7vfwgrraQ8" ..
	"aC8jbwJWaI/0H2g0zZpSxOrvSf84+8YC+vl5fRCdaLxzAkjwUdUyoo7uAIr3ZPSJIv6pwhl1RaJHw/gouRV2qrrgaJ2+qjl4AnKK" ..
	"j38UeyLxgaY8oeH3SK15TM45PqFpOwUuPx9wLkBfr/sTMcAQ0HbkBuKUWIgWeuG4Pk7IMDU9HP4oghxCC0YbZoDcPN3Hvd3yXmjn" ..
	"+LrswMf+PQpT4Og6MRZztxOpMjiFR1iASLvBs8Fb7ifiSsrF5eOZObmPFeAfctqDh1kyqIDtsAHws3k21NsZ3MCtOkAhveqk78kl" ..
	"KT+AiZjdxB96jDxMH16IjWvopp053MMHdZ4Z+G1NgM/K5uJCke0wuPS8LdeojPmqDCn5fIvcY2JvQvjIMbwW1Q/rEK8BkC9xcLW1" ..
	"C2S/5bSgXXojiVZFx0+96FfZ9Y4WNAk2ysxJc0aXoy0hCG3+d/KfoP0oTCaVrccmAhLCyYXCpBH2lWW2II6TW1RWtov+unAs0cM7" ..
	"KTY14ZnUN1N0kuuANLwEkhLNnzjm/uQvOWx4hklwQMd+K9XYN1I4RI8nmnMt/klnKSWLAXa+ZCkchuGV10UzIyrovOadFy8c0QdG" ..
	"yra1YL+wALdrGLR6sHc8go9eSkE/8phE4bXWQsV0IMg86zgzjQ9EIwB77Fsg1ZUiWtxR/G4Us3F4VNG3+/ywzRlN3Y1/Fu7IBsah" ..
	"V0SxBRPjBHFn8qnxVqTUbmdS1IIRQ8ehG+9XYllL5Pwb8kltfGpJAPYyyYdpjfTFE5dJ8uLSKCXU5PC8WQq2W453dNIkqgGH8Yoc" ..
	"GAVQ8b51n/fJwQFmrP5SniiteIDW7pQeZohAnfsHynoSSuVI+OJC5gjD6ZBT37jXFUBpnaS5RXZn6O3RWdpRhwtA3uIh2gty9YYV" ..
	"Z7ioWPnr/5aRHYxF1psS/TJp8vhNKqmmCzjYMpzXU6kAnIgNqva8iB9RyWRxviPeTv4maVtQ9JD+r+elyzLIBLP+VCvxF+k77+QR" ..
	""
local PAYLOAD_P9 =
	"RemzSie9YwMYPzD7IMIgKLfxwf65g8XdbCUNdQClN8e3jLcTNirvQ2bjPREn+eP64BIQQb/HqapsBdosyqbKx/NtUtAAuWofL6qe" ..
	"iiZvPBhfSp9fcJeb/mDMh3tgBCPFEj1gEFRRY1McWds5QiEwv4qjjOXqa7R/6dIVqGcEmjbo3o+EVMn97S/y3JzK7s7lHTC3hpj3" ..
	"Ye0jNWkb7pfNPIVgcZoQIBpuA/P0QC+IvEJxvu0rLdKOjWzRwjbhz3MjDjd28evKPHhwTQq3PtruSNQJb2kt6/1QRXPnZhfouiAe" ..
	"khO7drkT7ie44linVmbVK98f934Vv/8qvcHHS/Ms8T9TOky/NEeOmTMQhxGxhfu0cIPRQlxU9l9Kz4Jgx8kBcIOhwFz7kN3noAgR" ..
	"H4xKAv7Q9lAeS8zlMxSax+OP714/sukZWlpkOVFfjD8cdxhoq5rEP7xEDFYgQEkd0Y0KlA556Vso8tdHi9KY3dW+pm9krp/nnBzP" ..
	"e0YnRe5Z/pGq7q+3Vr5wZMAzoRCsYPCwZz3KXJ2p/RoyHn7keb13PzL62TROJrvqywmrQw92gN+ycZiRQhdZfj3mmUiiHpL/1f1p" ..
	"0zQrCp2N3JkuPSNFp35z82rZMUR05bgCIrn4C1WDOCWVB85NKXJc3LjkOs+84LGf6kpFI2Rnr32qb4QWW2GgZngysWaxjBAGWbie" ..
	"jK0gOJkVOoPxGGg5rw5M85PvQDPpViRdSNb1kYBew9Y4nFacNpcZLT6fAd95ptZQueJWDfw/ge2p4g1GhYM5qQFyDuiNE3dN56lm" ..
	"yQNWmz4x+JYagyX6kbeW1Lk5CMNNoIYnEiEzb+sFhHuZZ7CDBAgCN4ZAexYSzc0QpqxlWMs8kFVhDb2QP1EdZEDvFjJRBL/AAmpR" ..
	"8Llxoqq/wlqKSfneoa9RwkOMqjIjGdjRRd+jrd2TDuyy0OF7yinWDdj7EnF8X+QnO0lg+jyuKhTO9aHOyLl2HCjOCu+tri4SvDFp" ..
	"R9wu9xvPExacnYduVcBIljkG6Tt7BY+L43Zbuz0VuxLcwP9zLHRvLgiJaQPtnQR8IaKoJWW5U2Iu0CaPtqH0warJ5f4Wqmr5zGIL" ..
	"y8kJkKuJFrSWal5ZEIAwixNaz0bRxhL9O4vi0tRCf1Jrb7kP56vFMxxdHhTIi84xNopnwuvcNmq1e32oFOrSk34v1pWGLH+DIx2A" ..
	"+3sjVs5NVupA4yHmpkOG3yEjOC2A2EoTifq2Nfr8I+AqDtCi8t0FDJo/6enR2NuBLngNSui74lCpth0EBRhJVHuxAmX2jRDqNRfW" ..
	"nYC52ajDLJfZsh0KK9bj7X/qACXg4npNfZQUCt4vtJSswPSKYX15ho4JSJf+jSOYC7Mte6j+gFpRVIR3RbMn0qI4xiPOF6H4ifEM" ..
	"/Q2e3Tl1/h3/bVzO2gmYvGLK4usSG4drBz+6SYlHYDKNkfoWSDgRnU48Q6pCd648XN5GnCBxb5tzpNbpYqW5kkca3z8MAGL/ktDR" ..
	"zHi2qWghwrKks4zLRLy4jyKbs3JD3z73qECAqlzUIrVo+avMDpbYq/gxWm2hss9TJJIQBI1yd+1K1q0vCex7/mkBqguuCJkA/TiN" ..
	"xZWmnhfdZRYP3k9omKeAfLC99mUFesWhP7NvLM0qEJe1vMDrFnvI/aEbukjh2vid4ao+NBurSBE7g2GgopRw6cqeHfgOqqKjTLCu" ..
	"jvIsxi4zZBQ6+gF+t4GMXBW5Z5+tW3rsHWGLWTwGgw58uyRevapjCS5yXRtmIiWvbdPWQfQyUlN5JTPno7rQUXJ2YPZ4PMBSLiUE" ..
	"4gCrc0kTiix2fi03oE4t8FUTsZEQTlaPlXPVkFkaM23Jw+I3HhmTt89lhUV78QaFAoOgArzIjPU1t6zYlU3/zrgktXbu8n8CEr0M" ..
	"bfo7K2fMALvUvZpy8LU2P61noERnX8chswaQBFH2Gv4tZsuH9CqofBDX+KL9Q22lFg7h4VffHzkb/D30SbnEuWPlUdUav3bohAGA" ..
	"vzqbLGJjywFr9/ZL/2q3G1XEcABErvkc0uzRO9+IQsR66D97wt9YY9GaR0oKbKLTdeJQDsapLdqZR57v/WSHTeUWLos4wCiuzbJe" ..
	"W2Wl8V1TZP2BrixwHQEdiaexdB1//RKQNRxaNb7Xz/8NEuBjJ6CMe6FxvrlD4fzkp3ePUa5gA7GfkcMoXTK7kmxtlLJHrakKboB6" ..
	"VucvmEr+NWdZNbB/EoQZZzhE4S3yyQ+JNMmaktevaEucWVV8wBbWfsU5jxaHWwwrRoe6FDIb0QRP6Li11gsHtXriLrJsodxhUo7L" ..
	"+fkXMBlEFM78bNg+mPmeucdbkeLQIYRTsZOdVI7zfxdnyaW0/ZNRdI9K+vjoQuvnfPxhBo5QvRLOzodIO4Vxo2bRfzLOWyRDhzX5" ..
	"4ertvuqyXZ82CoZ3tH5m5U47jUM0EzPEZjtf0lyUmafq+kIIAAgyH94X6HJ/hImYu6Y7GRlEutEPqqjvcr3WN1O8+8qe5rRxHMTa" ..
	"341DcKDYUw7YqHn4r9+jJAi8hnrPa3d+Ai90p60i78Rwl2rF80WNnZH0O2Q4Gm47ksr1WRM9E+edmduIuJFB1RYT2rxHL0K1F2nf" ..
	"UA4QmJln5Jf7H+nDdpRqbSqE86a6HRnMJGDDBKF4NHVt0znunt1nbBi0JcDxQqerNwaY4uPk75IcvaxOtzHJ+9XlVi6/xe7ZBvm7" ..
	"TS620ieUt7JWLpdQX95Jwc/9u4LbgRz/oXUi7jZtIDHnG9bwnKeeBZ2O0qgu2IKFoTRJeLkZQhNJfwFrBSEBHA8A+OSqIZgyWlMI" ..
	"PkgxI1NqC5O9crebjcOakPfJ87FjPg3sEzcWmpOeG+CBDXQEhnhYzNoBogEkBQ582qyqwsKrAaJ+Ck4ydDp90hD8lr9bn9TVoSV5" ..
	"9g9iPR02rBbet9eY4TTHp7kYR6wbrgW+UvkZ3hrIQ330snIO9ZbjQBy3Dk8UUKUNs48eKyWK2xinCdguFofxKRNLQrmbIUKlRxXf" ..
	"h7NmrZrMNh4EWlqZGSzPWv73ae403X77N/AGo/d4edOzTwc9dwdK+BzvqMqNDD1Csph2//kGi7F74uRhkn30x43IN+GAj8EfC9ST" ..
	"jT6KoJWx0m7AdiRrlZM9WVnL/5mjvsv/o29MXU/F/kH41G7TITQfDsGabdWwcR+DPgWh0tuWIMhut81vUS/LH6pGOfSEX9OtKQKJ" ..
	"SGCiW1hDRmGUs5XJGJlpMNVbQoq08EZNof9vqCxFmkQxqKJQA5WqXdxb3CB8KO3hNNKspbcYnESZ8uf8Xq+OqfGMTdJBUoSSJ+41" ..
	"DnzD94NAJFjdkB1uH564mj/HwJCAh8hkFysRQQPJ7Cbl45fGCEWSgJQbvivQM6zaQTbJ2yGLVnLU3b+ESijbZzDiq7YyPFjNx1g9" ..
	"yDbR8MbKKjN9bA8Q6/sUF7bwndcar2dBTUbdpjg7IAec3C+aAoySaJN70mZrh8Tek1MkHLXQ3jco/qDfNF4HkatLo9qL22a7yXD4" ..
	"bdeNNdkX6+aaEHaHGyjWAldx+S9jpoPf5/G1n+u/aqHLinnvohBQN5ait8qsU4bClx+1yTrnMWEvkcN4t2lRXKHk8pFGtf3IwNnT" ..
	"qwCyBxJ9eunZNdO65oXh6CY+UDTBMs24hL4iMLPk7s46ukquc9wtGa9R0NDZKhgZliY/4sAjxMxDIEod6f5pWTx4su8UG+r95qr2" ..
	"UAVjBuw/G41zVxVHFE1hJP4o7NtmHWEiwAIgiji1UgFvAzBwZEE6SDkY+YbtcP434VDpnrkhDygkFPSZXBwRq1WVbt/Fl23O6POK" ..
	"WUNqhvAngex7z8+CHAztH63FvOja1R+sqxaCgBl7/fcn5qdV2OimQejGvx33FW4Lj3uw2ftJNpHzuQPHbGdaoN10AFr6KoQqCvnq" ..
	"QZ1iNto3kFUGwKcBYNwleGKJVgGA8g/nO2sySocud1KVFQbW1wlIr+HUOA0FkJUhM9siJMpI7DaUE29AY7JC2YCwc1MPFCEqw5OZ" ..
	"+gvpPS77YwX1aq84AQW00LAWXUgfOnwO/WqpezU5jQxAY8R47wMWtr7kiEt4LrselmQkKz9qr4dmGF10P6gbE1+4hZsgjZ857APu" ..
	"klNFh8WKxIa98zkRuQA5DSe9ZkPMfmgE4Rx7OxSu9Rx3WYQiXPpdH+h9thuHKpwCjq9WpZuBt7Rb9ZIKevC9q45PmlswXmLBQGqm" ..
	"FqMUyIYWSixtrEZt7XPWgEpYRGDSbk+uzaKYbp9r2/tc2xZ2O1C3BMSGlxnKGklaRx+DiIDbkgbZpUdvVYlrs1eYgf7oyB8JeiEE" ..
	"fhpVlW1HuEEbket2ZVvqfgnvT3aFHWtqrGRKHUmBdLfnYl5KfDiuv9vmX2DCvyKgpNbcLZ3xXjq+8HkTdY7Gd8YJT/OWCjEYWwg4" ..
	"JRy8nSJClH6anG9aFLiwwHI4duRK1qrkJ/VHbCnMkVKFeRgPC6iTFSgk7DGbyJ5WMzzyakiWSq0S1Hr0jZn8zn8NP79aU9W/qdvf" ..
	"XvjaGKeighj5GkuOStiLS7EQRsjc1i6wDSxTEISU0U34ymDC8FkTTrACm2TyEQbvon59iFpQXTp4yZ9SYp88yeCo1RgnlzyrBf9S" ..
	"yXTIgsY/qzMESCzDzKjWtoGazxiu0QNzAYEXfAIFnDsL/hy0KWoT5XF4/4O10CLDsU28HFXMX4+sjweGFLMOImmnJxyQCmjv/eZk" ..
	"IiMlOzhqyA5HzspVcKvrI3VIihXABQZf2jnWMQUGoW+f5IRCfBYk7BzftmLcnd705KT2tpBcxWEta6wdmBqBtjbsHiDE/CM8oD0s" ..
	"XEfb4nLE8jZXWolzRsdkAtgvvt+qweovqyqjg4uab1rhrHQ6jwIGfZYqhvXN8aAPWuZ29gTUIhY5ZofJTe7h1KVh//7vcUYSJliG" ..
	"aaTmBaMCQKnbA+PD/rQ1a6xVAoSw+7dVJd2bp1QSgjuNDng68O/skJGVO3sxdHoaMK51pKZtGLwZ0z3oGUGXl0binyVdv9WRryG+" ..
	"vEN4icRePYDuubEXaX5hLaVZin7uc/Xrj3jc+wdbV1vr4zdw9aKGJGqG1oq1V14e6WVNJa2BMbcTKyJksXmpxZrpVLfMKUYa2J6u" ..
	"0AfMqZD2pwpPgHovrt/qponUVhKpCMMnOUDwvrBcjJqyVVD2EtkgPHd0qK5lYhuPn+JgMzsQiW6aNyj+IjiVCp4MroF9K+ge9V+x" ..
	"U6v6zkXmjJr8XkeMxTQoOXBz/8OffN7jKm9yhq5mA3h3V/hBWlyla5JltZiD0UHyWOLjgEtT6TXESeys5WEespnFHtwTm2Q3WVEy" ..
	"buZrp/KENbRk7UgN7LjdTUrMTWIOuZeIXwdYJSRPvjIrKgTmuSD7j+xwrCaa7oofbeHNTtKsdbZXQpFgUWwNjrNcCxv09MvVNwh4" ..
	"nii//wjznLqmglPJ/e+f5+bKhw5dTT6aTp/GeMLbjbPoWTFrIjdhVzx6GcbmxDhqF8ADYGaZqI8m5OQ0SFRnwoQU/4G/wpfyxxw2" ..
	"dpbm7IL+CVDA7VhrPhceCjU1Yo1FDJ+0pbxSfowsFelH4qepMjC7YtR5yZRFYV1EPcQ4pHcwWsjJdqo44yEQOuuOdjI1iSqCpzVP" ..
	"rdNiIZZa19c4PTTgb81Mb5mqj8UPW6MtmuFALeU5rdzvAoljwOLm5QBa7vlRKHPrR6WsP27kX/UlAO+49ZBNUnOMrBSNGBacK5A/" ..
	"vVcL+DfSzsnakrjoGgdYAWElLQ9n5VFNMNj1/apGLFELLx7v226Iquyv7m4euM8qrGe3jQKl3c51a2LH0muMtCnUN3lnN94/jeWn" ..
	"Gu16kjkQK+hSmRj1550vwUoLToA5HEiWI2EGU81OtDy4D/Mxi4HF6HrezhimelvUIgnPraUfAvgDakbo1A6kJplqP9eSLjesmZTc" ..
	"Gv2x04quMjukt2UbE1xvSfhzj1wgWCNJQXvRCnATL84v/qXASSzPRl+nSTctsGL96vkpmrfSKmsi2M7MjMK8br41Jv10WPubbb7p" ..
	""
local PAYLOAD_P10 =
	"XD8Vum51hKzR6lgFWgG9n0Ll98bNZeopdCn64LRfQvagiGg5j43TkcwInP2R60EDCvI9V7ry2ven2zlKwylLpmWYJGGADslgNmgn" ..
	"SFyXPDrZOJFemkpaFVd/twML/ucRPUeouUdXyM3K5HX5Zv3Kdhmtg/+DGayhg5mySHhWcP3SZ8MbmQ3+DPdFW1HBpQSSiqrgByDm" ..
	"ZnMYQKEAbJ9X+/eUWOhMEmmK/N5CUoxwwk8XCbSyXuMzjZQ7z9E5d5oDJ5sMIBlDQOvqml5W7RWwHWxluVsqRLYNfmSRpviIaqer" ..
	"W3lXObOf/MlONbGKg8w4k8MOmQ4Q0cHH6aGEhKNHPrgZh98+jKf4PnyKwqzq94tVZd2yuvczPu0Ua1cqcVYwFtWgAAJ/HT+iw94i" ..
	"b2N18SHLvSo8Vr3OXpiofwSX68MS49Hr839FpY23gx5DtBHkaJCCPoT1/aUXmTkK8OqleXB1t2EhUoelIjGQTxXmwtsISgDOJWX1" ..
	"Ua9F49FtPWsH0T4xjfi//LzO4HgS6qrh6Gc+WFijoSNSWaKn61uQpIyjL9zdJ4NxX34OoO8vf6O3QQtlumflGuKmBkYDbL39I64T" ..
	"nFfXKXcg98GyQUBZhzCiUvNQAGZYCSUdKv5OUGAjY87sCLbApUHA5clhwaCv8Mk6BxGhMvwuGj05KMTm/mWea5t9Ukl8MfCb0rwW" ..
	"IjOQDSOE5OcTNi8Ra+vBqi8tQiONmqSqI3r/fC4eDwD+v60uGwRCsXi+Au8liwnp3VuOpuiQBTn1XhWsnlQIqJpIB9m/W9/uJmNJ" ..
	"islA8lgtgGiKFgLEQfvPwz8nGccbse5Fg/ri05KvigFF07kIOMGNFH79mzIhH4mVAzeHoWsDtvd3S2MOHeULU1tZX0HulZ/7Aqqy" ..
	"uTMO0dnDWaCZqMfG3oA9IWQNgj4KCc7usW5xUIBlHO2WVQGDhYX8g0CjHwJwiuM+8uJL2Je+4sCOZYDcV7NpXRJI0Xe+PedmuzXE" ..
	"UnTWqIx7ABKcUXtnwVKGjXDsflQeKLdP+Tzmo2pxbxGOHT2Gi2mQU2BCJ7Bd/uG84UBuC7Byk7g6spI8kEFkcZMCvnnr70l4C1uj" ..
	"TzCPVBJzZYzYaHrIJxU8up681VEahxnQTXwhIJ20nooC8MZXrFilFvAlxDguniPEcU8FOgdluYr7yZziott+uycUL8i7mMP5N6TV" ..
	"hgLs14wVwoJa65Xb5r7QuIZEB0Rm8j8chl0SZXDk6KG4t8hzSbtyBHLAY+ZywxFvuCrJY6p9qg4wkOS2SwDrCno7p5BUr1zFDXv1" ..
	"CAbRdHkabKcdqxbb4CyKFZ+/7+LYN3XvPOCfeZOOPj0ZCU6h464mVyhlHggXimptoFAD6LlAESys1TkNeHFng2pRD86gmQKVANCW" ..
	"s5zsYJ8o4NJYv6qM3u09DRu439V/bITmgA1mfD8wBP4MMs19KRu8f/ciajdPqo3uIu4ml0/s/bf6krpV40uBl3s1Y/ygAvyHuPh3" ..
	"YIbtFySZEty5d9iwoNR6OhFpAPgtiM6ODV9snafZ50726uc/A9Ls7Dk1t4Q69JLyEwlggBf1LcaDwngyrvN8Ce39SYOBVzvBGmIC" ..
	"YyUHwcdy80RIEJcm/V95EC88J7aNLUkcTGK6byBhLulWgtMXKe6+9Km8oQgYe9rl3/5OgCi1AvzmJMkkifrrkenb8MH3KkJwtV0H" ..
	"oKjRtGCYd4QVwYDtaC+gITRb5yqP4BvCMzKQL6LoGW8eLs1iAFpPQadIqPAGQAzVk7/b1/XHXaIkEASX4DiKDCLY4fufMpBZ80JH" ..
	"wZxUOrh4Zw2zqrANgrMS/vNqjMef1dHOcq5dpC/cySuDtPvC4cPjfk2qm9cMOu2hvrE9naBHSGk1/29jZkR/YHRrAkdtMSh/phMm" ..
	"UVb/bt936yLoQ6Oi/NOshWeVZiI8GRYnwctuMo+dt1YcYhz9iXebFG/Qby/yxXttIRdRQhrM4CAYrB4bNHkl/+JiIaroKiJPCaVo" ..
	"4WB68gziCftMKSX06U5F7k/R1oIEeqFW4yXBc2QT2VKHo0U7P1V8JomCw9xmziHouKpOp9ZEubzoYIVRIgJdUBmeUQYqgpvZyNdI" ..
	"djVc2Pl7rLF3loJli82YuyIE0DUFvo9UJr41xG6vaeYnGNTDq6BSpM1OmV/SdCbVGYVwpv/P3l6ej3RBQMbb28U5IH1IqdgBD6sT" ..
	"WhLWkJ8UnZDIUVbbpUDbcDYZAA+DAM4PGzpNSzLTltQGsASR+n7qzk4+dzYmP1W7BRDFdovsXgANYkzVq+v624d2YjynqLJp5Suc" ..
	"dczo0HA/uz3Btc4Iyb804Q4ChiF6siUwEpiL7GZjCWLPn7/5hSzBlSqElv752EXUpEA+YW94jlgw01uBRUgJRVsuW021sbFl7aEm" ..
	"BVWXYxOnhg7EM4y2Z6Co87UR4r9/kyRUsbRaKyvsPvBHFQut4Vzlk1BZ409djXwrrSY5uGVuZKzD8jE8q0bVYHpc34PgdkljuHGM" ..
	"JnGNC7cbL4xSipnw+ju1LJJ34S43P1PlYKEvlTnoWmMv5y0Iex3ZOs/amRkMVZmxC18KUUazksF1FpV/qqTIWQzQUnj1JYkCf2Zx" ..
	"wXmxgEm5kyTUkg83bI3dRDf/gmsv9xfs7Lt+I6yA1RbSH6rHeaj/qoa23z+8t7uw2LaCqHQTS4o8Y1/W0tWYU1IoVhf0EpKu5kew" ..
	"asTrUFukcN82SrqtR2/9xy1qnYY8wWMaOf74iqOoI4jjkxJ9rDH1VBY5pshoEV4UNNIXPsTM6cpxG/odPglDzuLJBeOnqaGWTkMb" ..
	"DJ10U7klwrK0Aavt03e1wTb8F53j8Mb1m7B0iykifbb+GwSaFhDpdKo8XjPwo33YM2i7PAutwHryInEERthjAM233Ilax2BpmXJX" ..
	"mM9sRQWqrpBENAIu7vu3pLVJxsR/7C7ibM9nyBj2RIrHAGAHRrYG23a97eRiBRWuQ2BtUqfOzZMmHcuQ50jPhC22557mI66mYLre" ..
	"2D1iW+0aP09lhME42DW1KJpCUSZR57DLunvCd1SMRtSx+QTSVR4L6qhPVOVuEh4IAw5foG5PLwNCA+avHUulngq79+NX0ILnyCPo" ..
	"CFLlvrvlrEma7+uZLZowGsHRgqcU3rBgm8dHgrzhai9v5urJ3jWpAwqjbe+PN2hfs4Xr3hWR8oBDN147KzKpk/6fyFjO/brHjdkD" ..
	"prYOy9zf2byTIEqxqH6uNdox60lz5Gz8i6ymTPNTMrGs7HTaiaeKCrEFtTWduzR34dfLgsRMcNp2DOfAP1mgqSNEZCcc22lHzYrX" ..
	"99kX1tYXM47Yatkd4iXkjpx/iUEE+q+USj7X/oMF8iGcGss/Yl6zGjExL8VIP6asrBPgnD1Z9RRS7OyASyMbakGPVcbc0ybI8SXL" ..
	"OO8ykSbvsXKT5JTTRa7MjD6gYhRRXkaQUB0BOyE+/Gk9xhfJWycEXh7zRlFZTZE0O+IgrehOyVhc9QRqHu4tnfq9AECVlBCyJ2hh" ..
	"XCa2EChpn70mLxzp0rA+Y83gqPDPjCHg7jF601hjgG0Oah3zIJqLGJaK9FnnL8EOE4FdQlRUbIYIMbeGOOXdRXCJpL9Ne6Ng/iZa" ..
	"HhoKPOxBE3gcZ9WxXrV7JOJ0FDCr5gUWYKBsuyy7x69RdHEe16Vcp+Cs+Da1UN8tQMo+334o2Bf7/zxBegluGyZIdoYHHdZD0WNM" ..
	"dpk5XGmh1pBlzMFmjKLv2DF4QVSurQUndqavPPKJGXJCeGsKU5ffZZa5QIV2KyT/JcgIxNQs9mbm1+s5tNj1qFB8BMMBJle175WY" ..
	"4Sb7y+nCDdaV53c35u84CCSOuc5nQMNZfn8DAba3Eqe7Jeh1wIeBEbVRXO75jvJ264G53u7qnpE5p0vwTSuwZzcFaYBbJbZVzyea" ..
	"ut2ddvfuQEwqVasRHAtuSU+YHO603Ehc+tfwGlh/5bCr1fcLQwGdP7WUcIETP58p9RkwJUHCApVcSisDPz0zPJ+1APtagIkyp1fC" ..
	"YeUJ0DNW7dQxKYXC5wpahkfD62/fSUJHxKXm17kZKYgfztgKZw/EwCNI7kq00Tw6mEB7DNcS9FfjstUsU/Hst54mHi+lEzLznqL0" ..
	"4St2SwL4PJ/xN+1HxK+TOn970zne38/riM07GWSgwFUhiardLKtmLzITy2VyiEH9sP5JKmyP+pHeGS9NRuosvtbkTLu1AdA5Rot8" ..
	"vTM4V5ijVr4Jw1XS3NZ7bysuQ0S0DgGotXu2wVq2TfzlZIDbaUd5yHY2RzYkvsiQnDaMcFzeENSHlgHIzmCf89mFXcIJWhcnhsCm" ..
	"weeI8+caCCwOlOoY0xVz2lcP7xGhL+jpQUG1AJbF7s3HfVv5gkqmniWqCJGdvbktkNEwrcidYW6TQBUtt1xqQqldgwhDx+Jjdia7" ..
	"j5D7vFOtunreB6plcHYM0P70aqQ6fiBW10qg9heWbVmp7aGmlj/EKvn2Q3GRiNsrir2Hb9ZR4kYc2HYzkGIbl6LsBI+aOTy1JuM9" ..
	"d+tN13q1oDvWSnYN2ATCgDA7" ..
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
