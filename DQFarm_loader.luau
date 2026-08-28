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
	{ seed = 1092434191, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1097160985, exp = 0, plan = 0, hwid = {} }
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
	"Q6tuhDep5g377N7bcfNkrtuqI9Pjt+tkvcddB498bGNNqH+ii6TR+cbP7A73XYEAhcYWYycMAEHXEaGJEx2o72BByeDKW8+PtNF1" ..
	"a5F3Aqkrz0G/gk7YDzmkGoLO/Kj3X697CnJDbJ3SOqr7fI6RSp5/q2Vcyts4bHKB5Nnhr2aK99a0m46SgAueKEchVyw4ezopTvPW" ..
	"3bPfR5b2IKvPIYiLsaP+Yfcv7Mw4AjOz+P9bs8yGPwDRDtv354iUpsTRJ5xsuUyI5h3D9H0HJcJFKNAQwaWO1puaJIsoLd13mk+L" ..
	"2RNrCODQdrrh7cfOMna8/YqUHLOy9Tkys6ITOhX9cPe+N8hm1cQB4JYbAcG+yu5NMf/Zvpqgud/+v8RXhaQwyJh6K7zAKN1TzOcT" ..
	"WfBaz2IipSgN1U7/WcwuNa1SDQPs1USAb32RiGSysr/vLlJT1l3SMg/9gU2ZQsUaF08JtUj6YfjYLqw6JXHCHdFZVSdWBJhP5yuf" ..
	"E0Rg+QPU2/T4h1mYqWq0pxPioPyOfascrivU0hNdrnKNXNnxtHPjPGDc0yAUGT13hJ4FUITQkXjTShmXLYQstJyk8B4xD+Bbtl7D" ..
	"QcUaWIUEpQFMXmAVOgINQJS5CsW0bHTJjxDn0lleqKtN057z9h8bcQJQTqhUqtjc6HEtofBx0lXDEsNMsTeLNX76X9t5F9+533ou" ..
	"egsHn5iJ07R/LQ9Su9gx4iEM/kC3X42ExWRap2zXsz5SuC/ay/11iMR0fLQNdaJ7QIbh8kl0PgXTQhcjLVIKqN9CHQ6ume2G3zZ8" ..
	"kbFV+VjSeDYyS0c2tLOFuWV62C/X8uSH/iawNh72DX9O1frTte+ZO8M/8AawK+wUY1cY2Vku5kFOdqvXFmmRab5ukqSKLxbIsy2P" ..
	"bv1rdx8+MlQZsiOBT5d1en24UWxmnCTV8SjqJacvvx1zXYJWj/nwJU4DgYyOIuTGXLJupkHrvFtX1oWHTRphBQqfLWcqmcfvD6xE" ..
	"R+dLF8sdM4Vx4bt2J9TyerkcQCild2hlLwYDQ8cukU//2VcvjjTEQlSRIXPJ6fI7H/tZdZJnkgJAwuYKZDewRkejuMs9i4tiyIIS" ..
	"/1RiTrzrc0d+b2FpWRI0lfJgrZ+UPAvC2UQo3iqXTf3XPDpQFf7usJ5GA2XFRML49nHJ77HkHQXU+BtYnZwtQEC4P+U2O+bxrTgk" ..
	"a/37xzjyxVfjy2TsGquHLTnDeryigggMhOmmGDdTpIi/3BtAjFVVq50ptVcWfv83r5CTHSVRh+nKeGbJHwRfYi0e9oRAXsDSElh/" ..
	"zgCNJvZOolaEEn352KxSI9aOgviDc2o+xoibsBhj2YVrAdjVH2CGSJiDhsdRdmkTQjzK9br52YY/JJvfq1znzgoPLrQYHA37ad0r" ..
	"GGAH9pNxDnOoxyiZDu+Z2ync3FZvn4vQvAuAwGVIKYtQU14F5mROMcPa3nOfaNEY4ZQNSf9uKKxF56/fVCdDSR6KncI87z0o4TM4" ..
	"ZCXEO/RKEkX8Ze8unUA4h3ELV4MTrFy/lG9aO+2cZmG8FNoYDbfsnC/S+YtbS7AWKLLJLkHSWR9Qrn2ahwXderoEE2Rednuape6q" ..
	"NNRf09JCSVxLgJOvk6hnJg4K9VjgGl6ErrmoaxTa5HqZUqCP7gdnUyr3x+hMRjGKllKExn3hDmCAdA/2xkwAyjV5+fskyzzTRGu2" ..
	"wwXeHKv0bVqARuwitpRgT+B/aaiiiCtYEDPFqA4fj5BC5Xm81hLA3omsP1/nUwHiJo4mXqSvtWIUEB4Md99dcyxKorn5OLDccLWt" ..
	"mvYVMVMlg14a3LIXC0HUbAtpUQoguHXDAm+V6pNH7XC22GfKmMiMPYQMSjUmnAhs9avmCYvbTfdRP4Sp49QowzXDNUnKdSdd6UX0" ..
	"GcrWKyZvnwtpZ4jN71T6EkRYiRdKKWvXkYGsXgVMEJ2ix6l2k141wAh9Z+VCWiCwsmNqwPAeKYgkpmRhWYGbFBtgawVi8gbgxTOf" ..
	"3kcRqJF9ZB6M0QnHHzJSLdeLWmvIXCPkWZhUkQ2cwohYFGDM4G0NzS2EVuVA4uIbcbsY6Z06lVnxQtSiTbNtN4cR7Gf1sg1CRJ07" ..
	"ewNhuudQAegbNb9xHnBgiMUBSvfLDvEg44DUUZ+ZaJnCl3NyBCaA0sDjNeqEVRHBiHbd+fcb14TYBPPDB/x+cL8Frd3H60k/XRSZ" ..
	"mja9Us1W0tYIbEm9WnRLDtawO7otU0JyT8XLKHwN2WNW75Sr0zSEJpMqdsrhGuafmBlqx+r3yWuPeok+4NoE/jTjS3XmrZhzd/cI" ..
	"GwrlBwVO7fgeflAzcqYHjwAxFkyEAxqMNGyZhL5aCzTcmJwrUYRd8DHtUWB0AGUtiay/pfwRABuUMehIlu2ZC9ms/MMgQIouIM22" ..
	"VVOvhgH9Y/j8rhhPbpV+atsG0KLcWDMf2AZsXxV2VmMveZpwYpIO2uR+ZUVgRSq9EyZEMf2iX5MCGj0POBym/vagF8QKOLJKQ1Xz" ..
	"z7Fw/MnmMzcvoX/n0lb3VUz59fspeTZu5rsOZ57JgnDC0YzTaN5/32h0j/haTdQVn3iEl/f6fNIM8hGJ6FSx9Y9zM2a7Vbgn4SUo" ..
	"R16p0PM1HWo1wTVCQuiWqYgnyijDz2kbeCOVhrNwi9ddj1jlc+LxCT+Lh43afw3XObQcZxK9YTHoEU9TCDxHx4JY6GbKlr4i5vHo" ..
	"KEaWlDgRz9TtyAt6WNo6nL8hEbyaOlD/pT0a/CDVOATKmETveh5D7Cg07IM02ndw3+Z4yzYJlK4NTnft1vGtG5YUCiDBTQ8zYYzR" ..
	"DV7JKj5gBb+NCLivxiM41YGFBrCygK85vh1NG0P2mjKJLd8p9u7kwj9tgLDQseysqgl2ehuMXcg1S7THp93CD7J76OZz+R0vIelw" ..
	"uaHkv8h8RHVRb4egGnrlti4+L9XlBLnZltkiHGUNeMbvpWIzcy9mbrsIHIII9F6rGsvarwxvwIz2xde859Lim9Hm0cpwZUSD/IPW" ..
	"COd7DR1NW1FSBGSma+K/9txXPzqYgVI0+VI0++EtY/SPe+GFqpyLrZL0b1wHNgdXW2lgRNDbLP1YaxH/6TfgDHsRlCwN3mEEL6OH" ..
	"fXu9VEPU3guqxnb7iC8Vp1+q99wVCV22V/WNy8L5d7CKIAfq1Q+NGDRJokOtuLkNmkMDWTLmrsuta3AstVwZT3Iag2TVxkJ5/mBp" ..
	"tvL6aPZfYktt+qO2QLj5TICYDFjflqSDsieKFiDw3enT2nJgYDtpw1MERw6Mc7ZuwK1lVx7b1VC1RAUP5rOnOkvjBP+EsvwMp12l" ..
	"CbdFivGK1mB/3ssxT3Bf1cbtEUFNUkDrkvhGoM4qflpAdpSls1RvhdU3TbWSiH3q3IivcwSx0Q3goUtStYwgimE/4NCwF9ldJK4g" ..
	"GLvkn9LhUquOwoC7RfUZDYN2GNXfRqZEKM+kjQ7dEBbtlu0JAetu5lkzfnqPwIlwXyGgQClGzQEFK7DWYht6OuAUYaC+MJ7TaO/e" ..
	"L+BEuIuYydvGgKPmnr55sR3PbSVfBfaBIn+jbsFm8Y191axB2trWq00LUWb2+b6GiD7Dtqh3K2pdPOTljgyXayGNNK999V5FHkC4" ..
	"WjJGj1DQmsYdRgeST6crqfkdp3a+ho3V2V2MpYMRkTH8oG31RbMFlpMK6k6vkg3nBbF6wiXrDgOT3I8YVmWLqZwgcKAnhlt5UUoE" ..
	"UzumxAaYWXiijIYjX6pc7s4fim7y601pcVEDuScMM2+uB+TwchJuM31ixhxNcCjRhoBxweoOq2qWGP4HowAnE81IIoYKmXOjaGDq" ..
	"7UEtGwdKu6gqi8grcF/dBtO5J4V5y61tuRt5W8U3K7TvHte7+gmdd26UbWPsLTNEWOec5Gaj2hhiplP9gfi+dooX7+dgw+nWLw1Y" ..
	"DYahpWpoPf3yBgxY37lZ2AiOJArNzdDD1qBKldQZy2d9PukmS5NOQedN0YthcDjIiB3B3DHsD5pQ2apanE3AqC4V9I1SRqPdxwmg" ..
	"FrizsMlwLgfDCJW0kFHao5R4xwPKighooOMQT7Mp6V+LswpWO+lSwB73d20yG9E97zYH8XsmP7CA3ttXOXskLDEGpfdxgSzuAxtQ" ..
	"UdZJfMSEkzyi/ktDvaIKBfH/hTawfZN5RcjFFuLLYI3ym5lVwbS7dr2H31Xh47aQHCkxDFLfSmcRAXtFp7xTxw1zkIBcYAOIJh4R" ..
	"z0pBV5C2in/BMMxBYCICw2N7K+dGD8VJ5jTH7gNvgfYQFNI71P2TO17vfOxyT2LqIyKfw8fCdxCQxX5+KTHFsOu018k8GQOF/obr" ..
	"aABbQiIRJGprIZ6bFD4TSYEh/nVw2OJ7Abiud3trx6ce4RKYiGPRtY2Bxr9eH4budesjWRzjOv7Q+q0sglfIQBa7hwNZZeBxhe/C" ..
	"KE1EkyUb04wm0hcJgmmcfkGRBO+PXh333k50PAd1lcVD8Xiq0aSfRqw1bCl8QVruftItU8jtBxl4CKaG4wpk7eEkeRUrqF0Amieo" ..
	"ar8/ELVNievmeTXStX9EzG33U9I+k6GX662Ma61FAm7SGL0RjdlUvs3eUy9LtQJxvaiLQVGq7ZZqq8l0CIlYV9jgvlvSqAPxkdPs" ..
	"9HrbsEX+0mjJ2XQbaDFOxIo7k2MmFWPjkVkXn80JLpv601yXv7m/ADiGzcS5+S8pFd3czS5h6QIZ4VqhThxTaT23LWC/jRQ2QNts" ..
	"6CKQ1Fm5pqapXdrenGsQMPABsk2MLDufF4Ys84dqk6oIhGnDe+AW2IOJ4BcMmBGK23dZOB6t1OkcfvumaNy4hJC3iejSAfTjxzWk" ..
	"9T5hyOApD87t4kNIX6FT2BBwH9I7Pm3i8pW6WMVQ2W0he31ICCqC+XkAs6/Mg6kLjIoGos2YA0Ddf0dvpzI+1NjE2urZdG8IgP/s" ..
	"JE9KbxR2X1j0/jsEGHDZLM4VSs+RrtwfN3+qI1vaN3SfHwBDCCMl/sGUDBCJR8I3bLVc5ffAIC2AQhZYA7aTx/qDHRwHmBqkYfnL" ..
	"rTnroagXT8QCCa/mtH/P3gPmUui1oRJdgZ033WrkM79MYynnm3a4N9LghGjSvmqBBtOXoPK64LAz44nlqR+ye7Tirui9jNYE5Ynk" ..
	"XCA9RDUsHyRqwlWaN4Lfd1BehO52vPU1rNPUP5wnWL3TGwHIzL8/7enz8RToM//tRBn+pl/1+xzKrQ9bu6xfe+HYAo19L4QNXnIJ" ..
	"YTnTVvdEjSrEmotJgnlparwavBQDkpzmg3zYTJMHJoEz4CPU6mkxGa5L9vAkc/6CZtDNMqXI6T0W4VS7GSZcYgjgTzRmzb4AfpXE" ..
	"KSSonvVVxfwVf85ydYonWLshlzaqr9AX8YPHmDNuT5NHtMMzCLOs1z4wBCwuNy9K+qnAGixYFVUWLcrfRkYRucwTwg6vbedFt7+X" ..
	"b+sFmLZen/gg3DvoAwcN38m6Hu9KiS26VltrE2ywpBSdU16mBCn2xFOiC4zHHXE87394lbIWpms/tCJnVYW8b8B5xIJ+5O1fZWVz" ..
	"IcFD4lpDEVfx2W6SNkozjDgeEQA6qJGYvZMxrsJHn9WZDrgOAR7W85DjSwzugeYkg9DRSPjZSVeCUhxpJyvgbUvhLs0XnNK+5RL9" ..
	"/OemIOzMEa+VIMiUOPpiHC5nxAc6joctMYnPrG++G/zCZaK568tjzTAw3QD/BoZAlsuijBFQBZ6buPdCJZm11vSt+R/C3KOjJBE8" ..
	"6Q5WhIZfvjw4W1/AODQU7xhrbJoetH06JA/3z/km4NzT0aAGjMbLJbvYh33Ba+/dLcVqNiNC+PdoOo4E4L2G2lg77o88zbKHJunn" ..
	"Yuza0oIAEErfWRyL3fiexy+WbFDnva9ucv1ahEundg+3Il+055VtSIivuQi1vBap+1DXmTr9NiaxY4yCKPKFT6oUJlNoXLDFbyRW" ..
	"tjTAFVIBDfdwFRNBkY1kSHHX6z71LIcMV6NUu39hxAJSOq1x35r7jvMw1FcW9lUVWHY7DJPouzSBayQEb7vZYy4iNAiUlcZHdrcL" ..
	""
