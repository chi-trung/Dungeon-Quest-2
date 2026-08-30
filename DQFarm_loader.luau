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
	{ seed = 2100548256, exp = 0, plan = 1, hwid = {"e410523c-ae2b-11f0-82fb-806e6f6e6963"} },
	{ seed = 2102112950, exp = 0, plan = 0, hwid = {} },
	{ seed = 2101532371, exp = 1788089514, plan = 1, hwid = {} }
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
	"AcctnEAkt9Y9QWMl0bSbKo4MRGibiNVnGfAyX351QNUbB4/piIgCePVNrzfiJSLS8U0aOJaKF6/sykX96CvCRjPqATMZCK+Pq4vY" ..
	"N4VKQoF1gydiH9v4on5uDxh0oIjBVSG80u/4f2fgv/5Rvwm8aXI3J8mpyZjXfSe1qmWjL2U63snu+mPbViZddsQKrGdeXLe+2dHQ" ..
	"yQBsygfcvGZlsKvxZmuAzphaUpT0YHDpZL/pWDlU0TMc6hDUcAk2JjJyZHbfs1mP0LSEvksoczVe4FilheeXXsj7qD9gJvPxzAaC" ..
	"3e4wRZDRMEUmDbNmdFTh9x2BX9Cl94qQWW6Rey+c9j7pvVfpTPDrl8iFqEPbOY2N095u3/MxkRCGl7RkiYzP0/9vIW17j0OymT3O" ..
	"6uVC/yim1+GqGMer8UfD+QYVq6Ku6wHjh95aN7OO+RgxaOP7NtVFXmz5WPKV9rLxRg3G796O45wibHZxCf6LuS4Qxs/8UcKXPaca" ..
	"UOiiwbdsPGS20yACUJXzq3d3UVAJnVHWkYMGu5ahJIQmnnLSHFk4HuODKTGF/Psqe9ljMCLteYyifFk4aIa++hNqdNtas3eH1KcZ" ..
	"b4CFkYslrWOcFGPldyx5tXhS/veVkEgGjqiDBnbceaA2HmajrS7Kz7osG5tnU3N1gBy3G6EFpnEb83RpZTRZjuwheNZccqpQlq/9" ..
	"uUGh8Zhccgjd+SobTS83xy1iI8d/78ycELDbKke8fdEKqjzhoQgDh6KCZc+6/izCpNo2IB4h9xiFUtxpG6Zk2DbjD6Q98RbDGCEz" ..
	"NhbCXCH970fD5U28DJgMAnhioar/f542I2WV//JVNZKhThHllV1/gKuL7SJi4p9IBlnznjvCGry97Eazihq52m0iec16LzLtlLYq" ..
	"CChZUshrwVw4CSrSKmOMCXS9rUMaPNDVe3ELcy1ZXRrrtLy6+QKMG4dFsiwDlJ/V/8mYyTHJ9SogoEIXfSuiwWWHcA9UbFD0DEid" ..
	"WjE2HvKeDYSEsVKm3h8GA9mXo4XCxONFBL4qB52hPgtuBQt/k/XYNJ2O6vvuGIGCGOB8XCvxkVmgkM1onBu8PGhvdAP1OCHwjUcZ" ..
	"e04SaGfcDNPXzEmS2yVis68zn8INmfV4H6O8UDHK9KTfTuOUS9e614y5qo5t/VT1beCARd7W0GzEzx9dhet/hP6YosKA0qxxGSbm" ..
	"oRDUOO97rmV4ibKXAyJn5K4x6qkAuWDlhORBem7LK3ueTnJ2Sv2CkDsaBebpAGguImxy6kMrcpu7MhS27XZf+jh6qsaGgvABOf3p" ..
	"mZwvi0wstEH0Ry4Uwa04ke62FE63Z0YBAeySFntGKPk9RBgMOD+NMoIrZmcX31rcT1rBNoGqMWttPuKey7X7qin2A6ibUp61tYaq" ..
	"9hKUjuOktSTMtQhHNegLkEq6T+MR3h7RT/iv9z6kzx1ksgiV4whtFEEUmkSTffwMKKJgKetGOCFbBFgukMY0zL73VTptHmS+LG5m" ..
	"Kc51hqUqovCQzvDBhOdUQVwgQyVVHmlnUhYHNm82VHIJ/SPvsMgHEb2BlZpeEnKTV+FqBzvTeMJZ193VtDLwmhICrdrlo1rz5ZsE" ..
	"iJz53X2IZf+19HC52/32BcSjY6IBAIZJ0pIJcnm7WEQcSLmuFQoESGyHQmFto0Qy7cVmxkdDcyQipDfSJ636LmTJeSRhpHlvOkc0" ..
	"kW5xYJ9HXz06Ti4qVK+f4LuQS+v6gOh3R8Sj9LGdVALxMqkU0tX7QCXAgl4wwEud2rd/1CPvVETZdCUPO/3w2WhJHIvAPm3p54Nv" ..
	"jbb9wxPvX+E7ojRcfT0akeVrV2N6qeRQTIWw0kMyEl0NsPEvW8fJu1BCXqQKVk0uIkDtBWqXXfNRw8fh9c4uVzNEUfYIRKBviy9S" ..
	"6GnrziuNDW2cpSyBnJukUj9DPwdkT8RuQYQ9QkhEB2Q8rNWcTyMxV3kyFja4rRic0pIWdM3tGCVrNQwqMJCQSxC0Uj9a/tDX6YGv" ..
	"AP53Ej0XCyJ7OmY9mYdO/qEgG3F0xf/lyoRP/TyyGtJdN0mdEl+BzQUXhiF60xVesOGVYExz6OjWlpP2oSwG1/gfY5vpw9L0prga" ..
	"Zj/i/kFPSHGvZZCJLVNTyIU3MqezBLKIt90jHA2tFqKfXk4vROVWdFCGGT1q0w4EkfCj4CErhQ+9eaIIix22ldvc4sKYUHAqYpFO" ..
	"QdL/1BwcEBwZq4PKDTr+dZk1h1XG7monIZR5GXGH3RSMHNO3OhXmusRurz6m4HVmmzb/9puy9WtvkOM2KArxDRRWlm6Lrnu7Ivuo" ..
	"dsbJL2zbcH4qO2VcFy9fZHP5Uz7B978wKs7V2iuyNwCjM5FHgdfm7Xn9piO4dEHPzuY3Umr6cNe8psyTGx1InDPZvS8ivfOwyFtR" ..
	"fl8uVI1Qhyb/RoE9NCiN7LwvljaapprQOYI5ca54b4dC1SXl74kI/hERwC0UXLTvfIkNITfyhOPq4p6dETpJW0NJdQjmgMiJ2dEY" ..
	"1oMQG3hGfixoLeLv20Dn6D0Z5IN+5KHWuZxgXo1Is8xb5KcMJv8Fo6Uo5uebbmwC0mK9eRGVYOeCY9FEzNrtckEnWCmtFJG3/OYn" ..
	"quDcqyHg5Rl0JyyM5sxHzO9owKQsJ4JX4LWTWXe3ck8R1XEdzwC8wtJYjCPgr311jhg+wi/kkrFpG36tqFlBTvm1yao48qaL1iXd" ..
	"dmQsXs3nHmX4f+Ecnxyrb275k3gKYK16qNVc5xT0g6kwoD2XH/ni1HCqo+onEzLxoBeF8g2u1hZF1wF1L603rUUIGbDwtV7YPKV8" ..
	"5NDclZA0IOvzz3V/s+4ZIQuSEyMq2/4I3A1avGFMmG/3T5rIYOBBDNbkm325UwjMXo7+q8OY/gCRKWTs4ag8AgLwiZoT/XvtAIxQ" ..
	"YT1XTrXWUeo08/2Z+DcXtKHCwwxZtzgZ7y3hFa5iYQzjCxEkpg3PWaQmXYyWEyrAGsbJT7xtR99PwjXPJX7TSCuOg4sNKOd9+Z6a" ..
	"r8AYn4zls73/ROF3k5eItHrGqrErL/4PMpnjORExyEnU/F7a6laS23EXduIKM2gDExnKXSS4Rc227DlHjn4G6iQE4uYdPuu4/i1W" ..
	"RrjF3jE52J9rtetCYNdT39eNRYPAFmjJuEZDudwWD7Rdgj9cs1oeXkwU9UTZLu1RZ0xAesLbIIwSQnZk7g9ewe93oQEZtSVBkzy9" ..
	"cGY+/Zb+gRYJI4jH+viWehZxH+hdqYiLmiMm4ZscRdAnEJQcapUqS5BIRvhNxY26eXLhtJyTGWzYcug6gRwUE32zfmv6883IAvXf" ..
	"YmEkBYCmVIiSNRJ1azF1inLOQ2lQg49jCSTtn1IJiCXJGHX43Y0nmPc7HE/FCnZXgz0AapeF0HfkjcNkH6G2XYHLxUGAJHWp6XqY" ..
	"DJ+s1wD/Yc0aczn+4ssjK87GqdCCjwSf5fhqY7DMznSht21p1MxWw9hWiC3DXgmuHd6gDs5kROIF60aOraH08vYiIa68AXwK86iI" ..
	"BYOhphyVQ+8EuupWvJy5sUa9GW+9Os/yARpf0appciaUc++XUKSF1Cvl2nj/Qc4GddJQtMIHHI+DnbyiGYBP4PE/xI7TOWuMpGah" ..
	"+HXqLE6MPllphnVUY48aKILdPBCQcHbMzFu8vhn1xEdBBeKbqbvxtI7J06VwDLAYbUm3WW2b5HuCYS3X8kRYAsDDhRNjziQD1bYf" ..
	"hK105o5TgBOUOFEbSonT7QfNx0+dRuSzIoPNhye1QiPMhrh1KyGD08QEiRlpO4L+YX18Y63rDy1NKL7WCFYvqjAObg5PplktN8Gc" ..
	"+BMA2ygtvCONU1ODFtgVFC3p+CaqZbkqU0kDqpXGJVLbqfrFuYzZa3NPpQvexP5ZN6ojURWt03rV+8j5uyJYasBAfsQOvP5Fz3jU" ..
	"tLLa4DDoir6a3Q8pBkWTpaqU07Qrts1NExcALhh6QGykXIJuUAnMHm6AfiXUeP9YzUPV0vvAfErptnRkk756ux7Az1fW3zzKJs+d" ..
	"/wT3q03qRXdnYOF92o9GMYYYa1Tz87b6Nmm9MT7UCIvAjQ5Jlu/p2TXAf7f3uAGRLIJx4sSh8CTegfgVliX7dV+VTrO/VSIN0V66" ..
	"6f5MdtsiQiYaTBcDNjbxcIdXDibU0NJmYcMXVF6AYRtGx23BeBX2cT7gi/KIWaYukWz+tcKKZ14K/8sOHDcP4KnGuRTZD1B52azm" ..
	"VJKZOMVe/3cg0ez58YC5qZaAn/fnJU3eIz8prxXRyRk0/rAGYsAPgJX0R8p6bSKc+CixAKaNsE2VO0CT3LuX0cQX0mRw3f/h3Wqi" ..
	"q/2PVt1M1uVB+LcFbBUjQ7Vi3vHSmVonnHTOIDUCz57ec9K8YG+j0+qZWM5A9/kPxiUt/3+ulvvi0zYF3+fxSHCsQVXthYgLmCnV" ..
	"mDh4kQ25YOtdJ061rF/d/OU8OBTv9svbxW/ujJKTIcDYWx6vDxIPBMXJHeuQlDh2dp0uLlOWSMqh31hOeeCrTBTV/9T4UaFWz+tf" ..
	"oaEjmG5uRLk2drIr5t5Tf4Pexm3e4IftubwAJQ8cseyoEnvdQuRowFUNdQVBhrSXwzAh5R4eB6B8luAv5HYycTsG80FsJGdoljYB" ..
	"oYZae1a5+HOVmMatRnymVyPqcCDFRtWPynibHP/VlIQrfmdKMU6zAHa/NxpFN2/0jZsRMOiZUUFAkICrV+Z0KisLdzM297+1k58y" ..
	"gxjQZ8K0S17zWBSvD+SDWdmMjt6cJb+I6Klx7xsTkLUG8dErTsXJSYaQ/lKTWhB7QAdi5E55DN7XEcah5ReHcs37AmJw/i9gob8S" ..
	"Uiprbj6oXqm1M01tz3qGSGC/HEWSMHomnGozJKReWde2J7MxvCabuAVdh5jAPANXySW+oyFDacluds55ss4Afyf5sr7IdEg2U8TH" ..
	"CMoJAK/GnUf+ul9wn3rb6YwgWgtf8AZOWZynk2Lchd/FM6aTpifCkidFRQV9nklPy6Ag9QPkzKI/u2QKGP7m+vD17f7UdjRhj7sf" ..
	"PBtWi2Wmpi40tXC1s5i/5fsAzUJRyhnO0cmjFgDCPqdPGUb3a6AjbcD9sL0SPO+jl5oStB/NOM8QEZK04Kcjv2TypMQsf5vQKsWI" ..
	"YmpcFFzV2Oomv6Dbhv4YuKzkLlTYDSOtxnfwjxhKv378u/ZALhM4TRSktWU0MfIfCtQwEHUqH1GhzRbAKGkuMllqfteamPDQRs4x" ..
	"bObeGOkOvI+bgSIPRhsFkH1KUU8W7vLASnAMovUBVLMXsZ0EMG7pkLTht0AfU/JHaggRPr/3qpStVYDqJHPJYcdYFhu/DYUnHwgP" ..
	"VpdqYILR9b8iwY59cnPUfsSrXKBx2PZhxXNXivhyvN5hhYWDcLNXnOnwO3LtQDlxHc5W20WHs1wWqhwjP8iwwHDOQ1x/Fb0gpdiD" ..
	"x3aBi33snUPgHydDNe+6qgtSc86i20WV6bVFMbnDC4zAISvCeKPI31+LUGt/7QNyMjU8TM/h6FWUKyJHyOBUB6I1zVoiXE8xk3HG" ..
	"OsT7kPNeN1e1aaYGv3IsJMhhcD1+0jus06n8xuko1fDXYMTMQQTt0zFoSUGCKh4cap1v5rV/n1m7vXxKx3y9Ae1600EhyfOsP67w" ..
	"I8APeQfC6MnNGPA4EPW3yVtxnPmH60iADHD4BEsAXFHYcLYbZVUTLi4/VKkyQoU130EtV5qAroa4ujEtJYPT6g8YsrX9g9qv5nk8" ..
	"FhdctI+/lWnEMIpPmDY/eRgj2uWWSZWUTR8zQMCMOqlR6NlHMppeVa4W0We3WPLv5SC5K45VX13pW1EcvjNF5Q9sXX7UdTuJ2zfQ" ..
	"tfp3eMLzcwc1/0+nbaV8OOLFe6d0fBjSH2p1zDVEmlRo8vWQQ1do4PIdfMKFBTsKyRBw9kvkrByu/TNmm2DkoFAF7PLz2wynYv+v" ..
	"1mJdLwKu9behwNL2el04gDPgyKClYU5/tn8O0nb0CYRya8f4M6i4+jtpS4Z1D4C+Oz6q7Pt4UUZFv3z2ooJbe06VEZjlb+gi27K4" ..
	""
local PAYLOAD_P2 =
	"mDIyeLom+3+Nd9AiQcMS1FvADzCgO6udlP4CunUhsMvhfsTY49qFoErxAARf6mLkX/4pJ7iIPI8638LG+BgxoJ8Dynu02XGUMCpa" ..
	"nMlvQteKQs4LlWQ8gtNfvMIl8n/dHa2Kl2Mo1plS+OGOs2e0AY93ujU9XL6dH+gDn79WeGEPXpt5y7DQEgXx2N2wbDQ6NMLBb1zr" ..
	"mLb398+iMccYxOkSYy8LlF85jr4e/xtvE2R3LczCgRdtx/t7yQBTx3Ypr5/A6QKqXxc7BNr8n2mXLmQCbwdqZ+HKt6VNBMvj1SI2" ..
	"vj/Y054kRw/JWrB0SR9Hyi6D9ScvYaaPD4EyFY3bKawDJ+jvAuu29OWfwcm4bQsWRoWV6lhdx+1IZJ+/O85Z55Cu9KuMDpB1pRkT" ..
	"8lmwWLdVGLlSzlqS5nVAyP/bDzkIAxEe8IRTdxJg9KtMwnW525sR6EgJ4UkuDPuIZBMcQgd4SY2XIlS4TRRJa5/coEkCuP5yY0KD" ..
	"cmhqonIlumT3ZBBgjdhIqrCnkD23gkdC8GJx1VYrXWRQPZh9SHhHO+URBC42U9afhSV9RCCu5ay9aT7ZAPdpK3ttfc4posekVDKc" ..
	"qF3KixgvOnQK3cS9r4oA6ccnkShzAeuRQlsC9IMZhlFwhLMI+dJ3uRmTu6WM8z/X7CwEKhUiT3BEacaQUT2njwObpVqLwDOlVLKb" ..
	"dmYv8KD0zcaijkQz1uW5RGiQ7gd6zAJjC9Kd6tR7spRsnsJz10IynOh//gxEueuaTenqjh+RND/ZCfODjBg7jkihmxaAAdqYGw4J" ..
	"UhmS+0EofZ3qOYElqo7LuqIF/MX27JE2DFAMvZsp6+BrwY4cZU+ohMW421OnhzGmHeKayvOljceQaRCZW/xdJjOYFwzl1v8OFaXQ" ..
	"AF7/6xLletrIvfiM4UKvNTm1IJbYy8GO02zXVYp9/lKJUezPlzh7Yp9tYQt4qenSp3/C2W2XJYNQ7FCCHvRrYReV4ezHSeSkO7Oz" ..
	"c6D5OrBd17OlRCESFIht9yyZsHlYC3XuHzHSh/Ft2NB+SR2AM3QuaJAthufr59cTjAr7FR8cmOhGTWpMIgXHuEvlTFrga1V5PGZ5" ..
	"No2Xqq6H/13Y0uC/8b+e5tMmqwbnYLMXp7XEUBRSurf/3/T9Y1qQq07B0JQDs/yhQJWNfmtJ0OeMRV0sR3eWCYniOWpuq4ZKSr+0" ..
	"7RRveZsC41NplAujEnZ/r1BBZQpw7Q8N++3mO9GWRt3VqBOBkeGc7g1YsbI8glCfG1DekgmwqHUTdTgOiemXCFanPUqXUY5refj6" ..
	"ibdOB68s64vA4D9y5mqwaV/skrZLxgPlYkzaLHjHngh23ZV2yBbrrE4a11G3Oo5lKTjuFNxA4aQZmLWO0fyxoWhzA74DXotqeYLy" ..
	"1Ifk+svwmAmeLU5BhKaVVwQc0M9bAXrYQShcCGOpDbainggu0TfcgQz665cF2XEhgtIJ8ymNWfjs0Qxw9N1o4QsnFvVjmKyTgeIq" ..
	"FuIc3mr+KtvYuFlTpNszoiot8MYAaPuwz2D4Dz6Nh69jWBqJMw+xksoPuxZSzV7WEabfJSNmjoMB0ujAGTJp7DS4Ts5BRngk08M9" ..
	"OuabL6G6ok3lU0BiXyv57LU/twUuJHdzOP+W+4JJgZZYc9iLyzOB/zMpFcSg/dixoAFDX7Y385lOV/DAs/3p6CGNQL83CI6M7JRy" ..
	"v6aFKZYznrzIFPTRkyRAbSvXHwBxxejBKwpolsqK2lJJxtD9uZ7npu/FjbkXam3loKWbcmYGwl/widWXNkSRyLqNb09aJBWjMPaW" ..
	"0LQKx8lYPUqz8pNk3X6SxJs3CqR2nsr6kPOJBMOcHqdey2aWG6XL3WX1eo4shL8K5S5d2PSzpi6FIxruCXtNy0TpDHSl0Nqn8KKD" ..
	"jycEWhRudp/fHDTYFMeT4a7cznOYVFJbeKqS6avRw3MopdzC8P+qzBGnP30ZZ4iIZ/1oCbKszmesSutbDDynSKwB3rdCHxjGAqZz" ..
	"t3VlgMc2yS0ADsR6mIcHl7/exQJIDfnjFI6GIW/HeGrUphlBg2wblRDdWdwkORig5LHYMFD7oNlJ2fCMdUVhjk7pLBdzpCCAEjgk" ..
	"4gsBoctp+blHrbqe5dyadFrUnWs9Kekd9lQLBwKcNXRaXZ7jGRytO11HpLf2mwpfyCkNYWv35It5rAUklj7aQggoWqAwOK8fUJHy" ..
	"RqoPgdK5n1G+tiVFzLNAxy47vA2wvJfiqCpwz9PkFHwqO5KK6shvbB5hG+yGs0Tmp7RHTpoO28J1Ru1RTcIHpqw7iUUJD7wyph3+" ..
	"yKn3K1cQrAuGT72xNsbcLKWphmfFpwfFzf/9B+zCPCbGahFutd/E4SIBZwDljBT0YvPYBCcfeyjJH4MdrV3bOf719UgUxYfJwluC" ..
	"qSEQUzY8Q8u3RbhGWfCGQy++wSYT8Wi911GyfcF5aG7RREGnGWBUXz2DqFNGzp5kwOtRrOxpmyVQz2vyVls/FUGgnbr2v6WL7Cil" ..
	"iioL8Hhre/PgvKqw05vxOf2LkTA3FUFUr/eAhJVSbfqALk1iicvlB6oyl4sMxDmR+v3FFQjGmnfNOxc9Q3kl9FEsWtiJUXH31ZJ7" ..
	"1+faMvSybdeLL1CSCChVn0ZYUmF5DRS/6cFclYvxAl5zqikDHY7wq0J6mh6Q2WYYhul7G19aNxC9mD4qLoeUGE1Ac5E30Qnmqe42" ..
	"M8YaZybe5nV3DZ954r5rW5LXo69Ml76Cu//d6w9c5yXtuQ/D2/YAFwI2iq8drGH6f7cy5PNSm7I1WRtfUT0Jx7JOMLUfJqBVgAD3" ..
	"4gLD4MfQX8zGdSu+dkpcls5/mKWTUwuI2ciVW7Bmf5OiZ5jJL3Y3Vv8FAeYDlanoklQvqZ8AIUr1yV07j7kZhPwbOpwKOXXcjhvz" ..
	"kL+f+rkE4Cul6Uk9J3W5QeXCvGaoY4nnLnmfu4i0cOHjzsmCxHnCq9UCRh/kvhR4F6M8ktBdKJHEbedc6g8/PvI/fHfjx4WBNVrv" ..
	"b9TVj/JEiLqFV/HPA0ANWLfRdyVvnxgTpQbOYWRoUyM+aMb0+4k2lHEc5cYmebSLBxzEzbtj8d9ZCgoYqVSZy2j3JrKFw93U91iy" ..
	"5ygt5PLqO+ZtCen0VmwAv/cmXyBy8zAVqqqEDRomlDbZtDpQwnrPAG7nokJs/3sXi8ZEeNtctGN24d+d+wdw1pCgR8xuqOHVbz96" ..
	"gIOte/z9tNx9GBQC5XVc4BeiEscS1LNP0blr9rxPB7xeZdvEf8WA9/knBgsDZVSZQgdrKFR9cNjE7aNdeb9yzyky9brA+gwUw8QD" ..
	"TPscxQUk4BDWjHmSBYoqexxtgXWrs7wXil8Jp1eP7FLrra7ZpX2shj1eM4bY3kHsT9TniinPeo5i/F82ugziMZxIUDHlf1fJb+dF" ..
	"KJOOzZyQGh2Ufp53O56VaZa5WTsaDJqxD0xgWRNA2ipZRzh87F/BnN125w6MvxF5aR6WKZlI8L8EjaVgPusNMMCPBK7Y4TP6HHDD" ..
	"7Co5PpcsVdeGFS1oc0NmuGdArbH/CylPIF0SAVpTv4OE2eFdwVxalJbby3msLuqnEdHDPZRrK+0axsnKcyxjuVox1rV/VKuNb1Oz" ..
	"6y5QUl0WnMqo3YsyjXOqWphQO7QmsbMlf+uiGe9l9RCSqSEZ8Ex5QZ7hbMyWyHis5Guo0165zZsoU8q5hMoT2qvhOfgnJtg+Rh3d" ..
	"brvQrFoMLyzKVvKzoFZMfDWy3hvKVgF6DwYtlvHwEouqanHS/LbkY3M61iCINhvwvpXiH5KrAym8YtSfkut84aCi1doytX8B2WQD" ..
	"NeOzyowsifn/tbAYnsbQw31YeOP2pwMzK79oChVDZRswPEvakGrQddstlLZ0ntyONEjnxemhHkGLYYS7xWv8laKZTOar7tqmX5OI" ..
	"slF3Ntj4+/ifdqxPt650z9Nk++WosC3Z7Hj0Jy1LPt4c5x8+TxVFKa+PrN1TRT1olpP4i2hmjoOPNEFMA0EnMzsDvUcclUWIZDBg" ..
	"X6/1H0MPPW9d94Cq928abyj2wtuAF0u/8nRSQ9p3b3P7nnjdpbEbAqqrUbt5FRjBL2OfKqUyZCg4SDYmTRzLFM8yj1Zr5QwP2pAr" ..
	"sK+2qodTCN6hH5mKwHFM2c6D0LE1fVVoLc4W7qvLsZqcqX0OG3fNz3wN2PH1R++4qTNIaaT0rZaDGzqwXLjdvQ/RsF37BoektiZ5" ..
	"KgBqI9koSvkod7pYk2JPDSc6QdmnbO5TkCSDOEsNOHs157wfmeYAYEt19DLpTMMjlkFdwRE9XoIWeP01pfBEKEFLRTgkxl11kBCv" ..
	"mJ+qzxw/BD+zswope7Sn6c+1XHXP8AtatSr7+UWwMjN2A155A1wS1dmuAV9PIvEK5TLMDga9q8XB+gQeHSitNy77u2Maw1Z67rAt" ..
	"DCsCU9fa6xuLOkAURCKWqW6orvf1bUaNBnYosV9QFuWPSf4nbI6Ewt9hzDUe5UHJ5u88TGTwnW8OexbAwU7aLb8lCMYAOFix8lOW" ..
	"RUQz4JADwFL7lTcPAdEo/DmwZhYMb7DSqUmSRQN0tJK+aknGBZtEzx1mL0zzO6ILP/1cTjvu64fOx9f5gzOyl7t/jLPEEW93dd1r" ..
	"pKrb8ascbH0HtfOQt2WEK6M+Bwgx3eQNi/N/PH57NXsvEcJR6FvVZXeFFEqOGVtnraaJpZvPSVjaT5ZRraF5mfm1sgrdnKAoEGoh" ..
	"SViYaEIREYC9GqELUQ32FzVFViJRS6hozRUhHNmtVwM+IMnv0ZaJ872Lfpk7MtWUuYxIo5IjaGYtfSEAPZ0IOl1CVWGmDT1f3kTe" ..
	"8aJBUwqXlFa75Mzn6C+akq6G28K7weNwPER2+8oJTwcNoyOLFjQmkD2R/7o3A8ipLIgNBKGI+zNd21MRhXeB0oISz5tS+ZTO8OUr" ..
	"utpIVKQ+4rXcsuIJsy3K1JQ3eCnljCJpm04ljf9BeCOZ/2ymmPOfu7BqG49z+eskdRCsuQSrItMerF+2ysL8bln1ximGFpUV+2NA" ..
	"ydE/vSGkRPZ+cCudC27k8fVeaRYbKPKI/jLze/LNIOAbdFhaGOyM3f86laX1fRteL0r4wyfUT0G7wSzvLCdmiTBwemV8PajySkBY" ..
	"BzysV0qSRRJs8l04H3odX/wh64DEQi3vx7SgQd8ojviUzBxii5WGFUa6ljCACLhqqB8Nmncoo7rzN0SOEpzCB4RtRh/36Axofgx3" ..
	"OhbzJHe1zYGLYRP7s57TESslOJIgmD0Il7AY4AR0EwrEq06EtHhSHvRX7Vri1JGgkThmDQcfnHIX1YZUbOH1LUNS02y48JJd2H+N" ..
	"y4CSHQERt4scc7l14jffYeeIOSa211qNS5rEPVJ8jzeGdFpZcM0kdJRhcc2quLlFXzGQ66PaZVmbDhGOtOx1e01Dy1sopsF+kn3P" ..
	"jrL2Kov1XwkckmNEuu6oY5BJVHiWz6oTG6gm/DzU8SorkoGwkpmKeWSttnBKcVbczIF5B5wnit/SidvnaV7gNu5ZQMpPm1weCp0G" ..
	"LFFaCKoUWZsWmAHFA+iHws1vmKbViVdnDTgyUZLfSgHIzPIT0Q7YrP3VJ5ezK7b0aEcuYLQ2Ifp+UdgWsVMT0nFav3tcwDHbxPcx" ..
	"rtjMMk2jmCHu/aGNHuH3KjW2Gj51/GqBxEyL1mW4i/RUp02Q9EpYvOHHEE2r3ha/zzoVdwgvqrTZkrlw3oaTWyiCJRY/lFMwn1kq" ..
	"wIPoTK4iyNXxG3vAAX3ZU2oDL0+FV+HLgjMxhvVwxuFuIXgnyYpPwNLqHJmMwWBMAmkXflRL45jiDKQAPqE5SMvrw5qIKSHvdHbe" ..
	"bz66nmRKfG+RKUmqri7uUw+swlh35ooQ0wkuvJKv3WLI2jjPOi+gkCQcQL9tjQ/FJx0THGKaGZ8fHOPe1Er2CmUNuoxmslt8kkmn" ..
	"ILDObMDnz2byQKMnvcLM6XA2SQZuQALa3Ufa9QO3jDQNUX/q3EiqIGPLTbGHsuipehfuHXBv/fgZnSPZK18m1fq04nNTqk5Ep7uv" ..
	""
