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
	{ seed = 1793440029, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1788729611, exp = 0, plan = 0, hwid = {} }
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
	"TBSR3DisSQUao3XDNeRu5ORXkUsBUdhGpB7tWEKPKIIx3DayJah57snW5IdWl8X9emfnwHruPX6y1jAwN2jP0lj4RsC2VTHc4oAx" ..
	"e6XqZpMQ5hJAMMCO6oNNcyfubM1nL8bQABX92g/vRJnFJXg6bv70CVFvvTgiIgbPQnNsyWbkShxDGy/VaFSbktR9BWegS9DJAmpZ" ..
	"LoPHIlU/k7AhKSeF9MoLsCUdFtUEpVYmN30d1/FpgAv3lLGzG2TSlm/nDBixl1sPw6kMb8EDZNuzG45J+t9M2gUUi0kctqLwv1oN" ..
	"KaaMimQFql8hS+DW2AUoa3sFdDjvf1vy6OAfn45+iF2TcWl/1/wGRAKRqjyl9oagdqCkBnV6PN1D371ycD95qBLs8RkQ8Zqnujn4" ..
	"wL5kJ4lJWs6gZX3IQMGcIeN/0iqa8rIh45GhFQnn9M4Vvrpq5esd5hN4Jwjd1VI+sOMK574ooLEsNOPg2mjOaguMESix7SE8IUtl" ..
	"HilxBLdDIB3c6SP9T2Zeo8Nzow31FWhMJfXmclqyzhWLVLkdKhV+LEY63OTtp78DMuW6DYVIn8jXq3RPLKPegRcExQo/RYmEpab7" ..
	"GWX3crxfsa+FI60/LjcnXycWWrpKpqy/wkBVNcs0ytP9f2mYYcQOkR2WV2PjvHpbtRcZ4b33R4sA4zyW1XX3P+Ffh9BqLvhyvW2S" ..
	"WyXua56a325zrhKgYGMV6MAQqOyxRvC7LV+FmdrhFQMrIjSJGdy66Oi72to29KlpXUqNIoOecIsVasyCIAnbte/DpS8jMjFH8DLC" ..
	"oFAj1Ulbr5bqBfkrYyTSw1H+bRJ8eBed4K/gs4nAusPmPgyB8ZSalNx5/+/z3vDYVhW0a756EUG2SdfnuK/e1myGE6FOuKIhHpho" ..
	"KwYO5YwMAgHwuWtnORyeE57Ezr2hgXqEh2rRJiEyiVdn+3P5t9BY0d5MK1uRnKQ7Nh3UOVR9aT9+1xGJqAon/U2D85YsoNjbr8B2" ..
	"s7tvX60R3KZ8gUe/ZF63Nqkx+I8FMGMXvoHiKlAvHzFY9bPeqT0vvtF2c5CHrhOXZExatrs2cak7/5TiaQNMN66tBWyQFo3BzUXi" ..
	"kIw3mKLnqQKu4Lk4MeunQceZ1L0yxNd9aVLUqitVA4pWQT1sTI1HMhpu5Pqj9Dt2XIW1JeYjy5H6z8jMCWcINuV0ZeMSO/2yeVUS" ..
	"KqY30ZBexoK0CedxXrn9jJunQuw1L+uj6Id0ngVu7RTSY/2WPkVw5K2jmjKpisxzeM+NsK2o12yxIewMmvHfqgXAxPmUQIf//cn1" ..
	"v1xIGSiD0N1WoPaGABBui7dHtSAUfh9hreYk3UltlkDylHClOzGW4HZYCXvpddNsivRKDJiA47FlUzrh9nOZVncSe+OQEQQ0YgcS" ..
	"cRd30XSIO+N7c+CtmZ2XL1/1LwCd+3UnTp6PTAikb+xYM1+2FGKdtqkofa65G+b4+7/7TJbuSaoc5dwI1UAHrdFPka9RIDhZsI5O" ..
	"AxwjCuiVoYw0LhIEPZ4MLun+jnSZ8sAd5Q+J1l3smiOxTq91bfcPToY46R7bP2EzkKKnnkLyAyUtIhgPr9w0AaemASM1NSXXIOC1" ..
	"JR5DWxthQxlRsWRGP1saFPcJw/6OhTSyErKgGT4bYdae6r6+x5v5DohcaKpkqcNmBcCEM6P07l5D6qNbc1cub7WS5g0u48/uaVCq" ..
	"WsLDhyyycEVrNkJenDiQ3AsicUNb63bLPGjty8MvfMHh3/pAeltRSeyt2gj2X9G3yZH3HBGL0H1ZFMJqu2C+BIffSj047hjWbUgt" ..
	"873WHaDRUKtF8pTdPEQVQedJ7dTQ6AXS5lhjwGfEp8EsM+JGyF37+senK/go5pYUgvwcTMoOPlfX/tMXF1NmnunZHAx/dLxr654+" ..
	"6FAs0Nt7/VMx7+N39qvbkjY1kzHrMj1jEBKKdE3QK0fzTNCyLYDeDrW5VULx9X3UsiGAN9QAr5t9MSyt97f3JDnSEugZFln9eUOc" ..
	"Jn4YbpeJO8HodaxqrUwgbqUhq0fbdGoIHeQef3K+4QEmycqdVa7onLHgjE6ky+PYzChz75KthKInbe0o7+3nhdzdK+pa+ObpwLnt" ..
	"xVkf3MOI/WC6vTz208g/H2BeeHQqBhkZnYBV1xzNSXvHRGp6DWqPXWB4fEM1j2SbgS0MViVHT8XELqkAlhvEL6orFz6Qs82ZzwwQ" ..
	"TKpm/79wCi03qvmXfN4FZkNmK/4yb48321yRC3KTux8Zf/YfVvIAaczOtyvNtxcvQvIuMVEK4QpnvbI3t40ef0VLX0Ema7rUjkZY" ..
	"vLieVNRuqDO+gtfT3PZmVevfbifgNkQ26BRSEMt20PXdeTWbJ6FZYoEeYKBnnYRhk5FA1g/wqn0N8yncx57qH65uizXRbo3lHh7G" ..
	"yO59kk5X19iJBpF5HE6cMJlg+bwHtJ+sBSAg3VL5XSVaLCyCFTdlwU8F7qQfqQi3/jM1HbODFiRJFUqd5fk5uK96CPLuBmorowoI" ..
	"B4fGXG0XSE2OJo5dOwBY3n4wmAZMkCeF/T8Wqe+EDR+2r1gb0kGrfNCCkt9bLMnWNW3BzkzoS3hJBwPE/Rt4XWtve53bhl6fTNAN" ..
	"f6LniQCl6GTdREir8xsttuQ30OMqYknHKKgCJGGKXPk6rF4cCoL1Fyklj3icymul4QdQhPchvw3dutdf6pn1XSqRClhkgpfw31YQ" ..
	"KNMmQNBFzfYetzblkQhIWrVJPirs3TDCF+0ES96kGjF/h6TxVxJOlAVfX9Ix3teuh/bM9YC2vY5KEZudcS6V/NHyiv0PskHNZDX/" ..
	"ix2PJqMAHfvLUCFDnBQ1aehZbEK0OQkXhaIWv5lWdTABvmi5k76bSHapuNrv+A0KYCrYBshWKWIwjuHp2bxOa1kANq6I4TXhr367" ..
	"EpGCcK0OcTwb2yFK7SNpDmvTLOUaPgTHU1DnEZCdI7rzEndg+47ZTbfhYE2ZFeGVgGcLZ0EXFlPLVcdLv1x3/rc7ZM5Gfo0hVI4g" ..
	"BG662BSyiWNeZr2w+SG4bEDM1b+LS/3vP4pCRWPjqnkCxs6cNxTUWiIb6UWPorK1FdRg0fcFXO4aTYdjH4MJ33qet85IqzsXziM+" ..
	"iJmLa9P6q5KOp0RFfCMCo6SsH6qJrUKI3uD+lq2iDS1dxnZ4asuCY1UquW7GKteXLO/xO+Mr+jn3bnhlErUOviZws2tPsKI7V0oj" ..
	"VniTySg5yAHMkbv01IxNDWP3SZWWS2auHC+7gdzmV4aO+/4MaJ94fpIzDHO8GkwOIb8oGwgtERYPUC66cKlTWFmD8CJihAOeTxgf" ..
	"Ii/w9caMtjBDFAEVFPNsiBeMkqvFqAfoARlTq1H8fijFow8pblxdx0H7qQdUjMeTwKbwzxrCgLnTSPcQTBSeWgnAKrwbDfSFzuf6" ..
	"hr3daV+ivB39bWxrsyYh+mqvH7y5I5Zh1GIqSOb9u2RftxHAzZ2Bs+SE6e9N+sDDB5L+WyZVk8D7G+nNNUXBezdAyJ78iAcPz21k" ..
	"djSVOnNunno8geV6uvWvHYAuG0H03T9GJ1SYKpn5p3WWaFM64tXn9nj3wCFLE6KJJcz+1prwSwnZ59DVRXeWJEDEYTGP2QUTl8Ym" ..
	"qnR/5XbMVX8iiAneEuM5s10y2rCK/Gr9e7WV+AaPvIHBkuwlQsWq9aVlfyC2RJrrBt+aGgYeHL+a7WDl54ZnFG8EZI0anuqRO43I" ..
	"Nn8g7Behv/evAy/Jfcdeyppb2osYETZ8TtFxNQEtu6Fo1iIlQX6XZVff0VFhiBu0002LJn9Cyq5ZBPguXUmfRRA6xAtGZ7F2/wPB" ..
	"aqYbWCRNmtgKw4b5zICWVSsv0hef1D5KM1ijuxK4puRAlawz9o1de8O6NutBQL8Wfw2ZKGzlwxFOohos17480wfbMAGxVYs8r4UB" ..
	"ELN/RbnluRMbM1tYWYrWovjX1/W3DoQgcNNJyjRpAUdVSVSyDnxk51ZWh0gFuJBgzO99GYwbs22TcGCeose4n3lnLrcQr9M05ZTe" ..
	"hTNBCHiIo0avl1Xvl6rSZH/8z3aU9y1ZFaySlSacubqKvcGZS+bX6NxyVFhGgEPCJJVQSbgrnr9m3RKCWobmAaBQdnjQENg8iS2K" ..
	"HEl1XwvMOFHHbcT17aFVqqOfLx7TWoRHB4fZc9Iiuq7WzCR4B2ifWRVtCu1o/ZF7L8beVZhfVo+ok4iJgOIgexrcRcKe6+t7VO7L" ..
	"luBr9Lr8n3dr+XFLRqOjuOZjooecP9pZFQ64NI4F+jReoyG/9WtZyk5YOQ9oVaj0dYTStjAgQXXzKzRSdYuWdO6uYiIqpDVQ/81a" ..
	"cOA9MgvWhrcHVouTHJBmUji3rObnwKKV4THTqKbmCH1MJKvpFj39J5bzYD7BBz20ij665XRJaUxQsDnWIfXOG/oMam3VEcnhQgVc" ..
	"XyIAe+U+kT7x2f1C4d8aX6X78BDqtvD/uokoy0+SWkV5kRfuAds4yE3QAFNH5dKHQEnBpUy7voyp9sWeGxTy1c/Agd+C5WpChOQG" ..
	"dZJr/dUK1/BA2eCxbk21oL3KHdsS/wyfl2VD/w9e1j1uaI7o7OJ3/EAEN97XXUTJdQgJkQQrCQ7RW1RZajBOFX2ryZ7OfIpHf2NA" ..
	"pxWklWc5ceKS3bV4RIgpSwosjT/LDICQjUfJRLpJoBha55T8D/Jwaq6FJxELcCftI5rDvY491DN7Xqav7gv0GwY+TRyq6X9FU4Zh" ..
	"rWKnEtBBUyEOX1NLzg90tsa/ABgYafEpfMpiOBxGawP6qgv/wGvCgNbHScDFuvXeYclUPet3dx36ze6BntRz4vcBVQolcyyJZbYU" ..
	"nSLRZnxdeFW6yZjbXavi6LHxCoIJ9I6rVsHsXZIE6orsbqha0LT59kbcC/2wnBfZOuXDuZf3JEprbMbETBKA3QN0h4Cl7HJLyRAJ" ..
	"Ro7HhrxTMaFPoLpSkl7wku4uQk4gbsDVJPZdUMAGCY5MNe7tFO1q6dlGuRIjmyIDM4MSPIdHzUny00gFr8s6ff+lVj5MuqRJW36E" ..
	"W8IWkVpJjfinGpAi+AWDSFSNjjFQqKvDSlf6d8K75DHaKd1WQtZIKk11h1TOvhs0GUf5MuVVvj4/6EqAfCauDN0RxAjMf2sixup3" ..
	"IotJ6EWMs1VxMPdlb8rY509ceNYa+QTi8FQ1x/K8ZkqXh/52A5V7sP9nXcPJ65Xn2jchzpRGxYBam5v/CzMmwPzLTV3Bz/bK+1b9" ..
	"RCbpPwjw04d5SjKCW+t3K22eSCyuBwJeaByJdWRPsYvFHB46hCnwqAoaZZcwBfTSozVUhR4tHNAvU4wnE7V9d+sBLIfy0RXNVCyF" ..
	"Cp4gl90LE5YViR8NGo9aE51zfsNthvz8hktop5Vfv1bVdPJ4z3F9DjQDK7VqHjUi/xYEF888JaqnBAeDXQ7id35mzI2IeEHxPzZK" ..
	"rlfzNJ2rQubNWKWLbrRWSfzFnTIlEMsz5sMRWiwCZ2/+8VEyk9QqEmUGQBzAFx4cD34hSYGNrOPjWFGG1NECS78sICuNx0/jzslF" ..
	"a+Uf+tCgPT+7cyGC6xJQaZS/zlOzl83UAmqKeLOBOTpWB2JmkSz2qIeC0GqDEAKF9KVI2aC84fyGQ/sn2SDQ9pkjAQKwP3LaHbXJ" ..
	"kG4liRXtCS9iOGselSuo+O7Bqmz0+aznCkjVYDEJwEuAJipuC050circgAOgrkhBgK5fJHLaVihjRfrYcWl0CSynygKngw7D6qnH" ..
	"fMs0YVPRu5BZVL9+z8TGEL34NArMJF0JqpYqZvUVd+U76aJ0YNq1KG92LYnO93r0UOg+WDOBXy0VI1hUiJJRakuuSIteXiSflucg" ..
	"VkWmRPYuOvJ5kIpoxWXFnwzlPRR/miggZ6ZoMTCnVRnSH5pjTQ9f8WXf/TlASjPfSvFMpGw7xSWwH/zCPcwHCd6IKGhyCSP7szbP" ..
	"BaryprxSiN93Mmlj3XJQ1eajYmKLvM6WOBir1pOlX1/tuZSfSnYM2fg7JDGWVh+QyGWj9LHhJPfaNwbidmov620dubmtMZ2ztqHG" ..
	""
