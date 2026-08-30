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
	{ seed = 1943382937, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 1940769679, exp = 0, plan = 0, hwid = {} },
	{ seed = 1940172778, exp = 1788089514, plan = 1, hwid = {} }
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
	"+EIP2DLlwYd4w0vI0JBmlP1dyeOshbA40OxKOfX6paI4b6w7EnJlViCVWm0r+H7ikJmIkxn9YqqCnuNdEck7nNa8O1CvPPDaz35F" ..
	"Gd26v++bTyPkIiZbsVsNq+VxvfTbB94Ygb322mgnK85lkUs3tm4K80MtfSBZjdFPevnzwoReCzMYABYdu3G3xuGD13Y/VD6p5RBz" ..
	"RqgC63XzsEymclPWFktRaG724HY3geSsd6RO4L2NtET0JtG5so+cPATVdyUMLqwtnycgDP2Jm2/9mqHxEFYMjeg6xxfwkBGR3UyN" ..
	"ZI3wDSzkcHtg27NjZXALsz86QamCZQamwJPYKay4sVUB2DtV/+MCTSRdTg3Y9OdPuQAZrn1YE4+wV7XSDNtf3LH90G9nrVLgeQw+" ..
	"Nlv9dkFOCrVgg/QyByzrWPYFDL9ljh8WLwzxvR6bkxgm6rdFSWDPHD7KpAxqEmPisv5qC12fu8iAMjLkZrebp2tJQ94yGE/O6Dq3" ..
	"qSCXdwjaGqE5HFrpGJ6l/gcs6U8dGOF2KxvrxP7XWdVYSpY7woaCTWVKU6ySLfEy11a1gdmBCv6wryWGPM7UlnOgjzHkDSTh23Qb" ..
	"Uwsr2cr0YmyhnWQqqWMHj57EoA0LCgVyLK/nItwvmzU+rI3rBtJ08UjsrxkDAzLUHU1KMEW8udyrBTRpkgah+qCx68mINif0tVPw" ..
	"PUPxGH4oZz9uUVvlA/mT0rH1XB6YlcQTbA4+LyQWcCMuVOlgebh9yTKXoAieb1Ugs7Mzx+d6z3SY2/Cja/A0h8sb4pPIDRJqhTJx" ..
	"ENbRFql/swPxYy/hGST+XX1oelW2mUggz9PoVuvvN0xxr/JumyFe2mAG+VjJyRbyRA3eDpwjCx6qke+dbNN+HY2fWPvO5wsl5HaH" ..
	"mlxHfHST665SUEzZq2rUrD7TP2RGOuAbnVMygr7sb7l2ZGTyo9EaA+nfOyS37A2Q/+EfPtjtEUh9UElk44QDhLbaWtCAG00f58fo" ..
	"bpvwCG9lkSnU7Ej0Jeqis8U/EXAMKK5p1MY6bFZ7zLlCnM1GgxrSybK1i9ofxi586ODxYtwv88O4joNeQQ4xi76co7TJIOk8W7B0" ..
	"2Z6zkL7dNcL4Pe+cbA5AT51WjxHaARgiYntstlf9P62Chh/aVjxOX+wvPfQEw4QqJOta9j0tNzHqYAh+auKCILRPFy6d7x7IZemW" ..
	"fqED0MiNyui+qK6+Pys9kKdzA2giU/CP3k+eca+ibCmIY/JAsU8pg8itlnBFPA2y14s27i8vanoRW1DTzBeujgSOyHOs1QAEuUno" ..
	"UH1kSNtz5D8mT+HdxyFjX0F6PQ43cNz/S/fD5xZFOygLEZidp1aNfnatSjItNLKyETkbmxVDpvgDjGQGZinOO3ZuyyuF4eZdU1Ok" ..
	"qvrbTTEFk3H1YHzIJ5vYE5jnX75n1lEhzYLR92/1vZ/1VuKfNOfScE0saYUzIr5kAwVuvlL9/udh8Z0oD+t3HL6aazn7VttAQf7B" ..
	"58siieQvijPMVoD8CRnoqI+Uua/SIFPTiW1R0EIEy15fgs9XHzlWxrNVVkMP4bPgA5bkniEcCiOIzHaw/H7yVcb+aon7OxlyH0ps" ..
	"kevukPyWEvr67BQRVNDCt0h38f3Ny5IQI+MeE84QiD3yvgSJFsHmcpWtoezXHwJACXhL/W315hZv/IVZWbQo+kFv6XUvtdF8mcH3" ..
	"JeqDz9FQpeBWgYMLNaqdIB3mSgBSQzVTFOCN9Nw43y9F/L+jkwK2FAbUe3HEVPt52ihvAliG6v50GiRZHqKzBpqkWeiEHQxPrBoz" ..
	"PbC0LlIPdtbllybnEMNNgNzo7ux86CcIoVBLP+cu8xwVCTSRIhqtQ7olN7SUaWfNy4JzVTxl03zHcm9D7frph0mCsN49K78IH808" ..
	"NA76tB8ZznH0x8Y+jlJpOk5vgvNluejd3/k/ic6Baud2ttLxm07mhZhP/DxTSJ3a1cJ/O5V3JjQUlHJyTfPCDYcNS2/MhIHGa9eB" ..
	"QJnl4V6HEb5m2Ip/ip5LtlvY2DlCUEf2a458G9cEeNJ4AsYNmsUOCswmqo4uymdxop7L4MrmFVKXoVKy9RD62ozMM1oucnz3/xIP" ..
	"K0+Q44tSfJdNYPDzG2Ak16JWRHoR9rsuZBEyJ2bJZ0MRYsA6NCuII+LLOEi0yLp2+rKtrdWhRCZ2GqF7APg9OX9zWVVbpY0Vs9fb" ..
	"DzEHWKVHl8KNNWVpwpEosiA6khYycRxf9YeSCqSDvyf48ozBzq5Fdb3F52rULH7LnijimKwoK8dS8JTBdF3TZA6XTiA9S9t419hh" ..
	"RnRWkOgvowyk6q4ILmXTt/viBhuSYLbzabKY8prfocVh3mwTljWCKG8FWEM3CsKi0Uwm6B0hTcKy3YZHDuWOOS5HvT2YZicM13El" ..
	"YZz2bCCHbXWjF8kzVky4DUv6j3J4LK7Eau4U98k2I7TSGoE5pvGJc2Mx1JMgLUq7Kg5/SuhtoBz59/wQCqoY+gZgPL2Rs39qeA7B" ..
	"ebltf4ZAjwnc5ZDeR5ENdjMeq5n6iVDF+zrsoPrjOEQCVEc9RTaaJBZFRfkW133IQ88k42y6IL4HARrZcTJDas35+AIGAPN7i6kW" ..
	"ooHbCnUPGPApcBcbzYfYAwW4BvkAVlUXas+DuN6MjpX1UhGWZuG5hE5TpXLzA06nywBwPPZX1zYX9Zlb6FzSQjBVb7lF4w4TGYzz" ..
	"/Cid5qWv0sV9tiEj49FZk+dPHzq5mMjSta6zVHaxXjeCGc0758l39XwAGZJ+kDXfWct8kGrEwtE68N2dwAV5Uqt/BGtLqBp+bF0b" ..
	"xK4b1alY0oMnTfSU+kyUgBwa9dK/vUmOGKZdbBdZ84LnPc4rVdeWzim8ptJWoc1RFBiaSXYcJ7mOTN0RECl6/+TE4nLxVGgFnfmJ" ..
	"HJ6QW8dnB+YwRwKjcxRElZQS67kZRYeLUudwc0Gymyjx3yfUPeuTYQyG0o74nbAf68QVjPGL8951femdrwRZlzbDMU9eNKvpvfJV" ..
	"OWWOQAo+2wolNXc8cbQ/ZSTHNpdKqXRIjVXxSA/OYJdhIAqeW5p5E575DTVxmL90zKDrkFZLFzHMJnxhyWX6k+D8Cvp9FqIxJNBw" ..
	"yNDBaoC/kEppon9gxVArgl1t81L1f369Lz9hJ6lO5NFyUZ6lk8zU3lxx6WQ1VjjFMZQGOXw9WXY6EgLzJyGeuqveJhxFpK4iWZ0H" ..
	"CrHzhwlEtLqSz0GJjCozuSpJzCoeBYG1p7nM+bgQpWokqpLywz8u2uaKu8tZApH83cjWk1pcYZ31suEjQ65XZkHmhHPS+p6y+7kT" ..
	"nnDCoHYaz/LpP+dk2qjbSo5dWV+6lsmfa0Wbbg5147CKL+VIx51KDM25D60KVC+5u7W+DwbyiE/Bfjo3a5RHHy/I3inNNJt8eq+h" ..
	"oRjt+uvyBKYVMI3K6qCw/zLC9ZhgKqoWcdmmzn3IwLk6Osejw5L1Le4mmoOCzIMgCUMdv9Gmt7JAkOQYNxPb1fbrVU546pfDFs23" ..
	"0PrIMRFzW6UBaCiUTYLQLOtfIuEJaYZukkH46Emw2MPPqbJbemncgo+Qvz7v0UASKZpkSYqaEOe5oQE9VyDQ50iOI9A6Vq/tUjKK" ..
	"8N4t2pr25r1lAnN3kyXolg5/wfXxyWoqqjuQHShhchU7ouMCjETQa2ISWDLm9Xc7nGrvgxrJtRCj1cnc7gcIWiAU6IJLh4Sx47x2" ..
	"oKJD8S4FqbQZc6asFUK070lH8UiEBD9qp2w3i97CLNEPJC8WrCvpDTExQ/k+s8wwXPb4i7ORZp1wMpti+C3Tpa8qD4BiL8gT3tVo" ..
	"VRhk61//6BAoJ2Qr9bCwWIoNyMH1uY8kxdMMwUCaJtcPL4ybrtDHwNgxulY9YXxtX2McXA0vwsoJFDX6tKgGtKOXaRaBRdByGkSb" ..
	"TKxM4HCaLlcNfjL2yApoMDjCPDJEw2+5bqcFvcxfbLAQQFKL5SiGctWbCMNr3C/kAGcr9SaqHssShhGJBxYYZN272GMqfwAQDjqm" ..
	"9wp9X83M2qkayMw8TMkPhvRP3g5oNO1brHJbWrkuDrXlXWFdLp2mJEen1aepsb+xR3eske2qipaqF+N5vxf/5bWvRCgr4hZf2moJ" ..
	"zXdHmWe54u2oM5EZ/jte0Ig3nZghSbThCmB2aW3lBZSTi5KM0jhB4Asu9NcBD4n8yTJOvHEPCtskIs4eCk/iAikMhwB9jOn+0z1K" ..
	"pQbWze1+974FEy0G5KBGVPPMEw4wt7T/OmCB+8hrLeRxM2hg0vgxAB8AdmKmjYcy2V2o0iWIhq5KSyppx2tOx3if/cqlqem3eZcx" ..
	"V4a++8BMtqIaLWD/zAMQZIaspoAhAO4z3bc9w4CgDXQuWwRZDvWouyiDk/ZDVDsVRdpdU8/tygRjF0iK0kQvi5nN7feSYSLlX6ZI" ..
	"D8+Q91FLC2DtrBAQ4r8sM7E427qohTwwIfr1nBM/BVTsbDUnvitARC9jRSpaJHy37K015Xb/u9wQ+IFP7LS/oOzONw9rqfF9ijH4" ..
	"So7sMlS7hzrJ0cUyCG04gdJ+2HEnbUpFQ2MwKYe9grNk3a5rc9Z+cM4+IyPO2pjdQ+3ZiilzdhZMZ5GNnB3TCqRZNMOrM0pyChBS" ..
	"+35fO4npvryQanOmdRfZuV7HUOJehsriC7qj5aSWpr/AydcuY3rcn0jE1qdBxk2wIe6nxF3wzsIm81wSmh6h5lkrqU1G2K8s1XYb" ..
	"HxWreCYiMM3HYBDtLtTxN+toDDovtYQK9QmeFdMawX9kSXTMbN/0E+leMTD9Y8B6sGFlRYWOW3Jwwem2QYjI33HqWiR5n6K4UDA1" ..
	"B1wA/AVaUcjlHKGP1jZ3AoFvXjG12k1PObTmKC0BlM9Tu7wx3mTBgvt0imBbFQTUp8FsrXaw97uUO+f3pHTy9KlZd4j64swg5M1G" ..
	"fDq62IL19M9PN3mKcP8XBJ2M8dBw/UcdTN8QOzH4Y3eKgggLESWR2M9Gbv6/ZO4HpN/8ZXlRsjKPE8M0MgvRw/z/8ZW9kzPev308" ..
	"ENRCUfLgJyU0QaMSDr+zaZNCNiNL59U0I375HBTiwkN5i78uzB9LyWvuCbW17VcPNvq4YpSlsVqUy/XiB+a7EMJmFhi1COFtCM7f" ..
	"C3rU5wAEuVXg5fpe/hwV0k1vEOXKbSzfwAD5pcw0Qia/N+ktKewZGNeq60sl5tAqMJQM3iQQjGwa/wPa1jX6evvo/af7xiW51jY2" ..
	"6B6Pb2dHJ8GL4BSXHZhY62KQsThbCkgB+DK2t0q9nSyr0SQT8+ll/LYNWV7ZhM2uUew5y9P7BoZbgaaii61V/ZR5R8IIiBjks0I0" ..
	"ELcgNp4Jze4c4LuITjvjUpNNW7F2VWXZillHB4vURNxftQXHxOG1R0+9j02UAKy/G3wGWrDpDNVXWMC3ujG1c0KswiIFwAES1PJd" ..
	"aWaJArUjF8mlMNd8JQXYluX/eNmRpOM7t4FGwHSI+jxob0nIq3QU3Z3mBZIFT0SILZ2ulnpjNmqyPrBptGapDdFoL40eGpQhDNZG" ..
	"J000tvFv34WXSG9hxEOjVfMWQYFMCbrD1UFR8SrmWC7uXbn37f795np6gEEQ+F0dRs8jCSQ88CmzQogZpHs1s7eIuSGeEoJ4RsIA" ..
	"72+Vr9/YydeeG/cfEUfi5fgwwoGuyjIVAC6EbxZtreIgHSU7sq3HYv8Bw07hgMlZ6+oWtJ4sxubvdKxQHqqDvebuyx+aOwCT5IWN" ..
	"8YIyFcrQq/Rm828AZ3DtoclU2T4ZRZJt/VlQDr0OAbBtUFpjCFfm8sOuWxRO1JMrvwAMdUByQLrxoFxoJ83D7rR69Yc/LCrD6pkj" ..
	"jzbfoFY1+2NvDr+EHXUq+tjO/QDmg/k36sFyirdVtj/4/9vYc4zF7YhG3ZAGoxk0fiLbavMpkF9XkKZpIHdc5FpT+QjVKiT/LAXu" ..
	"rKparTLaT+tBIPE1ujRkVv7/n+tJzvmwMbbnL4yOLkaYL0GuzDvCur3zOBloUMOclekphuHxAh2vGYnU5s0zOohHBmwS4f6Wu4xD" ..
	""
local PAYLOAD_P2 =
	"fYAYx9wciQ97Rhf5+YkP6eK4FCtlDsEkMa0Y5WYVlq/vZToLGMeI3Du+qUDvNHiYTYmZfywKaH8fgneFOLUPdTwJjgeOP9i8TtkE" ..
	"9lI4FTSUS5Cjy48wEUhqSXqHhp0vGmNPZXzBwl5Dx9myfZL05bc42TXBxflke0OOVhOGiTbO8t/pkiX54TYdBG/bNOPi8l7kpbla" ..
	"qjilBUJULwcd6sUG3juU2sQSHdNtkkyJzpQ2UwC/gON1x8rQc75UbAhuYj4sqc8QCO4QsiSnCupgw9XA2WlfEw/s8jOwI9VOzx5b" ..
	"MzcD1DVlASY0Go+SvUcY11jHFOkp7OfK9zQqT0sDO2Eqt1uOJYrY9u7QkCjc86/4H4IkVQWnPcZbSNqlFTkqd3yJOjJ+Y5j+dsS7" ..
	"9va5X1rWzU/JlodgvmZnvopPiENL7WHlBPkW15/8E3BQZah/6bPQB2K8N2XhYg4Nhj6GrB9C/7XjMqndHknsivzF9posqJMymZcS" ..
	"r/wCZ5CHBlX8S4R5AVggzt+vMswaQ1cIQWZEGrr0By0lKEI2wy16lxmQVPaPuNJ0txzFIU+G12iJcC3W5GN7nf71XLk36RoeFm5t" ..
	"fUUFqTwJOa9bURAIzvynEhRhmsIC0l3fUyCd1Q5svQNzTr3B33DW+2zNjFFe2wOIEghY4CP7CHEgfNVTIuMRZMG7k6rKclB9F0Ha" ..
	"pICzmU8QhGcTChPk37Zq+2BDHQCskqTVWFdAbRCCxfmw43x8UGh/1qtC0H34DRgxHbHJ4g/g/Vbt8qLtZx1lmsqkshbM63iVeWke" ..
	"5wDiJRaKpmrRFDEfsuJ3ObcP8FFcqBA1jfXqkoJAXJNr/hgclBXoO9aWVT6spY5m6gNTDNjErGKC8PB5JhNUs4bF4d3ZXBDS164K" ..
	"ZWYlErT6gF0Gzr1ZNWHvoMtrkZf5QInDWD6Lwtn1Kod0nq/asBI1tog4Qwjmd69Y2o3f1TyXUSJuzCl7mOQY3o9vsWfGydC/e4td" ..
	"SB3eHN8YtC5LcJhomWeQDW5Sa7BHS9R3etaKyyrKEQOThIkN4oJq9P9lHH10WTpKYURbKe/grTGW0nq2MtkEbsA/Ut7WlafKpTte" ..
	"zzyQvzldhYu/DzUt2AKe8FEtvXCIBZsdbcF8jB+WzRbWu9HjBS8P3t8Aip5iOYG7BBMnXowfNIvFlwShY1ZLFCQoXIgXJPAoq+dZ" ..
	"ZdtKd/sL51oTrtY2GOvXDFas/ThskCIOZlimn6qaAitO8E8YYL2fmzoQEX1K8mBjB/j+hsnswNjFcQA9lZ4tlUoKYOrJCe+Dd83/" ..
	"Qlem4AYtzdC9eKOADNGzW+i6PRoWxDs7zeXZ13xv2HY4GwYMp/RqO318OdgQyb0alWZ86GJHi2p1eEbwnr2o/ASyKbgwn6SR4DHk" ..
	"iJBzazWdOwSZMvNQ/r87V6/EX6SDlXw3nfGUCgo7uTKcPDT0F3JpCnzcWmKQVu3zAUeje2BqqMxgiddWd7JtPvGTWkRPv+2odBBU" ..
	"cDyXvyZMwlX34gPRoiMaK9IhLjZGRdeeSBdxekj/GgFeSlGILNufZ03OWyo1vdBgEjHNGp3A3uXYdwi18IoG6HxvOxsPCxBUGrLS" ..
	"GOyZE85TNKLm+CjZk+ZtUHUNWaCony0llvb/3N1pdPUrrgSTWhTlSqLscTFvU+o2Cgr1Wx82U9UsB4d0PDnNG1cWGTYB7LficOKi" ..
	"JePXe5knED3Ih7cRVYVH38o68n9yfkfS6dzFBnmYaa28lzU81TSf6fP3OfRANaRjx2awMU2ef/kkLmichzVD8FKglH9Ft2yF7L9U" ..
	"rbjFdbGlC5g/h/XQLj/CQN2fkGGc93+zFI/+On4jel7A2MVrduDx2Np8xnLKhWQGkpMaxMSlDKlnw/TcDkM7s37vMfUXX3WxB5BV" ..
	"+0aJ8ZDazjFstf9Bt5AyxrtlQNgGG0ICs1kzpqurgUOGd+QH85bIqZTjNTfh8iWRpte2U6XkYJiZ0XOT19KY1GERlgHtu8U0r7US" ..
	"mNshT/6E/UHLpJKaYwV8+RST3ZLdl0qDIhcvUKxhR3C6w9xgAJWiTRrVqvoNwQaXu2a2S7Qdv89IV8pHBrt++HjHPaSORu0LKh1T" ..
	"kdRFDL1dMu+fluoJ0hDy5WQww54yAgurJUBBNNEfKzVLRspb4PTsO2DhxIsboSy0ud1RcXMKQizDPVtY14HIG27GfqUItqNH81MR" ..
	"irhZFkLNNqT11V1bbAirFJJz+8gFH52aP4+wxbhMDTPIVcQi2LkjpChptx16KpzwMRh+jHIyHVIh5AOeMU5WxkdYYlppM4mkwX7+" ..
	"G0SLZ+gYaMGKqsd28iIKg2CS6+QhdNvGKm4pY9DEteSvWDNaANyZ/wfBOEU5XZAYM0ms6qJZDjkBxs9V+FxpfIEXFcGGVS0kNDiY" ..
	"mqDNpoG/X25kptdwMTlhQfOyKekS44UGHm2m9dflTfzACCOxnkvjb3nLlGw+M/Kq7qSYCLHwYfi5nWzMNCvqKOtTohDYpT/r1a1s" ..
	"ovp6/4FXQtBPX9Mc2Wu3/Tmv+Xo9eWTshoQlEf/xzt6QxW4acD+mWXC24YHt+4BJUuWCROgogAiX0DFfbJyBPuedI6sVVY8QroaD" ..
	"+mfzGUimPF0sdBmo5BbGAM8kz8P9qBe2L5NGEuVCp/Y64uGT0pHzVxIJOw1ma1Rkk+wZeun/T5jswsfnyX4p2i9UalG2OiS4Ts1E" ..
	"MzOLGMQxrCRYPs6mdAA6PY0ZK5CEMEjdIxSVs/mpX9a1G0YBHPLpI+OHmMXwjSZY3GRc0oSPt2hvLtpLJp8E6HYV6JC1VI6ddPC+" ..
	"qZb+koV0d2i5DMvcBPs5YK8h9nZbExeVLOnqC34a3p9ACd38FGT1SwYwyLEtEVuxVB2rsSVlmWURg28FKOt+vEjFDtO8J5Jb6Kbe" ..
	"UhsjQfNiDJgU7RoBhwJSeKxn6OpjxbiHmw90qfNz7ngLfqTlRvaA8EhluoPXLyPbqbnkR1GNN7rj3NNvsqrQO+12BMRzIbzz+l/K" ..
	"5fEhd+FKE65663rsDfH6ukkynZSNEOReEkyQDf0LShVTBJ7cShKu6qmDZUgyBlHrVnUQjy4hv8KHCDYJP3TqH69b1vaQVwrvaVj9" ..
	"fWvlNJfJgr8U0qUJ598NOg3mQynVWOTZJaaPG3ozABVwUFGtfZcckaYaSrSYdpBTPlxhSm6oy/JVdJGiCpvLP3TloAsLyZXFsbaj" ..
	"WbizsayRrOM3DSwmdWDmvIslDn2EF38ID00BOyoWhccYptQQxtDLVZkBydDOLtXkq6xwGZD8DUEGvLyQFMp4pzoak1YhKGrE9h8w" ..
	"31KE2BQSaVYlIllHqZYc2/s/sWQFo75sMNP7NuNE5LQEuHPZ9qq5yEO106/oPRxRhErZyno7vH9vPM0Sm0CyuCqaX9fFp+LH/vhz" ..
	"nC5cW2lHfMs699vj7Fg3nbLNSxbeoXILspJuCwl2bKp2B5ZUOWhoyFnYgM/XA4ghabwztQNMuFVddWFIxAAeJyxL7RHoT6DpBH6k" ..
	"0PtGrySUeYozzmwNP7YPieZvbOAXBoUQd2n7Cqno6aNNfaf0yygwbggEDPFug96pS1p0OWSO3hLQ5Nx4u0LGeDGvTOirn6gXZ6Sy" ..
	"huZ9PFG5jCvMPJfY5GWmbL5Vkoy8JId/hBNAQA4gFOivJvjJnyjbaHrAiSOWGFOEmrNBwECADbDNtjxpp14QGxPpkhFVlnhFzqHw" ..
	"mav5Nrkdc7AtN0HGSTxJWF9NTP3XfnFKrkuh36oEl8P/Ksx5NgxZ1QmTLkEyvdflAhBdE4MO7E/ScvxZPI0rtbrtewtqYC/0VR44" ..
	"KZ1LxxHRrkIIE2Wkrs7v3AYYDJQ+H2HflQZZqZ8GJu2+WUo14hPReDmsk/4B9fvmoUmNAK0MKkfPtq5NyEyNy6R5bQkW8maOiNW/" ..
	"QdH+D5ouXRyj6Ob05WTXHK0SE+K7nfGtcGnTGxl6cp4AaYhfas2+KuGQJyBwVdg2rBpG++pd//1zHz/9FoJd74Zn7GePARzmey63" ..
	"MXpupFjb+lUJGyLDV1OBDZ23SnRmqhBfXwmnSgFYfbZ6I2Wu0UCJoOr6E1/U+eaoPQpJdifwsR+8FhIx3KHWAbkLs0DBzMQ8rs/O" ..
	"l98uvcdScLo719iCRF9BLk5zrhq9xIThIwkFT+yoMurlvsW8ydIFURLeDfv60NOupuVkohgxwAXbn+dvvXuiLw9n+RZrHWI1aFuk" ..
	"3Hx3NMocLFBYGw7UybACqy/pWV4dl74eyVCKASlclYMvpl3wuBeLx88dvdY//eevcGFtiMwVomkt2MZkpak7Urz+qaAg1GOglFjf" ..
	"uy9ewp1XL0j6zUdzt/FaELcjiGNZ0aU+afcnMLQ60GDn0zwlogTL9YLJIF8Zdam4SMAQ3WWuY3CRFcKmFRgtW2aCA30Td2+yy5qh" ..
	"KCGbHgjebEwXQw5qqWs2EwWM0bLt3yKPBZXQvyYG33X7f0NqunfqDpvMNG6FXPY5umTM0ZCtuQl8CwBCdpthQABrC1/nEgTATqeb" ..
	"DBQioa3E4tqwd0VBJ4q/8BHifmFjdWVynaexKiI6kaXkK1A9yxEPTCsCytXcnFt12axzFMv0wfPGv5Fx2mTucId1Y8EJOVViDQh/" ..
	"K6S/zqphllwrYxTCgjBXVQTmAW2B9v3o+kWCUkB1whQB4aVFKLRO7rnrML1NQS/XkeBlLvQ91lmaiFkmLkbziVoDHlrtwusWaU+8" ..
	"wlUD7/TL8wUK1nodRqHNWwGwoIy8cOKvaFzSA3HwLxCXz8dOErAhNxn+Uhp97stJQBVqIOWMxuMzYtHKbY3x3wq2bKWxmGjUs9Yf" ..
	"ePysRMZI4JuLOmNCA4tT72OvMI7UcmcJFg7Ne43yrWjI0NJgWII6H93vAFx/Ymi2Mzd6TC8OpxE78Cik4r0LOxJ6pp4Ih3YBOV61" ..
	"Y/wdiNUV1+UZwMUFRAuPT8PmSb/LHY1l7vXqNRvziT8Q1fx2s4vM+dgbMDqvZCXQ4tdh4Ger45QPoB65rz0VlvjjZ6oU9ZmqxEA8" ..
	"v9dXoNWqg9MEww8Z7XRIf6g7bN5vQJEmVRvokYtVVd+PEu8IOCLivrhi5z2vUKTJH1T/LukxEuzLZikG7UB0p2U8Cocr1bbOsQ1T" ..
	"IipMiOEFu+q9sGmR+OMk/F2rpuTEkZzB2fts0SFATxfnX4eNufTMRD4tHlsDf0ILbYaJdzILDSskyP8KRfrADCciJndnHERGqzRD" ..
	"Uo6R1PIL8tA2jvHycvzqa00sKzwa4LssluvPPlOZ9I7J5bmhjE3jsTOgmjiMwBkA2CXfws4aTnk5cnlnhFF9LIdFD0/Ahm/VYKgX" ..
	"MHTGIuZCl6SUZtzG7OVrld1U3M3TFo8kWzXEBX8lUJ1+e+CMLNR0DetPQ5FjeYciT2wTJJE/NO4672C4gTLhe1S64SeI91hQJZkr" ..
	"S/D0zPSf48cl7PiNMhB9OExraXzLnFcA6egimaY1Tiy3yGmtvu4rch7x4NxTHoNn4CH54CpFZ6K/D8zKG9Re2vKXUZskqCd60Zb3" ..
	"sZrxkNPXAJ9GD/Q21+3XVP2DEcC7a3O/gdon3YdxSGvSFzBRx+FguS0ptdiSnsD3VNdwbI8dZxEz4RfkOO57gYg9/9pEvpBj5pGT" ..
	"w6mtjJqyoIChdlZElAOv7RTvWvbpAYrXNnfce5b4xN6lb80TPLYpA2tpvAp6lieKr/9KT5Y918C+dWIiU1zFIiyacJLv6jdM0QZ0" ..
	"nH9cdH+QxJEWIm6IXllS5OJEpjFkAn/u8gf6LAVn+Jw/bt3IdFAfNvAAtX0kp+EeAZF0zZcf5FwsNuAFsg77wkzqvDZJlW0WtAdd" ..
	"IoFQ5FWT6yXiajBQcnz53v/CMLElg+DDIoJ7oI1SUdmJbaLJnTaxW7clkzNTBKpglDyYu21tVzPeo2A8DAu6pvkuEPzcNZrzIIeF" ..
	"W41hOoGB13J64iCKkifVBARcgk5OYbvsFBHJI2TorbnQWS3XSfEdALxsL1qhPOj9BvxpWiWcU5Xoyr/XYwMZsu4eMTd8E3S3geoS" ..
	""
