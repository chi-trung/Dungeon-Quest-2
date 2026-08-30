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

-- teleport-persist: MENU tu arm queue_on_teleport (armSelfTeleport trong
-- dq_menu.luau). Loader KHONG arm nua de tranh double queue khi re-paste;
-- loader chi can luu source da giai ma ra file dqfarm_source.luau (xem tryRun)
-- de BOOT doc lai sau khi doi place (Lobby <-> Level) va chay lai menu.
local KEYS = {
	{ seed = 2158583101, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2161196331, exp = 0, plan = 0, hwid = {} },
	{ seed = 2161662286, exp = 1788089514, plan = 1, hwid = {} }
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
	"iGWfgn22JaAoH4Iy+aaZB8H2qmhGaidV/IwW3dmTohPo1j6tsh8APlYq9JRz4ulmVWG6/tcsX1cN51zNJejFnL4vdRkWAeCEVDzb" ..
	"nUDLMog9T5G5M1kKsneWHp+XhCXyZTAQmVNmNIXZY6lYj2lBSzL6ZI1ZncTpxIm343gzGGM/Or39e4yLyZA6TfzUoMxwVcxZ690H" ..
	"vJfkVXlOgrMymu4hObcfSJYozoh6P7hN5v5KWP1QmviLwES2w/s+DsvL1wGRBWUsJ/mB6kQgqA+zbgYUrXhZVOzg+c0KUR9JJHjx" ..
	"PSpb5YrjhAbZtl+XEkjAQmFoSxuSncRRDc9Ip7kYlpLUpNrhpGRGjoiT24MaRxUfFf3/ACqqKxS/eIODL2qFvj8Wa01UdBb0021v" ..
	"GI/DSgcoK8MA43dGNmq6Rx40iEF1DuarLgt6X+SE53JswNCoyYwDMPLG/4vFqSUmfHVO1HdiJlL5MSJpAT/M6uWMCNZJgR8VjYAS" ..
	"TPrEwxMJkQEZJhWMUe7chKRbNQJnKgmMH1d9sh+ec/Ld/nR0JaN+/Ac4WF6O0H4bThOZu9g2nbVqe/JRIKWMAjIsOt3RAgQBLLbH" ..
	"TsE+CGlAbpD4aXUTiWNvb3bVGG4oRV/rw7QgFEF1GntD1GXoWb4zptv9lxpw+JvNLVCf2u+OvIBO+aL96zXK1YSjJMvRAmnjqwnp" ..
	"8DQ/YutV1xkDEr4Ykq2pgEDhDbXgb/W5bbacec36+/oK9Ytfwj1ieuQxnAZmNB9jdpX3Eg4K2TgineR/Qg9csaiYECkafRJLAFtt" ..
	"q+UoZ0Kmw2fyjMjIqy/aox3FU+aMLbbuQanOibALMDVKdh48SrpfKbD3X3LSVGtxfebfAXFi4zgPGm51VE1nSwV5wJuLICIGxQ3f" ..
	"JGGFd05el+M/71d4l+45uNsb82+Dp7Qx4e2FFfgS0lWIrSlcxGHaniv2I1jLLMo2EQW0yAHNvH7dnnAGQ2M8gEzQMz9nzjAqeaJ5" ..
	"lZ0GJbrMY6GBaVAqbEUIpt0WoLWTFWyxwphP6mgGNG81Gdj0ra5Jha9U/5sRRJ/8XjV0lGLV+94P7nevi7i98SI9aRTzL6SVtex7" ..
	"Beattbxl28Vx26x76HINbvK3qHsewznP2WtEw2t/lRvs+XsiYdqAsqQwak69vnWjNDluk3Vayk8+Ybpys3e11x+/AsbXPFuWWOwR" ..
	"uwfmJdoULSjBbF0Ju8xej9svdgFnhLmdN+3jbfPKqSd6QkPVjzXTLGsM4um41vYBN+VRapJcKKWucnuHZ8XhDqaaH0iSWVWNIOXm" ..
	"oeLIxmB4cE0hTFTBkngZpjp3GKROxHsUg7KRlULRpGKJUtvMpSKS14hzNI5ZARbhqgsaL19GZewTOKI/GBhMfOn8lORoXveomL8W" ..
	"NCebuJ6CqXNMJ6cwnL9kpd9Km5Pd7U4C5SFv0icvxcDAEq6YJNIgICiKtkHnjubKU7cZx6wFB5wzDN7LypJr/IgV9DIZJx4SjqMm" ..
	"xSS0TCMdThIOSu7nK+TxJ6Z8LrGZ/RfYMcoPVWooBsu58YysLQlYBYXd4Kd+Owe4NYjg0OjfiWRcSlURybFiICQRb93ZHbLiuJsE" ..
	"suDI/BheTfIl8agogaLMxlrrW/HfWdNy3nHB4EaoQ5+rthrmsttPGHw+cnSFyqaYwfAeRbdBtADn/Luq4w01lPKbc82ofb0FZbf5" ..
	"7w+WnquNGAGv8bZX/tSFjG9KELJZxd4nEgHLBff/9TBLgW1OtIAFVM0qXEDE/Vt0TNYYpSkAH2ycdtS+5wxLYb8aKzn4xzZe2EC4" ..
	"CyVaWC/LZNRx2YpbrMXp06EF7xVHFr2D90rVueTYDRAaJGewJAMqbKLcQ+IpwIBatmmS4osV+fiPbrCd/OCu/hfPn73d9lU98qoV" ..
	"N6UeqKjP592UqE0BftYTGtpLedt4B1JEHlYsESWZUye420JBVNXKwUqN8Y0kMXQPE/ejHRBIj8oC6BBEIqI+9QH/cZi5Hw0M/vFX" ..
	"fpsVJlxn8zf6DcFJ9DE+zevKer0VuVipUbPsrSAbMQVguaL7XrdEJDr1mHWQEPAiWUTga0bhAuJyOJ/abzn6/ULkekTKkbaI2LPf" ..
	"7dlUzH1GKe0VCgLjnxRz8XIaEvqGLZSN0P1Xx4KuSND2zUt2DHYYLXWHg8NRdD1+ckZuikLKLASl0EB5zODBXwOnvJUrUSfXhXmY" ..
	"I/pKylzgZJBxrjs8xGCVM6v6cR4snWyh3QM6jrZ6SMsyAUfTmlWVPsrIhZBykexVd0nGRVQ73y4UFkB1g4DS/y+lhTCJl/uV7PT/" ..
	"uZubQOiQlHMw1sYVSuUIMCfO2kTrKZSkFccpVS8ij2lzu/9+j/QWuThM10mLkTQZ/tDgKG8Kp1ZQRRVEeyo8ujccLBe5TLlPIKSg" ..
	"JrWMr5wLEbIjblDASODwoLET27IWqVfQ3Leq0nYyAWjW8njHX4TwS48A9mlu4sNThX9ofo0VgHyk71s0uXcwGB/dVz22OXFJnTPn" ..
	"rutXRPed9qP4HNcydp/mcRNWFr+3h70YlZcBgwbRDIE/94kcwF9n7RSC0lLJrzTsX5bWDhmeBpL7wi/N2kmgvPtYXbuzLs490NtK" ..
	"+vHdHv5RhuUbeTddBK9SG7SwHZlNm8QUv4e/OPTxQIVNphpW9D6CNjHj9XZlSCzk+spW6if+dmSL7RDLfvaTUjDlcAzokS71iA+f" ..
	"28x9bVMqIHFM91p+G0hR8MrG3AR9voYHhXy3cm38gJXzYwEq4R2pngJyFQ/VPPPqvhNnzZbFDGLt+HnHN07C2lOgI7YOx3tNWA+1" ..
	"LgF/dVGNOVZE1jIFirGv506s0n4rd+RummEPiTQlp3ZLRgXbX2SAx/digE1iZAh7hpoLkzLMaZiBq1TKoxfiZGDFIq06FmSBef4+" ..
	"HgeAYoeP2LX5x2/sKCKPTz/ewWdkPB/sF+M5+Uzl3fSQQcMuXu5fp4dEu99CsRp+2Bzq/OP6Rf/6MmxADxN8UrbiEMKCfgn5e69A" ..
	"5nlcmVEhO+hYNM09Q4KG9TwHcqwcgC8Sq9bUb8Dyu/6NumDmXorE6vA8VJyqs4NjKymfIoUec+tlC3ph/OvPmo4ZQNTgt2nriboC" ..
	"sXXCWIasRC6Jgm5Q9OaNrsI9yNPD07k5uBhJ1bAIKAxMntuRhCR+2qhfuBT7vSWDBq+Bs+DBL/R0GeX1PfJMYhRPmIr6c+ixIH4F" ..
	"AGoDkjnEtQ/g/SpTgj2UzgV3Mq7l/nwWdE5Wt3Lf/fT8ZWeOZF8KY13WmO+/ykY6gZLe9mR6Qm92iQ4zkraFad1YXefv+BEYKKrJ" ..
	"nbD4SqYVpsaTOYMCxT6eq3Sz+jnZh+T53AIVH64142AmX4Uy9aapwgJUBEEtdvQ5zyg4Aabnn+Zx5umX/rADAiCiLWHPsJ97UJC7" ..
	"0tZXUGF1r/VFbmn7dWY4Z2TgdxGnIDCrl2PFNCDd6rR8/nc1Kfm56VfWAtzrkMlsZ02ee/ZJsZiKX3erU1DbW9TSQq7UjzbdS0GW" ..
	"bwYlOTtS3c5nI1vibak4BAeO3+DB0vZTiLe1pF8/6W5OcTtwityYbf/CjH/828NEhq4/cmBicBPNa1RjSahVPmh8sAUV/vKuBOFS" ..
	"Z296goPvchtVNPLBT2rc5D/w5Orrpacm4vWG3/kBRB6Gy3a1SYSf0oNtPLg1EiIp+0bcPsxoGo6uZZf/N8mn+G+W3oykGGu4mcsH" ..
	"SabolITgCtLpeau5m5XlKbf7wrOZWBiDDL1kq/I0oPr/9Fg6z/LNEPnRUkmfQcwz3uyJd9F4NKCy5PHSqnp1KoMW37b30WBgI8OI" ..
	"fI8o1dwyUumiTYjgNGXg5ud68pt18RYZcO0Rd6s743WMK6T4V2HWziBiCPgP4tpM6D+wXz/S0oUCm2qPOgHxYMvaXBoRCk9+pB4S" ..
	"Y7BFcvhWjN1PAGI9PBNO7j4ML8bPQ9YW5pvG2dSEAGVUBvmhlUr90Hs6BYmJuosIjdQa55fYiw0KmQJuoEquUEMHAS9DacjX3Fvy" ..
	"VNj6hmxRNgxbAi/tMgLSTCIZ6mXOJ+JwCDPuhVKg0EikNCx3EJyy5caTpi5tBRqW12oJBHrgG7OWu86GIh0+qJLZPE37vVjF+V1h" ..
	"cBE+dkRVTb83WPj0dIEV15rUp/oShdyMI5t/KcAtz5G0VvXtYrt6183BuNq/QWJ6OuLIm2OhkztsGhORG4ZpFW8zztu+GaNh6mlg" ..
	"4vpIpq4u9s/05SlJsM/kIvD3jWZO3wW3pVDeFwRtxXS5hJFmeBlfEZoS5R+T4P1OUI9M8u4GIIQ8ImbE+4m2P9J4AFYpNjXh9PFp" ..
	"GZcSAMKM4P0dztwKdT765pksCqGkrnqMTrOb7TuxBvTjNfMDD5IdYSxzhjtUlKnU/k/ZKtiKqdBDIbkQvs109UqNB548YP4WY0qV" ..
	"hD/ALsqeuWOP+j3csZli+O+imYFj9d6ONxy054PjBz9TELiAnVz1sgI76dt6H4sb5LcQKGPoDq8kiA2c3Y1kwg9/D1iFQrkupU2C" ..
	"MV7v+qoKlZfD4D3mxP8UF35NB0k6l3gWDyR6x5irfuPeREd35r0Fh3MFPJRp1BB89kXaavttS0v7RMtFhzfiacwcu7ZW+tVzQ6EQ" ..
	"GQHO66z0DEkHngfPe9nQobGRmC3oQhxZxAmt/2+z8Oghe9sHaT/A7uAoXrpC9cWCLffaScizcA5syQJsK/Vt9c/TPwNFON12n6GC" ..
	"sRcLaNvvMjIFoaKrnNm3471E+AYiefPlYnSNx4G5gQugoD2/G3+2L4OoUUAYoPEwlZZQKxhleRadtOZEmC5UmtdZ0XmaYR1WbW3a" ..
	"ep3h3j/bBs84Gj0azxCKz3xlXbH98o36hSA1Sk4iDf6qqRuj3eAoN5bUkYffvryVCTdJsP4iSgzd49wmQqf7lFf9OI4dcnxToSzh" ..
	"pWGwRSSQ1+N+62xbYk09pHP5Uubi2bqPPbKWLzVbUrFXP/dR1r2U/axlsr+XVQkXLxBdbOpSHpz4HyaAFoWJD0j0z2gfmA29R+jJ" ..
	"WMk9pL9a36RAUM4SPIPGd80/Tw4LBgPGXbEpEfhG4yhgG2Yyy8WIoh3U1uCKoZtixycqLixz39FJwIH9oLULYqAeDiYcuxQESGR5" ..
	"SK2dq1seJ6Oip8DHnUFHuUgwYmJnI8GrS32CmE4wtLsO3eWhrFPDVfpqZghnWtgOkbvdop1FWpeSH0CNAhFXLQKp/3Sv+qm0pkJ6" ..
	"dtJU3T2rRW0IaOdC8N7IzFJoKhx32wDdK6N0+nHY4seGVDk9imwRF5eSCsLH8sV2HCXOmLNcs+7qx4sutdR0vDY0SNIY8Uc4GuYW" ..
	"sajW09iNwQpXYHcFPtRnNDEBf7QBUQuBgyUK/NESbaSFQaCioD5fVIV8t9TgpE/WRXe2jonAQzTqsYB4X9sSID9yDgYAR/jwbPDp" ..
	"7tx3azGBB0BGTvBVc6vWBWy75uTa0gqeCnmCijrl5liCeLfITx3ldCddm0yNOekI2pX++SkSxipkI9bqgC5whwXDkdwsf0rnfwgS" ..
	"a3X/Lo11i+eUIrthepMIXivHVhql9QFPue8S8qE4NmcYKcgCAOYk/6nr2Hc1JsuE9+JIFh4mcTwaI0kCNB8T7hwmUjmEV7txuFO6" ..
	"Ge7ZHBvqBXD4dmoyW0Szl6XSlZz8Z7u86KC4/TQlsbEFgGlpZL7jVD27n3NudNEEwRtmrsaJ1tcTBe42cLibA1KQe53Or5dGpsin" ..
	"MMoZTWS2edxeIzkzSne+2geWEfBlllVHaVawAUF534arnpJJPDXfnfnHp9Uvdf1oDldUYC/feni8025dE7413OY3RO1BXmA0Yrn+" ..
	"mA5Y6/nmiqvGh1IIxyDwP9pQYLKjJGFSYswr1uDVf/0yFx1xr8Hx3j93uNAHI9BqrjeaxP/clt0uL2ncESDguANb2LWG69/1EX1Q" ..
	"D4MredxVosJoGYfqDEsGwFU/df4rzew8A1TSgl/6BcFD6gIB0imJwWYLmRoi5JavVCWVrz0YrYuinyiPSqheqe/otDi7VD8+HSeB" ..
	""
local PAYLOAD_P2 =
	"YHFOt6kh1i+8VLJZXK379A+fLyJmIMB74B2q0oueMOFb1/I/3l/nIwUxa77WgD4l8gqf60zq5CItj0oX1yNF3hxpciilPwYXg3TC" ..
	"JFThIyH7exS6o2pcVS/1fVFwo1AkVwcE7++DX9b6muvn8xrT9IzlaUOmOpfqgpvj3q4+dGT1R9sqOcdrOoPnT7cdoxVuqjMonVGP" ..
	"ExRLoyJmZB+A6lmCKDsKZSNhIy+MamTDFZnyxfC6HZk4kBl3bJ2AMv9gqsrSKWo2O4sIJCBvbXu9KGZojbRqNnhAr9xR9tpCZKla" ..
	"B0FpGkOKtCBKXpfCZ++TEEe61Tmufc3vAC0DLAG3P2+affWS3G+ELsuzZeCPHvWPYoqFTNOgwXxcvQ/upvvn4avQ5m6Tzpz3IbEn" ..
	"md55MFZqlTVN94Jg+pxuKLG8iY4QTHdh8inogeKq5okR4Oed+/n1TLZ9omN3aimkbC00dMC+K7/OSSK1n2zXWyC915L1PIIkFlXH" ..
	"kWvwanuf9RTSOOM1Budz4AHOlytMJ6Y6dHVcSh5XL0GyIh7pXVN6SvgOzTw5w3KyKYfKt3/GlZVmr9bPGl3S+x9FXRBuzX0IyQd9" ..
	"2ydoe/iC1oZv+RvydkYWCfSazcGRSMItbHhe0Eo2aFqMEWejStzgKNqQ8SyfVp1iBPtkZmtkyocffg6PI8ljaJhke1STcVgHlVb1" ..
	"h0SDdvgFWOpuclzkEpp45alNc0XOjVTx6iUodMEg+VEAwjhBlC/ML1KCbCSNQF1iNqgiVfXY0VNTsVIeQfcYa8RlGSwgipTkaFA/" ..
	"6T9ysO3cBUMuirxw5406JaCSOKYiAfewaJxZnA1zF/NWKpQ07tsF5/j+C5GjZfkq8xEMw6r0QTsuWNYZ81Pm0bWN+QXyPlutD1eG" ..
	"i72T/DE072cBHcJuEYAjQTyBYk1JHDhQAr6tpM69CPzwQXwfhTM2+UxRd82ftwWSkqYeYrjQgjJFI11aJz/ylu8IHYUU+XCrf0iq" ..
	"O/3BAvsbiTF2M+qwXe/C0hSOJnITXr24K3HjYy7EUQByKIjdkZI7/B5abmkb0bTL3YYsGT6Nad09KZKz8C0+wX5nymhLde+OXcpt" ..
	"A3mz082zOJdix8sKuliKritX3uJjoBaA9/2gvQOSlW0KVg/sArEOUx/V/0jOiB02UxXgw8pF/xgiCdzlsR6djwaHxy+J+narFgxJ" ..
	"n9Pw/1PCpGfTyyyJ3XCUvoNguj8KcXoOplPCUK9Pe5kJEnCrW5XqOj01GU4DJEmvPbqdsGgL1kw7ns74eo9KpuYOrHszobpdHdb9" ..
	"ek5SXlikfn/GIhadOtl9/wVSf8UQf9eK1eW0g+O8IwkdaI231gI4K6tgUsm1m4fAyQS8TJsoe/ldsf7zqiqzS9UW4alWEU2yVSZC" ..
	"n5SEruBB0grHCQM1Ax1951jnIETJvP6jZSE0HKbm+cPPLAzOGav0YGUjP7f/lfcvObT6gUQcRq78ZeT9MKFqr+n6k9GyLxP+PgP1" ..
	"dMdOt8GQUKdVm8CwnW8eW15cIEYSvhG8ykV4LFg3ptKtmUbZFFh144VYZFkmb8I5Qgy54bbY2bk1BjwUrtgffRzTb3GSwbcqLGXB" ..
	"6TQrXSY/NcpdKW07elVb0ZgpZwFFPueftpGW2yky5zlWf6zZFtcq8O1pnYffEIz759GP9xZaIQwsVsERQDgEr/YoIhWH9OTfBYsv" ..
	"0oqmyJkCgAy9zVUQFXw/enImCOHcODQDOeSzMkUx9PugnQzKvlhaB/qmPjLQ5+S+AY5Juq+5BxXdNeTwOrqzrTmplq6R4oM1z4IF" ..
	"7496koyoXTm75h2KRY3OKQIwRc2aOJG5qXBLPga+TYubTcxyO8yYrKaxuBAvHxWmgzwVm3uImuojxVharvX+WLvVzSezItGHRgW7" ..
	"bxw9U1G7Z5hEfdJq0sMVwVo4RJsMICMZOj+Lo803ixImIIjelstostv53cBeJYTE1oLYmpoyOJfE8iF+bBw7bKhlhp9yUs2kKZ2G" ..
	"Sp5dH81kN7KSmQccYVXACEpj0GDMreG6dioTJpuPHUFaxE8EAjv9CTXGku/VVMeGOIHYMmTR+BsOTUqhuIBtOdoMamHXoRahN6pJ" ..
	"+2sCGDxyi6lpiGFVmIaCrvjwA84lNN5aHKiy71M/VCgnpv0Ss5ucRv+KKX/hGZ7ZwMiUT5Wa1manbVEJGeVxhoT1DUU0Dk8FdrBC" ..
	"AIwHodK9SJvoYnGkPFrQc/WfKxnoAtwRGPaUXIOwsJsQiwtqserdAVYoU5+I+RQee0YBVafDLKR9pwMsMQxLDYDPN1OdtHfEd4WY" ..
	"T06vOT1gHqSMJ+ar2NcRl6y53YF7/apQZMIilkMJ97vIRCmS+kTVyN9P2yyX/rRTtFfXSRC+S9cLRUWJeVi0LfzKG8JvK7yxPlUW" ..
	"Ft6JuIdpV6+A7n2XOnlaRmXYHaeRmdGAtH5wNgTsV0m+V7ImLEIyJtI4np6TDZmJEC9QlTD9RLpNa18Wj7+4gJBTJfNOJRpO6fV6" ..
	"IgCloAjKNn+pVI4AqMtEb34LUDYpjrPPu6ZYixqosLm/ubNc4JwyI2Ha7OEdE0NaSjVnjQ4K74kW7aH0AD7o+6w+me9dkG9yr6cr" ..
	"SOTCzhePk3icCeCaJ3L2LS5ioQsraUOEGvjIuoITKTL1zF6kFUrxAJ+qAp7AH0CSuuAf/6mgKJ3KJRJRsKLmhlgKa2o/p7Yc0+qm" ..
	"wMAf0LEovuifQhSW5pRqYY2xbS3IiqAVnUCDAXv32SKuYrKR/osW9tMOZLlHmIU42fJnklsCH6W9cYV8uTPx8RnbphyKsqQSSrJe" ..
	"PAi+MpqTEqvh81XrXm74Ih4ZA93TNa3bUlj2VEQXHcsICIQUXzyupJzTYCVGU+/C1O9jh/5q+CTt5Z9n/JmswvJa2NJuyxnAd6xx" ..
	"0dO6Zc9Z26VSU2TUB6LpNkO707DV+RlhhMm4AGvPhVxhOyGtgvpzZZab8qbrmGkU7bH094LRLNLCCPBlKfsGJDoxbeog8zyptwvg" ..
	"6rdeTAKYwbomvsTM18/Qu8eJ6LMbeqVN+J8UOdmlGzoUPoVjwbK6hHtp/OG050b3Q6FuLe9Q3CeimCfoNgx7ImDCgsYkD9hxQvsB" ..
	"Z5ilArDHPZ9fqBwF3XZ37p4xe8JXw5tXYtCV/3PgrMJJ3I9BtfEVqKgKys8v2meDqcHMRFb/SfdZcO7jNnkztg/i9QtXXOY40Owe" ..
	"BjHAcFABAnwz5/O0c3ccQVdKjvR8BjHyU5VxpYTfgCXj+gCpxVDTkJTUpGlDMRBCp5gEIwflBY45HytAOYDu9bG4kZREsorBIheY" ..
	"mU6UuqjnEGX4aVbAus3bMBFDhkR4zft7bPw03VPVGmtd0oXRBJA2rAzH7MpNprz1ddtHyS4qDa918kfDKwufmb+7+ETITRl3z6oC" ..
	"WP80FwIgYVR+pOsH90XtdPr58fuGBs/TvXX5O2d+HDVhyDdFQbXSZamXAL194ydpKoi/g3aH0Vp7zPL/YzFGIEqia7dWKKxgK3K3" ..
	"NezAL8kRe9ovsIJ8v9ZL2yK0mzGD3kmN52BHBMRskNddvpoy/KMJjbvLmv9EYzHjLyZO8Tb34jGhEmTvXiOlWiy1ExRSvgqxwuv7" ..
	"SVbymK8LtYXbOvRTXKLDtpAoEdSaluh/wPtZT9Boyeh4RoejKwY2A5xFZLbQnFlmjp5nzn9/jZKy++DUReVkHTbKFEYoiwOCFOkR" ..
	"1KrtpJrfFs7k/sCULK123HoNttjH+Op4vAdHT5p0vxuvmPLGTW0OaLRbrqn2CRNp6OmHwg3tg+8v5sY9JgNwkIC6q72+Wtebc//Z" ..
	"CcNCAWoMlYbuPcQ5G3lT4oz4unQduAdPPqwY/Y76PPnZ/gSlQ9//IheouxfOziVNYowr4eJCalzF3cYAo38bcgOX1mdgOgs8x7tx" ..
	"zPDwaIa8u3Chlbk0Hed+K6jtsSzQ3eGhfC9qzkwmIMeylp8knTdGWlYF/x0rXJ9v0dmWrGm8CeZ7XdTn7+q2O7JtoQI8aOBd4B01" ..
	"ff6MEMOZgAfbmEOaBHtyd68oJ/1zcd+TV/T8o1zFWdrVcqG8YneCjGeFlvVfSH7O4d5E+uEw0acImET3qLhsaqykESrt4mepXfAJ" ..
	"f/RTVMiNeY+HwDI+YgS2Ath18Z+TQdn3UBJumnyRP8iN0yDMhVzxcj7hpDsDUjzLGxq/K+cEvBFtNhgKVPmB2mcPDfUGNYCyRexs" ..
	"fUzVSnx9hno/N59Mrr3dpxEZC23dGh/2bOlVJyFlfNY9q6yaU3JBaa9x8Ku5Qsx6sW0NQnygCpZLD/HO1cdJTH4nR3L0bKW0oNzn" ..
	"HNN9FsEWVXmBWDtbzLRSn1CPC8NHNW/PIacOIm4egIiejmu5gcwjPSmeSuHvA6Yqp5L2wZYk0z7kxAMy56zLSblsTilRdSKGfyrq" ..
	"d5Drg0EnYy4aoKJYQU57f1hV8VfPXSQbnbYomb4Lw5zjI0PTJZZzUYclnmnDmMEwz31OOBv4oPmGilcWv8qoF9pvlxfYZvZVwT1a" ..
	"UGr2X92lAoAe9RIxIk7jnlIk/TTfTdFhaeXKcLriAa9LLQ3rhRGDim+rBoqnJIXKmfMEFm8ZUZzUuV1ocGr8NEpLCdw5toyNWMs4" ..
	"Oy458NtkBl+kAjHi+5+z3r+up2HIXznYIjCfDK13vdNI1trwKkPcFdnGCmYVKgBUQQ6MyqdoWxPnFAAYwSm8t9dQKC/zzXfa4wIu" ..
	"hoqon+0Ov91xTSwXRc66ETYkJxDn5fxuXY0HlcMgQR0dgYxBTFLehqir4a1ggH1tGLIjLXSRn/wNhZvjgTd5/V57bNhCEg6fZ8Ck" ..
	"X/aCpahPmwK0nrwAWPSjzmCOP26Y37dx7c2wzCDMFHUhmMT2TguiGN0yBTU6J43nwpWhvdP2E9OMNefC3mfVqi2NfdGgfURzmSKQ" ..
	"PcFh/t4lCgDVIZ+UB635doJnRtBldQMhxsandKTwKlIJcFoOUUX+RHAdkJFllsp/aHFYR88UpjzChmjVtgvvq/TdnKehL/sK6R+y" ..
	"m9/5aqUiBczQ89MfsONilJHp3QlPgiSPJafm98gX4gPPwdO6UflZuj/H8TVhyTOZg2Je5wPvttKMGKiSstR6ardIPxZxYcRuOybU" ..
	"LEoumit0MShoEluIdkjb5mx1Kt9M0yX9Eg330sQ6YJN22yGj6ri4PPf4L3fD0hus+Zcfjir+Axz8VrtfAVDNpiv490DTUUG4ptrE" ..
	"fgVe3eJL3xqUDd4O2gxtfNAbrJR89sJ1i1c1+Dj1nezqzbiu4fhbGdK40ylxwOa2ur9ve8jTBAs1O62zYhN6ceFJZONFN++I60DW" ..
	"aCL9Gzwjg9+vSOmmW1hf5pzGA9KYAgbckEueWb0VlnTyBhwEGwkT9p5qbq/ZZlIBZk2KKRvsSeWgAoyQSb96JJ+iMY08Ni/KqUeQ" ..
	"aV/bywpCRJ7k1n/WqfahP4LMVRQsoqIA6pOP4azBrhSWqf/OQs7OO+3NNZuErtdE0VxjFtZ0JZ6aV2RwLAE1sbT1Z7gFr2WLd4Or" ..
	"4LLXcKSR/5dqxD+vvAk0n7v8HIE1Ob3mqp49OGt7XjPERV2JH7bPn7i69SlC9yt92PT70uH45P8PPtgmwLFYUKR6xKFL/FwnziG1" ..
	"EehRgTVC9ptSBUKe/JiFoV3MOIXHMe+atXy0sW7qerVQ+s9wAJtHrwYG8PZfMUHPF3ylnsG9bYkfK3Ef/hBxyoDkfQj/Wq/LnRHP" ..
	"+l93zHO2HJEzR8tfcgd45TgGQox9618kpBUNSWR8RP1WlalrxdYqJVgfwvhTS+Jr07MhsgrB/IuTW+fdExqKg2CN4hQq9w+BXi8g" ..
	"5Ww8crJUb8JqSlkLGyKcu1u8PWGzDq9cny8K4gr5F1ENfMEM3vffna4//K0UkEX/AD0vWzKEaK0f/PUhkLOJ6+UK3htX90sTBU5k" ..
	"dj0RWzTzRD1kbxuoKtYKrEIpCj61nze1vj7e+qSaxkAS3qyyf3KNcyEEK6p0hmQMHBO6yZpaOgd3wuIs+/6mkzBn+JIMR4M616jj" ..
	""
local PAYLOAD_P3 =
	"CKNi6GuT4AXOHog/ansoPiokQ6+vPIhI8H1N/7nJeEKgV3Ke7v8PKlbyFnToDzpL3k9mVBoqwvthX0ZNAlVIsAuBKT3Iz/CgT97I" ..
	"jEOkKQzJKisyWSYc3ltqm3Ed3dRiVj94QrRr+gGJjjQB07tRXKmbHpQi4v6vP84w+dHLv6R6UC6V+CSXLoynQocKoJqKF/Eim3Ec" ..
	"j2JZx6j7JXPu4Z7b59kt/SJJfK+m2WrxGTUGsA02eL9q6MPp+DtHP8HbAi8e5jJ9IvQhEj0lx4s3OYtZbRsE0DSg/0BsdGV0wHxP" ..
	"fjH5Rj+5S33wJ80iTtI8vXoFFVtrHvJr3yEgMxedAq6Gp8eKaug8shI6jCFvihKLOegcPOtfPQ/7tTc8AxwJ7QHo1B0KThpLBnk0" ..
	"dF9Bf2Fp5lDmEAmQAHCmKdtG+wiOQeUxE8GhXLf8PdQBVfCjqQAQr6liy8glVrwHr8lJSfywUR76fYRE3EV7W0m7oJM78XJ4rcN3" ..
	"3ePZMbihx0Gp6FrjsnL2CncTTAPI1QuhgLHDvV31tAhIiHwp3yCK47ivt3SQw41pGFM+HJqK0rTYuW9P6kTGCdlWqf0fDZKKBr+l" ..
	"3lN0yQKJkceyDaowDp8/wgXGtVzCRj5TGfz3WheUZaTMDps4G+g2j/BRaHP3bo5pf6GXUrX4e08J6t70jRBWatX+9PBO0X9FTTIP" ..
	"0rPuYT6UQFW0201bi28nHnP45XjYHvZ2j0IYk0EbCoP9zNav2UW1f+1cKkWxtQdGB71RMvRrHLUXnjGO/XNQ8ih8YK6jKLUWgluP" ..
	"NgdPq2FDki/tBdC4dyp1uBBcu6cJeZtSa+nEnRNQh4G0vWtPxBVP1OnRC81cLB9GA3X1WA8vybX/2PrNW7zJvYfvMsmToCMl3kx1" ..
	"1W8pJsZuhie+7b11D3opeH4nmc0cOchcd9cCiv3NoqbBJ/nMOarDclNyc35mDDuK4HtePIkDdzsm8d7LzMupcAnO8RHEKWjss2RW" ..
	"KqLmjUhY1VjiCNAAsd6x4UL+d+ahNx9u1pN6PKv41VgF0dnYl4YaHk3g9TIIP4wvj96C6nnhp3y5drtYzQ1rbx2GMJPHd7V+pJ+A" ..
	"p0B0LdjC8iEWwrLqhHe2NFdoEFUZbqJ+6Xm7AmCgoPR3YiB3M2Rvoj3vuqbWpdWl/GYg2n4LRI8as4OMXXiE0B7mZoeKI3A16H71" ..
	"tFdawqaFt0rJlmibIzhWQtFLfkmT77CQZmOe8+fxG7uDZq9tMjx9YeY9ksgWRvgRbZEDjah3cQ0WBJjyJjM1KMyOdUM0muYW/Srp" ..
	"iTw4LkYdvIqF3UwgYWzzAKBNAMoIJPTlkHLGX1Nfr42ee9F2NwRWnYHntCtNDf5Ti8azW4/rFcfNdKZ0n1y8yIdm4am+joYEGuEZ" ..
	"jxr9b4nGY/meszp6MDdnpKqnB9692uD7ID+u05u5gk2Ds+8qgdjpNF5rGfK+ALYaOl+SeqjC5/rU98bvLvvc8agqGN+iFwDo0dp4" ..
	"MOiZmqp4JtFI9WoHR12E39vuZsUaNiUGjz5oUlkh0iGm+jNb3+1iiS1+XtyZHbVD9UFoqWbBTyoFDy/iEn4LTDzgB1WTAo9gE73t" ..
	"iF+XWZP9XD4rUl5dXEWiOn+wF1p8x1tqjUkxvytcqVAMpaG95IzoiOWds0sgZ0SkGRp93cQqU8jjXXFERP6MY+9t5N7e+6l83Bie" ..
	"LcUXKSGuvjgCrDtoftFdD0SdXqrZdNfb4ouRGeCegAqlCaIPXjhtVvDdaydN/Fr2J9pS1UzMCLcGUCHjxKagQVvlAHENbjwhZeqR" ..
	"DPVNdLZBKw+3M4iFn4he72WQn1CZSGdzJWS7NP3JlzFnrUo5acxIqdQnTbhaCHtloKJ30RqBuUVlvt8BrjahvuNFjqNodYjUHtI9" ..
	"CPyJ29HU9zA1DH+ECXPCET6NqKKsFVBsppvlBkh92TJeXpz+6hmZ3QVIWAm+gg3evAJLXC+2HWtpzP3wPqKKef0riNoDIdvOYojH" ..
	"2cmMDNiSkaFxoidmtSygcJyGoE+Kk28T9/g95lsmzf18XOX0zLrBKle7ZuoAR8omAqLG20jU4T/nq1U0mXniHPU7BMCD6CaRyrno" ..
	"IRbCYBBwh7uEoXZIukPTrD7Zls+0bLntcdI0SKaQosZ6dou24XtyJ0maHvO9b3oXyx3V58ViOv8yhH0Hfz0i3xRwckSdq09SAZc+" ..
	"KIM23+DzbYJZmiImbgZBS340m4Jd3Ed4eCvyrI4LwrZYpAtkEK/T6ct49gGQML/PJSZQnP+TCIVsQPwM7gsbpEzKOsuTjE57v5Vp" ..
	"a6jqKM/ZKClmCLGpjT8eFDCgMprmGNZI/kk6zdkXuSq4uhWo9DhZVGIXRRSniKsbgBMaIlEc8RC+7v6ZVRGUtljRDSPx5qL+2yJl" ..
	"VVEckkd4pfHf2m9d5pnzkV31ACdOBfSz2QobJOmRjU2DuhXHHC/n66ORRIb+dMqcFLE/mg5dCTg/90DE3is0GvZ+Lil2LvM+GyF1" ..
	"wsUXlUfL1fwz6j4MXrQHNhX/yRuze7NnjHADabFwYe0/8MHDLxGJn68Et3y3IDVEt1SKvwGwJnhfQM8j1o8CLPDhkxIAoCWvqqwH" ..
	"mhlRpMRmuzAf5iAmcRf9oTXcp4uoSgy37YsMaVDyNqfzb2X4NAtkY/Eu2FJutYTDvo4S4iCg6eLOTR7YFlj33kQMu1mSnoJYfN2q" ..
	"nSLoLByHxf/+ZvelsV6NNew52a7ZXzE3kgzp3AR91JUQC7dvf07z+oUlV+6jW8HAYStSQ2rPN9vSGnpFNtwIqm2H0hbXNnSVdC/0" ..
	"xMLIPqpHdX+EJEz2taPMOj2xXM7aYwzZk7INVmUnv3IQ1ev7xsOG4gRLeIDfDxjadhyeFX6xiPjiQMfHorOaFWUBVHLxLFi9PPyB" ..
	"6ogVhT7m3biLCObZVLve8acJ7lC4V8x8lnXTbifpF0AkPaeCrcH9bYa7dHufp/MXPShY+ZWFkxfPpejzZ8YTS2UTa/SqRmvoj7yE" ..
	"cPkAJMh+0fPvxQN+n9/kcD62N6/xQybrIenc0ZpiG8xiEPa4EPVEVq7Xw6bL6PHlKJQX26w8cYhN2b+BjL2qlms/6yIM2Z7t3DNJ" ..
	"icVV9264T/XxdYR/FIlzoXpja9+OFoV90rHweUdg3VSlxiRJfbtf0ZRc/atoRISMrNCKEccBa5onck21wzMzwmvjCA6uzAIhBd3p" ..
	"2WB+ft2w8/1l/BCZ0wGhiJisuJ4vuPpXD2XuexcV/Pn5lUlr7Wfd3kz9Rg12LBBjU0EJnjVLzrXdLPn6SdFkkJsC/VdCXCDIuQMT" ..
	"GspnqBdOCy+4+8bFUg+seSGALhKb540uKuEJ+6a/7k2X30FTTu9duh7ZUFUtcUGU5Zb7xOfOmQ8bGcrBxNS2CQHQVR0xpKHfb1ha" ..
	"b8sWeIztHwZjdrhDEYE6/ptXw+It8oxbghmBjhnVA51TKA1wQqHrtFlrpqgUzAskUFPmlE3T+33YRijDarZF8DG2O5uZ7nUwT8vM" ..
	"Pajo1KrjP49NUjFEtFuMEYdwJzKwpop5coyQOblef6mINpcIh1EDLYwkPHwZKjRlLoRvt02P9gxcTP3P5s7mBDPDbrhBtpOx9YSa" ..
	"kQhUb4m6wjrKN4Eg4eA4dl7o+S6kVduKfNKfn8L6XH8Yjac6qn4Q3+YvbGDKiqtUxmWyHWEj/kW3lDd3v1GYHXeKKwQNc1R9s0aA" ..
	"vFWtrYrPP7cih+3nshd5vGi99Oc28wXv2Dlu6gTA5IHCTlBt2eUdSzQj1SRn4Va8anFltiybY5V36RUJshb+JXgMsyOYn41Klef3" ..
	"8fIoqtmdjq7F1xq3GDszlGuvnacIKZA4QMj0HnhFRbiTTF1cqeus3vegVqa/vy++8elcx88x11L4nFcdWQttNWzrVnZx5D9fDZ9r" ..
	"vbBxzEnNBKY0V75jM2LG3xlDNL/t3K6fW+uz7bNZwKBHkR1hfrJ10gqb4GSQJdleBvu6nZY8aV3BpUHB/by0DCwYaHs2ZYOtoKo/" ..
	"hLkhl2cGP4QDOLTvjSYPD6EUGqzmudtGoBD6yy5btDEdjlTF723ZXdzwzpb5H3IcTQBFHBsraAMFZOrLRslyxk0WFjmqXUJkKyY2" ..
	"PaskSUIDzX6pNw8tJ9lvQbCOhkb8ZfdsuKA625NZMBpvw+2ItxSm1Gc/oWDCE+e4kJRtqstA9/lGFmJ+0oux7gRSzQ6YwfAEQdPK" ..
	"dxd9nJHcn6NEbOKldBlmlj902yMVzjeEk65gcXLNu8Y9nfrm6KSz4lx7dmSDo0mQcFpyAvvwgc4FoHPFXHZG/7iiqyIfYxRTOYni" ..
	"pYCc6qKtm3p9uxQxPu69LKSdEkIeeLA7rBB7mzelHGchc7Gf/1qL5yBjdVVVyWWZjnIJPAdGzEAN+a1RaTR7vTjsQszsbSBU8NpB" ..
	"NrMAvBqgENZpA02Jx92fZkUonVy51lYGrQLkSCB9lrZCzPQ6X3GPkQ0c9aqI0t+nIyvkJIShAwCaOC1iTEA40hucQ6fTcj1jgOb8" ..
	"mO6bni4m55L+SSRVh+763ZuJT0TclQbx3CbTCDko29nwEpfvSOUKR93ZKTRJp5bDGXpZjM2Ues5nkntcpaYCTj3pBPAF1T0FW5b7" ..
	"JmaNDxRDWQfSzX3aXkwV16HSg5bpL5T4LHBFsYXyW3B/+r34mkSVhfRDnIZU9x3ujYk+KSCRJ9GsQ2QMnQXb6D78ES724ZQEUcFu" ..
	"oBjNEkYOIdm7/Lq84UMOe3VYzPKaAjLB6HipjDqLzH47UedI1n8lPdJnf7p0J3Lo93sWSOgjvwKxxzEAewVjkSALEPsxgVguj2oa" ..
	"INwH9Yo8lpbnJ35h4C+SpKYjYoCJ/9NewjgsfuzWK8RQdEgX2NA7V/xyLX0yBZ+bzvm1llrBBfB9aFEvDu3jjrBMDpqf3SvSZ+jo" ..
	"Wf15FD1DG8Eft8nbULb/P8hYg7iSBmM1vnMa5A8nKHNsHRgQpuKHylwMowsX/ixDp/jZyXCPEKj9nf+TgQ+jSqNczLi2D4/DMeZJ" ..
	"BUvp5N53a0/ETyw5UwbB/T7VNAm4UtJgJVwQaPMUeiwdtr13ZudgafsduLCITfSRb+sXqGUzWPR2D4TnA64ytUFNDs7lW/Yozrfl" ..
	"6KiatU7M0YW844l4U8YKbmYV+iporO5GfArDAHGJhOtZecCR03FNg9K9TOkc7HTXaSI2+E4VBfYdR2/gML7C6jpg9rtWpfDwWkX4" ..
	"AHYh4bbIdPftKk5bmGPct4cP2S1RgCAz85Yfa4RnMw1hnuKWuSKLQVNiWBNah+r+V3N0X+58absGZc0i9GPZgOBGibOvv4DiuScS" ..
	"MCktzZi7/f9cQ69ZIUM77z01mZXplZ06RNCC7eHrRnVTGgk+iepLm5AeKN3/U+sQPQ2eeYfMlrPF9Ibg1KYvMMLHjFYZZ4oVjI5N" ..
	"Z1AcBCqY3JkOV+trAmwUWwZSL85N1Syq1XIPYdZ2zS7e5EAbTxEqBCs9yfQc6WrrSXSJvQzUpHgo5Dhhus3zl9ChdJO/S7XWDv+u" ..
	"vu1nRS3y+JiC6ntnulEt+xO9SCRJ7oR0jtnujQQW7jQZhCkTKPF/jUhbMkc0sDCcltIF+lYAtvcDypaXyLQPPMKAnr4igz7IvOPV" ..
	"2QQytxqzgaQdcKgXC8yK8Bq7bkGH0JmuBYzugrdIQ6llJtAJ4kz9aRjHPdvPYsx5ir2YfZpFH68WCfcu4N2penOqS27WF/surlkN" ..
	"p3HUozFgZ8xaTqak/Z9mJcvEjlEtESXcnKmohiQnudCodme0cPIivCdiQ+v+9xw4h+T6kQd8G1Rsk2/vELnUBBQ5UviwlNLYyvFi" ..
	"JcRxsBHIZWttSU3AZzVaKQNf52HI9f7EgQ0OdAm2m7LonCFiHp2LMVk0PwoA6Cgx3whWx2p0HSn0Nx1aDxlnge6rBLTCqSWmebdv" ..
	"cO3We6YwHQyJMSS4NpeVoGYe1Lz8oUu6fFRkH/v+LiAezDwcRnAKdny67Z4cZM296CwD+kPNmd53w76nkUS5PKk7E4QgLrtBzzdK" ..
	""
local PAYLOAD_P4 =
	"qkrObTGFzw8jKeSPoKAFEYnLxS/JNw+VH2+buIy36aCZeaOOBCUpSm9FupJqLpvjsfV8F6BkKZilnWzY2m+a+rMjX9htVV4mRMSo" ..
	"yEXqP1wHgTjZIktIKdVhX6r08bEHzuiGIJ5Jk8G/WV17tvUCFUBkvaZfsV8BThU88bap1AJw9A6aXQUZ+wD6kpuqEBbylYDvdgSN" ..
	"qau0QN6bbXuawtsoRskohL6vgWA0W0bBHksFWlQWL4OGlYJqhBQTKM4TwtBDx4vxgy9heSuf3qoYknPZrg0D7WRXrcb4jPW0mV4P" ..
	"Muc6QdJg+Q9wVZ6H5PwQC0OHsa5cOici76xyZakcPx5lR+FvuWB9eLmFrFxdZx+BsJnXIw7y4eWDpkj4ZE63vr8r1YYke7bMZF4p" ..
	"AighTC//DT5TEFt9Zy4fy3qa/ua+kAktevwTcx2Q4kqW8w0HFDziS9hFLCNwj0ZASb9t68BQWkryU3aYuRWFUztmfhtZcXDcKIHl" ..
	"PpvPsuxCVVRBJjV7zVoPJvGkorkRdGhryvwHPcsFcMiVBxTW6JPxqd916GwvLQ48h55ZmE3xXlTgyo2+M8UbTo7I419pji++QiaS" ..
	"4n/cTFfU5wNlhClglCN1b7PFVAT3vOcupY0nldRn+84EX2fYNqGro4Hhg1Gb0A9hhLNgbsSpfDZqhLB1boMEuYu6xFF6YQknjYzt" ..
	"ovK8I9m7+VYxcgLBtw1GNZ2WWIqVG+Oc6AHWduZDf2zq5SVkqU5M+vF8EXYpmbtmUOzEQTyP2PgaPtAALoCO6qjWpbhKbp7xwPDL" ..
	"aG3fELUiH13Sc2lWxOUmlKdkf6UDw7BFVv5NFNxq+afAhTT0fYJtEzTNBrhPTq57ankJsbodVW0/frq7U+wV+PS/7pi7Gds2MH1t" ..
	"aEFQU277phv4cVBDmxpemVPeoEI7efzh3a3Wo46FXBcrmFY8hg9FOdoml/h7PxGQazmZ+LQLEOF2fCGjb2sdTV1ur6z6eCK6xDqP" ..
	"dj6BdHi0Upix5HA1otOJz7hR3nFokAZh42AWBc42eruJui3oBYxxb8fHXLtCtg5drSQ2emk4C/++K1M4jf0ZthwqawzoSkFNSSl7" ..
	"1NayOfxEfrUOXZyJm6Z+o20mUHWo765CUnGLTwMyOCkfRgvRdzb0fLIcfGC9fEEIK/ogp3CMWctHQQeclljGvAN7j43gMJTrqnqz" ..
	"f55v39RaAcmfCS3rgMCQte6ZEsXN2gkQW9IPk0UhHfueZWxDBwZOejvcthBOCLav1V4W5kN9FB9HSF9b+xGFlno1P4wBJ38D94i8" ..
	"9A5ZCBNFcX00ME/j3SM3FKtIockCkk92covFJ0z0uxUAWHvhIW5USaws/sdlfnYdanE66i/U2TilHiWJQI4RTDIkwD3dcLJya/KL" ..
	"cZZvDvKk8FRzRRl70ojU2fDORqsnQ4Riu+94NkAUMoSl3FJKBA7o1Uoxsk4kVXRo4k7K5VmsJd7sqwQWR1X59FKtWJqaY35Q9fT4" ..
	"1b8l0Xgr6KU3HFyZycHHX1y6zJ3eBiM0YBVBWeYXPhF9kVpMScHmXVjARLnwJYiDwDAZK7raS1yNgmq2YFX72UXgfwoCUhPM6MY5" ..
	"7DY1BtLGgnVhC1v38S+MF79KK6AG6KxxPbAAVKB14vtYGtyJTqyZ4SlLLjlUYLoytBkJI4piWcx4b18JQWMx7Jx85+TTfkAQQZmd" ..
	"RwL8uFWGDYYgFUhLQLiy+3yxJWT4c+ZWMSJyiVVEgSZTSHI8Yin/VTqaW7J9fn1HOAQiu/cUy9F4oq/gKjwOPc4sbUsJLp5OPse+" ..
	"GKTrwX47NHZCVa6YGXiYXEjDM9pA7P2nG7iIxhc/0nwyxPSZE8yb//xEmfT6K73xjYplY6A6ZI3SLOPUNgB8F8lN1xzeigiaQM4Y" ..
	"5na3iuAioDledz3m7umGvxrdX+Zx1fv9wSsFkeqQxFzLbeHV4zC6BpWFLAtEQOTZrplmFlwMnDJuiCdYVdyfFSyamjq3pvu8Wwsx" ..
	"HPsSB3x264bBwRtxDNBx0cG4r8q18dI0gB3hP4PKgPB7geLiHZVnUV1g6/yxJaAqNCDN4NraiIxFCzHEb3Rjay5aI4fBp+Sz0gpW" ..
	"Z7rESdvEEtbGp48PNZO6UCa6+kgy/9/+7Y9H47/5FwsgC21fcXZpbvBnI/hEAPcZV4EPm06EG3S8CYw7x0T770gMRSv+yIBbEwG+" ..
	"R7WzbLqyIcOsAZ0VfKuIlJ03vVt23eXOQCIgPiyQdnJ219/3iKSbtyC4txGubotLPXSiGnL6FkDMyvLzgOg0zDqlXL9+J6eS//Fw" ..
	"i7BjMYRG3R9Lvvh2E9sq1JtD2GtMfMLtwzxyBNmyPoGFZp6Mu5IMyxOzfWlMOvCswsG+rlJL/Zj3OZnF6Kzih+Bqd5s23fOHLUtn" ..
	"q7PI0VlkFTKUV7p7woEHmSXrSP2kq98f+cjMf2xeq/l6u7G5mimGStVYWUFOs/sFTtfK/3paE2b0Z/MqM8Q0sazCY2GrMfPz/05d" ..
	"3FS69q2bY7QbgXab9kVimVPmnXnAJah2BKpZoCTLBR5DosDmQ7jkTu3J+cHAApjNSs5xJG93eUF798iT9BOeFJTrPAIz8gJKm2zB" ..
	"yBXMUUMKBHXLnjm7k/3et3Sp2O3ps8sXSPS81yLjOEbOAxK/YeP3XG0lXOO5w++WKypgGwhkpiFpml+2//XknVR6M9zWxvX9R9c5" ..
	"M9RRv97urzVRdfDZ9+ev2OJoU7fpRqSTIgCS/VjJqkH9zlbiEC77rwsEMl+8hI9gjp1ZfA6YDrUTahMxM8JzSq4lAfHcdVBvG0hK" ..
	"4iF7n7ee04atWtYPW85zxnXOQyuniY+FwOAy93yhxvN3fFddyupiG/1ZwyTLO2+XRx2TOIBpDA1UI1NVRcElKpsV4b6ydiH29bDJ" ..
	"vEiyhsjKqwqtpQmdfjp9VBs5KKCU9L10pA408khBICXnkVIj1yj7ELQLCn/ZW83vAAEEhDfXgZUUzL8CYwMcggX2JOhFrKNUzr7V" ..
	"cRQ8pnv9Gd2SB9KgWsdnui3LzaUMcjMYN0R69zAyUeO5jLg4r+3g31acdeVYpzbVVAvVNl5vfttCbUDkmzDjdu0tq9IhliJUiYSe" ..
	"OT5d+sxS9t5c5HaXNfVELojv80dyi7Hl6XanA0u9jO63xFUiufaiuaiU0tJ1TsTqrGAUFpdDxdpFcJC1CVqOKw3XaEk50FuKASgc" ..
	"BmU1MZCB5TKLQbe7BqbOdwwS3HMHSPmUGfrZL6mNQOFDXN8977fszsBFUVbcgfPxFc+vvqaFRqxyXk/Sxck2IoE/IvfX/ueu9pcb" ..
	"TIWHai9OaEB8SbAx/mC3RDm41AQiJaVdCs9ynpAq9e7VZs86ACr1uB82KsagrX3MuJ52R+GqRgVxq7Npf2XE5ifFYhDOaQ7IdPkF" ..
	"hVkpq41Pkr+FokjAXgQ//9sGVzGdBglsSDTdcivPd+yDcbROum/EkmPK1AfIzmIlr5I9hL+0LCzkST+QWbDUgeFhTf/mMM668k0A" ..
	"miPC1MVlDwF8Me8hjxvpnH4nfijZ7tY+EuUd5VpyRMT/WBW8G4CF0Dqgzowp5AvwqcfvYKuDmYmqh0EzkdpgtZvWHbbOCRD8XoaX" ..
	"lB+NC5RUdXVbH2DCD09JxFLW/a63Q7FYdbF2dkfQU/y9bH5BhWNZa+T39D6cRAsZO14zVLv/Cj3PYFi1w1qrSmkGkLA+O+RIFahe" ..
	"VaMYRGUHXYSIbUD1RmQYwAqPLuR3ao4/+6bha/68liNj1ZH/OxNKDuc5Is9NPtPIRznfXeHef7oExCm/+ljVdt+m6CrKgPe2q+b4" ..
	"dQf1v5QkrV1kmdqZTpGsTVZ0/OyV/Cw/3EprtwHQ1qzEAX3uUnzNTR2blOr4tbHFjv9WJ4Cj4Dfh2UrB+8zgQsS4eeYgSRQCBB6d" ..
	"f5M7psvGdRWYR1vnE4JTu7jNrFeZU37uYlXAviwrdrOPp03bLufRVIrxZePFCS2/JxcgN5yAnfN4JR6wnOdb7AWv9zM7FE24FRfK" ..
	"PLeUuM5GSoriS1hNZG2AdZ7a3OR4oy11L3yyPjFLzDcT/YqEF/9kBwVh6HqxW8e/KqegEWxQRIUIqmoaxvRh2jEVavkJ+DAVIwyV" ..
	"+67DtH6pXiIOUWCYFYMz0bFGji5B8USwIO5T4qMzGFIsIdEbZvfmzyQXzLmerOajZAA2CFVko7k36rCCqCjlQaAafhrn3PBoIyn2" ..
	"VsNUBTnFENjSn6P6Qwa++sZVFxPylDUL2PbYPGVt/XK5Xw3S0TI7almVp7wHN4FMIkItkgQqUpLsLME3lSmqxy4A/01zZrsUnVZ7" ..
	"L86FCg3q23ViXY/A6kYyEW1L5Lf1zaqKwJuTFnJSJtK0ziE+Q7HZvBYFwnRSxrZP3uLv/Kh0BGWOF01KYPWhE9oXRzs4z8hJTEpp" ..
	"z6bIYxfA/U1eTkEc+tZ1D4mWYtoo8Zm+4ZAtSbJ2z4w42bgHN2sx/mcQysqqvHUIIs1hxvSFkQmlxgQBBv8vu2Z6FQKbk9DsxGdA" ..
	"0bRKcnUlFgNfz1ABtf4xV0tNV25+fA7R+TeqodR28ZendPqfr6ozKnCo6ZHo17ySQETLB7YLSwZ12qJFByYAPDYD8L6dDvO58RR/" ..
	"LK4DLG8T0Lp2n9ifufPTIVhQwMNdjuLmi6i1h4MqkRI18fXnih0hm78MjuXAJTHMxZrLS9s484qauyKMqcoV0m4FdQm3YuKHeo9B" ..
	"4Y41kRfM71n0qMfBfn5vMmDzkH8l0kWTRQinf4PIng5eb7k8LTNAvyKxeWHOhBUwbWJBqeJZrVOsKwiJhi6brcM2McQhPg4C4YgR" ..
	"zslvqiZJqxTpSv07leOho35msn3pLnxn5uTtXmjhtI5N3WHEmrXTU7wrOSWMdgfuyxi2RuuIC7ecOODT7eNvUb9RncSziPAAEBDw" ..
	"vI9a5BXnUjHX3BvDDLa+VB7G5xz8qfdBlnkflZfJvgeKhQR8+SICNrSa3KTs9G+eU/MfAgrx+Llclup5a6Jorfb9Y0WwrUCHqZRv" ..
	"yv6ZnCJ5k+U1TPRLKwY7Ki/PQBbqRkYErC7AZgMBlRgbfdYEN4FQ0WSeqRFFOlCdjlPYznc7SuLx7ZhLj4heDw9DWEhXUowh7Bf6" ..
	"Jp9tivEF1amYL/WfNQ/JxiG3wcPlk0ul4z/wLcQlaMJUcaPdurnWsXBQjisXK6tm7uWw1ONHFn5XoMFdqWgMCFlHi1XmfjbCkt7q" ..
	"9HTcPg4RIfjjHNf9Pbrj4TnVDPkBZUl7wO91CzW8WXauLYMV6cvsaLXBzeRSaX0ufk3dqTmvdyn0/WyTeVyfCW5sxULvqNou0LQG" ..
	"9Xtq9+TFclLNgr+M9/fo4RET7f08vz/nLbk3VTqG5WzSrM11YgSi+awrloXBFS7yfB6K+4wFb2O/7rZAWwwUWCfygg63UMIL8h9Z" ..
	"TGzD0YFrZsiZ4tgoRyiCpLZRdP44yTSo0zHp8pPG/AOKJlfyH9pa4Y69aotEwXPFb8omudP1Sq5rSVdtfo1QLdK4pE4qoTfjQFtd" ..
	"kWazan7ghiyGgUv44VYB+rZnFp1IbgJpH27Rf0bvcxStot1hgB5wP6lwsmSbCWwmFCr5ugKt1I/bdnI7epM3qwF+bV5EE2evH36/" ..
	"Jaar9oE2Kq84B4hHZbZJHLhentFHU7q1UqM74NmgMeUlyrNUDlTY23qSUwvzdc1i7ZrxsqUXjVVI2+KY1OBA7asCfMgJhK/k6Urq" ..
	"YZKHOkjXfCIHDyMQzKGprkMjnKLZdkez+pVOy6CE+kmhHpaI98NPjic/8lgdeI+DdQqHP7rTXdccwkylAR9OuYn/MYLwRmM6xhJe" ..
	"gSglrz+73DIAwOquu2w98Y/IjJyWYeM6N+ouALzMitx4dsOVM4msTEJQ+rC1GxEJYXeaHI9gjeEcUlZfIXnZtwdCqVHkFfFFyRr5" ..
	"OnDUpR3uhtxVOOviPRQI25F/8ly0lYZGBgvuWg2kYee0Syf6ae7Gpoo9EWFftOGlgnxrNU7zxLfos7EplQgjEqS9woM0gv3wi6Nj" ..
	""
local PAYLOAD_P5 =
	"cS9Als3D8JYUBSVpAdL4g9n78/ZBtOhsmdDPM9Y61PSi15UPVa5e8TZ54f3y2HSY7a/b+crWBht9VKBZVaFyd3PAcoTx5P42rqWX" ..
	"HVvSB0TDZSCSjsREpjH0X4buy+RfVN3e/M0o032gmlN22bYV+9ga72hahXtcJ61CQoD9R8NTfvTdwlj91NUX3vS/habi+wBKk735" ..
	"JrkKACqh/5gjRLAnunlOimYdHgDf+WquZVM4zBISgtxJzeMjpwf4/J/hkE3MW8gc+V1UyzKjFgWo7nASDzEWvM4K1GVZA8rTFqXI" ..
	"kxJXesqxznEgBhG604cH3wt3yBiQLfyIPA4elOcHFJ6ul41UyaIYuwE6YwPFU9nWfkSoLo4DnFbN50e7FyPEluFB6duyHWT/e7yx" ..
	"nl4UMp+osJAgy5r4ehBnlQIpFKSD6gaUyeoeCaSfmA3Wct3i+fuH6UjK64VP1NmxKeP/naC0pERVltJasSTru+ORC9ldLF42e0OY" ..
	"G0D6D+FylGn+IYgjFzxz2QmW9cZJzpuwxShI8G172MoGIvJmMkBsRdMgBcP0O+KSGE35hilAEw0SQIpPKrf1rkzAa05SAvDkFZoh" ..
	"i8gaNRfrwwlsgx1B25pYGh3jA5lvbzmafygb8AmktHWDU+sXw4NxRmGzcCnGDEi/VTNXPWlVggLCOjj00eAkiatfY1eC/TBcf1fV" ..
	"J9DYJqI9R7T2ee5E/X81MG3zAnS1tYuNE93VQ7BGSFbpNalfcaIgOOOqwR9qEo+1JmYZwAQXJiAY7nV3fFxXN/Pwn+jqem7y70X+" ..
	"D39c/XrgZIu1H80C3orS7o4JNnB6A+w4/lfmpPQ2tWYI1zgEzlvhaCzWQRMw8iXc7EzNSbf4juzruzgk7USsSyu5QsKE5Gxyg7Qu" ..
	"Am5VQWVhLpkQ3qsRu1d4gCxHTw6KQ8C6ZBrFZ0YKFKQe5EtqPrzAe11xX4QU6TUIwR7WuGEUvAEAJjZRJjengNzndlrpahSX7p93" ..
	"/6pR4L+QWFLq6DOiYci7ulKdeKcqKSB55+vdiANOBikY21M2qPyYjAD3PVroWitmFvuvzNWPQjspjIyTTRoM9cNVZw+Ekq+8ZkcZ" ..
	"Edg8rNcS9ZFgyZFXcdXrvp0/R1w4KKGvQY4y1Ca6+oUeM6oIBm6oLzxqzVUPIZEMfTYn67s5rgqi4MvW5flyL38sA9P/xwUImNuI" ..
	"9+N06GzXP51YiVdO1spV6ahq+FV5IlnNxPrvTBVbq+8C7isv5qpEe4Tvr11uIczoiLLXwwuBPZ+Sj5TuIL6pErS/CWkEq59aT4dR" ..
	"aQWrweadOPT32otoBG/3KK+9V3qEp+pAbd39B25osTjJXcJ64W4gXlv8QWVwTEm1FYggtBVCiHR4IROPq3aKP7nkf5nQJBjyEtIY" ..
	"VmGWND6uVieEjkyxXeApcE3IDwV1IwhHjZV8KQ902CwzM0P+lSFxre66kCnDDJ5SFNc7U1CC3G9VDvajwxmWpwAaE2s/pRxjxsW4" ..
	"5ECMmDcyemSuHjYK2YhzDeB6UPwq5RBMo/p/1ecO/qG6+JBDlqyXlTI6erSjqcWsATE/3wtlJ5dOfU+Y0fzDspsUey94k48jjhhy" ..
	"dg6pEROmnGGfK2JbAeSNg4fQSefsRDB+FAfTmbVd31pCOkcNbcHXg2WL4vaJp/NXpClx7CFXaRdAXH6ns8Na43ADywmYH6zcNBjI" ..
	"cnQe7/4JQ2t6dbr+jov/ZdzBW50ha6R9E92FqNNDACzcY79NMyw50dfWYnYnnmISIUHAP+9Z3MCMpejup56AXkkKqGNDUh5xTKps" ..
	"KYgc2ERonP607uS1AvKTxDdHiLvwI1fX1DvaJJhsUSswexOBObT//tAAbp9CVE6WqJQ7E4safuIaNtyJscArztffSGXJOzJv9xhH" ..
	"ySfefxGNc05x3V5md2M7mQ6aETCnyAGO90RBjMLTM/MsbOBSMnRUqScN3sJD2rKWx+iC+X/DGJUCNlmNRExyAhyguA0clHaidEqZ" ..
	"f9++6Sy2qaz3j/44n8MuijGsXCbquNM9Elo0YuMkDpWLbltJpLD+w/1AghVaxV2sia+W2gYu42KJXB2Plw5Wcvaut4RquTZ0IfFd" ..
	"96+UJV/ZixUEVl6/f7czccw1chYmsQZW/X0jdgLVq49c9eyty05J1kAgRm6jW8vOWuumDG0OCgDJoeJwCnBuO2aNRfQTYGYJIXlO" ..
	"COTPrkf/euOZKG6pdX7Rp9lAwh+tUwHcu7OX3ZgbgSKyYn1QHPZRDwrt3/K6/UtbmkkfJDm58Sd3eoUGCLs51Z6X69wGKPCmhMRK" ..
	"kuoTflFUnHwrakhzaaes9JIQVRQZ61MkStst8bQzjCqW8UJrNrGA+t00NQV960Rg1RXp0XdeDPp9SbNmIOx7YmnCNWsKEa8cQz69" ..
	"JRyc2DhwRRVb0AiPLHXY7U6SFP91TxoUWkRqbVdp8yHVp9LEwUcTsFUuu64GCCVdcAlqA6q9Peawyte5m2OI/pmWCOVZjK5n02Sf" ..
	"W6BtZHXptjuQIcQxFk3RqzJwIK+TnJsa9DZwNswuY0h2u3yClffl8U1IEPJtsXGGphuORbFd1wJ/51cdFa1G80QZKlZxD1/AMr/b" ..
	"ft6ufclmvrHNq8jMHMtZeZPBOcFdjmezX6BvSYl81xvaeA4Lgh9PTPNBYADilPoeFWpNg5Bltljyi98z3zzz10XkcjVt/5QFej4r" ..
	"O/r8stYPTw4JQjkqjAS37aOEE0849F31A7G9vLAi5rF8TZjBPluJdcATbWBk5iOLYJi+3KhojZyJrLyc/NR5zDCtr+7clECGngLv" ..
	"jmE5afMHLljwGiS5S9KD05AeGDkBLX/M4X+AoADfbarXPSdpTs37/AUVou6zbdoh8ARanZAL1ydUOIiLvyIsYN5//4f6h/IOw/H+" ..
	"3gp2OgwetEz+ELhux2xkJwwyPtwpJ7Dt1Pkx/IKV2Y2R+Xl+J/Ahv+FG5wKPMFOPKFJOtDyx+ohISiX/SNiEbzrVnD28EaFojvPL" ..
	"UEkYBOq9cWoJ7iOra+bzgfMcJyuFMm/fGLSguVCh1Qxz0SvmGZJ1shKGlgGEI3eeNWqHdPIdFSNMa/gcueDj0VBX9e9FsXPn0ZWd" ..
	"MjFkPrGv2w6WwEifsmmdpUjpiWjN6+t+BLT5mRMjdMNU40nKzLA685eWsiPCZrGGtwLPAP0uHciv7uzqow8Fy5bPKvBUuW7gqX3S" ..
	"cO2cL5dPRS9DUr8CeALQq16O+Q4A4csgpVrMqlGiJiov3Zf3DsY7kjd6XP7/lSdZaFZJe4T69g/wWbWq4E6EH1V+c+/e61/th040" ..
	"MKaJjVQJbWFVu4SRlCvK7XM9aZp3dbY+NVB6PBslSAwizNgUmX3HOQfnQFZZUAkpjp/mm6wh8gS/FGuVlKwJNitPoHtWzH3yD/BI" ..
	"N4aqKOuAvOnqnDpXEl3zV3UcV6s3vL2CghmuW/RwMd5sjMjKd7fof4Mw/De7+QkMJ4+b2+YiMl/U+Zdt5rKyVwn8r2NsbFsGWNnx" ..
	"KksllCEfG5kDIzOmtluGRCnCvDm2WmWZrXVTSGTBGO4c1lHZ+Znc02zQgz8nEVyLPlAiUG+flfDD7jiY1KfhA+pMVQxW4u6Rg/Ws" ..
	"nrTWQj1ed3dAI1o+YZTbboilXX7b/Dsq+nFZvH8QICKMH+Np6cMSsM8+i/e7PWv/BbpWzLkQQyeDbcSgAy4p5ODvK1NdaQdPAAqa" ..
	"JD2NTw5HACFGCW0OKSOzyVxzWJBdzRtifKRULLVXAa9g3LOAj4vr1rgTBPS4jkt0+GVtCgYcsOIUHaaMIfucifN2fThm4chfcqvA" ..
	"RMgrTZmcCXMnq97KbqvtzBFko1dYFxFaUb8OaWIYjtRGbuty+gVkMCFLfVaaCIMw2Nh70qEqWPtqhmoLQEwMVxTgPHk/03IAQ9Sv" ..
	"2WIiKbxD6EdVve2jHkSw52drVeXDaCDYkEk58LgbZvFwx00SShHcdZTtLarrSFwIKIPO3trw0YySUvwu6OUWIlV8IRpcV80Qyn4B" ..
	"GbSWH+vYghQp21Xu79XxPJW2skiLwcD+jBX7Fu4po8ET79ImZbvcsRJuN0K60rnih+8PPngcqwiUOL9EBCaEbiv7dni/jNRIahCQ" ..
	"mSAmAKt7rYMjnTftQUh88xro8eRrzX4mNAH2Q7/3RjV7/moyW4wdaQ9et/rA4IU8WPDFMbAXAYXIuMWM1lMgEXMLUAMaTawgijWo" ..
	"cXGGXo72LnYoKRiTemIXcYiHy9ziFxqsiLvTq/2G7do9OPiqZ10yX4domPMQa4CdCjIqgyKb8/4a+jNCVoyOd132hwd6CWLVBj28" ..
	"TibswjTlPGjYnzn9gs1TN4r6m6DDwcIAHYm7t+lbAbwXlyg5peLfibZ1++AQXDKSThLg8iqcs9hcS7GNjDadGAMj3QgIZfuH4DCw" ..
	"km3zIhiI5xEBNJqcUwpN09JNY07fOdLlbEvw485e8ctwBCpCW6Hj9tfreAnZSqGlBFd9lZo9Rl4Pbw/iKS43n7r+GgZZZM8C9o37" ..
	"ezLixzMhuK9MaxtTup3lVGy8wQrlVO/pUA9hKG1mbItSZlzN8w6VXgMCiG6h1C3Y6U/3Yr+dxnAjDnxRJtTuQ9nRaTpwSOF3Y3YE" ..
	"LbenQyICfDRGsZHTMpFqp96+47IaWVfRiV9ck5DEVcOYXUKoUH9Tt+8pT06BZiiTlvFWIThEKdLfGYtfEgnFCOKGCeR64vFyBJ+i" ..
	"IKOcGkz//DfKgJCLrl/LbiTu+SgptaabEMRlCWdCMAckucq4E2+PpB6SM5wf2IR92OKG4e/4DVJxC5DhRrd8x0jE/kcnsugm9pXP" ..
	"Md9HZ36sZLt7XFTlpfOdDX5RnorX3dXOCRnaigS7aK/64DJ0HBhneED8ahS9tcBRqnRQaHGswNRgbBnF6xfLej5xStthtF1y578s" ..
	"L2+uEIHKn+XXIxTPVeQihoJPtK+nzd2aa+ihJQY1UbdWbrWwOnak3c1fb74ok/0eVTh8bMK2zVBFe3RTYycPhumL0Q2sPEKVVWfv" ..
	"/2VVa9Gtsk0SfDMpMSRNE7lkmqNhJPHVjccBEVfCtzXssjZzzBVkW/4WlH2H5XFsAc3P7HwleRRwvzuz2GCNnQhfnZlqVtw+nUyG" ..
	"+6GWArvP5TpyYDi7oBpnHQAk9VWI5jSvuSGBMMr730SGf/w10VvoQT30atrvLg7652uEXEqSQ80usFDWzJhAdXVl8s6ZoYeRg9ek" ..
	"C6zD+g4KHNAyKui5EFUHNtQxOviVicoZL9Ix1r0AYPg/VtMbIS9RlaNl/lfNrjOimQg6Xy7ZuY32tpeGk068uHoEJ0tTkoJ0L+Fo" ..
	"Ovg0jLogAAj3fKP2s/p7vNYMz5lyhijSS35hZDW1fAcuE1xKWFdEg9AZbHGtpWLKq9giu9PUPB7cEx5SMfroN8kVRrY58LuysFvW" ..
	"lbEzDtloxFbCupfBDb7YOKSEwmjb8f7yxwyea9jmvjV61FJHNKBBo3MjS7Buwyut0yHNeZuVnUZe+hd1KrFTlwBQ10TvzQAt9NBw" ..
	"3xN0JsvEUdjZKWK4pCq0ViHE2u1MJ+f/U3gckjV8uleWdCn+i37LwUha+2XLp3cSQjbdUvSlOIwdRFqbCxAdoeaB0B8BHj8vWKim" ..
	"qtVEEhaZVx0l/SRxdrbSSAIg3yqzrT0wP+AATb9nkX1XMAUQbDu3CplmiAuJm74UNvoxRtPA1yGEQHUZ/xFBp5IZ5DWmYdHRvRkv" ..
	"r2IQarAWVKUty7OiWVeKFHNfMGZCbz09AbRp/zWbFPbTPp7dwIwlr1Wxy+d2IDjlTA4guAFIgDEXRL3ItFkyn2PuMeNawNqUDeqi" ..
	"IFNkNrTyg3oJHib2FJuYbhE6plYvYGmywmIGZZNMTImO6Hu8kMrnyNQIyEEnoY7ryajog7FgoCMpfU2XCNwecH+TT6Qa0nOoEXai" ..
	"rFSC8nf2iRkmyDPeTMn+OieiDE1N6w6L6ZzirrX4VKkc58VR/Lq5mzroEK1/YOA1UCWlLocG0G43IgiP76CyxbvAOg6mmKN013/5" ..
	""
local PAYLOAD_P6 =
	"/9uH9r82ufEFhx0bSuGc2C1cB9xszpQmjQOX6Gu88SnlUHqnd7Qak8DnkC0YdErzZTZWHZs/W3jh6wod5++ymmhQGVmkGh13Z2+i" ..
	"GavpIN5iNB+iSs9kiODN7+19uX3n7RuTFw6FWgqKOe2i1VHObUoeKfv1PqldTytsd9IjdnYRcBfKpQVPPjKo9+Di4F06yS0r0Y4a" ..
	"RlTEVP8wxArMJrVDHpXythiqB9AEABnQMbOvzxjcTYaKjYVTaN5ZUg2YVRhEqbm26dAi64IAivzCvxWOqfbDW6YD1Vo1YDasAh0x" ..
	"7SQI8RSCciz4d7tOA3+n06P7FSKGTW3tuZ7LWJ7LkxGJFJrgbOlS5E33lhRIWDvSeMC0twu/jwztKqDFFrJPOMilpPxJptZir/P8" ..
	"B98T+Ar31Tt1U4yWeHqizJ1syvyCOplzeVqIHUYh14h/KapkUpgFi91/7YwOnSzcPTzQiCczxl3V/ouaKONmfb9vuMfeqtqwVlwo" ..
	"6e4UU/p+lJ2VrdT8Gb6ATESnbN/YTImdW4b4hShWwXjvH6zwqz0HSUCooaZExXanfsYSAbQB8oiRiKY0fWb84u4rAfO4gVXNu0v0" ..
	"QxG0hHmaM1aMNinmr4WCTMSz4HHzp5vOAHebShYIh5L5hoc8uv+Lvwo81811rqd+Et+BAQFQwCyAvdzQjro3N7CCNXC6/phzQHVQ" ..
	"1ncmvJ+Wdl95Uvmd1DGpjR1uHu/np4X9mcDOQcb0DitfQF6GWVFEfLUBDVUpnDiklocIVoKWjfMt2Y+w2/5TxXC9zWTW6Kpa2E8o" ..
	"y3KUtztePIYf9KDKTHT545AUoEVNXJQkGn9ZtJry50y3jNYnELNlb/vy86bhYeUnpgJ4tM1ERGE26HGql0JM01WPhrXawKDvxvrE" ..
	"7J7ytsnhAMgO3qSLM1/2wh4l/9mYaighYTHwnupsWVuwmx9eXzVVEmYLY7bk+ZWYxRYW8BSweeAXFP2xSrbS4h1kooAyg2/flKIK" ..
	"NHTChQkGMHkHspL5prNIaOQBahMMywzUrFg5Q9uC+n8FvH8iudQP1nJPmoh5PZqGa59MAZ9vXSR34hdlYhQ5kM+9i3YdMw3I5u6S" ..
	"jTlPeXcg3tlOQNTLHK7gOXO/C+VV0nAjA281IktePm51YmUEPh2hFCBhbGXFFbtou1G5S7/1GY3HQSXrv2PnVuVdkIk7ILHW09Bz" ..
	"zT439V+CvYOmKEZXPE95czdvZUnB46pLqTmTVtz51qzFP8qPycXhEWvak1UZLQ0JnVOymbaT7zqxHP1Dh5NlxTC5rsR+7Br/GCsw" ..
	"yjQ/DusIlMmXwEMeQx4HVYxTqCvY9bRZHn5t6fXG/DB/wSABsS8zseEeD4VrMMANIl08myDdHx9+jwqeqlCmV0mnLutfZ+jmXHzx" ..
	"zvWmeAspJtp0x3FGrPnCRph3lxf87G9Ewsh6cbRbwZn5oHd/uwSUV0FJWwe9OxhPdAihrwRM7N+H5hIL15tZo70V51hiIJ7OoScD" ..
	"XTL/D5Z/A2u8FUcRKnUSjZrQUaSuplNLhu6UBJRnwY9UxVLYJ1zx/lW/38MXQalakhhuZN0qkcYmarTDg6v710rk77itCLBACOwc" ..
	"QE32eWRRR1RK7ZZu6hRvBOCQDADXck3fnC9E2mBR2YlDbQevkcxy80L2H7UHLDhEJoKwueji8JW3vWh9u9CLYhUgc4IcCATuIXLV" ..
	"j5f4Om65IHpFU93YvijZp2Kmy+ldj/SonDT94kleyzTC/Yq5lmaIxFzst4tbzDGwDDT/XG36EmDp+dCm4NcEM0Y155T2KuVZtEVi" ..
	"mM1kVehi2V8mUXpq4j6eQg+Q9nF9vdC8ZYKg2Rc2c8wsREk/e7jMxdk/z38AzY6IBlrRgfI9DIJ9p+L2+HjccjdhQLg9p/85wfBl" ..
	"8H/GwNJjnoUq4W/LT++DOMqqmbmVulHX9ev3ZTQ5FfOYcDxrVRHztrvk5+HXZqGwkAWXmHwmc2+xeiYK+ccbaINvYSEqbE1EAiM5" ..
	"XR+BIQSnoKZ6snroJ3HhOQ9ML0WXPw8idATmLUr9ia9/G98fK5TMbuJBwW51p5mOesNlCuwucMNhFJ4xhaAlt6bG1daRhOSK0vRI" ..
	"kfYmYI5RUcMDBUNbqydbcq2m2Ikwk3Fo7aXAodX9PVe0Wl62NDoJaWEzhTuiYFTQjACtzv8QbkiV0NDycFeJVYYm8b2QqsXz2xvy" ..
	"/H/iJPmo7phZWT82Eb3c5RV+m0wawoiQJmfqpC7ZpPxywG9IYdJMPTKcUAtMdr+Vp1tzbU8oNhaZamYcFgbbKavR8UDitwoDrD76" ..
	"BKp1BLghW+DJwxBgl80iAt82m3uHlFm04WTgLykib3hdJqbXKEIOLuPzK0V+ai0WtgycMA5UONVhdhN6eZVv1RRsJBEKzpeOzwCi" ..
	"GPzmiNSHTz4g4Fn15+6ErS0FcaOnFnitnSl6Jo99m2foR+98iNm8kf4uWtv2flgNQnJmWFu4SfJKywoXAsMsGvYB6KYkT7/wZmJH" ..
	"cwEEi63e+HIjynyuSPmI5pSU4QIoAsmMP8iaR6AUYTW9BwuS/DYtuv15DpykLVnhftkTYgFumAzv75sHf9F6/cehyEm/fj+Af+dM" ..
	"wHR4BDp8jyunF3KBHMAKR+yyY14MBfgE3cw0H2JPcMiuoJhhvUf40U4Eu4HmRXnT0GpNfbAJbeyWkwJH7LLsqT4yiX6wgPjRATEI" ..
	"3xhxRj7NDK3WTiJph6P24E2vgzuSsUDtjW7ZiWPdMpPSloPrgUISUc+jE0jOMs7g7Fr5cp4VWHd9jBxubZWaDCzHdp3MmwQgFYgA" ..
	"RNYfvEbelIUjlF2u6c0NHHxmhWV++P6bPr385a2ZmBRpftREWiv87FUpXfeoLNRIMl/gtj1XQNDZJjpxgvBs+nwfP0t64UzbHgEv" ..
	"bXLZ1JVkzx4Aqx7z83E3CMVK+EBiLiITmoFqLaVkeAUoz+nBYO5oDnZWV92XyBVkY62axrPNms3DkmeYFfHmL/4qN4Qhc/83TnR+" ..
	"xdcL2xhis13xMJQHOI5OubjHjiCzWT8D77OFKdAVhHcfJ2jkym0qBcM3eDman8GygV1zOwtdlx92nsl5rtIlDDLTwYQYMDRF23dx" ..
	"WVGBTO1e3mPFiUm9EUwJ3q39BBu4GK0SW6p+EqAcp9E1GYh+6SoCd7b6vW3FACQWolEoxlo/Qd/F4mCsZhVQloiAngZZQ+QGXWzK" ..
	"9Ogw+U3ou5rUCqiPL1CDanp/u6p7zqef+z/lYCaJ1mo6gAcWxj7QtWQE/RNmCxklRVViq1QLNDcCMIabxTgF6iZ9rHeCWalx5eTK" ..
	"ivPkhCi1te0Mixz/FRA0zElHvn9UYre5DZL7PyFHOu20wQfJImfPVSumHfaAOcxr7zGC8wSSNgD0w/654Ow9sv7KYA6YbYf7MZ8x" ..
	"7ZkLH3bDjgGIzWIvKLXy3RMYTz38WIjYv111FLWo5MIkYg/7LmKDaxS60ZSBm4P2U3nLe66nH9FaINYafXmSory2Ra3UiZHpvm+D" ..
	"NBa+y5Z5BVlSoQ53F1xG40rqDO410bgkcN9uSlJxG9uAfMO7osSfk7lNr3SDk2o/4VIYVF3xzj6kE+exyRPJ3OzNxqhaS3HD9JD0" ..
	"pmbBFfvpxDDzTDYA8ByNc6ET/d4xmWLFRMkrJIgCUI9iNmgUZZvxCO60mtYXmQ7kX0GWRH7t+YSYOedxewvOycqatAv5dSXJDsFJ" ..
	"mvD6M/yMP11uPJJt3E7PnGAL6/GEWY0+fdSBiq+uikJsuCLZlQBXivWMqH+FX3IDNrl0ru9wvewz6cQz1n00DRd6as1uLqL40EUn" ..
	"7jz2cY2Oi48oTDHEYhf2CJNntwyjJor/GXyKWFJtQYvY33xrbMNEfmv1DfaiWQBgyPJoIGynlFAQp6B3QF60CA4umon+vX+kC5qy" ..
	"jFKJa9sxOCP6N6R11K4BB9EzqCqCSg+4HSdVhZWMPYSePxmWDN3GjY2hSAj1IYm+YxXV7xZ5KXY88ta1C8X3RKZuVmvs6g89Tazw" ..
	"5vM+75JFTpIMPLaC0dWunKStBNCXaoF45h8kTZzboeQALBUoGwx3YoyNddJcfZlNWGvG23mnORiP7OBHyQBZPA7gFWlgIo1LiaDF" ..
	"WHJMJSAbPK/sUiXiYIs1y3LvO+t/iMwB7pyYt0kD0VwDrgeIzMrJKPHXphqialn46LZmUzfL1zjVa1rDLYKg7HJ0IzCI1JIw7PFw" ..
	"dujZy/aoNdvKXyUeA0RgOjTfqHaJTftjlEmCYT75OIQsAvwVImuWnvfft4d+0g62ZDxzgQqfx1AM73OQmEFIv8TTVbzOogwsKx06" ..
	"ZNKUQbjoa9foEYocIbMg4EmRwChs1EtjZThS1Dygd7gDBj727/D2Czh8GLyomKilClFY3gDZSIF6hlo6ms7mrJH0a3Z9OBBwm8IK" ..
	"mMrtylxY0BfztwO9lUH7a3lZ0dfTa5Rn18Z0dr+oboHoTyLJZ3gTDN/ze2CMIElak+Trr1CJyta1N2IEIj86FTQ/NZWy3nguOk0o" ..
	"Md1sdSiE68j9K8jgvDLuRru6xw6FRZsZuY7DjB3Zp9LPhVg1vmPzylVVScveW2cj4np11ajy6ZWp3jCuMu5mbq3JljX7zm/f22Jy" ..
	"/UZsE9vaooQCXdRaDQhS1p8jRatQT2E0td5cVtYPo2f90NzmPPeNWsoYvbzhicCcAwEWI+kxoa8Gj74cbE8Os8KHSLeNZOAkd/GB" ..
	"cuain9c7tfxs9f7jQig2CCKg5hNIm9AzAlz3pmey0/aWZ68Ch7Bx3ZYP5vhNMjAPLtpPpWSxMXAPYlCwm52V2jl7NBocxG4dyj/w" ..
	"Se2O5ezAzG56oKKGsB5o49UwBUNTqkn6fZZ37hDcWpov/4mI5HuSc1iRShtue0Hwp2WAyL1rkEGet4NywQSm3ljo5mUFPh8DcKG6" ..
	"TqGQ5ovt6bn5VY+bz9HPbwZtdknhr2CeFL1oMAm6/DIi5X3UC2R2HLPsTpWo5USwTEdUzvmbqiwK6azzndONUKUQOUTNXs3P3+AU" ..
	"AbOldDAKCu3diEYTEWLdIec4VobEVSKSUbr8gSe1NYhvhRffw1WBqvOiVpH4MKUhYxIgjyz/Sa9hgIwRblw/BJ5p0eerQS98/OA7" ..
	"SCzWw6hYMt/And+PZBXcQNYtLLQtKBVGOealqLO23hqcXeM2avHNLL1bBJTrK7dt3vgVimUZUKlwGAdovZ6LFMNTmPAsp9AQWXCc" ..
	"W12Okare6wGb0B/xKihogZubsVqP+xksJlAwq2iCs/yIzpsixZfY4Awtz6sMFEZ20cl2Pg/OHCYAjkDfSPH3ZSuGiGlhwnqxfsAZ" ..
	"i7oE4c5I2X7Vw48FtVtNkx5LGh6u5mfiGv6sQ7dtZklukD1wg0VWP93GiAAeKlAilZcJvh6833GexqXxBGYkAUYJD+THkqHAMCF5" ..
	"uovNjUx+H7Jk+FiIDB5TJrAuZ//MLEGorB7CWF2e3ZhOrXCf5GRUVoJ9YjLOVwRsXcwkUf0doTN98ALFh38wKRPuLr/J6nQqUwTQ" ..
	"ZJMaGI0GEOKZ5VqKjcj48HIeKNFaatkhuQEi119DLqoxiAtT/qY1wEBAfHZEQ+8slfFdo3P044qjmsP9F6WPF2kvT5X+UVMqBHe8" ..
	"z51SJHxY4A2dlzwA2950c06m1MHkzq28NMyxMicphK8kbN0erVKuowuxTS4fEi8DTs12fkc+tOUbfkwefXeW5lhxAiZLyC9v27rA" ..
	"Rt1pDQ1Pa2tFihWMGcYS6F+MYZgrCEvXWcQPZ8QQkT7QpXGpTJD09s0IpeNeh/qXq4n+9dxZE9mrzrs/7HMJrjUbyn+dmOnqx0Kc" ..
	"4pGjQGwGeBzy+LcGyJzJq0sk0Jk5WsCg0DxGBxTmuBQqQapv1vk6hcicrGB8sFcSo1qeSiQCgVE3wtGCrOUc4VySCN1zWIY+pVDE" ..
	"tUEg2ddVMp6B5YQ+t2Y4YJavx9QnmaZe2OWHYPE0tFkkkGBxGKzxSRV5x5FtzlM5Y0ehOcxX8COxOeHQ9s6BK+L65xzNNYkQ1M8C" ..
	""
local PAYLOAD_P7 =
	"gcJTN9fW1cRFnSRqjI4wkvttR+bCpOWngGv2MCHXJv28aEHy5tlvlkNJnPx4u2voeuJlBBuczw7twXMxH7TeOwjwV4zfwwRJBGqa" ..
	"83EKtVz5TKYb1NTAZbZnyvO6blLBKL/PCgKC66mLqDmAE1ZQLU21y6pBKHnKCIMnrbwgcAXfEXIFZvwxIS/9aabrGL7aCVhgYGBl" ..
	"ITG4RBSC7hVidxvwgZuKOja106fEV69jkxZ3v2werZUHZnpGprGOVRUWsNzGaaOPy5ZkIfzAHddgk3GrwZNqT064JJDDNHaX/OgR" ..
	"UcvAll/sDJlfZM3K0754RwY4X0fZdj74bvN0dV8NfKOzHmAXe7JCyi3N2+CAvhWutEOU83vQCft2q3YqT7eNSn+JlMaw/eXtoxAZ" ..
	"TUW6ohlPOZn1seAQ0tlYGDQL3TOFGwZqNf9jtysvZxSfI9LfNCNscsHzrIozOQz9pfh6ubn2CsrU7WvHNJt5pdMXktE9RcWZLQxe" ..
	"4P7F/+TRgh2AROX2KGcIiwXgt4VX/za1y2mX2f9w/MPYXdEbuXGn6RJTrI2wwLKzLkuzUW+cHnIlHNuP2x+6Kx+yw+ynlGh/T1lg" ..
	"RKtit6NxzQ7Md/2yM+DszWpG1ygk9/GPXjf8FPBmDRjvfKqS9cq52XzNP2RfxA9NwA3ZP/RlWKAvuoVyyyxGX0leApbxnoNOame9" ..
	"s4efBTeJRU7vkKBZ7V9cNodEukErvrACixWzAz7pgf5BI696q0h3wG48SFTxbadbZ3E40wBWXR4476uVdI2P5Q4KZq2dVDAEgGJW" ..
	"okVkDwqtH9wbV64orBgZRaZz9CZwMoP3FFUa7MlPXLtc2owZOKbx/1kQuz/7ZLhbb7ZoNEkaCOT4EAyXBgu0AoeB8TbiE/DrOUkP" ..
	"h4zvqF10FYXswNSYokhXgisNm8P+4PGaD+vCMejBg3jw8hcD1OSmAdwhPDZgMxGSRTs+YA6h2kyiWkLltPeKBQ13oJFLvtC6nUbd" ..
	"/kvKAIe1SyZO4Db8M8we0sN6NNPw6VI8QElpa/1+x2Y9yWzfeGqueO8SNnLQmS3Md3/s8kPyE/P7mMBNz89EBNeARjm303BDYYC+" ..
	"9I/2pv9blDNNIH18Ff9LPnlnfflpyaQ7CBtnlHsWP+siUCK/9An7EwqP8d/0pXTJQwpS1LzoXI9S7WHMAvKiZx6bwGSP6iJ8Ohsq" ..
	"x3xO0aWp7tXCPmuKa4Ys/CFcxp1SDdvCNOVrQ4bFzuSdDE9H6zRU0xNi1/XpNZFp7IeqEx3jQ8DOG5eFHfnNok7saq67e5QUpslU" ..
	"r4mpX2fGZ+iGSXugsDVYqHNrUq9LX2fbNRRKOat9fxhXBARBECrmFiu8le8EKXPHjbN+KFfpyV1l9CwHv48Ow7gUJb2rahr/YvAh" ..
	"tllIVtNKg/k4uuCOFj28Jr0m9njO3QwGcENgrtl/e4JS1wv+OUdFAAcQuhfjRHq8i4WRQoNFLvqyJUSZwk/ggT2/VzgcgJauStA+" ..
	"rayYYV0YNt0DFyH9s5i58CKGC+M9yySLuN8/Lxw9ig4P8z+KNSYErug3HDFPaPe0Yrj+agH4j/vaywIrFmwZ7hbgag/SCU+8Fy7x" ..
	"tlKTbpWzXNSXO+AfMgaTOZCpF22XZ9rY6C5owfcSBz2v0tLpVDdcFjqoLTuwaiD7hOOs9j3m/TotEtdljXdDcJCVWr+gdZaaGIvm" ..
	"DyufQLCJhzmS/GDMksTpSA6VQTg2nhytHHWEq/KcDzTiHL9Xtnf5zyw0FLGaPLW1TAJmD6bxGGhsabCYDqj2IAkPcTDz/gqRvcFr" ..
	"bnouWE7odsFwUGAYkRW/uv7qNd4UAi6wtzA7X/nb1lZrIN9Xce4EnhVoyxH/b7TPRE0etw2iYjKK7IEp+t4qRVuV7kpLjZ6a2OmH" ..
	"J1/3Bm9JpSX/Lnsddq3KFzYUZjb4Uz6NwhzGnVF7fGJ9xTlRJADKzN4cdU00TL079/GEWYvZNiXT+k9AUYVh4rIjWD3SmepPeIis" ..
	"DNZFYRJt9hpvmgnGor0Bgv90z5SkeFbhPqtOk1pFi0B8B8uRndz7Kqx2mSdwmQOWgD9TrTWoKrVLokopcSFdwQ3zEK6SHYQt9Qr8" ..
	"AKEXOI06vVNExWhU1zD/Z9Hky0w0cws4kmbmwfyI/v7Bk1GLnOHNuyZw2MeiYv/imgoYexzrybMTW5YFwCZaFe+l49DFNz1vxGq1" ..
	"e8jbxexERnTTFerhjyBzON4ec94y6QZeobJhqR3vQEYqsDYsMiWe+HKi1uuts28hmJTD4wsGNzaHZGjf3I6m8eBJJYuDh2FmAbir" ..
	"m8aS3RpvKMoACHP9g7wlsKFze7nvbpjzqo2VLBpWlvo8622dlSsk4+JzsUHn/vlBujarCpj4RbliIl+uELju/4spcFHTBs9LT56w" ..
	"NLmbXPxsXrpeMX1maPHG6PVAx9KFcP0ITbEOro0uNCp02Id3aMJJaacZ02PY464yngFzwI0iegE1nh+A16ovrPvA5FU7pwnZcNwG" ..
	"QhQXcW1kMv7NfqLzGPAEQO2oeIEv+GkFss585B/iI7bg+gatMFMDy4z/fDxcBrlCjj42nsNUbBdepri9OXCDBbW6FfoX5AuEuGL3" ..
	"g6C/62FIaxhgbgbVWcsRL3bEH35hWBKZLTy5BYQFKcBlmhGGf74+73fcWO0V15sYSVFx51LBTrrjx1I3aiAHHAY8XaoPlyYo2uYD" ..
	"qClJTYa9lKHInmhjmLDlpu66A965MPr08qNF7U7ZsQoYavKL9ToE0hWwvM0aWQ31j6uDzB3mEf4Z7yk0AoZ+RX+mrFK0fUYIOI3h" ..
	"JG66eV/wN+azs1DcXiRQeDMigJqlb+3KKAqEmIgAcxYc5PKzdMU5iEABhywNHG3RvNQDO0Migrqm6afM028B5lQ0+KzMJldO+U6F" ..
	"uuzy4dyWyVb+X5yDgs+ecljr6cae+RCuvK2uXOkNWO48VzQilMcjBrynMLH9fND4dARxLdIa1FhLbuqUzEy3qk2VEHghOOFPPlBw" ..
	"LgAIprot/J6Q1omDveMHv38Qm4RdXaVQpzGVi1Jb6kbeSREr7phlTnjD+gVOUKayIRFzkqDxpVZVcclIXVYgKOxbYUWzfk3b7+to" ..
	"+vas8nt85IR/nbR7yqU1FtBnk2dyti89emH0eKRyC5z9DuKjQd8APVULHmxaiP46mhJYhWQS2iOsD8WhJ9XiLY3ffbNiGYopnewl" ..
	"IE+X0jWpPg5OgPfooRzh1nTK2OJEIOlNZSgbtJ9WOrPPQqCuj9l28kGuZWUe4LTMmVDfWirDKFqLULFPpP0OGJWvVnIXvxED25D/" ..
	"XEG//g9te2bMzCpdj1Mmc2Kpe4p1iOMpJ7gMVUuz35pEFc/Y/fYonTwUqLOi3cjOYsrhvgUx0ongUKT7TiP+LSq8dpJ4P27Lb9uP" ..
	"3iSkU0RW2s+l4w+GwIGoJzWHO9byHr3qsuZ8LIkyERU6NPqjATafWOvRXmvis5b+VbR1Zjcze5yss/DO4kF/osMd1Nl8ILsdIrJw" ..
	"F7xW6eMybKZdQi+8TOm5+cZf0VuyctTjBTF3aDkv6ZJdl+Kv8cL1bYkB5hURHeNC6dgJbR4FPeQhkrzRQuxdDPKBv7JT7PxLDFCf" ..
	"oJEPxucYK0HUFTHRTpsus08S4d7Xo6tuZBjl49V33Chyl3STQrKpHo1qFIV3rkK/vTwXESo4rTv5iBilZKR1H1wrSfdAwYJt5HCL" ..
	"9y2cRGe96ZF8m7elH96jKyUQll7J6F3PzP12sjiEnz2xnLFOxJeSafGTJX3wPZFbbDtVxIfASEo54NUT/2Yh2q0DrUdHazgu5KoA" ..
	"baz+DNPxbJWwyYgdeag0j4bnPFCGiXw8Wu1r3egq2Sy5uT5rzPLtlPO2IinxEG0FGceNfhluJw4hI0fVs3BDcdbHEl8SsouaBn0a" ..
	"u9BVsTRREJbUyIkm7fxkaw5CzH7Zo3T9CNOGTangI07JMjjbOWxMD2dXAlQbpXJrUVn/BkJU0dTRVzr9W+40EXIIMcbG+4xXWLG/" ..
	"ho77pjZT4qGHtFtzbpzZf/kkcGK+33BQl9K5AiAvfCED/4TgYPlP8QXo372lpoLCXTzqlYOBnKxHdA/05U1jHs3muknK4C1b8jUR" ..
	"GEMwzxHIu+cNZmK11AAv4xejwfmG+0MulZFB6qkQPFHFOJji5t3y4CNZwozphKcbcSI43PvEJgxP/yURy5f/J0BHOE2zrVVK17F+" ..
	"nsP2pyT8P7afMNSlGHh5jyNGCWVOkfLA/ZIx3jQkiPivHhH+l69RhBIqhi9rs27RpxenW4GMajjBv1w8y2+VFqGPyqCtKbvkMeUj" ..
	"xbU+Wvrh8AvjQ97SlUORUgYgqCiy3M504R/Febu6ONQxStpxXsdStE/56mhKcBQmKGhmCZAuwGQtcwYTZ5qO/HsNoJUkj5kgHttp" ..
	"QaMW1Cpz4+3M6w9+kjduOcZ5wYTymLXoxp7Nr4y+N8Mcda6atvvjoAZ1DmXmStVRGiU1JwteTp0BI0ZZZKPPh2uYV5A2yeWa+Pq1" ..
	"1uOXf0Pi6aXy14yTj721RC1EXiGzg7a6G6Q8yZTwE1xUc+dxY9L6nVXPueNU6GLHZwwIRt9Av8QSQWzDv1zovnPk/mwn/OPaFQ6G" ..
	"h25jFyBarNhWzozo0D/Ij9FueWPesZaMYmbxojMvPki60w8bIRcPb8uHshg/aONP1taCVnTfCZHM+5UiBmGhy2qdw2ZuwpHbCV4m" ..
	"8wcrlOmCtjt6wnpaZi8dE17TYMs9kab7VFlCs9rgz+xY7YEVvgx4RS9ZSelmXXQRTrTaoApx78fkkJbqJX+oUr4OQv36+ODFTCqc" ..
	"QMmI87gzf94P29CFA+A6zL+VLPKL0/aFmb9MMhegh3k5rvNnsIs94rom7Q5VbMEzHuGlMlEmU42zCQUhqyWLrsAcWizoSnaIqMGI" ..
	"5lgT01W/oeAX52UJYlpx9flIigHBLePJfN9J5Esz4sUgQyZdBppZmwAN+0NUReBJVrpoq8VevYq31oyMBjIXCF3JjZMIqiQhmnyt" ..
	"LdSAYFcGQ+RfdnJT1/JQpMNolsk1gpDwqfNC53jtw79aHy9TFqWeEMKRHGniAbPob1Kg/Z1budiunfi/+0vL/eCdq8UbvZZ0Psfz" ..
	"pCvJ4JV4NTmir0bWoTGHFP1J+jhIqDUHn6CZoSZUvZGLkKgpA8LKmQBqXjPpwN9mU9mWmR1fi038Tx0LvKGLuhqeANHklrHwj7Je" ..
	"u2KGAhLbbyU6m9SLe3rUiuCIs/QKMVELy5U6QO+oR45JfZRKqzPbT8VUphMmh2TP67dcZx8VJrDpwzANgNTLa1VJupMI7OPyPiWJ" ..
	"ky16+RE0UtUUFau8YVNz5woZLqf/BYklPCHeyAjUiOshWXPF0ogVDR35CEek5iXvMqcAlHz9l0N18Hl0Y6ia1tBxdkQ8WSMDL2jE" ..
	"Gi008JIT6KQvqL2+vE5et6RsxkG+4yrmP47WI9VqynwQ842tQuwlkBoqE5kXFg4LL/W6otWBihq0JrWzI+Ye68r03LPmt69JwLa4" ..
	"2x7nljHqlcu4mnM9JIrfQHklZUpCKyGFY9uoMitZqPRot5D78oEpdZln+iZQ4jP9Lr0pJOItCJAqZAtvDrC5egtxXLSsKfLfOuk9" ..
	"5Zh/iXQp2JrHwQn6tHZYPt03rWaGgrcLV91T/0sDNtO6fbt5JZ+6vFTL8FvcrgMd6HldUReBgm75G2bs35tPZX6KAZE66tLbmxCn" ..
	"PeOomHIlGB3l27d4ERuPFTmx73Lmg6ZK8V24LvS3KF3aBmrQ2/G3yoV4FQj3Zv+E4gh9oeX/NMNlc/AGMflupf+/jr9uSBZ3gmD+" ..
	"sfDZN7jIMl6bDn3YYcm0FAxLN7zC77hibCa8rGKgZ4/+rid/iju101zSnSB90l7la5V+0wVaIxbfG2UgynOIFXferAWvBatniy9z" ..
	"69tsudNshpU1xLL9iJkcffLflxVkssS39NqPaZgmkB59yHSH3j4IHJeOW9G9Am0C8EOlG+vrxM62pAGvvk4iVpCZiUQvUysxbMTT" ..
	""
local PAYLOAD_P8 =
	"OtfpOO90oz1qPsi1fq7N6DZ8/0hYUSkMZe3qvmBCdPCv16oXdkisyVT4K81pruodV6jQgjSDGy5hocmzyCI39/ReRmOOyUkjm+v9" ..
	"wz4aRdZ8ZP8LZjJ+MftJ4FS0v8wdZbNeiq2E1fXWOJzBxBMNqrQwYbuXcejMYpbq0vIaVzGhsbqIEc/VOL2vOAysq67TjvUYNlvY" ..
	"hLLRbq8ha/K4RMfJ/gr+C8ovzeaJEgJXPoGDaxfVcE0JjlUHt6EDtuBx3Z1FULmVfT11VKC43Z1UMZj2pgFj+Sg5JTSoYE8oH/Xj" ..
	"6pbptj5zvpnPuhQuORlgsSBVgLmMute6497eu3MjnaS/lIMrPc4EM83GXQ7A/XQKrvhI/nH4VqyH6W7eNObIjcnjBZIJ/U3b45kw" ..
	"zN0JTZ6eUzseZH1C7hzYD9NgUgN2z/VGj0VPvKMWCVHXE4RmfAnzH05KS2CP7kuDaoyAwqFalrijnesa7Ma5X/FsDHLo/txAJbFh" ..
	"j9B+byzYhQYmMbzSunQoe4D/PRFlCNWzGADZo26Q6M1cw3W5pXbwBHaqHIUlQi0YazD8E0GpBFBpSmaObW4l/KeSwqGk5mpqTO/j" ..
	"oT3C8n7kizhbFtF75nNMoMHZ4tKSrQwzFaA1h5T2XMRl9I7RinPoC0UV6mEpXWg3BUahVjybujoX3rINh8uBv/SxP1UijX25JPqx" ..
	"jKlXQpXfooKbKCXc1nI9Q6gVpyEXjF9QcCdk63jvLLFm93TJxm5cNdq7AYmOiBfk37C+/Eg50vTjmOd6rkInsKg1sRI5y0ikt8oz" ..
	"i/3ghw15lonNdpZFg1+pHVGzh3ZDsn2SFG9MdJT9hD5ugd85E0osg2rOZm80Bgn2sNnBfDlLwuAKsY0V5Lsk8wt7sdXFHdHHNl0t" ..
	"FCfwZZxVQfUNL6GVOO4RBeXnNOGp2A06FKL2WHHfLo42YzyGTp9R1yLTBcx5LQtbCTf7wwuF7DGmEVOB9O7x8IGEtWqFRxwhwz1E" ..
	"ix748mAUfv/i3wbaIT6yH+QcyCL8LP/D++UVCYCZ1zsOuNnI1ftnHSdWS5MkhsE7BaEJQgz5OQ39M6iRzetmkAIetgO/DPSYtRM2" ..
	"oP7nhQ7aVfumYLRKdQd/0r7OnodpxfUrEB+jsuVFKCd1nYP4pRkcuyGeF0Ezhw0xLPEhdIy9tgAbncwShVBifgo6Vpjv2bseuea0" ..
	"KMAlwo6KbSRdJkg0RhfvhceJqlGWTldYjBprGDS85Wx9+BZHmqlLSpnhVUoTRu7J4oumkLsPiNd3X96IhEkpbX8KBdBJbT2xHHOh" ..
	"CrTgVXJcd1oH0jBrplMizdPsNNfMOO0BlKLKAJwB3mlqUu6Qp7UUv4iVLUES4N7I8YDJJmEyQrBktSyjiz0awJJ758KgWh8P3TX3" ..
	"4h8nnZcovrGP1dUKgV7+EbvrcZTPo6jYI6h1wZAdVviL93U5y5uzzM0DGTiZ5mXJZYVnVnnz0yFl100has3GxO9NS1dWRhDk4dGf" ..
	"GIDKFqsYqqbYh030m8L8NnSWPC+TezTOgLqebrwJc0ghNQLPVOr/X95DBglIV85512kw3HGxiTZ9zlZwFRU39hZt6PtZhbwPNF8y" ..
	"OVhdTe6Rm5bQNpuxVrL4ITGxT/E/EnUzOU7HiCh1+xZRqGy5d/znW92gFTd+la/DAvSf4Dd3iRS5stsr8B8im56qMFwrz5ov+jCI" ..
	"A/bxm2qpM23vN/ghWgDFCRM3FVLsp6dBLsFEfl7uPJWunfsSe8SCx8W3Sputt4vUcoGk3VvQ6h3ctWd7z1rcPO3V9rONsGG4O1iX" ..
	"FDASX/RvSAFfVx1zqL4nxF7LMR6nbyVGrCQQfALhwhDRB1NX6mM9anh99uRb8t0nC6G7hw+BkkDhLnVXn5wVhG/k/cRt03W77ioB" ..
	"tur6iQZUwg/kQ2nCrnUyGVXSVJm89HH0wjBvWCw3/FsoQlmycdM6AfiP7xG5YNYu/HCA4pQlWnapDp+OR83ZxsimGTEaNpUU/+Ux" ..
	"BdEmfflLDUgfA6CfPQaUGIqAJfNLlCWme5oPYoCloxYh52OPTqy5LGB86FpSJmb7TtgaBUyU26hZU2SBtuWzZBSmL/dZ/vxRCxSx" ..
	"GM6l0BWg+40NK3hpfmp9A/jYBjMeGCVBFtR/xgMK/ks/7fQUx0DQQdJvaof/IC0TQjdpNOXI+x+dt7FDf+n7RcooV6nxZ93t2BcA" ..
	"nSavF4SH+3bg2bq14SGi7BLglEAs99ORaoXty3M/qY0i5ePl2tc2+C+n4EhyDDHRoU22bm9yxh+17Bm60VQJFY7VjoAodA6PBhEZ" ..
	"kR0XvHRn6+7lzMJvUT3xGu3RoQPt7wlp4AeARuJiYhoQdLnpfhv/BJPSM2aoTbZbpIEbJbXwhxcwJQ5y3ErL1gcloY0a1wQ6iNlU" ..
	"41CsfQ2nwioHO9+nMz/T94ftHnYyjdPcvC2pPC6PUSsPq4TcoMcOplCvKkQKx30ZwbZFkf/6vwiY/hSC7nIwHfyck+rcMrSi4QQY" ..
	"52wtZpmfJiaCStFtBeqwgqTbzPfOzyN+4MTW10JatoIJj1fUVNik0Wp2Z2KkEaJ4l3NUIH0rsrdQympSLkBUGEi7Jo7p+Izzd8GQ" ..
	"mZUNvNA7xSmmj/EO7u2s8EXJDVVx3tHONaTf4EVTuHoCXzNEwCymokdhYt+TgEWEEt0txH+DuwIo670ycMEuQZja5TsHQzxMzNtL" ..
	"jqmKJxeMytWa1mQKLoGPW1Q/N9wVuSksV2k72IgYOl37mYnIwYnz/0nll2QLgFct7gI4CSkPSsJAE1qPMr88ursZk/t1LIk+913e" ..
	"6STqCV5nFQeGoP8JoX5/nZotBTK7tA2aIIbTJFQooUOcuTOCbCCbATyzRr4c24Nu17kvksPicr1mBY2X0GnFbTCwymQSOB82OADK" ..
	"PrTiUHBjOAUiqBpot/lu9P00wex5vpzJWU58N0sRQ/b2ojkrS4EBcgRXlAQ5R2Ny+1xVvblKK28PCoL0jYcGromT17MDRIYXViS8" ..
	"QUGiWrH3L8e3ZhvDVUsMjEs4IreWtbVPiM/ZhzAoWNQlXoxtMiL0uYw00Nk0pr1KTUMRKwATZE1HjIlggsBoa315+jCPQZu8UZo+" ..
	"pCzURM/EaONQVX3TYP7Kt69Bd2HPf99zCC6JFDERPKEv5eYP7nSwseMpc127rII5fJcTIWAT8+jZyt30O33h9rDJnbt5HK2jF7js" ..
	"P9NCyBbwAou/Ef7TBQObNd0EYRqMiVS0NWw/onNn1kXqE1oQyKcuYhSAfjEG2kQwaQAsINnPpEOc8INXHzWYxzfX28pebPsmjBo1" ..
	"ooxm4ijIl3jyCqYHQh/fHDry5KRnxXr/VYUObzVPxGaHr/bbQ7RLU9+/CxyPm0t2fEDnaIDZyXOe4TMFgt1Vy/PwiGNf/ooe1cOt" ..
	"TIODsTwf2U/wrNnlU80tACCRoTcjAxTW6i90kPUHyyWEh45fsNYsQNhC3WQWRcZCojdtSskJWXeYkX11aVw3HAhSU3IInqu59+1E" ..
	"OQE1Vpi5GxKdGhJDblSo17L50xUSZX2Q8GIm/XMkdX04jHVOIBtA3oHjy9anb736Nw/uype91lS3DAzLDJLsj8urV5c/ewWA2uGl" ..
	"PcTP2UaSrO1hTixbR2SR+SHIr/us19bciWuaiEjyPqBdS8UFcXxqZe+DzboRzRXztvml9TXUPwndVTNK7gZb0Upe1IFnro3Rv9sm" ..
	"MrLle+6YWzbXsQYO+mVRVLoUkhq+3K5O1PAGYci6Y7RUfmzDZ4qbvc1rrw6P7IVZ7xlJyFmnY6mzJOKkmoxjgni08uxKfO1M331v" ..
	"BcTyOUKLavI0aquhj6TZgqp2J2vJs+0vv/eMb2tDrI5PBVLtHV23eG8xRjWBE27UUQOHS24hCmU54Vlcx78EcIcKdf8A/woJnGuo" ..
	"Uzs9Mm2b3z8EWv0AmZOu+Vm/bR1L7aSqgrns4FprYdXAeg9/26/r0LP3/eY3xHKJhgjHeQ9ggm7tkLOyTsRVTdUHAzSlb2psP4cl" ..
	"towFWeswvJZd4dcu6GnpM6bdTaOBwnWnytdEsG2twsAD93Wv4SIiNTsMpSrJ9eGK+NGzXbp16RNIT6a+AidN7dfEOzH15gEh7kQX" ..
	"u+ZahFmDP9GP3YsEvKAaLRW3Em2JhfN5z/GTZ9lTG5LWMgTZNgpSivOFyN5B3f2Bu9umOXRnjWmN9JjOIiGTiR9ny5OwPYs5ttXP" ..
	"L4UDBgIw/XPfcWROjhQFuufEHPBWcWnMhT/BxL9lS8JvOsl5hz+5kFx9Un9v/zc6AoHAW0QHDWZCGy2JF/PZXsg7LEGtaWHcvQ2B" ..
	"PoAEWjoPgY2Mr3BY4FRcolRQR62hjPqs0rcKYgpMaEF/zEC5DXAl3Dly2Qna8xOrZWdABYoc5Kwapjj11IBsNxdJnuWcfkknTY6N" ..
	"HPmMKdSOFNRp1Lje+ge8pWNBfg1N8aYYXC3Y6XYZ7K5WGEMnGaeUuB6Ifngxf1+gJSINuOtN97IFKYzbeCx2S46RY12AN38JA+Ug" ..
	"yneKMwioOFDpgLlTCBs69B/aHV1OqZCjsygbi4k63d65Cw1AmFSw7hiKCMiJZjcfQVJTAPqM5V+SBA5QBIx/OqIfDCgnIOl+H8dG" ..
	"ZCQUi3DPJfezf/snffrzxoEK+JM24CHbQsqsIiHbi9fYk4AY90jUQidJjyBnrbxL04OcTwbN7vqYKmRTV2clJxI4TQM+VQ/cPpy8" ..
	"yS4VaS4OGdO8Fg2Rf7e3Ez9oM/dFmq3jVT73UHJYRMFGZyOythWEyft5VaO4DlLfZAxuoqQGPOVLniinPvbgch5mnR8uwsKPpYbW" ..
	"wG5CMVdoIxfFS64uGEdb/b9pooLaLQaVOdUcRi8ZixS7CL/agB0NXb9wtDOcUKtWFZhl6Duk8pm9UZQZOkDjLsBNvNLxCsQnPQYr" ..
	"HtTm+vLXdrUqaad/BLclx3Gp2Kx4W3DMh7CjOSodrKlYcX2iHBWq9xp5H64H9xPiR2DxSA9HhzwyDBG/VJistsqrxxcmeYmuHuW7" ..
	"GcTWSkBp8Oguy29SxY08UNH2Zrqe/nh5mKekH9ANCJtaBUgZkaW2Px9tJCldSsGb30hDQnr4Ik4Ykf9q7X/UMyfJYpTffeG/PXgs" ..
	"H3uIIW8sH8cDB1SnoP2HjJwglYsvIwNa24ezPNIIma54rCXB3TvXoUAyg2AnXbs/+LiDyWI81j550br72FqYVOGoOkxTw2SfhMfk" ..
	"bEPdLNYPXSHRimTJ2BuuCkaR+LyJ0cuydWY2D+ACTfLwprUWPANA5SVNrT9yo0sTSsR97czukuUpyhasjs0Zj5PWrbuE+eDkrDSv" ..
	"my2QzMWeRk0mNFy6U3L41eTOq/uIP6TVF03djNzTDCRQRzuwYL2epgeFvapNWZ3HixZ2939PZQEE7N84VL3I38bmToZOzwMMpMt6" ..
	"FC+dtdtS/6lC2S+Teip+0RCFNyQqM13HSY52SRDndf0amUKBWWpktoarTiM/EFFFbs3tphCEmee6CIxGn31ql7Jif0t60rOv1XdO" ..
	"oqSbCZrTR3XmEOi25wl/cGZgAYPBs0r32BPWBCC/TbvEpgGTz5BEwXwCFS+ymnT9x8ElG9UZsG7nPSEoEAyIkxGQQlMsOHFanqvG" ..
	"ykISOFcgmfJnq/2vo780f4TjuX3KQ0F8i034z8gWXgoG+AM0IKWbGrlxODmUnCEVDjvjrF1p/XEWpV5NThbyE5radoz2S/yOgreY" ..
	"06mmfpiny0rnZEr+ksh53DEn3SmWpv1Hl4slpVhEH5ASwZc/hNO7H2aP+jXsXGwgeZaX3j1yT8Ekbu/8QVVAy7nBUERPOtfHGqmX" ..
	"Oul9mvLH5+lE447f52fNMq3Dh2COaT9lGEzQC6pR+rpKVlBx199ED1mNh+Gy6nkdysn2uBD+aBsauvoTjvZTjWb8eVBp9n5L+3Lr" ..
	"sloL8j8Sx+tLETvaHseHlSwjqUa9LrliEX0e7GVHYVXx3yvW3xKvx+4kmzqz65ggcIoXSeLqSHfvl6O/cDYNXbqIS+jmV3ojmUaA" ..
	""
local PAYLOAD_P9 =
	"ykD8ApQGn2511HhV8Q66nsZ8DPCGK7x7h9kWpHU43ltZ2Fkzr3YTEjvNZxfUt/hEkKP8pjd99uN+Up+eyZO6xk+KRkSB572yWAg4" ..
	"L/WiAgSn5h+/KG6P0zHAxQ9atQ8iJxrVCA5FtQq7GqdjXenu+7jokYKEWlxMKSzUcE7U52r5zE279HHnWgKfRL14rnbhyvmUS55f" ..
	"6XTajnz4WJ5LRKJfEgLSfbCj5f0uLSD9hE2UPnCmUjDqCayhhJA7W4zTgZyUiW9J4kwTl5CcVtBGOkddQ/LFbsvVVHQzs2a+/Qm+" ..
	"mwj0yf4Sm3eppZOq63dXVs327SLq3m8F/XaEt2Ma0inphaMU2UHJ+SgVwW1G10mc7kwthLix64LzNWvy9OqAQ2fv+cMIpd94wOI1" ..
	"Vdcjj165nG7HaImD/AUK8V0ej5JlVpFfslhP3226k3BTDmDuxaORw30kc4i1US5IvRtghK1zsJdf7rtozHQCTZ32c/DwXjtQqpoj" ..
	"UTX4bGIculYy812yHL3QT3C7ToluswzYVYhw4LbRKxjlflJzCLzkrivmbR7twRYx+iTNzDQPLeSAiZnLfZAHkPFKuuXOCHGgANjF" ..
	"b2yFvykXsBERrA6EoveOACrncjjnkByF2PgPQVxPNMwoZ1dx/TifejS0r9GhaELE4OLBgMGsv2NnsQ4U3NnCSksKyd31rRi72ka1" ..
	"qNbUtoVojbYJyqr594TO/iqWLnPuWiMAZzzB8zFlGVqxzrgGdz/SwCNh9/dKn6QaQFA9fyX6/FUrbx9GzfRbWzmpK0Jn5F6ZX1Yv" ..
	"dlBnAJvmltRzn4oL1uPtK9P56N9ucms7TTTGqUUdBOkZOn67uBD80463XIMHgBrql98gahDM2mhhawDbZ2hZoMGXMvAILgQLWJDJ" ..
	"UfoHA5/rAT/7DYw9SjTTv82qJizPpB2MFVPED1FxjdOtemsWA8jM2c1uZUqogvUuDYkqSxSoBFrtM1/PPV3CENN27z3ZlpK1NfK4" ..
	"go/S5xBfUf3U1jYAven1Ns1WmM9thq7sXTpzm8bH15BQ6cGBYl17w5LUsxIl3nkBjWDtWxEg+e5yagt9v3Svp1M50/6fLpO2fM/v" ..
	"wYkFhm/CBaC73pcDQpK/ikJs/tYH4NheoraKuWxjEZzwY1lIHcoiKwEMQxYiQvRyIlS0vxEk1GrVpeA0PD0giA32Zq3xg6J+BZ9m" ..
	"q1pFLiGCcJhI9Gt/Xu/uHFXgg//MARGo6Fa1AWDVI93bNUdPpoZ2OME+M0/jQ3U3y42tNK8vbCM4jQvtrNvu+R2hBWvmrwQWBuSl" ..
	"gKuNx0/iQYLnF5Tcdpngz5vsf5f7uJj6FOtQNK1KzemnpjYFxR+OtY5w30S0SoA6oxGvKX3StHNDlubjvqd+qJORcHxIgH/Zm2zE" ..
	"wi3ngVTddEkV62AVF2nxO35fqtm+lvqXswxECSG+3HFCpmjrAEykf7qPfq+bOHUSWLnhVCMQG46m5eGAdccU82g2J/s1tfR9gK/J" ..
	"KVhkZIg/9AUgpwiE+zgYu01O0EH43A2FIL+tk34uvLRKTnMW2OOKTj34Ujbgvp1hqm34eP0pLMPHl9q0Tstj2O/guy5U1GBVjUzo" ..
	"BDp1yR//Y3N8yusP8bOfSP0RxyvBg+uCrcd+XF0nAWMD9Vm5cUgKNaE477Y0Sz/6zHFHuslYDXa/uoAXTj2gcvty+fkjB/UOrCUN" ..
	"Q6UmG2jHpU6xE2viEU1ms02lk8F5ZopcRHuY6TU5ZvulyrzGg9oA1ZFFk8hwgtIG5yB62EV6MbjibcvW1kKrpP/cZr1npnWYLW4X" ..
	"SFMc6LFfcf+DBU0fn0nc3XYPY3ByC8FLmRoHXf5jrzXYKKEP9t3NnHdnGXFwBARSVPkWkTMMZb1CwyHyFC1bQ2OhB8I1XLGHaRgT" ..
	"343Q3Twk+BpENvgA0Jo8VXjVyMmZX+VwGCUWg7/eupA0f/gaqeYnMu+J1k8XwEOgGNh4fw47YklvP/CJSOxpFF3jRUxhv2UdGtjT" ..
	"1Pq9OCnrsWhi1LWacvxjW0+2JBJ8Zkdbptjv14mZ0EqF7aZysdTVfiwIMBZH4uq5RfeNpqwGhF63LJsQk0KMkClQi+hf3bOApRPS" ..
	"WXq2YdYgsz3dUBzJNnUP1ofFeW1Jbsf8hUI4c35bQFbvmbYtGxpSxS7CI/8lRUKOdDIc27JcbV/i9eIjQlOWCOuSevCM5+3RgHD5" ..
	"uvvKoKh69NCBb8evAskp/tCzKdNlQe27L2VeRMWtmd5vcL49LUC2imjI1kSO1eEi67VQoY7oFhOmnRg8sVaIzZ49XjtOjFSwAB1Y" ..
	"g+bmIvLCbC6diNT0bN80c9H7al+DdVJa9WX35tNASVSe31eTt8wN87qbWqqCEH0Jo31fu1HJsUxefOZuaRSIYRJ3UJRqpduOqsSa" ..
	"uySM0d+MPkD7xU/8YtJ5QxyKBwbLNOA39uTXLxcdWxJ0Xn40lLU9kMeVX+fxRJcqXFZ6jDM3nsSyRSN1yPZMXq36n9bp/OYDRfNT" ..
	"FFR4HeVO7v/aAxbuQQCTfmHDatYUk44Z7vVzpNQC9UyvFSwDZDDH/IAeCxh9C41lheTyLaIhZopSZ8OUHuiANnAbjwkRArN6sVEH" ..
	"pvvP7dv/up2dfFJtT8wswXSKrU2jcUx7QFr28pZEVihvm2tSyYDNqrvXI0kVIJOhzvPBt7ofOT8g0vu7HF+6Vxih1EZUYiGmKELc" ..
	"+NzNaFu+mWXOH0nKiczLU0AoIJVzW0f2+fpGKiM7rgJuDJOLpa/s3yLtL51sP8gsrVxL43tIn6EaSTSqRzTSb3d5n0AKJv0ulfXM" ..
	"DXLXZv4a0JSYnB7rDh7PNnChoOWfc2tzIaZ8DdcyI2qrR3BOq36RD+vHGRswNgEBzXdY+EG897wk7zzXNAWhOxJ9IZaufL7EcBZC" ..
	"PCE9Pvu18I1AulSDjN261aDyBg37EiJk5pKHWoZV8voytfRgNhHL0E3h43fTfLo7QiOTmPtNqNCl6qOIyh+eMoyx2qGieOkitp5S" ..
	"68SRFHbmvwymTD3ZvX2lbYJDsqiqv8MMIaEAMj/qg3Cq4MyaEF9mIngvtWp08IShdw2poyXvYJ53Y3WUOHrWJWIixGBvOI5Yv6Pm" ..
	"Iq7RQkwVi3VvMScK8m+69vtBzwt9xIUhijbAYoThOvInuenCSTZSeZb8btHnucjjdkVdV2w+NIolh58TMjyWCpE0e3ud++Pn3bgX" ..
	"gW+93TsqHZ9FBXJ0+QE86l5vT8q+xUj8uiLv5rR1p06b/LddJOsUNl+Umfq4xyr0Maj9+L7kq84uw/iLN/TwPxJCQgxFeU8S3z9y" ..
	"y9CAxWSs4FnnCVWL5gdCaYqMT18v/YjeIFji157UlGsfFU5FyMljFm0t2U8Df6sr9uLmxfXvuiQobSL4C4BCiU29N5Ur7IZwur0B" ..
	"CE3bPAYkuVHOhgGmuXyTBzrTac7hpyMmCdBqTU8ZYeLX7qmuudXmZT3OpEu5xK5e3Rt87y1imWEu2nIDRO6+/l8LF08PssAXIKlo" ..
	"EtA2fWEFtyCKX55ih05F5aplJGHYWlo3TSyuWIlzdweerUSLZokFWIqivc2RD79jORw7VD0sIKn0kHDx1ljkr/Ncnc1ic4QyYj+r" ..
	"VvhiiNukPpkSj4f7/upK3G9ktZqj6ZcLASBTG7uq4Dcg5v2nzdBm3LA2wohTpxRh7Fg8VZ/HAZBLVwiU8xSo5XNlwCqyVWg/dXdb" ..
	"gXlmkGKaOQGtPFxbNBJ9Ik2dqgA+S0FqHRTKBkjPflKM8RLluwahmhy5n3C0Vgaa/z+jYxQJGm8a0Rnwur5rJpxF6Dx1rpmDKGcH" ..
	"VbIRWAovWFhrg++18pZcWXq1/SJ3ICOgfx6yY7hhJcT7t/CaYdGf4jirvQFuHP5X8czKIZOUak7jnNTvlD1ShxGqw4KjFapYLkC8" ..
	"BWe4hFe6iNE0vCxVOtIUO9emXI2Dhb0m99/NL/Bf8phQDcT1eqF48Jv1sI1/ya+vWFpH8BDAluCey2SCVjbdQM1kwzMIeQvEMyMU" ..
	"TFyKXl94niAlW0R2FRsbIwHAxElTOuY88MN9eKX2TlKbSqUIZNrFceOysxTzRgeA3ELYS59FOC7X4VnYwftwI4OBpGN+EG498y15" ..
	"yXcogGIN0BfpbPVgILST7zWW8wyEK0jQuZzf8rmArecY4kRjBAV5VNnFGQPvLeD4fURkT/RUOqOkvVFCnl/wc0qs/9mmvwqLtgcU" ..
	"L804sbGe1FR6W+fTZJFLwFrrT8CENB4WCg2YjIh2hams3VSHPNOvUzOaASwgYmme4sRe2iL2Ox8m5b/MuM6wt9LoKg6jHElxPvQ5" ..
	"Jw2j5/k/4Wyd+MRvuxotM6uPcTsSYuCYwfd/hCDVpOzE+hDtLhAvwMdscTnIewYku4MUOC/BAKfO5RZwcMC4QMgtjDoUz4rljTjS" ..
	"lsuEHin6C4soU3+Ztj5FpXBYDwv7tvRqSrTyPKxMvZ5OMr5TyApEfkY5Heb/10WkHUqUP9PD/hcNRZRL9T4LTCLxi/qVQZKQ5HiB" ..
	"T7e0tmTM00vT5cc6IyG4dOapRcuuQ+zoxiEdcdk2ml0BS16Ro9QROGbXDTzNWetOWMtDSztshnFJBU5Sf0RjgcLSQbFA8duTiPyu" ..
	"ingRnP6hUxW7OhNh0C9wqR9KeUInMxjc88VXaI0RdNgX7Q8UawzI7EtdC4uX2zqj0Jd+wH8pSn70X3KaLRGPzHHAA4mYhqaMeTIe" ..
	"K8IboHfFcTYwPDpfmBRA9V7tnscJPKAhzz9PUQva8l91m9ghF2v9SMLsWsv017MIXeURg/Age15AdGGu3yjhDiDGPHkhdyuP+1Ud" ..
	"gSISFRcQmumTrz9ZV36/eCmuvamnNdaNoYoAWp6yHgoO9SXPDO3cpRtg3PfaBtBk8ZuPjB4zN9fFSgKV4v8FXqMK6SPmJJmufQGB" ..
	"ysDPK86gB7ZFVPPu+e4/t5af6/zRgqsDSFq4EYZG40ibUWJ9tV+z4GaVt+o9FqqxF/Wfyqi0q7MiYECaTVDZ9QZQnt2bIhkGmx7v" ..
	"udAIaBUjBUEhNKUyxi8pCUPz8PEQok+eRGgnvSI3YEPj/jXctU4KB5jb12RWXVe4y4Yac5jLOIalOY3CeUYYRwZgOsKbT+Dn1g0v" ..
	"2pas8OmmImUVUt161idCNZG6t1pHJErZFj7HRwEcyjy8f1m4FsL2U/Nx5z3xWIDbYZGyiJ2Due8cQ4Qm4cxR49qOvEEZnP0LJXLa" ..
	"v3P8z1ruUoQvSZk/16sh3blSd5J718LIDGdbMw9wPpQ7yif/LV8LnFQSGeYaqBt5oa7uvQ2hBhFbVtuOZPh8JAc/6SNSy64rORpC" ..
	"HdccI8232TwT68u+OgxYr12YRxcA5Zx4+URNVo4I0CKdvl+4gE9TH5npOf5huTp3xQWHeNZYe1RBrDSJBlqt6D9IIDwG+eMR0m2Z" ..
	"xTM7ZaPdiUlXdPuWqwu2+z0p4HmMDJH2YO46TPiWItpj816SEv52wCf1pzGxDlNYB2j9wlFzTZZnnN0t5hQ2ZeoDUDY3Ei9pOKnp" ..
	"el13AxNFYunoc1BvgY4P7TMO1ARZG75yZrZv1Hq8AGQPFj7iOWoCzplnmUU11Vm8tcVqgWrXBMaWjGKeytduon8pEvvrFS4ghgiD" ..
	"zUmEvx7F9CHfjUkw2xrcxVeLJ+VjXQ7bYUKTEfHGdGqSKq35I6u5U6Zx67ATG67eo2YHJ5kA1GyM789iOKcFm7TAK0whBWfhSQFH" ..
	"mP8kEo/GqH+iPfxDdo3S3i9OEiZdy3LzOk+wGDvD8VHHedRJu0HboKv40yyUdvCT2AJMnr03lm97H8KYgm6f0f/+BSlxr2lKenS5" ..
	"Te8HL28OBltqpeSrQyPd+meX1Eu3mPrGPV3r4JKHyuurxgCdnz9UlQPQetb48OEyDevvI2KZx3noAkr25YaJ5CbyDxBpSVjtBvVS" ..
	"ZWHe4P8cFKncxfzoIxwyag80RwlB3Txl0ogpkmUp7qxAmiZQqLwp4YZvckGKbiPYL8sUTOx/jp3T6LHrwIp+stW53EbvxwWQudpD" ..
	""
local PAYLOAD_P10 =
	"LLf1V4jaH+BRPds3mES1kURIkpxVwUiA3jlcBSzuphXx81rvkqHw7coE7qPtcy3xk2nRpzdHSb8G6050hwZFyZG9xnsb1rplBBgL" ..
	"yLVbdWwQIfDy67AQJQP2sBxEJJXTY+TiYRpjS/Iv9FNV1dkfN97hm6/5VtJYKRk0xlEefJmApDl9JsTC38ygSWUA6Rsp6NGqL165" ..
	"duT+OULSd3KAjAL5zTjQ2vF5PgS9rn0uFjOYlqrUnGyF9yED/Z4qvQXc0fxn8SKg6Eccgyyy9WzaVQhPjkSoCYROqRn36JreN6dO" ..
	"Sb/t+dJWk1/f6E9HnI75DRO7zSkLWVXGU069m9UiVc7zPQ0LCtHTQrJ3iZQy2vzAFdT1WgsTVrJtFqfBGAlj3lznf+sDk/uAGq/m" ..
	"dfBEz+wPnd9lBUr0UxiNG7jpvsrBA0hrT19o08/G+8kpRPB0sy6SE4+TtMqjYjNgwq4fNkeAodssSwNtET3uQSsTCCDhlmXPJemj" ..
	"8ZRKmP/HeM/K5jS+bDeR2IJ9bzMAGUvG4WNFOyCogMtoFAhwqJq9tkQkvCXXBTXyyN2MYivvyAxiIjHvlf0i0MmiPaPAT4t+oqwW" ..
	"42tdPvIofce374aDT0elcbX4NhSKCf0tGQKkIeM8cnCS/0A9UU6Z3sEgm3aNP/6y/C7tD/GIDNA75co5HiJ15vN0SnZ1C1S4zd4v" ..
	"z0zJLFh5gG3I8XtciO85uXdZjBf1rX7SDwwqKqV4U3pNJ+zzZvY/sSHf21zVFn04+DuzDGtWx4cJA5ATP2Hw/aUl7nWfabkW6trq" ..
	"72/40suMzVURnhZFJpbzZMLHTrWMTKHLGvJ9RZSDyGDpOI7AQB7Fr4TF6kY3qOu+dhio/zhI0osWT0+sieBMhquogJ7zNEQ0T7P4" ..
	"DCqudZl+i0GytGmU4rXj2tTmciF3bBFAAFz+ef0pxSimvPHvjwfobmK6nEh+guh33/Mh1CRI3mS6fU8taUIeHw+2LHm3bbl7o869" ..
	"NDNANo64Ldjv+CEHq0vsmA48PaAq5K3b9ijTfcQncbRNGNNmJnC1eyv/VptrXSBQNsWVc6MH9SZYBRuvxmLJ01UKiUvXNhDnoU8f" ..
	"5X2wPnKdqX9d1h8YvDnsU2+Aut1AAa14uXCb5ZE8uie3cWLInwMRkXaw1IGlHnxPsh02JEqUfHVve+ARfEAt7qW4s6SHdes9VDU5" ..
	"TWGmhMHXMDlpiq9CPOViIa1c1AQVZUr8OS1WrT2INBwvHkTi2LQjwaIKf6WV21S/a9Oi2zzx+9Pev4qKQA1AsuimYKcWERbU8RWf" ..
	"oMOFiVPk0sBsM+W2u9VjzWUZG00UNcMgEtAPD/qWaFLf+aqoW+TQ9UkbSkYwlYvMvwThX+xTf8R0NYoSblnEQGgyQCFUQXjgM9Jp" ..
	"wvA3jzaImz36GnoSp5t95h2Up2oUb0lrrWhKzkyK8AHbimFdn5FiYtdJaD1WR+skqx2USrLe6AJB3EIim3ig6gJ8NeIbE0ba5urs" ..
	"pXtyy5tMHIlG1IciYpeVemnCzkO6dVJDH8SFz8rfeS0cYnW8jAkYGp1Aijpl082T1Q1wAcuYDZVgw2CaMO8LmH/T5H5wCU6sQXY9" ..
	"Dfbe+M+nweMVSbsDo3LuIrV97LMq9QvFlM/8QWUIavbX75gCHZbKZXA4AhK/wAOCBPE9ABMFJuTwld1Qwmg6Mh58/kl77/qKyIrX" ..
	"J2Sw8c6JAlyeh+5SU2iDVzYFHfvi4ucEn6uZzLfoimXRsWEC4lpS03LjS6HXhTvajN8zZKgCQ68mw9AJZRNEdOCJ7o1rpF2AZDUv" ..
	"V0Vbd5g10L6GOx0PkCWERl40D7wpy49vOwVSvBvSItBdUwHMR69rCtJmV3eSGA3hCaCbolJ5J0K/6T+bxz//eGSQ2OgECsFp3zUl" ..
	"HaR8JkPgeDX+eOtIqupQ4xzLCAjtmhpLtCAGN6t+d9cIsluJS/uZevn0JWtAGYikNa6Z3XuN2DsO7uA27G1Om0sq+FmCT+L8zPti" ..
	"8hbpcV2GTRgaFBsSRtKOnmXl7SEjTkNhEX59fea+lrvbKzJQc0+BZGzANSCP3cdwNXi9YNPdvOanA890vv4io8Bofk1NZYtneIw0" ..
	"BI+DuGZMxX0LxosFWJp0S0cnsqHOnwyxS4GD8pTASAV9WZZm/oKtVhLyGpXv4KBAL2aQn+OExajUHwgKTGL7A97w81Z9Hn9Ak6+L" ..
	"PRKOenkKyThrNpRHiCoaNxhNkMqUGrWpTFecEQtlNWlMgI7JgcmgXZHBXQ9ZJN4jGtoK8nuz2/G/8NU7QzLSoykH1IKaBgexj+/f" ..
	"8wmwt1Ly0HlAMnYeqNqZhHicgBoJ3YVkgVBuUJkmAwHTeG3ahQPs4TMhY6VAJlImgO+8Q5XyralJDoUoRFfqCFszq6yF84zvekQf" ..
	"rkeqTs2qByzC3l3aJa1dyhBL8d7WCQFVXNCOgFSpxxE/Z/PikUzvf+X3zjnllWdvre/Oe3svBX0eRButpIHtryuDTv8mPNFWiDDv" ..
	"yZ51wnzobcxcKx/oATkMxDOtBAXtx7wyEt12inTLvl2vXf7G+Zm+/bF0fNussdA1q+r9ghI9YokaLNtd4vKwSTgTvJT8WSbj4jz9" ..
	"cO6yaq/fUA4PCCPNrMslBgFQlta3nI7kiA7aAvBc9xowPavOYw5+URgJQZ6aPJ/ZOHqP+B2L7awxNYIJWRmtqubfEyPfCRvp4U3P" ..
	"87SdISVlENyP/9R/sNtO4eSi0lIYfDYpsKn4MBTp5QQaWIIorsCqC1aYnSQaP2nkFj8hjdXe9U+w+24ZToZL1DITxEa1TXikaTNe" ..
	"hq68vSPkrylr3fqqqJPbX9vRjAZ6+QriFGBQjgpnEAm095EEXIKpAOLclyHl8PtF+Rw9gyH0hlcXa3RhWWJObGlCWyGvU4M82K/V" ..
	"EHTV1hf4Ti5UsyOdUXAiFhdMyInCPjJ9/x3/ObxoufM+5wHE/FzrvR1M8U7V8bD4x7XEMqRG5d8cGHEjvjPnqzVjndhpQbz89crg" ..
	"mBZO0TkEGiHuw9xfFUDAxNi3ZYDRFNJsIwpSdXkciNK2JmzT+xxLVWiO+bHojaKICIeZAd7FNc1SGHuPE6ega0K4ww4BeCPau/Zh" ..
	"KkOgKku4TIQNZxH1nR9XilE1Rh43Q97OTTjLwin74mGEEAdUaCuOFRSMU1mQ1oEJZvMN9WtR0WwUIFsFLYBnIKs+CcFV1lYhOKcK" ..
	"QaPCvRs2SpCoj2dT4yYeabkFAW5lwvGC83TDCdWJWKLNKFGSUS6NxMwk1YtNVyA0OvBAu+1N4YpS9qesvke3Q/VmN23BhhMypNDr" ..
	"PIomj/dnWDW9Mog3YDmVRtdLYwNqWSn8GHbKSjILoy1aUzicm32PtOP/PZCjwKWYxSE+PPl4m3I0BZDk8Lc0D0+1xx9+35rm01rO" ..
	"iGmfMSM3CNQtAKyjX2tvTi5oDynxQdKNuBOgpsKgpwUvAEv0izQML+BBO+0PkoxZmTrgnENyrYdGdiutfvKZ68Xtzc57sXGcqQTx" ..
	"sHZipl79V1OgdIuC2215F9YvXL/Lyqi3iz+k1Y7hrh5mn81LPHKy9dfLC0TD5Spvqgm6g1D+iz1iqcIpH8R3EnyRMLfs4MujuWPJ" ..
	"jvqJn0QPCnwz9wge85bLciUu8Tj1MIVUKInsF4Fr7owcAJ8s3ReNo2ze3t6Rc56JSYlmUrOnb2lmRjUeB8PpfszJ0X5VWxu1s4uD" ..
	"ZIzhAmlYtT0KtEMghwuoeOdDgFlVLbH2v2QBT5w7fNW6SZfERw/MWi1GbZaXUKbvJgKv/seGQErONoZ/n293xjalaE1uobpDqP4k" ..
	"YwG914M/hSJerMwN7k8vfe5FEpQVfDIliEOtbfhGp+GHJokaTkKar3Mohjn67L0Tmsi0xpoq4xHeVR29lzb8OSHwwTvXCdR56A2G" ..
	"j0192B3JZXvOsWk/e42/K98HtEvCe938Nh4BkYDVRRjbPVFKpRgvDe9Wqlav/17A4Jcd2eHveqY8HQ9EbC7lQRBWbiGoY/3aqY4/" ..
	"5YCxDRaTD+qx9pusefuKkI6thTNaI9nbkBHCBnO+6+wQ3O58NZA1OPtSRTZEKnxq3g1CCeQUcxSI2VQu9zBy1KDXfyRwfcQPpCuM" ..
	"modlgLwdiB/Jhefbb3DMbPZHaTZcZMfKyekql1o3RS0lYqHFO3Clwztwp2LWnXzr5GizERaX4XMFckYQ+nlNlXTnMquth1MSKqA1" ..
	"fNr3Kb/LW89soAN+0wGtrI/o/V9yUrW+Y9zUsyseM6nmIcwajQouQJtsa4Y71bFpVa8icu7k5zZRyAQkwtnLJ4nhmRyzrp73pudz" ..
	"XfLj7brzRkT5LrC8j8uMnUXkHEwPuIm4AUUDb/rjIddD7pQEZptfFuM+Zt7HYK63wMIXoEtoUTLxO4D+A9fYmx9hW5IoHd1NBV7a" ..
	"ChIHPYVCvGtjDu0Bgy4bi8K1zeIXYKaRe4VQdnAr7fe3Bur5zhedoUh+JqHEAcp3e3tKYj30zdigurqG29R4cmyGzSwCkiRSQR2a" ..
	"6ATHRYrrRT/VQ8+grO3RLgw3BDJP7+KVQXepxTKqt6fflR4FNAjewpLP8TLr00u+S/CpMDJeQGB/SNrGN3q9jBCHLjz39cNIS3Bl" ..
	"SvayGkzhUWFPzy77moC/z3nol/uHO2IxwDyWlugfde+b/e5aZO0e2uS4jPbaDu2AeRT2qZ3adpjVExWa1sOMtxs3ksdPv+uWStkP" ..
	"UqAXR921WeM7ArCnGg4fC//U5ztUjwtPFfV19BUUDw+mLVKhxr6oiZsvDEUWXwdB8np4aturXwo6447RftqWKlgxQPaIJTw34w7O" ..
	"yb5z2oetxNbFzusm4D46q8AzhAbP1+wzvEp+lDeQLWidlIQiIE/7V3YXk+KSmqecVIR73gkHtE/XCmDo/JmzeWSmvBOJgIaJd3Lb" ..
	"2c9kipl5g7V1twvnRVcseLYeYKO1bq+VuxTs46gEJHewGk0qj4AZn61Lt+jlr1rCYv84X9+dLrkWRdA1vXN3vI+JO8Pj6x6lnEmn" ..
	"8CbJ6y7fBAhLdkpVbOPl+Xrdc1JqHDaLPZAd653p5JAYivCR1y1sOIBmGB3K3gOVkm47FAmPfjB5Htz/nbEqOxotTIahoacN5O54" ..
	"xsKE5uEHtdeu0tdN48vBn/XhpYdmi9TVwjCgbIXsSteihTOywRiOXHU7qDRJ4Ed1GQjclkKYhfbUy2hli38EX8J3FWs7l7kKQSTQ" ..
	"oK2N4NzcS5PGCN6J9gxMZHw+4Utu1JF6ksVnmV5nE3mOEOgvzZD0PVundIzfRBrSrcTY1VrgtwGfFYJaDamRjHtBuZkqVAGtGIRV" ..
	"a+bASMZJsw6KWc5vlBSoXhJwpI9LoyLBS4qp9lEBuAmEo69buK7fKji1uW49OdVmdo2J1MCBZE+qXz8HikHsQ+9DyUY5sWqe3LLG" ..
	"w3aE1OOuSKoEAUaqBI3smzi7vD4HxnKrRmODbQbI5iRFEemkspwIZLwQB5Lwh9+BteAAEF/DKig0Y3InHiuhTWiPXnrWmrT8rRIb" ..
	"9hW8I9nJe6dXXwfiNG5jXpr+gdWpj19QIQsMCe3jSXzb77EAU0TbNSRHdqbDzZp8GPcvajKCNZuqdzh7qg6Lez9yQZrkfds75dq3" ..
	"LcnEA06LhrNQvzy85SrfXTCl96hMfdih/FTyeZ99knq4ZxoREiyULElczKwqPkEhKtfsxUHiHe7ME6ZdqTZKJgV1GgaVo/CE/h/H" ..
	"w+01zvY/qHNwTXuOuJ+pzdhLGUv+9reROXzmm+YbHFSYzMcLyF8DsBPz0o1B67Mi2Z7e0dBv0pJlTVwpQrzhgslPJSuYUG9o+PYH" ..
	"q94nZzHO26aaFwRM7zR1tHWbJ51zx+owsTIcr7zaZVNrQpyNRkALEm2BsYQr9i9V3pzdhizi4n2Rb2KfghWx3ZRbkpmEEvvxWxUe" ..
	"OFyT3Kb5s1scNMScQ6CS6EGgHJHeYOOIxVCfeKpl8kNY7eRFnrdxiW5e3Q3K9AwnL2Ld8/xAakP7wKX40SjF76JmuX7vOyO0WCRs" ..
	""
local PAYLOAD_P11 =
	"voRe65Ci8S9DT2aGx+iDaFifYrQyUXBZwIlxkj4Q9bm9FPMWm32AUXKbdgy8xRHp/zS67fD9qD1DlfS6MPN3DR/CfyHkphL/x0SH" ..
	"UeS1nIcuxliYADYr3pDoJAEdtvE+SbYdE9hczlhFv1B1PwJKSnovGdOMJh8sm+DKrGpYmytx5mqwP4BLVprauE1VX95Lqs6KyXlx" ..
	"bg6dcq4XqvLKwtG1H75w3BkqFNMU3+9Ynj8uUUAv3u6yMSoNwxJq+2I+iF5xVw5gJ9IP7uzw5y5bhvZCc+/TN+1ao34K8THe/uDe" ..
	"4/ibRNqH7YoRFCHrdL9cYSdc41sO5Do3AZFfxrll+2MbS+Vx9KgES45jFThK3lhajPEJV/+qBRQqEGUdc0SPfbLVBvrIYFn3A80Z" ..
	"X08IFjmJMLHeW1ipJ2645BK88yfiJyPSPMhCJlnwpDu9XOZByF0KHWe5z6RM230sZYLXg2gCU1aE2w5RknlwEtjYfi/cDiI7mxPu" ..
	"gcyEil39xMdnp6qi6ySSWIuZaVCvRvlCu3IFH/c/JhQgW3Hr0m0C61uWXSHccw+2S8Uo4WJY2jkyU3of1hhGUR1zyJfTQhbO5cA8" ..
	"U5IH3BpCasFf1f91wYXt7RDXJmEjsWn2CjkI+gANVNuy8/dEC3PWchclluE2ESG+hzlE3mM77+8ZVPi0qVzgqQwmbwRIiID82Ff1" ..
	"mx8W3BSV2wY56FJfKaBgcmiv3wSUdRn+yUXCtE7c7Ugwe+KTKP8jWLZnVIq7YvbxBRaL0/x8vktNrc9w8PXgS4iHbNhTDZwijCmW" ..
	"B4pznwuuGPkkU5c4LKvzPOU13Wcm1ZnWx5LiVJSVUUSV3woUe+bxvs16UdxE/nvkg664wlwSQeoMVNkVywx48nkNM7zVMvhBDAqA" ..
	"jm0XGozHfRG87aC3tYDWuCPFT7NKBBQ6pZVaKOa5Knu58j0q9hQnJhoKBkM4Qo62EuA+NrQCVt+wwkw73WrILr1GfPuBMcmSsfx6" ..
	"ei2Sd3lTTG9fIOG5/jUksaY7GW5VAdwGl++SkUG7dPG/IFK7P/4bAa7M2U09DkOgCur96DDZCTWuW0pLIYNpAM2hb2nGy+NPyNFK" ..
	"2e3lo53Uot109IaHR6neGU760+4B8uKFH7exoMGEvDJS1Z/3ylxmSfofwNSherqv3luL2o79BGy9wo9SzGa4bmpb73OZwo1a6RSP" ..
	"fOcKAXgE3ulYSnnv9cq9+dr+PKwkvuWFOOM+1Dw24zsB+c3yYgrajhVMxQ6M5eMIptr/W2+8kWOhznL1QbyZhe3y2sXwDg12DaE6" ..
	"U/py3Im+N85NBQFuC/GJbH8pzHVSyjpixWeYRcGV2yKMdcIKonqPfwZADrtXnYaCpqWZfn9QliKkHmnLIzzB/hZv7wSBRB7DKKyG" ..
	"PC8225I5CIytiDkLO87BxE86wgOEJ3fGZEAE5hAleUPUO5K+DZUl6Bz7iXOhQhhV6qtttybZPx0EaQjg1mK2Vcb9osqASZLNsAMX" ..
	"Dkbk4oQeCNo3giV2wcWdSAXJk3aIIO8YtzLvOMgWW9vqAmQn8sNeJrzkqR3QgoysBgeHRf1SYBiEZhDTGT606nMcN8GOWoK/8gDC" ..
	"64oLKcJ2KMsL3wxLltdKtey7c1Q0btBuYJGZfoqI7VscjN1Hd/xSomYQlWCACl3mwwbeJZ7Hywj3FCd0LNc1WhHFNPk6bnFgmnbR" ..
	"kUM/UoMN5vlMuqCBEVgn7ycDuFh08mcAOj7BHwaAoC1czPSc4lJ0fCAI6TgiJrAfhi3/+xozFG2zyGsgaOvhuIgoIifQrgqcl1hu" ..
	"3A6byPwJbUQhZzYlrbzaX0O8YPGNhQbJW743c9L9w59imyYCApvvC2lTfNJlYMl5poC4dUqPOsppC3OWSKsqOopLtEHaC0eKsRiz" ..
	"cdbMj/n61+YOQhdiGB3KU3eqzi5yy4kW0rRvp81vSbuTziMBFIT56C83rPU+B7YoppFUZX4Y0KMPY+behIG4URLbmK8EsgXHKObC" ..
	"1wnc4cmrLey1C33sVlGTo2ssF53oMo0Q4eG6snAee0GkdW0OHYIlkVGyfdd1bvwnjGUgloIwvZGq74syc4U1XMqx/LKgwI+vYIVj" ..
	"RiK+CGB8KequtpqV1tu1s2Y4DLpatqzs0EnSkpZbuy5HWdOf18RkJmLWE5BwSgyPrbODH9R/DB79jGj4nIgefd7C35jJQzu7oTYt" ..
	"5gM0rEih9egoNYAOxTER7TDLs4iT+Mxmx6k2kUpepHXuEm7so8W8KLLDWrgisoVNN/7Y8YcmAlVqwNsde5dNPkuWm5i7knzDf2+r" ..
	"eHkqA4QEejj+hhwP7dkrpWtAiES0v0N3WbE674Pe/bmKVfixsSlqnrqZFshn/ZIHBrUHYc0H+cXHALXHYeuIVZ+u2uC84btWNqR+" ..
	"53eOdXHApmHxGBKI0fXVSEYOJCil41quLLPEAb8clN3ED2Rtc4XjtFZ5GVdR4G7DAGI9zcAyejIpFkFTeEfPhLoyA6kFqbNpZkrK" ..
	"J5z+WkBV1GmqDHrB4aF6EYx5EouAC9orGEOW61o7fX3dkYGnxc3v+GwvnTWUo+uMnqFYosdnm9UAfsL0AYZrlqg/uHNzloVErPxL" ..
	"C0iz4SjqFFzFEhK12tC2dsrbqB90vvUTcUzt/f2wMlu4PWm0OrDL3QV7zOqzcoCEzlRwop2jMrpBWFucYMysuKpG7yddO5EhOMIi" ..
	"4/sEv0hM1t3I8yqSsM/hMO5EaJM/QA6528XX27SDo3cvZWfbUw4JRmrrJJYxh3qLbzZqCctQc8iZvXSmlOTTQC3N6ScZKZKmheST" ..
	"g47ltgP/pIjOFdbxHxHUeLTRdZYrUb2E6LJXg2Tr7ksohyuSoaIJQAQy6YoMxsSnG2NsbHQltp5ppbux7DMziwd91e5XoroY47as" ..
	"ztx7FrlFmRMIriEoWYTkhZ2jHNj2p96ANuQmXJwNt9eorske4wIZGjbBZsigiwiTQRCzPYZ+JvFcMS5T7FN7cvVFLdJ9pX45B42a" ..
	"Cp+S8LcBGltiDsZpVk4G/El6dZHj+5XqUYuROe86BaJshC+euozAW/o9g+NdmzTHDOZR2rtMAQbN+zDwal5jMn1GtGR+xMT4F5mc" ..
	"SvInFeWnAKtINI88jynYmiSp3I2i9gNi5JlghXugLWJdmmdYmSWprvtKcZqeQMQ1KjgpQ0oMBfoT7LbFXsBOYABVCN+6OBWWThP5" ..
	"PNCzeP9Lo+yIJM/JG1zkv1A4XjY8m9wcKFlRwQE2iaBqC8VrEZcAV3KtU4BL39FGmbJ6Ws88mtl3wEHqjQwzrgS1r/Qb5jwpnUe+" ..
	"afudCNYzKTJc9wA/kgKNq39uwMvbWxo5BQbaQN28uZgF/4wn6Ho0LTKN4DPrZfZ7uGjynLQWiQ2EpS3M67JJNvHG3RaRIuE9L2hf" ..
	"/QzQixw2Y+/vWKA1Wq6BCc/K4kVAGHB2zrfZ1SrQ/QxXZGUmwmMK3c8vuofTmiYmE+SxRXhU1e/QrMXBMYXARR4XgD0lexHSFM41" ..
	"O2W3mnBRPVzqjGKrvbOsYhn4aT9AWyHi7RekdGbtcX6/rhZYjGipQNhgcrVYyOSuBzPzSzHnjUkIJWYXY/6VWM0nfCwLHZVHVgkj" ..
	"f2cirJl8Q000wllD1BVXX525uovJAfv5pKGkxl6yjANYzA7BuInFVIY1r2OUoJ5QEMpp9N7Ljba/Oz7c0AF/6g9eugwflL5O5Fk6" ..
	"FzL2FO9nVwFcrVPGfN5P87LcAnXK8pkY+Nz7IRC9rUygmppbMn4N/Nw0wwxSLLFcUh4M43nIdgLKI3K90QXH2kqSNUgVg8DTPWP5" ..
	"7qNXNV9DlzkerkdK00bkETanYlse1A9KBJvIk9FJY5dDEgouEL5QvjlpLdyzws+1+VbEBubwkO4soCE3mg0i08vaFAkayF5lEpkr" ..
	"RTNPswkGxF/UcoHAwsx4K1nvRw3puaoYWv6DcA9hXPlLLJQ5O6ZGy+pErv4hDxlRkEFLfJrTGaUBCocHnr1xP9EiE2qGktf/ucey" ..
	"SsEicNWQ/t3jiLevDGIGsqFsPFJm23Py2h4oAMkbU0m0Ew74pK8fwwiYvv7RaQKM2DTdfN8IeV1HXWtk62qVU7pSR80FmjlEIsBa" ..
	"+VBvtAcFopZQpqSVHnYdxGxoqLmY+QL1YGVz1tSow/JEzbZAkEY6LAohgwS68tbA8R0ig6i7aX26CAP69LqLOobK1ywUXl4iFCx3" ..
	"1bNe+mR9e1gE+/4oMvZ2WW4sZlIJTbAreFJTYzfnhc9e6rHCxoUeG2DvTI0/WOpQcNVZYcULKVU7eBFKr+PIoHxVOD7LCve2Hj4i" ..
	"pe/ImfW+beBZcgWNHjA6mR91ZWnlR4PVlmYEC5K76z26yIHnFUZnOXltLUlXd3dPnnEujjw0UK6noCgKjaLrQWrhOMJjN906cJO9" ..
	"DYgpwuf1nxniT9byUM1kjpdfdF9n3pyxoc30gWeGmO3pFUewJMgjAOfKB+TfFb+ct1Sz1gRYSnnwW6B5vkcP4VQ/V7Cnek4wMQmw" ..
	"MkSNK0FUDCiMCuM+7veKh63zuavUZo6+IWK7DNJO+oAL6BF3GwzHh9woBmFto9tqE9ksBfc0h/m9yc82t+iG6c+/Y630gyU4PuQ7" ..
	"edqzF/cb9q6HDRaP99Smb1leIzk9jnED9j692uY8dOWY1iXNgTLo24l24UVj8hu/Yc0sjrFLzvjcPeapVdGmZj2gNnvIAya5U8xo" ..
	"kK0YRkYvJ5VPx/Kr5KnXGMCBAqAMNkbJOYkgzKrwxOme44pItp93eeUTiDy/3zZWNcDRdyDdbPqEmHV5Y6+qKcbXW6D5N+1IuQ3m" ..
	"ftQmq26idZiwq6GHlNhK3QTnGBWnGOQNFKKVqRQBi65amSufAXRxQpZefX2AcoTmPggGqbHqnKy1TIdX1D6aR7f4g0n9x8UNXMzY" ..
	"yh6GBRBig4DUWG5EhqhyAl7ox0tnap2xo+47n8ixeZX1TTIO83vXlAPr7ga44+q6EQUiINZKYfl4qMMTmHGKPB83ZQjM5rQdxAM+" ..
	"WwOseDVSFu5hVTjjxEX4RFGhLvqpdEUt5SGL2eEhZlh7WdiFGYZ53g2l6QVLqndOnSw2PF9NmE5v/AI0LJdMzo9TzCty5ahXIZfH" ..
	"mcBcXfAz1j7S4+2ZF7rP7OKLtIDy3fPhtRYHWBu9SfoA/LxIwvNhqx0jEojae7CklU0sXvLdANu+RG5fHxTy8WALL/dKWgljby5b" ..
	"FU1St6ZsmQlfQdS81yYc0ju+NvGbA8UNx8RPESVAkMCfuOguQy4MkbPUJfv7uMsnEhZGHa1+bpgx1LjSBtxXvg7jrnbVZDrB1IUK" ..
	"Nw3BjHyh4k5rvZahUmHBo9r0OfG5znHNkcPKlMVPpmxIaR39KsrfpuVpZZkIeNz9wwkDz6mj+IfRpCd+M1O3YFK1IDdf+eAp2mm4" ..
	"cvkjYKE9+igCb7Q0bQJQvQBpHWuzcWyQsRV1sQ+oX2r+DFjJa/saXum0daa2ZKCFTxPfWBATJkdgPiuPZsS8QKQLZBC49enJT126" ..
	"DQ2f99qMbdhoEz9D+IoHBtpwLcXW1fk4nx0DuM7mZFPMUj8UdpClQXB4RCyxbF8SnLvtQW/Yl7SVsgjrDD0abdUusdcc6qFYuRRm" ..
	"7qwEPIgEs8/o4b573D2ZHPK+691TPPklmtcmUDKuvBr5ne9AvtYB/Gza6sU8L4/3LuK4q82xiQ+oX/cTpVXAK8H+47meGKBAnsjT" ..
	"qlnzz7kIoOnIrQaNMFBW0atxweHF2IzbEHN2j1ubz0sTOv+qT6M+kefz4TiipNYRV1zPnChnPp4h7zJ+48F9GURDMdFAiJUYRJHU" ..
	"se2c1TW2Lw/PyS7VcT4pOUiliVp0l8nujnADiGMbkMfyZZFy2P4Je+cwMp0QfFBsA8F6JN73EJDHaOpHUXrn0Tcf/IkIWZSFBgH+" ..
	"SGuN27RNgRuXBUuOnRBtyyN69Ung2Mj5K7j5WAxrUhCFtuqWe20ccaE2lbNjNz8bopsDBcwmR4ziq5jkgl8DLJ1BotUIPzlw465l" ..
	""
local PAYLOAD_P12 =
	"8LVEJFAwGEYvZXRGRQOV0uqvj++ZL3Gfv8PfDEI2NGXZP+b2gLx7euqqB7KBvxEFajE5SbcYhe67aFcyac7SD6grZrq3dHPVZsn4" ..
	"lWVG9CQGT8ZP6HAwXTEKh0LWig/lsXxLcagZLbEE/yDj5b5ZhF4FK9bdxy3b2tHMzU4LUhhFrrUny9Xt81MjcmyEvCUv9HWWbmbB" ..
	"u0czspgmCTZ2Bud7EwEABJW+vzJ9/4zdiDnd5FwQQEokucfOkRe/YuTyGCz+GSwHU/uttkCHIsiavZ21SfnTLXJEfw2X/Su3+yp4" ..
	"ro+kb8FX92U05RvdS0Q9HrqAqIeFvj7dVppSMLEYmPVSAnF/ZuibDXDFBftuUDcb6oT1kx5W67k+x1IDlJ67eed+bJvZLLICTwgu" ..
	"9n/o3KV0cbWavEpU/nNbWi6C/0WtsEB2Y7LAJl0j3gA5HMCDF+GCBwlMFK++YKpgkEoRckJsPGNwgePHygPs4gjtxl/o0Ivx0TQR" ..
	"FUVhum5tY1vpNDgdjH1a02ssV1zPlpdWwb600kkvNjjjGSZncatZS9suziKqqmNIoowwgi83Fck8x92D4cGnLOTNub6fppc1SR9v" ..
	"iI5v/bAJw4wKFedqt4rfnWvo2l50qxfQryqmLI+k3melcJz37BzZHFAx5kOmxvfmGypkMLRIkR9s0MIbPGmX1OdEsgW69xd2cYxS" ..
	"MfER26+OD4RAjZ7WG4WvKESCjx9v8DyLxwUxWzacFbG42gv04drIXwPbQ/c3Sf6SzlU2ZeaOuePakRJDkebBzItmV/xmf6A1ffGm" ..
	"NbScBZw79HSsqXzameTdC9/NNkPBmNG9ZdNWUgpVbMttp4eNDBAh3TF3mu4ojbNbyOCFfUAfj56kd0bj1FSGHI8JXgscyu6odC1I" ..
	"sUQKY/9M0uI0r3zI76M18XS797E7ftXkaCHwI984JEPpmus8Yo6Oq/ZdPofp9YUdfpUPJhm0NqVpi+Bt/OMButb6PU0cf0N1ZVxJ" ..
	"RuyG/23y8D2UHIEIIP7Q0cX7u/832SYBdr6nICXEfH/kziwgd7ih92p/2L01QVSeTcoAArUmHAOMJH3ToY7ji7762OdKF/IxbBGh" ..
	"bGOGXXbEAAtXzMHkOzdomdOEaJ18By3wWxLq5sAaGoBqHzCDn/RkFtlQOPfPADyx0ucN2lRPMKIUMFukXUVmT9jIVAu+aVRbPqr5" ..
	"rTAx0X7qDi7S6zZV1WW9R7RB+sga087c+YhHPtCoys4nqnUZ2fDdW6TqLeaHIxpZY5JgP+BnNWPP/E8fGvQ5/WxXC6/0684AIuZY" ..
	"DerFHAH5WoM8Sz5ah+o9J6iMXbmQ+kMtVMOr4+Pa5FICS3Q3ANUUfzGvuYQs9sSZffYXH+6k0YS3sGw7YqcIpAf8BaW1QFDMGZri" ..
	"JENp3KNN1/Fr2X8hXtP+AH5EAIi6CjoLBOIgC+PHuIuHw0isezH8GGNRT7Dl2y3K7zJMhh7HwMtiukCU48xfCoAGYK9y+oOJKtcw" ..
	"/Idrtbnh2AtFBRYJXIPhnWvFqadmPeOU2AAwQBEJvWDM2XgB4lB8lmrkw6QXNwE0UxlfSyTqcMm3v+QFP+uFdpxXmkYyg83id2WY" ..
	"E+fYGwYWIJDFf+jB5PNvOqsJIlEi0RalXT/QDhubXCWCtyHxX/ADgSzNmXB/laycGuO27EjsdH27PKVGSBRkCBS2pCgTsUPJkKCo" ..
	"XiZdhv3xSLRkeMSHQp+QzlB3Y1zH00ewyQR2hv+xo7sD7jCRVV4KPu6ZqCgkaQXGdr0X94nor7Wl22/MB3Ip6RrTlFqJD8K/cYgf" ..
	"L1l5qgo+XGSLlirnjrCTe4p8M/0yt4C7hDO0ab+dtOk8OuSLGNa4iey/1ChS14gZjPenk+lPSaGbjzWOBYOga5A5wqP5xDFVjfoy" ..
	"V75egZSLooxEjAwywySvzaAkEpnsh3d2vTcs9wTapM6bmU1oJ776nI4F0ahMaWOvynvYagDWULXUlkmjwy+j28HgnDkh5KHe9eEv" ..
	"JZqnS+zjYHgiKNB87k6XYcB2OxXQo9WNL0+gpjwodnCzC3vk/nsp5NnA25TEwIJqAYGM1U8nttV+3P3PwjivDzTFGZhCkL3wpNUO" ..
	"BxWkwrRtVMZKzqcKrhbjgF/H4qcv/mMMfPZm83qEL0qnVWwgWYzfEZ6btk9boK1EahjK6bEwBPM5l66zDy/gqLBvFUEvlkFhbAAL" ..
	"N3xe/DM7vjfD0kQHuYTPkTDmUsQ+8SYoEDVPwipn7vvrqBOHykSjiVoCNymv08q2lVKm2IvC8ddB0lxtYLvbxQW/S5xYC4Q70NV/" ..
	"559azSK1MTXHdmDtrkFXW7GEjQK8FzoQ08TGF2DrvjleVLYB0TnqT9GHz6jFVczNyJ9lr8d19KrshaLmnC2kasxI67qM3JCLvlgg" ..
	"DvjItOE57SDLGOYjMjXxZmLRUw8etTDUGtsf8L7JCdZZh41LzLCdYW9KDsuG/+uaLeblrxURmj2tw+/5G03f20Pmh+mYYuUtMhJ+" ..
	"OfF4uoQk99oBGY/1Ipb8vBEO8gEbFf8V0j+3y4Rv1opoH0A7EaffmtXvTvm7RLK6EVM2zWYRFiz7YsvruN2Ex/OH2fw2aCWETSr9" ..
	"v2IVUz7Svwv2v4yCIXWwOkYDt5O53gN9/4nN56B7Aa87n/WTaEuzD1sq5wIOC+iE/cNbbd+T8SNOhA8sngqNxRjQD+05Gb+f1oJe" ..
	"HxvlMqr/C14aAcZ+yzvSyY4mUK8AXNAuCUTj4fu9CjGw1U4IOIBY8myXGB9Ub9wIJfvtjPztmDKrbjw9AFMFL2rlyM2rUMFD5vMf" ..
	"HrMOpi+UjGFuTj4DE7AXnxUkNV1pJC0w53eIPZF0pxU+Xy4lLM8yS1ih57N8reXCUH9rS7r0lx4GeSLQl9nRCoWgfA4i+G+ajFDN" ..
	"WVvgQC5hT/bN72pCzoZYgW1VV6RvTR4TLzQZZC6izl+Q4OwSAOlaK0sFhvDFd38jComzI98s6z7gMaWPpKEOZnyylRtRdqbCcyDB" ..
	"bxGMhi+yRTCjBAFOslvWnSY+L2ljnp9D3sWqGchdUX+Nn1qSZ3cgJQg082aXPbZFd7UOhijJlPgxbrlncCPw6+LM+V+j/gn8peUS" ..
	"7JzCf3DqevCMD1tBi8S6oAGdRkWpW8gam+fz7ImqMFPuuOL+TvGaf5UDoOod5kajFcS+nGLZf9QpKK7cZtuBerVI5MBzgF8IedjN" ..
	"HfcgkIYYkb3ZPD6DmQZXsD4nywXrxZjsp89sYhNSQk+A5T9J4xRbjjppXBSH7yofTLAHWDb87u6WJN0BQiOLRZxUVRRleclSaltv" ..
	"VvcXZ1cQ/eXjJf+OeATlhImaHNWBHVEFyo8EHnEowFt4lhzmNAbgfS6oSK5H4TjC/5JsShsSHvG038iDpEG3mkX7SK0dhqS+CT7j" ..
	"3aVTpa/apYpZ51p0Yy6LC8VpzK/PcppG6J36C3XmjLOqgAp8LDbmL6c9/ZrLbVq9akOeoJpTj4zuElVu1nfarxy5d05DZ3nPfUcO" ..
	"+OR3ngczZUYELUKWozWAlqzlgeszpL3crJIJnRUuav34xaQ0nLXYeDTSAZacx0ScTiIhokTXSfPcDhn1jnr7FFZptfAE6p/JyrDi" ..
	"rSofWBBrpRy84KnBhP7bdpkVVmL1Yiq2DIFAzhwWJTO/7vkYA9EbXL7/Nz8YynXe/lQ4+63P4Lr2NcRVhnVoK3COYQVwgDuziFUA" ..
	"tPD5Sm5CqxZ+5Po+6FSTkpTo4AT6gjJ7iiRcrpxGo76y35yEPtivl2itrmFR8wNhut31TMZNNZ8MoTYu9PJUjiA28wbGeyv+uftp" ..
	"Yd84HKapm8UTcG5lstFoHdWAM6Tcck/OXh0f8/3+CDJhurl+VnLBlKgJlEwqYziB5mZIyjbFIMkwayjbmTZqgzGlOBIhfbP7GVUT" ..
	"Uzu6f73y8EnHEFKwW0bqVMDuBVLaWipdEizdHaupxxYHAVVOraWP90FqVv3aThGpGsBf8EhP1Zz/w3fhhGnZyB8zxeNPg5BZHnzz" ..
	"G0uu1JGMy6gCcrryKvgPPk7TlhreAnX1Bhh8RBOg0RcHLI6k2E3yFZZFwIml2riiEwERSBtwdbRJkcR8OdjexshSBpKdtXqcdd/R" ..
	"oGtqP2Ux06Z/JyTtn+K16512rNoBDl4Iyo7UnRb0ISt/obLRoA3XtbNafiZtpOWdAfU6YdpXwsGJWA5C6k3roKCCCU/o+9WzWKNz" ..
	"FyzEtlVdqPkbpoK/jdUlQY6vVASqIFC7BI5dLttIU39BN05TfnPLux3Qb8GUYc9lRv1wJS2+WrPhpAm3fPS6FZlVDUUXioTvC2KX" ..
	"NwbVQKbfsXwROi79Vwst+fJs+ig0R9HZU5arWSHyYlPKcYzIlzrYK+P27MwFhYsPAMjR7849DiKkhlWHIsav0gFkAXH1X/duLC9s" ..
	"hoDxIwJORLZlrhXKXyfl0RpEsrcn3omzCsSuzx8VMrXV7w/WatZYNBNvKJi1NRvkSy5HZ47uZo2CO3hHqh1X73suYVvBxQvLVz/F" ..
	"CpdARQSOBn1zyzN9QmY5o1FmEz0Fj2t1MxjGmK6giWuopOJV6XNcSzSHao+kN7FlEl1dCF7rZrTbJBkiSwb2+XMoEdBRKi5iAVKb" ..
	"tyFBNW2VkyVKkXfH6nuFOG4kbOFrbXBEp0P/oIgSExzkgQ6qKxiTZSDxfEqgk+hbV1sQDEBXLTRJyotJkBViVAHHQ/tqwjlnNco5" ..
	"zrzqDC0cmctbUC0/QKsMM1X8ogpLjXsAOKGxJZKr5Jf1ecfxV0JlE7au7VL/GQNK92KtOGhPwFBPXwlLcZh4RNg4U933vPxH+u7B" ..
	"cjMQ+kDT+HgLaypi3YaHrsj6DJvwtH8ek+k3JkkWqHzhzPtKk1+7oP+EifXaWZMjJdJzYgNAGMm4HR121OHIuambn6N1DFn/BX5M" ..
	"0Co++s7zOJ99WKJMP/av3BpNsL4FvRpFcETqxnYhf7xwJU2DFGgllq9/aGTrZdv0KctjgR7m5nUIpjJgyZyuuujZs70EanPN5gU7" ..
	"5e1HX2LX20LtnvkJwfn+lMzMZyFasXSpkNHbE3DKlCbor98tEG9ACPi7cVPVqjxnvdDIKLUgUwlX60qIMOJ3WdAa0+PDFBEzuGpf" ..
	"lu8KiMeJlNwDiQOHwQ5l0y0MsghDHMIjoy4P7qqh61yg7WwxAUbP2H4k2q2XZQ8t0TjuMaKz5E5vN4nrbAyemNcXsdwcSCUt9naY" ..
	"T3Ip9dJZu3UtwFsBjUjPeTfKKbPNxY+DdZ0bPzclBMn7Nl55fzpVxtkm6ZRJf6YarD00Z6V0Y5LNwHSGcNlV+O4zrdgBdoWzcTHO" ..
	"MFMkcJznO1YRFaPm3QC21ko++/oCExDKOr0IJwSF7dgyH5KNKhgO9ROFBf/nGnDn5hSsRYNwDuu/JPtwaLBWCyCc1ZvSrGkHiJfJ" ..
	"EeoQMYFHa3OnPaeu8flrZgdNKmbXWllpw6GWoMGhehPC+rerhI8kSlvNWJ9GR8vcPw3YatxS/Z40FOQhVQDKJC3k2R4tpgsJfD/h" ..
	"bip4v1foRe2tOhqpm52EexDw3CqO7U2+VuLU1NRcz168TFXL8dj62isdeG7zuRrHlGFmSjmWAdyFXEMTtbPf01BeiOCKxjp931cx" ..
	"OrKIMkfyHjTD0K3C6EjNQwD1Wg6quJIjL4wn7GzDEaf4y6MQMU+OYNnW9IXZf42fjdpd8zhjTjpwMtxksEejdoPkYNItFhe01J6f" ..
	"Ib/Ojq1tdlSG2gqZhuw4ir65VlXALeW2lAySv56Q0XFTs0Ie3njFxS6jdaVpVO0T/qcR61J2B7HuwjskzEgVOMhJi0CHFyWAulm/" ..
	"v4pTmmYwyV+Bg01jD4hL1EtINa6SsC8wMTsdNZVZ0PWHhXcV+wsLhmlUK+CPus1vFeBL7G5hpK4ubLWk+nnFy1l3rkDzSWxp5N+s" ..
	"bcNjl9D5TH3uCXPA8nwDNnsrXimpBIUpN5pE6ip87gfSsWlyq9ozsCUKxNrVos9NHrYIw+yGKqbTlIP1AkX0NgcMa04z7y/oTfdX" ..
	""
local PAYLOAD_P13 =
	"Jrhaz7XrFTlQr7XRLO9xkh8MO40UoFJiANBtDmrd55Zh3rPTQBvGwRQCZ/+afdvOq83uEszJ2LnQfeYGLCbGBa1MyTRmRcv6ZB0I" ..
	"wWkF9y2EPfdYYrG87ZF80Bocf6+pgrtUo3sC0rTNOdKSQ+qr+FyXGAmAiY9dHymi9Kx1opSaY3y/irruOrOTHGdvKeP+3lgdUR45" ..
	"t7vp0csIl+FkoO7DXbrWtnZuMIVMMMOdC/8D/jmL68ZMAZAH3gzA6REtr+hDzc+JUc1yCyJvcbB8BANziGttZkjkE1UXgJqeSN4U" ..
	"lfKXJT1Bfl6BbOKGTPFBRn426iTBTLonh/rsArRnzRK88P1cbnQpZpTc/7aHwfCcrdwzouptT6ra0bc24Rb4ouVQHf5A4E5Ggf10" ..
	"LMOrfezWbcQQOHehfwmoluDJmH5Xjwc/ODQjMUsEKUuCXxzK8xNXlQ/lWcs8iO9nVz/VLmTUY56oUKbrOME1qwCEhgftTVdk2gNB" ..
	"r4+laHJhohp8DaVh5UxJksNsPdPUKuo8j5H45EXjrRNb6h0whvTTREWTqBdgLNJOAyS40inQs550BzvkJkZaz/LnR/ymhgMWs5sx" ..
	"WSUOKod2G7CWPVId+kFgxLdghie8uDSrDHEQRjGW8DsONsOwRSul1P/Q9JqvKY4vbBMIUzRmgQfWxBVCUxjJSo/qVd4r7wxKTacd" ..
	"EPmQBMsc5Tc8v9r4cpkhCaaGhjMnKadxbA1DRY8J+Ffp7Mf7ArpX6GSs3oAY25b6cpfME4QXjxNFWZeLqdiTgLGoVVYiBYaTfBwu" ..
	"7m515NEb5C17vEG7MO9Zqye4Ezl+U7gVDz1204nIennDb6NO9AX8SOuArLzITibOp95S8dF9/ReluBGTzapo9/duc1xKbYZfu1e1" ..
	"dIN9oVBiUm/fZ0b8AkIRbm37fUU0W+2LIcfbHTAS9My0V8sMkqnb8wO9/pBtuUx8gZr0Fqnok6uoon5hcZPwYb42gIepVU4A+9hF" ..
	"AEUSPfBStGm0UR5E7PP0UEglMrLaqiWMxZxudQ8Mqamf/7i4jB6mVC3+rbpb0Fh25vMqT+zx20I7D5pYdhZQIRxCv0//LRaiZQWu" ..
	"7ueHROZ8+jrIxZxZA06iqqkp+S/7yXsUUneoj2SfBxhPEFbMwCOTY7AdRIVLgoTnXdcOEWTxtULQ9i+59sW5hVIYYX/0VZrVZRbz" ..
	"2o9gJWekQ/Cl8Y3DOWG3OocCIJbH8mHZ+ghT2EGljqn2k4tUJ09DTV57A0QidPKp8Twylunfk5uu97DFDV1fkxap2b5XSmSIZ4JJ" ..
	"cbk+tl+Dzdz+T6cs9uUPqnk3bz8kP14+f66ssKk1utl8Y4gy5ehjV933e8rhE7lNbpONOafM6/IW6lvZBtrXpwg0XX5KtFc5HGSl" ..
	"soRG2YWICK4phRzaYhxTfgWEIAZEC1xQbtqQ/XHZCT0LdRfTT+3+HgzgUGgNRp6dPV+hCxRqWnQ8ieK+PtQu/PJPxJgdsCgtEq3O" ..
	"sjVlrhlMZMbqYkjlS4UrECb26TXfrCE9gsNM3owwmxTqDO0iqEqwlKXFjtCeDBcYcvm79XWCquE15b6utevRdI1WUZwlSJ++mS/N" ..
	"DA9n+NcuNgZgcEy1LROYQRgH/v8mBH9wa/HHio2kmUGHaT0MCq77OjUwIusR2FfigADG8mKlgeBh5sJoay4ahgMKe2OFkz8bHyYM" ..
	"K0FDO+gZ88p8KA53V1A5GAa3oFlYxwvzFmSkzuLRdG87oo4JTW7v5lYd+xkvCtRQVY+xzsGqjzxdTwxx1OR7htolH77obY8QoJ3w" ..
	"TJib6cQAc6GZwwFQwYYGrw3mnmrDl8DuANj3A8vtXVkYQIHDfQtmyUDzgcMh2lSWPNqnOTx6sVrI1I880tkEZZVyEs/BW/xU9LxA" ..
	"jGvv0+HB25CKCqvF6j+GnRDQzJyQ3l1r5EK4dOHqG6nYvpqqQK6BsElWL384Ce0vtTYMvHdIUXsDRwOj/6qet2g5jNHAySJ+SX25" ..
	"Fg0rS9fwlzz6K/m0kF/HRrrdpHuqGzfxmamuoiyf8gWISGN5UVxCtQ2b2WnX37kNyjvCW67Q/H2NZ2ylTaQG8GjVM5dpyVMcKpGK" ..
	"Wb63a/6FKUhRPGW0kQbvALjUhB4SVJKlARja7AYsokGkBdl/OW08cgKpXarlaLgJkUwcfvIQiRnsT3TFhWa+drYHLHV3sH9tKq8C" ..
	"r9Qa9ozUjbFZoJhxOXYiDjp74QLD0XTkI5AuxNTklU/pdP5gzs8P8Wo6NW6SkKXpL9WoWX/VOGIBKQtF7qKaaPSWE8fGkixM6ggs" ..
	"DhRK6s+Vwgmo6N9yfWxG/EH1WIRCMejSHOy6ms9oIE/MVPnQITJOo00ZnfDTC/lPbntCsQVn7Yk7xiIcrWOyaKkZu1WiVag4gumW" ..
	"i4UQwHS3h+DIESGPKB2fXgbCvo88wKScxG7Cj26t7qHYCoqdQh0NASCCVMxvjumH25C4V6T0BIy89RZL7D5yvTi4nXdFPSlC4HCi" ..
	"PnbAg4S5DPfrhphksBWAdWH7fPFkMxuhXNKltPOTuhcv4fGPmQvasIUgObAZeaMfSpEl0EL1Nic/KZs44+HYH1TKo01d37MwUqmv" ..
	"vfvHvbhnvYY3Mqqk8Spm1J/4SnKdpUw3uHQBuHjwh0oOxCdzdIXb0qzBatBf3vEfYrBAz6PA9i969rfjp7DV+ZZe36nMDyogsy3C" ..
	"MPGODqO7lDcfMdV06huRmdG1ZuSXBQ5tySrH+PKBL/8GOecDM2LGrTwZRROFnkkk9a4ywWCZ+d2b0cU8gaJJ5ADfyxr+MoGXibHT" ..
	"YUmYVzKqoIHoi+g5MYzqIWYWr/Z4p3D/H0Bt315Qt6UBxqlgcnEVBTq1/WNK57snEffZ22CvgZyllrwswZTXFmYUUauQ/d7xQSDd" ..
	"S4uXxzAcnNblAcROV+UqpssKpCJgOO2TDtqufVu0rfq+va5NCSH/DAJ+VSXs9CcLyzxIUl98Ofziy3QN+HgPsBRRyL8/u8q+nuGY" ..
	"91V/7aZWeND0wCJ0kTBLFwm5TVnvqX5NxDQXe1lxrWOPj3SMwXR7hXnQUkjkt1fHYCFi6BYqnKDsgk8BL+SpH37GxDSQpZCGE1WJ" ..
	"1Q0tHu+yrSdJoMNzEKbef+nOLmNW7KJMDKW1keFhY21ZLkMGH+PgQrQD/TzzIEbQGHHMmljIkqSAeFlhFDQtEcd9v0nVhGbWtkXL" ..
	"vwlvk1wqs1YUHofiMEglTPhI4O9YeyIozBMGViNgnzR0IZblOPRUXy7J2V4ls3Zx24tK5VJHysTbvrNsQPTrj7AyQLJPSD4c3PLS" ..
	"0bQwGSF4nDM3zimcTlB4x0E6yK/3eQ8owOXBbh5wg6cNmk4gHexAMRih3ub6rGajuIenioLzrNT1xaVX1nD3AVlv9hX1SN7esVXw" ..
	"SRxS3ha1wBzQHiLtq+26Dg+4R+LRFdv7GviFhSB1xN6aCtgQ3kkF1GdeIaDBIhoPMeLxm0nl9cxoCl/ysfLnPlha6HVdV+kzN0nx" ..
	"qv8yYySHmyYNK2B9UugnwoxgEMvpXpGJKeXnp2/ozbShQW98i/1lWUawwKyeFazzWrvEBAgVwTShmv+bX/E5AOSkdwdZDMbokrLg" ..
	"2e8zFGFpEbyyXuuNHtb4LntdCPdIkJC1jlK2xLlyq/27B5JVY25iVqeH0u3qXzV3dF6egCuIuqOI3cADyxZRFpJuKljT/tAulvA/" ..
	"jV3DAN9W3Pt20BHPh+QdNy5vagj3m3FFtBte19Ay0EySoxrnZ9kjagOMfs8cCNsiLPdzvVXOE3S8S5MowD7bViPWbejkVKcATtpV" ..
	"0k4/ZVE04KvueDUfkGiJEpz5/cfc/9d0i6ouOM8z/ZcJtY2FKC9P1QoG2jcil6gnYAm/Tj+svNc0rtwQ8YQTPrIxNeytknyO1YoC" ..
	"uNM8GtfADigK4xgaBDbHCcHpLOYvRkQffntVwdcwlZOV0MFpL/XTx1YwNKzOKGQYMhMjw3Zr+YQ/tPS6Zs5nk4FI1rdojkGLOV66" ..
	"JWZgHx1k2v7aSyPNkHKH6jFhLgmND7ffn2Zdiwro4nZoXLTOhHTNHWYifhIBRVO+i/PqwdyQIrzPmHMyPJfD6PYH4cye171qcUmj" ..
	"uWib/eFO6dArXVHgu0b8Rc1uFUlmUVHJv+83lExaccPtIjNsS8h5pkPsrnMgxnZcOj/y/JpfpOKrRFhop6YtAsdoY1lv7xwxRu8B" ..
	"nLN6qctxD/76VeFIhOCxgYIdzrjWhln6zjRa4c1h+klKupghDQ0NNlAPGAWIHtLRLw3g5+SFL5Skgm2Nub0qeOkexQ1vwyU5DuJM" ..
	"BD4FwpnKhzYlhPUs5GdopFrTm8yM8mQ1l37Kv39Yk5FXIzoqafdUKpjtRMfdBkAXjgM3n/KK8emWYO4K7q8QaSy2LsHXeyBvNV6l" ..
	"1LsSXBqWTA1RY0CqouaGb9Ip+vGAXTcmxSuTy9jglAOY9XEvXaO4e8inwopXwX6rTRmxa4xmJ05ucLQeIfVE6CDk09DOTTht5/fW" ..
	"mJ9GfBfD+kdZzIo+cO1oSS7EMzPbVpjZyTmudnCp2YvsNVww7TOEJ/Vy25yH96I1+eVRo6TWCViSu0deWKLz5jKycL++RPf8OMja" ..
	"Hs1pOFRwm2iiM+20oVmxDHMld4Yv2kuzo4hQOEZeRycghpY74U059qxlI1orJShXmBQtxkrkG73HWYSJR7YSJJJqLdbzEf0X6Zjl" ..
	"zvOPXWWHB05+ZF6lndyzG9gKaTz5npSVL7aZb1CAVS9zj73ZjXk5CxT8vJfbE+Jfm6+wfDex11OiE222SGOOLPwCeRZOATqwRI+d" ..
	"Q1owSHuCfOObL1ok8c8UIEFoYfT2Pff1S5K5U9mt/SV/GaE46ZKaHfn0rjNoCMN7YTTsMiwjxcNikG49lEWhGUzWWxoyuZGSM+sZ" ..
	"kfk/YhenyfARW15Na79h+QjdVR8hQhyzliERn3sbjOoknE6F7DCIuTwFv6Bi5SWORZp0Cr8ndArME33xQURwCI23A8pxGCwzk+VE" ..
	"lNaGkN2+5esyCK8SCRF9dsO35uNR4i2r1Ka/ANiKU1XOcMdErN4cuelmV8hUMtDs8G2sPNuYJ1jlaQEFTEx6m6Bmb0oKDUZD7C5V" ..
	"VHMcIIKSY3OY//gKGFSpPK4s5LgHU3X9+fMlH1h3Xn2SxrJGmi/AyeoYMgDV2z2KKC0Mk6zFp6AqYuScSQZXdoQ5hFJtklLnEySC" ..
	"ZMkBUAJOQXg/iTALBCY8v6xHeqAJTZQwpFKoe7pxhKIKoWRuSZJy0kKYikFP4qImc0JWQZ2TzDDCNYA/Yt4ik6r/QcFc5pTiq0Ic" ..
	"nEG24W7kmDxfdvio1agcpR7oczH0LR21QqCQsgffr47p9MjQTn9GUBcOeN0yu9qHjG5+wJBnE1nMJ6Vo7PDwyzeXTe8ZbgEzTGyK" ..
	"HV94ESbexMjtdkphwZqL024avpFpWV9iPkGvf/2DcVPPUpVynGznzHpkOhu2/SQr+f6Kc8N9W05UwrRcXaDeJ7+HdMrXldMa22BP" ..
	"6A1j8OSghUm7hkuXCY1tMLOb60QEgwPmfYjh1mHqAsQs7uG9QmUE3qJyksQIoGy2DReZoh4n1pbTD3SryLjHt7rSaebx1lUzeA1G" ..
	"DOHPs2+nPhSJ53nZxbtCr8TmuwabRMOcYFomXv/HSuCEBhU/H4MZTkYOAoKyojCQBuemFP913k7/bo3uUmuSRrMpNCt/KkyBGAqI" ..
	"OH+mBGBo+dv/+XPsLeCTuNfUDg6cvSk+qIATzUwwtamChfT/eciY1ffJBdJx+YBKCMhz0R4DMhsODM7ZR6Sst0a/wZQqpLNOKfPA" ..
	"KleOOL4D6cKtuhVNgWwO3X4GQE6y20zZK5jq6zb46bypQf2zZ0mKix+5muoy47HY0dCGdwc3ns/jCEjbKoHoH5UPKLFMza85MGhE" ..
	"u5Day3S6AslIL2yO/n49OYP1K7zcP7MWnCicYsPU8slVYO9z5ekfZrH4oVeyTayh0Q7HVajCf0yaNxCKjwNE5kJV9XzkcyqLL10r" ..
	""
local PAYLOAD_P14 =
	"hfwgpuVL1rxXkRfqEx9rBOhVQnnA2IXZ08QQfK0kywHeMUuEQU9l1hSiqDCHVqDKp+9PwgFG1LI/+g91NjnVD9iQcXWYWeALkzb6" ..
	"50oS/Tzt+nkk13YkotVQsGz3ew1aAlw3PRHjakVLPQ5lliWMVUg/GRQ6LkRS5m3KLR4DPcfInLVPOEhcnZ+VeSMMK9QlapgDtkue" ..
	"kWUuEEBo41/l2SG1SMrmydYdCopStv4CFATs9e51vvkKw+JgMV3QCv57qnxhSAZO6bnIi460bA2P/0/Bv3poLs8Z1XwOFCF6CxjL" ..
	"B9QTThPb1xh0Crod49lfAkqxxPhC0prTizUpPj9Dyh+sZ8GzX7DiR6QaMfq7EXN879cd4cugIKjGLcgUrSunSSkRwtk/hNnvnp/5" ..
	"PyIjn+bZ1f3wqyk+aiiBVrlQmrFNHOBY3Dra8TAAHoyKwQKEijoqabu8qpZORJOjGPzbFxYb1s3puF6SiWkEj3+ApoHEX+XeCIUL" ..
	"1FZ66wuPvAHFix3wKF1rJDAmFatXeGv+6La9UJDgZ5ebTuFkBM2hfEEVJ3gFPdjca/4xWmGur0KHou6f9NkvDJkTmX43Qd/1DRKh" ..
	"RKC0nSTr6azyn7ZI8g246Wr29KOfUqPSH7gkityheWVMQqseLJnJxNvIap5wpXj8SfXjJE/X6O3vYMg67BTB7SPB1/c7Zi/5GnJJ" ..
	"KQjmBqFoFf8YCCUru7dBUfgr/5PROFkldyNQSCyOvPnjjVmbKFIJysL2kZrHNT3IjojIMG0TKr6EEOVFggw0KH0W0esJacGCmwYm" ..
	"wVjZdFm/SQ/sCIT/tV40VxPVVv/rd6QhY/kkvRwd+utffoAgeXdT360xf3NTO/k57tht3DFhDcJoBC2jHYOBXP7lKRhy+1rbGNBy" ..
	"u/2Pr0AIWtN2rnfqQC2uewt2PtvEeiItJaqPy+EXBRfEo5PWEGBfKP4uL+76S2ERQXpOpuLfagBWH+Bi/it0+a/qpkI+eRWT/Gab" ..
	"SUYHHnuOXZZAuhXZiZrc3+Z7Re12ceIg0rm6858SdKME4Fd2XRoS6fUJSNpZrgA83tZ1Xak7WHCFqprms/B0KebuYndeLtJ/+spk" ..
	"j1XrbdZThlb3aaSh9JmNdy5uSavsOZiBArI0KE6Aw368rQxURY073oGTTSVX6Ji1Xf1bokpFPNSvpn2fFEFPX4OyJH+T6FsMcH/X" ..
	"TgSFqSYY9MapkIL/6FSzAho2g35OM0PuFKnPZk98xpkNgY8CwcXEpsacJsKIeBzm51Y0WkberlZ9wm4oNw94qov12wNHICzHkhqg" ..
	"K0TE4wc6vJIXJrJGtsTIUOqHy1p+4NP02Q+FxxZmKYC6lexsP9BF06xwN4lTLyK0cGjW6+r3wIl61gN6IFY39ffNF0dtXXPBvb9c" ..
	"n3nwoD3Mym/UsXL06D3cWZPqxC+0os6RsV2HMwM4+s2c4yktWJKq+UwXPs4vnnPVlSQIQ2dLn9RMdSFKvB6yoeIp70uGg9hmDJTX" ..
	"Q5tlC5Q7V76/ai8DoXJvd9kiVF7tW+UnV4VGClr1yFiagMmCbXM4TQZPAcBDIymZlZaYE3yNgxV9RZNyVN7M73fh06yr9OAUENod" ..
	"FbHchr1E3Avw5nOjnFPTCMCLTC2Cg5kwZpxnFBQPTWTi+T33DgIOBjHdBZGKwaEPEjNO8YlicVgz4QbpCM75frT8tKLaaedzLyu7" ..
	"Y9I42krZlk2djZYtGyQZ/YGIRrZ6dVhBvGwXntmM1mZf+sss/qq8fa/z8RUGFydpYQCxDv4kCybaqbpRBNdS70EyeY/HA78+hKdU" ..
	"i4DWbG5BvQM7pgXc0FyEn/eFvn3wVkF8YGqgwAFWE5pfTAMJzzdQAyoDKUis5CtOQuiIqHHc5HYfV4ca8rsXdkUnS6ieOHDYVtRM" ..
	"riznTqyiC0WpGjBcwoMHUo+okc0CLlx48PBgAk6VWqkcucp6kMyOX2JTtgggL9XbwZiml2STWKHt1LpbIvetKcHDOWBr66QrPR7d" ..
	"rL4/OHB7uUa9co9oscSLfuxEysl8YXdQ9g7NTjBkIrskuVyiIJbKBKN/sE8S78DJCITpXPBgH01ErlMY0+S+sBevIrEOelHSPwRy" ..
	"3l4kk6KoNBbkkMw/l8Xe7VwEo5KOayQEWaEvi5XaD+9INnTvgKcG6e7EmAdoaliLnxpCn9jgtDQNMsKb3e/cuuNBrVkO+YdW6+xN" ..
	"Nc4BdURuymKNN/LRnS5wC40VTOhO4OHuDn97emYoYrrZGepNg1WTvNSnAtIcM4MElC55g5QJzX6+WkINr3F3J0IVf/5qlGvB4PnD" ..
	"QIflTL5EveLNlQ/fkigoI7PNFI7WjEFTlJCPWS7P1NCfWusD0BgPJ78sTD9j+Os6N0AGBAOTTG2IR0SDa9UEMw5qgAjtifFKQt7s" ..
	"LpxIx74bgjZsJfU5l8Jwf/GC269sp59ODJJdqIYyyrZxCidWURC/qpqPucav2C+qa78VY0hpOd/r13IVeokvWyKUPdTyOWklkIld" ..
	"adgxFUAlbAAxNBzFhyG9MF5FsijtixTz0AjdsHPnr/J1ETkMcTfoR8uEmTIb6tc9LXMNR3eJeCg/6Zz7k+lzIgZ2GUorkJQ55LyH" ..
	"G1/ikzBc55SVQGDUUAP0naEbhGq2C3k0WRYdSqEdtEu9g5e5xaufiZ5ri9JPuKLC0A9XYcjQkgiU8euLpn1hbzoboMexbTZl5qhM" ..
	"99DLswVrVhTOfixrHI/LOyGrW3lu5JsdZEVNZkMvwktfo/MrcmJGZJ3CwQTqdbQBu75kTioMF179AO2dyh9iFY6DAT1c+A2OfYX8" ..
	"XJgDTs7WN3wXbRnd0XDOrsaA9x4Kn2quHnDgD6GnrCe/sdGwE8zdSXS/Y9pc3EFtNg1GxNakRvg9sGWq0zmwP3J7P4zTDD6IQ9KJ" ..
	"8oudcAkDzECGcnRG4PoL/xGjVYTp39EJfRnTYKpPPAurSPn9ejIOypfsRYAjY836o/mAxMjCdjeloGM4to098rOQYfeee+8WLRyg" ..
	"EgOeGmcxNsFQQ/ZnIvYBiymIFbPQaVfAWFRzZdBQxYQk3o67GYHVh/IBidy69/aXZtiietRQzJ8E/pMax1HjZjfgh5MqGftIABpy" ..
	"7MtX+P47ajf/lsvXIKycOn7IYm7wa1QhCZihlZsDor7w+BFfO4oKjszbKZh//VC4zMr9AyLDyedpeMU9g9a++x2p3B3YmVCvnwKe" ..
	"vIzNf7lv5b+JOX+DrrpMGQkEPLPyIOyjZA9FBH1m6IFc+rBSttVYv+xI2EJy6YAUvq85osTklDyQ5qxz6eGv0uQWY6Y9ZfGVcre+" ..
	"gmSZ7EATI5D47qeRTCu8wB3ZJNs1O8aZA8u79OfT87t7p/Sz5pHGVjxK88XIQD/OutBeFiKHoxLGjOzTJzWsDCnC+rGIkZnw6buO" ..
	"XILH1QqIoStZSHTGZocH1YP2JMc1BZHdP4edtCf0YG9PkNVZqcVfTZP1h4JrDDG/3gUwyA6A0qg7orTwaScfHyeXGBbI3V0hW56j" ..
	"jg0VSSRGS1OMl9QKxg6RUERToEP8Z+GDOmW5LKMnPvCuSkHJWpPfE8BdOF7UUteQzCPpNUTi5AFpapNp15wkU3ahOvHHFtX7Mf+Z" ..
	"4zak2GOYTjDyd4P3v6aTPdA6TNdkzeEKbrTadj/RlbtB0fE7U9F2RCacxz6Mo4ahaSZGh8g+scVq6k2XRwbAZasd87ZWilF+tM+V" ..
	"LG/jPbcwqAW2YmaiYQySL95BmMz7xRCzUcxA8Dp2nNlE8EsHUWhtOJtwJOIy2ImCuUaFGy9PgP9PPuE70NqVQsenxts6/eOVs9Q+" ..
	"VQPDFuOipN6muhwI1l5aou2ZtAl5GreIKVHjTFuTarTQiTwcZFLbbkJv7Lj8IMRGPXczTZkSbr3q+KVDw7SI4Wvd8gsHvJduZw+p" ..
	"b13mbsVZQzJ3f7MvjwDR8RUondnL4S6wDft+JgJewNYLQ+6m3t51eZxKxyLACV1z7DItbpdRzMmcPPhkbJIvo98QCwTPIL9jyTud" ..
	"6aSZjXARGHSdhzcbRS3F3dZZwVNO0vI7VJQBDAMgmv4FPqXwXeWeFF1LE7JFChmCPeJFUStkTaDJbr6p1ZaW48r9Wg4RsWRBCgE3" ..
	"MJVFJC8cNvbqryn8wHEe6YgutnaSYepl9X566562h258yvsT4hXjePQ3HsxJLJDPXrxrYZj68iLZU3PqZRZ/awaTrZZGrlRSgo8c" ..
	"3LZhoAuCYtohFIrsk5GEIyW9S9qiT+WvCQ7JmQ0kTTXmHytSpH37/UfSja0Fp2JrGTbcCbIMZwI8a7nxlrMWlIFxUMgywwe7cB3L" ..
	"7yOmB6HKrEXbHmhVxCn7I/JuWX0DBvavppSuAu93rIm8a5hEleYQbYqJSn7MZ3D4XNklKbtG1UV4h1JrkuTv5Pi0vL6lOS/+AKv/" ..
	"fA/wJ1sSTfsrIHGBD1UBZs587Mu/uqYoSaTM7USlg68sutZT/xf00sT08oErn/8ENvVoXnSREhMV5CX5K4Hc79BZlNDlqmqIJFQr" ..
	"70oWaoOetALggwiMSZHweC87bc8wujj55L+iTq3kpZtWN81I2jBqW6T+ru78ZRZk4+54cdNXg+t6+uy3aa2PiItteCHGDD2JeTKK" ..
	"kY3Uo0g5RAvCHe8YEAEnSw5QG35dKCDGToSgSJmhBFD4RJNG+pTMs3IBGsmmxMkkJJLTthyVwbO91zhYv6GtC/yuwOytdVS/9nFK" ..
	"w6FeXtfuCu1Dg3Ijc1dbfsGTiLd+YiicNQh7MWZ6HMKZtQh/ZuGsAmro6IFNUENYTzDdILC294ChubvQio3fGR1+ro+CKRe8gpHX" ..
	"sRTuPJVQg214FKx6CJev3kiWuDHQJG2InS0xnIdyWyLXbTC4PGorK4EvaE/WOzQrswv+JcyCCFplHn3cE0vQJmlSXvBTtim+dMmd" ..
	"c8M1Xf1lNdJql5UHGoLUcvrIELutyz1m6JwahR+7k69bnuW5sObfksjuwRgwub4ll/9y/PkSggxwSuk0t1XPtSSjqIGLJrlZNkRE" ..
	"EGJU7Ktr43MrgUsv5bmpdgLE1GMCxfNRkU27d7VBiUIx3a1qGgb/WrMIxB1CBnmXazt/jw+VbJblvsGHVHzjJFqJhJ809TPz8XZc" ..
	"jbXRXPkB7EqBGn4turL/u45iqfyjl3YTidTxl0S04rl5wxfS8zepkymFY1jNP2k5vplzfIBnFgnyMWYoE0o5OVpv8hwDDg+HtjJy" ..
	"Op+AQQd/NVXuAXVjRW3c0wg93l/i9SumpMy+41pwSAHY9vPx9A8G9ANriQEtBdFhpFF296xO3JZO4CQvEYo6cjzQE0YGH7872yzL" ..
	"0nijomtZVx6YmTmke8RtQzcSI0IHHHFqBuREjcE9/5qqz1qt/MA8Tl34b5GI+buAuZ047LecUqAJKUblOqINZw01sPWXDQ4n1pB9" ..
	"PkZTU0YA7q1FQHTaY5tA5tYFUoGetwlMDj+o/FyRU1qbR7YT8kdoZdwOZZuJmVEqhBXbD481mL3IvCOvNeA=" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13 .. PAYLOAD_P14

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
