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
	{ seed = 1135479510, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1138125504, exp = 0, plan = 0, hwid = {} }
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
	"XnFmE2IFfFkZGtuRnSHGlZsU/RpGvqYCGxA9+zwmS8igrm9uTba7JbFOiGBtM5UY3VrXzTbwoY6ZPIDwDhzS4XScKaeYoD4eTDaV" ..
	"+NIvtERYWPAtkDs+8D/QpEBclSDB1T/4t6XIpSjhd17oStUjxjO+WREuaenJyQ02Jq15TpksYn/23wxuiW6B73uGeNZXPTX+W0gY" ..
	"KiSXi55mdx0P3OC5CNy6Zz09qQ1k+sRnrrit+HxcpqX8XP/5tjegtuGjSCpMbBpnNlUgW+tut8SioajZxxGYKLKpz/AcyQBAv8Vm" ..
	"M05VCJ2ACiwGhpbrZbBWjG31fuWFwZOVezu+EOOpQwSOpuqfY8sp6Usa+NQNb79r1h2ZcX3GlrhOiAgkZbUGcBr7wiwMSL6Jky9J" ..
	"T0boLQMHYC032EUlw/Jn7aOmKZnpg+K8OVrdAa3FJsy5C6lpgdOOik6JvwJXb8rEQqqGY+gzWL095cTspA9tyqt40z3QhmhuukBd" ..
	"Ry9Q/GGy1txLyFByUXaa8ZHNLz0MK1of2e2Nc05A3jZWqfqymIjeOV72/VfK8NgPR/7eDfU65uhdWxGCJqsfbbCrGODOOvJgwsM3" ..
	"3NHmlE+YZn9765nBGoUvAGqjZwa/DzMYegYQaS46LBAYf1jW+j+uitI3/vWUZZL8G9mw21JN1LrV+ssWM/Jr5UKxQg3G51dq+azE" ..
	"hro2s7RrfNAL0qF8gn5bjNEJAT0O0148X2VEiLtrq0BIOZIOEXGqmO965i43xS6PuqF9112xJ1ebvYrL3nzCPSM2c4feU70xQyrm" ..
	"Jlx5FNi69FbApqbp7lCrysulnBdOPRRdANsETRzmNiYwvs6QrUp858onj9jJOqgHA+4LzJ6tnHwIvtLnu+XK0ZHtvmmwcif2oH35" ..
	"kp7rHWkK7zi9cAZ+Fz8HoRmbJ4eZPH0bVnTh27G0BATYUz2cJTMxZAjGAXxpaONAhDLOEJLtOLrd8bBszeRUQGdJepWSPCBNLLHi" ..
	"lU3EB6x4EFWagvTC97QHbrCkMjjnoxsmsRIJHUR4TGPAdoB+yvIoAVcVhzjcgem8K/EHpOSr5X0X5q9I0X4hG7MYerqPiEgLAZFQ" ..
	"YRIaATb5JymV2Y8oGzSC5gEzY6JBVJ+hujRH28Xt/lBzoD9fKHgsYegBvpIXAshG0lT+Ct+X2lUSUzkCSIyL7D/a1SGrExA2dXug" ..
	"7hTtqStJLKGsO5y6rEauJR3mIrtkcTRyEmQPBAt9OJsiWBpLPLRgWvr11XWFdAa7dmUSj+NHnHchufLTTi4ufHYR1+upbPdotv09" ..
	"7ApjGtwmwc1fTZkVyAN0oR2omsfdNexGvrenV3gYST6TcvZ682u9kB4PVR+tD6zMvZGECuHvn24a1bzrElLNDW/DPddYF98/Rtv0" ..
	"pxxxKcAiIKRNoVkzKvNfJDPnSRHqzPCouAEzoeC9KQ5lks5WxmCe1K0WrIRf7dONSsrxKkit0DmIEAircDkdeibTetQB7B8LVWF3" ..
	"gZ/O4b4V6PAYkATMLbXJnSANA4ulHPMZBOpyc/GCvLRQ0Xeab2C8mFKSmsc+fS3cWBGpqmrIzedu0PtHKcnb34udwrRsL38ONV1b" ..
	"bXsPoseVMRob3zeJmqnEQBLi6pgQGzaEtmK8ieC6TMkzggl26U6l3EUzayVz7JNHZjR/u34qAIpVuY6nKOVgVl3bRlXqBRD3rg3D" ..
	"EvFho8aATqUpJLz8hXAOuxUI54UfD2LO/hw2saEhei3NJcnTLuyDC/Ahlv84pamn3ivfPqLe/diLDZVkrKdO19ncCKCdL9La0b5y" ..
	"vrE2/SlkvDhuRf9oQvw/d9MpvTMvIf4lKt/YuWboGbuwni3Ata1UWMltGbj1I+aLNxi83fN1DAOEZx1iTb2d3jXCNsomRCmZ5Zmc" ..
	"rEF0bFpkAbQRdilNgJe3eqRqVp7jOUPioqZLcy1GXi0tGWYD8COOnuF0bk7kb+o4i+AjT3hG6GVvm7M6/bmycKuOL9vmFgN2LDrN" ..
	"gTP9fB+PpAJU43fJUfcvz75D9vJvxeye+OnnQkXMszSJVbgtJjO3kcdyIjQ2ASGOuf/+QmWauqUfP1MhTQ9wbWNEkKxFHUU1UPze" ..
	"h0RWt08mVyH19H96SItlIJ53oJr3BJYGMtj8qFGjlOnkjbDzhedCKigtp758sc78Oo/eaGDncJulp8mpV5Y5S1XBkH0psbIN1MXN" ..
	"mW8g3mgTeQFd6xqtSFdvjJi2YSZ6XmCEzycABWwMUphTPA+teImFG0smvaOX9YqxOSUKceL2Ri5ZRmWiYi+Tk4ly4FmWGEm/MdME" ..
	"2X1czCdZYmqcV3bYiFizREjqRCDaetbRma1yATrE6RNwPm2dF4f2rfh8fjCyErRHxbn7hpPgVlnr/QS/VjbTO800A6aiRa8KynoB" ..
	"xz1/I1iLkrbcB5WuTVjoU7vKb1fwP8vhhFkVCQ86lgSv6qHdBIwoXabqJJaDxd8iu2mmRWhazayWBXB4ZmqRJS1yXJG/eoZyD/+B" ..
	"EqvlwG+lL+kC0js45/1t7vs8SG/Pvl/5qiG0q/R0bqwgDOPXPMoFQSvWlH6jkznRjlo7+h/9qr6wrxn+3iarjRcNOIhrW5kS44yZ" ..
	"eL67IcxeDyKJSn1JeqpxVAZPZokjAfEZAyZ4Vn6GBTeEo1CKWyZPYqW7LUWD831go33ZsRCqnYswkgCsWbLHrJEkMLfZU4sGVBmD" ..
	"rAySkQ20T0sSp73+Pfg5jg+HVC6oqdzG0khbqd1Dj69PjNUoR2A/HtPqES+wNw4Uq0mJeXDDtRTqBYSmqJtreOeF+2Qrs5bxSIHT" ..
	"LwAGvCqttiY03B4JCiBbRAaUoY6sSu1ducOSd79jKNnABiCGr4PQ67aZmiuW28+mm2XtXBN9XoYGakNG2huCxZ5Zf/O5hINC+UZb" ..
	"/J7ZCV8NzAdEYZp1POsSShnXZvkgqhztS3kHhA+UcZcB0zePLBSdH8YSiLJuPeBDKTFnfLr9sWZlbv6RcKBTWefvDVKv1agRJwHR" ..
	"PBj6nRF8g5H2svWi1hwgxeINixKnud1pNFENvxPqkpKMp97sv6vV90QKj8CNdlQ+abXTBj4EGvN4j5VyNnt+QDo8AKKlipq0Uc5b" ..
	"UMRxPksHxHvVMOpT2hv3W+0oRMaY++c0apYRS0N5fZ3jrzQqxefXV2te90LovcN3iKH9SLtPp7GAPRGzKUFUclNr8PKaWxjP1Wd3" ..
	"B8wtvXTXnwRn34tfkfb4Huk3jOCYBH6NtMia+k/LiYZbIRCB7yMAFQ4OtzT8ql2meOCokG2tjQWbnKY5KHwyn6ZQSIS86QAnKXah" ..
	"2mvbyGQIrg5Z/1IJckcSTXUvC+sKhKWurmexT6RcuWsz/4lsLBvnOR0IZYOVFjZYPYouhrqydnqlwOPTClCl9oFmiQfC1Ccqucxe" ..
	"uBlHInOUTNZ/MDSiUeZN6W49MdSCNd+xA/0h5i6C7op13LJRZpKmgf2fEA78eUumkcyVRBpefdgjJTxeq7SKRaj3wqJMfiO54oIy" ..
	"43aou4L+pGE+1GJmYwp6uJByV0NylwkrUlDyjp/xNTUZsD56kTr7wacomMp3tZto60qFyypD1vKk8ngqMp0bUk7PA460McvNTSb9" ..
	"hyY4ZsyocOnS814Dw+YFqrRHal3eEjc3w3cm38Yvkq2/fS3dMZWA3IMb5LIpZE7NqqzNsfuHm0vuIvGYqQDSk8pAi/mEH8VLuv/H" ..
	"Ee3ZDjQa1EQ9g5DzB+TJv/i+/C/FKd1XVDuAfrD38BVUsZHWCd0MoJ8AspBdHYmrJdQKs3WD5MFttQAnDmKf+a+3X49HqjBhJefh" ..
	"OYcAZzeAWVQOz9CvRqV2Y/fl/fxUWCRQ2XhCkglkQ7Mg5CkCvT5/MjNsfLN6qT+xCJCt1AMZ24V4m9LHRmBVil+WvjPeGOOpBJZC" ..
	"ivW9TXdtqkym86Zc2M3h1R1ZPAnuOLKb5fzsORYmAVga1YI6N4AlhQaL4tW1KtMW4wRQ9kulWCWxudVkSTxAMGgGk1mP64FP2bSm" ..
	"4dYxMy+7yAWtQwsV7yoM+v1XqNGyRe/lN2jCwLtBUbw+xjD4TRCj7gxXgnxdVE7/wokHoorVj/xYobDD8OLeuwjekQ9YL1hbabah" ..
	"IaxmnEjqq3L2+K+yyNNWDpxv4IsDCb8fEBQTa5lRUK50GZvjqH1JQbu87pWeD3OAUya5vSS6CpNENGzhlbm9f9K+AQgc68a8whMi" ..
	"3ipO3y7CYdjBlVar/5teAQiyJMDFYJDFqaRCXdCIsl/gCcAZbCemfZ0aOGNP1BmQCIebdsnvlbpqKF1C7eubpJDm0Uij2NIIXFxx" ..
	"s+B1TCLSZz9yhhk6gJ4L8T/z0BdLgcHTJ6NHDGksnn17uTDLdzacdGDqf8PFfaz40ytv5b+8j+1wRAcTLOnVZJKnurpWNkLCXesN" ..
	"sH1TcVRLbXQTcthJr/rFYHB4o2tk5vxd/iEJZ3qSLZtLfEDgY9fGI5q8KCjA1xZSISHM7FqjxHicY7S9bd4JSalvevdn+XZY+i9O" ..
	"n5a6v5H3Ayqb7TMDRHLC/hlwvrT6nASHvq6H60/UKgQFFj7NiAZRy/kO8HqEGPVY5ENM80rYEYZUDO0rtuTwEv+onWPqaUirMvxu" ..
	"oLM/k9bzigVGn4bIFSDT9v/E9ccR8uS4WRhb+WM38UKFOJuT8U/9BOUexAKrDZiEM9AThEcLfTku0CV4vR0XCBrTE+9K3j4P/3lQ" ..
	"q2HSfPNuxu4W5lwhz4Ji1bwj0WQdRByITjBUaWFjiaOISaMdFYwywJG25ZvMlFsaibsKF5KQvHDhaAaPwAEmr4FZO5SE2P8jkkd5" ..
	"abhiusFR4rXC011wh7NbHbbDlUdMIiOxpdIWsPWOxIpxbg7ZcY5dn4BzfCVE5NBef6tMpuCg/nBEeFHj8H/gSviMDIpupKx3TqkN" ..
	"7rtqV86xkB+rkUehdGJ8cSZihQnJkWQacWGjAirCkyMYKl8MkV1+QJuVYqOdpwVJVxp7YvXdI/CvZEMhWbd7zqEr2hv5KPKm/naO" ..
	"z9wgDDqnD7/aJUR2CVTSY0MxPDzya9DyHKq13KVa/r2xAwSNh7LoBSqBloSjI7JJgWBl33vIJCJkdZzfRhiS5AdCYi1kqfV7vAMP" ..
	"bFVQEStKdtVSNY2ajSV1eP7iHF8HztUBLWbgaxuPE2EvktE35NPUmwgXmSvBpMSobnfRHUTc7fBHWaykLh8xYcXlTKjs/fQ2xugl" ..
	"I67X8lal8h3Mbby7tvF3O22LNi6hqMbKV51R4icqUOJcvG7wCFKSzT4fMMm41JHa9Km+bHDaS1Y0/yGkIdeYUWoxBcYT/QhLxYCq" ..
	"4D7N/KfgtQHH99egXthLv7JM8AZwqdp3kyl4Gaqse0dIcE8uyXIdT1o+1dqwyiK3mOa+Iv7+mimsEGom+bWdwfm/M9+pPdRXLHby" ..
	"e0Kr+I1IoKF9La9//StjqHLjlF2ZD7WhMXXZEZ3VmFaSQZ+B4yVOhhJEe4D55F8y487T8/bJTKCUyvRZwpTlWXngqXBjKQvwZ13o" ..
	"Dlfup+p3AUxSIW2J2US0s6GHukiSN1X+IrMkBJz2/xiN6Bc5N3u45nekZ3JBdtPaKnOM/PI1lc6Uhn84TU1gL0vjDfax/i6aWxIn" ..
	"vX6VSCg9q4VUJ2D+PjY9rG9lpjlId2PXPN4+L9bae0u/66IRczb1iRyUl8trdyv7nBPtILh+/+x1xSb+YwMN8TNiHYjUsFS3Gb3x" ..
	"MfH8a/e+8nUArl3O0PtUp0QG/ME4I2nJRgxQEVXok6OSBW0i1gRi7mUBSdMJ1DX39VBDqm+aEBAUQQ9HYhrmM3XtOMV6dQhYSzjl" ..
	"V9Q2JdoEu1Rr/23gHhEX6k3nXVpa6/LXmW2XAbFCh0rceds1ttAYkpD00jsduxO5jZinF3TeciEt/T4eJEVXBB1nxyNNFPnylM6J" ..
	"DAxMwa393svexhdLS2hAdp0YKCb4EoVNCsXGH/UTa9S5bGV787Qgb86Xai20CnsnLp6a7eq+is9wF6n48PqzwOfU71pOUyqHaBZz" ..
	""
