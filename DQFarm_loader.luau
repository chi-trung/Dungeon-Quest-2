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
local ok, s = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/chi-trung/Dungeon-Quest-2/d138ccba1172da51d8dd2cded9bb51e7ddbc346d/DQFarm_loader.luau")
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
	{ seed = 494551140, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 486678642, exp = 0, plan = 0, hwid = {} }
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
	"TdQaGFiWLZbYJZZpmM5zEwZ0+a3RHxk/C2U7aZiP6asLqNSfIKmT08vl1HucNQOuddmhwFSuy+HoO8GBRPv6RbgD7LH5b0R+vPZK" ..
	"qQNvpvPzmndzYr7Kbjwrak8e1Z9Kalm265W0aamTZrU19dEf85uKVq0S9UzywnEXn3pR4TdgRYAKxtlcpZFSIEFwntQDpQQGuZmK" ..
	"z7M8kl8jZjBi3nMNSFbCuE8/tpt1OLnaOQB/ERCKdwX1/3g7ygRUpA8bMiXn1Dt5WW+AejjgeOl/hcRuuJ/+yy4AYtm2UROZpn9o" ..
	"dS7WdCOeqwKZwi24WnkrkVIJv6NS2VDUXc4CiyVjxqz5+m3OYYfQ2AlLU7MA/w34NqIZG53jmyN5wlpHSkMLoXRsBnoR4suD6CRz" ..
	"BAyyhw/O+Z7Yq3BqVEqCCgQ6uJNmttVpIsto/s/9+qKnkTppxujIhruOuowg0la5hI9BUPrfaj1srTghWk1aTjpop7Kc2XIRgZZ2" ..
	"1DKZsOJFaP/nSCYDD99GdhHv06gvfmL/cOD8LVijE9udwXf5hGmkwwNTsUVysrojgSpARhufhKXQV74zHBElNaBj5xUCD4V8lLAk" ..
	"pUxDX9VpnGL1YdNrbbBXfyfG/Nb442ZQrjV80Zw0hhWTMpd8Qh2M1wcHZbonef8ELcvOOKqgwPXSnRb8FUfKJ9RongGyGjOVy1fw" ..
	"/zThp1nNlRKMPRl+fXXv218iX6kl2BfJrE2pQcJBs64Vt20Q6VTBGxT18xG2ecvYEXbhrekE+USODuDKJc9RehjrggW3Y9/419gZ" ..
	"BB5YzPNfbki4RVig3uyVzQbvPXWuhAN5bg+pI6RWPmKCW1F0N37V5+rrTrSJoTLZcacen2mImMaYfTYW4V4gCt/1aaH+HT4i2k5r" ..
	"+Sc8uVSoSj4uLKi+JzRVFkrJBzbqAxtLvu2QOZH7EB0gHXO0VPftochdvO8hgzTauK/WdD+CYnhgYDdFTnAQEbY9+AwSRqxrFioA" ..
	"8/iJRwoPJbVwVgazFnRleH2yJMxnmifmpfdPPLQenwd+bTxaiKkFjyE3veMB9gRNEhcfLnDLb3sBhUqnk8woEZ6TRvGL58Qcabmw" ..
	"kKpZVd+9ldUR2X3HiPkWkqs76CTVWCv4bDxY4EfWRhJN6Ua4zHlCOohUxouRsINmDHPYhvBjRLQARYw48xXLSgehBKKgLWlbvTZw" ..
	"oPO4uS7l307Oxdt6VxpWR8EzTfhdr6+a+b8Ox9eRfz3l+TObkxj3Xu+wL5VmQSZ3UFVzxqFbMCY2EG69wh3mCsl+93i+1AwPqtZ5" ..
	"9Tsfg5TIEqVTAEjhDRR5oxZxbSP+oAr/Ngb3n2JVU2BnsK0knY0HLOdTiRet4QHZ6jzVq5/neEMqs70OzeD0e+5CcKVgFpm4mm5P" ..
	"uFzh82E8Fqq9+tQO/nv3C9QTzTCG2+fBsKi67EV09qG6UKR+D/AkdX7wF8J4vOI9ug9HPphc/YPrtPK3NwH7sWLlEpshZYix2Ceh" ..
	"mn7KWzf5+4C4ylB4EkVraoCupbShd6Y9+kWOuOXdoeIC4EWgkH1K9FEiy9WMItloknIbVvHIpGc4LmPE56HrQGlTxnmSaifjC7Ae" ..
	"CosPkWbbHZItXpQWjIuTISW/+DaabrwmSziHlwFcC93RxrO3j1gh3Sn7vLo0WiK0nYkcyWVX4hVfKB7Mn/kVc3vUINRnIrnzcuWW" ..
	"9zaE1mgaGwjP6h+m7dfjpCK/SHEbwHTnULHOFvYympFmQhBCLPUf5MUjSvDsWRWsOpVM01hdEPwoWPAD+RxE2eKN7Nl9yDjillTL" ..
	"CaRroavRBOL8Ow4FDHnTiFbHSFHbzv9hl03xLK6wLz3sZJMXQgXHHcf//AdtBj86Lp/cJ+jIyFVItT8YJgFIJ7GtJmKP/Vzua3Ys" ..
	"CQnLhg3tHRymp+BWM85v4o1gJMENsVdI+o1drrfsY7N/qIYpNw67gNQL9Suxxtpcme7ELodsyv2G5HxRbu8cVIuhjtusCcBOlU/n" ..
	"MD2pie3Y9wEBo//zUMNpcjle8RElECBEB5uilXmatoDCA1oNwTJGh175RzpIGkXr3bB8C65uwhkZ6C2tVnqPGiGvIM3t73QjKUKH" ..
	"SZd948xS0XbbqYMdkIUjJira6nM2H5F7pWpL2Yhevn3ZlJCF/Txnu7IbhvoGtjdCP1oVNFIpF/encfdpUN9KFC8XZPueMeA7InqQ" ..
	"Ww3Uz12sKXLkb0VawKC39D9ygHyLyMvbqj7g8dFP0ZfXG6Tv6vlY8IuMzWbnisny2344u/+yszccCC/rW0TGs81CtCUn+5gUZBBI" ..
	"PFQX9fNQq34aJAnIzwWgo82TPcwZnEVxk8E3QuEQbyQaPK6HzOM5jgOyh0V5iXlwFZ+Vp/BoYNr69qdiW+RBKu+bpNRL5fumoj72" ..
	"I6ie8FLmYkh/t+QFZPN/8kAjRhhFuHvwx2y2TE6OXofbQbuSuTmaGLBfN2uHGmQ+KTz+DG+no2CGMsts8dqus0aMMCW5n4OOmFm0" ..
	"4DCXSgERvoCPSITIUQNxEUVwqeLNnb8BSMUzUGJLxrIZnZB9CuUkT853yvfidCdN6rKcM0IGLNrRlocOQNyZUk9WS9PVDKFAGEIs" ..
	"Ue63g+DnYIq0QmSBTpNvNQBPOXKWh9WKqSBpDH0WykFQmrEkDEpF4pi0FIeYpD//ODeoFa7chfpfQGmGbyoqIp3R15qqSBKwcKyE" ..
	"uzNSQfCl4aQGmrE1o7935fBkYwNn7D/rCyfa2EMrlw395vMuz7e4cORAVo7qC0uOCbh/B/Upb5OlMEiS646tOPmpSof6v++eCpO1" ..
	"tXzm6hi9ofkElmepCIeTHhNqO/+ZvOHO5Kb5NjYEYyqE8qbDqy/e8OQDyqlyDoGWRL6tdJnHYX82+/OgUMap03qnXvfNuuTWsC95" ..
	"GwRUOcDz+krzM3TAWjEaVu8EIY4OR03X5JWQvkNl52dCILQfh7JgmvbGSDi2O3NneLm92mh3j7zMoj4Ttp7K4jIva+L6A3DXl4z3" ..
	"R6PXzup0/sQjxcsJK8sJ0tEW81KdsRFLEkBTukAgyZY2dSKHrobH+96D8P33UMiPeMm226USeMaL1ZjbSlMTXWMMfCKwzrCxsNeL" ..
	"4gRP/ZuzKpDzj8OstSwmatRhEjHJOq1CdoTpSK+N7ayapo/iJjd+WV6m0IGd3VE/I7W2PH5TShLU3pPVbweISlfPzyu2XfPTfi37" ..
	"mmOYQYLjgYlua1UglyEbV+yWByB/LkDDirF3Dftf+geuSyFGPiijt25M38mhvvTS+GxAb2JSaWZ+nGBjjhpa3GKGhZ6eo3Oj/mfc" ..
	"HuQUgZgrFAQQPNeBvqsIPTzvCx/qzlVa4N/z19xbbfqO+fIqbYgbwoEch2qoq9S2dSLjtanqjxecDjPnfNV9NX/o6pJkSeMgbSAE" ..
	"0kYNpFhYsZPB2WejFYuyg0fwH3H8H/vSeW0pp8sKbbcuTMsVHK9NoJFXa51QhA9QlEgZXpII5azdSIDb7pELLZRfeOtHoANBFniH" ..
	"MM9+Ifz8AhxdvoLSPBFjKG07ESBFJR52wLLiK5nynk7bFsd7Bt62DQcKK+UhdyypPrF75t9KzoU+9UzPHY4ydwVGsDB9qk+xV2Jl" ..
	"00AkU8g8PLe/oF1GB28SZi1RHHZaf+9aNzs/T6Fnduo5QSl1XZYn86BhfCLOumUuwmQyUrRYA635/rWTCmAkN4nIICxeOabFoGZ4" ..
	"XohGV8rWQWWquVF/pZh3ks8GMv1roz/BNOnoT7h1EMNT4JdXIo85aeuS0UuTP6sVE7szwdYWK43cnspFnBTx2ag5nl/6cMSzpaS3" ..
	"dJFLJfPG3ezrQur9+D/Sum1BuZhaoUQLv6gpIp6PaJ664f2ou0sRaxLysyHaiIEPyL1NaMcUkCNbmnzOWKnlOfM4yWa1jsCKKUw7" ..
	"I8FK6P7rRXYsdvsyihyYAw7IVymo130klCIrHssR1Q1gQsc+EFMA2/h0/ZsabyUMRvqFWpr9oBw5wkYRMGpaawwFUthP6hkIYMqR" ..
	"Vayn4UcxXLXyIfSo4rDnMVi9w2crjMF9LKAsjPDX638TmWv7WPoEJVyAo/9C89w9Ivyzbc8Y93grZehcr3Rmu1ktizup+/pk1p2M" ..
	"QG6odlB2ng8nkZ/fqRiF/4Akyp2495lrwF1aU+1vNuJahNHx/g5GYRUreWfUaOqaKhwpwjZ4N796MUgMWhjdP0g2dKo20KBLFqur" ..
	"VgN2OJ/iwXqTqRjRpgyTJeKerZ6PGCUMQqItVYX94bmMF3CQK1JBrAKxhtIE/uc6qj1UB/C5IuEIvh+9aehXqNLdyJTSr7BGqHJB" ..
	"WFodledJDu7FyxFtHDzB1aY8XCeLh6gA9icTLs6uJzS/NukofT8vXvrmEy2UXmAyoQlP6eecOoqy0WKQmZTaK+1t8zau7v9kDs98" ..
	"aklbYt4LJDOoMjsBG3ktvyJBsQpj7C5WnCemtfZnKTjy/hbVHUSLlVJA0LN2IHZUTQNEWTgmdydBrw3wuOrmfjid1dNXAalERg9w" ..
	"5ROh79WjjD62NCoKso7j13Bmag7AiiZJaeWMMNWlfqsjphAocq7M3RlYGg5WBlZUHVppDhDFNe3k1Li2QmreQgyiE9hPwpIGcrtL" ..
	"1aPmofnOvno553OGDQb0Lg7bXAAXcLf+VtAqgb7U7fDrW4+ZQmMEC2M8IAHegQz4NQqh2uGagCuAmIAQVZMkuUEdvvXfBal3S7ia" ..
	"22TtyctMX97CujUX8nen7h1D/ZILz9Sc2avPFJ64lL+ADToMZvu5xDuW2tRqcHtR9gFtMHdHI2v5sTqKtluartKDR2DYdCMwufNS" ..
	"C64FAMFm1/6ZKJyEBqsT1Wr8SODPvUKCsRsqutTZrakb/J6LzIXxC0ihMbcsPTOTtQmog7feaC8juChRTqoZcbOfA6Hgi6/xGh5z" ..
	"o8DO59VVyzDJNtUIYVMT3As/eKeS4KtDK3malE6Jj+RZ7kcuv2EcfNb6NeGjP2kEmazYft1pRpvvP+Mq+i4KdXlhBpNT6tB8mWSJ" ..
	"2bLcZAXnNpFOUzLatBSNdlQ0Uhn3YUSw/G2xK1sjcBf+4C5PHMmMmfbLskIIO8CqVsQqnPXl2MFPdDjpj1o8KKU7nRCNZUmbt7Vt" ..
	"P+MwOPnxxzU3gCkj9JFDm2zJBgpHsQsBYf5nf+vec6ye4xlaTyn/SioLIExdsK//7VPKQR46AZWgIDT6n3dUqplpS4YKjIGbOBO9" ..
	"vkSQeF9iTicCZqZeFiH1QNKi31D6kKoDFEGfIic18QN6VFOVQxrnDh+tvnoJSNjXZizIxIRpybVJJKV2qcUkQYseOQfRdJSbJ99J" ..
	"9GwJYkUkzv+ibkgGIRNZZFGK7puiWPSL4/IuunfxzvdNxxwvSiIIwaZLzEFwQowZ7NXJyWbb7Qr5ckCrFLIcsLdEHYUnYr8RP0y7" ..
	"PCSwgYRGg3c58pSKEF0im7Szaafm9KYrl3pASAVZuNXi+mK8TOirFSAOHCfaeoCnziktHwlr/G/ClseANVgSHFh+IRLJXppOn313" ..
	"ENAGvY9pvlxxs3qSpdMN4NmPw0hQq6e7R0VufaPnwRZoOSl0WNSAxMHaZoDAO90EMldq7TlFnhEbzbSgU4YZcCa2dv2J4J7WlzMT" ..
	"a/cvHjJFyI869XuXlCwOMAFaB8DGEYLW1WVmdC4X9BQbtPBxYk6sgghqvaWwnQ5sYc4P8yIfWdWcFP8+tEQ5zcFphnWm+bTmNjS8" ..
	"ayEQxFsB4nXW6zZUn0vn1s9jyFI7dibZx+LfGF/EdpiV2KVMPKqKaWbeypjJT9NyaaI1nQD4uMiLzFiHXGTdj/6p+K+3M7CrcMbt" ..
	"RJUp0jlDVRHeztEkagWpgdXPXN01qTsokJzugw3AvGN8MLGr9f0o/gasRcYWgqxX7XVkvq+fiaE6XcoRdnO+tnhKXB9AbjhxdLFj" ..
	"I1eJ/yfBQgOXjARV5neqW1VOPtslTY95Kv2KsWVMZAoNMg75f4rVt0nGnYWRkCCPmOO5VwhrsGcqOJeUedzDGCFRLuRwVdX5+tju" ..
	""