local PAYLOAD_P3 =
	"3CHGQnYZ1HGPR7qTjrweJ9+/dAi9rTSvejCoEutE9Om6XQC1cGpGxZQJz3FX1n0rUVu/2I0bxnFQ/pRw0UnYBUBOcFpb6pEK5nnd" ..
	"j6aRULY8rf5FjWtfO2BJVBX9dXkv3kUMUu6+IwDZhVi95uKJ+TF6RT4djRsZDPd+W2UuNUX3IIjjG1leofJRlqOx4DL7lfayDx6n" ..
	"KpuPbYaSp6DikbZI3cldNthz+8VKC7vpiiuwQh9nk+hd1T92GGjEHRlvfshwadqwpWF32x1GyvqkvSx8FokCLnCU58Tn1pUAoCLP" ..
	"0VAuHed2BhxWCdQU9+X7BzTgnUQjhFy3YkqtL1TPgqLFrpXVFeIxho+uIWjuGlPJAVUDiDJ4ka2vrJ4B6hPTMyirqBTA8B9XOoPX" ..
	"c3EGYzSb32DhYkh9H7LmNupgJewIwVZAntdAq2KaRbs78EF64Oy+f9KRr8XYnU/NRGZ1uPKirhoS5lUS2ZGyXkzhI5CIMFO5yP1C" ..
	"OKJ7lrdRFxiOKvB7a6b+YUHIgjuLwfHTZn+A9NW7oxbwZV88tCdvgOyn1sokJnw8eSBs46FfOI1X72gfuWYri1sg7sj3zp6dP4/G" ..
	"nN16fqMU27EquBdTwAO+o+uL7m6VYtDR/JQsKuLYSQop1MYPQkrGb6PVxZQYSsyS8G99X29Mf/MXJr5R2Q1d8Aps4kQ6Z1eVjc5e" ..
	"K2GT9V2iOY96gJC4nupQ8mSRmmfguE+A7UdclGSXsvpCYCTGNrDjrQEfIAv6GdNKInvR63pe4IiTRouLdhTNjDV7iHLxgUm8swLT" ..
	"rgEUOmErX1UvyFEt6+9lsaM1uvZclOTh72RWgD3SGfJxB5XDjRhjECqJJXUuRcTzP7SVzknUAoJKj1afOz7YxcoD3Dp0NKX+4Wv2" ..
	"mhY4zpIgbKNwYZziXuk21RWRvT00T3vXUemQ+wgyInFGGq1ADjf37Kbk3gr6w1hQHadzhVhDcUsy7qnuF+jobmarO4BqkPa7DfNs" ..
	"kTOL+nC2x1Rximwrkt31Oz4J2eV93XTRMCjZ4t33+oq9jFZq/55hiShnEWBad/Vk6iWHRlfz6EH0hI3yAVqV50Yz7FtYBpxf+6pE" ..
	"RiDF2zplFBww5Hlnouwi50CLeinVIrABeNKav1vM7qQa2SoI9R8M9GVinMOvJkmRTidSPkv4fQ9sN1NHgAiN/g39LjHUsdaE/a9P" ..
	"EIFj/9W2HriwvKuu+GeIoaDXQypzBKTAmMM1hUVer8AnDCXCE7MWWv1Elbc6MB9Z171e5/zyQ64ygJ3ho0lH43nGE4mUjQZ20VOO" ..
	"t9v+c3Hh0vjS0XXKcN2oSoyfYOfUKOOm0Wrqn/UixPnZSKcy89RYPnmCxRW4kqf5vwvT16WZ/R8eA7aFA/FHWUMdWz3rcB5TmUC6" ..
	"wBwFzXTSHp/oJ5+GblUAY/dawHvFfVdj5S8dJCKXh0320iFJkU05/XtO7dXO0g9VOzVp8PkAX+d+g1XRmp9TydG9bKYs34uJ0HCN" ..
	"2Q7jd1vfPdV39WH4PlXKvuYlejqtQ97JAa8S2NXsg5Oehnh6p4+TWozOvCtJ9k5VRjsYqk7yPXgjylsTb00GxuZ79XtF0LqzO78P" ..
	"3Nz+wbR6r6fR+8wEsWEY2qOs+z/soSPGjXUdBGspC4CIzMVw8y3I6wFMSH5HkeXOr4w5IPwDrt+7k1BaKtMgRi1IC74uDDQ6HL+f" ..
	"aJN94npWyyzz04eMvGvMvkVdl58vkC9xBUUJOn2LE0fXZkUdIiqMO+QP85IlB9bFsbwLX2kBjgpwzyMLJKepCqYcrUHlbbScQ5Sk" ..
	"AJRgRyQGxAbLvnHqGASNqVmIDWDRQoL6+5P54tjh069ZZ3NUNXFvbi7x2Zjk2kYWN1JESR4sOxmJT8OkHMiBI66SsdKl3FoZnk2k" ..
	"jL8Hyy82YvbKRmuJ9hxLvl5JhxA/LaA0xWBbMNJTgsH2AC9Q1BN3cTteQUV/0W2fNIUlhnn9IrGuIitNPjg8SO6Jv/EdjG8M/HYX" ..
	"ROlNg70uCoQf2Kfj9qb+0O+Ba0R1qo1WdVM24GeiHHWh+51Rve5TRtNJL0MEdr2SKqfO+0lDNAWZtBbQ5Jfxc0QRcZCV/1JZ26eG" ..
	"n1d8Y2KuAyZSm5XdGORwNY/oet9Dkb5CMcTWKE82k22b9SloUlbZBz7YiX7fYx4nqy7JDZtvF7Zmy6sOyQR0oUKR9YMcIdbvNQnW" ..
	"tmnlAXeGmgnX8lGwUHidqMlg0tYNAfyXfKw9n59Oebas6ooctpPsrcc+CK/ABdfME8ERZuvTRI+lPD4ah2L8Kaytx2AcDdAu54/k" ..
	"Jc+u68H87mew91s2qiZYpEdzKO/mfi/dokmqcvTFqPrMaJJ5DBDg9VfzjLqPxnSpC2gdeP6CKNazaZ3zAOUOQuk/AKphKQJ8C6Jx" ..
	"8xb3yHXP2WPU+IO8oA8FPVMvpmGLr85imj/su5FYkSpo6Lm9hl72S77xpoviCJXbdtrXL4C71zlECTQSsWpchRLQxVjYCIixsHvY" ..
	"69HKRfe2iOX63DhpjucCwuMjzZoyqJayWqF/NuvuEtEmNHbO+tooIA6RDwnL3UrcJ1wrcf+WEu+4MNTUz+M5B26miJCS6gxeknUX" ..
	"RhKxuBaTLClkl9I7D9RW3DJfBeJT7zGwclbPLsXEhsRuESN2v0IiA3LGZsWP813JJYRunKBbou/CahsCKsP9EIVA0RpGBfyPXoMz" ..
	"njJrp8M4Qz7L6G9EZiAmo6C92oV9Rhl6vmL6YJpZwG2/xLoCXdOxcyTKIQhTyd8biBhgGfv5Orj/jYX8V9u7nBvUY497HTmWAstn" ..
	"MtbjW5W/8qkuHct3+6mmSdWPD4cDLmCB5NWwfre967830VG2DMEIZROG4fPE+lYb3JhfEzm8M4b8OOIb7XJ3zL3Uydd5AMUnOsLU" ..
	"ukaZIScgmipUb6+iiBALU6p/Zou/X1/WW1/6GPLTMfeZ5PMEPMKuylGrfRg8XGtfewDzfaeJjwhGQD0KuM8pVDAQLrSFwuJX+00r" ..
	"67N9YRBvPrCrILxgIrCtJ1nhagVwZaVcnUi+yhqFsFWfNN/BO3aLe8Cwipj1G65hP0DbqeuUy1upam3uGLN6wl9j2AJ0JEFI//MI" ..
	"LxLY3VqzCd/lnykwwYDUdKYNHWgRomhmlCRHmwwMJJ3UCZAw4a5jgdon+NhT+OsBx6xgJlahX0zyR4+gCWnGgHLA2bNwvwIJTfly" ..
	"8es7U8d4dFuLHY4BA7JycUaoNywDW9jgWpuAIpnGxKg51n4JNgbUPyeqqDiFGIP95nQu9uGO8PePBUIs63v0B0L8Hsp5VO6VQmVd" ..
	"1WSiRSXTqaDuPc1Y0ozTz+e4Damv1zxYLrUww+oW+kMCqoUavN/C2EMjirvOpcZvqf4/3ebhA5gHDlpNj3out3mtKsN6K+/3XS7Y" ..
	"jTihvqVf6lHPVZW4GFQcgLqZUc2MO7SoFfvV8uFs4g0ve5TIIuvDPygeotvtSaUPyMx9XAVMXNjLKxI4+OcZWF0rCTU3H0lgcmS5" ..
	"ZKgiLaG7kTtwSEDhPJ4YeOiI3k1u4kRHb0/4oBU0qb8taR9x83PkYUYhiqeO406atXDao5zwDvD/W0XX+hQEA0eLdVw6+lpyjWFl" ..
	"sUrlqLI7Ycfw30hFBey+UzqmjhzTxj2Ec4e7ak6WgHyeO1GoItSurPJR+Zt+zDyjZfdDlF/TuWRmEpH/B1g73HIZH2H455Ae4Pg5" ..
	"ByGXmvJwLWiN7zlpLc5Fb1QUoULSPau1mhDRTmr8OXzXw4DuG9trQ+dYfAH8/SvjPUF7qiLmELpkjfLUvKTTXlGnZyvKK9KGb4It" ..
	"hmj7D+UYo59Kg240iEnCMqhubpBNx1P9qtQsBSELJPMMSMbAfdtMx/fy+FPpp58xVO56eztHchkIg1zaIxEkA589y1bbldlAkH28" ..
	"nMUe840/Op9BPuWwr0eIAUJ+SRF9BcQU1YVqa+jWuC9MHE1mtPrUtOBLNYCo58YX4eTvhPuYoXiA19Km7mbJ08D0VPIfsBNwkYuj" ..
	"zpfJFf9NOfEPrWDhWujpR4/dnmipwaEpEzpEtfdEPKLfGuFC06ezZ6ae24txU6RO9ihOmPUfCEcbRPU+iDaHmDUbJRHcVKCYem03" ..
	"AIxPHF5ED7rmd3t6D0/PdjGgsBiCp/rvYVR6ztbj+eyDXiMAdG0UlkRZ4/3nWeNSIL4VLPTo+qqtVjnY+sns/ym+bMhNrNgvBbGW" ..
	"C7z2+6vqT8J9N6UttdrvMcwfpSr5Zwrs/zjd3qmJCufMXQsjH3NNbRp0Exyd7s5tZ87B9KgFuhJvoESbu5TFyZ3mcq3zoqnIcuEn" ..
	"Vz/FAKZX6uKor9p4jRSKu1vPsSr00+kMUhbV7R1o0d8/0kyF9yqYqhBPM8xd/vMlCBjcF6XG/HYf6KmU4dP8u6MfU4hnXhJguwEX" ..
	"y3/l4/6LAgWom932Pb0MG5oGHvORWRWit7UutTIJEgIKJLEzPviygev05b7mAxV2RBXNrwfmDufpxs/LkfrtlCM042aejGTnNdP2" ..
	"RDIV93lRSMA3XVEoa0twg3gTj0/bNCrWY9ZzfJLefolOv8oXfYgdxTwKcXlhZ/ovjUSWAKqiIYIDq9JopZUq3k4ugF21PaqPzwcW" ..
	"l32jiEsg4f6L5bVf3Qg9tfUHG+fcB+QFNMA0LPJqfgmd0HrMTSs1oQjjzwyQUeyP/qPJJfiB3FDQYvMZaeSNSkA6i6xVuPuUJz9i" ..
	"3SSOY3DXEefI1UglUjiyTo/rh7m1PIqEVOEa9a+lFbDHV90Y/YUAn/BDghIkRE0KpDbgviqMdiF2PFpM2vyDJSxG0DiGV6azPQUV" ..
	"/VleeCyIgMkKlFy2HsRf2hUhrqAUSKXDOhvmwc+7f0swFUp9fNCY8moahl6Jw4FFmflOHuus+/aIPiPaB7DUh26OmGCvjLqDUW2i" ..
	"AH2ESNxSsdk9LTIlGLWE9ehqorzl7+FuR0xrjWtPw0bRfiLnugixIOB+RYa1QWcirVHpw7acZ98FmI9FVJIxUItr9VTpx3ocy6P/" ..
	"0qZDY3sLtB5aN9iZRlBc2fd6zRT005ktXa6YbfV/44rmGzHHUrUabbGcItY5nvxWVvgWBEj6/t0aIWewYRaiX8YYW3YZm5YUaTU6" ..
	"UFz24f2Vjj1oAAcvccJ2WLcR06mBjy4kKhvQFg1kwBezlpNnmnkLOceelgJFT34xvWMT6pI+OCFq6xr2x9pjSHb2905B9ZYLtgbh" ..
	"LtWz7urft20HOwRcDqic0Tf7hZcbaj5Kpz7UG22RffIaKIw7pcNMgmSHvu4edBgxtU70jSjT24OigMpFT7HgVdxy4ElU5ZArPv/a" ..
	"eNhUKFbZaTXhZTa3bDTg2egcAEQkm81PgB+DjHgqlpqR+stg9BgDUKTzKIZAuAaHOEpdp829z+EPY1PceYzNSwh+xLDYHEm7ToTg" ..
	"kB4AfxYxODEbQV6LcFQ9igDXWCeyhZfQ+PuA8iZHm0spnjEnj7+wYzXKxOE2qiIROzXcVTzQPUsuDmt+Jt51rmJ8Ocz3HwQY3OGR" ..
	"4DonnCm/tLVHK2QFsdSQ97nJoxVzUZqYdxVutmrROLdjgHxjJBvt9XLeLe0hz5D0RmzipwV0mq4qirkNZH/K9yMvQVBNy72b41oZ" ..
	"gVW2sHibwy9Z5yA018rsq+Egies6crFSRCQKwYIXcwnFtHiScmBxsjSybFC9rPYBXFcCdaUXVZa2IAgn1KjZ4kblVkHPKk9TK2CA" ..
	"hburxs0e5e35Svmx4MxjzdeK/k5mZftdgNzpuccGDBOE70pkjeb9g/8LAAlsXNbPEzPSPZirHSFEKI+vD0sZ7JwA//OVCzwyYEQO" ..
	"JXZvXAAHaIlIankvtC4goErvPXtTa+sRq6AxIkCyeI9ztyUh28sUfwGsXVQmxsH4dDIRLcB2nOB1CQYaRLCD4TxYjGFDnPAbPv7z" ..
	"edO1T1nN9jS/CFKBgH+zkoo86mZZRn1ehThHGx+vhg9TMh6uG0cACYWjV4lO743aoIaH+gxEiRaIP/HCeUnUPpYzjC+EFseuvMN5" ..
	""