local PAYLOAD_P2 =
	"ciXdIDKIZNqYm1AmoQ0gpZ2oSQJFbT/gtiEsuwTXauddCYimr3lJK2CRmQIban05TCZreN8+YTpv+oS2sUhcoYbpswjEExFFh3lY" ..
	"oib6gmLGMvnPkSnO6EA7Ihvp+/LvPjaQdwjCnS809W8ro/BOKaktSlztxmt20oe7MHJMfW9z/pZVoBXZbOfiNhfUKP9R7nOIlTNJ" ..
	"iRPFdNHlAPukeeH4fA/0rxh5Fvxpa1GHWyLDpBzt6Xj8aSRBc5zdsg49L0RvJ73n2qrqGKUG4IX0hOmX7Vb/hKmo2LLZP0Zj7mqb" ..
	"2mnmcV8Tdmlc+VXFYER0FE866PIU2KSU+OiEKX/SKtkTY476+ucU8Bz8/7GJLNbaKzE+ppikfpXu3YqIE4+HTL20AH+KKUXQFqxs" ..
	"T6Z4ezJwSVin/W7IvDX8cIp9UswRP7BS6Yzb5AU5AX2LPIxtDdzXN2R1okh97cO/vKLmz0CA+hMhy74NEktT7UHEW1XVAvUPi6KS" ..
	"Crv7sz9b+jYUTXA673LgZo0OGyz8cyD8OabCl6w9gVCgkn41fOG4jAj+Zuv+jXPLSkTuEg9tr1qyIOPY6AIaHr068gFOSeVuwAmm" ..
	"V8Nbz0a54Wlob3NwcMwwkr1J0LNOHwh7LR9NBGA2rlubioSe/AFpx/CSldDCtghbiafVvu2HYdX0H4yUMQqX57IEvaVQGITjpY7R" ..
	"/U2EVg62Usq5VaQi2xv36LeD1BIyE1PX8+iyQ0auw7qq2P+/ungzFRf3npxP47h43HDc0Styx+9sLi1rv6cA+lp63cK0LXT0gV8s" ..
	"4260rgaFglzNOZ/da4K5rVTqZkLrJYYQzrDHXZTd2BUNbBGJ43cWBylocG/bWpU3/DHO/HeTom3bsGEKowxPaROEVHHKtDtlRK2i" ..
	"JVQx+h1BSsIzFgQpnQ3cH/UhIH3h4LP+4+Ugy2gbBHHL88rAkDbMrq79A6uIu/GPpD195oEDwD4gB6sGw1/KA6JxnawtDtH8NgNx" ..
	"8iUCb6y4SY9WHr/ZfQiwP17/VENafrz9cul5fi2Pv/sFRLT2EiHSQtGT7uEeLo/L6X/59aJNeHDXz1aQ3aYbzH0b6SWcFya2O0i+" ..
	"v24M460ftegZDWQawszGIyohH3aKy7LZEmLvEHhxSHV2JzsyC6kXhNc8z44Hl6WY+rOFiOu729cgqBIio8ec5bh0EJO/pZiihW4K" ..
	"pkAbBecE8wvletVuHmSgZKFHRw3FQkSA0mtsoC0SYy1MrGf/Zj7F/wTYXagIcOOO/8VtvvTismlMxN96xcf91l8Y7Bk+ihXIqDCS" ..
	"8KALaJKuyyXvj/18Kckz2DdhKZLTyORAwGtjTc+eVBn/suO+8ZeMhVCJvWVh3sOoXQgjYTakixqhtAnV5+835G97/9DcqwlkbD7u" ..
	"fjwvR9mF7bq9fZQ2jVNmENm6Tx8GhlMwuDP6eRUWjv+2ZU19W4KajInI654e6VBuTTPVT3Tp4OBmcG6hC8INmuLagpBOaAjUv41Q" ..
	"Xcn0wXHrjGpTTzbMWPPZy///CbFGJh3IVlHg+/sSNz7rfXb0+Cj9pA2+U56yod8Jlf8HsIkN0FMNpC7WWp6mMJC2RXO9caUbRAk2" ..
	"2h2Bx5p5U6CRw1vqcvwb3h9CXGjP6Bs4FCXv4BS+eMqbf68H+PeEjwuBx0BBko9aNusx6SOFZhGbG/MsaCbPeN8JCBIklBeGhV1d" ..
	"IQU1PSJ3QQgpPl2rv+disB+SM3wJjmHQstq1gP+IXDS4NyOruv59wqu1y6kYNuPHZOvDMYccVj3GMRnXPRTLM6DPB0k4jJLI5uCY" ..
	"j+hBRDjaYLpr1hztn/WfgvbxM7HWwN98pCsGLiPhWkM8UJaqv/GXUkJAPVScQ/OlFwT6shtntzeH0AoRVrTGK89a58R5H8+yEabZ" ..
	"RK7ykczFZW6KbghjShvok4BBnNgBMJ2Qk2obTWusVpUcRROTPiDzouTo6QyagOIgKCD3L1NAYvKZ/V+rvhZ95ROPcWpZaWQ3U3lM" ..
	"99ibqT/uHm6gGI6N4Plzb0aIA3+/mN5qzilfck0Wj7JoptP4kKBXaq90YfOhGp2SZFGo2pfKPgGKTSOluSBYhQAKKxHbdg4cB5Dg" ..
	"EtYwUTNaTnyESIvp5SziVaAZyfwTt1l8koMg3mXaxxpTRPkmeLfn1rK8cV42Z6aU+chb2bidUp630mvEH3x5y0JlLDmrhS9gQIB9" ..
	"Ya7OASKo12N71Rp+NQRYtlUc3IBTklaMUl/O/+vBM4M04nhUOHFzbPl0pinmxLVHPLiMC6tMWb51D/N6oqAP6kc4WL1mcxWyna0f" ..
	"X5CK+2xUvL7A1jTr3gcuqi5EFnh5DYRlfoEBL3BfIYHlKnR4DotOs4B4E3ach2R8GLbseZJu53OYTFhujuCvmF0zC3AOdpn5kNCT" ..
	"b6/vE+ugrwY8SlTWOB1t3mdydvPbKJ82ErMIHqk5QWYS0f0AHF9Qu/k7/0Gv7AmnOIJVxBe6tID03i7FbLkvMWDPqVsf4tKU1qEM" ..
	"keUzPxL0k2FJiCwZI9VzG571YB6AHQUz5scYhoZsN5WBlosn/C+oXF4maQEFsBn5Rg0iH6+RhmISFr6JT0v5m5j0K4gp1Uy6+2O8" ..
	"5Kzfo1U1lgwVUI2sIdJPCmZOs9sOPtf/cuPgleOwiUYdoe4kiXrVOZSOylhdCZeSeoPBE2CXYgn2+9/SPgiRWd6fH+pnb9qWb4q5" ..
	"4cBtUuQr6Gllo1QwddGopkljVI5gddKEHfnc5h+xuz8jRse1OHx4obP3k3FPFLDSmBLGguuvi7E5Ny1rzWoOaqGedO502Tn+o+k/" ..
	"rxbK05HTG1Q2E9rcTcvpWhKOuhn61zexxrFtL0FGn2UzYknDItLrNEhogU3//vroDsz9th2IwUiYubHljx25V09IXgaeod3lELQH" ..
	"CKd5Js4+c573hFWcuDyaA/bvKcEfT29RUVBBy5Cn5cxU/RH0C4IJbiz2tS7LBGF6Yc3AVtyK6NRiE8W0bU5ch86WZvPW7oQ2Zgw3" ..
	"h2rwVVhBoIrIIRhWZBT/rOKLGtRmj77HweaAE7qsiLnUAm79ZqnfbouxEAMEc5nI+A+wG/J4WodORZZJzusrl+5bf58I8uqGN9F2" ..
	"c+qdVmgt+BMSNA6BzMhCBJBJ4QsRNx2ypEx6nLip1NEG/kInNvGI+FLDvqrUZKoKgDaz6BCDHImadSuGdAfbp20kk06psqiyUtnk" ..
	"XcP3xlxy1OxcmXylSe+sKvEGBWC/F5QZ686nmmikUDejAOuzFkxfQHzm38Cf//mNkd6R96Xcm/OwI/lpcZr3J0aVwUwEJ6NiTDND" ..
	"NN0AAaLy/j1JjIr8e9MI2U12WvHx5SR8e9VjqcTTPnl8D0fIG8R2r3uyZMLTGz8cp18Lq1G49JQXdXR8OtRxoZ25JiUc+atz/t1p" ..
	"JSPGlFmRmjaoyGj31L3b+qiOP8l41cretkHWqQLNTAe6TY1x+5G0JuZOLyWkLP+KlCzsvaaQSebkHgQg/Ita+jBXpgkiEYIzskQO" ..
	"C+dyq+P8fYyCnpb88qK/BmmGkpD7rr1NuOPaCnKpqkOAA/zwj6Io8vojSwWhAVRD/9P0w0x2gIo01ou7KXIYEhnR5XFkFPQR8i8a" ..
	"ERVy0stUWqiIQNOC/zUOvllXROoCHc3b+AQBcQk1QgUB8JvkY9Mcipsm4m9/1qmt2qgbj2mmjOKQMKQHlkksHHA0SXH2KlYnn7SJ" ..
	"6DkCxwuGLgw939Hdw0YT0qXwuhYqapC9orph4W02M4aftbZJZ2cygshNYoxfAp/LNd8f//rl8AjiEFwBoAB81C3jBSlK7M1dkoT1" ..
	"3GqKtE5Yg22RFfaF+BZUvdaJS/cY7d3UqWflhF95KsIIX8q6SS5REQu9Tyzhmyrr6lv2WC8fs65KLjAUeJv8BfRsVjEpacb26WuF" ..
	"gPoG9H3E0i4mvDqOaV4UjxHz8lM+zofXdUZrwYe+/mj1ZP16b0zI07TcWty2PNp53bHMlsm/09zNSgdVwEU2ZhDOsAm9UfFPepJA" ..
	"OXNwiGR/UORiUQJb40lRNynKgAwZL24FmstbKrAItwt8P6ix2y3Xe6BAQzG4x4b1nP/DSC+Ux9rzG2g2kyLZs0v5Ddg+uG8bMLaY" ..
	"qd+1hgbkPjR4FjC+3Jg91PECGrmlHQApXUCrEASwTWjbI+qIHJJ0fJd/sZAxsxP/WI/+0Lxo9EXKZ9I0l2iu6u9ZQTLtjHkfYMPL" ..
	"qYeZufQOBT6dgrVuEhPHRoVLy/ez/JKAeC+GMr6wDq6WH9XoKy6goSWfTczUEY95uOPzJi+HFJDrlTAEcAlheXmvUwtvObNw/PCJ" ..
	"vinq/Bm7COjL6I1pfU4Doo4ufeJwcftAbDYTY9pWzokiJe2x+JyRf7oEPtY6bkCpNFJj24jWyHj8RnggqH8GuIm2voyfW6MzttJO" ..
	"9WjIrx1ZPTL+YnCLtw1d7aqQBZqP2rkaS4QTX4v+SfRkaqlyZuXDqn/gQJMPpPcHNwsIOfVyfRorb/iX7nq2fOWG53xiLyzXk4RD" ..
	"uri5V/h3yp7D9d5Q+Wb4ctrcDMWkTax8R4Jixzll7mPfy6K1vfj+zFjSSa684lE0vKQkfLaPWBNRAyT/M2/hgRGBJmj4j9OgHMN3" ..
	"/BbzuEE4qVCskMxmVsvkA1OnXBS009eZ2hWszCRTnayEAe0EL1SiftgQ900y8xuvFMNAwpMhZ/mJ1+ASr4uVIu26/IvEB5fbtuy6" ..
	"7J00BGZdCdkM03kGcl447tPNrzfCTmDCHhKbuW69QJcNOCCADbS+TYWGSuuoXtiTLbWS7Geh9xIUuD2yqNWU7FWQV47SAmn4JZ+S" ..
	"zwayftemLHd+EmNEKLdk20E1uQapUohjw1Sk2rtr1KlrVbN5/ZGLQEiP17LWgGn0EmtPlVVhQVpXGQiR9y5IMiqmp1Fp+j3/JRwB" ..
	"OZRO2preVCgjqVfEBowthmlif3A9rV9mYwRjqKacrAmzyXnF0XWUkwF4e5S3xk4KdgEXynvZaNkA6uVeocvAk+Wfoqipa/IcwNMh" ..
	"Tr4Aa9GfEdhLzqs3ELBHc9qN/AVERHvAWf2ck6R3ehxK5ol0uM/uuLhRyGAbaThDMIiyoEsWgOlr7zgvgJIEsXDtCkwhZ6V8OuI+" ..
	"5B7B27mrz2d85AddGG6ROF5aLsAHUztq27Inse2D5OzvgejiMt4wI9FsQ+8QlIAKoPpagzh+hX0meZhwoBjxPvTLIu/gc+3cCJkO" ..
	"ZQv/ZyPlJDvPESTmmATrlD+F6EGsUnZVNTf1Itzc+N+leknLQTR6KV20jle3YHBfim61vlxVuRO3W0pAnJNK2oiZCfVlTGozrWGk" ..
	"qRrMwV28rMfzYkz6Wh/PsPG0EPA0wVXsH3pmMmK3ip62GZXav+xJq4ZYwkD/hv4Y4X3XURLwW/P1VAMBhaoY9iOl6/c8rmHAuUxt" ..
	"gImrjWpH3kR46XGajAuWcWFYInK8M/YMA0Kf01PhUJAa+C/G4J7AuRTTEJgPbQ3UoyWPtCYJiP/F1cUnWs93kfz4ym3rUDhHu9Ae" ..
	"JVwoJeC4O5BA4PKcu4g8zL+8ekf1RsLM8Ci+/bBiMsJOJgmXKuOp9P0aAWkZ8O/V//X9mWskuj9MwwYOkMEledO9eJma37nOIfya" ..
	"8TopWi6yFxYcTBYwhFQCKevLoJc32TWquLS7k0ldcR++F8dRZW36dZ+3oipiAYYToDLZj6AnkzEg4anOAgO0YqVcIwSaSrC+Jf8S" ..
	"sJy8zIe1YEbf4H/Kvtp/Vl2JTGGi7BYRImvbD15y177c7kR22jwh057ZCsiuky/YB99dS8gjYaa1BwZUeiSox5AA0BZqPJ/v58T2" ..
	"DF6i+Yn2HwAmLFWoV6KCXzEvNcjU5L5r/qA8YE9fVyUyHBf1/wBN6ZXfx+K7jsYBLUwpwr2z8pqoMfcDej/nlehWkG9mRxR3/qPT" ..
	"axg98fkqgs0vJ9fWpCx/kACZIE77mmxU/mZ7dXpLFkMUcbgNIlBzvqEGtRHTynKCanX5my47G59YMLPFuYycVdVg0knugwOQCf8l" ..
	""