local PAYLOAD_P2 =
	"e8xmCTlHGZr7jEnQfFs06ATvmmi+Kwl0GTWmgTG6NYwnbpUWtln7wVMKlxgw4Ljf4hAOM5g9M/BtIFg2JgJVFsx9o0lqsNEZhT09" ..
	"d83aks3WqtwUzE1XPPTkK7O/xR08tWr21WHls0OjRFQj94CnSMg5kki+c9JHIxRljXuUD47vWIb640MVDJeLOwtYcITMO8Cr6UWx" ..
	"s1meEw6LDUy8US7ReI8OB14HySQPOqrMwQxEX5arIYZmXPB929EdJ7HTf0OJksgsv5l5n/nj8l1DSKNazZA65lCobUaVfSBB8Fap" ..
	"CT1fDWHJKzSfRXFd9yaNbwC/D9chsF1yiPTZBLIQ9HJNPnwdSxnXmg0AjO9G/hCfPsPNqOPPOoeSmBuTYdKr8ILfPWAZLh0RsvIR" ..
	"OlfAUoYFU7MjFOed9LwOnLAgugFxk5BSHkFRYy1WBpX92sRIfxi8yP4g894cajjN7UtDWPiEAvvHaEcCxImq4Vs2AfwEU64z9Qcn" ..
	"gRUWAI3mZm61npayFE76vhC+9tO4ScZ9spvpS7sviiUvg4O6BCjF5hcKrlLmAifgwbhNB5L1ghusUCWmgM1Fq9QURHMOLwwxO3Q6" ..
	"iVsInc5+7fo+bGPy1Ao/syNgF6uOwXPtyyz8VCKVKo1YY/8uvbBr7weYcASwyn7jUR28IcE9g/7fKJrq37SoOu3F1pfZ6t8evzOh" ..
	"INjgmbAB/AfMXsQBJikgA6ykJP6yf0jRw6E/7iPJc9YDuhpO4hAn1xyzJdITWF1sYgcWHoQDv/sRD26B5t0kVQcwpjJE9YNBKv9a" ..
	"wgIFygXkjiGUNVb8nJjWKM+SkY0Mtm5sCJ6clfSmaWxlqO8qIEElnhiaG0uvPshdG7AqDq1ZgbF34EG9W3ChoXhN7GCz2rtKE10g" ..
	"ty7+hqq5vVfYJ2b+Rl9LRicaEovFsXUyIiuCcJ3YA3LSpS6dqZJn+CfWvEmmMkQnV8Y4Pop9Q2OU9qG5FUpImFJ0FUxJk079RkHN" ..
	"wbin56/uXcJ56omG8FDTghChsCkQsf90nQDq9KIjgBpPmo1fYhcJW7HJ9PD0aundvIZiaywobrXuPGYFrca8fgE+2fF2/hjeCkrP" ..
	"8JsulMW5BrLPLICbeSXfMkQkV/yvvUI6kSVgI7uYp1WtY4FAiRbXBSRmZFs8h1PXqzsp6iliM6wYYLVwkEg1wHiNe9RP6SdD4Juv" ..
	"qayrk41DIVH5HLUAPwMwKUtJAIrB41DvGP9np8q0Cmm9ptjImAiR8RwKm0RSN12h31PpXHW7U60pMahR8SylUfGhIWfNGfHxkRk6" ..
	"bC9QBwkI+0FXcBwxEHVG7UYdWnFArEUQ86buNXau/xSXYeJunqEtNbumcMHZ1fFiz6Qdhx+D35YrlDo+4X6ntwZ5gQDg+gJr0wtJ" ..
	"DneB/24VfGON+y9k6ePRRKnV7i6Ojo4muXN/bjuwoueaaGIeow3gJ30JXJKZAFDmGikT2vfBWPeGKJk6kbhnq16XDB8b22V0qsbw" ..
	"RNxwGKiwN5Y8C7lIX0P75zGgKEGK04KrnLu+yENTMUx1wu0IXGY5MRdb6emib+lvCFrg1euGTRgFyoAu9pmaDbd+nBLd5ABVAFCt" ..
	"Upz4zS9eXr1x3VhRgT1VhvkBsSnR9P55kG42KKBUDRXn9Yul4oItKxatJv3vz4zIOYrOzfcORFkXxT5hncF1n5uJQ6Y5qU8qUi73" ..
	"nph588hTEHEsx++xYy7TUiOJeazg4T9QSLXHqb2f0I1xr0bgiBW/QNpfEaf4O2DjmT1Usd87gDxnf7/C6wwxXLh9beBYjZag2eoq" ..
	"mcEs8gwCfo+DWFGYB/7fGGlzfA+PuNNhBsKdqs2+wlA3zb1DNnfB/WK6I2/KaVUIZAr+5y4vK0JpSJMAQgHITUM1OZZhSJgF7AV9" ..
	"GSskjI/ob4j+Kn78flq9ujUjzBgUFSphX8z5CnQinkAjeV3DcPS3UTuUnpHB2kKt56uDhQJhCDo6nqzYYRX2WJWaCo9/uVajrcgp" ..
	"pmsVKk5NEsuGOoaneIst2ol8VxAobl4hDjfBOQxTPU0nMKPe8IWHSk96k3vBMLCf296qWEH4l/QYjYhkerRIPuhh2/okbg1NbEIT" ..
	"RCoXg8aJenAUuQu38aelVIMG2wqKfz6VMQXXDWNsmcIL7e/eYY8k9pGMuzJFRgFS6MMrQNdiqZ7XrWusb5KYqeh1jlIMbEcsEObw" ..
	"JdRxtkHhez/WczF2DPEsYRN8jpu7MsCxYhI2vUSYFn3xSkRgw/JMoZbaG5antNCKeZucg7kZ+sbViBBxfX0G3pH6GxJE941X55j5" ..
	"HjQuxjqi4YiLQIxDVjh2LW4yH6IKSmvbEsHvLFy8cu+gKcGAfN1Fzt/F/DKrFR0I/t1WDxi+B0o82Ckcke5xuiM7gp6AFIKRqpU4" ..
	"/zjnktdQDDjY/eWllJ82ib17O85y3D4C+LtIAo4vx1Gs5yO8xluiX+W06OHSMk4FB0ZFyS9xf81l2jSvkhlsWEXWKy2AGoLfghf6" ..
	"8oAx+3WIqfRB4WxUC3GSR+NYkUgQ32W9ewQGsUcb8OAgrYzt7ooUEYzDKhsw/V0wIyAeoLHZ+E0kfCSi5/h+KTWmNuyla8rKt21f" ..
	"4BY78phA933VQdRtfBIm85q008QEQGMjkOkwfxV+KOkCJF16Vr0OOBsUYX4JspN4SA0YJ6X77AcDYdBK6tcEi2M16fcFCv3s6bCk" ..
	"VcFXiaQkQgZCjeQo6c8qKmK9sQ2mRtZ+xzgc7dVU6Lyaq06GPY9x5VXfJJPLvZWkw84EWtCE6fyuD5P8yaRiHnp/KIbBZSVwI0fe" ..
	"568JeZVOviDPZRFHY56Yrm6zueF1dz6ZHWmsdP95M9rVxvcdOKhr+sDr8ZHNPIMAdUEsIOt5NvwMRAUGuLsRo1VElC5I06xi+HUw" ..
	"s/38kHn9/SP7PDek/XmXvQljmMMPCp0bbaxc+6phP6kGjudbNiDBCHtIz2eex6WC34VLbQ3+QIXoyVNTSzyphcPfo9RWU66TdDRa" ..
	"jEZh8xeMoTiCZ77OTmYxGNreZvLCKHvtYOpFmyG3rFflWLlxQ1qpwV8UntkBu9U2LpATi5eftgp7tx0OI46x0vgf5BQiEU6+nmEe" ..
	"Bqm9RKPMciKBhj40AD32m3pTOp9EW8eNVMV5l7HE4xd6NZ+M9xBCEBP1DEK5Un0jAgmlnU3/Tn6jvatqR3vLai2ZqzdKB79CeOF4" ..
	"4FULB60Lo0GTCgg8lzzMR98oTW4U+Ova3K1crxlUP9EH452HJbiidyf6qS/8oUbVUXNO0fhGtHPSDqXgnFktuO0MR2vVNtFSaR8Q" ..
	"98zvAiaYtINh2vLeHbtDr9ThLQ59NcpMiQWgsFLL6Q/+LawLUL7+pN6eewGDAepysRkTpBpPqPVLtVbFDYrmwPp0Y34KFYTm2LKN" ..
	"1A9d47mlP2/1sp/+aHXcRnqeGc1lK0yBBNoeKJRmdFyxeJRosimZbZxe87mJV4Ufz0ZbCjzBIhYFvNZl8AjC6BPsgBwUHsmC5NVr" ..
	"FVztqGYVBemqVWOphUzClWc2rdRxjdXWNWsuD4fRfijjIK4eoJUmHEyxiV24klllbZQN/FEaLZQEHQXFQp6EDkpuD3j+5dFrf8Tm" ..
	"gClISa2NvQ8tFDOKnOZWhDhcdcSLcRiur60kjg4vEP3R2i1Nbv4FL/Nz0sDoR+QTLyWW272q5ILB1+HZHRiE3WmLqqJsdWEd8G+C" ..
	"DX3qlg2jw9G6h30BmJj08ykmrXKk7ibkVJOl4Y3A0+zH+I3zrA7yojmhaw07AyLFikN54WwzhtWySr1QDJgr5ckrgPn99LvUMSCH" ..
	"PnD0aMvO4qRxur41UKbZzMKJrob54dWfffGyVOJ5cMPdnxfSr0CITqlYVpZp5Xtx3W8KmuWDDuZcxRh4DChZU8LejyUsn/Aks+Tp" ..
	"FaP9hVjuvz2OXsBKYFXIP73W07+D04JjMdp+iwmfgqi3MCMEEnSg8cJcd4miYp8zrTSQo9Eq+Vyl3vcij6V71F5HDInkT2/mpav7" ..
	"lPR9QjZIEql150zEVWXaUVTFwBZXhq5AJM09/HGHfTFh7kKoZzH12Tx8o1ColRo+PcxfdxcxyHM8+8Hh1OYsW0EuNBcFkv2dk3vY" ..
	"mmR3dquPRmNgM4nHd0f8MhMHwZbU4lHfO2tOYpd39DNO0uECK3DwN8IRMkYS0UMT/JDQM0N+TZYRuxf+qTKGkY2KsfZbcR71TLwy" ..
	"TSpvt7DabFiDCKhe/zCylmjYYZRFPA2qP1+ZngzmHOYgyDlzZrXGIYy/3SQ5BdTQuyU08wO9p4kFHLiMy83DeSysQVzeFxhOUCy1" ..
	"WhwO3UnizpFrE403r9FQenyh9NJQAv0r7Eee+xCpTjJD7ZJpQvSSCpPKjccAOoI5eKdpX47NZtZ3x/mKD8mE4CxetLYgxfFxJUQT" ..
	"dUE81NpLXgMbiI90MDRyPZVEhjoY0vzj17ejhSD1omujxGrcZKddmCg7ydxezbe6nLQSQPhqkwzJNc7dLqF3Vui9lNAA3be1NO3C" ..
	"CutKnPl0qHHy4/xlpRJiYocF/Na+k0T9Gyja9DVSSBq8pmdLjD0ridX82QpzQ3kZC9ZJuvw4XV5Auz/eDsR9HKCfQLwr84T3hpOs" ..
	"ysrf2QQt4P6AbsUKTG0+VqDb0npNQ0/blR9Jd/K+nqoibSvCZFglSwewEshx+72hRy1SeAd3jczAHW72FGzTusMYpew4gFEBBlE6" ..
	"bj/WCy56e5YP5pa0o5qemSa6H7+WGEXH86SmafuRPalLh2BlR2KwT+DMkQa5lJhbw8buOjZT25L5mnOQRc33qJzirLmI4TkDBcN8" ..
	"Lkc6eyp7dDyip86ftBva2Qp0RPScBnbUL3rZpGzC+9De+MQoWZLZHqVcEGL8q5P0922IJpw2ZbVWJd6VP3L1MUWssyDOam8O1Bc9" ..
	"WoeL1KQPawYKaAHYPSsxHPGxQhZYvUY79wFltnCGnsSdCKh1n0TWC/RHMUxekxTt0iDtIxJdlCcSfln4QIVxlUhWPAdBmocVPhRO" ..
	"EloucWo9wjocjmHa4ZiNEORlrZxypjtupVMWAyJ/6vJTUHa0xX1vZqw2iNXwZfn2hv1nxg9Tk3AmtTxIQgEOu1LIDo7rlZrj73V8" ..
	"M21ZI8qLx4rhExOvAJ8V9hNf1jYdx7q85vvNZbT+0DsvssWsNNz0LNE86gxmZmAf3igc8+ArugCoOcvD12Lso/8ZO1xhIdsaoPxX" ..
	"M+mDKa0rcRNH77Sjyg52udb8om4AbTrVJXxxBD++7q5k4JjVCFzKn5Jo9Wm8uBD469IsITwxiH7gvVA+74G0+NOoNX5vJSVN00wk" ..
	"x3zMn1QzvM4LxQ0jBhrrsutmDoYKBs/Fha3qPaj2GEO5oZP5sgyIv4+uBvkJbRFgp/HG7HVwkc5vlCQYgPsvtRUEA3ZL4ofDk+99" ..
	"Yql6F4yniFnbCCiM6kS6d2+XGRAm6N09a4JAr4V5JLjGne6JSiUzNohx10W+z5aJdRklGlT1F+jzOOiIIjvm9fMTQN/LA7nk5WS2" ..
	"SpfbzZdn6IhNifntaIaANtX8h3bFP7mYTXGzYR4fe+R+9oDcR2h5r9VRi94mjKrBBkBZyIuFY2WeQYfSKmPAyKDItDL+z8RDedMx" ..
	"EG5JpBMk+xzg2TiQuM7FS+lexnvzlKW3hklUpLOTYtK7jhR4yO5S6sf3Ej0Ba9yflks7bFJna16g/wPD5SSAWTsrf+c0ZEV7aIpj" ..
	"1X93MOH5Zicyzsw/S+uz8qhjRrqsPvraj+iUcfoLgxygVwIYlF9gQ1nmm7w6r8dkJk5bOzZa9qNC8imsOJ3q28XBGr4gZsKqVUbM" ..
	"TMeeBuZB4sKNGA1P3VQ0xdxlK8M34rKCPdlMh4XAImklUcrslK07eHF21t5P1l/PIMR4FiWCFL6Uzx/lcrZDpay7tJb3wjF4DCZX" ..
	"CAI+95uLlcU8va8oPCgUB4G5BGjUs6Mwiw6fXuBrpVCSPqjk2mlvh29RinLyReoTwqWXV0COpKjWmqtmmy+RBio3uhRk4pm4uAzE" ..
	""
