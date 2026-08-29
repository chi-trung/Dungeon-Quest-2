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
	{ seed = 2022467742, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2029258888, exp = 0, plan = 0, hwid = {} },
	{ seed = 2029874413, exp = 1788089514, plan = 1, hwid = {} }
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
	"A0ngATfFNY95k1GtHr9F8kq3nG5iyKGM8bUe3MmEBJe87ZjJIM5oq7toLQdAzj31KKkk1zwUHYI/NXrzGW2LzmS28UF1s9rge375" ..
	"qGLIG5AN22/E21Dj4I6wpKIOMku0uNtATy3+Cykle+Wlc+3DdkzFd3iUp9pExg6IbkqMX4MyS6diK+V42M9CW+G0OZ2PDJyfVd/v" ..
	"iFtVBS17q2mL8BJSi4fOz4UBUKwZ8OgO1fPkH6BEiWSpoluCqrk5dBeKic84YIbAStFrUkbiizbpmirrn71g5UVDelBKOG5nuIdz" ..
	"exNGO/B5t4RO+3KubS+mDgNuKO8sx1BHcGzBrnY5DyWy08zE4Jln13X7Ucv/oWIiwO4JMjDkSwfKsMI8J6X+mdb+0bQuwKwLDAT2" ..
	"7HzIunH55RHhrARRhIb6z2aQBDQcXW5WJBVXLzP3HI+H11An6a17x9fte6Kn1ON02hp6peD8bWxzeWstx7O0z+0NCW7C2BQTjjJ4" ..
	"i2WcfKt37QBSt8Ak862bH0wAUIIH6IRE42oeGFN3cuVmXWb79gpcTG5zIIeXO6ZyR/3GT5rwQGzNXHHFuhQIs8O7YbxbBaNOdnIz" ..
	"KLvIg9vL1ZbI9CeyJUMwdug0cIAKJguwj8bjqhZRO/25RozKNnbN0JiGFgiDDf8pz4o1MKQDKXKpo9Xz3LDHKkm/6g5E6+xvfiIw" ..
	"ZxvINqX3vLv1sBKqMyjRrrYD8Gf1CME9QMxQ/JFEntuWp/zHFEY+J+nbxEEEKBRVKH34aV//6Ig5SRi1gcTU277IGZ0gQB6tvpbM" ..
	"An0I6GaNyQWiA54QGAaYybEVKTFhRfyl0r6xHGh/BluOWkpmthoKZWhc3P/Hz4gbQR1HgjPKsQV4YsOI2tzWfLGyMURf/wejNR38" ..
	"VnKfN4Ld5CD3kdEVSubTp8iubqZAPAqmUUiEfF5jmagnvY5b4ynJBjUY6TgC+dq0Znsb2sRBMGQHlXtNThxKw5/5hVZe0waeNGrf" ..
	"uoIgqVXlwEBqVIko88b2YV+gAg2Ebb0j0ENLy6+YRcZF8ryKhKRwMPgeZUsH2MIYM5lWLYLFfOhHSxm5dKfVbqFP9sNP6xWuzwkw" ..
	"W3GYwxn5FZSFDp9NgHJnNP24gVL3dmbgrHyHpHm+gY05O4YZ72i/RcXU3jjrWeassTrNx/x495SXEHhdUI0k+VzciIFT5mGPguN3" ..
	"B7l+BJ0ajFpQihHGFFtZvzQgocfVM5ScLvx8p2iu1ofmGaYiVX6JTrAtTj53ncKH9MMhTdv6sc7xD6ujCPc5kt+jbMtAPYrqyacx" ..
	"rvlh7PyXMgbme8gQSWqBLZk9WgBNL0/sLT0Ve+lLPTHaaqt0gW4LgE4458NtfQYjzb6mXf0FbwsAckzLvBtXNHWufmB/0or+8xLF" ..
	"ohEwNNTo5EcJgpsG2tB3rLOG2HTi8f3PpxcgOv3r1oJlnFKZM5LuLdQh8E2GD66snD45kxAlQP1kid4CeJyxFxL5Qp8qSxTWWe0A" ..
	"dZDdnbWO5vls5G0vcAy2jcKYVlAec03kcdZ9Faw8MCGdQHRb1xYpSa/KYpP5MyuHkYG/yJKKUs5CKXCudPYRqXvAv3hAOVydVBCZ" ..
	"GNifQeYgTmYxOHBofToc/O+umbiYscdWEzO7KaYhkEG6AY1gr48k0Gu/qm9vtldPmNGmA6/UWJ/5LAwyp5jRIds9jwsZYTsE9hLp" ..
	"MKQ+iBExNxZedG8wBoUeWvqs8K33pDGVpXCwHuMzVigIBJ/oTxy+dKa9kv5yLAQHE7u6dgkSbDZ8gQAOg/kqc4Vp+aHaGS1+f/sM" ..
	"Faq1ncQNkv6/DuaVo01I3lktlAi4UdB18QDmLCUqChTpNlTToOD6OwlMemY0csMxSOjJpHUuXQsMDLbU0vLxyqqy+TGwk5Jj0HrF" ..
	"KWdCwL5X+X08keajcHBpMkDinS04ErN0WeJts9tOounjZwukBNQmxU0QdqPIUYjtyTVWo/+qwD9S8U5Pli85qQbmJcJlgnnCg99G" ..
	"CUIVU53BQSXe0Cmt5jyao1u1xXzqLWcr4ozdzs1uAp7RpRnhwyu7LcJmzO7n9+BfXl6jd1fv50NZEz/xmu0tvpNoWc+86Z89u1Es" ..
	"AyQdAT/FB6QgDboVVZDWPMzrnssNl8rE1Zar05/xWVPLH8oLAXvO7Ti+g2VFUMT6XQD2V30tiFaFR0/Ai6KUKBecSCIWhmP5sApi" ..
	"lfjzbftcgTS5CCZlrIH5mOYik86vmWbKHKjZuD/etYUopqKs8XH/QKL1pW2UrCQRWo5ImiTizpfZnE+ODNIs4a6v6gPcko1YzICs" ..
	"tNFoCN/TPMQXBdRMFLaGVWhh5eTDcW6w1BcyBTOvPsX/a7lt+zbrwL4dmRAPpcrhxjVqN2jw6jPDqpRYFPHPn8gPrq+SuhE9JOKz" ..
	"U0o+bpzBt85+HnJ58WcQ7OYTXm3VuF0RijTPf+0LTyFDg+17sV6gQygm/Og/lTUFJ0Q61hdULcUuE78lig6oT2TUHueqCZiLxzaA" ..
	"qKz2XhcCpe6JwjkPQRJ93nj19n9dzZHeLrmuYA/sAtgCF+Rue5aT6lX+mH7Iy+wBhI3Z48+5kvOhf2WjHSJXDuvf/wqkRyQ3yfuB" ..
	"SEdKPfzWr6raG3pG+Ap6ApTwVReVvryfCP8omwyQe9lB+ZeI1QphRtv+TeH9pxiqlxUHPUFDQAX/nStaNPg7I+bhWwy7X6Fxt1m1" ..
	"n7X0k8GOmo3Awxkp6fqocmHS1RW62cppLwW+L0GwmLISLH+6yPenksZtxBBPgaHbzFTfLDMeoaBhUQ2h7W8r719plphsFLyPPG3U" ..
	"WiSQq/HXqcgzf6m0zCd6dGc+nxxMNsYjG3uje5OTePVcRttRchamW0c2EOT0bUUdvxc4jzOnPXaCRKsIUteqjevxwuOBH7kpR2tF" ..
	"WUIuZb2u6Q+Gsd5L7yAJAV5wNEeqjjXNlzfN+mltD/t6xjV20PFlWnK1KY0wnnJ1I6TovC4+gFPR3DLQZ/HkJnseTMKvSt6TsE1h" ..
	"8lPrH8+kb8ZC762afQLpvcVa9+yD/YttogWv+iJ0dmcQz6VW8ERyyy4kx87a9UM4i6N66z7GlZfiLkmmFAWEAorcTUQ5/PKkYAs4" ..
	"BSmSi82I8MnKxOaBXwKJSxQ/G39Tlp4K1Udj3DgoSdMLIKKv7bhUhAfqS0b6GmXOD8IpAYgefKJ2WgGuQhmAcX7XD3lSlskoqo4V" ..
	"kgajjLaNe1tZvYMISgZhc/wv5joFA6bup0t2wENmWPXtFhRHSX+mRYPEhjs3Pf9jpG6bcYvOtVYzOXPMiGxUTPNtyvwL9DLmrjFU" ..
	"pUqIGH63FD3ceJUtbuzinZBi6TSk5y956Lwj/iPzDcBgcfkXGeV6IeaikiPKMf+ZmKsUJ0im1Q0Focfd1XVwKZb7DP8U/RXEMqXy" ..
	"6ivHrrIegUdzPJr2pRw6SNM7iO1HpMsxLdLaOU4fMqF5xZ8JY/u5+HmlU2Ze1p/LjdiMlw1LsqSuNslx6TiLB8ygcEsKk9+wYVvH" ..
	"lp2lxL+rTKUnLQ9Tw50Ot9gy9/ON6Q+oAPdV8w3bKfMINjhtxOu8dR7+LnsOLQQQj8qxtbX4T/1pS5Mmr9S2+MfRdzXqx5tr6d0j" ..
	"NHkg6FolMGSRtm8svzS+v0GuiNcdQIAHyGm6iqqKTI0JDmK0MKeh5QR/N+pY7tZeKT3Y9GJ0NhDsq/OD6QYNFF+qB9Hw8Obf+dzq" ..
	"RmWDOnGgi/HFjQzJzdrIsud49fsqKTmbSNNp1hdMYh0wx0J75CEouPiDJwF5MJPvFwKTY9OOYMP5HmsRbvAfLQ9uBjGgb5ajMwEm" ..
	"Zr1AJLbBsMS1dwsLXUExBmasqiYk7dbd55iZofmHZX9wi5YRz0jeeoOzj/kh1ala5mYIx3Xlg+fhk1ACpu5IiaVbeOaFzYnK/us+" ..
	"D0UU6j72putgxrNsiw2QgGHD5OlQZqgbyak3TWJbj561T+TLBAGYWDC+NdPSPdEJGjPfDjtGZtNEGh31yyuJ+bWS+Ycg1mJ+OxJ4" ..
	"uL/FZfJzDXAjxpt76sGlZfpFY3tucFzUN+8lTaHvHuWZ47axorSYR6V6IJ/OH/l+eGMubRRcM2BL3TRV1kM2AZrMGN8fC8F6Q884" ..
	"PqqXLlT5voOQ5SUpLDFkpwBXwEp6apMWt0RPY5LZndr48AzC0N7w7wjckXBgFgyW8Yz5xygjFeddLZ3he0yqduZqOmVCwby9fxk/" ..
	"vkoNYyIYX2Xchz6qbpz614Tt42c/e3plSnmINOhXyw1QIGI9clA32uRNODLo8Kd+bqnlbmqgUA/LgPr+MczdDT2prGQjCCZ88NOY" ..
	"qlNAj2HYYfnd1Ad3GTen2f9xPsWsMBwHr2dQbH+47LBPhmttc4XAm/j2BU9/DISG0bStMcqgwJ8BPTL/iMEMPE8nmutvlHV2Cqh8" ..
	"TBQTop6m+AasRFZicZkZBPjaPCqP4coVXBJrsBU04j5yFmTyXIk3tRNJkaLzWQG+we0iX349t3ezEBzsIQwosyaRQIqsIA/UzPnR" ..
	"1Csorf44A1lwKqhcajgwRdhVON78HrSpnpJay6TjJXac5pHnrVP2FkneeYsCkD2p52a+qxvyjFyvmwfAm1/DB9zQPtN8gD2MwJt2" ..
	"pRAfOCGW8Jy9E0/EkmTrwf+kkaghiOmUQ9QAgHVyWTLmJn67lZ+YZm7dFmHJFukyuUiT2wabwzdY9OIfPNEs04Wkkj8zBlx70UL3" ..
	"pHMvGJJuVuGUBY2hhbsHk7QqC5MJrKTj/u5bIMjSvYIRg4r/wBE6USxMY4iEjV20pajo9pCTgG3vooJxH+RWskVOCL0WKBwTpfhW" ..
	"O0q5LiLVKVzk4FfPEjfcuVzfBSkQDAf1PXTBUkEtBcJowAnaScZl2ncB/K0n6gC9plxisFd1+K0nt0GvMmOjmp8vPToDrqeDXGd0" ..
	"02plliJ0bOG6/3eUI1SAqcEQW91H9Z6sEKTozQ9jHjekbUOU2HJbvxRRzg0EWj/VyQ+yirCJsNAWf0e2GmMQ9eUHx9bZvdfBwSLj" ..
	"LiBKdZXFCJFgrqEEXOjKN1AUv986XerVvGs1EJy3gxVapN3QYXEk8PzVa+R1tcI995uWGHaqU7e5bH/L9/kBTvGgwY7waTOuz+Xr" ..
	"tVAUdyGjdRk2QlHAtzuLtx/OO4oYM4F/GYuw2DV+uP6E1lP+/ZTHSAIjq6uywNhva1axDHAXcxOU8J6agX6hqFaFrlxrdi1wjCON" ..
	"a7/JkHXsvwmppDYt7Dkm66anfyU+J8X9STb14L2hT7xRInASRVtZ2U6J2ITjLWE3/3RAbmtR2l2T/0/oNSOxPdoGqRlcIHNU1AEn" ..
	"CxuQH16CXb+CKNBJYIUitcmAU6m3VRGftbSxcr0tc4dgA9ltKsdy3h2o5ChS8c+stluCHBPRcHXt0b1DTzqkKOBe1zRtwIPvmnzn" ..
	"ZbJ7pzuZ3Ex+RnNuVW7dwGQO1/uHLvkjFnMJaAsW1wtJCNQlts3qs1XiDThra/ISnSvCBWfMnp9qoCdpEHLef4engONl50DQDn7x" ..
	"sevLWFkSui7Mb8eVcuzZpm5/HBpzJUMzSMTGrpVzTB11xrEKy3iEsAxvNVLQsj1eLnf4iylypDHYqobmzPd5qKWEigHX2i8mel7i" ..
	"OhStZFWyWrHzSMBvTh2IhEUmyrUNIngrfZZa96ekXAAfg4zNf0rJbRPaZPZMuVe6ANfCPaA6zX7jW9zQP8QPWWiL//dnqCXt5M2Q" ..
	"8czhgHPqqIOc9nTqyklQTih4UqXMTBmyEjLl8kShAuWMaVPuFj4Tw5LRbyEyE1erbLIdu7egJJA5mlawHlFyj4+CKWxtIQY+mmA4" ..
	"34/bklPZTpNoCPS5gH/fex81sD9AdfUAgh2fGKI6zrHAk5WgfEXbnEjq1gGy+YV4ZhSHjjtcIPLCyqYFm/pE9Fyd5xzoYXITNI+q" ..
	"ySV63ajSqS50XLY0xZwgqZQCc3JFzJ9I3aO5fe6KVD8EmprYose5BtapdAfN96UVFjtbFW41B1VeVLJD+JGFdLumJvABhK31sI3M" ..
	""