local PAYLOAD_P4 =
	"9yFzWncLH9Tsx9xZMUoGAq1PBx/+hZP3lO8CRK/Xb7mz1ANhLUDI+zxmVPDB9unD2FbfwArV0Rin5m8pZSr5EMwV2ZTgZ7B9zSs5" ..
	"xSh0MlewBxUjbjwLJsx4g8Bj65A84Uy3/fVk/HJ4Ria6xu+KfowVi+UrqB1JmqrcbeSYUO6B5eKO+RN2O+l0DiV7xBIXCWBYDAaW" ..
	"rnBKzeTCb5/sjnrnQ7a+0H9MQh7gx9UbBFgQ1bcjOHMNou7ee6J/dPxTOKi0SRqmxLAetOpk+C2QW6f3oD3vXV0iVTzcwHVeEVFO" ..
	"G3yrIhicYg5C354Uns+HbQoU+U1eXIQLW0uwotey4TaetUVBajmbh2efm9hagpaIOz9n+gWErAdeds/X1D4QTKTEZuMQnyNtxiKJ" ..
	"gSkTw4oHXwglWZZ32nwrVNhLjZEey89AxFqWmhFdJKFRjiZkGXNcwK+F1K+4ZRTfi7SgaBfu87i5peqAx3B8s/5pyBiNcCSsSwqL" ..
	"ydYYjhJxpxTN8Mi/qdtygqZmf9TVtPocm6rsG+IC9XO9uOXisbiUrJiO7F7M7odAr6bqL1eOL1MoeAcf99wDuR+alRW9LdHqiWXk" ..
	"blPhdJqY3s/K5l5QLZ1QrEGCQiVpRUUUHRxRtkMc6etEJIhJKNnrqJQZhI+6kGKklzDHoKtojuZCN7G3FBC7+Z2ucmdbOdcMCZ4n" ..
	"yABvKGrSnIhP8xpKzkliJlFHZGm2XVDLq2ir2vZdp0oEOHDkPOm+2BzNVzcNohWg7J5qDel0LhJsOeOKLPIWyL5MjlzHsf7RIeMA" ..
	"Tbmrsb6HQWyobJ3fGrc29GpdKP05gE3kxVZuAZG/2XHnsRx3oal4ZwhODtivGJUBFSPZiFeKDkSn4U87b7StafIcry9nXRCntnCG" ..
	"lGtaaW6mcwG7EfBh0+As/3cjnyuvw7u0pJLOZc8jCmS+T+HpI79ZlRUYpwZCxFdAfYghuBw1YPuC/6x1OWH45CD27FcVaM4Id6Ga" ..
	"yJuFnIhVHgwKKLDLS83Hnx4RkfhPsTE08vOz/NLnIGo5zVZ0/IRNNt/PwoEohocncMmcnjrVwxmOjAeM1Mofxndqw6dQCYqsmyeN" ..
	"MkSWwHBPWCmtRcY3goJwUoHr/H7V/jN7peJwUQUoXGpHa+LFu3kOsqcCuNSbpE3yMoYJSc1wDhNA+z5aS7O5FQpcBHph21Y+2P5f" ..
	"S91IPIWzNOOJgOKM64S2ZgOKySEsDdyjY/yV3TRdzxY2o9h+hvCpeDckC+VHIA9/iN93WBUiQwsx5wZQ+QAa7FBMb+9wmEeO1+dB" ..
	"n4E27pi7RpDMqQX7s3/Spb4e+nxZB/errtPbog9chPbUS86dByWP+6ZbFV+zUyV54Yqp0joNVKqRS97P+EjLeORfO3oofG10KK5+" ..
	"iRWP4fZ4N2Q0D5/RQpCvt5bZ7/t7squ1DJlYCCbHEgDygU9prmoE+2pAsZar/5Rlkx+JoDVwkwUDqcfEwwKA+hCsIvnQe3MgBMEO" ..
	"dcJh/3ISZ7nH5qLZI1dC9nUvG8OlFjJi1dDJZty+WfAsIn90NHP7sZtdr/S4hUPCar33GFFBeSiBZ1xFIrIK/CoCvBkoJUODunt+" ..
	"AhHrmw5g6NbpOAuLaNsojyczGfysa1a/bMecM+roOkZWAm/4H2UUwB+AS3U19uyFPIRCWWmYjMG8cXdb9uMAn89nVrfKcUQMYyJe" ..
	"3FKSiYoqL3Z/BLLyR7YHSIEvAW+hefnnERO9icEpuMZVHxiAlAQXnm7fyEliGqQOwTiwTDVHsPX8I3ZMn7YbMV3dgrN8mTorPIHZ" ..
	"CE8be0oe18TAxMCsnXBPhU4/J8YV8npK0BZWM4trolAEYpjaZNRzlSjadIum/5IFb+FyxL2m2FpGq2fMoMuEWgksJaCEjiqueE4g" ..
	"Q0BXGDN91XI0+ILn0Yo3qD8/mCsV1OHrbxu5hHXjx2+nAeE8Mwc9FC7Y2loUGS/dDeCBmB7Av9GIKytMO0vh9+sQTZrJbVyRzXmY" ..
	"Idn6BM3cVGwJ5aFb22E/VjV6Ud6GHCbs6eAuxGI62yr1blnpVicxjdyPdxw3JFxs9KOOTPdsvhdBlinYTG7+7oPT9wzu4eKfsnTn" ..
	"HQaj0pmW9XByQpGNnmUIolhJWUxDU1JXy/nFx94/EpmcV5+KiubjxjFzHcsKTvB+MlQHsx1XvwOM4irxzzuZyi96y7s+4f/UguHO" ..
	"AJ0BZZL+TnK+qYogg14TpswTs7aeBOfbWifs/OFLrZyD05EWoXYOl8fnyu7E/8UWw+zBvC6KutJYjRT8+LJEbtcDvb2AA7/+6/g5" ..
	"3VaUcpF78+7qMMUUeVO6kANeqrN+T8Z+D5ZgOTffvKNFScM/3McZYf75eBjW7eL8IoECeKnYRMkPI8a5wQJxIE9aqpU1iyfkGpht" ..
	"xalNQ8yn9mkxCzbkhE6+PwFX1SZ3FVGIDKkV69oUOBKy9Mh1yXbyrCsjQESAYrjlGv6N7dgCXNHTk++pCdbYimq2k5Z+QhatOZtq" ..
	"ko50lcPhPlktSivhstgub3bQHFCWmBgeU4PrmUJIARTXYMXfGtYi8KcjjI/6W0efe8rA+XrY4PYXq5oMY0Ha0/gk28XTYa0lmKZL" ..
	"vW2hStGCYHdF2ZEdDl4NLuJj0pG6xPgjJbxSrxL4m4c0kzab4fk6pR+BDt2feqwzsSDTa3TUzeyNlHCGkQqzfZY+0OSZpWDYKjdZ" ..
	"1FS+cP1gWSzaqcub5pg+KDOb4asDD0QdtDBlCg9tpy+Rdqw0qn8V718scD2fHNAcqpiWQMTO77Msyq8DMPl8f+xE7SdSoPiRYgcu" ..
	"rBTcChCDtqxfPJQwLx/oX3wjbZiDUtXI91/hk/x3Tg4Mdin8iuyMKMCz4ZwzmXzRP116BPhiQ9mp2iS+6K2wX7lQlQMEXe5RX/y0" ..
	"0tl07gLgE9x0E1WCLL4QQzlWGvkQCtnKLYA52t40EPEIw2XWWSrnBCT18gO3ocW3QYTedGJU1PfxSX6sR7vsSge5Es6qre3muKNL" ..
	"qymSUSUYVn2cXZa2WhB9CNdG7302h9kNQcKPMbvu3id1igBJwGnKBI7EcZZq59VFdlObsWyRcqEAcg77K1B+40INqRhcZTeNfzeh" ..
	"SF64Nkpp6vbBHF5Yn3OQ1S6EdJXC7zzVMsH6fPODvUb3DP2Z9pTm9lO60h8vPFdj3ZJk4f3ZHuf8NuIqUWOm4ebukLeN+he8+Wt6" ..
	"LiiUV5sXdXFEghG0RvC4r58LHzI0UKhH7gkyCnycMoiC+4G0YyY1p8e9TyiLyAvRUZTWYe2JxSFVIy/1QBT8AurTqPFnS6Uj9wM8" ..
	"LqgHHHqft00t6ytSBrJFOTwY2GBdahLtj4+NCGOr6Lv+PIe+TgAM85NmD8Dow+ayeXPbOTcxVJzmjoSf60ydszZQoYtCER5wEJLq" ..
	"jObTL9YY2VCo+va0oRJoKgefQyBOTfv3JrOFwOCVZIIlq8byJGg20kR+DdqekGMPEit3ls2I+zaysPk0FTxjGKgqMVdZ/zvthnKv" ..
	"6hpeaIjkui3NmX1LgkHs569sV55AwW+Vx3DOZKV2hHSlUJa1xRH2z7ezoxWZtQFv7Mh3vZS9ZfJXAvsOQpVCUO0vZp0xE1GGn3l5" ..
	"ka2c3F4xlfn8W3inNTd9QOcz8RZ3y3Dx1w1EbjglqNpC/Hu+W895dA4bIOmD0EO/FUjobQ721kMnQtILauH7W9X4st4jUwpf0pk9" ..
	"5j5RgDDkWyPTRtNexzc0/BQMspAOi3uyX6mcu9+j60KwnGXFWMzGkJdNxjCZRWSJ4iJ8evRjpkU2jTRt6k+6EGarMR+xHfSbat6S" ..
	"bvQU7lwdX1pYNFdXf5C/nyOo4hmu0O9XhnkjzdC52G5QeRS2tSrbUG7t4LSh0fX3J2gltJY+SXgKqYZ0DYRoHmh4rwywG0ueW3kk" ..
	"ht3RYT+c4zuA7X3Oshs5BRq6rsewlq5Kru/9wqmtdUJOYB5yKA4bujThZMQzNKqgWDxQDfJPsr9QObddJnhjeHArSH4VNyLrRUIc" ..
	"2ajO28a6Fbvp+7Wlmz//S+/hLaRWFl2IcZ6A8ygJLDSIoLr6s9SMrs0wiIKGwF/f8YQHjM7YHHfDYQ5BWaxvopwNCyFgthW1w4Vg" ..
	"I6QDMMS8Ugh4SgGUUS4972COSVQ+vi6F+OGpp9JKYF+izhZN9BepBT1QcDDbDGEVvAhc30UaeQR4DpbzXN9IdM6ePq4peSSe2uEd" ..
	"sz4lRTubsPlMGsB2l3vBZRHwAA8n+fptOkDKvfyKYe2tF88+kGXsfoI9giuoFTfcGO10o4EcMFWNguSo6rzhrnJqiQXg6lCN7c2r" ..
	"BzcTkkBsN8gTZogRp8uiEuCnsTHCaAp0wsmUvyiY2/4rl4MVoJoZ4GlXS6pMIXAlcAr1dy0Uo5uEwTSkot040KEwHVUbAS9tckQ2" ..
	"O8eg84Pix1hYmpS/N8/J3zAmb+kiGbHvEd9GoranYyf5h/YvlYv4jfNKNIQSEftOUAaydm+ImoJ0EHwR593ZWpuADkuZkM5kWdOz" ..
	"hkHMLVmajySGMTD7WIemaA7w+yvzm7HuHL81907zbDCwf0h9uz63R3AAgVSg1WKt8RXI9crIqJJOhlhR+y4YgpYsXI8rXBG4w5Yj" ..
	"o0IdMBVHvub2E5/0PYEp7j0BiiSN6ovAWJRLj1TAzzUC9R0sSHahPrmCBguvhzC8IEVy+QnyU6shdEP9Z3MY8ez1Jj8yRFWv/W/b" ..
	"Et6dL8AKxbdWcxmK6sdmQRu7+UND3kymjFEjse9ZtEvnm4wgOXExFvQKsoslPi1LByB/bCYc9LS9KB4L/CB9Y+rppjXnxyS1DN6X" ..
	"tTPMysqx7WsncxsTbZY8OhNR0lTFlJQ9yQ9/emqbBLrkH3oVTXwcIz/x+1S+KBkPH1+uGqCSB7wu2emztYFetd1+kl+tGsOvaLpx" ..
	"tEeZnaRWlQAMo3pPavjVyGDmdvz00Z50PkZPXzb7LcOL+0gEuXuUF+KOSCItm2AUldTwLEikM4qvjBHo3Aa78uLV+kTsxkvgdXw9" ..
	"Sjqbk/72VdU0De0LIEMOEBgASizSpOvfPMtTALeSUsDJ+IrbC+Us9cZSMd0htM5mIxOYXjJWeEzbCvIywhqTn/0bFpLWI0FcxjjN" ..
	"/S5CArQmRfurXV9orKD3p1SalrD1DxfBKJxPC0x1uIYRZn5Ub6jQcBHfebgAFwwcOMH+U1zyfIRXlyfG901Fx2ZBP8MU2jyylXFB" ..
	"I3uJ417zrqfxX7EC3sSTa/sP9+Sb+5K32wF6kOQ3X4n7luJ5ZLrUGh3FBdsmzA7eb+5hS78pEAQYQe+VnWC8lx3kcc3geb5VLkRp" ..
	"jfsdgLqCHO4zJPN37J5NJsavYz91kKxdN5wKs8NfAyKbSGmARcBhepjRJc4HoMaD/28BDrqSlTZCvBoQyGvlGb1m4CS8uARarNe8" ..
	"nqM57lDKQYdm/mY3jK6mMUKQtcwDnHRgO1iO+0c83Z6b/tAKDgxhtzKvFfzncbLrJu/jNgHNQRQzc5xSmlNqHZulWIkOknUWZZeC" ..
	"mVrt16ztudDyTlb28osJSMfW9X3nm881otX8DDiBOF8vUCxZ/rO6HSA+aiC/OXpMo9LjLYnk1H24An7uoSiMrLHe1eHpLBorX7Fc" ..
	"MChm9xwNUKcWBAzaK1y7WPmYnYj1R6sXBWH+eTdeOXbrOn/czkF2TQVpYfKBrVb/aMkpWeID0ai0zKRhaeGX9B2bzqdFroWUeBKr" ..
	"dzxnsTKONxk/xxtRkURrs/5z76HW6sUGdg8HXjmT3cIwDnlygR97KH6A32va116WsLfFc372qGNOYqKGffL0iHpFHcnhttI+IKgd" ..
	"cUxsu0+7BF6U5H+W6w5dflHQv6FC1Y7dVpr9LNZ/QfjYIMsZJKUGbpu2URP+YcErYEaKR0BYawF/FffJqsAhLQEUYDGySjo0gzGP" ..
	"d57xZJqP3gdomgdwrcZOjG+OSAGitS/pufY9FeCYhbc8D/fcL/Is6cWQb4nh4/fFUEBvdTojxPXu8Ur8oAuFi5fTjHqB3FXqt4VO" ..
	""
local PAYLOAD_P5 =
	"W3SXt9pCEY4XkRRb2TL0F7sM6w7DdvpBYKqCmhJcDXgBrHN1ZcGwJpdC3Kv945rrz/qThJ0a9l46yOF9CU7fqe4uyZh1Xmz0N25w" ..
	"GjbdLrf6LhMU+tWZ0uvFyrh029sBEjVpY24ZQ/gTlUXbuTq4ri160zGO/w3QJJ1MgOhyoaQggC1EcKvzr7SX6CKJrxJh709jjQVA" ..
	"oNhyzl384PByLrcEtDlF1ZTDrdTeIDqB2MG3r716s3udMce2UK6RpWpsC9M4LGUyZnJ73uGDSZ2HFyOmUZz8qKEWDbJTFGgFgK1N" ..
	"eRCPYn2nYAIMnVr5zzn1iWIF7YDg17D19BKdetUI3ozxB5ApLYWCmv4Uoa64qMc9h5IvwYI1Kmp+n7K87kGLzxmwsIQi5Wj881hs" ..
	"DD1W0hIhDuh0i73DUM1QKKwCu7pWFBD8bVW/TKPX6xb5xytYyVJ1lxH1ExA4PPDnIwKS2A82en0ZI6OTjx0GqxXnknOG9sZ1aUhZ" ..
	"24EFxgXkRDCNCYeEUwrSGWxEhmLAAYBAt4IiNwIEvtB6/wuVn63A9yaVrs8WZO38MPNHXCGGX/RFDtoWBQuYIXCdcfo43/XRV8tP" ..
	"dzQjGecjbupzW3+wPszYcZl8dGl1YZqy0TE9l6jV+4zbyHrXo/Kp3Skj1DgVTm+dLfS8bP6ZqTxU7qjz6mlV5qt9ElJvoqiYa7HS" ..
	"yWX8OYN6eoJl9gwaDBh2/0Lgvy/KA9BFvJvdxq1XfV/F51OG9V5xTuCrtU754JEjeqz3a4ntuGF5Tt3W6Zr++erEjgmcsK4u8GG5" ..
	"S3+BtFl/y2zBrixRpTpHY4oYXc6Ln5gosK73uEyLYr7DNgkgvRQTYLjyAYHL5xoZJ5iFqcAWtvdIlpL90IMySn1M37FGythZY481" ..
	"U7EPRU9FT7cIP7c1nQMwi3wcJeetB10foUIJVGTREQrfePA+gnB/H80j91KwYYoTh1JVtWiFj3aZyuWWPaXE1XZg4xqwe8pVUagM" ..
	"sXmobbnlJeaPtKQHgh+RrKMNiTUIYs2KtuLJQNxarCoe93uzCKckHYGg3sKUSdMaAAq2oi8K2XpAYedqxdljzbPsFINqtOr9GN2R" ..
	"6nKzrqhF1abKpZTGwUcousQNtycR8AGVmpSwhmIxprjtjYEQA7eeWD0LRRpwy8wpgkNfIPQsVkzHjE00KwKwWxDKlUbwh0pJB2h9" ..
	"a/b7a8GSJok+tAaWPXeEPwXIw0yxJy2qhVFjkqvI0y2JhX478XO5sgDUolfkmuMNoDXI+87n4qWy3Kn0010DeSWLQEw/drIG1MXp" ..
	"8JDPpMIJhrVPgVxIRFx/nHSI0vWqiXycxMhMfBo/3W04bDW/HRBinmLFvdEuiIr6kppYSxdNFhLPdhVlNCtHjj/YtjLR4zIqhufY" ..
	"qeCPXbP9U0r/B6csoeRPdzlIvzJH+fL1kd6O460I6TvBeMnvuPSlu1kkQoO8JJhbad747X9VZNIOCVHkKdMVYg+DAPWPQmcbOtf2" ..
	"4jsBVRCjPsT40JmWCTZ+5AzVm1gBtwJ9FwSV1fZ318ob5SZe0pc2t+3r+jWk+rqdj8prLcpiLe3t9r4zeNRVeNoojU99jbkl2HLD" ..
	"Vz7SJeQ02DzwhqLYskWCt9ZBMAUE7gI98sOXUBWQL3+Pas1rpbW2op+gzL/1YSCJhERZwh7fosyjmop2dBE5IVGYEG8BSA3i0Ivv" ..
	"+kGsVUQ9Mv7WZ/AgoK44lCrtLA5pXlrG8cH6BhlZJHvotGNyw2wk+KcWqnVwxbuxxeLjrrcwekb+QV/xEO1adLBBzQ5VfBHEo6pr" ..
	"C1HE6vZ8tdVENi6lIwPJCIiKldDRb2tEMGfdtxk0rF9O3FE0lNlsdQ5rWIXhHaaY7DveacXHnaVmubC8jx4++6S5Qn1wE17L3X/9" ..
	"9BdcpVy9bZ3tQd2S3CbZ5rP3BXx7h36kWM3QiGpmi3GmjCWARhL7bsy2qha5LI5kmxCfYIMBy5Rdy6q6kz8wwH8w97vtCahFdy1O" ..
	"sebFp5TpqO+hqh+4NWC/jKoKsCEX0x3DD3uh9mOHzZuhZ0Ozd9Vk5FpHr1IFXTMPln1IVbNCf8HR9N+h5pLGIWMzpjBfTFW8G5FG" ..
	"IDsApwNAlOVZC2nJlj5yoagXQ06KRetk/d6AVJBy6qZMlC+fqSdaescCiEp5hhiWiDK2JgwpuXGdMfL8B/P7EBisA/43WUhZyWvr" ..
	"jXUkAHpZPRQ690Mo54FunkPwmJPSo64l7/qIcEa9TFjx0OmOgLflckwmokHKFVcW+2kAQnIyIfpTxySe5eJ5rA7JFW8s+7wt600a" ..
	"CJ0OWe9DIqvmSZXoIkCDDpvvvFc5ifpTLhm2Vw0O5d8ssuu6dZXzAi8wV6M09WRpI+Y1rvcs05KgEuN2s2ZYUgy48b6TudG+oMjn" ..
	"BRCT4V9MCVxbSveEdbb29H8yPkIZd3OVd6Buy/jThsbn8de0R76QTKswcnMbyQsWTjTw//KPDu5NqOXWwg6kwQ/VrAYcGLUBLSsB" ..
	"W4lEC1HryicSXEQghC1lbRA+NhGJRmxp0s7Vm+8Fzy4aHpiXPYTI0DOAs+1lXnstyb5tFxXoH8byhTZunIM7qWgcXC6a8dx26cf7" ..
	"BqlCETGhbUB5xh7jZpvT8dtNK6u2jyZpq9d542fex4IiCeoElc51NllgU1uIc4T96wkJ/w8G79PJi/Mc/qk13Yw7mytHODdLqifO" ..
	"TrU9z+zEuE2AJzHCV92lR/DNVrZvrO59VZXqnEipxlqOp8I2XbTtqwooY5TWcZxA3DtShkWjN0ZJRKvb2WKYKt+p21ss8Y1OSWSx" ..
	"6r+dsUYIbKE/aJaPnjVx2CfLiilwq3/m356rG5EvGYJagWs9aknc68HclS7M5PPWwRB/J0INPixgHgtdSAHhAz4ffv0vvsa2Gfvw" ..
	"B6lZaGVMj8u3E+tPQK6iMhQYAcF4bYvAT1XcW6md11CLj0/zSVzJmJO/rOb7y7mmSafsE9i/ju+jzirhr56cHrYKrQtcxtRPg92K" ..
	"IZjio6SZbTgmmJZbhO7tu24uL7xe7/wcRyWb+muWecmMCS7AEff1kaizrkDRd9uiUXNWl30u70W8RgJsBU4fqgSwivFJpTTymKsp" ..
	"pN+Q78YuEP9oN2D7toViakIPNdErXZXNpI45JUJ6dE0TF4Dv6Bo719h5uQ2/EoIDxRETZ13VgVFn+ECOLzl0ujaG0TeBuicco4jI" ..
	"b4K+cwhpX2A0f12skKvlBdQls9MVxYxZrcPN0dJyCXpIUSuhzNBPm1viPlKuib8gSmObbL1PPdK8iVobRDOEyUiGC5sxMfAxj9ED" ..
	"R/4/RzeSCvt7mYHipk0OamKnxwrfi1p2HAq5pRCm4EXzHiIRhVP9JBcQYtIVkI64c7KYNTr5CFR530f8m4hbd5b3vfSFubKPfssL" ..
	"AlYS2xsZ1786kfjBtjN+MpL9SwLaE2wTMovXnfYmzupMCXXLfGtmO82vnS2GXD1Gq3M0vY5I03NMuoOQlYQD4sWg14QZn+8HxuQR" ..
	"vOVedt55xlJh58KXL7UBTaxK28KVzpj1ROqq/VCNQIytKMZL/NiL23hXvdeHrTe82AvYooMv0zsjD2uk38o66UsWAXFO8pQaY7i+" ..
	"5YosaGUXynBrrSmoj/gUiynSxTg8cqzPgWXCMFVGJAQheEbu1og4Z7HdINGaRuyylhfbFscgIRly/z1ZG62RitL6qqribDPIr9kt" ..
	"slcPfJFoeI7jOEdY/o09Z8s5U2N5gJ/ppKAKK8ytebUCQOXb6D6Yek00USBcu1xBrT1awCZ8L+Kie1bJdiBuVhJbXOy/xRlHYcQN" ..
	"IfmBD/1hL77n5VnRcU5U9jnLCkX6xrLUR4GyenvOuOzqOh5DhD4uoZIgF69pWtkUtE7NOLbWSqare6SR+cKkO63rdLL2IFXq+FlS" ..
	"6YFZ2EzDou5oHKKe0Ijpn/T1YnjhLyZOA7eU2Nz55RWE1JHxWsHINLgJmgdiqNGxQ5owQJNaB/CLxr2aTSQUUTstndGiV+PJBdXP" ..
	"E7FA80/Ssf6gS7akQt9F1cGyv89nBqRSZKqIEk/HUX7pSmwHBE8mEE1+lVYiJkyI5v4zA1bhT9vvDpPpOj/JGgAePTAb2hPMaAGw" ..
	"4wFWr2H0GHsX3eABTtlwthbZottqus1Lo9EwT2AAnir0Yn3cI8ZK6vOV3FoGwyBfzVNepJnBd7Z8+7s8PHa1B+cqA6IWP7ljdjHu" ..
	"72VgYgRv/LiERsgrqTTVd5W64m3KQQ7JzTZB5F85wuVrs5FIS3BWSLWveWV44TxPoGNW5HMLztvCGca+gYNJ+1p2Lx7D8Qnn8rbP" ..
	"PzwQQISquKMNHEqPEDMmDwZuwBMkJz8SAkcbnoETD7pcV7mmYUN9+hjhv4KDOk119f1WpATFLWjmZ2vRJJy9ZVbxblA6tkGAw935" ..
	"K3lOAsJFRtyvz4PK+BnHxa3tq5iRBMEqbJvOlIkowXyWCd8Vc4dJ+iiR1lFE1cZvfobYIXH6F0DhVaKoks6Bg1I5gsH6PTyjRRrH" ..
	"fYF6CO7uX0QA7ebNy8/bbz/kqmroqaMQ4KyewZbv1MJ5IfMSV1rUSG9pQOkJkwW9+I4JfcdxUKTvnCxKpnTh9CjRCBBHu2e3Yc9y" ..
	"oICpwhxZbgyjL9V280Xd6Jem5PKUVyEQKsuAI6vy1rGi41/cRaOxVNQmQNM7Al5C4NVGoP0j0khffIoElBBqxZLxrigtWdcVhHB5" ..
	"8RLyOPClfLhg8VnENwCSc0BFsDsXuHYDnFV/AiBhtZyO4bJYR3sA2LsFxl0P9/MqceSAcsyYaM9H6Wt+xcWnmw8GOZV2Hm648utA" ..
	"7KA63ksQOop5ZjwuROL7CorAMUtb5zULiuA0YqvNrWcxDvBBSeik7qI4afyWXHOA3Boa7zXY43VlZx2WBQpSbA0M0OG/Npe2x3eu" ..
	"tvQ+bbjjUsctthxzpNAW3kem9x4OQXBZJ/iLop6Dm8GaKfUNEoPXZQFZHGQy9tOCvrm96oWe40zdncfpTMn2rbr6yHf4DDpnvZlh" ..
	"HIX39OcUInwPBwOxtFC7TVdgQJUJdJ13JdhBfLXAfRIH6inQcqY8udQ8BVHsArLly18B9+uhhnH+rvuk80vCX75UT2/FZDPM5irx" ..
	"JycRNQOzmut7K6pnhTlYxXkF5SZQYKfQWMFovA2bF5esgEVUjHwJU+idg0XE5pq82nXCCdu5MdHou68kykZSja2bw+YjJi+kYvgN" ..
	"BPhdn4JVZV2/PntDVfdvoed3clP4wBgVIzprwDj3jguLugjFlPNcVOtgYTkJ5L1pYEUINbAsy0eqx9j+15Dqz4XlxkX4u/v1ZS6B" ..
	"K+zVaYh4yFYpux/3ZCzDhLakk+z30h1CVZeK6e74WJup3PTzy2izWdqHv6Nw/t1F3FytDgpDkYhUc1sf2NRCc/6WU8UcBj1yW4RN" ..
	"D1WBmCFr4nc4sCKiKMl04FRpOBhE5cndK7Cp3iIas48PjNuU2/aca/UbcZ97hdm3kBYS/AiBWOLI/KfOrSRrxZqWthO9LNrDKCaV" ..
	"OCCYZy8hTQdj3v/mukVdP8Q/Qu02ivaZz8h2sdUJDMaPb40F4vQ2GU39x6m9Xm4g2HP7ZTUVJB8hKV4s2e5r4JxDLNpzgsz9oaVC" ..
	"XTX776JOlG/cjf1PdQ3Oz10dIpVa+vHNhgoZMvjWCJ9/mwlk1+KKQkoWAoWVb9tGpMCBVIiWL9T+jzI4OB7CqfSbdjzGTVKSikmD" ..
	"/TXegDw26DqqxDZH9JZwvuPszSKX9IgZaEWYy3FwXqNSTcEmFr2sNdylji5ghemrnAQ1ZoA0fNQwCSqR4hOK3Ik8uKX3Osgtt09o" ..
	"6xvyDx5o3e2z/lfHqySIgNvc/CqNDFodT6utOQnRbzwroGWVcYVCMG6d9AHb+M9xhCIm/XKFx46fwxTC2c4fxil3veINwXcG1SrX" ..
	"QequsaCKtQZ9/aIiDkNmLe+AsLNlicASoJOukL0C7gpW4ByTHl5AB2nPXJNsKfbHFvK1df7tXkf8/z3K9FI4Kf+UIsxwmSWY83pl" ..
	""