local PAYLOAD_P3 =
	"JYP19uAAF6r9KkkFcPwH0Y+M0UBtQM2Tw1+iVvzdSbm/H3MVhrBT4YxeDUfgHkhF5YvHTu/ojD9NF5OBfXhiJYrwH9O58jJmwDxq" ..
	"yX+DLiSnrPcTiGqCf/daoQ3crufKIIMWbP5H4hFmQyJGT1rsnUi0wzoE5nV/PUGhQXkTj2drZ2C5uWZ3ftA854VDnDSuqw/gQc0E" ..
	"G8YyMFOFhohKlbfO2liqlxEXhkUJIB6COFwqZj9qo7HXiDtx7hJ3vTipgzBmWY/jF1DE7wzOtTX6QAc4kZRGF8QwoZ6WBvuoRB2L" ..
	"/GqnRmIA16kZjyJy3RTuAfIfJtE/5Q/Us3Ix/SlmeVBLDZWGPUIfyv5Day6l20QpvuYUXUSfEeEsj1M7KUKrIUe7FfBkRjXLHWeT" ..
	"pk3H+zb4xbDwNJO/jUUmTuxQdOUhvmKdDMfdpiSIbaZksckGlRKPXiwLl520zPXpCjVEZG+lXXlRd1NiN0ELgixEiyNQRABmqfdo" ..
	"HdK68vImKGZfu/WOov8YWb84oJWvvzYhpdWkh8F1g6Wtw1ShcjneNSCRvG2aJR9NJIrUh/yyDMmodP/mkPuEwnQHx45OgW2/S/I1" ..
	"0ys7rVXghW6/Y1c+uPbi50CzIN0jPuFVpSAbKl54JysTn1eOcJov/Sh5b/BKZ9Q3NsmDerR2BTVe6LVATKq88Stj2VZTd+rY2WUR" ..
	"GouLwOw09KixoST8AbwmCTuF4Cxx9Dh+e5av/N1VoRTgOZDXiLXV2VRKJ7UNGEh3N2YohXGgm1IqeW8rBKNvPFpxrfsrYDPQTphp" ..
	"aHLphxzATxaA52Oja/YPDyoJGgjSQJPRvTjgLap9dCFjf3IleOoQycCsThH3vu3NAY26VjqXJvTX5fHYYN9qEA0ONvMgdhLqPyI0" ..
	"YzIvGazF4CpMaXvHHr3cPjW45D5cYDyBxDM5F3qQ3u9XSNW10htYJY/JTpowYrM46PsfNnpr/qONW+gl0vpqK/13CokLZztzrGIu" ..
	"FlYj+4Erqdaekrh6QGOjrlBglp/zC9S+jI+/oywh125RLaqgQu6uGX2cImN+FQpa5o5NKwB4ArEVOq3nL7GNhc3chH5+pZSKFq79" ..
	"bYfJ3yEhdTJ0o/Qyx/Rmyx1zp1vkv33QtDxBCEJj5Edv5FH/avkyb1rLj5ED9KrGqGaMBkcWbcUyfxs/HcanX7/hwFfFxpYxOye4" ..
	"9IZTATDTEVRpyrQ0UgXTVnUi/bcTPsiMXE6dJZ66hwICHUBAsbImSPZfoVNEpu+UbSR1WCyVseOT8u+0Cea3bbJWdpiOtYWNPUeL" ..
	"ChZaXthYQliwhjpgC3UsSZ3LFyhi/1BwjOiLyIPvAPJn3cs+b0d91EdPMuJ9WYpwIbfkyR3AWgsxkilUi589h/j0wswwGwsd92A8" ..
	"WGkpQtBPUUslyMkpHi1wApYZ42yr/5CuzUGe+I8x0FLMchb3cjBrCN3cjY0Sv6MStkCDDO/8Mx8WilQUF8Bsfn+aiNfecvEWcUf1" ..
	"uWOlYyRQUZzKwGzLkE7aoH5lCA2QzF8klLVAyFvhP/BZyAg8KhZXVwxHWQ0204jbs1HKMh0hya7re0InLVVlFqKWmDqLATRyYhTK" ..
	"Qoroa8eLIfROEa6h9oZyt3abA5JYGrLYL3iw/oml4yWQuyTKELdTkuKVXDyNmoLJuUpaqOmIUZUAb9VbxvrT6xHxpLhocdeZbejK" ..
	"qnKivq1VHwVO9jEyAAvD42naL1gguPCcvfnx7OB2QeFXkbSIDVylriSwy9HvULILaqQrPHD0s0pXBwU0EniQg7/PnmW5mby7pTeV" ..
	"8EY+vRqB8iWb5OkNOGm8MNS6njM5v9p3lqYwqQy6h9aLs627X5WwW7AvC2pxmqMK1+EmcXBeKP2oI9XSB2N8snUv0RKWv9LfMGpQ" ..
	"vKx9VpelMlHq3xXtkNykIuD03UrMfS/a8gE4INsDUiJeWGn+rQdFadmHwFoHJPj6vmkcxG6J7hCu/Ywk9UsIIoY656eRWcfFapc3" ..
	"GPz34YIPdhfocDaKJE8LenWp+BfSSE6CfAKGiClWVhOEnBWj23RGLeV6n/Duy/ZGx3VOowTyc1DYLmxZmYzB8Hq98hN6JdnIXG1V" ..
	"gTbINGOnxmQWeEQHoZntSccq9YdwMeTCgHQ3qCDRtwqae4SpFmeKk74aHdcN03QK7Ibr/DNXSlAUt+j92O2IC78RH7o/GQL6rmG0" ..
	"FzU/OCFqK4bWmScISqQxCSkbxz4rKpLTcEH5Bl1WlGJ6+tkBUIAsQwOq6UBpqMGAqD214Sa2KEX0To/N6C1Lelj+DRl0jaeAZoVM" ..
	"F+eMower9aEK671EGcsh+NB+ACrWnzIiRJ0J4MSXeFbDzgYGqDLTTbwV2KRzBC4msH2titpuo88t/1FxzBMjGjMTzNWIHyiuAZ2W" ..
	"4lJrSru+X/iK8TCiicVX8Lh3fVFm3OPhvdhODk1/TU4PRGvCwVfCgLk45Vh05Dao89wrejc4Z5WFgIzHRyZcPFPvBgBPZvLR0rCA" ..
	"6UYxnLw8gJSicncR2nvqLFicxPAMtlId49QcI9zGk1Ye4fCBgoUuNj31fIX1fVt9SQc5qgDz9em+PWlleUdHk+PjQ0xtBi18VAbj" ..
	"TjxFaSYiRl0YjG/HfGwEr59WCkf/9Kd7PmTa6/b2xWojRqCoi1JyOgwGrqBmfk5mkVBP3af1rsoaqDcpBRtKzlTGQ8iHeEgihrCM" ..
	"fa4392aBaPb2UBpmzG9HxdigvJNHI6lNlfs9biLrGM436bEcip5gg+4DcWjSiAsPLMMeQ5rIKkma4IMQddWjCMJE3MK3y0sWlEcL" ..
	"x2ZXjSNB9ZCTkJcXnPijJyiwEPePoyg67tRVkA8ikTkkg5/5Ge6iYfA5B22xSfs1M7dA4QoLV07Ys0d2VIs16z0vAxLP+UJtkFni" ..
	"YJYQ36wPDvzu/4ex0MtrRt0U597ATJ81oxXbgzs594d7SzzxxHu8i0Ed0vUXX5cbY+XDd6PyL/huzWZfcgqYuyeEl2xQp5mAP7Mv" ..
	"JNzxtoJ4c6hUqGOFuxu/8S/KzHazVyvl7T+BqPncObrkGsbxMfaOKq74SiYNB9exkbBm7eH+4LENXthq63x1p4GswblA+lWU6DjJ" ..
	"ObkGoA8nNxpM3lcee4Bo6dAK9D+7iOXn4cAJMbVWY57eEBXixMRb/1cF+Lcl9VJQpTHQiTbDDITHJ2dWVQF+GXMQq7FV/NXmvYQK" ..
	"2RqG8Ehqr1gr+DOpAX8bMc8ttYUlnawHwhuR6h1FC+wdw0Nj0smWZ7GFotoF/yRuZI+CGu7PeWet2cR5sEIP2nL/2A2CeCMcu7eh" ..
	"js30mbLXvD5z7e3voa/uBPreDAOSC9SYXF6vYkpVH4VMk5qSwPX4Gceby5JjkoYcFs6mJwMsHsUHzNB/nXJ5vbrY6OsMMxEtwqIX" ..
	"lpUkM3j5gUOb3tvbek9GuEe8nT9ARn+0osWRFvxsP2YFKkGZ2ksUBHCeV4Bju9Yb4+A+8JvQffcbNkinV5+7RlZWqz3qskow0qGO" ..
	"1neslYie0u77GLZJo+UQClmLp2tvw0RdcR0EWKQr6D7eNRC9sonzRZy55GGJQ8r7YFYR+bVwZ8GWH/Vzt6WSy+9pHTvKi/TsZ2uQ" ..
	"5GOG1BB5qwxPdvmT46tGnxOCjtei6z2s1KvbwardUXU1MvRFArNNn/kMtdspx6a7h8H1l9z9dgfUKkQPWJm62KoaZNJ5bhG+Q8H7" ..
	"m1LzTZY3bJw/yTL91Nn9LDN34spyjiZLgptV8/ln8q8wB2/f18HDxShnzKUceDn4cqtw0VV9zV9lnPsIPN9oEyqeY+SEPUA6k/53" ..
	"isS66ovJF9aQt0TNnNtDlGjJN/aZCsrWXYxOBR5uTVkhLVWPc/A7lE7LBWpxPitmV9usE8GXcAZ2f+WyDTrF6mp2xJQrddIMI9ou" ..
	"PU6SMrGG/+43Wy9ea10gCTOrHRDUx7KJD2oOLuxvdYdKOSrCGyh+EHIiRTgm1N970Fez/SZoqIemjZ6ITQZiCvZiNMbKxuWoSr+l" ..
	"yH/maEwPwbVHWJ7E6/D7G42fudhnAInefL4ME1K9LthsSdjGtn8loVXxVYNU93lVjg8WgukdUxpHbnkUaHOFmOJJkP7Y0uq9XnS/" ..
	"ImZJ7tkHRHkXEp9KFjolOmU5VrvQPmEoe7gNrp3K91GwaoH9eA+0rQPRNxz8WoSLNIs5LMSalRPjeWrPn5SY9g7Fj80tZTgQ8NT2" ..
	"neh+pgy+OdM0nnNULrPqWq1+S/pQepXVQiy3i1kAnQVssjFvTnq0A/+rCGNnHN82d5TvR1G63k8xU35zR0jaLj8Pe6/TTlxiaoKr" ..
	"UNEXVnM21NfickpgvmNDllYqTCaEabXhRqiPo7HfH/Hx0Do138Y3eC17+uSrbcKpfAKJ4Ru/idpAIBf/NwiDgWzHzJroM8L3UbW3" ..
	"l5j3frunJvgF2/zvSom8FpdYjDKWauk1RyHrBF0ucImKqoFnyB5WyJe8oIjcVlgAFLGsqBG8ahkssgXjbh5JoQQOKq8DlihgDoWF" ..
	"VubHFCZdNluNgJ5CYUqHZ4L1B9bvQ22c15I7uPLHQrX2vvSJ3xvmszY/qfi/xhWgj2wyLhxWW78ZOBE/w4Zo1cXbdNVnUkgV32Le" ..
	"hbeO+KEZV9yr/pXBuJ3oFy09kMzSgxDTHLVxtvElHKexraqJPEYyLASBR0HcBqaggfCK/msg4gPRrRGaXM0yQ+pYoOmfi4iICHF0" ..
	"JPu4ipid3sDiRoEa1bgtQOKcm7SpLD1+i7yx8IkXMhbg70oSuwGvN2KJlQc7ZzZJE+mgNmiranWdQ+HyvePfDzFgfrS1SP/+5UUd" ..
	"hCKHrFrY+7ubChCcWV/hMtYOBlrTjopIM1K2xAloEYa7vsU8MSyaP/sHw410YR0f9upcdruMvMYVsSxm1AR17vRrwrjP6NmHKD3U" ..
	"jpmj/MQO2w61EGp3lWaytDKSpOQFCA2PW1amP7DEIi2cLsv8L3n8Wuscn5v0HeiyVKdM1Bt6XjQATRU4iiZ4VgG99OMDn4qjawe6" ..
	"nEtMiHpOhOeVmAH4Fcu++faZMHZRXrV4DX6VdqCu4gcJGu8+TU2BeNwrBTWXhwtuRXKBOaLlzDMBHl9Yxgh3FWdvyspGOG1e3GuM" ..
	"fZseeNWCbFW0J2UW1wMIF1b0cluzGiKCsbIQjj6no8BRKnTePKtjjD7EfDCb3dp94MWCwAj2bstresgM/q9FBCnp4on54CoxNTE5" ..
	"CDz82S5FoehtgojD7AKBFGIOlylDzYdb5Ph0BAxk3zzVmDXqOoea84F0Q2QIHS4jcHlVO/oSZAXhlJ7hnS9KgvTrK7M+4Tcn923u" ..
	"bvj9fhCPljHPgjv987wyQ1U8QNt6fhaOghoJOSRp46b9XbBtDJc+d3t3O1sPRXRfFvzepwmPEL0jCvgZhzxx1JOB/XQ1O6SDd0bH" ..
	"liltVVGirrVlbnqnq8T02b8G8WsLcwwzpFITYNrYQzvATFXanQANv7aGRE1xgsYxxZAlcs2KlicTQSmFnpmjDyDbZg0yoI/N/7G9" ..
	"lvRKoFP+wKthyVkHRyl1sa6BMTXXEwynwyG01ew79Y5hiBkaIIb/Ta0IIW/5/e1wmAeXwIhOFNEt4sxfoo1pu529zyT26h+x+dcW" ..
	"g4rulZufgmaBJUUPBUy0pSnozw9ZLe153HpVP2uO6dg5JxWfa3bYHeKOcnlj51K5LWQqOK3vGSuiuKjlDy70F/6N/K+X3IhAZ1N9" ..
	"UuTK2zZ+0Pntf9RLG5btRfju2y3j6qTWn9fDoNUy3j8RSBbFSRmKOH6TxIYtEZNdut8FcJciW/lACi5gSNeFzUnlXHoB3RQ168Nd" ..
	"HSLDcffgJUfs2ZAerW7+Vtd869yTjhYOI7q/YdXFSoY3Hjv/X1j8xDKVCamMu079AFVG6P8FyW7Ducd2GVBhW4ky9f4hU1E9ui45" ..
	"PwKsfptkY8wLlVF7CFdrfXDawaUYXpzmsECTGBmEuJEKAcJZJ9mhJPWwtPT3xkdgseIFuuyz+Yl75XfVgjd1WlcCGbD6jLH3wQlf" ..
	""
local PAYLOAD_P4 =
	"4JnGCoYeWgNoGf+1IM5MAo3AsLeIjmVouuEHTqXISj4k6I/5MIQtcigm1AdvxhwhYwLtGY61w+lzNmK/+ex4Xo0U8jlgXjTv6OBq" ..
	"LOsBVUctoyFxH8DGKZEROfyJivk3bbPOKu9nQGcgesQXKilklb/3ZUE2jGQhXnrcRBkGoWDVkGdenubE1Rrl9ySUnn5sohMYgvX1" ..
	"pnwvSdbxPZye1FZuuaV90kHgI4q3iMLYzcfY/Qd/avWVHokFf17sSt9v3EoFoPbSDss/6dfkfq1jlXKRaS84vS/w9QQt1MdhM56s" ..
	"fBEdKi6mcWhJvuZo2DI71Y4kS7cEbMvzE4lKcWHQtSTJnEJlsJw4smiZETL6tRIV7lLmOzY17UdAPTcmrDrATMG/ShEebK3iGWXQ" ..
	"kfdszLxYHNUkMgzPp5nhcD8uCbc27TGLoDnhYr/MaDQmL1djLToipgE2xZsz8Qlwi5db+5TbI06bHtiGCQHA3CgSZH+qqubbl3OP" ..
	"T+fJC1eOJRMdLxdlh4puOh5xkSzKrsGWhYXCcjHC06+Mo/GM+tnBWqVt9tLy/WXCq7FlwTb+n5gMT27vbA4qnQKr+C+myW2vrKqL" ..
	"k6LRSJTnV5j/pqjCp4YZZJG5xvL7p0K1AZORjBkmHY8V3FbRXviwTHv20N0+Rh4CM/4BU8Wjvw39Xyk5VUrtUNiv9qVT5DigUdLq" ..
	"j1fyi4h5+ApsfToysC5up3lvrvwj3Q0wA5HAst6ZToMCJcZ8vM6J39ZXbcaWmUXpjmRFsK4vs36gHS8amD+84hxb7gLRZfYeh0cT" ..
	"m/fPCvYze/8JKU8dPCFjn0fR3Cxtjh2fTPMQPelk4x+f3got/hZSID/ulJzhAFtlDUl/OYfw5jwELBjj3ka4znSYUpsumHU9tlDC" ..
	"kDpTkhdVsC1efjXrV0jJXnQMiZviRojeJE6IzxYqufNyeeh9q6Vb2FwttxdVDNltEOXGtEQPDaaRGD9b0BraKCthCilV5XaUe9m1" ..
	"oSbJp0Qw8w403SVIrd6tF0jn1XKPIe4D1o7tW6Ipr0+IoTdxkC8pRXUXFqhYN6un1X3RSnQZQGgztaCx7ImTvzVbP5aWFHTRctyC" ..
	"gjlho4tSWv0HlP+DK78rIG/vAbMaF+BD/F3ZUperShgASXH2YpYiGIqdwssMHO+6njTZclgVrRNWK5Gq6IK+8UK4H0X/va3inkWA" ..
	"NJIm5sbunuSffcBcIEV45CXxaMhXq1+MevR+rcWt5YifWJxAeXxq/5MTFa93sTIXN/ezeUumwvgPnmtK3G/5318qxMRMGuxYaT5E" ..
	"Rm5Zw0gBRZYUkCG6BXNBX6qCDFQFRuGqRhL33dFnp39HtdapcnuMaxtgFvUGcp4YNw00ZHcRm6sC7Av0V2/04x9BZO+xsSHmyt4H" ..
	"eYseNIibuabphvGF9hyu6ktkKKNOqgxj1KqhkCM1BFdqBW5pAoIOWfWa+Od9UaXKCXC2SUum9K9TsUTbtxlfdajE/a9DGf33hXhM" ..
	"P6t21DbujojMzSwysh59w6Pw5Qv0ujaxAO/FPK8nGHeV2xl2PeJyBFNFnVtijY9ZAoosUpIhoU7cbDQ/cwcZxEcFyHgLyGbt57nF" ..
	"6pN/Ums7dKNyUWQydxr2YMRYmdMvUKL7hMu3s+YXjbYkbWwzP9/DQ6GXTe6fByYuQOrFSJ/xr+hDmMTlMrMqbWgLtX/dy1HSCSmp" ..
	"QmmXICCfWJ+tKpK0EfG1WuWfjQPp25bodOCoRu3mzIv3xYtNzFWKW/0j62MPddmrZVLslA5RLU9mPfvwnPvoqWm6xZkHxTKPKsCM" ..
	"sZSHzmAovyB0jx3DOHAJgqgTP6EdPP6/C49JMK27YKyzkS8kFeMRDv2yfls4UUpgeSvQVGQxMVVYutRGaR2VKstQkCJvqGIcwVE4" ..
	"QVfDFOZddsVwL3lL9lxD7CldV21D8W+hT/rnxD+TeWBowJSRcYjpjNSP8pRFgNF0jg1QtZ4feF+iK6WI9mUh68le3eOklo2pAROn" ..
	"SVr9fXKz3XlwrVnWHZiu1NM9A9fMiHEtk0y8XrChmdkV7CpZt89lemJS4uWe6/tixZRapjevjjC+DsLrIm+x/QwLOYaQwKXd1x2y" ..
	"8AA78an7j7MyK7J1i19oUgumYbjKblMW3NIjMhf9s9POfNudnI3z6p7A+MGC/AWznyHnWYsnBvbn9VSnsWVnulM+O4jeFTav0smB" ..
	"sQweiiHTalj5up93zfme/yGEbSIQgmvMRvNDAoEf8The9hR9hG+mEArCUmkhbVHZCjuKwFq8zYZzgzxJbKCMbDhvadeWB+2JWUUg" ..
	"v0OvkXbwML7sKHM3L/DHTEsV2/3ANAaenxrQkObkAf2rKeaMh/GVTsnTZhdY1d1Yl+0lhJ51PIIi8sdymmO76Km8ydaboerZ9/Vh" ..
	"br9w8USIOMc06oKaghCB11XIbAPgruORXST6jIbRtxFW4yh4NcK4VXVxwbyh1l7jeb4OUbfR3cyMHYlnpQKBR9puF5tsxWppiCN4" ..
	"1dOSpS4LKVy4jy7gQ5nUIqH8FAscMdy00c5ykg0Fv+o+icInnTAFJYafMutJnobGa6l+sbatAwpSwGjsDDMAxYuuwjbaspAG26sf" ..
	"eMCudT1sgWw8Olz1HccdlmJe0l3xDyU1s1kLRluXIb07fLa75pBDSdUFjgOVx9BCgZ/AHSp6iohIsYsAgdl+G/YocViEXVpozIGO" ..
	"feNYi6xc5cRsexE75Pr/0jiAdfkWI9K/dh+0dGW+f7mSwCOtjYKDND0mpad8GKl3YfYq454GY5BMFc8Z82+AERMdl00DoG9Dnh8d" ..
	"IUBmnQiMi779ijKZso6rkXEEHKlRttYIEEftrqz297Ysh/23OVt6puHLfx0WjP20WnBbEbnfTvfkCcdEhHcUtonrt2tjuAFd9Tns" ..
	"juITGFEQPwCbn5QmvItV/ZXyZVS+c6i3nZ/nj8DClDe2QnvdSy1xbILRLi96FkVPx6dI11zvHZKDF9u4hkxnbNy1x8Pyark6QBWo" ..
	"AtagJDFe8qdHZHxDzRzVR85McFzJE/QCONQEtdoI3kDV4nWQE2beRZXlq8fnSEVWXt34koLBBJOwoQrcZyzduD83vdnpBVtInCvI" ..
	"ehrmsA0mft/Se55ngxTcX4BI3/FAdnu+VDJ/WhY0uHa/wYdVde13W+ftOiPy3INOxWxGwDudoF/Djgp+spKAFpuRHaxaIkKpaurf" ..
	"pVelQYQAWL3xWSl39mrSWerzi0+MiGTCNj9WaqCavtdzw9NyGK4YYW3ovEi6tWecfrK/HeoSuFh46RNdqMFSOPsYAgTjUDs6l6Eo" ..
	"T1IldEf585EIFYfbH+dU8cqcLwca6gy2TofCfcpeSF8Djb71tvUkk7pAV4TBUqYLxOPOBhOCfMlqpH2K9uJ2dHDElRHlxJMpAqep" ..
	"3gcET9drOAeyr1x0waMx1CxfU632te+QdYaZRQk/JLZOzB1guzbs9Ycd8Hil3hoB/d4R5PkfUaw36xhvYWrrwURaExZzXYR/BCxW" ..
	"5K9vlMkxbbTexOv5zQP3feCEKJ+2fRhhQPlYp+A27dnoQ5O4KULevzkjIWj4+lQ5KdbFsMh0M23MxLAJM21MEgM9M1R4hblVeDEA" ..
	"ZTBNQwgoykjqp3PT0BLt4VZMiVPk0Cu0VldlcNdXSW5wMGfDWRH7dxDWpOc/9iwTUuKLUbgC0BrczN1Gq1ZGcANY9FBTzCXnAyJc" ..
	"DOTbhlEUNK9CwsfSH4YFS58+cO7nShi56qKJGbVaZjnP1LF40TejNFhjSdMvNgKLknnLz7qiHnadpfu+zEwXrpWUCkg05gYcJXZR" ..
	"YOQyDJR+BuqdVbupaUd28IH55PzvaCesNzgY3wwATjJI9MNtzmU7hFAMHep3HwgAekpXR7WNMLF5yh0z9jp+atrJYjXfz+nbIery" ..
	"geLwvEdFsH3kzzXVuIUpIEioadS07Uum75/uVwFFBIq682f4zedx9BRoCLnwKstUWmytL84W/KOaPTAWjZIXghbcV/f5ljFDiqhK" ..
	"s+skQdw19W2VPE4T5JE/O+XqBqynI82JEQTitKzkp37x19bq7f9tSH8JRv/kyQD/UEtZHWdS6T7ob8YLD9GwFFGa22s0qCsjl9DC" ..
	"V/Wgw33Uyf4KVSqTaNVcBdPFZl+mX+/HbtA9hxpuuge6gseuWiL2Z6bGNCgcxiD9uS3dtTUFhcGEJXRYD8806lN2N3RkHBIaHQfo" ..
	"IsMW99rLT1zUrI7EartM3tg/2wPrztTTgogO/WqtjOTkbtkOjN3ioD43HsWPkwVxGpFyEmVTN/Kf2EYThMZlKJnFZGKwl8LjuD1n" ..
	"Jy9G6+ssa+0cphToQgtBHUZmmwGtN0+t1bAu2C9fmDPZsd4EmYaQO+MCT8zd7sM2TjcDnvqVA6Dp7lIRo0i6ZR01wPezCMKzpWGf" ..
	"xoOwZyf1pf4DGj9lJwpWhODQuye8vGmJYC4GZ3Ro9kSp1kLEuf2h+F4zJ0D5rs/ZFtg7ipA1345sOS8LlE4UafM233/zDLFu9Kx8" ..
	"SX5fDRiJZoVz7CKmyiRdu4aBwrh6+0tZnncoksb7NscjPuRnXl7xSg/b7ssVhBL13hoJRD/P0eA6mUER5dm8kGGlIhRGKwOY3V/J" ..
	"QvEY+PQ17SHtyYej1Ej2LrbneopWtLac8zWc7u3zIyDuVPrdtLJCxiltzNrl1oz2dEtEPLbvGxlrS4PHoiq/rLSX6LqUNR094WRe" ..
	"gy3UaXuOH6oJy7wZHyS+uigLVUCrs2slrrGXi9ycIvzDCua3y5s3glrJFnK4SEB0ICoe9wMOG98WDK40vTRjRuK5gNp/bwKNtcrP" ..
	"Mr5MvA9YyugC8iJAmLPEDpYvfWpED+2Kl5aLmE6SyQRsXZREbRWWYu2gH7Dqvpt7v/L38usWF00twcgmwUHFebYY774lImrvQGUa" ..
	"DcI4F7VyziaYLbhq7T/hwB9BU0F7ykT8+AgpCVIA12AlGIRj2csVVJ03xprXE6siOlHyPcq8lFuiYCQP0Hs3rGWiUCADd3VBff8c" ..
	"P5lNq+W3174jBVApSEHObk7MMNP0lmZlRV1Z5Nw6uYFdkEJ/2h45CUfTrMPGD/xkMKXvPjFJbGgv1wnIoJnyRSLlSnspsruSQk83" ..
	"WCEwRM0au0s4LWTVlho3wfARBmoSqTGtoSw9xXDKV/OZgApOEYfCD/yMo03yZ4VjWJdUYd0CpIpfpqZqeNJ5Fhts7xwMmRf5UVX8" ..
	"g7xA5S4elxAcOXjcZUW/PewJ+sXUUeUwirTtjQBa+GBEadn0jHJhCYqHHuJa/Vv3lFetqlFh2ZnU470QvLrq4Evw/Chuooyyraca" ..
	"0FVXe0JLfx3VWfktyex0PDscpK44dC8oXWuIAbDX6BDJlnxYWERQlEHv8LyNHywxLD0oNUoykwHlE7BC1ozDIVhQLFDUdY2fK3ay" ..
	"w3iZPlXQ109bS4kDD/YUiUB16yH11xRWjcjGGgjjsv5c1exoBI7Zh407dGKPuPKVWuohyHLIYa3NYiigBzCn/mzyMq8KFPa76U98" ..
	"UQPNb/eBAou6bW4KK+fVBPh6gZEzBURJLVmmbFOqRaH8o/UNopQPfwD/tL0QXVLjaO6/QUnnoKHiliWtZVjkvv0OgJO8/deTI8/X" ..
	"RdgelyvANNErxpQ/seo11PB/JXoR64ktMfSq6qeri0SjwvykrwJ0wgSb1iJ2ASywPt0MdjFPPSOtYogO70Xv63IUXjSYcZ93khy+" ..
	"6KGDEnqOkfoY46lzl9V+yepRYPuI4NPzpLDzQQm3DXHJtIvHahKTf9NsNtdGcrpZGjXBPM8KqUV+h1BFry+NGq5TvCeIucHv4Zjd" ..
	"dcOtrVd6+EYWhv1N0r8jE3iTFVAQoFZ+inGvJJ78Nc9Q5NpRQ0ry1VeZ5rxt6/jl/a13+W+iNop94WH6gKh3FYCZlFVp/HD61ky3" ..
	"eJWOhXuskY1j9pDmx7hc99c+aH50MDMod6jJ2jCppgeP44DRtVEYUhV8I2j9QMFh4O+8Q1Fco+rfK9NSfrotUmBhzffQh3sOUayH" ..
	""