local PAYLOAD_P2 =
	"aZtnhlOHSf07l+0udBv2491kUKUDQyiQQLxzhiqusI8VNoH3b5Z0GscHGkd8wiOE1Oboo6RelnIm4hM/cyKipIFh0reDt757YMqm" ..
	"QhW3mBuqUGJGZWZ9gota8Fs9MHrOC2/6bd+gbRPKGwphYp4d74QI6hJfWgXFVTguWa200EFTylRLRQcnoChIMLhVZAdHk6+HoxBC" ..
	"yuEzMc1+QsodCe4bDH4Z1ww6kUmE3z/RyRfNxfC7CRWZ+rawXArqYt4tpZWM2UkO5yWEj58WYGrgLoVqHJbASYsQfKz43psj365B" ..
	"GycBSFnrfsv7JSYhCXrRzPB46ZXFsqT6oWxHOHu6VrQoceYwU+qhiLjr5bEHS1Lx3LjxDjQUdCYvAT8kvIKdX5fUy+kHMBvkI2yO" ..
	"de2WHYXBBLhVfGmzaw7T2CpyXLimoOXDGLD2KxjUTvjCxslxWaxHuAQHcr1LClYKZQw6RjcelqaegJWZ0EbcA6qNa6FAoLawWWSy" ..
	"etRs0N5qZn0M2l6lH+vmUxSv/1Lz6RNSjScwIb2kWE0uMEzxj2bXbhXu286ML/eIJnCO7J1vrRYSfhwa1gfLHuB8OlCgunNFjK4y" ..
	"6wT6DHd0wymudE7R73TJptGAIOy+fRFEWmjsMnVVJ3DXEdPQnMX1bUVHWqa40+H05UCl5yCJr4hdjjE7v3OQZaE5qERFi3of9NGg" ..
	"sdj9n7U9Qv9WaKimsoNz2OWm9tXVGKpgXVt+x+hdpWIozmMpE72SCpdAs8wfPjD36tccjlbKfA9Ee4rN7K2JxNMeLgfSP5/AOyhG" ..
	"FOkmu95tKvfrKiw4eiD0r6rJDR7sSPb1AmOG7IOiwg5iEFwJDoiYakPEY4/BHbLaZV7Xmd2LKT9WcHmm2wIXahnZbY7n2WeykuyW" ..
	"ldAt7fto/K/SGkNEGnJpw0zuroA/VgdH+0SO96o66vA4u5sTb/rFxJiTBe1mg2GE7jyRLes/zIAoQHohqIg367rclrJ3uieJrjRw" ..
	"C5G9zw6HWxdgnPcNFFn+L7IUlQq4YRpPojgQ8zz+b2vZVo4q4H5oKGCCQiMibjOFTQW6jGuGI++Fyhx0Z+Ixl4VKOKmJd/0gJBPn" ..
	"Gm59KtVPdekV2NbEgGM8yBMvsTc98KmdrsbUx6sf20ISwrcpdV1lEjSXV/2/RyIgrZFOAuklLWN9YBKvjSgtg5Tv3m9eYMXs9skW" ..
	"G69jLp0L5cgZeYqa4r3ysZ1RoOQgknAiYA7rnuUx4ZsUDTi/QjZfuEIWu9jWQkpZYc9Tv5IIzfnr/YUDb02zpAlcSs5+0WLgkhpj" ..
	"fJ1thal24KV/lZ8J+P6fYrNeOA1khEuJYck9fOoZo5Rf/pfuZ/G0NBFgVDuPdpqVRlwoJ3FrxwUKyx4mm536x+/1M5V1XH6o5Efu" ..
	"LXY/6HAzwXOYIpUHBBFtW6cyNw/D48Jr9/c1c85H1j/lvejvvymbZwrbFscFppq7AiSskE3Kj09HmMVOkBLtfx55+wBT6QSkDsTN" ..
	"J1U1/AjUndBB+Ynvr/rqM+SMO1iV6BosUW6nd1fziy9tflwLg/ziN71tWlSePvlOOPCvSneY5+TY1wPB+yz+nu2I/vaQSZhnH0sh" ..
	"c3AJFFsmJURB0BE3lRCVbrA9DAo21WqXvfZ+QOPXekGT5F+EOsedBjsaoF5P3Bl4musoT3nXGWcKCFJrfKr5QkLOO9LBkD+uDzIt" ..
	"hFP6p1IyKL0YKLkC++JvLmRE5L1NiBjM/D6r+xjZ2Pwd+nh4sQ8aXguZ23LPNxggZBSH77nkowsj3MgttNbfI2hGKUo/usoqT24B" ..
	"AHU7ZN7Iyv+AWlNp75NoNWfRPyj32/4Z3cilBuVeJMSWoUhRhpFKtoesY+R3LPhD3b2ZaGaytq3IeWfZW9m8oVUt2ZNwKmoI5vY2" ..
	"vGaeQk00lHcg5EDDhu6t26VaXqL580eh4rLNfWXJf426LdBK44IJ1b0MNCQ9DU0f5MXFPyKPVgIzOhhjswVHnMAb9f2piR5lSi+y" ..
	"RTXrUtlwjZ48PuU/ojo74Y21fffYezGQKzLMGMB04dW3WIMxgQWZUVhQuh4PlxPmV2MWuaqK4/puIcagpEp4g47RBFMK5q2eknU6" ..
	"GXhoF+lguAV5eVauiHlSHNWx8b9C6ANVmiih97CbVtcU5iA0uluHgVWhOthu0iXfLnGGpXmSQjO6dUdgKhPNzqeELQwF4svfgvIS" ..
	"HhwfunMFTK0Pp23P4zdTZeNb1qFqXrU8/6LuQvMtWNC3wxhQuEhg4Du/AUJ6UXY3ekMia8eIMRpI2b272gsUH0kvJLvAhqIwEG6J" ..
	"d9cH6JNP5tjP0GtJc51iqTwsl4CHTvC4/gjYqLZg9xvqZn9yxSxLTjbdUPVaF2Ck9eIbvXMnbn2UtS0dlImMHHcqQsh/3yOzcG7r" ..
	"KHPur8j+vAb+WnBdivqEdoR4Rtlsd4lJIllJiEmu7ZCU/fHGdXCICruVOnKvxM1kqcXDuUZoOVQJQqHu4H6mWNV9jI6xjnuVcCXO" ..
	"ygu+kNseiLBElxFsaes+0UytAMdRTowMv/V+SZEVIxQtT7M93+XSTV5iA6UUJkjmqhtMm6OvqbFCccwpTWfOogAMurNLY60L/Q97" ..
	"sUuem/VEfAEpQaIkDVRdxdTerqINC0UMLGSUv+9tH0DX+1KaSzeAOTWnnHWf4QA4u5trH2nsueR53Tjkz+l7iPqq+cxg0E2epuSv" ..
	"KdxiV2Nhkmm+hZcxYfu4x8TNMgplRQkb46kjxLYV7R+0bYGwB9GPLBkMq9viDb9bMRskuCjrEk5+KOtwOpewifihCfKUsmsL0rO6" ..
	"TSylUt0pFfWMuldqJ4a2Bq4FGW5eJBTnkogHFA908ayliI8dVow6IN03u0Nma/nMoU4Ak6zaWMX85i0lx3eEzjQHW0MjBKxJjJY5" ..
	"eU77xQ0/H4lXL35KBPmHl4kCqMPUXOnGJh4Uv8Fp+G5dxzAC3fGA0NQTPDRU1vcMCJZ5sSKeUHAE9BOmBuCH0FdhUhGxaZvm46QJ" ..
	"/ZDN/vxuFTgoz1E4cmEiY3D2XiKgqkuO3Kko3mQoeWrvpR5iOScGaWFEhQA33yMkkDvmBvRPJYUO/UBe+JfLTaTWulfA/aEGW66T" ..
	"XUhMC99o/uyCZbMGSgjw1y3rhJJJZZ9RkYDGWOmWl3iNh94Se65D5DLmzytrRXxghWIvlBm4zU7U6Qz5ay06fA/a/n7ArRDhDwjn" ..
	"m4PszScE4i6GpphPMI93Js+wVyM5i05ZoWRCpndXczMFJqerIimGSIsZGm1C7boFVX9xlnCtGGkD+WIA4OveVhsx8byl35NqZ/FB" ..
	"zD8d5AQYtVjGCKBtYxgFMvzc+zdyCXCmFMI20s/jCnNYvhFTekMoU8KoaFhU7TA0pDyOeOe301+Jm5Dru8rp6R1R2S1OvWq9xFVV" ..
	"t8vxj9vYd4gxTk9v6y2iyU4UqaRXuegaXBRW35ToPBOJP4cCC4lrq78duHVyKbLu48ytDeuJXa5K836nIynJl9megveswDiiZsUy" ..
	"CeJLW1f1B2NxbeqS8f3Gch/CvfSBl4angFiJp/nhdPsrs5ZiDsqN8RG9wv1EYiTzq+HCk1UNcYew3wE1Oo4nJz7TJr4tH9ZwVmcq" ..
	"P+RrJa42deoq4RI1dB8K+8WKa9MufW+QKMUbO5njZu9mxyWhCfGdYa+FZPXufwMdKh4U/mk7VH/ko4HU9b0kKZlp03K2NGPDb0Yx" ..
	"L8DoL7TsA/NcJJDpzASO4SHvtf7THzfyzvp0LE01glMXiUIFsHYFxTiF99USwGNItLX0qAJSYUoIwp+ESmghmytcICk8324GKSLf" ..
	"4sCJbOt6IBCYBVdx64P2+a0FQ0vaBNXTMT1toHnIQl/r3B2z9t/4DZlq6SOzNpxEeKGUsMTmqJGGe/qFC/gVkHJxiQu+i8/+6shr" ..
	"8KXue7i8kGTl/ZX50/ulPzJQpTiGBrtRYA7TKT59ifVaAfIL+sSdLPlL23CFHIF0HfbaHFyIYXoEPTOTCRjyU/D7R1pWKytsDr6d" ..
	"icY50lMvHXyt/Znm8BdXsWGwlcD3Rh4ZSpS87EczSAO9Aa84IrdixeXadyqZZfig8seqU41hTNOZX98mSk0s1d7qF73KWgwOlDr8" ..
	"pW/T6Rbav2OCFlqXq4R6gQZJp463cajdhrfH+4O7wcpXrKyhrIH+wwyacl0swRxftyq8lOqulcDZwTgCjuSj3ldvzFjV+SRtifNk" ..
	"Wbj3E3JQpnmDI+m1Yc8oBVrv7l5zbNQxN35jju7tKjHSC5meWkokaWYCD4JDLrk8vlVjYvpO3dW5mH6LwdiKwrGpDPt2zZti9ToR" ..
	"DEGCs3haNK4SX6D7fs2ypFJFj9dZzHDR5A9IgB9rmT7aV5DgjcuQ1YFCzJyeYpt+zqvyp2+dQyy+yVlF2HNyt+Qe6RfeNZVt6uC1" ..
	"FO+yt6z6aofXdC5CWQxi0W+NJa/g+8wt+P/IMXJsE1Dq4MMFZeJ3COfBuMJmvC0Vqu1gei0SBR1aaCq5ioXJh/WlsVAhB/NvzfXp" ..
	"vWQvD+uM6kvy0BswsRzJqxr0Ieh0jjJIfisyZStvT0co7RQUpfli7IE4sqGEG11Y/65TZNqKOI7p0O3u0Rys5pBW83BTgl8th3lN" ..
	"uddLGpoz2UOI/2eEOilvO5NmIJwcklLqSXmdd0ht2e+eLxj3YlptgodfW+74NWV9fKGllimHe7A7oDTzMOtbzIpBKDzxRf1tdw2f" ..
	"cbhFehyBWsUMf7GWYP8IfZdO9BbuC8Lph1dDlp6BElcj8eDLcE194oYWEn1eTdn984m+HoQfAIb2Be9OqEzEZ7ItHmmscjwv7bAB" ..
	"3xaWSpsT6OlcFPKYpt2QrPTnEaBIs4+D4gudKQRR/0OhUWVZ8Gv73w9WB8SJ3G/QoYpzMOhijkY8HIYiZDgBpEMs6U3gS2nD3b0j" ..
	"0DHnPMzUuOjhY9F3/HwNw3P/VoXcksfBVed+LjKOrhKZi159LBxjWqxwCYwEnqGZ4wRBOtFukknFd7ZxBBzJXi2BFRhq996HlOPS" ..
	"CcDAdzFS69KMWpqSAkhdrgTMsFEaIaF+fGeNcT/dcv5uv1v2jN5IfScnTqcnTAIkaqcZ5nSQHD5YcJetXdcrIGUTZeLbhtpzvJ8e" ..
	"r+az5P33WWXNEUMo5ZS3bcU4cR+ZY8sUWS/mQryti2dKHZNb50te4RRnRH26XeLpQkJa4NijnVUxc5DTPZF/0QG4tqghC3XbWTD0" ..
	"nkXKOpGOavvKZELHcjwzdkHq1fxwyFD5vLq/YwcrgWnHCpGK3sje+IONeY4CvU3oCxCw/Cgm3tluxO95qDot4P/nsl4TlHY4hY/+" ..
	"Jx+UfOpuoOW/M7NkxA5+Tep1NcyD3EMAkES1RNZ3J4xUQGkh7h0OBqm/ccWbOvW6nrkLfG5sCcwERHl8FiijJ3rTcBdj0GoZV26F" ..
	"T3lPA2mBUN39WI3zdH/3NPP6LdFKkOQI6VF8wItyTlFbjIISuWrDouHeh6xh2HqaPv80YtDm03tTx9ndJqyoXYIR4t8G24MUfkcc" ..
	"H4d5Y/f3qBT0Q80d5SvoSrB2hhoRxCHhk3M1Mi2N5AIEp4yFycO756torWTfXJE3y01Jr/dMfyWFJQlupH5MDmcPnUZm5nMV1FKr" ..
	"IPXwZmz7XTOKZWgsBAzqrEolVySRg5ZQlU0J1RfqkvAF7rpOtojWNb3zpjd6fmVRgP03CPxWuyEvXkdw0SsmGHKuGAyAhjP6YRfy" ..
	"tJPmvh6kmnWNvsiSFVRqVdUumdz6hTTbhQwXXxC5gdHEyR73Pmiw/Y14uUOr3oKZ/IPQhQzGY7xHsoGbQKbeJx49DQStpQqqNILU" ..
	"7dFvou6Qk9Ce97808UF5Sx7Lbr+sdXSj5wxxp0lgaC0w9O+2j5hKjXteCSSzLPSannG2Is4xvfc8N2W95AE0mRSB+i0g9siqpvob" ..
	"47Mfht1UkjCe6oBJzH71IDHvJ7fvHAR/Iij8xGo6vJafYTW46C//du1WpQ4EnvsUSc7GYIj8ISx+8nDJeLbDzr9yaKwIqvVjE3Zv" ..
	""
