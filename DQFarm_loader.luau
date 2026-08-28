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

local KEYS = {
	{ seed = 949108331, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 954883709, exp = 0, plan = 0, hwid = {} }
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
	"NqQNcKRnTPWQ+TKMM3BBGKzWVS2AM8wumst0wdZV1+QHOl+mPermywpTKGVlXIbNq/+gS3vWzHx8f6REV5VAOWoSBrnJPBHN3UxN" ..
	"9kizsbk4PmmwyrvxgZDzmxcC3snV3ja3fQaVovLzI0glFaKLkjD104ZDs9Vg/OaXTvlT9yVpZhLhkSRrglaZoOQusUMK9JYXStIr" ..
	"Y5e4pntz3VldJIJ16k1B0yUUbnGgsgav2clas+5d0PW2kIXRX1ai2TXOtnI8QPqmrYGQQz7wT0uVW6HCqswSM4G1UqqrbqhMcEns" ..
	"i2HM8f1DD3FzABkIVb2UODdWxOz+a2gWDSQD71t8McYCLLwWiffRIRc6bxwMN/OXWz/DucFZKoTW3e1or53OR21SxMdpLMAZP44H" ..
	"wyJlB07ZSXmMw306EW8+m5zRuBiyqdU4GSLAKrNR/yA+HIuOuGeYEay09Ww59n+ZWHFrUxktcB2wTBebuK6gsQbj61VVV4LcDjRl" ..
	"3zcCuCAARpnVUrm7vmvY8Ent7jVnJdniQEn82pp8bCcL6xTgqeDdBUhKGxaySVaFvPgEqZI/yGrRwkE8k9xo0UxwNuhitxh7RXos" ..
	"wAMcgOHDH2hRzyXln8KDFMjQs1/cxpycCYDFvyLMpq61OKU2Nd2e5HNXVPEnLWoW0+i4YHLC5WsAXX+jLYAbwoA9F51FRDNXuzfh" ..
	"eeQTeg4LTB/r0l1qeTSZRL09yk1bftV1rlCcIzGk39v6OFMIDT6vajiDw6xKyFrIErz9q04lld3GVAlK9kkmHTjGkXoOijneMzj7" ..
	"Ai3eMKNrSX59zG7uPY/UYD0bnpjXZYxMopjUTghEFKvkp1xbfE1aABkRxaZTFfCSF2G5Ww+gfXHnD/48d6pA0K6A/ayeyzajjXC9" ..
	"WNo/jyG5f/qH2ZE+KGAA1zEOCXU4k3znloLCwccG9FEdzy8QHXwVBlYGAXmgRu/kiyXeg6vElAgVkg5SfZImhGojttGb2+AQUoub" ..
	"HppGbQsCZONxxXwfeGSCzkyM6b9Gf8dnlzIE5JVgEPdUPofpLmC9uJEvitSsMZ0KTeYSAYJ8rtoSf7NOd16XuFx+3j3BLYvYTYCX" ..
	"BQbcOyD2zMp6SKug/5HIVQg5XKWOF8X/TNDyHizZ02wqJxJb0t4gvAo0jxsENAVUhqmlxRj1u7A3yXUQ0geLlUyn1KGbjrzx9ojP" ..
	"kJyLoUrO8oVaPCgzTRq0HqGtqLQYl73GdvL5lK/1TfKfSCMYWv5ZUvADoZXUeSyugyBb3x8JxVGJdUuaE+hTprn4p5djhX0mdUqw" ..
	"Gnq+Y4e50F4mTLkRagxOVReR1zT8Puk7p9+9JRCIkZtNKAfjbkaCYriCWa36ghR9loIrycj+pVP6L6pUYtxymiy9MW7/NRg32yXR" ..
	"KkK7YJyqOIVee2X44XpnaSkjAZTbCksrlgIQP8S6AGNlhlLSo96z6jrNH2eEjOCwGATr2oC2vveIM0H5gua/VBpQ7Mglpl6nf99a" ..
	"VzabgcjhZiDkmQKPGbY27Huy4ztiuTGQsgbIe/qLdYaz6xHXPuWh93k5XeK/8PONSHZjzXhXvqPFB3y+A8u/tfrdR7jZslDV6RBy" ..
	"r8AggWPTXyVj7AX+qzQsGktGXv4w0co7+OBjiZBuThhVUjkItxX3Dm5Wp4ONE5W+gwFW5vb0hAqP9AWdQUG6MGeDV+zA2EM4fBjN" ..
	"YoeLOMcfxzCov39Y/DFOdenDTKX4HJRcyZMDobYdsmT+9LMe8v5mPV3fq2q1W/pLSL5RyVz/a8YsuVyxTMXqCm99kpca3I+CYu0D" ..
	"INxYpLbcSZBsraCMWbOepHqcRwmN/e60ArTgKgTTZ9U98USb+gwtV8zoHf+LD+5NFgeuaRbXGWZ+BbSLFRfSZSn4786YgA3uM6t+" ..
	"nYkEKDV/+NDADK7nB1JJiPo6nIt8uX8CjqjxEIvQF3hOZt/5Ttd2jJlV6/MPzTNX32635sGvbYn6ktu0scOrxx60GSRBee7L+w4u" ..
	"M3yZcMqsElOFBS5kXhnlaJhqbljJzvP6f58MPYyGb9WQC4IvzS0n8tTb61puwlqmas/qICxpb3UjiLXOJmk1rpIJ2pXjIm+R0ZdQ" ..
	"z5ePfobglGz/RXls2/wi+ql9JDRIlUuYfKPEZWXLAVZqUK2Upyea9bdN2p0LeVh4hkUOEuuTnBNBFFCPW7SMtcxa7StC1QDDZ9d1" ..
	"IV5628BmJwSEX6yGR85pQXRDjAgKU4MKf26Jui/mediXvpnmpug3NbRhKa77lEgO8/Cr/zRuDRsKUuRcas28O2V+TDc7KTXwGTMr" ..
	"vOHJ1nM1PCcHnytMqK+SnN6dcHfbEQnOYTq5pZNIy8t5K8oMXgNt0S2GqGSZGHXEAd1frZjs0U+lhS6vwaxfdlHke/0KhfGKcFOi" ..
	"sfzU1k6WTIK1RwwMWCGQpazXUDp7HxDA0Z9M6MnLWQ4vLvw965GmTGQ0GDpq6Y6N4S6jUAz6jm25LOEFnnSYvpSjNWUc+ZOZPkqs" ..
	"w+bIlEhw1IC+fJm6HoyyQszxBauy0/2lGSm3NE0X0zeObRhTF9HdeirOMk8DpBaXIhayit4Dzstturrrxf+vgcKWNqJFmfRf06Sf" ..
	"fEuvVQGLtZjcZ+nxKz+yDRgqGURP6uhkD4liwN0aHRX9feQnbM8HJCEZFl2qsWWRS6qdN1s93vhmCS10WyPhVHrbDZYenfsHiROl" ..
	"A1gVxkTG9oFKBZwj+xX0rHfnWwQwttLg8pWr386gGgnF+zD2CevaA9SWPCeU4ezZr/e9LoZoyVQVtLJ/wP0ybQkjvs8tJTRnLXEj" ..
	"eTBHPQytYGbC76QroW0GBJ3J3mPTt2ouKJqsHXklXBOFirYcEnvrWTX/x9o/5RtUT9FVc6x8tqMFvep93NtIjf4CGt7hcN3rkfSO" ..
	"kFuNvh3LTd9SSOPHXAgYX1VU/6ZSQjqK+g3XVq0nGDjdDAE2yQv/R9bfUnLDxoCy7YDL1lUyeCHRciCOY/8hxWB5Wuzgxood1TQk" ..
	"zahpEta7Eu7MkovtcHY1kcsSSynpb8yPNtxsoZxcIQNEsgZ1thmIdG7kyCsKQhTD0Yk24OnGtl9LR27dw33AQqgHc4GsqPTkXaB5" ..
	"4j8JHSR/QvR8CjDHtpROCIP1Jl8lFtK6HZKmbIFGe/gWtbp/OpI8gQj4PxNTeet1+z6bJ7IeDKKCu4Yn27KeIRy2TOxE1ohLLRxN" ..
	"e/qt6pIR5hC4Ucgm01wuatlFwhurbCgSxgRmScfDFzfklwjjUGt0k8USvX3Q2D7Wtm51RbdzHbgo5Qol+Lz1AIcSBGhE+d3VirUJ" ..
	"bl8yogMoUB5OpOHrkDNEPADF0XZhAifwtLquX2BzCBuaDovDkYSCmgHQmu4IR0Ki9fBPTJMlaZtZiR6453OzaRK8QudH2gCJ2kpO" ..
	"UeZu7EFlRc9nz/xHTyOtTk/OLEGred2Mtbh6L1sKHZwM8kPGz1gZYZL2aX1QiUNdO+5WLUwEnt89MAlQI1bZNAodYcx9X6hIB5CM" ..
	"VomIHWvTbQX16dfCswuiGPbiZt8OkjxrrOau87iblrm/voDdjZhWukDcRLz/WTy/31kWOaO1wS2ER/C2bkUkGLXnRbs/MtC18KK+" ..
	"eURkOxBELd0Olk/2t1j+r0rOviefrmdkEb+s8daXBszn9FxhjO3lJNSy78u6u+AXlbXhiNbdZq7tSAPlVHbdRcfMXQwov+aXtCEj" ..
	"odM2nf9l+QNM8Ccb6qKtF8CBc8LmKgGCptKoAMTXRGWbE8CnPdenYIRiEIp/jEWV9gKrvTDXWKoDqYCe2PHzPz/Mk1Owhl/v83jS" ..
	"YLK73D6vCvN0onJ0KuGqDTtJBZ1qoPfpIIq9PcMOGOhlA+h5+xQIFKClyskrcAORyjCMvuBUjiXUDFQGhvk2LtAfb8gPS2or6N4h" ..
	"VbpUL2O2Azr41Hd3cjSnORLQhI2WaNC4CUsspuGuYf/MDK2yJmBZlYzjfu/RbtdOusScMcqA/W9pGj/OLps6oj6rTneZvlQgqkvW" ..
	"Uvp5zUuREE2JYF7TnnxV/KO6nSx6fDrkZFe8CHdHi6AtSuwIBv4UHVOIbByGguvoItdMj0Soa2ygfXshhlEaRFsWSxK+9/HLq8kF" ..
	"Zg8CfMu+iahzh4vUqSO/POM7XgRj1sGVxR6ig1QeuLB4+JNJIczC/dBDEjLgZ6GnnyJNbV88gZJeJ6YT8M6RlsDg6rp6+a3H0z2D" ..
	"KrrhnrtuGBqPV0PrA9UgZxauRSM2iTRFAYP5Kq8M1ysFOJjuLv6CnuycwkXYHYJe6S1v/0Y9XBJTlSvXNPqniRwuXqLPFXwVsEIT" ..
	"SqVnCndN+YUaj8KQ9m5Hnt7y+d+UcHVcYZdeV9gc3tHXSKivOXv6QKHa0UXLGDz5JyMoVQ12tnv8N1UGM1GaM3rti4WKS29RDDbB" ..
	"4YBOwvxa1UqJUAdM8izc1E2/8nKEODDYbtsn4DPfo1ODnuZYnhWBNxfPAw6rCMjPzGZoWurOoZyNo83mGr/X82tt9+SuQ7W2a9HW" ..
	"8XNjmSqlepZ+xv55Z0JyG3zeyGpU3kR+fN6WhCzFdkMzwNp+vpkQ4KnJFBE0jNXm2od9/+pp4R5acC0VxZyHbQ3ioQJu+Ai1bZH8" ..
	"mdHwTIl9zaAfBmLzKBM5pwJ2SO1ERGVKqXt84zGyoCx1Z77R1eJblwjr0a2YQY7ki1IbyEbNOxePZmdg5MG1BJFum9vtlxD2qWbX" ..
	"4YSGXscYsSfQNd3boOu97Y0mLh7n9EY2p58gEW2CsRp/KXoRLvaNl3sYW9JyA+mqZDJLa7ohvlTxWMFrLJ2diD9xtORh1rVUBJBe" ..
	"KGxyRAEeMFieVylOX05wofIPlkeaksQJyBTNpwhi9qcGcN8FZSQ9exSQQNYwJLl7xJb8ZKyBD86qylNYaPpRcLF0O3y/QjOXipAq" ..
	"FGhDBHio+aTGVhoq90BJ/BSY00AvSaKJJt2IMz4YjqT2N8/PwRRCLBzA6tpNQLm/ACu5wBeOStYwRhzFdW5od2o3XHTAZ1szywuo" ..
	"2KD5N9Gzn8jIhkEUXdV4BYkFiiR1mjqDOy4EMnnrVsLvre3yMvZWvKlzeddG1LiNLW0EbbDQPjJpHLwFxD4dG7KCjv8hrUmGAJLB" ..
	"t0jT5Ch5u8nE3NBMujhlmrdZ48y3R9aE7Sjpn/gkySKxOrhnUUpLpSyv9JF5mdWQLCzdIsvbDeeBdswqy06GNNxR5mVcfxB6DjZE" ..
	"IebvJ1BTdIwH3wWqviaCEkPbAU7lkZVw/oljYwQm09ztliOsIS6H3h3QN9oI4TNMObUKEaZyqjVZyc2Z8VVee4owcf/LjtXdMGum" ..
	"6MeYduXg2Z5HGUzBWlwkspwSbWvo6ngbvsF2iCUwIT+BAJaJccrbD36OZHXczSot44VzfXWBNJW1Pc7N8ag7C5hE7pgPAMqTY7q5" ..
	"/mv6KzbQ/gp4+9ekra6GcpLqVg5WcQ9SNLMty9Fw+F2QJwjMwSQS3dhbcW9j1X40q226n/xoaFfxckdy/9GzETqZPlnM0Qqak/kK" ..
	"DwHVfqOPLWvxM6xfKw2bWB215aaNUxxWL/SOyxkHnae2d+DHijpr0VpINOw0GXfXVecl3trCBlGNz7bpSAJzLyW0crSfJ6cHAXUL" ..
	"mjqxr3I46SW/JPdPK9Rh6M4Ty3hlppAFUqPpvrR2u6HGU8QRSNdHEMFoLusfbkCz2HZ/paa8pP/pEs33f1eCrNxVsZO1YNBmi0wh" ..
	"a0WMF3+WEwzjf5oGEBM6uVqS9ZjHNdf4GlUcrv0UXQDZU6aM9L4NmgypAEGpazTnh/bdJiGFI93+gKYxDQvhHAa4ykcm6t1IDeRT" ..
	"WFrHl050aurMqSoZVgYOYzgr+WoKIj3z54s7BaNUuhg7ErCbX9y0SjllAOoxxQkjtq+xjg758G3oFLNqkhc2JYmB2H0pGhnfbj92" ..
	"kJvWVdApPc+L+A9B+Ty0E122c3dWsi+2VPiC7m6lLLzntcf4SWc1szj1NXUq7Cp2yI/GIj2M+BIHq93fH5CMg/sCiiajqF0ceQIl" ..
	""
local PAYLOAD_P2 =
	"wnHyBHcomJYDDG/vaoHkL8eiB9Gci3tHcEL70WS46xOYxJaC8sPmNdY88LuMyaB9/Fan5gUPzDXUxzR/gHLbx5UnGOlulCI/vk8P" ..
	"AISS+0P7MYWRh5eNH0RwC0LinUb0fx41EPfksfrB361xqZb+h6ZD+tznhu2qUpJLEKSRMdBF7cSG6onS36Z9w94a2+Lz2OCOXAqW" ..
	"yqco6w+TKqKaKh53BxxfemTjBjRLoNInpjAWN6tcJhu6ViHIyvcDqG8XZ60Pu+SNTJExTNYwCL4OXXk+hN+45PjtbVG/4fzDwZkm" ..
	"Jo1OZgbnz0jepF+XZh5xPtYX4uuyD2VxtsEgLWjyeHWni40DKW4E7pwI3+5+Z7mYJXaDRrTlXZD8n6tGvL2edFmASsFyjtI06js9" ..
	"t2yK57SRphtNx5BFNSjooIsZW/vuYLxJK50eiiRjBdj9Uelq/h+WbnDzNnLvSJdJY+QPxC9LGmnvo3La2gkaJiC7kkgScfQHhX/F" ..
	"raTPCs6F2FnCmXBVkffb3qkVAwlayW0smjqz8TMpyDMgKgQ+ID/EYhF1JFD6+vMTfSWHm2QQJynJm2N8bCawZVQnosavAxOvC7oi" ..
	"bNN5z/yjwdj+fbzCT9Ki8yySy9nGraUREtljMF2aK2MBr4BCVbCL/1aLY88W+vqawU6u5Z8Gge5QMr5tl8MNvodx0cTjR/phR8+G" ..
	"orPXiUUWS9XWjr/3/c/C6Ong0KkjFGv0KK8Co1YCQvSzxQEsOlQTirhPoa7clmPYDlJ/PyxahaTInD1lHKkwpgeNaRw6osfhnB7t" ..
	"Il5FtKP2dOAyyh0Lf4D21tmqa8wzwSXYlij2ApNv5j4Qur/a/n6ApQ3lC4C0bUdPBgwRxsE7Gz7Y/q1dmOk001UlPowVcR2AQbUL" ..
	"8D3x9Yva/7wuAoSW8fs975arf3x/YnQJMjt3D439LAwiXkPswwCMU9bWcHxrR/8glhD5cp3GSkJ0cQ8r42PE7AI5UdaNOpiE+A8R" ..
	"aDCPvBOAGdj5iNffdAu2dQcDg5MvEznnBU//URSNwzSDvqLlKVnA5ExvlBtZYRFNuvVeKAGPerV1lgGlSLxjw6P9w3R/Nr8LOJdo" ..
	"qP0dqqmdY75MZwnfl1W2C1XfPv2hlGE5f74yJD/pZZUNKX07BGtXoWTIRQAtUwlDRkbTkwXjslhOpMW+aniE0V+UmkeweSYvS7jU" ..
	"SbuA68CgPzj+ixzY8Gr8dG5xZKxk+s0r5Mk8rXUfYtclVH1iTf3QjqKxl64FIQsiIp/oIYLQQ2VBTgUkYQb0x5dEzvzIKK8QIO7N" ..
	"hmMSO2iDX2IAaG9aYiKCOlXyykfyVv/KUvhsTAySQopPh3SjZLHbTq1DKAHuTpHNfoVPNEH6RCal3c4bJMCopeP745W0reVkGvbF" ..
	"8Xba9A1TjMl688kMjHronEHxqNDha5B7t4KtGuOTmz3YuYR/Be3De7kvjRjb88aEDl9EXrJamKGb9qxA0Ltq8Ynko+YJYz9qR6GP" ..
	"LDvsuUqC1oFPos5uCHq5agx46l+ccxJZoL660InL81+WgH5ORIORe+SoFSkVuVCtzJo8ELyrJhIt1yR0No79QefnjTP8lMtmeWU9" ..
	"W6Lu8xjaK6B1pWtx+5ejdFqdShFv7DEA5moJEcx2GXMYrpghy+aZiffrN0z/DDTbaLRQdn4UIOEMYGGuhX2G5wbZGzUDEPDXxnVe" ..
	"bMa/CsvVXRDV0OJlEdYSiLnGP+Iewfzu4yKIeJJ/fHd2tmPk3KJj9FPGQHSYRsbQl90+a/uqZUGm8Sq8SWEOlSFddugQm8sqWWOB" ..
	"a3sNGyGAhqSpEO7ft824sO8isHNBpAN/qhj4rOD8TdvQJl0lm6PQchjE8F5UwPAtIU3gAOx3ZFTJL58vrjK0eVmSzyapgHpwl3pG" ..
	"MiOO2smXGcgKoLpTIhtQrCyrB2j7plyo8w55Ts10K67DkryDon7rbeuBA+R4gwgi/AInGS0nCRJwg2S200Hn+xRvIHo450WrCRGS" ..
	"vILQRppnh/mQUlGc5vsVwCxMTsQmdSP3ZkibtE8mJSgyO87eiW7+tMiQNnEU8MorIa4Sdp/i1Yyau0fW5v3L+qlQlFiw0OXNopXS" ..
	"NSk/wI/lHqkLW+nQ50tYd0bWeRsueaAXCf2z2ikepvrOZRWpPK0VgrbBrvVN3tRChZ3sSqRpNlYyFfE/PB1Vny+gJ5TcszddfHXw" ..
	"RwYnHRGIhNOZFE7KgCgbyfdmkNpkIC05fp8kYAwzbdCiJkXiGuSkrHIGtH60mnU2Nvxov4vfrzxw3cAdCn46fHh6of9pWi3wrnqe" ..
	"auvxPzxZXzG2dJsj11XNor7fJyqxcyiYVk4OTsrzp8lMwU5/uzKdbqKM5mjJ74gFrIXe3K7RBhlPRDRPKWpXwB87/P9b/hBrjY+r" ..
	"cqlhw/jM/rYpkHdoo9sjVftD0qQ/EO4BcGTyMftlTTIAbL7SiTaaRYYkjj717J3CuY8gX7nr6FwQPd7mCoZcWHJ37DThcKcb2wt4" ..
	"SvN9db1L6Mv5r0PeKBehSC2ZReXFpUmF4btWwjLKPjYCXXLf+d/nymZNIuzcb/O1Y2OBQi0vbhLcrrSxCWqFiWyw5FsKdr2NJ3r0" ..
	"5uDMQaGoOweHCv59XbA72cwb07FhKeTItMokwoP0PuVo4llnmAbJhqr40mrW59XEGwnTaqO2CohhZzn25lRxaZ7kbiN0pdrClTTb" ..
	"kmWuAz9hY78WvDs0sBfGMSCA0PTceb1ZlbzxRTPUs3jare32j+6Uhys0gLS2fqouSgzLfgEVaKQx3l+p/8X9xCMYvUO7wdpgOyKi" ..
	"DGuLPDpKOehsIK/J+GCwzlmi1Ql+6St0AC6b7WVwjxXY/Utu5NeuNAeqg6EcABy9MQbOhoxht047CTKqCUT7BKiJwWtOYxlneWBw" ..
	"wBIN7vwK9SChXRD8q0DQJaN4CcrAkGq98dIuiTG4B2N6G1jQ3/BIOStMpB/tEcO2EgOl05LlPg/UPdxzKYPW69JBIdSAmFcOHhNb" ..
	"T255N2BArDfZ2qNj1nI1NzkBnp8ysYnC2Z01QrThDp5Gzw2GwyWpdzR4IS7QYY1RzgOjMt0RuF5SYVocIe9xjwLnuvGZlvcy0yLf" ..
	"+v9W4O8AYz59l5f/8Yq2KXJu+cjBw23vjY0rE0MvoxTEKb4p+fEwC8KQxMfZhvU5n/qpLbwqAgvuENLbcDuOWBIyLXmFIL7N5B2r" ..
	"iIHaXqvRSyw1vY+94TUfOfuD/rFSYtTG8hIh1slLAQaeU5fXwj4H8ehjVmJMGouF72v4Sgqoso5WH9HV183MHOwVXKLTPODzVSzY" ..
	"9s6oarf3LsspggQC+IbkoKJMDBAVol5ZR5tAqPUxa+D+v87ZNePbhTlK8VMVrvs1qn/23dkX1mqGtD13jLDzaBUjyZCriTq3rtlD" ..
	"nKYrCy9lSjUBOz8IOE4OhdZCPkkvmIeo5pH7ro3T3Yi3tw9Mvb+ua95JR5lg72wuVrbY3MYduMta84UftrMrTX+/jdSmX7q4YtZO" ..
	"zVV+mr4DoB06SuAzuov4W4M9gB1LDnbYb/LtjLR4EiMkjQovLB13A26k/76vShnkphfE4xLqQYXiALaoxJyZ3qjgtksvr/B6sXem" ..
	"wnwW1xRLrY7aY0gjbE104GWdIhbRCmjVcK+SPwbxthmDxzZQQAlpvHPP7+a5uf/6lGzDnK5pA8QG2DJCU6I0Asl17eJiDPtbMbX6" ..
	"2Qct0rgCyXspVDz4oSnrZ0tJ1nYjBM/UgkivFQEzMZMSJKUWzzGlq15tN4cc3S2jfHHNV0KqgLKz9DToEWnJ2wfiyqsvmO3pJmWc" ..
	"CxOAueFKa1s9h4jlPsL4R1hCN3jWqJh5/j5KSFGiVhk5SPgkf6HKGP/puoImmgZkiXkslbG4ZOZ7JIScgCaRT6ivXQcY9bbtjBet" ..
	"AlQJppdHKYGBkeKadMFIFvvTrfaBrQaItNT9IHJ+ewOB2CyITM0oHRE09jDcgAwgYZZHR69MvjmU9SGCb5IRuFcxlUOtXaG4bP8x" ..
	"IckAPwfnQC3syUjjFdA3h3f38p/v7mplXmbFtlwMjOHqNHQOCjjFqzaay8OJJgiN1duMqGefV7AhH6SWLwSr00JVzdl34qhd1fZ+" ..
	"3m5rOTocIJRAJUjf9acAf+h6zXt5nKWbS4qxBTl5hetrK/ulQSIaMnezOGr7y99vABNmXJKWG6V0CvDNHEev74k4J2YsMIf3EXoU" ..
	"W218a4omE1yGt0Rms/qsRVLpKsN4wqYNvi1IMhDHmBOGlYtqzZSoevFKore1nw+v4Aax39aOa5N1i8TebLYWQgNA4LvrsLrRW+Wq" ..
	"ZpThSAdofGWcbS0ye27O++28yQHa3uoD2O/Ta+Hq1NQy/MZhomlPzyXEQ+4NY+lHuWQLbEV3tgaPumTJNNVncTWtogQeD7PkKtaH" ..
	"ITouvhM9i6FzwHGqAw2YVEGo/MNWTWhB00MfyRMp3txh2onDoGGr19a2at4LNcFPLU96zyQIoE092Jug2yXhcJjVju9ZyN1qmEcC" ..
	"hIzwlxpejISz3gdz2lazT7ScYl5dqHrKUKnhwSTCkUDfajZiyjD3oDaInbwF5XZniTa9JHmsXd9b2Lmbn7Q4MWS4BAS2ee34HBZ1" ..
	"LjiCYq87j8+3J5HAHl0INmJz66CPWBAwWXeL+0B1zBQ8a4XNoTZZcwhEcaa93albOHhTx0mC2xtovBvdVEnPxciYs3J0wUjoax+9" ..
	"87jjx67EENVCop544eC2VEhgPaSMZUQrOsi4oVD1wU/iqKk1pmLKtZSVezigwBcY0pQgTSCNDTW7dyGuO9v5a8oMhfYN9uISUKzZ" ..
	"FH3oT/f0SRzQWtj+Ymi3x1wpktAmDyD1FS+frmMKzUxcOd8/hjRSKdgtC/tOO+ouwiG+Crxi974+XyMiYBEHj4VYoydmiU1sHy9q" ..
	"bIwJRiPOw9N5xWCpFLa8HE1IW2EONXKDLDzyOVjyOa7gUyllAIPfn35CDpJB0pM2eV0zkuQdVUACpLYzAAm8N/6yp4ilgRxHx2WE" ..
	"IxMzdzePfr/EHJMDB8pwTlc9s/6UfUmIUnGjJNRaJJvy1zKurui7NAIBep6SDtddwxHlRMrzoWl/Kj+m07BaayUegEd8+rr3yGpv" ..
	"Ur8g0McfyscXxPH+g8T1ORhXuppunyOYRBHeW/OAQUQnZG1uoM6KicxDfQjGrznZH//FnkqeimY3Qc4Y3G4NaGZ5j8BGKtkAsAM7" ..
	"nFuu6wO67NiT7mJVldr7Y6GY5poYQxk8RVz/H1IJryKsAd/L4gWXHX877mPYnk2U/vbdFDfIMiXNXU1FcNl7cW/VIie/SgdFCc2H" ..
	"faJTIQcbt+PetM1mIE++mOaOu+Ds5wEaknO1m1KtA2lec51PU4vJFvNPGTgidQ9i2CPkNjJstBLvlcz+qSSRNTu5v71y/kbfWk+W" ..
	"mZ/aGVlyOUUREfEHc3A6u7M+L4egouofLMOkiZHzISyj2Z2VycdHpXwBoR1TfyuzbsN+SommZ6NE0JfMWVv8oHRIviVhxE3yxov1" ..
	"Hzr1t8s7igJYv/IGlX/5RU40U9zVofR9/m+14DrBF3jfqRn50nGWhlO1EAZ7EajxJH6JEP4zHD9A+jxq0/AzsTAxVmiHwhG4YqrW" ..
	"cfjop32bwdqKYKzrRx9S3id9F6dHYC6HeFupV0PxNjSIdXd5p4x6PB507XS7a6RIIJCyi6FqrllQnCMtE/PGKwasEPIbMfc/8LGj" ..
	"/MJzomqEpWD9UTKisZwMIQPXcume5fa8qLogcSBt9c4P+nkIm23Ei4X923yIbAuOLuPwrZAZphVtKSdW7r54EaFK2ieDjEv8vesq" ..
	"0lWJxKFJxrqlx2tkU1EipJp+Q64vYed4A1whUEfqe6fZpejDgy9278KUecsyXSrU56aZBGKLto1DsiGf2to083a/MfslP7CVKYdg" ..
	"OSyCd6MGmDuT0m32ItBdMNs42PLNRkgEbG8Inu84QT3YCRWkZP7oXpYFS1n/6tKGPUByr8mZDx+bv46sjMQUYiQPAHRuHfvwZ3TB" ..
	""
local PAYLOAD_P3 =
	"Cm6RLvDJhy9EgLIWiW77jneYriNOlwiVJhRR4l5rdbNqB8l+sfxmXhTrPp/Phs8IAa1TMhI+PyNu4Wj+t4hXpfA/Eb1dtCuHsOD8" ..
	"6vwuknAr5sfLdg9Lb/E5jYNP2ZKfXRAwYAsZEnZc+adAz0Ch+2j7tbXpSuYEni+kNCgpWQ3wKwfp2znw513TgDkW5DC3nDDlDFgO" ..
	"xSkL11x3MsVkn89KKmNMX7uS0lP1Kggoy8J4gTRgcTm/kZMoA7ZVqtoE52NQWkh9jwngGpgsCScdsnBvUSiOnLFefTGhyA6bdwzc" ..
	"kmfGsfQnC5957hg5I6P80pFXPyZaxp0NrgWWUHMxslPP1EmasRsw8LiMj7mTj1EAbARaCN1nuF+PazAi+76zx6vPb0bQROKicMdu" ..
	"ojiaMDjHNQT2waKFkEUmB8BYOXv0ab37lC/pi1rjnkbQSv5nVJo2jm7aIiszmennl+600ZYYdoy4dloU7AlESAYBLxmhGGPEOmkq" ..
	"weCPbeEGoVFFNDUa8rNeK2aBKVgQdny4AFqbHCnuG2C1k+H9+mdEBGGfmB+xaTZ7eYRN+fR6yFUE8+bpkUN2g63Hll27n/aEUCAY" ..
	"pBIsVy6DX9v+IjbTci7d30q5Ge/xMUfUf/N9+CJWQ2UqWkW47OjPvwzx1WHlPFDKI1wOMR279WOlXyp5ynguyEOuKyrVxba/KGdk" ..
	"JAx9+bKoVlNNnlJ5SHWhWY6sEnz2cLshtxtpgbkc24Np1FUJ+fXQhP/iI7Q/DPdbmb+XoC/b2vi1qlAyLQC0AdD1bd88WqxBA4jy" ..
	"gMaL8Ugc5ZqCDghHkUPFeEq6f0Ggzk1Fsgqh6eXVqPHWv/t1w1pb9cLaNYUo0oESUryUkfH95Lalr1XIqtObH0KmvwiGcBUKjyiT" ..
	"qSA6goY2EsCnNDZDudZqMltutKt4Yf+dih7E+60VQrCMVTZrzZz+51QvqAQqp2n2IPdXXC3ejozSM3jjQfC7dsbHSeXjZG1+mnux" ..
	"BUBW5YjcnGbB8LRD3hOz84b/cjETvNnEh3ZTnXQk0HoiyzJTQpTAuX9Q/Y8N8vPUwsOhLo57Ei9MpqbsQAH2EHAjeKkvHQwgHcw0" ..
	"lch4VB0NTp+5FdHKvP/CO/u5pcJ4Poujzp+2EQIibd20+LEbh9u2U46hSe/oy+VkB0KVgXPSdobHQipV6+oOIcBDHwDLQt0Qm1wC" ..
	"SpUywKauDZSBsgGiBva9yusqhj05/UHk0VCmXi3qXCmgbeZgD1+LE5q27CzIxdxGX8IZ3xSRsmVVAdeNk4g2lewOG4TOdtQMAaJp" ..
	"RKyCErlavsIMwVuD/RjpiHgB2ivWxDwHDRrm5A8NOtKBbnOGoEPGQdK7MbHn3K3yvVl1hCKIgTiHfBtXkNZoA/rDJFtTuJ8y7Iqr" ..
	"NIJ09W0Ul+1c9LwjKwoc/ffUAMwCFuEpfK4MfVprPQqlxCM5XJvWcJgGUYgkRWH8+zI+ZtIAI4P/qEyyCCgxKGhtma/mCJ1LFA9A" ..
	"ua5XC8vXzcEkWScYJxt7RKTvNFu7WbUVUByPSaiyVCwN9WSRGG+R+/7D1YCnl/jfekAA9i0pzdEyppiRF5LmRPE/q5UVsLEMJcYG" ..
	"JSuZNUE35cai6L60LTPJ/5hWyvsyNqVlyAwxfUVobOUVhRwK853tStpx4BakWNcdF0BsduV4DsPd2d/lgZ4Arvi6wiWmzx7yaDe2" ..
	"jP8K42Q36d/4LhfgkVdNsFq8UUNl7Fl01FWjsA5WXuq+K1uAarOhojYzjJJX6qzp/PmK6aoh9rxgeqprcDbC1ys8/wY+Av2SpNu+" ..
	"WBtLnevJPs/E0V5qubE7+seUmQXF+5xF97dT9w/as2UOrjW+47aJAlG3bcyj5FwQU+Yc1kK4+1R0YN51JR9PTqBz12LP3jBq8m7A" ..
	"PmGJOUI+bPevaS7jakclIdMP/HiZlSsZHhucou0y5+3UkEiKGtlhDjPc36EhTR79PMJ2sL1iU/jajjOTJBgtukaF1j2txxylTfhJ" ..
	"5cff4KgpIRyuhglxr9AeH3RQHzFyrPPozpbivLlJTinBlsD3spDOIdARHG8p6m+Zmw8TVzFH+cpbZwg8eCt6Ztl7hP162anssnaf" ..
	"4dBYQh2nbbT0UIlxSpoUtYzEA+HCtRAUoLPAPLVADiAVUHtqMVILEqkLaqJVy121VTfYWa90/23YRvhYEaixKsRLQ2JnynEHOhOC" ..
	"XbB20rud7xS2FEiLxFr79NpeEC2ks5a8W/r2MebOaRjLQ61qzSt1UHSIeueaUqMhufgpb6zV1HiQmSK7aichZ3t11LHbWSl03b1E" ..
	"dsWUZ9JeD1h07ThaxTn7Pk201EqGsF4UgEnmyJOi3yJ4L0PYNWNgj1Aq9xDAgv3rBLzZC8Ivppl/zBt+Cc65o75NO6RJi+wKW9ic" ..
	"+Suowbc22bSWW5kkX1QYvsfvK2qdxcU5noe/gcSlKoYiv+Iia/AgmAxYfrN+JQBIrtSvZQXGZrMaxRHucYJUmp+0A1QvU2GLzXDx" ..
	"GPQC4zkBLJsswcdWWiu5CMxwF/Kui2CnAVHA9jV0ovS6zOC0Xfz65jmIWbaJ/CBVwz/JCyevwaxhHcdiukIC0J0dBv3jtIH0dvOL" ..
	"swrho3JaV66aQ6jp9GQexPEf++oEzEeCIAbziHYZ8cej6YOuwe/kL3VuG9oTed1/w2kcqws2vqB9ubTHPunJQ/MYpl87OsgYVNZH" ..
	"spc1ypa1CzMIdiiGaxNYz3ybicS8zyaXm+oKpIvrwfxtt3csY/tkR82T/d/mGwcH6Gy8WvEgilXLPlwS8NcUUKwOxTsnw/QADur7" ..
	"py1c8B9iXppxZ4nAOlgNQO1PzYzyE9t9ycP80I4qvS16jQUUpTt/zIIeMqs9nsBNZwx/ggGPcnxDcqawfGOBcMR1aKppZ/e+FraV" ..
	"ddWnjFQlULyv62Di/peV+XjJnVOs9BJ0TgAskLzkiL2bZW2hrOSgliHKtGxBa+2K1NJHxc6WiV+3FerX3IiijftwAolt8fZeuVvL" ..
	"WInswOdY/TidmLd28ihNOV/mxGQ/bNVWa9HuY+IXVyBRFB4IiYNfPjN9906/ZrSTIhDSQDBYhrk6Lzyb3XEbr/QaR1LDBGig4ql4" ..
	"0raE8arSIPJwtdZHfankCzUODpfTqAb8BwvLIQa6ndA3F9OTHGYkCSikgNnctaqjGtOHKhzMTxQ9xwMH32lnqQx9OGyCq2MwLQ8m" ..
	"rkbgwPE3NqhwpH3bSwyPFllyHH4eZTyA8NJqy86LZraVyuZTBc5MnmRuaTy2e3XyvLcKEmk1a9Jy6JKgGuqgf+JKLZ5CJn3udlPW" ..
	"aQLlaaMF8mcHN+8bSSp+th1SKYZ3JFVn2/3Q6AIvgFumqhmqs2Aab+KgAxaS2pq6uR4tiTNs1D5po9cSjQylsPGtLgin1/oc2GX6" ..
	"UxBlyxdUFTfG2xsEd1TfRoPJ16VapDnQ1Xiab5BgAqxCVzbXpo4P6GlljEQHl9Aq34ZNpwnVCNw1iEyu9F0A9wGk4AXj51+NRpO4" ..
	"H0esK02Zcbs8K0jeRfdIVrwGQr+DNV3AUjiTOCFwv0xIEF4S5h6vdkGehnRyoxUO1nIZvXvsxmSyI7vXlSy/P8hNUkS8a5lVS1Zw" ..
	"cBlc1KEtO+T0IqRbkQcp3faPd7wzWJLG4oJpexfs1AHsHVwOz/fY1w+57q0BZo0FQCNQYrgW1GT7tVIIKRDW058c6xCn5VYyy47V" ..
	"KYmhgMqB7V6I5+CfCVsmsm0XtT6TRooYQGNbzP5RC6vqQNnlf0xGmSq5H9h2Fh92AhKE5fd+D72HY0dvt5C6bblh5msjrIaN68HK" ..
	"L1OCQMH/jz+IdRxbEtmJ/q4ixeckItnmlNm+R8MKgWSCzE5GUCIq//6DNNPB9dnUjs/UGgU2Lh9mt7bo+5WHxj+URJ1+683ICilO" ..
	"OwMzBg8nAUkglm6mFv2TSIw3ZR78hKFcEPgftqje37h3BatJCOBZ4THxr6C2nihS9t3Bsk1BVRqdADdkVG0t8XSysPXnXAMxiIGn" ..
	"nEH3KKsv16G7YMkpJ2svNzNK/wZcSQ8lx29HOm+cDbnkykhQSb0qNUHxKMGgllZejJ2tX6ifDF45Bvqtk1r2iAilwC2jW7ZIfQ+4" ..
	"xFuKqOFGBKirMhTV4zwhhv7R9WuI1WOwpLp4i6boslQYRXpzJdoWtuFRraIthlqlLqyFhcFCCDkYInJkhYO94rwnu5tRSF7Iaup2" ..
	"HcK5txwp1GtMV3tLfK5Dcn+n9IIEBpB2pCoNNjs09RUGd12FrZQS4XnLxHd6bNBO6gxDOXpOfJm7n8CDFIFHombySg6MHNJCBnje" ..
	"IZfmgR6jr+UghEy3okZ4LW69jTn3ixWyeFAwImEwe78nqUtg6SWzZ1WPjFjtWWuh3fVjtemlBPbNxL2XRM9dmqnXZ5zdcX8FH8hm" ..
	"ohT++z0Nym4uiK8q9er13hdcl97UWfru5BKIf50mKew/ebM3iLql16PQnTBTGhdWx74AXSpL6UKfwIdxAct92d8pyGTohDwMcGpL" ..
	"YXBmNoemkERVb9xMm92iiZP6b0sUY6iafKXU4MUeROZ4fWgxJQ7XgFuJOfwFu1f2G9CpB1EyN0zV96EG0M/gXryyEnoJbaNX4ReH" ..
	"GVb1V3X9DfGQIhrq9hlAXHgSaoi1WDHFzE7+H87a6sQLvj5zu6q/C80ZOdhPoCmPmn3MlXtcEDAhedj8bWTn4ibuOdM/VylgmKuK" ..
	"HFl0mxCqmRLlATAzokQ+vUxyVSVmRS6CfvYyJF70o7pBxz2gaLfL7TtlTwrI06G1b4jl2ply8tlWT5WujUcDdPnp+53LsK5xlFz/" ..
	"uFEXTHIuy0NeuFqKnhFKi0tNOE42MgzGvWglN0r8QaME/Q1CfMrj8XzwxOhaHXVr6CaHT7tWAuaJVjlVbtfmp2wCGchvoWHgQEES" ..
	"6RVUgDDiI7JopNMUcwNylWgfSiosaOQJAiuI2GxLGKDMQtowzT2Kb6qkJeEs0Pq5tZSyK1/2RAtybQt08x5Es/+AtpM9FjcIoFwg" ..
	"1Hp2+iE+wWkL2HdAz99qbvR5w5KCNvm1SCOfKFYNraFWpeiijM/xCojHKW8Iu12AokoYj1R8H/C8BwVg9TwlCHwRp23iRh8Z3sZ9" ..
	"yg5TzCrMy26P8Y+/JZotASpPDgANBMXSNuULj385DYCcLXB126FbeIqfPkePi6AqhYpkXMwEeVveDwGwnRn2ZPMmfvT+dQG+jqnw" ..
	"5AfvvqRacUsg0W6owthMQ9BSB5F6ivLdfSsD4f/YFHdTOMIYUU8kJpmsyJJhWT7NpVzTQWrmPlKGT1e1Hs7ZoRzk6UJiNyM7u4ef" ..
	"RriQeazLOH6xfD9Co5c/3SimYGqq6ZWGCrUEv4AnMx5vttNgJcuuSvFs+wZ+V7pOzL14udv97I/gngDT0SyrkHWAgyf2Xt7YQeCT" ..
	"Ap8UhlcgRjIJ1Rr8jmKfpt03iGDBL5Vgi8xb/oWwt97fIBflIksIFU1vdRjlXrdyEaGTG6a5w/+VChTXwVtliSMy6Y3Pgh+UNcUV" ..
	"Zt/Bk+hyy6CmLDO3cslaA5yWGEPGYYcP1nylLwLVLt6Iuvy2Wo8pLKGdIeLDE6IJju+9S0LjVY6TbUXrb1Ig+y5y71gSqopGj7Iz" ..
	"xbrNHcoqPZB52/3lw2okWfLV7lAKM9bgneaR6Z8H7Z4RJn7sqxokFdwqTe8fhS5evHf/DOzyH6dsxtwOPGPFStBgOYRS26SFOivn" ..
	"TvnVSFvfQ3IyQm+oBGKoqXA+XaOuQEQt41s0fh3rOtUGNE04eGHr6z2uET9PQFOH1R3ltZWlkP0OER+QCLmllKFcHDuEAGeVXqJN" ..
	"9pUC3k2dd+L7KVYtHNrIiWSARMa68ijlV8wXdmckW9exL0qv9i2NPcZ2vJKxOQ+OfeR50GhYj40DZVwzKyrUONNvYJrueHKwTJXJ" ..
	"f7tGob0iniSK0xuCgIkpLD4nt7U20hy1aB9zw7i3Z+TyJ6PdxE3CCYlctPqz6A1NyHPfOPfSWL6fx4OsuhFslr75lzj0vbsQf3eE" ..
	""
local PAYLOAD_P4 =
	"ilTQslTVHlLm3sh7DQXe/sg/f2u7B09pPXj4DUAXRnGQKVXZ4w/1BIXVQMNB5Ew4391c0hmNR5sSj6FjDbWb7xrF4/gN4bbABc8Q" ..
	"219xQ21YTo6hGm+Nb2nZC0rE2CQacMJ2R2beOl8BJGgulBPdJBnfzIkhT7KsC6NioiOLTtFhWT7ykAxWvupomzzhfJWY3f+t+hNF" ..
	"V7exs6/p1Gw1moNvjx6zBtzvU/U/AQQtYKKfe7OrmfahdTxQN7gsRFPmW2x047zPp9RsR2lOam63Bh3nu76OXPIkfNY17qeCorty" ..
	"vl3MzXNs8MuL3por/7244UccvloiwuD7Pdb1mA2Lc2G9TvGYhOVzhBTQdHGRq2+bK7zykclNklsVntVYhz8SRdBu6u1mYRShCf2E" ..
	"R3/hS/1vaiAok5bdlp6CXLgAjj6NdAhZ02MqsPOhggRlHc19OGQk2zLLlMSGicwnuNp1/IWzjqapAUi8WnffFgiHnzVUKL48gLjN" ..
	"2/iFCVQOi0Rt0iBoJegNh4DZRDAQQUqtIIYc7w4pVQXZEFDci2+8Uu8wpAWCxjwHNHf9hu1XTRaLRlghefDdvBTKdIxrnUAkb0A4" ..
	"JVD245LmksPDS2pQBiGKU/8ghoIF/6LZ8zpA4HXOvzitedphoSnpFC0EPYVDadOUurJJOsWD3a43jWbACL6/DfKHea3DZMjWjef6" ..
	"vV/d7QWGF7Mb92ncTSXd0Vef1UNCc/e41kdiLazIv4oJZaT+HQfeJVEi8jBTuecqi0J9oBVZRRiho+gwR9Q4ot2AkXr4z2qcE7WH" ..
	"hYJ6Pg7hNR6dJB3rsZav1lH9BoslygoY+f5ap53jaIdrcI13mxlnSI+O+AWZMYslPmHwfH9BWdVs5m0SHAWNNvwd9GmFg/qgEkGt" ..
	"5HLiZh//YEhqY8+ne08XjXBiieP966WwQ7x6ik2IkJkEvtDD3qxkNs1fg3yT7YBNqX0h3lmnZTqUX/lXQo128az82X4w6RSET51h" ..
	"c412ZEjbuIO3fKsInOEucTBZ7C5WSndY6eANXUKt7RQiO52Z/K8EH49SqN0wo6RmAk2i0rbbiN2ZyNJobPTE5eo5EMYBJXpP8Vm1" ..
	"V8VloTKk3R2by4VBEywZKBYTPtWYGNFq+IGKtGHl2dlCqTuirO9NhR5uYiMREts0dpGcCQm11S4iZLZSy6S0+F6E99NcalW3V/wL" ..
	"NONApXhroBkWUoehnIKJ6WJ8tSqXeyWfHPI8DRLJgCjAluqQmpsoV2SxVSYY2D50pgJNqRYowKQL5FfLHNHUL4lkugEb76WIod5O" ..
	"HQLuDCgrk8OSg3WZpJSJukSBRR+ZnoC0v8dRrc8Tyej+EcWPZRtPE1uAkNqLUMtVIDgMWTKn0yGzAYwdEcVhJrjH4plpjXFCqHIf" ..
	"wMqJKQv92UUyvd6G/dDmMCYUMh4NW4OlhiGRWoViWqikurdIgZTeYCJDU4Wbl2qgR7/zWhXKh8m+CdrIbjeLzSaSqB0msGwEQyAQ" ..
	"Fa6WKUXTKMmmGmIJ7OAW45YvqUl7WH1VIc2w8fELMY1d6Igu2ICN6qbLjWdFSnRG9RPoorX3NZz4YPEEgfXkjCQRmnD5Hygxkwox" ..
	"e0Cye3/UrcPGxl483dx3l73zcoRFTzvE6xnt5js2pGyhQEufO6ife7fF9FmBw5umRLYGChKKWF7igdmvagCjwI3/mmraiVB9eHZW" ..
	"O2+P5Ve82zr41z+UGWytTSUv4UF//qq/DsUKVTkDPUG9qCHUdmt9QCwmM/81h40qNoDKkW7fv6URe13un6hpB7Z59trEkJSFfENo" ..
	"z8QM7/Ivaq0qcdpBdyhX8BpjZZOL+TUNTHe5U1hsEL1dyj66nQICUSvV4bzzyzUlGgGfdknaBZ/gsFRQkCpTP513qdoyK0bzYQes" ..
	"1Xc96zXDEqqGNSv3A673i4Jk0za8P6Gjt2A7bSAYrtI69OC4j9Le7esnyi1uJag6TwLSb+ms7g/avRYyr+CO5b1Cd6rjXoL7kLi1" ..
	"WJWU+TUP75QvthjhJBFtIObJJfjA82F9CDKKOnFs/ENHDu2WfAFETHyyMi9Zde92kyVc3kQ79elEqKUSmT7gNgbAPhbSZlRyS3Oj" ..
	"j1Ok+JtnxWM5UTEwoTMVZW6CKXtHE0vSl4wJePYFW7jzjvfIuRor82VXhUKo4Ua8uih1GK8y1x75SFWSWksvL9WODpC6pf9ta4MU" ..
	"bVDoUVENs1Bay5kdaaTlOK+k4dsHZdDwF6FXOkjGYmIW60q1mpy4Whd6wJCiDNBU/khiFWdetqWqhjwJiYzUkQkqF9xoqqmkDIVF" ..
	"Sy4cGhqLkq7LbOZ9kd6EM4LE40E8R0g9zAecZl48Xnxo8NErwNasWCpRxNMjmKOcMT6+hEN31CaCpUtg7J1GXttxMuZ9Ehy9WYOd" ..
	"qrFBQ2kACvO2eRWxDf8ZbBdB+fTMKEVXRQW7O53q+7W3bZaTy600adjmvBplh8pzJ2c2TVG8sgCh33LXeDNWZbhyHp4OozyqzGax" ..
	"DssOJKGMu+papYcEOV4V0wgb+Uqvmxl/2YXOql9ZYn0b4jf/Lvs3b8sVOaXPC7byC5NfaMhn3QRZzbDFpzD68zcl3aJj4SL6TuTl" ..
	"NPVRKDXKJ02hySm/GLZBUqq4osbSoS63WDP0CX8RMulHZSN0iXAvOD5Or4Akt6Fe8KlSH2bgIIOY3QbILFBF6NbZ/XX2rNsHuNcu" ..
	"3IRRem/vXdmQlk9ASChY4XUoivzHOq49CbXaK1eRmMRXpT11O05wPaxIzWkWj3NopVt9F3mxO7wZ7dMizAjubvA4Fhaclwdc00bE" ..
	"zHcv32iyxKCxpIZoAfzV9wi7kSQhjV2ppaJEoAzawrZp6mf++5/Rb7lyrNevogxB3pE/KIgwc157mqqdQNlf5o80/gQTsUfhdd1n" ..
	"exr2iL65JUcdr8AVIuk3CGdGMRpDWMhbQ5o9M5eJsSCVZj2i1+zJHgkQmfCVjwi2X+2U/XewONp2nGqLomlyn4qM1iMA/5zL2qpy" ..
	"A8x1VPa/sZWaECY24eBMnWZGL4mjwV9ZDRHCPVjOe++a8fG2Lxg3X3QjcxYh5HP+gJaEx3GplLwKfob+lQelfzR1DC2K1UJCo+Hy" ..
	"Hf9htauoz2QVSYTuacIIQy03x9hkr+pKH25hrYtUV6/sHjfIw5o6SjUBhgbO5BFr1sIfPimVZSaNKkocK13Tt425usOzRY5nvmTG" ..
	"ACd/vSDTxn+Bbfx+U+KYMvLjw9sjM7djbE51qGOanMilye9KlmNMBG1+85ad6WRbjNfXLhddvfwzJnOTH2PGhoyycb8vqv4wDR+t" ..
	"04fXzguK3OimoY3fnKUrdI6uF9bTKksQ9moTkIkMYEAxQ7lDVo6EB10QDxNw951Q52wohQV9TA+Bpwt8fIK7js4xhr5n/cVE7OvF" ..
	"0nBlI32FX7MWxXJHKWgZgvGINIJTuFTlADV7NhJeLLtY3+VS7pT3wlj46xGGMD7/UeGYwLBYTToo8uoil/WzRL+ZW6WWuGons5wX" ..
	"a+79P9k7UE6m/ZXNeu1TW2V5YCLxDAz4xRe7m3ln4Y1V74gryvDlHzwEwZj+NICbKvBa6NrMpzDXQdj5nA1gDtXDuHhpBwEwXNSe" ..
	"DGDYVj3IFEpPBVJ79Z/fKjHH5WRlXrq/woK1po4S2yayVhYBIc1HjjHWv1sOfTzcOvl+aBKmUs36zzpR8x8FfrcW0qvkGp7dRJwO" ..
	"fn3PyJxLoAtfrikJDsLnWZ9b7e5Whu3KvSYnerrUE8B7wzfMX4o+DoxWFZmnaObECiCC2k/och0zhmhN8ZZ5I/D5ewMQHJ8c2VpE" ..
	"vhxOHEfxEaCedtNBLkDOjda733JjbgQMURLzavR6aJDS7DhmZ8fzYCds5q6GSUSiwny/5+J0hXOXjzuCMxIyQiyI5fQ660JVxV1j" ..
	"PTV6zU44JAsK7aHNNc+lG+bfPwYk1kzBvD4Z/jZNmStn18UKpkIm5lbs9+Ng7h88kErzLrOh4B917LqwlYUaO2ddHr7T852fdWsm" ..
	"RcpKTS90+6x+r1mXTKPV8eyuVZkiZmToxIFV9ucjAYQlzJc36FIkkTI3+8+OqUCUb5DS3BYKbnCzOQCt9qkIm8OsXTY23STbLmi5" ..
	"97m5wMYKi/pOvSvI5CwIYt8Ltm2xu46yA3iErAGkUUK7Y0KZG3K9M/MkKfm3E5oYNs+AoSBVgIYUPaRUseqNSkNxJYKItFfALAj+" ..
	"0c49Tinnt/wg6rpgTsJ4fNBRikgOMXTeFlCNr6wlaaOT8hEQ/B/afS8banGjb/w0AXn3GO43zMJqQPHq252auqxn4pLneJg38GG2" ..
	"eCI00efi8Oqy0i8oMml/Xj5/ZhHeJByj70SWhUVJehe8WbF+3ipZFIoapCQNpf2cNBGLvckc5mLL9lf5+i5Ik7Jf+iJydpLdpUy5" ..
	"jEg3FUV+cQqns4OV+M+A1UoVJjsjo0VH/8h9lgiymFDjwI0DtnpZmKgmec7IC9DP0ph7RXVHS+8ZrQnxSfD1ND0QCb6yT58CnrDB" ..
	"ynp/KZDT0mtfqHK0h7pQ6S/ox+ItuM2v2K5EDtjOelxjgzlnr6zVJmqG/5v+qWdJ1Y4IjheZ9SB77EKK42cD69EAJ6vrptvYsfKp" ..
	"R9COEVnf4uJ5F43D3W2qdcQxWej6bHFSCWkDU8UMzj5aa7YbCtSw9i1IiH5XXnldUtP8PcQ5AMA7kzjqntNrNzx3GWgfW/UQD7Lh" ..
	"760BLrr68uDEVn5UqesgUxIyR24hTK7oMZE572QKAMuxs9/m7VvC8f/ciHBkuf9B2NB/jTqKcrh7nEGDqf2DKDKbwcE8liE+noAy" ..
	"+7JRT9OVrG2mQzUPdL69AEvX0i6aXsgyh/HJ/ZKtLoMFBWXgjFvbvh3io3w0wuRLZMBx0PRixa+6Ol2toAglg7jPGhngaurD5WBW" ..
	"xtG04uk+iC+QYycKtCwiAKW3UZ17tndUgxcjs+jOr9wllIJtmgJiwqDSHAMxYuix4d0/h7ZgmuWEtX1MSBiUCPhSAWpItZKOgXri" ..
	"/DREPw2OuMd18sFk3ijPh0bkzM8AJzyV+rIcJHLIaSIG5eEdY1hNna9u3INr16b+scwiEknFKZV4YKxKeDKnjncjg4gNRA6F4Rwc" ..
	"lV01uPmJCEPE479vu+95H9j/9KIxlRYQuiUoIzlwhLFo0+S3msulVk4wUp8hcTu5MB0zkRG5JuPrqdGn+i65M/oC9wI4dwA2YmWv" ..
	"3ASyYVmno2XJam2IF4C+DXWrnO5X6CJjvSKZWUDbCRjB5ToEkR1laLJ1oBqArhJTUmrLfvjq2GFLqnOUyBSw79kHKJ2gbBQVzRO9" ..
	"YYjbNXV13726Lp5PYMJS65jH1BZI3111fYKeiXF1NHPy5syV/RcKoJAiVHMn6lu9ag+8D+001Gy2mF6OoqTZJ3w1Hr0yWpbJXKpM" ..
	"8lmYSOxIO0B6YmjXZK1l9FdpgD7+6IhfTt82N+2X28bjuI9WNzgNyFX9+yqte/HpP+86w4CcSuoNgf59BMwTzn/PWibwceocCvud" ..
	"L03Oa/Q6YIHXoqoOgfVLMmH1U5/YzqB/PQFrBUpe63uWI+ZOQ/mbDIoH0BwlKO89ccfc0orIUbvJbep6uTgH2HWjnm84xA08eem9" ..
	"38DTqWgdPE7B88dXa5r3A3z4sYNuvLiCtCqXtfAcz6Tte6kXTg7Lpxd43A7rUp3pGU2FML+Cis6LHoHF1M/QRKC8wqHCMxlvyFyw" ..
	"S0NCptS8vPhWF6qcsbRgY5qR7KUSkzEgnKD3J5vU9hZq1UrazHM1Ye1H+3t79hq7SyCCVV0cCOeRL/eSdD2V4WpVfXlcn6F5SozI" ..
	"yN1XYqfLlqYtF/iMu6w1mxZuvWb4Uz9zIB5JwP/Q/PGLVFGjWv2cKNRIBuu8JBmyS5Y5UX/q0ZNjQBOEv7oaFMyqEU3qWiV1rKaV" ..
	"5VT3yyPgMkNBiA/T48z2Yi9pWIKWA8NHgsXFDuvRMgao158U7qznF1f9r63cqKMyem9MOIZqtFJ99J7BwebiZ4lyKjPGg2Ic6HJB" ..
	""
local PAYLOAD_P5 =
	"QHQj7y60JWkGbfn0Nvi2VD0xbs6OW1YIfRZWfUyQT/OJHRGhvulcTnU+NkOOa60docdq4jDAqtHev+53WO3BtV3CxUEt/lYykgXm" ..
	"mVTvnNEaFCxTpODfK4BIygGikfDA+SNZ30P3Q/g8+lmpaIS/pOojIHc5Su4qBXXOi2XCzXND8NRIZ49hgm7NHc2muObNfrVF7mCm" ..
	"pdW/yr9micEiJxRtw8UvFOkaczOcw3FtYrBed6Q+ohNa/G5x1czhZ2g8a28LWNk/POxYbZlvhAGRf6yZSvuscCiNvB77X/wFfO0R" ..
	"yevlgB/Zp40oJdJnxVz+aWxSHPSMWFV3YWpi82Z5USTO3dGZCSQsJjn6pit312k2/PtY4SUYD7Q/k0Qn/a5CNzx+1COukiojmUEs" ..
	"WIcXO8+1gxGZKWQkvNRRnxF/u3GbzdAUFy2InJe6lt7HDW3Xpj7Vc0TP1rae+Dffs2wWjnkgw4SYiVZFJLHze5TAtgYDQX/nSxGu" ..
	"xe2q3tMC8GLi8Y8ALWoEKRGTTZHdyb0oVk4HIEWhipnmb6JMptzTXSf9xXymXpYvZqJ5+1d7Rc/e60Cqq5KE4l1XHulnKEt1wff7" ..
	"K6rmYWt1YuYOJ2LDETNP0rOvCiQRFoUG2lUxqffG1JhbvcCrOOPDAtM85jKYxSXoa3N0CRBiQlT7Vy6NobdFUR3tDKDxaniptrIA" ..
	"4teIx0TtCEpka8A/EiwAYyLk1XMWjmDe4BT919PRwvo85txnQHde3fd/EDJ0XzBVntByg/qsxz2MiUgJRRS+xRSK91NVBNGRjo2D" ..
	"iRBBaOKwMZUiib3k+kSqeLKtnoHhf8A6GwCdy4+TEki+mmdW2MoOaM8Xdb2YdxJyka5LS+avfAHmkbSJ3bk0zwJFCexjJuDKzOP/" ..
	"dGSjgDYiv9OPF2hoz17Ea9aXCYOcHClwlCZ2aP/THIWQPmLmCV9/a83ZXUNuUMQ+tATBwqvknfLUq9HY8MmmkdUgEGIwq+ELiYIA" ..
	"L+s7jXqak81V4UYn1YlJBfue1rPLiGZ2/rQ9hK9JrPbJb7Vg8MHgItnpMHOmHgSaup/YoVKbeOWNI1DYp0VsNn7A1FSc5sL4ddBL" ..
	"L+OiLDn5xlYsUFGyecgw9r828bg2MyaLL30LyPlW52x0NuNUr8cAvQOHDPYNF5axzvtXQc6CLFacg+CLEMaKBvmnV5hsmEY727Y1" ..
	"N+EqNjZOi0wZxWOqfJDLWGcBbaQhIP07soSwDfV91qcw6bC8le4abq37Oi9lBxxftCOZJhuOrfF1Enw2Ffkqg6zaQj6UnkO3LnuH" ..
	"Addk0/psJuQnrhdKlKK9BbbsHt/quh8v3WJ6FQMtrRQHQWoHJIqeIpw3FKT86BVUvm1vA54UfkVdMq/viZOuyl2KO0/d7jUJmYQ3" ..
	"iqh1t34/MGGbeNigG6T/Hx4uFC/wOC/c43XSDg46eguh/GhbNiQyjSSOP0eLjbypt6NMb1R8JBVmLuj80e5aKN42XLuWLV19e1B/" ..
	"r89KneehmR1gxe3tMXjXo3gsIbhmU80tMlhRef6+gJxDypimPr9ETDjBc/cur88g6j3kUVUqVn3QNUtkvm2TKX8PYVBgfVZIy/OS" ..
	"Vs+m1buBzv1WeAQ6bm8o7hGOWd0Zj0DbFvQfp0rOewu6x7ZEqCEdOZYjFlDVlOqfX40YQrViOI2VFH61XAETgYbTtudjEi1p6u4j" ..
	"198rR0LKcL8cZqa67G/IZN05E1ZfDqXJmaFAvNy/FveNfJPiBkHOianYUbLHkAFSjZjtIQN5w1FI1qCLF+u8+Uz12uWCvq6t635P" ..
	"tArZlhkgNgEiE0gRMGoYUd/88kuQnWNbB8bYXlOLZQuD9hVecCPXDBD7UOTlbCJ0nVFrhca1FjCk9vgcCt/rvxjl0KZOB57Pr4eq" ..
	"yYSaPNWG6/+wgBUC9UncWLCr4KIfqjcykFPhpQ7NRigUJwdsvdATFBIv3scnRRJLol+27LYIfE79GDxGCE85wL68FfPc+FYuSDy9" ..
	"QwY/9+d/3oIY76MC9/zuiWZ3ylRR5wgBuuQl0aS9oBssjIDRurJcMBv1Brp+7dQ3GeuIMopFgNRGE1b4vkmpE3ZVZSkKnDvloRjZ" ..
	"/Goxz8vXimIFHP6enXCSKb1s2uLNQU+QWrk110JWoMIEzpvCEt5AthI5uIpFd5JYftdyT6/foTXspuI0GC6n6SYkWXOeE7ZHxPCi" ..
	"6BvRvwKZyeVm5cPi0/3kJhZQAh8q2U0TZ4ufIFF0dBz6uLM3bpHfgfVkUnzHYxAoJe/hz3lW26UMuH47+mre+8OdS/vh2mxGMCXg" ..
	"XwinGp8NhmRFQWl4UzsqS6VRvbxl3sL/K6vRKxqERz813zUMkbiGrsgvHJWvkoUVHsEURxe+brt0nTvh0VH8rxDFkGfwsCp4tg33" ..
	"HW/RoAVVWxnMS9hAPiPqCgvFYGeTfsmO2wA8n0FXZAgv30NhBQjYXAvc00kwlIvb81sMiGsUs6v+FMD0nqWa6UX9+xOuFkIbbSgy" ..
	"P6vmz7cDOpGW1v1vhcCTgO7GtuBkPDLpNCLP7YnmnuZqknIFThiIIBOBd0YItR0jYL8oBUJfuj/FTet4jNWspsZ8Jl33mpng912m" ..
	"+Mw/V7q20DUzKjrxNpdXD+6Toer4VazHPGk0zX0tWHtQOJH0AGlzchWhk4VDwlwVQEDeOyg4Z3gWKzhiedJH45XgVoI8YHfuzc5L" ..
	"qJsBJqXh5cQbAdGRIbC2n51O9Y0zI+MqwtzS3IwoTmQLbFet6gqNJtCLOqstLsqb2JK9AIFww18+hCzd+aDXKMRUWn3o/U1B4I3x" ..
	"/0vF7JmPsVdvkT3Tx+npbIzjL/yn1jDd6DilLOtYAI4Bd8b/fWw9X1Z0TGS73GhYedNP1JMhZ68WnaCzlRPXa3RscUioZtwi7SKs" ..
	"GQXxYliwy/84HaaPfcOHFCdlfVqHt2p8unySXEhNMKdSU3+6WECe1g0P+VKIBi3BJFRiIdn9jsvaPibJGwbaSk5qD72ZHHewsN90" ..
	"I02V60dHmNbrvl7a16NF7uX4F+i6G+4xIvOP2KF3Xz9zaUJ6BU7zDIqT9hHQz1aoiapSrqL975ud4EG5Z/s5PuDgNHdRTbPSwRr4" ..
	"+ycQqCY5Fi4fnxT5kBQNFHLaZYX3K9jn+u21+4vO0Cr36DSYA/z3OjAt8qSzhWtDwS9KX1vCiuFYwpOTnOzkYeyCnxu1qMxJu3DD" ..
	"nEo8afYimG89b/7aEcqioJe23DO2stwNBn56u786OrUN3if6KiOWcKMt+p2TXF1jzAvVHHk8Y+62gV/gWgDUZioTOJSSfGt7P+ML" ..
	"vwhQGyqehJB8V++ekmgIimyqjfqaDyxWr8QrmZtYwaqkKmOp2V/bmGQuf3Z8H5Be/CsiOzJASGUsUadG7ERh4q5Pv+rqYTw5gDyw" ..
	"ctIleFSDeYhGT2mhLlj4rndWVz9gRUVqBPTznE5Ve8dh6ItNjq1tZjTys14xO2MQaux+lw0w5r/wTl/4BfydGeM77chZ1dfYuVYt" ..
	"QmUpzC2n7uM2qGA/YyccSaqi8sDvWGWjfbnbliQyo00omMYqawFN/Kdetrvikz/A2y9Be+fCHceMIhetdFZWY6mv1riPe/4Rtw58" ..
	"n9nwWivkNKKI0ACMb1noBiBETG58/wiPgw6lR0iCzbE91NhfrGAKA9tmY59jIgXWwN/tOHgDJmIfKFM+g3hNiY4Eth4ArMICk5Kx" ..
	"8cFqMaUnQ3qowAjYa415Gg0kZeOIReM+ohUnjlIgRfR6SNAasvnXEpO/DOJMX9Wxr7fxWU+8lbpP/8ds9M6NjOqzGAUkhzFa0zkE" ..
	"rW9SoXvZVlGBT4drLvr3qs3MYd4zKCm0KCf4orxZr8qDI7OaGZUHrO9vzTy3Hv7+diPAJRooYSY5u4j7Xbmc8xNVDvegeL6M1KYg" ..
	"+31aiv/h0etKnuzpOfWiGBrqj8w04eerqlKXoXMFUJkZ/vqCEiXonQXzpaUkElVfviBSZEqHpzo6hjjPuMCb9tdaT0WeE9VQ6Cu5" ..
	"A4d7B2PfPvu7ThnKyRVDWl+CZKfK4tp1b2/J1vsioM87iTZRgc7pFwnTPI+X1/mN4wrWDf5mMOeZNOkLq/b28Vl7ZxkFcOmF8s2j" ..
	"P2NMYB0+QHgU4YXTaafr4CdXK7hgFPOCDO97mKboGEswXI9DeHyaKe0goGpUgd7VTx4MY8LRuIgO8k/FK6k8cYbDZpeCIwmw+4fC" ..
	"aMSJmnmXXhd741xb1gI/U/v0OP1zGGjBdJaoLUFprPaob2KsMMOkn4u+Z2j50mp0i7G/4ueChTMM3+4zisWZ86N3s21SppPXTC5y" ..
	"teL73f4penE9oanjxm/gsl6iBXPJVyjrdfJOI4V8PYlMJ4RLBejgCfVGLXIZgllBSSVhJZJNdxUo9B/pW7jW/QSt0pZY/HnSb+ql" ..
	"/fFjO8i+K9fljSA8Orr1rdt6zuhkiFTSQ7iQk0Z0eGDLmvFruTMb0wYMHLE1EuEO5tswKrob2ZSg4EO02lNjCFPupOGtr/i/i2Xi" ..
	"2W6gkvEZy3acodFyf5hGVvn2TDigxsvHzR9xfxyxQh0wmio2kAaOx5h6eNSepgmiJUG3grmZhx6hk8jpqy3T7FNoHGQsxvCtW6Cl" ..
	"+o+WlXqpDw0aZIUpPeQbXP2eyu6ICXv4X2NWw41AL0HJIgq4/DrOclYw1V3Oi9/W8x4jAOXn569tSHw0bl6LTUt2t0kDBFwsvLHo" ..
	"DrwfWVAKZig6d5Vg8mQQwP571kuXZzETUcQf0YeQ8QbHCBfUsHfKJBZB5zIdNJIhq3YELxBZ4n6Nm96BJzhlBs+mFMn695JyAQdp" ..
	"SlK5kVnvlXTfbOgNngHrewx0o1e85cle6n/eoYqFcWTr8aY9JFQZgrbpcWyr0SSYaGHHb5yefHumgnvNlEwHOK+YlhtYitbnY+g6" ..
	"y1wn+LFF+EBZdjQqfiHTTvDQc3N+TNSABKxsYC6AJdNIdUZeckyC+38DYwB9cCGGJkZw6qJwyddAqpXQiom6vWOyVpw5B+oo2vis" ..
	"9lTQxd93lwsElp2O8szvJdS00yM3lV6FG/LOA5ey8k32GmbVrKEdA9bgbhv0VkEec563uTBd89L04lTOsao06Irl9m2rSJj/EOTX" ..
	"ALJ27m0L1TBhn0zR1r/VYKDlwnFyA8Sw/Qog9XkmVkHSdrcLh7rosd/97MMujlA85u8us6q8NA31QIcL4XGhg7MwdXeSBQH2Jttu" ..
	"ImMzplT2FnGU+OC98FZqD2vVJSRDE+u2XY/I4Zt6unJlYG1Bdf/AuchZvwDCSXW51kUf1wXGICseHuEc2BwyXgtnVZRGGqGw998y" ..
	"a4A8JOYavPzcAkkwdg3pMfXQTThZDX3dqN9ZuRqPkhbutQKzQyWErtbAfrTEFV4X8Jyi5SPIH0Nu0T70vWbG075HbABWt4cDrJHW" ..
	"45Q165WF1fxuROTxcVfp/LEYHhPiSlguFctf6jXtr7OtSIYjpKmPczsfjKaU+2l04gGsguLumeIb3xkRdn3Y4QWKNVKs0hOqgLp+" ..
	"gTwOKQFkBOHzh3pUs/jOo60kFqRWaJj96EkkTsnKmRNXAO251uM3Q1ZbL3dBxq6mwsIwdesymezme4Xbt+QQraedFCtTvcR0Bh65" ..
	"gorwtV+8WLxmU5EeRLLb0BC7ZJ/Iek5UPxK+RCthE8Jwjos7d2s+s2LZv3Ayl39hazsmtMVQz35UI9k69Wr4ZjRP4nDNGgaV8O5d" ..
	"AoLvctBvuQy3+vfumSpPM/whMfxlPcN3XZf1PDiQSk2t2VS2aA3lc6L/sMQmRuseseH9gIBZKQ9qYqmkkAVchtCkWfg2Uirdf6lW" ..
	"N598Ex523R9TbLlW6U+P1K/94OlZuHx8R8STacw5k+evuFVeJjb+RHJHTe35lXKik2dCuQ5u27vyCF4Xox7OoYieFy1kXGm7CRSh" ..
	"XDhUlraPi2wQ+/m8rd1W7M9neNaINxlOBbBHsflyBAmkvSYkwqpG1MwqWpZBeUgT2JlcF18MeFiOcPdy/Zd9Rw3YXFY5ZTGukTlR" ..
	""
local PAYLOAD_P6 =
	"+/ZD1448RroROBk4bpTgUksjLwrRyC9V/9I+LvSpkcQoVRArgS1gJTFIEAlnZ7K/dWEz6wjEjPUn2F3N1KFszmJiCtM5lvKtt6kY" ..
	"D06dIx+EyO/s0vOoRz71EUX1EESe6O+ZlCLcIpbv774uhzWp8zMpKT7EAwRpxDj1aHJGyJrPivfBFfjR/NmFEstx9fzTFpjaF88/" ..
	"GEQmnZuOhoNlSRizjdO6IxI/H48Ax+H9kH6jiKPiCDpWafxxjUGGJNFo0wLCQ8LM485YedBbh0lR0tXs+vroyq7gEggo0tFRgV8X" ..
	"t3Keg7+3TP8rYjNNXekH/X/tmer2smSvH4O4SoSszE7edTAaggJlSEi1gyoF6rZxuLeRSR/TZMt8ap0NPfRJlgkNDdht5OQXpbN0" ..
	"eLZ+lLBL4BGmLB/+8PP6TDoIpAXMCx1CVSOTNcYMB3TWgn3gdgzcvalz7sOXC+MAXxkPou+HDa6KTt4bXlj5Ws3uMm/DBefEoQCi" ..
	"ABnvu85nZKBAeA5+h/pLuAuE3kCAGYn7NZkEo4Ifk9ZIApjBZnObS3/OIhJqXkumARHspCeQx1X+EqoVYGeaCGl1/dcT+try2OBb" ..
	"r/jWUY+Y5JTgzFhN7DguCLAsUMvRJOES+EGmIzdKF4SAEQX4Xgu+3sWCKSFQWRi/TYbqcoKguTB+zhdUauAmzxxW5YIn0Z1R8GyD" ..
	"mACSophkbw67vPIkVkY7fyblaLXpLvgfuTefWvqf/sIB7I840dTRIU8XwUDdbaLg4emf9eMldHCSJZZMrzcYZ2cADOyZSkJEAcbE" ..
	"UIlKO1zWBSDeGUAdyFJQc8Kr5ikkacDJYVc/o99o8hZyauCuktywEDnYBL9M/Xhdo8AylMR3KvuQvn/7/fJbSJjw4SUM5n9+KACC" ..
	"63K03YyT5J0Qaw==" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6

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