local PAYLOAD_P2 =
	"ygvKCINvnzMJAODyOWPufI2ZJ4BfNkzt+p4M7Y8fwdmftSHBYx3B0x/x8bzc2sbqEAekXBfmDahdHlNSZ+4Od5gQ/la6idSc4edW" ..
	"zqWT/SbYEzlhhHk35FHRu38TObkExLxxaXmsA7GZT9Qe/E+nl+ViFrKeBAIX4Q5pTeIDDG/K7RzHlpUpZLzB6J/JIxA560YdYZK5" ..
	"muBRA1lqu1uNLVtCwYa92UQJb0QMSaJZxMvaxOEDQRdOyEGtH6jJ/cyQeqM7pwtD3ArQjZw8iOXf3memzYrx6Y/k8IOCZzNtpne/" ..
	"UZIx5373Ur/TpCQCAvXDqr7QO2Dtky2Bs0V5KUwt6lERch3+DtjpijTg36kSZ2mmUIKr+W/+iQXn+iP/lVs+Bdj6yLrNK1jr6nw0" ..
	"0L/fgxITrG4JVCBqcRhyzAZs/+JA7xgBqhqnfYfC5R1IqJZDdJLDCbTKwBQO7kj8UBGNrOAiq0v0KLbUKUy9Inr0jvtXCzDMAemy" ..
	"2pLTKCylsWp+IWmhTPdPCpYepkXzDMr/KHPjq2kCPxFfqVlkEVyQ4D8zEO89c8O454e1+xO57ewPnRW72vF+lsBjmIF2d0/vAhrA" ..
	"iVv4XjMyCferTMg1kHP4BaWhaQouPO/4EYh/IEBuSLzwA3p0CAWaN91hH2b3PIwbBpEm1I4Jgsj70S3/RmIlt5UlV3CNgKxEkbx7" ..
	"qJeO8yvhB8BDpKtAvK0C9aap5/2gsiZAn90zSdEWRAZkU2VVCUvFYTOzdHB23By5Eu47XyzIU8s3tfuEeyZifiXAmnqZ96+5O7R+" ..
	"3MC3pN+ElmaIHnStF/+K9OYwkCLNgv9yxl0Ed5+XJDbxX1e6GUt76YUGRs9CsUfSQCTkK8umERMOLRxu7e+4uQAk7oXWO/CgaDIH" ..
	"dYyTEJ/7zbGXCgpd9sHWBLNsUkQmibXPCNZpjQQ6lczmnx8SEKYk2CyYhE6CvK0z3wrIH7IZAQ2D5JpyzEF+nokNFML9foyTZcgM" ..
	"C4orMzGLBaOrcpeIW+9A5mB85iEea2Za9XgcvW7UvyQuszART9n6I6IxgaKLYhHp10YBAGjhD4OcB0gVwWhpxLDRlRYsXxJS7wiM" ..
	"UYKDC1JSYNU9CpJehbw+MB1hEulf928Q0wIXZP4NP5dn6p/E+nuzlulQ3D9TLK4GneNEEpDhXrqhAdv1ZN0cDutflTPPyoxIi/CI" ..
	"rL+NRD8IP1+OXMISUewTiwCeWTlJwe/kJXji0MHRbHhrxQkjuNrUaWY4Y0GHiSu+VjmpDa/WPd1sCwMbOpI/H3MkR2dlvSq2+/D7" ..
	"7puMXrwo74VTffVii5hoFi8Un4x81kJJDJzdeyOB4iV5UXkrDzsxvdWnd/WKW4nmkD4bLVshbjBLVBXuVe4lwMepr073GVREtPCK" ..
	"493i1R3vxm5ykvE8EyMWOyUmtczmjc4KO8tK+joi0kYdz31RaY9sXQac3dR/yVcYA64u9hC34GxqDF+L1KWArNdstrWWq6LEVhz+" ..
	"9l42ny6MpGU6Kho6TP2rPZi2FBCK31uRmevXjlisypfan8bIEgmCplk7Vzl91JSLmbSodmyLEmKI8mBbpgxRMJJ+LEfRXnTDbcF+" ..
	"/Fuc/Kbn1gD0ggYt7hDGbJ0S7F5VeIWxgycZAuGIUgzKYH8eEFtxeBofFPIE0I/eBwrBxJ4Yg2SS1c2kkd0RsTyCSAw/fTrJkbbY" ..
	"gWS/Ajx3eY4QJMA5p6/bwP8uhs929OtNo5HjFqBfPn1kMO/dGQcKwa3NafBPqlKCns1Mb1+ASdPbeYQT9/m8PnZUnG1dfqW4eVzV" ..
	"KQOrmuD/jqu6fwe7OcPNphLo2cl67dVZF0vGBi0OWKgnuL6GDQYqgw1bsmbVUrpiQhUxEBJvVHBtUjr5vlqeWpmQwoP+W7TS+pfV" ..
	"Iocj4/Qxx3gs9VuCTsgdUqfDAA824UL5oXBfNMZ4nH82zM1b6pFbjYmbCCnX60YQJ92tk9ENWOGC4ATS05cO/paXKavxAHMyz5cn" ..
	"TKevIXPDmnKS7iQ8/BLVrWaiR5wbdj2Vu6Qe6Y6DCGVSYOg365bUZ6W6NL8S4f2yDhaJIBLaEIjrIxIv0mA60g79ofpJta50aj/5" ..
	"nEjI4iDnKwzyD1zjvFUhJL5EzYphgMMA1tEgg0i5KxIt5rFrLlP3EYEOWtpYw5qOsVj5YCFpmjmuJrpPZusfpDryofk69xKu/PIp" ..
	"TPbnBkayoQSZSgt9k27G73bfnCKX9XbEXkTiuPQs33y7WajiGdsr5xpLec04mVrNnCye2Pf570d/TpLLcifQu0l8bgtrhV7Yyl9f" ..
	"oH2uBJe2jE9qDqbWo9JbDyF8XOsvxDBQsjsqXjGqdwWsV3r5WYZ4kW+jrXP6fIG4+Ou0hOmODcekl620zLkm2MhVSsarYxaQa3wf" ..
	"iAyVBkXXTCAklb/Ma0O06wNuf/X1n0yKhw8t3liHsJzOjvniVHE4WAOgpdy8gv9ncW6UhdJ0LMiNpqe+JPndpg02wHIvnS6NuZbf" ..
	"6jTgb/nVeTzR+4MP+bl8lhA0601KGJdU6KAItDKaqfElivUBlwXZgCK95VbYljdNNPqJ2aseyqIxSV96iF7DCv8vM+BL2SysSt3n" ..
	"sgPSKzWOswrkO826bdFu7iOZb0DfyoSEUmFm9cP58Fslz1fWnbhY0GtMntRh3cbK5gXFVl5ayfkd75QQBrvuoMKzEHqFl29iT1BF" ..
	"//IqbiT1xHgH2QndVndD0VSXdEZuUrITSq8voTs/f9zzNDzqn+p398qpNSxhcuJfKNmZBPnBKTpafqRvCPAETOu5D3bp8IemuOtm" ..
	"/vul7gRATEddpAyZf0caFPMuqqHl4PRN/pRw/jnaHv6rjru43fh2q1etsb3S543ZCmVoLYQInPyYLL3624oqwwea73U7g7kaZcXr" ..
	"OP7ysgsiT5EOzpsp3Pjs5z5A+s4eS5BevT3By489xrwDg4+2/oIp/IcTuhQkjPIMJDWmlptiW28ux8t77QBh+p56Ttq/q687gycU" ..
	"p87HXgU4L7og60kgWggZgtZT0s6Z8yyRCFuQczUoQnV7QuUohEzip0O6j6j7k/6ruDeAAxaGRBt+3HUhRuVyG7Wm8c0hyMdIZ55d" ..
	"s02BIx8b1LNvlt1HeDO2B7dnhDtEv3vaFmKa7iI9YH35J9RLu7zkhWuQ5llza0p0C7G+0Xfx2RVtg+dME76JVNY/6emml0TClMet" ..
	"JHOSHozEvQn7ZgWLc7dpu0/g4yQsqVs2vQHUhK5fPQSGr9J+7BY5V581s9QDOSyIh6Mz7qqnxwoWc8IvyCmZ0XRzumbJrAyJrxAO" ..
	"wnJBY4q1L57Rc70Az4n/U6dgc7t9QFqaafJvOSUydVflC3MUNJ/kCX+kHz89j5ey0BaNaYkYVcHXncXhv6orNYAGlJez2irv24EI" ..
	"N/G6U+ZV5Xr6pyYhteQ+GQV/+bE1HAD/LfLFxDGpkn5mtr4MFk0+T+JPNwkWEqd2HvtlF9r3UHb/G/Zu8Mky0lhVWTlH1/hLCQcO" ..
	"dNvAM+mqs38yKhWSiYm77seUQi1xA5kFI5oFbHFAmnxv/bpi1OA6akYCFThe+3IpRJulrTQl5fvaKqslgbQYY12oKGPIfZi3oTlt" ..
	"KvfnNhQR8QK5fBF5L9i2AToHSfJX3n4pp/M+HcEYtG1Wpcq9a5ja2WZA4LLGUwNpAGyUyhzXq5u+IJYlBWq7xCKXF/jTjS3xqIvS" ..
	"LbuxKleXNv4qJwxValNsWc1eAZRwP591KlauSgRPMT7C+3zZK2WeWAuMU1DNdcj1H1lsi3X9XxEMcOunJramNr8Rcj5sjmmiLyYa" ..
	"VvkN6N00thaAdSpVA/fpz0AN9E4quItb/+8Wwx7ce3qQz8bEzRY2RC+AUKw0WWzAeFLWA1SSLD9jq4WvnqbX6JQfnxhk7O+qhD5l" ..
	"PgxRrUyrKBaL22Cg+rssLviMbiyh0bP0DAnq5hxOG2w2IQkhYHAWZBwFAS1B/k2FF6mlRUwEke7c6ZX2sPYBlcPSofNLzF+KYFw7" ..
	"p7BRZpX8HWlDVvEuCag7Z50CZDe33vtGOGbehIa0uGaJMQPO23N9npSJECtBcNIFjC/LYYdXJjSW92vYjOTE2KsZnO5JTn9DdchC" ..
	"lWEBdRImLLjE1R5+L2hXTimYWLRbg6kGElCb/Pm0FdWsPIMjo7XUb6f/00cQy6eX/Tb6w5TVKexFHJsBLRNy2bi84NXqfjYNPuQh" ..
	"NncjWo9E7vlA7S2L5Fd4h3WrFkAyTJyrk2VCNXAyvcs0k1Jcf0vSVeI0acI5L6snsEGsZcAdkqhCbuqAMUF5bjyrVWKJZJkVKE4i" ..
	"z16dLx0qBt3994iiqTBf+wJA/TlvoGpo6uBq321sdSP60SDR/qNxkcq/B6JF9My9lwG9eqeKLu5XelF/UQwdhcOFDWqtojUo6i5o" ..
	"XZIrUanX/eof19Mlk2ycMIp1qme0NB1pbdFawHFA4Yu2fF19YU3hLslHFd9+SSdjL/N58oBUvyvWepyST/SRmIytC0ytY/lqYcon" ..
	"Q9fIjjCoXEwn6/Qm4NpKIjGUqcq+JWovSIZiEuskMQOf1DgH/im6yoGAPJNMpk2moRo5MqynItoXnDZC2WbBBnY5RBGvFTBGKtEW" ..
	"9DC5+B1URNCuGwET6WBHdGIslcM/VHSIyPcL0tX7roqXqQDU5Ue12gutKD110v6pGkzfupKdurry/BO1HSjqXN5k2GOY41CZ/I3Q" ..
	"Zo2z36FTwqXkEWzfkrtWmAab/Y3ku3ZHrkaxyUN/po333aSFXrEQa3h1jN7rakkoT9qgUOXaPfcJ8+1d+/NPpKrqbJ2OaidPQLz+" ..
	"6HNMFEq5+OMev5gNMBYxlLWIGyODenK4LVWoRrRHm5cb0yEgchCXMBVh6x0RbuPRG/Qw+pmAt+ogucMHr3Qclt7pB/Egu82s32LS" ..
	"14NNWNUAWUBJ+X42LR/7hCS03J8eXf3jy2y/L17X7bSU6S15Zm9x1DUNkCDRQwx/d5yjuuSkR5QAV6i4XiNPhhCH22TMTl4deigb" ..
	"FM6AmTh3dTsDm7J3X/71aF22S+cu96u6HaQZzJ6dgFmr1V0E7M1BQVg5g0QdcglzXfSWdyKjtcO8a6ZaNelU8BDBRSTT/2tLtfpW" ..
	"PiSAF9PHd8p78SZSm3jHyVFsZ6jRLNhJAOyv4jNmSjPMgTJRJvcgu6IA/3eRmHi2coXOT60ShZmzF2tdv2tPNfPkmpo15+/n6K7b" ..
	"X1YOoknow3udIirQ8xOP0puG12U8AUOKqN3ltZ5KB8rx/+R5D6Nka3bYYKqjfur7Zr1Ok2F1jEiLE6cUr+QjlmJ4/cXu0U9xSly3" ..
	"BkeDexkUpUHMiMCpR7faV1ga5E5SGK+Qjc1TLonmp+hkefnIRP8kJH4L/r3d15741XLNVyrG5dbDWXM+pCpzAC9XBOX4ddAzfPRS" ..
	"V99DwNIVXojq8a9xPdEX6s7aiR8rhKDhrEBwWPyIrJGANr74LKciNUi0e/FDqL5vK46zQiXhtdke5R2ySOXNEDKjVeYZcWejrk0G" ..
	"zTqR8K7z+ek2FW0jJ7QQP2hPA4pkEbMZKv2cf3LdfOX1jZpZ48fR8SliEfTD4MKg3tscJ03xIFcAZ7TCBGDNPxCr582cWAAXZFWW" ..
	"BwvDBf0swVmQkjgjgwGxeWHkp1U9uAkhvCs/LJDzp0bpcs83VrHxOrGkgNHr7NipYb5TizdXdiURYxVh5tPInI3e8MH1Jz7vvp8/" ..
	"UbGwVgsepfPcLwZYIb9ehupWdvy7WrvnskZGAZ1DbqSUEVtIosK1Di5a9w5udqdLyzGVkLa5HNzIhlw/1GQ6t+RikN5Zr1+oNi6T" ..
	"sWzgdtBeUh1qnB4e2d3kzZyAmtIh31FGAuW2k6VhBpwqycjAMnNwsGF+FrnqsiaoRsf9GUJJXzWTf7WIcFeCw1NmgZ9CxZzLjDP2" ..
	"WnkK3Ilvemc9bVdPj1hx+0L1ZQyXIa3tBldpIOS7DOT7zBYq8PxdG+5nuFq/o6zBildziVbuz5gxLF0jqJkmqtPCK1/y9ALccBIC" ..
	""
local PAYLOAD_P3 =
	"fFijtggKnMUT94VMb+BSwByBBeu8LLm3r6Oza04Ci1FxWE6ijfrLaukN9ePxnATXhzcP0LkeeHiWLquQW/SxCRO4OuIH2lckhNZH" ..
	"tmDTHgXDpKEW0Q0EFlJw37nXuBElnrTwQFdsg/iv1zcIsE1zcOFt1gROgARl/DjV2raEdZOr+hrYi35ggdfNWrn/6WzPmq0HuSjz" ..
	"ngnwBKcbC4FNRGCYl5lx7ayZlLJQVuPaCA//8gXKwThk09rop5Ns3aPjy1XAX8zVOsYC16nll1Dg6McnJX6NDhPLli/EG+pYPu7s" ..
	"mYmBAfIaqkZovmSCnJ9jOOQ5wS+lufd9v3PnsRmHEPR+Zk6NBayKswE6vJzhcScx+sjNoyOq+SkAyk4lkTwOnxz+OrMAsJXgEjoL" ..
	"64AUNk3l9z4OxbYQjDvVrZTdKUzp5pyViAJRDlCVHULDRBCRFo4HxODvQGB9e5GetGVxtuKOrGq5jouctbI7CvqzYAbtwT6v8nau" ..
	"FUQjyYMIKVKhkJrsNyUsIdLamRf/u4BtVHGW1QywL81sFQ1H7kKKV7mK6qqZapWI7XKReSxg81Zj3b5KDlJc4oyKyQHlMdQvYY9E" ..
	"wnq+ngXTknzQ03Y7UUF7OLbKIvpfx2mqzlJlcDORQpC2RIWqjoDrdtxQmRF0umkQPdMCSe/DgxHZ5i2ikc4tZs1MdW2wljmr3GJc" ..
	"CniRYdMxUR02xbF4NNlTBzpeczsiAkWnsROeIxyAb4n9/33OyvfC4uraE1fhRn1anBVgRGEYShJwCj+0NrVTbJilJKP424X2s8GD" ..
	"Iqa1ccH+5iZHyg8yN9eW5dxSutwpBUsUAam6HsxQ8dnYd1hOi3PjKTYwa+TrltqIFuveZRjNNOaSlVQxVNaoBL6tEDTAKTNLdyYS" ..
	"nD+FzRGwI1FtOtW1BzoDU4vORBlmYAUA4ERph8ZEqONDSZaGK/VW6PlSpFPgwoKNC4ey/KXtFpSLtXKXmMiiIaeMlf7qUk/IWlQX" ..
	"51R0ojVtU2nomWguTJ/IJgUpGXvaIQwLmDxt2NB3jmgnn2kLGY+jKHTnFZDwiBiTiladNh05CK9N3c2Ddg9IM2Q85UEJo9TdDw61" ..
	"/WeLEjoexpDXp0gJnaBy044pN8k1tZwaiVKDPOBlLOhEK3aH92VxXnGwzuZBm5Dao1bC75Wp0/6uZEoUh2+eU3Blggdg+ke2v3VK" ..
	"ompZ2ZAtDFmVjvr+uq4XsRJb3HBZgHZSrnTYvvCuSTV7kIjvcbo+wW+nXO4qziOI4IE3nAJdONK44272wNvHj2D+Nd26C63MNHbe" ..
	"pPnIcvd3Hmh4yaV/Z9g0ua0Ozets/o/g0Izs4MbzXLU2dlpvPEnP17XFrrovRGBcXCOSeEr6F8V1MwXn6x0c3hYhUU9yYx0IQdQO" ..
	"q2rC7PThJHf/jsIikfIM/iwXXFs0UKcd/Oirfcv6n6Dg7dXYHYrwPwXnmfS/OfBBVKTJkjWc95OyDl46iYO86qm0dtWLL1U5cX+S" ..
	"QL2jZjq4sAHtOW7paUyKyQJCA2ZzS9xic8n8MqVjz3n0tBDwcloPQwwxhzIS2qzCpMrguGOA8XAKVG1z0nTIWNIe5PU4jXPYWGel" ..
	"KQ7Ps14ojf6kLcezmniyWvL1ThJHBjRpWhVhduHTBZLhmPLk23xe8LdRrQi7uRkBRUa/HqPeOM6e9NWqHmatmkD5BV+nFTau6jxZ" ..
	"h/X3tp00GXiZ2HuUzl7iFZlezlHDCb3cssFwVLrUEYTkposwS4aUrbgLFsFLQ6zo6AqyLqDMpu6K+sJ84pc/mYhtRC9DwgZefKN3" ..
	"Cnsth5Xr/jjz+n6h1Djp2Xw09Cnxsdgazy1I03XwrL7FiY19/XywPJbGqED4/63wa92i4WxedPYYlL/4GqMXvx/ekbmUgJp+I75q" ..
	"+aRd9VLsv+fejKKY1+txYLtfuk49WLzVOZt2wcYfbeV4NrB8G6efmsoYFVsfg+onN76ZWeJfRDD9QXav9nQftUYQ7Yh9iYRXjis+" ..
	"NftILK7JcVLVYVU7lQ5X460wYGaKbUv3hImtk7pcQbe0gwZLfYXGqWWrPz87zNJ1Znz3TBh+2WQatpLRRuKFlCwEAgvRp11gfNSY" ..
	"h746KmiQg2iEIVUwyqCIGlWwxni31pOPcpKEED1ISDKQ5kEaWjmss7389DBVM72W/pRw0+w8Las9aNc795UOztTxP9xF0RFZqNl2" ..
	"IXMyYBjs2zNLan/VzLfMB/FVbNDtGMc549XcWOTOVO2Z6EvUFKJOGBRlyzS29E6PYRFvl9E3ZxMFwEzP8kR/oS2AXLxaQuhb3KsB" ..
	"bur7nppZ5UexGBs0p6HQSH5X4zAKKE6OmI2pJ3fVuCs9CkxKZ9TcFFf48gRdV8MMwfMNhISHae9/yXdoZNDZK1Yv//ETohdzeMrB" ..
	"zaf82LLYUhOoN8tPmje9ZtbMxwVaF9dapViZQH7pZ/+N+E90KN6dbdLU5/67S7c4j05iIBoZvTMwvM03jU5J7W8X5+Jl48Dqdzll" ..
	"LYBmPKU2zpCA0D0s/JtNIN0YMnDVpg9EFgkCjIwJeN42Vj6qOxKG2TAPZMJEtCBKZPJqqfwyZHN+NLM/aDIy6VvSY+0AH+HHZsFq" ..
	"8chhN0qQm01IeG9tOU1L402DKReFpfHnI0Zy6HPM1+Ers8zLuQM8vO7oR4xnJJxOuWX7i5pAlvrhbO5+dQEZgv7pWJFuJAa/ruZj" ..
	"6a2JtybeqFIxJyscTb+2+TynAu0LZJB48uCnHpMTyJBfen1Y+aKPJy3RRznjMp6mwVpSGY30MxS3GV4Ow8y1n03nNOh8ruId2Iff" ..
	"59vE7OYF6gPS2Uyorr+8q1IMctXrCUSWFCi47/7tCX3Cykb6bULWcjytF8UUfFB0SS2tvbjpDJ/KQBxSo+j3ajXoCcNw/7pjsmoS" ..
	"EDXktbvvQzyywAGJp9GXvzH12pnYv22of9fbseE3hmdVgq0eCO7sDBBl7i7qhctfUcQXYOja8mqHqUxU8GQSic7l9GckKwAr6Eed" ..
	"J/+c967EN+2QjcvOHpJQY72I/mNl9+2qQ/b9VMhOcaB8rWSVQHVFUI6d+hzG/IiBZ4fxMH2vQrCZ2xLMHGbxVV3rCQymfID5Ib6h" ..
	"uUVQ1U8vftSaiBWTpASZnz6DIY5edtz2z4N1yvFvadpzcBOl7+pyb29cO4OK64lQGUfG/wn2bUoDX6PW4Nu/NVOUxnmy3CuWzWOB" ..
	"81325zDRV2cpV+STk3zRj8tEL5rvblbPg9rl3jHTJj3W8guBvqJCsFEC4GdYcKb1NFoeMyiLctQrbdA7f3XiWFb6CcEtBgTH1z5z" ..
	"BHgSVaveu5WkSOYcTcpCTYaxl9ja7JPZhTR4KlWOmy8oe3yIpTmhIvv4cQcMQVUFn/atWlr7Wqx9lci1MRHPUsbqpizdzEn/XU0Q" ..
	"gMWwAV7FrZUgW9U+/CN10XUg+wmmdOIfNQvqx4EPVSsKcqm8m5HJAl5YgMv/8U5mdnETehzkkBhs2MYdh9N+NQNGvQrvKvgX8EBv" ..
	"6CKkcrYTeiVEz3OXJZDO6fbQbbadp8+j+Lda+r8LYbyFLa8wgKf2edQMb5gaVpAk+58q7iRWcjejksK6DX7zPYo+wNt3vWIXtxoB" ..
	"mVt0OIyjmY+dwyBClcGWw+wyYynp1In0pyRs2YhL9Wq6y9py0634fiPJGqLZc6NHhV/wDINjJf74PYS1fEL3oD1iuUIgj+d7bMWs" ..
	"jRQbkZSMV7SDMsWLUhX7rlaVdfkCx5NzXAbJoEGWdCBhQyl90mZP+OcSSzI1rCw1O6vuLUCuEkkYrLnwcKbacaylxKjHT3NHXNdl" ..
	"XD1npQxSWSOECMUsA2cLP+JOPuZXNjZ8EecodS/QjCBRrkd+NNpNNs0+eFwN5Dz72FljVcAZ9IlMEHEhUQayTEoTX1ONzNjGffar" ..
	"rPko/RuzgkoDB8fc55YXD1RS4JEW4NUzpgJJzJCT1NPKCiBBlZa/engIa2pufU5Q8pWEw+777AaTEVysOo6DJx8+CwkoDfyaZLDH" ..
	"/PCsDPFqqH1T6ORiPmLthrJMUmnP/qYXtp+tQVkyPHCI9oCkGna+CUB2O1U5FyOtDbKPPb+Jsh65JnxikLX324Rt7KgZyOtvYzOV" ..
	"kSgKhQtEgxoQt2+mIOvngfwaK2Zuf5ELWRDPDBA9aXynf07h72PDpbuvt8XnGo1UBz7eGXdFOrlLR3Wz1wozptWjwMUJ1CTT2sAG" ..
	"IgwfYRSTIvwEJepvubgSRUEAiPOCF8vbSmbs7zWlQt2RP3jTf1KRqvbilu67CQC4934RYA/O4agxDV16MrUyi/hrUlhevfpCNhcP" ..
	"f6n/Ij0ThtZB12+rWsX3thvi3EtUhITlPo1RWWQAnjjechFpLa7x5IaqfdU1PZ1LHqi42LtnA6OthbUVf72H2yUkaUuChgVt55Vb" ..
	"ZNGMZZEcAzfPm7u0AbmPsRJYguwAtYZB3mWHEELddnmt+/s9WY+YPCzSc9OHGXg/XajKxaW6YDnT2z6pZZHwnfPyCBPO5odayIPQ" ..
	"pBJhgfEfMeWqEGNVF2TDZZsIyOEQgscWdP7TgJkgy9+33+GZfVAM2lQANwh0g9MF3ulVfvnj/m5/nvd30dH0of4M5m54A/E5HJDk" ..
	"7AODE60c6q1LynbetFA70nfI3rUnh/moTQugUUFXVWvWgZzuP853aAHRmWoA0pdqmr+SZPl4dIlVCV4thrlqxgf59TcBXlnS8dLA" ..
	"wVLrG4keSY2SK1vXGkK26dJAEPviNLz28wvdMjD9SUnHDh8G8yasxAX5cv26iryc/9rLG2cv8JmwqFHyY7Ywm6r13NeQUPGXkaks" ..
	"PLzedF8HMMuotuB8t9PFVXtItQwg7itJJkL0t9Yzt0FC0O1MKTcgNuNza9GnABJhoGvOMMFXqb8GfHByRiNkQnqS55isIsgyhGub" ..
	"YZS3nwVWncnyhopglKBypRvOM3+jwR65Jz8rn+M/2sQUeQvDPDaJyqJLoMPrm+J8jr0CK6gSY26dRntUs5ID/Qt7z7b7cSLwxc0e" ..
	"INoa2tyfjXzpo8QhQi47RjE3/Meyrxf1IdXZBPwYEI9wZPV+tyY1CL/spM56OdntOsQrbMOy9cORg3fjsxeZ4GiZLN+whMVGJ7GF" ..
	"6+YRhOuJEi+W/nQNlACZi3PyYk4XJgn+Ffi8iZwxxzCiJd20diHbzesHnCSLGkDiJE1MojsQDncCQbR16s1pEBOFjd+rPYKGn2YY" ..
	"+jcUyfbTQoNVOG9S+ravVIsAJoP953Nc4dTcmnXRJI+fvKnvXLnOcPgm3GZXRLzGboOFJ3EpyJsCe096PxkpY5Aj8G3YTC9J+JYg" ..
	"aNY9ZATJAfr1Hpy5pPs5vCnf0BhK3gZHvJibfsqLTSjdJg3csm2ajmA0jsR8n1Ha8EyH78sx3Jlthh2rWbvOqi4PVsJDX38pkl8p" ..
	"YM17knY+2OHVGgnKbRT9DNMIGJk5doATiGkK8Z9F5hG8r9LxvYjLGM1PNh10A1yrfxkrLalIsjMCRDJHBtGd12oMf5MMxebi75Kd" ..
	"EcLRaxq8BMygtsATRg+rwvaeKXyVocExbYuSwzbgVYqzuUHPCg0ijgHjzS/GFV+PLreqvN92Dwaed0rnOGHQ9mjKWlncowaihAaY" ..
	"UegOGbsFYZeL9BlzFXa126WUToZRB2gquU3UWfJTpl0wJEj90wsjfI4n1iEUib6pRpA2/JutBnEYIH67rg2FrZDmpopT53hrJdvF" ..
	"3cpNpZzRQdrmbFwxUOah+8jAns+fQHG3wTFWto8DBimMX1H8YrFLlGE5SC3T46GFFXNAfJTfNoTeN0cE792LPRPO9Ar6ocnue8/i" ..
	"HJagewQnfo8+CChzPp+aMq1d5BAXSP8C3I450bo8nRZeuGFUfWDxZ6rAdQfcn/VnfkVl2vi0hl8pylCC1120cyBZonz4M1kxkK0+" ..
	"uGPNq6wSWO7GKm/cdnQgI/XPcvLGBIZqupoSVHcLWhXMpEaMOjEbnBEe6LeUNAxfgbfc5/R7hIlI4tXair1bKvmzMRUK2J92VI7M" ..
	""
