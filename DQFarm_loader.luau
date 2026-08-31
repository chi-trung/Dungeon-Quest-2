--[[ DQFarm Loader ]]
-- Licensed to: GNURT (1 thiet bi), Gnurt (nhieu), 1 (1 thiet bi), bakuru (nhieu)
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

-- teleport-persist: MENU tu arm queue_on_teleport (armSelfTeleport trong
-- dq_menu.luau). Loader KHONG arm nua de tranh double queue khi re-paste;
-- loader chi can luu source da giai ma ra file dqfarm_source.luau (xem tryRun)
-- de BOOT doc lai sau khi doi place (Lobby <-> Level) va chay lai menu.
local KEYS = {
	{ seed = 3686014293, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 3687611715, exp = 0, plan = 0, hwid = {} },
	{ seed = 3687127334, exp = 1788089514, plan = 1, hwid = {} },
	{ seed = 3688327715, exp = 1788742721, plan = 0, hwid = {} }
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
	"aPCVIimsKnUBWuwHGj1ZTFBjK9w6ZAr5OVMxObvGyV4bSGuJs4SgeYBTUFLCeJ/FZYoul3tkTRrqjjulf9RG+rPKOdZNWXroQDJD" ..
	"nBNZzgv2/1ir8xrI3FYJHqrWcnPWa/MPfIgDGPswvKZ9Kv+35lFmfZiU6L+P5FUnFVsxhpWxiSFioZPr9ZXOdwMsRHjwjHitsjPI" ..
	"386Yt97uWuQWCPgicAPdqG/Em4HH8IgBEJR4sEMb0DFC3w3Otfw3E/gzM7SGwo1lWCIBN2l4GUJ9w4qHzmUYUoapxkbF6AwaFOp+" ..
	"DINbglFMI0W65fx6N0tHqdOHoZwBvRg8YkAwzjn7YfZMtoyYw5wA8c9GNI0euc5txQ1GLV5OgMvCPdUml4xWgGmZnTUeGqKZI69T" ..
	"ZPdkDcTeJP6kLABQic9yKi2O5smahDqdavDtZDDXw/FM80uA4QGeCh53l6TVmJB66kZmNZhlKA3a1wfO+YLrDxIIrd5iKT4+l9no" ..
	"DEtRuAQfxV9UHQLOhaOuFVGvIEe0oiDGAr6glk3KOu7uQJIkJ1lz5LlmfG+yubQ73hyFTjtQ76aLRCKcZ8jcbNsA3fmuekBwPkGB" ..
	"gQxGcIpLpXOeXENSgwD+dnynryNcyWs/3v8clqfYH1SK6RdvL9YvmgBfU4KMKs+apNv6kM7pRp2bLhz2mAPRwxIr/IgcljLdb7qv" ..
	"dVru3Gu25sNFphNUOkGImJkg/iwzm69JCfTwce2HPHW/OlwmERl2WZMEStbi1htWab+rRjM4vPAst4HAcRMFiyDqoztOCI4PK20n" ..
	"51Bd2AFn6pus2dXasCJvMQVX0GY9MLDNScxggu+RtGBgAaRdTwu4TOl8qLbkvVprzw5VGc4z3yoRcWk2q1iOWfx0ZfsInySbrl2l" ..
	"M9JeIlW0fgfXmJVeNdpDLPAFjeSzFjAyasu5XV/kv5OFd4QxR3peLiOrXr1YKQOXsTMfEUGrvEeGrGJpMV+xPZKSI0XYIo0/tikF" ..
	"hi57kN4VmSN+bYGIflNZWH54i2affvDEi333Xd5/lkuGp2jV2KbuUKPbDPy+J8ASUEqCGcf9Snb/QcTcsrmXQoEC2vgDwvgS1/GG" ..
	"plMOr5KRsQZC2pj7xxkVbHiHZnD0uuOKxd385cSsXMdYv9b4mdolqHSPOsePx+ejDrb1/VNuN0w/bFPmNtyVVkuTwWg1dKzyNbkC" ..
	"pJUHKJOUrcmchikKXnhqjHCIrCF5lAoJ81NrEg4t8IFrqvlHsWmiAdHb/ZGBzyWHzNJl36bohdkX0xBomy1A/XKRT99Wjfs7nnQG" ..
	"groHon4BDm8k3yopHLYjb/9+7d7P4WNQxJLP5iXZw8iWabf2mhcB7oD6Qy3LPF5o/WJl7cAu1t5Q3JWPMAiIgg6u2ebuzJooa8rh" ..
	"V7qNYZSx6rFXKaPTKe2GylKce3kqUWLogH3bxeEmoQn0xnwkMbaC8fGMmT3pVJGKyH/VakDgCA8Us6JMV19t+4+D6DB5cQuWYDBx" ..
	"CKVanIWJVEpCs1MnV6Qa954nGAB7QPDd2602HPHeY+kvQoHDI7NJGeFVOjxtkAPlr5yG/vwU0hQchwPM2AA2ofFvye+D8kRIAWdP" ..
	"EhoCgk7Y/HlfYNBS2LOQioqN4PXrB/5KC0052xXgb1iI2x0nkE+TWM1B/EsXOKKR9h7u3zM3hPZBJD11tNGhtwmujW1S8tm28idH" ..
	"I+fB0FD7EURELr+gWVknkC2Do/p1DuSQjcqRciP5nWA6XY/3IkSegvTlllil1hYyEkFI6n2KAbatNemZLsO5KMcddMKsxubIoJyL" ..
	"a49VD2CFBAWHOKvxTW3zFMn4JsbH/VOX6N3KsFhdTiaqTuNdYcONWvFUFEHWy7JZVFJus3IBAW6gHE9DE2cd78Kd4ExOwwmd/Z64" ..
	"xDHXhT5/BfwgVTxkItOO7wqQ/FeN+leUPOTaIo6GfuHmPgBsB1cMM66uIIOKN2qQxOpELhL33KmIoXXN21qbUU9LrcWlKgsVjQso" ..
	"DYIkh8y3rEJUsPryjmvgWIZZePGOOCwT2ETIorfgK6t9NuBR0EEBUaexK9CfjreqHC8UX/ULjc2dCy44JZLsvGN24yw/z42GSO+V" ..
	"hdSk9fog3VFd9TIsvMng7sRpHwtZGlcVX9RSfXFb9xx+MrvRUJq55BZ7nXEGJgPvRapeFSHqmshX+O0fqbILZ3lz4I4UwN6ZmixX" ..
	"JHgyvVGGu5gtGaG1SFzNMlohj7/Pl6Io0iRQzbpF3Mxpmc8bC6WmMm+IhJdMVWnoRT8hJIhklN2UbpmOSeZe8kzxsaxEweFr9J+D" ..
	"++/G1DJ3jzvk3FSxySUsQNK39mgLat9duubEm0Vmya6ueGOIeI4JCy8Hc8qfkZQExF9lJ8eVBTyvCaXC2J0JJzHxYbSEeXfcvvW4" ..
	"xHkKQVt891OoiGjykXs/+7oMdl9VSwfOS/kaFAViO89eBlHcDoeEVIH2ic8/uZsImfXKRIytaL2ztS/L94gbvr3H6i6H77HJCPsw" ..
	"M+Hn3fDtROVD81NC4cHbUIzVt6erl2FYYjwib+wpyEfV6Ga4dIW83/tDcc8vKz8cj6S6z4jSujejymihpsA/HrI6J/qIPACsyToM" ..
	"CoNYZid4YaHZqBPJgfUzCln4ssqAyGZvcPcN6vYcq4fRiHgVmqjL6fxcBD/KCoWS20V7JOasOdT9E3QEA6sfbHqNmufz+74K6SpU" ..
	"nnp2iOgQ7zL8T1s2OqMz10EV4WwYmllcSrWyUhz+vTVD8AeyQ4dZFBgvP2N0icEGi9hM0M3RsUH5Z7VeCeLn7iKOYfcEnHQOfUAm" ..
	"cyjBxWL3BfOsk2QErfTJOEE+JL0hpwzPVFjOW4V4a/arS58wJM/bRWRSn2yMUjXMuPLu1QT3fweBQk4t9wxNFKdknpGQq+BmbR7H" ..
	"xWhQL/OnkZl/WuT46zKJB2QhooV2U1S5EICAtjar24LSLaTFJecnDEdk5vprBLvPSb2lbbAiQ2aAbjV49q1pREgLJ6Cu0bwWXqFH" ..
	"jgyc4YfW0UlOCwD8sYqTaCR6FLOtxIuiMGnx4fH9uahJDuwyQBKLBbBEXqX6F9caFsJu7UaO0hxXUpfTtRxZz9bAqQXDnp/RmPhe" ..
	"Ma5YaqZBfMmx1etSJ4jsSio1YzdbGMSvQnmH2nEMW70ySsfGu2julndcolDl8N//3JiNT7UEn1j7sU8H1Ax+vyi7gvicuVmJyVMU" ..
	"4Dwk+wXZEOF/E2d29FDDKmB1ukZyfHfSq0vpAqH1+s2Tb6/wj+U8D6678E24sVGWOWws8q5zyjElQ1sdf35lD5n/k7mnI/M5cCoJ" ..
	"c5pn+UPNkKTRPolF8vKtMc5CkC7Z7PVQzbDD16sQs/O3OpDo29BNFLZ1K+EXU+a559fPD0tojEnWMsy/d4Map4IeK9FSfXLL1mDv" ..
	"NQhqt9Z81i4nxYXhcJnOcnMM27jxSDKGDNTC+bVuZyp9LHG24+clw1sThPiTWqooVdlWSvDRLZYtJYqaN+kfJ1gh92d8Uxd+SXSa" ..
	"t5xl8JbFY9D6dO5S0oDt7X1an/IX8UFlipaogJWX7L4ww56zaFWpZJhW4TioBe5pAMMFqCfnZsZ03MrisDAXv/w1Bens07yEKTJO" ..
	"FR27WTXPgpigmyfBF7JeUD+D4Nh5PULLJnDumXoe01rSggEoFacLGLh+k68OYfDilKH7LpY5HTQJAFguukWa4H4lq+g9BGJpUAvg" ..
	"fP4iDCLvDBhDvN2kKuQtA8gws5uqa/q2UgqFsqroC995/m7lOux0TEzziXZKj8aTcuviN1p6b851XFDQ8UBMa5FuNIl02peA1Hjb" ..
	"3bhdpIchYo362QV3B/8k741P+8dHkCdisAP1+z+yzQt3oQTLS8+y2FgWXNSUjNa9plV36yMU2antRG7zb3aG4R4PxXmVP/+YGLIk" ..
	"49PSF16kYQ1m5jgT8ub0+0wIZGc14ezZ3rJj9g/CaKHGABM2MDbHXycKg3Za8rTl4nIpaFZQ7ZY7kHhyx6Xvd1oZukvZJECoA7Be" ..
	"SFj6lNQhz1HgB2vnnkDFSacbC5YDqUrdBlTlDcRGoCIF1K9nXqjmJflSH0yQ2qUZjrjRtJcb0OGkjPqTvEOOpzojVtbcoR4J5Ppe" ..
	"+V2WGmh/0jgSAhVVyoaoR0TXk36VBmdK5MHM8jUYh/FiMfnsd938sdneoShywoJ6NNrDXOJXSNPeGyCeOtbmH0NFkc2LmPgJWeX4" ..
	"Q3l5RxP0lbIOw+hje7ABW5zlKoW+e66/2/HB0fH4fpzDFRpW53zUgyyegSCv1zgMtdJrCmk3n9CtUbqNs7wuFhxuH2ACA1UQqq13" ..
	"UXQVs1c1hWMGL6xvOF4RStTlpsvqC9775degTcJ+ks+MUFzq9aZRfg93J3DhaTqbMVoAqWTd0wfs3PzRzYaCixUd3+NoCaKzKupb" ..
	"MYzp+v5W26JHlKqhZujguTZ4fosNJFSb2GgCeZyRW4KhtQ0fd70YLDwQJK53bN/dpk02H2QlHpasxloFd/ldKYjGnVbiCmT+Qh5p" ..
	"K+72B6HOA7L+qWsNbvGxOBpxiy+Z+dlIARVk9PQ4OkuKSoTl8SyXecspd4gpNxT4N4BJzu1ClVILqLjqie9bKm0yghAqaWOQG8Ch" ..
	"xIy6Zfqjhxa0QzkF5h/mEOopW5R3aKQ+KMUV9vke60taCuY0aPUkuUSdKNuYIpdGDmm9OiRtZ032IBluoXhA+MtVb1oIYjz8VF3y" ..
	"c0LCFD2KAmp01GsjPVEQVptwzeoCXxEN52beNG4ilKveyv+f3jdLxa3x9yIwWbyb81W9JjqGADU8WMm2g4xRjwnqbDwUEREyH5EB" ..
	"TblFq2qNCM8o29+Vqv/BYmKD3cOywT6DMG01ZkRfiYLc4RwXdn0/mPcrRBWed0dh3DBUJcRVz2wsL5WRgWpdRgSuI8eNuDAS5f2E" ..
	"pg1yav8jPKa/VS4nhV3aO1rjHDgxcKEtEC/8jmBF1iGJE6adb/ukHTSBSXykwytA2t6OsDr8m//UhDGOtAqSEYiVuto7deoZeuiK" ..
	"4bWPYLzbUswGTN6BoaJfn02G83qNSbZ/Vey9yIXILWOBw4m/J3EY9JRdyBKbtt46yLNtWqCSvt7ySZCT+wSJYo/mdlh3DeLcYlEo" ..
	"fYGHVtBYr2tdCriDG8nrk9djMhdI09vq8/RiCzS3D7ExFHlIaC07WKZxGiryj24XKkv2Ymx+nmSo+fwg9f/cN6BWaw/5dikSZSGE" ..
	"JWSH2KRp9wuNLq8a+B0Io/AVUAghWUlyzCBRnWX2a5pJ8s6k9tOZ6bJ4GTbmVZygq2Vx2oZ/pp7fDcrU0fklur/gqDmUTxrAe4Pr" ..
	"LIlS1r5fW1t5LcTcTGESSB/0ImUjmDauB3dY+HLI0xBUiiBNQSWPSUQqWniayo8XUN+pEw0KWHfVnsLt9Eu6Ww1K1VtiI1krXkDh" ..
	"2e2joNPLxt7yAsj+2xShUZ3msFMFR7wIQR59SdwHJPTtVw3NUhAUccY0YPgWNoBAFDyBXyUZ6JGEBMry1y7IE6RkLY9FSxeSv+Yl" ..
	"m7Sh2haLX0Ds7xtNIfIenirEi09X7h+LzZBXdU2mlNlFUab5GBGPGNGZzqPNMJe/iVIbHROr/VemY/12PAcNDpe+MnBSgQTLW1C/" ..
	"4f257PsXl7SlzfLxxPZUmgeOK4v0aPiKKhuE9+5S4R7MjQzvBEidWY6Mk/g6HC2kHCC35mfBeIBzjfLXbINFo8U/mOIKyrYReb1u" ..
	"e4fPZGmhIhzGgOD/kHzNcJkw2j83CJCI0mJIjCjoINav8yEJ/H0NAAcDenKC5SHT2DtHFdob01VZ/BXotnnNX6iJ1Osg2LwjK0nm" ..
	"pfYfaFsC0DJyrNbrXSKLFiIevrKTv/dqe1ulzdUGbZQXwL7P7iOQnvTrzOwXs8OuRVyIWxuzoJ+HIkAF6kW6kmGnbKgRpPc4tejD" ..
	"FJVqT0F4sx7Qg6ahgesVQDBhY2xfd2rOjSFnQZwBw79UKKNcf4Akqtzz9yzjnGyiQACEkNa940r3/+3vZ4P1sh8YVvwxmkFvNF8n" ..
	""
local PAYLOAD_P2 =
	"ezpYXHg5AKSex0rYURQRKLTBkbmT+E2gFKkmZMdruhtlDUIlpdhsyfLmjFvm8fefjBoAiKzJ6yx85hV8whA3niJKH8muccbH17l/" ..
	"LfDA8zI7TRjqZI6+UcPUK+TmJcXi7gdXdOv+IVl8xv2SMBNniW0xlvkvXGqo/zs7x4DorR3ZFaQoY/Ia9EPmnpOOe+he9ksflODe" ..
	"LE+9SLd9xNOs6G5CGpZP3dl2C0pMjAp9BMP23mAycnckd310Uzlm5Qw1ywbDGjs9b854UTg3OgnPAm+zCD/Q4Y1c9bkc1p7yUOH6" ..
	"I6X4LsiAvux7U67iE3Z1G+XvzH04+Kn09r4vkbDqfLdP76oJNUcNfdh/FR53KCmDO2kQ793cD+ctdVLTsk1Qaky+auGa2NG0Unu3" ..
	"Zqwy2tV7jfuysNW7z6YtC/B23vEgfKJp1wrnA6Z57h0zlKFg1ut40yRxREexsLyJt19C4Qm+0kNX/uz7hkoWg2OV1/QsJn/0bhkp" ..
	"Eg9jIPyedlZXfCRHRWxkhid8wNYu3wB0wnyFSIdlNusFFWGFkyZsBknqdOEPxNvsjAEkwp8xxjoVcpoKPsSeY6ej814gR5xBQvcW" ..
	"IJKMBge/VqJMdd17zQaD4OzRrp6nrgAV+5/zrvo+PqOgmQ98Y7N5Y1EEaalxJlSe75gBke0JToGTgmEcRDQvUJbVCxJfvrLVrPt8" ..
	"lGjPFBFmu1LBM0Hg4IS/rutIrgn453suwgkcJfB4dC31oHjMcTV03u8jsmaTezwB1kUqLS2NPR3FNWdwgsG6Tzq6/EK1ltv90U52" ..
	"orYyPOYPBCNNN2ZOHuWYIk6/2JsDTPq2ONRW7G0G6v+YTBAG1JT3Rj1ljs6k8HucDMZw1wW0cLhlNoJyC97kr3YwhhZn1G71CYav" ..
	"XDbNS4RGdERVV/7XoeOOEiKnXXzmo4s879Ct6ppn+aQwNQlpgpf/MuLHjnQmJAoILB3hZ1BiLejTYNUJ4TWAT/5lUCGRLhSYRJIJ" ..
	"bA/3vy00d9bo0U10yNuQ9laqFAznWEHCnoix80PPFarVvojAVDlydC2BofmsRYj6kb24+QxhA+k8gSwGh7smatcLfje66WiNdXNA" ..
	"d12tjUBkisREvxwaRnMr6qn5Ja9UjMRovPtqjOyI+5ZST2cJnhBBDgTR+zXQXqExOcXqIgxGPyS517pIOcasM1BEq6iWYleP2Ajz" ..
	"x89WK0SUicuHD1724kD84mPglBvVolctfsICFxJC/cwKR7vwkKhFyynJwl/Oqf5+gUaJmmHkNhwYSYmcUJgZl/QkXow7GmhvO9F/" ..
	"QxbzgTTR0rC8BHJ9xCbgD/lBiVWIUEOYvWM5t/yD//cB0vgMAOdoFMZ/greQuiYqQsdXu4dP3oSJ5ZegqU089Wngm3dS8W5ciEBo" ..
	"6humWru8ZNsfKT7DDenYIErndZX+SIgHJLDDfNikvjwJq9IR+Rar7PCY9VJ8/0L4r92e/YfHYe7Tv0qW9fyYg8BdwWujQXCHl8sN" ..
	"IDPTUzoVJtYPVqq1nQJLJUB4mZaV2cAYhE1yvyqhpBnETvu21ePm+q7HOLmAKPdXMx/8+vri2mTmIt6ZGIh2JBl1yAoFM98SUj9b" ..
	"Q0F7OXBGlDyejbGeCVa21IpA51nt1yRZGB3wYtFMy/zhbf1piVeHOHpV/9Eo1Agwvzl3dQmll0bikiFfZv1N6O0vnKzNLXtAiwQ+" ..
	"oQOSpr61lUJ5KE6oLayivqzatM9bG+FYc9dfklGDjuOwuGJZFHh5kAi6yPreQdO5CZmHNPHVEzH2tDWl158E90OEUd/dppG34KOv" ..
	"YTiDrPNLMzcEIJqJ9ecrfFFP+LmWrvsftmWvnOxTdxshTIexMJNjwRtdHYYOef6V2AyvJW4s0fwJRJ1/tp653UuKlGUtmNRrb4jE" ..
	"2cWn+eqIyw2BKvoZVB+t9i0eHJmyyjsPQ60ZGdFrTkrMEq34jPj0oXQDDBxbJVc4riQbCACQBsU3etyVmhGBbsRGyIRdjK/I+q5u" ..
	"8BZV5+KVlsI/lsb51NCRj9DYYbux9W7+HH0uUVgTjRdsIBvIrRN4BftUwQlLcezaR7lkDd2LgC8F//vvp6F9+tSMwYEihsCM1TZA" ..
	"fJDHhjANtBcbSPz+ecq5pIX6BLg0TDOxQf0Jcvh320x8/I+Saabk2Sq7InL7YCsYocDSOruibiOctM9YnxlDss8GUHCIUZKpj/+S" ..
	"W2WH4bLDsqgH3rTcmHyXN0O0GmpepJAgwb56RtSAtdJ3eJ+cOmyDenOf85Cn4QxtGa25U5wQNQhY7L1nIe7N69i5WxYYfaqEWPHr" ..
	"r1PRpV4j4cg1Zo2ADxvTE8yidaux8xsgwQYZIo8s6g+NTZGLEpUjldyMbyypjHxBmZipS983kqoq43QQIurcoKP2olSX7XKXeY+f" ..
	"0ovd6lPz2UprPpdQJ3K3YHZ3Ed5R7v+lLYMBjb3WRV6C1LM/dFW7lcQlRwC/6KKWASGtSYWKdGfskHNOuWGpw/FnQKbLZZFWQPvW" ..
	"CwugPe6DlS0WV/i6KFk+jAkJsVUfKr4wx8MhZPwIDMq9H8W9L9IQVOE08fiF+/aBKvSE6QP160q/u1L//fBhMLg4hsYn0DiMAVm3" ..
	"XQbzaYP15pF3tqu1ElnZRqFEM0wqZBAqdngbupUKo0aR4rSgKLRHO915nVEUaR6SGzDh526dIROu7gNTusNfNss0GF4YLhxyK+xP" ..
	"MwGn9v2VkYOZAVIBnNaxydcbMxcrmBcRgGlGMgA2/J59XhMlR+HcmXLLZnswyEU4fvo6sALId8A+rGZN9gv1n+Gpd1KHEWPrVm2r" ..
	"dOLrwveo/BB+sOGLC3iN3mOE4w4VdTbWqDObVHipeOxMQg1l5G2eb/nxK5ws9AISQ1MXtP5y7G3eXMmYW9fI93qc0FWxfOGz53RT" ..
	"Cy113AAT2jfCsF75ian+ulKpac8b/f2Cx3wsHxlmz7DfG+JfTF4kAuH0MrXBnstdcIokgcxUkDRL3+RhpFOA8QGzi64Pzmuv4SHn" ..
	"ApoXrV0PAVl7/oKvdrIOng6QnM6k+jXbIWd59HJPrTKo/GbuCxDW6f5gHfJrMugNmJ2UzpaAlIj/NbpASIJk8WFVvUgEAFIx2tq8" ..
	"PIxoflE89W26DxvQM3etWqL64qEhi4nmeXCrnU/3yMEcY3ug+Dbv5ig5ByDWja2lYLYZTtzXMVGSr3oGHuS9hHU0pjW9YKL1KAvo" ..
	"LMlr0K2+8ErsowQOcQW4qi5qnVdhKn7qz1LZEXTI3pGRn1KGLeumeaRJa/6IRIjS95XIf1IaQQN5mVLNWAhSvxRFBg92ebHl1boP" ..
	"E2QsDdWLyEE4T+M1h/Fr/12lVFF3mya+6/SvEAqCTb4uqfaP9q9Z89Kxzrp/Pzg89Up0pmfwNNZhoM+1qUBKtMYCiDsBLt/oIanO" ..
	"YqlHiJ0vNkkV9ly/VLTfCBm1Kuy2fp660hqiLpt50A3Yfl+jFHQ18V4dWfvPLg4dr4oQyVvCJnv32e99PrYihUxSwfZ4s8JVca8h" ..
	"SZvyaKQZ1iLDqwSe8OfWFVKPT9c4ZRR4WHnfsIa9EcvNZqPZoR9aGv++loJM8/e+bZwXzF821yIf0sjmGwW3HXcQWFFuGWye2uPJ" ..
	"5u7G8HXZXwJHKTxdxvtBhdaiDqAOO5ZoTl3KpPsEy3xH6MkJ52oLM/jejH3rRv6hbEKLHm5HAGDEtlNN61y+7wYBTVyWvQiABDpW" ..
	"IwXXvXbVia3UWpK8tjW+EWgmRQFS3w8n+ick5HafP7DVpDh3unSFATKX1ir2TYBkvTFiq9p3FwJEZH1mtacmpTqatKLzxvh3ktx7" ..
	"UgHVMLPdasRaaKINoihr2FdAM9d+3JDOkqDRy0awH32/Q8L0Vb1ajkQ9Fn5T77WM29jP0zgWa6kThHrxlm3ElwgKjyIDjkuql500" ..
	"2C7Tn+Exw2Fq6QCD/C8G1iQiGLNWR+0R86+R0nTA0YfCt7wHlCRmSS/aKYcY4B7IW1f32XSinioLlun5NeVlIYIkSAq11QOz8J2l" ..
	"ri5PF8ca40A2dhzEqkzjIfLFZBSkWSr1XY2WJrN1T0/0EeQzbI8cD6y0V38EjRya7CmugzksmtyOzlhKuO5U2rTAYqCIrzjUgl0f" ..
	"RlqO5oigz6J6tgLdtg1vRnPAocfjec51OruAhqiucLgc2HiOmtssN4o9bB/XIQwyuH1B6SsKVjdMPQfbzVoy7qfHzQl2UXC+lXeD" ..
	"m4qJqv5Y9GhfqCdR+xON0dFEo59b9NtYbFYIqeR8PcN/h+BHpua6lhjQw0Va54Kwgp/9eKmISyQYdAn69UCFTydIp7KulNxwSAGp" ..
	"Z1qujXc9TAeYordfqEsSx55Opiiz7QKBO1RyXzKuH/a1ZE7FEAqMc4y3enlvXlaW8pU3WVyuoSY2Aq3pswjhOEZ6tsIAWYgNBBtz" ..
	"HjiZ2oDlmLjZNJFDlpq3pOz24tA6qMpgPb5sXXkN/mrFO+xMX4jXU/fe+ESBfLrxGsFada9a2ZqzPxDktV+6lOoxTaBBCpGC833Y" ..
	"uUH77Jbr1s8fUD763YoUGzWcV9HNsdNGV5ba0KCEa9O4JDvl/ewZf7ueLxE0Z4U7LdQum0D+Fomxw+swMtgOOa/z9IYmiVicnblg" ..
	"jo71zQ0tOap0wxOBqIZRUqSS5nRcDvIgqnd+ciiIWQ7AbGFcPhdRrUa71MA9pgwrAqTQ9rkSqvelwlb/xb+mtnJFDhMuxggHOsN1" ..
	"OAiHUFGosNwBOKsVmajIpvsdFcN5AfTaZhgFlEXkJQ++bDDRBtnZ6/vx4wiVPheNPmZeROirAfhjBsf6UTF3mUwTgRztiBa2APCh" ..
	"wxf/tuhqZbJojZn45fjxQGFFoI3LEjQTyUj/L5aKXTKlAstE1jueUKBjfuUvAfq0RJmJWVyYBu3GInWYdOxqOMHJe4OxZXTfSiqC" ..
	"C1TFd3CVuVeIvALjHJ2ZoTF3f0SFP5rwscorUNJYKROx1QG9hikp5m+96bJS/fEc+kFShkWu9JTAEHfMPCPPKqj7UnF7YXKhNfgW" ..
	"1K2HMs5/WsePAeGpCcVzSlVHrWneSBlA2/n0M0cWXnkH5ucgprKDXStOS3Cc5Ml412vg0MQqR9pyLvsq1tUzi7X9y0psByuDncGw" ..
	"DTnyNLspvEKTCglug0X3GjP0ThhGsen8aVkz4x/GBAdYNFzbBsSPq+q0LHMIckv5tMu4eZCv0RmMXRIBaJ+tWJzySQgxMYqkOiBg" ..
	"sSNxIZA/2TN89g7YJ1k4BMsU3MLlEkoCZQQm0hXx3n+homlHlpFWu9yBIJvRafvo4yenUo+r+IEp09NYnaubVptSqJZzY8jALErL" ..
	"aLj+c7FoTvmMhmd4Kl8/JnrcNtoKOBWddiBHGbaxQDXelOzgx2CSB8gW+1+z6KUZXIKGsNO3G+GPCUxGKvIdi2gizlZHu3nXoluy" ..
	"RIZrImS7k3rcZku7DQ9jB4bLLOAeF7+Cc2CEJ6G903Ari/XMLKAnIMDmNe7b+SeoCOoq6wHiOXb4cbccFIYCPZQQEuauDW1XzrCj" ..
	"JXQ+YkkO9JZ9kFGV2Lx+re1cpIGP+ugI2g2Y3q6zLLhHHK0BCh6ljiPGPEj15xHxLbhBcHpnHGBcaeHd6vik+NdmtiRjbFBYsvrj" ..
	"jcqD7HAfhKhUXfVOirlcjZobcoF+Fcho4Az5UD2A8qcXQ5ezSc+Joz6C45HlvZ1cIgm5v+4X0r5/uxrVVrlktg/jFvHGqKuStPia" ..
	"27qNb7Wbm8D5V7YSxKpHYyd2TBGinQSxvAxIvqFSW/4TpEFv+UESnVNMPPRpkucW5CqbCh1B2EpnDiwmVFIjezoBadz3SbelRhhV" ..
	"/ZPJwxLvxpYgkFiVcz9QzhNVtZd/pjKiUkrfWvqfCxcsbLCkfzo0nDzMn0s8tIPcT8bNTdJpyv5OcsceLOtasDtPhdyG8CdYPETS" ..
	"hVxKlvYXfRyWaq4Gg0NEcoQFmIFNcmS8KLgS76S4CgRZWLG0F7cWdpblSHscsmv5t9hT75qrYbU6TkJYP4sBMQ683Wol8tPbpGgM" ..
	""
local PAYLOAD_P3 =
	"tJJefuFwtOUAoZafp2V5RnG0WN5HVRsXn5X5FMXs2Ialw9fTLIvo0Xu4c8jYNDgLUEyPB4SZGpm+0CgYgnCtvXUKVKi3TENuyPs4" ..
	"fyqhYoJn8ameOODaH9345gLVdjkfKeUI5MXz0rZmYFIrbirX1ibpHFFFlZ76n++fBt2KCORq6YaVeqkcTZ6eqpyNkSKiMAUxlx6K" ..
	"Fz9jggHvjXXqFL6YpYZFo2BYsd1RykE4tqVlDGl+FxXT/5luXz8+mD1HeCl+CZFsd1urWIYBOrJRUo3bjAnPTyqMtCNz60LY6JgC" ..
	"uA/vEbCq1Ul0eNbKup/zPIH42rlgcb+f2VDq7UjnTtZ7yISfPzEkLl2kNmjzDLvEf2yEm4oNZQMtbHFGlwIksBT8k6dVrN26X3Hg" ..
	"qFrgkDqK51SNUVoUfg2OXcWIE/nqU5WSNHiBliLV1HBgcjrXmre6SxiE0u9pNLNNKNG0AoHGGc2r4KqJsv4IwIRZuGnkISkGO1We" ..
	"3LvEEw8Uwt9XF3vHLKyPwp1ltPMF++YElcbkzH0rF1SfS3xam/irnt7bnm27ulnEu+IF3ksmgOjnP8xsMKpIfBcZdRfpHy0wOQS4" ..
	"g/vCZh2YCWphNCtXs4FkMoYdb2hNYnnVqcGSYQFviQcF+5/IHVcdGewrSnNiWVrUcZUOpDQE4r7nri+hZm9gXQKHNbkM/v5qrXW/" ..
	"kDdmQLza8FN2emAJrdmFOwvaz5cSVMbR/bFy97zp4/5OS2xkWaKuv8rP7k6rX/+FuZEudV9McM58ilfP0ZZgXLBauE963ti9nLrb" ..
	"B6cbY2Ur7syb29NI0OH7UUu3eJSMlZZNFbSY2Wu5REsy20HTJdgwBTwOn0zMJgag/XTyVeAJlPja91Le26CzZpxKZ+DapR9KC0c2" ..
	"G2aqGM7Wrp4mQlwDJt8LTs1fSKK0ZOgLeUYu0kRf15+vmLJRfkW98ihJ7my40fNIby/DohiKMBCrrVpLUjoCgWd94ln0Kuy7D2a+" ..
	"fhpo52JNXb1C2Y9OOBAE38ifnu4C3KnhzmO04tjoa9dLeCsL99waaYO8TJxVxj/qwCTUuZqFJS8uQgY3O6gTbQFrEiz0T4jeR23A" ..
	"rNNsE2w6U1c9EIFtotofMa0ECoUwKtiGDdnvJANdQhZolj3AUdlO6B0wXxHKEZA8XQ8QtH0vh7imOUPTbJzpyzM/mcUBA20V0KQV" ..
	"raZQNOzUFLmU84jiCtXUUfAYkGJVMeA0Z3NFpAvBGElDOzSHi0XFod5TEwLfnNq7EYZ0HKMBIkwH/25JWsZ75d6MiRC+n6aO3UPe" ..
	"St+IvQVoo0Ma7rBo3Ce1vjs2tbrMSb417i155emrIbyerhXo0M8XPa20yc2z0lzsGdREPg8ovHPgSiJ88wX58Us7VAykbu5wHJ/B" ..
	"xOjSdF8INvmherfjgC7yap10fFo74+vKKMWDHrwcVnWcfoNtzf1eHYWYdpg3Ltchn0JOrh4wnkcKaAxniXNBfvgKKX3QFP9lQF2S" ..
	"yedmsznrjoon9dOv1ChzQrUWn8vegUeJoW3waiAPhxDhAg1QUOPluAQZ8fcRoOU5gusEVdfIHwfmqoENleTiSzPz31Gsr2hCRLeT" ..
	"T5vET4/M1BE+PozZjr2VmGQb8aYrIzlm8CoPmuAAsji47vL4XOuqDO1TWT47MD6J8tRggIDnkEsVIBZGAaSvaIeEe6KdJjnhJ8p8" ..
	"l5iv4m9HGr95zy6Xro+kj1WyQE1V9ZNqNfMtCt98UpZ6579peVolZKLmp/MwT5V9lM3g65QS6R160BP3z5EKYS6mTMWwdPT9Po6O" ..
	"ZknOG3EFZuTlJ9V+UycQ3ieaSNOwhG8rPncFkNhnkeyQbR79nHFXXBABLWrVFbV5OqNOlga2pDlU+yIMhG7MMKveWo28Z9cis3No" ..
	"puUNoANS0qeQ+CL6xtqbHDoUqzMHtNmlM7A/Df/1WRB0lYX7AabSF+WAuAPJ1db5O4Pnttw7XUE05/aoaE9sOxESgwSIQbFqcbJ7" ..
	"clAF96/dyybi5RpDM12JVyO81eCPlz3//5QFXtvJiJ8lbk8287EzUerg37XUFQSbytkXAJYGHkgqZ7pezDxhMwtHoG4GEUKMEyKV" ..
	"ui8BsHktp+TCHSAIdo+ciVUwICNwByJWqKlWlxdr8j8LZq8foeGwgQVwURUiVhWHrjATB03imgYqqN4RV6XMQLHyBTpgHvIhfyEX" ..
	"gCFQwE2o3JWwk/ZDSU/SJaVhhZ9tUi9FYivmi0v0Q0pdpZnv4nSBZriunleSBfqk2sEIUJ7SZFL0noyAXxc3bbBgwigUZDgYWkKw" ..
	"oeAJ8oevX6oI0cqQTVsVutBiKV0u746rSfRN+I46UbJY/8CBObXU4/v/LAcxETCkDAx1fPnwmqMD3gkCDsUUMpNnAyVEtxBhzXdD" ..
	"doUHbD3x7wqNZmPUO6D0gHSoK1K+/pj9Mk0CUzouhlRImP3seDrmhsy7sUnZ4yxnlNpXw6dJzE4xL54Hq8ine+z22gwwWS4rGfgo" ..
	"twA+GNPMUBdAy1cKTXQUjG6TErk4KTZIRnWirJsKwPKLU1tyXO74mTg042OaG/Hy9ssDZ1XA8NaNyLd3RSL5f51E2yYfUjOQhDZS" ..
	"RSyLQy3lSwfbdBzc8E39CnbYiNYICA5sPvUaPkZzN3pxK6DP/+1r90DnS61YLoGGxsj+UeA4jfHLytfPqrogawERkhFjzekz/vxb" ..
	"02YcKDmgAbNiHEQdZb90jXF2nEUErBUIc+/a9sWFbWZuMWsbTDRRx3flyRkuTPz0qqY6SAPbDmwc1xVgYK80t+vGtfeXBuxGGpmI" ..
	"9+wfpAru1eFndA+w5lvqGrkb5kzwP8MPKqzMeh30qqYxA1qkB92/oSq93NJiaaQBBVy8HRRMWWg5x05hsZ8UWBH0dAk4KnOnOCZY" ..
	"FKt9a3JhAuM4dbd6a5yovlCJ7rq8a1b9B3mJ0EkOEGUT5GEcx6GSV7nzsJZTKhrJ9VxYDjYSLNv1zvfMgHqQvfVec+fLS58pTiQ/" ..
	"gJat2TM9g2FZr41v+w8VgYm1doDEK3j0RGClVk6MdUyaSHtwHpjTU+bdal3Y2XVy2DgtxfYCDXj25H4ylJECpPGQfzaKRO2HSzGV" ..
	"TCOWasunkuRkU2PU1hK0ozxS6F2IXchE3X6xUpTvRi4jkxW0WrmcYnpgiIK160XmNU9WUGP3lziERFXlfQe/Bemwtf7zEFvNHxhA" ..
	"pnGlaJs3Bsdsj1R4WhER2LdcU27RB8irq/W5FC1QSERK7dq3oRJAYBye8OAU+uQR2f8kZfMZlF0aZy3MqsUGDqySOvjU57+vT2dl" ..
	"LHpZ1N/8+i6fROV632idq4uWeqLQ1HPjaF7WI+n9I+uGV6BW2zm8DpioKqBw3CBQSmO/faGgAYNHzVb1YWHJ0gWwGOV8GV0aBb4+" ..
	"0WGGySyPnH8lpPnGkf2Gh0m471EM0qbzJhsbAG5cG54IpVN3RNaKrCYSS8XIQ0zBFJ859i72Sks66nTnER3AZeclXAmsJ2s6OHGt" ..
	"GQjZMyMwzamTI6plANWcH/Ke7UnlWhvN34EwteDmdCTH2TUv07jaSElO4mMpH4z4ll0CEX9KBSEHsqXURI7usA99+AOLT9sr0MG6" ..
	"oa0lMacTsM/ce7Qc1F7BXVnvgbSX/P60btE3e+VQgHa7mefxThmFZdcBaTiqaudqLsPsaoyojqKxxEJSPv/DZPTIyo5vLhiz0M1k" ..
	"BP3sFwQz6Tz57X4qdbQTTSODGQ2a/HvXfP6yzWTGjVXHnn3oSgH+oac9eL7X1GdnKkYl65LljqPPLTHxhIHaVoAwptxXsFPQYrU1" ..
	"DKTl75aV9DEQ/qv/fCkdfmkpZzo6/yk0+ONl8YwbuEr85kWAkKVna6EVuiFadheqTQPuQh9aIevS+1GNFqZQvdpLCk5xLLCh6VBm" ..
	"SojeWD1TYH1yBHPUSMBGF7qTz/atATVduOgMXxir7BE4iBp2muf9ebptagAdW+eTAVwA58BrrEVU09F6/BcF3vC8NZyLJ/BJCrtz" ..
	"cGZ1SM6f4QEbjzyPBf9qaTGHdMHMIu4Vokk+dQDG36DZ/JO+/CpIFFB2jaCCTc9CjrWS1bPc0yCcUBB8NozTitgn9mDBKbpmBlnP" ..
	"Gdz/rb/xNyyOxJmzsjUduHAwYePgClQAug3j/15Xw3nsQrW2w4mU4evzRSWpc0EF09n5fTgOwWlpRNbIyeeJQtDaW/Jh/iQl3dSm" ..
	"jbSq3LRJ9mAPVApC7snyiE8BpMRh7oFgyy8SizBarhRRmj4dpCWRaHphlNf9poAo2dhqqForKIDcAipx0dtFnWbTffDKz7x6HII8" ..
	"vVZz+nUAllHSjVm4GII16FCzONtevTdC+T/X6eP4FhiwBWkwA58vfqWPL3t79E2VgJjzDgfZ3BQGmFmnO7AacdK5jer2VfFh0g5c" ..
	"aUQ1RvbhTs5cxVD1RETLAKLJEVorxzHzfDq2753DOGoi3roZluwiZ8sPP+TgfhuMqj5jUpBa7hvNGZdsNOE5EifSJgmYbuEtRGn6" ..
	"aGpuzMVyrX79NPyS4U516fBGoEjYF3eYYGbebB//m5oei/icS2htOSteglX5CIh6TxMSp4yS28TWwwZaLA5QsZ3sZ0Ub4Dhgmhds" ..
	"5ArwVWAJflX/kmpAYnoYAwJLQeR55FB1SZX75TfzEipGab129i/SWp78ODiuQSDl72qRyWAI6JxIfeByTTgb23TUU/a/IXSithMu" ..
	"ZV/nqZi8mKqT8c1NR+CfGi+jUVXOoS0pc7LWuJ/VLRESJtDmhOUFgFu50Tg7fUSLxFnQQVHbIkXcFz8BFq+33xUzg7bwMt43jx4W" ..
	"oLneXxwHlbZV5m1MzBAF8+RO6HR6BCUfUBxvcflxlwCK63eQk1LUhdef87TxB3VrrWiDAfY4tZse7hdHYAc0eO7NaP4GkecARLwm" ..
	"q8vrlA6fbBJ2pCtxQah0SwBqrLzo5G4ouMKhtCTb3Ci0oA1PM/8Sb0+YniHwcIbAtDCzd1Oj2DyAoKPRPLW3pXF5CPtV3GNFx9rG" ..
	"4MCUo9eXPumGVYiLw4UttFbwFZV5eiCtpOimc7JRNYxZlIpFBGzcqyimT4LslsQ+dSc4xomWs5dOMxvSihtfkjJEokjBCh9+qVMi" ..
	"RwaPT/YxWlP7ngvSQu41izZ2qx2u3UXE9OWIKigCUXOicH0wz13h8j4GRY1hDsTIVrw2FVMTqUkPG5CseNNkBP3svuvPzDZc9LLH" ..
	"M3Chp4WsRelE4j245iuv47IUlJbyM2Sdb2D49Sn9fQfoQuLc/A6BH6iN+i6yeMMVbLI4rA6aOnUXuc85OmRWds2dkdPvK93bzT65" ..
	"a8Feql2A7xVSXZVota/wXwH7B80+9sYYLHprOhYsNyOupwyfky2U8LUeZD58ikahIZIxPzNfSIIhvaww5zrI4gbK0Z8Tq5KlNIxD" ..
	"OTczFpOmC+2CncmkMKBzGkHKXd6Xq/IKO1D7pC1N/YtmwgqthkPOY0mJ9sQpdm3PpeyDoucq62tdyQ/JdcZO+BGgq8gPBV0HNHxY" ..
	"mn85UrrBWz0aaxnQG3Uh/jgD11o2pWESV6ybR/mD01868Rt9RxgwYhB1c2AVvq+WycUbhyUgr6nPvBeFOphFmTLp5Gkx2TQN5NXF" ..
	"0ZvaEuwjiyyFJbj0WOaWhgStPUMySCR+7gRuXQxpgt/zs9UdeN4zi+lVZYY2f0psWgnFClH85Uz/jqGjVy0llOvw8wNoXTkougL7" ..
	"T/PS4zBi5pxxit7aNq5LMOnw8GxxK0gLqNx9pWFQ2/Okp0dPl7wXxcOr5hGAnwRTirFZUjC+y24M9IIJwu/dXXMSoaRzcDVB1tpn" ..
	"OIDiNuR8HcNbfY9oSX25/DQwm72GFIOLoylsyykMHmP2XYbiyRTbaznYAiCWhxdVagHaMKDVjvEdG5rZc5u0Mkwqnt8AXrjSsEM1" ..
	"Cg/8umr7M0aIgFFE8hinrTYbOekSm2hj9kRF6zAt1uxzacjv09tH4aNDbezWwm8IklF/LZJh3uEDe4mgxGW6XylmzvUCQNpWPoMv" ..
	""
local PAYLOAD_P4 =
	"riBMpac+6ntQv4pVRmYrbVnFpk9mdV7Ajuw/zdRXYlnJZmVjHYC9RGujaBbhSUltZepi2epb2RZoNbQa8q+tMx2I9N3lkoFSYRS1" ..
	"ZdZh8dYZ3+BHeJkkvLGCl/8yqOreJ41oVWulrU1V5ThalyMybT8GgK8+0u9vwgpWznfjwL+LpnlMgSrex4wWVqReDHHzksL251vf" ..
	"BIBHNGa6JO00cbfr1GGQjIu5d71tbWjkRGwam52sm6yz6BMYsf2ny7sjLKA+fq4wh40CibAzK420CPPR2ys/xHxn+T8Gq7zqfZqD" ..
	"PTH11VCqcWtYWyD1d6HcxVKorzeqPaWXKvJyLn1Q9DzJolgVF2Vv4vtQ3kURU8kB7YehKUVfRCDoC4cWBk+Mm1DHnITp4VjZxdmb" ..
	"Yc8V0WhJjS1bUS92s4wlvK7BXE0zZWXfv5lXEu2+lREvI/Tg7TW9PT8WqeHt4ScxeL48N9pZL/F38Q48OKvmrlYm+MFrvfcfaJjN" ..
	"vA86P1hW37FFpKjj/vKssEDgD67sRYrKiJZ6kF8gnQl8f27kjVUtdFUkCZmF/QPk6UIWoHgm1KPkV+NIb9mRhEML8N4OWZeKb1x/" ..
	"7LIn5gYRQXFafldsxWR73gOuYJ4XR6e6q9J+R+5WDwNdCgpH57neJfErKo7xgFL8MoIRo9DJYGOX/oYPeMIJoP4cTt29DhfKzicc" ..
	"ZEkSjtQllVm0+2/rrQtS7Jc6M6EqVW21kTqw/qq23zzsyIghyVGVgQlaS5PE0khhku2Wz6urTyDm4ur8KOyNjOQSkMgE3Nf6XcOv" ..
	"WUP0rG5oL+onDCKnrvMNi2RgF9RHJEiSsP+TEd0mVdyPaO1FgQ9Q87QomjprS5WTKwm01JjpshLosbCjs5kvngXTiHQ0msfM1i94" ..
	"es2hw24fmcD2ef0x+BQJtMw9HX4/R5tY4oPBCflDIhUNIzAGRi598LJNwLAaZutIy9ceUfi4S4x3OQPqeCvmqjjToHOKCQ5WrsWU" ..
	"+ebkM+RWvIBAJaUhEp25LS8ciIWL69qzOL/U/kwAXBuEUTjCpoeNkhcbcSidw6wLqt4MXVxiVNdiwTRP5h1UlX5unzwWCEDPtjBO" ..
	"bkRE0oJpCdOq6zESW4kIr28bpm18+rkEofuJc/5IhoZXmvEZ+zOjU4rA6e490E7k8ZLK8YyCH/Q2nQXiBTQPf0IQ3Thgzuay08fZ" ..
	"D7h414kospWZ7f2hycqJ/TpdWWmNrEUjoXKkojHeQsxcODgv8uV0PpJvmckWgAOGhWwJ7eiUB5NJvqpYGAOY13xRgvPd6HnzFQRX" ..
	"aj645EpBxwFRE8QBBphWW5eL3+vWgwi/CV6ujm2m6EohZ90YTXtOvo8ZVv0e0lBuognIcS29g1hfkljyDkKzUi3uRPLN9sq9RJYW" ..
	"t+aMV+1gMSM1qkJy2yGrHch/jESCRmXIgVmxlh9CzXaLTSlEDOxsMXysIW9blCSe5wj22ASZhcboe4b+L3S4Aj7JpeJJ6Gdvaxk6" ..
	"kT+q9omTSEpKvtwX48er+IVzrQkfmZzsNboVDxd8GO7zwRbkOfHsiwgLZ9B/pCGHoEmNqw91w9iIwsZrv6P3OrkuZwLOMRAIiFS3" ..
	"2oxqH9Ot8JsSNSgvbgMGmiTcXbgJy4gOgFCuN9tSK1jLdFuYd6GbSESvTkIpt5CDiVCxp5LHrPdcP7mzvz6vKTk98yWv+M+xkodc" ..
	"T7GCyf82A3IeTEPmNTFDjP9CajUrKNDCuZQ84Ka1furoCppAmanAJUlO5EcfBSVMrrZRQUY0OhmtYMcCdW2cYP5k+xjTzKLjHKV8" ..
	"Z5PSdOSrtU+SG7hHpcAJDHR+ocWqkpc9WVVoNqCQSE38lQvjhHy/x4C29ef7xQFTlXOXCiHlzU4IMYFk7y+CCGRvD4/onkL4DDel" ..
	"NsdKE9hXrrcY0nn7LIGxRPEMQoiMiY6DKAmu4M6mbR6ZOw2s/4pWhCoKmRtaAvm6T/5inQtIUqAZnOW3QaWUd5RlraqVGt5i8D4m" ..
	"EJjuKcDGWsRCVlpFi6PegxyAD3QvL7suVS43mwkg2Q1cQ1tjB3ICWEY+aK+pK2j4NJ63+E4GNfFQfrnG6cEA1mPbXAGqMKCcFq71" ..
	"NZ/WuGqeewJW3wAwR65guqby5NjPLqBDSgxhHMii4y0tqF53AUcz7r/J0LBAq6PbNI8wMvRAPZchS/1+c5GnAm/iRwyJc1DxLAUl" ..
	"zCP51RjHduBMoLjF0PohDuxsogyeVO4RIJpPl9jP9ppcOcR5uvgP56MQE6ZU5JAdR1Cb/GLxMz9xHgMZOxR7o1E53AWWWZqCRoEj" ..
	"NYNYzcfKdVvMA68is2T5GSgS3zd0XYiVNsNrN3Qcd2s3H7WBPM2AAbQmBosWRRED5PlbyeHWfOJ1LfaW7rmBJNhRjLLofCrislci" ..
	"cz0I9dW7mI4d+eIUIipATukB5Ll7rB8+95I1JUyo1lujuS0QyE1DUd2PvitwikcU8KaElqOX0nwMoSsjXsIJuWTy7OSJwVQOqhLY" ..
	"1k/+azkeaCfrCCwN3N26fqofkVehimrhE+dVvL6b9Rf1AUjXv8cLYvWsXt866+KV48M+qz8CdulYRI1S/Hz+bwB9MOYMpUPf2WVv" ..
	"vilUkv8hnSrJfqf//Pm+3bRLervedBzwt660YjKDYBd5NnPYJpsWKLkPlcjDrvAAy1xoTkxANiruU7/uaQlCWJd1hMye1Rv+ed4b" ..
	"8jBHJ+fFd7IuON3fLi+OauXn0d74oxjd07B7Sbaqw4TPpdR7OxW0JSYszfrlodbPMgX9PHB0Y51LU3YXmMPmdsoF99Qlk3wFZUBY" ..
	"8Nv8okNqyXvcfmaZGkLGEev9LPziRUWTT1ZU3YdOpk0cIjwcFNwA9h9ykKFLfAqMq9GQIOsHvHQzvl0o56pi7BHN6CBUwuX6p2wp" ..
	"q3TBEX/Dy/U00tu7oLmW2s+EaeNQ5fyVldRYBxl3h35IoR+FZWzN25WUXXRvm30cJTysf/+cYGiCNUjv3aAlTNWX/1AdFfRJYHs0" ..
	"K1QkdkUZkFh9buDnyKqLpiy2zaWEAePJnby/IG7hKHvWe3e5LLEt1pRBqKuPJyTiP1AT8+ULIFjPX8LgZu4vVxuQLweqQlV5cbuZ" ..
	"buOx96RZTz70XACKfjR0dvJKAIaCHvoe7s3cqKTqeIx1i9YZrc/7uvOSNomauQ3KJxSJbI1qp/1hMPnUVDZiPZIZNEb8Bdf61UCe" ..
	"e5514v4XnjdklBC+fAT8YAd9jY51AfgZfFo2o94x5iWMG/8WPn4wp2H9PjFJ9xuKtDlnVqtCbtKyA8Hh+DWA+5ukvXkwekTVHh2J" ..
	"XYkRB+yICfEFLWjc35c/j757N0s00sV2Tl/2McY0QewzmzBBpKETmGTfVMmjNbm8Uyk/kEkVmcZCrjytcuFCwkLhFWia0gaRmRci" ..
	"EYBndjcxu5+KpSVmo6KPNGMxG3VuwP8uQkj19rDTe6xRYC5UD1bOPGT7h9xSWcpeECBV9NOlbdaDI2OKFeCp76Csw0eplzb6v5X0" ..
	"bbIkh7j21Em54h5CvkG3ZOW8CCAJwviAkuRtZMPlkwb6AHZffRtkY0wzNSDHWuyUe/gqE/02ITre1hamdLw27o5odB9eEwH6xxei" ..
	"cMONji0byjTHLD5dgsQu/M52Q/5hYM0TRMfbgqNN9vO14Kz0KhNpsT3T7QWYOQVEE5X4V9U2Illywg8pI9h/iCmCvY73hynq1G12" ..
	"O/z6BtViD7MNP1/aanrel8C7IQ4N5xefEc0kDLiFVYXq/65GCscZdxn3PAzTOhuhbOXwKqrfXuCFLo6Li+Iv/Iq/WG2ExkvYv0Hl" ..
	"dMO53GrK4efMRWii1KUGKE27bRq4/M1bzri62Ed6TkgossEnjjLTsn2uEUfk7MxoPxKp5c3FSG6geNtquQB8QVlIqosBcYg7vBuL" ..
	"SouYBi+kPFJmRyX+4zcOowF8KpTWej1O/63180X6epCNccmQTVaC/++2TF8xRjxy27AdYo+gSXjXAnAdU9YZ7FX/sOylGeWtRBzB" ..
	"0NvCGyo0/w+OsuJzqgnJJ7W9+58YiuFR6WnW/zXTu3gCbAamzHyhL3O4OhBlJ7PvdzLuu8N8MnJtFn7TWekDbYY6mrqxDQhcZjul" ..
	"+WIfJLC1ljaOB1kiTsK+e0/9VEbXGgnYsNK12p88IP/aI8/sK+tlWo8uJsJGzbgVOkfGv6v865JZxba09KHqeDODCRaJ8U2divF7" ..
	"k62xJ5lMLhAfhLJlr+tAsOvYWAT0n1iOiFOchyGDvIZ+QRRob+FTTO2sp0uFZmFA+jhfyFi4FJIxecPDM6OmQUeXJA4Doyd5ByP5" ..
	"PVwhR3EihZ0yZpHPEFmppkXLaEG8f73PW7XhYjDbgNbGRz/r9ePJkNLO3cz7frPMVoxgA9sY8B+wSd99kN0jOeLz6M8IvVsBLJDL" ..
	"uw8Kc0uhP+keElkWSbWEqkK0ljoMc6RQ3bmGuBbXuOLcQG+jyeigg1+LsKi1WBbMHYd1qfF101ADmVq/IR4oPktV/SWPIpEYx+tn" ..
	"mHBMbEkgB6ssnuZ81iCUWASUnjE7s++10bhNMuX2bD+7G86COUdgBMdOHXWBNFiMsgcw5yGebuinvQXIl93ziWmq5OdzUV33Sfg4" ..
	"k6/w9PyXJTdMb0VyzLe7KI5G4U5GElEKzdgsMGb4DNfn7E5lpUjuG/nYrTYMaNz3/iWdMqf0t+QylNSgLTfZqOrV8g6yUlV1WPQm" ..
	"8OoX5vbOLbga8uLhUalgF3kMGmvrpEo9zQpjk078A7iQQbaZgo0v5he9S0ySK+Jk+UjdLtkCKGwbrGagu2C//xAT7jLJUnvaKhlG" ..
	"8KnOTrql1S0xVdbpR3vlWJ9qv+BHoAYFB9gKwsC+okUwVMTX0mdVi6YVwCfdzbJPCZCe3BrR9yQtLNEuevVyM6+PU2+9+tWKYbw8" ..
	"sT5bgkvMvHrMBHq7/+6E/YPyGldzJM6PosBrVFvi1SIrib3heVngRkZ97Jj1wD/jXYlWcvSkT2Mtub5CIG92nT6GrTaSbLpPi/3C" ..
	"2RkhSFbLMoPJhooP+NkgW5VYVio+ePZMCLTPZmn6rZUyUdzYFE7MWPYSYdTymEocys8KDS4ZAtC/ohKW+7Xj0GToXepIU0kwvCoR" ..
	"qGA4C5YoQ21r1XlCXylnDYPwN0DgAOm5P1xxwGPR26xkgrjj1PiPlr262drHa+BzzGWCk4e+l808ZzkXTlaOKfPosTSx6dprb0FR" ..
	"F2UfKwHmPgEqe2jlBujVyeKbQeA7CdGIaULbuK7szVFNEmqWCbwjEkiaOGkjfOcJ7LXb/8QeXU0RuQ1QoXGp4g4kIcWe6xS9WE0h" ..
	"I9Qv/MnulZUAFn/8K4GbDoNn5A1VQZnVYaDrxgxOhZ/4sHAaO+SI93z+wwLo8YiK9gfF+5kNO/N74ufaSzomRT0jRpBoumFxwwiG" ..
	"9FbHWSdBbhgS0mtOoOnuiZNDIO06skk2LYy7TNGc6d0gdRaBT3TQaoF+30pl57KMjX81+LhobxQzJWWRVzHW0+CECAaFqT69hYB6" ..
	"ZdaCrthpVTUe5z1PgEVqgCUF2zAvhSbYBf7htbmfnJRiZ7wjrNzUiFW5PyxV8Z0DdIwjhq2MW5StUD75TxAohdlqWwFSMWeMdRdS" ..
	"Ek/CrYKrd3I5NtZRJKQoONdbyTlvWyJiTYN5LWurWQ/d2CdOsH/pqV85d8wW9c1/Au146sPXlw/djAJWD9LXq5Ftafrl1rtMvdpL" ..
	"UsxvDtCfnWh+roVnybYvM7hxqDhe5lEuKWNySQjUG1IX60tZu9y0j668wenvFAU3I9NNdSSPpwe4+UCaMu5NnxKonXM55Q8IaEU3" ..
	"sDeLLudARSo1iGM+oDae5BOytRVfH4VjM8I57jHMuvYT09HvUv8oz0cQ1q74RQQTfNhj1I7tX4Jwhc9zxsOdwy19vA2Tzy2LSIbl" ..
	"+lCsRvEMiPr8yBAIQn7PiZEU+kbMZwqcOUIm5q60UHDF7Y463oHDGHejI1rZkng6nCOROEtaO+OuoDit3aixIDTv9OhMdVYj/iWc" ..
	""
local PAYLOAD_P5 =
	"MFFGVGtG6eThTpLhKjsnTL16MmUBeSg4+YwXKNd0EN/8+4aanPikuP5NSJrs3n9cWZl5gBS7zVPBUx94UPw+T8KPs3BJsnrVcGXb" ..
	"VsktBSAYZ6/PNLgJ0ZI3KvGkqHn9eW1/7nEHgY47JrzueCyaZGEtcAxSWoS/7If9Xvh8aSo6i64IPS5+T64wPmJwXn38q4rxMvRA" ..
	"kG8j9GUhG7OqO+M6Fb61jvBofu17ixukyloRG9SU7bzHxY//kGmgIH83DqQuBNKZLAZIdscm5TIuBpdb/z6vQi76sVcGnJIfTFnQ" ..
	"rf88gB+LNvWEm9DkyN1kUg/PMRVnCc/Dwspb6ITbq45Xq+1xhjpFXwHuisS5hSgg0Ggb9VS5UQ3kCuEZqV6wB4RpUQ59d9iHsHua" ..
	"e77dV/6IGyWFAzBKysaYS6SnK8EXeqwis1k3s6/5XGmYIiAN6+/GccckEX8mLmkoGM8mJWhYxsl2+HUw3osdxaStZe4FaofCjplG" ..
	"VVy/ikTuReBZOMJgfrweJ49gIHsbcJjv1QAlMyHUDukaclhMvgpIkLO7pws+xa2rdNMUMYjheicI1ooKDQsggqCxyXgNFJCN3SqV" ..
	"jhAAbPkHdCEjc2oZ7GcFPrL5b6i2aHiEG+RVSlzt42+G/hoabrgfUvC28II4RskE0HCDuMiMU6Z8WPa6abkNdjWoRvIBq26movmX" ..
	"yHdmkVI7vVtk8ETyTFdv5/bpPkbflEvuQoe3eS9TyQp2K3K0ubHp2w/Ge7EHNB4mc5KDWVc2xO3grCtNmZ2KrzfDJZp3FjKANpXM" ..
	"DjL8UK1R9mjaJEAf2PzWieIfWGd7aIZ3lqB6Mci7ZXSdoHY/bIiQUy2B4b+ZNGTMgOTy7Hntm+pwGNN3ksOYsRRcpJVmGlmtU3/o" ..
	"6vUTc1c4LIMum9gVx4ZFTAxbqx/XhLuZgIp43rdMCSCn6SBAdJ7GadQmv3c2V4xwcxOjW0F5H/VMVKAVBpe2IYnj79VXLo7H7Rb+" ..
	"fqitErazoH6c+6gkWbI62XUbsRU7yEqpA+VKzWcwV8fHu1515ZlHXj/KQYUgqELEoolnTT8ypLxdPquZTECMmE9suhRC0W7V5VYj" ..
	"klF1+MUUdPJKiCAfHoJzg67YNjg7fHMdxFM98YWHYK0AjjRG9Pm6Z0dhZGN+8inho9psqZrrM7lXSDcZfYRW5RF3Q0f+Daapk/IA" ..
	"Etv7FWeW/ZbQKwPHAN6AR7y0VAOruIf5Z81OmnRbgpSgKfrLrvpn89OX3ZWvxeNdpEM4Daal6yvaP0IZotNLnJkDk9JcRXXJ8CUB" ..
	"PO8cfmLJV29PQHrkZpPYMeJWVs+hRELib6q3VOKrhVGSOf8vuh3qJn6SGuMt4lt1Yjz26TZ/bAYe+Vyfa/9h3Cs2nFUuzG6HU+xq" ..
	"I8ijse6YADLTc88Q1F47nsBtCypgZ0qZqZGCWZxo1jikc+hRGwGWD5KvovQBTyHLa4s+UqWFvhCy1WIVia2M3wJF+T+d3fya7Szr" ..
	"+GQs3mCjk2PvYt/czz+nd948zvZShB2H36bYpLvnsNp871AWp0Aw1VAEetv6YQ4oQAB4XNehrQtblaUAILVpUUjdLC89q4/lPxsO" ..
	"9vg5+ps91n2FOaYx14murQe94NcVQbDW/dNpflTs0xqcC4Dky3pwOIhTJfq2XiMVCDOgxyIgZTMs659rfcfpo9t/HIYgY9d1Egjw" ..
	"9e0iDQcS5Vm0QHjLSfyz4BLxEEKVOMAhgv1DnbLIoTcWYNMCZmFTUwFhRtPqf9/Pay4do9kN2KQShh9ttOFMoWZ4WkYu+KazAh2z" ..
	"dPlzHVIUW5UFnvVNIAHMrmXrIfhxUewmdCscH47VQWGZZ4mzrP7864ZZPjt/gW5y5f4sHraua52BE1PmJanDefBPxGXqIBw50bCT" ..
	"iaK735ZG6C+oo/6pUb6vCVOvXKR8GE1S7XyFbhId7y8G1ekYwdmFs3kMRj3aoeSd8TUw4ol/7OLuhfKcfPt5aaepKumIyOcnhXhm" ..
	"82Ii8ZyE7xjwi7r2ikdJ5G47MLHmLLmBMowHA0F2a2NI2m9PB+sjFEzMl/wUn74gTGlCQ8twrYaAt37MnArDXaIYc6s+KJRVKSYU" ..
	"bJt7eHESPO+R7no2PWF0lwXeEBXVwPJ3FwDtWwpgsJ25E9nnQbIaJiR8LVO749pHaO6TQ4id5PaxqSmcl9OEj2tuZMK+xbDkW47N" ..
	"gM0yxwiVtjF64MeTeznzz/bicxhnDBMKlJCf5m+bFYc+COp8uktY+SpIhw8BpSm4uMM9I1gtJjgQLuo0SyxSf0E+/szIpFMjAhxi" ..
	"BoFhL2OHdIi+ZFpAT8dXM2NqNdRqWfcYwt9DcERivTX8bwXoImIZ7BYoL3QqDAD//TSkowqFdfl4KcasdLirWadX48xouskIMj7B" ..
	"fngDhdw7QddGCADf4SQlQm70mx8CRScxvuETlYYdP78rZXNvHZ2G7iuDQCU60xNyYUitbwxC5jZyxo0fpfhjvwpTx+owabuNl90K" ..
	"y4KDNqUI2a64Dd6Nv/3tdCsszfuDAKXNHuPtMbhGpMrqEFMzCIasCuPq//9hPyBN/JvBxF5ahDYDI39QdY7NHz2Po3RU4AK5Lqxm" ..
	"T1DYZN35nN6WaQQTFJNyLsJjVuKC6iozkuk6Ls6ExSxtoJ2WnXzqNvHzPxjbMXGlmoV0wdTNdw+PEOBJMX3mAXwRvx5fMLdKU4sb" ..
	"EFUgmPzWd0cFAtaA74bOdLUVLhN4PR1mK+FD6kIdR3oGLNUMOri89Ctnl6Td4nontMT07MyEVkcGYjVoYVfx4Eu27XdpqhEM5G/0" ..
	"ozR+azYNK+lbt5ygQGEw+6NDPYu5YLSbb34D+0TOL9xEDBHSOQ7/rhEqmlwqdUtqVLpjRSWWMwTLMC5rGg8dUaqkGBDLjPC4t+or" ..
	"SNwsdYO6x6yTGvrAZmCEoyAuLxiuD7vLQxmUabO55ZhpfKtUhv7/3AeJsVD3CyYP42Kaq/WnDohkuIo7q6a5F37KfDZnEO7EwlWQ" ..
	"Hd0EukLlr6zukMo7fJTALqPMKgFl3/Q8Iv8jx6OAlv7lP/2GLrd7220hVisrk6zirf+fjbNwvg1z++DsFC4yV7KUQHya92YuLU2Y" ..
	"pwWECjqdFiGkKWJgegUKRiaoLKXEWmSLTgebVczDVHt/W2GbHcqtQwIP3I1/S5JfGATcDhqSbl6FhlBM7SyHjn3YYDiR8WNf4Fw+" ..
	"iv1RAclLueYQWn9mUvWmHwr8vTb0o6+1OkIiRp6QmtLubq48QkRtjlXxS4oDkWPeR62RtqwTLP+QirCVVunjBL2XBTIH6Jh+J8E9" ..
	"FJpjmSQPL9L1JAN1oCTg+7YN13J0RoZsIgpacokmf1u/WtwsXS1AbGy0TRP3TgbdgXlFWiXDlJBZVgUUJvK29y9cp664YCmrzPVW" ..
	"+Kc8zrb8k7gRbry6bfbrnCQ03HFsD2OKfVdCAsa5YkWw2Aqisymr+jnirmoVCMJN28+ykZth4D/CvU18j9F8RBUPzJHARw8EZOed" ..
	"xzJ2BI05Cxz+sDlaTxZRT1+iQtlHeztUkve4b4ulaBwum8ytGl3FSV+f97CVYZ2dFqg/IyNvXyzdUZ57lG+iBYT2ztI/YtLJRUFX" ..
	"F4DqHPAFLRCr4jBP/uMZNwcYF3mmnrFl+W0KReWq4v7Yae9PzZcRgW2jyDlLzyuLDNmU7nxqX7EN1xiS7DsyQ2nrP0KKMR/Vt3rY" ..
	"9umW3YOXzoege/wIlTkgbo0R/93jAwaF1pYRpvMYdOLLtLfgOnmBvy2SOYc23cIFt5ezSZ7RQk8ciZvsvxVSxTyJadiCHdH1JCBT" ..
	"c1lecxFr4Rc9rdy++Wn/m6mwNeYBE1sx3lno0n38xh/2dXVSQpUUCjZqm/NNq+2IbTaaGoON+zDvRGhC2FxmIPitUqzHdrAM2mh9" ..
	"/BuQQNVOWRrDHrUd6BWM5JokEfPWYMs+BgX7pQ6CM9ftpfT3qOafaD8Xw3haJbwKr7jjCP24OXDWVL2Qf+uIzOh/E1Xf6mm81+/B" ..
	"BRSZqQiUxaHtmpdj9Ct04V7ir9s5e2USB9edxW/FD4WlyCLuD0BDc6qcO+45fkCu0ddewuyRuS43rVKQgnpsx9CBt3e2mUd5Lh3K" ..
	"JNFpQWYOEZbh/xAWFbK9XYJWAWHcPcTkO1O2+uQirX73x7hZ/7sngfpWb8/ZLPOnsVgxwSeuplDGPvrYuo6uqv/gh0eiiFh52vNR" ..
	"4ofMjecjWn7lZzh2zsfigiW48TwglYWmUi4jeIXplPB/hXTSP4ZJZ9wIVJqbYZ1Fdb46HlBfQh9pjL+Pj0/srQ/D+ceUjxEQ6kyP" ..
	"8nAdDeltrKWPnT+qaEwHpPy31jC427S0yOhFCxXHTE4Vs35OjEWJGxhXbtoKe0xRmwqTO4O6i0pGF5rXIPae2A4y2mVBWsGjUsOp" ..
	"ZIrFI3/Na3X2t83eMyjaRREpbcd0UabO/BFflmtbjazJjITmx8V0iysosLOmweEyJgErM4cBTeAm+7fpn0+XmoZT2mePQgvpVTAd" ..
	"oEjj7wGWDXJfhAGpQ2SvYpTYJuUkSjBmqIwFKpCSuZdsFxyFA9e9gJLkL1xSi+Zxb8TT8fgqGahXQcLt434M/7YDgBltOMC3mU9I" ..
	"aYKDllJQ6aQyHz8It2TpN2DV2e5H7m5KCG3zWmrBmnJp+2n5+5d89Ecf0Uah5DYhmPY7zPV+CkN7Qyw21qNbeYM/WS5D8hcGtAHc" ..
	"zf10d0FbnW1/DHuU/tMXUEfFbhmtYk3o8QPopI2giFM3KiaT/vO8om+6tOfYUv7ub43ikFJVonMBjragpooL3/VFDzRlo1YPcrHz" ..
	"LrsXj+M3skJnHoILf5b0R0U+yp11Y7xG1ydrRlf5ussdryyHOBvO4z/vASoFRxkptZSTLtP2dJBbDdr09jmCmSDHX/1XmtddWWk8" ..
	"5tkw57rKw0GXq5fk/W2kfXUC4fnkTwDJ84+utlz9L/UWbIY55hiSp321g9oGPsulnJ7Ps6U/amGBz09npneNlcEV3xfK+TGFMS4G" ..
	"W1r/03GtkhbTitiz5hwIkVZ8gQishrItxl0CW0h7mcUQ2YV8cvWgrIJCdCg4ET0Xo4yqE5T3gEY2C6ZTHReXHT9fp5KqYS6DXo5P" ..
	"G0nGjcVIy2/qIUBykgVXU8jzctoTnaNSIVu37TXCTwggK9mSWeHc6XjaSqScUfh7nhvkvFJOjhP79TiOhzuQxOma/FXs44GN9W8f" ..
	"VYmwX0zPQdNk9xCykKqnA2/OUeH3bVYNa4E/DtfqhUzzbJkRzmiDfNduz0VBTEK0A9b9nJDgf8akSeOhhKcK3TNZkUq9+wr5mRSy" ..
	"TRCfFEx72Uy6tzDZ8icRijE1B+rVxK2sV0dYonaUllYpsy5MPPjx7+9NYV4t9kmnBvKDMgcrAZrFyYBUD9U9tWxvsXL1rjuCB0cU" ..
	"wQ+cYL2c7cm0uDb5e00bPXaoaVsQg6akLNW5EPyvkozQjZqHwByVRzVD0Onx1ltiDOCiHpg8a+3P5DLKB81qgqZcbS8UlfNuM3bZ" ..
	"4FGBsveMLW4sZ4iVv92b/t5nSN4T0iQGFh4Qr9pI20xRbSc+izJlh/9kiTKIsnM4jd2KqBug9bvO5/18khjWeBP+2/JpZw6Rqjzg" ..
	"+VOKhmKFj8m1nwApYKxiErxAZKxzy+rTrbfs7dBsF2iYoK9KybSAJPxtEi/gfr8qrera6YDq7So7jpB3HmV9YjPMDw5h2A7EC3HH" ..
	"IO74nEPbkl6rQNAGhNEAYWZZfxFXQRGwmQTVvAo3PEKPihBkGELSrnc/OVqrv5Fb9d9AlfaU6TjZHnaDhQfv9J1mSyzEdaBlFil9" ..
	"CCKnRpLCCqK+LyFLFwEanP1hS9cZcxv4oMkAmsd0dIJq6pHd81hEvZvx7KOdRKfVwdMkeJfyV3je8ObmZpQUHyCI3fiiHzf6wCUI" ..
	"L1+qd2EMwSNrpwLEO1DfG3mAuVUDYC28LCS2A+hvG6TpwC5KKjfbKeW6OyerCGhrHBFBOxjIKQUSuanolFPrTwxiI9A0XCneg5Bp" ..
	""
local PAYLOAD_P6 =
	"cOXoAu/OL89MjK4Nw/SYtFBi+dbXklWQSiLYOL3LcXOEZYYN4kQuoZ6+SpwolN9YNpYJJIHJA1cANvQISm4a1QiZcGGtV5oqBX/2" ..
	"wQyNFNqxgfHhphVz4tUae1QNTIHfafcpv6qfgchFmjicLKmGe4juZ3MQTSCsO+rQYwtJWkld9jNjZzshk9K6JF9xOfCey/ckCg7a" ..
	"gsKOGIq0Xw1iBfYEL35VrA2rvG/Hr2ur5nTw2dTiF/RJT9AASom8nzg6Kz55WF/7lpwAgrVNEC/Gz33+PMOQa62Pv5LfrCDPRcnP" ..
	"Hut8H+JwFmX31oXmXY/7+9o4GGv/RQnk7riYOIUF8T99zfNDbJBqXWGPbmytjybjWDaVmd0C1BleQqS3x7NlmdUxcs1D59LrvfKf" ..
	"W9vZKyNVBPRv8LkjYAhCutgiyWcXK8T5GmfkJOh5r+HQx3kmA6ON4Fab2LtACfIkXk4m/fbLLcreg/5TjJGyte1br4J05eJIE/sT" ..
	"rRVB0bIqPI0DY6/g+omItcdr0KYxzVHlp2kSHgTSpJc3xqVjC+e1h6NU517uex/cKplsxnk0/PTIZ8tv9L0ZsEsxeIDpcl+Nikcn" ..
	"oAFB28cpE0m+mlroBorcLs5nu1SSAML9RvOTu+ZcIiyFXBMJY7/tu0kFSkdor5HdfMQqnZzDXGS6WelXAg36KlbxUS4ZWlSkmyeX" ..
	"IRNFitM+Cpw+F4XTT6cfUhy7pC6ncqOWNpmNodbErZT73tIZ8gL8zAvk1QwH/2sI9hGylsq3iBSBMxeYqH6YaNeEPC4GEcQHgnHS" ..
	"KgIiWJAkJh254mMvTPt81UyUF6m6zfqCTItz7bnA5ipsvdhw0dFyNyfxKGfRFTrxsN8TtO251eocsNHYG8aNpCWbUro+mlp4nZ7d" ..
	"6Fc7Q2lGeBrlxJ/csPK/7ij05U+/JQ6qjIDTDDSSCOLdQd2TJpSuaOqckFBNQQdT+Y8PpJzGwhBA1rLIi6+Vm7tfB0GbaTG1Ried" ..
	"rartrNAUvFD8QG2T7T4v0KzjaiP62fDSOjxuhXvv6flmfJytWjyQdD7nhhsh9l4hQmu5ZjOiIcf9OrsLuSWoyBnJnmJL07eR/Pui" ..
	"HR1/u4WUTiO51eO4DaRKhBHMKczG3qHDh/DZXfPOTosadhJFstOU03PvtllkqeyklYGr2Zc8Py48OY7cU4hgtyzRZnPz1P6O60R0" ..
	"zU6shkflB+j/7Lg08oIA3UbXeQXKCp7tu+UESqjfrLXBzhYLHlpsFIe2j3AP/PI35gzLEXgbRyRmXpcDmHgJH00ZIWqpf+Njf1La" ..
	"A2NcEaMXqOaJeoigMgv+HrkAYvy5x72/R/q4lpzenTZ+cwLLMSxFe6jYTNVVg5aEaZP+x7co8kaWrwZEFaF8eN8LmYnT9R3mri02" ..
	"daut8G0d/n6Bm1s/ZRgcZpF5xo51kVscnhK3I9H77C+u0pHFTfxltUbmacioZDEOQYLTXq/y7izbInfJrULgajbYt3Z3o85wCUBv" ..
	"UTPbnX9rZVrlPrgwDoWwrXKAue253Z5FEldtClA5OJhuv4Ik/yfK9TshPsrRm3ChEkZhPa+70DhUtzEO++0EJo2XUhvEeoegtV/G" ..
	"GawJWkkGwpBr5ZH571AF/VO4EXaZascegBJBd9jUAD09+0VWnF2p7qIvb4io3mjvsjRXJp5Jblixa0tgvn21pf3jRNc2evnKeVRM" ..
	"8wGoVtnMQr8WBF7t0kFcq/7BJ2KgYfoIyF7+mb8bw2+ps8u5WCsi1stiJr1sHkirjLtnkuD2YYmYQULt/uUjy+FScXyv98WAwp6x" ..
	"+RHLRzX+YUfGF67QELe9ngFd69fQfJoy+cCUiwCcRg/Abxy3XzirHOzWGTN/CI1la/SHoQbq3m3YDmUghJ72Jb/Rc1iUXPkRTWAt" ..
	"JlfsOPlbW1mBejGxZ6JDa5OtrJgb3kV48VQcrB3aHEhj7jfyONuK4nyFJ0PPFtz7WxkB/Y08koZBlL1p1pwGDdB+kmx2ziEGsPkM" ..
	"u0BYctRaPWfHVkjYLZXnFzNRZfkljF5vB7S5bA3LN00yGenAZX0HtgmLXzb81MbZsqOD3LAS6Hf42pZQCjlm85BqYPZ78jzs2qNr" ..
	"fENj7RStNHx3Tvp+pEYl+hbMvQJ0vP8dveBk68wsxjfh/2MDhr1FX38hrJSIxcdfPUy7KAL+fUEu2fDjkOehkcxIPoO4yfFPwM6V" ..
	"3y17gLyfYUDRmNRFAKkZnQgr49qmRAgusKfWeVI7baUoqMSowUncJNiizxQ4l5EKEW0dkZwryAl4skQpD/fRcLqd8m0O09ec1bPS" ..
	"2iG5Qsp4EbhiJiq3YHmxc+tD1IdEyHJAmMMBWYnSdYy0qcrDSKOrEzVgoUx5GkfaykGNh9ZYD6FFbPUCAjkvWX/itEEVhIRjBQD7" ..
	"Uaa2PZw7/gOw5HAogZ9hG4Z1UaqC2+aHj7fMldvfqmSMakaCYaXe5EEUce7OiTh7Ugm0UYMRyIT3pUroCnapTw15cIQ/6Y00TJA7" ..
	"K3dHgfzrUxCYz5eId2M0Hax7sCGRn2HTppK4oEIdY8002nvLz+DkHPNEH8sgq4ytxZV4XF4yi/y7WoiJx8PAjQsYebm/8EK1yivg" ..
	"w/xeQSPpklX+CKnhhkcW7tA/U/hwsT4vX35mgFdJA4bUMYpc/5GeniMA0ZTi2biXsix4JTRfaxMFHX1lXHUai2t7ldLr2sLgnc2e" ..
	"O1D/AzMBGN8SkMKpzfshCQ8SqHtAlicAKiOivYB+of+nUaJQZBlKedU9rW1GmR0K/DCGuf7/OKjc2k9junDkg6ck/9F32cUNM6l6" ..
	"RuqE5kzN3hBLFP51E3x7afDnF98Ie0JI3jdJLPE+Jliaby+9iItCjW0C1piGyaxyQPkfpukdDOZRX2iYtr0veqIUrrHOcTtudhvr" ..
	"ZB54D6r4fmNLZ0O2OJMWhOOXX7PvBVL6qSD9KV8dRr1RWBA0gabBdplaB+xI39WBTsc13PrbhfFuw3V0MrHmQrSCE7mgEUAByyd1" ..
	"m+IAtQgtzlyDFJFVNDSv0utoTZA+3/XXe0VZrJfLMEgA6slyXIJSOX1aejS+sCudewlcBCb/vyJya8Pl4XqubtXR4/4pIF6NvKTp" ..
	"+vU2wgpOsPhe6Hw78WTiLb4JC9kgNxwZZr9UP4ABTWzfwRJHGHEwAP5lOh54TjMTqMJB56qjPCbJPnB3+DiCps29SRyl+MoFzMBE" ..
	"N7Y3+AxUWlKr1h9ld0xyoqerqg0YAojp0zOesI9Ovjlz1u6HYQLLXMuGznyvXKRIASkMjyjg8wSmqldUQ2et3en4+lV5sMMve+Yr" ..
	"FTq2oQzZ5pQHHAhiNHJ9jh9IpNqfcOu3i31nWU+b5iHU4NHVCPW+suPvmVxxprdNzGR49R7W8vYwaw0+IhlEguuTwH1bteuBCVh3" ..
	"ite/AFIh7KE9S+bQ45YZ3u4XnZJ/0YMX1xSc1FY+GUQT36Np2tbFesyghWwOTlADZaOZrgnjPaSVlf7FJqpB6wLoDhgIc/TT/YPz" ..
	"ps1QYlL+qmwhN6RUYxPUywd+eXggWNLQDrapsJdZZblIWnMGGnJU9OnBnH77djOIwe1RJDD5uPInQ+ErmU3deHprbxc4r/IJB2wZ" ..
	"CxeFe/tW3naj+PePjueezDnj/PKnGL42D4ZUV+2qlZy/5Rgp2VDXOqhd7n/75F3MZc7hu6Gafbr01nzSaVchuaw8joX18Yjc3q87" ..
	"7Vwyd5dIt68VeCr/7ocBamTAdpnDGT45h9bxflfZvAnQ/HVE1DNe8EFsond8jldJAxHcoBkM5oI+dp5eK0hembUut6GfcjURy+et" ..
	"8RpM1kno1ClSmvLiPYggn4F2sPcHaMoy+4stiEyAGTlDHCPdzWDKQ2lC+umZWymjiqZ7a/u8O+7fR1V4/BXApb2tJIC6LpBk9eMu" ..
	"xS6w3W49zSvdrrhlKufEjcqF6O7AEz4fIQ+B3Oc29QCKazDvSiHCxTmmTRr+QONd6fseGSc54Dvbxw/sZFioofeUySHibKhl6UsO" ..
	"9SabnX9GFw4My8P/XUKT+8Qm7c2p4zBN5c8gAz72QJZckCk4BBHZZsWy/pafv9TsOG07wrTxx5BVU4Skyytwfu2Gpnlvn2cCmSVS" ..
	"vhwcp4pe/D8HlZnGjTAAVBrWZArIdtRkx/5DPMl03jeAoD+pi4idKQRusJNyzJUEthufM3O0a/aCmYlt/xHm38eda9Q53Fm7gzKZ" ..
	"yKAeki4rwUQvwjCyvblNl+17VZHKMdICkMJzGVpqAD/A3sVJ/4fGUTjoOnm5MEpHg+J137LgFqqXvfewWhGGrtSy+dsElYAOsECV" ..
	"3VjLkIZt1riZ3IGZl/AXJhlDtDCX4x6ePE43XjsJ25NhtwOWDIzcxjBQyGNVC98XrdYMFK0RYw6cWA1/zf1uT1momDkBHcB+TK3j" ..
	"XyLJeQ3QlY1Mo56fR/94zMJawSnNPbIEVk+cjX7YO3zdJY9vvgd6oZebHI/FJ/RZBT2tDvHXTxh+Ub+Om9V+JURs+JvqIZ2WEQz/" ..
	"ihrqSrD9jDWsluT5bsbhyAZmx+6fdFYTdGmh/1D1oARV/b2i7wzFwp3DpKR7M0OR9pGDze6kSSy2vswVrRMMCddaiaW2JBPzGr9t" ..
	"w6U49Eha7FdL3mz9zh8PgeSabtT3ZjKK1Uuc2GHXThZdAA7oyK7H9ir8B9pI4xTHY+nhUtXijyqa71uoujSlaBa6BQZ8t/QVAj7o" ..
	"xB4FFE13ddgysDpbvxLI0Gk/sQj5tdqiE5V7lCfGiI5/ZKlJp63+ByVl2RKYlBdOrnJrPeTvr3DtPaM1itzTuu5z6R5elIV99Qo8" ..
	"4pcHB8qW6QdRII19diVPEp6aM834fspBiGvMpgJILdfTbvNGtBbkxBibQP13VRJp0uFKyET0WHecEQUbfzalHzkKaVsx5dZurd8e" ..
	"7HZnFKWu8rMrU+Q9g4oxZ8EtlHuRd0Now9m0Be2ikdJBokvaX/jFfsoU45SaRGZMUPGbUH5T85myGonUIl3Q+FcP9VIXM4+RWQ7Q" ..
	"pfkit9YEEPvfQcbHpeKy9ZzpbV91b+QDcT9qvi+8viZ4c8hsYsmWr1hihQ5itJcuhzlbetHDWCySunyFFVAFlxS9POfW0DuEw3xx" ..
	"mmlyyeOrG+Np1DlD5Spl4r8iLY+v49N9Oq9hz++zbyMBRgEwP8uyLmMRojZAq7RQU1QOOkNehTFpLzSf9ArqnyBaFtAczedM8TEz" ..
	"5uD7uZcgeJQWOjm9V2ajC+UiDY3ONSf+nCv/bUzjNtlZOVMLYndsDoRiVVjnc0ixdAk9kc3o9WdXtfy+y30zZT102015c7NddavT" ..
	"d2e88ueWuheD4pQcgAOM/7EixehaOHg4GUAXbTz50fINr6EQYwx9SFedYWX5zVMMALWKxPJcMgV4jLBOCYeevmct9+ojaOBY0J3O" ..
	"FuQqhm408qjw7pmwQrSxhpmbMwxwq8MN3azPRN7lgMBJwQhhKR9d50HzT3gCPoZ7FLXtBWkNgQGYMIOskFQnbwBLJaX2KftUT0PB" ..
	"+ZP2gL7ug0eeyODLfzKArC4GA+ZixOnrZNn7w03aydafGKPMhUT2tX3SkMTP8fxrmXR3c+vc4zdp+x1VZfR2mVwIcQ8sivZKdFi6" ..
	"symsblCjohOweLOT21bCJpUL/BcDFqHyF6kity8YtR00NxdwoX/ybAIi/dkyp38v35klqYiVOU/zMyaRjExOrKCLEUood7tfp+De" ..
	"UtfM7hXVJpvPaFvVJPkFNwKL5Me6QC8hkFUyu9fBUVxXjXCMd5vS+9mogaAx9o0l4U0NoSuViL0TMBD9gHgfdbuy8ZU3WGnfdEDH" ..
	"oBcLxIToV6ubmIzoQEeo4UGUQOmBhiWtzzq9x/78lLwkE/LIOlX6e33GLzQdXGSwQYlbcspV/EB4IUnTfuiBwL3GIfGOXCh2SoJt" ..
	"bk5Te7IU+e9rEOMPttiAPLso0Y+xOgPtsnWBNGTDFnDEYk7amT0X/FCx+kqMujKE5JIW8STEF2BhapbduiZlNCIUd+ewTt3XGKyl" ..
	""
local PAYLOAD_P7 =
	"jUEJCgbKqbG7p1U2Vef7Ssz2ChyALBaZZAHb2igbkyY9oLsqY/K61gudkT9L36mKo02fhZojd4fS85oM8Pr70uVW5LfHT8+/TKqs" ..
	"Fmu+3gbaQ6azOrglD8qXNk5fDOYH6R0r7nMiNFhID3r8R2Tb42kMARTFqJt+2ZGlX5whawLkKkiyO/JfFaowiDybzL+aKzoXVsBF" ..
	"gIJwJV/TbArKpywoOJ912dWm+iwIjFH25NC9q9BpDEtpyPU6G9OyDKMB/ja7uxSu2U86z/bEV2NFZdjJzVqnYYSGerF5DOF6Qexc" ..
	"rvCf8xInCtYR6m/y2OMhLFIAagNvdnsABv9z9O+KdPAAO23PAmyIn1I3pN1DIkdQprs7CguEgHUe9W7ouVCb9MmWl21N5T/Pg+u0" ..
	"nWUyvaZXh6v3hdTBKh0/UTIWzAxy6dp8S+4Ei63XAYq90Dm9Ito4OQbZWgO6MyvlIFZtHDNyraqPhvX0s382JamGGlUpINdT2y3d" ..
	"HMTK7Yp7b8pE37piVoMMT17cRZ320zWSvOotIL5cf1aENDv1yG1Pz9OHoaRcFV5vNX7VRW03dxgp8PBZ92B4uxbcTcwNyFkxaEws" ..
	"qwXmairbSDUL8+A7c6secPTHm3HxGHIQTrAGBCTbDRCyaHQWCdUh9N+2XtXIIfpr9Zk8JkboqYF8Z3wNqBZ03rgD92qy0IqKYc6C" ..
	"m2ebdx1KYu5FrFyj50hQLFgTiT/0/Y3G7Riqj+uKAbS8tzRlwCmZwh0Mot3PQelsOHxd241YnqiwMfJJKr4uD8pD2LILZrz8hC9D" ..
	"9M+YT9eL4Kr5Y0oXRQhZxcEgT9dUTVbIYVESEBRrgG8wwMccGfU9MK0m4IjgZzVSXBOb7z2CBqBloimunHmolmS8m7qcSrOm6Y+I" ..
	"YVzWHCS/OuU89Ade75ILCsS7+nmsGsCVUg70RW2aSR9hgHF+4XeMQQWWM0eSgNxy+cfvE0tEeuiDH3BcVIBOs5mE7vqqzNgT4QT3" ..
	"yXUqAaeDJFY/pnfqKKn6tBneTwLPA/m547O6xi/QRpyCcdcVNPmbQQPYngCZQ/Wmxgeia8ItxAijfSHjYYQ6DcsrFAlvtXd4Q0PT" ..
	"le+LXV3UJM+6m2lNbp5aRZj/6fgPVJB8IqXZJJa5fVipEVo28qx9m9btoAIWmZOQxM6lm1TFXUNbPcDWIzxSKF/Hil5TX25lwpYE" ..
	"Rtmjnz384PMOaU1vr1L/L5f5wOxDKYqSoG3ILZhdwAvDPlSOg4KuJRApspXd1arRfWDQqxiQV5XE3wkqys6GlZauJiLc2q/Wpfpg" ..
	"1Crl9x10WXLtPfszZQmcB/21IZ4JIh2eoQ2We0sU06RalQuOrwNG0nQoXrJ0MpUOKN6BQz/N98jLJJvhJKo4ArqI5arHM7Z/spTg" ..
	"lBIGZYh+ol3v6LWrtyEryyriRy1lf5f09kNUIAMIktXbmp0V8yKjaQz3Oo3AZI2hNp6cXpY1vQOTwQR47rchzyeIpJiSc0RLSwSA" ..
	"vduQYeWv4+HtOdBJRS2k9Zxhfnl3zs0Sp+YzeTtda8XImPaBH8W9K1xk6L8V5nrxaHp8xV5v185dLYkqFhCWO2/I3JmyTSHUrwea" ..
	"yIM1QVxDgBRq/Cc8tCR0jUJHNqDAbGkD2PxKWAdk1Z0sGjQz2HsHPdcXgWv9ygtWRBwOXR4LP56UZMouPMc9q3u5ZMznwlr1LUlj" ..
	"u8264ou0JmJRgue2zzhriZYztQ9fF/R3RtXCibZszYkAdkaP6/CZOZ2M2WlLu+JUMQQYSA9RYq3PSjdS7JOomPzGCi7rApCfm2op" ..
	"26s4tHUr4hMLdJgRgLZ9sns+PLFurqzirWDwZXyyd2K+Ozc5vNSqxDfLH62II+cdoSFatgzxczAJVEvvdTmBF2B7PoTebCAWVsgG" ..
	"ERuga1MvD5M5MWtMjqX3xRO+VjBnXeH0pjtQJeY5Qp2qhSfREihq1vxv+BJjb4TjW8WbWv5uDzQexddr06QSaQBh+A7wZAxh6rlU" ..
	"V8Bo9TDtYB/nIZg7YmTxo4FWCk0zWqSPuhc29MKfyDAGyi9fX7IWiNzikPhCv9+sxkrOv91YcLlzOCdbO37dPlpLQSa6F4Daxvkq" ..
	"ogDM94j/rjyBswr62nC+N01jLx7tq1pd5VOdv9lnvR8IV9oV1Ar6sPdRH+uKA13061e3eXWr01NDsfT/hE3l1S0LRxDYT9liPR8O" ..
	"FJfrFEcmSEpnWdlBUARJhV1DDxVQXNOkHv2Qarf0rXbQXcpkKCxqR3cf7wUb5dW3e3/J/JZZ1gHA+KE0UGva3HwdbDD7hrqoCNYO" ..
	"3j+i5kor0W5eSM+bPudBkXDzbZyQkfqmRkFcGsW11ESTM8Jx/0sRc++h3X80q7t83hy6KI5cV/i4KLxSbVGOcdFM5rIfjy5OF0p6" ..
	"I1YgUryKXsMMqhDXhHaNeRddY0tHRvK8pgb0TJWv324PY+bQBMFo/nntKaYpFSqIxMlNXvA4Qena2u3Sv2zgIylEFAeyu8meVVR0" ..
	"w9jk5EyLBXlgpqiXoe4MwHoKkXLdMdM6dydi48HoOlbRa0AhBkEEbHgqXsnTyhL/8suUtjax5hiz+qWKQ+bYihMAAz2KOc0DDZcu" ..
	"hk4lOTJD0ZsDf0qga6jFiqhul2qtVVfascaS2uMxc61RrBQFpphqGxKsS0Hm/m9GPIIvhXqb4CLLCzpsaBfMiTwLDDYAXpYpc9lO" ..
	"kgLPnPvqpjVCQFIcri1Uq5F+VYTg12NT9QgyjGKxFS8G847IOi3ZCxMcvwf0d8yMG/7yYJPJoC34RhVg+T40YbWC9QfOZSA9EC+3" ..
	"TpfHI/ZlB+gKbKIDkogofnnNsswxaZmxquIMl3nYsq61SOtyovL8Yzf35dpIGZB37ynhS/bCrW5C/7X4WT3liTkv7stKAoZ4ptZF" ..
	"dlf/LV2MbSPp1R2bHxAePNrLGY9dElAmUnC2dVL2+E2ay3f5CTY1K5fuxQU2ES24AEAKoCBhJIMyc42TVOx0bakbEnBUvrI3jhgS" ..
	"6pfQECBexmVuHzxW6lxJg3ZIe3IGPnTqIFLn9b3W1WDojNoquzFhMFz7GEuW0nqxQwfY8wokYw5t+wwpua6TqM2XgD15k9pR2IAl" ..
	"3AQsewQz4MBlifeRwQGSkoziZQjSpbh4lY1X+sYWecvPnBw57o9WoG0iJ6/7ovD+W+Gft2bll2wd5E3vPPP6sWQK5oD2BaBvNPYi" ..
	"LGDBncyVYyF33IDnJaOaQX87h5xPxTU0l4Qww4yKZmOjBzqVScSK95Ae6IGk4Kmd5Dp3vBbGKmDNHxeDMFkqDVVl81vw4nkCxbmd" ..
	"g+NRQOBWrE+BNjZaT4Gnky8zMpsYNPHyApgX4vxC0PWfWERILtjw5deINK81NLSv3v7C9rNsRNe5HxbVg7/8oZJ1nUM5gnGz29VW" ..
	"FUL6TDnad0pV7rBPYZWILzyWbRBDbAeleCtKCsuVmwGcxui0rbePCrPLa+NwXGvYIRMIyo12EG3mzEZWvpxAOGEZ/wVWRunMSIHd" ..
	"sKuxejUeB/8BajGTZGq5Rwmy8AkprRP6MaTjhshNaiKiLctDOsb+I4fJ12v0JYT38aj6RHMN80MHPceAcL7iAP6P79SRN/Uau9Tv" ..
	"mR13RGqLpp2TjHogrGAASXqS9X9ivk97M9pS0FKJ/cU39bXc8DXgYtuusq9Mm/qRgF9ZUVfBNULLct37/tWL7MCNhhfobQfEE3oK" ..
	"pW5lpakmunjlK8Kg0Ziv7doptDBDMCL2/eQ2m+dVafS/Kgf8rpvcTD1roNGH/CqcFNE3j4PZDY0NBW8fuFwCPu2XMGp0tmqi/P2W" ..
	"kGX7xkBTCB8avaT22Gl6eMUpTXiOklA0jsoLaomo66FJeMNMdgPw7LvfLZ6MeKWTtJ3SJfZJXHu7ahfVyJvXt8LGQ1IoLhuOWnC8" ..
	"PWcJhDMasmDHkRBC4qgyF080syPy+vo/QR2R20RautiyG2rhd/of5C2in4dLYxd0hONIPTTQh/6cO5tYoFYtF02PY+WBdBa9hJ5D" ..
	"Zdj5apS12qz4/EJ6SAxftJj5HuOEBd/iOhPrlDP1pUg7kyjke0Z94YPT78Cb7J78lCZVZ+z9V+pgr8TXWJBDgOrNQRzWOyr2mwQ0" ..
	"zl67mxiFpaj1qs/ulnKHPBf4JfX9xEfObVnwXeThJVMZ7AvrZ5YxbPGKTkqtwdMRvYGNv4VRYXZAYJsBHaMZ13S8sTCZsfjKyC1n" ..
	"p2y4GCBDqzN8WjYVu9MvYvPsFBTRQ3DOl14oWIPZWwVQHOC8vOzVd1EQexVJ3RG0qLbN3RKW+3vtU6kL5fLKMHR+FXr9p8K3sI0g" ..
	"4tuGckfxmW3NyaoHjzTfX9ZvaCfsV8BVDWZiuyPrg5LR9vFBAltDg454DOix2s2pe44KXYdq05ZNcN4ibmlaMJyJmOG3Kp0yIIVw" ..
	"nhGHqSKhCOMzTxYRzZl5gaQXRWA9i5MO6Z+tAOQqbc5enZC519BrC91vI5jJioBX7NwOFuncg75wSIrhMOZdSu5nGabZjyyXIsIy" ..
	"stdqn1TrCyWzUhMpG96DHFoMjTaQVL4xLxLt1mEDkbTPo9wTHgsBcx6CdGX1yXvkCm0TY3YSRZhsnvSHtS8ruhrN+5vQ3PcmKww7" ..
	"cKgYqZGkNKvndB2AOFtT6ComxvDYTYaZxFh3KCEoKXOxOTzOu9PGJ/3aRogDah+agSNil2xmcpoz+EFCXNQrWg+zqi8dt40wsuHn" ..
	"wK93KjbcvZbrJjKJnjcTTS0iw3aGjBooUloH0Uy8rqHJHbDSdaWFifViJEEauCkMpQOovTLiUZlnqDf1EoB957H2FgM1frhqzSMN" ..
	"YYIQ/msWA+KB/CAmeZ3eclb8uohZfmzTHn+Z9OXo3QmNOTGQRXSZ5XYhvl5gVGEMEm5CZu8f0NAFd8sNcqhTm6QW1TDwAlfHdpqE" ..
	"skkMOWBaYpeUbADlN0j/K8Lcs0PxFJ9x0zRDD5mvvpL5qUf0u8ss2XDvHRQyTVGIX3Vloi/0iT2vPBNW1v2shOIwrvvoCPq13VAz" ..
	"yfHmBsMVIyPmRdStGrfVjyrRGMcCkehykMB8qxfZm6oCQIJzekLhSY+sTAzK0gwpjUjaptY+YrQnW2T7meYR/Il/fKNHyuFk3VQZ" ..
	"6Cs7+IJ9In62fkXL1yZEF+S7SgGA95WozZVmCZ0sCXVNfwQHF3wcdCvuceMidPgPwD69bBhmNN3zkNK/CGRT1vwb8ksvZ/qY5C3L" ..
	"4MBe/ZhLBHDUrIfh8inax93HmnDi0Lt0ukduxe+5O7kkEc67eLVFDeGomD1pprB9due5W6FC3JF3PNvl/5fTVa8bMPWIdF3I/V6E" ..
	"rXdLk+RfQmk4JOC5V2r618a8ygAmGt4l5MLy2NRA26avk1e+EhqTwojSODzoz3lY4zwxXBHOI+ZRA7YX7F2sECIJOZeLR91sD/n3" ..
	"hl3Ky0gSvMKJGduJwlslPJUwSni9x5I14nqsdHqsSHVsHJxiDdJIP0HAdHhaGckQKaJPQBMzruwpMrpCBZLgkqCQB1NB9zQPdrmb" ..
	"fkiNRgCmbsghSbqWJKyNcNUqnm6STgqXs4lDIJVR1sGoqYVsYJIGFVOIhoHD90jitrnI6xKnMY88w2qrzQwc29jIhl3P8BkO1BiW" ..
	"Kr5cXmLUzz4p/cBlN5xHg3dsnSJAI9801D5igTFS+0Ef+qsvuYQCEi8WCPc5H0sJItpiEhC/YhknMumHBBD2LDIreUtipbu1iP9r" ..
	"KX5jJ3JFSW0GBrNFLz9r5SeIiTVv5lZaRfcC7Sc3dCsaeny6bPkdmvmAkwzSy/rPg+vQVJGq4ojJ4aImn5/dS+wugF8eakK3tv20" ..
	"BqdXm9Hw7n2ds2Nh73zb2RZE8a5BquUWV02n68ccnJfEQtyBYnXWh29x0JYkMiTFP5RAG+l8UWS2QT1r4ES5xap1g/YB1GXDXYrb" ..
	"LzyMy5pklQt9dCbrkewL2Kb0sQ7/GCKhbHI/16bRy3OAoUiLU+qCZ6EntbCoTgzP898RGJ7kS9UIN3oQj1aEiDMArWuoDEunI1CI" ..
	""
local PAYLOAD_P8 =
	"JAwhsMGapWp3273HCMrSWMfpGXyRsL4Ei0OvDh44SKFH3CuPBbyTNTzpRYVFAd5XLzuSpR1kol6S35Hl9s4p5rlIv6j2Mt4n2f76" ..
	"pTn6/gcwqJPS2YID+x5mMTz7psQRkfRM36ulVNRhHK2JcAo42IZM11XBCjsSkpQ33TFnfhwlzYVV/5f11HYk3feb8/2tQjoFuaWq" ..
	"09VoacMo8aA04DEiqfzjONUsQfWgTMxXNju/26fggGpSQCFzSazzgxcPLPy9CycgJ/s3qw0JxN+4j4h8Lo2F/+fShbjCZxTZU7gZ" ..
	"DJCaimB2e0cBaKrcnK3fokr4S9vJJB1r5+ZhFWRLc8DvhoTOlV3u/8YO1jspMsbNTYz1ZhVt7hmWkteXsAPP9kpCdps9tBvMEI/M" ..
	"YqiBRG8a5AENnyS8Lc4h+/yAtIaWyxWeoDHd5pwKxLBlmyuefHd18M3/pKbH8zBE9rU3414p2HHC3OC+Xdv8GZ9JMD9qIao3qzhS" ..
	"pBddE1l1EUUJG1T8z3OzdJmGkfCIbvdLbLJqN1itlSg6xQfFHhTq+4LolzztR8AtSvXcXoSf0R6PLfzbm/zsocLzr6jL/siybBHy" ..
	"RiwC24YNxAS5eRbTvxaq7yPPTXzTQm+LHFKD3ayoNfjjTuuQAOaMmRgNVQgZ4JyTKedf+hkrXKDf8mRuiS6fVSzZBkqQd4SFrLjx" ..
	"fwCTIb8mF8oxItQkwgGXIBpGoz7f2RTMBupTlShL+wlX1WCIEzdECQs8bv0V7vRzVUYxfztq7mxTf2hrxddAFI0fR2cv6GqYbRwF" ..
	"cjo8Xhg1dqn92uRMusKJ5VRUUcs4r4Fjm1nWEoOxsSGsdwC9BuXFwC7QDtcbCtC2AYV86MkcZw9h1pPbb63+/kUkJlRc1G0dWgVG" ..
	"FKI7J5xFVTbNRTgAwViQxd5BvgGLMCVCeKihPN+Nr5V+lPOYo0HsKFNJdcu4hD6aGxrFDmpeDCAzRx3y3tY6jLnCGpGT3BnvlaFn" ..
	"kOA5H27ktGJeBkNUzejELj/EcN6B1ND2THTITuGnxg7hphYc/LkZ4NuacIn37JR2k1mQzP8WfUmCYQ6JS3okKGc7/r6xBiKZ2Bks" ..
	"DsEIRkBUs0er246oaO4tgIM3wJNrTK2l1efXZUkI9+Okt1OjT48jOPnq9ldut8QuPAFQ87uJIkkvCuD0OjrIwiHdPx5xzA1uBQas" ..
	"d2c0OpQUu+6UnWfJD+wdGH9yv9BIvN1fpqm/+hms8LmLgIKgLHxFPx/k4NWBwTkL8OUKEaEQng5e6omqeDak+07bfVwKsoodiGZe" ..
	"wgkE6VOik2bFjlLdLjnMUyes9j8VnMijpqbOrXf6dKzfjQMDVQGeJZbu0INZqwWuckM/E4ZMITvsJ742RAE8Jpch8ua5Wc3GJiYj" ..
	"cl+WTE7Ycg0efEhfVxbOR7ObhBgsDAFm1MOa+08jg9LTJoij8MdW6JfKbUpFzrcSBS4YGfyCX3+8YGs/AloMHfaucsGqRyKk9kfG" ..
	"JNlq9A4caLyC2Z06cowNSwsRccO3V89XQUlPWo4vwPW8S0UyJ8PwO6eToeiS/QNkEKVtYZiwc2/lG0RQmFqe0Kvj134zvsQGNeg+" ..
	"G4Z+ClSQnR9C0SdYxhON5XmJS0CZ1+zAnB7RBXyJG1HqrdcAfZQRNwg6Np9JGZfkdAtRgtWDgrDax5Hw529+CUlKn+EIGm2biXOm" ..
	"0ImZaMkBfRhoSBVRlzoW8MNMJwRywqtl2L3d8WF3GmLJ8wwpr1mEzEZkA84sXvePE222+/6LR46bl9R5cTzzBAyeWfPEs7hI2oyS" ..
	"yKvUA2eTerWxvy5QH+Vbr+2xG83Y83yWSG4FZWxe4Ti7iEORSx0kZOUJv0xviuBIUAibtb6mEzVnrxDzuMmBtVdXfgaEFJYJpj0n" ..
	"MEeuRrjGhJibu2Wb1EpaKjy4Q7qdvPEzzxYhXQGbmtrUgp93EfcA9xrDfFKjw5B+3Y6pWKnyllConxgzyJWem+eYU18Ue8UB6Qec" ..
	"2LBSUi0GJR4bzULoPwJQUe9F3Om0lW8iVUEYNN7k5lAEEdNdY59cS0+IVtYnAWpFFrW60UoUB6Vc7mIyrAc4+ctXsJsEOOgcI1aQ" ..
	"J8mz26p/p+mxs8JIPkTI73STkiGS1WK/eypDp/Jo45H8oYfn+PiK6RFabhPMvk8wQ6aYml/lr4pfeipuCI61qdM9yqj9Kpe8CVIo" ..
	"zEcOr7aCYksNvJkEOhBfZtUnTFV/xpWCOw51Ivr1rELJLzSt/I8qLn/LPcuKH+nOjm8tpRBIW0DyDDUB2x8gGIgFR3cCVqUX+3L7" ..
	"C1QgggY5mtAa368IeCUdLcaXYWgE42orYA+if9JcIyR3qgrup3ADfzm72GCQ4KwdbpSCw+WSzuwemAe2oMjnZ9YhtF5d5qhEO8Qf" ..
	"SQcO7dr+TfM/WM9GXOC5d+hGueiUx32PI2hWMPqnYvuYDtO+zKlSnQgDpZKTU1ExY9IQv513BQTd8eiZOsNNU/MQ2dn2oUS750Fh" ..
	"stdQ82+bqa36fsH+NGa5wdJnO6DNH0x/qpdQs7qU7ffYoecRipUX70vAD6tzx0AOuLRuEtpjEFFmi7c17HRiSAkzEjuKfawjQUPd" ..
	"OVsZsdIeryjgWBRC4CJvMPpfAeAovZ1VHJss35lWRyH8Q7FULV7XTmITGQKRzZnY2GmWenAgJnmP6iSmotSf3iDKmZsCBc7jnfw3" ..
	"PQk7ykQO3eKngfglfij1e5HF7hV3OhLUdluquWGg9sY0LFlSzbQUOrzcnuhpcz+7MyxdOFk9Ovi/iA7SyPwCqnw/GWbvFOb1NNND" ..
	"zwYYVp1bK1agb5NnveWIMqGF9PjWzDDrsZnUSSCmxTgcUFe9Unt69++q2DlquPxLnNfq8DpkKRXP44wJU3f5R11A/0b/0Qnq1PLf" ..
	"MGcx5DEYkN35x6rFeKeuJS8BvpYeWdAOBwf4O1IzLf537cRn8J/hsGyFtFPi7vj3xzesefOiJk0KHZ4gXLqa6IuK41uEIOaHtz3J" ..
	"MXl7Tz+tVelKUHqB5Cx9LGw8UdTLHBesmEU4WaQCSLQKqkVFgEA2mWTMZEXPaLO6t499o8akzI6QCAS6zbubW5o36Et1IduRinP5" ..
	"SXufs4NSweF8V8XpTTM8q9KlWje1lm2FU8C6kfSBw2LQSZnR95YEwpPf8pt/3MFOrD1Yya3tey9mLyKcERKL8RRu/WnWw4OWcNa1" ..
	"176z/kBweLxx/yOcBQvPkFVWA0RwHVAGrPIfNn+BH9+s3Dy8IVkA0op/GlBPFygVOgu5y/sK4lkJ4u+cfPXOpMqcGZXgk6OMPlnK" ..
	"rp8b27QSsUDqzvR1A/9NcoGBoT1zq1sKOw8AZOsMwYvRd1dvQmBtcpIAg506Ga9RzMnDmTor/nsy94uLHyQdH6+TXyoxc1WFUkQi" ..
	"eCJ1Nt5x8aTXbnMrYHmh6iYGgDwDBf13poKvinfqiMB0Ih6B9cUGL9WPZZByVcndMgJGVEJb7NoBDcxyTb4emSojSfniuEOBahTF" ..
	"l6UPJPpQg0u21zL4S8lWEDuCNgboqZOwyOS2P1JokqK8Q1RyScse6XFllgC2iEt36UHGOkND4i9YJPf1C6jgGl70pc7fc1yIvQAk" ..
	"9LK08D3GwKDLuyG03uvNvpB1BUujuZ6Hxq/4jsAP4deUwQfSobewxsuy5YggtnQsaU4p3t2TNW3ChQcGCHRIn55u06baLO+oZRXU" ..
	"qL3xsTuUFiJ4kHKOyaS2KhghDMDFM8pndBMC8CE0jscHiZuYV2b+htxedxxBAcFugjoenfcQ7P7GYoxbZM7lAcnMe9FCQL7lyixf" ..
	"h5XgT3IAn/io2KvEnNXWdxcBk5bcaWRclqslZuW9ZUMJXbDJ1qvYUS+QG5aD0KrY5Z9BrfAS+ygGJde945HlnrKLlANq5yBD+YXV" ..
	"2HMBDRvJHnQru+h9x7vCzsMq/EOQJf2X3/6v7nBBUqt7cwWJp0of/Ar/QhyxdNpkcMd+o72sirsr64K1Gmv73kvnc10+2uoHyfnf" ..
	"BvpU+JkbICMvdpwdxEwBJLNcR+1+1nmaJa3INBES1q8zkxQuAHiZU8P5OSEXdajaxEp2gHOP9CYudYPnhkF26wUDzrnmc7AeGZPi" ..
	"i28+tcROW33GnvycKSCjER5DkLZuiiAA5wcRqtAQLMQcUkzBYQuRaGy1RbQ9XmTNQKL7u8WEG84rNDrHakR46y+rFpZjJk9zu6TM" ..
	"BtsM32O9KlKNL25ElzjLzJORJ76p+yMSc3rP6O2we3MVVk2aDKRJvcPuwcvywZZhkQFUlzjfgJJ5gBSM7l3mcGtQ+yX1+JRMxb3e" ..
	"Lwm7ZlDkhClRqRDLEan02ziGpbd1CW54+y5qxsyZfq6D+EoaHtBTJNPqbS8Z7wvRq3BG42/nhfww48FDs/F3IdsMCyUGP/CG2TzS" ..
	"3gmOHw73cIdkta1BnPhxspvOzzeqoDYH0EmlvB5Tou+Wq4KXyWyX17zpTkSz8TfS+TiTD0Sphdg6TRJze0NP6QqQY7BaWKu53X8p" ..
	"qbAzbnLpHO86Wb6i7YmjYYpGdgtKniAw8CStipG4VGDl9O69Xu21fa6/P/yfTJbspA31XBcGr0oxgY+N4sIl2B7RpKaCTWNWR5hE" ..
	"btgSsmpwseK1iEOoo4qatQxse45rMbBtlYMxOX5hASrhpGeikEb3vzWjz9eZ8m87rGTDHxhTDEjjfQ+mdjUyu177K8LVSVmevC+9" ..
	"WMp7gQPAmZ0grleaq8ggUOUcf2KSPpRaOgzLm7YmNe2k7G68TMPWnChzWn9zlX39elrZ6ikQzpQ6nqgIcW2RjOhegCEPWaaSGbMz" ..
	"iuW+cH7uJWrFs0TvDfvPYxEYcXGOjtN0ytoxokwQJt/heG+dqZz9RNv6bOQS++f+FQaszznqnEW7eG1b/FLceoBRvBi145x5CFqR" ..
	"9xK6kN590c9obOhtKAZzYeDg7+oHVaxkIGLMyF/+e76tL2jyWUkXEfC4vio5gTEUEyZx6Iz9lD8diewpSmE8GfDk8C9pmCXhHqTJ" ..
	"Y192q+gW6DhY2c5oXglc2sRTUySxfViOhdrwUSmH9USuwbgoaS5d5g7oLiv0BhzctGUzBCidGepiT9eaiDjZ0mOnTUIMSjYxcJys" ..
	"eMjADlpRtUQYF+FLAG5ND3cjdFON2vciXvJOHUvynRfxqXHUZul73ro9McWvJLwJb+bntD+f1n2KXUXMd54mVyBTS7yPOzeiZjd6" ..
	"vpX76Py7oRjLs49J6//AO5BXGA10AU2LtNONDMeoMuREiGiPJRFPQK486I+3Ds8QyQePUiHk0wn99Ezhu7721ehQ9WFW08PomGye" ..
	"mQv1JjiowtH0fpk1/vw3XGVhUc40EyUZ2da/EJzhSv+Fq5tLwdu5DdR0khMVvgURNe1t7SpcB0uDR1BKBLx4fg2VBC281mJ1lV0X" ..
	"STG8cQCRhj/v+VH8p4x0cHMlzpTkrLLB6U5MvEunKHFbxw0e08etnt5fb/hQ0wzTHlBou0BJMjUfd1/kTQ/nC7ZlpW/x4aalavPW" ..
	"+6VtXeZa+xFniZBpncLZwEJVl3acz+1/0Gi6jfGebMpMg6HKoudXtCFKMao09gB/txlsOZXUx4L3g1DzOAJ3hTp31CHIvxQUHY3+" ..
	"PKeXXCLD9lMCQ6gRtts5x6s7sqvor/TdInVjDFztnIQahpYq8vYLCYC3NFK2/k2zRNQ5I3fVVSXk0bNKzk8i20zWddWZWU9j36UP" ..
	"1rwmdjzL0UGeS4kmTI+1e7oNus/1bCg2X5FciIa/3xR5QKOdRP4vhU63OblsmQab5QzCYOK2HEjACwhiTM/Aqq9OcofZQjXr23yZ" ..
	"NGpXgnbuTz/W9oS+YjmeXSnMbvgvv5FWRXjF/WHVFmrzZgfYLwLpSZVbEdP5Rj1cFMkk3pKZnX3ogBJvSgfTOQRC4KWFHQAjKjZh" ..
	"pKwsuzoaae1w02XFWmurY7fP4BqY79QTkUqkIw5AC9aTxlguMCE7EkQRjAgEAO5IE2gpg2UExEHKk5SfKMKp07AwSUSeHyz7GYNW" ..
	""
local PAYLOAD_P9 =
	"GVRTdvSxcsRhYOGUuD3uAI5aNWGY7BAqxninqBxNpWo9J9A4Y0dDBbNph4esDXz+2Qp8HaHd0dY0WzpoIgtKtFHCxvJbINHe92u1" ..
	"tgkPEqhiyT+bSXdmp+EWZ76ZwnAcYpwVFkkS+ixnCy1liQo8adHvYlJNX6pIEqLZGLjJrCVU9YDgJcgx+xZy2zvp7+3RFfcxHmlE" ..
	"pyw5nTARWX11d7bngXFyMYsPD9JNt/jIKGAcfJ46zSjI3QqLzS6WCOy19VG/DvUCDpqrbgt5Gs5lbEMnIwugPC/Znn58fdcPf1tN" ..
	"WmnpSOzPPdD+ZCscF3c7akolMDc4DIDp9JPrahEHCBZBXBGb93UxotrAG2/NoWX3El05IrKHwmHhn8WdYpqWhVH5ddht7mdUXAuA" ..
	"+Gcq5bTuS5jXaqRY1gPjyShKDqFTWUYQqb8+Z9ukwXaHYAGP2e+d6Lun1wT4vaG/HoTd/TdmPysIu5YHY478CHRsSo1nnc7auzrV" ..
	"xZborC8vmeUduiinkNA5iVgVEj7Iyps1aSQ5FLYMSLh6V40ursrdtVueeV+z8EQvt901GTGWhxHUg+LQeU5AqgYH/GVr9KT++xrY" ..
	"WODnWIlTS/t6RX4ZgGhI5cGgMK7qzxGrsAW4FKjTrLy7xP4mx4v7L7y+sR4Z+lGI2plaKRn/8iOojGzfDNY4AFwWEc/GFA+OVuEN" ..
	"8NzFVx2xraGHfT2kLEySpVxb2XbRPP+4ZVqq6V7nJPoHDFYomtBYEZYendf/gND0f9so074K/9Qx156v008BXJqBmLGxx/4VxYqs" ..
	"8uoMFTuLroqNU7sC8zpa5dGojBtIvDBg9wLRcrq9yxwjw0eXTL0LWvr3HcPDpAqR+AKsDHr5+CigJQVTV/0AmSxZv72HPi+32e0i" ..
	"lttiGKQGOYRcBGrbnM0mTFrJHP+L2BDhr6tWdCkJmkCk9UFqqUxJ2ZSqBBLR2zxYQGzVc0xdE5qJ29+w2X9JhOOYGbJtUXyFDL79" ..
	"r+A/ZAUq3boRW9YCVutgQsFZ4Fa9rNfYojx9TXmehcmYR5F15EKEEZWMOI9CbBS3Vi2OemwAW7zle7fE4JZX0OFEF3d3dRtDMLqD" ..
	"YAsbyhj6UkXfvuAQ//iQAbh7pSTqda+g9hcnSJaJ1XhF7LpsETE76RDSeEavPObF02VnaqXfaGBhUn0W5ujkqo1AbVjNFw1fl7/A" ..
	"VmtVX34MzkngHF4st7qDgv76KwNDZDIwQnv4xY3uC08ZCI57qAbNjuT2JQBjXWF0iyzB2KMmr2TSvPvJwp9dRwFsPPpro/XUGMW0" ..
	"Y/wl61vYtwVzxaymbjGDSMi63h8i0vBppppwWqOIIn9rB1JYLhYAX2ejJZDKW7TasMsjRH8TY0cZWY3rb6IKuDxYuv130jrN8rdE" ..
	"jbnc2RT8E3dITckgU8p/HEQuIDYlwOPBr4Rz0/pzKEwdYRX7jo+Y17U7zwoXWoFdnLqY8PwyvKo3l/+LT3FzHhDmlhWjYmJoIyj5" ..
	"Jx6KyZ47wi6y4NLfbM+vQpU5j4GXLI9awmdZF39pmxQMYoM4s0/cFqR04pMGr8crhsUB0W3cinBBagD93pU3c9OvPOVjN9I23MMz" ..
	"zsnoeORoWqWISr6V2XJgRmRDs+T2vH1lU0GA0qOiyEMDIFpRdAyKPm72Q1n7N5Yutz8Dx0CAXThab7BcDmmo4nuLSnlkhph6zgRe" ..
	"pukzPU6jJAQt7HvQYB4uhgHl9WVZbnIupGoQtluALWr7Ke8BT0WP21e17dKrOXAQAXLi/phqdkkRXMTXwJwAuVCvWGz+WaZPB2zL" ..
	"iHvTrLfGHMe0AI2EgnkzxhCTnK5PQdCshi4e3Y67nvtXdnMmSmkRwUNwHnQFL9RKlQHakFDlzc4K4SdummL7kNgX0PMVXJgKinYG" ..
	"BBSXND78kbER4B+PeOd3lot4t0iqszKCDOE6Vrsn+vNrw4uvzMMSB/bvKJAGBgMy/9BOtcQhA6rVDW4ukTaO8tXcyt5LoyX+DeNM" ..
	"lSleYHy+VdNbk4CwkJYxZsz/2sij8oYkBg8MV9LfTASgZKM+CU8ZLQTYSjnCy2QEL8cwzcVp84dE/QqcNzO33PrykQqSKL+3LnKV" ..
	"gTyfjq/MXOFKr4Ci9iVvE4X2LfCFvqbcS0xLDczSHwpuk8YFXDoa2vF7j+w84DxXIcUWbYQSebe98ANeaomVYwx0cwsxvvesOCvs" ..
	"cijqhN9mj5SlHouqzR5HSbRcijPwyOmrX3cc3pXTSO08Wy9eiRfCmGXqlRkrqf0gvnySpM8nihG5whdUYiyFjE9I7nrgKjiUCtC6" ..
	"vmjLgWSvL+EzX+7/v34wN42BSTQWp3KKPrCnSQqWdLSVaTMCiahZJLv1FQx8IlLuer3e51AnJ8uYnbkf8VNK0a2eqCqOBC0+wZER" ..
	"ufwN9n9Ge6zJfu2gZz4hSrV0s1OV1YNEyBm+us/kAGI+37Dc7R9sUZnVF+BF8r9cyfgH4QLUAPPJvQ2L3cz+u0SBb+QZD/Dyau0a" ..
	"UEwXEw6yQfSaIhqs3L+gbdS7W3rO8BbEiWGNQYtygYvfPZBBSAp8s35bf3B7OcZVxHzbzU3St0TCeqwZJuejho0DsXaqqN8BZO4J" ..
	"n84esJWkxiPMf8pF6CuciQjZf8oOOHLDhbyzj78nKP0mdGeRMeRE2xNAlahFKJPsZBiGoC97ClxhJtNCa/Yfo06Wdker+WotlDxt" ..
	"TI2JQHU0XDzcHx03Lf0eRzdZXQyTkiNGeEKXYV3uw/1njnNlMGeW/YGy5udSQU5Po/6eMe+UHlrl1mg+TEO6HWCfP0znOPLu7GCt" ..
	"klVMIvzvgVBMdM2SK43OotPQ8x/ZcJMlV9xnP6szeReadvYM3kY2zA+yBj2YpAs3Ax6sVaAe3WD2FFoj1qYjkhUDx0Lrq+HjHoid" ..
	"KLSnnNgQAo8l697HwDWstNmOMR1fk7jCunfQ7mze0DPnh78SNEHXtMgGeQ9xcEQL/QEZg0JIqpziu9joLaZ60ZXLBIGAcxrTk+i2" ..
	"0H9DLgXqJrpCMIgIonIowuRJ+0czGyX5y9shPzR0X9ec8hf6hUld7dl+RyXFiU0S46us+9uchgs40Kjlq6vB9hFU+uWtpz3MAl8u" ..
	"W09n7a8jjGW2uigne0wLG9DMtcd30kV1P/itSqdjl+y1VqbR7mnEC7ykq766swo5R/JPJdH2vDDvSdXammw0dfJXxmlqxfSNKqVy" ..
	"K5ohLVmpcjrus6iNmuymeF0vykhwUkLEwDH/iRNJWc+Dvs3K7Q/qPqFNWynwH4J7sGx+++qp1eJO+2BA6Nd/AUpiYh9UHXvR6OXU" ..
	"A5+w2W2pn/+pxr97CYCvjmpwa7Ap05QWlN4oAbK7pD9Tt9b/7kCttFMmlW4onVaD3Dw3PrrzgeDdjOUmUN5fsH4OZRofez8SkOsc" ..
	"sFnXEW8q2cRvor6CvU2VwjiGFNB5kVGVqHd2zlK5aKA2nDU+rvvBR7EPFUE+cPwVJCA2aVjuD6LvjH5QYN+uHfxd2+iLgNmq0XVM" ..
	"Zm/wY2UjraDUq9hobJnAdS0U7fKDsLcNbse+qeVlJRaIv2/PzyI/fJP2n90uzEnc0j8NScat+tTd320ANAJ5FvK125gBbmxAM3UJ" ..
	"J6WcLsRdWy7Stw3p4AY4yBLE80GIdYOOuDjgpwadgVjt15tSnFSGCI2Hb/EwakEmqM6f0cwInI9Wsvu1LmqrsiwZtGZgrA7y971p" ..
	"Rmb/e/gK/a9HSr8NaBny8HtRSV8WcLR4E0/f5te0j6vnqtDxebUsLlfJ1+QHpQXe6QDqLWG37lsq8azJX2DY5Nf+ltJMnI+GTG1E" ..
	"Mh9PpP+Np1Q2SUU6yyPmmthbWeqZrVFO+intH9JNsqYwq3XdI1bwnOqiDrcd7DkmyRueMa71S35kui4WeqLdD9MFlMZig0/S0UF2" ..
	"NTvLCBBGAS07XrSylUDqO12XjtOu2/xLuCsaWItSTsjqErJFgPrzVht99noLe+0Ag27gynsSQRufCiA587/+bcwn5xToOVytsPmI" ..
	"Y0GIkxEhq4ohrmMP6X4Np9x1dElkSkCOy6lFMgUmyGaJ9paWupR5Vnr0Ifpkcu4sbRAWoB0gb8HfEoxPIpDfoxJIUihqz+lqYki2" ..
	"kgSLevGr592XMPssNDITEzqY4+7icxkiQSz9xhv0kcUHwjidkPr+iY2rKoqK1xJlgiA2yitNllgkbkHoDcpce57qbeNekbd5fZiu" ..
	"tNMluvo1MUY2V2FKlP/UuhcX4sSmPR29ni3p/fqnyhB8t5FZMizFpDC/P6PvpesK5u+irLr1fm3DTmFP9p/OUNrzAxwDHR0gt5/g" ..
	"OxlhUV5CUgP+tLW3sjVSYZq00txhDIhcNuVnFE1hIoPpuDCCTc8eG5U188/5XtjI+orsiOz9TywugM03vGRIt2AZ9mvgtjWNVlxD" ..
	"+8hy1HQCWSu2vJIa2oeqXOO04jWJWlIPsXx0mR9Yge4LqUnHBo0EdwGLbl00iPtYemoxETxWuEWMtgb8hDKD9oRb5GYSlNsF2Apz" ..
	"fPjMUcq1QUU+abZHS3Z0ZHFJDJHmSMEH5VxXm2/hhyePpUl7VFgq5vduKziaHhel3ODfTgUPiC61jQHloBHRYVJ1OIcP+r2/OWtB" ..
	"Vk9rFQ0SumoofdAcdRMoxtRAmyKCEgHVNxTUfg+fTjDDXvqRFFWW9yzLxpUtNtF0N/IsUEm0TTZ3LnfqnyAKOiP3dB1hO9dTHZe+" ..
	"roiolmCAA6q3NdI/iZW38D52W7aSawC2WxT4ljYzRI/pR/UbIhlZbJk/TSePby2LVYdHqAVSFH3qS+2b3+pVe0ktf50d6rleWHrw" ..
	"GnjG72YRwNwhsj/iNljVN2ZHD7JDvC2okr2z1/tXGLnZm9HZ6czZyHdeWls80xuS8sT5nRMzrivNtfIMlxASxBCzs76cLuIns4oX" ..
	"uR+cizAEwzcibZPuWVah79RM4Pew7/4Z/ZCxkUZpv6xhCJpG3VN8oYc9PlReFDIhv2+gILkNveOT6w+QcCzqkUyWA5Ujs9dKr98e" ..
	"Z8WYiHFey6DTIVb+cJVEAz5KSQ9WDVpv0Ki8hoYBqGHUOLljiXnwhdrDyQoaCIOiEIPzaMY6etgZF3pOQTVuduIc7Lh+iPrsHWCT" ..
	"ko3kr33fuLuOaCv1ddigi1+Yqd8lf9LH5SVR0eZeBkkqS8bXSc+PWUKPXS1kIndjMNwEjnoSItGlX8vEeQHBrmP9a3Ji6ZFlhDe1" ..
	"BB7CVIqjO+Z15QBuMCK6GqTl/3UnDicU4v7CG68ZJlnBHbjrODAT9udhWac9KQZ/CMp5E6BYpRtXF52BjtOoljPEG9YPGs3QuZEo" ..
	"kBSAmcb0KKIkVqzXenCS6/Z6pmgkXFj7koBVAVsd6u6hwV3rDy/tSDECwZ8c1gV82H4FrP7jOz71Fglwe7nNyBnn0zDdK8M511Z9" ..
	"YbF6ZHu2d7x8vuJEFen5tLcZ3laWeISIAbtfNMHW4iU2WO1T+ZKQVAL+BorwKM9LyZl1SBAMXZa5uATD1KLFPxPKsqMCIjqFvfeK" ..
	"Z7L6szFPKLgvUYf8fQtCWanI2oQdEk1VMPNd+FUKPNe4LMarb5I/X7RPKdVyy1L6eS/m+xuQU2I4dzmGrWZFEOUs4tdekqBKrUzh" ..
	"4FU0RNG0rR1h4l60M6YKoWh0KNHOpcHS67403H1wa4O2rVx0awdEf2rMxrPgr+jbVfofyHQZmnr7lpl3W7r6qSL2B5sGzeWIU3Sf" ..
	"jAkT8CWNBGxQWqYsm4kAY1eyWKBb1OwPEWSVe/OBXOESQUHv9lWZv+fi766B+yoXZAt7XYUaj77up4b9eNRlbYxT4VoxFUqXrFKs" ..
	"eMn1V3V0x9NFb10D9+WY0A0Ll0mvs8ddToYKnWW2Q7whqEMilEAluEqMkqTpm7YgAP2yTXFOgvf7BZRt0llT7jfbTdXTYVQEG09U" ..
	"27mEClSIfoK0OkSxyoxQu8YVx325TvS0P5l3iwLJFz1o6Omt3n0nch//YRa1rCMvjE/kQMkn2DV3LEaC/LC5Q/CTcXs5EdTAAxG2" ..
	""
local PAYLOAD_P10 =
	"oa+2u24xEEAwJ+TkJgNZ/i24tXt/VbmUqRVVJmqGguh83J8Mlmi1LiIg+trcl6/SaT2Dbr4/xQtnz+f2BJsLhsYUXkw5X9WtT5b3" ..
	"nvHbtfDhOJiQMtwJusplMxMFKJ8fMczJRcrUDeM1MaJd+d1Up2kGWT+JvEhX49rQZKtPbs26aMx5E9XHk64LiBz+38n6IXf8kYGk" ..
	"M3EUp8aQpflPL2+5wHp4MiWnpzZc3KRFTriiYjqdZgMaVXAotp/YtZqaMabYqtaAbvftEqlXrpkYlilcRzaoxM3DB4AR61ldQYei" ..
	"gSVz/N3EbKGsHRUwcsrrX3AsF/guQg27WuEC6ogbhy6oa+IsrJSC0H0J+EfsD3XhjiAsxvatz1tk2tJAQ1p9bsW0bPXVSkz39Hnf" ..
	"i97+nWAIuUIX6NvPrBDDvkOA7AdJls7ESnRI4JE++r9MD+WvNYNbCmPYuoxjLibDRTpp/Q47uLVxdUsrF+GQn8FMlW0+rzG8+IO5" ..
	"yw87p8uZ5LvScfJlZu2AE4JU65Bbbau0m3xepyI18wvuVo+EaQkBMcS9JTRqoeWCkBH+jh2PyVN0Fuk3j4UvA+9oXLXCKvkKATdr" ..
	"aY+LsmsP/PhNAHz4MJDecCdCsMM5sSIfOVJuSBjkdFnE9xTAQvYw9ws9CdiUDpD31YY6OhbY5aI1TUjbOEK8aJ8oVlSO3v+hr1+m" ..
	"ZZ9ksK++YAqtcjs975GllLjvyaSXw4IClkmNVrR8FUy3BfV7haIytE/zdMLeOJAGq2cfEmMB2ZOX/E/ALxMu1p+A/rLls/tx40K/" ..
	"Va5x6FSGECuMkm8qpvavnqOylTqR8YEGxQZ/AWR8Kvn18WHsqf6d9XkX5AcVqgnI46Sku6AfByEAJFARMQomXcgaWQvR2oarxHH2" ..
	"kFecGbzIhC0d4eINU/vWs96P+zZ8DS04FnohM+ihEcvcdtTXVBNQzCOx5YwO0JLXFIds281qT9PQ77WrawLKd8mjYlwKFvVPGd1b" ..
	"5+NSjZCBhNcVOx1SbJ5Et7OyCXgglAzUuEceJ5vYh2byyRK29sSVElxVt4Tk9i6kD4rssCd5/ElgOktgij8L2BI6WawlfpCU8cYL" ..
	"HpiV6wOHBWX5k/U4eKUyIZ0Dvveub+babBwhcl9C44hb77dNbLl+8a1y7JJZv7e6znNxIrAI0Z4LD/AXQQ3r2YWeg5s/v1Ox7X10" ..
	"V+6nc3YYlJ3d7XPdrZlPW9MmFv9bkmaiRHYMqZ25+AgJpIR4QM6WFc4+AT1wsY2FxlY5/tDNh/A/ShNvqvGJ2WHHMSvkU9vPO6Y5" ..
	"peLg/04HN2NFi0fGPipWn3w+/fNWd0PQa/LfWlFedmfmHBtZW5t3LrLjTyjRQmdnEx2kPWZqiQ4+xZAf63Q2jZY4ZAO+XJdEvkCj" ..
	"m5lMqnR4iEak61LgAST3Cg62giF/Pg9UC9gySK/4X4hhO8IhQrokfDxzQ2Wcm893M0NFDcNom+9gePaGusIjrHxzXxbZJvj7tJ45" ..
	"p96pQw2hzByYgAZXhBggEB3RXKLpuS7/hx5MWU9AX+2oCbS8ZNJvbKqN8DtVOVveBuVhZGzS9wjzHKXD1uY3XbgChwt8Xq5dh7DH" ..
	"zOaIZHJkwV8XSzE/E4IQo8wg46y6Xsd9VJq2wjjOM2E7sYnwzNpvZ+OO3TW7ZJRTJtlrkyBHHV1gUxGhs7pU7jDQZkaYwj8hZ0xl" ..
	"CtHprpQgEkqxfQc/jYUNSrL9evCl6dZi4bHyjSY0LnwpWFO1t236LRSo+W8ITn9bnZGoQO24OLcfWkkkVPcMXDGwz9Puyy/pAdG5" ..
	"sTJkuwwaw60WEqDGJ6LDxGLYBg4syxmQmI+nIYICngIfbzKzSQS/jS4hsTf1jFS6yo0ZY0IyuC3h37+yZi76pJCVtL/0YeAZgsO6" ..
	"b4oKoiCIXdYbC0J8Wc/e/id1b6PV9Han9ZQj0SNxjVC3XjWnbaT7OlKE7m95jN4XTbd2f/aj0iJ6B6CX9xzjytBuGnFp8/ssGZjc" ..
	"s1Ky1s8lckfixyO7CFfErAvKTQQbyftWvJE9j/usfw1YiyF4kdyMLHt/yJk4PUoNwio+RN+ZM9Sk6LqYkltaoObdwncO9CTP6MPH" ..
	"slQt1O8KQELFojlLph1t8Gn/yMUxYiwwjovVdNQDu7oG+8A2+FW/MdrlWxoOHAwjWB6ZF+Lx16z/BPPTGQnCPNGcYKdG0ayd+uDA" ..
	"RpD68HDVP6+7UYNtc+dUFFj5Sd3Ljfx4AFcCPV+C+eZi6v+ElA41ZAB3wpTn5WG23t3KdTap3ysnaoapzCc+gHfBL3Y0haf4st3J" ..
	"0bhU/LraxmFwL632wu+q7BtCxMgaDc+1nzh6Q9oz0Qw0XXUeLYvRVm9v4vq56ZzfgYhjXlSmqiqkydwz2NIy1sacuqd3tsMt6bbD" ..
	"LdOJPAEUIi+6IC7vfdqHyNWvR6eFVFVxt3g4Z5U0DCCf2/u+/uS8N3frLcVrTdbvSqbqoEYZpaz89R7Fscmfln/nG+/iOjv8HZhb" ..
	"uH3KiMO8nfZDUULXeYIkUX3Ge2d45EhJcbg6ZGNilbwqEHCRYb6dOyC7gb31qWjo6K+folNT80mmEB8vqHQm6HR3wMIY4BXTsPAN" ..
	"U6YmGDpW48tYAgPYCBvzeyNjQ0mBssJyEuTdR8dpUB4K+ACa5EGFSoIWRouV4s5h51wtCNPh0jnFHtN5+DMR7lbqW0TgGTjg/ZVS" ..
	"5oaHlFuV4iKXge48f6+s0+Uz/dUWdzzWJG7FpG+gGaXlWbY/6N+Nc2viBmd0ZUfXgxgKyVBDYhYXF3PReD1uBfGe3rFvfNMqgJmS" ..
	"0eLjK40TerKd4Q4oiII8NcecfLW/lTVcs1e0+BBxMfhVHIIypht36jBQmlemzPxnUc1JKlvYK2y77gAr/IWzaq2l8BpRtwQVrnF6" ..
	"CxY3D/GBQl1TBqGUar+6uKn/rdfQ47L1mgfSLFi1rWLIvvghwu0WBsdzpuZ1e+TasO4w6g7Fvi7SdfYAgSiRUtPpjmkW3cjdn1BH" ..
	"Lo0p7aoc3/34+QE8tgKn036UH0ndjOtYe1wsXP7lnBck33/CDqWYx3xs2oA0RXUmzO1E2D8IuZx1bUbQLg2fflJTm3jMIWIvjs6c" ..
	"hxCM5mGUHcPETg8gktR0JX2gEnoi+B25HFRLo39yfs424hfq+BdRwzulzzGQW5yNpeVZ+prBfGGzFHmH68A2XnzGkqic8VsRcE+6" ..
	"8EDKX3cDlIc9s2y5GQP+cvlDb1OqKfN2Kx7Xs+sBHrz9++OovzN7D23I0zkVzCXtUZpljVTKue2CD/+ayayyge2cUwdVx8Esb5W7" ..
	"rmURt3cy+zKYf88WLvPOH3r/LJixaA9mknghesgcG5YF1wxro9uV6ST+KkZ1NrLuSEDzmRUT/rVRUdCtHLd0r6xQJLgo1t3djx3T" ..
	"ZNExNsoZV8RNwv9UiN4NxPz37bCluHGgkraDKQBZCMG6p/ndz/gZKpJS9yvLPMx8/b/cH4pGcxQ13rH80GgsFKqsZpBcdqpC5BLc" ..
	"KrYij70RMl5oMWUzjZhNhzNKm2DV5qMr74SxmnL8MNOqIvue2QeaJYLaxxNs6V4RHDV4nUDUyrlmBktSZPAtNz7zZC63UhZDurya" ..
	"FfA5h8YiH1tz7y+s8G+7dwjb0RM2XGJZNjf2K9SexsJByRA4fN9xcfLV58SyteAyNIAZ3znnUSY4bbm6i12IQhDMih8T/1qsmhYJ" ..
	"AdCpAWoaDiLQcl8QqJF51aMf7Lo/K9R/oWYhHZddS1R+4GealILnK4CNoC5D9Z3fktvNHiMw+88m4Fl0mUX0KgFWSZhCjogbP+pZ" ..
	"aC1Ocr5X3D9SHEUNNKfZ/lpaSb5iA4GILDESnLeNo/4bwO9Yok05aGhcRnv9gOlNLEvq3zKJbd82t40dS1BBnnxRJTqhxNhLM77S" ..
	"zM69pRFTKTqUNfEluC3oOQWBGHvv8r9+KIlLzmFCnLSAwHsdX3zVHjdUnT7aAZwXigJw60OYjTW1qtMH3lBSEcVfbw0HfRix2ro+" ..
	"LFUMy+TFYM7jfw/1hatpCWpYNYLYVzS8n7/FlR0XNqsE04a9TGmZQsZZ9J7CbGAH+G3MPm/PNnAur9KgXh/vAaii4GRtm1K1CmGH" ..
	"pDrDl8FvZH7GHZc2KSSrRRDYvLABqVBew/SzuI59QVclW/a/qLrFE/bIbSgEKXbYpI3Xdo2oqw/ji6mpcTneLIAHnUlDOWKeFZ6G" ..
	"KUezqDHjXarhiWIGzVE/ynWpmCk5fwSMJ7XKpcmfNNMlsi9YzEAF7SVYiUqjRONLR9ulyq1qs3McGPhlauQ+JqTHO73ejqKM6eaX" ..
	"yydsXYGoxR/IjoIiYx9UmXVslGZzAiyLigr+4VoWXx6cnkFi7zVnuybpihem9dLPfBzjsauWHtLn89XbUkD1x2sUQabK34KW41aq" ..
	"5tnGoxtJ2DXBk7jD+H3cwzJEduNYZk042wiy4kGJsl8qNj9Pq5tQ4c7LXSCT5BGdruWzkUERpMooZBS3vDhxoKBFJyQRaxVIQyq3" ..
	"HIfvbijcAP1JAAoaAq8Hr+lhgylPc+aGgWgEbfWBj9cNJAB751q2VTviBRxu6hzC/jwW7eIamwaDZfauFUlRtvyPMBCBjU41q8Gg" ..
	"TriHX8AuqmaBnqz0Ox7O2kmmnkz1xaY+S6ZpIEXrikgLpLZ5Hfip7Dz5RxvpOsg2AV+HY6a6LMIpkOtI8vxjN0rpAyIvCK3Hc3qs" ..
	"0DxwNsc/j37S0jlcpLMQyu3y11rVxgzsG05tpJJ8yK9mlhy5117N3uvo+YfRd0cVYxWnOz5fD9QzCcR+/9GDyZ5Iq9JxzUj5q73w" ..
	"6JSOgoLl7NP5VkwJm47AWM41lZ+PpBSKvc/SPjyTfpL5//KmbHIQsDrbLxNjXea5BHwjh7ZXvyMgyhYKnCXbIxdIRW2ZtdEoBGEa" ..
	"WrEktKvhmpUN2cZKj6ecyOY2xfEMh/Gz1AatTlO+TC7tg5Fz6evJz/mf15DuWRwdSNRxIBfgchELUwiShrPEZiNg8hWRfE1l1qZx" ..
	"sBTl6agnBpdQ1O7+Bw87gPZ+RlvVQ+HFxUFkuBJMbMOwvDcfWJsKe4zc+VaHlljsKMidPn80ofHfp6lmyz0XQsjlZ5WHKE3f6KoG" ..
	"WzPe4M3H3FB369SlhAy4NuVvYUYKYWvCze1Ho0BVoZ16X8/kxlWI2exE5wuUk8h2Yx0GX3J/o/whYhpjV0nIdxyJUijpzsq2EDY7" ..
	"1r4I/MzvTf+ZxQX1vxQtBHyjhgQlQUEL1dTO1gru8kc+2JNYQ4P8vB+VvGa6RYT9wMWtELAwAVlgNKlaxTuwBf3IYN9+YpJaJHs4" ..
	"BH9qHogRjoaMFJrYatxob13qlNPZnQQtcM+WPgY2JUgXMHYA5ojy0Ugc76WwZqt/rtH3YtyB+/HcWiKtHZMFZE6qrSrokoNjAtyH" ..
	"JglxJKOsIaHfHJFQDPIuXEwKuv6Ep1a6U3erH4aVDT+tqWbuqiQ5JpQPKpmODlueHUTW/sDnsxjDqiwbFa2ho/zimp0XIuzOndt8" ..
	"ngkIkAK1MnELk9d2gVOR/zzDtsdh8RHl8180XYLRJOuqoCLYrQ2S2Zq7ZOlVwRAxducgI3EZVw8QtVFYqaoxV+3vtnnB4aaa4bPL" ..
	"NXyLTawTI7S/D1CsAv6nSe9qLO/xnGe3CVCU6P3nlUq79B2UE5R6EcuH9E4j+IWsCNjljWpT9/5J7AW5GSIWhdVoULJyOxfZTvJd" ..
	"aU4eU8nNJeihfXtxe0PHMj1iLO4ntPOkFgzMNZolGe54rquNugZiAuXNSob8jbhtNMTgtnL0a9YKX2zzI1ZPx+faNBEyocY+3DO4" ..
	"tj2vGuIhq/ybMpNaRtQBqeqGaxjZ29Ug8MHBp5E8hGwOnvHznwTkruVg6HrL3vw3RjivJuGECS82BEbroKQQ7/dLthYIPpu5LsjM" ..
	"vsgqch+zrrfHobvu/2Og2qotabYX/ImKcnIHbR+lZVBE4LrhEwicKmXDiGjHLN2SiUejXY3lzQtw3PQLUjplGS/1bPz7yIUg4oUX" ..
	""
local PAYLOAD_P11 =
	"WYWcS4UUXT7KHjFE7QRanKZB6Tp0KblcUy36ZO22gSqf6110PBFTt9Ju2tfcWlTB5Kho8rcIYygxa1MJh9YRO+d6WbZi1wyVNBfg" ..
	"W5OphNjtoCvBIXWzk/xHlZul7v4kuRP56+y71Fa1hFVu6WUdIBKM9sHvOqglP73cDeTMRu7cqSlA/rqNZ1sAvTuejg/9fDNMP2ru" ..
	"iQkc0SvSiQjCLC65XQI9hFaJLK18nAlqHn7BBzNRsZOnqULWTEiqGR41Fa41zqZQ3zM1zJIaGcuv0PKZ/MPktcPRo3ioHWIVUz3x" ..
	"27btk4KiObVsHkawIrsBocY5poTlFVtSUmHbnVHB1avJ163UBrZEn78XcJoBfcT3tjTAbTfLhdJuZ8mIAdP1c6qfxIpEL8VNr9Ju" ..
	"sQZp+0JmVElI98AdwYlK4xOeiJW+DqFtU7Z7RUI5h+74JAiPA28UmKV3tSS4YWUZsz5oSFPmkW0tFQiQV7oI736Ve1iN1YnPHnb0" ..
	"JShuyl5yMVSxCXY9BUs8usq66IwfoTb5aNMIqgzR+zHk5jet2L/qSiAReqXAibU6nb4fICtz8/JBzx7RX1ht+nyr8ProX+CWUWFv" ..
	"QnozOSBS0TZRYod5JeoQgdp1r8hqiZXoXYgK4LFr0gP78PJwb2UYo8t2hysrstlpVsu+g9Ye50G880W9Quk3jy6DTo7iI3RA4Qzk" ..
	"yPcDePRGFnvQdqxQhuU7gyqx2xSl3NTSpxnDZQKDHH1K7FBMZML6rGxDvnwpmSiYnPtaYg5Sa9NvurOmLK7oULH8wQhbA3ReEkY0" ..
	"RktDn1ruhrilvRJE7CTZ/QAb+aY7Fb5IcyBhLN1Yy6w59Lr67B2d/n2GX4fq7HUKjNYtvLdZpR5bXPA7XzwVM7k8q1oFyRaGoBJ5" ..
	"ppHCmhR48YmyZSe903bhhIhy7jn8xELVtwsO+AWWoeiNlqHJeoRs+6akY26vX+f3h000pxnU47ocLaCW508vUw+BsS4ucEeV4jAJ" ..
	"ZPRlj354guYYGUYfs+HeT3gLA1FlucoW7GZGNMLE1T3sAkD9DLsacVEDKjjj3qgRTsNhT42kvjBKnfvTwvMln9edCEsMXAW1GF+b" ..
	"U0WD+CxydUQxGBb1gScAPMNiSzufP2IQAzavLShyVor/F3ntc8HpeMGSM4dTLx1YbUJCx/8W0gGFnH/7cdnCxu/n5fo398B72fmw" ..
	"kGgdwucnPq+Rc9z4XtWW2ywjtjB6DaM1fo9ZHJhHNMk5+tHgDS8cotWmRm6+YCc3SLsrSPltIK5bdyTQhrWYEvLC+h+oQVPaPV1u" ..
	"e24VynZm57SiQVqXkcygQFBBKBpZmuG4w49f9CLkt5Tk68pjUVSzroX/FhscTYnXavB7b1PAuCtIX9LgMchxe+3y0kID++S6wvBx" ..
	"eh7GvzMVKx4ATXb4IMuQTdlu+VEAZZHa0knmESx6Ak5ypOXl4Cy+tztzLwDEYuOMOwTh6bkipo/qdqSb/RBxCj2T7rRN8Qg2XfRZ" ..
	"78cZ5IzZnXuuRNT7r8gEtqwN5bXvEG4yLesI3A+RBtUSyvUcIYcpUVsz3skSKKMmDt9V+21HK0DRUn1GFSByo+D9U3nLifn3Fs4b" ..
	"IZVuHzJkH9ErAVCo8jOu40Gm/mfeVCY48KDR1ekgZU2TqprxkmyEJl4TA79h7qK+tp4yHvtOpKS80KrFEOr562Ps+nBSSTzWJLrH" ..
	"cj70ogOU/2AEBJehYp3hRNoRGN6BVSO/lkoFZDHzG7QICAI8mtdp8aP7OBlnhZTmWV9vxnINRqknpumvL+vcbhXIyizqBrv6wYGE" ..
	"R+h+zlGauIsRrwW/w7agpy2JwJd5BZrFR42RydH+tEdDRdHindzX84DQ87i0c2fz4AE4SicP7gbCZuGdy26/tC2X/hWwuY/gCa/E" ..
	"wrJdR2RBadcMIoo7KQEzLtkIgAW0GXH6NLAjsjDJ8YDi5XWzmS5r7N3Y8eK5G3aOeQa9LBhBWi/GpYipsQd2d6SkMlD9fuWgeI/f" ..
	"DMfEd13aV7FsEZChKLjQ5W2WgY/hKooF6fOPZ3D9W8jZepQhDw5cMy7Qbnb9UDaYJcun1azx+FTRbbOo26uxy0EmQxq87IJ7GLT/" ..
	"zEY0Cg3nSWjjNo0KEDrToaCBRSwJbT0Wdbf78w0HSQAjp6C0DxIwFEzmTPrejHddn1Pesm2heuuAvG5TFLWqFTXkJJOpxef2hGgu" ..
	"d1hiTsLa5x5HOa4W3eady1ZSbC1jOJjA3Mba0TDvRb/l/mRzv9ApbY19FpPfPggwB1dykCz1Pbc89dY/PtH7AI+xs4nNTZ38j3xF" ..
	"K7C9BSN302o6tqrqcSFePxqarGJav9BRIRALR/b7RXPM89PNFWwFt0wc0b2ch08rJk7RAT9SpeNNe+MuhaglKE7MJLeeJovateGh" ..
	"U+grsWgX72N4jPOE40SyUTs3QV90EkA5PUaITGVXCFT9YY720paI+DEC7rShHGoDQ+YKkG2bkUeW3sfc4OudvKz3UBv9oNJ+qEvw" ..
	"gZ5r7fns8c9n0PJOILOsigcz7vlLMMU/aDXmS4wzbzTcmHxFBse7jCmhsN0VFxLcihwtEMYWzydnjuDqYGq9iujMUZfBeh0kUv4F" ..
	"5Ho/6T8z3dj+PK227El1Cv+R6u7xmMYomBOhtH7fzV7OWVJYEB2n3CIama8WgJSF6no5rMACJoyYlBVoCAIEuERSrYUO4TDfrY9D" ..
	"FpJuYUJ+kS4ZsBnFwn4QSmLP4YO0popxmBZxr7wyiDyQLUN37KYOnkptnW4pXKj5TEXn3r8gFuxNu9SRvIZKnTdg3NcDq06SldLx" ..
	"esSiQEzkaq73/zDg6/JVHERFpREoJaTFK4RyIZZo5/cbDdqhkNSJx6PKCJZ6Idx4MoZfRL31knWks+3Vb8tycCxlt+mBMOzDDahj" ..
	"NAefuz6hdjajVat5l861mTcSs+w8/RnptbQ0CJf4ZEb0uNttVGYc+yJbAVFYfeCC1brHE85TY6ezDtBcbx+60EhO/Zj/hptSZn9U" ..
	"zQmINWel9WoqXy0KU9ZNatA03baGJrE7srTOnHnUCj/28Z8RQplU55n4D+IahY6FOCCR+BBGGh0igx9FDbbvKkW2S1h0xnzCLqY0" ..
	"BS862A9bpHqfJP2M73CPOLndyjUjtJ7V/YMqZ1cKn5f3l/9p8yEi2w6oyB7YNsgZkjqbN4+75bfh8uwJO3kdrwfW7a/cjHBrn09f" ..
	"IxvWOGfh9ODGOXXQyYi23f6VSHiZjTUFSyNG/0pxNse0OUonu3z6nV2OubFhvpvYiNud0aLoUVs0/Ado3SCkZR+ozCQEHplMqMKz" ..
	"5fo7uOTWyF8dXLcFW/x8x5YNmZD1fc/+FpkaMH5wGJjFhJhFGaT2KTStbpdZ3q+WwdYwAvbbhFHajnZKuQUtIZSeFhdIyv8CQZZY" ..
	"fR2J5pIl18DbWefDRdzWkwRO9UzeVfmbGoCR6TfOyQotk4QnlKb8nq2Ebz8fJFpsHKYaElteqB2xs2suYoQEaxG3QQIt+w3QbtQG" ..
	"6MBYAIxlcqUCJmz4vE2Yn1Y5MCklz+R2BP4b5safMzBlVM2/9G1fBADfSwSsKrL6zIoLt1MHwamZEPLbpkEgLsd2wm8M6xaEdtyJ" ..
	"YyPHodpw7yPkE7ZDFl7pFiAvfybGofc+8YAlzt1Xv3UPIvhdol0NoxsLfGDov8X9WWJCVslZcSK9Hc8nVG1LWpFblbhXG7kpqT+a" ..
	"GjGqkz3haEx286N8X/w+gxkF7aRveGaYJCdxj9I1QN6wyzPvZI/a2zyt5mKw+9h+NhxYgCr4phM/MXUYVo0bWIiWm0q5ZiyTFc+d" ..
	"Z8ZVkWltTo3eV6gXF4SmX4yApf330743GofBAdE0R7nD4OWe0GxFLoLWJ+Psl3BcBvbnM0CsSXWF9i1MyizA3Ka5q4GEjBDsvcmA" ..
	"5L27QHQnoke86Oe5/4QBY204b5nv+DpAIK685S/biMXM3OhJPLHnmRsxdeF6FV2qspxqcuWaecZ2OZKGXi8wEQVUoWBHYhJBt/SV" ..
	"9tiq95dPlCYHZuj7BSGnMGmg1PC7yYiIbRTESMzIqyfjLw7r7Vmhd7xnQHsfhBJjkT7hqcZuj+pDvRpCsQZ/cVPK2iEmHOSYz5Jk" ..
	"jlY1rQSEi0wNCgNc1f92Lisw2YAiXpgJKhgX0P+N+wprhXkHdf7LZW2ykc8g16SAK2PXzmbEGij4cuTYl0DbmMcry0oZSjcrTg6j" ..
	"C7lbwn71WgyrFB6o5CPlKe3t0QZd2mefhfzZMvrjaOITdjmzisNdQk5Cfpg/BxvgD6SLeXaQuh9N2jBak0E8eycmLvXvH7pWFtBh" ..
	"CG8JOUVYEFxxtP56WlewZBq3RLa6DXkZb/8SHvl2uV6F1oyer0BNJku1yWDoQOAuV9tUPCy8LV/AmPBAiTgaEoCp/WSKPZ7KpCw4" ..
	"v/FJsAEkHgIEpY7NzDGWdE58ftyKxfCo/ecBNFrzX+FZWjFBozgIZ7xkNdx87epIapZGTLPqkmSDfjeBdnfqTHLXX9OKxC/0hcrF" ..
	"ZA7xW2w/f5nDcd3FEokPKHPjSR7XStQrI0BmV1fYF+EKOiS14d3RiU3dhJVnzHXgxh6JF+kCJ2UXg+9xOP8dYIBMmFLS8LOwhoo5" ..
	"LTydOrCwMkbritvuGTWvEPKHOApEpoSSNlKdV0z7dphhKEfwjHGwfJMeCcZSS4pQz6X1xP+f3r4xLp/tbAuuGZ8kirweuzuO8LAj" ..
	"Aj0VWNwavCCUEseanv38b5Y46ckTWPvGmk9XSSm0s1FRij+YHXE2cdGudJ2468/VxBEc/zgwESqvgkQyOutlll+Z2Sdy4UyC3gIi" ..
	"+10B5j5mmE/HbdmodCZkRU3+sUN0uaFaKzOZgqRlZrAm4dBMES7QXpZVHZYcd0svvGBtgRpo7++UeeaYCvNhI1VF5IYJH4LEOv1X" ..
	"ImpVRSlk68Nns0jGfEW/pws1ojNxcgFUy3hIRN5CEjG5eVmbt0Jfw3iLM7Ka6u7uu1BuKUbf/BiFIlk1+YcdZ3tWg+gytoVo1Vl4" ..
	"JnZJ0kzkvtaMBFfL6pfBJ7LRRoItn6sfTVFFDeaGPmT3iTTO/44yFn1d2QAlD2FF3lRRq70lYZkhBSZP98+cf6lw0zcw+x6V47oh" ..
	"x38eh2E/o23zHY56CBgo+sIUJv5yG+Snr0FZCRq+ErQjfBlsgTdItKCWAibM67jCX0DSi2IHwNZE2QeXzpWGnur45gAnF8GhFSPc" ..
	"2+uwLITNXhp/lndpQ6mwNm5XwZV0mBeXVD4LOVRLgjhFFiJ5oBjHSfMjzHpFuTfcU0FG84j+1FJbJ9V+YW7Qvimwhvimd43PFvQv" ..
	"bpDtY6RXOzV1l6xxaAZGzOwLEi24q52c0Sp/+6mVWl6bynIqpN0rC+rNOea9Auyfr1przCuegVZEgB0L5CfP/UD9D5JUWgQf2lN+" ..
	"DO9jiDR5PhuFl4MMxMzDR3bs65wcQt41z/vmsj/+NeFFQ+SoDfWFdSt+GAAUfPwccLJ4iV2GyMBrTM51PdlKmubQJKhrCxvRFdCn" ..
	"k1Wk4edGE3zrpMAyfxYGWk/NsyaCnKpuczx7yhGvfNUK/F+6pGTf/Y9SHkBYNNr1v6ScgxHL/+7jMzIfQBOg17I/nYO+v9q8qf3L" ..
	"Jf5hNnthli6Uy+4ybdND7C44S0Y1/fUnLGtwbGTwpkKgOZ1uEmwnV5INe8IlfRLbY0Lm1GK8c+rSJtp8QnVyNym2McXsvBpv91St" ..
	"bfx97KioxK8/vmvGYYz8eyVG6Nu/4tEodmQq1QKVc+32/7oFPHZ2hmY4T93pReyka4/zXWTzS21kaLzqzuriG06KZhFNh7niXOwN" ..
	"dXAxLqf4CRaSZxFKNYSRu/5FZMjMZosxY7iGWQHWDeAhnf9k76A9n3OMvLwFI37tFYxEqrUAIJemZRDfamWX6OEhZcTqFoi4uBgR" ..
	"Tjbn6EN8KzgP6LlNegNhtR/76elMctTmUak8RvrMOTGEeF4XWhyytW5M/xsU5dMqOmJT6srY6PdfRJrJkb7xlABTwuwznXq5NwaG" ..
	""
local PAYLOAD_P12 =
	"TplDa8dAxKovBPJ54raL7flcOKYym/LH36cmguqayrJZdFRxFulW7M3F2f5wk+q8cU+pYSoqhWp4qcfgCTRk36M9plGl1mrEGqjP" ..
	"AtxPfN2+zP1KwQzeOueTUd58MoRHQEJHLCL4d355M0z/vpvWvYRjLzpFF12clLbS0r77ZXTPoDkImL+tusDyfr1llGO/PzEmvmdO" ..
	"Mcd0WErT5i/oLR0eMtsLB/E5U+BNCW2ONshiBaVkB2tAa0sc2bvvNk1g+6xvwOj0J7vLhXewYaxy13RAFn662ZCEsb6dlZmsiWDa" ..
	"73aEO8a2bnCyNo2VHvZ47HXVZIGTVmhu/FKSpPngikWvF1uURLpQmS1fxo+h2ejKYXnTCElA+g0uiFYUUobG+Du5mbrL7rqH0RD4" ..
	"hQVC3bZAeaXncQzs8n6Wcb/aVHaiorsqFpbZGNwbZvRM4OccaznvK2HSV66EqEurS+1Lkd7qvxMJaQCrK+aZveFg5k1QLj0yVuyx" ..
	"jIsrz3lNVHFzH5mrDMx3+8JFVm8HP8Ncz2Huh/4HWuEl88eYBCRQ8BmLTQkMlMn3K2zbRMhOgvr0wFVZnx0ekpoOb+R9XuVQqz51" ..
	"nsuclVJH6dlaJM3RN8au1deKlyE6eJSM9Gt8tWGDSaQfhlAnX7fbQWFdYjDPqMMC5qs1zuwMkJadC7Ektnf9a9eOJzmYdlNjc87n" ..
	"bOimQOulnWdrsD2J757Ccj1NIIZnj33k9v2FRr4s2penn76woDnMd5UvQaPzTmET3VV1Z/NL+AdBBhEEErgJapQFKCBMkscK10mG" ..
	"sLk2lDzWlYrcbJ93vH88H3FHsOmuOF4lu3CO/da2tc9Tq8HUuH3WVjFPX1htXhJCZ2KoPlLMEq42MmTNcjLUG7A2tS5z8ZOjfro7" ..
	"Qo8gjMoqPingea12hLXTjSbesu7SRnD6J9sU7nuGwHCREij8mutYXW+MWDbgACOkz870Jp5+atwyrBpbrqmO0cIvsZR7WsVnQLWj" ..
	"1q53rMkbGS5eK8FS+Jeq8grRc5tWpx9dbbNdobQe+XDzA7oodrHe4D2HJYPyzQSWYdCP3apeyBzVFD/+sRJBTXI7a/f1XBY6GX10" ..
	"N7vu2yzwgbLcXNbarPunMnuibrVWl+o6VpslvYFSu369O4SWZDyAj43ULHCkSquXh/yPh1Rhz8DaU/hTVFNAe3YSlSqWcVvkaiL8" ..
	"RLyS3Bsc4xxYkpI0jdkKTsMGDkhqFnGycyMSYmsNK1HfhN8Ljk+MWmbi0DlMuygcUE7Bz4s216WwhMnCryUaED9C4VX8yamrYtcl" ..
	"D5xfOfG4eoFEr8/3ESBtQFzN02Zx++wRtdFitSouQlCBSTt28RrUDjRW9QVB8jr+6OF7Y2XJip3SpPVSYol5qbuQpdYk0djbX5Il" ..
	"GRBh53dokaw/aYqAOuOIqOc5Fvq68tVNqIxNaYNeHMh5RhCq3J5LWQ2L9pN68bafujsV8TzyCSv4PiODT9iQYYaUTQ458DyJjxWQ" ..
	"cUwQeLsQHWH6AVIb/5LanWjcfDay1qLTEaAC6J304DimO2NmKZTJZIUrmr9qJ0iQEN9Ev8wcBXA8KBGtHKhf2Gkbhht9SAngKZ+K" ..
	"4r9sI9xA3Q+k6AjO9PEfxhjfk+OvAXTM3j258ZN/vQk59tod9jFAHIIq9tFo6b22QO1VhyTkANY2bIVLVCdYCuBluFVSqkQ4g15M" ..
	"giqoTfO3oGQJeIYLwVoBDkMDhXLcn+H+kU3zm5LQtoKia4r0reyfRXcildjThCJCvelaotPtnmKvflh1RsvY+ixlTYXTCPnhzp/w" ..
	"Sa3rVG9szLeEp9+qTgpy8artYVO5ifdbOPVeeIYzkK5qEwCQemv4G90aFYudHFAzeRhRUinqoFwp8w3QIyEYSlVpGya6qpRFaaFn" ..
	"E6YNKS9E4jcomtUjP6YVe2tMv5KWmrFaVqwqVpWhkxhGMCuOz245hRbGcekldFdrR1XYIb2voe3QGWc9j3gEYi0huiEb0QIHHErH" ..
	"ZFj792xpDHU3a/yIbUtzd7km5ioZycbcZR60YWMOHKtT9XPTyB76AbqC26WKwFUuS0uHep+cs/ifXdMFkfFclcskA/52ZsINPIXb" ..
	"udy4pr+xI41vIvUvGPhw3tXz3t6M4YvPEM0k5rrh/TmfK0e+tlIVZMfKX511txXNY9Gqsu2vVlkVd7rBqGCZX0SIInb3cu2v2Ng/" ..
	"HVZYvq6WKybaFgWGgKaUgcEWcmpjkF3ZbiSstb+CYoqb4vNQcNgubqpJ/V06py02qU4s5NBwvnXxrAnW76YYqcR3LuddKKGy5YQv" ..
	"EbdA2+4dsnURy+rpyp9SHmtGDW9ePbbwpMih31i7wpump5LduzgWKNRqLmnPlxVLW5W551MH6j5CeA5cxuE9p0Wp+VYjAlmSMjlT" ..
	"W3NLtk7V8lbtKcDMsn9GEy4mhYX2/mYO6lOwx3I06FrqAtdeXK0GkLwdz3NhxfaxyJ5/ciVuVduy/QqE2ftif0koHDCozOIRRIPR" ..
	"h1gIAl5RVZKFb5oKmXgYSWxvXu2au3oPSFByu93oMyNv3Q6OwA0lfhGWpIzxCb+WumkJBRRl2vnONA3EZbMoc/eidS/q3LJIiwKX" ..
	"z7Me6C3e8r34I60kkUi75cUYZR2mw2nSvq+cm8HVFhwA+IshhqAZWXfOg8A6f/aOdvXTK3zZJmzx85vmPW0QFw7aP81Jdwuy/BtX" ..
	"A5IMzLCQxAAfSZ95anPxR0gmfJ8vF8YkVjtZHTw6FaK2ZFBEcTHcsX1bj3NmW5GqKNvy8BLVZ+fBFNTTFNHDz3oeBO5HztLWOhSD" ..
	"mvhixAFq5/1nTees2Idoj2KnZdutvfntMiyIKE9gINe0B4CvNFCByUb3shDZGgHFVgtVNsh/qmumoDZ28j6vP+f62nJRV0eO5LvS" ..
	"gk5e4gOaOkkoh5+35Pef+8hyrep72JImGVED93BMtsSB4aHyiG0Oi4SYNnsM9BqZpW38yEbl22iMyW68yIHGIKGNIaFdNWQFZhM6" ..
	"eEH6Lq5dkwsjDOn1QcYL51nfTvVdLCPilr/RxVxM4CfnSUfOOVl42hgudKavXxtuRUd1auoUAhLDQIyRNz3gv2lFQnaLIMQBOxxx" ..
	"uILNFfW9XT0Z3CLUz3s891YLiXkU7lz/NG2cZ2k7djqpSVHBNEGBXRbvQPaM/sNtyb31Hmeo+Y9Goy3E8koSrjZ7U10tsSGrjnGz" ..
	"m6Zu7obrcKuSE2Sx/XXmsjD3SnchCAruqS5L73lsF2CoOhtxCsPoD5Cz4fUlTG1oEWi/YL7yDKR1pTT8DeZ+oUg80BWHkDApi+31" ..
	"MNBbqO1+64y9k0jZvOr/VI1m1yECLL0FY4JbIwNoU+4les/lAlDVRPfhjiqtjyexIAgvQtSvoLCygx+kwW+BDTx7bXovuXGrOj0k" ..
	"x5JO0tNBHBSQKkOC5YrN4C80t4yE99wa6v9tvbv8849hJNItv7UGX3Vhj5t5jdX1BQNh4TbM0xgUl080gaI+tviiMge3QL99T/14" ..
	"7vuK2T0Mo6aRzYrCQEsaeZ8DhSy5ki0X3BbTtwO7XUsOl3onKXp2Wg0ylzFsZ6oeA5wd25PU1y/IGDk5xqtKFIM6zeidxY0J3ZH8" ..
	"gYDKn5PnwQjDcekm8oHp8zAu+pqOfJVF7S0qB1XQ5FzU1YgCtG2It0+392Ma5zwcwnnlODYiouAOadsXO3Ue0V1cBUgBqOa41F6S" ..
	"KY3xVC9Suyx0iEdDSvF/WawwsiJiu9ShMrOQwHEq0wox2erERUIAxMZiEpcofi621V3owPwZUsBIoaVcQqE073aYtWYGaJtN5rz+" ..
	"FcYTFGy76/Bs/gN8zPQ+EsZxf3hHiu1G7i3EHPMV3DnT2urdeWS1YNvUIxxA+9GdM4KY3yhRLjR4eXryUQg7JQVje3GbKoo1HyhE" ..
	"lRqvlEmQvg/v9KcwZaTEg53EjqoFUj4QWGWNpTXQQWIrpMAWMF8NFSE21cCv2RcWv6ftxddjajSttTt6ET5OQBVBcvtAk1BNKheC" ..
	"DEZkTHw0kXWFzG1wTUgz/s6lEwwbpoiSvUJl+J1brw3dRAoLeq5fQl7d33JltOG9PHQJHm6F7e+K5bJMA3ya970164vW8zgDg3/0" ..
	"+qQzb11UYuiF0Bf+lsCmSqZTHs9HF8CboEUWaQzAtBgmiTCWomnNvoGL1ZAu3qhSJlYGKxBp+9u+IXwmXtJn+tkLTYo5jfw8w1wP" ..
	"MLcaIWgmet3XzKJKmPShDv3Jw8AqHzHg6Th2TrhhzNajeps2NQbAoIUvnYSo4DR0SiyiRj7oYu5PQJuX/UHtGXoaiA2a5HZAkmQt" ..
	"Dy/wk3UezxfBctN4sX0YUjQ+e9BwO3gB78FVFUtVH3gRZ8b/dqxtGiDVVKrML2GNQK/YC1Zao28NTuzc/SY+jha/Q1Z+UkwR8yK4" ..
	"nlCZhkfVlu+EGOlkphwcyUPF5LBb0Q/zfmL4+fPlAELjYAsy9Gmut/DSuJPyNQSQ/F4iSC1q54cSgt3fh0S/ezOrv3r+6dTI08Qv" ..
	"pqpgPrxtOS38kZE+wrcdQSnTJXsudEGtNp99pUqEjoyWdYs6ujhKnXKmfS45eNLtmUZKF0XNRhX+9it6JDbi87w1+bMv+XbMSCCv" ..
	"RQBjrK/i9uUvAtAyuAdxBFCCRTZsNALq53OioCAxYsojVgvJWFNOFwRBboBXOZcFe9S7ehtFfHkLyR0c+qwASJX2BPQxxLptrpST" ..
	"fzbrT2pA9ickforEw9kOtRSRHUh+0BbI7mGqwD8smJ8++53Ypi983w835eHsRZ4gadkjfTyj4jvY97ZO+Mq0wevUojESU5/W9f+y" ..
	"3z7bsYotMrbSzrJ+95nuCn/JAC/swGDMeDKA6TWXDyoTUCnDr34Fls+NtWzFJcdWCLAQh9dpqyozz2B2ze36n/vbmCLq6OZWjEHl" ..
	"QhFnJnhZ3vKRfoWwXH/ZdezPFJszc1tGVvgCXPcUO0R+J/nKg1AtM6/EvU43wQ/420l7YSXD86LQlowIE45ticeae0oE2yGMHQwJ" ..
	"xXn61SZhs4c8c1Hh6f5SyvOfriI6R25aseX4J/RUyTq1KVGPaRwnoSsq8Or/aOauHUGB67JrHgsgL5Masjx/HXMa7kKohEK4lzau" ..
	"fqfgM4mWSnyDEUZ/YgRfvU6yseKLFfwIqCCnostTk+zeCmP0pwLsphblFZ0Ay5Vau5VatS7pxCag+MJ7Og67PY/9GRLO8qA/yzrs" ..
	"SPJ/6HmLEmPgFzLyQyW4pXYqV4qpKvsaOO91CjnUUnVdzarMlJ7BLbRSnGNOIURWkrqke/jEmMvvEGNslG4rLK3YGV6GkIz64nFB" ..
	"JjxrnITnAGPpoPVQszKuJNbTHa4Oy/AG7rlikWQg00b1sHrRuxn/ck5D5CV5B2DlorqfsSL4q5aMJM97ZVr5V9oVV5I1wh3yLVKn" ..
	"ILgTqzrqaieCdKw07I05rEFVB+w+UvcE694tzJ7cAOE5t4pdeLaHSgPcaE7iSebfaRP6lOiHp6y80ARxrG02aAipEQPvUVz89QcU" ..
	"q3xM/uozfobY1ksKtCb+ABtkbruVqzyCm6wIRVcWWgtNX8vuGWRqKX++z1pqbLdE/4IepRhodZuAMNAglGDzQwGCo7pip6IoiwgA" ..
	"Z9OMJJ4ps5mOS2KisUE8EBMiN9Rs+LI4HdN/Xkg2Kivk0yK4ilw8UeYNJftnAKXp0flqiAdiDvdECjf/6QTh8b5LXd2RQaLXK6EP" ..
	"dCU0PvzYygSlaZbNKwxfQtksvcVGqBrJ7io1VJpqj/ZnslFai49IOqPJmV+HjnbDO2nWPfUy7Dbeo/G5/tRnKSESsT/AJcKU225f" ..
	"ysPFYuFfagCVwJgIzU6dG4Os1h0wy+y/LHuUDUg2mqoDPMrHSH1uVQmdVhsTEMNQRBNn5CVL02lM/yYORlIsnKogk8O2OskvntDs" ..
	"vC6djVooEz09vC/sI5o39fm7XxffiJrsjLYdpmxU1O4DsWQ6cjir3dFzaUzpCFiUC33T6nFKcVc9h8VJ0lViXhb7Mh7m8KNtbyrJ" ..
	""
local PAYLOAD_P13 =
	"+QPrELlVSIrjr6ijUMAzdolMCPKNMXXCrgUpCp4Sjlhj3eE1Zv31tuDxDVMOdP9P0QTVUqKBvoVWBqQbmjl2ZnP4oioffJFTQYg+" ..
	"/xNPQ+RpT9IYuuZGVSYvQPMYJnVVf7B9BzZ3v1iObZ0lO2sompvIVOC4pSmzghRVvBA4U9ly5O2vpRzjJ0VyF4dasUu7Pr1O90qF" ..
	"p5vXaHfos4SvT9+TxX6wuGZ5H9RvIU/1SeULRFVxFML909YrPiHSczw6cRIpuT02HeaGqSyv99nPfFQEttNxkT/te2bdZh2w95S1" ..
	"bvJCncwLLd1+dhxEBlYqv4Bftv9ESsDOlIxPDa/WsimJsU+5ztcQetP1kKDkYxALa7qnx/FbfpCI6VbD20NaNn+dcArw0gdASSIP" ..
	"pBc+Gv9TSX8ZMUkI5OssLThoCj651G97SfUD97nn8kzJbW+ONXOj3nQtvx8KlcGK46DLD6q9oU7OyZcm7SmuMA4ek/e+WP3HHCkg" ..
	"Sw2v19nOV05oLRIBqs+m+YA9z17MyeS5tZmVxp4NSkO6Mzh6UgrviLTujNUB3cN09B0H8Uf5s9+JgucbKQVj+zxN+f8vdiIzCgBJ" ..
	"KYDqlkgqiTyE81Z/AJx/s9JyfDQySHZu9I/ylm4noZnDtf3Mk4EcW0BfTdZcg6E46frr8GQ6ENLlM0ch9nmZStsyZ6t+Zm8hR5rR" ..
	"07/VgnKbHwoFEwQxDLb94iATul/1/ghHAxjvP8NhZgcEu5dNkDJ8YuwKl+drfqW/tf3Q+wF58fu2r9w6DEMsYN69StMxeuLAme+m" ..
	"l3gPh7KhXK5oC3gxp8J5eBWvlStWayo2kgAxTlTz4+PvaYHEUShugBV5WrtawPB9HeDzPRPs/qKjbbNCrC6j8o5LDMZhbmDsPws1" ..
	"3gY6Tuw9Jr4pni3kjxKSpTRoGU/3yjibub6ejMLneyx5w5fbCDc8D6TivwX7vu84jbjpv7XxqbBjXqhKPAoK5+M4wrn0UDiO2573" ..
	"cTVuc47qAsNBusMyM0e59nX62XP4xyT2njmmBoQWcnxJnVidD/hBCw+2sKfcdRogFoUeUIeQExpAsPb0PTlpu2BlJCqfz1Neafsb" ..
	"QvlxbkBS0rPLEzcGoTDDuxtBwreMQiCjp9eBC3TENMB/fwOPldg6f15G//O+cSG6nwfqYMakkS1aqIuNz7nslkqYmTgbNcrfcsxB" ..
	"NfXyGyr2N8MJrDaUUfpfWChNp1T1NQpxd2bJCqhMdzHTJ6bqGH1CJWgUx4H0UqKCfAOKEFJGxSORzuFTL3O4ekM+8YrpaL50Q5kT" ..
	"c7FVNXQ3nIBBpqCxTFWZZGV4leiHsQOuvLiU56Q8wbqL/mt3zFLUVOx2K+5jPFPCAqrs2OjOFWMU2IDkrcu40IgGiollaerDt0vT" ..
	"U2dVHHLjsbIqBXQfeCBvdW5sMwgtAYfRyvXZmKekAtvdDdY3NQHF2+L99mnIujyKpwThmKoZIHRybwOnZQxjIJp+dKDOSMXkHAtW" ..
	"LcXT3lCmJQf/7BuvRk8sRxzOT7nP4HUKHChkV/GsATUF58FCQABGM5J8/JGuPPUFFQSerQjmUPNrZk55wZb9Kh+1JlnTa5ZLxb2z" ..
	"HglWrcjisTkKLv7McLncePg0ephQakXW6Tl3UnlRjkuk+xH8BSqdmzuZubmHipe8GwQSTwk6H6BsJhKL+QL+CoQEWwrMvYM9eA4g" ..
	"MGb+YCqxlbkMDg7XAuzlcAnYNGytXc7cYCUzgUs45tMew0wWkR8SPJPc96UPUd6S21iq7PQHu+SJhM9B5vcDwEkQyGsRwAN9Ei8o" ..
	"5xPAwxpNq/3kkUyWTd1qJHPDmEIryRkqsa3+HxnUbnojlYpx2EPhdNqb8MSrgOx9K/DDDGoH0PotM9mdUbnt9vJpcGVV6/A0Ip6c" ..
	"pmIt4ONvnYREhIw1MuoWGfZWogFT99sVTizpYYRcTgrVVMejaUjNsdQR0rhCkXgJLf70jnNYN7jaREonA6PIv6w2b88oQvLeDJ11" ..
	"CJWkuaLuFiT2xrzWV5DwuWECo88PFbyU7T6Qf22rHSXkM1R3d2VTfGSBBBsqVRUAuv+Ky6W7aXoLL/lWYXItldH1k4f214LEV8/1" ..
	"7SHXHyns7mG2Ve2fRLlIejmx4X1XIvmaUqGXlvZDYlls3B90TGGgbBr7HNhIiqLI2lEGcNPaQEDQYEKeaZzaCA6yEhSWIgWBqX7L" ..
	"RYMCPJ1X+b1HEtg5Ukxq4E+L1L7obXa6e06yeVyVIfU8vG8QgWO1FDH5E9/K5Z0FjGtwHI7TfS5JnB7+ZEEj3oY4a0g3KDq/zSwt" ..
	"qtE3UWDFOIb6xXs8B6sHWK4DFKo2DreIFfxIPhAWI5O09vqgnK0M2k1kPsudxWueuNZMrA7zYqqG8UJwmHhED/VrgEfQSD+iQDqH" ..
	"ntPPQG4xol50Fl+yhi3EAkpJtakfTp2jJ19s3EW17zy/B4BlY+t2I6jHX0NXBasre0EHG7wuHicZ/SDdwgnGNDuiwx6/INyRzFcT" ..
	"ENiYplKjxZcXoDB27U6PMNkbRDihmNdQ55IZIJ5GqWuQQLbGBnIvjRk0q8Vgx2hBOoMUExmO+/0HCRBZP6NOafhTO8OG60Q2IW8S" ..
	"U5D/Vv40f2sexO6C2FMd5HT2fwOZCWkXT8SeY6kJEl8+dWJqghKZ1ltixhEU6Gk/YXWn4W42NngkOkDo8gjk/5dNs6fAun41bRY3" ..
	"eoFegNVJSyu7g05chQMQ2qHjJoGJ2MxTb7swDprBSelqwJ2FsXP5jl0pPTX1KIDHPSi0PDOfjqJCdB2bWoiqjcRRJzzcswI4uwZ4" ..
	"dS2A9iXUgp2ihPi/y0NCHby1gLVk2kh5dLwtdBtENGcXbrsd4Bx+T4dRe9LxOvXzNJteuGCKsrM2Ptk+qMa7Cp5jIO7oQfsAESh0" ..
	"hCL3V+hWwyZSb7g/rjt6J5rZO75j+2lcZgFdwg1okOCGL/7/RJkL3R0HYT8xKDvwIA67NTef1zFNoLRb+88n6irt0kZtSnofzM1u" ..
	"zlOHtbbXuh+Tq5EnXCW54WE+ZJFP9hlGFQEq1rbpfjSZdCnUQbsR+qP17uBTMeXAab3nwjyywvMjscenxsmHMRHwlIKRW0mpfvSg" ..
	"yqjfsxfRNybvNm2pADY8nsvif4Q00nSxQeew+8ju1B/n91N4dV11RAKRgB7KMaMkTjupfJXcwEzMA60Igyq01iNijf7JyfWxVgKZ" ..
	"31L+ckrg8+xH5JQPIJlnU1gPdofTgwZmS1N4F6/EpaBLjDWVCqDzHBAHMYWaGmLX7VQMmJdAR7PhtR5e4LzVqVXH7uYDtNU0Kz1m" ..
	"soYnbbIiHe2ca8FPZDaGSZWXjJY4mLJoe01je2ZaWDxPFmBHWtnAOWHW2dsGG/nus/+m/fgwyIAPny6X05CEtWGIgGEye0zQE2bd" ..
	"WFR9Z9axDBJoXRWg+wfw+8iSkjAb+UAgeX8DuO7tGmP9dglDgvALINmPepA/ikGLqnaXMU2kC0Shu3VlZu3hjP5NfkckeEH8sEFb" ..
	"JW1giDYPIHucwVms0/77m7zaBY+nVy7SdectRt5EevFzLNx/IkCkOBw54kYqk2oRD6a5i9lzvvmnofY7lOtdHor3NGJKpDcnmjU3" ..
	"jb0bRiQSy+ZmhJPChBU7jgtCr4iWwMmBrDsnyflxtvEHyQ5Rlj1LcE8ihKf29+hxwojQBJf2GBPveUlathTd1O15mG8uDTeB4Acj" ..
	"oi9/EcY0PDRhOCrd+yrgEYB2W9RaGdbwN8QCE23INvLK1bbL5W/m8oRcl73ZHntHLq94Qg1HwUYROfhVO2U5m/UO6E6w876Ufpkf" ..
	"/XckosWfXI+5ZQ+y6i/eZak4KVl/0zFeDEyx0/3T7jCHxwmYaF8oDhaY6wY7ww9xdJZXcGZn83KPcemleezmI7/LA/QQuuvC6Ff2" ..
	"ghIFPA2hZHfRm5Mqh6AWrDQFxEu2rpHchYT9LYgsVhplA7JWKeou7VqkSFQMIDpxLTkgh3Wk+J30rn6LhQkXWcpe/9BrPPHC4Z+e" ..
	"9LsHje083BSFM22RXZJFNgGl0sZ3gMRNamvNCT1YTU9NxRXtZVHULzBc1KtkDTqWs08shKsmj90hOwJ0OeDXgALjd0U7jTla9F5o" ..
	"6DnOrBcaxnNtHC7uikusJ7yuGMdpJReZgHsh971LLmijEWjnwJy+EZxOzhCvPJl5YryKVz99uJ1sK6TPxDlDhI3UYxCQuNtFFcxw" ..
	"pqdoPr62EZ3VfBHgnNLlZ/G6KDnFUFvMEPjYphvXtYNDAUhBAPZ3diDMBydFVfZizIcmMaPak0QP0fMDJkjGCtAyyIvrZzvA2ZHk" ..
	"EkQNuXrPDAHf7z8mU2ICb/oHg5eKroWU1eT5evRnS8X5Jss6zAQEkhU5EF78eQrRYUTka1iOsvqA8RCjzoPGNh/UdRD4Q4/GdBtl" ..
	"Nu+vJp+/9uMmk2xyaKNdx/CNrZOfhyyk82rE3e29HOwHbf75uRVjU2GZxgphY5KX5cfEBlRd9gqXOpbwhoyOiKybGTTwQf/3dbV2" ..
	"8EFjx0wKtmHi+TXR4xqiUnWkPUikIAIMgJPVmVMif7iw5csMKvzBM976P/NumGul8OGguzqdo8NOixZwD+wzcw1c4Xw9ma4dEI2L" ..
	"NEVh4+2zblazz4xYIyqOEwxZhndL0zv60yauws3jjOMfqPgkdfvLjZHL3MtiMMgqvwHm3x4SUGZe8Np24Rio0e4v8QhMG5mRzfGM" ..
	"uZd/8PGw/CWmWUj5spzSVAlpuq4k6y0lHmagFPCfAfZ/Vgkrjec0VvguSuJpPyqQpgScjGeXIH7q8Q769emWZQ/d5MZBt6t/iMwc" ..
	"unDURurib/MAgpvRR8htM58umeNEVQ+2Axz2ysK5RNAmv5AhfDr/E571yCZmBNW7Ayf64tQJ/2/c8YzJ4vLh7QCqXt88XXcqKfIo" ..
	"v+3tXwqbHyCKygA7GfqSh9iK7c8suswKwjNFSqJ9vSWviInYedaxJfiXZgt0e+Tq2Ve4otSuP7hngkYYrQVxQU9DyaToRuZIMh8G" ..
	"d1WSS2ZtBs0HRfmr13uOXQSyekT5waMU2IiVOsRYjoE5rHMD34EXygQ5VHpQ/rfy7pKvVnAccbOzrylo2/Q0sTSS0XZgqkl0cR86" ..
	"tzHMvvxjsUCf1i0JdUwMF1VIt12X+1VMqw6BG9ch8qh2xHDVrYDp2wTEIcoxQ9ZmGEGFijTZQSOqwEvStwxiItS0grAYHToSiQTo" ..
	"yO6uuXJ7XVfPe3Z6pr8qjEv4+VVKjciYcfcXfwUPgJi6om3ASY7nM6R9gILCFaRtjMUwnic8QgMf5kWpXYCiw8kMvLmb0jDDabFY" ..
	"+HFmQ3tay20hImVf3w3yT5YEaFTWiYMQAZQi/eMWl96dLh9P9xILAK6/XVU7JvVMS/DnYqYRZORWfTUl48x8WiMzTNOb0EGuIM3f" ..
	"zb3VSMtEUixzJn+iee0zSuNWQ+q7TNvnFcvG3lKHZrupn8LFPQ5U3EMBLoogOybwmTfv+3PSMFWGh+QNaW+zF87uwmi6quIrT/WJ" ..
	"/kWoo3fBSdZbJ+vGQzM7CJi2vmr30q51QC1DmJmH1rpLMjiHj3u9AERnfuU7tqn7MKrvtgY3mjHaxTdB2y7bSREPr7tyT5pmAAiN" ..
	"aGkyWAtdD13lFuQT9b8tOBAvOVf8/oN6PYC9ZGDuOwIfPKHkcg3gp8kIuVFpFwmhl6vorz9xghjwPqINMV7bzouz21ASHgObaNtb" ..
	"iHGtESkn/cQZULin7Pnri8JF/41+jsJ2tPUWDVGiKZPJbTGLNTMisEUsw942tqEqlPTk06QRlCm9/85rCf4EBz7CA07VYhW+OS4P" ..
	"PmMbXX2bzvjQLlntt8NIlZFIOVF3tH6ckjDxOlrz4iu5K8UwEa6vtffuN7BkOS3LHTZmp8zsbyATDzX5bkXbiVNe20eXnUkZtsYt" ..
	"DxreryqBmjYq9Tem8GiPANbvWXKAhonTklmHtHNSN+VuVzKObj5FNgiuM4SekryLF7qgUjkCVBSZ4C8P0prUz7gZYQ1Zdz5zyrlE" ..
	""
local PAYLOAD_P14 =
	"CGfO1v/0+rGJkNN2Hk7qOaYeWazO1lUi/bM0gJ+RxFwQWE+LVhRThSclk90oX4jaP58ld2l5LanppUcEA30YOoH77wZX9CWlcuK1" ..
	"THCntd8s38zfU4dd0hAjpjjsDy1oQsqOmT7VQfyRUtTKTIwKgzsS3IE103vKhF8jZuAEqcRVmm3IiYJ8qfdMEUWLQOaEGr+HhFto" ..
	"CxK6zYT/7hoap86i1Ke+WBFwwE9VepKxv9VT+ODwZXIrjQ61OOUFHJqGTkbasCUB1/dy+bc38juRPJA3+LymyBG1fOY4FGsjf2qj" ..
	"0Anofpk6MZutKIzf7T48tnHH898XSO3dyM7RX+qkrNy7wzmxQc5Wi5otJfAGc/8rWo4kOJue71L83xUEEGQdBJ6KGdenCgSItcJ1" ..
	"xHQ0MbGqhNSF+ongqQyGTTLcxyL2w/53CobJW7Vn2/RufmZGowkiRoTWyn4LPnS0l1s5PlZ0u6PMAybhd0sWqQIRN27BtnAwI8KN" ..
	"5mOkC6DraARuR2HwnPl1K8Ahr31NfEBRaADeKuMra78CR8pXu6ptGnm1o1d2ZYhVpYqIcEmles1xXLO18hwkT6QX193mcw3zPnl1" ..
	"I4ssaJIanDlhUvrNlWW9kiZMljE0JTdPxsBGRK6ysUg7viT7nQsNL5VOOMK+05bRfY5egpERrU09dz3fWJnYRrb/wPHtSIshjoa8" ..
	"xGWYk/WFbENfKiIrcUn0oWGFiq+89CeTO4O8x/PC5TMGsD+JgARBrxHwEJkEOjz0hn8PqfqxQIsKgrBT9y1FoV0tb50sOMbX4qR2" ..
	"TWnsmFs192IsjPx40oPch3CN+BpotCxIPnasPhU2GjOz6J0hfRbIlUCumg2k4atZZOHhyngW5pDlGHob5cU8uIRForHIoyHfDw9c" ..
	"3oXtBSAxULQ95b3sHekTgfLXn9nrEeenwwINBUarqiXHsQjSxwwglxbYeiSTZnx4KMj/WqXcRecXBlEQ96xJ0kLeDidVB3T+BsyY" ..
	"twnnCZY+4OurEBI00CnqB8twygCtjGZJJiZKcVbhBk5Cl/NckHo6vblhRie5XZXWGDAFgMIV7qubojTikiXOXTSHkWZgked72E0p" ..
	"PtDalUndRZNowdMzrvDG0byYVL/fkknvrzmQjyah08yEUYlHPusTglkiG+kwlu3g4uS0QzguPbC8Ck/UTerhyYZC+w1eyinOguMc" ..
	"f001RSWvRH8BAsnWOzBv4fS3LZxh7wmbkVy22KeQ7ThFoDE4hkJ5NGhMd0tTumTzZxBlW1RGZlw2xKnh60QOpNktC0GmblivWWI+" ..
	"m1uorLS7NH8lWci/aMZLPjkGdeQYeax/lbZ7rkgx+ZBL9ka9nH20+KaG2GFUosOVnW2m96WJ9AIP5VrcxDY3JGIMRXVm20Q3NvNn" ..
	"4LSR8SdD181I0JulH3eG1f91oSMmYxPfycXpEzOK3q4pHGTZjEp35pg+tTHAe6FeQ+mLSoYntJWrlZ1VuxRkNkn3xB2vliBrFa0g" ..
	"2TRJETE+WuAgwFNzA1j59/MAbRXpnafgoPK/e9DMCoAjfIAD/77cFpCPXTMMd/sewpZqhDam+XnxgDoDTYgu0EFGrr0uN2KhLrkF" ..
	"RswO7p5kb4FA/jQXsT8NjSKkCkNwqUSgEUEytap8PatdGp1VydGNNBy7j88lbWcqN7pL7FEm00QlNBNweP7RH07Kze8xXJ7x6KQt" ..
	"P/b6OcfpPAovqhhZtLeoEj1tL3sQQr2OM100zbr7VIkPatFCKGXDLADsLP4hVwVKm1QDkG6DiojByyv4AVsvwBhct9MLaGZaNgwn" ..
	"7YW1VUoUV/6hdu6JuRcwEAVj301IKa7Kd24mCCHpZtLbsHn7VPY1SKoZ8R+8OZT/HwxqfFYgTCNMjOzXWH18gZ4PorlsxSlr/aCr" ..
	"8VIElCINr7f5AsvvcXpQfeB5LEN3KPqJvQL9ypxjW3Pkf2GLmZUzJz1ywvKQeHcSpB/YdvXqgJhHNqTPi2C3ElZkomLJX3U5qWoP" ..
	"wD9JOr7Ue+VlRH3GsaM9SzWPNC1megM/cjUoggE6OQ97frA9KA9FCIOC+9iml29pOtPrM69yyW66NyUwkwms0lrxOeR3sooO31cn" ..
	"bzz+rm08ciTJhR78Zhfggpg/UWHjJlBGH3z50XvdHC95kzJYBL3Aj33jf/3kuE6bTkXTEIqX1R5jXoA6udMYC2prT8vnCUaDZfBT" ..
	"aMEkFOBEOMnogjid0JbfL9KP2Z20C+P0akLLQc9DQ4K37N6tOapGn6P72TfMRL1etTpD6F70Z+jZi6QxUhtXT5FsRy5aykcb6GHt" ..
	"jzxgjbjPB6E235Q/a6TqVXZF77QfUV/XWdwKyUd7nWuCAko12OTCNUrRi7I4gKzhVMom1OF7sOhZigDv4MkIPgmoAb2SBwPlaR19" ..
	"RpsKr7fqDoA+AW1I7L4uVeFPqCe10aoY4gaTwENZFryR4XqsUdYKHoVjRwQ6CK64aY+vkPpqUPRXmHkEULQ9Nu/nl5xnLFTpaWTI" ..
	"kCZxa0BT2ZOfyIjk/D6YhEhF/DpAVhIxg7n//rAOVyNIdlUEddz/REj24ykUQi1WapyTLR0yOEkGXHmfTcQxsFd/0KddpjuTkmtj" ..
	"2ECqM+ZIwKFNakT+UNIX3eckeb4yi3itpkjUTQaIZfGl6SaJQfhMdNnp7fsk8DOExlGgQi/lKhBlunZYZlgWC/ZjOirlwKcdLpr+" ..
	"hOkGkVVSq0NX+/OxlcT3q99pc1iMx9LS5sUN8Df/Ak2E/w2E3nbMfeDtwCyW353k+8qwRiw/sMllSpiAWR0ni3XEGzeDi7B/qGnR" ..
	"ati+rBXYqYeTw0/mWTRBuUB/jY/3ePtpF1bpB+04sZCW1G89n0fRl/A0Jv89xJj7u9txuMPN8x5GG78HpC9WRXckD0nCEaGHF7Dd" ..
	"n1Y7p4WLY7iahjWKQ8sKz1E5GgzZhTK7vUihh+Ko2rTCXd0sphykmD+OdAmvxuoEPoVAiZ2OjHvpJy5XhZePEjWbFsN6hYYWqrrv" ..
	"upJMHgHJYcp11+/yMAdT76HjuUfh349rpje1PHtBfB72vC+/4hixaO+iwOH+/1KOhDblRgPoVJQX5uVbhopTYz4Ov0HPWt6tvKzd" ..
	"7cSCN50yvfeK167i9DlUUkrXn8N33DNH19sjSnaN74VIQ91l0UKSmL+UUYXEffI+2JinaErx1CaCxeHdNQKkEvTG1qWh3L+HJuvF" ..
	"V6XFIZTPbQeShvkqiwHb8Ntc5HnK6AwBHNJv37abYJl0rtbVm2dc0SEfocKstDzeqGoUOvsTaAZ1I6lRyWQlNDslEdzKqjTka4ry" ..
	"GChHi40AehZKDcQotLjk0/iHyPdlFhBPuEM+w7rbqavVtNaUNZR9mtuviRJhpS9Xhksph7KznRbfPZ97B53M74sDuBxROyD9EZif" ..
	"S2aV6gOLFNjdfZKHG3I5jrLHfX9oDY6RTnFzm2b7jdYkhrRO7H2cEQ+uJYi6H4sZwFJI6NsNgDwlgSyIF9/EO1Eo+ww2VPr/Gvru" ..
	"hmU9q+hl6Y8dpOC4wfVL7hAdTioy2f8ssj0FTKw0L1fHshjEkrcSlYLJAlZopdHfb1s7YaTMNNxF4RtuFCsHhqes53876K2GdEHL" ..
	"YoNb3+P0f7URezvUx2PMZEdmxN+JRg2eRPTTzeAD5YMacfGkkqL2GMJV+P/x1nZ6c220j/Pg+bSg2/S3Sf8Jm2k5xk4RVX7aHsRM" ..
	"oQKYj0dQEQN4jK/GIiVN3qkt8hG36XY28ar+FnkTn7tcE6xLIkUQnmbY4OXHuMSFcEzqpK+3gCOtwnabyEVyXyeS2v0cDYRGoL0t" ..
	"wAV7UOOmJrlx2xMgJzTkGLJIswSeSOXlMQjZ4/Z+XDZ4zWoUyewNJCeid5ZT3jlS3GiCKwe9k+gWTn8yxc9xLYmcg5EvTZ+u1xGr" ..
	"TeTlrAJQxG114ouEONDIk6befQV6TxE3ZIRO0vZCe/SWBqEEcDTlTEkbJjJrtwHRs7WGIulnfdZebzllSOck0POlCEjEbpn8JFb5" ..
	"qKuk/pt2t4tNg93xO/cibVb0W6iTz1Ct6ViGJ9FTgGd8MSdTzrQErFeAH1tYVf0DTnpG+WXRXwoQHnZXxQV8SEmRR4IBm/yfHF5e" ..
	"ziXdCP7h6MBfcnhjkYftEC2q4DGEIcQ3rtXxnAHtC2IZb3ECddHilO3ACrPSxqMalAEfiBHKccPp8fdm3D6qN+FJFMJRRb4JPkZC" ..
	"Eq68wvMY9jN23EX1POZ2l024bvklL4v6Rq75c5bQh762HjGZcS208pOpfpiwqhLXxMd5QqEDozOom9G7CAvsNkq8Y6MkZnN6cSG1" ..
	"TpaB8NZVhHpalxYbfhT8IoGlmoE/XAQMSKyTwjpKlypNPTR6dz8aVtvx7Vpv4uadkGkmn5uot6gHqnvTtYLbWUb8g9O3Xnaucbtb" ..
	"kfQQelYzP+bjLfsI4BrySt682TFDZMSmbm5Vm+DCWeFVDfLDKb2v7zXbRCWIlP7tN9UvzIKiTiWaDHh1kdAK13Glj4Y50Xj7N4Lh" ..
	"oqgeAcvw/L8w5/7LAMppy0l3TwE+BZ7zyLgEOVfpk/oag/d8zm6N/wlEJO51KauTqpyGA3QUqhV9UvP6J2zAzpJ//POhNUKIpbNp" ..
	"cREDpgf2oDlhfu8G5D9N89FNmnC8ipw+Rfls0z4SiS3yVtWBEzRINQBGfH20IApicLKTyNRcvl6i1kqmrQndGZ/2iP9XKdqO2wMd" ..
	"gO8a6Mw4TxDj6Pgo+3111bTI518OGJvhQzQE3y8lOmTZabeIwLVX2MSoRlA1p8u7+1aab1cz7W9E6U57AWYOkAuA6cO/9tNXz3nB" ..
	"hh9OFXU6sXFz+bsKbsfDslTHHVzKr1dPNES6KLK96+FlBNNO6tjKOrgal8ncnG9VhZ6cQo9A1t0Z6uGHbNzVKimRL1qD3qMEW0Q1" ..
	"7sfLLUPBHQWorxRqeVtuZmNAh2TbyikXT+cEtmyw/Sy3I3M1y94QgHWuJIh7qummYo1UDZg0x6jkmxUNY7Zw7j0rkWNoCNjTNpki" ..
	"QkQfbkY60oIOSNROE3h6uZN4PM2/xbXEDVuyaReN786FYhpAtJR/kkyKRjsYy/AmUHRrDDfxdJvJ5SZrn1sMeQRWQ8QEJdDJP2rV" ..
	"IxkMST2tItuEH+7z5us5XSrcZEeXP9uzOZBpbHGbaUEIUX+X0WA1NVIa+6lnRROoSV55V+2USzQo6KiStW4T2uhPm+1TMGO+DzCP" ..
	"yde7fv5W1lUL5JGCbPNji76hm9Bl5RNis7Ld/Q0cgiROnT7gat2Chxm8g5VptVw9V4xqYCYYy+22iqfHkDgphfwINUFSsSYa0SwP" ..
	"6R4uEwUrURUP1V2SYcseJNze9QcRZeNJI40ElEX2Fro+ypSW8GrBK7FRnnhO9NnyRAY7OvkX0hJExM+k++mApyjsK/6/qAYrcnaX" ..
	"hifsiSAN6eqbvJqsVpNC+2H0cnlzAAjPVm1kd2nZMUOJD+byfLrYDyx8218YKS9bbEHc70JS9/UFgsLB1A1QIHxCba+ycx+qXpaf" ..
	"NuoiajXUwH8nbJgzCJCRlw5URK5U/WvZBLm7tBipRKP9rv4pShnj+FChcZEPX98SD8FhxS/TbJqZcu5gmobCAkZlqueCfZxWamXT" ..
	"ER3sXIlSQdZB20bPKQsmgIpUZv6fRcqAmjzDWIEmHNYjAw8hFUFeovn4X1fXlWNS9OFdE0egU6C0a3Ijqogm+BD0NF3++5OiSfno" ..
	"/PluK2noUkMheGVGQ5xKzwTJVO5OeIe0CWMUj110swFlElvo1D8ORFrO+MLzK8rday7neBYG7E7uFd55lWihTGdQOwIRuoaeEzdU" ..
	"KswiCh15lMpq+iVKJiTYl7GdNCE6cLJwBLEtrzmfLLpBcjwlIWTu4uxD6ya+rI84AG4wfrzajHvR/pLCFxEEU/McihlGnDVyRz0Q" ..
	"PsBuuhlLcacRGPUrb5WwSGu9PJtHuTrjDMZ5YFAfeR9nYTC2IpzmOieEMp1x4ieQ3ymmHf2y9NKakVRsIJ0h3kxIKxGzrK4slLNQ" ..
	""
local PAYLOAD_P15 =
	"r8n0UtTJ/U2veveW0ib5618SYKNCpW2//cMSIAqfB65IvbauylzPv9fjZWhMUUe/BDiQ2hB3+oSmmYwnnU8Qd9lWuHxcjWGNX/10" ..
	"j4Fdgvu6eEvMMWNAGhD5Co35kJxigCAXHE/rd1odofxZgogbJzofKkJVntFbyDphPPCyUJRwJZB+tNvv2huO1XpEkWgLmMHQvbLV" ..
	"n5zcB00z0hvx0ltKL1GuaHDY37FynxpoaLMyHbY5R0jHflY8phBiDZvgMv99cbnSQcvXfi4LKAira8A154bKPmNEOBiZYqF3G/Ck" ..
	"Qc65urzkTJNPd6rScusL8ONVApPByQZ+M1M3pco9k4lfGe2RHQmue+oyXboKi4HhWMoQh/f7bqMMx9yk6mSCRYLP2xSZRK4Q9M6D" ..
	"J0exEWuyQb81zUDWsyrazM9TYCODcO/TYwU8k7d7hKTOQpPSJoFThtlRy6M3HVS0eGD/qBf+MnBNavvy8dfWpfuuHJfAuqjtriEM" ..
	"k8HnAaXB8jlFbARlR7g/UEa4Z2jfO78T6M3t/TwhTBol+4mXIW62acCRnqBtQhOs4fs+Dsy6evXswNNCpP8nNC+XZY4/3KI2WLeL" ..
	"dnNTZH5NTq5LEEeY4owfUTS2RapNhKNzPXD6rofWimN2/M4ziIsUGTdvHmHwg9QArbRTEdRyE7b02KXhWvvG5zMC1Wd7OtWA43WF" ..
	"kiTC4p1tn7IH+aiFmqTZ/msT+wkFCfk6RjVHULB263bitWc8sP6D5oLKw/QtoDCt4F7MAA1PxLl44FPIvMYQj+WNmB2pezvdp7Sj" ..
	"uCMepRA905muO3ixifCGDIF9KzgQmR4Nt8fzMwbJeWxYX8dTTPTEzaE0hjJPkG0iiu5r4hUkLGo2J2vFcwkwU5OCY3IRIhf0vPTa" ..
	"1QtPx+I8bZp2dCl/qGlbXx7wtJySwOrxT49LWx0JH35x+LIECtG0KDyw1njQ9CjawfR9P0pw6erEDuC0pziPCA1LKXdX+YVg9xtd" ..
	"BlrLEC6vTV4BAUBeNDpA6co8V8wswYFSbOk1hxyqrcbokvECDltpvSMKsqbcZYbhj9825MrA/4hQOMD+0vfXdP+T7ybCvsPSfs2X" ..
	"LG5rOF/tQeFhM0LN6UTsikz0EoySCSlXQR+ZZGjACnb8U2T75mIEEjOFFzl3Gu+GauXPZ9STD/LovgEhzUwWVUpaWi9guAU0+XWQ" ..
	"cQymMulGgZIkjPVTApkxr90qnkEYqt1U48YnYuqacF+Pnm2scczPEmd0HmW89qbXOIweDFLP1LbmdCuGtq+CuPEGP/eMMb9PSQTF" ..
	"+ENFtgeTeJZLiq9fMP9cYJ+ShyP3fflu5r0RzYlIp4/BWG6FacgXM4Iubc/fj7gPnO1ZAW1gWOjElcC+rAKk4IfmoJZ60GiuTBig" ..
	"I9ZGalFDJY8fxoDVhjVDfhcuxF04b+/54+wYQNLL6G9S8ZIzC7RJwO3cSoKVl9G2Ap7A/nQI9Y0yCNMxH+MAtFJS6S3D12wmhWmv" ..
	"8NzTnhPIxNqe7aHKzGkOaH4s+upOGYcPgmOPBmp/aYaWMdARhHpsPrl1AkK0tt4+Os5OO75VAK3hLn83CPNHf0GA79ZrGwsG54Y5" ..
	"xN+3x87pW46SGbmZbhpcGNFhJkkyTPSvYvgkLfBzRqbp4GD1+7Je/+Ep6Yi4t3EqEXRFmjS9wLo7d3Tv67K418Fod6eEx1UkToSW" ..
	"QogZKTdkBINaf5DuuVqFRo3dd3XYDlC9stgumYCu/PzW5rWvDlFyLZ9F0dvR30m42kWujvi07ZiGef27nuyHyw7Y2Tw2yDVj7bfq" ..
	"k5qNxYCJwd83z2VNc35AEpNtWJ+EYlFGlaZEMPkKiPXtt3wiZu9mhyJWnBwjFZhTA5LBL7O4r4jLulSH3IcKFC/kAix88AyTSBgG" ..
	"0JTiUci7OCzoOfd1qxB8p4npDIdLukkbJMvCE9dlatPcADuGwWvGmrr9NA6Megvog472xSvhWO0unYe+a6ggJnlQX9B6Sj4F2dbd" ..
	"CkoQxy/eKKbW92WY7AF6otjWhIFLnWFfXag5FY90N4k6IUZJE24EPt6U5bB0oQhm2jZiDsC0gB5zQnTWzGj5NXJy8qdt2c6c84jJ" ..
	"FMhmZWARbskoQ9eBfxX+GWMJZkifEYQmVs7MUj77A8BYiaJFsjzMP+BmTGFwV2xYOKy5a2i4DMZ+fwoZCA/Ybgi96Vp5xpSM2vu/" ..
	"BFr8/AF0uPdsS9qBGdNOdqM7TL4MHzDReiosbg3J2xEgCesAK/ormTqw2qoVU/DZYYJvUb1N9mKowjEE1tkAP7Ptmb8W+xTjX4fX" ..
	"iML0OO835DIShH//1XGHg3RTK9VYvnNxl/qYbJuu5KCXTDwm6x/HoMnGgx7h5ta6YoyH6mpk7tkgLSO5ZMOmjTtV4DeCIrZuw7UX" ..
	"e2S44draQH6vmyiVxwGKroPRoDOzDYD2KQCzjcniy8xzkXU1B51WjPSgFAIKFYRNBpPY9ePX7tY+d3VLG3DWUrWVzczmY/nkyGpz" ..
	"Wd8E1bFyweHIeYwht4nbYIQk0G75PgsqtKWIcNHwQiVFX5CveIctxHDLZK9blRZvsjyDwhWZuUqymfLbEc3k/gRdViTosMeA/8cH" ..
	"To4zGZnpjLLW7jy8XUfOpUYHyMtaxYYXQN4lQMUXYsb0nqlBWwB2vdtyIeHegSHz87lT0ZHLawGlUVHhhaWQnCXYUKcKXyWRlhUw" ..
	"nsG+cYvFxP+erBO7P7gOFBFdS/1wxiDGvqTZYMqTbTiVf1h9jOJKtBg37QQMFi6tmsD1Ulhp9Za80+FncesjPF9OKbPSGNJ/Sh/b" ..
	"CJn/5rCMd7yERAO64czADMOWS6rqzC5fHOVHkuUX3KCVLArmgAv26h6S40ECj1P4SFQtM6W3BzY7pNJ1QueuvD/ieWqVsS3Zo9qA" ..
	"FjIxe0peI14W4sOKi7GNy2JZ6OtcyC6uXqi3H05SKeIN00SB4l98XS+XRh5eAsCc695zHZI6o3sSq+MdGKs8v9qmZs3f7h4pDhcP" ..
	"45st1BIssKNIy1He5tPrABArxXNsrXHdRDhjudJ4N8AaUK4Xbprdv1LvmOz3yfkZ8PbBuq83h+/xOMbP/5uXlYmPeGznj500TZX/" ..
	"jezpfDqkAVtKexRJivqBWkER0bQ/kLy5BQWpsA/z62fF67aLFRbivx5WCmX9YZPCxWu7kmJUW8DhTSlkY3vafCENN9AQP76pQPoO" ..
	"9qNJy3/MgOngKOT1hZNY2RVDOpnhkHPZ4HWWf322Eqt48D0bF7Uu6T/hg9R+EJjbxkQiJFMcB0Fbq6lGM4aBXPK3W9c+pOUiYZqU" ..
	"XMShv3gZ1dMXMMuD8o3H6hLWutOmmbJu5k6J8f5KGPYt4rZo/eRzT3lVFjqgTDZfATtCfyTJyFze8H0T9bABeNm21He3bFvdSsR6" ..
	"efD8i+ul7foYWwP3MB82aVjW3ReGDjdCi3AlJNLI4wBMEniv0H25oqbGeiLJYQiE/D9zm8+J1Kx+lqnmtHr/bGz15pMWAYoEmvcm" ..
	"sCj8EXDc+kWcs/HQzgDqUsMVx8VzVUFSvldseziv3yUqMehIb6XzfaOnf/lL5PJha6Jy2ChcJ2147/KsAsFpf7Oa5z7DFhcO0RdQ" ..
	"Zu1pt7Az+1BvIN0oABSdZHxLi2/Fp8VtwIo6XgbcQ4mQOoMI98q0BnuQifXGa20+RwUX4BX2yzwPIWkOdSfM5eRwtRS3Ncpt+wIn" ..
	"Idhim7376dnalfoTR4Tl6u29ozEs2Sv9bkk2+8ZLwdmW8YsDd/OnenfYFPWWeephIPZrxTuB46kn3ZPcAZMb+LpzqXOMALj2LMif" ..
	"jJ0HQoy1OKo9NJ7YIUu8LqWq+0n3Y+SpqVvjR9HcHpSFQuehWjkwbvYkY0It0RtkEadRimnKQV2imXZQ2BLWsUGkBfDmytWVWbIo" ..
	"gikOFUzpWqFg4OmRHJU250I+/471oKr5lP893iSLEv2pfnvX9XXP8PSi9Rh3CzX20jVDVZu2joqmwvY5o4VvKjaYQ+nUSW8l4fBA" ..
	"rzaUR61LZG27Re8=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13 .. PAYLOAD_P14 .. PAYLOAD_P15

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
				-- caller destroy key GUI khong bi block boi task.wait trong menu.
				-- Khong nuot loi im lang: neu menu source loi thi IN RA de debug
				-- (truoc day pcall nuot -> nhap key khong vao duoc menu, khong biet vi sao).
				task.spawn(function()
					local okm, errm = pcall(fn)
					if not okm then
						warn("[DQFarmLoader] MENU LOI: " .. tostring(errm))
					end
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
		return
	else
		print("[DQFarmLoader] " .. msg4)
	end
end

local sg, tb, okBtn, errLbl = buildKeyGui(function(input)
	local ok5, msg5 = tryRun(input)
	if ok5 then
		saveKey(input)
		-- dung FindFirstChild de destroy, khong phu thuoc vao upvalue sg
		local _pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		local _g = _pg and _pg:FindFirstChild("DQFarmKey")
		if _g then _g:Destroy() end
		if sg then sg:Destroy() end
	else
		pcall(function()
			if msg5 == "key het han" then
				errLbl.Text = "Key da het han! Lien he nguoi ban."
			elseif msg5 == "thiet bi khong duoc phep" then
				errLbl.Text = "Thiet bi nay khong duoc phep! Lien he nguoi ban."
			else
				errLbl.Text = "Sai key! Hay thu lai."
			end
			tb.Text = ""
		end)
	end
end)

if not sg then
	print("[DQFarmLoader] Khong tao duoc GUI. Dat DQ_ENV.DQ_KEY roi run lai.")
end