local PAYLOAD_P6 =
	"Pa5eUSRpPmMk2ctVEBFvS4QYKTLE7jigcZkTNpp8ombEyDAFI8xJPuNb3Y0XUes6nbKZuLgi/iki4VAv2PyjbQ2StzKd8lIVoGjM" ..
	"nk0ncJ9HfC8UzXexiiPMwQRp6qzUMoIxidGL8aNG2IjvzjJvZye6CzIYxmoaTBKS7QsJ8KE6DLvjm5jLatlRX+h+cuidEwzgtXn0" ..
	"2W7t729OmkHtTl67KZiy2N8OIQXFImTiZrHDbyPieKkvqE266clhF6iKtfOnM+eui+avTOenj0DZsggxncMjb+UAo+HjthoV7nsX" ..
	"ktF7+1nABDRZbxcnAs0+YBd8Ccc0dspD5mVXGkRTct9WiFu1AyrMyr2l3u0kseeQNOf77YJUr+Ny+oBPHbt7FggI9/aZUVLXCHpe" ..
	"S5xXQdOjMSenHP7k8hUUNFWLxDdE/G00qBgo7ccCdGjCFiXKPIXV1bJJCjmHOJBo1Fm+OEiJeoMHriKsGBUD/fAOW+JWcAKg4/Fq" ..
	"10b3xNQMDda0MEzqi2eRI4gR4egjWbP63Vp2D7uxltNui+cpAl/ZqxcL644To5jCRAuEW3oIH/JJjT68tGOwazXZz2jca7LFn2Gz" ..
	"HD5N1Yvaey0LE+OtDPMomrI7BK/CJPGG87JlPNfEnH2Ibk6Sax79OZ08VM7SXm1QlEl1tfprZcrLIK0wvwYPTUSlEpCNPUN5ORVV" ..
	"Us+7xFBDOgZX+Xl2fwGfv7zjmbi8XjenOAQGpI7OC5fAZ1sWAzcgjUI8kCha+B1Js5zM8qBQW9yAN7aFvmddX+k0/QSW4tzJkSwi" ..
	"xFgnxQ0oMg0H1dtpBnqbr5SdxVQvwuDxbfdjLGPIWXWQH4H8JEMBYx+fNgcG/TwIy/mlNnmFBj8erR+PDt8NObGMI59h0+uWfS0Z" ..
	"aVAyK6Cj/ir08oAbI6xAnlEHZt650di93Ia6AJs+DOQPMmVIvGlhx0YuFsXS/hVnUSW2/sDNKuWSGwLYjO0Xp3Xt3GuynBUUHU4H" ..
	"6pfk0k740n5nL9Kc88o/D7ZUOKArjUeNVhJK92mPJGsbzk9PunOFdMWLsgPzcdhatep7mkiuUrPuKylzWA6+3nymXClTDarWOzlL" ..
	"4ItdDUNwOSZYMnXFX/1+IAfYx4m+o7VfnlfW6CDMM6IAfW4bG2CgfsTKzmchp9CFKVlcyFUe4MX9uw0MKwD37tcDHTDXKcRprbtv" ..
	"X8B8JbfMnmuln6qSW4E78YS1nIcGCjP8gKP8ZZnDD+0vcH3JMY4db598AIZJa6knxw0T4Z0Mx81e5P8A5p0Ug4M/9FZ0/jHuVkl4" ..
	"RGQaYZotHPRmE7ChZoRnk4snicOsUJTxQz9PrxIGtYc4FgYQoeF/k4j7CFUhcJrcfzqH3+RvgHCfEj+Kn/YS4XV7CPzrMzWkSY4T" ..
	"HB7hMaRn50Y7/40VMQeKWookW9BEuXK9sHUP8MrtTsWrJooCMUbm+s1BaHWoco7819i/Qq3lZXIzMtHZfyBamz9BQaJvqZjjtE/z" ..
	"ETpNE9YxSUA3oonFafxUdMzO1lRuLRhExiZgP2rX2PHonoMzpA/npAXEajx8M/WZX123rP35MFx6eFCypKoMibmja2xczopOGzHn" ..
	"9Lk5ofS/eRuFNxnAvtyWweD52CW28Q2bWUCCTIlA2Y2mIoKVvUoY1l4oa0e+B17lPwrKCeOtcvbqcbHvuDJblve+abuRJjUEBYoI" ..
	"5mrlqewuR574MqS7Ad4IKKbbg6Gj3DlYcLWBEluOP/Q+12ytz90VB7CtaLhhSvvR7g+xRK7kWYf1m6xfu4kEnQgPQJc+Fv4+WZur" ..
	"9v9zFnlz4CbU9E0ABxVqiffrYKsNAdXknWjdN1KusrbH2/mSxdtiLUrh8Ewf09xHj8LnANxvmaZ5ok0japYcfkJ0bafVPd1qHlVq" ..
	"LTYp1t7pnRXTCZgV+r4+pRIJq5c5S02vzoTifBG4G/8FTfaFYQewcOZ8QnqYa8uDKHZKnTGlSZSgDiqLqHuZH8fE3e4mS48Q/kC6" ..
	"s2eT2H5w4BYOe7QQcpdmeJyn55gt+uOERC/lVZ8trg01IqhbtFRlFbOSg0ISNvZb7LsWqmd1ai3kGg+veb+qxkOgiNh2t1Ceh/xe" ..
	"L7dBRw7swV9d0AaUrCDkUJtzj6d8hKe+5/eI5qWUwpp3XnfL6ohFaCbs2PtFPy80W1lhheCLclWxDFQgLdiJdyYaUayFl6UVoDuF" ..
	"HrI11xcyf+WXBqc0Nc0HQ1fyJoXWrS7V8hkxRIf7KmxNdlISFTxsvN1DyQxImRDZKEUVDCMyAmVNFuO8YwjsJ8nGjAgIlvI92gfq" ..
	"/LlFyfYtioHXkN0Rsnlzkk+rgxS3zJ4pPqO30MbaDrJ8Y74sd0N3nHvRNtjIppZabR6pZwBPSj3dZwbsvL5oCu8OBy2wm9X0BxIY" ..
	"M+Q9aApeQVP4WUYu8DsLLrUN5URV0ihbBfmgP1mD/c4zGqXtry98MW9Mp7zk2BIUlN+C8U3pMiWj2NvUdo8FQR7/RWQFl3Lz25mn" ..
	"1849NHouhUZuITUNk+N8gbsoOublWZUe8+6e6kC/OfzGclBz0XQ5jOGnxAk5FFS8hAPQ9CF/mMxQnYNsnR0k/YuYpSPIgFEsIV0a" ..
	"087xAYV5j9/B28pHxjdcXOq3s+T9kFH4Wx61IDCJin4TQGWBYEwwDKsS64F3bxp5riNbPO7vuOOWvHAb/CEGr0LHpy8vFpwekeRU" ..
	"joPRMW9VPINBhjEgYMyriHUDa8ebD8YJvhSkGRe8/i5YDjJ6NCVg+xAEEXWcdPZTd8tHYB8rIXEwhah9EzR4HwySgm+wkMGNkD5k" ..
	"psMkwtuQCtH9eNFdPujKKmiNmMjc0lnN57Q5Ul9cmreM+B6cwrKM2dEnOQY5Y5Pc8nS5fjHzjZ/ez+PrIAxPQlmK+2Pq5RsRkGJa" ..
	"aooAIhDsx2omICI0EqwA4+UKpXEApEEOhX3bKSOUdk1+kl/HNuGFyUXz4ne8VtEhOnTABZV0Ww6pTZCJi3LRNf28/Vbb1zXGdtLN" ..
	"h48PKym2yAxfd1zkZVysmM3ABHm33um7HDnBYu5hf1CAAfGriJYO1XBvM3rPOoY4dyml3xhBuCUPeJ3vFzqSdCgBvQc4oOt1WFz7" ..
	"CdaacEpKWS4ZKkbRG745hS9gG5gmh11dhkoQbRdrvsW2PUBLMpHB5Vjsd1NoxBfz/CvUSQfxTlMY3CRJCSYqnzakQq9YClal9+6y" ..
	"Kz37gyWuCTBfa0i7/8Ohk0dy4O7dRbZBxzVlM+Kgcce97/kXiMgYO2f/gFt1VkzqDMpDVbfpvdZ55+jBVYKGSFNqTnV5DZX6vqyy" ..
	"Tq6+nSiQGIFLnGTt8pr882mqnV9VkzXtveWkASR+i6m5LqRe214YR02tcV597+fJg5wEtm9ZqhpEbUOfusvKnp/8uy6xuBGdGlMK" ..
	"XMamNXbJLdrkqNUKzagGMaqr4ECj7KgP45gniHVWTsQ8qKIqQKqTdAuYwWOyQldd3vOrmh8iNalLhaqCQmvoIB4u7FcT9O0RQtpy" ..
	"p1n/3qWyF+wejzrjrTAxewF+MXUvAq6YB6YiNwQp59ko9vIWKee2ZkAON5BNdxVz9SVTkuQbIWEPWUKjjvFCi1C07gtM2dfBk79/" ..
	"ciqra/V6+IAa/vS7ml/B7Sp6SXFCZSaG+seQS1g84vlmzlu0ZgBTgDQA9Ial0OXe7GTEqfcwTi+cz9Scv1iSqjax4hUfNBSgYWod" ..
	"ck+lmjKyipVMVfrrAoBu8KE59Oa4bci9dhTtZz+IOBAb4z9TtA/5WGE20FomM6YlLT2jrKDf11vHcW4BCj//WwbEdfqtyxvmXsIN" ..
	"ZXJxHDMOno3txAjaVMSGccgFr1j+6zdX5V9+d93wjhRiz5+WbGgBEWJM1IvX+dPgiXF69BJAxgyIVWSoJJF6MNUx/AKnvnimTyUz" ..
	"twIZWnS5ZRLtOKaTWteAKbUFzDjSoMBN2nNjCNgj5YzpAH71CxzGUGBzMESWMAnRkVKfcL8Qz+QlQCz58SCmSITkDiXSugtRf142" ..
	"WRsHu4dgECsdNqpA42yHuup3AZUaGsAUbn3AEz/R2P6Z0a+qNR/o2GBpZbSCwvbInBvIgCcBNebumlwia94/bFU01Mk/NnPMI87J" ..
	"xNHgipNq4RkWlW5nBYM2t0yEqutOj2Rna6OM+OfczOMHhl23NuBAFX5cqpcmv6BaZITVyBDClEjBStrD1Hfdl+B4p07KglKnbACA" ..
	"ib/Y6kULwIgeIHJtg+9/KV1xt9kwVLdphyycouF7iRlot9Sm3Hi8qCUI0PZrO2ANb/lGlOmzX9fyWrk1myiS+ug6mUMkCmGUYsEu" ..
	"eepcNK/yE5AT9F8dCcxz02QBJFQ91c2ZkjCU0BG1qz72wuDpQKgivadBFn/FnTLPaiGHiMxOEGYS1JPiO9/9OIAvFG1JpFPgwECT" ..
	"cDkijFzPrqj1BfAMa+7VLzQA7eLJemnunOjWYnOL0UBT+4QYfmDS7by2fr9li9gJH+lFeU6CVSvW4c38CCZMqQSOOHsQCDrRtISX" ..
	"AbJveVQ9gFD5KmxGF2rkZUKZ0RcdIrsgvxSOgz7ROPHmS6VopgndvP536AfvmeLPxS8wAjppBtC28Jo3Vj07NEc3Px5zTbC+qeTp" ..
	"GfLzWOSYPCmqXOjgZWsShLqAiQGFMLNdk4AgViF4sZhpD6wnTT+PPxx661aEXNx0H4Gy6Re69in+xuQtLTQrwWGKUWeYSwz/tq+3" ..
	"C69d1ugUIrk2fLV6ewXYoJPBpS2R6FNYAJfAI3mk3lMgX3n12y+k5dWWlGTo9Asywd2w+XGp6GznHkh+XJHgBFHlEQ0JsQYfXp9z" ..
	"tVerQvqyIT2U/LlUChhTBdXvWYD2lVed8r5yV7VWsyd3sQURiiTkzq/7wKqNS02V4Fv1YKgkj4a1EdWGt2KMcYYkE/tsaADPfKp+" ..
	"WjvB+pZgbj157aUZyuvKmbp8qDP8fnjnDO0bWuVosJzGsD09HU2fdgprQCMiS6Yn6BhIIVMHZte+5gyk3a8fgpQoBSmtBL6sMumj" ..
	"4m9zEzdotGK5HmGH8067oFQXQAXj2z3BclhgcmqZ4lFw3+5CBG5+/3kqMmO6xkN0pRNd7TDSmpXWeCEZpq9smFZ1O6gwWHTnO0Ig" ..
	"6gau5EUsy4eF/qSfxmnyCBHxRMCNUWTl5f65ExYfDv7BbICA4zagJEsCxOU6H76+9uejxpQeEM8KZla8+R4V8V8KreW4m4z1xbIP" ..
	"8N7bvAtSfIQTV7dVvQ8DohAHMps2+JPTVKagpB5p4I4j95XXAZSLRtuyRwTFvoNcD5HfgtCXqxNs0t1LjVYgjhA6vQRZ+GJH0SDK" ..
	"1Mw/66MBWEiBRkZRZjscMutEwWAAxcn33j9v7evNKM2IPq+2SekSx9zZsrmdL90vydLjkoC4gj0W6DgnyYSzEuZ58If2U7oudrJH" ..
	"77sYatZdPRI+Bmcm+bUC2XXuGm/hbr0ql9hvemBsayL28ykAJibNbNl7IkXPUbJap9YfcrpwHRIAU1oWk8CC36rrT6FDM+QOj9C4" ..
	"5wm2DvKOgUYXKR1TxLWWyGj5yt+GrRmv4+uXLCPsZBHThVGAZmH8+joLFxy2KJ6fpRyHtTsWg/rwZniH01REQjSDT1K4hR0k1kzT" ..
	"4BysczSD4w9oTXmCsLh60E3/szTjwF8zBHgVkCz5iQvxI/2QzvVn5Kb82zeajook6Xbu3GnsL4Uuv6cHDmV6uyMpcnMXBKBc+Qr5" ..
	"nNznh5H6MjQf3CxqS/s1yDlbNUFYMjlFz8ieAj3M2d+lM8PHEElScesEoi2VoLnEh+fGx+kGyNfSMBA8tkgFmN/5aQmoL8PDcLtH" ..
	"vOf/6uPmXtofRUixMA4Lmjks99yZAAzAUE1GTq4JUAagSI1GG63oBGZdEH8jW4viQvl3rCTXXy+zRI9tWWjhA+mzDMb1v4yQqzuX" ..
	"M4k9SUC67hzXWQOEFdAnts0hm4KBPGTHmLamtVVW8WfEbh8+TVBSRtP+MEGNwNAztqxzwCk6Z7jG6ZJOVXV2VLpPnpeJF/nVLmFF" ..
	""