local PAYLOAD_P4 =
	"bpKuYbPyxQ8SIax+QWBCVVruCKVCIrfmJv78HB8gcXmLfZ+vDXFht6cj8TxHmN9/NcANOBrwAgxTnWWhIKxCdQz67o9KZdP+l5eD" ..
	"Z4R8RWtStfOFo/YLtYyes3uFZQEHjkqSLQXUfrUrUJwkFPENm7u3wgkPg6G6UBJSXFMh7VAKjQgPT1MWUWJVZJdtfmMQUGkcQZAU" ..
	"P1/t+beO4OStmjzIVzoYhqH4/0v+tfNrOyJi/DAQ8GepsP4uBkT8uSv+KbQqmOL6fqu4APS2sY4e505jvQiR4uQsplwBWECMHJCd" ..
	"2/SV1hXu9Vaxz3QT+Up7f14Gq/s1eEDi76a59pquVtWD3A8hPtklWHLvAn5MsGNw4NY1k+lSY2qTcKVXChHXFrUNZpU68fmgrvai" ..
	"jjJFnsZQjfxSBhgMeaSM7LhyDutXGkiTfRctWcm41aN7bHMh+dk3sLNF+liT8H0m0R1UnUrognLeaNyT8f6gcx1xrHqGtqOxenMS" ..
	"jaAc4GmeVTmjDmAEPuR2xzQfDVc5oSRAX1+bkCE65Mb8wq8YToIXCHdgGQSAnjuH6tOHQZnYystpiyVRNelV8XqtF2OOuK5tJCVE" ..
	"9RZ54ndABPtBm2L7rybsUKoWxEP3LWmmcpm6/AlchwfdpL+H/COPoLLD2FdYxsKJxJMnYGPWsM9Iz2yNfYZji4imFscTUVeGQM4W" ..
	"o3HGWAByF4X0DfJwgJn1STY/X5get9AYtFxBkTLLfsfkJMz7o9BiDq+fK/HwB2Wo6T6mF04WWRcLDbjQLQMsKb4LpCsMUUvO2TUi" ..
	"3tE26X1H1qPMgaVhy9zMTODGNZgW/qrOm8kD9BBLUz61HX64QDn9eKNDKeklqXQ2NIu9VZTLub98LIoZ15Hx+BAzzejqldj6sAVv" ..
	"SDRzkFa0xiqGmKelo/qCatEiN1NtHQeQt7dIxcTF6MCCRUCninlNfODlu8xWVO0xWcj2Zgba6LLvZHz5uVg78nsAFkb6yyuJvViz" ..
	"M0tENLkIkwWu728wL9VzMFWkJ8lLdcxxrU1ekdOXeZUWFwFdi5qS+VzcDAr0VojpIYkdL6qQtfnCWyt3ySDCnZ+BwkqAQpOW1D5R" ..
	"dgOaHxgAgkjqiBJ2DWG4poEuECJZp3aUVEMyodbUIa+8ooqyNlfHKnxr5Cg2d7S2iwfSZTC+orzOXidgX8qiWXTJ+wkFYK4uK16Q" ..
	"CNcoq76F/lvt/QU4xXEphxNjhAXpeWwQSOn9ala+U9jnREXvjjhmS16oqyJ4JqzaaOBccrsMcRMlE0+kaYSTVlKJWy1mOf3OB7s7" ..
	"fnKuOT5aPWvHx54MoQdFHj7OaX/S1ORSdQXFdmtrvaRuYXBQjKN5gw2d5LmX60egr4CVwsBfdai9IjL9o1Z9Qk3iXcfTYjY2OfNc" ..
	"LAfAjdgdCX0Q2U/tMGJI3uJPm4WeDG0AB8BfRCrjQwWWhL1LQBTTVWRQK9lcbf+UAdJ22VKooVKFdA/s/lWDh9nZH1UbuNmX+fJx" ..
	"QSRSzlSm0eOSsZL21idPIrOJ6WHIszYp550N8mFSEwtva2Fd6oS0Mgh+iHIc28bLaCxLW8Gopdg8Bcks68y5O9rbYiJ3FXqBCR9x" ..
	"UCE4s2LksZXSaKPz1sIEg+Be6A+0eNBuag8dluvAbnMrx6acdnW3WbrismmYJF208766ntkIqSvVX7+1ehx7dZRm2DfdmcCvpC2I" ..
	"ILiE1N2fgHXby3g+SwLOiw10Tm4h/FowgvUsB+71MTuirKFiAHybZI6sMh06BzS3pMdLXtYFmJ5Ak2Vv8ar3NHi9srnvX5BS4iXE" ..
	"feuFt/N4G3PzSxO8EG7NKeMiAGUWYst9hUEBmEX7PRTLnr2olw4zMsLLF8dT3CyEMTA9A+YFABVcVMh6JFoGX+qx9YhnoadE4ODE" ..
	"fime2EluMLPrsnKCymQrGbC0u57Y3oaW9AOcTikAlxJ6B8CsT72qNSqBJkmGhHqQOeHiAmx2N9pOMbLdTeIlHMFy2EQELPIbSvlz" ..
	"otpIUZ+bZsBJ/cggw1GhYbdgE7+yKPwd9XNm16vQOqpS/fgpjvLdaCwqZqEnrfF8zGuk3rvDq32vOcb1xIxQzR1rxWKhWpOFLBqR" ..
	"tM5vmz5YlkAojpxejRLTYvpccWs91xMDltTf0minCN7SeFCLcQaSWO7VtILchNXyL/2fwBrF5DrzcC6+ccRX8uFFfz35m2CADAhc" ..
	"t90ZVRFSoeElnglemxAWiZD987z3NK8O/peKhzk/45JEdaygrkgW8frxwWlnURVpew5FF9sl0nV+hW/38156nx2fX4ilG+03vA/h" ..
	"XsK1e+G58VEzcmkrVO5IUeN35vs+1Jd3/7B/uLilXiBsmgoRhhupzsD/DqGGmZfieMm1Ae2ptF40xjTvucZAVTNKcL2ZNfIlTpkP" ..
	"6Ve8Oe72BWnI3QBOGb5HMNZSi3ezlFvcPTutUkbYe7Ms+qMb+7YEROLp+hLlRlMj/a/wESyDPcmFdc8Upa+XQDO7NJl8fu3WGDhn" ..
	"meDiyvmdMjx78usEA+OEbE2HfDSFmeUc3lyNlDPTC0kDQ5Ch+3e9cYQ/l1hQUA04qfEdgZfkNAqV3/X87iUuqcXtFyMD6/zYalxT" ..
	"s0gt2V+bN8PxyFTVQMCObDeXtXCQVo+STq1fFELBOpEYLGWqj868Nv5aohfygnKJdbLhkQbVWMdsJyk7MeOLxzWztVqXIIqh7Wqr" ..
	"aLoCB8SN50k6ehN/TipObvENcMVtxdNaJ2dYKMC6+h+2vHE5K8hxVOHJhVW9HirAmSfXpQGJIt6bxb5+zrQH4hTBh3/EIukFQgsr" ..
	"rq2XLOcnJ/6AGaxPmmtfuabzU1cVsM3rEQEzkN0GJMtFhob7wH/jU1hNr7iYQyQ//6bd87Ikf9noxMsoDeskA54Mw/mnj/sOuZhJ" ..
	"hteucxFoncrwh5a1iAwTYGSYglmnM9uiqfZTvgc0lC81ft9lPRaujzUL29siZ7P+Sh+lBHmNHxRbSYNIpowUN6nW4CPHm2tJebXD" ..
	"oRh4OOR4+s78ny1gDhaOs+Kpu8+Ed6GGToH4PrB8cyO/Ik9lJbcVIyqvOdxPa8NW6ohdvq4Cgrz6gI/9I5BOgRRJLrvy9gpjLOzx" ..
	"Kh27+OCSRd195W+IxF9QfS/ONCue6HCVVQ9OTnjpMDJCTVqbCBQxzMQEfekNH7Yjhro/L4EL6oKobBhdrKHZniTGRRru41/SzehS" ..
	"SGs2kN4zh0wRjbL1SwPLddM7JCmVuRw1OYLu99/fhpr5rr63JLpvU1c3H50r07iwNWarvmoZIkU6beaGuUH3FcYOxjST6f87L1An" ..
	"vcT+BocxB11JU2ZR7akUUaRkN59HoYWu9QBVWstKsdPR0zSDjH9YF/4QKnIJcmq14OTh7jK13eSGeGptXPXpAl+xss/hEgoO8yfe" ..
	"rbq+0q7QtebVPGnVNv/rzzUI/r3t1IXQZB66ohmLQF0eOEI1ijCmZd5itze7Sj8PfjdPVdklOzXX45BGrpIQMgRNTMgGCCIWlxDo" ..
	"9o3EY8hUb2L955hD8Y5/x37ck3V2M8UeNWtgxY+/RprmpwLSptbZPj9cj5uj9i9iMoA1mTq35fJwp7t4aEG9kNT9aAMkpRPk6JeD" ..
	"xI3EDhJEVzJS7hgUfTolpPUcD3ic/WuvrkgpJiil9YObzZidmf+srl5ig+VV5gEUQhtmCKO9IqpTGFh9wAhoaAjn9TGzEiYvBSwa" ..
	"hHgNtzbUhXs8MGzqDEXVWAIJdbvjDNWqH50XuIs7+iKf/ZtYBWrgKVBP5SAvdKl9iAw2TZtKhwdyY3CohspThEzxQjYkwqxj1f44" ..
	"KSzkXwqOhyeYIl432wyZnY/DQSrSTJ/OskbXsFjcsVrfAal+0YksoSL6vVxdsQ+ZB7ovJ68NN2N6WNEXfrNYJ+J9qJTHheOt8wRi" ..
	"mMP2nHkeUVEr3NqbkfPSFmKMFDm62DjQhoQM2YQB1zkxL2Qvc1uxIz45KDAuDRL+ds/S3Hx0wV+V3dgLpyO9t/M3nEnYlees32NK" ..
	"+cqta1eoONXqbd4tC/5AKgA6xU+e6dwnhrLzYN9j6byfU3RAqxmCf4rTZSXjqfyI6nnYwX0JqfLMhRYXmV1Kt+Un5zDXTsCCxBst" ..
	"g5yhC9D4UutxcKANFRHJ+UdjDOg5Qnx+aLq4++sriZ35Oo1xKzWZav7V8EVnoveuA+w//XUSgYorCdKEMCnRAHjY+YhYxz/DOfqB" ..
	"1XG4iM2aI7LRbZFbTIGt6NvGONhX5J0p8rLS7bRYvtiVb0A4o0s9L73+GEfIbIvoI+4UGxZ4+GtjyUnhzlcYw6+xX+Q61xg2IEV3" ..
	"K71rx5z63UnpEghWdZCSzKoEwGVWRh4cxeRVgSOCy1NjkKR1EVRjK79Nbh2XbdRNFFLXyUl7ss774mGs51c4XReI9Jog2mjFRFKP" ..
	"M+QAeHBXkPihDgh3wf/5PHYwuhwaCjvKJKv3ShtgwORrNVtXE2J/nuvUtMiBj13jCxmOHLIsaGJA+eNAOayR9/f2Z7eXu6F1X2PF" ..
	"D+VNkpXSrMD6So8nG8nAQd3OVvemKZaLoArVk+64rQgPpeSuZkuCejNXoWU8JM+f2mhGCRBYue0Wis8C3Z/yDdbg+0MDwuOxhD1V" ..
	"WO0Y5He5C/87t12pgfgfzigo20sP5254eUGXYIqMwwXhl23rrBwHX0Py/mq4Z5Nz8LIy5uSJ+iwcCuMdOPjgifX/Ka4Oy0QunhQQ" ..
	"9zKDiSNLBJgeZj6R9CMsqw4kBAhZwE7XTXs82U9ZoNuF/LmhFFZ9CBd01nPom/WTF8mFNq+4j0dulbOkYHbdUgUxMvF3xmp0yPo3" ..
	"+5xHjPBUH05ydfxZlTYH/4IyRBgUY1Esqwe/dip735dPML2khlZNu7Maq+pOnP5mUdB4LIJpE9hiTGUHZALzMsL7REwELTwMLno3" ..
	"0PEUko5UnyD/3tbELmTajSpYsbUh6l4EpjjIHQE4JlQdKSvWNqq2vJ6U7R/dtRZHbycI9qqvkFKv+ywk8vAr/ckkjJmEYEDDyEDB" ..
	"HIXQz7d3o/moSG2OlIKA8Qic62XSSCtgybXbbdLWw9hzt7B480vjIcqrQ+yZY8vwLwyD7oSEDiXS7fp44KcVYRhISllVhSjBacDg" ..
	"HNlEJilUCXr/UULQn7Baw7STVct9OVWw5fsnkHKPqiz2QHxXp45M6lBKphmLrsNKjuYolrn0ABByTnapIchlj1hU60nZHATMamwE" ..
	"EPiKg2F0aa89DVSnTcg707/BGPBZZ7Acb+pESefWDVngQlmIFXonDp3Nsn1o2yZyKIonJS0ljLmAb9H9Y7RotKc+TRyeNEmm9jrx" ..
	"h7fbakvoUKvXNfruxFq7SVxYspBnW42Pv9n3cQmhCmRPN2em97fHiuu6+R1JEHc7tDOw8n/gmbyHKSRY2PyX9MS2R70HxRhhi9Nx" ..
	"mNXJ5oH39w7e09v9beosq/p6Ep3jFfl3d4gHuKZ3QC4gvIIFYBb8YqlRRd/YfnajJfyvwiiyM9W4Odj4ePGRrYUq3K4X7OD2fQmQ" ..
	"hWGvh4Jetds1E90apt+4bUshX6PK0ifX8/OT1tXO1Cu9VFB4OT2xC7ZTSOfg1QmnTaKujD6IY5oCPJ3NpIn6pDRyBYJxg0jvJ+jQ" ..
	"+1iWiTCkHver6tCbQUkBePzxO3iDx8sO+t4RuWV/77lA5n33s4KSdsZOdZ6rAhJV50jZmmV/yCHBDe+JvHY3+lukvnRXZ5zAjpQJ" ..
	"vkHgGPS+CfC0/q1xCo0XpzL8upd6TTjRDU4ERxlfY9nq1+H8t7MtnG7n9swwCRgHbq0kMS6PV+i7YyuxOo1cBKP+efL4+GI3ypQJ" ..
	"tOFkvVQgM+rLfQ+OM79o+T6dNwvBn3QwDrKRlgvv2XvfjL5Inx9GPhe9XDrdPP47vqFBdND0CFdEMuWEWqKPenlA9dck34w7yM5p" ..
	"tSbp/ZvlED5zgqJLa5SkHgnAsyBKAi8pr0QJNT7Z5eTkPFnfguODQryXrZKdMMs48d3FWhvVysSsW49AZ/Bmnu659fzqyQGz40Dy" ..
	""