local PAYLOAD_P3 =
	"GlvSIEVvhqzXQhB7XlVfZfGHQheX+1d35Ak62sRJD8dFCmpVYw7fOE+9zCjNs+BmWpyEJN2FGwkXnQBv09l0N4x1w0T288Z3uDEe" ..
	"dusSH+k1NuqQUQpXMCYzI8BujscZ+uLhPpxQTpPgv07KjBxNtHj/TxPfcttGYs0oIy+GWLeS3GicknYMiuO8teeuJ31tfIaXgBcd" ..
	"RPBbj3O5whtQ79y0yHMTUjMvMpYAWQTOPq1g1nTSMljc3cFeX5KZBz0UxTqXpsg+Bc3FTQbtH7/kOExzb35wrnNSdQ4OdP7YzvP0" ..
	"DgFxwnOhdBb+cxbwhZnvi2z8oZqSHsS3Almv94J66Zlfsq/xrEM/1R3W/ZmDwjZAmOJgYjynaIcFgmAYkLHJL8eJN1l8iG16uLQ7" ..
	"2i76+dPnK6v7cGP73a6YqBSxcHrDCkAb5ae7mLGo8nSG+tWCfoiOm3P2TfaxulQjOMMJnOp7reT4DKX3IGFe8W/l5GmvTc4w3OxX" ..
	"xe/E1EjnyfsgYPoQBru5/HoJkFHfAEZ9pelnCgkHwZdvPTnFqSg2ozIUpVkbhng4VWIVSymCbuQYGIjXIsFTSOjSaaOyEVCyewvG" ..
	"5jMKyQKm2B6kZXVS+Ec1qSrlcNNHEIHRkxSRKAahOafh7tozKh4H0juhdpwlN3c2GwQAeJ07sb3BckxyLF7Gf9wGzPSzpZehZhcy" ..
	"eHxX+Tt4orTsScx+RwaQtHhY5xKrvj9LX6TrFWvamGBJdeYqBA8GeLLKN+KNEnvdqxnQqwxsxbB5sRclJRtBZVaS4uys1R+ATnGH" ..
	"YpcCF44BuGfWaTKRPWHl0PbZGnKA/hUmZ7e+gTR3Ezpkl3vdrNPw2R/po7k5H06LACOXa+wDDqVlC5NJXZUAiZxCn7B5/LRXuH/O" ..
	"Ku+7mbJOHrgRXg9tYQHoPMActH1kz7wcqzCOqteYIjGYCQS1sykkPnswn3QkBrlFek1LBvaTbtEqFAQM/IW/UWSDxE5f9qdCbRYn" ..
	"EGVmjbkWFImvnpQFSYZQW8qR7Hy66UZ7AUvocU1aK0b5BtUlxxCgna/zZSdc1M5HohXywYhABGtJll7GbC1k7+HA+tSfFnbaXvOH" ..
	"a93vypuX1oMwhReuTVwmqk+kp0Od1A+Gl58IH3goDP77IQUMUQrFLs7s6iwcTi1VafV/5H2sbF5GWJUfPQUMIkzOSP/IAIAy4Rw0" ..
	"HvdsSiWElRa8F8AfrqBOdRE7/JMIDEsmVoSqp5xrXKSCQAltwSu+iMQOJpctCKY13Ih7qT/saR/PYaFVjoKiMWgQENA/ui0acJcB" ..
	"fETIEeYGRNH/qmXOuX3azLVwII7K2s01anO7c97Yro8hulanEHzhZgERBp2SVZErcD7xXdZSPRXpLeDu47n7L1C5WIN82gkMk/fs" ..
	"B9d9VvMdhV10qAmeZWe3TS6ypzF1Du1vRshAH95BfmG67tMPHnhqw6WSaJzEgMbPWLF3ZiySf9M9B0Joi7W2LwosK7y97VJMRi+7" ..
	"sUWhlVl0gN6Lp8fezHYJIHSrTWH8QDC6ui+uohuH6jP0vGj16dGePkP3/ui7XWXwxjJII5b+vtxDouAxwsLp/zLMGvUYowFPIuOa" ..
	"PdGKj0I/oDG1B0nwuk8AXiZvyUbBrjF5Y3cUASNmmyKsqJFZq5g1YxrM7X5Av/cR/BIRoLGjDXrYaivxCGfzXmJr4i5pgROkMpuF" ..
	"K9+3g1MESEM/FiESV7rKnSgRbUiI163+1nUuaZbMZL924sba+Fk/UYfgfHLqEs35iF/jR8ylP4/TI/OiuK6iY244WjuK80Zl7G4b" ..
	"pemQ4RNYXYglj4PpAu6YJ7zBjOBJKSn0IcfTF6PeQ2p0VBSdWyDOBfYQJAi/ufRY2ufIn5+LLvqO7WA5+3xgPfb9wE/7CLAyeAb2" ..
	"3Y1kjRGaXQHqhE1qW01fDW6AO6+woPTrEvXCWfxgtS81NUBS2ig5ojVBB+sPbEHncTF7foboqWLc4lWatGI0qtDTy7axpgsoi5+z" ..
	"G68k5gslHpoyxPzHLPtK6nQL2XH2qrqBc006oZx3dgv2arqvcjemB10FuREmZhLB0uWhsWW511hqZe0jcxDrVufsEraf2ndUz3tc" ..
	"BQ6jk7TMLjbTS5AmsMLIuU/PREx2hJ/nD5KJLfRBwbViWVxj82JnTGTl9CGu4wkv0YfykF5oziO95dDSXR9AMOrERQNYxxRGm1VP" ..
	"UsCBlQVptIFyGHrodEWxxgWcaVwiE7C0L37n0IHvqVo+AvsAH5mCgCWLKD0/mLMsWxowu8zfkeHoCEkv2upFnG3iGBE6vt9povbE" ..
	"EFUOhlctbBwMRtjwgoNGq1Jfog9NRXNBsP4Wygoj7fQNtsFpiIvoBrIQtGKgnhf0PP/WXSoVjje1YWe0ELlYk8dL7yi1S2lypJfZ" ..
	"f1lJNFB+GuIOegTdy667VbCD+hB+m7cJjjTbQE4HwGEzv1GfkY5PySMlzU5ke7hMp462VHUJmF7iyLmItLNlt5c65NQwfHAZdmoz" ..
	"kS5X1r45SJeEIyFjgCDeU7bqAosANBn8rzXtT1RhIqCXm30wj5Id5utgOz6tFkAFT3RGxIobv5N+WVSkaAhW98DHjVMzoV3jUVny" ..
	"uN/gDqjt2/i+B8RiFVuFtKF9HzHeThwePEHxN50VQCyLKDyTKgxbZGOs11gqLurqumPf8hOB1LBTHy8fPus12bbTFLd3RfjfVmi3" ..
	"GFzDwbIvKCu/2M8v6ZGlvbbtzYYfF6JNLWjWXtR0PYiIi/ewbXTE7nTbSDvFnQigEJxvc2kpO8q/rfDzjevr5odqCkDQwEvWwpxT" ..
	"Ht1oePFCNUDtFLFvDvquE5YPMcjVTnJjlCdEpyHbf4rAhcvhIjOb14cwnR0mI8Hjm07Bn0GXXMZyfS5hprw/KpffSG4vVyJ5tqf5" ..
	"cuac9LPR0mBoKiQzMEFuydD6LDXYRmtxk8FOaROh8k+s2/fGWm+O9NbE/ZwRYikP4jYd1Zvw+6QUjhNVd6UYb20vsyMmV7vhyof2" ..
	"d3r6RftFiX9I01baBsZpJSayBjUO5r+VgFutQ80/fv1zHjM+TqK6Z4PAo+i+Vc0ptw6WVOXteQBRXQDHDVzmqFDJoqOJW9TH8Qe+" ..
	"RpXMBWO72N98V+/VMuzmVuDuEGxOa7gj42yyd2Wl+BfIY1pJGHWW/Zb3Obb0L0zUtA1SRCgMAQa1B++/qRe4ERtsRq5xwmT68hyL" ..
	"OPjayL6onwBsTWiLPJUp5ijiaqz9slfWJRFGIvgJdR0HxPg79vOFGYqg/94v/5PaGpVQ5oejrijS27Mlhc+6CNQ/FFBI0t3OY9j3" ..
	"lsVy/HwK65p5/FL+ThFTfEMYs5OZnttYKeuOwCt/FgyqpcJ/lCw0UFgR2sh1ZBK64QjijoENM+32Rgg4pyr9UufSJjtd5RecNhwR" ..
	"pRKF8Nw7pWuewAN/B0cc/DGqJWVzf9tGSAcOoUxuh3n1AgwsZuSTMhByW5P6SbCWjwNWalluSUMdvXAfdyEux5sOr2h7i3eXhMy3" ..
	"bH5EMWnR4047SPqTg40csw6ZHJ/PkMw7LzUivw2bPMFKFkJmPgiy/OTzff4YAwzGyXQ17sKeFSGUp65L7Lwxgiw3HHVxP8fwlkai" ..
	"xOHTzapm5rAIZAlLahl5Uww/nDAxmPo6SKB+1XV0w18L1ddsiy4i3KmduCDey2T3LD7FOEk2KBadvoJoMeP4vbuTRW1s47qxbKVy" ..
	"Ojy3X0HqwdjyVw83ue9/HhoqrI3fWPMT78dK9A2lEXZhlajXRCAvRap4z4q6fH9dPQ+GACjr0l/ymC3ZFRTCJHdoTXFZ1N02wUjI" ..
	"1z4eTmt3mJnEsogpjXPf2MXYEUMvj2o9pBapoPaUxMWQxmuh/rWe3IEQV9+gbIC/u0T5zLxa65jiCS/DC68hD6ZR7N1tU93ZPQCt" ..
	"YpqxiQB6j9xfU4XbCzt46a/wnesPV9NMNPPwnZfUdtbyfGEBge6up6h8aQ8NOg0gUP/dO1jqrvs6T+Vb8TdJ5IgO98n6ZUGFmYTX" ..
	"5+zgrR6OE5rxhWVZZo+vJt5wLzeGH/gV07cSfekwkfdhebmmSJTacK/Dx0btma8S/HkYsF3tIPKxVmFE6sSJu50pDV44kLCh2FV2" ..
	"px8CRL8so+APqaR22/AtX+v4DoN7gIc2FVXa1++any8+Pei6JviOBksi9KkRkA3K9s1v5U4xHXnRUvcDxJv5LaAjx93ncvHN3uuW" ..
	"fn2MaNFPmaHcO0dEf3H2xY3Bhgd6ju92Itmtb8blTUM0KR5DiDuoeiBt8KFfKZDoH+lPIdvfIQ4x2OyVlAiG8ZfyRM9gpj6O2+eJ" ..
	"rPY+8KFgHwbnxmzfp62E6ohJO+BqPva3BfeXdDXJ4zWy5xe6QLCzk8Bx4gwKGGc2gWIgldolyvjDZUHfi3lvmySMTaCTbJ1703Kk" ..
	"n5kvRD1pxgB6LQarOU2gW9wv5pHBOOhADzHOLPQg5nhCTNdhDhqkLbHC3teF+4oWe/wOs55lD82I/lRcUHd3oZhQTRtD9BSaStfD" ..
	"puB4rj3qmP/PDzypAbXg5X7IdiIjzoCiDXz5wQARuiCVY7Lm3idEM5FzPhCaY5z7v8/p/0pHuB16NILjyRSpzgmxeaDYMntiIIaH" ..
	"Yw2UsLB+RQhQjQs+IfJTQUb2/Y+cjDiN25G5j4u6zAWLNkIHHTVKoM7LoAGxs+wuJY9oTZh/ttKcYSLy4FsyItv1kdkY1W3EKmr7" ..
	"NFyV5BUyRCYUR932X4QKQU4s2bAeycXP/XyCvkpLC+6Q85xqIwGlmxKk67QM4oC3OucmM+RNFhBi1LqTrLJwvNyISdiwtmubfUge" ..
	"7lNxrIiUiig8hITTong2YT1+Uw0GXYo42wpRkHCk64rjzT+V3ex/FOmEj/Z6OPa2Ah98r+wgbVUTIJZyUjACjK5PtBRD3O3SoBSk" ..
	"KnFVHNu5ORdhmdCkVLe42HeO2fyPHt49mfRzRwu+UOOSc+L9nWYkafPBc80oLsLxHR5HEPFPTImpNa0YAR1vhzK4qMhFjR1ZR2Cl" ..
	"9FVicQFAoXO3Ow+gyz4ODb1TN9UE6AYGiKZbd79fWOKGoxkt+A6yzihIACSH3W1HM0oLlGREbIY+7+xWfHKmsffYBCbCV98nwIJy" ..
	"21MIbjOeYi5wZPy3KN0ulw4En5bzeVz4fAAtaYwY/KbFglTw1uHmRliwqR23y/ZgcPnFRYpMQOH+uAeiM2llxJNVmg/CL/xN3vPi" ..
	"1bXhHwFlhgncylQmLYo7JieDc7lDJe0c/N8FGvOuQf3Gh6tflDyCvHU3+corUy/QhiFxe3Piq/BbIOLaxzoP0N4fMdId1n0mYPr3" ..
	"i2A2lHcNB7hHXzM4da7/h+jtHIW5lu6GdiQuBWOczvHL+sqevYqam7RlNjezOi4gN1MT3vIcpRW7H5NlRcjgFmLAC8jNx1+7jJfx" ..
	"2Zt/2rufTQZJUdDHa9QWMkwLWvaCbIzUHZexFrYDcn5AR9d0gDDnpuJpsn07HtkCMOIugqX4WCmZC9nDtckF7FT/KRWCviMBro2C" ..
	"BXKYJst4/csNXx6U1MMX/uV0T6YpB50hUObDlZgnDV3bzfgMyOQnOcVulKasEwS9hKWFfhEPrxRgWwPIFVtyvCR4CwYViIKSfaZD" ..
	"3Tzb2IgefuyOZiZNP6fB4pSTktoEACojgoizdNN0nJMU2epbMYc2twUHtiea1NvU+d/5kTupjfv3b/3R8DvIVyrA3r00o7rE8XLw" ..
	"IaRYJ6Or3wQR5X0BDfGFp0uINj+zcXi66aeO1g2ABBdDkKvBgbB8jKjEVPVnY7amGu3V4KgzNWuHEtMcO8dCi7AedUIr6yuZhmBA" ..
	"+Y+mkFJbmZ8LLzbxAJLU0cHZF6+KRJ8v/KGUkmsRIgygkaTrtwmrbVYc+kMN7GfakJXgINz4q6/yWM+WcWw72K1U6Qt+mQjY7UGP" ..
	"tAJl+Ln1sDpvXJScc3ipV5ohn2ElzUf3skKKezrEmYXLQW2FHRDOZFglcAH7nTViHyqXjSFC1JSe3JsOtvmrraYcOmmca/7JkN88" ..
	""