local PAYLOAD_P7 =
	"OoYOqdfyWx4f6iQcfwzzOeN2Ld+I3jntrBHWeyKqjbGMtOhfpMKOBW14XHblZk1KslA+I1k9yi/e55sfrT9TyxvIyswU85Mpcrya" ..
	"JyuOxW1KHONTanQMcFMJlZknAhjhE5/NvvTGnqeqZM8M0KnOEFjoMp6WnVe0KT4vqhDsCylHULVzR9QtZQ+5R+9tN9XaSRxe0Ium" ..
	"288T6hlpuHpIex+TjIOaEbZuhE3sfFn2nQZKjl5u8TOiclIwVJwpDYK8UH3PflrpocmqUDcLhzk9BdH5XLwKy51yYJ54o1ISMj01" ..
	"np0de3zsU4etSghAtji4g4UM9JeG28laKz4f+Keli0g6pz2SM3j9SJa8xJ1n/EovwfY5Mho7MDrQJ/JnSQ8mAcnGRlWG3rMZlOHk" ..
	"ftaibWcdUwjokLjgtZIdFQSRbXXrNQ/NeuskOJR4YKOz8qCgw5f/rICbWQBkB9BwSXVIV2Vs48CkwLB0cctDUADSEZa+tbq8po/p" ..
	"wa8GrKhmevfvItoD3W7rQKWuJUG4noykeNVN7c1vWTz618rSVIwdnxO2nN+qWl3w+i19cU8HvfoUM0m40KF+a8czs93FREfruyzp" ..
	"IWjZCyrij6nd5Qgsqsz0E9Ic0McnI9KXDRPL9isLOpasY7BwxVeOD5r1TCiSJXAkKPD0lkoXNx6aZd0+OzuVohh6D/YWhk9F46hI" ..
	"Raj5b4tA5CGmoxwCI9sF/Rsociy54v9PNoyC9dDFfOqb97chgFP6o4tT8YrirSQUT0Hi5u2DUcIfuYaBbAwNOyJGMlTPcJ/nFwK5" ..
	"W32+hZNhEy0f+/A6/S3yUycR5mUXhAVWLP/M3BmmS29q1pIRA7Pzn0BtfHG0fcM77dI5rzYybhQ8jNWcTXy1KMCSwwRAvjJ6a2pX" ..
	"GYx6N3nWCfK0z2LgO9gSgZVPnTGCDEbxQGVXK54VSxUbc6FG8+Ix8w81CxUyaUtaXgVWVIkQf/yV0aCc5EL4Kdp8FbZFHrYZh2BW" ..
	"yWUeMIK/rOpQwZTto1c3X8ncknF5s51Sh3a2kZl3snEvfV6h46sRIp2PEKMTggkK95buw1OcESXkrKt+U/nq7Aiaryw8eifzmpVg" ..
	"bcq32J/P2qBP68xi5d60cFTmAwMX08nYSQ67lcZ6gesqpIcg4xR+iNnG9klji+zhuK0cFbTp+0nyFhsVnDIRG0PFotuRjBDoJEKk" ..
	"y5BmzjdU1wWc7pOlY/7pcsMOciufNQwScTTqqvDMS9il8gCoPvQfsFj4+9WU3GB447b5OOARW0xM3Uio4qLTRVV/XAV5LRhriQnW" ..
	"280qymfpCa9g0Q0GoxRBQZUG8HmxJhrdHIz5R03s+MVkj1hSh7y3y4u3F9xYcQkHj03EK58v4PJ7lg9Ey/r9WhRaNoKLCWefAQ+H" ..
	"UufT+Sg6rGABFYr5vBmcKJygXslx8xCXrY5me5J2ZzedfMYAmAjQ3w4C/VVjpnr4fW/WspWYrb6taaQZ7Hp5dQgYmj0Sve0p0qyx" ..
	"UIkBqrxWl+bZ+Iat/isA8PWsCqvxjpRvtaXyBQpXzckMGjwUQms7LfAywAaSJvr1KTrlV09A28A50QvG7yk6n17RgNQxq7ACu+kD" ..
	"zuL98/MOquJ8NeUX/DXVCEUVCYImkl6n6va3Nt/DZSf+PHSFWjmxlfuGjKIobYja26INVOrPloAYxVM9wx+6/oFPWSYvcP4o64Eh" ..
	"PyQ0qovMfKzdes5XfEsWGxkOfvT+QAZHDTW1SgP1HylrbPO9R7uWgX+Y6geG8Nl7OMk5DQ5w/NPJaudxa07FQ5ak1s+yV5SEMitb" ..
	"Sdrvbv+PEThbE+sK95hSOMAtfhW8enJw6fuRcVsWE8xlxWKvQJt3ANIERJOIJ71w5ulsSejjlJYRPttfqh3G5/6L0sN9ykneffVP" ..
	"SlpnXCnoLZ9SCt0JeZioSpD6OqxoRdXy91XiXcOUbE+Xz+tqJYW7q+r0cdVZm8OEyaQjdERZ32OPOQMq6PWDY3SnBzjqg8lZIzyS" ..
	"rK69bAQTTbXv2zoyEgosnPa+mDa+U+rnm/HQqQ1w6wwbk/W8vAr1wPI7paHTpqesJ3CN+90XcGLyuE8V1frhtcocc6ebkj+GfH4d" ..
	"XE+HjRpkWKxwHtm81NA2sAjomVVwHUDKBtPiUqdPLiaZrlmstLm4KUQT5LdJx6DR8l3mIfudrrg9gQHNOXMxBWav8qNG4X0+0E2L" ..
	"QEIo1OZ00z6NMhPbD6iZ1eHsejUUlaZWs8HV9SpWk3x4h14fOy9F8wWxyssb/IL7hM6/FZQirW+eOK8FeukkoM2ODvnzNirYsSix" ..
	"BF4Iy2pbNkaytPBFtXqFu/HsM6mttCTFB0FGAHLGgL+RFTsgx7/AQqSyczRwtRbSuLH+X9d32yN0c08ry9l2oNOOAwflKJRxra5L" ..
	"DhTlm7/vtdaeGtt9EFzDeu/h1MGZp9gc8EgjeVFAalGeXTfChDfgMABwdnD676ltE//wB4Bs8uTyaHywHtIMmVVj+UgqH/5Q/twf" ..
	"4H6rROf8w/1rS1mb4CPFxGJLxz08hUkoT6RQMHlGE1E51JLWlA1+FZu/2B4wW5B+GB/VNIs2d6OiqDbTpsQNZSACXn1pi+kcv69Z" ..
	"AppKtXI/6bnVRwEnu+2u/HdrUL39xDlIoM+CYYbzKcD3Ztv5GBiaPKOjxw3/sH3Y6ebwPI/cebopGG5zdZrfxTB/VQYBTo6OK0Ex" ..
	"5+HwtIw1L7Dwv6vC6vmvT4yxaO/Yk94ET4ZYdd41j7aDnUuVm1Vq8STQgSZBeNRtKMOWVUHdoa/x7jzuQDaIagZZWFV19uIYFVjd" ..
	"7RniHLolAJS5MbJa/X0G1A+3Po9k0tA25wLNpw3mBm7gKGeOTicaen7C5XxvQ71XGz4I9Djy0W/xPNgPGpf/PpZAycaX6qYoLrnd" ..
	"ONqryV896zrYoqjTjfGViThgE2gWJteUj97NNHB/N1szIJg6Qtn//SO+xK9GzK/PLs8r7SQcdAuf9h3WK+KT+xx5SuHxE6GkxyR0" ..
	"FiuWcwG/8wJ32ss7nserrG+VxntILU8neRfzoVHD5vh2zjg/v7eFnvqFmbUu1ED58XjbN7FUbOQOVnBsNWC2vIn61Q61VjnlRP0J" ..
	"2eFyaUolxtFrfmq7omjKQnrbaCjZADuWA9Nc4Qf5OZ/OpwMHD5lpqAOCXr1FRP+nR4+eVKrgswwyqKr6giFzEWrbqCp69USjyQ7x" ..
	"aNnzinyfC7f4TvppfJE9hNuHXmaHDfCyXhT8lBnfrIyb/bLdT9rvVZ0LZ4O6H0OBUZtq71uDozCNzIYaqYyugDic3yqU2u4Jy1aJ" ..
	"X7vG/DVq7feGKVerSqxqjXCTea0GzpeejOE4VLpGoomJNQU4+1YC1nPvC7RClwYF3PdixRXFmzh5kAlTzuPY/sDCAiZwABGDsT6P" ..
	"GXofg8c7jPgKtKEBNFZ7cCOWvocGt5JUXIZ+vqTg3DoUVBUTqKQZOwxpoe29lC9po7ZM8EOwC4+vj9J8qufFhp0UKvwusgfRCi3x" ..
	"4MB9Vkl8jOmswoYI3HEx/yCrIj44Xgkyqe54s1VoXdHGC3dvjzwaMmtW0nkJswEztFdZelW07DS9ZCXuhuKatF4Pz6xiPMD6Vu5O" ..
	"CuzHuR5tVN4GBpOifb857d0te/hRsnHl2oMfOsxcHcG++G5VoJiIkuY89eR0L5gfcnfWvUhiDe8Ch0FP6CJRd4LjKztkQdmmkcMX" ..
	"ZsAQhGp6m6eKVxJOKMiY0SOG05Hhl0DDvkHY6s/bh4NSsC/IUicn8RCpoehu/j2oPot+hIRoQqI3FfiXW6TkDYFcQP7Uoxt4WZDU" ..
	"e8ZiXQ9ofm5AwLdfNvQyA7U+rJZyHza54dVWO9DFMz6LsaT+j+zWEUo8h7Dh7TL74oMZ5v9PrqH3YCCJ34T7Xhv2thI6MJBSh1bM" ..
	"a/3mej7B+J/iDL+FvBMDDVfLnjWvOouQghtm95R5c10YX8yJ1BFLrlv0Hm7uAdBKE4RuMPHqtZ4ZRj/5c29boNQNFw9dBrsJxuA7" ..
	"bNQ182pd1ew0c5JjV+xhwm4Bk/u/wTWSDPfuiLHRbjkMPiLm9bdHoGKwHO3QMrHwC/s9CPFLDzZUlfEQRpT/WZm2+sRjZ5yx6KSG" ..
	"SlIXm/raauZB18NyYAFDnznQ//K+FQjYpbDJ/vCOikMrdxTXr8GTL+ANaIu4IPYg7+fmnrVCy5bty16lQKThN1T1fieC3YKOTVK+" ..
	"Yy3V6oiwsnTIkmrwytWLwALjUXqmXDdHqlztxkCLzKNGMp8zsV/mdjPb8YYtmfdEXQAYwQEphL/ZFc1HgEQSHRTlxxDq9g3hu9sl" ..
	"zlcpyxmaofgXNH99pves0OCYzKIMLiAGjsCimeLG2sD0ytKysVfQb/ME8mX85W+9TxRBU12innjAttqD/dbX2VTSIaXUGRR0gu0i" ..
	"dlKI7Tb0YrC2wOtYsu3nRulrv1tMQ1Fk9gQANR10fR3EB77TK+0/D36hh+2UngVRQ2DRYk7xQDRgjGc/twic8Ffu64ffwuUpWnH8" ..
	"/mJGi0cKBhf0VjJJHOE2xHE7Yt4Ukv/APnV9z0VkgAJGD4JFhsp0YU4un562X3zH+Q3yEw2DpK5JXNgOA8MHzPY4OJ9/2pMSEMwD" ..
	"hIKbl9GwxLQOemrhL4L4hDihMi+ksMGLSpPxEN88dcaBhsa17u3TnetEBCusRB5A1Z5svT9NaevCKqcOo5dRGSklE8QOypuZQ6PI" ..
	"D7IFG8L3TafwieK7oh6m3MGM526d7bQZZPOAqznLLiaKw/6/XLfU4kN95LpS4MG/8ZZkDTQ/izg4gNLzzFaJ1Jciy6djA4VFr6rd" ..
	"VtR/M47q4yabBINvTfxf6lkzXjmDs5gXSBHBTwvde/V+VRLttX6MSwPht2d4wU6wObmOUTdxlRx577nHJGPPVIM8YP9Bm9z0p15W" ..
	"2cyZMCvYBbr9HzjRcn5L61N8Ornml1HLXzGLwNevhaG3pSEClmdknbKQbOTzZGg+lafZKY59dr9vm25HDDDDSYGldUhsSzLOZHbO" ..
	"Q9yqXeUN7Vj1KP4YWjW+BcxTlqCDqnapp/l+orsuJo1704+uYXiyGU6FCAGMABLoM6oTZ8H0lzmNBlPnNP3IhzDj2TCTw71fCRfl" ..
	"/+1B2QuGYw3algorEfIEov0MKY5bP4m02HeiCWziaUNPsoz4vhkX2LU2OUz64f26GNjfASQ0Wha/Sqtk4uPy5z4GkuMmkAOpHqCB" ..
	"dm/ZQnqRX5cgzrcTGAm4PDwwdr5AaQd63bOG8pOK7FrRoRRRd0UyVBu1DQE1DYvH93MoeoSBIJwWFMNbKY5FSFPlYmR/Y97U1NP2" ..
	"ZbGo+gwkK7wpXpfuVBiZs9N0ktDy5mbhhi6fz770OubMfupQqPX3EIFJoN6uTM1RYq3PVNu4E4rFzidlNuMprp1D/97l8+Shezno" ..
	"mymdR5UgvFxu8BUCumT4gl3Aaf21kWraa8QdG/+KgY7aEgk6zoyG8FkMWxs4hKoDwM3m8LyPi8ZJkpBEM0lOg3bj8QsVHCzQQZMO" ..
	"oahmTYJ7hOzb+vKrSf1y+XR5jXecknrbSa8HV6kvLWqvtfvh7UtYphXpuKwi7bbq8ZsXe5AnQZAumb0rwG4TyXV+R5CiRcwRapaW" ..
	"inXOQ72B4osN/54CiLaYB3KnzyV43EtBWmSI9wHYnRqmYYKM9/mU9rcCY/Bir7SN+h4/KWND6TOSeQkEkrE7jC5er5wAl4Vm5hPL" ..
	"dzelLb5asnDfVGgx4ReCKrSw0UY+dbew+aVYgQjhqXd81xZ5Vpx17RAZZnlIYwQ8BpJYJKzqndlMZTBecHvDyoqkyc3wA+v01DpS" ..
	"tYRE5ePuHnAIFPpyMFvawTW80EQ8o4HOjsd5KmAHXzw6HknQMzD4HYMsklg/xssi7GQd7Lrhv2oO3H4oJz6QUNYIBDgQ9AribLOk" ..
	"VszG38KsFqBDEt6+hgQRCfBhxOT3c9wqVm8ijzyN6gPqAzj1sbu7Sq4UAZ8UoWabJ57LjAIQkXw7iQd5wcP9X3N3rl00qPRHeqCS" ..
	""
local PAYLOAD_P8 =
	"ZstqugP+WYJqhRvbG/K1vYB+LX2q++t+SvSH7Vu5xEWvqriMDoJPFF5PyuWZ27AkYLfwfnjkfFoskZgq7fqF4eIrMLfqoX/ZP5ED" ..
	"z1KqYT5IxDvfa0XnhvfJZtCUZy3eaJ/ldpunb98T0FK6vG68Enu4szMGPFnrCeCiXOoiIXt4/1Gxof+c+3Gm0A59wlzaYHGdRO6r" ..
	"UJ4a4k3nxBAatu8xt9coQbpXE0KpuiWDrvRYfMJvYOVl4mW4GP+OaZxRQE4VL3VJRabwVcxLJ1uZ8ieUmj9laFOK+fDwI7tV7R53" ..
	"XZsQz8bTpM6795He6Hyf1usVB9/8ZkqPdeOVyjElEwB/kEaBk3dLuiX2inciia8GqAaf6rBBOerz4M1zFVBuX9TmOQ8h+/tZNrWS" ..
	"IBR+vN0yjQyAjO3DCJ6boo/5AqOH9svdeVk9JoCDiDw+p/3OnjmLoJEXVStVtz98hieeJ6GP2R62S/UtM+lv5hPdF1wYdIbDoNZF" ..
	"cmIMJS5KheK30OirvPp+6xkN0mr0EMfZ53Ycl3KgLFWWXps6LLJ6p0rOMgaRv2p5Vs+XzIXApODsB+m80vQbNk5iFgyjkgHCNyA/" ..
	"aMXs2M2JVvwXpH1yZbm+IZ95jQ1I81AgPFCc45KqnCukNg2Y9NMSnftF1gQWXy6HiPCk2GQ+Taqmy430bnuZjx1yzPHdfVkrSnRX" ..
	"Y15kRjb0vhMlvJSzaD/8UhRVyenDna6KFGcL778nPfyCA54waSYuCNaOfzg7p0VHvyq6J5dEk8Rw31g0Pw+E3eU0vBrDiG5Xif7g" ..
	"rErPZ67vdZvW4bj+63OY3sGBU8IjbbjwZKUjrQ1xhiiwTdxbVnMPvUj11arb+E1yXw3yBTZxNsu2KBf+I62aSYtgltKNbN9TNxhD" ..
	"OaOBy68g5nWTNKtOmVlztyD5rGFUxtYIw0PuODmzdKn72irple43GlfZYgWWW/pwM0oOBupPPKNwKFREoHtA8hlD3qt5wCZbL2Td" ..
	"8r3MA/JY+loiNkGrEtWp+z9W/UNOR7hOgeweuoeTXB2oEbDsaa2+Hlwx854Zg7eA9Zjv1L9KgQBCfrP+nsNOBAwRtI9ucGX1Ao5z" ..
	"fAu+wtpJ4LGg8B5f8n3ZT/SxvThOGc96vYxoT4fsaRvuyYJpJD4C3/4OqxuD7PFACHlMPRYgfka1X+o9HTvgGfpW1mqmNwm4g66N" ..
	"jYckuUomZ3KheWPsrqxWDQZaND7KCm+8czzLCJ1KFtYxbgOGlUZ2eIudsjXy1NKpjaGWDEuWiVX+fPscPPV4CGNPYSkqrrVLdzb/" ..
	"/RXZjAazp3Qz3OwFvBS7SybAG9c2BP3+JgeG0j4Zs71vuWSv0ZDdqfB48dRAL11Ti9XdMearaJPOtim6/ULLEaBNIM1UsX9T+ZUP" ..
	"ZCd11y9/LOeMMjWFEaa4V5saKa903eDYiU0z1lhnK/j6ru4W2GNcncyShYnOSEQnIr8uKTepAvj+t7ZxMtBvlzRQCjZG9lq3HfTh" ..
	"Tf30mN+agKSuonXaDUOpPsLoqxntoyj8GHc/n7vHARSabyq0Y5S0+fsTbXG1l4VgzxTRtsN+Ce59mxaTwNR9XyC34Ni0LUIltYhU" ..
	"Y7UfBM0hVuLyT5NkwcwynCON2tvMmJXF3QobTViXjz9zsMwEiMdxu6JIizwqEvtGIsASxmdRIpPTowJDv+aI8JUTtrBFDOwe+Ici" ..
	"8Cd+GR/fvjREfKvR+EceM2uXYOgK+P5/4Nv/o6SbEe8rISzJ3OIqDSJ5UQCyaH+ROaVehntjxJwq6E99hfsCNhXPcmlpMJ2kCS7F" ..
	"6GdkQcnc+58vzJK2/JJFFTwGhbQhbOWZzWiuDI5aGcOFhHtvGovZUlxwieQr7o2BYEJ2kJBvFVwD9A2O+zjxaUec8pZaGugYJj44" ..
	"1ZDd5iVwxWUMAiAIlS77pkusG7bd9KrMGKQNF6p9ov9sdXy8CjL+QVrMWDjnK2UiqNuB3TztGFFYnqaAtnVjmmEm9Imn7BQAoLpD" ..
	"i3Q7QOgCr1SwXnSsusgnyn29BiNpC/PQOjoioiI8/e/X+TolrkkYAgyhtzJRxN7/dUDB8j3xqky/PPYpVtJN5O76poB37zCXVE2d" ..
	"D4/MoGBvYYr1VhmmlRqIXevCx88sc3g1mNwEEDCgBuIegFS6QpSvZbaMFJ2C65YIYqRPEz8Y3sHrhd6evtyqJGUjqtSXabbwYHh8" ..
	"geVLOD0W9Xhrdy6kvVWjbpYaUYKgKAydrTZ3s2qnzXP7P6574HoJzXnRbYL2kisBRU3QbLzKfRbyrZGM6AVM77kVAH1crPc4WCOb" ..
	"j96VKt+QqXtFZiWyM0kTW3YqCZnFdHtPpZDX8to6GzVmgE1MZvcs1jtkl+S5ePMflmCwNl/Bl1gtAwEpfYYuANDYViR9OFJrgXPQ" ..
	"iXbaMXS+rpk2FaEjxmUXA0Ha8A6davBcdZs8Jh6QcLKcwgeJKBNFuWIDYjN2X2ER9XXLsAdQ9WUY+lMviFt0G58A8IsQruzO6lwg" ..
	"wGPdUtZLqwp4J21m5iYkH3GIpVw4f3bc4Ay/nP2UCwou1cTjU8JbTxieTSQEGh20e16u3Ye2g0eLphgtWtWYi5cCnTG6mTU5XBoh" ..
	"SHCmtzQDF5vjuTc6g9jgbqvHPdu/SVtA6bXhFMEeu1INjRgQOWDBm1S/UG4z1HyoOZsBL4ZLjVq60wMZJYac+oqFmINLHsGuGsKd" ..
	"kOGWxhCMUQuju2c7ygmP05Bmg14sSxFptq2p33EW3APoJrv/gNhW2cPYoyJyBRvk2jx2GNpsSdr/40gZ+fzcLq5SM/uxjkxhYLL/" ..
	"iFj6SWcKTIouNKbvEuAURLiZMntLBlM5nhir4BNr2XmY1Lq2knJPhLEg4861ajParINM6se2wfuYJbbQdygHmCz+bBLzsmLbH5EG" ..
	"8l7mWrUlBDfZzqr0GBkysShKA4CryP2ZEuNSI64fSJciMh3x9hmkQ8lD39ROf6xr6/3RQjF647KAaAMmJOY0BwQ6N21Wlbr+aw5K" ..
	"3THPl3e/UurEF0KHQl5k4bmBdfUzNVRLpInJ8vruwzFqddNaOPW9+VafA3gtnQ+m0R9dhuSIi90E1yp7UUiPlVuxElCzVC8BTNoc" ..
	"tMamcwgetZark9hUGxr+X5PKGtU3WK+eL1gE7tY3yItfT+EVYcdTdaXhhRb/ofOoWieLf8bhDo1sTKXifZoDO+WLlmkLuvL1+asf" ..
	"VNSlV0kcH07uHMQsuz/ZIcG99J/lwjOloREV1PxzVLIpZ87XGeE+qhCJm3y+xup2j2oztztbR/9EqJm72zf0bbQcb2LVLYW/Lie2" ..
	"1uxue/BpntxZn3yIBBz078/rSaPFVBlK4vfquU0tZDRyZKh+HJ6OF7KE0uRD05mGFpXGl2atkhgaouckTc7YZqHiZQc4Agb5rcoh" ..
	"HBVAopkz3g2w1Kd+7E/spfSA4xseDx2oUfPU0A3VpekEFXZKmiK0OCwYz3LLkXMcmnNl1umqkIP8tblHtBE/4iNdJmbDTqbCrAiv" ..
	"6hD9StYckK8gVH6uO6tRs3/1W9k1taZX0/8ViKatCfI8x6mNFTusviT0/a1X4SjhKpM7kjuExsNylrEBkFDGekz5sW/lCj7lC2OY" ..
	"UD2jSjJlkPb4ut2SQpuyZ1+UR4KH/UxYAcCBFM87F5KKoZpQv0GpAVO5kinKzcrgt8h2vav4z7hynaz9PQqb09RWdLpGydXIoA7G" ..
	"29bmcJDDaAMwtlzpD4xecAIIPQZUYAaKyj+k3cR5G+VF+PHpcfc5w1l2NyRsDShVv0cGnvTsHniByAf0C1D6ycJZ0SEn7r9rc/nS" ..
	"xNVaVogy9Ov65yTuz9dKzMZzcTNUQnuofUITdx259x5NQwGm22ZCwqu2gsvfaov+DdX8noa2A/V8dYpx9yJvZG/ygDtEDxVKKxjG" ..
	"jcYTCTt1DQVdiTDyRE8piY9zeui6zToLkBw4aNq91DoPfsBxoQyGo/9UUrK/GlSMWxl4Fsy6v/I1q47dRLjdWb0EeIbqOEXTrRr6" ..
	"fgZ0dy8OJ47bBp0eF1wEFywUy6JCL9I15sa+7aHNpqhr0BXGZCRz3EDygcK6bwoeSQ7GjLh7jSeeMfcwWYinc+q17MpQGUuNK9ep" ..
	"utaYOyHQxJyFmt4l035ZKCmbSVaIKlfWZI+E2Ox2BMEsiRDmkrVZddMJP/8azjY3qcY+S259RqNTgZ2hUy/SrNO/O1AwJw5UXXuT" ..
	"SLPMzOmdPqoJ1HxhVPnnSwA1GrL4nnfSXq2PiLSR4VxEYtaJqRZfzWwt/piigMQ84DSXRJh++JhPJbbsi1YAQr9YgsnEE3HCHYHd" ..
	"yK/VV4eZLLBKD1/wzEhEWYfBQYYiT7Z8kOlRTWd9seLKIMK4oGrB+PF6UVR2L2ZBAdlJ+Nt2l+Qwmd/qMfzbxe4D4qihenHLfdZw" ..
	"eiPT/Hz9QPj4/mTwZSdKawxA69aKXk6uiOJm8jvsBr1bYlxR79icHIYtc9RYwXi/Jo8PKMJ8vQNf/0Ng4bhAIi+yx/lxtjhdQJW6" ..
	"ZH6hPsddHqO3VYnRZ2AzELt5QBMdjN5T/XKEykVnOuuC9EmjsGpSuCKy8iw+/C5eOY/7h2urNK4wQaUT0LEI/h0TOiOk7o2kmSyK" ..
	"yv9URLaFkMilYmhENo9k1b64CAHllCroGeqVJX/dTuxefxFtt6HZc1EuKBNZRng+vuGQNM/f7egfi8VkgJQ6R+uSzhPPpbQsxsM7" ..
	"XH2GsD23w5XEHfJWIdyHHIZU0xFaW97F2ex7NujoaNvjoJZMCtRW1bW31d7310G70fwCzVIs9d56u6XLuXLg/+j9Y7FC3GhdRo11" ..
	"Vp2lH6l54+zlfyXm7IttyDCOuqR3WMFRJRMarNIDlbS5P08D5ZF10qDZjgdvOfM0uv42WySO4NMxlmIEBv6dX9/ebJ0nheOFkzCY" ..
	"8NkeH2Dyb0Z7H6QCuKsslAMQMBnmw8H94iGrQJuu/wkBLl4SSX/DMfSy8vqXSkTRRv96+GdvVh3QMRFTpEr269SyJDLZ7TkthbM4" ..
	"Qu4qPVyCloZaykcerJr4JL9kM2eVwQu4l7rwA06638WJwQVl1vViq/I7b9UntoSSgB0uKXOpfEUH7rJcfuw6YAitSNBOpTxw9ZbR" ..
	"OVNyaM6Llbx1O7QJiNPcgNKpLQmZx0Gu3g/InPSpe8AMcslKYj+tF4nZ/EctvrDo63flVptN3X6xLxfgnFh62lQ5nvyjKdEz9BUE" ..
	"wagxT/I23X+phZI0MwOmhBz+HeSCakz9/iLqzWv9OaMGWkgmuwKKH25LMOiN8M44UkO4nKplzGUF92Ml9x92s4DN/ypT28sXYPGY" ..
	"UYr0Resb9RhC0Rcpn5WJbh0bkIKHD4HYgAyb2o4CbAhh29KDvKa7Y2nwR5+27sm4WKtY2t/4XTWjqTMMbqUDdyyTK7c3l7AFSEQJ" ..
	"h3+akCczfarO0eBdCNE2CskLWJxaLLhxxYlWxGFaSB36otRcBVy8yHe5JSXGoswaoJkQfwRAqUjjLM+f6u3IfehvcsHkUaZFib0G" ..
	"NS5BhFSGAAEMTZPqkhozHcjc26KzhPathW//YKLXdm/25Rar8DVaWxxSOqi/tKaSi1J4KjTGTP6xAFmmS7+G6QwoBaLNXQCsM05C" ..
	"PWlQ1JeAWK0xjzmsT9jclt3QQGLTKSChzYYcWn0lT2OeY7IXmei29gRE2uv0kIPuiYQpArUzsomicEXtmvHqZ2cc3WAwj/yhprCo" ..
	"VQFmFLnE2LhLGO2Okzhq4/yLASzrO6v6aKNhW7HticgndWHmu3Vi1zab8BkSOA+ehPzeSaBOjFZLS4Kb3E7z3aKZQnsVkGlD66ki" ..
	"94jpuTwPheFjrk+aBDVSC29aksJWZim6fZOzD1HhUFKRFFxISakP/VupgOgzbYFFGQMsSozPzJBUlrPzGoiUgpv2u7SaWRF8qicE" ..
	"UzyjslsZw+/IIwEyPb4Ifrwuh0mzlYdoLLyGPtqSJIYRIHXYll6PKDsalFyZKI4+VKA7G7j34Bv2ow8aVG77Mac/EaFolDUoJgVi" ..
	""