local PAYLOAD_P2 =
	"/LUpQLACTWyL/VWlJSPwK8NfHC6opYdJ6kkA0xC6y/SGZp0ZK89BMjULg9oFO58qNCpw1UYOy0CreEOOh2pyfxd+iVZJfyQ1LcSV" ..
	"X5esyTt2oTOIOMU+7Oz0PhtMpXtw97iBcZyi5R3CRfp42utO9468LGOR2h0iIRW704kdCSlSantido+VMfssSGV3mGlASBCHEZt7" ..
	"6d5fcvkr2G8vvo/fEx4MtnwUuyAKn9ZaY0womjReJcBsSppQ2F8JsjF4xQYVfBxhcKImlGTUio1WXlnejtZJz8fXHC89vIzHU04a" ..
	"6C2HcExuBGZgVmY+POEJvqEU7UzyaynmxzI9FK2IejxoYntUEqcpCfh0e7sRLQKkVA68kh+vB6BdAK+2EBGuDDYI17ML6fXZOl3/" ..
	"7eJ+hcF9CA2wULtGWho9EIUiN/73/4JgrJM3h7Vth5lClxTOgeSHlsstmZbh1pZaz+wA3ULY9grj9348VfslaMr5529WuYmCDit6" ..
	"6PAvkSBIkTfvp6c0FkdIScawOh+ImvgZCT6Pg2hSIQ0UHVdz5Y//zfeW/92tQNQCb+n6qddlUZM1U2BfzXEJmPu0JAvcfS9NzGNW" ..
	"DeSl3Ze/tnb7a0VFYuzyTbR4yb2iyjI/tPItws4AoCwJyu8nsAwR3Me0hwBu2X6usTlIeNPlUOU38tX087leZW15jN87S/NC18cR" ..
	"t1M7WLIhrKDIchtWS9g9Dd+a+i4aCcDI5Z7LO8e2wO1BDqjgj+34dkLetqP6fnkpgPIfE+ENMGuiDryQnJjw3UW+4maw4wDt8/k+" ..
	"EqZBEzSOdni9EQOxlA3GCh5p8TKjN/Z/PeyyuXKLzZuUBFxfy9fkIqvRim5Iqa8SFFlzs9KS2q/YCjh7ZsYakYTFOj0znIYO1Umv" ..
	"IMIK65IVo7mV3CnjZ/vJ0eq7+7pID4znCjN1DWWhMjGKx45vH4XOTyq4+jVzYTbm8yqhup3bXYhEMeC19uE2yT0dKMC+w4uZjVOi" ..
	"yEphPNCd0IfKYhIvzC2TzLaYTYz+rXNKIU0ISkiSk1QiNTNbsBDwuhXbYFo3AZjh7vGYMIN7vK4uFs+PXOflzJVFnVw/pFS7gk3J" ..
	"0pMQtPhF/9w10obtPfkK6fq/j1Wug42B9aDX/JoR6119wYTMie+nZ/Ox15tsqw1F53lVeWTFVsZoQh/k7Q8gLJZpQnTljX3aTBpN" ..
	"1awW4MKWM7csDADvi7Izzx9hCGESYeIP+JaFyLwZmGIkJgFRlGdhVdsKqOgUjPk1FkKSNCmMH9y6bdCslNUTBP6LUQ27id0c8ryW" ..
	"ou2KS0DEKHNSW4e3X2KImSk13G1pWPTfFVOErm3p3W4v2iXWJz5l2DLSOTI4A6LMJr6mJIyRpaIHVNPO+0WiVsTCtTZrz1xds1yT" ..
	"G6LGrk7RU6fc0762Z4EPEtfWTwd1ZGLvNIBs8tDiUiUlfCgOMECLYNXALZVpu42ZD5ktWERSAHAAohOFQVHZAd2Z7Vh+qATeuHa4" ..
	"wWB7dMaGLdcYbujfxOFTdeEpJfxea1bf2j/P4kkQLpd0cRrFVC+FCetUHNw1UYJ236VtkjVE50aabqrddTj+eyjEeHefQyy0OAie" ..
	"NDbDdVzlzrxRG/1UmVntPQFLrvwR2QZebe55tcIwQ7qL4ZfpwwjOnXi2KQ3goqBAVHkqGOLR+Hk3jQvGbwYANyiwWwnqJQcHZj18" ..
	"YgBbhtBjqY7/1PRmftIoKEY/CEonPzcL6rlLbfyGBWkoB2I5tFxm/UureMQjjfvYlkRnf4WKYgTSm6OU9nr4b/THZVLLE6KX6uFZ" ..
	"7mJ08rqaUB4CUSwSrpnCvufYIoKVrEqnB0j6t+DivXnWpUui8mOv5xegStyGyIradKXNfK2Av+SSJC7QlxN0oJ5+maClaW2mX64A" ..
	"ME+8E/6d5OVd1zYOzhMZ4gtS/ZYCIMHeX1fhfGFU2ZbDvGizz6CKhNRJrTnKWop7hC9onwLM489hcHdxIPMcFtj5KupbrDILwWlo" ..
	"WqwgYM7jJjEEd+uLbkUHsliI+9+q6Y1DBiRXuFpA+J0KSTRb10dJHeURbkVT4OerdlAhzoBFHW8vWxPgeU4nNz7L6lor+IwVyVly" ..
	"Cva9MeEbNNoZ9IuaNHFgdY3s2GZh8S9hC/Bsx2gqAFQdB4I31JU9Uv2yOYK1Iv7YzkkR4Ru4xPn1TWSdP6LnxLGkPFdlulfyX7y9" ..
	"xza0bLhPYCtab1PcjjqQqUGvuRfg8o6q/Mg+RBkmKrmhz+Yp6pChAM4AuyRhmeuMz3z27M7/PXi1xfv83N7TayhdAJDmYiVX357v" ..
	"e0Sm93VftF/Dbc0kozFZzvVo9orc+/CeBfjzexSLBE5vcRbIvQJb0gfyrzHvMG+lokc/J1UE+MACR8tDwf7C+xnt+P1h8iaCsJgc" ..
	"0msJyDVnHjsZJdYyTOJLN/SHX01MxcF/FGdd4qEaXN7DAloyLIQEHjFezzJsJIxTd+Je1cdHWEtEEiuMYlsFaEDsa2NLfi54dV1e" ..
	"3KMJPTvb5T861NG9RpUd4SsDRA1xvKXKyQU7ccBLRBGp8PN6TD5/0vW5yTUFbcsBo4Nlmg3oZMLlxCC0HOY9/X8byOs68Mxct4Mz" ..
	"BTRHNIQDnbsGqy9WOfcxS/JaAOhSQtkuUzCkmibe8R4AGf53VH41GWkdmRa+gDTH6ERVM8idZUh7uYkIM5c5mJmtJJNMf/3j46jq" ..
	"UapfV337lv3+P72Eh2tyCJO3oHks3gHrSnOpuxufQ09Yfivof0E/q0v+IWodsPzOfAgZiP/DP7akZt1kvRo3aAPLa14Y3V989wT4" ..
	"E0gCmlx5hWugj4Q8PzslPsEw4XgCr83UlqHC7Mt8iH14TCD5ShkrWTLTfZxrTONfyJdYzyxQgWEAmsFroMoBF1fYo0LAagemrBCV" ..
	"SOCWqj1uaZV6t113UO0VhmLjUOWQ8rbTNfwBP4Zxt/4SxvvaymflT2UBGY0CLKpnIR/HTfiLuHf/TS8uIiUdWDe3JtU8imysDwhD" ..
	"PHN0U21fq/OIXO3W/XsNXt1n1tnNHHXXSDUgJo361mQdpng4MA3T1MrG3o7bxVtoJKxdUdJ24xoK4BQ3jsE32i/7FD2r42L4ndX6" ..
	"YiFSbwYzVWpEezTZWVh86iB3ZE7FX3MIdhadz+TVd5+QLT9+03j+HH/gnD589Qr8K/otuIsuuXy5af1UuhglkMZdyAnCNT62cLtR" ..
	"unmso69XSA2shKvf3eFHt4I+37jNpD6xb7w6pLknZDeb9zebFrPUYYp2eIxFMDX4weOy5futYSzUwoIbbYrzqQXDlRrauu/d/hih" ..
	"Y+6ejC1zxYfyMt88VCixgkE1BC5lcWpQjES502JjoG4GKbYU4UcayCSK5OGYroXHDFFlqXmfaxvt+Uox7EcTKb84ueFDQsQK56pb" ..
	"h6zx+FOkJwdnrasFEnXpXbJ6O5+GQqFa3e1jTrJqwtKQfNPu9P6p8nNrEFDWx5BqytW+YkCEZjkk876K8tVYoQQFO92XOikyh9B9" ..
	"FchFqVqAu1lxyV72A27rTXJVAXNPIv7IB91y/v/h3la3Z9VJtBOa7guNYRZaaEGPwRfl+PL3r4NTdq3Axm9V+XRuArCt2U1oIRJe" ..
	"Dqq43UNCC8FNOgP4jmpmoedAZkaqQ256gs7BeFvnAioP629kBuRkkfoyX/wi2a0Ub3BxvQBHIjS9NLHUNN7pvk7wno/MGcGlvZ0e" ..
	"5TTdYN5IVImGQQxjtgYIx2drKYy/sv2yaqIjHM/hds38JpWFZOkwsjQ9i3K/fQELFUsiRCIUHRSTa8QYTuVYNY8igrB+pcXLI8rh" ..
	"6F1GHNqoLGw1FPCkuZmbV38g4DztslNRuGU2VEItb8yXl/iV/RjzQwSPbKr2xe3xnhRSNbZmWdvlFT1d+G/9WdbiBWwlV7IZ9r/E" ..
	"MXjxZkV7T2sMannNtKgfeg65hY0zCt77MMq765CeO+3js3bdrBnQ5Gws4sNHaH5zC35e+unWP5txWAF7Gvws60oeZ7JZUSIEDFCq" ..
	"Awta66B/04Qqhd1WvsOyj8fLAVEa3ddmoBjhEzl4FV3aqZ7wM0qhY9oi7OuY7b3uyFe1SUtEtQrLe0nTg0WSF/3grPHrDYuQ924q" ..
	"JCBsqX9zllhONS8lr4pz9KarNjUOwCH4E7upqSUIfx7x+GfK1QnzMmq8I549ewj1+V0HvNqMl9sDrqPrCmOsCFvhsewY/zsecHCS" ..
	"kXmscmsL+PJTScR0eoiRKy5QaAQAyXtNylZS0BNAGsxn5e7Q1WBI+BzZn3cwD5LzxT20c+iPqDau6b1XGxqlHhzmV8qvTddOnmb9" ..
	"B3LP1Qgs0XuN3Kw8t1kGPFtHNJUC6BJ2iAALY3cVVN5erHukLRY7VqE0Qq9v0LF/1kTF7nvk6morh5UUCMB07ggDPwUHFZ0edPXU" ..
	"yYkU3mFRmkK8YU29PlboIU4ZCYUdtL0TuUlGHdsnKgb7uaIPhzte9rHtsNm62CqIT+P1h1gtbkkIi4Pbo60c9SAg3FlgEPd618ek" ..
	"+QoZa6LL04F9H54aRG135MTXjX6WWt1lWdZtjewR5HRHuwgkrniVQcfdBaQlsfYtWbHIUxYScwpo2KwskO2g46UBz79AeYhwmlXF" ..
	"uV5+nqzBv2OfI+SQNRP/7WRoX+4w8QZkdZU+6ZFwlvEdVxJ8xK2UMbQsiO90zNpApz4+zff0qYP+92UIkl/8Bo0XTKD7lFveNDrm" ..
	"caR2RDeDuRIlSCVioIJxgS2fSA/TA9LKumh6GfMEP5wuPWsHBqYVcRoP4VwmBXVKkyUFupeo+smRw9Ind6dAYFVKPOm6Z3Xsy7a3" ..
	"RfFXs4oC1YEF1bvuMaVW2+6vWCquSR7xa1fcpQSBdqN8pnWujD0qQneSsBJiQ3YZjtgvaeNUEwUO6/GhbSDShs9fHhzqCgrZqMH7" ..
	"ny3Tjfr6zG971FAz+So75c2/0iFj7JkZhZTC0F4IY5pn1LKnHh11AZyVducjyRe4rlwD5/w8LjTiSrPb0BInj/h9awGm4N4cKjpW" ..
	"FFwrIAcwcRvEUakj4z6bdgxc3RysJnivf8JpdWKjZ2ys4dYeezMaiv7ro0D54fI08p9Bwkl7bb80c3ThaOoDB/WCNF4Fuep0Hmbk" ..
	"5r/yqO/4hZwo8IndCVfbZjMp0GycKH18YAJXf5y7jZJ23II8wABwVa7UjgaspsPs16+07rjNOK1EmWfQML+wy204VuBW36ua999B" ..
	"OYSISaIXZRACCSKbyB1oauDCvo1Ap43kvZL916sOhQNuFkzQLJWIaqLr+Exc27NPKEsYNlhiJT138XuygtkZRp+R/Tn9z5cESg6j" ..
	"U2Q5OIqWsFq6Khc9yMDUCw2nkKpRpruQrhHuvH3eZHBOS0+Rdq32ckROHakVaEwh1zlfqbk/1tWq8pAP/9JJWvxsYeaUl21NX8Ra" ..
	"8PF8DPpGTNj/II18rkT62VIZRensdBIbRWUVbOrNa2L0PfgkjbyyLlKOCXTNYWC7wcQsTQCaXyTEeCL0I3aw1UzkUpmAal0AFJeJ" ..
	"2xBo7Ik+V7FpTObg4WBor41x4X7K918mJVfq8kNOuHiI8xzmZooXjGqhepcWX1cAzway2wtmSGvNPLpZ9gbaFyChtkWw7wH8Wif+" ..
	"fTbWlvNiAT35QQH2B1aDJ06lQE9n9RTT/1elXKRLcxrX/DCVMOExIEl4eb5KiSvSnCn17Oddh39aeQs8O5T9P5Kl4Apd/w/2S1As" ..
	"y/e29Hlfnbu432FQsj9v0w5qZsCLZdtkql27KJ97DK5UG7QJ58oskhjNBVjOnAZYo+pWMASzPR8A8kzvUK3CVDcjaBIXJT8UM9tN" ..
	"wlrQ3k2prFywu12sXmzff/jr6KTWpzqKLZ3DdGrsNaOVxfJ+hKoCejtv6TBOWPJZih4ntmgUlYNDZGkyGO4VRUWcjf8yfYgBClTl" ..
	"xVqeTzp1oXhHVr9eSePYO6iohO6vKmD3BhMucYp1jxzMyVCemneF06sWePzpABpk7kv9XjL8+3ZKkeyIEcmTLrfkMVC0Mt1h925d" ..
	""