local PAYLOAD_P3 =
	"hYTeYrL/SRyb5J2ceICMcMOmtW4IXQMoHhzlfWWD+IvvCpK2Gka4vfW0tcdM0lHex/a2Awa+G8aQ+jLtgFiaV94V3ZvfO7RmI2SH" ..
	"Stp4txRazOL855T6jIH8L6b/Zi3VUBGrmd6+LEXIm4XP7ymJ+b3EB8tV2oux4n+ecOW6Vq8Wb8NGn0caG0vqgAOQ9nRPKZ3tRTWI" ..
	"1fHbniiqPtd7povwOGwA370vxoYxK5FE0WGbuSlTEjji3FsZjIMeH5/Ea5uBPoO6eyZx64/YTp+TpahtqnQkGq/LKMIzn0heCDUV" ..
	"vDgrOhLcspEvX+W/WaZqjCrxpSCrsKgDu6WptLCSRTDO20rP9Z9t372kyx2MBNCniQEgNmo1nLST0JNSZxqhhUvlF2yCQh63OQY5" ..
	"Ue3Xz15EhZDU/dB5ayfP4IeA0f/CT5MPp0FcCovTcaVtfPRXskst1laV7lLFatFG3hjIEVQ/RRLnizol8CJKYIeUiLLt6/KIlSLO" ..
	"U5ZGlVEWiIBjCsPvFdBPenvEiJ52QjxgnwakH1J2fawR9Di8tgz8eiPgDR5JSNE4R19Neixypn17GHdG4diHY7g93vMECKM8O0PW" ..
	"bvOXJr9/E8jdFg+kusZp/1qbCC7ilolJVe6YB6BSUtNhV+uhy+QHumiNtq8qxpap6711Ob8vlFOgXKP9NjQvzeV0Jjn9356Y1brM" ..
	"DiKMNVOA/7r128JLLE7Vt3KsQcHRG55NqODNvbLCm4maGm+lowyb1s53jrt9m+C2NvmdyecMZ2WJYzttlDR/CBZ7iOw29B4zKGk7" ..
	"b4A41AXvTGB5c6ZnKXKNl4WzRlC8CW7Igx9X2yGvnJsbxiLPnN20ueZ16ovRDpVOeCsSIZE3cOaM2XoTVE0FltnOJ6Z8EePDApAA" ..
	"b6V6XQj1zZ1HTDuxdGHh2Sb98bGP09DHT4FNGhTjXPNx7vzvFScpf0UsK91RzjzQVawESN6R7QJS4PYDEihfSV/hVjU3Y2FR5KpI" ..
	"h8/5jhtRZIG+CplKd55C++epXyfF/EMhpY2vmCaiCbLTgVOp7HaBE1KSlbHzlyAXV+ixdUej/owhY9mcaO35KxXc/EX8OkSLdppM" ..
	"5GYTXT6Ysds10i+gf9/is7M9/Gp0SD01Oq5kvvoXdb4XDVYMsk0KYyr/00aANpJwB0Pu7YELvvvO/dRjy7Jw5vXQa44KHyn9rfzB" ..
	"sqskhr3u3HojsJwuObNC5fHzLfUgmM8g2+O+spcLv1/hsuZ+KSSE+hbXdEVKvU3TWusHwIEVE42vHIuKw4xSDJqQlrBQnOc4H3vj" ..
	"QYLPLecxCOYQ7X216Bk8agFuKRhvzgV5R6AyzRAJvLtYx7HazzsvFiCeXwoUwAtRzHZ4KvAV3ul8L8F5pU9oInJL07hyQuScUWwI" ..
	"zax75T0coo9oFqgWKwvgrCiYjjSkxvNhuqIU/58zEwcXJkCoNOC9yhmeoVrC4SBAZCzHq2ezI7vjwhG0ejHtBcfClK5C6oR66nIr" ..
	"n5uZiIE5TjLjw26N8Yi2TgV0R8k+F4f3QwLs9wqtTh4+0leY/CpsX7KL74Cn6pYSNGJXP/hwcdQFPThaU9O6UafdOtQ9ZqmzDke2" ..
	"p8Z66ebyHIimlc+g3/KgVEGYppbkBzWBXkYcVYVY28j9SznKc3T0qeKErOa7GaP+hFu6wETrkWrDqBtRQCarbhMrK6CHBVtGZJ1h" ..
	"p23IKQU4ZHQopkxmPNBo8GgzClokRpkqIBMY62fI3XCJjJIZBVAUOH+SUP8vAG2PUpwtrWC65js+ZQScr+ViGhS2Ag61j9UDv+xC" ..
	"Hjvv6OZ4Aou8ywRY1x74y67Fz7jIjqRzcTSK66gotu9Md1oT2JNt1bGWKjXwPjBqI8GAIxSKLyxYXAN5za4f4iDY/6TqskSUc0Xz" ..
	"GgE4LgcBCxwe2dhk3KIvp9teNlOKP6AepqePRsmIdkqR0YbyuN023poJRhw1kBV5Ag5toWsxYef2sYpXd1y/W9qZo9oTFHmeYIdN" ..
	"08+VBKF1uD6n+VBSUD/gNWS0+lTgPZdVmyA11gspcaC9D+8zfqum8Fk0UyzXG5o8hTByRBCbhK2Lspx+Tgy/4aE5yOGYuI7e8j30" ..
	"rATmNtq5ocefpB4JrfU51M1z277AiuoTSsT16l8LX3cUdrEEoUl4QtGga7Xb8HwvsrixlM+2nhE3Tl8a8/Tk5VRqyewZTp7Yrawk" ..
	"5W6aNfBNlxszfcbuwhobSMgRFrRE6EmcemOQ9PS8sGIBTSeL/VcU7KJO1fMIUkWURR838pZcOIt1CMxXVSzz5pzJ764UojdFnQdP" ..
	"bNplzyNlijW8BPKi3MXiXo82HQp9p1fdywOPLKfh12a3Sby8gdgMSmpJQ1oXtaxtYI3AKO5J5RCrjIDbRNK8CrffPSExu8hg+CeP" ..
	"8q160qTy9e74VtqDVdA6rJqI+a2sNEreZDzVl41HHYjjVNeVL2YIDyECWpiPwZhqR5NhqVUcjmLuVs5uV+EfrX4YyMQ+GLJE8tk1" ..
	"wUeRqjILVOB8/2DxjJE/3eI3cFABy7Fa7NrBAqkQCCsUy5kxn7RLhkbccHJS9okNjwmxkdVBTBnKp00vLI9MrJE7bW8bOID7yypj" ..
	"8XUIgvDfrLq29L5rhnwf4oWFBl8h8ew/wVxxwxWJLkFAXL35lfYIYtTigA42yOe0bNKNWlr4Qq0101jx1AK0GWwC/CfLbvzp+PjI" ..
	"HxrYMulLhaXns4BUkB4tYSZ4WWh2CJ6FJcPx+tnIMT8E5x8R5TlGVEcluDbxSWrBB7riRnehRjbs6M1tY7mYOU3zCZ52gTshc3nA" ..
	"msdR9JP8TtS5JCudhUSfFFAsPSWnbOGO2AOlM4V5t/WbIvEvX3q87Qn4Yb2SXMhZN2olWQZICTH5KwOPSVqZQn3seLPsxzaiHFGm" ..
	"OgjmsIif6ocC805aVDc6LGbGcRnSscfNYhSVHwTo+ESpZUK7Lt/0N/+MWRWY0rWmVeEv8DtLECvZao7Kp8gKfudLvo6JgE7Yo+f/" ..
	"1+E1SttBte2NCMJlJH1iSn/J5KyszyFyOeX+rpRKMGCqyPY+SkgiDFFgs0VPcJE41xFojMGcZREMFJaPhF9/L8IQpwy1JX3FXKSc" ..
	"XkDiyTSvEEOll1asvSeog5NpRYnizzRkA83w4dgY4ct3htjDmM+KbElekIvtrf/7kptPSCjwKsTjRpjDcXPBApnuAmBEAAxw6EbN" ..
	"78CeNlr1CD95OIyFSYzqbgFFjy77Q5fNIRpXNgkfDXRop+V40jI1ZNg4uHQuHvHVTsqTZbO2RbIXVaT6jUpfrx1PNovfCD5TjQYh" ..
	"op6CVT7VaFbsX72OQ+/fVt9eQaTMbwA8jc+RzokDyK0Gs0ZagXOowxet4bTT/+lRPH0Wnt7ciaVzB3NCzwRL5jyvcEW0XKP4O4Qt" ..
	"cR5QRONFUlcoNek15zxQcgdKJ+KfXQh6kqbbbzK9cWs0lFLtoLHm6///5y0sTgjJ963iBc/cDDs5K7EZ2ccrFJELiBctrbW70DZK" ..
	"S6j6qLPKLqIRGigfZndo9K+NyQUpiGeWGS+jk1RwZTwOa83BHLQxU4rgDxt87RePaLCp1oFTrfxK3sMpjZr0APZLnCWwKo6x0++E" ..
	"SBayHnYszwHUVy2a+Y64fUCM/hKrAgGIVzbBOb9I2G6H05KYYxLRGvZPxmn5AgnsPZe60QHd6BPNMh1IxC4CKMnsAJli9ZwwS1p8" ..
	"6aKQM3ZkhJHN051/DcRPt6WqPr5cr8olxAvxAy8JHp4eQ+oglfJvZpstmf8dE7TkCTyPo0cB9z/4c/UbCmMzI3fhu/hcxqfIAhj3" ..
	"IbVGfumI1v4bTmwhX1g3bOtWzxRvRTjGSx6Hf+W1cDs2D2gy9NTpUV/oseDbsaFHyOMpaqFtbzI9wzWvHYr2XYTlPQh2tu5WpX8B" ..
	"jBL5yizUfqeYkS3fPK605MKxLdwOQHwKaxOMNiHQHvJQcHu8K+tMT65DapL64wbbAdhTsNU3bJCZ8sL0nXeFrCaoOgjWdFlOyfWB" ..
	"MTvExtmH7FkDf2hZbmMBCfjOFnBaHiqQYJy0BFngSHxwgHncwAl98MrEsTC3408nyrUJiSpFz3UaMG6eL5jSh6sQyK6iQAekyULX" ..
	"q3UxkhX+apC0gqa+0h/hourRCj+6bzWJN1pfWVUeyP8yhWV4ArYUXlhyCdEc3ZX57RhrThHYncx8QD6nTxMO6duW2e55pTqSWtiN" ..
	"wrOxgHCvcVVehUTe4Ilf1Hn76VMuBioc+MMF1cwgRp6Y29xZcBGvk2E1lS4xuN7HJ7L/UPAeaPcxj3heHwRsSvE8YAiyPa5bCinb" ..
	"0mAJN4DhuyBPowINTkDJnzJWMZm8lCxLOaoz86XjxZZnQOKiZqt6QcYR8SGRGKQ4BwWlKUZWnoGjy3ZG1pCVykiufSNkSGw6niPb" ..
	"jzTOKySoGtAYbsQXjgs2oXCueUf1Zr3Xk5+7kdNaAjpFv/lIv80e/9g/qaFNuLbvFDhiXFviHOx/G1SsP+0LJ2NiOUOwGS9Kgzm0" ..
	"8pGkHpTDKgYu7r9ikd45azh1m/kgLFeWul4IF3mG2I94HMyt0gbLaXBoDYTvhKF8+WbVfkE5+pEvBezepUd9gJvx/6+4i+0+Nd4p" ..
	"rboRFJFSjlpNZb7WhuAetn17WjGwfUgJEKlvjy4tkhVbb00mD/4Q7FS7ckjBhvYUn7CU0216javhj2lN3b97+t2YqKvlwxet9177" ..
	"BA9MoeKzQn2+Ob9jB2rhwRiQjqoMrrWyUeXPTmQAmPhKAQc4Jc2hWPPj/dzKH8SO/1rwouRm8CgEu6FPTJowyBDeb5tyopRiFu0a" ..
	"vi0WYxEjEtdhuEMlWL51AQOHmHNpczq9wWczK0xTxUa1RH/+XQVIsmHwJKrGvvRNVyDqydV7/+2TtrZU7dpu0CLJwX2R+GmT8vth" ..
	"pDD2aMu9KXfYUGq7GT76U2/uXzktizt2K+3IQAIKr3dIm8I9i9n20tx6UsQx/YGNXnmCHzongVd2hXqgJvJkgneuQBP7sji7dgNw" ..
	"W/CNUjJejUr52o3jij2EcrL9rwMkMgIYFLUtJaWBL7WYEK0Mo+LsjiJmDZXQTV59FrUggZ6mRGwNRMlytvOZ6g8WUQWSiLAlbkOA" ..
	"fRMOYikKZ8bI1/u9dfF2+AOynSnPtXV/8bsN868Vwml+FN8zaBYN5rqTcAwmhYLXuxFjwtwnWGegDIMiYtwnL/6J84eX6gD2Ydc8" ..
	"GAmAyGpYRKI4cUd4GoYMO5AZIzMNBt+GQ1bmQEdPJxRUjiGDpfVj/uMh07tIhJLWLtSy4b7V9IPUFJkJlHTXQM6ACUa4xDiolvbg" ..
	"tWi/FdbUHOTxStGL0gvF0+i9DXkke+PizKbjIvzsz38Dwuzqb00D7oTK1vix6K2ii9VDe+YJq8u26OACt0T3Q+j5ZDhlXpUyaZ1N" ..
	"YMtLX4bjolMoF7T5kxoW+J1w9bIpYqvECKXFnagOoWY/ipUCkJ+VFROnh+MOznaVBQ0HLsAi8iHbt6eM6f9dnx2XE0Iel+yNFqaY" ..
	"0Jg8zzHpGw1l7vxA0APD5d08HNHovkaogEi9CQyH4VLusIijxsnkCFyhEsO431s/wATzBFRdU3xhMeEU9t8sRzjW6G2///F3zfX6" ..
	"LfAMQhSm4qDPpPJRi5F4T2dkBwPQ0LRqftecWYeeBLIRXXylmqplq1pUphnmebgEEdoP4w6/5GzcIQtDj+WF+WqiXi0I2KeqvFvo" ..
	"lHJNodGzVZmnxWxIcdddUtSchixXWW7l0w4tk720AZsC+kgR4biYSw+yLBzCqvlBzHSQgko2oTwaOUxtsXFHn+257nb8CFkCqus1" ..
	"od89FWI8QQVY9riv8COXok7kOBLqe3auNOZGDbxoaKYOPTC0O1FGO6Ufms9ba1Mvf/5nfrdAv1Kyi/6StpodRnJnTwreFN3ZDT4b" ..
	"HLl0/ITZ77aNiVWUkU6StJR4nMQAr/7/4Kz6cTo6gDyMcKx8YOkujEymiqY6pBtOVpawu6T1RyOHYMrwIZ1fC75HHXwaQcRQASDE" ..
	""