local PAYLOAD_P5 =
	"6AIGp8Q4uZ25N1QtGRVUDprxoMLMOHkkd041Mi3tuqEL7uIcpD8bFpP+hdv/x4X6IEDX1M+DehziMZdcekaHhfLbbB/zOG5/nXfy" ..
	"b3Is1oNlX4NhpvBJuXYL4KDrw0mZZiVOBqx/DliA77K7ZpVHWm0qoLHLVfc1U6mCwSL7HCUxh9ZR1341nBO46O26Il89nq7uGCfU" ..
	"NpVqTkCkrz1B0T5vEyu4IgTRQcnuEfiyzyekfTidAyZMHvoJWDmIy1S9xmA+wYC3TsWbZ840D6885e+oWVrZhMn8braV0/eKYvak" ..
	"rLpJnXeG4r95pBD8TTHtjG0eF/a6we7l15DQ6fSDF58zoinzIEKTXD0m1ux2MVhanrSEmaaw4fTmT7cO0ehOR0JWGUTBnxcBDipw" ..
	"eECoBl5mgzhmWXA9tHSrRGxiMMGMwXNoVzHKHCe2Z/+miQmERHrlfKlS/I6jSJjD6aVQci36JMWDdDtyDrxsl1LydjFKa2Ds72zy" ..
	"AaRQsKvr/raoznedTGREIHSOvaR9JRBCF6DZqlpb2+v0VfaCk1quq7TcuAaCiSq9enfzv7DcSRmrClb3BbJUATmkipvhrOXU+XKo" ..
	"G1id3GuipNJoXVLQ2x9XKd4GQNqqMRF1jSRl8SYelFwJLuU6VjTqSTBEMnJOgRnC0ZxeDLLoZJojB1Aj0ECOWtAqXACSY9ByyX/t" ..
	"hsMJfJyW1qRqqj795P4Qr5Mq2qviBh7wqH8lU7LaDeaPn8AWN0Fjmd6VdRIH7Sw3R0POGTDmsd/v5Ea5ujORBkTbhVn+MKdfLvLY" ..
	"jJeSXCJTLwQ8675yZ+uGyACuxXdJYAhshcyIL4nZyJI7N6wdvfu1EsbSA7aZ+wjTkM/26I+L3PSUpeEDIyeOzHrjEaiFmoj8GP4R" ..
	"xYVHqonRe2u3jfTMcHZI2NfV5IVO1xMjKDeZkw2ABBXwrW2Uyk9JMjk1FXyBQ58E35vTTcNuxyeqpeasDovRv1yazAe1svqkBu0C" ..
	"zT/gf6J48W2YBaDsafSdHBGIrf07FoM1XHx1s3rcUC8CQWSMB99AhnMykeipo7WgEeeZ5sChGbjRThPS7UpVPPi/+5MZdgu6kOr5" ..
	"aV6qdHJ5fTd1fiZw/dRoueZSPRYnZHFttT/aSK4R/fuIfTMBMjJ81iCF5Pro9oc7vLuUMs9uLIJGnbFQ0Sjnw1+6zQvNP8MwfB1/" ..
	"Ihpzw06fiW8zXZXIJt5nbyiIG08GBhemeSe0+/B8dIllnJPl7xJsU5h9NoAOQHcK3aQ7g0x2zewXGRA7zCtY0m0iHxpBHI/lz0RW" ..
	"IIVHixSnCGa00v7/X668pPf1YS5y5jlix9SlMuSAVC6wh/CevkHg4eFCTrGpTirBBbiZtW4L1SdSk2cK6uNfobh/ObXRaiZB5/1z" ..
	"M3qPb/8ro9miZryj+9Wa1D9Vqo6F0IwbnIfBlEQ1hgZGJjxHSrAUDCR+Q0EQYQu5+OL0idRlqabQvolnQuDL9fNS0Btv3RS0NBub" ..
	"JKjY0Uya9IL0REf0CVk0+6wRet6zF6TNE5kL3Tj9pLsvNljCmWBYnVCKbyzzm1bVYFyWQLOYbIEYLstpgsUFgXTH46zEb8FJvzjQ" ..
	"w4tP0UASmXuEUdkPc2pJFtpJU56t3NixLR03RCorYe0ERyv2h5XFvBqaDwrIwKlebgR/3ALmGN2q7/iWp36x5XkBLfne49A9y0U9" ..
	"/ylE03WPeFEmklrg0ZaYYh1MVZP+3h/FjHBWxyWEIi3EHL8mKBkOWUNR6LA00qt6a5hvF3ACKSUK3ML57WwYIwpOD8V9hRhGZ7cq" ..
	"6gbeaCB9erT8K+Axn63255sDqqMQFbx0KYn/akTwUUr3wpe9A4ttIH81nStVH0Ynh9OSjZ1cxFFJ58Db1946P+yFV+fVLwg8iMXz" ..
	"oR9fN7Zx/zkMKAeqTUYFzgrPzbhBTjpbN5uVZ4w7EGIYl/E3C1XGKLEfpuh6+rzdky5MjssYNcf9yqTLqwJarpOW0PASwe+Qe11m" ..
	"BS56eyVFeikmR8d3eXNol9bTcXoqSKBmqAeE1e3SbWtEoM9EC1fRrGTIxRXERlgCuRuUJlZEGSMGztrGN7iMFLTdVYTZNcJyg11E" ..
	"PAlCg9OE0eNGG/uXzZHv5jhA43VUWSEI9377P1rcEuiDzEl0X+UK+Anq0SwRjVXeyyInjuHBnrY8NJA88eypQVC7TJxyBIjBjeoQ" ..
	"tKpncGf1PxBGJ+AbwuYIN3TFQnp9+2y7QN+c7duzSNTP/vZ6oWVCc/TNV71Mhr8aju9uI5fuJkp4wNaf8N85/gM8wlJw+4HPd9ck" ..
	"d6SQborVRB8VBIvy1YBgrEF/quFqQrDAMK+1vMcFqirbatMCFaEHLEyaN1wOHxBGnvcniwSAIg1ISPHA931cJ8nHqr9XjviDHVxJ" ..
	"PJ5xup2g5JqdPN7hXCY2fyDMabFlYjkRRhBheIxaQGrFWEBo4cjPFMKvpXzfgRoXGJAefki/E+LzIqyi3MEWF6xqdXgRc4cWhP7o" ..
	"mVk1PRMI4W2BrWmRd/iV1LYRcyNFUxx0p67EKvsOeK+PUq0uue/Def+Zi2ngw/PaeLv602O1ztEfAxn4I33XOflu2Y8b+TpyfEtJ" ..
	"qlj4sXesRqHkqkmrCJ4xhEZUk6ScoLBfjvxKvJJt2161z6TUvu8wGpTANk1z3DTsZ6AstvLUc+pBeycEQ+37pRgpU6wpT8cldvGX" ..
	"UAzvjwHgC05mLROsAhoErSvQLFhTuah/tFx4fckFONzwwZhd2gfLxqAAO4Y808N8rJOgeNWmZDYWNux5W7uShLBchWp0JESUmC0Z" ..
	"VeKcR4pm686WVXH5aHwlJ8EQmUIqgqreVD85xxr2TMypaOlthN0X0vlwGWB3rr+bZQFJid25SN4Eb5z33uHV1U6qLq/zWAtlodcQ" ..
	"EM/oHtfl1yyfJLe7zv5HpkeMFhoH6ha5eojDMot0SQ0LYG9LAvrFsWdcw/fAK2t3O8+exREpgB7n1eEir4iAPFj8LbIdtM0sOETs" ..
	"2XCCAoMX9kccgmmOqNh4oBjUfhkBEZrUO/KsCJWfwuy8HJiv7MJr/KiNuq9577uXItb22z7ZSW9G0+1em6YKa34cCv+fGEVG/XOU" ..
	"ex/nQuiZdr+MLaZ/zkYB2760kHqiEGCSKLuJwWwwl51SJFGz+PekkRJFbzobpn4lpzXv8h8KZIQcPLdPiFj/bYIdqt39SoHDjehB" ..
	"IhgA7M/enTTvsueD+kxO7dIyB8dCm6TQzf9ftQDnZR3ZT5OefvdUT2Ec4HSh37XvI6nkdRUmixM+RjZkm4OzyPVTq7BG20PB3Pyv" ..
	"dnTYr19cS+O39isoTbzxOT5OfaYiH7E9iTx+/yXFM5uuzkElMzhi6LhV7NqV765t2kWMabZrIVy7VRSjsVfrq0MXLSYhAQ0iMfju" ..
	"rbP8Kx/v+tz4ckSOBuyxYQ0H3d8RCNaFQUhRK/Uw/NbYkIhYP2mrgkkR0wV5sIzXjZwUMzLTC3cOh+7yCBf/nR/laRBNYBQ7y5kZ" ..
	"nDIYzcSl97OwiME51LxRDj31gw0P77g015jWfG5qpWwgdPb80yYr0f2qdEJcsc1oBojIhD3EgTqiVH5OMyDUDQuzPcz1WRffKWbY" ..
	"CEXl3QzokHQUfSUNtBIFlgimHQtMGxKIji+ke6rf4Zj9k9v9GW0vjsS+6/W+Tk9ln6+Tve09pDAVpK6sXraP9RVxTc7JJNZ2iC0i" ..
	"J6egLG/mDYi+WE1jTT+ynNsbPPTzDvrH2c2ntdZ1NoRlsq9/fymb3lvlISOfFIZFZ7mQkrgx30Wtm3SLvgCgygPJAG9yJRlDBOjH" ..
	"A5m5hXO8X5420WbDMPl9vE0s93E1thg2kBrgaqB6NpomtweIOZ1B+icrIDfVNFgJK03QinvVb92ecNJf/7FMvPvkRds5V5O0PtzN" ..
	"HCvFMiijl7gWwSomxymwx3kwRV4AMW9GwgTuroDXVFYL9bxOKbGSxMoRQv4w36PTb1i3BuURDEQtZXB7LRAMB6qM+SnGW+7b882M" ..
	"ZZiZAJ5exzCQG1btfOIlj/RewhHKJjfxi2wSro69VFoWi0R1/ERFv8WW2FpQC4OhnRQJ68ppVOrZIxA8nh6YgvSrt16h9g5ddGG7" ..
	"3gWXYN/6Mb8Y9PQZoAOgHGRpZSlF2a1IEcby5Vko7fZ0bL9885+SLPsQuTVF/Mpb/BkgT7m1YH02iAZzXOVupUYiq0nLXH9zIIrm" ..
	"a/q58X+y5en0P3t3PA3meJ9FQdWtujVeeD2d3HpbZ/7AEjrSM8bDqi4TFgzCeK+4RygAIC7miky9QyNXv/r7gfQZTbWTfuLQYrOY" ..
	"g3bwBQLsiHxe4CYnBGzp1q8ACimbnwE2Xng+n3UCqrjaay/+wK2g5yUgZnOoLL4ebkGeeMSAXjFrVk4lcWYpUDJNXaj7+S0aYM+N" ..
	"YbKNNcmhATJAwiXpc+nYBA3mpy3QQKDwx55rIKrqv52c6MVK/xsz4emToQULcPblhmol/i3ISH0mkV0mB/1zsC+sz5EyU+mNsxDg" ..
	"YB2gKYbsiGDz/UyRk/Nvl6zc0pEP2Y7gEAkaW7OaUAB7tJkikQNmyki++rwcsgwwGD1UO5HKZJIz2KEgWnxQsggxDcIHZqDZ3v1X" ..
	"WxsATKAoAM9cTJx9FvtWMFtIUEA2RjtskcfUZiFuZdMccEjliKnP6zcXZthkeHzhq1tPnbAuvoJnaRCUOdOk40ASOgUXbPFzeJ89" ..
	"oVSiU7Vi+k9MWSk58MCPDF9q3Da+HNC4Nk4wmIE61Hbb7EfNgzSBAJG4sVlSxPTqjvikh8BveyAyX+GG9qlIC9mTztT6ILDP9cNo" ..
	"FAT8H8Mea99OgqLO1rYup4FfPHHJ3IUgNBOCT2Q+bGn2LiG87rlc2imYD0detsC92sXskSHxg6qvlPk8dS9zzVm1VGS7OhYZDDo5" ..
	"vg/qUrlCt2cXaVqPuMi1E7/uJZkrPvUtddwmh3RTrb3a5JEYrGELLnkjDmPcte7egDqBvuDblmFcK9cEmc9Z0socfNIbsatt6OyA" ..
	"L8MvlpO1ZqHwV1mAbVSYJnUnO4vC/zIy7dLlUvh+Bgg/++IWgD6tMonDLejXCdzpVBMPNEG+ntdHBZQxvufxT/l4OOFYnzNGrIPe" ..
	"RGggRkoGz8yCQRR7p5Y9kTITMSyirMlWGIjipj8v5xACu39kVx5fn/UIiwgHyTx7Ds3ARVYYRH2u1MpQ/iTpM3hmJ7aCw59dvvCt" ..
	"2cv0Zh2wH3E/SYOl4QEZsXF8kdBS+jgnZ3ikx9bczwbiBA2HBS3pJ2u2bBBEm2JQFArj1vUMFCoSu7ydMG05dlzQShgxJOEP9DCQ" ..
	"6MabH+y/iIMhugfaUH8GT+42uktCp7ZoSR0GcBJAjBsdsKKdwzcxrqLKNHvCe7g+1r17b1BzZZS7FCKUkWHRsi5sBsvroQH5Du3T" ..
	"80Ntp3gvSj1NKZ5Yy1WzUZmP2OSO5L/1ZO2cdq1hcbKA7fsI6bpWPvV2fonx3Rb7clG5RPLInTE90YTdOm6yaM4gD58VEvIdstX4" ..
	"Xe6MlskiLNTjQEMAPzx+rokSPhP4qz4wLWGsjuBf9kbzD6/dAGzmYn+1Aoyh7pV8V4EDtUhe6cRu0S2MQlDFQ2YiEgrtPecJbVxg" ..
	"ftvgPBEHI6g8lShNvSP4I1nnt823g1EGNpTdnNQU2rbzbbs6M7YGt4yKCg5h/Bwtsq/8PiOdSJiL7nCA/dtdty7yyDgT+hoPc4kO" ..
	"4B6fMBh8qaXgtO41ypp/gBeyN4oM6lBjAOykgpLWuIMEBHvWq84qvo5V8+Ykb7qUTtmnS8cLLnjnzdIBhlc1UuxqVs/qLlBCvi1C" ..
	"Pub5I7syPI6way+CALQvWbtwuzLcYYkfpWz/K+Ujb4Eef8Usdu4+KOxGFay9bqdzxiVZLEyGgH1YO4P8qFMz/0fVajK37jxSTtVM" ..
	"dWWVIu8OKEUduxkAPP8OPBI01o1LiMv6ovTri2S0zN0YBtZi9A4c2Sxhq6+X7SIHU/nQmi1FZcCgRkKg76VAgZ4giNGpK0rX30CR" ..
	""