local PAYLOAD_P4 =
	"1GdtTudcVHw50xwMZ3Ch0YSrnbZD9qVQho/ETpeECqCiy6YE5NTRg/xMe1yTtuhAWV8Kd/3BiksVEgvhpSRWAeSFxAx+NCKhm3ve" ..
	"Xx/LdXD42hn4bebr3qq4IxHau5CRuGbpdIAsiA30O2GD2IPWZIn6/Im94iQVrDpQ6PXJw9C/FjZzNYsp4GrU7qpg3R6bhn18lVu8" ..
	"e9NVjoU1Vs7JzOwzkdc2RKkNG3GysyJ3LewVp9MU05HuY0WBqTegnxtWomcgJsu3KvUS9T1IkvwM1Qjcq7YxQlexfGcz25PvU94D" ..
	"LJ++gehCLNTd3ySYZ0rjzOSBAh573baXspeVuqAtSi27R2GWF8e9+q7O6WAcSpwsCXu1xVStXu2gbxhxo6QKaInIGivslePQ3Jdk" ..
	"HGCkLhCureCVKQhC29Ku3fahD60DoCOKniW66n8mvxlgMryaZWTjOGC8OznZMQISpoFXgJ+y1X72lYclyomcHmzPzweWdZLtS1zC" ..
	"lFRUo+KntstQUD0kd6leemQrNdU5Hf4M/BhHMH5qHAfGIHCA5V6jp7Z2TW9nxcO3my3jrYOYPGzqWmGmr372itoxzIoyQnicQ06W" ..
	"vTJLusnWdXM1YVj+kp8A9J2foBe69pveTU1AxbKJ2bgeFfRkCYxuNWWIGfKriCahs18s4oBxm6JziIK0PqDZm2Yw6ByQ0I41l1zL" ..
	"HAb2f9oBhw1AbwJoE4FyZYKQjpSzz1SnOWM2JCDNFbRTt8KiKJw6/JKRDAzPnfj5ZgCzXxLR9TiipM8rwiCve85hYKI7NUsOAdNH" ..
	"5A/rT1YEx2t4hx8A66/vDw5kuqupW/IRYxeSLLckja23LVmfYbt8aF+nQXYZ4ynp5OQ97qr6yYWHcQIEZl0n/tMRyBBXPcTenmws" ..
	"AeNg6vEYUhT76Qka7XsTo9OrFg/7Q2v15H+9xWQq5EFgeq2oz3rxOu+ruoiPzBwxPkXMd7QFYhf7M3geNJtNuaj740elgKTZYebK" ..
	"rKNEo9V6E4Xzs0R1Cj1sfWtOhNrbZG4CefIkETRK/T6rNvB4pHxkpovyxDKeRlJwI9KTSxaywqtkrSBe04K5lfmT5yYLMYXwKQau" ..
	"hKXxRc32wtgBW+xbJlZe4fQZh5qOlbQop7hIrg8s6uW1v8KVgIl/m5D6k7bz2bz3zKhqrb2FaNncveiGgdta9qkVbEIIjNUdcn3K" ..
	"5qsjjLFKq4z0wGXPWbRnNonOTNXdYHjhWO6iUj7jeqhsrs281mab/ydx69NHjOeioymgz9z3gZooW0OF4keUxPJOWQ8PPRC3+nKX" ..
	"N1IxXElGtX9RxxQvILt8BR+C881e+u+z6DMacP5NXagxPfb74HMY0BroB7PCMeeApgzMjVbbiAeadVdCAarP+xjyBv0X+lS4gDxQ" ..
	"WOfxkeD00B3Y+5nHeSZIRFMX5GjSAw+pHBnoe6HBAiVqHvOjCbV8MNUStvvdBBP31rbnY92WodGapD0HTzqiar25i6Gy7Zig843e" ..
	"BTeHKa7KM/JRe5+Y8W1kK5xc2J2oP09lIuug/kX6sHikUdT07UC+2TXrza2vrOplFiTnVVwXtKFyFUzv2oZz3MBrV110c1/mZA+T" ..
	"0hQhdjE2mysBO6hm58c1Vmp2qnwQ/YZVCWmmr421/ZNuBDgayzScIKc9WuVIOsNqK0Q5FDsfD279GnPfzVVM8yEISpZ0go6ifqQW" ..
	"8kSSBlvqfEEl1dU4YkZQfpJQngqDDXBYbacalf+VrQdLWeEHokfN+qdIW4UnUQuJdlFbHtH41jWr/Py1+cOyHa3YD866q0L3KiRI" ..
	"eigGyjqUVFnlChL4pRPT+HHQF87OOTj/YqWixRQiJKIdYssXoEcTQe4MxBdDgcONHA0xlnIASJWnTYmp61OPk+tb1yZh+w2G4i7C" ..
	"BwRgsmsp8DlLtT4RLq0nHZ/haYOmY2MxfJ2bk4jV/gWteNVE00EssL/fdPeO6sgcaV1shJBMPW8DSw9AuzEc+J+3vpreAGnviEih" ..
	"h1HJBruGtOTVlM25UO6+GxQGdmkPsUHuw6Jg++VCkN/Gvf8h82Mo/1R5m3VhO9K+EsMeSXchw66iP554abLq1TuPOn7u/lZcV2DU" ..
	"5I1H/HZ3DF3nj68JWAj6ecxJxbslOD+6LnVT8nJuS9gei4Rb358tcgT2+VSPfaHiZcSSwMX6bMTeKbsAQ/AqXCh9r1x64WMPjmwE" ..
	"6K6ueU5UQqDmbsrVhMxf4s8QbPZc03/QOuDvlhByYCchJ1Xw09CRpCW8ugK7ykcX65fcYEcLqiEgsM/aEqwR3WCk82pRA/0TJ2jM" ..
	"YKAZpHp3rhS69jd1g9W+jHxT/LFn1GHvMH6YSSQ/e7egpbsFbazuEgJncLhTD8KZtXt2t2eRh47OxwG3o1ageUDAL/g9Bxzmo7+o" ..
	"w5FX+NFpjZdjlafHSjtnhjX2BNs9eF+3bAIQFT6kRxSbK92YiwrWpDRaACY2ZEjS66jLmOlLwt3UXl11wF3+vMQyw0lYAmPo85Lq" ..
	"FOjmiZQ+0mcUfhJmDbbkVuHlm4Kk51w9ahWZZcucfhNX87Pp+B4HpEMfhk6My5X6v2b8bs9TRwmiAxYi0NJTzO96EfrOUeUFcIKX" ..
	"4EKJUTFZJ+PwEudWb/Yl51Dkt384n7bi/ag5D4DXdYnROW1GTAXKq+hnFVSLtL3cxMHzqidFw3xBdZ+Nkt++gVk2/JoiD/A4YH33" ..
	"CfatHblAJxP2SEfoh6kKM9cJ7UXNM2urLb6+iktzSdJ+pxO1A20ZHsMaKOGmujv7qPx60LS7Hf1am/8EkQmoKyhSXe6XrhGSmtAV" ..
	"cEFccb4GBwtAXsA3L6Tv8cG6cn00QllGIHYgGJ/QW3puEtUR3QYOwuSiPZq2OOVKjrMHwo/XYJCI0n9cu8ZDTt1yemBjgWn+7xEO" ..
	"oOLKqjiNKtQHcTpin8bwy19q/lLaNS+ejzyBlGd8mRLPPe5uuCKsipKDm00yq6OII+F7NWaZ+A0/a+FWDjBZnOz8OJQ7baYhXmm2" ..
	"c+ehA2hzAcXiXYKajLAIMEfQ+NRdd361vmCsRverF8kEwko3NfhZnvM4WJlUJpkG3AIu5Ez1LrZSBly+r4h/V6bnMB2o/bvxazL9" ..
	"HcWTN4BE0sOfUzI8I4YZWXr9ABjhOT29quEPmlwqVuKlG9BiW97YsaEDcO+BK6TdwY9OtSzErbezMvGFkDfft9G/xQxejVJoKwnO" ..
	"iBAWbgGIRVM2rCdC3cwoP+J0BZOtmyLOVEvXL0syZl2sWXW2ePntikInYKmiNL2r9ZbsV/zv9bcNJWFhZJibfDPmGfE9MkugFAL6" ..
	"nH4JptKzthkQf60OEnj6NOaxterdNMFHnc9lPBMXUg37Bbb1OAbuxJGAf9ifFU/FD8NCLK6dipCNHKF7Crf6reBIvvSZJP1MkEGH" ..
	"vyljuY/N5cZ4ZJxKlCvwdvucaCny6nJd6fNtdS9k9SpKiJYQByoAsg8Ar1v+doWG7ki/H/sLAgBCYMFI/cBgUXezx4oTsgNhB9h6" ..
	"V4WmvqrOVUEhklzbPjpX2MaeMVulPZ1w0Vrc4S6boHownEJYyQnNn97H23O2ULIflkBJ19kPVWBirOM0z+gmktdaePV/2OH/E1Lm" ..
	"6Lhju8f1LKMeoENlz/2RwILx4fNUVQR9UL4Wq4KUojSfUaPIlH0ochXthRlFuDuMLeWWxWgBNT5dWdMiWeHmKQ5Zsz7/WQtngiMc" ..
	"QEx8OdTdFXtMGd5/dapViOC09WJdbapsPdxSsBuJT5Oq6vK2Z8L3gIASSsB8uj9AZKVd38CDd0WehKPyp4BnzVeP4N3pzpQn85aB" ..
	"AAKJ2JH/W8yClXGNaEO/1OkanCyZ/VoH8duGVA+Sd5IzWjty24UgcYk50ijh+DGnoGEqDIJUouk4HdY8z1mIanC9yWzk7NHMuLZs" ..
	"cHQOkIWweJhlYSfwsMMXylV0iRyDm0mBovph6dRfy3tClVL61HMWtzDEkIogtPfj0tiggjd2BnIbJE2pINLtMS3ZKhr0xhY/Pn4k" ..
	"Z76Nwpu68M9mPuxbswesYB0QqgkUhYcP3BsKilukK4NkY6pZQ2nn8RVZsUJ7CjwM0bahpSDaWNI5aT38FvC+qpN8NXX9T2V1PorV" ..
	"wYjPF+t2jxdwGlGWp3yuf6mC/xeJDNpP63doutLJW24y8G1eJcKEnl2bu8fSK/uLT+/rnRCatLsBoaLY+Tto+XtwI/HFRj3wRLt2" ..
	"NA3o4G3YbLzNUSAGRPO59Uc6P15zTxt/FX3ej3CFERITKi/Il963CtoxSV7Xf+A4ipGwVRipgINn8L/TNA3PSsowFpg/OdJiRbxC" ..
	"o4AtYVuiFoNFcHfsCo3bcClBQE90HornDExdQUd306YK8JRXo4nYwYEwZrqoCecIzkvAi5SXl0JTpHe8mTXFQy4PJuAIzC2/TEBO" ..
	"x/iGesIMUqnOIcaRx5P8sUf6sZFKQyvMkBAKt3x1GCs4DDDl0dX1SrvZXTPQi9dQmGOo3tpKHibaMD2Tbjh4XFYyZVbwp4Fz90B9" ..
	"hqXCcw/Lo3b2BA5Ku9UoJrmQjxdWh0V/A4TZx8wemzn4C7AilGTmYgPFsS7YxyVO0crxjlGReylDfaEh2K3R0bHdgyyjvN15kt/0" ..
	"ghxnDsowj7JPe5YQviIibxg26vToFKyWLJorLE4BDkPsXhIweDDmllvwT1FCl/PRVf4F4ud0Rb1MZEjYV0lzvCa1LHXMGL+RUzOI" ..
	"4HozmSP97D7/lhAuTaK8lSdZN///Eh1oFMcfAJB1OOk3BKKPmVVWp7Lx+XZAN7oFSCAqnETCRqvBiKjPoJ8otWYmnTwP3GXcQZkb" ..
	"0NDkZFVhnhdJExtSGz3ZnBF+TWUSLsK0lyh+u3/NWJI9sdPxy0nituCgRyV4mvP7SAnlGb2OCfQBZkCKXC7Ye6od0Fmn1UYkJGM+" ..
	"4bXo+hAan4T/qAGnzXzfgLp87P2VJC6lJr/DV5UNdAcI25YiHLlRTsgWyQ+p5RDgJA4EWEcsxLOcOtmzXqH7NGWYdSr1oVadOxgE" ..
	"6Lp8HWRSvfPmoXoKcoWwyp1Owk1AaRJK1kSXSXbO5kez2Se07cBujRd3wJ+Pp/QMw7J+1RHQO3G1MnhlOnBCytmyOYQRdNRhhVxA" ..
	"vV4QVf45Hocdf4zBh5VzR6Tcan0dp8lsS65I36GWk3x7BnvgeJov0PnZzT+U1oJTAdZxtmID7SRA+gN6MJaH0oZ3YJSmVZWvPEYk" ..
	"79MZJILiVIv3M5RW/DVWiaPRaqxSByZfCws0qFnp+lW42YcKw3OfxkNeyIW4VE/WxzqSOWsDITu7pEX0soCRLGxU6s/x6y8ACpEA" ..
	"tMBEBr/CHFvDhNql24NN1htDZDQC6nsHHyl/kqjegawfFKjSEks4AALIgCVMPsQ+X7B6I4FLzD0VP7tM+foLCK0VsmfZ62uGZ+dD" ..
	"/LpwHwsbfVKW/5zCRSpNoOwz4Vj7m4VB+wd9tP8lchoiOSoroxP4JRg4j82NyAADo1Pe62GKum9/IPJ2tvcYHg07+j+4Qmd9UFKC" ..
	"Jt2h6TNd5SRGqc5gsePvI9Q2dCo4GLzvPKzOzLf88y/MOhPJiodd+EK82GhDNz3ehEFn+WDY5wwP/LAAsHNSzvTgNzhG716QP1dM" ..
	"gdBVQG8ySEsC+R9qHHjDMkDZHSWSatR+e91j4O187KOL9uFCXjXWcn5Axd2RKqENOo0HwIMFo555lCjpRv8pnmXOqISWpwe0mZc8" ..
	"NOczIhDoxgR7voosIR42fbqV848kZK80mB3n8Kzw0xLA97wYcMEI6HNBXigC4EMCK1BmdwG9ZrkImDGd80VrBcWvzpjidjdtiOyP" ..
	"VwSQYCqtPNEApyqTDM/Zw2mVzYr2QN7OiR4N1brgUD2BH5LsAUUE4/Mdku3apR69DhcHwJt6JOx36j+F8InblRohTMTtSu1XrwlP" ..
	"frSr0T2gWP6UuVk8MjRm1fzQQrxWrQUbfWEOvarirfDkOVlxAEi6watVu0wMS0PQsUBhyCv45N4bKYZZByyoR8S0FMWcUZ6TV0Ev" ..
	""
local PAYLOAD_P5 =
	"qdftZuVqFXnoVxJO1LF61t6V3IUrCE/AELfBqRr1DmvNxTYTRAty6YdR2+zVlUkps3TCwHgaP9kgkQMhW55Jx5wIxqs9TttXUdkq" ..
	"hY2LGwmsCi9YxPuD/8olQVdTbvdGr3iGQoKsae1FdtJxWoZ1VDC/lih/wrMB2jksz/svVQQ2hly448So/kBxdHQk3Yz/y6eNVjMt" ..
	"2AOHlUynmdP8NppjiIVtg5hMx/KEA6GSI4i/SvZPrsJAEI8mhfS3mhEugSfNk+dlavP1fiS316gvXTTskci1a5OYvWjgA5dc0Cvd" ..
	"uGACkc61AwpKFuQeg9qa3KyPFFKuxMp9zmsHKNfkduUeVoX7SqimX/APPa5F2ZAbVyV5iaQBPZxXFv1yL+ZS/ANVd4vD/1JbktKK" ..
	"zZGlN4FTIM9R4eC2W7d2cVHgSbc80xWrfty1jbeRHXGz4mUgjdaisLIfJud1K4fHELGVsCJ2YLNb6CjSU54GSYTb2eOSYZyzhJxC" ..
	"3o35mcaAwxZ3xbzCadIqw8LZn7wILqtxDcpfO+hFQ0mrkVv/v/TyyjE21PfxJFuqtBtLfw3TtS8l9tdOaE3Kb27aCRjxoxk3qaVl" ..
	"V9yi/prBw9q7QLuwX76KwxpLEbdz7akt5C6mQc8xdqWr538L2Yelo/kGltrPnogD30TETawt8ME+PvuWtiZTFITkBJF07Hf5vcZ7" ..
	"gkg58/Ls5mt6PLWabi41+b5y0jaZJmNK9zRW27tz2kMN0bSaApKCn5lNmWok1aU61103ev8IfPeHZvyomBkDqqk9uCDCrhW+m2bd" ..
	"/k9MZN42edRGPB7a28ANW9Px3UPmGk/pCxHku9k1W3Qo3wswaH3aqA6gOBHvIg1douUS7p6wB6o4wLye6Wyb+wsMUFnT2b+UnhFF" ..
	"ICjHZ1+eAME+HR8n1PwYSJzUf4PuP7NtWQsQjTyDihWnt7f67oLCiQRDPW064bKBljboNJMfcreBQ3b3ell0+0DQ+6idyqwROMeD" ..
	"GMJy1uSYW6i/H9trxQ3/k0X6GK1Jb1CeDcyZ9n4Mos2BfLH8IE0J5p0W4eQCfWpycKtl/3ubi0Wlh5j1ao4rWoyiwNM42SDNj1o4" ..
	"uL/C5gyr7esW2pNIF54luNerklJ9v/uuDATqTicRIH4ikoAGoV7+u+yPz37ugfIx+LEqh8rFPDT17Q3HjHXhteqxyzrorONeCvnl" ..
	"dw5Ijp82QE36lpOJqo9lichUOMXPj4vc9WZw398zIpG+Vch6j1pHII+du3svaCkHwRmT4yx/uvDKOt/fcigjt3Dad/fipmGl31kG" ..
	"7VoqSyjoQH8A26G0nWT6pGv78MxNcrRXn//ba1XLzwFweSnGva5+49Q82JR5JswcYvZtymYh8f/SZeDya6G/W/eNU7ZmXwOxtHKt" ..
	"J7baex3rYU0R2e+NiZMbbDFM84Z8UC95i0IbpKioZVqCxaiur9ru5l3APx8QCmEWabN5N4nquHW0VoymdREqPiidfJixZlktj9wL" ..
	"va4RF7NWZ/vkukN62Inn9gkussZ7jv7WsDXTjdm4dcvzirLGW3TMUAvqNoSQ4Jh+7anVxyyG6NbIIjHNh4IB9z1+WeadcS3kjbz6" ..
	"rR1YMOirkgiv9lLoK5Pmp0YTemtz6+TlNxCgwGHPYKU/vcgGhnhu9pdU+kApLBVl5c0us9QNZQfepyv5fZ6SYoN5b73BGVjo/VFo" ..
	"ZkJ1On2TKVTu1zva3d2w0vvr8qt3p7J5xHrqAz9AiSOLNbqNGcLHXNczVJUxFjGRYcEjjTqod8QJqV7ooaRfQmrluhtJhwM0/f/f" ..
	"vVSrvfUvbpW2g/4x14rxRaUG9Gr1qpikYhMc48wz8KVV4LFv5Uy8wWhbGWOiPe70g/hFSDtT4K7Eicb8ICS+cmjes7OqZWTS1TK8" ..
	"OfWckPJiPw5C3Lq1RqMboySFYQJVM9H1OjfTC8uyXtbRZ5Kiwh2lTSIZOORJA+h73qBSAdzr6+ZsNemISdTbySkJL20PcmCio7jW" ..
	"lCYWtdM+KS5nRu7JdZcfbd8eYsrNFqBWF0JAJ9cD0MeamJrkwwrfejkIQX9jxfpUPCSOOFRPMAZ8QT9cbhYMLyZDzR6rjfvfxPJC" ..
	"a/5VPDLUf5A1ffylyVha5xj6adREds9YXYqwCp73XzdULlivBH/zWsfUMtZS/z07ZEGMVzeJJ/oZ8nrvbnXoalSDiHDgKKtnPUIe" ..
	"2NNJZtcNOy/Ktk9A76abXCA3Ipb+bl2A2cALrpFgBexNTQpdLo48tbWS7TDp8oQElv4ppFoJko7hvfHgCnW68VXMtvPRdFBkOBSO" ..
	"1FBOkrwxs1s3vMkQ9g2TX7dfwTyE5nNIjzwqeEILXYKh4zV8WFMZDRASSM193QGi5BjSEfXYwAg/8YgQKhgJ2LdIh+rQV6RRhHim" ..
	"mKkOGPrfzWoLn2yOQFojAbB5eA/ZuTksRcSS2sAXBjIFkCRv9SaYXuNMpAB4DwRCuCb9BJRBIRP4npm2TbtnWI6jARLXTEDSuqNZ" ..
	"9y25co0OkqWlJ5e+oy73ywRZ8Mek2qvkIm4Wui2L+PtnPxIYp0+fbjV/fYnKm4mdLTwRtqupc9jC8LIJVEZJg19X/rKgANOqdkYH" ..
	"zTljJj+6kpMLO91TzUbcgyMdKMVcb3cs8ptAv/pEWuqhNdFxCdZsnE4PvVV1IbpcDR3yZ9vr/euiWHq3nzoBk6hMwFt7R+lRvqXF" ..
	"dsZd2SiGwdIV71YDr5Nb9RoyVkLF2moy6ibdSsGy+n2c2ABH9WegBpXtSR/UpOxqrQy88Rl2MGfmJqPJKT6DZzgdkzTcEZeyY0a4" ..
	"fcWXKdXJ9Tj6STJPEh+2vOBUhNlAP3VHCzRlrxO9VfQTNcNCyFSshzfE5kb1bemkQMcwthY95vfjQa3N07wp0Rol6N9GbahLbl7j" ..
	"DWAAoxJks4IQeppSvWBxZmUu0oAP9OtgQhSpVkfu/nMZR4RqBnUmTbUwO4sXXAt77y6ghEHQw9d7p4TBjhZ9eo+bFm9jVPuXpeWR" ..
	"jnw4Cu99chqvg5GM/gOGJftRnJ+2i2Htnlwoka8HW6uxQoP9iBsLjq0CweIDEHhNzgqIfp6dx6EkMV5tgBgw1yS0Ewx/PfG5cvZf" ..
	"Fh1dpQ1yg0EkG3m9yC7RYIjM23qyMLqCTcgTetwvz+bVLHGndmS9DnwS6mCP4MO5FAVBxexJU7TGJH+kzJPF/C9TlNmYjosj5aIB" ..
	"4/iLDuoS5CXBO5vgDd00/XqYt5ldTEiwyCY3C2Udyo8gtRI19GMZXPLtqHJLn8OBMSAiGknS5ywl9/TRPAcdT0GVuMsYMfYnaxDm" ..
	"WmqBAu+LWmJ2IeYkKl0gEhj+YYMjw/btVf9YgGXOiHqSQX5Vxr0OPnYVJY6ywMOk7YlsGjQxJgMHkx2/46z/qnZE6RyJdkDuGe6p" ..
	"uNoGodJQUZ3xQ0CyzmxHs4tuHbw1kmz/6Q0txmzSxCEPAW+HinJnuAlYK7L27L+IRMaIpJEl9FoJwVYXg3iNJl5MqX8ReGfr+DtI" ..
	"HNcCHrAGMisyNol5JL7t0V7tMgnMQI6yq4SZMRQGYzAKpT/ertQG+W9I0m0qv/D9cnxc0aVBnKG4vOFU8pG9lzDNZqMFoXXeruhf" ..
	"w7XhDlPO5NDKBPAy4n/ksYNmswIot1aSslpjIpWWYKxjyeLLnB9yqm+xi8s4aJ/S+KMAQoFCoKpikcyGvrjrJboJUiiMPXxTdEl4" ..
	"yDk4BGOKQ2hHLqYTJCZKnn1+KtyeM0yryEJfRvyiQqoOJ7b4OvIgZ62wQWs0PbWaB6jRwua574AGdN/zCREZfAkMPj6+6W0UrVw3" ..
	"sUzz3PyTiT9mckvEKhgyZxCkv/JSwO/0AqQk7Eg9eHl/VdoQ2CusV4L2+M7dKA/EAcs/H0vURourd5N40fE9F8XeCCrNQrMvU9xk" ..
	"DcBVULZLIkrzbkj2nx3MrRdnVJ/FcV1RUfTWM+wtdgS82uasJfDoS/7s6IaMuSarcDjF+sbQPKzyIaq2pWu8WhmsvhGCERFoCs6C" ..
	"s1Q34SGaBgiNpFJC27hJerwm8j6L1tl4CJsFQP4V1oSmkqO9j3czYiIO7CXBC/2ntKu53tDUrbcPYtfjwsEG/QW2CRukPdcsSd/u" ..
	"QGgHp6fvBOGfwgFGkWHDdmaXKqAYm60UZwG4vplodlPJAMp6RYMobYFZ00SvERjSzN7clwRtnJ1xQsbFzdZ3A8wnlpLE+9WxHcMJ" ..
	"mSYXOhtE13CkQH356h+5jf67pGygw4tDpv+h8mEKWAkINpieosPyrcWVae2q/2gl8aZG9a0h9BaZoKNNKSLs1anyWK0aIViBwloM" ..
	"AR/1k/G6lOHw+XR9DKl4qPfjRjm6h+2fvxOzzMExJR5NHmRbClVK8qWnDWK3Qb7UGIrY8eL9x2pcESmlTuZbRRahF6pfZsVcQsyd" ..
	"+GE7touUo5ujihokq4bb7tgl6pwbXshYwwMlE5OOwTSPDVo6b40tRcOzemOTCmG8al5OAASqsmMlZfjR/uiCXDPekDIA3o2ZDvBF" ..
	"f898CxGsCYhRzG3ZkkacsMUXppcyDmLpQ0dQ2W8h+r/rQAFwjNIe9rgO+AdDlUg+2awI8cElHu8Kxs6UuHrrFSSFG85BQv6pqqL9" ..
	"JR4Nprnho8if0COK6CT0ALpIxvL1UvTqgUccHsBXqXJ8GbNwWDuX4eNS8xyblIWnF6NscK22oOjczODm3sUVz2lS/Jib3mrXa4DW" ..
	"030RPKWVX1UaG5iXftFSsgX2im38wDLEnfKEcoV+PhkonchnM7vSFadodhhET7/tVGuFlyiO8WzFKkWGth3rmABunUyHg/aDqVRt" ..
	"xN75Z2dZvYR009xxquD+FhgXq5Gciyf7/aoqmvvfxcsO6bfQdCdRhXFAgl5mZaHOEWEqMNJWdoD7LPG/hzSyid77hiSE6FCg74MS" ..
	"RWCRQ7R0t5WGwxThogiKEmQcrm9i4qDkBPFKLTtkktj0PykyAoHufuQisdQPEV6rs8A/KJKFBf1/5QfFHfczGgfUrAx0q5wMABzo" ..
	"2hLMi4zvsn71o3qGZ7JaDZb5j+PXS9PABYCmqktAAaaVkem2hUUgXriz07pfEb/+HR5YHw9rr0YwmVbHgTEzuHdlR9NrJ6lIKSmd" ..
	"JF00SHUFrKjTPV4RARqGhgj9CL8eBMEs2zang68UOKu0Rx6d05SqZtao6pt6MKqqyxykRjKv9/P/zyqA5Ps4OboXVKd7hLvqJ1Cw" ..
	"8e9aDleIsHLUrDAOWSz6Pgtvm6bj57/JZNjEfo+gfL0LPW87NGlOz2UcjB7OQCcNqalSSCuP9DvE0kGiKEomymaZK6Ot27DeK1IT" ..
	"+JsroPYQUhI0Wl9fDiZax3ssQQKh056+D+YefS5qRMA4yTyZlkmAs4ofdrSYxsGob5v6ecglCZtIOcoAkjKA63bi8Hwr1WR/M0n/" ..
	"uEIGh0PaENZAPVShaG/qvyvvAYjoVPAiBWYDUfLdVDA04ZUMT3JOlrf00L5flTxD81V7NBl3zr4YNQewFvSk2YjgXpccxqRReqJA" ..
	"iCJMsEufpYeyA3K9AffECufSv6RLOEekp38JfysbKlAwvBeP7JDMm47GbUk2YrGJ5HVU/dHhpygC8c1T4wTS27WJk85neSQl6wma" ..
	"b4JHQNMliLRGlsH2KSBOYDacw6zuM/4loU8ZDpru4p1Bpd9RI7iuJRUAgMANFLzCHvyjELfAB1J8ZTXgD608bShZv9w9jzLKkVjx" ..
	"NJHLKe2mPb0ilh1Mqgt3jzhDKVUuglzj3jIeiVPkDA3ZJ7Wfe4YmcddOwAPhspnd6ePlyfPmtYJOTuO0T1zcm1xI6QHo75dI/XIT" ..
	"+ovKq5bJV5NpZntWYL2Q2vagsKneDZgIxaQO98KwMnCLSkFd0Iz2Gs8WhggKWtGb2/Sa47K4UWe/OXtmm8p7dcu5JLhGy/0ptNcL" ..
	"uI4AnJMivKwJpquSXH46S5Nl7DUah1p2Tf66NrNawFeJDOZss4laRNPtrDrGGoyvfYBNH94IbwJodrMfth+C+y+uCRQAMDtT6Pc7" ..
	""