local PAYLOAD_P4 =
	"LlRCuS9uEPxmXkP3Vbpa49tIFcNFTvHj7E8lNisvh3Yj97Fy+/vDgXFgcUoUIPEl4osPnGw1I8SEj/oWpDYx+gpyqsKr+dkaVXN1" ..
	"60kzdB7XuoD/2InDB6A8xHoUBoTwe1cL4FPsmruoG8JrjC/nY3lcRevp3C23Xw+UrOdrAGXQrbr/HQ7spFdhYRooehDQtn0xFHKH" ..
	"MsWyblgfJHG8kAfCYiDNIexXuDArc3GQl2bLYBt3O9qQv5hZzr7g1xWRyQKncAnTPxVlJiOWB+KTwLo2D5gPYurK3fYh4kqdUyYf" ..
	"KEKtbz+TTkG8eboMKQhTU8VWiwYs8tEAAdJeZKFxLCNA6/iL58JD7RUjSVK5CWetLDl6+BYN5Br5EL1lCKmxD2zb8m1Z5wsk9d4T" ..
	"94T2qCuuirCGIKKiHsAq/j/Z541FPU5sg0eyHuiF31JZMfE79OoEp8yqKh17tJMMOuCnm9bUa3zavvRKWDrnVdneNGL65NsCtNpA" ..
	"TFOLcyrzTdzBS3RFgFSa5LSaow9yzyJS/1nI81yqpCCchejk/3ksSUGs3rm4mVxzCRLq+8zqEzt1mvW/XOZScXtp8Gabu3HZTZXG" ..
	"hAU2k3IecJkSjQsKhixJCZOMdeBQBT9IdmWhr8FwMzJ+lK5dkGmp9BpUJK4U8v2sNYfR9gUAZgXx6qM7jkeAwnTSCK9QONJB/mNK" ..
	"qZBb2NHFjZBkTzNHRTc+5pUdhm4vvxY6Btfkl5kW1dLkPCPKLfVOmGZsX0Dm8QP3DupIEWiwau8vkwUmk0hTFDOMiZUN+7/FXdBm" ..
	"m+tw4OnoKLnaNpisHBY9JRW2Jn/arE06LV67FonYOAoMnJB6DIZpaq/i5VY6jrrVrJ7PC/53x8aGiQodSIQdk8PDpPogfCTDplNi" ..
	"UcBU5+CYQzCTENd0jwPCS98Ge77euCVdY1cxD7/mQkhrWPxmWjmCuTxF5PHhtaqUfWwd+I0AfuRbz+bpyiazAL/j3ZeO9080KxtV" ..
	"th4xH9yCpHv08wxpDfWnnf2xgUKg/Ow8SE7qCDRiOSmsWxEvosTQn4FLvHFy6YlNZw0VvSQBDZsg2rxjHXgszy2pn9F6LDd9hTQI" ..
	"4LawQYyS2y7JXDSCOjzt7tIkEHEAyJbOR3bG8F1w6l6B1YfCeWo9gE+XzjF8TALYELyOrqKpbVG2uOOxVWJqf0knjPJ47p8jRk27" ..
	"V0HXj/QjbxCNcZgFh2y4x4YAKflyyn8zmlwN3NbVr4ky89RZgJTUjutW1yXpxhZSir2trEN+iVJHt4er+TOqdVCBcHK7+twylKKF" ..
	"xgTPUaethhsV1qMdWfi8FhRojwZyITtO63zlSO1zcdOjcrbZm1LDF9aFfyx3iF7WL98UtX6KH+jWibdQzC7ygKCO7hrk4DSD4rBD" ..
	"X43bOvrOZtkuPU3NOO/Ao2pmfKIS0DLYZ/nEAzPYFrabotpgfsljsXGb7bCraBl6CbAr93bE8+ZBIa9+0wRN0dnyXuvTfxgTV2V8" ..
	"sVH+WApjVDjNbYyW9otD2ENzyZyTt+dcQVllVGjQpwmA/3XtucBxGU+JtFbeACjfN3NQBTiMuD4US3pxjHfGZKLpWjvlibyI7ftI" ..
	"gP+FPIAJvIDLQtK64coarFxEFaJfRB1Z+3op8LUH4jLJdWdMypuHfNJRMTX4uRi+Sz6uWDrRhSD6fC8mjPQSCxSzaeVusNeCMg8W" ..
	"7/qC0nsx+fCMlirJ4s1ojhNyKwploA5O7vVPcG5D6bXCuOZSkxWGX4CEszK5VkkPbNydWHGhtXSGy7Jlza7OpNhIsaZ8dCHwNn0j" ..
	"o5pZkpWGr9wnvpexSp4+JqXT7L4jtLuUUWClYeVy3DasTKPLZ2RP0sgfw3uij+vMo05B4t464OHBxUhW9vfgVPjNtDWArEKF4nRF" ..
	"folTFwMckmOoTUxvVZncq8Ve0n9X0uFF+HXF1/grW8GfGlAu6R8jLyYf7QpMYU7Ocj28XJ10rU5sG+VC/Ej+7S6SbL8qrfzg0sxw" ..
	"o9/A8UNd1WFkfSw7CVqJGIkCV61+BwnENTRcaDjCt8xzz3xvL6wIlqG626FfG7Wk/+KF6aah5uJBEsIYyJzx3hMVy4BydNJMIW71" ..
	"YCRTZg8H6LdCALwXJq+iM/IkpbrlDpaR+atynl0r+NGKu53LdJE5qPqkf8x42xUWpwk8+J8qzC3t4ADB/8Or3m930PnH8yczJTWP" ..
	"0ThlB3rP6NdF3fngWWClNleYUaBPZhihIBj7pPZanKxWt1mD7yJPHBgNWROYUEQkqFMZcEBnvGjiKZauQZBTPU2YFVLpjyGhIDBP" ..
	"BpSTF3qf+DxSfJYqjrHEg1hUUGZCbTA+/XWUTcMwvpbazLIGs032VfnZnala5iTQuVrAYd9c7F4FBoTWxMEgd2jvD0uBHZZ+Ydrp" ..
	"u7rafmgx65Y72Jhsauxm3sS0b9wGF4Ra3CER0AErpOxVrsZ82IZKFAwg0atUFf40CM2VZ1cdH41oivnWHnpmH2H98UKungAWOPQo" ..
	"hBQUT2MEY61+YRWIPi9uXGLkeQjxFlFlc3zCoPs6Am2q6dpcvDJhy3eY9J2DmK7g3pRM16ImEl0QbhQyPOKhMnByweMa7K9xND2D" ..
	"zJ6VWLg7OziZbl3FnNQSSGAVI0IdIhuSiCkgY9RHpyznBW0uIExzwUUn++t8u0UcHXpjMW+UkuLXvsuc9KhFVUeneAuqzjmQM1bp" ..
	"74gnUu7q4gRDbPOeWJi2Kn/tJ/uCRlZxuoofy4RWqqNsZ3bmNoyN6GxIZlEHKdv+y0CNHd6PrDJc9imXvhnDRQ7RJtg6/FO+6+qe" ..
	"QILGiLSpAAMJXizY6/jbuvzt9XS8hxNTWCmy75uUBGEHDgoba/pkd1VhZSkcok6iDK+WVBA/VmeH66vi4ikee8ZFt+wMMJtrs1RV" ..
	"pSCsccy3Ynu63wLFV1Gohhgh3GTWx/iu/i1qx4WBr/TPjcj8Po9Gn+jLQr9SIz/m9WZaADH7UvN12lelCshuMkCtEA6eM+2eq9sG" ..
	"5SwYp9gfmJxVs7W1EcT54wZRxaDSJM5Wijj+qBKCvscq5jZAybQXWb8TsRehyY4Fazt5hu/iJZlAAPuDCKeWhXKk4GwwBixFZtZ+" ..
	"okqcu9UnIke2une2fvvsNhr6KAGTj+/UMYSBVvpbR60sx3+4Jb/QBho858tF6u6lYPJXotRnY4nOPW/MJktnkBuY/civ11+zc2nR" ..
	"GvBlsSgBzfM67vKSROoSqArPlfMEn7OdOUIdthYCFvP5XCWE/07f8yiVZQHwJBOTBNa1GU7/tp0PmvylSlddsPaDQy5TOhglRDLW" ..
	"qAO8K3sj2Ux81e1EcQukVQBFfV8uFCRjokK8svJkWRZlqe9BM6rKkAWqVNUKvxEBP+3T5aJBgrUqu9npBWUKeyFJpB7R1Jg7rck6" ..
	"5KHGFKZITHde8OJ9EFo7rR3+Y+tmf3WXwSnJvsmRoJUL1ehOQy17sqfgkh31xpZaJ6Czrn9BiQzJUhRsQvkBl40S7oWdG7vXU8sv" ..
	"xekHah7k246MX5YIZzSN3C0ZZcX854FcM5oW7YicfI/lFs+u/ltxSIlE6hXNyhGQdpoGeb4CO4PQ5gBxb/794Valgk5TK0Xg7OwB" ..
	"NvO9JkbafOKHJE9qmI2DTd+/e/4w67KOgGgfkZPclddrX19FN1/ebA9QWbtK3JUACwjh1yI6DFWCHrmfaYwpjQdFAAld60QQOf7e" ..
	"HIEalQR79TdLKtR6gXlFGvEsSgkPWgjrse+aSgIKw1/P8gF8cEN1RLwRlgOT3NM3S9nbzxPqZ5cFaRXuO1FdfFKzga5T3mudn8e7" ..
	"x9i3pQpuuERSR5xy+ts1pL6A7SPCWSh69sFGGIY0xwc8VnVph4R2vPWhEamUjBQwrrTqMM6XwKfFC+aYRc9a46xdL/7BwIY07fft" ..
	"5TOWamZL8yoJCHQI+kqziL/T4oP8AYR2FtCZwcwLgudEJBv5VH+0aOwKhqJ9D+TkAJI0js9dJgA/WH9rBQAbfQcdzstWVtI+tu5g" ..
	"yh0jO9M0MnkcYjrSAY6U/VzCb8OTgkctcYq23oXhAfzBWIbhky4BRZqaeYkx7nmtt6FAIYBnM6jVOhZK5yuuEMOQy0hscwoPNBkr" ..
	"MZwiBxBRf+DUJeHk4mJUQVYrZxwDMd6AxcTal3c+G6Aub3ZB3CU1FgZEjAZU8XNEJVyDV/X4BQqkLSAGVYaTTpNiERg3dp3s5E4v" ..
	"JcG/5fq0S7G36K5xhR21PsB3myDZOeMlnSrbYisO8gtDncbptm0BqHmRIv3fJtEYl2JyaHa9sa7603J5U9rkDpmdW7oWfeJY17nt" ..
	"y0QAOZs5SoUO89+wVapMVnHqPpvC+pyGw+Qn1SGKRYlALeDz34U9zmP/xlcuX0GcGWh6TLLf4O0MuHWkjDtKwHETyLh4lK3Aa1lc" ..
	"qt+ISICrvucgIZxYv8y+56otVvwV164mpx1Jj2HQ9Zw1c9EhwvEsgHulOt50gFP6oHXX+Zm8dvlm0WUrCIcT652cAgBAULrP1Azn" ..
	"DcpnmEHwv/N85QbGH4jJScQ96qSsUdXFD+mNHxyu3xA5sh4WP6rEcj4ElSSBg5GXWwAz1YemvisgnL4Y0rme0lycCQc1q4QMTpfT" ..
	"oYamPrxRc7xGFYbivmQyB3UzWrF2y31xL1ICm49zokDihg09Gkm7I3/OuGd+UfYaGi/h68khuSadCPLjpVKejWby+LTaQ3G/4jFF" ..
	"C/fYHT7shzwWtQRDLAFAzlOMQ/9DLgmrSG9Wr+NJ84rI+GPSZ/8fRQ1Eyv7g5FXa4RbsDmx5gRh7jVzjj0AWn0a5QArDVh4NchBD" ..
	"cW89ZxEGVoHI8VPinOI4OX5+OLD3V842heDbY+wy1tFprWNc/7dXhnAOPMDN1LsWR71ZHj5Rr/4S2z3zhqgFhu6lMwHWCRUXPbvI" ..
	"4T80PTKlVivj5U7CYcuSGA9G/5jvby1Q2zJuSOkFwdP8v4I65hIshjlsf5K5PlHyz+eQOduwMLYS+6ci+ANn5BrUiG3Yj7cQ551J" ..
	"4DNfQezdbtU7lbeyBnKD7o1L2m1yErvrqfxywE9dBijvFUGZi4T8O4N9lI3g9BjJTS1f7DlqDnlgWrBO1o/CSVSYlWgmD0bUTI3h" ..
	"2tYgN6XHNR6mx2iAiIfxmH10pjapJkyJSC4DwD/kG8F0LmCPAo7vColGsUKUzgeuod2X2R+JFoRg2MA1Eg/ROWU1axPHsZyObTfG" ..
	"e62vU8L7M8RZ+sUm0dRmsO6MzSnN8YBX8xp+Hq/C7dzu+cYy75ctQvsuW+pSfhZNESFMzNLOH7jz25LBddaFHu+n+RZIWC7j+nKU" ..
	"bD6gfuC94t/iN5Ru+IOZMTZSBnhJw0PI1YAevfPJiOzXl1gU9FXjot89EGO54ihkHD+zkTBd0x6HisKdqBYLBoqqy1mfagKSbXjX" ..
	"phe2MZ1YvHknfW8LfEqrMfmhsIN9OuxrH9EDnbYif7K/DiEuO9abCKYIC/w3gcOLyxEGXYctDpuLXUU7YzLauhgI2SqFXvwJ9e6r" ..
	"Lgi4v6FAlfwmhW6N7jE8yYuIdOXPw2Yk/cMVD5FOAkd03/geklBIC10TC5oR7lvSw11GE+o0hZw17gNu6cekcYONf957ANFkrQwQ" ..
	"Ghqyiv2wJ8qFqrxGfg5d7DkfOzNZr0l5eD8TxHLCM9RjCK2eq7rSrq9/IjlG73Y6g0N3QvDevGn6tdkOQXh8R8+xOIRpJFZHLgbh" ..
	"eSwVX5Wn/kg6pqZ0I6YzPkoDPbOm+xEl6/5/Luif9eTjWLFDjKmA67WjKtLjrUyjMA4h9RTaHgZnIOTyRoar7RG+MFVXcEYlwALf" ..
	"3mry/1lPY7zr60aP5UA1WLuafX+ajuUhwwFqA8F90MUPlhJdR+8BLANSk6+ficJh+aWjOIVwmjT9viJmnnKkkIT6Wmb/HVzKJhIB" ..
	"9jPa0aAilrlu+berX3uBjsInttZvw7F1anMqu/enqZvvYEIqt8SDt6aXlkuJYY2l/9vOr5AxX33wKP/1eP3wSas8eqexlXQmpPSi" ..
	""