local PAYLOAD_P6 =
	"EjKm/ytVjqtMpxMHu13Jn4FYrpaz/zv3syGb3cgfYi4LzDAP6RnAv/NIgs9DGqzlsQ7Y4/3aH+53gP+xWChoE+XsvlP0hBUTcKvs" ..
	"1TypWCBFZG0W88+mF+PH/Amr/U6zBvHdxpmx6fDn8wnviHKkizfBodwl2/qqtD5yB7qthq1qnlbCus8B2pQZBzONJ/kJg3TA9fIZ" ..
	"6NKNn1LCRGjNe0iVfY2UJDQ7ZKcbqLn3v8y66QAHs9M2Xsnp9fsArMHeNayGqpksSP172vxEMnOekSV6XNO5HOffNWbT9yZ2x0X1" ..
	"tcuVv229W44eLl+uo9QKn0ZtLDVWlpv02rxj3gLx2zlIQylsPRLaThXI3NwdCea6hZhKO41gnYiI2uYQhM5DNKZzEJHJgMbqbl8N" ..
	"Svfoo9gN870KsrUBmjubCfrdPHtxDX/hKKpiwM/mWtV1TGzyZIJjbj//ur0z13ZSz+qK0isbaXhCjFqd+VzN7mYeOX+9YTWuXd8C" ..
	"ck1Ichny7BbWX4OkioyEoWCvfiJLA70udcJp/l8+1c9/snCZLd+yXGD33pzFTHADyqWTTWQ9XQfQkDN8guiF5xQewDoVC3NrPB84" ..
	"rMJlX36yy0LySxF/eVfOZ1LFvuE5C7qFpq28O8s6IHKPvawRvqsItXeIXgBdox7tPcq9944Wyxj9uGga5ge3QFXmrPejVyCH+1Ug" ..
	"9ucYTr+BYbRAjeGBwqfuGj/4CAssfX3Li0Qmpgm5S2RrkoejhgodQnrGO2J+WlJIXD0h8okx50+m5xcTQJ6tVg01DTsq6XgCf9WA" ..
	"5G3/ooDtMVBHX/q1Vt4RfTa7DZ6FKN4LU6Fyd5HJlkolIh8eB0MIQa6NY7xHusN5wcopHUes0E1N2rM8TL17tSKbR0VI2/4b/4Bz" ..
	"eakASOhc7drpTluBK0I/yDHuD6QiPOg8kL14dKOZXHy/2pmF/XeFsRRGksRVFDvhrLGjGpXLQPFzqrURHAyiSqiVAIewXEcarcd0" ..
	"3knqBrPK0dL29u2ThPbXb/ss3TOn/Cb/2WI+JvO74pSXf+P+vBQWUYfZga6dMIdkfzXYVEXCslNw2+XN6Vs4bbUP3xMl270Exe9R" ..
	"xHb8TblEyq16CIBuXl3E/gTCkwLtz6PnPC5b2IckMAZZ1jJpaDw99GDA1KhLa+rwMgUi/aqcVxKXAzhKr5Gy3R3sZi1k1Tdc9HjS" ..
	"HqDkXmhWClVZ4FGN+IVZNzhqqJNXf4gJON1mLGh11J5ET9GrDa3F8gCQNgEy5BZQ3bfbRhbyncv5paeooeVRIMXRBSSqA75jf1w0" ..
	"RKRW4EbdbKWi0jW9nmWwVsY6guT5Q3Te8TgdtzOfW2GHUQyqiLejzRPxSLwWvnP22fUJxbsksKsGiX1MBN/7nkSJb6Hmhf6S/cip" ..
	"mZIPq+oLYmz5VTWuTPtZpblfNqlBX4bUcGKVNaSRO9/p0gDGvZr67Vfk+2XmhlTUsFqojEuMYHCGl3rmWrS68y/2h3BMNNGMgSgn" ..
	"okL3tgTNswK4ft6ACfKAeIivcLxRiX7cTshwoFPIwrplKlyHO0y+/lTy0t3RERTOIsac09rlXQUZ7Btgw/2IhTfNxLxX8UXc6leX" ..
	"8BAAbCrIVlVWzBIRqJM9/XMxf4MUsQNJwtJqNEuORqu03XjZUQ8nNGpG+5WrMAGxkRvzelZBuyGm4mux03YVU8x6FDmQwJ6Vtkp4" ..
	"stFGzZGi0JoGbU7kTZ3E01xcqEfK54XuL2yS33FrMmuTbTPo0w5xWbvLqdDwRXBDHN7n2VveabvCok7wBUBNWLdRQUF/Z11kOEWk" ..
	"eqTYGttzFaRHbX8A47zgJxTIllQy5cqTR8UYBycJFza0jtQmvaPybhfqG25vk03y/vFvm/6DYYhL5T+71A1DibI/HWfsJKnepydx" ..
	"ASIgreV8hDwy5QyQFsEb0Eb0/VALl09cmfHlo+Cmj12PGTzzloRdeeNMHEhpp1ewQRX+U+xW9dRChsZBTTcBwUxPDqGuEqE9ThAo" ..
	"I6dIoRX6XiiXTYsJirrBWtVovqq2emtj28Bzm4uIRWiteL43tufYsUb3a7Q45hQQz1Upuxd9NImfikuSzuux1E5dkO1G+4s7MWIJ" ..
	"3ZF31awrH0axRLAy9HCDOJNp3ONWxDpkM5BHK5rrIrrB2V9HPCoMRw8b/bQmtpsPg3cKiy7hZDFoBwxl6FclJBl1kBrl8skKo0om" ..
	"ZWD6+fJybpB5jwo5k0B9ccSRNub9+Lw7jaSFVZMQUZ0bFu1Ukxq967xU40XFEYG1rshV77xKQFgC9k6NspVbZ/T2OCOdvPf01GXK" ..
	"nAE4wF72cMILNxONsz1RohNClsnScBTsDNfrS9KdeNM19/nJyNFwX9owVkZLx9vpAXIlcp4aD2sfdG8mxULKD77kHBkrWtSrqimM" ..
	"rqOp09XH2ibneZIS7Gd4I4URtp9aKDhKYo6Yms2D5TC8NWmreUVxfmXRPmY6X8pKU28Oavf+dGjh4eQOevEM1cX0SMMoNiMVbZbs" ..
	"IsMaj/kQa12xgogh8AFcd9QXYj409TK4OXQM86AsdEnPyiDlDYEi7mjVRThb+LzClPMdRGHKk4c4r0ZNS7Yv0/YYkOXWu0ZeDpMf" ..
	"VpGdErhUFQJr4kO8+IlcizB0k45doTVY3zCZzl8W0TMpf510rhVwDL0ULo8Dmmyb+0gRbTsqzbGaDch+CMjgENn8Z752m+gooOGF" ..
	"MDE7IWRARQydzT5laqRGx5k8vV4s+sS1TbbG2R+B5wnT/fy7HzMUDVVcRAcxVJarorYTh6U50Viw7acTfwA+1sCn6PryZxFmg6cE" ..
	"ceYT2UjNYN5wYM0LeDRAWlv+HqxMtb6LIKezrPWX/BZtc0tA9do8G5lqlHQ35ySrM/QnYLNKxXdxqIWLCsnirDzEXZY6kYz4nw5V" ..
	"M87iwHbwfNv/JPHcWo9U6qFwJys1eZpS+ez3DFmQjuP8uMuC9NzcSgW7flqfG6VoAJCHd8bvQKi8NVf46oZXpX54xE0X3ACeQKsj" ..
	"WjqVvSV1A1Q/lFtr3BLnozq1b6UDo3Yh7pem3gDnOmMeUpffyu9VkKWKjsF4fMqRdAc8sbZTIb4rPFJbCm6A1ui8YASl3WFnS+at" ..
	"/hMLJqfBI/DCshKPo+kuZ6PuYjZOINzU46Q0TatiJ+Zhn7jJSYIUJKg1617hBrMdtOmsUu0+rFPWPIJc72ci1OXuT9/eYp5O1AH3" ..
	"BmQl6Fx80wqMq/ZQd1x8bNTD56NdT2LmclR1gYUfwUSfAoks6Eum3is0YKOI9ZgduKm1NYuzag0A0bl43/U5nB66/foEYWK6ZD1x" ..
	"qdLfPYEt2Zsuw9sV1+ORbnletk6YtS13XDW27dEn3CvDA7fB3KwVEm4TZpbbGh1j8jkRH+P2SROJ2YMJkX8Ivc/C/axzdAJG43Zi" ..
	"AmTH5h4Hm0qBKO1F12xMf82UNo4QdjLNjMp4tAkVhe9q+Ga09tbvm/xEAUfg4T+J37DYtx6e/c6rybyvLiKbkeyhLPflblQE2fLW" ..
	"UePi2MKFOCW9+mWY7pko8XLZ0Mmgxsga27bvYpW7xeXcV2mnHmjrcBKsyN2nCqB94vR2xAlbb8YUwYzUSF9ZYVLTCHpZssOY9oqk" ..
	"jW1L9Rjj396RbCU/Obe9vkVxVBfkyPjwjLxFukJjp4KfwJrOeytzp3AaGZxJrswFUj0hq+PX6zhYX1ZJmAey6tT0QCsXT3VGmGtE" ..
	"W5T82SyG3IVsrxR66+U1L1nbUWBDbX4ImtBb+nelIECsGd0OlsIEDHKetzRlHSgYMSsJglVbGVH9hCB8k3Pe1P2th1zysWqffbZ0" ..
	"WViI8eSFtUXKEBVnzzvcDXZhSxdQgP6UnaGgb4p+Lh72TIl4E8ZOqajhyhuygVokFeHt8pTI8DpqUKyMsWoEOhRO8070qXaugP9w" ..
	"t+8x5yBO4eZRCGE/mQA+nDM7evzfgku+4jM43A384dk7Ufi2JcuydCtr6guoK/LtXwRJk8ni92vyXN8Sx8pC3sTdHu2ikPO8DlM8" ..
	"mhXGGdl0aQIxy5Og3TWPxkQJiXbTPyCK/N8l0SLD3lXahns5DteJoMBsAl3Al7TowIea80u0OBqnwL3x8boZXuO0a2OYlx8EkzGL" ..
	"m2yhLsQE62o2NZeVVRamBh2cTenF4Avo9UvyWBGR5Y7H9B7yHJ31MbXHLFFdyDrWhCf1xrUmI5c0fXog0K++qNDFJjZMaCN6WLl4" ..
	"tLgCoEXfFGX3da5+/PAweDGQZxqk3xQIKfGoOyH8fHQ+71KZMlCf37cWEWwAXkwNm1VkSQkrJPX4vrw+7TkzP//ps8PzQscNnCM6" ..
	"RupHWl0tlUDZxz3nwkljx6feJ1wCnnT9STaqJC+NC7D7tM/8Ft1jjBdMZTUXEjolZoFH9OY09h3fo5wdwfw3q8eUvzbWbDWKaMbk" ..
	"JNQ577HNh6+6D0pbagzPJX5MZ8hiACDpoljNwkT4weM52GV/ZRldmUPQET56ytevzdQE1hOSznUxkJ5G2F1RMjyJUqpQ1J1LHcYz" ..
	"xrSM1F3Ez/bJCYRU3jhOHs3JfUG80aqYBTCTmq/HhcqG73CCAe9qfxogj0bPI+at3DA0Z4vwefubuqFQxRmetWBC1dddpRkgfUdi" ..
	"UHFUf+KgktRD6etGmm9jYfWnuzkN5Pxifaj3KKA9QHCn5NSUGAP/tuTiOILmu8ek8fcgvgin52EnisUgDWaN6VkcCAZZWJxcMNc3" ..
	"Bx5aSqBsbNQ+2r/7XPffjTv/nHvTGoWh5iqcm2JDTnVREvJLUKYsqYtdUcuPA9LEoE7Hv3nmh+xyL3c9sEZvkfiUKjXgxEj3aC7P" ..
	"kaydd3sa3ZhmFSiuSyfJQAPp26Dkpq399xGUpe1uLd7VILl06Cg6DhG5RBg2Hp0LV4Z40dO76ulSaA9MvBu7/cUi8EgX1rF9c4Vx" ..
	"6acgS8oF9yUVMeLNy9HFvTbtKGcVxtELrWynnVjrm0pg5SQOOux9m9hbpr5UwSEbQWvmP8wHMzbWdnaDhDKvCiannu16/gMpxZsy" ..
	"NW+p8LAFJ4zxBXIzu4XeNl31KX+PHy7zhOwl1WcBXdBQJ2inxmsGwqMp1CCUuv+srZeD2j3YIQ+/6UbEkrcxewIJkxxxGu63k9JV" ..
	"IQPO+ucwD7yJOIxFkx11wBnVK+XMiUpUEM/DN5gxqPn86K9sFCJ7XB+2p+Sr53kxj7mGyfxjdnHJzlOUomhTdWgRVo4yr6Dlfmil" ..
	"7drs2PlCgWjPhEjjrJKo5mr9z4T28OO95xXr4q3132vxZ/A+IDLyeSmQogxT6mjvnV+r2Gt9XB5LawBmrxtg1hLJ8qfjQo+zNR9f" ..
	"/BgDFHWjApAshmJL5RT5hyBZsu5fxnRHmjrTul4H5iOah2qceMIIw8+LbMdLtSW8P10yz3m2gcP6c0SfeObpTOhlHRUYM+BItcqJ" ..
	"X+AX4SZ+zgHrB85oLBJI2/PFhUgl7N0fGJ3KuineksHDhZKbs8o3a6QypL2v+wKzNE3PDBS7/4dmBTu4Th9z1TUFHxffEOwLZC6G" ..
	"Be5fOuf2aU8L5+JIY/+6G2DeC3PKZruxVPPG0eMyxCdwKkW9BoHOfBET53uvr75uhgYJIIGfW9+unbkwQcR9ggwBegcwnR1881NG" ..
	"2b0nla9XNGu4uFRhCpkXVYdIhapfL7hRl1pZsQE4xdZrsGfxf/IYma7IU3r/lP1DxvDTyNBneQSkW22ZpVYuYCxSkfkQ/zgP+IrH" ..
	"iN+6g4NTX/bGWZYpDiK1IeAkE49QGc+q/0iF2FdqodrtbV0CIWYXP1e79QzdNzmdJzep43V1OaGA4afRIvnYpqltYucQ+ep8oegB" ..
	"Fkze/HzAxoLY0FYl7susu5rnjyMFGwwU9D5d14ywI+hgOiMxxN7kAi/NVjTzJHgGTN0Ncn9N3dsoFXN3kH+DzaGG19SryNARAVGw" ..
	"94PS2xU9zQcOP8WWvPHIB1djWMrgvQYFlSHbNY3nwswd4uaO7Exa5X2UoPT3mSQrFK2uY97uvOzG0k0OJ1DPkZqsuE/yaA5qS8iU" ..
	""