local PAYLOAD_P3 =
	"B0Uy1D0x36/bs1a3YDcj53vZcIOfbXxlIzi3O7Rj5E4mkyuy8+qg7DCcXp4Rfun4Tv9hWrzy+1xTdNUCEleOlCjfUjRk+PgDV+Rp" ..
	"4DMIka0mJWNG2x0xEgE9aFQgWeTF/el3gtsOLNTk7Ia9Kkpv7ehp82ULMfWeWp/K+eChkeDlyH6QI1z6XAVQ4WmJp6ysXUyAPNyv" ..
	"LJFD0zQTWTVDw7CxRmesJAV6ujqKx8OI3OAyAx5gVe9Gl5NouvvjdA49XypyBTJPDs1uUDN5jBeB3/hpApvZyF7Cf5n+rozbc1IX" ..
	"P36EwWvKM8L+UEsJsb/l73wVJZug0COoZc6ruz57plrsnjy40d1nERWgWOfrI3pY9LAy/8krdD2Y0gDXdFb7o8Rt+axTyX8T6XJ6" ..
	"f4ozY0ktbQ1PJcpk6jYojYXyQkP9UYGnbCPnsQ6jb9laf/hlj/E1THHp7OZ2VQg0o3T4ipyTsUr1lDF+5p44KyRTjxX2DQwkOaXX" ..
	"N1MkkZBdAgm6yRx3bioem9cS0GMzME2+AVclszElwdLz1SGQ7Y9fTjChJZfdRJwub74mkubLv3uFTf2rIaqPL+vGfib5PXK6SH7p" ..
	"iiAF5OR7E013VlrDBAQhyAgcBHL/76kFqLFwa5fuWWs0a0z7iYC76GUbfNglGRMo4gJldiyWNlkV8QBufsyTQ1bAkhrstrJZWlED" ..
	"eH/6kCuRXg8zfTR62gFELcSxOgBUem6IqJ/sjSYDiMP18Vms8K8J7uHlKx7x5thWKy5aZjWQeRyQpQSWuJST30atX/XUR4L0JGa0" ..
	"/bNFJtclT9xBBCsh9mc7Eht3sBwNlOkuQSI7DYN5agfsuCBrT9IHVSN08U7XWs3SvX4XkNRSdznX1Qg9JA4JqKU49oQ5cri8ej8Y" ..
	"OY0kHfDZ9N6H/rdjtwrIQIFe55V8VviStspJT73bdAuKpL12ItDdRud7thjYS7m+dPwEYqeWx0aKBt3W1RO4zNVhVkFYCmsz6BE/" ..
	"rdFvlMGQSJM0qUbsFwGss7PmIaoftLn0WbkZSCXzd/eq7rhoB+A8gxdlvwrpJp0/u34VYhKvon8uvuquqDyoTMpoY69CuNYPWQ19" ..
	"1jy2IngCiZ9xO+UDfHjP4zX48CZe6wWHaxYRIdLjUaG3/CEva011yc3OO8dAf/6YbQQxOlw+IT47qSYfDVwu8wqJPuqbzxN36I/l" ..
	"CF4w5NYyeADoCj22/FpCV9I7Iw5bTCP1YkBT5VkfM16BCslHIex1xLq6Bnf7QHNMpO7cPEkUqkt37BOPPuMFDtMYqTSs1ZR7JH0K" ..
	"4dEHof/uHq7juKIow5cz40xDWLUkBQ829v0/6v0uHzrA3bDABm5N8HXbXdJlonwnceHc6tde+UhR6BEAO+BvX3wEKp3qNVJZiyil" ..
	"I0/3rfQZcFD794PkLpaLtvNovcPsreskriYksc3E1D3HRgKOPbz3Sm2ce0QZJlwA7PkN0Qk47kPUWhPdE32gKqcd2p/I80+7mWGn" ..
	"rbR284URCXdqWSjyn258VGzURBRQTP7NiiDZWor8IR6xZ/VXVaWB6UHphCgPTaVr18fstq9RV8zmOEdN/C+1rllAf2O4PT9XU3rh" ..
	"gMg/oPJ3BoSO2c3CLcChAcPErQzPII+bBGfz63sQG1E7n4HPXE57cZ374zJC8yeO1r04qSXrW29wdEziYRWR7N8IRR5Wjo4vgwUI" ..
	"ZNEGMBJE2RQWhsbVm6ykqWAa7dP22bNh4c/VE9mSldlgL9LiV2gWuEQODxuJ87bmW3Y571o5ZDmerRsNsP5mB5n+K85aZHufHBbW" ..
	"PA+4BFLCDM6jp7Pl3c5u41tiY/S2ksZnukt/sYrf4F6RhMoVO3s/nrbYnAeMpCk8PVXA4JwhaxVvMwGa6sj8u8YofSRGgsoo/cBW" ..
	"fPIt8Rlmqn/oxJYt+6RWxZ8QVqTvrAJiYFT+YD8ZuJBwVO4eZyJO/S99vC2ig7Lgg5uHH3kBYlkGEJT1FwqBlppkO9mEUnkDFiAK" ..
	"R1dc5rnIaj9o0hJ2/Ytoiu2DB0xtebfSR8q8H9TWFAikzAxBkeuZP7NXUTnZwbubLIayp8f+gvZPxfhsXPioOLCnwc8+ShqPSllG" ..
	"q0OofV8SfMDAJgKxR4u94maNYufy67U0eFBrsq1F1yPKXUwdR8EFHC59NTZgxl82qpSfm0KC53serg3Mi4BKMKTm+BQhfa6+Pnkv" ..
	"wyQrtOq3WWbSFTNGLBD1H4FwE3eM9KxeJwd2b3CeRssNPIIbgB8axXnLwZPokbBE78Y2pM/DsLB1dd/m5S7Cy0XnhdeP7WsOxxv/" ..
	"5cLuGhP3VtS6eIdZXHLWCvTultrHwh4BJLowFknxg/6ORtQVvfTNUJGBgZoy3FBAltrawonz6Gd7k6avlD7f9SD+xHlshUk8pXx7" ..
	"X56JuVs84FjE/lKan2Sal/4UrdtEU2GOqrR3U6WJ9dUUl1UN2yd6Q0UZXi4R+zh7ZNpo1bNItA1uxJ+I/Fjbhd8HUOKf62N/ORVn" ..
	"YrMIvhLf8NnbGS2wgjdy1M+3GYWP4EDAE7ULef2NZg1b3DZnVUScoxphulY1q5ovwczOJ3droEDtgAzGMEzH61lWmk0zUWbo22TR" ..
	"Ugdjub1InV0tiYyiBizP9hCqsSLcqk1yeBOCpQoSD7w+z19pHDR4nmiwi6RwgjWxXboMS2qri8prorQ/k6ch8hce7J88462T+wmC" ..
	"+yCrOewDZzD4Rzl2ZCTgSaSPIspLlDmMxV95VNLYEBsiuIiO16hqGlDSrDtGDV6VxPXyr/l5CXydQ6t443c8hvB65HPGqDxv1i0M" ..
	"WAKNzLuT3vML42CG/jKzTv0K8lbSE+fE23EOnNAykuzRxWpLi5ZALd+BAyTnw9HTocb0nVvcnAdY8KLaujOd1A/uNi/8P1kwWoLy" ..
	"bll3Euaafxa4KmssMB23ma4xAs6CnM8GszWAL3zxyYOBU3Qe0Jr+v8CRQEkMpKmOsN/IXjHZGZps/Li1nqBZ4CfBFOvo4kE1uwoo" ..
	"LM9BsrdYb7X5VYZmvimznYdU+bKdjoWPJT1kUANF2qB5M+u28s/oawGnbN8B6v09/1jtDIpfooEQnXYqphLf5OxKW+LBplCu4ayJ" ..
	"v1pwhFJ9KgkyJtQb/OGjPQ2zz8FxIrNKnEVgOLInNz2sG6RmZ0IBLVvEDtyhRlvXdPHRwlf6BxsryNvJ8rPd3oknpt8WHkS6MECW" ..
	"nb2hU83SLNrz4AOmuE1my3P8vg1g1GecBnEin1bKcMxEvyUGKujJzpUd8QDjmwpx9e5Tv/IasuJLB4A7qYwoYy/6r9msaO4RgQW6" ..
	"sz8wlKkNzAi/oNU/GRzeEPzIq0CDnCDiBLKrImqxX6hfhTaTce8jGuy3uRdVBZQXWztTdqu19GbuvqIysZEo4k+HPVfZ6f8D6uJp" ..
	"VbcyYd5iibTl67eVDdxMveMCWiW3VctqLRlTRePYCgQxj9q8apL2iRNZbSw30FHPHn/QCJzsUYJDzKfrj6kSAJkoNe/Iu0HTQudH" ..
	"GTkuUQUwebP10GL2rAlvFpsZuxla9M0oW6jv6Nof/dmcgsusb3uQVGYNMby4VHRtYTBik3TuT17ClLffqS2GSh25Cnt52Kk0ELIU" ..
	"pCeISSFv8Pw3OfNYQ463HC7LU189+NfGwq1IJ4S/Q6+pfobtzvuYv+J5HTNaFC33l5r9cqsppiyswHPbatsM/iQ1bmu1+m0wNsY6" ..
	"2ESM4wFNKrr/NuJKHjeTfsxwUxY18p3B4hu8tBaEo8KguQ3gkOCaqJcYopB8TrZoERjJBvqTdButA1XHTkhpbQ8Ne8uopPor0p7X" ..
	"MvyPpR+gcqJTCTSjRzGYISj/UM4Xdlzzo1Bmsf2+PZr8opBBsRTbXzyWHw30+ENhB8NsQzp/aGZJdS8mekVU6DHwR/lfKRfOoaii" ..
	"bu2uixD1ktDgSoLOCmqBWMSGU4EPeBlbho9LCEnExsQG+FfFSBaKDJ6WfWUjC6GjegAz/LumsCWafqEoDIWKr81YznxNSUZ35AGz" ..
	"A3gsX/o2Gj/x2E1ZNotUFiv2d4cgRgBiQ+6Cz3J8MLifjNZpT+jfN7qUYe/iz1LGsYj3qnFOkeZm6XWQ6v/ZU+1adBohV25XJgKf" ..
	"6lPzMjA+huaerZMGtVoH4/nNat3/TqharVbcysqzNhWyitxlBN7r9t/r7jFOsFYMxWmnMMYI27nBxJBLNQoJK93fY1jYsG+q/906" ..
	"fCR1JHZ63+p+MGkcy1OvLPUkBhEQNIPRc0e9vtXqOEBQhMG1Zib1L9f3dZSFsMh6mt4twI6vtY8oT2zOnA/0jdM2bhjZHA0f27o3" ..
	"22N+eTi/gsMoqkK4s+LdJEkcGvsBniDK6BwsBArU9mIx5g3W+xuAHvDGHbDUMOKYDnfBjoWXT/zXaKApuEN9sgccbipyvnAh66JU" ..
	"nvXTs4N+Hc4arIo+KbglKqFEu2PHHxVzcDHHbhBECkQ0Ja9XHG9dEZm4ZAUdfU3vZ3uaacBoCjqfJi9XZnJao0SA2REzfY+17zlN" ..
	"RPi2eSHE0Kiw9cCI4nhm/B40+5hoIiqH0Er3Rmco6yvHWZLj4gJmkojxqbVIHlefUZG1aFAF9W/mA6b5p6aY5phFr4lemnyYLlfv" ..
	"XC5HH43X7bkS2trUo02ICF0N3v5YJQyBAai7TUm445gbl7XrYCJ1uwXkNfNHakogp7Qs3VwLX1L961vzSo7aSustoh7LN/imBr/D" ..
	"WkWFkQOmjA4vrr0M64JbRyvNewqcu7kZFlwRZQTAhQnFO5/gndpFHkA9QXxu4eeH5synh81ByMgY4Yfr+rcpf5BMr2GIWFDShugE" ..
	"vfS37/fmD5aGqoiRqIITnxLS5XfkdXjyOABwgmadWFJVVH7A21P4/NhW61oxTAA/M9wlGFW/RrrXm222BCGCJKble6t3/AuGkiO4" ..
	"BZ8zAnCh0czoAotqcGHHO90unf10n/m/j6H8Lr2/TuqqYAzIYBxgQw0OYTpsu+CU9LgzyfgQtdpFKV1ESCSBmyntPvIu49WVUfkZ" ..
	"KcdFOzndVvaTT93yjFCb4w8T+WeXu5fI11V8CEa3nNzROUWnepZ0eLhd4CyMFsf8/+qdPZ25o6J+pBSRT345Ut7F+hseDrXp4QYZ" ..
	"bReOEouvl1Ecqd2dT2WnM6v+A4OTctP+KmXkAy96MFAZgHvHoFhvhprTtQIt+Njriqc8xDpcEkHj3Y0MetWAH/oATQUzvScQelOS" ..
	"ViczpoQgS5LejBI2QNaWXe1kd3nfLeYtz44ciJz1DAKYWCytpdx+Y+j/Hd3nrG/tfl8+rjGryeX1kCcTzJGLQl/InZ9/tx0WcvtZ" ..
	"aaNk1caVFAkBbHwvOB2QHdK9KFv8Xw/BqYzTFgoDQtaa4wLKTbaoFc7Te2s5l+57OFVPmd96HV/1/sQaresX0j6A/G0Fm5moF8o+" ..
	"RBlN5iPegaA+b7ncLYSR9QovE3cCCw/BJKNykM6VcK2SwSsCEoOsvz6OHE7Ca6hqbIcuW+4cmJPGuF2DBJuIsG9hU5eYE0WNtVIr" ..
	"TpdzUxM+RyDonQ6RZoTT0TGMETOtzzw13SaNOGWFj9ESY5e9gcO0GIEFC8fKDAkmHU6N41JjxiGg6P9q9DLQ1MSJiu4MyaCPqpZR" ..
	"nvZ4CUFEgzP/GnkE82352tLu/JG28LIp4uF1b9ganLiUC8nNOGegY2TBg9Mz0bWh6yWnsq16VbjcwpotG6cm+DdCCWvZSMDHu5Kv" ..
	"bl+w9gFsk5EHhmc/c1LCjbwT38ycUUaDf5UM6e2JEhPRVrqdWsQ9xyydcYAs6wSFxrZEabAkoiNW8m/OWgrfosyyY1s0+DxN+vAT" ..
	"q8SAR6ieXQtI+5t24nqbTiAFxO1hZoWz6D1a8VMaq6DAsCGVRnJ8oTcdKpSfhWLv71OtiQd5QgWk5hxqJV0VuQBUq02KYDSxkNue" ..
	"iK47MBK1mAFWD42H3GYzapLEW6EWvstyHN+9Tjl/9ZvNL3cM1QDA5ABiENoJ1CsPHHllkuDH3pvmzkJufEzhUJ2pUfMKyxduhdxI" ..
	""