local PAYLOAD_P6 =
	"do0IiqPCseSDI/Rl3z10OUrjNcXXm25iGTbNDdOMYM7lNMGWeiX9E8P79NYT6I+B7rqxrRdUJpGCsYUp5vhVOAue6jyP2xtBNVzs" ..
	"eGmfNUt7a4ONdXEKEwpKVjnnfUpmRCIxmeU6akWWcdKM/5lmH0dpjSsFYc45VLqSPGQDCuH5iZ8bUXDhSkhzwvFJAmD6vqs5c+Nu" ..
	"Z0Zh2VZqKIvIAMLo3xE86CrCWn2+hmMu2hEfP5P5ZHTDyOIrtTiWIoPEgu1Uxxpv629KrzMSMcK7rel/e2N/WmIabp6OM+6Le0S/" ..
	"h4lDDPEo8p2DDcormWH4+W4Wh83RX2biJcvssDuSdV2qoG1dFzwpMMcajLyZCVM7PtA9Tw+kwPc40qEk239lIJ9fc6HqteDu6qCH" ..
	"FHHjS3jVZEvG8DVrsJiASpedub8I3aKllhS+2csx+dJAtxAIadbQhJ4Zhfwc64g2soR6Wi0hYlgTSkPbFoaBi9c6UOhiqzIcpv0P" ..
	"YdPLmwG45QsluI9DAD/UswH2YI4wJ5GmSofyuwZbWBQAsfiX4cJhPODwZ7rg9PeJ3vqd3hj+GkvG2p2cJR1ead892+KRo0I5lWaZ" ..
	"5IlspoxWngV+Y8GHaZvMG5UU2QFrNPMq/vRBLTzKrzYlVCS/ph5HuZ84Z05ZVqT8dZcn1cm/hWX96hi95dEzQ9fQBQWXBUWvKz+p" ..
	"kAzIyZb5cjpuGXhzwcVRY74LTA0I1mVAkoMQFzOsLiwwTAoAbBAosnfs4aEi83NEUCQw76zgGOQA0eym2QUyUCBIrUElPZSO6BGk" ..
	"28sHcbhFdS0k4JMtDPcrqINFsNGsvDes9TXmbrs+xFzT2LAhPDeaYotaI51iqnSGZaPVCKdfvccUVRP4cprh6V/y9e9/VpCgSGwV" ..
	"FAH0uScAVRoUWamrirHKmmCMVs2XryUGk14Uc3XJbGtF5VEGFilit1fONGQExhtLrI8MG4mo1Dna+HnFNNKcVfXQaUXQU7N0SFLT" ..
	"F9hERzeDL+ru1n6E1YBRZjVLjw0d0ab0IoypkrCYf7rfnN8YXhkjCHD6/4qkQoufooFdehAUZ6G9rtUPUplYSqw2voItJC0lAEvz" ..
	"WA0SHWFBAPhIQDDACSWliONwsYeXVPoZ+zaiqtsD+FLOR1nEaZjK6mCAQEDbxhy+G83YeU37aZqEQb0e9w1p5ptssaKwWoPn+fzL" ..
	"7CaIKZI8gp95mRcrlIfjTbWFdmAHmpRm9/yelE8++rwHcNthEcLIzjq4Oe9hQ55noTmD2DoxeRIWOwttoN/7VYIgb31acOfyxsvV" ..
	"4hQ+J4ZlfCD04QcdigdCvt1/Dk2bLMOyzs+jVuYc2BIrJ6ok+jCEBR6J5+yOAw/+b+j11vDabnzI2Y/+BSr8BQZuJrXDLrCkScsd" ..
	"Nm+dbHUQuOzjImvQBSX+elB5Mf55vTqR2yC2bgrG3dNt5ADgT2rPIIyN68VaNQwreP0+PHPhiderGuLDwq0LhHV4Ds+b9XwxNttx" ..
	"e4Fx2Znww76S+cZmsu/tTtECY/ESYiQZ76XlYLXry3QVv5Y8CW6WsSBbfqGdU6XSmegz3KrauWLCGtrD0S2LhPZVV2Z8mAxeBXna" ..
	"LbiSv+Xa/xiurV2sA5KMbaEWq4lgRljyuzvxaGBn+jKOFkvmfegfDms8MUpbbkkqR+y2Kr9UjJg7Jed9FduNLXCtbAfN97kfy7YK" ..
	"gIKzM07JSMiAjYVgRcAKZRluPI6MLXIBEivZqmieQ55R6X10yD6vHDUyrSjc51vv7y0GX2VUnATuByBaW+Cx3nnDUeqYIAh7ZSUO" ..
	"mp6ueMiyi2RCI+9h5S1itgqHtuhx/nK21jC5ibHIAnK5ech0pZQ+qD0ne6Tf0/Two5HgeqxqrVCaEcaypll9kAI+KSqnrBkEdTeQ" ..
	"FPTpEO+bxNPN18wmvV4BIuOblA0iWed2O91jUvr4BUM6Tv3m94v01zxT2Wu7r0tGj24xkWTYHem/KYnTGYYDUKu4ifbHr4f4LNN+" ..
	"rYA9IH0bEcCiIMCsMNENXs/pJtuXcCfLxAmC60WjVCc2R4V4yFrkfCOxcqnLHmNozV44Rx8+zUCCqymJ/ICCkjQ9NAkcQatx1Uw/" ..
	"etrSgMa9edFmjWd2dP5FjAKXniSquiLSRv5nc62LFLRya/zWHELntYtKBi9/Bp6vYXxpZLaDLBlgVnJqOa5hPKoePJmFPiBD92We" ..
	"p1MpeGxpoS3cNqs/teYr7ISWnuWS4sZU/YeuYKemCO2h6eXzum+8JFFXzydca4SZL2OXKRLkYZr6CXs0rBq/H983nNtH8/ru4nxf" ..
	"33cqeYYuWMRJJFHwfMIOirn1q0rTJxMgV+2+1QMPk5/P/hHeOjyuBU2ntkD6V7TTdGRl8Z8fqPARsZG1t8JFYNweT1Lb1U74Suxd" ..
	"f4WOLGYKs6NYFwplVHt5o8Q6FW0lVF2CQ6kdpg3KeMVIVNH8Aj7Qd3FqkqnzivEDnOXp6HNpwhaUQZ5t8/th4unnZ1NKBXMADLTI" ..
	"67TyJFlWCDn+wWMxaeW6WPYY94J2X2/oDuTPpDvl7aj8DYzOxocoqu2egmemiJx1XxqW3CAHw15q5SeCo9blhaalRP+m05g7vhx/" ..
	"KH3/vxwBdVofpHt5l2vJztwzOogeVCy7pi0bQWR6Q44fr32oskRocG0FY/fwzrCRmVpU6o8o6enwqCX5gV9UCmI8enD+JduZd8lO" ..
	"Khi3FuIusbJcIPbJh4Csx8laFV2WFPtKiyOeT1NV6hhjBYsq7S5BI7s8BGqNF/TQr4hkrVGjkRiEWciEuIex0fnOr4Wm61HKf+wS" ..
	"ztq/XGGzJADrpPo9CVFLgvF05dJ2rhYH11memir15NQcob1y2h68jWNGfidgLXkLAcTwdslyiVjDwcmmLRq2bEbmVrm982N2tdVL" ..
	"3q1Di72w2eGvK2Igj2XACzUgMgHWPOgCOch4NhbJaw8LPvoqruRG75LzT6FiZUCipo2GPe5M/+CeiW8NUC89JYcbEMU5ydX93+/0" ..
	"rFAvCyaWR8Sa3UbZcDu/jcYPmEwWV9JsksTCjwdanUftlzwcKcbjpnPV8oMSkoKFexh6x/wtXVP7Q8WzIVzd96ZW3No65juvnUYT" ..
	"KeeNOSblaAmQ6rNdBaJTfVxLwXKpHvQSxwV8GMAGcr7P0nyCylR7W6k1cwtdbymnzExrDJLZhk9GRV4DnNCTAXUeuQvvHLYwWXYm" ..
	"aQHfiivp2ipCYCX+xs4pqL1elfUpCiyC1DMbOf0+d7xIjh9LiM79NyzC0oVr9AgA1oxzO+I5/Fr2ZrgikWtqKCbdo4CpIAdpTXoD" ..
	"tTaQjsJaswEbJ1p31D4JcfH0pCeN3n1PzNHEy+YjvWwVLrfKvgIgj6AiXTx2OS0Yfa8QeT3+XvelQJYy5HRJaUx88qtU7FS5piQB" ..
	"vjZ8F2+XAw7nYGzrKIdBWv2mmf5d+l9nod/AdDf298zsJBMdB25xXef38A7+9YzwGRL+rDemTkZblSpAU5xWNsrjnXhNqQ/lKW0P" ..
	"9ySZ+wI6wbsMW3nVZTlofrVa6kGhLmRDrtQ16U6fgM1tVSxzqFnUw4j+yRjE3tEBuoNs3EYoEXEJX5gogFAf2NYwAawYhZSU6fjG" ..
	"vFGdwjwv3ZVS2WkCrwv6aX74Mipnvhz7P5k8QHVZRKQ3GUF/m7mx1xZ9F/n1g6ooIwAQ0rcUzJPTxQQTRS7WF3Nf/pW973DGd4Jk" ..
	"ewj1mMCgl6BNd/PNnobu5D/xX47f5Jp/Km+ZZsH3JsWl+//Z8iUtJc2HYy8CDMe9zIB2YbmmXBTBM+v3frsbjGh9TNIzxFR1rgf9" ..
	"/qt8dafmWu+BgrpLC/IADFPUIwp0oFozP8jHjtpu9h7FQ8LGbjdH6tLdEDQwlcuso6IgmEi7lcjgsb55m6xTyymxMLQ4I0YaNs1P" ..
	"HTX18dToKW/IPJ2fbHslLwMje3n5eG2LYxXpybfzZq8m7TXvkm/XWg7qo7UHrVG/d4XYrSHspAxuaSbBEMfgTzGABjYXBH+gwqax" ..
	"MWlOCVKkDDIwtWS/GX/g4sasXz0FFavIahzqDe7YrD1w6o0dcFJJvyrp2L8q937Y/xtRBbt51KaYwOlhffa87lY/kfyuM4MpzA4N" ..
	"f5JuvkzHc5AIGNIfrGMGr3LhhZvhAkgVVSBC/Yua4Ne+WsKqH1OvD6iglHv7fk9cPH5xsubnRxdtm71euHX4FjF1tM1rKDVTLQPO" ..
	"nEt5KnJFzBnl2hj5Ec97u9jTZoEgE+0tc5277cTmH6mx8LGHSE17mI/x+m/S/Pn4Gb1FeXxDsUvgSBKXfwukMkoJcGkSjGofBuGk" ..
	"xTs+yKvNl3M7rNlKC2xkUlAHMFUz++5Qv5uiBdAqpJOYr0Ww/vjyfWr24vcUo53IldE+Xrlnh1WeUC4P0ttvoHwbtgzhxzm2jafb" ..
	"j/MnabZ+f86ebU8fz/mfOy2I3xAh7uy5i7lDnIbFn0kFtIixRFo9+VnuCC7iTmboHYPhaxqodGx5G70PtjoGW5XewqNzDstCVZYP" ..
	"TVjDDHYB6Hq1xpT/uC4rw+bYTyTWiPbhI7H4HTcxfdTTVy1EY5SguBZbMc3A8E/Ekt5kC+/lg3GvGRk+fFskHVNWXmQF8UcBBDIP" ..
	"kV5H4dPpbQmRLYbUEGo9qLHWXpp7Xo/fS69zA0OSz7lzo+0oYRbc+E1LsGxMQeHgrbbHDwcXX3z1CH6wMZ1689ljttDeNhpxJdkG" ..
	"T65LCZerDzJoDFfyYJqdliqWiD4/ysqYywtAinTwAMPGio5x3FXOlV96A6/f+e94ls89/WrL9BqYws/XcIDHZjRwq4nxr6GX39qq" ..
	"dmsCbo9k4cdnhzb6GEma4OflAHLgLnjBFfL0N0fICMU7YMp/1zI2NRQWxWDKNz18E8tAjIk7KtHBnUt/5bW4+4qSmmN0L2Ok+sMc" ..
	"AxC0gPFz2vV+evkI/7INurdzqmKD9on8++GdpMaEXYqeiXfbmkhZgzFhR77jNqDpvJlF3MIIBcjelJGaart/ESMSgsYQUDZG4xMH" ..
	"DX7NQfZ5sORLTMr9zzdznbQJ3npaMlR2R5bq++ytShe2pt8PDbEYR9EtJzuq4uWasSOASYBHnsbPC5Kw/E7q2dVoQErth9frs3tU" ..
	"dNS/LIR+gnwnTiHwXlCLEPTadojKI+OmqVW5owVkY6Li0jvgplcssF9CwWzYII7nHp2xDTTM/RG57f8tVT5hdxMuTpWnA3sy+z9u" ..
	"NohIB4cHUhir3ayucq8GI6R4+mCFRTE8Z5cZEj4WAbLTiA62jJkb6wVqL6BPLdEViYae0x6Ms9fthhwp8wYMjkDXiasmDT6RXGkw" ..
	"zU5J4pCa4vZG8pyub2kNEii40s9OHSvwXu1diJjf7SRrOjG/auJXaX2OlUB8WmmcWktzfXu4aOTjftR6VcxSl7nQOc8gf7DH1lAG" ..
	"LGfiJo+cdypLVrmYwrQIZ1uCjxl9CS3enOL/34TnuRYdd2qP3WwGScMH2sB5JA79D4O1SldIq9Zwd4owym7L7MtbzYriC4yFA31Y" ..
	"hM8oXW0xoBmghOwJvZqrh0o/4hQAXBGVnhX5JejFbBQqfG7v9AFrDlJhT+g7UL3rKk1vJ6l5roR2VpH1D8laWYbCb3m4NfOOYZlf" ..
	"19ACfL2FmRErIYWj7R6wAN8QsxZ+aVlubZEBmE1d8EEpHRgdSAIXsPPl2OhTT8rBuBHi1MJb2H/RRvNg9sYIalRGLf/AzSIQIcwZ" ..
	"ruf066b5dqE7T+RHwd4/NrK/STuW0mLKcCrfc2E0qrgyA60qt2ueEZwUAdHjV8rqvQ+gPGKw4Nabo7CDF7/DAP6UFU9lQNolkKlD" ..
	"XOGiIIMMwbWckr0qn0QH6Mj0PR70Zqt6xmyWzcgXK2TcDk07hzBRBZNTvEam2smxGJebzxo4I+x/49OV9DSouZjUhnOb8ppCsSXn" ..
	"jC0WCsHO14rMzu3Sv6C3v7UKqK6AjYuLh+VjezfY6CXWeWmZMirKa6P/SL5AL/2WJVXgY7wNewOkgqWqaY7eSmKqt++/d86sZCxZ" ..
	""
local PAYLOAD_P7 =
	"WxqVA6i4QivpE3JUPKE4e1Vph+zbhsNNVgPdKF7BZzG9cWEPEnnZe7A7nDzCf5O+153csN0xqhWhJDfS9i5zuBS8LxvxngD1Ed+a" ..
	"bLRt+moqd9QHLq1wfAvS/PUS6XYbDeDWephe0YK8tiyh6epP604Hfe/ai5JXjcjtsjiwX0ImpqY7j/PcQA5HrqpGTCTzBKdMq0id" ..
	"6fHocMOKfuJd3aIQv7mVrIfScTIHfGd+cG9oeTR+6hzirKnuz38wyjiFyMBrjvbfDorbcDo6qSLQFovBriSBFilWYzlFuiH2XRa1" ..
	"ok/fbYqT4LXV+lFGnWR0Oc58xTDr65puA4SMBWwvqUBPEmol2JVLDQg/qRDHA66DOsGdw6ZRMZ6dJXzgp+63F2SPVx4RJHzrIznb" ..
	"nDm/ddJ1Fu0XrzIGVrMWooPNA9Sz5yEi12tUyXGM4FeOYlDXr6S/Xd4IfYCAm2kezmv0xzH6N/wQMRPKHIuQZZ0kbdoUH9ohBci5" ..
	"P5WsV8aCL8saBNIbwCmzRuATn0WMHu7xDBFh9KJEMUjmn+S1tPsBrbEWEaiITmqzkixx33uEwWNt2nN6LpgULGHOpGret3ywdjFC" ..
	"pypN4SCY7SiuAfbm99yOU0UttvGw8ehN2Y/2yf9y4DFE/PIUItG/giW8JFTQyLuZVzH7vCXA8qRY5X2XbzlAe0ZzCR7QNFb3xMCK" ..
	"1jKeXkBuL/MOBQRhzM7f7xcxJJefhmMgVTya9MzDSL96bILJpNxY7MevD6dvwrAc0AspSus6qWSqcQYroJNU9LcwGNRfDUx2khmi" ..
	"HK7WnyFUycAkdZqfixc5Y0GFLyxPmmbt2Fjw5GhU1BW/GrlLBAj+mnfzRJQUP6+sVXK03sxQ3OAKYwZqVLTrBxYyYuZoAiYYLCuB" ..
	"YI/SrmfUIxmQ9+kJQhpwL6VPwNa1IvY9LznqFGeBqIcToiyebroWoznVNqgMv843hwLJeJwmXVIa8gWqoUza4UCzgG/W6/ZieYd6" ..
	"PvbZF1Z23jXR/9zeb3no7U/24iYoQrdmNFdVUEY6XWRtjZQy+NQSqRm/gm5G575r9D+dqzBZNdrJhN2IRJt4JnETHGl9hrOYbLr7" ..
	"niuA0A/gJjSqVc/f4cYIuQIU+ln+nUdLgOoug5Sjk0TSz54dLuLOEI/g7vtP1VNwg3Ts1Ov7OQMtdIh1rKL4kZzyuHvu1x/sfzOx" ..
	"MB0q1MPVeVrFPrdYHV3sHXi/Q2WX6Jdq8sILs8adMgUQNKJ9JF2pQQhEYdG/cLEwtfeiQzfrxBMm5cMcYjEMMcRMN8t13pj0qGk2" ..
	"pZs1lJ++ExvZEf6nfFsZQDzG/5izYBhGZbOQAYOdOWSSr/RhwDa2zCc5zjafsQbjBHQrP3FaPP9LDp5hpXyLuIUiKAIaXYR/8Pt9" ..
	"4MW4dbEzpxTeXX3A4nu7PWLhhGrfCL1NxPj9yW3fgPR3aitE9PHRo3kzKneNfzY+Dhrk7R+wm0i+TkKKtWoWHjvr8NxZUbFMkSst" ..
	"rbwGPvkf/lJOHe5bMcJEwAPNMuw0YIWg3mmzRWQNmeXxxiUOkan9ahrBtYWqzHYlUDYZk1KKuzaxnHcgFJuubqn1GdcjLLSgogcv" ..
	"ygw/RrHL21xGhQk4hFh41/lUhfUS1NtebKlUVmwHI0+1JzySYj/CxJcx9CQKvmEveKxi6NrVoykmhEqw9bSHItPr1GIJWaoNAIH8" ..
	"wgiXY1L7PgUFs2SdE5OVVixaC8utAouOBtKAKeND5HqTwQU5xcpikXT6Eapaaq73R9XWwbQE6NVXH5d2pOTPZTZ3aiE96c/rDb9O" ..
	"7AeYXlatoXfGjwwSLznvXsAhknMAygHeqNvUO7Art9IWv7yjuXhIJDvzfuFZt8WyXWygySmI9aMqYuZHb+9o5FtYIkOORTxE712P" ..
	"Z9EYLAm/WwaR+XT58QJa+01diT33W4NTYMmEKcjUp/kikSOA1E2BO3m7W8Yp9h5TwqfqnwgkQLXFufTB7bkwU56+IbEsnY2ZnhBY" ..
	"YuYJfcGpm+BjntY2jq1vfb/EL0x0o6ooQyB5clb5FQ1MMwfAwyWj67IF6wHudWlFFmstJ/+d7dZHIo7Eo0vKFtPqrr5Gu5Aen0MY" ..
	"5/2oCyGRGuqowEaTOJE/BujejZuIZD1/ZSDr3SUBj8CQ6+RJlfrkm3ecDfI+liInXsxGZ2CmQc0vFEzljVICl5wt2/uhx5U3KZ+a" ..
	"3hN9Hpj6zcDmtAB0PZkXh0e+Hcdfpr3JBf1FNs1MkRSJrYDlGvhEmRUpLphFZKKfhMiLv5Qvr2AH/pOusgsXOIjlTV1G+bKql1lg" ..
	"jeGh9WJ/i7Fw2BhZfaLF04TbdOK9huYv35keppahZCOzMbW/11njjIbhYTXCt/VruN2jw75idDK57mfdbWVyKD/uaj81eJVDVvpc" ..
	"zfh273c+md4Lpd7Mm4A/kLT//PDiIXJiJwxfvbmX0bsBGn1dpRx2Qb+vLft4cC9lbvzlA+N73gvTSkFY4hVlDHlOA6LAH81fcVkn" ..
	"+nQiU3W62lPiXUtg3eJBgbNV1rDsHE8X67QWPCzz5KhwogDofIUrx0B/yHb3aBibBROazPfjRfYS8Iiljvpu6DYBs8cnAXENm7W+" ..
	"iWMOc0Xv7t7tEN2YBrQws0YVcjMuzTBR+ROWhXOA11h9T/QdbA9XpOFZ9fLUIilc6iHY+UA0HK+Ucj4XKzCn5s8Bu7haCMToi/uA" ..
	"ftvMz9CSD0eQU9iJ934FGolDJKgKt7m6YhBoU0/p2YErEfsD3K3yrYs6zWGTVZib2IEECTYVwWm4uLZZecFizYFhYuQAVVpw9Q1r" ..
	"XxBNryP92LDtUghf/UwCX7zypIxkQVyH7jB+kLJVwyQtmregteLbj7cpMK3hG1i18eoT35YooJiSi0CTwmUQ/v5HtZaV55ERoFtR" ..
	"6bflmKG8CYEKdH1vHe6RxUBHQBONdq0js96m/gPbzgZwcMxed5OkhyJyBcxKGAC5lnDw2QVSCpm6Lnrws4HPYsvOVAHCm12hj2SY" ..
	"vd6d/mCKwCKwiBUphC8n8hK7agwF+WGZ8D4KfXXvSw8TDRko4DpzFJjM2EhAMYtWdSB38dDLdLKtXXutzL6Mz7eAT0GSXBBWXR6F" ..
	"nUdFzpDvz+cBlvVmvRMGKM2bs7eIWP5vDahRFlX9X1elLmytTKf7HYUOacGH6zebMXvC3wFH7SSwox6G1ggMiVfTwE2BuK3dzKxt" ..
	"+zi4aZw66U5aUkZChhv5X3JWKn8mCNI+W4sy/L0LRliCgGHGxPAdxHipzuRgrbxwSi3yZzhoZaIRLV37Z395BAkKZSKRKXHfjG8R" ..
	"8GpnJ/bYBX/tJGBmjiSCmDPvlJy+KnDnrkHHB4U1MLK9RZp7oroY/zs0ZnKntcLwAVRBcftW1wAFLU6rTIudrWxU4cyKL26v5Rke" ..
	"evYSKH45aaZEj7l8ZTWnx1b/YBYAsBxhbVsrqCUTzKVlwn9syQdtSGDG54v1efrhlrCUL9GAnI8gyLFMMwdWk4i3Boi3r4X/FKyn" ..
	"LK6hVivv+Rn9MeoxVzXHduQoorBHqexaecvwKP2kKQtDWWM/P44pqpCKpe1/DGEzegmNcG795INSYWRVvEPinsyCdL4lZEjO8Xwl" ..
	"/UDksdV2UlLUbwP2ywGutAeKsOGieg6FKMYSFHLnupr6Jmkjy1AkZffszhkbCCbmFdK8XWCakitVj7TctzTqay3aJxx6Qd8mSnxI" ..
	"/E4SHYXIVR6YmZWVeq7cRslkZCeK/pGslDwH8SO76p9H2wsMdoeftGN4BbyM/LjyruMsnAbchkQ7YqPUEqoszQtwZlnh+R3ImOz7" ..
	"guShTfouLKJN2eT/B83v1Qg31YFfvU1TkjHKwYZ7Jcm00pD5ioY1whAbV9/0rglJvWZVNPxRF/peQ7UGrsUgYggq60M1xa1wraBL" ..
	"157732Dv73WgXZ6/BsMUiZhw6uWWPQtpbavuA/3uBdFt7W8rC++Y1sMcTxC4mmL6ribvyrr5I4cgfGzQYeI2Da//oRyaSDtxz9eA" ..
	"W2tJeitfMCt8FXQNJA7hY8fS99bggHGO/nxcsf3QRSvo1gP5fBcbWuIMzJsP/f7j2LSNUjrkRrpPxJWdeRmRHnA+Cdk751hG4iuv" ..
	"j83152/HxQenRxpIR/Dv0gOSH3vt98PZeqPPWSoS/P6fi+Ik1bzsrZFY8pga4fG9D54JPu/gLqaEg8luHpB3xdcpkf7Te0RV5dzz" ..
	"MNx0TUeDVBh25Rm+pHUXSfGlKqwh2hsbJxKJZWTpl744ArhDR1Let8t+qAd5eYEDIsRtrQlqDGBxFclVICQnrEfaN7Jp5TUKXJf9" ..
	"xMjJAhFihOmBCfDL4gn9VvSx6dUijgBmIBcj6lj3/+7Tu6oXKKcVEb9R01DFjjh+NuTBpXW6RiCXInCe9g5JzpuR99EpmAPFYBMJ" ..
	"NJxGYGKQZ0dpF2BzogxjikY50dWRitDe3KukrYTbAkK4iau8h3zMotZUfXUNoXTSTsad0V/NoO2VkCfTuVrZn5GpiuHk2Ntcg/Wa" ..
	"QcE05++c/5GjKa5TEMWv/c8sCXRk4KMM6a0yTW1yaQ0CrXVojbSd3jdwIdY3+kiwTOohGO1RrqYGZJlB+Xf/P2D6+jdcT/OExZF+" ..
	"bcZvl0gswYQe0dr78UK89nIN6Nn3jWvSFdkloLxpeyZcEeWNdXpExvMD50wYUi0Xr5hbNrEgGcJ+43P1qL27KSpgExzL/Vfh09Lf" ..
	"Jee3FPXgYyF+MYuT/DZ573VmSp8R5CDP5Qpfiixy56uMl5FgLPMZkA2ZMljkioSQmKtDj2DJNv/FPg9+p/51h7RcHi6d3Z1nkBs1" ..
	"heLoSAkCv7A8bnBMePu7y8n4JMpSD+2iLemRFDp/MucyKhvl217WAQG5aUdlGjOCMImNcGYOVZxMLXiwLu8vyv8zfvXwuDPnDjOQ" ..
	"BZ7nqNJlyYWrGPjFfFEiU8Vr4mnHrdx1JqAzS9OmU4Z+bJSMLjQYCLWKL1h8LGJzJpktOj5XrM3WJonesMio5HaY1wvFFG66WhAQ" ..
	"JSvmbmgiZqvbfTjVAO0uIByWL38lVo3MxBq85aEQn9WOVjM5dYMFzc150qeGrSCxKhKqXiP8ANDYr+miXWYR2V7jPaKwbDulgLxJ" ..
	"u7IyC40DeIb4SgdmvdAoHWrI+JZNeDJS9kZfBkPA0GTXD2Tsgdkm055MOHpvqjPTiliVCxYbGDwxe7SzNCb8oJKFi9t4SNeBsGAX" ..
	"OM4yuGFQRYgVJR69D33px7NV1PGosDulp6JovHQsS31rrqLzlG/3xvU0GRo3tZBXlTJpXTPzseKsRTtTYFRSFMffU/4bKRFydihG" ..
	"jYxj7dYbv2fk2zI4GzeQUxVlQlsPV0kXcTraUPiriyApsfg6kjxAcqHRpVh7AJbKW5dct7SdsgQjV9JlJyid3O6V4onRoleQoish" ..
	"CGzlqRkba0zz2lBdtEsBM3U8FNzyQGqgxi62cWO7JIvqcdRNluzxFSnXM5rAeB7IKgPizLihzHPhSFFcIn7LkxI8Oqg1YErciYg7" ..
	"TLlF2dpOamKP0UHdtL7lfThYVvji0qa0msHcaXfywcfNuLFdFfLfYdt8Inh6I0uNraGamrxeEQRBVnuLuQEyL5xIItVlwgL2JhNm" ..
	"BdFPQuPTTQItX8mt4kMzCR0ZB3JO0LIQyej2V28wAcaPRetvKB/I065/FsjyVZZxVJFR3a4098PfYkc/ZMdMMn5gWk4pws76a7WK" ..
	"Bz1JCytHe192LGO8HP8KqFoJYf3oJOHZhaJXiiEXN2rqIvUJLNl22wU1OVNkeEFGPQGf+3lF765FgLfYIYjrhedXIbLYVF+dCTs8" ..
	"Vup5hOFoJzQkf+s3R7W2R9pNjt16H56ibXvwb4VEvPOnU2Ijptp594WjE77xg4KdMBqrWZPH86Akn8kLM/i01ftaar/YTpwK7MsY" ..
	"Rzee8Iwu0IUq08fCAmiwfIohnn263fCU6QNqX6SB6npzkYdTyE3TX7H1KsdFaEDNVX2aEnEwMrpxYICBVblaQYz7aikzXUqEcuYj" ..
	""