local PAYLOAD_P7 =
	"iIPlPP7NUtxQ27NTS3iXYhB8y6GrG5jpnHfj5Hc0xxp/tItT7kWkw8ujgNHPL7KN2Z/T6oMDv7Lendb/mkCpnXzh8SN854Fm1eeZ" ..
	"IdUTzvAI1EEYgUKfmqevJ8WtyAInWtoFkJ+/GZ7hgXHlMTWAUQnf/eKrHTAH5Y2fxddohqwo77sO5H+9SMOSvSMH5x6dPBhCQRGR" ..
	"B0LEcMyh61JbiShNl4ejVwlhHQy6ylX5SGQnrXqgtsr7PkqjFV4e/T+2aPadtOOw3wFExYYjE3oxdH2et5eSZjnGUyQnFlqIECd9" ..
	"leJKlQmVJJJavKGt3I0IuIs2TJMdGv0YutqdpszzbRYzxFWrGL4vqlf1Y5+sYQWvMpYdEXYgd+IrT0iysj9CG8SrmJ7X21GrXJA6" ..
	"H3uZRQTJvIR38tbXAjOtRT0MOG0KGtNYnDUam36cZ1mGlZm/5ZzQcDUWfdBW4Eb4dXFNzrIkRaH8i4aG4NsKHvQBxTR9JU4ZOL0m" ..
	"2UEtFo8kCYd41hXUks7BiLJLIlZHoXT9aNfq5KTy77SXAEJ5sPyvRrpFxBBBYmoOYYexV7qgA/rxb8TOHW1qJjZtxypJkM4+34jR" ..
	"unDIQZQ2GpebCG/Yuv/MaqFHIppo5E93S1oXaanYsAdNTaUPTj0NNpj9dZHRIp8YbHZBidXcfBHYZ6rlOv564pfrA4rrPdnpaufv" ..
	"L0eU6oURNlG+qAGl0sSB0QAYu7XNg8Z1bSso/moo6NfYWsvuKoKgbkSsD6T4AVRRaBUCLlRLv0W+XbuxlVgJJ++An7MqxPTuedfE" ..
	"U8Am2IXrAVZdumsYR+HExkDlaQAHKSySy50Hil9NyqQBNSy0lvjUB+xomS/+Rl/pGJB80lWcmGuGpVXZSo0r+PykimPPjqWhWkbX" ..
	"27SVyGb7qxJJ+3qJ3iaNvjsQ9zjo5Umtk3sfJhKvjtRKxfJbB2reGoehYMuvI/L2TTNKJX7TNd26HGOQWzGiipHblu7RRfCqPEp3" ..
	"f+Mjs5018VnobviKdmue8xxGcrlPwGv60aTtd+Cn3Oez2YgjjNf1jZzOWHmQxBC8gxanQnH6kUs4nKbJd2R4HXDkpvUPAOEPt9TD" ..
	"JG2vj4pVWPL7Afd2Xt43zKeawjeE5mod90xLJ0VMLq+L4iBlaE53vHvNfW8uzM6dqujsd4rl+CZhk3iPlMnyHcV1BW+a1zseKMAU" ..
	"u5eczgUdRzcxnPCpKMxumbMkjScjBz6xZruwKmMPFhN1tm9unAIPHseB36O8ImC1PObJAIgU8BT9+C5qTcPGZN4NgMx8ns+djHuk" ..
	"4dZ2xY4MB/A7RUtoTaxd4X5rDcAJ4y6CbY+UnqHmtpkQ3MX/RAlyuT7Z3A+tJc3YQcc8SnKHyv0QxizfCWP6wIFL4Ny3HQvHNPHu" ..
	"pjZhQ8iKv4oyUlPUzqUCmGYnNeV14jZ10x7PZegG2XDoEq6Pu7BDC3TWUf+mRkQ21mTFu4iLr5Pgg1povsRF5R1xRpFPB2dSkBXH" ..
	"Du5zeR6cmOt8WWan08SniPABEibSPCXsugHCVw6qxzxa/mB1/5jIswpnE8Pr57dv9OFGzi9AeBgChqsFEssIQ3YVNScAUx7FyXQq" ..
	"xu0zHdFcP9VOKVKBXZm1tg1BiBgST367LkKf6Jr3wchzJiYQGjpWjzFm7kdr8L3kYueFOfE9G6F5uCfHZb0WVZfpwhWAIIsiB5cP" ..
	"i8DqnXI1OHyjl2jOgS4dRc1s7iQ/fHFNl7pV6aWIZvWHuUrSscZnuc9isl73SOM30eO29NQuEM21zdTuifH9/tkN7+3aBKh+qrxv" ..
	"XY7WadRKJh/F25b677R6JoEAl22lRLfG16wqaSqK2DQt5bZ9bdGnr0N1C014aDjRtrT9rRFER+lQOIXNzDHblPNF2M3rE4zkoulS" ..
	"YxWWFUoE2eDNyEd+x+bEKmNGGJjAvCdpxKuI8BkF34keYYr+gjV33L+ZdI4kSrVWMfypAdN7IOCKkwYSZO+yf9DoR+/GciP5QxBQ" ..
	"z7GBoovuo4xkfTv287sDs+cJ+qOShTS15RFnOuOgHBLKdoXmzxvwT68L26mVu+EvVhd6Uwks0GwXqsX5BCvRqaV9HPC4mt/cH8Tl" ..
	"ZFpySwHQ4e2+WiCJsJ4lLcBk6LQlBl7Aidb/GJL/7sSGdIBsOux5iQ+bbzHAgHDWYSvyEBur+1RWGkVf62YYJf7Wx6ddJMqebm7E" ..
	"ZbA41GUTJF/LFIBSQYTxTjMMBdtWtLWEJr0LlQhtfeXCpIkJx4gvnEdGpqKOTVOvtj0/m5Lz/hXe/ze1VAk0tcHG3qj1zrD308aG" ..
	"+0nZbAj2+dOQANS86n4CS+Szaspe532wml3KKrkWFyTfsD652FgiGP56k5a1HZ1IdHDZk9as9wfL//GfOeYI4g3ISe1LRv457JLi" ..
	"CSvNbLCqXSjEkvGNkRiJQKY+hAgiK1LibKXN4m8EyA3hnswq3EyYfyNj/tnT4PKDRQB/7aG7qCrZ3YANYs1pEe3UeugDVD53uVy2" ..
	"V2amAakx6A0jqHWZO1cgA1UgDIhWX5EpNI0cVEHRRXmrRC9yHx4TL6kBgm9c0E1xeIvHoXVyoAFUB94o5ec/+lRyT4vsjL1aQ0LB" ..
	"3mPJe6uv0svk9jzdzAwSqblCEcBHI9r8POP9btXRRf2fiOMD4YBNAp8PO6BNlPVmXONtaPtQhXbrkD1//Ey4mV3xUhC9t/XPLs2m" ..
	"yq9qnUOWrgDnzQDwG4SbCrT9VdulW9ZifAZWOv0SirPFqfmehyY1TdTKlMwLtHJyYhdrE/M/VLMRMBH0p1/UXa2hmUsDu6GDdOd4" ..
	"6ACWDH1u2S5LZo/ZXuF7VB0Viyej5HH51zcX3OuVubm0PcrQHhoCwQj/xrmC4HW0T65PkRzAVsQlt9xl6j7nTi3PQ1Qy13AwrDK8" ..
	"NqWA2CYIWFYj5Rwhz/9EqOHvV7i4HL2EbX9POuB/MxDqXbWGFhMKDEwAjmshPg1HH7Mi0r95kfzTPFPXNjNW31BlRxD+6x+RPZyi" ..
	"61AS73JmmeZUD98x9ee2yYCIcx6IqC1HBb2GH4zbo3Pcbg7JYVjyz1DkExkjRy8DUoESGIpXoE4AP0/HYVyaYu+g7LC0FfvnjNAJ" ..
	"T04FqzFLHa9/70jAG5txs9knGgRRQMQPRlzIzsrxvHVlFvOKatXm9fGf+rQeLna3e8iUM6UJMpxLwEl0rtez9zWMeVE+/M3aFpZd" ..
	"VNtjMX/e1fEYUT77BgV5S0pOIznSNfmcy3tJWr8CCW4pUWpZkHhlWcThBeB+OIEuYUZ8g/+tPTDaxiis+gl0Tfrh4RykdYev5GX8" ..
	"zVctMllKJOL0w+APsiUG5x0xj0AtDsHLB0mC1cBUD61avsL1OIX923asc71xOSJHNoO6X6qv37KtLC+4sMa7tV9vud/rS1F7Lxlr" ..
	"+0J+179bAcPGd+/5wZZ0NSDrbq0T0b9xL5hQRnolR38el02d3Bz3jzZukcjAXCgijGi/AIIg7SRTi4uD4CrgjuLeWY3l/k6j6s/g" ..
	"FyWwHInLfhGIuRW0/AQt1UdDuPuDlQgEowgsR++xAihm9Rlqis380Y4peGzy2GkTqP2+YgzP5/9oRNSWoCfrKxoVdmU1Tnxegzwt" ..
	"IyLPPGXw8GhbcD/fVj1iyLNbXVVjsDYTA30VZeLmJn69wlXU7SbgkA2svEFthbK1chhmjLu3troMDUnB+pywOAkkxVGTmQR1ONQM" ..
	"VSjySlT6L9extPuDS80sfZzT5zY90ANrKqmAZ4coew989QJv/THI/f4LYY9k8Wb9HQj6zVvigoyg/KlUMnsMIP/qK4/HxaiB4Pvh" ..
	"IbCiAJENsfALm2C2ZCVpOMmEbOwCgvEWmJ7RkejrMVmNRIvWYV9L6pongMenf7EV5LyfbBJoIGOxQN/B7m4lZyBoh+Yu7XEMVEiT" ..
	"S4JOLu9LP+LE0uN4rIVmCCgIRF0tREf//iUUI2JcHLTP/q/8e6JCQ8gFumEbbJEbgh+QKEn5VufduhhhlWExYAynpPITpyeDtCm0" ..
	"CMOfLLsoFj/zw5Sb1H+M7vko9YXGWy/GFryfLvS0XclZgPSWZf4gYtOi1OBlpsLCkDVlpwARgInrQ0yX4Xh4pFRd7MIgtWofDW6z" ..
	"30r+PhFt8iB7qeROIWqRh8WJ00+67fiHcAG+10RaBmfx99fwtKKc73Joz2lZscDYk5HRBNLkvpv1lDocf4yRtSb45neF+sbnVGbK" ..
	"I3s6wgngtsGmc3VdgAN0hoFaArOLjwHot/3yC+4aJg75bkQ0ioKAfvETXTI09QK/1xewfXDK/Bx7+Yk8d/w398r8edYfGbQA+gQc" ..
	"wdT8pisV77UL5VJiUsSgRF1XOQsz4yWf9F7Ot9RFJLUPtgs+PzxeXa9OiuhdsEEL81a2RY5UeBPeBSK63h/H3btuFBHxIcwB7ABA" ..
	"qPB72gwTkPg2IxLYrw/thb0RCTkgJlMjFmyKiyUeFQMRI6LwpsPUGcHjTTO3HPhdpBve58QmC7eoSAYjYmOh+HEPTs73SYd17tme" ..
	"7lD4im3LwvZOpqg/IeosOTNF7REnmflSzBdmTjMLNC33iJFRSoClnunmFuZR1fWDW22/ZHSIcx6rYp30EN4no5yfVUAe1gtg2rob" ..
	"h2+owViqFB/y8ySeOuDy8VuxH5t15NYATomhXrx4lUrdX8yNj+Y4XOq3YYdp6qy8+4Ue3DsWv5wuMoAFrwnpiTA2RLiE0s7E9gDg" ..
	"a4Ex+HeBKbHrUq0wbawbjMS+St+pixYLhQGSC920eBPUKhCKo7j+z8OSVUZ0UN6JMJebl/+mRx1Z/PAIl5ZsxVtA+kqyJnX793Cf" ..
	"+IAJIYVl87TOQauvvxdnvx8IDoCRvJtoKNHL5FH+M7TqeRwvXuzjDQuTazM7ISAE6PmGO46ulhMaknaUJl12rskRWWq7DkfW1Il5" ..
	"fW3z980rLShf4kppWsM7NLwjqIp/Jvtd/AjYSBV/VBaW6urjfKO26+rxtULI8R/mHLuHX1lNcuoLAEFjDmFf0kmfbx8ye2pkx2dM" ..
	"FmSZ1UFY+1RgmvA7Wm5RxomBMkgCBbMWxx/0J4Nkrz05XEnMjbsvsgVWhFkM2BaPBu/DZyzma2PNwBMqVVjaCVHASqrBpQuNIhIf" ..
	"nT/AJNcjZr6FtN4TCkQSCkNcS9XmyJtEQZ5j/coevcrUHENtRG4TTokmxTDfyhqQE01/ERqbgUBSRovCGiwXmu5lkoJLT++mf469" ..
	"hktvf9JvPar9WLkjnYepH1Idoyb7uX72JdeEWGL7f0yDhim12dw47x9clMLvotperHjF9Cf4mp9Q5MmKQur8e9xmChuDf04Wx0nv" ..
	"f3ZvV6T1HhpVoEB1+UPzRd3HhRCHyzN9SlL0uwUYub4lHEZtnEq4akCNfcik6KTmcZZkeVo7M2Qvq4PdgBITfaatT4vvLwaaPKnr" ..
	"OffMhJIZyD7eain+W18/Hsc3hu0wd1yukZmGvE6Iub+2LkhmXi44/ieqOIL02n1DNxW4nHdhGgPPMitHKwdeEyOJEFEspWq7Qfly" ..
	"6sa4w10mzIEHrzVCROuDvrTa54I6pyHvO2/peI3sJUH5rikHuzj9BC3vKrViqjkgjnTP+WpbYE7gAduNXvOaD4RNrvu2ZRTeiZsj" ..
	"4iJAVbPDmp7Ap6f9uL9A3sD2sB4OOQdz0q7Hp28c4nQJvjmFCMrWnK3QSsZmOhCLb6sgAqfHmsGqMQsua/oSRVVKjRANKDUY4IAo" ..
	"KkpeR5NOyKgtl8/HVXMD+z+BDuxsYLpLcYr4P36uKz7U9hfpn+9ocO1aRXlUBX5cJl6CcJvtOkHVNRB8vqJ4EXpPiJJzkt/Lq2HC" ..
	"x4F+mNrnCClIDj0F6FGfPptUI3Fr7CO5ubX4EAGe5SiOopqk+2cMpL/nm6i7BIzzyRRTdKdKPxA+F+NTabMGQMY95khifSHvfmio" ..
	"tz1IkR9kmDNj52KVJ4D9YCvsayOcEC6SZTUSiq7ufJRAnyr6D2pg+QyfQhpgpiuAnhJd3KQJH6pR3jBybw6QvRBuUQl3M0B8fH+M" ..
	""