local PAYLOAD_P4 =
	"sEFjpHkEDvDs8dfiYa5aUN79dJdJgw4vnOrpc4usHaa2mEDWEoNMLjmsOQgUdA5FQi7O6Ze7IWT1XnpqDd1QnTHV5AI/XJcD1TAZ" ..
	"77BopczH92zjzLjI/e1juME3YvrA+6IcroVA6QzgZEGdCN2MLvlbysP53qfeFN+WHABrcTj4gUUqNmlsMHDKja6MxNTeHLmFtJip" ..
	"VzkWUAzbN0YgAoSR0TXGb4m0q3zffHM94VWfstLk9bplRw3GoEeHtQa5NkvNPhii/EO4f92ajTFE2f0F+MKQTnezY7WkfYz/ge20" ..
	"e+8L0MiwVjm+aOLRWrBFnk2wmYVvUGmiYirMbsQh8dkgycgsNe2+luobySOqkcdImp+mPSL0ZXydPsE3N3u1eKV20saXO/1oFB5m" ..
	"U2coGrPxvQK9KdvAWKuDa5QT40DWHMsgpSxUXSrIFuwz5YFwZnaQMF7W5QMj1BEwo9Zi1qakHGIvcheYwAttaz5uDk5RBlDkoov+" ..
	"yBAXZbudoSJ/RQtmYUMfZ54yTSLMoCN+LcOLGf/OnzlJ7tBgxQ7QtTIBn12ONakdWTdkjVUbEk40EKP+RwniUKkCJvno1yOJkpMv" ..
	"5LBZ8lFC613JIKIaWcWsN6F85UK6C5DVDOMAg+BbVV2CRfb1HcG9Jclb23z8OY7uWxNYDz6D2YzSI3O0ILJO3pIB4HD+i9gBHOiA" ..
	"mV6LZ7HoiCI40yWPOwSZxMxWZo1+IrpCEZ5ALVeksoEjWItSHwuAjyEQYKKlqRBxSoBNwW6PMTIhq7k9HJYaXVnSjuk7QOfIFkSR" ..
	"wdQydoc+/m5hfpSujD9njiOAxkfvAG47N3gGWIssr1RS7bZmxT0ygMuNSMpTKZRKPfF/IGAa+1TTMXcVbd9yw0+CfDPl43VTeae+" ..
	"u9ReD6PwmReLvTb7eBFGtNIa1rC2F1zOhDV0A7gqB6q7fzaqiR+709Ayqt6AClD3CnenGeQ8i79NcQgbFC2kOMdamCuAWJFXsV0K" ..
	"NmYLeOd8vlNCNiyJIkEQllfT8U47VEAlQlMdzstnTXxIUj1cevGpMMwuSsJXC++nzr1BR+iQAiF2tBl1inS8Byd5e7VT0MU50O5g" ..
	"VDMZcSr5KoPiQwEJCrMs3ne3VE/qF9f9GPN4ukf+yrWnTtMLUuzKgJm7zvO19U6SKZDWP2WrEA9r1rZ1tNGoPYrp7t3vaShVVubt" ..
	"QiBSJvNoQ/mqshlUQzbKmv9aA9vvH2+ued9U9pPWHxSkhNPNAZGm05lqNqlzfOoGUgSjxk+I3OoVe9u9sk3Eu1stwrfMrvg5ljOn" ..
	"3R7GWKv/bzCBQmASbr8oHg12x3Rz7m+DQMMapPIvvIGxIjOOHPFDq4T/npU9KvIm6IMIusEuFeLpulrut9DVBVnP9iK2e/chDYiq" ..
	"5RBt7ERz/OWDhSWcFsHjgHULGv3UxWUyfKNtwiqp4zhkjYEeEfor4b/O+qrgYMh74gJ/pqqWb+eHVIizdKDePbiBKEjwRsMGTdHl" ..
	"RzbaAJkHoWVPxcXhV9Qmi5U9VNmXyjM8bkVEzAUBdp1wfW2ryPO0LNKE9ozCGOkw0NvWu2Qjy9r4PU7gD00BDDP9zSTR9r59P4/Z" ..
	"PBfFHT84ZbdXafyC3XDTcidFEJKIULpazitFLwKsSivMkbxNb1Wa7/9QGhYH4ni7+saYOnzai2fUXjgUv2F8mxThEcaKaHHMSGQ9" ..
	"/lyUAjNyMhsmKFUXkaRq+9qsT9R6GFJj03U9KiUMBHd18Ven5BnpgsgH5Z4M2wDCUlhHC1ZUiBSTmsn1cR9XE23k8Mw94yCWmggi" ..
	"8M2JqqVkBwQyRVu8NwsdQ35/i0ondkFr+XoSO9JNf4dOHlr74xeoMiwzWsMtH6nwjTXKAy9T5fX/kwdKEe4av7vqtgW4CaEhe0xd" ..
	"x53NoZfpCX60/jNTG1mhHtZn4SFuQ+CXM02kN3R7gfFFIfqJMpRt1YuyxvRmS4uyswBFBaxXGlPj46v19IAyIyeUp2LIuV2i7uWq" ..
	"OG9oQ2VfBipfIm2a+IKsv509xC8I409LY15l2TivPIJnJKKb4jNfGtEwcvZ4Acdzmzk23kfOfpWA90EDYqi19pLmpxt1PWcr8wSJ" ..
	"fStakOhTdcn55Bi7wTtJZEcBJVAHZvoOUPn4rNws0SepBZgf7SkpDiXHP1fabr1WzE7KZa03UJzmZ+hNKSGYNveTRlJGnMeu6H78" ..
	"WD/XlEBZucL2L9UmFcPlr1WoRiKq1idSP6hVj7scSks9zK0aaslgNAuae0KvsrgobbjD3zuo/IBEw1BIQRX6FUjMQdnJOnxEhh29" ..
	"g/zgZJY1ImOge0Ds/3RbKQlROFewS5S3IS9yvgjhIN1A0lZdhhdXJq7UlynjFdywKumllz6bH1wekGKJjogXMbcBFPAnw3xZrm3/" ..
	"SeAg4gNz+v9hbsmkph3r2SavDIgcj1V6045IH1Tm1eTy63scKM4CSj0oe8V6JBsEH2ymDOHe7YBeV8IaUn5ebiKM5jVgub4Hwboo" ..
	"dYe2f2JkAFAzOoFi7qAM0CjmvVZ5NJxErD3bxXxEENwPHdosRKBbye82BRg6EYw2LItukYHn2nbbIdJrx04Tl8rYADehqkHJvUk2" ..
	"bBaB+YTfed8od797rqGrjUbhwiaDpitPKPvur4rrYWnZ3SPyhmrUi7k9pmJ+J7S2hJsTtkltBaLo4s1kRH/rf4PO6DrsxbODacMH" ..
	"6GFycSz823kLDfuaS+EoK0vD6b2ZzO0hYvQDw6unEzwJssN4xtxWycGtx4gsYjoS5GJS7/v61UKUD8xLPUSJdXX6C1S/ZSteHUG2" ..
	"9Km12kohQ2e4ybtK5adIlxgnBEX+TZCdgNK9U1Oew09omL34FRq/kSjs3P++kn6JCOy1pngU3fd6/vtwQWo5d3alSPXYSFLk+e2f" ..
	"MDc041fV1Z088Ht6dEHywmxJi/h9wFA+okR+oDNEt47GqWLAaTXZX21P97jvQo39KWCV3l87k+rnwE09XNTcD20yEmfLwBuyjkhr" ..
	"FQWetLb+7Y8oUFqqXTyzIOI5OkCwat8HpJE75EI00jGwJuZFRYfWcmmS+Ivqlk0EPz3QJ6uk1fcVeOTqm3cFATX0Yo59J+N9plXC" ..
	"ZG2b2arkOvQp5W9IX2lrOoZWBgkrjgTdzeoVdIPflcgQswLCkDl6SzY6suKfV3LWxUtFbWytgY5T+jNW5yX3ZD0Oq6tVKsm8SBSQ" ..
	"UqgsL9FlEKGiIgxZQ9KklexwznwiBso/DbIeqMksQjX9BNMxkJKy6nhnPtutASV2JZnNtEgHFM8t4JnQtv0xcJmurnvjC1Lw407W" ..
	"zJ4vb9piBzMoiIJ12peBajuQeEEjeUNgjBrW9611ZHNzHq85aJcohMrhFfmfO7loPGRfggx9TOqwEA1Ds4PMdJ4exxHxHvSP2mim" ..
	"y03FZmLA2MP0gUcJ4tw3T2v4dHi1CUVr2MGtGNM6X33mZlqDuI8mP8tf/AFDUjpoWmjahJIh+8tuvXQbMjsArXeD6TJrOCPBX9pu" ..
	"L+EJV+LCA+cwx01MJj4/FppNsFRWAyqJ9ZYQ8jnwwRrFCYIw2t8Lo+Unj/z4dcfP5fTboK5GwxkWskgXs8iXdlzs5ruFS5FZ3DLP" ..
	"NgMY74goGxJmss4Z8FbvEx8bR363tcxWtTFKe2U4WBkrYYse7dA8fi/Gn7urNcuR5iRkD8Ubh7J41EdtCDZY8Y691HTQFoqEIBUt" ..
	"697jZ7DLnf43QhHFomzzs1CV/yo2+1rA+NZurtl1t0DbqhtDMzhpR0/S/CVKuPHqbL3Kh9J2Int6ADvwTt+F018NphpswZMXaAgK" ..
	"1ItkxkF9+117+ODS9xGairq5XIylgvO6Th4rMmxC0Ie/Q0xc1GJRvwQmvG6I+vW6xcjUiVO5pU3zWpiafQhp39AD2zddtkdg/Pcs" ..
	"ONXyNuibD7Vz9GC4xEuk/z7pML3Dk8JZNLtyK3d1hu/YptUiuITqcR6DGIFVsi3AaKm9hNrBesI/k7WaFveqzYsxkjnT+1LMETM/" ..
	"8H37Lf8ALnR+VO6DynNl/iu63cyY3U28l9brGzLRbDH9EcqhIrIFCp5i1MR+gkWIN4Wd9Yc9GeUKGq73pkLdqSzd66fTEPxZZb1S" ..
	"h0dwihp4YGNVLlaZaKp33PdMKS0c7GjYYsqeAX5IHmzeuxOEFWru8OmJcV8e2DiVZZOvgSg8vKmtD91TvI0D2L40vaw9kM5m60aL" ..
	"L7Ovmgic3jtE4TNjf8a7nrFK9WkO74aBuwdYv2vUBnQ2Xv2gfYFvXI6eDYlQUZhf6lSNlSv5vjvgDupgzkCrL7vW+CKl2vMzzUuy" ..
	"mlvP8O6CRKNQpnXheYZhqYbHbTLJZ6sIcGjQY8s5LTHY1hSB8/CVJkN11Jru5pV64hZbLkjz/JCulqdxIKmVnUHKYAQfJ7zcvSJ+" ..
	"eTLya8djUoh3Mz2KqjPUbUHvK4Fh9bMruFxOeXdbfxq8ORhXQFoHBTPvsj0g8N/wUwjJ4/GlCnoI2Q+b1pJWMkEUKUh+NJIlVUTW" ..
	"nq2J+DK9mO0k7gGwjJxfEBSoNfB067Vzt2glmJyimcYmuzTwz8bxsI90xwW2dc6XrzIKWCq+Ey2nUPUZEcp++yUv4k0GTDLsVBeR" ..
	"xvsrYqP5pSJ/F71uMp5seUdrYqv9pv7eJPRZUBHFkPOKe6ZBNXvEF3jSIhiJpj3Cms4lAOV/9TCi9bO+pSNBmEARiVgonAEiFn4p" ..
	"JFo7b7lr/PNGT/JZhI+SYXijhc0MdKcKm7x70QfsiaXRtZXQG/WuflrUXQIxxMGlKO8gDQjLbeon/BprIAtvrIr3F98RENLgXrFj" ..
	"Dj8iceJUddcfB7vCDQPVRqLIR5o9LS8f6UdO+CZZVgCyKRRhdAUfaYQA5KYouStHqy3xfNja9EtLNnhIT/eis1s+P2Do7WZQvNS1" ..
	"55A9jhU/mpr7oUxGnZx8s6+sSAx3NyZ40wosATnB+vv/QJ3bH7MUPPKD7t2IuOKgGlMFsFXPWR7HTd4WmBfYbUJhjZm5R8m6I3D8" ..
	"ZEjFe59Rx5Qg248HAF0EGxdc1eFeADgR67vqEagQGdVsGDq6TSN1++KeLHG6hLIuntg0/Kw/8PDQ6ZaBvrkzAI7E/AlBRLn0a+mp" ..
	"0yEfRbGQLDSGoIZ5vofOjW4aqm7x5y/68TTIbQMcd6HQ9gzksRL6ElMf8GGJSfaHd9WExQikjbe3SksVS84z6TjXwRVU7gfd59bl" ..
	"8xauThyx47BtEvgmpu6gLO7f1+q6f36VTJnzwhDZQpCbDU3KFK/Tc5TEypLeq6LNgg1ZlUZNbWQzBEwP9yf4gz8BVcr6W4vakAot" ..
	"ObjLcU7ETDNbE2f3vJPkcXDZfUEJufAG/1gXtsLvvAmi5byKMcxNBBfVwFCoJdgPJaJYvDjd9SUDC7oyHOHue+QvQX8oqutUrQrM" ..
	"aejQVKWLhtOBAEwo4oxvOotylwzzMpiE210tGh3xBvTGJiNUSti6s1sBG2S5GIr+DLg8tbMJJHJLjPgcHwf4HNMwoIOuK+Yo3e+4" ..
	"YH7k4EwzDYyWOQxtjIHvcj5lV5yvKOh13xuDWO54wFKVAcqDGz5tQ84dV485+Fuob3bcKp2HTswSS/BIkwMYN5l+BPl6Cvxcd/b6" ..
	"jzTk/B23lDxe0PNUcOYcyrTFGIqwkDzUZje7PrTgAJZtDpgmxqRH/ZwdOVFrqGWrxqz2vY1Z9YD68zg93KRIhPNLLPvpUJvypk4m" ..
	"kiSeZZCkdATVZKpuix4KbHrBT0Lg9IZiiuyAcZHo1UNDT2wqfRJzCtWNCL7688FIuAzY8YE9t5U2Bc6xgTZSnfXR0A44QQF3iXfE" ..
	"BuXZMMEgldkbargfBqZcu/MaVYk3OVkIQ2h5cpiNfqdecXv2qG+SmWfFuIKa7A0YVy3HxULMJqHJiILe43iAd3wnMP8SRxhgwHXW" ..
	"ijhdrGTnWM4xoNxq/auImVcAXRq8GbFB7hu8j2HcX1tqe+HSzSKlIRFwTq/I9EilZIcsBxatHhjpDvaSovIOwZx7NLwwnrUp60am" ..
	""