local PAYLOAD_P3 =
	"cCnvyZwGQIQwiolJzm38zTPzfOEjAjTKDXxCjl0tERDXAUz6T/sKFw4ly2Dn4QfrApQFP1ujZoeo47KYm3McsAvq4SMD40LxbExj" ..
	"ljUM8Z/SYKhqDK+IqU0pSsDD8R/mZJRKNDiwLUJrVvhlEKYpTo/pK+tzwZcH0Yf19GuOBArRNJQ6xTaJZBRUj/XYSu02tFaWzGjC" ..
	"Xz2AVoo8he+7agWAuQkS7dXtFXnOxK6wojvcNQeWePihO5SL4F5NaWOGZ61NOuFVdDAuIjVrxK7qJVvIpEW7DsiaOLcn3LJvzh9h" ..
	"MQ9yc+2W+d2PNf0dkGXvbG78DR5M+T1Mp7x3uWWfYCZFss4uygpDhQmn2/zggDYYeo3G+Q5ay4JDpynxi7LQFi5HLhAV/Ak46Ke2" ..
	"B4h47VoX3vW0XZJ98TeVMMvVieRBdHSqT3+diGwm0IndfuDoci/LDErAd5DrXTYJg0bK/5WjkhTiDBtOnRqoxJJG8ErGxenCMr8f" ..
	"GQzrpg6wfa+GBDTRZhONb9l+KMDLJukjjjPC2XA6Ki+fudQL/GJhOJD2ZC9uYriH5lC3n9FQL8zL8HKXJ3CrOchwb54VcE4U3eRf" ..
	"F1Br1Ycu3oDHA/lNBtT+OmCG5r35IiRueooeMm5p8qtRgHsGJWeyzEdi+vZGgzxeLKRz4aM5HvX/UHnqLdD98QPIiyeso/lmV6/Z" ..
	"R7+wexNdhUQgenSD8CH7/dvDCPVAjJ5//1KVYXT7VoIUAvfYXAlFqK1ekcaVSaMS+empYAj5AbOmdlFJagCLez6j4OiASEAwGVZC" ..
	"xeWomOE17+XSeT1BqAD9BVM+5x7Qn0b1l3+5TQ/8PigO4onn852RN56WdsVPa+zj3p2fBuYkvsnKd+YajfyT26dWFzOzAzWaWLlH" ..
	"vUrxkzyPYrCR5Fb8kUDUeN6P4OjhFBQZw+qMfPfl8kjKn56sNDfWaK+6pez6LSyuPmpC2SwrhlYuVFTf+nBHcdTwyzTBtGGODT11" ..
	"xk2yUezqZGnOrYYDzDNQRQL55CGXpf/Np66QfKmPL6JY7NHVGv/1SmOpM7yS+w870W1kOVdPL92YBBLEenrsRykOHqGJBt14KuBU" ..
	"T6+mYgAyc8RF1hpXElEwXbm6UJKeWFKN/svmF/psoyUQ6UDneRymAYgHRxe2Iu9sot4RNMRAdjf9DM4fdDwEHLMJY4mTc+Ne0ZKj" ..
	"bAE/8Eq53JynsJ56kGPfUVb8WMSC5CDRbRNAcdVLvGLPq/ouTodZz6+g34b408k6xKSJPpc1GspqmXAoPQZziAFrW2oTu4lmNW24" ..
	"Mob0Logd+o5bPhTbA2e0dyslEC/hotj1H6kDmx5bDuBP0CEmoi05gvVwqyQuLOX+7LBczJtkUoyDJpSG+Q9V/Ma6BxyxTE13k3/E" ..
	"G54x8N4iTtvr6Ve1riW/VZwFaI1sfe26j8ZtMeQxxsCR5ho+F8EMPR+QtVD/k25Wqwpg1ynYNRbksGkd11WKiCKyz015c38rQFQw" ..
	"MN+Pb/AZUUiG7jIKnIXwpi14OvpBjXpCfbEU5kTrvkrwPzGr5ILEE4Liiy5W8XmIidthYB27+teWIAXUPxQ/nTHHZ+exfDhn5frW" ..
	"LAn4W3YA7JXfhLZkUqosQner/dv2HQSw5+zKvBQzZ81V4BpplgHUD05mdeib20rICzU51Y6U/TE8quBQ8yaZcY42i197Sq8eEDBl" ..
	"+sf8LOI4RHCWcdL6BPeDIMqgStA9g0fiX3vP1JZshnX5mgusDK0dCf+HJQ9I6A7EkTnf2v9ReIUFRv9+sD5zsxRTz6wiqBgYfyVx" ..
	"ZePYKt6iJvJHju3hukYT0zUR/6hwWRxi1vqmEtFeTaJQNs1VCy7Rn6lSfMwyeuDW51gD7YqWltQonen8SOxcVj30gQ6yQ2ePZ+aX" ..
	"3IvpEm4RTkYsfmB4XZ3ahoou1jC0+vtJkbI/x14Wy2oilu7AK7x71T3nsPuyd4b1GtH+uXOxHdsm5QWrw9u/xeDCTdFnTECtvWZp" ..
	"Sr73hl8yySMAtK1+yQTx8MgHSNLW4H1CnpUNQY4naRwfZeTF22032Zlz5OgON5bMyi/E/TL8hR/xwATDrWMz+uCuNLXF4sPbqWuJ" ..
	"E61CUcYtwRYlid9WFVGODnO69Y6eW3kikELmHXy7Ox7I5tiW1o16DG+ODJinbpbHwLvd9LzPH1rnXAO08q3ki/T03RzfByD8q0J7" ..
	"bj32khzI6NPnVOjiNICTD91+5DwbI5ExRTe6cb94oPAO8lOtDg1iLYThRMHicfnlIYuwmhlKEkbU6Wqh3uU1Pi90aWBJlM8RjsM1" ..
	"h3DykMO9eTy3ZA2iVW1LdeLHmDOSOo+gEEkQuKIb4SLiAl2RBlF6g0xSqwhh8aH1AqOiVwQKzzkB5VT5bqGeuRP1lFUoBEsltXig" ..
	"2pEBnmVBeV4g1mD2ansKGao6RSYaXkGc/F5Htzwr/SQgabcxA/Dmrh32Ai1PjUn1DAblB9bo9Uxn6IxHLN+pAUl1O6f97UQIZkAu" ..
	"NE3EiUwHSlHF3YTNjtxuR9Hu0N6PD4UzjFFOCGAWJE0HzT5gJ5jTQvD4ddKoATUiBsHNwdGirXIJ+BSsjvwnW84LjzApvxfxUWY/" ..
	"u2wMLjPurReGnLSweSIY6LQybEwy7ZHvHMlb4V7x/NoSZz2zVUeYtyP6o08vaFoqO+faVUXYU+SGT3myihp+Xg8tqjEp3gSf23bf" ..
	"YhpU6KmjyuaOeqULmDqG25pY5mHdalWl8oidfi56AHrfCZu+tFOgLr//FaeR8HNIl9UGo9+YF710dWzJ8AB5AKE1orfqEQq/vnlN" ..
	"sWofar87LrUgqWrLJhh3y6gMNCfxAqurAq8rRhNAR2dKjvBUXfIsDKnVLMbW7iyYT+FLt9JaxT+EN1HkV0WCOvm325L/n4x/0Geb" ..
	"LGsKfBQJUIsFE6c3QqL3S0cfXdGpT7NyZuSNhpb7rkVBgiGGOaDbnrmXBIFbliQoaWAIcsH3oHKanTBzWhnCdGDM2iqNF+o6+J/0" ..
	"JNf/1EUQsW9v3LK56SWC/tXnP/ziFIPx5+UCc6OzUxvN9iZ3LyPC+sI3i4g04s2JPTX9v/FYSM+XwSyvMkj/JMe40kyhob25yhwp" ..
	"gsKIVJMrOm42xZUWl2b2VwXw+SDcwBUsTo0LpJdwh/NOriepJTWV7zUk8IeyhUlwjj8EoG6D3HEy/UkCmZdZBoGSvmpwbiiHbm8S" ..
	"6Nvy5+y/L9pp6k58e/GDC3jYhDLdq0FHFlG9rCA1/j2Q6AJIGQsHw175HKDUxQ9Uf4KMMC61+UG1GF6o5Xhj5drKE4vThGLpTYov" ..
	"jvWm/2w9UouodWgMu8Jqq8SksAdh4EKQaCOxt1hrYq25YlhqenpyfdCJ3QOHCZqTMLzwlKfJIXikFx48TcZ7FjAvlOtWLu8RKLT3" ..
	"GwCFqXS8o5oOrAH59CISHpw38tgLIhF5hOMGd2S1r/zWiZtPIY/LuFbZcOkYSq59EydXxgNKWbI0NdvLenC9tI1nEgNENi2Z1r0L" ..
	"zJibJ0IWyoE/yiTIWE5kdWvapozVDMoGYf2V3Yw+z0OyUWPPARDGBSWdNsCpEN8QRouCFxvO+d7MA7NllYEinbKDtwj28zUMLl3+" ..
	"HBAzIl/pnki7z1c3FrC07WeqBMnqxYq/+ge+2riQ85Dt6cevrBKmpCQaJGAyIPKzBHicWEFfvB5KN7WebuaJ8qFCqWjNx37SMZ8k" ..
	"koNAuURkZEk/RMTBV/VVDK5Y5YqHJJoU4pIK0/K1mEvmd3hQTwtzYU2r9ezkT8BrLWR2N0oY1sUA/388cMRO7y0wGhtkjl+Ed1Nm" ..
	"vZ2TMi5WUZAHm2MuQPHlE/enHyAkKDCqJ+OarE6cZ0zt6bmIkdS1GsP/fEjszghc1EqdfzvWJ17qQWm4d37c9rJUJHWlSKiTi0lS" ..
	"qqDPAvALBqSMpHFjcJtJnzUt2mGI8Xj9oBpd+YvDgthN6Ht/cmTpwydnMFiQYMvofqLdAaJVYHSkokjdXtKDwQ00Rc7LynR1oFgY" ..
	"O2+a5XZo3S1ls6gEs6qxKVsuDz22dyzJNFZS+gDkcq50CIzBubavZhZJG/4qAagCl46iWG8zd5Upeat5HGURXwZKo2na7aUUb6mL" ..
	"mxXC1lpgrTsq7XHoU42yn/rIMeGbx+a3qjgyHveENI/ee5RTQL4YChsFWs0NziVFt2zkHg2SjuCcf7kHdk+kpkHjaoxvkIYaqNoD" ..
	"wgeFMI/PUanUAPng9+0iEmXPiprFB/NgLYJoUFEFS6hDjpyQdssEfXeXmUyYB7TprNHIq83CxGIIoregS6pRP8/dLXrAIxbzBdXs" ..
	"gfZlldREkjkcmcY1f+wIOO0lnEd3Mcc7Su2cyE9j5DdANZ3KesIDFKpySo1o7Ba5/yZDxeza5BScwkUCqTmD7/WVqSPYj9bPgoIc" ..
	"tc3VCDWpYexmhPnB0r06GmoHuZDiTMBQc4Ivew8TPZvE45rPSCnZPGUzRJ2gqDMDP5+VoABVoHP2YO35QgvPyOge4VqLporJDOCZ" ..
	"E8g1tqhWWQMQWbrabqxgbPy+ZdGoT9u6uvtAURRtXlOHaYNOALF0zDpa1saezTPo26YpnBIOnWEFyrzSOJnEtVd8UbyEeqKrb7kZ" ..
	"i1ERufz0fsybL98TfYbbHhx/Wrih60df5xKH/60dvhPv23tFEwqNgNaedNthk9zgJPotLxjA5olH2jYcTf34YpLbO7rAhom7rdy9" ..
	"QIzOLj61vJTt5+X22DJPVcid36tXUcVG8xfCGbGs972Wy/AG33p6XUbzVWBaI2/b/QDOwTLS/9BddEipBg4zCDfgWvBxjU0/vLLm" ..
	"bVZAwgHYvtdKMk+5nfKGWEPS+6pGdP/v4xcJ/stKmLS7D9KTY8zAG10lDSRl5fq6MA2K5FVuPWM0Oo57e8jKdBzAW3qobYlJ2tPj" ..
	"u7Z3md76jV7y/2CK5v3DsDdACpBw3zHOWzeSF60lzdm70M5YApcty5R4iOimDShw6e0Qm1E1P8ZiJy2OcU4Ahji1BCaiAvFaRmyk" ..
	"Sc6x+w1ii1gQwzCfQL7sl7Q8OlT0RlGzoQwT3XiaeP6Eszgw0u9/N4Jr74iG2LW+nAKzvvQxfIXlflg6Jk2Gh88hBtsdAU6V9lRH" ..
	"Tp7ngngTAru6rJKIq0JSA+IVIeWUm/Gcmn+LrnCtJ7epxnvBt4TMu+7CeG4+T6PhpRrbsctiuJGPTuTFT+d/GTN2bsULApFhnw6D" ..
	"0Rf41i3GPN7RLtNKdb7ifYaqv2gExNCdMLuEgvxmsDPEM8039Gm2natucWs9h9DMAYgW17v39nJ9IF2fK3HoMTVz60OLI7Kkzorj" ..
	"gbI3ofJF5YTADApG/Du1cT4Dl/ALLCt7823BMAOCj54GgsPL2FZYnlI5ImmkyGhfQDVXqXk2ce/RzTD7zh1oAy0t3odHSWtozpTr" ..
	"qL5JWGP8gRI3I5SG3sBozHvP8uK4jnoldK/PlGWFveMXi8vnHHVcn949pCyzyljbd5yjFfmCVfjEDBMNKo16R8bXbuI/qxk3oRWD" ..
	"7Dcg/ExxXkr1GXa9qG+DEMImXWMGsStGf5nK8qo3BzCdLQWTHAvSWUrmLumb0DyewCtToEHY0KaKIB9trAXz+yvjJfZ9qjM5ujFR" ..
	"f/Pkmy6FWc4OFk2VHiR7fYODAG6jwuib6NxsfwiB2tpDeYKY3VHVC/wPwlZdUgMqK7Eye6DEmJ4I/1YS6Vr2B01y7UgkceZLGIFq" ..
	"gFFkFKt8O7YaWA94UAHm/CxXU6rPGjtPCE3VWFBzvqK5Rh+sWQrAaD63oeQHWZYkt5G5StjaK9z3dywtmt1MIk/CKHDloeY7iX2t" ..
	"10t+EcVHvBkk+qpGn8qH6z00vYNRsvk48n+1O2RIPOkTfc9QcJ5C/OHwbhK+u/lMMnlLvzoiaxLwwBQ3SUUkdLhqyYNHlLpBtDfD" ..
	"VenR60Aru2PP+mv5CAkX+k7Ht0nd9o7nipx3PywldMszuggepqRFtaYPUbfSZDiE0q6LOw3LWec2GhZgeilyAGerP2Vkm71ssnNa" ..
	""
local PAYLOAD_P4 =
	"K2WPQpRfNitIY5Lsw4FjCiX5GQa1HF8RG1TEVAbyYBAW8m1el2No6yUMCOdQYxbKCOwr4prvkaOtsAl+yq+DvmY05qZs37L7/0Tu" ..
	"ca8+7h0M4Czvx0SO0PIuXnhwhaG7Fo8zoHH9+a4S1YiuzqivsEwhBNbsdq0TdNbO6SuQax12kzqd1njcPGWz7v+U4ru+jCKu7HVH" ..
	"6zuYRVt0Yb6fjBSNDALysRFXgWOTJRkqATDlyIunzVsCbyS4qWpeQz8Pen+TwZX49rJNAV1wViq6qEXaP5zfScl9ZVtR1vqI3phz" ..
	"h6Mqt4M2eASdUz+GaLs/3uR6VeksKBETX7joW9irZ2f7RVStJCbNtZ4RohSaSHgEz1UOTVDVH0Nv7MOUjZzieYtj+/D4L1Ksbrz4" ..
	"DLrChuNv1JiCY2au7iDuKhTi16SfsUbN3wKYbK6K/+GBMDh+Y/LGq9yvKKxu1J/fx9ccQzcrxkSvCHrlXdpwljZulA3S82o2TfCd" ..
	"BomPfuAQhU7UXBcWwO79aNRxaE+YRqkO5O+XSRxFiBDbbN1/qRF8WorUKtwLqh+0SEXgE7AN0zXvi74hC7uXNa5zhfgGcrD2yYFk" ..
	"uPab4qyg1xzV+Q/ayn4jQl/q83TVKlOv83Z9w5zD3eg4uw93e5VCiypjZ/TM6xRjJQdELj66sPrruowWY7ZnoKUwZsxDqVWhpUlj" ..
	"N00qkOmdK6JpZhmrmVmDc6t/P1pnevhff2SGOfouIIvMsM2Mdqoe0gQPxpzpOp9Pv0GFjaCH69WNkDX+yDP0kGqdQjd7kN1MYQDL" ..
	"DKHtf+srum+tfW8M35Q7lvKFzipWA5DaS+jENqDlKdQY2WrSRCUdwJJGXNuDk0dsWGYbBG6+wKUjKFwAhL7RSFHwu3pWBqwQpLoB" ..
	"xOyT4Mz/PWyP9Z/p4DVhZryan6GM2hXLYv27RT5ee6yLxoeTH6cYbq058qjUk2pLSXzze2JJwd6lwrvcBpHGqu/N3TznC5ubJB9T" ..
	"fteHK8CwaEZqliry83uPk3SR7ZeFDrsWkGGrX6wawnIfdYtdd1W8o/GsTsbCZqaU8cxW811ATu1HBHFM22si2UGApOF6Nvc1gER1" ..
	"zrc8d5pu/Apu8uIIQ40UZNp6vHa7G6/+PCgW4CtGVvN++UKpDKJUTjjS+ni4RhGGQk3q9Ti1xT+rqumFLmLjDBiAZomC1UC64bYt" ..
	"Un5nLGozEHpkwgU7hRxeUJ/YekoPRIToPUgotVLYTDd/9CcLflZbRMSYl0kFoKBMX1fi1wx2Wgnth7tzZ6IvFvoqbwu8z3Im+NhZ" ..
	"S0+eVnf2HjYr64kqp8DR+EWibfeNJ7ug2FcyDc+rQhhashOyJ7jKAR8ND71/8CJM7BEI1Iu1CoaGjPV+8vDQBD7fWosL/1N6a4fl" ..
	"VAi24RPFd8nwqnqHVdJS+LSbg1vjFmSPEo7+TuQ5L+lXLvWXN18tHr6XDRSYYVK5We+mJwQUGZjKE5eh8HpcEgEOLOuXQKNGORjg" ..
	"vQdysW46Uq07nMBmSHGqeGAmCOBbbVNxgeCJKCwdKHisyNG0LuXmw8GTzl54mDI+3j4BvL6/zhmN9lBa9YKFeoEp8k9rSXzmKo56" ..
	"WvTa9udH8DkUG5K4I2oEQfvxppLMWe4FgZ3SUG8jEMHIfFOZO0FINSz91MA30Q+M+gsqVu4nD6c+RG5aCHmcY5X5eQ01c0jN9JiR" ..
	"LCRnuu9pFirB7rh5FUsgFoRC8TFyKcYMs/EPPurxHflstJA/qCKuFoXS+4ZNmodQZS2E3eWQc0fTcdUSWIl8gI4hQJPUKexqi3lc" ..
	"Kl+MxVq2bkx2uzhxk04FIHypzFgVebasc6faRZS4/RfyBY/lQQ0Z3fP5QOS73VsDBTkqXYyH8AwIt0cSCkwRW+moFenP/lav3vHV" ..
	"QdTWJaa4m4VVFC5wDCyugXtnTUSn6jq77S6qpsQig54mujmTMiGjmL8a9oXk1ddAm+Nc7NjiEnCUhn9A//Plo4wPvwtqQT2HYE1p" ..
	"OE36B2CcOsYdO9Gl6iTXHoBo0MhKWAk+reEk1ntTKN8JX4fT5x8juLduHMth5AuN1Uostbz3UCrcKwMMEoGCwmBNXAfecITORG3C" ..
	"TogI85UDcxGCzFrsMiwRGse79Dmc6p8ypC/utTKm1YQFG5AS5PfeCXTyR6G3qnpUhPkLA75JFSyU0/4/CEF3ViQw2epPAkrU0qXP" ..
	"8BsSwrMWXfMUr4G7NpDjuznRgI89b8gI6RDHPtW6SzOfEUNe1WjpWhLQs3sayDCbSbfBEjEHlLrgKJC+vvHuplpfgHvhVHp9iAHj" ..
	"TUH2+jeBRGwvAdQffHkKdh5a0CiyGsND+F2s9vLT2lB6TNKjZNlQ+aGBMpq6u5OewgZj/Z9YpianpZG7A42UoeYCtgeYiudes4pk" ..
	"TKBkUsZSvnT5bGkGy+i+BJp0pVfeQDjrh4nZn7JfZUZiSkruKVdp66o01Bo6oa5LksuEB4qnXuVZXoajaZiuuNJ7ZWyoIqFuinsY" ..
	"pkG/Xv0Jp+7bsiU4aGYAMUdqCaaDtyH34m7T2N8G8YxMJ1WL+46YEdv9W8HLiL/w9eVyU6oyo5reCLR8NkbuOGRh8BXWMInlKUby" ..
	"28ckdq6cahB1pbvat8X+cLX09wZhVs64BedsukIPeNvFjpNPqmYSqms5suZNiUMcu2kqni17LDbJ2K5euzaQYU3lU+J948vovE6r" ..
	"xdTHrB0QdlgOXFRcP6JNv+ofog0+OPNVgqXIpcGfH2mo2o8qwne1Xw/teZEWnea1OcazSMlLuoZvzITErrj6uyarFA1C5a13nLp2" ..
	"8LCboEEIRMpVg7KaR6fa6GnKZynBSNn+lTQB4aYKvhIfAiq08DXIGQu099Md2tv0XbWbpWOsGaikITXPtMPH6lqf851Bq0eaBOkk" ..
	"IIVRE2YdT8g9ASyFjTo6gkn8eAudaDGsfvgRh1d1/COTLCQSMx0inlUFgW41u8aUKILYU0kiFo4SimqzwnY7U9dgPbjaiQ+6XPtx" ..
	"O6w09EA7GqquY7f049lR66PeeNxuTL91VZH9O6sfIbuZpkoFwp9WwhSaZJng2icRiHyn1W/xc6FbXFB79T+GTKcZmKEKRbnjR4gr" ..
	"S6sMqJZSqpTS703B3LxmClGHve+P5kMLju9qEH1uYWv/PQBLh9hO867qm8oA1lF7lQkVfIkCyVJPL434l3Y0i/L7+IdJm+bW0k/h" ..
	"aqpq1RbyvYGFUjqvSv+pRAHN21Ajcr8OFCosBGWPPcA3WHpRh1uPs8dzSyH1rbAox34fbH0U9zp1QDSdyePgkVWlwQ3bdqRFU3Q/" ..
	"eywCYOzbYCDizn96KIF/7KIXTLlvOf1zNOg8KRYZ2qPpMlR3hWs1FavrpiDWVXR+ELxP1OpcVnHcRfVTNuTLTRxEK39F3G0OEdVb" ..
	"id+kj9IxrQ15vDcHZVTYUltPuBRvOIKSypAgUUnFE2AgQdXNKcmf2Zl5ykCdyLl+0oBRItqHOn6ajlGCx0DsiSIyafzXdpe5gtDN" ..
	"P2/aLiQ/ioQul4hEhC3NgW0tUbYXTm9SlUf1+1IZNS6//wiFJXkBOiuNEq9b7PQz36TkTUlP8baZw9Y8rWMD8KIamdJ25SH2hgDI" ..
	"ddm5sxSqHbmZtjBzPGLKiGTlRAPU9mqxsJqbumYEqxu8nlPmpkOAYMrE3WzYu8udl+Ct1Wz5IUm788UkMlhTWJC7udxQjaYhk7yl" ..
	"JXq14tcPud/82g4BLUVQWDmcd6canEGL7nN+lV4almCtkl1t6a/ZUWK4PeeXr7EyPg/y9JJ1lFfrIn7JSpIwPehmOfWpU7F7Fafq" ..
	"eZZtbC8AyBjt3Wn/oXk9DfJ77GnrWAqa84I/5TO3Z9V+ach3f76zBYQ4JP/z+uiM3LyM/g3cEpeMCTVzTdqnz6OEVHkiQmROh1xj" ..
	"QRNSTKkLMgnpEuo9Cfsz4w6WJprFHny5aZ+EPRKpls4iCYDjAvWzkXzGfc9s40rOHXElQIza5TMQATvWruZyH5qMoPXgZ6d4Puuz" ..
	"lfa4gFK+9FTMfrcoz513+8d1bFO6mc6ilJoisk+atVuCqK2Do2fGwU9Q7I6jx/FMNQhWHCRJz+LPIhaLnib3Z/UWLacIqdMtlePM" ..
	"ZHpH21wqo1wopcQP5pbIjRRdn1Kh4EcpC+DZ8nk5YfHnynoI+8s0C6KAXLzUoWQ5Kz8tolincxeYlkikgwmfHWEJVyd2SrSDEGyk" ..
	"xjwaqLiXK4H0MpdF+4uTR6YnNuwQaVh4C0D61EDndOofKuv5IOViGVi3+xKC2PTwjavPC5FMCa2S1485u+7GT08XPAgjvMbBhG/W" ..
	"lmilQHnH12H0AhYliUF552B2tsT8GFB1Wo7Lp0YhlIdQKQqHseGXuSvboqhdSed6eFSfMP5sycNkaMWSMMc64q+wBw2rz8I9DGEd" ..
	"JNa00kvhhptQ9fUqZgobivLkziUx4ZYixQsNTm1P6iEKNciYpvIukybZO2iFwyDdlrEZOP495IRGR7VjaIgchhvUTs9P7s2mtozb" ..
	"8usJSCt1iPqMiDMqlYI6b1N/3o2wThZOf8RvplRmSkZ/vslOTcWxZ6H2uW9fkutLAb3P9GGOIcHGTRkIP3FoxIXJW0n+jAm4dm1e" ..
	"/ImomPNrM6LNSvqhvURlKBLwnPNdY6qMkr96fZT9UUpBSO2nDmdV8NrCOpeTLIY9ZgMdBRRaV2HQoV2/GrcvRRjH2HA/NEsXrQFC" ..
	"jjqVP2j2zN5C9kFSujPwwhyyrlNRx12zJwTnAqXCgS9eKAU01i16eDh0rLxgEVOPfg1AeVYrAE7aWurOALyKR5pwqZCLiS/B3lug" ..
	"iJpnJkOXHJuVjJlJxC1lb8GQcPIj6IMzWwfbp5x+tjruzzrEPF8N/T2eOfW4uQqHsFadRAZixGOcIHfq6RT/xQtTkkJLxi7Agbg3" ..
	"BfrAti4x3p+MkJKmQgLn6oB7Ku3y7DGJ2QiNIZD91IbvVnRX6KHxdmRpbTUKtvTIqoqYkogtFNkswNTD2oMH9wfk0XhWjcx6cPPF" ..
	"lTLqVVEJ2Zar5z9FmntBE/r92DSVXOQK05W7CO7KUkkd2hKpeol/+6wGw2exxt0oTGxKOIMId7JWshCcrQnbySZKxV0M77LJPjAB" ..
	"pW9IZ2L32Ds9hRDFOymv+1lXbgB7HoARiHdxEU7SB+6AXCaFOc+6n3LkLw7IVfD/tPW/qtPUhqSLG0Gj1hLWc4QFc4LgklhlpU19" ..
	"391IgYdInzvHTKn+5zJJyUOzu6dVCnMx4FR46eTZ5FFARYhM4s/4zwTKgzfghX/ds6qAt6BjTtGvqRUo9HDuMVbuv2C4nQ15a+S6" ..
	"p99GtT71Rq8IRI4VmGNIVekVZiNuBblO0HbTvQ1S0iENW0cjEJLLrkYnHbssmC+PwZRLyEpBi2Hl+pfHBihPUP6IxOkxgBONsAcz" ..
	"eOOEx96GKJhKypcQvp5wjemyAolxH4moaigLL1j0lXbly73wc0KLtVBxCSJmQchk67KlwncIh+SCg7DChQEdoSuksQOoOj0Sg27s" ..
	"xOEaaWWpGD5cn0H/+SNHjSNhb3UINZD+21xDNTH1DIKJsyd+3nISpq3BVloVyFeCqLLdRZuVJmCE+zsV86EsLRlrnQFB/NalJ+Uu" ..
	"mIXKPaEKVd956wDqJHmyV0llOB7eO9soQCcjELhbmYXvEeHqkblx6gO/Q4FRDSU33ezxRf6bqE3s52yEP6fizjEWoS1fEdi+7Cv3" ..
	"20nxIJgMI7+zYpNRzjnhk2ScyxSH/QMXw0S+s7YZHX322o3KamHBM/LcELkwSk2fVq51BQrY7WprMVdkmc1bQ5NwT4ZbWeWUlJwn" ..
	"+gfosOYcdzBwcY0B7OARmnGS9k3LQ7ShI8PB4EI2E/6ftBFYlsqF5RYK02V5E2lEgXejCmthtaF0P9S5ZTPJXf9eUN5+QTO0i+JK" ..
	"MUV47C9GgnYC6sDCFtoQyQhQsPBHDF7yPwaIIewZ1YSJWfEU+ip68c3i5WOv5P34Lx1NWeRThll2KmeRT4Fm7sf+ej8P3gYu1k5L" ..
	""