local PAYLOAD_P8 =
	"OEIt+UhvFwxEkFQ1QSMOt344rf3XEB2yqf+rP4qh1HOTGeFl5U9kdOz0ecmPmXzSS7okQgJvjNMQBV3RQIt7iAkfQdxG60zeUpKz" ..
	"Wj0lNII/lVsc9K1Yya2P+yRVIetViKl82d19+PVWfT13z97lI+3B3omgFyIkvKgEOFKUp/rKfEZUPJeokSN+j90915p70s1r2bgK" ..
	"626egy4t2yx8Aj1JX04Jez+bjUB3okJwoPW6wEzJmT/bca6YRPEC/c4f3meVcEb+2GbmvYyCP3jjezyG+yD9GXFhVg2PRF0OjjqA" ..
	"tsApR7rC6TxpAgOEQbFMKA4siUPebXrwQWTz+9kDmf0Am5aAPb2wLhMJQV8e8ZEAJZYBwigy4/Y3J3wedD9nK1bw9m1SvxdDMIeN" ..
	"wpqcJjg0pd6T2WvRYRSFD/2VIhuBEXAZQR3kQaM6pq/grMj2RUNQ0As6JEeQUEvgbjlmZdaq1Bs3Z/PkuOdBN0NZPudMuhYf4Lzt" ..
	"B4PFHG6O9ISnq2oYbzBAPXl6NzRNrP6HZGXKHmBzdsO8HcFQwRMCGyzAqLsKRw5eH3huAYp8SqvdTlORhK/pdqE6bRwaIDGjTpRl" ..
	"BCwIlQ2FPBh5XDq8UDlsvSDYxeVt58RaJIfSg+T02EmbndCqplHUC6OmBA51Y4MdF56xzzul0ccuuQtKgp2ndiZopbfl+S6SoVV9" ..
	"f4S9J0miMaadv1T3oj+lCrml3YyGQ4nwzZAW4ShDL4rrcqWWGKNwljPBlZRzx6C05v8ObkKFnimtVvUOCIuwEWOtVmO+hXQVHC2k" ..
	"ttbRWv1cYJi8TqrOCpKs9Irj/70OmOEka8YaWFkMvJzALUxfoZRhM5ZXvaGa6cJSa/PiPM8xKwbpOF8g4W3ic3tt9QWumqh8BKBM" ..
	"7r2yHJgsUH3slmHP6po43xW3jMozgxB4rsSrjN/HObOsaKq8xl8c2zIh6XAN40Z97PhWdmkJxrUL0pAhFVsjF17gIQW95OItMZaV" ..
	"eqSkvBe9DkOEQYxGxMAPvw60pe2p9qzmc1YtQLYk9kFjk3VPkel5cZhsVhARN7awTYuSqPnOizWQs2QH3CoA5rCaqxaxnSNIK5HY" ..
	"YY0ndPBZ3mW8HwJvbfaTcThKzbF6kB+SLNYvLwi21W/CO3XAs3EElZFyWAiOf6k1BizU12hQ/Pu+6ru99L9nKTMkKlmH/XSItqJL" ..
	"fppCDO93XzTONOKDYSgAodS4gfmgSOpTZEZP1TJHmVSnM88CsBSw+R1PqKVMBra2mqRZ3GE/+EK65m5r1l+ILCs2Dp1Rfl8OyUCM" ..
	"5rESshvUEkojIAWLFJFVtCDS7fis0tNVDo7DjcJ/wur5xnwNTvxl3mA4GdcFne6uJfIPMzN+A+P0KQr8zX5vboz+3b24vcZkH26G" ..
	"k/IAdIy2vlFVD8FH24hcKB9Fa0xIuPVeIuOxirTSiOY3WH32RX6y0iLn5GfHXZZ0d6s1b3uQwbQVKeYqJekC4cM0QVyHBAgQVHDk" ..
	"n2T0wUX6uflYBY+ptKqixpxbbIwOmqImKc23WBf3DyI0gVsPZNl25eKf9SLSENtcgjHuAgWvBGO8NIU4aJ10jDBy4cMnHFT8cbuo" ..
	"u0ts/o4Xc185brDdW6NcAjqv7HxdGO0pr1UOqasK3Abkqq2yer1D+VK3vem8Wq9LFJ9h/9pfsnAUQxhfjY7a0TV3QgbgQyrMoCRG" ..
	"8Sf8ibcW4VvFE0yAnzgn0W5Zg3Xswvlw1UXldAdQOW0EfltSzjkRgXd8hSAINfZAc7XAzRal+yFEQB9DRKoyxCERyIrwiyQnkt1u" ..
	"pjeLmvNk4IL0IZFnFTtW+emG/l8Unx1C7/SNBqDcul0KScXEFP4Ztma8uA/EkXreMZ72uNoFqsP+Yymi5RIcX2qBI6iWRmRilI/3" ..
	"qXUyo9ZwH9dt90fItbAETL6sEE9MPriAPdL628dTw4JKNB3+ZhsjOnHVg9LD8jajjCtauNRObEc7kTsl5Zw4pn8ibo0ODNN2phbl" ..
	"vIDYSI5JRBJkbkOfSnIrZO9lP7d/8VJkmUMtotoX+IGDgZJud34Ty4xai+spaKMhk9SPkyi+Mgw91F3w8d0fjGrRoqD3UtI42WAx" ..
	"LiQR6m6VfSBTzFJW7XzGnahF52S+28nPpOvPHjfeR8YgCtbNd0oGLW/fs8EyjagicoH6DRs15Z39/x5sKh7btju5wbnVMdtAzYGF" ..
	"1gxyOTB1tWZi7ePCD/1aa2gwfdd5m6nQ8oQ8I8Gpy7aCZ8LwBB+4GewfIof8TtSVQ0B9Vq7Dirurz4/B5rO2MUsx5ufSRwTIrjcb" ..
	"wyfh/TAwjPBj9KQ4aarybjpOdSgOnCllTRSMAeB7AXiXzyOTzgft2a7mR74WYvKu3skIcnKNNfn8Pjaip56QVNML9E0SGYFj8Hno" ..
	"O6bkvb8a/S3Iiu32G4rR5h6qm0v+8GkGL/ws96hJDRA3pJ7znyOu+A1GWM+pTF6I5+IrasnVXl8Oa8g/EJxa0qGtmgANgSQ4wraF" ..
	"yawSVEy+A8A6l3gvF+IWGIXA/fkBdfnyxsBIZWROisrAf+YbuiPHcG3aZr4yniG4q7Tgg5QOhJRX4fyjaU9sh1wHCmKaiY9dP2Cd" ..
	"GmbfimUM9YTfbziqVsW4rrHfYsnIuwD0IU6GmdKzH0b7TJvdFUft6TsJ59XqajpO/f70z+52S/zspZ87J2ZFk39WsOwd99/8XipF" ..
	"bHzWyLhRfk5c/dq6vitgitqFHu+Rw7vetTdg8MkUfy04sebm5kzJNfQ/IxgWWgzyKE4VsrtEVuHRdcYfvvPClGJu/xNnlQP93+1E" ..
	"HE6pfrpF1rRpayxMypyojrAmXWlAToAc9KjyXFcdotTcP6/p855D1FdP+fjqbEIzNkNLA21cHRYVe+JnKTe39b0CpaQJLaUyOglb" ..
	"Mq9uqnmuVAmDN7NOeV3yAiObcQR8bsVWLHLXII9Z1DX9J3hmapbo+MprKMDxsibI8/0kVghPNaN0ouJlihsCJ+VsSgCNQoqmOaDR" ..
	"gLHOJnxr30ysNzGpcZZ5Zuyle1mU1U1J3W0KV2E4dFDFAqVL8bQRfQLzURIK2IuxXpsK/y2Qwc6h8qLvQbK+sKhVIVUjGp7Xb0+j" ..
	"7pn/jT4oRP4WaAeEr0UHU88eTrMFVgSkTeAVYApSTsoFE/mMkieGkFn8K4lH8zmzJk9tQcv4n0eNQKMURR5cmvXI5lKO1XdldWta" ..
	"4oR1qI1TFoRaKHyVGT3kM6aTuiZDHAP6tEHJPl5Jhmw9AkPybIq+TATgvmb1uoe9B2uOep+xyyfPOo4bwRbm+6gN8w0OJPJHWrHs" ..
	"BcTZxd8ZoQzulpT5pYLfmINoG7KomOQ/nAT8Br6w2g+Iw0vHqvyFA/m61B+wsbZrLkxuDjz4hkm6wESqBaO/y0hm/a3khDEByrcn" ..
	"nykayyqb/miGXOvR2WU2zIBLxTUt+RnaD8OGeJd60E24+7r3l6KQ4OQ1pTTOsj0ULSV68/lRBdDM5RLKjdt43mSM8c7KasEhWup9" ..
	"gvanRTVGGzSJYv/cGPY4syYC02qaBBisU0eq3uysVV5ah7u0WXzlDyvzIvnQkub20deyYqN88W9uyQIge04DA9pmXdFvsdp0IIg2" ..
	"mZWOXtu/ooSP/7l0S/8RiuFuBqDQ7g8Mdr8xSBH15TqaUVKpbF2MjJkmNuRrfmNXe4573nddyfFeJCRGT+Nc6X7aK2fLVhwO0Gu3" ..
	"QvsBV7E/WGQlEan0m6Ezn6wS4N5dM+l1jhwjx9EMkICcymo8ujE7HbhRabnn1TpIPagj3dpqV3EZz936E/xXFxSF0+IHiO5dfecL" ..
	"P4278lTYAfYMHDJ37cfLMIb/gQecQPKKWMi+XwM9s6xqexqOye2QLlELJkjFVsDrU0eoAMR7THbpG5BywxnGkNy5pdn+kfAACCp1" ..
	"tjJTTjv5rUygS28UGabhBuPnIr8sZdrU6GXuSIyP73iUJXyh9NBNbdPLxfiQOe/VMPXWbuDfu1Mfzdx17DafIgutAHC9oKV4WRdl" ..
	"8vetnYVyjcJkHqRVpnPwTj20h5njck8OzxLnIB0HcamnNHcsr7qIifabUfna1Eur49qguFo5iI6x/K2GC7ES9J94LZelFM5Q8X7H" ..
	"VFktx/xhPouJDTIlN2KqIPmhQX1Xm82SvNTIjPJCTFYB/N5jU7iin7qEbCQ55MS5RChjTrb/iQioKmP/kAqygOdxuJmKC+XAxCzL" ..
	"vcwmqBkaa5NUSs1uTaZ5caKaHPEoaeyX5LvU63yKUKkDasiphiap/jlgn0CDZTqACUs/YpJe7hapT1Unor4CcsDSya7VBH22EEn2" ..
	"YRItsQZxU/1gfTPrLjEFjQEbNx2SJ66kM4BHNJWyVOiUnQNXyrZ6QY1MG7dn7t20Vp9tQwIN5kfPXwHX1ocYZlXcPJMphuSx074p" ..
	"dbuenb0BaYkcuzNDA6n90+W+lMt7WN5aegdBK4CYxVc/uv/C+4+lj6Yb/TMs/y61GjKhtMqA+exk6T/RELKkKWvl+UWTbI1BNihq" ..
	"HGrAoN4aW5ouaekfyEthph45oomL5DHh/4aCiMRMEMKgrtmFXXmWtMSZ8B9VrU/8ltVhOFlUMUml1q2Ymr6zp7KaITZc0AEqzFnZ" ..
	"M8/UqBVYyITWVUb5U1uZSBs9jXp4kLI5X2P2BedEEAg4sK0Nmmbvou+M2LgVA2wdTmLH4l/SE+IvjDFEQKAgxtdTDm+eJA+ZE1vN" ..
	"/7/geliCPHkRA0aHaprKF5UMdNSCwW3n02QMbZuhjd6Bo4RzoO00wyDdg88gWbZjknVI/A5LUqzkFkE9/2eKkTfk15OqVDIr/8nH" ..
	"Q7074W6i0lARW0pvkRU0zIdB0oGrycyhy9evIqTNUk5QXjl30hfryzTMBqXvxU6eZTnNRhzEbkRSb9DQWxFweKQUSv6pI216YK6M" ..
	"wZSdJq3gDLvlAxd5mvStkIFk2mbhNLYcYqGuODL8JEj3zMU4mFV4l1LyNhc3nUALS8fHo/apEuSpwX5V646cncZp5wrcCwbi2iV9" ..
	"lh37lqvAdr70/Z8OnJZTVOHDC1Vu/5Mm2JtoVMq2V70QnXPw3yxbIAQetqmmpfYI/hIUcjMVWSZa/6CScXMde7S3TBwYDTHwWGQt" ..
	"U9ZE4HrfVzKZD3r/QaNaVq0h4Vf/qoSsyZI71PJXgDjAeJHi6I5rXQZ8BzOuxiHGAlHolEbDUEVRYq/U9Fzhb6Nl2xz8Z3dRcDNT" ..
	"Z7g7A+tWM8ZPcIKa2oEmIf//OBfstx6GOdLnuy+x9w+LVZVvuoVDut56kFPwUUrcNN4xis3IVzK9KKlgTDwYRcUSJsXF9m4ndO2d" ..
	"v4/DqreFD7J046TTCQOm7gaM1bbmrcJCpPlvo/8w07xyhivm2t0ELOtgYwn4tEEi/X6YkqKEW6DvtPyg5766IaCL6ann60YV7ov5" ..
	"gNlkNZx4/HYNQErg9PFMapiPZN23hv7k7aKVogEMxpNLi58/doBeXHIxUEtjRcnZGa/b4DlSBmfi9xabVSvCHGXRmxza6jWo3JD4" ..
	"yGlngPgdWWcIcdyt2DgMju/YF5MfWc0XSX6nqyT9oDUK9Hr0hgV2QtPGLvEU/rdDJWddOfcrs1TCR9J+/n3cRcacVLZpLJvH3cmp" ..
	"Fm1KONVCCD6thL0WnfjfR3qHzxWtwuC6NHyEtMH2Xuwjm3Mou+oYcq2pqkVzVe4hnBjzsTVqQh/LQzni2zpInlyvqe+idEkDDYmO" ..
	"AQZcKO8Vdx6GjN+9HwCvkDp3adnNlomMjVTK7lXOa+1Ucst833vh65SnbY/FkEhxSV6eVSSu1OaAgE3Difzaa0QxdeY/5/xVpQ0C" ..
	"4l3yaJX5UFvsyRDOVcRH9DMQff4aCc5HAR+Fwf6SHDoYwo8QC4mXsHBXSXwBhmZ+ORiX4mzAW/4frWa6G8JBMkarZPMWFfzISSs3" ..
	"O75INzWk7FX5VfqMFl3cQRg9bsrzASHuwz6mV4ak8O8+ANAV7tOimTIQPgJNuO8/0A95U3BWv/OuKoDYTK2gDf2B6T2XsHaaX2vR" ..
	""