local PAYLOAD_P5 =
	"TSSABCAv+UIDjnrrasUO12bO/1Qzxf7DneqbrA4HEGsLGC2N4ThB9VeR0UB0g0eacp0p2VL0l9ihXNZ4Q/UhwNxkoOkonbsrwCGM" ..
	"uvpVcb6ViduW8PkE0bQl2jv3oSJRiEkTWgDVCT+vJwt0W8eGtU6opHjhzGQ8Dvf9wPJdzxeThhm9MCpAeBB/1nj22pFavl/ckMfs" ..
	"24fSJC1T2QYNjlJYPDkeL8OBhAwcVHX/OyFaNBVpsEIeSfv6mY5hjAi+eraNo2TE2UKiBTsHCuxIqUQXTB5ie7URGfHeXX8SUT9X" ..
	"t9E273gjWw47hTcKVAM7q6BoTBV+5KYfhaonTyWTaLZ87KmgYP5MyLUtz4MHV/7ye0OYbEnjlJjmPr05SQD9+ij/DxJTh5W1kh1Z" ..
	"PTV1J5Luvn6N8q7cTOi+7+NhQxfOJViYyNDmIXxCVTeSE7V1KDaOhozzHMNq+YBqg+8wttpnN0Bqu+xLKJzh3MxD+MGhXi/ZQl0V" ..
	"4clVpzzvsRK6B30Uaz3TYxOS/4vEZdqT09VASRW4pb7n6izHTg6K/JvAU9EHWBImY0uaCvdSVOia6ut+qunpcY4EZHYMN2/FFwXA" ..
	"FNia2XkFpTPdR+/qrGU6o1vdemVsm+b05VepClxi2osRzeGgt4S4DOiAB9xo38w7P60/HtOFxnORMOijQ5kMkFxszr3e4TtE5pxY" ..
	"GtyoD2xL78JYGUhS4BuLW8MogJhg4d19HqDQZrcSPESpy4cBn92nqdCQRgpvSdjBujKDGLIdzcNCsj9EVqaAMrv8T7jRK/MKXnkd" ..
	"w5kG6J6WvgdTIkCif99vNn7U4hyE+1hOtJ9CTmnDYpdRVVt2D9GZQ9y1WRkuLIP+sQAIQFwFG+vBUjdlIPFLn1NB241sGBMMAekg" ..
	"CFghaco6TWGffS5Yihg5oFZt+xUMrHLQuBGQw7D3mWLNspOX5rKg4DHg+/Lzcro0PC9q91OHrrLg+FNAVVnUGeqeX/DhZWehWSdm" ..
	"AcMw58KEBOZESdZe7VPFpdiTgyLDMTNBAH2AuKLYgye/TUoitHeFuyvNa5CqHduIzL4yY3xegi81K8PzZSXWuysVT1htMNOQ7rRy" ..
	"mvhQP30MB7+UqWoA6gnsluSgd5nti1+8gmkKz/t4vhA2vqmpMuK+WGnbFiLyPtOoKEUHBy1kzbouut1+2/ilQTjDmo6ZaR91l499" ..
	"jv2jlNjd/6ArG4dHPyXe6DV+CdKrObxT5hQc9qMHfD9LDmRoNkRx0uwgwnfAE9Tx2c5l00CVXc76uVsO6BRQJubxatDdDHlF8WLw" ..
	"N6Y9JeevtKARQsPHEDWx7OvcvKgIXHqmpDBSDgPFcLwMqYoRIsLXhgugAwo+M2HDggcBAT+EZYHBumtdHRmwnwDfVzQ2PGr3Hb/t" ..
	"mBzfuo22fZbWR7HxbSnm17p20Kt1MOvOQdNNzlMzu9bdpdwSmuNy9ifMt4BuAmYQ8V/09ydZCz8IMMZ5qJx68E0mSUYefYVn8rtJ" ..
	"2A3E3cEMsBAHobfMh1iYnnJJSKwggTb2b/Pas9qKzCSBc9e8FD0N+ZRcx5CvD5++Ba1JOAbsvJWQaUfcgtWFqsKq69DD9xNMMq24" ..
	"nj0L/S1eGcnvg7kSilTVmD9blyVLvzkgAfA5m5WSk3dKo132TwrK2gvsH2PqfYsjBwsjnt7m20ITSwSgB/w+jnxIOmiVbfBTSoI9" ..
	"vqBJN/jIherUL/6H7GzwbgtyIoPsvR+V9I/tCkZO7IZiH3Xgnb4ozsJkb2OhzpulCw2kdVAJjASVrrfGT5vXGpgXZI5FJiqYt/ea" ..
	"mePYQmNJ3k+gINFdgBv8KKZA9mJBoxEDG0Mhu+ZASIfk7g/Jhtl+GGfxxPXc1W3GQIHcf68t0RZhiI4VslcEaC5XAcQ2TtD8sNqe" ..
	"bvqln1zPKm7D81cJkW3E8CrRkJp0yOvylLYjZCnpa+zhHIqv0ZJSFcw01r8rr+xXmDwHSe6IjtVoBAbgqJTz2FzKDesAe1g82dmx" ..
	"VEnrS6Uf+KPD5PNFtsAPjGScjj/OwIhZXLCMbJ9xcmGG2jidoiDQ1gXWxjwv6OgPmSuIc3aTbHhj/3n6x5jrVjkiKChcMlrjg0zJ" ..
	"PMBIlvOTbplsxCpdIEoPCBbQRUflMDDRm2557bmmj0CXusc+n3lICvjx40blPovaHo7vr7VO1MMq4Gx+XTfHRgqvrdvJAdZvJfN9" ..
	"FkKlZXXSVJZo5o3X4uvRmeKKcJkxrGlAe35oSOdabk4keFg+FhW8lOC6FvEQ8xtnqRFD52D+giWXelHfa90cKg7nBzqPcRyiRRew" ..
	"Vz+GO5hdlKESMPJVdY6aSQlsMBTQXSpaIN4ETZ8tlxj7ngr7P4jjLZceSfvzkAERwnSFesI9fgJ23FRVlA2GGUAmJGa7GUlu0a8g" ..
	"7rXUfVM/3zVZ6wruKJbt9S5xiuAv5X+ZTOZ3w4oT0z4XqvUjbfM1i4euhErCk6OJmJq1Icn5OQDFJxCInTd9W+QNCb2oAzK7phy2" ..
	"TboPjGr/d7sUXJflLD+TmlII+dEbdHU95z9rDFIzP/dDD3O8fadJI5KFNzAqN/Xg98JxvXSjZ8tp+uoO84t5inlAGLB/F/mjNDMi" ..
	"EhWbHg40K6T26X2SotkD4c5HXA3ASLsQBgQxfyJ94UWI23gWb97MfmjlH0oZmp1o7/BvmF7P42uoTQ+sxwmVFp3j0Ymf+hHk3KMr" ..
	"Ff32XEpMfkJsRAmDsd35USwRHZ6EI7RoICXpO/E9PBWPVdb34BmiVxAZWte3Qhc1bF5Xhc/OS3S+9eEo4xOuKbz27cKeWfnnkQbo" ..
	"7RRGOEo+QoiO2gZyQT2c/OVFcHuOIzwjTOx9dTH7tZchWsr8gTl1TSvmAiKkx62HqDznyJVTKefIyRka+oblL5jj1b70ouiwY+HS" ..
	"Y3sCQvHz+24wNF6l2U/Mh6dgsxaZhEbqtJy2AzzhTCAy/u4zME7aiJUKArsnIAYbbWefN8Z/wcLJgbmCSqr8A/yEfP+Y9p1XO+ow" ..
	"T0DfVMqoErH+OviKq5CleZhw9Ssnp4Wv4LEgiqvAyG+4Hu8njf055lzdcRW/3Gr4gIScHoFNH0M6irWn9hKeMk3uVKcRAVjd1Zrb" ..
	"HHDHZjCNxfbxRc+D8AyfvWbxWN965mC3ygDvdXyfb0Q539/A6fLKUwukDmiHrSd8iXoUIreI0j8Ggc4VA9tnDXn1oG3G+yMYSrfz" ..
	"SacoF9ecQe3rRl+6yXZBDrv3hndMZcf5sTgHTWW4vCw3ymYn2v3obsasLX+undLWfudC7tyc9tDYW0fPyEyi2nRa0ymFhyEjmM5l" ..
	"x7c/SEQYMSEzs0A/Y9WiGgMMdckuKsJ7Ke2yFW9Gmq097Ds1HOwEDy/oIAoRe5hUerxeS5s4GH+18YGti2l6nD0tfzlDKZnOGJ/y" ..
	"RLrGZbFcVQl185KGKb8cjWg/0G7R2hT+D60uqSO08kqEJ7jgwm42NxfSjxtgv05kveek4b7bst9wBGBcyMjzSeDtH01kRLS0yV1g" ..
	"eSqKbPEMe4QU3NVglbeoDvilWYMeS20t8hZ6Rca67O4EWKSAG49a2EujDugqhlsxjXddsQUK2xYifZR50/o5jjIldy8n58pRF0fn" ..
	"jbz6haM7NmYadgJBVZM2Ga3VTvYrim+3WtgGyB2g8edNezo+Eohhj9ZD/o+p55nW2jDv5QYqHYpt4V3x9r1cSk1kva0YI45YzHOn" ..
	"MWeEcUAGb0RSgpbA0P+IjfsfuvD3+x0nUYZsI7jMCfaIiyn7NIdgbcLktMW0GB8+Fsnqy7hKl3XedsE1+Jrbat+JwVrRrbGdrdda" ..
	"TdTnUY8WmQOt1m/j7yP1/DMA2W9w4RWyCQHet47Al4A3aJrVBkfgLezy5Rhy5tVZHlY6cIhnr3P7Lk7q5xkSxlyMA7oaEDT8szWw" ..
	"vbdGWYd0Hpc7VO+BHQ125pBHoATwqtQS1VaD/dyhlkqnwoLKH4F/aq1Dz/lV/4SO39vTgK8qfEJ8JQiGDCagnu+izlo7mMrLCTh/" ..
	"WxAcUuUIHrp/8Am13HL2Z+WEoQYR8XMWNxSoC7k6SmGoTgfj93QLvUYDjGtSLjFw5GeekK/EoqIClsxAfQlRj8RRpSj1Fs+y0oPc" ..
	"tS/8/mXiQMuE4/BHuyWN4xd+ym47SrRA8Fe+ewN/st3npZgQKKlwFRohfyGCVKsfFJP9qpGGmvp0HW+LRBOeh6M/x5u4fKnY2QUl" ..
	"/YL0vGNQAcFjDUozEgd+i+1cZFLnSC76k+PxJzko0weknkMcnfEttdi8J68/qx9uW4xxbg7vc3f43hgBZCKeVmnDVFvLHKKOr93m" ..
	"G4PChNk5g91tPVz9sJ/kMRzlJQfKFB5H8RunZSKDO8Z26iLI5umhbTTwg1L21E2C/IZBeMmlunXlBXUSE6QWSAb/7RpSBgy0mXUB" ..
	"sCpbFDsnJsNF4LYg/AgaQrsplFfu9P1TEu24FroySs7OgU1S93eA9yUMoAymttV0PMMTTTGmRBIm0ZxIsCmLQa0nb7qo+ZF2hbd1" ..
	"C4AGLKeW+PZedoOTCkW3u8ez7ZPWuKPBrNk02bc3Ps9zDHWKqJcOV/sccXB2+U/NwmRxehipa9s6bTXrw6pCkT77JvsHE3zIiZHd" ..
	"qNTdCIlU8FJ7oIqKkfyUpvl3b7r17MrbleqYwmbg/Vl7GW2mjMMPZOEAbSZzlcDKkJHrgC0edVCmUmpNa9FmGbIOPmP+VyfbU2hu" ..
	"0K/d+ehdq+77K17/T8OhHcj7zSWePdJduMZ/sOvzX9p3XulYXBqDdl6fk6JJBx/58CcoQodLB9/R0vr8J9JG/CtGvUAiMlPJ956n" ..
	"RV/f0CR2IZ4o2ZqP2+RAibhC8sN69zQ2tZBaSMKXEvam+dtv0x7y2uYTXAqixEgDUuGTu/SgyNo2wEtTBsi32NWDNfcD2FL5LkeB" ..
	"+yiy/mqwG0ClpL06M3y4gcQV2vTMw/CZl5D/0KfhHTJeXAFrJMhmGuiPWPuBK/52RfBZ8zhnTbId0RAq4PbZzxjnxnGUHvd7pqZK" ..
	"qdkt4ftNftdIs5lu6SaoHXPy+q6B9KM+GdayuYhwhpQBHKpA2URi/8QO2f2TtOEgfv1giLPVVhZ8MSkytxXNjd+trg2PbvZNb1Cu" ..
	"ixVn1BqfVnUzwBs7uNuc7XboNLg1MtEaHlaKysyMdzE0lS2sFb9fBSqhyDKKlMHbVeNgu6x/02LDZZMQYGS5wpP78ilgjNRYmCZF" ..
	"AEFmDTpP/5EIDK17BAX3lLmWp8L+0tUg7aiJoJKvc3EI7GJMvYQs4DWdJUYgxO0FYTuWzRziEuDVDBcqO8KjzKuG/9vFjeZ5r1Gk" ..
	"LfDEN6KgTkDQabSJWLssQtdzGtZiqt8f54liUnX6T0AmdYTEQjzCKRJDQoovQcXd+/SjW2n/PpflQSGLHcNTSA4cPis5Rhovp38Y" ..
	"jXO8zRD2c5LVXIJQWPd+JWUA60RwaFGh8/5QX1HX3BN8tsdcX2XTHFbtxsgLcGfqGItqeQkHp3/PG69Evafk/Gl3UEuYS1Jm9Lox" ..
	"9Hk0lMwIKTONL2W2T3NKQTMiZTh0fo1NSZhw+r/sToa/ypVWqPkJEmqy63LZ73Su5svwNUhIkl+ILcy0KA7ze8chKUoMQqgzSuT/" ..
	"ag28hQKnO/PY+ZT/Cgvi9ktGZYc3HqmSx+xangNDFJwHhF3ebFS1gGqMQ6OR0rIVpE9eo2+tuv1Q/XyhYG6Mk4Y5KEtNK0fA/kVg" ..
	"kXzkWq2KgoAiQ9b1XVVWlhXmg8schhhsKx791pw2CzarGIjg73TO3Tmbd5rH3B908PPPNFbMg/kPiKgvZPPOQg/mjmvPoT/aLCMK" ..
	"faXYf3N2ePsc9ClfMbKjqx6N3gZQHht2NJK+niM47HP9DHal/cMx0vgBkvWpCs/GynndjauJWxe3xU/bFuJr4aAoS2PWtIsSoP5l" ..
	"Ad8avmP7qsc7NR+n2Qai3A1p6I7/aNXZE6YO0jRrHpAOkOQQxSSLZ+klY2y+VmcSc43E7EUoF2nK9RIcHBrcrnWlOk/ojmREt4rx" ..
	""