local PAYLOAD_P9 =
	"2Ge0HILkbGVBqsHvkVGk+7eMJ2swAN8quJzvphp45UDGTcLqhJN6Tiw9Zm+Dtn+gALABSmwVze1ZMzWq1jAS9P9dDbQYiHlj/WeB" ..
	"Ozge2dw7ZXnk9V1YrMgxuzXa3n8Yi0tfQkiSipEsPIijjdRGQrHyyIRzh4lcgaKQLLb3ghc61GNYMsEF7jdTSMeHT/eTTODzfj/N" ..
	"2305tOV6Ftx2DPFoGpBFcIyEShNgTytzW5PUhbXNx0Rav3NOBFaJ3HaWyybb4Pe7b7U2hOcEKZV9O1Btd2PkjvEiAIxwBdEF+3Nu" ..
	"m2/mJQHQE/iZAieE1zFv53jS4I1PRQVaRt62/oFhH9XJXvXtjc/SizPslbZrQtblGLAIPPG8QhzJ49t/Qk5WxBe+qVOC1fLXFT4E" ..
	"HXml0Cohg3mnago/JcNymnHS0et1WrnkIAnV0ZKlnd/taUCbq0uC21MtLY7LQX5Z4kqp14EZKRS4cJksk/GA3KHZcKI/8Z2anxPt" ..
	"X2AynXAJTBLmdmczBE3yt+YHLtenC3oD6fvPcUbS9SQMWyLbrDW7EdzzZv6PdydE/G84h7JTWE4GAj91BAzxREfxwjRq7ZbAhXqS" ..
	"lJcj8bCh3leIPrjXDs2sr38+l9cTNywo3WZF/M7//Nhf9+Sda740LeC0Bf5jaqCZQU4fQVjTPfb693CUJYxgKBOXl+JHSHJsTEsJ" ..
	"uHzWD+desBnJ/MipnQhcFgKMxmU49114X4PnSSWGJYc6r87Mz4vr7K1oKWv6jqFCqRqQZhtywvzqAVRKreUUqJLkhy9R7B5IFfSL" ..
	"GQSxAoYfrqJ4LQZ5abVoUYGNAQ3pu3tTfxBD9wepFaU6D43I8b9ns4IIRBwyaaa2XGSflaJh8rPrqyAfE8fZwoBDA3+pEP4eIjkP" ..
	"NfqTDXr/0L5Z8eGIt5Ub+SiLY/pYWY1rc+Gxn56lDQCeeeoBjmtot6dFHKmxsGGKEcNp7bNES5VD7briKr3Byr4VljLXAs7g1zYI" ..
	"8vWaeD3JAvHiuiiQpS9vGIASSjjZzG9huGvNuKRKkm96njWKJpNN7gEEsZBFeQjSg8N9QosB7+ldoCLPidTHdK/EcNp5VKEu8nnT" ..
	"MrJfkS9njvX3gjge/OjzsbU64ZlU0sWWtW2pcnBG7rz8Y14ckBqC643cnxKja1Afn0pKhYhsoavj6tnmJtlTlacqRQ2CkHnztRdY" ..
	"XkmOvS1tXANiYzUQoZJS3j//G4KsJMpjJW3s+eXzmSltcMGi5USi1z1YjEzPi6RI5mK9NvPSjD1wWNv7IruWloyl3EIkAx760M4m" ..
	"Oid8v2lBWcw6nm+AAHKUgD5ImfbZ9/F0N6b91k8ptCzqrc8G6+EIQOFnOU+qsYauy5MXwIKtU1pkUecyuMZPEo8i/H1o3P3jaHN6" ..
	"PYCadJ+vQgNaw9jYxkd/4WFV8Z4B02N9qlDrm2NCmaioYiyYBaBwKEr/Q/Zu+Lk9NpQQGWOIMS30EdINv1a+yZ2NkPWK5O+ad+dT" ..
	"/RCLxwb17xq63ObEyyUUzU9BU+Y7HLmNyBIApHHXQdz5NzA61kdHytYeTl6K7VnZi1/lJLhUhv0EmPc+nKaufT8e9rVipCzBpemW" ..
	"LpyeUOek3hZpwSGKj1jf0AhmPcEYKUn8wrpTKCtnjiWby3tqstFqBoyITDVFFjp/5VqSBqgSOMhXCqBEPnse6AMwYVz2FIUXwFMg" ..
	"jK7FyhkzffCeeOSmAZU7++7kg4YXyqXvxHuaYn8236wceuk4YOjr/daA0HpoIYPhkJzwOE4tP5ujlOSz9/RHOG5pgHoIPmfGYk83" ..
	"iS7qW8YybONJapigaB6Y+YnDXTj7Xo86rTQ+tq/Vz3ndSmPtPihf74ypuhQUqi0keysckEkgki9MINF0hbe3YrNCtiU9XaNSNkmR" ..
	"+Nr+2N4LVF9OV3dv+90C9L05hL06jRK64ePx29hDjOwa8fuF7slAeGc1dnEfSIyIv1CtwxJyFw4mTkXulhw04eHpxpWLYJnG5UIA" ..
	"xeUW+rMgZk6MoFzXJguTYiTwAWYp7/OgR7sNCG9cdXmX6JfYC+F45Sa+Ofbq6HKMhoQiIMs7sbPnn95QRNSUQG9Otc/UB3xUUaFK" ..
	"rGQX7delbzcQNTo30+8MbH6rcl3VRXf6CBtPQFLsyz5DWZB1hlFRf36+x4BQXXbWXkBBTeJlqOqkl0300w0Z5zuWqTAYuXrtuahx" ..
	"p0wDRmuXnI5iNdym5FRgo3FVMZRqE4Sv8O679L8OfZh/X2EKS/F1g60Bba5a9bbPdoMJE//zYJO0DyuZP3Z82P0QoQYeRLO7SOS5" ..
	"1fw8yqZwePoHH7TidfWuJdyzEzh1CUFSqqETOrLVoRW05LsaWCfuaXubIloHO4RVsGe5QzrReTpjx1AavXRGor3yC+1ld2C1yns9" ..
	"LuT8XeGLS/vO7ScZAMUMOyxOH7UraFGFBpV0gaOPoDKbk9jPWl2Y0G02JX88twfrxr0Yh+mKOdZvWFGGxuh/gOD2nk4H/UocYBxC" ..
	"n2uUovUzliSEU/o1BmdIeNRHr/zBPdoEVMVFrQsgQkBMn8UlAomykHqRKYoUNtEwTqAL8CsliDWLjP4NgwGmVvoNp3c8Yg45OvOS" ..
	"sJ0pZAYREnoSzaXkkHOd2sBeMnnqWUtwcvtordSZb2CdofzMTUmKCdHkS2vyyGok5BP7DKT94U+y7xk1ZHAluFwKNWhNGT5s95cq" ..
	"0iHmWEAgzicUgdS50RGiZ2T0V0qmfu/AVKeATaIDn58kq0UFdpZkP9nzwXK4hhdSI41cr9In0V16D+Wx+TflzjCgyL5x8X+uIs0K" ..
	"Yx/vSWKrO6xFj8s3GItXFOLd2pgpWCREYWPuZvy/zzQ0gCqdBoWjjE9NWtmT8wwqt8ZsfkVeMte6BY8dY8s1Zxv8Jp/T9qyISgH/" ..
	"MF5hZZSpz/T6Jrhej5ZTmO6boavFDVvWSLf6iKs7/4sJpDP0vilJlqmldN+Q7Si99Ucl/S/oub35/n8Mra5zzEGyl/57IltJOTzQ" ..
	"zsa+nOHPD4yjyvmF00EYB+gJbBrsXN8Fr74MA6VZNOGFMWAivkkLAxmueEHGRz+Yxvf0+25T+sXS8HOfGr7pq2+mx7ngth2PZVln" ..
	"tJG1En5uxin2+JBVptbcfNjEi6JJTMTm7cHuxdw2LeC+NPveKv2aMvSRQEZ0F/1Kz7/K95vvGCrPtgV7IGJ0/sW5uKHPWI9CLZ2F" ..
	"6dSK4qP5j9l19gS9dkAFdKlHgJyBabo77bhb42+JXDg7kC4rbMHAc3foAHUacNL+0Xoiw+yK30kONYxnQMz4xbS9mmvWEZM4UN3u" ..
	"SPHViALMQ3/dS26PMthtPT6e0z7KwbV7E1489N0eeZgVo/EuRDiSpuCrq8KGmbb6MHu1LT67dwFJwKpY3hCr/gQ7BiHZGRwyiGeY" ..
	"bS92gHNBiVkhM7azHnO64d4yc950/K9ElIpeUpvrwzuJMuBTFxTgaO7RHCsiSpD+yuuGQf7Wa9EJOKpGW7X7RaWwxjS2DDagB7G5" ..
	"BcQarmaLOqAFcEo3Cgjg2Po0m1DQU6pmpjvCO+zFtQgH9c71kGMAKYXizu2m1c1OkDCspPIIoUtnt1Vq7cCin9yw60m6YMm9aaVW" ..
	"M4KjL2AunUQSHew5n917DZEQYknC7ulYKoNhGsTgUsKmevUr44LYG3cicEyZDQyimwBycLvz/Ol5F6EpypAoTv7YTOQY17+vv5jx" ..
	"k1dl7QezXz9F38dJk0SRpZUgJ2TxOXJqhSyF+AIKJPmpr60YNegyD6qw3zUFTUQSOMG4hM3cj13Ubhc12clUiG8jq/I2TM7IKcO5" ..
	"GvIgxWkY63TdatFb4mB/siEogM29MOmkAqcRWd07OILCC8YdG/o/07NJbtxVIc8dgYW6wHbevo8HaIfg+eetc7tTlQdO4gc2Mn6f" ..
	"fgLdmqYpFjM1kNb6PrIcUlGPe05tosW8Tq2HmgdI/pnq+2llxfiDL1OMtoO02nGZv0kpkm/+wDFBJ7XCDPK1pEaDxGZO+0Z3NSCZ" ..
	"6zcdHgvffptfKSSnankjM17hPocIlMkTFZzLRdZi7nEUDoz6OQvXdeehKj2TvK17n81EAkodTQeAWr7BDh2CoH6mdMkPv4nY5M6U" ..
	"BSvCUXVALZGilykI0WTG7NbB8uqU+mER6ihgOifeZi086pyqLl7cGFqsS/qhkyDcbhB26AcoIc1OzHPdZBr1jxXDo6+axmCivtup" ..
	"A5R9aKSF8kPvQuWoiTHAAsuGMraJwHFSXgvzUfc7NYKICGPKOo26nPuBAzS8eT+x05hcKPrg2rQubB+wsKOL5lIAMM1GJOv1qL/m" ..
	"NxyA8oKcS9KF+N+POWw4oqMfv5ccTDgE4LArsJpUmNtkBtTcsILnFpBXOZUZfnnPSeiR3ba8EuYumM1GxZifpbkeB8nbIccKuLSs" ..
	"wXdrMOuBCmeZII28l3cKLctHwDkmVzw4cH48VtiMv0xZgbE2zrtb9ro4HNvX/lLDS1y2Q28ARgRdcSriM5K5JHtU7zeSzFpTQ5eV" ..
	"ZdSWxA4jtTabxByEyBmevXt3rzqm1LyEI10Xaryhn+WEN96I0nWNhq4h3bGsdQ7qiFUz9TKAL/9DbILa/rPSjwKTgh4VoiCEWUy9" ..
	"yLW4cnsy2WCGWSsLFsiCWOOmcm+qC0kdzonJChFZ1IyswLywmmcDJN2px39RG8KILxeKVugQQ+l0w6Rlk5Z2zo5kXgIIoKgjPvMl" ..
	"BtWQKFvnVaRxfD71XrUCJifqYGncWag38jbMdR5d9q4CGsLCLNTBmfGPXLA9ZfR1sK/xbkoYHxUViglqMu4cMmBtmS1ypnzqCu+Q" ..
	"Z4QLcC0scgFeUmQ9mfjXEiL4L7UbyueJUW9WbPimCT7M9wXfLiXQV1YPuHM/M/P9uYONATNECyoLtTcQ/tXBpxXxGrvWCAw243Ky" ..
	"njJnbYHmoxgh9c9vzsFYQjdgipIx6HlifAxZfLvE2vHF3xoJb9/DIQN3ISiL61nmpQEiGr3CE33MwHZbp62PeOp7bE6AMJp2hg52" ..
	"rfBkgsW83mO9xo+I43JTR4WHAnFNH3OAerR5iVNvhsBdMhy2+jTL5L7JsCbx4PyzIWPovdSqRD+2TfldYzcvo3XdQpaqusuVkqhL" ..
	"2z5X4h2jMwf1Ofb+lX/bGuQdgywO7wm+qDSjjFzhTowra69IzSQp4ih7T22dt4W1fICEhFVM99sWPsAfvShOUrGWvOFv/0bzKIJ5" ..
	"N/yixsuiiFwHZIiZ9KjjE4oHfierAhsWL2oZ1WJfqJvBIwOWyntz1FktvvWH6YpEqV6dDNli7QgM6g76sGeaTigbOrJ+0Bah3mEt" ..
	"r2vlZmIfLvmT2vZViBueOWcT6JF1brxBmEl0c2N9KH2Vj3+E+nAs4tn4v6x4cWeAbubxpEBO0qNgHi3fLqQgXmLjSzJuHf25dSlM" ..
	"sE11ws0ltK4g7I7yBSb+1Vl0xSVGh+qWxAAndbtMPU3vUy3WwPmh4z4mz7GhkaYYI3sLm3hem5zpb1ivbv3eYEsTXoix7YWYksNO" ..
	"wTPIYrTT7a4h8B6BjJkFbDJQZUXYDg+9WRBW/ZpbyIpQb0h77weAY5vPfKRuvGpvtgboDk94FMnPOWDmXx//sP4ATXbw1GR83n24" ..
	"eMiy0yq25xrwFu7ENJl25ddnbKgrxcgy1acdu6oCUnox55B24UoHCdNzr7KM6Z0vYStDjl79YXkxIfTdaagzG5VapxS2Jgsd5e0u" ..
	"LHbvW7pwYfUY5MTqGFOqTabS1kgPEOyxlhPXv0QObBVOkAI+OVlqEgcVQopfkKFCoPgZn9aYPkciiyaA6TV0XLr6LJNK/QFt1jiw" ..
	"IWQzSCnPStsAU8B8IiulrFUTmAlYlYDGpg+3vGgfsn0gWJvAC1t0XZTCQj/mZQ1SAwpDa6ww/242r+SEtzoxOwBiCv49XfWoXkGF" ..
	"EI2boLnZrjZyv5s/m7kkeNC+hy+qYh7rrvphR/BuFc/Q54EuwI91oH7/WgDANKapreb6n+XKDu3NRNPxyBo/JsdW/l1N8i2MSVWx" ..
	""
local PAYLOAD_P10 =
	"qByVE7DPDRv+kW6kq4nYsKYzt7ymS6edVbX7ly5lr6KfRD4CubncVa3yBuzFrqJXysYCRAJDtRYLlzq9aDxNs8hS6yg2jm/OSG14" ..
	"zE0tYWpEzBNf1Gn0qFe5BKkrAEsQ7KtyO8cBdyLiBF2xt01E9QVlWzIqxhj1lhiZmGuZoOH4/HFaagDeIumSxmul9rmKlOyL6Irl" ..
	"a180FFG9VmAc/WgHGSSZmiYzfiDo2qtByqVfAi2IN1/YFZ7VMWXPc34UzD/hjme4I1hWiaxiCbb3rZsPftUtyaNVPclSJmB6Wt9x" ..
	"BqN5Kfy4ipRv3RhDoKOReweMgJu4Jnd/UH8jQj+ecr/sxuCoYhKgDaKNxK19JFujZivh1fKhr8CohjEEBjrIkBhjWBw0tNIvWnFM" ..
	"hwUDrnrTZRdhs5V4DlM0R0R8fwm+J4M+PIZO4ESrVQDW9Sh0vGPJ10joaR10Dn1acNs+ppCoAkEQWiMe9rcOwvOmUX/9M9nl7Nkk" ..
	"boWZc7Osnqj6djtAJ3XnXdW2jeez3jgdM/lHnVg7l0Glpo0WgNWPoaHkn4ljTKwr9Fk25IeGttfJjdKMci37R+YG+2pKCFop1CPE" ..
	"WzKTI5G3GXCwRa6dTcmlAHe37Nh96Iv7b4TjSHfdrnxQc0xcxC7SBi17qKDYEp6RsOrgUITF3x3QIJSbAsFYSTVAM4uWMwGrSPxB" ..
	"LeiIFuLuZr+8A+r76Is/AGUpoOiLj2O0dccE0zK/q31lxycRGC+Ioo4emza3tKrHU50SdrIq+GtNj2QCz11BARHETrQD6AhFogkl" ..
	"UpnxOsscTlFphWhZ9ewZ+jId2aJBPojRoMDzbOUgBokkmx9WWDBKPdae9jmZH3usK7jOyLDxYtP02bjNQEqXdeXyQEeVQ5K3VEpW" ..
	"DTfeGcRuZgxfTWUQw3PwGdgySZGW6YSl1yQ19WKYXDdw68l8Mn8aneR7hBmb9mrgK2oo2MS+Z7FzeyEtO7GtaFaQRya03pLC7Fpv" ..
	"w/dKCCsUZaLOX2fJmXgL6b9MxyNO3Oi2a+RgzD8n1vYT9RuI2FAAQ6jb/kD6uxMXJBn8PbcVKp0nBuiMRczb5qxAhBb1qOzYwcK+" ..
	"bDsgeuSCebg+zyq/Hs21+D27vCo0JL6toxwiduFvvnXNHjoAUVzK9/Ct9KPJg1cLdUfUNhgk6RKpVgJiFyODjUMikP2M4+pvYVlP" ..
	"pBPcie3xDWpYPyql39DGyaDcZfPW2pr1K14O9mieqtvOBKagfO17/THzHbuhSSWY5tSpYao9FsPPthL/YgDGC2WNIWgcduX3Sunb" ..
	"vtWfgQ5XwV8RYmQoGR6PrfLqiffOePN8rchM7nyOHNEHp0gchAhwySaguqP6vLK9RNwlwWveybF6EiLmFUeV2iGxKCeOlZOazKi5" ..
	"AEyBN9JXNi63utwrT6PCLspOBWslcLMrC+mT9DH2B/k2wTdEmT/OBvItZh3szgbTeRdM1mJbBDEDmOgQHA+mFoScS6B96fXjyK/H" ..
	"Qfb+4faA7R3x0uqp9nCcvHT62BIt0bpUDu0PFCjCXSGnSR6NMYGZmRcQyKGBHAjZct1aNqWKh++LgZT8ua1p4ElANykYBnswDN7P" ..
	"KXNw4AGuJhkgPUzIGd93wfR3zYbYLqkdzIh52OfGb6FmScD1K8HakdZ6fSMGl2XUo72aLUP7HHhscGkL+8RIzu/5mBOk+9ulNlQi" ..
	"/i9Ecf0Cs4XO80tcrXVMxaluBHRgkWYWBkENWqRd9mWNB96oZExNM1YsjtEYNj5bY/EQbSkXpJevrf+M3/tbglYy78CEFehDPTrH" ..
	"xTKIJPNwQrLM7N4lnKlswMYvHeWPQUArYko3FrmbrimDBbeqSTmbWc/SVKIAdCg8S0XU8ey6JARkkOzA0rPoOshEbp8Y+RWPcYxP" ..
	"Lt+jlpQiFnKhsloH6vyDUzzgimzsFy+FXZX6QaeLQCIQXozaT1uxPEVGpKCsYHJlQc6C7WewqeG73sVOBZf/l+Yz22KgVdFrst8E" ..
	"gH4N9d0LgDEwGjfwjIRp1N6BSweUPMDl8nCPOwNcR6xewlMJ6C167b7dUTK5U0VhwbxKIPNzZUvmIVGAEsSw3tRsEvtybW5XX5ti" ..
	"YHV108R/HW1/RHxh0Ksu71cJe1hvSKirfyIRKWyXwumpU0M7MA3iKLwGmGb9wTU08VBCPuZtcIzyiiNtkFB8vr6gahaHZXXpcrdu" ..
	"gz7iJ0+kM4X6kp8FJGHIV9BKwzI+Lf26CU09R3W6UfgL2MN1c3y3gpdLVD5MfT6hmSo30KKwNmyNRVKd0FdX7+WPAO/q52hfrncb" ..
	"IYZQSbUrm8EcQ8aEZd/f5+gGz+vyzI5L10LjzwKDiy3ccCGJXPXFM+fb6h3xV/HLyOL1TzU2uVYoADLkb7AcPP2+Igup9yHcSM1s" ..
	"uhc0TdPcP9IfYUBp7xVDGyNq6KXQJLiTyaKBYQ1eIS12+A4i8SkHwh0sidB6uabANNHtlfy54O5dfc8IcMf0cYrN0RgtzJLTBBYa" ..
	"oZXsrOiH33IfxGFhsYAHvycXTsNBc4Jhlqn29MEXmfSnf7ayRE7H15P7xH5N0+FEIwNc6vAns9qpXojrzuwJEHvseTUXjQy6ae0V" ..
	"fW9DUpKO/K/+Q/SAGm6bwMq/mTKnb17ig5bqjw6N5/leBiy7X0UCLSAbCnp433zplP8z1mbp8FOfuX0OTZMfuXqilP8SBw8oSaQJ" ..
	"fxxl7c/HXo5aX73KCNVnZ4BsMZw7hTIELHihON2FQTXkK4tF51EqLOw0ekIICq800evAIFLbNNQiX3x4XWVJoSo1/SnHuWFAmFFl" ..
	"Mh8juocDcc8yVYyAtXW5zJsE5sBywjKact9YOzoH4GPnfgvp/b4oInfnX+AToEtObbC01ypZOYkK4p/UTCcI+uEgUPEAGxVSxoom" ..
	"Wdu4EA/dThL3Uxm/peOQ0shRgXGjuo/cIn0MK7Gvc8Oy1RIhkVfbqWv7azSUfls/r8USvt7wVASFvd+Us/Na2pIOqmrJnR8eNGhI" ..
	"XPp0GgB5ub1opMwKSUYis5FNED33hbkjsPnyIVOf0yecHibr0aAAiCN+SJJxm8RZA2inl67whnuF3BU3BIVh145w0OjGW7zw/zR4" ..
	"g5J89ujrPMs5r1jVMca3ijfRlo8YK7Zps21ftAXaNc55T35qReFp1OOepDLv2iu+mWWTRfyZHhIouWrMpvagAkmiVH3u28/e3n1l" ..
	"BCboInjAxj9+Pg68LhhGqBn65u1vqFPpgv0aGRxZReDtxmyY3gT3iXReqQRvtc75b682niEXOqYz1T1m6RLz+De1Qi0iOXll9qsQ" ..
	"d6o5eyqhVGSc1xIywZMFPzcwAXjwo/zZH1uCvWg6vQvLfFX+yqI36LzObwZdoTTZ+EArM9QNPsVztIIwT7cqzC80CWUW16r+o/l5" ..
	"1J0CZ0xVqoSBJ2QqVesv0BrRSsYss4ZjyIzFSVMUJx1mcpQKPcwTsfqO5PlqAKlAeCisMwLjg+azl6S4qM4IcmvoBHzjfDRijCRR" ..
	"k2EUv58R89Ww0wavOvg9gP/VTvhCFDcfpKaW1prtoqRUUvVQyPkUAMpAhBfjoTBbmioE2Lm9FvefpQ4EO8F2uajp4IRRIk6oTuXg" ..
	"ghFrBMU75O3fba7gPlYX20vfD7sVmykFNpQB4+laGyMD2e5XyLjKwubT7BLijcCX1uIZVnx4m3qJHF1+n0X4NbBggMEanoh46/fR" ..
	"L8Ek/q9Zhlil36stvorf8XU6+cGqjkZnSobDTJD2gxDnB/2dYZq4ovB34tPXaIvzy/WyVPXqHiFjUT/zQyfSnCpvWWFQKh8cWSps" ..
	"MNigC0ENkYdtR/5kDVisSw9PQWk2PMELoZR8Xt7aQoJWAez63HueO1OB9CL9jx/U5HP+XzpURGVNN9JXR3JvCxBPipdGJd9mVI+G" ..
	"qVh8G/qz/wjbgXhNoOr//dL4CAw5GVXM+OoGmeJPz9ZXNQg0TJCrVpWgxJsTqhOW/9Az7zkWxdCeZsZ7QeIJ0s28rZIMmKzabA5t" ..
	"KK2QreSZhNFE1fovTg4nj1mI8t0gFezgYellASy+PHMpl9pA5t83x+26V8bKdG+2X8utFDBzl6+kMIjH6Q9nPHe8dMm7QAFrtSCb" ..
	"Oe0xMZAOx1N7xsra6LsdinEqP0KJAWGLe/A4V0OREPq+WZvXMLzR20dsDR3ag3nd/aaCtNL8vwQsI/oYbFISI0Va0Omm7BAZ27k9" ..
	"iGUvws9jw84dxb0VaDkx/+lcuK25FD35gh9lMOszm2pwUitPTKiiTwAJlaeNrQx855NQipq9T6BKl88s+d4uNaPyhcUaqqMGNxor" ..
	"AUMuM2xXJ8q158YNizNyr+KpLkd5cZyXwHf7D18nwLObssx1YXT+37Ikpq9dKcgtBdCE6rmxMB35qJnNjLXzhlOkgqAtq4axOYmX" ..
	"mnTdVoHTpCcTkFD8DrCxbZiC2hsw6upLKdE8N1ggY7PoXQXpea7awFFv28JNZCHXAR8YTliGUv4n/Hh4FmZSdhR4qvcaYZbQfA9q" ..
	"CI6b937sDM1ZPgmYplJoUCB6L+oUvA0C3lmImwvW/mUnGTAOv6zmwf+k7WdS5Yia4iwIBOWXZnDd0hRYJ419GWAIfmhx335GejPD" ..
	"q3PN1yHK71WJIk6Isu0IX5HM69gCxGt2ZnXgli72Nu15yhzX+eTQYXp0FyKkm6zoRL/FAIet7S1MmulScqoFkDua1RSp2iYlrPVr" ..
	"Qf/VSmVUsvAEu2BwzH5OquMLceSYF83XC0sst7KkB+me2CaonlwW9bFnNqN2pmxGD7AsUKqsr6VmxK12MVJ1p3zcw30ocY4CRXpf" ..
	"N0i/7+3fBVZHfRdFGq2DaN+SR+wbwvFKybSxkT41+WVNOHyR5bzKCmMWN2FW3DzQmSk14gkIqRFAcw+BNAscfpJ83gp/jKRpIxm3" ..
	"iWhgZoMwfxsO7ogEyIPwsKv1prpew12oS4T61FEmarhCP/YpKaaWVHASDBNc0usSL78l1BntS/aL5UpZSdFAh0zURM90ZoCIfi/A" ..
	"NY+lQyZBcKSPoPwhz5MGmsELEeeOTPgna9Uczb0J/7WZAEclPDZPfyA2n0Wc7iGSIapvKpYe34zzxI0t2pdV8Dm9+QDTOyp8Jg8N" ..
	"p2WzfNnQcAjj8n22GsLHrf3yYwrL95X4buHOyV0SfPfd16nyHJTPxXVCKVglBaT8DouZIAA8aHe5VbnomdhkXBxrTptbNo/RHYqM" ..
	"jTBaDF7zKW+SfE/Yx3/DeHFe6L1J+5Sca6m4xj1AD07Mb0SPBF9B7+8QzmdMMC215hiKNhYcMjMrN8N65jQ1pbv3EFRP11hRwEk7" ..
	"M5UODKcmTCpZ/u9bOEGHsbu7MAEASXrO41dwi9iSENMXWft1XbFtPiDhykzHGgBWB5zVyAuCvnJTZQgA+WIfnI7SoxSyqCHlzPcL" ..
	"Qjzqts0xCWhe669uODcFP21IcSZQJYoWm+CcwNEtbBH5NSoyvlt6UNv6zzOAMFz2wqV1eLf5QsBuIASWuj2pJRH7UTFjCQpd7Syu" ..
	"A+FbSUPYP3jdDN/qRCPFHIeZG3OuflPyl8CfYg2XR4mFGyoFRSDkTPIHJ2cYb3ekwUWG2+UcXZAT92xLU6QKdFKG1qMJDNxtfXst" ..
	"ld+aYs+rPnyFujzljPLhtoPZmbQMu7hwSnpk6ACEQCQWauDmIiyqG8VaWYW8vMEqqQTRn4dq+rT0wxG23ed9VnUaWHfZMfF3jC91" ..
	"x7zUK8H+pMF7KzVlSHmJ8liskid3WyFqKAo3m/G8EM6525nDwLS47/rJMs1MjqAZOHqoLUujSLhPq/A3O1Y8Tz0A5spgDe+Dyxio" ..
	"rMw5Ou+Enh6+UTcFVfWCFA8zmFxNb/8MHnUYyj527QMsrn14uVZoNIJZ2XVg1xakoozDo8afGX1O3oV28ycYfYpWFzlmTDL7cd3O" ..
	"zGFtpMddNMWm+bO0Am/w0OwvqYtRs6+Y1IXqxoggNDYHtglhkpA086HLMXe7s/bo05nrU52audVxwLfYzfh63OTlWmE6qb6D3Cks" ..
	""