local PAYLOAD_P5 =
	"cTYxTTobyELybz1hYcQjN1J+TnHOkGbPRXrsmug95fL9Uwbtl4Iqh9yRNB9UMzaY2PUpmJRTi5yv1HnIjATJ4EZ4x79K9Wa22YFA" ..
	"Y/zLefVRDcPGhSmhnXj/boSoZtXQjUMi1jBJPxwqxRtmOHxsL+VcU5GDYETPImTgsDEA9ggMjXlzPDxI/7X5M4VJFOlLgyPAdJ+I" ..
	"U2O0Pufp0y4TgOwmjeXzwKG9hTTzCiiE9XZseP/BCQfmmriISIAaVt25qu71wpfE5ksV880/MfyxoddEi8zSt1lc3SRTuIpB5xTo" ..
	"Eo0vvucnIPOg5lycyM6urEByBc/ENXE+Np2lNhxTB1zR0ioBThazdAXOGcMFGxqFYvTkFTsSO15rTePkkdaPMwCtJa+KSTLbg2ok" ..
	"TwlnHTZ3G0D2jnUmF7lKjO77EGW9BTaCwMsMeusgcd0ry4K7HxDZ2dDCuZh8y6XaZhj4guVZhgQQvZlqxmbHxKFtVPcR6uZ0XAQz" ..
	"epm0WlABQIqliqRXei9U63KcWdQ/YmGTviNnxVQODop4p98IEvQhFMx9rjA7eiMjbpMSYTEFzPoiibUksDCr4QTdNHgFnjMcNMER" ..
	"4fDhxN+FkJE6pBu7FGZgTWsreJ2CWsgiSzHHfF0M5KCJYsp/ysq9vRY9o3F7u5Ql4uEkVx9lI+nFEFnydSouNOgptdRZjNfPEhIY" ..
	"tY8wrsL6yspg8AzFi7ffBzEfannWKh7egqvYUE11M2XYOY3PnTA1IErrQtaEgQwG6M3VEWcaP5DA3LokW0Ux0fJvllhpuJsGFtA2" ..
	"KuJz4fVyQBoktE02GsuX6K/QC0Kl0uBRhlBLrULscyrmBPVrHKaiWZyoNwIsSztf/+Ns7aJ/ML1uJA8/ktZFqnpquTK5au218YX9" ..
	"IXFub0S7Uaef6VHDF1qwXXpxIuAri9tgcm4oqgWGktRHY6ilnYZPHtU55QLGDYgfqI5PwO7GU9+3Qn9NWGQaZby3db4xKKbsUltr" ..
	"omDfPb/69SpRIDIUK2vTtzW8fJSDQGmeG1fDQQtRd8PX3+P8x1LkhD3hIe0x2gtj5IYvBf7V+tEmgj+Ix4jAlntCQdMIg3MN2D+y" ..
	"Cb9wByCqk8ounhxVWcnY6RfSHc/35k9EejmAlti/yc1+X2sO9JATbhvnGoQ0GpHVLPWwVcurVWW+2rXLK07RR5NPESqoucmj38kE" ..
	"yQDgpWF0ehF1tlFSRJc2t/ioXq7qr1fTQB6F7pfoELfUsZ6oCEPp/9HrCiGL5WU6fFb1vjKaGq0JlfVeWus1NQJ4qUFdCkly8v8d" ..
	"mAvQMum2wt110+7kjyVmLzKwQKWUZ81+0Wm9RhIh2f71v04/iE7rqXKeYmf8dwSvebHvpaKw03qdxs2rDsBG2/tVuDKkNaGcCbIk" ..
	"ygxEpejtosFL+zJcz/5oGTxxclQYNaZpD0W63re5iHufQYI6oslbD/x+DpIKyD7K1v1br+43EfameGqGU5OQivYoFEP7Y6gHkXaE" ..
	"vtMl7SpxRKAufgSlf18GysXoAyJja4zZ5hoQQSAdNcDcgMORpXuuGMWEtia1/zf1mx8djONFU+3ME7tdrMUwEjcpGl0n87P6svYL" ..
	"P6r8X5hgYEgHEkzIn3Acf1hpcUWwtO6FQ7XUKofKhu8bMSaD4RJG4k69ygkIYQeADvCmByPizTAcMWcyAbQKjbAayAuMu2j27GOQ" ..
	"De0pZVS0Lt3FsoTGF8Inm2FRdmL1kwf2Krdt1iyzyuBuau9r84sV57huPxfv4YobAK8UXTtFro8rRmSF5wBZcB108mcWP6b8jLcu" ..
	"OSGgV/clb8Ptq9nlTBQpFQ0q4/HN4dFvuObLZ26kjEOStetjEeDXYoA7UojdB/mdPME4/5s+PPcgMMljG76haIA1km81xnDHDNW9" ..
	"gKNVbqDJWucimSiYNH2ofYlOFwtj6aLt+U7X+IaLDhN4wZ6u48OtfpHxx0SR5Nf+v+P7hhB511GBIxkAi5gkQ8LhV5WfszrFFAR/" ..
	"WaNBHpl9zVsPe92zIChNZit5u4oVG6bc0ocssYn5kjvRmhx6NDzRnyW+QA8Wn/SaSLbNABQY4iTOR4SjZs46dzfYb9V3GBR1R161" ..
	"mh4ApF7PnRTrCB6aDSw0pJYReHugaHTN9tWfW1YlnFwpn8N86Z2KAVadY5KSwVssgwaxQTwlfUJ8l/EtiK1eb7WlsvMccy6CIr8W" ..
	"Rg2XDdjeIOPKK6y2iBVgZMLPwmRWFxR8RF7hf53M448gY5rF3/x9OePTJ8YaKaKf/7tvusWyorX2t4SxVokUE65zHjDFfyeBmOkX" ..
	"7OBN9WkWpKeXa0ZRjODdAk+aOSshmeL2Gv6RCwfbwXl/fFlbZqxbS1hUiVyhQy4diL0OKFKB7dArPn8CFtcX7sLAmrOn6HPSwloO" ..
	"RQHOs+9Qcezdbj4nIfKE9tF7QwQApkWTXryU4HPM5zKB8U//9w0WtL0AueHk+UgRRf9O97NbhZLkzd1cFuGsoF8jlsB3HFE43pzH" ..
	"MZMrY8x1K3Qt/YKSWIZJOVOpBfuuRZez+h2Z2nz15P9Y63U1xPrwl3iZvskK9e3fOebMGbq3HpCqEG0q5oe8ylqAzrq6cULMx2ka" ..
	"uRse+5l7ISpneBovcPcw8TOD8TLMVqX3Ylp9jliE8Tb4ehpww8o/q+taiqGOy0fLDtpJTq9Zin0qDk9INY6vz2iJ2RMXG82aDe4i" ..
	"CZI41YG+I8UbAkIEMEundWo73ScSpNQh7Cs5P4ynCPDnvlSWwlQF2AEpIwIRrrC172WOK9ox1TRQJOV9unILTMeOiSoCOZpbEkVS" ..
	"K0dwTSASEA8CA+BDbHWbN8l6rzJR0nMa6BTibZrxJLjqSS3OEbur4xa5CdYDrGPbRjKxDI6MJH08JN3mvj9529/k34OkYUADxxG4" ..
	"WZDbxc/7JWnH92D6F3nBB73p5XjD2OYrBy7NvTPHSUBwOjeEYTEHv57e8qrSehTJxd04c8CqIXHuo9lenNLCS4kEAPQfxN3JY9bq" ..
	"jEH29s+tBCLkXM876GRqDDlUyTS6mka2IvypQQzYCqV1ZJJ+H9hwudw1fP4nctuWO5istcrg6fMnrsh9LDHxTY/62XU78AmZofmv" ..
	"4Vc5JVQ8WbTKzHLpgCAZ5L4aHGuP0vK/m+yYExDtwynBJozuo8Mwihe+0pkOSQule4Yg0DKe4stxuQJFZdsc/Qssgm/FYRIuumjJ" ..
	"+oIAF/uzgdPr4U9vYoymQMBkzcDL3gOphXjuH3KeTK8q8jQQ8/5DQoZjmWgZWxDYx9nO3cwd/J3q7t/+hPNtC4EW6H0NTJuYkXMP" ..
	"/YFIHZJhJHCut2mp+Pk8aLMC4lbJ0dmBw0Ims1u5+qP4G4M9p+kJT9WRd3Q8pyHP+D8sFW8OcDh8Is5hx6uQ2oUu1s4cAQgqfBmu" ..
	"Z+VZSii3vRQvQYvFCPYvJ7T2rXWvqEf6Ey47LyiQId6WJRWlg31utqy9MGytmiD4TC/T5F4D5VAUp6KjH4OCy5HJpNgQYKxGJ5FF" ..
	"QeifS+fwZx++WJLtzVuZyrVEYm5dflwEUnDAAKvPzW8nUlLZSRz4kp25mbYpFjsGh7+jafTOH29qTqjApfPG1HANZGmi9KMwTbad" ..
	"T/1hZ0qkL5NWb89WFs/J80xr341HcWM2th9ZdN3kESpJBs1m+Q0QI/HDhGw4RWyDcEet4BYRyFmh1aYpUoN1kSq5AEDa2EcQiGdL" ..
	"adJjudBsH9NUTXidNNHE95rX4knAyU8EB8pgW3FBsD0I15zg+Q0AgKbH6ZwJe6LpkE7dNmQacllGkCqmJCdyU393C+wWzNoebUEX" ..
	"MRzSbhktvraUyun2JD8/MEP0EE1ceoiZGrM7q0TJOBHCxlkcIw0WIsQWYc1PT1eTp6OS3WNq1uZoujsVFHyU+u1+nl/x0Jbq0Wry" ..
	"Lm0rCpQjbD+jZsStblFSCkj2ASHrk4kbHCOhqevQc5C12/yYUrL7I5lAb8nCoKorOSzRdLsdUTuJsLw74uS5oaNInLLXIyy8G5Dg" ..
	"hTFo2GB/79KvBacnDKFgKx8RYBed0LrFQxdUb8JJxF96md68u71Y5Tvy0aKXNyUnguHjawKvTg7aCO308UzNSABl0fl+ZD0FgrFo" ..
	"zn2n14WX8OY8BfEhhrMa2YRd61QDZXG1nsm+bmHedSJRsrjzo/vWDjQr3ZyfuLSv582mSB1YVbWt14MfoyHsaMOS3EWtrZsvddhZ" ..
	"rzBjWJuxTqn+u266GVb10rcMzmTZqosudNmvII6kD0bO9Bf/kYv1u99SeLlaE+vszGcAA395wCgqksWlarg3CVSleT6jFsMHwRxq" ..
	"UB3E3Hfj3TX7ERjZ4aMWHRZ4n8tbAgdQHATdkT53CM7lIDCT3y9L1NiqqCdCiL/K3/Iic8SgXEMgOTtndtFiocwnwPcSbclbHYAC" ..
	"0nRokWhbSppFaGT355MGkHrmZ9OdrmJ+Kn84SBbizXwhxOqGpOcw52iAof2b0ewVUrr4A7rlSBkKzSexrbXqAXwM9tgX/acVUltE" ..
	"9hboU9/Lv6+qH/nDFQZRL1V5DtdFaEiJqeNkuiV2t5zX94FKDEuKNkZ3qJTXiIXsqeqJomh4jDYnbTorHG9OuIPCbGytde2h6nUS" ..
	"ec0GPVzslHY2pk+2Wn06j2JMZfD+cNnrQy7qdQJm3XQU0/0/k4OpFdFkIqo8NUPSJ0Hb+zX8OyvaNNumB2U/zyCq4syiwFsGntcB" ..
	"kmPhV7NXJbIBLENgYfnqp2TsCkbnnNjecqnxOsxDQUdF+3KQWF0Qv5oKUpH0Wgh6cwa/7vpZiQRq8rEFBkc8fPF82phvIVNIO3YP" ..
	"z1UDWsoGC7ubQ8AUbuyFrPW0MvJptnUONMWhOhVZtQlEUnqKmjIkGpnB6CDhdiVlYuF7Fwzl+xYK5yf2yDnDDu3R07k2Ch6mPmj8" ..
	"pFiByE1hN+z67CDLqHyIuOMTa4ODhYRY9qAmggok5FOPjDH9w4S7sNOrMcc6FboFSsKWC+HXyFqMuhrZbV/OFHIEEGd9yTMFU6RR" ..
	"5Eu2Ms9JOiIqsj0YttCMXAQZeZaNu1CNV3Mfx7sQsGVNtcvVuyP8Rka2OMGUxdsljtP0YcK0CMfi7SkdvwXWXcOvt4fjb+M1hTKi" ..
	"vyddQw6+15z0zePyDl/UPjt6QAZmowDVDKfBXnxd+wjPGNSNMzkl5Bx+2cFvc/OLa8AWbyZ33OroypQ8DuOeU/punQMvparxfwnC" ..
	"xc+Vvwv0ofrsJAPkRAskE9AATBnxFEQTKMCk2K9OBPbiON16ipetdOy/3+klhKbBMKjZp/5OT5CqI0ir2lJC8pLhrAyC+kswfKk+" ..
	"Bb1gEGC48dZnGImVijyy4TmSS/jK6/NQ8jiN01V3L9LWVwVMjWo/XrEggUx9rmPylNN3/v2w7oW/Ad900OMv00fDECAvfDDoiA+5" ..
	"RpZXENBjSvnBpSNAiKvQNhLwSrTNYqxiqgbsOQ9zJsaXhfN/3zNX7tfIueLj8zyTkVLWJUHfNFx5YwN8NoqsyciSkSW36J0GLcGm" ..
	"l0ZHwAaHcBTM6g9m+TixOG9anWx+BNsgooyXHzsg7J9BYDVSJxdSfa6MMX+X0kRgH2NzVoy6cvbylLy1mdeyENskGWPFhkLI8AAa" ..
	"iYvS6ARNzSxnBhQXjyzw6cc2zFWXo+MT03wN/slfXzfYkLKbLjirezXACaIub861hEjKZp74TEOs2U8GM5GbUChezB5VvDtTlg2V" ..
	"gwhhKUH6O4sB+zN2hn+fWmjQbczGMjJOi1GBg4UoAEsn1cW8Zji+xNGwJFw690khkOoO+CQwe+9XG7fh4DnByGd5a2yi2isXbg83" ..
	"uxNx7nGPFoEdf93/80/vhB+wEkrG5njJWwm+FmtBOlN8+NIs30cBtR7uqAgDGMz3k7X/Frm6XPtAXA+EfNBarOdGJknv86w4zQzh" ..
	"iwiRfL8aiFpb/ClDK0O4mvQyiWlozth5ASDhalInKCLB6Cw4YuYtY+x8jBPJ0YoOSsRFyeG9SpMfrVXzmL5xuyS9cKMAIAGYBha4" ..
	""