local PAYLOAD_P6 =
	"KaNgL3gqaNlqkvFzwjqA/s1vV3b/A7E+fHbwvgil3Dd5qvxsele4tbtD5lIN+6Sp1ops+5BQZBZYSreyv0St8lDLE2r1cMEGIoHq" ..
	"KLbzqTLFvDH9AsQujpmK3O0T2ZsL2pBdnt4EB/zlHENHmu7crvTZkxHFSQocbhcNfpoOpdZHRD6D9HmjBFZZH65WcqUkouYG4Oxd" ..
	"eHGkqdetnnjBftL87g0F01wbZav3AuX4asJg6qcz5wVW2KLDV/alUgzLf5oWqhPvl9ra/SXKu/Mtb6BXTreJcO+nRd10BfXM2cwR" ..
	"XbJU/f2DU1yQue430HBRYXuBmU6kSoNWSbJYfnrL2ccO/Qqj7FzZQqpcuQBABvnMwfPFn7hy8yVkjVUauzOcLulvR4M6jWNAWEIg" ..
	"Gf3Fsg5aPFAmqGn7/LM19fJohZ13tAKkNAaCR+hsDzqbVFoC8QyKitpu+iCeEZkUZIiXEV8S9QV78/h8BIaZMp862zyNJnV2yhBJ" ..
	"HBpRENHTjc1lXsaXvdW0CsR29Rse9cPxBe1HGgDkYsQQffvVQ06wGdar1xnPBWYuKO/ZAjMlpNNKQmW67z6QYR/u2rp8HkfsBzBP" ..
	"gI8Bii/+T4Z4pzdx8cP0ca/cc8M2wYmNMmEtR6RX2qhWfS3CitrLGEh2xRTVzB5/ziqdSt6uWaU0jcCInM4VMzIUWHF70pCCn5/h" ..
	"wI42i2lS2JFXM5b2aUQv5S+NIRVxOX5pWPvf0F/RfJt6P2NPSjnerDT983lC9/ZJF4DVDpgp6YDgxhOwd4JT0DcmuB6FH2DvJPzT" ..
	"1l4h9VNEOYjzrSBZk2QzKxylQXtmGtijIc08lUy7qPpyH05ZcXukMcg3cxX3JUXp4Fw2ikCvRycdfj58+pxf7V0ddXI6hikbMFCS" ..
	"ciBUZNRVjnKuF2BUhXcvRga6dltopEXoxZZlfzl8qmgLc4MWju6udNXbvpHZTQFlZPcm8FbOWnXtITRJkiapmfC9LvbFkbKAzc38" ..
	"iVeZRxWA07C0+QYOHiiWy4YlhyHpzfMOl0QT1Xskmg+rEQmVAHKukTswj/m2pJrq3kg7cZqKsGE6eZc5asFeyZE5wZUBnSQGKM43" ..
	"bFjU/wZiGtsQuol/F0xpTY0WElkVLvuk/Y3IrYNFwvGiKDScr+XgAVC1QkfOAJmtIn7H+/MjbF7WQv5kFm5IJllZJDZSalMiVZ5m" ..
	"CNDLMCAF5xHP1d6XNRluVZEFDzlim1HrLhK4G2GReGnEDn/s45Ez/1ZE/zlihkvdDVe5/s2wTIKZrPgxLgIGrzSXEXXe/qUgm8zr" ..
	"BbgiC4rOPyS1QT50qhKv8LEBDIbddu016Jzr2RSfBuBpdOs4mG/3D6bwzs3LnK2IfrgnTetwz72z0UUlm4H6E1Fy8djXvfmnUZ9D" ..
	"5Yadr7D4+0n6NF+5x37f27jmvI9KGfa2aCYW7Ha9G5epKXdC5Ry1te3FmPsN1PVxK0w6nJPMSwoj0SwHDR9RTKmfoekdz30ph9n3" ..
	"c/zJaIa0CUcZVIkWD8J5w5NwMmcmL4kGtADodCD7lXeusYlMziTGrOfamnzmIBQScuVAVobiNqkIgOmRrmLEmlWudzGeQy95y2lc" ..
	"x7OFkDO2jJjzx4OVO7+IXJxoN3TKT74Mx12mTvUR1QT7QWnmfZEBga7ej1S3nZ5np3CxSvlyi1DBHQQVXc9uptJ8ePed7eT2LVTb" ..
	"NOJOXNI6OHhpQ5A1UtL2zn2X4W1nISWbFjUHu016LfHnVFLX7JsHDOLl3g8bn67JqFIsKDfhqnCqHJ7Vh03stwCMB8YlEeXQqkVz" ..
	"WuVkjMlEd6T2nytoZeiaQkAQpXMn7DPyOQzJq8WPqddgZglDOoDY1j6V9HOVGz7a6JTkycvRzSP7vntRUEbwAIvYOzsY6khJoMph" ..
	"/MTu1gODkkay+yMmrO2m7RjmA+iq/ZTc5/xvEtc5iWSx+efkZalAybMPzOu+LZ0cLGAT9GN7whWvNW5JZF/6e9RZ8izfF7pidxTP" ..
	"XIrqwlMUfEdvM3G4BUhHFsCDHxM0hE2K11s5opMVCy+/eGqZ1Y9B4h5eRlSjkwnfETe0JvucTGQSorOHL0JMYsiOa4n2ec5EzAR4" ..
	"eeNkfG1ixqeEzi4YAouI+EK7rbyKMkclOr+RelcVAshZDE9od5qlbusFp8nQkYCf/urlh7bimkb+eOhgPGzmMk48BtDSaPtq0pjM" ..
	"ycgEzjKa3ukBFioDRI363QexPHGR5I5YKOHY+up+m0WVYj6UHQGsJLzjS5GSXO7AR6VNaRLrvH+FtcSa4M9n2qjy2fFaCGygiJMA" ..
	"fjzPPgstRjxW22FQHNkJHBv6Qj5v8/vXKlIkIE5l4TbbU4q9Ehtv1+2bgNGg7hTNVeGm///6HoC8mijDDDN2MzLkWe1yUT1BjjS6" ..
	"TtoOe6fo4fYgxPhSaR4XRxhdRcTn1InmCungMEt1h0Knl6Lg9s0Nizh4APCtMnSmAu4L+3KinanyoFAYhcTf8tZBocPA+VY8Ci6T" ..
	"FQHm2NlOdqcMetg9n0Ng2d6LjMWtohvWbTUx2KUlPDUZNKCNQv1W4mj4yvwdXfJHMdW9oRM+Ec4DyxBSjpd3oqYXnaCaLizlR80w" ..
	"6E6WNpjZx+JY7W09YZxlVeB7FA84mgxRtsQQOqjGI0CuZNbYZ6NUteMTH4sEPm5LOGbaWImSOB4aJ0VgCdK8YS0eoFCqosydS23n" ..
	"z6e1n/DJ7y8kJoSmvWBNq1ehtDJA5hyyG9kpZAfuXC5cIrdPuygwWjXXFBb+eygcR/JlmojrbSk39zaxF7kj7uaSlKoHmqHiROm2" ..
	"U7B0kis4sM+dOP3CsW6hpwnP4OMBJOE2KLTjFV1GvAw3wdfg51uBVT0RS/qSsBAHiBH5D3VSuLEm5fGsLiFxhT14newJmho57AAJ" ..
	"evq7J37rOxUL/aVPDE4ctmQnrYZCdbX9TRbvWWftqe1CVhcjnNT3cyy/rUz4SssEsH0eW+OPSpu4XmANPOUczO14NTyGu3b/r1e9" ..
	"TIc8WqIkjNMnhpVX+22tbERbnmwBYHHJSGwibOuxTrt2SqIcAEvwD3rxUYJw8yddcxM+mjk4JplSbvchXqxJtqnbSAeoU9JDzwfa" ..
	"uPWtgnz3RGOqBESzWm/Jh5OXAOEhdoPVN1Z3g/H1JqCjgGhwuQ7adRawaU2SuoLX6Afc8OIKiFijKGSt+r+2yzWsRw9jsRFniUtZ" ..
	"vYxyX8lDYIaIPch3+P43XDAFkfmxRvfSxf368kG7DPV84ocm16mWtaNx5avl9yeB+Zsihn5aICEBpFhAUs4azyx6dhmhNhQiMGs/" ..
	"jOiLB5MloNCgwqHLgdHkdn1VVsFHWlDYE+ufxoh6vTShSIrRIltZXZ5fP3/H+0BFM+Lxu0Y/JnGqwFGrO09f2WAPA+Lc5GBeQ+2I" ..
	"kQ1TOuu6tExN0vsRG1tHUVogpj2Ut6eCn6ifylc2xGUhwnONQOMrNeCL/Dd4Y1+oQUQQEnftip/ZtJnw7zE9ZJ+5A2NQbeqYs4SS" ..
	"IY+NBev/AWx2x5USqkcW/RmhXPRfbMaPokygqylHOgtgnMY0cmFNQrMyRilL+tICuhmiUcMQZ3KXf0SBCN/gU/18TsK6lqMYHsGo" ..
	"ObYvvnrM90jVJpVC6Qybn6rt31TJnRTzI29q8SR12JtA8A33bgTL39giy5tm02W1+rXQKvPPKjdVnH9PQsgIWMQpY8T5lNCkf8sT" ..
	"fgsLIALXO6yn+yZ0j9Qwi+4Nqu2qQowlV84FeagoLenWlqiDf02+Szgc9tvsGfF5lUUe2CHw6dsUurN3kag1wiY0076yD6V6zGzw" ..
	"Iv7slr2vq4SCJy96ZG5q8J0vhUl4APnCDOqnvglSnJyqApkW6v9nO0FEvIQMfE6barbzTNV9Cbat2GRgIyW0zoEMy8A0Z+0Ah7mA" ..
	"kQ8Ud3TNopAtQyKfvQ4u59evNSig8SXfFj9mZ73fCsJPeeUwAlR6OEcLchXfzbjkSyZLbdc2caCeNPztdYPbS7D+aOm4rd1Zx5x5" ..
	"trKr41T/0VDEG6HoiTXoxG1MZIa324Jhl9oPJAmhDZeBjoo4LS+4F+fhJGNnT8Kq2EZEAm80UOY6g14IrJQH8TzVRiwALnc0qQon" ..
	"Zq3rgiXpoevkuGTlyJCLQy9Wb15GHNtkM+XBiq5ZkHHaNS/xHO9kbS++ztxyaQkSYdsWkpQCpMen/FgtpSRKJSZpD7BfFC1Hzqam" ..
	"xoJ0g/iusnvl3JrAn2eD9mKdDifd6qbEA+58FRqsJyP2K+RYFBORgAxA2uh57nG8kNg7oj7QjQ0/tshBAXlsEdUTvqemiEVtf2w+" ..
	"S/rO44TZqjozC/fqCMmx96g/HiXr713ZE0AYeAs3W9wphWvD6L3AYOVdJxOilCMXdfqhn/6OHuUbA6U/LEMVnqxueVgvmAMPupkM" ..
	"tyL48Y5tnZj+aY8m9TzSkdPSRjOyGuAglKueiuqNKxMxL0Y/10dxAY0Zlc/Sf3hw6T1tMmxrmt+dG8FbKNpsVRHYUruiVYlLVKdg" ..
	"cJYjpehlST34zazLF5i1tO79+DWwOgkR/icLK7OxWBHXY0qxEbs0gAig3XYRuvLK6Rff+hJdwCrk/rtBnVEz6R69MgI4KbW5sSev" ..
	"jLieSuC107ydRk2q7QotDgXOyo0eNSKG/Gg+YN8K4YmPQrXVz7lsdDL77MuHdXTgIwtUqZhraQKJGoIeMxjV3wGzYZI7dNkbiLK1" ..
	"quYtZcc6ZUo8dXSBfgyK0c7koNMauiK6VSqJ/oz40KUd3V0ALl6irCI+WMaKEKa4RQOYag8zkGXQVjJeedPW9B6zTcUJYfOIoZWL" ..
	"KmrMsMukV6NlxSupAfwO4SxnfXV6qU1M9I0GPOsE8snI/+tah6itIyYbq8UyRSR0mYiq1TDTvbCBzViEGh3PGoA3ZrK2uPyFaq7B" ..
	"whdkRjtDSAFI1arySYRztiNTZhL2BogWuZE1B8GUruEQjaMSYNYCmBYH4H4W8f4C+wF4NzJjDgUZV9o5uEhbcf01WKzxrgK9DRDF" ..
	"SHA39cyfMpnzemD1pkjEFhLdvPdIb/QYmWqsmV4hZnZwq+SP5yi9WqpmB7GNxjehAIwwvVAT6FCjPTGJMf9jBbvEsCc1953AbH9+" ..
	"prxQQqAmvIdRr3CI/CMrgHapX8fe7I4a4y89DmsxdVfMbH9KwppVgvzUJHd8Npx8r+CzDkNmZaR1DqGat5ocA/DAoItBAuhINvow" ..
	"2R0daA0OIyzyVIJgXk/CRBHA8ZTOJzMx8Nt8zIfGoKmxWGRVjLUqFvsn8kgAfm662KgbbWLwW6TNXtKPTlr0ohQxulale0TJgQIs" ..
	"RfpFvS7eP1BqIkV++nsHAd33+NN4k10TLn4S5yUEmoB83UH5qQLLhQuo9d7HoaWZbsC01RfRKevxtf6YYEhixWKotDfErc7eA2p9" ..
	"IV2kUL8zS/Zrk1puivLIbsvHskPuczYIAiMFRrYmeeNv0Q+D8DkBr9/+znqfEKLCqytj9jWVDnQa/8wzqfUcu8FOwCVZla/1D7pQ" ..
	"2GFDjjE5TkhEywFDlctoQ4r0ggf6nrP6qRjevsfhlfGHSaBF82a2Hcjjr3jLuyCx3l5PDgm892KNhviQNMDOzVz4g95XhzGYFE+q" ..
	"ecsodZUO+0vwswj/VbVdoeJ5sXQR2mLZTbRceNFaUSq5w+RhYOHApS7chUFzqdsqQgW62InNtUhVTayEy6ASr8LS7sTpN2FWggLd" ..
	"9PmM/nWn1NsfFU+XG4uhnKsyRVzPEROcWkIiUbO1/yyCRMZE+mkYs6nn6d3qub4nEFmVQc923yJgEPCimdcXdgaDtn74f6Daa5Kn" ..
	"M0o1yet1NNe8lrcrBQDmWp/1w5mIjUZkHL/bC8F/umxXv2A2+CIRo7kU2gwKE8RNoRAWatDTNXYyufM1ZqyfmU/HCyQDOBLqwqxb" ..
	"aS/vwCjdMiFQTMN3svAThPi2qQ7LznkUKGy+F9eUkidJxEZfKWT/q0tPAnHsjx5Tq2gvrCT0B1fvW25Sts2oUv9eQyR2T+RHeoTA" ..
	""