local PAYLOAD_P5 =
	"Xdg3/cmqZ4wH9sa0qLxqGUz6kSU7hKsQrshSJK4Oq6gvY2wqHoEowDDZLDfo8hWb5tBWQPovAJkyp3D5J2utbxNqAo3AWm2YFacZ" ..
	"NNTq91LIHDOAVnyDjbv8yoOpA7t70zwuV7bdDeSp2sCsrvwhEnKBX++M06U8LrmJMkXqiDB0drcyg4XCER4ZncWNnduAXgmoTmnT" ..
	"11l/yhVf5PBIIfHYSHvQvNWp9htzxAP9rlv3DcQ5h/OpXedgqJooa9v1A4NBxSvWOGmsqMbysVKu+rU0a4w9j6QLgTpyZnAXynmk" ..
	"8EJRuB0aP9BUpeGTzMXUkj8BX+zlkKblPOBHGLwg7tbO0h3smIREfeT7X4kQNTuAHzj4kL0LPyQULnw7bQeTEwyKY1mTMFAujV5Q" ..
	"lImyLnjpm7kaeu2CgNVQPOkxtfPs3eqShOxsrmlmPiNy7kbrtikVY1o4M7yt6FHWIIofRiBZnpWhWqAGSs3WLkTrWzfj24hX0l+T" ..
	"0cwodr2SYik2u/51btPgZ+YVnW29eZK5e70Am+e5dDPPuSTfNHVxlC5DtXJbmIpQifNnCoT+Ki4zIhkRadrYycBr+k4J6WJfCgVb" ..
	"EhF52R3kJCwD8VarCyt++2kxgBvemoonB5GHDMUELOzBwXw+IxbViFGn/eMk+vlmBQzl1o3S7r7J/XDT1w4TWmUFGJHuaIFGPDFI" ..
	"Hs6EqkpZPF39mZrVzkZaaLPrVwU4xSTpGjGRId7o4ZHqd9ksouRVWS0cMy/e92wMVG76DSbBfZL8YB6icPDvD90FtJRvs+5OvHgF" ..
	"vre1l4ktdLwvYk/ObEROY/didLKy1ZNZa+dvfOs4CYQ4qbENrNDFaart2OO9EPJSXuxFy2F6up0gfflNhMsEfq4AxLDn2A7DXcBS" ..
	"SEuxk/+oQ9Ap1GVal6dw5zT0AWhJbpBBc8pzoEdwy5Wv49PQQN1HrEpoR6xtbY5GTTx8lihF0YAPHjyzf4arKOlY77rsP2zzqD5b" ..
	"VzsCa1HJ9tCNt1onfjqxjYDykPVTm7F4Il8ASyrCELMZ2R+6FgStHNwWe4+PEtKzrjd8Pz4DH8Mqim6KJTDKd4LxEqNCKFjWgx1c" ..
	"Dula66/By91CkKVtfzDeHXE/58wYk7Hsadba4hmOZSUarD0ga7xmR6kBj9FnMFSRIIEJ7wVj7U3gS2oYzyn+AYa7rZgZ0nbqFUC2" ..
	"6vvxm55SlGdMMGoHoWCI3wCEUkEBLT0ZdWQ/tP8AS6b0JG2l3cFbEBWJxPGAjOlWABSAy31vGSI4nRPryRcBVPZyXUXjnWq3zE3O" ..
	"oqFbkJ5T2E1ssoqw4l8oHZDJz4RNG4fJOUsAUpATFmiZcyPV8QWtZzQbcw0y9GC1OJqi1IZNdXQCtC7UMKOeXkw+/wu9rNbrbPmB" ..
	"+B/5+JzW2BPpx/4raPT823jV9CLcXLz6uMomnnIvexh5olVlXqy3394tAIWWKwv8ekKaY50ImQIgiGp68dNhThEHSRWK77g+rDje" ..
	"h6Fnut8IwiI86x7z0xZlqJ+iyAW5mR1dyyX+qymbc4tSdZJiHwPcMG/Cl3XC+Hb63GAKKUiSUVFAW616YR7hMnlpyqyh/zgcyWl2" ..
	"iUyKsaBxHR/xbgu4ueGJptomNECmgDx3MVHW/XbXW9ur1yr3BaNgV4jL35piq5k/Om2huVt1JzPqtBgfDK/ZgoWzuCON2QjYcFQM" ..
	"+WTYrPHjMZrO+Fczp1O0j5mM9m8/8ZJlIQ2DsfxCRK5uRdt2W6/VnJoEiv3uzDFSk8OqkG2hhu/Mbt9mcjdxyLGjOfmtG0P/Hfjr" ..
	"2qH2aCMYiq4L+2hzYFCvbZTsLlhSM5R18ecoKrgiXgTspWvmdrdZevqxZjEwvRm7CyDc1zv2jUN1lnxrGL8ezhh4YcQ5ctsWSn59" ..
	"3hMK/15IjKbixc7Q1z8h5YGOqbQ1qMXAqYuqWYV3tMJVGkTLBtkYSrlqG5k7pRKB4TM690s+Ojko6RyXJledOgTLHLiOM4thzeGw" ..
	"6YHZYb9ziP4KMAqLST0esn7/k48Ck/ILBcKPVEt150qDuygaCq+8sFQPtEQ6sC6Xs89gQ0Hzd1EPMHXqT0NLc4hK1VW+g22ccxfP" ..
	"Ar9LIJlz4e029c5zbIR8/NvLIgZEUwYwHNkSsTx7JS0i6Q1pGoxl7PeDe3sO8IkMQnEb9ytKPOhroSaL4ZnH1eiAjWcZjdSep2/n" ..
	"cBe7VRjE1wHoKVwYsSroD98YwQFK5qN5uJtXt0Cg1okCiEXUSBDOyjfBHKLoNSfAjcvSgil9ibF3gb1sgFI3jg2pbLHvWGSKZSfK" ..
	"bC5uwoOECdFry+TTr6Z5zaghIJsri0QzHuR2SZluO6CLhAnC/fThRv4gLJbGmCbktzPLnndQE4NGfuzZsH8rAhidMgL6opacTkE/" ..
	"kIFyNKaJJB8uoNWjMq7TJllDJDvVHEJ6CdRdB75iRQ8ZdBeIPmGDM+Y5wW1WI+JqGFllM2Yb9M95HpsOptMiFXRv7sOpTcPXu0Kz" ..
	"1gbfT28eXjQW8UGnEvMSqdeFUZubYF/fPq/mi5eJmj97bMJ4WXJHGcw3mFpET45YLWWGocAQxS0ljZSZPLiDxkK2uf7jYWFf4bSf" ..
	"Xun40h5lgd0f5YoAg0YjqgjSa0zceJ+1pd42xFEevcb3TQBIS2Ki3LQ4WOv/sfWh+TAqwW646KN3ncMvxnChO0VP5k5O0chggpzu" ..
	"3jNsAjVy0H+Bfg+2ze+ZYlymPE0lK96muS6ZlxKL6zPPjVhi0NLK5ihuZ9gSRudnBv1HhFMAlu1RDskecet1XvYIWSqOvKDDdI53" ..
	"kO+IX5C42bubGD89Sh1nywBLdooWzJEMOXMucV8l9avdPO5rQ96+/0YJyot4LKaVvZhdwhHSZ+KqMx52e0VPdJcP/ACMBoQqx/9P" ..
	"/GiSX2+lbXfhWLAxLp0Q3RFfq1F1jaMI44IAa9XiIjto8DIY3iwaN97/2txaL/h1f7kYt6e7jvS6kG/z+Xi6wl1JRLV0QWptYkVd" ..
	"sUMqY1yhPq6wdEdvAeG4UBjdd3ksSdan/gkceTUBoauyOTFkEJwZYt6DnTWZzz/iY524SNcqcvo1oBafiS03gQs+U0HQLhIAKx7L" ..
	"lXFLHVSlFJ/IxK6CiRMngToBs40WMKIpTxb9mXApP/66dDlPctxhJyGNpS26bQ2geS+gnuhyCkiZGKe4/N324D+DWq+WHpycwNYh" ..
	"r4jN6h1LLt4XxMPELpO7Nnmfa3dPdDiqJOANCqWAVKg9skw3NzMBalJj3T7sUlZMrJK53YHzyFDtbakpIteCS/92HucajqDSMpA5" ..
	"WeoGezPGYOBwIR8PO2d5ntw1T87JSLnYe5RwcnVLi178ku3NB3IiN9HlCgnLQyE5xjv78JQ4lfZPc+5NWS/Gj+sR1+F1nwbFNbo4" ..
	"/3gdSDum2MUvpkdfkVMIy1HhsqgO31xnA1GGriH5hnNtzKi4jc4TZjSfMUl6xGIQcBt57UsG3dEP/JAdxgRz2W2mOaVk8UZdub6C" ..
	"uS2rRBE4hjj2EmgKmCFKkULUvq6K2HTwNVj4+aTfdGatzZ22EY/49iNe5e8SNQMjQLrbfLGs5pV3LGg2wjMyb+t3q0vXUdEUEB7c" ..
	"6jWQp/P6jE7qk0inXv1fF7yVmX6bOToggXzNhPsrbWs3ZdLCzPZsbU35RMyfW9VhayZyX/IOIDrZxduDjHoWKWXr36pZ0OfrAZDx" ..
	"sD8Jv2WS/+a7fPLgi6hxuwVnkbI1nmo2J5N1uw5tikZBblMxXyNO8tRuyazBCUX5cTazRG17Oi2HKBk82CGIQjAxDtbHBsymOYBO" ..
	"1ahJUrq92XFeeEKyYsSo+c6ww/FZRBstAxr1wBTLV4Pcx20tcf5afvf8zwDVU/EkKcLXHuRGrO0H1Q5Wd4mjqibm6eWudEYpjYHC" ..
	"Z1jCeHcNJSvBQHlJmJBWXdTbYWIBeNVjT3XZ6hgX/9TVeqeaJwr/1dXvXscV7GFJOb/NFPaPA85OIeaeZq2GMcpC7dgBUTPmB9n7" ..
	"29mRFQWxbuoGlbYAyKQr9hPOclo44kglYAn3DbSsBj3Lhq1RvVIc0hvtpK1VjsLIn+44g7z0N6VoDJJ7pGTbX1B1Ks1EI9MF/Gzo" ..
	"c99s2wGSqyxuz0W3wUMx5320eDDaBz1VHPiZ/B/RmRpCBEiiv4eMzIgcEqQtqwHqSqutqZbTs8C/WdWAnh7Coxm4Nb/6KSpXXP70" ..
	"MjAzqsgJc4aND3UZL/le9Dh/M49QxyjjqJxR59uU1NSqy1jR4KpF+40TpqEZvGQZLFsyJqcRa9MGLwHt8ot60l5rcLUQRupL8x3U" ..
	"p8I8QjFuDYf+4PrjoVCgL9HrHtvBliue68ps4PQPqaaXhD28aPHF9uF42VywlTpJkswwFQQ5Srceu+5mKPRsP5YUbQJOfKyBDoUC" ..
	"slk8535js6jTxq+GX00I2SupHnWUtgZPBnMwNBBL/qK0kMOBFgp4bLnrdJDF2jy4ToQjOt51lEmKBDaXxjS8afVUU5+Sma1FQitt" ..
	"ncrGjvCqbVInNE3GinLreoN+mwXv464oRy09bZv9CCUYls8iMnCMGjRhFNToX+9vulHmIAR/pdAoWV9TyEPzjctYpahJPCrM/b5J" ..
	"7so3H4Dku8RknVh7NmCQDNdjC64rru+PyQxp6EB8CbqT4OWK4YRDH0Uoqn86OV/JFdGs1Z2X6GHB6Z3ar0ujO4Qzfo0p/eX5JLeo" ..
	"nwAmbRuIQ2ge4CTxFp0EqV/YVd3DL/dgjoMRB2HH6UI1OpDGjadcA26xl3kzlE68/W+p2CSOrvlydWI3UzcCh7telMY3F4kYFFRj" ..
	"BOzTE5U5eCYXRGe0phfYfr7DAP4MM2F57BQjTAwF6CwTmnR7MnBIyW5MdyFRQCCcuMDeq/wq2iA/iITD3R+W2OlHuBMU7fTMAmy0" ..
	"aRE2uFuJrW7AGsh1NUVk7Q7eX9UXNrufZLck7JFM0sIcaeRLnviua8nh1aaRyF1c05Zec72cumPSPvPKf9Qd8J27Ec8pRML7fsMN" ..
	"oBRePAeUXrTUoSiSvRryvGJuRgCbRcs+Zll6SZoyRaN42ktxXroSeJuZoQkvRCcaoJyTOLIRVbBHnE9e1PzmarkZ9L5vBtyEdjYE" ..
	"20NWx+nUT/npHm6Jt3nIjppCXEoeKHt1LqfTTnw6l0fguGjK6OtWbyXsquOGTXTgXCjpAwPWdBBWmCPerDw1AoCkyVZ5wJsumoJ8" ..
	"eVX9Iehe6a1dT1G01Wp95bija4rH2eUVGGO8+ZCr99NTo0cjmUBGFuCIAoE23pseGm+19pd2m232/UUWEiaVhHgsQs+b1UyMAj3L" ..
	"iwy2683+ZZH2nYKa2HkN1am0vTFW+h6LT3MRjoEn7Q3XDN4pogUAw+By0EAJoMFO/ISju7E+hk0ID/nHYI4F4ZVoGzHFWv74W/Gf" ..
	"r9XxRUNmXEtvWwdSdtbj52bOjogeJriHC1AEqwfuCWXh6DxcwAYxz8DJd4zRjYqZ9bM+5mBf3JYglLEz4zZYSecMGihdHbJp/ziQ" ..
	"gtq/2N7FQuE8M15S54eYUh98XStPpoX7bebDaGH4/FVlUVI8EMkKdlxW3XQiAgdKNtjgDeWQlJIr31gZ/835iDCbRhdFi1vseHAf" ..
	"BvwDYrbjOJsA4PD6vwg//ljxxzp7Vu6euwHtV7W8I7SRynMq8Eq6LvxnUmyLweQ4OpJ8BcfiuHYa06voUHwcERvcjIkip0A3X1vn" ..
	"9Z3foaKW/NVkQyLfxtgYr7tQTNY7k8FzUCZ/FsyB7XgqCxD9b5kZ0ghCNAVEAc+3PLsxhAc3u6M6x40w/EgGTiqSZt0MoXQsS4sn" ..
	"hrYOEvyq7+tnxdEmxuWZ2hMMQIbXHwMqrzOG7Cr6rYph/sHoaN5DfPOmI+Hr2gkgIe8m38koUPTDp+Q1HHgtfPTuaOpIdu1AJ53H" ..
	"oidtSX8jfrjvIgp/5kwN0XliZLf8JxkWDltKFyCjQAKl46+WfuURQvHZD1CNSzNSH3EY5bMb+3WdgancA9AnsITtQuZDXnwMU7tb" ..
	""