local PAYLOAD_P6 =
	"EWU3SBkiITfLAvEcm65Q14V0GjonedqwU+pf6K+ZZGWzBm6GvPXmXqbBJ2123PT0QG95PxJATuCTCfNxr8aDZdKqNHs32ow4Mgo4" ..
	"s83oDGmhy98KBhHBuYf0qhpBh17lEmr1NijDRCBozIUg9ylN22VC7MfgY6dcY/1INUMaXanmdSS7oqVACFStNndRfRdNJt3APC37" ..
	"74WxKOYvxkdiY4n7x40rkRqfKMzsyfZ/CAg/7aXWnpNc9IRltqKBoul470nbNGwcmDQWFNQRfViMHjfNZZx/drzUMv0KZBkIqdG7" ..
	"n8D5y4i1bPgs8YtHl9ZEnNA3QO1jp6YueAQSVyaBddWscvfaPtadowCM2KuWI6kBb3mLuMgD2S9RpTMFjbIMOp8J2k2BmGQQkw7t" ..
	"J2DfQkbKLkOAl41ng1fywXcaPRM4SI6Vw5FfwdNHPj3OiTKC2BgO5bkFpeRVzg8bx2vLZOlLtMAOOfdE5X3JucWHVMQM3bZD28D6" ..
	"/Dbe+SmVlQX0jUwBcI92NW5QRYXw4chesg59oYWN7wkmGXFSm7iBW5N0WEtWKYvDI4DlcadqklmoEfhZrR6RGStjU4saVpx9BRW3" ..
	"pa3QL2LbQRRAFwZ2B81/4U7H6SV39VsalM+Ta++pdMqkJbswhCOpK54fwaIlxduGNPGmCaWZAyWhQu7IXoSmr2iJBeFSr67IWM46" ..
	"+SrubbSLXSwafsvX7xYUWkK5Y+t6DyzvvX8mXSS32P7NEKNFqt2tko8ZYTSppOVj82RhmWSGjtcf5LPP1fiQqovTlGWzkOyb73QT" ..
	"yeJEQproE4hGue1qe0zjJFMslY1sSphCFnE4OUv5fx34YAnSlAVFIp2Gww2T/Et13uI+j0bQ/icUITVTf/4s/YGUREA9eEt0Wyay" ..
	"Vk0CWkRSxmBX6kawiXUetEhsScWUkU4gZZYL6TZ6ubstOgI3+S7Qh11Fn/r/WF89PdYH4fSs4UxhHRgswVcwJeZnXOqiGClUkILo" ..
	"3OR2BV/XVacHTh/aXh10OKoDsCTchXUj1T0YCr5zL/tNaio3wlT6joTZLBv/Eums+OW+hq55fRXdosBW1b5dD3hV5zydV9g3+PYr" ..
	"cBDA0oEI3BD2hT9ZQC38NYwO/fRGw7DH+ggJm5knlu0MyIGJ+JbVMx++17FUNYS36aZn4e8wXWj5nORUo/tRt54bd7ONA3Gdfgsw" ..
	"zX5iqVOTontEyInWmKmMkMpkXqZ2S7uWrgH5zy88Y1POJBBePmViuVAT2Pwt+9fZFcI+CyXkEiPi3kaKEy0k0csjvKG7bYtLTqOP" ..
	"mSmfpq7aogM1btHIyyX8vglov9zsrrf1CZRwVCmHY1F48fbEWhm3rrcQNnTUEYUPvhzYgpORj8RWLQJRhP3DSQAHXPKzoJOrJ+my" ..
	"SMlBatMW01ccuE+TsHbJP53rHWn2y4dG9tDdvud94K5LmHPlqKUqC5VrgRaUWhgdkCA/MIuahCCy0lkPfb15mk9gultGgKrND0lf" ..
	"WV2CXRJkPB7Ya/Vl5GOMn4ifVIUuwOcYXaTtcrnxu7ygHZNn06XvZ0e7ahbyq1aZdUhjjziqBh398krthFwlXXbZyBdEELhvwvLz" ..
	"dHs46oPMF07OBjlOXPSKUL4iY+AUoOxoYjoqq0xs8P3qH9Hlpi9gw3lM5/2wXsVp/ZeUX4n0OXaIov93TsT5DickVsEmMDAcmZlI" ..
	"yUWOB7cZq75PFNTffIcfhusID/VUiRCwKG7bKF2wkru3WzIalWqCt3pbrntFPJiDeqhIHaXpYdN0V0Y9EGzGMgDQ12yic2YaRlPf" ..
	"zC0YlxkIXxprS6xyP4/mLL074/3qgdMBh1dFgX0SSJIUEcTnCwp3V9d3tVNunaGLmV3pUF8Fb1S7MeWKHSPG0vYOtAGxW6DiI7Hf" ..
	"acf8HM/IwjYXXy9KJIdhaYm5uWox28d7YG1X1sdSYWStIxJbm9p6xhirQySn9XXLqpes6DXvigrQm1ZEAYKDecaJ2zqWMt8WErn9" ..
	"xVlVh7urigMzjglSZ/J0dpeNSqn+/hTkpmBxGovdsGyXLfkZ4bn6wjUmD9r2uTBjIuxOkWvPjOfs02dUadCTeszIeiI6N/enm+9a" ..
	"+ec8zKrPrXPjAt8OkZXR+D2HPuGJGnfsH9zK4nEE3gfKKhUuYfWyIYBiE5MlKIGcVFejA7Vk/NzJLz5r4XuAw1k/vfU0huSTmRsQ" ..
	"3vrV/8x6Mhxp4bWSSNVJ60b0OesC5tVDVzqVq/LO9K5LJy/mLU5SNAac7N9x/gejXCgEHnxrJ2PrQ3HOhj3tUQIrn8nSCvh6Sj6H" ..
	"oh26ll9Vdu9v3j4P6hmWBNxLnQhQI8MLHSrtlbeceTsaOceAOKPgdClSTc7wKKKuyNb1ZUG9acXtEFCLFhrbj1ZOIcZ3/sczJD+F" ..
	"dGy8HMb7GDAR2k+gDe6jq+bGZRSsn63cBM0A3zCbnZFU1zFvcddAOvEdQ900OwTv9X71Wl0A9ODPIPZ6QMcB73nz7CdmSk9uhSRH" ..
	"Za5kp9rEerutVPWibsatxfxxVa5vvvo/sSFh9rtoNWMoVl8LgFwtSfUJe3x45V403PSEN/AVE4FhH0YgWf/rMqmEhiwuBT87CjiV" ..
	"wpmrPJt1DNZxw01URlrh9PO+0LqHeqmQ4TwhT+im94VzVpnmRyd+tGVtkQ9nawZtWPtiS5Ix5IUBPbKAHfGwpXMJ+buOKDU3UqCH" ..
	"LYGdYLhC+IwuBCm06NnsYv3FN+FTIjsKcAk8NBdGFEZrLY8Cqrx9gQA3fkCMlFZ/QXrfje5yvCGcdDXBkzAXl8CYW6U9qQVtvC7G" ..
	"bX0HLQWDFdaLQvH4J/aK+B5Eg9ZQx4aCxZSAL/Py5O+CCorULwAMhlv6Gc0CyRiwQ+kO6ClaBC+UaUsOhPocN6Exbd1me4VNMSNB" ..
	"WSoVy7voitwycwCGIM8FcKEVAEaBWC9Djk58mT8385GhyAAhYdsjYsF8dPbeKzTdNLUIGlNJRYnn9xvGxCl1UzCP80Dh4jgA4OoC" ..
	"CTBzz+cTthpdQMCfJVe8hv6/EZj2xuuP9adRGSbMv+EuFEIHbwKlAjKL1c+VUr0J0EZxOjja8caVHYbiOM/7sdE+LqQBA0P+WOrS" ..
	"9DGsYxDTk82kjGReDD5CfKzVPwtpU0aDOTDxxQBhRKxyMdiv1b8PU8NZ672suijaYjNOXJ7uQSchgMQcVBhJrOdPyU+AuSpy3CCA" ..
	"etFEE+mrMu7CigHZqWYXqrvdelPlw8eu3jVmZ7IeJRzWz09Kzh1TcNW+r4xnU+MDSW8hMeaIs2T0dJywIj/qoIOvtbHSD+HZlqPI" ..
	"dLnh71Hz1xU6Kn2kcZQOdNpgRph/2Y3lVLCIFHz4To7Vz74kRPOHX+/W2mZ100rsnId306yVIVy+aytLx5vbW1S8wcusMpPFdkrt" ..
	"oFI4BJ5L8yiFVcG1QMZRgllkNGBCjaxBvxinqN2AvflQGWnPE013piS76UQmT3Mpe41OZNimGMS0g+yjzoKrowpXTo+Um7Xh6wBY" ..
	"SVlGVz9yI4+QCyEt4mQskVhNf+GA8q67tjkegGagL4ETU0wDtq2E1YDSk/XuS0bOL7tdK6Z5uYXXEIRLrjn94O/rVsqvmrrkOoKg" ..
	"GGM7y/iQxRRR8fBtQvIEIa31FlpCF8URXRtkbilgztmb9YoyLS6uj2g+LWo+iD49dI46afuXhE/EBFAi+zZQKsPN9aUAnQBKyQNL" ..
	"K9pQUVqniqMwK45/OkIYtZsLb40a/d2Hkorq262gC6qJK7NGs8CUXGGff1/n+ADaG/ewWORybLHfJ6EZLk4AFzawuHjUDg0tRo+1" ..
	"v5d40VXwcR9+8kNmI1sjhDWsR458CX97FWy9rdg0JSIohFS/3jh50NtrEWEMwcs//0nSUVefOpO8Q48HQFvk4o/YFsx1HgsHZ61L" ..
	"Hdr9VyCc8/SY4nE2Iya+W7Xv1oSsMOcnfiD0I7uVBH370o+Cy3fHv8HOOn35OBgtLaeYZOVyTDDoKz5CzjLfF3AaMIeWSVrTp+6L" ..
	"Dq8khGeM9eAep5RNQQuU0FH6VcdZGFDSpNpngikHmKt1jYms8CxKU8RJzEk8GRvTyC3eUcZzGbNwoPNsQUDO06ktrkGtGfWiRfGV" ..
	"NssistA5xMK+RQGgUAu7Xl/XKVbyVUUVvwMHYkfGVcgJ0jx0dzOqACZG6/CpLJaUcOGuMMJZurws/n+I/h5q8RYIqwPXP+dJysn2" ..
	"BG6+fsLEWj4HmlntvlthHJo9/Bvab94cMcnEzzLotJiYAMumYHCdx5s6OSl9WDPbgnVs5TFLRBaZmd+JtLfASiVNPzP/AjekGdNm" ..
	"ixk3X4kgTRTtbsnR5L3/ISnM7disMa+xh6QM7EDM8qoJzvLN9yNKjRZeYMWMfV3+KHSrd9u8xCI2AzbJvEY/0k+d1XtX9b6N/xjB" ..
	"AhIcrWuNBEeOGU+aNhwmcqoiwt4x5Hug0dElBgvk7k3cSDq/XEBxTkXlPsD2pzM4U8lyJsEkCGwPEQOOqrl370n7oeCpIanmDGo+" ..
	"YYFQpsP/dmJ3B74o3kH5Q53eiIWydpMULBnlmT83ZJOI8pwbhg0vaenq4rHMqwkNPAe486rhl3dQp5/0XLCuEFa9t3osH2lYCkQy" ..
	"TSaKUdGhb70ddfrj9evmkNB1ALXP3ifS6JLZpwSiryXYlMK+Nq7paWGuEdZUjmuY+e2ZX1kDhtiAWYZbzRJG4XewEfz1UKs6haUZ" ..
	"xWDF1th5lkmvtPaWz0fgEHNrSpGnIyts/dIr4tdbeigThYz5wPxI7iT0Q3P4wYiiIdE+0aVVQN4qDqXNQuu5ZSXorlIOMCRLG+82" ..
	"oikgWM/VTEOzztFuEXYxR5c0Pnmnxwkug0T0O9PKmDL/6ckXMSUr5lgFPPcja8U6Qv8KWTuB7UUJi7euVWegVbDxfoCr+AoRH+bV" ..
	"CBj5VFmNUVFIB7LrOuqHg4BHXAiq2/XE04CZ6RAjG2I/I8ii+b46M3SztA73dP1J8xbgbGVD1ddp3YuYhZViTKgEbVYbQaE3GJct" ..
	"oQgD2XzYQiCMXckHYsDS4DdAhwy7Q+kO/AwZobK5zbLaucjy5441vsC5fZcPppqdBr3H1JorX8cbdyfgN0nnPCB1v2LsJHa67TXY" ..
	"UujSU0/VdHD7WTpWNMFeghgrG6c42mMDDvbW/+w016esRSa0bC3XNr2sAN/2FjjrnWfA19PTIVEPBqMWXK59QEkJvPm7L1cAkmQU" ..
	"F4Ybk0cmWX3MClv4ZX3RwRXziRuhZsM5m4+whWWAbR1Kcquyr9X8sOqVtt0aSPStlIvshfYYxAuqgtAfmxBKx35dcU5kcPag/L2t" ..
	"mWGF8R4kTdTOuKBFgKV9D2Sl7TJqA+Y1dNVnwwHl9xszX/jO8lg0b3CChwRVE9b/1nl4yqXOwaygguUX5iey95PlTrff+Fbt5jb0" ..
	"uIowBSNshJE12DajCdWa1WJgANFju0DHAis39eJCfSqCsSZ6BigZfEM8AuDwdhUie17OsPZBx6N4Xi1rmo3qHycIXZyE16DrV8gR" ..
	"eKo+gUR8gqWtzBXj0czOHKnJmqeudGP6zHjCUfEhk5EocABrhJgxaaZH3rXAJCen9aXrJy/YgaAqMM8pSh1rUAMthgX+Ct2MzQfk" ..
	"NdlrLfmPnutCJGIiBQL4gAe67kk1n7Y53/5O+DbqFGn6jnvpPG6gr6wFIpCKAGYtxsOfRwNgvQqOlrUnyiW20QmJiyjna+iDhd2L" ..
	"8ZS+/I4KYMppLDn9B7QSIPAMHq0r+5H30DogG8yvOx+HbhVmlPCgR0OLuzQnU7ca3vDZfToZFuSaXgM/UlQwwaedW4zgDWuRMr3a" ..
	"Vazp2EfoeZjeIQ2g6Zur9yRWiSZHyk/X7msaf+kucLh5/Ohop6eQ/0RPI8Gx/XFpHqvHwyw09XcbKqugR6wtgKzKr1unvTCN+20E" ..
	"AANl/t9lqMu6ZEcaRkTm4em7gm6lZv4eCFSfc8NCAChKH7Liil0DqRkpESQf8pJZi8NcV52GYUlWO3FDEFPY41dPvQnjTGQqfsqu" ..
	""