local PAYLOAD_P5 =
	"tpzvyzKH0HcWCUlhNnjyTUV1bwXEOxoghqEVlatpAz0xdSHYSpbfJErMUbmNOj42hfzdWMEAXf+Zs31S0pQSqZKe6iIKNS1LqQx0" ..
	"BSz4WciM4y+BD4H2JbqcPjgVduUYokbqEFU4Ow1ekrh0j3IRdfL9Jfx4MoUk8SjqUT6R85obZ4jVblWZcVW2hMW4/UKPViyf1Fay" ..
	"4uSqL/nRskujBR4nSYufLltfIC69J29ajCQpcXIbs4zZfkR+Bh1TQlTXeawd+PLtS1m2wBthwB7NyOlZw9Xjaji73pavMhtbDCry" ..
	"eR/Vg/gcofJTkL8gke14MHk8rofNQvyR/SAhsenlPIIishNhEc06WaYs4w1CwjSkzdBGDKg7H+1G7OhWj/mOhQWJIyWmi4uLsvS+" ..
	"s/xNYTmzMO9Jry40W+2eoYzo3pCxElgFzVeDBxqBHP4wYrV99iPSEOmBwAL1yMGQH73Ks9xEBlQwDZLvStP3n6ggr7gwyCEXL8cN" ..
	"BlMZOhqbGYOYBCuBOWE2EK/bSjxQ2Y+mE4gGy+0jyhtdRN3/5wgKJZXAAZsH1I6HAi7tI3YAiE3+SZMleHNgybDQthl95Lopq22+" ..
	"p6SYPXqE7BJMEtafq6RPz2KNspLVh2VrtfTSwMrtIZtRjNCHRIjt9XW6QnoGuYfea4R+UuNBkhhgAnAprQUJKgngZpMvd850cbqc" ..
	"05Vko5K8mqPMMxLQy2FpRq+nxHa+2KFy8pufvCrFwOMLhuETLsQwUcs/jQPMdP4/Sv65wkyGxryoqSru38qp9bhD0bV7Vov9xMi8" ..
	"Q4MIctN4PqxOH755EaELuRuCNAmqwvmLXrWPbGaKZoab5Vz8Eql3G529ZpZH4ufoWPiwYShUNlaNg2bJA2AC1+OMJW/NJog3CR1L" ..
	"EyynpgIWzDwyBm6fn90FFsvDLLEjblrSTu5Zy3Jt5dKRR/ud+APukLpKwsvbtHyKurZdckomI99lGV29CILhbY+2NZtk6U36pAEY" ..
	"MaYq7ETuxwYlnt68MA8SjqlgWoFhk25CB33vkFhnpeejZjDp6h2zSAaOINxk+5d60n274S7oRnOJLYMJVDN6bKcqLvRC0GXbLB2p" ..
	"rw7E5yTRVDq4Lyo1OZOnER0hIDOmrzXcZJVxNtE6hjJfe9RLZO8hA/Gn8ThYG5PdZsv2+dv679K7tUJS/EHs4RbQVVx/Uxjbhdm6" ..
	"d5lvS86qvAIMFBiStbJ/J078J0YZiGWMUmS1GKadvAmFUGhldkeOVYG5zZQCak1/7vM/srEc0wLmt9Gc/dpHsmiV0Mi0nVCtbgjy" ..
	"dpLjjCuW1d9H25f6U2dNlQI3n5MtniIy8U6nfzOgIB4HxRe7w/uaOzVxXf3TFrzkSZK5lfkrvu3N8GS3z8EfOO88YifB2HX3RrhJ" ..
	"mdWAY6ds/uV1yX3l5UqEAxd0EObPYbOh2g1qmUV7/owX73867/A9fSrjtXDuGPVsDmesJ+zcCskNAb7Bls9drIqCxRbs0lBXIrWu" ..
	"SvQzuh6A079EPe/EbFDms3XI5VDZv+h5gWJLDW7CLfbM1M85uJeIZrMbaZ7P9nbw60wHdHNZcdLFiCRTMbjhlOzLMMrgpfkIygJB" ..
	"Y8z82EaofVTcwmYi+Ndr396D+f9Mpz/hzoCGk1+T4pcKI5V7qykMg8quXHYXeRjaISzqGHSjgBlFtFE3ZrzdvWn3ZEqeQp4KIIh5" ..
	"VTUhs3cprw4cxZcbwAq5cjF8besdT8B5kUQt7UkixAd6n0aOaBI7ocolnZQ9y88qbIeybfsI3v3BGpXmhLb7cAgnU5Vxn9rmtmkk" ..
	"jsbCUywKCcXTH2B/9rvNA8pvQQOx+Nlwg1R7ENIDWq5ycXSfTUQWv00aVI2UQ+eXZwPDUqHL914W3cSyUEwXBcFUSjsFQOUSuktd" ..
	"sGmx38ldhQ3MHlX9c6fT0BOm0kukNtjOpe6T5EdC1wjXR6CWlEIJXCG3ALP1PxzQedkNr8LdfL/bAJrfeetxksgWsH3WDxNAmarQ" ..
	"gd/5bdewmFgbBzU7FHTiGiqufF3UdNLN8WwS9Tp8nMTSoc6BLQmwuegpGrOLhGxqFs3RhzluhT8/kj0tAnuUSIubANWUcZ1/CQ3d" ..
	"zY5zqsN1umXNUIp070ugbkjl3RPh3NGc8xn2NJBoJjjeMDnHpEKukO2yxsCawBDhmpKM+7IRUydUE92bvRi3iyigBmXINjBEqJj2" ..
	"uvviHCm0HUybCB/H5aIqOhDwgW6MMqgmsMPzj6HP/rl2Rntw4rpPzlyfqrbzITSewX0f6wdSyFxFvyDbklt1XVinhZuDDghLwD/K" ..
	"I202HgxaNBscRsGrkUt7ZoOoIOlau2e2i7bt3QB1PyPqe0lLqDr4MDt8F0ivkGIxdI/Nbh7m+Y3VdeeBI3ui0ZKZmkIvT4wprksI" ..
	"9p8zhEuDlzQwYdlrG24JYe7tOg717bNK455QHz7cIy+0PLUim9eqi2hc2f+s2hIYUV1+AFv7G6uetGVFmkJDdNCKJSeslw1N5t5C" ..
	"fzxUDqslTqtl43qEvfJLWz/+E7I828UPJMqOf4UYqugJXcDvA+E9w443Glmc4mows1f20jk3ZPwBgCEMwNHpctf/Vf7RNMKT7PHn" ..
	"rVF9lpthu3zAP5we+FnVPi8czVrJN2mz8C55yrOybEan9BU/8NllVd+pruI832MB2jqY4BY3mSaoMbUNSfKXA4ZT32qQxSr30ONe" ..
	"+pDZYo9CzdtLolC5ih33809SFiTyThbYzbGxaHBnObVL3OxqsubI40JmzYRtyYxElep4PijgJW3O/ZuPuZfX0DvUAxQzWYOBS4Xh" ..
	"QBCllZSCoy6rqYeHbqJdXB6rgjkUliF9p62ZaBXUUTOBuaNdtALQbUNqvzUpdT6Ff67oCW4BG3Z/1LwSFppqBr9yVR0ALl5HDBbj" ..
	"jzSnEf/ZqlDsM/RSD4QWty8erpk2gd6RqLRISJKCoR0SfWThYml3GjTOkFMKkUk3WnuQlJXkEwv73ovGmZs/Z4PWuieFpnOiiOrI" ..
	"NuC4R+6tpgzCOfarxe62joQoqjpCRxF5iZ71H/4DzPw9uTbiUj96MI5DxGEUtJPic/Q6XaQxD1WDXG3/PwJDGnVqmHWu60f1OYmR" ..
	"VYqR3XyLCfgEh+TdWlo9AhxvKH5e85ndKU9k5Y0fQXBBjsqoCWryugNY83ScpKIDfCPshGsWSENaKR4+v4v1S2bTKYENNH3nhFiR" ..
	"186h6nXnoi8/03nTmM+qRweH3a9WT43uPMmO1S43ujJI8ytwd6KaqwOi0WQ7P2y3XVOVw/IX5XiwLZW0z63fG/TkkerwOSMGosGA" ..
	"hOUh3I/wDd+gtePNqIvldjGMpQOg8AHkbN7lfdfPkb+AyP9yTWxXxfNu9GZaYucGo+XprQaHXWBhJnD6l9Eib8gr/SezDdmrOCWw" ..
	"G3D2rLfgf+RxkIiYpsETYkn3Ay/rXIypTyVhqBly/nkHRh6JrFU+tzKFR5e2IK/ZDGzjuy0+gG6gczdlpS2K2sWF/0W9tesm0hCi" ..
	"6yc0NpDcIrQJSrxUI3qMZOjny4K/q1SjZNLe/J7AZ2SshFSS+KlYlgQXu6ybh3BwT4kizUF3FbQMdno3eJRBLrtSBQeKRDp4kW+V" ..
	"OLvM14TiWjuRY9j3UKzQUvq/lwbG0THDcXXvnuIfx/G2UFQ/U1EGdGKM5xm7b0k688sVS3cMwTpwtRxdpD9fm8vJmgXGFG40agzf" ..
	"/GVA/iGV9aKN/y8jk9pzwLHbhuTx4od1gBLchPyQCjrU8ndYqT3IHEHjtBt+jZBMipKT0R41n5H1JrLRd7vtELNUYklKdVaBXHH1" ..
	"i2RZbTrdb74590wjmZa57Kj+Fgi+jqU7FL0bWqLhRrrCaMh1Cva/xEk/hfbNFLKDKA1uJSdEtbWNLKpC6GWZizkSaWw/rhCbxzLz" ..
	"hwwRGOY0bdgnM1kXoajtHAaCvTpFGlv4mMqGfymrSYwlNHytSvTgwHuGccOFc5D1U5dTHu4Yq9o9OoIL6ytTk1p+gcI8wFFDZbsx" ..
	"KIJ9/9vx9gPAPW7HTAsefpqCddt0tV29rFQapHSOwPhZM/WtquOSeoeGl+nMg+yDynpWcPyKzYQJDQfBFVN1oF1sOrwxJqf5gAcQ" ..
	"qDMmoOV/SlezoWu8BNey9Neg85K4xMME1gIMJQmQbdWE3INEr3Ec65PBsUEF1jlamXI//q10JCsYoOTeXKbeUydvEQCFC0wzFHls" ..
	"P7AYImDomo87L19sn//tJTVfvmxF+P6Pnu2ccfYRGh0yj7VppanmZVvRgaGu57uvV0t7pIiW/cth9/BKX7j66PaB/DIUgim+GjB4" ..
	"OQB+TsTNCyY0LLccG/tl+etCpk7q6LncHC/9kGPfs+Y0x7SI6Mc6F4PqC75l7LdP+Zo07VKXpmKGCpXjhAEyAoyAPFxd320PxKTW" ..
	"zLb3JkxIJ9/eedbZvr+WuSWfqUqVgR9Zjc0cN9Snr/+ymDM1RPkxGQo8sOoIEqS7hw2AI4mDtbPU3WezqdSX+iAUORb1LM0aoINj" ..
	"CBlUqoig5DuYofTefpl3KfsGCP6E/3O7qfFKIoqvjeP8P+8ssfxnnvWQeZkOVhIz5n29uobIozUB9FDfEwBLW4+5gtTy7knlUUKZ" ..
	"UKjgTS6ublMm7aSImJ8+JVRyEkXynHI3BlH4AdkdiCx1dLIllsfEnPBlHJrF1uQfNv3w9FIzHO2O8657KNqqvM6DaHNjYUK2YyvL" ..
	"Epx/lP0a20tM1OrCylWqFJ1I5sVsN5rXALfDyrOGhJz/KLcB+/sRfF1zhHlABfWtM+TIYBYBepUNhT6Es4jqt6+d8omOb2v7y6G2" ..
	"xqnvoRT4ub6Lclh7Ql1mEJUvNNolSCAuxKSBHyUZR5KKLBN6v6o6+95yhVW90GzRldXNQildT/uz+E1cZJEi1QOrIZrnEOaCkPxv" ..
	"J4n6xDM2PZsNMiGSeKHBeSgYB/TVJywAey8HZ9FTTk/TPAQlYm21/Hu1QSHjWXKdDAKLcUa/1AExWgq4QU1fsDWpafm53ZRqWik8" ..
	"+AgYgJBUrPZw+/2+94PvUc2LhC0v3hZJM7A2K208z9eiu0wtT7Em8dOO3HXz7ms1emLh5xwFTTLju+a36FoyeDq1GEckg9uMlx9k" ..
	"uKWIVEnh1dAS5Hb8rNpTifgZYGrqaziwufSAqtQmwk2Ljdjy4wsXAIdydvd6kNVjFrG/KihTlM1FMvqIVWZrcF47pvwnz5Kyd3jK" ..
	"533mzr/K4dYsJ4pta9XTLbnX632OYyjA0RFaB6VrfVe9HwzCJzJ8KmKLdizSG5B97+fkMVRbXD3MU6BogaXVZfBcfwcctO0AteLE" ..
	"ZV/jAQne7acecfLPglai+TBFs/cQUIJjSuv/+HuKHJ3yHzLD0pcMjTHGPhjc/L3rdQ7h+ETUXY90AhfnGirQU8SVllliC8RFvGum" ..
	"Nur1myfXZ/Kc8VYAPjlem5G4yXeqLAHPgmER0NoQ/Ikc+PDHtRufqrUTbbI1Jmhk4I5T/pbujcVTDyfkTPo9U6hdG8zJltO3dER2" ..
	"R+MKr0JhCDV0bHDKSfcBGkJRUGAcegmKrX5L+Njxv8MYRkITfktNcS/oI6oYO+Eyf36i8emsNxlf1KUYwEUdpB7Zen5uFULK/xP1" ..
	"Mkz742OaexOVgFk4NGEm6rIT4PVViZJM0EQ4FUSYhAzrTrjPCfS+XDyhR5TGghRBvCGhCnHSc7O3Oztd0ruIJLiWx/qxWfDR6e+0" ..
	"zMZrxJU5FgOToszvjZi4S+BXzw5+RnJ8ZQ4smF3aZnJxfJgJO0Qz6F0ldQ17uuVKMKjGDsXNA414Hi1D/CkdqL+xRdY8ZiuTLbNV" ..
	"38S+TREaXBO3pEHSAI5v8pJVP6cBBp54K7hoAJqTQXGRRBloukuKdEgO53EvvOOgox6I+xipb0rRKhI2N10T8o069+HEyF099+KO" ..
	"aVrmoO4rPw76xAxZpUxM3CVWhgikBV/eLt1ARxTXhHE4zFJMaY2q4Xtf3XHCblp/SM6Msq4bozsKR+yRqdcxy6C/Fvd/1v3wHeBJ" ..
	""