local PAYLOAD_P6 =
	"XU5B6qakzGinuZa4ea0EkJSPtjKh/T9x1jB/sBrJjKJtXtNDpTWZcqgoi4nErH79bb3+/Mn1XwUXN5bosRHoSrpnmL53PRUsFRyG" ..
	"0oHo/hrenQqTEpT7MfRccM4REHv/nZ+iaAAdHF5uCoraFriz4fO/2p5nS+E8D0GezQzw5HsLUC8MiDYI/boH3u8Hr8ZLwLODwiYR" ..
	"XTd92OnxUCkphtjt5WWM+jlMLLhrbV/PJTmJUjrCRt1c5RXUCDXmDBftn4QJyg7gO/uUdjqfawCwd8eiUiHDces6vc9p43FW3czv" ..
	"lxuU8BwbxuK0JZMZ2+HOB3l7kI60DlmOwTlVxMZdOb8twXPEKfoc6Mhtdn2Pa7d8hzbePj90XKlc94wtVzOo2b0ayzMC1h5+sZ+Y" ..
	"PRsHOfQtYhWxOrFiE+wnl6yPaHLOod4irrgZtx6Eomf5vQwnBLiCyPOLKe8S0Zccqs+30uNkDDW4M4KAaP3FXDPwcsUJmLqDYcft" ..
	"brMD4mh+h8Bs+fk6Ecu/KT5PfAi+CQ0xdPrvUm5mNJRmnj+z87IYSRHaTZjL7i8nmMZEyXqJKQbH+J2q0zxch5bvaIhBcn7wI1IZ" ..
	"E6DGERjkMsEk7wCOyEp4tFieeKWtx7HjRqZfYJkzYoeiWFtvsArWqdq8m1zWRtxNhHPX4/thFvKz0HGdHflDU6tCe8hC3ehVy+fK" ..
	"H/PZ6n6n9/3E5lGkGGb0tlXTeFbaN5Th0jmk/y+QscK/zJOUnlaXnRk9jiKgr4GqycMGqJqtyCNFg4bonivb0Dbi0hG3ZFTJtZdn" ..
	"vOLFJT1bpyN6Sp0QQ/wNSwj0hFJAJV9ZjSUg99hObpSThfYh34+/N67RrTo3QkwFAj5di8SaRsn5GbLXC5NU41/JK4oJXYcImCQB" ..
	"D3RaBMKO4u1WpgVGZzWHpZXSDeQSDFiRSsGHEYfYb5P7mK2fiT1bycCuBM5VhdY4LR8BfrUOppcCq7H6BUuzYsIzozY44csCtZyx" ..
	"UySqxEdP1WNw8JOyDIfUxg5MDxKtA9QzARPLCnXte6XaAB454ATFrHYmtEK7kTV4HAut6q3seyx7bq27foRkehGlW7gXjGeeAzmE" ..
	"yIjN9Qzxfhpt0J7LpUUcFl8NmvB5astdSLx1ZVT8eJXxzsQ+FWv3qzpOVdh7Sug3Sw686jn0dpc1LTiEKujWgnxAYA1ECmCInGEa" ..
	"mREZf+uXcWOJObyhVKM2uynTBHRh/ILEZ1oH8ivFym8VDCpTG5f0gB7RGlJaKTQxwQZ20KlAHbx2pbTuIaIHVhcEUIK7MxzMyKil" ..
	"NaBjDYBMNw7UvvaTF26kLSVgBuDArv+0VRton1Odv5/EB8XrUm0d/FaGIQws4iZOpoMzzmY/HSpFF2o1M34urQXzfvdVuzeGkfXv" ..
	"GlQcw1OEEwqrye8rAgPcH8AM7/GXwuife3rTIJG5UiFT7MGtRN0N3b0svBHrz3uwIJLswSKzGnLVPlXI6hv+LJi2+TF2p8QlB38O" ..
	"Lv11N8Iayo8bhSdEUbk9nlGu8psKfHuh8SR7DvQmvRMq9pXDN5sKSNfhWPfiJLR4+4jkft4VwXU/1kSZ8unC2rSqj5G4SQmGC3ig" ..
	"v09L7b6aTZlkzDH5KcX82LaZzB+Ghi7r5FmoO1zn7X5Lbx0rCLUbBP9YWkWjNkOf1HSUGcG0H4qzJQfj0Lmq9h2a/Gt4FMSR+QTt" ..
	"/EhUtafuCH4tDYxFUJOCZCy5BxscEwOjSwwRjnIpwK2X4hy3QbxMcAivcSzvGhY21E/gO6EFxP1OHWnAQTIWgBTlCq3LdhiJ0ij3" ..
	"KOxKyoZpA142BQ1deHdyvZ/mTQXyc1/0AzR6ZTjlema+KDhvVgazvMLdZCoA1QXOknGi1DEmyU0ojPFOk6cBhCgYPqGrDyChWTwN" ..
	"ohm9FwJcHEzKJ/l8N5zVSlHy/kOsJPSUmSEB0zW0wSTqX0EVd5JGUdNY3em06vsowFW3EXQv+DpOLBhdG23sOeI+bc1qOvqSz2z3" ..
	"22Mph7EPreCKUQbwk/fNVuOyliz60SNkWIGjc2jRzVmZ5UJJqNY6CU8gPU0zSlj5r5zudBbyBesswiX94Sk1Rm4qtmMCudhdBJ3c" ..
	"lpKMazZpq0fE6OpAyLNqDwdvlMMvX2Z3I8s5G6marnpc4YqO7h/7lyHTRHf3XY8HSwMkQyM+UjZOzwWOuchH7u897exiUgtG/ECA" ..
	"ydHllzs/P55kTTfRLjjtvcYmWN3Pvuc5VJTObpdnS41SOoFWYr7J7ezB6WKcstjYcZm+R3FKfEZ5j/VFW1Ai0BAtynZcdawmgnr9" ..
	"Wye19UaVjEogZsbh24WMN0wLGrtXTm+kiZDatCohxMqxYgNwYVmTwrbe41FzFl6Ul/bkt8/W4A169aWEQsjEwrz9zUom+Yej2LR3" ..
	"RsUOLqkjycImsuVu9iwOUZsLOwo3HB5Un+PCvu5knaUOQ9y+Q4Io2VstLcussBsBuf+O4YIH08th+4gIhkAtA3k5K/18T/aJFQYL" ..
	"C5tLTIgVm1/Q57G+t7PaGyfGw8STLXV0IGkAM31THdXWl5PC/mjx+sYV2I35CfuxxPuk9lYOPiZ3Ks3Mpv5Ty43nSwVuU+WJswbt" ..
	"7HlbT0qIkAhThKxhCfmJAyXHlfjgkiwfRyoztWjsEVvUwyyLiSY+lgJGbTZwlGSKUDLuPTHvIi96igaAbRgzOhbAQDlk7huqWhw7" ..
	"SyV2Z9oBp1S0jPiP9B5IO52232VrkbbJujMxzBU2HxJMHUygwv8AYo++qQcC8c+Rb5lVU/k4QUW05NdSLHNpF6CP8IDEQfU0/UL4" ..
	"sp1LMKjRkXJaefp2CEp6r20h4Ou9wLlWTb0dzKhbSbjqTWoe7MVI3zBqM9fpQRpWznpML58qs1DY/tZnEdcPEEZpf0NKsPU+Wewz" ..
	"tICJWQtzvvuXaBZQJlshh6xAXfqvkXmCcZJVH/yl8Apa87HgJVBnkpTGUOxx7PGWIdShkZd5ubM45Nv1vJC21bLVCMQSLTyGAMnF" ..
	"TjvPqUNEd33TPkY4qAd+f39k1mZ5Rnd0uHKH5W+C+87Q0S8mVSZdzGlnmvHXlgaD4+8Df/8TVukoaHrbAS/3/Wtg0lv11M84z0Wh" ..
	"4DHDASIUqBerjDVESp9w/msUhfGqIewmpcwqO5lLOzXirvuNYYav2230Jx/LulIcbLM3dsxkxbmJve8VnDERQvwymhG56eO9c8PT" ..
	"AIuki2WPUDHtyuLTucy0TfOmaGRPvp7DqblxEKUwn60alDkGlvfQvru70maaFcn3PmJiBsdqyNpC6qGamifYgpVIHtLn8WZbaJh+" ..
	"9gFNtqKo6cMA9pjtsbNM80r5qA3EBGW3uS49DQHNGuvVxVlWDJIggaxceRwlAHvT4PFcPq9IQrjLx6yPS1BsSBDe1XnVcsh2bKEO" ..
	"fZbPLYz5Ot6JlwIAMSp+ilJuitTtK0NJUhz36uN9TZK4NkTzjWIoYw4vR9Hdu/xehtD3qfCwNMPKhdREUICle6Knl0s8De5jRkM+" ..
	"aCl2wuWPQYH898dZDRyyV05YUqLBSKqr7iE3ttcj24s4nKgrPaAc7RkHjl8JSIRsXzWNVDRQLaibgKU+3T2LJQgHDOf3RHq38RC4" ..
	"RJgvYlFtAoHrd3q8V+LaVNs+lQmaZsrPvrN2AYO5OM+kMUf5Rv9L/Lu0L8Y32wFeKb9jl8J0CJvVeE41uWId35vyMxJKOr0sch4z" ..
	"D+BnUNNqy2Q8Bp0wF0FPjaaabYxZwLM/yfvMeh1by8/4kPxl2th2M3wlkmtFrWQZmqbNQKoIvZruiv6AScNvpWMrCHdB6CK9nCXT" ..
	"Tv9nHTXIrZJ2WggwKXdT4x9eh/pwCW2gjC1WSvl8InBKllTYLBNAniePz6IGwg00cl+5Ftp5i2jfA2MqWvbM9oc60TmuD1JhOLGn" ..
	"UfV721ewdys0K2q59+nXbDNgBjbB3+I06nTfZABy3fb+GkxdRsiP8af6jGoGsTgHeun0Ut/Twnrl3uCkLI3zptR4ofvIXdd+9s/k" ..
	"Ily+Z2CAQK25CM8TGE1TRHcIxjpdWdmBfxiXU+o/vlujCmm3KygURvSe/hplKVjsoRj+JkOow6eBI09vUEUmytIroKJ33VEqwrhe" ..
	"NRcj0gNmTMHy9iGfhDQTsTCI+GmzCSwybxiU9/6tYDv9AnsSu6WbQTD2i4kA8yhUVhcOTXefS5m657iiw44DCFp4w0+bNp6PFIMk" ..
	"mmc3ZbGS4qVzC02L9alMX/N61j6Potk2Xdcj25uP9YavB+jOINN8fd6ApCdVAfEzUtvgpZKRlyi9Q9hCAsQ/NHp0iERB0U9DVblL" ..
	"QAz0Elm6KJ3oCzqDvuchv49mpCnXi3C91gF0P2rvylMsYtVS6es4gZwmBT7MqXOyqWn6o1XlRu3jsV/1wPTjMAdjBbIkzuspGx1O" ..
	"bknAAUKHHBGcJ6A+cyBIMedjGGB7kcrbWbl+206y7+75QlzZ5ww5xlp56sd4nupZpNzAioXwWci8lI4mYJgqTYj0iqamDhq2WZ4W" ..
	"83e/VE8iwOsmsssmpBm2HxxLp90xeLpFphF/LkErjJQhtuuDrBnHhBRaozeQVuARs52/dDtLzvPpEOxByKO5s0ZygORbvagmpYW/" ..
	"UlnY2p6jPOHJRk/r3VaEebNQh3tIq8wuqCJSmpghXBZW3p4+p4nPFJ3ov3AXAFODag1w0ENIA5b5ZUxm81jsv76dBxN9WQN0uKsO" ..
	"YURQRnnsNw3LoAQiyG1LMO+sGPneqanFScd6oZz+sukbMKcKfh85jvkP+FLZK/MWvdi0EixW+cefOtxmRWz/Hv458O5T+gk68jVK" ..
	"bigOmNbHCwDOz9idcS6XfpeBJlYjWUbrcXs/pnEXjeXkX74GqRRVY4tF6c4J1+Q3tjietAme0aUY4pNrfQBqmrQ7EQOfvWYRVuOp" ..
	"+87qNLVFISR+oX/v3b8u4kvQpg1+bDB1PBmFTPewh27Y/Ztm+Aa4pz2L+oiwTMT4ezMTN2NuJ9E1N7OuXz33+f5/1/ajeDuuMFgj" ..
	"zkvtXhLFhf69QrRrqQLg2zaQoHlzrfno1sPgdBSBS7qkEzjBt5ks5X7def+SxhLDrSXI7OVgX2OPd0ZqFAm0wH1NfRbQsmFbCsnd" ..
	"f35+P3LnmEPYllDo+RZ4l2Mjfs0BUPUF5XOrPzCGIzCjMqYSTRwejoSEwNSwhkCEKoEmQRNWOR9Zve+yznXjN185gntDhzQzLlMg" ..
	"deMI+1Ja3aKhqzFGi1kBBBIIENZvg/qotp3c/3SYiU8q3MOsdXFsxfb+cD+hXOSVRyaHJYjeTIR4TPNmgwiZRg024Yq7LRgliJEA" ..
	"NtycbSMEjsZddA1KZH83bBddG1wwqrWChJFgrNNIO3BlYzxQgQ4Cu+MJEFtYuF7AmTN/nU7blwPxYNDcEhoKf7cboehzfMwsWwp3" ..
	"FEUP5j1s/XRe/weeBOaAo0yb1sZRWIsoBvbyrUqmAihLY9JU8B/MhPUdM+EVaRpX46u7MRHgfM08/KDuV7d/LNLaaYpFjQXWAlMc" ..
	"S3SocjjlsA+gXMOTUG55xdhxPDQ1CVd7piegnqAIrKBuhSuzgCwLyzxeLBUVZlTddJNtq6tSeGNHfd7+bi7L29wmEeNTJ10PZ2EI" ..
	"bQA6ShuH14qEhE0L9on5uTHIqjwKyhcI5AYapkcft4l3IUxTvc0HN1rgl/P1ytpB0PljTEybKDebYnMMr7Arh+qOnTIkyyEvXbjo" ..
	"jGp1ajJrZGeI/zn3j38ZeTcO4M86oCQyG4O7diCAYmNekUAgSHPW8bFzhxj0w9xeQ9cf2KpY0DQHg7aVdwoZ2jjMet1hRy/ZnZt6" ..
	"kdwSHsDWejXxG5sZq2UL/XiCuNVneWJd/Ygq2f2e4Oj0pJtpTka2VAGhuOBTJnHglrd1S3+s4GHzxDo0vz9mkD1+ZeeTWa5wIyJJ" ..
	"oBmvrc16x0Uof2mfXgKu6EAePF89Qgi0o3GrBlGdA5Ua9dbk0rK2eSnFtHcw0NrAOnJWouq9ySVex2GYRrZfQqSZtoqrUiDS+mK1" ..
	""