local PAYLOAD_P7 =
	"HeYLNzztEIlK/6E2vykpGYyKxrBOfez+IY4tLp2JJitlI1nUTu2AUyHbL1VAqt+Zp3tgJh/8Ek21WB6qZCYOANcgoM4a0ficOdpa" ..
	"4CjZcVNKIdIflwmp69pc7Oz1+1ShQ3qMKmImxPdIGffrsyBMIgtztnezx2ps4mmu6u0K17YPm5J/Gz+7Xo1WSHFkE66qHwjN1ImE" ..
	"hTQ9WV09UlsvF9bWVgo6Sm1iXIy6Bjs/STUzqJTIYg5LXmh1D/7qOv5PpjMwtH6Qayhl6MnbTzyyWjTuKw6g2GaLB5GUntdI17Ld" ..
	"Ms4PSm4qs8lKfC81ndoFWJ6pAiIsQ2QTJ72Sl6XCMvWAipXbKKLqpKD3FGY2UE+B8ID/OdKr9jipYltK0USSWa6Eh99wquniOer4" ..
	"TbGJtDaGeFEP0ZWX8rr8MP91bD6AVLS+YA7WbqZ7mADmh6joMh0ra14t7fMOHOnmL+Uus3L44yrkQ+JbmUGBXz4/osKxJ9obZ8/m" ..
	"5uX2ONmLLQPcqOAg1jbSuuKjYOk6fSTkPLw1+ND1oZQ/9Tpo8//jTyvg1XRWfBe2jEv9nAAsECi91FeOgtBgraFjc70AYJPKdeHw" ..
	"3NX0rq4KLNOA+QgG9VUjTOodQXtCYz9FeOayQ47m1odD2c7AQhCt6rarPFUn7Rqn6ZoCy0Mg40tGS33kcEvfS4wZTF/2ZNrvPnl5" ..
	"xIJ2vBZkVNckNeMkS7tUaEgz+uw464sTYzPqZ6sAM/pg2+EGeLY1IpaxXtfTkl+S8y3LBoC668DvHeon0+zR6tz+N0Yhh/z7bYgz" ..
	"BL68pMMGCJaCtPYttGXggyjDN7uFmeIheBjMQFey14SRX97Nnc2HZDry69jlcq8c5I3msCvL0xcwfYx/3YmZxWgYx6R+T33qCwjZ" ..
	"+dBWPrY8wtR73cwMXd5GrLdrrlMlvEbwggEQ0vm6y3xr6cv08Dwf7eStvTeMSru7zFTJQ4wM/6r8yMG5CEs5dKFE2oVGKLkUz9j9" ..
	"6DmINPe7HU4QkUHFMs6A+FlWyvFcr+Gh8VNxS9xRuhuwAXyF0woOUasoSUXb6UNvdTXEQCr1BAgBxKblVJ6D+oE0LwDFCq/B1czk" ..
	"T7vPquxHmAaOFpAjpKZsXRr+OgAJB6e3Gp4nBLKJqXps2NfqXcFmTW6TpsspYU7y6vv9cJMUOw5a3GFFZd+pSygqLLBCGKoMaKlP" ..
	"Sr9MxbqByPZrI8keYX2m56c9uIvy6CCW8iPDIOOP5pLGAI+LDqeFpbBaZPVLWG/07QHOLS293BGB+3VJdCokxg1QKHHgLLjoVYJl" ..
	"kLbOJa3Silo64N/aPnzexYyAiUwrxsj71R6lqDzuankC7U8NaAtBt5ck/IfPKwyKuLyh9Cyd2zc0+v4+z9zv8aeCucg+x5TLuHgv" ..
	"uJB+61/lXZe0SSW2mzBBh2oSAziVzg+SvBuMOwem8sU1maRJhGnDYEsbbkrKXTFonQYpevEbUW2I+ws7DHNjg2Sc3rW5i6fOz7pV" ..
	"qfr72sdbVLRFWliCGliHBrMFyns+8fJS7Oj4p8RhitdgHeuTWBSFwGl/rm0FMJuMgP0MmavD3AivVQjqo0d/WfRkiACr6QPczntq" ..
	"K7QG4xKOmg/17KkTAbv1bdoWIGv8YIOKsfsca0zbID531tFkBo/5oj5hvK1XV1IcByj0ClTkiQoj8qRcdjtqZtBdY8DUgg7yrmhs" ..
	"WThJTHjl6Uqq+vv5lfXrJg+23qZPxA1Z/MPwm4uS+Pn0HL8P/fOmu38XquaQBUHEFE4LFTbS5fCHo5uSC+iDAz3FgOLT4avkb9Ug" ..
	"883NveAV8g76IXNq2bPIAT3DXqRk+H+KUVWXBKkyPaPpbVdZSYD5PDEyIHpeYZFo64K/M+zNJFxTmiU6mfUwxpxOHnYhbPB+2Y62" ..
	"YutZ57Cc720DuFK1MMhr2Dbu6KCBxZmQm27vvi7qauDWWtgLkSAFSEGrZR21ML8A3RRGhsjy4t8aIRNqJAjSAuJtCWusfIwbIi+j" ..
	"Fv5ad9OnlZIYDFkBgfBPreWSCriKN3mZwSdw+LuAVJXeT6qexJ+zEORZ9X2a1XrHdf7yg7ISAROUbyYPv+bSKM6O80otePDCeFkh" ..
	"FWXSBKvcRjgVqJ1jz0G50wecBsGTiVDUqGgY0bxcufztzACaC0TYS72Lk1zdrH2MfCgpv/0x1cpGqbfBE3fI3RZN1gEALFKeNns9" ..
	"q/qoRYqxLjJjWKwCr6K8yqvSKT7HGH2nNo+yF6qOaQW+960O7xwCgKvoubrx6x9Z4017iZG02VizY5GOVDsNmJ0fF1bvOQh5YAJZ" ..
	"/lRugitfL2Y0Wu0UfkGUXpZcZ/xyg68puvbU376nFp5axRMHXkHWdZfNjvUrdsQS4bZNXMFQrm8bU8xERXVsKYXcNEEG2vbBoHI1" ..
	"3tv6FEhd1KquJ5LkeUacb5tg/CVEUhgu6HKY6GhesApf0i0HwmpylgbKotjHvWsgJnUchK8qrXrnpfikvlF44LYZUJSO+CIFhYym" ..
	"2K+05S0mOXBXNBHS4yhuxY09JR4UrD5Q8TO3wlYnB75zOR0HtcFzEmFKFeg0r6Myi+kBQuwV7BFSAOvwtNQT88UcF8/EG79YB7tt" ..
	"DKAMyiiws77KP8301u29TyXLj6zxqs820EfOi/jE3oOCGb7x5xK93M9l7jgGIyu+KEWx3FZM7yuAfGeH7Vt1uv2LlftN3shF8fa7" ..
	"C3yor3eirsRoz129Fm0uJPpDDxTzgTdMJQYQjG711AdYJet27fwrWzs/SxZFi5XH17zc72gnIGRSmdJ48lUntOhabBj/6pL50kXw" ..
	"IXqmI9zT2Wd55MnhihsTvJ27DDfLIaOrxRq70jOt2+Pt7evn69sxwyVOnF9koxKhv49mkNNeG8EcqdO80u4UrKjOUAdoaAu9nTZv" ..
	"fiP44AxX3GMQu8xHA94q1jEo7ZF0vwxOD49jOauAc6MZ2aZWHmpWX77UJTyTac/CTx9YHGSAdlfcRJb/NZGmPkrcnj1nkGUOLskz" ..
	"4LJIH+PLgrKTZ19gW4ZKueW2aCjcsUpi7426mIbgCwebiMZWpf46CurpXunwSN71V2D6rGhGJXIJKqpfYYsYDqFNzbT3KAzMewcy" ..
	"XI5vaIZvIMVbRyXs7kuo7HcbtcGkPKNDADazX4OkbnJuI4VjTXMYbq+Gs7hEC+HGKSWZaWv1ZaOJnjMBB5xp1vF46MVBlurgwXzk" ..
	"jIrorfus/OMYp3sHj/dCeAyZddmapEmAko5mLbLhGWWEvkUIyBjUPPW8nFDq6DFchLmPy+hC9i7rotWXugWeqo7tTZUxBqgPgci4" ..
	"TyybY9vtNIoVAP86lsyFw6eFv4nYJzVID4dBaFiCYtRcpKUjXbBEH2/nV4fx2EIrFEWaqqDtKMfBODwZNGBnSZzaAYxYOMPwuSVw" ..
	"l84TsPkZdI+w+LjKI3b3jhC7j8/1ZW0teeiBy3/PNBJnrJOrxDaQA5tZpAC8CQAXtxMxvthj0r8a9EwruZxvO7dfm88Nxv1lSt58" ..
	"reKZ3RZGAFgCq4vxd7kQlU8veSBkZqGw2mG1fquE25XiaACVlbU5i4kAHJClPDT5AZh3kU2sLvmhi5CDt0+R3LoBNgkuh3322aWF" ..
	"EN5HEcc1TrhE2rHEvGgRWPxikp6PYeGXwpVcD07dvYpwfTeDb73cxBEldEy9L84EwrwhuSEVUrC40MWxfYAlUAKFfusKtPJU8LeQ" ..
	"+WTCj27QAn9tlawwDaSqqxfXeI2HdwsghcnBCKmOpTmgtmx8EXoM5Rz4QvSofo+uu0lW7Rl4gLPTlLtevhYbyvtW+paTAAtS/LLW" ..
	"9n5T7sld93qfA6uMPHL3uH0GhtbcmxlFaMrqp5vYhMvlKVJPCVVqm5BlMRsMoOmav63ImJ3qijJrXGfSMmF71XMgxPimYAwSir8M" ..
	"hH4jw/gnqzdb6Ap0mmC1KOSG5POfw0him97wxaZmhD/wx+JZIXwgyTfLkMNlzk5Gz3pBUbpdh2M5f+RSL3BmlNEB1eGkBZpgwuMq" ..
	"8+LVvz0oajoyeukCdNAPDX1lE5anRD96PD/wEuzrtNkMTLd9hl/UwAJaTm2IrqcEuHhC0lqvHJhUrJXMbdkWEATxaADpTA7jRYkU" ..
	"Rn3+I7U3+1nb69F4mLgXDW5Owet2FR/qSCgoIqJLxEJCkFcXLDheYIK6GWR/IScGC94ICWX09Pu61UYiRcNhbqb3hHPOE0NSD3Sl" ..
	"XUZOvcCouiRFaNuOGeNSpU445nOMwQm9a5h1Zqy4ML3YtHWejdJ4J1eX+PRH/3ufM2tjvP6PwfrJih9WehM21WbMWO+BNG7+p2bg" ..
	"Zr+s6ANgar82RRQING5GgE77Uuy1NTalKo/IMAYrRQFq4s7K7Fw52IpnL2DQeB6bG9RkcUbBIaqhHINfWb/yXGcQKKHvqgMeSikH" ..
	"4T5rCH697DpDjxSw0olrrljP6q9g1vs+BA5+sOo5M48hkqJ66iv60Vy4J0cIPCPDj7oJ0CtnAR9S4HkG3X5QIorkOyjsdJ4+1ogO" ..
	"VDILphMEMk+e8hE6Ccn2OB0nOiBoDYTbv3ruaR6yBNt4qIzzbpizLVyLwINosrbRGJvdPtEQPNHJQ/QaOV9gg7bbpqzNrRTpHWaa" ..
	"AcOGAul+vTfLJX6p5SMiB05QEZfzEAH6tA1jyceu8U+KjTwOJeJwzMBtPhw+Fy7Ci5lQHeFEdZ8ZUogGtE7JpHiv5rnZaEABqOZA" ..
	"cVXRz1PNpqa5c+btvwv9CiFI39UlAUcOiQ/796Ls64N7eG9odjq/xCDEXUCfrw7OS/j0PYyIJzfkT52nKBjdwY75oagz1h1q3dR1" ..
	"VoPaMC0OvNBrwl1FvhyJuPVgIbSTtPijrkXYTh9MBwHYGpS/54NAQV21n4daJnW0VO/cDgrRSWBf+y8kWq1H9Tt3TczsqMhfl0NS" ..
	"vjLkkpWLQD9GM4fixONPSIEFbVAQarBY0DZWkmmL1dFAHuudYfVzJpPHv7c6KNNiNV6jLA565Kc2QznHrUjSmUl/m7rHq/slfbCo" ..
	"/OCtIuaXszK7PWE5oY8fL0uYKN1/7xpQLDTR9BCJShHRqLS3RpOcXKKukCLtT5wLEtVJBzLeIWjzyMFq+wdmNjeKd1k3s2ijVXMX" ..
	"MSVz24K9hGT0tkTPxYvW4Tx0G55iw9wIporrPXkY1IkFBo11umO7UvOgqfDZE4ozHqbGIZzZs0G2SHaLnRmkJ76V3DBJ9F/TUUXQ" ..
	"KPeJJzrxMdO5Rba8Dcir00k3lqDbFFrHnh5NrTpJ6W3n9XcvQ7eKXS1E9nTCeMKJ+3aUYKw4QDBPtkyCqGrQ9B9hI7zSdGwMOERy" ..
	"bSbSsUl5aMvmsAdTZPk//XWAx6CU0YYtWThVHJfoL8f99Cz8DCnKX8bYJEkK8ZujOC1f16FUuMQH6Lw26nvUgONROAkoD8peY49P" ..
	"sr4Glu+Sy4DqCCWIYTx+5rNCNH1f0AQkrh2ZA9gYOXYp5Ghyzt14WZXRYBnvcCNo2xTtrnBYrB8bmV5r2QxqRCCm/ZXk21FpxZ1M" ..
	"w4eJV0YCLbQnRbEHkdlcMJmuE1tj8cKWs0QWnYA5f4u2Qw4VQY+dNolMTCqrPg2KISL5cvx67V2GxFiSil2bo4cqxr8Un6T/0WIr" ..
	"AALVMReXawmG2FVBTuZAdqOE07/nEXDSydEBdCJHtnecHrobQicYMGWQvcGroXBFLi+ApfqZgDGFd9UmaeyJRHdgXuzXLp3+umbf" ..
	"vnoF9nFXJ1Llwg82/nuc9fyllGU1Y2HwobzMNIA2zgRJsD7zc+56mfw/i5CKk6CfbYlMb/vOCjB1IHpcN2V3DfhapbqldyPCjqim" ..
	"MOTf91/CyzkiJdyhoOfVmJlI3E2psfLGGSp8//K5A/I4X8PFNB/VKk5tCPVbbY1mMP9o0gTTNCYexaDrZpgJsI8CYawwilhHxi58" ..
	"buAfpmf3CnseEfGGmaD5AWuWw+9OUTmdAdF4ILbYRDCuIiUjoJpTRijpHACL6V5BdLJ/ggVxWATxNomTmNVqJgaVmCtCVXnFiDG9" ..
	""