local PAYLOAD_P8 =
	"dpRVpH6auL1Xaa5RqH/UilDmLocQUZlgcHR3oQRYEDPnPukcnRV/2zR31GjRqdB2hws0L3RaTP8HCEXs9drRzRiq0BYiVLnhtZCw" ..
	"KSuc21HqDk5QHoNhB4TxHLwMAD2xf+5Bl+m07/lgoV0xDCkd/N7fTBOw8bqRu8GvDhb9q5Bl0jANb4MdsD3oGZ8vCqJ3+95tRx5b" ..
	"D6o0vQtgmewZi8/ZAKUr80REKGe5xSNNYBMhewVyjn3KQvJw3zAFtDX5wrAzZ6gpztTvgSSN5L0rPinDLs4Mm+gO4qgzeAGeQOf/" ..
	"RJNKgKDbL4i672OoQhB5MZCblEBHpE7yDDwUdOzMVw9j/SI8OqgkQNu8+AZAGDLT8d6daARg7AHZC8GwTJxF1w0RKqVnDkGYROtq" ..
	"JMuF13o3XO/SsUkK2cPFXus9o/JAwBeL+W4TU/fXs2HVGhfTDzxnfsnyTHINimxWyPdPkDGT5ZcYeKbYflL7qLIgsHbFdEcgQLrN" ..
	"/0klMel8xrWQqH1rpjpcwI2nPELZhc5Cjvzc8sSk8Z3NOgDzmP6k2VhRO6kRB3x1NmwIf5D90PP1ElwH/AHu6kx4kGKVN/3023xr" ..
	"u6Sur9jGjCW6Bb6K/edzdmkF8Siul+pMbKRRWf4Kc2c62citdkxOdgWcFTdV2vgyKYSCMD5ZUCSufo0n088nXLZ5MMgVSKy4iYy+" ..
	"c4mDoCPsR7NIkRnUrYRwHDOBgalgYwLQLxi6lBwo5S5WKpQSLYc1OnkTyFb+7lwd7tWG87KIU2F+UqPrUGO5yosiSofVNLa80hVQ" ..
	"AzYOJa6kzf++E0Rnnqjr0yX6JmApNb3e1z/sLU9uFO4MqELLlWBKwiVjRJ9WD/iJyw6I7Ob4wF06A5WWAi4vFRnyBISJG/IZRQyt" ..
	"l8pwItHlPSRwMnNYbvKSqMQmJnqwcDdHumtP9pmqNVkcBm9tzWdVjkGYvKE2qgoKD9dTzQnEUEBWPbqJo+DrhWgLWY/lvv0cux3a" ..
	"hxhsOu2QutMBaQPFaj5sgMuDOAVQXf3ZLFo9bKlJ/AFeMO25uRHOcBMZkk2GKEaOLFHKG+7qcU9l19UqZfvWSdOkr43m9szW/Yx1" ..
	"TS4JG/ONm1cGUXHYX5p/IOTBTGMy8v/kgKeuBSL5qyblhzexp8Iz2U6qnuc2y9QjYZXqv27y88wCUrMLOhj7eKmSGe8/5Oarg/Gh" ..
	"+S8c2sr2nfJDq130OMCoPVuiZkqzYWoI4qXl8HZz4Q06L7PuD5R8Y8v8f07NNQRmu+9SF8XdilICQec0ex8a9k9xsLZ6NUQzP2BL" ..
	"DUqEc4rz0NHvGi5iZ5vJVuyEpj4uGyBgUfrxRG+1Q6pso0QNSGLE1QHpHdblk3poOVoGTae9W/bQcq5vK0P+jURlCQ9476r8c8Gv" ..
	"nKHCmOiJoG2FIyJr4ayN3PUh40T1Jaj7rD8zTdb5sltAfxXBHkAd3zSd4gBDIVnNWzk6C52k8lLnOsYgXAjbsi0S7HRt685D+H30" ..
	"SwJ79nZkeRRiCldBJeQ2kPKjBgqK1ukh1ureuFKE3wyrCdD+NITjVnhHFOHA/5Vwq7IeCr68oHx2Q/Xpom3dWBdGxjv7CXeLHRd5" ..
	"Ia95W2+jTNlqZfkgzYumbjX61XIQUCBjgkH1jiASxPGcR4gGQExJnnjihMv1SwU6z7b8Whmz2amIQ+qhq+44P8Yz7yhe3k9FqjJX" ..
	"Dd/QqZgmaOQ8tNl3WKWS6rJNwlBGGTF91pdyKg9XOhwFRGQldLbE8Xg8Ro/MhY8Hz0nHZeomk3hTegkSpAfxGXe9SxianJW7j4Sj" ..
	"HELNfsYSwSDHUYJlzLpkLidbjQo6GQHm9PpB9BJ+agguBVQxUrsQrutX/i/kAS/CF+kP6+4pRMtJSfI1sZEU7krkuEI4bxsiiIVq" ..
	"FQ0g4GlPDHk3BSWyJ8LbcK5756+l9NlHimS2p6SBIlOLzjmqiCP6PbbuRoxb1ZFVqH+zsqspyfqv0pv4OsPWdZ6iKi+RXraed27u" ..
	"7IzmFAAPp25+P/tds9ZtyQUogCTCav/keUk/ObGKW00EuKuAlel1T1p7Z5WwdwQ6yoNJu6Z6hdlQ2+jQ6E+i5kphkgBhmggZlYgg" ..
	"eb1Lqr/HHkccDumM0l/ddp/WZPVliDJmaY8TyDUlMYVTHIyp9EmzbwHHaOSrezpfZT8LFf+2ile8CDjuhkf5TvruEAcOUvnDn7eI" ..
	"eNWgHHshfUf61E5GoubHlL0tMlbneN+o/gNGEOBwnlJVJAO6NnTZieP0DLFtrKq+77ZvrI4Cfl4eu0e2+IRLwvIm9CrG/bWSLk/E" ..
	"CtrcjVQEM7d3X0kjJjB3fqi0IA5zy45qZ6O+2EP1LMF+qSq6bJc7026I2MQXOBZYr4GtKkpg+9yRzlT8mXVm1+Mh903h9yO8THfj" ..
	"ew13Kx4RFHZeqyT259fdTmeAkux6RTNr99eQRih6RS38KBMhNmZzhesQ/3RLM406EUMaakUI5AjTA4gCZEjVl0gIXigewuip5uQc" ..
	"CzFG6REmsoSIL3/gnDgMKLVAp//lSV9S90gVIMrnrWdFbjj4EvDsbz8LXLAEd8segWLBE0l/zmY49QZV7WRRfEhwrdLYfBgQzKkp" ..
	"vw9rkebF5Qr//90807eT3kbjb891V/5ldJxDhLqvpofUCEkn2ODjsSp8MSu/t8EosBn6GS3OIbRtlemQyhhqsI3R+F235sj6J3EQ" ..
	"Wz8QZ5GpJggbdUD9kEgpcjJyE+U2IQG/frkOVyikX+D5Z3RaTGiFJ0R5ses2r3SdCjABE9R49wZzMMj7dHdVlRglgUyxVt5akZDA" ..
	"ccCm64ZZhsZrTw9e6bGkqS4Bd24BHbAdWOntimMUD+3mBGbsNF11YsSKrgqc8grNYUfmPxDpqdoHRipblT9ufuP4DN1UQXZ4Ya4p" ..
	"NKKDtYf77hdaTPTLcXqMybdyYo4pEbVfYUNPWuMO1n8UGoAiI9MrvOvAye2p0P3Di1tqN7PMFRCTS/ydwKVSG70UAKlNYo5uHagU" ..
	"D1I8HBEzS70lCLRhL68aIUaVf4XnpneqxI321Nqo9AEytsB4TYyebfTwacRq+NsH50RWPj9ccKQaAddKCRlcFe+rO7sMicFWlOnW" ..
	"zqHgrudMD0893/A8wOzglROpY5zIAi8DphgukmQgrRCitG93vxrK3I3/+meQe34SzCLLSbFjvXAZXz6RbUAJSL2ZIPgmNwlYh7+5" ..
	"CY0UJvR3FfdGab9lmHvEEV8iQ4EnyP/7CnWAHgbBmp6DewF5rbKS+oO4rv2wK9C/CXQCOHSc4SJIpuoulGSgr8Skr/jdcEA4wUrq" ..
	"4YnZpi5BMgQ1ZX7h7vkmhCUtKg8cTOXPSVrHqTZGtl5Vw9HlSZna3xDspY3ADQsWjfJK+m/e7CWPtSG8zKWVy75G19z8Au3RyIDI" ..
	"I5NFOms0kM195gR5iJL2ousYaVa7amKoJw28M/crCKqvpcEwDFoVo2bJ5suWRD8GP4r6c8zoLnI1Nf9atVBTcmQ9vxqWmAcywi8J" ..
	"hn1xufi9/Jnp9oCu2/pquFI3ZW428r40+9X6V6RIq5bF9GkpjEzpbb8iba3Doh/rSvTMerikCKGeMOSLzAfNBaiiIZ9MrppXF1d0" ..
	"mHlhT7FGjWpru+bvlrO87OzQg8SYCPIPvLARqOl4IJ7YvwOxHu34sAJNRclIOI3JkzLX5dhFYEa13vrqVdWC6+CJFyEBFuwt+sp/" ..
	"SncQGHeGPRr3Dd6L5LKmGwi9ld5kn8phkmL2oXZQGczvliga+NjGO2dJz7EkgFWZ+ulh2tC5UoN1Orqv1tN19p+hs1VwB6E3WHm/" ..
	"I5xadU1Qp03kuVTjbEUp0G8JdL5C6pjgHfZrORWQEODm5mV68oqpvskrf+Gbjug2MU8PGI3iuCUTNzHVF782X5jnrCItupzwYqKF" ..
	"TQgFDstWMTER6KpW/6FbXG/et7VTZjsUTCN86Pjtx1Su8SlG2QobYMFTRD8h07zzm37IW//lf1HmqY6K/cUdFDcIG3g/sIA26rxv" ..
	"+qnjOw3pstqswYS5xQu7PIMykWpr0kOoGqbg7VCnlLE1Dgipym3ed6SFonBGoczCFhrAc1bSk3+bMc+pOSn+3TusygTRd35Po/i2" ..
	"pp6EY9UUE4BVIfYGELidu0gMrN1Idi7P+777CSwEtEy08DQNT8p3iwo8EWGrA8UT3xA0SNYnoyRbkXvOVEQrAIyI8ZRfoKIyvYTR" ..
	"7kapVDSO1HNtwURagxtGRGy60eEfixfbl8dHkOfq7fr80OKufaXLx05CMO/vK3gxxhuQOVEZ9erMFFUSs9X5W6f4zFdnlRuEDXyO" ..
	"6wMTTHY+agD8J4VcLiIURVb9RvkFzeNImd7uiJasfEYHiXz3GKW2v3P2o981naAVNeHIzvBIuFrMjY3w2Nd6kJkyh99rnz69ncwN" ..
	"0szAYHMPPfvqMc0lgoXNlGPUljOAS6ScOfRz3ejYSIneBC5HeJU2erhWFpcFYoWiKalPDDEyO1fjvalb2QUU9FCGyjVl2wnvvpqZ" ..
	"e0HsLL40otVt27kmTCC3VJf5XESPi/Y2m078dXdxTVvoPYUM+OawKwRFCh3z6plpnXkNYf3czvrAVonKtVw14dUnJQATiCgNa5Ta" ..
	"7w0mFdI7wBtwI2j+BDq4unwV5CLoecyFr+XJhezTdE0WdG77agsgAgFtrA4mlCoxy9k2b3Sq7umi45t50EG3hEBUp0uRo/Qowg4R" ..
	"AlliGfUjbxNtgj+24nWtYpLgNIm6KRxim64ePgUd9ZGe6X/ps6+30DZ+4vfsd+nrv5lYsd4PK0cjh0SbrxNDjZW50wo9cgC6psHx" ..
	"4/XG2gaidHTA25juauJ79NNiue6OURofRxH2igeL4LlPav7chYJsovIBee5ePV77nfvSKj2AYmEOCEK6wFv5WkgVoqiBONGSTrkh" ..
	"BXUW+2flrwyMgQpkW1+xj+GynlPAXAmnE6ao+HWG3P/JUfgUpTufLnRIcWyQw9R/A3fwEbQCHIFdP/ub3cfWiqMrnEorKzEvBrmD" ..
	"t2HiRzWYheBUtUfbccKB5oHQ4rAIqbw/SlFUuxrqBwiI0r7UgqFMYNX3f09Xlj1Y/DWmczdVlv/P+dI3EwAo7tBE6AnhIxFvv6hj" ..
	"U1O9K10qVi0ESZuTSO624Lw6ZgOPo2EtPwUjiY+QPH0lnfJo1eFrsSkB9UVTkQ5DqKfeKvuWtaU7DMB6r14bJGpN33zarXyfxXTQ" ..
	"Z7cafsPTQ1NwSbn0ooGuTM4cr/C2Pm4n/JWY8ON3ChgJfSVs9HkHt5DA0a1TSLMPoGyhcZcLswyyMaAaHaSj1zpguMnbTYw1sIGU" ..
	"9+kuVkF9DIcHKYIxE3daQUx6o2yF2R6tz5NoUUAjLKSw4gVfPDkRz2q4sxKnNaZX4IsXMLG0dOrgES+uDVjD+3yE3wiT60IViMYy" ..
	"JiZluW7DtjDNnAYmcLg9SSn6MAKliagQ4pljLiuoZKWnbzZXnzKDL1vzx7lqoDwggBENbX/37eTt9xiV2beTXMCTSUtFTPcx6Jil" ..
	"b0J6T1Hupdjt4GvkEpR+xmIda6pKlTD+0TiBfbJP64BsHdtJTVNEx8UaW9hUy2K+ATOuNrsgNjeUaEWworl3SQ3BJ1mRyw5Lyirh" ..
	"0VZfZ8RzaTVfy9Rs2MJ8Pstmt1OcCIqfuTtpMtTmtaYV5eqf7zXFzR+KcaaMTKEG0hPUQ5VQ+vC2iLx3+lgclM5ZciE1V5WaMnv0" ..
	"zpxpGDYd0uUpcNpiCjNzbVY/61Kg8k/6WZzHmntDedftHuRRoBrq03sfM5BNd8VmNfQJidrQWjOoei+LZVQir/wgVlxHu+tPjXRW" ..
	"m2dHRNlAn6RBUF0Dmt/qOUY9/OOetR57cx2RmHzOB8zZ9dtO8VxHoW8RI6371JAePLUDmN1KZ2uUgjdunoM4O90giC3LRyqf6YOO" ..
	"//79H9HdWkL0OIX2/944ubyC35kE2Kw3OENE24SbkEtNT0Kwh0JzexstotMiZukpju5d2Cp/jaznkZLSQ1z2bsRHW7XsUMAxp5i9" ..
	""