local PAYLOAD_P7 =
	"8KL6tx4ByoRK5fsnNmZISQTrfaDWw4LAUyEn4lto7q+FA6DH5rwEcIGCpf+U85WSq13SnXZsT393GI7RAKtVIUnly3j8lV0b8Wat" ..
	"xW75BqnQW+cv7HLigBGr8IOJkZ97/6jkFtiJTaQ+RcsJgA+Ll0hKxv9J5XEqmXP5xmzg/CYns89oI/lE92KOP71X0iXPcZpxoxPF" ..
	"F3+gcYGvCT1gSZLJvzh478Nd5ouhFasy6VT7aV0cY2R2lgvDZrW/FR4rMpcXtaNZ5Sk/ZINymO/Tk5VgkYMk/rJbtqS6niGKqY5A" ..
	"OCUC0wtGf0brz+t9dtIKGvkh94lAZ3fKkx7URTQg9rbYJA6yKAmRGOweHSnM7Bo+RnmZ90EkR6WPMChZ1H205BQIx8f37h6Il9za" ..
	"83ht8cYqLCnqMO/LGxCEaZWqEcPeulZzSGBTckxhs6tQ6fc/B0U2U9LpnN8TiLljrreXaQXF4VVb2IxwsrbMwoQ/0IZl+v3GOQ/i" ..
	"/rm/m3NTfHoyjSvp7t/0+yjuQG3dWAS5c3qm+ONsd+sH0dwVMMNiBXBrtXbbAZ/GCyCYGw8cU2i/2jtHLxWmC54Jrf5+KTE4Dikq" ..
	"wg/1cHFTpHcVMxHLO0daNrsdy9MiTp98szVvqqZIuoFwfbTiX1vB+5TbgGEe/2hcBScJXGJi+wGYBXsDFV+E8iW/uAwsQ1MWMYZY" ..
	"SOQ9giLFPVlffhiaBLQhua+I8YrJD561BgFwIU83iMDttM8stV2I+LhvQDSuMGFE1Ok9sbr34dX9w5deoQCZEjGCjqSyy1YQlfst" ..
	"S9BvcLC1lqdNplRU8LRxfFNia8x11dc1CEVe7WvkWOtWhrJks+Rqrv/XXCdlj1vuL1DS1xV5hDBXzBkgV+8rExQUOa0iQXo+bHeY" ..
	"EDXZDLiq6VwNakJgeRuCyTCF+3TeUfBrVOlfmo6KRxFzNB13GpC/BO/XFMPN+HdEx+Ih0i8gNfP9uL2PPAGqZG5XOIrhtrAyQXdf" ..
	"wlFaJG97g0PZRrzta3ZOqV21KiT1WqPtGmC9ghg+Y8uAEVFJktFtjUMzvyERAHGVUdOWwUcvcBQux9s8O+BfymFhujauSWZY0mL8" ..
	"MYvMwaNGMwAUQjxNICA3ytnRYN34hajT/WXcCbaosY7hjiZO95W70P+4SK8vivJ9a11cQMPEwj/gqXBBzglseqXA5YeV29SB4ukz" ..
	"o4RunX4ZwvuIEXf1LIidGIRHrsXGGCU9YKlpdXua1jXAlka4uA8g6f+LwWeT6XdWLtoDSSHKkWeXEDM6iwUir1OpI7BlDJEMOs0v" ..
	"0X/8MlkuTzPe4jzvnQzQEOPXu2FkHHn8+KMqweFD2ITmYl5DN9eho6zdgLsUwOzMjCu5J6LicS5gct/jV3gfEyGZgBQ82yBsAvqs" ..
	"jr1BPxU6hUHl9HET16pmTYv2yo0GYj8wK34i7pjApZ92cyAIxqCkGspQ4YMKB7Lax62wfXY5uEwO0nQ5RCp5iriwp8XzuYjNl1pG" ..
	"+Fm8SBrFIypRAbSe08qvxwDUIl/Dnf7jovLhCuM5ddccz/fz1uc2nLuvlomYeHDWR2kSaGWwdfOCK9YGQFxVrqLEpDnj7yNjsYO2" ..
	"UBI3k5ewxqfN1+JGD13YBfifpmfwtT7S+kiEg7zRQAWPTi56Ck/Yohg3YDVnlkELoYIjgvIaeyA5Xc35SXLauoBeZ3Qv0jWKwbKm" ..
	"MIVZ2xY03AsBHyASSb0QHO4orlPqUXRaLSDms9evQ+7BVTDRVFhHoGPc+WsoxliW+2roTDGs5z4nIU5cmv7YBNamy6mvmnFEwm/j" ..
	"Pxf5Gspr2V54qAsGwWMT0eKVRIX1Zx27AjRh8kMnH4ByN13T0pQGbY5ub9S51krB8TtzLhUBnbvu00ww5ampsISppsAJTYJ4aA/r" ..
	"71sRb2VdHNW0dEi2Bzahg0RegcPLNKUHgNiPjPZCO3sFA6bcFIAr5693ifSUpXB8ZISipO2xwDozGdKkCWHCcbPGOSOQ+e9S81Uv" ..
	"W3DPtLHiZOoQ9U1/YknKavfv8FWAXayydmp+3atgpTXN6Xr7McmY6wVEYt6wRsdebAYbu6KhmWxUHbEfSpNMdyd03vmZ0tl7OBli" ..
	"CUK5k4eOWDyBoUDgkgu2rYEFZexGy8YxCRgvxzUb7KHt16WgerZNJFFvmTXMHymoAZWdf6nGBXgFEVS95oHQsmxHBF2hEbXLT1V7" ..
	"OY09T+HTCJFgP0Rg4HLsY96nQJazzghK+T8dSMVJCFmq5AU8OpR5y6wEdCDAIUexZvaaWm4GcTToCOZx1+XCXTeG4sY64lEM6YEn" ..
	"6n1QyPT4oaWH5gWNltxGhepgZS1Nn43ER4XoTYSOww6L0ic5C2GoWKXMgK/JDIVdnEea5JADLN+LJfdO4tD/QrghDx/m4VpWBTml" ..
	"gh8uH+kmh6pba/SuWwBhDrNUxNeJyvJzeo7B0eJElbUadHY6sytXQqH7Js9OAufkTY3jhiBmx+7ejxGb1NhjFWxDaSXh54KOwSFd" ..
	"qO49MB9J0KlUkK394PjVttIRa4Oe76yoUYc01P6xGtV1vvwBg9geQohWAnxuZkcOJJQ3N60zKW+gX62nUG0cvWBjQsgwDGOhMalm" ..
	"6DcC1n5nOyrL2ew2qbLdvPc+0qMtxqBOrCSRRc7FfAd+G6nYlonhB+38Ud05WRKMLrdL2dfhnfxg2hJW0OiXuFX0UgB/tExuBroB" ..
	"e4NhH9UfcRrWHpqJvhbXyw7gjk+oBqoR+P5VGb4qY56YFOI8STKmUCN+kb8pwEFrd5FOAqg7hk3VRo0iCfs7NWSSyg5chChZIoy3" ..
	"gKE6ZhIuP4P1HRa3CyU0YR0VZeXZ2t1yOUlR2fLehBoZTRa/oBmm9IQ0u6IInFS9R8zHZTDc35I/ut3uPdbPcekeBgYjnKKQJOLw" ..
	"04/Nz+FDMU4Jf/5OtVeZL6BIAP65Nlv0ZY31qcs+vM90k7RjpHxG/hLrew4c9693vdsrsPaT4Cm+NWWfSN3fiHWp6BFHtj7k/5mh" ..
	"0VocSmenA7RTpu40RY1g6aDYOQszLYpdr06T8etiWfN5t74seBYmJ8JFQ2M05SUnsGjkeLF7GvOEcp4JHA2lY2pB8xJlZgFgpvDw" ..
	"xc6GutvctwVSrnERPaOvAqcrUDY4qUpJlWi1AfOJC5qFvps/CkN5bH6a3/B7Nc9DZBzt9knpz7HkusVT3SUIDHBFSQw5HZAEalS2" ..
	"Fezl8VYzhasdc524Db6zej+NyVht9mX6IuJksTV1Zo66nZaAVGGLs+ayfs1GO+vc0bq2d37//lvVj5sTU1boPBuEjZ/RYG2OLjZE" ..
	"6+g0PXlqvh68PcE7FyfPEs77Um9NxkntN2jkPNVVQknmKYy/wKgWDDLxs3PKwnXs43QyfMW7kDUqLamilxWeXOspyRy+bXiDYhyG" ..
	"iW+uOX+PJT8oSFIm88mUB+x3AqFv9ag3FHFEDXrnBAsMEarTcQh2NK3kgciQEntJUl4wbRSAv3pQxLyyYhkMBvBP/K8LDjohZ2fr" ..
	"WW/7y5fjOmWgg/GK4H2tH86akDKmsDdlDtLajuSCgjU/k+BONFo9IxH4kh5U0iDZy6jMRMqBv9eTXWWSy54/o1IWzF6uHifRTgia" ..
	"npY1VRG5kN9tdcyzhrQyONZiQ01ah1mV48kd3VZ+Zy2QkS1PXJLJtKzU58yRIvo3WGeAfPu1eZZqnil6XJ3Wr5QI6xTERTP5vr2H" ..
	"6c8yz0+i61CKPvXJBTzERgQVffpSbg5U5CmP0eadd9Mh9ZE5n31oR1iNytnsEXK3K08U/1R6V/JR9JSEx1BJVpFJf4i0qRsW5B+a" ..
	"5EYAASECd5E/KkCucFpG/4RKiEq3re2WkItQ2uf+1NeWfMRWf5rsWf/TsTP5mI7gW2EOvpEdo9u+Jqc4WzJ4O/Q3bpT9P4eedl5A" ..
	"tc6mk1hOW0e/dK0mfaQ2u/Bl2wQ3I5jbv64RpohuN7EeQxQHkCZSur/sfqMkOmQEJGWVHKOsqUysVGRR0CzVSVzlhgvTRpLL6P+z" ..
	"z7w8YTnNuinhBiLudG2MslA7w/SqQUl5lhm8Gert+IZcWQppTFz3XMYxAffeNPTkBL5wwLO9Hm8bYyJ5FMGjNb7KbQq6LhXncbOf" ..
	"TcepvnMtzcnvRZy9Ca3LWUDjLF0ihe8IErZBWDAUfM1M0/X/nD3NtMoiQohrPMEQVgtvUdKJXDlpDsqP/OQaLz3mZXTIPWsBHSHm" ..
	"hr6KOUlndgYg3J3KpcuyRFYg0xbMJ7Hgizj1YFlgjuZcsMuckvoG7ydokDMTaEOtbSu/mTt+cLgLur5WefTNjHhx9QcOrOmgpPM3" ..
	"5F5yCffENakog3GYVKnY301eRI5ZAE5h4uppgWYkDmfguTEjwVUegM9zKqyzqvK9oSQobG5OQysF4DSlGrInEudoo9u5WFJfDmYK" ..
	"YXlpLSbMvqF5FF86ekk48XoNxt5ASBamtcx9XkrJpwIlBsLuUzzobGhd9Ukzpptiut9ge/ULOjpM8d/V9LzNai+81yVspo8ycxwb" ..
	"0BOyjapSjsiU7fC2LJ87xOH1a229qTP45uprYWf0K3AQPjyucXK36Gvtv37f53eCKqxJl8+HmPgg38CyslYbsy0UK+Yuu8L8iZNK" ..
	"2Ux24k+BG0KSJ4kQ1FTQyqL0qkwH6MJEajlkh4oxEhpVGTmN8tmoT2vX8WZxjZDqWGmSTDln8T3as6E9Z7C+HX6MZssp+oPMxdD1" ..
	"oBNNvJZh9AWvrkkNOqWBhvmYRCnlFaHQPO8c+9bvlSDemQkBiZfrXZOyi0D4obo+RJRY3R2igPWsDjlwapsgF8icQNdNaP9Af0hs" ..
	"ytKAD3SkhN6Hn84qP3CisDYxB3ZjkH9BHPT8d4WXSNYx9rIk71O8gmyXnquzFn5evd0A1ytUwS+OpzdhLBYFGygZD7YN4RW2nHGg" ..
	"2cFb42WhgwiKTFdts/3SsFFYScde0z5G8dlVyK8tc2MYeqYezbvTeJUWvHvOyPrvEinqT28D95SA0YLvl4iYlDx1H/NelgHA1PsT" ..
	"PZUSGMA5oljbmU+2fIDoPHURkXBmkcTBvUOeUObefyS5HYBVnteNT8s224PiJGf+GCdTvctHHps3e7VSaOHAxvl9UoMiFgbUHT3y" ..
	"GkOLM/4ZeFKagHn4xov62o6js9gZVkM8rev8iiONZ2pjC3v+HhA4DeyJDIS116gByo5/r85V85avRERpg+Lq9cUES13sl0i760DW" ..
	"X8TInf0oWeYIgKEw63HoNuHrSuegUHJQz96HGVaRqWNfFudKKBKxSWsw5vuExDvmK4RQfLnJulvroDM5bArOaGrYXjgUxtKmprkj" ..
	"tFkzVhx/aOV5KiwY7PovQxv5cNtQ0ZLJXDTpQFjyualAo7yBrWvCBiEQMDCYXsVJtP6HflFgKEjdYzkQTYr5M9Mj5qXbfO5z/A48" ..
	"a4mX8qCzaDMJx+MQhZTcrniV+BGGTUlKZkpxvP/nay0x3MtiE+Ee3u1eeQXLiWRh7KSkUF79F24WqJv6R80FFsmLgE9tgeznVnl5" ..
	"7FO7WJqwXtdeKCHm68LO26hbKKMFUlrtIRzD6zyWifMkKYpPNAuFptVFL7ojZZR2MYqIjErSZPthemITZTPnVxQQ0zU5NotJXugq" ..
	"7aGrv+Y1MwzogAUa80a+NuaRrNZyYvDDBjt61jVNrxAP4uOZlT225xiJZAGmV4fdkmO9O5WVCgxRBKktR+a7KPeGclfj0FdBrias" ..
	"tFP23KaGCpMfz7O3bLTmzd/VGTjOC0B55HAtnsSiMrE6oPvKU/ZFW4QYrwUWHRpMN5X8mXAp1XrxYn7rn1yrC8PwhbG0GixlvqJj" ..
	"CoNf+4Fcs/oqRwPcU/8g3On3PF0NLAp2yztgzrDk0ey5WPDp6AVJZUV7gPn2lWxRGQemp66A58MIBOCgrtwNDmLezvQHGRYTFCYY" ..
	"1H5jIOHF6JSi5i7EpCk4wglJL06lq0f9DGB6Akd6/DJIEiwG868vOdkpcDgob8Bd5+dM4M8igraRFw7hDNuy2jc9kbaenS49uZXM" ..
	""
local PAYLOAD_P8 =
	"xy5GpRkmleiB175cjodzncJOC9YP4qUtC5JvY2oH9Pcg/pWjJsaGSPvIfZCBp2BL2oBo7Wc9b2PL6QXmCDkTzwmrc65BhbXpZfQf" ..
	"PQoVRBsMlruEOFVjtlgzPea5RsPs7JjIFzoYuED8ZYHxzDxZ59D/D2O/DeXsu3kc9aS+AUz9egpOcrzyrR7igxA7P79a48xDbmuu" ..
	"RYCMiYWzC4GRRRQ6S5OfctuTrvnt5fcGVxLoR3aG5XxHNxkkbDOlbkViDZrMb8Cx069oET/BQEwklKAE9Aeelbi+NZFuLWOZpTG1" ..
	"aOzVWHhyulvpJlKkG3CuRSIKjWyFnddonnEFdlagp/PP6jc1BUTBUn1oaicY3QfoqA0zLpleJvYhArO5qmTbgydvkd/Hlf6n8XfO" ..
	"PW9VVnRjzSyoLvYvJ+AOFrJ6KsYnkNlo1Z6UCD+x2fHx+ZTrlJPrhJZld2v3ek2yE2+vOqSNPmhwHS88J2G9W/y6XE598QG7sxEA" ..
	"bsg+09j06PpYn8CSozSThkGinJkvALdH5nvW1IC32+R9eFa7eG6PKQkpfI37VWZnT/rhvS1lY0rZ+Ql49ayJMyQ/+tx+QUriBc0Q" ..
	"EVtlRvoO5wvE2ibbbD6wzBlVV8ywycjShI6ydgw4dTDa2qhuvMFFyEqw4v8ag3rkZ1V64BTu5BePCGtUHXeWWW90/QqD7L3f4Tr9" ..
	"ZJIufcUe0Xh1iJrGXcIH0v9rKFw5uTc7Hkm2nsEDK3TpL5BEy6Mb7YG6JW4Eza63C9fxSAEBfXzxqrALkV9EOXfPnUzvrm12Rgfl" ..
	"QoFdFLu77BSPAy92qkgJpyvvvwXXIEbXTO2/sJvbEvZ+6JKQUh+fd5VLyZU1x0U8ZyMc61mHwDReMiNZ6m8GZb2PAIHxqQx7zZ37" ..
	"hp9qHc6BGcpSDAMLtfdI0K0iEf8qatsPAs6FOFNLM4yUCrplrvB2TpZwYXsuLcRb0mHjSAwt5LJ4zwLjC7aTHuid4sangLc8sMeX" ..
	"YgRH7K+bni7s5yp+bofmHhP8sAT1d3xP0/5ngjNB0jICEbF2zcjpTqekPjqZZcJKxdwqcBhOI7fn03Qgg9rCpViGt9hy2ph4sQmT" ..
	"OPnpAX1/ivSNAo6xjMfqSVZzLmiXiy+7LNJ0Y6er8uVv1S5rg59ljUcrPckC/KzHUkYsBVFyakmRbDnKUH/uEyC0p+nBNvIBWSm1" ..
	"CdPjAc/DEko2szt3vMYRA3ih7DXG3/Ae1ZTTOG6izCOcoMh4nBc1IcZbLvZzfv5ZAtqvGA6KBFwIjZyIOMS8YU0DI9EZc1bWlZ8F" ..
	"USvbdpy+/A9L4K+wW/XzWlOrc9apLlLaSWmCi0kNNDUKBX1dG7OyodHfHQbA9/aE9/3xm6VCUDRj6TcwtJHvB0Z0mZWfYeLf54Yb" ..
	"dFBoEKNbQfUfgjI5SfMdguM+tWNlFnP0bVc6ULs3UWH93duGl8Wlkd/0ugiYXOqaJIphlXf/ca3m3yP9d/45YxXkVcdciD7Uw1BP" ..
	"BwrCe66KZqZVCcynHtPurC0j2wOQ+vKplAbCbQnxBFcpWyQgkW0c9efcPvBg8vvmXnf7vy9Tt0Zov0KdX5eCT6FDrMc/+4sddE8A" ..
	"bRDLhMjSDUBolVp/2IlKTEuJV2IjwNxYaRvFxgtRU7Ceq02soFrjFTfgQ3eINq1ZRMlso1EgXTdxjxt0XO4vIQ50BhPS04aKGEr+" ..
	"inbvdg+aOglFbTvemtbxZxaRKWS9znYo+s1aIY5HoCOyWffzCRqsvC3jK5F343x7QfDG8Xp1MFGDqL4jv+s7NhrAVe7DqGhcmCi+" ..
	"U1EoVrfG4njJvXC9UKX8fbczwuIFM8YEtigsi81K53OYF+8AA0ikFMRKM0kzBn51CbPW+OwdnJjtTn3X6cgOlh1gmWzy9rt0nksH" ..
	"7VEcdy/AsRLlEVHWXcwVO/sg50Vc0+v8l0C7sn6h6tMCcgT0Sid2wwyEMcrP9CDu4RfaqaQrp5vVpdApdbMWWfa+KWF9yyjw9fyX" ..
	"GSLZ7yue2aGytXtxmIEQXzhF1L9WcaYeOZuxwgBKgccYBXDMaNvnxTBlIK7dHElOzXPD5LLZkHb01CT6thpGPqSrAqcA/IdidEZ7" ..
	"wRcMxr5vJjs/QxVsTh/L5kGcrpsiMFfv/vnYELCjvi9rquDcA0b9TKp/SEiHqqSHjGmligkvRptRKr0bQlDqXZejz1MELb2xKvDd" ..
	"+WVHxe0Jj8T0/oc1Od61Yd4yOTaNYUFPcXA9jvRx1xisKueOwBXirjItxnWpWErSx5lfpICTTWzpW3kNNF83GZHxZluPkjNAvn1R" ..
	"3DvknWQ9eOaGl4BOQ1QK7DIypCf1La+hn9Bqlec/q++JdOSrdc0kUxdiwQ3u3KU9kxA6FnI05Jm8psBGvmRx30v/OI0a8dbbPipq" ..
	"N2H6UYagaiZiytLp0809bRqaT3vkLdmgHr7IQ5CGVUuVmSp0FsWHwviqcmeIkDbNDTD7zXtcGQZjqb7BAMdY+RPULs9qZHnqmUaC" ..
	"buerSAcztMri36twRPiq+4CtpEil/L3hmpO4mRLsek0UtgI2FefJjqpke4BAQxEzcoTBbGJzdwXvxIZm/vHYq8IqN8gxREFhzVIg" ..
	"AaV1MHpAl8w5UdgKtPc+eVJVzxarqm7jj5Wx44g9nX/pRbKxHjcwK7upJS6NImYcOd2pWzZx/nSRvK11mQR0uIqeKIMQ2SSIcP+C" ..
	"tH5VHziuPbiXy4vaaJhZwyKZtLnK/3SNPvkLa+mrTXJj5rZxYFhwGOxSxIPAlm5PDzbPGJDiTw/AF6Bwkn2LGuqGWBruG5/oscZ8" ..
	"ZMKtDWWJfutXKLeHwG4NIl61YakE9ULiEHd1O83GUs7kkOrRs1jPBkgTB492XOjATX674bSmC13vkags/4Z6wbE/HOIHQsGj192U" ..
	"RrfFtep7AeCkNnzerdRwHwVlvEI8iSZc5JJduH6ydpmjGea+HuRHDpZcbxhrAywB6xDeBxJZWS5/ckYSvgXih7OfhYIaJ/S2bHON" ..
	"L/4ZamQ9JaqGPusdKJhux7c5SyEd2NcKeKMgPsr7qvYimBb3IEY099NHR4RxDrv2R0qxvVfUHVPHM3cDDmwWhMHNTSlk2QuFA7kU" ..
	"StHf1CRxcfsQJcJk3emoXGmXBdZSWapMVc9GZ1os+HGcVXTlKeh3hzMC6S4llknm6pJ4vefP8jdPs8Ajkn+qYw3GkfgMC5UHiT3t" ..
	"pQrqhAfCrdLPIE6fYjOPBvw/zm+x/Xi/DhQ5I6LJ3vSCDInn03txCbXnAXDrnqTZT+xInuoi0Xg/y9a8OvdMnd3wDWIQw8DCxol9" ..
	"1C/Iycn6auqjMUQMcU/tI6JBuzIS1SlBHDD0IvHGk4EcQHnun7V4voCqhOdN4pDiQczwsLpB6jJkvT14eZZ0rvW5Ajfy1+NTcoEc" ..
	"cOkFOBH/XxGb6qEApoDCM+gkm8FlCTaiUVTHFEpONyZm+PgCj2rCvPGin4ZUZKDLGUtUFfsky2bn4IHpXOEtOlphHVqMp230gm4+" ..
	"/of4KOaZqq/6qIumxu0xSc0LsYpt5yLECsfCMaGlzpUckoRnuH836twP7Qs8JSZ7dqPg4McJFu+TsCL3Gwe1BlxJ5eU6gc02zkfa" ..
	"5/K9stbalgWco4VVBISdOGyydigE86iyhBuxygOe3xAHcHT10wx4T0ylyWPDNHQmFqN8vWrUSuTLcTOjSXbDIm23AvNXrs3PhZzi" ..
	"HO0k6Id3sIZZF/zMiATne8mBnR+V6ar8f2H842XynytSbYJKK0PNAf8RolbSKKIkHfK04Fl58jN0umUSOjXTid9xxCPdSKdBu32m" ..
	"16EdImZjDQouhoUTG/yNNdOO466aCN7+fvw6nMyb0HnaxxkYyjVSHAarLYYlF/+RBlSQ8csK6ynXmtikt8GnM4dBfWbm9ST2CdNg" ..
	"Yztd+UqkadYlkZE+7pm650xUYK3Bsqc/4OFN7xuPpUNIPmDE8KpIEtIvLe6wq0B00GPvrLUX7d/szeyYUFbdqfGxr/IOagN9RhI0" ..
	"PfbP/nP+SrPouxTasPlsL/YZzYsPBVgwgnCbfVA3OFCazR51wRwkLRnYNds4nuRFDhVDG5ZCO7UdtYM2Dz1AwS0qOA74wTImqfoH" ..
	"xSaODSOOQxUoLKMNxf+9QS5uafnRa3Sz7xmDJ4Ngtgdt4ks0NHboVXIdTGVGov0f6Y+6osiF6uvaNKGD7YcKTBAjRe5URrLIH9Kw" ..
	"pmZjYkM4HzryCZdsUS0seabJk4EYuOu1DkFKxR9NsYEfeyUd4gF7jEbUnRh7VwcRpUsGDAUVGrkr7JmqHIR7W0ImUk7WC3lBO71V" ..
	"cUWxope3VRyMpHFsN72zdd21rlVvqsvivtD131OqpiQUkFFcGKr9041hdGRXUsj4mulVe8IvQdhGI2b54VD54Wih+7myeeVBS+3Y" ..
	"mS8NZGu714TQg+APlGZ8jRoJFgALjIoR7jinjJbID5uAz9rpNkiVwmT3DLxIr+xzyjO6j60yN/z0Ktk8Sryxl6E+AHmR1ePSSoVt" ..
	"3gLWV9XR35qUzaQn6axOH9oQ47pL44iI95ppkSFub2tasvunN0TmT4ucG/KzdF2EOg1pI75wYw4LuUueyP0DICjYLUWB2ka+lppQ" ..
	"7VPtfy0MOMyxYK7Npva9DsAat7SPTQQcTsCJlows36LCEGaW2EzAy0fmfXf/i0FZUE6WG3yStg8amxfmVx5muMJvZnYPDMczssL0" ..
	"hRb5WknNhC2BswBsK9huxuuYdR/dX1kKJ0PLlHzrn+A9xKrNtY7YIc1ksUxsOCjTAlhnnc1j/ecbGwLFWw4ITXqPsVGjJCD1Cg0O" ..
	"/wPZmdWc/7Fv8LF2gVAKz9ZQ5ATf5xnjnVmM9ZlCMWnabZ3Juw9S6rcm7aN3imRf0SaCaQevPsGsKBbe8HnZcC8OJZpbz4ltEQR6" ..
	"Uar3mCIBUrHuiEWZIbI769/QDBl9Yy1geuG328RJUkGy9EL6pX0xq0IrfVUiYt9rtJd6quhmkL1x3UT3CGv0uaJ6VPDuVh7BSdhn" ..
	"ExQDRy3JaJtSAiiI48KC6Dj/p4zDiRC+TFaBAvxtSdTtYX5fzvYji9vTsKMloCEB4//WdU9ogZLxXjvfy2YNmXqtGkfz84uONF8h" ..
	"CUNHMrY4EXspvVR1tGQM+37pIsCd5yROfl4tyYqs35d+UjWAkAabqwFlFHJ0iPJIJ7mBgOzbQAsXIYcAZ3Wu+eKiMuk3hV060NED" ..
	"koxuRO5x6O4L7C1y6NExcwUjQqCHoeNWzqlSwRGT6ckklp+XC3gFxi/vNHe4WE9U+ERqwf3LdX0RbrkgrpvuHk8QR9DK0Yd7VmyP" ..
	"vx9DDgDcS6qm1PIRqQzcu+lAYbefEj8KaGNU+6VWzuA8ny7PYGIGYvqWa+JZ93ER89/lCg8odt1ETQxfZOaNUP0dgUiau4e9R2Km" ..
	"wsG6lFgE/DgG3GMB0bSQ6pMip4JbIdnH0uimwInMuZ8m//xYeDsyLWDMDTQsCX4no/kykiL1TzidXhZl4TUO8w4Igu377YwZQU7b" ..
	"gs4FdKkIl7QOX70hbEgQw07jf/a1Ucxv7UepahQS05FVCcAsBu96Oi6j2D7eaRlXTu4Cv+smL4k9T0MGqQUY/fMECke6zgUo0VpD" ..
	"FDJSWVHH9T8ZgXwtiLD2BcGqhiIB9CSgekRHRGDAyU9c3yYgd5VQ4hO+9Pw9wFUrQdds6ALzlTPJDsV+5t7iWhBjx7hvR7nNk1Ro" ..
	"VloLZzkAujh4tQ07j0fclW2VPayvlCHPUlBT4hlaGGhiHpZ7yUDPCh8eOXHKrGkLYsrlRZAOxOuT5wB+y8pFoiijuyJw6XKKAGu0" ..
	"9QI4FQksYDv7cwtOtnhwriJUxA8/gDLRdL02QbP3jrGKa+kCTEXRM6MONhdu2D7gz2NrsDLX1+MC48NJJPsLonJF9VyBv5zSfyML" ..
	"RdIK4V4vp+/kTIe7gaEp/rhqRMKFLJGB/dByUv0uHleZwGn895QIx7ypIilBay4aXUdINMe4K1LdaWQkLWylbhPnAQtmM/+ms69K" ..
	""