local PAYLOAD_P6 =
	"mROqnDLA90dBdM76PyWO6Tr5+nViHtyz1m8PaAdBhtc+Y9DGAaVEd7XA5oQVe1bX3ROruGs2b1BFTnj3qpz1ATTAliJuFWDRaIyf" ..
	"fo1pBtEojE+ScLI3NgNp1xW3JGB1xElFIOYFcG6wKYYENoxRZI/epaIady26EqsVf0qrt4KAcKXh7QsiriTTPJ0WxgkdwFJjOKWp" ..
	"loqCQPc3ammzVa1MNyapz8fI9sWuFRfqyzs0zbC6fG6eqWEXH83mlR5vIFg8ADRLn4U5UoeQ4tId7s6zCH/9V7lMZd6IzeCXbXOG" ..
	"57JGHbh9mpiagtHxITm5JI3momZF9IspkSHtCyIo7McQPVoFmrhA3+EPTOvPNlSmWdQ7NJKRk0H8JYSFAHmWc4hTNr7Z+lFiEyCj" ..
	"nsniHB0a2ZfVNxXd1n0nnXeBcAf0U+pNQgDuhMQoax7cMQI4CW6HsEQfjVqEcnUF8yd+/hzKHQYADmAXL6VGJVA0YpduuFN+eTtH" ..
	"eJVfDppqSur65LPunX9738cqZffC35gJ83TXod3Ix1Ja77IP38OxwIO/wrPD/i/LlVXAO3Etk8fPLGUb9f1g8GELAgFGMCQMqznp" ..
	"OSxrlVNFXqWan1ZmYHdFPfXevbzLGky+PeiA8KJ///5MYLGr8ZMsPKHu+eTnCT645b21pKk/sJri0v1usGf435w9Rqrpv3piucX7" ..
	"JF0TIiFCmq5EdqWRetumNzJHenMhinQQmemgltqCAl3Gz3GRBGJk3Nfumv9Z9ZZbj/B13Wk89LQYI69xGsIm+9V8X+zd482bvq7j" ..
	"Je92zR3l0GRC9OFRlOB1dyT7p0KCnLp2oQYfLONLzkZ73E5csCIjm6h/uH5WwJ4I1zzhlSIMsUCfa375/h+/Z+aY1yOCwlxU+3Ii" ..
	"Qbc0Fk2EJSlLwbizlgijkRwSrZmJfGtiGgAszYLtnGPrHBn7BnqLcWsxF3mgC2dPRgS+uKMui4PqqsqLCNnMKqo1uc6byJ7U9kOs" ..
	"1qNZfZX5vQ92ZqKDegsJF0XiTBWV+DtoeU6aPaoPzuKddT2gvm77DbJRgF+SbOp130ldzLh1RfEi/NeFtRyoL0Uuas1MxTRbn18v" ..
	"wsYXUZAou4lTcfWWTeOHrTwRFZw/ANAbZRiPQBOnee7MZ7BjzhLGJf1mFtUYe1+QzMcucQ2uLpvbbnbR6Vs3OHNsvheIesBhYuZs" ..
	"AtKN6vzecdYasu/eH24z7bK88xkzBe+0BfyORgBszEtZK8RI1f8y05+jagxpUhJUSIZh+VXBp5jDWBRvNROo1F8rXvCHip3VYIT/" ..
	"aLb/R2ofPiyCQ922hzPo5Xks/Wet0rygwyCocRvr5ctvRtVd8z9645FMtXCM/jzqllCR9ULr/iUe2IAi3wLQgzpjoo5DtUyYlM/8" ..
	"6rZECK1ieo6/Mc8wUS7+pFpq/RkJ+NVWhEmQ1lkE2xTGmRdBqdFuLlLPeytytaJ4S6iktpx5yVRS1l5tSSuvS7vwf8rljWNbNP8p" ..
	"HzOGBrrZIurBfMdDhTJ7I2bNiPAczdKxRMJomyDiC4I7oZHwNdaX8okCQwB0D1+x6vks/u7sSsTSm89frdkz14ZwO503WnyZRE97" ..
	"WIeDAkQ73tNtb+E00dyjQcF9dN8ioZEC9WQKhN9GyCPYXYgdXq/HatPKT55Uvebz157BQSzVjRrZJUWUXAeXhSqUO0xQe2J4cBEm" ..
	"dYXqZDJmY27YEp73Qvqp1B6DgVBgG88/3C5WxoEUiYOewX+JfqE2tcHRQpFRi52w5M9voSn4fX27JGNp4ekFfDyArVGvPI3MmO6p" ..
	"SXgkA0tYR0RUv3NI8luf3TVvuxAwSbZRcg9pZD1MWgNZYBQUHR1X3U4w/EkNHrqQYuSdmDTP1irffsu2mkIN+10W6GnnuA6OJ2OG" ..
	"Ojzt5AlwQWDUy7mDG2EOdgrfBtSawhibSBDNH24jrfqgmKor/7aXVx5Be96QtKVYyBS9aX6Y+x+e2jCyNbrHF8Nl+at7cOt1MPDY" ..
	"cAH1cgeRuTeHuVgAAiwixrF+cBGFd3amx5AvGyY2kr887ZQF+32NIA39+cxlPNlGNXs8z6/J6OrW+1vIX9xNF2T2FJWSPkdrjdoK" ..
	"en+CWNKc1J/u0/XHApHiDDcxaYHqSpjPJx7f1XjwbezNnLpRbRHp8oW1xyVDCCtqSwiQKGpOVOWclkdBJtRlmEtEoBDn1GzcFb+q" ..
	"ocwuXnHQldWP+ljy2XKb+8xuMpwtMRlCjqc9MCw8Dv4ESbk24xTwBDS1lW/QdADfPy/VlUDg4VD9lI3/QMAzEJoKMxhH2RJjKPwW" ..
	"wKxRyZeLxYVvX4q9AI4eCFlnAfAbwHu8WWEJOtVB5qDj/IIY7LdXSLDtFZUmabV1oMG8ZF9xbY17n1DhrCDdjEmJ7e6rRO6zMROT" ..
	"kq86vNW1bL7hIN+UVukGxl9TuHEcJzcj6rtzXFxbYUj5Z9pk933L3+7/Cx3pqRcoAV8WznYTqipoJ7Slek+f7QUa4aArieu4p94S" ..
	"xoNCl8h5tFTFbYjDNVvJDrVNsCsN3bVV1fsUXdsOs2XlJcNA2SH4aqmdwDJcsoqM5VzxlVscvSYmKhMby1N7ms08k6Ccq5Zt1WIR" ..
	"l0LSQsdY2IoTqc0kFgM4LTCdV5W8UaQjMOjQU9IhuZU2/SRq4NEu/9/DMmVuIvJyntbJgC4y0z1k05s02JIG+YQw7o/Oxka3EDSU" ..
	"z6//DCvnUyCWxfBxfmJdOLqxbGvcSRK2YQ2KN+Y89Mg/DHWZw89jxMQ954Eo73E1dnnWdCVcyV/O9ym34yjpuJjh6kqpRSJR8NFn" ..
	"OXBzeWI0WnNQSVGR1FoEGpmlrzXppUWVyuu3qBOXtYVj1HYbShJ877OQqWfRc77/G439wNEc82e9qz95IkVNMwLYIhpnB7msnI3M" ..
	"qY+7hUNgbaBg5ck1iF+6xV65/7L9daWi2bBz5PbnrzfAkVmhr7kNmXHNTLbFxG0f2HnY5l466Zp69HSamh5hiWlH0VUI3LYCENMg" ..
	"LbsZ3zxnTQHbQ0IaXGzS/BikCwpW/VQr/xUnANrWKF0XqatkAp6nUHox8NJ0/1jGT3AMq7ID2WFcPPCiKJnuVwZHyHTZ9H1hTqTU" ..
	"iuSjp/nKOaPc0H9p75L1gKOOYZAnnYiyOd/xlrHKF7LvlSQ0yE7R6PnF1Rs75AQuaZvzeJpnuf9zbu/ldOAUuK1M+CpyX6xmCIeR" ..
	"5zGJmi9yXfPtmqrdmbs8WnaK8UYnlUV4mBgMNEe4bSu35UlYtADJP0vVc+N3/9xDnWPswkhna5Up04OQeyh8/V3/slZeshAnSB+B" ..
	"YNtiw1mtNo7B8B3SVeku+U2UDyTdMY284ISHLtRHCmBJhjjU5QdY3s1AhjRWfaf7nO6XJ63ad+UDrMMbLUdRAwFWCxlNii6/KUe6" ..
	"OKF0mjvNQpWrOqyrUPy1/BUcW9DkO7Y1lZqgivdaXIBU65VTNJAXAcy7kgkDMQYEUwANv3Uq2UlEnMgKHVqfTxYSKlUj7yjQcpdA" ..
	"vkn8VqYKeHtQEoyM0oQz/7sAKiQcgy0EqedEZ6kyaGCGSxeqGIukDHyA+nmc14eGfzrpBxfiMBp4xO40TxEiftQjgsukSXpnzEQM" ..
	"8f/FNURNwhUXPxDgeocIjqp3XX2Jdqyg2lwjIf/vzI9C8ikOLtD+mm4DPUshYBrHGWKon6+FqHvKJ/duyyvB9kBBX6vQUn18wB+M" ..
	"2pOleij1MRFkQW/TJjstSJ+oGe54P/ZG/y0YL4hV3+iSez6s8JzVb5rVM0jxFG/Ny4I1JZdyzAfmgnzqnmRnBUEjq+oM1tQSXvTM" ..
	"WEQjJmQ79qaFWYzRXwq2fM2/Tv02Z+q7Rxg8QYqOuk0QiPewbcwzCcF6TvDwDYiYq/67CsuqySt8rG/7L4Usux/zb+0AaBWk5xXx" ..
	"VKhBTYQRydIW70KUBVwxEIiobanWcbsoG8wVBFmg8fu7ZDQ2V4iJblTaN1dN0WHBYeefW7TIK5hUozn3Zcb/VFY0awa+MosxwJZB" ..
	"6/LT2oTGfzEYrOw+0A5ul1yp1TykOUdg4BynqJF0OE1x142BbhVQfWG8Lw/6Gqmp0n6B1J+aBy1XoACy8H2Q7bCitVRJNH6KCGic" ..
	"CCZRlC45+MUHit56dhmRpLOp7B2CbzAsIFOpYsUi02hU0GGRrbZC3O95r8BY5xVdZt5fZcU0dEvYkqbhshwCHjF0gr0/H4ynLwp3" ..
	"yKY2LZqH1au8GlL77LrJ91ZJK+BA5F2BjguGog+JXN91p7UZLf9rSElC3WzbRm5pFsUETjXk+spEU0FLRsEfpwxl7NFLnKo4KFPP" ..
	"1guBwnv36NXm4lHyZQpYfA5dDofpIXrIhslrKLLsNbr1wlDIb9vnF6SNBoI9onLAgSU7+/0KOwAghfbpX10yqUL/8fGEBieSVkST" ..
	"+g1a6+WcpLRh7uq0JiWMtION93M7ea3IFhg/RSQtSCT1GN5j6aiBrBtKB/tUxj56vOBuy2alwqlKXrH7XwQ7uJKxBV1QIoe41v8k" ..
	"pR6vc7kwRqzC6nNDPEG4z42oItEW/h5H90LUNzjrkJCwiTYmIkBr//ZyelfBjM7eXExCEzFCwysHStfzyn/aP/VbT29pzSc7PLzc" ..
	"DcNNlM/pr6F8ljvHkCbbEvq1Lytt2ySPpNM7JsrCW+v+NJXyiTEAVmGTVdfmYwS1AptSe0NOqTN67B5PmXBjN3lyVr/Jx77gJc86" ..
	"R49wVY61g/xbqJANEm3iyWKIuseqlRoBdLxtv1jyflPmHft8neQkEJQD8gfe9TFgyfMvkzbR9lrnc+wMRPNpaTbcD4ngfgvCjgK3" ..
	"dR33BmN4JgP58O38lkTe8sRjc/fpeZmwDbGXxu4hJSSqaU/llhm4KFwNJFN7+FFJvnqrykY3moUvF1pkjkCQVxhGLkVt9g0Sj14E" ..
	"AVXNf/kOYwVxI1BruiQCkEMimO++yplzjl/r5HZ55rucfPgqU/3g6Idc4rx66AAEmCbLStSQg2TAv6JkcGjWjfeL1srEmW8tXWIr" ..
	"oP3oGwN/2eWCgjXXYxZHdFuykLuX3slqJKvDSvd9eIY8nUQs7Uf4GSFUJ/GujFGk5fgPFuKCu8jQ48tgJn5gn64oton2rsr26wMX" ..
	"96biKs94eeucWgyN6RIHdHSZLuwN54gD+HuAaXIWoKdtoNbtwJtF3mjNBbBsBHzeS9A+LQNA9NxSb9BEuQKbpYkoqIa0m69c+3z6" ..
	"kyAPDXGzOMc7aCVIkAv91ahZ1iPCzK2Qy6S+yTQz42QY1fP4HDS/ah/JuWHB4gyQ8aRXGCev99Ad2WgND2oE7blYNa4fhl3tf65n" ..
	"RC8MPAtkIGWhDBG6HUzX2+Gv0DnH8+trkq2vthJrwhlnL8t88ZSggZIsoxnXbahp/TzZ1/gACLdyvyMIhvqrvd8lVQ5BceYMU6E2" ..
	"6xXQ2ss4HPEOCsMXG8C2ZlOXESATiooXQqwrqrmrrap3JycmfL7uzcJD9A3DQSvS+x8GU+f5wHu1R4q+2YqnsHzumdkUwFgUFdUx" ..
	"BzeH2Vpc49Qr2oaa3pEzopFT2U2cMMlExGCjInDvjRjv8KO65KY3etDI1Q3PBgTZfRvsnnNlK/1BbaFDC4AOPeSdFa+iEXuLMXrr" ..
	"v2TzuGeP2QQZGStrifeqEl00NII43w1LaQr8ruQJwYL4RrP1v0zb1jwj84bpfipJvvUvDcxrOvJpQqHNIytQbjQedprTMzJwY9+v" ..
	"OKbexFSJ3qaRQ9rtVAdHd0f4c+A+BD/h+cG5KuUlJvSLel83x//drSg1VqfYaBj7JVIxwyHxGHfDm8HGDjLmxswB+MW/Y0IJ/59P" ..
	"Zs45FhApI4av9MYWKV2PbweAoMmMKRfpe6L4MrlY+SMPM7rekg4PbqxugQntHD0brjL+AoClOAT7ti93QUGlH9izpw1nkpwFI9SV" ..
	"PAJKNgUUUDbV+JmNzx+saK/psCzYThx/mFVWFqw9xqGWWpNvsHK4hS3uKuOO+ACr+mYy25yOcr8ATCkOLaElnb4AqYOPfDA5Yg8M" ..
	""