local PAYLOAD_P11 =
	"HF/TCClyqXFucP/fHcOZJB31l3BqTZBLJRnl7urAnPtiXiuImU/TsrVyA6FbUz43mhn6GHumTwenXgwXiqJJlo7cBQpg/nqfgN2C" ..
	"updLcS5GhB471Rtq5mclApcGvRlM9ZKJTOKltM6Tkn4jipRKDLXL3cMkz99calYRTMquSDjev4dvqm2GWzUgDJkuPSPjUNobwPTR" ..
	"NGlEhZj6xL4RpMqsS+IJkdjHYPVql/V30SW85dutC11K60QF9ndPtnWju53NRvBNXbvoghJ5yuj3gOXruipoA81Ms6okCm3SQeMY" ..
	"M7hkfCp3aTPMrmEeVSAT4JUYXvkeSbb8HeGhCK40b66jrKuqI6RAuWOfkZ1wgqjqV6q20F8QB2VxUg4M/lFR7NAueXJpNfDH11tR" ..
	"y/XiWmShCSWch7XRpZUl0qkCKsoeiSQfImiZdzGQk5rCUVWQG396Y7ivRlvfmTk/OmosOZLM5+w9Jb2Ive2lSwf46aIyJDQbsfIv" ..
	"xrPa1ijBDdQ0sGKVWD99Uq9crP0OfYV3Cuctl1a4wUclOtRBT7Jj+xCzNylGtTLVNzhNk9wQGNURevIaTDLpanEnQrKho2ynM5Bo" ..
	"8FP8wAYOjk5MAfjHOocjKxPOQ4F/RsNDNfnkbSMiE/tagtX5wbGpECukf+qPDn8yZUjMlHYwEMKQ+NA/0r1GQkb9eDRMnzMt0Kr+" ..
	"4pa8Ss+D7wYo9pY2bKpz19MgQK021jA6Cx2ln3FtY6wsTwNLm+Gb0gAtpVFlfNfmYtX9t0wHpYSCUOq/u5FNanxmL7i14CB/W3gn" ..
	"UmJQtMwILhcDBLFki+rUAAIKIw8culBddOfkwYTD2W17DJuYyPL8Ojjcauka44lgJGinNr3Tp6n+7DalfydFhFYrB3A5UbhIx/0o" ..
	"DAUmImnptUn3JOECaoyPTqlrj7O7vtnPJUejla7sg01P2ZLO4fNuhw2gju2MTQuPfzv+2C4vQYj4uwjIVGie1jkfbgGoUBpaqo7J" ..
	"bJ8dbWEalUB9cgWyvKjOmOcLBVX1DSFMFnfQY46mp4UKCv4r7THcHjjO8piO402d3MUNXVXIBE/vVF/7CLONHqNU9af3Ny/Ly1cl" ..
	"6gHyIrHk4AdonYYwccvHOI9DYq75uZiSsqxWZKx5TnOFXO4jrQpZuPFAJUJ/RCbQqgVEmxcj+PxRKIfwRiS134ajcSNvYFLokvS/" ..
	"f36LSwzAdg1eJR8by16N0nmJvnpOeV/CV2LD1U89/twzJ4RjMG2qYOco8kMvCDqTrh6fhDGbl0P0E+MmSnWc9PbbZiYKWqCgxZF1" ..
	"F+N4g0+xDTPI2h+S1635FtpXVrZDJn0PXIT7o3tEuWGNpwKv9U1089pUwcUFIxDkInc2S3e8hEmG1gCX54kDmJRnWQh2VqHRDrja" ..
	"BreQFNzv5dVnZlImXqAuiKp9+5P6dqpr7CYfGHRUAPjpLbdbe/9817TEe9jAe3tX32yS5hm/4kqGU9D7RFzHEpQStjPFM+yoJVnF" ..
	"PfE/IgrdvM7NP6AIfXMbho0t9z0SG1nTAP87+MgqU7j/adJETIqatMyWai9Mx8mj4l4q3wTALUcl73xigkrR37ON7S4lNF0CMlQO" ..
	"ibFlQiooj2XszAj7n1KriTty9nxJVSrRiHPOoP99jrt0w/CcwvzfZFWGupa2ccGmo30sDSmt77MpLMvtWYTjE5g6VxXjU6ezRcm7" ..
	"zLhBb1MC9vHbuVsBdpMy4uKsdeUaiv17UZTkaO8G21uAijBOgDPfaDj0rXaivqI+G9QDM80zuI2i1yfu8RnrKmtMLNqVMLMr8UpY" ..
	"nIq8oiP44Y7Xa1nSkG0TGgIcPmORqiX2AFKjkLfTRo8jVEvvJqf6mnDMOGF2pR3onQbUZFJSvswxrZ3bnGaJ33frlumY7FoqXG8E" ..
	"j3cfW3dcy31CcCUkhr5Jktevw6+6ifhkWe/bGW1i6xN52HNHDcCkZ0gnU6kLvBwGBGow21uPu+nXzNdsqjbfsb1j2GqcESOYxfZk" ..
	"qLorwmFhE1DmhmlIKAIXwTo4m5//7q6WzUyI7AYRQW25rh5SIkCyrurhkpBOohvCOGrVtiWJD+gtjP8YPSmECcCFmnjv2mWPQHgx" ..
	"tioJAIFhNRyBJ30pORoQQZxPB5ISpDztPVPmbETIv/+IgZl1ZvHxtx8i+rKqIi4OVLP1LwWFzDO2Gjyz5GjrfaViiTyqJsZvJN2k" ..
	"/yJsnFwOqB9k+4dtvVZ6VohCD4PXlbxfoVUK7zxPXhttcre5tjkn5Rq4wcvie+2tpr/BRoqJH3g/KHEh9luAlf6eLMlq/kVqvp7f" ..
	"jaCr+xNr4+JrkTSGsJWGGU7pBLpHNJcVyeA15tC+VccBArsauCrGxYebxH5u7u8PhNXPFEX3J/U8fWay0goPvXOWBvE/WV8LOq+h" ..
	"zdSAR+xhDmF9CILulxCzI/nIP5EPle0uKGdpbxW+JuGfW5Vj/hQK+wnW/tCc75Wn4YvORE7ZkShAdPRBCEd7Uu2oICsQUiRnO00c" ..
	"dW0v4jKD74/4ycfQ4LXJzYm8Xk1Jr6vT49o87WhkKx0SL+4zxYQzW5bulKjyfe/3cNMXo2o6/sT9og7P+ILOpedu11LLQCyU2Vr3" ..
	"DRcEztsdKcypYhuXpFSoJ5D0PGbUtzbAh6vOQND17hcZXrL7r4LLxRUhb3ym5Nyb6jIOsFJaGqcXPUsm27xR5DYOBLVaQmENWUWD" ..
	"x8xmOc+MxdReaHZZoJh3EjQeBsFSsVlDFnuAdyRv3EAweEcxLfVuW/8oZnFJ3iBsBlvLiejnBVktJaq3bcxjEn5eBP12NixiNlr7" ..
	"3+KsxJbxB+3pdXI1NDnapvsOUT+sBY/NhM2q4PlCIXZUMmnC9m3eKnY+8TlQ67hPw5TWEyC1Zd9sN2wjEReVhsZSeMZ0F/Kf7YUe" ..
	"Vv5IyRQiIsPrs+ZTXvi5RsKL0LcVA8IDtKv1/w4atMvnte9Vqhd7fL18WHqx1LNZOgMgEelNbq/e1wEUxWN+2skXPSDI7/hL5MtN" ..
	"kZF0Mq1pJ8QE91nyCuylXmJDyEibTW8xNcw1eboBwzigVX6gVEoNEeJO707ZC6uN+DmvsdpyhxS+1A2xmUJyRVuUjGBKcTQfRdnA" ..
	"5Ah+3AeF0hyhtcz+1qb3/Cq4ap6dcPPGotaKNKiIKyRFj58OwTAQR46DF/VkGuUe0NOM+SayBJBm0NrSD1iMFxiUeL5NDdnvzTz7" ..
	"untXWhLgrXZ4oUYBzH7MUUtijDw4lpAZaLhkRMOgChgwyAXBRH1qdrEB6Ozr+phnRuuMZsQJpcntnxrlGf4nOWKNLELgpQLhZ/mu" ..
	"1/kRqxbCd975zM+zxbZpbU3IeUMHBdO0Ulhu625y7a/sLZVPXlrtRLIREofbt3fsF1y6qNMiJlb7b3sHRqpkXkQTzBQnZaA3SWT9" ..
	"8KCzjmOfdYKodXocjjISectG5oKaBXehl+F6W44hgZlNMiQcmReTyVDjqu52FjGHoRT3cRoCtc/06ovu1vAq3hBKP424V+UmvL1E" ..
	"f8Nemf9gYAeOFVhvZDWF9yrYJDd6+Dt75rFalYjqJ+4w/KxVOdvS+Li2Q5iTkEh1zdp7DMB8484UQLg4+l/biQKoIjeyIfUjQOlm" ..
	"q5Eaq7EsPOBDFTEuyHBiCAVuCoD2qbd8W+j0Lh0/sCJDSAuw4dzx3PMQhm0ztD8JSvLTlpNHKRX4mFqrD0OOnMmiefqp39uTdHD0" ..
	"Vx7xuVzv9QGh5bTZRPQ4VowDrohJgXNjGpVro9aqaeucnj4veQcsbYHgEAXwo9k9dD0Gv+99Y59XDy0Lq4ryaJC2NzWaCYskgoIN" ..
	"vp5Ol6rpZjZ314vcMmde5vfBk7ZEs04X2c+y6VOYoIum0d0m0ERLEtEBykuZs+XemGgLIwIXWo5kMYCIaO0XpbxsVkV6y6FrfN/k" ..
	"L3w0ypuaVCgGmRBi06WftW74uQjDN23TbzS0u4NZhMU84tWGS89PDXF7UGCbqWG1NNiFLuju86tLWoPEF7glQekuBnrCoIDVNFJH" ..
	"mKsEWsWxiZsrDIfhyCyX7bLmM9RpeHAJdgENFkGWjJBPORQSzRmeY7ivLpNHiJg0L10tW3PXw/6G8rZF4TyRMF4Wh+bRoUPi30ko" ..
	"k5L2kGaHGtnEemu8kiss+JC9SmSn35KOhxDGcqvXsvzV1vt3UMGI+tmIJ+d0/HU7+XBrkOZBd21yUT5dHgWMptuSNClETFD2j2o0" ..
	"pTB7VPggDKpT+JFfyTNvXRNsrSFe4SKYIbbLRQPHSqsYa16bTrH3DnGUO2pupiO7IBZqmjt3/7Gw9trbvS/RUW3MtOYGxajYWAx+" ..
	"fCh/n0GLAuxgYq4nmqMlgk2XtzNmL+4a/1KDv3P2LhbrzF9HmgfRQfhEMwP0s745kqPefwtAgbuuBU/5FsNnevdemgJ0eorJvOQ3" ..
	"57/QvQKij0ozLumEL8Sbug4yx+LXGSfiYpoyKHSxnh6rEvYwfO6GIWHWsH0GglWUO7BE0mQCzMfzZwwEHDqxeT0ItIBZ7z/X76cr" ..
	"GZybuoWG7Qbccqn9rB4R3gHGNwWvbBcByPRZlZbH/AhfLPH4Tt3JGi4bp5t/WIxt853E/WTvDP6o+tAMSCLQVmLgpn3uACqV2K0m" ..
	"3/kTYDQarbz7vDmYlsF2mTHkQ8uHkTZMfjTVosdr0OMVAnGJ/yfNRZBonsMVKTT+EmMVnvwTGhQYf/N3aAAoAnJQAgyMGE+2L1FB" ..
	"14iWryyHFnmr1SbIYH6P2strHV682b6hrorAn43CAM5VEUz65M56AaIX/4TFRLh7yECZw0hqQPQUyzhFDqDhl5010ApEH5AckiW1" ..
	"XVOATBWL1OL9F3SrYSkMzvCgvAqEm8Ysu7mYnAukzLd0jW0TyokqHoCZuytX8AnjI6x6nV2P44BwidXP+9FGXLAXMaJ4bwW4m8h+" ..
	"V6Ua1tbEyzqvfXfuEI3tYgTs4TnTR+OiSwrjTAqPgMeXekNTx5seg6X3ixs17mow8d6xIPkoSa6M9eDv5THdIueTklntZhxswznP" ..
	"lkuMMgRQCWMHSazk62oJ5eGC5PQIZx8pu0xZcCSFZsD79PoJYZPYWBcIKroy55wK9AlRlArropOI6AdrCcD1EdCduQLcfblczkdF" ..
	"tKzbKmqmt+GXE9R9iOgupbGckVNjXL0FGdbknMaKik3ExfYYljcrC0LkytJJTs2g4/nkyW35MbaYqTFmJLjOsETA0m1dQocDxIFl" ..
	"W1eSbIpZ7hBi+NyxpivCLFpvKlXtNdbGLO1VFjK5okIL66euiFDFAtdeQc5COsQIyIxXWm/TJd0cmkNFuopBNiWWjmQ8LVcUx/ge" ..
	"54f3T3RX2Y+CT+xvEMYG3Db6oZ3l3C5PapkyMIXGhRtkMyY1aeTa16qPZSZVb5AoxcsJ1414//d4e6iK4rWlhCGk6vnh5ppdpM2w" ..
	"knJS3EHYnn51mFSkewxkROl1umiL1aOWjPKR0oRU+4hBwxADU00xKVg+6e/NTukYZuVi53YhjCN6H0DklDI5UvdeRI/3dz7LgEYb" ..
	"ePb2QbWqNIqHivamsYsjfExOjXpuVkDvQg/mTng5xEdXW1sL7hXLoKmeAYIbW5UvcTQdWaAL6u3MM5PvbOCzmQHLyLtljCupp8+L" ..
	"OktlNRCqZxn2iff+UTfbSvFD8WUAbnjiwM+iVR2g3hD430dhnO4oAm62Xzcw6JMBVdF+O3GxzYCTmbzQSeU/IZvqRHO0mwbbX19+" ..
	"/3LQgiqWfu+bZkf6pp2yjhKt1jNbSh2+JTeJXivZRF+ts+SjgbMIuGDxx6g/BvufslzCzKCHUM3km5vWiLdWWgiEoLtr5BQchb5p" ..
	"eXDTX5ZM6TeLeeAZuwFvZskxFACWjzR+5n3xA/0wRePxWJFTHvgkwsn8ttipFJEjS6UeiuvccbACeYVs2EZU+6O7JW80yMsLQzYy" ..
	"zn+Kvdv0jla1FkhU8TIOFJ15cPeoCAS7A+useJYWWZId1iw2K102IaCZl6t3Yu+DfczolRnwZsNbO1S7B5oWdJg+AZyybkZcCxA3" ..
	""