local PAYLOAD_P9 =
	"ZvwSa0JC6DU8hUWXPvf14/zlyx/vIBBxBaHa6r1ZQFyj/FB4w6t9c1okRqSPovggtrFliPtIG2lp5Ve/iZZEiPglhvdnXR26b+3M" ..
	"U/mxZErPvVKlPJW+nvWnqgIKj2PPxierdkxZXEJM7pUvfynetbg4XcM+pU2H4tHIuq0H1ipGhOZVEWS54C08YymxUJgUyCbxskPO" ..
	"V/gk5f3BB5d2cvpsmm3hrf0pepXnP+1prrC8k1NxblJlRl6VaFX9uv8JCbC3meufJ9r5iW2te1Zkui6AhT+QONK+9P36ZjFFAJeQ" ..
	"E8kbNzg2zkYR9MtHMvAuQwMf0l4lkQ5HvlMDFkBDl7V+OsQhv+S5oWQ6BHcgfg2IlPcHogeYPWYrtdy7q2mQoJbyuXlPcXqQ+das" ..
	"1pExxlk7hgeLwZDyF/Liug0sMZJHqr5c62YyJF5vW7/WMM/7JY0RKoalEaL5WrsTy8hfL8pzBA4ScY8JGzD/6rUnKbFv9LpUWzcO" ..
	"HAsvhpTC2pjtS5BESEjBfuQCZGt6sOG+t8jceni9t8ilKPVRDKuBNPm2ZV+0JJbfXCUIyOWyOg6T3KArUdfprnYjDIBuxks0z6qZ" ..
	"8Z4wW3k6YfUnnwZrzjj2q/DY0M+zBSrrqpit/gdINdcPCxf5I+OxFcmyOFep7wUO9F3ZI1l9ekfDvxBjb5YMOjh3e5wRElpqjutv" ..
	"nXftDlObedf5hjlFCtQtjwTpCpG9/rOP9W/I867MSUbHIFvnc7GJKFpu6mW/Z05C4poeaBS+Q7kWIXA9+wrVh3aBB/6uTVj4ufLK" ..
	"INZI1tpC8XuXQi2oqytQYLvZs/+Di1XXDNQNdGE2zoIQDE71JbwX0kiymWX0yiOGdvdbK9tvg+4bDsLQxR5L4BfudP8hrR8gG0hr" ..
	"rsxtB9SWBT/0IRWscvvq5oWtwiF2IOY2EXONGvZJffHyjL34H/4Qi2E1+ASAzvnm2dwiu8H0Kkzwtp/55nDaG4FHXwdnjgCUWG94" ..
	"tHAqbI4VH+6OVlwa8Ui8GFpbvOGyeR7CMG2K0nW3qLqmSGlUaYK+xUJ6yFp14z2F+Hc7emHQLQzNRzqj/GrCA138UDUNMYvsXdlC" ..
	"IQS+UIPswJt37yqWaP0SgRLrrKLWI98bXGBLxvanTzelVEy20fM4ocMpL1RfBcOvNbD7DS3YIlzxzvlCzkHPuWZshPfhk+JZOynn" ..
	"UPA/2ajKGmUX3W+oVKUmoDPzK9bHa/9T7CJEHNM65naMoc5/5gLkPsLqBTvqZYzome+r9/PduZgEf1KceoQU22s7vBI8g+MXpifc" ..
	"URTUCnSFZFroPrKoKqPwGVrsjrAH5aoowb3XObXUTHbDk9LoMD5v9n22N9p5sNmPhvJDFxB7qXRQIW0kfYiMM+goYvYy8eE7Rlws" ..
	"TTFZi10WurmBtfdF2lnjVpkm6YBYR4Jpt52G9sZ3CJ2cVMx63UXUUs8CjZ3GjbDJIBUi9CtpfgpViNTZqyWLroKeuDfwqChXEm84" ..
	"dlQIFQfpX9nmRgfWVhvbY0hWYYCy2dtkVZkos+MtWIZt1gi+WdAxYAwc0L53cViOCc5HrqFNE9XZJvNoWSWw5Sv7gO8a0eIk8cSG" ..
	"F1KtNhdaZd8+IU3PF+zz9iVgxKKj3HWM1lKnYsv8BRNxPBWFLMsTUemjW+1YwEGxX0JuCYAamVJCoq7MLdE9AZLiBXj4S6pqCpfH" ..
	"CV5vGGZ5zWiudn0fyDgf5JiTkMkwCHXc6P42LxyBLd1GhNaBuinb3OhnDXAnVxkH4hyQUYrfA6EUCvAPUQ5FR56IecVY10+EppoE" ..
	"1cypp6t2mfBega+LcGhk8JcVlx5dt1p5bNJ6cLa9EtSdCvNvuDDcoyXIO4SZO2UTAkKCsihw/0Fj7CgkvurSzjfduU6AhK/NJEYu" ..
	"gLx4f9FFG3Wacc/ShsICOa+3wLUDYFxSWOYYozm4+KNICNSmpVJ7ulJ43MRj7OagM/aziBBQx2LDrg72FukaDL5elBX99FAdKtEk" ..
	"+mUbMQGRkSjibv6064W5ri/wZi5s/Gh4HadF7OA9wYMOwyKaZSZ3rG80RSw1fZ/1uKVjVCfH3l2OS7/NrbbkGkpsG/rdf69intsw" ..
	"2fEkKO2TtMseXQo+TgfXhBfJ5dQe8NNI+5fu3VlBoP0LqxTQy/iPrWMRfLu1V277D5yz+sGFUAjw+Ljdap5kVt688eU735xxiX/p" ..
	"nhLFXBmW/BbuY1Inr1wVAODmFjEBJ3Trwl9X6DmXiOze84xOCb6fne6OLMWZGR8NQvDbF7lhTvRoPr0zDjCSOGp2aE85z6o/HP6b" ..
	"iQ6xIJA0mKpwklQUNDf3zDVL1MX0CCrBQU1YCHc+T9xfi0BXS6ZhKqBT8ojDpBN86nBX/6jU0PA+W9pKCxlpxhNYuliqQdPvJKOS" ..
	"9xSAAYrNJFhvGyHTqXVSk0434Ojh6cpYa6u3X953XqPE94D1vEOMJ4p5hJEdeyyQ4QMTlfc+Inp51r9D8cXBduVyesXYBINcPFWd" ..
	"qWzGT2q0e8hqQDqprSBEzlFrb1mwiDIOgeUpJrFNdUjIW6Fqse80WJFX8JYSIqx9ap7tMlhgADb6jj8uGePI4DldLdUhcBlktSA9" ..
	"VzlPVU0goIxhhooeB2j8GzDFMfjUK6F/zOsKpN10/lInzHLg3E68UGz1v7WQcvCOMmVRTFDhctIRqkJ+yihF3u0rkKWiBhSFVWck" ..
	"gVB98A/GO2D/z3Pd3j1HcdLkQgjyAobGNS5XxtCOu610qvjOP/5/dvMhT4F2MZhQXF1liGB9RZp6gaY9chQaiVLkg2kxQVmiEL/q" ..
	"LO7qSNFCFxyga590SC6CnQIXUsr4FV/QvpeF9cRVA71MqtzfHae8eQHcpbgTO3GGYxtkDGJquFD5TBwWkiKODpifJgvzHgm0LoW/" ..
	"0cZW8On/B7wr2v7InYgH5F1aYKFp258oNebL7Q4+83TYuULh50tgyEyihbzn6p3yDQhoy0kkG/4H2NSim6i/otORuR5bWmoDlBdJ" ..
	"ekTlWXfB/pZRX7maVLusF1y4HpYYT5cA/3TZufj2GcQJGuOk/uY6vbmtmQ8Rxy6FdKYn5RrDvYKqTDMmqxUcPIZq3phTuHhXjeJs" ..
	"uxg9tGV4bEuymgx5EoBHFnvjqL/JoXKBJjVeHgMz9HOJdjml+JnrdIxpAxEAU06pHP8DvrY299h/uhl3wGb+6iVMFZ2EVv+zMH6o" ..
	"GGHC2FNsbTRVS00sq6ZXigEQwAuvQGa1hLkwagcbRyaGvO4X2mM5zXDTi7YozyyLqo5y9L0D7fGhdbPWtBTx1pl/qJ3ZSf5E0r86" ..
	"y2IMzFub1CMMMo6IN8rXS2fbkJ6dZSh5/iM7te8BPzRtYxW3nHqgifxOxEgSNh6MMWntedTT75QHj+kjlR9/gOzM1QqrptMkFK8D" ..
	"VGdX0Ta1aXS6NDwB1LwvGrL+5cDe2Nx1qnmveEzwqFGyUoo/ZyCCObK69AGndjcWd+UKdMV5dLMmd9C/hVf5qv1BoZIT/Cf9E2aN" ..
	"knE34GO4OZ4XGO53qltpymvhgQG1M/LSGR+B+NyxhbnjL3Cdevw464EdZydZCLq2h+EDGrq8I/pbahd7L3rk4WrAdq9BejDMGYfa" ..
	"EHrqV30EtcUyWTdy13Xxl8RFPYmKc433QGCsNdI3tmvNJ6eB6dYIQP6Nwa6ab7pKsnAw95cvmgCqw1DCKEFIrCtkoCI5r98beSNp" ..
	"tLLmo0Zhg/atzTbUufpOM7qOUbuM1UhIC2CTaDVsykDRRtfdWf5rpyyPJJ3jUfLfFx3lKVzofRsvGI1vTEgNGhw9wK+RPvWpHg2N" ..
	"Z5PvATtzsKFKmJNQsqCHozm57pRFWfuWJcjxbZ1owTtCceZPy2ZxbcC7hqJne3YI4bYHWTSjlYosqXJTDYRho6U5B/oOOZYtfpmk" ..
	"YHH0uG2SAKMndP84YTDslt9PIsGQYmgQTJWpySpSpA4xSi5s+XzS6wkoLySgmliFEsFR6kL6bgjuAAKj41UWvrQX5U+vDjI7qwyW" ..
	"JuHSFmSakQrxZNOeeQxOZkY7pl4qbN3GR34yf38FviheGdqPLkBri67FCxES5eeVKISCz/idY4Nno1IFyLj+oUtmt6YoiZXTkvsc" ..
	"6dFtUBs96oRuwcXcQXXdqD3CsMx8b5mITkgYHTGtA18S78qk5dyeYqLAkpP7QQouQrUfnboPxbEv3qXAlDEb+PbMfYFeWLigbcFz" ..
	"OlLq4/D5p0YrVd2XN8nEhfdtR+Ls1WIdEIe7ncVLZHhOVxzqPpXItrM1CaeEU3aFVDqmwbsuSGmg+2HUJAvv/seQ8ViQaHzIFmiQ" ..
	"L6mf2QfGyMjqe+ip6aXZ+XYahitc9s4XhpyJcj0pT3MruFdYJ/0c76dvlJN+9PAach5eEoizYIILbuGR+VK4OCMDRTzFqHw4FMUa" ..
	"0HVqjlsnbpv1FdHJSL9rS10n3WVN5mV6vFYmSvnbYZL9d6lXxH9X9YZFut29o5sY40r+0XOpzBErvzsnvCaCqUpyyZ3vbGZh3pSQ" ..
	"/CLxaoUvechWe858X6TP0UjkHZVx03ob/K+jnGA25C4EK/fQ1gz4oLgEAGLrEB/GxhEsIn/4WPqqp+i06VlXN8+SsRJhbDSuyJzr" ..
	"P02c8xOFZH56C9Fx/YHxtTS2fXpVky9dBIVPwu1wSZuFoI2/R46mwrjNoZ4dSckJQI/4vFk3FyMjna6T0g0j9wpN8uIBlwTSInJs" ..
	"EdNsOU8GBsP5slZAUcuME6khI/MmQh6hTnBnwseNe+bJ2+JgZd0/zyEIDXu6rOe2qmqazD8kfOf4lNmytaRNm7u4g/GKiWaPf2JM" ..
	"O3sFWhw4jAeLQUhXhwrBxGAdr/VCX3rdOgiGwu6MrfdBgJXrS3FQowkQSia2s2RN3HBm/ERn8NOPAxHfyrmguFRYPRA0e/PYUy58" ..
	"BFfjwVqyjlboq+0rIagPrHZdyqDeeYOkPCgaRmNMcczmzhUfWs9eI/0UtahgFeveTVAaEP4oYCyOy+pOkoyhg0AqyDGVm60QRQKu" ..
	"aDEpQgh8fwVRISblY10apF0ZdjdP3UA9vfHdClEtouZtYVtDqxvtXS0eBvwIXfnrXw+wnB4nwAohOzPjur+qSehwxlZyK9uzmWCx" ..
	"7Nv6/um90ucf2F8Iu+Bk6ZDUhSnIqEPwdP50OJ8fZ80x2Ap0UgzZPgetZru9X6++QHiqErnNfr+V8OS8dhmcW9DDP/eiozWXuGFK" ..
	"dWgxGAJBNut7U7pZXE2MQM/iEj7QymwI7QQXnOVtiVgNkV5KpK5gcn8kMBMeIQ+Uy4jYAT9G966qKaXQ5XBsXYGEKcf8w+VFNK1P" ..
	"C+uuiFk9G4yi9KjlV1XqsOsukcNsJllO6s+b/QnbhQBaoLpW6C6pTY5S/LJjFoRjXlXD4F71k50aZzTvTeA/2nYxpqpAgYtNgukP" ..
	"IvU2vyndKIeP7+3FcMDYAHEmTJ+LgJT21o2sg5XNBN6nqu4F3v40Qk512WmkVlPJR/ZuNQObSCFYsU4AFTAMmlV4wph8Tm5zO8+K" ..
	"vcdDnApsJ4sB+QtwX2y0/HBq/ShUFrPE46/0JGNmMZ768R0R1Xb3q7l6yhCpDZPkuxX+TX6xeTFyhEbKUXl4zkywrbKSCRbZWb2H" ..
	"PBVd1FbrUGf7QIPVSykC68t2jHQODcvRMdVp0Cr7Kvwi3IkH6sILESWfNCDHic2tJ8ak+CbUgYo5TIMsbGDCwekMVN2XDJQiv2ff" ..
	"npx3l0TXWfMIXsQ+/Olv15s90N2gp36yN0GJ/PU4wuUFw5ZGQual6CGBwftXBG+0X0pqi8HYeY5mj27nf//ZuHJaU9DPS0JiP4Uq" ..
	"5EnJmocK4PBpC+UQWlT6uj2TL504MHl22xSuBuWW8AD7Y1YxLYtTDSSgNzEe+F6TMwjS3OGe+xBQ44W9Kd2PtMUJF+1YKEs4mc9j" ..
	"nVKqlX/yJVn4c1XMoi5Wdakf5X9zW7c1IWXaQgY8F3Ifle1bHE071IhHnX9W93puFyLsBD3Nf0dlq/r6t9Kdt2ulqCDKASzzJ2P7" ..
	""