local PAYLOAD_P9 =
	"UYwiW4lDH+6hBYVT3CJHEU6xcNZENDWvs/j2BuH9ApIcAXAfINChx9Cu5F0N80gnpiZG0oSam5otfWl7qfg/0u287YFfwWAIlws3" ..
	"ybwQ4zqJVzgAeLc5telpLh0lfROEj+skjJPKWprWQZWOlPhjGBIOORHXTtqnTSC3yQc0PPJBM8GAc3odz7V/k55xVHiU6Wfq/ZIK" ..
	"43grXDPffRnAslfV3oNEq1mDvjWcCIlKdZb7bhcTeCkyHlPoNTKH8D719N2XakoBxldqthr93dlbto09newkRj9gFmoIa3+GTIxt" ..
	"/xiOrQrBQbhLY939X3TdyR6B0WlPT+1fFLOPgl4c5FvGmn4AJE17klHKRSgglI9aLZTd9uw55meZXtf95sABePNdLBCoNQeUt7L4" ..
	"DYUJ408wCxe0LGeuGo2RJCCv2FDMcyPiSTiaw9IuMf1qqaf+5d9HVIXwsGTRIQMLHFkAUt11i18vr9BdaUMeR2h9ftE6g0yORA9K" ..
	"i3OyLvw4vPD/ySMlHpkggCeWk1MVnpgEmhYxa7orYx3Qk7g9QTh5c0XXC8ZxeFZR4tVS/gdqNshreMz/g8zzoAqbTLYJVZ5iQo2H" ..
	"jCMpdHJcrzg45iIZpfLFKU6qHK4a0pMhUJABe28v0Vsnw8DOTmXqJKm2zQ0EMcvVieN4kV2PMzquk8pXOjmi7NYIa/aE/Q36tp+D" ..
	"XKkoGM6tyWp6OmnpBQt2/X7j7piWdLw6zofo1tNlDTZpNv3LDV+VTBsCjwfOrAZDEOPs0JIngb2ujBBStdubke/MS0ZjMFHnIiY7" ..
	"ToYklJPxPK2lpFshfN3RXZ55WYsYQ7bEHRziGKyMg0fRyMUCkhMmNfcVxuXFDfxrZe7pW0l2WaGzGAeAd1/Kcmiz3ciudFss9Zku" ..
	"/5I9kSa2iWRMRWMR8CbkJbCgUagBqgV30cRUQgOqnY4IOWXDb7n9bWHuponGiie1T6gSR8V4uIwyUkjCZPSF3q9H6cAJlSSJqwmZ" ..
	"zyjtx1c8nZhPuRbAjtdpIQPBJ/87paib1zH26qN2mEgAeZcAdmbkJVur97jtguAhh8T2P1tSwVAfbxKiKvtrn+w5weNO6YMSzEuJ" ..
	"rW13OE4Lzm15NKYc26aPWT2BvfN8FEIB28+LyjZ1/TRp+DgOE6ZM3ISiLwoC41y/d6UrGISKKvMrTtKkYgepgYmlh4+EU3jguQ3o" ..
	"ZaeyojhcQS/raXP8jEU4rPJDxF2dkcfQRT6sZIefeds44k22Vdp5kw5yDSn2SeGLEbzqIRaswXTMLsJ+s9iFlKke+/p3ot9aeeru" ..
	"01h2h3lUME9Q80PxrSKcdZdevfBj467IpmaE8bEnnfcpvGJLIM02tTkK2tFKjNoYeTgn04Sew0nSARr5SFg/D2eU2mVuwVdT9TMH" ..
	"dNgVTCZLEGSKU47e9dWSQuwPm0ayc04pwRI+W7cxIx2IiUBIdACZNde7eVAefabMfzv3RRahgREeaoBk3gkyt5zszmiu3zU1s+Nh" ..
	"e2IaZmsfaoVFzWimX2+1HsSK1lHCKHJQeyQciElWnt2GAy5x3dYdsNFHGEj6SRyCtLcTaEjnnVuTOnL2Jyyj8SDuk8Z+ve9rS0yW" ..
	"uTZjGYwOSVZVbWmpK3B4hzKdOR0xNwfnOBREj4b5swfr0vMDayvzTto8Ghi3XkRFnYlHjT4cJ39F1rlNW6q9bFWl4BsM2lTSioyI" ..
	"tqRQ/Bw+LPy3nfEn5JEaMuFyfFcreeXin07vNf1/RMT5gA0dppMZoj8ZO8IJ2uVlBoH5VoxK5Fb1obBsSRb7t4iOeNsOC7LkZezE" ..
	"/0hdXokHyJv7cZzzWLDQ8jMyVv6KBj2dVC2EqOP60MebzZUY+AIq/O3es27C14P2uWyG0Lb3tbvgTwsZm2GyAUBcdlWxE1fCrdJY" ..
	"6X+iTK1EUTjmO1bqCS4lhy0KaUz3lwsKYgoMd3frsARH7bdmK0fp9y7iGkhAoglpz0GaXWW/ZLMN+U1YigrUkSfTfhyzPUop1syN" ..
	"VoSmH2ZFp+ibLyUxjjBHCnkxmIo7Lxd10j9OkCj+klCBRYzH5haxpigxVahrwXlgU8LSOQ/BLbMmNSYStL1Pv+DqnZj1B71mKEnq" ..
	"QiY5UaKLb3DjAYxWlouSvOSFthyH13LJQav6D6Z7ubN1URFuqHOwP/cYU74gb9RNpQqH1CSOk3OasxLcCsa4BPCGZ13LNpc1Hd6s" ..
	"1fp6CPgUu5WUks6j4h8JgLdOuNofuDOQd9wCQG9NUssY94irgUwsW9MVl3+7xjbp1asVIAiKedHsLgV59Uz0flc02kFQYK+ti4NW" ..
	"OXhI9PDN3KSzfe+n1FOcJiUk9RucXLhMZknH2tS565YS9RTyK1aP8ddnF9gHS7dYyDII4q9/KiW2oKZETFk5TACf0dbQkI2SP31/" ..
	"axmJ2OTWPMJ4+lmnHPSNiF5GIy5Yv9MY4lWRZdxwPas+STiH/St8yzL3zy+2b3OdRw0jl3kEisL2HcqAo7uVG4eKs0wdgE5Hd7OU" ..
	"8KtNIr7cjK/apwlXDoZ2HsRFssZB9p5BMRjMyO6nza154r9ke1ULNkiC7f9QqsavC/TUJzrKbTJLZjvEFXSNwA29MyZ/DPXPlLgp" ..
	"Xw3w0knb4+Z/PIyyCSc4rZ0RtT2JNTgMXtKpNGDM2xJNi9o8axXnGiawI0utP5GTMJ0/pfyfzp3pE80fmiiy+WHQ7lF9r8EkFyEF" ..
	"H08Nl7sl1Srea+qYth8DBhHvDdDPCItVyaXVPzhR1kvgqoW249BvH+Pdy6iQdITCFK1X7IQBz4LthP26g0Amdo1fQQHXPhxwiakm" ..
	"7iba22zQr37KcU11jzaPuGtRbMoN/SoTnZQu3QIyHomTDklwRZr2T0rhAPVhmj5QsGeb3/9t73x/ifOfDnFzOMgri0TDvNMKQT5S" ..
	"gnUK1bB2GQIR+oUgVhBwzgzHJoEShewIL2u/iY/znwKUcpDVmv56QwyBweScNz6qZMizQuJMo+3uWMUy/6B5IkD+cJQD20ttZRkx" ..
	"b7yIKfEZgPCbvJbpL0EezEzZCwcMMLbdx5H5+8knZkc6+hf8SACmlQuslcTyeiRwUeV6tsYUF3AjguzaIs0NktDlB4Pz0ypvuqXc" ..
	"sPW2aF3ojDBOmM7wtrj2vdqo2sfLxYEf7Yqdpt3mdI73Us5Tc9/87xzJQx/XJB+mPbEoV4lqoRF4fQPkTCEeglsjgkpXewJK5rx+" ..
	"egPBxlau3JstZrgyUHHaV9ODR12hkZXjZgQalAQiE96FKblwb9z/lp9NOTUxtUbBypbS0G6X6ILJlFh7c+PqWqWda1YKaXreVUVp" ..
	"xWg1K/2rj+hYQrSOSpSM5JxnFF+SlZHYpJzzTC2PrZcqzR/zXaAYUAJskNpSg+nRXYxk9oA9j9JSKMB/TALwDhx8X5a68f3S4JsY" ..
	"s0RUnrJZzakaetDaMHOSPjnZ6fmajf5Kh9rCP4GnBnIBP71Mie7yAF6F1PSY6qSbjIKAhwx2LR8Th+lfwZVldKs/RtBeqDtLFis1" ..
	"cwvgcHUqBmp90Sq7/6imHmYlNDFFmXHAv0HXLWdbxmf6SQBBjRutg8gNUwYz7uUGPKMn/rvsd84Y+1hD3Fjd/jbd0s3l8LeaPkLs" ..
	"OFCXOjXawBIj6XfS/TxNenc7vhABq1VM1/w5sXQpAKJ+Edm5D3UTWm1UTKDtus5hAPdqbz3+WBgr3f4dzOOcIPu8KHj+KXaYUCkp" ..
	"P+fzi2NKMxDdlETTlt7yuf3+wDQCaZUkxq1dpzdIFzL3uV7ap8DyOGPOa3nGsVJUtHWlmnKGcO9CqvTd0/ZVm3PIHGyb9oKFDu2l" ..
	"vxtu5FB4QJZMeuMxilMdCj+PnfJw5J/DMYY228InvrY4OMrehUmtEWEDh2zvfouAtfwVT9JtPJSk+I2HsPz6TXlrr37GGbsbF1kl" ..
	"gNkzDWPLCW+DqRml2vgX1j8ly8DB1hCT69OBVHlH5E73RXGOrysosQy5TQx9HiOzJfhOeLQWo4o8Rpe5NqGxWoU2SWieEtYbe4K/" ..
	"O6kbE+iWfXBL4QI3xbxTpL/T0aZosX/L3kchR/GvzOMgTK3zimzK0CUMxM5KRglXTYBfR72kVM8R4Ucn7KNz1x9ZdJPQZf9cx8fv" ..
	"1a5NfFBQRvrgeKf8KL1mlE+tRkAzmISti8r0nr0i00odRWG9inzfgEioYVpyp8IB0BsUtdJQnNZpeIQBei48w/XP26yiJg/MQMux" ..
	"VgTaDumpgLSDQblHPMz6UaZ2+EYjhxGRUwKinb17FaUt+LSbPDnFj06u6bQ5c9Vpx1ES7U7pS71dDbtyWf3DF8haRCJGqHsiIc3f" ..
	"3PCdBlGiMHxpAUsJRAZGPeLoJ3WSYgltbxZbNglH752CiyBHSxua4omL0t8hd3epMWdzdvMVG2+psZAPxNv63O2CzMDnyAz00bDf" ..
	"wnkZStcG5vk1guad9KazhpnJHVYB00pOwxQiIQ0/SJDZuhTqv5yiukSgFXKIMJ73cM1Yz4lMkpZ3KiomBHF6HDcFvsVOJK0DVpDs" ..
	"IOPtl/6ljlPU5gj6zoylNZ2LnX1FlUDIK9Huaqdz6hM+QKOkFVROFeoTEQjFY8928f0eCDQaHd4VwsjN5+VfZGGBz1AMMd/PuZj+" ..
	"t8MGO/lI8HTu2EgdbNW4HX5PAvwXNFtWmQ+DSqGdIPj5EVwqPjmuMvjfgoZn7/SCsBTvCIllb8lVT0dAxdoNh/32xApzTBDe4Dfc" ..
	"EKsqtMawjOnt2lVW4jCdp98JqEuMCDIUV+xkkq6cxa9A0ewNVruLWrX8R+UqgLwvlEgmxEe1pSGynW3yXo5TEm5Mnio7NQU1/X56" ..
	"WsMbf6Kpy5G2Jm0DutiumrFltYxas2GaT173Bh3x3qzpp9tKXcIoXFUnASNfqWLNLx7MsC9DOqE9UV31KO+TfRUzbQHQ54xwlyPq" ..
	"XlnztH/WCZpGxCNsGWqizHaAthdnO/ZCC9vGLAa9ctQcq8oLQREoClfBsl4MKNWhVwNuUk8f5978NtCZIn10xImkcABjy3hnkCtD" ..
	"7UtiS4op/F0N1xCIjk/1zu3GOjCaORb4+L1W94mErNkmQ25ZKIqDtZ1oiZrB6EzvwigfoGYnYUTE0idIWQVMVS/XwE3EHX9bSOFS" ..
	"ciV0+xZ5/bQwZfWcdesR3dULjn5zVADQLYd+M1FzejYYJumw1/ZcZTHkmBidNLNsGYBhDnpNPZa06kjHzynGoZTnoRTlj8wzIizd" ..
	"cFD/93jKHZLDz5n4jXMc8pmbNVYL2yamjkK+H7Ec84othr3jG5dDfrinJQV2+kbH19Zn2hi/qTHbGiSM0nkV6Mcxk2elWDyBmvsC" ..
	"fWBZPDKWvZ9OLjissd4EjAsSzdqKcx9DNu0/4tt9gfyYzsXCUegBke2XLpzjiNok6bGOFJFmqUqN7D6yJIHbqixrlQqhyYD7iGCM" ..
	"s2hlk4MOEuuhjIwMA2VcG50WFzTNxJJBxbKGldfywWhaNqg0bfZdzNvXERWJmUPEFcgHAXMlSaJ2HHrWSnMmPcVdUUI0HR7XLTmL" ..
	"PuKXVTcZn9i/iK4EJiQAyFLW+HTCGRpR6aG1F/lcSopQDB2LEGcTyKFT2X+DeQ/S2GI3U7EX0eVxV8oePG1AZnVyqsCuYgCfC8N6" ..
	"M1AzSkCwTHlZoXWhjopHJZNqF2efAVKE2yO8LwB3n6iL13LIX57Oa4KmOiy6Dg8qzqr76wgbrmePYI6Hci1GIoAWwVbJY5QZrkzw" ..
	"Uu1EIQp3M/7l24Yv8a017TL3ocm7mqAW5/7/SZZ8k/iQh3c/V2bOb2rbqVQTdrgrgb7871Lq6VljXwbfsPv6fjCpyeemx+2pRV2V" ..
	"NzyNcotMPX09UHQMCkIW5UYVCpB8LlqSo+pH/M6dok8YCJ8cwRHfZOLpjGiErShbKFM23sL9xpmQSQN0R83gUsGsqI0IuDIFZLOA" ..
	"DxequgdmpotbP6NuGnFy2L4DjS71cmCL/XnQg1Xcs2kmVRD1djeHxHB/GQSwem+wjk4mDlLtxyK9ZH1ywYCUyODl/ebYEN7E2dBR" ..
	""
local PAYLOAD_P10 =
	"txl+tus4F6lj1fQpuWWYKPlDZJbCpmPYdIfLmNANTdz2lvMNASbF0rS+8L6b0OMRrp/HKuEI1E9n/6JniSv1f7VWLr5YadGJsqfm" ..
	"fBFHS4St6+3Hq60Gv7V2A0jfVeJky1ekdkUNYr9qijTtdvO+Q5MWIm0NJUgjRYiqWB2sMf3tANKPD1E5pWajWAIeR2xs5pzL+zO7" ..
	"/ttaaFtE3anc7yki0tXo6G207RUettlmblU26qT4dDg7GUl9I0+TFJxh5IjzHdCzyVid+YH463wWwtlrSmTZZd8qnuoRtuyJoGbp" ..
	"PzL5lS6oDGLSaNLw/ZrydVpyJe4o+UnLsSa6zvSJ3Cj0xWLtV/gPFV4HC3k86/WqIfq/Ss3osY4TIibW2Ih5i8VWZiDePV3nIZy1" ..
	"LELqzElf21RxdP/nIqSZk/v/PQFAz21PSC3Tf1M2ASUbEaRf3Hp3q4EVsGO10+vNtqvTYjYWbmObDGqMUh/Jz01GqG2zfhm8KRA7" ..
	"JUky4v+4CRTiJ4BunscFBIfINg2ZZz9txKmiAt2pnu17AOY+jWWB9NjSW2fILxpkPhkuxF71VWBPD9M9G2oeVqw45onRQjSuGuF5" ..
	"LVUAD6RUk1wpbS3am5oy/dW3DYO5F/E/M+ftuH5xqw10syBh1cM7GIkH0HW3kwmqS+it7Gwle4iXgFyqxgucHv5G3+HTmvNHxArb" ..
	"DOIYPn5fqvTzMUPNjs6fGh+VrINqCA9IDI2W4wzwlwPhBqFCAcvklOfdmXMBLgpDHDFs+kOigqG862QOsP9+5I3inueb+qsXf0lk" ..
	"xS9vT4F3wskFOxMYIJiFMXRw9DQbsvZfpLKFoa8uW9Pkj6uF0hdjyBgOxYlGIaRMn0s8t5CzIS6K6fXUyelw17rgvrUA6JuIHiZE" ..
	"EnqsUeISDjcLk3RFK6wCtyQDddrdlUq4B2+k9uGCmWnUqIQf9qTspO3aw+tkCsOPPdtzlDGRIZ0m/qmcBUE3gm05+zx08JupiMCh" ..
	"rFQTJYYo2VjQ7uizx5Dh8QsGbWlhrN38kK/BDEgi4EwCF79tW9QPY1IpJQwlXt29jAkL24xqbD8T2c31kpsvxHg7Iel5Q+K/Wo78" ..
	"f3cAUN4nDXq8ijaJYCl0UyOYJJXXxHOoLLPWtscDfru6idnu9nY7n7HoogdNmQ9NcUUCbrQyvO3s+nBcWYO4AP+d7Ujgmk/OlJrP" ..
	"hT0DIIesqnSo8BQSJ/ZxwhT+9ZwWKe7cW3oZCduu7P3sFvf4E1uesk2H70OpY4Njip655gsUK5wgcsCZYH/LSrmEnEYZa4Jl9Eyi" ..
	"Idcuh05HJqb1EJh+M67Is5KIMSlZRMR4TyD8u3Y+nH2WAACu2fOjPwlFSkMkneGlDqgA3W2RpZGLT3Xm6+c71K8Zj3eWKHVQoCFZ" ..
	"trBB5oFZYWCB31gnJs8wXdzf/R2E8ZqGsoLDjLX+sWokA7+pCCqhptq5srYAMDhJE1VeauLAmteQGJivLyUJGRuYo+DhfuAyzZzy" ..
	"hTMm/hCiOlnmsBAhASe7B9XdyPmV7d8HxXmQQ2dzmuGpkgVV0Emupsfc/ofRkhXKuD/aVI+VvzMUJ6WuqIkJg2SnJnpR+gJ7Nawr" ..
	"7CiCEvzYpmzXc5B926q5tl58oki2uD3ewNqYyuZOpCNlAtkNfWS1yAfmHA6Jik0YQHbG9HYPqXpk3khcm30N1Onc3YFkp0KA4DOu" ..
	"uZjk4E4T+a3L4urZIK6lDBfRStU8TKibmb14M+1Xkr/TS5PA9YEqYguesQ0irP1oB2LcdnCDoty2GOP6GdsgttpyE/xJJPwxJYbr" ..
	"BJmZIMvXThT99j0I6wFwmJgXDfitPYxligVhylzTbXMJD3qFOKi2ZFH12HvW3qMcJrPvjQH8RIHP5eEm3Iz6W51/6EvXYA9/2hHa" ..
	"YOIPmSDv1IaWHfkKy6mO8OYsO84nDObzfVx26VuiJeUV8swh8vfUoTMpfkqpqFnHrxgP9qgFiNSz5qHLn7KCXx/wYff3IITzxg0h" ..
	"Nn/2fNTpvoRmstOPDGodimHtz1R5D2tXQY6x4ahyxKKE" ..
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