local PAYLOAD_P9 =
	"UHIE5HhJgDjC/iCua0c/mj8zRiOPpN3mjCr5lbwPlM7/BO80AB7w6K0oluByZ20YiOVSRdMYx0QUxJlrUBwTgmuwyfm2+UXWsJkp" ..
	"BoYxq1ai1cu4C9/XfA62LXKJIO08Ws+d2DCKknR1NIs71xXW/wXEhOY3wA5JgeJ/7YvqJcboOCcGCe/5nH8TNmqA/L+ezZzGP1hx" ..
	"UPyJYOpEnXCskXJ1zcFG8BwjrtSz6O/oXbtQvlRALv68i9mQBf4HnbKPNy/WO5x0rWXf1uc+I1Eyq1goAL+eBGVNsY/50MP3TA3b" ..
	"EAbP8aW44w/e3Ws3AKxFEWdgy2rMTgv2I//aZ2L6uBFFbm3MgZXMrvF67/N9DTEP5zERYRqHeoSxmDm5Ld905CFH2WMLuRhhqzGi" ..
	"UkWgMifvQpAsHRoE7+I2fEDW2vh9ju1Dz4X8Z1YtOHhbtNMOqXeWzkTa66bl9Qaio7ghpNt9FKKYhTNbsDUTsBD06WHfDMAzfey5" ..
	"FqohC/17exiMG0asxGKp+CVV0hgjJ/90OD21RrSkmgWhKtO+o0Gksg1c9CcBtAPOmkRX0FdRzs0fqoLCXBUULBYVJ5mTs2L4Kmtb" ..
	"nXqzoouiZrPwjdD4FzqMA8e6F8ks0hAdJDa6qF0YKHTwzF/8lzW7DiESIkRqrMR4DWcCFo+N5SG2D7HWD9RjhP1TvP6CnjYhxQ0a" ..
	"vzoQ4K0jy1AEhPQDjDXEmXJJHI95FardwkqGZo5yEmEkHfBRViAEbZ1yUjMxezb4J5uAIuDP1i3YTauOc9rjWPiQCSFAKQKYNv13" ..
	"V3bdYqa7gQVq4oKDmzlPhEM8VxR9Jo8hRyhKgD8jKu2lgL79nZUIVF+6p6zYfdUKviJzQxiAlimPMRk8WrqWFGDRixPHldlUoCHD" ..
	"lPZLFfyrFuxg9yhT/L3VRmE/l2nvfgwbo0pkhq5Mx0LZAKvsPBYTmeg5Dy/BNW7XtMNVIIbe1cgbf88StpNQUp4TSuvUDTRj9L29" ..
	"PfuCenVzAer7dXtXuno80tOcEfEGYJfb60GjKFDosvvQX53JNpWEmwI9RGYUCgeDip4nnbcoG89BkUYMwlVrGmLiBjDPutxHfNkb" ..
	"atbJcM7tq1zPKfo+xpO+SrRZs+znJ4uEXcr8LFKUwWH6o8KHCUwTq437ADi0yy5i9duyGWvscAAQFImpWXnUhpjjjAbrtE1ocsgV" ..
	"n/DDBzLc/CdaC5CIuzjRPaptWxy3GBL+HRKAihXbmEUdaoagOXgKovTxnuORhmUhFguoqwTt98v4gcGWC9QEBFRElwaO2LtKqMcx" ..
	"JAqGqMjALG+amWqYPwyzPf8JkOWMGeEXz6Y/jL4+5+fz/Ykia25KLisrXsJC3L/88YiVpisWMW6ya/NKUUDkyzLd09krtqZjp8Hj" ..
	"15tA1TjFl2x8nggK0hyYo3Ptg3i2vybRdfKRQyNyuHuq3xxzQncu2JIJYGDcup7h6TQ5OjFCEEvNf4l8SgEEEZUJRlVa8ASelYdn" ..
	"MZhOLax/i0Wgw/cm3TGXC6u1/NLWhuEOG3HC1JS93P85K/X0RM0mcxm4HZBGj4Hct3N9YcuECSgi+/tlZRxGQv4ZxgysW42zgKVm" ..
	"hoOmE55F6zwfpFXHZV3oI/zC4xAnDXtIlWxGUWKS3hF+jip0iowtJZTAHhZ4VJ3i6fHaHVh5WRhcS0B0oCZYMaVIyJ85X7VwSls0" ..
	"tSvp31jwtyPkz1QTjaMYoNfFQjpJTYrNk2qVGhFkkJuqzjn0SeYs/4AXKPQ7PqMhhMMxNuMFaaX27wGyorI1onwvHZeA1bQ9VOKf" ..
	"wq7xmF0QpkvZExC6L4W1S4bbr9we2IQQKP+xiTa4T0ujXALEIUOhsVVo2yIUni8RPPohcZsumR8XNkankmr2jTw59kGRNqLAbt74" ..
	"oJy9Tf/AznObyIIfhH2B4GYJLb4w3rEYe9dfEXMtqpD7BYB6YPrFuUa8sx2jIUWaceYYGuVoWzB0cho4uUmQWl1Nl1tjwtksb1me" ..
	"bhOWknj+lKvQdNaS1oxjF5eFWLM0mGqCQ4KtI6cuK+sYsAbNXm5Yi0aeFl2Cqs70jdud5E4wedeuBu7WWPl+9lBNG4G2x2Z/PEJQ" ..
	"XSV/5O+ixGuKW+mG7+p8PcTRbo879q9jBSxq0AlDIz1ugcOASyAQsnmeORImabci5IUaOSOOgvH0yPuCJ1Ol4w3yQ7nvRXYz1TBS" ..
	"iBO4tgYZXMxHvCWizo8LMqjoc1lpuW6JDyVZbdAmids28EFX8CXBtLAmULfy9Twvw7ZuJKVrfp/We0OKxuuuOPpJX75AGn4GRlQ3" ..
	"r/zAY7TDJwql8rUl8svFKuH1XDZi6dd9eHQcNLB3nEfK70TfovJ126GaLDOZBKEN0554CpyU0467Wgdxv6FdahpszZXeMpwEuNxt" ..
	"Y7r17zrvQ1icvgrodJu1eWiUQe5FtT51LB0ZpA/ZAk+qoUR2/VVCovOzozjPxm/aBvfbui6l1SwAiThcfvsw6rYN8CF4ihj4xSno" ..
	"oxYjQKS7+1tHqxTQG47QF4zDmSkZYCWkaVEk+cLFjL8EDVhnRwLIbx3bV0WboOpeuQ/gU+gVqrnDa2soBUSkaLlVHIDI2eVjoZL4" ..
	"2DYaxbBCIc5+eaqKJm8YspflAiBO74E7tYuh04cEfc4KapniPt5osCLEoUFhpW/dxFuZtSRQmOC/BoJMvjYgMwuT7jjGNny+G+eD" ..
	"GZMocZneSL1DbwdbHj4/Y4fnYl5VsV0Zy85r8Ck/kl5bYIHaF5pmLqnCnPDx8gnfBEoaBr/1shfHkcYnFyc0cRLUUOYH2/U1KBDw" ..
	"JimUo+CGQNcphnTFn8MJzAV5Ej0DprIdTRrHVqUCx7WbFlfpSTwBH6nH8hlrLg73OiUsKUp3bhn94RWE1CBfd8ZAh6PVe3EpFpCO" ..
	"xRcgKFBkdv94k8eCCWAFMRZDoVU1x9qIKYeoK2FfihgdjkqZE7NQ5F6LyDqg2tMle1H0NYYGgPDuByBJUXTLvhh23kxcclQvlf1V" ..
	"1gXI0s8ZixQlAJfBCvFzdl5zNRW+1fgxtUc0gBxOj2oFdcr/AmDX4nfZcKv8v/e/SJzG2liOAWB4duxzaz0s0hmo4A0lPsBu/nBe" ..
	"cD72H0W8/pD9P64zKPFd8dIUUY71hYt5fP32smkCxHGTbuz8RDrOQKVCLCoPdUgqMv7sfKhs72Y932egIYvlYTx96FAlhfvpgFix" ..
	"5L5Tld4m+jrexTVBbFgH8B1PF+vo29Vzn/kEN1mr4PJDaH1hm1LEPkifuVfSPkJd4hD1qCNTRK5tcxJD+ognBad/94LYL71wgPJp" ..
	"m6RK4VTHQSwQBNWvGpkKtYlSLnrSoe53eKE9hCWqaqp6Pf2DGyy1HYL5lU+n1o2mSqe3wVWW/H9M3nvSiR1HpJM6bQkyO1P5HqOb" ..
	"eAupcjGoicRzMljb97Sh8uwoqacZDZyaxmTLC4zPUx6UvpObUmyzoFQM7kh5oF888WQAsOks5elXTbXLR4bgTojYoC5mt2kvmiyW" ..
	"EjviAI6pJJPH5jt0m7L3XClzdNttWLUWiD3zBd7nk9Xf5JGD5BY6Byo2akzll/6PsgqdepL5dm785PwJq+lRE6wJ5KsbkLUqf2UB" ..
	"EOzNHC2ykOcLKL/NOy6H9hNhY8ovudIi/jH0ufa5xi6bMZ+Q0GcpgfHDgj7xQXpgoBiwPUmsgxYLs+IJHwyoNtl4537mOts4hhp4" ..
	"QeUYaXxJdxuvJeMXZGcrebTXqIGp5FmxlZiYLtEcl6eezyJ5B6NTLInIw3rDKzQBj8yk0YaTfzJ2uusCVWw+3SMItDbHKCJ9751W" ..
	"HeRkr0VpNNat5qtSqE2tT20V8TjFbtF5gYgW54U1uHiySDsr8EyGGmqjeyauCm00FuEcrliPHsarhLLhzQUw9rnI0bBLQxGlJf68" ..
	"wrK44wfulezMVNL5AE68IUBmiDcxzVWCLkoBjlXhxwm5xOd0o/lnSKMHx4svD32QmFNZeNntP+UwP7nAbaGoMCBfxzM5lOTYLqvw" ..
	"uFQepN/CTKiU3cKo/iGa7SGtjVRvDZEKHuiwxZXOhGMN91RL9CbJaaxKYKfwqDyx0HGgEG/E+61qxWHmiomxb0I+J4n7VoafvOVX" ..
	"v1D3CkYpJBooALr/WUCK9iO/NBQ04eRWCstBKviGlQvXJ8r1KALKAzNy+PFbnjG0mq/WNjDPUYiblIdnLGkNP0CGCzm/0KQXFYhG" ..
	"BiJ3Z7CTAjLLBWndLnjzi9HO4UG4ItuWEk6OpRVWNrDgoZC8SrO6cZmZ8mZ8fAf7gKrg1QV8SvRjUgE9bw+agf9HRapkuuWXndLk" ..
	"QgN8AwrYwhuqWI527OFyH6QaWZs/MKJ9GPFGvtFAxnQICgJetGBmDZbnr+aWGM0owKFdki9XwNiOQuq3c/IuvCI+rRhaqLHiJVua" ..
	"gNavxJ2Q4b6XRSIL1J5mMrSU/yQBDk0EkSYlcHdOpfhfB0Cmf0X1R2y5Ytd72QbdMRc+858w1rUj+oqn9zFqds9ny/y0r8IUeyQD" ..
	"PPeoHYIoNxz2URpxr5EIV9jnQ/TVcgLVfoN+dyPWbDnSFuo51QkwlJhEIqu+PvcEKL3nL6iQHBrg+5iQazPBql0VCmDPTdIKL7iK" ..
	"ysC901Mgls2aaYCL5SzSCbrVFv9Jra8uxJAbKzWNUGcdoCtFTSDjPWsjQntM5plBJwjALSdAjxoMn0C8OFZ0nNnNzCRfhfsNaCXr" ..
	"/oiDuKse2zi0nL69HU4+SbEGF/70M+au5LEXIGtV3I/qRwRs16yVDCxtpwzkzyp1wFLx8s1umkUolIu7H2D7nsgtDSeqHjsZQx3M" ..
	"Afaln5gMMXqrK0t6qUENBfsXtBBXGNBCSIKcUiZbGm6cEVh/WaTwNT1mELAmDKyuXk5ow8Ls7Xwh5Lh0YHovWNSRxthVFhwdO1EZ" ..
	"3HuKTWLzKel+QRFkR9p15fpeApDUeJvGneHm5IgMhbspBHsIcFiWgCv0BCJ04WLdrhsyrNOcv483bwGqeroHwSqAQbf5Ew5pffiV" ..
	"1YtmaR1QcGufHnsIN+VIEkRqE91wMrd0GSOVAsUT93QM7Pzb2OjIFTKKqKqslkeyqB36vmEOxR8h2NdTLt5c+Pu6v4WHGL3HPPwD" ..
	"Gfu7SIAhjf7J57OpizED3Ao3nhph93vQy7qGp9LhaSOFDdp6v6zd2+nOJT76QorjIqYBNz7RDH20SekbJwWFapL7WfPIdHVr5HXw" ..
	"I3m3PhI2xO6ZEAd3ObjKXrBczcQTT0Gyog1XnqQxlOpzieErP2Gy00XqNTfaCMsqH/thX2fNmUkuPSJeLKJKjHN2i9bz1tavjBpK" ..
	"2SS0sPdSMqRk14Yh3C8SG9iArtvwuU/foJCdKBoZ7Ttp0vQ42bsZ/8V+8/zHem5VJsnYkWQB//mLadYu/gVos8tiPLMlzj+QLrf1" ..
	"D5j+/MIG61BCoWXjFjlbRj+G/ox+bJHmRJIUs1u7/hyLC1YMIKl39DhJvVf4+PPBen/lKJciV2OYEsgJl6MU4aHB+ghfvO+jYGCG" ..
	"FI8OBQdNWqhj757jbnCGzM13V85L8O5Y6cX2/QtaUSPVNrQ1Bfg1M8K+CHxIgOGa2ThWqMNDBzOUp9gnbpkG3XMe7Yhny/qS1Mw7" ..
	"4fEWLLluWqXjPJEezT5cPcJWmoV11dIVKzH+vapGX8m755JbJYR57cPEooKi0M2FeQBtKwBvUg16U0yoJiMNFLsOpkSLoAEgrH+E" ..
	"QhECEnYCwtw5ojBO8+MQNmCr9XWXOExX2m9AM8mYMzQ+i2DX+S6rGvv5LAlsSkQRwR1KzEDptUNk+eBaYIjVH/EAU0fxcOOXqRsH" ..
	"F6PJez5JmVxn6DeptR6JPbi0dclKIncvK0XBNlp/C7YsRdWBvCFZ7Vi+DmTs64VOVsf2lwO9/XLwrNfxaoIxtF+ycvYYb5tauUQ8" ..
	"ks7GO+v/feCEGZI2hPNyR+44Ke0IwIFKdWgZ0cHsK6jSDtZA9cKaOdVnfNUGQo+/8YB5nj2gH8ckE60UFy9egFMzx008vIePxLYn" ..
	""
local PAYLOAD_P10 =
	"vXYBIkW1R6Eo2GnGsLaSqarAEk0v4w+/06gZcZxSwdic82Xu6J7GPEkVLfgRfaa8z727JY3ql8ngf+6rhnUlghL+y11WGiKLtf7F" ..
	"GPjOUePyzyApHhugnTCIrKSwx+FKDHc+NGB3PP1mci+ioagbZGxt//O5ZsBFggwE6PbDgJGBTXtYbMYuNlQMiae/2nF8hincqbNZ" ..
	"usAzg3Hem0PnOfBKrZa1Fy1bdgimwaDWT9RABwZRlqONfr8L2mVZYEW6p6DgyZv3hwdOlj3+JPgAKU7RgURFuiiEWoxdt2s+/Fkp" ..
	"cJNXBm0YBDFwolUjJQdnmzZp4kO0Fynib9gYJdPkFWxlRqrOqC4g4NNhsqFalxh6PHZrnrsQPAktHhR1NLWvfK88SXvhk5O3gS8P" ..
	"4Cp/RkpleF/hHAC4yAEIfP8yFbGh8NEDFG/Ma8/QFA+K/85s4gQAC6O+gDrgKzhkN3lPvuotOCjdL3/36VXXyRo5H5C9RrvLVxzh" ..
	"0knMUluJxNM7TaEX2MagusIVHbi3cLbVVGehtR6YftBJ03ddzKyKeyKRC24Tb1AhDQX/234Iwv+utE9bvsPMdD0mx7LRBVILiss/" ..
	"JJiOwT1VEW0fiqOglttDQaViHkUrfKVKag/WfazAEDLBPXlYtYVl4XxhZegRNpPIZQQffUE+N0w6ode3lGGxYax/m1gN0wfJ3dVG" ..
	"YEztQi0FTXUsOejLUTPxyZQcFdjv7vpVsEQVUoyVUxjvtvMl8W4b6xN3T6QyDs8MpOSQdg/1osYebINBKmuGEINB/8e4nIiU2GlM" ..
	"urIlrSK68I4tieNumLgrpmcKTerPx414Cc+ouaeIm3OlXBR1EHoFdCuBvN+K0zytwzVQlwPY/RUfkv33eJAGxOFliTl+2TzHw62N" ..
	"N/L9QPsM2Gc6xQON1uBA9nkSY/RGsq8DrJB8Z9XEE8CN7NvF0KYVM3XGSn1JFtm1S1dSgMREMXj5XYWDoE+YzhA82WvSBINaTbJy" ..
	"lgwjxbRZsVjeo//s2sE1v7M/8P+7SPUXzBAHLMeVF16nuRj4+PekmkEIUuT2EgSIO5fD/j8vU059uK05gn74KnvCzmAlgOF6FPoI" ..
	"OcOYmg+cuFGp2MagbS6GhRaTgyvs+A63WLD2MJekZitcGt6at7uXZGK/GrN/GMAS2j+2WAS4yjSBc+QsWozPKY0IojiJXgfnXx4/" ..
	"4HcgV/XDYJXzMHwnyRGBCLUsm8aIQN6iAuo8AwYjOcDvWG+gEZ4MGJMPP0NAEV4fNpZEGFsXNUg4+MYFDlzXOyZ/ABWLsVdOTXI1" ..
	"Cn2bT2tMDj6VfFc87GhWKRsgfQPp1Zlf6Gr/5qnamhZk4s6CpWEGdg9Um7b7DSkxKGbNN4lRgBJRSg2NceYQXFW0SKg+g407nsfJ" ..
	"oKTKedkQyXd+iXYlf9uS/+N60iu+pmoWFwB4ZKNZS2EwKh9GYDcmG1B3Zj0Fd+1t1hvl2qLR/1oP4roQqqST4r9stlWgMGtvP5LF" ..
	"aKzK5gSB/aKuq4QlvePsLOeOHCpVHzTzHOV41IJjJ98RM+KJEjj7cbU2FADQ2jE8pUmi/k8v+U+WWVRMZ+bpHJcV+rSyt+YsiibU" ..
	"y6d6OaOvK7gQBG9OMQe7X8lnOyYxVHpGxzTFm8rEsUtMiZbYFkuhWPJuDEvo/3ESzF64sBGISjxfWuzGczUoyGa0j3pCL9SxpL9v" ..
	"X6FWisJZbo0iWWQ8d/xVN225+QN1hnN1fDl/Ypo4A4fDKCoSUwz9PGsLPypMRMgfnkCBIONUflCAPEolvylhjqPwWpAq2Jn+b+5X" ..
	"Gjw451fNl3SQZWrNMeH7ARCZ+xxhepB6gAVhrFMKYQUVWCXTRp/7TJ20JlA9v0dF+gwpq+z2AEhyOzhEqZDkQsNC5hHS640E/WSZ" ..
	"uStuzQqe7zyBZUVU/RfFcX95Dbkqh63AHNxSlBisIdX4xPSaoRVKX4qFsF/bnFyNgnqgVMuhHu3C8ciCz241NCfpFhoR0vlgQjsD" ..
	"dhNJKgkIDgyuKKFlzoOP0F4i8Y1zzoe4k4ZJTGA71OeEGqBm3kFlvip89Q9zxRhXD7OP5pjibAiQ9RWKusgqkzmszT4OIJNeP/Se" ..
	"Qxk2k9W3OGUCmrKx1pzBpOcMfnlUjLixBRZzaxaRPeP4u/+RVSyYh/CNW4ndJ4gDfPQdqI+7O/GKMBvxDAYHYMW2UEoQDIZ3ppBq" ..
	"SITevSQt/SBVRXSNqreuMWIQE5OHybebbdDYLMmVKLuaUCLnzAJzaAfMLhzl2JE6N3+3XaIDwaecuYjdpNs8waSt+AHfmePWYxlg" ..
	"vW5rxBW1IewBoVvTD7gEPNNUFz4l72blO15XZbry3of93m5ugLEhs62jyXJyTXB8Lf3EeJK7SImvaNlqW/PSV0QRzKEvw4wlxYkF" ..
	"xowfqhhqjO1GzScdWXGHlL7wSR57fGbzVSVgWmv3n5pQa7okoxCNLmPeZhPihKKE7EsGnFEukeqV/4mS4V/ElNYR86DE7mZbpAhq" ..
	"QkOMqduvC1XmjZwEde8Q5HrDFiBpa5ceN5848FheFVLt6AcD65WmcLydjfjkyU419oQdUSdnh1GcEAcQXdGt4ScR9eGlE9YOYXp6" ..
	"52beWCDSJQ2bWk4YipFI+NF61rcJHAj46MTUtvI1RE1OE/cCJnOrkD6PHbBWtZjlkjK8UcRzLDFSEnhg1x3S4Eqddatas9F2d94+" ..
	"ozf7DBQuV7FZsSGUZz+3Z/4oFIKCQF3O2VSPJDqTGGmER1QWpPIVZCv3KabLdIRqgfsXzM1KBZoMu3CU5BW1YjXDdvlG4Y9zSIRw" ..
	"VCGSc/Z4jshm58yYIu0WbK//4MS/8UpXfckpVX7BHHH00qeC01UEn4mv3BbnoQHbc68AnbK/9kVRlP6ap8CXj6VIksvInt8hEPwZ" ..
	"6y/ynAZ12m2CF8rdU5Zg37TqM4ZK4NBuQQvgmfY6QchPEw4mlnKHxFotLMYgT0zZHcQH3ICNGiG+yJesQj/KcX6ZqkjBGQ07a9aH" ..
	"Lvv/36mHb1jVLDW33OB6UQBYGtEfCXPWxY+qdHrumL26Ir8KCv2eHfCJKsxRHPbMmctBFeQt7SLeJaw/5/cPsOIj5udUyNj/6mvI" ..
	"CyCOdhklYgE5qY30a79F2DiKsEbENOz3sP/p1JfGeaOApTG3zMrb1wCJoKyNqXuSpZZ9/xf4p8SSiGejLmQVeYtmzi3Um1Qh5ZEP" ..
	"HllSvHZ6UJ4dBd3B/2BhTxO0GVk+8unb2oUxMpHwCq9eH7D3eYifDgVMdxpMflPrJLcs666lChYo8z3ojdW5jRMwkkb0TyIlqP7s" ..
	"hcwW/GuxfUlY7YuTJsEN3vZf3HqPKurPL5gRXwFW1y2goLZmESowZN7hMo9pD42pW7Ccfma+Xvdn6TkaiZRAOKUJDtBGezVDaVKU" ..
	"p811Kb9cXEz8uiV59BFOQ5g17UyHAeZI1YGnluccRNqHAEjGFT+dLiMDPhgGHRfA0ZnK13+N+vk8NwUvZJoXs8bUEpLgLohM2USZ" ..
	"AUMGAVbBZJFMG2/kXOLQ9iJDg5Jyoc39SDRrQPr9hQyxOq8XN0WakcFHGtKkg0MI+REoSqXJtNwyTIyUsYyUXyXVOeNAuPwdsTLg" ..
	"Y69zIoc+qq+T6Ke0j/uioJ7czXVV9hft2U0zWq2OL/qf0VWeqB4YPT7yEAebh2gb+kd1/IFXPunetc18wGnp7TA3aD5mKEktD3ic" ..
	"OUXyOHVAo5bPEDWNdxQeG0tJJ4yC0B/03NIuOGY0C3dKecw8sEIdIuIfvpj5VdcZg/09884yaIoTwVjSIv6QA1AQXnqQR+rV13OC" ..
	"ZX6jFKpQNxlTm7xvj5zo3aDt/MfqF4Z9C6Wyn0+ECBLUh2ZyqV5UOM59bRPADOHrjWuA/xOYhDpoBGCPkSE/ombws23m+k2u5Vuk" ..
	"GnbxrrrUYGpWeiAfsSfVNSNErasufbMOoItzmEn4YN3y1/mQPV5Rf9I9Ry+k4eA+HRV2qCLN0FEYlifHn1Ko8U0p2m3xFRZiQb9a" ..
	"H5deczEMqzriW9aLUsdhbB/ddaG6bLSWXOCc10LPDcd27vspaMod6QJYNND+8nLoOz84F2IE1/jn7tSy1BRt4sIkX2vEsupTLX6N" ..
	"AN8ccVKKmnKO+AQldEdijauPLpEaswYus7EGglUWCHUFk5YhanFzoh088EHwR3jtL2MKmkcCWVDZlyLsg2MD83apCwhor5J3dPnx" ..
	"vCWj8NDpWQRpZo+BoQWILmZ4YLWsLGxZjNFA7kfVx6v+SQZqeMPHg9sU0K6D2qMgsiHIPy3/QGNTxlXCho9AsXzWG3+hc+fG88/J" ..
	"15xlnP1rK7dOykgS/bcAnIEl1sO8IilTbpoMfHFs53dk6IPgg7hlWZw6BqkKk35TYhTl1I0GcLRMvQL0F+2XGc4NNzpjGHLC+q++" ..
	"F8jxBoQVYHsgrlpXzEJVFH28/7exY3KqA7sdYMonDqzHGsws8AJbGRIDWgJQ+i+NSG3orl6dtgXXWsbIX0LBdefehNCjbN8C+19J" ..
	"w/70ZtJzAIGP4EFyRzkCyuIuA8jTB8FPOxxh33yzp7967Z1kPVhy3hvWM38Q+5lJIwQADv70edy8kQ2Z86D3lp7vB0fBa7ZuGqSC" ..
	"tWFwDJxZiyBzOSZ1phIZNx3iHwBCADa07pbSOlOXUNCRS/4fff3OHWopSkl+qjpwCdVyOnr2rWrewUQj0aq93jDPCTfhW7yFYAsU" ..
	"nci/YtgL+APUV4wZqBIzkH2kf7IuKQmrBQ+NSbkvRFTaZompAGSa6ZhsWpRS3kdzhxxs9uomo9Yi/F55laEWfI1yj2e/FWZGJ0kZ" ..
	"yVQRQG6zbif1kZsTAqXNIgRl0/WofmshwOaTIjZUjep3S49/Ctwaczz6as5JsgfB8AGSffU3Uobxv4MSTFOPZEZwzdPruxbFj5V5" ..
	"1OHbTT+8UmtPQjs3J4es9errNkU7vyZxdyinn17kksmGSwYKOJdsopreqF7s5hCnFtgZvweYU8tTHpAOqi3bXlHv/Zb8Nu+PhWgH" ..
	"fZk++Zjj4vwYRY06VLTYVRUaGzTEACKFL+3RNOJZ3FegKWWWwVGoisB2djfSbC0PC2vLETdMEdJAI5xk9WyoDtsyDjuQFBT/D94Q" ..
	"ZNu8qpMPLXeJkzU/E+ZcrldpkZJ7bTEZOGmSqDj/QVqks2f/fDa1jDkpk1FGNf+5/ciYWRa9He+EYo7Y8pQxcyVei+XcfAs/Rbij" ..
	"1uyYGBK3svfZ4GjZPNkoc4XPj4tP5Q3p67Hqbh9jSGUEXVR17fKaDyTO0rQvnxf+vxFAYeGkpf8myyRnrLVx+U2RyPYEmnsW7i7D" ..
	"pwtT1PtqZp2g/WfbhwkFT7I7aw/p6OIX7C/xWneS9J9nBMZ44kZlVcnR6hBEhqKtS3vmOeB1BpQrFik72db7iujfluC5gJhDyr5f" ..
	"kHzjVy6nLtueVyCMKxKpQdA+LTrIz8U3cV/Tzoh7m74mvuiyTy0F5yQllFUbpN+BkgYoENFNnoWQRaGb72+/9MXK4OjVP11oKIjH" ..
	"ID2xgEtz0SIv8EtNTzvyLtYCkFaGptS+RAT6laTc14YhqGbyLIhoQI94WmtFESesvLaJn5NLuVkCfjI3/i2gVlUGvbq1amRWFADT" ..
	"vu11uSURcpKiXsPW1Qm8NWG/xoHYbKwPRCkSYiUfrIExq0hmDZJVcD4tba69Aqnj0qTH302MMyYM5vtVn5UhI878IRleLpAQs9v4" ..
	"wzpfuqVXpDHE+iYLpb+dXqRoWw9Qj689qtj/zOMErM6Gt1cHE77iwPtMsAtkKsWl9fi7u43O+/l+e5dru3PfweV2dR16nwAnxmso" ..
	"/TZjdhTJSYx8E7Ae33TVdbwP3s3djs3X6E4BJgXkxGUoQC6AitHo8UvqUbG+t+wMIMv28PvoFbIhmk/il0xrxzWKBUGbkOMZfdOE" ..
	"fCxOJvD8BxvDUhIb1iPNRf7O6ztGV/6wfLIDkxHwdp3VlO/I9YBiaT5Yx+qZZg0V7hLj4R5BCYooQhg9xkiSmpOw3AHcEH8SCEhU" ..
	""