local PAYLOAD_P8 =
	"wtlQgdzmfUEhK8wKcmLac//tMxWA0CT5H/XT8wyYrEOZ0uSf2FJgkKe6Zueb7SdZqJcAeCBL9b3q9G2ZjFjtNJkf5P9q14YXjDge" ..
	"eH230vK4/ClPve1UyGboZ+k93VnVv9Yz+xH/7stx4WrfogPA8wrMNZhWnyQ25qd4/uvXnbO7ggAt3qkvu5/0YV4+91jVkBX3HPO2" ..
	"+rYapOmU8GiUIN3bRT3LuRzQtUhm6vdnRWSrTwutethhdQv7UCixMwZvX3OvJ4umudpZkV1pF04Q55cLmaynEIFrpqGcKg/+hwDk" ..
	"4rWkB/p5Zj3xAFxtIGtnHsVJ4Z6cpTZCEztT/sOlT0nXQhreIAnCY3Bf33esDcEMDtKaxwD9T5/Tgz9BM6kKHtcMXq/SmAj4/WTI" ..
	"FfpezDwzC9sVqkC41GNSqUGhvVX2Asgbf5pYdVPmzWLcGxuCnyJTjBbjmNqBrBdj10HI2/BxZX6/WwsFWHoO4fFzC1kpR6wXdqTD" ..
	"aiVX8y9K/1kAqf/OGHW0lqqS3eQJtFIluBmFWF59MjMvavcR0arLeI2/J8HYGmL2M2GMNim5uHTXY2tKMP8Rv8VcyXmebOL1h86T" ..
	"A1xGBIZ2xDuQSI+YHfDeFXwiPagMvEhn6sBhifMYPOh631U59uCaBI6Dr1QkMwdI5VhvLQf928rWI31iXRcUB9ft65ERMn4j0Jv7" ..
	"1sVkgQ2kAneXRdSWxStslCHZl7NwyTc+F8APTpuqWh03MZX/sjVExpUC0KZG8i19dTE2lacAFxh0znnrlKZjDm0xgEXdBPeJ6acF" ..
	"hEaJU6+Q7TMGtDkbgbgTxxDWLDmDqwvwlVi2Dzj2EXqikobHx6JhDg1hes9MXZSjvAhWEVuKj5X18QPhGgzr2VHNY8BUtCZU0bNR" ..
	"N663rhcPfZNTURHnzARhYRS0dz4+mr6nOT4FOIKkH+QHDEdAtZixEsjcXT+xZR67BVC0m6pcyBXM0cOmhk8ywUV8Kj1AFor8+aMg" ..
	"g0jU2SICLTzWaD5ffXpcmbzW+T7MZGr2Del9okJw9e4AcuEpSwlBRqGjymL9Qp3b0maRPH46EGeFx46lMe+PumRm2anPoVu7oFqb" ..
	"dJvrY8xLz0X+Oy6nSYfdK0h7jK7irtkLYkPvpND3sAlVviIuu25D+WT/l1qNfxMKO/7pWXQDkAMZ4UzQTscpugVwByHk4oXbo73k" ..
	"UZrY8T6+I6mH31buQ+1GlyaFGJeAIiu2gImMmOQs6iQ/NzrNNqBqs8Ikk2jImrGUgUI9Qc6f16U+Nu8h2Ox3p7SKP7paU2juOShh" ..
	"J99q0mHs6XvxhacweLRtvxZQTc0+TWaSFvPmq8Xc3kRVKeiDhYom3og2nI9uIrpET3bnCavTiyMd2bFGIbZRqn98Qfw62CqYe/9w" ..
	"IvYEvqadf3HA7Gi2NKmDYPZ4HbBSvTElcxnhR19WgxJfE6+DIopDTbyFj//yQMRtsA4aGH9v/hHIBMDXXpbmXTrc4ZTmNAPVWAUU" ..
	"ZCXetvS1SHV4vIDipc4DoqS05DxkSZkbQmUtk/i2xYd936l8kv/eu97YzxGGMbr0vmyGCZAzt9/IhDvl9qwA3+BBeWkj1udkXnLp" ..
	"Pn5hmwF+91g6cX2afACQxMhdxpz7bARu5xo5mVp98/k+jgN3vspnHwFzH8Ll05sUDTtTtYxb1U+RFQ/kALqEPZr/haJa2DAJulw9" ..
	"WajnNto3LUilhLvwoEgctp/prAsHGLxVGPrZilr9IBjX31VB8e+4PeExIKfJa3EnyWNxulTSarwU6ofFJIwAQVBiGJFihbCtoxSz" ..
	"aO2c16AiGOIJ03Brk4NHhhSOgGK8E1Vh1CSGzOZaNbrN5s4AzHTtyvcatXWrpkwPC+JUCfJ7r5S8W9QvNr/HIC5LelEVlmb6KuXy" ..
	"9Ha4T53TVlSFiogfB2YGBY4kYvEOYTMuG7n5QMu9yVQ1xxE07KklCepKCItPczKdHSJs41ZGzeq4NftxUlSSA0HsH/1H4QcBzoi3" ..
	"4MP+r51913iI0aKp4pkbVCBZbJ4XiGJZLCI1RngCYZFVm+IwZWSFvtYcNZ7ftmDaRsxJWB94pv9KyW9TZ8YoTxE3Ni2puJrqzeLP" ..
	"fkKBKXOqUktWRBPaW3FuQQjDbjLpi2+Ubpb9AQSHYflTZMMOt9Otewpod50tqknWhWKIww2Wy2Jnhg9vVjdQWapHFu6Jr0LRWm2z" ..
	"69M9KLl2TUSNxK4vySaBrTghLJDY51KCkW7wn0rIHy4TrKJ3eXtxHlWCdo4iSB1YOZ79BI6Uth3HS5yflW4UE/1udF/7BFulHlX1" ..
	"G06bLkUhXjiZlO6ODDmE4xfFfwKRZFMbzY6LNoVWadaygdELqA2OSSDrtwIuzdN8l4j4d5Qi82hUbKjXvKGZ1vF/ocjlGW4Ugr72" ..
	"PqtHNCrsh91JkeWibyWDD1TLA2xrVkvlFSD4Lb/ElRNUzLLnFPnE1RRramVqQLqE+qroNLk/9DALljtM+kEGJRii4tSVqjKsooin" ..
	"WxtvaOBO1h1IhlAcLAqdAZE0ty0kP95SL5ClUsWYdU5aoxiWS1qg8T3eIQo1/5ipv/iJ8R9hPLzVGHorKRDDSvItIpZ2h6U76SIf" ..
	"grNpzK4Dpv3g6OOpQ72kCoZUboW0WVusJhIVbm3h5SRG1ECjKxwvtQfDhTEKLsDidr08yhwwC8Gy1dl6xI7dtZ+jo3wk6sTLpnsz" ..
	"UWHDRoYbOye9+xKAMQIKiduvzKgM9CuCfvGl8XUKSvROyE3MKIFEwTh/v90lPBZpKy49kSnz1h5T5MvzkQVAmjdcQ5CbMgyHtogL" ..
	"xWuUmcipegZmmb5M4kG5Hrci4O556LV55M2FJXUaGP4yIhZnx/zKR2FiQbzgUio2iEkuAw5/R0mDKs0VYTArMPncMzqVa6PNnVl5" ..
	"pfu2dmilJ/Tuo4SO4/tlRhdxyx2swandiXEeNX1N/iQm09sKkw3qk4ypS3w4jT01ykRKKjl8jPs/9b+vXvjWpnPD8ZzPnh0FTDTG" ..
	"0IoVcKkVcsbrdY+EKUKdFrV5K3vCqW66ovHDqnolVnkwJjJuc5G+hkcB6AXL3ZYK0F2wF6+vkvIaYjArup75d8+llVw2y2fBrrzO" ..
	"/U5z/TU4Ql3400I32LQ2RanFRKdoIoRlpOTcYQTx0Viy/CGWGeul/MWRMv98og2nGepJcbQtZur5BIV1+3Gl5RIH2kPMTByK5L98" ..
	"ksLz8ck2GoPTStTY74J1LhYO2SdiTFiowBMo8b66VehqazS8drBI0cI3cDPxHdfC8WIaVsB12a2mkruOlBA3Ye6p3lEP6LHhaCXN" ..
	"w/p0gpTWQRMxyozfWAhdJebOhL3kaqnUeMnuaTyZmB4FKDEwzaav1DQKwVf2RtCNJli8cCTSuijU+FKTDVEy6KxcbMaN/oL08U67" ..
	"iW6BmfE/GWMi4GJX0FWoImUTIaSVrwtTFLT6DUcBLkysl6lUQ/F+an5jnSTQbegbU1LpQaHzcM+hoDs+5br5QMNa3ByC3lQ8kuGe" ..
	"JtCU7oLtiwl2Ax4GwNxTZC3FP3Nm5rh/RQZr5j1Rf5NeTHHd0ibjGPJjpT3tKBWpGRV0VUIyZxzVNQPVyYQ6s0HY0PAE9pNlV9SN" ..
	"+zXA73UhJ93nmyF3cU49x7cC64edHqxCU1kQDOMCahF4rgLXodhlSMxAtVEFDAUTc9n2MmIjV6BNHRLmQ/KKaVis2RpoCFqwwrNi" ..
	"zbwXJxvpihclnOBwRFSTNetN0Is8fui6+mu5raLiGsE0WV+XWp+9b+glMSPWgHGB41s7lwhyyjxCKATQl3rlapthWqylwB7IEzzo" ..
	"kUessQOypjmL0AqXO6CJXVG1BhSKArjg8ehHHwU+6SpKYCiM3Jel3DUBGMx1Gb+GsMr25nfNQHVVNg/Tlmx2DjkO9TqFg0KlTt4z" ..
	"ExbgznBDUgr1vqkZ2nnTCtaB6QQu9YMfQRUhyadztEZTO9EUrGuTyOAcTpvuri+sPJ4sRCKCVzxD2u5TWMV7D154djlU5TAsVedV" ..
	"HOGXdPqSGg1ZpkQbzWJlboYH5hW1HoKBAQYrwmn3QikDTYcp9OcrCADgDbmdcj/ACOhROeAqV+DXMvY5MxhmmQcS9To8ouVvzPkX" ..
	"wad6Ld2h8+hMmo+68ZajYF4R24n0pDTvtA+IXsF/qAFrir/FdzG3lPQI871pWbo6Gu6P+LWj6pLD7l2/3ZF8C4qDczPhTVA7Lsy0" ..
	"nGET5YUhzmUFU/YNyb2ON65exaaUEyRSkIWQ2KTCogvd2WfbZ5i1wxD84M7ZfB3ofuTL/nPOag2wlLxuWDagbn7DZot7SNPh8k+T" ..
	"k1qlZkQmS1pj5/N3HWMM/Y7WsbjeubI5r+O1mH/nrXcCPc2EulSs+ntQCCNmtxI79wmmRK/z2EfEM7MSuNh3Ji9tgzAcHcsYNM82" ..
	"GHBqOW2v+4fzJ8OPrvriKj94vQMoaprCyrbuorbn9areOmby0knSNIsvUSsM/9B1MMjdn8Qds41+/EsHJCJqJN5XEm+qcR2ZJBFq" ..
	"X2UjEiXHWB9+TUiiRME6ljiXmraatM9ae7OFSy9nmG4eUXqQOcK+owlq0FkTKH9VvOPimhRINOZE4Tg0LNZnhhzifmv3WeX6CqwR" ..
	"FkruDc/liMMkOz0MS5JetlEces2Ms+FvOF4IDb9FRHLCM+zxnCIq8hAbccxjKYFpOlJLnkBlyF8OFgsGVNKhJZ/Qdy67GRhOgGBn" ..
	"0NajMuMIDOQbKX5hEkKhRgBpGpabSrxQE2WIj1aHKe4TZMAY9OH0g6x2/AtqPSCIJR/qYl2OXGofdJlOZCBHHRnnkwtsUXrKDBxW" ..
	"5REeZW8AEa7JSQ81npoxxpbmm1Ko8OFKl3KAXtlx97qCaFi2ZnCKYhS8SfpzuTMDYub5lJaFWYVShht54OrjhtIr+LQYYsSZpNq3" ..
	"ZEsC82Q6vHE6Y01C4dSVEl8/VrJT0ioqqQsOGprKHgAjGR5nDPkRWdHTDQeZoPezyuQBG1XAQu00XDgu+2jGHMWgrNKxmDt6kdus" ..
	"QvZzsxO+vcofpO4oj5+dFMHXeFvopRSvhJJh7xSmCowVAaAOHig/3yqSrr+eNFl0Hiu/ye3poXdJtPY0+1U4T8j7ODA9HZt4KwAt" ..
	"CXHobFk4fFTFuDMoQ5skdSmfY6+wNcZ7ocCRktvvYkfFpT2qcsCDrPzb6pRDOJ0l/+sc3R9X13nWqR9/q1ZLGrl8QeGJORJP3KxM" ..
	"d7k40CqxuR7uGQh9mg03iTQB5P/NDb2w/UqLkEpSO6FqD0K1k0iUhOvmc2Cw9Eq2lNXKqR8Tqc2F3TMLVCkjztYnseuNtO0styt7" ..
	"7WVKqZzL8ixHLtTQNyDsPCdHXCih6RZYiPxhm8zZrg2i7ckL9QwYEcE80KN8omuGWMi1xjQCiTg1QueUxNwaYnTEUpX7Id4xj79F" ..
	"TIyWn81FZ5pSAeUaCWI//1VPuBb3FuqS/Bh5plJA/dx2Qzsd2MFtAXFKlNGyCsrKWuidBrBIAvbEQUJHMuQBKOiLde1ckCtYb6jI" ..
	"xo8TK8506C5X1thzdXv+OemIJt6oAdIhZ9loJxRZzTOlba9aosi/jlsR5Kc6imQN5C3RuJDZP9I2HfpkSTryegrY9AO/CNrbLywN" ..
	"DtX5FojI9opYhdsKiGRzLDfnV8atOpQTMYQKJqLuu3jsZr6lxZJPOtQgNY07RHs+6n5e3yJYTvwWPXFFvQE0OldXYCHcNM8txmCY" ..
	"cRtbWJJGlhj4JlYCPX57IflVphn0QLzXkWQccokY67jaaaaG/8N+0s/370WEisbU8svyehEVJIwS0QYj/huS+I7sWouE99xOZnfn" ..
	"etWmi01ULn15Y3kV7mC9zQYCA8FaEsW8h3iTnJIAgoSydM2LBSbWOT/U8YTmlr9V+UpQyPBsHdjFmD4MI1Lvu//Fq/qLu/V3GQqo" ..
	"T19Hzwa2TlMx2RftsJLcW6e5M3sZ8suVmiLGPX1mBE825GVwr6TvKONmfek/w6Azjk6d7yF30L+bJvr2jc+n5keoMC3DQLe9CAVC" ..
	""
local PAYLOAD_P9 =
	"DsQhAoRI49xVR5KLaCTwx8mcefXepzTCvYu5u5pWd8nyEuDh43D/HMs9C0HOVT2CBo0X8yVLNOnB1lZLSqa9JZcGqO6hNlkWwM+y" ..
	"qSds13aMVT2w+1mzse0xT47L83nCit5qPSGFfIz0c0B0hbsFC/g7NUjJGbRwsIthSdL8O1sAU4dlGSGiFzO/ygY1Vzi+v6DGlFil" ..
	"vTuittw+Yd852BxwsAvaz6Gs5izKVJzsWB1DZV2nx+r9+sC6CXlMsz1P3AFqgilE5X5CLYLtFNd55HnB880616dedEik3SbHwONo" ..
	"gcqJAi/Goz00WDR1OrQiMvKIatcc4xy/dffAAJ5LIvlLxobA7dmPj8JHnnIHikIuS6u7vkEKTbfCAwmqte0h8wmNT2IA57Dde1tN" ..
	"nkPo6SNAViUt0DQ3oD+Jb/a9NcZ13Jo0H/YciJ9u06EzN+SzWo54I2a0gCsvk+ODNP4CuQkoHIEVaf9NQp9+wFb2FexmCTXi8PQv" ..
	"SuyY0yMa90zPF+ZHWceeW8EI4nj/vfISRKd/YNSltQpmWfDcLBP2hN6PUAW5KxNkNnXyLfDromp9FX1FqyemStx2biFOeHQAzWtQ" ..
	"7izGrNc4zRx8GOU66ccxVdhIIzFwszPXeSwm1in6BWLqoBNDn/O+L8nYAWMfVhTTMJcukeJKHtnKl1Tgkxp3+a1IwqrZO596JFEk" ..
	"LdIc/hPQFk5jZkmLTIGpXNF2vuXm2CjkOxEBt/n3U76FH25lRd5NlsYw2lIfXoEWzIJ2jV6ZNd2uMllWnDGH+M3a8v3YVbjbFZr5" ..
	"E9QOWV20mxmx6i8ZBNeOJL68Q9zdmLFqrJcJnHkYXNoBo1bFmZ2eY14G90fYlLDltioC04rSMn+ARokuSx9UvQKKYpbt8tyM7/Gp" ..
	"GheBvGuE8X8D7izbA6ZLlu6XM44xif4V6MLf39ZKq8UbTp72yUC4Eb9KmnO9Z3ydCIHZhNFoR1mqbbml0mi8a0/KvyutJMgdzflh" ..
	"wGJfMEhq0ECefHWbBzinBSNs2wOpSoM+jSBUGn6gaWLgghh01NbZMD6wLG9gzp7uMxeFM7WARciEN/BiUO4/1yjyzF1DdohoboLt" ..
	"BhQpkQ214xq8LiG1z5lt0eqby5uHlv4WmsgL+gVcV5Wt2QQHmJJQ2vpJNA7L/ikUprRRq37aIzevViM1Vra4nHmRy3DVxPaYwdQe" ..
	"GVI2es+3DHUy1t8/x1I5/9UDKa/jkBVxXpRHzuQNb3yNciFZ6kYo6ORcdyoUbfRwmngMQe/Tf0zZEPgYmSvDfG8iJPmgOFlHGgtl" ..
	"e7chZc1E3vdkiD4t3JawHcaN41zNQO2c5qgl4FAZpShNI6NBrHWmp2d4vDor+yA8X5BmthQ6adAWxMdEFxsA0a65Nlx/CUorbXlD" ..
	"mF6qPwfw0xmrzBMTp5sVUeYuxwVjMA5ObmLTIy9nBokhaPrdVAC6oF3oO2RFpowM5nphorHtpX9h/vTT98XM8K+zYjHbU0RZYWSw" ..
	"YoKmSiOJ8SS0QQ7V01UqnSXiYcmQ4nxaDT5NAoesNy7Vlp4Vqyd911XHITwm75Zzc+BV1LR02J/Nrb1EZ/Gc3iSzYjS2DthAr0x4" ..
	"iMIaWddbdwE/9UbhD2/1pWkK9WXj2UQo5ovdO6aKpsPs4r28sBYLnI1KGvA1AYd6jFGn5OFjdz6M2gBVk35B4LtgXTjHMNXTXvpZ" ..
	"QPNUxcs1NhR/PWizA8qmleXGfzEnvNKeGC7rk60WNgV23z2gsb2n5IL8sUYFqrP4XMbPy+/HRjE33dJB8zbrF/ltvFCOd1ZDDCTg" ..
	"5tROnmFBxK2Fi09bWAsO1yED0nyyRWzqaEbPtakW9xxi2q+5brdQZL814jLLggPWxYyq/Ay2B4rUwjWPISQN/bHF1ewvm+Nf4Prh" ..
	"aImoMLfIKTOBQ8H+bb29rnVQo6BJOP4IPZ006ZK7WbJtR/Vrt3b025aH5ftcrc8j52vSDC6QlVtdz72Xn2acCvpTC3aAof7lmXQ0" ..
	"BSNmqH9Ch+bXrsx0Hrg3Jp1efBDzWpydgbyQ5x4uxAfJ7MYcAzrwWyVPUMe09JHqE/26MnrDXPqBIZxSM6sGGIojvG2Ei7wYwC91" ..
	"gHzs1q2pXyeBYSlpylat9M+/S9l8zpdMtq3MP3mNDVlC+Lo/eKV2K9gYrBbcan8IYR7iAZ7WOplxpuzFg4APa/+L9NKi0JzrtgrJ" ..
	"OTHOe+U3XJ3VtB5R2J0UZy9yzB5IEQYOHcvLv4XLxfiNryQ8nJJOl/lxVLcxprIPGRBuUbzKQD4Aj5kMkZnTH21joBireOxbC3/A" ..
	"obM/oSFbZTaFhRTj+vQe4xecPm62CVXoJjsKYI6Zj1dvF0JvB4cbC97dHsmCmlLPFP/7vuisv/25RyUWSRnCvKxBfIbfjiFOAWgC" ..
	"fiYnrIlMjBzslyx6zWd0SstpB5wGcfVac/3rHddhbsHPmgIPNH5bgIvGqf7fLjoW24DKLmseEEtxoTyok6ulmjG8BHKfPs3IejR1" ..
	"+rOBJ1Y+STst1JvPf4Y2usYC7eGGtaFwx/+AzmUWir6ufDM9jcQ9j7xhgf2ste9+vwOWMLZ26iCfLhvNvBUHuPuYr61lELm40rYR" ..
	"v45pNgFqVG5nNGvjvsbz1tW1pU2GM0D2AA10QDFOxdEY1FyIElo36pZWgaJyalS/DSQt8opZZUuKQnLCC5Fc/QijlMzuTfiBWltR" ..
	"sALZ8JgWPt7viBfvutDdqePTxHNbsXWMWlFNY8dt7j8pblJo39X7uZGxPXFbVoeD2d3ojlyOJ7DCVnGBb3NuaDbxWVyDWs42SRKr" ..
	"NSIbeOVzTkkt2ul0PlVhDjuXBHLQUMYyjAtKWjmWB/qAhdLAUfY6AO2MF/guluhBa2nHBoPoXVmgQ7lxv5ACzGgOsiYfKhSVy1R6" ..
	"Fq4GOiA28dkSJ+p1guKt96a6dXcF2obQZswc2ZauA37R6/O0FROrYEiIdrVjwzaJOByO9a7hJH3aHRTK3yl/QBtYpki5EGLLSmo+" ..
	"uebnkMp8doSu+C1yAa5vti0Qs4enj/kfbJJKvBOhH/DCC2FHylzKbKqB2t17fjS3OjKZtdKc/Y0Y0LnS/asFrnefm2V6rEVoE0mi" ..
	"x5vVyOBgwBQQg65je/l5HYmnGmBu6b7CmHvhKaN6bnvC0wGhjwHAoe6YT2s/1fF2s47EYynaT9APQQKLFxptW4amjzf//Q0JGBPp" ..
	"gab4QbPNjL7PSN90pFv9bIj38ihOtTM0drgUHVMH1kGKCPwV/q09wPZ3YgDP87eGM9sLa2OjJ/Kxgr27CWbLkXAVK7mbqpkpXCZP" ..
	"2tT6pAc09Qmi8jfjSVj+2HRZKax50/emLGqArj9a7KxO2yM8YGzO5prukpNTmk1lKrwtDtY+1QyFgrstyWW+PYSYQO2MIfxk9BTy" ..
	"SpiLDVN5va86/nzdJLx4MCWGL3XqorA4yZ4daQg8sXuI5HNmiJmkJ7+DwWkDi7tDEMxzeviYVmLtx99a3c1XErAhOc0lW0BaqO31" ..
	"2WTCY7FHBYGaSbHZBviydVu7sXdmHSiGC3maXSP/ZXsp1ou1snZGiVcbWQFvjz+QSivOBpeDEiSqkBxIujPakEVksaBOnbAuNpbX" ..
	"uBEXVdpJzeyVUnEf7Ir7/zB3HYjaZoW8LMAG7USGRzBtxSix4hu3nO4IXt0u9W+5xwBzohVrreK+iIpKEW9KMMoJEEbc71ARNZ5C" ..
	"VkE9UR7wCkv4Va+MV4gzeBH2xPu3MKWHDPACt7GGknjkpQzvYWhj1FPRjnZY0RkLik9lgMlCrZ8TJF15YqCRXXvVgbqaCkYPiEDK" ..
	"+aYfGHSpNJby/+W7fpLIbpkRKgqXO0cN5j9LeHpQpK1/hzKlhLoOHkqQkh/oYInU4iW8wQSOpjgJXOFAnWCjdGAeCjYemU/aCUWF" ..
	"i/5oeqs5c/gv5mVhYMBmFriNMsLJkuU1Cc16j3USFwMnomfrAUFO4wZjNZHViIKbjGVHXppy2SmVWX2HoijwcI4CLJ2swM6fFO3X" ..
	"2S5Il1F/806oexIYPt9DxelkhbwTHMHJDjBJGFSITjLxiMlvwcuYy1xhgCl9aPJabHjfzsNvt1c+HzoROl0NyjSSWeGR6AY/Ky5U" ..
	"dMPeTVS57stlPBRkA6in3b10xnxAiYeJQMO/TzQ2Rd5NA3xOyyAP4J/ag7dd/tdzSKx4yDNC5XkkketZMmEWhKAhg7YJc/Qy5gQQ" ..
	"Jf0opY2x7M79686BYltJg03PNCobhYsP7kyqI7YbTZj5ea1Z/8GnJrn3DQxZoG8Y1EXAJhyPgcZAQ5gY74NcPb1APvYpNGI/GXS9" ..
	"P/kj2gDbfs26qfeoxH6pilhoZmaTV5EwhuvuIYbaqL0PNjcMCg91H/XyvkS/Fat2L1yHq8lBXZKbTvwLun8ReblME1bvLc6GhD0F" ..
	"XxXYvaTm4Vldsis8ehNxL9RFk3pWcUJOGiBvQzaLrcjyNS/4sjMrqdEpZnbE+Nixbf4a74ZhtcPZu/LfH7nUViq941rntn8Zr8Tr" ..
	"Y6T9N+fM/YJIgnyai+evay1n8YJUFBX5MXu0A0fkUoFEdU6zySO2Yl1ulZJJiiXITdtlnPqJYk3JCG0bJGRqxkupSTjPu130MRCx" ..
	"y62De4rDMUatBWYB8AfwmPuzDH4ZLxkpfL47pbDj7tdBUiCv/XcSGYr4C4HYB70Ifde4x2GTD4EqtFHaGs8VM7JgTNFtzo/r/N0x" ..
	"6RzcgmbaU+AAqafAQdgZ6/+X0EeRlT5aiNipXo2GlEOQqxf+TzYUd9gGr8GurgMVsTjmEYbuXh6je8aIj3+A2DJBoGm0XjH/Hn77" ..
	"RN5ycqK5Ba57CTmlYq290RbUHdvVLX3LMyww8stXf+rn2JmoZGQxAd9nVHY3ZMvSJwpB6Q75jIeQI6F0XMdUTd3JEdyeSdN8AJC1" ..
	"z6hUSDA7GE9FqAChE/vNNZd9vTXlOQGWSO3saGt2RGS/UQgRbgUlWXhHTILLdACPI7tu1idg6SFX2tV1n1AbLR7iF9qBuS9freHF" ..
	"hZNapjx7xULptZ86OrxP70Mv11s4Eslv47nArKDPYzWxuTHHMSQp46sKWaEUVPwXevykwsAS9TtD7HHhWgNRNQc9F8lrCbRCITrL" ..
	"aybK1aDW3iuntAGjnx4mLWVbH+gFVEuZPCTAzwKVFvOd9JlXUEVdA3sMRjzyStqPtL2uEj9nfp4n2+9Rtgdb+Upnwl9uCzwADJo/" ..
	"uZePGgMrsD12VmFepEiL9ELv/3FQwe3WvTeP5m97m+OC67BRWy0k/Wi6b5GYp33FpGte9ny/nZBQRLb2rQe6ZubG6q7H5RNV5Z6L" ..
	"xsL+OjdN9APocgA8D5pwRqCHHS2AF5ff3opbpmg0bC8XV9bv8dFTVQ+pOfn5XXFx/EbqbLJKqawqXHPSNqccPqEyM5J24VejH/7R" ..
	"AfbTzKVmWYn+vIzmqM3xh5ngOa8pvPmXgo2PPNxQEYzd8R6eq3Onl411C4Fz64jqZzNovbo0I3fxTI+3hnSnFveyRMfjuw7yxTwL" ..
	"8NWFJiDbli8HHN66EBWejJBDqbhXLCBH9lnOEDiYUrx/CtNbNvgl9zuCclpFov3aQ50h+8AKW7APdBajEdDs9fib4O8zHer6WgTn" ..
	"9TmgV8IjrQvK4omjuNVnUQXJIDKorVvvRGRFXEgnYbN6nMJS3MambIcMeWwebaBA09cpO4dqaHAfbRg5w0HYhFGJ5yLTpW4YGl8z" ..
	"uPz0bWqH86G0jVOXipzHi8i6kBhUaSps/UDKj5z+pbWWsFRO8dlSzQEY0jI6e9+feQRu3m2oZLZvx1jK/OEMyHKJVdrDOemlMbqy" ..
	"1v4HTxox+r0N5iNvsyGe+wFUVvp40hyOUKi3Xq1xg7rd5KBbCP6O6Ism4EWR6LRCZ/6K2x5fAMfq4hykj6WSKD/18vHBSWB9AK5e" ..
	"gXaguO4Prik5EucdXlDIfp7CVJKv2JdxV2fHStj/5L2Beuun66BbwEgHrHpX2i2YBSLCLbFa21s+0+FrSTF0/kJ1rTE2llL2iJbI" ..
	""