local PAYLOAD_P12 =
	"IL+kklYPrOANVyO+c0est5WtC7hDF1NTkcN2IGXpwx/6+PaYpNUAPlk+O1977RerK3xBRyzVbPA1vjQqWJ9uZdDY45qWwUC71Mgx" ..
	"8kInUl5JXQ6+hU1Hn3SOmqCtxo1BeDIDTwry/MDw9GiGW1sxeOZQCug3DT7nlhtu0iVEL1+wnqmGtpJWavViaWn8qOJdCwjjJy5T" ..
	"+LVluCVEGmlPt9POKYV98NvopQV10wMh54FeY4bXPr8Uiy4eV/E2SpSeHcYDy/ivcVxKmgHM3OWrzZl4F4L7FAvSLFBgmVcc64Ag" ..
	"mZQB3/BMqkSBCO/DBIT9oIksb+0AtNDNJJyhr4ygHgYyQ1ArLS3dRl3wX1Y774Vt3oNMZSY6pwSEjVyr2MvGZnkVnURSFjqP6CK9" ..
	"09QlLRrCaMXAXe0HvliAh1Cj4lkE6z/3SHD73CMchHhBCRLEXGsAGyJox5FdEqdECULGcBjhD+Xmt3vUsVoPRuHQldAdpIzezcmw" ..
	"SerDmHLlQoEEnDN5BRQHiHKWHsOxHn187rN4c+OTZgOTo37SzaZAYC8ru9ATFF6sqQdIiLq0VQC0VRy7d7mwWFCG8HXJpwloqmuR" ..
	"AXhz5ezsw4vI5A7fRHZuW0Cp7LtrwoaPWKROO+UAPBiUPxBizlq/mmczFjFQHrIJihPTLFZ7OKW4+wB+1lXonxeIToYO8FtRAT2j" ..
	"fGwdNJJfr4nDS+G3BRcBkxEYJQTstVBQdD15cpmixFXTKp9Yw8awPf4uJVdhy3g4L70+JSWZLqul1/Y/mqBkURHkmTty/Gge7503" ..
	"vE8ezLAq9IEvBZLFPBCONmWQe6XLYtUQsSH/xmRMyEw7tdu7/rehuc84suFjOa4lx7v52RY0utR37/ZinMVFdIHB2D1cIVQCxYd2" ..
	"vPX3RcuaFvEFc7E6SWytwYQNdtsggFHX78DFtluXzm+UI+ttEGCh9tOFd8L+FXn4BdOxM5v5IGzcbcZ5LoYsenm+D/qMS6VobzwZ" ..
	"jgPDL5LY1X2U+TBNlrBi5ZuF4wjClp069ZhNiVB3+PxMLNJHmbkQ2uYeEYRsZqsROoYYJoFi361avfDvoNtyOuCb7jQxepRVZ/8o" ..
	"BdpsVwwXIizsNa7iNgPkJxkKoDf0kRF0GgBJmiv/TCD+GpmQ7EaO9cxz/MDYUTT96XYkJbaKeHcYjzIrktmmhC+h4S0l2weBHifr" ..
	"5yjXVT2VpsxCxhAuUAm2TAdH82uImW/3+SILXxSgI+ysFzrzygmt2KeAtFqOYjQ7T483HOx3GsA+vWa14WX7g578dJvJSCZ0QaxU" ..
	"vk9g/cdBJ1voZiEY+WhwMzxxrh5LtjhcYF4DolTLH8MGBxdodNx+4BZoEcaUGWdXPSotOqWbbwWYB2AQXXPeJB/kkl8xA230q0fW" ..
	"XqTlj6DNdJQF4TpjUUU5roEbHGCDCZ4tl461kJAuAiqcYG27LUY9Rqxd6ee2LwQ2SZhh4i9k/+wxxEDAEBf4wtbjRZvh/07SE5Rx" ..
	"NT6xnppW+NtvI2pse/uCMv6Bqr50ZU27jp8SJgNzPEuFAPCVtIhmvDXWQJl+Y9D8AoDESJBtwfBEoGtuV0ftse/HvGZB8XL6ysnT" ..
	"i4Xrwy0HqZVQeM6wKU+JI+9GMq9Hw56Zi6fRGgY0XbfJKSRrsQg200jrfxuI47O9eIBgTgSzTG+WdLhIZRtjUnGXb7kXv8f7vQO9" ..
	"FUQ/gPyZ8XqDG1gNPa0/iJF8AdI6jhtCp5uPoaT7rgREcyupCI39XHiGK46F3ptLjnaQ6VkleQWO4tsgKxltQo/z9ubF8aegqiJa" ..
	"M4+2iDuc1r7+44xDj3PUmhA1ukfgZPBgrfvajD3SEpQY0Symt7UuH4HqavOnDXkhrvnly7G10AHbyD4YN41OJC7SfrLi5/XbqFuL" ..
	"kZTLcXm4yxdS36ri6ju00ilWhU88HLBrlIuY2aekzQ42ytDyjqrqVLDG6gGOYixVIz5rO2gcnZGL1jqiqQTbSeFJBnx+zeqT6bBB" ..
	"vq4meeMWFeYA660OtvTwMn6BUVsm7Zma4/bfj2StADAohGsvs+FdgH+uH+v15+CaPZpKEUgO9uwrR4wbqeKaAxxDVaoAJTqVm/md" ..
	"C38wgmmXVSXmKF4Q5HpiqWw3OARCu3h45+0iccNqoZIValI+mNLcNq5E53YG2jOugmhMe/BhOQSKnN2vPpfzZLpmr1/TnbYixjrh" ..
	"OvmQSotUdxVhoSp+o1N2IQrEFqFaUL0m5X3m6QTddsOyxwXXa0YfH4LcgBIcmdTg1UzI6qrRdwz45r3rwBKAl73g2BnLTN4jZ6Zz" ..
	"V23BzejnQIVhLWMq8SDzDdlEFPxS5oh3E0ynFymatXyUx2QvaVJqaOpuTj31fFCsnnvGeSj0q85iRe4WgAs2f1NZYLYHEG5vr/rJ" ..
	"ePWe7zhUFSAxa0VM4wgfZ5tTOmRWkyAUqbyL5TiiphRqgsidSVzRwLtamfUqZO8ly4GAhkbXG7iQuxbYMBJ9Vm4n+D4e9ILWwx45" ..
	"rXMYGfcVsW2/rpgt9D7hj3OdLw/OD8lzdHvv3tx0HXLuJXypqgsoKsbG6qJnOIck3p0As8RtjMKYXOMtJbVqTGXBB6ByaglF0Zy+" ..
	"6efNKnJVKJrbRi7794m5u86y6XcbsNXN1XngNvRoOPhyyHObUmlWNsQ1VsRu/hKO3JAJtsSYwd0uYxYhVYLj0M3VkCaT4hZ6r0uE" ..
	"sCEImRpe2AhPgPnN7VV+mprAKats8N5/mMc/ujSHOGiFazt0INt4hGsMTTbCDWse61y/Hc2JsgT5s2aZVR9bZBdrUxif4Cvyt8Ve" ..
	"BnFn08KxJAn38F9dpZ5nTlxy2aN91tGTAwAHKsNWXZNBeIzc2VjpZDtmxGoDedRQuxM3tdehiYlfOit8v0qg8cBoipUkrhYRH6s0" ..
	"jj3EBc/GPdgziRJaig0LZ0fZzt5tzTKjw95Xo9GuqVJ4RNSX7qUqeWE9o5tlg+qURgNTAhcd/5WVSqZUVLsdwlrvIjph0jFn4MFG" ..
	"TF4r2nZrIq/izDStioXVKfZkrAy6tJLycHc29EjwUXr5CdBxzdTZJ3CN1SUt4neQ6CVOWEE9y6R57U6QB1I51xNLEvQhAsvXWkH7" ..
	"AUxB8BiYNU7Z5LER39z9J1SaP+Lr7SLdz2luTTshOWcPKS98RUKRwhP+tSEqXbMZc6HF1mDisCLswliLyE9NCdsxTmexoJzANKUC" ..
	"aWvcgk8l2njNRjYlCcsTTL6DvrbCaFZlyw089tjXRIbyNizfOOIB9I64hUewQi0zeeKy0pgAq7DD/pRsZcGolndfMLjbbWmM4PLC" ..
	"7FN8nb8oadrRz+FlNCqq3f8ZCygi4qn4r2RnGpOJ4w26YtwFADpSERHuVFtO6gWwbNBuAsey0jVBbHeo7KdJzAQMkIWKXibkg7Zp" ..
	"ynIncGHR1l/yvsgpFcqMXkyVtZIg4+QgD7+LHz66jcsNjtKw2DA1i4hd5Zz91vYjuXyRt5p7qldmpux8zP4wfT6jNb3ZTU98eLK3" ..
	"9Gv1lpq+NVg8lkSRDljPCTdRJa+jhlli6iEKh0GXUQXqVYuvxR6YHhmKHuH8uOePmnL1Oo0lF+feKBewu0lEOUlkf9BQvMrAK9Un" ..
	"bAKJHGogGxN5TvfTm8dhmG17pGV90Zux1t+MZU7C7k3p/rOCFSNN9dmK6DL8jz/EA56i4NS/j3O346+K9ldeBoxO7r675wZ5ain8" ..
	"PAT9vCWrkIu5N9joEv+rYRNlTdDfbI+P7pnsIGIlj35RjNyk++PNlJod5gxOOAFEUVT3iUkjopBL4YsieLo6kubS4PhU5OEFEq1c" ..
	"/0l+Ki+581vW+DljHC5EMe5Zh19ylmTBKEAhaF7XJupG2eTbggi3/wzTKkV5qLSmvxeOTdyOJsxrVtxRsLQ2LSHqpLF4/iBEm+iy" ..
	"N7NsYhTT4F7tEarogiZ76qx3xmTBBC86+Lumz8G2jnhSQU4iTUYYPXA0CuJj1/hN/on8K90xIlg8XhNgDWT1ODCkTvEngu49QhhD" ..
	"SNLcc7WLBpbHGdvkrvlWccBLf8vEhsLyj5S8jACUEWqyKc08l7VU0oDozGA3SvZdM3t7vA2a1NwZQY6qQA72F8D6fB0eMxH0SKkj" ..
	"3FgYAFqW5zuqxuZuQboIBWbp0c5YOlYr188I2tD7+HNp5eovY1NF1G+gCtWcol2udhGDVXk4IU4QEdwQ1MUBOpd6UKhHQrA2xHxp" ..
	"95+wDjCHFmuN1ODISB1Whs9RXwT9paGClVnRN1Y+BSzA4F5izcsgiTS0wihKryo5tu0PJp3FCaUG9F0C2R/V27lxlcUiPlIPCRdo" ..
	"9iMW/MReNT6B7qbSrwHTl2aja9NcAayR/fIVY54o5rfRIheP6JzZWORELEnY3gveZ8tUU3X8OtkLgxE9G7G92gWC4g05A0TbfYU4" ..
	"nuqCk1hDyif36XmschnGEBwhNN7mQuY2M8TYj7uqwzqXZo3mPo9ToFV1UOKze/uOGlP22oD7hFXfm51cv9wEVGVzNOQb4KeWPgjC" ..
	"bLzG2ohiQCARjubRyxEmW+ABFC1IkSQUada/5LFtgwlZUSB0cca/cm6hFpjHpcA5Ht7sfFDrHbElwT6xQB6Uu3cfEFidyFoGhchv" ..
	"ugBPwcaerx4giT0ppube6GkynvCogcwDxhFrTyHs/U7pPygNr39jV6dkGWB4tyqyh3AA27lzj7GmfnFJt6pC3CCQFg9yiEK5hY9v" ..
	"FaUvNBTox0R4AOGGH8U150g+dGT2HEKuUr5cXysL1Y0NULlLdyFObdvmJaihSeyr20T5YVkUxqFMXCJ5ngWijJPwfXYG/tej70Mc" ..
	"v+FxJ9oj9qt5PoKS+jpvs86DrtXDs4W4WFciPJH2D4MOQjqe5BqmQYngYlz3SmK+wCploXNTZySax4vDgXfBcnrqqgAmQKIqmP/O" ..
	"O9JVk+bXrUuw3W9mrsAOfEHzOU5qgxTlC2nvXqH6/+EANApPHLeyTDI0PSJNMjCPsAMmjC2x92kA6n1YQAsWCHrJXAhvQ3wPVfS7" ..
	"nS/XpOMyDKiDu4VbtdaOy1umICm5x4TLRitwtmKfoEPIHOxLZB5s3apLRpZJQRholEbu4eLIBMiTIoMk7wuor8dtAoyZVpVlT0Y3" ..
	"p89Q4B+8+k8YTpX7qw27s6XB2eh2NnaLzpZ1PTzKsKjTyUj+JILK/1WDbFZNs0CcYxEw6eDgpHrhY8zhAvXCEj0uo9VAQ74kGSK2" ..
	"itZ9tBD+/qNGKJ1izXgQpRS4EbIhT1/UrRy5ZWXFpmy1iSO/mFHXxxEbvV8NAyPX543/nYHAOc/ULJoCFcnAUK86YRv2AVVcdxM9" ..
	"7r7wN/zTFIisqIZm6qcFUXMzE/s2M7yGjxV6kWedtQKGp2l54rn/MoD7Q9MeL8dGMHb0cv1JyY9tyZztlRsPyANNXnVcMhucBOnf" ..
	"VRZc+DmMDJ8qw6+5FucXBRt3u1HDiJTwcG+DVptfIDmg6W/g+FL7qPSQg1wGBNzFVFODD+E+leZo9Kxzx0jICZHVi4gJa+kEv799" ..
	"J/QkVo6dWJdtusFXEYBflv4NCNr+sLotpqiB8MuoYf2BohMQJykvTcK+CLG1nWFhxVPT5DQRFQwwDJj15Q48i9LkOZDENGpUdmLI" ..
	"+MMxjgkfkAzhVjC2pdIEv8aVtzSxzb3pSx23B29GEzwIyqSlxhu8DP+XHnfjrTMdbpw0uIe1fNQglm0YOiwUu/cjLgxYvEbCYfVr" ..
	"xguCf+I9wP245cps3MjF2pQjhmX0PzVPw9wdCLQZZA+VIS7vPzpnCm/s62b1r+hs/0hWDJLC9l7qySNA6mv4bdT9NfYun/eyXwFM" ..
	"/ZkGeGGvMZdijtv8s5oEL7g8AbEzi9ABHbI7+BGG33E3iZxRP80ngGc7uggt/o7nyEcGPQr6RbfzHbnEujXqbvQqOJzI30JjvPla" ..
	"F+bOmvHXRnB48raMGJkRxzsjilFaOaCS4JcSS2TvsMjgqjFBbDJuJAj9NncsTedZz5k5DB8RiDQVlvZs/ELvPAHAiodoeUqXR0hf" ..
	""
local PAYLOAD_P13 =
	"xZCrpXSqUoP+LKNifEaMGu9EHMqlV0mFK40CZQfvm0wBdDvObhP1+8/NVG9VRaePFPz216cPoIlnX+PVq6hpaScRPetmYBLjoVVd" ..
	"4GkzB98rXEYmMlzDMQv87QvqTQKVu5TTe3gCgIyVqddSd3/6Hrb3YbtHkuG8wfroxFsweUGvsnJM/dvsRh+PSU7M4QTHJKzgekS3" ..
	"Aw14rHqDWpVsFs5TMtCiXjJGQI2PQCScny3MbtU34EOPc7pAtNH7eujBo1x6EDfYJn/8QlWGkPiylgChXFpMG4EAnqQWDDy33wFa" ..
	"0Is6ZTNYlybK6i8M0ShPWhGAreRUaL5RxPel3pEUdJ923feCXrjy95VGSXXd8VjXmE3Jnlpz/zlejW5AOnssrn+oiIXUC6JlweHE" ..
	"HqwmLUnNTMAVVC2Vn0roD9QYvIv2LBs3QeQbNefy8V5F83+HJfhczSP4YxPdJrNOY+YY7ApmVA3UKlNLEeKyBBKyUsQFDjp20k1R" ..
	"oQrVOLn8P8vDw+oekujmylInOhhassrUZLrl5F0y5lqDwJ20jEy2r68vNlDerVZZ5u2RihJLINw/b1U5KlPJTpLAbYfLI9jwg7bL" ..
	"96yIM4iWVMB/5SVxRLQXR3jUvgS7APVlGKPV7JrpfFfinijb8Nplz6l4a6cCfjH4RDdklMGAjrTnVksIV2E5HaGSmiZ7u/FGiu8k" ..
	"pqfkyyJJeQPJc1j2DfVg5uYgBTsndfjlCGpO6I0jwQ7aiNL2kZ8JblrUSl8bYg3CGgQTkjLlrGqzxl+2AG5lEoyqevNMtNDXtTZl" ..
	"UgeJ3ULgTX7o9Qhpct/VzatMbU6nxN4r4kadRpu5gVSc7VxYIVqF2wfRugJ/FXnrW5qhQF4B5pmEDhZwDcOoaztG0l7e7gWTJJxF" ..
	"1sODwVjSlfoM31ViFMhHwB7DrxLysnjqHkEWW06mTNlBcZjcqRZjkPLCThx09lyLcpvV3b47+Tpn3/PUvWpGHvVYDjjUPHqUr39K" ..
	"BEg4iM36QY0qAwqUc4cGx4InZIhOP+qbzHocJjTHE2UM7JwhX2yp5cs1KXdQv1dstVtZNrvFokiFJN6NBUZgGL9CLoAeVpbP6Xpj" ..
	"Axqtao8rac4UWgr3/vzOWZmk+EJHQHHcysQvehWbG1g8SbZWGvCLdSNYNh/pES2+DIUzKXb9j5zF9lgHWfaALE2hixrxSUt6weLq" ..
	"q0xvH3qiP9+YYLBDF3g6qi8e67sPlw+El/3y1NuGt2INnURdyz57KEQz41+ap2PtAXJYhLs2Cdm+TTU98CCfGS5iCsOkoTWfPJ3Z" ..
	"xhuIesqJLwdUgP3sIITnypKV+YyCgXz8CAycvtmELuGj/e43h9qtvbwX5fbdjc9o4l+kxu1xQc5Q/a9XAFTFVNOKXUxU840hRl+L" ..
	"C3ai/PJ0oqd/4yp0hb1P04QWQfz2BYMZyOCDcD1YCr6yOEvsf7lBUxFW9JrlugxnTJSIt72ZlaeN4q5Wfp43PDCu36zsssNrIrY6" ..
	"1DsQQqMwZAB5Q3Cs2BEhQ5+Hx8yviJ/NKo90iyfIt9XV7nFdqZbpfGsf5eZpSaVGgsZ2e0AmnIiclh55/HS3sw42mcGNE/N/zBRL" ..
	"ThI3/dsyMgaGN2s206rxKo9MXygWX47JZYl3KJL8z013Ax8+7tXeZhVJ6NKk8bgl7sWBXypntTe8O0viyxgnRG5Fk6hALnLbGFSs" ..
	"AzE2krIZ1uZnnuatealFuG9qJ74spKT2mjPgDVGKDRxZzXhBbkTr7bRgFZcnfuSZTvYk3qPIjW/qSv3VRjZE2gHTO2WYo54Tcsvf" ..
	"OyBCqBFEuRuCo23J5qQgzFIsHvFIfBVN8f85PW27NSnWIxOgeyWs3cCkAakwavH+TbwyXwUcmybUHvRvUVs0SOneEiTPFsxk+Qq4" ..
	"RDXw41aiWMO+1QVlr50JzOUdcM+S1BMZzqeHyovZq40gxzAwZ+s68YjA4hFWdwo+usQF/Y697N77qbl7pHvtf/bCJzL9GgQooqsH" ..
	"YqN8A0lw6M7atZygkD6yP7/4qP52suBqHMKnl2Gb9cnlH3wzH9xOtgUl6IArDobuxxkg791eJfFqnzphM5V/0I4++Ef3H7fiUyte" ..
	"Jcc/KMeoQnBR0lpxpZ6kWIzPDnNdC3GWzHsoLRDhDOApNjKsofOdrQuSIvfoy/S3nk8FbN8TmjuZGeZkn90K0azBbk//S9rLa2HI" ..
	"OKI/WfOqTEpmjrj4CXgd6g8MPyk4zow66Z3jeeB0zG6eJXednKejKNLfuT4zFuwoFWHlsyZ1zNKrsLQtY9mWr/Qwu49TYznDmX/e" ..
	"OFn333NJsBE8QHn2CSDTsOIkneKgXtkxhH8ev+bv5ou4jzcac43Zq2Zhp/TWikRlUIVxRpv15kuamSsxreHR/UJhhXGei++8+FnR" ..
	"G1GNbV+7IeROuPhNSVzdVhtfZbomQnjZkbn/RZUChnlJtx3/rrlwFn2nIMF/SDG21jATcjb708FiNHYlxnx+05GxDmdAUBal3IJR" ..
	"IqZKFCj8W5HkpXI0OWw5hu2kMs8sJyxYxt4n/jOgIvOAufhNc3jHYbDcAm/vTOhMnwf4vY9CEeJhEX+98/VVkJLhtk0czA7lUDRG" ..
	"z9RDp+pkd9qf0XY5RW49FmB6raMarcYYpj755cXYmCOoOAhUdhwB3A9padPcRfLRb3+685pDKDmfVggfA11KNXTr3ViJ81sBqdVn" ..
	"TpOTSPgx245Xk6R9bflj4Rz7QT1XQYeky5QYFO5nbXxLqU2I1lOEdZOCOubIbW3hhcHvIz6VByJ0YnEN0moLQ3ectm3X7A6f5DE9" ..
	"sw3B5LDEaITjWiF9r3UelXBh0OHMGQkTXpo22GO7Q73NgAUCV0iM7G0z1Jyx9esnyLdMrRNVRGT3boSZXMo/bpeWe4VO15Q8jkzA" ..
	"XrrG4bpiLvWvfCfbNrB9DZ+n5SZ1Os4hdtt3D/ZmMaTyABRYkcf8KeZsMUXFqqV/D0y6ec+NC4GKUa11BUpImTrSNERkXbdNQwBk" ..
	"8n7N270eGBhaxiVhn5l8ySJ4ZQl2Z/b86+VTAeKFcParYqNLHHmBgfddiowfMRabArctXut88drxt1YyZsmbH8HBnI+8Yl5cb+6y" ..
	"2kLggcqwIZId/JidcJ9igDj1qSa+uWpO3LB8u4PfmkDyBbTRpsdJ+N8U10EOMhPRch9g55EjBfhYmGtn3vj3PijLnYmwkFbopZkr" ..
	"0b/7v8W8pqvXLwm2vpAJDmGTmy0qD+MxHaGrUQO5n4wjeNe4j+NmokpzbalK5X7IX7aV3D8AcqppXJ3+DDp1ECFD6TC3iGM5Hd0l" ..
	"q9NIYp/DLH0GD5IHoqfQsiWDCwtJlIe3kZ8PsWVVeBaazihPaxPnbScRaJmenQnDxjPQq+rDWO5PNY5kbm1q7b31NpfUuNECQ1yJ" ..
	"r6rzIBZrL4ybp4rZlQjHWpQU+KpyJqYtvvGzg7qBmxym2EOeb5fOW39G34F33iQi160uKsajnyCjeMad31Vr0vJpXEXEIx9Fqk9L" ..
	"6p8QMhFylnvYsD4+MuNoq4eYlOFBqRKZcvCij3EFzhn2jIj4BWeK8W/hDH9WIg4vBv7G6JQ+Y0iZ22nyUxO3WKTVL1pvM/IF9Iva" ..
	"0p7Zr26nsnXWLUUF5IqqjXhAYiV8REZytX/VPKkaXsEJEwnPZHjrbxs+xJmPsVSId3zVatf0CXx330sXwmtaOMqFqa3U4dWMz5LF" ..
	"yIumVLA05m0v0roUJA4GkfFi2+o+CaTIJG0IeHMYITRj88gMT4XaSGsomDJfBIfP/ylTooV8hjOSx0uDGHuV1Pn+oMrN1jDEblcb" ..
	"xtdFkV0CDwXM8tcZWX/oqNJCO/DumKTUK2+0WblT05qwUadZqkuU3RRMCTfaxe07dJY6Dpq5kkDZEZp7uX0blEVhyDSfqRG5vse/" ..
	"iQuMjlu3O2VS13QbsAoHZTsazXeAzjASnTHWe99f3iGRqqCrpGK5ElJk+f+ogwsu6j/c1ItWBYRHzFFlZ3aV/9xmFLqg6YHGJ8g8" ..
	"FdW4jhHgloRNN0jucRF8AWCU1xKhRQPZezuRdNfSKVYGeNS0IIs/w+7VMgHaQCKIllpxveIimHqnV35imeaPuDNdcCCauxi5dBna" ..
	"slm5CIl29yX4aVwWbn7S5xT+bKSAjB2o6sbe4qx0GSkTOdy6DrryOwF9peKudG/GfLfDZSLkQhW2iYl+6ukEhJlqEkbVrqSt9A4D" ..
	"GtGZEmtFib2GP/BNYaA2ocZcvN2yPHk8j00eEVv7Zn7gb4ff99cMfzJ2w/66M42TkuVDbJSxClgF93lLEjXDwQymTbcZ9OuLmRXY" ..
	"Go7diPyn1eAFT8LFgbx0OonDaxFHUmtFSqf70TCMNJsBWwu8E2uqf/uwVSfO7eMjQrXZpkGhxItxfPW70fi/6IZpTlANiQJQyAwP" ..
	"iYYrZSZwWhRGIlpfkLRurWW55HLfhyL68APOG7Wmjgovkzejwyi0zeBFA1qiJRZZeyKzCNeQEINw8Xm7hbad92PwOyuu6bqqblwt" ..
	"fnPgP8gpgaHm4x/UYfILTeWCu1+eNNlR4TWR81bDLV6z+aRr2/C6kHgiBR0LNJt+X4/8d/hNARIg8qEOJuMOiBNfqNCd4jOd3MTm" ..
	"c0pSSzgHiqtx7nHX8IUra/wLXV9uJMIJDmmTTF2nl7YygPu1NuKC/6wUFdNDUYKLTDHbY0rMXKbbGB7amIZwkY3/z5oQjBrTGKG1" ..
	"uuVK5B72dH66UU+FfazuTsDzdDvoFwrmq6zUc7fRbwYHsUjrVFLxVEX2nc3v6PpmevYpDSJuSIM4WqNGX9ChuydWr6OffFUZpuJA" ..
	"LM5sAcff1BvBN+kfp/cQVat8UJeflmfl9e7ZAxxyDlc1MCyxbbEYdRj1j7bPBti1axCJ3ZwSGT/X7vHviHkTpUyis364VpCF1K7C" ..
	"EQx4Y5ma9fidl+XML0UWcc0fu+uqFB9yEweQnYvsfbmQeNarC8xdksx6iaxdZ+YRq30lFCfKsj/N928zkf4FwcPAaD6YUqPwd5Xt" ..
	"ZO+mcQQTfWtfKSLRHDBKElb1hzAQiTm4+mqyCgzuw+ug1pe9En5KjiQNLckhj5Y/8aIlxYoKm3EiH1x0WxpR2dNPtDOu2L5vlGz8" ..
	"5kU39IFCjC88hGG9UIscwVXSyYRNMygDFlb6uXP4ev726NQEGJNer38KclvEmIXOdxh1vcxrpUlNGW8CyDn2Psc4FOKK9Kp7uajk" ..
	"SZNZurusgsRBJ53P7u0R39S8Sdw+Izoc9ZV9bY0NhFg+dxQmK7rvI+R6ncQvWqiuW4Drar5g1fyv7TSD0Q4XCXOJJ29YV83tb1DP" ..
	"o5de+qCxlzOW5z6OmoQ1GtOdjzPjPEbVP9XQh1yJZ1sAJyr1zyLKiv5pAnzCPkKmcXV5nsYbrrCjOcxtnt3LwEmO6DyvDez/GvdZ" ..
	"aT68iv5xetKXgO51VJ/C4h+h1twVLbo8hKwptaXRf3I3ccFPa9A+xEmJhnmiQm12FaGLJeVJfpzK2TgKu1xnagdYdzsSGZ9ZbpRt" ..
	"axigEok4IgChxGhVZDYWRk1Q0Eh4saEkmdLh1Z+9+VO6nUDOKzXgsYx7RAUxGfeS1jtnfBGoKjzxEj/+EzU5ofOjrbJADciI6b0x" ..
	"Jueudsuhwv/vVPZ2//5wqt+Q+UukSLb6cnFZXSWV45Lpf+tzADX3Pe/5n1cR" ..
	""
local PAYLOAD = PAYLOAD_P1 .. PAYLOAD_P2 .. PAYLOAD_P3 .. PAYLOAD_P4 .. PAYLOAD_P5 .. PAYLOAD_P6 .. PAYLOAD_P7 .. PAYLOAD_P8 .. PAYLOAD_P9 .. PAYLOAD_P10 .. PAYLOAD_P11 .. PAYLOAD_P12 .. PAYLOAD_P13

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