local PAYLOAD_P11 =
	"wjOgI6gFk1Sn+wRi4n9eThFPiEjF5RkzvixQ4qWjgYFRtWhcTW9dLnfCLM0y/bFIYeAk5jP9jFcpLefchjQF6px27xoT4WULq9Ik" ..
	"l3sgPlA00jYy6oOHxnlIOU3cG4uvWSeEs0ebyXB1s3LGMwr3yLgI9AN52CBNpPKqbOS1CtkQUgXnRXEGA/WRPzmZUJ/fP/GLr4oz" ..
	"dVjmo6UyFrD7iPFjLIp7HC7QaYZ+Td9ACCp0mq3+IFbeNdgPn2LKzR04khjXrh5J5o2VemjDguLPjtQ8OSGVOLk4VPmKgsVdla6h" ..
	"tkFY5kbPMvyRRwP4Q0yVmoWpOK0EPoz3d0TLSU6uc6XvgLRLxZ6DA/pkXkqaQIZP89CAtl/zzOHJt8nr3+cCMIVBTdQlcxliL4ud" ..
	"cJzwJLsOsLqGLimz3N8n8CbhBDvAcl6fkoFCYwAAXSUZZm1hW03cYadId5TGEjBma+za1OUZeAQPzY7FzbF4cK01NJ96QJHivcze" ..
	"qSvyAT25cxEktekFC8InebsKTOn9414JkBssM2We5S0hyDpge3zpYj+ftx3nETWyYC2+Gb7indEDKRXpCBuyg7WSw7ZsMYaH+gfn" ..
	"I5Ll3aODUHjw7MEea+9d3pjyE66iECaW7C7r0iK3HdX8cKI6T0LMNxuN2kiJakWmioUy9j8yi7rqP7MDgUfNCCfJUmb23x2cpo4s" ..
	"VGSptJoo1rKZsomZOGVIQzc3WQJAMAZWKCCBq3NZ/J4vOvddAkKo0IhALEsrBy1Lrw/IM7uvw1PAMjVNBp1+oFUlJ9do1mX76sZg" ..
	"xD1VNDj5ntetguH69F1VQH9NMMVyIoCGb7suiX1dJZF/dbs7yyWvO5a6sdWzmOJdgaqlQBkoiLgE4nw49sgij+VRnj6fnQ/fQrwh" ..
	"8Kcp3QSruIAnn7pf/0yCmon/hCK/1Yatz7f7rr4JgQfm/hBqqgQ/mQDKvNtpHFGFadDz6yyV796uEJh3tizpsdIgMc52A/k8+ApV" ..
	"pQVJn3Ut65IXKp3WlwdJHuRsE8C1eLB5ZQFbFs1rOpItGepivjbJT2X9hxQO12wzvWlxz38qc5c9OSLXfKD6fb+rOX/CC4jidk26" ..
	"sDS/3izpcw7Ps9eZ4JN5sbZZhQkq4H7gwsP2e5Hop8rk+19jB20O3/mM81kKMweiqlNhvlhBSFGeHXxmfCyp93bEo0NMjo8VYoT2" ..
	"gVj+8eJ2AFTjpIRJo1YV8WKbCS5+h1UQOp3+C0Bv14mqxk7LaGeriDsNTxXoagxamlWzExuhO9HMZ0uF6KSfhCG/tTl2NERjJKqd" ..
	"ptE/2/lNWtHdgdmnzbLZ4csQPYTnjWRDSAvQW64iU6dcKY4TNgvWtA8ppLZaKYZwQ7hLtbIkOQX6mUUktYbWiDwzagsDkUG9NILB" ..
	"T1zauH3KJoCGx90TwMIHxo2HAyAHkMe3BSvKxU4dZX6JJVf5awhGmKTrthvFMmW/av6Jd2KxvIr4eRE95nWd6Ym1OcOq3TypKaCm" ..
	"QI9LLCaBumOjOQojNbqCsBWz2MtBUqk51RAV7gYLWzIeGth4tVIxXUBKS2B94Baj0XZJb0Jl6LWdhosVub4Bphwlwmt6DUIpYLQG" ..
	"Xxaz9WC2n6X+QTv0aYsFSKZVyY6RDeGvkHdnJw60yiHN0AX3u7QxyG1tJdujOFD2ietf64N0gXIIr7KyhY8au6X1d/we2iqHooaf" ..
	"kouV7fjIPU/6Twf/IvDYffM3kViF/rS9j33x4d8uoSGpeybUgDRdb6qzsw5RHW14+vhnh+9JTLY5YLK4f8vz0LMxcIIvBD3tbhrT" ..
	"/zGiG1MvSCAt6rtV4KrBr++JyvG08g0t4V1xrkFz/SSp/gq2PGN1hcYsInWdbqzueceCFwk2H6HETBeUoyV6YKVL2x/zpYAWRm2C" ..
	"nm1WioXYo+7TjHujeEQnRx6BthalFZGhTrBjvMzYIRx8HB7n0B3omXsoJinz45ugW69c+Nq9ETkYkLVOkZmGmMbKAtrDwOVgYaBR" ..
	"oDjyeknAVjOC1GwHZR0NddTMn5Rk1VlS360g/Q3p9hcoNEfkl2N97Zt/7wHrjlI+hKNGsy0kcHw4VkV5eogPy3ZIR7Nxy5qDmcX6" ..
	"rMr62WVArhuB+kGcabBAhtdx/6gJZZcwmakEFz7NVFVaXga1V8pyoFaCsPxAuE8Nwiuhd7xCG+IrllQtgJZnx8OqEe/are+ZQvo5" ..
	"k4CYQZL06Bb96fnySZtakd79ZWDDHBm8fXDlF46jDG83ht5TFsibdlQndWuvFiQyOSayt32/KMqfM3Jc8Hv5+S1VJLCTTsvrMq7V" ..
	"gKxtEIJXv1TnWRLWbCGRqbCxe6bFkbxK3vHpQn4OF7NApCGsE3yeN3jm1FsQUZSke+QJUvLSOK27QZ6meroXNNPxcPwo6lgOV5Ey" ..
	"sQD3593GKEZ+eiDhIvCtNOYiHfZZanruHxBFHXNCi7eJJ4BuDrarDhgVTGWCTM3vpjKQBpYPQtW+XU5O5WjHDnMfNJ2mjG3bhksA" ..
	"lfs5qZOrd36C4IQnwMSMI+kWHpsLtD7Yang+Ax3Lwi3iu4yDbWHiiVRsq8AXcJjoweuwnrEFrRc7sob51KTdcEWuiKnOjmeQX6Zt" ..
	"BjOurveyWdhMSR0mpKiRYXLuQ/6bbrnHtziMK3EO7Q9ibE//GTCsgtcK5D/iSFiim6sSOwhWMa8HEvcYVk072JRIEHASYLOgELe9" ..
	"fV8wgA1vQJ1oXXhlyBYGK8sZiyiRj/Csl8QT9kp8rwOaPPhQe82c6QGWyQdngSWoQo6imA+xjgqEyDGJbxLKiWHctWMO1AT+fxGD" ..
	"RBNoqA3UewdF1/TieJxEhaG5DZjt4bvebVA7vx3kq500iVeMGG+tsL4H7nptxixFAOzC/1MimsJx+vZlosAnE1tgve+lyE8nXIr5" ..
	"hLSzyH16+nZfRFmIhc6whHt9V3oh30fovNYo4JQtU7KozVzyk5QrJ6L7ieNrDJ/OSw3xVUCkJIy6EM/nH/+XxRr8LAw6HBlPJ5sV" ..
	"6Hgmgieu+hyU6VTdTqmvPJVj/kUG969NyGG5eMcwJy0QI7BL50NrzZ7SiqLWfKB5HdlN9K4zc8g+0CXfOCvPpKxS7Lm1eYe4dGZM" ..
	"mZN7p4oQOzA++V5EgJWSYOxfDYST/dkE/x52VRcI/NUuAfn9LtwZ5HPMru0HWO68oxQmZ0cm0H8gWdjgspI8SbfmaKIvmKFlAjvW" ..
	"n9PuHaqKpD5Yqmunl195ysduR4DkhEI8VQYx8c6GptSuIBlijEpZfJE857S8ecksEaasGqIaAC1NN6f41jO3dJm/Shnjei27DLY0" ..
	"2M3fgBf0SWghb+buG6fDrDv8DRrDWvQIzTsy0LbzSLvM3ICPRW9VqROfScraKdvo99JmLANSHNQsOdThoxHTDt8y69OMaJLcec95" ..
	"aO/Yfl/8Gx2CZbx7tSd6CwNuDv+ww1D1g8xrTwzJ8XzY7nLiXhIlqS1fJbQOVXmYN+LUcxdqTlbogl0583SPL05+FSu7//Rtou5s" ..
	"jB8N+3ALDppLdLEemJgqJrRFI4w4xzww29bzhfciLaS+8Y8fc0UJgmNxMabrIJKfvi+HH6XPdOrItD1ZHGuf8miSJn7/apWy79nW" ..
	"2Uu873RmfRdlvhimeckk1G4Dm3nif5YLU8NferXGWxuOGWjDdUTTOwSG0VzoZahzkbNGgPYFRjknHvj4zPBsq7EYepgiQ9MYJsfU" ..
	"gFzrm8K5WDWJWbOUcMTiYMnxrC/honK2yOsNd2RPLpcq7XfVN5uUuZCTyuY1iUN9LwL2L+icqpRxjbYLCFbvc9qwCNnhkigl+ODq" ..
	"BGDh3C+lND+GFI9rKoP06pr2yNYYgfZsfewmyAe7oIxZl5+Rk+cSCKu5ZYbeWXYAD2d+wBK9kCbgaeqD/iRUBc9CbzS5L8pVuZkW" ..
	"A9+KHERnPqnQeDHw0Ny5RMdoxt0yl802VWL1VP0T5GtPx61C8uP76K8ia317pXCWhrwu40U4V6KzZhr7sT5WQ3n6boLkF5Qtjrzd" ..
	"Y0OPWJo1zG45X+jrpEiinI3jIwfTpfrub7xn4Is1H4xzXUYOLBAJbYBhID4Xdco1C52G9F7PRxUQGjZX2YL5erjkb96zaoY0gwtz" ..
	"vWSYc9kDoEMYdxl5xe+TRGHBbeCpZB8OPOgloVHR0McxGhqXK1ra/tXkYF32x8e/KX0o44j1V8Qk28ctw2Q9G5L9qSGkRX5hJ9fO" ..
	"qt9epWF2yOlkFzLiGP9XUWoKpnykwlknC8cXP1JJGSnX1/huccBZbbSXw1BsKR9lIqlcmOw8btTNPoCBevZT3KYbUPZEAufwUVF/" ..
	"RYhqGVsjgnueCjd0/Cr6b22T5n3wei2JJo3zLfrNmOzTv0Da25E1tyVFxqdEn6hckn/uc2LfuGNU5FEE/D9wNQO3E3jcnXDhAhBc" ..
	"kLgP34tSYcccE/tLiEeDFeqy9PbWCNngDMfnJdBbhHpAfm3Kg93qftuaBEtOa5mJn9v/md8AL7C/4CGZcfOSZVfhDLRQ0M48gFbo" ..
	"io5UaWxh0tQCMi8lZ/uYBXkDhzpjpviMlAVTOQ5ipQjjyIXaUzlT2uQUAS6SAmTH3nEBVRP1jl7RbaVLmFrMce5kpIqF/4bbC9cb" ..
	"fJGQCEnBx6QXq/F0hqMUAKUsel8r3dcDrCJFsjax1ZOfbw6Y18Kgg8/Z9UG8c0St8yA40NlTRFKczVzzYHzRVSMfaPPC/f/t1Pm7" ..
	"g9W5Ib8AP5+k4PaszaaMqLPFDSFP2Uq/oGrWc/CMXmJMXegUa68UjMzU/Lsbtt78kNvyt7yohIU9q6tqXeX3oWLSSc0cgGj4FIGi" ..
	"M4YWnB94KqvU8UYUCDZry67qzZdLn1Y/w5zKJWbB0Ask/Y1Fw12nUrD5OIsEH/A+ZI6rtTppfN5ajfoLBkib2B2LMxHnDjZ3Cqkv" ..
	"K+5FL5imkZpYAauJmnXxbEbh1coP9ifkq0GttpN39P8ido4Nu+CcfSyJhA6UXcWk2zMZBofBYU4e9fQyyqvuj3XoWUBHqLqmow6Y" ..
	"jsQ1cpBZXCy2/UWi1dqPiDfAs9eLSIhCsAi1fw/uzxgDU0u1A+XQNF/4EgvzdR3oHZT2tbQnl+nv/JqjnJwSu/jJyNwrdZl4dqLB" ..
	"dDouot0rN4xa/9iTZe2NQVWBKEpgIOkZwEj4e6AZj1u2zfvfj8JbFojPDhhJqgeh37NqWDyWAF2vtJY0xSNPzPNKmKKMFaSC4Zj/" ..
	"d2zvoK5vUlW4+RCkgQxmMDhBP5Ea1TITm1CuWc04B+mUEpm6ShZib7U2fore/u3Ms7HvT1uqLgRP7vraH0BDlyt6Bbt/dXgTPhYl" ..
	"xjfY36V1P/auS9tP0SjFASkmogGB6SUIcGrVWOgSOxys6XPyeItPDxXyEAIYygU8qw7CwYGF5/q7selXZeAeeHvCclIIemWbhBbS" ..
	"W9MGBFURCi/pgH0Km9iY4Ji6WdydJ+k+UfZ1xldgfiJ3Yj2oeJf92merSak7TJp081LR22zAxmsRcXlYGBtfl25Uq8sE9mVXP2XD" ..
	"KIsXVuEOe7H/3K9Y/WdI46BAG1u65UjwTsSvnYWwwQJYo4ab1QVR3PJcxgr9zb4q6pX4qsIb3bsFACoYnLedAawVLs3Ukvy8qdsg" ..
	"bvg349ofme/ff6qnJPcypf3PdR1SvyK2Z047y4vZh2R5al4U9Gv3LVNSHIcSSbiZ2RjMqwrn0mWtV6Gl+d55NRJhtkodOWfsH/s+" ..
	"cveZMJmNJ3hFuApc3ZgRiiveKNb94A5+gO9+IF/Zy8MMisdYZK5YC7L/UGlFWN7iHnGFRjJaQARWnAsMYw67xUqFHgUz61TczVrJ" ..
	"2lLqqvfQPmHtmEw1TSpZnkLkYyhqUevZ6fodk4NFlQdUDdwah4zQ0cmx0Rx0k+ycaTYNfyYVKgyZ9dng7Zz4NDH5bTii0w+Qrnmp" ..
	"0dzCLB+yxVq4tCOuaia4/u7+wxKNh+W1dSqehUErFGrAxeuMEPzf/vY8f6V78+A+B1o4TBxJ80v0OP9V2CseQ7K2HujOAt0rreBY" ..
	""
local PAYLOAD_P12 =
	"Mouxy84exSKS7O3g2mVMm56BLnE53wW0EC5/QycmIOmgwKxCAyzZDsqklyLXEeGAaAHaOHLSOJb7JHxeS+3GcO7ZKHT40SQqC/44" ..
	"0Mzt9k86WHmQjBMpou5lXTZde76twNFR19eHVi9lMgiXq2TbDHhnX3Hpq32G9BSFFNhS0kYIxlABWbpUKGvd+O7+los3z5/c+yZ2" ..
	"9hszwWrFBjybt/V1yfs6MazAuCCYEUJ0oQTtHRY4goqpVSG8FTVdVbaLni9kYC8kZusTqvG9DyRDlvpuVVLSzGwj46RPVjbDZILl" ..
	"cx4kJBHwhm9bTgUmDwfmuM08hBTQfqPQ01Rel5y3QFr48UG4RVM79k2vlQ20r0AnF6bCiYbU3xmBGKd9AJU3kbYw59bWkbFuD+Xx" ..
	"d6dHWpgFs4PMamQ6i7dIXJzp32uBqiYxriRkUcLqN4+/a/dsnCf5ZgtV9HwbzSMefiH8LyEUexYAEB7WQO2Ww4REo44iCgEWCAjD" ..
	"FU9huuNJWTTfv2JvzFsVNR0pONwTmDoluJAPjyMI3Y3jKMPp8KT/bpYyCxEWG3PxutvzzY2kSwv4IlEinzmFA1hFyxv+K7ULrazW" ..
	"V8RIzH9yTyt/kZPa4zDaNuI5ytqTr2kFeHz/vz3OnDY5t/JVKZvtNldrBpUaqNqq3SvWmQM2NUPuU8F8xNMLIJ/zAhU9AEG5I1GM" ..
	"zvf434x8HLRLry4un+B970RkBckGrgjr/rwKbmqhNc24tFVA4k5fiZve4Fwx5cb1b0bOOQJvekRjzgCPTgm8toDKkAuXMupTNsCd" ..
	"CwTe8gNepF+TiAJLCG4GKJSn8t8LnB0nyUSbxK+L1EceXktVaMLsVT8A4YNSC3hKzEG1Qhv4W5WnHWK9xPOc1pkTLm3nZ6a8HJ9J" ..
	"MvvrukpKtNR4M6KdJZWTohx0NsqYuhLpp+zDfqTk1nlH1laaijwhmmyV8uWVs7MomgCcHnrqT26ktPAsXf3BYXZ551qTxsjOeCg5" ..
	"23eh3C88njgRM4RzDTZpNtsEwt5mUClJZrGj4l8J6sBwEKRlLP9WZI0C5jrMgkYuWVGOmn50HGVU4094HCOFLjKbr1Sp8nhGUVFD" ..
	"XRHadw9epUxgUwd084TgnYFGjyHZg+HP543kldxvwM4dE2mt8vZH78AN5yGGbgIxawCIDC5waoDqJg8btrD4bc+9BqPRlIitPS3Q" ..
	"AXofdJDGSbdfpmmqcHRxj/++N1tv8FGqM1Fn2lJWhVo1fd9WibMSbdLKguPaunSHuYu+EkfaHdUWazwAdDpJJ6jquBZtiS3NpVBo" ..
	"i+AAHMlrwPaIeoM4fmvy4aXakW/eWy4FVhvLEgKfMxue7CWl4KYg86d8u4GGdF01nDHQo6XzLMPJzXGJTxMnEsRC6IR9/9U3cQQ7" ..
	"Gegs2J6NUuGnnGm6zLlW1eXujNJf3lwx+oRvCGjJ7aNU3ATbhqC9Zy8Ev1rq7iVcGneHd2wESO/8ha7Sl7jwZAeXsYj9r+U+Mmf8" ..
	"7IBAeJuCuhzVWgP55oOd0/g9D4p8WXrTAohvPV8JGf2RQ+Z5ywur83NcOhGG/ZdmmTkaYPzBtmAz8gaPLS6ipJiTxwnHGQzXEyzG" ..
	"gJkFVCp1X4/Y5hFCZFz23PKdkiYcLks3soyo+Mat3Gxdi+cclx3DpQnD3wdetIOPCtP/4ArN7RhRQoBnyBsdsmdT+8OqSkUC6sUI" ..
	"S050tJ3sX6XLvv45ZZNZQ8WXp7ym4HR0cO9Fo/X6HW4rlWN38B8O03XP9Ib9q2FXUkWKOyg3TfPwMWySZzSJKgJNOtJFkwMwfywy" ..
	"UGCSAbKW5aO0VNeObNid/yfmrKwUghnbBPUchg4Jyv+JLrZMPnQwnQSjPEUr4JX8ZNZ4LsjMouReFPmW69C899S2TxAdvCz7Dhu5" ..
	"dWxdSETbX7Qor5hQzWTvaxQJpk36PO9UQpYZXUXZtcVZmxSrLc761hAjgtgPAWEU5TEAtjyeLrxi43rSLKZyeLcb2bnzvMSKF/oL" ..
	"cRor/y0J4bHB3/guXqItDwNrP/c8k4njzM+/buw3QbhEnf4acnBUE0zgP0QV+5tLtEZmlP16cFkD8lOj1mfETRkmUVbzPuSDJA4e" ..
	"ckewzzsGAwEXs8q7x0RUFzXqAyb1SjBoP/pGefdGRgTnRBPuOtfhTZNIoTdhBxNxm+8kjcpFVbUogvl89QXYdJINSllNQ45CVURG" ..
	"+ZBbehLkwxha/y9l/RCsbHMC0U/4UTfnKXMfqysqDWQWwgSLGX6Uu9Q4yc0MRLYcC/00Na5PGaCgoChDLZ9MQjkLv4NQQvjyUJhD" ..
	"6u3SPAD7hhB7mXPGGZ0izB+Iz/NbEi8O/Nq/lcmdOcKRIwlOu2sGBgJOzztBbwjc84nsPzD6YZUn1r7G48WnO423Knxc1SBijye7" ..
	"kCyPt3r85ZfDV8aF/88bN2J+GQReCr42cyifwtyl+mkT/xnbgGknX0nNoKFoQHPR7/wI6w9XFUD3P93kOSBk+XTFFEc7Mywp68cB" ..
	"FVp3R/2285idwvj0YdRdWbmXYpryoFmvr5wA3lvenqIhSyN5UZn+6wM1x+mdsgdA6/uEr8QPlucD37LhCKfStl26znLPrRNVj5EN" ..
	"O3JDT90jYBIpMEmngw/1K/uFLAfCZxHTGwm9LnWpvXkkxNhLa4IF1vpJaI9SKnW9/x4YjEc9evVykTTDWMTTuHrl3P5hhVy9qmA+" ..
	"yJXZQmjyZTpRGOtq/0RLvcDU7Mjc2go9UeZooZkuaj/lZ1Kq+lYzwVpYPaHaJVONK2AE95CLfO6yBq1V1z3pX96a9F6xVo3wuD8h" ..
	"XDFSIAFREWdSY3YUJ5/upBws2eSwNQVWyMTdfFM/QPKgXUf4wG6HA8cQBvQXaJ3bMnFgn7QCFF74xOiKnv6cu1DoJs4LPwFGyJ0T" ..
	"EXEl9kmCXxVzvNVvmBT1uywMGdt+2/DLiPfVAG1ydJPo2klvsJlxtt9UHev7DuoqqG4eEQBEw58W4fqfY/frulk6S7Uq/w4Gx1KP" ..
	"mDs1Ctyf1nlrUalXmpFs5zpAfHDPczwrOXmYChQuPzIrKCVnO4gygZEYhxubNz23Wm86C0/x3I9KlwIQ91MqIuESAvqVUqtBCEgV" ..
	"0ZAJsmcdtgR3K4+eIadp8N1aQPAP8jZ1RjXcf97rIqjxZz13bIwT7ug8M2qS4EIutD+v/dOqteaIl6LtHwhbIfWf69xPMDXqIMj2" ..
	"U+WzU3ow2sa3cGQi4uYM3oVHElpYDAZfrDwcBER6AY3UzaV8LpotK78TZ9rfqs6gy5vM2AYQ5XEh0bkyW6AswIfn0pe1bP3c/vz2" ..
	"HyZas7Tnfb1IphohJManrLnF2cIW591ck5vhwO7g/Xec2/7Mav0KUTfTIdFNjtmEOz6gO0u6k45elWBQpnxqYHbz7DBFcFrc4ZlH" ..
	"kKiwjhRkQN1xXWAM3S4EBsqENQ4ezoZeCOuysFHEhUa0oqvwovL9300RwB0pNPwqggo8jp4C7PqtuTpGl6eg++P/23V+cvUcjyMq" ..
	"9r+5hO99YR894VSpFdbmOnlTj6t1QeugKUo4b2YBx9yGO4OTAr74RqUY2SphgC47CPaukvHmgHsHpRZ982ThbL5Y52aC7D+twKKl" ..
	"zuE/Rs1ZrZ8CKqECtuxjq9GOv+uiF9CMa5prLYOYU/ZPRIJcM9pMKEr6x0EBFi43/zqCYWV/ZexjSQfzeN3A4ok38kqDBCLtSRlK" ..
	"cu8OSxkCKWNoXjvfdfAHS7ukT1ef63xN8YHrTFChlGOBY8A7Fnuxo5agmn2ca8xVVyv2G+dQwbjS59GILvQOQB+q4eZL9jZhQcnS" ..
	"IUEglvkCvDgfwVslhFdPolMWpyxY+w50zRXoFZaN00nU/ptXKyVUQcVdcbQE4IFggOA/WkOvlgONl1ATwOhoyWw//277orbkkoRP" ..
	"JOT9upejSM1b8wYZNH5GZMKcsfonZsMDdPSvrM2HkFu8oszfv+WyhZbsY+RTqores0ia0JhClgh5K0XxkMullJOl7dqQdla4aC9j" ..
	"JptDu0DFsemOWzkASL6UWjclSMhAzZll4bJxvELMuup51EpbHhj0+UoXvEUKp1Wtgha51LZBCca46kVBffW8GOIgKkLv7jmKtz2d" ..
	"vFwuQmGHESosxrx+87iJr/hEgBothcQuBSDs7e1g+jYfH4qO+Qy/pZ66gdZdUQVhfPcbFbNMbNVzxv5jrAp83ibOZuIHsIofNE5r" ..
	"/PvOfijF0iH0oSlOk9LV/Sxea93sZhsoDYwpksMNPByObjygsdhZBJcFPy/PxoQ+SUrPdWRlSiIg8C+lTA0mvOqS3IxK15/bY1nN" ..
	"5XRFGzYkfUdRmKTy3a5lvbl29pa6MQLFgw2By2NTu18lH4HqT/Mrtymlz9mPoS9Dsp7lmg1osh44+fXi/BgkYzsmvtr29nrk1IdI" ..
	"Lq/OGhme9ZL3IcpBe6oEcMbBIIwlZ9EPqcJEmfhoEkHYFgPNYpwDDVT1oBYaE6+GvjnID5ZLqnOKqPQKCKPa+GcCyE/zyanWvNuC" ..
	"atti53MrDBfPg816mKM8/8N0G90EXrVTFzreJ7G+ZJTvH3YLAOiMgbzNW5LPF23EW4UnMPJhfGaK+PSSzxt24BjbLaMuPRwadCzm" ..
	"itx60QxuR1YnG04Nv1WZu+c8LEON8W/5ZtLz6i1oMGSpy3br9YHJBhoZ2UPB7DwepELW645LliNeIAIs5DactlB6an1bjndaRYD4" ..
	"Myj2MnsMuDGGjSUUkP3Z3X4Y1em63J086e46ZuvbYkAkDf5cADPj0EjcRCXxBGnivjyS03dDkOr1L18KloKmsHUgBQTO9v/P1QGN" ..
	"omRe7mm0Cc9bTys7A+vZYvLu8JILgRkyarzlQl0OzaUpEv3nFzX5dVoMd2bjjz8QBSPQTWkS9kFt7iAqdApCuRwdUWNYNavYJaF/" ..
	"LLqIjWL5WPPB4dNGqaBLbrLIoyn5pjLw3FS7o7ui763n/5vsMJSwOKv6f1BBYZJ56LJtfKGHq+XkKT6EOirvu5KefXQwFlfRNqTA" ..
	"v35rVuqwc9I7umJ7j7g0JT99Ta0Ow+wGpW93UKbKITImCouKK332AcBbW3KtugCDyrWl1tlTkefa96F8HjXRgEwcxmJ2JN4/VRwR" ..
	"sqhoj+/dwQHKL3X09G7K/R9dlzPqyHLuWiC4chLQG8P64rUANT/PK//EUlMxARQo7QYvPu4cg2uuiCn4Ls6ORmM4rDvZf8rapfRS" ..
	"Srkey4oE7rk6hZzs8xJ2oktzz9fpLjLtJaLD3h/Rgv14nltdeEBxOsQ92eJflp8ed6qlEA1JEvigmuiOgI4jLo3SZ05ufasqroQB" ..
	"zWb1LG5e1xqD5W0exlECUwICHpK/LfgffZEcqszRv5fi8I9DuC2uEBuIk8uo6+Zc3Pi5u9Z3sJcGe1jMMF13VCeVRLLyYthUzV1P" ..
	"lEfpu+GJlxSNDZEiGyFbPeEr8kFRd+4rl2zVWQyQvwjybgY96nq2Fw/5u2aRwCLFRmigaFzXGU77pyhtr+4mXnsgnbDYcift9Rvu" ..
	"uzfFW/olm6BFvF5kNsSlkzGkAzLxB/3MnFT+oSDmoP2eAKZO5BHDbLMR66BghqLGz16/dg80bMVi/+zKorl/NNMFhDMb+U0nXZhf" ..
	"HPahez9vqzxSzzSeK78+w2Xe6vh4exgFB/38acqsZC01My20ckxmB/cNfSmRxY6eGe4aQj9eavw+k/cIgFsbZsmn2DKDDNRsyxZu" ..
	"vE2EKMl+3wCaQdUDvwbpMQkWSPFfUmimjwAq05NxzbYVXHL8vQmjyOfSrPFE1OhpBbV0CcKzBFdC61ZzIrWrLRs4+Nb9al4ZvLoJ" ..
	"cr3cpTnl3/6XcVQsktofQzsDRjA0KzNte8FC1bFvjFnQZ8V72/evBNhlULTD4yp2Qbr6Vj9lxNqCu/Ww0ltg9vykzhfdhHRBpPfV" ..
	"vTMbmgd22edcCnxi9+9/tUdFd2SncTLBZHnEgdsB/18scmQrPKjZ3/idgbOKpu3gA0sAZVvckjmqGvPwn7avCCPtL0eSze8n+nBM" ..
	""