local PAYLOAD_P10 =
	"CBDb+UQTV8dcLjWGMMnz4jrGg7BiFJki+LGihNk/PGKrzaXeR77LR9wvjTrsKjZbFccbE0nPyz3JmeF9viAgwyRW3HSHyXdrSY3B" ..
	"iWtw9TsAc+rkHVk5PA0KR1EwzLmgcbDrV3taST8DWYs735yhWnUUDLQWGwyvsQabjzb5EjYixfTFgKH4JrPj7BCR8nUPkt+gt1zu" ..
	"tjrIkygHW9vk7Hf/4EiqqpJlxcI3hMLqdr/YaRxHN0DgpEiLAqQGdCyPpB1KMd6dKN60bx8RQZHvoiXDja7BOVNkAFujxe5xpvq3" ..
	"iFKvWp5tnBlYxMbOS6/l13SxhdqtWaoOB/HntbmjlPygUkuUh8krXT0QB0ebe80hpr5ij6dQ9xtoS9K7ml57g79vxsKvPx/qQvaA" ..
	"A4f1wkVlgYb5YluZZaPmocRt1PRkOLZo1ExosZ+K39Sd7zRV3slE4hTuAFGs13azwyc/dEzK6st/gzo7hwuybnNQF6T7Myh3b5JQ" ..
	"tC5/IRpiNI03uerP8IrIgsk18aZSOpek8jCg5cS6km25mOa0n/z/Cpcag6BWX3+uq6SnXN9k8jUalDjY3fjONwVq8ciONHQbzisd" ..
	"u7W3/hSoUm8J6YsUHEZ8ZT9LOJ5ja8jqGycc2+cmg4sjkRu4TC64b2shkRLw70S3pdwPgMu1jBBXIItGsOPMIpPC9SbgEwIjRRnJ" ..
	"qqNrKlZ8/IT0XSSb3PpVX3rql1KyFb0BVdLXlMv74VyI6c61T5RUp1Ilm6JiAKx+1mLvRdSNL9qEF4/D1kBz2ajuVFyd+CLjjjIw" ..
	"VttWasGHGnSGHv8P4B6fKgJZNYopDC7CmNBQkEkwFqlEeozxseEgWkNQkOH/DpZjaJKWFlYrddy/SVDW2zG1PVQnL77TtER6KK6C" ..
	"bm7XZkwH5Q+vgRuFRO95xOGSMterSCkIABFvIwiaVdppSMXxJ7WBGfLxAuZNK/EchhSUgVpX2RK1i9Xh9ofxpvt5eveMLPGePnWI" ..
	"EomBdWyvK34+juowhbhAxhRzrBccR/cLMGtuxwj5cD2v/hx5AzjGudeEujgz0cEnXUlZTNKwPdtsgLOKEjl6JZeojpojom0E/2xa" ..
	"Rwh3Ss8L1WMGmnNgYYvh82jsRDkTGrckaWWlz0ScDZ24Sza2/NEGHwu6nMnFg/auzJmlSrfNh6zlB/KTNqtIk//GzQ88H32b3psB" ..
	"fFZYZf/9aPhvkCsNcdL8P7WXKr0tJ0oPKvnthAZa2koOgyfusUYLqud4rnEoHemoYIpO/eP6viBRqgfyRk4pA+X2i1egb0AZJhl0" ..
	"GXZG8G7GOTSQOcxHq2U/y53WT5WqPiG0igTJsUyEox0MJXBj1PFY/6gB3/qdbnwaOMijxWIpBtkhuU0ePcDaj/shrgxA96td+Rkh" ..
	"2iaC4B3sn0oD2PkO6gbvjbr3Vx8Kcus0VmKtj/gDXTQFLx3tUnjsm22xc6/Zyb4zxzlTvomR3Xta/8418DC15RZDTX+3yTQIxDg0" ..
	"qIwXR/zweUMHVQ+HdOXtuRq4yDfCkJA7lk8pqxDH0rVQqvYfb2sA27XvKeFbKLQgRjt6o6UNLSxdMLxvOFsUnkUNj5Di94y2FK6G" ..
	"xFaozi0COMV6TRST2RutLcVx80W1dmk3groKUZck78Q0TyLK0/Fo4olCMTI52IANtAYkKM62GRRUWFRx0N60rcUVT7mvqHmneIbF" ..
	"ZeTj30t55ud2LcLIHg8bDnExSdoWJInOhEjCdWPdtR1appsnrD1XCEzM30FynGcEtzK1ECYfJS1rh/1BU5CZp1JWXxCQEVkWzPov" ..
	"qeS8Ro6S0xO3ARfJitBI+zvwYyxIJVe7FXF+0DE6FhcxGrLt5+D7T2WilkEd86MHH/f5d+JCQM90BGQ4YMk1VCuVSiCGEJTTABAW" ..
	"/6ZgnPgfz1+EWpD+bl5DQvV1ND5NqStg8+P4lnF99X/asP5YnW95Z9uEuJt56+e5S9UfeLzGfD7op4L4Vblk4HcI2iGv5ZiTl32T" ..
	"fXuvcri+0VcHzHsKyNyRJHnirW6jaOgadSakOhol2oImwWYXEst/xmBjTuxmyxgBtypgoFg9jTCtQa+fAz+j9ZXnXDlLeorR2jMn" ..
	"y1sV3hTJAj+oMbXQUE2HhGGqEXG6zXc7WWxUa9FPD/BYRroZaEXnRWU0jIgy7LSbNBagpsDdepl2HARFz/duDYBdmsqk8fJMmKo1" ..
	"nDttmedqMvngcn32oA0Huk4StSjHILX/orjmmz4+AjuQwOmrEZlc1A2jMFjzAtq2yg6DrD7CV+meNIDiSbPXLlbmkuwyTM711j2N" ..
	"URRbmueP74K/LIlpinhU1m7f2wA5uJSgFBp8Yn9lLs+h1A2Da31/3wRtSW+vqLENTQONIsjCzVpX5SjfsMzyPCqRXvOlxUB87R5q" ..
	"MRRMO2GaEGsdqGnR1ouuQfQAcU7V0Q2Gfy3q2dyjr8YK75C49UpYUD76Hqks+5jxzVgERVsqtSzagdw1/1DWA+IAXlKjZGeV/C2l" ..
	"IsaAis2y8Byy+cI1TFr21POdm8DFmolMWXjynUUjdKuI22qBZw9++CiauqeUNzrOrq4TgeRwWd1ay4TluCYUyHuhVXwDLZ1lDFLL" ..
	"3J6Xnno1+OLbsMF11Fbm/RkBFe3S6U0/bPjT9ieSeJ9BzdexbaD9WfjkVr/x2asdQM/zfjPO9uIjBtIgabT4ToeaQRi2ZguhXDV/" ..
	"bVihqTgC9/fZtAfZtl3bawS1e75IOXmW0rElx7thGjvbbEkQF2QYyP7NyPGqUE5Jra45sOK6E+k3XcresD+59AJcclAr4UQDPW+1" ..
	"yQDiDlNgr0OQmkbhMkJJnapLUi45qnSD0gBV3TMWc5mx8DAL0a1aAcWHb83IMQ5IptFASpDTNbzHMKtiViNDZ+0ez6krHHBCOUV9" ..
	"wWl6y4n2LKe1EgaPpEWsU57bNTh8i80iIucSBLtqxtVaOB7BbPSGSwkxszYyOUOFraf1A9f/oIKB53HLAXHDNz/tX03lGQc8hUsR" ..
	"IJNx43Eytd9mT72vqGUXudA6f/Y5YkalR/dhnHrfiDrGAAPgbChmEHSvouCIUkqIT6u6Y7rsz6eeC0Dzb6/u+/koIyswmoIqhF4n" ..
	"9lL70jUtAm2K0NighfLuofZ9ecP7NiyKjplmM8fbgkQf19grAq4W/zLzG0JfbvczUohD4E+LZkH7Dj7+t4JSFqMhZymjapvhp6DM" ..
	"D3ocFevLJyQkxFBYfuOXNSFSYnidqfGm92Wqp1p+xqlvnhEPap4SQKMldQlaCNNb8wQJ4U8SNIGJiOFNuX+JXWH4Imxsm1vHJNVH" ..
	"O/BfD97DyUlVHOsOMBz0crvYM3CxQbSjQkATmA1VN48G4OZvTqwIhap3eIKlgSokB6o9r8/RTsnZnRMVn/farTCfXmMZ3QMjA980" ..
	"zoMnK0tE9/PaER5RAangMZXYVbTxCsURUB6Jw3iT0UCkkLiiegXQnt3s6mjJB3QT4Am1f1qkZbvea+3ogiCdACrDUcGzBfchQ++l" ..
	"pEjy/r/kjwjXF+DJBeyaKcuKcD/LGjFlsGnTZD9YvCjLZocbs9ymNbnxIH9mumzd60xiCtrIUq+xSgvnIaMZ3yRSGJlLbrFg6A2N" ..
	"nEEBKdeHdhmZp0NsH4WXCealW4Sffglf9DMR24v1RVmYvok5MC4N2TEKz/gON9GjM/ukQ5PiC+x/WF8iShdxc3DuVe5FN/iNTTCG" ..
	"pHJmj14WM17sdo4VufV5lMZ0ymeSjpCuHgaGkhPKkvRJ2TSJrtTZ7Ul1PSxXwRWh/s+mHlThSwx9/ONrIehJ8z2y+ctvu8g9gOnW" ..
	"ASqr9s5dFdXmtdV8DSZyJVSIGigqCnKPq1v9+amHE/Z1NjuQOdIY2uLmMulf8aCCpW6DYMqrsCPiIEon6ce9blTeYZypD3uW9fm0" ..
	"6/bOYWcyCyy6MBYkT+UMYXNLFyX2T3TJRIqlW5WQDj9HBnt67ncfHBRf5qYzPBMtW+O/ir52Qx8rzwcvFFlpcxZLXPX+UA6AAK+c" ..
	"FrLxY0jcsxJiG80n0fvbMn9+bT64/wxAqIC64UyO2dYAUv9uk0FDHo79lRLh8ahDnHy9GVqL4LEDVE489vxrAEqeMliG1fyuYs1V" ..
	"I+JXkFOLHn4p77AKNcfz5gQ75W0y7NGArH9B9iAqBzXRc86TmM6KsVwK9KUj7LyM2/71kLvTIDI+QQW53nleOK47579LhalgHnCd" ..
	"mHYGRpsUEkbVtasV44W3CO1KC035V7N33mXHIQCIGQwgU2P7sPRby55OEMH9PBRz8kqiCZQUNol+aLO+t0S8hsDqk8XtpqzqojCW" ..
	"eado6A+ZRz8oj03Ji5dpcM50OcHcN8Xn8BXvjMSWkeWXjtyJ8SCbUVn1ukT1hlCLrNZz3V5t8YpaEl5hqWGSVTG9WP2BU0rwfK/V" ..
	"xRQz27tgOum8eX1CdPTKX0uyJyieDvWXZFOTm2by/3ZH87enY79GkgTN14vRGtGEblmxXggnLv7VeJzhEqPCrB/V+nplexRrq+Rt" ..
	"zlv6OgtENiyirxwFnzXI5mzOMqjwqphdrk1vEw+R/tNI7N7qEZ6mopHK86pnOv5ghVFM0oJGLZhws+e/Hn9BoIsZhHgZTluoWCoS" ..
	"fQf/BTAYv9Y2ZnF9cg+xs1jtAiB7xTZiCuhZFIstiEfv8dkUYSB+fCi0lKZVta8SOM0YaBwJoqYQFv3CsLfWnSI9nF1F6QcJXj8z" ..
	"0ekeM3KTgMhwxmwsHqhdbZHdfpdDyThjkNrx1ySGnLtGuPZByzY5QgsKH6PC0Q02rJFkfVBcdByHQy24MSaLVq8zA+qpSE63lsUt" ..
	"ShYrAuZuV3fVCv80qSFkqBCRBpR212ItPRXMPAlUBLNvOj73AkwgbN580rYSGznOTlGQEeZ8CaoCBPgKy19eAadCFA7lW2hhFL8d" ..
	"tfdUaNHpIYNP8SQayIRtE8Ve9OXXq3NHHGYDIrWWdnd1sUHY8amqmR4DW9WlO6T45hTMjw3ZiPfJVJRRA87doF8EIcL5FLdO/4JD" ..
	"l8IcvpNHc7h8NPQBmT+bAabsA/chDuNuKbIIhyMhpngPAd/nCSebsLZxYK9munpvi6hCXtZihQ9zgg27MFrpJl5gSJ1GDV7ixPe2" ..
	"mp/ab5SY9VGaOiwrK9no4syKiLSm8X0BMwdVOUJ4IteqQuJkCsvjbxnV8+ytx5bCefn80cxacbrHFK3Y28pzHa6GWQJeossR3ZUL" ..
	"iSwK3GGYl+xG9D9c2NFVPRvXhYkNbtToEmkEkyPAuiN2itLLk3kTuDSiU94HlZvUNksbrlTtkoyDMI5JYKNdmrNDKM08oZ/SOR+J" ..
	"w7arydY4NrVLddl76jmQdJsYenY4bpu8QfUmke87EVb45kljqV4y8ksOSHuTY8QEVRX57AyGPLktGUZS3qMuoHtQPoL+ZqwV6YQ4" ..
	"Rz5d74jz2B7Dxn6xnY9HAfuAAhNZrZGsDTYFGW0eeIx+ntPyj5/mTSxMCfcUvKHHCwr26kmnxezx6IrLuiKllzo9ap0mw++Whczy" ..
	"qlHHEZMUJmYkp2ebh2zB74Pn27gPy0Qv54DQC3bOL48x612wFAXQ8fiea1S1BkXVDFkZTL+UjwdV03gWGTrO4nW+RaAv8PJUH9xV" ..
	"6MpPxViMSEvej/ZIvFFwapKTqja5Zhdvu0w500LqucpRxAJPznHAjwLAAMEYHpbMhiwsvOMy4BiSAyfhCW9R/CrCsDdlUc20/HSE" ..
	"yqUc4hnEt81dhdIX28AoVE9C5M+7F/NhlpeXE1+G2hFivubC/vkFRC9rQbBcDd2hdq51KTKjatEII8cRAGRlu3qhsVSAghhUZbuS" ..
	"DkGqv5jsjLJpbHy8P2KVvzM7wnmUwl54GgCTk+l2z7gmuVsr8fVi6EtZPEbAkaa60HJ2rTyInEKs0e4yJAIbOTD6XWOF3GsQT69Y" ..
	"JhwAOrFs5DGVgMEhD5bK/1nifQdwZsUb0No8c/YBt3PR255YCTgojEif9OStvKFC5MRK39B0H76cIW/bOJq0AiVnlC7KFYT5siDg" ..
	""
local PAYLOAD_P11 =
	"oRS37Jkdx8xJAfWOSpi5nAb/3JKRN0ZcoVlPNX4e+uBxVcrta/tomX4ju8f2lqDTtardScxFoXWiCRNMowgQCLXrb5OjUzYCWDFc" ..
	"nm2PbAOlTAWcJzJyUGhOTEIv4UetIq+a1dNPLnqNuyGr3bPH/E4muqG+Uq70lbtz7paDbNwnVPcECDrUHw5q5SaQn7d6KSjBdJ38" ..
	"IWBCzfHqmSmvGwq/YS+eD1iwDU3uVVdwKvJ0wkG+igswWM3xZ4dd5WAS/dD6j8cdbkxD2P22e5zXRUAPM0gU+4Wj9MCrF9rsmlEG" ..
	"ZSbLT09V2UZda5m5o/udftLdqEKGUwI3ADEKCfLi/pYNS0kDs1ELCVeis+wpekAUITa8QwPJs66ewJgDYWAk+R4T7iN9/zBqrrHz" ..
	"eB+txXGIgW/ECzcd0Eq32M3coTF7EvJA3uppN0KGdL3gOYsRBLrhTnUth7enZsbPGjmEdAIihLrd/aRXFdr4GbQRNZU4O9R9I93h" ..
	"Ljn/jSwArKFc74iLekpoeBpTNPdm/tQ5pYSoxtazCjXtbwHFMyIUgyp3KMpyH89Hxv/mwISVIoTgLIiAr4CmbZ8ilaSmvgm29la8" ..
	"IchsZhY6f3XqbAdK8MndpC5H3urpVpZ5YmAJu1Hykc+hH2cpHgQ119iq1cqcjpoDzjpX8Ycct6OEbIjNwvoOpMsrwBAiNCp6" ..
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