local PAYLOAD_P7 =
	"zIuih4OfM5CiBJ6RmdRT6B0xNOREWBHS5D/hV30LKRby3MZad2+KQo19l5AQ3QWLSccA+Ta9y3VN5T8KS3J9az09sugiU3lnHObZ" ..
	"o9EGAR4GyLWG8U5UFFnwOp9DmkZ8sm38Kk8xPGE+FJRGtWkIxkaS9pz2SqQEc0mxR2TX6GFFXs7kLAk9NVP8VKG7PSqJFns5F0mF" ..
	"1CIIjgWKmsfbMOiqBJjz2P/gjyjuTtQPgUb6xQl+CaLdvU57n6dVqGG7plZiEqurHCUWePD3+R75GpekMHTVQQbM1bj9CB0wX3o3" ..
	"0eyJ5wArHprPH4ngDHe3H1EP8nRDdcOT14uPgyA/AZiIsvjdefTgPbGQ0bIAMP/83jRkKrVetWMM0XOBx0c3Dmtwby7wVNLuEHyU" ..
	"etXc6ylBXwKo35Hm88xqvRpZmuFY0lXXK2in4i3cgcK0HFVuMlJtLew1aV+/L0i1f2/ATtRlF9IR4Zzj+iotYli6zUzZfZZsdEfX" ..
	"RYZA8lts/rtDB3u1AlrP90u4wx7XRjiyfdt6SSKuNdRszUvI4u6TR8csgDc9QcCMDvYnRFfRsFrXzm/O83vEs+ytKNN2s1A8oOaN" ..
	"X0/cIsTwgV3kLczSqG67ZtvEUmzbWJvsIpamx9mZqLlNQS+x3WjWAywdK6dlpa1Kk9sVCZCf3xxi+rTyXpKRb45oK7GGF07J3Uan" ..
	"RGa+rQQ4RUSibCnZV/jsFZB2qqBoBAvgb/pCrkdCiAC1GN/0aEbEFu0dKX6N7SZ+zG16tCOdg9W+ZujWGSf0KCPUuBUYjlljiFQ8" ..
	"g4ZE3RZYXtSI8/RIyFgmzY/z5As5HYwgPqsn+MjdSfA6o4fahOa7YguLApCWaYh+OdXeKEG3PDjZoRHj3UNpcJ4UPP8xwXn+SVnx" ..
	"r574GV7pSZUJ4Pzj40UhkPpOn8XTc+Y1kTYeabe3GW95u0J24AREidoZIlAtHGrWBtC5Yk/5glmyYjyWxwinpjdyT7i3BCw5hwje" ..
	"FN2xqgnFDuv1TrRqmKUR2Mvcv/OUapLJI3y+DsKkeaWcn2u6KEGGDcdyAKj8uE6wt6e/sV+9y/zjiEKDRby+o5nmJRpWT23jjPZF" ..
	"0+pL7cwQGgG0SVoPzbi54G6g1J/iCsUadXW8R6HDR2m6yRHL1eI2EgqU+4KL3wXLE2NXvKfMWdsbb1L+EpOqTQxXoncFljPp/gKo" ..
	"JI/EAIzioJypFRRoVPROS30U0QFwznTg83IHssa4bGGZYSaUBb6aOyq0QEVRltVrzCHwSEf5P0vUNqKG/o+QtcfTuvLzPsJFbMor" ..
	"znRVOHz8m2LuhbieY4spXgd/d9WZdc3AgtbaQhhNuNTHOkyRk6Q5jMTFIvlVZvixud4GGZIDORugP1DTQGo4vhEtz4EumltsazRr" ..
	"J17qrSzI1gRZcBBfzBQF2HlUCaQpbMY4xwhpR8Iw2Q/SloBTlSFBtj1Qeq5Ei0G3+LGUZGn5hB12bV6MxdZeTuPEa2+IE7SrocJy" ..
	"gHpBc18+ZbhMdjp9GsX4ecj6Kb4R+pnLYGv5gcTxYBG0FkQF0uQGpUVImF1M48BCDsVI+6SYWkiiARnYyALMmo8k+PSrt4OF2g+n" ..
	"r6XgDpPzwPuYZ3lTdcWnN74nxS5EYJZrqeCNM+GEottNwfyhxmczfGahLpUHRoYH0X68TuwnEbXwOAs3CqXAR8s9se8AcHtwxUK4" ..
	"UlCE4VJqPVS9QDxImF+uhdIEk+gwkWxjEfySYD6nxGn/ma4iWnqtJdWS6tJ8u+LEoggBeVRiM8jjk3aq2lcCPa03yJnt5lccDno2" ..
	"ZlWFLngpFhywrNyAsS3IzoYOm7dDNTplsdCDFQ19yYPe4r9ggWGsTgxrqCiQS8HGyhVsHbAMkS1AIqa2jZqqHfB0B42tBCS6OBJy" ..
	"USmPbBjsdp+EiIlFQfwiCB7QKqqm8ydtlzjF23HkRBfeqC/K4OvnMPLm1+RfuoD9T4sLaBYHVRGm/6lztK9xpEqu01noMNat3zNP" ..
	"jFjcdyHWfLMYM00lXh6qCSXEk7DTWmQe+iM4MKQcDgt9MBMiy8AIoJbQi922AcUlX/ezEObbfTovKYDvQ9fDLSf1h1FS++UCERsB" ..
	"CmZL+N4D9opXeQTWkcpflAqnQXlF0Q8jvVYDlSIsJi4MmeTyV0E1twnjPiJCCNQ6z7ucrXXeNbw/xufZYPyBhjBUSkDa6+cfsJvV" ..
	"Xe4lcCwVvfcYUlkEHNiEG6q25cqOBERSudOOpFdbpgRmBxREvH91vMahe+ZdAHHFaa2yyospysz2Oagn72yB1wJio7lb+ZP4QASf" ..
	"vEI6Z8g4AhBGgaTkn2v0UT8iLfzaPjs5/YcET1yspXLG+ZAG6hI0ULoFbX7u7zHuyuJ6KWT2HWCcvZpKr5eVP2U5vgW/8nXoVCpn" ..
	"GOsfl8V2rg9z52AXyljfbCAvxzUYEMEVbLH5yEDVi3MU6frFWHr6R2oscVigp5HGc3fPeLMI1JWL+Vl3XMWJOa+1I/JbDIQEmBRj" ..
	"jG2ls6HKWgAqwGixSEWDrrrbsQne8MH0k/ggGuAN9AUSDkOoskszAjDijjP7/qhJfXEUjsFAxXU+relxYKmEWnhn174+O1o7oEz1" ..
	"xzu48Deu8fNTOE8cKyyeSnKXv8hN6J3+pBKp72N/XQCdnxyic906SHr9haM70OjxYB7ngRbcw0ttPxeRCIUK3K3DbdYMrrh7Kryp" ..
	"SOmeSFC3+/t85DuJll8C2v+f5bDVQHvIU9DSdl+hYLTq0Lg/P6HHEdkPliexvM7VJmvw1N6yD0CSeJtneDyOWA/+175KH41R5uJD" ..
	"1lTmzfYmZKPj2X/iT9jrM5qLHbdNvCYSKmT6MA8gxWt2SYBcPRMtslOAkg+OIEKM7P2e3xDl1pGiFSvGkYtHZT5L6yCPEnfqWQOJ" ..
	"oKHvSwQHe/bD3u9o/C8X65zlAAx5WlYHqM/kVzd9hxgFziY1/PKR63eNm1slYeT4NLREVZVVzxXEQFEM9XTrVnNX88861m5wZPdz" ..
	"PJRuvMX3HLbKipNZuDaWzpUxKhZKv3Rm3/X8Jv+bdjdlO7OAvLg5pBcgdGwDY5DhBsI8tv9ZSi1fTnrAZ916lqV0c9glHWg6sgCz" ..
	"icnyEIoW6p53PuIdoIGqOvoqdtEIoMQwMMLGc6QdDLmCp5JDNfpCiVqm+/eCOSEKzTy/2LNpbxBv5/LbVmaIOv+401AETsSe2cYC" ..
	"CPgJcWXKPxnWw2jItwW18cIPqtMs/RWstzt+8U3iCCEFFRRL6UhpCo6amX/heavQQFF1yvlIGk0nQB0paTR8WeYsu/CpdpnUkNNJ" ..
	"CW/kQZuDSj+yC6u+ez0E+zjTG3FeCXoudb32NKYUMbJQGl+TpSOP47XVCyIWediXXEgyWs+WmLnvSo4+CZFY2SRmcDckI5ZWu4Jg" ..
	"8iW0Q4WI4wuCiuMCa5+VwXsncr7KvPeabhaI5aXQ51IG2hhDS7fBEJhZEsYLQuqhmdfNMLOxOulSvdTKgHIZ+bXh9WrTPD3VRT9y" ..
	"FPF7A6LWq1Gs4dVGKZHOVPO7Qlknlz2kT9arsbZTJE+L0xQQKXfIecRiQEtHNf5HiX76t/vOkGIU7LjwFxFIBOHr9yq/FEKoEfcq" ..
	"ZcsV/1N3KlvIPDGhrUR5ub7Vyn5miTNL1VPwwGYPOIHlXTyF98A+4C7W2yaZfLJCr6OjNODhcUmrvjfLVfv/jKJTt1znHzQzxcYk" ..
	"Mer7fel+xpbmOUfzaklzSFwEBBOhLUwa+93uRrw0gEqA/bW+cWxrAC2EwKjQpsnsZpVFon0kJK96PUC8GHQQFy1V8PcRAUg/NRXb" ..
	"TD4Jf/JFFFg8N9XgVfBXJOPxEu08Aw35TEQeALO065Jo7v502bm9nBB74VF49DOm+8mBS5mladdN4EVvJ1kL2gRQTZG2AgmfkpA3" ..
	"LsZzfy7mwQ8bySuHROuUQXkvQs/P7wHb4Xx4INxT/LslSLja5JPPVpGrkpH9Ma9GaZrktvt1Ziiq5WrIuLYdA+ZcQZx16ERX2Bz8" ..
	"woIYGBXXUgT7wQj4pF6d8T7fvrW5w7DYif89/sOfuRCJ23O6vdhCBtHcmhAj6W/h7koBzlZk1tcRKxVdSQB2lwldgAYrSEvT5eoa" ..
	"nNq1vHlAz+oYYJ8X5Ig4bGDw9Okpv7g9vv01ZLV3qB8RksOTLASJ8URTJhPGghB/a3YWsUfAuGOUhK2ViOrVQ+TEcvt+xa+BAXDs" ..
	"E0pC0Jx1pUquVIaTpnom5qk4A6VuuJrfl68EIplr9hhgfdhnUkLUPtDZmR+x7tTDkIEdLkJZtwLvgEXUaDUJu4kykLveYC8rFCwQ" ..
	"YD9fn3SbZ7+kBZHEoMhv0yqxLFDHgfFOMIkeKlXfu786MTZnsY/w3sDejpyVNoX1Sf4bf6ciyxOQaXhcT7YfIjqbgwNDP+zb2E39" ..
	"f/u8lvekkWTzYFglpdrsoNTk+r5xvHhHDSQ6CAHlDsXTAC7E66AVwAztfkNudNY/rylJNKuS419jnkQ4/Xb1hJn7VrUA+8x1UoeQ" ..
	"JNYSr8NF2PPhxzpGFTHMKRRj3xnXzG6/E1LD3YcyMsBo5VkrV2kL+Vcoxl0lG1xmQc1ZlYEuLkbxgpX/t/miLPHIiKRO6qgLH1cp" ..
	"BmHepIxd6/uRuXA/Q5hpbM7MiDmVPpIAmFPR/w3lQ0T2rTPsrS+EzTtOdJQe0ppWuwPse0v5UDtcV0dycc/fQu7H76N8Q1M0ec3A" ..
	"LASBJarSkm9QAu8tT7qGzwhbg5uM7dFor6KongoMPJehtMvYxVVR3JiLftPQG6wN2R1JgeyY7eEHUzaiVpTwLQDf4T4dStXqEVo2" ..
	"hAwDzOwTY2NVUUCGxm4nA4f27DVjFYz+zaE0wwrTHZE9lKS19pGhTiodUWbRUTno7csOAquW66luCMl62ejfjo8altZareyzQ2nE" ..
	"LrZIMaTLtZPHLhAd/cmF9V2dRFJBGS3XJUMG10HsUk4G5tCI1e7qjHNXMWpxJx5Am5i9S2Gi00nBOO5qWCe/HDgxhiKLOlc7w3bv" ..
	"sC6FmJPFJq/Vr9XezdlDBk+jz+LMPzX0fOPiiRh3x1Bn1dD+wp8+5Vp5yUIIN7rdodbt7R8AbeUF0TeC02EOUMX+jC4/rzTmadU2" ..
	"XXui3jrYk11ciZo/HeEi1EnF0PjX7b2idngzGdbftZySJn9owWDEl31NgMa/TnFbdCEDzNAWkYmucQaGDV4lZanzatgQRU+1n+T6" ..
	"caAPwJprkyiRtDP+yuizTWSwmbAS3F0b+6RENM6XRPvX4m+44aG9pFS6Y+roLrCvDoP0cFMop8j9caQkMbYvsLHrWACPpVgCP5PG" ..
	"avZcA3TLn3+pNJZegOi+E34bIPv8/eecCa/78QqzHdevZwrv1DQkcHRXKxGlK+ju7ilHjQZ29CTFNVRaslqqekZiqDUwFsIA6TzK" ..
	"YCWvxUQoBGe26lAXydy0haKkT9rzSLCpukfSuH/IegYG2mpPu+myXwL2vwTt3NuDv31+r1StjI2TBGQjCTQTuSfOu1INU1fnmiKt" ..
	"hEIHi9mho8zaihg+M8HACK6XLn1mKFKNMdVmsGlDnK7BWQMSPi5Utns926xMknUDJySQZp5pBSHHV8XChxoxMfoYeNpdGlF2w91M" ..
	"60tuXtWs/Ipb+Gw+Mv810kS1GyuEfVHQSiNEUkYBYQc5i8dn4bodDC/TCDjOwEdNIqDJPlc0k24hwp2yT4nZFtP53bKTYHbfA0Fz" ..
	"MUSeqNCdC8aa14PiBXmOZqqIeD9lyJpno5HtsRq/bOYxgbFZZZP3VESql1UpkNSYjhe51TW0iLdQCZlz7GmBybk/PuWzWJBR9dAs" ..
	"/AD7dQx7vuStsYaGGqFl9oQQzD6SDtb/b/ROaid3RpAmmNalS4CFhWoXBXv0gkt5AxMKIk66XVfSW6/F/MKziBPTbhrr3ValLmdT" ..
	"jF0RcxaIGnmaPPV0h7y5ESNa6NA/QsXLkFmo8QYj+zciz9NWtlM/9YxHNCGbwDFhoWPyPkCUu0QLUbdYmHWwSj2HwJW3+GXNEDcR" ..
	""