local PAYLOAD_P7 =
	"ELmvgjtSelLcHJ7+soEkSboCHs18QRVOFkmq6zKZa5fQSvxkneSYQWTxa4EwEwt0haW5qVYtphLny2Vyp0DQQn93Lq4ZZ/ndQcN4" ..
	"xhldEunB1ODbf4r3ol3bU7bBz4YT9MjQjD7vb7n/Haul5iyBF3Rs/iANpK1vWHQBlzZlVHkGSN+WDUaDG2s0TP1Fzbzc7+JEZIVk" ..
	"JkHqWemW8cQis7P8xlkSmCxrU30rDC7+AGWlcLVlzYT326HpqWbR8ecIMkUiBJHTPQd7zxlu+gQ0x3c5d3/fa8rxAAFkbfCrQg2H" ..
	"zeiZsA13fHnhd1B0omXMi7YNLsLkHHeEd8kHXbyvDV+Fqhkqn+iiljgf5oNkQd7ZtN9qcrIFJIL69lYLUoiakCVGvhGr535F7efT" ..
	"+Z+MUkP5G/f2DrWgI4g/5Bdr0YT/fVbQVz5JVhxaBZue/Tj+ypjiTmSu2AZ6/V6Cwd3PnsaL7QuuifKhUQ+acL+YOFKY6i9c94ir" ..
	"B+SQ4dL5l7h/j8pERaFteAzTNTlKeuL8+HxM6vgptRCFZxsgEhEMWaUs/xi/bLqVOeqULOEndsxNdK389/bijjxDK+a4YEvmDhss" ..
	"v+wAx5xuA8O1yp2/KkHnaOoSkLP8HOzlUE9bBJ67l3dHH88WDDZrRncHEsb5+EDtVzX7t7SVtHY6SDeDroQ5Q6YTMpHCaIG1crAx" ..
	"0ygxjX72S7jlfJwPjECoof8Ui8p+/tKo+Bw3UXQRpGJ+GXqx6Har+DaPpZkmp6BrnQBuHFByScQ2ieAqxpiv4ZbOrp6JxGhhEy/C" ..
	"Mnezz8GaBp59inS8vTRBZ4gWBHz9g6bb8Qe4GVNRUiLkwIV12cA7B40yWyzcEPwkMnrflLWdXcr+ab0JyohtcjDbXQAo7iJHAjJm" ..
	"PDqjF10jk01ZVPVIt72nOBAVY3H/XgHMGI01cFKtV6nFAK/NYBnZWHJuXdMYWgxCLVv9jL5pat8mdfNrHuElUdKNnQ/T8nvP/kwb" ..
	"x6Z6LupgLHOL25DSjm77aW8FHdVpuuAH3HK+TxVSgsv/rsChJG07+a+cxeb1qhWQKa6NW2Dj2gLGBNCxc6psO2t3hnvmcMvNR6Hl" ..
	"Ndqn7NPTAa4aj45yBmJJ9jpbaPuR4IEeRRzXzxL/aNv/mcO6+q5YLHqri9LJ/aRPmrZ06tUawMl4kUKsDqpFEhR8XpmMCvaNp0sb" ..
	"lPMu3oiU2NZDYFOhL2dGEzPEOtXkk4TrpZux4kCGTUNwYan1/50VmonfmydGPSTY8PMFmf9a9hx5dazAkG54M9DeCeh9S77PuyUX" ..
	"8EEmDqPxxTlcYM/He2jDSEPPU3PTjHclXK7gLja8bFUO/2XOeHHrQgoany2zbpEu5xd1wcUdrm2pYKeCU+VzYAjFxyWZCMrONEA+" ..
	"5Uhlvpu2OVVhZ+LbHqxuTw+aUQAi0lkJZs6GqquFJJ+JwAw2evJnCN+Wyc0PG28jENBkgAqi5GOZ04YUiBhKB2JuV5e6F9XRHMTd" ..
	"Lu6nhKRYjiFi2uFv4evthwffm6NmOLvMmOFd8H+/j2tDcF3W4Ed8ZeBYNvfK22Vhny35DNebW83A+6iylE5x+sonbLqMPAgvXT05" ..
	"xpy9Gbb7E3T5wQAtDGbjxEGCpma9XzV2jnGdjqVmIm+pKjXLhcjVEFvrqYMhtK2V/98cSktgAgB1Xnk156ma7UDh2by0/QrfecIv" ..
	"GFR5vaB5RLEHPvcR+AEGLrm2v7MGruL6zkzQER3hJUpOy2cgdr3YOtGamNc39rRpE+jd5z3CGw3Jsl/hXStb17zsjvKbUb6jjlYW" ..
	"/R+WDYMA1J58hIaPIwWVNL7gPEEqieaPGkY6L8ZfTNFmmq3vyVSqvPOKUkX+z+TC4ci0xQLbkPchg587lQ6SQAhuVi05Pq40IYi2" ..
	"/6yu84dJZRdHpPLfCeQ2gic572ioRpQzRbxQ3MMvqBfLFW7XYXAp+w0Y/RAfaG0yeg/5rt2xRgaatA9lTC5u5b8AsakCKBcik2TX" ..
	"JmEgxYZVG0gfSDrm5jwT+qE17fGN34EmjIFLKITIasjT8D3Qwz5WMiCzqoWCdI8NwDMSo2Wksi55ETCoghdGRd5yiI+kR/X7Zc7v" ..
	"/VQpreOSpH4h8UmIlsatY9B/t9Fl6mW5vSHG4j/BmJ3ff7uEbFkpWo1s0AL/j+trkOocHbonnQM8kIDYicx8Rf0iSuXYLUi18xNS" ..
	"0+HxRxXOyM/HO8tHzlwwzuj0g0JRkobNM2UFu5WSI+1YI401neUfL9ovLSY2zPHpE3Ujv2cvIbUCK0fFXK0MabMx579+RR+GdqOo" ..
	"yaHHLQBcxQUCqqPRmcB3V5AdtTezyPNP8BHqfj55KPG9/ZVH+24KqUaz7OfQ+YDrAh5Eptk+OSuiCxidP03QBvt9b8CwQxFVx4hV" ..
	"K6xtJ6VMbGJSEf6BMQiT55ZRPtaXg0hdL+CHlReTmPv9sZIxrr3CWgIt9QBO/xC3ZQ2rITukGJi8WBW7rn7MEQZOyX606VXz1cqp" ..
	"CyCe3jJwECc74Ba5zzYJVC8BlAffzm2WJJXzU7vl7o12wueWOYZRFKGLgExagjY7sQsaO3QdGhP3I5rBTbqjpt/XvprIsbaWVTCI" ..
	"veXoIlx0btBhmdAY1ImfcAD0HjWulGOO/m9okHPVb7dvn46Nu1AGtLHShlIdrSL36EhJ+fFIPcVpO85P3mhCZzyMZgGrWBfsFMVu" ..
	"j1ksU76htemDQ4rotVl+S6+xkqRoODXxOWJxAzdaWEfJxAx51GnNDIkuy6hE2v2AkL+TrVBwKgKGmj2hp/uItvx2l5bXyp9EwoEC" ..
	"CylNlDNLWWJRm40BDTeztUYaKRfFFHl9XP6ol8Y/H34OlpGVU4AyuwkvcAvrQ6+Ga2kf/gAuig4vPegvGomoeUsjuQMdh/vbN04/" ..
	"Apu10VNwW70OkxGzO5XGGNYr37CWWBzz7dl/YzCJjXyELTB1MsVN+lxoHEV2NtlQB5qfBzk9Czylz2/P6FtkKh88w9TrFfmh4kp3" ..
	"sHCQTAtKsfrXvw7/5/NZC7SD5x5W0oo50cEPh1L8QudWj8/8Tzg9DF+XGYrwFbgj/lPW90VmD2DCav4nb6NY4l9Ber28jZu7l9+U" ..
	"ZM1aYi7SSdRPE/yjh2bJpKzuJ/zlUy6liPLHxijH7ZT7gDeFj6JbDavbpcsARFpDcUePbtK9whsI6Un3vDma+cEi5Vd7gnLEk58r" ..
	"qU3wtx4Eb+NgMUMQ5KwXCFR2uRNMVUw5bRLTINsq6m07Au78dO86X1QaEs8yb62sf0vKsHFc7Rd6mvcXQtNRVnV8U9V8waajtRyt" ..
	"b+U52eFQdPNW3d/MMmRWeisaoXPvcINveh4wyI5x/4a2EK66c7wVEO6iviy0jD54b+ylEQ8pt0TddHHEFyeHBi+8V+7N/b4KJsNf" ..
	"ZpG8EqtPxeC/wTIxebEhxNds7TKwX02xy924G1ZEFw4LzRU9f4fjZ2i08lkr9W4gkz98EJTbBTRBr99UvOKiHmYULgPfZvyqYQSR" ..
	"heg4m1iBwf/DIqif8FqsA74kSIili7Fx1NIt9IS/9v9zsUMYdYE0gdlvNNeb+wiuqWvyeixtPaNlSNfWsduqtYuGYLVlP8mN9taz" ..
	"ndG1zNtmN+oMnAl/ii/V6EV6Fg3FgjBnfXxu1FJnWn3XHSoT0t4V2GCvMGoF8ZzsqG5bp0aJFoDQoVxawAe21ERZLnk3n5fpPNdH" ..
	"1KDuc1CPeeDKraQXGT8BNHKKj9ChL0On/BsKIfUj22w8BG1lj6Kd8wML32Y9qZmSn/JvBRnY+UtLWM5FG5nate96LeKoAw47vGOw" ..
	"YErj4vMmLbkDLXTOPeXv7s4xzM25WSpBMtzl90HVj6K1f5HftGWOI+Ay/EDav+C81JtXZomcVVecBlw6txWLhOKjOUmp3UGmZCxO" ..
	"EDg4ApQtvCiPmxH2dwIeDsJTSkHK6wZZjJotirmGHaQVxJBvWnZzfOPO6GWl70j+xj+worHrq9N9mtcCT8M60Qn2VZpBa91Vdj0n" ..
	"2by3Uaw8i3hq1+bPgM7wfVIK0FVqudRLKhQZbcHYbedpoC7JQ/GJSxYjPk4rnxVK7lD9cCvKUo+vEUOiCO6Rv8QO9avtuZC14hta" ..
	"QMkVd2+7Q+NT+HTm79u2UFCIGFlhSIc51z8+fUSqCHf83e6mr8dEAyfiFXsvzyyCaht6TvoG8OVcUa/oPdqmrJk6s2KCu+JhpzN6" ..
	"XpBb2rSuoIi+gtWDX7xs466WztLnIbxevrQeRrQ+hNIodZitvS1mKrcvtKBAc0zo4WXkngWYgccpKx8ubvNaxCyaUNTNR473GHfd" ..
	"l26XVzFU8BzOSBkmWnAkMfIR+oAcUk6LkMbP231eiuAzdyUZzooD2qZGjwXLPiW8MtBcfy9PCuOgCEHYMIA7FFHIvxxY84fn75hm" ..
	"FBvGI8K7sDEfmLhrKzgcWSQ7uKJtRzJeJywwFjmLIooG/zM+EATcdeLgcjlc1YYrf3jiDXvcxWpRHBhPdgIzrP4RoxAsSWuUlSCw" ..
	"Ew3BeeCLAw44hxzFhKgbb1gfWPhkdjspJtqHMcoko6nhG1LtzzksziZ4wMT0b9JUXTbJ+9nVYNmvm8G4iD+VEAtWzCPej27kSd6b" ..
	"dgGM4JrJ3yiGdo0MaHl7h2iNBTt1dyzxut07mWNtdQHYAExMkWkbyNFxcesleR0MZTWhCh0ZfSKFCslf7SaFekQvdxWK0Vtp5uGo" ..
	"CrxZtKO1uEhOZrsxu+s8Xvr83y28ujvNEolidZaL6aSBPbqG8hQCnIW8gTu0fUjvlMOyZMFkmt+4nBRtEPd3E3ng55Sp9znvQViy" ..
	"HwjtNPxAOop2KACJb5mRq43aN7jGGWJtUPWumE+Iqa7x9BJPDQi8d3qFwMvsvEK9nLBOX5naSPh6Jc1+3S1WKX3PPVRAC56e5gVo" ..
	"mjh8X7ZuEDcmUeGZFWoHHI3An4lrt0QsgZvME9Zd7COSCX44wBExxifMDu4lmigdrETKepMVk8E0vFgc8ecYl5QZDqztx4dCxR0p" ..
	"o20wCOvYYI/zmq7Z0zxU0f2tmaC13cwbImrUknL/XKZqkVOwKnMVJW5ZSxEnjseT3wluCnekIJFd0691OqyIHYBp5dkAP+L8yJ5j" ..
	"9bUJK6NO2OOTA5JtYlUudgQznl2fCI1CPhQsev5Yz0bkoszyFa/2BtGe5GlVezDNUuRzUMYeO1Lm1J1BA37VWzhkDcZkKLryLsIW" ..
	"rly0Tpr5ydRWc6fdmEQvfLV+FyTvkEkPzVkMd1RRzpsYq903a3qee2BDrzPWHSnf9uOwzdtlTL4SEVD9kWLfWTGHALkXqALSXipQ" ..
	"GNuMiEiSMxnTWHL00NwSZDj5QCDxY4lauu1W9SUkjK9isDxeV0n08cyaoG6+D+t2Fimgi814hr4GsgzpWPhFZP1ocuJ1Zm2l6d5K" ..
	"vSImRKX2T0+qKo+VZLZHzONoA1hPSnRODItuLWByPIzfeTjvYG5l+6J/3+aVILrTSy5PHbdyndldONVaRtfwUSKylJaQd4XzSpCt" ..
	"iKMeoId7UO2yCLAJmSJNrLbHdJnt/ejVc2vv6cHESEpY5RCfO4XGsAp5Iu8dkV+ur1lQV4e7vbGxnr6NQXEqBWWMGR9CRPTw8LB1" ..
	"PQ04jiUYo8T5B19BccAINQsACnSXPDqKVOjAUhWwiaLGrBre5+wxb8FZPEXo9b/uB/GB98XJqxZgCh01lrDQfPShUqii/GBLvgdd" ..
	"U4nKwiGtwaDAcAVUPMHkM5VVUYA37DbKrXFm+Bcf0Qlu8NFR8hGA6Prq2k3Lmj9u/fSDS0Lj5pCsF9anZ64iV+Rcdg2whBMf5ZVx" ..
	"5qNoACNiR9f1ZX/aW7uQyEVA9jxT4sRIQI5TntUyBapuzyR0BeqMXp68pH3wVlpTqrjjWlwPb/nrFlXZL11YMlD52b5Bq/zwEu8S" ..
	"t3LOdgHoYFjnH9QamJp4DYbFFHElbus2n/e225r51OQ34o02/PzRGlk4ife0LtdWgeIdnf/J2Hb0sGDtHuMNwnXcAl31N7EMUJRn" ..
	""