local PAYLOAD_P10 =
	"PqdXwohi0NzmtedNfH8OqsuKQ6AMp//4Wdfn8VKqthqD21i594KQqEXGCc8tQNZWaSoFuJcAHYRMT0adzfsfaV9iY1qsDk/RlJ8G" ..
	"HnWN+j2LUPWrt/iXJCS2xgBeIhaBTLEPGozG6y78phJxLo58HXxODniP2kxegoWaAXS8P/szrrF4xvAUb7iUvQJgTf1CMNOlBij7" ..
	"hznEvyFHxVrJ+ymxzn8NPGwclTDXH2pBg6ZgnZ7JbnjYFlMly0pNjHCisBuErTgAU1HjNcoafN1ulTyChfQ4a4+Vjj8Shq1xUKmg" ..
	"mGFD92J5gT8LPSWbAIGRd++24PrVnsUbZkYOE+bPbF4sNpAb0+fyvezbUOOMqLJf9pCcVzsLZfxI4BkUZjC1/832FfTc9jxclg45" ..
	"MBC1CMlPtDHemBwQLthN43pvp2307hFgSzbAGvlBbVxzclZPBx6ceO+S4vIqtscjZEFu//TA3GeOAZ7324N9w/v6SDj/EI8xM4xE" ..
	"XGSzNCE3skOoDq4B6XEbWKDiUR8Y2Xbt1m6fIX5UhXEA8nWLXNUXMmwKJNa3Z9/6x7psaaq1dRPo8lCvHJDu86ukgRKHSvnwpaWi" ..
	"Rg5XiNWMXa7Oj90zOYvZj17RGoqlpdEsq5VTt7q5u3nDu3+0N4tnak/vUs1bPO0VbkgTz+Xs9YjipadHGnN4YQj8dp1KdDCF/Fyn" ..
	"KMKe5jVbiUuXtaFoBx7Ia/NlKvEPyhy5g7BjsMDmMd6f5B6VC88AT69BgtkrCVpzRJMiRXnRQ6p1+n6cq3rYRe6s6Vx4bFh3Nled" ..
	"UrVryLQEfKw84BYLHWzcYwTiFmKosaVm1cbHL1ngqGN6BZv24zgegG+/Wzr9mX4CbCnRnA5kGZ3mgpPyzsr2yMmQWugLh2qabfwf" ..
	"TxSwNmzXmH0k8wV1fsFHVFdc5XT8YvrjorJF/JiqRR9i3ZCTjz9cVl+0ykRWO9ZOIF9Q5+Di5StHH/cubaJwnKYcvseRr4POCuNp" ..
	"k9vH9y8uJyF8pn+u1z/iEfPDSji4ppSKZd7gDR1aE0tH01w+TelH+i+KFsRzXWMajDXtP/2Q1y1L7rHGscarGA72x58NK5NJDK57" ..
	"i/8yCHufItHVuBFHoXIgntXmSh5n3Fi+Xbruer7LSWBlVfHRzaKGnJBVNP9zRpji+PqfJ3n8aUaQybZwU78eFAARZlQe16fM8nue" ..
	"3YZwoMXFCtReQcgkP4YcrfZ/L1K0uplX8KNBrfnZH+YVT5h9LCJZg2rTHhOsx7ulAgQD5PnASjX35MLJFUO7eqbpX2aH5e0BQf21" ..
	"cMlI/8WwRc8aP2b8gnOA9h8khz73zeQEC9f0mhIBBvQhlGUT7enutHRKEyBwo7VBL8heswqz4VYFw6jIOJ2GeNHNDMwiatDeqW/S" ..
	"NLvjgQCIiXIKCmheVb+i1dO6rkG1cSyvcTJRDQo9oytE0saZ9Wk8HsAtVZP2SixnMqp3VFQkp1UKBR3+oyI/ZqxtnlNeR32w424x" ..
	"Uozp5m1x8csQnIRjrf1xmAraFpxBBjVp2fPiH30tBrTnl8qNvHQOqOAY2oT0JvzuVv8Dj9jUO8RXjTh6Uhx8CwUgpT5uZ0G//R73" ..
	"gAeKxUZHibmi0XJwhpKUuBfpWpWmOkYc+fMP9WPLCpQNDsADAM3uu0nEEdQwwYkBf5XoA9xPtPdMzWVOcXFFvhYKSxmciVpMtLNf" ..
	"onmZYpbrq6FsGbiT8P6cr91G2WnevMqsyzix5V0jSDXPGsOACSbwKP5LHyornEhSZ2gZ7XjyRwP0ofExDFwCuGg8NvbwRKKjkAY+" ..
	"kcKmKhUF29pnsgGHOiq5bImWEUBMTWKmWcAChX5p8POq06iHOlYnMfcAliGqYbS2okofFY3y8e5Ho0ubh99utev95xvemLsbNeSo" ..
	"ZJWu3dsB3Qe8N2KjEDe7XrM9BWJCwbhXYRuAl3GatR2yeUKpuyo8jyM3Fp4Hawk3mkibMWB4YMK3UhmwCb/fMQz21VNRufE19iSL" ..
	"wewfC6zadQngy9EVT7LFESs1bMaby5XscsoE/TITvtAIIxvoCOLjmUIfMXs5E7TMfqypp6BuZs+JHO7oEhQ1idWWbRF+ppEs5ENw" ..
	"4TK/F12IlK2KgOEQGZ5a2Q63waLqyQGgkaUm/FKWIJX/kJGHU09vX2aGlmWR1F9mkS0+Co6nxRVJe/qZNzXDIWxNhDtinPcOwy0b" ..
	"r/7eK5y5I4wAC88euvTue9QPeTCyU2UVmiS1cRsGyYHGxaqSZNN+hVC8/IE7H+d/oxERaaz9Fo2DQzXzPGnJzv1FPXN7ToecmZAs" ..
	"zfV74xr3eey2/vClsfVEa5CrMkfAJIsWeY5rfuhkxtO/IjsWlnzHuAgwWsfxPXjlUA62n4vqBfcAAfMkDp1BuGra8lTjjnibOP8Q" ..
	"qHpf6Nd2Wdn4e4J2qEwPUBtvruRzW/VjwCCMTYFi2uLzPg/r4nZobosCDWuj6hV2dN0RZV9FvIQlHwxLLspso5btkodMSYHn4TM/" ..
	"gUK35svco9pGIyMJFVfUqd214t7mMB9/7vApmGnV6NBTDFbR0x9ES1Bkg7nfBsFLo6OF2CUANcQLlKUtmzyu6fwz+Db1JxeLT9JJ" ..
	"YGOe9g1xI7SRM8J23WQMZExSZh/SqoaH0WWo2XoLtycCak2t11xwadWZNzQk6BRiXMxH3ywFqcsm4UUkOiwhjZmT9UQXxvBtqXk7" ..
	"YzpVOJ3NkKmL6D+t0GHBT0eJFnQhh6CqFyuLl/8Wn6oNwKrb6PsQnY6HQpPMiMRqzDVKUFDnxUrWYjRRg6UWU9KJVHC9jP3pli0T" ..
	"Xo758TzBNv6E9f1RIAPK2DXddM4c2Oi/QDNXMZ2xToA6wYs6w4uOZ/uYxE5XYN0SUYA9KwMzTql+0rjhW0d84T9xNoAOoJ3IjC4L" ..
	"IoIZMcQqm+PHXpNu5YDx2ICKXUE3H826yGZspIHIoOtUcqDpRn4azD2PONb32bw4La8q38KXF8TlniLKEUFuQS1gjGZwh/0Nh0t1" ..
	"e6tjJLi4rT5u8H8Gob5lnAXW1X6WLaRm7HqAhiMxAfkLtoKmsd/90ntmuwB/DIgHsVr5PuIzYZGem7cryqxgNy5rI9M3uE5xBW0Q" ..
	"6oGtA7gMfSOY7KWm2mIaY+bT+WgTLOJYfLURXNST0i4N11Tu4L8QKzDNdVrgVGKQHWHXl2JQ73wvVxH+75BqhxfFDd0m8PPGJRu4" ..
	"gS1UiFGMbM4S0PqC/5G5N2xnwfli13NHlaXtnJMQkaeZA5/d4NdBrDuSFqvoVPjSIx6YUv00p+fGUWV9wlFowdBrg+o89zLpvpx7" ..
	"UaJSihRybWVsQazGj9eBGkI5XfOOCHSGuJd/AtZGJkqW1y9rN0TKq+lvh/o/3iwpiEPopRw0qQ7wKWNriXbxqH/wsLMRSWB8qy2L" ..
	"YjldoLTqoziQ6h2bQRaxJNHNmNOV3NvOPhaYb+8pts1FSLZvTy+bpsAvhfKobCq9qgqbA2x+3TQo/8NuTAY7Npdeg/QWLdaBV6WU" ..
	"UyTHySjRh4psTtZQJuABOfJDTbj5wccKKqhgcBTlkyVmoi8/XuIpce4NIzhN+eRsEqUpvwiTs4L8X+acFpo7XREaTs0Rh5lOAoJX" ..
	"ljc0VxRcosmoH+tsMn7EfpfQZ5JwymgYHmNIXvlRXN/NOQzOhtaOZyoL5Leee8QXVAXHD1NaP2tI97Q+NzWathANbLgNX0Il4HAa" ..
	"zOnIHl/qd8xE/ysxJ6B5RfO/j5xJiirz9+afdvUXBGhfABNB0WXFSr0+wBWd9ALglbFGJZmHQ5Gd0YoKa4lJo6iPfyXI49dtG/0d" ..
	"nK8AVdUmAx6fOXiNTF96e/CmnkShkVOhuJ83EI4yqL+jvKYxNNP42t+waX0jMaEukdamTL5GEkt2XHdkYLyjeJDdnD+WjT9NMnm6" ..
	"zotdTwMK451dUuQmWbVpmwqAx5SWNHNvkftPSmBrYHS+gOw8Hl60NBaPOi6ing37vXnZrWUksidAX8IGyxSASBoEZg5l99yrUaCR" ..
	"elqpgzfNdd4X5rm6+HH2tKTZ/mtSARuL0QSxRQtPaFNTf7xE0EIzOjgVrzd4aoySJkw0/+x9LskqYaTiIzdNHayXnM5qPnpYdpOk" ..
	"RJRZg9FM08cF/N2l211I3NK32DGV6iZ7y8ePAOgy+Sp4M/MWCBfa54SCvXOxnhBFpdIg250vYnYJM6IzphrJCehJ36K9h0eCQuXG" ..
	"/D1MUk01Q1HFH7cqr6BaoeGF0bRrNMEIwdcmnm1e7fZV6dLC51Mmh+ijQ0lRrY2K5ZxHPEWlehd0VZZ8Y/yXXKNfguhRrHlh0gdP" ..
	"cosSUpikQyit0drHpsLT3DOrI5pBwJGEA3+u+WbC7U4dL6AbhMANOIMnvY7lrIEZ7WBpFOxz+Te6rle60cO97/AUKQR775DZ0Nam" ..
	"TS7NEMgz5f9Mr6HZ4umYo7FxOMbUthgB6ipUuzc3JG3LSvfHxvz3b2EhiVvaXE5vCd+aotbZbE98TJAFEx6i+h2s56CiQOr1owm+" ..
	"FY/219HzRkqp0k9YwdRuUNdUupLdRqakpYQBlKl7xVxpG0oUAmEeguBP/OLKc1Unkq3APqFhIo9jyk546UheZyrlbVK7X61NYrMT" ..
	"mCfVdUoxMV6oqa5Ibav3/hj0cpjDjFYCD1k1X0Lu2G5UwnIqXKaqclpYQi1sJkjWzaPtR3r42MOjeZOpY0L0MMYh9US4gtB218JV" ..
	"cm669tAjH6iXAoztUZAC7RyAIGByAfLa98ZWriyxZ5Y5ZT+h6+iqHNuqCaPEEmmfG6xK1UpK90yawgixJ4LDzqb4q3KtXj1zbAyB" ..
	"q6tE00zmwsiuAFnimXnjS/FprdU80VXhseQHLiCShMECEhtPYZ8q9Ze66Zt0sUUA05FgvvRPkqLKkVRlPhVudVdIKWjiZxQjsL7A" ..
	"ICiHA0JimhAAsTCWfkpr/nHym9xr5/shYBHscnQ3zV+zuHT3NjFFxMSYNI8I9oRIdmrrZvlJ5n0/qG1YwU0cz/TrRo1R/mft94ng" ..
	"eiMZ68Y1QFlRUbwkiUtsTO+13Go+4d+qGtmKcF8jWjaQ7JHoyjTysZSumQdBN60+rDeTtL4SSGOaGnAnGZnHT+eQhujaS/Kg/up/" ..
	"DffvrFFStXroNYkIPg0F3Dc8aqeu/uRcCAWa3MFeyZmnV17j8c77it619KSpF4v1mhTTL2b6+TaatpiBQCXSZexJq2NxKhpsI/uo" ..
	"hMkyHnSEp/5eb2F9OZblZsRJCyU7BGXcolnAprigzVjyMYtuT3I3mgz3asDVMeyphRUJS5lTxP8vIx1CxCGkWjVWMEvI5pNzsQO6" ..
	"stTirBkL8QWJ6BtQQM+hDbwovTREOURrcdrRWl1pS1TCc2Q1yJXORxKqJenvERxgSYLABwWsMH5AlK3FwpRa6h0IrLpPNib8GD6H" ..
	"+M8TmRgr53Rj+5jeY04W8S1MdudSA8VrUOC6IBALfQXez7rLXL4s6JXxnlL6fvo8SJ7/1aStNlMH1kNEVMGhxiwZPYN/f8QdPv1t" ..
	"B0xFALFQBpzhh6UG7dF2wSjknCtRhOE71fncj1xTfmPpUgW4FUmSXhpUOWoJXwbDsr8fc9QK5CcA2xy2rLWIko92IH9fnZTWQ4qV" ..
	"SN9jlx9j2YKtDkfWp0J8MqaiEBZBs9A=" ..
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