local PAYLOAD_P8 =
	"+lpN2Xen/HMdsQaJJ/4paWbU1Xk7B6LTKgPMZiZIWCEJKMJfUQ47I+k8Ww/N9DiFR/5V3CSzFaAXY2Ji7oOYMVntQjcxUArO7ZN5" ..
	"Ev3oTf8penqCXbhKgAgp0PCSmimiA9hwCyPKDyIxwsgImkzoXexhxQddAuc9OQ8dtd2u26nJgG50z8JdTodu5M1m2SC8y39HksL9" ..
	"Fh70p7fTr1JRrMrzCNvq9Zp93Zwu+hi7Fsv9tVtMkIK2MVrre+jQGuOplS62ZOqxRtRPtHR/v1WqdDIP0U2Eh0j5XwElrSi+xoTY" ..
	"3RTA4ku8hFy0LpjWBeYtTAn2F7nADXIzDSSS/tTXGvIZYeYNwm6ppV1UF+oqkdmgLlkpQPnWlNRQH1njMu6HjStWltjqXsg936ou" ..
	"p9RvL1AbD2vQPvUO7GL7GXxNcfGKdY+wOK23PeXnCXPrNnAmWHIvocybMQxG1bE+mGmcv8WBhhcY3WP71F7l8RdtSOxChWmsTqPF" ..
	"MVFFFw5O4iKNsX8WZ4ThXekUTdw1ppozNdRSHnnL6fB5FLe4gD70oM+QJRkIOtwkKNk5u7JmAQ0BZj+RwJW/cHyMk2cGpYjUbqLl" ..
	"sDVNSykoEaGzlXs8bdJuGwKVIRsQyXBTWXKqpsCyDXQoGLKVWtPeDg61oF9MCFUqxyNUBbTq0DrQRdpDnka53/3srjZ0qM01QZm7" ..
	"BeS4n8FgdziPgMn4ITDxr03ZG37z2Z4Tyyj94ox/zVaRuDQ7YoJY9WpT45obc8MXiq5KXQDFycjKdJL/G+EMeHmnQ4k9hLB/uJEy" ..
	"wIWSS4HjmWpWsE4XklgEULzrluPTLPJl5vHvWa+0ZcSe+cjC3KEQEHb169vAJ4lmbG8Py3rBifvhcovxGvJqtE8J7pj6dcW2YBWn" ..
	"4n6pO4FZLxP7VYJjug1GpKihleKhUqHi5BxPKBfw18sL4VeK/46jursNwLJ41gPMcP8wrZfHeM0FTKH8CWGHoBrZnroAc/7E8rzk" ..
	"GRblARzLjfsrVPjc8cNmyyTzpENXvJv0KI4fyXGT+tOkbRsLwaivR2A3M+8If35Hbt1qQY+DgGbJ819G5Sz8U6DGq9CFUrOTKpRm" ..
	"m2h6SnrtJ66TapMFAJNtX2R6wkbmNCmb66PznmWMWqX7AoIFdkxqEhIZeRF2vF84npJLIwfrwJQNfMjqXp2iT4CHDBRuzQMeQp5M" ..
	"5OCxnXe22FxjBiJh+aDFj0Dferi9LLUS8DYrGeHpb86FXVmF75ZC4Zbnigr70swPEKfcYcsIn7rNO1jd/cE4i65pB+Rk1LK50RW4" ..
	"jLWQovS5HyTHgVFBoaJRZ4oSRQcyak5W9+qu4Q381R8+vljKSaVo4mUJwGtbx/Q+ab6W9z3O74rJgdwqsNE8254Ad9USewqgraYA" ..
	"TNp6z+a/AWJzWMozWDK3mdo9hENesuGV+CbAOyTKfHwkjycRlAKj4esnBj2aBTk2Zx9C1bzqXPKXkpmxOPta+Wb1xIU9SYJ8AeUD" ..
	"tO+KANeIT8yctOaBfcDrkISyEf/gFAaXRZyC0qQ0hVprmWiq2SdMG4iyO35gu+TQjZP3mKTuDs/2xsZfdckoYC4kaBDJ53pmgZrj" ..
	"K2zlLr2UFBtFXIkrws7007BF95OWZenpIYI0UV68BtUBq0/wnOoOFsWGjF4BZLg1NrEWPqfXNx800ZW0gEJ3f2/qF9Ti3Ekw718+" ..
	"SHycaZqWdTs8YjZITRTCALLL0ydarcpjlbRVquL4Br1mObHQMdkHzv7iv9vrzlbr+ZcjXPSGpN/l/4nXqt5njfHplq/kEfJFgCJ9" ..
	"53JWjcspwI3eryVOekZa0f1kIL6DC4giBrHRjVDKngFcROlxJMhcB1x6Aaxu9J5pOMN9LvFl7MXjswi7AUapkoIwa7PCPNa1Dma/" ..
	"10U/SfsfycIuZIBg71DFZnsZIgHoIvkvqhTwuc/mprslTjQhQ/YUa10v51Jfr5eGb43lTHj1jbhzSz/Pgpaue9u4Y4gxe3fEs+Pq" ..
	"1L7P56UDQEhl3G2hXE7U92Aec4BowlUDhjRrlqPfUvUjK3V+dUYBBUk0OWVTf2U8rvgSK4tAO4XrzUI92uAscBBJZEGcK1kYnxWH" ..
	"v66cZ+u2tmhu4ty+NP15onm9UUSQVB3aCGa1JuqcHJomO98ySYaZyNYFRtiG2INo466bU37eCdlrXMicjnx2LMTJ/NHROr0pbFrI" ..
	"+Mwr0KbA/Rcbw+y/QAurrSfgiocFxzA14R4IluVQVvP2VMk4xgkss+6AyWivIMZz2NRSThLonpGeqLYX3trx5fiTzI7FIcxQbkuE" ..
	"L2XU9FDxl6rTc+5vJGMn8888Frf6twqHSy37ZZ1aemfi1sEvDclf8xxUYmpF4w3VJJ1mbpFN8tjejAO+c1YOGHDLndyQJlcriX3i" ..
	"s1+eviIX4MqiZcGzIIyBwSIW3KE9rXHLOZC3NBiJ7iXpOhkt9HEEqld5+kAFTyR4s1pVPLjDyVbo3DOWBm8FJWbt3QQ6NO6guUn6" ..
	"ktK9QaWxI4BwMQaKLsnhF3KdxZSedBMNWlIf8a0lRI/6HKCMNoOVIzlb/9K3PiSUaa+gOREqgFtdpN5Yt6hhY7NMMv5omrY3Rekw" ..
	"86qcIE0yf4AzL4rdyrkr3ZcrRrfJ9fNFXlNWujA00Ff77MpYnG77V2b34UsDLzD2EQ/0uyrRJzD9G78iz92DdbAK2lRHhtZ7nQ1l" ..
	"yHnOCMe3nr9cWx8MGdcoRNFRmSELhZHV4KmfWAJXzjRro9mzL0EvDnPyQbuSgWZk5l8muAgplWaAvziJUwOztRgskrmqzVx4zH3R" ..
	"DV/A5u+UqpJ0KXhxpQe1/8MYQJ1JTnbQdUvWh4vMcOEUEC3+34cI6FoTIJNPDfLYQ3b1l8A1PIrz8+xDBHLBWbk42zifCk4+5XOL" ..
	"XzG/R1nHwYBd2SeWxwPpbLNru0LxZVD0nEwc5HvJuIS3NhYHIl0OYpElTor6LbHqBy9FEcuPy2Hxc20mCFpTJkmPI2N47+zL5iSc" ..
	"at0sr3uOcZS+1KjLjFvjgK4zhZfVeLbHOqBMJMMKPxsoo/jZaGrWti3IrjqQmaN5UQnk8Cqsyf6h49RZpZ3lneR840Cr4f8y1k3L" ..
	"2JyPW9mMTX+QKBKBEBzKV9hxKcfR3zdjIgWRqfMXgPfY/rhAikMax6gZZ92+IM4/KanvQw6HI3eev23x2uu3+RrQQfOuUc7E5ltH" ..
	"ffIJjjdHphEwb4nxXnM0a96VH7ICeylE/oocRLlLjsXSTyPgeyj3MLfbAZvTnUQst6da6Wq7lG7cNOkcgVdBdAE19eaSrtra+Dpi" ..
	"DLPHrIF6wH4swD4vQbYB9efTISJf78Jv38inyWdXdE4BqPcrx8brfKD81KyBIEmPU7e5thKqCJmblu9XfzxqpnPPY/BzrUcfuul0" ..
	"IZqVuF72MU83SbOvwhPgTfed47jkhVpYzCRVbW1pU9TaCGH88E4XsDhwo5u/w8i2WLtbt/+rvWMdvqp+I0aIOqHCMCDF6kUqq99U" ..
	"6HYxOyICoVprq+s1nyXFurq+HotMits2+XseXtypP0wxG5gz+Cquq7i9M9vyDH83d0EblUYD+lhtxyKNpEVqZIGuqeVtMRKW1JIS" ..
	"K1W4lgjQqNCAmu2i9EIW74almU+PySrQOASIPU78Jfr01xaMk0mSQuVySsN1HERthl1fz33MeOARr6/PHaKwmjaRnj1TQskeruYT" ..
	"ZnW9hb0UAet2y6txOzQZflrM0grwwCqPgpLX3j16sYZmEE6ZqKYUL49H1fsm75XSnjwlpSp1buyMNRH+1Vry1YvF2Wz1rVdq8cth" ..
	"xnjhnVGfU9sdvWxCmPD6lliAhSf+PdKnbLVfvQq5PxexkYJDrZOC3QXnfFyRYPFYyTClhKmYgv38om73SkcCRDpLuGRvdlHJhbrq" ..
	"dCxGf/VWJW36xEXTdyiB+me/odKPNErC+lacbcMsObmHfipjuqmEiFraXYYHXUxVy0bHW1Bjj0rys2TdRXReT2xRmErYkmcehXUB" ..
	"AGLOxqkhkpHPz9QgCxeTUMZCPXAXxto5Phrdlgnz7otHo7UvFeIXK0mSFHK/H4Ki7V6uiac4FEIXGM6xwzffSNp4Lg1d6cdOPTWF" ..
	"I4pwOO7ibVYeJexIb4bq16CtJ83R71829z4GGrhPF1sa0bJaCJJl583Ek+Yo+MGqCNIrvVLeqeWW/2seoR+aPze7FHhFfdaWoB0Z" ..
	"oq4cTNtZ8zSjgbPa7ZexO71Vhm1fIucMvWSFkAm2yInKhTaJaZGkP2SLtRefwmcW8U0yrFRlkeQiQRqddu7nsnuLfPHESScJQOir" ..
	"lmG29qbuVVvguBdorz3IKYkgAjAZg1OjSUhy21BQdM9mSIje3+Npl0+kl/YX898lXUaQZZi/urTRh/JUQipIIMEcdjCfxDCM5PC9" ..
	"gQykS1QugRSOQnVlwTAbXVyWWcn4Vpq/n6Jq17NtYprLlPYB402PnsBHD2jJMZG4ccat+N6GCIfrlpwyizzxzpzE3sm0x4Ecrb5L" ..
	"M0zY+qdgGS7lKP88RAE8LUN7bPdYwA1TwwblxzQOqkYSvWnjmZQXNLo5gheHGh1QmA8c7BzRW3X78yFtveeFFx2damZ8PmbJfDYm" ..
	"XIJsxvxzcurSdupxDeQ0wyLArAvDhXFxTD1tqKEAErXywC3axvhfmQE1e+8YbVd+p31tp2r7ZdXy6O0CIL9Pf43V6iMo2PYkKXPs" ..
	"/YMGxAr+JtEKqpP6Cnwl08MRo528GKYKtXVad5+qnD8+u/ldkSnUy+Pi+8NuCJWUWv5IZ8TLLhEnXPsCznDpM4preQ6qae9rtaKf" ..
	"oCz0AtUvg8cF34UODQcBlcAWuzTjdZT7o/DDEgSpBjxDj6og2HaXSOiN9AU+994HIoGFAvP9k3piFdlTkNIiSdkHS000PCLilf+p" ..
	"GfJB06vkzojiHOABb0nmvS98k8RBOJWdoYkJtoZ0T2ypqSbCWALisfhZhUXMBxaAtZ07IfOLmMfptt4k7uxCfCm59+rIoyveoB2h" ..
	"8D3PhaFI1flwxkiZQ40MV4ZXkjIRez9SZGr+wgrYqVmaoGlXJtHHT2LCs4GvKDB01iKFaHcmQL46c/Pu1AeslJoAhizrNvfco+2Z" ..
	"5Gt+HR7QlM6hXGdLfLSs+O4ZiIH6EZWeY8a09HYtljD/paqHUULU8U/G0ZwEQnoZnmeptUqgVPejw8Sm5RnQ/INaZtY0hwZDoXn9" ..
	"LF0h5SvsWGQkCmJXyr1ATjmVWaRsJZZSuMIhqO9yO70ukX4Vbc8og1vyUCs9X8YKqRM6UufVHerlBaVvbpoROsV//NGtrG3xHql1" ..
	"nmr9zznuS8S5IvczcnUZEpP9E9VMg61zVqTK2pTYbwgxK7DfMCmSFcIJMgyCjtjKWCv3yM1G8bHRJozUS8WUvsVGaJZDyFadoiwU" ..
	"Unmxm0PPYcApsMGR0VumNiAZjLtSrWZEHDoINlQ1VRnnkxOHZkZATshHb3PV+DoFUC9VpHr7tLSb6tSN7DmD+skAj1P3YrdKiU+/" ..
	"FdGO61w54YuBSKJoF0kBNg1ZrJu7xFeoe2NnhWIAk6aDyD6o+ceJuuEJ/AfHAw8dJ5r0mkejZugYrXjGgp3gYAMnjVeWb2m4iSaI" ..
	"qnDWPaJ1J1uJNZM5o4aPOJ8Xh12KgJ4w3TKxBgWZ+P3tCXIHw6v4Bb7TFjx5pJgTOFsKV+Z8CXShYzMl1O7SG934JoyrQdPWKMU3" ..
	"32a0iqYTONrmBRPE12c+sjXs/IVU/zxPgz47MOM/UX9B0xpb0OhcW4cgh68uskqr4pWOOz11PAqFP25pf4xxXoTIUZKSkyT2gBE6" ..
	"QBvNJp3YtSXSjixSXlmXys3bl+CB8jCS0gPuZHHiIXn5SgvyBP0v7MdDAC94wwyv3RoMx1oD5sBhsc6y1tkcOg0h84JG2ZVe0j99" ..
	"GHX4lJfUNs0YOrSPYv1V0i5H/y67JkzoK2h1l8n6U6YRkdhb2TEp9lW9+pu31LsrJoHPBwQx/yx6VMWcB/5s0iW2MpHYA6K3EbEr" ..
	""
local PAYLOAD_P9 =
	"yqzO5UaFOq5Lfm0y7/V/n28VeE71ai2LGrmr0aulk6j7Hfx5vsS3Z3elOFfLtbdXeCKDDqbb7pf1aS12z/XZIrd/9lXJKTnChYZA" ..
	"539cqqlQP4LLSjzDNazEciDBrnguE9bIVEV5rPwJUsVLk7WUrz0Szdk2lGlRs8N3P1NGGjYXqN0DomAZ1WO0a8gfV8QKJijjQ6ge" ..
	"L2G4pJJIoPm6lTMPgm4aJzI4RbplA9FPQhENjL//gXbNQp9KJz3daw3YUDABM7+yvVZLHye53p+MUHnjSH+R87+UvYZTFnbe5kbU" ..
	"YhCnLR7WDXYvJFjiaQLdmdXLrNoQxRyEhernm2DCwc8bDyNnD2acFa14dZDsRBDfW4g5SUDekgGFov+9uBZijDW01YtHoUPW54al" ..
	"SxJupQneDVSD1t46B+W82DkGqN6pyOU7lozcxmj0xTfX25uQRWCs09U/8W8/UuamD4Zj0hU8AchGemPu4EDbAgmHrNvQwDjLXfXz" ..
	"3coZUlRoDT3nirr5UpDRQHizjMrWFd9w56TL4UUClXbFFGpMn3axbJYcJ5iTGNtdZuUUqVPTI93fjVEEwNKJIHZBHMt0CVc1PQm4" ..
	"DWifiLWPyKChuv6/Fj0mMuoubHgH1GuPqGTxtfGlH8qDcvmNfFwHdbCnYCSMONjh6ESshTqxYLIzNCHMDkhrgiLibcYTZa0IMauH" ..
	"XczmM/sP23CB+KftYvv1qpHC4TxtsRI4fZRxtnX5HOtZ/oURHNDhPDLihE76wIiYTUwEjR354IQt22WAt0tadxe6Qx/szrzkiLDa" ..
	"SC+yuprzNmf0z/M86kN2YG7wqbQAAKeaM0XimP+X0PcOEc8/WBghCiyrM3onSauAOdDbNlbTKtIPKbYTrtvKh+i9abuHc4y8AFBf" ..
	"xTplY7cm6VV4nOFdOMSOI+Q9Em3BrG316ZsgPA1teXKiLJRyD8/2F01gjqoT9PxeCYAGRm+75ETkTDCzyEAGOIm/9lvXmx0G5NFX" ..
	"TnP4yDX/zhwAF8hjFWdemYOt1QJK8vqPxpT7pGrL0S28C2bdzFV5vMBHp1SFGzgkQCuGdYpPtn/4pKgg+0aK1Lu7gn9l0rdevK9m" ..
	"rYmKHZuifXX9tx/p1mqOXQ/rjgG0EV1j5s/XPd1QsDhNvYsKYcuwTXECCcPfF+8A54SCaP8R+3Rsqi0t1qi1G8XZT7XcIkAYDH+z" ..
	"REWr8n7tYvl6rGxXs3lPNznjj6i7HZiuWuGdT7YZ4DrN63Qv3YTK3ENVRJV8H5JdEaaFTbM9a8fYWiyGnPigmXIICMRaeKFQNqkN" ..
	"hYYeuVyI4IEzk7tDfhd36Yqb9rFn+DC+lWZPFNYa16RTL46bC0q93PPDlBdK0dAqklzPHgZjCa6C/8mpCOaCVD0AWYhf7BjAtU2y" ..
	"aaieCG/bLRUhFx8yflYlu7wOMZxvJdwgRGRE4bXbhAlVkhmxabJeBV3sEocjAyOHbTc0OwQHhFNQ6xQLFVBg3EzvAvhsEAVLYTl1" ..
	"kTOZ47JZz7MR83JE4seOwKeoicmnJgc5HExmcoEUZlUjY2AV4j4lEYExeEJzsIFQg3DI6OMbiYuPB/JM/Fff11NVKWJH7Ii3e9tP" ..
	"C+qgTyx7Ao3Ebpq8njm1JClzi90DbYlSC++h1pzcmHK4ekP6qoWnE5zs1Vvqb0cIviYwasbc+OYgVuzzG1b303U1Tkw7XGBbX1q8" ..
	"gkNNIouCR4b8J0VMkXiG7Ia71pxt/b5NT7rfqNF0Ci2tiFrZanMbcF+f4NTMd7XH2TCQSv6r3rTYwyIwG+RJH+xqYNbY7+qihHiR" ..
	"i6FpE+VWaE8ytKzz3hprADZCKkO1zH81TZLYOzZM30gJHqhHOTHrQhw4Qkh9LxWHdM3kHJ07vxftaB6iBs+Du8NDIrLcyJSLagaO" ..
	"ZkPJwqhs7fdIKL5E536C23RpoN091pLE5OuPB9pyFidA65jh87kQgD1jtNWJp2jEgFD0KtXrzKK7zSX1MxiTqGaa5n6Ayh8AK0n8" ..
	"8fCHmu7b" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9

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