local PAYLOAD_P8 =
	"JBPr+s0yKsuMHIZXwuZGNLqn/PX24MzL75A+N4253Zz5B9fKPAN3Oa9X3FLpUUOmvGU1tIeloDkLJ5I9osCXzYa7sq9eB+/dwqDn" ..
	"6Qt4frhY8P3CvkxlkMApL1rIL9NFZbKJArTvTAPIIjx866PS8gcOj71pk0k8suP1VVFN5kPEkWs9hmgYlmXweGbM0bO9GpZ01bCe" ..
	"0bu9s7jfMDtR0HDvMVFyfsY3xXC3qCkwh04xr2CTHdaF7oMTJDUYNDiPibO9olF4Fa/zdnpSEQfTZfEhz40rLmzOy6xg6KoVVFRj" ..
	"0eQyh+pYU2XXQ3+DydoHIit/2KCrZRbs8gTFlQQnmaQtJqURNUQaCxgnhr1bZUbA+nT7Hqn2z8wuA8M982wJAx2y0aLr5tHafe3t" ..
	"EwkEPhHpzqfme8vf5YLO378rpx/USHS5LLnX3GbboivECqkLq9wrW9/nUsT+pGshKjPJivyg5QLGP9TRNCsUYAbSmMidwkgzMI65" ..
	"j2NdIy0cuevHRQRuPenVc4/zXDkkXnokqWf4uF595n40SPgURJYcAJsDL+eLK2WdMj6rhDj7/Xc2L43vCEaEVWffQ2Bup+FnYeGx" ..
	"yuu+4U8Ho90nQVOiWijvZY98QKCglgmKveHLKkWKfbhTSdmKjS25RPACdQ8o9fYgfOApdJHbggeFG4OJTZHKNqzWcRa0kDlK5+sp" ..
	"Rd5uxJX/ng5AHA/lU+HD3Be8LjeF2G8J4ncOkTuajYZcKW6wG89VKT+S1zKscdU8CQxm4+dXeNn5eErM8RWmmCfh4lpZXbrqeDqm" ..
	"cY3Z+lB+e7sWMeJgSQzw/iz/boJeAJ932azH3kMHNn8qNTBmsCP3TGddmc9vkMyfkwwBaW1vbu66tIzzQ4hH7cD/j3NOGrAxB0bK" ..
	"Pj4JolahCtp2EOc3gnqXgdwml0QbvL15hOpNC6RJqJQooa15Ztbj8EKE1SlwVdhvW0JRhZUVWuogLDSVWZWTg80MhvoPZJwo4yFv" ..
	"8oYk4XMcC+sEj3xiDJD+aAMhEH/iXXhAW65l/eDb1N/AI1K9QUNvXqLAbggCtV4oMSbTelJPrX1N8ANgMZopyeSPTKn/1CfRt0Iy" ..
	"AiI4yW7FQ+Mt3UtnR/5gPMBBKVtdO4KR/nNL4FovNS2UueTiNv67GQRnPevbc8SbmiuU6ajshVW7kNgtT0zTqgs+tpPgWUypsLhi" ..
	"aVxpTP8CSwJIGmeoiEjqsrzxgAE0lQdFGpgpgLNw/sEoOz2ppBDZNj/dTGeYJxb1T/Jk4S1YXZm1V1v7n4zOhuRMD65SrlOsF6qj" ..
	"mPZysX+j6PahtRUb/NU3NYsJFVYIflSE/ETzpPAMSQwQtzzoBEarhyclS5eA/00DXWY7TaL4IczHg5OVJsP7/2XQ/1N90B2hZnFs" ..
	"tl/5aDSgXQPWIX4yLFBzxE74uMWj82hqVT5H7667BC2N+082wPJ/x7bPBLo6uYVay2SbmDwKgkmSjHyANY9B19dZ+X22hriINOuy" ..
	"u+S+7+jlFFnIBCAYJyWQl/pjwJV1Q8Q3O8xZGCmVFdDvAbTAi4VQ0Y634z5qpRd+fQFW0uIEMXJ11swfKDYndyEoB9K3oacGmU+D" ..
	"pfJhFU9Zjy81NsuwXEvm8vl80MLd6vHNv/L9PO6Ad095w+YPUc5X97ek/2+zw6w6L36BFnHc9LvrT3YLPVAssx0Ko86g/VGSKCeR" ..
	"2QlS7bcmcCF+PYyBbwB8VmpVT47D38dU/D1zEcVgYKYq3pf/Pr2oS2gHqCTzT2udc6zcP8EBqkjTXYY8YGcRtfQLD71Fgj34g2az" ..
	"/8qwMG8XWzzWF3yTBSq/7v5M20P8DDZs67AjSypd1GrIpKnxiJUHvcJDZ/7GuycYQOMq0D+s0gEzLs8+UOVi7/GstJglNqLk96mf" ..
	"kppq65lCHTZ7VHVrENyX+W20YV+DfbzB7jRQyXVraVQp0rhn035nqd6L+Kdgbs1cxMTYAL8dq4urcZi8MYQhG23p7dnZfBAxHmyN" ..
	"rWq+RRFIbDK8qnVuT9dAAaBpp8DvJEtH4+NhtrZtCqSqKLIrzx5KSy6Xjc9Fpdh2uGqNt59wIVqT15KO2EOI7TWOrhz8kprn8K+E" ..
	"q0YpWcYzUCgBXnmALVKMkjEYjQW0n/5VUQaYASfFC215v0IvANBH7Ttc5D/5W18awn5zw8DPf2BUtT8MnKtJZqmVJdJXNnyAjyxP" ..
	"rIx2L94YORA4vwIN3FHdSsCKlpklzAYJNyIQMGFCLeux270iUzdCHEwgr5VaR4sEfDtXENPk3aDpU4paWrGZbMCI/D6onAgsX6ke" ..
	"UzUrfmDYpXQWPxowlHQjmVnfuXYkqRjjlBzS4bf16T1x8Fqe9gcsacIrVZpybqd+CcelwcQ/eTsunPwvT1X8O60J8SoeOIELz6Kc" ..
	"zxoEcMrgiaXVKMAbSPOgb1o5f2qARGDP2hNh1UjsWE0qoZ3jksyeDcdlMDGcM4ZPy3yFFe20wkBlGSpkRo9HXf5LFwBsPSDOdjds" ..
	"7pkIb+MewMDpxXb9K4rhEW/8eg1xBVapAdBsx/1xMVm1fmLrcQttvrko8t5xXNNgHHMOLN6HhrPrS9a5MsifnVvuCn+x/Eh9+VgD" ..
	"Qdb7Li0d4NUche7B04i4rDOxZizzIcYguXZmVR8NnFw0Axe/vQzdDQzRw5PzsHdNyVpTz0XGWInw0bG9aBKivKvwiMVlB3+ZyLGz" ..
	"Q+iMnRV6+0oy0S9wPfntCVINkWuGUybfkQcw0k03ORjlsjJvveaZZQj6OFp4Rp7z6TuAmCRI+aKe8wIPyXrlvJBz0XatG9pUdpOW" ..
	"JqgGsB97ABj4eNKEOOPKApdOkt1V5nctpoSU2v08sr/k4JjHSPFqte8V7sFLofMI82RV94HuUPvv+1vQJpMRcOruIhFVNkHhFykE" ..
	"Z6vzbUtzsNJgo7Rr3bBf4CUxSzskSzfIWCQgqXlKQOs9TyruYbYqGJk6IsIyYTmcn6bZ6is6daAsF7A1gVrsgUc7Dm2s1Oa+x1u7" ..
	"GxEwypjWhtyQ/gycvymYKtyBE3C+rmy08s3DVh8V/6hVf/wd0T9aIEjC44Lps5i9VXA34SKM/ZLafoa2UGZ9BrOpC21o95op7XBa" ..
	"tQQebe2gik/ORApGXVcYmAz7kDXEwEHx1P9vx7qWP6arKrh3MYJQgqOYYI57/uMhR3xvS/fxwvPvN3UtTIYFAKUq5yX4xx7ZvydR" ..
	"B7ZhMGF36cemNxuQAv5KwHb6F0T0TUH878ai8b/sJVF8JZwqS1xe6xXFzpu1DOMXbyv0I1FSpBNMxdqOyJifFZhqiCQT4QhW45oV" ..
	"wPRRqkOVNlbxYkF2iW1Oxu0zz06eAXosrDAsQNZi3eAlo+O8IMUn43nzzHTI50BYwBMg4SK7ajAELVhHCdp/tKNgNwxvIyVPxlnP" ..
	"g6NhsfkKPOhTBKNtLIYEKhhZZqIuxGn0bVWMVjR3Y/jloqy+Y+f9GWkorIXDOCqeySbIyJg+RY6BjQaad5yBUgCmJgEu3X9qQodS" ..
	"jkZoDunrY5piKfih5NRj2p04rFSlMpo4zIxx/PrtYqh4V3pcT/zUFuYho61EOX8ZSkmuTYP0bzxP523XiArm8zncJie/j/J5O1Ha" ..
	"ATkZ/R8GDJIzc7qOMZltZsDUMFLsdku0SGgOmTIhskA8tTM2U3hzAfnXSiTJR2J5i0o8h+EP5Jtv/EDfQX5OlUNKZGX8tAQ2FBKl" ..
	"enF7O0TfpR1G3FN6DlF5giWvZJkR/AoFIdWKV+D7KileOhtmjW+sZ9TuOOqwalQ1VyA/FY/OvUUEDYG6PjV+Qx2/5rWIWBMkFYXk" ..
	"tsUEZtv3IkygjFHsM/92CweLtODlMaFkftKYMz7rDjc/wFjWZ9XkHlcT+m4k3M9j1cCdj1ujkFitEZduoN3Hzhop5Gh0rOQb6/MP" ..
	"OXR0FQ8Yc21KrJgFgFDzj7/hKpA3DgzndayAj8VnAh+mc2glVMJd7qR2cOFeEnYwhvxPQ0KKyM14ORwQqKv7Z5sz7yymFz+LVlZ4" ..
	"fDeIuU211Ythr2o1nvwY9yR3hY9Q6Qs=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8

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