local PAYLOAD_P13 =
	"I/Z+oBPcZhA9dMLt2ceRq1p7o0vwGEdSHzae+nxew54mDsMtbTA4M8+5aobkJRvRbhRjZE9BZ78/pN223eEPzfzhiDIZcCODoNvW" ..
	"7uyFFDai1BDR2vS4DbJXgYPWMa2HYz7QBJhTrkcFhXAn+Mf1/yOE2pHYFDx2XF4pdE+a3FcREJTNjy+n5m6IBE/sVQYMBVBxKc/b" ..
	"bQ38jAYzJ5piPhRaR9VNWeSa7t1gNhppfD1jYieMnWsVo9++9MlN+VyIaYchtgtTu6ZeCQfN6yRIbyiFOrEKM+ieOchNwkBzYs2D" ..
	"ccTOUo7HFPRXKMdLN8zpEm21B+5ApxpfHASC2j01Fx9W1WU8sGnfrz0L/hoZSwPET3m0ycwE6zgoTxLTOYOE8NwS6afI6Wfq36cC" ..
	"0UjEK7W4QO5JK9BAV+821iUDWohHj+zYvIpUEVlxQaM7ceBW+DGcUMWQ5w4n7JrNvunqIEtTEtXczrnlhzYa4Al1kJiliqucX2Gt" ..
	"wVfyRPqlrwnPV1KjoT6BkQKtFpB1GzuJbIex4flxmjh7QHq8ZM6wLDQQxEY0E0W6QDpbxBr5ulT+K+KVBdWDImiexVzCuR+nXmA7" ..
	"pnJ6ng5GHgppou25+9wnyUQHluyq0ZhxpaN8m9zFniK7sdgwXDa95ItsY75mp3kh1rDZCBAn6ou4WWw4FnB0wlfVo6/DerwItsCQ" ..
	"y4iXqbyp180/Wb3dN+nUCxVZlMYMa5bxUpDR4DL8o+QW9n43N6EsVYne1HqOHy2Z+c9wYgsr/C1YeSUfPSad1kY28TmzxbgacYji" ..
	"SHsIt2eoadGuHHF0OmHjY3yZ+v7caPvPOWh/FGrbRWyAw20pbCxYdl+1XDtVckyqXeGsKJCwPQ0wPs2LJyKLuvS0jfxxS7ik2BKb" ..
	"B3UxGYCphb2QrjpbUu3MpuCjEJ7A5U4TlOHX8+ZIwOMEPVPABtZ7k5zDYqLXEI2sTND+V9mD+/xu0hi6WINK3oQ81bGMr8jLWyYT" ..
	"xeKaKoHWq1hxm20RhdnWbnWDX7E88RgvBroA2i5on77Ryg9k1ArtbSWSotzjwmff4ZnYyjmki1dfNi/seA0RYEkHBkfk7OChTn10" ..
	"ViWaye26HgjzH56oLysJPPCf1PCmr75NkvslQcZwYJFxClLuEpU8Vu0kuTUqdQg6QX2Gh3NI54A1PPx3x+SzNyMS4MwiUW3tRk/T" ..
	"OkIyModccuklp08TyoqpgRhiCnEd6cDLm8jhdhCnl/gVUdMPyVDHkEDEyZAJh+abCnBbiSGgvhlDNV15EJ93XDIyxqskb+Vou/eM" ..
	"SVBkcrqzzig7GBsi9MW4WQj1UIbPXKuerRLMhAXrVObXz+4GbGjhvd6mhTm5HXy5Gr5LdnYXJRGzbAEuOc1n7IAdwU8N0yId6Tdh" ..
	"cym1ENvLvZGoc6nWQg1KXuRs9kgRS1W0NdbGubOBbWU5WosZ0NzoO+Tb9QVY3wLigDHVS86tihqlke7XtQJR1d7NBIDXbsBVIEEk" ..
	"+I3f0I0N3ydutcdPfYTkS0atkWS7wnMW7yMKwhp7sS/nQSOnsqAMXlDeFIY6gZjwnIYh2WE2yj9EL0X+ldvL/ccqXL4r7FbeSAg9" ..
	"uy2z7KZUkb/MSCDXuZvvb36UWTnw6JEm5ZEdgerkNeetNnAspS0ubevCancWZ/wAlHN4Igzb1D7OeQ9jSuuVvONezcI/mGx8ZHZX" ..
	"ieL/wxHCZRZFSUOOvBGZTQ14fbxgcBL7DWfXPBpoMy4sy2qVABhMLaFzrAu+erpKszffAFKTjvxSb9B3rsKEyIfWWKeNoQI4BOPH" ..
	"KBpyi2i/2eidOoQ3cT/f+h1bVDhAWJI7wMsyTD5kvYcrXAMVlqx7TxGrhtL5dEkAMZPhvSAP/rhhyNggjl3EckVz9YOC8KVUcjIb" ..
	"xiFs3C8WB3rO6KrqZp+J9BIPFcpzyCw9Z9d6oGXTCHM4KpVsXQKRaNZhWub7idREl3dU+qPh0knA4eGYRJyrUoLNXgfSUBHkSfwi" ..
	"CHwT53sUJLizsLKEgdvh77zaI/ACbB2TU5djHGIcddo6j/292sbEw4+DawdLXAjf6v8jbeuIJJYWS5+zmYSZayNE/nnLZsB90hn2" ..
	"dbsTzGg2UYmIJOoPGUiWX+Al/fB5+j8R41bo1/akbHZukBEg0EZ2u0U5oJETJi3RigZirr+/8b6gqp0Nw0Pi8ULEm5l4Qopp8XVI" ..
	"k9LkhoA0KA/MB/7isfcsOYBAffPW7MOJPTEt+Pye84g2g4877ru1RmWWNHXX2PxfEWWYkHcRbE1MoBDa7uoiQaHULbqlV30WvdL3" ..
	"OH0PSag6kn0XSgzAv4HByA5YK8MIKVg2eHuEmykDEgBoPwOKxCbRnpaeCxjEmmnbMhnrr1rqbj+1B/Y7HNOtbArC73Ez10eE/tdC" ..
	"2MbKjpYV1tUdlO3icEzpBDqqq5b2rsmH25NLtBCheazpShy04UWZR4E9re8i3MhrjNuTtfauPZu/rGQiD3c5mWpNF8i+0FqV4PFe" ..
	"84+at3duc2MfAzfCeEpnlsc4BiryDBaLGZruiO/U4y+UU+qdbdAJpBX9Ww2K9L9FSAXZhDSfcXfXf+XWuuI1jR0n5g2li8+IxfB6" ..
	"fchudgKpZ8nFo+vzCoFPelemUZXgHrsXYtoRk+ZxVj3FI4PTkkOBL68Ysx5f2zJ4bd4T+5dX7rLKmOuCo7RRKYuUOm2AK/QEwvs3" ..
	"JjbYqi99aWIQm+w1jZ6pzQxOPMM9Df0v0w1Kaa2i0NaYSL9IEzxWiyehjLMB0rIIrxGs/xjeAYw1LrFYXjLR323+5MbmMl9o83eV" ..
	"WKz0wp+zlEztLxnqH/5pbpOUbFPebmsCrgIDQE1MHfuGsDoP10fby0mbh43kWXpEaKUNEh+8d0cvgVKk90cPS79AiCRzefmpfoAN" ..
	"/ThzuJtbP3i0ea8Hflrrp3ehDMktnmhfPM/mpec+t0YEAVP6mGDU8pLeS6opZJz6L/qw21HLbQ/g94WKlPzKlzPW5FcKVqnoJ8o6" ..
	"ZWH7BZW9vUjFHnI7obTRaicG9eTx45vxI/w1xf17c8Yw69p7DP6uRasiyi1DWGs+5IToNfGqDoShcPzE/qbWltIbcinPfgyqYoet" ..
	"PzzPqqKHPl6Ws85zlS/vHWE0Er9N99rBM+vBucyzAPkcP1QZzoplLI11v+FfjciIufLPP2S8XFXlrXbu5KJlcbyA+gqV2sCcr12m" ..
	"FTwVQmBfVqOAVt94QLSfSBRCgDZ2qGAbqacoUDTH4O7fURqkYLz3mjRAf8olRLYUt82FAfTBaKjFoyh0xEbt4/LNb7OR7m9hlsk/" ..
	"cOQZ8uMQ/6cHymgHudo8NbWAMRehHVR8/MA8zjf8snZr6C6eHsN1MAGvT7yleTPPCtW9k78U4b1DlYjdH/Uf8XshDC+HJNxToJLu" ..
	"4hNoaYwzLkbda2+OaKQw+57mY9W0H13e5XIyFfaPqaxAKbzlSjq/pk55f2YY28yuIztj3yLyuNj3L7+hLafKXptW377vQDsJ4F7J" ..
	"zlPdiyRXGYU4wLzvF65yh4uZ+Au8o70RIvYx1uewJx6BPAxAS2uqpJ6ZHcSZUhp61ZIGgw9gs80ohRRoTZiJipUbyER0h27y+9wx" ..
	"z8lALPpxiBKLJ17IDfV36eZQGrUfe2M+XzKGEFluvLCbwLO8kP72nDKl5KTyavonjBlqsz2eQ7Cz8jRM9+aa0ibSY0cTWmsfvVZZ" ..
	"M2Cw1RujbjUrvDvcIdVPXELYIdM47Rp88dHPBBSfoooExwthOuYi30C0R91ka4P0DtO4xbBbnQI/my0YBs5cTI3CMQEsJQ7+1T0N" ..
	"3TOOTvw4YAeJ72dCGEfaWNF9FjAlaDmgRldgi8Lo3+iyrmlUMT49H9Fl6+c2xqfG49twqtn6VYxxnCgxOXsw05DXWvDTFK1yXI/K" ..
	"+2UEKKAKZPoHqJEjPwRBVdKsxga13A4Cq/kyVt7Dd6GSk8CtlB4kvkKYM2Nc3cwQYW5X+Xm47NG/V4zVWY/i2XbBGXC+NSj1kLUG" ..
	"a54Tk68TD6Ay/BG6XulIL12ModoyLA/2tIMsnF66re5aPN02W1h+zkhDRebfDGkLh2OP3BqsihroRcIy2CE+TOHiS05vM6J0Cpzv" ..
	"Swm2HOEq295UsEIVKxwMn4v02fWAjKQBasJ23wIPdd216IIuVxnso871ZWPhAlGkM+c8PcZXb57vVDT80i3S67bj6c7G1T5mBtwT" ..
	"sGWlI2ndlMkiTWA3/h4sNqKnZfwiWBbzZzZd2M7ySwLZdGRqe7c0WeLY+weRRdRAlyD2ArhOgz4+HK1n81ST1UqGsCed8Eg1Emeq" ..
	"w5z2AROiVE5WJiRRArQA703i8JMKufHyvyDqmASzGiDDXz0TtH6Q0MD5NOVX/OnAu76Iq2gGV2+LFFxbsVKaE1eq0JpzysdgYjcH" ..
	"UbyL4GU/s5vg2LmBY7+W1tCj4nzrh5yqtNQQyuQ/EZBVSFMUV4ajsnWhq/lwrejX/cSMXOM5BPI87WItB5ZT0zENmcTw0H9YGOxL" ..
	"PiQiipG9AGJOFkAiutS4e84wTFWb+H7H5MM22d1Yg9iGW/CJXeKEjkNe2rKVtfFwWMY2v/OMEHVBqtwR5n7imTFUZaTLj9cdkWeY" ..
	"+jdO/BfIADX5H4j6URwLC/xB5gmRbC+FnpcTEAIrIdcqBpxeE1qJ6palLXlAQ979u2iZv5SNhNNu8tr7akj/zxhhC1eMGZgGMDRk" ..
	"AB8FFEPHENdN0QlMEgHdqqOGhjKQ2lU+pSDT7/gB4EO/z9zqofQfifm0GdOMRvr5v4+0+qQ2tnqgJs2gr2OyB3HfRXb1HNXVY0Sr" ..
	"FlojE14bjvnxqjFZZPz5HQi6GlWhZUtm3UNaeImbtPw5H+rvzMldp80BE8rAPwJE81PAMkLAqy9thYKx8OId5Pkdp2BCZdFcDbb7" ..
	"JP98C//w6cSy5J3pTVwW2Odf7oa7BGBpSp2xx9Px5RL8i1IYyXRFASxA1DQRiAONbbexV9Zxlw+17Z5PvLHUTZJT0tfVJE30GIdQ" ..
	"X4hLUB8fZBKUiNPMa4JasK5gubZToKeEsfquRWhucrPuDcxiyI8alOk3LuqkGwVrmOgniPEioWhesNHkqV914WeHb2NfhpXN4PtN" ..
	"7Y0WVeshofNwi+tpBEYIaemoLbs0hHLrfhSHUFdkYdZTfbdIj+MOCofVRe+xtsP2wtB8ybkVOXh4yAjXC1aQzUto8SRnDdsW3W1M" ..
	"Pmo/Vvj+Vi3ic0VEC0pZON6fvl0CyaMWWr69u9k1QdiiWpADqCppXhmH2HdVB2F+c1SkCDAB+IYbNYCT/OC26UJ6f9zgs4r4zcFF" ..
	"wGPl620k9eE/a1vJsW1z3ap4jVzJ++LeQ8RcPeYVf/tq3qO4i+zuLDJsCIO4muYZu4Myw8RIEbCr4qZIGrhEbLxgrVwGsfiabxXm" ..
	"knIRDyA1nu5TmLgUl7X/p6eXi9ZhAM9rZmyJUqL2F9U2rnqL+SALe30ENaJKAEqfPM9KZvMZ2g4EbRG8ZrvWjL8GOkZ+iv94W2oh" ..
	"pfmbWWIFxn5WQpwGdpRgfZ9luVNwNYq/Z9Gk7jOFi5TctjfgUl6KJGEFhDlnt27OrUwyrjvBopvRFawzPazgD9iU0f23rhUAHSdr" ..
	"JQDlEhRgtgH0/WqTaSgafMFP1qimdyGCKCtQcI0cmJT0TPkB9lnDQ6CG8nw9Y2JZhDU5FYhWWlZYLe8/NxDSQCz2dH1FINxUD/K9" ..
	"7rFsCVeoJyFvWTuAiMy5PIG8cPapVmktmP/IQmCbdny0OMsLAhHQyM3I9s1aQ8ZGoulnCWeop4Yk+g53Sk6ALnGlBoro4WrBSqxZ" ..
	"bZPhfbo3kdOUc3DhRS4UrQ95/dvo3zTuNrQFrAMmbRNO3otVMea3LWRTlv5NZ3Z4URHxWgw47LxjH6Eh4FvNXEFKcqkW+g2LiwYJ" ..
	"Y9mwqvgrOYHjAIAJ9E2yqJhiVsYj9913tAoolxMxblFTTEGaQQn5S3DoikXSuRtpvFhTG/E33FEolBE6tSGB5tg+7K878hDOyeRK" ..
	""
local PAYLOAD_P14 =
	"cAWeNSgRgxkZuODBUGxvzgb7YXklvDERQrwL80z5lZTL1wQuMJXG3DOjA6aEwfcMBTPm2PQA2iBEobbq7LTqO+ELUCQay1TpxK4v" ..
	"duf0ka876Jxk2sR6b9M0UjIMAoDJBMYQ2hkn6jzzrOt0JSXGI3x6p568zwdzAkknXVRL0UD9LHn5a8C6qD7C6d4J+HUVrAsEZUmH" ..
	"7EXPNMlm4156ikDHKf/bvxsXj37kOErLPtDxqYjBZPek9nFCvkn5wsFfzFrnPlawXW2syD8Xet2kbcc9o5oRR/xbo2oqagsxi8Kd" ..
	"VbYmrqrtKet4n5th4Abg0xIyZUj9w1w+NvGC8SWkiFrUYnC0SteDn68+iCqM+rNGP65BmmEvYpsP+u3xkH8RZJiXI2K3eFFUOG2k" ..
	"iol7zfOBpF66ldgd1T/iMAOpUUjXmuncyUVGCieT9z6htWbnTSoU7yCdZvdVPL2AZ2rCd9HWVJ1w6mIHhRAm9qZXeBcWw90/FNfS" ..
	"U22vNMGmggt9XD6nch8dPuCgCTCzmhzC8IVU5JFmYtNiqs2R8mfFW6tJBisuxehH1f9Ct/orbKNXel4XefuSfvte1FI3XJ9wquNp" ..
	"qKryVDHl2zJGG2nEfmG2SQLie4YYDWYTKaKq+5yc33LtFAeSCy4IBab0BAn1zoM0vAmLEfXT86cdsHJcEhqZWDXCH0EPqMGYjQ7n" ..
	"6NVYe7tTiqI1lFFV/68sQkDYbkzxgi/FFHaUe+o5nS4xYANGGrpo8Ur2HLNJkpYQW3QU9Kxny2jVaY2OpWxFlxERPmccMF7ywr+x" ..
	"3LZLAvAjUJlD79dbnVUjZLsMGlhYzxLiCR7MNYCQ7DmnkuJ6Z1le+ggA8oW21j0iPmTQHh82HU/4JIwB4m6HdRs+bcUY3rjSA8gd" ..
	"HxaGQ7v4QgQAV6lG1UlCmw3sPvG0EWfTBIv40WD7cxwyULogz0HupDmSpehKrEMF4mtMGokLqRAqBjgdzWhvl/up95UPoxGfCAMX" ..
	"q5qFsDKoianXvEEJLOLeAex6t62NHggAYITiy2TF63yHMcphR27IcRFpIwsLKqESYAM9HrvKP64h7856RvSKJvEOVMHVtjnbsBTR" ..
	"YfUTRXSHBYv/vJ+crmSHlwac8aIg9jiXgXeXQJCcbcrgkA2nUsR3jZlCOphR4Aioe+OfTHhtLg7qgsCUVjKLIHQtmShbk4xe7XFr" ..
	"iEsCwTtF4f+kvEqiaSSIEQPnrkvxS1eSEWTwi57mnenn4fJXcrbMPlZ5xqR7nKjD3FEz+G9c7IgjdhvVyQmRc4YnXWm7RH+bxplV" ..
	"R5+uSnEQ0naRph4chrMivYasJo34p/O+EtHZKBh14ECz+qnmf2UlRH3VWUpO2CLwwGLsc9xYbPdTzDXvP2Wdd7a4dtRMt74m+VMe" ..
	"YorwuPQe7NCbkOcOTPe2mCCzrKoHiSelnyLJLiOhznpmiW3mFOVZtQVYoRscQM7FF94PCJnp1EGf3jEw0elEfOnXZHyrLpkiQ137" ..
	"JnI3SaZXHujlnS9xORlIRTKTZxKnJHQJFTUw7vPO3BaOI/HbmIRhrdu2BkUS6y01uxp0KH6CM5ZlfKW+tbSiAOfyoWEN4VyVB7jd" ..
	"0uz8PCajiKeTG2l3WnMbTPkdSVxM5HnrSxiZeQ1lkm2ZbZAsUogtbaXKW91Lu95AQrMUue5lbC1096iAVepP1A8xevKzx3lw607a" ..
	"53E1qoSLfAmmYbhG+SxfTA1vD3Vxa41b8u2BznO9IPToSA944sij5n4EbuhRdvhSzyfjuL9hNOEA/i85PCShtE7djOHmiU7vk/2Q" ..
	"vgqttr6wTSkFlIA0Nvze2zgj1TPFrJlk3EroIvWe8mY//fTOhCr1WbQ17SgLuxhZfLsRZ0/Z8KXQ+pvgexhT1UKpuHEambDnxlXU" ..
	"M9YzFBk5k1CcaFArTmWXvWQB+WrughUzMN8dNP68e8EolaycsZ/ZgvEaFLKkXXaM50jnnjRy7FrbrKWxfV7pWRT0PLl7uLKCryJA" ..
	"VV3kdrPML0XOZg==" ..
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
